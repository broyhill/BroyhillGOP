-- ============================================================================
-- BRAIN CONTROL SYSTEM - COMPREHENSIVE REPORTING VIEWS
-- ============================================================================
-- File: 010c_brain_reports_campaigns.sql
-- Campaign analytics, CRM sync reports, alert analysis, recovery reports
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: CAMPAIGN ANALYTICS
-- ============================================================================

-- Campaign performance dashboard
CREATE OR REPLACE VIEW v_campaign_dashboard AS
SELECT 
    c.campaign_id,
    c.campaign_code,
    c.campaign_name,
    c.campaign_type,
    c.candidate_name,
    c.status,
    c.actual_start_date,
    c.actual_end_date,
    
    -- Duration
    CASE 
        WHEN c.actual_end_date IS NOT NULL THEN c.actual_end_date - c.actual_start_date
        WHEN c.actual_start_date IS NOT NULL THEN CURRENT_DATE - c.actual_start_date
        ELSE NULL
    END as days_running,
    
    -- Budget
    c.budget_amount,
    c.budget_spent,
    c.budget_amount - c.budget_spent as budget_remaining,
    CASE WHEN c.budget_amount > 0 
        THEN ROUND((c.budget_spent / c.budget_amount * 100)::NUMERIC, 2) 
        ELSE 0 
    END as budget_used_pct,
    
    -- Email metrics
    COALESCE(m.total_emails_sent, 0) as emails_sent,
    COALESCE(m.total_emails_delivered, 0) as emails_delivered,
    COALESCE(m.total_emails_opened, 0) as emails_opened,
    COALESCE(m.total_emails_clicked, 0) as emails_clicked,
    
    -- Rates
    CASE WHEN m.total_emails_delivered > 0 
        THEN ROUND((m.total_emails_opened::DECIMAL / m.total_emails_delivered * 100)::NUMERIC, 2) 
        ELSE 0 
    END as open_rate_pct,
    CASE WHEN m.total_emails_delivered > 0 
        THEN ROUND((m.total_emails_clicked::DECIMAL / m.total_emails_delivered * 100)::NUMERIC, 2) 
        ELSE 0 
    END as click_rate_pct,
    CASE WHEN m.total_emails_clicked > 0 
        THEN ROUND((m.total_donations::DECIMAL / m.total_emails_clicked * 100)::NUMERIC, 2) 
        ELSE 0 
    END as click_to_donate_rate_pct,
    
    -- Donations
    COALESCE(m.total_donations, 0) as donations_count,
    COALESCE(m.total_donation_amount, 0) as donations_amount,
    CASE WHEN m.total_donations > 0 
        THEN ROUND((m.total_donation_amount / m.total_donations)::NUMERIC, 2) 
        ELSE 0 
    END as avg_donation,
    
    -- Costs
    COALESCE(m.total_cost, 0) as total_cost,
    CASE WHEN m.total_emails_sent > 0 
        THEN ROUND((m.total_cost / m.total_emails_sent)::NUMERIC, 4) 
        ELSE 0 
    END as cost_per_email,
    CASE WHEN m.total_donations > 0 
        THEN ROUND((m.total_cost / m.total_donations)::NUMERIC, 2) 
        ELSE 0 
    END as cost_per_donation,
    
    -- ROI
    CASE WHEN m.total_cost > 0 
        THEN ROUND(((m.total_donation_amount - m.total_cost) / m.total_cost * 100)::NUMERIC, 2) 
        ELSE 0 
    END as roi_pct,
    
    -- A/B tests
    COALESCE(ab.test_count, 0) as ab_tests_count,
    COALESCE(ab.completed_tests, 0) as completed_tests

FROM campaigns c
LEFT JOIN LATERAL (
    SELECT 
        SUM(emails_sent) as total_emails_sent,
        SUM(emails_delivered) as total_emails_delivered,
        SUM(emails_opened) as total_emails_opened,
        SUM(emails_clicked) as total_emails_clicked,
        SUM(donations_count) as total_donations,
        SUM(donations_amount) as total_donation_amount,
        SUM(cost) as total_cost
    FROM campaign_metrics_daily
    WHERE campaign_id = c.campaign_id
) m ON true
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as test_count,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_tests
    FROM campaign_ab_tests
    WHERE campaign_id = c.campaign_id
) ab ON true
ORDER BY c.actual_start_date DESC NULLS LAST, c.campaign_name;

