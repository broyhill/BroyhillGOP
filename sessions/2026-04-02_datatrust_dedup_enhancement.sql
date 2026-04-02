-- ============================================================================
-- DATATRUST DEDUP ENHANCEMENT
-- BroyhillGOP — Enrich spine from nc_datatrust + improved dedup passes
-- ============================================================================
-- AUTHOR: Perplexity (CEO, AI team)
-- DATE: 2026-04-02
-- STATUS: READ-ONLY DIAGNOSTICS + STAGED ENRICHMENT
--         NO WRITES EXECUTE WITHOUT ED'S AUTHORIZATION
-- ============================================================================
-- CONTEXT:
--   core.person_spine has 128,047 active records
--   99.98% (128,026) have voter_rncid linking to nc_datatrust.rncid
--   But spine.middle_name is 0% populated (DataTrust has 92%)
--   spine.household_id is 20% populated (DataTrust has 100%)
--   spine.suffix is 0.9% populated (DataTrust has 4.7%)
--   These columns are critical for dedup accuracy
-- ============================================================================

-- ============================================================================
-- PHASE A: ENRICHMENT — Backfill spine from DataTrust
-- Populates middle_name, suffix, household_id, reghousenum, regzip4
-- ============================================================================

-- A1: Diagnostic — what will change
-- RUN THIS FIRST (read-only)
SELECT
  COUNT(*) as total_active,
  COUNT(*) FILTER (WHERE s.voter_rncid IS NOT NULL) as has_rncid,
  COUNT(*) FILTER (
    WHERE s.voter_rncid IS NOT NULL
      AND dt.rncid IS NOT NULL
  ) as dt_match,
  COUNT(*) FILTER (
    WHERE s.middle_name IS NULL OR s.middle_name = ''
  ) as missing_middle,
  COUNT(*) FILTER (
    WHERE (s.middle_name IS NULL OR s.middle_name = '')
      AND dt.middlename IS NOT NULL AND dt.middlename != ''
  ) as will_gain_middle,
  COUNT(*) FILTER (
    WHERE (s.suffix IS NULL OR s.suffix = '')
      AND dt.namesuffix IS NOT NULL AND dt.namesuffix != ''
  ) as will_gain_suffix,
  COUNT(*) FILTER (
    WHERE s.household_id IS NULL
      AND dt.householdid IS NOT NULL AND dt.householdid != ''
  ) as will_gain_household_id
FROM core.person_spine s
LEFT JOIN public.nc_datatrust dt ON s.voter_rncid = dt.rncid
WHERE s.is_active = true;

-- A2: Backfill middle_name from DataTrust
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET middle_name = dt.middlename
FROM public.nc_datatrust dt
WHERE s.voter_rncid = dt.rncid
  AND s.is_active = true
  AND (s.middle_name IS NULL OR s.middle_name = '')
  AND dt.middlename IS NOT NULL AND dt.middlename != '';

-- A3: Backfill suffix from DataTrust
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET suffix = dt.namesuffix
FROM public.nc_datatrust dt
WHERE s.voter_rncid = dt.rncid
  AND s.is_active = true
  AND (s.suffix IS NULL OR s.suffix = '')
  AND dt.namesuffix IS NOT NULL AND dt.namesuffix != '';

-- A4: Backfill household_id from DataTrust householdid
-- REQUIRES ED AUTHORIZATION
-- NOTE: DataTrust householdid is VARCHAR, spine household_id is BIGINT
-- Safe cast — DataTrust values are numeric strings (e.g. '5320062')
UPDATE core.person_spine s
SET household_id = dt.householdid::bigint
FROM public.nc_datatrust dt
WHERE s.voter_rncid = dt.rncid
  AND s.is_active = true
  AND s.household_id IS NULL
  AND dt.householdid IS NOT NULL AND dt.householdid != '';


-- ============================================================================
-- PHASE B: ENHANCED DEDUP PASSES (using newly enriched columns)
-- All produce CANDIDATES ONLY into staging.datatrust_enhanced_merge_candidates
-- NO spine records are modified
-- ============================================================================

-- B0: Create staging table for enhanced merge candidates
CREATE TABLE IF NOT EXISTS staging.datatrust_enhanced_merge_candidates (
  id SERIAL PRIMARY KEY,
  keeper_person_id BIGINT NOT NULL,
  merge_person_id BIGINT NOT NULL,
  match_method TEXT NOT NULL,
  confidence NUMERIC(3,2) NOT NULL,
  evidence JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(keeper_person_id, merge_person_id)
);

