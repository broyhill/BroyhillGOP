-- ============================================================================
-- DATATRUST DEDUP ENHANCEMENT — V2 PATCH
-- Incorporates nc_voters (9M rows) as primary enrichment source
-- ============================================================================
-- ADDENDUM to 2026-04-02_datatrust_dedup_enhancement.sql
-- AUTHOR: Perplexity
-- DATE: 2026-04-02
--
-- FINDING: nc_voters has middle_name (91%), name_suffix_lbl (5%),
--   canonical_first_name (32.5% = 2.9M nickname resolutions done BY THE STATE),
--   birth_year (100%), and res_street_address (100%).
--   Join: core.person_spine.voter_ncid = nc_voters.ncid → 99.98% match.
--
-- PRIORITY ORDER for enrichment:
--   1. nc_voters (state source of truth, 9M rows)
--   2. nc_datatrust (RNC overlay, 7.66M rows, has householdid/prev_rncid)
-- ============================================================================

-- ============================================================================
-- PHASE A-REVISED: ENRICHMENT FROM NC_VOTERS FIRST, THEN DATATRUST
-- ============================================================================

-- A0: Diagnostic — what nc_voters will provide vs DataTrust
SELECT
  COUNT(*) as active_spine,
  -- Middle name: nc_voters first
  COUNT(*) FILTER (
    WHERE (s.middle_name IS NULL OR s.middle_name = '')
      AND nv.middle_name IS NOT NULL AND nv.middle_name != ''
  ) as will_gain_middle_from_ncv,
  -- Middle name: DataTrust fills remaining gaps
  COUNT(*) FILTER (
    WHERE (s.middle_name IS NULL OR s.middle_name = '')
      AND (nv.middle_name IS NULL OR nv.middle_name = '')
      AND dt.middlename IS NOT NULL AND dt.middlename != ''
  ) as will_gain_middle_from_dt,
  -- Suffix: nc_voters first
  COUNT(*) FILTER (
    WHERE (s.suffix IS NULL OR s.suffix = '')
      AND nv.name_suffix_lbl IS NOT NULL AND nv.name_suffix_lbl != ''
  ) as will_gain_suffix_from_ncv,
  -- Suffix: DataTrust fills remaining
  COUNT(*) FILTER (
    WHERE (s.suffix IS NULL OR s.suffix = '')
      AND (nv.name_suffix_lbl IS NULL OR nv.name_suffix_lbl = '')
      AND dt.namesuffix IS NOT NULL AND dt.namesuffix != ''
  ) as will_gain_suffix_from_dt,
  -- Canonical first name: nc_voters ONLY (DataTrust doesn't have this)
  COUNT(*) FILTER (
    WHERE nv.canonical_first_name IS NOT NULL
      AND nv.canonical_first_name != ''
      AND nv.canonical_first_name != nv.first_name
  ) as has_nickname_resolution,
  -- Birth year: nc_voters ONLY (100% fill)
  COUNT(*) FILTER (
    WHERE nv.birth_year IS NOT NULL AND nv.birth_year != ''
  ) as has_birth_year,
  -- Household ID: DataTrust ONLY (nc_voters doesn't have this)
  COUNT(*) FILTER (
    WHERE s.household_id IS NULL
      AND dt.householdid IS NOT NULL AND dt.householdid != ''
  ) as will_gain_household_from_dt
FROM core.person_spine s
LEFT JOIN public.nc_voters nv ON s.voter_ncid = nv.ncid
LEFT JOIN public.nc_datatrust dt ON s.voter_rncid = dt.rncid
WHERE s.is_active = true;


-- A2-REVISED: Backfill middle_name — nc_voters first
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET middle_name = nv.middle_name
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND (s.middle_name IS NULL OR s.middle_name = '')
  AND nv.middle_name IS NOT NULL AND nv.middle_name != '';

-- A2b: Backfill middle_name — DataTrust fills remaining gaps
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET middle_name = dt.middlename
FROM public.nc_datatrust dt
WHERE s.voter_rncid = dt.rncid
  AND s.is_active = true
  AND (s.middle_name IS NULL OR s.middle_name = '')
  AND dt.middlename IS NOT NULL AND dt.middlename != '';


-- A3-REVISED: Backfill suffix — nc_voters first
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET suffix = nv.name_suffix_lbl
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND (s.suffix IS NULL OR s.suffix = '')
  AND nv.name_suffix_lbl IS NOT NULL AND nv.name_suffix_lbl != '';

-- A3b: Backfill suffix — DataTrust fills remaining
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET suffix = dt.namesuffix
FROM public.nc_datatrust dt
WHERE s.voter_rncid = dt.rncid
  AND s.is_active = true
  AND (s.suffix IS NULL OR s.suffix = '')
  AND dt.namesuffix IS NOT NULL AND dt.namesuffix != '';


-- ============================================================================
-- NEW COLUMN: Add birth_year and canonical_first_name to spine
-- ============================================================================
-- These columns may not exist on person_spine yet. Check first.

-- A5: Add birth_year column if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'core' AND table_name = 'person_spine'
      AND column_name = 'birth_year'
  ) THEN
    ALTER TABLE core.person_spine ADD COLUMN birth_year SMALLINT;
  END IF;
END $$;

-- A6: Add canonical_first_name column if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'core' AND table_name = 'person_spine'
      AND column_name = 'canonical_first_name'
  ) THEN
    ALTER TABLE core.person_spine ADD COLUMN canonical_first_name TEXT;
  END IF;
