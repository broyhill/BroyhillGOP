-- ============================================================================
-- BROYHILLGOP UNIFIED 12-FACTION CLASSIFICATION SYSTEM
-- Master Schema Implementation
-- November 27, 2025
-- ============================================================================
-- This script creates the unified faction system that aligns donors and
-- candidates using the same 12 faction codes, enabling direct matching.
-- ============================================================================

-- ============================================================================
-- PART 1: CORE REFERENCE TABLES
-- ============================================================================

-- Faction reference table
CREATE TABLE IF NOT EXISTS faction_types (
    code VARCHAR(4) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    color_hex VARCHAR(7) DEFAULT '#666666',
    icon VARCHAR(50),
    display_order INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert the 12 unified factions
INSERT INTO faction_types (code, name, description, color_hex, icon, display_order) VALUES
('MAGA', 'Trump Patriot', 'Trump donors, America First, endorsed candidates', '#C41E3A', 'flag', 1),
('EVAN', 'Evangelical', 'Church-active, pro-life champions, faith-driven', '#4169E1', 'church', 2),
('TRAD', 'Traditional Conservative', 'Establishment GOP, measured approach, Reagan-style', '#228B22', 'landmark', 3),
('FISC', 'Fiscal Conservative', 'Club for Growth, deficit hawks, tax fighters', '#FFD700', 'chart-line', 4),
('LIBT', 'Libertarian', 'Liberty focus, limited government, Rand Paul types', '#9400D3', 'balance-scale', 5),
('BUSI', 'Business Republican', 'Chamber, corporate, pro-business, free trade', '#1E90FF', 'briefcase', 6),
('LAWS', 'Law & Order', 'Police support, 2A, tough on crime, sheriffs', '#2F4F4F', 'shield', 7),
('POPF', 'Populist Firebrand', 'Anti-establishment fighters, confrontational', '#FF4500', 'fire', 8),
('MODG', 'Moderate', 'Swing district, bipartisan, suburban appeal', '#808080', 'handshake', 9),
('VETS', 'Veterans/Military', 'Military service, defense hawks, patriotic', '#000080', 'medal', 10),
('CHNA', 'Christian Nationalist', 'Faith & Flag, no compromise, culture warriors', '#800000', 'cross', 11),
('RUAL', 'Rural/Agriculture', 'Farm Bureau, rural values, agriculture priority', '#8B4513', 'tractor', 12)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    color_hex = EXCLUDED.color_hex,
    icon = EXCLUDED.icon,
    display_order = EXCLUDED.display_order;

-- ============================================================================
-- PART 2: DONOR FACTION SCORING TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_faction_scores (
    id BIGSERIAL PRIMARY KEY,
    donor_id BIGINT NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
    
    -- 12 Faction Scores (0-100 each)
    maga_score DECIMAL(5,2) DEFAULT 0,
    evan_score DECIMAL(5,2) DEFAULT 0,
    trad_score DECIMAL(5,2) DEFAULT 0,
    fisc_score DECIMAL(5,2) DEFAULT 0,
    libt_score DECIMAL(5,2) DEFAULT 0,
    busi_score DECIMAL(5,2) DEFAULT 0,
    laws_score DECIMAL(5,2) DEFAULT 0,
    popf_score DECIMAL(5,2) DEFAULT 0,
    modg_score DECIMAL(5,2) DEFAULT 0,
    vets_score DECIMAL(5,2) DEFAULT 0,
    chna_score DECIMAL(5,2) DEFAULT 0,
    rual_score DECIMAL(5,2) DEFAULT 0,
    
    -- Derived Classifications
    primary_faction VARCHAR(4) REFERENCES faction_types(code),
    secondary_faction VARCHAR(4) REFERENCES faction_types(code),
    tertiary_faction VARCHAR(4) REFERENCES faction_types(code),
    
    -- Pew Typology Mapping (for research validation)
    pew_typology VARCHAR(50),
    
    -- Metadata
    confidence_score DECIMAL(3,2) DEFAULT 0.50,
    data_sources JSONB DEFAULT '[]'::jsonb,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    calculation_version VARCHAR(10) DEFAULT '1.0',
    
    CONSTRAINT unique_donor_faction UNIQUE (donor_id),
    CONSTRAINT valid_confidence CHECK (confidence_score >= 0 AND confidence_score <= 1)
);

-- Indexes for faction queries
CREATE INDEX IF NOT EXISTS idx_donor_faction_primary ON donor_faction_scores(primary_faction);
CREATE INDEX IF NOT EXISTS idx_donor_faction_maga ON donor_faction_scores(maga_score) WHERE maga_score >= 70;
CREATE INDEX IF NOT EXISTS idx_donor_faction_evan ON donor_faction_scores(evan_score) WHERE evan_score >= 70;
CREATE INDEX IF NOT EXISTS idx_donor_faction_calculated ON donor_faction_scores(calculated_at);

-- ============================================================================
-- PART 3: CANDIDATE FACTION PROFILE TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_faction_profiles (
    id BIGSERIAL PRIMARY KEY,
    candidate_id BIGINT NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    
    -- Primary Classification (required)
    primary_type VARCHAR(4) NOT NULL REFERENCES faction_types(code),
    secondary_type VARCHAR(4) REFERENCES faction_types(code),
    tertiary_type VARCHAR(4) REFERENCES faction_types(code),
    
    -- 12 Faction Intensity Scores (0-100 each)
    maga_intensity DECIMAL(5,2) DEFAULT 0,
    evan_intensity DECIMAL(5,2) DEFAULT 0,
    trad_intensity DECIMAL(5,2) DEFAULT 0,
    fisc_intensity DECIMAL(5,2) DEFAULT 0,
    libt_intensity DECIMAL(5,2) DEFAULT 0,
    busi_intensity DECIMAL(5,2) DEFAULT 0,
    laws_intensity DECIMAL(5,2) DEFAULT 0,
    popf_intensity DECIMAL(5,2) DEFAULT 0,
    modg_intensity DECIMAL(5,2) DEFAULT 0,
    vets_intensity DECIMAL(5,2) DEFAULT 0,
    chna_intensity DECIMAL(5,2) DEFAULT 0,
    rual_intensity DECIMAL(5,2) DEFAULT 0,
    
    -- External Ratings & Endorsements
    trump_endorsement BOOLEAN DEFAULT FALSE,
    trump_endorsement_date DATE,
    nra_grade VARCHAR(5),
    pro_life_grade VARCHAR(5),
    club_for_growth_score INT,
    heritage_score INT,
    afp_score INT,
    ncvalues_score INT,
    
    -- Assignment Metadata
    assignment_source VARCHAR(50) DEFAULT 'questionnaire',
    assigned_by VARCHAR(100),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confidence_score DECIMAL(3,2) DEFAULT 0.80,
    notes TEXT,
    
    CONSTRAINT unique_candidate_faction UNIQUE (candidate_id)
);

-- Indexes for candidate faction queries
CREATE INDEX IF NOT EXISTS idx_candidate_primary_type ON candidate_faction_profiles(primary_type);
CREATE INDEX IF NOT EXISTS idx_candidate_trump_endorsed ON candidate_faction_profiles(trump_endorsement) WHERE trump_endorsement = TRUE;

-- ============================================================================
-- PART 4: FACTION AFFINITY MATRIX TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS faction_affinity_matrix (
    donor_faction VARCHAR(4) NOT NULL REFERENCES faction_types(code),
    candidate_type VARCHAR(4) NOT NULL REFERENCES faction_types(code),
    affinity_score INT NOT NULL CHECK (affinity_score >= 0 AND affinity_score <= 100),
    rationale TEXT,
    PRIMARY KEY (donor_faction, candidate_type)
);

-- Insert complete 12x12 affinity matrix
INSERT INTO faction_affinity_matrix (donor_faction, candidate_type, affinity_score) VALUES
-- MAGA donors
('MAGA', 'MAGA', 98), ('MAGA', 'EVAN', 70), ('MAGA', 'TRAD', 40), ('MAGA', 'FISC', 55),
('MAGA', 'LIBT', 35), ('MAGA', 'BUSI', 30), ('MAGA', 'LAWS', 80), ('MAGA', 'POPF', 95),
('MAGA', 'MODG', 10), ('MAGA', 'VETS', 75), ('MAGA', 'CHNA', 92), ('MAGA', 'RUAL', 75),
-- EVAN donors
('EVAN', 'MAGA', 75), ('EVAN', 'EVAN', 98), ('EVAN', 'TRAD', 70), ('EVAN', 'FISC', 65),
('EVAN', 'LIBT', 35), ('EVAN', 'BUSI', 55), ('EVAN', 'LAWS', 75), ('EVAN', 'POPF', 60),
('EVAN', 'MODG', 30), ('EVAN', 'VETS', 70), ('EVAN', 'CHNA', 95), ('EVAN', 'RUAL', 70),
-- TRAD donors
('TRAD', 'MAGA', 40), ('TRAD', 'EVAN', 65), ('TRAD', 'TRAD', 98), ('TRAD', 'FISC', 85),
('TRAD', 'LIBT', 60), ('TRAD', 'BUSI', 90), ('TRAD', 'LAWS', 65), ('TRAD', 'POPF', 20),
('TRAD', 'MODG', 80), ('TRAD', 'VETS', 75), ('TRAD', 'CHNA', 50), ('TRAD', 'RUAL', 70),
-- FISC donors
('FISC', 'MAGA', 55), ('FISC', 'EVAN', 55), ('FISC', 'TRAD', 80), ('FISC', 'FISC', 98),
('FISC', 'LIBT', 85), ('FISC', 'BUSI', 85), ('FISC', 'LAWS', 65), ('FISC', 'POPF', 45),
('FISC', 'MODG', 60), ('FISC', 'VETS', 70), ('FISC', 'CHNA', 50), ('FISC', 'RUAL', 65),
-- LIBT donors
('LIBT', 'MAGA', 35), ('LIBT', 'EVAN', 35), ('LIBT', 'TRAD', 60), ('LIBT', 'FISC', 85),
('LIBT', 'LIBT', 98), ('LIBT', 'BUSI', 70), ('LIBT', 'LAWS', 50), ('LIBT', 'POPF', 45),
('LIBT', 'MODG', 55), ('LIBT', 'VETS', 55), ('LIBT', 'CHNA', 25), ('LIBT', 'RUAL', 55),
-- BUSI donors
('BUSI', 'MAGA', 30), ('BUSI', 'EVAN', 50), ('BUSI', 'TRAD', 90), ('BUSI', 'FISC', 85),
('BUSI', 'LIBT', 70), ('BUSI', 'BUSI', 98), ('BUSI', 'LAWS', 60), ('BUSI', 'POPF', 20),
('BUSI', 'MODG', 75), ('BUSI', 'VETS', 65), ('BUSI', 'CHNA', 35), ('BUSI', 'RUAL', 60),
-- LAWS donors
('LAWS', 'MAGA', 80), ('LAWS', 'EVAN', 75), ('LAWS', 'TRAD', 70), ('LAWS', 'FISC', 65),
('LAWS', 'LIBT', 50), ('LAWS', 'BUSI', 60), ('LAWS', 'LAWS', 98), ('LAWS', 'POPF', 75),
('LAWS', 'MODG', 50), ('LAWS', 'VETS', 85), ('LAWS', 'CHNA', 75), ('LAWS', 'RUAL', 75),
-- POPF donors
('POPF', 'MAGA', 95), ('POPF', 'EVAN', 55), ('POPF', 'TRAD', 20), ('POPF', 'FISC', 45),
('POPF', 'LIBT', 45), ('POPF', 'BUSI', 20), ('POPF', 'LAWS', 75), ('POPF', 'POPF', 98),
('POPF', 'MODG', 10), ('POPF', 'VETS', 65), ('POPF', 'CHNA', 85), ('POPF', 'RUAL', 70),
-- MODG donors
('MODG', 'MAGA', 10), ('MODG', 'EVAN', 30), ('MODG', 'TRAD', 80), ('MODG', 'FISC', 60),
('MODG', 'LIBT', 55), ('MODG', 'BUSI', 75), ('MODG', 'LAWS', 50), ('MODG', 'POPF', 10),
('MODG', 'MODG', 98), ('MODG', 'VETS', 55), ('MODG', 'CHNA', 15), ('MODG', 'RUAL', 45),
-- VETS donors
('VETS', 'MAGA', 75), ('VETS', 'EVAN', 70), ('VETS', 'TRAD', 75), ('VETS', 'FISC', 70),
('VETS', 'LIBT', 55), ('VETS', 'BUSI', 65), ('VETS', 'LAWS', 85), ('VETS', 'POPF', 60),
('VETS', 'MODG', 55), ('VETS', 'VETS', 98), ('VETS', 'CHNA', 70), ('VETS', 'RUAL', 70),
-- CHNA donors
('CHNA', 'MAGA', 92), ('CHNA', 'EVAN', 95), ('CHNA', 'TRAD', 50), ('CHNA', 'FISC', 50),
('CHNA', 'LIBT', 25), ('CHNA', 'BUSI', 35), ('CHNA', 'LAWS', 75), ('CHNA', 'POPF', 85),
('CHNA', 'MODG', 10), ('CHNA', 'VETS', 70), ('CHNA', 'CHNA', 98), ('CHNA', 'RUAL', 70),
-- RUAL donors
('RUAL', 'MAGA', 75), ('RUAL', 'EVAN', 70), ('RUAL', 'TRAD', 70), ('RUAL', 'FISC', 65),
('RUAL', 'LIBT', 55), ('RUAL', 'BUSI', 60), ('RUAL', 'LAWS', 75), ('RUAL', 'POPF', 70),
('RUAL', 'MODG', 45), ('RUAL', 'VETS', 70), ('RUAL', 'CHNA', 70), ('RUAL', 'RUAL', 98)
ON CONFLICT (donor_faction, candidate_type) DO UPDATE SET
    affinity_score = EXCLUDED.affinity_score;

-- ============================================================================
-- PART 5: DONOR-CANDIDATE AFFINITY CACHE TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_candidate_affinity (
    donor_id BIGINT NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
    candidate_id BIGINT NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    
    -- Affinity Scores
    faction_affinity_score DECIMAL(5,2) NOT NULL,
    personal_affinity_score DECIMAL(5,2) NOT NULL,
    combined_affinity_score DECIMAL(5,2) NOT NULL,
    
    -- Personal Match Breakdown (6 dimensions)
    geographic_match DECIMAL(5,2) DEFAULT 0,
    professional_match DECIMAL(5,2) DEFAULT 0,
    educational_match DECIMAL(5,2) DEFAULT 0,
    military_match DECIMAL(5,2) DEFAULT 0,
    faith_match DECIMAL(5,2) DEFAULT 0,
    cultural_match DECIMAL(5,2) DEFAULT 0,
    
    -- Classification
    match_quality VARCHAR(15) NOT NULL CHECK (match_quality IN ('EXCEPTIONAL', 'STRONG', 'GOOD', 'FAIR', 'WEAK')),
    solicitation_priority INT CHECK (solicitation_priority >= 1 AND solicitation_priority <= 5),
    
    -- Metadata
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cache_valid_until TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days'),
    
    PRIMARY KEY (donor_id, candidate_id)
);

-- Indexes for affinity queries
CREATE INDEX IF NOT EXISTS idx_affinity_combined ON donor_candidate_affinity(combined_affinity_score DESC);
CREATE INDEX IF NOT EXISTS idx_affinity_candidate ON donor_candidate_affinity(candidate_id, combined_affinity_score DESC);
CREATE INDEX IF NOT EXISTS idx_affinity_quality ON donor_candidate_affinity(match_quality);
CREATE INDEX IF NOT EXISTS idx_affinity_priority ON donor_candidate_affinity(solicitation_priority);

-- ============================================================================
-- PART 6: PRIOR CANDIDATE SIGNALS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS prior_candidate_signals (
    id SERIAL PRIMARY KEY,
    candidate_name VARCHAR(255) NOT NULL,
    candidate_level VARCHAR(20) NOT NULL CHECK (candidate_level IN ('PRESIDENTIAL', 'FEDERAL', 'STATE', 'LOCAL')),
    office_held VARCHAR(255),
    state VARCHAR(2) DEFAULT 'NC',
    
    -- Faction Signals (using unified 12 codes)
    primary_faction VARCHAR(4) REFERENCES faction_types(code),
    primary_signal INT CHECK (primary_signal >= -100 AND primary_signal <= 100),
    secondary_faction VARCHAR(4) REFERENCES faction_types(code),
    secondary_signal INT,
    tertiary_faction VARCHAR(4) REFERENCES faction_types(code),
    tertiary_signal INT,
    
    -- Metadata
    notes TEXT,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_prior_candidate UNIQUE (candidate_name, candidate_level)
);

-- Insert key prior candidate signals
INSERT INTO prior_candidate_signals (candidate_name, candidate_level, office_held, primary_faction, primary_signal, secondary_faction, secondary_signal, tertiary_faction, tertiary_signal, notes) VALUES
-- Presidential
('Donald Trump', 'PRESIDENTIAL', 'President', 'MAGA', 95, 'CHNA', 85, 'POPF', 80, 'Defines MAGA faction'),
('Ted Cruz', 'PRESIDENTIAL', 'Senator', 'EVAN', 90, 'CHNA', 85, 'FISC', 80, 'Evangelical champion'),
('Rand Paul', 'PRESIDENTIAL', 'Senator', 'LIBT', 98, 'FISC', 85, NULL, NULL, 'Libertarian standard-bearer'),
('Nikki Haley', 'PRESIDENTIAL', 'Governor', 'TRAD', 90, 'BUSI', 85, 'MODG', 70, 'Establishment favorite'),
('Ron DeSantis', 'PRESIDENTIAL', 'Governor', 'MAGA', 85, 'EVAN', 80, 'POPF', 75, 'MAGA alternative'),
('Vivek Ramaswamy', 'PRESIDENTIAL', 'Businessman', 'POPF', 90, 'MAGA', 85, 'BUSI', 70, 'Anti-establishment outsider'),
('Mike Pence', 'PRESIDENTIAL', 'Vice President', 'EVAN', 95, 'TRAD', 85, 'LAWS', 70, 'Evangelical traditional'),
-- NC Federal
('Ted Budd', 'FEDERAL', 'Senator', 'MAGA', 90, 'FISC', 85, 'LAWS', 80, 'Trump-endorsed Senator'),
('Thom Tillis', 'FEDERAL', 'Senator', 'TRAD', 85, 'BUSI', 85, 'MODG', 60, 'Establishment Senator'),
('Virginia Foxx', 'FEDERAL', 'Representative', 'FISC', 85, 'TRAD', 80, 'EVAN', 75, 'Fiscal hawk'),
('Patrick McHenry', 'FEDERAL', 'Representative', 'BUSI', 90, 'FISC', 85, 'TRAD', 80, 'Financial Services chair'),
('Dan Bishop', 'FEDERAL', 'Representative', 'MAGA', 90, 'LAWS', 85, 'CHNA', 80, 'Conservative firebrand'),
('Richard Hudson', 'FEDERAL', 'Representative', 'LAWS', 85, 'TRAD', 80, 'MAGA', 75, 'NRA champion'),
-- NC State - Council of State
('Mark Robinson', 'STATE', 'Lt. Governor', 'EVAN', 95, 'MAGA', 90, 'CHNA', 95, 'Evangelical firebrand'),
('Michele Morrow', 'STATE', 'Superintendent Candidate', 'EVAN', 95, 'CHNA', 90, 'MAGA', 85, 'Christian education warrior'),
('Steve Troxler', 'STATE', 'Agriculture Commissioner', 'RUAL', 95, 'TRAD', 75, 'BUSI', 70, 'Agricultural champion'),
('Dale Folwell', 'STATE', 'Treasurer', 'FISC', 90, 'TRAD', 80, 'POPF', 65, 'Fiscal watchdog'),
('Mike Causey', 'STATE', 'Insurance Commissioner', 'TRAD', 80, 'BUSI', 80, 'FISC', 70, 'Steady conservative'),
('Tim Moore', 'STATE', 'House Speaker', 'TRAD', 85, 'MAGA', 75, 'FISC', 75, 'Legislative leader'),
('Phil Berger', 'STATE', 'Senate President', 'TRAD', 90, 'FISC', 85, 'BUSI', 80, 'Establishment leader'),
('Bo Hines', 'STATE', 'Congressional Candidate', 'MAGA', 95, 'VETS', 75, 'POPF', 70, 'Young Trump ally'),
('Pat McCrory', 'STATE', 'Former Governor', 'TRAD', 90, 'BUSI', 85, 'MODG', 70, 'Moderate establishment')
ON CONFLICT (candidate_name, candidate_level) DO UPDATE SET
    primary_faction = EXCLUDED.primary_faction,
    primary_signal = EXCLUDED.primary_signal,
    secondary_faction = EXCLUDED.secondary_faction,
    secondary_signal = EXCLUDED.secondary_signal,
    tertiary_faction = EXCLUDED.tertiary_faction,
    tertiary_signal = EXCLUDED.tertiary_signal;

-- ============================================================================
-- PART 7: PAC FACTION SIGNALS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS pac_faction_signals (
    id SERIAL PRIMARY KEY,
    pac_name VARCHAR(255) NOT NULL,
    fec_committee_id VARCHAR(20),
    
    -- Faction Signals
    primary_faction VARCHAR(4) REFERENCES faction_types(code),
    primary_signal INT CHECK (primary_signal >= -100 AND primary_signal <= 100),
    secondary_faction VARCHAR(4) REFERENCES faction_types(code),
    secondary_signal INT,
    
    -- Metadata
    notes TEXT,
    active BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT unique_pac UNIQUE (pac_name)
);

-- Insert key PAC signals
INSERT INTO pac_faction_signals (pac_name, primary_faction, primary_signal, secondary_faction, secondary_signal, notes) VALUES
('Make America Great Again PAC', 'MAGA', 95, 'POPF', 85, 'Trump official PAC'),
('Save America PAC', 'MAGA', 95, 'POPF', 85, 'Trump leadership PAC'),
('Club for Growth', 'FISC', 95, 'LIBT', 70, 'Fiscal conservative scorecard'),
('Americans for Prosperity', 'FISC', 90, 'LIBT', 80, 'Koch network'),
('Susan B. Anthony Pro-Life', 'EVAN', 95, 'CHNA', 80, 'Pro-life single issue'),
('NRA-PVF', 'LAWS', 95, 'LIBT', 65, 'Gun rights'),
('FreedomWorks', 'LIBT', 90, 'FISC', 85, 'Tea Party era'),
('Heritage Action', 'FISC', 85, 'TRAD', 80, 'Heritage Foundation arm'),
('Faith & Freedom Coalition', 'EVAN', 95, 'CHNA', 90, 'Ralph Reed organization'),
('US Chamber of Commerce', 'BUSI', 95, 'TRAD', 80, 'Big business'),
('National Federation of Independent Business', 'BUSI', 85, 'FISC', 80, 'Small business'),
('Farm Bureau PAC', 'RUAL', 95, 'TRAD', 70, 'Agricultural interests'),
('FOP PAC', 'LAWS', 95, 'TRAD', 70, 'Fraternal Order of Police'),
('VFW-PAC', 'VETS', 95, 'LAWS', 75, 'Veterans of Foreign Wars'),
('American Legion', 'VETS', 90, 'TRAD', 80, 'Veterans organization'),
('Republican Main Street Partnership', 'MODG', 90, 'TRAD', 85, 'Moderate Republicans'),
('Republican Governance Group', 'MODG', 85, 'BUSI', 80, 'Centrist caucus'),
('NC Values Coalition', 'EVAN', 90, 'CHNA', 85, 'NC faith organization'),
('Carolina Rising', 'TRAD', 80, 'MAGA', 70, 'NC conservative group')
ON CONFLICT (pac_name) DO UPDATE SET
    primary_faction = EXCLUDED.primary_faction,
    primary_signal = EXCLUDED.primary_signal,
    secondary_faction = EXCLUDED.secondary_faction,
    secondary_signal = EXCLUDED.secondary_signal;

-- ============================================================================
-- PART 8: CORE FUNCTIONS
-- ============================================================================

-- Function to get matrix affinity score
CREATE OR REPLACE FUNCTION get_matrix_affinity(
    p_donor_faction VARCHAR(4),
    p_candidate_type VARCHAR(4)
) RETURNS INT AS $$
BEGIN
    RETURN COALESCE(
        (SELECT affinity_score FROM faction_affinity_matrix 
         WHERE donor_faction = p_donor_faction AND candidate_type = p_candidate_type),
        50  -- Default neutral affinity
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to calculate weighted faction affinity
CREATE OR REPLACE FUNCTION calculate_faction_affinity(
    p_donor_id BIGINT,
    p_candidate_id BIGINT
) RETURNS DECIMAL(5,2) AS $$
DECLARE
    v_candidate_type VARCHAR(4);
    v_donor_scores RECORD;
    v_total_affinity DECIMAL := 0;
    v_total_weight DECIMAL := 0;
BEGIN
    -- Get candidate primary type
    SELECT primary_type INTO v_candidate_type
    FROM candidate_faction_profiles
    WHERE candidate_id = p_candidate_id;
    
    IF v_candidate_type IS NULL THEN
        RETURN 50;  -- Default if no candidate profile
    END IF;
    
    -- Get donor faction scores
    SELECT * INTO v_donor_scores
    FROM donor_faction_scores
    WHERE donor_id = p_donor_id;
    
    IF v_donor_scores IS NULL THEN
        RETURN 50;  -- Default if no donor scores
    END IF;
    
    -- Calculate weighted affinity
    v_total_affinity := v_total_affinity + (v_donor_scores.maga_score / 100.0) * get_matrix_affinity('MAGA', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.maga_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.evan_score / 100.0) * get_matrix_affinity('EVAN', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.evan_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.trad_score / 100.0) * get_matrix_affinity('TRAD', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.trad_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.fisc_score / 100.0) * get_matrix_affinity('FISC', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.fisc_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.libt_score / 100.0) * get_matrix_affinity('LIBT', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.libt_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.busi_score / 100.0) * get_matrix_affinity('BUSI', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.busi_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.laws_score / 100.0) * get_matrix_affinity('LAWS', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.laws_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.popf_score / 100.0) * get_matrix_affinity('POPF', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.popf_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.modg_score / 100.0) * get_matrix_affinity('MODG', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.modg_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.vets_score / 100.0) * get_matrix_affinity('VETS', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.vets_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.chna_score / 100.0) * get_matrix_affinity('CHNA', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.chna_score / 100.0);
    
    v_total_affinity := v_total_affinity + (v_donor_scores.rual_score / 100.0) * get_matrix_affinity('RUAL', v_candidate_type);
    v_total_weight := v_total_weight + (v_donor_scores.rual_score / 100.0);
    
    IF v_total_weight > 0 THEN
        RETURN v_total_affinity / v_total_weight;
    ELSE
        RETURN 50;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to calculate combined affinity (faction 60% + personal 40%)
CREATE OR REPLACE FUNCTION calculate_combined_affinity(
    p_donor_id BIGINT,
    p_candidate_id BIGINT
) RETURNS TABLE (
    faction_score DECIMAL(5,2),
    personal_score DECIMAL(5,2),
    combined_score DECIMAL(5,2),
    match_quality VARCHAR(15)
) AS $$
DECLARE
    v_faction DECIMAL(5,2);
    v_personal DECIMAL(5,2);
    v_combined DECIMAL(5,2);
    v_quality VARCHAR(15);
BEGIN
    -- Calculate faction affinity (60% weight)
    v_faction := calculate_faction_affinity(p_donor_id, p_candidate_id);
    
    -- Calculate personal affinity (40% weight) - placeholder for 6-dimension calculation
    -- This would query the actual donor and candidate profiles for geographic, professional, etc. matches
    v_personal := 50;  -- Default, should be replaced with actual calculation
    
    -- Combined score: 60% faction + 40% personal
    v_combined := (v_faction * 0.60) + (v_personal * 0.40);
    
    -- Determine quality
    IF v_combined >= 85 THEN
        v_quality := 'EXCEPTIONAL';
    ELSIF v_combined >= 70 THEN
        v_quality := 'STRONG';
    ELSIF v_combined >= 55 THEN
        v_quality := 'GOOD';
    ELSIF v_combined >= 40 THEN
        v_quality := 'FAIR';
    ELSE
        v_quality := 'WEAK';
    END IF;
    
    RETURN QUERY SELECT v_faction, v_personal, v_combined, v_quality;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get top candidates for a donor
CREATE OR REPLACE FUNCTION get_top_candidates_for_donor(
    p_donor_id BIGINT,
    p_limit INT DEFAULT 10
) RETURNS TABLE (
    candidate_id BIGINT,
    candidate_name VARCHAR,
    primary_type VARCHAR(4),
    combined_score DECIMAL(5,2),
    match_quality VARCHAR(15)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.full_name,
        cfp.primary_type,
        ca.combined_score,
        ca.match_quality
    FROM candidates c
    JOIN candidate_faction_profiles cfp ON c.id = cfp.candidate_id
    JOIN LATERAL (
        SELECT * FROM calculate_combined_affinity(p_donor_id, c.id)
    ) ca ON true
    ORDER BY ca.combined_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get top donors for a candidate
CREATE OR REPLACE FUNCTION get_top_donors_for_candidate(
    p_candidate_id BIGINT,
    p_limit INT DEFAULT 100
) RETURNS TABLE (
    donor_id BIGINT,
    donor_name VARCHAR,
    primary_faction VARCHAR(4),
    combined_score DECIMAL(5,2),
    match_quality VARCHAR(15),
    solicitation_priority INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        CONCAT(d.first_name, ' ', d.last_name)::VARCHAR,
        dfs.primary_faction,
        ca.combined_score,
        ca.match_quality,
        CASE 
            WHEN ca.combined_score >= 85 THEN 1
            WHEN ca.combined_score >= 70 THEN 2
            WHEN ca.combined_score >= 55 THEN 3
            WHEN ca.combined_score >= 40 THEN 4
            ELSE 5
        END
    FROM donors d
    JOIN donor_faction_scores dfs ON d.id = dfs.donor_id
    JOIN LATERAL (
        SELECT * FROM calculate_combined_affinity(d.id, p_candidate_id)
    ) ca ON true
    ORDER BY ca.combined_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- PART 9: VIEWS FOR REPORTING
-- ============================================================================

-- Donor faction summary view
CREATE OR REPLACE VIEW v_donor_faction_summary AS
SELECT 
    d.id AS donor_id,
    CONCAT(d.first_name, ' ', d.last_name) AS donor_name,
    d.email,
    d.county,
    dfs.primary_faction,
    ft.name AS faction_name,
    dfs.secondary_faction,
    dfs.tertiary_faction,
    dfs.maga_score,
    dfs.evan_score,
    dfs.trad_score,
    dfs.fisc_score,
    dfs.libt_score,
    dfs.busi_score,
    dfs.laws_score,
    dfs.popf_score,
    dfs.modg_score,
    dfs.vets_score,
    dfs.chna_score,
    dfs.rual_score,
    dfs.confidence_score,
    dfs.calculated_at
FROM donors d
JOIN donor_faction_scores dfs ON d.id = dfs.donor_id
LEFT JOIN faction_types ft ON dfs.primary_faction = ft.code;

-- Candidate faction summary view
CREATE OR REPLACE VIEW v_candidate_faction_summary AS
SELECT 
    c.id AS candidate_id,
    c.full_name AS candidate_name,
    c.target_office,
    c.district,
    cfp.primary_type,
    ft.name AS faction_name,
    cfp.secondary_type,
    cfp.tertiary_type,
    cfp.trump_endorsement,
    cfp.nra_grade,
    cfp.pro_life_grade,
    cfp.maga_intensity,
    cfp.evan_intensity,
    cfp.trad_intensity,
    cfp.fisc_intensity,
    cfp.assigned_at
FROM candidates c
JOIN candidate_faction_profiles cfp ON c.id = cfp.candidate_id
LEFT JOIN faction_types ft ON cfp.primary_type = ft.code;

-- Faction distribution view
CREATE OR REPLACE VIEW v_faction_distribution AS
SELECT 
    ft.code,
    ft.name,
    ft.color_hex,
    COUNT(DISTINCT dfs.donor_id) AS donor_count,
    ROUND(COUNT(DISTINCT dfs.donor_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM donor_faction_scores), 0), 2) AS donor_pct,
    COUNT(DISTINCT cfp.candidate_id) AS candidate_count
FROM faction_types ft
LEFT JOIN donor_faction_scores dfs ON dfs.primary_faction = ft.code
LEFT JOIN candidate_faction_profiles cfp ON cfp.primary_type = ft.code
GROUP BY ft.code, ft.name, ft.color_hex, ft.display_order
ORDER BY ft.display_order;

-- ============================================================================
-- COMPLETE
-- ============================================================================

-- Grant permissions (adjust as needed for your environment)
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO app_user;

COMMENT ON TABLE faction_types IS 'Reference table for the 12 unified faction codes used across donors and candidates';
COMMENT ON TABLE donor_faction_scores IS 'Stores 12-dimension faction scores for each donor';
COMMENT ON TABLE candidate_faction_profiles IS 'Stores faction type and intensity scores for each candidate';
COMMENT ON TABLE faction_affinity_matrix IS 'Lookup table for donor faction → candidate type affinity scores';
COMMENT ON TABLE donor_candidate_affinity IS 'Cached combined affinity scores for donor-candidate pairs';
COMMENT ON FUNCTION calculate_combined_affinity IS 'Calculates 60% faction + 40% personal affinity between donor and candidate';
