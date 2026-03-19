-- ============================================================================
-- MIGRATION 077: Populate core.contribution_map
-- ============================================================================
-- PROBLEM: core.contribution_map is EMPTY (0 rows). It needs to be populated
--          from two sources:
--          1. donor_contribution_map (1.45M rows) via golden_record_person_map
--          2. fec_donation_person_map (479K direct FEC matches)
--
-- STRATEGY: Bridge inserts first (DCM → golden_record_person_map → person_id),
--           then FEC direct. ON CONFLICT DO NOTHING for dedup.
--
-- DEPENDS ON: Migration 076 (golden_record_person_map populated)
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 0: Create audit table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.migration_077_audit (
    audit_id SERIAL PRIMARY KEY,
    source TEXT NOT NULL,
    records_inserted INT NOT NULL,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- STEP 1: Add UNIQUE constraint on (source_system, source_id)
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_contribution_map_source'
    ) THEN
        ALTER TABLE core.contribution_map
        ADD CONSTRAINT uq_contribution_map_source UNIQUE (source_system, source_id);
    END IF;
END $$;

-- ============================================================================
-- STEP 2: Insert from donor_contribution_map via golden_record_person_map
-- These are NC_BOE, fec_donations, and fec_god source systems
-- ============================================================================
DO $$
DECLARE
    v_bridge_inserted INT := 0;
    v_fec_direct_inserted INT := 0;
    v_total INT := 0;
BEGIN
    INSERT INTO core.contribution_map (person_id, source_system, source_id, amount, transaction_date, committee_id, created_at)
    SELECT
        grpm.person_id,
        dcm.source_system,
        dcm.source_id,
        COALESCE(dcm.contribution_receipt_amount, 0),
        dcm.contribution_receipt_date,
        dcm.committee_id,
        NOW()
    FROM public.donor_contribution_map dcm
    JOIN core.golden_record_person_map grpm
        ON dcm.golden_record_id = grpm.golden_record_id
    WHERE dcm.golden_record_id IS NOT NULL
    ON CONFLICT (source_system, source_id) DO NOTHING;

    GET DIAGNOSTICS v_bridge_inserted = ROW_COUNT;
    RAISE NOTICE '%', format('BRIDGE INSERT (DCM → golden_record_person_map): %s rows', v_bridge_inserted);

    -- =========================================================================
    -- STEP 3: Insert FEC direct matches from fec_donation_person_map
    -- source_system = 'fec_direct', skip already-present rows
    -- =========================================================================
    INSERT INTO core.contribution_map (person_id, source_system, source_id, amount, transaction_date, committee_id, created_at)
    SELECT
        fpm.person_id,
        'fec_direct',
        fd.id::BIGINT,
        COALESCE(fd.contribution_amount, 0),
        fd.contribution_date,
        fd.committee_id,
        NOW()
    FROM core.fec_donation_person_map fpm
    JOIN public.fec_donations fd ON fd.id = fpm.fec_donation_id
    ON CONFLICT (source_system, source_id) DO NOTHING;

    GET DIAGNOSTICS v_fec_direct_inserted = ROW_COUNT;
    RAISE NOTICE '%', format('FEC DIRECT INSERT: %s rows', v_fec_direct_inserted);

    -- =========================================================================
    -- Audit
    -- =========================================================================
    v_total := v_bridge_inserted + v_fec_direct_inserted;

    INSERT INTO public.migration_077_audit (source, records_inserted)
    VALUES
        ('bridge_dcm', v_bridge_inserted),
        ('fec_direct', v_fec_direct_inserted);

    RAISE NOTICE '%', format('============================================');
    RAISE NOTICE '%', format('MIGRATION 077 — FINAL REPORT');
    RAISE NOTICE '%', format('============================================');
    RAISE NOTICE '%', format('Bridge (DCM via golden_record): %s', v_bridge_inserted);
    RAISE NOTICE '%', format('FEC direct: %s', v_fec_direct_inserted);
    RAISE NOTICE '%', format('TOTAL contribution_map rows: %s', v_total);
    RAISE NOTICE '%', format('============================================');
END $$;

COMMIT;

-- ============================================================================
-- ROLLBACK SCRIPT (run separately if needed)
-- ============================================================================
-- BEGIN;
-- TRUNCATE core.contribution_map;
-- DROP TABLE IF EXISTS public.migration_077_audit;
-- COMMIT;
