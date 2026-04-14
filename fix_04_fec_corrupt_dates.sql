-- =============================================================================
-- FIX 04: fec_donations / fec_god_contributions — corrupt dates (year 1015, 2106)
-- Tables: fec_donations, fec_god_contributions
-- Issue: 3 rows with invalid dates found in EACH table (same 3 records appear
--        in both, which is expected since fec_god_contributions is a superset):
--   Row 1: contribution_date = '1015-10-19', GORGA, JOSEPH, $200.00, C00561258
--          Recovery: 1015-10-19 likely entered as 10/15/19 → parsed wrong → 2019-10-15
--   Row 2: contribution_date = '1015-10-30', CALLAGHAN, KATHERINE, $1000.00, C00561258
--          Recovery: 1015-10-30 → read as 10/15/30 → ambiguous. More likely 2015-10-30
--          (YYMMDD where 15 = 2015, MM=10, DD=30 → actually YYMMDD failure?)
--          Pattern: '1015' prefix = year 1015, but all are committee C00561258.
--          Best interpretation: MMDDYY format: 10/19/15 → 2015-10-19, 10/30/15 → 2015-10-30
--   Row 3: contribution_date = '2106-06-13', MCCAULEY, JOHN, $1500.00, C00385526
--          Recovery: 2106 → likely 2016 (transposition of '21' and '06' digits) → 2016-06-13
--          OR: stored as YYMMDD and '21' = 2021? → 2021-06-13
--          Safest: Flag as requires_manual_review=TRUE, set original to NULL
-- Estimated rows affected: 3 per table (6 total)
-- Diagnosed: 2026-03-28
-- =============================================================================

-- -----------------------------------------------------------------------
-- DIAGNOSTIC VERIFICATION
-- -----------------------------------------------------------------------

-- fec_donations corrupt rows
SELECT contribution_date, contributor_name, contribution_amount, committee_id
FROM fec_donations
WHERE EXTRACT(YEAR FROM contribution_date) < 1970
   OR EXTRACT(YEAR FROM contribution_date) > 2030
ORDER BY contribution_date;

-- fec_god_contributions corrupt rows
SELECT contribution_receipt_date, contributor_name, contribution_receipt_amount, committee_id
FROM fec_god_contributions
WHERE EXTRACT(YEAR FROM contribution_receipt_date) < 1970
   OR EXTRACT(YEAR FROM contribution_receipt_date) > 2030
ORDER BY contribution_receipt_date;

-- Confirm total bad date counts
SELECT
    'fec_donations' as source_table,
    COUNT(*) as corrupt_date_rows
FROM fec_donations
WHERE EXTRACT(YEAR FROM contribution_date) < 1970
   OR EXTRACT(YEAR FROM contribution_date) > 2030
UNION ALL
SELECT
    'fec_god_contributions' as source_table,
    COUNT(*) as corrupt_date_rows
FROM fec_god_contributions
WHERE EXTRACT(YEAR FROM contribution_receipt_date) < 1970
   OR EXTRACT(YEAR FROM contribution_receipt_date) > 2030;

-- -----------------------------------------------------------------------
-- STEP 1: Create audit log table for date changes
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fec_donations_date_fixes_log (
    fix_id          SERIAL PRIMARY KEY,
    source_table    TEXT NOT NULL,
    row_id          BIGINT,
    contributor_name TEXT,
    committee_id    TEXT,
    original_date   DATE,
    recovered_date  DATE,
    recovery_method TEXT,
    requires_manual_review BOOLEAN DEFAULT FALSE,
    fixed_at        TIMESTAMPTZ DEFAULT NOW(),
    notes           TEXT
);

COMMENT ON TABLE fec_donations_date_fixes_log IS
    'Audit log of all corrupt date corrections applied to fec_donations and fec_god_contributions. Created by fix_04 (2026-03-28).';

-- -----------------------------------------------------------------------
-- STEP 2: Add audit columns to fec_donations
-- -----------------------------------------------------------------------
ALTER TABLE fec_donations
    ADD COLUMN IF NOT EXISTS date_corrupt BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS original_contribution_date DATE,
    ADD COLUMN IF NOT EXISTS date_recovery_method TEXT;

COMMENT ON COLUMN fec_donations.date_corrupt IS
    'TRUE if contribution_date was corrupted and required correction. Added fix_04 (2026-03-28).';
COMMENT ON COLUMN fec_donations.original_contribution_date IS
    'Original bad date value before fix_04 correction (2026-03-28).';

