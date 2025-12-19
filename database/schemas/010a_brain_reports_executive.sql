-- ============================================================================
-- BRAIN CONTROL SYSTEM - COMPREHENSIVE REPORTING VIEWS
-- ============================================================================
-- File: 010a_brain_reports_executive.sql
-- Executive dashboards, financial reports, KPI summaries
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: EXECUTIVE DASHBOARD VIEWS
-- ============================================================================

-- Executive summary - single row with all key metrics
CREATE OR REPLACE VIEW v_executive_summary AS
WITH 
-- Platform metrics
platform_metrics AS (
    SELECT 
        COUNT(*) as total_ecosystems,
        COUNT(*) FILTER (WHERE status = 'ACTIVE') as active_ecosystems,
        COUNT(*) FILTER (WHERE status = 'DEGRADED') as degraded_ecosystems,
        COUNT(*) FILTER (WHERE status IN ('CRASHED', 'OFFLINE')) as offline_ecosystems
    FROM ecosystems
),

-- Function metrics
function_metrics AS (
    SELECT 
        COUNT(*) as total_functions,
        COUNT(*) FILTER (WHERE is_active) as active_functions,
        COUNT(*) FILTER (WHERE is_ai_powered AND is_active) as ai_functions,
        SUM(monthly_forecast_cost) as total_forecast_cost
    FROM functions
),

-- MTD cost metrics
mtd_costs AS (
    SELECT 
        COALESCE(SUM(total_cost), 0) as mtd_total_cost,
        COALESCE(SUM(ai_cost), 0) as mtd_ai_cost,
        COALESCE(SUM(vendor_cost), 0) as mtd_vendor_cost
    FROM monthly_costs
    WHERE fiscal_year = EXTRACT(YEAR FROM CURRENT_DATE)
      AND fiscal_month = EXTRACT(MONTH FROM CURRENT_DATE)
),

-- Alert metrics
alert_metrics AS (
    SELECT 
        COUNT(*) as total_open_alerts,
        COUNT(*) FILTER (WHERE severity = 'CRITICAL') as critical_alerts,
        COUNT(*) FILTER (WHERE severity = 'HIGH') as high_alerts,
        COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE) as alerts_today,
        AVG(EXTRACT(EPOCH FROM (COALESCE(acknowledged_at, NOW()) - created_at)) / 60) 
            FILTER (WHERE status != 'open') as avg_ack_time_minutes
    FROM alerts
    WHERE status = 'open' OR created_at >= CURRENT_DATE - INTERVAL '7 days'
),

-- Self-correction metrics
correction_metrics AS (
    SELECT 
        COUNT(*) as corrections_today,
        COUNT(*) FILTER (WHERE correction_status = 'applied') as successful_corrections,
        AVG(cost_change_pct) FILTER (WHERE cost_change_pct < 0) as avg_cost_savings_pct,
        AVG(quality_change) FILTER (WHERE quality_change > 0) as avg_quality_improvement
    FROM self_correction_log
    WHERE triggered_at >= CURRENT_DATE
),

-- Campaign metrics
campaign_metrics AS (
    SELECT 
        COUNT(*) FILTER (WHERE status = 'active') as active_campaigns,
        COALESCE(SUM(budget_spent), 0) as total_campaign_spend,
        COALESCE(SUM(donations_amount), 0) as total_donations
    FROM campaigns
    WHERE actual_start_date >= DATE_TRUNC('month', CURRENT_DATE)
       OR status = 'active'
),

-- Vendor metrics
vendor_metrics AS (
    SELECT 
        COUNT(*) as total_vendors,
        COUNT(*) FILTER (WHERE status = 'active') as active_vendors,
        COUNT(*) FILTER (WHERE v.status != 'active' OR vh.status = 'down') as vendors_with_issues
    FROM vendors v
    LEFT JOIN LATERAL (
        SELECT status FROM vendor_health 
        WHERE vendor_code = v.vendor_code 
        ORDER BY check_timestamp DESC LIMIT 1
    ) vh ON true
),

