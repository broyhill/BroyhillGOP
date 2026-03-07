#!/usr/bin/env python3
"""
FEC Filter Pipeline — Merge and filter staging tables into fec_god_contributions.

Merges fec_2015_2016_a_staging and fec_2015_2016_b_staging with schema normalization,
then filters to Republican-only, NC-relevant donations and writes to fec_god_contributions.

Steps:
  1. Schema normalization: cast contribution_receipt_date to DATE, contribution_receipt_amount to NUMERIC; UNION ALL.
  2. Party filter: keep only rows where committee_id → fec_committee_candidate_lookup → fec_candidates (party='REP')
                  or committee_id → fec_committees (party='REP'); remove DEM, IND, LIB, GRE.
  3. Office/geography: keep Presidential (P) and NC House/Senate (candidate_office_state='NC'); drop out-of-state H/S.
  4. Write to fec_god_contributions (78 columns + source_table + id BIGSERIAL PRIMARY KEY).

Connection: SUPABASE_DATABASE_URL or DATABASE_URL (direct Postgres).
"""

import os
import sys
import argparse
from typing import List, Tuple, Optional

try:
    import psycopg2
    from psycopg2 import sql
except ImportError:
    print("Install psycopg2: pip install psycopg2-binary", file=sys.stderr)
    sys.exit(1)

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------
SOURCE_TABLES = [
    ("fec_2015_2016_a_staging", "fec_2015_2016_a_staging"),
    ("fec_2015_2016_b_staging", "fec_2015_2016_b_staging"),
]
TARGET_TABLE = "fec_god_contributions"
LOOKUP_TABLE = "fec_committee_candidate_lookup"
CANDIDATES_TABLE = "fec_candidates"
COMMITTEES_TABLE = "fec_committees"

# Columns that need type normalization between staging A and B
DATE_COL = "contribution_receipt_date"
AMOUNT_COL = "contribution_receipt_amount"


def get_connection():
    url = os.environ.get("SUPABASE_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not url:
        print("Set SUPABASE_DATABASE_URL or DATABASE_URL (Postgres connection string).", file=sys.stderr)
        sys.exit(1)
    return psycopg2.connect(url)


def fetch_columns(conn, table_name: str) -> List[Tuple[str, str]]:
    """Return (column_name, data_type) ordered by ordinal_position."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = %s
            ORDER BY ordinal_position
        """, (table_name,))
        return cur.fetchall()


def assert_schemas_match(cols_a: List[Tuple[str, str]], cols_b: List[Tuple[str, str]], table_a: str, table_b: str):
    """Ensure both tables have the same column names in the same order."""
    names_a = [c[0] for c in cols_a]
    names_b = [c[0] for c in cols_b]
    if names_a != names_b:
        missing_in_b = set(names_a) - set(names_b)
        missing_in_a = set(names_b) - set(names_a)
        err = []
        if missing_in_b:
            err.append(f"Columns in {table_a} but not in {table_b}: {sorted(missing_in_b)}")
        if missing_in_a:
            err.append(f"Columns in {table_b} but not in {table_a}: {sorted(missing_in_a)}")
        raise SystemExit("Schema mismatch: " + "; ".join(err))


def cast_expr(column_name: str, data_type: str, date_col: str, amount_col: str) -> str:
    """Return SQL expression for this column with normalization for date/amount."""
    if column_name == date_col:
        if data_type in ("timestamp with time zone", "timestamptz"):
            return f"(s.\"{column_name}\"::timestamptz AT TIME ZONE 'UTC')::date"
        return f"(s.\"{column_name}\"::text)::date"
    if column_name == amount_col:
        if data_type in ("double precision", "real"):
            return f"s.\"{column_name}\"::numeric"
        return f"(s.\"{column_name}\"::text)::numeric"
    return f"s.\"{column_name}\""


def pg_type_for_target(column_name: str, data_type: str, date_col: str, amount_col: str) -> str:
    """Postgres type for the target table (normalized)."""
    if column_name == date_col:
        return "DATE"
    if column_name == amount_col:
        return "NUMERIC"
    if data_type in ("bigint", "integer", "smallint"):
        return "BIGINT"
    if data_type in ("timestamp with time zone", "timestamptz"):
        return "TIMESTAMPTZ"
    if data_type in ("numeric", "decimal"):
        return "NUMERIC"
    if data_type in ("double precision", "real"):
        return "NUMERIC"
    return "TEXT"


def build_normalized_select(
    columns: List[Tuple[str, str]],
    source_table: str,
    source_alias: str,
    date_col: str,
    amount_col: str,
) -> str:
    """Build SELECT with normalized date and amount, plus source_table literal."""
    selects = [
        cast_expr(name, dt, date_col, amount_col) + f' AS "{name}"'
        for name, dt in columns
    ]
    selects.append(f"'{source_table}'::text AS source_table")
    return "SELECT " + ", ".join(selects) + f" FROM public.{source_table} s"


def build_create_table_sql(
    columns: List[Tuple[str, str]],
    target: str,
    date_col: str,
    amount_col: str,
) -> str:
    """CREATE TABLE with id BIGSERIAL PRIMARY KEY, then 78 cols (normalized types), then source_table."""
    col_defs = ["id BIGSERIAL PRIMARY KEY"]
    for name, dt in columns:
        col_defs.append(f'"{name}" {pg_type_for_target(name, dt, date_col, amount_col)}')
    col_defs.append("source_table TEXT")
    return f"CREATE TABLE IF NOT EXISTS public.{target} (\n  " + ",\n  ".join(col_defs) + "\n);"


