-- ============================================================================
-- NEXUS PLATFORM INTEGRATION
-- ============================================================================
-- Integrates NEXUS AI Agents with existing BroyhillGOP architecture
-- Follows: Brain Control, Intelligence Brain, Cost Accounting protocols
-- 
-- RUN AFTER:
--   001_brain_core_schema.sql
--   002_brain_cost_accounting.sql
--   INTELLIGENCE_BRAIN_DATABASE_SCHEMA.sql
--   001_NEXUS_SOCIAL_EXTENSION.sql
--   002_NEXUS_HARVEST_ENRICHMENT.sql
-- ============================================================================

-- ============================================================================
-- PART 1: REGISTER NEXUS AS ECOSYSTEM (Following brain_control protocol)
-- ============================================================================

-- Register NEXUS in brain_control.ecosystems
INSERT INTO brain_control.ecosystems (
    ecosystem_code,
    ecosystem_name,
    description,
    schema_name,
    api_prefix,
    status,
    criticality,
    dependencies,
    provides_to,
    ai_powered,
    ai_provider,
    ai_primary_model,
    monthly_budget,
    cost_center,
    tables_count,
    functions_count
) VALUES (
    'NEXUS',
    'NEXUS AI Agent System',
    'Social media integration, harvest enrichment, persona matching, ML optimization',
    'public',
    '/api/nexus',
    'ACTIVE',
    'HIGH',
    ARRAY['E0_DATAHUB', 'E1_DONOR_INTEL', 'E5_VOLUNTEER', 'E7_ISSUES', 'E13_AI_HUB', 'E19_SOCIAL', 'E20_BRAIN'],
    ARRAY['E1_DONOR_INTEL', 'E5_VOLUNTEER', 'E19_SOCIAL', 'E4_REPORTING'],
    TRUE,
    'Anthropic',
    'claude-sonnet-4-20250514',
    5000.00,
    'NEXUS_AGENTS',
    12,
    8
) ON CONFLICT (ecosystem_code) DO UPDATE SET
    description = EXCLUDED.description,
    dependencies = EXCLUDED.dependencies,
    provides_to = EXCLUDED.provides_to,
    ai_powered = EXCLUDED.ai_powered,
    monthly_budget = EXCLUDED.monthly_budget,
    updated_at = NOW();

-- ============================================================================
-- PART 2: REGISTER NEXUS FUNCTIONS (Following functions protocol)
-- ============================================================================

-- Function codes: NX01-NX08
INSERT INTO brain_control.functions (
    function_code,
    function_name,
    ecosystem_code,
    description,
    is_ai_powered,
    ai_provider,
    ai_model,
    cost_type,
    unit_cost,
    monthly_forecast_calls,
    monthly_forecast_cost
) VALUES 
-- NX01: Harvest Import & Matching
('NX01', 'Harvest Import & Matching', 'NEXUS',
 'Import harvest records, deduplicate, match to donors/volunteers',
 FALSE, NULL, NULL, 'per_record', 0.001, 150000, 150.00),

-- NX02: Social Profile Lookup
('NX02', 'Social Profile Lookup', 'NEXUS',
 'Look up and verify social media profiles from harvest data',
 FALSE, NULL, NULL, 'per_lookup', 0.00, 50000, 0.00),

-- NX03: FEC Enrichment
('NX03', 'FEC Data Enrichment', 'NEXUS',
 'Query FEC.gov API for contribution history (FREE)',
 FALSE, NULL, NULL, 'per_call', 0.00, 10000, 0.00),

-- NX04: Voter Data Enrichment  
('NX04', 'NC SBOE Voter Enrichment', 'NEXUS',
 'Match and enrich with NC voter registration data (FREE)',
 FALSE, NULL, NULL, 'per_call', 0.00, 50000, 0.00),

-- NX05: Property Data Enrichment
('NX05', 'Property Data Enrichment', 'NEXUS',
 'Query county property tax records (FREE)',
 FALSE, NULL, NULL, 'per_call', 0.00, 10000, 0.00),

-- NX06: Persona Analysis
('NX06', 'Candidate Persona Analysis', 'NEXUS',
 'Analyze candidate voice signature from historical posts',
 TRUE, 'Anthropic', 'claude-sonnet-4-20250514', 'per_call', 0.015, 5000, 75.00),

-- NX07: Draft Generation
('NX07', 'Social Post Draft Generation', 'NEXUS',
 'Generate 3 persona-matched drafts for E19 approval workflow',
 TRUE, 'Anthropic', 'claude-sonnet-4-20250514', 'per_call', 0.025, 15000, 375.00),

-- NX08: Approval Learning
('NX08', 'Approval Pattern Learning', 'NEXUS',
 'ML learning from candidate approval/edit patterns',
 TRUE, 'Anthropic', 'claude-sonnet-4-20250514', 'per_call', 0.01, 10000, 100.00)

ON CONFLICT (function_code) DO UPDATE SET
    function_name = EXCLUDED.function_name,
    description = EXCLUDED.description,
    unit_cost = EXCLUDED.unit_cost,
    monthly_forecast_calls = EXCLUDED.monthly_forecast_calls,
    monthly_forecast_cost = EXCLUDED.monthly_forecast_cost;

-- ============================================================================
-- PART 3: ECOSYSTEM DEPENDENCIES (Following dependency protocol)
-- ============================================================================

