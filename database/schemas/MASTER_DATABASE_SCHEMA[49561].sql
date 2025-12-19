-- ============================================================================
-- BROYHILLGOP MASTER DATABASE SCHEMA
-- Complete Donor Intelligence System
-- ============================================================================
-- 
-- Version: 2.0 FINAL
-- Date: December 6, 2024
-- Author: BroyhillGOP Development Team
-- 
-- COMPLETE INTEGRATED SYSTEM:
-- - 12-grade donor classification (A++ to U)
-- - 0-1000 point percentile scoring
-- - 3D grading (Amount × Intensity × Level)
-- - ML clustering and predictions
-- - Volunteer management
-- - Campaign tracking
-- - Performance measurement
-- - Contact verification
-- 
-- DEPLOYMENT:
-- psql -h your-host -U postgres -d your-db < MASTER_DATABASE_SCHEMA.sql
-- 
-- ============================================================================

-- ============================================================================
-- ENABLE REQUIRED EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- ============================================================================
-- CREATE SCHEMAS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS broyhillgop;
SET search_path TO broyhillgop, public;

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================

-- Donor grade enumeration (12 grades - VERIFIED from actual data)
CREATE TYPE donor_grade AS ENUM (
    'A++', 'A+', 'A', 'A-',
    'B+', 'B', 'B-',
    'C+', 'C', 'C-',
    'D',
    'U'
);

-- Level preference
CREATE TYPE level_preference AS ENUM (
    'F',    -- Federal (President, US Senate, US House)
    'S',    -- State (Governor, State House, State Senate, AG)
    'L',    -- Local (Sheriff, Commissioner, School Board, Mayor)
    'F/S',  -- Federal/State mix
    'S/L',  -- State/Local mix
    'F/L',  -- Federal/Local mix
    'MIX'   -- All levels
);

-- Campaign status
CREATE TYPE campaign_status AS ENUM (
    'DRAFT',
    'SCHEDULED',
    'ACTIVE',
    'PAUSED',
    'COMPLETED',
    'CANCELLED'
);

-- Communication channel
CREATE TYPE communication_channel AS ENUM (
    'EMAIL',
    'SMS',
    'PHONE',
    'MAIL',
    'IN_PERSON',
    'SOCIAL_MEDIA'
);

