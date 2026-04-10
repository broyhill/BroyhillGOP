"""
Cross-source identity matching for BroyhillGOP pipeline.

Tier 1: Exact match on LASTNAME|STREETNUMBER|ZIP5 dedup_key across sources.
  - ncboe_voter      (nc_voters / normalized staging)
  - fec              (nc_boe_donations_raw / fec staging)
  - datatrust        (nc_datatrust — uses regaddressnumber natively)

Tier 2/3 (Levenshtein / Soundex fuzzy) stays in the match layer and is NOT here.

Name format differences handled at key-build time:
  - NCBOE:      stored as "LAST, FIRST MIDDLE"  → last = split(',')[0].strip()
  - FEC:        stored as "FIRST MIDDLE LAST"   → last = split()[-1] after suffix strip
  - DataTrust:  separate first_name / last_name columns → last_name used directly

Street number:
  - DataTrust:  prefers regaddressnumber column (already parsed by RNC)
  - NCBOE/FEC:  uses extract_street_number_v2 from ncboe_voter_normalize_pipeline
                (PO Box / RR / HC addresses yield NULL → key skipped)

Output table: pipeline.cross_source_matches
  - One row per matched pair (source_a, key_a, source_b, key_b, dedup_key, matched_at)
  - dedup_key_null_count logged to pipeline.identity_pass_log

Usage:
    from pipeline.dedup_cross_source import run_cross_source_match
    result = run_cross_source_match()
    print(result.to_report())
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field

import psycopg2
from psycopg2 import sql

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Suffixes to strip before extracting last name from FEC "FIRST MIDDLE LAST" format
# ---------------------------------------------------------------------------
_FEC_SUFFIXES = frozenset(
    ["JR", "SR", "II", "III", "IV", "V", "ESQ", "MD", "PHD", "DDS", "RN", "CPA"]
)

# Non-physical address patterns — same list as extract_street_number_v2
_NON_PHYSICAL_RE = re.compile(
    r"^(P\.?\s*O\.?\s*(BOX)?|POST\s+OFFICE(\s+BOX)?|RURAL\s+ROUTE|RR\s+\d|HC\s+\d)",
    re.IGNORECASE,
)

_UNIT_RE = re.compile(
    r"\b(APT|APARTMENT|STE|SUITE|UNIT|#|LOT|BLDG|BUILDING|FL|FLOOR)\b",
    re.IGNORECASE,
)

_HOUSE_NUM_RE = re.compile(r"\b(\d{1,5})[A-Z]?\b")


# ---------------------------------------------------------------------------
# Name normalisation helpers
# ---------------------------------------------------------------------------

def _normalize_last_ncboe(raw_name: str) -> str:
    """
    NCBOE stores names as 'LAST, FIRST MIDDLE'.
    Returns uppercased, stripped last name token.
    Empty string if blank.
    """
    if not raw_name or not raw_name.strip():
        return ""
    return raw_name.split(",")[0].strip().upper()


def _normalize_last_fec(raw_name: str) -> str:
    """
    FEC stores names as 'FIRST [MIDDLE] LAST [SUFFIX]'.
    Strips known suffixes then takes the final token as last name.
    Returns uppercased, stripped last name token.
    Empty string if blank or single token (initials only).
    """
    if not raw_name or not raw_name.strip():
        return ""
    parts = raw_name.strip().upper().split()
    # Strip trailing suffixes
    while parts and parts[-1].rstrip(".") in _FEC_SUFFIXES:
        parts.pop()
    if not parts:
        return ""
    return parts[-1]


def _normalize_last_direct(raw_last: str) -> str:
    """DataTrust / tables with a dedicated last_name column."""
    if not raw_last or not raw_last.strip():
        return ""
    return raw_last.strip().upper()


# ---------------------------------------------------------------------------
# Street number extraction (mirrors extract_street_number_v2 in pipeline)
# ---------------------------------------------------------------------------

def extract_street_number_v2(address_line: str) -> str | None:
    """
    Extract house/street number from a free-text address line.

    Returns:
        str  — the numeric street number (digits only, no suffix letter)
        None — when address is non-physical (PO Box, RR, HC) or no number found
    """
    if not address_line or not address_line.strip():
        return None

    normalized = " ".join(address_line.upper().split())

    if _NON_PHYSICAL_RE.match(normalized):
        return None

    # Strip unit designator and everything after it
    unit_match = _UNIT_RE.search(normalized)
    prefix = normalized[: unit_match.start()].strip() if unit_match else normalized

    # Try to find house number in prefix
    num_match = _HOUSE_NUM_RE.search(prefix)
    if num_match:
        return num_match.group(1)

    # Comma fallback: walk segments from the end (handles "APT 4, 789 ELM")
    for segment in reversed(normalized.split(",")):
        seg = segment.strip()
        unit_m = _UNIT_RE.search(seg)
        seg_prefix = seg[: unit_m.start()].strip() if unit_m else seg
        m = _HOUSE_NUM_RE.search(seg_prefix)
        if m:
            return m.group(1)

    return None


def zip_left5(raw_zip: str) -> str:
    """Return first 5 digits of ZIP or empty string."""
    if not raw_zip:
        return ""
    digits = re.sub(r"\D", "", raw_zip.strip())
    return digits[:5]


# ---------------------------------------------------------------------------
# Dedup key builder
# ---------------------------------------------------------------------------

def build_dedup_key(last_name: str, street_number: str | None, zip5: str) -> str | None:
    """
    Tier 1 dedup key: LASTNAME|STREETNUMBER|ZIP5

    Returns None when last_name is blank or zip5 is not 5 digits.
    street_number may be empty string — key is still valid when ln + zip are present.
    """
    last = last_name.strip().upper() if last_name else ""
    z5 = zip5.strip() if zip5 else ""

    if not last or len(z5) != 5:
        return None

    num = (street_number or "").strip()
    return f"{last}|{num}|{z5}"


# ---------------------------------------------------------------------------
# Cross-source match result
# ---------------------------------------------------------------------------

@dataclass
class CrossSourceMatchResult:
    passed: bool
    pairs_inserted: int = 0
    dedup_key_null_count: int = 0
    summary: str = ""

    def to_report(self) -> str:
        return (
            f"Cross-source match: {self.pairs_inserted} new pairs inserted\n"
            f"Null dedup keys skipped: {self.dedup_key_null_count}\n"
            f"{self.summary}"
        )


# ---------------------------------------------------------------------------
# Ensure output table
# ---------------------------------------------------------------------------

def _ensure_cross_source_table(conn: psycopg2.extensions.connection) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS pipeline.cross_source_matches (
                id              BIGSERIAL PRIMARY KEY,
                dedup_key       TEXT NOT NULL,
                source_a        TEXT NOT NULL,
                row_id_a        TEXT NOT NULL,
                source_b        TEXT NOT NULL,
                row_id_b        TEXT NOT NULL,
                match_tier      SMALLINT DEFAULT 1,
                matched_at      TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE (source_a, row_id_a, source_b, row_id_b)
            );
            CREATE INDEX IF NOT EXISTS idx_csm_dedup_key
                ON pipeline.cross_source_matches (dedup_key);
            CREATE INDEX IF NOT EXISTS idx_csm_source_a
                ON pipeline.cross_source_matches (source_a, row_id_a);
            CREATE INDEX IF NOT EXISTS idx_csm_source_b
                ON pipeline.cross_source_matches (source_b, row_id_b);
            """
        )


