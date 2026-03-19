-- =====================================================
-- BROYHILLGOP PLATFORM - HEAT MAP EXTENSION
-- NC COUNCIL OF STATE + FEDERAL OFFICES (US HOUSE / US SENATE)
-- Extension to: 1 BroyhillGOP-MASTER_DATABASE_SCHEMA.sql
-- Schema owner: donor_intelligence + candidates + datahub
-- Version: 1.0  |  Date: 2026-03-15
-- Extends: local_intelligence schema pattern
-- New schemas: state_offices, federal_offices
-- =====================================================

CREATE SCHEMA IF NOT EXISTS state_offices;
CREATE SCHEMA IF NOT EXISTS federal_offices;

-- =====================================================
-- SECTION 1: REFERENCE / LOOKUP TABLES
-- =====================================================

-- 1A: NC Council of State Office Registry (10 statewide offices)
CREATE TABLE state_offices.cos_office_registry (
    office_id           SERIAL PRIMARY KEY,
    office_code         VARCHAR(20)  UNIQUE NOT NULL,  -- GOV, LTG, AG, SOS, SAT, SPI, LBR, INS, AGC, COR
    office_name         VARCHAR(100) NOT NULL,
    office_level        VARCHAR(20)  NOT NULL DEFAULT 'STATE',
    term_years          INTEGER      NOT NULL DEFAULT 4,
    fec_applies         BOOLEAN      NOT NULL DEFAULT FALSE,  -- FALSE for state races (NCSBE jurisdiction)
    contribution_limit  DECIMAL(10,2),                        -- NULL = no NC limit for individual contributions
    jurisdiction_body   VARCHAR(100) DEFAULT 'NCSBE',
    geographic_scope    VARCHAR(20)  DEFAULT 'STATEWIDE',
    is_executive        BOOLEAN      DEFAULT TRUE,
    is_2026_cycle       BOOLEAN      DEFAULT TRUE,
    notes               TEXT,
    created_at          TIMESTAMPTZ  DEFAULT NOW()
);

INSERT INTO state_offices.cos_office_registry
    (office_code, office_name, term_years, fec_applies, contribution_limit, is_executive)
VALUES
    ('GOV',  'Governor',                      4, FALSE, NULL, TRUE),
    ('LTG',  'Lieutenant Governor',            4, FALSE, NULL, TRUE),
    ('AG',   'Attorney General',               4, FALSE, NULL, TRUE),
    ('SOS',  'Secretary of State',             4, FALSE, NULL, TRUE),
    ('SAT',  'State Auditor',                  4, FALSE, NULL, TRUE),
    ('SPI',  'Superintendent of Public Instruction', 4, FALSE, NULL, TRUE),
    ('LBR',  'Commissioner of Labor',          4, FALSE, NULL, TRUE),
    ('INS',  'Commissioner of Insurance',      4, FALSE, NULL, TRUE),
    ('AGC',  'Commissioner of Agriculture',    4, FALSE, NULL, TRUE),
    ('COR',  'State Treasurer',                4, FALSE, NULL, TRUE);


-- 1B: Federal Office Registry
CREATE TABLE federal_offices.federal_office_registry (
    office_id           SERIAL PRIMARY KEY,
    office_code         VARCHAR(20)  UNIQUE NOT NULL,  -- US_HOUSE_CD1..CD14, US_SENATE_NC1, US_SENATE_NC2
    office_type         VARCHAR(30)  NOT NULL,          -- US_HOUSE, US_SENATE
    office_name         VARCHAR(150) NOT NULL,
    district_number     INTEGER,                        -- 1-14 for House; NULL for Senate
    term_years          INTEGER      NOT NULL,
    fec_applies         BOOLEAN      NOT NULL DEFAULT TRUE,
    contribution_limit  DECIMAL(10,2) DEFAULT 3300.00,  -- Per election (FEC 2026)
    contribution_limit_cycle DECIMAL(10,2) DEFAULT 6600.00, -- Primary + General
    jurisdiction_body   VARCHAR(100) DEFAULT 'FEC',
    geographic_scope    VARCHAR(30),                    -- DISTRICT, STATEWIDE
    is_2026_cycle       BOOLEAN      DEFAULT TRUE,
    competitive_class   VARCHAR(20),                    -- SAFE_R, LEAN_R, COMPETITIVE, LEAN_D, SAFE_D
    geographic_character TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ  DEFAULT NOW()
);

INSERT INTO federal_offices.federal_office_registry
    (office_code, office_type, office_name, district_number, term_years, geographic_scope, competitive_class, geographic_character)
