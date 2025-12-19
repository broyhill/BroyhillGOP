-- ============================================================================
-- BRAIN CONTROL SYSTEM - REPORTING VIEWS
-- ============================================================================
-- File: 010_brain_views.sql
-- Dashboard views, reporting views, materialized views
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: PLATFORM HEALTH DASHBOARD
-- ============================================================================

-- Overall platform health view
CREATE OR REPLACE VIEW v_platform_health AS
SELECT 
    e.ecosystem_code,
    e.ecosystem_name,
    e.status::TEXT as ecosystem_status,
    e.criticality::TEXT,
    e.monthly_budget,
    
    -- Latest health metrics
    eh.response_time_ms,
    eh.error_rate,
    eh.cpu_usage,
    eh.memory_usage,
    eh.disk_usage,
    eh.active_connections,
    eh.queue_depth,
    eh.last_error,
    eh.check_timestamp as last_health_check,
    
    -- Alert counts
    COALESCE(alert_counts.open_alerts, 0) as open_alerts,
    COALESCE(alert_counts.critical_alerts, 0) as critical_alerts,
    
    -- Correction counts (24h)
    COALESCE(correction_counts.corrections_24h, 0) as corrections_24h,
    
    -- Function summary
    COALESCE(func_summary.total_functions, 0) as total_functions,
    COALESCE(func_summary.active_functions, 0) as active_functions,
    COALESCE(func_summary.ai_functions, 0) as ai_functions

FROM ecosystems e

-- Latest health
LEFT JOIN LATERAL (
    SELECT * FROM ecosystem_health 
    WHERE ecosystem_code = e.ecosystem_code 
    ORDER BY check_timestamp DESC 
    LIMIT 1
) eh ON true

-- Alert counts
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) FILTER (WHERE status = 'open') as open_alerts,
        COUNT(*) FILTER (WHERE status = 'open' AND severity = 'CRITICAL') as critical_alerts
    FROM alerts 
    WHERE ecosystem_code = e.ecosystem_code
) alert_counts ON true

-- Correction counts
LEFT JOIN LATERAL (
    SELECT COUNT(*) as corrections_24h
    FROM self_correction_log scl
    JOIN functions f ON scl.function_code = f.function_code
    WHERE f.ecosystem_code = e.ecosystem_code
      AND scl.triggered_at > NOW() - INTERVAL '24 hours'
) correction_counts ON true

-- Function summary
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as total_functions,
        COUNT(*) FILTER (WHERE is_active) as active_functions,
        COUNT(*) FILTER (WHERE is_ai_powered) as ai_functions
    FROM functions
    WHERE ecosystem_code = e.ecosystem_code
) func_summary ON true;

-- ============================================================================
-- SECTION 2: COST/BENEFIT VIEWS
-- ============================================================================

-- Function cost/benefit summary
CREATE OR REPLACE VIEW v_function_cost_benefit AS
SELECT 
    f.ecosystem_code,
    f.function_code,
    f.function_name,
    f.is_ai_powered,
    f.ai_provider,
    f.ai_model,
    f.monthly_forecast_cost as forecast,
    
    -- Current month actual costs
    COALESCE(mc.total_cost, 0) as actual,
    COALESCE(mc.total_cost, 0) - f.monthly_forecast_cost as variance,
    CASE 
        WHEN f.monthly_forecast_cost > 0 
        THEN ROUND(((COALESCE(mc.total_cost, 0) - f.monthly_forecast_cost) / f.monthly_forecast_cost * 100)::NUMERIC, 2)
        ELSE 0 
    END as variance_pct,
    
    -- Variance status
    CASE 
        WHEN ABS(COALESCE(mc.total_cost, 0) - f.monthly_forecast_cost) / NULLIF(f.monthly_forecast_cost, 0) * 100 <= 5 THEN 'green'
        WHEN ABS(COALESCE(mc.total_cost, 0) - f.monthly_forecast_cost) / NULLIF(f.monthly_forecast_cost, 0) * 100 <= 10 THEN 'yellow'
        WHEN ABS(COALESCE(mc.total_cost, 0) - f.monthly_forecast_cost) / NULLIF(f.monthly_forecast_cost, 0) * 100 <= 20 THEN 'orange'
        WHEN ABS(COALESCE(mc.total_cost, 0) - f.monthly_forecast_cost) / NULLIF(f.monthly_forecast_cost, 0) * 100 <= 50 THEN 'red'
        ELSE 'critical'
    END as variance_status,
    
    -- Volume
    COALESCE(mc.total_calls, 0) as calls,
    COALESCE(mc.total_records, 0) as records,
    
    -- Quality
    qm.avg_quality as quality_score,
    f.quality_floor,
    COALESCE(qm.avg_quality, 100) >= f.quality_floor as meets_quality_floor