-- ============================================================================
-- PASS DT-1: SUFFIX DISAMBIGUATION (safety pass — PREVENTS bad merges)
-- ============================================================================
-- This pass does not FIND merges — it BLOCKS them.
-- If two spine records share last+first+zip but have DIFFERENT suffixes
-- (JR vs SR, II vs III), they are NOT the same person.
-- Flag these pairs so downstream passes skip them.
--
-- Example from live data:
--   WILLIAM BRYAN DIXON JR (householdid 1311082, zip 28570)
--   WILLIAM BRYAN DIXON III (householdid 1310991, zip 28557)
--   → Different people. Without suffix, Pass 1 would merge them.

CREATE TABLE IF NOT EXISTS staging.datatrust_merge_blocklist (
  id SERIAL PRIMARY KEY,
  person_id_a BIGINT NOT NULL,
  person_id_b BIGINT NOT NULL,
  block_reason TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(person_id_a, person_id_b)
);

-- DT-1 diagnostic: how many same-name pairs have conflicting suffixes?
SELECT COUNT(*) as blocked_pairs
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.suffix IS NOT NULL AND a.suffix != ''
  AND b.suffix IS NOT NULL AND b.suffix != ''
  AND UPPER(TRIM(a.suffix)) != UPPER(TRIM(b.suffix));

-- DT-1 execute: populate blocklist
-- REQUIRES ED AUTHORIZATION
INSERT INTO staging.datatrust_merge_blocklist (person_id_a, person_id_b, block_reason)
SELECT a.person_id, b.person_id,
  'SUFFIX_CONFLICT: ' || a.suffix || ' vs ' || b.suffix
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.suffix IS NOT NULL AND a.suffix != ''
  AND b.suffix IS NOT NULL AND b.suffix != ''
  AND UPPER(TRIM(a.suffix)) != UPPER(TRIM(b.suffix))
ON CONFLICT DO NOTHING;


-- ============================================================================
-- PASS DT-2: MIDDLE NAME DISAMBIGUATION (safety pass)
-- ============================================================================
-- Same logic as DT-1: if two records share last+first+zip but have
-- DIFFERENT middle names, they may be different people.
-- Less definitive than suffix (middle initial vs full name could match)
-- so this uses a smarter comparison.

-- DT-2 diagnostic: conflicting middle names on same-name pairs
SELECT COUNT(*) as middle_name_conflicts
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.middle_name IS NOT NULL AND a.middle_name != ''
  AND b.middle_name IS NOT NULL AND b.middle_name != ''
  -- Different middle names where neither is a prefix of the other
  -- (allows "J" to match "JAMES" but blocks "JAMES" vs "ROBERT")
  AND UPPER(TRIM(a.middle_name)) != UPPER(TRIM(b.middle_name))
  AND NOT (UPPER(TRIM(a.middle_name)) LIKE UPPER(TRIM(b.middle_name)) || '%')
  AND NOT (UPPER(TRIM(b.middle_name)) LIKE UPPER(TRIM(a.middle_name)) || '%');

-- DT-2 execute: add to blocklist
-- REQUIRES ED AUTHORIZATION
INSERT INTO staging.datatrust_merge_blocklist (person_id_a, person_id_b, block_reason)
SELECT a.person_id, b.person_id,
  'MIDDLE_NAME_CONFLICT: ' || a.middle_name || ' vs ' || b.middle_name
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.middle_name IS NOT NULL AND a.middle_name != ''
  AND b.middle_name IS NOT NULL AND b.middle_name != ''
  AND UPPER(TRIM(a.middle_name)) != UPPER(TRIM(b.middle_name))
  AND NOT (UPPER(TRIM(a.middle_name)) LIKE UPPER(TRIM(b.middle_name)) || '%')
  AND NOT (UPPER(TRIM(b.middle_name)) LIKE UPPER(TRIM(a.middle_name)) || '%')
ON CONFLICT DO NOTHING;


-- ============================================================================
-- PASS DT-3: HOUSEHOLD ID MERGE (high-confidence positive merge)
-- ============================================================================
-- Same DataTrust householdid + same last name + same first initial
-- = confirmed same household, same family name
-- Confidence: 0.92 (household is RNC-deterministic, not address-heuristic)
--
-- This replaces the address-string-based Pass 4b from migration 080
-- with a deterministic RNC household assignment.

-- DT-3 diagnostic
SELECT COUNT(*) as household_merge_candidates
FROM core.person_spine a
JOIN core.person_spine b
  ON a.household_id = b.household_id
  AND a.norm_last = b.norm_last
  AND LEFT(a.norm_first, 1) = LEFT(b.norm_first, 1)
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.household_id IS NOT NULL
  -- Not blocked by suffix or middle name conflicts
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = a.person_id AND bl.person_id_b = b.person_id)
       OR (bl.person_id_a = b.person_id AND bl.person_id_b = a.person_id)
  );

