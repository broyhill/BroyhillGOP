#!/usr/bin/env python3
"""
Run FEC 2015_2016 seed against the database using pipeline/db.py.

Executes each statement via the connection pool (no psql). Verifies
dmetaphone works after CREATE EXTENSION.

Usage:
  Set SUPABASE_DB_URL or DATABASE_URL in .env.
  python -m pipeline.run_seed

Or: python pipeline/run_seed.py
"""

from __future__ import annotations

import sys
from pathlib import Path

# Add project root for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pipeline.db import get_connection, init_pool


def _execute(conn, sql: str, *, optional: bool = False) -> None:
    """Execute SQL; raise unless optional=True and error is benign."""
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
    except Exception as e:
        if optional:
            return
        raise RuntimeError(f"Seed statement failed: {e}\nSQL: {sql[:200]}...")


def main() -> int:
    try:
        init_pool()
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 1

    with get_connection() as conn:
        conn.autocommit = True
        try:
            # 1. Ensure fuzzystrmatch
            _execute(conn, "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch")

            # 2. Verify dmetaphone works (Supabase may block extensions)
            with conn.cursor() as cur:
                cur.execute("SELECT dmetaphone('test')")
                row = cur.fetchone()
                if not row or not row[0]:
                    raise RuntimeError("dmetaphone('test') returned NULL; fuzzystrmatch may be disabled on this host")
            print("dmetaphone verified OK")

            # 3. Source quality rules (6 rules)
            # rule_sql_condition: {staging_table} replaced by ingest
            # Use param placeholders for values with embedded quotes
            with conn.cursor() as cur:
                rules = [
                    ("require_committee_id", "SELECT COUNT(*) FROM {staging_table} WHERE committee_id IS NULL OR TRIM(COALESCE(committee_id::TEXT, '')) = ''", "fatal", "committee_id required (critical join key)"),
                    ("require_contributor_last_name", "SELECT COUNT(*) FROM {staging_table} WHERE contributor_last_name IS NULL OR TRIM(COALESCE(contributor_last_name, '')) = ''", "fatal", "contributor_last_name required (for dedup)"),
                    ("require_contribution_amount", "SELECT COUNT(*) FROM {staging_table} WHERE contribution_receipt_amount IS NULL OR contribution_receipt_amount::TEXT = ''", "fatal", "contribution_receipt_amount required"),
                    ("require_contributor_zip", "SELECT COUNT(*) FROM {staging_table} WHERE contributor_zip IS NULL OR TRIM(COALESCE(contributor_zip, '')) = ''", "fatal", "contributor_zip required"),
                    ("require_contributor_state", "SELECT COUNT(*) FROM {staging_table} WHERE contributor_state IS NULL OR TRIM(COALESCE(contributor_state, '')) = ''", "fatal", "contributor_state required to verify NC filter"),
                    ("require_entity_type", "SELECT COUNT(*) FROM {staging_table} WHERE entity_type IS NULL AND entity_type_desc IS NULL", "warn", "entity_type or entity_type_desc recommended for filtering"),
                ]
                for rule_name, cond, severity, desc in rules:
                    cur.execute(
                        """
                        INSERT INTO pipeline.source_quality_rules
                          (source_system, rule_name, rule_sql_condition, severity, description)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (source_system, rule_name) DO UPDATE SET
                          rule_sql_condition = EXCLUDED.rule_sql_condition,
                          severity = EXCLUDED.severity,
                          description = EXCLUDED.description
                        """,
                        ("fec", rule_name, cond, severity, desc),
                    )

            # 4. Norm readiness rules (tight thresholds: 99% to match actual data)
            _execute(
                conn,
                """
                INSERT INTO pipeline.norm_readiness_rules
                  (source_system, column_name, min_non_null_pct, notes)
                VALUES
                  ('fec', 'contributor_last_name', 99.5, 'Last name for dedup/match (actual data ~99.93%%)'),
                  ('fec', 'contributor_zip', 99, 'Zip for dedup/match'),
                  ('fec', 'contribution_receipt_amount', 99, 'Amount required for totals')
                ON CONFLICT (source_system, column_name) DO UPDATE SET
                  min_non_null_pct = EXCLUDED.min_non_null_pct,
                  notes = EXCLUDED.notes
                """,
            )

            # 5. Dedup rules
            _execute(
                conn,
                """
                INSERT INTO pipeline.dedup_rules
                  (source_system, dedup_function_name, notes)
                VALUES
                  ('fec', 'fec_last_zip_first_dmetaphone',
                   '{"weights": {"exact": 1.0, "fuzzy": 0.85}, "columns": {"last_name": "contributor_last_name", "zip": "contributor_zip", "first_name": "contributor_first_name"}}')
                ON CONFLICT (source_system) DO UPDATE SET
                  dedup_function_name = EXCLUDED.dedup_function_name,
                  notes = EXCLUDED.notes
                """,
            )

            # 6. Audit columns on staging table (Master Plan 4.7 — mandatory)
            _execute(
                conn,
                "ALTER TABLE public.fec_2015_2016_a_staging ADD COLUMN IF NOT EXISTS _job_id UUID"
            )
            _execute(
                conn,
                "ALTER TABLE public.fec_2015_2016_a_staging ADD COLUMN IF NOT EXISTS _batch_number INT"
            )
            _execute(
                conn,
                "ALTER TABLE public.fec_2015_2016_a_staging ADD COLUMN IF NOT EXISTS _loaded_at TIMESTAMPTZ"
            )
            _execute(
                conn,
                "ALTER TABLE public.fec_2015_2016_a_staging ADD COLUMN IF NOT EXISTS _file_hash TEXT"
            )

            # 7. Expected indexes (2015_2016 only; add rows for other cycles when loading)
            _execute(
                conn,
                "ALTER TABLE pipeline.expected_indexes ADD COLUMN IF NOT EXISTS index_definition TEXT"
            )
            _execute(
                conn,
                """
                INSERT INTO pipeline.expected_indexes
                  (table_name, index_name, index_definition)
                VALUES
                  ('public.fec_2015_2016_a_staging', 'idx_fec_contrib_last_zip',
                   'CREATE INDEX IF NOT EXISTS idx_fec_contrib_last_zip ON public.fec_2015_2016_a_staging (contributor_last_name, contributor_zip)'),
                  ('public.fec_2015_2016_a_staging', 'idx_fec_contrib_first',
                   'CREATE INDEX IF NOT EXISTS idx_fec_contrib_first ON public.fec_2015_2016_a_staging (contributor_first_name)')
                ON CONFLICT (table_name, index_name) DO UPDATE SET
                  index_definition = EXCLUDED.index_definition
                """,
            )

            # 8. Identity clusters (dedup writes here; not in pipeline_ddl.sql)
            # Full schema per Master Plan §7: cluster linkage, status; person_id
            # filled later by identity passes (core.create_person_from_norm, etc.).
            _execute(
                conn,
                """
                CREATE TABLE IF NOT EXISTS pipeline.identity_clusters (
                    cluster_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    source_system TEXT NOT NULL,
                    staging_schema TEXT NOT NULL,
                    staging_table TEXT NOT NULL,
                    cluster_key TEXT NOT NULL,
                    member_count INT NOT NULL,
                    member_refs JSONB,
                    match_score_avg NUMERIC,
                    status TEXT DEFAULT 'pending_review',
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
                """,
            )

            # 9. Canary checks
            _execute(
                conn,
                """
                INSERT INTO pipeline.canary_checks
                  (check_name, phase, query_sql, expected_min_rows, severity)
                VALUES
                  ('fec_2015_2016_row_count', 'post_load',
                   'SELECT COUNT(*)::int FROM public.fec_2015_2016_a_staging',
                   1, 'error'),
                  ('fec_2015_2016_has_amounts', 'post_load',
                   'SELECT COUNT(*)::int FROM public.fec_2015_2016_a_staging WHERE contribution_receipt_amount IS NOT NULL AND contribution_receipt_amount > 0',
                   1, 'warn')
                ON CONFLICT (check_name, phase) DO UPDATE SET
                  query_sql = EXCLUDED.query_sql,
                  expected_min_rows = EXCLUDED.expected_min_rows,
                  severity = EXCLUDED.severity
                """,
            )

            print("Seed completed successfully.")
            return 0

        except Exception as e:
            print(f"Seed failed: {e}", file=sys.stderr)
            return 2


if __name__ == "__main__":
    sys.exit(main())
