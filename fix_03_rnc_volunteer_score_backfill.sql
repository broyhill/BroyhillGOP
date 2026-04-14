-- =============================================================================
-- FIX 03: rnc_proprietary_scores — volunteer_score 100% NULL
-- Table: rnc_proprietary_scores
-- Issue: volunteer_score column is NULL for all 1,106,000 rows (0 non-null).
--        persuadability has 897,861 non-null values (81.2%).
--        The table rnc_scores_fresh_20260325 EXISTS (1 row in information_schema)
--        but does NOT contain a volunteer_score column — it has different columns:
--        rncid, rnc_regid, state_voter_id, republican_party_score,
--        democratic_party_score, republican_ballot_score, democratic_ballot_score,
--        turnout_general_score, vh26g/p, vh25g/p, vh24g, household_income_modeled,
--        education_modeled, last_update, loaded_at.
--        No volunteer score source is available in the database.
-- Columns in rnc_proprietary_scores:
--   rncid, trump_support, donor_score, volunteer_score, persuadability,
--   gun_owner_score, religious_score
-- Estimated rows affected: 1,106,000 (all rows have NULL volunteer_score)
-- Diagnosed: 2026-03-28
-- =============================================================================

-- -----------------------------------------------------------------------
-- DIAGNOSTIC VERIFICATION
-- -----------------------------------------------------------------------

-- Confirm all score column null counts
SELECT
    COUNT(*) as total,
    COUNT(trump_support) as non_null_trump_support,
    COUNT(donor_score) as non_null_donor_score,
    COUNT(volunteer_score) as non_null_volunteer_score,
    COUNT(persuadability) as non_null_persuadability,
    COUNT(gun_owner_score) as non_null_gun_owner_score,
    COUNT(religious_score) as non_null_religious_score
FROM rnc_proprietary_scores;

-- Check fresh table columns
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'rnc_scores_fresh_20260325'
ORDER BY ordinal_position;

-- Confirm fresh table does NOT have volunteer_score
SELECT COUNT(*) as volunteer_column_exists
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'rnc_scores_fresh_20260325'
  AND column_name = 'volunteer_score';

-- -----------------------------------------------------------------------
-- FINDING: rnc_scores_fresh_20260325 does NOT have volunteer_score column
-- The score is unavailable from any current data source in this database.
-- Action: Document the column with a comment; no data backfill is possible.
-- -----------------------------------------------------------------------

-- STEP 1: Document that volunteer_score is unavailable
COMMENT ON COLUMN rnc_proprietary_scores.volunteer_score IS
    'UNAVAILABLE: This column is 100% NULL as of 2026-03-28. The RNC fresh scores table '
    '(rnc_scores_fresh_20260325) does not include volunteer scoring — it contains '
    'party affiliation scores, ballot scores, turnout scores, and modeled demographics. '
    'Volunteer propensity scoring must be obtained from a future RNC data delivery. '
    'Do not use this column until populated. Diagnosed in fix_03 (2026-03-28).';

-- STEP 2: Create a tracking record in a data quality log (if table exists)
-- This is a no-op documentation insert pattern — safe to run
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'data_quality_log'
    ) THEN
        INSERT INTO data_quality_log (table_name, column_name, issue, status, detected_at, notes)
        VALUES (
            'rnc_proprietary_scores',
            'volunteer_score',
            'COLUMN_100PCT_NULL',
            'UNRESOLVABLE_NO_SOURCE',
            NOW(),
            'volunteer_score is NULL for all 1,106,000 rows. rnc_scores_fresh_20260325 does not '
            'contain volunteer scoring data. Requires future RNC data delivery to populate.'
        );
        RAISE NOTICE 'Logged to data_quality_log';
    ELSE
        RAISE NOTICE 'data_quality_log table does not exist — skipping log insert. Issue documented in column comment only.';
    END IF;
END $$;

-- -----------------------------------------------------------------------
-- OPTIONAL: If/when a future volunteer_score source becomes available,
-- use this template to backfill via rncid join:
-- -----------------------------------------------------------------------
-- BEGIN;
-- UPDATE rnc_proprietary_scores rps
-- SET volunteer_score = src.volunteer_score_value
-- FROM <future_source_table> src
-- WHERE src.rncid = rps.rncid
--   AND src.volunteer_score_value IS NOT NULL;
--
-- -- Verify backfill
-- SELECT COUNT(volunteer_score) as non_null_after FROM rnc_proprietary_scores;
-- COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- ROLLBACK INSTRUCTIONS
-- -----------------------------------------------------------------------
-- The COMMENT statement is the only change made to data/schema.
-- To remove the comment:
-- COMMENT ON COLUMN rnc_proprietary_scores.volunteer_score IS NULL;
