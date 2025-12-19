-- ============================================================================
-- BROYHILLGOP COMPLETE DATABASE SCHEMA
-- Version 4.0 - November 28, 2025
-- ============================================================================

-- ============================================================================
-- SCHEMA: nc_data_committee (Owned by NC Republican Data Committee)
-- BroyhillGOP has READ-ONLY access to this schema
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS nc_data_committee;

-- Master donor records from FEC/NCBOE
CREATE TABLE nc_data_committee.donors_master (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100),
    suffix VARCHAR(20),
    full_name VARCHAR(255) GENERATED ALWAYS AS (
        TRIM(COALESCE(first_name, '') || ' ' || COALESCE(middle_name, '') || ' ' || COALESCE(last_name, '') || ' ' || COALESCE(suffix, ''))
    ) STORED,
    
    -- Contact - Primary
    email VARCHAR(255),
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMP,
    phone VARCHAR(20),
    phone_verified BOOLEAN DEFAULT FALSE,
    phone_verified_at TIMESTAMP,
    
    -- Contact - Secondary
    email_secondary VARCHAR(255),
    phone_secondary VARCHAR(20),
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),
    zip4 VARCHAR(4),
    county VARCHAR(100),
    congressional_district VARCHAR(10),
    state_senate_district VARCHAR(10),
    state_house_district VARCHAR(10),
    precinct VARCHAR(50),
    
    -- Employment (FEC required)
    employer VARCHAR(255),
    occupation VARCHAR(255),
    
    -- Source IDs
    fec_id VARCHAR(50) UNIQUE,
    ncboe_id VARCHAR(50) UNIQUE,
    datatrust_id VARCHAR(50),
    
    -- Data quality
    address_standardized BOOLEAN DEFAULT FALSE,
    ncoa_updated_at TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    source VARCHAR(50), -- 'fec', 'ncboe', 'datatrust', 'manual'
    
    -- Indexes
    CONSTRAINT donors_master_email_check CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_donors_master_email ON nc_data_committee.donors_master(email);
CREATE INDEX idx_donors_master_name ON nc_data_committee.donors_master(last_name, first_name);
CREATE INDEX idx_donors_master_zip ON nc_data_committee.donors_master(zip);
CREATE INDEX idx_donors_master_county ON nc_data_committee.donors_master(county);

-- Contribution records from FEC/NCBOE filings
CREATE TABLE nc_data_committee.contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES nc_data_committee.donors_master(id),
    
    -- Recipient
    committee_name VARCHAR(255) NOT NULL,
    committee_fec_id VARCHAR(20),
    committee_ncsbe_id VARCHAR(20),
    candidate_name VARCHAR(255),
    candidate_office VARCHAR(100),
    candidate_party VARCHAR(10),
    
    -- Contribution details
    amount DECIMAL(10,2) NOT NULL,
    contribution_date DATE NOT NULL,
    contribution_type VARCHAR(50), -- individual, pac, party, other
    receipt_type VARCHAR(50), -- primary, general, runoff
    
    -- Source filing
    source VARCHAR(20) NOT NULL, -- 'fec' or 'ncboe'
    filing_id VARCHAR(50),
    filing_date DATE,
    amendment_indicator VARCHAR(1),
    
    -- Deduplication
    source_unique_id VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(source, source_unique_id)
);

CREATE INDEX idx_contributions_donor ON nc_data_committee.contributions(donor_id);
CREATE INDEX idx_contributions_committee ON nc_data_committee.contributions(committee_fec_id);
CREATE INDEX idx_contributions_date ON nc_data_committee.contributions(contribution_date);
CREATE INDEX idx_contributions_amount ON nc_data_committee.contributions(amount);