# ---------------------------------------------------------------------------
# Key extraction per source
# ---------------------------------------------------------------------------

def _build_keys_ncboe(conn: psycopg2.extensions.connection) -> dict[str, str]:
    """
    Pull NCBOE voter records and build Tier 1 keys.
    Returns {dedup_key: voter_reg_num} — one representative per key
    (multiple same-address people may share a key; that's intentional for cross-source match).
    """
    keys: dict[str, list[str]] = {}
    null_count = 0

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT voter_reg_num, last_name, res_street_address, zip_code
            FROM   public.nc_voters
            WHERE  last_name IS NOT NULL
              AND  last_name != ''
            LIMIT  5000000
            """
        )
        for row in cur:
            voter_id, raw_last, raw_addr, raw_zip = row
            last = _normalize_last_ncboe(raw_last)
            num = extract_street_number_v2(raw_addr or "")
            z5 = zip_left5(raw_zip or "")
            key = build_dedup_key(last, num, z5)
            if key is None:
                null_count += 1
                continue
            keys.setdefault(key, []).append(str(voter_id))

    logger.info("NCBOE keys built: %d unique, %d nulls", len(keys), null_count)
    return keys, null_count


def _build_keys_fec(conn: psycopg2.extensions.connection) -> tuple[dict[str, list[str]], int]:
    """
    Pull FEC NC donor records and build Tier 1 keys.
    Returns ({dedup_key: [row_ids]}, null_count)
    """
    keys: dict[str, list[str]] = {}
    null_count = 0

    with conn.cursor() as cur:
        # Try nc_boe_donations_raw first, fall back to fec_contributions staging
        try:
            cur.execute(
                """
                SELECT id::text, contributor_name, contributor_street_1, contributor_zip
                FROM   public.nc_boe_donations_raw
                WHERE  contributor_name IS NOT NULL
                  AND  contributor_name != ''
                LIMIT  2000000
                """
            )
        except psycopg2.Error:
            conn.rollback()
            cur.execute(
                """
                SELECT ctid::text, contributor_name, contributor_street_1, contributor_zip
                FROM   staging.fec_staging
                WHERE  contributor_name IS NOT NULL
                  AND  contributor_name != ''
                LIMIT  2000000
                """
            )

        for row in cur:
            row_id, raw_name, raw_addr, raw_zip = row
            last = _normalize_last_fec(raw_name or "")
            num = extract_street_number_v2(raw_addr or "")
            z5 = zip_left5(raw_zip or "")
            key = build_dedup_key(last, num, z5)
            if key is None:
                null_count += 1
                continue
            keys.setdefault(key, []).append(str(row_id))

    logger.info("FEC keys built: %d unique, %d nulls", len(keys), null_count)
    return keys, null_count


def _build_keys_datatrust(conn: psycopg2.extensions.connection) -> tuple[dict[str, list[str]], int]:
    """
    Pull DataTrust records and build Tier 1 keys.
    Prefers regaddressnumber column (pre-parsed by RNC).
    Falls back to extract_street_number_v2 on regaddress if regaddressnumber is blank.
    Returns ({dedup_key: [rnc_regid]}, null_count)
    """
    keys: dict[str, list[str]] = {}
    null_count = 0

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT rnc_regid::text, last_name, first_name,
                   regaddressnumber, regaddress, regzip5
            FROM   public.ncdatatrust
            WHERE  last_name IS NOT NULL
              AND  last_name != ''
            LIMIT  8000000
            """
        )
        for row in cur:
            reg_id, raw_last, _first, reg_addr_num, reg_addr, raw_zip = row
            last = _normalize_last_direct(raw_last or "")

            # Prefer regaddressnumber; fall back to parsing regaddress
            if reg_addr_num and str(reg_addr_num).strip():
                num = re.sub(r"\D", "", str(reg_addr_num).strip()) or ""
            else:
                num = extract_street_number_v2(reg_addr or "") or ""

            z5 = zip_left5(raw_zip or "")
            key = build_dedup_key(last, num, z5)
            if key is None:
                null_count += 1
                continue
            keys.setdefault(key, []).append(str(reg_id))

    logger.info("DataTrust keys built: %d unique, %d nulls", len(keys), null_count)
    return keys, null_count


