-- ============================================================================
-- MIGRATION 079: Pass 2 Identity Resolution
-- Match FEC donations to person_spine using: last_name + address_number + zip5
-- 
-- Context:
--   Migrations 075-078 established the person_spine, fec_donation_person_map,
--   golden_record_person_map, contribution_map, and giving_frequency.
--   Pass 1 (exact name match) linked 479,291 FEC donations (45.7%).
--   ~569K FEC donations remain unlinked.
--
-- Strategy:
--   Extract address number (street number, PO Box, suite) + zip5 as household ID.
--   Combined with last name = high-confidence match without first name.
--   Handles ED/EDWARD, ART/ARTHUR, RODDEY/RODDY/RODDNEY, etc.
--   Ambiguity guard: only match where exactly ONE spine record per key.
-- ============================================================================

BEGIN;

-- Step 1: Create temp table of unlinked FEC donations with parsed address keys
-- Extract: leading street number OR PO Box/Suite/Apt number
CREATE TEMP TABLE tmp_pass2_candidates AS
SELECT
  fd.id as fec_donation_id,
  UPPER(TRIM(SPLIT_PART(fd.contributor_name, ',', 1))) as fec_last_name,
  COALESCE(
    NULLIF(REGEXP_REPLACE(fd.contributor_street_1, '[^0-9].*', ''), ''),
    (REGEXP_MATCH(UPPER(fd.contributor_street_1), '(?:BOX|SUITE|STE|APT|UNIT|#)\s*(\d+)'))[1]
  ) as fec_addr_num,
  LEFT(fd.contributor_zip, 5) as fec_zip5,
  fd.contributor_name,
  fd.contribution_amount,
  fd.contribution_date,
  fd.committee_id
FROM public.fec_donations fd
WHERE fd.person_id IS NULL
  AND fd.contributor_street_1 IS NOT NULL
  AND fd.contributor_zip IS NOT NULL
  AND LEFT(fd.contributor_zip, 5) ~ '^[0-9]{5}$';

-- Remove rows where no address number could be extracted
DELETE FROM tmp_pass2_candidates WHERE fec_addr_num IS NULL OR fec_addr_num = '';

-- Step 2: Create temp table of spine records with parsed address keys
CREATE TEMP TABLE tmp_spine_addr AS
SELECT
  ps.person_id,
  UPPER(TRIM(ps.last_name)) as spine_last_name,
  COALESCE(
    NULLIF(REGEXP_REPLACE(ps.street, '[^0-9].*', ''), ''),
    (REGEXP_MATCH(UPPER(ps.street), '(?:BOX|SUITE|STE|APT|UNIT|#)\s*(\d+)'))[1]
  ) as spine_addr_num,
  ps.zip5 as spine_zip5
FROM core.person_spine ps
WHERE ps.is_active
  AND ps.street IS NOT NULL
  AND ps.zip5 IS NOT NULL;

-- Remove rows where no address number could be extracted
DELETE FROM tmp_spine_addr WHERE spine_addr_num IS NULL OR spine_addr_num = '';

-- Add indexes for join performance
CREATE INDEX idx_tmp_pass2_key ON tmp_pass2_candidates (fec_last_name, fec_addr_num, fec_zip5);
CREATE INDEX idx_tmp_spine_key ON tmp_spine_addr (spine_last_name, spine_addr_num, spine_zip5);

-- Step 3: Build match table — only keep matches where exactly ONE spine
-- record matches (no ambiguity from multiple people at same address with same last name)
-- First, identify unambiguous address keys (one person per key)
CREATE TEMP TABLE tmp_unambiguous_keys AS
SELECT spine_last_name, spine_addr_num, spine_zip5, MIN(person_id) as person_id
FROM tmp_spine_addr
GROUP BY spine_last_name, spine_addr_num, spine_zip5
HAVING COUNT(DISTINCT person_id) = 1;

CREATE INDEX idx_tmp_ukey ON tmp_unambiguous_keys (spine_last_name, spine_addr_num, spine_zip5);

CREATE TEMP TABLE tmp_pass2_matches AS
SELECT
  c.fec_donation_id,
  uk.person_id,
  c.contribution_amount,
  c.contribution_date,
  c.committee_id
FROM tmp_pass2_candidates c
JOIN tmp_unambiguous_keys uk
  ON c.fec_last_name = uk.spine_last_name
  AND c.fec_addr_num = uk.spine_addr_num
  AND c.fec_zip5 = uk.spine_zip5;

-- Step 4: Report match counts before applying
DO $$
DECLARE
  v_match_count BIGINT;
  v_person_count BIGINT;
BEGIN
  SELECT COUNT(*), COUNT(DISTINCT person_id)
  INTO v_match_count, v_person_count
  FROM tmp_pass2_matches;
  RAISE NOTICE '%', format('Pass 2 matches: %s donations -> %s distinct persons', v_match_count, v_person_count);
END $$;

-- Step 5: Update fec_donations with person_id
UPDATE public.fec_donations fd
SET person_id = m.person_id
FROM tmp_pass2_matches m
WHERE fd.id = m.fec_donation_id;

