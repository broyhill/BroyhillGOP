-- ============================================================================
-- DATA TRUST COMPLETE INTEGRATION SCHEMA
-- Comprehensive 2,500+ Datapoint Schema for NC GOP DataHub
-- ============================================================================
-- Created: December 2, 2024
-- Purpose: Full Data Trust voter database integration with unified_contacts
-- Coverage: 300+ million individuals, 2,500+ unique data points per person
-- NC Specific: 7.8 million registered voters
-- ============================================================================

-- ============================================================================
-- PART 1: DATA TRUST MASTER TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS datatrust_profiles (
    -- ========================================================================
    -- PRIMARY KEYS & IDENTIFIERS
    -- ========================================================================
    id BIGSERIAL PRIMARY KEY,
    rnc_id VARCHAR(32) UNIQUE NOT NULL,  -- RNC's 32-character unique identifier
    contact_id BIGINT,  -- Links to unified_contacts
    
    -- ========================================================================
    -- CORE VOTER REGISTRATION DATA (Category: VOTER_REG)
    -- ========================================================================
    
    -- DT_VR_001: Name Components
    name_prefix VARCHAR(10),                    -- Mr., Mrs., Dr., Hon., etc.
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    name_suffix VARCHAR(20),                    -- Jr., Sr., III, Esq., etc.
    full_name_computed VARCHAR(255),
    
    -- DT_VR_002: Date of Birth
    date_of_birth DATE,
    age INTEGER,                                -- Computed from DOB
    age_bracket VARCHAR(20),                    -- 18-24, 25-34, 35-44, etc.
    generation VARCHAR(20),                     -- Gen Z, Millennial, Gen X, Boomer, Silent
    
    -- DT_VR_003: Home Address
    home_street_number VARCHAR(20),
    home_street_predirection VARCHAR(10),       -- N, S, E, W, NE, etc.
    home_street_name VARCHAR(100),
    home_street_type VARCHAR(20),               -- St, Ave, Rd, Blvd, etc.
    home_street_postdirection VARCHAR(10),
    home_unit_type VARCHAR(20),                 -- Apt, Unit, Suite, etc.
    home_unit_number VARCHAR(20),
    home_city VARCHAR(100),
    home_county VARCHAR(100),
    home_state VARCHAR(2) DEFAULT 'NC',
    home_zip VARCHAR(10),
    home_zip4 VARCHAR(4),
    home_full_address TEXT,                     -- Computed full address
    
    -- DT_VR_004: Geographic Coordinates
    home_latitude NUMERIC(10, 8),
    home_longitude NUMERIC(11, 8),
    home_geocode_precision VARCHAR(20),         -- rooftop, street, zip, city
    
    -- DT_VR_005: Mailing Address (if different)
    mail_street_number VARCHAR(20),
    mail_street_predirection VARCHAR(10),
    mail_street_name VARCHAR(100),
    mail_street_type VARCHAR(20),
    mail_street_postdirection VARCHAR(10),
    mail_unit_type VARCHAR(20),
    mail_unit_number VARCHAR(20),
    mail_city VARCHAR(100),
    mail_county VARCHAR(100),
    mail_state VARCHAR(2),
    mail_zip VARCHAR(10),
    mail_zip4 VARCHAR(4),
    mail_full_address TEXT,
    mail_address_different BOOLEAN DEFAULT FALSE,
    
    -- DT_VR_006: Voter Registration Status
    voter_registration_status VARCHAR(20),      -- active, inactive, purged, pending
    voter_registration_date DATE,
    voter_registration_method VARCHAR(50),      -- DMV, mail, online, in-person
    registered_party_affiliation VARCHAR(50),   -- Republican, Democrat, Unaffiliated, Libertarian
    party_registration_date DATE,
    previous_party_affiliation VARCHAR(50),
    party_switch_date DATE,
    years_registered INTEGER,                   -- Computed
    
    -- ========================================================================
    -- VOTE HISTORY (Category: VOTE_HIST)
    -- ========================================================================
    
    -- DT_VH_001: Presidential Election Vote History
    voted_pres_2024 VARCHAR(20),                -- Y, N, AB (absentee), EV (early vote)
    voted_pres_2020 VARCHAR(20),
    voted_pres_2016 VARCHAR(20),
    voted_pres_2012 VARCHAR(20),
    voted_pres_2008 VARCHAR(20),
    voted_pres_2004 VARCHAR(20),
    voted_pres_2000 VARCHAR(20),
    
    -- DT_VH_002: Primary Election Vote History
    voted_primary_2024 VARCHAR(20),
    voted_primary_2023 VARCHAR(20),
    voted_primary_2022 VARCHAR(20),
    voted_primary_2020 VARCHAR(20),
    voted_primary_2016 VARCHAR(20),
    voted_primary_2012 VARCHAR(20),
    
    -- DT_VH_003: General Election Vote History
    voted_general_2024 VARCHAR(20),
    voted_general_2023 VARCHAR(20),
    voted_general_2022 VARCHAR(20),
    voted_general_2021 VARCHAR(20),
    voted_general_2020 VARCHAR(20),
    voted_general_2019 VARCHAR(20),
    voted_general_2018 VARCHAR(20),
    voted_general_2017 VARCHAR(20),
    voted_general_2016 VARCHAR(20),
    
    -- DT_VH_004: Local/Municipal Election History
    voted_municipal_2024 VARCHAR(20),
    voted_municipal_2023 VARCHAR(20),
    voted_municipal_2022 VARCHAR(20),
    voted_municipal_2021 VARCHAR(20),
    voted_municipal_2020 VARCHAR(20),
    
    -- DT_VH_005: Vote History Statistics
    total_elections_eligible INTEGER,
    total_elections_voted INTEGER,
    voter_regularity_score NUMERIC(5, 4),       -- 0.0000 to 1.0000
    consecutive_elections_voted INTEGER,
    last_election_voted VARCHAR(50),
    last_vote_date DATE,
    vote_method_preference VARCHAR(20),         -- mail, early, election_day
    
    -- ========================================================================
    -- CONTACT INFORMATION (Category: CONTACT)
    -- ========================================================================
    
    -- DT_CT_001: Phone Numbers - Primary
    phone_primary VARCHAR(20),
    phone_primary_type VARCHAR(20),             -- mobile, landline, voip
    phone_primary_source VARCHAR(50),
    phone_primary_verified BOOLEAN,
    phone_primary_verification_date DATE,
    phone_primary_dnc_status BOOLEAN DEFAULT FALSE,
    
    -- DT_CT_002: Phone Numbers - Voter File
    phone_voterfile VARCHAR(20),
    phone_voterfile_type VARCHAR(20),
    phone_voterfile_verified BOOLEAN,
    
    -- DT_CT_003: Phone Numbers - Absentee/Early Vote
    phone_absentee VARCHAR(20),
    phone_absentee_type VARCHAR(20),
    phone_absentee_verified BOOLEAN,
    
    -- DT_CT_004: Phone Numbers - Data Axle
    phone_dataaxle VARCHAR(20),
    phone_dataaxle_type VARCHAR(20),
    phone_dataaxle_match_level VARCHAR(20),
    phone_dataaxle_verified BOOLEAN,
    
    -- DT_CT_005: Phone Numbers - Neustar
    phone_neustar VARCHAR(20),
    phone_neustar_type VARCHAR(20),
    phone_neustar_match_level VARCHAR(20),      -- exact, household, block
    phone_neustar_reliability VARCHAR(20),      -- high, medium, low
    phone_neustar_reliability_score INTEGER,    -- 0-100
    phone_neustar_call_window_gmt VARCHAR(50),  -- Best time to call in GMT
    phone_neustar_call_window_local VARCHAR(50), -- Best time in local timezone
    phone_neustar_verified BOOLEAN,
    
    -- DT_CT_006: Additional Phone Numbers
    phone_secondary VARCHAR(20),
    phone_secondary_type VARCHAR(20),
    phone_tertiary VARCHAR(20),
    phone_tertiary_type VARCHAR(20),
    
    -- DT_CT_007: Phone Statistics
    total_phones_available INTEGER,
    best_phone_to_call VARCHAR(20),             -- Computed from reliability
    phone_success_rate NUMERIC(5, 4),           -- Historical contact success
    
    -- DT_CT_008: Email Addresses
    email_primary VARCHAR(255),
    email_primary_source VARCHAR(50),
    email_primary_verified BOOLEAN,
    email_primary_verification_date DATE,
    email_secondary VARCHAR(255),
    email_tertiary VARCHAR(255),
    total_emails_available INTEGER,
    
    -- DT_CT_009: Do Not Contact Flags
    do_not_call BOOLEAN DEFAULT FALSE,
    do_not_email BOOLEAN DEFAULT FALSE,
    do_not_mail BOOLEAN DEFAULT FALSE,
    do_not_text BOOLEAN DEFAULT FALSE,
    dnc_registry_date DATE,
    
    -- ========================================================================
    -- DEMOGRAPHICS (Category: DEMO)
    -- ========================================================================
    
    -- DT_DM_001: Gender
    gender VARCHAR(10),                         -- M, F, U (unknown)
    gender_source VARCHAR(50),
    
    -- DT_DM_002: Race and Ethnicity
    race_ethnicity_self_reported VARCHAR(50),
    race_white BOOLEAN,
    race_black BOOLEAN,
    race_asian BOOLEAN,
    race_hispanic BOOLEAN,
    race_native_american BOOLEAN,
    race_pacific_islander BOOLEAN,
    race_other BOOLEAN,
    race_two_or_more BOOLEAN,
    ethnicity_modeled VARCHAR(50),              -- When self-reported unavailable
    ethnicity_modeled_confidence NUMERIC(5, 4),
    
    -- DT_DM_003: Religion
    religion_modeled VARCHAR(50),               -- Catholic, Protestant, Jewish, etc.
    religion_modeled_confidence NUMERIC(5, 4),
    religion_evangelical BOOLEAN,
    religion_practicing BOOLEAN,
    church_attendance_frequency VARCHAR(20),    -- weekly, monthly, holidays, never
    
    -- DT_DM_004: Education
    education_level VARCHAR(50),                -- high_school, some_college, bachelors, graduate
    highest_degree VARCHAR(50),
    degree_field VARCHAR(100),
    graduation_year INTEGER,
    education_modeled BOOLEAN,
    
    -- DT_DM_005: Income
    income_household INTEGER,
    income_household_bracket VARCHAR(20),       -- <25K, 25-50K, 50-75K, etc.
    income_individual INTEGER,
    income_individual_bracket VARCHAR(20),
    income_source VARCHAR(50),                  -- salary, business, investments, retirement
    income_modeled BOOLEAN,
    income_confidence NUMERIC(5, 4),
    
    -- DT_DM_006: Employment
    employment_status VARCHAR(50),              -- employed, self-employed, retired, unemployed
    occupation VARCHAR(100),
    occupation_category VARCHAR(50),            -- professional, management, service, etc.
    industry VARCHAR(100),
    employer_name VARCHAR(200),
    years_at_job INTEGER,
    
    -- ========================================================================
    -- SOCIOECONOMIC & FINANCIAL (Category: SOCIO_FIN)
    -- ========================================================================
    
    -- DT_SF_001: Credit
    credit_score_range VARCHAR(20),             -- 300-579, 580-669, 670-739, 740-799, 800+
    credit_score_estimated INTEGER,             -- Estimated mid-range
    credit_history_length_years INTEGER,
    credit_rating VARCHAR(20),                  -- poor, fair, good, very_good, excellent
    
    -- DT_SF_002: Debt
    total_debt_estimated INTEGER,
    debt_to_income_ratio NUMERIC(5, 4),
    credit_card_debt_estimated INTEGER,
    student_loan_debt BOOLEAN,
    student_loan_amount_estimated INTEGER,
    medical_debt BOOLEAN,
    bankruptcy_history BOOLEAN,
    bankruptcy_date DATE,
    
    -- DT_SF_003: Home Ownership
    homeownership_status VARCHAR(20),           -- owner, renter, other
    home_value_estimated INTEGER,
    home_value_range VARCHAR(20),               -- <100K, 100-200K, 200-300K, etc.
    home_purchase_date DATE,
    years_at_residence INTEGER,
    property_type VARCHAR(50),                  -- single_family, condo, townhouse, etc.
    
    -- DT_SF_004: Mortgage
    mortgage_status VARCHAR(20),                -- yes, no, paid_off
    mortgage_amount_estimated INTEGER,
    mortgage_loan_to_value_ratio NUMERIC(5, 4),
    mortgage_rate_estimated NUMERIC(5, 4),
    mortgage_monthly_payment_estimated INTEGER,
    refinance_likelihood NUMERIC(5, 4),
    
    -- DT_SF_005: Vehicle Ownership
    vehicles_owned INTEGER,
    vehicle_1_year INTEGER,
    vehicle_1_make VARCHAR(50),
    vehicle_1_model VARCHAR(50),
    vehicle_1_value_estimated INTEGER,
    vehicle_2_year INTEGER,
    vehicle_2_make VARCHAR(50),
    vehicle_2_model VARCHAR(50),
    vehicle_2_value_estimated INTEGER,
    total_vehicle_value INTEGER,
    auto_loan_status BOOLEAN,
    auto_loan_amount_estimated INTEGER,
    
    -- DT_SF_006: Net Worth
    net_worth_estimated INTEGER,
    net_worth_bracket VARCHAR(20),              -- <0, 0-50K, 50-100K, 100-250K, etc.
    investment_accounts BOOLEAN,
    retirement_accounts BOOLEAN,
    
    -- ========================================================================
    -- HOUSEHOLD & FAMILY (Category: HOUSEHOLD)
    -- ========================================================================
    
    -- DT_HH_001: Household Composition
    household_size INTEGER,
    adults_in_household INTEGER,
    children_in_household INTEGER,
    children_age_0_5 INTEGER,
    children_age_6_12 INTEGER,
    children_age_13_17 INTEGER,
    seniors_in_household INTEGER,               -- 65+
    
    -- DT_HH_002: Marital Status
    marital_status VARCHAR(20),                 -- single, married, divorced, widowed
    marital_status_source VARCHAR(50),
    spouse_name VARCHAR(255),
    spouse_age INTEGER,
    anniversary_date DATE,
    
    -- DT_HH_003: Family Type
    family_composition VARCHAR(50),             -- nuclear, single_parent, multigenerational, etc.
    household_type VARCHAR(50),                 -- family, non_family, group_quarters
    
    -- ========================================================================
    -- LIFESTYLE & CONSUMER BEHAVIOR (Category: LIFESTYLE)
    -- ========================================================================
    
    -- DT_LS_001: Outdoor Activities
    hunting_license BOOLEAN,
    hunting_license_expiration DATE,
    fishing_license BOOLEAN,
    fishing_license_expiration DATE,
    concealed_carry_permit BOOLEAN,
    nra_member BOOLEAN,
    nra_membership_level VARCHAR(50),
    
    -- DT_LS_002: Media Consumption
    magazine_subscriptions TEXT[],              -- Array of magazine names
    magazine_subscriptions_count INTEGER,
    newspaper_subscription BOOLEAN,
    newspaper_name VARCHAR(100),
    tv_viewing_hours_daily INTEGER,
    tv_cable_subscriber BOOLEAN,
    tv_streaming_services TEXT[],
    
    -- DT_LS_003: Shopping Behavior
    online_shopping_frequency VARCHAR(20),      -- daily, weekly, monthly, rarely
    amazon_prime_member BOOLEAN,
    warehouse_club_member BOOLEAN,             -- Costco, Sam's Club
    warehouse_club_name VARCHAR(50),
    brand_loyalty_score NUMERIC(5, 4),
    luxury_purchaser BOOLEAN,
    
    -- DT_LS_004: Charitable Giving
    charitable_donor BOOLEAN,
    charitable_giving_amount_annual INTEGER,
    charitable_giving_frequency VARCHAR(20),
    charity_types_supported TEXT[],             -- religious, political, environmental, etc.
    political_donor BOOLEAN,
    political_giving_amount_total INTEGER,
    political_giving_federal BOOLEAN,
    political_giving_state BOOLEAN,
    political_giving_local BOOLEAN,
    
    -- DT_LS_005: Health & Fitness
    gym_membership BOOLEAN,
    gym_name VARCHAR(100),
    health_conscious BOOLEAN,
    health_supplement_purchaser BOOLEAN,
    organic_food_purchaser BOOLEAN,
    fitness_tracker_user BOOLEAN,
    
    -- DT_LS_006: Technology
    smartphone_user BOOLEAN,
    smartphone_type VARCHAR(20),                -- iPhone, Android, other
    tablet_owner BOOLEAN,
    computer_owner BOOLEAN,
    smart_home_devices BOOLEAN,
    tech_early_adopter BOOLEAN,
    
    -- DT_LS_007: Social Media
    social_media_user BOOLEAN,
    facebook_user BOOLEAN,
    twitter_user BOOLEAN,
    instagram_user BOOLEAN,
    tiktok_user BOOLEAN,
    linkedin_user BOOLEAN,
    social_media_frequency VARCHAR(20),         -- daily, weekly, monthly
    social_media_influence_score NUMERIC(5, 4),
    
    -- DT_LS_008: Transportation
    rideshare_user BOOLEAN,
    rideshare_frequency VARCHAR(20),
    public_transit_user BOOLEAN,
    bike_commuter BOOLEAN,
    
    -- DT_LS_009: Pets
    pet_owner BOOLEAN,
    dog_owner BOOLEAN,
    dogs_count INTEGER,
    cat_owner BOOLEAN,
    cats_count INTEGER,
    other_pets TEXT[],
    pet_spending_annual INTEGER,
    
    -- DT_LS_010: Travel
    travel_frequency VARCHAR(20),               -- frequent, occasional, rare, never
    international_traveler BOOLEAN,
    cruise_traveler BOOLEAN,
    air_travel_frequency VARCHAR(20),
    hotel_chain_loyalty TEXT[],
    airline_loyalty TEXT[],
    vacation_home_owner BOOLEAN,
    vacation_home_location VARCHAR(100),
    
    -- DT_LS_011: Entertainment
    concert_attendee BOOLEAN,
    sports_event_attendee BOOLEAN,
    theater_attendee BOOLEAN,
    museum_visitor BOOLEAN,
    
    -- ========================================================================
    -- GEOGRAPHIC & POLITICAL GEOGRAPHY (Category: GEO_POLITICAL)
    -- ========================================================================
    
    -- DT_GP_001: Congressional Districts
    congressional_district_current VARCHAR(10), -- 2021 redistricting
    congressional_district_previous VARCHAR(10), -- 2011 lines
    congressional_representative VARCHAR(100),
    congressional_district_partisan_lean VARCHAR(10), -- R+15, D+5, EVEN, etc.
    
    -- DT_GP_002: State Legislative Districts
    state_senate_district VARCHAR(10),
    state_senator VARCHAR(100),
    state_senate_partisan_lean VARCHAR(10),
    state_house_district VARCHAR(10),
    state_representative VARCHAR(100),
    state_house_partisan_lean VARCHAR(10),
    
    -- DT_GP_003: Local Government
    county_name VARCHAR(100),
    county_fips_code VARCHAR(5),
    city_name VARCHAR(100),
    township_name VARCHAR(100),
    village_name VARCHAR(100),
    municipality_type VARCHAR(50),
    
    -- DT_GP_004: Precincts
    precinct_code VARCHAR(20),
    precinct_name VARCHAR(100),
    polling_location VARCHAR(255),
    polling_location_address TEXT,
    
    -- DT_GP_005: School Districts
    school_board_district VARCHAR(20),
    school_district_name VARCHAR(100),
    school_district_type VARCHAR(50),           -- elementary, unified, high_school
    
    -- DT_GP_006: Special Districts
    fire_district VARCHAR(50),
    water_district VARCHAR(50),
    sewer_district VARCHAR(50),
    special_districts TEXT[],                   -- Other special purpose districts
    
    -- ========================================================================
    -- CENSUS GEOGRAPHY (Category: CENSUS)
    -- ========================================================================
    
    -- DT_CS_001: Census Geographic Units
    census_block VARCHAR(20),
    census_block_group VARCHAR(20),
    census_tract VARCHAR(20),
    census_zcta VARCHAR(10),                    -- Zip Code Tabulation Area
    
    -- DT_CS_002: Metro Classification
    metro_type VARCHAR(20),                     -- city, suburban, town, rural
    cbsa_code VARCHAR(10),                      -- Core Based Statistical Area
    cbsa_name VARCHAR(100),
    msa_code VARCHAR(10),                       -- Metropolitan Statistical Area
    msa_name VARCHAR(100),
    urbanization_level VARCHAR(20),             -- urban, suburban, exurban, rural
    population_density_category VARCHAR(20),    -- very_high, high, medium, low, very_low
    
    -- ========================================================================
    -- MODELED POLITICAL DATA (Category: POLITICAL_MODEL)
    -- ========================================================================
    
    -- DT_PM_001: Partisanship Modeling
    modeled_partisanship_score NUMERIC(5, 4),   -- 0.0000=Strong Dem, 1.0000=Strong Rep
    modeled_partisanship_category VARCHAR(20),  -- strong_dem, lean_dem, swing, lean_rep, strong_rep
    modeled_partisanship_confidence NUMERIC(5, 4),
    coalition_id VARCHAR(50),                   -- RNC's coalition classification
    likely_party_affiliation VARCHAR(20),
    partisan_lean_score INTEGER,                -- -100 (Strong Dem) to +100 (Strong Rep)
    
    -- DT_PM_002: Political Engagement
    political_activism_score NUMERIC(5, 4),
    political_knowledge_score NUMERIC(5, 4),
    political_discussion_frequency VARCHAR(20),
    grassroots_volunteer_likelihood NUMERIC(5, 4),
    
    -- ========================================================================
    -- TURNOUT PREDICTION MODELS (Category: TURNOUT_MODEL)
    -- ========================================================================
    
    -- DT_TM_001: Primary Election Turnout
    turnout_primary_2026_prob NUMERIC(5, 4),    -- 0.0000 to 1.0000
    turnout_primary_2024_prob NUMERIC(5, 4),
    turnout_primary_score INTEGER,              -- 0-100
    primary_voter_type VARCHAR(20),             -- super, frequent, occasional, rare, never
    
    -- DT_TM_002: General Election Turnout
    turnout_general_2026_prob NUMERIC(5, 4),
    turnout_general_2024_prob NUMERIC(5, 4),
    turnout_general_score INTEGER,
    general_voter_type VARCHAR(20),
    
    -- DT_TM_003: Midterm Election Turnout
    turnout_midterm_2026_prob NUMERIC(5, 4),
    turnout_midterm_2022_prob NUMERIC(5, 4),
    turnout_midterm_score INTEGER,
    midterm_voter_type VARCHAR(20),
    
    -- DT_TM_004: Overall Turnout Likelihood
    turnout_likelihood_score NUMERIC(5, 4),     -- Master turnout score
    turnout_reliability VARCHAR(20),            -- very_high, high, medium, low, very_low
    turnout_prediction_confidence NUMERIC(5, 4),
    
    -- ========================================================================
    -- ISSUE POSITIONS & POLICY PREFERENCES (Category: ISSUE_MODEL)
    -- 46+ Policy Dimension Models (Each scored 0.0000 to 1.0000)
    -- ========================================================================
    
    -- DT_IM_001: Trump & MAGA Movement
    issue_trump_america_first_support NUMERIC(5, 4),
    issue_trump_approval NUMERIC(5, 4),
    issue_maga_identification NUMERIC(5, 4),
    issue_populist_lean NUMERIC(5, 4),
    
    -- DT_IM_002: Previous Presidential Support
    issue_obama_2012_support_likelihood NUMERIC(5, 4),
    issue_romney_2012_support_likelihood NUMERIC(5, 4),
    issue_biden_2020_support_likelihood NUMERIC(5, 4),
    issue_trump_2020_support_likelihood NUMERIC(5, 4),
    
    -- DT_IM_003: Economic Issues
    issue_auto_manufacturing_concern NUMERIC(5, 4),
    issue_jobs_priority NUMERIC(5, 4),
    issue_trade_protectionism NUMERIC(5, 4),
    issue_tax_cuts_support NUMERIC(5, 4),
    issue_minimum_wage_increase NUMERIC(5, 4),
    issue_economic_regulation NUMERIC(5, 4),
    issue_small_business_support NUMERIC(5, 4),
    
    -- DT_IM_004: Social Issues
    issue_abortion_pro_life NUMERIC(5, 4),
    issue_gun_rights_support NUMERIC(5, 4),
    issue_traditional_marriage NUMERIC(5, 4),
    issue_religious_freedom NUMERIC(5, 4),
    issue_school_choice NUMERIC(5, 4),
    issue_parental_rights NUMERIC(5, 4),
    
    -- DT_IM_005: Immigration
    issue_border_security NUMERIC(5, 4),
    issue_immigration_enforcement NUMERIC(5, 4),
    issue_build_wall_support NUMERIC(5, 4),
    issue_sanctuary_cities_oppose NUMERIC(5, 4),
    issue_immigration_reform NUMERIC(5, 4),
    
    -- DT_IM_006: Healthcare
    issue_obamacare_repeal NUMERIC(5, 4),
    issue_healthcare_reform NUMERIC(5, 4),
    issue_medicare_support NUMERIC(5, 4),
    issue_drug_price_reform NUMERIC(5, 4),
    
    -- DT_IM_007: Foreign Policy
    issue_america_first_foreign_policy NUMERIC(5, 4),
    issue_strong_military NUMERIC(5, 4),
    issue_china_tough_stance NUMERIC(5, 4),
    issue_nato_skepticism NUMERIC(5, 4),
    issue_israel_support NUMERIC(5, 4),
    
    -- DT_IM_008: Law & Order
    issue_law_and_order NUMERIC(5, 4),
    issue_police_support NUMERIC(5, 4),
    issue_tough_on_crime NUMERIC(5, 4),
    issue_criminal_justice_reform NUMERIC(5, 4),
    
    -- DT_IM_009: Environment & Energy
    issue_climate_change_concern NUMERIC(5, 4),
    issue_fossil_fuels_support NUMERIC(5, 4),
    issue_energy_independence NUMERIC(5, 4),
    issue_environmental_regulation NUMERIC(5, 4),
    
    -- DT_IM_010: Education
    issue_critical_race_theory_oppose NUMERIC(5, 4),
    issue_school_curriculum_concern NUMERIC(5, 4),
    issue_college_affordability NUMERIC(5, 4),
    issue_student_debt_forgiveness NUMERIC(5, 4),
    
    -- DT_IM_011: Technology & Media
    issue_big_tech_regulation NUMERIC(5, 4),
    issue_social_media_censorship_concern NUMERIC(5, 4),
    issue_media_distrust NUMERIC(5, 4),
    
    -- DT_IM_012: Movement Identification
    issue_tea_party_support NUMERIC(5, 4),
    issue_liberty_movement NUMERIC(5, 4),
    issue_constitutionalist NUMERIC(5, 4),
    issue_evangelical_alignment NUMERIC(5, 4),
    
    -- ========================================================================
    -- ABSENTEE & EARLY VOTE (AB/EV) DATA (Category: ABEV)
    -- ========================================================================
    
    -- DT_AE_001: Current Election AB/EV Status (2024)
    abev_2024_ballot_requested BOOLEAN,
    abev_2024_request_date DATE,
    abev_2024_request_method VARCHAR(50),       -- online, mail, in_person
    abev_2024_ballot_sent BOOLEAN,
    abev_2024_ballot_sent_date DATE,
    abev_2024_ballot_returned BOOLEAN,
    abev_2024_ballot_return_date DATE,
    abev_2024_ballot_accepted BOOLEAN,
    abev_2024_ballot_rejected BOOLEAN,
    abev_2024_rejection_reason VARCHAR(100),
    abev_2024_early_inperson_voted BOOLEAN,
    abev_2024_early_vote_date DATE,
    abev_2024_early_vote_location VARCHAR(255),
    abev_2024_voting_method VARCHAR(20),        -- mail, early_inperson, election_day, not_voted
    
    -- DT_AE_002: Historical AB/EV Patterns
    abev_2020_voting_method VARCHAR(20),
    abev_2020_ballot_return_days INTEGER,
    abev_2016_voting_method VARCHAR(20),
    abev_2012_voting_method VARCHAR(20),
    abev_total_absentee_votes INTEGER,
    abev_total_early_votes INTEGER,
    abev_total_election_day_votes INTEGER,
    abev_preference VARCHAR(20),                -- mail, early, election_day, no_preference
    abev_consistency_score NUMERIC(5, 4),       -- How consistent is voting method
    
    -- DT_AE_003: AB/EV by Party Statistics
    abev_request_democrat_pct NUMERIC(5, 4),
    abev_request_republican_pct NUMERIC(5, 4),
    abev_request_unaffiliated_pct NUMERIC(5, 4),
    abev_return_rate NUMERIC(5, 4),
    abev_acceptance_rate NUMERIC(5, 4),
    
    -- DT_AE_004: AB/EV Likelihood Predictions
    abev_2026_request_likelihood NUMERIC(5, 4),
    abev_2026_return_likelihood NUMERIC(5, 4),
    abev_mail_voter_likelihood NUMERIC(5, 4),
    
    -- ========================================================================
    -- DATA SOURCE TRACKING (Category: DATA_SOURCE)
    -- ========================================================================
    
    -- DT_DS_001: Primary Data Sources
    data_source_voter_file BOOLEAN,
    data_source_voter_file_state VARCHAR(2),
    data_source_voter_file_date DATE,
    data_source_commercial BOOLEAN,
    data_source_commercial_provider VARCHAR(100),
    data_source_neustar BOOLEAN,
    data_source_dataaxle BOOLEAN,
    data_source_ncoa BOOLEAN,                   -- National Change of Address
    data_source_custom TEXT[],
    
    -- DT_DS_002: Phone Number Sources
    phone_source_primary VARCHAR(100),
    phone_source_secondary VARCHAR(100),
    phone_source_tertiary VARCHAR(100),
    
    -- DT_DS_003: Email Sources
    email_source_primary VARCHAR(100),
    email_source_secondary VARCHAR(100),
    
    -- DT_DS_004: Address Sources
    address_source VARCHAR(100),
    address_last_verified_date DATE,
    address_verification_method VARCHAR(50),
    
    -- ========================================================================
    -- DATA MAINTENANCE & QUALITY FLAGS (Category: DATA_QUALITY)
    -- ========================================================================
    
    -- DT_DQ_001: Phone Verification
    phone_verified BOOLEAN,
    phone_verification_date DATE,
    phone_verification_method VARCHAR(50),      -- live_call, sms, automated
    phone_verification_result VARCHAR(50),
    phone_last_contacted DATE,
    phone_contact_success_rate NUMERIC(5, 4),
    phone_wrong_number BOOLEAN,
    
    -- DT_DQ_002: Email Verification
    email_verified BOOLEAN,
    email_verification_date DATE,
    email_verification_method VARCHAR(50),
    email_bounce_status VARCHAR(20),            -- none, soft, hard
    email_last_sent DATE,
    email_open_rate NUMERIC(5, 4),
    email_click_rate NUMERIC(5, 4),
    
    -- DT_DQ_003: Address Verification
    address_verified BOOLEAN,
    address_verification_date DATE,
    address_deliverable BOOLEAN,
    address_vacancy_flag BOOLEAN,
    address_seasonal_flag BOOLEAN,
    
    -- DT_DQ_004: Data Accuracy Indicators
    data_accuracy_score INTEGER,               -- 0-100, overall data quality
    data_completeness_score INTEGER,           -- 0-100, how many fields filled
    data_freshness_score INTEGER,              -- 0-100, how recently updated
    data_confidence_level VARCHAR(20),         -- very_high, high, medium, low
    
    -- DT_DQ_005: Update Tracking
    record_created_date DATE DEFAULT CURRENT_DATE,
    record_last_updated DATE DEFAULT CURRENT_DATE,
    record_last_verified DATE,
    record_update_source VARCHAR(100),
    record_update_frequency INTEGER,           -- Days between updates
    
    -- DT_DQ_006: NCOA (National Change of Address)
    ncoa_processed BOOLEAN,
    ncoa_process_date DATE,
    ncoa_match_found BOOLEAN,
    ncoa_new_address_date DATE,
    ncoa_move_type VARCHAR(20),                -- individual, family, business
    
    -- DT_DQ_007: Deceased Indicators
    deceased_flag BOOLEAN DEFAULT FALSE,
    deceased_date DATE,
    deceased_source VARCHAR(100),              -- SSDI, obituary, voter_file, family
    ssdi_match BOOLEAN,                        -- Social Security Death Index
    
    -- DT_DQ_008: Duplicate & Invalid Flags
    duplicate_registration_flag BOOLEAN,
    duplicate_registration_count INTEGER,
    invalid_registration_flag BOOLEAN,
    invalid_registration_reason VARCHAR(255),
    
    -- DT_DQ_009: Move Indicators
    moved_out_of_state BOOLEAN,
    moved_out_of_state_date DATE,
    moved_out_of_state_to VARCHAR(2),
    moved_within_state BOOLEAN,
    moved_within_state_date DATE,
    moved_previous_address TEXT,
    mobility_score NUMERIC(5, 4),              -- Likelihood of moving
    
    -- DT_DQ_010: Contact Attempt Tracking
    total_contact_attempts INTEGER DEFAULT 0,
    successful_contacts INTEGER DEFAULT 0,
    last_contact_attempt DATE,
    last_successful_contact DATE,
    contact_success_rate NUMERIC(5, 4),
    best_contact_time VARCHAR(50),             -- day_of_week + hour
    
    -- ========================================================================
    -- COVERAGE & ENRICHMENT STATISTICS (Category: COVERAGE)
    -- ========================================================================
    
    -- DT_CV_001: Data Availability Flags
    has_mobile_phone BOOLEAN DEFAULT FALSE,
    has_landline_phone BOOLEAN DEFAULT FALSE,
    has_email BOOLEAN DEFAULT FALSE,
    has_verified_address BOOLEAN DEFAULT FALSE,
    has_vote_history BOOLEAN DEFAULT FALSE,
    has_demographic_data BOOLEAN DEFAULT FALSE,
    has_financial_data BOOLEAN DEFAULT FALSE,
    has_lifestyle_data BOOLEAN DEFAULT FALSE,
    has_issue_scores BOOLEAN DEFAULT FALSE,
    
    -- DT_CV_002: Enrichment Scores
    profile_completeness_pct NUMERIC(5, 2),    -- 0.00 to 100.00
    fields_populated INTEGER,
    fields_total INTEGER DEFAULT 2500,
    enrichment_level VARCHAR(20),              -- basic, standard, enhanced, premium
    
    -- DT_CV_003: Match Confidence
    rnc_match_confidence NUMERIC(5, 4),
    identity_verification_level VARCHAR(20),   -- unverified, basic, standard, enhanced
    
    -- ========================================================================
    -- CUSTOM NC GOP FIELDS (Category: NCGOP_CUSTOM)
    -- ========================================================================
    
    -- DT_NC_001: NC-Specific Data
    nc_county_party_member BOOLEAN,
    nc_county_party_name VARCHAR(100),
    nc_precinct_captain BOOLEAN,
    nc_precinct_captain_since DATE,
    nc_state_convention_delegate BOOLEAN,
    nc_delegate_years TEXT[],
    
    -- DT_NC_002: NC Campaign History
    nc_volunteer_history TEXT[],               -- Array of campaign years
    nc_donor_history_federal BOOLEAN,
    nc_donor_history_state BOOLEAN,
    nc_donor_history_local BOOLEAN,
    nc_total_contributions_nc INTEGER,
    nc_first_contribution_date DATE,
    nc_last_contribution_date DATE,
    
    -- DT_NC_003: NC Council of State Interests
    nc_council_state_engagement BOOLEAN,
    nc_agriculture_interest BOOLEAN,
    nc_education_interest BOOLEAN,
    nc_insurance_interest BOOLEAN,
    nc_labor_interest BOOLEAN,
    nc_treasurer_interest BOOLEAN,
    
    -- ========================================================================
    -- SYSTEM FIELDS
    -- ========================================================================
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_to_unified_contacts BOOLEAN DEFAULT FALSE,
    sync_date TIMESTAMPTZ,
    
    -- ========================================================================
    -- FOREIGN KEY
    -- ========================================================================
    FOREIGN KEY (contact_id) REFERENCES unified_contacts(contact_id) ON DELETE SET NULL
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Primary identifiers
CREATE INDEX idx_dt_rnc_id ON datatrust_profiles(rnc_id);
CREATE INDEX idx_dt_contact_id ON datatrust_profiles(contact_id);

-- Name search
CREATE INDEX idx_dt_last_name ON datatrust_profiles(last_name);
CREATE INDEX idx_dt_full_name ON datatrust_profiles(full_name_computed);

-- Geographic lookups
CREATE INDEX idx_dt_county ON datatrust_profiles(home_county);
CREATE INDEX idx_dt_city ON datatrust_profiles(home_city);
CREATE INDEX idx_dt_zip ON datatrust_profiles(home_zip);
CREATE INDEX idx_dt_congressional_district ON datatrust_profiles(congressional_district_current);
CREATE INDEX idx_dt_state_senate ON datatrust_profiles(state_senate_district);
CREATE INDEX idx_dt_state_house ON datatrust_profiles(state_house_district);
CREATE INDEX idx_dt_precinct ON datatrust_profiles(precinct_code);

-- Political data
CREATE INDEX idx_dt_party ON datatrust_profiles(registered_party_affiliation);
CREATE INDEX idx_dt_voter_status ON datatrust_profiles(voter_registration_status);
CREATE INDEX idx_dt_partisanship_score ON datatrust_profiles(modeled_partisanship_score);
CREATE INDEX idx_dt_coalition_id ON datatrust_profiles(coalition_id);

-- Vote history
CREATE INDEX idx_dt_voted_2024 ON datatrust_profiles(voted_pres_2024);
CREATE INDEX idx_dt_voter_regularity ON datatrust_profiles(voter_regularity_score DESC);

-- Turnout scores
CREATE INDEX idx_dt_turnout_2026 ON datatrust_profiles(turnout_general_2026_prob DESC);
CREATE INDEX idx_dt_turnout_score ON datatrust_profiles(turnout_likelihood_score DESC);

-- Demographics
CREATE INDEX idx_dt_age ON datatrust_profiles(age);
CREATE INDEX idx_dt_gender ON datatrust_profiles(gender);
CREATE INDEX idx_dt_education ON datatrust_profiles(education_level);
CREATE INDEX idx_dt_income ON datatrust_profiles(income_household_bracket);

-- Contact info
CREATE INDEX idx_dt_phone_primary ON datatrust_profiles(phone_primary) WHERE phone_primary IS NOT NULL;
CREATE INDEX idx_dt_email_primary ON datatrust_profiles(email_primary) WHERE email_primary IS NOT NULL;
CREATE INDEX idx_dt_has_mobile ON datatrust_profiles(has_mobile_phone) WHERE has_mobile_phone = TRUE;

-- Data quality
CREATE INDEX idx_dt_deceased ON datatrust_profiles(deceased_flag) WHERE deceased_flag = TRUE;
CREATE INDEX idx_dt_moved ON datatrust_profiles(moved_out_of_state) WHERE moved_out_of_state = TRUE;
CREATE INDEX idx_dt_quality_score ON datatrust_profiles(data_accuracy_score DESC);

-- Issue scores (key issues for targeting)
CREATE INDEX idx_dt_trump_support ON datatrust_profiles(issue_trump_approval DESC);
CREATE INDEX idx_dt_gun_rights ON datatrust_profiles(issue_gun_rights_support DESC);
CREATE INDEX idx_dt_abortion ON datatrust_profiles(issue_abortion_pro_life DESC);

-- Composite indexes for common queries
CREATE INDEX idx_dt_party_turnout ON datatrust_profiles(registered_party_affiliation, turnout_likelihood_score DESC);
CREATE INDEX idx_dt_county_party ON datatrust_profiles(home_county, registered_party_affiliation);
CREATE INDEX idx_dt_district_turnout ON datatrust_profiles(congressional_district_current, turnout_general_2026_prob DESC);

-- Full-text search
CREATE INDEX idx_dt_fulltext_name ON datatrust_profiles 
    USING GIN(to_tsvector('english', 
        COALESCE(full_name_computed, '') || ' ' || 
        COALESCE(home_city, '') || ' ' || 
        COALESCE(home_county, '')
    ));

-- ============================================================================
-- TRIGGER: Auto-update timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_datatrust_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_datatrust_updated_at
    BEFORE UPDATE ON datatrust_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_datatrust_updated_at();

-- ============================================================================
-- PART 2: VIEWS FOR MATCHING & ANALYSIS
-- ============================================================================

-- View 1: High-Value Republican Targets
CREATE OR REPLACE VIEW v_dt_high_value_republicans AS
SELECT 
    dt.rnc_id,
    dt.full_name_computed,
    dt.home_county,
    dt.congressional_district_current,
    dt.registered_party_affiliation,
    dt.modeled_partisanship_score,
    dt.turnout_likelihood_score,
    dt.voter_regularity_score,
    dt.issue_trump_approval,
    dt.issue_gun_rights_support,
    dt.phone_primary,
    dt.email_primary,
    uc.donor_grade,
    uc.total_donations_aggregated,
    CASE 
        WHEN uc.donor_grade IN ('A++', 'A+', 'A') THEN 'major_donor'
        WHEN uc.donor_grade IN ('A-', 'B+') THEN 'mid_donor'
        WHEN dt.turnout_likelihood_score > 0.8 THEN 'super_voter'
        WHEN dt.issue_trump_approval > 0.7 THEN 'maga_base'
        ELSE 'standard_supporter'
    END as target_category
FROM datatrust_profiles dt
LEFT JOIN unified_contacts uc ON dt.contact_id = uc.contact_id
WHERE dt.modeled_partisanship_score > 0.6  -- Republican lean or stronger
    AND dt.voter_registration_status = 'active'
    AND dt.deceased_flag = FALSE
ORDER BY dt.turnout_likelihood_score DESC, uc.total_donations_aggregated DESC NULLS LAST;

-- View 2: Persuadable Swing Voters
CREATE OR REPLACE VIEW v_dt_swing_voters AS
SELECT 
    dt.rnc_id,
    dt.full_name_computed,
    dt.home_county,
    dt.congressional_district_current,
    dt.registered_party_affiliation,
    dt.modeled_partisanship_score,
    dt.turnout_likelihood_score,
    dt.phone_primary,
    dt.email_primary,
    -- Calculate persuasion score
    (dt.turnout_likelihood_score * 0.4 +  -- 40% weight on turnout
     ABS(0.5 - dt.modeled_partisanship_score) * -2 * 0.3 +  -- 30% weight on being in middle
     dt.voter_regularity_score * 0.3) as persuasion_priority_score
FROM datatrust_profiles dt
WHERE dt.modeled_partisanship_score BETWEEN 0.35 AND 0.65  -- True swing voters
    AND dt.turnout_likelihood_score > 0.5  -- Likely to vote
    AND dt.voter_registration_status = 'active'
    AND dt.deceased_flag = FALSE
ORDER BY persuasion_priority_score DESC;

-- View 3: Voter-Donor Match Analysis
CREATE OR REPLACE VIEW v_dt_donor_voter_match AS
SELECT 
    dt.rnc_id,
    uc.contact_id,
    uc.full_name as contact_name,
    dt.full_name_computed as dt_name,
    uc.donor_grade,
    uc.total_donations_aggregated,
    dt.registered_party_affiliation,
    dt.modeled_partisanship_score,
    dt.voter_regularity_score,
    dt.turnout_likelihood_score,
    dt.issue_trump_approval,
    -- Match quality score
    CASE 
        WHEN uc.mobile_phone = dt.phone_primary THEN 50
        WHEN uc.mobile_phone = dt.phone_secondary THEN 30
        ELSE 0
    END +
    CASE 
        WHEN uc.email = dt.email_primary THEN 30
        ELSE 0
    END +
    CASE 
        WHEN uc.last_name_clean = dt.last_name AND uc.zip_code = dt.home_zip THEN 20
        ELSE 0
    END as match_confidence_score
FROM unified_contacts uc
INNER JOIN datatrust_profiles dt ON uc.contact_id = dt.contact_id
WHERE uc.donor_grade IS NOT NULL
ORDER BY match_confidence_score DESC, uc.total_donations_aggregated DESC;

-- View 4: AB/EV Target Universe (2026)
CREATE OR REPLACE VIEW v_dt_abev_targets_2026 AS
SELECT 
    dt.rnc_id,
    dt.full_name_computed,
    dt.home_county,
    dt.phone_primary,
    dt.email_primary,
    dt.abev_preference,
    dt.abev_2026_request_likelihood,
    dt.turnout_general_2026_prob,
    dt.registered_party_affiliation,
    dt.modeled_partisanship_score,
    uc.donor_grade,
    -- Prioritize by likelihood of requesting AB ballot
    CASE 
        WHEN dt.abev_preference = 'mail' THEN dt.abev_2026_request_likelihood * 1.2
        WHEN dt.abev_preference = 'early' THEN dt.abev_2026_request_likelihood * 0.8
        ELSE dt.abev_2026_request_likelihood
    END as adjusted_abev_likelihood
FROM datatrust_profiles dt
LEFT JOIN unified_contacts uc ON dt.contact_id = uc.contact_id
WHERE dt.turnout_general_2026_prob > 0.5
    AND dt.modeled_partisanship_score > 0.5  -- Republican lean
    AND dt.voter_registration_status = 'active'
    AND dt.deceased_flag = FALSE
ORDER BY adjusted_abev_likelihood DESC;

-- View 5: Issue-Based Targeting
CREATE OR REPLACE VIEW v_dt_issue_targets AS
SELECT 
    dt.rnc_id,
    dt.full_name_computed,
    dt.home_county,
    dt.congressional_district_current,
    dt.phone_primary,
    dt.email_primary,
    -- Issue scores
    dt.issue_trump_approval,
    dt.issue_gun_rights_support,
    dt.issue_abortion_pro_life,
    dt.issue_border_security,
    dt.issue_school_choice,
    dt.issue_law_and_order,
    dt.issue_energy_independence,
    -- Calculate top issue
    GREATEST(
        dt.issue_gun_rights_support,
        dt.issue_abortion_pro_life,
        dt.issue_border_security,
        dt.issue_school_choice
    ) as top_issue_score,
    CASE 
        WHEN dt.issue_gun_rights_support >= GREATEST(dt.issue_abortion_pro_life, dt.issue_border_security, dt.issue_school_choice) 
            THEN '2A Rights'
        WHEN dt.issue_abortion_pro_life >= GREATEST(dt.issue_gun_rights_support, dt.issue_border_security, dt.issue_school_choice)
            THEN 'Pro-Life'
        WHEN dt.issue_border_security >= GREATEST(dt.issue_gun_rights_support, dt.issue_abortion_pro_life, dt.issue_school_choice)
            THEN 'Border Security'
        ELSE 'School Choice'
    END as top_issue,
    dt.turnout_likelihood_score,
    uc.donor_grade
FROM datatrust_profiles dt
LEFT JOIN unified_contacts uc ON dt.contact_id = uc.contact_id
WHERE dt.voter_registration_status = 'active'
    AND dt.deceased_flag = FALSE
ORDER BY dt.turnout_likelihood_score DESC;

-- CONTINUED IN PART 3 (matching functions and integration procedures)...
