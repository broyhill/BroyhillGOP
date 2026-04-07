-- =============================================================================
-- FIX 05: nc_donor_summary — last_gift year 9007 (and other corrupt future dates)
-- Table: nc_donor_summary
-- Source: nc_boe_donations_raw (date_occurred column)
-- Issue: 31 rows have last_gift dates far in the future (ranging from year 2307 to 9007).
--        Examples:
--          9007-01-21 → NEIL MOORE, $1,389.10
--          8908-01-02 → HOYT Q BAILEY, $500.00
--          8290-06-01 → BELLSOUTH, $2,000.00
--          7007-03-01 → JERRY LONG, $100.00
--        These look like digit-reversal/transposition errors in the source:
--          9007 → 2007 (reverse the digits in the century: 90→20, 07→07)
--          8908 → likely 1989 or 2008 (reversal of digits)
--          Pattern: many of these are 4-digit years with transposed pairs.
--        nc_boe_donations_raw has no rows with date_occurred > 2026-12-31
--        (returned 0 rows), so the corrupt dates originate in nc_donor_summary
--        aggregation logic, not in the raw table.
-- Columns in nc_donor_summary: norm_last, norm_first, zip5, city, state,
--   donor_name, employer_name, gift_count, total_given, avg_gift,
--   committees_supported, first_gift, last_gift
-- Note: nc_donor_summary has NO unique key column — use (donor_name, last_gift) as identifier
-- Estimated rows affected: 31 rows
-- Diagnosed: 2026-03-28
-- =============================================================================

-- -----------------------------------------------------------------------
-- DIAGNOSTIC VERIFICATION
-- -----------------------------------------------------------------------

-- All corrupt last_gift rows
SELECT last_gift, donor_name, total_given, first_gift
FROM nc_donor_summary
WHERE last_gift > '2026-12-31'
ORDER BY last_gift DESC;

-- Count of corrupt rows
SELECT COUNT(*) as corrupt_last_gift_rows
FROM nc_donor_summary
WHERE last_gift > '2026-12-31';

-- Check nc_boe_donations_raw for any future dates
SELECT COUNT(*) as raw_future_dates
FROM nc_boe_donations_raw
WHERE date_occurred > '2026-12-31';

-- Attempt to re-derive last_gift from raw table for affected donor names
SELECT
    s.donor_name,
    s.last_gift as corrupt_last_gift,
    MAX(r.date_occurred) as best_valid_date_from_raw
FROM nc_donor_summary s
LEFT JOIN nc_boe_donations_raw r
    ON r.donor_name = s.donor_name
    AND r.date_occurred <= '2026-12-31'
    AND r.date_occurred IS NOT NULL
WHERE s.last_gift > '2026-12-31'
GROUP BY s.donor_name, s.last_gift
ORDER BY s.last_gift DESC;

-- Ambiguity diagnostic: donor_name can map to multiple distinct donor fingerprints
-- (same name, different zip/city/employer). These should be manual-review cases.
SELECT
    r.donor_name,
    COUNT(DISTINCT CONCAT_WS('|',
        COALESCE(r.zip_code, ''),
        COALESCE(r.city, ''),
        COALESCE(r.employer_name, '')
    )) AS donor_fingerprints,
    MAX(r.date_occurred) AS max_valid_date
FROM nc_boe_donations_raw r
WHERE r.donor_name IN (
    SELECT donor_name
    FROM nc_donor_summary
    WHERE last_gift > '2026-12-31'
)
  AND r.date_occurred <= '2026-12-31'
  AND r.date_occurred IS NOT NULL
GROUP BY r.donor_name
HAVING COUNT(DISTINCT CONCAT_WS('|',
    COALESCE(r.zip_code, ''),
    COALESCE(r.city, ''),
    COALESCE(r.employer_name, '')
)) > 1
ORDER BY donor_fingerprints DESC, r.donor_name;

-- -----------------------------------------------------------------------
-- STEP 1: Create audit log table
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nc_donor_summary_date_fixes_log (
    fix_id          SERIAL PRIMARY KEY,
    donor_name      TEXT,
    original_last_gift DATE,
    recovered_last_gift DATE,
    recovery_method TEXT,
    requires_manual_review BOOLEAN DEFAULT FALSE,
    fixed_at        TIMESTAMPTZ DEFAULT NOW(),
    notes           TEXT
);

COMMENT ON TABLE nc_donor_summary_date_fixes_log IS
    'Audit log of corrupt last_gift date corrections in nc_donor_summary. Created by fix_05 (2026-03-28).';

-- -----------------------------------------------------------------------
-- STEP 2: Add audit columns to nc_donor_summary
-- -----------------------------------------------------------------------
ALTER TABLE nc_donor_summary
    ADD COLUMN IF NOT EXISTS last_gift_corrupt BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS original_last_gift DATE,
    ADD COLUMN IF NOT EXISTS last_gift_recovery_method TEXT;

COMMENT ON COLUMN nc_donor_summary.last_gift_corrupt IS
    'TRUE if last_gift date was corrupt and required investigation. Added fix_05 (2026-03-28).';
COMMENT ON COLUMN nc_donor_summary.original_last_gift IS
    'Original corrupt last_gift value before fix_05 correction (2026-03-28).';

-- -----------------------------------------------------------------------
-- STEP 3: Log all corrupt rows before modification
-- -----------------------------------------------------------------------
BEGIN;

