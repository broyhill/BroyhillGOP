-- ========================================
-- REMAINING 8 TABLES
-- ========================================

-- ========================================
-- TABLE 2: TRANSACTIONS
-- All donation records with partitioning
-- ========================================

CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    donor_id UUID NOT NULL REFERENCES donors(donor_id) ON DELETE CASCADE,
    
    -- Transaction details
    transaction_date DATE NOT NULL,
    transaction_year INTEGER GENERATED ALWAYS AS (EXTRACT(YEAR FROM transaction_date)) STORED,
    amount DECIMAL(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Payment method
    payment_method VARCHAR(50),        -- credit_card, check, cash, wire, crypto
    payment_processor VARCHAR(100),    -- Stripe, PayPal, etc.
    payment_processor_id VARCHAR(255),
    
    -- Check details
    check_number VARCHAR(50),
    check_date DATE,
    
    -- Credit card details (last 4 only)
    card_last_4 VARCHAR(4),
    card_type VARCHAR(50),
    
    -- Transaction status
    status VARCHAR(50) DEFAULT 'completed', -- pending, completed, failed, refunded
    failed_reason TEXT,
    refunded BOOLEAN DEFAULT FALSE,
    refunded_at TIMESTAMP,
    refunded_amount DECIMAL(12, 2),
    
    -- Attribution
    campaign_id UUID,                  -- References campaigns table
    source_code VARCHAR(100),
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    referring_url TEXT,
    
    -- Recipient
    recipient_type VARCHAR(50),        -- candidate, committee, pac
    recipient_id UUID,                 -- References candidates or committees
    recipient_name VARCHAR(255),
    
    -- FEC reporting
    fec_reportable BOOLEAN DEFAULT TRUE,
    fec_reported BOOLEAN DEFAULT FALSE,
    fec_report_id VARCHAR(100),
    fec_filing_date DATE,
    
    -- Employer disclosure (FEC requirement >$200)
    employer_disclosed VARCHAR(255),
    occupation_disclosed VARCHAR(255),
    
    -- Notes
    notes TEXT,
    thank_you_sent BOOLEAN DEFAULT FALSE,
    thank_you_sent_at TIMESTAMP,
    receipt_sent BOOLEAN DEFAULT FALSE,
    receipt_sent_at TIMESTAMP,
    receipt_number VARCHAR(100),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_amount CHECK (amount > 0),
    CONSTRAINT valid_tenant CHECK (tenant_id IS NOT NULL)
) PARTITION BY RANGE (transaction_year);

-- Create partitions by year
CREATE TABLE transactions_2020 PARTITION OF transactions FOR VALUES FROM (2020) TO (2021);
CREATE TABLE transactions_2021 PARTITION OF transactions FOR VALUES FROM (2021) TO (2022);
CREATE TABLE transactions_2022 PARTITION OF transactions FOR VALUES FROM (2022) TO (2023);
CREATE TABLE transactions_2023 PARTITION OF transactions FOR VALUES FROM (2023) TO (2024);
CREATE TABLE transactions_2024 PARTITION OF transactions FOR VALUES FROM (2024) TO (2025);
CREATE TABLE transactions_2025 PARTITION OF transactions FOR VALUES FROM (2025) TO (2026);
CREATE TABLE transactions_2026 PARTITION OF transactions FOR VALUES FROM (2026) TO (2027);

-- Indexes
CREATE INDEX idx_transactions_tenant ON transactions(tenant_id);
CREATE INDEX idx_transactions_donor ON transactions(donor_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date DESC);
CREATE INDEX idx_transactions_amount ON transactions(amount DESC);
CREATE INDEX idx_transactions_campaign ON transactions(campaign_id) WHERE campaign_id IS NOT NULL;
CREATE INDEX idx_transactions_recipient ON transactions(recipient_id) WHERE recipient_id IS NOT NULL;
CREATE INDEX idx_transactions_status ON transactions(status);

-- RLS
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY transactions_tenant_isolation ON transactions
    FOR ALL
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::UUID);


-- ========================================
-- TABLE 3: CANDIDATES
-- NC Republican candidates with bellwether tracking
-- ========================================

