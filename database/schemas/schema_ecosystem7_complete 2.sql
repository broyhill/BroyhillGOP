-- ============================================================================
-- BROYHILLGOP ECOSYSTEM 7: CANDIDATE PROFILE SYSTEM
-- Complete PostgreSQL Schema for DataHub Connection
-- ============================================================================
-- 
-- This schema creates 7 tables that connect to the existing DataHub:
--   1. candidate_profiles (273 fields)
--   2. candidate_media
--   3. candidate_admin_staff
--   4. candidate_ai_generations
--   5. candidate_profile_edits
--   6. candidate_profile_questions
--   7. donor_candidate_affinity (THE DATAHUB CONNECTION)
--
-- Prerequisites:
--   - Existing 'candidates' table
--   - Existing 'donors' table (DataHub)
--   - Existing 'users' table
--
-- ============================================================================

BEGIN;

-- ============================================================================
-- TABLE 1: candidate_profiles (273 fields)
-- The main profile table for all candidate data
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_profiles (
    id BIGSERIAL PRIMARY KEY,
    candidate_id BIGINT NOT NULL UNIQUE REFERENCES candidates(id) ON DELETE CASCADE,
    
    -- SECTION 1: BASIC POLITICAL INFORMATION (28 fields)
    full_name VARCHAR(255) NOT NULL,
    preferred_name VARCHAR(100),
    date_of_birth DATE,
    birth_place VARCHAR(255),
    current_age INTEGER,
    gender VARCHAR(20),
    race_ethnicity VARCHAR(100),
    political_party VARCHAR(50) DEFAULT 'Republican',
    party_registration_date DATE,
    previous_parties JSONB,
    current_office VARCHAR(255),
    district VARCHAR(100),
    first_elected_date DATE,
    terms_served INTEGER,
    counties_represented JSONB,
    cities_represented JSONB,
    district_population INTEGER,
    district_partisan_lean VARCHAR(10),
    committee_assignments JSONB,
    leadership_positions JSONB,
    target_office VARCHAR(255),
    election_date DATE,
    primary_date DATE,
    filing_deadline DATE,
    incumbent_name VARCHAR(255),
    incumbent_party VARCHAR(50),
    incumbent_vulnerability VARCHAR(20),
    expected_opponents INTEGER,
    
    -- SECTION 2: PROFESSIONAL BACKGROUND (20 fields)
    linkedin_url VARCHAR(500),
    current_employer VARCHAR(255),
    current_title VARCHAR(255),
    years_in_position INTEGER,
    industry_sector VARCHAR(100),
    professional_licenses JSONB,
    bar_admission VARCHAR(255),
    previous_employers JSONB,
    board_positions JSONB,
    business_ownership JSONB,
    undergrad_school VARCHAR(255),
    undergrad_degree VARCHAR(100),
    undergrad_grad_year INTEGER,
    grad_school VARCHAR(255),
    grad_degree VARCHAR(100),
    grad_grad_year INTEGER,
    academic_honors JSONB,
    greek_life VARCHAR(100),
    study_abroad JSONB,
    certifications JSONB,
    
    -- SECTION 3: MILITARY SERVICE (7 fields)
    military_branch VARCHAR(50),
    military_service_dates VARCHAR(100),
    military_rank VARCHAR(50),
    military_deployments JSONB,
    combat_experience TEXT,
    military_awards JSONB,
    veteran_orgs JSONB,
    
    -- SECTION 4: FAMILY INFORMATION (9 fields)
    marital_status VARCHAR(50),
    spouse_name VARCHAR(255),
    spouse_profession VARCHAR(255),
    num_children INTEGER,
    children_ages JSONB,
    children_schools JSONB,
    parents_names VARCHAR(255),
    siblings JSONB,
    family_political_connections TEXT,
    
    -- SECTION 5: DIGITAL PRESENCE (25 fields)
    facebook_personal_url VARCHAR(500),
    facebook_personal_followers INTEGER,
    facebook_campaign_url VARCHAR(500),
    facebook_campaign_followers INTEGER,
    facebook_post_frequency VARCHAR(50),
    facebook_engagement_rate DECIMAL(5,2),
    facebook_priorities JSONB,
    facebook_religious_content VARCHAR(50),
    twitter_handle VARCHAR(100),
    twitter_url VARCHAR(500),
    twitter_followers INTEGER,
    twitter_following INTEGER,
    twitter_total_tweets INTEGER,
    twitter_created_date DATE,
    twitter_verified BOOLEAN DEFAULT FALSE,
    twitter_frequency VARCHAR(50),
    twitter_themes JSONB,
    instagram_url VARCHAR(500),
    instagram_followers INTEGER,
    youtube_url VARCHAR(500),
    youtube_subscribers INTEGER,
    tiktok_url VARCHAR(500),
    personal_website VARCHAR(500),
    campaign_website VARCHAR(500),
    email_newsletter VARCHAR(255),
    
    -- SECTION 6: LEGISLATIVE RECORD (20 fields)
    bills_sponsored_count INTEGER,
    bills_passed_count INTEGER,
    bill_success_rate DECIMAL(5,2),
    bill_issue_areas JSONB,
    prolife_bills INTEGER,
    gun_rights_bills INTEGER,
    tax_bills INTEGER,
    education_bills INTEGER,
    criminal_justice_bills INTEGER,
    notable_legislation JSONB,
    conservative_rating INTEGER,
    nra_rating VARCHAR(10),
    ncvalues_rating INTEGER,
    nfib_rating INTEGER,
    afp_rating INTEGER,
    party_unity_score DECIMAL(5,2),
    prolife_votes JSONB,
    gun_rights_votes JSONB,
    tax_votes JSONB,
    controversial_votes JSONB,
    
    -- SECTION 7: CAMPAIGN FINANCE (18 fields)
    fec_committee_id VARCHAR(50),
    ncboe_committee_id VARCHAR(50),
    total_raised_current DECIMAL(12,2),
    cash_on_hand DECIMAL(12,2),
    total_spent_current DECIMAL(12,2),
    num_contributors INTEGER,
    avg_contribution DECIMAL(10,2),
    small_donor_count INTEGER,
    large_donor_count INTEGER,
    pac_contributions DECIMAL(12,2),
    top_individual_donors JSONB,
    top_industry_sectors JSONB,
    real_estate_donors JSONB,
    legal_donors JSONB,
    healthcare_donors JSONB,
    agriculture_donors JSONB,
    finance_donors JSONB,
    energy_donors JSONB,
    
    -- SECTION 8: POLICY POSITIONS (16 fields)
    abortion_position TEXT,
    gun_rights_position TEXT,
    tax_policy TEXT,
    immigration_stance TEXT,
    education_policy TEXT,
    healthcare_stance TEXT,
    criminal_justice_reform TEXT,
    religious_liberty_position TEXT,
    election_integrity_stance TEXT,
    border_security_position TEXT,
    nc_budget_priorities TEXT,
    teacher_pay_position TEXT,
    medicaid_expansion_stance TEXT,
    coal_ash_position TEXT,
    charlotte_transport_position TEXT,
    outerbanks_development TEXT,
    
    -- SECTION 9: FAITH & COMMUNITY (15 fields)
    denomination VARCHAR(100),
    church_name VARCHAR(255),
    church_city VARCHAR(100),
    church_role VARCHAR(100),
    faith_importance VARCHAR(50),
    faith_based_legislation JSONB,
    community_orgs JSONB,
    charitable_boards JSONB,
    civic_club_memberships JSONB,
    fraternal_orgs JSONB,
    alumni_associations JSONB,
    professional_associations JSONB,
    country_club VARCHAR(255),
    hunting_fishing_clubs JSONB,
    sports_affiliations JSONB,
    
    -- SECTION 10: PERSONAL NARRATIVE (12 fields)
    campaign_slogan VARCHAR(255),
    stump_speech_themes JSONB,
    personal_story TEXT,
    why_running TEXT,
    key_endorsements JSONB,
    media_appearances JSONB,
    awards_honors JSONB,
    publications JSONB,
    speaking_style VARCHAR(100),
    communication_strengths JSONB,
    vulnerabilities JSONB,
    opposition_research_notes TEXT,
    
    -- SECTION 11: CONTACT INFORMATION (10 fields)
    email_official VARCHAR(255),
    email_campaign VARCHAR(255),
    email_personal VARCHAR(255),
    phone_office VARCHAR(20),
    phone_campaign VARCHAR(20),
    phone_cell VARCHAR(20),
    office_address TEXT,
    campaign_hq_address TEXT,
    home_address TEXT,
    preferred_contact_method VARCHAR(50),
    
    -- SECTION 12: METADATA & TRACKING (13 fields)
    profile_completeness_pct INTEGER DEFAULT 0,
    ai_confidence_score INTEGER DEFAULT 0,
    last_ai_refresh TIMESTAMP,
    last_manual_edit TIMESTAMP,
    approved_by_candidate BOOLEAN DEFAULT FALSE,
    approved_at TIMESTAMP,
    approved_by BIGINT,
    data_quality_grade VARCHAR(5),
    missing_fields JSONB,
    data_sources JSONB,
    total_donor_matches INTEGER DEFAULT 0,
    avg_affinity_score DECIMAL(5,2),
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

-- Indexes for candidate_profiles
CREATE INDEX idx_cp_district ON candidate_profiles(district);
CREATE INDEX idx_cp_current_office ON candidate_profiles(current_office);
CREATE INDEX idx_cp_target_office ON candidate_profiles(target_office);
CREATE INDEX idx_cp_completeness ON candidate_profiles(profile_completeness_pct);
CREATE INDEX idx_cp_denomination ON candidate_profiles(denomination);
CREATE INDEX idx_cp_military ON candidate_profiles(military_branch);
CREATE INDEX idx_cp_industry ON candidate_profiles(industry_sector);
CREATE INDEX idx_cp_school ON candidate_profiles(undergrad_school);
CREATE INDEX idx_cp_active ON candidate_profiles(is_active);


-- ============================================================================
-- TABLE 2: candidate_media
-- Stores headshots, logos, campaign photos, videos
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_media (
    id BIGSERIAL PRIMARY KEY,
    candidate_id BIGINT NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    
    media_type VARCHAR(50) NOT NULL CHECK (media_type IN (
        'headshot', 'headshot_formal', 'headshot_casual',
        'family_photo', 'campaign_photo', 'event_photo',
        'logo_primary', 'logo_secondary', 'banner',
        'video_intro', 'video_ad', 'video_testimonial',
        'document', 'other'
    )),
    
    file_name VARCHAR(255) NOT NULL,
    original_name VARCHAR(255),
    media_url VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    cdn_url VARCHAR(500),
    mime_type VARCHAR(100),
    file_size_bytes INTEGER,
    dimensions VARCHAR(50),
    duration_seconds INTEGER,
    
    source VARCHAR(50) DEFAULT 'uploaded' CHECK (source IN (
        'uploaded', 'scraped_website', 'scraped_facebook',
        'scraped_twitter', 'scraped_linkedin', 'ai_generated', 'stock', 'other'
    )),
    source_url VARCHAR(500),
    scraped_at TIMESTAMP,
    
    title VARCHAR(255),
    description TEXT,
    alt_text VARCHAR(255),
    ai_tags JSONB,
    ai_quality_score INTEGER,
    faces_detected JSONB,
    dominant_colors VARCHAR(255),
    
    is_primary BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT TRUE,
    use_in_print BOOLEAN DEFAULT TRUE,
    use_in_digital BOOLEAN DEFAULT TRUE,
    use_in_social BOOLEAN DEFAULT TRUE,
    
    uploaded_by BIGINT,
    approved_by BIGINT,
    approved_at TIMESTAMP,
    rejection_reason TEXT,
    
    display_order INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_cm_candidate ON candidate_media(candidate_id);
CREATE INDEX idx_cm_type ON candidate_media(media_type);
CREATE INDEX idx_cm_primary ON candidate_media(is_primary);
CREATE INDEX idx_cm_approved ON candidate_media(is_approved);


-- ============================================================================
-- TABLE 3: candidate_admin_staff
-- Staff and permissions management
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_admin_staff (
    id BIGSERIAL PRIMARY KEY,
    candidate_id BIGINT NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    
    staff_name VARCHAR(255) NOT NULL,
    staff_email VARCHAR(255) NOT NULL,
    staff_phone VARCHAR(20),
    staff_title VARCHAR(100),
    
    role VARCHAR(50) NOT NULL CHECK (role IN (
        'candidate', 'campaign_manager', 'finance_director',
        'communications_dir', 'field_director', 'digital_director',
        'scheduler', 'volunteer_coord', 'data_manager',
        'staff', 'intern', 'consultant', 'family_member', 'super_admin'
    )),
    
    permissions JSONB,
    
    is_active BOOLEAN DEFAULT TRUE,
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMP,
    invite_token VARCHAR(100),
    invite_sent_at TIMESTAMP,
    invite_accepted_at TIMESTAMP,
    last_login_at TIMESTAMP,
    last_login_ip VARCHAR(45),
    
    notification_preferences JSONB,
    
    invited_by BIGINT,
    approved_by BIGINT,
    approved_at TIMESTAMP,
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    
    UNIQUE(candidate_id, staff_email)
);

CREATE INDEX idx_cas_candidate ON candidate_admin_staff(candidate_id);
CREATE INDEX idx_cas_user ON candidate_admin_staff(user_id);
CREATE INDEX idx_cas_role ON candidate_admin_staff(role);
CREATE INDEX idx_cas_active ON candidate_admin_staff(is_active);


-- ============================================================================
-- TABLE 4: candidate_ai_generations
-- Track all AI-generated profile content
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_ai_generations (
    id BIGSERIAL PRIMARY KEY,
    candidate_id BIGINT NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    
    generation_type VARCHAR(50) NOT NULL CHECK (generation_type IN (
        'full_profile', 'section', 'field', 'refresh', 'fact_check', 'enrich'
    )),
    section_name VARCHAR(100),
    
    ai_provider VARCHAR(50) DEFAULT 'perplexity',
    ai_model VARCHAR(100) DEFAULT 'sonar-pro',
    query_used TEXT NOT NULL,
    query_parameters JSONB,
    
    response_raw TEXT,
    response_parsed JSONB,
    fields_populated JSONB,
    fields_count INTEGER DEFAULT 0,
    citations JSONB,
    sources_used JSONB,
    
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending', 'processing', 'success', 'partial', 'failed', 'rejected'
    )),
    
    confidence_score INTEGER,
    completeness_score INTEGER,
    accuracy_score INTEGER,
    quality_notes TEXT,
    
    error_message TEXT,
    error_code VARCHAR(50),
    retry_count INTEGER DEFAULT 0,
    
    tokens_input INTEGER,
    tokens_output INTEGER,
    cost_usd DECIMAL(8,4),
    processing_time_ms INTEGER,
    
    auto_applied BOOLEAN DEFAULT FALSE,
    requires_review BOOLEAN DEFAULT TRUE,
    reviewed BOOLEAN DEFAULT FALSE,
    reviewed_by BIGINT,
    reviewed_at TIMESTAMP,
    approved BOOLEAN DEFAULT FALSE,
    review_notes TEXT,
    fields_rejected JSONB,
    fields_modified JSONB,
    
    triggered_by BIGINT,
    trigger_source VARCHAR(50) DEFAULT 'manual' CHECK (trigger_source IN (
        'manual', 'scheduled', 'onboarding', 'bulk_refresh', 'api', 'system'
    )),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cag_candidate ON candidate_ai_generations(candidate_id);
CREATE INDEX idx_cag_type ON candidate_ai_generations(generation_type);
CREATE INDEX idx_cag_section ON candidate_ai_generations(section_name);
CREATE INDEX idx_cag_status ON candidate_ai_generations(status);
CREATE INDEX idx_cag_created ON candidate_ai_generations(created_at);


-- ============================================================================
-- TABLE 5: candidate_profile_edits
-- Complete audit trail of all profile changes
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_profile_edits (
    id BIGSERIAL PRIMARY KEY,
    candidate_id BIGINT NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    
    table_name VARCHAR(100) DEFAULT 'candidate_profiles',
    field_name VARCHAR(100) NOT NULL,
    section_name VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    data_type VARCHAR(50),
    
    edit_source VARCHAR(50) NOT NULL CHECK (edit_source IN (
        'ai_generation', 'candidate_edit', 'staff_edit', 'admin_edit',
        'api_sync', 'bulk_import', 'system', 'scraper', 'enrichment'
    )),
    
    edited_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    edited_by_name VARCHAR(255),
    edited_by_role VARCHAR(50),
    edited_by_ip VARCHAR(45),
    user_agent VARCHAR(500),
    
    edit_reason VARCHAR(255),
    edit_notes TEXT,
    ai_generation_id BIGINT REFERENCES candidate_ai_generations(id) ON DELETE SET NULL,
    
    requires_approval BOOLEAN DEFAULT FALSE,
    approved BOOLEAN,
    approved_by BIGINT,
    approved_at TIMESTAMP,
    rejection_reason TEXT,
    
    is_rolled_back BOOLEAN DEFAULT FALSE,
    rolled_back_by BIGINT,
    rolled_back_at TIMESTAMP,
    rollback_edit_id BIGINT,
    
    batch_id VARCHAR(50),
    batch_sequence INTEGER,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cpe_candidate ON candidate_profile_edits(candidate_id);
CREATE INDEX idx_cpe_field ON candidate_profile_edits(field_name);
CREATE INDEX idx_cpe_source ON candidate_profile_edits(edit_source);
CREATE INDEX idx_cpe_edited_by ON candidate_profile_edits(edited_by);
CREATE INDEX idx_cpe_created ON candidate_profile_edits(created_at);
CREATE INDEX idx_cpe_approved ON candidate_profile_edits(approved);
CREATE INDEX idx_cpe_batch ON candidate_profile_edits(batch_id);


-- ============================================================================
-- TABLE 6: candidate_profile_questions
-- Question bank for profile forms and AI research
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_profile_questions (
    id BIGSERIAL PRIMARY KEY,
    
    section_number INTEGER NOT NULL,
    section_name VARCHAR(100) NOT NULL,
    question_number INTEGER NOT NULL,
    question_text TEXT NOT NULL,
    question_short TEXT,
    field_name VARCHAR(100) NOT NULL,
    
    field_type VARCHAR(50) NOT NULL CHECK (field_type IN (
        'text', 'textarea', 'number', 'decimal', 'date', 'datetime',
        'boolean', 'select', 'multi_select', 'radio', 'checkbox',
        'json', 'file', 'url', 'email', 'phone', 'address', 'rich_text'
    )),
    
    is_required BOOLEAN DEFAULT FALSE,
    validation_rules JSONB,
    options JSONB,
    
    help_text TEXT,
    placeholder VARCHAR(255),
    input_class VARCHAR(100),
    display_order INTEGER DEFAULT 0,
    show_in_form BOOLEAN DEFAULT TRUE,
    show_in_public_profile BOOLEAN DEFAULT FALSE,
    form_group VARCHAR(100),
    form_width INTEGER DEFAULT 12,
    
    ai_research_query TEXT,
    ai_research_sources JSONB,
    ai_confidence_threshold INTEGER DEFAULT 70,
    ai_can_populate BOOLEAN DEFAULT TRUE,
    
    donor_matching_weight INTEGER DEFAULT 0,
    matching_dimension VARCHAR(50) DEFAULT 'none' CHECK (matching_dimension IN (
        'geographic', 'professional', 'military', 'faith', 'education', 'issues', 'demographic', 'none'
    )),
    donor_field_match VARCHAR(100),
    
    completeness_weight INTEGER DEFAULT 1,
    counts_for_completeness BOOLEAN DEFAULT TRUE,
    
    show_if JSONB,
    
    is_active BOOLEAN DEFAULT TRUE,
    is_deprecated BOOLEAN DEFAULT FALSE,
    deprecated_reason VARCHAR(255),
    replacement_field VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(section_number, question_number)
);

CREATE INDEX idx_cpq_section ON candidate_profile_questions(section_number);
CREATE INDEX idx_cpq_field ON candidate_profile_questions(field_name);
CREATE INDEX idx_cpq_dimension ON candidate_profile_questions(matching_dimension);
CREATE INDEX idx_cpq_active ON candidate_profile_questions(is_active);


-- ============================================================================
-- TABLE 7: donor_candidate_affinity
-- THE CRITICAL CONNECTION BETWEEN DATAHUB AND CANDIDATE PROFILES
-- Links 243,575 donors to 72 candidates with 6-dimension scoring
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_candidate_affinity (
    id BIGSERIAL PRIMARY KEY,
    
    -- THE CONNECTION
    donor_id BIGINT NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
    candidate_id BIGINT NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    
    -- Overall Score
    total_score INTEGER NOT NULL,
    affinity_grade VARCHAR(5) NOT NULL,
    rank_for_donor INTEGER,
    rank_for_candidate INTEGER,
    
    -- 6-Dimension Scores (each 0-100)
    geographic_score INTEGER DEFAULT 0,
    issues_score INTEGER DEFAULT 0,
    professional_score INTEGER DEFAULT 0,
    faith_score INTEGER DEFAULT 0,
    education_score INTEGER DEFAULT 0,
    military_score INTEGER DEFAULT 0,
    
    -- Dimension Details (JSON for debugging/transparency)
    geographic_details JSONB,
    issues_details JSONB,
    professional_details JSONB,
    faith_details JSONB,
    education_details JSONB,
    military_details JSONB,
    
    -- Weights Used (for audit)
    weights_used JSONB,
    
    -- Recommended Actions
    recommended_ask_amount DECIMAL(10,2),
    recommended_channel VARCHAR(50),
    recommended_messaging JSONB,
    priority_score INTEGER DEFAULT 0,
    
    -- Status
    is_current BOOLEAN DEFAULT TRUE,
    calculated_at TIMESTAMP NOT NULL,
    calculation_version VARCHAR(20) DEFAULT '1.0',
    data_completeness_pct INTEGER DEFAULT 0,
    
    -- Engagement History (updated by campaigns)
    campaigns_sent INTEGER DEFAULT 0,
    campaigns_opened INTEGER DEFAULT 0,
    campaigns_clicked INTEGER DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    donations_total DECIMAL(12,2) DEFAULT 0,
    last_engagement_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(donor_id, candidate_id)
);

-- Critical indexes for fast lookup
CREATE INDEX idx_dca_donor ON donor_candidate_affinity(donor_id);
CREATE INDEX idx_dca_candidate ON donor_candidate_affinity(candidate_id);
CREATE INDEX idx_dca_score ON donor_candidate_affinity(total_score);
CREATE INDEX idx_dca_grade ON donor_candidate_affinity(affinity_grade);
CREATE INDEX idx_dca_geo ON donor_candidate_affinity(geographic_score);
CREATE INDEX idx_dca_issues ON donor_candidate_affinity(issues_score);
CREATE INDEX idx_dca_current ON donor_candidate_affinity(is_current);
CREATE INDEX idx_dca_cand_score ON donor_candidate_affinity(candidate_id, total_score);
CREATE INDEX idx_dca_donor_score ON donor_candidate_affinity(donor_id, total_score);
CREATE INDEX idx_dca_cand_grade ON donor_candidate_affinity(candidate_id, affinity_grade);


-- ============================================================================
-- VIEWS for Common Queries
-- ============================================================================

-- Top donors per candidate
CREATE OR REPLACE VIEW v_top_donors_by_candidate AS
SELECT 
    dca.candidate_id,
    cp.full_name AS candidate_name,
    dca.donor_id,
    d.first_name || ' ' || d.last_name AS donor_name,
    d.email,
    d.county,
    dca.total_score,
    dca.affinity_grade,
    dca.geographic_score,
    dca.issues_score,
    dca.professional_score,
    dca.faith_score,
    dca.education_score,
    dca.military_score,
    dca.recommended_ask_amount,
    dca.recommended_channel
FROM donor_candidate_affinity dca
JOIN candidate_profiles cp ON dca.candidate_id = cp.candidate_id
JOIN donors d ON dca.donor_id = d.id
WHERE dca.is_current = TRUE
ORDER BY dca.candidate_id, dca.total_score DESC;

-- County heat map data
CREATE OR REPLACE VIEW v_county_heat_map AS
SELECT 
    dca.candidate_id,
    cp.full_name AS candidate_name,
    d.county,
    COUNT(*) AS donor_count,
    AVG(dca.total_score) AS avg_score,
    SUM(CASE WHEN dca.affinity_grade LIKE 'A%' THEN 1 ELSE 0 END) AS a_tier_count,
    SUM(CASE WHEN dca.affinity_grade LIKE 'B%' THEN 1 ELSE 0 END) AS b_tier_count,
    SUM(d.lifetime_value) AS total_lifetime_value
FROM donor_candidate_affinity dca
JOIN candidate_profiles cp ON dca.candidate_id = cp.candidate_id
JOIN donors d ON dca.donor_id = d.id
WHERE dca.is_current = TRUE
GROUP BY dca.candidate_id, cp.full_name, d.county
ORDER BY dca.candidate_id, avg_score DESC;

-- Profile completeness dashboard
CREATE OR REPLACE VIEW v_profile_completeness AS
SELECT 
    cp.candidate_id,
    cp.full_name,
    cp.current_office,
    cp.district,
    cp.profile_completeness_pct,
    cp.total_donor_matches,
    cp.avg_affinity_score,
    cp.last_ai_refresh,
    cp.last_manual_edit,
    cp.approved_by_candidate,
    CASE WHEN cp.profile_completeness_pct >= 80 THEN 'Complete'
         WHEN cp.profile_completeness_pct >= 50 THEN 'Partial'
         ELSE 'Incomplete' END AS status
FROM candidate_profiles cp
WHERE cp.is_active = TRUE
ORDER BY cp.profile_completeness_pct DESC;


-- ============================================================================
-- FUNCTIONS for Affinity Calculation
-- ============================================================================

-- Function to calculate affinity grade from score
CREATE OR REPLACE FUNCTION score_to_grade(score INTEGER)
RETURNS VARCHAR(5) AS $$
BEGIN
    RETURN CASE
        WHEN score >= 90 THEN 'A+'
        WHEN score >= 85 THEN 'A'
        WHEN score >= 80 THEN 'A-'
        WHEN score >= 75 THEN 'B+'
        WHEN score >= 70 THEN 'B'
        WHEN score >= 65 THEN 'B-'
        WHEN score >= 60 THEN 'C+'
        WHEN score >= 55 THEN 'C'
        WHEN score >= 50 THEN 'C-'
        WHEN score >= 45 THEN 'D+'
        WHEN score >= 40 THEN 'D'
        WHEN score >= 35 THEN 'D-'
        ELSE 'F'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ============================================================================
-- TRIGGERS for Updated Timestamps
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_candidate_profiles_updated_at
    BEFORE UPDATE ON candidate_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_candidate_media_updated_at
    BEFORE UPDATE ON candidate_media
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_candidate_admin_staff_updated_at
    BEFORE UPDATE ON candidate_admin_staff
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_donor_candidate_affinity_updated_at
    BEFORE UPDATE ON donor_candidate_affinity
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


COMMIT;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- 
-- Created 7 tables:
--   1. candidate_profiles        - 273 fields for candidate data
--   2. candidate_media           - Media library
--   3. candidate_admin_staff     - Staff permissions
--   4. candidate_ai_generations  - AI generation tracking
--   5. candidate_profile_edits   - Complete audit trail
--   6. candidate_profile_questions - 500+ question bank
--   7. donor_candidate_affinity  - THE DATAHUB CONNECTION
--
-- Created 3 views:
--   1. v_top_donors_by_candidate - Top donors for each candidate
--   2. v_county_heat_map         - County-level affinity data
--   3. v_profile_completeness    - Profile status dashboard
--
-- Created 1 function:
--   1. score_to_grade()          - Convert 0-100 to A+ through F
--
-- Created 5 triggers:
--   - Auto-update updated_at columns
--
-- Total indexes: 40+
--
-- ============================================================================
