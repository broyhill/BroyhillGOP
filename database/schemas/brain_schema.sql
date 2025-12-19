-- ============================================================================
-- BRAIN CONTROL SYSTEM - COMPLETE DATABASE SCHEMA
-- BroyhillGOP Central AI & Automation Command Platform
-- Version: 2.0 | November 29, 2025
-- ============================================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS brain_control;
SET search_path TO brain_control;

-- ============================================================================
-- SECTION 1: ECOSYSTEM MANAGEMENT
-- ============================================================================

-- Ecosystem registry
CREATE TABLE ecosystems (
    ecosystem_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) UNIQUE NOT NULL,
    ecosystem_name VARCHAR(100) NOT NULL,
    description TEXT,
    schema_name VARCHAR(50),
    api_prefix VARCHAR(100),
    port INTEGER,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    criticality VARCHAR(20) DEFAULT 'MEDIUM',
    monthly_budget DECIMAL(12,2),
    dependencies TEXT[],
    provides_to TEXT[],
    health_endpoint VARCHAR(200),
    ai_powered BOOLEAN DEFAULT false,
    ai_provider VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ecosystem health tracking
CREATE TABLE ecosystem_health (
    health_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    check_timestamp TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) NOT NULL,
    response_time_ms INTEGER,
    error_rate DECIMAL(5,4),
    cpu_usage DECIMAL(5,2),
    memory_usage DECIMAL(5,2),
    disk_usage DECIMAL(5,2),
    active_connections INTEGER,
    queue_depth INTEGER,
    last_error TEXT,
    degraded_functions TEXT[]
);

-- Create index for health queries
CREATE INDEX idx_ecosystem_health_code ON ecosystem_health(ecosystem_code);
CREATE INDEX idx_ecosystem_health_timestamp ON ecosystem_health(check_timestamp DESC);

-- ============================================================================
-- SECTION 2: FUNCTION MANAGEMENT
-- ============================================================================

-- Master function registry
CREATE TABLE functions (
    function_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) UNIQUE NOT NULL,
    function_name VARCHAR(200) NOT NULL,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    description TEXT,
    is_ai_powered BOOLEAN DEFAULT false,
    ai_provider VARCHAR(50),
    ai_model VARCHAR(100),
    cost_type VARCHAR(30),
    unit_cost DECIMAL(10,6),
    monthly_forecast_cost DECIMAL(12,2),
    quality_floor DECIMAL(5,2) DEFAULT 80.00,
    effectiveness_floor DECIMAL(5,2) DEFAULT 80.00,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function configuration (editable parameters)
CREATE TABLE function_config (
    config_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    config_key VARCHAR(100) NOT NULL,
    config_value TEXT,
    value_type VARCHAR(20) DEFAULT 'string',
    description TEXT,
    is_ai_prompt BOOLEAN DEFAULT false,
    is_editable BOOLEAN DEFAULT true,
    requires_restart BOOLEAN DEFAULT false,
    validation_rules JSONB,
    version INTEGER DEFAULT 1,
    modified_at TIMESTAMPTZ DEFAULT NOW(),
    modified_by VARCHAR(100),
    UNIQUE(function_code, config_key)
);

-- Function audit trail
CREATE TABLE function_audit (
    audit_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    action_type VARCHAR(20) NOT NULL,
    field_changed VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    change_reason TEXT,
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    ip_address INET
);

-- ============================================================================
-- SECTION 3: COST/BENEFIT ACCOUNTING
-- ============================================================================

