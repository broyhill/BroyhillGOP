-- ============================================================================
-- BROYHILLGOP LOCAL CANDIDATE INTELLIGENCE SYSTEM - PART 2
-- News Intelligence, Neighborhood Priorities, Calculation Functions
-- November 28, 2025
-- ============================================================================

-- ============================================================================
-- PART 7: LOCAL NEWS MONITORING (County/Municipal Level)
-- ============================================================================

-- NC Media Outlets (imported from CSV - 214 outlets)
CREATE TABLE IF NOT EXISTS local_media_outlets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Location
    county VARCHAR(100) NOT NULL,
    county_seat VARCHAR(100),
    cities_towns VARCHAR(255),
    
    -- Outlet Info
    outlet_name VARCHAR(255) NOT NULL,
    media_type VARCHAR(50) NOT NULL, -- 'Newspaper', 'Radio', 'Television', 'Digital News', etc.
    frequency VARCHAR(50), -- 'Daily', 'Weekly', 'Monthly'
    
    -- Political Classification (critical for GOP campaigns)
    political_lean VARCHAR(30) NOT NULL, -- 'Conservative', 'Lean Conservative', 'Non-Partisan', 'Lean Liberal', 'Liberal'
    conservative_friendly BOOLEAN DEFAULT FALSE,
    priority_tier INT DEFAULT 3 CHECK (priority_tier BETWEEN 1 AND 5),
    
    -- Details
    description TEXT,
    circulation_audience VARCHAR(100),
    circulation_number INT,
    
    -- Digital Presence
    website_url VARCHAR(500),
    url_status VARCHAR(20) DEFAULT 'Unknown',
    rss_feed_url VARCHAR(500),
    
    -- Coverage
    service_area VARCHAR(255),
    regional_category VARCHAR(50),
    specialty_focus VARCHAR(100),
    
    -- Contact Info
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    editor_name VARCHAR(200),
    political_reporter VARCHAR(200),
    social_media_handles JSONB DEFAULT '{}'::jsonb,
    press_release_email VARCHAR(255),
    
    -- Outreach Tracking
    outreach_count INT DEFAULT 0,
    last_outreach_at TIMESTAMP,
    relationship_status VARCHAR(20) DEFAULT 'cold', -- 'cold', 'warm', 'hot', 'established'
    
    -- Metadata
    last_verified VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_media_county ON local_media_outlets(county);
CREATE INDEX IF NOT EXISTS idx_media_type ON local_media_outlets(media_type);
CREATE INDEX IF NOT EXISTS idx_media_lean ON local_media_outlets(political_lean);
CREATE INDEX IF NOT EXISTS idx_media_conservative ON local_media_outlets(conservative_friendly) WHERE conservative_friendly = TRUE;
CREATE INDEX IF NOT EXISTS idx_media_tier ON local_media_outlets(priority_tier);

-- ============================================================================
-- PART 8: LOCAL NEWS EVENTS (Monitored for Campaign Triggers)
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_news_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source
    outlet_id UUID REFERENCES local_media_outlets(id),
    source_name VARCHAR(255) NOT NULL,
    source_url VARCHAR(500),
    source_type VARCHAR(50), -- 'newspaper', 'radio', 'tv', 'social', 'press_release', 'public_record'
    
    -- Event Details
    headline VARCHAR(500) NOT NULL,
    summary TEXT,
    full_content TEXT,
    published_at TIMESTAMP,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Geographic Scope
    county VARCHAR(100),
    municipality VARCHAR(100),
    precinct VARCHAR(50),
    affected_counties JSONB DEFAULT '[]'::jsonb,
    
    -- Event Classification
    event_type VARCHAR(50) NOT NULL,
    -- Types: 'candidate_announcement', 'resignation', 'retirement', 'scandal', 'endorsement',
    --        'crime_spike', 'school_controversy', 'tax_issue', 'development_issue', 
    --        'budget_crisis', 'public_safety', 'election_news', 'policy_change'
    
    -- Office Relevance
    affected_office_types JSONB DEFAULT '[]'::jsonb,
    mentioned_candidates JSONB DEFAULT '[]'::jsonb,
    incumbent_involved BOOLEAN DEFAULT FALSE,
    vacancy_created BOOLEAN DEFAULT FALSE,
    
    -- Issue Classification
    issue_tags JSONB DEFAULT '[]'::jsonb,
    primary_issue VARCHAR(50),
    
    -- Political Analysis
    political_importance INT DEFAULT 5 CHECK (political_importance BETWEEN 1 AND 10),
    urgency_score INT DEFAULT 5 CHECK (urgency_score BETWEEN 1 AND 10),
    opportunity_score INT DEFAULT 5 CHECK (opportunity_score BETWEEN 1 AND 10),
    
    -- AI Analysis
    ai_summary TEXT,
    ai_sentiment VARCHAR(20), -- 'positive', 'negative', 'neutral', 'mixed'
    ai_extracted_entities JSONB DEFAULT '{}'::jsonb,
    ai_campaign_angles JSONB DEFAULT '[]'::jsonb,
    ai_confidence DECIMAL(3,2),
    
    -- Campaign Opportunity Assessment
    is_campaign_opportunity BOOLEAN DEFAULT FALSE,
    opportunity_type VARCHAR(100),
    opportunity_description TEXT,
    recommended_response_hours INT DEFAULT 24,
    
    -- Faction Relevance (which factions care about this)
    faction_relevance JSONB DEFAULT '{}'::jsonb,
    -- Format: {"LAWS": 95, "MAGA": 80, "EVAN": 30, ...}
    
    -- Processing Status
    status VARCHAR(20) DEFAULT 'new',
    processed_at TIMESTAMP,
    triggers_created INT DEFAULT 0,
    campaigns_launched INT DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_news_county ON local_news_events(county);
