-- ============================================================
-- BroyhillGOP Database Completion Fixes
-- Session: March 23, 2026
-- Run these in the Supabase SQL Editor ONE BLOCK AT A TIME
-- ============================================================

-- ============================================================
-- BLOCK A: Add is_donor to core.person_spine + populate
-- ============================================================
ALTER TABLE core.person_spine ADD COLUMN IF NOT EXISTS is_donor boolean DEFAULT false;

UPDATE core.person_spine ps
SET is_donor = true
FROM (SELECT DISTINCT person_id FROM core.contribution_map) cm
WHERE cm.person_id = ps.person_id
  AND (ps.is_donor IS NULL OR ps.is_donor = false);

-- VERIFY:
SELECT COUNT(*) as total, COUNT(CASE WHEN is_donor=true THEN 1 END) as is_donor_true
FROM core.person_spine;

-- ============================================================
-- BLOCK B: Update spine aggregates from contribution_map
-- ============================================================
UPDATE core.person_spine ps SET
  total_contributed = agg.total_amt,
  contribution_count = agg.cnt,
  first_contribution = agg.first_dt,
  last_contribution  = agg.last_dt,
  updated_at = NOW()
FROM (
  SELECT person_id,
    SUM(amount) AS total_amt,
    COUNT(*)    AS cnt,
    MIN(transaction_date) AS first_dt,
    MAX(transaction_date) AS last_dt
  FROM core.contribution_map
  GROUP BY person_id
) agg
WHERE ps.person_id = agg.person_id;

-- VERIFY:
SELECT
  COUNT(*) as total_spine,
  COUNT(CASE WHEN total_contributed > 0 THEN 1 END) as has_contributions,
  COUNT(CASE WHEN is_donor = true THEN 1 END) as is_donor_true,
  COUNT(voter_rncid) as has_rncid,
  ROUND(SUM(total_contributed)) as total_dollars
FROM core.person_spine;

-- ============================================================
-- BLOCK C: Insert WinRed donors missing from spine
-- (winred_donors has voter_ncid, norm_last, norm_first, zip5)
-- ============================================================
INSERT INTO core.person_spine (
  last_name, first_name, norm_last, norm_first, zip5,
  voter_ncid, is_donor, total_contributed,
  created_at, updated_at, is_active, version
)
SELECT DISTINCT ON (wd.voter_ncid)
  wd.norm_last, wd.norm_first, wd.norm_last, wd.norm_first, wd.zip5,
  wd.voter_ncid,
  true,
  wd.cash_amount,
  NOW(), NOW(), true, 1
FROM public.winred_donors wd
WHERE wd.voter_ncid IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM core.person_spine ps WHERE ps.voter_ncid = wd.voter_ncid
  )
ORDER BY wd.voter_ncid, wd.id;

-- VERIFY:
SELECT COUNT(*) as total_spine FROM core.person_spine;

-- ============================================================
-- BLOCK D: Add WinRed to core.contribution_map
-- ============================================================
-- Check what's already there
SELECT source_system, COUNT(*) FROM core.contribution_map
GROUP BY source_system ORDER BY COUNT(*) DESC;

-- Insert WinRed entries
INSERT INTO core.contribution_map (
  person_id, source_system, source_id, amount, transaction_date, created_at
)
SELECT
  ps.person_id,
  'winred',
  wd.id,
  wd.cash_amount,
  wd.donation_date,
  NOW()
FROM public.winred_donors wd
JOIN core.person_spine ps ON ps.voter_ncid = wd.voter_ncid
WHERE wd.voter_ncid IS NOT NULL
ON CONFLICT (source_system, source_id) DO NOTHING;

-- VERIFY:
SELECT source_system, COUNT(*), ROUND(SUM(amount)) as dollars
FROM core.contribution_map
GROUP BY source_system ORDER BY COUNT(*) DESC;

-- ============================================================
-- BLOCK E: Stamp rnc_rncid on public.person_master from spine
-- ============================================================
UPDATE public.person_master pm
SET rnc_rncid = ps.voter_rncid
FROM core.person_spine ps
WHERE pm.ncvoter_ncid = ps.voter_ncid
  AND ps.voter_rncid IS NOT NULL
  AND (pm.rnc_rncid IS NULL OR pm.rnc_rncid = '');

-- VERIFY (run as separate query, person_master is 7.66M rows — may be slow):
SELECT COUNT(rnc_rncid) as has_rnc_rncid FROM public.person_master LIMIT 1;

-- ============================================================
-- BLOCK F: Stamp is_donor on public.person_master
-- ============================================================
UPDATE public.person_master pm
SET is_donor = true
FROM core.person_spine ps
WHERE pm.ncvoter_ncid = ps.voter_ncid
  AND ps.is_donor = true
  AND (pm.is_donor IS NULL OR pm.is_donor = false);