END $$;

-- A7: Backfill birth_year from nc_voters (100% coverage)
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET birth_year = nv.birth_year::smallint
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND s.birth_year IS NULL
  AND nv.birth_year IS NOT NULL AND nv.birth_year != ''
  AND nv.birth_year ~ '^\d{4}$';

-- A8: Backfill canonical_first_name from nc_voters
-- This is the NC BOE's own nickname resolution:
--   LARRY → LAWRENCE, BOBBY → ROBERT, JERRY → GERALD,
--   JOE → JOSEPH, ED → EDWARD, BILL → WILLIAM, etc.
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET canonical_first_name = nv.canonical_first_name
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND s.canonical_first_name IS NULL
  AND nv.canonical_first_name IS NOT NULL AND nv.canonical_first_name != '';


-- ============================================================================
-- ENHANCED DEDUP PASS: CANONICAL NAME MATCHING (replaces nickname tables)
-- ============================================================================
-- PASS DT-7: CANONICAL FIRST NAME MATCH
-- Uses nc_voters' canonical_first_name to match records that filed
-- under different nicknames of the same legal name.
--
-- Example: Spine has "ED BROYHILL 27104" and "EDWARD BROYHILL 27104"
-- nc_voters says ED's canonical = EDWARD → same person.
-- This replaces Pass 4 nickname+zip from migration 080 with
-- state-authoritative resolution instead of our 326-row nickname table.
--
-- Confidence: 0.93 (state source, not heuristic)

-- DT-7 diagnostic
SELECT COUNT(*) as canonical_name_merge_candidates
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  -- Different norm_first (otherwise already merged by Pass 1)
  AND a.norm_first != b.norm_first
  -- But same canonical_first_name (state says they're the same name)
  AND a.canonical_first_name IS NOT NULL
  AND b.canonical_first_name IS NOT NULL
  AND a.canonical_first_name = b.canonical_first_name
  -- Not blocked
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = a.person_id AND bl.person_id_b = b.person_id)
       OR (bl.person_id_a = b.person_id AND bl.person_id_b = a.person_id)
  );

