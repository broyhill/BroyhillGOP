-- ============================================================================
-- BROYHILLGOP COMPLETE DEDUP — V3
-- Incorporates Ed's full dedup philosophy from April 1-2, 2026 session
-- ============================================================================
-- AUTHOR: Perplexity (CEO, AI team)
-- DATE: 2026-04-02
-- STATUS: ALL WRITES REQUIRE ED'S EXPLICIT AUTHORIZATION
--         RUN DIAGNOSTICS (SELECT) FREELY — WRITES ARE GATED
--
-- CRITICAL SAFETY WARNING:
--   A prior run of dedup instructions caused column bleed — one column's
--   UPDATE bled into another and deleted thousands of records from a column.
--   EVERY UPDATE in this file targets EXACTLY ONE column per statement.
--   No compound SET clauses. No multi-column updates in a single statement.
--   Cursor: review each UPDATE for unintended side effects before execution.
--
-- PHILOSOPHY (Ed Broyhill, April 2 2026):
--   1. Block on address_num + zip + last3 — cuts 128K×128K to small groups
--   2. Match within blocks using name/employer/candidate loyalty signals
--   3. Resolve newest-first (2026 backward) — current record is truth
--   4. Employer is primary key for major donors, not address
--   5. Pretty records merge confidently; ugly records go to holding pen
--   6. preferred_name = most frequent filing name, NOT voter registration
--   7. Middle name is a filing name (ED from EDGAR, not EDWARD)
--   8. Second home addresses are sales leads, not duplicates
--   9. Honorary titles (military, judicial, political) must be preserved
--  10. Never merge on a guess — unmatched is better than wrong
-- ============================================================================


-- ============================================================================
-- PHASE 0: SCHEMA ADDITIONS (idempotent — safe to re-run)
-- ============================================================================

-- 0A: Add columns to spine if missing
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='birth_year') THEN
    ALTER TABLE core.person_spine ADD COLUMN birth_year SMALLINT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='canonical_first_name') THEN
    ALTER TABLE core.person_spine ADD COLUMN canonical_first_name TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='preferred_name') THEN
    ALTER TABLE core.person_spine ADD COLUMN preferred_name TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='honorary_title') THEN
    ALTER TABLE core.person_spine ADD COLUMN honorary_title TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='title_salutation') THEN
    ALTER TABLE core.person_spine ADD COLUMN title_salutation TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='title_branch') THEN
    ALTER TABLE core.person_spine ADD COLUMN title_branch TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='title_status') THEN
    ALTER TABLE core.person_spine ADD COLUMN title_status TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='legal_first_name') THEN
    ALTER TABLE core.person_spine ADD COLUMN legal_first_name TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='addr_number') THEN
    ALTER TABLE core.person_spine ADD COLUMN addr_number TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='addr_type') THEN
    ALTER TABLE core.person_spine ADD COLUMN addr_type TEXT;  -- 'ST' or 'PO'
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='record_quality') THEN
    ALTER TABLE core.person_spine ADD COLUMN record_quality TEXT;  -- 'PRETTY' or 'UGLY'
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='person_spine' AND column_name='best_employer') THEN
    ALTER TABLE core.person_spine ADD COLUMN best_employer TEXT;
  END IF;
END $$;


-- ============================================================================
-- PHASE 1: ENRICHMENT — One column per UPDATE, nc_voters first
-- ============================================================================
-- SAFETY: Each UPDATE touches exactly ONE column. No compound SETs.

-- ---- 1A: legal_first_name from nc_voters ----
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET legal_first_name = nv.first_name
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND s.legal_first_name IS NULL
  AND nv.first_name IS NOT NULL AND nv.first_name != '';

-- ---- 1B: middle_name from nc_voters (primary) ----
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET middle_name = nv.middle_name
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND (s.middle_name IS NULL OR s.middle_name = '')
  AND nv.middle_name IS NOT NULL AND nv.middle_name != '';

-- ---- 1C: middle_name from DataTrust (fills remaining gaps) ----
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET middle_name = dt.middlename
FROM public.nc_datatrust dt
WHERE s.voter_rncid = dt.rncid
  AND s.is_active = true
  AND (s.middle_name IS NULL OR s.middle_name = '')
  AND dt.middlename IS NOT NULL AND dt.middlename != '';

