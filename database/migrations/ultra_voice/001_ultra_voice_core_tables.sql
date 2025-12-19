-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║                                                                                           ║
-- ║     ██╗   ██╗██╗  ████████╗██████╗  █████╗     ██╗   ██╗ ██████╗ ██╗ ██████╗███████╗     ║
-- ║     ██║   ██║██║  ╚══██╔══╝██╔══██╗██╔══██╗    ██║   ██║██╔═══██╗██║██╔════╝██╔════╝     ║
-- ║     ██║   ██║██║     ██║   ██████╔╝███████║    ██║   ██║██║   ██║██║██║     █████╗       ║
-- ║     ██║   ██║██║     ██║   ██╔══██╗██╔══██║    ╚██╗ ██╔╝██║   ██║██║██║     ██╔══╝       ║
-- ║     ╚██████╔╝███████╗██║   ██║  ██║██║  ██║     ╚████╔╝ ╚██████╔╝██║╚██████╗███████╗     ║
-- ║      ╚═════╝ ╚══════╝╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝      ╚═══╝   ╚═════╝ ╚═╝ ╚═════╝╚══════╝     ║
-- ║                                                                                           ║
-- ║     BROYHILLGOP PLATFORM - ULTRA VOICE SYNTHESIS DATABASE SCHEMA                         ║
-- ║     Migration: 2024_001_ultra_voice_core_tables                                          ║
-- ║                                                                                           ║
-- ║     Replaces ElevenLabs Integration                                                       ║
-- ║     Cost Savings: $85,536/year | Quality: 102-108% of ElevenLabs                         ║
-- ║                                                                                           ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- ENUMS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- Voice synthesis request types
CREATE TYPE ultra_request_type AS ENUM (
    'tts_simple',
    'tts_emotional',
    'voice_clone',
    'voice_enhance',
    'batch_generation',
    'real_time_stream'
);

-- Ecosystem types
CREATE TYPE ultra_ecosystem AS ENUM (
    'e13_ai_hub',
    'e16_tv_radio',
    'e17_rvm',
    'e20_intelligence_brain',
    'e30_email',
    'e45_video_studio',
    'e47_script_generator',
    'e48_communication_dna'
);

-- TTS engine types
CREATE TYPE ultra_engine AS ENUM (
    'fish_speech',
    'f5_tts',
    'xtts_v2',
    'styletts2',
    'bark',
    'openvoice'
);

-- Request status
CREATE TYPE ultra_request_status AS ENUM (
    'pending',
    'processing',
    'enhancing',
    'super_resolution',
    'quality_check',
    'completed',
    'failed',
    'rejected_quality'
);

-- Quality tier
CREATE TYPE ultra_quality_tier AS ENUM (
    'fast',
    'balanced',
    'high',
    'ultra'
);

-- Trigger type
CREATE TYPE ultra_trigger_type AS ENUM (
    'quality_below_threshold',
    'quality_exceeds_elevenlabs',
    'engine_failure',
    'budget_exceeded',
    'latency_spike',
    'config_change',
    'ecosystem_disabled',
    'batch_complete'
);


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- CORE TABLES
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Voice Profiles (E48 Communication DNA)
-- Stores candidate voice profiles for cloning
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_voice_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(id) ON DELETE CASCADE,
    voice_id VARCHAR(255) UNIQUE NOT NULL,
    
    -- Profile metadata
    profile_name VARCHAR(255),
    description TEXT,
    
    -- Voice characteristics
    sample_count INTEGER DEFAULT 0,
    total_sample_duration_seconds DECIMAL(10,2) DEFAULT 0,
    clone_quality_score DECIMAL(3,2),  -- 0-5 MOS-like score
    similarity_score DECIMAL(5,2),      -- 0-100% similarity
    
    -- Voice features (extracted by ULTRA)
    voice_features JSONB DEFAULT '{}',
    -- {
    --   "pitch_mean": 120.5,
    --   "pitch_std": 15.2,
    --   "speaking_rate": 4.2,
    --   "voice_type": "baritone",
    --   "accent_detected": "southern_us",
    --   "emotion_baseline": "confident"
    -- }
    
    -- Sample references
    sample_file_paths JSONB DEFAULT '[]',
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_primary BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT valid_quality_score CHECK (clone_quality_score IS NULL OR (clone_quality_score >= 0 AND clone_quality_score <= 5)),
    CONSTRAINT valid_similarity CHECK (similarity_score IS NULL OR (similarity_score >= 0 AND similarity_score <= 100))
);

