-- ============================================================
-- BROYHILLGOP COMPLETE DATABASE SCHEMA
-- All 14 Ecosystems - PostgreSQL (Supabase)
-- ============================================================

-- Create schemas
CREATE SCHEMA IF NOT EXISTS nc_data_committee;
CREATE SCHEMA IF NOT EXISTS broyhillgop;

-- ============================================================
-- ECOSYSTEM 0: DATA HUB
-- ============================================================

CREATE TABLE broyhillgop.event_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    source_ecosystem VARCHAR(50),
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_event_log_type ON broyhillgop.event_log(event_type);
CREATE INDEX idx_event_log_created ON broyhillgop.event_log(created_at);

-- ============================================================
-- ECOSYSTEM 1: DONOR INTELLIGENCE
-- ============================================================

CREATE TABLE nc_data_committee.donors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100),
    suffix VARCHAR(20),
    nickname VARCHAR(50),
    
    -- Contact
    email_primary VARCHAR(255),
    email_secondary VARCHAR(255),
    email_status VARCHAR(20) DEFAULT 'unknown',
    phone_mobile VARCHAR(20),
    phone_home VARCHAR(20),
    phone_work VARCHAR(20),
    phone_status VARCHAR(20) DEFAULT 'unknown',
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    zip VARCHAR(10),
    zip_plus4 VARCHAR(4),
    county VARCHAR(100),
    address_status VARCHAR(20) DEFAULT 'unknown',
    
    -- Demographics
    date_of_birth DATE,
    gender VARCHAR(10),
    
    -- Professional
    employer VARCHAR(255),
    occupation VARCHAR(255),
    job_title VARCHAR(255),
    industry VARCHAR(100),
    
    -- Wealth Indicators
    estimated_wealth DECIMAL(15,2),
    home_value DECIMAL(15,2),
    is_business_owner BOOLEAN DEFAULT FALSE,
    net_worth_range VARCHAR(50),
    
    -- Political
    party_registration VARCHAR(20),
    voter_id VARCHAR(50),
    congressional_district VARCHAR(10),
    state_senate_district VARCHAR(10),
    state_house_district VARCHAR(10),
    precinct VARCHAR(50),
    
    -- Scoring (Ecosystem 1)
    lead_score INTEGER DEFAULT 0,
    grade VARCHAR(3) DEFAULT 'U',
    score_components JSONB,
    scored_at TIMESTAMPTZ,
    
    -- Faction (12 Factions)
    primary_faction VARCHAR(4),
    secondary_faction VARCHAR(4),
    faction_scores JSONB,
    faction_confidence DECIMAL(5,2),
    
    -- Giving
    lifetime_giving DECIMAL(12,2) DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    first_donation_date DATE,
    last_donation_date DATE,
    last_donation_amount DECIMAL(12,2),
    average_donation_amount DECIMAL(12,2),
    largest_donation_amount DECIMAL(12,2),
    
    -- Engagement
    email_open_rate DECIMAL(5,4) DEFAULT 0,
    email_click_rate DECIMAL(5,4) DEFAULT 0,
    last_contact_date DATE,
    last_contact_channel VARCHAR(20),
    contact_count INTEGER DEFAULT 0,
    
    -- Preferences
    do_not_email BOOLEAN DEFAULT FALSE,
    do_not_call BOOLEAN DEFAULT FALSE,
    do_not_mail BOOLEAN DEFAULT FALSE,
    do_not_sms BOOLEAN DEFAULT FALSE,
    do_not_contact BOOLEAN DEFAULT FALSE,
    is_deceased BOOLEAN DEFAULT FALSE,
    
    -- Enrichment
    enriched_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    linkedin_url VARCHAR(500),
    
    -- Source tracking
    source VARCHAR(50),
    source_date DATE,
    
    -- Tags and notes
    tags JSONB DEFAULT '[]',
    issues JSONB DEFAULT '[]',
    notes TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_donors_email ON nc_data_committee.donors(email_primary);
CREATE INDEX idx_donors_phone ON nc_data_committee.donors(phone_mobile);
CREATE INDEX idx_donors_name ON nc_data_committee.donors(last_name, first_name);
CREATE INDEX idx_donors_county ON nc_data_committee.donors(county);
CREATE INDEX idx_donors_grade ON nc_data_committee.donors(grade);
CREATE INDEX idx_donors_faction ON nc_data_committee.donors(primary_faction);
CREATE INDEX idx_donors_score ON nc_data_committee.donors(lead_score DESC);