VALUES
    ('US_HOUSE_CD1',  'US_HOUSE', 'NC-01 US House',  1,  2, 'DISTRICT',  'COMPETITIVE',  'Coastal/NE NC, military (Seymour Johnson)'),
    ('US_HOUSE_CD2',  'US_HOUSE', 'NC-02 US House',  2,  2, 'DISTRICT',  'SAFE_R',       'Rural eastern NC'),
    ('US_HOUSE_CD4',  'US_HOUSE', 'NC-04 US House',  4,  2, 'DISTRICT',  'LEAN_D',       'Research Triangle core'),
    ('US_HOUSE_CD5',  'US_HOUSE', 'NC-05 US House',  5,  2, 'DISTRICT',  'SAFE_R',       'NW Appalachian, Helene epicenter'),
    ('US_HOUSE_CD6',  'US_HOUSE', 'NC-06 US House',  6,  2, 'DISTRICT',  'LEAN_R',       'Outer-ring suburban mixed'),
    ('US_HOUSE_CD7',  'US_HOUSE', 'NC-07 US House',  7,  2, 'DISTRICT',  'LEAN_R',       'Coastal Sandhills, Fort Liberty adjacent'),
    ('US_HOUSE_CD8',  'US_HOUSE', 'NC-08 US House',  8,  2, 'DISTRICT',  'SAFE_R',       'Cabarrus/Rowan/Stanly Piedmont manufacturing'),
    ('US_HOUSE_CD9',  'US_HOUSE', 'NC-09 US House',  9,  2, 'DISTRICT',  'SAFE_R',       'Union/Anson/Rowan Charlotte exurb'),
    ('US_HOUSE_CD10', 'US_HOUSE', 'NC-10 US House', 10,  2, 'DISTRICT',  'SAFE_R',       'Lincoln/Catawba/Iredell W Piedmont manufacturing'),
    ('US_HOUSE_CD11', 'US_HOUSE', 'NC-11 US House', 11,  2, 'DISTRICT',  'SAFE_R',       'WNC Mountain, Helene primary impact zone'),
    ('US_HOUSE_CD12', 'US_HOUSE', 'NC-12 US House', 12,  2, 'DISTRICT',  'SAFE_D',       'Charlotte urban core'),
    ('US_HOUSE_CD13', 'US_HOUSE', 'NC-13 US House', 13,  2, 'DISTRICT',  'LEAN_R',       'Wake exurbs, tech-entrepreneur suburban'),
    ('US_HOUSE_CD14', 'US_HOUSE', 'NC-14 US House', 14,  2, 'DISTRICT',  'COMPETITIVE',  'Johnston/Wake outer, fastest-growing competitive'),
    ('US_SENATE_NC_C2', 'US_SENATE', 'NC US Senate - Class 2 (Tillis seat)', NULL, 6, 'STATEWIDE', 'COMPETITIVE', '2026 live race - Tillis seat'),
    ('US_SENATE_NC_C3', 'US_SENATE', 'NC US Senate - Class 3 (Budd seat)',   NULL, 6, 'STATEWIDE', 'SAFE_R',      '2022 cycle, NOT on 2026 ballot');


-- =====================================================
-- SECTION 2: ISSUE INTENSITY MASTER TABLE
-- (shared by both state_offices and federal_offices)
-- =====================================================