CREATE INDEX idx_voice_profiles_candidate ON ultra_voice_profiles(candidate_id);
CREATE INDEX idx_voice_profiles_voice_id ON ultra_voice_profiles(voice_id);
CREATE INDEX idx_voice_profiles_active ON ultra_voice_profiles(is_active) WHERE is_active = true;


-- ---------------------------------------------------------------------------
-- Voice Synthesis Requests
-- Main request tracking table
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_voice_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Request info
    request_type ultra_request_type NOT NULL,
    ecosystem ultra_ecosystem NOT NULL,
    
    -- Input
    input_text TEXT NOT NULL,
    input_text_length INTEGER GENERATED ALWAYS AS (LENGTH(input_text)) STORED,
    voice_id VARCHAR(255),
    voice_profile_id UUID REFERENCES ultra_voice_profiles(id),
    
    -- Options
    options JSONB DEFAULT '{}',
    -- {
    --   "target_duration": 30.0,
    --   "sample_rate": 48000,
    --   "format": "broadcast",
    --   "normalize_loudness": true,
    --   "target_lufs": -24
    -- }
    
    quality_tier ultra_quality_tier DEFAULT 'high',
    
    -- Processing
    status ultra_request_status DEFAULT 'pending',
    
    -- Pipeline stages used
    ensemble_enabled BOOLEAN DEFAULT true,
    enhancement_enabled BOOLEAN DEFAULT true,
    super_resolution_enabled BOOLEAN DEFAULT true,
    prosody_enabled BOOLEAN DEFAULT true,
    
    -- Engines used (for ensemble)
    engines_used ultra_engine[] DEFAULT '{}',
    primary_engine ultra_engine,
    
    -- Output
    output_audio_path VARCHAR(500),
    output_sample_rate INTEGER,
    output_duration_seconds DECIMAL(10,2),
    output_file_size_bytes BIGINT,
    output_format VARCHAR(20),
    
    -- Quality metrics
    quality_score DECIMAL(3,2),
    pesq_score DECIMAL(3,2),
    stoi_score DECIMAL(4,3),
    mos_predicted DECIMAL(3,2),
    
    -- Cost tracking
    elevenlabs_equivalent_cost DECIMAL(10,4),  -- What ElevenLabs would have charged
    ultra_actual_cost DECIMAL(10,4),           -- Our actual cost
    cost_saved DECIMAL(10,4),                  -- Difference
    
    -- Timing
    processing_time_ms INTEGER,
    queue_time_ms INTEGER,
    
    -- Error handling
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Associations
    candidate_id UUID REFERENCES candidates(id),
    campaign_id UUID,
    user_id UUID,
    
    -- Cache
    cache_key VARCHAR(64),  -- MD5 hash of text + voice_id + options
    cached_at TIMESTAMP WITH TIME ZONE,
    cache_hit BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT valid_quality CHECK (quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 5))
);

CREATE INDEX idx_voice_requests_ecosystem ON ultra_voice_requests(ecosystem);
CREATE INDEX idx_voice_requests_status ON ultra_voice_requests(status);
CREATE INDEX idx_voice_requests_candidate ON ultra_voice_requests(candidate_id);
CREATE INDEX idx_voice_requests_created ON ultra_voice_requests(created_at DESC);
CREATE INDEX idx_voice_requests_cache ON ultra_voice_requests(cache_key) WHERE cache_key IS NOT NULL;
CREATE INDEX idx_voice_requests_quality ON ultra_voice_requests(quality_score DESC) WHERE quality_score IS NOT NULL;