-- DataTrust enrichment data
CREATE TABLE nc_data_committee.datatrust_enrichments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES nc_data_committee.donors_master(id) UNIQUE,
    
    -- Voter scores (0-100)
    partisan_score INTEGER,
    turnout_score INTEGER,
    donor_score INTEGER,
    
    -- Demographics
    age_range VARCHAR(20),
    gender VARCHAR(10),
    marital_status VARCHAR(20),
    presence_of_children BOOLEAN,
    homeowner BOOLEAN,
    estimated_income_range VARCHAR(50),
    education_level VARCHAR(50),
    
    -- Consumer data
    interests JSONB,
    
    -- Voter registration
    voter_status VARCHAR(20),
    party_registration VARCHAR(20),
    registration_date DATE,
    
    -- Voting history (last 10 elections)
    voting_history JSONB,
    
    -- Update tracking
    datatrust_updated_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- SCHEMA: broyhillgop (Owned by BroyhillGOP)
-- Full read/write access for platform
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS broyhillgop;

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 0: DATA HUB - Core tables
-- ----------------------------------------------------------------------------

-- Platform candidates
CREATE TABLE broyhillgop.candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    suffix VARCHAR(20),
    
    -- Office
    office_type VARCHAR(50) NOT NULL, -- federal, statewide, state_legislative, county, local
    office_name VARCHAR(255) NOT NULL,
    office_level VARCHAR(50), -- us_senate, us_house, governor, lt_governor, council_of_state, state_senate, state_house, county, municipal
    district VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    
    -- Committee
    committee_name VARCHAR(255),
    fec_committee_id VARCHAR(20),
    ncsbe_committee_id VARCHAR(20),
    
    -- Contact
    campaign_email VARCHAR(255),
    campaign_phone VARCHAR(20),
    website VARCHAR(255),
    
    -- Faction alignment
    primary_faction VARCHAR(10),
    secondary_faction VARCHAR(10),
    faction_scores JSONB,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active', -- active, inactive, won, lost, withdrawn
    license_tier VARCHAR(20), -- federal, statewide, legislative, county, local
    onboarded_at TIMESTAMP,
    
    -- Election
    election_year INTEGER,
    election_type VARCHAR(20), -- primary, general, special
    election_date DATE,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_candidates_status ON broyhillgop.candidates(status);
CREATE INDEX idx_candidates_office ON broyhillgop.candidates(office_type, office_level);
CREATE INDEX idx_candidates_election ON broyhillgop.candidates(election_year, election_type);

-- Platform users
CREATE TABLE broyhillgop.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Authentication
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    
    -- Profile
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    
    -- Role & Access
    role VARCHAR(50) NOT NULL, -- superadmin, admin, staff, campaign_manager, candidate, treasurer, volunteer
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    permissions JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(20) DEFAULT 'active', -- active, inactive, suspended
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMP,
    
    -- Tracking
    last_login_at TIMESTAMP,
    last_login_ip INET,
    login_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_role ON broyhillgop.users(role);
CREATE INDEX idx_users_candidate ON broyhillgop.users(candidate_id);

-- Audit log
CREATE TABLE broyhillgop.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Actor
    user_id UUID REFERENCES broyhillgop.users(id),
    ip_address INET,
    user_agent TEXT,
    
    -- Action
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id UUID,
    
    -- Changes
    old_values JSONB,
    new_values JSONB,
    
    -- Context
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user ON broyhillgop.audit_logs(user_id, created_at);
CREATE INDEX idx_audit_logs_entity ON broyhillgop.audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_candidate ON broyhillgop.audit_logs(candidate_id, created_at);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 1: DONOR INTELLIGENCE
-- ----------------------------------------------------------------------------

