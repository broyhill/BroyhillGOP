-- ============================================================================
-- MIGRATION 080b: Repair golden_record_person_map orphaned by 080 spine merge
-- Redirects person_id from merged (inactive) spine records to canonical survivors.
-- Source: staging.spine_clusters (merged -> cluster_root).
-- No DELETE, no TRUNCATE. Wrapped in BEGIN/COMMIT.
-- ============================================================================

BEGIN;

-- Ensure repair log table exists
CREATE TABLE IF NOT EXISTS public.repair_orphans_log (
  log_id SERIAL PRIMARY KEY,
  golden_record_id BIGINT NOT NULL,
  orphan_person_id BIGINT NOT NULL,
  reason TEXT,
  logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- VERIFICATION: Orphans BEFORE
-- ============================================================================
DO $$
DECLARE
  orphans_before BIGINT;
BEGIN
  SELECT COUNT(*) INTO orphans_before
  FROM core.golden_record_person_map grpm
  JOIN core.person_spine ps ON ps.person_id = grpm.person_id
  WHERE ps.is_active = false;

  RAISE NOTICE '=== 080b VERIFICATION ===';
  RAISE NOTICE 'orphans_before: %', orphans_before;
END $$;

-- ============================================================================
-- merge_chain: merged_id -> survivor_id from staging.spine_clusters
-- ============================================================================
WITH merge_chain AS (
  SELECT
    sc.person_id::bigint AS merged_id,
    sc.cluster_root::bigint AS survivor_id
  FROM staging.spine_clusters sc
  WHERE sc.is_canonical = false
)
-- ============================================================================
-- UPDATE: Redirect grpm.person_id from merged to survivor
-- ============================================================================
UPDATE core.golden_record_person_map grpm
SET person_id = mc.survivor_id
FROM merge_chain mc
JOIN core.person_spine ps ON ps.person_id = mc.merged_id
WHERE grpm.person_id = mc.merged_id
  AND ps.is_active = false;

-- ============================================================================
-- ORPHAN LOG: Capture any grpm still pointing to inactive spine with no survivor
-- ============================================================================
INSERT INTO public.repair_orphans_log (golden_record_id, orphan_person_id, reason)
SELECT
  grpm.golden_record_id,
  grpm.person_id,
  'no_survivor_in_merge_chain'
FROM core.golden_record_person_map grpm
JOIN core.person_spine ps ON ps.person_id = grpm.person_id
WHERE ps.is_active = false
  AND NOT EXISTS (
    SELECT 1 FROM staging.spine_clusters sc
    WHERE sc.person_id = grpm.person_id::int
      AND sc.is_canonical = false
      AND sc.cluster_root IS NOT NULL
  );

-- ============================================================================
-- VERIFICATION: Orphans AFTER
-- ============================================================================
DO $$
DECLARE
  orphans_after BIGINT;
  log_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO orphans_after
  FROM core.golden_record_person_map grpm
  JOIN core.person_spine ps ON ps.person_id = grpm.person_id
  WHERE ps.is_active = false;

  SELECT COUNT(*) INTO log_count FROM public.repair_orphans_log;

  RAISE NOTICE '=== 080b VERIFICATION (FINAL) ===';
  RAISE NOTICE 'orphans_after: %', orphans_after;
  RAISE NOTICE 'repair_orphans_log rows: %', log_count;
END $$;

COMMIT;
