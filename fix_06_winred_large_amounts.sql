-- =============================================================================
-- FIX 06: winred_donors — $32M cash_amount record and other large amounts
-- Table: winred_donors
-- Issue: One record with cash_amount = $32,226,278.96 (id=199288, entity_name="Totals:",
--        norm_first="TOTALS:", norm_last="", donation_date=NULL).
--        This is a SUMMARY/TOTALS row that was incorrectly loaded as a donor record.
--        Additional large amounts:
--          909 rows > $3,300 (FEC per-cycle limit)
--          286 rows > $10,000
--          27 rows > $100,000
--        Many large amounts are legitimate (party-to-party transfers, PAC donations):
--          RGA Right Direction PAC: $500,000 (multiple rows)
--          David Bryan: $500,000
--          Greg Lindberg: $500,000 (multiple)
--        The $32M "Totals:" row is definitively a data error.
-- Columns: id (integer), entity_name, norm_first, norm_last, transaction_type,
--          cash_amount, non_cash_amount, donation_date, address_line1, address_line2,
--          city, state, zip5, county, home_phone, work_phone, mobile_phone, email,
--          category, voter_ncid, zip9, voter_party, rncid, matched_to_ncboe,
--          source, created_at
-- Estimated rows affected: 909 rows quarantined for review; 1 confirmed data error
-- Diagnosed: 2026-03-28
-- =============================================================================

-- -----------------------------------------------------------------------
-- DIAGNOSTIC VERIFICATION
-- -----------------------------------------------------------------------

-- Find all records over $100,000
SELECT id, entity_name, norm_first, norm_last, cash_amount, donation_date, category, source
FROM winred_donors
WHERE cash_amount > 100000
ORDER BY cash_amount DESC
LIMIT 20;

-- Distribution analysis
SELECT
    COUNT(CASE WHEN cash_amount > 3300 THEN 1 END) as over_cycle_limit,
    COUNT(CASE WHEN cash_amount > 10000 THEN 1 END) as over_10k,
    COUNT(CASE WHEN cash_amount > 100000 THEN 1 END) as over_100k,
    COUNT(CASE WHEN cash_amount > 1000000 THEN 1 END) as over_1m,
    MAX(cash_amount) as max_amount,
    COUNT(*) as total_rows
FROM winred_donors;

-- Check the $32M "Totals:" record specifically
SELECT id, entity_name, norm_first, norm_last, cash_amount, non_cash_amount,
       donation_date, category, source, created_at
FROM winred_donors
WHERE id = 199288;
-- Optional idempotency variant:
-- WHERE id = 199288 AND amount_review_needed IS DISTINCT FROM TRUE;

-- Would $32,226,278.96 make sense as cents? → $322,262.79 — still large but possible for a PAC
-- Check if treating as cents gives a plausible amount
SELECT
    id,
    entity_name,
    cash_amount as raw_amount,
    ROUND(cash_amount / 100.0, 2) as if_cents_to_dollars
FROM winred_donors
WHERE cash_amount > 10000000;