-- -----------------------------------------------------------------------
-- STEP 3: Fix fec_donations corrupt dates
-- -----------------------------------------------------------------------
BEGIN;

-- GORGA, JOSEPH: 1015-10-19 → interpret as MMDDYY: month=10, day=19, year=15 → 2015-10-19
-- Log the change
INSERT INTO fec_donations_date_fixes_log
    (source_table, row_id, contributor_name, committee_id, original_date, recovered_date,
     recovery_method, requires_manual_review, notes)
SELECT
    'fec_donations', id, contributor_name, committee_id,
    contribution_date, '2015-10-19'::DATE,
    'MMDDYY_reparse',
    FALSE,
    'Date 1015-10-19 interpreted as MMDDYY: MM=10, DD=19, YY=15 → 2015-10-19'
FROM fec_donations
WHERE contribution_date = '1015-10-19'
  AND contributor_name = 'GORGA, JOSEPH';

-- Apply fix for GORGA, JOSEPH
UPDATE fec_donations
SET original_contribution_date = contribution_date,
    contribution_date = '2015-10-19'::DATE,
    date_corrupt = TRUE,
    date_recovery_method = 'MMDDYY_reparse: 1015-10-19 → 2015-10-19'
WHERE contribution_date = '1015-10-19'
  AND contributor_name = 'GORGA, JOSEPH';

-- CALLAGHAN, KATHERINE: 1015-10-30 → interpret as MMDDYY: month=10, day=30, year=15 → 2015-10-30
INSERT INTO fec_donations_date_fixes_log
    (source_table, row_id, contributor_name, committee_id, original_date, recovered_date,
     recovery_method, requires_manual_review, notes)
SELECT
    'fec_donations', id, contributor_name, committee_id,
    contribution_date, '2015-10-30'::DATE,
    'MMDDYY_reparse',
    FALSE,
    'Date 1015-10-30 interpreted as MMDDYY: MM=10, DD=30, YY=15 → 2015-10-30'
FROM fec_donations
WHERE contribution_date = '1015-10-30'
  AND contributor_name = 'CALLAGHAN, KATHERINE';

UPDATE fec_donations
SET original_contribution_date = contribution_date,
    contribution_date = '2015-10-30'::DATE,
    date_corrupt = TRUE,
    date_recovery_method = 'MMDDYY_reparse: 1015-10-30 → 2015-10-30'
WHERE contribution_date = '1015-10-30'
  AND contributor_name = 'CALLAGHAN, KATHERINE';

-- MCCAULEY, JOHN: 2106-06-13 → likely digit transposition (2106 → 2016), C00385526
-- Manual review flag because 2016 vs 2021 is ambiguous
INSERT INTO fec_donations_date_fixes_log
    (source_table, row_id, contributor_name, committee_id, original_date, recovered_date,
     recovery_method, requires_manual_review, notes)
SELECT
    'fec_donations', id, contributor_name, committee_id,
    contribution_date, NULL,
    'UNRECOVERABLE_FLAGGED',
    TRUE,
    'Date 2106-06-13 is ambiguous: could be digit transposition (2016-06-13) or 2021-06-13. '
    'Set to NULL pending manual review. Committee C00385526.'
FROM fec_donations
WHERE contribution_date = '2106-06-13'
  AND contributor_name = 'MCCAULEY, JOHN';

UPDATE fec_donations
SET original_contribution_date = contribution_date,
    contribution_date = NULL,
    date_corrupt = TRUE,
    date_recovery_method = 'UNRECOVERABLE: 2106-06-13 — ambiguous, see fec_donations_date_fixes_log'
WHERE contribution_date = '2106-06-13'
  AND contributor_name = 'MCCAULEY, JOHN';

-- Verify all bad dates resolved
SELECT
    COUNT(CASE WHEN EXTRACT(YEAR FROM contribution_date) < 1970
                 OR EXTRACT(YEAR FROM contribution_date) > 2030 THEN 1 END) as remaining_corrupt,
    COUNT(CASE WHEN date_corrupt = TRUE THEN 1 END) as flagged_corrected
FROM fec_donations;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- STEP 4: Fix fec_god_contributions corrupt dates (same 3 records)
-- -----------------------------------------------------------------------
ALTER TABLE fec_god_contributions
    ADD COLUMN IF NOT EXISTS date_corrupt BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS original_contribution_receipt_date DATE,
    ADD COLUMN IF NOT EXISTS date_recovery_method TEXT;

BEGIN;

