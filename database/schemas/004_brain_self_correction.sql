-- ============================================================================
-- BRAIN CONTROL SYSTEM - SELF-CORRECTION ENGINE
-- ============================================================================
-- File: 004_brain_self_correction.sql
-- Self-correction rules, quality metrics, correction logging
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: SELF-CORRECTION RULES
-- ============================================================================

-- Self-correction rule definitions
CREATE TABLE self_correction_rules (
    rule_id SERIAL PRIMARY KEY,
    rule_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Identification
    rule_code VARCHAR(50) UNIQUE NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    applies_to_all BOOLEAN DEFAULT false,
    
    -- Trigger conditions
    trigger_metric VARCHAR(50) NOT NULL,
    trigger_operator VARCHAR(10) NOT NULL,
    threshold_value DECIMAL(12,4) NOT NULL,
    threshold_unit VARCHAR(30),
    threshold_duration_minutes INTEGER DEFAULT 0,
    consecutive_violations INTEGER DEFAULT 1,
    
    -- Correction action
    correction_action correction_action NOT NULL,
    correction_parameters JSONB,
    
    -- Guardrails
    quality_floor DECIMAL(5,2) DEFAULT 85.00,
    effectiveness_floor DECIMAL(5,2) DEFAULT 80.00,
    cost_ceiling DECIMAL(12,2),
    latency_ceiling_ms INTEGER,
    
    -- Limits
    max_corrections_per_hour INTEGER DEFAULT 5,
    max_corrections_per_day INTEGER DEFAULT 20,
    cooldown_minutes INTEGER DEFAULT 30,
    
    -- Approval
    requires_approval BOOLEAN DEFAULT false,
    auto_rollback_minutes INTEGER,
    
    -- Priority (lower = higher priority)
    priority INTEGER DEFAULT 100,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    
    -- Constraints
    CONSTRAINT chk_threshold_operator CHECK (trigger_operator IN ('>', '<', '>=', '<=', '=', '!=', 'between'))
);

-- Rule conditions (multiple conditions per rule with AND/OR logic)
CREATE TABLE self_correction_conditions (
    condition_id SERIAL PRIMARY KEY,
    rule_id INTEGER NOT NULL REFERENCES self_correction_rules(rule_id) ON DELETE CASCADE,
    
    -- Condition details
    condition_group INTEGER DEFAULT 1,
    condition_logic VARCHAR(3) DEFAULT 'AND',
    metric_name VARCHAR(50) NOT NULL,
    operator VARCHAR(10) NOT NULL,
    threshold_value DECIMAL(12,4) NOT NULL,
    
    -- Order
    sequence INTEGER DEFAULT 1,
    
    CONSTRAINT chk_condition_logic CHECK (condition_logic IN ('AND', 'OR'))
);

-- Rule effectiveness tracking
CREATE TABLE rule_effectiveness (
    effectiveness_id SERIAL PRIMARY KEY,
    rule_id INTEGER NOT NULL REFERENCES self_correction_rules(rule_id) ON DELETE CASCADE,
    
    -- Period
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Application stats
    times_triggered INTEGER DEFAULT 0,
    times_applied INTEGER DEFAULT 0,
    times_blocked INTEGER DEFAULT 0,
    times_rolled_back INTEGER DEFAULT 0,
    
    -- Impact
    avg_quality_improvement DECIMAL(5,2),
    avg_cost_reduction DECIMAL(5,2),
    avg_latency_improvement INTEGER,
    
    -- Success rate
    success_rate DECIMAL(5,4),
    
    -- Metadata
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_rule_effectiveness UNIQUE (rule_id, period_start)
);

-- ============================================================================
-- SECTION 2: SELF-CORRECTION LOG
-- ============================================================================

