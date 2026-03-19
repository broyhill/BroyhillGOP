#!/usr/bin/env python3
"""
FEC Donor → NC Voter Matcher

Matches norm.fec_individual contributors to public.nc_voters using tiered matching:
  Tier 1: norm_last + norm_first + norm_zip5 + street_number (highest confidence)
  Tier 2: norm_last + norm_first + norm_zip5 + norm_city
  Tier 3: norm_last + norm_first + norm_zip5 only (lowest confidence)

Writes results to public.fec_voter_matches. No destructive changes (RFC-001).

Usage:
  cd /Users/Broyhill/Desktop/BroyhillGOP-CURSOR
  export SUPABASE_DB_URL="postgresql://..."
  python -m backend.python.matching.fec_voter_matcher [--batch-size 50000] [--dry-run]

References: docs/PERPLEXITY_FEC_DONOR_MATCHING_PLAN.md, docs/CANONICAL_TABLES_AUDIT.md
"""
from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

# Add project root for imports
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import psycopg2

logger = logging.getLogger(__name__)


def _get_db_url() -> str:
    url = os.environ.get("SUPABASE_DB_URL") or os.environ.get("DATABASE_URL")
    if not url or not url.strip():
        raise ValueError(
            "Set SUPABASE_DB_URL or DATABASE_URL (e.g. postgresql://postgres:PASSWORD@db.xxx.supabase.co:5432/postgres)"
        )
    return url.strip()


