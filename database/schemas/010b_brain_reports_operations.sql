-- ============================================================================
-- BRAIN CONTROL SYSTEM - COMPREHENSIVE REPORTING VIEWS
-- ============================================================================
-- File: 010b_brain_reports_operations.sql
-- Operational reports, performance analytics, health monitoring
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: ECOSYSTEM HEALTH REPORTS
-- ============================================================================

-- Comprehensive ecosystem health report
CREATE OR REPLACE VIEW v_ecosystem_health_report AS
WITH latest_health AS (
    SELECT DISTINCT ON (ecosystem_code)
        ecosystem_code,
        status,
        response_time_ms,
        error_rate,
        cpu_usage,
        memory_usage,
        disk_usage,
        active_connections,
        queue_depth,
        check_timestamp
    FROM ecosystem_health
    ORDER BY ecosystem_code, check_timestamp DESC
),
health_24h AS (
    SELECT 
        ecosystem_code,
        AVG(response_time_ms) as avg_response_time_24h,
        AVG(error_rate) as avg_error_rate_24h,
        MAX(error_rate) as max_error_rate_24h,
        COUNT(*) FILTER (WHERE status != 'ACTIVE') as degraded_checks_24h,
        COUNT(*) as total_checks_24h
    FROM ecosystem_health
    WHERE check_timestamp > NOW() - INTERVAL '24 hours'
    GROUP BY ecosystem_code
),
function_summary AS (
    SELECT 
        ecosystem_code,
        COUNT(*) as total_functions,
        COUNT(*) FILTER (WHERE is_active) as active_functions,
        COUNT(*) FILTER (WHERE is_ai_powered) as ai_functions,
        COUNT(*) FILTER (WHERE is_critical) as critical_functions,
        SUM(monthly_forecast_cost) as total_budget
    FROM functions
    GROUP BY ecosystem_code
)
SELECT 
    e.ecosystem_code,
    e.ecosystem_name,
    e.criticality::TEXT,
    e.status::TEXT as config_status,
    
    -- Current health
    lh.status::TEXT as current_health_status,
    lh.response_time_ms as current_response_time_ms,
    lh.error_rate as current_error_rate,
    lh.cpu_usage,
    lh.memory_usage,
    lh.disk_usage,
    lh.active_connections,
    lh.queue_depth,
    lh.check_timestamp as last_health_check,
    
    -- 24-hour metrics
    ROUND(h24.avg_response_time_24h::NUMERIC, 2) as avg_response_time_24h,
    ROUND((h24.avg_error_rate_24h * 100)::NUMERIC, 4) as avg_error_rate_pct_24h,
    ROUND((h24.max_error_rate_24h * 100)::NUMERIC, 4) as max_error_rate_pct_24h,
    h24.degraded_checks_24h,
    h24.total_checks_24h,
    ROUND(((h24.total_checks_24h - h24.degraded_checks_24h)::DECIMAL / NULLIF(h24.total_checks_24h, 0) * 100)::NUMERIC, 2) as uptime_pct_24h,
    
    -- Function summary
    fs.total_functions,
    fs.active_functions,
    fs.ai_functions,
    fs.critical_functions,
    fs.total_budget,
    
    -- Dependencies
    e.dependencies,
    e.provides_to,
    
    -- Overall health score (0-100)
    GREATEST(0, LEAST(100,
        100 
        - (CASE WHEN lh.status = 'ACTIVE' THEN 0 WHEN lh.status = 'DEGRADED' THEN 20 ELSE 50 END)
        - (COALESCE(lh.error_rate, 0) * 100)
        - (CASE WHEN COALESCE(lh.cpu_usage, 0) > 80 THEN 10 ELSE 0 END)
        - (CASE WHEN COALESCE(lh.memory_usage, 0) > 80 THEN 10 ELSE 0 END)
        - (CASE WHEN COALESCE(lh.queue_depth, 0) > 1000 THEN 10 ELSE 0 END)
    ))::INTEGER as health_score

