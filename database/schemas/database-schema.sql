-- ============================================================================
-- BroyhillGOP Multi-Channel Marketing Automation Platform
-- PostgreSQL Schema
-- ============================================================================

-- ============================================================================
-- ENUMS & CUSTOM TYPES
-- ============================================================================

CREATE TYPE campaign_type AS ENUM ('email', 'sms', 'print', 'phone', 'social', 'mixed');
CREATE TYPE campaign_status AS ENUM ('draft', 'scheduled', 'running', 'paused', 'completed', 'archived');
CREATE TYPE send_status AS ENUM ('queued', 'sent', 'delivered', 'failed', 'bounced');
CREATE TYPE channel AS ENUM ('email', 'sms', 'print', 'phone', 'website');
CREATE TYPE event_type AS ENUM ('send', 'open', 'click', 'reply', 'bounce', 'unsubscribe', 'donation', 'event_rsvp', 'call', 'voicemail', 'conversion');
CREATE TYPE consent_status AS ENUM ('opted_in', 'opted_out', 'pending', 'bounced');
CREATE TYPE donor_segment AS ENUM ('a_tier', 'b_tier', 'c_tier', 'lapsed', 'prospect', 'vip');

-- ============================================================================
-- AUDIT & COMPLIANCE TABLES
-- ============================================================================

-- Audit log for all data access (GDPR Article 32)
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(255),
    action VARCHAR(255) NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    record_id BIGINT,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    created_at TIMESTAMP DEFAULT NOW(),
    INDEX audit_logs_created_at (created_at DESC),
    INDEX audit_logs_user_id (user_id),
    INDEX audit_logs_action (action)
);

-- Consent tracking (GDPR Article 7)
CREATE TABLE consent_records (
    id BIGSERIAL PRIMARY KEY,
    donor_id BIGINT NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
    channel channel NOT NULL,
    status consent_status DEFAULT 'opted_in',
    opted_in_at TIMESTAMP,
    opted_out_at TIMESTAMP,
    opted_in_ip INET,
    opted_out_ip INET,
    opted_in_user_id VARCHAR(255),
    opted_out_user_id VARCHAR(255),
    consent_source VARCHAR(255),  -- 'web_form', 'import', 'manual', 'api'
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(donor_id, channel),
    INDEX consent_records_donor_id (donor_id),
    INDEX consent_records_channel (channel),
    INDEX consent_records_status (status)
);

-- Do-Not-Call (TCPA) compliance
CREATE TABLE dnc_records (
    id BIGSERIAL PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE,
    donor_id BIGINT REFERENCES donors(id) ON DELETE SET NULL,
    dnc_type VARCHAR(50),  -- 'fcc', 'internal', 'tcpa'
    list_date DATE,
    checked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    INDEX dnc_phone (phone_number)
);

-- ============================================================================
-- CORE DONOR & PROFILE DATA
-- ============================================================================

CREATE TABLE donors (
    id BIGSERIAL PRIMARY KEY,
    external_id VARCHAR(255) UNIQUE,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    phone_primary VARCHAR(20),
    phone_secondary VARCHAR(20),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(2),
    address_zip VARCHAR(10),
    address_country VARCHAR(100) DEFAULT 'USA',
    
    -- Engagement Scores
    engagement_score FLOAT DEFAULT 0.0,  -- 0-100
    email_open_rate FLOAT DEFAULT 0.0,   -- 0-1
    email_click_rate FLOAT DEFAULT 0.0,  -- 0-1
    sms_delivery_rate FLOAT DEFAULT 0.0, -- 0-1
    
    -- Segment & Classification
    segment donor_segment DEFAULT 'prospect',
    rfm_recency INT,  -- Days since last contact
    rfm_frequency INT,  -- Total interactions
    rfm_monetary DECIMAL(10,2),  -- Total value
    lifetime_value DECIMAL(12,2) DEFAULT 0.0,
    predicted_ltv DECIMAL(12,2) DEFAULT 0.0,
    churn_risk FLOAT DEFAULT 0.0,  -- 0-1
    response_propensity FLOAT DEFAULT 0.0,  -- 0-1
    
    -- Event Attendance
    event_attended_count INT DEFAULT 0,
    event_rsvp_count INT DEFAULT 0,
    
    -- Volunteer Activity
    volunteer_hours DECIMAL(8,2) DEFAULT 0.0,
    volunteer_activity_count INT DEFAULT 0,
    
    -- Contact Preferences
    preferred_channel channel DEFAULT 'email',
    do_not_call BOOLEAN DEFAULT FALSE,
    do_not_email BOOLEAN DEFAULT FALSE,
    do_not_mail BOOLEAN DEFAULT FALSE,
    do_not_sms BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    source VARCHAR(100),  -- 'import', 'web_form', 'event', 'call'
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_contacted_at TIMESTAMP,
    
    INDEX donors_email (email),
    INDEX donors_phone (phone_primary),
    INDEX donors_segment (segment),
    INDEX donors_lifetime_value (lifetime_value DESC),
    INDEX donors_created_at (created_at DESC),
    INDEX donors_engagement (engagement_score DESC),
    PARTITION BY RANGE (created_at) (
        PARTITION donors_2023 VALUES LESS THAN ('2024-01-01'),
        PARTITION donors_2024 VALUES LESS THAN ('2025-01-01'),
        PARTITION donors_2025 VALUES LESS THAN ('2026-01-01'),
        PARTITION donors_future VALUES LESS THAN (MAXVALUE)
    )
);

