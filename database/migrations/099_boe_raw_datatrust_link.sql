-- Migration 099: Link BOE donors → nc_datatrust (populate rncid + cell_phone)
-- Authorized by: Ed Broyhill, April 8, 2026
-- Scope: All rows where voter_ncid IS NOT NULL (output of 098)
-- Prerequisite: Migration 098 must be complete (voter_ncid populated)

-- STEP 1: Stamp rncid + cell_phone via voter_ncid → statevoterid bridge
-- Direct equality join — format confirmed identical (BJ10743 etc.)
-- statevoterid::varchar cast for index alignment

UPDATE public.nc_boe_donations_raw b
SET rncid      = dt.rncid,
    cell_phone = NULLIF(TRIM(dt.cell), '')
FROM public.nc_datatrust dt
WHERE b.voter_ncid IS NOT NULL
  AND b.rncid IS NULL
  AND dt.statevoterid::varchar = b.voter_ncid;

-- NOTE: Run in batches of 500K if timeout occurs. Pattern:
-- UPDATE public.nc_boe_donations_raw b SET ...
-- FROM public.nc_datatrust dt
-- WHERE b.voter_ncid IS NOT NULL AND b.rncid IS NULL
--   AND dt.statevoterid::varchar = b.voter_ncid
--   AND b.id IN (SELECT id FROM public.nc_boe_donations_raw
--                WHERE voter_ncid IS NOT NULL AND rncid IS NULL LIMIT 500000);

-- Post-check:
-- SELECT
--     COUNT(*) AS total,
--     COUNT(voter_ncid) AS has_voter_ncid,
--     COUNT(rncid) AS has_rncid,
--     COUNT(cell_phone) AS has_cell,
--     ROUND(100.0 * COUNT(rncid) / NULLIF(COUNT(voter_ncid),0), 2) AS datatrust_coverage_pct
-- FROM public.nc_boe_donations_raw;
-- Expected: rncid should populate on ~85-90% of voter_ncid-matched rows
-- (DataTrust covers ~84% of nc_voters active records)
