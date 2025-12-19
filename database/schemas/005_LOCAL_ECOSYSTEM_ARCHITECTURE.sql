-- ============================================================================
-- BROYHILLGOP LOCAL ECOSYSTEM ARCHITECTURE
-- Defining Platform Structure: Donors, Volunteers, Candidates
-- November 28, 2025
-- ============================================================================
--
-- This document defines HOW the three local platforms are:
--   1. ORGANIZED - Data structure and hierarchy
--   2. STRUCTURED - Relationships between entities
--   3. DIFFERENT - What distinguishes each ecosystem
--   4. INTEGRATED - How they connect for matching
--
-- ============================================================================

-- ============================================================================
-- PLATFORM OVERVIEW: THREE DISTINCT ECOSYSTEMS
-- ============================================================================

/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BROYHILLGOP LOCAL ECOSYSTEM                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐        │
│  │  LOCAL DONOR     │   │  LOCAL VOLUNTEER │   │  LOCAL CANDIDATE │        │
│  │  PLATFORM        │   │  PLATFORM        │   │  PLATFORM        │        │
│  ├──────────────────┤   ├──────────────────┤   ├──────────────────┤        │
│  │ • 243,575 donors │   │ • 15,000+ vols   │   │ • 500+ candidates│        │
│  │ • 1,030 fields   │   │ • 500+ fields    │   │ • 500+ fields    │        │
│  │ • 21-tier grades │   │ • 21-tier grades │   │ • 21-tier grades │        │
│  │ • 1000-pt scores │   │ • 1000-pt scores │   │ • 1000-pt scores │        │
│  │ • 12 factions    │   │ • 12 factions    │   │ • 12 factions    │        │
│  │ • LOCAL profile  │   │ • LOCAL profile  │   │ • Questionnaire  │        │
│  └────────┬─────────┘   └────────┬─────────┘   └────────┬─────────┘        │
│           │                      │                      │                   │
│           └──────────────────────┼──────────────────────┘                   │
│                                  │                                          │
│                    ┌─────────────▼─────────────┐                            │
│                    │   UNIFIED MATCHING ENGINE  │                           │
│                    ├────────────────────────────┤                           │
│                    │ • 6-Dimension Affinity     │                           │
│                    │ • Faction Alignment        │                           │
│                    │ • Issue Priority Matching  │                           │
│                    │ • Local Engagement Score   │                           │
│                    │ • Office-Type Weighting    │                           │
│                    └────────────────────────────┘                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

============================================================================
KEY DIFFERENCES BETWEEN THE THREE PLATFORMS
============================================================================

┌─────────────────┬────────────────────────────────────────────────────────┐
│ DIMENSION       │ DONOR vs VOLUNTEER vs CANDIDATE                        │
├─────────────────┼────────────────────────────────────────────────────────┤
│ PRIMARY VALUE   │ DONOR: Financial support ($)                           │
│                 │ VOLUNTEER: Time & skills (hours)                       │
│                 │ CANDIDATE: Leadership & representation                 │
├─────────────────┼────────────────────────────────────────────────────────┤
│ SCORING BASIS   │ DONOR: Giving history, capacity, loyalty               │
│                 │ VOLUNTEER: Hours, reliability, skills, referrals       │
│                 │ CANDIDATE: Electability, profile, endorsements         │
├─────────────────┼────────────────────────────────────────────────────────┤
│ LOCAL WEIGHT    │ DONOR: 30% geographic in affinity                      │
│                 │ VOLUNTEER: 40% geographic (must be LOCAL)              │
│                 │ CANDIDATE: 100% local (runs in specific district)      │
├─────────────────┼────────────────────────────────────────────────────────┤
│ FACTION USE     │ DONOR: Match to candidates for solicitation            │
│                 │ VOLUNTEER: Match to candidates for deployment          │
│                 │ CANDIDATE: Define profile for donor/vol matching       │
├─────────────────┼────────────────────────────────────────────────────────┤
│ GRADING FOCUS   │ DONOR: Giving potential & history                      │
│                 │ VOLUNTEER: Reliability & impact potential              │
│                 │ CANDIDATE: Viability & competitiveness                 │
├─────────────────┼────────────────────────────────────────────────────────┤
│ ISSUE TRACKING  │ DONOR: What issues motivate giving                     │
│                 │ VOLUNTEER: What issues motivate action                 │
│                 │ CANDIDATE: Positions they'll campaign on               │
└─────────────────┴────────────────────────────────────────────────────────┘

============================================================================
DATA HIERARCHY STRUCTURE
============================================================================

LEVEL 1: GEOGRAPHIC
├── State (NC)
│   ├── Congressional Districts (14)
│   │   ├── State Senate Districts (50)
│   │   │   ├── State House Districts (120)
│   │   │   │   ├── Counties (100)
│   │   │   │   │   ├── Municipalities (500+)
│   │   │   │   │   │   ├── Precincts (2,700+)
│   │   │   │   │   │   │   └── Individuals (Donors/Volunteers/Candidates)

LEVEL 2: OFFICE TYPE (Local Candidates Only)
├── Sheriff (100 - one per county)
├── Commissioner (500+ - multiple per county)
├── School Board (700+ - county + municipal)
├── DA (50 - prosecutorial districts)
├── Judges (200+ - superior + district)
├── Mayor/Council (1000+ - municipalities)
├── Clerk/Register (200 - county offices)
└── Special Districts (500+ - CC, soil, hospital)

LEVEL 3: FACTION CLASSIFICATION (All Three Platforms)
├── MAGA (Trump Patriot)
├── EVAN (Evangelical)
├── TRAD (Traditional Conservative)
├── FISC (Fiscal Conservative)
├── LIBT (Libertarian)
├── BUSI (Business Republican)
├── LAWS (Law & Order)
├── POPF (Populist Firebrand)
├── MODG (Moderate)
├── VETS (Veterans/Military)
├── CHNA (Christian Nationalist)
└── RUAL (Rural/Agriculture)

*/

-- ============================================================================
-- PART 1: LOCAL DONOR PLATFORM STRUCTURE
-- ============================================================================