-- Campaign performance by segment
CREATE OR REPLACE VIEW v_campaign_segment_analysis AS
SELECT 
    csm.campaign_id,
    c.campaign_name,
    csm.segment_name,
    csm.segment_size,
    
    -- Volume
    csm.sends,
    csm.delivered,
    csm.opened,
    csm.clicked,
    csm.conversions,
    csm.donations_amount,
    
    -- Rates
    csm.open_rate * 100 as open_rate_pct,
    csm.click_rate * 100 as click_rate_pct,
    csm.conversion_rate * 100 as conversion_rate_pct,
    
    -- Performance vs average
    csm.vs_avg_open_rate,
    csm.vs_avg_click_rate,
    csm.vs_avg_conversion_rate,
    
    -- Performance tier
    CASE 
        WHEN csm.vs_avg_conversion_rate >= 20 THEN 'Top Performer'
        WHEN csm.vs_avg_conversion_rate >= 0 THEN 'Above Average'
        WHEN csm.vs_avg_conversion_rate >= -20 THEN 'Below Average'
        ELSE 'Underperformer'
    END as performance_tier,
    
    -- Average donation
    CASE WHEN csm.conversions > 0 
        THEN ROUND((csm.donations_amount / csm.conversions)::NUMERIC, 2) 
        ELSE 0 
    END as avg_donation

FROM campaign_segment_metrics csm
JOIN campaigns c ON csm.campaign_id = c.campaign_id
ORDER BY csm.campaign_id, csm.vs_avg_conversion_rate DESC;

-- Campaign A/B test results
CREATE OR REPLACE VIEW v_campaign_ab_results AS
SELECT 
    abt.test_id,
    abt.campaign_id,
    c.campaign_name,
    abt.test_name,
    abt.test_type,
    abt.status,
    abt.started_at,
    abt.ended_at,
    
    -- Sample
    abt.target_sample_size,
    abt.actual_sample_size,
    CASE WHEN abt.target_sample_size > 0 
        THEN ROUND((abt.actual_sample_size::DECIMAL / abt.target_sample_size * 100)::NUMERIC, 2) 
        ELSE 0 
    END as sample_completion_pct,
    
    -- Winner
    abt.winning_variant,
    abt.statistical_significance,
    abt.confidence_level,
    
    -- Variant metrics
    variants.variant_data,
    
    -- AI analysis
    abt.ai_analysis

FROM campaign_ab_tests abt
JOIN campaigns c ON abt.campaign_id = c.campaign_id
LEFT JOIN LATERAL (
    SELECT jsonb_agg(jsonb_build_object(
        'variant', variant_name,
        'sends', sends,
        'open_rate', ROUND((open_rate * 100)::NUMERIC, 2),
        'click_rate', ROUND((click_rate * 100)::NUMERIC, 2),
        'conversion_rate', ROUND((conversion_rate * 100)::NUMERIC, 2),
        'is_winner', is_winner,
        'lift_vs_control', ROUND((lift_vs_control * 100)::NUMERIC, 2)
    ) ORDER BY is_winner DESC, conversion_rate DESC) as variant_data
    FROM campaign_ab_variant_metrics
    WHERE test_id = abt.test_id
) variants ON true
ORDER BY abt.started_at DESC;

-- Campaign template effectiveness
CREATE OR REPLACE VIEW v_campaign_template_effectiveness AS
SELECT 
    ct.template_id,
    ct.template_code,
    ct.template_name,
    ct.campaign_type,
    ct.channel_type,
    
    -- Usage
    ct.times_used,
    
    -- Performance averages
    ROUND((ct.avg_open_rate * 100)::NUMERIC, 2) as avg_open_rate_pct,
    ROUND((ct.avg_click_rate * 100)::NUMERIC, 2) as avg_click_rate_pct,
    ROUND((ct.avg_conversion_rate * 100)::NUMERIC, 2) as avg_conversion_rate_pct,
    
    -- AI
    ct.ai_generated,
    ct.status,
    
    -- Recent usage (last 30 days)
    COALESCE(recent.recent_uses, 0) as uses_last_30_days,
    ROUND((recent.recent_avg_open * 100)::NUMERIC, 2) as recent_open_rate_pct,
    ROUND((recent.recent_avg_click * 100)::NUMERIC, 2) as recent_click_rate_pct

