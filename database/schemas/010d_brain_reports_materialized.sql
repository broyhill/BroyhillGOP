-- ============================================================================
-- BRAIN CONTROL SYSTEM - COMPREHENSIVE REPORTING VIEWS
-- ============================================================================
-- File: 010d_brain_reports_materialized.sql
-- Materialized views for performance, scheduled report definitions
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: MATERIALIZED VIEWS FOR PERFORMANCE
-- ============================================================================

-- Daily platform summary (refresh hourly)
CREATE MATERIALIZED VIEW mv_daily_platform_summary AS
SELECT 
    CURRENT_DATE as summary_date,
    
    -- Ecosystem health
    (SELECT COUNT(*) FROM ecosystems WHERE status = 'ACTIVE') as active_ecosystems,
    (SELECT COUNT(*) FROM ecosystems WHERE status = 'DEGRADED') as degraded_ecosystems,
    (SELECT COUNT(*) FROM ecosystems WHERE status IN ('CRASHED', 'OFFLINE')) as offline_ecosystems,
    
    -- Functions
    (SELECT COUNT(*) FROM functions WHERE is_active) as active_functions,
    (SELECT COUNT(*) FROM functions WHERE is_ai_powered AND is_active) as ai_functions,
    
    -- Alerts (today)
    (SELECT COUNT(*) FROM alerts WHERE status = 'open') as open_alerts,
    (SELECT COUNT(*) FROM alerts WHERE status = 'open' AND severity = 'CRITICAL') as critical_alerts,
    (SELECT COUNT(*) FROM alerts WHERE created_at >= CURRENT_DATE) as alerts_today,
    
    -- Self-corrections (today)
    (SELECT COUNT(*) FROM self_correction_log WHERE triggered_at >= CURRENT_DATE) as corrections_today,
    
    -- Campaigns
    (SELECT COUNT(*) FROM campaigns WHERE status = 'active') as active_campaigns,
    
    -- Vendors
    (SELECT COUNT(*) FROM vendors WHERE status = 'active') as active_vendors,
    
    -- CRM syncs
    (SELECT COUNT(*) FROM crm_systems WHERE sync_enabled AND last_sync_status = 'success') as healthy_crm_syncs,
    
    -- Refresh timestamp
    NOW() as refreshed_at
WITH NO DATA;

-- Create unique index for refresh
CREATE UNIQUE INDEX ON mv_daily_platform_summary (summary_date);

-- MTD financial summary (refresh daily)
CREATE MATERIALIZED VIEW mv_mtd_financial_summary AS
SELECT 
    DATE_TRUNC('month', CURRENT_DATE) as month_start,
    
    -- Costs by category
    COALESCE(SUM(CASE WHEN cc.category_code = 'ai_services' THEN ct.total_cost ELSE 0 END), 0) as ai_costs,
    COALESCE(SUM(CASE WHEN cc.category_code = 'data_enrichment' THEN ct.total_cost ELSE 0 END), 0) as data_enrichment_costs,
    COALESCE(SUM(CASE WHEN cc.category_code = 'payment_processing' THEN ct.total_cost ELSE 0 END), 0) as payment_costs,
    COALESCE(SUM(CASE WHEN cc.category_code = 'communication' THEN ct.total_cost ELSE 0 END), 0) as communication_costs,
    COALESCE(SUM(CASE WHEN cc.category_code = 'crm_services' THEN ct.total_cost ELSE 0 END), 0) as crm_costs,
    COALESCE(SUM(CASE WHEN cc.category_code = 'infrastructure' THEN ct.total_cost ELSE 0 END), 0) as infrastructure_costs,
    COALESCE(SUM(ct.total_cost), 0) as total_costs,
    
    -- Budget
    (SELECT SUM(monthly_forecast_cost) FROM functions WHERE is_active) as total_budget,
    
    -- Variance
    COALESCE(SUM(ct.total_cost), 0) - 
        (SELECT COALESCE(SUM(monthly_forecast_cost), 0) FROM functions WHERE is_active) as budget_variance,
    
    -- Donations (from campaigns)
    (SELECT COALESCE(SUM(donations_amount), 0) FROM campaign_metrics_daily 
     WHERE metric_date >= DATE_TRUNC('month', CURRENT_DATE)) as mtd_donations,
    
    -- Refresh timestamp
    NOW() as refreshed_at