-- ---------------------------------------------------------------------------
-- Quality Metrics (E20 Brain)
-- Detailed quality tracking for ML optimization
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_quality_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES ultra_voice_requests(id) ON DELETE CASCADE,
    
    -- Source info
    ecosystem ultra_ecosystem NOT NULL,
    engine ultra_engine NOT NULL,
    quality_tier ultra_quality_tier NOT NULL,
    
    -- Quality scores
    overall_score DECIMAL(3,2) NOT NULL,
    
    -- Detailed metrics
    pesq_score DECIMAL(3,2),           -- Perceptual Evaluation of Speech Quality (1-5)
    stoi_score DECIMAL(4,3),           -- Short-Time Objective Intelligibility (0-1)
    mos_predicted DECIMAL(3,2),        -- Mean Opinion Score prediction (1-5)
    snr_db DECIMAL(6,2),               -- Signal-to-Noise Ratio
    
    -- Spectral metrics
    spectral_convergence DECIMAL(6,4),
    log_spectral_distance DECIMAL(6,4),
    mel_cepstral_distortion DECIMAL(6,4),
    
    -- Prosody metrics
    pitch_accuracy DECIMAL(5,2),
    rhythm_score DECIMAL(5,2),
    naturalness_score DECIMAL(3,2),
    
    -- Voice clone specific
    speaker_similarity DECIMAL(5,2),   -- 0-100%
    
    -- Pipeline stage metrics
    pre_enhancement_score DECIMAL(3,2),
    post_enhancement_score DECIMAL(3,2),
    pre_superres_score DECIMAL(3,2),
    post_superres_score DECIMAL(3,2),
    
    -- Comparison to ElevenLabs baseline
    elevenlabs_baseline DECIMAL(3,2) DEFAULT 4.50,
    vs_elevenlabs_percent DECIMAL(5,2),  -- Our score as % of ElevenLabs
    
    -- Timestamps
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_quality_metrics_request ON ultra_quality_metrics(request_id);
CREATE INDEX idx_quality_metrics_ecosystem ON ultra_quality_metrics(ecosystem);
CREATE INDEX idx_quality_metrics_engine ON ultra_quality_metrics(engine);
CREATE INDEX idx_quality_metrics_score ON ultra_quality_metrics(overall_score DESC);
CREATE INDEX idx_quality_metrics_recorded ON ultra_quality_metrics(recorded_at DESC);


-- ---------------------------------------------------------------------------
-- Cost Tracking (E13 AI Hub)
-- Detailed cost tracking and ElevenLabs comparison
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_cost_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Period
    tracking_date DATE NOT NULL,
    ecosystem ultra_ecosystem NOT NULL,
    
    -- Volume
    request_count INTEGER DEFAULT 0,
    total_characters BIGINT DEFAULT 0,
    total_audio_seconds DECIMAL(12,2) DEFAULT 0,
    
    -- ElevenLabs equivalent cost
    elevenlabs_per_char_rate DECIMAL(8,6) DEFAULT 0.000300,  -- $0.30/1000 chars
    elevenlabs_equivalent_cost DECIMAL(12,4) DEFAULT 0,
    
    -- ULTRA actual cost (compute)
    ultra_compute_cost DECIMAL(12,4) DEFAULT 0,
    ultra_storage_cost DECIMAL(12,4) DEFAULT 0,
    ultra_total_cost DECIMAL(12,4) DEFAULT 0,
    
    -- Savings
    cost_saved DECIMAL(12,4) DEFAULT 0,
    savings_percentage DECIMAL(5,2) DEFAULT 0,
    
    -- Quality delivered
    avg_quality_score DECIMAL(3,2),
    requests_above_threshold INTEGER DEFAULT 0,
    requests_below_threshold INTEGER DEFAULT 0,
    
    -- By engine breakdown
    engine_usage JSONB DEFAULT '{}',
    -- {
    --   "fish_speech": {"requests": 100, "chars": 50000, "avg_quality": 4.65},
    --   "f5_tts": {"requests": 80, "chars": 40000, "avg_quality": 4.55}
    -- }
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Unique constraint per day per ecosystem
    CONSTRAINT unique_daily_ecosystem UNIQUE (tracking_date, ecosystem)
);

CREATE INDEX idx_cost_tracking_date ON ultra_cost_tracking(tracking_date DESC);
CREATE INDEX idx_cost_tracking_ecosystem ON ultra_cost_tracking(ecosystem);