CREATE INDEX IF NOT EXISTS idx_news_type ON local_news_events(event_type);
CREATE INDEX IF NOT EXISTS idx_news_status ON local_news_events(status);
CREATE INDEX IF NOT EXISTS idx_news_opportunity ON local_news_events(is_campaign_opportunity) WHERE is_campaign_opportunity = TRUE;
CREATE INDEX IF NOT EXISTS idx_news_urgency ON local_news_events(urgency_score DESC);
CREATE INDEX IF NOT EXISTS idx_news_discovered ON local_news_events(discovered_at DESC);

-- ============================================================================
-- PART 9: LOCAL NEWS CAMPAIGN TRIGGERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_news_triggers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    news_event_id UUID NOT NULL REFERENCES local_news_events(id) ON DELETE CASCADE,
    
    -- Trigger Definition
    trigger_name VARCHAR(255) NOT NULL,
    trigger_type VARCHAR(50) NOT NULL,
    -- Types: 'vacancy_response', 'issue_capitalize', 'scandal_contrast', 'endorsement_announce',
    --        'crime_response', 'education_response', 'tax_response', 'opponent_weakness'
    
    -- Target
    target_county VARCHAR(100),
    target_office_type VARCHAR(10) REFERENCES local_office_types(code),
    target_candidate_id UUID REFERENCES local_candidates(id),
    target_audience_criteria JSONB DEFAULT '{}'::jsonb,
    
    -- Audience Estimation
    estimated_donor_reach INT DEFAULT 0,
    estimated_audience_score DECIMAL(5,2) DEFAULT 0,
    
    -- Faction Targeting
    primary_faction_target VARCHAR(4) REFERENCES faction_types(code),
    faction_score_minimum INT DEFAULT 50,
    
    -- Campaign Suggestion
    suggested_campaign_type VARCHAR(50),
    suggested_subject VARCHAR(255),
    suggested_content TEXT,
    suggested_channels JSONB DEFAULT '["email"]'::jsonb,
    suggested_ask_amount NUMERIC(10,2),
    
    -- Timing
    response_window_hours INT DEFAULT 24,
    optimal_send_time TIMESTAMP,
    expires_at TIMESTAMP,
    
    -- Approval Workflow
    status VARCHAR(20) DEFAULT 'pending',
    -- Status: 'pending', 'approved', 'rejected', 'executed', 'expired'
    priority INT DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    
    approved_by VARCHAR(100),
    approved_at TIMESTAMP,
    rejection_reason TEXT,
    
    -- Execution
    executed_at TIMESTAMP,
    campaign_id UUID,
    
    -- Results
    emails_sent INT DEFAULT 0,
    sms_sent INT DEFAULT 0,
    donations_received INT DEFAULT 0,
    amount_raised NUMERIC(12,2) DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trigger_status ON local_news_triggers(status);