-- ============================================================
-- BLOCK G: Write voter_rncid back to nc_boe_donations_raw
-- from rnc_voter_staging for any remaining unmatched rows
-- (Covers the 69,490 resolved queue rows that weren't written back)
-- ============================================================
UPDATE public.nc_boe_donations_raw boe
SET
  rncid       = q.resolved_rncid,
  voter_ncid  = COALESCE(boe.voter_ncid, q.resolved_voter_ncid)
FROM public.rncid_resolution_queue q
WHERE q.source_table = 'nc_boe_donations_raw'
  AND q.source_id    = boe.id
  AND q.resolved_rncid IS NOT NULL
  AND boe.rncid IS NULL;

-- VERIFY:
SELECT COUNT(*) as total, COUNT(rncid) as has_rncid,
  ROUND(COUNT(rncid)::numeric/COUNT(*)*100,1) as pct
FROM public.nc_boe_donations_raw;

-- ============================================================
-- BLOCK H: Stamp new BOE-matched RNCIDs onto spine
-- ============================================================
UPDATE core.person_spine ps
SET voter_rncid = boe.rncid, updated_at = NOW()
FROM (
  SELECT DISTINCT ON (voter_ncid) voter_ncid, rncid
  FROM public.nc_boe_donations_raw
  WHERE voter_ncid IS NOT NULL AND rncid IS NOT NULL
  ORDER BY voter_ncid, rncid
) boe
WHERE boe.voter_ncid = ps.voter_ncid AND ps.voter_rncid IS NULL;

-- VERIFY:
SELECT COUNT(*) as total, COUNT(voter_rncid) as has_rncid,
  ROUND(COUNT(voter_rncid)::numeric/COUNT(*)*100,1) as pct_rncid
FROM core.person_spine;

-- ============================================================
-- BLOCK I: Batched fuzzy match (first 20K rows, zip-anchored)
-- Only run if GiST indexes confirmed present
-- ============================================================
SET statement_timeout = '110000';

UPDATE public.rncid_resolution_queue q
SET
  resolved_rncid       = m.rncid::text,
  resolved_voter_ncid  = m.state_voter_id,
  match_confidence     = m.sim,
  match_method         = 'fuzzy_last_zip',
  status               = 'resolved',
  resolved_at          = NOW()
FROM (
  SELECT DISTINCT ON (q2.id)
    q2.id  AS queue_id,
    rvs.rncid,
    rvs.state_voter_id,
    similarity(rvs.norm_last, q2.input_last_name) AS sim
  FROM (
    SELECT * FROM public.rncid_resolution_queue
    WHERE resolved_rncid IS NULL ORDER BY id LIMIT 20000
  ) q2
  JOIN public.rnc_voter_staging rvs
    ON rvs.zip5 = q2.input_zip
   AND rvs.norm_last % q2.input_last_name
  WHERE similarity(rvs.norm_last, q2.input_last_name) >= 0.82
  ORDER BY q2.id, similarity(rvs.norm_last, q2.input_last_name) DESC
) m
WHERE q.id = m.queue_id AND q.resolved_rncid IS NULL;

-- VERIFY:
SELECT COUNT(*) as total, COUNT(resolved_rncid) as resolved,
  COUNT(CASE WHEN resolved_rncid IS NULL THEN 1 END) as still_unresolved
FROM public.rncid_resolution_queue;

-- ============================================================
-- BLOCK J: FINAL STATE AUDIT
-- ============================================================
SELECT
  'core.person_spine'       AS tbl, COUNT(*) AS rows FROM core.person_spine
UNION ALL SELECT
  'core.contribution_map',         COUNT(*) FROM core.contribution_map
UNION ALL SELECT
  'core.fec_donation_person_map',  COUNT(*) FROM core.fec_donation_person_map
UNION ALL SELECT
  'core.golden_record_person_map', COUNT(*) FROM core.golden_record_person_map
UNION ALL SELECT
  'public.fec_committees',         COUNT(*) FROM public.fec_committees
UNION ALL SELECT
  'public.nc_boe_donations_raw',   COUNT(*) FROM public.nc_boe_donations_raw
UNION ALL SELECT
  'public.fec_donations',          COUNT(*) FROM public.fec_donations
UNION ALL SELECT
  'public.winred_donors',          COUNT(*) FROM public.winred_donors
UNION ALL SELECT
  'public.rnc_voter_staging',      COUNT(*) FROM public.rnc_voter_staging
UNION ALL SELECT
  'public.rncid_resolution_queue', COUNT(*) FROM public.rncid_resolution_queue
ORDER BY tbl;

-- RNCID coverage on spine:
SELECT
  COUNT(*) AS total_spine,
  COUNT(voter_rncid) AS has_rncid,
  ROUND(COUNT(voter_rncid)::numeric/COUNT(*)*100,1) AS pct_rncid,
  COUNT(CASE WHEN is_donor=true THEN 1 END) AS is_donor_true,
  COUNT(CASE WHEN total_contributed>0 THEN 1 END) AS has_contributions
FROM core.person_spine;
