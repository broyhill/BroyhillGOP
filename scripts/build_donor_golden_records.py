#!/usr/bin/env python3
"""
Step 6: Build nc_data_committee.donors golden records from norm.nc_boe_donations + NCGOP staging.

Groups norm.nc_boe_donations by dedup_key. Merges email/phone from staging.ncgop_winred
where statevoterid matches. NCGOP statevoterid takes precedence over NCBOE match for same person.
Adds second path: NCGOP donors without statevoterid (unmatched) — create donor records using
same dedup_key format as NCBOE (last|first|zip5) so contributions can link. Email stored as
profile enrichment, not identity. source='ncgop_unmatched' flags these. Truncate+reload.

--dry-run: Query and print counts only. NO TRUNCATE. NO writes. Exit 0.

Usage:
  python scripts/build_donor_golden_records.py
  python scripts/build_donor_golden_records.py --dry-run
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
from utils import norm_name, norm_zip


def main() -> int:
    parser = argparse.ArgumentParser(description="Build donor golden records from norm + NCGOP staging")
    parser.add_argument("--dry-run", action="store_true", help="Report counts only, no TRUNCATE, no writes")
    parser.add_argument("--log-file", default="build_donor_golden_records.log", help="Log file")
    args = parser.parse_args()

    log_path = Path(args.log_file)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(log_path), logging.StreamHandler(sys.stdout)],
    )
    logger = logging.getLogger(__name__)

    conn = psycopg2.connect(get_connection_url())

    # Query counts for dry-run or pre-insert reporting
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(DISTINCT dedup_key) FROM norm.nc_boe_donations
            WHERE dedup_key IS NOT NULL AND TRIM(dedup_key) != ''
            """
        )
        norm_donor_count = cur.fetchone()[0] or 0

        cur.execute(
            """
            SELECT COUNT(*) FROM staging.ncgop_winred g
            WHERE g.statevoterid IS NOT NULL
              AND EXISTS (
                SELECT 1 FROM norm.nc_boe_donations n
                WHERE n.statevoterid = g.statevoterid
              )
            """
        )
        ncgop_voter_matched = cur.fetchone()[0] or 0

        # NCGOP unmatched: statevoterid IS NULL, need last+first for dedup_key (same format as NCBOE)
        cur.execute(
            """
            SELECT first_name, last_name, zip5, email, phone
            FROM staging.ncgop_winred
            WHERE statevoterid IS NULL
              AND last_name IS NOT NULL AND TRIM(last_name) != ''
              AND first_name IS NOT NULL AND TRIM(first_name) != ''
            """
        )
        ncgop_unmatched_rows = cur.fetchall()

    # Build set of norm dedup_keys to avoid duplicating
    norm_dedup_keys = set()
    if norm_donor_count > 0:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT DISTINCT dedup_key FROM norm.nc_boe_donations
                WHERE dedup_key IS NOT NULL AND TRIM(dedup_key) != ''
                """
            )
            norm_dedup_keys = {r[0] for r in cur.fetchall()}

    # NCGOP unmatched: use SAME dedup_key format as NCBOE (last|first|zip5) so
    # build_contributions can link their NCBOE contributions to this donor.
    # Email is contact data, stored in email_primary; source='ncgop_unmatched' flags these.
    ncgop_unmatched_donors = []
    for first_name, last_name, zip5, email, phone in ncgop_unmatched_rows:
        ln = norm_name(str(last_name or ""))
        fn = norm_name(str(first_name or ""))
        zp = norm_zip(str(zip5 or ""))
        dedup_key = f"{ln}|{fn}|{zp}" if (ln or fn) else ""
        if dedup_key and dedup_key not in norm_dedup_keys:
            ncgop_unmatched_donors.append((dedup_key, first_name, last_name, zip5, email, phone))
            norm_dedup_keys.add(dedup_key)  # avoid dupes within NCGOP

    ncgop_unmatched_count = len(ncgop_unmatched_donors)
    total_would_insert = norm_donor_count + ncgop_unmatched_count

    logger.info(
        "Counts: NCBOE donors (norm)=%s, NCGOP voter-matched=%s, NCGOP unmatched=%s, total=%s",
        norm_donor_count,
        ncgop_voter_matched,
        ncgop_unmatched_count,
        total_would_insert,
    )

    if args.dry_run:
        logger.info(
            "DRY RUN: Would insert %s rows. NO TRUNCATE. NO writes. Exiting.",
            total_would_insert,
        )
        print(f"DRY RUN: norm_donors={norm_donor_count}, ncgop_voter_matched={ncgop_voter_matched}, ncgop_unmatched={ncgop_unmatched_count}, total={total_would_insert}")
        conn.close()
        return 0

    if total_would_insert == 0:
        logger.info("Nothing to build.")
        conn.close()
        return 0

    # Ensure schema and dedup_key column
    with conn.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS nc_data_committee")
        cur.execute(
            """
            SELECT 1 FROM information_schema.columns
            WHERE table_schema='nc_data_committee' AND table_name='donors' AND column_name='dedup_key'
            """
        )
        if not cur.fetchone():
            cur.execute(
                "ALTER TABLE nc_data_committee.donors ADD COLUMN IF NOT EXISTS dedup_key VARCHAR(255)"
            )
        conn.commit()

    # Build norm donors: one per dedup_key, merge NCGOP email/phone where statevoterid matches
    with conn.cursor() as cur:
        cur.execute(
            """
            WITH norm_agg AS (
                SELECT
                    dedup_key,
                    MAX(norm_last) AS norm_last,
                    MAX(norm_first) AS norm_first,
                    MAX(norm_zip5) AS norm_zip5,
                    MAX(norm_city) AS norm_city,
                    MAX(norm_state) AS norm_state,
                    MAX(raw_street_1) AS raw_street_1,
                    MAX(raw_street_2) AS raw_street_2,
                    MAX(employer_raw) AS employer_raw,
                    MAX(statevoterid) AS statevoterid
                FROM norm.nc_boe_donations
                WHERE dedup_key IS NOT NULL AND TRIM(dedup_key) != ''
                GROUP BY dedup_key
            ),
            with_ncgop AS (
                SELECT
                    n.dedup_key,
                    n.norm_last,
                    n.norm_first,
                    n.norm_zip5,
                    n.norm_city,
                    n.norm_state,
                    n.raw_street_1,
                    n.raw_street_2,
                    n.employer_raw,
                    COALESCE(n.statevoterid, g.statevoterid) AS statevoterid,
                    CASE WHEN g.statevoterid IS NOT NULL THEN g.email ELSE NULL END AS ncgop_email,
                    CASE WHEN g.statevoterid IS NOT NULL THEN g.phone ELSE NULL END AS ncgop_phone
                FROM norm_agg n
                LEFT JOIN (
                    SELECT DISTINCT ON (statevoterid) statevoterid, email, phone
                    FROM staging.ncgop_winred
                    WHERE statevoterid IS NOT NULL
                    ORDER BY statevoterid, id DESC
                ) g ON n.statevoterid = g.statevoterid
            )
            SELECT dedup_key, norm_last, norm_first, norm_zip5, norm_city, norm_state,
                   raw_street_1, raw_street_2, employer_raw, statevoterid, ncgop_email, ncgop_phone
            FROM with_ncgop
            """
        )
        norm_rows = cur.fetchall()

    # TRUNCATE only when NOT dry-run
    with conn.cursor() as cur:
        cur.execute("TRUNCATE nc_data_committee.donors RESTART IDENTITY CASCADE")
        conn.commit()

    inserted = 0
    with conn.cursor() as cur:
        for r in norm_rows:
            dedup_key, norm_last, norm_first, norm_zip5, norm_city, norm_state = r[:6]
            raw_street_1, raw_street_2, employer_raw, statevoterid, ncgop_email, ncgop_phone = r[6:]

            donor_id = str(uuid.uuid4())
            email = ncgop_email
            phone = ncgop_phone

            cur.execute(
                """
                INSERT INTO nc_data_committee.donors
                (id, first_name, last_name, email_primary, phone_mobile, voter_id,
                 address_line1, address_line2, city, state, zip, employer, dedup_key, source, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'ncboe_ncgop', now(), now())
                """,
                (
                    donor_id,
                    norm_first or None,
                    norm_last or None,
                    email or None,
                    phone or None,
                    statevoterid or None,
                    raw_street_1 or None,
                    raw_street_2 or None,
                    norm_city or None,
                    norm_state or None,
                    norm_zip5 or None,
                    employer_raw or None,
                    dedup_key or None,
                ),
            )
            inserted += 1

        # Second path: NCGOP unmatched donors
        for dedup_key, first_name, last_name, zip5, email, phone in ncgop_unmatched_donors:
            donor_id = str(uuid.uuid4())
            cur.execute(
                """
                INSERT INTO nc_data_committee.donors
                (id, first_name, last_name, email_primary, phone_mobile, voter_id,
                 address_line1, address_line2, city, state, zip, employer, dedup_key, source, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'ncgop_unmatched', now(), now())
                """,
                (
                    donor_id,
                    first_name or None,
                    last_name or None,
                    email or None,
                    phone or None,
                    None,  # voter_id
                    None,
                    None,
                    None,
                    None,
                    zip5 or None,
                    None,
                    dedup_key or None,
                ),
            )
            inserted += 1

    conn.commit()
    logger.info(
        "Inserted %s donor golden records (norm=%s, ncgop_unmatched=%s)",
        inserted,
        len(norm_rows),
        ncgop_unmatched_count,
    )
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