-- DT-3 execute: stage merge candidates
-- REQUIRES ED AUTHORIZATION
INSERT INTO staging.datatrust_enhanced_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'DT3_HOUSEHOLD_SAME_NAME',
  0.92,
  jsonb_build_object(
    'household_id', a.household_id,
    'a_name', a.norm_first || ' ' || COALESCE(a.middle_name,'') || ' ' || a.norm_last || ' ' || COALESCE(a.suffix,''),
    'b_name', b.norm_first || ' ' || COALESCE(b.middle_name,'') || ' ' || b.norm_last || ' ' || COALESCE(b.suffix,''),
    'a_zip', a.zip5, 'b_zip', b.zip5
  )
FROM core.person_spine a
JOIN core.person_spine b
  ON a.household_id = b.household_id
  AND a.norm_last = b.norm_last
  AND LEFT(a.norm_first, 1) = LEFT(b.norm_first, 1)
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.household_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = a.person_id AND bl.person_id_b = b.person_id)
       OR (bl.person_id_a = b.person_id AND bl.person_id_b = a.person_id)
  )
ON CONFLICT DO NOTHING;


-- ============================================================================
-- PASS DT-4: PREV_RNCID CHAIN RESOLUTION (high-confidence)
-- ============================================================================
-- DataTrust prev_rncid links a person's old RNCID to their current one.
-- If spine record A has voter_rncid = X, and DataTrust shows prev_rncid = X
-- for a different person with current rncid = Y, and spine record B has
-- voter_rncid = Y → A and B are the same person (re-registered).
-- Confidence: 0.97 (deterministic RNC chain)

-- DT-4 diagnostic: how many spine records have a prev_rncid that maps
-- to another active spine record?
SELECT COUNT(*) as prev_rncid_merge_candidates
FROM core.person_spine a
JOIN public.nc_datatrust dt ON a.voter_rncid = dt.prev_rncid
JOIN core.person_spine b ON dt.rncid = b.voter_rncid
WHERE a.is_active = true AND b.is_active = true
  AND a.person_id != b.person_id
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = LEAST(a.person_id, b.person_id)
      AND bl.person_id_b = GREATEST(a.person_id, b.person_id))
  );

-- DT-4 execute: stage merge candidates
-- REQUIRES ED AUTHORIZATION
INSERT INTO staging.datatrust_enhanced_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'DT4_PREV_RNCID_CHAIN',
  0.97,
  jsonb_build_object(
    'old_rncid', a.voter_rncid,
    'current_rncid', b.voter_rncid,
    'a_name', a.norm_first || ' ' || a.norm_last,
    'b_name', b.norm_first || ' ' || b.norm_last,
    'a_zip', a.zip5, 'b_zip', b.zip5
  )
FROM core.person_spine a
JOIN public.nc_datatrust dt ON a.voter_rncid = dt.prev_rncid
JOIN core.person_spine b ON dt.rncid = b.voter_rncid
WHERE a.is_active = true AND b.is_active = true
  AND a.person_id != b.person_id
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = LEAST(a.person_id, b.person_id)
      AND bl.person_id_b = GREATEST(a.person_id, b.person_id))
  )
ON CONFLICT DO NOTHING;


-- ============================================================================
-- PASS DT-5: 9-DIGIT ZIP + HOUSE NUMBER + LAST NAME (Ed's rule)
-- ============================================================================
-- Ed's principle: 9-digit zip = 100% pairing accuracy
-- Combined with reghousenum + last name, this is a deterministic match
-- for people at the exact same physical address with the same surname.
-- Confidence: 0.95
--
-- This uses DataTrust's pre-parsed reghousenum (no string parsing needed)
-- and the +4 zip extension that we were ignoring.

-- First, we need to get regzip4 and reghousenum onto the spine for matching.
-- We'll use a CTE rather than modifying the spine table.

-- DT-5 diagnostic
WITH spine_enriched AS (
  SELECT s.person_id, s.norm_first, s.norm_last, s.zip5, s.suffix,
         s.middle_name, s.is_active,
         dt.regzip4, dt.reghousenum
  FROM core.person_spine s
  JOIN public.nc_datatrust dt ON s.voter_rncid = dt.rncid
  WHERE s.is_active = true
    AND dt.regzip4 IS NOT NULL AND dt.regzip4 != ''
    AND dt.reghousenum IS NOT NULL AND dt.reghousenum != ''
)
SELECT COUNT(*) as nine_digit_zip_merge_candidates
FROM spine_enriched a
JOIN spine_enriched b
  ON a.zip5 = b.zip5
  AND a.regzip4 = b.regzip4
  AND a.reghousenum = b.reghousenum
  AND a.norm_last = b.norm_last
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  -- Exclude blocked pairs
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = a.person_id AND bl.person_id_b = b.person_id)
       OR (bl.person_id_a = b.person_id AND bl.person_id_b = a.person_id)
  );

