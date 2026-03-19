-- ============================================================================
-- MIGRATION 080: Five-Pass Spine Deduplication (v2 — spouse-safe)
-- Populates staging.spine_merge_candidates, staging.spine_clusters,
-- core.identity_clusters, then remaps contributions to canonical IDs.
--
-- CONFIRMED SCHEMAS (Task 1 discovery 2026-03-17):
--   staging.spine_merge_candidates: keep_id(int), merge_id(int), match_method(text), confidence(numeric)
--   staging.spine_clusters: person_id(int), cluster_root(int), is_canonical(bool), cluster_size(int)
--   core.identity_clusters: id(bigint), person_id(bigint), source_system(text), source_id(bigint),
--                           cluster_method(text), confidence(numeric), created_at(timestamptz)
--   core.person_spine: person_id(bigint), norm_last, norm_first, nickname_canonical, street, zip5,
--                      email, employer, occupation, voter_ncid, is_active
--   core.contribution_map: person_id(bigint) — remap target
--   core.fec_donation_person_map: person_id(bigint) — remap target
--
-- Idempotent: all INSERTs use ON CONFLICT DO NOTHING or WHERE NOT EXISTS.
-- Safe to re-run. Never drops or recreates tables.
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 0: SUPPORT — Add unique constraint for idempotent inserts
-- ============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_smc_pair
  ON staging.spine_merge_candidates (LEAST(keep_id, merge_id), GREATEST(keep_id, merge_id));

CREATE INDEX IF NOT EXISTS idx_smc_keep ON staging.spine_merge_candidates (keep_id);
CREATE INDEX IF NOT EXISTS idx_smc_merge ON staging.spine_merge_candidates (merge_id);

-- Add name variants needed for accurate dedup (critical for Passes 1 & 4)
INSERT INTO public.name_variants (nickname, canonical, gender, confidence) VALUES
  ('RODDEY', 'RODDEY', 'M', 1.00),
  ('RODDY', 'RODDEY', 'M', 0.90),
  ('RODDNEY', 'RODDEY', 'M', 0.90),
  ('ARTHUR', 'ARTHUR', 'M', 1.00),
  ('ART', 'ARTHUR', 'M', 0.90),
  ('JAMES', 'JAMES', 'M', 1.00),
  ('EDWARD', 'EDWARD', 'M', 1.00),
  ('KATHERINE', 'KATHERINE', 'F', 1.00),
  ('KATHY', 'KATHERINE', 'F', 0.90),
  ('KATH', 'KATHERINE', 'F', 0.90),
  ('KATE', 'KATHERINE', 'F', 0.90),
  ('WILLIS', 'WILLIS', 'M', 1.00)
ON CONFLICT (nickname) DO NOTHING;


-- ============================================================================
-- PASS 1: Canonical name + zip5 (confidence 1.00)
-- Uses name_variants to resolve EDGAR→EDWARD, ART→ARTHUR, RODDY→RODDEY, etc.
-- Then matches: canonical_first + norm_last + zip5
-- ============================================================================
INSERT INTO staging.spine_merge_candidates (keep_id, merge_id, match_method, confidence)
SELECT
  LEAST(a.person_id, b.person_id)::int,
  GREATEST(a.person_id, b.person_id)::int,
  'PASS_1_CANONICAL_NAME_ZIP',
  1.00
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.zip5 = b.zip5
  AND a.person_id < b.person_id
  AND a.is_active AND b.is_active
LEFT JOIN public.name_variants nva ON nva.nickname = a.norm_first
LEFT JOIN public.name_variants nvb ON nvb.nickname = b.norm_first
WHERE COALESCE(nva.canonical, a.norm_first) = COALESCE(nvb.canonical, b.norm_first)
  AND a.norm_last IS NOT NULL
  AND a.zip5 IS NOT NULL
ON CONFLICT (LEAST(keep_id, merge_id), GREATEST(keep_id, merge_id)) DO NOTHING;


-- ============================================================================
-- PASS 2: NCID voter file match (confidence 0.99)
-- Same voter_ncid = same person, regardless of name/address differences
-- ============================================================================
INSERT INTO staging.spine_merge_candidates (keep_id, merge_id, match_method, confidence)
SELECT
  LEAST(a.person_id, b.person_id)::int,
  GREATEST(a.person_id, b.person_id)::int,
  'PASS_2_NCID_VOTER',
  0.99
FROM core.person_spine a
JOIN core.person_spine b
  ON a.voter_ncid = b.voter_ncid
  AND a.person_id < b.person_id
  AND a.is_active AND b.is_active