-- Main correction log
CREATE TABLE self_correction_log (
    correction_id SERIAL PRIMARY KEY,
    correction_uuid UUID DEFAULT gen_random_uuid(),
    
    -- What triggered it
    rule_id INTEGER REFERENCES self_correction_rules(rule_id) ON DELETE SET NULL,
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE SET NULL,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE SET NULL,
    
    -- Trigger details
    triggered_at TIMESTAMPTZ DEFAULT NOW(),
    trigger_metric VARCHAR(50),
    trigger_value DECIMAL(12,4),
    threshold_value DECIMAL(12,4),
    trigger_context JSONB,
    
    -- Correction action
    correction_action correction_action NOT NULL,
    
    -- Parameters changed
    parameters_before JSONB,
    parameters_after JSONB,
    parameter_diff JSONB,
    
    -- Metrics before/after
    quality_before DECIMAL(5,2),
    quality_after DECIMAL(5,2),
    quality_change DECIMAL(5,2),
    
    effectiveness_before DECIMAL(5,2),
    effectiveness_after DECIMAL(5,2),
    effectiveness_change DECIMAL(5,2),
    
    cost_before DECIMAL(12,2),
    cost_after DECIMAL(12,2),
    cost_change DECIMAL(12,2),
    cost_change_pct DECIMAL(6,2),
    
    latency_before_ms INTEGER,
    latency_after_ms INTEGER,
    latency_change_ms INTEGER,
    
    -- Status
    correction_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    status_reason TEXT,
    
    -- Approval (if required)
    requires_approval BOOLEAN DEFAULT false,
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    approval_notes TEXT,
    
    -- Execution
    executed_at TIMESTAMPTZ,
    execution_duration_ms INTEGER,
    
    -- Rollback
    is_rolled_back BOOLEAN DEFAULT false,
    rolled_back_at TIMESTAMPTZ,
    rolled_back_by VARCHAR(100),
    rollback_reason TEXT,
    rollback_parameters JSONB,
    
    -- Evaluation
    evaluation_timestamp TIMESTAMPTZ,
    evaluation_passed BOOLEAN,
    evaluation_notes TEXT,
    
    -- Alert reference
    alert_id INTEGER,
    
    -- Metadata
    metadata JSONB
);

-- Correction execution steps
CREATE TABLE correction_execution_steps (
    step_id SERIAL PRIMARY KEY,
    correction_id INTEGER NOT NULL REFERENCES self_correction_log(correction_id) ON DELETE CASCADE,
    
    -- Step details
    step_number INTEGER NOT NULL,
    step_name VARCHAR(100) NOT NULL,
    step_action VARCHAR(100),
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    
    -- Result
    status VARCHAR(20) NOT NULL,
    result_data JSONB,
    error_message TEXT,
    
    -- Metadata
    metadata JSONB
);

-- ============================================================================
-- SECTION 3: QUALITY METRICS
-- ============================================================================

-- Real-time quality measurements
CREATE TABLE quality_measurements (
    measurement_id BIGSERIAL PRIMARY KEY,
    
    -- Scope
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    
    -- Timing
    measurement_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- Quality scores (0-100)
    overall_quality DECIMAL(5,2),
    accuracy DECIMAL(5,2),
    consistency DECIMAL(5,2),
    completeness DECIMAL(5,2),
    relevance DECIMAL(5,2),
    safety DECIMAL(5,2),
    
    -- Effectiveness scores (0-100)
    overall_effectiveness DECIMAL(5,2),
    conversion_effectiveness DECIMAL(5,2),
    engagement_effectiveness DECIMAL(5,2),
    
    -- Conversion metrics
    conversion_rate DECIMAL(7,6),
    click_through_rate DECIMAL(7,6),
    response_rate DECIMAL(7,6),
    
    -- Performance metrics
    latency_ms INTEGER,
    throughput DECIMAL(10,2),
    error_rate DECIMAL(7,6),
    
    -- Sample info
    sample_size INTEGER,
    measurement_method VARCHAR(50),
    
    -- Thresholds
    quality_floor DECIMAL(5,2),
    effectiveness_floor DECIMAL(5,2),
    
    -- Status
    meets_quality_floor BOOLEAN,
    meets_effectiveness_floor BOOLEAN,
    
    -- Metadata
    metadata JSONB
);