-- DT-5 execute: stage merge candidates
-- REQUIRES ED AUTHORIZATION
INSERT INTO staging.datatrust_enhanced_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
WITH spine_enriched AS (
  SELECT s.person_id, s.norm_first, s.norm_last, s.zip5, s.suffix,
         s.middle_name, s.is_active, s.voter_rncid,
         dt.regzip4, dt.reghousenum
  FROM core.person_spine s
  JOIN public.nc_datatrust dt ON s.voter_rncid = dt.rncid
  WHERE s.is_active = true
    AND dt.regzip4 IS NOT NULL AND dt.regzip4 != ''
    AND dt.reghousenum IS NOT NULL AND dt.reghousenum != ''
)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'DT5_9DIGIT_ZIP_HOUSENUM_LAST',
  0.95,
  jsonb_build_object(
    'full_zip', a.zip5 || '-' || a.regzip4,
    'house_num', a.reghousenum,
    'a_name', a.norm_first || ' ' || a.norm_last || COALESCE(' ' || a.suffix, ''),
    'b_name', b.norm_first || ' ' || b.norm_last || COALESCE(' ' || b.suffix, ''),
    'a_middle', a.middle_name, 'b_middle', b.middle_name
  )
FROM spine_enriched a
JOIN spine_enriched b
  ON a.zip5 = b.zip5
  AND a.regzip4 = b.regzip4
  AND a.reghousenum = b.reghousenum
  AND a.norm_last = b.norm_last
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = a.person_id AND bl.person_id_b = b.person_id)
       OR (bl.person_id_a = b.person_id AND bl.person_id_b = a.person_id)
  )
ON CONFLICT DO NOTHING;


-- ============================================================================
-- PASS DT-6: CROSS-ZIP MOVER RESOLUTION (via changeofaddressdate)
-- ============================================================================
-- Same name at different zips — normally ambiguous.
-- But if DataTrust shows a changeofaddressdate for one record,
-- AND the old address zip matches the other record's zip,
-- they're the same person who moved.
-- Confidence: 0.90
--
-- changeofaddressdate is only 7.6% populated (~582K rows)
-- but for the donors it covers, this resolves cross-zip duplicates
-- that no other pass can safely touch.

-- DT-6 diagnostic: how many spine pairs could this resolve?
-- (This is expensive — uses previousstate logic as proxy)
SELECT COUNT(*) as cross_zip_coa_candidates
FROM core.person_spine a
JOIN public.nc_datatrust dt_a ON a.voter_rncid = dt_a.rncid
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 != b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND dt_a.changeofaddressdate IS NOT NULL
  AND dt_a.changeofaddressdate != ''
  AND NOT EXISTS (
    SELECT 1 FROM staging.datatrust_merge_blocklist bl
    WHERE (bl.person_id_a = a.person_id AND bl.person_id_b = b.person_id)
       OR (bl.person_id_a = b.person_id AND bl.person_id_b = a.person_id)
  );


-- ============================================================================
-- SAFETY QUERIES — Run after all passes
-- ============================================================================

-- BROYHILL CANARY: Ed and Melanie must NOT appear as a merge pair
SELECT * FROM staging.datatrust_enhanced_merge_candidates
WHERE keeper_person_id = 26451 OR merge_person_id = 26451;

-- ART POPE CANARY: Should have at most 1 merge pair (already canonical)
SELECT * FROM staging.datatrust_enhanced_merge_candidates
WHERE keeper_person_id IN (SELECT person_id FROM core.person_spine WHERE norm_last = 'POPE' AND norm_first = 'ART' AND is_active = true)
   OR merge_person_id IN (SELECT person_id FROM core.person_spine WHERE norm_last = 'POPE' AND norm_first = 'ART' AND is_active = true);

-- SUMMARY BY PASS
SELECT match_method, COUNT(*) as candidates, ROUND(AVG(confidence), 2) as avg_conf
FROM staging.datatrust_enhanced_merge_candidates
GROUP BY match_method
ORDER BY match_method;

-- BLOCKLIST SUMMARY
SELECT block_reason, COUNT(*)
FROM staging.datatrust_merge_blocklist
GROUP BY block_reason
ORDER BY COUNT(*) DESC;

-- OVERLAP: how many candidates are ALSO in the existing 7-pass queue?
SELECT COUNT(*) as overlap
FROM staging.datatrust_enhanced_merge_candidates emc
JOIN staging.donor_merge_candidates dmc
  ON (emc.keeper_person_id = dmc.keeper_person_id AND emc.merge_person_id = dmc.merge_person_id)
  OR (emc.keeper_person_id = dmc.merge_person_id AND emc.merge_person_id = dmc.keeper_person_id);


-- ============================================================================
-- END — All passes produce staging candidates only.
-- Merge execution is a SEPARATE authorized step.
-- ============================================================================