-- Donor activity history (for churn analysis)
CREATE TABLE donor_activity (
    id BIGSERIAL PRIMARY KEY,
    donor_id BIGINT NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
    activity_type VARCHAR(50),  -- 'email_open', 'click', 'donation', 'event', 'phone_call'
    activity_date DATE,
    activity_count INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW(),
    INDEX donor_activity_donor (donor_id),
    INDEX donor_activity_date (activity_date DESC),
    PARTITION BY RANGE (activity_date) (
        PARTITION activity_2024 VALUES LESS THAN ('2025-01-01'),
        PARTITION activity_2025 VALUES LESS THAN ('2026-01-01'),
        PARTITION activity_future VALUES LESS THAN (MAXVALUE)
    )
);

-- ============================================================================
-- CAMPAIGN MANAGEMENT
-- ============================================================================

CREATE TABLE campaigns (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(500) NOT NULL,
    description TEXT,
    campaign_type campaign_type NOT NULL,
    status campaign_status DEFAULT 'draft',
    
    -- Targeting
    target_segment donor_segment,
    target_count INT,
    
    -- Content
    subject_line VARCHAR(255),  -- For email
    body_text TEXT,
    call_to_action VARCHAR(255),
    ask_amount DECIMAL(10,2),
    
    -- Timing
    scheduled_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Configuration
    use_personalization BOOLEAN DEFAULT TRUE,
    use_ml_ask_amount BOOLEAN DEFAULT FALSE,
    use_optimal_send_time BOOLEAN DEFAULT FALSE,
    frequency_cap_emails_per_month INT DEFAULT 8,
    frequency_cap_sms_per_month INT DEFAULT 6,
    frequency_cap_calls_per_month INT DEFAULT 3,
    
    -- Analytics
    total_sends INT DEFAULT 0,
    total_opens INT DEFAULT 0,
    total_clicks INT DEFAULT 0,
    total_conversions INT DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0.0,
    roi FLOAT DEFAULT 0.0,
    
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    INDEX campaigns_status (status),
    INDEX campaigns_type (campaign_type),
    INDEX campaigns_created_at (created_at DESC),
    INDEX campaigns_segment (target_segment)
);

-- Campaign variants (A/B testing)
CREATE TABLE campaign_variants (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGSERIAL NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    variant_name VARCHAR(100),
    variant_type VARCHAR(50),  -- 'subject_line', 'ask_amount', 'cta', 'image'
    control_value VARCHAR(500),
    test_value VARCHAR(500),
    allocation_percent INT DEFAULT 50,
    created_at TIMESTAMP DEFAULT NOW(),
    INDEX campaign_variants_campaign (campaign_id)
);