FROM ecosystems e
LEFT JOIN latest_health lh ON e.ecosystem_code = lh.ecosystem_code
LEFT JOIN health_24h h24 ON e.ecosystem_code = h24.ecosystem_code
LEFT JOIN function_summary fs ON e.ecosystem_code = fs.ecosystem_code
ORDER BY 
    CASE e.criticality WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
    e.ecosystem_name;

-- Ecosystem health trends (hourly for last 7 days)
CREATE OR REPLACE VIEW v_ecosystem_health_trends AS
SELECT 
    ecosystem_code,
    DATE_TRUNC('hour', check_timestamp) as hour,
    
    -- Status distribution
    COUNT(*) as check_count,
    COUNT(*) FILTER (WHERE status = 'ACTIVE') as active_count,
    COUNT(*) FILTER (WHERE status = 'DEGRADED') as degraded_count,
    COUNT(*) FILTER (WHERE status IN ('CRASHED', 'OFFLINE')) as down_count,
    
    -- Performance metrics
    ROUND(AVG(response_time_ms)::NUMERIC, 2) as avg_response_time_ms,
    MAX(response_time_ms) as max_response_time_ms,
    ROUND((AVG(error_rate) * 100)::NUMERIC, 4) as avg_error_rate_pct,
    
    -- Resource utilization
    ROUND(AVG(cpu_usage)::NUMERIC, 2) as avg_cpu_usage,
    ROUND(AVG(memory_usage)::NUMERIC, 2) as avg_memory_usage,
    ROUND(AVG(disk_usage)::NUMERIC, 2) as avg_disk_usage,
    
    -- Queue metrics
    ROUND(AVG(queue_depth)::NUMERIC, 0) as avg_queue_depth,
    MAX(queue_depth) as max_queue_depth

FROM ecosystem_health
WHERE check_timestamp > NOW() - INTERVAL '7 days'
GROUP BY ecosystem_code, DATE_TRUNC('hour', check_timestamp)
ORDER BY ecosystem_code, hour DESC;

-- ============================================================================
-- SECTION 2: FUNCTION PERFORMANCE REPORTS
-- ============================================================================

-- Detailed function performance report
CREATE OR REPLACE VIEW v_function_performance AS
SELECT 
    f.function_code,
    f.function_name,
    f.ecosystem_code,
    e.ecosystem_name,
    f.is_ai_powered,
    f.ai_provider,
    f.ai_model,
    
    -- Thresholds
    f.quality_floor,
    f.effectiveness_floor,
    f.latency_threshold_ms,
    f.error_rate_threshold,
    
    -- Current metrics (last 24 hours)
    COALESCE(fm.total_calls, 0) as calls_24h,
    COALESCE(fm.total_records, 0) as records_24h,
    ROUND(fm.avg_latency_ms::NUMERIC, 2) as avg_latency_ms,
    fm.p95_latency_ms,
    fm.p99_latency_ms,
    ROUND((fm.error_rate * 100)::NUMERIC, 4) as error_rate_pct,
    
    -- Quality metrics
    ROUND(qm.avg_quality::NUMERIC, 2) as quality_score,
    ROUND(qm.avg_effectiveness::NUMERIC, 2) as effectiveness_score,
    
    -- Cost metrics
    ROUND(fm.total_cost::NUMERIC, 4) as cost_24h,
    ROUND(fm.avg_cost_per_call::NUMERIC, 6) as avg_cost_per_call,
    
    -- AI metrics (if applicable)
    COALESCE(fm.ai_tokens_input, 0) as ai_tokens_input_24h,
    COALESCE(fm.ai_tokens_output, 0) as ai_tokens_output_24h,
    ROUND(fm.ai_cost::NUMERIC, 4) as ai_cost_24h,
    
    -- Status indicators
    COALESCE(qm.avg_quality, 100) >= f.quality_floor as meets_quality_floor,
    COALESCE(qm.avg_effectiveness, 100) >= f.effectiveness_floor as meets_effectiveness_floor,
    COALESCE(fm.avg_latency_ms, 0) <= f.latency_threshold_ms as meets_latency_threshold,
    COALESCE(fm.error_rate, 0) <= f.error_rate_threshold as meets_error_threshold,
    
    -- Overall performance score
    CASE 
        WHEN COALESCE(qm.avg_quality, 100) >= f.quality_floor 
             AND COALESCE(qm.avg_effectiveness, 100) >= f.effectiveness_floor
             AND COALESCE(fm.avg_latency_ms, 0) <= f.latency_threshold_ms
             AND COALESCE(fm.error_rate, 0) <= f.error_rate_threshold
        THEN 'Healthy'
        WHEN COALESCE(qm.avg_quality, 100) >= f.quality_floor * 0.9
             AND COALESCE(fm.error_rate, 0) <= f.error_rate_threshold * 2
        THEN 'Warning'
        ELSE 'Critical'
    END as performance_status