-- CRM sync metrics
crm_metrics AS (
    SELECT 
        COUNT(*) as total_crms,
        COUNT(*) FILTER (WHERE last_sync_status = 'success') as healthy_syncs,
        MAX(last_sync_at) as last_sync_time
    FROM crm_systems
    WHERE sync_enabled
)

SELECT 
    -- Timestamp
    NOW() as report_timestamp,
    CURRENT_DATE as report_date,
    
    -- Platform Health
    pm.total_ecosystems,
    pm.active_ecosystems,
    pm.degraded_ecosystems,
    pm.offline_ecosystems,
    ROUND((pm.active_ecosystems::DECIMAL / NULLIF(pm.total_ecosystems, 0) * 100), 1) as ecosystem_health_pct,
    
    -- Functions
    fm.total_functions,
    fm.active_functions,
    fm.ai_functions,
    
    -- Costs
    fm.total_forecast_cost as monthly_budget,
    mc.mtd_total_cost,
    mc.mtd_ai_cost,
    mc.mtd_vendor_cost,
    fm.total_forecast_cost - mc.mtd_total_cost as budget_remaining,
    ROUND((mc.mtd_total_cost / NULLIF(fm.total_forecast_cost, 0) * 100), 1) as budget_used_pct,
    
    -- Alerts
    am.total_open_alerts,
    am.critical_alerts,
    am.high_alerts,
    am.alerts_today,
    ROUND(am.avg_ack_time_minutes::NUMERIC, 1) as avg_ack_time_minutes,
    
    -- Self-Correction
    cm.corrections_today,
    cm.successful_corrections,
    ROUND(cm.avg_cost_savings_pct::NUMERIC, 2) as avg_cost_savings_pct,
    ROUND(cm.avg_quality_improvement::NUMERIC, 2) as avg_quality_improvement,
    
    -- Campaigns
    camp.active_campaigns,
    camp.total_campaign_spend,
    camp.total_donations,
    CASE WHEN camp.total_campaign_spend > 0 
        THEN ROUND(((camp.total_donations - camp.total_campaign_spend) / camp.total_campaign_spend * 100), 1)
        ELSE 0 
    END as campaign_roi_pct,
    
    -- Vendors
    vm.total_vendors,
    vm.active_vendors,
    vm.vendors_with_issues,
    
    -- CRM
    crm.total_crms,
    crm.healthy_syncs,
    crm.last_sync_time

FROM platform_metrics pm
CROSS JOIN function_metrics fm
CROSS JOIN mtd_costs mc
CROSS JOIN alert_metrics am
CROSS JOIN correction_metrics cm
CROSS JOIN campaign_metrics camp
CROSS JOIN vendor_metrics vm
CROSS JOIN crm_metrics crm;

-- ============================================================================
-- SECTION 2: FINANCIAL REPORTS
-- ============================================================================

-- Monthly P&L Report
CREATE OR REPLACE VIEW v_monthly_pnl AS
SELECT 
    fiscal_year,
    fiscal_month,
    TO_CHAR(period_start, 'Month YYYY') as period_name,
    
    -- Revenue / Benefits
    total_revenue,
    total_donations,
    total_benefits,
    total_revenue + total_donations + total_benefits as total_income,
    
    -- Costs by category
    ai_costs,
    vendor_costs,
    infrastructure_costs,
    payment_processor_costs,
    communication_costs,
    total_costs,
    
    -- Margins
    total_revenue + total_donations - total_costs as net_income,
    gross_margin,
    gross_margin_pct,
    net_margin,
    net_margin_pct,
    
    -- Budget comparison
    total_budget,
    budget_variance,
    budget_variance_pct,
    CASE 
        WHEN budget_variance_pct <= 5 THEN 'On Track'
        WHEN budget_variance_pct <= 10 THEN 'Watch'
        WHEN budget_variance_pct <= 20 THEN 'Warning'
        ELSE 'Critical'
    END as budget_status,
    
    -- ROI metrics
    platform_roi,
    ai_roi,
    
    -- Key metrics
    cost_per_donor,
    cost_per_donation,
    revenue_per_donor,
    
    -- Health
    ecosystems_healthy,
    ecosystems_degraded,
    functions_over_budget,
    self_corrections_count

FROM financial_summaries
ORDER BY fiscal_year DESC, fiscal_month DESC;