-- 2A: Issue Taxonomy (canonical issue list)
CREATE TABLE state_offices.issue_taxonomy (
    issue_id        SERIAL PRIMARY KEY,
    issue_code      VARCHAR(50)  UNIQUE NOT NULL,
    issue_name      VARCHAR(200) NOT NULL,
    issue_category  VARCHAR(50)  NOT NULL,  -- ECONOMY, SECURITY, SOCIAL, JUDICIAL, EDUCATION, AGRICULTURE, ENVIRONMENT, MILITARY, LOCAL
    is_nc_specific  BOOLEAN DEFAULT FALSE,
    is_federal_only BOOLEAN DEFAULT FALSE,
    is_state_only   BOOLEAN DEFAULT FALSE,
    description     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO state_offices.issue_taxonomy
    (issue_code, issue_name, issue_category, is_nc_specific, is_federal_only, is_state_only)
VALUES
    -- Economy
    ('INFLATION_COST_LIVING',       'Inflation / Cost of Living / Energy Costs',         'ECONOMY',     FALSE, FALSE, FALSE),
    ('FISCAL_SPENDING_DEBT',        'Federal/State Spending & Debt',                    'ECONOMY',     FALSE, FALSE, FALSE),
    ('TCJA_EXTENSION',              'Tax Cuts / Extend TCJA Provisions',                'ECONOMY',     FALSE, TRUE,  FALSE),
    ('DEREGULATION',                'Deregulation / Permitting Reform',                 'ECONOMY',     FALSE, FALSE, FALSE),
    ('ANTI_ESG',                    'Anti-ESG / Corporate Accountability',              'ECONOMY',     FALSE, FALSE, FALSE),
    ('ANTI_CCP_DECOUPLING',         'Anti-CCP / China Economic Decoupling',             'ECONOMY',     FALSE, FALSE, FALSE),
    ('MFGRING_JOBS',                'Manufacturing / Textile Jobs Defense',             'ECONOMY',     TRUE,  FALSE, FALSE),
    -- Security / Border
    ('BORDER_IMMIGRATION',          'Border Security / Immigration Enforcement',        'SECURITY',    FALSE, FALSE, FALSE),
    ('FENTANYL_TRAFFICKING',        'Anti-Fentanyl / Drug Trafficking',                 'SECURITY',    FALSE, FALSE, FALSE),
    ('LAW_ORDER',                   'Law & Order / Anti-Crime',                         'SECURITY',    FALSE, FALSE, FALSE),
    ('NATIONAL_SECURITY_CHINA',     'National Security / Anti-China',                   'SECURITY',    FALSE, FALSE, FALSE),
    -- Social / Cultural
    ('ANTI_WOKE_CULTURE',           'Anti-Woke / Cultural Conservatism',               'SOCIAL',      FALSE, FALSE, FALSE),
    ('ANTI_DEI_GOVT',               'Anti-DEI in Government / Federal Agencies',        'SOCIAL',      FALSE, FALSE, FALSE),
    ('ANTI_WOKE_MILITARY',          'Anti-Woke Military / DEI in DoD',                  'SOCIAL',      FALSE, FALSE, FALSE),
    ('RELIGIOUS_LIBERTY',           'Religious Liberty (RFRA / State RFP)',             'SOCIAL',      FALSE, FALSE, FALSE),
    ('SECOND_AMENDMENT',            'Second Amendment / Gun Rights',                   'SOCIAL',      FALSE, FALSE, FALSE),
    -- Judicial
    ('ELECTION_INTEGRITY',          'Election Integrity',                               'JUDICIAL',    FALSE, FALSE, FALSE),
    ('JUDICIAL_NOMINEES',           'Judicial Nominations / SCOTUS Fidelity',          'JUDICIAL',    FALSE, TRUE,  FALSE),
    ('TRUMP_MAGA_ALIGNMENT',        'Trump Loyalty / MAGA Alignment Signal',            'POLITICAL',   FALSE, FALSE, FALSE),
    -- Education
    ('SCHOOL_CHOICE',               'School Choice / ESAs / Parental Rights',           'EDUCATION',   FALSE, FALSE, FALSE),
    ('CRT_CURRICULUM',              'Anti-CRT / Anti-Woke Curriculum',                  'EDUCATION',   FALSE, FALSE, FALSE),
    ('LOTTERY_FUNDING',             'State Lottery / Education Funding',               'EDUCATION',   TRUE,  FALSE, TRUE),
    -- Agriculture
    ('FARM_BILL',                   'Agriculture / Farm Bill Reauthorization',          'AGRICULTURE', FALSE, FALSE, FALSE),
    ('WOTUS_AG_REGS',               'WOTUS / Agricultural Deregulation',               'AGRICULTURE', FALSE, FALSE, FALSE),
    -- Military / Veterans
    ('MILITARY_VETERANS',           'Military / VA / NC Bases (Fort Liberty et al.)',  'MILITARY',    TRUE,  FALSE, FALSE),
    ('NDAA_DEFENSE_SPENDING',       'NDAA / Defense Spending',                          'MILITARY',    FALSE, TRUE,  FALSE),
    -- Local/NC Specific
    ('HELENE_RECOVERY',             'Hurricane Helene Federal/State Recovery',          'LOCAL_NC',    TRUE,  FALSE, FALSE),
    ('RURAL_BROADBAND',             'Rural Broadband (BEAD / State Programs)',          'LOCAL_NC',    TRUE,  FALSE, FALSE),
    ('NC_MEDICAID_EXPANSION',       'NC Medicaid Expansion / Access',                  'HEALTHCARE',  TRUE,  FALSE, FALSE),
    ('HEALTHCARE_ACA',              'Healthcare / ACA Repeal-Replace',                  'HEALTHCARE',  FALSE, FALSE, FALSE),
    ('ENERGY_ANTI_GND',             'Energy / Anti-Green New Deal',                     'ENVIRONMENT', FALSE, FALSE, FALSE),
    ('RURAL_BROADBAND_STATE',       'Rural Broadband State Programs',                  'LOCAL_NC',    TRUE,  FALSE, TRUE),
    ('MEDICAID_FRAUD_STATE',        'Medicaid Fraud & Waste (DHHS Oversight)',         'HEALTHCARE',  TRUE,  FALSE, TRUE),
    ('NC_DOT_ROADS',                'NC DOT / Transportation / Roads',                 'LOCAL_NC',    TRUE,  FALSE, TRUE),
    ('BUSINESS_REG_STATE',          'NC Business Regulation / SOS Corp Services',      'ECONOMY',     TRUE,  FALSE, TRUE),
    ('LAND_PROPERTY_RIGHTS',        'Land Rights / Property Rights / Eminent Domain',  'LOCAL_NC',    TRUE,  FALSE, FALSE),
    ('WORKERS_COMP_LABOR',          'Workers Comp / Right-to-Work / Labor',            'ECONOMY',     TRUE,  FALSE, TRUE),
    ('INSURANCE_RATES_STATE',       'Insurance Rates / Rate Review (DOI)',             'ECONOMY',     TRUE,  FALSE, TRUE),
    ('PENSION_RETIREMENT_STATE',    'State Employee Pension / Retirement Solvency',    'ECONOMY',     TRUE,  FALSE, TRUE),
    ('UNCLAIMED_PROPERTY_SOS',      'Unclaimed Property (SOS Function)',               'ECONOMY',     TRUE,  FALSE, TRUE),
    ('FOOD_SAFETY_AG',              'Food Safety / NC Dept of Agriculture',            'AGRICULTURE', TRUE,  FALSE, TRUE),
    ('AG_PROMOTION_EXPORTS',        'NC Agriculture Promotion / Export Markets',       'AGRICULTURE', TRUE,  FALSE, TRUE),
    ('OCCUPATIONAL_LICENSING',      'Occupational Licensing Reform (Labor)',           'ECONOMY',     TRUE,  FALSE, TRUE),
    ('SCHOOL_ACCOUNTABILITY',       'School Accountability / Testing / Standards',     'EDUCATION',   TRUE,  FALSE, TRUE),
    ('TEACHER_PAY_SPI',             'Teacher Pay & Recruitment (SPI)',                 'EDUCATION',   TRUE,  FALSE, TRUE);


-- =====================================================
-- SECTION 3: COUNCIL OF STATE - ISSUE INTENSITY MATRIX
-- =====================================================

-- 3A: CoS Office × Issue Intensity
--     intensity_score: 1-5 stars → stored as INTEGER 1-5
--     tier: 1=Defining, 2=Very High, 3=Significant, 4=Moderate
--     audience_type: NULL=all, or specific donor archetype focus
CREATE TABLE state_offices.cos_office_issue_intensity (
    intensity_id        SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES state_offices.cos_office_registry(office_id),
    issue_id            INTEGER      NOT NULL REFERENCES state_offices.issue_taxonomy(issue_id),
    intensity_score     SMALLINT     NOT NULL CHECK (intensity_score BETWEEN 1 AND 5),
    tier                SMALLINT     NOT NULL CHECK (tier BETWEEN 1 AND 4),
    is_primary          BOOLEAN      DEFAULT FALSE,   -- TRUE = top defining issue for this office
    is_unique_to_office BOOLEAN      DEFAULT FALSE,   -- TRUE = issue only activates for this specific office
    geographic_modifier TEXT,                          -- e.g. 'Appalachian counties only'
    rationale           TEXT,
    created_at          TIMESTAMPTZ  DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  DEFAULT NOW(),
    UNIQUE(office_id, issue_id)
);

-- Index for fast office-level heat map generation
CREATE INDEX idx_cos_intensity_office  ON state_offices.cos_office_issue_intensity(office_id);
CREATE INDEX idx_cos_intensity_score   ON state_offices.cos_office_issue_intensity(intensity_score DESC);
CREATE INDEX idx_cos_intensity_tier    ON state_offices.cos_office_issue_intensity(tier);

-- 3B: CoS Donor Archetype Match per Office
CREATE TABLE state_offices.cos_archetype_match (
    match_id            SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES state_offices.cos_office_registry(office_id),
    archetype_code      VARCHAR(20)  NOT NULL,   -- MAGA, EVAN, BUSI, FISC, DEF, AGRI, ANTIWOKE, HLTH, RURL
    archetype_name      VARCHAR(100) NOT NULL,
    activation_level    SMALLINT     NOT NULL CHECK (activation_level BETWEEN 1 AND 5),
    primary_triggers    TEXT[],                   -- array of issue_codes
    concentration_notes TEXT,                     -- e.g. 'Strongest in rural piedmont counties'
    go_signal           TEXT,                     -- What activates this archetype for this office
    created_at          TIMESTAMPTZ  DEFAULT NOW(),
    UNIQUE(office_id, archetype_code)
);

-- 3C: CoS Office Geographic Overlay (county-level overrides)
CREATE TABLE state_offices.cos_geographic_overlay (
    overlay_id          SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES state_offices.cos_office_registry(office_id),
    geographic_zone     VARCHAR(50)  NOT NULL,  -- APPALACHIAN, PIEDMONT_URBAN, COASTAL, SANDHILLS, PIEDMONT_RURAL
    issue_id            INTEGER      REFERENCES state_offices.issue_taxonomy(issue_id),
    override_score      SMALLINT     CHECK (override_score BETWEEN 1 AND 5),
    override_reason     TEXT,
    county_list         TEXT[],                 -- ['Buncombe','Haywood','Madison']
    created_at          TIMESTAMPTZ  DEFAULT NOW()
);

-- 3D: CoS Go/No-Go Signals
CREATE TABLE state_offices.cos_signals (
    signal_id           SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES state_offices.cos_office_registry(office_id),
    signal_type         VARCHAR(10)  NOT NULL CHECK (signal_type IN ('GO', 'NOGO')),
    signal_text         TEXT         NOT NULL,
    applies_to          VARCHAR(30)  DEFAULT 'ALL',  -- ALL, PRIMARY, GENERAL, SPECIFIC_ARCHETYPE
    priority_rank       SMALLINT     DEFAULT 1,
    created_at          TIMESTAMPTZ  DEFAULT NOW()
);


-- =====================================================
-- SECTION 4: US HOUSE - ISSUE INTENSITY MATRIX
-- =====================================================

-- 4A: House District × Issue Intensity
CREATE TABLE federal_offices.house_issue_intensity (
    intensity_id        SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES federal_offices.federal_office_registry(office_id),
    issue_id            INTEGER      NOT NULL REFERENCES state_offices.issue_taxonomy(issue_id),
    intensity_score     SMALLINT     NOT NULL CHECK (intensity_score BETWEEN 1 AND 5),
    tier                SMALLINT     NOT NULL CHECK (tier BETWEEN 1 AND 4),
    is_district_override BOOLEAN     DEFAULT FALSE,  -- TRUE = specific to this district, overrides generic
    override_notes      TEXT,
    rationale           TEXT,
    created_at          TIMESTAMPTZ  DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  DEFAULT NOW(),
    UNIQUE(office_id, issue_id)
);

CREATE INDEX idx_house_intensity_office ON federal_offices.house_issue_intensity(office_id);
CREATE INDEX idx_house_intensity_score  ON federal_offices.house_issue_intensity(intensity_score DESC);
CREATE INDEX idx_house_intensity_tier   ON federal_offices.house_issue_intensity(tier);

-- 4B: House District Archetype Match
CREATE TABLE federal_offices.house_archetype_match (
    match_id            SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES federal_offices.federal_office_registry(office_id),
    archetype_code      VARCHAR(20)  NOT NULL,
    archetype_name      VARCHAR(100) NOT NULL,
    activation_level    SMALLINT     NOT NULL CHECK (activation_level BETWEEN 1 AND 5),
    primary_triggers    TEXT[],
    district_notes      TEXT,
    created_at          TIMESTAMPTZ  DEFAULT NOW(),
    UNIQUE(office_id, archetype_code)
);

-- 4C: House District Override Registry (the critical per-district localization table)
CREATE TABLE federal_offices.house_district_overrides (
    override_id         SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES federal_offices.federal_office_registry(office_id),
    issue_id            INTEGER      NOT NULL REFERENCES state_offices.issue_taxonomy(issue_id),
    override_score      SMALLINT     NOT NULL CHECK (override_score BETWEEN 1 AND 5),
    is_number_one       BOOLEAN      DEFAULT FALSE,  -- TRUE = this is THE #1 issue in this district
    override_reason     TEXT         NOT NULL,
    key_location        VARCHAR(200),               -- e.g. 'Fort Liberty (Bragg)'
    created_at          TIMESTAMPTZ  DEFAULT NOW(),
    UNIQUE(office_id, issue_id)
);

-- 4D: House Go/No-Go Signals
CREATE TABLE federal_offices.house_signals (
    signal_id           SERIAL PRIMARY KEY,
    office_id           INTEGER      REFERENCES federal_offices.federal_office_registry(office_id),  -- NULL = applies to all House
    signal_type         VARCHAR(10)  NOT NULL CHECK (signal_type IN ('GO', 'NOGO')),
    signal_text         TEXT         NOT NULL,
    applies_to          VARCHAR(30)  DEFAULT 'ALL',
    priority_rank       SMALLINT     DEFAULT 1,
    created_at          TIMESTAMPTZ  DEFAULT NOW()
);


-- =====================================================
-- SECTION 5: US SENATE - ISSUE INTENSITY MATRIX
-- =====================================================

-- 5A: Senate × Issue Intensity (primary vs general separately)
CREATE TABLE federal_offices.senate_issue_intensity (
    intensity_id        SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES federal_offices.federal_office_registry(office_id),
    issue_id            INTEGER      NOT NULL REFERENCES state_offices.issue_taxonomy(issue_id),
    election_phase      VARCHAR(10)  NOT NULL CHECK (election_phase IN ('PRIMARY', 'GENERAL', 'BOTH')),
    audience_segment    VARCHAR(30)  DEFAULT 'ALL',  -- ALL, MAGA_BASE, ESTABLISHMENT, SUBURBAN
    geographic_zone     VARCHAR(30)  DEFAULT 'STATEWIDE', -- STATEWIDE, COASTAL, PIEDMONT_SUBURBAN, APPALACHIAN, RURAL
    intensity_score     SMALLINT     NOT NULL CHECK (intensity_score BETWEEN 1 AND 5),
    tier                SMALLINT     NOT NULL CHECK (tier BETWEEN 1 AND 4),
    rationale           TEXT,
    created_at          TIMESTAMPTZ  DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  DEFAULT NOW()
    -- Note: No UNIQUE constraint - same issue can appear across multiple phase/segment/geo combos
);

CREATE INDEX idx_senate_intensity_office  ON federal_offices.senate_issue_intensity(office_id);
CREATE INDEX idx_senate_intensity_phase   ON federal_offices.senate_issue_intensity(election_phase);
CREATE INDEX idx_senate_intensity_zone    ON federal_offices.senate_issue_intensity(geographic_zone);
CREATE INDEX idx_senate_intensity_score   ON federal_offices.senate_issue_intensity(intensity_score DESC);

-- 5B: Senate Archetype Match (primary vs general)
CREATE TABLE federal_offices.senate_archetype_match (
    match_id                SERIAL PRIMARY KEY,
    office_id               INTEGER      NOT NULL REFERENCES federal_offices.federal_office_registry(office_id),
    archetype_code          VARCHAR(20)  NOT NULL,
    archetype_name          VARCHAR(100) NOT NULL,
    primary_activation      SMALLINT     CHECK (primary_activation BETWEEN 1 AND 5),
    general_activation      SMALLINT     CHECK (general_activation BETWEEN 1 AND 5),
    primary_triggers        TEXT[],
    general_triggers        TEXT[],
    strategic_note          TEXT,
    go_signal               TEXT,
    created_at              TIMESTAMPTZ  DEFAULT NOW(),
    UNIQUE(office_id, archetype_code)
);

-- 5C: Senate Critical Binary Variables
--     Stores the override variables (e.g. Trump endorsement) that collapse all other scoring
CREATE TABLE federal_offices.senate_binary_overrides (
    override_id         SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES federal_offices.federal_office_registry(office_id),
    variable_name       VARCHAR(100) NOT NULL,   -- e.g. 'trump_endorsement'
    variable_label      VARCHAR(200) NOT NULL,   -- Human-readable
    current_value       VARCHAR(10)  DEFAULT 'UNKNOWN', -- TRUE, FALSE, UNKNOWN, PENDING
    applies_to_phase    VARCHAR(10)  DEFAULT 'PRIMARY',
    score_impact        TEXT,        -- Description of how TRUE/FALSE changes all other scores
    last_updated        TIMESTAMPTZ  DEFAULT NOW(),
    updated_by          VARCHAR(100),
    UNIQUE(office_id, variable_name)
);

INSERT INTO federal_offices.senate_binary_overrides
    (office_id, variable_name, variable_label, current_value, applies_to_phase, score_impact)
SELECT
    r.office_id,
    'trump_endorsement',
    'Trump Endorsement Status',
    'UNKNOWN',
    'PRIMARY',
    'When TRUE: MAGA + Evangelical + Defense donor stacks consolidate automatically. Overrides all other issue scoring in primary mode. When FALSE/UNKNOWN: three-way funding war — platform treats all Senate primary donors as uncommitted regardless of historical giving.'
FROM federal_offices.federal_office_registry r
WHERE r.office_code = 'US_SENATE_NC_C2';

-- 5D: Senate Go/No-Go Signals
CREATE TABLE federal_offices.senate_signals (
    signal_id           SERIAL PRIMARY KEY,
    office_id           INTEGER      NOT NULL REFERENCES federal_offices.federal_office_registry(office_id),
    signal_type         VARCHAR(10)  NOT NULL CHECK (signal_type IN ('GO', 'NOGO')),
    election_phase      VARCHAR(10)  DEFAULT 'BOTH' CHECK (election_phase IN ('PRIMARY', 'GENERAL', 'BOTH')),
    signal_text         TEXT         NOT NULL,
    applies_to          VARCHAR(50)  DEFAULT 'ALL',
    priority_rank       SMALLINT     DEFAULT 1,
    created_at          TIMESTAMPTZ  DEFAULT NOW()
);


-- =====================================================
-- SECTION 6: DONOR ↔ OFFICE AFFINITY EXTENSIONS
-- (extends existing datahub.affinity_scores)
-- =====================================================

-- 6A: Federal/State Office-Level Donor Affinity
--     Extends the existing affinity_scores table with office-specific scoring
CREATE TABLE donor_intelligence.office_affinity_scores (
    affinity_id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id            UUID         NOT NULL REFERENCES datahub.donors(donor_id),
    office_code         VARCHAR(20)  NOT NULL,  -- References office_code from either registry
    office_level        VARCHAR(20)  NOT NULL CHECK (office_level IN ('STATE_COS', 'US_HOUSE', 'US_SENATE')),
    election_phase      VARCHAR(10)  DEFAULT 'GENERAL' CHECK (election_phase IN ('PRIMARY', 'GENERAL', 'BOTH')),

    -- Affinity Scores
    total_affinity_score        INTEGER  DEFAULT 0 CHECK (total_affinity_score BETWEEN 0 AND 100),
    issue_alignment_score       INTEGER  DEFAULT 0,   -- How well donor issues match office issues
    archetype_match_score       INTEGER  DEFAULT 0,   -- How well donor archetype matches office archetypes
    geographic_relevance_score  INTEGER  DEFAULT 0,   -- Is donor in the right district/region
    historical_giving_score     INTEGER  DEFAULT 0,   -- Has donor given to similar offices before

    -- Activation Signals
    top_matching_issues         TEXT[],               -- Issue codes where donor and office both score 4-5
    activated_archetypes        TEXT[],               -- Archetype codes that fire for this donor+office
    helene_activated            BOOLEAN  DEFAULT FALSE,
    military_activated          BOOLEAN  DEFAULT FALSE,
    judicial_activated          BOOLEAN  DEFAULT FALSE,

    -- Output
    recommended_ask_amount      DECIMAL(10,2),
    recommended_message_frame   VARCHAR(50),          -- BORDER, ECONOMY, MILITARY, JUDICIAL, LOCAL
    affinity_category           VARCHAR(20),          -- EXCEPTIONAL, STRONG, GOOD, MODERATE, WEAK

    calculated_at               TIMESTAMPTZ DEFAULT NOW(),
    expires_at                  TIMESTAMPTZ,
    calculation_version         VARCHAR(10),
    UNIQUE(donor_id, office_code, election_phase)
);

CREATE INDEX idx_office_affinity_donor    ON donor_intelligence.office_affinity_scores(donor_id);
CREATE INDEX idx_office_affinity_office   ON donor_intelligence.office_affinity_scores(office_code);
CREATE INDEX idx_office_affinity_score    ON donor_intelligence.office_affinity_scores(total_affinity_score DESC);
CREATE INDEX idx_office_affinity_category ON donor_intelligence.office_affinity_scores(affinity_category);


-- =====================================================
-- SECTION 7: HEAT MAP GENERATION LOG
-- (office-level heat maps — distinct from candidate-level)
-- =====================================================

CREATE TABLE datahub.office_heat_maps (
    heat_map_id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    office_code             VARCHAR(20)  NOT NULL,
    office_level            VARCHAR(20)  NOT NULL,
    election_phase          VARCHAR(10)  DEFAULT 'GENERAL',
    total_donors_evaluated  INTEGER      NOT NULL,
    exceptional_matches     INTEGER      DEFAULT 0,
    strong_matches          INTEGER      DEFAULT 0,
    good_matches            INTEGER      DEFAULT 0,
    top_50_donors           JSONB,
    county_distribution     JSONB,
    archetype_distribution  JSONB,
    issue_activation_counts JSONB,    -- {issue_code: count_of_donors_activated}
    helene_activated_count  INTEGER   DEFAULT 0,
    military_activated_count INTEGER  DEFAULT 0,
    judicial_activated_count INTEGER  DEFAULT 0,
    generated_at            TIMESTAMPTZ DEFAULT NOW(),
    expires_at              TIMESTAMPTZ,
    generation_time_ms      INTEGER
);

CREATE INDEX idx_office_heatmap_code  ON datahub.office_heat_maps(office_code);
CREATE INDEX idx_office_heatmap_level ON datahub.office_heat_maps(office_level);


-- =====================================================
-- SECTION 8: TRIGGERS
-- =====================================================

CREATE TRIGGER update_cos_intensity_timestamp
    BEFORE UPDATE ON state_offices.cos_office_issue_intensity
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_house_intensity_timestamp
    BEFORE UPDATE ON federal_offices.house_issue_intensity
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_senate_intensity_timestamp
    BEFORE UPDATE ON federal_offices.senate_issue_intensity
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();


-- =====================================================
-- SECTION 9: VIEWS
-- =====================================================

-- V1: Council of State - Top Issues per Office (top 5 by score)
CREATE VIEW state_offices.v_cos_top_issues AS
SELECT
    r.office_code,
    r.office_name,
    t.issue_code,
    t.issue_name,
    t.issue_category,
    i.intensity_score,
    i.tier,
    i.is_primary,
    i.is_unique_to_office
FROM state_offices.cos_office_issue_intensity i
JOIN state_offices.cos_office_registry r  ON r.office_id = i.office_id
JOIN state_offices.issue_taxonomy t       ON t.issue_id  = i.issue_id
WHERE i.intensity_score >= 4
ORDER BY r.office_code, i.intensity_score DESC, i.tier;

-- V2: US House - District Override Issues (the localization layer)
CREATE VIEW federal_offices.v_house_district_overrides AS
SELECT
    r.office_code,
    r.district_number,
    r.geographic_character,
    r.competitive_class,
    t.issue_code,
    t.issue_name,
    o.override_score,
    o.is_number_one,
    o.override_reason,
    o.key_location
FROM federal_offices.house_district_overrides o
JOIN federal_offices.federal_office_registry r ON r.office_id = o.office_id
JOIN state_offices.issue_taxonomy t             ON t.issue_id  = o.issue_id
ORDER BY r.district_number, o.is_number_one DESC, o.override_score DESC;

-- V3: Senate - Primary vs General Issue Intensity Comparison
CREATE VIEW federal_offices.v_senate_primary_vs_general AS
SELECT
    t.issue_code,
    t.issue_name,
    p.intensity_score   AS primary_score,
    p.audience_segment  AS primary_audience,
    g.intensity_score   AS general_score,
    g.geographic_zone   AS general_geo_zone,
    (g.intensity_score - p.intensity_score) AS score_shift  -- positive = grows in general
FROM federal_offices.senate_issue_intensity p
JOIN federal_offices.senate_issue_intensity g
    ON p.issue_id = g.issue_id
    AND p.office_id = g.office_id
    AND p.election_phase = 'PRIMARY'
    AND g.election_phase = 'GENERAL'
JOIN state_offices.issue_taxonomy t ON t.issue_id = p.issue_id
JOIN federal_offices.federal_office_registry r ON r.office_id = p.office_id
WHERE r.office_code = 'US_SENATE_NC_C2'
ORDER BY g.intensity_score DESC;

-- V4: Donor Office Affinity - Actionable Pipeline (score >= 60)
CREATE VIEW donor_intelligence.v_office_affinity_pipeline AS
SELECT
    d.donor_id,
    d.first_name,
    d.last_name,
    d.county,
    d.overall_grade,
    oas.office_code,
    oas.office_level,
    oas.election_phase,
    oas.total_affinity_score,
    oas.affinity_category,
    oas.top_matching_issues,
    oas.activated_archetypes,
    oas.recommended_ask_amount,
    oas.recommended_message_frame,
    oas.helene_activated,
    oas.military_activated,
    oas.judicial_activated
FROM donor_intelligence.office_affinity_scores oas
JOIN datahub.donors d ON d.donor_id = oas.donor_id
WHERE oas.total_affinity_score >= 60
ORDER BY oas.total_affinity_score DESC;
