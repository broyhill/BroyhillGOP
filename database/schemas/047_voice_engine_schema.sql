-- E47 Voice Engine Schema - 7 Tables
-- BroyhillGOP Platform v3.0

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Voice Profiles
CREATE TABLE IF NOT EXISTS voice_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    reference_audio_url TEXT,
    reference_youtube_url TEXT,
    candidate_id UUID,
    default_emotion VARCHAR(50) DEFAULT 'neutral',
    usage_count INTEGER DEFAULT 0,
    average_quality_score DECIMAL(5,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Voice Requests
CREATE TABLE IF NOT EXISTS voice_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    text TEXT NOT NULL,
    text_hash VARCHAR(64) NOT NULL,
    voice_profile_id UUID REFERENCES voice_profiles(id),
    emotion VARCHAR(50) DEFAULT 'neutral',
    min_quality_score DECIMAL(5,2) DEFAULT 95,
    status VARCHAR(50) DEFAULT 'pending',
    campaign_id UUID,
    candidate_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Voice Results
CREATE TABLE IF NOT EXISTS voice_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES voice_requests(id) ON DELETE CASCADE,
    audio_url TEXT,
    duration_seconds DECIMAL(10,2),
    file_size_bytes BIGINT,
    overall_quality DECIMAL(5,2),
    intelligibility_score DECIMAL(5,2),
    voice_similarity DECIMAL(5,2),
    emotion_accuracy DECIMAL(5,2),
    prosody_score DECIMAL(5,2),
    technical_score DECIMAL(5,2),
    word_error_rate DECIMAL(5,4),
    snr_db DECIMAL(6,2),
    lufs DECIMAL(6,2),
    calm_compliant BOOLEAN,
    model_used VARCHAR(50),
    attempts INTEGER DEFAULT 1,
    quality_grade VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Voice Quality Logs
CREATE TABLE IF NOT EXISTS voice_quality_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    result_id UUID NOT NULL REFERENCES voice_results(id) ON DELETE CASCADE,
    request_id UUID NOT NULL REFERENCES voice_requests(id) ON DELETE CASCADE,
    transcribed_text TEXT,
    original_text TEXT,
    word_error_rate DECIMAL(5,4),
    target_emotion VARCHAR(50),
    detected_emotion VARCHAR(50),
    emotion_confidence DECIMAL(5,4),
    pitch_cv DECIMAL(5,4),
    speech_rate_wpm DECIMAL(6,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RVM Campaigns
CREATE TABLE IF NOT EXISTS rvm_campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    voice_result_id UUID REFERENCES voice_results(id),
    audio_url TEXT NOT NULL,
    caller_id VARCHAR(20) NOT NULL,
    total_recipients INTEGER NOT NULL DEFAULT 0,
    provider VARCHAR(50) DEFAULT 'dropcowboy',
    provider_campaign_id VARCHAR(255),
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    listened_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    cost_per_drop DECIMAL(8,4) DEFAULT 0.004,
    estimated_cost DECIMAL(12,2),
    actual_cost DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'draft',
    candidate_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- RVM Deliveries
CREATE TABLE IF NOT EXISTS rvm_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES rvm_campaigns(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    donor_id UUID,
    provider VARCHAR(50) NOT NULL,
    provider_delivery_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending',
    cost DECIMAL(8,4),
    delivered_at TIMESTAMPTZ,
    listened_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Voice Usage Stats
CREATE TABLE IF NOT EXISTS voice_usage_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stat_date DATE NOT NULL UNIQUE,
    total_requests INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    perfect_scores INTEGER DEFAULT 0,
    average_quality DECIMAL(5,2),
    total_audio_seconds DECIMAL(12,2) DEFAULT 0,
    rvm_total_sent INTEGER DEFAULT 0,
    rvm_total_delivered INTEGER DEFAULT 0,
    rvm_total_cost DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_voice_profiles_candidate ON voice_profiles(candidate_id);
CREATE INDEX IF NOT EXISTS idx_voice_requests_status ON voice_requests(status);
CREATE INDEX IF NOT EXISTS idx_voice_results_quality ON voice_results(overall_quality DESC);
CREATE INDEX IF NOT EXISTS idx_rvm_campaigns_status ON rvm_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_rvm_deliveries_campaign ON rvm_deliveries(campaign_id);
CREATE INDEX IF NOT EXISTS idx_rvm_deliveries_status ON rvm_deliveries(status);