-- Aggregated quality metrics
CREATE TABLE quality_metrics_aggregated (
    metric_id SERIAL PRIMARY KEY,
    
    -- Scope
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    
    -- Period
    period_type VARCHAR(20) NOT NULL,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    
    -- Quality scores
    avg_quality DECIMAL(5,2),
    min_quality DECIMAL(5,2),
    max_quality DECIMAL(5,2),
    quality_std_dev DECIMAL(5,2),
    
    -- Effectiveness scores
    avg_effectiveness DECIMAL(5,2),
    min_effectiveness DECIMAL(5,2),
    max_effectiveness DECIMAL(5,2),
    
    -- Performance
    avg_latency_ms INTEGER,
    p50_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    p99_latency_ms INTEGER,
    
    -- Error metrics
    avg_error_rate DECIMAL(7,6),
    total_errors INTEGER,
    
    -- Volume
    measurement_count INTEGER,
    
    -- Trend
    quality_trend VARCHAR(20),
    effectiveness_trend VARCHAR(20),
    
    -- Alerts
    quality_alerts_triggered INTEGER DEFAULT 0,
    corrections_applied INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_quality_agg UNIQUE (function_code, period_type, period_start)
);

-- ============================================================================
-- SECTION 4: THRESHOLD MANAGEMENT
-- ============================================================================

-- Quality thresholds by function
CREATE TABLE quality_thresholds (
    threshold_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    
    -- Quality thresholds
    quality_critical DECIMAL(5,2) DEFAULT 60.00,
    quality_warning DECIMAL(5,2) DEFAULT 75.00,
    quality_target DECIMAL(5,2) DEFAULT 90.00,
    
    -- Effectiveness thresholds
    effectiveness_critical DECIMAL(5,2) DEFAULT 50.00,
    effectiveness_warning DECIMAL(5,2) DEFAULT 70.00,
    effectiveness_target DECIMAL(5,2) DEFAULT 85.00,
    
    -- Latency thresholds (ms)
    latency_critical INTEGER DEFAULT 10000,
    latency_warning INTEGER DEFAULT 5000,
    latency_target INTEGER DEFAULT 1000,
    
    -- Error rate thresholds
    error_rate_critical DECIMAL(5,4) DEFAULT 0.10,
    error_rate_warning DECIMAL(5,4) DEFAULT 0.05,
    error_rate_target DECIMAL(5,4) DEFAULT 0.01,
    
    -- Cost variance thresholds (%)
    cost_variance_critical DECIMAL(5,2) DEFAULT 50.00,
    cost_variance_warning DECIMAL(5,2) DEFAULT 20.00,
    cost_variance_acceptable DECIMAL(5,2) DEFAULT 10.00,
    
    -- Auto-correction settings
    auto_correct_on_critical BOOLEAN DEFAULT true,
    auto_correct_on_warning BOOLEAN DEFAULT false,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by VARCHAR(100),
    
    CONSTRAINT uq_quality_threshold UNIQUE (function_code)
);

-- Threshold violation log
CREATE TABLE threshold_violations (
    violation_id BIGSERIAL PRIMARY KEY,
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE SET NULL,
    threshold_id INTEGER REFERENCES quality_thresholds(threshold_id) ON DELETE SET NULL,
    
    -- Violation details
    violated_at TIMESTAMPTZ DEFAULT NOW(),
    metric_name VARCHAR(50) NOT NULL,
    threshold_level VARCHAR(20) NOT NULL,
    threshold_value DECIMAL(12,4),
    actual_value DECIMAL(12,4),
    
    -- Duration
    violation_started TIMESTAMPTZ NOT NULL,
    violation_ended TIMESTAMPTZ,
    duration_minutes INTEGER,
    
    -- Response
    alert_created BOOLEAN DEFAULT false,
    alert_id INTEGER,
    correction_triggered BOOLEAN DEFAULT false,
    correction_id INTEGER,
    
    -- Resolution
    resolved_at TIMESTAMPTZ,
    resolution_method VARCHAR(50),
    
    -- Metadata
    metadata JSONB
);