WHERE a.voter_ncid IS NOT NULL
  AND a.voter_ncid != ''
ON CONFLICT (LEAST(keep_id, merge_id), GREATEST(keep_id, merge_id)) DO NOTHING;


-- ============================================================================
-- PASS 3: Email match (confidence 0.95)
-- Same email address = same person
-- ============================================================================
INSERT INTO staging.spine_merge_candidates (keep_id, merge_id, match_method, confidence)
SELECT
  LEAST(a.person_id, b.person_id)::int,
  GREATEST(a.person_id, b.person_id)::int,
  'PASS_3_EMAIL',
  0.95
FROM core.person_spine a
JOIN core.person_spine b
  ON LOWER(TRIM(a.email)) = LOWER(TRIM(b.email))
  AND a.person_id < b.person_id
  AND a.is_active AND b.is_active
WHERE a.email IS NOT NULL
  AND TRIM(a.email) != ''
ON CONFLICT (LEAST(keep_id, merge_id), GREATEST(keep_id, merge_id)) DO NOTHING;


-- ============================================================================
-- PASS 4: ADDRESS ANCHOR — THE CRITICAL PASS (75% orphan hit rate in prior run)
-- Match key: street_number || '|' || zip5 || '|' || LEFT(norm_last, 3)
-- Street number extraction:
--   1. Strip APT/UNIT/SUITE/STE/# and everything after
--   2. Then extract leading digits from what remains
--   3. Also extract PO BOX / P.O. BOX number
-- Examples:
--   "525 N HAWTHORNE RD"     → 525
--   "525 NORTH HAWTHORNE"    → 525  (same person, typo irrelevant)
--   "PO BOX 35430"           → 35430
--   "P.O. BOX 35430"         → 35430
--   "APT 202, 6111 SUNPOINT" → 6111 (strip APT 202 first)
-- Confidence: 0.90
-- ============================================================================

-- Build temp table with extracted street numbers for performance
CREATE TEMP TABLE tmp_spine_street_nums AS
SELECT
  person_id,
  norm_last,
  norm_first,
  zip5,
  COALESCE(
    -- Try 1: Strip APT/UNIT/SUITE/STE/# prefix, then get leading digits
    NULLIF(
      REGEXP_REPLACE(
        REGEXP_REPLACE(UPPER(street), '^\s*(APT|UNIT|SUITE|STE|#)\s*\S+[\s,]+', ''),
        '[^0-9].*', ''
      ), ''
    ),
    -- Try 2: PO BOX / P.O. BOX number
    (REGEXP_MATCH(UPPER(street), '(?:P\.?\s*O\.?\s*BOX|POST\s+OFFICE\s+BOX)\s+(\d+)'))[1],
    -- Try 3: Leading digits from raw street (fallback)
    NULLIF(REGEXP_REPLACE(UPPER(street), '[^0-9].*', ''), '')
  ) AS street_number
FROM core.person_spine
WHERE is_active
  AND street IS NOT NULL
  AND zip5 IS NOT NULL
  AND norm_last IS NOT NULL;

-- Remove rows where no number could be extracted
DELETE FROM tmp_spine_street_nums WHERE street_number IS NULL OR street_number = '';

-- Index for the join
CREATE INDEX idx_tmp_ssn_key ON tmp_spine_street_nums (street_number, zip5, LEFT(norm_last, 3));

-- Insert address anchor matches — ONLY when canonical first names agree
-- This prevents merging spouses (e.g., Art Pope ≠ Katherine Pope)
INSERT INTO staging.spine_merge_candidates (keep_id, merge_id, match_method, confidence)
SELECT
  LEAST(a.person_id, b.person_id)::int,
  GREATEST(a.person_id, b.person_id)::int,
  'PASS_4_ADDR_ANCHOR',
  0.90
FROM tmp_spine_street_nums a
JOIN tmp_spine_street_nums b
  ON a.street_number = b.street_number
  AND a.zip5 = b.zip5
  AND LEFT(a.norm_last, 3) = LEFT(b.norm_last, 3)
  AND a.person_id < b.person_id
-- Join to name_variants for canonical first name resolution
LEFT JOIN public.name_variants nva ON nva.nickname = a.norm_first
LEFT JOIN public.name_variants nvb ON nvb.nickname = b.norm_first
WHERE COALESCE(nva.canonical, a.norm_first) = COALESCE(nvb.canonical, b.norm_first)
ON CONFLICT (LEAST(keep_id, merge_id), GREATEST(keep_id, merge_id)) DO NOTHING;