FROM campaign_templates ct
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as recent_uses,
        AVG(m.emails_opened::DECIMAL / NULLIF(m.emails_delivered, 0)) as recent_avg_open,
        AVG(m.emails_clicked::DECIMAL / NULLIF(m.emails_delivered, 0)) as recent_avg_click
    FROM campaigns c
    JOIN campaign_metrics_daily m ON c.campaign_id = m.campaign_id
    WHERE c.actual_start_date > CURRENT_DATE - INTERVAL '30 days'
    -- Would need template_id on campaigns to properly filter
) recent ON true
WHERE ct.status = 'approved'
ORDER BY ct.times_used DESC;

-- ============================================================================
-- SECTION 2: CRM SYNC REPORTS
-- ============================================================================

-- CRM sync status dashboard
CREATE OR REPLACE VIEW v_crm_sync_dashboard AS
SELECT 
    cs.crm_code,
    cs.crm_name,
    cs.crm_type,
    cs.sync_frequency,
    cs.status as config_status,
    
    -- Last sync
    cs.last_sync_at,
    cs.last_sync_status,
    NOW() - cs.last_sync_at as time_since_last_sync,
    
    -- Is overdue?
    CASE 
        WHEN cs.sync_frequency = 'realtime' AND NOW() - cs.last_sync_at > INTERVAL '5 minutes' THEN true
        WHEN cs.sync_frequency = 'hourly' AND NOW() - cs.last_sync_at > INTERVAL '90 minutes' THEN true
        WHEN cs.sync_frequency = 'daily' AND NOW() - cs.last_sync_at > INTERVAL '36 hours' THEN true
        ELSE false
    END as is_sync_overdue,
    
    -- Latest job stats
    lj.job_id as last_job_id,
    lj.status as last_job_status,
    lj.records_processed as last_records_processed,
    lj.records_created as last_records_created,
    lj.records_updated as last_records_updated,
    lj.records_failed as last_records_failed,
    lj.error_count as last_error_count,
    
    -- Today's stats
    COALESCE(today.jobs_run, 0) as jobs_today,
    COALESCE(today.total_synced, 0) as records_synced_today,
    COALESCE(today.total_failed, 0) as records_failed_today,
    
    -- Conflicts
    COALESCE(conflicts.pending_count, 0) as pending_conflicts,
    
    -- Entity sync status
    entity_status.entities as entity_statuses

FROM crm_systems cs
LEFT JOIN LATERAL (
    SELECT * FROM crm_sync_jobs
    WHERE crm_code = cs.crm_code
    ORDER BY started_at DESC
    LIMIT 1
) lj ON true
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as jobs_run,
        SUM(records_processed) as total_synced,
        SUM(records_failed) as total_failed
    FROM crm_sync_jobs
    WHERE crm_code = cs.crm_code
      AND started_at >= CURRENT_DATE
) today ON true
LEFT JOIN LATERAL (
    SELECT COUNT(*) as pending_count
    FROM crm_sync_conflicts
    WHERE crm_code = cs.crm_code AND status = 'pending'
) conflicts ON true
LEFT JOIN LATERAL (
    SELECT jsonb_object_agg(entity_name, sync_enabled) as entities
    FROM crm_entity_types
    WHERE crm_code = cs.crm_code
) entity_status ON true
WHERE cs.sync_enabled
ORDER BY cs.is_primary DESC, cs.crm_name;

-- CRM sync job history
CREATE OR REPLACE VIEW v_crm_sync_history AS
SELECT 
    csj.job_id,
    csj.crm_code,
    cs.crm_name,
    csj.sync_direction::TEXT,
    csj.is_full_sync,
    csj.entity_types,
    
    -- Timing
    csj.started_at,
    csj.completed_at,
    csj.duration_seconds,
    ROUND(csj.records_per_second::NUMERIC, 2) as records_per_second,
    
    -- Progress
    csj.status,
    csj.progress_pct,
    
    -- Counts
    csj.total_records,
    csj.records_processed,
    csj.records_created,
    csj.records_updated,
    csj.records_deleted,
    csj.records_skipped,
    csj.records_failed,
    
    -- Success rate
    CASE WHEN csj.records_processed > 0 
        THEN ROUND(((csj.records_processed - csj.records_failed)::DECIMAL / csj.records_processed * 100)::NUMERIC, 2) 
        ELSE 100 
    END as success_rate_pct,
    
    -- Errors
    csj.error_count,
    csj.last_error,
    
    -- Trigger
    csj.triggered_by

FROM crm_sync_jobs csj
JOIN crm_systems cs ON csj.crm_code = cs.crm_code
ORDER BY csj.started_at DESC
LIMIT 500;

