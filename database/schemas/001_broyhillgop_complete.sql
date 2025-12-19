-- ============================================================================
-- BROYHILLGOP COMPLETE PLATFORM - SUPABASE MIGRATION
-- December 17, 2025
-- 
-- This single migration deploys the complete 45-ecosystem platform
-- Run this in your Supabase SQL Editor or via migration
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- CORE SCHEMA: CANDIDATES
-- ============================================================================
CREATE TABLE IF NOT EXISTS candidates (
    candidate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    office VARCHAR(255),
    district VARCHAR(100),
    county VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    party VARCHAR(50) DEFAULT 'Republican',
    status VARCHAR(50) DEFAULT 'active',
    campaign_committee VARCHAR(255),
    fec_id VARCHAR(20),
    website VARCHAR(255),
    photo_url TEXT,
    bio TEXT,
    platform_issues JSONB DEFAULT '[]',
    social_media JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- CORE SCHEMA: DONORS
-- ============================================================================
CREATE TABLE IF NOT EXISTS donors (
    donor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),
    county VARCHAR(100),
    
    -- 3D Grading
    amount_grade VARCHAR(5) DEFAULT 'U',
    intensity_score INTEGER DEFAULT 1,
    level_preference VARCHAR(1) DEFAULT 'S',
    composite_score DECIMAL(6,2) DEFAULT 0,
    
    -- Financials
    total_donated DECIMAL(12,2) DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    avg_donation DECIMAL(12,2) DEFAULT 0,
    max_donation DECIMAL(12,2) DEFAULT 0,
    last_donation TIMESTAMP,
    first_donation TIMESTAMP,
    
    -- Employment (for FEC)
    employer VARCHAR(255),
    occupation VARCHAR(255),
    
    -- Lifecycle
    lifecycle_stage VARCHAR(50) DEFAULT 'prospect',
    churn_risk DECIMAL(5,4) DEFAULT 0,
    
    -- Status
    status VARCHAR(50) DEFAULT 'active',
    source VARCHAR(100),
    tags JSONB DEFAULT '[]',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donors_grade ON donors(amount_grade);
CREATE INDEX IF NOT EXISTS idx_donors_county ON donors(county);
CREATE INDEX IF NOT EXISTS idx_donors_email ON donors(email);

-- ============================================================================
-- CORE SCHEMA: DONATIONS
-- ============================================================================
CREATE TABLE IF NOT EXISTS donations (
    donation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES donors(donor_id),
    candidate_id UUID REFERENCES candidates(candidate_id),
    
    amount DECIMAL(12,2) NOT NULL,
    fee_amount DECIMAL(10,4) DEFAULT 0,
    net_amount DECIMAL(12,2),
    
    payment_method VARCHAR(50),
    payment_gateway VARCHAR(50),
    transaction_id VARCHAR(255),
    
    status VARCHAR(50) DEFAULT 'completed',
    election_type VARCHAR(50) DEFAULT 'general',
    election_year INTEGER,
    race_level VARCHAR(50),
    
    is_recurring BOOLEAN DEFAULT false,
    recurring_id UUID,
    
    source VARCHAR(100),
    donation_date TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donations_donor ON donations(donor_id);
CREATE INDEX IF NOT EXISTS idx_donations_candidate ON donations(candidate_id);
CREATE INDEX IF NOT EXISTS idx_donations_date ON donations(donation_date);

-- ============================================================================
-- E4: ACTIVISTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS activists (
    activist_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES donors(donor_id),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    
    activist_score INTEGER DEFAULT 0,
    influence_score INTEGER DEFAULT 0,
    reliability_score INTEGER DEFAULT 0,
    
    skills JSONB DEFAULT '[]',
    interests JSONB DEFAULT '[]',
    organizations JSONB DEFAULT '[]',
    
    is_precinct_captain BOOLEAN DEFAULT false,
    precinct VARCHAR(50),
    
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- E5: VOLUNTEERS
-- ============================================================================
CREATE TABLE IF NOT EXISTS volunteers (
    volunteer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES donors(donor_id),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    
    availability JSONB DEFAULT '{}',
    skills JSONB DEFAULT '[]',
    interests JSONB DEFAULT '[]',
    
    total_hours DECIMAL(10,2) DEFAULT 0,
    total_shifts INTEGER DEFAULT 0,
    reliability_score INTEGER DEFAULT 100,
    
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- E17: RVM (RINGLESS VOICEMAIL) - POLITICAL EXEMPT
-- ============================================================================
CREATE TABLE IF NOT EXISTS rvm_voice_profiles (
    voice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sample_audio_url TEXT,
    voice_model_id VARCHAR(255),
    voice_provider VARCHAR(50) DEFAULT 'elevenlabs',
    gender VARCHAR(20),
    tone VARCHAR(50),
    languages JSONB DEFAULT '["en"]',
    is_trained BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rvm_audio_files (
    audio_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    voice_id UUID REFERENCES rvm_voice_profiles(voice_id),
    name VARCHAR(255) NOT NULL,
    source_type VARCHAR(50) DEFAULT 'upload',
    script_text TEXT,
    personalization_tokens JSONB DEFAULT '[]',
    file_url TEXT,
    duration_seconds INTEGER,
    language VARCHAR(10) DEFAULT 'en',
    approval_status VARCHAR(50) DEFAULT 'pending',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rvm_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    name VARCHAR(500) NOT NULL,
    audio_id UUID REFERENCES rvm_audio_files(audio_id),
    
    voter_file_segment VARCHAR(255),
    target_party VARCHAR(20),
    target_districts JSONB DEFAULT '[]',
    
    scheduled_start TIMESTAMP,
    delivery_start_hour INTEGER DEFAULT 9,
    delivery_end_hour INTEGER DEFAULT 20,
    drops_per_hour INTEGER DEFAULT 10000,
    
    is_ab_test BOOLEAN DEFAULT false,
    
    total_recipients INTEGER DEFAULT 0,
    drops_delivered INTEGER DEFAULT 0,
    callbacks_received INTEGER DEFAULT 0,
    
    status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rvm_recipients (
    recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES rvm_campaigns(campaign_id),
    phone_number VARCHAR(20) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    
    voter_id VARCHAR(100),
    party_affiliation VARCHAR(20),
    voter_score INTEGER,
    precinct VARCHAR(50),
    
    carrier VARCHAR(50),
    is_mobile BOOLEAN DEFAULT true,
    time_zone VARCHAR(50),
    
    status VARCHAR(50) DEFAULT 'pending',
    delivered_at TIMESTAMP,
    callback_received BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rvm_recipients_campaign ON rvm_recipients(campaign_id);
CREATE INDEX IF NOT EXISTS idx_rvm_recipients_status ON rvm_recipients(status);

-- ============================================================================
-- E30: EMAIL CAMPAIGNS
-- ============================================================================
CREATE TABLE IF NOT EXISTS email_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(500),
    preview_text VARCHAR(255),
    html_content TEXT,
    text_content TEXT,
    template_type VARCHAR(50) DEFAULT 'campaign',
    personalization_tokens JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS email_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    name VARCHAR(255) NOT NULL,
    template_id UUID REFERENCES email_templates(template_id),
    
    from_name VARCHAR(255),
    from_email VARCHAR(255),
    reply_to VARCHAR(255),
    
    segment_query JSONB,
    
    scheduled_at TIMESTAMP,
    sent_at TIMESTAMP,
    
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    total_bounced INTEGER DEFAULT 0,
    total_unsubscribed INTEGER DEFAULT 0,
    
    status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- E31: SMS CAMPAIGNS
-- ============================================================================
CREATE TABLE IF NOT EXISTS sms_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    name VARCHAR(255) NOT NULL,
    message_text TEXT NOT NULL,
    
    from_number VARCHAR(20),
    is_mms BOOLEAN DEFAULT false,
    media_url TEXT,
    
    segment_query JSONB,
    
    scheduled_at TIMESTAMP,
    
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_replied INTEGER DEFAULT 0,
    total_opted_out INTEGER DEFAULT 0,
    
    status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- E40: AUTOMATION CONTROL PANEL
-- ============================================================================
CREATE TABLE IF NOT EXISTS automation_controls (
    control_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    
    ecosystem_number INTEGER NOT NULL,
    ecosystem_name VARCHAR(255) NOT NULL,
    
    control_type VARCHAR(20) DEFAULT 'OFF',
    
    timer_enabled BOOLEAN DEFAULT false,
    timer_cron VARCHAR(100),
    timer_next_run TIMESTAMP,
    timer_last_run TIMESTAMP,
    
    config JSONB DEFAULT '{}',
    
    is_active BOOLEAN DEFAULT true,
    updated_by UUID,
    updated_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(candidate_id, ecosystem_number)
);

CREATE TABLE IF NOT EXISTS automation_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    control_id UUID REFERENCES automation_controls(control_id),
    
    action VARCHAR(100) NOT NULL,
    trigger_type VARCHAR(50),
    
    status VARCHAR(50),
    result JSONB,
    error_message TEXT,
    
    duration_ms INTEGER,
    executed_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_automation_logs_control ON automation_logs(control_id);

-- ============================================================================
-- E41: CAMPAIGN BUILDER
-- ============================================================================
CREATE TABLE IF NOT EXISTS campaign_workflows (
    workflow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    trigger_type VARCHAR(100) NOT NULL,
    trigger_config JSONB DEFAULT '{}',
    
    actions JSONB DEFAULT '[]',
    
    is_active BOOLEAN DEFAULT false,
    
    total_runs INTEGER DEFAULT 0,
    successful_runs INTEGER DEFAULT 0,
    last_run_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- E42: NEWS INTELLIGENCE
-- ============================================================================
CREATE TABLE IF NOT EXISTS news_sources (
    source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    url TEXT,
    feed_url TEXT,
    source_type VARCHAR(50),
    counties JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS news_articles (
    article_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES news_sources(source_id),
    
    title TEXT NOT NULL,
    url TEXT,
    content TEXT,
    summary TEXT,
    
    published_at TIMESTAMP,
    scraped_at TIMESTAMP DEFAULT NOW(),
    
    sentiment_score DECIMAL(5,4),
    relevance_score DECIMAL(5,4),
    
    entities JSONB DEFAULT '[]',
    topics JSONB DEFAULT '[]',
    mentioned_candidates JSONB DEFAULT '[]',
    
    is_processed BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_news_published ON news_articles(published_at);

-- ============================================================================
-- INTELLIGENCE BRAIN EVENTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS intelligence_brain_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    source_ecosystem VARCHAR(50),
    
    entity_type VARCHAR(50),
    entity_id UUID,
    
    data JSONB DEFAULT '{}',
    
    priority INTEGER DEFAULT 5,
    processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_type ON intelligence_brain_events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_processed ON intelligence_brain_events(processed, created_at);

-- ============================================================================
-- FEC COMPLIANCE
-- ============================================================================
CREATE TABLE IF NOT EXISTS contribution_limits (
    limit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES donors(donor_id),
    candidate_id UUID REFERENCES candidates(candidate_id),
    
    election_cycle VARCHAR(10) NOT NULL,
    election_type VARCHAR(50),
    
    total_contributed DECIMAL(12,2) DEFAULT 0,
    contribution_limit DECIMAL(12,2) NOT NULL,
    remaining_limit DECIMAL(12,2),
    
    race_level VARCHAR(50),
    
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, candidate_id, election_cycle, election_type)
);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Donor Summary View
CREATE OR REPLACE VIEW v_donor_summary AS
SELECT 
    d.donor_id,
    d.first_name,
    d.last_name,
    d.email,
    d.county,
    d.amount_grade,
    d.intensity_score,
    d.level_preference,
    d.composite_score,
    d.total_donated,
    d.donation_count,
    d.lifecycle_stage,
    d.churn_risk
FROM donors d
WHERE d.status = 'active'
ORDER BY d.composite_score DESC;

-- Campaign Performance View
CREATE OR REPLACE VIEW v_campaign_performance AS
SELECT 
    c.candidate_id,
    c.first_name || ' ' || c.last_name as candidate_name,
    COUNT(DISTINCT d.donor_id) as total_donors,
    SUM(don.amount) as total_raised,
    AVG(don.amount) as avg_donation,
    COUNT(don.donation_id) as total_donations
FROM candidates c
LEFT JOIN donations don ON c.candidate_id = don.candidate_id
LEFT JOIN donors d ON don.donor_id = d.donor_id
GROUP BY c.candidate_id, c.first_name, c.last_name;

-- RVM Campaign Performance
CREATE OR REPLACE VIEW v_rvm_performance AS
SELECT 
    c.campaign_id,
    c.name,
    c.status,
    c.total_recipients,
    c.drops_delivered,
    c.callbacks_received,
    CASE WHEN c.drops_delivered > 0 
         THEN ROUND((c.callbacks_received::DECIMAL / c.drops_delivered) * 100, 2)
         ELSE 0 END as callback_rate
FROM rvm_campaigns c;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on sensitive tables
ALTER TABLE donors ENABLE ROW LEVEL SECURITY;
ALTER TABLE donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE candidates ENABLE ROW LEVEL SECURITY;

-- Policies (adjust based on your auth setup)
CREATE POLICY "Allow authenticated read" ON donors
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated read" ON donations
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated read" ON candidates
    FOR SELECT TO authenticated USING (true);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to recalculate donor grade
CREATE OR REPLACE FUNCTION recalculate_donor_grade(p_donor_id UUID)
RETURNS void AS $$
DECLARE
    v_total DECIMAL(12,2);
    v_grade VARCHAR(5);
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_total
    FROM donations WHERE donor_id = p_donor_id AND status = 'completed';
    
    v_grade := CASE 
        WHEN v_total >= 10000 THEN 'A++'
        WHEN v_total >= 5000 THEN 'A+'
        WHEN v_total >= 2500 THEN 'A'
        WHEN v_total >= 1000 THEN 'B'
        WHEN v_total >= 500 THEN 'C'
        WHEN v_total >= 100 THEN 'D'
        ELSE 'F'
    END;
    
    UPDATE donors SET 
        total_donated = v_total,
        amount_grade = v_grade,
        updated_at = NOW()
    WHERE donor_id = p_donor_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update donor grade on new donation
CREATE OR REPLACE FUNCTION trigger_update_donor_grade()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM recalculate_donor_grade(NEW.donor_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_donation_insert
    AFTER INSERT ON donations
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_donor_grade();

SELECT 'BroyhillGOP Platform Schema Deployed Successfully!' as status;