CREATE TABLE broyhillgop.donor_faction_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES nc_data_committee.donors(id) ON DELETE CASCADE,
    faction_code VARCHAR(4) NOT NULL,
    score DECIMAL(5,2) NOT NULL,
    confidence DECIMAL(5,2),
    calculation_version VARCHAR(10),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ECOSYSTEM 2: DONATION TRACKING
-- ============================================================

CREATE TABLE broyhillgop.donation_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source
    processor VARCHAR(20) NOT NULL, -- winred, anedot
    processor_transaction_id VARCHAR(100) NOT NULL,
    
    -- Attribution
    candidate_id UUID,
    campaign_id UUID,
    tracking_code VARCHAR(100),
    
    -- Donor info (from webhook)
    donor_id UUID,
    donor_email VARCHAR(255),
    donor_phone VARCHAR(20),
    donor_first_name VARCHAR(100),
    donor_last_name VARCHAR(100),
    donor_address VARCHAR(255),
    donor_city VARCHAR(100),
    donor_state VARCHAR(2),
    donor_zip VARCHAR(10),
    
    -- Transaction
    amount DECIMAL(10,2) NOT NULL,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurring_plan_id VARCHAR(100),
    
    -- Commission (8%)
    commission_rate DECIMAL(5,4) DEFAULT 0.08,
    commission_amount DECIMAL(10,2),
    
    -- Status
    is_refunded BOOLEAN DEFAULT FALSE,
    refunded_at TIMESTAMPTZ,
    refund_data JSONB,
    
    -- Timestamps
    donated_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Raw data
    raw_payload JSONB,
    
    UNIQUE(processor, processor_transaction_id)
);

CREATE INDEX idx_receipts_candidate ON broyhillgop.donation_receipts(candidate_id);
CREATE INDEX idx_receipts_campaign ON broyhillgop.donation_receipts(campaign_id);
CREATE INDEX idx_receipts_donor ON broyhillgop.donation_receipts(donor_id);
CREATE INDEX idx_receipts_date ON broyhillgop.donation_receipts(donated_at);
CREATE INDEX idx_receipts_tracking ON broyhillgop.donation_receipts(tracking_code);

-- ============================================================
-- ECOSYSTEM 3: CAMPAIGN OUTREACH
-- ============================================================

CREATE TABLE broyhillgop.campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    
    -- Identity
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50),
    tracking_code VARCHAR(100),
    
    -- Type (22 types)
    campaign_type VARCHAR(50) NOT NULL,
    channel VARCHAR(20) NOT NULL, -- email, sms, mail, call
    
    -- Content
    subject_line VARCHAR(255),
    preview_text VARCHAR(255),
    content TEXT,
    template_id VARCHAR(50),
    
    -- Targeting
    target_criteria JSONB DEFAULT '{}',
    estimated_audience INTEGER DEFAULT 0,
    
    -- A/B Testing
    is_ab_test BOOLEAN DEFAULT FALSE,
    ab_variant VARCHAR(1),
    ab_parent_id UUID,
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft', -- draft, scheduled, sending, sent, cancelled
    
    -- Schedule
    scheduled_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    
    -- Metrics
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    opened_count INTEGER DEFAULT 0,
    clicked_count INTEGER DEFAULT 0,
    bounced_count INTEGER DEFAULT 0,
    unsubscribed_count INTEGER DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0,
    
    -- Audit
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_campaigns_candidate ON broyhillgop.campaigns(candidate_id);
CREATE INDEX idx_campaigns_status ON broyhillgop.campaigns(status);
CREATE INDEX idx_campaigns_type ON broyhillgop.campaigns(campaign_type);

CREATE TABLE broyhillgop.campaign_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES broyhillgop.campaigns(id) ON DELETE CASCADE,
    donor_id UUID REFERENCES nc_data_committee.donors(id) ON DELETE CASCADE,
    activity_type VARCHAR(20) NOT NULL, -- sent, delivered, opened, clicked, bounced, unsubscribed, donated
    channel VARCHAR(20),
    metadata JSONB,
    occurred_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_activities_campaign ON broyhillgop.campaign_activities(campaign_id);
CREATE INDEX idx_activities_donor ON broyhillgop.campaign_activities(donor_id);
CREATE INDEX idx_activities_type ON broyhillgop.campaign_activities(activity_type);