-- CRM sync conflicts
CREATE OR REPLACE VIEW v_crm_sync_conflicts AS
SELECT 
    csc.conflict_id,
    csc.crm_code,
    cs.crm_name,
    csc.entity_name,
    csc.brain_id,
    csc.crm_id,
    csc.conflict_type,
    csc.field_name,
    csc.brain_value,
    csc.crm_value,
    csc.status,
    csc.resolution,
    csc.resolved_value,
    csc.resolved_by,
    csc.resolved_at,
    csc.detected_at,
    NOW() - csc.detected_at as age

FROM crm_sync_conflicts csc
JOIN crm_systems cs ON csc.crm_code = cs.crm_code
ORDER BY 
    CASE WHEN csc.status = 'pending' THEN 1 ELSE 2 END,
    csc.detected_at DESC;

-- ============================================================================
-- SECTION 3: ALERT ANALYTICS
-- ============================================================================

-- Alert summary dashboard
CREATE OR REPLACE VIEW v_alert_summary AS
WITH alert_stats AS (
    SELECT 
        ecosystem_code,
        severity,
        status,
        COUNT(*) as count
    FROM alerts
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY ecosystem_code, severity, status
),
resolution_times AS (
    SELECT 
        ecosystem_code,
        severity,
        AVG(EXTRACT(EPOCH FROM (acknowledged_at - created_at)) / 60) as avg_ack_time_min,
        AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 60) as avg_resolve_time_min
    FROM alerts
    WHERE resolved_at IS NOT NULL
      AND created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY ecosystem_code, severity
)
SELECT 
    e.ecosystem_code,
    e.ecosystem_name,
    
    -- Current open alerts
    COALESCE(SUM(CASE WHEN sts.status = 'open' THEN sts.count ELSE 0 END), 0) as open_alerts,
    COALESCE(SUM(CASE WHEN sts.status = 'open' AND sts.severity = 'CRITICAL' THEN sts.count ELSE 0 END), 0) as open_critical,
    COALESCE(SUM(CASE WHEN sts.status = 'open' AND sts.severity = 'HIGH' THEN sts.count ELSE 0 END), 0) as open_high,
    
    -- 30-day totals
    COALESCE(SUM(sts.count), 0) as alerts_30d,
    COALESCE(SUM(CASE WHEN sts.severity = 'CRITICAL' THEN sts.count ELSE 0 END), 0) as critical_30d,
    COALESCE(SUM(CASE WHEN sts.severity = 'HIGH' THEN sts.count ELSE 0 END), 0) as high_30d,
    
    -- Resolution times
    ROUND(AVG(rt.avg_ack_time_min)::NUMERIC, 1) as avg_ack_time_min,
    ROUND(AVG(rt.avg_resolve_time_min)::NUMERIC, 1) as avg_resolve_time_min,
    
    -- Auto-correction rate
    ROUND((SUM(CASE WHEN a.auto_correction_applied THEN 1 ELSE 0 END)::DECIMAL / 
           NULLIF(SUM(CASE WHEN a.auto_correctable THEN 1 ELSE 0 END), 0) * 100)::NUMERIC, 2) as auto_correction_rate_pct

FROM ecosystems e
LEFT JOIN alert_stats sts ON e.ecosystem_code = sts.ecosystem_code
LEFT JOIN resolution_times rt ON e.ecosystem_code = rt.ecosystem_code
LEFT JOIN alerts a ON e.ecosystem_code = a.ecosystem_code 
    AND a.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY e.ecosystem_code, e.ecosystem_name
ORDER BY open_alerts DESC, alerts_30d DESC;