-- Campaign sends (every message)
CREATE TABLE campaign_sends (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    donor_id BIGINT NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
    channel channel NOT NULL,
    
    -- Send details
    status send_status DEFAULT 'queued',
    recipient_email VARCHAR(255),
    recipient_phone VARCHAR(20),
    recipient_address_full TEXT,
    
    -- Personalization
    personalization_data JSONB,  -- All merge fields used
    variant_id BIGINT REFERENCES campaign_variants(id),
    ask_amount DECIMAL(10,2),
    
    -- Tracking
    tracking_id UUID DEFAULT gen_random_uuid(),
    external_id VARCHAR(500),  -- Print job ID, email service ID, SMS ID, etc.
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    failed_at TIMESTAMP,
    failure_reason TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    INDEX campaign_sends_campaign (campaign_id),
    INDEX campaign_sends_donor (donor_id),
    INDEX campaign_sends_channel (channel),
    INDEX campaign_sends_status (status),
    INDEX campaign_sends_tracking_id (tracking_id),
    INDEX campaign_sends_sent_at (sent_at DESC),
    PARTITION BY RANGE (sent_at) (
        PARTITION sends_2024 VALUES LESS THAN ('2025-01-01'),
        PARTITION sends_2025 VALUES LESS THAN ('2026-01-01'),
        PARTITION sends_future VALUES LESS THAN (MAXVALUE)
    )
);

-- ============================================================================
-- RESPONSE & CONVERSION TRACKING
-- ============================================================================

CREATE TABLE campaign_events (
    id BIGSERIAL PRIMARY KEY,
    campaign_send_id BIGINT NOT NULL REFERENCES campaign_sends(id) ON DELETE CASCADE,
    donor_id BIGINT NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
    campaign_id BIGINT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    
    event_type event_type NOT NULL,
    event_data JSONB,  -- Flexible data: click URL, phone duration, etc.
    
    -- Tracking
    user_agent TEXT,
    ip_address INET,
    
    -- For conversions
    conversion_amount DECIMAL(12,2),
    conversion_note TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    INDEX campaign_events_send (campaign_send_id),
    INDEX campaign_events_donor (donor_id),
    INDEX campaign_events_type (event_type),
    INDEX campaign_events_created (created_at DESC),
    PARTITION BY RANGE (created_at) (
        PARTITION events_2024 VALUES LESS THAN ('2025-01-01'),
        PARTITION events_2025 VALUES LESS THAN ('2026-01-01'),
        PARTITION events_future VALUES LESS THAN (MAXVALUE)
    )
);

-- Multi-touch attribution
CREATE TABLE campaign_attribution (
    id BIGSERIAL PRIMARY KEY,
    donor_id BIGINT NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
    conversion_id BIGINT NOT NULL REFERENCES campaign_events(id) ON DELETE CASCADE,
    
    -- Touchpoints
    touchpoint_send_id BIGINT REFERENCES campaign_sends(id) ON DELETE SET NULL,
    touchpoint_channel channel,
    touchpoint_date TIMESTAMP,
    
    -- Attribution
    attribution_model VARCHAR(50),  -- 'first_touch', 'last_touch', 'linear', 'time_decay'
    attribution_weight FLOAT,  -- 0-1
    attributed_value DECIMAL(12,2),
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    INDEX attribution_donor (donor_id),
    INDEX attribution_conversion (conversion_id),
    INDEX attribution_model (attribution_model)
);

-- ============================================================================
-- PRINT PRODUCTION
-- ============================================================================

CREATE TABLE print_jobs (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    
    -- Job Details
    job_name VARCHAR(255) NOT NULL,
    job_type VARCHAR(50),  -- 'postcard', 'flyer', 'letter', 'package'
    template_id VARCHAR(255),
    
    -- Production
    total_pieces INT,
    completed_pieces INT DEFAULT 0,
    failed_pieces INT DEFAULT 0,
    pdf_output_path VARCHAR(500),
    
    -- Vendor
    vendor_name VARCHAR(255),
    vendor_job_id VARCHAR(255),
    vendor_api_response JSONB,
    
    -- Tracking
    presort_file_path VARCHAR(500),
    tracking_numbers JSONB,  -- Array of USPS barcode data
    
    -- Status
    created_at TIMESTAMP DEFAULT NOW(),
    submitted_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    INDEX print_jobs_campaign (campaign_id),
    INDEX print_jobs_status (completed_at),
    INDEX print_jobs_vendor (vendor_name)
);

