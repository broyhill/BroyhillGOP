-- =============================================================================
-- FIX 01: fec_committees — party column holds FEC cycle years, not party codes
-- Table: fec_committees
-- Issue: The `party` column stores FEC cycle year values (2020, 2022, 2024, 2026)
--        instead of party codes. 35,461 of 35,521 rows (99.8%) are year values.
--        Only 60 rows have valid party codes (REP). The `party_corrected` column
--        exists and has proper party codes for 17,440 rows (49%).
-- Estimated rows affected: 35,461 rows with bad party data; 18,081 NULL in party_corrected
-- Diagnosed: 2026-03-28
-- =============================================================================

-- -----------------------------------------------------------------------
-- DIAGNOSTIC VERIFICATION (run this first to confirm state before fixing)
-- -----------------------------------------------------------------------
SELECT
    party,
    COUNT(*) as row_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM fec_committees
GROUP BY party
ORDER BY COUNT(*) DESC
LIMIT 20;

-- party_corrected coverage
SELECT
    COUNT(*) as total,
    COUNT(party_corrected) as has_party_corrected,
    COUNT(CASE WHEN party ~ '^[0-9]{4}$' THEN 1 END) as party_is_year,
    COUNT(CASE WHEN party !~ '^[0-9]{4}$' THEN 1 END) as party_looks_correct
FROM fec_committees;

-- Sample rows to confirm swap
SELECT committee_id, name, committee_type, designation, party, party_corrected
FROM fec_committees
LIMIT 10;

-- -----------------------------------------------------------------------
-- FIX (wrapped in transaction — ROLLBACK if anything looks wrong)
-- -----------------------------------------------------------------------
BEGIN;

-- Step 1: Rename current bad `party` column to preserve it for audit
ALTER TABLE fec_committees RENAME COLUMN party TO party_raw_cycle_year;

-- Step 2: Create a new proper `party` column
ALTER TABLE fec_committees ADD COLUMN party TEXT;

-- Step 3: Populate new `party` from party_corrected where available
UPDATE fec_committees
SET party = party_corrected
WHERE party_corrected IS NOT NULL;

-- Step 4: For rows where party_corrected is NULL and the old value was NOT a year,
-- backfill from the old value (the 60 rows that had REP)
UPDATE fec_committees
SET party = party_raw_cycle_year
WHERE party IS NULL
  AND party_raw_cycle_year IS NOT NULL
  AND party_raw_cycle_year !~ '^[0-9]{4}$';

-- Step 5: Add a CHECK constraint to prevent future year-values in party
-- (excludes 4-digit numeric strings that look like years 1900-2099)
ALTER TABLE fec_committees
ADD CONSTRAINT chk_party_not_year
CHECK (party IS NULL OR party !~ '^(19|20)[0-9]{2}$');

-- Step 6: Add comment to document the audit column
COMMENT ON COLUMN fec_committees.party_raw_cycle_year IS
    'AUDIT: Original bad data from party column — contained FEC cycle years (2020-2026) instead of party codes. Preserved 2026-03-28 during fix_01.';

-- Step 7: Add comment to corrected column
COMMENT ON COLUMN fec_committees.party IS
    'Party affiliation code (REP, DEM, IND, etc.). Populated from party_corrected during fix_01 (2026-03-28).';

-- -----------------------------------------------------------------------
-- VERIFICATION QUERIES (run before COMMIT)
-- -----------------------------------------------------------------------
SELECT
    COUNT(*) as total,
    COUNT(party) as has_party,
    COUNT(party_corrected) as has_party_corrected,
    COUNT(CASE WHEN party ~ '^(19|20)[0-9]{2}$' THEN 1 END) as year_values_remaining
FROM fec_committees;

SELECT party, COUNT(*) FROM fec_committees GROUP BY party ORDER BY COUNT(*) DESC LIMIT 20;

-- COMMIT if results look correct, ROLLBACK if not
COMMIT;
-- ROLLBACK; -- Uncomment to undo all changes

-- -----------------------------------------------------------------------
-- ROLLBACK INSTRUCTIONS (if COMMIT already ran)
-- -----------------------------------------------------------------------
-- BEGIN;
-- ALTER TABLE fec_committees DROP CONSTRAINT IF EXISTS chk_party_not_year;
-- ALTER TABLE fec_committees DROP COLUMN IF EXISTS party;
-- ALTER TABLE fec_committees RENAME COLUMN party_raw_cycle_year TO party;
-- COMMIT;
