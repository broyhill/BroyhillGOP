-- Migration 094: Stamp person_master.rnc_rncid from core.person_spine.voter_rncid
-- Authorized by: Ed Broyhill, April 8, 2026
-- Result: 127,562 rows updated (dry run estimated 127,565 — 3-row drift, negligible)
-- NOTE: Run in batches on hosted Postgres — single UPDATE times out on 7.66M-row table
-- Executed via: Cursor batched UPDATEs on isbgjpnbocdkeslofota

-- BATCH PATTERN (repeat until 0 rows affected):
UPDATE public.person_master pm
SET rnc_rncid = ps.voter_rncid
FROM core.person_spine ps
WHERE pm.ncvoter_ncid = ps.voter_ncid
  AND ps.voter_rncid IS NOT NULL
  AND pm.rnc_rncid IS NULL
  AND pm.ncvoter_ncid IN (
    SELECT pm2.ncvoter_ncid
    FROM public.person_master pm2
    JOIN core.person_spine ps2 ON pm2.ncvoter_ncid = ps2.voter_ncid
    WHERE ps2.voter_rncid IS NOT NULL AND pm2.rnc_rncid IS NULL
    LIMIT 50000
  );

-- Post-check: SELECT COUNT(*) FROM public.person_master WHERE rnc_rncid IS NOT NULL;
-- Expected: 127,562
-- Also verify: SELECT COUNT(*) FROM public.person_master pm
--   JOIN core.person_spine ps ON pm.ncvoter_ncid = ps.voter_ncid
--   WHERE ps.voter_rncid IS NOT NULL AND pm.rnc_rncid IS NULL;
-- Expected: 0