-- Extended donor profiles (BroyhillGOP's view of donors)
CREATE TABLE broyhillgop.donor_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_master_id UUID REFERENCES nc_data_committee.donors_master(id) UNIQUE,
    
    -- Grading (21-tier)
    grade VARCHAR(2), -- A+, A, A-, B+, B, B-, C+, C, C-, D+, D, D-, F, U+, U, U-
    grade_score INTEGER CHECK (grade_score >= 0 AND grade_score <= 1000),
    grade_calculated_at TIMESTAMP,
    grade_factors JSONB,
    
    -- Faction alignment
    primary_faction VARCHAR(10),
    secondary_faction VARCHAR(10),
    faction_scores JSONB, -- {MAGA: 85, EVAN: 72, ...}
    faction_calculated_at TIMESTAMP,
    
    -- Capacity indicators
    estimated_capacity VARCHAR(20), -- <100, 100-500, 500-1000, 1000-5000, 5000-10000, 10000+
    home_value DECIMAL(12,2),
    wealth_indicators JSONB,
    
    -- Giving summary
    total_donations DECIMAL(12,2) DEFAULT 0,
    total_donations_platform DECIMAL(12,2) DEFAULT 0, -- via BroyhillGOP
    donation_count INTEGER DEFAULT 0,
    donation_count_platform INTEGER DEFAULT 0,
    average_donation DECIMAL(10,2),
    max_donation DECIMAL(10,2),
    first_donation_date DATE,
    last_donation_date DATE,
    
    -- Engagement
    last_contact_date DATE,
    last_response_date DATE,
    email_engagement_score INTEGER, -- 0-100
    sms_engagement_score INTEGER,
    
    -- Contact preferences
    email_opt_in BOOLEAN DEFAULT TRUE,
    sms_opt_in BOOLEAN DEFAULT FALSE,
    mail_opt_in BOOLEAN DEFAULT TRUE,
    call_opt_in BOOLEAN DEFAULT FALSE,
    do_not_contact BOOLEAN DEFAULT FALSE,
    
    -- Tags & notes
    tags JSONB DEFAULT '[]',
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_donor_profiles_grade ON broyhillgop.donor_profiles(grade);
CREATE INDEX idx_donor_profiles_faction ON broyhillgop.donor_profiles(primary_faction);
CREATE INDEX idx_donor_profiles_capacity ON broyhillgop.donor_profiles(estimated_capacity);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 2: DONATION TRACKING
-- ----------------------------------------------------------------------------

-- Donations tracked from WinRed/Anedot
CREATE TABLE broyhillgop.donations_tracked (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Processor
    processor VARCHAR(20) NOT NULL CHECK (processor IN ('winred', 'anedot')),
    processor_transaction_id VARCHAR(100) NOT NULL,
    processor_status VARCHAR(50),
    
    -- Tracking attribution
    tracking_code VARCHAR(100),
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    campaign_id UUID,
    channel VARCHAR(10), -- EM (email), SM (sms), ML (mail), CL (call), WB (web), SC (social)
    
    -- Donor matching
    donor_profile_id UUID REFERENCES broyhillgop.donor_profiles(id),
    donor_email VARCHAR(255),
    donor_phone VARCHAR(20),
    donor_first_name VARCHAR(100),
    donor_last_name VARCHAR(100),
    donor_address JSONB,
    
    -- Donation details
    amount DECIMAL(10,2) NOT NULL,
    donation_date TIMESTAMP NOT NULL,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurring_frequency VARCHAR(20), -- monthly, weekly
    
    -- Commission
    commission_rate DECIMAL(5,4) DEFAULT 0.08,
    commission_amount DECIMAL(10,2) GENERATED ALWAYS AS (amount * commission_rate) STORED,
    commission_invoiced BOOLEAN DEFAULT FALSE,
    commission_invoice_id UUID,
    commission_paid BOOLEAN DEFAULT FALSE,
    commission_paid_date DATE,
    
    -- Raw data
    webhook_payload JSONB,
    webhook_received_at TIMESTAMP DEFAULT NOW(),
    
    -- Deduplication
    UNIQUE(processor, processor_transaction_id),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_donations_candidate ON broyhillgop.donations_tracked(candidate_id, donation_date);
CREATE INDEX idx_donations_campaign ON broyhillgop.donations_tracked(campaign_id);
CREATE INDEX idx_donations_tracking ON broyhillgop.donations_tracked(tracking_code);
CREATE INDEX idx_donations_donor ON broyhillgop.donations_tracked(donor_profile_id);
CREATE INDEX idx_donations_commission ON broyhillgop.donations_tracked(commission_invoiced, commission_paid);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 3: CAMPAIGN OUTREACH
-- ----------------------------------------------------------------------------

-- Campaign definitions
CREATE TABLE broyhillgop.campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    
    -- Identity
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50), -- short code for tracking
    campaign_type VARCHAR(50) NOT NULL, -- welcome, thank_you, ask, urgent, eoy, etc.
    channel VARCHAR(20) NOT NULL, -- email, sms, mail, call
    
    -- Content
    subject_line VARCHAR(255),
    preview_text VARCHAR(255),
    content_template TEXT,
    content_html TEXT,
    content_plain TEXT,
    
    -- AI generation
    ai_generated BOOLEAN DEFAULT FALSE,
    ai_prompt_id UUID,
    ai_generation_params JSONB,
    
    -- Targeting
    target_audience JSONB, -- {factions: [], grades: [], counties: [], etc.}
    exclusion_rules JSONB,
    estimated_audience_size INTEGER,
    
    -- Schedule
    status VARCHAR(20) DEFAULT 'draft', -- draft, scheduled, sending, paused, completed, cancelled
    scheduled_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Tracking code prefix
    tracking_prefix VARCHAR(50),
    
    -- A/B Testing
    is_ab_test BOOLEAN DEFAULT FALSE,
    ab_variant VARCHAR(1), -- A, B, C, etc.
    ab_parent_id UUID REFERENCES broyhillgop.campaigns(id),
    
    -- Results (denormalized for performance)
    recipients_count INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    bounced_count INTEGER DEFAULT 0,
    opened_count INTEGER DEFAULT 0,
    clicked_count INTEGER DEFAULT 0,
    unsubscribed_count INTEGER DEFAULT 0,
    complained_count INTEGER DEFAULT 0,
    donated_count INTEGER DEFAULT 0,
    donated_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Cost tracking
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    
    created_by UUID REFERENCES broyhillgop.users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_campaigns_candidate ON broyhillgop.campaigns(candidate_id, status);
CREATE INDEX idx_campaigns_type ON broyhillgop.campaigns(campaign_type);
CREATE INDEX idx_campaigns_status ON broyhillgop.campaigns(status, scheduled_at);

-- Individual campaign activities (one per recipient per campaign)
CREATE TABLE broyhillgop.campaign_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES broyhillgop.campaigns(id) NOT NULL,
    donor_profile_id UUID REFERENCES broyhillgop.donor_profiles(id) NOT NULL,
    
    -- Personalization
    tracking_code VARCHAR(100) NOT NULL,
    personalized_content JSONB,
    
    -- Delivery
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    bounced_at TIMESTAMP,
    bounce_reason VARCHAR(255),
    
    -- Engagement
    opened_at TIMESTAMP,
    open_count INTEGER DEFAULT 0,
    clicked_at TIMESTAMP,
    click_count INTEGER DEFAULT 0,
    clicks JSONB, -- [{url, timestamp}, ...]
    
    -- Opt-out
    unsubscribed_at TIMESTAMP,
    complained_at TIMESTAMP,
    
    -- Conversion
    donated_at TIMESTAMP,
    donated_amount DECIMAL(10,2),
    donation_id UUID REFERENCES broyhillgop.donations_tracked(id),
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(campaign_id, donor_profile_id)
);