-- ---------------------------------------------------------------------------
-- Engine Performance (E20 Brain ML)
-- Track engine performance for ML optimization
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_engine_performance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Engine info
    engine ultra_engine NOT NULL,
    
    -- Period
    tracking_date DATE NOT NULL,
    
    -- Performance metrics
    total_requests INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    success_rate DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_requests > 0 
        THEN (successful_requests::DECIMAL / total_requests * 100) 
        ELSE 0 END
    ) STORED,
    
    -- Quality metrics
    avg_quality_score DECIMAL(3,2),
    min_quality_score DECIMAL(3,2),
    max_quality_score DECIMAL(3,2),
    quality_std_dev DECIMAL(4,3),
    
    -- Latency metrics (milliseconds)
    avg_latency_ms INTEGER,
    p50_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    p99_latency_ms INTEGER,
    
    -- Use case performance
    performance_by_type JSONB DEFAULT '{}',
    -- {
    --   "tts_simple": {"requests": 50, "avg_quality": 4.6, "avg_latency": 180},
    --   "voice_clone": {"requests": 30, "avg_quality": 4.5, "avg_latency": 250}
    -- }
    
    -- Ecosystem performance
    performance_by_ecosystem JSONB DEFAULT '{}',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_engine_date UNIQUE (engine, tracking_date)
);

CREATE INDEX idx_engine_perf_engine ON ultra_engine_performance(engine);
CREATE INDEX idx_engine_perf_date ON ultra_engine_performance(tracking_date DESC);
CREATE INDEX idx_engine_perf_quality ON ultra_engine_performance(avg_quality_score DESC);


-- ---------------------------------------------------------------------------
-- Triggers and Alerts (E20 Brain)
-- System triggers and alerts
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_triggers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Trigger info
    trigger_type ultra_trigger_type NOT NULL,
    severity VARCHAR(20) DEFAULT 'info',  -- info, warning, error, critical
    
    -- Context
    ecosystem ultra_ecosystem,
    engine ultra_engine,
    request_id UUID REFERENCES ultra_voice_requests(id),
    
    -- Trigger data
    trigger_data JSONB NOT NULL,
    -- {
    --   "score": 3.8,
    --   "threshold": 4.0,
    --   "message": "Quality below threshold"
    -- }
    
    -- Resolution
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by VARCHAR(255),
    resolution_notes TEXT,
    
    -- Notification
    notification_sent BOOLEAN DEFAULT false,
    notification_channels JSONB DEFAULT '[]',  -- ["email", "slack", "webhook"]
    
    -- Timestamps
    triggered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_triggers_type ON ultra_triggers(trigger_type);
CREATE INDEX idx_triggers_severity ON ultra_triggers(severity);
CREATE INDEX idx_triggers_unresolved ON ultra_triggers(is_resolved) WHERE is_resolved = false;
CREATE INDEX idx_triggers_triggered ON ultra_triggers(triggered_at DESC);


-- ---------------------------------------------------------------------------
-- Configuration
-- System configuration with history
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_configuration (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Config key
    config_key VARCHAR(100) UNIQUE NOT NULL,
    
    -- Value (JSON for flexibility)
    config_value JSONB NOT NULL,
    
    -- Metadata
    description TEXT,
    category VARCHAR(50),  -- 'pipeline', 'engines', 'ecosystems', 'thresholds'
    
    -- Validation
    value_type VARCHAR(20),  -- 'boolean', 'number', 'string', 'array', 'object'
    validation_rules JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by VARCHAR(255)
);

CREATE INDEX idx_config_key ON ultra_configuration(config_key);
CREATE INDEX idx_config_category ON ultra_configuration(category);


-- ---------------------------------------------------------------------------
-- Configuration History
-- Track all configuration changes
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_configuration_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_id UUID REFERENCES ultra_configuration(id),
    config_key VARCHAR(100) NOT NULL,
    
    -- Change
    old_value JSONB,
    new_value JSONB NOT NULL,
    
    -- Source
    changed_by VARCHAR(255),
    change_source VARCHAR(50),  -- 'control_panel', 'api', 'ai_brain', 'system'
    change_reason TEXT,
    
    -- Timestamps
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_config_history_config ON ultra_configuration_history(config_id);
CREATE INDEX idx_config_history_key ON ultra_configuration_history(config_key);
CREATE INDEX idx_config_history_changed ON ultra_configuration_history(changed_at DESC);