INSERT INTO fec_donations_date_fixes_log
    (source_table, row_id, contributor_name, committee_id, original_date, recovered_date,
     recovery_method, requires_manual_review, notes)
SELECT
    'fec_god_contributions', id, contributor_name, committee_id,
    contribution_receipt_date, '2015-10-19'::DATE,
    'MMDDYY_reparse', FALSE,
    'Date 1015-10-19 interpreted as MMDDYY: MM=10, DD=19, YY=15 → 2015-10-19'
FROM fec_god_contributions
WHERE contribution_receipt_date = '1015-10-19'
  AND contributor_name = 'GORGA, JOSEPH';

UPDATE fec_god_contributions
SET original_contribution_receipt_date = contribution_receipt_date,
    contribution_receipt_date = '2015-10-19'::DATE,
    date_corrupt = TRUE,
    date_recovery_method = 'MMDDYY_reparse: 1015-10-19 → 2015-10-19'
WHERE contribution_receipt_date = '1015-10-19'
  AND contributor_name = 'GORGA, JOSEPH';

INSERT INTO fec_donations_date_fixes_log
    (source_table, row_id, contributor_name, committee_id, original_date, recovered_date,
     recovery_method, requires_manual_review, notes)
SELECT
    'fec_god_contributions', id, contributor_name, committee_id,
    contribution_receipt_date, '2015-10-30'::DATE,
    'MMDDYY_reparse', FALSE,
    'Date 1015-10-30 interpreted as MMDDYY: MM=10, DD=30, YY=15 → 2015-10-30'
FROM fec_god_contributions
WHERE contribution_receipt_date = '1015-10-30'
  AND contributor_name = 'CALLAGHAN, KATHERINE';

UPDATE fec_god_contributions
SET original_contribution_receipt_date = contribution_receipt_date,
    contribution_receipt_date = '2015-10-30'::DATE,
    date_corrupt = TRUE,
    date_recovery_method = 'MMDDYY_reparse: 1015-10-30 → 2015-10-30'
WHERE contribution_receipt_date = '1015-10-30'
  AND contributor_name = 'CALLAGHAN, KATHERINE';

INSERT INTO fec_donations_date_fixes_log
    (source_table, row_id, contributor_name, committee_id, original_date, recovered_date,
     recovery_method, requires_manual_review, notes)
SELECT
    'fec_god_contributions', id, contributor_name, committee_id,
    contribution_receipt_date, NULL,
    'UNRECOVERABLE_FLAGGED', TRUE,
    'Date 2106-06-13 is ambiguous: could be 2016-06-13 or 2021-06-13. Flagged for manual review.'
FROM fec_god_contributions
WHERE contribution_receipt_date = '2106-06-13'
  AND contributor_name = 'MCCAULEY, JOHN';

UPDATE fec_god_contributions
SET original_contribution_receipt_date = contribution_receipt_date,
    contribution_receipt_date = NULL,
    date_corrupt = TRUE,
    date_recovery_method = 'UNRECOVERABLE: 2106-06-13 — see fec_donations_date_fixes_log'
WHERE contribution_receipt_date = '2106-06-13'
  AND contributor_name = 'MCCAULEY, JOHN';

-- Verify
SELECT
    COUNT(CASE WHEN EXTRACT(YEAR FROM contribution_receipt_date) < 1970
                 OR EXTRACT(YEAR FROM contribution_receipt_date) > 2030 THEN 1 END) as remaining_corrupt,
    COUNT(CASE WHEN date_corrupt = TRUE THEN 1 END) as flagged_corrected
FROM fec_god_contributions;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- VIEW: Show all fixes applied
-- -----------------------------------------------------------------------
SELECT * FROM fec_donations_date_fixes_log ORDER BY fix_id;

-- -----------------------------------------------------------------------
-- ROLLBACK INSTRUCTIONS
-- -----------------------------------------------------------------------
-- BEGIN;
-- -- Restore fec_donations
-- UPDATE fec_donations
-- SET contribution_date = original_contribution_date,
--     date_corrupt = FALSE,
--     date_recovery_method = NULL,
--     original_contribution_date = NULL
-- WHERE date_corrupt = TRUE;
--
-- -- Restore fec_god_contributions
-- UPDATE fec_god_contributions
-- SET contribution_receipt_date = original_contribution_receipt_date,
--     date_corrupt = FALSE,
--     date_recovery_method = NULL,
--     original_contribution_receipt_date = NULL
-- WHERE date_corrupt = TRUE;
--
-- TRUNCATE fec_donations_date_fixes_log;
-- COMMIT;