-- Alert trends (daily)
CREATE OR REPLACE VIEW v_alert_trends AS
SELECT 
    stat_date,
    ecosystem_code,
    
    -- Counts by severity
    critical_count,
    high_count,
    medium_count,
    low_count,
    total_count,
    
    -- Resolution
    acknowledged_count,
    resolved_count,
    auto_resolved_count,
    
    -- Acknowledgement rate
    CASE WHEN total_count > 0 
        THEN ROUND((acknowledged_count::DECIMAL / total_count * 100)::NUMERIC, 2) 
        ELSE 100 
    END as ack_rate_pct,
    
    -- Resolution rate
    CASE WHEN total_count > 0 
        THEN ROUND((resolved_count::DECIMAL / total_count * 100)::NUMERIC, 2) 
        ELSE 100 
    END as resolve_rate_pct,
    
    -- Response times
    avg_time_to_acknowledge_minutes,
    avg_time_to_resolve_minutes,
    
    -- Auto-correction
    auto_corrected_count,
    
    -- Notifications
    notifications_sent,
    
    -- 7-day moving averages
    ROUND(AVG(total_count) OVER (
        PARTITION BY ecosystem_code 
        ORDER BY stat_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::NUMERIC, 1) as alerts_7day_ma

FROM alert_statistics_daily
WHERE stat_date >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY stat_date DESC, ecosystem_code;

-- Active alerts detail
CREATE OR REPLACE VIEW v_active_alerts_detail AS
SELECT 
    a.alert_id,
    a.severity::TEXT,
    a.ecosystem_code,
    e.ecosystem_name,
    a.function_code,
    f.function_name,
    a.vendor_code,
    a.alert_title,
    a.alert_summary,
    a.suggested_action,
    
    -- Metrics
    a.threshold_name,
    a.threshold_value,
    a.actual_value,
    a.metric_unit,
    
    -- Auto-correction
    a.auto_correctable,
    a.auto_correction_applied,
    
    -- Status
    a.status,
    a.escalation_level,
    
    -- Timing
    a.created_at,
    NOW() - a.created_at as age,
    EXTRACT(EPOCH FROM (NOW() - a.created_at)) / 60 as age_minutes,
    a.acknowledged_at,
    a.acknowledged_by,
    
    -- Duplicates
    a.duplicate_count,
    a.first_occurrence_at,
    a.last_occurrence_at,
    
    -- Related alerts
    COALESCE(related.count, 0) as related_alert_count

FROM alerts a
LEFT JOIN ecosystems e ON a.ecosystem_code = e.ecosystem_code
LEFT JOIN functions f ON a.function_code = f.function_code
LEFT JOIN LATERAL (
    SELECT COUNT(*) as count
    FROM alert_relations
    WHERE parent_alert_id = a.alert_id OR child_alert_id = a.alert_id
) related ON true
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

-- ============================================================================
-- SECTION 4: CRASH & RECOVERY REPORTS
-- ============================================================================

-- Recovery overview dashboard
CREATE OR REPLACE VIEW v_recovery_dashboard AS
WITH crash_stats AS (
    SELECT 
        ecosystem_code,
        COUNT(*) as total_crashes,
        COUNT(*) FILTER (WHERE severity = 'CRITICAL') as critical_crashes,
        COUNT(*) FILTER (WHERE recovery_successful) as successful_recoveries,
        COUNT(*) FILTER (WHERE manual_intervention_required) as manual_interventions,
        AVG(recovery_duration_seconds) as avg_recovery_seconds,
        AVG(detection_latency_seconds) as avg_detection_seconds
    FROM crash_events
    WHERE crash_timestamp >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY ecosystem_code
)
SELECT 
    e.ecosystem_code,
    e.ecosystem_name,
    
    -- Crash stats
    COALESCE(cs.total_crashes, 0) as crashes_30d,
    COALESCE(cs.critical_crashes, 0) as critical_crashes_30d,
    
    -- Recovery stats
    COALESCE(cs.successful_recoveries, 0) as successful_recoveries,
    COALESCE(cs.manual_interventions, 0) as manual_interventions,
    
    -- Recovery rate
    CASE WHEN cs.total_crashes > 0 
        THEN ROUND((cs.successful_recoveries::DECIMAL / cs.total_crashes * 100)::NUMERIC, 2) 
        ELSE 100 
    END as recovery_rate_pct,
    
    -- Timing
    ROUND(cs.avg_detection_seconds::NUMERIC, 0) as avg_detection_seconds,
    ROUND(cs.avg_recovery_seconds::NUMERIC, 0) as avg_recovery_seconds,
    
    -- Active crashes
    COALESCE(active.count, 0) as active_crashes,
    
    -- Recovery procedures
    COALESCE(procs.count, 0) as available_procedures,
    COALESCE(procs.active_count, 0) as active_procedures

FROM ecosystems e
LEFT JOIN crash_stats cs ON e.ecosystem_code = cs.ecosystem_code
LEFT JOIN LATERAL (
    SELECT COUNT(*) as count
    FROM crash_events
    WHERE ecosystem_code = e.ecosystem_code
      AND resolved_at IS NULL
) active ON true
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as count,
        COUNT(*) FILTER (WHERE is_active) as active_count
    FROM recovery_procedures
    WHERE ecosystem_code = e.ecosystem_code
) procs ON true
ORDER BY COALESCE(cs.total_crashes, 0) DESC;