-- Local Donor Profile extends main donor table
CREATE TABLE IF NOT EXISTS local_donor_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id BIGINT NOT NULL UNIQUE REFERENCES donors(id) ON DELETE CASCADE,
    
    -- =========================================================================
    -- A. LOCAL ROOTS & COMMUNITY TIES (25 fields)
    -- =========================================================================
    
    -- Geographic Anchoring
    years_in_county INT DEFAULT 0,
    years_in_precinct INT DEFAULT 0,
    generations_in_county INT DEFAULT 1,
    born_in_county BOOLEAN DEFAULT FALSE,
    owns_home_in_county BOOLEAN DEFAULT FALSE,
    owns_business_in_county BOOLEAN DEFAULT FALSE,
    owns_farmland_in_county BOOLEAN DEFAULT FALSE,
    farm_acres INT DEFAULT 0,
    children_in_local_schools BOOLEAN DEFAULT FALSE,
    
    -- Community Organization Membership
    rotary_member BOOLEAN DEFAULT FALSE,
    lions_kiwanis_member BOOLEAN DEFAULT FALSE,
    chamber_member BOOLEAN DEFAULT FALSE,
    farm_bureau_member BOOLEAN DEFAULT FALSE,
    homeowners_assoc_active BOOLEAN DEFAULT FALSE,
    neighborhood_watch BOOLEAN DEFAULT FALSE,
    volunteer_fire_ems BOOLEAN DEFAULT FALSE,
    
    -- Local Volunteering (Non-Political)
    community_volunteer_hours_yearly INT DEFAULT 0,
    local_charity_volunteer BOOLEAN DEFAULT FALSE,
    youth_coach_mentor BOOLEAN DEFAULT FALSE,
    scout_leader BOOLEAN DEFAULT FALSE,
    church_volunteer BOOLEAN DEFAULT FALSE,
    school_volunteer_pta BOOLEAN DEFAULT FALSE,
    food_bank_volunteer BOOLEAN DEFAULT FALSE,
    disaster_relief_volunteer BOOLEAN DEFAULT FALSE,
    
    -- =========================================================================
    -- B. LOCAL POLITICAL ENGAGEMENT (35 fields)
    -- =========================================================================
    
    -- Party Membership
    county_gop_member BOOLEAN DEFAULT FALSE,
    county_gop_member_years INT DEFAULT 0,
    county_gop_officer BOOLEAN DEFAULT FALSE,
    county_gop_position VARCHAR(100),
    precinct_chair BOOLEAN DEFAULT FALSE,
    convention_delegate BOOLEAN DEFAULT FALSE,
    
    -- Meeting Attendance (Past 2 Years)
    attended_commissioner_mtgs INT DEFAULT 0,
    attended_school_board_mtgs INT DEFAULT 0,
    attended_council_mtgs INT DEFAULT 0,
    spoken_at_public_hearings INT DEFAULT 0,
    attended_gop_meetings INT DEFAULT 0,
    
    -- Campaign Volunteering
    local_campaigns_volunteered INT DEFAULT 0,
    local_campaign_details JSONB DEFAULT '[]'::jsonb,
    phone_bank_hours_total INT DEFAULT 0,
    door_knock_hours_total INT DEFAULT 0,
    poll_worker BOOLEAN DEFAULT FALSE,
    yard_sign_host BOOLEAN DEFAULT FALSE,
    event_volunteer BOOLEAN DEFAULT FALSE,
    event_host BOOLEAN DEFAULT FALSE,
    
    -- Activist Group Membership
    tea_party_member BOOLEAN DEFAULT FALSE,
    moms_for_liberty BOOLEAN DEFAULT FALSE,
    second_amendment_group BOOLEAN DEFAULT FALSE,
    pro_life_group BOOLEAN DEFAULT FALSE,
    local_conservative_club BOOLEAN DEFAULT FALSE,
    activist_groups JSONB DEFAULT '[]'::jsonb,
    
    -- Social Media Political Activity
    shares_political_content BOOLEAN DEFAULT FALSE,
    local_political_fb_groups JSONB DEFAULT '[]'::jsonb,
    political_posting_frequency VARCHAR(20), -- 'daily', 'weekly', 'monthly', 'rarely'
    
    -- =========================================================================
    -- C. LOCAL GIVING HISTORY (30 fields)
    -- =========================================================================
    
    -- Summary Statistics
    total_local_giving NUMERIC(12,2) DEFAULT 0,
    local_giving_count INT DEFAULT 0,
    avg_local_donation NUMERIC(10,2) DEFAULT 0,
    max_local_donation NUMERIC(10,2) DEFAULT 0,
    first_local_donation DATE,
    last_local_donation DATE,
    local_giving_streak_years INT DEFAULT 0,
    
    -- Giving by Office Type
    given_sheriff BOOLEAN DEFAULT FALSE,
    sheriff_total NUMERIC(10,2) DEFAULT 0,
    sheriff_count INT DEFAULT 0,
    
    given_school_board BOOLEAN DEFAULT FALSE,
    school_board_total NUMERIC(10,2) DEFAULT 0,
    school_board_count INT DEFAULT 0,
    
    given_commissioner BOOLEAN DEFAULT FALSE,
    commissioner_total NUMERIC(10,2) DEFAULT 0,
    commissioner_count INT DEFAULT 0,
    
    given_da_judge BOOLEAN DEFAULT FALSE,
    da_judge_total NUMERIC(10,2) DEFAULT 0,
    da_judge_count INT DEFAULT 0,
    
    given_municipal BOOLEAN DEFAULT FALSE,
    municipal_total NUMERIC(10,2) DEFAULT 0,
    municipal_count INT DEFAULT 0,
    
    -- Preferred Local Office (Auto-Calculated)
    preferred_office_type VARCHAR(10),
    office_type_affinity_scores JSONB DEFAULT '{}'::jsonb,
    
    -- Local Candidates Supported
    local_candidates_donated JSONB DEFAULT '[]'::jsonb,
    -- Format: [{"name": "John Smith", "office": "Sheriff", "year": 2020, "amount": 250}]
    favorite_local_candidate VARCHAR(200),
    
    -- =========================================================================
    -- D. LOCAL ISSUE PRIORITIES (25 fields)
    -- Importance ratings 1-10 (10 = highest priority)
    -- =========================================================================
    
    -- Public Safety Issues
    priority_crime_safety INT DEFAULT 5 CHECK (priority_crime_safety BETWEEN 1 AND 10),
    priority_drug_epidemic INT DEFAULT 5 CHECK (priority_drug_epidemic BETWEEN 1 AND 10),
    priority_sheriff_support INT DEFAULT 5 CHECK (priority_sheriff_support BETWEEN 1 AND 10),
    priority_immigration_local INT DEFAULT 5 CHECK (priority_immigration_local BETWEEN 1 AND 10),
    
    -- Education Issues
    priority_school_curriculum INT DEFAULT 5 CHECK (priority_school_curriculum BETWEEN 1 AND 10),
    priority_parental_rights INT DEFAULT 5 CHECK (priority_parental_rights BETWEEN 1 AND 10),
    priority_school_choice INT DEFAULT 5 CHECK (priority_school_choice BETWEEN 1 AND 10),
    priority_school_safety INT DEFAULT 5 CHECK (priority_school_safety BETWEEN 1 AND 10),
    
    -- Fiscal Issues
    priority_property_taxes INT DEFAULT 5 CHECK (priority_property_taxes BETWEEN 1 AND 10),
    priority_government_spending INT DEFAULT 5 CHECK (priority_government_spending BETWEEN 1 AND 10),
    priority_economic_development INT DEFAULT 5 CHECK (priority_economic_development BETWEEN 1 AND 10),
    
    -- Growth & Development Issues
    priority_zoning_development INT DEFAULT 5 CHECK (priority_zoning_development BETWEEN 1 AND 10),
    priority_rural_preservation INT DEFAULT 5 CHECK (priority_rural_preservation BETWEEN 1 AND 10),
    priority_infrastructure INT DEFAULT 5 CHECK (priority_infrastructure BETWEEN 1 AND 10),
    
    -- Values Issues
    priority_religious_liberty INT DEFAULT 5 CHECK (priority_religious_liberty BETWEEN 1 AND 10),
    priority_pro_life_local INT DEFAULT 5 CHECK (priority_pro_life_local BETWEEN 1 AND 10),
    priority_gun_rights INT DEFAULT 5 CHECK (priority_gun_rights BETWEEN 1 AND 10),
    
    -- Top 3 Issues (Auto-Calculated)
    top_issue_1 VARCHAR(50),
    top_issue_1_score INT,
    top_issue_2 VARCHAR(50),
    top_issue_2_score INT,
    top_issue_3 VARCHAR(50),
    top_issue_3_score INT,
    
    -- Issue Alignment Score (0-100, calculated)
    issue_conservatism_score INT DEFAULT 50,
    
    -- =========================================================================
    -- E. LOCAL DONOR SCORING (Calculated Fields)
    -- =========================================================================
    
    -- 21-Tier Local Donor Grade (A+ to U-)
    local_donor_grade VARCHAR(2),
    local_donor_grade_numeric INT,
    
    -- 1000-Point Local Engagement Score
    local_engagement_score INT DEFAULT 0,
    score_community_roots INT DEFAULT 0,      -- 0-200
    score_political_activity INT DEFAULT 0,   -- 0-250
    score_local_giving INT DEFAULT 0,         -- 0-300
    score_issue_alignment INT DEFAULT 0,      -- 0-150
    score_activist_involvement INT DEFAULT 0, -- 0-100
    
    -- Office Type Affinity (0-100 for each)
    affinity_sheriff INT DEFAULT 50,
    affinity_school_board INT DEFAULT 50,
    affinity_commissioner INT DEFAULT 50,
    affinity_da_judge INT DEFAULT 50,
    affinity_municipal INT DEFAULT 50,
    
    -- Metadata
    profile_completeness INT DEFAULT 0,
    last_survey_date DATE,
    data_confidence DECIMAL(3,2) DEFAULT 0.50,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_donor_local UNIQUE (donor_id)
);

