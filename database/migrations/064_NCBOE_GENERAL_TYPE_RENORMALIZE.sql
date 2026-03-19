-- 064_NCBOE_GENERAL_TYPE_RENORMALIZE.sql
-- Fix 70,283 General-type rows wrongly normalized as organizations.
-- General = persons giving to party general accounts; should be parsed like Individual.
-- Per CLAUDE-TO-CURSOR-GENERAL-NORM-FIX.md
--
-- Run: psql $DATABASE_URL -f database/migrations/064_NCBOE_GENERAL_TYPE_RENORMALIZE.sql

BEGIN;

-- Step 1: Re-parse General rows using fn_normalize_donor_name (NOT pipeline.parse_ncboe_name)
-- fn_normalize_donor_name returns canonical_first_name, last_name, first_name, suffix
UPDATE public.nc_boe_donations_raw d
SET
  norm_last = (fn_normalize_donor_name(d.donor_name)).last_name,
  norm_first = (fn_normalize_donor_name(d.donor_name)).first_name,
  name_suffix = (fn_normalize_donor_name(d.donor_name)).suffix,
  canonical_first = (fn_normalize_donor_name(d.donor_name)).canonical_first_name,
  is_organization = false,
  donor_type = 'General',
  content_hash = NULL,
  dedup_key = NULL
WHERE d.transaction_type = 'General'
  AND (d.is_organization = true OR d.norm_last = UPPER(TRIM(COALESCE(d.donor_name, ''))));

-- Step 2: Fallback canonical_first = norm_first where fn_normalize returned NULL
UPDATE public.nc_boe_donations_raw
SET canonical_first = norm_first
WHERE transaction_type = 'General'
  AND canonical_first IS NULL
  AND norm_first IS NOT NULL;

-- Step 3: Re-derive content_hash and dedup_key
UPDATE public.nc_boe_donations_raw
SET content_hash = pipeline.content_hash_ncboe(
  norm_last,
  COALESCE(canonical_first, ''),
  COALESCE(norm_zip5, ''),
  date_occurred,
  amount_numeric
)
WHERE transaction_type = 'General'
  AND content_hash IS NULL
  AND norm_last IS NOT NULL
  AND date_occurred IS NOT NULL
  AND amount_numeric IS NOT NULL;

UPDATE public.nc_boe_donations_raw
SET dedup_key = pipeline.dedup_key_ncboe(content_hash, id::text)
WHERE transaction_type = 'General'
  AND dedup_key IS NULL
  AND content_hash IS NOT NULL;

COMMIT;

-- Validation: Art Pope should return ~155 txns / ~$1,190,719
-- SELECT COUNT(*) as txns, SUM(amount_numeric)::numeric(12,2) as total
-- FROM nc_boe_donations_raw
-- WHERE norm_last = 'POPE'
--   AND (norm_first IN ('ART','JAMES','ARTHRU') OR donor_name ILIKE '%art%pope%')
--   AND donor_name NOT ILIKE '%james w pope%'
--   AND donor_name NOT ILIKE '%james larry%'
--   AND NOT (donor_name = 'JAMES POPE' AND city = 'LILLINGTON');