FROM functions f

-- Current month costs
LEFT JOIN monthly_costs mc ON f.function_code = mc.function_code
    AND mc.fiscal_year = EXTRACT(YEAR FROM CURRENT_DATE)
    AND mc.fiscal_month = EXTRACT(MONTH FROM CURRENT_DATE)

-- Latest quality
LEFT JOIN LATERAL (
    SELECT AVG(overall_quality) as avg_quality
    FROM quality_measurements
    WHERE function_code = f.function_code
      AND measurement_timestamp > NOW() - INTERVAL '7 days'
) qm ON true

WHERE f.is_active;

-- Ecosystem cost rollup view
CREATE OR REPLACE VIEW v_ecosystem_costs AS
SELECT 
    e.ecosystem_code,
    e.ecosystem_name,
    e.monthly_budget,
    
    -- Total forecast
    COALESCE(SUM(f.monthly_forecast_cost), 0) as total_forecast,
    
    -- Total actual
    COALESCE(SUM(mc.total_cost), 0) as total_actual,
    
    -- Variance
    COALESCE(SUM(mc.total_cost), 0) - COALESCE(SUM(f.monthly_forecast_cost), 0) as total_variance,
    
    -- Variance percentage
    CASE 
        WHEN SUM(f.monthly_forecast_cost) > 0 
        THEN ROUND(((COALESCE(SUM(mc.total_cost), 0) - SUM(f.monthly_forecast_cost)) / SUM(f.monthly_forecast_cost) * 100)::NUMERIC, 2)
        ELSE 0 
    END as variance_pct,
    
    -- Budget remaining
    e.monthly_budget - COALESCE(SUM(mc.total_cost), 0) as budget_remaining,
    
    -- Function counts
    COUNT(f.function_code) as function_count,
    COUNT(*) FILTER (WHERE COALESCE(mc.total_cost, 0) > f.monthly_forecast_cost) as over_budget_count

FROM ecosystems e
LEFT JOIN functions f ON e.ecosystem_code = f.ecosystem_code AND f.is_active
LEFT JOIN monthly_costs mc ON f.function_code = mc.function_code
    AND mc.fiscal_year = EXTRACT(YEAR FROM CURRENT_DATE)
    AND mc.fiscal_month = EXTRACT(MONTH FROM CURRENT_DATE)
GROUP BY e.ecosystem_code, e.ecosystem_name, e.monthly_budget;

-- ============================================================================
-- SECTION 3: VENDOR STATUS VIEWS
-- ============================================================================

-- Vendor status overview
CREATE OR REPLACE VIEW v_vendor_status AS
SELECT 
    v.vendor_code,
    v.vendor_name,
    v.vendor_type::TEXT,
    v.status,
    v.monthly_budget,
    v.monthly_quota,
    
    -- Latest health
    vh.status as health_status,
    vh.response_time_ms,
    vh.error_rate,
    vh.check_timestamp as last_check,
    
    -- Budget/Quota usage
    vh.budget_used,
    vh.budget_limit,
    CASE WHEN v.monthly_budget > 0 
        THEN ROUND((vh.budget_used / v.monthly_budget * 100)::NUMERIC, 2) 
        ELSE 0 
    END as budget_used_pct,
    
    vh.quota_used,
    vh.quota_limit,
    CASE WHEN v.monthly_quota > 0 
        THEN ROUND((vh.quota_used / v.monthly_quota * 100)::NUMERIC, 2) 
        ELSE 0 
    END as quota_used_pct,
    
    -- Incident count
    COALESCE(incident_count.open_incidents, 0) as open_incidents

