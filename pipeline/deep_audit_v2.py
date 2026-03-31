#!/usr/bin/env python3
"""
deep_audit_v2.py — BroyhillGOP Pipeline Deep Audit

Extends audit_ncboe_status.py + schema_check.py + nc_boe_pre_handoff_check.py
with two major NEW sections:

  SECTION A — PARTY CONTAMINATION DETECTION
    Scans every dataset in the assembly line headed to the spine for:
      • Democratic party candidate/committee rows (should be 0 in GOP spine)
      • Independent / No-Party / Unaffiliated candidates
      • Green / Libertarian / Constitution / other minor party rows
      • Committee-type rows that map to non-GOP party flags
    Reports raw counts AND percentages for each dataset.

  SECTION B — COLUMN QUALITY AUDIT
    For each key assembly-line table checks for:
      • Street address voids (null/blank/junk city, street, zip)
      • Void RNC IDs
      • Void Voter IDs (voter_ncid / ncid)
      • Missing candidate-committee IDs
      • Deleted / soft-deleted records (is_deleted, status='deleted', etc.)
      • Merged data in single columns (comma/semicolon/pipe-fused values)
      • Bad schema matching (unexpected nulls in NOT NULL columns, wrong types)
      • Duplicate dedup keys
      • Future / impossible donation dates
      • Amount anomalies (zero, negative, unreasonably large)
      • Missing first/last name split (name in single field)
      • Phone number voids
      • Email voids
      • County voids
      • ZIP code format problems (not 5-digit numeric)
      • RNC score missing where voter_ncid is present
      • person_master linkage gaps (voter_ncid in donations with no spine row)

Usage:
  python3 pipeline/deep_audit_v2.py
  python3 pipeline/deep_audit_v2.py --table nc_boe_donations_raw
  python3 pipeline/deep_audit_v2.py --section party
  python3 pipeline/deep_audit_v2.py --section columns
  python3 pipeline/deep_audit_v2.py --section all   # default

Requires SUPABASE_DB_URL or DATABASE_URL in environment (or .env).
"""

from __future__ import annotations

import argparse
import os
import sys
from textwrap import dedent
from typing import Any

# ── try pipeline.db first, fall back to psycopg2 direct ──────────────────────
try:
    from pipeline.db import get_connection, init_pool
    _USE_PIPELINE_DB = True
except ImportError:
    import psycopg2
    import psycopg2.pool
    _USE_PIPELINE_DB = False

    _pool: Any = None

    def _get_dsn() -> str:
        dsn = (
            os.environ.get("SUPABASE_DB_URL")
            or os.environ.get("DATABASE_URL")
            or "postgresql://postgres:Anamaria@2026@@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres"
        )
        return dsn

    def init_pool() -> None:
        global _pool
        if _pool is None:
            _pool = psycopg2.pool.SimpleConnectionPool(1, 3, _get_dsn())

    from contextlib import contextmanager

    @contextmanager
    def get_connection():  # type: ignore[override]
        global _pool
        if _pool is None:
            init_pool()
        conn = _pool.getconn()
        try:
            yield conn
        finally:
            _pool.putconn(conn)


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _sep(title: str, width: int = 70) -> str:
    bar = "=" * width
    return f"\n{bar}\n  {title}\n{bar}"


def _subsep(title: str, width: int = 70) -> str:
    bar = "-" * width
    return f"\n{bar}\n  {title}\n{bar}"


def _pct(num: int, denom: int) -> str:
    if denom == 0:
        return "N/A"
    return f"{num / denom * 100:.2f}%"


def _run(cur: Any, sql: str, params: tuple = ()) -> list[tuple]:
    try:
        cur.execute(dedent(sql), params)
        return cur.fetchall()
    except Exception as exc:
        return [("ERROR", str(exc))]


def _table_exists(cur: Any, schema: str, table: str) -> bool:
    cur.execute(
        """
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = %s AND table_name = %s
        """,
        (schema, table),
    )
    return cur.fetchone() is not None


def _col_exists(cur: Any, schema: str, table: str, column: str) -> bool:
    cur.execute(
        """
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s AND column_name = %s
        """,
        (schema, table, column),
    )
    return cur.fetchone() is not None


# ─────────────────────────────────────────────────────────────────────────────
# SECTION A — PARTY CONTAMINATION DETECTION
# ─────────────────────────────────────────────────────────────────────────────