def main():
    parser = argparse.ArgumentParser(description="FEC filter pipeline → fec_god_contributions")
    parser.add_argument("--dry-run", action="store_true", help="Print SQL and counts only; do not create/insert")
    parser.add_argument("--yes", action="store_true", help="Skip confirmation before TRUNCATE (non-dry-run)")
    args = parser.parse_args()

    conn = get_connection()
    conn.autocommit = False

    try:
        # --- 1. Schema from both staging tables ---
        table_a, table_b = SOURCE_TABLES[0][0], SOURCE_TABLES[1][0]
        cols_a = fetch_columns(conn, table_a)
        cols_b = fetch_columns(conn, table_b)
        if not cols_a or not cols_b:
            print(f"Missing table or empty schema: {table_a} or {table_b}", file=sys.stderr)
            sys.exit(1)
        assert_schemas_match(cols_a, cols_b, table_a, table_b)
        columns = cols_a  # same order and names
        print(f"Schema: {len(columns)} columns (match verified for both staging tables)")

        # --- 2. Build normalized UNION ALL ---
        union_parts = []
        for src, src_label in SOURCE_TABLES:
            # Re-fetch types for this table (in case A and B differ by type for same column name)
            col_info = fetch_columns(conn, src)
            union_parts.append(
                build_normalized_select(col_info, src, "s", DATE_COL, AMOUNT_COL)
            )
        union_sql = " (\n  " + "\n  UNION ALL\n  ".join(union_parts) + "\n) AS u"

        # --- 3. Party and office filters (join to lookup + candidates + committees) ---
        # Party: keep only REP (via candidate or committee). Exclude DEM, IND, LIB, GRE.
        # Office: keep P (all); keep H/S only when candidate_office_state = 'NC'
        join_clause = f"""
LEFT JOIN public.{LOOKUP_TABLE} l ON l.committee_id = u.committee_id
LEFT JOIN public.{CANDIDATES_TABLE} c ON c.candidate_id = l.candidate_id
LEFT JOIN public.{COMMITTEES_TABLE} fc ON fc.committee_id = u.committee_id
"""
        where_clause = """
WHERE (
  (c.party = 'REP' OR fc.party = 'REP')
  AND (c.party IS NULL OR c.party NOT IN ('DEM','IND','LIB','GRE'))
  AND (fc.party IS NULL OR fc.party NOT IN ('DEM','IND','LIB','GRE'))
)
AND (
  (u.candidate_office = 'P')
  OR (u.candidate_office IN ('H', 'S') AND u.candidate_office_state = 'NC')
)
"""

        # --- 4. Full SELECT for insert (all columns + source_table from u) ---
        col_list = ", ".join(f'u."{c[0]}"' for c in columns)
        col_list += ", u.source_table"
        insert_select_sql = f"""
INSERT INTO public.{TARGET_TABLE} ({", ".join(f'"{c[0]}"' for c in columns)}, source_table)
SELECT {col_list}
FROM {union_sql}
{join_clause}
{where_clause}
"""

        if args.dry_run:
            print("\n--- Normalized UNION (first 200 chars per part) ---")
            for i, part in enumerate(union_parts):
                print(part[:200] + "...")
            print("\n--- Count: union total ---")
            with conn.cursor() as cur:
                cur.execute(f"SELECT COUNT(*) FROM {union_sql}")
                n_union = cur.fetchone()[0]
            print(f"  Union total: {n_union}")
            print("\n--- Count: after party + office filter ---")
            with conn.cursor() as cur:
                cur.execute(f"SELECT COUNT(*) FROM {union_sql} {join_clause} {where_clause}")
                n_filtered = cur.fetchone()[0]
            print(f"  Filtered: {n_filtered}")
            conn.rollback()
            return

        # --- 5. Create target table if not exists ---
        create_sql = build_create_table_sql(columns, TARGET_TABLE, DATE_COL, AMOUNT_COL)
        with conn.cursor() as cur:
            cur.execute(create_sql)
        print(f"Created/verified table: {TARGET_TABLE}")

        # --- 6. Truncate (idempotent re-run) ---
        if not args.yes:
            confirm = input(f"Truncate {TARGET_TABLE} and insert filtered rows? [y/N]: ")
            if confirm.strip().lower() != "y":
                conn.rollback()
                print("Aborted.")
                return
        with conn.cursor() as cur:
            cur.execute(f"TRUNCATE TABLE public.{TARGET_TABLE} RESTART IDENTITY")
        print(f"Truncated {TARGET_TABLE}")

        # --- 7. Insert filtered rows ---
        with conn.cursor() as cur:
            cur.execute(insert_select_sql)
            inserted = cur.rowcount  # may be -1 for INSERT...SELECT; use count below
        conn.commit()
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM public.{TARGET_TABLE}")
            inserted = cur.fetchone()[0]
        print(f"Done. Total rows in {TARGET_TABLE}: {inserted}")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}", file=sys.stderr)
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