FROM vendors v

LEFT JOIN LATERAL (
    SELECT * FROM vendor_health 
    WHERE vendor_code = v.vendor_code 
    ORDER BY check_timestamp DESC 
    LIMIT 1
) vh ON true

LEFT JOIN LATERAL (
    SELECT COUNT(*) as open_incidents
    FROM vendor_incidents
    WHERE vendor_code = v.vendor_code AND status = 'open'
) incident_count ON true;

-- ============================================================================
-- SECTION 4: AI USAGE VIEWS
-- ============================================================================

-- AI usage summary by provider
CREATE OR REPLACE VIEW v_ai_usage_by_provider AS
SELECT 
    provider_code,
    SUM(total_tokens) as total_tokens,
    SUM(total_cost) as total_cost,
    SUM(request_count) as total_requests,
    AVG(avg_latency_ms) as avg_latency_ms,
    AVG(avg_quality_score) as avg_quality_score
FROM ai_usage_daily
WHERE usage_date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY provider_code;

-- AI usage summary by function
CREATE OR REPLACE VIEW v_ai_usage_by_function AS
SELECT 
    f.function_code,
    f.function_name,
    f.ai_provider,
    f.ai_model,
    
    -- MTD usage
    COALESCE(SUM(aud.total_tokens), 0) as mtd_tokens,
    COALESCE(SUM(aud.total_cost), 0) as mtd_cost,
    COALESCE(SUM(aud.request_count), 0) as mtd_requests,
    
    -- Average quality
    COALESCE(AVG(aud.avg_quality_score), 0) as avg_quality,
    
    -- Average latency
    COALESCE(AVG(aud.avg_latency_ms), 0) as avg_latency_ms

FROM functions f
LEFT JOIN ai_usage_daily aud ON f.function_code = aud.function_code
    AND aud.usage_date >= DATE_TRUNC('month', CURRENT_DATE)
WHERE f.is_ai_powered
GROUP BY f.function_code, f.function_name, f.ai_provider, f.ai_model;

-- ============================================================================
-- SECTION 5: ALERT VIEWS
-- ============================================================================

-- Active alerts summary
CREATE OR REPLACE VIEW v_active_alerts AS
SELECT 
    a.alert_id,
    a.alert_uuid,
    a.severity::TEXT,
    a.ecosystem_code,
    e.ecosystem_name,
    a.function_code,
    f.function_name,
    a.alert_title,
    a.alert_message,
    a.suggested_action,
    a.auto_correctable,
    a.auto_correction_applied,
    a.status,
    a.created_at,
    a.acknowledged_at,
    a.acknowledged_by,
    EXTRACT(EPOCH FROM (NOW() - a.created_at)) / 60 as age_minutes
FROM alerts a
LEFT JOIN ecosystems e ON a.ecosystem_code = e.ecosystem_code
LEFT JOIN functions f ON a.function_code = f.function_code
WHERE a.status = 'open'
ORDER BY 
    CASE a.severity 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        WHEN 'LOW' THEN 4 
        ELSE 5 
    END,
    a.created_at DESC;

-- Alert statistics summary
CREATE OR REPLACE VIEW v_alert_statistics AS
SELECT 
    stat_date,
    ecosystem_code,
    critical_count,
    high_count,
    medium_count,
    low_count,
    total_count,
    acknowledged_count,
    resolved_count,
    auto_resolved_count,
    avg_time_to_acknowledge_minutes,
    avg_time_to_resolve_minutes,
    auto_corrected_count,
    notifications_sent