-- ============================================================================
-- PART 2: LOCAL VOLUNTEER PLATFORM STRUCTURE
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_volunteer_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID NOT NULL, -- References main volunteer table
    donor_id BIGINT, -- Optional link to donor record
    
    -- =========================================================================
    -- A. LOCAL ROOTS & AVAILABILITY (20 fields)
    -- =========================================================================
    
    -- Geographic
    county_fips VARCHAR(5) NOT NULL,
    county_name VARCHAR(100) NOT NULL,
    municipality VARCHAR(100),
    precinct_id VARCHAR(20),
    years_in_county INT DEFAULT 0,
    owns_home_locally BOOLEAN DEFAULT FALSE,
    works_in_county BOOLEAN DEFAULT FALSE,
    
    -- Availability
    available_weekdays BOOLEAN DEFAULT FALSE,
    available_evenings BOOLEAN DEFAULT FALSE,
    available_weekends BOOLEAN DEFAULT FALSE,
    hours_per_week_available INT DEFAULT 0,
    travel_radius_miles INT DEFAULT 10,
    has_reliable_transportation BOOLEAN DEFAULT TRUE,
    
    -- Communication
    prefers_text BOOLEAN DEFAULT TRUE,
    prefers_email BOOLEAN DEFAULT TRUE,
    prefers_call BOOLEAN DEFAULT FALSE,
    response_time_typical VARCHAR(20), -- 'immediate', 'same_day', 'next_day'
    
    -- Physical Capabilities
    can_door_knock BOOLEAN DEFAULT TRUE,
    can_stand_long_periods BOOLEAN DEFAULT TRUE,
    mobility_limitations TEXT,
    
    -- =========================================================================
    -- B. LOCAL POLITICAL VOLUNTEER HISTORY (30 fields)
    -- =========================================================================
    
    -- Summary Stats
    total_volunteer_hours INT DEFAULT 0,
    total_campaigns_worked INT DEFAULT 0,
    total_local_campaigns INT DEFAULT 0,
    years_volunteering INT DEFAULT 0,
    
    -- Activity Type Hours
    phone_bank_hours INT DEFAULT 0,
    door_knock_hours INT DEFAULT 0,
    poll_greeting_hours INT DEFAULT 0,
    poll_watching_hours INT DEFAULT 0,
    event_staffing_hours INT DEFAULT 0,
    office_work_hours INT DEFAULT 0,
    data_entry_hours INT DEFAULT 0,
    social_media_hours INT DEFAULT 0,
    
    -- Local Campaigns Worked
    local_campaigns_worked JSONB DEFAULT '[]'::jsonb,
    -- Format: [{"candidate": "John Smith", "office": "Sheriff", "year": 2020, "hours": 40, "role": "door_knocker"}]
    
    -- Leadership Roles
    campaign_leadership_roles JSONB DEFAULT '[]'::jsonb,
    precinct_captain BOOLEAN DEFAULT FALSE,
    phone_bank_lead BOOLEAN DEFAULT FALSE,
    canvass_lead BOOLEAN DEFAULT FALSE,
    event_coordinator BOOLEAN DEFAULT FALSE,
    
    -- Special Skills
    has_campaign_experience BOOLEAN DEFAULT FALSE,
    has_data_skills BOOLEAN DEFAULT FALSE,
    has_social_media_skills BOOLEAN DEFAULT FALSE,
    has_fundraising_experience BOOLEAN DEFAULT FALSE,
    speaks_spanish BOOLEAN DEFAULT FALSE,
    other_languages JSONB DEFAULT '[]'::jsonb,
    professional_skills JSONB DEFAULT '[]'::jsonb,
    
    -- Reliability Metrics
    assignments_completed INT DEFAULT 0,
    assignments_missed INT DEFAULT 0,
    reliability_score DECIMAL(5,2) DEFAULT 100.00,
    no_show_count INT DEFAULT 0,
    
    -- =========================================================================
    -- C. LOCAL ISSUE PRIORITIES (Same as Donor - for matching)
    -- =========================================================================
    
    priority_crime_safety INT DEFAULT 5,
    priority_drug_epidemic INT DEFAULT 5,
    priority_sheriff_support INT DEFAULT 5,
    priority_school_curriculum INT DEFAULT 5,
    priority_parental_rights INT DEFAULT 5,
    priority_school_choice INT DEFAULT 5,
    priority_property_taxes INT DEFAULT 5,
    priority_government_spending INT DEFAULT 5,
    priority_zoning_development INT DEFAULT 5,
    priority_religious_liberty INT DEFAULT 5,
    priority_pro_life_local INT DEFAULT 5,
    priority_gun_rights INT DEFAULT 5,
    
    -- Top Issues
    top_issue_1 VARCHAR(50),
    top_issue_2 VARCHAR(50),
    top_issue_3 VARCHAR(50),
    
    -- =========================================================================
    -- D. OFFICE TYPE PREFERENCES (What races they want to work)
    -- =========================================================================
    
    -- Preference Ratings (1-10, 10 = most interested)
    pref_sheriff_races INT DEFAULT 5,
    pref_school_board_races INT DEFAULT 5,
    pref_commissioner_races INT DEFAULT 5,
    pref_da_judge_races INT DEFAULT 5,
    pref_municipal_races INT DEFAULT 5,
    pref_state_races INT DEFAULT 5,
    pref_federal_races INT DEFAULT 5,
    
    -- Preferred Office Type (Auto-Calculated)
    preferred_office_type VARCHAR(10),
    
    -- Candidate Preferences
    preferred_candidate_faction VARCHAR(4),
    will_work_any_gop BOOLEAN DEFAULT TRUE,
    candidate_exclusions JSONB DEFAULT '[]'::jsonb,
    
    -- =========================================================================
    -- E. LOCAL VOLUNTEER SCORING (Calculated)
    -- =========================================================================
    
    -- 21-Tier Volunteer Grade
    local_volunteer_grade VARCHAR(2),
    local_volunteer_grade_numeric INT,
    
    -- 1000-Point Volunteer Value Score
    local_volunteer_score INT DEFAULT 0,
    score_experience INT DEFAULT 0,        -- 0-250
    score_reliability INT DEFAULT 0,       -- 0-200
    score_availability INT DEFAULT 0,      -- 0-150
    score_skills INT DEFAULT 0,            -- 0-150
    score_local_knowledge INT DEFAULT 0,   -- 0-150
    score_leadership INT DEFAULT 0,        -- 0-100
    
    -- Office Type Deployment Scores (0-100)
    deploy_score_sheriff INT DEFAULT 50,
    deploy_score_school_board INT DEFAULT 50,
    deploy_score_commissioner INT DEFAULT 50,
    deploy_score_da_judge INT DEFAULT 50,
    deploy_score_municipal INT DEFAULT 50,
    
    -- Metadata
    profile_completeness INT DEFAULT 0,
    last_activity_date DATE,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_volunteer_local UNIQUE (volunteer_id)
);