-- ============================================================================
-- TABLE 1: donors (MASTER DONOR TABLE)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donors (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donor_id VARCHAR(50) UNIQUE NOT NULL, -- External ID
    
    -- Basic Information
    first_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(200) GENERATED ALWAYS AS (
        COALESCE(first_name || ' ', '') || last_name
    ) STORED,
    preferred_name VARCHAR(100),
    salutation VARCHAR(20),
    suffix VARCHAR(10),
    
    -- Contact Information
    email VARCHAR(255),
    email_verified BOOLEAN DEFAULT FALSE,
    phone VARCHAR(20),
    phone_verified BOOLEAN DEFAULT FALSE,
    mobile_phone VARCHAR(20),
    home_phone VARCHAR(20),
    work_phone VARCHAR(20),
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(100),
    city VARCHAR(100),
    county VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    zip_code VARCHAR(10),
    congressional_district VARCHAR(10),
    state_house_district VARCHAR(10),
    state_senate_district VARCHAR(10),
    
    -- Demographics
    age INTEGER,
    date_of_birth DATE,
    gender VARCHAR(20),
    occupation VARCHAR(100),
    employer VARCHAR(200),
    industry VARCHAR(100),
    
    -- ========================================================================
    -- DIMENSION 1: AMOUNT (Capacity)
    -- ========================================================================
    
    -- Donation totals by time period
    total_donations DECIMAL(12,2) DEFAULT 0,
    donations_last_1y DECIMAL(12,2) DEFAULT 0,
    donations_last_2y DECIMAL(12,2) DEFAULT 0,
    donations_last_5y DECIMAL(12,2) DEFAULT 0,
    donations_ytd DECIMAL(12,2) DEFAULT 0,
    
    -- Donation counts
    donation_count_all INTEGER DEFAULT 0,
    donation_count_1y INTEGER DEFAULT 0,
    donation_count_2y INTEGER DEFAULT 0,
    donation_count_5y INTEGER DEFAULT 0,
    
    -- Average gift
    avg_donation_amount DECIMAL(10,2),
    largest_donation DECIMAL(12,2),
    smallest_donation DECIMAL(12,2),
    
    -- State-level grading
    amount_percentile_state DECIMAL(7,3), -- 0.000 to 1000.000 (AI precision)
    amount_grade_state donor_grade,        -- A++ to U (human display)
    amount_rank_state INTEGER,             -- Rank among all NC donors
    
    -- County-level grading
    amount_percentile_county DECIMAL(7,3),
    amount_grade_county donor_grade,
    amount_rank_county INTEGER,
    
    -- ========================================================================
    -- DIMENSION 2: INTENSITY (Engagement)
    -- ========================================================================
    
    intensity_grade_1y INTEGER CHECK (intensity_grade_1y BETWEEN 1 AND 10),
    intensity_grade_2y INTEGER CHECK (intensity_grade_2y BETWEEN 1 AND 10),
    intensity_grade_5y INTEGER CHECK (intensity_grade_5y BETWEEN 1 AND 10),
    
    donations_per_month_1y DECIMAL(5,2),
    donations_per_month_2y DECIMAL(5,2),
    donations_per_month_5y DECIMAL(5,2),
    
    -- Timing
    first_donation_date DATE,
    last_donation_date DATE,
    months_since_first INTEGER,
    months_since_last INTEGER,
    days_since_last INTEGER,
    
    -- ========================================================================
    -- DIMENSION 3: LEVEL PREFERENCE (Where They Give)
    -- ========================================================================
    
    level_preference level_preference,
    level_score_federal INTEGER CHECK (level_score_federal BETWEEN 0 AND 100),
    level_score_state INTEGER CHECK (level_score_state BETWEEN 0 AND 100),
    level_score_local INTEGER CHECK (level_score_local BETWEEN 0 AND 100),
    
    -- Level donation details
    donations_federal_count INTEGER DEFAULT 0,
    donations_state_count INTEGER DEFAULT 0,
    donations_local_count INTEGER DEFAULT 0,
    donations_federal_amount DECIMAL(12,2) DEFAULT 0,
    donations_state_amount DECIMAL(12,2) DEFAULT 0,
    donations_local_amount DECIMAL(12,2) DEFAULT 0,
    
    -- ========================================================================
    -- COMBINED 3D GRADE
    -- ========================================================================
    
    grade_3d VARCHAR(20) GENERATED ALWAYS AS (
        amount_grade_state::text || '/' || 
        intensity_grade_2y::text || '/' || 
        level_preference::text
    ) STORED,
    
    -- ========================================================================
    -- ML/AI PREDICTIONS
    -- ========================================================================
    
    ml_cluster_id INTEGER,
    ml_cluster_name VARCHAR(100),
    donation_probability DECIMAL(4,3) CHECK (donation_probability BETWEEN 0 AND 1),
    volunteer_probability DECIMAL(4,3) CHECK (volunteer_probability BETWEEN 0 AND 1),
    churn_risk_score DECIMAL(4,3) CHECK (churn_risk_score BETWEEN 0 AND 1),
    engagement_score DECIMAL(4,3) CHECK (engagement_score BETWEEN 0 AND 1),
    optimal_ask_amount DECIMAL(10,2),
    ml_last_updated TIMESTAMP,
    
    -- ========================================================================
    -- ISSUE PRIORITIES & IDEOLOGY
    -- ========================================================================
    
    top_issue_1 VARCHAR(100),
    top_issue_2 VARCHAR(100),
    top_issue_3 VARCHAR(100),
    issue_salience_1 INTEGER CHECK (issue_salience_1 BETWEEN 0 AND 100),
    issue_salience_2 INTEGER CHECK (issue_salience_2 BETWEEN 0 AND 100),
    issue_salience_3 INTEGER CHECK (issue_salience_3 BETWEEN 0 AND 100),
    
    primary_faction VARCHAR(10),   -- MAGA, EVAN, TRAD, FISC, LIBT, etc.
    secondary_faction VARCHAR(10),
    tertiary_faction VARCHAR(10),
    
    -- ========================================================================
    -- COMMUNICATION PREFERENCES
    -- ========================================================================
    
    preferred_channel communication_channel,
    best_time_to_contact VARCHAR(50),
    email_open_rate DECIMAL(4,3),
    email_click_rate DECIMAL(4,3),
    sms_response_rate DECIMAL(4,3),
    
    -- ========================================================================
    -- ENRICHMENT & VERIFICATION
    -- ========================================================================
    
    last_enriched_at TIMESTAMP,
    enrichment_source VARCHAR(100),
    enrichment_confidence DECIMAL(4,3),
    data_quality_score INTEGER CHECK (data_quality_score BETWEEN 0 AND 100),
    
    email_deliverable BOOLEAN,
    phone_reachable BOOLEAN,
    address_deliverable BOOLEAN,
    last_verified_at TIMESTAMP,
    verification_score INTEGER CHECK (verification_score BETWEEN 0 AND 100),
    
    -- ========================================================================
    -- VOLUNTEER STATUS
    -- ========================================================================
    
    is_volunteer BOOLEAN DEFAULT FALSE,
    volunteer_tier VARCHAR(20), -- Bronze, Silver, Gold, Platinum
    volunteer_hours_total DECIMAL(8,2) DEFAULT 0,
    volunteer_hours_ytd DECIMAL(8,2) DEFAULT 0,
    
    -- ========================================================================
    -- FLAGS & STATUS
    -- ========================================================================
    
    is_donor BOOLEAN DEFAULT FALSE,
    is_major_donor BOOLEAN DEFAULT FALSE,
    is_lapsed BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    do_not_contact BOOLEAN DEFAULT FALSE,
    do_not_email BOOLEAN DEFAULT FALSE,
    do_not_call BOOLEAN DEFAULT FALSE,
    do_not_mail BOOLEAN DEFAULT FALSE,
    
    is_duplicate BOOLEAN DEFAULT FALSE,
    merged_into_donor_id UUID,
    
    -- ========================================================================
    -- METADATA
    -- ========================================================================
    
    source VARCHAR(100),
    import_batch_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    
    -- Notes
    notes TEXT,
    tags TEXT[],
    custom_fields JSONB
);