FROM functions f
JOIN ecosystems e ON f.ecosystem_code = e.ecosystem_code
LEFT JOIN LATERAL (
    SELECT 
        SUM(total_calls) as total_calls,
        SUM(total_records) as total_records,
        AVG(avg_latency_ms) as avg_latency_ms,
        MAX(p95_latency_ms) as p95_latency_ms,
        MAX(p99_latency_ms) as p99_latency_ms,
        AVG(error_rate) as error_rate,
        SUM(total_cost) as total_cost,
        AVG(avg_cost_per_call) as avg_cost_per_call,
        SUM(ai_tokens_input) as ai_tokens_input,
        SUM(ai_tokens_output) as ai_tokens_output,
        SUM(ai_cost) as ai_cost
    FROM function_metrics
    WHERE function_code = f.function_code
      AND period_start > NOW() - INTERVAL '24 hours'
) fm ON true
LEFT JOIN LATERAL (
    SELECT 
        AVG(overall_quality) as avg_quality,
        AVG(overall_effectiveness) as avg_effectiveness
    FROM quality_measurements
    WHERE function_code = f.function_code
      AND measurement_timestamp > NOW() - INTERVAL '24 hours'
) qm ON true
WHERE f.is_active
ORDER BY 
    CASE 
        WHEN COALESCE(qm.avg_quality, 100) < f.quality_floor THEN 1
        WHEN COALESCE(fm.error_rate, 0) > f.error_rate_threshold THEN 2
        ELSE 3
    END,
    f.ecosystem_code, f.function_code;

-- Function performance trends
CREATE OR REPLACE VIEW v_function_performance_trends AS
SELECT 
    fm.function_code,
    f.function_name,
    fm.period_start as hour,
    
    -- Volume
    fm.total_calls,
    fm.total_records,
    fm.successful_calls,
    fm.failed_calls,
    
    -- Performance
    ROUND(fm.avg_latency_ms::NUMERIC, 2) as avg_latency_ms,
    fm.p95_latency_ms,
    ROUND((fm.error_rate * 100)::NUMERIC, 4) as error_rate_pct,
    
    -- Quality
    fm.quality_score,
    
    -- Cost
    ROUND(fm.total_cost::NUMERIC, 4) as cost,
    
    -- Moving averages (requires window)
    ROUND(AVG(fm.avg_latency_ms) OVER (
        PARTITION BY fm.function_code 
        ORDER BY fm.period_start 
        ROWS BETWEEN 23 PRECEDING AND CURRENT ROW
    )::NUMERIC, 2) as latency_24h_ma,
    
    ROUND(AVG(fm.error_rate) OVER (
        PARTITION BY fm.function_code 
        ORDER BY fm.period_start 
        ROWS BETWEEN 23 PRECEDING AND CURRENT ROW
    ) * 100::NUMERIC, 4) as error_rate_24h_ma

FROM function_metrics fm
JOIN functions f ON fm.function_code = f.function_code
WHERE fm.period_type = 'hourly'
  AND fm.period_start > NOW() - INTERVAL '7 days'
ORDER BY fm.function_code, fm.period_start DESC;

-- ============================================================================
-- SECTION 3: AI OPERATIONS REPORTS
-- ============================================================================

