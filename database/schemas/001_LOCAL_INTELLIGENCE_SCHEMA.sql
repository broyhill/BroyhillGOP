-- ============================================================================
-- BROYHILLGOP LOCAL CANDIDATE INTELLIGENCE SYSTEM
-- Complete Database Schema - Mirrors Main Ecosystem with Local Focus
-- November 28, 2025
-- ============================================================================
-- 
-- REPLICATES EXACTLY from main donor ecosystem:
--   • 21-tier grading (A+ to U-)
--   • 1,000-point lead scoring (7 components)
--   • 12-faction classification system
--   • 6-dimension affinity matching
--   • News intelligence triggers
--   • Campaign automation integration
--
-- ADDS LOCAL-SPECIFIC:
--   • Office-type weighted scoring (sheriff vs school board vs commissioner)
--   • Neighborhood/precinct priority mapping
--   • Local news monitoring (county papers, local TV)
--   • Municipal issue tracking
--   • Hyperlocal donor-candidate matching
--
-- ============================================================================

-- ============================================================================
-- PART 1: LOCAL OFFICE CLASSIFICATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_office_types (
    code VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    jurisdiction_level VARCHAR(20) NOT NULL, -- 'county', 'municipal', 'district', 'multi_county'
    partisan BOOLEAN DEFAULT TRUE,
    term_years INT DEFAULT 4,
    avg_budget_needed NUMERIC(10,2),
    voters_per_race INT,
    typical_donors_needed INT,
    key_issues JSONB DEFAULT '[]'::jsonb,
    display_order INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO local_office_types (code, name, jurisdiction_level, partisan, term_years, avg_budget_needed, voters_per_race, typical_donors_needed, key_issues, display_order) VALUES
('SHERIFF', 'Sheriff', 'county', TRUE, 4, 150000, 50000, 500, '["public_safety", "drugs", "immigration", "budget", "2a_rights"]', 1),
('COMMISH', 'County Commissioner', 'county', TRUE, 4, 75000, 30000, 300, '["taxes", "development", "budget", "services", "growth"]', 2),
('SCHBRD', 'School Board', 'county', FALSE, 4, 25000, 25000, 150, '["curriculum", "parental_rights", "budget", "teachers", "safety"]', 3),
('CLERK', 'Clerk of Court', 'county', TRUE, 4, 50000, 50000, 200, '["efficiency", "technology", "access", "records"]', 4),
('REGISTER', 'Register of Deeds', 'county', TRUE, 4, 40000, 50000, 150, '["property_rights", "technology", "fees", "service"]', 5),
('DA', 'District Attorney', 'multi_county', TRUE, 4, 200000, 100000, 600, '["crime", "prosecution", "justice", "victims", "drugs"]', 6),
('JUDGE_SUP', 'Superior Court Judge', 'district', TRUE, 8, 125000, 75000, 400, '["justice", "constitution", "experience", "integrity"]', 7),
('JUDGE_DIST', 'District Court Judge', 'district', TRUE, 4, 100000, 50000, 350, '["fairness", "family", "efficiency", "community"]', 8),
('MAYOR', 'Mayor', 'municipal', TRUE, 4, 50000, 15000, 200, '["growth", "safety", "taxes", "infrastructure", "jobs"]', 9),
('COUNCIL', 'City/Town Council', 'municipal', TRUE, 4, 15000, 5000, 75, '["zoning", "taxes", "services", "development", "safety"]', 10),
('CC_TRUSTEE', 'Community College Trustee', 'county', FALSE, 4, 10000, 50000, 50, '["workforce", "tuition", "programs", "community"]', 11),
('SOIL_WATER', 'Soil & Water Conservation', 'county', FALSE, 4, 5000, 50000, 25, '["conservation", "agriculture", "environment", "rural"]', 12)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    avg_budget_needed = EXCLUDED.avg_budget_needed,
    key_issues = EXCLUDED.key_issues;

-- ============================================================================
-- PART 2: FACTION WEIGHTS BY OFFICE TYPE
-- Different offices prioritize different factions
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_faction_office_weights (
    office_type VARCHAR(10) NOT NULL REFERENCES local_office_types(code),
    faction_code VARCHAR(4) NOT NULL REFERENCES faction_types(code),
    weight_multiplier DECIMAL(3,2) NOT NULL DEFAULT 1.00,
    rationale TEXT,
    PRIMARY KEY (office_type, faction_code)
);

-- SHERIFF: Law & Order dominates
INSERT INTO local_faction_office_weights VALUES
('SHERIFF', 'LAWS', 2.00, 'Law & Order paramount for sheriff'),
('SHERIFF', 'MAGA', 1.50, 'Constitutional sheriff movement'),
('SHERIFF', 'VETS', 1.40, 'Veterans engaged in public safety'),
('SHERIFF', 'RUAL', 1.35, 'Rural counties depend on sheriff'),
('SHERIFF', 'CHNA', 1.25, 'Christian nationalist sheriff support'),
('SHERIFF', 'TRAD', 1.20, 'Traditional law enforcement support'),
('SHERIFF', 'POPF', 1.15, 'Anti-establishment sheriff appeal'),
('SHERIFF', 'EVAN', 1.10, 'Evangelical law/order values'),
('SHERIFF', 'LIBT', 0.90, 'Libertarians mixed on enforcement'),
('SHERIFF', 'FISC', 0.85, 'Fiscal less engaged'),
('SHERIFF', 'BUSI', 0.80, 'Business less engaged'),
('SHERIFF', 'MODG', 0.70, 'Moderates less local engagement');

-- SCHOOL BOARD: Evangelical/Christian Nationalist dominate
INSERT INTO local_faction_office_weights VALUES
('SCHBRD', 'EVAN', 2.00, 'Parental rights top priority'),
('SCHBRD', 'CHNA', 1.90, 'Culture war battleground'),
('SCHBRD', 'MAGA', 1.65, 'Anti-woke education movement'),
('SCHBRD', 'POPF', 1.45, 'Anti-establishment education'),
('SCHBRD', 'TRAD', 1.30, 'Traditional education values'),
('SCHBRD', 'RUAL', 1.25, 'Rural school priorities'),
('SCHBRD', 'FISC', 1.15, 'School budget concerns'),
('SCHBRD', 'LIBT', 1.05, 'School choice support'),
('SCHBRD', 'VETS', 0.95, 'Veteran education interest'),
('SCHBRD', 'LAWS', 0.85, 'School safety interest'),
('SCHBRD', 'BUSI', 0.80, 'Workforce development'),
('SCHBRD', 'MODG', 0.60, 'Moderates less energized');

-- COUNTY COMMISSIONER: Fiscal/Business/Rural dominate
INSERT INTO local_faction_office_weights VALUES
('COMMISH', 'FISC', 1.85, 'County budget primary concern'),
('COMMISH', 'BUSI', 1.75, 'Economic development, permits'),
('COMMISH', 'RUAL', 1.65, 'Land use, agriculture, services'),
('COMMISH', 'TRAD', 1.50, 'Traditional governance'),
('COMMISH', 'LAWS', 1.35, 'Sheriff funding, public safety'),
('COMMISH', 'MAGA', 1.25, 'County-level MAGA engagement'),
('COMMISH', 'LIBT', 1.20, 'Property rights, limited govt'),
('COMMISH', 'POPF', 1.15, 'Anti-establishment commissioners'),
('COMMISH', 'EVAN', 1.05, 'Values-based governance'),
('COMMISH', 'VETS', 1.00, 'Veteran services'),
('COMMISH', 'CHNA', 0.95, 'Less direct relevance'),
('COMMISH', 'MODG', 0.85, 'Moderate local engagement');

-- DISTRICT ATTORNEY: Law & Order + Traditional dominate
INSERT INTO local_faction_office_weights VALUES
('DA', 'LAWS', 2.00, 'Prosecution is law enforcement'),
('DA', 'TRAD', 1.60, 'Traditional justice approach'),
('DA', 'MAGA', 1.45, 'Tough on crime agenda'),
('DA', 'CHNA', 1.30, 'Moral justice framework'),
('DA', 'VETS', 1.25, 'Veteran prosecutors common'),
('DA', 'EVAN', 1.15, 'Faith-based justice values'),
('DA', 'POPF', 1.10, 'Anti-Soros DA movement'),
('DA', 'RUAL', 1.05, 'Rural prosecution priorities'),
('DA', 'FISC', 0.90, 'Budget less central'),
('DA', 'BUSI', 0.85, 'Business fraud prosecution'),
('DA', 'LIBT', 0.75, 'Libertarians skeptical'),
('DA', 'MODG', 0.70, 'Moderates less engaged');

-- MAYOR: Business/Fiscal/Traditional dominate
INSERT INTO local_faction_office_weights VALUES
('MAYOR', 'BUSI', 1.85, 'Economic development key'),
('MAYOR', 'FISC', 1.75, 'Municipal budget, taxes'),
('MAYOR', 'TRAD', 1.55, 'Traditional city governance'),
('MAYOR', 'LAWS', 1.45, 'Police, public safety'),
('MAYOR', 'MAGA', 1.30, 'Municipal MAGA support'),
('MAYOR', 'RUAL', 1.20, 'Small town mayors'),
('MAYOR', 'POPF', 1.15, 'Anti-establishment mayors'),
('MAYOR', 'VETS', 1.10, 'Veteran leadership'),
('MAYOR', 'EVAN', 1.00, 'Faith community support'),
('MAYOR', 'LIBT', 0.95, 'Limited municipal govt'),
('MAYOR', 'CHNA', 0.90, 'Less municipal relevance'),
('MAYOR', 'MODG', 0.85, 'Moderate city voters');

-- CITY COUNCIL: Similar to Mayor
INSERT INTO local_faction_office_weights VALUES
('COUNCIL', 'BUSI', 1.80, 'Zoning, permits, business'),
('COUNCIL', 'FISC', 1.70, 'Local taxes, fees'),
('COUNCIL', 'TRAD', 1.50, 'Traditional governance'),
('COUNCIL', 'LAWS', 1.40, 'Police funding'),
('COUNCIL', 'RUAL', 1.35, 'Small town councils'),
('COUNCIL', 'MAGA', 1.25, 'Local MAGA engagement'),
('COUNCIL', 'POPF', 1.15, 'Anti-establishment'),
('COUNCIL', 'EVAN', 1.05, 'Faith community'),
('COUNCIL', 'VETS', 1.00, 'Veteran service'),
('COUNCIL', 'LIBT', 0.95, 'Limited govt'),
('COUNCIL', 'CHNA', 0.85, 'Less relevance'),
('COUNCIL', 'MODG', 0.90, 'Moderate engagement');

-- JUDGES: Traditional/Law & Order dominate
INSERT INTO local_faction_office_weights VALUES
('JUDGE_SUP', 'TRAD', 1.90, 'Judicial temperament'),
('JUDGE_SUP', 'LAWS', 1.75, 'Law and order judiciary'),
('JUDGE_SUP', 'EVAN', 1.40, 'Faith-based jurisprudence'),
('JUDGE_SUP', 'CHNA', 1.35, 'Constitutional originalism'),
('JUDGE_SUP', 'MAGA', 1.25, 'Trump judicial philosophy'),
('JUDGE_SUP', 'VETS', 1.20, 'Veteran judges respected'),
('JUDGE_SUP', 'FISC', 1.00, 'Less relevant'),
('JUDGE_SUP', 'BUSI', 0.95, 'Business litigation'),
('JUDGE_SUP', 'LIBT', 0.90, 'Constitutional liberty'),
('JUDGE_SUP', 'RUAL', 0.85, 'Rural court service'),
('JUDGE_SUP', 'POPF', 0.75, 'Judicial restraint expected'),
('JUDGE_SUP', 'MODG', 0.80, 'Moderate judicial philosophy');

INSERT INTO local_faction_office_weights VALUES
('JUDGE_DIST', 'TRAD', 1.85, 'Traditional jurisprudence'),
('JUDGE_DIST', 'LAWS', 1.70, 'Criminal court priorities'),
('JUDGE_DIST', 'EVAN', 1.45, 'Family court values'),
('JUDGE_DIST', 'CHNA', 1.30, 'Constitutional values'),
('JUDGE_DIST', 'MAGA', 1.20, 'Conservative judiciary'),
('JUDGE_DIST', 'VETS', 1.15, 'Veterans treatment courts'),
('JUDGE_DIST', 'RUAL', 1.00, 'Rural court access'),
('JUDGE_DIST', 'FISC', 0.90, 'Less relevant'),
('JUDGE_DIST', 'BUSI', 0.85, 'Small claims, contracts'),
('JUDGE_DIST', 'LIBT', 0.80, 'Individual rights'),
('JUDGE_DIST', 'POPF', 0.70, 'Judicial restraint'),
('JUDGE_DIST', 'MODG', 0.85, 'Balanced approach');

-- CLERK OF COURT: Traditional/Fiscal dominate
INSERT INTO local_faction_office_weights VALUES
('CLERK', 'TRAD', 1.70, 'Administrative competence'),
('CLERK', 'FISC', 1.60, 'Efficient operations'),
('CLERK', 'BUSI', 1.45, 'Customer service focus'),
('CLERK', 'LAWS', 1.30, 'Court system support'),
('CLERK', 'MAGA', 1.10, 'General conservative'),
('CLERK', 'VETS', 1.05, 'Service orientation'),
('CLERK', 'RUAL', 1.00, 'Rural court access'),
('CLERK', 'EVAN', 0.95, 'Less direct relevance'),
('CLERK', 'CHNA', 0.90, 'Less direct relevance'),
('CLERK', 'LIBT', 0.85, 'Efficient government'),
('CLERK', 'POPF', 0.80, 'Less relevant'),
('CLERK', 'MODG', 0.90, 'Competent administration');

-- REGISTER OF DEEDS: Fiscal/Business/Rural dominate
INSERT INTO local_faction_office_weights VALUES
('REGISTER', 'FISC', 1.65, 'Efficient operations'),
('REGISTER', 'BUSI', 1.60, 'Real estate community'),
('REGISTER', 'RUAL', 1.55, 'Property rights, land'),
('REGISTER', 'TRAD', 1.45, 'Administrative competence'),
('REGISTER', 'LIBT', 1.20, 'Property rights focus'),
('REGISTER', 'MAGA', 1.05, 'General conservative'),
('REGISTER', 'VETS', 1.00, 'Service orientation'),
('REGISTER', 'LAWS', 0.95, 'Less direct relevance'),
('REGISTER', 'EVAN', 0.90, 'Less direct relevance'),
('REGISTER', 'CHNA', 0.85, 'Less direct relevance'),
('REGISTER', 'POPF', 0.80, 'Less relevant'),
('REGISTER', 'MODG', 0.95, 'Competent administration');

-- CC TRUSTEE: Business/Fiscal/Rural dominate
INSERT INTO local_faction_office_weights VALUES
('CC_TRUSTEE', 'BUSI', 1.75, 'Workforce development'),
('CC_TRUSTEE', 'FISC', 1.60, 'Tuition, budget'),
('CC_TRUSTEE', 'RUAL', 1.55, 'Community access'),
('CC_TRUSTEE', 'TRAD', 1.40, 'Educational governance'),
('CC_TRUSTEE', 'EVAN', 1.15, 'Values in education'),
('CC_TRUSTEE', 'MAGA', 1.10, 'Conservative education'),
('CC_TRUSTEE', 'VETS', 1.20, 'Veteran education'),
('CC_TRUSTEE', 'CHNA', 1.00, 'Less direct relevance'),
('CC_TRUSTEE', 'LAWS', 0.95, 'Law enforcement training'),
('CC_TRUSTEE', 'LIBT', 0.90, 'Workforce freedom'),
('CC_TRUSTEE', 'POPF', 0.85, 'Less relevant'),
('CC_TRUSTEE', 'MODG', 1.05, 'Bipartisan education');

-- SOIL & WATER: Rural dominates
INSERT INTO local_faction_office_weights VALUES
('SOIL_WATER', 'RUAL', 2.00, 'Agriculture primary'),
('SOIL_WATER', 'BUSI', 1.40, 'Agricultural business'),
('SOIL_WATER', 'TRAD', 1.35, 'Conservation tradition'),
('SOIL_WATER', 'FISC', 1.20, 'Budget stewardship'),
('SOIL_WATER', 'LIBT', 1.10, 'Property rights'),
('SOIL_WATER', 'MAGA', 1.05, 'Rural MAGA'),
('SOIL_WATER', 'EVAN', 0.95, 'Stewardship values'),
('SOIL_WATER', 'VETS', 0.90, 'Less direct relevance'),
('SOIL_WATER', 'LAWS', 0.85, 'Less direct relevance'),
('SOIL_WATER', 'CHNA', 0.80, 'Less direct relevance'),
('SOIL_WATER', 'POPF', 0.75, 'Less direct relevance'),
('SOIL_WATER', 'MODG', 0.90, 'Environmental balance');

-- ============================================================================
-- PART 3: LOCAL CANDIDATE TABLE (150+ core fields)
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- === BASIC IDENTITY (20 fields) ===
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    suffix VARCHAR(20),
    nickname VARCHAR(50),
    full_name VARCHAR(255) GENERATED ALWAYS AS (
        TRIM(CONCAT(first_name, ' ', COALESCE(middle_name, ''), ' ', last_name, 
        CASE WHEN suffix IS NOT NULL THEN CONCAT(', ', suffix) ELSE '' END))
    ) STORED,
    
    -- === CONTACT (15 fields) ===
    email VARCHAR(255),
    email_alt VARCHAR(255),
    phone_mobile VARCHAR(20),
    phone_home VARCHAR(20),
    phone_work VARCHAR(20),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_zip VARCHAR(10),
    county_fips VARCHAR(5) NOT NULL,
    county_name VARCHAR(50) NOT NULL,
    precinct_id VARCHAR(20),
    precinct_name VARCHAR(100),
    congressional_district VARCHAR(5),
    state_senate_district VARCHAR(5),
    state_house_district VARCHAR(5),
    
    -- === OFFICE SOUGHT (12 fields) ===
    office_type VARCHAR(10) NOT NULL REFERENCES local_office_types(code),
    office_id UUID,
    seat_sought VARCHAR(50),
    district_name VARCHAR(100),
    election_year INT NOT NULL,
    election_type VARCHAR(20) DEFAULT 'general', -- 'primary', 'general', 'special', 'runoff'
    is_incumbent BOOLEAN DEFAULT FALSE,
    incumbent_since DATE,
    previous_terms INT DEFAULT 0,
    filing_date DATE,
    sboe_id VARCHAR(50),
    fec_id VARCHAR(50),
    
    -- === PROFESSIONAL BACKGROUND (15 fields) ===
    occupation VARCHAR(200),
    occupation_category VARCHAR(50),
    employer VARCHAR(200),
    employer_industry VARCHAR(100),
    years_in_occupation INT,
    is_business_owner BOOLEAN DEFAULT FALSE,
    business_name VARCHAR(200),
    business_type VARCHAR(100),
    business_employees INT,
    professional_licenses JSONB DEFAULT '[]'::jsonb,
    board_positions JSONB DEFAULT '[]'::jsonb,
    linkedin_url VARCHAR(500),
    years_in_county INT,
    years_in_district INT,
    nc_native BOOLEAN DEFAULT FALSE,
    
    -- === EDUCATION (12 fields) ===
    education_level VARCHAR(50),
    high_school VARCHAR(200),
    high_school_year INT,
    undergrad_school VARCHAR(200),
    undergrad_degree VARCHAR(100),
    undergrad_year INT,
    grad_school VARCHAR(200),
    grad_degree VARCHAR(100),
    grad_year INT,
    law_school VARCHAR(200),
    bar_admission_year INT,
    certifications JSONB DEFAULT '[]'::jsonb,
    
    -- === MILITARY (10 fields) ===
    military_veteran BOOLEAN DEFAULT FALSE,
    military_branch VARCHAR(50),
    military_rank VARCHAR(50),
    military_years INT,
    military_dates VARCHAR(100),
    combat_veteran BOOLEAN DEFAULT FALSE,
    military_awards JSONB DEFAULT '[]'::jsonb,
    veteran_organizations JSONB DEFAULT '[]'::jsonb,
    military_retired BOOLEAN DEFAULT FALSE,
    military_discharge VARCHAR(50),
    
    -- === FAITH (8 fields) ===
    religion VARCHAR(100),
    denomination VARCHAR(100),
    church_name VARCHAR(200),
    church_city VARCHAR(100),
    years_at_church INT,
    church_leadership BOOLEAN DEFAULT FALSE,
    church_role VARCHAR(200),
    faith_testimony_available BOOLEAN DEFAULT FALSE,
    
    -- === FAMILY (8 fields) ===
    marital_status VARCHAR(50),
    spouse_name VARCHAR(200),
    years_married INT,
    spouse_occupation VARCHAR(200),
    has_children BOOLEAN DEFAULT FALSE,
    num_children INT DEFAULT 0,
    children_in_public_school BOOLEAN,
    children_names JSONB DEFAULT '[]'::jsonb,
    
    -- === 12 FACTION INTENSITY SCORES (0-100 each) ===
    score_maga DECIMAL(5,2) DEFAULT 0,
    score_evan DECIMAL(5,2) DEFAULT 0,
    score_trad DECIMAL(5,2) DEFAULT 0,
    score_fisc DECIMAL(5,2) DEFAULT 0,
    score_libt DECIMAL(5,2) DEFAULT 0,
    score_busi DECIMAL(5,2) DEFAULT 0,
    score_laws DECIMAL(5,2) DEFAULT 0,
    score_popf DECIMAL(5,2) DEFAULT 0,
    score_modg DECIMAL(5,2) DEFAULT 0,
    score_vets DECIMAL(5,2) DEFAULT 0,
    score_chna DECIMAL(5,2) DEFAULT 0,
    score_rual DECIMAL(5,2) DEFAULT 0,
    primary_faction VARCHAR(4) REFERENCES faction_types(code),
    secondary_faction VARCHAR(4) REFERENCES faction_types(code),
    tertiary_faction VARCHAR(4) REFERENCES faction_types(code),
    
    -- === ISSUE POSITIONS (1-10 scale) ===
    position_abortion SMALLINT CHECK (position_abortion BETWEEN 1 AND 10),
    position_guns SMALLINT CHECK (position_guns BETWEEN 1 AND 10),
    position_taxes SMALLINT CHECK (position_taxes BETWEEN 1 AND 10),
    position_immigration SMALLINT CHECK (position_immigration BETWEEN 1 AND 10),
    position_education SMALLINT CHECK (position_education BETWEEN 1 AND 10),
    position_crime SMALLINT CHECK (position_crime BETWEEN 1 AND 10),
    position_trump_support SMALLINT CHECK (position_trump_support BETWEEN 1 AND 10),
    position_environment SMALLINT CHECK (position_environment BETWEEN 1 AND 10),
    position_healthcare SMALLINT CHECK (position_healthcare BETWEEN 1 AND 10),
    position_spending SMALLINT CHECK (position_spending BETWEEN 1 AND 10),
    priority_issues JSONB DEFAULT '[]'::jsonb,
    
    -- === CAMPAIGN INFO (15 fields) ===
    campaign_committee VARCHAR(200),
    treasurer_name VARCHAR(200),
    campaign_website VARCHAR(500),
    campaign_email VARCHAR(255),
    campaign_phone VARCHAR(20),
    campaign_slogan VARCHAR(255),
    campaign_themes JSONB DEFAULT '[]'::jsonb,
    fundraising_goal NUMERIC(12,2),
    amount_raised NUMERIC(12,2) DEFAULT 0,
    cash_on_hand NUMERIC(12,2) DEFAULT 0,
    donor_count INT DEFAULT 0,
    avg_donation NUMERIC(10,2),
    campaign_manager VARCHAR(200),
    campaign_consultant VARCHAR(200),
    campaign_status VARCHAR(20) DEFAULT 'potential',
    
    -- === SOCIAL MEDIA (8 fields) ===
    facebook_personal VARCHAR(500),
    facebook_campaign VARCHAR(500),
    twitter_handle VARCHAR(100),
    instagram_handle VARCHAR(100),
    youtube_channel VARCHAR(500),
    tiktok_handle VARCHAR(100),
    truth_social_handle VARCHAR(100),
    social_followers_total INT DEFAULT 0,
    
    -- === ENDORSEMENTS (5 fields) ===
    trump_endorsement BOOLEAN DEFAULT FALSE,
    trump_endorsement_date DATE,
    nra_grade VARCHAR(5),
    pro_life_grade VARCHAR(5),
    endorsements_received JSONB DEFAULT '[]'::jsonb,
    
    -- === BIOS (5 fields) ===
    bio_short TEXT,
    bio_medium TEXT,
    bio_full TEXT,
    stump_speech_themes JSONB DEFAULT '[]'::jsonb,
    key_accomplishments JSONB DEFAULT '[]'::jsonb,
    
    -- === MEDIA ASSETS (4 fields) ===
    headshot_url VARCHAR(500),
    campaign_photo_url VARCHAR(500),
    logo_url VARCHAR(500),
    video_intro_url VARCHAR(500),
    
    -- === STATUS & METADATA (10 fields) ===
    status VARCHAR(20) DEFAULT 'potential',
    profile_completeness INT DEFAULT 0,
    last_contact_date DATE,
    last_updated_by VARCHAR(100),
    data_sources JSONB DEFAULT '[]'::jsonb,
    ai_confidence_score DECIMAL(3,2) DEFAULT 0.50,
    approved_by_candidate BOOLEAN DEFAULT FALSE,
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    
    -- === CONSTRAINTS ===
    CONSTRAINT valid_election_year CHECK (election_year >= 2024 AND election_year <= 2040),
    CONSTRAINT valid_status CHECK (status IN ('potential', 'exploring', 'filed', 'active', 'elected', 'lost', 'withdrawn', 'deceased'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_local_cand_county ON local_candidates(county_fips);
CREATE INDEX IF NOT EXISTS idx_local_cand_office ON local_candidates(office_type);
CREATE INDEX IF NOT EXISTS idx_local_cand_year ON local_candidates(election_year);
CREATE INDEX IF NOT EXISTS idx_local_cand_status ON local_candidates(status);
CREATE INDEX IF NOT EXISTS idx_local_cand_faction ON local_candidates(primary_faction);
CREATE INDEX IF NOT EXISTS idx_local_cand_county_office ON local_candidates(county_fips, office_type);
CREATE INDEX IF NOT EXISTS idx_local_cand_name ON local_candidates(last_name, first_name);

-- ============================================================================
-- PART 4: LOCAL CANDIDATE 21-TIER GRADING (mirrors donor system)
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_candidate_grades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL REFERENCES local_candidates(id) ON DELETE CASCADE,
    
    -- 21-Tier Grade (A+ to U-)
    current_grade VARCHAR(2) NOT NULL,
    grade_numeric INT NOT NULL CHECK (grade_numeric BETWEEN 1 AND 21),
    
    -- Grade by scope
    grade_county VARCHAR(2),
    grade_district VARCHAR(2),
    grade_statewide VARCHAR(2),
    
    -- Grade components (each 0-100)
    component_electability INT DEFAULT 0,
    component_fundraising INT DEFAULT 0,
    component_profile_complete INT DEFAULT 0,
    component_endorsements INT DEFAULT 0,
    component_experience INT DEFAULT 0,
    component_faction_fit INT DEFAULT 0,
    component_local_presence INT DEFAULT 0,
    
    -- Percentile rank
    percentile_county DECIMAL(5,2),
    percentile_office_type DECIMAL(5,2),
    percentile_statewide DECIMAL(5,2),
    
    -- History
    grade_history JSONB DEFAULT '[]'::jsonb,
    previous_grade VARCHAR(2),
    grade_trend VARCHAR(10), -- 'improving', 'stable', 'declining'
    
    -- Metadata
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    calculation_version VARCHAR(10) DEFAULT '1.0',
    
    CONSTRAINT unique_candidate_grade UNIQUE (candidate_id)
);

-- ============================================================================
-- PART 5: LOCAL CANDIDATE 1000-POINT SCORING (mirrors donor system)
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_candidate_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL REFERENCES local_candidates(id) ON DELETE CASCADE,
    
    -- Total Score (0-1000)
    total_score INT NOT NULL DEFAULT 0 CHECK (total_score BETWEEN 0 AND 1000),
    
    -- 7 Component Scores (mirrors donor system)
    -- Component 1: Electability Potential (0-300 pts)
    score_electability INT DEFAULT 0 CHECK (score_electability BETWEEN 0 AND 300),
    
    -- Component 2: Fundraising Capacity (0-200 pts)
    score_fundraising INT DEFAULT 0 CHECK (score_fundraising BETWEEN 0 AND 200),
    
    -- Component 3: Profile Completeness (0-150 pts)
    score_profile INT DEFAULT 0 CHECK (score_profile BETWEEN 0 AND 150),
    
    -- Component 4: Endorsement Strength (0-150 pts)
    score_endorsements INT DEFAULT 0 CHECK (score_endorsements BETWEEN 0 AND 150),
    
    -- Component 5: Experience/Background (0-100 pts)
    score_experience INT DEFAULT 0 CHECK (score_experience BETWEEN 0 AND 100),
    
    -- Component 6: Local Engagement (0-50 pts)
    score_local_engagement INT DEFAULT 0 CHECK (score_local_engagement BETWEEN 0 AND 50),
    
    -- Component 7: Network/Influence (0-50 pts)
    score_network INT DEFAULT 0 CHECK (score_network BETWEEN 0 AND 50),
    
    -- Office-weighted total (applies faction weights for office type)
    weighted_total INT DEFAULT 0,
    weight_multiplier_used DECIMAL(4,2) DEFAULT 1.00,
    
    -- Score history
    score_history JSONB DEFAULT '[]'::jsonb,
    previous_score INT,
    score_trend VARCHAR(10),
    
    -- Metadata
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    calculation_version VARCHAR(10) DEFAULT '1.0',
    
    CONSTRAINT unique_candidate_score UNIQUE (candidate_id)
);

-- ============================================================================
-- PART 6: DONOR-LOCAL CANDIDATE AFFINITY (6-dimension matching)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_local_candidate_affinity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id BIGINT NOT NULL,
    candidate_id UUID NOT NULL REFERENCES local_candidates(id) ON DELETE CASCADE,
    
    -- 6-Dimension Scores (0-100 each)
    score_geographic DECIMAL(5,2) DEFAULT 0,
    score_professional DECIMAL(5,2) DEFAULT 0,
    score_educational DECIMAL(5,2) DEFAULT 0,
    score_military DECIMAL(5,2) DEFAULT 0,
    score_faith DECIMAL(5,2) DEFAULT 0,
    score_issues DECIMAL(5,2) DEFAULT 0,
    
    -- Faction Affinity (from matrix)
    faction_affinity_score DECIMAL(5,2) DEFAULT 0,
    
    -- Personal Connection Affinity
    personal_affinity_score DECIMAL(5,2) DEFAULT 0,
    
    -- Office-Weighted Combined Score
    -- Formula: (faction * 0.45 + personal * 0.35 + local_bonus * 0.20) * office_weight
    combined_score DECIMAL(5,2) DEFAULT 0,
    office_weight_applied DECIMAL(4,2) DEFAULT 1.00,
    
    -- Local Bonus Factors
    same_county BOOLEAN DEFAULT FALSE,
    same_precinct BOOLEAN DEFAULT FALSE,
    same_municipality BOOLEAN DEFAULT FALSE,
    local_bonus_score DECIMAL(5,2) DEFAULT 0,
    
    -- Match Details
    matching_factors JSONB DEFAULT '[]'::jsonb,
    dimension_breakdown JSONB DEFAULT '{}'::jsonb,
    
    -- Classification
    match_grade VARCHAR(2),
    match_quality VARCHAR(15) CHECK (match_quality IN ('EXCEPTIONAL', 'STRONG', 'GOOD', 'FAIR', 'WEAK')),
    solicitation_priority INT CHECK (solicitation_priority BETWEEN 1 AND 5),
    
    -- Recommendations
    is_recommended BOOLEAN DEFAULT FALSE,
    recommendation_rank INT,
    recommendation_reason TEXT,
    
    -- Predictions
    predicted_donation NUMERIC(10,2),
    donation_probability DECIMAL(5,2),
    optimal_ask_amount NUMERIC(10,2),
    
    -- Donor local giving history
    has_donated_local BOOLEAN DEFAULT FALSE,
    local_giving_total NUMERIC(12,2) DEFAULT 0,
    local_giving_count INT DEFAULT 0,
    
    -- Metadata
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cache_valid_until TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days'),
    
    CONSTRAINT unique_donor_local_cand UNIQUE (donor_id, candidate_id)
);

-- Indexes for affinity queries
CREATE INDEX IF NOT EXISTS idx_dlca_combined ON donor_local_candidate_affinity(combined_score DESC);
CREATE INDEX IF NOT EXISTS idx_dlca_candidate ON donor_local_candidate_affinity(candidate_id, combined_score DESC);
CREATE INDEX IF NOT EXISTS idx_dlca_donor ON donor_local_candidate_affinity(donor_id);
CREATE INDEX IF NOT EXISTS idx_dlca_quality ON donor_local_candidate_affinity(match_quality);
CREATE INDEX IF NOT EXISTS idx_dlca_recommended ON donor_local_candidate_affinity(is_recommended) WHERE is_recommended = TRUE;
CREATE INDEX IF NOT EXISTS idx_dlca_local ON donor_local_candidate_affinity(same_county, same_precinct);