FROM alert_statistics_daily
WHERE stat_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY stat_date DESC;

-- ============================================================================
-- SECTION 6: SELF-CORRECTION VIEWS
-- ============================================================================

-- Recent self-corrections
CREATE OR REPLACE VIEW v_recent_corrections AS
SELECT 
    scl.correction_id,
    scl.correction_uuid,
    scl.function_code,
    f.function_name,
    f.ecosystem_code,
    scl.trigger_metric,
    scl.trigger_value,
    scl.threshold_value,
    scl.correction_action::TEXT,
    scl.quality_before,
    scl.quality_after,
    scl.quality_change,
    scl.cost_before,
    scl.cost_after,
    scl.cost_change_pct,
    scl.correction_status,
    scl.triggered_at,
    scl.is_rolled_back
FROM self_correction_log scl
JOIN functions f ON scl.function_code = f.function_code
ORDER BY scl.triggered_at DESC
LIMIT 100;

-- Self-correction summary by ecosystem
CREATE OR REPLACE VIEW v_correction_summary AS
SELECT 
    f.ecosystem_code,
    e.ecosystem_name,
    COUNT(*) as total_corrections,
    COUNT(*) FILTER (WHERE scl.correction_status = 'applied') as applied,
    COUNT(*) FILTER (WHERE scl.correction_status = 'rejected') as rejected,
    COUNT(*) FILTER (WHERE scl.is_rolled_back) as rolled_back,
    AVG(scl.quality_change) as avg_quality_improvement,
    AVG(scl.cost_change_pct) as avg_cost_change_pct
FROM self_correction_log scl
JOIN functions f ON scl.function_code = f.function_code
JOIN ecosystems e ON f.ecosystem_code = e.ecosystem_code
WHERE scl.triggered_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY f.ecosystem_code, e.ecosystem_name;

-- ============================================================================
-- SECTION 7: CAMPAIGN VIEWS
-- ============================================================================

-- Campaign performance overview
CREATE OR REPLACE VIEW v_campaign_performance AS
SELECT 
    c.campaign_id,
    c.campaign_code,
    c.campaign_name,
    c.campaign_type,
    c.status,
    c.candidate_name,
    c.actual_start_date,
    c.actual_end_date,
    c.budget_amount,
    c.budget_spent,
    
    -- Aggregated metrics
    COALESCE(SUM(m.emails_sent), 0) as total_emails_sent,
    COALESCE(SUM(m.emails_opened), 0) as total_emails_opened,
    COALESCE(SUM(m.emails_clicked), 0) as total_emails_clicked,
    COALESCE(SUM(m.donations_count), 0) as total_donations,
    COALESCE(SUM(m.donations_amount), 0) as total_donation_amount,
    COALESCE(SUM(m.cost), 0) as total_cost,
    
    -- Rates
    CASE WHEN SUM(m.emails_sent) > 0 
        THEN ROUND((SUM(m.emails_opened)::DECIMAL / SUM(m.emails_sent) * 100), 2) 
        ELSE 0 
    END as open_rate_pct,
    
    CASE WHEN SUM(m.emails_sent) > 0 
        THEN ROUND((SUM(m.emails_clicked)::DECIMAL / SUM(m.emails_sent) * 100), 2) 
        ELSE 0 
    END as click_rate_pct,
    
    -- ROI
    CASE WHEN SUM(m.cost) > 0 
        THEN ROUND(((SUM(m.donations_amount) - SUM(m.cost)) / SUM(m.cost) * 100), 2) 
        ELSE 0 
    END as roi_pct

FROM campaigns c
LEFT JOIN campaign_metrics_daily m ON c.campaign_id = m.campaign_id
GROUP BY c.campaign_id, c.campaign_code, c.campaign_name, c.campaign_type, 
         c.status, c.candidate_name, c.actual_start_date, c.actual_end_date,
         c.budget_amount, c.budget_spent;

-- ============================================================================
-- SECTION 8: CRM SYNC VIEWS
-- ============================================================================

