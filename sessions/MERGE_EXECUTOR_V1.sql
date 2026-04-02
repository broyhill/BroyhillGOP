-- ============================================================================
-- BROYHILLGOP MERGE EXECUTOR V1
-- Executes the 4 approved P7_DT_HOUSEHOLD_SAME_NAME pairs
-- from staging.v3_merge_candidates into core.person_spine
-- ============================================================================
-- AUTHOR: Perplexity (CEO, AI team)
-- DATE: 2026-04-02
-- AUTHORIZED BY: Ed Broyhill (April 2, 2026)
--
-- APPROVED PAIRS (reviewed and confirmed by Perplexity):
--   keeper 4742  / merge 149805 — KATHLEEN EATON  1944 — same birth year, DT household, moved zips
--   keeper 23556 / merge 158538 — RICHARD FRIEDMAN 1956 — same birth year, DT household
--   keeper 43758 / merge 199442 — JOHN BUGG        1944 — same birth year, DT household
--   keeper 79305 / merge 188525 — THOMAS BLUE      1955 — same birth year, DT household, WELLS FARGO
--
-- SAFETY RULES:
--   1. Creates merge log FIRST — full audit trail
--   2. Redirects contribution_map BEFORE deactivating spine
--   3. Canary check: Ed person_id 26451 must remain is_active = true
--   4. Final count must be 128,043 (128,047 - 4)
--   5. TRANSACTION wrapped — rolls back everything if canary fails
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 0: Create merge log table if not exists
-- ============================================================================
CREATE TABLE IF NOT EXISTS staging.v3_merge_log (
  id              SERIAL PRIMARY KEY,
  keeper_id       BIGINT NOT NULL,
  merged_id       BIGINT NOT NULL,
  match_method    TEXT NOT NULL,
  keeper_name     TEXT,
  merged_name     TEXT,
  birth_year      SMALLINT,
  executed_at     TIMESTAMPTZ DEFAULT NOW(),
  authorized_by   TEXT DEFAULT 'Ed Broyhill — April 2, 2026'
);

-- ============================================================================
-- STEP 1: Log all 4 approved merges BEFORE executing
-- ============================================================================
INSERT INTO staging.v3_merge_log
  (keeper_id, merged_id, match_method, keeper_name, merged_name, birth_year)
SELECT
  mc.keeper_person_id,
  mc.merge_person_id,
  mc.match_method,
  a.norm_first || ' ' || a.norm_last,
  b.norm_first || ' ' || b.norm_last,
  a.birth_year
FROM staging.v3_merge_candidates mc
JOIN core.person_spine a ON mc.keeper_person_id = a.person_id
JOIN core.person_spine b ON mc.merge_person_id = b.person_id
WHERE mc.match_method = 'P7_DT_HOUSEHOLD_SAME_NAME';

-- Verify 4 rows logged
DO $$
DECLARE v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count FROM staging.v3_merge_log WHERE executed_at > NOW() - INTERVAL '1 minute';
  IF v_count != 4 THEN
    RAISE EXCEPTION 'Expected 4 merge log rows, got %. Aborting.', v_count;
  END IF;
END $$;

-- ============================================================================
-- STEP 2: Redirect contribution_map from merged → keeper
-- ============================================================================
UPDATE core.contribution_map cm
SET person_id = mc.keeper_person_id
FROM staging.v3_merge_candidates mc
WHERE cm.person_id = mc.merge_person_id
  AND mc.match_method = 'P7_DT_HOUSEHOLD_SAME_NAME';

-- ============================================================================
-- STEP 3: Deactivate merged spine records
-- ============================================================================
UPDATE core.person_spine
SET is_active = false
WHERE person_id IN (
  SELECT merge_person_id FROM staging.v3_merge_candidates
  WHERE match_method = 'P7_DT_HOUSEHOLD_SAME_NAME'
);

-- ============================================================================
-- STEP 4: CANARY — Ed Broyhill must remain active
-- ============================================================================
DO $$
DECLARE v_ed_active BOOLEAN;
BEGIN
  SELECT is_active INTO v_ed_active FROM core.person_spine WHERE person_id = 26451;
  IF v_ed_active IS NOT TRUE THEN
    RAISE EXCEPTION 'CANARY FAILED: Ed Broyhill person_id 26451 is not active. Rolling back.';
  END IF;
  RAISE NOTICE 'CANARY PASSED: Ed Broyhill is_active = true';
END $$;

-- ============================================================================
-- STEP 5: CANARY — Final active count must be 128,043
-- ============================================================================
DO $$
DECLARE v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count FROM core.person_spine WHERE is_active = true;
  IF v_count != 128043 THEN
    RAISE EXCEPTION 'CANARY FAILED: Expected 128043 active records, got %. Rolling back.', v_count;
  END IF;
  RAISE NOTICE 'CANARY PASSED: Active spine count = %', v_count;
END $$;

COMMIT;

-- ============================================================================
-- STEP 6: FINAL REPORT (outside transaction)
-- ============================================================================
SELECT 'MERGE COMPLETE' AS status,
  COUNT(*) AS active_spine,
  (SELECT COUNT(*) FROM staging.v3_merge_log) AS merges_logged
FROM core.person_spine WHERE is_active = true;

SELECT keeper_id, merged_id, keeper_name, merged_name, birth_year, executed_at
FROM staging.v3_merge_log
ORDER BY id;

SELECT match_method, COUNT(*) as remaining
FROM staging.v3_merge_candidates
GROUP BY match_method;