-- -----------------------------------------------------------------------
-- STEP 1: Create rerun-safe quarantine table for review
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS winred_donors_amount_review
(LIKE winred_donors INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

ALTER TABLE winred_donors_amount_review
    ADD COLUMN IF NOT EXISTS review_id BIGINT GENERATED ALWAYS AS IDENTITY,
    ADD COLUMN IF NOT EXISTS review_batch TEXT,
    ADD COLUMN IF NOT EXISTS quarantined_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS reviewed BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS reviewer_notes TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS ux_winred_donors_amount_review_source_id
ON winred_donors_amount_review(id);

INSERT INTO winred_donors_amount_review (
    id, entity_name, norm_first, norm_last, transaction_type,
    cash_amount, non_cash_amount, donation_date, address_line1, address_line2,
    city, state, zip5, county, home_phone, work_phone, mobile_phone, email,
    category, voter_ncid, zip9, voter_party, rncid, matched_to_ncboe,
    source, created_at,
    review_batch, quarantined_at, reviewed, reviewer_notes
)
SELECT
    w.id, w.entity_name, w.norm_first, w.norm_last, w.transaction_type,
    w.cash_amount, w.non_cash_amount, w.donation_date, w.address_line1, w.address_line2,
    w.city, w.state, w.zip5, w.county, w.home_phone, w.work_phone, w.mobile_phone, w.email,
    w.category, w.voter_ncid, w.zip9, w.voter_party, w.rncid, w.matched_to_ncboe,
    w.source, w.created_at,
    'initial_load_20260328', NOW(), FALSE, NULL
FROM winred_donors w
WHERE w.cash_amount > 3300
  AND NOT EXISTS (
    SELECT 1 FROM winred_donors_amount_review q WHERE q.id = w.id
  );

COMMENT ON TABLE winred_donors_amount_review IS
    'Staging table for winred_donors records with cash_amount > $3,300 (FEC per-cycle limit). '
    'Created by fix_06 (2026-03-28) for manual review. DO NOT DELETE — quarantine for audit.';

-- Verify staging table
SELECT
    COUNT(*) as quarantined_rows,
    MIN(cash_amount) as min_amount,
    MAX(cash_amount) as max_amount,
    SUM(cash_amount) as total_quarantined_amount
FROM winred_donors_amount_review;

-- -----------------------------------------------------------------------
-- STEP 2: Add audit columns to winred_donors
-- -----------------------------------------------------------------------
ALTER TABLE winred_donors
    ADD COLUMN IF NOT EXISTS amount_review_needed BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS amount_review_reason TEXT;

COMMENT ON COLUMN winred_donors.amount_review_needed IS
    'TRUE if cash_amount exceeds $3,300 FEC per-cycle limit or is otherwise suspect. Added fix_06 (2026-03-28).';
COMMENT ON COLUMN winred_donors.amount_review_reason IS
    'Description of why this record was flagged for review. Added fix_06 (2026-03-28).';

-- -----------------------------------------------------------------------
-- STEP 3: Flag records in source table
-- -----------------------------------------------------------------------
BEGIN;

-- Flag the totals/summary row (definitive data error)
UPDATE winred_donors
SET amount_review_needed = TRUE,
    amount_review_reason = 'SUMMARY_ROW_ERROR: entity_name="Totals:" with $32,226,278.96. '
        'This is a spreadsheet/report totals row incorrectly loaded as a donor record. '
        'donation_date is NULL. DO NOT USE IN ANY ANALYSIS.'
WHERE id = 199288;

-- Flag all other records over $3,300 (FEC cycle limit)
UPDATE winred_donors
SET amount_review_needed = TRUE,
    amount_review_reason = 'AMOUNT_OVER_FEC_CYCLE_LIMIT: cash_amount $'
        || ROUND(cash_amount, 2)::text
        || ' exceeds $3,300 per-cycle individual limit. '
        || CASE
            WHEN cash_amount > 10000000 THEN 'CRITICAL: may be data entry error.'
            WHEN category = 'PAC' OR entity_name ILIKE '%PAC%' THEN 'PAC transfer — may be legitimate.'
            WHEN entity_name ILIKE '%Republican Party%' OR entity_name ILIKE '%GOP%'
              THEN 'Party transfer — may be legitimate.'
            ELSE 'Manual review required.'
        END
WHERE cash_amount > 3300
  AND id != 199288 -- already handled above
  AND amount_review_needed IS DISTINCT FROM TRUE;

-- Verify flagging
SELECT
    amount_review_needed,
    COUNT(*) as row_count
FROM winred_donors
GROUP BY amount_review_needed;

SELECT
    CASE
        WHEN cash_amount > 10000000 THEN 'over_10M'
        WHEN cash_amount > 1000000 THEN 'over_1M'
        WHEN cash_amount > 100000 THEN 'over_100k'
        WHEN cash_amount > 10000 THEN 'over_10k'
        WHEN cash_amount > 3300 THEN 'over_3300'
        ELSE 'normal'
    END as amount_bucket,
    COUNT(*) as count,
    SUM(cash_amount) as total
FROM winred_donors
WHERE amount_review_needed = TRUE
GROUP BY 1
ORDER BY MIN(cash_amount) DESC;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- NOTE ON $32M RECORD:
-- The record id=199288 (entity_name="Totals:", donation_date=NULL, $32,226,278.96)
-- is a spreadsheet summary row loaded in error. It should be excluded from all
-- financial analysis. The cents-as-dollars hypothesis ($322,262.79) is implausible
-- because the entity name "Totals:" is not a person or organization.
-- Recommended action: DELETE after manual confirmation, or keep with is_archived=TRUE.
-- DO NOT delete automatically — this script only flags for review.
-- -----------------------------------------------------------------------

-- -----------------------------------------------------------------------
-- ROLLBACK INSTRUCTIONS
-- -----------------------------------------------------------------------
-- BEGIN;
-- UPDATE winred_donors
-- SET amount_review_needed = FALSE,
--     amount_review_reason = NULL
-- WHERE amount_review_needed = TRUE;
-- COMMIT;
--
-- -- To drop quarantine table (only after manual review complete):
-- DROP TABLE IF EXISTS winred_donors_amount_review;