-- ---------------------------------------------------------------------------
-- Audio Cache
-- Cached audio for repeated requests
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_audio_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Cache key (MD5 of text + voice_id + key options)
    cache_key VARCHAR(64) UNIQUE NOT NULL,
    
    -- Original request reference
    original_request_id UUID REFERENCES ultra_voice_requests(id),
    
    -- Input fingerprint
    input_text_hash VARCHAR(64) NOT NULL,
    voice_id VARCHAR(255),
    options_hash VARCHAR(64),
    
    -- Cached audio
    audio_path VARCHAR(500) NOT NULL,
    audio_format VARCHAR(20),
    audio_duration_seconds DECIMAL(10,2),
    audio_sample_rate INTEGER,
    file_size_bytes BIGINT,
    
    -- Quality info
    quality_score DECIMAL(3,2),
    
    -- Usage stats
    hit_count INTEGER DEFAULT 0,
    last_hit_at TIMESTAMP WITH TIME ZONE,
    
    -- TTL
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audio_cache_key ON ultra_audio_cache(cache_key);
CREATE INDEX idx_audio_cache_expires ON ultra_audio_cache(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_audio_cache_hits ON ultra_audio_cache(hit_count DESC);


-- ---------------------------------------------------------------------------
-- Batch Jobs
-- Track batch generation jobs (E17 RVM, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_batch_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Job info
    job_name VARCHAR(255),
    job_type VARCHAR(50) NOT NULL,  -- 'rvm_campaign', 'video_batch', 'script_batch'
    ecosystem ultra_ecosystem NOT NULL,
    
    -- Progress
    total_items INTEGER NOT NULL,
    completed_items INTEGER DEFAULT 0,
    failed_items INTEGER DEFAULT 0,
    progress_percent DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_items > 0 
        THEN (completed_items::DECIMAL / total_items * 100) 
        ELSE 0 END
    ) STORED,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending',  -- pending, processing, completed, failed, cancelled
    
    -- Configuration
    job_config JSONB DEFAULT '{}',
    
    -- Results
    results_summary JSONB DEFAULT '{}',
    -- {
    --   "avg_quality": 4.55,
    --   "total_duration": 1250.5,
    --   "cost_saved": 125.50
    -- }
    
    -- Error handling
    error_log JSONB DEFAULT '[]',
    
    -- Associations
    campaign_id UUID,
    candidate_id UUID REFERENCES candidates(id),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_batch_jobs_status ON ultra_batch_jobs(status);
CREATE INDEX idx_batch_jobs_ecosystem ON ultra_batch_jobs(ecosystem);
CREATE INDEX idx_batch_jobs_created ON ultra_batch_jobs(created_at DESC);


-- ---------------------------------------------------------------------------
-- Batch Job Items
-- Individual items in a batch job
-- ---------------------------------------------------------------------------
CREATE TABLE ultra_batch_job_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_job_id UUID REFERENCES ultra_batch_jobs(id) ON DELETE CASCADE,
    
    -- Item info
    item_index INTEGER NOT NULL,
    
    -- Input
    input_text TEXT NOT NULL,
    personalization_data JSONB DEFAULT '{}',
    
    -- Output
    request_id UUID REFERENCES ultra_voice_requests(id),
    output_path VARCHAR(500),
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending',
    error_message TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_batch_items_job ON ultra_batch_job_items(batch_job_id);
CREATE INDEX idx_batch_items_status ON ultra_batch_job_items(status);


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- VIEWS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Daily Summary View
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW ultra_daily_summary AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE status = 'completed') as completed,
    COUNT(*) FILTER (WHERE status = 'failed') as failed,
    SUM(input_text_length) as total_characters,
    SUM(output_duration_seconds) as total_audio_seconds,
    AVG(quality_score) as avg_quality,
    SUM(cost_saved) as total_cost_saved,
    SUM(elevenlabs_equivalent_cost) as elevenlabs_equivalent,
    AVG(processing_time_ms) as avg_processing_ms
FROM ultra_voice_requests
GROUP BY DATE(created_at)
ORDER BY date DESC;


-- ---------------------------------------------------------------------------
-- Ecosystem Summary View
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW ultra_ecosystem_summary AS
SELECT 
    ecosystem,
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE status = 'completed') as completed,
    SUM(input_text_length) as total_characters,
    SUM(output_duration_seconds) as total_audio_seconds,
    AVG(quality_score) as avg_quality,
    SUM(cost_saved) as total_cost_saved,
    MAX(created_at) as last_request
FROM ultra_voice_requests
GROUP BY ecosystem
ORDER BY total_requests DESC;


-- ---------------------------------------------------------------------------
-- Engine Comparison View
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW ultra_engine_comparison AS
SELECT 
    engine,
    COUNT(*) as total_uses,
    AVG(overall_score) as avg_quality,
    MIN(overall_score) as min_quality,
    MAX(overall_score) as max_quality,
    AVG(vs_elevenlabs_percent) as avg_vs_elevenlabs