-- ============================================================================
-- PART 3: LOCAL CANDIDATE QUESTIONNAIRE (500+ Fields)
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_candidate_questionnaire (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL REFERENCES local_candidates(id) ON DELETE CASCADE,
    
    -- =========================================================================
    -- SECTION 1: LOCAL ENGAGEMENT HISTORY (60 fields)
    -- =========================================================================
    
    -- 1.1 Community Roots
    q_years_in_county INT,
    q_years_in_municipality INT,
    q_years_in_precinct INT,
    q_generations_in_county INT,
    q_born_in_county BOOLEAN,
    q_where_raised VARCHAR(200),
    q_why_moved_here TEXT,
    
    -- 1.2 Property & Business
    q_owns_home BOOLEAN,
    q_home_years INT,
    q_owns_other_property BOOLEAN,
    q_owns_farmland BOOLEAN,
    q_farm_acres INT,
    q_farm_type VARCHAR(100),
    q_owns_local_business BOOLEAN,
    q_business_name VARCHAR(200),
    q_business_years INT,
    q_business_employees INT,
    q_business_industry VARCHAR(100),
    
    -- 1.3 Community Organizations (Check all that apply)
    q_rotary_member BOOLEAN DEFAULT FALSE,
    q_rotary_position VARCHAR(100),
    q_rotary_years INT,
    q_lions_member BOOLEAN DEFAULT FALSE,
    q_kiwanis_member BOOLEAN DEFAULT FALSE,
    q_jaycees_member BOOLEAN DEFAULT FALSE,
    q_chamber_member BOOLEAN DEFAULT FALSE,
    q_chamber_position VARCHAR(100),
    q_farm_bureau_member BOOLEAN DEFAULT FALSE,
    q_farm_bureau_position VARCHAR(100),
    q_elks_moose_member BOOLEAN DEFAULT FALSE,
    q_masonic_lodge BOOLEAN DEFAULT FALSE,
    q_vfw_member BOOLEAN DEFAULT FALSE,
    q_american_legion BOOLEAN DEFAULT FALSE,
    q_other_civic_orgs JSONB DEFAULT '[]'::jsonb,
    
    -- 1.4 Local Government Engagement
    q_commissioner_meetings_attended INT,
    q_school_board_meetings_attended INT,
    q_city_council_meetings_attended INT,
    q_planning_board_meetings INT,
    q_public_hearings_spoken INT,
    q_public_comment_topics TEXT,
    q_foia_requests_filed INT,
    
    -- 1.5 Appointed Positions
    q_served_appointed_board BOOLEAN,
    q_appointed_boards JSONB DEFAULT '[]'::jsonb,
    -- Format: [{"board": "Planning Board", "years": "2018-2022", "role": "Member"}]
    q_appointed_by VARCHAR(100),
    
    -- 1.6 Community Volunteering
    q_volunteer_hours_yearly INT,
    q_volunteer_organizations JSONB DEFAULT '[]'::jsonb,
    q_volunteer_leadership_roles JSONB DEFAULT '[]'::jsonb,
    q_youth_coach BOOLEAN,
    q_youth_sports_coached TEXT,
    q_scout_leader BOOLEAN,
    q_scout_years INT,
    q_4h_leader BOOLEAN,
    q_school_volunteer BOOLEAN,
    q_food_bank_volunteer BOOLEAN,
    q_habitat_volunteer BOOLEAN,
    q_disaster_relief_volunteer BOOLEAN,
    q_disaster_events TEXT,
    
    -- =========================================================================
    -- SECTION 2: IDEOLOGY & POSITIONS (80 fields)
    -- =========================================================================
    
    -- 2.1 Self-Identification (1-10 scale)
    q_ideology_overall INT CHECK (q_ideology_overall BETWEEN 1 AND 10),
    q_ideology_fiscal INT CHECK (q_ideology_fiscal BETWEEN 1 AND 10),
    q_ideology_social INT CHECK (q_ideology_social BETWEEN 1 AND 10),
    q_ideology_populist INT CHECK (q_ideology_populist BETWEEN 1 AND 10),
    q_ideology_libertarian INT CHECK (q_ideology_libertarian BETWEEN 1 AND 10),
    
    -- 2.2 Faction Self-Assessment (How much do you identify with each?)
    q_faction_maga INT CHECK (q_faction_maga BETWEEN 0 AND 100),
    q_faction_evan INT CHECK (q_faction_evan BETWEEN 0 AND 100),
    q_faction_trad INT CHECK (q_faction_trad BETWEEN 0 AND 100),
    q_faction_fisc INT CHECK (q_faction_fisc BETWEEN 0 AND 100),
    q_faction_libt INT CHECK (q_faction_libt BETWEEN 0 AND 100),
    q_faction_busi INT CHECK (q_faction_busi BETWEEN 0 AND 100),
    q_faction_laws INT CHECK (q_faction_laws BETWEEN 0 AND 100),
    q_faction_popf INT CHECK (q_faction_popf BETWEEN 0 AND 100),
    q_faction_modg INT CHECK (q_faction_modg BETWEEN 0 AND 100),
    q_faction_vets INT CHECK (q_faction_vets BETWEEN 0 AND 100),
    q_faction_chna INT CHECK (q_faction_chna BETWEEN 0 AND 100),
    q_faction_rual INT CHECK (q_faction_rual BETWEEN 0 AND 100),
    
    -- 2.3 National Issue Positions (1-10, 10 = most conservative)
    q_pos_abortion INT,
    q_pos_abortion_exceptions TEXT,
    q_pos_guns INT,
    q_pos_guns_detail TEXT,
    q_pos_immigration INT,
    q_pos_border_wall INT,
    q_pos_federal_spending INT,
    q_pos_social_security INT,
    q_pos_healthcare INT,
    q_pos_climate INT,
    q_pos_trade INT,
    q_pos_foreign_policy INT,
    q_pos_military_spending INT,
    
    -- 2.4 State Issue Positions
    q_pos_nc_income_tax INT,
    q_pos_nc_sales_tax INT,
    q_pos_nc_education_funding INT,
    q_pos_nc_medicaid_expansion INT,
    q_pos_nc_lottery INT,
    q_pos_nc_voter_id INT,
    q_pos_nc_redistricting INT,
    
    -- 2.5 LOCAL Issue Positions (CRITICAL FOR LOCAL RACES)
    q_pos_local_property_tax INT,
    q_pos_local_property_tax_detail TEXT,
    q_pos_local_sales_tax INT,
    q_pos_local_school_funding INT,
    q_pos_local_school_funding_detail TEXT,
    q_pos_local_crime INT,
    q_pos_local_crime_detail TEXT,
    q_pos_local_drugs INT,
    q_pos_local_drugs_detail TEXT,
    q_pos_local_growth INT,
    q_pos_local_growth_detail TEXT,
    q_pos_local_zoning INT,
    q_pos_local_zoning_detail TEXT,
    q_pos_local_infrastructure INT,
    q_pos_local_water_sewer INT,
    q_pos_local_roads INT,
    q_pos_local_public_transit INT,
    q_pos_local_parks_rec INT,
    q_pos_local_libraries INT,
    q_pos_local_economic_dev INT,
    q_pos_local_incentives INT,
    
    -- 2.6 Hot Button Issues
    q_pos_crt_schools INT,
    q_pos_crt_detail TEXT,
    q_pos_dei_government INT,
    q_pos_transgender_schools INT,
    q_pos_transgender_detail TEXT,
    q_pos_library_materials INT,
    q_pos_mask_mandates INT,
    q_pos_vaccine_mandates INT,
    q_pos_sanctuary_city INT,
    q_pos_287g_program INT,
    q_pos_defund_police INT,
    q_pos_bail_reform INT,
    
    -- 2.7 Priority Issues (Rank 1-5)
    q_priority_1 VARCHAR(100),
    q_priority_2 VARCHAR(100),
    q_priority_3 VARCHAR(100),
    q_priority_4 VARCHAR(100),
    q_priority_5 VARCHAR(100),
    q_priority_explanation TEXT,
    
    -- =========================================================================
    -- SECTION 3: LIFESTYLE & DEMOGRAPHICS (40 fields)
    -- =========================================================================
    
    -- 3.1 Family
    q_marital_status VARCHAR(50),
    q_spouse_name VARCHAR(200),
    q_spouse_maiden_name VARCHAR(100),
    q_spouse_occupation VARCHAR(200),
    q_spouse_employer VARCHAR(200),
    q_spouse_politically_active BOOLEAN,
    q_years_married INT,
    q_previous_marriages INT,
    q_children_count INT,
    q_children_names_ages TEXT,
    q_children_public_school BOOLEAN,
    q_children_private_school BOOLEAN,
    q_children_private_school_name VARCHAR(200),
    q_children_homeschool BOOLEAN,
    q_grandchildren_count INT,
    q_extended_family_in_county INT,
    q_family_prominent_locally BOOLEAN,
    q_family_prominence_detail TEXT,
    
    -- 3.2 Lifestyle Indicators
    q_gun_owner BOOLEAN,
    q_guns_owned_types TEXT,
    q_concealed_carry BOOLEAN,
    q_nra_member BOOLEAN,
    q_nra_grade VARCHAR(5),
    q_hunting_license BOOLEAN,
    q_hunting_frequency VARCHAR(50),
    q_fishing_license BOOLEAN,
    q_pickup_truck BOOLEAN,
    q_american_flag_display BOOLEAN,
    q_trump_merchandise BOOLEAN,
    q_thin_blue_line_support BOOLEAN,
    q_dont_tread_flag BOOLEAN,
    
    -- 3.3 Media Consumption
    q_primary_news_source VARCHAR(100),
    q_fox_news_viewer BOOLEAN,
    q_newsmax_viewer BOOLEAN,
    q_oan_viewer BOOLEAN,
    q_talk_radio_listener BOOLEAN,
    q_favorite_talk_shows TEXT,
    q_local_paper_subscriber BOOLEAN,
    q_local_paper_name VARCHAR(100),
    q_podcast_listener BOOLEAN,
    q_favorite_podcasts TEXT,
    
    -- =========================================================================
    -- SECTION 4: REPUBLICAN PARTY ENGAGEMENT (45 fields)
    -- =========================================================================
    
    -- 4.1 Registration History
    q_party_registration VARCHAR(20),
    q_years_registered_republican INT,
    q_previously_other_party BOOLEAN,
    q_previous_party VARCHAR(50),
    q_year_became_republican INT,
    q_why_republican TEXT,
    
    -- 4.2 County GOP
    q_county_gop_member BOOLEAN,
    q_county_gop_years INT,
    q_county_gop_officer BOOLEAN,
    q_county_gop_position VARCHAR(100),
    q_county_gop_committee VARCHAR(100),
    q_county_gop_mtgs_attended INT,
    
    -- 4.3 Precinct & Convention
    q_precinct_officer BOOLEAN,
    q_precinct_position VARCHAR(100),
    q_precinct_years INT,
    q_district_delegate BOOLEAN,
    q_district_delegate_years TEXT,
    q_state_delegate BOOLEAN,
    q_state_delegate_years TEXT,
    q_national_delegate BOOLEAN,
    q_national_delegate_year INT,
    
    -- 4.4 Campaign Volunteering
    q_campaigns_volunteered INT,
    q_campaigns_volunteered_list JSONB DEFAULT '[]'::jsonb,
    q_phone_bank_hours INT,
    q_door_knock_hours INT,
    q_poll_greeter BOOLEAN,
    q_poll_observer BOOLEAN,
    q_election_judge BOOLEAN,
    q_headquarters_volunteer BOOLEAN,
    q_event_organizer BOOLEAN,
    
    -- 4.5 Trump Support
    q_trump_2016_primary BOOLEAN,
    q_trump_2016_general BOOLEAN,
    q_trump_2020 BOOLEAN,
    q_trump_2024 BOOLEAN,
    q_trump_rally_attended BOOLEAN,
    q_trump_rally_count INT,
    q_trump_endorsed BOOLEAN,
    q_trump_endorsement_date DATE,
    q_seeking_trump_endorsement BOOLEAN,
    
    -- 4.6 Donor to GOP
    q_donated_county_gop BOOLEAN,
    q_county_gop_lifetime NUMERIC(10,2),
    q_donated_ncgop BOOLEAN,
    q_ncgop_lifetime NUMERIC(10,2),
    q_donated_rnc BOOLEAN,
    q_rnc_lifetime NUMERIC(10,2),
    
    -- =========================================================================
    -- SECTION 5: LOCAL CHARITABLE & CIVIC (35 fields)
    -- =========================================================================
    
    q_annual_charitable_giving NUMERIC(10,2),
    q_local_charities JSONB DEFAULT '[]'::jsonb,
    q_united_way_donor BOOLEAN,
    q_community_foundation_donor BOOLEAN,
    q_hospital_foundation_donor BOOLEAN,
    q_scholarship_fund_donor BOOLEAN,
    q_scholarship_name VARCHAR(200),
    q_fire_dept_supporter BOOLEAN,
    q_sheriff_foundation_donor BOOLEAN,
    q_fop_supporter BOOLEAN,
    q_veterans_charity_donor BOOLEAN,
    q_veterans_charities TEXT,
    q_crisis_pregnancy_donor BOOLEAN,
    q_crisis_pregnancy_volunteer BOOLEAN,
    q_crisis_pregnancy_center VARCHAR(200),
    q_food_bank_donor BOOLEAN,
    q_homeless_shelter_donor BOOLEAN,
    q_animal_shelter_donor BOOLEAN,
    q_arts_culture_donor BOOLEAN,
    q_historical_society_member BOOLEAN,
    q_historical_society_role VARCHAR(100),
    q_land_trust_donor BOOLEAN,
    q_conservation_easement BOOLEAN,
    q_4h_supporter BOOLEAN,
    q_ffa_supporter BOOLEAN,
    q_youth_sports_sponsor BOOLEAN,
    q_youth_sports_amount NUMERIC(10,2),
    q_church_giving_annual NUMERIC(10,2),
    q_tithe_pct INT,
    q_mission_support BOOLEAN,
    q_mission_trips_taken INT,
    q_mission_locations TEXT,
    
    -- =========================================================================
    -- SECTION 6: FAITH & VALUES (30 fields)
    -- =========================================================================
    
    q_religious_affiliation VARCHAR(100),
    q_denomination VARCHAR(100),
    q_denomination_detail TEXT,
    q_church_name VARCHAR(200),
    q_church_city VARCHAR(100),
    q_church_member_years INT,
    q_church_attendance VARCHAR(50),
    q_church_leadership BOOLEAN,
    q_church_position VARCHAR(200),
    q_deacon_elder BOOLEAN,
    q_sunday_school_teacher BOOLEAN,
    q_small_group_leader BOOLEAN,
    q_choir_worship_team BOOLEAN,
    q_youth_ministry BOOLEAN,
    q_mens_ministry BOOLEAN,
    q_womens_ministry BOOLEAN,
    q_outreach_ministry BOOLEAN,
    
    q_faith_testimony TEXT,
    q_faith_influences_politics BOOLEAN,
    q_faith_influence_how TEXT,
    
    q_pro_life_position TEXT,
    q_march_for_life_attended INT,
    q_pro_life_activism TEXT,
    
    q_religious_liberty_importance INT,
    q_prayer_schools INT,
    q_ten_commandments INT,
    q_christian_nation_belief INT,
    q_biblical_worldview INT,
    
    -- =========================================================================
    -- SECTION 7: EDUCATION ENGAGEMENT (25 fields)
    -- =========================================================================
    
    q_pta_member BOOLEAN,
    q_pta_officer BOOLEAN,
    q_pta_position VARCHAR(100),
    q_pta_years INT,
    q_school_volunteer BOOLEAN,
    q_school_volunteer_hours INT,
    q_school_volunteer_roles TEXT,
    q_booster_club_member BOOLEAN,
    q_booster_club_position VARCHAR(100),
    q_school_board_speaker BOOLEAN,
    q_school_board_topics TEXT,
    q_curriculum_reviewer BOOLEAN,
    q_library_review_committee BOOLEAN,
    q_moms_for_liberty BOOLEAN,
    q_moms_liberty_role VARCHAR(100),
    q_parents_rights_group BOOLEAN,
    q_parents_rights_name VARCHAR(200),
    q_homeschool_coop BOOLEAN,
    q_private_school_board BOOLEAN,
    q_charter_school_supporter BOOLEAN,
    q_school_choice_advocate BOOLEAN,
    q_education_advocacy JSONB DEFAULT '[]'::jsonb,
    q_teacher_union_opinion INT,
    q_school_board_endorsements JSONB DEFAULT '[]'::jsonb,
    
    -- =========================================================================
    -- SECTION 8: SOCIAL MEDIA & ONLINE (35 fields)
    -- =========================================================================
    
    -- Personal Accounts
    q_facebook_url VARCHAR(500),
    q_facebook_followers INT,
    q_facebook_political_posts BOOLEAN,
    q_twitter_handle VARCHAR(100),
    q_twitter_followers INT,
    q_instagram_handle VARCHAR(100),
    q_instagram_followers INT,
    q_truth_social_handle VARCHAR(100),
    q_truth_social_followers INT,
    q_parler_handle VARCHAR(100),
    q_gab_handle VARCHAR(100),
    q_linkedin_url VARCHAR(500),
    q_youtube_channel VARCHAR(500),
    q_youtube_subscribers INT,
    q_tiktok_handle VARCHAR(100),
    q_tiktok_followers INT,
    q_podcast_host BOOLEAN,
    q_podcast_name VARCHAR(200),
    q_podcast_episodes INT,
    q_blog_url VARCHAR(500),
    q_personal_website VARCHAR(500),
    
    -- Political Activity
    q_shares_political_content BOOLEAN,
    q_posting_frequency VARCHAR(50),
    q_conservative_pages_followed INT,
    q_local_fb_groups JSONB DEFAULT '[]'::jsonb,
    q_viral_posts INT,
    q_controversial_posts_deleted BOOLEAN,
    q_attacked_on_social BOOLEAN,
    q_attack_details TEXT,
    q_doxxing_concerns BOOLEAN,
    q_social_media_manager BOOLEAN,
    q_manager_name VARCHAR(200),
    
    -- =========================================================================
    -- SECTION 9: CONSERVATIVE GROUPS (25 fields)
    -- =========================================================================
    
    q_tea_party_member BOOLEAN,
    q_tea_party_years INT,
    q_tea_party_role VARCHAR(100),
    q_912_project BOOLEAN,
    q_local_conservative_club BOOLEAN,
    q_conservative_club_name VARCHAR(200),
    q_conservative_club_role VARCHAR(100),
    q_federalist_society BOOLEAN,
    q_heritage_action BOOLEAN,
    q_afp_member BOOLEAN,
    q_club_for_growth_rated BOOLEAN,
    q_turning_point_usa BOOLEAN,
    q_young_republicans BOOLEAN,
    q_college_republicans BOOLEAN,
    q_second_amendment_orgs JSONB DEFAULT '[]'::jsonb,
    q_pro_life_orgs JSONB DEFAULT '[]'::jsonb,
    q_christian_political_orgs JSONB DEFAULT '[]'::jsonb,
    q_oath_keepers BOOLEAN,
    q_three_percenters BOOLEAN,
    q_constitutional_sheriff_support BOOLEAN,
    q_other_conservative_orgs JSONB DEFAULT '[]'::jsonb,
    
    -- =========================================================================
    -- SECTION 10: PRESS & PUBLIC RECORD (30 fields)
    -- =========================================================================
    
    -- Positive Coverage
    q_positive_press_count INT,
    q_positive_press_articles JSONB DEFAULT '[]'::jsonb,
    q_awards_received JSONB DEFAULT '[]'::jsonb,
    q_community_awards TEXT,
    q_business_awards TEXT,
    q_military_awards TEXT,
    q_civic_awards TEXT,
    q_endorsement_articles JSONB DEFAULT '[]'::jsonb,
    
    -- Negative / Vulnerabilities
    q_negative_press_count INT,
    q_negative_press_articles JSONB DEFAULT '[]'::jsonb,
    q_lawsuits_plaintiff INT,
    q_lawsuits_defendant INT,
    q_lawsuit_details TEXT,
    q_bankruptcies INT,
    q_bankruptcy_details TEXT,
    q_foreclosures INT,
    q_tax_liens BOOLEAN,
    q_tax_lien_details TEXT,
    q_criminal_record BOOLEAN,
    q_criminal_details TEXT,
    q_dui_history BOOLEAN,
    q_dui_count INT,
    q_domestic_issues BOOLEAN,
    q_ethics_complaints INT,
    q_ethics_details TEXT,
    q_controversial_statements TEXT,
    q_opposition_research_concerns TEXT,
    q_skeletons_disclosed TEXT,
    
    -- =========================================================================
    -- SECTION 11: ELECTION HISTORY & FUNDRAISING (35 fields)
    -- =========================================================================
    
    -- Past Campaigns
    q_previous_races INT,
    q_previous_races_detail JSONB DEFAULT '[]'::jsonb,
    -- Format: [{"year": 2020, "office": "Commissioner", "result": "won", "pct": 52.3, "votes": 15000}]
    q_wins INT,
    q_losses INT,
    q_closest_margin DECIMAL(5,2),
    q_best_margin DECIMAL(5,2),
    q_total_votes_career INT,
    
    -- Current Race
    q_current_fundraising_goal NUMERIC(12,2),
    q_amount_raised_current NUMERIC(12,2),
    q_cash_on_hand NUMERIC(12,2),
    q_debt NUMERIC(12,2),
    q_donor_count_current INT,
    q_avg_donation_current NUMERIC(10,2),
    q_max_donation_current NUMERIC(10,2),
    q_self_funded_amount NUMERIC(12,2),
    q_pac_contributions NUMERIC(12,2),
    q_party_support NUMERIC(12,2),
    
    -- Fundraising Network
    q_total_raised_career NUMERIC(12,2),
    q_total_donors_career INT,
    q_major_donors JSONB DEFAULT '[]'::jsonb,
    -- Format: [{"name": "John Smith", "total": 5000, "relationship": "business"}]
    q_bundlers JSONB DEFAULT '[]'::jsonb,
    q_fundraising_events_hosted INT,
    q_avg_event_raised NUMERIC(10,2),
    q_grassroots_donor_pct DECIMAL(5,2),
    q_recurring_donors INT,
    q_donor_retention_rate DECIMAL(5,2),
    q_fundraising_network_strength INT,
    
    -- Finance Committee
    q_finance_committee_chair VARCHAR(200),
    q_finance_committee_members JSONB DEFAULT '[]'::jsonb,
    q_campaign_treasurer VARCHAR(200),
    q_campaign_consultant VARCHAR(200),
    q_campaign_manager VARCHAR(200),
    
    -- =========================================================================
    -- METADATA
    -- =========================================================================
    
    questionnaire_version VARCHAR(10) DEFAULT '2.0',
    sections_completed INT DEFAULT 0,
    completion_pct INT DEFAULT 0,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    verified_by VARCHAR(100),
    verified_at TIMESTAMP,
    interviewer VARCHAR(100),
    interview_date DATE,
    follow_up_needed BOOLEAN DEFAULT FALSE,
    follow_up_notes TEXT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_candidate_quest UNIQUE (candidate_id)
);

