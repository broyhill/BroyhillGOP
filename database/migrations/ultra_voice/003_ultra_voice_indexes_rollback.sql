-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║                                                                                           ║
-- ║     BROYHILLGOP PLATFORM - ULTRA VOICE SYNTHESIS                                         ║
-- ║     Migration: 2024_003_ultra_voice_indexes_and_rollback                                 ║
-- ║                                                                                           ║
-- ║     Performance Indexes & Rollback Script                                                ║
-- ║                                                                                           ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- PERFORMANCE INDEXES
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Composite indexes for common queries
-- ---------------------------------------------------------------------------

-- Request lookups by ecosystem and date (dashboard, reports)
CREATE INDEX IF NOT EXISTS idx_voice_requests_ecosystem_date 
ON ultra_voice_requests(ecosystem, DATE(created_at) DESC);

-- Request lookups by candidate (candidate dashboard)
CREATE INDEX IF NOT EXISTS idx_voice_requests_candidate_date 
ON ultra_voice_requests(candidate_id, created_at DESC) 
WHERE candidate_id IS NOT NULL;

-- Request lookups by campaign (campaign reporting)
CREATE INDEX IF NOT EXISTS idx_voice_requests_campaign 
ON ultra_voice_requests(campaign_id, created_at DESC) 
WHERE campaign_id IS NOT NULL;

-- Quality metrics for engine optimization
CREATE INDEX IF NOT EXISTS idx_quality_metrics_engine_date 
ON ultra_quality_metrics(engine, DATE(recorded_at) DESC);

-- Quality metrics for ecosystem analysis
CREATE INDEX IF NOT EXISTS idx_quality_metrics_ecosystem_date 
ON ultra_quality_metrics(ecosystem, DATE(recorded_at) DESC);

-- Cost tracking lookups
CREATE INDEX IF NOT EXISTS idx_cost_tracking_date_ecosystem 
ON ultra_cost_tracking(tracking_date DESC, ecosystem);

-- Active triggers lookup
CREATE INDEX IF NOT EXISTS idx_triggers_active_recent 
ON ultra_triggers(triggered_at DESC) 
WHERE is_resolved = false;

-- Batch jobs by status
CREATE INDEX IF NOT EXISTS idx_batch_jobs_status_created 
ON ultra_batch_jobs(status, created_at DESC);

-- Batch job items by job and status
CREATE INDEX IF NOT EXISTS idx_batch_items_job_status 
ON ultra_batch_job_items(batch_job_id, status);

-- Voice profiles active lookup
CREATE INDEX IF NOT EXISTS idx_voice_profiles_candidate_active 
ON ultra_voice_profiles(candidate_id, is_active) 
WHERE is_active = true;


-- ---------------------------------------------------------------------------
-- GIN indexes for JSONB columns
-- ---------------------------------------------------------------------------

-- Request options search
CREATE INDEX IF NOT EXISTS idx_voice_requests_options_gin 
ON ultra_voice_requests USING GIN (options);

-- Voice features search
CREATE INDEX IF NOT EXISTS idx_voice_profiles_features_gin 
ON ultra_voice_profiles USING GIN (voice_features);

-- Engine usage in cost tracking
CREATE INDEX IF NOT EXISTS idx_cost_tracking_engine_usage_gin 
ON ultra_cost_tracking USING GIN (engine_usage);

-- Trigger data search
CREATE INDEX IF NOT EXISTS idx_triggers_data_gin 
ON ultra_triggers USING GIN (trigger_data);


-- ---------------------------------------------------------------------------
-- Partial indexes for common filtered queries
-- ---------------------------------------------------------------------------

-- Completed requests only
CREATE INDEX IF NOT EXISTS idx_voice_requests_completed 
ON ultra_voice_requests(created_at DESC, ecosystem) 
WHERE status = 'completed';

-- Failed requests for retry
CREATE INDEX IF NOT EXISTS idx_voice_requests_failed_retry 
ON ultra_voice_requests(created_at DESC) 
WHERE status = 'failed' AND retry_count < 3;

-- High quality requests (exceeds ElevenLabs)
CREATE INDEX IF NOT EXISTS idx_voice_requests_high_quality 
ON ultra_voice_requests(quality_score DESC) 
WHERE quality_score >= 4.5;

-- Pending batch items
CREATE INDEX IF NOT EXISTS idx_batch_items_pending 
ON ultra_batch_job_items(batch_job_id) 
WHERE status = 'pending';


-- ---------------------------------------------------------------------------
-- BRIN indexes for time-series data (very efficient for date columns)
-- ---------------------------------------------------------------------------

-- Request timestamp (better for range scans)
CREATE INDEX IF NOT EXISTS idx_voice_requests_created_brin 
ON ultra_voice_requests USING BRIN (created_at);

