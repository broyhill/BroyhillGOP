-- =============================================================================
-- FIX 07: fec_party_committee_donations / fec_committee_transfers —
--         transaction_date stored as MMDDYYYY text
-- Tables: fec_party_committee_donations, fec_committee_transfers
-- Issue: transaction_date is TEXT type storing dates in MMDDYYYY format.
--        Both tables confirmed to have the same format.
--        fec_party_committee_donations: 1,734,568 total rows, 1 non-8-digit value
--        fec_committee_transfers: same MMDDYYYY pattern confirmed
--        Out-of-range validation: only 3 rows parse to dates outside 1990-2030
--        (edge cases with ambiguous month/day values)
--        Sample values: '10312025', '06302025', '09302022' → Oct 31 2025, Jun 30 2025, Sep 30 2022
-- Estimated rows affected: 1,734,568 (fec_party_committee_donations) + fec_committee_transfers
-- Diagnosed: 2026-03-28
-- =============================================================================

-- -----------------------------------------------------------------------
-- DIAGNOSTIC VERIFICATION — fec_party_committee_donations
-- -----------------------------------------------------------------------

-- Confirm MMDDYYYY format with samples
SELECT transaction_date, COUNT(*)
FROM fec_party_committee_donations
GROUP BY transaction_date
ORDER BY COUNT(*) DESC
LIMIT 10;

-- Total rows and non-8-digit outliers
SELECT
    COUNT(*) as total,
    COUNT(CASE WHEN LENGTH(transaction_date::text) != 8 THEN 1 END) as non_8digit,
    COUNT(CASE WHEN LENGTH(transaction_date::text) = 8 THEN 1 END) as valid_8digit
FROM fec_party_committee_donations;

-- Preview parsed dates
SELECT
    transaction_date as raw,
    TO_DATE(transaction_date::text, 'MMDDYYYY') as parsed_date
FROM fec_party_committee_donations
LIMIT 10;

-- Out-of-range check (should be near 0)
SELECT transaction_date, TO_DATE(transaction_date::text, 'MMDDYYYY') as parsed
FROM fec_party_committee_donations
WHERE LENGTH(transaction_date::text) = 8
  AND (TO_DATE(transaction_date::text, 'MMDDYYYY') < '1990-01-01'
    OR TO_DATE(transaction_date::text, 'MMDDYYYY') > '2030-12-31');

-- Non-8-digit outlier(s)
SELECT transaction_date, COUNT(*)
FROM fec_party_committee_donations
WHERE LENGTH(transaction_date::text) != 8
GROUP BY transaction_date;

-- -----------------------------------------------------------------------
-- DIAGNOSTIC VERIFICATION — fec_committee_transfers
-- -----------------------------------------------------------------------

SELECT transaction_date, COUNT(*)
FROM fec_committee_transfers
GROUP BY transaction_date
ORDER BY COUNT(*) DESC
LIMIT 10;

SELECT
    COUNT(*) as total,
    COUNT(CASE WHEN LENGTH(transaction_date::text) != 8 THEN 1 END) as non_8digit
FROM fec_committee_transfers;

-- -----------------------------------------------------------------------
-- STEP 1: Add parsed date column to fec_party_committee_donations
-- -----------------------------------------------------------------------
ALTER TABLE fec_party_committee_donations
    ADD COLUMN IF NOT EXISTS transaction_date_parsed DATE,
    ADD COLUMN IF NOT EXISTS transaction_date_parse_failed BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN fec_party_committee_donations.transaction_date_parsed IS
    'Parsed DATE from transaction_date (MMDDYYYY text format). Added by fix_07 (2026-03-28).';
COMMENT ON COLUMN fec_party_committee_donations.transaction_date_parse_failed IS
    'TRUE if transaction_date could not be parsed to a valid date. Added by fix_07 (2026-03-28).';

-- -----------------------------------------------------------------------
-- STEP 2: Populate parsed date — fec_party_committee_donations
-- -----------------------------------------------------------------------
BEGIN;