-- ============================================================================
-- PART 4: ISSUE POPULARITY RATING TABLE
-- Tracks how popular each issue is among donors/volunteers
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_issue_popularity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Geographic Scope
    county_fips VARCHAR(5),
    county_name VARCHAR(100),
    scope_type VARCHAR(20) NOT NULL, -- 'county', 'statewide', 'office_type'
    office_type VARCHAR(10), -- If scope is office_type
    
    -- Issue Identification
    issue_code VARCHAR(50) NOT NULL,
    issue_name VARCHAR(100) NOT NULL,
    issue_category VARCHAR(50), -- 'public_safety', 'education', 'fiscal', 'growth', 'values'
    
    -- Popularity Metrics (Based on Survey/Activity Data)
    donor_avg_priority DECIMAL(4,2), -- Average priority rating from donors
    donor_count INT, -- Number of donors who rated this
    donor_top3_pct DECIMAL(5,2), -- % of donors with this in top 3
    
    volunteer_avg_priority DECIMAL(4,2),
    volunteer_count INT,
    volunteer_top3_pct DECIMAL(5,2),
    
    -- Combined Popularity Score (0-100)
    popularity_score INT DEFAULT 50,
    popularity_rank INT, -- Rank within scope
    
    -- Trend
    trend_direction VARCHAR(10), -- 'rising', 'stable', 'falling'
    trend_pct_change DECIMAL(5,2),
    
    -- By Faction (Which factions care most about this issue)
    faction_scores JSONB DEFAULT '{}'::jsonb,
    -- Format: {"LAWS": 95, "EVAN": 60, "FISC": 40, ...}
    
    top_faction VARCHAR(4),
    
    -- Metadata
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_points INT DEFAULT 0,
    
    CONSTRAINT unique_issue_scope UNIQUE (county_fips, scope_type, office_type, issue_code)
);