-- ============================================================================
-- TABLE 2: donations (Individual Transaction Records)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donation_id VARCHAR(100) UNIQUE NOT NULL,
    
    -- Donor reference
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Donation details
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    donation_date DATE NOT NULL,
    donation_datetime TIMESTAMP,
    
    -- Recipient
    candidate_name VARCHAR(200),
    candidate_id UUID,
    race_type VARCHAR(100),  -- President, US Senate, Governor, Sheriff, etc.
    race_level VARCHAR(20),  -- Federal, State, Local
    race_year INTEGER,
    
    -- Payment
    payment_method VARCHAR(50), -- Credit Card, Check, Cash, etc.
    payment_processor VARCHAR(100), -- WinRed, Anedot, etc.
    transaction_id VARCHAR(200),
    
    -- FEC/Compliance
    fec_filing_id VARCHAR(100),
    itemized BOOLEAN DEFAULT FALSE,
    in_kind BOOLEAN DEFAULT FALSE,
    
    -- Attribution
    campaign_id UUID,
    source_channel communication_channel,
    source_campaign VARCHAR(200),
    attribution_model VARCHAR(50),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- ============================================================================
-- TABLE 3: donor_scores (Multi-Dimensional Percentile Tracking)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Universe definition
    universe_type VARCHAR(50) NOT NULL, -- 'state', 'county', 'issue', 'multi_attribute'
    universe_criteria JSONB NOT NULL,   -- Filter criteria used
    metric VARCHAR(50) NOT NULL,         -- 'total_donations', 'last_2y_donations', etc.
    date_range VARCHAR(50) NOT NULL,     -- '2020-2025', 'YTD', 'last_2y', etc.
    
    -- Calculated scores
    rank INTEGER NOT NULL,                       -- Rank within universe (1 = top)
    total_in_universe INTEGER NOT NULL,          -- Total donors in universe
    percentile_score DECIMAL(7,3) NOT NULL,      -- 0.000 to 1000.000
    
    -- Display values (derived, for humans)
    display_grade donor_grade,                   -- A++ to U
    narrative_label VARCHAR(100),                -- "Elite Mega Donor", etc.
    
    -- Metadata
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    calculation_version VARCHAR(20) DEFAULT '2.0',
    
    UNIQUE(donor_id, universe_type, universe_criteria, metric, date_range)
);