FROM cost_transactions ct
LEFT JOIN cost_categories cc ON ct.cost_category = cc.category_code
WHERE ct.transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
WITH NO DATA;

CREATE UNIQUE INDEX ON mv_mtd_financial_summary (month_start);

-- Weekly function performance (refresh daily)
CREATE MATERIALIZED VIEW mv_weekly_function_performance AS
SELECT 
    f.function_code,
    f.function_name,
    f.ecosystem_code,
    f.is_ai_powered,
    
    -- Volume (7 days)
    COALESCE(SUM(fm.total_calls), 0) as calls_7d,
    COALESCE(SUM(fm.total_records), 0) as records_7d,
    
    -- Performance
    ROUND(AVG(fm.avg_latency_ms)::NUMERIC, 2) as avg_latency_ms,
    MAX(fm.p95_latency_ms) as max_p95_latency_ms,
    ROUND((AVG(fm.error_rate) * 100)::NUMERIC, 4) as avg_error_rate_pct,
    
    -- Quality
    ROUND(AVG(fm.quality_score)::NUMERIC, 2) as avg_quality_score,
    
    -- Cost
    COALESCE(SUM(fm.total_cost), 0) as cost_7d,
    ROUND(AVG(fm.avg_cost_per_call)::NUMERIC, 6) as avg_cost_per_call,
    
    -- AI metrics
    COALESCE(SUM(fm.ai_tokens_input), 0) as ai_tokens_input_7d,
    COALESCE(SUM(fm.ai_tokens_output), 0) as ai_tokens_output_7d,
    
    -- Refresh timestamp
    NOW() as refreshed_at

FROM functions f
LEFT JOIN function_metrics fm ON f.function_code = fm.function_code
    AND fm.period_start >= NOW() - INTERVAL '7 days'
WHERE f.is_active
GROUP BY f.function_code, f.function_name, f.ecosystem_code, f.is_ai_powered
WITH NO DATA;

CREATE UNIQUE INDEX ON mv_weekly_function_performance (function_code);

-- Vendor health summary (refresh every 5 minutes)
CREATE MATERIALIZED VIEW mv_vendor_health_summary AS
SELECT 
    v.vendor_code,
    v.vendor_name,
    v.vendor_type::TEXT,
    
    -- Latest health
    lh.status as health_status,
    lh.response_time_ms,
    ROUND((lh.error_rate * 100)::NUMERIC, 4) as error_rate_pct,
    lh.check_timestamp as last_check,
    
    -- Quota
    v.monthly_quota,
    lh.quota_used,
    ROUND((lh.quota_used / NULLIF(v.monthly_quota, 0) * 100)::NUMERIC, 2) as quota_used_pct,
    
    -- Budget
    v.monthly_budget,
    lh.budget_used,
    ROUND((lh.budget_used / NULLIF(v.monthly_budget, 0) * 100)::NUMERIC, 2) as budget_used_pct,
    
    -- Status flags
    CASE WHEN lh.status = 'healthy' THEN true ELSE false END as is_healthy,
    CASE WHEN lh.quota_used / NULLIF(v.monthly_quota, 0) >= 0.9 THEN true ELSE false END as quota_warning,
    CASE WHEN lh.budget_used / NULLIF(v.monthly_budget, 0) >= 0.9 THEN true ELSE false END as budget_warning,
    
    NOW() as refreshed_at

FROM vendors v
LEFT JOIN LATERAL (
    SELECT * FROM vendor_health
    WHERE vendor_code = v.vendor_code
    ORDER BY check_timestamp DESC
    LIMIT 1
) lh ON true
WHERE v.status = 'active'
WITH NO DATA;

CREATE UNIQUE INDEX ON mv_vendor_health_summary (vendor_code);

-- ============================================================================
-- SECTION 2: SCHEDULED REPORT DEFINITIONS
-- ============================================================================