-- Seed with standard issues
INSERT INTO local_issue_popularity (scope_type, issue_code, issue_name, issue_category, popularity_score) VALUES
('statewide', 'crime_safety', 'Crime & Public Safety', 'public_safety', 75),
('statewide', 'drug_epidemic', 'Drug Epidemic / Opioids', 'public_safety', 70),
('statewide', 'sheriff_support', 'Support for Sheriff / Law Enforcement', 'public_safety', 72),
('statewide', 'immigration_local', 'Local Immigration Enforcement', 'public_safety', 65),
('statewide', 'school_curriculum', 'School Curriculum / What Kids Learn', 'education', 78),
('statewide', 'parental_rights', 'Parental Rights in Education', 'education', 82),
('statewide', 'school_choice', 'School Choice / Vouchers', 'education', 68),
('statewide', 'school_safety', 'School Safety / Resource Officers', 'education', 70),
('statewide', 'property_taxes', 'Property Tax Levels', 'fiscal', 80),
('statewide', 'government_spending', 'Government Spending / Waste', 'fiscal', 75),
('statewide', 'economic_development', 'Jobs & Economic Development', 'fiscal', 65),
('statewide', 'zoning_development', 'Zoning / Development Control', 'growth', 60),
('statewide', 'rural_preservation', 'Preserving Rural Character', 'growth', 62),
('statewide', 'infrastructure', 'Roads / Infrastructure', 'growth', 55),
('statewide', 'religious_liberty', 'Religious Liberty', 'values', 70),
('statewide', 'pro_life', 'Pro-Life / Abortion', 'values', 72),
('statewide', 'gun_rights', 'Second Amendment / Gun Rights', 'values', 78)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PART 5: UNIFIED MATCHING ENGINE
-- ============================================================================