def run_matching(
    conn,
    batch_size: int = 0,
    dry_run: bool = False,
) -> dict:
    """
    Run tiered FEC → nc_voters matching via batch SQL. Returns match stats.
    """
    cur = conn.cursor()

    # Ensure fec_voter_matches exists
    cur.execute("""
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'fec_voter_matches'
    """)
    if not cur.fetchone():
        raise RuntimeError(
            "Table public.fec_voter_matches does not exist. Run migration 058 first: "
            "psql $SUPABASE_DB_URL -f database/migrations/058_FEC_VOTER_MATCHES.sql"
        )

    # Check nc_voters columns for optional canonical_first_name, street_number
    cur.execute("""
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'nc_voters'
        AND column_name IN ('canonical_first_name', 'preferred_name', 'street_number')
    """)
    extra_cols = {r[0] for r in cur.fetchall()}
    first_name_expr = (
        "LOWER(TRIM(COALESCE(nv.canonical_first_name, nv.preferred_name, nv.first_name)))"
        if ("canonical_first_name" in extra_cols or "preferred_name" in extra_cols)
        else "LOWER(TRIM(nv.first_name))"
    )
    has_street_num = "street_number" in extra_cols
    street_num_expr = (
        "TRIM(nv.street_number)"
        if has_street_num
        else "SUBSTRING(TRIM(COALESCE(nv.res_street_address,'')) FROM '^[0-9]+')"
    )

    # Build batch limit clause
    limit_clause = f"LIMIT {batch_size}" if batch_size > 0 else ""

    # FEC staging: unique NC contributors with best address, extracted street_number
    fec_cte = """
    fec AS (
        SELECT DISTINCT ON (contributor_id)
            contributor_id,
            LOWER(TRIM(norm_last)) AS n_last,
            LOWER(TRIM(norm_first)) AS n_first,
            LOWER(TRIM(COALESCE(norm_city,''))) AS n_city,
            LEFT(TRIM(COALESCE(norm_zip5,'')), 5) AS n_zip5,
            SUBSTRING(TRIM(COALESCE(norm_street,'')) FROM '^[0-9]+') AS n_street_num
        FROM norm.fec_individual
        WHERE contributor_id IS NOT NULL AND contributor_id != ''
          AND norm_last IS NOT NULL AND norm_last != ''
          AND norm_first IS NOT NULL AND norm_first != ''
          AND norm_zip5 IS NOT NULL AND LENGTH(TRIM(norm_zip5)) >= 5
          AND (norm_state = 'NC' OR norm_state IS NULL)
        ORDER BY contributor_id,
            CASE WHEN norm_street IS NOT NULL AND norm_street != '' THEN 0 ELSE 1 END,
            CASE WHEN norm_city IS NOT NULL AND norm_city != '' THEN 0 ELSE 1 END,
            id
    )
    """

    # Exclude already matched
    exclude_clause = """
    AND f.contributor_id NOT IN (SELECT fec_contributor_id FROM public.fec_voter_matches)
    """

    # Tier 1: address + name + zip5
    tier1_sql = f"""
    WITH {fec_cte}
    INSERT INTO public.fec_voter_matches (fec_contributor_id, ncid, match_tier, match_score)
    SELECT DISTINCT ON (f.contributor_id) f.contributor_id, nv.ncid, 1, 0.95
    FROM fec f
    JOIN public.nc_voters nv
      ON LOWER(TRIM(nv.last_name)) = f.n_last
      AND ({first_name_expr} = f.n_first OR LOWER(TRIM(nv.first_name)) = f.n_first)
      AND LEFT(TRIM(COALESCE(nv.zip_code,'')), 5) = f.n_zip5
      AND f.n_street_num IS NOT NULL AND f.n_street_num != ''
      AND {street_num_expr} = f.n_street_num
    {exclude_clause}
    ORDER BY f.contributor_id, nv.ncid
    {limit_clause}
    ON CONFLICT (fec_contributor_id) DO UPDATE SET
        ncid = EXCLUDED.ncid, match_tier = EXCLUDED.match_tier,
        match_score = EXCLUDED.match_score, matched_at = now()
    """

    # Tier 2: name + zip5 + city
    tier2_sql = f"""
    WITH {fec_cte}
    INSERT INTO public.fec_voter_matches (fec_contributor_id, ncid, match_tier, match_score)
    SELECT DISTINCT ON (f.contributor_id) f.contributor_id, nv.ncid, 2, 0.85
    FROM fec f
    JOIN public.nc_voters nv
      ON LOWER(TRIM(nv.last_name)) = f.n_last
      AND ({first_name_expr} = f.n_first OR LOWER(TRIM(nv.first_name)) = f.n_first)
      AND LEFT(TRIM(COALESCE(nv.zip_code,'')), 5) = f.n_zip5
      AND (f.n_city = '' OR LOWER(TRIM(COALESCE(nv.res_city_desc,''))) = f.n_city)
    {exclude_clause}
    ORDER BY f.contributor_id, nv.ncid
    {limit_clause}
    ON CONFLICT (fec_contributor_id) DO UPDATE SET
        ncid = EXCLUDED.ncid, match_tier = EXCLUDED.match_tier,
        match_score = EXCLUDED.match_score, matched_at = now()
    """

    # Tier 3: name + zip5 only
    tier3_sql = f"""
    WITH {fec_cte}
    INSERT INTO public.fec_voter_matches (fec_contributor_id, ncid, match_tier, match_score)
    SELECT DISTINCT ON (f.contributor_id) f.contributor_id, nv.ncid, 3, 0.70
    FROM fec f
    JOIN public.nc_voters nv
      ON LOWER(TRIM(nv.last_name)) = f.n_last
      AND ({first_name_expr} = f.n_first OR LOWER(TRIM(nv.first_name)) = f.n_first)
      AND LEFT(TRIM(COALESCE(nv.zip_code,'')), 5) = f.n_zip5
    {exclude_clause}
    ORDER BY f.contributor_id, nv.ncid
    {limit_clause}
    ON CONFLICT (fec_contributor_id) DO UPDATE SET
        ncid = EXCLUDED.ncid, match_tier = EXCLUDED.match_tier,
        match_score = EXCLUDED.match_score, matched_at = now()
    """

    # Get total FEC contributors (NC) for stats
    cur.execute(f"""
        WITH {fec_cte}
        SELECT COUNT(*) FROM fec
    """)
    total = cur.fetchone()[0]

    if total == 0:
        logger.warning("No FEC contributors to match (NC filter may be too strict)")
        return {"total": 0, "matched": 0, "tier_1": 0, "tier_2": 0, "tier_3": 0}

    logger.info(f"Processing {total:,} unique FEC contributors (NC)")

    tier_1 = tier_2 = tier_3 = 0
    if not dry_run:
        cur.execute("SELECT COUNT(*) FROM public.fec_voter_matches")
        before = cur.fetchone()[0]

        logger.info("Running Tier 1 (address+name+zip)...")
        cur.execute(tier1_sql)
        tier_1 = cur.rowcount

        logger.info("Running Tier 2 (name+zip+city)...")
        cur.execute(tier2_sql)
        tier_2 = cur.rowcount

        logger.info("Running Tier 3 (name+zip only)...")
        cur.execute(tier3_sql)
        tier_3 = cur.rowcount

        conn.commit()
        cur.execute("SELECT COUNT(*) FROM public.fec_voter_matches")
        after = cur.fetchone()[0]
        logger.info(f"Total matches in fec_voter_matches: {after:,}")

    matched = tier_1 + tier_2 + tier_3
    stats = {
        "total": total,
        "matched": matched,
        "tier_1": tier_1,
        "tier_2": tier_2,
        "tier_3": tier_3,
        "match_rate_pct": round(100 * matched / total, 1) if total else 0,
    }
    return stats


def main() -> int:
    parser = argparse.ArgumentParser(description="FEC donor → NC voter matcher")
    parser.add_argument("--batch-size", type=int, default=0, help="Max new matches per tier (0=all)")
    parser.add_argument("--dry-run", action="store_true", help="Do not write to fec_voter_matches")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(message)s",
    )

    url = _get_db_url()
    conn = psycopg2.connect(url)

    try:
        stats = run_matching(
            conn,
            batch_size=args.batch_size,
            dry_run=args.dry_run,
        )
        print("\n--- Match Report ---")
        print(f"Total FEC contributors (NC): {stats['total']:,}")
        print(f"New matches this run: {stats['matched']:,}")
        print(f"  Tier 1 (address+name+zip): {stats['tier_1']:,}")
        print(f"  Tier 2 (name+zip+city):    {stats['tier_2']:,}")
        print(f"  Tier 3 (name+zip only):   {stats['tier_3']:,}")
        if args.dry_run:
            print("(Dry run — no rows written)")
        return 0
    except Exception as e:
        logger.exception(str(e))
        return 1
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
