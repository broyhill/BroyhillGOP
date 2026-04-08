-- Migration 096: Purge memo rows from public.fec_donations
-- Authorized by: Ed Broyhill, April 8, 2026
-- Purpose: Remove memo/earmark transactions that are not real individual contributions
-- Expected: ~779,182 → ~295,000 rows after purge

-- STEP 1: Archive memo rows before deleting
CREATE TABLE IF NOT EXISTS archive.fec_donations_memo_purge_20260408 AS
SELECT *, now() AS archived_at
FROM public.fec_donations
WHERE memo_code = 'X'
   OR receipt_type IN ('24I', '24T', '22Y')
   OR (UPPER(COALESCE(memo_text, '')) LIKE '%EARMARK%')
   OR (UPPER(COALESCE(memo_text, '')) LIKE '%REDESIGNATION%')
   OR (UPPER(COALESCE(memo_text, '')) LIKE '%REATTRIBUTION%');

-- STEP 2: Verify archive count before deleting
-- SELECT COUNT(*) FROM archive.fec_donations_memo_purge_20260408;
-- Expected: ~480,000+ rows

-- STEP 3: Delete memo rows from live table
DELETE FROM public.fec_donations
WHERE memo_code = 'X'
   OR receipt_type IN ('24I', '24T', '22Y')
   OR (UPPER(COALESCE(memo_text, '')) LIKE '%EARMARK%')
   OR (UPPER(COALESCE(memo_text, '')) LIKE '%REDESIGNATION%')
   OR (UPPER(COALESCE(memo_text, '')) LIKE '%REATTRIBUTION%');

-- STEP 4: Post-check
-- SELECT COUNT(*) FROM public.fec_donations;
-- Expected: ~295,000 (real individual NC GOP contributions only)

-- SELECT source_file, COUNT(*) AS rows, SUM(contribution_receipt_amount) AS total
-- FROM public.fec_donations
-- GROUP BY source_file ORDER BY rows DESC;

-- NOTE: archive.fec_donations_memo_purge_20260408 retains all purged rows
-- for reference. Do not drop this table without Ed's authorization.
