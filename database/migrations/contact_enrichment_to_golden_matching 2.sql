-- ============================================================================
-- BROYHILLGOP: Contact Enrichment → Golden Records Identity Matching
-- ============================================================================
-- Problem: 330K contact_enrichment rows have no matched_golden_record_id.
--         152K of those have emails that could backfill 219K golden records
--         with missing emails — but only after matching.
--
-- This script:
-- 1. Matches contact_enrichment rows to donor_golden_records (same logic as
--    scripts/match_donations_to_donors.py)
-- 2. Updates contact_enrichment.matched_golden_record_id
-- 3. Backfills donor_golden_records.email from contact_enrichment
--
-- Run in Supabase SQL Editor. Column names assumed from transcript — verify
-- with: SELECT column_name FROM information_schema.columns 
--       WHERE table_name = 'contact_enrichment' OR table_name = 'donor_golden_records';
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 0: Verify columns (run first; fix column names below if needed)
-- ----------------------------------------------------------------------------
-- SELECT table_name, column_name FROM information_schema.columns 
-- WHERE table_name IN ('contact_enrichment', 'donor_golden_records')
-- ORDER BY table_name, ordinal_position;

-- Optional: add match_method if missing (run once)
ALTER TABLE contact_enrichment ADD COLUMN IF NOT EXISTS match_method TEXT;

-- Column hints: ce may use zip or zip5; dgr uses zip5 or norm_zip5

-- ----------------------------------------------------------------------------
-- STEP 1: Match by exact first + last + zip5
-- ----------------------------------------------------------------------------
UPDATE contact_enrichment ce
SET matched_golden_record_id = dgr.golden_record_id,
    match_method = 'name_zip_exact'
FROM donor_golden_records dgr
WHERE ce.matched_golden_record_id IS NULL
  AND ce.first_name IS NOT NULL AND ce.first_name != ''
  AND ce.last_name IS NOT NULL AND ce.last_name != ''
  AND COALESCE(ce.zip, ce.zip5, '') != ''
  AND dgr.first_name IS NOT NULL AND dgr.last_name IS NOT NULL
  AND COALESCE(dgr.zip5, dgr.norm_zip5, '') != ''
  AND UPPER(TRIM(ce.first_name)) = UPPER(TRIM(dgr.first_name))
  AND UPPER(TRIM(ce.last_name)) = UPPER(TRIM(dgr.last_name))
  AND LEFT(REGEXP_REPLACE(COALESCE(ce.zip, ce.zip5, ''), '[^0-9]', '', 'g'), 5) 
    = LEFT(REGEXP_REPLACE(COALESCE(dgr.zip5, dgr.norm_zip5, ''), '[^0-9]', '', 'g'), 5);

-- Add match_method column if missing (run once)
-- ALTER TABLE contact_enrichment ADD COLUMN IF NOT EXISTS match_method TEXT;

-- ----------------------------------------------------------------------------
-- STEP 2: Match by first + last + city (fallback)
-- ----------------------------------------------------------------------------
UPDATE contact_enrichment ce
SET matched_golden_record_id = dgr.golden_record_id,
    match_method = COALESCE(ce.match_method, 'name_city')
FROM donor_golden_records dgr
WHERE ce.matched_golden_record_id IS NULL
  AND ce.first_name IS NOT NULL AND ce.first_name != ''
  AND ce.last_name IS NOT NULL AND ce.last_name != ''
  AND ce.city IS NOT NULL AND ce.city != ''
  AND dgr.first_name IS NOT NULL AND dgr.last_name IS NOT NULL
  AND dgr.city IS NOT NULL AND dgr.city != ''
  AND UPPER(TRIM(ce.first_name)) = UPPER(TRIM(dgr.first_name))
  AND UPPER(TRIM(ce.last_name)) = UPPER(TRIM(dgr.last_name))
  AND UPPER(TRIM(ce.city)) = UPPER(TRIM(dgr.city));

-- ----------------------------------------------------------------------------
-- STEP 3: Match by email (highest confidence)
-- ----------------------------------------------------------------------------
UPDATE contact_enrichment ce
SET matched_golden_record_id = dgr.golden_record_id,
    match_method = COALESCE(ce.match_method, 'email_exact')