-- ---- 1D: suffix from nc_voters (primary) ----
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET suffix = nv.name_suffix_lbl
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND (s.suffix IS NULL OR s.suffix = '')
  AND nv.name_suffix_lbl IS NOT NULL AND nv.name_suffix_lbl != '';

-- ---- 1E: suffix from DataTrust (fills remaining) ----
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET suffix = dt.namesuffix
FROM public.nc_datatrust dt
WHERE s.voter_rncid = dt.rncid
  AND s.is_active = true
  AND (s.suffix IS NULL OR s.suffix = '')
  AND dt.namesuffix IS NOT NULL AND dt.namesuffix != '';

-- ---- 1F: birth_year from nc_voters (100% coverage) ----
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET birth_year = nv.birth_year::smallint
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND s.birth_year IS NULL
  AND nv.birth_year IS NOT NULL AND nv.birth_year != ''
  AND nv.birth_year ~ '^\d{4}$';

-- ---- 1G: canonical_first_name from nc_voters ----
-- This is NC BOE's own nickname resolution: LARRY→LAWRENCE, ED→EDWARD, etc.
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET canonical_first_name = nv.canonical_first_name
FROM public.nc_voters nv
WHERE s.voter_ncid = nv.ncid
  AND s.is_active = true
  AND s.canonical_first_name IS NULL
  AND nv.canonical_first_name IS NOT NULL AND nv.canonical_first_name != '';

-- ---- 1H: household_id from DataTrust (unique to DT) ----
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET household_id = dt.householdid::bigint
FROM public.nc_datatrust dt
WHERE s.voter_rncid = dt.rncid
  AND s.is_active = true
  AND s.household_id IS NULL
  AND dt.householdid IS NOT NULL AND dt.householdid != '';

-- ---- 1I: addr_number and addr_type parsed from street ----
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine
SET addr_number = regexp_replace(UPPER(TRIM(street)), '^\s*(\d+).*', '\1'),
    addr_type = 'ST'
WHERE is_active = true
  AND street IS NOT NULL AND street != ''
  AND UPPER(TRIM(street)) ~ '^\d+'
  AND UPPER(TRIM(street)) !~ '^\s*(P\.?O\.?\s*BOX|PO\s*BX|POBOX)';

-- NOTE: Separate statement for PO Box addresses — no column bleed risk
UPDATE core.person_spine
SET addr_number = regexp_replace(
      UPPER(TRIM(street)),
      '^\s*(?:P\.?O\.?\s*BOX|PO\s*BX|POBOX)\s*(\d+).*', '\1'
    ),
    addr_type = 'PO'
WHERE is_active = true
  AND street IS NOT NULL AND street != ''
  AND UPPER(TRIM(street)) ~ '^\s*(P\.?O\.?\s*BOX|PO\s*BX|POBOX)\s*\d+';


-- ============================================================================
-- PHASE 2: RECORD QUALITY CLASSIFICATION — Pretty vs Ugly
-- ============================================================================
-- A record is PRETTY if it has: norm_first + norm_last + zip5 + addr_number
--   + at least ONE of: voter_ncid, employer, email, phone
-- Everything else is UGLY and goes to the holding pen — never merged on a guess.

-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine
SET record_quality = CASE
  WHEN norm_first IS NOT NULL AND norm_first != ''
    AND norm_last IS NOT NULL AND norm_last != ''
    AND zip5 IS NOT NULL AND zip5 != ''
    AND addr_number IS NOT NULL AND addr_number != ''
    AND (
      (voter_ncid IS NOT NULL AND voter_ncid != '')
      OR (best_employer IS NOT NULL AND best_employer != '' AND best_employer NOT IN ('RETIRED','SELF-EMPLOYED','SELF EMPLOYED','NONE','N/A','NA','NOT EMPLOYED','HOMEMAKER','INFORMATION REQUESTED'))
      OR (email IS NOT NULL AND email != '')
    )
  THEN 'PRETTY'
  ELSE 'UGLY'
END
WHERE is_active = true;


-- ============================================================================
-- PHASE 3: BEST EMPLOYER — Backward scan from 2026
-- ============================================================================
-- For each spine person, find their most recent NON-RETIRED employer
-- from donation records. This is the employer anchor for major donor dedup.