CREATE INDEX idx_recipients_campaign ON broyhillgop.campaign_recipients(campaign_id);
CREATE INDEX idx_recipients_donor ON broyhillgop.campaign_recipients(donor_profile_id);
CREATE INDEX idx_recipients_tracking ON broyhillgop.campaign_recipients(tracking_code);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 4: DONOR-CANDIDATE MATCHING
-- ----------------------------------------------------------------------------

CREATE TABLE broyhillgop.donor_candidate_affinity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_profile_id UUID REFERENCES broyhillgop.donor_profiles(id) NOT NULL,
    candidate_id UUID REFERENCES broyhillgop.candidates(id) NOT NULL,
    
    -- Overall score
    affinity_score INTEGER CHECK (affinity_score >= 0 AND affinity_score <= 100),
    
    -- Component scores
    faction_score INTEGER,
    geographic_score INTEGER,
    history_score INTEGER,
    issue_score INTEGER,
    capacity_score INTEGER,
    
    -- Recommendation
    recommended_ask_amount DECIMAL(10,2),
    confidence_level VARCHAR(20), -- high, medium, low
    
    -- Ranking (within candidate)
    candidate_rank INTEGER,
    
    -- Calculation metadata
    calculated_at TIMESTAMP DEFAULT NOW(),
    calculation_version VARCHAR(20),
    
    UNIQUE(donor_profile_id, candidate_id)
);

