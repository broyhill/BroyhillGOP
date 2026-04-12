"""
Normalize employer text for NCBOE GOLD + optional SIC/NAICS lookup.

Per SESSION_APRIL12_2026: use donor_intelligence.employer_sic_master on the same
database when populated (pg_dump from Supabase when authorized — do not pull from Supabase here).
"""

from __future__ import annotations

import re
from typing import Any

_STRIP_SUFFIXES = re.compile(
    r"\b(INC\.?|LLC\.?|CORP\.?|CO\.?|LTD\.?|LP\.?|LLP\.?|PC\.?|PA\.?|PLLC\.?|DBA)\b",
    re.IGNORECASE,
)

_VARIANT_GROUPS: tuple[tuple[str, ...], ...] = (
    ("ANVIL VENTURE GROUP", "ANVIL VENTURES", "ANVIL VENTURE", "ANVILE VENTURE"),
    ("VARIETY WHOLESALERS", "VARIETY WHOLESALE"),
)

_SELF_EMPLOYED = frozenset(
    {
        "SELF",
        "SELF-EMPLOYED",
        "SELF EMPLOYED",
        "SELFEMPLOYED",
    }
)
_NONE_LIKE = frozenset({"NONE", "N/A", "NA", "NULL", "UNK", "UNKNOWN"})


def _collapse_spaces(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip())


def _strip_corporate_noise(s: str) -> str:
    s = _STRIP_SUFFIXES.sub("", s)
    s = re.sub(r"[,.\s]+$", "", s)
    return _collapse_spaces(s)


def _apply_known_variants(s: str) -> str:
    u = s.upper()
    for group in _VARIANT_GROUPS:
        for variant in group:
            if u == variant.upper() or u.startswith(variant.upper() + " "):
                return group[0].upper()
    return u


def normalize_employer_text(raw: str | None) -> str | None:
    """
    Uppercase, strip corporate noise, map known variants, map retired/self, blank → NULL.
    """
    if raw is None:
        return None
    t = str(raw).strip()
    if not t:
        return None
    u = t.upper()
    if u in _NONE_LIKE:
        return None
    if u in ("RETIRED", "RET", "RET."):
        return "RETIRED"
    if u in _SELF_EMPLOYED or "SELF-EMPLOYED" in u.replace(" ", ""):
        return "SELF-EMPLOYED"
    u = _collapse_spaces(u)
    u = _strip_corporate_noise(u)
    u = _apply_known_variants(u)
    u = re.sub(r"[,.\s]+$", "", u)
    u = _collapse_spaces(u)
    return u or None


def lookup_sic_naics(conn: Any, normalized: str | None) -> tuple[str | None, str | None]:
    """
    Return (sic_code, naics_code) from local donor_intelligence.employer_sic_master.
    Table may be empty until a dump is loaded onto Hetzner.
    """
    if not normalized or conn is None:
        return None, None
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT sic_code, naics_code
                FROM donor_intelligence.employer_sic_master
                WHERE employer_normalized = %s
                   OR UPPER(TRIM(employer_raw)) = %s
                ORDER BY match_confidence DESC NULLS LAST
                LIMIT 1
                """,
                (normalized, normalized),
            )
            row = cur.fetchone()
            if not row:
                return None, None
            return (row[0], row[1])
    except Exception:
        return None, None


def _self_tests() -> None:
    assert normalize_employer_text("  anvil ventures llc  ") == "ANVIL VENTURE GROUP"
    assert normalize_employer_text("RETIRED") == "RETIRED"
    assert normalize_employer_text("self employed") == "SELF-EMPLOYED"
    assert normalize_employer_text("none") is None
    print("employer_normalizer: all self-tests passed")


if __name__ == "__main__":
    _self_tests()