-- ============================================================================
-- PASS 4b: HOUSEHOLD LINKING — Same address, different person = same household
-- Populates household_id on core.person_spine for records that share an address
-- but have DIFFERENT canonical first names (i.e., spouses/family members).
-- Uses MIN(person_id) at each address as the household anchor.
-- ============================================================================

-- First, assign household_id to ALL records at multi-person addresses
-- household_id = MIN(person_id) among active records at that address
UPDATE core.person_spine ps
SET household_id = hh.hh_id,
    updated_at = NOW()
FROM (
  SELECT
    t.street_number,
    t.zip5,
    LEFT(t.norm_last, 3) AS last_prefix,
    MIN(t.person_id) AS hh_id
  FROM tmp_spine_street_nums t
  GROUP BY t.street_number, t.zip5, LEFT(t.norm_last, 3)
  HAVING COUNT(DISTINCT t.person_id) > 1
) hh
JOIN tmp_spine_street_nums t2
  ON t2.street_number = hh.street_number
  AND t2.zip5 = hh.zip5
  AND LEFT(t2.norm_last, 3) = hh.last_prefix
WHERE ps.person_id = t2.person_id
  AND ps.is_active = true;

DROP TABLE tmp_spine_street_nums;


-- ============================================================================
-- PASS 5: Cross-zip name + employer (movers) (confidence 0.85)
-- Same canonical first + last + employer prefix = same person who moved
-- Only fires when employer or occupation is NOT NULL
-- ============================================================================
INSERT INTO staging.spine_merge_candidates (keep_id, merge_id, match_method, confidence)
SELECT
  LEAST(a.person_id, b.person_id)::int,
  GREATEST(a.person_id, b.person_id)::int,
  'PASS_5_CROSS_ZIP_EMPLOYER',
  0.85
FROM core.person_spine a
JOIN core.person_spine b
  ON a.norm_last = b.norm_last
  AND a.person_id < b.person_id
  AND a.is_active AND b.is_active
LEFT JOIN public.name_variants nva ON nva.nickname = a.norm_first
LEFT JOIN public.name_variants nvb ON nvb.nickname = b.norm_first
WHERE COALESCE(nva.canonical, a.norm_first) = COALESCE(nvb.canonical, b.norm_first)
  AND a.norm_last IS NOT NULL
  AND COALESCE(a.employer, a.occupation) IS NOT NULL
  AND (
    UPPER(LEFT(COALESCE(a.employer,''), 8)) = UPPER(LEFT(COALESCE(b.employer,''), 8))
    OR UPPER(LEFT(COALESCE(a.occupation,''), 8)) = UPPER(LEFT(COALESCE(b.occupation,''), 8))
  )
  -- Exclude same-zip pairs (already caught by Pass 1)
  AND COALESCE(a.zip5, '') != COALESCE(b.zip5, '')
ON CONFLICT (LEAST(keep_id, merge_id), GREATEST(keep_id, merge_id)) DO NOTHING;


-- ============================================================================
-- PASS REPORT: How many merge candidates did each pass find?
-- ============================================================================
DO $$
DECLARE
  v_p1 BIGINT; v_p2 BIGINT; v_p3 BIGINT; v_p4 BIGINT; v_p5 BIGINT; v_total BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_p1 FROM staging.spine_merge_candidates WHERE match_method = 'PASS_1_CANONICAL_NAME_ZIP';
  SELECT COUNT(*) INTO v_p2 FROM staging.spine_merge_candidates WHERE match_method = 'PASS_2_NCID_VOTER';
  SELECT COUNT(*) INTO v_p3 FROM staging.spine_merge_candidates WHERE match_method = 'PASS_3_EMAIL';
  SELECT COUNT(*) INTO v_p4 FROM staging.spine_merge_candidates WHERE match_method = 'PASS_4_ADDR_ANCHOR';
  SELECT COUNT(*) INTO v_p5 FROM staging.spine_merge_candidates WHERE match_method = 'PASS_5_CROSS_ZIP_EMPLOYER';
  SELECT COUNT(*) INTO v_total FROM staging.spine_merge_candidates;
  RAISE NOTICE '=== MERGE CANDIDATES BY PASS ===';
  RAISE NOTICE 'Pass 1 (canonical name+zip): %', v_p1;
  RAISE NOTICE 'Pass 2 (NCID voter):         %', v_p2;
  RAISE NOTICE 'Pass 3 (email):              %', v_p3;
  RAISE NOTICE 'Pass 4 (address anchor):     %', v_p4;
  RAISE NOTICE 'Pass 5 (cross-zip employer): %', v_p5;
  RAISE NOTICE 'TOTAL merge candidates:      %', v_total;
