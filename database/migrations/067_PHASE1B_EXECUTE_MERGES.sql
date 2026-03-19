-- 067_PHASE1B_EXECUTE_MERGES.sql
-- Identity Resolution Phase 1b: Execute spine merges from clusters
-- PREREQUISITE: Run 066 and visually verify Art Pope cluster looks correct
-- CRITICAL: This is irreversible (marks records inactive). Verify clusters first!
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: Count before
-- =============================================================================
SELECT 'BEFORE merge' AS label, 
  count(*) AS total_spine,
  count(*) FILTER (WHERE is_active) AS active,
  count(*) FILTER (WHERE NOT is_active) AS inactive
FROM core.person_spine;

-- =============================================================================
-- STEP 2: For each cluster, merge non-canonical records into canonical
-- Aggregate: sum contributions, take best voter_ncid, collect merged_from[]
-- =============================================================================

-- 2a: Update canonical records with aggregated data from cluster members
WITH cluster_agg AS (
  SELECT 
    sc_canon.person_id AS canonical_id,
    SUM(sp.contribution_count) AS total_txns,
    SUM(sp.total_contributed) AS total_amt,
    MIN(sp.first_contribution) AS earliest,
    MAX(sp.last_contribution) AS latest,
    MAX(sp.max_single_gift) AS max_gift,
    -- Collect all non-canonical person_ids for merged_from
    ARRAY_AGG(sp.person_id) FILTER (WHERE NOT sc.is_canonical) AS merge_ids,
    -- Pick best voter_ncid: from the record with most contributions
    (ARRAY_AGG(sp.voter_ncid ORDER BY sp.contribution_count DESC NULLS LAST)
      FILTER (WHERE sp.voter_ncid IS NOT NULL))[1] AS best_ncid,
    (ARRAY_AGG(sp.voter_rncid ORDER BY sp.contribution_count DESC NULLS LAST)
      FILTER (WHERE sp.voter_rncid IS NOT NULL))[1] AS best_rncid,
    -- Collect all name variations
    ARRAY_AGG(DISTINCT sp.norm_first || ' ' || sp.norm_last) AS name_variations
  FROM staging.spine_clusters sc
  JOIN core.person_spine sp ON sc.person_id = sp.person_id
  JOIN staging.spine_clusters sc_canon 
    ON sc.cluster_root = sc_canon.cluster_root AND sc_canon.is_canonical = true
  WHERE sc.cluster_size > 1
  GROUP BY sc_canon.person_id
)
UPDATE core.person_spine s SET
  contribution_count = ca.total_txns,
  total_contributed = ca.total_amt,
  first_contribution = ca.earliest,
  last_contribution = ca.latest,
  max_single_gift = ca.max_gift,
  avg_gift = CASE WHEN ca.total_txns > 0 THEN ca.total_amt / ca.total_txns ELSE 0 END,
  voter_ncid = COALESCE(s.voter_ncid, ca.best_ncid),
  voter_rncid = COALESCE(s.voter_rncid, ca.best_rncid),
  merged_from = ca.merge_ids,
  updated_at = NOW(),
  version = COALESCE(s.version, 0) + 1
FROM cluster_agg ca
WHERE s.person_id = ca.canonical_id;

-- 2b: Mark non-canonical records as inactive
UPDATE core.person_spine s SET
  is_active = false,
  updated_at = NOW()
FROM staging.spine_clusters sc
WHERE s.person_id = sc.person_id
  AND sc.is_canonical = false
  AND sc.cluster_size > 1;

-- =============================================================================
-- STEP 3: Remap donor_contribution_map to point to canonical records
-- =============================================================================
UPDATE donor_contribution_map dcm SET
  golden_record_id = sc_canon.person_id
FROM staging.spine_clusters sc
JOIN staging.spine_clusters sc_canon 
  ON sc.cluster_root = sc_canon.cluster_root AND sc_canon.is_canonical = true
WHERE dcm.golden_record_id = sc.person_id
  AND sc.is_canonical = false
  AND sc.cluster_size > 1;

-- =============================================================================
-- STEP 4: Count after
-- =============================================================================
SELECT 'AFTER merge' AS label,
  count(*) AS total_spine,
  count(*) FILTER (WHERE is_active) AS active,
  count(*) FILTER (WHERE NOT is_active) AS inactive
FROM core.person_spine;

-- =============================================================================
-- STEP 5: Validate Art Pope
-- =============================================================================
SELECT person_id, norm_first, norm_last, voter_ncid, voter_rncid,
  contribution_count, total_contributed, merged_from, is_active
FROM core.person_spine
WHERE norm_last = 'POPE' 
  AND (norm_first IN ('ART','ARTHUR','JAMES') OR nickname_canonical IN ('ARTHUR','ART'))
ORDER BY is_active DESC, contribution_count DESC;
-- Expected: 1 active record with voter_ncid=EH34831, merged_from has 2-3 IDs

-- Validate no orphaned contribution map entries
SELECT count(*) AS orphaned_contributions
FROM donor_contribution_map dcm
WHERE NOT EXISTS (
  SELECT 1 FROM core.person_spine sp 
  WHERE sp.person_id = dcm.golden_record_id AND sp.is_active = true
);
-- Expected: 0

COMMIT;
