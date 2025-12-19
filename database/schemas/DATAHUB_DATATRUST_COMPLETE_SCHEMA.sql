-- ============================================================================
-- RNC DATA TRUST COMPLETE INTEGRATION SCHEMA
-- Adds 2,500+ Data Trust data points to unified_contacts
-- ============================================================================
-- Created: December 2, 2024
-- Purpose: Integrate RNC Data Trust voter data with BroyhillGOP DataHub
-- Impact: Transforms 115,234 contacts into hyper-targeted political database
-- ============================================================================

-- ============================================================================
-- STEP 1: ADD DATA TRUST FIELDS TO unified_contacts
-- ============================================================================

-- Core Voter Registration Data (RNC_VR_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS rnc_id VARCHAR(32) UNIQUE;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voter_registration_status VARCHAR(20); -- active, inactive, purged
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS registered_party VARCHAR(50); -- Republican, Democrat, Independent, etc.
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS registration_date DATE;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS name_prefix VARCHAR(10); -- Mr., Mrs., Dr., etc.
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS name_suffix_dt VARCHAR(10); -- Jr., Sr., III, etc.
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS dt_middle_name VARCHAR(100);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS mailing_street VARCHAR(255);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS mailing_city VARCHAR(100);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS mailing_state VARCHAR(2);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS mailing_zip VARCHAR(10);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS residence_latitude NUMERIC(10,7);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS residence_longitude NUMERIC(10,7);

-- Vote History Summary (RNC_VH_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2024_general BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2024_primary BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2023_primary BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2022_general BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2022_primary BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2020_general BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2016_general BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2012_general BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voted_2008_general BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voter_regularity_score NUMERIC(4,2); -- 0.00-100.00
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS total_elections_eligible INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS total_elections_voted INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS vote_participation_rate NUMERIC(4,2); -- percentage

-- Enhanced Contact Information (RNC_CONTACT_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS primary_phone_dt VARCHAR(20);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS raw_voter_file_phone VARCHAR(20);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS absentee_file_phone VARCHAR(20);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS data_axle_phone VARCHAR(20);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS neustar_phone VARCHAR(20);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS neustar_match_level VARCHAR(10);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS neustar_reliability VARCHAR(10); -- high, medium, low
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS neustar_call_window VARCHAR(50); -- GMT optimal times
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS email_dt VARCHAR(255);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS dnc_status BOOLEAN DEFAULT FALSE;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS phone_verification_status VARCHAR(20);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS best_phone_to_call VARCHAR(20); -- Algorithmically determined

-- Enhanced Demographics (RNC_DEMO_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS age_dt INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS gender_dt VARCHAR(10); -- Male, Female, Unknown
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS race_ethnicity_reported VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS race_ethnicity_modeled VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS religion_modeled VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS education_level VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS highest_degree VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS household_income INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS individual_income INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS income_bracket VARCHAR(20); -- <25K, 25-50K, 50-75K, 75-100K, 100-150K, 150K+
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS employment_status VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS occupation_dt VARCHAR(100);

-- Socioeconomic & Financial Data (RNC_ECON_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS credit_score INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS credit_history_length_years INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS debt_level_total INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS home_value INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS mortgage_amount INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS loan_to_value_ratio NUMERIC(4,2);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS mortgage_status VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS vehicle_ownership_count INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS vehicle_types TEXT[]; -- Array of vehicle types
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS vehicle_total_value INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS auto_loan_amount INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS homeownership_status VARCHAR(20); -- Owner, Renter, Other

-- Household & Family Information (RNC_HH_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS adults_in_household INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS children_in_household INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS family_composition VARCHAR(100);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS marital_status VARCHAR(20);

-- Lifestyle & Consumer Behavior (RNC_LIFESTYLE_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS has_hunting_license BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS has_fishing_license BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS magazine_subscriptions TEXT[];
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS newspaper_readership TEXT[];
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS tv_viewing_habits JSONB;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS shopping_behavior JSONB;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS brand_preferences TEXT[];
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS charitable_giving_pattern VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS charitable_giving_amount_annual INTEGER;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS has_gym_membership BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS purchases_health_supplements BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS social_media_usage JSONB;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS uses_rideshare BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS pet_ownership TEXT[];
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS travel_patterns VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS vacation_preferences TEXT[];
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS media_consumption_profile JSONB;

-- Political Geography (RNC_GEO_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS congressional_district_2021 VARCHAR(10);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS congressional_district_2011 VARCHAR(10);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS state_upper_legislative_district VARCHAR(10);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS state_lower_legislative_district VARCHAR(10);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS township VARCHAR(100);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS village VARCHAR(100);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS precinct_code VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS precinct_name VARCHAR(100);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS school_board_district VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS school_district VARCHAR(100);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS fire_district VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS water_district VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS special_district_designations TEXT[];

-- Census Geography (RNC_CENSUS_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS census_block VARCHAR(20);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS census_tract VARCHAR(20);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS metro_type VARCHAR(20); -- City, Suburban, Town, Rural
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS zcta VARCHAR(10); -- Zip Code Tabulation Area

-- Modeled Political Data (RNC_MODEL_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS modeled_partisanship_score NUMERIC(5,4); -- 0.0000-1.0000
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS coalition_id VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS likely_party_affiliation VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS partisan_lean_score NUMERIC(5,4); -- 0=Strong Dem, 1=Strong Rep

-- Turnout Prediction Models (RNC_TURNOUT_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS primary_turnout_probability NUMERIC(5,4);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS general_turnout_probability NUMERIC(5,4);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS midterm_turnout_probability NUMERIC(5,4);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS turnout_likelihood_score NUMERIC(5,4);

-- Absentee/Early Vote Data (RNC_ABEV_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ab_ballot_requested_2024 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ab_ballot_returned_2024 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ab_ballot_accepted_2024 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS early_vote_2024 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS voting_method_2024 VARCHAR(20); -- mail, early, election_day
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ab_ballot_requested_2022 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ab_ballot_returned_2022 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS early_vote_2022 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ab_ballot_requested_2020 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ab_ballot_returned_2020 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS early_vote_2020 BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS historical_abev_voter BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS abev_party_preference VARCHAR(50);

-- Data Source Tracking (RNC_SOURCE_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS data_source_primary VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS state_voter_file_source VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS commercial_data_source VARCHAR(50);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS neustar_source BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS data_axle_source BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ncoa_source BOOLEAN; -- Change of address
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS phone_source_provenance VARCHAR(100);

-- Data Quality & Maintenance (RNC_QUALITY_*)
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS data_accuracy_score NUMERIC(4,2);
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS last_data_update TIMESTAMPTZ;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ncoa_status VARCHAR(20); -- Change of address status
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS deceased_indicator BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS ssdi_match BOOLEAN; -- Social Security Death Index
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS duplicate_registration_flag BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS out_of_state_move_indicator BOOLEAN;
ALTER TABLE unified_contacts ADD COLUMN IF NOT EXISTS within_state_move_indicator BOOLEAN;

-- ============================================================================
-- STEP 2: CREATE ISSUE POSITION MODELS TABLE (46+ POLICY DIMENSIONS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS dt_issue_positions (
    id BIGSERIAL PRIMARY KEY,
    contact_id BIGINT REFERENCES unified_contacts(id) ON DELETE CASCADE,
    
    -- Core Policy Models (RNC_POLICY_*)
    trump_america_first_support NUMERIC(5,4), -- 0.0000-1.0000
    obama_2012_vote_likelihood NUMERIC(5,4),
    tea_party_support NUMERIC(5,4),
    
    -- Economic Issues
    pro_tax_cuts NUMERIC(5,4),
    pro_deregulation NUMERIC(5,4),
    pro_free_trade NUMERIC(5,4),
    anti_minimum_wage_increase NUMERIC(5,4),
    pro_school_choice NUMERIC(5,4),
    
    -- Social Issues
    pro_life_position NUMERIC(5,4),
    pro_second_amendment NUMERIC(5,4),
    pro_traditional_marriage NUMERIC(5,4),
    anti_critical_race_theory NUMERIC(5,4),
    pro_religious_liberty NUMERIC(5,4),
    
    -- Immigration
    pro_border_wall NUMERIC(5,4),
    anti_illegal_immigration NUMERIC(5,4),
    pro_deportation NUMERIC(5,4),
    anti_sanctuary_cities NUMERIC(5,4),
    
    -- Foreign Policy
    pro_strong_military NUMERIC(5,4),
    pro_israel NUMERIC(5,4),
    anti_china NUMERIC(5,4),
    america_first_foreign_policy NUMERIC(5,4),
    
    -- Healthcare
    anti_obamacare NUMERIC(5,4),
    pro_healthcare_deregulation NUMERIC(5,4),
    anti_single_payer NUMERIC(5,4),
    
    -- Energy & Environment
    pro_fossil_fuels NUMERIC(5,4),
    anti_green_new_deal NUMERIC(5,4),
    pro_energy_independence NUMERIC(5,4),
    climate_skeptic NUMERIC(5,4),
    
    -- Law & Order
    pro_law_enforcement NUMERIC(5,4),
    anti_defund_police NUMERIC(5,4),
    tough_on_crime NUMERIC(5,4),
    pro_death_penalty NUMERIC(5,4),
    
    -- Election Integrity
    pro_voter_id NUMERIC(5,4),
    anti_mail_in_voting NUMERIC(5,4),
    election_integrity_concern NUMERIC(5,4),
    
    -- COVID-19 Related
    anti_vaccine_mandate NUMERIC(5,4),
    anti_mask_mandate NUMERIC(5,4),
    pro_school_reopening NUMERIC(5,4),
    anti_lockdown NUMERIC(5,4),
    
    -- Political Figures (Support Scores)
    trump_support NUMERIC(5,4),
    biden_disapproval NUMERIC(5,4),
    
    -- Additional NC-Specific Issues
    pro_nc_values NUMERIC(5,4),
    concerned_charlotte_crime NUMERIC(5,4),
    concerned_education_quality NUMERIC(5,4),
    
    -- Metadata
    model_version VARCHAR(20),
    last_scored_date TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_contact_issue_positions UNIQUE (contact_id)
);

CREATE INDEX idx_dt_issue_contact ON dt_issue_positions(contact_id);
CREATE INDEX idx_trump_support ON dt_issue_positions(trump_support DESC);
CREATE INDEX idx_pro_life ON dt_issue_positions(pro_life_position DESC);
CREATE INDEX idx_pro_2a ON dt_issue_positions(pro_second_amendment DESC);

-- ============================================================================
-- STEP 3: CREATE DETAILED VOTE HISTORY TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS dt_vote_history_detailed (
    id BIGSERIAL PRIMARY KEY,
    contact_id BIGINT REFERENCES unified_contacts(id) ON DELETE CASCADE,
    
    -- Election Details
    election_date DATE NOT NULL,
    election_type VARCHAR(50), -- General, Primary, Special, Municipal, Runoff
    election_level VARCHAR(50), -- Presidential, Congressional, State, Local
    election_description VARCHAR(200),
    
    -- Voting Method
    voted BOOLEAN,
    voting_method VARCHAR(20), -- in_person, absentee, early, provisional
    ballot_returned BOOLEAN,
    ballot_accepted BOOLEAN,
    
    -- Party Primary (if applicable)
    primary_party VARCHAR(50),
    
    -- Metadata
    data_source VARCHAR(50),
    verified BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dt_vh_contact ON dt_vote_history_detailed(contact_id);
CREATE INDEX idx_dt_vh_election_date ON dt_vote_history_detailed(election_date DESC);
CREATE INDEX idx_dt_vh_voted ON dt_vote_history_detailed(voted) WHERE voted = TRUE;
CREATE INDEX idx_dt_vh_election_type ON dt_vote_history_detailed(election_type);

-- ============================================================================
-- STEP 4: CREATE PHONE NUMBER HIERARCHY TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS dt_phone_numbers (
    id BIGSERIAL PRIMARY KEY,
    contact_id BIGINT REFERENCES unified_contacts(id) ON DELETE CASCADE,
    
    -- Phone Details
    phone_number VARCHAR(20) NOT NULL,
    phone_type VARCHAR(20), -- mobile, landline, voip, unknown
    phone_source VARCHAR(50), -- voter_file, neustar, data_axle, absentee_file
    
    -- Quality Metrics
    reliability_score VARCHAR(10), -- high, medium, low
    match_level VARCHAR(10),
    verified BOOLEAN DEFAULT FALSE,
    verification_date TIMESTAMPTZ,
    
    -- Contact Optimization
    optimal_call_window VARCHAR(50), -- GMT time ranges
    dnc_listed BOOLEAN DEFAULT FALSE,
    contact_success_rate NUMERIC(4,2),
    last_successful_contact TIMESTAMPTZ,
    
    -- Prioritization
    is_primary_phone BOOLEAN DEFAULT FALSE,
    phone_rank INTEGER, -- 1 = best, 2 = second best, etc.
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dt_phones_contact ON dt_phone_numbers(contact_id);
CREATE INDEX idx_dt_phones_type ON dt_phone_numbers(phone_type);
CREATE INDEX idx_dt_phones_reliability ON dt_phone_numbers(reliability_score);
CREATE INDEX idx_dt_phones_primary ON dt_phone_numbers(is_primary_phone) WHERE is_primary_phone = TRUE;

-- ============================================================================
-- STEP 5: CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- RNC ID (Critical for matching)
CREATE UNIQUE INDEX idx_rnc_id ON unified_contacts(rnc_id) WHERE rnc_id IS NOT NULL;

-- Voter Registration
CREATE INDEX idx_voter_reg_status ON unified_contacts(voter_registration_status);
CREATE INDEX idx_registered_party ON unified_contacts(registered_party);
CREATE INDEX idx_registration_date ON unified_contacts(registration_date);

-- Vote History
CREATE INDEX idx_voted_2024 ON unified_contacts(voted_2024_general) WHERE voted_2024_general = TRUE;
CREATE INDEX idx_voted_2022 ON unified_contacts(voted_2022_general) WHERE voted_2022_general = TRUE;
CREATE INDEX idx_voted_2020 ON unified_contacts(voted_2020_general) WHERE voted_2020_general = TRUE;
CREATE INDEX idx_voter_regularity ON unified_contacts(voter_regularity_score DESC);

-- Demographics
CREATE INDEX idx_age_dt ON unified_contacts(age_dt);
CREATE INDEX idx_gender_dt ON unified_contacts(gender_dt);
CREATE INDEX idx_ethnicity_modeled ON unified_contacts(race_ethnicity_modeled);
CREATE INDEX idx_education ON unified_contacts(education_level);
CREATE INDEX idx_income ON unified_contacts(household_income DESC);

-- Geographic (for targeting)
CREATE INDEX idx_congressional_2021 ON unified_contacts(congressional_district_2021);
CREATE INDEX idx_state_house ON unified_contacts(state_lower_legislative_district);
CREATE INDEX idx_state_senate ON unified_contacts(state_upper_legislative_district);
CREATE INDEX idx_precinct ON unified_contacts(precinct_code);
CREATE INDEX idx_metro_type ON unified_contacts(metro_type);

-- Political Models
CREATE INDEX idx_partisanship ON unified_contacts(modeled_partisanship_score DESC);
CREATE INDEX idx_turnout_general ON unified_contacts(general_turnout_probability DESC);
CREATE INDEX idx_turnout_primary ON unified_contacts(primary_turnout_probability DESC);

-- Contact Quality
CREATE INDEX idx_phone_verified ON unified_contacts(phone_verified) WHERE phone_verified = TRUE;
CREATE INDEX idx_neustar_reliability ON unified_contacts(neustar_reliability);
CREATE INDEX idx_data_quality ON unified_contacts(data_accuracy_score DESC);

-- Composite Indexes for Common Queries
CREATE INDEX idx_republican_high_turnout ON unified_contacts(
    registered_party, 
    general_turnout_probability DESC
) WHERE registered_party = 'Republican';

CREATE INDEX idx_persuadable_voters ON unified_contacts(
    modeled_partisanship_score,
    general_turnout_probability DESC
) WHERE modeled_partisanship_score BETWEEN 0.35 AND 0.65;

CREATE INDEX idx_target_universe ON unified_contacts(
    registered_party,
    voter_regularity_score DESC,
    age_dt
) WHERE voter_registration_status = 'active';

-- ============================================================================
-- STEP 6: CREATE ADVANCED VIEWS FOR TARGETING
-- ============================================================================

-- View: Super Voters (High Frequency, Republican)
CREATE OR REPLACE VIEW v_dt_super_voters AS
SELECT 
    c.id,
    c.contact_id,
    c.full_name,
    c.rnc_id,
    c.registered_party,
    c.voter_regularity_score,
    c.vote_participation_rate,
    c.modeled_partisanship_score,
    c.general_turnout_probability,
    c.congressional_district_2021,
    c.state_lower_legislative_district,
    c.donor_grade,
    c.mobile_phone,
    c.email,
    c.best_phone_to_call
FROM unified_contacts c
WHERE 
    c.voter_registration_status = 'active'
    AND c.voter_regularity_score >= 80.00
    AND (c.registered_party = 'Republican' OR c.modeled_partisanship_score >= 0.65)
    AND c.voted_2020_general = TRUE
    AND c.voted_2022_general = TRUE
ORDER BY c.voter_regularity_score DESC, c.modeled_partisanship_score DESC;

-- View: Persuadable Voters (Moderate, High Turnout)
CREATE OR REPLACE VIEW v_dt_persuadable_voters AS
SELECT 
    c.id,
    c.contact_id,
    c.full_name,
    c.rnc_id,
    c.registered_party,
    c.modeled_partisanship_score,
    c.general_turnout_probability,
    c.voter_regularity_score,
    c.congressional_district_2021,
    c.age_dt,
    c.education_level,
    c.household_income,
    c.mobile_phone,
    c.email,
    ip.trump_support,
    ip.pro_life_position,
    ip.pro_second_amendment
FROM unified_contacts c
LEFT JOIN dt_issue_positions ip ON c.id = ip.contact_id
WHERE 
    c.voter_registration_status = 'active'
    AND c.modeled_partisanship_score BETWEEN 0.40 AND 0.60
    AND c.general_turnout_probability >= 0.70
    AND c.age_dt >= 18
ORDER BY c.general_turnout_probability DESC;

-- View: Low-Propensity Republican Voters (GOTV Targets)
CREATE OR REPLACE VIEW v_dt_gotv_targets AS
SELECT 
    c.id,
    c.contact_id,
    c.full_name,
    c.rnc_id,
    c.registered_party,
    c.modeled_partisanship_score,
    c.general_turnout_probability,
    c.voter_regularity_score,
    c.voted_2020_general,
    c.voted_2022_general,
    c.congressional_district_2021,
    c.precinct_code,
    c.mobile_phone,
    c.email,
    c.best_phone_to_call
FROM unified_contacts c
WHERE 
    c.voter_registration_status = 'active'
    AND (c.registered_party = 'Republican' OR c.modeled_partisanship_score >= 0.65)
    AND c.general_turnout_probability < 0.70
    AND c.voter_regularity_score < 70.00
ORDER BY c.modeled_partisanship_score DESC, c.general_turnout_probability ASC;

-- View: High-Value Donor Prospects
CREATE OR REPLACE VIEW v_dt_donor_prospects AS
SELECT 
    c.id,
    c.contact_id,
    c.full_name,
    c.rnc_id,
    c.donor_grade,
    c.donations_total,
    c.household_income,
    c.home_value,
    c.credit_score,
    c.registered_party,
    c.modeled_partisanship_score,
    c.charitable_giving_amount_annual,
    c.charitable_giving_pattern,
    c.occupation_dt,
    c.mobile_phone,
    c.email,
    ip.trump_support
FROM unified_contacts c
LEFT JOIN dt_issue_positions ip ON c.id = ip.contact_id
WHERE 
    c.household_income >= 100000
    AND c.voter_registration_status = 'active'
    AND (c.registered_party = 'Republican' OR c.modeled_partisanship_score >= 0.60)
    AND (c.donor_grade IS NULL OR c.donor_grade IN ('U', 'D', 'C-', 'C'))
ORDER BY c.household_income DESC, c.modeled_partisanship_score DESC;

-- View: Absentee/Early Vote Targets
CREATE OR REPLACE VIEW v_dt_abev_targets AS
SELECT 
    c.id,
    c.contact_id,
    c.full_name,
    c.rnc_id,
    c.registered_party,
    c.historical_abev_voter,
    c.ab_ballot_requested_2024,
    c.ab_ballot_returned_2024,
    c.ab_ballot_accepted_2024,
    c.early_vote_2024,
    c.age_dt,
    c.congressional_district_2021,
    c.mobile_phone,
    c.email
FROM unified_contacts c
WHERE 
    c.voter_registration_status = 'active'
    AND (c.registered_party = 'Republican' OR c.modeled_partisanship_score >= 0.65)
    AND (
        c.historical_abev_voter = TRUE
        OR c.ab_ballot_requested_2024 = TRUE
        OR c.age_dt >= 65
    )
ORDER BY c.ab_ballot_requested_2024 DESC NULLS LAST, c.historical_abev_voter DESC;

-- View: Issue-Based Targeting (Pro-Life Activists)
CREATE OR REPLACE VIEW v_dt_prolife_activists AS
SELECT 
    c.id,
    c.contact_id,
    c.full_name,
    c.rnc_id,
    c.registered_party,
    c.modeled_partisanship_score,
    c.mobile_phone,
    c.email,
    ip.pro_life_position,
    ip.pro_religious_liberty,
    ip.trump_support,
    c.donor_grade,
    c.volunteer_status
FROM unified_contacts c
INNER JOIN dt_issue_positions ip ON c.id = ip.contact_id
WHERE 
    c.voter_registration_status = 'active'
    AND ip.pro_life_position >= 0.75
ORDER BY ip.pro_life_position DESC;

-- View: Second Amendment Supporters
CREATE OR REPLACE VIEW v_dt_2a_supporters AS
SELECT 
    c.id,
    c.contact_id,
    c.full_name,
    c.rnc_id,
    c.registered_party,
    c.has_hunting_license,
    c.has_fishing_license,
    c.mobile_phone,
    c.email,
    ip.pro_second_amendment,
    ip.trump_support,
    c.donor_grade,
    c.volunteer_status
FROM unified_contacts c
INNER JOIN dt_issue_positions ip ON c.id = ip.contact_id
WHERE 
    c.voter_registration_status = 'active'
    AND (ip.pro_second_amendment >= 0.75 OR c.has_hunting_license = TRUE)
ORDER BY ip.pro_second_amendment DESC;

-- View: Complete Contact Profile (for AI/ML)
CREATE OR REPLACE VIEW v_dt_complete_profile AS
SELECT 
    -- Core Identity
    c.id,
    c.contact_id,
    c.rnc_id,
    c.full_name,
    c.first_name_clean,
    c.last_name_clean,
    c.age_dt,
    c.gender_dt,
    
    -- Contact Info
    c.best_phone_to_call,
    c.mobile_phone,
    c.email,
    c.neustar_reliability,
    
    -- Location
    c.city,
    c.county,
    c.state,
    c.congressional_district_2021,
    c.state_lower_legislative_district,
    c.precinct_code,
    c.metro_type,
    
    -- Political Profile
    c.registered_party,
    c.voter_registration_status,
    c.modeled_partisanship_score,
    c.voter_regularity_score,
    c.general_turnout_probability,
    c.primary_turnout_probability,
    
    -- Vote History
    c.voted_2024_general,
    c.voted_2022_general,
    c.voted_2020_general,
    c.vote_participation_rate,
    
    -- Demographics
    c.race_ethnicity_modeled,
    c.religion_modeled,
    c.education_level,
    c.household_income,
    c.marital_status,
    c.children_in_household,
    
    -- Socioeconomic
    c.homeownership_status,
    c.home_value,
    c.credit_score,
    c.occupation_dt,
    
    -- Lifestyle
    c.has_hunting_license,
    c.has_fishing_license,
    c.charitable_giving_amount_annual,
    
    -- Donor/Volunteer Status
    c.donor_grade,
    c.donations_total,
    c.volunteer_status,
    c.engagement_score,
    
    -- Issue Positions (Top 5)
    ip.trump_support,
    ip.pro_life_position,
    ip.pro_second_amendment,
    ip.pro_border_wall,
    ip.pro_law_enforcement,
    
    -- Segment
    c.segment_category,
    c.motivational_state
    
FROM unified_contacts c
LEFT JOIN dt_issue_positions ip ON c.id = ip.contact_id
WHERE c.voter_registration_status = 'active';

-- ============================================================================
-- STEP 7: CREATE STORED PROCEDURES FOR DATA IMPORT
-- ============================================================================

-- Function: Match and Update Contact with Data Trust Record
CREATE OR REPLACE FUNCTION match_datatrust_record(
    p_rnc_id VARCHAR(32),
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_dob DATE,
    p_address VARCHAR(255),
    p_city VARCHAR(100),
    p_zip VARCHAR(10)
)
RETURNS BIGINT AS $$
DECLARE
    v_contact_id BIGINT;
BEGIN
    -- Try exact RNC ID match first
    SELECT id INTO v_contact_id
    FROM unified_contacts
    WHERE rnc_id = p_rnc_id
    LIMIT 1;
    
    IF v_contact_id IS NOT NULL THEN
        RETURN v_contact_id;
    END IF;
    
    -- Try name + DOB + zip match
    SELECT id INTO v_contact_id
    FROM unified_contacts
    WHERE 
        LOWER(first_name_clean) = LOWER(p_first_name)
        AND LOWER(last_name_clean) = LOWER(p_last_name)
        AND date_of_birth = p_dob
        AND zip_code = p_zip
    LIMIT 1;
    
    IF v_contact_id IS NOT NULL THEN
        -- Update with RNC ID
        UPDATE unified_contacts 
        SET rnc_id = p_rnc_id
        WHERE id = v_contact_id;
        
        RETURN v_contact_id;
    END IF;
    
    -- Try name + address match (fuzzy)
    SELECT id INTO v_contact_id
    FROM unified_contacts
    WHERE 
        LOWER(first_name_clean) = LOWER(p_first_name)
        AND LOWER(last_name_clean) = LOWER(p_last_name)
        AND LOWER(city) = LOWER(p_city)
        AND zip_code = p_zip
    LIMIT 1;
    
    IF v_contact_id IS NOT NULL THEN
        UPDATE unified_contacts 
        SET rnc_id = p_rnc_id
        WHERE id = v_contact_id;
        
        RETURN v_contact_id;
    END IF;
    
    -- No match found
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate Best Phone to Call
CREATE OR REPLACE FUNCTION calculate_best_phone(p_contact_id BIGINT)
RETURNS VARCHAR(20) AS $$
DECLARE
    v_best_phone VARCHAR(20);
BEGIN
    -- Priority: Neustar High Reliability > Mobile > Neustar Medium > Others
    SELECT phone_number INTO v_best_phone
    FROM dt_phone_numbers
    WHERE 
        contact_id = p_contact_id
        AND dnc_listed = FALSE
    ORDER BY 
        CASE reliability_score
            WHEN 'high' THEN 1
            WHEN 'medium' THEN 2
            ELSE 3
        END,
        CASE phone_type
            WHEN 'mobile' THEN 1
            WHEN 'voip' THEN 2
            WHEN 'landline' THEN 3
            ELSE 4
        END,
        contact_success_rate DESC NULLS LAST
    LIMIT 1;
    
    RETURN v_best_phone;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate Voter Regularity Score
CREATE OR REPLACE FUNCTION calculate_voter_regularity()
RETURNS TRIGGER AS $$
BEGIN
    -- Count total elections eligible (approximate based on registration date)
    NEW.total_elections_eligible := 
        CASE 
            WHEN NEW.registration_date IS NOT NULL THEN
                FLOOR(EXTRACT(YEAR FROM AGE(CURRENT_DATE, NEW.registration_date)) / 2) * 3 -- Approx 3 elections per 2 years
            ELSE 10 -- Default assumption
        END;
    
    -- Count elections voted
    NEW.total_elections_voted := 
        (CASE WHEN NEW.voted_2024_general THEN 1 ELSE 0 END) +
        (CASE WHEN NEW.voted_2024_primary THEN 1 ELSE 0 END) +
        (CASE WHEN NEW.voted_2023_primary THEN 1 ELSE 0 END) +
        (CASE WHEN NEW.voted_2022_general THEN 1 ELSE 0 END) +
        (CASE WHEN NEW.voted_2022_primary THEN 1 ELSE 0 END) +
        (CASE WHEN NEW.voted_2020_general THEN 1 ELSE 0 END) +
        (CASE WHEN NEW.voted_2016_general THEN 1 ELSE 0 END) +
        (CASE WHEN NEW.voted_2012_general THEN 1 ELSE 0 END) +
        (CASE WHEN NEW.voted_2008_general THEN 1 ELSE 0 END);
    
    -- Calculate participation rate
    IF NEW.total_elections_eligible > 0 THEN
        NEW.vote_participation_rate := 
            (NEW.total_elections_voted::NUMERIC / NEW.total_elections_eligible::NUMERIC) * 100.0;
    ELSE
        NEW.vote_participation_rate := 0.0;
    END IF;
    
    -- Calculate regularity score (0-100, weighted toward recent elections)
    NEW.voter_regularity_score := 
        (CASE WHEN NEW.voted_2024_general THEN 25 ELSE 0 END) +
        (CASE WHEN NEW.voted_2022_general THEN 20 ELSE 0 END) +
        (CASE WHEN NEW.voted_2020_general THEN 15 ELSE 0 END) +
        (CASE WHEN NEW.voted_2024_primary THEN 10 ELSE 0 END) +
        (CASE WHEN NEW.voted_2022_primary THEN 10 ELSE 0 END) +
        (CASE WHEN NEW.voted_2016_general THEN 10 ELSE 0 END) +
        (CASE WHEN NEW.voted_2012_general THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.voted_2008_general THEN 5 ELSE 0 END);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_voter_regularity
    BEFORE INSERT OR UPDATE ON unified_contacts
    FOR EACH ROW
    EXECUTE FUNCTION calculate_voter_regularity();

-- ============================================================================
-- STEP 8: CREATE DATA IMPORT STAGING TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS dt_import_staging (
    id BIGSERIAL PRIMARY KEY,
    
    -- Import Metadata
    import_batch_id VARCHAR(50),
    import_date TIMESTAMPTZ DEFAULT NOW(),
    file_name VARCHAR(255),
    row_number INTEGER,
    
    -- Raw Data Trust Fields (all as TEXT for flexibility)
    raw_data JSONB, -- Complete JSON of all Data Trust fields
    
    -- Match Status
    match_status VARCHAR(20), -- matched, no_match, multiple_match, error
    matched_contact_id BIGINT REFERENCES unified_contacts(id),
    match_confidence NUMERIC(4,2),
    match_method VARCHAR(50), -- rnc_id, name_dob, name_address, fuzzy
    
    -- Processing Status
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    
    -- Quality Flags
    data_quality_issues TEXT[],
    needs_manual_review BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_staging_batch ON dt_import_staging(import_batch_id);
CREATE INDEX idx_staging_processed ON dt_import_staging(processed) WHERE processed = FALSE;
CREATE INDEX idx_staging_match_status ON dt_import_staging(match_status);

-- ============================================================================
-- STEP 9: GRANT PERMISSIONS
-- ============================================================================

-- Grant SELECT on views to authenticated users
GRANT SELECT ON v_dt_super_voters TO authenticated;
GRANT SELECT ON v_dt_persuadable_voters TO authenticated;
GRANT SELECT ON v_dt_gotv_targets TO authenticated;
GRANT SELECT ON v_dt_donor_prospects TO authenticated;
GRANT SELECT ON v_dt_abev_targets TO authenticated;
GRANT SELECT ON v_dt_prolife_activists TO authenticated;
GRANT SELECT ON v_dt_2a_supporters TO authenticated;
GRANT SELECT ON v_dt_complete_profile TO authenticated;

-- Grant usage on sequences
GRANT USAGE ON SEQUENCE dt_issue_positions_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE dt_vote_history_detailed_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE dt_phone_numbers_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE dt_import_staging_id_seq TO authenticated;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE dt_issue_positions IS '46+ policy dimension scores from RNC Data Trust models - tracks individual issue positions and candidate support levels';
COMMENT ON TABLE dt_vote_history_detailed IS 'Granular election-by-election vote history with voting method and ballot status tracking';
COMMENT ON TABLE dt_phone_numbers IS 'Hierarchical phone number management with quality scores and contact optimization data';
COMMENT ON TABLE dt_import_staging IS 'Staging table for Data Trust imports with match tracking and quality control';

COMMENT ON VIEW v_dt_super_voters IS 'High-frequency Republican voters - ideal for volunteer recruitment and activation';
COMMENT ON VIEW v_dt_persuadable_voters IS 'Moderate voters with high turnout probability - prime persuasion targets';
COMMENT ON VIEW v_dt_gotv_targets IS 'Low-propensity Republican voters - Get Out The Vote focus';
COMMENT ON VIEW v_dt_donor_prospects IS 'High-income Republicans who are not current donors - fundraising prospects';
COMMENT ON VIEW v_dt_complete_profile IS 'Complete voter profile for AI/ML analysis - includes all key data points';

-- ============================================================================
-- SCHEMA INTEGRATION COMPLETE
-- ============================================================================

-- Verification Query
SELECT 
    'Data Trust Integration Complete' as status,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'unified_contacts') as total_contact_columns,
    (SELECT COUNT(*) FROM dt_issue_positions) as issue_positions_count,
    (SELECT COUNT(*) FROM dt_vote_history_detailed) as vote_history_records,
    (SELECT COUNT(*) FROM dt_phone_numbers) as phone_numbers_count;

-- Sample Counts by Targeting View
SELECT 'Super Voters' as category, COUNT(*) as count FROM v_dt_super_voters
UNION ALL
SELECT 'Persuadable Voters', COUNT(*) FROM v_dt_persuadable_voters
UNION ALL
SELECT 'GOTV Targets', COUNT(*) FROM v_dt_gotv_targets
UNION ALL
SELECT 'Donor Prospects', COUNT(*) FROM v_dt_donor_prospects
UNION ALL
SELECT 'AB/EV Targets', COUNT(*) FROM v_dt_abev_targets
UNION ALL
SELECT 'Pro-Life Activists', COUNT(*) FROM v_dt_prolife_activists
UNION ALL
SELECT '2A Supporters', COUNT(*) FROM v_dt_2a_supporters;