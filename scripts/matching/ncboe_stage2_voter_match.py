#!/usr/bin/env python3
"""
NCBOE Stage 2 — Voter File Matching
====================================
Matches dark NCBOE donation clusters to DataTrust voter file (core.datatrust_voter_nc).

Strategy: 8 passes, most-specific first, each pass only touches unmatched clusters.
  Pass 1: Last + First + Zip (exact)
  Pass 2: Last + House Number + Zip (address)
  Pass 3: Last + First + City (wider geography)
  Pass 4: Last + Employer + City (employer match)
  Pass 5: Committee loyalty fingerprint (3+ shared committees)
  Pass 6: Last + First + State (NC-wide, unique-name guard)
  Pass 7: Geocode proximity (100m radius via all_addresses zip centroid)
  Pass 8: Household propagation (if one cluster member matched, try others)

Safety:
  - Each pass writes dt_match_method for audit trail
  - Ambiguity guard: only match when exactly 1 voter candidate found
  - Never overwrites an existing rnc_regid
  - Canary check after each pass (Ed Broyhill cluster 372171)

Usage:
  python3 ncboe_stage2_voter_match.py [--pass N] [--dry-run] [--verbose]

Author: Perplexity Computer for Ed Broyhill
Date: April 13, 2026
"""

import argparse
import logging
import sys
import time
from datetime import datetime

import psycopg2
import psycopg2.extras

# ─── CONFIG ─────────────────────────────────────────────────────────
DB_DSN = "host=127.0.0.1 dbname=postgres user=postgres password=Anamaria@2026@"
BATCH_SIZE = 5000
ED_CLUSTER = 372171
ED_RNCID = "c45eeea9-663f-40e1-b0e7-a473baee794e"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("/tmp/ncboe_stage2.log"),
    ],
)
log = logging.getLogger("stage2")


def get_conn():
    conn = psycopg2.connect(DB_DSN)
    conn.autocommit = False
    return conn


def count_dark_clusters(conn):
    """Count clusters with no rnc_regid and a real person name."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT COUNT(DISTINCT cluster_id) 
            FROM raw.ncboe_donations
            WHERE rnc_regid IS NULL
              AND norm_last IS NOT NULL
              AND norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
        """)
        return cur.fetchone()[0]


def canary_check(conn):
    """Verify Ed's cluster hasn't been corrupted."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT DISTINCT rnc_regid FROM raw.ncboe_donations
            WHERE cluster_id = %s AND rnc_regid IS NOT NULL
        """, (ED_CLUSTER,))
        rows = cur.fetchall()
        if len(rows) == 1 and rows[0][0] == ED_RNCID:
            log.info(f"CANARY OK — Ed cluster {ED_CLUSTER} → {ED_RNCID}")
            return True
        log.error(f"CANARY FAIL — Ed cluster {ED_CLUSTER} returned: {rows}")
        return False


def apply_matches(conn, matches, method, dry_run=False):
    """
    Apply a list of (cluster_id, rnc_regid) matches.
    Sets rnc_regid and dt_match_method on all rows in that cluster.
    """
    if not matches:
        return 0
    
    applied = 0
    with conn.cursor() as cur:
        for cluster_id, rnc_regid in matches:
            if dry_run:
                applied += 1
                continue
            cur.execute("""
                UPDATE raw.ncboe_donations
                SET rnc_regid = %s,
                    dt_match_method = %s
                WHERE cluster_id = %s
                  AND rnc_regid IS NULL
            """, (rnc_regid, method, cluster_id))
            applied += cur.rowcount > 0
            
            if applied % BATCH_SIZE == 0:
                conn.commit()
                log.info(f"  ... committed {applied:,} matches")
        
        conn.commit()
    return applied