-- Step 6: Insert into fec_donation_person_map
-- NOTE: Must drop/alter CHECK constraint first since 'pass2_addr' not in original list
ALTER TABLE core.fec_donation_person_map DROP CONSTRAINT IF EXISTS chk_match_method;
ALTER TABLE core.fec_donation_person_map ADD CONSTRAINT chk_match_method
  CHECK (match_method IN ('pass1_exact', 'pass2_nickname', 'pass3_address', 'pass4_employer', 'pass2_addr'));

INSERT INTO core.fec_donation_person_map (fec_donation_id, person_id, match_method, match_confidence, created_at)
SELECT
  m.fec_donation_id,
  m.person_id,
  'pass2_addr',
  0.85,
  NOW()
FROM tmp_pass2_matches m
ON CONFLICT (fec_donation_id) DO NOTHING;


-- Step 7: Insert into contribution_map
INSERT INTO core.contribution_map (person_id, source_system, source_id, amount, transaction_date, committee_id, created_at)
SELECT
  m.person_id,
  'fec_pass2',
  m.fec_donation_id,
  COALESCE(m.contribution_amount, 0),
  m.contribution_date::date,
  m.committee_id,
  NOW()
FROM tmp_pass2_matches m
ON CONFLICT (source_system, source_id) DO NOTHING;

-- Step 8: Recalculate giving_frequency and totals for affected persons
WITH donor_stats AS (
  SELECT
    person_id,
    COUNT(*) as contribution_count,
    SUM(amount) as total_contributed,
    MIN(transaction_date) as first_contribution,
    MAX(transaction_date) as last_contribution,
    MAX(amount) as max_single_gift,
    ROUND(AVG(amount), 2) as avg_gift,
    CASE
      WHEN COUNT(*) >= 20 THEN 'frequent'
      WHEN COUNT(*) >= 5  THEN 'regular'
      WHEN COUNT(*) >= 2  THEN 'occasional'
      ELSE 'one_time'
    END as giving_frequency
  FROM core.contribution_map
  WHERE person_id IN (SELECT DISTINCT person_id FROM tmp_pass2_matches)
  GROUP BY person_id
)
UPDATE core.person_spine ps
SET
  total_contributed = ds.total_contributed,
  contribution_count = ds.contribution_count,
  first_contribution = ds.first_contribution,
  last_contribution = ds.last_contribution,
  max_single_gift = ds.max_single_gift,
  avg_gift = ds.avg_gift,
  giving_frequency = ds.giving_frequency,
  updated_at = NOW()
FROM donor_stats ds
WHERE ps.person_id = ds.person_id
  AND ps.is_active;

-- Step 9: Final verification
DO $$
DECLARE
  v_total_fec BIGINT;
  v_linked_fec BIGINT;
  v_pass2_count BIGINT;
  v_cmap_total BIGINT;
  v_freq_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_total_fec FROM public.fec_donations;
  SELECT COUNT(*) INTO v_linked_fec FROM public.fec_donations WHERE person_id IS NOT NULL;
  SELECT COUNT(*) INTO v_pass2_count FROM core.fec_donation_person_map WHERE match_method = 'pass2_addr';
  SELECT COUNT(*) INTO v_cmap_total FROM core.contribution_map;
  SELECT COUNT(*) INTO v_freq_count FROM core.person_spine WHERE giving_frequency IS NOT NULL AND is_active;

  RAISE NOTICE '=== MIGRATION 079 COMPLETE ===';
  RAISE NOTICE 'FEC total: %  |  Linked: %  (%.1f%%)', v_total_fec, v_linked_fec, (v_linked_fec::numeric / v_total_fec * 100);
  RAISE NOTICE 'Pass 2 addr matches: %', v_pass2_count;
  RAISE NOTICE 'Contribution map total: %', v_cmap_total;
  RAISE NOTICE 'Spine records with giving_frequency: %', v_freq_count;
END $$;

-- Cleanup temp tables
DROP TABLE IF EXISTS tmp_pass2_candidates;
DROP TABLE IF EXISTS tmp_spine_addr;
DROP TABLE IF EXISTS tmp_unambiguous_keys;
DROP TABLE IF EXISTS tmp_pass2_matches;

COMMIT;

-- ============================================================================
-- ROLLBACK PLAN (if needed):
--   BEGIN;
--   DELETE FROM core.contribution_map WHERE source_system = 'fec_pass2';
--   DELETE FROM core.fec_donation_person_map WHERE match_method = 'pass2_addr';
--   UPDATE public.fec_donations fd SET person_id = NULL
--     WHERE fd.id IN (SELECT fec_donation_id FROM core.fec_donation_person_map WHERE match_method = 'pass2_addr');
--   -- Rerun 078 to recalculate aggregates
--   COMMIT;
-- ============================================================================
-- EXPECTED RESULTS:
--   Pass 2 should link 30K-80K additional FEC donations
--   Combined with Pass 1 (479K), total linked should be 510K-560K (48-53%)
--   Key test cases:
--     - Eddie Broyhill: ED/EDWARD variants → same spine person
--     - Art Pope: JAMES/ARTHUR variants → same spine person
--     - Roddey Dowd: RODDEY/RODDY/RODDNEY → same spine person
-- ============================================================================