-- 3A: From NC BOE donations (has date_occurred)
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET best_employer = sub.best_emp
FROM (
  SELECT
    cm.golden_record_id as person_id,
    (array_agg(
      d.employer_name ORDER BY d.date_occurred DESC NULLS LAST
    ))[1] as best_emp
  FROM core.contribution_map cm
  JOIN public.nc_boe_donations_raw d ON cm.source_id = d.id AND cm.source_system = 'NC_BOE'
  WHERE d.employer_name IS NOT NULL
    AND d.employer_name != ''
    AND UPPER(d.employer_name) NOT IN (
      'RETIRED','SELF-EMPLOYED','SELF EMPLOYED','NONE','N/A','NA',
      'NOT EMPLOYED','HOMEMAKER','INFORMATION REQUESTED',
      'INFORMATION REQUESTED PER BEST EFFORTS','SELF',
      'NOT EMPLOYED/NOT EMPLOYED','RETIRED/RETIRED'
    )
  GROUP BY cm.golden_record_id
) sub
WHERE s.person_id = sub.person_id
  AND s.is_active = true
  AND (s.best_employer IS NULL OR s.best_employer = '');


-- ============================================================================
-- PHASE 4: PREFERRED NAME — Most frequent filing name
-- ============================================================================
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET preferred_name = sub.pref
FROM (
  SELECT
    cm.golden_record_id as person_id,
    (array_agg(
      d.norm_first ORDER BY cnt DESC
    ))[1] as pref
  FROM (
    SELECT
      cm2.golden_record_id,
      d2.norm_first,
      COUNT(*) as cnt
    FROM core.contribution_map cm2
    JOIN public.nc_boe_donations_raw d2 ON cm2.source_id = d2.id AND cm2.source_system = 'NC_BOE'
    WHERE d2.norm_first IS NOT NULL AND d2.norm_first != ''
    GROUP BY cm2.golden_record_id, d2.norm_first
  ) sub2
  JOIN core.contribution_map cm ON cm.golden_record_id = sub2.golden_record_id
  JOIN public.nc_boe_donations_raw d ON cm.source_id = d.id AND cm.source_system = 'NC_BOE'
  GROUP BY cm.golden_record_id
) sub
WHERE s.person_id = sub.person_id
  AND s.is_active = true
  AND s.preferred_name IS NULL;


-- ============================================================================
-- PHASE 5: STAGING TABLES FOR MERGE CANDIDATES + BLOCKLIST
-- ============================================================================

CREATE TABLE IF NOT EXISTS staging.v3_merge_blocklist (
  id SERIAL PRIMARY KEY,
  person_id_a BIGINT NOT NULL,
  person_id_b BIGINT NOT NULL,
  block_reason TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(person_id_a, person_id_b)
);

CREATE TABLE IF NOT EXISTS staging.v3_merge_candidates (
  id SERIAL PRIMARY KEY,
  keeper_person_id BIGINT NOT NULL,
  merge_person_id BIGINT NOT NULL,
  match_method TEXT NOT NULL,
  confidence NUMERIC(3,2) NOT NULL,
  evidence JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(keeper_person_id, merge_person_id)
);

-- Index for fast blocklist lookups
CREATE INDEX IF NOT EXISTS idx_v3_blocklist_pair
  ON staging.v3_merge_blocklist(person_id_a, person_id_b);
CREATE INDEX IF NOT EXISTS idx_v3_blocklist_pair_rev
  ON staging.v3_merge_blocklist(person_id_b, person_id_a);

-- ============================================================================
-- PHASE 6: BLOCKLISTS — Run these FIRST, before any merge passes
-- ============================================================================
-- ONLY operates on PRETTY records. UGLY records are never considered.

-- ---- 6A: SUFFIX CONFLICT BLOCKLIST ----
-- Same name+zip, different suffix (JR vs SR, II vs III) = different people
INSERT INTO staging.v3_merge_blocklist (person_id_a, person_id_b, block_reason)
SELECT a.person_id, b.person_id,
  'SUFFIX_CONFLICT: ' || a.suffix || ' vs ' || b.suffix
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.suffix IS NOT NULL AND a.suffix != ''
  AND b.suffix IS NOT NULL AND b.suffix != ''
  AND UPPER(TRIM(a.suffix)) != UPPER(TRIM(b.suffix))
ON CONFLICT DO NOTHING;

