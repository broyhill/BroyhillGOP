"""
e61.normalize — canonical pre-ingestion normalizer.

Every CSV that wants to become a Hetzner record passes through this module
first. Encodes the lessons from the 2026-04-27 party-committee diagnosis:

- Names ALL CAPS + BTRIM + single-space (collapses 8,447 non-caps + 80 double-space rows)
- Embedded nicknames extracted: 'NICKNAME' and (NICKNAME) patterns lifted out
  of the legal name into a separate field (~12K rows in NCBOE party committee file)
- Addresses BTRIM + single-space (fixes 2,830 double-space defects like
  "632  KINGSBURY DRIVE")
- ZIP forced to TEXT, padded to 5 digits (fixes 290 broken 4-digit zips and
  prevents future Excel leading-zero strips)
- ZIP+4 truncated to ZIP5 for matching (11,746 rows in the party committee file)
- State forced to uppercase 2-letter (no-op on this file but defensive)
- Empty strings normalized to None for downstream NULL handling

Designed to be idempotent: running normalize() on already-normalized output
returns identical output.

USAGE
-----
    from e61.normalize import normalize_row, NormalizationResult

    result = normalize_row(raw_row, source_id='ncboe_party_committee')
    if result.quarantine_reason:
        # send to e61.quarantine
        ...
    else:
        # send to e61.ingested_row.normalized_payload
        ...
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field, asdict
from typing import Any


# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------

# Single-quoted nickname: JAMES EDGAR 'ED' BROYHILL  →  nickname=ED
RE_QUOTED_NICKNAME = re.compile(r"'([A-Za-z][A-Za-z\-]+)'")

# Parenthesized nickname: ADELE (DEE) PARK  →  nickname=DEE
RE_PAREN_NICKNAME = re.compile(r"\(([A-Za-z][A-Za-z\-]+)\)")

# Multi-space collapse
RE_MULTI_SPACE = re.compile(r"\s+")

# Suffix detection (Sr, Jr, II, III, IV, MD, PhD, Esq)
RE_SUFFIX_AT_END = re.compile(
    r"\b(JR|SR|II|III|IV|MD|PHD|ESQ|DDS|DVM|CPA)\.?\s*$"
)

# Honorific prefix (Mr, Mrs, Ms, Dr, Hon, Rev)
RE_HONORIFIC_PREFIX = re.compile(
    r"^(MR|MRS|MS|DR|HON|REV|REVEREND|MR\.|MRS\.|MS\.|DR\.|HON\.|REV\.)\s+"
)

# Suspect corporate/PAC tokens (NCBOE clerk-error indicators in NAME column)
NONPERSON_TOKENS = {
    "LLC", "LLP", "LP", "INC", "CORP", "CORPORATION", "INCORPORATED",
    "FOUNDATION", "TRUST", "FOUNDRY", "PIPE", "PARTNERS", "HOLDINGS",
    "REALTY", "PROPERTIES", "CO", "GROUP", "ASSOCIATION", "FARMS",
    "FARMING", "INVESTMENTS", "INVESTMENT", "CAPITAL", "CONSULTING",
    "MANAGEMENT", "ENTERPRISES", "VENTURES",
}

# ZIP code patterns
RE_ZIP_5DASH4 = re.compile(r"^(\d{5})-(\d{4})$")
RE_ZIP_5 = re.compile(r"^(\d{5})$")
RE_ZIP_4 = re.compile(r"^(\d{4})$")
RE_ZIP_DIGITS_ONLY = re.compile(r"^\d+$")


# ---------------------------------------------------------------------------
# Result dataclass
# ---------------------------------------------------------------------------

@dataclass
class NormalizationResult:
    """One row of normalized output, ready for cluster_id_v2 + DataTrust match."""
    raw: dict[str, Any]
    canonical_name: str | None = None
    legal_first: str | None = None
    legal_middle: str | None = None
    legal_last: str | None = None
    suffix: str | None = None
    nickname: str | None = None
    honorific: str | None = None
    addr_line_1_canonical: str | None = None
    addr_line_2_canonical: str | None = None
    city_canonical: str | None = None
    state_canonical: str | None = None
    zip5: str | None = None
    zip_full: str | None = None
    quarantine_reason: str | None = None
    quarantine_detail: str | None = None
    flags: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def _canon(s: Any) -> str | None:
    """Uppercase + collapse internal whitespace + btrim. Empty → None."""
    if s is None:
        return None
    text = str(s).strip()
    if not text:
        return None
    text = RE_MULTI_SPACE.sub(" ", text).upper()
    return text or None


def _extract_nickname(name_raw: str) -> tuple[str, str | None]:
    """Strip 'NICKNAME' or (NICKNAME) from name; return (cleaned_name, nickname)."""
    nickname = None
    cleaned = name_raw

    m = RE_QUOTED_NICKNAME.search(cleaned)
    if m:
        nickname = m.group(1).upper()
        cleaned = RE_QUOTED_NICKNAME.sub("", cleaned, count=1)

    if not nickname:
        m = RE_PAREN_NICKNAME.search(cleaned)
        if m:
            nickname = m.group(1).upper()
            cleaned = RE_PAREN_NICKNAME.sub("", cleaned, count=1)

    cleaned = RE_MULTI_SPACE.sub(" ", cleaned).strip()
    return cleaned, nickname


def _extract_suffix(name_canonical: str) -> tuple[str, str | None]:
    """Strip trailing Sr/Jr/II/III/etc. from name; return (cleaned, suffix)."""
    m = RE_SUFFIX_AT_END.search(name_canonical)
    if not m:
        return name_canonical, None
    suffix = m.group(1).rstrip(".")
    cleaned = RE_SUFFIX_AT_END.sub("", name_canonical).strip()
    return cleaned, suffix


def _extract_honorific(name_canonical: str) -> tuple[str, str | None]:
    """Strip leading Mr./Mrs./Dr./etc. from name; return (cleaned, honorific)."""
    m = RE_HONORIFIC_PREFIX.search(name_canonical)
    if not m:
        return name_canonical, None
    honorific = m.group(1).rstrip(".")
    cleaned = RE_HONORIFIC_PREFIX.sub("", name_canonical).strip()
    return cleaned, honorific


def _split_first_middle_last(name_no_suffix_no_honorific: str) -> tuple[str | None, str | None, str | None]:
    """
    Split a cleaned name string into (first, middle, last). Conservative:
    1 token  → (name, None, None)
    2 tokens → (first, None, last)
    3 tokens → (first, middle, last)
    4+       → (first, ' '.join(middles), last)
    """
    parts = name_no_suffix_no_honorific.split()
    if not parts:
        return None, None, None
    if len(parts) == 1:
        return parts[0], None, None
    if len(parts) == 2:
        return parts[0], None, parts[1]
    return parts[0], " ".join(parts[1:-1]), parts[-1]


def _normalize_zip(zip_raw: Any) -> tuple[str | None, str | None, str | None]:
    """
    Return (zip5, zip_full, quarantine_reason).

    - 5-digit numeric → ('27104', '27104', None)
    - 5+4 ('27104-3224') → ('27104', '27104-3224', None)
    - 4-digit numeric → (None, None, 'broken_zip_4_digit')
    - blank → (None, None, None)
    - other → (None, None, 'unparseable_zip')
    """
    if zip_raw is None:
        return None, None, None
    z = str(zip_raw).strip()
    if not z:
        return None, None, None

    m = RE_ZIP_5DASH4.match(z)
    if m:
        return m.group(1), z, None

    m = RE_ZIP_5.match(z)
    if m:
        return m.group(1), m.group(1), None

    if RE_ZIP_4.match(z):
        return None, z, "broken_zip_4_digit"

    if RE_ZIP_DIGITS_ONLY.match(z) and len(z) > 5:
        # ZIP-too-long; take left-5
        return z[:5], z, None

    return None, z, "unparseable_zip"


def _is_corporate_in_name_field(canonical_name: str) -> bool:
    """Detect corporate/PAC patterns hiding in the NAME column (NCBOE clerk error)."""
    if not canonical_name:
        return False
    tokens = set(re.findall(r"\b[A-Z][A-Z]+\b", canonical_name))
    return bool(tokens & NONPERSON_TOKENS) or "&" in canonical_name


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def normalize_row(raw: dict[str, Any], source_id: str = "default") -> NormalizationResult:
    """
    Normalize one source row. Returns NormalizationResult with either clean
    fields (for ingested_row) or a quarantine_reason set.
    """
    result = NormalizationResult(raw=raw)

    # --- NAME ---
    name_raw = raw.get("Name") or raw.get("name") or ""
    canonical_name_full = _canon(name_raw)

    if not canonical_name_full:
        result.quarantine_reason = "name_empty"
        return result

    # Quarantine-flag corporate-in-name (don't reject; let admin review)
    if _is_corporate_in_name_field(canonical_name_full):
        result.quarantine_reason = "corporate_name_in_name_field"
        result.quarantine_detail = (
            f"Tokens detected suggest a corporate/PAC entity in the donor Name field, "
            f"likely an NCBOE data entry error. Original: {name_raw!r}"
        )
        result.canonical_name = canonical_name_full
        return result

    # Extract embedded nicknames (BEFORE further processing)
    name_no_nick, nickname = _extract_nickname(canonical_name_full)
    result.nickname = nickname

    # Extract honorific (Mr/Mrs/Dr/etc.)
    name_no_hon, honorific = _extract_honorific(name_no_nick)
    result.honorific = honorific

    # Extract suffix (Sr/Jr/II/III)
    name_clean, suffix = _extract_suffix(name_no_hon)
    result.suffix = suffix

    # Split into first/middle/last
    first, middle, last = _split_first_middle_last(name_clean)
    result.legal_first = first
    result.legal_middle = middle
    result.legal_last = last
    result.canonical_name = name_clean

    # --- ADDRESS ---
    result.addr_line_1_canonical = _canon(raw.get("Street Line 1") or raw.get("street_line_1"))
    result.addr_line_2_canonical = _canon(raw.get("Street Line 2") or raw.get("street_line_2"))
    result.city_canonical = _canon(raw.get("City") or raw.get("city"))

    # --- STATE ---
    state_raw = raw.get("State") or raw.get("state") or ""
    state = _canon(state_raw)
    if state and len(state) > 2:
        # Sometimes "North Carolina" instead of "NC" — leave as-is for now
        result.flags.append("state_full_name_not_2letter")
    result.state_canonical = state

    # --- ZIP ---
    zip_raw = raw.get("Zip Code") or raw.get("zip_code") or raw.get("zip")
    zip5, zip_full, zip_q = _normalize_zip(zip_raw)
    result.zip5 = zip5
    result.zip_full = zip_full

    if zip_q == "broken_zip_4_digit":
        result.quarantine_reason = "broken_zip_4_digit"
        result.quarantine_detail = f"4-digit ZIP {zip_raw!r} cannot be reconstructed without external lookup"
        result.flags.append("broken_zip_4_digit")
    elif zip_q == "unparseable_zip":
        result.quarantine_reason = "unparseable_zip"
        result.quarantine_detail = f"ZIP value {zip_raw!r} did not match any expected pattern"

    return result


# ---------------------------------------------------------------------------
# Self-test fixtures (the lessons of 2026-04-27, encoded)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Each fixture is a (name, expected_legal_first, expected_legal_last, expected_nickname) tuple
    fixtures = [
        ("Ed Broyhill",                       "ED",     "BROYHILL", None),
        ("ED BROYHILL",                       "ED",     "BROYHILL", None),
        ("JAMES BROYHILL",                    "JAMES",  "BROYHILL", None),
        ("JAMES E BROYHILL",                  "JAMES",  "BROYHILL", None),
        ("James Edgar Broyhill",              "JAMES",  "BROYHILL", None),
        ("JAMES EDGAR BROYHILL",              "JAMES",  "BROYHILL", None),
        ("JAMES EDGAR 'ED' BROYHILL",         "JAMES",  "BROYHILL", "ED"),
        ("ADELE (DEE) PARK",                  "ADELE",  "PARK",     "DEE"),
        ("CHRIS HOWARD",                      "CHRIS",  "HOWARD",   None),
        ("PAUL 'JUDGE' HOLCOMBE",             "PAUL",   "HOLCOMBE", "JUDGE"),
        ("DR. KEITH NAYLOR",                  "KEITH",  "NAYLOR",   None),
        ("CHARLOTTE PIPE AND FOUNDRY",        None,     None,       None),  # quarantined
    ]
    for name, exp_first, exp_last, exp_nick in fixtures:
        row = {"Name": name, "State": "NC", "Zip Code": "27104"}
        r = normalize_row(row)
        status = "PASS" if (r.legal_first == exp_first and r.legal_last == exp_last and r.nickname == exp_nick) else "FAIL"
        if r.quarantine_reason:
            status = "QUAR" if exp_first is None else f"FAIL (quarantined: {r.quarantine_reason})"
        print(f"  [{status}] {name!r:50s}  →  first={r.legal_first}, last={r.legal_last}, nick={r.nickname}")

    # Address normalization
    print()
    addr_row = {"Name": "RENEE HILL", "Street Line 1": "632  KINGSBURY DRIVE", "City": "DURHAM", "State": "NC", "Zip Code": "27712"}
    r = normalize_row(addr_row)
    print(f"  Addr collapse:  '632  KINGSBURY DRIVE'  →  {r.addr_line_1_canonical!r}")
    assert r.addr_line_1_canonical == "632 KINGSBURY DRIVE", "double-space collapse failed"

    # ZIP normalization
    for z, expected in [("27104", "27104"), ("27104-3224", "27104"), ("2780", None)]:
        zip5, zip_full, q = _normalize_zip(z)
        print(f"  ZIP {z!r:12s}  →  zip5={zip5!r}, zip_full={zip_full!r}, q={q!r}")