-- Cost breakdown by category
CREATE OR REPLACE VIEW v_cost_breakdown AS
WITH category_costs AS (
    SELECT 
        ct.cost_category,
        cc.category_name,
        ct.transaction_date,
        DATE_TRUNC('month', ct.transaction_date) as month_start,
        SUM(ct.total_cost) as total_cost
    FROM cost_transactions ct
    LEFT JOIN cost_categories cc ON ct.cost_category = cc.category_code
    WHERE ct.transaction_date >= DATE_TRUNC('year', CURRENT_DATE)
    GROUP BY ct.cost_category, cc.category_name, ct.transaction_date, DATE_TRUNC('month', ct.transaction_date)
)
SELECT 
    month_start,
    TO_CHAR(month_start, 'Mon YYYY') as month_name,
    cost_category,
    category_name,
    SUM(total_cost) as monthly_cost,
    SUM(SUM(total_cost)) OVER (PARTITION BY month_start) as month_total,
    ROUND((SUM(total_cost) / NULLIF(SUM(SUM(total_cost)) OVER (PARTITION BY month_start), 0) * 100)::NUMERIC, 2) as pct_of_total
FROM category_costs
GROUP BY month_start, cost_category, category_name
ORDER BY month_start DESC, monthly_cost DESC;

-- Cost trend analysis
CREATE OR REPLACE VIEW v_cost_trends AS
WITH daily_totals AS (
    SELECT 
        cost_date,
        SUM(total_cost) as daily_cost,
        SUM(ai_cost) as daily_ai_cost,
        SUM(vendor_cost) as daily_vendor_cost
    FROM daily_costs
    WHERE cost_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY cost_date
)
SELECT 
    cost_date,
    daily_cost,
    daily_ai_cost,
    daily_vendor_cost,
    -- 7-day moving average
    AVG(daily_cost) OVER (ORDER BY cost_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as cost_7day_ma,
    -- 30-day moving average
    AVG(daily_cost) OVER (ORDER BY cost_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) as cost_30day_ma,
    -- Day-over-day change
    daily_cost - LAG(daily_cost) OVER (ORDER BY cost_date) as dod_change,
    -- Week-over-week change
    daily_cost - LAG(daily_cost, 7) OVER (ORDER BY cost_date) as wow_change,
    -- Running total MTD
    SUM(daily_cost) OVER (
        PARTITION BY DATE_TRUNC('month', cost_date) 
        ORDER BY cost_date
    ) as mtd_running_total
FROM daily_totals
ORDER BY cost_date DESC;

-- Budget vs Actual by ecosystem
CREATE OR REPLACE VIEW v_budget_vs_actual AS
SELECT 
    e.ecosystem_code,
    e.ecosystem_name,
    e.monthly_budget as allocated_budget,
    
    -- Forecast (from functions)
    COALESCE(SUM(f.monthly_forecast_cost), 0) as forecast_cost,
    
    -- Actual MTD
    COALESCE(SUM(mc.total_cost), 0) as actual_cost,
    
    -- Variance calculations
    e.monthly_budget - COALESCE(SUM(mc.total_cost), 0) as budget_remaining,
    COALESCE(SUM(mc.total_cost), 0) - COALESCE(SUM(f.monthly_forecast_cost), 0) as forecast_variance,
    
    -- Variance percentages
    CASE WHEN e.monthly_budget > 0 
        THEN ROUND((COALESCE(SUM(mc.total_cost), 0) / e.monthly_budget * 100)::NUMERIC, 2) 
        ELSE 0 
    END as budget_used_pct,
    
    CASE WHEN SUM(f.monthly_forecast_cost) > 0 
        THEN ROUND(((COALESCE(SUM(mc.total_cost), 0) - SUM(f.monthly_forecast_cost)) / SUM(f.monthly_forecast_cost) * 100)::NUMERIC, 2) 
        ELSE 0 
    END as forecast_variance_pct,
    
    -- Status
    CASE 
        WHEN COALESCE(SUM(mc.total_cost), 0) <= e.monthly_budget * 0.8 THEN 'Under Budget'
        WHEN COALESCE(SUM(mc.total_cost), 0) <= e.monthly_budget THEN 'On Track'
        WHEN COALESCE(SUM(mc.total_cost), 0) <= e.monthly_budget * 1.1 THEN 'Slightly Over'
        ELSE 'Over Budget'
    END as budget_status,
    
    -- Function counts
    COUNT(f.function_code) as total_functions,
    COUNT(*) FILTER (WHERE mc.total_cost > f.monthly_forecast_cost * 1.1) as functions_over_forecast

FROM ecosystems e
LEFT JOIN functions f ON e.ecosystem_code = f.ecosystem_code AND f.is_active
LEFT JOIN monthly_costs mc ON f.function_code = mc.function_code
    AND mc.fiscal_year = EXTRACT(YEAR FROM CURRENT_DATE)
    AND mc.fiscal_month = EXTRACT(MONTH FROM CURRENT_DATE)
GROUP BY e.ecosystem_code, e.ecosystem_name, e.monthly_budget
ORDER BY actual_cost DESC;

-- ============================================================================
-- SECTION 3: ROI ANALYSIS VIEWS
-- ============================================================================

-- Function ROI analysis
CREATE OR REPLACE VIEW v_function_roi AS
SELECT 
    f.function_code,
    f.function_name,
    f.ecosystem_code,
    e.ecosystem_name,
    f.is_ai_powered,
    
    -- Costs
    COALESCE(mc.total_cost, 0) as mtd_cost,
    f.monthly_forecast_cost as forecast_cost,
    
    -- Benefits
    COALESCE(mb.total_benefit, 0) as mtd_benefit,
    COALESCE(mb.revenue_benefit, 0) as revenue_benefit,
    COALESCE(mb.donation_benefit, 0) as donation_benefit,
    COALESCE(mb.efficiency_benefit, 0) as efficiency_benefit,
    
    -- ROI calculation
    CASE WHEN COALESCE(mc.total_cost, 0) > 0 
        THEN ROUND(((COALESCE(mb.total_benefit, 0) - COALESCE(mc.total_cost, 0)) / mc.total_cost * 100)::NUMERIC, 2)
        ELSE NULL 
    END as roi_pct,
    
    -- Cost per unit metrics
    CASE WHEN mc.total_calls > 0 
        THEN ROUND((mc.total_cost / mc.total_calls)::NUMERIC, 4) 
        ELSE NULL 
    END as cost_per_call,
    
    CASE WHEN mc.total_records > 0 
        THEN ROUND((mc.total_cost / mc.total_records)::NUMERIC, 4) 
        ELSE NULL 
    END as cost_per_record,
    
    -- Benefit per unit
    CASE WHEN mc.total_calls > 0 
        THEN ROUND((COALESCE(mb.total_benefit, 0) / mc.total_calls)::NUMERIC, 4) 
        ELSE NULL 
    END as benefit_per_call,
    
    -- Volume
    COALESCE(mc.total_calls, 0) as mtd_calls,
    COALESCE(mc.total_records, 0) as mtd_records

FROM functions f
JOIN ecosystems e ON f.ecosystem_code = e.ecosystem_code
LEFT JOIN monthly_costs mc ON f.function_code = mc.function_code
    AND mc.fiscal_year = EXTRACT(YEAR FROM CURRENT_DATE)
    AND mc.fiscal_month = EXTRACT(MONTH FROM CURRENT_DATE)
LEFT JOIN monthly_benefits mb ON f.function_code = mb.function_code
    AND mb.fiscal_year = EXTRACT(YEAR FROM CURRENT_DATE)
    AND mb.fiscal_month = EXTRACT(MONTH FROM CURRENT_DATE)
WHERE f.is_active
ORDER BY roi_pct DESC NULLS LAST;

-- AI ROI analysis
CREATE OR REPLACE VIEW v_ai_roi_analysis AS
SELECT 
    ap.provider_code,
    ap.provider_name,
    
    -- Models used
    COUNT(DISTINCT am.model_code) as models_used,
    
    -- Usage
    COALESCE(SUM(aud.request_count), 0) as total_requests,
    COALESCE(SUM(aud.total_tokens), 0) as total_tokens,
    
    -- Costs
    COALESCE(SUM(aud.total_cost), 0) as total_cost,
    ap.monthly_budget,
    CASE WHEN ap.monthly_budget > 0 
        THEN ROUND((COALESCE(SUM(aud.total_cost), 0) / ap.monthly_budget * 100)::NUMERIC, 2) 
        ELSE 0 
    END as budget_used_pct,
    
    -- Quality
    ROUND(AVG(aud.avg_quality_score)::NUMERIC, 2) as avg_quality_score,
    
    -- Performance
    ROUND(AVG(aud.avg_latency_ms)::NUMERIC, 0) as avg_latency_ms,
    
    -- Cost efficiency
    CASE WHEN SUM(aud.request_count) > 0 
        THEN ROUND((SUM(aud.total_cost) / SUM(aud.request_count))::NUMERIC, 4) 
        ELSE NULL 
    END as avg_cost_per_request,
    
    CASE WHEN SUM(aud.total_tokens) > 0 
        THEN ROUND((SUM(aud.total_cost) / SUM(aud.total_tokens) * 1000)::NUMERIC, 4) 
        ELSE NULL 
    END as cost_per_1k_tokens

FROM ai_providers ap
LEFT JOIN ai_models am ON ap.provider_code = am.provider_code AND am.is_active
LEFT JOIN ai_usage_daily aud ON am.model_code = aud.model_code
    AND aud.usage_date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY ap.provider_code, ap.provider_name, ap.monthly_budget
ORDER BY total_cost DESC;

-- ============================================================================
-- SECTION 4: VARIANCE ANALYSIS REPORTS
-- ============================================================================

-- Variance dashboard
CREATE OR REPLACE VIEW v_variance_dashboard AS
SELECT 
    va.function_code,
    f.function_name,
    f.ecosystem_code,
    va.period_type,
    va.period_start,
    va.period_end,
    
    -- Cost variance
    va.forecast_cost,
    va.actual_cost,
    va.cost_variance,
    va.cost_variance_pct,
    va.cost_variance_status::TEXT as cost_status,
    
    -- Benefit variance
    va.forecast_benefit,
    va.actual_benefit,
    va.benefit_variance,
    va.benefit_variance_pct,
    
    -- ROI variance
    va.forecast_roi,
    va.actual_roi,
    va.roi_variance,
    
    -- Volume variance
    va.forecast_volume,
    va.actual_volume,
    va.volume_variance,
    va.volume_variance_pct,
    
    -- Analysis
    va.variance_drivers,
    va.root_cause,
    va.impact_assessment,
    
    -- Auto-correction
    va.auto_correction_eligible,
    va.auto_correction_applied,
    
    -- Review status
    va.reviewed_by IS NOT NULL as is_reviewed

FROM variance_analysis va
JOIN functions f ON va.function_code = f.function_code
WHERE va.period_start >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '3 months'
ORDER BY va.period_start DESC, ABS(va.cost_variance_pct) DESC;

-- Functions requiring attention (over budget or underperforming)
CREATE OR REPLACE VIEW v_functions_requiring_attention AS
SELECT 
    f.function_code,
    f.function_name,
    f.ecosystem_code,
    e.ecosystem_name,
    f.is_ai_powered,
    f.is_critical,
    
    -- Cost status
    f.monthly_forecast_cost as budget,
    COALESCE(mc.total_cost, 0) as actual_cost,
    COALESCE(mc.total_cost, 0) - f.monthly_forecast_cost as cost_variance,
    CASE WHEN f.monthly_forecast_cost > 0 
        THEN ROUND(((COALESCE(mc.total_cost, 0) - f.monthly_forecast_cost) / f.monthly_forecast_cost * 100)::NUMERIC, 2)
        ELSE 0 
    END as cost_variance_pct,
    
    -- Quality status
    f.quality_floor,
    COALESCE(qm.avg_quality, 100) as current_quality,
    COALESCE(qm.avg_quality, 100) < f.quality_floor as below_quality_floor,
    
    -- Error rate
    f.error_rate_threshold,
    COALESCE(fm.error_rate, 0) as current_error_rate,
    COALESCE(fm.error_rate, 0) > f.error_rate_threshold as above_error_threshold,
    
    -- Latency
    f.latency_threshold_ms,
    COALESCE(fm.avg_latency_ms, 0) as current_latency_ms,
    COALESCE(fm.avg_latency_ms, 0) > f.latency_threshold_ms as above_latency_threshold,
    
    -- Attention reasons
    ARRAY_REMOVE(ARRAY[
        CASE WHEN COALESCE(mc.total_cost, 0) > f.monthly_forecast_cost * 1.2 THEN 'Over Budget (>20%)' END,
        CASE WHEN COALESCE(qm.avg_quality, 100) < f.quality_floor THEN 'Below Quality Floor' END,
        CASE WHEN COALESCE(fm.error_rate, 0) > f.error_rate_threshold THEN 'High Error Rate' END,
        CASE WHEN COALESCE(fm.avg_latency_ms, 0) > f.latency_threshold_ms THEN 'High Latency' END
    ], NULL) as attention_reasons,
    
    -- Alert count
    COALESCE(ac.open_alerts, 0) as open_alerts

FROM functions f
JOIN ecosystems e ON f.ecosystem_code = e.ecosystem_code
LEFT JOIN monthly_costs mc ON f.function_code = mc.function_code
    AND mc.fiscal_year = EXTRACT(YEAR FROM CURRENT_DATE)
    AND mc.fiscal_month = EXTRACT(MONTH FROM CURRENT_DATE)
LEFT JOIN LATERAL (
    SELECT AVG(overall_quality) as avg_quality
    FROM quality_measurements
    WHERE function_code = f.function_code
      AND measurement_timestamp > NOW() - INTERVAL '24 hours'
) qm ON true
LEFT JOIN LATERAL (
    SELECT AVG(avg_latency_ms) as avg_latency_ms, AVG(error_rate) as error_rate
    FROM function_metrics
    WHERE function_code = f.function_code
      AND period_start > NOW() - INTERVAL '24 hours'
) fm ON true
LEFT JOIN LATERAL (
    SELECT COUNT(*) as open_alerts
    FROM alerts
    WHERE function_code = f.function_code AND status = 'open'
) ac ON true
WHERE f.is_active
  AND (
    COALESCE(mc.total_cost, 0) > f.monthly_forecast_cost * 1.2
    OR COALESCE(qm.avg_quality, 100) < f.quality_floor
    OR COALESCE(fm.error_rate, 0) > f.error_rate_threshold
    OR COALESCE(fm.avg_latency_ms, 0) > f.latency_threshold_ms
    OR COALESCE(ac.open_alerts, 0) > 0
  )
ORDER BY 
    CARDINALITY(ARRAY_REMOVE(ARRAY[
        CASE WHEN COALESCE(mc.total_cost, 0) > f.monthly_forecast_cost * 1.2 THEN 'x' END,
        CASE WHEN COALESCE(qm.avg_quality, 100) < f.quality_floor THEN 'x' END,
        CASE WHEN COALESCE(fm.error_rate, 0) > f.error_rate_threshold THEN 'x' END,
        CASE WHEN COALESCE(fm.avg_latency_ms, 0) > f.latency_threshold_ms THEN 'x' END
    ], NULL)) DESC,
    f.is_critical DESC;

-- ============================================================================
-- SECTION 5: COMMENTS
-- ============================================================================

COMMENT ON VIEW v_executive_summary IS 'Single-row executive dashboard with all key platform metrics';
COMMENT ON VIEW v_monthly_pnl IS 'Monthly P&L style financial report';
COMMENT ON VIEW v_cost_breakdown IS 'Cost breakdown by category and month';
COMMENT ON VIEW v_cost_trends IS 'Daily cost trends with moving averages';
COMMENT ON VIEW v_budget_vs_actual IS 'Budget vs actual comparison by ecosystem';
COMMENT ON VIEW v_function_roi IS 'Function-level ROI analysis';
COMMENT ON VIEW v_ai_roi_analysis IS 'AI provider ROI and usage analysis';
COMMENT ON VIEW v_variance_dashboard IS 'Cost and benefit variance analysis';
COMMENT ON VIEW v_functions_requiring_attention IS 'Functions with issues requiring attention';