-- AI model performance comparison
CREATE OR REPLACE VIEW v_ai_model_performance AS
SELECT 
    am.provider_code,
    am.model_code,
    am.model_name,
    am.model_tier,
    
    -- Pricing
    am.cost_per_1k_input,
    am.cost_per_1k_output,
    
    -- Usage (MTD)
    COALESCE(SUM(aud.request_count), 0) as mtd_requests,
    COALESCE(SUM(aud.total_input_tokens), 0) as mtd_input_tokens,
    COALESCE(SUM(aud.total_output_tokens), 0) as mtd_output_tokens,
    COALESCE(SUM(aud.total_cost), 0) as mtd_cost,
    
    -- Performance
    ROUND(AVG(aud.avg_latency_ms)::NUMERIC, 0) as avg_latency_ms,
    MAX(aud.p95_latency_ms) as max_p95_latency_ms,
    
    -- Quality
    ROUND(AVG(aud.avg_quality_score)::NUMERIC, 2) as avg_quality_score,
    
    -- Error rate
    ROUND((SUM(aud.failed_requests)::DECIMAL / NULLIF(SUM(aud.request_count), 0) * 100)::NUMERIC, 4) as error_rate_pct,
    
    -- Efficiency
    CASE WHEN SUM(aud.request_count) > 0 
        THEN ROUND((SUM(aud.total_cost) / SUM(aud.request_count))::NUMERIC, 6) 
        ELSE NULL 
    END as cost_per_request,
    
    -- Functions using this model
    COALESCE(func_count.count, 0) as functions_using

FROM ai_models am
LEFT JOIN ai_usage_daily aud ON am.model_code = aud.model_code
    AND aud.usage_date >= DATE_TRUNC('month', CURRENT_DATE)
LEFT JOIN LATERAL (
    SELECT COUNT(*) as count
    FROM functions
    WHERE ai_model = am.model_code AND is_active
) func_count ON true
WHERE am.is_active
GROUP BY am.provider_code, am.model_code, am.model_name, am.model_tier, 
         am.cost_per_1k_input, am.cost_per_1k_output, func_count.count
ORDER BY mtd_cost DESC;

-- Prompt performance analysis
CREATE OR REPLACE VIEW v_prompt_performance AS
SELECT 
    ap.prompt_id,
    ap.prompt_key,
    ap.prompt_name,
    ap.function_code,
    f.function_name,
    ap.preferred_model,
    
    -- Usage
    ap.usage_count,
    
    -- Quality
    ROUND(ap.avg_quality_score::NUMERIC, 2) as avg_quality_score,
    ROUND(ap.success_rate::NUMERIC, 4) as success_rate,
    
    -- Settings
    ap.temperature,
    ap.max_tokens,
    
    -- Versioning
    ap.version,
    ap.status,
    ap.is_active,
    
    -- Last modified
    ap.updated_at,
    
    -- Recent performance (last 7 days)
    COALESCE(recent.recent_uses, 0) as uses_last_7_days,
    ROUND(recent.recent_avg_quality::NUMERIC, 2) as quality_last_7_days,
    ROUND(recent.recent_success_rate::NUMERIC, 4) as success_rate_last_7_days

FROM ai_prompts ap
JOIN functions f ON ap.function_code = f.function_code
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as recent_uses,
        AVG(quality_score) as recent_avg_quality,
        AVG(CASE WHEN success THEN 1 ELSE 0 END) as recent_success_rate
    FROM ai_requests ar
    WHERE ar.prompt_id = ap.prompt_id
      AND ar.request_timestamp > NOW() - INTERVAL '7 days'
) recent ON true
WHERE ap.is_active
ORDER BY ap.usage_count DESC;

-- ============================================================================
-- SECTION 4: SELF-CORRECTION ANALYTICS
-- ============================================================================

