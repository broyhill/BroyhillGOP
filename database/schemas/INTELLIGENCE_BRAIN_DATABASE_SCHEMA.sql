-- INTELLIGENCE BRAIN - DATABASE SCHEMA
-- Ecosystem 20: Complete Schema
-- Integrates with DataHub (Ecosystem 0)

-- Create schema
CREATE SCHEMA IF NOT EXISTS intelligence_brain;

-- ============================================================================
-- EVENT MONITORING TABLES
-- ============================================================================

-- Events detected from 905 types
CREATE TABLE intelligence_brain.events (
    event_id VARCHAR(100) PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    event_category VARCHAR(50) NOT NULL,
    jurisdiction VARCHAR(20) NOT NULL, -- 'LOCAL', 'STATE', 'FEDERAL'
    
    -- Event details
    title TEXT,
    description TEXT,
    source VARCHAR(255),
    source_url TEXT,
    
    -- Location
    location_type VARCHAR(50), -- 'COUNTY', 'CITY', 'DISTRICT', 'STATE', 'NATIONAL'
    location_id VARCHAR(100), -- 'WAKE_COUNTY', 'NC_HOUSE_87', etc.
    location_name VARCHAR(255),
    
    -- Categorization
    issue_category VARCHAR(100),
    hot_button_faction VARCHAR(50),
    
    -- Legislative specific
    bill_number VARCHAR(50),
    chamber VARCHAR(20), -- 'HOUSE', 'SENATE'
    committee VARCHAR(100),
    primary_sponsor VARCHAR(255),
    co_sponsors TEXT[], -- Array of names
    
    -- Timing
    event_timestamp TIMESTAMPTZ NOT NULL,
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    urgency VARCHAR(20), -- 'IMMEDIATE', 'HIGH', 'MEDIUM', 'LOW'
    
    -- Processing
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_type ON intelligence_brain.events(event_type);
CREATE INDEX idx_events_category ON intelligence_brain.events(event_category);
CREATE INDEX idx_events_jurisdiction ON intelligence_brain.events(jurisdiction);
CREATE INDEX idx_events_location ON intelligence_brain.events(location_id);
CREATE INDEX idx_events_timestamp ON intelligence_brain.events(event_timestamp DESC);
CREATE INDEX idx_events_processed ON intelligence_brain.events(processed) WHERE NOT processed;
CREATE INDEX idx_events_urgency ON intelligence_brain.events(urgency);

-- ============================================================================
-- OFFICE & CANDIDATE TABLES
-- ============================================================================

-- Office types (Sheriff, NC House, US Senate, etc.)
CREATE TABLE intelligence_brain.office_types (
    office_type_id SERIAL PRIMARY KEY,
    jurisdiction_level VARCHAR(20) NOT NULL, -- 'LOCAL', 'STATE', 'FEDERAL'
    office_code VARCHAR(50) NOT NULL UNIQUE, -- 'SHERIFF', 'NC_HOUSE', etc.
    office_name VARCHAR(100) NOT NULL,
    
    -- Characteristics
    responsibilities TEXT[], -- Array of responsibility areas
    relevant_event_categories TEXT[], -- Array of event categories
    geographic_scope VARCHAR(50), -- 'COUNTY', 'DISTRICT', 'STATE', 'NATION'
    typical_district_size INTEGER, -- Approximate population
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_office_types_jurisdiction ON intelligence_brain.office_types(jurisdiction_level);
CREATE INDEX idx_office_types_code ON intelligence_brain.office_types(office_code);

-- Candidates
CREATE TABLE intelligence_brain.candidates (
    candidate_id VARCHAR(50) PRIMARY KEY,
    
    -- Basic info
    first_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    office_type_id INTEGER REFERENCES intelligence_brain.office_types(office_type_id),
    
    -- Geographic
    district_id VARCHAR(100), -- 'NC_HOUSE_87', 'WAKE_COUNTY', etc.
    district_name VARCHAR(255),
    district_boundary JSONB, -- GeoJSON polygon
    
    -- Political
    party VARCHAR(50) DEFAULT 'REPUBLICAN',
    faction VARCHAR(50), -- 'MAGA', 'EVANGELICAL', 'FISCAL_CONSERVATIVE', etc.
    ideology_score INTEGER, -- 0-100, 100 = most conservative
    
    -- Committees & Leadership
    committees TEXT[], -- Array of committee names
    subcommittees TEXT[], -- Array of subcommittee names
    leadership_positions TEXT[], -- Array of positions
    
    -- Campaign priorities
    campaign_priority_1 VARCHAR(100), -- Top issue
    campaign_priority_2 VARCHAR(100),
    campaign_priority_3 VARCHAR(100),
    campaign_slogan TEXT,
    
    -- Performance metrics
    voting_record_conservative_score INTEGER, -- 0-100
    fundraising_total DECIMAL(12,2),
    donor_count INTEGER,
    volunteer_count INTEGER,
    
    -- Contact
    campaign_email VARCHAR(255),
    campaign_phone VARCHAR(20),
    personal_cell_phone VARCHAR(20), -- For urgent alerts
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    current_campaign_id VARCHAR(50),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_candidates_office_type ON intelligence_brain.candidates(office_type_id);
CREATE INDEX idx_candidates_district ON intelligence_brain.candidates(district_id);
CREATE INDEX idx_candidates_faction ON intelligence_brain.candidates(faction);
CREATE INDEX idx_candidates_active ON intelligence_brain.candidates(active) WHERE active;

-- Event-Office Relevance
CREATE TABLE intelligence_brain.event_office_relevance (
    event_id VARCHAR(100) REFERENCES intelligence_brain.events(event_id),
    office_type_id INTEGER REFERENCES intelligence_brain.office_types(office_type_id),
    
    -- Relevance scoring
    relevance_score INTEGER NOT NULL, -- 0-100
    relevance_reason TEXT,
    
    -- Match factors
    geographic_match BOOLEAN DEFAULT FALSE,
    responsibility_match BOOLEAN DEFAULT FALSE,
    committee_match BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (event_id, office_type_id)
);

CREATE INDEX idx_event_office_relevance_score ON intelligence_brain.event_office_relevance(relevance_score DESC);

-- Individual Candidate Relevance
CREATE TABLE intelligence_brain.event_candidate_relevance (
    event_id VARCHAR(100) REFERENCES intelligence_brain.events(event_id),
    candidate_id VARCHAR(50) REFERENCES intelligence_brain.candidates(candidate_id),
    
    -- 8-Factor Evaluation
    factor_1_role_score INTEGER DEFAULT 0, -- 0-30 points
    factor_2_district_score INTEGER DEFAULT 0, -- 0-15 points
    factor_3_donor_score INTEGER DEFAULT 0, -- 0-15 points
    factor_4_committee_score INTEGER DEFAULT 0, -- 0-15 points
    factor_5_priority_score INTEGER DEFAULT 0, -- 0-10 points
    factor_6_voting_score INTEGER DEFAULT 0, -- 0-5 points
    factor_7_faction_score INTEGER DEFAULT 0, -- 0-5 points
    factor_8_geo_score INTEGER DEFAULT 0, -- 0-5 points
    
    total_relevance_score INTEGER GENERATED ALWAYS AS (
        factor_1_role_score + factor_2_district_score + factor_3_donor_score +
        factor_4_committee_score + factor_5_priority_score + factor_6_voting_score +
        factor_7_faction_score + factor_8_geo_score
    ) STORED,
    
    -- Role in event
    candidate_role VARCHAR(50), -- 'PRIMARY_SPONSOR', 'CO_SPONSOR', 'COMMITTEE_MEMBER', 'VOTER', etc.
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (event_id, candidate_id)
);

CREATE INDEX idx_event_candidate_relevance_score ON intelligence_brain.event_candidate_relevance(total_relevance_score DESC);
CREATE INDEX idx_event_candidate_role ON intelligence_brain.event_candidate_relevance(candidate_role);

-- ============================================================================
-- DECISION TABLES
-- ============================================================================

-- Campaign Decisions
CREATE TABLE intelligence_brain.decisions (
    decision_id VARCHAR(100) PRIMARY KEY,
    event_id VARCHAR(100) REFERENCES intelligence_brain.events(event_id),
    candidate_id VARCHAR(50) REFERENCES intelligence_brain.candidates(candidate_id),
    
    -- Decision
    decision VARCHAR(20) NOT NULL, -- 'GO', 'NO_GO'
    decision_reason TEXT,
    
    -- Mathematical Models (7 models)
    model_1_expected_roi DECIMAL(10,2),
    model_2_response_probability DECIMAL(5,4),
    model_3_relevance_score INTEGER,
    model_4_expected_cost DECIMAL(10,2),
    model_5_control_panel_approved BOOLEAN,
    model_6_budget_approved BOOLEAN,
    model_7_confidence_score INTEGER,
    
    -- Target metrics
    target_donor_count INTEGER,
    target_volunteer_count INTEGER,
    expected_revenue DECIMAL(12,2),
    
    -- Campaign details
    campaign_id VARCHAR(50),
    primary_channel VARCHAR(50), -- 'EMAIL', 'SMS', 'PHONE', 'PRINT', etc.
    tier VARCHAR(20), -- 'ELITE', 'HIGH', 'MODERATE', 'LIGHT', 'BATCH'
    
    -- Timing
    decision_timestamp TIMESTAMPTZ DEFAULT NOW(),
    campaign_launch_time TIMESTAMPTZ,
    
    -- Results (filled in later)
    actual_sent INTEGER,
    actual_responses INTEGER,
    actual_revenue DECIMAL(12,2),
    actual_roi DECIMAL(10,2),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_decisions_event ON intelligence_brain.decisions(event_id);
CREATE INDEX idx_decisions_candidate ON intelligence_brain.decisions(candidate_id);
CREATE INDEX idx_decisions_decision ON intelligence_brain.decisions(decision);
CREATE INDEX idx_decisions_timestamp ON intelligence_brain.decisions(decision_timestamp DESC);
CREATE INDEX idx_decisions_roi ON intelligence_brain.decisions(model_1_expected_roi DESC);

-- Decision Details (why GO or NO-GO)
CREATE TABLE intelligence_brain.decision_details (
    decision_id VARCHAR(100) REFERENCES intelligence_brain.decisions(decision_id),
    detail_type VARCHAR(50) NOT NULL, -- 'THRESHOLD_FAILED', 'BUDGET_INSUFFICIENT', 'RULE_BLOCKED', etc.
    detail_key VARCHAR(100),
    detail_value TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_decision_details_decision ON intelligence_brain.decision_details(decision_id);

-- ============================================================================
-- COST ACCOUNTING TABLES
-- ============================================================================

-- Cost Accounting (5-Level Hierarchy)
CREATE TABLE intelligence_brain.cost_accounting (
    cost_center_id VARCHAR(200) PRIMARY KEY,
    
    -- Hierarchy
    level VARCHAR(20) NOT NULL, -- 'UNIVERSE', 'CANDIDATE', 'CAMPAIGN', 'CHANNEL', 'TIER'
    entity_id VARCHAR(100) NOT NULL, -- 'ALL', candidate_id, campaign_id, etc.
    
    -- Parent relationships
    parent_cost_center_id VARCHAR(200), -- For hierarchy navigation
    
    -- Budget
    budget DECIMAL(12,2) NOT NULL DEFAULT 0,
    actual DECIMAL(12,2) NOT NULL DEFAULT 0,
    variance DECIMAL(12,2) GENERATED ALWAYS AS (budget - actual) STORED,
    percent_used DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN budget > 0 THEN (actual / budget * 100) ELSE 0 END
    ) STORED,
    
    -- Status
    status VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN budget = 0 THEN 'NO_BUDGET'
            WHEN actual / NULLIF(budget, 0) >= 0.95 THEN 'CRITICAL'
            WHEN actual / NULLIF(budget, 0) >= 0.90 THEN 'WARNING'
            ELSE 'OK'
        END
    ) STORED,
    
    -- Metadata
    time_period VARCHAR(50), -- 'MONTHLY', 'WEEKLY', 'CAMPAIGN', etc.
    period_start DATE,
    period_end DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cost_accounting_level ON intelligence_brain.cost_accounting(level);
CREATE INDEX idx_cost_accounting_entity ON intelligence_brain.cost_accounting(entity_id);
CREATE INDEX idx_cost_accounting_status ON intelligence_brain.cost_accounting(status);
CREATE INDEX idx_cost_accounting_parent ON intelligence_brain.cost_accounting(parent_cost_center_id);

-- Cost Transactions
CREATE TABLE intelligence_brain.cost_transactions (
    transaction_id VARCHAR(100) PRIMARY KEY,
    
    -- Hierarchy identifiers (for updating 5 levels)
    candidate_id VARCHAR(50),
    campaign_id VARCHAR(50),
    channel VARCHAR(50),
    tier VARCHAR(20),
    
    -- Transaction details
    cost_type VARCHAR(50), -- 'AI_API', 'VENDOR', 'PRODUCTION', etc.
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    
    -- Reference
    decision_id VARCHAR(100) REFERENCES intelligence_brain.decisions(decision_id),
    
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cost_transactions_candidate ON intelligence_brain.cost_transactions(candidate_id);
CREATE INDEX idx_cost_transactions_campaign ON intelligence_brain.cost_transactions(campaign_id);
CREATE INDEX idx_cost_transactions_timestamp ON intelligence_brain.cost_transactions(timestamp DESC);
CREATE INDEX idx_cost_transactions_type ON intelligence_brain.cost_transactions(cost_type);

-- ============================================================================
-- CONTROL PANEL TABLES
-- ============================================================================

-- Control Panel Rules (247 rules × 5,000 campaigns = 1.2M rules)
CREATE TABLE intelligence_brain.control_panel_rules (
    rule_id VARCHAR(100) PRIMARY KEY,
    candidate_id VARCHAR(50) REFERENCES intelligence_brain.candidates(candidate_id),
    
    -- Rule details
    rule_type VARCHAR(50) NOT NULL, -- 'BLOCK_ISSUE', 'BLOCK_CHANNEL', 'BLOCK_TIMING', 'REQUIRE_APPROVAL', etc.
    rule_name VARCHAR(255),
    rule_description TEXT,
    
    -- Rule parameters (JSONB for flexibility)
    rule_parameters JSONB,
    
    -- Action
    action VARCHAR(50) NOT NULL, -- 'BLOCK', 'REQUIRE_APPROVAL', 'LIMIT', 'OVERRIDE'
    
    -- Priority
    priority INTEGER DEFAULT 100, -- Lower = higher priority
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_control_panel_candidate ON intelligence_brain.control_panel_rules(candidate_id);
CREATE INDEX idx_control_panel_type ON intelligence_brain.control_panel_rules(rule_type);
CREATE INDEX idx_control_panel_active ON intelligence_brain.control_panel_rules(active) WHERE active;
CREATE INDEX idx_control_panel_priority ON intelligence_brain.control_panel_rules(priority);

-- Rule Evaluation Log
CREATE TABLE intelligence_brain.rule_evaluations (
    evaluation_id VARCHAR(100) PRIMARY KEY,
    decision_id VARCHAR(100) REFERENCES intelligence_brain.decisions(decision_id),
    rule_id VARCHAR(100) REFERENCES intelligence_brain.control_panel_rules(rule_id),
    
    -- Evaluation
    rule_applies BOOLEAN,
    rule_action VARCHAR(50),
    reason TEXT,
    
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_rule_evaluations_decision ON intelligence_brain.rule_evaluations(decision_id);
CREATE INDEX idx_rule_evaluations_rule ON intelligence_brain.rule_evaluations(rule_id);

-- ============================================================================
-- MACHINE LEARNING TABLES
-- ============================================================================

-- ML Model Metadata
CREATE TABLE intelligence_brain.ml_models (
    model_id VARCHAR(100) PRIMARY KEY,
    model_name VARCHAR(255) NOT NULL,
    model_type VARCHAR(100), -- 'RESPONSE_PREDICTION', 'ROI_OPTIMIZATION', 'TIMING_OPTIMIZATION'
    
    -- Performance metrics
    accuracy DECIMAL(5,4),
    precision_score DECIMAL(5,4),
    recall SCORE DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    
    -- Training
    training_samples INTEGER,
    training_date TIMESTAMPTZ,
    
    -- Model file
    model_file_path TEXT,
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ML Predictions
CREATE TABLE intelligence_brain.ml_predictions (
    prediction_id VARCHAR(100) PRIMARY KEY,
    model_id VARCHAR(100) REFERENCES intelligence_brain.ml_models(model_id),
    decision_id VARCHAR(100) REFERENCES intelligence_brain.decisions(decision_id),
    
    -- Prediction
    predicted_response BOOLEAN,
    predicted_probability DECIMAL(5,4),
    confidence DECIMAL(5,4),
    
    -- Actual (filled in later)
    actual_response BOOLEAN,
    prediction_correct BOOLEAN,
    
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ml_predictions_model ON intelligence_brain.ml_predictions(model_id);
CREATE INDEX idx_ml_predictions_decision ON intelligence_brain.ml_predictions(decision_id);

-- Training Data
CREATE TABLE intelligence_brain.ml_training_data (
    training_id VARCHAR(100) PRIMARY KEY,
    
    -- Features (JSONB for flexibility)
    features JSONB NOT NULL,
    
    -- Label
    label BOOLEAN NOT NULL, -- Did donor respond?
    
    -- Reference
    decision_id VARCHAR(100),
    donor_id VARCHAR(50),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ml_training_data_label ON intelligence_brain.ml_training_data(label);

-- ============================================================================
-- DONOR-OFFICE TARGETING TABLES
-- ============================================================================

-- Donor-Office Targeting (pre-computed for speed)
CREATE TABLE intelligence_brain.donor_office_targeting (
    donor_id VARCHAR(50) NOT NULL,
    office_type_id INTEGER REFERENCES intelligence_brain.office_types(office_type_id),
    
    -- Match factors
    geographic_match BOOLEAN DEFAULT FALSE, -- Donor in jurisdiction
    issue_match_score INTEGER DEFAULT 0, -- 0-100
    faction_alignment BOOLEAN DEFAULT FALSE,
    donation_level_match VARCHAR(10), -- 'F', 'S', 'L'
    
    -- Historical performance
    expected_response_rate DECIMAL(5,4),
    average_gift DECIMAL(10,2),
    
    -- Updated nightly
    last_calculated TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (donor_id, office_type_id)
);

CREATE INDEX idx_donor_office_donor ON intelligence_brain.donor_office_targeting(donor_id);
CREATE INDEX idx_donor_office_office ON intelligence_brain.donor_office_targeting(office_type_id);
CREATE INDEX idx_donor_office_match ON intelligence_brain.donor_office_targeting(issue_match_score DESC);

-- ============================================================================
-- SYSTEM TABLES
-- ============================================================================

-- System Configuration
CREATE TABLE intelligence_brain.system_config (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value TEXT NOT NULL,
    config_type VARCHAR(50), -- 'STRING', 'INTEGER', 'BOOLEAN', 'JSON'
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default configs
INSERT INTO intelligence_brain.system_config (config_key, config_value, config_type, description) VALUES
('roi_threshold', '10.0', 'DECIMAL', 'Minimum ROI for GO decision (10:1)'),
('relevance_threshold', '95', 'INTEGER', 'Minimum relevance score for GO decision'),
('event_processing_threads', '20', 'INTEGER', 'Number of parallel event processing threads'),
('ml_retrain_frequency_days', '1', 'INTEGER', 'How often to retrain ML models (days)'),
('decision_log_retention_days', '365', 'INTEGER', 'How long to keep decision logs'),
('enable_ml_predictions', 'true', 'BOOLEAN', 'Use ML predictions in decisions'),
('enable_control_panel', 'true', 'BOOLEAN', 'Enforce control panel rules'),
('enable_budget_enforcement', 'true', 'BOOLEAN', 'Enforce budget limits');

-- System Logs
CREATE TABLE intelligence_brain.system_logs (
    log_id VARCHAR(100) PRIMARY KEY,
    log_level VARCHAR(20), -- 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'
    component VARCHAR(100), -- 'EVENT_MONITOR', 'DECISION_ENGINE', 'COST_ACCOUNTING', etc.
    message TEXT,
    details JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_system_logs_level ON intelligence_brain.system_logs(log_level);
CREATE INDEX idx_system_logs_component ON intelligence_brain.system_logs(component);
CREATE INDEX idx_system_logs_timestamp ON intelligence_brain.system_logs(timestamp DESC);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Dashboard: Active Decisions Pending
CREATE VIEW intelligence_brain.v_decisions_pending AS
SELECT 
    d.decision_id,
    d.event_id,
    e.title AS event_title,
    d.candidate_id,
    c.first_name || ' ' || c.last_name AS candidate_name,
    c.office_code,
    d.model_1_expected_roi,
    d.model_3_relevance_score,
    d.target_donor_count,
    d.expected_revenue,
    d.decision_timestamp,
    d.campaign_launch_time
FROM intelligence_brain.decisions d
JOIN intelligence_brain.events e ON d.event_id = e.event_id
JOIN intelligence_brain.candidates c ON d.candidate_id = c.candidate_id
JOIN intelligence_brain.office_types ot ON c.office_type_id = ot.office_type_id
WHERE d.decision = 'GO'
  AND d.campaign_launch_time > NOW()
ORDER BY d.campaign_launch_time;

-- Dashboard: Budget Status by Level
CREATE VIEW intelligence_brain.v_budget_status AS
SELECT 
    level,
    entity_id,
    budget,
    actual,
    variance,
    percent_used,
    status,
    updated_at
FROM intelligence_brain.cost_accounting
ORDER BY level, entity_id;

-- Dashboard: Top Performing Candidates by ROI
CREATE VIEW intelligence_brain.v_candidates_roi AS
SELECT 
    c.candidate_id,
    c.first_name || ' ' || c.last_name AS candidate_name,
    ot.office_name,
    c.district_name,
    COUNT(d.decision_id) AS total_campaigns,
    SUM(d.expected_revenue) AS total_expected_revenue,
    SUM(d.actual_revenue) AS total_actual_revenue,
    AVG(d.actual_roi) AS average_roi,
    SUM(CASE WHEN d.decision = 'GO' THEN 1 ELSE 0 END) AS go_decisions,
    SUM(CASE WHEN d.decision = 'NO_GO' THEN 1 ELSE 0 END) AS no_go_decisions
FROM intelligence_brain.candidates c
JOIN intelligence_brain.office_types ot ON c.office_type_id = ot.office_type_id
LEFT JOIN intelligence_brain.decisions d ON c.candidate_id = d.candidate_id
WHERE c.active = TRUE
GROUP BY c.candidate_id, c.first_name, c.last_name, ot.office_name, c.district_name
ORDER BY average_roi DESC NULLS LAST;

-- Dashboard: Event Processing Queue
CREATE VIEW intelligence_brain.v_event_queue AS
SELECT 
    e.event_id,
    e.event_type,
    e.event_category,
    e.title,
    e.jurisdiction,
    e.location_name,
    e.urgency,
    e.event_timestamp,
    e.detected_at,
    (NOW() - e.detected_at) AS age,
    COUNT(ecr.candidate_id) AS candidates_evaluated,
    SUM(CASE WHEN d.decision = 'GO' THEN 1 ELSE 0 END) AS go_decisions
FROM intelligence_brain.events e
LEFT JOIN intelligence_brain.event_candidate_relevance ecr ON e.event_id = ecr.event_id
LEFT JOIN intelligence_brain.decisions d ON e.event_id = d.event_id
WHERE NOT e.processed
GROUP BY e.event_id
ORDER BY e.urgency DESC, e.detected_at;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function: Get Budget Remaining
CREATE OR REPLACE FUNCTION intelligence_brain.get_budget_remaining(
    p_level VARCHAR,
    p_entity_id VARCHAR
) RETURNS DECIMAL AS $$
DECLARE
    v_remaining DECIMAL;
BEGIN
    SELECT (budget - actual) INTO v_remaining
    FROM intelligence_brain.cost_accounting
    WHERE level = p_level
      AND entity_id = p_entity_id;
    
    RETURN COALESCE(v_remaining, 0);
END;
$$ LANGUAGE plpgsql;

-- Function: Record Cost Transaction
CREATE OR REPLACE FUNCTION intelligence_brain.record_cost_transaction(
    p_transaction_id VARCHAR,
    p_candidate_id VARCHAR,
    p_campaign_id VARCHAR,
    p_channel VARCHAR,
    p_tier VARCHAR,
    p_amount DECIMAL,
    p_cost_type VARCHAR
) RETURNS VOID AS $$
BEGIN
    -- Insert transaction
    INSERT INTO intelligence_brain.cost_transactions (
        transaction_id, candidate_id, campaign_id, channel, tier,
        amount, cost_type, timestamp
    ) VALUES (
        p_transaction_id, p_candidate_id, p_campaign_id, p_channel, p_tier,
        p_amount, p_cost_type, NOW()
    );
    
    -- Update all 5 levels
    -- Universe
    UPDATE intelligence_brain.cost_accounting
    SET actual = actual + p_amount,
        updated_at = NOW()
    WHERE level = 'UNIVERSE' AND entity_id = 'ALL';
    
    -- Candidate
    UPDATE intelligence_brain.cost_accounting
    SET actual = actual + p_amount,
        updated_at = NOW()
    WHERE level = 'CANDIDATE' AND entity_id = p_candidate_id;
    
    -- Campaign
    UPDATE intelligence_brain.cost_accounting
    SET actual = actual + p_amount,
        updated_at = NOW()
    WHERE level = 'CAMPAIGN' AND entity_id = p_campaign_id;
    
    -- Channel
    UPDATE intelligence_brain.cost_accounting
    SET actual = actual + p_amount,
        updated_at = NOW()
    WHERE level = 'CHANNEL' AND entity_id = p_campaign_id || ':' || p_channel;
    
    -- Tier
    UPDATE intelligence_brain.cost_accounting
    SET actual = actual + p_amount,
        updated_at = NOW()
    WHERE level = 'TIER' AND entity_id = p_campaign_id || ':' || p_channel || ':' || p_tier;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger: Update candidate updated_at
CREATE OR REPLACE FUNCTION intelligence_brain.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER candidates_updated_at
    BEFORE UPDATE ON intelligence_brain.candidates
    FOR EACH ROW
    EXECUTE FUNCTION intelligence_brain.update_updated_at();

CREATE TRIGGER control_panel_rules_updated_at
    BEFORE UPDATE ON intelligence_brain.control_panel_rules
    FOR EACH ROW
    EXECUTE FUNCTION intelligence_brain.update_updated_at();

-- ============================================================================
-- SAMPLE DATA (for testing)
-- ============================================================================

-- Insert office types
INSERT INTO intelligence_brain.office_types (jurisdiction_level, office_code, office_name, responsibilities, relevant_event_categories, geographic_scope) VALUES
('LOCAL', 'SHERIFF', 'County Sheriff', ARRAY['Crime', 'Jail', 'Law Enforcement', 'Court Security'], ARRAY['CRIME', 'LAW_ENFORCEMENT', 'PUBLIC_SAFETY'], 'COUNTY'),
('LOCAL', 'MAYOR', 'City Mayor', ARRAY['City Budget', 'Infrastructure', 'Economic Development'], ARRAY['INFRASTRUCTURE', 'ECONOMIC', 'MUNICIPAL'], 'CITY'),
('LOCAL', 'SCHOOL_BOARD', 'School Board Member', ARRAY['Education', 'Curriculum', 'Budget', 'Facilities'], ARRAY['EDUCATION', 'PARENTAL_RIGHTS', 'CRT'], 'DISTRICT'),
('STATE', 'NC_HOUSE', 'NC House of Representatives', ARRAY['Legislation', 'Committees', 'Voting'], ARRAY['LEGISLATION', 'POLICY', 'STATE_ISSUES'], 'DISTRICT'),
('STATE', 'NC_SENATE', 'NC Senate', ARRAY['Legislation', 'Confirmations', 'Voting'], ARRAY['LEGISLATION', 'POLICY', 'STATE_ISSUES'], 'DISTRICT'),
('FEDERAL', 'US_HOUSE', 'US House of Representatives', ARRAY['Federal Legislation', 'Oversight', 'Committees'], ARRAY['FEDERAL_POLICY', 'NATIONAL_ISSUES'], 'DISTRICT'),
('FEDERAL', 'US_SENATE', 'US Senate', ARRAY['Federal Legislation', 'Confirmations', 'Treaties'], ARRAY['FEDERAL_POLICY', 'NATIONAL_ISSUES', 'CONFIRMATIONS'], 'STATE');

-- Insert sample candidate
INSERT INTO intelligence_brain.candidates (
    candidate_id, first_name, last_name, office_type_id, district_id, district_name,
    faction, committees, campaign_priority_1, campaign_priority_2, campaign_priority_3
) VALUES (
    'CAND_BROYHILL_001',
    'Eddie',
    'Broyhill',
    (SELECT office_type_id FROM intelligence_brain.office_types WHERE office_code = 'NC_HOUSE'),
    'NC_HOUSE_87',
    'House District 87 (Wake County)',
    'EVANGELICAL',
    ARRAY['Education', 'Judiciary', 'Finance'],
    'PARENTAL_RIGHTS',
    'CRIME',
    'TAXES'
);

-- Insert sample cost centers (5 levels)
INSERT INTO intelligence_brain.cost_accounting (cost_center_id, level, entity_id, budget) VALUES
('UNIVERSE', 'UNIVERSE', 'ALL', 10000000), -- $10M total
('CAND_BROYHILL_001', 'CANDIDATE', 'CAND_BROYHILL_001', 100000), -- $100K per candidate
('CAMP_BROYHILL_001', 'CAMPAIGN', 'CAMP_BROYHILL_001', 5000), -- $5K per campaign
('CAMP_BROYHILL_001:EMAIL', 'CHANNEL', 'CAMP_BROYHILL_001:EMAIL', 2000), -- $2K for email
('CAMP_BROYHILL_001:EMAIL:ELITE', 'TIER', 'CAMP_BROYHILL_001:EMAIL:ELITE', 1000); -- $1K for elite tier

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Composite indexes for common queries
CREATE INDEX idx_decisions_candidate_timestamp ON intelligence_brain.decisions(candidate_id, decision_timestamp DESC);
CREATE INDEX idx_events_category_timestamp ON intelligence_brain.events(event_category, event_timestamp DESC);
CREATE INDEX idx_cost_transactions_candidate_timestamp ON intelligence_brain.cost_transactions(candidate_id, timestamp DESC);

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

-- Grant permissions to application user
GRANT USAGE ON SCHEMA intelligence_brain TO broyhillgop_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA intelligence_brain TO broyhillgop_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA intelligence_brain TO broyhillgop_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA intelligence_brain TO broyhillgop_app;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Intelligence Brain Schema Deployed Successfully';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Tables Created: %', (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'intelligence_brain');
    RAISE NOTICE 'Indexes Created: %', (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'intelligence_brain');
    RAISE NOTICE 'Functions Created: %', (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'intelligence_brain');
    RAISE NOTICE '============================================';
END $$;
