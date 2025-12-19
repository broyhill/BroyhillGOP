-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║                                                                                           ║
-- ║     BROYHILLGOP PLATFORM - ULTRA VOICE SYNTHESIS                                         ║
-- ║     Migration: 2024_002_ultra_voice_stored_procedures                                    ║
-- ║                                                                                           ║
-- ║     Stored Procedures and API Functions                                                  ║
-- ║                                                                                           ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- REQUEST MANAGEMENT FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Create a new voice synthesis request
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_create_request(
    p_text TEXT,
    p_ecosystem ultra_ecosystem,
    p_request_type ultra_request_type DEFAULT 'tts_simple',
    p_voice_id VARCHAR(255) DEFAULT NULL,
    p_options JSONB DEFAULT '{}',
    p_quality_tier ultra_quality_tier DEFAULT 'high',
    p_candidate_id UUID DEFAULT NULL,
    p_campaign_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_request_id UUID;
    v_cache_key VARCHAR(64);
    v_cached_request_id UUID;
    v_caching_enabled BOOLEAN;
    v_elevenlabs_cost DECIMAL(10,4);
BEGIN
    -- Check if caching is enabled
    SELECT (config_value->>'value')::BOOLEAN 
    INTO v_caching_enabled
    FROM ultra_configuration 
    WHERE config_key = 'caching_enabled';
    
    v_caching_enabled := COALESCE(v_caching_enabled, true);
    
    -- Calculate cache key
    v_cache_key := ultra_calculate_cache_key(p_text, p_voice_id, p_options);
    
    -- Check cache if enabled
    IF v_caching_enabled THEN
        SELECT original_request_id INTO v_cached_request_id
        FROM ultra_audio_cache
        WHERE cache_key = v_cache_key
        AND (expires_at IS NULL OR expires_at > NOW());
        
        IF v_cached_request_id IS NOT NULL THEN
            -- Update cache hit count
            UPDATE ultra_audio_cache
            SET hit_count = hit_count + 1,
                last_hit_at = NOW()
            WHERE cache_key = v_cache_key;
            
            -- Return cached request ID with cache hit marker
            -- Caller should check for cache hit
            RETURN v_cached_request_id;
        END IF;
    END IF;
    
    -- Calculate ElevenLabs equivalent cost
    v_elevenlabs_cost := LENGTH(p_text) * 0.0003;  -- $0.30/1000 chars
    
    -- Create new request
    INSERT INTO ultra_voice_requests (
        request_type,
        ecosystem,
        input_text,
        voice_id,
        options,
        quality_tier,
        candidate_id,
        campaign_id,
        user_id,
        cache_key,
        elevenlabs_equivalent_cost,
        status
    ) VALUES (
        p_request_type,
        p_ecosystem,
        p_text,
        p_voice_id,
        p_options,
        p_quality_tier,
        p_candidate_id,
        p_campaign_id,
        p_user_id,
        v_cache_key,
        v_elevenlabs_cost,
        'pending'
    )
    RETURNING id INTO v_request_id;
    
    RETURN v_request_id;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Update request status with timing
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_update_request_status(
    p_request_id UUID,
    p_status ultra_request_status,
    p_error_message TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE ultra_voice_requests
    SET status = p_status,
        error_message = COALESCE(p_error_message, error_message),
        started_at = CASE WHEN p_status = 'processing' AND started_at IS NULL THEN NOW() ELSE started_at END,
        completed_at = CASE WHEN p_status IN ('completed', 'failed', 'rejected_quality') THEN NOW() ELSE completed_at END,
        processing_time_ms = CASE 
            WHEN p_status IN ('completed', 'failed', 'rejected_quality') AND started_at IS NOT NULL 
            THEN EXTRACT(MILLISECONDS FROM (NOW() - started_at))::INTEGER 
            ELSE processing_time_ms 
        END
    WHERE id = p_request_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Complete request with output details
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_complete_request(
    p_request_id UUID,
    p_audio_path VARCHAR(500),
    p_sample_rate INTEGER,
    p_duration_seconds DECIMAL(10,2),
    p_file_size_bytes BIGINT,
    p_format VARCHAR(20),
    p_quality_score DECIMAL(3,2),
    p_engines_used ultra_engine[],
    p_primary_engine ultra_engine,
    p_pipeline_stages JSONB DEFAULT '{}'
) RETURNS BOOLEAN AS $$
DECLARE
    v_elevenlabs_cost DECIMAL(10,4);
    v_ultra_cost DECIMAL(10,4);
    v_text_length INTEGER;
    v_cache_key VARCHAR(64);
    v_cache_ttl INTEGER;
BEGIN
    -- Get request details
    SELECT input_text_length, elevenlabs_equivalent_cost, cache_key
    INTO v_text_length, v_elevenlabs_cost, v_cache_key
    FROM ultra_voice_requests
    WHERE id = p_request_id;
    
    -- Calculate ULTRA cost (much lower than ElevenLabs)
    v_ultra_cost := v_text_length * 0.000002;  -- ~$0.002/1000 chars
    
    -- Update request
    UPDATE ultra_voice_requests
    SET status = 'completed',
        output_audio_path = p_audio_path,
        output_sample_rate = p_sample_rate,
        output_duration_seconds = p_duration_seconds,
        output_file_size_bytes = p_file_size_bytes,
        output_format = p_format,
        quality_score = p_quality_score,
        engines_used = p_engines_used,
        primary_engine = p_primary_engine,
        ensemble_enabled = COALESCE((p_pipeline_stages->>'ensemble')::BOOLEAN, false),
        enhancement_enabled = COALESCE((p_pipeline_stages->>'enhancement')::BOOLEAN, false),
        super_resolution_enabled = COALESCE((p_pipeline_stages->>'super_resolution')::BOOLEAN, false),
        prosody_enabled = COALESCE((p_pipeline_stages->>'prosody')::BOOLEAN, false),
        ultra_actual_cost = v_ultra_cost,
        cost_saved = v_elevenlabs_cost - v_ultra_cost,
        completed_at = NOW(),
        processing_time_ms = EXTRACT(MILLISECONDS FROM (NOW() - started_at))::INTEGER
    WHERE id = p_request_id;
    
    -- Add to cache
    SELECT (config_value->>'value')::INTEGER 
    INTO v_cache_ttl
    FROM ultra_configuration 
    WHERE config_key = 'cache_ttl_hours';
    
    v_cache_ttl := COALESCE(v_cache_ttl, 168);  -- 7 days default
    
    INSERT INTO ultra_audio_cache (
        cache_key,
        original_request_id,
        input_text_hash,
        voice_id,
        audio_path,
        audio_format,
        audio_duration_seconds,
        audio_sample_rate,
        file_size_bytes,
        quality_score,
        expires_at
    )
    SELECT 
        v_cache_key,
        p_request_id,
        MD5(input_text),
        voice_id,
        p_audio_path,
        p_format,
        p_duration_seconds,
        p_sample_rate,
        p_file_size_bytes,
        p_quality_score,
        NOW() + (v_cache_ttl || ' hours')::INTERVAL
    FROM ultra_voice_requests
    WHERE id = p_request_id
    ON CONFLICT (cache_key) DO UPDATE SET
        hit_count = ultra_audio_cache.hit_count,  -- Keep existing hit count
        expires_at = EXCLUDED.expires_at;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- VOICE PROFILE FUNCTIONS (E48 DNA)
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Create or update voice profile
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_upsert_voice_profile(
    p_candidate_id UUID,
    p_voice_id VARCHAR(255),
    p_profile_name VARCHAR(255) DEFAULT NULL,
    p_sample_count INTEGER DEFAULT 0,
    p_sample_duration DECIMAL(10,2) DEFAULT 0,
    p_clone_quality_score DECIMAL(3,2) DEFAULT NULL,
    p_similarity_score DECIMAL(5,2) DEFAULT NULL,
    p_voice_features JSONB DEFAULT '{}',
    p_sample_paths JSONB DEFAULT '[]'
) RETURNS UUID AS $$
DECLARE
    v_profile_id UUID;
BEGIN
    INSERT INTO ultra_voice_profiles (
        candidate_id,
        voice_id,
        profile_name,
        sample_count,
        total_sample_duration_seconds,
        clone_quality_score,
        similarity_score,
        voice_features,
        sample_file_paths
    ) VALUES (
        p_candidate_id,
        p_voice_id,
        COALESCE(p_profile_name, 'Voice Profile - ' || p_candidate_id::TEXT),
        p_sample_count,
        p_sample_duration,
        p_clone_quality_score,
        p_similarity_score,
        p_voice_features,
        p_sample_paths
    )
    ON CONFLICT (voice_id) DO UPDATE SET
        sample_count = EXCLUDED.sample_count,
        total_sample_duration_seconds = EXCLUDED.total_sample_duration_seconds,
        clone_quality_score = COALESCE(EXCLUDED.clone_quality_score, ultra_voice_profiles.clone_quality_score),
        similarity_score = COALESCE(EXCLUDED.similarity_score, ultra_voice_profiles.similarity_score),
        voice_features = ultra_voice_profiles.voice_features || EXCLUDED.voice_features,
        sample_file_paths = ultra_voice_profiles.sample_file_paths || EXCLUDED.sample_file_paths,
        updated_at = NOW()
    RETURNING id INTO v_profile_id;
    
    RETURN v_profile_id;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Get voice profile for candidate
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_get_voice_profile(
    p_candidate_id UUID
) RETURNS TABLE (
    profile_id UUID,
    voice_id VARCHAR(255),
    profile_name VARCHAR(255),
    sample_count INTEGER,
    clone_quality_score DECIMAL(3,2),
    similarity_score DECIMAL(5,2),
    voice_features JSONB,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uvp.id,
        uvp.voice_id,
        uvp.profile_name,
        uvp.sample_count,
        uvp.clone_quality_score,
        uvp.similarity_score,
        uvp.voice_features,
        uvp.is_active
    FROM ultra_voice_profiles uvp
    WHERE uvp.candidate_id = p_candidate_id
    AND uvp.is_active = true
    ORDER BY uvp.is_primary DESC, uvp.clone_quality_score DESC NULLS LAST
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Get configuration value
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_get_config(
    p_key VARCHAR(100)
) RETURNS JSONB AS $$
DECLARE
    v_value JSONB;
BEGIN
    SELECT config_value INTO v_value
    FROM ultra_configuration
    WHERE config_key = p_key AND is_active = true;
    
    RETURN v_value;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Set configuration value with history
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_set_config(
    p_key VARCHAR(100),
    p_value JSONB,
    p_changed_by VARCHAR(255) DEFAULT 'system',
    p_change_source VARCHAR(50) DEFAULT 'api',
    p_change_reason TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_old_value JSONB;
    v_config_id UUID;
BEGIN
    -- Get current value
    SELECT id, config_value INTO v_config_id, v_old_value
    FROM ultra_configuration
    WHERE config_key = p_key;
    
    -- Update config
    UPDATE ultra_configuration
    SET config_value = p_value,
        updated_at = NOW(),
        updated_by = p_changed_by
    WHERE config_key = p_key;
    
    -- Log history
    INSERT INTO ultra_configuration_history (
        config_id,
        config_key,
        old_value,
        new_value,
        changed_by,
        change_source,
        change_reason
    ) VALUES (
        v_config_id,
        p_key,
        v_old_value,
        p_value,
        p_changed_by,
        p_change_source,
        p_change_reason
    );
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Toggle feature with optional timer
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_toggle_feature(
    p_feature VARCHAR(100),
    p_enabled BOOLEAN,
    p_timer_minutes INTEGER DEFAULT 0,
    p_changed_by VARCHAR(255) DEFAULT 'control_panel'
) RETURNS JSONB AS $$
DECLARE
    v_config_key VARCHAR(100);
    v_result JSONB;
BEGIN
    -- Map feature to config key
    v_config_key := p_feature || '_enabled';
    
    -- Update config
    PERFORM ultra_set_config(
        v_config_key,
        jsonb_build_object('value', p_enabled),
        p_changed_by,
        'control_panel',
        CASE WHEN p_timer_minutes > 0 
            THEN 'Toggled with ' || p_timer_minutes || ' minute timer'
            ELSE 'Manual toggle'
        END
    );
    
    -- Build result
    v_result := jsonb_build_object(
        'feature', p_feature,
        'enabled', p_enabled,
        'timer_minutes', p_timer_minutes,
        'timestamp', NOW()
    );
    
    -- Log trigger if this is a significant change
    INSERT INTO ultra_triggers (
        trigger_type,
        severity,
        trigger_data
    ) VALUES (
        'config_change',
        'info',
        v_result
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Get all configuration as JSON
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_get_all_config() 
RETURNS JSONB AS $$
DECLARE
    v_config JSONB := '{}';
BEGIN
    SELECT jsonb_object_agg(config_key, config_value->'value')
    INTO v_config
    FROM ultra_configuration
    WHERE is_active = true;
    
    RETURN v_config;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- QUALITY METRICS FUNCTIONS (E20 Brain)
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Record quality metrics
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_record_quality_metrics(
    p_request_id UUID,
    p_ecosystem ultra_ecosystem,
    p_engine ultra_engine,
    p_quality_tier ultra_quality_tier,
    p_overall_score DECIMAL(3,2),
    p_detailed_metrics JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
    v_metric_id UUID;
    v_elevenlabs_baseline DECIMAL(3,2) := 4.50;
BEGIN
    INSERT INTO ultra_quality_metrics (
        request_id,
        ecosystem,
        engine,
        quality_tier,
        overall_score,
        pesq_score,
        stoi_score,
        mos_predicted,
        snr_db,
        spectral_convergence,
        log_spectral_distance,
        mel_cepstral_distortion,
        pitch_accuracy,
        rhythm_score,
        naturalness_score,
        speaker_similarity,
        pre_enhancement_score,
        post_enhancement_score,
        pre_superres_score,
        post_superres_score,
        vs_elevenlabs_percent
    ) VALUES (
        p_request_id,
        p_ecosystem,
        p_engine,
        p_quality_tier,
        p_overall_score,
        (p_detailed_metrics->>'pesq_score')::DECIMAL,
        (p_detailed_metrics->>'stoi_score')::DECIMAL,
        (p_detailed_metrics->>'mos_predicted')::DECIMAL,
        (p_detailed_metrics->>'snr_db')::DECIMAL,
        (p_detailed_metrics->>'spectral_convergence')::DECIMAL,
        (p_detailed_metrics->>'log_spectral_distance')::DECIMAL,
        (p_detailed_metrics->>'mel_cepstral_distortion')::DECIMAL,
        (p_detailed_metrics->>'pitch_accuracy')::DECIMAL,
        (p_detailed_metrics->>'rhythm_score')::DECIMAL,
        (p_detailed_metrics->>'naturalness_score')::DECIMAL,
        (p_detailed_metrics->>'speaker_similarity')::DECIMAL,
        (p_detailed_metrics->>'pre_enhancement_score')::DECIMAL,
        (p_detailed_metrics->>'post_enhancement_score')::DECIMAL,
        (p_detailed_metrics->>'pre_superres_score')::DECIMAL,
        (p_detailed_metrics->>'post_superres_score')::DECIMAL,
        ROUND((p_overall_score / v_elevenlabs_baseline) * 100, 2)
    )
    RETURNING id INTO v_metric_id;
    
    RETURN v_metric_id;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Get engine recommendations based on ML analysis
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_get_engine_recommendations()
RETURNS JSONB AS $$
DECLARE
    v_recommendations JSONB := '{}';
BEGIN
    -- Find best engine for each use case based on historical performance
    WITH engine_stats AS (
        SELECT 
            engine,
            AVG(avg_quality_score) as avg_quality,
            AVG(avg_latency_ms) as avg_latency,
            SUM(successful_requests)::DECIMAL / NULLIF(SUM(total_requests), 0) * 100 as success_rate
        FROM ultra_engine_performance
        WHERE tracking_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY engine
    )
    SELECT jsonb_build_object(
        'highest_quality', (SELECT engine FROM engine_stats ORDER BY avg_quality DESC NULLS LAST LIMIT 1),
        'fastest', (SELECT engine FROM engine_stats ORDER BY avg_latency ASC NULLS LAST LIMIT 1),
        'most_reliable', (SELECT engine FROM engine_stats ORDER BY success_rate DESC NULLS LAST LIMIT 1),
        'best_cloning', 'xtts_v2',  -- Known best for cloning
        'best_emotional', 'bark',    -- Known best for emotion
        'analysis_period_days', 30,
        'generated_at', NOW()
    ) INTO v_recommendations;
    
    RETURN v_recommendations;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Get quality trends
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_get_quality_trends(
    p_days INTEGER DEFAULT 30
)
RETURNS JSONB AS $$
DECLARE
    v_trends JSONB;
BEGIN
    WITH daily_quality AS (
        SELECT 
            DATE(recorded_at) as date,
            AVG(overall_score) as avg_quality,
            COUNT(*) as request_count
        FROM ultra_quality_metrics
        WHERE recorded_at >= CURRENT_DATE - (p_days || ' days')::INTERVAL
        GROUP BY DATE(recorded_at)
        ORDER BY date
    ),
    stats AS (
        SELECT 
            AVG(overall_score) as overall_avg,
            MIN(overall_score) as overall_min,
            MAX(overall_score) as overall_max,
            COUNT(*) as total_count
        FROM ultra_quality_metrics
        WHERE recorded_at >= CURRENT_DATE - (p_days || ' days')::INTERVAL
    )
    SELECT jsonb_build_object(
        'period_days', p_days,
        'average_quality', (SELECT overall_avg FROM stats),
        'min_quality', (SELECT overall_min FROM stats),
        'max_quality', (SELECT overall_max FROM stats),
        'total_requests', (SELECT total_count FROM stats),
        'daily_data', (SELECT jsonb_agg(jsonb_build_object(
            'date', date,
            'avg_quality', ROUND(avg_quality::NUMERIC, 2),
            'count', request_count
        )) FROM daily_quality),
        'trend', CASE 
            WHEN (SELECT avg_quality FROM daily_quality ORDER BY date DESC LIMIT 1) > 
                 (SELECT avg_quality FROM daily_quality ORDER BY date ASC LIMIT 1)
            THEN 'improving'
            WHEN (SELECT avg_quality FROM daily_quality ORDER BY date DESC LIMIT 1) < 
                 (SELECT avg_quality FROM daily_quality ORDER BY date ASC LIMIT 1)
            THEN 'declining'
            ELSE 'stable'
        END,
        'generated_at', NOW()
    ) INTO v_trends;
    
    RETURN v_trends;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- COST TRACKING FUNCTIONS (E13 AI Hub)
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Get cost savings summary
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_get_cost_summary(
    p_days INTEGER DEFAULT 30
)
RETURNS JSONB AS $$
DECLARE
    v_summary JSONB;
BEGIN
    SELECT jsonb_build_object(
        'period_days', p_days,
        'total_requests', SUM(request_count),
        'total_characters', SUM(total_characters),
        'total_audio_seconds', SUM(total_audio_seconds),
        'elevenlabs_equivalent_cost', SUM(elevenlabs_equivalent_cost),
        'ultra_actual_cost', SUM(ultra_total_cost),
        'total_cost_saved', SUM(cost_saved),
        'savings_percentage', ROUND(
            (SUM(cost_saved) / NULLIF(SUM(elevenlabs_equivalent_cost), 0)) * 100, 2
        ),
        'avg_quality_score', ROUND(AVG(avg_quality_score)::NUMERIC, 2),
        'by_ecosystem', (
            SELECT jsonb_object_agg(
                ecosystem::TEXT,
                jsonb_build_object(
                    'requests', SUM(request_count),
                    'characters', SUM(total_characters),
                    'cost_saved', SUM(cost_saved)
                )
            )
            FROM ultra_cost_tracking
            WHERE tracking_date >= CURRENT_DATE - (p_days || ' days')::INTERVAL
            GROUP BY ecosystem
        ),
        'annual_projection', SUM(cost_saved) * (365.0 / p_days),
        'generated_at', NOW()
    ) INTO v_summary
    FROM ultra_cost_tracking
    WHERE tracking_date >= CURRENT_DATE - (p_days || ' days')::INTERVAL;
    
    RETURN v_summary;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- BATCH JOB FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Create batch job
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_create_batch_job(
    p_job_name VARCHAR(255),
    p_job_type VARCHAR(50),
    p_ecosystem ultra_ecosystem,
    p_items JSONB,  -- Array of {text, personalization}
    p_job_config JSONB DEFAULT '{}',
    p_campaign_id UUID DEFAULT NULL,
    p_candidate_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_job_id UUID;
    v_item JSONB;
    v_index INTEGER := 0;
BEGIN
    -- Create job
    INSERT INTO ultra_batch_jobs (
        job_name,
        job_type,
        ecosystem,
        total_items,
        job_config,
        campaign_id,
        candidate_id
    ) VALUES (
        p_job_name,
        p_job_type,
        p_ecosystem,
        jsonb_array_length(p_items),
        p_job_config,
        p_campaign_id,
        p_candidate_id
    )
    RETURNING id INTO v_job_id;
    
    -- Create job items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO ultra_batch_job_items (
            batch_job_id,
            item_index,
            input_text,
            personalization_data
        ) VALUES (
            v_job_id,
            v_index,
            v_item->>'text',
            COALESCE(v_item->'personalization', '{}')
        );
        v_index := v_index + 1;
    END LOOP;
    
    RETURN v_job_id;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Update batch job progress
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_update_batch_progress(
    p_job_id UUID,
    p_item_id UUID,
    p_status VARCHAR(20),
    p_request_id UUID DEFAULT NULL,
    p_output_path VARCHAR(500) DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    -- Update item
    UPDATE ultra_batch_job_items
    SET status = p_status,
        request_id = p_request_id,
        output_path = p_output_path,
        error_message = p_error_message,
        processed_at = NOW()
    WHERE id = p_item_id AND batch_job_id = p_job_id;
    
    -- Update job counts
    UPDATE ultra_batch_jobs
    SET completed_items = (
            SELECT COUNT(*) FROM ultra_batch_job_items 
            WHERE batch_job_id = p_job_id AND status = 'completed'
        ),
        failed_items = (
            SELECT COUNT(*) FROM ultra_batch_job_items 
            WHERE batch_job_id = p_job_id AND status = 'failed'
        ),
        status = CASE 
            WHEN (SELECT COUNT(*) FROM ultra_batch_job_items 
                  WHERE batch_job_id = p_job_id AND status = 'pending') = 0
            THEN 'completed'
            ELSE 'processing'
        END,
        completed_at = CASE 
            WHEN (SELECT COUNT(*) FROM ultra_batch_job_items 
                  WHERE batch_job_id = p_job_id AND status = 'pending') = 0
            THEN NOW()
            ELSE NULL
        END
    WHERE id = p_job_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- DASHBOARD / REPORTING FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Get dashboard stats
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_get_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
    v_stats JSONB;
BEGIN
    SELECT jsonb_build_object(
        'today', (
            SELECT jsonb_build_object(
                'requests', COUNT(*),
                'completed', COUNT(*) FILTER (WHERE status = 'completed'),
                'characters', SUM(input_text_length),
                'cost_saved', SUM(cost_saved),
                'avg_quality', ROUND(AVG(quality_score)::NUMERIC, 2)
            )
            FROM ultra_voice_requests
            WHERE DATE(created_at) = CURRENT_DATE
        ),
        'this_week', (
            SELECT jsonb_build_object(
                'requests', COUNT(*),
                'completed', COUNT(*) FILTER (WHERE status = 'completed'),
                'characters', SUM(input_text_length),
                'cost_saved', SUM(cost_saved),
                'avg_quality', ROUND(AVG(quality_score)::NUMERIC, 2)
            )
            FROM ultra_voice_requests
            WHERE created_at >= DATE_TRUNC('week', CURRENT_DATE)
        ),
        'this_month', (
            SELECT jsonb_build_object(
                'requests', COUNT(*),
                'completed', COUNT(*) FILTER (WHERE status = 'completed'),
                'characters', SUM(input_text_length),
                'cost_saved', SUM(cost_saved),
                'avg_quality', ROUND(AVG(quality_score)::NUMERIC, 2)
            )
            FROM ultra_voice_requests
            WHERE created_at >= DATE_TRUNC('month', CURRENT_DATE)
        ),
        'all_time', (
            SELECT jsonb_build_object(
                'requests', COUNT(*),
                'completed', COUNT(*) FILTER (WHERE status = 'completed'),
                'characters', SUM(input_text_length),
                'cost_saved', SUM(cost_saved),
                'avg_quality', ROUND(AVG(quality_score)::NUMERIC, 2)
            )
            FROM ultra_voice_requests
        ),
        'active_engines', (
            SELECT COUNT(DISTINCT engine) 
            FROM ultra_engine_performance 
            WHERE tracking_date = CURRENT_DATE AND total_requests > 0
        ),
        'active_ecosystems', (
            SELECT COUNT(DISTINCT ecosystem) 
            FROM ultra_voice_requests 
            WHERE DATE(created_at) = CURRENT_DATE
        ),
        'cache_stats', (
            SELECT jsonb_build_object(
                'total_entries', COUNT(*),
                'total_hits', SUM(hit_count),
                'hit_rate', ROUND(
                    (SUM(hit_count)::DECIMAL / NULLIF(COUNT(*), 0)) * 100, 2
                )
            )
            FROM ultra_audio_cache
            WHERE expires_at > NOW() OR expires_at IS NULL
        ),
        'recent_triggers', (
            SELECT jsonb_agg(jsonb_build_object(
                'type', trigger_type,
                'severity', severity,
                'triggered_at', triggered_at
            ) ORDER BY triggered_at DESC)
            FROM (
                SELECT trigger_type, severity, triggered_at
                FROM ultra_triggers
                WHERE triggered_at >= NOW() - INTERVAL '24 hours'
                ORDER BY triggered_at DESC
                LIMIT 10
            ) t
        ),
        'generated_at', NOW()
    ) INTO v_stats;
    
    RETURN v_stats;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Get ecosystem status
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_get_ecosystem_status()
RETURNS JSONB AS $$
DECLARE
    v_status JSONB;
BEGIN
    SELECT jsonb_object_agg(
        ecosystem::TEXT,
        jsonb_build_object(
            'enabled', (
                SELECT (config_value->>'value')::BOOLEAN 
                FROM ultra_configuration 
                WHERE config_key = ecosystem::TEXT || '_enabled'
            ),
            'today_requests', COUNT(*) FILTER (WHERE DATE(created_at) = CURRENT_DATE),
            'today_characters', SUM(input_text_length) FILTER (WHERE DATE(created_at) = CURRENT_DATE),
            'today_cost_saved', SUM(cost_saved) FILTER (WHERE DATE(created_at) = CURRENT_DATE),
            'avg_quality', ROUND(AVG(quality_score)::NUMERIC, 2),
            'last_request', MAX(created_at)
        )
    ) INTO v_status
    FROM ultra_voice_requests
    GROUP BY ecosystem;
    
    RETURN v_status;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- MAINTENANCE FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Clean up expired cache entries
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_cleanup_expired_cache()
RETURNS INTEGER AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM ultra_audio_cache
    WHERE expires_at < NOW();
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Archive old requests
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_archive_old_requests(
    p_days_to_keep INTEGER DEFAULT 90
) RETURNS INTEGER AS $$
DECLARE
    v_archived INTEGER;
BEGIN
    -- In a real implementation, would move to archive table
    -- For now, just return count of what would be archived
    SELECT COUNT(*) INTO v_archived
    FROM ultra_voice_requests
    WHERE created_at < CURRENT_DATE - (p_days_to_keep || ' days')::INTERVAL;
    
    RETURN v_archived;
END;
$$ LANGUAGE plpgsql;