# Party codes / keywords that indicate non-GOP entries
PARTY_FLAGS = {
    "DEM":   ["'D'", "'DEM'", "'DEMOCRAT'", "'DEMOCRATIC'"],
    "IND":   ["'I'", "'IND'", "'INDEPENDENT'", "'UNA'", "'UNAFFILIATED'", "'NPA'", "'NO PARTY'"],
    "GRN":   ["'G'", "'GRN'", "'GREEN'"],
    "LIB":   ["'L'", "'LIB'", "'LIBERTARIAN'"],
    "CST":   ["'CST'", "'CONSTITUTION'"],
    "OTH":   ["'OTH'", "'OTHER'"],
}

# Which column holds party info in each table (schema.table → column)
PARTY_COL_MAP: dict[str, str] = {
    "public.nc_boe_donations_raw":       "party_cd",
    "public.person_master":              "party_cd",
    "public.nc_datatrust":               "party_cd",
    "public.rnc_voter_staging":          "party_cd",
    "public.rnc_voter_core":             "party_cd",
    "public.contacts":                   "party_cd",
    "public.nc_voters":                  "party_cd",
    "public.donor_contribution_map":     "party_flag",     # from committee_party_map join
    "public.committee_party_map":        "party_flag",
    "public.fec_party_committee_donations": "party_flag",
}

# Candidate/committee name keyword patterns for Democrat contamination
DEM_NAME_PATTERNS = [
    "'%DEMOCRAT%'",
    "'%DEMOCRATIC%'",
    "'%DNC%'",
    "'%DCCC%'",
    "'%DSCC%'",
    "'%PELOSI%'",
    "'%BIDEN%'",
    "'%OBAMA%'",
    "'%HILLARY%'",
    "'%CLINTON%'",
    "'%WARREN%'",
    "'%SANDERS%'",
    "'%WARNOCK%'",
    "'%BEASLEY%'",    # NC Democrat
    "'%COOPER%'",     # Roy Cooper NC
    "'%STEIN%'",      # Josh Stein NC
]


def _party_contamination_for_table(
    cur: Any,
    full_table: str,
    party_col: str,
) -> None:
    schema, tbl = full_table.split(".")

    if not _table_exists(cur, schema, tbl):
        print(f"  ⚠  Table {full_table} does not exist — skipping.")
        return
    if not _col_exists(cur, schema, tbl, party_col):
        print(f"  ⚠  Column {party_col} not found in {full_table} — skipping party-code scan.")
        _dem_name_scan(cur, full_table, schema, tbl)
        return

    # Total row count
    rows = _run(cur, f"SELECT count(*) FROM {full_table}")
    total = rows[0][0] if rows and rows[0][0] != "ERROR" else 0
    print(f"\n  Table: {full_table}  (total rows: {total:,})")

    # GOP / expected counts
    gop_sql = f"""
        SELECT count(*) FROM {full_table}
        WHERE upper(trim({party_col})) IN ('R','REP','REPUBLICAN','GOP')
    """
    gop_rows = _run(cur, gop_sql)
    gop_count = gop_rows[0][0] if gop_rows and gop_rows[0][0] != "ERROR" else "ERR"
    print(f"    GOP / Republican  : {gop_count:,}  ({_pct(gop_count, total)})" if isinstance(gop_count, int) else f"    GOP: {gop_count}")

    # Per-party contamination
    for label, vals in PARTY_FLAGS.items():
        in_clause = ", ".join(vals)
        sql = f"""
            SELECT count(*) FROM {full_table}
            WHERE upper(trim({party_col})) IN ({in_clause})
        """
        result = _run(cur, sql)
        cnt = result[0][0] if result and result[0][0] != "ERROR" else "ERR"
        flag = "🚨" if isinstance(cnt, int) and cnt > 0 else "  "
        print(f"  {flag}  {label:<5}: {cnt:,}  ({_pct(cnt, total)})" if isinstance(cnt, int) else f"    {label}: {cnt}")

    # Unknown / null party
    null_sql = f"""
        SELECT count(*) FROM {full_table}
        WHERE {party_col} IS NULL OR trim({party_col}) = ''
    """
    null_rows = _run(cur, null_sql)
    null_cnt = null_rows[0][0] if null_rows and null_rows[0][0] != "ERROR" else "ERR"
    flag = "⚠ " if isinstance(null_cnt, int) and null_cnt > 0 else "  "
    print(f"  {flag}  NULL/blank party: {null_cnt:,}  ({_pct(null_cnt, total)})" if isinstance(null_cnt, int) else f"    NULL: {null_cnt}")

    # Full distribution (top 20 party values)
    dist_sql = f"""
        SELECT upper(trim({party_col})) AS party_val, count(*) AS cnt
        FROM {full_table}
        GROUP BY 1
        ORDER BY 2 DESC
        LIMIT 20
    """
    dist_rows = _run(cur, dist_sql)
    print("    Party value distribution (top 20):")
    for r in dist_rows:
        if r[0] == "ERROR":
            print(f"      ERROR: {r[1]}")
        else:
            print(f"      {str(r[0]):<20} {r[1]:>10,}")

    # Name-based DEM scan
    _dem_name_scan(cur, full_table, schema, tbl)