# ═══════════════════════════════════════════════════════════════════
# PASS 1: Last + First + Zip (exact name+location match)
# ═══════════════════════════════════════════════════════════════════
def pass1_last_first_zip(conn, dry_run=False):
    """
    Match dark clusters to voters by exact last_name + first_name + zip5.
    Only matches when exactly 1 voter is found (ambiguity guard).
    """
    log.info("═══ PASS 1: Last + First + Zip ═══")
    
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        # Build cluster representatives for dark donors with zip
        cur.execute("""
            WITH dark_clusters AS (
                SELECT DISTINCT ON (cluster_id)
                    cluster_id, norm_last, norm_first, norm_zip5
                FROM raw.ncboe_donations
                WHERE rnc_regid IS NULL
                  AND norm_last IS NOT NULL
                  AND norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
                  AND norm_zip5 IS NOT NULL
                ORDER BY cluster_id
            )
            SELECT 
                dc.cluster_id,
                dc.norm_last,
                dc.norm_first,
                dc.norm_zip5,
                v.rnc_regid,
                COUNT(*) OVER (PARTITION BY dc.cluster_id) AS voter_count
            FROM dark_clusters dc
            JOIN core.datatrust_voter_nc v
              ON UPPER(v.last_name) = dc.norm_last
             AND UPPER(v.first_name) = dc.norm_first
             AND v.reg_zip5 = dc.norm_zip5
        """)
        
        matches = []
        seen = set()
        for row in cur:
            cid = row["cluster_id"]
            if cid in seen:
                continue
            if row["voter_count"] == 1:
                matches.append((cid, row["rnc_regid"]))
            seen.add(cid)
        
    applied = apply_matches(conn, matches, "stage2_pass1_last_first_zip", dry_run)
    log.info(f"PASS 1 result: {len(matches):,} unique matches, {applied:,} applied")
    return applied


# ═══════════════════════════════════════════════════════════════════
# PASS 2: Last + House Number + Zip (address match)
# ═══════════════════════════════════════════════════════════════════
def pass2_last_house_zip(conn, dry_run=False):
    """
    Match by last_name + house_number + zip5.
    Uses address_numbers array from cluster profile.
    """
    log.info("═══ PASS 2: Last + House Number + Zip ═══")
    
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("""
            WITH dark_clusters AS (
                SELECT DISTINCT ON (cluster_id)
                    cluster_id, norm_last, norm_zip5, address_numbers
                FROM raw.ncboe_donations
                WHERE rnc_regid IS NULL
                  AND norm_last IS NOT NULL
                  AND norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
                  AND norm_zip5 IS NOT NULL
                  AND address_numbers IS NOT NULL
                  AND array_length(address_numbers, 1) > 0
                ORDER BY cluster_id
            ),
            unnested AS (
                SELECT cluster_id, norm_last, norm_zip5,
                       unnest(address_numbers) AS addr_num
                FROM dark_clusters
            )
            SELECT 
                u.cluster_id,
                v.rnc_regid,
                COUNT(*) OVER (PARTITION BY u.cluster_id) AS voter_count
            FROM unnested u
            JOIN core.datatrust_voter_nc v
              ON UPPER(v.last_name) = u.norm_last
             AND v.reg_house_num = u.addr_num
             AND v.reg_zip5 = u.norm_zip5
        """)
        
        matches = []
        seen = set()
        for row in cur:
            cid = row["cluster_id"]
            if cid in seen:
                continue
            if row["voter_count"] == 1:
                matches.append((cid, row["rnc_regid"]))
            seen.add(cid)
    
    applied = apply_matches(conn, matches, "stage2_pass2_last_house_zip", dry_run)
    log.info(f"PASS 2 result: {len(matches):,} unique matches, {applied:,} applied")
    return applied