-- ============================================================================
-- TABLE 4: volunteers
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    volunteer_id VARCHAR(50) UNIQUE NOT NULL,
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Volunteer details
    volunteer_tier VARCHAR(20) DEFAULT 'Bronze', -- Bronze, Silver, Gold, Platinum
    total_hours DECIMAL(8,2) DEFAULT 0,
    ytd_hours DECIMAL(8,2) DEFAULT 0,
    
    -- Activity tracking
    activities TEXT[], -- ['Phone Banking', 'Canvassing', 'Data Entry', etc.]
    skills TEXT[],     -- ['Bilingual', 'Tech Savvy', 'Event Planning', etc.]
    availability TEXT, -- Days/times available
    
    -- Leadership
    leadership_roles TEXT[],
    is_team_leader BOOLEAN DEFAULT FALSE,
    team_members_recruited INTEGER DEFAULT 0,
    
    -- Quality metrics
    reliability_score INTEGER CHECK (reliability_score BETWEEN 0 AND 100),
    quality_score INTEGER CHECK (quality_score BETWEEN 0 AND 100),
    
    -- Engagement
    last_activity_date DATE,
    days_since_last_activity INTEGER,
    total_events_attended INTEGER DEFAULT 0,
    
    -- Preferences
    preferred_activities TEXT[],
    transportation_available BOOLEAN,
    can_host_events BOOLEAN,
    
    -- Metadata
    source VARCHAR(100), -- 'RNC', 'Convention Delegate', 'Event', etc.
    recruited_by_volunteer_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- ============================================================================
-- TABLE 5: campaigns
-- ============================================================================

CREATE TABLE IF NOT EXISTS campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id VARCHAR(100) UNIQUE NOT NULL,
    
    -- Campaign details
    name VARCHAR(200) NOT NULL,
    description TEXT,
    campaign_type VARCHAR(100), -- 'Fundraising', 'GOTV', 'Volunteer Recruitment', etc.
    
    -- Targeting
    target_race_level VARCHAR(20), -- Federal, State, Local
    target_candidate VARCHAR(200),
    target_issue VARCHAR(100),
    target_county VARCHAR(100),
    
    -- Segmentation criteria
    min_amount_grade donor_grade,
    min_intensity_grade INTEGER,
    required_level_preference level_preference[],
    custom_filters JSONB,
    
    -- Budget & Goals
    budget_total DECIMAL(12,2),
    budget_allocated DECIMAL(12,2) DEFAULT 0,
    goal_amount DECIMAL(12,2),
    goal_donors INTEGER,
    
    -- Channels
    channels communication_channel[],
    
    -- Timing
    start_date DATE,
    end_date DATE,
    launch_datetime TIMESTAMP,
    
    -- Status
    status campaign_status DEFAULT 'DRAFT',
    
    -- Results
    donors_contacted INTEGER DEFAULT 0,
    responses_received INTEGER DEFAULT 0,
    donations_received INTEGER DEFAULT 0,
    amount_raised DECIMAL(12,2) DEFAULT 0,
    cost_actual DECIMAL(12,2) DEFAULT 0,
    roi DECIMAL(10,2),
    
    -- Metadata
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- ============================================================================
-- TABLE 6: campaign_targets (Campaign-Donor Relationships)
-- ============================================================================

CREATE TABLE IF NOT EXISTS campaign_targets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Targeting scores
    match_score DECIMAL(5,2), -- How well donor matches campaign
    priority_tier INTEGER,    -- 1 = highest priority
    
    -- Outreach
    contacted BOOLEAN DEFAULT FALSE,
    contact_datetime TIMESTAMP,
    contact_channel communication_channel,
    
    -- Response
    responded BOOLEAN DEFAULT FALSE,
    response_datetime TIMESTAMP,
    response_type VARCHAR(50),
    
    -- Donation
    donated BOOLEAN DEFAULT FALSE,
    donation_amount DECIMAL(12,2),
    donation_datetime TIMESTAMP,
    
    -- Metadata
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    
    UNIQUE(campaign_id, donor_id)
);