-- Donor-Candidate Issue Match Score
CREATE OR REPLACE FUNCTION calculate_issue_match(
    p_donor_id BIGINT,
    p_candidate_id UUID
) RETURNS DECIMAL(5,2) AS $$
DECLARE
    v_donor RECORD;
    v_candidate RECORD;
    v_match_score DECIMAL := 0;
    v_issue_count INT := 0;
BEGIN
    -- Get donor local profile
    SELECT * INTO v_donor FROM local_donor_profile WHERE donor_id = p_donor_id;
    
    -- Get candidate questionnaire
    SELECT * INTO v_candidate FROM local_candidate_questionnaire WHERE candidate_id = p_candidate_id;
    
    IF v_donor IS NULL OR v_candidate IS NULL THEN
        RETURN 50; -- Default neutral
    END IF;
    
    -- Compare each issue (donor priority vs candidate position)
    -- Crime & Safety
    IF v_donor.priority_crime_safety IS NOT NULL AND v_candidate.q_pos_local_crime IS NOT NULL THEN
        -- High donor priority + high candidate conservative position = good match
        v_match_score := v_match_score + (
            (v_donor.priority_crime_safety::DECIMAL / 10) * 
            (v_candidate.q_pos_local_crime::DECIMAL / 10) * 100
        );
        v_issue_count := v_issue_count + 1;
    END IF;
    
    -- Schools
    IF v_donor.priority_school_curriculum IS NOT NULL AND v_candidate.q_pos_local_schools IS NOT NULL THEN
        v_match_score := v_match_score + (
            (v_donor.priority_school_curriculum::DECIMAL / 10) * 
            (v_candidate.q_pos_local_schools::DECIMAL / 10) * 100
        );
        v_issue_count := v_issue_count + 1;
    END IF;
    
    -- Taxes
    IF v_donor.priority_property_taxes IS NOT NULL AND v_candidate.q_pos_local_property_tax IS NOT NULL THEN
        v_match_score := v_match_score + (
            (v_donor.priority_property_taxes::DECIMAL / 10) * 
            (v_candidate.q_pos_local_property_tax::DECIMAL / 10) * 100
        );
        v_issue_count := v_issue_count + 1;
    END IF;
    
    -- Growth
    IF v_donor.priority_zoning_development IS NOT NULL AND v_candidate.q_pos_local_growth IS NOT NULL THEN
        v_match_score := v_match_score + (
            (v_donor.priority_zoning_development::DECIMAL / 10) * 
            (v_candidate.q_pos_local_growth::DECIMAL / 10) * 100
        );
        v_issue_count := v_issue_count + 1;
    END IF;
    
    -- Gun Rights
    IF v_donor.priority_gun_rights IS NOT NULL AND v_candidate.q_pos_guns IS NOT NULL THEN
        v_match_score := v_match_score + (
            (v_donor.priority_gun_rights::DECIMAL / 10) * 
            (v_candidate.q_pos_guns::DECIMAL / 10) * 100
        );
        v_issue_count := v_issue_count + 1;
    END IF;
    
    -- Pro-Life
    IF v_donor.priority_pro_life_local IS NOT NULL AND v_candidate.q_pos_abortion IS NOT NULL THEN
        v_match_score := v_match_score + (
            (v_donor.priority_pro_life_local::DECIMAL / 10) * 
            (v_candidate.q_pos_abortion::DECIMAL / 10) * 100
        );
        v_issue_count := v_issue_count + 1;
    END IF;
    
    IF v_issue_count > 0 THEN
        RETURN ROUND(v_match_score / v_issue_count, 2);
    ELSE
        RETURN 50;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Volunteer-Candidate Priority Match