-- ============================================================
-- ECOSYSTEM 4: MATCHING
-- ============================================================

CREATE TABLE broyhillgop.donor_candidate_affinity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES nc_data_committee.donors(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL,
    
    affinity_score DECIMAL(5,2) NOT NULL,
    faction_match_score DECIMAL(5,2),
    geographic_score DECIMAL(5,2),
    issue_match_score DECIMAL(5,2),
    
    suggested_ask_amount INTEGER,
    priority_rank INTEGER,
    
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    calculation_version VARCHAR(10),
    
    UNIQUE(donor_id, candidate_id)
);

CREATE INDEX idx_affinity_donor ON broyhillgop.donor_candidate_affinity(donor_id);
CREATE INDEX idx_affinity_candidate ON broyhillgop.donor_candidate_affinity(candidate_id);
CREATE INDEX idx_affinity_score ON broyhillgop.donor_candidate_affinity(affinity_score DESC);

-- ============================================================
-- ECOSYSTEM 5: VOLUNTEERS
-- ============================================================

CREATE TABLE broyhillgop.volunteers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID,
    
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    
    status VARCHAR(20) DEFAULT 'active',
    grade VARCHAR(3) DEFAULT 'C',
    
    availability JSONB DEFAULT '[]',
    skills JSONB DEFAULT '[]',
    languages JSONB DEFAULT '["English"]',
    has_vehicle BOOLEAN DEFAULT FALSE,
    
    total_activities INTEGER DEFAULT 0,
    total_hours DECIMAL(8,2) DEFAULT 0,
    last_activity_date DATE,
    
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE broyhillgop.volunteer_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID REFERENCES broyhillgop.volunteers(id) ON DELETE CASCADE,
    candidate_id UUID,
    
    activity_type VARCHAR(50) NOT NULL, -- 56 types
    description TEXT,
    location VARCHAR(255),
    
    scheduled_start TIMESTAMPTZ,
    scheduled_end TIMESTAMPTZ,
    actual_start TIMESTAMPTZ,
    actual_end TIMESTAMPTZ,
    hours_logged DECIMAL(5,2),
    
    status VARCHAR(20) DEFAULT 'scheduled',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ECOSYSTEM 6: EVENTS
-- ============================================================

CREATE TABLE broyhillgop.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    
    name VARCHAR(255) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    description TEXT,
    
    venue_name VARCHAR(255),
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    zip VARCHAR(10),
    
    is_virtual BOOLEAN DEFAULT FALSE,
    virtual_link VARCHAR(500),
    
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    
    capacity INTEGER,
    is_ticketed BOOLEAN DEFAULT FALSE,
    ticket_price DECIMAL(10,2),
    
    rsvp_count INTEGER DEFAULT 0,
    attended_count INTEGER DEFAULT 0,
    revenue_generated DECIMAL(12,2) DEFAULT 0,
    
    status VARCHAR(20) DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE broyhillgop.event_rsvps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES broyhillgop.events(id) ON DELETE CASCADE,
    donor_id UUID REFERENCES nc_data_committee.donors(id),
    
    guest_count INTEGER DEFAULT 1,
    ticket_type VARCHAR(50) DEFAULT 'general',
    amount_paid DECIMAL(10,2) DEFAULT 0,
    
    status VARCHAR(20) DEFAULT 'registered',
    checked_in_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ECOSYSTEM 7: ANALYTICS (Views)
-- ============================================================

CREATE OR REPLACE VIEW broyhillgop.v_revenue_by_day AS
SELECT 
    DATE(donated_at) as date,
    candidate_id,
    COUNT(*) as donation_count,
    SUM(amount) as total_amount,
    SUM(commission_amount) as total_commission,
    AVG(amount) as avg_amount
FROM broyhillgop.donation_receipts
WHERE is_refunded = FALSE
GROUP BY DATE(donated_at), candidate_id;

CREATE OR REPLACE VIEW broyhillgop.v_campaign_performance AS
SELECT 
    c.id,
    c.name,
    c.campaign_type,
    c.channel,
    c.candidate_id,
    c.sent_count,
    c.opened_count,
    c.clicked_count,
    c.donation_count,
    c.total_revenue,
    CASE WHEN c.sent_count > 0 THEN ROUND((c.opened_count::DECIMAL / c.sent_count) * 100, 2) ELSE 0 END as open_rate,
    CASE WHEN c.opened_count > 0 THEN ROUND((c.clicked_count::DECIMAL / c.opened_count) * 100, 2) ELSE 0 END as click_rate,
    CASE WHEN c.sent_count > 0 THEN ROUND(c.total_revenue / c.sent_count, 2) ELSE 0 END as revenue_per_email
