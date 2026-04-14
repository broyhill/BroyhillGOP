-- Migration 098: Match BOE donors → nc_voters (populate voter_ncid)
-- Authorized by: Ed Broyhill, April 8, 2026
-- Scope: 2,431,198 rows — RUN IN BATCHES of 500,000 to avoid timeout
-- Prerequisite: Migration 097 must be complete

-- PASS 1 (Primary): norm_last + canonical_first + norm_zip5
-- Covers ~70% of rows. canonical_first_name uses nickname resolution.
-- NOTE: Run in batches — wrap in a loop in Cursor or use LIMIT/OFFSET pattern

UPDATE public.nc_boe_donations_raw b
SET voter_ncid     = v.ncid,
    voter_party_cd = v.party_cd
FROM public.nc_voters v
WHERE b.voter_ncid IS NULL
  AND LOWER(TRIM(v.last_name)) = b.norm_last
  AND (
        LOWER(TRIM(v.canonical_first_name)) = b.norm_first
     OR LOWER(TRIM(v.first_name))           = b.norm_first
  )
  AND LEFT(v.zip_code, 5) = b.norm_zip5;

-- PASS 2 (Fallback — no zip): norm_last + canonical_first + norm_city
-- For the 28.1% of rows with no norm_zip5
UPDATE public.nc_boe_donations_raw b
SET voter_ncid     = v.ncid,
    voter_party_cd = v.party_cd
FROM public.nc_voters v
WHERE b.voter_ncid IS NULL
  AND b.norm_zip5 IS NULL
  AND LOWER(TRIM(v.last_name)) = b.norm_last
  AND (
        LOWER(TRIM(v.canonical_first_name)) = b.norm_first
     OR LOWER(TRIM(v.first_name))           = b.norm_first
  )
  AND LOWER(TRIM(v.res_city_desc)) = LOWER(TRIM(b.norm_city));

-- PASS 3 (Fallback — address anchor): norm_last + addr_number + norm_zip5
-- For rows where first name mismatch (nickname not resolved)
UPDATE public.nc_boe_donations_raw b
SET voter_ncid     = v.ncid,
    voter_party_cd = v.party_cd
FROM public.nc_voters v
WHERE b.voter_ncid IS NULL
  AND b.addr_number IS NOT NULL
  AND b.norm_zip5 IS NOT NULL
  AND LOWER(TRIM(v.last_name)) = b.norm_last
  AND LEFT(v.zip_code, 5)      = b.norm_zip5
  AND SPLIT_PART(v.res_street_address, ' ', 1) = b.addr_number::text;

-- Post-check after all passes:
-- SELECT COUNT(*) AS matched,
--        COUNT(*) FILTER (WHERE voter_ncid IS NULL) AS unmatched,
--        ROUND(100.0 * COUNT(*) FILTER (WHERE voter_ncid IS NOT NULL) / COUNT(*), 2) AS match_pct
-- FROM public.nc_boe_donations_raw;
-- Target: 70%+ match rate on Pass 1 alone. 75-80% after all 3 passes.
