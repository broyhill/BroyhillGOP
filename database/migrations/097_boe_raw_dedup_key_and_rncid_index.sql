-- Migration 097: Populate dedup_key + add rncid index on nc_boe_donations_raw
-- Authorized by: Ed Broyhill, April 8, 2026
-- Scope: All 2,431,198 rows — fast single UPDATE + DDL index
-- Run BEFORE voter matching (098) — dedup_key needed for clustering

-- STEP 1: Add rncid index (DDL — fast, no data change)
CREATE INDEX IF NOT EXISTS idx_boe_raw_rncid
    ON public.nc_boe_donations_raw (rncid)
    WHERE rncid IS NOT NULL;

-- STEP 2: Populate dedup_key on all NULL rows
-- Key = norm_last | norm_first | norm_zip5 | amount | date
-- Uses existing norm columns — no joins needed
UPDATE public.nc_boe_donations_raw
SET dedup_key = norm_last
    || '|' || COALESCE(norm_first, '')
    || '|' || COALESCE(norm_zip5, '')
    || '|' || COALESCE(amount_numeric::text, '')
    || '|' || COALESCE(date_occurred::text, '')
WHERE dedup_key IS NULL;

-- NOTE: Run as single UPDATE — uses existing idx_donations_match partial index
-- (WHERE voter_ncid IS NULL covers WHERE dedup_key IS NULL at this stage)

-- Post-check:
-- SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE dedup_key IS NULL;
-- Expected: 0 (or near-zero for rows with all NULL key components)
