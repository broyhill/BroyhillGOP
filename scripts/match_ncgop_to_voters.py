#!/usr/bin/env python3
"""
Match NCGOP staging donors to nc_voters. Updates statevoterid where matched.

Match: normalized last+first+zip5. Fallback: last+first+city.
nc_voters columns: statevoterid, last_name, first_name, zip_code, res_city_desc

Usage:
  python scripts/match_ncgop_to_voters.py
  python scripts/match_ncgop_to_voters.py --dry-run
"""

from __future__ import annotations

import argparse
import logging
import re
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

_script_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(_script_dir))
load_dotenv(_script_dir.parent / ".env")

from db_conn import get_connection_url


def _norm(s: str) -> str:
    """Lowercase, strip, remove punctuation."""
    if not s:
        return ""
    return re.sub(r"[^\w\s]", "", str(s).lower().strip()).replace(" ", "")


def main() -> int:
    parser = argparse.ArgumentParser(description="Match NCGOP staging to nc_voters")
    parser.add_argument("--dry-run", action="store_true", help="Report only, no updates")
    parser.add_argument("--log-file", default="match_ncgop_to_voters.log", help="Log file")
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
            SELECT COUNT(*) FROM staging.ncgop_winred WHERE statevoterid IS NULL
            """
        )
        total_unmatched = cur.fetchone()[0] or 0

        cur.execute("SELECT COUNT(*) FROM staging.ncgop_winred")
        total = cur.fetchone()[0] or 0

    if total_unmatched == 0:
        logger.info("No unmatched rows. All NCGOP staging rows have statevoterid.")
        conn.close()
        return 0

    logger.info("Unmatched: %s of %s", total_unmatched, total)

    if args.dry_run:
        logger.info("DRY RUN: Would run bulk UPDATE. Skipping.")
        conn.close()
        return 0

    # Bulk UPDATE: match by last+first+zip5
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE staging.ncgop_winred s
            SET statevoterid = v.statevoterid
            FROM public.nc_voters v
            WHERE s.statevoterid IS NULL
              AND s.last_name IS NOT NULL AND TRIM(s.last_name) != ''
              AND s.first_name IS NOT NULL AND TRIM(s.first_name) != ''
              AND s.zip5 IS NOT NULL AND LENGTH(TRIM(s.zip5)) >= 5
              AND LOWER(TRIM(s.last_name)) = LOWER(TRIM(v.last_name))
              AND LOWER(TRIM(s.first_name)) = LOWER(TRIM(v.first_name))
              AND TRIM(s.zip5) = SUBSTRING(REGEXP_REPLACE(TRIM(COALESCE(v.zip_code, '')), '\D', '', 'g') FROM 1 FOR 5)
            """
        )
        matched_zip = cur.rowcount

    conn.commit()

    # Fallback: match by last+first+city (no zip)
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE staging.ncgop_winred s
            SET statevoterid = v.statevoterid
            FROM public.nc_voters v
            WHERE s.statevoterid IS NULL
              AND s.last_name IS NOT NULL AND TRIM(s.last_name) != ''
              AND s.first_name IS NOT NULL AND TRIM(s.first_name) != ''
              AND s.city IS NOT NULL AND TRIM(s.city) != ''
              AND LOWER(TRIM(s.last_name)) = LOWER(TRIM(v.last_name))
              AND LOWER(TRIM(s.first_name)) = LOWER(TRIM(v.first_name))
              AND LOWER(TRIM(s.city)) = LOWER(TRIM(v.res_city_desc))
            """
        )
        matched_city = cur.rowcount

    conn.commit()

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM staging.ncgop_winred WHERE statevoterid IS NOT NULL"
        )
        still_matched = cur.fetchone()[0] or 0

    matched_total = matched_zip + matched_city
    pct = (still_matched / total * 100) if total else 0

    logger.info(
        "Match report: total=%s, matched=%s (%.1f%%), this run: zip=%s, city=%s",
        total,
        still_matched,
        pct,
        matched_zip,
        matched_city,
    )
    print(f"Match rate: {still_matched}/{total} ({pct:.1f}%)")
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