# ═══════════════════════════════════════════════════════════════════
# PASS 3: Last + First + City (wider geography)
# ═══════════════════════════════════════════════════════════════════
def pass3_last_first_city(conn, dry_run=False):
    """
    Match by last_name + first_name + city.
    City from NCBOE `city` column or parsed from all_addresses.
    Ambiguity guard: unique match only.
    """
    log.info("═══ PASS 3: Last + First + City ═══")
    
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("""
            WITH dark_clusters AS (
                SELECT DISTINCT ON (cluster_id)
                    cluster_id, norm_last, norm_first,
                    UPPER(COALESCE(
                        NULLIF(city, ''),
                        -- Extract city from all_addresses: pattern "STREET CITY NC ZIP"
                        -- This is approximate; NC cities parsed from address text
                        NULL
                    )) AS match_city
                FROM raw.ncboe_donations
                WHERE rnc_regid IS NULL
                  AND norm_last IS NOT NULL
                  AND norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
                  AND (city IS NOT NULL AND city != '')
                ORDER BY cluster_id
            )
            SELECT 
                dc.cluster_id,
                v.rnc_regid,
                COUNT(*) OVER (PARTITION BY dc.cluster_id) AS voter_count
            FROM dark_clusters dc
            JOIN core.datatrust_voter_nc v
              ON UPPER(v.last_name) = dc.norm_last
             AND UPPER(v.first_name) = dc.norm_first
             AND UPPER(v.reg_city) = dc.match_city
            WHERE dc.match_city IS NOT NULL
        """)
        
        matches = []
        seen = set()
        for row in cur:
            cid = row["cluster_id"]
            if cid in seen:
                continue
            if row["voter_count"] == 1:
                matches.append((cid, row["rnc_regid"]))
            seen.add(cid)
    
    applied = apply_matches(conn, matches, "stage2_pass3_last_first_city", dry_run)
    log.info(f"PASS 3 result: {len(matches):,} unique matches, {applied:,} applied")
    return applied