CREATE INDEX IF NOT EXISTS idx_trigger_priority ON local_news_triggers(priority DESC) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_trigger_expires ON local_news_triggers(expires_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_trigger_candidate ON local_news_triggers(target_candidate_id);
CREATE INDEX IF NOT EXISTS idx_trigger_office ON local_news_triggers(target_office_type);

-- ============================================================================
-- PART 10: NEIGHBORHOOD ISSUE PRIORITIES
-- Hyperlocal issue tracking by precinct/municipality
-- ============================================================================

CREATE TABLE IF NOT EXISTS neighborhood_priorities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Geographic Scope
    county_fips VARCHAR(5) NOT NULL,
    county_name VARCHAR(100) NOT NULL,
    municipality VARCHAR(100),
    precinct_id VARCHAR(20),
    precinct_name VARCHAR(100),
    zip_code VARCHAR(10),
    
    -- Issue Scores (0-100, how important in this area)
    issue_crime INT DEFAULT 50,
    issue_schools INT DEFAULT 50,
    issue_taxes INT DEFAULT 50,
    issue_development INT DEFAULT 50,
    issue_traffic INT DEFAULT 50,
    issue_environment INT DEFAULT 50,
    issue_housing INT DEFAULT 50,
    issue_drugs INT DEFAULT 50,
    issue_immigration INT DEFAULT 50,
    issue_jobs INT DEFAULT 50,
    
    -- Top 3 Issues (auto-calculated)
    top_issue_1 VARCHAR(50),
    top_issue_1_score INT,
    top_issue_2 VARCHAR(50),
    top_issue_2_score INT,
    top_issue_3 VARCHAR(50),
    top_issue_3_score INT,
    
    -- Local News Themes (from monitoring)
    recent_news_themes JSONB DEFAULT '[]'::jsonb,
    news_sentiment VARCHAR(20) DEFAULT 'neutral',
    
    -- Demographic Indicators
    median_income INT,
    median_age INT,
    owner_occupied_pct DECIMAL(5,2),
    college_educated_pct DECIMAL(5,2),
    rural_suburban_urban VARCHAR(20),
    
    -- Political Indicators
    trump_2020_pct DECIMAL(5,2),
    trump_2024_pct DECIMAL(5,2),
    gop_registration_pct DECIMAL(5,2),
    primary_turnout_pct DECIMAL(5,2),
    
    -- Local Candidate Relevance
    relevant_office_types JSONB DEFAULT '[]'::jsonb,
    active_local_races INT DEFAULT 0,
    
    -- Metadata
    data_freshness VARCHAR(20) DEFAULT 'estimated',
    last_news_scan TIMESTAMP,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_neighborhood UNIQUE (county_fips, COALESCE(municipality, ''), COALESCE(precinct_id, ''))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_neighborhood_county ON neighborhood_priorities(county_fips);
CREATE INDEX IF NOT EXISTS idx_neighborhood_precinct ON neighborhood_priorities(precinct_id) WHERE precinct_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_neighborhood_zip ON neighborhood_priorities(zip_code) WHERE zip_code IS NOT NULL;

-- ============================================================================
-- PART 11: LOCAL CANDIDATE GRADING FUNCTION (21-tier)
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_local_candidate_grade(p_candidate_id UUID)
RETURNS VARCHAR(2) AS $$
DECLARE
    v_total_score INT := 0;
    v_grade VARCHAR(2);
    v_candidate RECORD;
    v_office_weight DECIMAL;
BEGIN
    -- Get candidate data
    SELECT * INTO v_candidate FROM local_candidates WHERE id = p_candidate_id;
    
    IF v_candidate IS NULL THEN
        RETURN 'U-';
    END IF;
    
    -- Component 1: Electability (0-30 points)
    -- Based on: incumbent status, previous terms, name recognition
    IF v_candidate.is_incumbent THEN
        v_total_score := v_total_score + 25;
    END IF;
    v_total_score := v_total_score + LEAST(v_candidate.previous_terms * 5, 15);
    
    -- Component 2: Fundraising (0-25 points)
    -- Based on: amount raised vs goal
    IF v_candidate.fundraising_goal > 0 AND v_candidate.amount_raised > 0 THEN
        v_total_score := v_total_score + LEAST(
            (v_candidate.amount_raised / v_candidate.fundraising_goal * 25)::INT, 
            25
        );
    END IF;
    
    -- Component 3: Profile Completeness (0-15 points)
    v_total_score := v_total_score + LEAST(v_candidate.profile_completeness / 7, 15);
    
    -- Component 4: Endorsements (0-15 points)
    IF v_candidate.trump_endorsement THEN
        v_total_score := v_total_score + 10;
    END IF;
    IF v_candidate.nra_grade IN ('A+', 'A', 'A-') THEN
        v_total_score := v_total_score + 3;
    END IF;
    IF v_candidate.pro_life_grade IN ('A+', 'A', 'A-') THEN
        v_total_score := v_total_score + 2;
    END IF;
    
    -- Component 5: Experience (0-10 points)
    v_total_score := v_total_score + LEAST(v_candidate.years_in_county / 3, 5);
    IF v_candidate.military_veteran THEN
        v_total_score := v_total_score + 3;
    END IF;
    IF v_candidate.is_business_owner THEN
        v_total_score := v_total_score + 2;
    END IF;
    
    -- Component 6: Faction Alignment (0-5 points)
    IF v_candidate.primary_faction IS NOT NULL THEN
        v_total_score := v_total_score + 3;
    END IF;
    IF v_candidate.secondary_faction IS NOT NULL THEN
        v_total_score := v_total_score + 2;
    END IF;
    
    -- Convert score to 21-tier grade
    v_grade := CASE
        WHEN v_total_score >= 95 THEN 'A+'
        WHEN v_total_score >= 90 THEN 'A'
        WHEN v_total_score >= 85 THEN 'A-'
        WHEN v_total_score >= 80 THEN 'B+'
        WHEN v_total_score >= 75 THEN 'B'
        WHEN v_total_score >= 70 THEN 'B-'
        WHEN v_total_score >= 65 THEN 'C+'
        WHEN v_total_score >= 60 THEN 'C'
        WHEN v_total_score >= 55 THEN 'C-'
        WHEN v_total_score >= 50 THEN 'D+'
        WHEN v_total_score >= 45 THEN 'D'
        WHEN v_total_score >= 40 THEN 'D-'
        WHEN v_total_score >= 35 THEN 'E+'
        WHEN v_total_score >= 30 THEN 'E'
        WHEN v_total_score >= 25 THEN 'E-'
        WHEN v_total_score >= 20 THEN 'F+'
        WHEN v_total_score >= 15 THEN 'F'
        WHEN v_total_score >= 10 THEN 'F-'
        WHEN v_total_score >= 7 THEN 'U+'
        WHEN v_total_score >= 4 THEN 'U'
        ELSE 'U-'
    END;
    
    RETURN v_grade;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- PART 12: LOCAL CANDIDATE 1000-POINT SCORING FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_local_candidate_score(p_candidate_id UUID)
RETURNS INT AS $$
DECLARE
    v_candidate RECORD;
    v_total_score INT := 0;
    v_office_weight DECIMAL := 1.0;
    v_score_electability INT := 0;
    v_score_fundraising INT := 0;
    v_score_profile INT := 0;
    v_score_endorsements INT := 0;
    v_score_experience INT := 0;
    v_score_local INT := 0;
    v_score_network INT := 0;
BEGIN
    -- Get candidate
    SELECT * INTO v_candidate FROM local_candidates WHERE id = p_candidate_id;
    
    IF v_candidate IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Component 1: Electability (0-300 points)
    IF v_candidate.is_incumbent THEN
        v_score_electability := v_score_electability + 150;
    END IF;
    v_score_electability := v_score_electability + LEAST(v_candidate.previous_terms * 30, 90);
    IF v_candidate.trump_endorsement THEN
        v_score_electability := v_score_electability + 60;
    END IF;
    
    -- Component 2: Fundraising Capacity (0-200 points)
    IF v_candidate.amount_raised >= 100000 THEN
        v_score_fundraising := 200;
    ELSIF v_candidate.amount_raised >= 50000 THEN
        v_score_fundraising := 150;
    ELSIF v_candidate.amount_raised >= 25000 THEN
        v_score_fundraising := 100;
    ELSIF v_candidate.amount_raised >= 10000 THEN
        v_score_fundraising := 60;
    ELSIF v_candidate.amount_raised >= 5000 THEN
        v_score_fundraising := 30;
    ELSIF v_candidate.amount_raised > 0 THEN
        v_score_fundraising := 15;
    END IF;
    
    -- Bonus for exceeding goal
    IF v_candidate.fundraising_goal > 0 AND v_candidate.amount_raised > v_candidate.fundraising_goal THEN
        v_score_fundraising := LEAST(v_score_fundraising + 30, 200);
    END IF;
    
    -- Component 3: Profile Completeness (0-150 points)
    v_score_profile := LEAST((v_candidate.profile_completeness * 1.5)::INT, 150);
    
    -- Component 4: Endorsement Strength (0-150 points)
    IF v_candidate.trump_endorsement THEN
        v_score_endorsements := v_score_endorsements + 75;
    END IF;
    
    CASE v_candidate.nra_grade
        WHEN 'A+' THEN v_score_endorsements := v_score_endorsements + 30;
        WHEN 'A' THEN v_score_endorsements := v_score_endorsements + 25;
        WHEN 'A-' THEN v_score_endorsements := v_score_endorsements + 20;
        WHEN 'B+' THEN v_score_endorsements := v_score_endorsements + 15;
        WHEN 'B' THEN v_score_endorsements := v_score_endorsements + 10;
        ELSE NULL;
    END CASE;
    
    CASE v_candidate.pro_life_grade
        WHEN 'A+' THEN v_score_endorsements := v_score_endorsements + 25;
        WHEN 'A' THEN v_score_endorsements := v_score_endorsements + 20;
        WHEN 'A-' THEN v_score_endorsements := v_score_endorsements + 15;
        WHEN 'B+' THEN v_score_endorsements := v_score_endorsements + 10;
        ELSE NULL;
    END CASE;
    
    -- Endorsement JSON count
    v_score_endorsements := v_score_endorsements + LEAST(
        (jsonb_array_length(COALESCE(v_candidate.endorsements_received, '[]'::jsonb)) * 3),
        20
    );
    v_score_endorsements := LEAST(v_score_endorsements, 150);
    
    -- Component 5: Experience/Background (0-100 points)
    v_score_experience := LEAST(v_candidate.years_in_county * 2, 30);
    
    IF v_candidate.military_veteran THEN
        v_score_experience := v_score_experience + 25;
        IF v_candidate.combat_veteran THEN
            v_score_experience := v_score_experience + 10;
        END IF;
    END IF;
    
    IF v_candidate.is_business_owner THEN
        v_score_experience := v_score_experience + 15;
    END IF;
    
    IF v_candidate.education_level IN ('doctorate', 'professional', 'law') THEN
        v_score_experience := v_score_experience + 10;
    ELSIF v_candidate.education_level IN ('masters') THEN
        v_score_experience := v_score_experience + 5;
    END IF;
    
    v_score_experience := LEAST(v_score_experience, 100);
    
    -- Component 6: Local Engagement (0-50 points)
    IF v_candidate.years_in_district >= 20 THEN
        v_score_local := 25;
    ELSIF v_candidate.years_in_district >= 10 THEN
        v_score_local := 20;
    ELSIF v_candidate.years_in_district >= 5 THEN
        v_score_local := 15;
    ELSE
        v_score_local := LEAST(v_candidate.years_in_district * 3, 15);
    END IF;
    
    IF v_candidate.church_leadership THEN
        v_score_local := v_score_local + 10;
    END IF;
    
    IF jsonb_array_length(COALESCE(v_candidate.board_positions, '[]'::jsonb)) > 0 THEN
        v_score_local := v_score_local + LEAST(
            jsonb_array_length(v_candidate.board_positions) * 5,
            15
        );
    END IF;
    
    v_score_local := LEAST(v_score_local, 50);
    
    -- Component 7: Network/Influence (0-50 points)
    v_score_network := LEAST((v_candidate.social_followers_total / 200)::INT, 25);
    v_score_network := v_score_network + LEAST((v_candidate.donor_count / 10)::INT, 25);
    v_score_network := LEAST(v_score_network, 50);
    
    -- Calculate total
    v_total_score := v_score_electability + v_score_fundraising + v_score_profile +
                     v_score_endorsements + v_score_experience + v_score_local + v_score_network;
    
    -- Apply office-type weight based on candidate's primary faction
    IF v_candidate.primary_faction IS NOT NULL THEN
        SELECT COALESCE(weight_multiplier, 1.0) INTO v_office_weight
        FROM local_faction_office_weights
        WHERE office_type = v_candidate.office_type
        AND faction_code = v_candidate.primary_faction;
        
        v_total_score := (v_total_score * v_office_weight)::INT;
    END IF;
    
    -- Store component scores
    INSERT INTO local_candidate_scores (
        candidate_id, total_score,
        score_electability, score_fundraising, score_profile,
        score_endorsements, score_experience, score_local_engagement, score_network,
        weighted_total, weight_multiplier_used, calculated_at
    ) VALUES (
        p_candidate_id, LEAST(v_total_score, 1000),
        v_score_electability, v_score_fundraising, v_score_profile,
        v_score_endorsements, v_score_experience, v_score_local, v_score_network,
        LEAST(v_total_score, 1000), v_office_weight, CURRENT_TIMESTAMP
    )
    ON CONFLICT (candidate_id) DO UPDATE SET
        total_score = LEAST(v_total_score, 1000),
        score_electability = v_score_electability,
        score_fundraising = v_score_fundraising,
        score_profile = v_score_profile,
        score_endorsements = v_score_endorsements,
        score_experience = v_score_experience,
        score_local_engagement = v_score_local,
        score_network = v_score_network,
        weighted_total = LEAST(v_total_score, 1000),
        weight_multiplier_used = v_office_weight,
        previous_score = local_candidate_scores.total_score,
        calculated_at = CURRENT_TIMESTAMP;
    
    RETURN LEAST(v_total_score, 1000);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 13: DONOR-LOCAL CANDIDATE AFFINITY CALCULATION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_donor_local_affinity(
    p_donor_id BIGINT,
    p_candidate_id UUID
) RETURNS DECIMAL(5,2) AS $$
DECLARE
    v_donor RECORD;
    v_candidate RECORD;
    v_score_geographic DECIMAL := 0;
    v_score_professional DECIMAL := 0;
    v_score_educational DECIMAL := 0;
    v_score_military DECIMAL := 0;
    v_score_faith DECIMAL := 0;
    v_score_issues DECIMAL := 0;
    v_faction_affinity DECIMAL := 50;
    v_personal_affinity DECIMAL := 0;
    v_local_bonus DECIMAL := 0;
    v_combined_score DECIMAL := 0;
    v_office_weight DECIMAL := 1.0;
    v_match_quality VARCHAR(15);
BEGIN
    -- Get donor data
    SELECT * INTO v_donor FROM donors WHERE id = p_donor_id;
    
    -- Get candidate data
    SELECT * INTO v_candidate FROM local_candidates WHERE id = p_candidate_id;
    
    IF v_donor IS NULL OR v_candidate IS NULL THEN
        RETURN 0;
    END IF;
    
    -- === GEOGRAPHIC AFFINITY (0-100) ===
    -- Same county = 100, adjacent = 70, same region = 40, same state = 20
    IF LOWER(v_donor.county) = LOWER(v_candidate.county_name) THEN
        v_score_geographic := 100;
        v_local_bonus := v_local_bonus + 30;
    ELSE
        v_score_geographic := 25; -- Same state baseline
    END IF;
    
    -- Precinct bonus
    IF v_donor.precinct_id IS NOT NULL AND v_donor.precinct_id = v_candidate.precinct_id THEN
        v_local_bonus := v_local_bonus + 20;
    END IF;
    
    -- === PROFESSIONAL AFFINITY (0-100) ===
    IF v_donor.occupation_category IS NOT NULL AND v_candidate.occupation_category IS NOT NULL THEN
        IF LOWER(v_donor.occupation_category) = LOWER(v_candidate.occupation_category) THEN
            v_score_professional := 80;
        END IF;
    END IF;
    
    IF v_donor.employer IS NOT NULL AND v_candidate.employer IS NOT NULL THEN
        IF LOWER(v_donor.employer) = LOWER(v_candidate.employer) THEN
            v_score_professional := 100;
        END IF;
    END IF;
    
    -- Business owner match
    IF COALESCE(v_donor.is_business_owner, FALSE) AND v_candidate.is_business_owner THEN
        v_score_professional := GREATEST(v_score_professional, 60);
    END IF;
    
    -- === EDUCATIONAL AFFINITY (0-100) ===
    IF v_donor.university IS NOT NULL AND v_candidate.undergrad_school IS NOT NULL THEN
        IF LOWER(v_donor.university) = LOWER(v_candidate.undergrad_school) THEN
            v_score_educational := 90;
        END IF;
    END IF;
    
    -- === MILITARY AFFINITY (0-100) ===
    IF COALESCE(v_donor.is_veteran, FALSE) AND v_candidate.military_veteran THEN
        v_score_military := 80;
        
        IF v_donor.military_branch IS NOT NULL AND v_candidate.military_branch IS NOT NULL THEN
            IF LOWER(v_donor.military_branch) = LOWER(v_candidate.military_branch) THEN
                v_score_military := 100;
            END IF;
        END IF;
    ELSIF NOT COALESCE(v_donor.is_veteran, FALSE) AND NOT v_candidate.military_veteran THEN
        v_score_military := 50; -- Neutral
    ELSE
        v_score_military := 30; -- Mismatch
    END IF;
    
    -- === FAITH AFFINITY (0-100) ===
    IF v_donor.denomination IS NOT NULL AND v_candidate.denomination IS NOT NULL THEN
        IF LOWER(v_donor.denomination) = LOWER(v_candidate.denomination) THEN
            v_score_faith := 90;
        ELSE
            v_score_faith := 40; -- Both religious, different
        END IF;
    END IF;
    
    IF v_donor.church_name IS NOT NULL AND v_candidate.church_name IS NOT NULL THEN
        IF LOWER(v_donor.church_name) = LOWER(v_candidate.church_name) THEN
            v_score_faith := 100;
            v_local_bonus := v_local_bonus + 15;
        END IF;
    END IF;
    
    -- === ISSUE AFFINITY (0-100) ===
    -- Compare position scores where both have values
    DECLARE
        v_issue_matches INT := 0;
        v_issue_count INT := 0;
    BEGIN
        IF v_donor.position_abortion IS NOT NULL AND v_candidate.position_abortion IS NOT NULL THEN
            v_issue_count := v_issue_count + 1;
            IF ABS(v_donor.position_abortion - v_candidate.position_abortion) <= 2 THEN
                v_issue_matches := v_issue_matches + 1;
            END IF;
        END IF;
        
        IF v_donor.position_guns IS NOT NULL AND v_candidate.position_guns IS NOT NULL THEN
            v_issue_count := v_issue_count + 1;
            IF ABS(v_donor.position_guns - v_candidate.position_guns) <= 2 THEN
                v_issue_matches := v_issue_matches + 1;
            END IF;
        END IF;
        
        IF v_donor.position_taxes IS NOT NULL AND v_candidate.position_taxes IS NOT NULL THEN
            v_issue_count := v_issue_count + 1;
            IF ABS(v_donor.position_taxes - v_candidate.position_taxes) <= 2 THEN
                v_issue_matches := v_issue_matches + 1;
            END IF;
        END IF;
        
        IF v_donor.position_crime IS NOT NULL AND v_candidate.position_crime IS NOT NULL THEN
            v_issue_count := v_issue_count + 1;
            IF ABS(v_donor.position_crime - v_candidate.position_crime) <= 2 THEN
                v_issue_matches := v_issue_matches + 1;
            END IF;
        END IF;
        
        IF v_issue_count > 0 THEN
            v_score_issues := (v_issue_matches::DECIMAL / v_issue_count) * 100;
        ELSE
            v_score_issues := 50; -- Neutral if no data
        END IF;
    END;
    
    -- === FACTION AFFINITY (from matrix) ===
    IF v_donor.primary_faction IS NOT NULL AND v_candidate.primary_faction IS NOT NULL THEN
        SELECT COALESCE(affinity_score, 50) INTO v_faction_affinity
        FROM faction_affinity_matrix
        WHERE donor_faction = v_donor.primary_faction
        AND candidate_type = v_candidate.primary_faction;
    END IF;
    
    -- === CALCULATE PERSONAL AFFINITY (weighted average of 6 dimensions) ===
    v_personal_affinity := (
        v_score_geographic * 0.30 +   -- Geographic most important for local
        v_score_issues * 0.25 +
        v_score_faith * 0.15 +
        v_score_professional * 0.15 +
        v_score_military * 0.10 +
        v_score_educational * 0.05
    );
    
    -- === GET OFFICE WEIGHT ===
    IF v_donor.primary_faction IS NOT NULL THEN
        SELECT COALESCE(weight_multiplier, 1.0) INTO v_office_weight
        FROM local_faction_office_weights
        WHERE office_type = v_candidate.office_type
        AND faction_code = v_donor.primary_faction;
    END IF;
    
    -- === CALCULATE COMBINED SCORE ===
    -- Formula: (faction * 0.45 + personal * 0.35 + local_bonus * 0.20) * office_weight
    v_combined_score := (
        v_faction_affinity * 0.45 +
        v_personal_affinity * 0.35 +
        LEAST(v_local_bonus, 100) * 0.20
    ) * COALESCE(v_office_weight, 1.0);
    
    v_combined_score := LEAST(v_combined_score, 100);
    
    -- === DETERMINE MATCH QUALITY ===
    v_match_quality := CASE
        WHEN v_combined_score >= 85 THEN 'EXCEPTIONAL'
        WHEN v_combined_score >= 70 THEN 'STRONG'
        WHEN v_combined_score >= 55 THEN 'GOOD'
        WHEN v_combined_score >= 40 THEN 'FAIR'
        ELSE 'WEAK'
    END;
    
    -- === STORE RESULTS ===
    INSERT INTO donor_local_candidate_affinity (
        donor_id, candidate_id,
        score_geographic, score_professional, score_educational,
        score_military, score_faith, score_issues,
        faction_affinity_score, personal_affinity_score, combined_score,
        office_weight_applied,
        same_county, local_bonus_score,
        match_quality, solicitation_priority, is_recommended,
        calculated_at
    ) VALUES (
        p_donor_id, p_candidate_id,
        v_score_geographic, v_score_professional, v_score_educational,
        v_score_military, v_score_faith, v_score_issues,
        v_faction_affinity, v_personal_affinity, v_combined_score,
        v_office_weight,
        (LOWER(v_donor.county) = LOWER(v_candidate.county_name)),
        v_local_bonus,
        v_match_quality,
        CASE 
            WHEN v_combined_score >= 85 THEN 1
            WHEN v_combined_score >= 70 THEN 2
            WHEN v_combined_score >= 55 THEN 3
            WHEN v_combined_score >= 40 THEN 4
            ELSE 5
        END,
        (v_combined_score >= 70),
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (donor_id, candidate_id) DO UPDATE SET
        score_geographic = v_score_geographic,
        score_professional = v_score_professional,
        score_educational = v_score_educational,
        score_military = v_score_military,
        score_faith = v_score_faith,
        score_issues = v_score_issues,
        faction_affinity_score = v_faction_affinity,
        personal_affinity_score = v_personal_affinity,
        combined_score = v_combined_score,
        office_weight_applied = v_office_weight,
        same_county = (LOWER(v_donor.county) = LOWER(v_candidate.county_name)),
        local_bonus_score = v_local_bonus,
        match_quality = v_match_quality,
        is_recommended = (v_combined_score >= 70),
        calculated_at = CURRENT_TIMESTAMP;
    
    RETURN v_combined_score;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 14: VIEWS FOR LOCAL CANDIDATE SYSTEM
-- ============================================================================

-- Local candidate summary with scores
CREATE OR REPLACE VIEW v_local_candidate_summary AS
SELECT 
    lc.id,
    lc.full_name,
    lc.county_name,
    lc.office_type,
    lot.name AS office_name,
    lc.election_year,
    lc.status,
    lc.is_incumbent,
    lc.primary_faction,
    ft.name AS faction_name,
    lc.amount_raised,
    lc.donor_count,
    lc.profile_completeness,
    lcg.current_grade,
    lcs.total_score,
    lcs.weighted_total,
    lc.trump_endorsement,
    lc.nra_grade,
    lc.created_at
FROM local_candidates lc
LEFT JOIN local_office_types lot ON lc.office_type = lot.code
LEFT JOIN faction_types ft ON lc.primary_faction = ft.code
LEFT JOIN local_candidate_grades lcg ON lc.id = lcg.candidate_id
LEFT JOIN local_candidate_scores lcs ON lc.id = lcs.candidate_id
WHERE lc.deleted_at IS NULL;

-- Top donors for local candidates
CREATE OR REPLACE VIEW v_top_local_donor_matches AS
SELECT 
    dlca.candidate_id,
    lc.full_name AS candidate_name,
    lc.office_type,
    lc.county_name,
    dlca.donor_id,
    d.first_name || ' ' || d.last_name AS donor_name,
    d.county AS donor_county,
    dlca.combined_score,
    dlca.match_quality,
    dlca.solicitation_priority,
    dlca.same_county,
    dlca.faction_affinity_score,
    dlca.personal_affinity_score,
    dlca.local_bonus_score
FROM donor_local_candidate_affinity dlca
JOIN local_candidates lc ON dlca.candidate_id = lc.id
JOIN donors d ON dlca.donor_id = d.id
WHERE dlca.is_recommended = TRUE
ORDER BY dlca.combined_score DESC;

-- News opportunities view
CREATE OR REPLACE VIEW v_local_news_opportunities AS
SELECT 
    lne.id,
    lne.headline,
    lne.county,
    lne.event_type,
    lne.political_importance,
    lne.urgency_score,
    lne.opportunity_type,
    lne.is_campaign_opportunity,
    lne.discovered_at,
    lmo.outlet_name,
    lmo.political_lean,
    COUNT(lnt.id) AS trigger_count,
    SUM(CASE WHEN lnt.status = 'executed' THEN 1 ELSE 0 END) AS executed_count
FROM local_news_events lne
LEFT JOIN local_media_outlets lmo ON lne.outlet_id = lmo.id
LEFT JOIN local_news_triggers lnt ON lne.id = lnt.news_event_id
WHERE lne.is_campaign_opportunity = TRUE
GROUP BY lne.id, lne.headline, lne.county, lne.event_type, 
         lne.political_importance, lne.urgency_score, lne.opportunity_type,
         lne.is_campaign_opportunity, lne.discovered_at, lmo.outlet_name, lmo.political_lean
ORDER BY lne.urgency_score DESC, lne.discovered_at DESC;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE local_candidates IS 'Local NC candidates with 150+ fields mirroring donor ecosystem';
COMMENT ON TABLE local_candidate_grades IS '21-tier grading (A+ to U-) for local candidates';
COMMENT ON TABLE local_candidate_scores IS '1000-point scoring (7 components) for local candidates';
COMMENT ON TABLE donor_local_candidate_affinity IS '6-dimension donor-candidate matching with office weighting';
COMMENT ON TABLE local_news_events IS 'County/municipal news monitored for campaign triggers';
COMMENT ON TABLE local_news_triggers IS 'Auto-generated campaign triggers from local news';
COMMENT ON TABLE neighborhood_priorities IS 'Hyperlocal issue tracking by precinct/municipality';
COMMENT ON FUNCTION calculate_local_candidate_grade IS 'Calculate 21-tier grade for local candidate';
COMMENT ON FUNCTION calculate_local_candidate_score IS 'Calculate 1000-point score with office weighting';
COMMENT ON FUNCTION calculate_donor_local_affinity IS 'Calculate 6-dimension + faction + local bonus affinity';