-- Recent crash events
CREATE OR REPLACE VIEW v_recent_crashes AS
SELECT 
    ce.crash_id,
    ce.crash_uuid,
    ce.ecosystem_code,
    e.ecosystem_name,
    ce.function_code,
    f.function_name,
    ce.crash_type,
    ce.severity::TEXT,
    
    -- Error details
    ce.error_code,
    ce.error_message,
    
    -- Impact
    ce.affected_functions,
    ce.affected_users,
    ce.estimated_impact,
    
    -- Timeline
    ce.crash_timestamp,
    ce.detected_at,
    ce.detection_latency_seconds,
    ce.recovery_started_at,
    ce.recovery_completed_at,
    ce.recovery_duration_seconds,
    ce.resolved_at,
    
    -- Recovery
    ce.recovery_attempted,
    ce.recovery_successful,
    ce.recovery_method,
    ce.manual_intervention_required,
    ce.manual_intervention_by,
    
    -- Root cause
    ce.root_cause,
    ce.prevention_measures,
    
    -- Status
    CASE 
        WHEN ce.resolved_at IS NOT NULL THEN 'Resolved'
        WHEN ce.recovery_started_at IS NOT NULL THEN 'Recovering'
        ELSE 'Active'
    END as current_status

FROM crash_events ce
LEFT JOIN ecosystems e ON ce.ecosystem_code = e.ecosystem_code
LEFT JOIN functions f ON ce.function_code = f.function_code
ORDER BY ce.crash_timestamp DESC
LIMIT 200;

-- Recovery procedure effectiveness
CREATE OR REPLACE VIEW v_recovery_procedure_effectiveness AS
SELECT 
    rp.procedure_id,
    rp.procedure_code,
    rp.procedure_name,
    rp.ecosystem_code,
    e.ecosystem_name,
    rp.crash_types,
    
    -- Usage stats
    rp.times_executed,
    rp.success_count,
    rp.failure_count,
    
    -- Success rate
    CASE WHEN rp.times_executed > 0 
        THEN ROUND((rp.success_count::DECIMAL / rp.times_executed * 100)::NUMERIC, 2) 
        ELSE NULL 
    END as success_rate_pct,
    
    -- Timing
    rp.avg_duration_seconds,
    rp.timeout_minutes,
    
    -- Configuration
    rp.retry_count as max_retries,
    rp.requires_approval,
    rp.is_active,
    rp.is_default,
    
    -- Recent executions
    recent.last_execution,
    recent.last_status,
    recent.recent_success_rate

FROM recovery_procedures rp
LEFT JOIN ecosystems e ON rp.ecosystem_code = e.ecosystem_code
LEFT JOIN LATERAL (
    SELECT 
        MAX(started_at) as last_execution,
        (ARRAY_AGG(status ORDER BY started_at DESC))[1] as last_status,
        ROUND((COUNT(*) FILTER (WHERE success)::DECIMAL / NULLIF(COUNT(*), 0) * 100)::NUMERIC, 2) as recent_success_rate
    FROM recovery_executions
    WHERE procedure_id = rp.procedure_id
      AND started_at > NOW() - INTERVAL '90 days'
) recent ON true
ORDER BY rp.times_executed DESC NULLS LAST;

-- ============================================================================
-- SECTION 5: COMMENTS
-- ============================================================================

COMMENT ON VIEW v_campaign_dashboard IS 'Campaign performance dashboard with metrics';
COMMENT ON VIEW v_campaign_segment_analysis IS 'Campaign segment performance comparison';
COMMENT ON VIEW v_campaign_ab_results IS 'A/B test results with statistical significance';
COMMENT ON VIEW v_crm_sync_dashboard IS 'CRM synchronization status dashboard';
COMMENT ON VIEW v_crm_sync_history IS 'CRM sync job history with details';
COMMENT ON VIEW v_alert_summary IS 'Alert summary by ecosystem';
COMMENT ON VIEW v_alert_trends IS 'Daily alert trends with moving averages';
COMMENT ON VIEW v_active_alerts_detail IS 'Detailed view of all active alerts';
COMMENT ON VIEW v_recovery_dashboard IS 'Crash and recovery overview by ecosystem';
COMMENT ON VIEW v_recent_crashes IS 'Recent crash events with full details';
COMMENT ON VIEW v_recovery_procedure_effectiveness IS 'Recovery procedure success metrics';