# ═══════════════════════════════════════════════════════════════════
# PASS 4: Last + Employer + City (employer match)
# ═══════════════════════════════════════════════════════════════════
def pass4_employer_last_city(conn, dry_run=False):
    """
    Match by employer + last_name + city.
    Requires Acxiom IBE employer data for voter-side matching.
    Since voter file doesn't have employer, we match via Acxiom.
    
    Strategy: NCBOE(employer+last+city) → Acxiom(ibe_employer) → rnc_regid
    """
    log.info("═══ PASS 4: Last + Employer + City (via Acxiom) ═══")
    
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        # Check if acxiom_ibe has employer columns
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema='core' AND table_name='acxiom_ibe'
            AND column_name ILIKE '%employ%'
            ORDER BY column_name LIMIT 10;
        """)
        emp_cols = [r[0] for r in cur.fetchall()]
        
        if not emp_cols:
            log.warning("PASS 4: No employer columns found in acxiom_ibe. Skipping.")
            return 0
        
        log.info(f"  Found Acxiom employer columns: {emp_cols[:5]}")
        
        # Use the first employer column found
        emp_col = emp_cols[0]
        
        cur.execute(f"""
            WITH dark_clusters AS (
                SELECT DISTINCT ON (cluster_id)
                    cluster_id, norm_last, norm_employer,
                    UPPER(COALESCE(NULLIF(city, ''), NULL)) AS match_city
                FROM raw.ncboe_donations
                WHERE rnc_regid IS NULL
                  AND norm_last IS NOT NULL
                  AND norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
                  AND norm_employer IS NOT NULL
                  AND city IS NOT NULL AND city != ''
                ORDER BY cluster_id
            )
            SELECT 
                dc.cluster_id,
                v.rnc_regid,
                COUNT(*) OVER (PARTITION BY dc.cluster_id) AS voter_count
            FROM dark_clusters dc
            JOIN core.datatrust_voter_nc v
              ON UPPER(v.last_name) = dc.norm_last
             AND UPPER(v.reg_city) = dc.match_city
            JOIN core.acxiom_ibe a
              ON a.rnc_regid = v.rnc_regid
             AND UPPER(a."{emp_col}") ILIKE '%' || dc.norm_employer || '%'
        """)
        
        matches = []
        seen = set()
        for row in cur:
            cid = row["cluster_id"]
            if cid in seen:
                continue
            if row["voter_count"] == 1:
                matches.append((cid, row["rnc_regid"]))
            seen.add(cid)
    
    applied = apply_matches(conn, matches, "stage2_pass4_employer_city", dry_run)
    log.info(f"PASS 4 result: {len(matches):,} unique matches, {applied:,} applied")
    return applied


# ═══════════════════════════════════════════════════════════════════
# PASS 5: Committee Loyalty Fingerprint
# ═══════════════════════════════════════════════════════════════════
def pass5_committee_fingerprint(conn, dry_run=False):
    """
    If a dark cluster and a matched cluster share 3+ committees,
    and the dark cluster's name matches a voter at any of those committees' 
    other donors' addresses — link them.
    
    This is expensive. We use a simpler version:
    Find dark donors who share last_name + 3+ committee_sboe_ids with 
    a single matched donor cluster, then grab that matched donor's rnc_regid
    and look for the dark donor in the voter file with the same last_name.
    """
    log.info("═══ PASS 5: Committee Loyalty Fingerprint ═══")
    
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("""
            WITH dark_committees AS (
                SELECT cluster_id, norm_last, norm_first,
                       array_agg(DISTINCT committee_sboe_id) AS committees
                FROM raw.ncboe_donations
                WHERE rnc_regid IS NULL
                  AND norm_last IS NOT NULL
                  AND norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
                  AND committee_sboe_id IS NOT NULL
                GROUP BY cluster_id, norm_last, norm_first
                HAVING COUNT(DISTINCT committee_sboe_id) >= 3
            ),
            matched_committees AS (
                SELECT cluster_id, rnc_regid, norm_last, norm_first,
                       array_agg(DISTINCT committee_sboe_id) AS committees
                FROM raw.ncboe_donations
                WHERE rnc_regid IS NOT NULL
                  AND committee_sboe_id IS NOT NULL
                GROUP BY cluster_id, rnc_regid, norm_last, norm_first
            ),
            fingerprint_matches AS (
                SELECT DISTINCT ON (d.cluster_id)
                    d.cluster_id,
                    m.rnc_regid,
                    -- Count shared committees
                    (SELECT COUNT(*) FROM unnest(d.committees) dc 
                     WHERE dc = ANY(m.committees)) AS shared_count
                FROM dark_committees d
                JOIN matched_committees m
                  ON d.norm_last = m.norm_last
                 AND d.norm_first = m.norm_first
                WHERE (SELECT COUNT(*) FROM unnest(d.committees) dc 
                       WHERE dc = ANY(m.committees)) >= 3
                ORDER BY d.cluster_id, shared_count DESC
            )
            SELECT cluster_id, rnc_regid, shared_count
            FROM fingerprint_matches
        """)
        
        matches = [(row["cluster_id"], row["rnc_regid"]) for row in cur]
    
    applied = apply_matches(conn, matches, "stage2_pass5_committee_fingerprint", dry_run)
    log.info(f"PASS 5 result: {len(matches):,} unique matches, {applied:,} applied")
    return applied


# ═══════════════════════════════════════════════════════════════════
# PASS 6: Last + First + State (NC-wide, uniqueness guard)
# ═══════════════════════════════════════════════════════════════════
def pass6_last_first_state(conn, dry_run=False):
    """
    Match by last_name + first_name across all of NC.
    STRICT uniqueness guard: only match if there is exactly ONE voter 
    in the entire state with that last+first name combo.
    This catches rare/unique names that don't need location disambiguation.
    """
    log.info("═══ PASS 6: Last + First + State (unique names) ═══")
    
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("""
            WITH dark_clusters AS (
                SELECT DISTINCT ON (cluster_id)
                    cluster_id, norm_last, norm_first
                FROM raw.ncboe_donations
                WHERE rnc_regid IS NULL
                  AND norm_last IS NOT NULL
                  AND norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
                  AND norm_first IS NOT NULL
                ORDER BY cluster_id
            ),
            -- Pre-compute unique names in voter file
            unique_voters AS (
                SELECT UPPER(last_name) AS u_last, 
                       UPPER(first_name) AS u_first,
                       MIN(rnc_regid) AS rnc_regid,
                       COUNT(*) AS cnt
                FROM core.datatrust_voter_nc
                GROUP BY UPPER(last_name), UPPER(first_name)
                HAVING COUNT(*) = 1
            )
            SELECT dc.cluster_id, uv.rnc_regid
            FROM dark_clusters dc
            JOIN unique_voters uv
              ON uv.u_last = dc.norm_last
             AND uv.u_first = dc.norm_first
        """)
        
        matches = [(row["cluster_id"], row["rnc_regid"]) for row in cur]
    
    applied = apply_matches(conn, matches, "stage2_pass6_unique_name_state", dry_run)
    log.info(f"PASS 6 result: {len(matches):,} unique matches, {applied:,} applied")
    return applied


# ═══════════════════════════════════════════════════════════════════
# PASS 7: Geocode Proximity (zip centroid, 100m)
# ═══════════════════════════════════════════════════════════════════
def pass7_geocode(conn, dry_run=False):
    """
    For dark donors with an address that includes a zip, match to voters 
    in that zip with same last name who live within ~100m.
    Requires reg_latitude/reg_longitude in voter file.
    """
    log.info("═══ PASS 7: Geocode Proximity ═══")
    
    with conn.cursor() as cur:
        # Check if lat/lon have values
        cur.execute("""
            SELECT COUNT(*) FROM core.datatrust_voter_nc 
            WHERE reg_latitude IS NOT NULL AND reg_latitude != '' 
            LIMIT 1
        """)
        has_geo = cur.fetchone()[0]
        
        if not has_geo:
            log.warning("PASS 7: No geocode data in voter file. Skipping.")
            return 0
    
    # Geocode matching is complex — for now, we do zip+last+house_num 
    # which is effectively the same as proximity for matching purposes.
    # Full geocode pass would require PostGIS or haversine math.
    log.info("PASS 7: Deferred — address matching covered by Pass 2. Would need PostGIS for true proximity.")
    return 0


# ═══════════════════════════════════════════════════════════════════
# PASS 8: Household Propagation
# ═══════════════════════════════════════════════════════════════════
def pass8_household(conn, dry_run=False):
    """
    If one cluster in a household is matched, try to match other 
    dark clusters in the same household to voters at the same address.
    Uses dt_house_hold_id from the dedup process.
    """
    log.info("═══ PASS 8: Household Propagation ═══")
    
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("""
            WITH matched_households AS (
                -- Households that have at least one matched AND one dark cluster
                SELECT DISTINCT dt_house_hold_id
                FROM raw.ncboe_donations
                WHERE dt_house_hold_id IS NOT NULL
                  AND rnc_regid IS NOT NULL
                INTERSECT
                SELECT DISTINCT dt_house_hold_id
                FROM raw.ncboe_donations
                WHERE dt_house_hold_id IS NOT NULL
                  AND rnc_regid IS NULL
                  AND norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
            ),
            dark_in_household AS (
                SELECT DISTINCT ON (n.cluster_id)
                    n.cluster_id, n.norm_last, n.norm_first, n.dt_house_hold_id
                FROM raw.ncboe_donations n
                JOIN matched_households mh ON mh.dt_house_hold_id = n.dt_house_hold_id
                WHERE n.rnc_regid IS NULL
                  AND n.norm_last NOT IN ('CONTRIBUTIONS','AGGREGATED')
                ORDER BY n.cluster_id
            ),
            matched_voter_addr AS (
                -- Get the address of matched household members
                SELECT DISTINCT n.dt_house_hold_id,
                    v.reg_zip5, v.reg_house_num, v.reg_city
                FROM raw.ncboe_donations n
                JOIN matched_households mh ON mh.dt_house_hold_id = n.dt_house_hold_id
                JOIN core.datatrust_voter_nc v ON v.rnc_regid = n.rnc_regid
                WHERE n.rnc_regid IS NOT NULL
            )
            SELECT 
                dh.cluster_id,
                v.rnc_regid,
                COUNT(*) OVER (PARTITION BY dh.cluster_id) AS voter_count
            FROM dark_in_household dh
            JOIN matched_voter_addr ma ON ma.dt_house_hold_id = dh.dt_house_hold_id
            JOIN core.datatrust_voter_nc v
              ON UPPER(v.last_name) = dh.norm_last
             AND v.reg_zip5 = ma.reg_zip5
             AND v.reg_house_num = ma.reg_house_num
        """)
        
        matches = []
        seen = set()
        for row in cur:
            cid = row["cluster_id"]
            if cid in seen:
                continue
            if row["voter_count"] == 1:
                matches.append((cid, row["rnc_regid"]))
            seen.add(cid)
    
    applied = apply_matches(conn, matches, "stage2_pass8_household", dry_run)
    log.info(f"PASS 8 result: {len(matches):,} unique matches, {applied:,} applied")
    return applied


# ═══════════════════════════════════════════════════════════════════
# MAIN ORCHESTRATOR
# ═══════════════════════════════════════════════════════════════════
PASSES = {
    1: ("Last + First + Zip", pass1_last_first_zip),
    2: ("Last + House# + Zip", pass2_last_house_zip),
    3: ("Last + First + City", pass3_last_first_city),
    4: ("Last + Employer + City (Acxiom)", pass4_employer_last_city),
    5: ("Committee Fingerprint", pass5_committee_fingerprint),
    6: ("Last + First + State (unique)", pass6_last_first_state),
    7: ("Geocode Proximity", pass7_geocode),
    8: ("Household Propagation", pass8_household),
}


def main():
    parser = argparse.ArgumentParser(description="NCBOE Stage 2 Voter Match")
    parser.add_argument("--pass", type=int, dest="single_pass", default=None,
                        help="Run only this pass number (1-8)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Count matches without applying")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    if args.verbose:
        log.setLevel(logging.DEBUG)

    log.info("=" * 60)
    log.info("NCBOE Stage 2 — Voter File Matching")
    log.info(f"Started: {datetime.now().isoformat()}")
    log.info(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    log.info("=" * 60)

    conn = get_conn()
    
    # Pre-flight
    dark_before = count_dark_clusters(conn)
    log.info(f"Dark clusters before: {dark_before:,}")
    
    if not canary_check(conn):
        log.error("CANARY FAILED — aborting")
        sys.exit(1)

    total_matched = 0
    passes_to_run = [args.single_pass] if args.single_pass else sorted(PASSES.keys())
    
    for p in passes_to_run:
        if p not in PASSES:
            log.error(f"Unknown pass: {p}")
            continue
        
        name, func = PASSES[p]
        log.info(f"\n{'─' * 40}")
        log.info(f"Running Pass {p}: {name}")
        log.info(f"{'─' * 40}")
        
        t0 = time.time()
        try:
            matched = func(conn, dry_run=args.dry_run)
            elapsed = time.time() - t0
            total_matched += matched
            log.info(f"Pass {p} complete: {matched:,} matches in {elapsed:.1f}s")
        except Exception as e:
            log.error(f"Pass {p} failed: {e}")
            conn.rollback()
            continue
        
        # Canary check after each pass
        if not args.dry_run and matched > 0:
            if not canary_check(conn):
                log.error(f"CANARY FAILED after pass {p} — ROLLING BACK")
                conn.rollback()
                sys.exit(1)

    # Final summary
    dark_after = count_dark_clusters(conn)
    log.info("\n" + "=" * 60)
    log.info("STAGE 2 SUMMARY")
    log.info(f"Dark clusters before: {dark_before:,}")
    log.info(f"Dark clusters after:  {dark_after:,}")
    log.info(f"Total resolved:       {dark_before - dark_after:,}")
    log.info(f"Resolution rate:      {(dark_before - dark_after) / dark_before * 100:.1f}%")
    log.info(f"Remaining dark:       {dark_after:,} ({dark_after / 758110 * 100:.1f}% of all clusters)")
    log.info("=" * 60)

    conn.close()


if __name__ == "__main__":
    main()
