-- pipeline/nc_boe_dedup_fixes.sql
-- Critical fixes for NCBOE dedup pipeline (per audit)
-- Run after nc_boe_ddl.sql and before python3 -m pipeline.dedup nc_boe
--
-- Fixes:
-- A. identity_clusters: ensure table exists, add member_ids (stable PKs)
-- B. dedup_rules.notes: JSONB for validation
-- C. nick_group: edgar/ed → edward (Ed Broyhill case)
-- D. Index for dedup blocking on norm_last

-- =============================================================================
-- 1. IDENTITY_CLUSTERS — ensure exists, add member_ids column
-- =============================================================================
CREATE TABLE IF NOT EXISTS pipeline.identity_clusters (
    cluster_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_system TEXT NOT NULL,
    staging_schema TEXT NOT NULL,
    staging_table TEXT NOT NULL,
    cluster_key TEXT NOT NULL,
    member_count INT NOT NULL,
    member_refs JSONB,           -- legacy ctids (deprecated)
    member_ids JSONB,            -- stable row IDs [1,2,3] or ["uuid1","uuid2"]
    match_score_avg NUMERIC,
    status TEXT DEFAULT 'pending_review',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add member_ids if table existed without it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'pipeline' AND table_name = 'identity_clusters' AND column_name = 'member_ids'
    ) THEN
        ALTER TABLE pipeline.identity_clusters ADD COLUMN member_ids JSONB;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_identity_clusters_source ON pipeline.identity_clusters(source_system);
CREATE INDEX IF NOT EXISTS idx_identity_clusters_status ON pipeline.identity_clusters(status);

-- =============================================================================
-- 2. DEDUP_RULES.notes — JSONB for schema validation
-- =============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'pipeline' AND table_name = 'dedup_rules' AND column_name = 'notes')
       AND (SELECT data_type FROM information_schema.columns
            WHERE table_schema = 'pipeline' AND table_name = 'dedup_rules' AND column_name = 'notes') != 'jsonb'
    THEN
        ALTER TABLE pipeline.dedup_rules
            ALTER COLUMN notes TYPE JSONB USING (
                CASE WHEN notes IS NULL OR trim(notes::text) = '' THEN '{}'::jsonb
                     ELSE notes::text::jsonb
                END
            );
    END IF;
END $$;

-- =============================================================================
-- 3. NICK_GROUP — edgar/ed → edward (Ed Broyhill: JAMES EDGAR, ED, EDGAR)
-- =============================================================================
-- Ensures ED and EDGAR both resolve to EDWARD for dedup matching
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'core' AND table_name = 'nick_group') THEN
        INSERT INTO core.nick_group (nickname, canonical, gender) VALUES
            ('edgar', 'edward', 'M'),
            ('ed', 'edward', 'M')
        ON CONFLICT (nickname) DO UPDATE SET canonical = EXCLUDED.canonical;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'core.nick_group: % - add edgar/ed→edward manually if needed', SQLERRM;
END $$;

-- Backfill: rows with canonical_first in (ed, edgar) → edward for dedup
UPDATE public.nc_boe_donations_raw
SET canonical_first = 'edward'
WHERE lower(canonical_first) IN ('ed', 'edgar') AND canonical_first != 'edward';

-- =============================================================================
-- 4. DEDUP INDEX — block on norm_last
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_ncboe_dedup_block
    ON public.nc_boe_donations_raw (norm_last)
    WHERE norm_last IS NOT NULL AND transaction_type = 'Individual';