-- ============================================================================
-- SECTION 5: MODEL PERFORMANCE COMPARISON
-- ============================================================================

-- A/B test results for model comparison
CREATE TABLE model_comparison_tests (
    test_id SERIAL PRIMARY KEY,
    test_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Test configuration
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    test_name VARCHAR(200) NOT NULL,
    test_description TEXT,
    
    -- Models being compared
    model_a VARCHAR(100) NOT NULL,
    model_b VARCHAR(100) NOT NULL,
    
    -- Test period
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    
    -- Traffic split
    model_a_traffic_pct DECIMAL(5,2) DEFAULT 50.00,
    model_b_traffic_pct DECIMAL(5,2) DEFAULT 50.00,
    
    -- Sample sizes
    model_a_samples INTEGER DEFAULT 0,
    model_b_samples INTEGER DEFAULT 0,
    
    -- Quality results
    model_a_avg_quality DECIMAL(5,2),
    model_b_avg_quality DECIMAL(5,2),
    quality_winner VARCHAR(10),
    quality_significance DECIMAL(5,4),
    
    -- Cost results
    model_a_avg_cost DECIMAL(10,4),
    model_b_avg_cost DECIMAL(10,4),
    cost_winner VARCHAR(10),
    
    -- Latency results
    model_a_avg_latency_ms INTEGER,
    model_b_avg_latency_ms INTEGER,
    latency_winner VARCHAR(10),
    
    -- Overall recommendation
    recommended_model VARCHAR(100),
    recommendation_reason TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'running',
    
    -- Metadata
    created_by VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SECTION 6: INDEXES
-- ============================================================================

-- Self-correction rules
CREATE INDEX idx_correction_rules_function ON self_correction_rules(function_code);
CREATE INDEX idx_correction_rules_ecosystem ON self_correction_rules(ecosystem_code);
CREATE INDEX idx_correction_rules_active ON self_correction_rules(is_active) WHERE is_active = true;
CREATE INDEX idx_correction_rules_priority ON self_correction_rules(priority);

-- Self-correction log
CREATE INDEX idx_correction_log_function ON self_correction_log(function_code);
CREATE INDEX idx_correction_log_triggered ON self_correction_log(triggered_at DESC);
CREATE INDEX idx_correction_log_status ON self_correction_log(correction_status);
CREATE INDEX idx_correction_log_rule ON self_correction_log(rule_id);

-- Quality measurements
CREATE INDEX idx_quality_measure_function ON quality_measurements(function_code);
CREATE INDEX idx_quality_measure_timestamp ON quality_measurements(measurement_timestamp DESC);

-- Quality aggregated
CREATE INDEX idx_quality_agg_function ON quality_metrics_aggregated(function_code);
CREATE INDEX idx_quality_agg_period ON quality_metrics_aggregated(period_start, period_end);

-- Threshold violations
CREATE INDEX idx_violations_function ON threshold_violations(function_code);
CREATE INDEX idx_violations_timestamp ON threshold_violations(violated_at DESC);
CREATE INDEX idx_violations_unresolved ON threshold_violations(resolved_at) WHERE resolved_at IS NULL;

-- ============================================================================
-- SECTION 7: COMMENTS
-- ============================================================================

COMMENT ON TABLE self_correction_rules IS 'Configurable rules for automatic system optimization';
COMMENT ON TABLE self_correction_log IS 'Audit log of all self-correction actions';
COMMENT ON TABLE quality_measurements IS 'Real-time quality and effectiveness measurements';
COMMENT ON TABLE quality_thresholds IS 'Configurable quality thresholds per function';
COMMENT ON TABLE threshold_violations IS 'Log of threshold violations for trending and analysis';