-- Parse with strict round-trip validation.
-- NOTE: TO_DATE can "roll over" invalid values (e.g., 13322025) unless validated.
UPDATE fec_party_committee_donations t
SET
    transaction_date_parsed = CASE
        WHEN s.raw ~ '^[0-9]{8}$'
         AND TO_CHAR(TO_DATE(s.raw, 'MMDDYYYY'), 'MMDDYYYY') = s.raw
         AND TO_DATE(s.raw, 'MMDDYYYY') BETWEEN DATE '1990-01-01' AND DATE '2030-12-31'
        THEN TO_DATE(s.raw, 'MMDDYYYY')
        ELSE NULL
    END,
    transaction_date_parse_failed = CASE
        WHEN s.raw IS NULL OR s.raw = '' THEN TRUE
        WHEN s.raw !~ '^[0-9]{8}$' THEN TRUE
        WHEN TO_CHAR(TO_DATE(s.raw, 'MMDDYYYY'), 'MMDDYYYY') <> s.raw THEN TRUE
        WHEN TO_DATE(s.raw, 'MMDDYYYY') < DATE '1990-01-01'
          OR TO_DATE(s.raw, 'MMDDYYYY') > DATE '2030-12-31' THEN TRUE
        ELSE FALSE
    END
FROM (
    SELECT id, TRIM(transaction_date::text) AS raw
    FROM fec_party_committee_donations
) s
WHERE t.id = s.id;

-- Verify parse results
SELECT
    COUNT(*) as total,
    COUNT(transaction_date_parsed) as successfully_parsed,
    COUNT(CASE WHEN transaction_date_parse_failed = TRUE THEN 1 END) as parse_failures,
    MIN(transaction_date_parsed) as earliest_parsed,
    MAX(transaction_date_parsed) as latest_parsed
FROM fec_party_committee_donations;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- STEP 3: Validate — confirm no data loss before dropping old column
-- -----------------------------------------------------------------------

-- Run this validation BEFORE proceeding to Step 4
-- If this returns 0, it is safe to proceed
SELECT COUNT(*) as unmatched_rows
FROM fec_party_committee_donations
WHERE LENGTH(transaction_date::text) = 8
  AND transaction_date_parsed IS NULL
  AND transaction_date_parse_failed = FALSE;

-- Summary validation
SELECT
    COUNT(*) as total,
    COUNT(CASE WHEN transaction_date_parsed IS NOT NULL THEN 1 END) as parsed_ok,
    COUNT(CASE WHEN transaction_date_parse_failed = TRUE THEN 1 END) as failed,
    ROUND(100.0 * COUNT(CASE WHEN transaction_date_parsed IS NOT NULL THEN 1 END) / COUNT(*), 4) as parse_success_pct
FROM fec_party_committee_donations;

-- -----------------------------------------------------------------------
-- STEP 4: Rename columns (archive old, promote new)
-- Run ONLY after manual validation of Step 3 results
-- -----------------------------------------------------------------------
BEGIN;

-- Rename old TEXT column to archive it
ALTER TABLE fec_party_committee_donations
    RENAME COLUMN transaction_date TO transaction_date_raw_mmddyyyy;

-- Rename parsed DATE column to the canonical name
ALTER TABLE fec_party_committee_donations
    RENAME COLUMN transaction_date_parsed TO transaction_date;

-- Add archive comment
COMMENT ON COLUMN fec_party_committee_donations.transaction_date_raw_mmddyyyy IS
    'ARCHIVED: Original transaction_date stored as MMDDYYYY text. Kept for audit. '
    'Use transaction_date (DATE type) for all queries. fix_07 (2026-03-28).';

COMMENT ON COLUMN fec_party_committee_donations.transaction_date IS
    'Contribution date (DATE). Converted from MMDDYYYY text format by fix_07 (2026-03-28). '
    'Original text preserved in transaction_date_raw_mmddyyyy.';

-- Final verification
SELECT
    COUNT(*) as total,
    MIN(transaction_date) as earliest,
    MAX(transaction_date) as latest,
    COUNT(CASE WHEN transaction_date IS NULL THEN 1 END) as null_dates