def _dem_name_scan(cur: Any, full_table: str, schema: str, tbl: str) -> None:
    """Scan candidate/committee name columns for Democrat keywords."""
    name_cols_candidates = [
        "name", "candidate_name", "committee_name", "filing_committee_name",
        "contributor_name", "payee_name", "account_name",
    ]
    found_cols = [c for c in name_cols_candidates if _col_exists(cur, schema, tbl, c)]
    if not found_cols:
        return

    print(f"    Democrat name-keyword scan on columns: {found_cols}")
    for col in found_cols:
        pat_clause = " OR ".join(f"upper({col}) LIKE {p}" for p in DEM_NAME_PATTERNS)
        sql = f"SELECT count(*) FROM {full_table} WHERE {pat_clause}"
        result = _run(cur, sql)
        cnt = result[0][0] if result and result[0][0] != "ERROR" else "ERR"
        flag = "🚨" if isinstance(cnt, int) and cnt > 0 else "  "
        print(f"  {flag}  DEM name match in {col}: {cnt}")


def run_party_contamination(cur: Any) -> None:
    print(_sep("SECTION A — PARTY CONTAMINATION DETECTION"))
    print("""
  PURPOSE: Detect Democratic, Independent, Green, Libertarian, and other
  non-Republican party records that could pollute the GOP spine masterfile.
  Any non-zero DEM count in a spine-bound table is a CRITICAL data quality flag.
    """)

    for full_table, party_col in PARTY_COL_MAP.items():
        print(_subsep(f"  {full_table}"))
        _party_contamination_for_table(cur, full_table, party_col)

    # Special: committee_party_map NULL party_flag (fix_10 verification)
    print(_subsep("  committee_party_map — NULL party_flag (fix_10 check)"))
    rows = _run(cur, """
        SELECT count(*) FROM public.committee_party_map WHERE party_flag IS NULL
    """)
    null_cpm = rows[0][0] if rows and rows[0][0] != "ERROR" else "ERR"
    flag = "🚨" if isinstance(null_cpm, int) and null_cpm > 0 else "✅"
    print(f"  {flag}  NULL party_flag in committee_party_map: {null_cpm}")

    # FEC whitelist cross-check: any DEM committees in gop_fec_committee_whitelist?
    print(_subsep("  gop_fec_committee_whitelist — party_affiliation sanity"))
    if _table_exists(cur, "public", "gop_fec_committee_whitelist"):
        rows = _run(cur, """
            SELECT party_affiliation, count(*) FROM public.gop_fec_committee_whitelist
            GROUP BY 1 ORDER BY 2 DESC
        """)
        for r in rows:
            flag = "🚨" if r[0] and str(r[0]).upper() in ("DEM", "D", "DEMOCRAT") else "  "
            print(f"  {flag}  {r[0]}: {r[1]}")
    else:
        print("  ⚠  Table not found — skipping.")

    # nc_boe_donations_raw candidate name / committee DEM scan
    print(_subsep("  nc_boe_donations_raw — candidate/committee DEM name scan"))
    if _table_exists(cur, "public", "nc_boe_donations_raw"):
        for col in ["candidate_name", "committee_name", "account_name"]:
            if _col_exists(cur, "public", "nc_boe_donations_raw", col):
                pat_clause = " OR ".join(f"upper({col}) LIKE {p}" for p in DEM_NAME_PATTERNS)
                result = _run(cur, f"SELECT count(*) FROM public.nc_boe_donations_raw WHERE {pat_clause}")
                cnt = result[0][0] if result and result[0][0] != "ERROR" else "ERR"
                flag = "🚨" if isinstance(cnt, int) and cnt > 0 else "  "
                print(f"  {flag}  DEM name match in nc_boe_donations_raw.{col}: {cnt}")
    else:
        print("  ⚠  nc_boe_donations_raw not found — skipping.")

    # FEC candidate whitelist: check for non-R party affiliations
    print(_subsep("  gop_fec_candidate_whitelist — party sanity"))
    if _table_exists(cur, "public", "gop_fec_candidate_whitelist"):
        rows = _run(cur, """
            SELECT party_code, count(*) FROM public.gop_fec_candidate_whitelist
            GROUP BY 1 ORDER BY 2 DESC
        """)
        for r in rows:
            flag = "🚨" if r[0] and str(r[0]).upper() not in ("R", "REP", "REPUBLICAN", "GOP", "") else "  "
            print(f"  {flag}  party_code={r[0]}: {r[1]}")
    else:
        print("  ⚠  gop_fec_candidate_whitelist not found — skipping.")


