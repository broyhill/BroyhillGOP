-- ============================================================================
-- BROYHILLGOP MASTER UPLOAD SYSTEM - SQL SCHEMA
-- Mecklenburg County Local Candidates Database
-- December 3, 2025
-- ============================================================================

-- Drop existing tables if they exist (for clean deployment)
DROP TABLE IF EXISTS local_candidate_assignments CASCADE;
DROP TABLE IF EXISTS local_accountability_metrics CASCADE;
DROP TABLE IF EXISTS local_campaign_messaging CASCADE;
DROP TABLE IF EXISTS local_office_strategies CASCADE;
DROP TABLE IF EXISTS local_office_metadata CASCADE;
DROP TABLE IF EXISTS mecklenburg_offices CASCADE;

-- ============================================================================
-- 1. MECKLENBURG OFFICES REGISTRY
-- ============================================================================

CREATE TABLE mecklenburg_offices (
    office_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Office Classification
    office_type VARCHAR(50) NOT NULL,  -- 'school_board', 'sheriff', 'district_attorney'
    office_name VARCHAR(200) NOT NULL,
    county_name VARCHAR(50) NOT NULL DEFAULT 'Mecklenburg',
    county_fips VARCHAR(5) NOT NULL DEFAULT '25119',
    
    -- Office Details
    total_seats INT NOT NULL,
    partisan_election BOOLEAN DEFAULT true,
    term_years INT DEFAULT 4,
    
    -- Current Status
    current_control VARCHAR(20),  -- '4R/5D', 'D', 'R'
    republican_seats INT,
    democrat_seats INT,
    
    -- Election Info
    term_ends DATE,
    election_year INT DEFAULT 2026,
    filing_deadline DATE,
    primary_date DATE,
    general_date DATE,
    
    -- Current Holders (JSON array for multi-seat)
    current_holders JSONB,  -- [{"name": "...", "party": "D", "term_end": "..."}, ...]
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_office_county UNIQUE(office_type, county_name)
);

-- Index for fast lookup
CREATE INDEX idx_mecklenburg_offices_type ON mecklenburg_offices(office_type);
CREATE INDEX idx_mecklenburg_offices_year ON mecklenburg_offices(election_year);

-- ============================================================================
-- 2. LOCAL OFFICE STRATEGIES (Master Documents)
-- ============================================================================

CREATE TABLE local_office_strategies (
    strategy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID NOT NULL REFERENCES mecklenburg_offices(office_id) ON DELETE CASCADE,
    
    -- Document Metadata
    strategy_title VARCHAR(300) NOT NULL,
    document_type VARCHAR(50) NOT NULL,  -- 'office_strategy', 'governance_framework', 'campaign_guide'
    version INT DEFAULT 1,
    status VARCHAR(20) DEFAULT 'draft',  -- 'draft', 'published', 'archived'
    
    -- Content Sections (as JSON for flexibility)
    constitutional_authority JSONB,  -- Role, jurisdiction, authority
    governance_framework JSONB,      -- Core mission, priorities, governance approach
    current_performance JSONB,       -- Performance data, metrics, trends
    
    -- Campaign Strategy
    campaign_messaging JSONB,        -- Core messages, talking points, positioning
    candidate_vetting JSONB,         -- Vetting questionnaire template
    donor_positioning JSONB,         -- Donor appeal language
    
    -- Inflammatory Issues
    inflammatory_issues JSONB,       -- Array of issue contexts with responses
    
    -- Audit Trail
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    published_at TIMESTAMP,
    
    CONSTRAINT unique_strategy_version UNIQUE(office_id, version)
);

CREATE INDEX idx_strategies_office ON local_office_strategies(office_id);
CREATE INDEX idx_strategies_status ON local_office_strategies(status);

-- ============================================================================
-- 3. ACCOUNTABILITY METRICS (Per Office)
-- ============================================================================

CREATE TABLE local_accountability_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES local_office_strategies(strategy_id) ON DELETE CASCADE,
    
    -- Metric Classification
    category VARCHAR(50) NOT NULL,  -- e.g., 'violent_crime', 'drug_prosecution', 'victim_support'
    metric_name VARCHAR(200) NOT NULL,
    metric_description TEXT,
    
    -- Target Values (What we measure)
    measurement_unit VARCHAR(50),     -- 'percentage', 'count', 'dollars', 'days'
    baseline_value DECIMAL(12,2),     -- Current/baseline value
    target_value DECIMAL(12,2),       -- Goal value
    measurement_period VARCHAR(50),   -- 'annual', 'monthly', 'quarterly'
    
    -- Governance Context
    alignment_priority INT,           -- 1-10 importance score
    conservative_priority BOOLEAN,    -- Is this a conservative priority?
    
    -- Data & Tracking
    current_value DECIMAL(12,2),
    last_updated DATE,
    data_source VARCHAR(200),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_metrics_strategy ON local_accountability_metrics(strategy_id);