-- DT-7 execute: stage merge candidates
-- REQUIRES ED AUTHORIZATION
INSERT INTO staging.datatrust_enhanced_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'DT7_CANONICAL_FIRST_NAME',
  0.93,
  jsonb_build_object(
    'canonical_name', a.canonical_first_name,
    'a_filed_as', a.norm_first,
    'b_filed_as', b.norm_first,
    'last_name', a.norm_last,
    'zip', a.zip5
  )
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.norm_first != b.norm_first
  AND a.canonical_first_name IS NOT NULL
  AND b.canonical_first_name IS NOT NULL
  AND a.canonical_first_name = b.canonical_first_name
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = a.person_id AND bl.person_id_b = b.person_id)
       OR (bl.person_id_a = b.person_id AND bl.person_id_b = a.person_id)
  )
ON CONFLICT DO NOTHING;


-- ============================================================================
-- ENHANCED BLOCKLIST: BIRTH YEAR DISAMBIGUATION
-- ============================================================================
-- PASS DT-8: BIRTH YEAR BLOCKLIST
-- Same name + same zip + different birth year (> 2 years apart)
-- = different people (father/son, unrelated same-name).
-- This is the strongest disambiguation signal in the dataset
-- because birth_year is 100% populated from nc_voters.
--
-- Threshold: 2 years allows for data entry errors (off-by-one)
-- but catches father/son (typically 20-40 year gap).

-- DT-8 diagnostic
SELECT COUNT(*) as birth_year_blocks
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.birth_year IS NOT NULL AND b.birth_year IS NOT NULL
  AND ABS(a.birth_year - b.birth_year) > 2;

-- DT-8 execute: add to blocklist
-- REQUIRES ED AUTHORIZATION
INSERT INTO staging.datatrust_merge_blocklist (person_id_a, person_id_b, block_reason)
SELECT a.person_id, b.person_id,
  'BIRTH_YEAR_GAP: ' || a.birth_year || ' vs ' || b.birth_year
    || ' (delta ' || ABS(a.birth_year - b.birth_year) || ' years)'
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.birth_year IS NOT NULL AND b.birth_year IS NOT NULL
  AND ABS(a.birth_year - b.birth_year) > 2
ON CONFLICT DO NOTHING;


-- ============================================================================
-- FULL SUMMARY — Run after all passes
-- ============================================================================

-- Enrichment coverage after backfill
SELECT
  COUNT(*) as active,
  COUNT(middle_name) FILTER (WHERE middle_name IS NOT NULL AND middle_name != '') as has_middle,
  COUNT(suffix) FILTER (WHERE suffix IS NOT NULL AND suffix != '') as has_suffix,
  COUNT(birth_year) FILTER (WHERE birth_year IS NOT NULL) as has_birth_year,
  COUNT(canonical_first_name) FILTER (WHERE canonical_first_name IS NOT NULL AND canonical_first_name != '') as has_canonical_first,
  COUNT(household_id) FILTER (WHERE household_id IS NOT NULL) as has_household_id
FROM core.person_spine WHERE is_active = true;

-- Merge candidates by pass
SELECT match_method, COUNT(*) as candidates, ROUND(AVG(confidence), 2) as avg_conf
FROM staging.datatrust_enhanced_merge_candidates
GROUP BY match_method
ORDER BY match_method;

-- Blocklist by reason
SELECT
  SPLIT_PART(block_reason, ':', 1) as reason_type,
  COUNT(*) as blocked_pairs
FROM staging.datatrust_merge_blocklist
GROUP BY SPLIT_PART(block_reason, ':', 1)
ORDER BY COUNT(*) DESC;

-- BROYHILL CANARY
SELECT 'MERGE_CANDIDATES' as source, * FROM staging.datatrust_enhanced_merge_candidates
WHERE keeper_person_id = 26451 OR merge_person_id = 26451
UNION ALL
SELECT 'BLOCKLIST', person_id_a, person_id_b, block_reason, NULL, NULL, NOW()
FROM staging.datatrust_merge_blocklist
WHERE person_id_a = 26451 OR person_id_b = 26451;
