#!/usr/bin/env python3
"""
DataTrust Name + ID Sync Enrichment for raw.ncboe_donations

Matches donor rows to DataTrust voter file and stamps:
  - rnc_regid       (RNC national voter UUID — permanent, links to Acxiom)
  - state_voter_id  (NC SBOE ncid — links to RNC VoterSnapshot)
  - dt_first        (DataTrust canonical first name)
  - dt_middle       (DataTrust full middle name)
  - dt_last         (DataTrust canonical last name) 
  - dt_suffix       (JR, SR, II, III, IV)
  - dt_prefix       (MR, MS)
  - dt_zip4         (zip+4 suffix from voter registration)
  - dt_house_hold_id (DataTrust household grouping ID)
  - dt_match_method (how the match was made: exact/middle_name/initial/prefix)

Join chain (per Zach Imel, RNC Data Director):
  ncid = state_voter_id → rnc_regid → Acxiom.rnc_regid

Does NOT overwrite any existing raw data. Additive only.
"""

import logging
import sys
import time
import psycopg2

DB_URL = "postgresql://postgres:Anamaria%402026%40@127.0.0.1:5432/postgres"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler("/tmp/datatrust_enrich.log", mode='w'),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("dt_enrich")


def run():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = False

    with conn.cursor() as cur:
        # ── Step 1: Add columns if they don't exist ──
        log.info("Step 1: Adding enrichment columns...")
        for col, dtype in [
            ("rnc_regid", "text"),
            ("state_voter_id", "text"),
            ("dt_first", "text"),
            ("dt_middle", "text"),
            ("dt_last", "text"),
            ("dt_suffix", "text"),
            ("dt_prefix", "text"),
            ("dt_zip4", "text"),
            ("dt_house_hold_id", "integer"),
            ("dt_match_method", "text"),
        ]:
            cur.execute(f"""
                ALTER TABLE raw.ncboe_donations 
                ADD COLUMN IF NOT EXISTS {col} {dtype}
            """)
        conn.commit()
        log.info("  Columns ready.")

        # ── Step 2: Exact match — donor (norm_first, norm_last, norm_zip5) = voter (first_name, last_name, reg_zip5) ──
        # Only match where exactly ONE voter matches (no ambiguity)
        log.info("Step 2: Exact first+last+zip5 match (unique voter only)...")
        t0 = time.time()
        cur.execute("""
            WITH unique_voters AS (
                SELECT first_name, last_name, reg_zip5,
                       MIN(rnc_regid) AS rnc_regid,
                       MIN(state_voter_id) AS state_voter_id,
                       MIN(middle_name) AS middle_name,
                       MIN(name_suffix) AS name_suffix,
                       MIN(name_prefix) AS name_prefix,
                       MIN(reg_zip4) AS reg_zip4,
                       MIN(house_hold_id) AS house_hold_id
                FROM core.datatrust_voter_nc
                WHERE first_name IS NOT NULL AND last_name IS NOT NULL AND reg_zip5 IS NOT NULL
                GROUP BY first_name, last_name, reg_zip5
                HAVING COUNT(*) = 1
            )
            UPDATE raw.ncboe_donations d
            SET rnc_regid = v.rnc_regid,
                state_voter_id = v.state_voter_id,
                dt_first = v.first_name,
                dt_middle = v.middle_name,
                dt_last = v.last_name,
                dt_suffix = v.name_suffix,
                dt_prefix = v.name_prefix,
                dt_zip4 = v.reg_zip4,
                dt_house_hold_id = v.house_hold_id,
                dt_match_method = 'exact_unique'
            FROM unique_voters v
            WHERE d.norm_first = v.first_name
              AND d.norm_last = v.last_name
              AND d.norm_zip5 = v.reg_zip5
              AND d.rnc_regid IS NULL
        """)
        n = cur.rowcount
        conn.commit()
        log.info(f"  exact_unique: {n:,} rows enriched in {time.time()-t0:.1f}s")

        # ── Step 3: Exact match with multiple voters — pick by middle name if donor has one ──
        log.info("Step 3: Exact first+last+zip5 with middle name disambiguation...")
        t0 = time.time()
        cur.execute("""
            WITH multi_voters AS (
                SELECT first_name, last_name, reg_zip5, middle_name,
                       rnc_regid, state_voter_id, name_suffix, name_prefix,
                       reg_zip4, house_hold_id,
                       ROW_NUMBER() OVER (
                           PARTITION BY first_name, last_name, reg_zip5
                           ORDER BY 
                               CASE WHEN middle_name IS NOT NULL AND middle_name != '' THEN 0 ELSE 1 END,
                               rnc_regid
                       ) AS rn,
                       COUNT(*) OVER (PARTITION BY first_name, last_name, reg_zip5) AS cnt
                FROM core.datatrust_voter_nc
                WHERE first_name IS NOT NULL AND last_name IS NOT NULL AND reg_zip5 IS NOT NULL
            )
            UPDATE raw.ncboe_donations d
            SET rnc_regid = v.rnc_regid,
                state_voter_id = v.state_voter_id,
                dt_first = v.first_name,
                dt_middle = v.middle_name,
                dt_last = v.last_name,
                dt_suffix = v.name_suffix,
                dt_prefix = v.name_prefix,
                dt_zip4 = v.reg_zip4,
                dt_house_hold_id = v.house_hold_id,
                dt_match_method = CASE 
                    WHEN d.norm_middle IS NOT NULL AND d.norm_middle != '' 
                         AND v.middle_name IS NOT NULL AND LEFT(v.middle_name, LENGTH(d.norm_middle)) = d.norm_middle
                    THEN 'exact_middle_confirm'
                    ELSE 'exact_multi_best'
                END
            FROM multi_voters v
            WHERE d.norm_first = v.first_name
              AND d.norm_last = v.last_name
              AND d.norm_zip5 = v.reg_zip5
              AND v.cnt BETWEEN 2 AND 5
              AND v.rn = 1
              AND d.rnc_regid IS NULL
              AND (
                  -- Either donor has a middle that matches voter middle prefix
                  (d.norm_middle IS NOT NULL AND d.norm_middle != '' 
                   AND v.middle_name IS NOT NULL AND LEFT(v.middle_name, LENGTH(d.norm_middle)) = d.norm_middle)
                  -- Or we just take the best candidate for small groups (2-3)
                  OR v.cnt <= 3
              )
        """)
        n = cur.rowcount
        conn.commit()
        log.info(f"  exact_multi: {n:,} rows enriched in {time.time()-t0:.1f}s")

        # ── Step 4: Donor first name = voter MIDDLE name (ED → voter middle=EDGAR contains ED?) ──
        # Actually: donor files as "ED", voter registered as JAMES EDGAR BROYHILL → match on middle
        log.info("Step 4: Donor first = voter middle name (same last+zip, unique match)...")
        t0 = time.time()
        cur.execute("""
            WITH middle_matches AS (
                SELECT v.middle_name AS donor_first_match,
                       v.last_name, v.reg_zip5,
                       v.rnc_regid, v.state_voter_id, v.first_name,
                       v.middle_name, v.name_suffix, v.name_prefix,
                       v.reg_zip4, v.house_hold_id
                FROM core.datatrust_voter_nc v
                WHERE v.middle_name IS NOT NULL AND v.middle_name != ''
                  AND v.last_name IS NOT NULL AND v.reg_zip5 IS NOT NULL
            ),
            unique_middle AS (
                SELECT donor_first_match, last_name, reg_zip5,
                       MIN(rnc_regid) AS rnc_regid,
                       MIN(state_voter_id) AS state_voter_id,
                       MIN(first_name) AS first_name,
                       MIN(middle_name) AS middle_name,
                       MIN(name_suffix) AS name_suffix,
                       MIN(name_prefix) AS name_prefix,
                       MIN(reg_zip4) AS reg_zip4,
                       MIN(house_hold_id) AS house_hold_id
                FROM middle_matches
                GROUP BY donor_first_match, last_name, reg_zip5
                HAVING COUNT(*) = 1
            )
            UPDATE raw.ncboe_donations d
            SET rnc_regid = v.rnc_regid,
                state_voter_id = v.state_voter_id,
                dt_first = v.first_name,
                dt_middle = v.middle_name,
                dt_last = v.last_name,
                dt_suffix = v.name_suffix,
                dt_prefix = v.name_prefix,
                dt_zip4 = v.reg_zip4,
                dt_house_hold_id = v.house_hold_id,
                dt_match_method = 'middle_name_match'
            FROM unique_middle v
            WHERE d.norm_first = v.donor_first_match
              AND d.norm_last = v.last_name
              AND d.norm_zip5 = v.reg_zip5
              AND d.rnc_regid IS NULL
        """)
        n = cur.rowcount
        conn.commit()
        log.info(f"  middle_name: {n:,} rows enriched in {time.time()-t0:.1f}s")

        # ── Step 5: Donor first is initial (J → JAMES, same last+zip, unique match) ──
        log.info("Step 5: Single initial match (J → JAMES, unique voter)...")
        t0 = time.time()
        cur.execute("""
            WITH initial_matches AS (
                SELECT LEFT(v.first_name, 1) AS initial,
                       v.last_name, v.reg_zip5,
                       v.rnc_regid, v.state_voter_id, v.first_name,
                       v.middle_name, v.name_suffix, v.name_prefix,
                       v.reg_zip4, v.house_hold_id
                FROM core.datatrust_voter_nc v
                WHERE v.first_name IS NOT NULL AND v.last_name IS NOT NULL AND v.reg_zip5 IS NOT NULL
            ),
            unique_initial AS (
                SELECT initial, last_name, reg_zip5,
                       MIN(rnc_regid) AS rnc_regid,
                       MIN(state_voter_id) AS state_voter_id,
                       MIN(first_name) AS first_name,
                       MIN(middle_name) AS middle_name,
                       MIN(name_suffix) AS name_suffix,
                       MIN(name_prefix) AS name_prefix,
                       MIN(reg_zip4) AS reg_zip4,
                       MIN(house_hold_id) AS house_hold_id
                FROM initial_matches
                GROUP BY initial, last_name, reg_zip5
                HAVING COUNT(DISTINCT rnc_regid) = 1
            )
            UPDATE raw.ncboe_donations d
            SET rnc_regid = v.rnc_regid,
                state_voter_id = v.state_voter_id,
                dt_first = v.first_name,
                dt_middle = v.middle_name,
                dt_last = v.last_name,
                dt_suffix = v.name_suffix,
                dt_prefix = v.name_prefix,
                dt_zip4 = v.reg_zip4,
                dt_house_hold_id = v.house_hold_id,
                dt_match_method = 'initial_match'
            FROM unique_initial v
            WHERE LENGTH(d.norm_first) = 1
              AND d.norm_first = v.initial
              AND d.norm_last = v.last_name
              AND d.norm_zip5 = v.reg_zip5
              AND d.rnc_regid IS NULL
        """)
        n = cur.rowcount
        conn.commit()
        log.info(f"  initial: {n:,} rows enriched in {time.time()-t0:.1f}s")

        # ── Step 6: Donor first is prefix of voter first (ROB → ROBERT, unique match) ──
        log.info("Step 6: Prefix match (ROB → ROBERT, unique voter, min 3 chars)...")
        t0 = time.time()
        cur.execute("""
            UPDATE raw.ncboe_donations d
            SET rnc_regid = v.rnc_regid,
                state_voter_id = v.state_voter_id,
                dt_first = v.first_name,
                dt_middle = v.middle_name,
                dt_last = v.last_name,
                dt_suffix = v.name_suffix,
                dt_prefix = v.name_prefix,
                dt_zip4 = v.reg_zip4,
                dt_house_hold_id = v.house_hold_id,
                dt_match_method = 'prefix_match'
            FROM (
                SELECT v.first_name, v.last_name, v.reg_zip5,
                       v.rnc_regid, v.state_voter_id, v.middle_name,
                       v.name_suffix, v.name_prefix, v.reg_zip4, v.house_hold_id,
                       d_sub.norm_first AS donor_first
                FROM raw.ncboe_donations d_sub
                JOIN core.datatrust_voter_nc v
                  ON v.last_name = d_sub.norm_last
                  AND v.reg_zip5 = d_sub.norm_zip5
                  AND v.first_name LIKE d_sub.norm_first || '%'
                  AND LENGTH(d_sub.norm_first) >= 3
                WHERE d_sub.rnc_regid IS NULL
                  AND d_sub.norm_first IS NOT NULL AND d_sub.norm_first != ''
                  AND d_sub.norm_last IS NOT NULL AND d_sub.norm_zip5 IS NOT NULL
                  -- Ensure it's not an exact match (those were handled above)
                  AND v.first_name != d_sub.norm_first
            ) v
            WHERE d.norm_first = v.donor_first
              AND d.norm_last = v.last_name
              AND d.norm_zip5 = v.reg_zip5
              AND d.rnc_regid IS NULL
        """)
        n = cur.rowcount
        conn.commit()
        log.info(f"  prefix: {n:,} rows enriched in {time.time()-t0:.1f}s")

        # ── Step 7: Propagate — if same (norm_first, norm_last, norm_zip5) already has rnc_regid, copy to unmatched rows ──
        log.info("Step 7: Propagate matches to remaining rows with same name+zip...")
        t0 = time.time()
        cur.execute("""
            WITH matched AS (
                SELECT DISTINCT ON (norm_first, norm_last, norm_zip5)
                       norm_first, norm_last, norm_zip5,
                       rnc_regid, state_voter_id, dt_first, dt_middle, dt_last,
                       dt_suffix, dt_prefix, dt_zip4, dt_house_hold_id, dt_match_method
                FROM raw.ncboe_donations
                WHERE rnc_regid IS NOT NULL
                ORDER BY norm_first, norm_last, norm_zip5, dt_match_method
            )
            UPDATE raw.ncboe_donations d
            SET rnc_regid = m.rnc_regid,
                state_voter_id = m.state_voter_id,
                dt_first = m.dt_first,
                dt_middle = m.dt_middle,
                dt_last = m.dt_last,
                dt_suffix = m.dt_suffix,
                dt_prefix = m.dt_prefix,
                dt_zip4 = m.dt_zip4,
                dt_house_hold_id = m.dt_house_hold_id,
                dt_match_method = m.dt_match_method || '_propagated'
            FROM matched m
            WHERE d.norm_first = m.norm_first
              AND d.norm_last = m.norm_last
              AND d.norm_zip5 = m.norm_zip5
              AND d.rnc_regid IS NULL
        """)
        n = cur.rowcount
        conn.commit()
        log.info(f"  propagated: {n:,} rows enriched in {time.time()-t0:.1f}s")

        # ── Final stats ──
        log.info("=" * 60)
        log.info("ENRICHMENT COMPLETE — Final counts:")
        cur.execute("""
            SELECT 
                COUNT(*) AS total,
                COUNT(rnc_regid) AS has_rnc_regid,
                COUNT(state_voter_id) AS has_state_voter_id,
                COUNT(dt_zip4) FILTER (WHERE dt_zip4 IS NOT NULL AND dt_zip4 != '') AS has_zip4,
                ROUND(COUNT(rnc_regid)::numeric / COUNT(*)::numeric * 100, 1) AS pct_matched
            FROM raw.ncboe_donations
        """)
        total, matched, svid, zip4, pct = cur.fetchone()
        log.info(f"  Total rows:      {total:>12,}")
        log.info(f"  With rnc_regid:  {matched:>12,} ({pct}%)")
        log.info(f"  With state_voter_id: {svid:>12,}")
        log.info(f"  With dt_zip4:    {zip4:>12,}")

        cur.execute("""
            SELECT dt_match_method, COUNT(*) AS cnt
            FROM raw.ncboe_donations
            WHERE rnc_regid IS NOT NULL
            GROUP BY dt_match_method
            ORDER BY cnt DESC
        """)
        log.info("  Match method breakdown:")
        for method, cnt in cur.fetchall():
            log.info(f"    {method:<30s} {cnt:>10,}")

        # Ed Broyhill verification
        cur.execute("""
            SELECT DISTINCT name, rnc_regid, state_voter_id, dt_first, dt_middle, dt_suffix, dt_match_method
            FROM raw.ncboe_donations
            WHERE norm_last = 'BROYHILL' AND norm_zip5 = '27104'
              AND rnc_regid IS NOT NULL
            ORDER BY name
        """)
        log.info("  Ed Broyhill family verification:")
        for row in cur.fetchall():
            log.info(f"    {row}")

    conn.close()
    log.info("Done.")


if __name__ == "__main__":
    run()
