-- Migration 093: Backfill fec_donations.candidate_id from committee_party_map
-- Authorized by: Ed Broyhill, April 8, 2026
-- Result: 658,942 rows updated
-- Pre-check: multimap check returned 0 rows (each committee_id maps to exactly one candidate_id)
-- Executed via: Supabase MCP execute_sql on isbgjpnbocdkeslofota

UPDATE public.fec_donations fd
SET candidate_id = cpm.candidate_id
FROM public.committee_party_map cpm
WHERE fd.committee_id = cpm.committee_id
  AND cpm.candidate_id IS NOT NULL
  AND cpm.candidate_id != ''
  AND (fd.candidate_id IS NULL OR fd.candidate_id = '');

-- Post-check: SELECT COUNT(*) FROM public.fec_donations WHERE candidate_id IS NOT NULL AND candidate_id != '';
-- Expected: 658,942