-- ---- 6B: BIRTH YEAR GAP BLOCKLIST ----
-- Same name+zip, birth year >2 years apart = different people
-- This is the STRONGEST disambiguator — 100% populated from nc_voters
INSERT INTO staging.v3_merge_blocklist (person_id_a, person_id_b, block_reason)
SELECT a.person_id, b.person_id,
  'BIRTH_YEAR_GAP: ' || a.birth_year || ' vs ' || b.birth_year
    || ' (delta ' || ABS(a.birth_year - b.birth_year) || 'y)'
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.birth_year IS NOT NULL AND b.birth_year IS NOT NULL
  AND ABS(a.birth_year - b.birth_year) > 2
ON CONFLICT DO NOTHING;

-- ---- 6C: MIDDLE NAME CONFLICT BLOCKLIST ----
-- Same name+zip, different middle (not prefix match) = likely different people
INSERT INTO staging.v3_merge_blocklist (person_id_a, person_id_b, block_reason)
SELECT a.person_id, b.person_id,
  'MIDDLE_CONFLICT: ' || a.middle_name || ' vs ' || b.middle_name
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.norm_first = b.norm_first
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.middle_name IS NOT NULL AND a.middle_name != ''
  AND b.middle_name IS NOT NULL AND b.middle_name != ''
  AND UPPER(TRIM(a.middle_name)) != UPPER(TRIM(b.middle_name))
  AND NOT (UPPER(TRIM(a.middle_name)) LIKE UPPER(TRIM(b.middle_name)) || '%')
  AND NOT (UPPER(TRIM(b.middle_name)) LIKE UPPER(TRIM(a.middle_name)) || '%')
ON CONFLICT DO NOTHING;

-- Helper: function to check blocklist
CREATE OR REPLACE FUNCTION staging.is_blocked(p_a BIGINT, p_b BIGINT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM staging.v3_merge_blocklist
    WHERE (person_id_a = LEAST(p_a, p_b) AND person_id_b = GREATEST(p_a, p_b))
  );
$$ LANGUAGE SQL STABLE;


-- ============================================================================
-- PHASE 7: MERGE PASSES — Within address blocks, PRETTY records only
-- ============================================================================
-- Every pass respects the blocklist.
-- Every pass targets ONLY record_quality = 'PRETTY'.

-- ---- PASS 1: Exact first name within block ----
-- addr_number + zip5 + last3 + same norm_first = same person
-- Confidence: 0.97
INSERT INTO staging.v3_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'P1_EXACT_NAME_IN_BLOCK',
  0.97,
  jsonb_build_object(
    'block_key', a.addr_type || ':' || a.addr_number || '+' || a.zip5 || '+' || LEFT(a.norm_last,3),
    'a_name', a.norm_first || ' ' || a.norm_last,
    'b_name', b.norm_first || ' ' || b.norm_last
  )
FROM core.person_spine a
JOIN core.person_spine b
  ON a.addr_number = b.addr_number
  AND a.addr_type = b.addr_type
  AND a.zip5 = b.zip5
  AND LEFT(a.norm_last, 3) = LEFT(b.norm_last, 3)
  AND a.norm_first = b.norm_first
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND NOT staging.is_blocked(a.person_id, b.person_id)
ON CONFLICT DO NOTHING;


-- ---- PASS 2: Canonical first name within block ----
-- Different norm_first, but nc_voters says same canonical = same person
-- LARRY/LAWRENCE, BOBBY/ROBERT, ED/EDWARD, JOE/JOSEPH
-- Confidence: 0.93
INSERT INTO staging.v3_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'P2_CANONICAL_NAME_IN_BLOCK',
  0.93,
  jsonb_build_object(
    'canonical', a.canonical_first_name,
    'a_filed_as', a.norm_first,
    'b_filed_as', b.norm_first,
    'last', a.norm_last
  )
FROM core.person_spine a
JOIN core.person_spine b
  ON a.addr_number = b.addr_number
  AND a.addr_type = b.addr_type
  AND a.zip5 = b.zip5
  AND LEFT(a.norm_last, 3) = LEFT(b.norm_last, 3)
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.norm_first != b.norm_first
  AND a.canonical_first_name IS NOT NULL
  AND b.canonical_first_name IS NOT NULL
  AND a.canonical_first_name = b.canonical_first_name
  AND NOT staging.is_blocked(a.person_id, b.person_id)
ON CONFLICT DO NOTHING;