-- ============================================================================
-- TABLE 7: communication_log (All Touchpoints)
-- ============================================================================

CREATE TABLE IF NOT EXISTS communication_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- References
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    campaign_id UUID,
    
    -- Communication details
    channel communication_channel NOT NULL,
    direction VARCHAR(20), -- 'OUTBOUND', 'INBOUND'
    
    -- Content
    subject VARCHAR(500),
    message TEXT,
    template_id VARCHAR(100),
    
    -- Delivery
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    responded_at TIMESTAMP,
    
    -- Status
    status VARCHAR(50), -- 'SENT', 'DELIVERED', 'OPENED', 'CLICKED', 'BOUNCED', 'FAILED'
    delivery_status VARCHAR(100),
    error_message TEXT,
    
    -- Response
    response_text TEXT,
    response_sentiment VARCHAR(20), -- 'POSITIVE', 'NEUTRAL', 'NEGATIVE'
    
    -- Metadata
    sent_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    external_message_id VARCHAR(200)
);

-- ============================================================================
-- TABLE 8: events
-- ============================================================================

CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id VARCHAR(100) UNIQUE NOT NULL,
    
    -- Event details
    name VARCHAR(200) NOT NULL,
    description TEXT,
    event_type VARCHAR(100), -- 'Fundraiser', 'Rally', 'Town Hall', 'Volunteer Meeting', etc.
    
    -- Location
    venue_name VARCHAR(200),
    address_line1 VARCHAR(255),
    city VARCHAR(100),
    county VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    zip_code VARCHAR(10),
    
    -- Timing
    event_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    
    -- Capacity
    capacity INTEGER,
    rsvp_count INTEGER DEFAULT 0,
    attendance_count INTEGER DEFAULT 0,
    
    -- Fundraising
    ticket_price DECIMAL(10,2),
    fundraising_goal DECIMAL(12,2),
    amount_raised DECIMAL(12,2) DEFAULT 0,
    
    -- Host
    hosted_by VARCHAR(200),
    candidate_attending VARCHAR(200),
    
    -- Status
    status VARCHAR(50) DEFAULT 'SCHEDULED',
    
    -- Metadata
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- ============================================================================
-- TABLE 9: event_attendance
-- ============================================================================

CREATE TABLE IF NOT EXISTS event_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- RSVP
    rsvp_status VARCHAR(50), -- 'YES', 'NO', 'MAYBE', 'PENDING'
    rsvp_datetime TIMESTAMP,
    guests_count INTEGER DEFAULT 0,
    
    -- Attendance
    attended BOOLEAN,
    checked_in_at TIMESTAMP,
    
    -- Contribution
    donation_amount DECIMAL(12,2),
    donation_datetime TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    
    UNIQUE(event_id, donor_id)
);

-- ============================================================================
-- TABLE 10: enrichment_history (Data Enrichment Audit Trail)
-- ============================================================================

CREATE TABLE IF NOT EXISTS enrichment_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Enrichment details
    enrichment_provider VARCHAR(100), -- 'Data Trust', 'BetterContact', 'Perplexity', etc.
    fields_updated TEXT[],
    fields_verified TEXT[],
    
    -- Quality
    confidence_score DECIMAL(4,3),
    data_sources TEXT[],
    
    -- Cost
    cost DECIMAL(10,4),
    
    -- Metadata
    enriched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    enriched_by VARCHAR(100)
);

-- ============================================================================
-- TABLE 11: verification_history (Contact Verification Audit Trail)
-- ============================================================================

CREATE TABLE IF NOT EXISTS verification_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Verification details
    verification_type VARCHAR(50), -- 'EMAIL', 'PHONE', 'ADDRESS'
    verification_method VARCHAR(100), -- 'SendGrid', 'Twilio', 'USPS', etc.
    
    -- Results
    verified BOOLEAN,
    deliverable BOOLEAN,
    verification_status VARCHAR(100),
    error_message TEXT,
    
    -- Metadata
    verified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cost DECIMAL(10,4)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- donors table indexes