-- Individual print piece tracking
CREATE TABLE print_pieces (
    id BIGSERIAL PRIMARY KEY,
    print_job_id BIGINT NOT NULL REFERENCES print_jobs(id) ON DELETE CASCADE,
    campaign_send_id BIGINT REFERENCES campaign_sends(id),
    donor_id BIGINT REFERENCES donors(id),
    
    -- Barcode tracking
    usps_barcode VARCHAR(50),
    tracking_number VARCHAR(100),
    
    -- Status
    rendered_at TIMESTAMP,
    submitted_to_vendor_at TIMESTAMP,
    delivered_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    INDEX print_pieces_job (print_job_id),
    INDEX print_pieces_barcode (usps_barcode),
    INDEX print_pieces_tracking (tracking_number),
    PARTITION BY RANGE (created_at) (
        PARTITION pieces_2024 VALUES LESS THAN ('2025-01-01'),
        PARTITION pieces_2025 VALUES LESS THAN ('2026-01-01'),
        PARTITION pieces_future VALUES LESS THAN (MAXVALUE)
    )
);

-- ============================================================================
-- CALL CENTER
-- ============================================================================

CREATE TABLE call_records (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT REFERENCES campaigns(id),
    campaign_send_id BIGINT REFERENCES campaign_sends(id),
    donor_id BIGINT NOT NULL REFERENCES donors(id),
    
    -- Call Details
    calling_agent VARCHAR(255),
    phone_number VARCHAR(20),
    caller_id VARCHAR(20),
    
    -- Outcomes
    call_status VARCHAR(50),  -- 'answered', 'no_answer', 'busy', 'disconnected', 'voicemail'
    call_duration INT,  -- seconds
    call_outcome VARCHAR(50),  -- 'conversion', 'interested', 'not_interested', 'dnc'
    
    -- Tracking
    recording_url VARCHAR(500),
    recording_duration INT,  -- seconds
    transcription TEXT,
    sentiment_score FLOAT,  -- 0-1
    
    -- Disposition
    disposition VARCHAR(100),
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    INDEX call_records_donor (donor_id),
    INDEX call_records_campaign (campaign_id),
    INDEX call_records_status (call_status),
    INDEX call_records_created (created_at DESC),
    PARTITION BY RANGE (created_at) (
        PARTITION calls_2024 VALUES LESS THAN ('2025-01-01'),
        PARTITION calls_2025 VALUES LESS THAN ('2026-01-01'),
        PARTITION calls_future VALUES LESS THAN (MAXVALUE)
    )
);

-- ============================================================================
-- ANALYTICS AGGREGATIONS
-- ============================================================================

-- Daily campaign metrics (for fast dashboards)
CREATE TABLE daily_campaign_metrics (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    metric_date DATE,
    
    sends_count INT DEFAULT 0,
    delivered_count INT DEFAULT 0,
    bounced_count INT DEFAULT 0,
    opens_count INT DEFAULT 0,
    clicks_count INT DEFAULT 0,
    conversions_count INT DEFAULT 0,
    conversion_revenue DECIMAL(12,2) DEFAULT 0.0,
    
    open_rate FLOAT DEFAULT 0.0,
    click_rate FLOAT DEFAULT 0.0,
    conversion_rate FLOAT DEFAULT 0.0,
    roi FLOAT DEFAULT 0.0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(campaign_id, metric_date),
    INDEX daily_metrics_campaign (campaign_id),
    INDEX daily_metrics_date (metric_date)
);