# ─────────────────────────────────────────────────────────────────────────────
# SECTION B — COLUMN QUALITY AUDIT
# ─────────────────────────────────────────────────────────────────────────────

# Each table config: (schema_table, list_of_check_names)
# "all" means run every applicable check
AUDIT_TABLES: list[tuple[str, list[str]]] = [
    ("public.nc_boe_donations_raw",        ["all"]),
    ("public.person_master",               ["all"]),
    ("public.nc_datatrust",                ["all"]),
    ("public.rnc_voter_staging",           ["all"]),
    ("public.contacts",                    ["all"]),
    ("public.donor_contribution_map",      ["all"]),
    ("public.committee_party_map",         ["all"]),
    ("public.fec_party_committee_donations", ["all"]),
    ("public.person_source_links",         ["all"]),
    ("public.gop_fec_candidate_whitelist", ["all"]),
    ("public.gop_fec_committee_whitelist", ["all"]),
]


def _col_check(cur: Any, table: str, col: str, condition: str, label: str, total: int) -> None:
    """Run a single column quality check and print result."""
    schema, tbl = table.split(".")
    if not _col_exists(cur, schema, tbl, col):
        print(f"    ⚪  [{label}] column '{col}' not present — skipped")
        return
    sql = f"SELECT count(*) FROM {table} WHERE {condition}"
    result = _run(cur, sql)
    cnt = result[0][0] if result and result[0][0] != "ERROR" else "ERR"
    if cnt == "ERR":
        print(f"    ❓  [{label}] ERROR running check on {col}")
        return
    flag = "🚨" if cnt > 0 else "✅"
    pct_str = _pct(cnt, total)
    print(f"  {flag}  [{label}] {col}: {cnt:,} bad rows  ({pct_str})")


def _check_address_voids(cur: Any, table: str, total: int) -> None:
    """Street address, city, zip void checks."""
    addr_checks = [
        ("street_address",   "street_address IS NULL OR trim(street_address) = '' OR trim(street_address) IN ('N/A','UNKNOWN','NA','.')", "addr_void"),
        ("street_addr",      "street_addr IS NULL OR trim(street_addr) = ''",                                                              "addr_void"),
        ("address1",         "address1 IS NULL OR trim(address1) = ''",                                                                   "addr_void"),
        ("mailing_street_address_line_1", "mailing_street_address_line_1 IS NULL OR trim(mailing_street_address_line_1) = ''",            "addr_void"),
        ("city",             "city IS NULL OR trim(city) = ''",                                                                           "city_void"),
        ("city_name",        "city_name IS NULL OR trim(city_name) = ''",                                                                 "city_void"),
        ("zip_code",         "zip_code IS NULL OR trim(zip_code) = ''",                                                                   "zip_void"),
        ("zip",              "zip IS NULL OR trim(zip) = ''",                                                                             "zip_void"),
        ("norm_zip5",        "norm_zip5 IS NULL OR trim(norm_zip5) = '' OR trim(norm_zip5) NOT SIMILAR TO '[0-9]{5}'",                    "zip_format"),
        ("zip5",             "zip5 IS NULL OR trim(zip5) NOT SIMILAR TO '[0-9]{5}'",                                                      "zip_format"),
        ("zipcode",          "zipcode IS NULL OR length(trim(zipcode)) < 5",                                                              "zip_short"),
    ]
    for col, cond, label in addr_checks:
        _col_check(cur, table, col, cond, label, total)


def _check_rnc_ids(cur: Any, table: str, total: int) -> None:
    for col in ["rnc_regid", "rnc_id", "rncid", "rnc_voter_id"]:
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}::text) = ''", "void_rnc_id", total)


def _check_voter_ids(cur: Any, table: str, total: int) -> None:
    for col in ["voter_ncid", "ncid", "voter_id", "ncvoter_id"]:
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}::text) = ''", "void_voter_id", total)


def _check_candidate_committee_ids(cur: Any, table: str, total: int) -> None:
    for col in ["committee_id", "fec_committee_id", "candidate_id", "fec_candidate_id",
                "account_code", "filing_committee_id"]:
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}::text) = ''", "void_cmte_id", total)


