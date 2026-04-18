-- ============================================================================
-- PHASE 2 — Post-load verification (Hetzner side)
-- Run AFTER 03_replicate.py load completes.
-- Safe: read-only.  Expected runtime < 10 seconds.
-- ============================================================================

\echo
\echo '=== 1) Sacred spine integrity (must NOT have been touched) ==='
SELECT
  COUNT(*)                         AS ncboe_rows,            -- expect 321,348
  COUNT(DISTINCT cluster_id)       AS clusters,              -- expect  98,303
  COUNT(*) FILTER (WHERE rnc_regid IS NOT NULL) AS voter_matched,
  COUNT(*) FILTER (WHERE personal_email IS NOT NULL) AS email_populated
FROM raw.ncboe_donations;

\echo
\echo '=== 2) Ed canary (cluster 372171) — expect 147 / $332,631.30 / ed@broyhill.net ==='
SELECT
  cluster_id,
  COUNT(*)                     AS txns,
  SUM(norm_amount)             AS total,
  MAX(personal_email)          AS p_email,
  MAX(cell_phone)              AS cell
FROM raw.ncboe_donations
WHERE cluster_id = 372171
GROUP BY cluster_id;

\echo
\echo '=== 3) Phase 2 target row counts ==='
SELECT tbl, rows, expected, (rows - expected) AS delta
FROM committee.v_matching_machine_status
WHERE tbl IN (
  'committee.boe_donation_candidate_map',
  'committee.ncsbe_candidates_full',
  'committee.fec_committee_candidate_lookup'
)
ORDER BY tbl;

\echo
\echo '=== 4) Full matching-machine dashboard (all 13 tables) ==='
SELECT tbl,
       to_char(rows, 'FM999,999,999')     AS rows,
       to_char(expected, 'FM999,999,999') AS expected,
       CASE WHEN rows = expected THEN 'OK'
            WHEN rows = 0         THEN 'EMPTY'
            ELSE 'DRIFT'
       END AS status
FROM committee.v_matching_machine_status
ORDER BY expected DESC;

\echo
\echo '=== 5) BOE donation -> candidate MATCH RATE ==='
-- April 1 Cursor audit reported 99.67%.  On Supabase today the full table
-- shows 73.9%.  This query tells us the truth on Hetzner after load.
SELECT
  COUNT(*)                                                            AS total_rows,
  COUNT(*) FILTER (WHERE candidate_name IS NOT NULL)                  AS matched,
  ROUND(100.0 * COUNT(*) FILTER (WHERE candidate_name IS NOT NULL)
              / NULLIF(COUNT(*), 0), 2)                               AS match_pct,
  COUNT(*) FILTER (WHERE fec_committee_id IS NOT NULL)                AS fec_linked,
  COUNT(DISTINCT candidate_name)                                      AS distinct_candidates,
  COUNT(DISTINCT committee_sboe_id)                                   AS distinct_committees
FROM committee.boe_donation_candidate_map;

\echo
\echo '=== 6) Match-rate by office_level (where mismatches concentrate) ==='
SELECT
  office_level,
  COUNT(*)                                                            AS rows,
  COUNT(*) FILTER (WHERE candidate_name IS NOT NULL)                  AS matched,
  ROUND(100.0 * COUNT(*) FILTER (WHERE candidate_name IS NOT NULL)
              / NULLIF(COUNT(*), 0), 2)                               AS match_pct
FROM committee.boe_donation_candidate_map
GROUP BY office_level
ORDER BY rows DESC
LIMIT 20;

\echo
\echo '=== 7) Ed canary cross-check against the matching machine ==='
-- Ed's spine cluster 372171 has 147 donations.  How many of those
-- got matched to a candidate by the machine?
WITH ed_donations AS (
  SELECT DISTINCT ON (norm_last, norm_first, street_line_1, date_occurred,
                      norm_amount, candidate_referendum_name, committee_sboe_id)
    norm_last, norm_first, norm_zip5, date_occurred,
    norm_amount, committee_sboe_id, candidate_referendum_name
  FROM raw.ncboe_donations
  WHERE cluster_id = 372171
)
SELECT
  COUNT(*)                                                            AS ed_donations,
  COUNT(m.boe_id)                                                     AS map_rows_found,
  COUNT(*) FILTER (WHERE m.candidate_name IS NOT NULL)                AS map_rows_with_candidate,
  ROUND(100.0 * COUNT(*) FILTER (WHERE m.candidate_name IS NOT NULL)
              / NULLIF(COUNT(m.boe_id), 0), 2)                        AS map_match_pct
FROM ed_donations e
LEFT JOIN committee.boe_donation_candidate_map m
  ON  m.norm_last      = e.norm_last
  AND m.norm_first     = e.norm_first
  AND m.norm_zip5      = e.norm_zip5
  AND m.date_occurred  = e.date_occurred
  AND m.amount_numeric = e.norm_amount
  AND m.committee_sboe_id = e.committee_sboe_id;

\echo
\echo '=== 8) Sample: Ed donations that DID match vs DID NOT ==='
SELECT candidate_name, contest_name, office_level,
       date_occurred, amount_numeric, committee_name
FROM committee.boe_donation_candidate_map
WHERE norm_last = 'BROYHILL' AND norm_first = 'EDGAR'
ORDER BY date_occurred DESC
LIMIT 25;

\echo
\echo '=== 9) Cross-reference: FEC committees with 0 candidate_id ==='
-- We grew from 770 to 2,012 rows.  How many still have no candidate_id
-- (unresolved)?  These are federal committees the machine could not attach
-- to a specific candidate — expected for PACs / leadership committees.
SELECT
  match_method,
  COUNT(*)                                                            AS rows,
  ROUND(AVG(match_confidence)::numeric, 2)                            AS avg_conf
FROM committee.fec_committee_candidate_lookup
GROUP BY match_method
ORDER BY rows DESC;

\echo
\echo '=== 10) NCSBE candidates: partisanship distribution ==='
SELECT party_candidate, COUNT(*) AS rows
FROM committee.ncsbe_candidates_full
GROUP BY party_candidate
ORDER BY rows DESC
LIMIT 10;

\echo
\echo '=== DONE ==='