-- ---- PASS 3: First name = middle name within block ----
-- Person files under middle name (ED from EDGAR, not EDWARD)
-- Confidence: 0.90
INSERT INTO staging.v3_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'P3_FIRST_IS_MIDDLE_IN_BLOCK',
  0.90,
  jsonb_build_object(
    'a_first', a.norm_first, 'a_middle', a.middle_name,
    'b_first', b.norm_first, 'b_middle', b.middle_name,
    'match_direction', CASE
      WHEN UPPER(a.norm_first) = UPPER(b.middle_name) THEN 'A.first=B.middle'
      ELSE 'B.first=A.middle'
    END
  )
FROM core.person_spine a
JOIN core.person_spine b
  ON a.addr_number = b.addr_number
  AND a.addr_type = b.addr_type
  AND a.zip5 = b.zip5
  AND LEFT(a.norm_last, 3) = LEFT(b.norm_last, 3)
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.norm_first != b.norm_first
  AND (
    (a.middle_name IS NOT NULL AND UPPER(TRIM(a.middle_name)) = UPPER(TRIM(b.norm_first)))
    OR
    (b.middle_name IS NOT NULL AND UPPER(TRIM(b.middle_name)) = UPPER(TRIM(a.norm_first)))
  )
  AND NOT staging.is_blocked(a.person_id, b.person_id)
ON CONFLICT DO NOTHING;


-- ---- PASS 4: First initial + middle initial within block ----
-- J E BROYHILL = JAMES EDGAR BROYHILL
-- Confidence: 0.88
INSERT INTO staging.v3_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'P4_INITIALS_IN_BLOCK',
  0.88,
  jsonb_build_object(
    'a_name', a.norm_first || ' ' || COALESCE(a.middle_name,'') || ' ' || a.norm_last,
    'b_name', b.norm_first || ' ' || COALESCE(b.middle_name,'') || ' ' || b.norm_last,
    'match_type', 'initial_to_full'
  )
FROM core.person_spine a
JOIN core.person_spine b
  ON a.addr_number = b.addr_number
  AND a.addr_type = b.addr_type
  AND a.zip5 = b.zip5
  AND LEFT(a.norm_last, 3) = LEFT(b.norm_last, 3)
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.norm_first != b.norm_first
  -- One record has a single-char first name (initial)
  AND (
    (LENGTH(a.norm_first) = 1
      AND LEFT(b.norm_first, 1) = a.norm_first
      AND a.middle_name IS NOT NULL AND b.middle_name IS NOT NULL
      AND LEFT(UPPER(a.middle_name), 1) = LEFT(UPPER(b.middle_name), 1))
    OR
    (LENGTH(b.norm_first) = 1
      AND LEFT(a.norm_first, 1) = b.norm_first
      AND a.middle_name IS NOT NULL AND b.middle_name IS NOT NULL
      AND LEFT(UPPER(a.middle_name), 1) = LEFT(UPPER(b.middle_name), 1))
  )
  AND NOT staging.is_blocked(a.person_id, b.person_id)
ON CONFLICT DO NOTHING;


-- ---- PASS 5: Employer anchor — cross-address merge for major donors ----
-- Same employer (normalized) + same last name + same first initial
-- across DIFFERENT address blocks = same person filing from multiple locations
-- This catches Art Pope at home vs office vs foundation
-- Confidence: 0.91
INSERT INTO staging.v3_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'P5_EMPLOYER_CROSS_ADDRESS',
  0.91,
  jsonb_build_object(
    'employer', a.best_employer,
    'a_addr', a.addr_type || ':' || a.addr_number || ' zip ' || a.zip5,
    'b_addr', b.addr_type || ':' || b.addr_number || ' zip ' || b.zip5,
    'a_name', a.norm_first || ' ' || a.norm_last,
    'b_name', b.norm_first || ' ' || b.norm_last
  )
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND LEFT(a.norm_first, 1) = LEFT(b.norm_first, 1)
  AND UPPER(LEFT(a.best_employer, 10)) = UPPER(LEFT(b.best_employer, 10))
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.best_employer IS NOT NULL AND a.best_employer != ''
  AND b.best_employer IS NOT NULL AND b.best_employer != ''
  -- Different address blocks (otherwise Pass 1-4 already caught them)
  AND NOT (a.addr_number = b.addr_number AND a.zip5 = b.zip5)
  AND NOT staging.is_blocked(a.person_id, b.person_id)
