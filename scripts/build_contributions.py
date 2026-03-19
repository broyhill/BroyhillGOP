#!/usr/bin/env python3
"""
Step 7: Rebuild nc_data_committee.contributions with 0% orphans.

Links every norm.nc_boe_donations row to its donor_id via matching dedup_key → nc_data_committee.donors.
Writes to nc_data_committee.contributions. Reports orphan rate (target: 0%).

Usage:
  python scripts/build_contributions.py
  python scripts/build_contributions.py --dry-run
"""

from __future__ import annotations

import argparse
import logging
import sys
import uuid
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

_script_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(_script_dir))
load_dotenv(_script_dir.parent / ".env")

from db_conn import get_connection_url


def main() -> int:
    parser = argparse.ArgumentParser(description="Build contributions from norm linked to donors")
    parser.add_argument("--dry-run", action="store_true", help="Report only, no writes")
    parser.add_argument("--log-file", default="build_contributions.log", help="Log file")
    parser.add_argument("--batch", type=int, default=5000, help="Batch size for inserts")
    args = parser.parse_args()

    log_path = Path(args.log_file)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(log_path), logging.StreamHandler(sys.stdout)],
    )
    logger = logging.getLogger(__name__)

    conn = psycopg2.connect(get_connection_url())

    # Ensure contributions table exists
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT 1 FROM information_schema.tables
            WHERE table_schema='nc_data_committee' AND table_name='contributions'
            """
        )
        if not cur.fetchone():
            cur.execute(
                """
                CREATE TABLE nc_data_committee.contributions (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    donor_id UUID NOT NULL REFERENCES nc_data_committee.donors(id),
                    norm_id BIGINT NOT NULL,
                    amount NUMERIC(12,2) NOT NULL,
                    transaction_date DATE,
                    committee_sboe_id VARCHAR(50),
                    committee_name VARCHAR(255),
                    source_file VARCHAR(255),
                    source VARCHAR(50) DEFAULT 'ncboe',
                    created_at TIMESTAMPTZ DEFAULT now(),
                    UNIQUE(norm_id)
                )
                """
            )
            conn.commit()

    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM norm.nc_boe_donations")
        total_norm = cur.fetchone()[0] or 0

        cur.execute(
            """
            SELECT COUNT(*) FROM norm.nc_boe_donations n
            WHERE n.dedup_key IS NOT NULL AND TRIM(n.dedup_key) != ''
              AND EXISTS (
                SELECT 1 FROM nc_data_committee.donors d
                WHERE d.dedup_key = n.dedup_key
              )
            """
        )
        linkable = cur.fetchone()[0] or 0

    orphans = total_norm - linkable
    orphan_pct = (orphans / total_norm * 100) if total_norm else 0

    logger.info(
        "Norm rows: %s, linkable: %s, orphans: %s (%.2f%%)",
        total_norm,
        linkable,
        orphans,
        orphan_pct,
    )

    if args.dry_run:
        logger.info(
            "DRY RUN: Would truncate nc_data_committee.contributions and insert %s rows. Orphan rate: %.2f%%",
            linkable,
            orphan_pct,
        )
        conn.close()
        return 0

    # Truncate contributions (donors already built)
    with conn.cursor() as cur:
        cur.execute("TRUNCATE nc_data_committee.contributions")
        conn.commit()

    inserted = 0
    batch = []
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT n.id, n.dedup_key, n.amount, n.transaction_date,
                   n.committee_sboe_id, n.committee_name, n.source_file
            FROM norm.nc_boe_donations n
            INNER JOIN nc_data_committee.donors d ON d.dedup_key = n.dedup_key
            WHERE n.dedup_key IS NOT NULL AND TRIM(n.dedup_key) != ''
            """
        )
        for row in cur:
            norm_id, dedup_key, amount, transaction_date, committee_sboe_id, committee_name, source_file = row
            # Get donor_id - we need it from the join
            pass

    # Refetch with donor_id
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT n.id, d.id AS donor_id, n.amount, n.transaction_date,
                   n.committee_sboe_id, n.committee_name, n.source_file
            FROM norm.nc_boe_donations n
            INNER JOIN nc_data_committee.donors d ON d.dedup_key = n.dedup_key
            WHERE n.dedup_key IS NOT NULL AND TRIM(n.dedup_key) != ''
            """
        )
        rows = cur.fetchall()

    with conn.cursor() as cur:
        for norm_id, donor_id, amount, transaction_date, committee_sboe_id, committee_name, source_file in rows:
            contrib_id = str(uuid.uuid4())
            cur.execute(
                """
                INSERT INTO nc_data_committee.contributions
                (id, donor_id, norm_id, amount, transaction_date, committee_sboe_id, committee_name, source_file, source)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'ncboe')
                """,
                (
                    contrib_id,
                    donor_id,
                    norm_id,
                    amount or 0,
                    transaction_date,
                    committee_sboe_id or None,
                    committee_name or None,
                    source_file or None,
                ),
            )
            inserted += 1
            if inserted % args.batch == 0:
                conn.commit()
                logger.info("Committed batch: %s contributions", inserted)

    conn.commit()
    logger.info(
        "Inserted %s contributions. Orphan rate: %.2f%% (target: 0%%)",
        inserted,
        (orphans / total_norm * 100) if total_norm else 0,
    )
    if orphans > 0:
        logger.warning("Orphans: %s norm rows could not be linked to donors", orphans)
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