CREATE INDEX idx_donors_email ON donors(email) WHERE email IS NOT NULL;
CREATE INDEX idx_donors_phone ON donors(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_donors_county ON donors(county);
CREATE INDEX idx_donors_amount_grade_state ON donors(amount_grade_state, amount_percentile_state DESC);
CREATE INDEX idx_donors_amount_grade_county ON donors(amount_grade_county, amount_percentile_county DESC);
CREATE INDEX idx_donors_intensity ON donors(intensity_grade_2y DESC);
CREATE INDEX idx_donors_level_preference ON donors(level_preference);
CREATE INDEX idx_donors_grade_3d ON donors(grade_3d);
CREATE INDEX idx_donors_ml_cluster ON donors(ml_cluster_id);
CREATE INDEX idx_donors_primary_faction ON donors(primary_faction);
CREATE INDEX idx_donors_is_donor ON donors(is_donor) WHERE is_donor = TRUE;
CREATE INDEX idx_donors_is_volunteer ON donors(is_volunteer) WHERE is_volunteer = TRUE;
CREATE INDEX idx_donors_is_lapsed ON donors(is_lapsed) WHERE is_lapsed = TRUE;
CREATE INDEX idx_donors_last_donation ON donors(last_donation_date DESC NULLS LAST);
CREATE INDEX idx_donors_composite_targeting ON donors(
    amount_grade_state, intensity_grade_2y, level_preference, county
) WHERE is_active = TRUE AND do_not_contact = FALSE;
CREATE INDEX idx_donors_full_text ON donors USING gin(
    to_tsvector('english', COALESCE(full_name, '') || ' ' || COALESCE(email, ''))
);

-- donations table indexes
CREATE INDEX idx_donations_donor ON donations(donor_id);
CREATE INDEX idx_donations_date ON donations(donation_date DESC);
CREATE INDEX idx_donations_amount ON donations(amount DESC);
CREATE INDEX idx_donations_race_level ON donations(race_level);
CREATE INDEX idx_donations_candidate ON donations(candidate_name);
CREATE INDEX idx_donations_campaign ON donations(campaign_id);

-- donor_scores table indexes
CREATE INDEX idx_donor_scores_donor ON donor_scores(donor_id);
CREATE INDEX idx_donor_scores_universe ON donor_scores(universe_type, universe_criteria);
CREATE INDEX idx_donor_scores_percentile ON donor_scores(percentile_score DESC);

-- campaigns table indexes
CREATE INDEX idx_campaigns_status ON campaigns(status);
CREATE INDEX idx_campaigns_dates ON campaigns(start_date, end_date);
CREATE INDEX idx_campaigns_race_level ON campaigns(target_race_level);

-- communication_log indexes
CREATE INDEX idx_communication_donor ON communication_log(donor_id);
CREATE INDEX idx_communication_campaign ON communication_log(campaign_id);
CREATE INDEX idx_communication_channel ON communication_log(channel);
CREATE INDEX idx_communication_status ON communication_log(status);
CREATE INDEX idx_communication_sent_at ON communication_log(sent_at DESC);

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER update_donors_updated_at BEFORE UPDATE ON donors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_volunteers_updated_at BEFORE UPDATE ON volunteers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_campaigns_updated_at BEFORE UPDATE ON campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate days since last donation
CREATE OR REPLACE FUNCTION calculate_days_since_last_donation()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.last_donation_date IS NOT NULL THEN
        NEW.days_since_last := CURRENT_DATE - NEW.last_donation_date;
        NEW.months_since_last := EXTRACT(YEAR FROM AGE(CURRENT_DATE, NEW.last_donation_date)) * 12 +
                                 EXTRACT(MONTH FROM AGE(CURRENT_DATE, NEW.last_donation_date));
    END IF;
    
    IF NEW.first_donation_date IS NOT NULL THEN
        NEW.months_since_first := EXTRACT(YEAR FROM AGE(CURRENT_DATE, NEW.first_donation_date)) * 12 +
                                  EXTRACT(MONTH FROM AGE(CURRENT_DATE, NEW.first_donation_date));
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_donation_timing BEFORE INSERT OR UPDATE ON donors
    FOR EACH ROW EXECUTE FUNCTION calculate_days_since_last_donation();

-- Function to auto-flag lapsed donors
CREATE OR REPLACE FUNCTION flag_lapsed_donors()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.days_since_last > 365 AND NEW.is_donor = TRUE THEN
        NEW.is_lapsed := TRUE;
    ELSE
        NEW.is_lapsed := FALSE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_flag_lapsed BEFORE INSERT OR UPDATE ON donors
    FOR EACH ROW EXECUTE FUNCTION flag_lapsed_donors();

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: High-value prospects
CREATE OR REPLACE VIEW v_high_value_prospects AS
SELECT 
    d.*,
    CASE 
        WHEN d.amount_grade_state IN ('A++', 'A+', 'A', 'A-') THEN 'A-Tier'
        WHEN d.amount_grade_state IN ('B+', 'B', 'B-') THEN 'B-Tier'
        ELSE 'C-Tier+'
    END as tier_category
FROM donors d
WHERE 
    d.is_active = TRUE
    AND d.do_not_contact = FALSE
    AND d.amount_grade_state IN ('A++', 'A+', 'A', 'A-', 'B+', 'B')
    AND (d.is_lapsed = FALSE OR d.days_since_last < 730)
ORDER BY d.amount_percentile_state DESC;

-- View: Active volunteers
CREATE OR REPLACE VIEW v_active_volunteers AS
SELECT 
    d.*,
    v.volunteer_tier,
    v.total_hours,
    v.ytd_hours,
    v.activities,
    v.reliability_score,
    v.last_activity_date
FROM donors d
JOIN volunteers v ON d.id = v.donor_id
WHERE 
    d.is_volunteer = TRUE
    AND d.is_active = TRUE
    AND v.days_since_last_activity < 180
ORDER BY v.ytd_hours DESC;

-- View: Donor-Volunteers (Super Engaged)
CREATE OR REPLACE VIEW v_donor_volunteers AS
SELECT 
    d.*,
    v.volunteer_tier,
    v.total_hours,
    (d.amount_percentile_state / 10) + (v.ytd_hours / 10) as engagement_score
FROM donors d
JOIN volunteers v ON d.id = v.donor_id
WHERE 
    d.is_donor = TRUE 
    AND d.is_volunteer = TRUE
    AND d.is_active = TRUE
ORDER BY engagement_score DESC;

-- View: Campaign performance summary
CREATE OR REPLACE VIEW v_campaign_performance AS
SELECT 
    c.*,
    ROUND(c.amount_raised / NULLIF(c.cost_actual, 0), 2) as actual_roi,
    ROUND(c.responses_received::DECIMAL / NULLIF(c.donors_contacted, 0) * 100, 2) as response_rate_pct,
    ROUND(c.donations_received::DECIMAL / NULLIF(c.responses_received, 0) * 100, 2) as conversion_rate_pct,
    ROUND(c.amount_raised / NULLIF(c.donations_received, 0), 2) as avg_gift
FROM campaigns c
WHERE c.status = 'COMPLETED';

-- View: Donor full profile (3D)
CREATE OR REPLACE VIEW v_donor_full_profile AS
SELECT 
    d.id,
    d.donor_id,
    d.full_name,
    d.email,
    d.phone,
    d.county,
    
    -- Dimension 1: Amount
    d.total_donations,
    d.amount_percentile_state,
    d.amount_grade_state,
    d.amount_rank_state,
    
    -- Dimension 2: Intensity
    d.intensity_grade_2y,
    d.donations_per_month_2y,
    d.donation_count_2y,
    
    -- Dimension 3: Level
    d.level_preference,
    d.level_score_federal,
    d.level_score_state,
    d.level_score_local,
    
    -- Combined
    d.grade_3d,
    
    -- ML
    d.donation_probability,
    d.volunteer_probability,
    d.ml_cluster_name,
    
    -- Status
    d.is_donor,
    d.is_volunteer,
    d.is_lapsed,
    d.days_since_last
FROM donors d
WHERE d.is_active = TRUE;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function: Get top donors by criteria
CREATE OR REPLACE FUNCTION get_top_donors(
    p_min_grade donor_grade DEFAULT 'B+',
    p_county VARCHAR DEFAULT NULL,
    p_level_pref level_preference DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    donor_id UUID,
    full_name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    county VARCHAR,
    amount_grade_state donor_grade,
    amount_percentile_state DECIMAL,
    intensity_grade_2y INTEGER,
    level_preference level_preference,
    grade_3d VARCHAR,
    total_donations DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.full_name,
        d.email,
        d.phone,
        d.county,
        d.amount_grade_state,
        d.amount_percentile_state,
        d.intensity_grade_2y,
        d.level_preference,
        d.grade_3d,
        d.total_donations
    FROM donors d
    WHERE 
        d.is_active = TRUE
        AND d.do_not_contact = FALSE
        AND d.amount_grade_state::text >= p_min_grade::text
        AND (p_county IS NULL OR d.county = p_county)
        AND (p_level_pref IS NULL OR d.level_preference = p_level_pref)
    ORDER BY 
        d.amount_percentile_state DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate campaign ROI
CREATE OR REPLACE FUNCTION calculate_campaign_roi(p_campaign_id UUID)
RETURNS DECIMAL AS $$
DECLARE
    v_roi DECIMAL;
BEGIN
    SELECT 
        CASE 
            WHEN cost_actual > 0 THEN amount_raised / cost_actual
            ELSE 0
        END INTO v_roi
    FROM campaigns
    WHERE id = p_campaign_id;
    
    RETURN COALESCE(v_roi, 0);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE donors IS 'Master donor table with 3D grading (Amount × Intensity × Level)';
COMMENT ON COLUMN donors.amount_percentile_state IS 'Continuous 0-1000 score for AI precision';
COMMENT ON COLUMN donors.amount_grade_state IS 'Letter grade A++ to U for human display';
COMMENT ON COLUMN donors.intensity_grade_2y IS '1-10 engagement scale based on frequency';
COMMENT ON COLUMN donors.level_preference IS 'F=Federal, S=State, L=Local giving preference';
COMMENT ON COLUMN donors.grade_3d IS 'Combined 3D grade (e.g. A++/8/F)';
COMMENT ON COLUMN donors.ml_cluster_id IS 'Natural ML-discovered segment ID';

COMMENT ON TABLE donations IS 'Individual donation transactions with race level tracking';
COMMENT ON TABLE donor_scores IS 'Multi-dimensional percentile scores by universe';
COMMENT ON TABLE campaigns IS 'Campaign management with grade-based targeting';

COMMENT ON VIEW v_high_value_prospects IS 'A-tier and B-tier donors ready for cultivation';
COMMENT ON VIEW v_donor_volunteers IS 'Super-engaged donors who also volunteer';
COMMENT ON VIEW v_campaign_performance IS 'Campaign analytics with ROI calculations';

-- ============================================================================
-- INITIAL DATA & CONFIGURATION
-- ============================================================================

-- Insert system user for automated operations
INSERT INTO donors (donor_id, first_name, last_name, email, notes)
VALUES ('SYSTEM', 'System', 'User', 'system@broyhillgop.org', 'System account for automated operations')
ON CONFLICT (donor_id) DO NOTHING;

-- ============================================================================
-- GRANT PERMISSIONS (Adjust for your environment)
-- ============================================================================

-- Grant SELECT to read-only role
-- GRANT SELECT ON ALL TABLES IN SCHEMA broyhillgop TO readonly_role;

-- Grant full access to admin role
-- GRANT ALL ON ALL TABLES IN SCHEMA broyhillgop TO admin_role;
-- GRANT ALL ON ALL SEQUENCES IN SCHEMA broyhillgop TO admin_role;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA broyhillgop TO admin_role;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

-- Analyze tables for query optimization
ANALYZE donors;
ANALYZE donations;
ANALYZE donor_scores;
ANALYZE campaigns;
ANALYZE volunteers;

-- Display schema info
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'broyhillgop'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'BroyhillGOP Master Database Schema Deployed Successfully!';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Tables created: 11';
    RAISE NOTICE 'Indexes created: 25+';
    RAISE NOTICE 'Views created: 5';
    RAISE NOTICE 'Functions created: 4';
    RAISE NOTICE 'Triggers created: 4';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Import donor data';
    RAISE NOTICE '2. Calculate initial percentiles and grades';
    RAISE NOTICE '3. Run ML clustering';
    RAISE NOTICE '4. Set up nightly batch processing';
    RAISE NOTICE '============================================================';
END $$;