CREATE OR REPLACE FUNCTION calculate_volunteer_candidate_match(
    p_volunteer_id UUID,
    p_candidate_id UUID
) RETURNS TABLE (
    total_score DECIMAL(5,2),
    issue_match DECIMAL(5,2),
    office_pref_match DECIMAL(5,2),
    geographic_match DECIMAL(5,2),
    availability_score DECIMAL(5,2),
    faction_match DECIMAL(5,2)
) AS $$
DECLARE
    v_vol RECORD;
    v_cand RECORD;
    v_quest RECORD;
    v_issue DECIMAL := 50;
    v_office DECIMAL := 50;
    v_geo DECIMAL := 50;
    v_avail DECIMAL := 50;
    v_faction DECIMAL := 50;
BEGIN
    SELECT * INTO v_vol FROM local_volunteer_profile WHERE volunteer_id = p_volunteer_id;
    SELECT * INTO v_cand FROM local_candidates WHERE id = p_candidate_id;
    SELECT * INTO v_quest FROM local_candidate_questionnaire WHERE candidate_id = p_candidate_id;
    
    IF v_vol IS NULL OR v_cand IS NULL THEN
        RETURN QUERY SELECT 0::DECIMAL, 0::DECIMAL, 0::DECIMAL, 0::DECIMAL, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Issue Match (compare priorities)
    v_issue := (
        CASE WHEN v_vol.priority_crime_safety > 7 AND v_cand.office_type = 'SHERIFF' THEN 20 ELSE 0 END +
        CASE WHEN v_vol.priority_school_curriculum > 7 AND v_cand.office_type = 'SCHBRD' THEN 20 ELSE 0 END +
        CASE WHEN v_vol.priority_property_taxes > 7 AND v_cand.office_type IN ('COMMISH', 'COUNCIL') THEN 20 ELSE 0 END +
        50
    );
    v_issue := LEAST(v_issue, 100);
    
    -- Office Type Preference Match
    v_office := CASE v_cand.office_type
        WHEN 'SHERIFF' THEN v_vol.pref_sheriff_races * 10
        WHEN 'SCHBRD' THEN v_vol.pref_school_board_races * 10
        WHEN 'COMMISH' THEN v_vol.pref_commissioner_races * 10
        WHEN 'DA' THEN v_vol.pref_da_judge_races * 10
        WHEN 'JUDGE_SUP' THEN v_vol.pref_da_judge_races * 10
        WHEN 'JUDGE_DIST' THEN v_vol.pref_da_judge_races * 10
        WHEN 'MAYOR' THEN v_vol.pref_municipal_races * 10
        WHEN 'COUNCIL' THEN v_vol.pref_municipal_races * 10
        ELSE 50
    END;
    
    -- Geographic Match
    IF v_vol.county_name = v_cand.county_name THEN
        v_geo := 100;
    ELSE
        v_geo := 30;
    END IF;
    
    -- Availability Score
    v_avail := LEAST(v_vol.hours_per_week_available * 10, 100);
    
    -- Faction Match
    IF v_vol.preferred_candidate_faction IS NOT NULL AND v_cand.primary_faction IS NOT NULL THEN
        SELECT COALESCE(affinity_score, 50) INTO v_faction
        FROM faction_affinity_matrix
        WHERE donor_faction = v_vol.preferred_candidate_faction
        AND candidate_type = v_cand.primary_faction;
    END IF;
    
    RETURN QUERY SELECT 
        ROUND((v_issue * 0.25 + v_office * 0.25 + v_geo * 0.20 + v_avail * 0.15 + v_faction * 0.15), 2),
        v_issue,
        v_office,
        v_geo,
        v_avail,
        v_faction;
END;
$$ LANGUAGE plpgsql STABLE;