FROM fec_party_committee_donations;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- STEP 5: Same fix for fec_committee_transfers
-- -----------------------------------------------------------------------
ALTER TABLE fec_committee_transfers
    ADD COLUMN IF NOT EXISTS transaction_date_parsed DATE,
    ADD COLUMN IF NOT EXISTS transaction_date_parse_failed BOOLEAN DEFAULT FALSE;

BEGIN;

UPDATE fec_committee_transfers t
SET
    transaction_date_parsed = CASE
        WHEN s.raw ~ '^[0-9]{8}$'
         AND TO_CHAR(TO_DATE(s.raw, 'MMDDYYYY'), 'MMDDYYYY') = s.raw
         AND TO_DATE(s.raw, 'MMDDYYYY') BETWEEN DATE '1990-01-01' AND DATE '2030-12-31'
        THEN TO_DATE(s.raw, 'MMDDYYYY')
        ELSE NULL
    END,
    transaction_date_parse_failed = CASE
        WHEN s.raw IS NULL OR s.raw = '' THEN TRUE
        WHEN s.raw !~ '^[0-9]{8}$' THEN TRUE
        WHEN TO_CHAR(TO_DATE(s.raw, 'MMDDYYYY'), 'MMDDYYYY') <> s.raw THEN TRUE
        WHEN TO_DATE(s.raw, 'MMDDYYYY') < DATE '1990-01-01'
          OR TO_DATE(s.raw, 'MMDDYYYY') > DATE '2030-12-31' THEN TRUE
        ELSE FALSE
    END
FROM (
    SELECT id, TRIM(transaction_date::text) AS raw
    FROM fec_committee_transfers
) s
WHERE t.id = s.id;

-- Verify
SELECT
    COUNT(*) as total,
    COUNT(transaction_date_parsed) as parsed,
    COUNT(CASE WHEN transaction_date_parse_failed = TRUE THEN 1 END) as failed,
    MIN(transaction_date_parsed) as earliest,
    MAX(transaction_date_parsed) as latest
FROM fec_committee_transfers;

COMMIT;
-- ROLLBACK;

-- Rename for fec_committee_transfers (run after validation)
BEGIN;
ALTER TABLE fec_committee_transfers
    RENAME COLUMN transaction_date TO transaction_date_raw_mmddyyyy;
ALTER TABLE fec_committee_transfers
    RENAME COLUMN transaction_date_parsed TO transaction_date;

COMMENT ON COLUMN fec_committee_transfers.transaction_date_raw_mmddyyyy IS
    'ARCHIVED: Original transaction_date as MMDDYYYY text. fix_07 (2026-03-28).';
COMMENT ON COLUMN fec_committee_transfers.transaction_date IS
    'Transfer date (DATE). Converted from MMDDYYYY by fix_07 (2026-03-28).';
COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- ROLLBACK INSTRUCTIONS
-- -----------------------------------------------------------------------
-- If Step 4 was already committed:
--
-- BEGIN;
-- -- fec_party_committee_donations
-- ALTER TABLE fec_party_committee_donations
--     RENAME COLUMN transaction_date TO transaction_date_parsed;
-- ALTER TABLE fec_party_committee_donations
--     RENAME COLUMN transaction_date_raw_mmddyyyy TO transaction_date;
-- ALTER TABLE fec_party_committee_donations
--     DROP COLUMN IF EXISTS transaction_date_parsed,
--     DROP COLUMN IF EXISTS transaction_date_parse_failed;
--
-- -- fec_committee_transfers
-- ALTER TABLE fec_committee_transfers
--     RENAME COLUMN transaction_date TO transaction_date_parsed;
-- ALTER TABLE fec_committee_transfers
--     RENAME COLUMN transaction_date_raw_mmddyyyy TO transaction_date;
-- ALTER TABLE fec_committee_transfers
--     DROP COLUMN IF EXISTS transaction_date_parsed,
--     DROP COLUMN IF EXISTS transaction_date_parse_failed;
-- COMMIT;