-- Report definitions table
CREATE TABLE report_definitions (
    report_id SERIAL PRIMARY KEY,
    report_code VARCHAR(50) UNIQUE NOT NULL,
    report_name VARCHAR(200) NOT NULL,
    report_description TEXT,
    
    -- Report type
    report_type VARCHAR(50) NOT NULL,
    report_category VARCHAR(50),
    
    -- Schedule
    schedule_type VARCHAR(20) NOT NULL,
    schedule_cron VARCHAR(100),
    schedule_timezone VARCHAR(50) DEFAULT 'America/New_York',
    
    -- Query
    source_view VARCHAR(100),
    custom_query TEXT,
    query_parameters JSONB,
    
    -- Output format
    output_format VARCHAR(20) DEFAULT 'email',
    output_options JSONB,
    
    -- Recipients
    recipients TEXT[],
    cc_recipients TEXT[],
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    last_run_at TIMESTAMPTZ,
    last_run_status VARCHAR(20),
    next_run_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Report execution log
CREATE TABLE report_executions (
    execution_id SERIAL PRIMARY KEY,
    report_id INTEGER NOT NULL REFERENCES report_definitions(report_id) ON DELETE CASCADE,
    
    -- Execution details
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Result
    status VARCHAR(20) NOT NULL,
    row_count INTEGER,
    file_size_bytes INTEGER,
    
    -- Delivery
    recipients_count INTEGER,
    delivered_count INTEGER,
    
    -- Errors
    error_message TEXT,
    
    -- Output reference
    output_location VARCHAR(500)
);

-- ============================================================================
-- SECTION 3: PRE-DEFINED REPORTS
-- ============================================================================

INSERT INTO report_definitions (report_code, report_name, report_description, report_type, report_category, schedule_type, schedule_cron, source_view) VALUES

-- Daily reports
('daily_executive_summary', 'Daily Executive Summary', 'Daily platform health and financial overview', 'summary', 'executive', 'daily', '0 6 * * *', 'v_executive_summary'),
('daily_alert_summary', 'Daily Alert Summary', 'Summary of all alerts from the previous day', 'summary', 'operations', 'daily', '0 7 * * *', 'v_alert_trends'),
('daily_cost_report', 'Daily Cost Report', 'Daily cost breakdown by ecosystem and function', 'detail', 'financial', 'daily', '0 8 * * *', 'v_cost_trends'),

-- Weekly reports
('weekly_platform_health', 'Weekly Platform Health Report', 'Weekly ecosystem health summary with trends', 'summary', 'operations', 'weekly', '0 8 * * 1', 'v_ecosystem_health_report'),
('weekly_function_performance', 'Weekly Function Performance', 'Function performance metrics for the week', 'detail', 'operations', 'weekly', '0 9 * * 1', 'v_function_performance'),
('weekly_ai_usage', 'Weekly AI Usage Report', 'AI provider and model usage summary', 'summary', 'financial', 'weekly', '0 9 * * 1', 'v_ai_model_performance'),
('weekly_campaign_summary', 'Weekly Campaign Summary', 'Campaign performance summary', 'summary', 'campaigns', 'weekly', '0 10 * * 1', 'v_campaign_dashboard'),
('weekly_vendor_review', 'Weekly Vendor Review', 'Vendor health and usage summary', 'detail', 'operations', 'weekly', '0 8 * * 1', 'v_vendor_operations'),

-- Monthly reports
('monthly_financial_summary', 'Monthly Financial Summary', 'P&L style financial report', 'summary', 'financial', 'monthly', '0 8 1 * *', 'v_monthly_pnl'),
('monthly_budget_variance', 'Monthly Budget Variance', 'Budget vs actual analysis', 'detail', 'financial', 'monthly', '0 9 1 * *', 'v_budget_vs_actual'),
('monthly_self_correction_analysis', 'Monthly Self-Correction Analysis', 'Self-correction rule effectiveness', 'detail', 'operations', 'monthly', '0 10 1 * *', 'v_self_correction_effectiveness'),
('monthly_crm_sync_report', 'Monthly CRM Sync Report', 'CRM synchronization statistics', 'summary', 'integrations', 'monthly', '0 8 1 * *', 'v_crm_sync_dashboard'),
('monthly_recovery_analysis', 'Monthly Recovery Analysis', 'Crash and recovery metrics', 'detail', 'operations', 'monthly', '0 11 1 * *', 'v_recovery_dashboard');

-- ============================================================================
-- SECTION 4: REFRESH FUNCTIONS
-- ============================================================================

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION refresh_all_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_platform_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_mtd_financial_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_weekly_function_performance;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vendor_health_summary;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh specific materialized view
CREATE OR REPLACE FUNCTION refresh_materialized_view(view_name TEXT)
RETURNS void AS $$
BEGIN
    EXECUTE format('REFRESH MATERIALIZED VIEW CONCURRENTLY %I', view_name);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 5: KPI DEFINITIONS
-- ============================================================================

-- KPI definitions for tracking
CREATE TABLE kpi_definitions (
    kpi_id SERIAL PRIMARY KEY,
    kpi_code VARCHAR(50) UNIQUE NOT NULL,
    kpi_name VARCHAR(200) NOT NULL,
    kpi_description TEXT,
    
    -- Category
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50),
    
    -- Calculation
    source_view VARCHAR(100),
    calculation_query TEXT,
    unit VARCHAR(30),
    
    -- Targets
    target_value DECIMAL(12,4),
    warning_threshold DECIMAL(12,4),
    critical_threshold DECIMAL(12,4),
    
    -- Direction (higher_is_better, lower_is_better)
    direction VARCHAR(20) DEFAULT 'higher_is_better',
    
    -- Display
    display_order INTEGER DEFAULT 100,
    is_key_metric BOOLEAN DEFAULT false,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pre-defined KPIs
INSERT INTO kpi_definitions (kpi_code, kpi_name, category, subcategory, unit, target_value, warning_threshold, critical_threshold, direction, is_key_metric) VALUES

-- Platform Health KPIs
('platform_uptime', 'Platform Uptime', 'health', 'availability', 'percent', 99.9, 99.5, 99.0, 'higher_is_better', true),
('ecosystem_health_score', 'Ecosystem Health Score', 'health', 'overall', 'score', 90, 80, 60, 'higher_is_better', true),
('active_alerts', 'Active Alerts', 'health', 'alerts', 'count', 0, 5, 10, 'lower_is_better', true),

-- Financial KPIs
('budget_variance_pct', 'Budget Variance', 'financial', 'budget', 'percent', 0, 10, 20, 'lower_is_better', true),
('cost_per_donor', 'Cost Per Donor', 'financial', 'efficiency', 'dollars', 0.50, 0.75, 1.00, 'lower_is_better', true),
('platform_roi', 'Platform ROI', 'financial', 'roi', 'percent', 500, 300, 100, 'higher_is_better', true),

-- AI KPIs
('ai_quality_score', 'AI Quality Score', 'ai', 'quality', 'score', 90, 85, 80, 'higher_is_better', true),
('ai_cost_per_request', 'AI Cost Per Request', 'ai', 'efficiency', 'dollars', 0.01, 0.02, 0.05, 'lower_is_better', false),

-- Operations KPIs
('avg_response_time', 'Avg Response Time', 'operations', 'performance', 'ms', 500, 1000, 2000, 'lower_is_better', true),
('error_rate', 'Error Rate', 'operations', 'reliability', 'percent', 0.1, 1.0, 5.0, 'lower_is_better', true),
('self_correction_rate', 'Self-Correction Success Rate', 'operations', 'automation', 'percent', 90, 80, 70, 'higher_is_better', false),

-- Campaign KPIs
('campaign_roi', 'Campaign ROI', 'campaigns', 'roi', 'percent', 500, 300, 100, 'higher_is_better', true),
('email_open_rate', 'Email Open Rate', 'campaigns', 'engagement', 'percent', 25, 20, 15, 'higher_is_better', false),
('donation_conversion_rate', 'Donation Conversion Rate', 'campaigns', 'conversion', 'percent', 5, 3, 1, 'higher_is_better', true),

-- Vendor KPIs
('vendor_availability', 'Vendor Availability', 'vendors', 'reliability', 'percent', 99.5, 99.0, 98.0, 'higher_is_better', false),
('vendor_budget_utilization', 'Vendor Budget Utilization', 'vendors', 'efficiency', 'percent', 85, 95, 100, 'lower_is_better', false);

-- KPI measurements log
CREATE TABLE kpi_measurements (
    measurement_id BIGSERIAL PRIMARY KEY,
    kpi_code VARCHAR(50) NOT NULL REFERENCES kpi_definitions(kpi_code),
    
    -- Measurement
    measured_at TIMESTAMPTZ DEFAULT NOW(),
    measured_value DECIMAL(12,4) NOT NULL,
    
    -- Context
    measurement_period VARCHAR(20),
    ecosystem_code VARCHAR(20),
    function_code VARCHAR(10),
    
    -- Status
    status VARCHAR(20),
    
    -- Metadata
    metadata JSONB
);

-- Index for KPI lookups
CREATE INDEX idx_kpi_measurements_code ON kpi_measurements(kpi_code);
CREATE INDEX idx_kpi_measurements_time ON kpi_measurements(measured_at DESC);

-- ============================================================================
-- SECTION 6: DASHBOARD CONFIGURATIONS
-- ============================================================================

-- Dashboard definitions
CREATE TABLE dashboard_definitions (
    dashboard_id SERIAL PRIMARY KEY,
    dashboard_code VARCHAR(50) UNIQUE NOT NULL,
    dashboard_name VARCHAR(200) NOT NULL,
    dashboard_description TEXT,
    
    -- Type
    dashboard_type VARCHAR(50),
    
    -- Access
    access_roles TEXT[],
    is_public BOOLEAN DEFAULT false,
    
    -- Layout
    layout_config JSONB,
    
    -- Widgets (JSON array of widget configs)
    widgets JSONB,
    
    -- Refresh
    auto_refresh_seconds INTEGER DEFAULT 60,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pre-defined dashboards
INSERT INTO dashboard_definitions (dashboard_code, dashboard_name, dashboard_type, is_public, auto_refresh_seconds, widgets) VALUES

('executive', 'Executive Dashboard', 'executive', false, 300, '[
    {"type": "kpi", "kpi_codes": ["platform_uptime", "budget_variance_pct", "platform_roi", "campaign_roi"]},
    {"type": "chart", "source": "v_cost_trends", "chart_type": "line"},
    {"type": "alerts", "source": "v_active_alerts_detail", "limit": 5},
    {"type": "summary", "source": "v_executive_summary"}
]'::jsonb),

('operations', 'Operations Dashboard', 'operations', false, 60, '[
    {"type": "health", "source": "v_ecosystem_health_report"},
    {"type": "alerts", "source": "v_active_alerts_detail"},
    {"type": "corrections", "source": "v_recent_corrections", "limit": 10},
    {"type": "vendors", "source": "mv_vendor_health_summary"}
]'::jsonb),

('financial', 'Financial Dashboard', 'financial', false, 300, '[
    {"type": "summary", "source": "mv_mtd_financial_summary"},
    {"type": "chart", "source": "v_budget_vs_actual", "chart_type": "bar"},
    {"type": "table", "source": "v_function_roi", "limit": 20},
    {"type": "chart", "source": "v_ai_roi_analysis", "chart_type": "pie"}
]'::jsonb),

('campaigns', 'Campaign Dashboard', 'campaigns', false, 300, '[
    {"type": "kpi", "kpi_codes": ["campaign_roi", "email_open_rate", "donation_conversion_rate"]},
    {"type": "table", "source": "v_campaign_dashboard", "limit": 10},
    {"type": "chart", "source": "v_campaign_segment_analysis", "chart_type": "bar"}
]'::jsonb),

('ai_governance', 'AI Governance Dashboard', 'ai', false, 120, '[
    {"type": "table", "source": "v_ai_model_performance"},
    {"type": "chart", "source": "v_ai_usage_by_provider", "chart_type": "pie"},
    {"type": "table", "source": "v_prompt_performance", "limit": 20}
]'::jsonb);

-- ============================================================================
-- SECTION 7: INDEXES AND COMMENTS
-- ============================================================================

-- Report indexes
CREATE INDEX idx_report_defs_active ON report_definitions(is_active) WHERE is_active = true;
CREATE INDEX idx_report_exec_report ON report_executions(report_id);
CREATE INDEX idx_report_exec_started ON report_executions(started_at DESC);

-- Dashboard indexes
CREATE INDEX idx_dashboard_active ON dashboard_definitions(is_active) WHERE is_active = true;

-- Comments
COMMENT ON MATERIALIZED VIEW mv_daily_platform_summary IS 'Daily platform summary - refresh hourly';
COMMENT ON MATERIALIZED VIEW mv_mtd_financial_summary IS 'MTD financial summary - refresh daily';
COMMENT ON MATERIALIZED VIEW mv_weekly_function_performance IS 'Weekly function performance - refresh daily';
COMMENT ON MATERIALIZED VIEW mv_vendor_health_summary IS 'Vendor health summary - refresh every 5 minutes';
COMMENT ON TABLE report_definitions IS 'Scheduled report definitions';
COMMENT ON TABLE kpi_definitions IS 'KPI metric definitions with targets';
COMMENT ON TABLE dashboard_definitions IS 'Dashboard layout and widget configurations';
