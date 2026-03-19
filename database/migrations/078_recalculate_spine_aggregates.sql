-- ============================================================================
-- MIGRATION 078: Recalculate person_spine donation aggregates
-- ============================================================================
-- PROBLEM: person_spine aggregates were partially updated by 075 (FEC only).
--          Now that core.contribution_map has 1.28M rows from all sources,
--          recalculate everything from the unified map.
--
-- ALSO: Populate giving_frequency (currently 0 records).
--
-- DEPENDS ON: Migration 077 (core.contribution_map populated)
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 0: Create audit table + snapshot
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.migration_078_audit (
    audit_id SERIAL PRIMARY KEY,
    metric TEXT NOT NULL,
    value_before INT,
    value_after INT,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

DROP TABLE IF EXISTS public.migration_078_snapshot;
CREATE TABLE public.migration_078_snapshot AS
SELECT person_id, total_contributed, contribution_count,
       first_contribution, last_contribution,
       max_single_gift, avg_gift, giving_frequency
FROM core.person_spine
WHERE is_active = TRUE AND total_contributed > 0;


-- ============================================================================
-- STEP 1: Recalculate aggregates from core.contribution_map
-- ============================================================================
DO $$
DECLARE
    v_before_has_totals INT;
    v_after_has_totals INT;
    v_updated INT;
    v_cleared INT;
    v_frequency INT;
BEGIN
    -- Count before
    SELECT COUNT(*) INTO v_before_has_totals
    FROM core.person_spine WHERE is_active = TRUE AND total_contributed > 0;

    RAISE NOTICE '%', format('BEFORE: %s spine records with total_contributed > 0', v_before_has_totals);

    -- Recalculate from contribution_map
    UPDATE core.person_spine sp
    SET
        total_contributed = agg.tot,
        contribution_count = agg.cnt,
        first_contribution = agg.first_dt,
        last_contribution = agg.last_dt,
        max_single_gift = agg.max_amt,
        avg_gift = agg.avg_amt,
        updated_at = NOW()
    FROM (
        SELECT
            person_id,
            SUM(amount) AS tot,
            COUNT(*)::INT AS cnt,
            MIN(transaction_date) AS first_dt,
            MAX(transaction_date) AS last_dt,
            MAX(amount) AS max_amt,
            AVG(amount) AS avg_amt
        FROM core.contribution_map
        GROUP BY person_id
    ) agg
    WHERE sp.person_id = agg.person_id
      AND sp.is_active = TRUE;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RAISE NOTICE '%', format('STEP 1: Updated aggregates for %s spine records', v_updated);


    -- =========================================================================
    -- STEP 2: Populate giving_frequency
    -- one_time: count = 1
    -- frequent: count > 20 OR avg_gap < 90 days
    -- regular: count 6-20, avg_gap 90-365 days
    -- occasional: everything else (count 2-5, or count 6-20 with gap > 365)
    -- avg_gap = (last_contribution - first_contribution) / NULLIF(contribution_count - 1, 0)
    -- =========================================================================
    UPDATE core.person_spine
    SET giving_frequency = CASE
        WHEN contribution_count = 1 THEN 'one_time'
        WHEN contribution_count > 20
             OR (last_contribution - first_contribution)::numeric / NULLIF(contribution_count - 1, 0) < 90
            THEN 'frequent'
        WHEN contribution_count BETWEEN 6 AND 20
             AND (last_contribution - first_contribution)::numeric / NULLIF(contribution_count - 1, 0) BETWEEN 90 AND 365
            THEN 'regular'
        ELSE 'occasional'
    END,
    updated_at = NOW()
    WHERE is_active = TRUE
      AND contribution_count > 0
      AND contribution_count IS NOT NULL;

    GET DIAGNOSTICS v_frequency = ROW_COUNT;
    RAISE NOTICE '%', format('STEP 2: Populated giving_frequency for %s spine records', v_frequency);


    -- =========================================================================
    -- STEP 3: Clear stale aggregates
    -- Spine records that have old totals but no rows in contribution_map
    -- =========================================================================
    UPDATE core.person_spine sp
    SET
        total_contributed = NULL,
        contribution_count = NULL,
        first_contribution = NULL,
        last_contribution = NULL,
        max_single_gift = NULL,
        avg_gift = NULL,
        giving_frequency = NULL,
        updated_at = NOW()
    WHERE sp.is_active = TRUE
      AND sp.total_contributed IS NOT NULL
      AND sp.total_contributed > 0
      AND NOT EXISTS (
          SELECT 1 FROM core.contribution_map cm WHERE cm.person_id = sp.person_id
      );

    GET DIAGNOSTICS v_cleared = ROW_COUNT;
    RAISE NOTICE '%', format('STEP 3: Cleared stale aggregates for %s spine records', v_cleared);

    -- Count after
    SELECT COUNT(*) INTO v_after_has_totals
    FROM core.person_spine WHERE is_active = TRUE AND total_contributed > 0;

    -- =========================================================================
    -- Audit
    -- =========================================================================
    INSERT INTO public.migration_078_audit (metric, value_before, value_after)
    VALUES
        ('spine_with_totals', v_before_has_totals, v_after_has_totals),
        ('aggregates_updated', NULL, v_updated),
        ('frequency_populated', NULL, v_frequency),
        ('stale_cleared', NULL, v_cleared);

    RAISE NOTICE '%', format('============================================');
    RAISE NOTICE '%', format('MIGRATION 078 — FINAL REPORT');
    RAISE NOTICE '%', format('============================================');
    RAISE NOTICE '%', format('Before: %s with totals', v_before_has_totals);
    RAISE NOTICE '%', format('After: %s with totals', v_after_has_totals);
    RAISE NOTICE '%', format('Aggregates recalculated: %s', v_updated);
    RAISE NOTICE '%', format('Frequency populated: %s', v_frequency);
    RAISE NOTICE '%', format('Stale cleared: %s', v_cleared);
    RAISE NOTICE '%', format('============================================');
END $$;

COMMIT;

-- ============================================================================
-- ROLLBACK SCRIPT (run separately if needed)
-- ============================================================================
-- BEGIN;
-- UPDATE core.person_spine sp
-- SET total_contributed = s.total_contributed,
--     contribution_count = s.contribution_count,
--     first_contribution = s.first_contribution,
--     last_contribution = s.last_contribution,
--     max_single_gift = s.max_single_gift,
--     avg_gift = s.avg_gift,
--     giving_frequency = s.giving_frequency
-- FROM public.migration_078_snapshot s
-- WHERE sp.person_id = s.person_id;
-- DROP TABLE IF EXISTS public.migration_078_audit;
-- DROP TABLE IF EXISTS public.migration_078_snapshot;
-- COMMIT;
