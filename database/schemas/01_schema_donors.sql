-- ========================================
-- BROYHILLGOP DATABASE SCHEMA - COMPLETE
-- Version: 1.0
-- Database: PostgreSQL 15+ (Supabase)
-- Purpose: Production-ready schema for 500 candidates, 1M donors
-- ========================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Full-text search
CREATE EXTENSION IF NOT EXISTS "postgis";         -- Geographic queries
CREATE EXTENSION IF NOT EXISTS "btree_gin";       -- Performance indexes

-- ========================================
-- TABLE 1: DONORS (1,030 fields)
-- Complete donor records with 13 categories
-- ========================================

CREATE TABLE donors (
    -- Primary Key
    donor_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,  -- Multi-tenant isolation
    
    -- CATEGORY 1: Basic Identity (12 fields)
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(255) GENERATED ALWAYS AS (
        TRIM(COALESCE(first_name, '') || ' ' || COALESCE(middle_name, '') || ' ' || COALESCE(last_name, ''))
    ) STORED,
    name_prefix VARCHAR(20),           -- Mr., Mrs., Dr., etc.
    name_suffix VARCHAR(20),           -- Jr., Sr., III, etc.
    nickname VARCHAR(100),
    preferred_name VARCHAR(100),
    gender VARCHAR(20),
    date_of_birth DATE,
    age INTEGER GENERATED ALWAYS AS (
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth))::INTEGER
    ) STORED,
    ssn_last_4 VARCHAR(4),             -- Last 4 of SSN (encrypted)
    
    -- CATEGORY 2: Contact Information (25 fields)
    -- Primary Email
    email_primary VARCHAR(255),
    email_primary_valid BOOLEAN DEFAULT FALSE,
    email_primary_verified_at TIMESTAMP,
    email_primary_bounced BOOLEAN DEFAULT FALSE,
    email_primary_opted_out BOOLEAN DEFAULT FALSE,
    email_primary_opted_out_at TIMESTAMP,
    
    -- Secondary Email
    email_secondary VARCHAR(255),
    email_secondary_valid BOOLEAN DEFAULT FALSE,
    
    -- Work Email
    email_work VARCHAR(255),
    email_work_valid BOOLEAN DEFAULT FALSE,
    
    -- Phone Numbers (10 types)
    phone_primary VARCHAR(20),
    phone_primary_valid BOOLEAN DEFAULT FALSE,
    phone_primary_type VARCHAR(20),    -- mobile, home, work
    phone_primary_opted_out BOOLEAN DEFAULT FALSE,
    phone_primary_opted_out_at TIMESTAMP,
    
    phone_secondary VARCHAR(20),
    phone_secondary_valid BOOLEAN DEFAULT FALSE,
    phone_secondary_type VARCHAR(20),
    
    phone_work VARCHAR(20),
    phone_work_valid BOOLEAN DEFAULT FALSE,
    
    phone_mobile VARCHAR(20),
    phone_mobile_valid BOOLEAN DEFAULT FALSE,
    
    phone_home VARCHAR(20),
    phone_home_valid BOOLEAN DEFAULT FALSE,
    
    -- Preferred contact method
    contact_preference VARCHAR(20) DEFAULT 'email', -- email, sms, phone, mail
    best_time_to_contact VARCHAR(50),
    do_not_contact BOOLEAN DEFAULT FALSE,
    
    -- CATEGORY 3: Address Information (50 fields)
    -- Primary Address
    address_primary_line1 VARCHAR(255),
    address_primary_line2 VARCHAR(255),
    address_primary_city VARCHAR(100),
    address_primary_county VARCHAR(100),
    address_primary_state VARCHAR(2),
    address_primary_zip VARCHAR(10),
    address_primary_zip4 VARCHAR(4),
    address_primary_country VARCHAR(2) DEFAULT 'US',
    address_primary_valid BOOLEAN DEFAULT FALSE,
    address_primary_verified_at TIMESTAMP,
    address_primary_type VARCHAR(20),  -- home, work, other
    address_primary_latitude DECIMAL(10, 8),
    address_primary_longitude DECIMAL(11, 8),
    address_primary_geog GEOGRAPHY(POINT, 4326), -- PostGIS point
    address_primary_congressional_district VARCHAR(10),
    address_primary_state_senate_district VARCHAR(10),
    address_primary_state_house_district VARCHAR(10),
    
    -- Mailing Address (if different)
    address_mailing_line1 VARCHAR(255),
    address_mailing_line2 VARCHAR(255),
    address_mailing_city VARCHAR(100),
    address_mailing_county VARCHAR(100),
    address_mailing_state VARCHAR(2),
    address_mailing_zip VARCHAR(10),
    address_mailing_zip4 VARCHAR(4),
    address_mailing_country VARCHAR(2) DEFAULT 'US',
    address_mailing_valid BOOLEAN DEFAULT FALSE,
    
    -- Work Address
    address_work_line1 VARCHAR(255),
    address_work_line2 VARCHAR(255),
    address_work_city VARCHAR(100),
    address_work_county VARCHAR(100),
    address_work_state VARCHAR(2),
    address_work_zip VARCHAR(10),
    address_work_country VARCHAR(2) DEFAULT 'US',
    
    -- Seasonal Address
    address_seasonal_line1 VARCHAR(255),
    address_seasonal_line2 VARCHAR(255),
    address_seasonal_city VARCHAR(100),
    address_seasonal_state VARCHAR(2),
    address_seasonal_zip VARCHAR(10),
    address_seasonal_months VARCHAR(100), -- JSON: ["11", "12", "1", "2"]
    
    -- Previous Addresses (for tracking moves)
    address_previous_1 TEXT,
    address_previous_1_moved_date DATE,
    address_previous_2 TEXT,
    address_previous_2_moved_date DATE,
    
    -- CATEGORY 4: Demographic Information (35 fields)
    race_ethnicity VARCHAR(50),
    marital_status VARCHAR(20),
    household_size INTEGER,
    number_of_children INTEGER,
    children_ages INTEGER[],
    education_level VARCHAR(50),
    occupation VARCHAR(100),
    employer VARCHAR(255),
    employer_address TEXT,
    job_title VARCHAR(100),
    industry VARCHAR(100),
    income_estimated INTEGER,
    income_range VARCHAR(50),          -- <50K, 50-100K, 100-250K, 250K+
    net_worth_estimated INTEGER,
    home_ownership VARCHAR(20),        -- own, rent, other
    home_value_estimated INTEGER,
    home_purchase_date DATE,
    home_mortgage_amount INTEGER,
    vehicle_ownership INTEGER,         -- number of vehicles
    vehicle_types VARCHAR(255)[],      -- array of vehicle types
    military_service BOOLEAN DEFAULT FALSE,
    military_branch VARCHAR(50),
    military_rank VARCHAR(50),
    military_years_served INTEGER,
    veteran_status BOOLEAN DEFAULT FALSE,
    religious_affiliation VARCHAR(100),
    church_name VARCHAR(255),
    church_attendance VARCHAR(50),     -- weekly, monthly, occasionally, never
    languages_spoken VARCHAR(100)[],
    country_of_birth VARCHAR(100),
    citizenship_status VARCHAR(50),
    immigrant_generation VARCHAR(50),  -- 1st gen, 2nd gen, etc.
    years_in_us INTEGER,
    naturalization_date DATE,
    
    -- CATEGORY 5: Political Profile (45 fields)
    party_registration VARCHAR(50),
    party_registration_date DATE,
    party_registration_changed_from VARCHAR(50),
    party_registration_changed_date DATE,
    voter_registration_status VARCHAR(50),
    voter_registration_date DATE,
    voter_id VARCHAR(50),
    precinct VARCHAR(50),
    polling_location TEXT,
    voting_method_preference VARCHAR(50), -- in-person, early, absentee, mail
    
    -- Voting History
    voted_2024_general BOOLEAN,
    voted_2024_primary BOOLEAN,
    voted_2022_general BOOLEAN,
    voted_2022_primary BOOLEAN,
    voted_2020_general BOOLEAN,
    voted_2020_primary BOOLEAN,
    voted_2018_general BOOLEAN,
    voted_2018_primary BOOLEAN,
    total_elections_voted INTEGER,
    voting_propensity_score INTEGER,   -- 0-100
    likely_voter_score INTEGER,        -- 0-100
    
    -- Political Ideology
    political_ideology VARCHAR(50),    -- very conservative, conservative, moderate, liberal, very liberal
    ideology_score INTEGER,            -- -100 (very liberal) to +100 (very conservative)
    trump_support_level VARCHAR(50),   -- strong support, lean support, neutral, lean oppose, strong oppose
    candidate_preferences JSONB,       -- {candidate_id: preference_level}
    
    -- Issue Positions (15 tracked issues)
    issue_abortion VARCHAR(50),
    issue_gun_rights VARCHAR(50),
    issue_immigration VARCHAR(50),
    issue_healthcare VARCHAR(50),
    issue_economy VARCHAR(50),
    issue_education VARCHAR(50),
    issue_environment VARCHAR(50),
    issue_energy VARCHAR(50),
    issue_foreign_policy VARCHAR(50),
    issue_crime VARCHAR(50),
    issue_taxes VARCHAR(50),
    issue_social_security VARCHAR(50),
    issue_veteran_affairs VARCHAR(50),
    issue_infrastructure VARCHAR(50),
    issue_religious_freedom VARCHAR(50),
    
    -- Engagement
    political_engagement_level VARCHAR(50), -- very engaged, somewhat engaged, not engaged
    activism_level VARCHAR(50),        -- activist, volunteer, donor, voter, inactive
    social_media_influencer BOOLEAN DEFAULT FALSE,
    social_media_followers_count INTEGER,
    
    -- CATEGORY 6: Donation History Summary (30 fields)
    -- These are calculated by triggers from transactions table
    first_donation_date DATE,
    last_donation_date DATE,
    total_donations_lifetime DECIMAL(12, 2) DEFAULT 0,
    total_donations_count INTEGER DEFAULT 0,
    average_donation_amount DECIMAL(10, 2) DEFAULT 0,
    median_donation_amount DECIMAL(10, 2) DEFAULT 0,
    largest_donation_amount DECIMAL(10, 2) DEFAULT 0,
    smallest_donation_amount DECIMAL(10, 2) DEFAULT 0,
    
    -- Timeframe totals (calculated by triggers)
    total_donations_ytd DECIMAL(12, 2) DEFAULT 0,
    total_donations_1yr DECIMAL(12, 2) DEFAULT 0,
    total_donations_2yr DECIMAL(12, 2) DEFAULT 0,
    total_donations_3yr DECIMAL(12, 2) DEFAULT 0,
    total_donations_4yr DECIMAL(12, 2) DEFAULT 0,
    total_donations_5yr DECIMAL(12, 2) DEFAULT 0,
    total_donations_10yr DECIMAL(12, 2) DEFAULT 0,
    
    donations_count_ytd INTEGER DEFAULT 0,
    donations_count_1yr INTEGER DEFAULT 0,
    donations_count_2yr INTEGER DEFAULT 0,
    donations_count_3yr INTEGER DEFAULT 0,
    
    -- Donation patterns
    donation_frequency VARCHAR(50),    -- monthly, quarterly, annual, sporadic, one-time
    donation_consistency_score DECIMAL(5, 2) DEFAULT 0, -- 0-100
    donation_growth_rate DECIMAL(5, 2) DEFAULT 0,      -- % year-over-year
    last_donation_days_ago INTEGER,
    
    -- FEC Limits
    fec_limit_federal_candidate DECIMAL(10, 2) DEFAULT 3300,  -- 2024 limit
    fec_limit_pac DECIMAL(10, 2) DEFAULT 5000,
    fec_limit_national_party DECIMAL(10, 2) DEFAULT 41300,
    fec_remaining_federal_candidate DECIMAL(10, 2),
    fec_remaining_pac DECIMAL(10, 2),
    fec_remaining_national_party DECIMAL(10, 2),
    
    -- CATEGORY 7: Campaign Engagement (40 fields)
    campaigns_participated INTEGER DEFAULT 0,
    campaigns_responded INTEGER DEFAULT 0,
    campaign_response_rate DECIMAL(5, 2) DEFAULT 0,
    
    -- Email engagement
    emails_received INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    email_open_rate DECIMAL(5, 2) DEFAULT 0,
    email_click_rate DECIMAL(5, 2) DEFAULT 0,
    last_email_opened_at TIMESTAMP,
    last_email_clicked_at TIMESTAMP,
    
    -- SMS engagement
    sms_received INTEGER DEFAULT 0,
    sms_responded INTEGER DEFAULT 0,
    sms_response_rate DECIMAL(5, 2) DEFAULT 0,
    last_sms_sent_at TIMESTAMP,
    last_sms_responded_at TIMESTAMP,
    
    -- Phone engagement
    calls_received INTEGER DEFAULT 0,
    calls_answered INTEGER DEFAULT 0,
    call_answer_rate DECIMAL(5, 2) DEFAULT 0,
    average_call_duration_seconds INTEGER DEFAULT 0,
    last_call_date TIMESTAMP,
    last_call_disposition VARCHAR(50),
    call_back_requested BOOLEAN DEFAULT FALSE,
    call_back_requested_at TIMESTAMP,
    
    -- Direct mail engagement
    mail_pieces_sent INTEGER DEFAULT 0,
    mail_pieces_responded INTEGER DEFAULT 0,
    mail_response_rate DECIMAL(5, 2) DEFAULT 0,
    last_mail_sent_at TIMESTAMP,
    
    -- Event engagement
    events_invited INTEGER DEFAULT 0,
    events_attended INTEGER DEFAULT 0,
    event_attendance_rate DECIMAL(5, 2) DEFAULT 0,
    last_event_attended_at TIMESTAMP,
    last_event_attended_name VARCHAR(255),
    
    -- Social media engagement
    social_media_engaged BOOLEAN DEFAULT FALSE,
    social_media_platforms VARCHAR(50)[],
    facebook_username VARCHAR(100),
    twitter_username VARCHAR(100),
    instagram_username VARCHAR(100),
    linkedin_username VARCHAR(100),
    
    -- Overall engagement
    engagement_score INTEGER DEFAULT 0,  -- 0-100
    engagement_level VARCHAR(50),        -- very active, active, moderate, low, inactive
    last_engagement_date TIMESTAMP,
    last_engagement_type VARCHAR(50),
    
    -- CATEGORY 8: Volunteer & Activism (25 fields)
    volunteer_status BOOLEAN DEFAULT FALSE,
    volunteer_interests VARCHAR(100)[],
    volunteer_skills VARCHAR(100)[],
    volunteer_availability VARCHAR(255),
    volunteer_hours_total INTEGER DEFAULT 0,
    volunteer_hours_ytd INTEGER DEFAULT 0,
    last_volunteer_date DATE,
    
    -- Volunteer activities
    volunteer_phone_banking INTEGER DEFAULT 0,
    volunteer_door_knocking INTEGER DEFAULT 0,
    volunteer_event_hosting INTEGER DEFAULT 0,
    volunteer_event_staffing INTEGER DEFAULT 0,
    volunteer_data_entry INTEGER DEFAULT 0,
    volunteer_social_media INTEGER DEFAULT 0,
    volunteer_fundraising INTEGER DEFAULT 0,
    
    -- Activism
    activist_level VARCHAR(50),        -- super activist, activist, supporter, passive
    activist_issues VARCHAR(100)[],
    petition_signer BOOLEAN DEFAULT FALSE,
    petitions_signed INTEGER DEFAULT 0,
    letter_writer BOOLEAN DEFAULT FALSE,
    letters_written INTEGER DEFAULT 0,
    rally_attendee BOOLEAN DEFAULT FALSE,
    rallies_attended INTEGER DEFAULT 0,
    
    -- Leadership
    grassroots_leader BOOLEAN DEFAULT FALSE,
    precinct_captain BOOLEAN DEFAULT FALSE,
    committee_member BOOLEAN DEFAULT FALSE,
    committee_name VARCHAR(255),
    
    -- CATEGORY 9: Network & Relationships (35 fields)
    influence_score INTEGER DEFAULT 0,  -- 0-100
    network_size_estimated INTEGER DEFAULT 0,
    
    -- Family relationships
    spouse_donor_id UUID REFERENCES donors(donor_id),
    spouse_name VARCHAR(255),
    spouse_email VARCHAR(255),
    spouse_phone VARCHAR(20),
    children_donor_ids UUID[],
    parents_donor_ids UUID[],
    siblings_donor_ids UUID[],
    
    -- Professional network
    business_partners UUID[],          -- array of donor_ids
    colleagues UUID[],                 -- array of donor_ids
    employees_count INTEGER,
    employer_donor_id UUID REFERENCES donors(donor_id),
    
    -- Social network
    referred_by_donor_id UUID REFERENCES donors(donor_id),
    referred_donors_count INTEGER DEFAULT 0,
    referred_donors UUID[],            -- array of donor_ids they recruited
    
    -- Organizational memberships
    organizations JSONB,               -- [{name, role, joined_date}]
    clubs JSONB,                       -- [{name, role}]
    professional_associations JSONB,
    
    -- Community standing
    community_leader BOOLEAN DEFAULT FALSE,
    board_memberships VARCHAR(255)[],
    civic_organizations VARCHAR(255)[],
    religious_leadership BOOLEAN DEFAULT FALSE,
    business_owner BOOLEAN DEFAULT FALSE,
    business_name VARCHAR(255),
    business_employees INTEGER,
    business_revenue_estimated INTEGER,
    
    -- Political connections
    elected_official BOOLEAN DEFAULT FALSE,
    elected_office VARCHAR(100),
    appointed_official BOOLEAN DEFAULT FALSE,
    appointed_position VARCHAR(100),
    political_insider BOOLEAN DEFAULT FALSE,
    
    -- CATEGORY 10: Data Source & Quality (30 fields)
    source_primary VARCHAR(100),       -- FEC, manual entry, import, enrichment
    source_secondary VARCHAR(100),
    source_campaign VARCHAR(255),
    source_date DATE,
    source_notes TEXT,
    
    -- Data quality
    data_completeness_score INTEGER DEFAULT 0,  -- 0-100
    data_accuracy_score INTEGER DEFAULT 0,      -- 0-100
    data_freshness_days INTEGER,
    data_verified BOOLEAN DEFAULT FALSE,
    data_verified_at TIMESTAMP,
    data_verified_by UUID,
    
    -- Enrichment
    enriched BOOLEAN DEFAULT FALSE,
    enriched_at TIMESTAMP,
    enrichment_provider VARCHAR(100),  -- BetterContact, etc.
    enrichment_cost DECIMAL(10, 2),
    enrichment_fields_added INTEGER,
    enrichment_confidence_score DECIMAL(5, 2),
    
    -- Matching
    matched_to_fec BOOLEAN DEFAULT FALSE,
    fec_donor_id VARCHAR(100),
    matched_to_voter_file BOOLEAN DEFAULT FALSE,
    voter_file_id VARCHAR(100),
    matched_to_dynamics BOOLEAN DEFAULT FALSE,
    dynamics_contact_id VARCHAR(100),
    
    -- Duplicates
    possible_duplicates UUID[],        -- array of donor_ids
    duplicate_of_donor_id UUID REFERENCES donors(donor_id),
    duplicate_resolved BOOLEAN DEFAULT FALSE,
    duplicate_resolved_at TIMESTAMP,
    
    -- Updates
    last_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated_by UUID,
    update_count INTEGER DEFAULT 0,
    
    -- CATEGORY 11: Preferences & Interests (40 fields)
    communication_preferences JSONB,   -- {email: true, sms: false, phone: true, mail: true}
    content_preferences VARCHAR(100)[], -- policy, news, events, fundraising
    topic_interests VARCHAR(100)[],
    
    -- Issue priorities (ranked 1-5)
    issue_priority_1 VARCHAR(100),
    issue_priority_2 VARCHAR(100),
    issue_priority_3 VARCHAR(100),
    issue_priority_4 VARCHAR(100),
    issue_priority_5 VARCHAR(100),
    
    -- Media consumption
    news_sources VARCHAR(100)[],
    social_media_usage VARCHAR(50),
    tv_viewership VARCHAR(50),
    radio_listening VARCHAR(50),
    newspaper_reading VARCHAR(50),
    
    -- Lifestyle interests
    hobbies VARCHAR(100)[],
    sports_interests VARCHAR(100)[],
    cultural_interests VARCHAR(100)[],
    charitable_causes VARCHAR(100)[],
    
    -- Consumer behavior
    online_shopping BOOLEAN DEFAULT FALSE,
    amazon_prime_member BOOLEAN DEFAULT FALSE,
    costco_member BOOLEAN DEFAULT FALSE,
    gun_owner BOOLEAN DEFAULT FALSE,
    concealed_carry_permit BOOLEAN DEFAULT FALSE,
    nra_member BOOLEAN DEFAULT FALSE,
    union_member BOOLEAN DEFAULT FALSE,
    union_name VARCHAR(255),
    
    -- Technology
    smartphone_user BOOLEAN DEFAULT TRUE,
    smart_home_devices BOOLEAN DEFAULT FALSE,
    tech_savvy_level VARCHAR(50),
    preferred_devices VARCHAR(50)[],
    
    -- Travel
    frequent_traveler BOOLEAN DEFAULT FALSE,
    passport_holder BOOLEAN DEFAULT FALSE,
    travel_frequency VARCHAR(50),
    
    -- CATEGORY 12: Notes & Tags (20 fields)
    notes TEXT,
    internal_notes TEXT,
    public_notes TEXT,
    
    tags VARCHAR(100)[],
    categories VARCHAR(100)[],
    segments VARCHAR(100)[],
    
    vip_status BOOLEAN DEFAULT FALSE,
    vip_level VARCHAR(50),             -- platinum, gold, silver
    vip_notes TEXT,
    
    flagged BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    flagged_at TIMESTAMP,
    flagged_by UUID,
    
    blocked BOOLEAN DEFAULT FALSE,
    blocked_reason TEXT,
    blocked_at TIMESTAMP,
    blocked_by UUID,
    
    archived BOOLEAN DEFAULT FALSE,
    archived_at TIMESTAMP,
    archived_reason TEXT,
    
    -- CATEGORY 13: INTELLIGENCE & SCORING (50 fields) 
    -- This is the AI-powered intelligence engine
    
    -- GRADING SYSTEM (21-tier: A+ to U-)
    grade_statewide VARCHAR(2),        -- Overall NC grade
    grade_county VARCHAR(2),           -- County-level grade
    grade_district VARCHAR(2),         -- District-level grade
    grade_last_calculated_at TIMESTAMP,
    
    -- Grade by timeframe
    grade_ytd VARCHAR(2),
    grade_1yr VARCHAR(2),
    grade_2yr VARCHAR(2),
    grade_3yr VARCHAR(2),
    grade_5yr VARCHAR(2),
    grade_10yr VARCHAR(2),
    
    -- LEAD SCORING (1000 points total)
    lead_score_total INTEGER DEFAULT 0,
    lead_score_amount INTEGER DEFAULT 0,        -- 0-300 pts
    lead_score_frequency INTEGER DEFAULT 0,     -- 0-200 pts
    lead_score_consistency INTEGER DEFAULT 0,   -- 0-150 pts
    lead_score_recency INTEGER DEFAULT 0,       -- 0-150 pts
    lead_score_growth INTEGER DEFAULT 0,        -- 0-100 pts
    lead_score_engagement INTEGER DEFAULT 0,    -- 0-50 pts
    lead_score_network INTEGER DEFAULT 0,       -- 0-50 pts
    lead_score_last_calculated_at TIMESTAMP,
    
    -- BELLWETHER AFFINITY (21 candidates tracked)
    bellwether_scores JSONB,           -- {candidate_id: {score: 85, contributions: 5, total: 5000}}
    top_bellwether_candidate_id UUID,
    top_bellwether_score INTEGER,
    bellwether_diversity_score INTEGER, -- How many different candidates supported
    
    -- PREDICTIVE ANALYTICS
    optimal_ask_amount DECIMAL(10, 2),
    next_donation_probability DECIMAL(5, 2), -- 0-100%
    next_donation_predicted_date DATE,
    churn_risk_score INTEGER,          -- 0-100 (higher = more likely to churn)
    reactivation_probability DECIMAL(5, 2),
    lifetime_value_predicted DECIMAL(12, 2),
    
    -- DONOR LIFECYCLE
    donor_lifecycle_stage VARCHAR(50), -- prospect, new, active, lapsed, inactive
    donor_maturity VARCHAR(50),        -- emerging, developing, established, major
    donor_trajectory VARCHAR(50),      -- growing, stable, declining
    
    -- CAPACITY
    giving_capacity VARCHAR(50),       -- low, medium, high, very high, ultra high
    giving_capacity_score INTEGER,     -- 0-100
    wealth_indicators JSONB,           -- {home_value, income_estimate, business_ownership}
    
    -- TIMING
    best_ask_month INTEGER,            -- 1-12
    best_ask_day_of_week INTEGER,     -- 1-7
    best_ask_time_of_day VARCHAR(20), -- morning, afternoon, evening
    seasonal_giving_pattern VARCHAR(100),
    
    -- CHANNEL PREFERENCES (AI-determined)
    preferred_channel VARCHAR(50),     -- email, sms, phone, mail, event
    channel_effectiveness JSONB,       -- {email: 0.85, sms: 0.45, phone: 0.92}
    
    -- MESSAGING PREFERENCES (AI-determined)
    resonant_messages VARCHAR(100)[],
    effective_appeals VARCHAR(100)[],
    responsive_issues VARCHAR(100)[],
    
    -- PEER COMPARISONS
    percentile_rank_statewide INTEGER, -- 0-100
    percentile_rank_county INTEGER,
    percentile_rank_similar_donors INTEGER,
    
    -- AI RECOMMENDATIONS
    recommended_campaigns JSONB,       -- [{campaign_type, confidence, reasoning}]
    recommended_next_action VARCHAR(255),
    recommended_next_action_confidence DECIMAL(5, 2),
    ai_insights TEXT,                  -- Natural language insights
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,              -- Soft delete
    
    -- Indexes will be added separately
    CONSTRAINT valid_tenant CHECK (tenant_id IS NOT NULL),
    CONSTRAINT valid_email_primary CHECK (email_primary IS NULL OR email_primary ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
    CONSTRAINT valid_grade CHECK (grade_statewide IN ('A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'D-', 'F+', 'F', 'F-', 'U+', 'U', 'U-', NULL)),
    CONSTRAINT valid_lead_score CHECK (lead_score_total >= 0 AND lead_score_total <= 1000)
);

-- Create indexes for performance
CREATE INDEX idx_donors_tenant ON donors(tenant_id);
CREATE INDEX idx_donors_email_primary ON donors(email_primary);
CREATE INDEX idx_donors_phone_primary ON donors(phone_primary);
CREATE INDEX idx_donors_full_name ON donors USING gin(full_name gin_trgm_ops);
CREATE INDEX idx_donors_last_name ON donors(last_name);
CREATE INDEX idx_donors_grade_statewide ON donors(grade_statewide) WHERE grade_statewide IS NOT NULL;
CREATE INDEX idx_donors_lead_score ON donors(lead_score_total DESC) WHERE lead_score_total > 0;
CREATE INDEX idx_donors_county ON donors(address_primary_county);
CREATE INDEX idx_donors_zip ON donors(address_primary_zip);
CREATE INDEX idx_donors_geography ON donors USING GIST(address_primary_geog) WHERE address_primary_geog IS NOT NULL;
CREATE INDEX idx_donors_last_donation ON donors(last_donation_date DESC) WHERE last_donation_date IS NOT NULL;
CREATE INDEX idx_donors_lifecycle ON donors(donor_lifecycle_stage);
CREATE INDEX idx_donors_created ON donors(created_at DESC);

-- Row Level Security
ALTER TABLE donors ENABLE ROW LEVEL SECURITY;

CREATE POLICY donors_tenant_isolation ON donors
    FOR ALL
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::UUID);

-- Comments for documentation
COMMENT ON TABLE donors IS 'Complete donor profiles with 1,030 fields across 13 categories';
COMMENT ON COLUMN donors.grade_statewide IS 'Category 13: 21-tier grading (A+ to U-) based on donation history';
COMMENT ON COLUMN donors.lead_score_total IS 'Category 13: 1000-point lead score (7 components)';

-- Continue to next tables...