CREATE INDEX idx_metrics_category ON local_accountability_metrics(category);

-- ============================================================================
-- 4. CAMPAIGN MESSAGING (By Office)
-- ============================================================================

CREATE TABLE local_campaign_messaging (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES local_office_strategies(strategy_id) ON DELETE CASCADE,
    
    -- Message Type
    message_type VARCHAR(50) NOT NULL,  -- 'core_message', 'talking_point', 'response', 'sound_bite'
    category VARCHAR(100),               -- Topic category
    
    -- Message Content
    title VARCHAR(200),
    message_text TEXT NOT NULL,
    expanded_explanation TEXT,
    
    -- Usage Context
    target_audience VARCHAR(50),  -- 'base', 'persuadable', 'donors', 'volunteers'
    context_issue VARCHAR(100),   -- What issue/attack this addresses
    
    -- Effectiveness
    impact_score INT,  -- 0-100 estimated effectiveness
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_messaging_strategy ON local_campaign_messaging(strategy_id);
CREATE INDEX idx_messaging_type ON local_campaign_messaging(message_type);

-- ============================================================================
-- 5. OFFICE METADATA (Tracking & Audit)
-- ============================================================================

CREATE TABLE local_office_metadata (
    metadata_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID NOT NULL REFERENCES mecklenburg_offices(office_id) ON DELETE CASCADE,
    
    -- Document Tracking
    documents_count INT DEFAULT 0,
    latest_strategy_id UUID REFERENCES local_office_strategies(strategy_id),
    
    -- Content Summary
    metrics_count INT DEFAULT 0,
    messaging_count INT DEFAULT 0,
    inflammatory_issues_count INT DEFAULT 0,
    
    -- Completeness
    completion_percentage INT DEFAULT 0,  -- 0-100%
    quality_score INT DEFAULT 0,          -- 0-100
    ready_for_deployment BOOLEAN DEFAULT false,
    
    -- Deployment Status
    deployment_environment VARCHAR(20),   -- 'staging', 'production', 'test'
    deployment_date TIMESTAMP,
    deployment_status VARCHAR(20),        -- 'pending', 'deployed', 'active', 'archived'
    
    -- Notes
    deployment_notes TEXT,
    issues_identified TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- 6. CANDIDATE ASSIGNMENTS (Track candidates for each office)
-- ============================================================================

CREATE TABLE local_candidate_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID NOT NULL REFERENCES mecklenburg_offices(office_id) ON DELETE CASCADE,
    strategy_id UUID NOT NULL REFERENCES local_office_strategies(strategy_id),
    
    -- Candidate Info
    candidate_name VARCHAR(200),
    candidate_email VARCHAR(255),
    candidate_phone VARCHAR(20),
    candidate_county VARCHAR(50),
    
    -- Assignment Details
    seat_number INT,
    status VARCHAR(20),  -- 'potential', 'contacted', 'committed', 'filed', 'active', 'elected', 'lost'
    assigned_date TIMESTAMP DEFAULT NOW(),
    
    -- Training & Onboarding
    tutorial_track_assigned BOOLEAN DEFAULT false,
    tutorial_progress INT DEFAULT 0,  -- 0-100%
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_assignments_office ON local_candidate_assignments(office_id);
CREATE INDEX idx_assignments_status ON local_candidate_assignments(status);

-- ============================================================================
-- 7. DEPLOYMENT LOG (Track all uploads & deployments)
-- ============================================================================

CREATE TABLE deployment_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Deployment Info
    deployment_id VARCHAR(100),
    deployment_type VARCHAR(50),  -- 'document_upload', 'ecosystem_deploy', 'database_init'
    office_type VARCHAR(50),
    
    -- Status
    status VARCHAR(20),  -- 'pending', 'in_progress', 'success', 'failed'
    error_message TEXT,
    
    -- Timing
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    duration_seconds INT,
    
    -- Details
    items_deployed INT DEFAULT 0,
    environment VARCHAR(20),  -- 'staging', 'production', 'test'
    deployed_by VARCHAR(100),
    
    -- Metadata
    details JSONB,  -- Additional deployment details
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_deployment_log_status ON deployment_log(status);
CREATE INDEX idx_deployment_log_office ON deployment_log(office_type);

-- ============================================================================
-- 8. ANALYTICS & REPORTING
-- ============================================================================

CREATE TABLE local_deployment_analytics (
    analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Coverage Metrics
    total_offices_mecklenburg INT DEFAULT 3,
    offices_complete INT DEFAULT 0,
    offices_in_progress INT DEFAULT 0,
    offices_pending INT DEFAULT 0,
    
    -- Document Metrics
    total_documents INT DEFAULT 0,
    documents_published INT DEFAULT 0,
    documents_draft INT DEFAULT 0,
    
    -- Strategy Coverage
    total_strategies INT DEFAULT 0,
    strategies_complete INT DEFAULT 0,
    completion_percentage INT DEFAULT 0,
    
    -- Candidate Engagement
    total_candidates_assigned INT DEFAULT 0,
    candidates_active INT DEFAULT 0,
    candidates_completed_training INT DEFAULT 0,
    
    -- Performance
    system_health VARCHAR(20),  -- 'healthy', 'warning', 'critical'
    last_deployment_status VARCHAR(20),
    
    -- Timestamps
    calculated_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- INITIAL DATA: POPULATE MECKLENBURG OFFICES
-- ============================================================================

INSERT INTO mecklenburg_offices (
    office_type, office_name, county_name, county_fips, total_seats,
    term_ends, election_year, current_control, republican_seats, democrat_seats
) VALUES
    -- School Board
    (
        'school_board',
        'Mecklenburg County School Board',
        'Mecklenburg', '25119',
        9,
        '2026-06-30', 2026,
        '4R/5D', 4, 5
    ),
    -- Sheriff
    (
        'sheriff',
        'Mecklenburg County Sheriff',
        'Mecklenburg', '25119',
        1,
        '2026-12-07', 2026,
        'D', 0, 1
    ),
    -- District Attorney
    (
        'district_attorney',
        'Mecklenburg County District Attorney',
        'Mecklenburg', '25119',
        1,
        '2026-12-07', 2026,
        'D', 0, 1
    );

-- ============================================================================
-- VIEWS FOR REPORTING
-- ============================================================================

-- View: All Mecklenburg Offices with Strategy Status
CREATE VIEW vw_mecklenburg_office_status AS
SELECT 
    mo.office_id,
    mo.office_type,
    mo.office_name,
    mo.total_seats,
    mo.current_control,
    COUNT(DISTINCT los.strategy_id) as strategy_count,
    MAX(los.published_at) as latest_publication,
    CASE WHEN los.status = 'published' THEN 'Published' ELSE 'Draft' END as status,
    lom.completion_percentage,
    lom.deployment_status
FROM mecklenburg_offices mo
LEFT JOIN local_office_strategies los ON mo.office_id = los.office_id
LEFT JOIN local_office_metadata lom ON mo.office_id = lom.office_id
GROUP BY mo.office_id, mo.office_type, mo.office_name, mo.total_seats, mo.current_control, los.status, lom.completion_percentage, lom.deployment_status;

-- View: Deployment Readiness
CREATE VIEW vw_deployment_readiness AS
SELECT
    mo.office_type,
    COUNT(*) as total_offices,
    COUNT(CASE WHEN lom.ready_for_deployment THEN 1 END) as ready_for_deployment,
    ROUND(
        (COUNT(CASE WHEN lom.ready_for_deployment THEN 1 END)::NUMERIC / COUNT(*)::NUMERIC * 100),
        2
    ) as readiness_percentage
FROM mecklenburg_offices mo
LEFT JOIN local_office_metadata lom ON mo.office_id = lom.office_id
GROUP BY mo.office_type;

-- View: Accountability Metrics by Office
CREATE VIEW vw_accountability_metrics_by_office AS
SELECT
    mo.office_type,
    COUNT(DISTINCT lam.category) as metric_categories,
    COUNT(lam.metric_id) as total_metrics,
    AVG(lam.alignment_priority) as avg_priority,
    COUNT(CASE WHEN lam.conservative_priority THEN 1 END) as conservative_priorities
FROM mecklenburg_offices mo
LEFT JOIN local_office_strategies los ON mo.office_id = los.office_id
LEFT JOIN local_accountability_metrics lam ON los.strategy_id = lam.strategy_id
GROUP BY mo.office_type;

-- ============================================================================
-- END SQL SCHEMA
-- ============================================================================

-- Run this migration with:
-- psql -U broyhillgop -d broyhillgop -f mecklenburg_local_schema.sql
