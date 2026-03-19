-- Run these queries in Supabase SQL Editor BEFORE running the pipeline.
-- Paste results back for confirmation.

-- QUERY A (FINAL GATE): nc_voters zip column — res_zip_code or zip_code?
-- If zip_code: change scripts to use v.zip_code. If res_zip_code: ready to run.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'nc_voters'
  AND column_name ILIKE ANY(ARRAY['%zip%','%first%','%last%','%city%','%voter%'])
ORDER BY column_name;

-- QUERY B: nc_boe_donations_raw columns (verify donor_name, amount column)
SELECT string_agg(column_name || ' (' || data_type || ')', E'\n' ORDER BY ordinal_position)
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'nc_boe_donations_raw';

-- QUERY C: Contamination analysis (NCGOP/RNC/FEC mixed into raw?)
-- Run before deciding Option A (truncate+rebuild) vs Option B (filter)
SELECT 
  COUNT(*) AS total,
  COUNT(email) AS has_email,
  COUNT(rncid) AS has_rncid,
  COUNT(fec_contributor_id) AS has_fec_id,
  COUNT(*) FILTER (WHERE email IS NULL AND rncid IS NULL AND fec_contributor_id IS NULL) AS pure_ncboe_estimate
FROM nc_boe_donations_raw;