def _check_deletes(cur: Any, table: str, total: int) -> None:
    for col, cond in [
        ("is_deleted",      "is_deleted = TRUE"),
        ("deleted_at",      "deleted_at IS NOT NULL"),
        ("status",          "lower(trim(status)) IN ('deleted','removed','inactive','dead','purged')"),
        ("record_type",     "lower(trim(record_type)) = 'delete'"),
        ("transaction_type","lower(trim(transaction_type)) IN ('delete','reversal','void','correction')"),
    ]:
        _col_check(cur, table, col, cond, "soft_delete", total)


def _check_merged_columns(cur: Any, table: str, total: int) -> None:
    """Detect columns where data was merged (comma/semicolon/pipe-fused)."""
    schema, tbl = table.split(".")
    # Get all text columns from the table
    cur.execute("""
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
          AND data_type IN ('text','character varying','varchar','character')
        ORDER BY ordinal_position
        LIMIT 40
    """, (schema, tbl))
    text_cols = [r[0] for r in cur.fetchall()]

    for col in text_cols:
        # Skip columns that are legitimately multi-value (notes, memo, description)
        if any(kw in col.lower() for kw in ["note", "memo", "desc", "comment", "narrative", "remark", "json"]):
            continue
        cond = (
            f"({col} LIKE '%,%,%' OR {col} LIKE '%;%;%' OR {col} LIKE '%|%|%') "
            f"AND {col} NOT ILIKE '%LLC%' AND {col} NOT ILIKE '%INC%' "
            f"AND {col} NOT ILIKE '%, NC%' AND {col} NOT ILIKE '%, NC %'"
        )
        _col_check(cur, table, col, cond, "merged_data", total)


def _check_schema_mismatch(cur: Any, table: str, total: int) -> None:
    """Check for unexpected nulls in columns that should be not-null based on pipeline expectations."""
    schema, tbl = table.split(".")
    # Fetch actual NOT NULL constraint columns
    cur.execute("""
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
          AND is_nullable = 'NO'
        ORDER BY ordinal_position
    """, (schema, tbl))
    nn_cols = [r[0] for r in cur.fetchall()]
    if not nn_cols:
        print("    ⚪  [schema_nn] No NOT NULL columns defined — skipped")
        return
    for col in nn_cols:
        # PK / system columns that are guaranteed non-null
        if col.lower() in ("id", "created_at", "updated_at"):
            continue
        _col_check(cur, table, col, f"{col} IS NULL", "unexpected_null", total)


def _check_dedup_keys(cur: Any, table: str, total: int) -> None:
    for col in ["dedup_key", "content_hash", "unique_key"]:
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}) = ''", "dedup_void", total)
    # Duplicate dedup_key check
    for col in ["dedup_key", "content_hash"]:
        schema, tbl = table.split(".")
        if not _col_exists(cur, schema, tbl, col):
            continue
        result = _run(cur, f"""
            SELECT count(*) FROM (
                SELECT {col} FROM {table}
                WHERE {col} IS NOT NULL
                GROUP BY {col} HAVING count(*) > 1
            ) dups
        """)
        cnt = result[0][0] if result and result[0][0] != "ERROR" else "ERR"
        if cnt == "ERR":
            print(f"    ❓  [dup_{col}] ERROR")
            continue
        flag = "🚨" if cnt > 0 else "✅"
        print(f"  {flag}  [dup_{col}] {cnt:,} duplicate {col} values")


def _check_dates(cur: Any, table: str, total: int) -> None:
    date_cols = ["date_occurred", "date_of_donation", "date_filed", "transaction_date",
                 "contribution_date", "created_at", "updated_at"]
    schema, tbl = table.split(".")
    for col in date_cols:
        if not _col_exists(cur, schema, tbl, col):
            continue
        # Future date
        _col_check(cur, table, col, f"{col} > CURRENT_DATE", "future_date", total)
        # Pre-1980 political donation (implausible)
        _col_check(cur, table, col, f"{col} < '1980-01-01'", "ancient_date", total)
        # NULL date
        _col_check(cur, table, col, f"{col} IS NULL", "null_date", total)


def _check_amounts(cur: Any, table: str, total: int) -> None:
    amount_cols = ["amount", "contribution_amount", "transaction_amount", "donation_amount"]
    schema, tbl = table.split(".")
    for col in amount_cols:
        if not _col_exists(cur, schema, tbl, col):
            continue
        _col_check(cur, table, col, f"{col} IS NULL", "null_amount", total)
        _col_check(cur, table, col, f"{col} = 0", "zero_amount", total)
        _col_check(cur, table, col, f"{col} < 0", "negative_amount", total)
        # Individual contributions > $5800 to a single candidate in a cycle are illegal (2024 limit)
        _col_check(cur, table, col, f"{col} > 5800", "large_indiv_amount", total)
        # Very large amounts (PAC/corporate noise in an Individual-only table)
        _col_check(cur, table, col, f"{col} > 100000", "massive_amount_flag", total)


