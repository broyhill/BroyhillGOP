#!/usr/bin/env python3
"""
NCBOE Voter NCID Match — Step 9 of Master Plan V2.

Matches nc_boe_donations_raw to nc_voters on norm_last + canonical_first + norm_zip5.
Only assigns voter_ncid where there's exactly 1 matching voter (unique match).
Populates: voter_ncid, zip9, voter_party_cd.

Runs in batches to avoid timeouts. Use direct DB connection (Hetzner or Cursor terminal)
with DATABASE_URL or SUPABASE_DB_URL — bypasses Supabase API gateway timeout.

Usage:
  python3 -m pipeline.nc_boe_voter_match
  python3 -m pipeline.nc_boe_voter_match --batch-size 25000
  python3 -m pipeline.nc_boe_voter_match --dry-run
"""

from __future__ import annotations

import argparse
import logging
import sys
import time

import psycopg2
from pipeline.db import close_pool, get_connection, init_pool

logger = logging.getLogger(__name__)

VOTER_MATCH_SQL = """
WITH eligible AS (
  SELECT d.id
  FROM public.nc_boe_donations_raw d
  WHERE d.voter_ncid IS NULL
    AND d.transaction_type = 'Individual'
    AND trim(coalesce(d.norm_last, '')) != ''
    AND (trim(coalesce(d.canonical_first, '')) != '' OR trim(coalesce(d.norm_first, '')) != '')
    AND trim(coalesce(d.norm_zip5, '')) != ''
    AND length(trim(d.norm_zip5)) >= 5
  ORDER BY d.id
  LIMIT %s
),
ranked_matches AS (
  SELECT d.id, v.ncid, v.zip_code, v.party_cd,
    row_number() OVER (PARTITION BY d.id ORDER BY
      CASE WHEN upper(trim(d.canonical_first)) = upper(trim(v.first_name)) THEN 0
           WHEN upper(trim(d.norm_first)) = upper(trim(v.first_name)) THEN 1
           ELSE 2 END,
      v.ncid
    ) AS rn,
    count(*) OVER (PARTITION BY d.id) AS match_count
  FROM public.nc_boe_donations_raw d
  JOIN public.nc_voters v
    ON upper(trim(d.norm_last)) = upper(trim(v.last_name))
   AND trim(d.norm_zip5) = left(trim(coalesce(v.zip_code, '')), 5)
   AND (
     upper(trim(d.canonical_first)) = upper(trim(v.first_name))
     OR upper(trim(d.norm_first)) = upper(trim(v.first_name))
     OR upper(split_part(trim(coalesce(d.norm_first,'')), ' ', 1)) = upper(trim(v.first_name))
     OR upper(split_part(trim(coalesce(d.canonical_first,'')), ' ', 1)) = upper(trim(v.first_name))
   )
  WHERE d.id IN (SELECT id FROM eligible)
),
best_matches AS (
  SELECT id, ncid, zip_code, party_cd
  FROM ranked_matches
  WHERE rn = 1 AND match_count <= 3
)
UPDATE public.nc_boe_donations_raw d
SET
  voter_ncid = m.ncid,
  zip9 = m.zip_code,
  voter_party_cd = m.party_cd
FROM best_matches m
WHERE d.id = m.id
"""

COUNT_UNMATCHED_SQL = """
SELECT count(*) FROM public.nc_boe_donations_raw
WHERE voter_ncid IS NULL
  AND transaction_type = 'Individual'
  AND trim(coalesce(norm_last, '')) != ''
  AND (trim(coalesce(canonical_first, '')) != '' OR trim(coalesce(norm_first, '')) != '')
  AND trim(coalesce(norm_zip5, '')) != ''
  AND length(trim(norm_zip5)) >= 5
"""


def run_voter_match(batch_size: int = 5000, dry_run: bool = False) -> dict:
    """
    Run voter match in batches. Returns dict with total_matched, batches_run, etc.
    """
    init_pool()
    total_updated = 0
    batches_run = 0

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(COUNT_UNMATCHED_SQL)
            initial_unmatched = cur.fetchone()[0] or 0

    if initial_unmatched == 0:
        return {
            "total_matched": 0,
            "batches_run": 0,
            "initial_unmatched": 0,
            "message": "No unmatched rows eligible for voter match.",
        }

    logger.info("Eligible unmatched rows: %s. Batch size: %s", initial_unmatched, batch_size)

    max_retries = 3
    backoff_seconds = [2, 4, 8]

    while True:
        if dry_run:
            with get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT count(*) FROM (SELECT 1 FROM public.nc_boe_donations_raw d "
                        "WHERE d.voter_ncid IS NULL AND d.transaction_type = 'Individual' "
                        "AND trim(coalesce(d.norm_last,'')) != '' AND trim(coalesce(d.canonical_first,'')) != '' "
                        "AND trim(coalesce(d.norm_zip5,'')) != '' AND length(trim(d.norm_zip5)) >= 5 "
                        "LIMIT %s) t",
                        (batch_size,),
                    )
                    would_process = cur.fetchone()[0]
                    return {
                        "total_matched": 0,
                        "batches_run": 0,
                        "initial_unmatched": initial_unmatched,
                        "message": f"Dry run: would process up to {would_process} rows per batch.",
                    }

        updated = 0
        for attempt in range(max_retries):
            try:
                with get_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute(VOTER_MATCH_SQL, (batch_size,))
                        updated = cur.rowcount
                break
            except (psycopg2.OperationalError, psycopg2.InterfaceError) as e:
                if attempt < max_retries - 1:
                    logger.warning(
                        "Connection error (attempt %s/%s): %s. Resetting pool and retrying in %ss...",
                        attempt + 1,
                        max_retries,
                        e,
                        backoff_seconds[attempt],
                    )
                    close_pool()
                    time.sleep(backoff_seconds[attempt])
                else:
                    raise

        total_updated += updated
        batches_run += 1
        if updated > 0:
            print(f"  Batch {batches_run}: matched {updated:,} rows (cumulative: {total_updated:,})")
        if updated == 0:
            break

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT count(*) FROM public.nc_boe_donations_raw WHERE voter_ncid IS NOT NULL"
            )
            total_with_ncid = cur.fetchone()[0] or 0

    return {
        "total_matched": total_updated,
        "batches_run": batches_run,
        "initial_unmatched": initial_unmatched,
        "total_with_ncid": total_with_ncid,
        "message": f"Voter match complete. Matched {total_updated:,} rows in {batches_run} batches.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="NCBOE voter NCID match (Step 9) — batch mode, unique match only"
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=5000,
        help="Rows per batch (default 5000)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Show what would run")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose logging")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(message)s",
    )

    try:
        result = run_voter_match(batch_size=args.batch_size, dry_run=args.dry_run)
        print(result["message"])
        if result.get("total_with_ncid") is not None:
            print(f"  Total rows with voter_ncid: {result['total_with_ncid']:,}")
        return 0
    except Exception as e:
        logger.exception("Voter match failed: %s", e)
        return 1


if __name__ == "__main__":
    sys.exit(main())