FROM broyhillgop.campaigns c
WHERE c.status = 'sent';

-- ============================================================
-- ECOSYSTEM 8: ADMIN
-- ============================================================

CREATE TABLE broyhillgop.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    
    role VARCHAR(50) DEFAULT 'viewer',
    candidate_id UUID,
    
    status VARCHAR(20) DEFAULT 'active',
    last_login_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE broyhillgop.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_user ON broyhillgop.audit_logs(user_id);
CREATE INDEX idx_audit_action ON broyhillgop.audit_logs(action);
CREATE INDEX idx_audit_created ON broyhillgop.audit_logs(created_at);

-- ============================================================
-- ECOSYSTEM 9: CANDIDATES
-- ============================================================

CREATE TABLE broyhillgop.candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Personal
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    display_name VARCHAR(255),
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    
    -- Campaign
    office VARCHAR(255) NOT NULL,
    office_type VARCHAR(20) NOT NULL, -- federal, statewide, state_leg, county, local
    district VARCHAR(50),
    county VARCHAR(100),
    party VARCHAR(50) DEFAULT 'Republican',
    election_date DATE,
    
    -- Committee
    committee_name VARCHAR(255),
    committee_address VARCHAR(255),
    committee_city VARCHAR(100),
    committee_state VARCHAR(2) DEFAULT 'NC',
    committee_zip VARCHAR(10),
    
    -- Tracking
    tracking_prefix VARCHAR(20),
    
    -- Online
    winred_url VARCHAR(500),
    anedot_url VARCHAR(500),
    website_url VARCHAR(500),
    facebook_url VARCHAR(500),
    twitter_url VARCHAR(500),
    instagram_url VARCHAR(500),
    
    -- Profile
    photo_url VARCHAR(500),
    public_bio TEXT,
    public_issues JSONB DEFAULT '[]',
    questionnaire_responses JSONB DEFAULT '{}',
    
    -- Faction
    primary_faction VARCHAR(4),
    issues JSONB DEFAULT '[]',
    
    -- Pricing (Local Candidates)
    pricing_tier VARCHAR(20),
    monthly_retainer INTEGER DEFAULT 0,
    license_fee INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending_onboarding',
    onboarding_step INTEGER DEFAULT 1,
    onboarding_completed_at TIMESTAMPTZ,
    activated_at TIMESTAMPTZ,
    subscription_started_at TIMESTAMPTZ,
    
    -- QuickBooks
    quickbooks_customer_id VARCHAR(50),
    
    -- Slug for public URL
    slug VARCHAR(100) UNIQUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_candidates_status ON broyhillgop.candidates(status);
CREATE INDEX idx_candidates_office ON broyhillgop.candidates(office_type);
CREATE INDEX idx_candidates_county ON broyhillgop.candidates(county);

-- ============================================================
-- ECOSYSTEM 11: TRAINING
-- ============================================================

CREATE TABLE broyhillgop.training_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE,
    content TEXT,
    tags JSONB DEFAULT '[]',
    sort_order INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE broyhillgop.training_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    article_id UUID REFERENCES broyhillgop.training_articles(id),
    viewed_at TIMESTAMPTZ,
    view_count INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ
);

-- ============================================================
-- ECOSYSTEM 12: STAFF OPERATIONS
-- ============================================================

CREATE TABLE broyhillgop.staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    
    role VARCHAR(50) NOT NULL,
    commission_rate DECIMAL(5,4) DEFAULT 0,
    
    status VARCHAR(20) DEFAULT 'active',
    hired_at DATE,
    terminated_at DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE broyhillgop.candidate_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES broyhillgop.staff(id),
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    role VARCHAR(50) DEFAULT 'primary',
    status VARCHAR(20) DEFAULT 'active',
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