-- CRM sync status
CREATE OR REPLACE VIEW v_crm_sync_status AS
SELECT 
    cs.crm_code,
    cs.crm_name,
    cs.crm_type,
    cs.status,
    cs.sync_frequency,
    cs.last_sync_at,
    cs.last_sync_status,
    
    -- Latest job
    lj.job_id as last_job_id,
    lj.started_at as last_job_started,
    lj.status as last_job_status,
    lj.records_synced,
    lj.records_failed,
    
    -- Daily stats
    ds.total_records_synced as today_records_synced,
    ds.records_failed as today_records_failed

FROM crm_systems cs

LEFT JOIN LATERAL (
    SELECT * FROM crm_sync_jobs
    WHERE crm_code = cs.crm_code
    ORDER BY started_at DESC
    LIMIT 1
) lj ON true

LEFT JOIN crm_sync_statistics_daily ds ON cs.crm_code = ds.crm_code
    AND ds.stat_date = CURRENT_DATE;

-- ============================================================================
-- SECTION 9: CAMPAIGN MANAGER DASHBOARD VIEW
-- ============================================================================

-- Complete dashboard data for campaign managers
CREATE OR REPLACE VIEW v_campaign_manager_dashboard AS
SELECT 
    -- Platform status
    (SELECT COUNT(*) FROM ecosystems WHERE status = 'ACTIVE') as ecosystems_active,
    (SELECT COUNT(*) FROM ecosystems WHERE status = 'DEGRADED') as ecosystems_degraded,
    (SELECT COUNT(*) FROM alerts WHERE status = 'open') as open_alerts,
    (SELECT COUNT(*) FROM alerts WHERE status = 'open' AND severity = 'CRITICAL') as critical_alerts,
    
    -- MTD costs
    (SELECT COALESCE(SUM(total_cost), 0) FROM monthly_costs 
     WHERE fiscal_year = EXTRACT(YEAR FROM CURRENT_DATE) 
     AND fiscal_month = EXTRACT(MONTH FROM CURRENT_DATE)) as mtd_costs,
    
    -- MTD AI costs
    (SELECT COALESCE(SUM(total_cost), 0) FROM ai_usage_daily 
     WHERE usage_date >= DATE_TRUNC('month', CURRENT_DATE)) as mtd_ai_costs,
    
    -- Corrections today
    (SELECT COUNT(*) FROM self_correction_log 
     WHERE triggered_at >= CURRENT_DATE) as corrections_today,
    
    -- Active campaigns
    (SELECT COUNT(*) FROM campaigns WHERE status = 'active') as active_campaigns,
    
    -- MTD donations
    (SELECT COALESCE(SUM(donations_amount), 0) FROM campaign_metrics_daily 
     WHERE metric_date >= DATE_TRUNC('month', CURRENT_DATE)) as mtd_donations,
    
    -- Vendor health
    (SELECT COUNT(*) FROM vendors WHERE status = 'active') as vendors_active,
    
    -- CRM sync status
    (SELECT COUNT(*) FROM crm_systems WHERE last_sync_status = 'success') as crm_syncs_healthy;

-- ============================================================================
-- SECTION 10: GRANT PERMISSIONS
-- ============================================================================

-- Grant SELECT on all views to reporting role (create role if needed)
-- CREATE ROLE brain_reporting;
-- GRANT SELECT ON ALL TABLES IN SCHEMA brain_control TO brain_reporting;

-- ============================================================================
-- SECTION 11: COMMENTS
-- ============================================================================

COMMENT ON VIEW v_platform_health IS 'Real-time platform health dashboard';
COMMENT ON VIEW v_function_cost_benefit IS 'Function-level cost/benefit analysis';
COMMENT ON VIEW v_vendor_status IS 'Vendor health and usage status';
COMMENT ON VIEW v_active_alerts IS 'Currently active alerts ordered by severity';
COMMENT ON VIEW v_campaign_performance IS 'Campaign performance metrics rollup';