INSERT INTO nc_donor_summary_date_fixes_log
    (donor_name, original_last_gift, recovered_last_gift, recovery_method,
     requires_manual_review, notes)
SELECT
    s.donor_name,
    s.last_gift,
    CASE
        WHEN MAX(r.date_occurred) IS NOT NULL THEN MAX(r.date_occurred)
        ELSE NULL
    END as recovered_date,
    CASE
        WHEN MAX(r.date_occurred) IS NOT NULL THEN 'raw_table_rederive'
        ELSE 'UNRECOVERABLE'
    END as recovery_method,
    CASE
        WHEN MAX(r.date_occurred) IS NULL THEN TRUE
        ELSE FALSE
    END as requires_manual_review,
    'Original last_gift year ' || EXTRACT(YEAR FROM s.last_gift)::text
        || ' is invalid. Attempted re-derive from nc_boe_donations_raw by donor_name match.'
        as notes
FROM nc_donor_summary s
LEFT JOIN nc_boe_donations_raw r
    ON r.donor_name = s.donor_name
    AND r.date_occurred <= '2026-12-31'
    AND r.date_occurred IS NOT NULL
WHERE s.last_gift > '2026-12-31'
  AND NOT EXISTS (
      SELECT 1
      FROM nc_donor_summary_date_fixes_log l
      WHERE l.donor_name = s.donor_name
        AND l.original_last_gift = s.last_gift
  )
GROUP BY s.donor_name, s.last_gift;

SELECT * FROM nc_donor_summary_date_fixes_log ORDER BY original_last_gift DESC;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- STEP 4: Apply fixes — re-derive from raw table where possible
-- -----------------------------------------------------------------------
BEGIN;

-- Mark all corrupt rows (backup original value first)
UPDATE nc_donor_summary
SET original_last_gift = last_gift,
    last_gift_corrupt = TRUE
WHERE last_gift > '2026-12-31';

-- Build donor-name match quality map once
WITH raw_match AS (
    SELECT
        r.donor_name,
        MAX(r.date_occurred) AS best_valid_date,
        COUNT(DISTINCT CONCAT_WS('|',
            COALESCE(r.zip_code, ''),
            COALESCE(r.city, ''),
            COALESCE(r.employer_name, '')
        )) AS donor_fingerprints
    FROM nc_boe_donations_raw r
    WHERE r.date_occurred <= '2026-12-31'
      AND r.date_occurred IS NOT NULL
    GROUP BY r.donor_name
)
-- High-confidence: only one donor fingerprint for this donor_name
UPDATE nc_donor_summary s
SET
    last_gift = rm.best_valid_date,
    last_gift_recovery_method = 'raw_table_rederive_name_unique: MAX(date_occurred) where donor_name has one fingerprint'
FROM raw_match rm
WHERE s.donor_name = rm.donor_name
  AND s.last_gift_corrupt = TRUE
  AND rm.best_valid_date IS NOT NULL
  AND rm.donor_fingerprints = 1;

-- Ambiguous: same donor_name maps to multiple fingerprints, force manual review
WITH raw_match AS (
    SELECT
        r.donor_name,
        COUNT(DISTINCT CONCAT_WS('|',
            COALESCE(r.zip_code, ''),
            COALESCE(r.city, ''),
            COALESCE(r.employer_name, '')
        )) AS donor_fingerprints
    FROM nc_boe_donations_raw r
    WHERE r.date_occurred <= '2026-12-31'
      AND r.date_occurred IS NOT NULL
    GROUP BY r.donor_name
)
UPDATE nc_donor_summary s
SET
    last_gift = NULL,
    last_gift_recovery_method = 'AMBIGUOUS_NAME_MATCH: multiple donor fingerprints in raw source'
FROM raw_match rm
WHERE s.donor_name = rm.donor_name
  AND s.last_gift_corrupt = TRUE
  AND rm.donor_fingerprints > 1;

-- Unrecoverable: no valid raw match at all
UPDATE nc_donor_summary s
SET
    last_gift = NULL,
    last_gift_recovery_method = 'UNRECOVERABLE: no matching valid date in nc_boe_donations_raw'
WHERE s.last_gift_corrupt = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM nc_boe_donations_raw r
      WHERE r.donor_name = s.donor_name
        AND r.date_occurred <= '2026-12-31'
        AND r.date_occurred IS NOT NULL
  );

-- Verify
SELECT
    COUNT(CASE WHEN last_gift_corrupt = TRUE THEN 1 END) as flagged_corrupt,
    COUNT(CASE WHEN last_gift_corrupt = TRUE AND last_gift IS NOT NULL
                AND last_gift <= '2026-12-31' THEN 1 END) as successfully_recovered,
    COUNT(CASE WHEN last_gift_corrupt = TRUE AND last_gift IS NULL THEN 1 END) as set_to_null,
    COUNT(CASE WHEN last_gift > '2026-12-31' THEN 1 END) as still_corrupt
FROM nc_donor_summary;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- ROLLBACK INSTRUCTIONS
-- -----------------------------------------------------------------------
-- BEGIN;
-- UPDATE nc_donor_summary
-- SET last_gift = original_last_gift,
--     last_gift_corrupt = FALSE,
--     last_gift_recovery_method = NULL,
--     original_last_gift = NULL
-- WHERE last_gift_corrupt = TRUE;
-- TRUNCATE nc_donor_summary_date_fixes_log;
-- COMMIT;