END $$;


-- ============================================================================
-- PART 3: CLUSTER RESOLUTION — Transitive closure via Union-Find
-- If A→B and B→C, collapse all to MIN(person_id)
-- Populates staging.spine_clusters
-- ============================================================================

-- Step 3A: Seed spine_clusters with all active spine records
INSERT INTO staging.spine_clusters (person_id, cluster_root, is_canonical, cluster_size)
SELECT person_id::int, person_id::int, true, 1
FROM core.person_spine
WHERE is_active
ON CONFLICT DO NOTHING;

-- Index for fast lookups during resolution
CREATE INDEX IF NOT EXISTS idx_sc_person ON staging.spine_clusters (person_id);
CREATE INDEX IF NOT EXISTS idx_sc_root ON staging.spine_clusters (cluster_root);


-- Step 3B: Transitive closure loop — collapse chains to MIN(person_id)
-- For each merge pair (keep_id, merge_id), propagate the lower cluster_root
-- to ALL records sharing either cluster_root. Repeat until stable.
DO $$
DECLARE
  v_rows_updated INT;
  v_iteration INT := 0;
BEGIN
  LOOP
    v_iteration := v_iteration + 1;

    -- Find all merge pairs where the two sides have different cluster_roots
    -- and update the higher cluster_root to the lower one
    WITH mismatched AS (
      SELECT DISTINCT
        LEAST(sc_a.cluster_root, sc_b.cluster_root) AS winner,
        GREATEST(sc_a.cluster_root, sc_b.cluster_root) AS loser
      FROM staging.spine_merge_candidates m
      JOIN staging.spine_clusters sc_a ON sc_a.person_id = m.keep_id
      JOIN staging.spine_clusters sc_b ON sc_b.person_id = m.merge_id
      WHERE sc_a.cluster_root != sc_b.cluster_root
    )
    UPDATE staging.spine_clusters sc
    SET cluster_root = mm.winner
    FROM mismatched mm
    WHERE sc.cluster_root = mm.loser;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    RAISE NOTICE 'Iteration %: % rows updated', v_iteration, v_rows_updated;
    EXIT WHEN v_rows_updated = 0;
    EXIT WHEN v_iteration > 50;  -- safety valve
  END LOOP;
  RAISE NOTICE 'Transitive closure complete after % iterations', v_iteration;
END $$;


-- Step 3C: Set is_canonical = true only for the cluster_root record
UPDATE staging.spine_clusters
SET is_canonical = (person_id = cluster_root);

-- Step 3D: Compute cluster_size
UPDATE staging.spine_clusters sc
SET cluster_size = sizes.cnt
FROM (
  SELECT cluster_root, COUNT(*) AS cnt
  FROM staging.spine_clusters
  GROUP BY cluster_root
) sizes
WHERE sc.cluster_root = sizes.cluster_root;

-- Report cluster stats
DO $$
DECLARE
  v_clusters BIGINT;
  v_collapsed BIGINT;
  v_max_size INT;
BEGIN
  SELECT COUNT(DISTINCT cluster_root) INTO v_clusters
  FROM staging.spine_clusters WHERE cluster_size > 1;
  SELECT COUNT(*) INTO v_collapsed
  FROM staging.spine_clusters WHERE is_canonical = false;
  SELECT MAX(cluster_size) INTO v_max_size FROM staging.spine_clusters;
  RAISE NOTICE '=== CLUSTER STATS ===';
  RAISE NOTICE 'Multi-record clusters: %', v_clusters;
  RAISE NOTICE 'Records to collapse:   %', v_collapsed;
  RAISE NOTICE 'Largest cluster:       % records', v_max_size;
END $$;


-- ============================================================================
-- PART 4: POPULATE core.identity_clusters from staging.spine_clusters
-- ============================================================================
INSERT INTO core.identity_clusters (person_id, source_system, source_id, cluster_method, confidence, created_at)
SELECT
  sc.cluster_root::bigint,
  'spine_dedup',
  sc.person_id::bigint,
  COALESCE(
    (SELECT m.match_method FROM staging.spine_merge_candidates m
     WHERE (m.keep_id = sc.person_id OR m.merge_id = sc.person_id)
       AND (m.keep_id = sc.cluster_root OR m.merge_id = sc.cluster_root)
     LIMIT 1),
    'SEED'
  ),
  COALESCE(
    (SELECT m.confidence FROM staging.spine_merge_candidates m
     WHERE (m.keep_id = sc.person_id OR m.merge_id = sc.person_id)
       AND (m.keep_id = sc.cluster_root OR m.merge_id = sc.cluster_root)
     LIMIT 1),
    1.00
  ),
  NOW()