-- Self-correction effectiveness report
CREATE OR REPLACE VIEW v_self_correction_effectiveness AS
SELECT 
    scr.rule_id,
    scr.rule_code,
    scr.rule_name,
    scr.correction_action::TEXT,
    scr.trigger_metric,
    scr.threshold_value,
    
    -- Scope
    scr.ecosystem_code,
    scr.function_code,
    
    -- Application stats (last 30 days)
    COALESCE(stats.times_triggered, 0) as times_triggered,
    COALESCE(stats.times_applied, 0) as times_applied,
    COALESCE(stats.times_blocked, 0) as times_blocked,
    COALESCE(stats.times_rolled_back, 0) as times_rolled_back,
    
    -- Success rate
    CASE WHEN stats.times_applied > 0 
        THEN ROUND(((stats.times_applied - COALESCE(stats.times_rolled_back, 0))::DECIMAL / stats.times_applied * 100)::NUMERIC, 2) 
        ELSE NULL 
    END as success_rate_pct,
    
    -- Impact
    ROUND(stats.avg_quality_improvement::NUMERIC, 2) as avg_quality_improvement,
    ROUND(stats.avg_cost_reduction::NUMERIC, 2) as avg_cost_reduction_pct,
    ROUND(stats.avg_latency_improvement::NUMERIC, 0) as avg_latency_improvement_ms,
    
    -- Guardrails
    scr.quality_floor,
    scr.effectiveness_floor,
    
    -- Status
    scr.is_active,
    scr.requires_approval

FROM self_correction_rules scr
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as times_triggered,
        COUNT(*) FILTER (WHERE correction_status = 'applied') as times_applied,
        COUNT(*) FILTER (WHERE correction_status = 'blocked') as times_blocked,
        COUNT(*) FILTER (WHERE is_rolled_back) as times_rolled_back,
        AVG(quality_change) FILTER (WHERE quality_change > 0) as avg_quality_improvement,
        AVG(-cost_change_pct) FILTER (WHERE cost_change_pct < 0) as avg_cost_reduction,
        AVG(-(latency_after_ms - latency_before_ms)) FILTER (WHERE latency_after_ms < latency_before_ms) as avg_latency_improvement
    FROM self_correction_log
    WHERE rule_id = scr.rule_id
      AND triggered_at > NOW() - INTERVAL '30 days'
) stats ON true
ORDER BY times_triggered DESC NULLS LAST;

-- Self-correction activity timeline
CREATE OR REPLACE VIEW v_self_correction_timeline AS
SELECT 
    scl.correction_id,
    scl.triggered_at,
    scl.function_code,
    f.function_name,
    f.ecosystem_code,
    scl.correction_action::TEXT,
    
    -- Trigger
    scl.trigger_metric,
    scl.trigger_value,
    scl.threshold_value,
    
    -- Before/After
    scl.quality_before,
    scl.quality_after,
    scl.quality_change,
    scl.cost_before,
    scl.cost_after,
    scl.cost_change_pct,
    scl.latency_before_ms,
    scl.latency_after_ms,
    
    -- Status
    scl.correction_status,
    scl.is_rolled_back,
    scl.requires_approval,
    scl.approved_by,
    
    -- Evaluation
    scl.evaluation_passed

FROM self_correction_log scl
JOIN functions f ON scl.function_code = f.function_code
ORDER BY scl.triggered_at DESC
LIMIT 500;

-- ============================================================================
-- SECTION 5: VENDOR OPERATIONS REPORTS
-- ============================================================================

-- Vendor operational health
CREATE OR REPLACE VIEW v_vendor_operations AS
WITH latest_health AS (
    SELECT DISTINCT ON (vendor_code)
        vendor_code,
        status,
        response_time_ms,
        error_rate,
        quota_used,
        quota_limit,
        budget_used,
        budget_limit,
        check_timestamp
    FROM vendor_health
    ORDER BY vendor_code, check_timestamp DESC
)
SELECT 
    v.vendor_code,
    v.vendor_name,
    v.vendor_type::TEXT,
    v.status as config_status,
    
    -- Health
    lh.status as health_status,
    lh.response_time_ms,
    ROUND((lh.error_rate * 100)::NUMERIC, 4) as error_rate_pct,
    lh.check_timestamp as last_check,
    
    -- Quota usage
    v.monthly_quota,
    COALESCE(lh.quota_used, 0) as quota_used,
    CASE WHEN v.monthly_quota > 0 
        THEN ROUND((COALESCE(lh.quota_used, 0) / v.monthly_quota * 100)::NUMERIC, 2) 
        ELSE 0 
    END as quota_used_pct,
    
    -- Budget usage
    v.monthly_budget,
    COALESCE(lh.budget_used, 0) as budget_used,
    CASE WHEN v.monthly_budget > 0 
        THEN ROUND((COALESCE(lh.budget_used, 0) / v.monthly_budget * 100)::NUMERIC, 2) 
        ELSE 0 
    END as budget_used_pct,
    
    -- Daily usage
    COALESCE(daily.request_count, 0) as requests_today,
    COALESCE(daily.total_cost, 0) as cost_today,
    
    -- Incidents
    COALESCE(incidents.open_count, 0) as open_incidents,
    
    -- Functions using
    COALESCE(func_count.count, 0) as functions_using,
    
    -- Contract
    v.contract_end_date,
    CASE WHEN v.contract_end_date IS NOT NULL 
        THEN v.contract_end_date - CURRENT_DATE 
        ELSE NULL 
    END as days_until_contract_end

