#!/usr/bin/env python3
"""
NCBOE Pipeline Audit — comprehensive status check across database and code expectations.

Usage:
  python3 -m pipeline.audit_ncboe_status

Requires SUPABASE_DB_URL or DATABASE_URL in environment (or .env).
"""

from __future__ import annotations

import sys
from pipeline.db import get_connection, init_pool

QUERIES = [
    ("nc_boe_donations_raw", """
        SELECT
            count(*) AS total,
            count(*) FILTER (WHERE transaction_type = 'Individual') AS individual,
            count(*) FILTER (WHERE voter_ncid IS NOT NULL) AS with_voter_ncid,
            count(*) FILTER (WHERE content_hash IS NOT NULL) AS with_content_hash,
            count(*) FILTER (WHERE dedup_key IS NOT NULL) AS with_dedup_key
        FROM public.nc_boe_donations_raw
    """),
    ("identity_clusters (nc_boe)", """
        SELECT count(*) AS clusters,
               coalesce(sum(member_count), 0) AS total_members,
               count(*) FILTER (WHERE status = 'pending_review') AS pending
        FROM pipeline.identity_clusters
        WHERE source_system = 'nc_boe'
    """),
    ("dedup_rules", """
        SELECT source_system, dedup_function_name, notes::text
        FROM pipeline.dedup_rules
        WHERE source_system = 'nc_boe'
    """),
    ("identity_pass_log", """
        SELECT pass_name, status, rows_matched, rows_remaining, last_run_at
        FROM pipeline.identity_pass_log
        WHERE pass_name LIKE '%%nc_boe%%' OR pass_name LIKE '%%dedup%%'
        ORDER BY last_run_at DESC
        LIMIT 5
    """),
    ("staging.ncboe_archive", """
        SELECT count(*) AS archived FROM staging.ncboe_archive
    """),
    ("core.ncboe_committee_registry", """
        SELECT count(*) AS committees FROM core.ncboe_committee_registry
    """),
]


def _fmt_row(cols: tuple, row: tuple) -> str:
    return "  " + " | ".join(f"{c}: {v}" for c, v in zip(cols, row))


def main() -> int:
    init_pool()
    print("=" * 60)
    print("NCBOE PIPELINE AUDIT")
    print("=" * 60)

    with get_connection() as conn:
        with conn.cursor() as cur:
            for name, sql in QUERIES:
                try:
                    cur.execute(sql)
                    rows = cur.fetchall()
                    cols = [d[0] for d in cur.description]
                    print(f"\n--- {name} ---")
                    if not rows:
                        print("  (no rows)")
                        continue
                    for row in rows:
                        print(_fmt_row(cols, row))
                except Exception as e:
                    print(f"\n--- {name} ---")
                    print(f"  ERROR: {e}")

    print("\n" + "=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