FROM staging.spine_clusters sc
WHERE sc.cluster_size > 1
ON CONFLICT DO NOTHING;


-- ============================================================================
-- PART 5: REMAP CONTRIBUTIONS — Point non-canonical spine IDs to canonical
-- ============================================================================

-- 5A: Remap core.contribution_map
UPDATE core.contribution_map cm
SET person_id = sc.cluster_root::bigint
FROM staging.spine_clusters sc
WHERE cm.person_id = sc.person_id::bigint
  AND sc.is_canonical = false
  AND cm.person_id != sc.cluster_root::bigint;

-- 5B: Remap core.fec_donation_person_map
UPDATE core.fec_donation_person_map fdpm
SET person_id = sc.cluster_root::bigint
FROM staging.spine_clusters sc
WHERE fdpm.person_id = sc.person_id::bigint
  AND sc.is_canonical = false
  AND fdpm.person_id != sc.cluster_root::bigint;

-- 5C: Remap public.fec_donations.person_id
UPDATE public.fec_donations fd
SET person_id = sc.cluster_root::bigint
FROM staging.spine_clusters sc
WHERE fd.person_id = sc.person_id::bigint
  AND sc.is_canonical = false
  AND fd.person_id != sc.cluster_root::bigint;


-- 5D: Mark non-canonical spine records inactive, point merged_into to canonical
UPDATE core.person_spine ps
SET is_active = false,
    merged_into = sc.cluster_root::bigint,
    deactivated_at = NOW(),
    updated_at = NOW()
FROM staging.spine_clusters sc
WHERE ps.person_id = sc.person_id::bigint
  AND sc.is_canonical = false
  AND ps.is_active = true;

-- 5E: Recalculate aggregates on canonical records that absorbed merges
WITH merged_totals AS (
  SELECT
    person_id,
    COUNT(*) AS contribution_count,
    SUM(amount) AS total_contributed,
    MIN(transaction_date) AS first_contribution,
    MAX(transaction_date) AS last_contribution,
    MAX(amount) AS max_single_gift,
    ROUND(AVG(amount), 2) AS avg_gift,
    CASE
      WHEN COUNT(*) >= 20 THEN 'frequent'
      WHEN COUNT(*) >= 5  THEN 'regular'
      WHEN COUNT(*) >= 2  THEN 'occasional'
      ELSE 'one_time'
    END AS giving_frequency
  FROM core.contribution_map
  WHERE person_id IN (
    SELECT DISTINCT cluster_root::bigint FROM staging.spine_clusters WHERE cluster_size > 1
  )
  GROUP BY person_id
)
UPDATE core.person_spine ps
SET
  total_contributed = mt.total_contributed,
  contribution_count = mt.contribution_count,
  first_contribution = mt.first_contribution,
  last_contribution = mt.last_contribution,
  max_single_gift = mt.max_single_gift,
  avg_gift = mt.avg_gift,
  giving_frequency = mt.giving_frequency,
  updated_at = NOW()
FROM merged_totals mt
WHERE ps.person_id = mt.person_id
  AND ps.is_active = true;


-- ============================================================================
-- PART 6: ACCEPTANCE TESTS
-- ============================================================================

-- 6A: Roddey Dowd — should be 1 active canonical spine record, SEPARATE from Willis Dowd
-- Expected: Roddey collapsed, Willis separate, BOTH sharing household_id
SELECT
  ps.person_id, ps.first_name, ps.last_name, ps.zip5, ps.street,
  ps.total_contributed, ps.contribution_count, ps.giving_frequency, ps.household_id,
  ps.is_active, ps.merged_into,
  (SELECT COUNT(*) FROM staging.spine_clusters
   WHERE cluster_root = ps.person_id::int AND cluster_size > 1) AS cluster_members
FROM core.person_spine ps
WHERE UPPER(ps.last_name) = 'DOWD'
  AND (UPPER(ps.first_name) LIKE 'RODD%' OR UPPER(ps.first_name) = 'WILLIS')
ORDER BY ps.is_active DESC, ps.first_name;