def _check_name_fields(cur: Any, table: str, total: int) -> None:
    schema, tbl = table.split(".")
    # Single fused name column where first/last should be split
    for col in ["full_name", "name", "contributor_name", "donor_name"]:
        if not _col_exists(cur, schema, tbl, col):
            continue
        # Void names
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}) = ''", "null_name", total)
    # First/last split voids
    for col in ["first_name", "last_name"]:
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}) = ''", "name_split_void", total)


def _check_contact_voids(cur: Any, table: str, total: int) -> None:
    schema, tbl = table.split(".")
    for col in ["phone", "phone_number", "cell_phone", "mobile_phone", "home_phone"]:
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}) = '' OR length(regexp_replace({col},'[^0-9]','','g')) < 10", "phone_void", total)
    for col in ["email", "email_address", "primary_email"]:
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}) = '' OR {col} NOT LIKE '%@%'", "email_void", total)


def _check_county(cur: Any, table: str, total: int) -> None:
    for col in ["county", "county_desc", "county_id", "county_name"]:
        _col_check(cur, table, col, f"{col} IS NULL OR trim({col}::text) = ''", "county_void", total)


def _check_rnc_score_gap(cur: Any, table: str, total: int) -> None:
    """voter_ncid present but no score in rnc_scores_fresh."""
    schema, tbl = table.split(".")
    for voter_col in ["voter_ncid", "ncid"]:
        if not _col_exists(cur, schema, tbl, voter_col):
            continue
        if not _table_exists(cur, "public", "rnc_scores_fresh"):
            print("    ⚪  [rnc_score_gap] rnc_scores_fresh table not found — skipped")
            return
        result = _run(cur, f"""
            SELECT count(*) FROM {table} t
            WHERE t.{voter_col} IS NOT NULL
              AND NOT EXISTS (
                SELECT 1 FROM public.rnc_scores_fresh s
                WHERE s.voter_ncid = t.{voter_col}
              )
        """)
        cnt = result[0][0] if result and result[0][0] != "ERROR" else "ERR"
        if cnt == "ERR":
            print(f"    ❓  [rnc_score_gap] ERROR")
            continue
        flag = "⚠ " if isinstance(cnt, int) and cnt > 0 else "✅"
        pct_str = _pct(cnt, total)
        print(f"  {flag}  [rnc_score_gap] {voter_col} with no rnc_scores_fresh entry: {cnt:,}  ({pct_str})")


def _check_spine_linkage(cur: Any, table: str, total: int) -> None:
    """voter_ncid in this table with no matching row in person_master."""
    if table == "public.person_master":
        return  # skip self-check
    schema, tbl = table.split(".")
    if not _table_exists(cur, "public", "person_master"):
        print("    ⚪  [spine_gap] person_master not found — skipped")
        return
    for voter_col in ["voter_ncid", "ncid"]:
        if not _col_exists(cur, schema, tbl, voter_col):
            continue
        result = _run(cur, f"""
            SELECT count(*) FROM {table} t
            WHERE t.{voter_col} IS NOT NULL
              AND NOT EXISTS (
                SELECT 1 FROM public.person_master pm
                WHERE pm.voter_ncid = t.{voter_col}
              )
        """)
        cnt = result[0][0] if result and result[0][0] != "ERROR" else "ERR"
        if cnt == "ERR":
            print(f"    ❓  [spine_gap] ERROR on {voter_col}")
            continue
        flag = "⚠ " if isinstance(cnt, int) and cnt > 0 else "✅"
        pct_str = _pct(cnt, total)
        print(f"  {flag}  [spine_gap] {voter_col} with no person_master row: {cnt:,}  ({pct_str})")


def _check_transaction_type_distribution(cur: Any, table: str, total: int) -> None:
    """Full distribution of transaction_type to catch non-Individual types."""
    schema, tbl = table.split(".")
    for col in ["transaction_type", "report_type", "form_type"]:
        if not _col_exists(cur, schema, tbl, col):
            continue
        result = _run(cur, f"""
            SELECT coalesce({col}, 'NULL'), count(*) AS cnt
            FROM {table}
            GROUP BY 1 ORDER BY 2 DESC LIMIT 30
        """)
        print(f"\n    Transaction-type distribution ({table}.{col}):")
        for r in result:
            if r[0] == "ERROR":
                print(f"      ERROR: {r[1]}")
                continue
            not_indiv = str(r[0]).upper() not in ("INDIVIDUAL", "IND", "INDV", "INDIV", "I", "IC")
            flag = "🚨" if not_indiv and r[1] > 0 else "  "
            print(f"    {flag}  {str(r[0]):<30} {r[1]:>10,}")