-- NEXUS depends on these ecosystems
INSERT INTO brain_control.ecosystem_dependencies (ecosystem_code, depends_on, dependency_type, description)
VALUES 
('NEXUS', 'E0_DATAHUB', 'required', 'Central data warehouse for all records'),
('NEXUS', 'E1_DONOR_INTEL', 'required', 'Donor records for enrichment'),
('NEXUS', 'E5_VOLUNTEER', 'required', 'Volunteer records for enrichment'),
('NEXUS', 'E7_ISSUES', 'optional', 'Issue vocabulary for persona matching'),
('NEXUS', 'E13_AI_HUB', 'required', 'Claude API gateway for content generation'),
('NEXUS', 'E19_SOCIAL', 'required', 'Social media approval workflow'),
('NEXUS', 'E20_BRAIN', 'required', 'GO/NO-GO decisions and triggers')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PART 4: BRAIN CONTROL COST ACCOUNTING INTEGRATION
-- ============================================================================

-- Create NEXUS budget forecasts (following budget_forecasts protocol)
INSERT INTO brain_control.budget_forecasts (
    function_code,
    ecosystem_code,
    period_type,
    period_start,
    period_end,
    fiscal_year,
    fiscal_month,
    forecast_calls,
    forecast_records,
    forecast_cost,
    forecast_ai_cost,
    forecast_vendor_cost,
    forecast_infrastructure_cost,
    forecast_benefit,
    forecast_roi,
    assumptions,
    forecast_model,
    forecast_confidence,
    status
)
SELECT 
    f.function_code,
    'NEXUS',
    'monthly',
    DATE_TRUNC('month', CURRENT_DATE),
    DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
    EXTRACT(YEAR FROM CURRENT_DATE)::INT,
    EXTRACT(MONTH FROM CURRENT_DATE)::INT,
    f.monthly_forecast_calls,
    CASE WHEN f.function_code = 'NX01' THEN 150000 ELSE 0 END,
    f.monthly_forecast_cost,
    CASE WHEN f.is_ai_powered THEN f.monthly_forecast_cost * 0.9 ELSE 0 END,
    0,
    f.monthly_forecast_cost * 0.1,
    f.monthly_forecast_cost * 15, -- 15x ROI target
    f.monthly_forecast_cost * 15 / NULLIF(f.monthly_forecast_cost, 0),
    jsonb_build_object(
        'source', 'NEXUS integration',
        'basis', 'Historical patterns',
        'data_sources', 'Free government APIs'
    ),
    'linear_regression',
    0.85,
    'approved'
FROM brain_control.functions f
WHERE f.ecosystem_code = 'NEXUS'
ON CONFLICT (function_code, period_type, period_start) DO UPDATE SET
    forecast_calls = EXCLUDED.forecast_calls,
    forecast_cost = EXCLUDED.forecast_cost,
    updated_at = NOW();

-- Create NEXUS budget allocation
INSERT INTO brain_control.budget_allocations (
    fiscal_year,
    fiscal_month,
    ecosystem_code,
    cost_category,
    allocated_amount,
    reserved_amount,
    contingency_amount,
    notes,
    approved_by,
    approved_at
) VALUES 
(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT,
 'NEXUS', 'AI_OPERATIONS', 500.00, 50.00, 25.00, 
 'Claude API for persona analysis and draft generation', 'system', NOW()),
(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT,
 'NEXUS', 'DATA_ENRICHMENT', 200.00, 20.00, 10.00,
 'Free government API infrastructure costs', 'system', NOW()),
(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT,
 'NEXUS', 'HARVEST_PROCESSING', 150.00, 15.00, 10.00,
 'Harvest import and matching operations', 'system', NOW())
ON CONFLICT (fiscal_year, fiscal_month, ecosystem_code, cost_category) DO UPDATE SET
    allocated_amount = EXCLUDED.allocated_amount,
    updated_at = NOW();

-- ============================================================================
-- PART 5: INTELLIGENCE BRAIN GO/NO-GO INTEGRATION
-- ============================================================================