CREATE INDEX idx_affinity_donor ON broyhillgop.donor_candidate_affinity(donor_profile_id);
CREATE INDEX idx_affinity_candidate ON broyhillgop.donor_candidate_affinity(candidate_id, affinity_score DESC);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 5: VOLUNTEER MANAGEMENT
-- ----------------------------------------------------------------------------

CREATE TABLE broyhillgop.volunteers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity (may link to donor)
    donor_profile_id UUID REFERENCES broyhillgop.donor_profiles(id),
    user_id UUID REFERENCES broyhillgop.users(id),
    
    -- Contact
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    
    -- Location
    address_line1 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),
    county VARCHAR(100),
    
    -- Availability
    availability JSONB, -- {weekdays: true, evenings: true, weekends: false}
    
    -- Skills & interests
    skills JSONB, -- [phone, doors, data_entry, etc.]
    interests JSONB,
    
    -- Grading
    grade VARCHAR(2),
    grade_score INTEGER,
    
    -- Stats
    total_hours DECIMAL(10,2) DEFAULT 0,
    total_activities INTEGER DEFAULT 0,
    last_activity_date DATE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE broyhillgop.volunteer_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID REFERENCES broyhillgop.volunteers(id) NOT NULL,
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    
    -- Activity
    activity_type VARCHAR(50) NOT NULL, -- phone_bank, door_knock, data_entry, etc.
    activity_date DATE NOT NULL,
    hours DECIMAL(4,2),
    
    -- Location (if applicable)
    location VARCHAR(255),
    
    -- Results (if applicable)
    calls_made INTEGER,
    doors_knocked INTEGER,
    contacts_made INTEGER,
    
    -- Notes
    notes TEXT,
    
    -- Verification
    verified BOOLEAN DEFAULT FALSE,
    verified_by UUID REFERENCES broyhillgop.users(id),
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 6: EVENT MANAGEMENT
-- ----------------------------------------------------------------------------

