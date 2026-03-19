#!/usr/bin/env python3
"""
ETL from nc_boe_donations_raw → norm.nc_boe_donations.

Reads from existing raw table using pre-computed columns (amount_numeric, date_occurred,
norm_last, norm_first, norm_zip5, norm_city, norm_state, norm_addr). Does NOT re-parse.
Recomputes dedup_key only: lower(norm_last)||'|'||lower(norm_first)||'|'||norm_zip5
(do not trust existing dedup_key — old pipeline had inconsistent logic).
Runs voter match using norm_last + norm_first + norm_zip5 → statevoterid.

Usage:
  python scripts/normalize_ncboe.py
  python scripts/normalize_ncboe.py --dry-run
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

_script_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(_script_dir))
load_dotenv(_script_dir.parent / ".env")

from db_conn import get_connection_url


def main() -> int:
    parser = argparse.ArgumentParser(description="Normalize NCBOE raw to norm table")
    parser.add_argument("--dry-run", action="store_true", help="Report only, no writes")
    parser.add_argument("--log-file", default="normalize_ncboe.log", help="Log file")
    parser.add_argument("--batch", type=int, default=50000, help="Batch size for processing")
    args = parser.parse_args()

    log_path = Path(args.log_file)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(log_path), logging.StreamHandler(sys.stdout)],
    )
    logger = logging.getLogger(__name__)

    conn = psycopg2.connect(get_connection_url())

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*) FROM public.nc_boe_donations_raw r
            WHERE NOT EXISTS (
                SELECT 1 FROM norm.nc_boe_donations n
                WHERE n.source_file = r.source_file
                  AND n.raw_donor_name = r.donor_name
                  AND COALESCE(n.amount, 0) = COALESCE(r.amount_numeric, 0)
                  AND n.transaction_date IS NOT DISTINCT FROM r.date_occurred
            )
            """
        )
        to_process = cur.fetchone()[0] or 0

    if to_process == 0:
        logger.info("No new rows to normalize.")
        conn.close()
        return 0

    logger.info("Rows to normalize: %s", to_process)

    if args.dry_run:
        logger.info("DRY RUN: Would ETL %s rows from raw to norm, then match voters.", to_process)
        conn.close()
        return 0

    # Ensure dedup_key and statevoterid columns exist in norm
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT 1 FROM information_schema.columns
            WHERE table_schema='norm' AND table_name='nc_boe_donations' AND column_name='dedup_key'
            """
        )
        if not cur.fetchone():
            cur.execute("ALTER TABLE norm.nc_boe_donations ADD COLUMN IF NOT EXISTS dedup_key VARCHAR(255)")
        cur.execute(
            """
            SELECT 1 FROM information_schema.columns
            WHERE table_schema='norm' AND table_name='nc_boe_donations' AND column_name='statevoterid'
            """
        )
        if not cur.fetchone():
            cur.execute("ALTER TABLE norm.nc_boe_donations ADD COLUMN IF NOT EXISTS statevoterid VARCHAR(50)")
        conn.commit()

    cols = [
        "id",
        "donor_name",
        "street_line_1",
        "street_line_2",
        "city",
        "state",
        "zip_code",
        "employer_name",
        "amount_numeric",
        "date_occurred",
        "transaction_type",
        "form_of_payment",
        "purpose",
        "committee_sboe_id",
        "committee_name",
        "source_file",
        "norm_last",
        "norm_first",
        "norm_zip5",
        "norm_city",
        "norm_state",
        "norm_addr",
    ]

    inserted = 0
    while True:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT r.id, r.donor_name, r.street_line_1, r.street_line_2, r.city, r.state, r.zip_code,
                       r.employer_name, r.amount_numeric, r.date_occurred, r.transaction_type,
                       r.form_of_payment, r.purpose, r.committee_sboe_id, r.committee_name, r.source_file,
                       r.norm_last, r.norm_first, r.norm_zip5, r.norm_city, r.norm_state, r.norm_addr
                FROM public.nc_boe_donations_raw r
                WHERE NOT EXISTS (
                    SELECT 1 FROM norm.nc_boe_donations n
                    WHERE n.source_file = r.source_file
                      AND n.raw_donor_name = r.donor_name
                      AND COALESCE(n.amount, 0) = COALESCE(r.amount_numeric, 0)
                      AND n.transaction_date IS NOT DISTINCT FROM r.date_occurred
                )
                ORDER BY r.id
                LIMIT %s
                """,
                (args.batch,),
            )
            rows = cur.fetchall()

        if not rows:
            break

        with conn.cursor() as cur:
            for row in rows:
                r = dict(zip(cols, row))

                # Use pre-computed columns from raw; recompute dedup_key only (do not trust existing)
                norm_last = str(r.get("norm_last") or "").strip()
                norm_first = str(r.get("norm_first") or "").strip()
                norm_zip5 = str(r.get("norm_zip5") or "").strip()
                dedup_key = f"{norm_last.lower()}|{norm_first.lower()}|{norm_zip5}" if (norm_last or norm_first) else ""
                if not dedup_key:
                    continue  # Skip rows with no name data

                norm_street = (r.get("norm_addr") or "").strip() or " ".join(
                    filter(None, [str(r.get("street_line_1") or "").strip(), str(r.get("street_line_2") or "").strip()])
                ).strip()

                cur.execute(
                    """
                    INSERT INTO norm.nc_boe_donations
                    (raw_donor_name, raw_street_1, raw_street_2, norm_street, norm_city, norm_state, norm_zip5,
                     norm_last, norm_first, employer_raw, amount, transaction_date, transaction_type,
                     form_of_payment, purpose, committee_sboe_id, committee_name, source_file,
                     dedup_key, normalized_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now())
                    """,
                    (
                        r.get("donor_name"),
                        r.get("street_line_1"),
                        r.get("street_line_2"),
                        norm_street or None,
                        (r.get("norm_city") or "")[:100] if r.get("norm_city") else None,
                        str(r.get("norm_state") or "")[:2].upper() if r.get("norm_state") else None,
                        norm_zip5 or None,
                        norm_last or None,
                        norm_first or None,
                        r.get("employer_name"),
                        r.get("amount_numeric"),
                        r.get("date_occurred"),
                        r.get("transaction_type") or "Individual",
                        r.get("form_of_payment"),
                        r.get("purpose"),
                        r.get("committee_sboe_id"),
                        r.get("committee_name"),
                        r.get("source_file"),
                        dedup_key or None,
                    ),
                )
                inserted += 1

        conn.commit()
        logger.info("Batch: inserted %s rows (total %s)", len(rows), inserted)

    conn.commit()
    logger.info("Inserted %s rows into norm.nc_boe_donations", inserted)

    # Voter match: bulk UPDATE using norm_last + norm_first + norm_zip5 → statevoterid
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE norm.nc_boe_donations n
            SET statevoterid = v.statevoterid
            FROM public.nc_voters v
            WHERE n.statevoterid IS NULL
              AND n.norm_last IS NOT NULL AND TRIM(n.norm_last) != ''
              AND n.norm_first IS NOT NULL AND TRIM(n.norm_first) != ''
              AND n.norm_zip5 IS NOT NULL AND LENGTH(TRIM(n.norm_zip5)) >= 5
              AND LOWER(TRIM(n.norm_last)) = LOWER(TRIM(v.last_name))
              AND LOWER(TRIM(n.norm_first)) = LOWER(TRIM(v.first_name))
              AND TRIM(n.norm_zip5) = SUBSTRING(REGEXP_REPLACE(TRIM(COALESCE(v.zip_code, '')), '\D', '', 'g') FROM 1 FOR 5)
            """
        )
        voter_matched = cur.rowcount

    conn.commit()
    logger.info("Voter match: %s rows updated with statevoterid", voter_matched)

    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