def run_column_quality(cur: Any, target_table: str | None = None) -> None:
    print(_sep("SECTION B — COLUMN QUALITY AUDIT"))
    print("""
  CHECKS PER TABLE:
    address voids       — null/blank street, city, zip; bad zip format
    RNC ID voids        — rnc_regid / rnc_id / rncid null
    Voter ID voids      — voter_ncid / ncid null
    Committee ID voids  — committee_id / fec_committee_id / account_code null
    Soft deletes        — is_deleted, status='deleted', transaction_type='delete'
    Merged data         — comma/semicolon/pipe-fused text columns
    Schema mismatch     — NOT NULL columns containing nulls
    Dedup keys          — null dedup_key, duplicate dedup_key
    Date anomalies      — future dates, pre-1980 dates, null dates
    Amount anomalies    — null, zero, negative, >$5800 individual, >$100K
    Name field voids    — null full_name, missing first/last split
    Contact voids       — phone (<10 digits), email (no @)
    County voids        — county/county_desc null
    RNC score gap       — voter_ncid exists but no rnc_scores_fresh row
    Spine linkage gap   — voter_ncid exists but no person_master row
    Transaction type    — full distribution to catch non-Individual types
    """)

    tables = [(t, checks) for t, checks in AUDIT_TABLES
              if target_table is None or t == target_table]

    for table, _ in tables:
        schema, tbl = table.split(".")
        print(_subsep(f"  {table}"))

        if not _table_exists(cur, schema, tbl):
            print(f"  ⚪  Table {table} does not exist — skipping all checks.")
            continue

        # Total row count
        cnt_result = _run(cur, f"SELECT count(*) FROM {table}")
        total = cnt_result[0][0] if cnt_result and cnt_result[0][0] != "ERROR" else 0
        print(f"  Total rows: {total:,}\n")

        if total == 0:
            print("  ⚠  Table is EMPTY — all checks will return 0.")

        _check_address_voids(cur, table, total)
        _check_rnc_ids(cur, table, total)
        _check_voter_ids(cur, table, total)
        _check_candidate_committee_ids(cur, table, total)
        _check_deletes(cur, table, total)
        _check_dedup_keys(cur, table, total)
        _check_dates(cur, table, total)
        _check_amounts(cur, table, total)
        _check_name_fields(cur, table, total)
        _check_contact_voids(cur, table, total)
        _check_county(cur, table, total)
        _check_rnc_score_gap(cur, table, total)
        _check_spine_linkage(cur, table, total)
        _check_transaction_type_distribution(cur, table, total)
        _check_schema_mismatch(cur, table, total)
        # Merged-column check is intentionally last (table scan, slower)
        _check_merged_columns(cur, table, total)


# ─────────────────────────────────────────────────────────────────────────────
# SECTION C — INHERITED BASIC PIPELINE STATUS (from audit_ncboe_status.py)
# ─────────────────────────────────────────────────────────────────────────────

BASIC_QUERIES = [
    ("nc_boe_donations_raw — counts", """
        SELECT
            count(*) AS total,
            count(*) FILTER (WHERE transaction_type = 'Individual') AS individual,
            count(*) FILTER (WHERE voter_ncid IS NOT NULL) AS with_voter_ncid,
            count(*) FILTER (WHERE content_hash IS NOT NULL) AS with_content_hash,
            count(*) FILTER (WHERE dedup_key IS NOT NULL) AS with_dedup_key
        FROM public.nc_boe_donations_raw
    """),
    ("identity_clusters (nc_boe)", """
        SELECT count(*) AS clusters,
               coalesce(sum(member_count), 0) AS total_members,
               count(*) FILTER (WHERE status = 'pending_review') AS pending
        FROM pipeline.identity_clusters
        WHERE source_system = 'nc_boe'
    """),
    ("identity_pass_log (recent)", """
        SELECT pass_name, status, rows_matched, rows_remaining, last_run_at
        FROM pipeline.identity_pass_log
        WHERE pass_name LIKE '%nc_boe%' OR pass_name LIKE '%dedup%'
        ORDER BY last_run_at DESC
        LIMIT 10
    """),
    ("staging.ncboe_archive", """
        SELECT count(*) AS archived FROM staging.ncboe_archive
    """),
    ("core.ncboe_committee_registry", """
        SELECT count(*) AS committees FROM core.ncboe_committee_registry
    """),
    ("donor_contribution_map — row count", """
        SELECT count(*) FROM public.donor_contribution_map
    """),
    ("fec_party_committee_donations — row count", """
        SELECT count(*) FROM public.fec_party_committee_donations
    """),
    ("committee_party_map — party_flag distribution", """
        SELECT party_flag, count(*) AS cnt
        FROM public.committee_party_map
        GROUP BY 1 ORDER BY 2 DESC
    """),
]


