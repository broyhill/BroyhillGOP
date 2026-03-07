#!/usr/bin/env python3
"""
FEC 2015_2016 Pipeline Test — Full pipeline run.

Runs schema_check, norm_gate, dedup, and ingest (dry_run + optional real run)
against public.fec_2015_2016_a_staging. The staging table is in PUBLIC schema.

Usage:
  1. Set SUPABASE_DB_URL or DATABASE_URL in .env
  2. Run seed first: python -m pipeline.run_seed
  3. python -m pipeline.test_2015_2016

  Optional: set INGEST_TEST_CSV to a path of a small FEC CSV to run a real
  ingest (writes to public.fec_2015_2016_a_staging by default).
"""

from __future__ import annotations

import csv
import os
import sys
import tempfile
from pathlib import Path

# Staging table is in public schema
STAGING_SCHEMA = "public"
STAGING_TABLE = "fec_2015_2016_a_staging"


# Sample values for key FEC columns so dry_run CSV is valid and matches quality rules
_FEC_SAMPLE_ROWS = [
    {
        "committee_id": "C001",
        "contributor_last_name": "Smith",
        "contributor_first_name": "John",
        "contributor_zip": "27601",
        "contribution_receipt_amount": "50.00",
        "contributor_state": "NC",
        "entity_type": "IND",
    },
    {
        "committee_id": "C001",
        "contributor_last_name": "Smith",
        "contributor_first_name": "Jane",
        "contributor_zip": "27601",
        "contribution_receipt_amount": "100.00",
        "contributor_state": "NC",
        "entity_type": "IND",
    },
]


def _make_fec_csv_from_staging_columns(path: Path, columns: list[str]) -> None:
    """Write a FEC CSV with header = staging table columns and 2 sample rows.
    Matches full schema so dry_run (and optional real ingest) does not hit column mismatch.
    """
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        for sample in _FEC_SAMPLE_ROWS:
            row = [sample.get(col, "") for col in columns]
            writer.writerow(row)


def main() -> int:
    from pipeline.schema_check import run_schema_check
    from pipeline.norm_gate import run_norm_gate
    from pipeline.dedup import run_dedup
    from pipeline.ingest import run_ingest

    print("=" * 60)
    print("FEC 2015_2016 Pipeline Test")
    print(f"Target: {STAGING_SCHEMA}.{STAGING_TABLE}")
    print("=" * 60)

    # 1. Schema check
    print("\n--- 1. Schema Check ---")
    schema_result = run_schema_check(
        "fec",
        "2015_2016",
        staging_schema=STAGING_SCHEMA,
        staging_table=STAGING_TABLE,
        cycle="2015_2016",
    )
    print(schema_result.to_report())
    if not schema_result.passed:
        print("Schema check FAILED. Fix schema or run seed with source_schemas populated.")
        return 1

    # 2. Norm gate
    print("\n--- 2. Norm Gate ---")
    gate_result = run_norm_gate(
        "fec",
        staging_schema=STAGING_SCHEMA,
        staging_table=STAGING_TABLE,
        cycle="2015_2016",
    )
    print(gate_result.to_report())
    if not gate_result.passed:
        print("Norm gate FAILED. Data does not meet readiness thresholds.")
        return 2

    # 3. Dedup
    print("\n--- 3. Dedup ---")
    dedup_result = run_dedup(
        "fec",
        staging_schema=STAGING_SCHEMA,
        staging_table=STAGING_TABLE,
        cycle="2015_2016",
    )
    print(dedup_result.to_report())

    # 4. Ingest (dry_run with CSV matching full staging schema)
    print("\n--- 4. Ingest (dry_run) ---")
    from pipeline.db import get_connection
    from pipeline.ingest import _get_staging_table_columns

    with get_connection() as conn:
        staging_columns = _get_staging_table_columns(conn, STAGING_SCHEMA, STAGING_TABLE)
    if not staging_columns:
        print("Cannot get staging columns; skipping ingest dry_run.")
    else:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False, newline="", encoding="utf-8") as tf:
            _make_fec_csv_from_staging_columns(Path(tf.name), staging_columns)
            temp_csv = tf.name
        try:
            dry_result = run_ingest(
                temp_csv,
                "fec",
                "2015_2016",
                chunk_size=1000,
                dry_run=True,
                staging_schema=STAGING_SCHEMA,
                staging_table=STAGING_TABLE,
            )
            print(
                f"Dry run: job_id={dry_result['job_id']}, manifest_id={dry_result['manifest_id']}, "
                f"amount_total={dry_result.get('amount_total')}"
            )
            print("Ingest dry_run OK.")
        finally:
            Path(temp_csv).unlink(missing_ok=True)

    # Optional: real ingest if INGEST_TEST_CSV is set
    ingest_test_csv = os.environ.get("INGEST_TEST_CSV")
    if ingest_test_csv and Path(ingest_test_csv).exists():
        print("\n--- 5. Ingest (real run) ---")
        real_result = run_ingest(
            ingest_test_csv,
            "fec",
            "2015_2016",
            staging_schema=STAGING_SCHEMA,
            staging_table=STAGING_TABLE,
            dry_run=False,
        )
        print(f"Rows inserted: {real_result['rows_inserted']}, errors: {real_result['errors_count']}")
    else:
        print("\n--- 5. Ingest (real run) --- Skipped (set INGEST_TEST_CSV to run).")

    print("\n" + "=" * 60)
    print("Pipeline run complete.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"\nPipeline test failed: {e}", file=sys.stderr)
        sys.exit(3)
