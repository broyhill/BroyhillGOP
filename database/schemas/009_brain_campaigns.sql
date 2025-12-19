-- ============================================================================
-- BRAIN CONTROL SYSTEM - CAMPAIGN MANAGEMENT
-- ============================================================================
-- File: 009_brain_campaigns.sql
-- Campaign tracking, performance metrics, A/B testing integration
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: CAMPAIGN REGISTRY
-- ============================================================================

-- Campaigns (linked to LIBERTY/EAGLE ecosystems)
CREATE TABLE campaigns (
    campaign_id SERIAL PRIMARY KEY,
    campaign_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Identification
    campaign_code VARCHAR(50) UNIQUE,
    campaign_name VARCHAR(200) NOT NULL,
    campaign_description TEXT,
    
    -- Type and category
    campaign_type VARCHAR(50) NOT NULL,
    campaign_category VARCHAR(50),
    
    -- Ownership
    ecosystem_code VARCHAR(20) DEFAULT 'EAGLE',
    candidate_id INTEGER,
    candidate_name VARCHAR(200),
    
    -- Dates
    planned_start_date DATE,
    planned_end_date DATE,
    actual_start_date DATE,
    actual_end_date DATE,
    
    -- Budget
    budget_amount DECIMAL(12,2),
    budget_allocated DECIMAL(12,2) DEFAULT 0,
    budget_spent DECIMAL(12,2) DEFAULT 0,
    
    -- Target audience
    target_donors INTEGER,
    target_segments JSONB,
    target_criteria JSONB,
    
    -- Channels
    channels TEXT[],
    
    -- AI configuration
    ai_generated BOOLEAN DEFAULT false,
    ai_model_used VARCHAR(100),
    template_id INTEGER,
    
    -- Approval
    status VARCHAR(20) DEFAULT 'draft',
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Performance summary (cached)
    donors_reached INTEGER DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    donations_amount DECIMAL(12,2) DEFAULT 0,
    roi DECIMAL(8,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Campaign channels
CREATE TABLE campaign_channels (
    channel_id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
    
    -- Channel details
    channel_type VARCHAR(50) NOT NULL,
    channel_name VARCHAR(100),
    
    -- Configuration
    channel_config JSONB,
    
    -- Budget
    budget_allocated DECIMAL(12,2) DEFAULT 0,
    budget_spent DECIMAL(12,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Metrics
    sends INTEGER DEFAULT 0,
    delivered INTEGER DEFAULT 0,
    opened INTEGER DEFAULT 0,
    clicked INTEGER DEFAULT 0,
    converted INTEGER DEFAULT 0,
    
    CONSTRAINT uq_campaign_channel UNIQUE (campaign_id, channel_type)
);

-- ============================================================================
-- SECTION 2: CAMPAIGN METRICS
-- ============================================================================

-- Daily campaign metrics
CREATE TABLE campaign_metrics_daily (
    metric_id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
    metric_date DATE NOT NULL,
    
    -- Email metrics
    emails_sent INTEGER DEFAULT 0,
    emails_delivered INTEGER DEFAULT 0,
    emails_bounced INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    emails_unsubscribed INTEGER DEFAULT 0,
    
    -- SMS metrics
    sms_sent INTEGER DEFAULT 0,
    sms_delivered INTEGER DEFAULT 0,
    sms_clicked INTEGER DEFAULT 0,
    
    -- Mail metrics
    mail_sent INTEGER DEFAULT 0,
    
    -- Social metrics
    social_impressions INTEGER DEFAULT 0,
    social_clicks INTEGER DEFAULT 0,
    social_shares INTEGER DEFAULT 0,
    
    -- Conversion metrics
    landing_page_visits INTEGER DEFAULT 0,
    form_submissions INTEGER DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    donations_amount DECIMAL(12,2) DEFAULT 0,
    avg_donation_amount DECIMAL(10,2),
    
    -- Cost metrics
    cost DECIMAL(12,2) DEFAULT 0,
    cost_per_send DECIMAL(10,4),
    cost_per_click DECIMAL(10,4),
    cost_per_conversion DECIMAL(10,4),
    
    -- ROI
    roi DECIMAL(8,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_campaign_metrics UNIQUE (campaign_id, metric_date)
);

-- Campaign segment metrics
CREATE TABLE campaign_segment_metrics (
    segment_metric_id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
    
    -- Segment
    segment_name VARCHAR(100) NOT NULL,
    segment_criteria JSONB,
    
    -- Audience
    segment_size INTEGER DEFAULT 0,
    
    -- Metrics
    sends INTEGER DEFAULT 0,
    delivered INTEGER DEFAULT 0,
    opened INTEGER DEFAULT 0,
    clicked INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    donations_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Rates
    open_rate DECIMAL(5,4),
    click_rate DECIMAL(5,4),
    conversion_rate DECIMAL(5,4),
    
    -- Comparison to average
    vs_avg_open_rate DECIMAL(5,2),
    vs_avg_click_rate DECIMAL(5,2),
    vs_avg_conversion_rate DECIMAL(5,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_segment_metrics UNIQUE (campaign_id, segment_name)
);

-- ============================================================================
-- SECTION 3: A/B TESTING
-- ============================================================================

-- A/B tests
CREATE TABLE campaign_ab_tests (
    test_id SERIAL PRIMARY KEY,
    test_uuid UUID DEFAULT gen_random_uuid(),
    campaign_id INTEGER NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
    
    -- Test configuration
    test_name VARCHAR(200) NOT NULL,
    test_type VARCHAR(50) NOT NULL,
    test_description TEXT,
    
    -- Variants
    variant_count INTEGER DEFAULT 2,
    variants JSONB NOT NULL,
    
    -- Traffic allocation
    traffic_allocation JSONB,
    
    -- Dates
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    
    -- Sample size
    target_sample_size INTEGER,
    actual_sample_size INTEGER DEFAULT 0,
    
    -- Statistical config
    confidence_level DECIMAL(3,2) DEFAULT 0.95,
    minimum_detectable_effect DECIMAL(5,4),
    
    -- Results
    status VARCHAR(20) DEFAULT 'draft',
    winning_variant VARCHAR(50),
    statistical_significance DECIMAL(5,4),
    
    -- AI analysis
    ai_analysis TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100)
);

-- A/B test variant metrics
CREATE TABLE campaign_ab_variant_metrics (
    variant_metric_id SERIAL PRIMARY KEY,
    test_id INTEGER NOT NULL REFERENCES campaign_ab_tests(test_id) ON DELETE CASCADE,
    
    -- Variant
    variant_name VARCHAR(50) NOT NULL,
    variant_config JSONB,
    
    -- Volume
    sends INTEGER DEFAULT 0,
    
    -- Metrics
    delivered INTEGER DEFAULT 0,
    opened INTEGER DEFAULT 0,
    clicked INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    donations_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Rates
    open_rate DECIMAL(5,4),
    click_rate DECIMAL(5,4),
    conversion_rate DECIMAL(5,4),
    
    -- Statistical
    is_winner BOOLEAN DEFAULT false,
    confidence DECIMAL(5,4),
    lift_vs_control DECIMAL(5,4),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_variant_metrics UNIQUE (test_id, variant_name)
);

-- ============================================================================
-- SECTION 4: CAMPAIGN TEMPLATES
-- ============================================================================

-- Campaign templates
CREATE TABLE campaign_templates (
    template_id SERIAL PRIMARY KEY,
    template_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Identification
    template_code VARCHAR(50) UNIQUE,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Type
    campaign_type VARCHAR(50) NOT NULL,
    channel_type VARCHAR(50),
    
    -- Content
    subject_template TEXT,
    body_template TEXT,
    html_template TEXT,
    
    -- Variables
    required_variables TEXT[],
    optional_variables TEXT[],
    variable_defaults JSONB,
    
    -- AI configuration
    ai_prompt_id INTEGER,
    ai_generated BOOLEAN DEFAULT false,
    
    -- Performance
    times_used INTEGER DEFAULT 0,
    avg_open_rate DECIMAL(5,4),
    avg_click_rate DECIMAL(5,4),
    avg_conversion_rate DECIMAL(5,4),
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft',
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SECTION 5: CAMPAIGN-BRAIN INTEGRATION
-- ============================================================================

-- Campaign function usage
CREATE TABLE campaign_function_usage (
    usage_id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    
    -- Usage metrics
    usage_date DATE NOT NULL,
    calls INTEGER DEFAULT 0,
    records_processed INTEGER DEFAULT 0,
    cost DECIMAL(12,4) DEFAULT 0,
    
    -- Quality
    avg_quality_score DECIMAL(5,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_campaign_function_usage UNIQUE (campaign_id, function_code, usage_date)
);

-- Campaign AI requests
CREATE TABLE campaign_ai_requests (
    request_id BIGSERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(campaign_id) ON DELETE SET NULL,
    
    -- AI request reference
    ai_request_id BIGINT,
    function_code VARCHAR(10),
    
    -- Request type
    request_type VARCHAR(50),
    
    -- Timing
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Cost
    cost DECIMAL(10,6),
    
    -- Result
    success BOOLEAN,
    quality_score DECIMAL(5,2),
    
    -- Output reference
    output_type VARCHAR(50),
    output_id VARCHAR(100)
);

-- ============================================================================
-- SECTION 6: INDEXES
-- ============================================================================

-- Campaigns
CREATE INDEX idx_campaigns_status ON campaigns(status);
CREATE INDEX idx_campaigns_type ON campaigns(campaign_type);
CREATE INDEX idx_campaigns_candidate ON campaigns(candidate_id);
CREATE INDEX idx_campaigns_dates ON campaigns(actual_start_date, actual_end_date);

-- Campaign metrics
CREATE INDEX idx_campaign_metrics_campaign ON campaign_metrics_daily(campaign_id);
CREATE INDEX idx_campaign_metrics_date ON campaign_metrics_daily(metric_date);

-- A/B tests
CREATE INDEX idx_ab_tests_campaign ON campaign_ab_tests(campaign_id);
CREATE INDEX idx_ab_tests_status ON campaign_ab_tests(status);

-- Templates
CREATE INDEX idx_templates_type ON campaign_templates(campaign_type);
CREATE INDEX idx_templates_status ON campaign_templates(status);

-- Function usage
CREATE INDEX idx_campaign_func_campaign ON campaign_function_usage(campaign_id);
CREATE INDEX idx_campaign_func_function ON campaign_function_usage(function_code);

-- ============================================================================
-- SECTION 7: COMMENTS
-- ============================================================================

COMMENT ON TABLE campaigns IS 'Campaign registry integrated with LIBERTY/EAGLE ecosystems';
COMMENT ON TABLE campaign_metrics_daily IS 'Daily campaign performance metrics';
COMMENT ON TABLE campaign_ab_tests IS 'A/B testing configuration and results';
COMMENT ON TABLE campaign_templates IS 'Reusable campaign templates with AI integration';