# ---------------------------------------------------------------------------
# Insert matched pairs
# ---------------------------------------------------------------------------

def _insert_pairs(
    conn: psycopg2.extensions.connection,
    pairs: list[tuple[str, str, str, str, str]],
) -> int:
    """
    Insert cross-source match pairs.
    pairs: list of (dedup_key, source_a, row_id_a, source_b, row_id_b)
    Returns count of rows actually inserted (skips existing via ON CONFLICT DO NOTHING).
    """
    if not pairs:
        return 0

    inserted = 0
    with conn.cursor() as cur:
        for dedup_key, source_a, row_id_a, source_b, row_id_b in pairs:
            cur.execute(
                """
                INSERT INTO pipeline.cross_source_matches
                    (dedup_key, source_a, row_id_a, source_b, row_id_b, match_tier)
                VALUES (%s, %s, %s, %s, %s, 1)
                ON CONFLICT (source_a, row_id_a, source_b, row_id_b) DO NOTHING
                """,
                (dedup_key, source_a, row_id_a, source_b, row_id_b),
            )
            inserted += cur.rowcount

    return inserted


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def run_cross_source_match(
    sources: list[str] | None = None,
) -> CrossSourceMatchResult:
    """
    Run Tier 1 cross-source identity matching.

    Builds dedup keys for each active source, finds shared keys across sources,
    and inserts matched pairs into pipeline.cross_source_matches.

    Args:
        sources: Which sources to include. Default: ['ncboe', 'fec', 'datatrust'].
                 Pass a subset to run partial matching (e.g. ['ncboe', 'datatrust']).

    Returns:
        CrossSourceMatchResult with counts and summary.
    """
    active = set(sources or ["ncboe", "fec", "datatrust"])
    result = CrossSourceMatchResult(passed=True)

    init_pool()

    with get_connection() as conn:
        try:
            _ensure_cross_source_table(conn)

            source_keys: dict[str, dict[str, list[str]]] = {}
            total_nulls = 0

            if "ncboe" in active:
                k, n = _build_keys_ncboe(conn)
                source_keys["ncboe"] = k
                total_nulls += n

            if "fec" in active:
                k, n = _build_keys_fec(conn)
                source_keys["fec"] = k
                total_nulls += n

            if "datatrust" in active:
                k, n = _build_keys_datatrust(conn)
                source_keys["datatrust"] = k
                total_nulls += n

            result.dedup_key_null_count = total_nulls

            # Find keys present in 2+ sources
            source_names = list(source_keys.keys())
            pairs_to_insert: list[tuple[str, str, str, str, str]] = []

            for i, src_a in enumerate(source_names):
                for src_b in source_names[i + 1 :]:
                    keys_a = source_keys[src_a]
                    keys_b = source_keys[src_b]
                    shared = set(keys_a.keys()) & set(keys_b.keys())

                    logger.info(
                        "Shared keys %s <-> %s: %d", src_a, src_b, len(shared)
                    )

                    for key in shared:
                        for row_a in keys_a[key]:
                            for row_b in keys_b[key]:
                                pairs_to_insert.append(
                                    (key, src_a, row_a, src_b, row_b)
                                )

            result.pairs_inserted = _insert_pairs(conn, pairs_to_insert)
            conn.commit()

            # Log to identity_pass_log
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO pipeline.identity_pass_log
                        (pass_name, status, rows_matched, rows_remaining, last_run_at)
                    VALUES ('cross_source_tier1', 'completed', %s, %s, NOW())
                    ON CONFLICT (pass_name) DO UPDATE SET
                        status        = EXCLUDED.status,
                        rows_matched  = EXCLUDED.rows_matched,
                        rows_remaining = EXCLUDED.rows_remaining,
                        last_run_at   = NOW()
                    """,
                    (result.pairs_inserted, total_nulls),
                )
            conn.commit()

            result.summary = (
                f"Tier 1 cross-source match complete. "
                f"Sources: {', '.join(source_names)}. "
                f"Pairs inserted: {result.pairs_inserted}. "
                f"Null keys skipped: {total_nulls}. "
                f"Review pipeline.cross_source_matches for Tier 2 fuzzy pass."
            )
            logger.info(result.summary)

        except psycopg2.Error as e:
            result.passed = False
            result.summary = str(e)
            logger.exception("Cross-source match failed: %s", e)
            try:
                conn.rollback()
            except psycopg2.Error:
                pass
            raise

    return result


# ---------------------------------------------------------------------------
# CLI convenience
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    logging.basicConfig(level=logging.INFO, stream=sys.stdout)
    sources_arg = sys.argv[1:] if len(sys.argv) > 1 else None
    r = run_cross_source_match(sources=sources_arg)
    print(r.to_report())
    sys.exit(0 if r.passed else 1)