-- 6B: Ed Broyhill — should collapse EDGAR/EDWARD/JAMES/J variants at 525 Hawthorne
SELECT
  ps.person_id, ps.first_name, ps.last_name, ps.zip5, ps.street,
  ps.total_contributed, ps.contribution_count, ps.giving_frequency, ps.household_id,
  ps.is_active, ps.merged_into,
  (SELECT COUNT(*) FROM staging.spine_clusters
   WHERE cluster_root = ps.person_id::int AND cluster_size > 1) AS cluster_members
FROM core.person_spine ps
WHERE UPPER(ps.last_name) = 'BROYHILL'
  AND UPPER(ps.first_name) IN ('ED','EDGAR','EDWARD','JAMES','J')
ORDER BY ps.is_active DESC, ps.person_id;

-- 6C: Art Pope — JAMES/ARTHUR should merge, Katherine Pope should be SEPARATE
-- Both should share household_id
SELECT
  ps.person_id, ps.first_name, ps.last_name, ps.zip5, ps.street,
  ps.total_contributed, ps.contribution_count, ps.giving_frequency, ps.household_id,
  ps.is_active, ps.merged_into
FROM core.person_spine ps
WHERE UPPER(ps.last_name) = 'POPE'
  AND UPPER(ps.first_name) IN ('JAMES','ARTHUR','ART','KATHERINE','KATHY','KATH')
  AND ps.zip5 = '27609'
ORDER BY ps.is_active DESC, ps.first_name;

-- ============================================================================
-- PART 7: IMPACT REPORT
-- ============================================================================
SELECT 'spine_merge_candidates total' AS metric, COUNT(*) AS value FROM staging.spine_merge_candidates
UNION ALL SELECT 'Pass 1 (canonical name+zip)', COUNT(*) FROM staging.spine_merge_candidates WHERE match_method = 'PASS_1_CANONICAL_NAME_ZIP'
UNION ALL SELECT 'Pass 2 (NCID voter)', COUNT(*) FROM staging.spine_merge_candidates WHERE match_method = 'PASS_2_NCID_VOTER'
UNION ALL SELECT 'Pass 3 (email)', COUNT(*) FROM staging.spine_merge_candidates WHERE match_method = 'PASS_3_EMAIL'
UNION ALL SELECT 'Pass 4 (address anchor)', COUNT(*) FROM staging.spine_merge_candidates WHERE match_method = 'PASS_4_ADDR_ANCHOR'
UNION ALL SELECT 'Pass 5 (cross-zip employer)', COUNT(*) FROM staging.spine_merge_candidates WHERE match_method = 'PASS_5_CROSS_ZIP_EMPLOYER'
UNION ALL SELECT 'clusters created', COUNT(DISTINCT cluster_root) FROM staging.spine_clusters WHERE cluster_size > 1
UNION ALL SELECT 'spine records collapsed', COUNT(*) FROM staging.spine_clusters WHERE is_canonical = false
UNION ALL SELECT 'identity_clusters populated', COUNT(*) FROM core.identity_clusters
UNION ALL SELECT 'active spine records remaining', COUNT(*) FROM core.person_spine WHERE is_active
UNION ALL SELECT 'contribution_map total', COUNT(*) FROM core.contribution_map
UNION ALL SELECT 'FEC linked', COUNT(*) FROM public.fec_donations WHERE person_id IS NOT NULL
UNION ALL SELECT 'FEC unlinked', COUNT(*) FROM public.fec_donations WHERE person_id IS NULL;

COMMIT;


-- ============================================================================
-- ROLLBACK PLAN (if needed):
--   BEGIN;
--   -- Undo spine deactivations
--   UPDATE core.person_spine SET is_active = true, merged_into = NULL,
--     deactivated_at = NULL WHERE merged_into IS NOT NULL AND deactivated_at >= '2026-03-17';
--   -- Undo contribution_map remaps (requires original person_ids from spine_clusters)
--   UPDATE core.contribution_map cm SET person_id = sc.person_id::bigint
--     FROM staging.spine_clusters sc WHERE cm.person_id = sc.cluster_root::bigint
--     AND sc.is_canonical = false;
--   -- Clear staging tables
--   DELETE FROM staging.spine_clusters;
--   DELETE FROM staging.spine_merge_candidates;
--   DELETE FROM core.identity_clusters WHERE source_system = 'spine_dedup';
--   COMMIT;
-- ============================================================================
-- END OF MIGRATION 080
-- ============================================================================
