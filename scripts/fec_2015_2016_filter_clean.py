#!/usr/bin/env python3
"""
FEC 2015-2016 Staging Data — Filter & Clean Pipeline

Connects to Supabase, reads fec_2015_2016_a_staging and fec_2015_2016_b_staging,
filters to NC Republican–relevant donations, and writes to fec_2015_2016_cleaned.

Usage:
  Set SUPABASE_DATABASE_URL or DATABASE_URL (direct Postgres connection string).
  Then: python scripts/fec_2015_2016_filter_clean.py

  Optional: --dry-run to only report row counts and schema, no INSERT.
"""

import os
import sys
import argparse
from typing import List, Tuple

try:
    import psycopg2
    from psycopg2.extras import execute_batch
except ImportError:
    print("Install psycopg2: pip install psycopg2-binary", file=sys.stderr)
    sys.exit(1)

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------
DEFAULT_BATCH_SIZE = 5000
SOURCE_TABLES = ["fec_2015_2016_a_staging", "fec_2015_2016_b_staging"]
TARGET_TABLE = "fec_2015_2016_cleaned"

def get_connection():
    url = os.environ.get("SUPABASE_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not url:
        print("Set SUPABASE_DATABASE_URL or DATABASE_URL (Postgres connection string).", file=sys.stderr)
        sys.exit(1)
    return psycopg2.connect(url)


def fetch_table_columns(conn, table_name: str) -> List[Tuple[str, str]]:
    """Return (column_name, data_type) for table, ordered by ordinal_position."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = %s
            ORDER BY ordinal_position
        """, (table_name,))
        return cur.fetchall()


def build_create_table_sql(columns: List[Tuple[str, str]], target: str) -> str:
    """Build CREATE TABLE target (col1 type, col2 type, ...). Uses TEXT for simplicity for FEC staging."""
    # Map to safe Postgres types; FEC staging is mostly text/bigint/timestamptz
    def pg_type(data_type: str) -> str:
        if data_type in ("bigint", "integer", "smallint"):
            return "BIGINT"
        if data_type in ("timestamp with time zone", "timestamptz"):
            return "TIMESTAMPTZ"
        if data_type in ("numeric", "decimal"):
            return "NUMERIC"
        return "TEXT"

    col_defs = [f'"{name}" {pg_type(dt)}' for name, dt in columns]
    return f'CREATE TABLE IF NOT EXISTS public.{target} (\n  ' + ",\n  ".join(col_defs) + "\n);"


def build_where_clause() -> str:
    """
    WHERE clause for NC Republican–relevant donations.
    - Individual contributions: is_individual = 'Y' or entity_type_desc individual.
    - NC link: contributor_state = 'NC' OR candidate_office_state = 'NC'.
    - Exclude empty contributor_last_name and contribution_receipt_amount.
    """
    return " AND ".join([
        "contributor_last_name IS NOT NULL AND TRIM(contributor_last_name) <> ''",
        "contribution_receipt_amount IS NOT NULL AND TRIM(contribution_receipt_amount) <> ''",
        "( contributor_state = 'NC' OR candidate_office_state = 'NC' )",
        "( UPPER(COALESCE(is_individual, '')) = 'Y' OR UPPER(COALESCE(entity_type_desc, '')) LIKE '%INDIVIDUAL%' OR entity_type IS NULL OR (entity_type_desc IS NULL AND is_individual IS NULL) )",
    ])


def build_filter_sql(columns: List[Tuple[str, str]], source: str) -> str:
    """Full SELECT for filtered rows from source table."""
    col_list = ", ".join(f'"{c[0]}"' for c in columns)
    return f"SELECT {col_list} FROM public.{source} WHERE {build_where_clause()}"


def main():
    parser = argparse.ArgumentParser(description="Filter FEC 2015-2016 staging into fec_2015_2016_cleaned")
    parser.add_argument("--dry-run", action="store_true", help="Only report schema and counts, no create/insert")
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE, help="Rows per batch")
    args = parser.parse_args()

    conn = get_connection()
    conn.autocommit = False

    try:
        # 1) Schema from first staging table
        columns = fetch_table_columns(conn, SOURCE_TABLES[0])
        if not columns:
            print(f"Table {SOURCE_TABLES[0]} not found or empty schema.", file=sys.stderr)
            sys.exit(1)
        print(f"Schema: {len(columns)} columns from {SOURCE_TABLES[0]}")

        if args.dry_run:
            for name, dt in columns:
                print(f"  {name} ({dt})")
            where = build_where_clause()
            total_kept = 0
            for src in SOURCE_TABLES:
                with conn.cursor() as cur:
                    cur.execute(f"SELECT COUNT(*) FROM public.{src} WHERE {where}")
                    n = cur.fetchone()[0]
                print(f"  {src} rows passing filter: {n}")
                total_kept += n
            print(f"  Total that would be written to {TARGET_TABLE}: {total_kept}")
            conn.rollback()
            return

        # 2) Create target table
        create_sql = build_create_table_sql(columns, TARGET_TABLE)
        with conn.cursor() as cur:
            cur.execute(create_sql)
        print(f"Created/verified table: {TARGET_TABLE}")

        # 3) Truncate target (idempotent re-run)
        with conn.cursor() as cur:
            cur.execute(f"TRUNCATE TABLE public.{TARGET_TABLE}")
        print(f"Truncated {TARGET_TABLE}")

        # 4) Batch copy from each source
        col_list = ", ".join(f'"{c[0]}"' for c in columns)
        placeholders = ", ".join("%s" for _ in columns)
        insert_sql = f'INSERT INTO public.{TARGET_TABLE} ({col_list}) VALUES ({placeholders})'
        total_inserted = 0

        for src in SOURCE_TABLES:
            select_sql = build_filter_sql(columns, src)
            with conn.cursor(name="fetch_fec") as cur:
                cur.itersize = args.batch_size
                cur.execute(select_sql)
                batch = cur.fetchmany(args.batch_size)
                while batch:
                    with conn.cursor() as ins_cur:
                        execute_batch(ins_cur, insert_sql, batch, page_size=args.batch_size)
                    total_inserted += len(batch)
                    print(f"  {src}: inserted {total_inserted} rows so far...")
                    batch = cur.fetchmany(args.batch_size)

        conn.commit()
        print(f"Done. Total rows in {TARGET_TABLE}: {total_inserted}")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
