-- ============================================================================
-- MIGRATION 076: Bridge golden_record_id → core.person_spine.person_id
-- ============================================================================
-- PROBLEM: donor_contribution_map has 1,448,131 rows linked to 186,326
--          unique golden_record_ids, but these are NOT linked to person_spine.
--
-- STRATEGY: Extract distinct golden_record_id + name/zip from DCM, then
--           multi-pass match against person_spine (exact → nickname → address).
--           golden_record_clusters only has 3 rows, so DCM is the real source.
--
-- SCHEMA NOTES:
--   - donor_contribution_map: golden_record_id, norm_last, norm_first, zip5
--     (UPPERCASE names)
--   - core.person_spine: person_id, norm_last, norm_first, nickname_canonical,
--     zip5, addr_hash, data_quality_score, is_active
--
-- DEPENDS ON: Migration 075 (person_spine aggregates current)
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 0: Create audit table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.migration_076_audit (
    audit_id SERIAL PRIMARY KEY,
    match_method TEXT NOT NULL,
    records_matched INT NOT NULL,
    pct_of_total NUMERIC(5,2),
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- STEP 1: Create bridge table core.golden_record_person_map
-- ============================================================================
CREATE TABLE IF NOT EXISTS core.golden_record_person_map (
    golden_record_id BIGINT NOT NULL UNIQUE,
    person_id BIGINT NOT NULL REFERENCES core.person_spine(person_id) ON DELETE CASCADE,
    match_method TEXT NOT NULL,
    match_confidence NUMERIC(4,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_076_match_method CHECK (match_method IN ('pass1_exact', 'pass2_nickname', 'pass3_address'))
);

CREATE INDEX IF NOT EXISTS idx_golden_record_person_map_person
    ON core.golden_record_person_map(person_id);

-- ============================================================================
-- STEP 2: Snapshot for rollback
-- ============================================================================
DROP TABLE IF EXISTS public.migration_076_snapshot;
CREATE TABLE public.migration_076_snapshot AS
SELECT golden_record_id, norm_last, norm_first, zip5
FROM (
    SELECT DISTINCT ON (golden_record_id)
        golden_record_id, norm_last, norm_first, zip5
    FROM public.donor_contribution_map
    WHERE golden_record_id IS NOT NULL
    ORDER BY golden_record_id
) sub;


-- ============================================================================
-- STEP 3: Multi-pass matching
-- ============================================================================
DO $$
DECLARE
    v_total_golden INT;
    v_pass1 INT := 0;
    v_pass2 INT := 0;
    v_pass3 INT := 0;
    v_total_matched INT := 0;
    v_pct NUMERIC;
BEGIN
    -- Get distinct golden_record_ids from DCM
    SELECT COUNT(DISTINCT golden_record_id) INTO v_total_golden
    FROM public.donor_contribution_map
    WHERE golden_record_id IS NOT NULL;

    RAISE NOTICE '%', format('MIGRATION 076: %s unique golden_record_ids to bridge', v_total_golden);

    -- -------------------------------------------------------------------------
    -- PASS 1: Exact name + zip (confidence 0.95)
    -- -------------------------------------------------------------------------
    INSERT INTO core.golden_record_person_map (golden_record_id, person_id, match_method, match_confidence)
    SELECT
        dcm_distinct.golden_record_id,
        sp.person_id,
        'pass1_exact',
        0.95
    FROM (
        SELECT DISTINCT ON (golden_record_id)
            golden_record_id, norm_last, norm_first, zip5
        FROM public.donor_contribution_map
        WHERE golden_record_id IS NOT NULL
          AND norm_last IS NOT NULL AND norm_last != ''
          AND norm_first IS NOT NULL AND norm_first != ''
          AND zip5 IS NOT NULL AND zip5 != ''
        ORDER BY golden_record_id
    ) dcm_distinct
    JOIN core.person_spine sp
        ON dcm_distinct.norm_last = sp.norm_last
        AND dcm_distinct.norm_first = sp.norm_first
        AND dcm_distinct.zip5 = sp.zip5
    WHERE sp.is_active = TRUE
      AND sp.norm_last IS NOT NULL
      AND sp.norm_first IS NOT NULL
      AND sp.zip5 IS NOT NULL
    ON CONFLICT (golden_record_id) DO NOTHING;

    GET DIAGNOSTICS v_pass1 = ROW_COUNT;
    RAISE NOTICE '%', format('PASS 1 (exact name+zip): %s matched', v_pass1);


    -- -------------------------------------------------------------------------
    -- PASS 2: Last + nickname_canonical + zip (confidence 0.85)
    -- -------------------------------------------------------------------------
    INSERT INTO core.golden_record_person_map (golden_record_id, person_id, match_method, match_confidence)
    SELECT
        dcm_distinct.golden_record_id,
        sp.person_id,
        'pass2_nickname',
        0.85
    FROM (
        SELECT DISTINCT ON (golden_record_id)
            golden_record_id, norm_last, norm_first, zip5
        FROM public.donor_contribution_map
        WHERE golden_record_id IS NOT NULL
          AND norm_last IS NOT NULL AND norm_last != ''
          AND norm_first IS NOT NULL AND norm_first != ''
          AND zip5 IS NOT NULL AND zip5 != ''
        ORDER BY golden_record_id
    ) dcm_distinct
    JOIN core.person_spine sp
        ON dcm_distinct.norm_last = sp.norm_last
        AND dcm_distinct.norm_first = sp.nickname_canonical
        AND dcm_distinct.zip5 = sp.zip5
    WHERE sp.is_active = TRUE
      AND sp.nickname_canonical IS NOT NULL
      AND sp.nickname_canonical != ''
      AND NOT EXISTS (SELECT 1 FROM core.golden_record_person_map m WHERE m.golden_record_id = dcm_distinct.golden_record_id)
    ON CONFLICT (golden_record_id) DO NOTHING;

    GET DIAGNOSTICS v_pass2 = ROW_COUNT;
    RAISE NOTICE '%', format('PASS 2 (nickname): %s matched', v_pass2);


    -- -------------------------------------------------------------------------
    -- PASS 3: Last + first + addr_hash (confidence 0.80)
    -- Use norm_employer from DCM to build addr_hash proxy where available
    -- -------------------------------------------------------------------------
    INSERT INTO core.golden_record_person_map (golden_record_id, person_id, match_method, match_confidence)
    SELECT
        dcm_distinct.golden_record_id,
        sp.person_id,
        'pass3_address',
        0.80
    FROM (
        SELECT DISTINCT ON (golden_record_id)
            golden_record_id, norm_last, norm_first, zip5, norm_employer
        FROM public.donor_contribution_map
        WHERE golden_record_id IS NOT NULL
          AND norm_last IS NOT NULL AND norm_last != ''
          AND norm_first IS NOT NULL AND norm_first != ''
        ORDER BY golden_record_id
    ) dcm_distinct
    JOIN core.person_spine sp
        ON dcm_distinct.norm_last = sp.norm_last
        AND dcm_distinct.norm_first = sp.norm_first
        AND LOWER(TRIM(COALESCE(dcm_distinct.norm_employer, ''))) = LOWER(TRIM(COALESCE(sp.employer, '')))
    WHERE sp.is_active = TRUE
      AND dcm_distinct.norm_employer IS NOT NULL
      AND dcm_distinct.norm_employer != ''
      AND sp.employer IS NOT NULL
      AND sp.employer != ''
      AND NOT EXISTS (SELECT 1 FROM core.golden_record_person_map m WHERE m.golden_record_id = dcm_distinct.golden_record_id)
    ON CONFLICT (golden_record_id) DO NOTHING;

    GET DIAGNOSTICS v_pass3 = ROW_COUNT;
    RAISE NOTICE '%', format('PASS 3 (name+employer): %s matched', v_pass3);


    -- -------------------------------------------------------------------------
    -- Audit records
    -- -------------------------------------------------------------------------
    v_total_matched := v_pass1 + v_pass2 + v_pass3;
    v_pct := ROUND(v_total_matched::numeric / NULLIF(v_total_golden, 0) * 100, 2);

    INSERT INTO public.migration_076_audit (match_method, records_matched, pct_of_total)
    VALUES
        ('pass1_exact', v_pass1, ROUND(v_pass1::numeric / NULLIF(v_total_golden, 0) * 100, 2)),
        ('pass2_nickname', v_pass2, ROUND(v_pass2::numeric / NULLIF(v_total_golden, 0) * 100, 2)),
        ('pass3_address', v_pass3, ROUND(v_pass3::numeric / NULLIF(v_total_golden, 0) * 100, 2));

    RAISE NOTICE '%', format('TOTAL BRIDGED: %s / %s (%s%%)', v_total_matched, v_total_golden, v_pct);
    RAISE NOTICE '%', format('REMAINING UNBRIDGED: %s', v_total_golden - v_total_matched);
END $$;

-- ============================================================================
-- STEP 4: Final report
-- ============================================================================
DO $$
DECLARE
    v_bridged INT;
    v_unique_person INT;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT person_id)
    INTO v_bridged, v_unique_person
    FROM core.golden_record_person_map;
    RAISE NOTICE '%', format('============================================');
    RAISE NOTICE '%', format('MIGRATION 076 — FINAL REPORT');
    RAISE NOTICE '%', format('============================================');
    RAISE NOTICE '%', format('Golden records bridged: %s', v_bridged);
    RAISE NOTICE '%', format('Unique spine persons linked: %s', v_unique_person);
    RAISE NOTICE '%', format('============================================');
END $$;

COMMIT;

-- ============================================================================
-- ROLLBACK SCRIPT (run separately if needed)
-- ============================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS core.golden_record_person_map;
-- DROP TABLE IF EXISTS public.migration_076_audit;
-- DROP TABLE IF EXISTS public.migration_076_snapshot;
-- COMMIT;