-- Budget forecasts
CREATE TABLE budget_forecasts (
    forecast_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    period_type VARCHAR(20) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    forecast_calls INTEGER,
    forecast_records INTEGER,
    forecast_cost DECIMAL(12,2) NOT NULL,
    forecast_benefit DECIMAL(12,2),
    forecast_roi DECIMAL(8,2),
    assumptions JSONB,
    forecast_confidence DECIMAL(3,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(function_code, period_type, period_start)
);

-- Actual costs
CREATE TABLE actual_costs (
    actual_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    transaction_date DATE NOT NULL,
    transaction_timestamp TIMESTAMPTZ DEFAULT NOW(),
    call_count INTEGER DEFAULT 0,
    record_count INTEGER DEFAULT 0,
    actual_cost DECIMAL(12,2) NOT NULL,
    cost_breakdown JSONB,
    metadata JSONB
);

-- Actual benefits
CREATE TABLE actual_benefits (
    benefit_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    transaction_date DATE NOT NULL,
    benefit_type VARCHAR(50),
    benefit_amount DECIMAL(12,2) NOT NULL,
    benefit_calculation JSONB,
    attribution_confidence DECIMAL(3,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Variance analysis (auto-calculated)
CREATE TABLE variance_analysis (
    variance_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    period_type VARCHAR(20) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    forecast_cost DECIMAL(12,2),
    actual_cost DECIMAL(12,2),
    cost_variance DECIMAL(12,2),
    cost_variance_pct DECIMAL(6,2),
    forecast_benefit DECIMAL(12,2),
    actual_benefit DECIMAL(12,2),
    benefit_variance DECIMAL(12,2),
    benefit_variance_pct DECIMAL(6,2),
    forecast_roi DECIMAL(8,2),
    actual_roi DECIMAL(8,2),
    variance_status VARCHAR(20) NOT NULL,
    auto_correction_applied BOOLEAN DEFAULT false,
    correction_id INTEGER,
    analyzed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ecosystem cost rollup
CREATE TABLE ecosystem_costs (
    rollup_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    period_type VARCHAR(20) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_forecast DECIMAL(12,2),
    total_actual DECIMAL(12,2),
    total_variance DECIMAL(12,2),
    total_variance_pct DECIMAL(6,2),
    function_count INTEGER,
    functions_over_budget INTEGER,
    functions_under_budget INTEGER,
    health_score DECIMAL(5,2),
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(ecosystem_code, period_type, period_start)
);

-- Create indexes
CREATE INDEX idx_actual_costs_function ON actual_costs(function_code);
CREATE INDEX idx_actual_costs_date ON actual_costs(transaction_date);
CREATE INDEX idx_variance_status ON variance_analysis(variance_status);

-- ============================================================================
-- SECTION 4: AI GOVERNANCE
-- ============================================================================

-- AI models registry
CREATE TABLE ai_models (
    model_id SERIAL PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    model_code VARCHAR(100) UNIQUE NOT NULL,
    model_tier VARCHAR(20),
    cost_per_1k_input DECIMAL(10,6),
    cost_per_1k_output DECIMAL(10,6),
    max_context_tokens INTEGER,
    capabilities JSONB,
    rate_limit_rpm INTEGER,
    rate_limit_tpm INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI prompts library
CREATE TABLE ai_prompts (
    prompt_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    prompt_name VARCHAR(100) NOT NULL,
    prompt_template TEXT NOT NULL,
    system_prompt TEXT,
    model_preference VARCHAR(100),
    temperature DECIMAL(2,1) DEFAULT 0.7,
    max_tokens INTEGER DEFAULT 4000,
    version INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    modified_at TIMESTAMPTZ DEFAULT NOW(),
    modified_by VARCHAR(100)
);

-- AI prompt clarifications
CREATE TABLE ai_clarifications (
    clarification_id SERIAL PRIMARY KEY,
    prompt_id INTEGER REFERENCES ai_prompts(prompt_id),
    clarification_text TEXT NOT NULL,
    clarification_type VARCHAR(50) DEFAULT 'context',
    priority INTEGER DEFAULT 100,
    added_by VARCHAR(100) NOT NULL,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- AI usage tracking
CREATE TABLE ai_usage (
    usage_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    prompt_id INTEGER REFERENCES ai_prompts(prompt_id),
    model_code VARCHAR(100) REFERENCES ai_models(model_code),
    request_timestamp TIMESTAMPTZ DEFAULT NOW(),
    input_tokens INTEGER,
    output_tokens INTEGER,
    total_tokens INTEGER,
    input_cost DECIMAL(10,6),
    output_cost DECIMAL(10,6),
    total_cost DECIMAL(10,6),
    latency_ms INTEGER,
    success BOOLEAN,
    error_message TEXT,
    quality_score DECIMAL(5,2),
    metadata JSONB
);

-- Create indexes
CREATE INDEX idx_ai_usage_function ON ai_usage(function_code);
CREATE INDEX idx_ai_usage_timestamp ON ai_usage(request_timestamp);

-- ============================================================================
-- SECTION 5: SELF-CORRECTION ENGINE
-- ============================================================================

-- Self-correction rules
CREATE TABLE self_correction_rules (
    rule_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    trigger_condition VARCHAR(50) NOT NULL,
    trigger_operator VARCHAR(10) NOT NULL,
    threshold_value DECIMAL(10,2) NOT NULL,
    threshold_unit VARCHAR(20) NOT NULL,
    correction_action VARCHAR(50) NOT NULL,
    correction_parameters JSONB,
    quality_floor DECIMAL(5,2) DEFAULT 85.00,
    effectiveness_floor DECIMAL(5,2) DEFAULT 80.00,
    max_corrections_per_day INTEGER DEFAULT 10,
    cooldown_minutes INTEGER DEFAULT 60,
    requires_approval BOOLEAN DEFAULT false,
    priority INTEGER DEFAULT 100,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100)
);

-- Self-correction log
CREATE TABLE self_correction_log (
    correction_id SERIAL PRIMARY KEY,
    rule_id INTEGER REFERENCES self_correction_rules(rule_id),
    function_code VARCHAR(10) REFERENCES functions(function_code),
    triggered_at TIMESTAMPTZ DEFAULT NOW(),
    trigger_condition VARCHAR(100),
    trigger_value DECIMAL(10,2),
    threshold_value DECIMAL(10,2),
    correction_action VARCHAR(50),
    parameters_before JSONB,
    parameters_after JSONB,
    quality_before DECIMAL(5,2),
    quality_after DECIMAL(5,2),
    effectiveness_before DECIMAL(5,2),
    effectiveness_after DECIMAL(5,2),
    cost_before DECIMAL(10,2),
    cost_after DECIMAL(10,2),
    correction_status VARCHAR(20) NOT NULL,
    status_reason TEXT,
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    rolled_back_at TIMESTAMPTZ,
    rolled_back_by VARCHAR(100),
    rollback_reason TEXT
);

-- Quality metrics
CREATE TABLE quality_metrics (
    metric_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code),
    measurement_timestamp TIMESTAMPTZ DEFAULT NOW(),
    overall_quality_score DECIMAL(5,2),
    accuracy_score DECIMAL(5,2),
    consistency_score DECIMAL(5,2),
    completeness_score DECIMAL(5,2),
    overall_effectiveness DECIMAL(5,2),
    conversion_rate DECIMAL(5,4),
    engagement_rate DECIMAL(5,4),
    latency_avg_ms INTEGER,
    latency_p95_ms INTEGER,
    error_rate DECIMAL(5,4),
    sample_size INTEGER,
    measurement_method VARCHAR(50),
    metadata JSONB
);

-- Create indexes
CREATE INDEX idx_correction_log_function ON self_correction_log(function_code);
CREATE INDEX idx_correction_log_status ON self_correction_log(correction_status);
CREATE INDEX idx_quality_metrics_function ON quality_metrics(function_code);

-- ============================================================================
-- SECTION 6: ALERTS & NOTIFICATIONS
-- ============================================================================

-- Alerts
CREATE TABLE alerts (
    alert_id SERIAL PRIMARY KEY,
    alert_uuid UUID DEFAULT gen_random_uuid(),
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    function_code VARCHAR(10) REFERENCES functions(function_code),
    alert_title VARCHAR(200) NOT NULL,
    alert_message TEXT NOT NULL,
    alert_data JSONB,
    threshold_name VARCHAR(100),
    threshold_value DECIMAL(10,2),
    actual_value DECIMAL(10,2),
    suggested_action TEXT,
    auto_correctable BOOLEAN DEFAULT false,
    auto_correction_applied BOOLEAN DEFAULT false,
    correction_id INTEGER REFERENCES self_correction_log(correction_id),
    status VARCHAR(20) DEFAULT 'open',
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by VARCHAR(100),
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- Alert subscriptions
CREATE TABLE alert_subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    user_name VARCHAR(200),
    user_email VARCHAR(200),
    user_phone VARCHAR(20),
    ecosystem_code VARCHAR(20),
    function_code VARCHAR(10),
    severity_minimum VARCHAR(20) DEFAULT 'HIGH',
    alert_types JSONB,
    notification_email BOOLEAN DEFAULT true,
    notification_sms BOOLEAN DEFAULT false,
    notification_dashboard BOOLEAN DEFAULT true,
    notification_slack BOOLEAN DEFAULT false,
    slack_channel VARCHAR(100),
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Alert notifications log
CREATE TABLE alert_notifications (
    notification_id SERIAL PRIMARY KEY,
    alert_id INTEGER REFERENCES alerts(alert_id),
    subscription_id INTEGER REFERENCES alert_subscriptions(subscription_id),
    channel VARCHAR(20) NOT NULL,
    recipient VARCHAR(200),
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivery_status VARCHAR(20),
    delivery_details JSONB,
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ
);

-- Create indexes
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_created ON alerts(created_at DESC);

-- ============================================================================
-- SECTION 7: VENDOR MANAGEMENT
-- ============================================================================

-- Vendor registry
CREATE TABLE vendors (
    vendor_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) UNIQUE NOT NULL,
    vendor_name VARCHAR(100) NOT NULL,
    vendor_type VARCHAR(50) NOT NULL,
    api_base_url VARCHAR(500),
    auth_type VARCHAR(50),
    rate_limit_requests INTEGER,
    rate_limit_period VARCHAR(20),
    monthly_budget DECIMAL(12,2),
    monthly_quota INTEGER,
    status VARCHAR(20) DEFAULT 'active',
    health_check_endpoint VARCHAR(500),
    features JSONB,
    pricing JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vendor health tracking
CREATE TABLE vendor_health (
    health_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) REFERENCES vendors(vendor_code),
    check_timestamp TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) NOT NULL,
    response_time_ms INTEGER,
    error_rate DECIMAL(5,4),
    quota_used DECIMAL(12,2),
    quota_limit DECIMAL(12,2),
    budget_used DECIMAL(12,2),
    budget_limit DECIMAL(12,2),
    last_error TEXT
);

-- Vendor usage log
CREATE TABLE vendor_usage (
    usage_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) REFERENCES vendors(vendor_code),
    function_code VARCHAR(10) REFERENCES functions(function_code),
    request_timestamp TIMESTAMPTZ DEFAULT NOW(),
    endpoint VARCHAR(500),
    method VARCHAR(10),
    request_size_bytes INTEGER,
    response_size_bytes INTEGER,
    latency_ms INTEGER,
    status_code INTEGER,
    success BOOLEAN,
    error_message TEXT,
    cost DECIMAL(10,6),
    metadata JSONB
);

-- Create indexes
CREATE INDEX idx_vendor_health_code ON vendor_health(vendor_code);
CREATE INDEX idx_vendor_usage_code ON vendor_usage(vendor_code);
CREATE INDEX idx_vendor_usage_timestamp ON vendor_usage(request_timestamp);

-- ============================================================================
-- SECTION 8: CRM INTEGRATION
-- ============================================================================

-- CRM systems registry
CREATE TABLE crm_systems (
    crm_id SERIAL PRIMARY KEY,
    crm_code VARCHAR(50) UNIQUE NOT NULL,
    crm_name VARCHAR(100) NOT NULL,
    crm_type VARCHAR(50) NOT NULL,
    api_base_url VARCHAR(500),
    sync_frequency VARCHAR(20) DEFAULT 'hourly',
    bidirectional BOOLEAN DEFAULT true,
    entity_mappings JSONB,
    field_mappings JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- CRM sync log
CREATE TABLE crm_sync_log (
    sync_id SERIAL PRIMARY KEY,
    crm_code VARCHAR(50) REFERENCES crm_systems(crm_code),
    sync_timestamp TIMESTAMPTZ DEFAULT NOW(),
    sync_direction VARCHAR(20) NOT NULL,
    entity_type VARCHAR(50),
    records_synced INTEGER DEFAULT 0,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    sync_status VARCHAR(20) NOT NULL,
    error_message TEXT,
    duration_seconds INTEGER
);

-- CRM field mappings
CREATE TABLE crm_field_mappings (
    mapping_id SERIAL PRIMARY KEY,
    crm_code VARCHAR(50) REFERENCES crm_systems(crm_code),
    entity_type VARCHAR(50) NOT NULL,
    brain_field VARCHAR(100) NOT NULL,
    crm_field VARCHAR(100) NOT NULL,
    direction VARCHAR(20) DEFAULT 'bidirectional',
    transform_function VARCHAR(200),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SECTION 9: CRASH RECOVERY
-- ============================================================================

-- Crash events log
CREATE TABLE crash_events (
    crash_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    crash_timestamp TIMESTAMPTZ DEFAULT NOW(),
    crash_type VARCHAR(50),
    severity VARCHAR(20),
    error_message TEXT,
    stack_trace TEXT,
    affected_functions TEXT[],
    recovery_attempted BOOLEAN DEFAULT false,
    recovery_successful BOOLEAN,
    recovery_timestamp TIMESTAMPTZ,
    recovery_method VARCHAR(100),
    recovery_duration_seconds INTEGER,
    manual_intervention_required BOOLEAN DEFAULT false,
    notes TEXT
);

-- Recovery procedures
CREATE TABLE recovery_procedures (
    procedure_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    crash_type VARCHAR(50),
    procedure_name VARCHAR(200),
    steps JSONB NOT NULL,
    timeout_minutes INTEGER DEFAULT 10,
    retry_count INTEGER DEFAULT 3,
    requires_approval BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Recovery execution log
CREATE TABLE recovery_executions (
    execution_id SERIAL PRIMARY KEY,
    crash_id INTEGER REFERENCES crash_events(crash_id),
    procedure_id INTEGER REFERENCES recovery_procedures(procedure_id),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    steps_completed JSONB,
    status VARCHAR(20) NOT NULL,
    error_message TEXT,
    approved_by VARCHAR(100),
    executed_by VARCHAR(100)
);

-- ============================================================================
-- SECTION 10: CAMPAIGN MANAGEMENT INTEGRATION
-- ============================================================================

-- Campaign registry (linked to LIBERTY/EAGLE)
CREATE TABLE campaigns (
    campaign_id SERIAL PRIMARY KEY,
    campaign_uuid UUID DEFAULT gen_random_uuid(),
    campaign_name VARCHAR(200) NOT NULL,
    campaign_type VARCHAR(50),
    ecosystem_code VARCHAR(20) DEFAULT 'EAGLE',
    status VARCHAR(20) DEFAULT 'draft',
    candidate_id INTEGER,
    start_date DATE,
    end_date DATE,
    budget DECIMAL(12,2),
    actual_spend DECIMAL(12,2) DEFAULT 0,
    target_donors INTEGER,
    donors_reached INTEGER DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    donations_amount DECIMAL(12,2) DEFAULT 0,
    ai_generated BOOLEAN DEFAULT false,
    template_id INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Campaign performance metrics
CREATE TABLE campaign_metrics (
    metric_id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(campaign_id),
    metric_date DATE NOT NULL,
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    sms_sent INTEGER DEFAULT 0,
    sms_delivered INTEGER DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    donations_amount DECIMAL(12,2) DEFAULT 0,
    cost DECIMAL(12,2) DEFAULT 0,
    roi DECIMAL(8,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(campaign_id, metric_date)
);

-- ============================================================================
-- SECTION 11: BOOKKEEPING & ACCOUNTING
-- ============================================================================

-- Cost categories
CREATE TABLE cost_categories (
    category_id SERIAL PRIMARY KEY,
    category_code VARCHAR(50) UNIQUE NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    parent_category VARCHAR(50),
    description TEXT,
    is_active BOOLEAN DEFAULT true
);

-- Monthly budget allocations
CREATE TABLE budget_allocations (
    allocation_id SERIAL PRIMARY KEY,
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    category_code VARCHAR(50) REFERENCES cost_categories(category_code),
    allocated_amount DECIMAL(12,2) NOT NULL,
    notes TEXT,
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(fiscal_year, fiscal_month, ecosystem_code, category_code)
);

-- Monthly financial summary
CREATE TABLE financial_summaries (
    summary_id SERIAL PRIMARY KEY,
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    total_budget DECIMAL(12,2),
    total_actual DECIMAL(12,2),
    total_variance DECIMAL(12,2),
    variance_pct DECIMAL(6,2),
    ai_costs DECIMAL(12,2),
    vendor_costs DECIMAL(12,2),
    infrastructure_costs DECIMAL(12,2),
    total_revenue DECIMAL(12,2),
    total_donations DECIMAL(12,2),
    gross_margin_pct DECIMAL(6,2),
    recommendations JSONB,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(fiscal_year, fiscal_month)
);

-- ============================================================================
-- SECTION 12: VIEWS FOR REPORTING
-- ============================================================================

-- Platform health dashboard view
CREATE OR REPLACE VIEW v_platform_health AS
SELECT 
    e.ecosystem_code,
    e.ecosystem_name,
    e.status,
    e.criticality,
    eh.response_time_ms,
    eh.error_rate,
    eh.cpu_usage,
    eh.memory_usage,
    (SELECT COUNT(*) FROM alerts a WHERE a.ecosystem_code = e.ecosystem_code AND a.status = 'open') as open_alerts,
    (SELECT COUNT(*) FROM self_correction_log scl WHERE scl.function_code IN 
        (SELECT function_code FROM functions WHERE ecosystem_code = e.ecosystem_code)
        AND scl.triggered_at > NOW() - INTERVAL '24 hours') as corrections_24h
FROM ecosystems e
LEFT JOIN LATERAL (
    SELECT * FROM ecosystem_health 
    WHERE ecosystem_code = e.ecosystem_code 
    ORDER BY check_timestamp DESC LIMIT 1
) eh ON true;

-- Cost/Benefit summary view
CREATE OR REPLACE VIEW v_cost_benefit_summary AS
SELECT 
    f.ecosystem_code,
    f.function_code,
    f.function_name,
    f.is_ai_powered,
    f.monthly_forecast_cost as forecast,
    COALESCE(SUM(ac.actual_cost), 0) as actual,
    COALESCE(SUM(ac.actual_cost), 0) - f.monthly_forecast_cost as variance,
    CASE 
        WHEN f.monthly_forecast_cost > 0 
        THEN ((COALESCE(SUM(ac.actual_cost), 0) - f.monthly_forecast_cost) / f.monthly_forecast_cost * 100)
        ELSE 0 
    END as variance_pct,
    qm.overall_quality_score as quality
FROM functions f
LEFT JOIN actual_costs ac ON f.function_code = ac.function_code 
    AND ac.transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
LEFT JOIN LATERAL (
    SELECT overall_quality_score FROM quality_metrics 
    WHERE function_code = f.function_code 
    ORDER BY measurement_timestamp DESC LIMIT 1
) qm ON true
GROUP BY f.ecosystem_code, f.function_code, f.function_name, f.is_ai_powered, 
         f.monthly_forecast_cost, qm.overall_quality_score;

-- Vendor status view
CREATE OR REPLACE VIEW v_vendor_status AS
SELECT 
    v.vendor_code,
    v.vendor_name,
    v.vendor_type,
    v.monthly_budget,
    vh.status,
    vh.response_time_ms,
    vh.budget_used,
    vh.quota_used,
    vh.quota_limit,
    CASE 
        WHEN v.monthly_budget > 0 
        THEN (vh.budget_used / v.monthly_budget * 100)
        ELSE 0 
    END as budget_used_pct
FROM vendors v
LEFT JOIN LATERAL (
    SELECT * FROM vendor_health 
    WHERE vendor_code = v.vendor_code 
    ORDER BY check_timestamp DESC LIMIT 1
) vh ON true;

-- ============================================================================
-- SECTION 13: TRIGGERS
-- ============================================================================

-- Auto-update timestamps
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_ecosystems_timestamp
    BEFORE UPDATE ON ecosystems
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER tr_functions_timestamp
    BEFORE UPDATE ON functions
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER tr_campaigns_timestamp
    BEFORE UPDATE ON campaigns
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Auto-calculate variance status
CREATE OR REPLACE FUNCTION calculate_variance_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.variance_status = CASE
        WHEN ABS(COALESCE(NEW.cost_variance_pct, 0)) <= 5 THEN 'green'
        WHEN ABS(COALESCE(NEW.cost_variance_pct, 0)) <= 10 THEN 'yellow'
        WHEN ABS(COALESCE(NEW.cost_variance_pct, 0)) <= 20 THEN 'orange'
        WHEN ABS(COALESCE(NEW.cost_variance_pct, 0)) <= 50 THEN 'red'
        ELSE 'critical'
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_variance_status
    BEFORE INSERT OR UPDATE ON variance_analysis
    FOR EACH ROW EXECUTE FUNCTION calculate_variance_status();

-- ============================================================================
-- SECTION 14: INITIAL DATA LOAD
-- ============================================================================

-- Insert cost categories
INSERT INTO cost_categories (category_code, category_name, description) VALUES
('ai', 'AI Services', 'Claude, Perplexity, OpenAI costs'),
('data', 'Data Enrichment', 'BetterContact, WealthEngine, iWave, DonorSearch'),
('payment', 'Payment Processing', 'WinRed, Anedot transaction fees'),
('communication', 'Communication', 'Adobe Campaign, Twilio'),
('crm', 'CRM Services', 'Dynamics 365, EspoCRM'),
('infrastructure', 'Infrastructure', 'Hosting, databases, storage'),
('government', 'Government Data', 'FEC, NC SBOE, LegiScan'),
('media', 'Media Services', 'NewsAPI, media monitoring');

-- Insert default alert subscriptions for admin
INSERT INTO alert_subscriptions (user_id, user_name, user_email, severity_minimum, notification_email, notification_dashboard)
VALUES ('admin', 'System Administrator', 'admin@broyhillgop.com', 'CRITICAL', true, true);

-- Insert default recovery procedures
INSERT INTO recovery_procedures (ecosystem_code, crash_type, procedure_name, steps) VALUES
(NULL, 'service_down', 'Standard Service Recovery', '{"steps": ["check_dependencies", "restart_service", "verify_health", "notify_admin"]}'),
(NULL, 'database_error', 'Database Recovery', '{"steps": ["check_connection", "verify_schema", "run_repairs", "restart_service"]}'),
(NULL, 'memory_exhaustion', 'Memory Recovery', '{"steps": ["clear_cache", "restart_service", "scale_resources"]}');

-- ============================================================================
-- END SCHEMA
-- ============================================================================

COMMENT ON SCHEMA brain_control IS 'BRAIN Control System - Central AI & Automation Command Platform for BroyhillGOP';