-- Register NEXUS trigger types in intelligence_brain
CREATE TABLE IF NOT EXISTS intelligence_brain.nexus_trigger_types (
    trigger_type_id SERIAL PRIMARY KEY,
    trigger_code VARCHAR(50) UNIQUE NOT NULL,
    trigger_name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Decision factors
    requires_brain_approval BOOLEAN DEFAULT TRUE,
    auto_approve_threshold INT DEFAULT 80,
    
    -- Cost factors
    avg_cost_per_trigger DECIMAL(10,4) DEFAULT 0,
    
    -- Integration
    source_ecosystem VARCHAR(20),
    target_ecosystem VARCHAR(20),
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO intelligence_brain.nexus_trigger_types (
    trigger_code, trigger_name, description, 
    requires_brain_approval, auto_approve_threshold, 
    avg_cost_per_trigger, source_ecosystem, target_ecosystem
) VALUES
('HARVEST_IMPORT', 'Harvest Batch Import', 'New harvest records imported for processing',
 FALSE, 100, 0.001, 'NEXUS', 'E1_DONOR_INTEL'),
('HARVEST_MATCH', 'Harvest Record Match', 'Harvest record matched to donor/volunteer',
 FALSE, 90, 0.00, 'NEXUS', 'E1_DONOR_INTEL'),
('ENRICHMENT_FEC', 'FEC Enrichment', 'FEC contribution data lookup',
 FALSE, 100, 0.00, 'NEXUS', 'E1_DONOR_INTEL'),
('ENRICHMENT_VOTER', 'Voter Enrichment', 'NC SBOE voter data lookup',
 FALSE, 100, 0.00, 'NEXUS', 'E1_DONOR_INTEL'),
('ENRICHMENT_PROPERTY', 'Property Enrichment', 'County property data lookup',
 FALSE, 100, 0.00, 'NEXUS', 'E1_DONOR_INTEL'),
('PERSONA_ANALYSIS', 'Persona Analysis', 'Candidate voice signature analysis',
 TRUE, 70, 0.015, 'NEXUS', 'E19_SOCIAL'),
('DRAFT_GENERATION', 'Social Draft Generation', 'Generate 3 persona-matched drafts',
 TRUE, 60, 0.025, 'NEXUS', 'E19_SOCIAL'),
('APPROVAL_LEARNING', 'Approval Learning', 'Learn from candidate approval patterns',
 FALSE, 100, 0.01, 'NEXUS', 'NEXUS')
ON CONFLICT (trigger_code) DO UPDATE SET
    description = EXCLUDED.description,
    avg_cost_per_trigger = EXCLUDED.avg_cost_per_trigger;

-- Create NEXUS decisions table (extends intelligence_brain.decisions protocol)
CREATE TABLE IF NOT EXISTS intelligence_brain.nexus_decisions (
    decision_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Link to main brain trigger
    brain_trigger_id UUID REFERENCES nexus_brain_triggers(trigger_id),
    
    -- Decision
    decision VARCHAR(20) NOT NULL CHECK (decision IN ('GO', 'NO_GO', 'DEFER', 'MANUAL_REVIEW')),
    decision_reason TEXT,
    decision_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- 7 Mathematical Models (following Brain protocol)
    model_1_expected_roi DECIMAL(10,4),        -- Expected return on investment
    model_2_success_probability DECIMAL(5,4),  -- Probability of success (0-1)
    model_3_relevance_score INT,               -- Relevance to candidate (0-100)
    model_4_expected_cost DECIMAL(10,4),       -- Expected cost
    model_5_persona_match_score INT,           -- Persona match quality (0-100)
    model_6_budget_approved BOOLEAN,           -- Within budget limits
    model_7_confidence_score INT,              -- Overall confidence (0-100)
    
    -- Composite score
    composite_score INT GENERATED ALWAYS AS (
        COALESCE(model_3_relevance_score, 0) * 0.2 +
        COALESCE(model_5_persona_match_score, 0) * 0.3 +
        COALESCE(model_7_confidence_score, 0) * 0.3 +
        CASE WHEN model_6_budget_approved THEN 20 ELSE 0 END
    ) STORED,
    
    -- Target metrics
    target_type VARCHAR(50),
    target_id UUID,
    candidate_id UUID,
    
    -- Results (filled after execution)
    executed BOOLEAN DEFAULT FALSE,
    executed_at TIMESTAMPTZ,
    actual_cost DECIMAL(10,4),
    actual_success BOOLEAN,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_nexus_decisions_trigger ON intelligence_brain.nexus_decisions(brain_trigger_id);
CREATE INDEX idx_nexus_decisions_decision ON intelligence_brain.nexus_decisions(decision);
CREATE INDEX idx_nexus_decisions_candidate ON intelligence_brain.nexus_decisions(candidate_id);
CREATE INDEX idx_nexus_decisions_composite ON intelligence_brain.nexus_decisions(composite_score DESC);

-- ============================================================================
-- PART 6: LINEAR PROGRAMMING OPTIMIZATION MODEL
-- ============================================================================

-- NEXUS LP optimization constraints
CREATE TABLE IF NOT EXISTS nexus_lp_constraints (
    constraint_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    constraint_name VARCHAR(255) NOT NULL,
    constraint_type VARCHAR(50) NOT NULL, -- 'BUDGET', 'CAPACITY', 'TIMING', 'QUALITY'
    
    -- Constraint definition
    variable VARCHAR(100) NOT NULL,       -- What we're constraining
    operator VARCHAR(10) NOT NULL,        -- '<=', '>=', '='
    bound_value DECIMAL(12,4) NOT NULL,   -- Constraint bound
    
    -- Scope
    scope_type VARCHAR(50) DEFAULT 'GLOBAL', -- 'GLOBAL', 'CANDIDATE', 'CAMPAIGN'
    scope_id UUID,
    
    -- Time period
    period_type VARCHAR(20) DEFAULT 'DAILY',
    period_value INT DEFAULT 1,
    
    -- Priority (for soft constraints)
    is_hard_constraint BOOLEAN DEFAULT TRUE,
    penalty_cost DECIMAL(10,4) DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default LP constraints
INSERT INTO nexus_lp_constraints (constraint_name, constraint_type, variable, operator, bound_value, scope_type, period_type)
VALUES
-- Budget constraints
('Daily AI Budget', 'BUDGET', 'ai_cost_total', '<=', 50.00, 'GLOBAL', 'DAILY'),
('Monthly AI Budget', 'BUDGET', 'ai_cost_total', '<=', 1500.00, 'GLOBAL', 'MONTHLY'),
('Candidate Daily Budget', 'BUDGET', 'candidate_daily_cost', '<=', 5.00, 'CANDIDATE', 'DAILY'),

-- Capacity constraints
('Daily Draft Generation Cap', 'CAPACITY', 'drafts_generated', '<=', 500, 'GLOBAL', 'DAILY'),
('Daily Enrichment Cap', 'CAPACITY', 'enrichments_processed', '<=', 5000, 'GLOBAL', 'DAILY'),
('Candidate Posts Per Day', 'CAPACITY', 'posts_per_candidate', '<=', 5, 'CANDIDATE', 'DAILY'),

-- Quality constraints
('Min Persona Score', 'QUALITY', 'persona_score', '>=', 60, 'GLOBAL', 'DAILY'),
('Min Confidence Score', 'QUALITY', 'confidence_score', '>=', 50, 'GLOBAL', 'DAILY'),

-- Timing constraints
('Quiet Hours Start', 'TIMING', 'posting_hour_start', '>=', 7, 'GLOBAL', 'DAILY'),
('Quiet Hours End', 'TIMING', 'posting_hour_end', '<=', 22, 'GLOBAL', 'DAILY')
ON CONFLICT DO NOTHING;

-- LP optimization runs
CREATE TABLE IF NOT EXISTS nexus_lp_runs (
    run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Run configuration
    run_type VARCHAR(50) NOT NULL,  -- 'DAILY_ALLOCATION', 'CAMPAIGN_OPTIMIZATION', 'RESOURCE_SCHEDULING'
    objective VARCHAR(255) NOT NULL, -- What we're optimizing
    
    -- Input
    input_variables JSONB DEFAULT '{}',
    active_constraints JSONB DEFAULT '[]',
    
    -- Solution
    status VARCHAR(50) DEFAULT 'PENDING', -- 'PENDING', 'OPTIMAL', 'INFEASIBLE', 'SUBOPTIMAL'
    objective_value DECIMAL(12,4),
    solution_variables JSONB DEFAULT '{}',
    slack_variables JSONB DEFAULT '{}',
    shadow_prices JSONB DEFAULT '{}',
    
    -- Performance
    solve_time_ms INT,
    iterations INT,
    
    -- Application
    applied BOOLEAN DEFAULT FALSE,
    applied_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_nexus_lp_runs_type ON nexus_lp_runs(run_type);
CREATE INDEX idx_nexus_lp_runs_status ON nexus_lp_runs(status);

-- ============================================================================
-- PART 7: MACHINE LEARNING MODEL REGISTRY
-- ============================================================================

-- NEXUS ML models (following ml_models protocol)
CREATE TABLE IF NOT EXISTS nexus_ml_models (
    model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_code VARCHAR(50) UNIQUE NOT NULL,
    model_name VARCHAR(255) NOT NULL,
    model_type VARCHAR(100) NOT NULL,
    
    -- Model specification
    algorithm VARCHAR(100),
    framework VARCHAR(50),
    version VARCHAR(20),
    
    -- Training
    training_data_source TEXT,
    training_samples INT,
    training_start TIMESTAMPTZ,
    training_end TIMESTAMPTZ,
    training_duration_seconds INT,
    
    -- Features
    feature_count INT,
    feature_names JSONB DEFAULT '[]',
    feature_importance JSONB DEFAULT '{}',
    
    -- Performance metrics
    accuracy DECIMAL(5,4),
    precision_score DECIMAL(5,4),
    recall_score DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    auc_roc DECIMAL(5,4),
    mse DECIMAL(10,6),
    mae DECIMAL(10,6),
    r_squared DECIMAL(5,4),
    
    -- Hyperparameters
    hyperparameters JSONB DEFAULT '{}',
    
    -- Deployment
    is_active BOOLEAN DEFAULT FALSE,
    deployed_at TIMESTAMPTZ,
    endpoint VARCHAR(255),
    
    -- Versioning
    previous_model_id UUID,
    is_champion BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Register NEXUS ML models
INSERT INTO nexus_ml_models (
    model_code, model_name, model_type, algorithm, framework, is_active
) VALUES
('NX_PERSONA_MATCH', 'Persona Match Scorer', 'CLASSIFICATION',
 'Gradient Boosting', 'scikit-learn', TRUE),
('NX_APPROVAL_PREDICT', 'Approval Prediction', 'CLASSIFICATION',
 'Random Forest', 'scikit-learn', TRUE),
('NX_ENGAGEMENT_PREDICT', 'Engagement Prediction', 'REGRESSION',
 'XGBoost', 'xgboost', TRUE),
('NX_TIMING_OPTIMIZE', 'Optimal Posting Time', 'REGRESSION',
 'Neural Network', 'tensorflow', TRUE),
('NX_MATCH_CONFIDENCE', 'Match Confidence Scorer', 'CLASSIFICATION',
 'Logistic Regression', 'scikit-learn', TRUE),
('NX_DONOR_VALUE', 'Enriched Donor Value', 'REGRESSION',
 'Gradient Boosting', 'lightgbm', TRUE)
ON CONFLICT (model_code) DO UPDATE SET
    model_name = EXCLUDED.model_name,
    updated_at = NOW();

-- ML model predictions log
CREATE TABLE IF NOT EXISTS nexus_ml_predictions (
    prediction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_id UUID REFERENCES nexus_ml_models(model_id),
    
    -- Input
    input_features JSONB NOT NULL,
    
    -- Output
    prediction_value DECIMAL(10,6),
    prediction_class VARCHAR(100),
    prediction_probabilities JSONB,
    confidence DECIMAL(5,4),
    
    -- Context
    target_type VARCHAR(50),
    target_id UUID,
    candidate_id UUID,
    
    -- Feedback (for model improvement)
    actual_value DECIMAL(10,6),
    actual_class VARCHAR(100),
    feedback_at TIMESTAMPTZ,
    
    -- Performance
    prediction_time_ms INT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_nexus_ml_predictions_model ON nexus_ml_predictions(model_id);
CREATE INDEX idx_nexus_ml_predictions_target ON nexus_ml_predictions(target_type, target_id);
CREATE INDEX idx_nexus_ml_predictions_date ON nexus_ml_predictions(created_at DESC);

-- ============================================================================
-- PART 8: COST TRANSACTION TRACKING
-- ============================================================================

-- NEXUS cost transactions (following cost_transactions protocol)
CREATE TABLE IF NOT EXISTS nexus_cost_transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- Hierarchy (5-level following Brain protocol)
    level_1_universe VARCHAR(20) DEFAULT 'BROYHILLGOP',
    level_2_candidate_id UUID,
    level_3_campaign_id UUID,
    level_4_channel VARCHAR(50) DEFAULT 'NEXUS',
    level_5_tier VARCHAR(50),
    
    -- Function
    function_code VARCHAR(10) REFERENCES brain_control.functions(function_code),
    
    -- Transaction details
    cost_type VARCHAR(50) NOT NULL, -- 'AI_API', 'INFRASTRUCTURE', 'DATA'
    cost_category VARCHAR(50),
    quantity INT DEFAULT 1,
    unit_cost DECIMAL(10,6),
    total_cost DECIMAL(12,4) NOT NULL,
    
    -- Reference
    reference_type VARCHAR(50),
    reference_id UUID,
    decision_id UUID REFERENCES intelligence_brain.nexus_decisions(decision_id),
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_nexus_cost_trans_date ON nexus_cost_transactions(transaction_timestamp DESC);
CREATE INDEX idx_nexus_cost_trans_function ON nexus_cost_transactions(function_code);
CREATE INDEX idx_nexus_cost_trans_candidate ON nexus_cost_transactions(level_2_candidate_id);
CREATE INDEX idx_nexus_cost_trans_type ON nexus_cost_transactions(cost_type);

-- Daily cost aggregation view
CREATE OR REPLACE VIEW v_nexus_daily_costs AS
SELECT 
    DATE(transaction_timestamp) AS cost_date,
    function_code,
    cost_type,
    level_2_candidate_id,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_units,
    SUM(total_cost) AS total_cost,
    AVG(unit_cost) AS avg_unit_cost
FROM nexus_cost_transactions
GROUP BY DATE(transaction_timestamp), function_code, cost_type, level_2_candidate_id;

-- Monthly cost aggregation view
CREATE OR REPLACE VIEW v_nexus_monthly_costs AS
SELECT 
    EXTRACT(YEAR FROM transaction_timestamp)::INT AS fiscal_year,
    EXTRACT(MONTH FROM transaction_timestamp)::INT AS fiscal_month,
    function_code,
    cost_type,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_units,
    SUM(total_cost) AS total_cost,
    AVG(unit_cost) AS avg_unit_cost
FROM nexus_cost_transactions
GROUP BY 
    EXTRACT(YEAR FROM transaction_timestamp),
    EXTRACT(MONTH FROM transaction_timestamp),
    function_code,
    cost_type;

-- ============================================================================
-- PART 9: BUDGET VS ACTUAL VS VARIANCE (BVA) ANALYSIS
-- ============================================================================

-- NEXUS BVA summary view
CREATE OR REPLACE VIEW v_nexus_budget_variance AS
WITH budget AS (
    SELECT 
        function_code,
        SUM(forecast_cost) AS budget_cost,
        SUM(forecast_calls) AS budget_calls
    FROM brain_control.budget_forecasts
    WHERE ecosystem_code = 'NEXUS'
    AND period_start <= CURRENT_DATE
    AND period_end >= CURRENT_DATE
    GROUP BY function_code
),
actual AS (
    SELECT 
        function_code,
        SUM(total_cost) AS actual_cost,
        COUNT(*) AS actual_calls
    FROM nexus_cost_transactions
    WHERE DATE(transaction_timestamp) >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY function_code
)
SELECT 
    COALESCE(b.function_code, a.function_code) AS function_code,
    f.function_name,
    COALESCE(b.budget_cost, 0) AS budget,
    COALESCE(a.actual_cost, 0) AS actual,
    COALESCE(b.budget_cost, 0) - COALESCE(a.actual_cost, 0) AS variance,
    CASE 
        WHEN COALESCE(b.budget_cost, 0) = 0 THEN 0
        ELSE ROUND((COALESCE(a.actual_cost, 0) / b.budget_cost * 100)::NUMERIC, 2)
    END AS percent_used,
    COALESCE(b.budget_calls, 0) AS budget_calls,
    COALESCE(a.actual_calls, 0) AS actual_calls,
    CASE 
        WHEN COALESCE(a.actual_cost, 0) / NULLIF(b.budget_cost, 0) >= 0.95 THEN 'CRITICAL'
        WHEN COALESCE(a.actual_cost, 0) / NULLIF(b.budget_cost, 0) >= 0.80 THEN 'WARNING'
        WHEN COALESCE(a.actual_cost, 0) / NULLIF(b.budget_cost, 0) >= 0.50 THEN 'ON_TRACK'
        ELSE 'UNDER_BUDGET'
    END AS status
FROM budget b
FULL OUTER JOIN actual a ON b.function_code = a.function_code
LEFT JOIN brain_control.functions f ON COALESCE(b.function_code, a.function_code) = f.function_code;

-- 403+ Metrics BVA (following existing platform pattern)
CREATE TABLE IF NOT EXISTS nexus_metrics_bva (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_code VARCHAR(50) NOT NULL,
    metric_name VARCHAR(255) NOT NULL,
    metric_category VARCHAR(100) NOT NULL,
    
    -- Period
    period_type VARCHAR(20) DEFAULT 'MONTHLY',
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- BVA values
    budget_value DECIMAL(14,4),
    actual_value DECIMAL(14,4),
    variance_value DECIMAL(14,4) GENERATED ALWAYS AS (budget_value - actual_value) STORED,
    variance_pct DECIMAL(8,4) GENERATED ALWAYS AS (
        CASE WHEN budget_value = 0 THEN 0 
        ELSE ((actual_value - budget_value) / budget_value * 100) END
    ) STORED,
    
    -- Status
    status VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN ABS(variance_pct) <= 5 THEN 'ON_TARGET'
            WHEN variance_pct > 5 THEN 'OVER_PERFORMING'
            WHEN variance_pct < -20 THEN 'CRITICAL_UNDER'
            WHEN variance_pct < -10 THEN 'WARNING_UNDER'
            ELSE 'SLIGHT_UNDER'
        END
    ) STORED,
    
    -- Metadata
    data_source VARCHAR(100),
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(metric_code, period_start)
);

-- Insert standard NEXUS metrics
INSERT INTO nexus_metrics_bva (metric_code, metric_name, metric_category, period_start, period_end, budget_value, actual_value, data_source)
VALUES
-- Volume metrics
('NX_HARVEST_IMPORTED', 'Harvest Records Imported', 'VOLUME', 
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 150000, 0, 'nexus_harvest_records'),
('NX_HARVEST_MATCHED', 'Harvest Records Matched', 'VOLUME',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 75000, 0, 'nexus_harvest_records'),
('NX_DONORS_ENRICHED', 'Donors Enriched', 'VOLUME',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 50000, 0, 'donors'),
('NX_DRAFTS_GENERATED', 'Social Drafts Generated', 'VOLUME',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 15000, 0, 'social_approval_requests'),
('NX_POSTS_APPROVED', 'Posts Approved', 'VOLUME',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 12000, 0, 'social_posts'),

-- Quality metrics
('NX_AVG_PERSONA_SCORE', 'Average Persona Score', 'QUALITY',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 75.00, 0, 'social_approval_requests'),
('NX_APPROVAL_RATE', 'Approval Rate %', 'QUALITY',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 85.00, 0, 'social_approval_requests'),
('NX_MATCH_CONFIDENCE', 'Average Match Confidence', 'QUALITY',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 90.00, 0, 'nexus_harvest_records'),

-- Cost metrics
('NX_TOTAL_COST', 'Total NEXUS Cost', 'COST',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 700.00, 0, 'nexus_cost_transactions'),
('NX_COST_PER_DRAFT', 'Cost Per Draft', 'COST',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 0.025, 0, 'nexus_cost_transactions'),
('NX_COST_PER_ENRICHMENT', 'Cost Per Enrichment', 'COST',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 0.001, 0, 'nexus_cost_transactions'),

-- ROI metrics
('NX_DATA_VALUE_ADDED', 'Data Value Added ($)', 'ROI',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 50000.00, 0, 'calculated'),
('NX_ROI_RATIO', 'ROI Ratio', 'ROI',
 DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
 7000.00, 0, 'calculated')
ON CONFLICT (metric_code, period_start) DO UPDATE SET
    budget_value = EXCLUDED.budget_value,
    calculated_at = NOW();

-- ============================================================================
-- PART 10: COMMUNICATION STRATEGY TRACKING
-- ============================================================================

-- NEXUS communication strategies (ML-learned)
CREATE TABLE IF NOT EXISTS nexus_communication_strategies (
    strategy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    
    -- Strategy type
    strategy_type VARCHAR(100) NOT NULL,
    strategy_name VARCHAR(255),
    
    -- ML-learned parameters
    learned_parameters JSONB DEFAULT '{}',
    
    -- Timing
    best_posting_days JSONB DEFAULT '[]',     -- ['Monday', 'Wednesday', 'Friday']
    best_posting_hours JSONB DEFAULT '[]',    -- [9, 12, 18]
    worst_posting_hours JSONB DEFAULT '[]',   -- [2, 3, 4]
    
    -- Content
    best_content_types JSONB DEFAULT '[]',    -- ['news_response', 'personal_story']
    best_topics JSONB DEFAULT '[]',
    optimal_length_range JSONB DEFAULT '{}',  -- {'min': 100, 'max': 250}
    
    -- Tone
    tone_profile JSONB DEFAULT '{}',          -- {'formality': 6, 'warmth': 8}
    
    -- Hashtags
    effective_hashtags JSONB DEFAULT '[]',
    hashtag_count_optimal INT,
    
    -- Engagement patterns
    engagement_multipliers JSONB DEFAULT '{}',
    
    -- Confidence
    sample_size INT,
    confidence_score DECIMAL(5,4),
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    applied_count INT DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_nexus_comm_strategy_candidate ON nexus_communication_strategies(candidate_id);
CREATE INDEX idx_nexus_comm_strategy_type ON nexus_communication_strategies(strategy_type);

-- ============================================================================
-- PART 11: REPORTING VIEWS
-- ============================================================================

-- Executive dashboard view
CREATE OR REPLACE VIEW v_nexus_executive_dashboard AS
SELECT 
    -- Harvest Stats
    (SELECT COUNT(*) FROM nexus_harvest_records) AS total_harvest_records,
    (SELECT COUNT(*) FROM nexus_harvest_records WHERE matched_donor_id IS NOT NULL) AS matched_to_donors,
    (SELECT COUNT(*) FROM nexus_harvest_records WHERE match_verified = TRUE) AS verified_matches,
    
    -- Enrichment Stats
    (SELECT COUNT(*) FROM donors WHERE nexus_enriched = TRUE) AS donors_enriched,
    (SELECT COUNT(*) FROM donors WHERE nexus_fec_total IS NOT NULL) AS donors_with_fec,
    (SELECT AVG(nexus_fec_total) FROM donors WHERE nexus_fec_total IS NOT NULL) AS avg_fec_contribution,
    
    -- Social Stats
    (SELECT COUNT(*) FROM social_approval_requests WHERE created_at > NOW() - INTERVAL '30 days') AS approval_requests_30d,
    (SELECT AVG(nexus_persona_score) FROM social_approval_requests WHERE nexus_persona_score IS NOT NULL) AS avg_persona_score,
    (SELECT COUNT(*) FROM social_posts WHERE nexus_ml_optimized = TRUE AND posted_at > NOW() - INTERVAL '30 days') AS ml_optimized_posts_30d,
    
    -- Cost Stats
    (SELECT SUM(total_cost) FROM nexus_cost_transactions WHERE transaction_timestamp > DATE_TRUNC('month', CURRENT_DATE)) AS mtd_cost,
    (SELECT SUM(budget_value) FROM nexus_metrics_bva WHERE metric_category = 'COST' AND period_start = DATE_TRUNC('month', CURRENT_DATE)) AS mtd_budget,
    
    -- ML Stats
    (SELECT COUNT(*) FROM nexus_ml_models WHERE is_active = TRUE) AS active_ml_models,
    (SELECT COUNT(*) FROM nexus_ml_predictions WHERE created_at > NOW() - INTERVAL '24 hours') AS predictions_24h,
    
    -- Decision Stats
    (SELECT COUNT(*) FROM intelligence_brain.nexus_decisions WHERE decision = 'GO' AND created_at > NOW() - INTERVAL '7 days') AS go_decisions_7d,
    (SELECT COUNT(*) FROM intelligence_brain.nexus_decisions WHERE decision = 'NO_GO' AND created_at > NOW() - INTERVAL '7 days') AS no_go_decisions_7d,
    
    NOW() AS report_generated_at;

-- Operations report view
CREATE OR REPLACE VIEW v_nexus_operations_report AS
SELECT 
    DATE(created_at) AS report_date,
    
    -- Harvest operations
    COUNT(*) FILTER (WHERE source_type IS NOT NULL) AS records_imported,
    COUNT(*) FILTER (WHERE matched_donor_id IS NOT NULL) AS records_matched,
    COUNT(*) FILTER (WHERE match_verified = TRUE) AS matches_verified,
    ROUND(AVG(match_confidence)::NUMERIC, 2) AS avg_match_confidence,
    
    -- By source type
    COUNT(*) FILTER (WHERE source_type = 'event_list') AS from_events,
    COUNT(*) FILTER (WHERE source_type = 'social_scrape') AS from_social,
    COUNT(*) FILTER (WHERE source_type = 'petition') AS from_petitions,
    
    -- Social lookup results
    COUNT(*) FILTER (WHERE facebook_id IS NOT NULL) AS with_facebook,
    COUNT(*) FILTER (WHERE twitter_handle IS NOT NULL) AS with_twitter,
    COUNT(*) FILTER (WHERE linkedin_url IS NOT NULL) AS with_linkedin

FROM nexus_harvest_records
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY report_date DESC;

-- Candidate performance view
CREATE OR REPLACE VIEW v_nexus_candidate_performance AS
SELECT 
    c.candidate_id,
    c.first_name || ' ' || c.last_name AS candidate_name,
    c.office_sought,
    
    -- Style profile
    csp.nexus_ml_confidence AS ml_confidence,
    csp.nexus_training_posts_count AS training_samples,
    
    -- Approval performance (30 days)
    COUNT(DISTINCT sar.approval_request_id) AS approval_requests,
    COUNT(DISTINCT sar.approval_request_id) FILTER (WHERE sar.status = 'approved') AS approved,
    COUNT(DISTINCT sar.approval_request_id) FILTER (WHERE sar.status = 'edited') AS edited,
    COUNT(DISTINCT sar.approval_request_id) FILTER (WHERE sar.status = 'rejected') AS rejected,
    ROUND(AVG(sar.nexus_persona_score)::NUMERIC, 1) AS avg_persona_score,
    
    -- Posts and engagement
    COUNT(DISTINCT sp.post_id) AS posts_published,
    ROUND(AVG(sp.engagement_score)::NUMERIC, 2) AS avg_engagement,
    
    -- Cost
    COALESCE(SUM(nct.total_cost), 0) AS total_cost
    
FROM candidates c
LEFT JOIN candidate_style_profiles csp ON c.candidate_id = csp.candidate_id
LEFT JOIN social_approval_requests sar ON c.candidate_id = sar.candidate_id 
    AND sar.created_at > NOW() - INTERVAL '30 days'
LEFT JOIN social_posts sp ON c.candidate_id = sp.candidate_id
    AND sp.posted_at > NOW() - INTERVAL '30 days'
LEFT JOIN nexus_cost_transactions nct ON c.candidate_id = nct.level_2_candidate_id
    AND nct.transaction_timestamp > NOW() - INTERVAL '30 days'
WHERE c.status = 'active'
GROUP BY c.candidate_id, c.first_name, c.last_name, c.office_sought,
    csp.nexus_ml_confidence, csp.nexus_training_posts_count
ORDER BY avg_persona_score DESC NULLS LAST;

-- ============================================================================
-- PART 12: FUNCTIONS FOR BRAIN INTEGRATION
-- ============================================================================

-- Function to record NEXUS decision (GO/NO-GO)
CREATE OR REPLACE FUNCTION nexus_record_decision(
    p_trigger_id UUID,
    p_decision VARCHAR(20),
    p_model_scores JSONB,
    p_candidate_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_decision_id UUID;
BEGIN
    INSERT INTO intelligence_brain.nexus_decisions (
        brain_trigger_id,
        decision,
        decision_reason,
        model_1_expected_roi,
        model_2_success_probability,
        model_3_relevance_score,
        model_4_expected_cost,
        model_5_persona_match_score,
        model_6_budget_approved,
        model_7_confidence_score,
        candidate_id
    ) VALUES (
        p_trigger_id,
        p_decision,
        p_model_scores->>'reason',
        (p_model_scores->>'expected_roi')::DECIMAL,
        (p_model_scores->>'success_probability')::DECIMAL,
        (p_model_scores->>'relevance_score')::INT,
        (p_model_scores->>'expected_cost')::DECIMAL,
        (p_model_scores->>'persona_match_score')::INT,
        (p_model_scores->>'budget_approved')::BOOLEAN,
        (p_model_scores->>'confidence_score')::INT,
        p_candidate_id
    )
    RETURNING decision_id INTO v_decision_id;
    
    RETURN v_decision_id;
END;
$$ LANGUAGE plpgsql;

-- Function to record NEXUS cost transaction
CREATE OR REPLACE FUNCTION nexus_record_cost(
    p_function_code VARCHAR(10),
    p_cost_type VARCHAR(50),
    p_quantity INT,
    p_unit_cost DECIMAL,
    p_candidate_id UUID DEFAULT NULL,
    p_reference_type VARCHAR(50) DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    INSERT INTO nexus_cost_transactions (
        function_code,
        cost_type,
        quantity,
        unit_cost,
        total_cost,
        level_2_candidate_id,
        reference_type,
        reference_id
    ) VALUES (
        p_function_code,
        p_cost_type,
        p_quantity,
        p_unit_cost,
        p_quantity * p_unit_cost,
        p_candidate_id,
        p_reference_type,
        p_reference_id
    )
    RETURNING transaction_id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update BVA metrics
CREATE OR REPLACE FUNCTION nexus_update_bva_metrics() RETURNS VOID AS $$
BEGIN
    -- Update volume metrics
    UPDATE nexus_metrics_bva SET actual_value = (
        SELECT COUNT(*) FROM nexus_harvest_records 
        WHERE created_at >= period_start AND created_at <= period_end
    ), calculated_at = NOW()
    WHERE metric_code = 'NX_HARVEST_IMPORTED';
    
    UPDATE nexus_metrics_bva SET actual_value = (
        SELECT COUNT(*) FROM nexus_harvest_records 
        WHERE matched_donor_id IS NOT NULL
        AND created_at >= period_start AND created_at <= period_end
    ), calculated_at = NOW()
    WHERE metric_code = 'NX_HARVEST_MATCHED';
    
    UPDATE nexus_metrics_bva SET actual_value = (
        SELECT COUNT(*) FROM donors WHERE nexus_enriched = TRUE
    ), calculated_at = NOW()
    WHERE metric_code = 'NX_DONORS_ENRICHED';
    
    -- Update quality metrics
    UPDATE nexus_metrics_bva SET actual_value = (
        SELECT COALESCE(AVG(nexus_persona_score), 0) FROM social_approval_requests
        WHERE created_at >= period_start AND created_at <= period_end
    ), calculated_at = NOW()
    WHERE metric_code = 'NX_AVG_PERSONA_SCORE';
    
    -- Update cost metrics
    UPDATE nexus_metrics_bva SET actual_value = (
        SELECT COALESCE(SUM(total_cost), 0) FROM nexus_cost_transactions
        WHERE transaction_timestamp >= period_start AND transaction_timestamp <= period_end
    ), calculated_at = NOW()
    WHERE metric_code = 'NX_TOTAL_COST';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SCHEMA COMPLETE
-- ============================================================================

COMMENT ON SCHEMA public IS 
'BroyhillGOP Platform - NEXUS fully integrated.

NEXUS Integration includes:
- Ecosystem registration (brain_control.ecosystems)
- Function registry (brain_control.functions) - NX01-NX08
- Budget forecasts (brain_control.budget_forecasts)
- GO/NO-GO decisions (intelligence_brain.nexus_decisions)
- 7 mathematical models for decision scoring
- Linear programming constraints (nexus_lp_constraints)
- ML model registry (nexus_ml_models)
- Cost transactions (nexus_cost_transactions)
- BVA metrics (nexus_metrics_bva) - 13+ metrics
- Communication strategies (nexus_communication_strategies)
- Executive and operations reporting views

Follows all existing protocols:
- Brain Control cost accounting
- Intelligence Brain GO/NO-GO decisions
- 5-level cost hierarchy
- Budget vs Actual vs Variance analysis
- ML model tracking and predictions';

SELECT 'NEXUS Platform Integration complete!' AS status;