-- Channel performance summary
CREATE TABLE channel_performance (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    channel channel NOT NULL,
    
    total_sends INT DEFAULT 0,
    successful_sends INT DEFAULT 0,
    failed_sends INT DEFAULT 0,
    conversion_count INT DEFAULT 0,
    conversion_revenue DECIMAL(12,2) DEFAULT 0.0,
    
    cost_per_send DECIMAL(10,4),
    cost_per_conversion DECIMAL(10,2),
    roi FLOAT,
    
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(campaign_id, channel),
    INDEX channel_perf_campaign (campaign_id)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Foreign key indexes
CREATE INDEX IF NOT EXISTS idx_campaign_sends_campaign_donor ON campaign_sends(campaign_id, donor_id);
CREATE INDEX IF NOT EXISTS idx_campaign_events_full ON campaign_events(campaign_id, donor_id, event_type);
CREATE INDEX IF NOT EXISTS idx_donor_activity_full ON donor_activity(donor_id, activity_date DESC);

-- Query optimization
CREATE INDEX IF NOT EXISTS idx_campaigns_running ON campaigns(status) WHERE status = 'running';
CREATE INDEX IF NOT EXISTS idx_sends_pending ON campaign_sends(status) WHERE status = 'queued';
CREATE INDEX IF NOT EXISTS idx_donors_high_value ON donors(lifetime_value DESC) WHERE segment = 'a_tier';

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Audit trigger for GDPR compliance
CREATE OR REPLACE FUNCTION audit_table_changes() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, ip_address, created_at)
    VALUES (
        CURRENT_USER,
        TG_OP,
        TG_TABLE_NAME,
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
        CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE NULL END,
        CASE WHEN TG_OP = 'INSERT' THEN row_to_json(NEW) ELSE row_to_json(NEW) END,
        inet_client_addr(),
        NOW()
    );
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_modified_column() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER audit_donors AFTER INSERT OR UPDATE OR DELETE ON donors FOR EACH ROW EXECUTE FUNCTION audit_table_changes();
CREATE TRIGGER audit_campaigns AFTER INSERT OR UPDATE OR DELETE ON campaigns FOR EACH ROW EXECUTE FUNCTION audit_table_changes();
CREATE TRIGGER update_donors_modified BEFORE UPDATE ON donors FOR EACH ROW EXECUTE FUNCTION update_modified_column();
CREATE TRIGGER update_campaigns_modified BEFORE UPDATE ON campaigns FOR EACH ROW EXECUTE FUNCTION update_modified_column();
CREATE TRIGGER update_sends_modified BEFORE UPDATE ON campaign_sends FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Recent donor activity view
CREATE VIEW vw_donor_recent_activity AS
SELECT 
    d.id,
    d.first_name,
    d.last_name,
    d.email,
    d.lifetime_value,
    MAX(ca.activity_date) as last_activity_date,
    COUNT(*) as total_activities,
    EXTRACT(DAY FROM NOW() - MAX(ca.activity_date)) as days_since_activity
FROM donors d
LEFT JOIN donor_activity ca ON d.id = ca.donor_id
GROUP BY d.id, d.first_name, d.last_name, d.email, d.lifetime_value;

-- Campaign performance summary
CREATE VIEW vw_campaign_performance AS
SELECT 
    c.id,
    c.name,
    c.campaign_type,
    COUNT(DISTINCT cs.id) as total_sends,
    COUNT(DISTINCT CASE WHEN ce.event_type = 'open' THEN cs.id END) as opens,
    COUNT(DISTINCT CASE WHEN ce.event_type = 'click' THEN cs.id END) as clicks,
    COUNT(DISTINCT CASE WHEN ce.event_type = 'donation' THEN cs.id END) as donations,
    COALESCE(SUM(CASE WHEN ce.event_type = 'donation' THEN ce.conversion_amount ELSE 0 END), 0) as total_revenue,
    ROUND(
        COUNT(DISTINCT CASE WHEN ce.event_type = 'open' THEN cs.id END)::FLOAT / 
        NULLIF(COUNT(DISTINCT cs.id), 0) * 100, 2
    ) as open_rate,
    ROUND(
        COUNT(DISTINCT CASE WHEN ce.event_type = 'click' THEN cs.id END)::FLOAT / 
        NULLIF(COUNT(DISTINCT cs.id), 0) * 100, 2
    ) as click_rate
FROM campaigns c
LEFT JOIN campaign_sends cs ON c.id = cs.campaign_id
LEFT JOIN campaign_events ce ON cs.id = ce.campaign_send_id
WHERE c.status = 'completed'
GROUP BY c.id, c.name, c.campaign_type;

-- Donor segment analysis
CREATE VIEW vw_donor_segments AS
SELECT 
    d.segment,
    COUNT(*) as donor_count,
    AVG(d.lifetime_value) as avg_ltv,
    SUM(d.lifetime_value) as total_ltv,
    AVG(d.engagement_score) as avg_engagement,
    AVG(d.response_propensity) as avg_response_propensity
FROM donors d
GROUP BY d.segment;

-- ============================================================================
-- SAMPLE DATA & INITIALIZATION
-- ============================================================================

-- Create test user
-- (Actual data loaded from CSV in separate file)

COMMIT;