CREATE TABLE candidates (
    candidate_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,  -- For multi-tenant support
    
    -- Basic info
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(255),
    party VARCHAR(50) DEFAULT 'Republican',
    
    -- Office
    office_sought VARCHAR(100),        -- US Senate, US House, Governor, etc.
    office_level VARCHAR(50),          -- federal, state, local
    district VARCHAR(50),
    state VARCHAR(2) DEFAULT 'NC',
    
    -- Election
    election_year INTEGER,
    election_date DATE,
    election_type VARCHAR(50),         -- primary, general, special
    
    -- Status
    candidate_status VARCHAR(50),      -- declared, active, withdrawn, elected, defeated
    incumbent BOOLEAN DEFAULT FALSE,
    
    -- Campaign details
    campaign_name VARCHAR(255),
    campaign_committee_name VARCHAR(255),
    fec_candidate_id VARCHAR(50),
    fec_committee_id VARCHAR(50),
    
    -- Contact
    campaign_website VARCHAR(255),
    campaign_email VARCHAR(255),
    campaign_phone VARCHAR(20),
    campaign_address TEXT,
    
    -- Bellwether tracking
    bellwether_weight DECIMAL(5, 2) DEFAULT 1.0,  -- How important is this candidate
    bellwether_level VARCHAR(50),      -- national, statewide, regional, local
    bellwether_rank INTEGER,           -- 1-21 for top bellwethers
    
    -- Fundraising
    fundraising_goal DECIMAL(12, 2),
    funds_raised DECIMAL(12, 2) DEFAULT 0,
    funds_spent DECIMAL(12, 2) DEFAULT 0,
    cash_on_hand DECIMAL(12, 2) DEFAULT 0,
    last_fundraising_report_date DATE,
    
    -- Performance
    polling_average DECIMAL(5, 2),
    election_result VARCHAR(50),       -- won, lost, pending
    vote_percentage DECIMAL(5, 2),
    votes_received INTEGER,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_candidates_tenant ON candidates(tenant_id);
CREATE INDEX idx_candidates_name ON candidates(last_name, first_name);
CREATE INDEX idx_candidates_office ON candidates(office_sought);
CREATE INDEX idx_candidates_bellwether ON candidates(bellwether_rank) WHERE bellwether_rank IS NOT NULL;
CREATE INDEX idx_candidates_fec ON candidates(fec_candidate_id);


-- ========================================
-- TABLE 4: COMMITTEES
-- PACs and political committees
-- ========================================

CREATE TABLE committees (
    committee_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    
    -- Basic info
    committee_name VARCHAR(255) NOT NULL,
    committee_type VARCHAR(100),       -- candidate, pac, super_pac, party, hybrid
    party_affiliation VARCHAR(50),
    
    -- FEC info
    fec_committee_id VARCHAR(50),
    fec_designation VARCHAR(50),
    fec_type VARCHAR(50),
    
    -- Contact
    treasurer_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    address TEXT,
    website VARCHAR(255),
    
    -- Financial
    total_receipts DECIMAL(12, 2) DEFAULT 0,
    total_disbursements DECIMAL(12, 2) DEFAULT 0,
    cash_on_hand DECIMAL(12, 2) DEFAULT 0,
    last_report_date DATE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_committees_tenant ON committees(tenant_id);
CREATE INDEX idx_committees_name ON committees(committee_name);
CREATE INDEX idx_committees_fec ON committees(fec_committee_id);


-- ========================================
-- TABLE 5: CAMPAIGNS
-- Marketing campaigns (22+ types)
-- ========================================

CREATE TABLE campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    
    -- Basic info
    campaign_name VARCHAR(255) NOT NULL,
    campaign_type VARCHAR(100) NOT NULL,  -- 22+ types defined
    campaign_category VARCHAR(50),        -- Category 1-7
    description TEXT,
    
    -- Targeting
    target_grades VARCHAR(2)[],           -- [A+, A, A-, B+]
    target_lead_score_min INTEGER,
    target_lead_score_max INTEGER,
    target_geography JSONB,               -- {states: [], counties: [], zips: []}
    target_demographics JSONB,
    target_custom_filters JSONB,
    estimated_audience_size INTEGER,
    actual_audience_size INTEGER,
    
    -- Channels
    channels VARCHAR(50)[],               -- [email, sms, phone, mail, social]
    channel_config JSONB,                 -- Per-channel settings
    
    -- Content
    email_subject VARCHAR(255),
    email_body TEXT,
    email_template_id VARCHAR(100),
    sms_message TEXT,
    phone_script TEXT,
    mail_template_id VARCHAR(100),
    
    -- Budget & Pricing
    budget_total DECIMAL(12, 2),
    cost_per_contact DECIMAL(10, 4),
    setup_fees DECIMAL(10, 2),
    estimated_cost DECIMAL(12, 2),
    actual_cost DECIMAL(12, 2) DEFAULT 0,
    
    -- Goals
    goal_type VARCHAR(50),                -- donations, rsvp, volunteer, engagement
    goal_amount DECIMAL(12, 2),
    goal_count INTEGER,
    
    -- AI Recommendations
    ai_recommended_type VARCHAR(100),
    ai_confidence_score DECIMAL(5, 2),
    ai_reasoning TEXT,
    optimal_timing JSONB,                 -- {month: 11, day_of_week: 3, time_of_day: "evening"}
    
    -- Schedule
    scheduled_launch_at TIMESTAMP,
    actual_launch_at TIMESTAMP,
    scheduled_end_at TIMESTAMP,
    actual_end_at TIMESTAMP,
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',   -- draft, scheduled, running, paused, completed, cancelled
    approved BOOLEAN DEFAULT FALSE,
    approved_by UUID,
    approved_at TIMESTAMP,
    
    -- Results (updated in real-time)
    contacts_attempted INTEGER DEFAULT 0,
    contacts_successful INTEGER DEFAULT 0,
    responses_received INTEGER DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    donations_amount DECIMAL(12, 2) DEFAULT 0,
    rsvps_count INTEGER DEFAULT 0,
    volunteers_recruited INTEGER DEFAULT 0,
    
    -- Performance metrics
    response_rate DECIMAL(5, 2),
    conversion_rate DECIMAL(5, 2),
    roi DECIMAL(10, 2),                   -- Return on investment
    cost_per_acquisition DECIMAL(10, 2),
    
    -- Email specific metrics
    emails_sent INTEGER DEFAULT 0,
    emails_delivered INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    emails_bounced INTEGER DEFAULT 0,
    emails_unsubscribed INTEGER DEFAULT 0,
    
    -- SMS specific metrics
    sms_sent INTEGER DEFAULT 0,
    sms_delivered INTEGER DEFAULT 0,
    sms_responded INTEGER DEFAULT 0,
    sms_opted_out INTEGER DEFAULT 0,
    
    -- Phone specific metrics
    calls_made INTEGER DEFAULT 0,
    calls_answered INTEGER DEFAULT 0,
    calls_completed INTEGER DEFAULT 0,
    average_call_duration INTEGER,
    
    -- Attribution
    attributed_to_campaign_id UUID,       -- Parent campaign if this is a follow-up
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_campaign_type CHECK (campaign_type IN (
        '1A_major_donor_home_event', '1B_private_dinner_series', '1C_exclusive_briefings', '1D_legacy_society',
        '2A_online_fundraising', '2B_social_media_drive', '2C_viral_challenge', '2D_crowdfunding',
        '3A_reactivation', '3B_lapsed_donor_winback', '3C_re_engagement',
        '4A_district_town_hall', '4B_rally_march', '4C_community_engagement',
        '5A_direct_mail', '5B_phone_banking', '5C_door_to_door', '5D_personal_visits',
        '6A_volunteer_recruitment', '6B_house_party_network',
        '7A_business_leader', '7B_pac_coordination'
    ))
);

CREATE INDEX idx_campaigns_tenant ON campaigns(tenant_id);
CREATE INDEX idx_campaigns_type ON campaigns(campaign_type);
CREATE INDEX idx_campaigns_status ON campaigns(status);
CREATE INDEX idx_campaigns_launch ON campaigns(scheduled_launch_at);
CREATE INDEX idx_campaigns_created ON campaigns(created_at DESC);


-- ========================================
-- TABLE 6: ANALYTICS_SUMMARY
-- Pre-computed analytics for dashboard
-- ========================================

CREATE TABLE analytics_summary (
    summary_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    summary_date DATE NOT NULL DEFAULT CURRENT_DATE,
    summary_type VARCHAR(50) NOT NULL, -- daily, weekly, monthly, quarterly, yearly
    
    -- Donor metrics
    total_donors INTEGER DEFAULT 0,
    new_donors INTEGER DEFAULT 0,
    active_donors INTEGER DEFAULT 0,
    lapsed_donors INTEGER DEFAULT 0,
    reactivated_donors INTEGER DEFAULT 0,
    
    -- Grade distribution
    donors_grade_a_plus INTEGER DEFAULT 0,
    donors_grade_a INTEGER DEFAULT 0,
    donors_grade_a_minus INTEGER DEFAULT 0,
    donors_grade_b_plus INTEGER DEFAULT 0,
    donors_grade_b INTEGER DEFAULT 0,
    donors_grade_b_minus INTEGER DEFAULT 0,
    donors_grade_c_plus INTEGER DEFAULT 0,
    donors_grade_c INTEGER DEFAULT 0,
    donors_grade_c_minus INTEGER DEFAULT 0,
    donors_grade_d INTEGER DEFAULT 0,
    donors_grade_f INTEGER DEFAULT 0,
    donors_grade_u INTEGER DEFAULT 0,
    
    -- Financial metrics
    total_raised DECIMAL(12, 2) DEFAULT 0,
    transaction_count INTEGER DEFAULT 0,
    average_donation DECIMAL(10, 2) DEFAULT 0,
    median_donation DECIMAL(10, 2) DEFAULT 0,
    largest_donation DECIMAL(12, 2) DEFAULT 0,
    
    -- Campaign metrics
    campaigns_launched INTEGER DEFAULT 0,
    campaigns_completed INTEGER DEFAULT 0,
    campaign_response_rate DECIMAL(5, 2),
    campaign_roi DECIMAL(10, 2),
    
    -- Engagement metrics
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    sms_sent INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    
    -- Computed at
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_summary UNIQUE (tenant_id, summary_date, summary_type)
);

CREATE INDEX idx_analytics_tenant ON analytics_summary(tenant_id);
CREATE INDEX idx_analytics_date ON analytics_summary(summary_date DESC);
CREATE INDEX idx_analytics_type ON analytics_summary(summary_type);


-- ========================================
-- TABLE 7: ENRICHMENT_QUEUE
-- BetterContact enrichment workflow
-- ========================================

CREATE TABLE enrichment_queue (
    queue_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    donor_id UUID NOT NULL REFERENCES donors(donor_id) ON DELETE CASCADE,
    
    -- Queue status
    status VARCHAR(50) DEFAULT 'pending', -- pending, processing, completed, failed
    priority INTEGER DEFAULT 5,           -- 1-10, higher = more urgent
    
    -- Request
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    requested_by UUID,
    enrichment_type VARCHAR(50),          -- full, email_only, phone_only, etc.
    
    -- Processing
    processing_started_at TIMESTAMP,
    processing_completed_at TIMESTAMP,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    
    -- Provider
    provider VARCHAR(100) DEFAULT 'BetterContact',
    provider_request_id VARCHAR(255),
    
    -- Results
    fields_enriched INTEGER DEFAULT 0,
    confidence_score DECIMAL(5, 2),
    cost DECIMAL(10, 4),
    
    -- Error handling
    error_message TEXT,
    last_error_at TIMESTAMP,
    
    -- Retry
    next_retry_at TIMESTAMP,
    
    CONSTRAINT valid_priority CHECK (priority BETWEEN 1 AND 10)
);

CREATE INDEX idx_enrichment_tenant ON enrichment_queue(tenant_id);
CREATE INDEX idx_enrichment_status ON enrichment_queue(status);
CREATE INDEX idx_enrichment_priority ON enrichment_queue(priority DESC) WHERE status = 'pending';
CREATE INDEX idx_enrichment_retry ON enrichment_queue(next_retry_at) WHERE status = 'failed' AND attempts < max_attempts;


-- ========================================
-- TABLE 8: DONOR_SEGMENTS
-- Dynamic donor segments for targeting
-- ========================================

CREATE TABLE donor_segments (
    segment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    
    -- Basic info
    segment_name VARCHAR(255) NOT NULL,
    description TEXT,
    segment_type VARCHAR(50),             -- static, dynamic, smart
    
    -- Dynamic filters (JSON query)
    filter_criteria JSONB,                -- SQL-like filter conditions
    
    -- Size
    estimated_size INTEGER,
    actual_size INTEGER,
    last_size_calculated_at TIMESTAMP,
    
    -- Usage
    used_in_campaigns_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP,
    
    -- Auto-refresh for dynamic segments
    auto_refresh BOOLEAN DEFAULT FALSE,
    refresh_frequency VARCHAR(50),        -- daily, weekly, monthly
    last_refreshed_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_segments_tenant ON donor_segments(tenant_id);
CREATE INDEX idx_segments_name ON donor_segments(segment_name);
CREATE INDEX idx_segments_type ON donor_segments(segment_type);


-- ========================================
-- TABLE 9: DONOR_SEGMENT_MEMBERS
-- Junction table for segment membership
-- ========================================

CREATE TABLE donor_segment_members (
    membership_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    segment_id UUID NOT NULL REFERENCES donor_segments(segment_id) ON DELETE CASCADE,
    donor_id UUID NOT NULL REFERENCES donors(donor_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    
    -- When added
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    added_by VARCHAR(50),                 -- manual, auto, import
    
    -- For dynamic segments
    automatically_added BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT unique_segment_membership UNIQUE (segment_id, donor_id)
);

CREATE INDEX idx_segment_members_segment ON donor_segment_members(segment_id);
CREATE INDEX idx_segment_members_donor ON donor_segment_members(donor_id);
CREATE INDEX idx_segment_members_tenant ON donor_segment_members(tenant_id);

-- Comments
COMMENT ON TABLE transactions IS 'All donation transactions with yearly partitioning for performance';
COMMENT ON TABLE candidates IS 'NC Republican candidates with bellwether tracking (21 top candidates)';
COMMENT ON TABLE campaigns IS 'Marketing campaigns across 22+ types and 7 categories';
COMMENT ON TABLE analytics_summary IS 'Pre-computed analytics refreshed nightly for dashboard performance';
COMMENT ON TABLE enrichment_queue IS 'BetterContact enrichment workflow with retry logic';
COMMENT ON TABLE donor_segments IS 'Dynamic donor segments for campaign targeting';