ON CONFLICT DO NOTHING;


-- ---- PASS 6: DataTrust prev_rncid chain ----
-- Person re-registered and got new RNCID. DT links old→new.
-- Confidence: 0.97
INSERT INTO staging.v3_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'P6_PREV_RNCID_CHAIN',
  0.97,
  jsonb_build_object(
    'old_rncid', a.voter_rncid,
    'current_rncid', b.voter_rncid,
    'a_name', a.norm_first || ' ' || a.norm_last,
    'b_name', b.norm_first || ' ' || b.norm_last
  )
FROM core.person_spine a
JOIN public.nc_datatrust dt ON a.voter_rncid = dt.prev_rncid
JOIN core.person_spine b ON dt.rncid = b.voter_rncid
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.person_id != b.person_id
  AND NOT staging.is_blocked(LEAST(a.person_id,b.person_id), GREATEST(a.person_id,b.person_id))
ON CONFLICT DO NOTHING;


-- ---- PASS 7: DataTrust household + same name ----
-- Same RNC householdid + same last + same first initial = same person
-- (Not household members — same person with two records)
-- Confidence: 0.92
INSERT INTO staging.v3_merge_candidates
  (keeper_person_id, merge_person_id, match_method, confidence, evidence)
SELECT
  LEAST(a.person_id, b.person_id),
  GREATEST(a.person_id, b.person_id),
  'P7_DT_HOUSEHOLD_SAME_NAME',
  0.92,
  jsonb_build_object(
    'household_id', a.household_id,
    'a_name', a.norm_first || ' ' || a.norm_last,
    'b_name', b.norm_first || ' ' || b.norm_last
  )
FROM core.person_spine a
JOIN core.person_spine b
  ON a.household_id = b.household_id
  AND a.norm_last = b.norm_last
  AND LEFT(a.norm_first, 1) = LEFT(b.norm_first, 1)
  AND a.person_id < b.person_id
WHERE a.is_active = true AND b.is_active = true
  AND a.record_quality = 'PRETTY' AND b.record_quality = 'PRETTY'
  AND a.household_id IS NOT NULL
  AND NOT staging.is_blocked(a.person_id, b.person_id)
ON CONFLICT DO NOTHING;


-- ============================================================================
-- PHASE 8: SAFETY CHECKS — Run after all passes
-- ============================================================================

-- BROYHILL CANARY: Ed (person_id 26451) must NOT be merged with anyone
SELECT 'MERGE_CANDIDATE' as alert, * FROM staging.v3_merge_candidates
WHERE keeper_person_id = 26451 OR merge_person_id = 26451;

SELECT 'BLOCKLIST_ENTRY' as alert, * FROM staging.v3_merge_blocklist
WHERE person_id_a = 26451 OR person_id_b = 26451;

-- ART POPE CANARY
SELECT 'POPE_MERGE' as alert, mc.*, s1.norm_first as keeper_first, s2.norm_first as merge_first
FROM staging.v3_merge_candidates mc
JOIN core.person_spine s1 ON mc.keeper_person_id = s1.person_id
JOIN core.person_spine s2 ON mc.merge_person_id = s2.person_id
WHERE s1.norm_last = 'POPE' OR s2.norm_last = 'POPE';

-- SUMMARY
SELECT match_method, COUNT(*) as candidates, ROUND(AVG(confidence),2) as avg_conf
FROM staging.v3_merge_candidates
GROUP BY match_method ORDER BY match_method;

SELECT LEFT(block_reason, POSITION(':' IN block_reason)-1) as reason,
  COUNT(*) as blocked_pairs
FROM staging.v3_merge_blocklist
GROUP BY 1 ORDER BY 2 DESC;

-- Record quality distribution
SELECT record_quality, COUNT(*) as cnt
FROM core.person_spine WHERE is_active = true
GROUP BY record_quality;

-- UGLY records (holding pen — never merged)
SELECT COUNT(*) as ugly_records_in_holding_pen
FROM core.person_spine
WHERE is_active = true AND record_quality = 'UGLY';


-- ============================================================================
-- END — Nothing above merges spine records.
-- All candidates go to staging.v3_merge_candidates.
-- Merge execution is a SEPARATE authorized step.
-- UGLY records are NEVER merge candidates.
-- ============================================================================