FROM donor_golden_records dgr
WHERE ce.matched_golden_record_id IS NULL
  AND ce.email IS NOT NULL AND ce.email != ''
  AND dgr.email IS NOT NULL AND dgr.email != ''
  AND LOWER(TRIM(ce.email)) = LOWER(TRIM(dgr.email));

-- ----------------------------------------------------------------------------
-- STEP 4: Match by last name + zip + same first initial (nickname tolerance)
-- ----------------------------------------------------------------------------
UPDATE contact_enrichment ce
SET matched_golden_record_id = sub.golden_record_id,
    match_method = COALESCE(ce.match_method, 'lastname_zip_initial')
FROM (
  SELECT DISTINCT ON (ce.ctid) ce.ctid AS ce_ctid, dgr.golden_record_id
  FROM contact_enrichment ce
  INNER JOIN donor_golden_records dgr ON (
    UPPER(TRIM(ce.last_name)) = UPPER(TRIM(dgr.last_name))
    AND LEFT(REGEXP_REPLACE(COALESCE(ce.zip, ce.zip5, ''), '[^0-9]', '', 'g'), 5) 
      = LEFT(REGEXP_REPLACE(COALESCE(dgr.zip5, dgr.norm_zip5, ''), '[^0-9]', '', 'g'), 5)
    AND LEFT(UPPER(TRIM(NULLIF(ce.first_name, ''))), 1) 
      = LEFT(UPPER(TRIM(NULLIF(dgr.first_name, ''))), 1)
  )
  WHERE ce.matched_golden_record_id IS NULL
    AND ce.first_name IS NOT NULL AND ce.first_name != ''
    AND ce.last_name IS NOT NULL AND ce.last_name != ''
    AND COALESCE(ce.zip, ce.zip5, '') != ''
    AND dgr.first_name IS NOT NULL AND dgr.last_name IS NOT NULL
    AND COALESCE(dgr.zip5, dgr.norm_zip5, '') != ''
  ORDER BY ce.ctid, dgr.total_lifetime_donations DESC NULLS LAST
) sub
WHERE ce.ctid = sub.ce_ctid;

-- ----------------------------------------------------------------------------
-- STEP 5: Match by norm_first / norm_last if those columns exist
-- (Handles ED/EDGAR, JAMES/JIM, etc. — uncomment if donor_golden_records has them)
-- ----------------------------------------------------------------------------
/*
UPDATE contact_enrichment ce
SET matched_golden_record_id = dgr.golden_record_id,
    match_method = COALESCE(ce.match_method, 'norm_name_zip')
FROM donor_golden_records dgr
WHERE ce.matched_golden_record_id IS NULL
  AND ce.first_name IS NOT NULL AND ce.last_name IS NOT NULL AND ce.zip IS NOT NULL
  AND dgr.norm_first IS NOT NULL AND dgr.norm_last IS NOT NULL AND dgr.norm_zip5 IS NOT NULL
  AND UPPER(TRIM(ce.last_name)) = dgr.norm_last
  AND (
    UPPER(TRIM(ce.first_name)) = dgr.norm_first
    OR LEFT(UPPER(TRIM(ce.first_name)), 1) = LEFT(dgr.norm_first, 1)
  )
  AND LEFT(REGEXP_REPLACE(ce.zip, '[^0-9]', '', 'g'), 5) = dgr.norm_zip5;
*/

-- ----------------------------------------------------------------------------
-- STEP 6: Backfill golden record emails from matched contact_enrichment
-- ----------------------------------------------------------------------------
UPDATE donor_golden_records dgr
SET email = ce.email,
    email_source = COALESCE(dgr.email_source, 'contact_enrichment')
FROM contact_enrichment ce
WHERE ce.matched_golden_record_id = dgr.golden_record_id
  AND (dgr.email IS NULL OR dgr.email = '')
  AND ce.email IS NOT NULL AND ce.email != '';

-- ----------------------------------------------------------------------------
-- STEP 7: Summary (run after the above)
-- ----------------------------------------------------------------------------
-- SELECT 
--   (SELECT COUNT(*) FROM contact_enrichment WHERE matched_golden_record_id IS NOT NULL) AS matched_contacts,
--   (SELECT COUNT(*) FROM donor_golden_records WHERE email IS NOT NULL AND email != '') AS golden_with_email;
