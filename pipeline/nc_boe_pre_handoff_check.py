#!/usr/bin/env python3
"""
Pre-handoff check for NCBOE pipeline.

Detects: voter_ncids in nc_boe_donations_raw that don't exist in donors_master yet.
Those would disappear permanently with INNER JOIN handoff — they must be upserted first.

Fails if orphaned rows exceed 1%. When failed, prints diagnostic: orphan count by county, ZIP, cycle year.

Recovery: Run identity resolution to upsert missing voter_ncids into donors_master, then re-run handoff.

Assumes donors_master.voter_ncid. If your schema uses a different column, update the SQL in this script.

Usage:
  python3 -m pipeline.nc_boe_pre_handoff_check
  python3 -m pipeline.nc_boe_pre_handoff_check --threshold 0.02  # 2%
"""

from __future__ import annotations

import argparse
import sys

from pipeline.db import get_cursor, init_pool

ORPHAN_THRESHOLD_PCT = 0.01  # 1%


def run_check(threshold_pct: float = ORPHAN_THRESHOLD_PCT) -> int:
    """
    Run pre-handoff check. Return 0 if OK, 1 if fail.
    """
    init_pool()

    with get_cursor(dict_cursor=True) as cur:
        cur.execute(
            """
            SELECT
                count(*) AS orphaned,
                (SELECT count(*) FROM public.nc_boe_donations_raw) AS total
            FROM public.nc_boe_donations_raw r
            WHERE NOT EXISTS (
                SELECT 1 FROM public.donors_master dm WHERE dm.voter_ncid = r.voter_ncid
            )
            """
        )
        row = cur.fetchone()
        orphaned = row["orphaned"] or 0
        total = row["total"] or 0
        pct = (orphaned / total * 100) if total else 0

    if orphaned == 0:
        print("OK: No orphaned rows. Handoff may proceed.")
        return 0

    if pct / 100 <= threshold_pct:
        print(f"OK: {orphaned} orphaned ({pct:.2f}%) <= {threshold_pct*100}% threshold. Handoff may proceed.")
        return 0

    print("FAIL: Orphaned rows exceed threshold.", file=sys.stderr)
    print(f"  Orphaned: {orphaned} ({pct:.2f}%)", file=sys.stderr)
    print(f"  Threshold: {threshold_pct*100}%", file=sys.stderr)
    print("", file=sys.stderr)
    print("Diagnostic (orphan count by county, ZIP, cycle year):", file=sys.stderr)

    with get_cursor(dict_cursor=True) as cur:
        cur.execute(
            """
            SELECT
                coalesce(v.county_desc, 'unknown') AS county,
                r.norm_zip5 AS zip5,
                extract(year from r.date_occurred)::int AS cycle_year,
                count(*) AS orphaned
            FROM public.nc_boe_donations_raw r
            LEFT JOIN public.donors_master dm ON dm.voter_ncid = r.voter_ncid
            LEFT JOIN public.nc_voters v ON v.ncid = r.voter_ncid
            WHERE dm.id IS NULL
            GROUP BY 1, 2, 3
            ORDER BY 4 DESC
            """
        )
        for r in cur.fetchall():
            print(f"  {r['county']} | {r['zip5']} | {r['cycle_year']} | {r['orphaned']}", file=sys.stderr)

    print("", file=sys.stderr)
    print("Recovery: Run identity resolution to upsert missing voter_ncids into donors_master, then re-run handoff.", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Pre-handoff check for NCBOE pipeline")
    parser.add_argument(
        "--threshold",
        type=float,
        default=ORPHAN_THRESHOLD_PCT,
        help=f"Fail if orphaned pct > this (default {ORPHAN_THRESHOLD_PCT})",
    )
    args = parser.parse_args()
    return run_check(threshold_pct=args.threshold)


if __name__ == "__main__":
    sys.exit(main())