-- Quality metrics timestamp
CREATE INDEX IF NOT EXISTS idx_quality_metrics_recorded_brin 
ON ultra_quality_metrics USING BRIN (recorded_at);

-- Trigger timestamp
CREATE INDEX IF NOT EXISTS idx_triggers_triggered_brin 
ON ultra_triggers USING BRIN (triggered_at);


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- TABLE STATISTICS & MAINTENANCE
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- Analyze tables for optimal query planning
ANALYZE ultra_voice_profiles;
ANALYZE ultra_voice_requests;
ANALYZE ultra_quality_metrics;
ANALYZE ultra_cost_tracking;
ANALYZE ultra_engine_performance;
ANALYZE ultra_triggers;
ANALYZE ultra_configuration;
ANALYZE ultra_audio_cache;
ANALYZE ultra_batch_jobs;
ANALYZE ultra_batch_job_items;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- PARTITIONING SETUP (for high-volume tables)
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- Note: If request volume becomes very high (>10M rows), consider partitioning
-- by date. Here's the setup that could be used:

/*
-- Create partitioned requests table
CREATE TABLE ultra_voice_requests_partitioned (
    LIKE ultra_voice_requests INCLUDING ALL
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE ultra_voice_requests_2024_01 
    PARTITION OF ultra_voice_requests_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE ultra_voice_requests_2024_02 
    PARTITION OF ultra_voice_requests_partitioned
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
-- ... etc

-- Function to auto-create partitions
CREATE OR REPLACE FUNCTION ultra_create_monthly_partition()
RETURNS TRIGGER AS $$
DECLARE
    partition_date DATE;
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    partition_date := DATE_TRUNC('month', NEW.created_at);
    partition_name := 'ultra_voice_requests_' || TO_CHAR(partition_date, 'YYYY_MM');
    start_date := partition_date;
    end_date := partition_date + INTERVAL '1 month';
    
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = partition_name) THEN
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF ultra_voice_requests_partitioned
             FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_date, end_date
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
*/


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- ROLLBACK / DOWN MIGRATION
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- To rollback this migration, run the following:

/*
-- DROP VIEWS
DROP VIEW IF EXISTS ultra_cost_savings_summary;
DROP VIEW IF EXISTS ultra_engine_comparison;
DROP VIEW IF EXISTS ultra_ecosystem_summary;
DROP VIEW IF EXISTS ultra_daily_summary;

-- DROP FUNCTIONS
DROP FUNCTION IF EXISTS ultra_get_ecosystem_status();
DROP FUNCTION IF EXISTS ultra_get_dashboard_stats();
DROP FUNCTION IF EXISTS ultra_archive_old_requests(INTEGER);
DROP FUNCTION IF EXISTS ultra_cleanup_expired_cache();
DROP FUNCTION IF EXISTS ultra_update_batch_progress(UUID, UUID, VARCHAR, UUID, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS ultra_create_batch_job(VARCHAR, VARCHAR, ultra_ecosystem, JSONB, JSONB, UUID, UUID);
DROP FUNCTION IF EXISTS ultra_get_cost_summary(INTEGER);
DROP FUNCTION IF EXISTS ultra_get_quality_trends(INTEGER);
DROP FUNCTION IF EXISTS ultra_get_engine_recommendations();
DROP FUNCTION IF EXISTS ultra_record_quality_metrics(UUID, ultra_ecosystem, ultra_engine, ultra_quality_tier, DECIMAL, JSONB);
DROP FUNCTION IF EXISTS ultra_get_all_config();
DROP FUNCTION IF EXISTS ultra_toggle_feature(VARCHAR, BOOLEAN, INTEGER, VARCHAR);
DROP FUNCTION IF EXISTS ultra_set_config(VARCHAR, JSONB, VARCHAR, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS ultra_get_config(VARCHAR);
DROP FUNCTION IF EXISTS ultra_get_voice_profile(UUID);
DROP FUNCTION IF EXISTS ultra_upsert_voice_profile(UUID, VARCHAR, VARCHAR, INTEGER, DECIMAL, DECIMAL, DECIMAL, JSONB, JSONB);
DROP FUNCTION IF EXISTS ultra_complete_request(UUID, VARCHAR, INTEGER, DECIMAL, BIGINT, VARCHAR, DECIMAL, ultra_engine[], ultra_engine, JSONB);
DROP FUNCTION IF EXISTS ultra_update_request_status(UUID, ultra_request_status, TEXT);
DROP FUNCTION IF EXISTS ultra_create_request(TEXT, ultra_ecosystem, ultra_request_type, VARCHAR, JSONB, ultra_quality_tier, UUID, UUID, UUID);
DROP FUNCTION IF EXISTS ultra_check_quality_triggers();
DROP FUNCTION IF EXISTS ultra_update_engine_performance();
DROP FUNCTION IF EXISTS ultra_update_cost_tracking();
DROP FUNCTION IF EXISTS ultra_calculate_cache_key(TEXT, VARCHAR, JSONB);
DROP FUNCTION IF EXISTS update_updated_at();

-- DROP TRIGGERS
DROP TRIGGER IF EXISTS trigger_configuration_updated ON ultra_configuration;
DROP TRIGGER IF EXISTS trigger_voice_profiles_updated ON ultra_voice_profiles;
DROP TRIGGER IF EXISTS trigger_check_quality ON ultra_voice_requests;
DROP TRIGGER IF EXISTS trigger_update_engine_performance ON ultra_voice_requests;
DROP TRIGGER IF EXISTS trigger_update_cost_tracking ON ultra_voice_requests;

-- DROP TABLES (in correct order due to foreign keys)
DROP TABLE IF EXISTS ultra_batch_job_items;
DROP TABLE IF EXISTS ultra_batch_jobs;
DROP TABLE IF EXISTS ultra_audio_cache;
DROP TABLE IF EXISTS ultra_configuration_history;
DROP TABLE IF EXISTS ultra_configuration;
DROP TABLE IF EXISTS ultra_triggers;
DROP TABLE IF EXISTS ultra_engine_performance;
DROP TABLE IF EXISTS ultra_cost_tracking;
DROP TABLE IF EXISTS ultra_quality_metrics;
DROP TABLE IF EXISTS ultra_voice_requests;
DROP TABLE IF EXISTS ultra_voice_profiles;

-- DROP ENUMS
DROP TYPE IF EXISTS ultra_trigger_type;
DROP TYPE IF EXISTS ultra_quality_tier;
DROP TYPE IF EXISTS ultra_request_status;
DROP TYPE IF EXISTS ultra_engine;
DROP TYPE IF EXISTS ultra_ecosystem;
DROP TYPE IF EXISTS ultra_request_type;
*/


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- Verify all tables exist
DO $$
DECLARE
    v_tables TEXT[] := ARRAY[
        'ultra_voice_profiles',
        'ultra_voice_requests', 
        'ultra_quality_metrics',
        'ultra_cost_tracking',
        'ultra_engine_performance',
        'ultra_triggers',
        'ultra_configuration',
        'ultra_configuration_history',
        'ultra_audio_cache',
        'ultra_batch_jobs',
        'ultra_batch_job_items'
    ];
    v_table TEXT;
    v_exists BOOLEAN;
BEGIN
    FOREACH v_table IN ARRAY v_tables
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = v_table
        ) INTO v_exists;
        
        IF NOT v_exists THEN
            RAISE EXCEPTION 'Table % does not exist', v_table;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'All ULTRA Voice tables verified successfully';
END;
$$;

-- Verify all views exist
DO $$
DECLARE
    v_views TEXT[] := ARRAY[
        'ultra_daily_summary',
        'ultra_ecosystem_summary',
        'ultra_engine_comparison',
        'ultra_cost_savings_summary'
    ];
    v_view TEXT;
    v_exists BOOLEAN;
BEGIN
    FOREACH v_view IN ARRAY v_views
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.views 
            WHERE table_name = v_view
        ) INTO v_exists;
        
        IF NOT v_exists THEN
            RAISE EXCEPTION 'View % does not exist', v_view;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'All ULTRA Voice views verified successfully';
END;
$$;

-- Verify configuration seeded
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM ultra_configuration;
    
    IF v_count < 15 THEN
        RAISE WARNING 'Expected at least 15 configuration entries, found %', v_count;
    ELSE
        RAISE NOTICE 'Configuration verified: % entries', v_count;
    END IF;
END;
$$;

-- Print summary
SELECT 
    'ULTRA Voice Migration Complete' as status,
    (SELECT COUNT(*) FROM ultra_configuration) as config_entries,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name LIKE 'ultra_%') as tables_created,
    (SELECT COUNT(*) FROM information_schema.views WHERE table_name LIKE 'ultra_%') as views_created,
    (SELECT COUNT(*) FROM pg_indexes WHERE indexname LIKE 'idx_ultra%' OR indexname LIKE 'idx_voice%' OR indexname LIKE 'idx_quality%' OR indexname LIKE 'idx_cost%' OR indexname LIKE 'idx_engine%' OR indexname LIKE 'idx_triggers%' OR indexname LIKE 'idx_config%' OR indexname LIKE 'idx_audio%' OR indexname LIKE 'idx_batch%') as indexes_created;