def run_basic_pipeline(cur: Any) -> None:
    print(_sep("SECTION C — BASIC PIPELINE STATUS"))
    for name, sql in BASIC_QUERIES:
        print(_subsep(f"  {name}"))
        rows = _run(cur, sql)
        if not rows:
            print("  (no rows)")
            continue
        try:
            cols = [d[0] for d in cur.description] if cur.description else []
        except Exception:
            cols = []
        for row in rows:
            if row[0] == "ERROR":
                print(f"  ERROR: {row[1]}")
            elif cols:
                print("  " + " | ".join(f"{c}: {v}" for c, v in zip(cols, row)))
            else:
                print(f"  {row}")


# ─────────────────────────────────────────────────────────────────────────────
# SECTION D — NCBOE RELOAD READINESS (is the target 338K row count met?)
# ─────────────────────────────────────────────────────────────────────────────

def run_reload_readiness(cur: Any) -> None:
    print(_sep("SECTION D — NCBOE RELOAD READINESS"))
    print("""
  Target after clean reload: 338,223 rows (95,967 + 242,256), 100% Individual.
  Current state check:
    """)
    result = _run(cur, """
        SELECT
            count(*) AS total_rows,
            count(*) FILTER (WHERE transaction_type = 'Individual') AS individual_rows,
            count(*) FILTER (WHERE transaction_type != 'Individual') AS non_individual_rows,
            count(*) FILTER (WHERE transaction_type IS NULL)         AS null_type_rows,
            min(date_occurred) AS earliest_date,
            max(date_occurred) AS latest_date
        FROM public.nc_boe_donations_raw
    """)
    if result and result[0][0] != "ERROR":
        r = result[0]
        total = r[0]
        indiv = r[1]
        non_indiv = r[2]
        null_type = r[3]
        print(f"  Total rows       : {total:,}  (target: 338,223)")
        print(f"  Individual rows  : {indiv:,}  ({_pct(indiv, total)})")
        print(f"  Non-Individual   : {non_indiv:,}  ({_pct(non_indiv, total)})  🚨 must be 0")
        print(f"  NULL type rows   : {null_type:,}  ({_pct(null_type, total)})  ⚠ check for noise")
        print(f"  Date range       : {r[4]} → {r[5]}")
        if total == 338223 and non_indiv == 0:
            print("\n  ✅  RELOAD COMPLETE — 338,223 Individual rows loaded correctly.")
        elif total == 282096:
            print("\n  🚨  WRONG FILES STILL LOADED — 282,096 rows (old mixed-type load).")
            print("      Run reload with 2015-2019-ncboe.csv + 2020-2026-ncboe.csv.")
        else:
            print(f"\n  ⚠   Unexpected row count ({total:,}) — verify reload status.")
    else:
        print(f"  ERROR: {result}")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="BroyhillGOP Deep Audit v2 — Party Contamination + Column Quality"
    )
    parser.add_argument(
        "--section",
        choices=["all", "party", "columns", "basic", "reload"],
        default="all",
        help="Which section(s) to run (default: all)",
    )
    parser.add_argument(
        "--table",
        default=None,
        help="Limit column quality audit to one table (schema.table format, e.g. public.nc_boe_donations_raw)",
    )
    args = parser.parse_args()

    init_pool()

    print(_sep("BROYHILLGOP DEEP AUDIT v2", 70))
    print(f"  Run all sections: {args.section}")
    if args.table:
        print(f"  Column audit limited to: {args.table}")
    print()

    with get_connection() as conn:
        with conn.cursor() as cur:
            run_section = args.section

            if run_section in ("all", "basic"):
                run_basic_pipeline(cur)

            if run_section in ("all", "reload"):
                run_reload_readiness(cur)

            if run_section in ("all", "party"):
                run_party_contamination(cur)

            if run_section in ("all", "columns"):
                run_column_quality(cur, target_table=args.table)

    print(_sep("AUDIT COMPLETE", 70))
    return 0


if __name__ == "__main__":
    sys.exit(main())