CREATE TABLE broyhillgop.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    
    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    retainer_amount DECIMAL(10,2) DEFAULT 0,
    commission_amount DECIMAL(10,2) DEFAULT 0,
    total_donations DECIMAL(12,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    
    status VARCHAR(20) DEFAULT 'pending',
    due_date DATE,
    paid_at TIMESTAMPTZ,
    payment_method VARCHAR(50),
    payment_reference VARCHAR(100),
    
    quickbooks_id VARCHAR(50),
    synced_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ECOSYSTEM 13: AI HUB
-- ============================================================

CREATE TABLE broyhillgop.ai_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ecosystem VARCHAR(50) NOT NULL,
    prompt_key VARCHAR(100) NOT NULL,
    cost DECIMAL(10,6) NOT NULL,
    tokens INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_usage_ecosystem ON broyhillgop.ai_usage(ecosystem);
CREATE INDEX idx_ai_usage_created ON broyhillgop.ai_usage(created_at);

-- ============================================================
-- ECOSYSTEM 14: DATA GOVERNANCE
-- ============================================================

CREATE TABLE broyhillgop.data_access_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    candidate_id UUID,
    
    access_type VARCHAR(50) NOT NULL, -- view, search, export, update
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    record_count INTEGER DEFAULT 0,
    filters JSONB,
    
    ip_address VARCHAR(45),
    user_agent TEXT,
    accessed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_access_log_user ON broyhillgop.data_access_logs(user_id);
CREATE INDEX idx_access_log_candidate ON broyhillgop.data_access_logs(candidate_id);
CREATE INDEX idx_access_log_accessed ON broyhillgop.data_access_logs(accessed_at);

CREATE TABLE broyhillgop.data_anomalies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    access_log_id UUID REFERENCES broyhillgop.data_access_logs(id),
    user_id UUID,
    candidate_id UUID,
    
    anomaly_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL, -- info, warning, critical
    details TEXT,
    
    status VARCHAR(20) DEFAULT 'pending',
    resolution TEXT,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,
    
    detected_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE broyhillgop.data_governance_agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    
    agreement_version VARCHAR(10) DEFAULT '1.0',
    licensed_data_types JSONB DEFAULT '["donors", "contributions"]',
    licensed_counties JSONB DEFAULT '[]',
    max_exports_per_month INTEGER DEFAULT 10,
    max_records_per_export INTEGER DEFAULT 5000,
    requires_watermark BOOLEAN DEFAULT TRUE,
    terms_text TEXT,
    
    signed_by VARCHAR(255),
    signature TEXT,
    signed_at TIMESTAMPTZ,
    
    status VARCHAR(20) DEFAULT 'pending',
    expiration_date DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CONTRIBUTIONS TABLE (FEC/NCBOE Data)
-- ============================================================

CREATE TABLE nc_data_committee.contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES nc_data_committee.donors(id),
    
    amount DECIMAL(10,2) NOT NULL,
    contribution_date DATE NOT NULL,
    contribution_type VARCHAR(50),
    
    committee_name VARCHAR(255),
    committee_id VARCHAR(50),
    candidate_name VARCHAR(255),
    
    filing_type VARCHAR(20), -- fec, ncboe, winred, anedot
    filing_id VARCHAR(100),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_contributions_donor ON nc_data_committee.contributions(donor_id);
CREATE INDEX idx_contributions_date ON nc_data_committee.contributions(contribution_date);
CREATE INDEX idx_contributions_committee ON nc_data_committee.contributions(committee_id);

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function to update donor giving stats
CREATE OR REPLACE FUNCTION update_donor_giving_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE nc_data_committee.donors
    SET 
        donation_count = donation_count + 1,
        lifetime_giving = lifetime_giving + NEW.amount,
        last_donation_date = NEW.donated_at::DATE,
        last_donation_amount = NEW.amount,
        average_donation_amount = (lifetime_giving + NEW.amount) / (donation_count + 1),
        updated_at = NOW()
    WHERE id = NEW.donor_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for donation tracking
CREATE TRIGGER trg_update_donor_stats
AFTER INSERT ON broyhillgop.donation_receipts
FOR EACH ROW
WHEN (NEW.donor_id IS NOT NULL AND NEW.is_refunded = FALSE)
EXECUTE FUNCTION update_donor_giving_stats();

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at
CREATE TRIGGER trg_donors_updated_at BEFORE UPDATE ON nc_data_committee.donors FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_campaigns_updated_at BEFORE UPDATE ON broyhillgop.campaigns FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_candidates_updated_at BEFORE UPDATE ON broyhillgop.candidates FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_volunteers_updated_at BEFORE UPDATE ON broyhillgop.volunteers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_events_updated_at BEFORE UPDATE ON broyhillgop.events FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- END OF SCHEMA
-- ============================================================