FROM vendors v
LEFT JOIN latest_health lh ON v.vendor_code = lh.vendor_code
LEFT JOIN vendor_usage_daily daily ON v.vendor_code = daily.vendor_code
    AND daily.usage_date = CURRENT_DATE
LEFT JOIN LATERAL (
    SELECT COUNT(*) as open_count
    FROM vendor_incidents
    WHERE vendor_code = v.vendor_code AND status = 'open'
) incidents ON true
LEFT JOIN LATERAL (
    SELECT COUNT(DISTINCT function_code) as count
    FROM vendor_requests
    WHERE vendor_code = v.vendor_code
      AND request_timestamp > NOW() - INTERVAL '7 days'
) func_count ON true
ORDER BY v.vendor_type, v.vendor_name;

-- Vendor usage trends
CREATE OR REPLACE VIEW v_vendor_usage_trends AS
SELECT 
    vud.vendor_code,
    v.vendor_name,
    vud.usage_date,
    
    -- Volume
    vud.request_count,
    vud.successful_requests,
    vud.failed_requests,
    
    -- Cost
    vud.total_cost,
    v.monthly_budget,
    CASE WHEN v.monthly_budget > 0 
        THEN ROUND((vud.total_cost / v.monthly_budget * 100)::NUMERIC, 2) 
        ELSE 0 
    END as daily_budget_pct,
    
    -- Performance
    vud.avg_latency_ms,
    vud.p95_latency_ms,
    vud.availability_pct,
    
    -- Quota
    vud.quota_used,
    vud.quota_limit,
    vud.quota_used_pct,
    
    -- 7-day moving averages
    ROUND(AVG(vud.total_cost) OVER (
        PARTITION BY vud.vendor_code 
        ORDER BY vud.usage_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::NUMERIC, 2) as cost_7day_ma,
    
    ROUND(AVG(vud.request_count) OVER (
        PARTITION BY vud.vendor_code 
        ORDER BY vud.usage_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::NUMERIC, 0) as requests_7day_ma

FROM vendor_usage_daily vud
JOIN vendors v ON vud.vendor_code = v.vendor_code
WHERE vud.usage_date > CURRENT_DATE - INTERVAL '90 days'
ORDER BY vud.vendor_code, vud.usage_date DESC;

-- ============================================================================
-- SECTION 6: COMMENTS
-- ============================================================================

COMMENT ON VIEW v_ecosystem_health_report IS 'Comprehensive ecosystem health status with 24h metrics';
COMMENT ON VIEW v_ecosystem_health_trends IS 'Hourly ecosystem health trends for trending analysis';
COMMENT ON VIEW v_function_performance IS 'Detailed function performance with threshold comparisons';
COMMENT ON VIEW v_function_performance_trends IS 'Hourly function performance trends';
COMMENT ON VIEW v_ai_model_performance IS 'AI model usage and performance comparison';
COMMENT ON VIEW v_prompt_performance IS 'Prompt effectiveness analysis';
COMMENT ON VIEW v_self_correction_effectiveness IS 'Self-correction rule effectiveness metrics';
COMMENT ON VIEW v_self_correction_timeline IS 'Recent self-correction activity log';
COMMENT ON VIEW v_vendor_operations IS 'Vendor operational health and usage status';
COMMENT ON VIEW v_vendor_usage_trends IS 'Vendor usage trends over time';