CREATE TABLE broyhillgop.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    
    -- Event details
    name VARCHAR(255) NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- fundraiser, rally, town_hall, phone_bank, etc.
    description TEXT,
    
    -- Schedule
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    
    -- Location
    is_virtual BOOLEAN DEFAULT FALSE,
    venue_name VARCHAR(255),
    address_line1 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),
    virtual_link VARCHAR(500),
    
    -- Capacity
    capacity INTEGER,
    rsvp_count INTEGER DEFAULT 0,
    attended_count INTEGER DEFAULT 0,
    
    -- Fundraising (if applicable)
    is_fundraiser BOOLEAN DEFAULT FALSE,
    ticket_price DECIMAL(10,2),
    fundraising_goal DECIMAL(12,2),
    fundraising_actual DECIMAL(12,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft', -- draft, published, cancelled, completed
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE broyhillgop.event_rsvps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES broyhillgop.events(id) NOT NULL,
    donor_profile_id UUID REFERENCES broyhillgop.donor_profiles(id),
    
    -- Guest info
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    
    -- RSVP
    rsvp_status VARCHAR(20) DEFAULT 'registered', -- registered, confirmed, cancelled, waitlist
    guest_count INTEGER DEFAULT 1,
    
    -- Attendance
    checked_in BOOLEAN DEFAULT FALSE,
    checked_in_at TIMESTAMP,
    
    -- Payment (if ticketed)
    payment_status VARCHAR(20),
    payment_amount DECIMAL(10,2),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 12: STAFF OPERATIONS
-- ----------------------------------------------------------------------------

CREATE TABLE broyhillgop.staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES broyhillgop.users(id) UNIQUE,
    
    -- Profile
    title VARCHAR(100),
    department VARCHAR(50),
    hire_date DATE,
    
    -- Capacity
    max_candidates INTEGER, -- how many candidates they can manage
    current_candidates INTEGER DEFAULT 0,
    
    -- Performance
    total_revenue_generated DECIMAL(12,2) DEFAULT 0,
    commission_earned DECIMAL(12,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE broyhillgop.candidate_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES broyhillgop.candidates(id) NOT NULL,
    staff_id UUID REFERENCES broyhillgop.staff(id) NOT NULL,
    
    -- Assignment
    role VARCHAR(50), -- primary, backup, specialist
    assigned_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active',
    
    UNIQUE(candidate_id, staff_id, status)
);

CREATE TABLE broyhillgop.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES broyhillgop.candidates(id) NOT NULL,
    
    -- Invoice details
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    
    -- Period
    period_start DATE,
    period_end DATE,
    
    -- Amounts
    subtotal DECIMAL(12,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL,
    amount_paid DECIMAL(12,2) DEFAULT 0,
    amount_due DECIMAL(12,2) GENERATED ALWAYS AS (total_amount - amount_paid) STORED,
    
    -- Line items stored as JSON
    line_items JSONB NOT NULL,
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft', -- draft, sent, paid, overdue, cancelled
    sent_at TIMESTAMP,
    paid_at TIMESTAMP,
    
    -- QuickBooks sync
    quickbooks_id VARCHAR(100),
    quickbooks_synced_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 13: AI HUB
-- ----------------------------------------------------------------------------

CREATE TABLE broyhillgop.ai_prompts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL, -- email, sms, analysis, scoring, etc.
    version INTEGER DEFAULT 1,
    
    -- Prompt
    system_prompt TEXT,
    user_prompt_template TEXT NOT NULL,
    
    -- Configuration
    model VARCHAR(50) DEFAULT 'gpt-4',
    temperature DECIMAL(3,2) DEFAULT 0.7,
    max_tokens INTEGER DEFAULT 1000,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active', -- active, deprecated
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE broyhillgop.ai_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source
    ecosystem VARCHAR(50) NOT NULL,
    prompt_id UUID REFERENCES broyhillgop.ai_prompts(id),
    user_id UUID REFERENCES broyhillgop.users(id),
    candidate_id UUID REFERENCES broyhillgop.candidates(id),
    
    -- Request
    model VARCHAR(50) NOT NULL,
    input_tokens INTEGER,
    output_tokens INTEGER,
    
    -- Cost
    cost_cents INTEGER,
    
    -- Cache
    cache_key VARCHAR(255),
    cache_hit BOOLEAN DEFAULT FALSE,
    
    -- Timing
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    duration_ms INTEGER,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending', -- pending, completed, failed
    error_message TEXT
);

CREATE INDEX idx_ai_requests_ecosystem ON broyhillgop.ai_requests(ecosystem, created_at);
CREATE INDEX idx_ai_requests_candidate ON broyhillgop.ai_requests(candidate_id, created_at);

CREATE TABLE broyhillgop.ai_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cache_key VARCHAR(255) UNIQUE NOT NULL,
    
    -- Cached data
    response_text TEXT NOT NULL,
    model VARCHAR(50),
    
    -- Metadata
    hit_count INTEGER DEFAULT 0,
    last_hit_at TIMESTAMP,
    
    -- Expiration
    expires_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- ECOSYSTEM 14: DATA GOVERNANCE
-- ----------------------------------------------------------------------------

CREATE TABLE broyhillgop.license_agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES broyhillgop.candidates(id) NOT NULL,
    
    -- Committee
    committee_name VARCHAR(255) NOT NULL,
    fec_committee_id VARCHAR(20),
    ncsbe_committee_id VARCHAR(20),
    
    -- Signatory
    signatory_name VARCHAR(255) NOT NULL,
    signatory_title VARCHAR(100),
    signatory_email VARCHAR(255),
    
    -- Dates
    signed_date DATE,
    effective_date DATE,
    expiration_date DATE,
    terminated_date DATE,
    
    -- Agreement
    agreement_version VARCHAR(20) NOT NULL,
    agreement_pdf_url TEXT,
    data_access_level VARCHAR(50), -- district, county, statewide, federal
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending', -- pending, active, expired, suspended, terminated
    suspension_reason TEXT,
    termination_reason TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE broyhillgop.data_access_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Actor
    user_id UUID REFERENCES broyhillgop.users(id) NOT NULL,
    candidate_id UUID REFERENCES broyhillgop.candidates(id) NOT NULL,
    session_id VARCHAR(100),
    
    -- Action
    action_type VARCHAR(50) NOT NULL, -- view, search, export, download, print
    data_type VARCHAR(50) NOT NULL, -- donors, contributions, voters
    record_count INTEGER DEFAULT 0,
    
    -- Query details
    query_params JSONB,
    
    -- Location
    ip_address INET,
    user_agent TEXT,
    
    -- Export details
    export_format VARCHAR(20),
    export_file_hash VARCHAR(64),
    watermark_id VARCHAR(50),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_access_logs_user ON broyhillgop.data_access_logs(user_id, created_at);
CREATE INDEX idx_access_logs_candidate ON broyhillgop.data_access_logs(candidate_id, created_at);

CREATE TABLE broyhillgop.data_anomalies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source
    candidate_id UUID REFERENCES broyhillgop.candidates(id) NOT NULL,
    user_id UUID REFERENCES broyhillgop.users(id),
    access_log_id UUID REFERENCES broyhillgop.data_access_logs(id),
    
    -- Classification
    anomaly_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL, -- low, medium, high, critical
    confidence_score DECIMAL(5,4),
    
    -- Details
    description TEXT NOT NULL,
    evidence JSONB,
    
    -- Response
    auto_action_taken VARCHAR(100),
    
    -- Investigation
    investigation_status VARCHAR(50) DEFAULT 'pending',
    assigned_to UUID REFERENCES broyhillgop.users(id),
    resolution VARCHAR(50),
    resolution_notes TEXT,
    resolved_at TIMESTAMP,
    
    detected_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on key tables
ALTER TABLE broyhillgop.donor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE broyhillgop.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE broyhillgop.donations_tracked ENABLE ROW LEVEL SECURITY;

-- Candidates can only see their own data
CREATE POLICY candidate_isolation ON broyhillgop.campaigns
    FOR ALL
    USING (
        candidate_id IN (
            SELECT candidate_id FROM broyhillgop.users WHERE id = current_user_id()
        )
        OR current_user_role() IN ('superadmin', 'admin', 'staff')
    );

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Get current user ID from session
CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
    SELECT current_setting('app.current_user_id', true)::UUID;
$$ LANGUAGE SQL STABLE;

-- Get current user role from session
CREATE OR REPLACE FUNCTION current_user_role() RETURNS VARCHAR AS $$
    SELECT current_setting('app.current_user_role', true)::VARCHAR;
$$ LANGUAGE SQL STABLE;

-- Calculate donor grade from score
CREATE OR REPLACE FUNCTION calculate_grade(score INTEGER) RETURNS VARCHAR AS $$
BEGIN
    RETURN CASE
        WHEN score >= 950 THEN 'A+'
        WHEN score >= 900 THEN 'A'
        WHEN score >= 850 THEN 'A-'
        WHEN score >= 800 THEN 'B+'
        WHEN score >= 750 THEN 'B'
        WHEN score >= 700 THEN 'B-'
        WHEN score >= 650 THEN 'C+'
        WHEN score >= 600 THEN 'C'
        WHEN score >= 550 THEN 'C-'
        WHEN score >= 500 THEN 'D+'
        WHEN score >= 400 THEN 'D'
        WHEN score >= 300 THEN 'D-'
        WHEN score >= 100 THEN 'F'
        WHEN score >= 80 THEN 'U+'
        WHEN score >= 50 THEN 'U'
        ELSE 'U-'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Update timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER update_candidates_updated_at BEFORE UPDATE ON broyhillgop.candidates FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON broyhillgop.users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_donor_profiles_updated_at BEFORE UPDATE ON broyhillgop.donor_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_campaigns_updated_at BEFORE UPDATE ON broyhillgop.campaigns FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-calculate grade when score changes
CREATE OR REPLACE FUNCTION auto_calculate_grade()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.grade_score IS DISTINCT FROM OLD.grade_score THEN
        NEW.grade = calculate_grade(NEW.grade_score);
        NEW.grade_calculated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_grade_donor_profiles
    BEFORE INSERT OR UPDATE ON broyhillgop.donor_profiles
    FOR EACH ROW EXECUTE FUNCTION auto_calculate_grade();

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