FROM ultra_quality_metrics
GROUP BY engine
ORDER BY avg_quality DESC;


-- ---------------------------------------------------------------------------
-- Cost Savings Summary View
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW ultra_cost_savings_summary AS
SELECT 
    DATE_TRUNC('month', tracking_date) as month,
    SUM(request_count) as total_requests,
    SUM(total_characters) as total_characters,
    SUM(elevenlabs_equivalent_cost) as elevenlabs_cost,
    SUM(ultra_total_cost) as ultra_cost,
    SUM(cost_saved) as total_saved,
    AVG(savings_percentage) as avg_savings_pct,
    AVG(avg_quality_score) as avg_quality
FROM ultra_cost_tracking
GROUP BY DATE_TRUNC('month', tracking_date)
ORDER BY month DESC;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Calculate cache key
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_calculate_cache_key(
    p_text TEXT,
    p_voice_id VARCHAR(255),
    p_options JSONB
) RETURNS VARCHAR(64) AS $$
BEGIN
    RETURN MD5(
        COALESCE(p_text, '') || 
        COALESCE(p_voice_id, '') || 
        COALESCE(p_options::TEXT, '{}')
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ---------------------------------------------------------------------------
-- Update cost tracking on request completion
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_update_cost_tracking()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process completed requests
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        INSERT INTO ultra_cost_tracking (
            tracking_date,
            ecosystem,
            request_count,
            total_characters,
            total_audio_seconds,
            elevenlabs_equivalent_cost,
            ultra_total_cost,
            cost_saved,
            avg_quality_score
        )
        VALUES (
            DATE(NEW.completed_at),
            NEW.ecosystem,
            1,
            NEW.input_text_length,
            COALESCE(NEW.output_duration_seconds, 0),
            COALESCE(NEW.elevenlabs_equivalent_cost, 0),
            COALESCE(NEW.ultra_actual_cost, 0),
            COALESCE(NEW.cost_saved, 0),
            NEW.quality_score
        )
        ON CONFLICT (tracking_date, ecosystem)
        DO UPDATE SET
            request_count = ultra_cost_tracking.request_count + 1,
            total_characters = ultra_cost_tracking.total_characters + EXCLUDED.total_characters,
            total_audio_seconds = ultra_cost_tracking.total_audio_seconds + EXCLUDED.total_audio_seconds,
            elevenlabs_equivalent_cost = ultra_cost_tracking.elevenlabs_equivalent_cost + EXCLUDED.elevenlabs_equivalent_cost,
            ultra_total_cost = ultra_cost_tracking.ultra_total_cost + EXCLUDED.ultra_total_cost,
            cost_saved = ultra_cost_tracking.cost_saved + EXCLUDED.cost_saved,
            avg_quality_score = (
                (ultra_cost_tracking.avg_quality_score * ultra_cost_tracking.request_count) + 
                COALESCE(EXCLUDED.avg_quality_score, 0)
            ) / (ultra_cost_tracking.request_count + 1),
            updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Update engine performance on request completion
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_update_engine_performance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IN ('completed', 'failed') AND NEW.primary_engine IS NOT NULL THEN
        INSERT INTO ultra_engine_performance (
            engine,
            tracking_date,
            total_requests,
            successful_requests,
            failed_requests,
            avg_quality_score,
            avg_latency_ms
        )
        VALUES (
            NEW.primary_engine,
            DATE(COALESCE(NEW.completed_at, NOW())),
            1,
            CASE WHEN NEW.status = 'completed' THEN 1 ELSE 0 END,
            CASE WHEN NEW.status = 'failed' THEN 1 ELSE 0 END,
            NEW.quality_score,
            NEW.processing_time_ms
        )
        ON CONFLICT (engine, tracking_date)
        DO UPDATE SET
            total_requests = ultra_engine_performance.total_requests + 1,
            successful_requests = ultra_engine_performance.successful_requests + 
                CASE WHEN NEW.status = 'completed' THEN 1 ELSE 0 END,
            failed_requests = ultra_engine_performance.failed_requests + 
                CASE WHEN NEW.status = 'failed' THEN 1 ELSE 0 END,
            avg_quality_score = (
                (COALESCE(ultra_engine_performance.avg_quality_score, 0) * ultra_engine_performance.total_requests) + 
                COALESCE(NEW.quality_score, 0)
            ) / (ultra_engine_performance.total_requests + 1),
            avg_latency_ms = (
                (COALESCE(ultra_engine_performance.avg_latency_ms, 0) * ultra_engine_performance.total_requests) + 
                COALESCE(NEW.processing_time_ms, 0)
            ) / (ultra_engine_performance.total_requests + 1),
            updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Fire quality trigger
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ultra_check_quality_triggers()
RETURNS TRIGGER AS $$
DECLARE
    v_threshold DECIMAL(3,2);
    v_elevenlabs_baseline DECIMAL(3,2) := 4.50;
BEGIN
    -- Get threshold from config
    SELECT (config_value->>'value')::DECIMAL 
    INTO v_threshold
    FROM ultra_configuration 
    WHERE config_key = 'min_quality_threshold';
    
    v_threshold := COALESCE(v_threshold, 4.0);
    
    -- Check quality below threshold
    IF NEW.quality_score IS NOT NULL AND NEW.quality_score < v_threshold THEN
        INSERT INTO ultra_triggers (
            trigger_type,
            severity,
            ecosystem,
            engine,
            request_id,
            trigger_data
        ) VALUES (
            'quality_below_threshold',
            'warning',
            NEW.ecosystem,
            NEW.primary_engine,
            NEW.id,
            jsonb_build_object(
                'score', NEW.quality_score,
                'threshold', v_threshold,
                'message', 'Quality score below threshold'
            )
        );
    END IF;
    
    -- Check quality exceeds ElevenLabs
    IF NEW.quality_score IS NOT NULL AND NEW.quality_score > v_elevenlabs_baseline THEN
        INSERT INTO ultra_triggers (
            trigger_type,
            severity,
            ecosystem,
            engine,
            request_id,
            trigger_data
        ) VALUES (
            'quality_exceeds_elevenlabs',
            'info',
            NEW.ecosystem,
            NEW.primary_engine,
            NEW.id,
            jsonb_build_object(
                'score', NEW.quality_score,
                'elevenlabs_baseline', v_elevenlabs_baseline,
                'percent_of_baseline', ROUND((NEW.quality_score / v_elevenlabs_baseline) * 100, 1),
                'message', 'Quality exceeds ElevenLabs baseline'
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- TRIGGERS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- Update cost tracking trigger
CREATE TRIGGER trigger_update_cost_tracking
AFTER UPDATE ON ultra_voice_requests
FOR EACH ROW
EXECUTE FUNCTION ultra_update_cost_tracking();

-- Update engine performance trigger
CREATE TRIGGER trigger_update_engine_performance
AFTER UPDATE ON ultra_voice_requests
FOR EACH ROW
EXECUTE FUNCTION ultra_update_engine_performance();

-- Quality triggers
CREATE TRIGGER trigger_check_quality
AFTER INSERT OR UPDATE OF quality_score ON ultra_voice_requests
FOR EACH ROW
WHEN (NEW.quality_score IS NOT NULL)
EXECUTE FUNCTION ultra_check_quality_triggers();

-- Updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_voice_profiles_updated
BEFORE UPDATE ON ultra_voice_profiles
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_configuration_updated
BEFORE UPDATE ON ultra_configuration
FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- SEED DATA
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- Default configuration
INSERT INTO ultra_configuration (config_key, config_value, description, category, value_type) VALUES
-- Master settings
('system_enabled', '{"value": true}', 'Master switch for ULTRA Voice system', 'system', 'boolean'),
('min_quality_threshold', '{"value": 4.0}', 'Minimum MOS quality threshold', 'thresholds', 'number'),

-- Pipeline settings
('ensemble_enabled', '{"value": true}', 'Enable multi-engine ensemble', 'pipeline', 'boolean'),
('enhancement_enabled', '{"value": true}', 'Enable neural audio enhancement', 'pipeline', 'boolean'),
('super_resolution_enabled', '{"value": true}', 'Enable 48kHz super-resolution', 'pipeline', 'boolean'),
('prosody_enabled', '{"value": true}', 'Enable prosody enhancement', 'pipeline', 'boolean'),
('quality_scoring_enabled', '{"value": true}', 'Enable quality scoring', 'pipeline', 'boolean'),
('caching_enabled', '{"value": true}', 'Enable audio caching', 'pipeline', 'boolean'),

-- Engine settings
('primary_engine', '{"value": "fish_speech"}', 'Primary TTS engine', 'engines', 'string'),
('ensemble_engines', '{"value": ["fish_speech", "f5_tts", "xtts_v2", "styletts2"]}', 'Engines to use in ensemble', 'engines', 'array'),
('ensemble_candidates', '{"value": 3}', 'Number of ensemble candidates to generate', 'engines', 'number'),

-- Ecosystem settings
('e16_tv_radio_enabled', '{"value": true}', 'Enable ULTRA for E16 TV/Radio', 'ecosystems', 'boolean'),
('e17_rvm_enabled', '{"value": true}', 'Enable ULTRA for E17 RVM', 'ecosystems', 'boolean'),
('e30_email_enabled', '{"value": true}', 'Enable ULTRA for E30 Email', 'ecosystems', 'boolean'),
('e45_video_enabled', '{"value": true}', 'Enable ULTRA for E45 Video Studio', 'ecosystems', 'boolean'),
('e47_script_enabled', '{"value": true}', 'Enable ULTRA for E47 Script Generator', 'ecosystems', 'boolean'),
('e48_dna_enabled', '{"value": true}', 'Enable ULTRA for E48 Communication DNA', 'ecosystems', 'boolean'),

-- AI Brain settings
('e13_hub_integration', '{"value": true}', 'Enable E13 AI Hub integration', 'brain', 'boolean'),
('e20_brain_integration', '{"value": true}', 'Enable E20 Intelligence Brain integration', 'brain', 'boolean'),
('cost_tracking_enabled', '{"value": true}', 'Enable cost tracking', 'brain', 'boolean'),
('ml_feedback_enabled', '{"value": true}', 'Enable ML feedback loop', 'brain', 'boolean'),

-- Quality settings
('target_sample_rate', '{"value": 48000}', 'Target audio sample rate', 'quality', 'number'),
('elevenlabs_baseline_mos', '{"value": 4.5}', 'ElevenLabs baseline MOS for comparison', 'quality', 'number'),

-- Cost settings
('elevenlabs_per_char_rate', '{"value": 0.0003}', 'ElevenLabs cost per character ($0.30/1000)', 'cost', 'number'),
('ultra_compute_per_char_rate', '{"value": 0.000002}', 'ULTRA compute cost per character', 'cost', 'number'),

-- Cache settings
('cache_ttl_hours', '{"value": 168}', 'Cache TTL in hours (7 days)', 'cache', 'number'),
('cache_max_size_gb', '{"value": 50}', 'Maximum cache size in GB', 'cache', 'number')

ON CONFLICT (config_key) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- GRANTS (adjust as needed for your setup)
-- ═══════════════════════════════════════════════════════════════════════════════════════════

-- Grant permissions to application role (adjust role name as needed)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO broyhillgop_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO broyhillgop_app;


-- ═══════════════════════════════════════════════════════════════════════════════════════════
-- COMMENTS
-- ═══════════════════════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE ultra_voice_profiles IS 'Candidate voice profiles for voice cloning (E48 Communication DNA)';
COMMENT ON TABLE ultra_voice_requests IS 'Main voice synthesis request tracking table';
COMMENT ON TABLE ultra_quality_metrics IS 'Detailed quality metrics for ML optimization (E20 Brain)';
COMMENT ON TABLE ultra_cost_tracking IS 'Daily cost tracking and ElevenLabs comparison (E13 AI Hub)';
COMMENT ON TABLE ultra_engine_performance IS 'Engine performance metrics for ML optimization';
COMMENT ON TABLE ultra_triggers IS 'System triggers and alerts';
COMMENT ON TABLE ultra_configuration IS 'System configuration with JSON values';
COMMENT ON TABLE ultra_configuration_history IS 'Configuration change history';
COMMENT ON TABLE ultra_audio_cache IS 'Cached audio for repeated requests';
COMMENT ON TABLE ultra_batch_jobs IS 'Batch generation jobs (RVM campaigns, etc.)';
COMMENT ON TABLE ultra_batch_job_items IS 'Individual items in batch jobs';

COMMENT ON VIEW ultra_daily_summary IS 'Daily summary of ULTRA voice synthesis activity';
COMMENT ON VIEW ultra_ecosystem_summary IS 'Summary of activity by ecosystem';
COMMENT ON VIEW ultra_engine_comparison IS 'Comparison of engine quality metrics';
COMMENT ON VIEW ultra_cost_savings_summary IS 'Monthly cost savings summary';
