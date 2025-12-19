-- =====================================================
-- BROYHILLGOP SUPABASE DATABASE SCHEMA
-- File 4: Performance Views & Analytics
-- Real-Time Dashboards & Reporting
-- =====================================================

-- Materialized View: Channel Cost-Effectiveness
-- Shows which channels perform best by campaign type
CREATE MATERIALIZED VIEW IF NOT EXISTS channel_cost_effectiveness AS
SELECT 
    ct.name AS campaign_type_name,
    ch.name AS channel_name,
    COUNT(dc.communication_id) AS total_messages,
    COUNT(CASE WHEN dc.opened THEN 1 END) AS total_opens,
    COUNT(CASE WHEN dc.clicked THEN 1 END) AS total_clicks,
    COUNT(CASE WHEN dc.donated THEN 1 END) AS total_donations,
    ROUND(COUNT(CASE WHEN dc.opened THEN 1 END)::NUMERIC / NULLIF(COUNT(dc.communication_id), 0) * 100, 2) AS open_rate_pct,
    ROUND(COUNT(CASE WHEN dc.clicked THEN 1 END)::NUMERIC / NULLIF(COUNT(dc.communication_id), 0) * 100, 2) AS click_rate_pct,
    ROUND(COUNT(CASE WHEN dc.donated THEN 1 END)::NUMERIC / NULLIF(COUNT(dc.communication_id), 0) * 100, 2) AS conversion_rate_pct,
    COALESCE(SUM(dc.donation_amount), 0) AS total_revenue,
    COALESCE(SUM(dc.cost), 0) AS total_cost,
    ROUND(COALESCE(AVG(dc.donation_amount), 0), 2) AS avg_donation,
    ROUND((COALESCE(SUM(dc.donation_amount), 0) - COALESCE(SUM(dc.cost), 0)) / NULLIF(SUM(dc.cost), 0) * 100, 2) AS roi_pct
FROM donor_communications dc
JOIN campaign_events ce ON dc.campaign_event_id = ce.campaign_event_id
JOIN campaign_types ct ON ce.campaign_type_id = ct.campaign_type_id
JOIN campaign_channels ch ON dc.channel_id = ch.channel_id
WHERE ce.status = 'completed'
GROUP BY ct.name, ch.name;

CREATE UNIQUE INDEX idx_channel_effectiveness ON channel_cost_effectiveness(campaign_type_name, channel_name);

-- Refresh function
CREATE OR REPLACE FUNCTION refresh_channel_effectiveness()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY channel_cost_effectiveness;
END;
$$ LANGUAGE plpgsql;

-- Schedule nightly refresh (requires pg_cron extension)
SELECT cron.schedule('refresh-channel-effectiveness', '0 3 * * *', 'SELECT refresh_channel_effectiveness()');

-- =====================================================
-- View: Campaign Performance Dashboard
-- Real-time campaign metrics for candidate dashboards
-- =====================================================
CREATE OR REPLACE VIEW campaign_performance_dashboard AS
SELECT 
    ce.campaign_event_id,
    ce.event_name,
    c.first_name || ' ' || c.last_name AS candidate_name,
    ct.name AS campaign_type,
    ce.event_date,
    ce.status,
    ce.revenue_goal,
    ce.actual_revenue,
    ROUND((ce.actual_revenue / NULLIF(ce.revenue_goal, 0)) * 100, 2) AS goal_completion_pct,
    ce.total_invitations_sent,
    ce.total_rsvps,
    ce.total_attendees,
    ROUND((ce.total_rsvps::NUMERIC / NULLIF(ce.total_invitations_sent, 0)) * 100, 2) AS rsvp_rate_pct,
    ROUND((ce.total_attendees::NUMERIC / NULLIF(ce.total_rsvps, 0)) * 100, 2) AS attendance_rate_pct,
    COUNT(dc.communication_id) AS total_communications,
    SUM(dc.cost) AS total_cost,
    ROUND((ce.actual_revenue - COALESCE(SUM(dc.cost), 0)) / NULLIF(SUM(dc.cost), 0) * 100, 2) AS roi_pct
FROM campaign_events ce
JOIN candidates c ON ce.candidate_id = c.candidate_id
JOIN campaign_types ct ON ce.campaign_type_id = ct.campaign_type_id
LEFT JOIN donor_communications dc ON ce.campaign_event_id = dc.campaign_event_id
GROUP BY ce.campaign_event_id, c.first_name, c.last_name, ct.name, ce.event_name, ce.event_date, ce.status, ce.revenue_goal, ce.actual_revenue, ce.total_invitations_sent, ce.total_rsvps, ce.total_attendees;

-- =====================================================
-- View: Donor Engagement Summary
-- 360-degree view of each donor's interaction history
-- =====================================================
CREATE OR REPLACE VIEW donor_engagement_summary AS
SELECT 
    d.donor_id,
    d.first_name || ' ' || d.last_name AS donor_name,
    d.tier,
    d.lifetime_contribution,
    COUNT(dc.communication_id) AS total_communications_received,
    COUNT(CASE WHEN dc.opened THEN 1 END) AS total_opens,
    COUNT(CASE WHEN dc.clicked THEN 1 END) AS total_clicks,
    COUNT(CASE WHEN dc.donated THEN 1 END) AS total_donations,
    COALESCE(SUM(dc.donation_amount), 0) AS total_campaign_donations,
    ROUND(COUNT(CASE WHEN dc.opened THEN 1 END)::NUMERIC / NULLIF(COUNT(dc.communication_id), 0) * 100, 2) AS avg_open_rate_pct,
    ROUND(COUNT(CASE WHEN dc.donated THEN 1 END)::NUMERIC / NULLIF(COUNT(dc.communication_id), 0) * 100, 2) AS conversion_rate_pct,
    MAX(dc.sent_at) AS last_contact_date,
    EXTRACT(DAY FROM NOW() - MAX(dc.sent_at)) AS days_since_last_contact
FROM donors d
LEFT JOIN donor_communications dc ON d.donor_id = dc.donor_id
GROUP BY d.donor_id, d.first_name, d.last_name, d.tier, d.lifetime_contribution;

-- =====================================================
-- View: ML Experiment Dashboard
-- Real-time experiment performance for campaign managers
-- =====================================================
CREATE OR REPLACE VIEW ml_experiment_dashboard AS
SELECT 
    e.experiment_id,
    e.name AS experiment_name,
    e.status,
    e.strategy,
    EXTRACT(DAY FROM NOW() - e.start_date) AS days_running,
    bs.variant_id,
    bs.impressions,
    bs.conversions,
    bs.total_revenue,
    bs.traffic_allocation_pct,
    ROUND(bs.conversions::NUMERIC / NULLIF(bs.impressions, 0) * 100, 2) AS conversion_rate_pct,
    ROUND(bs.total_revenue / NULLIF(bs.conversions, 0), 2) AS avg_donation,
    ROUND(bs.total_revenue / NULLIF(bs.impressions, 0), 2) AS revenue_per_impression,
    bs.alpha,
    bs.beta,
    bs.last_updated
FROM ml_experiments e
JOIN ml_bandit_state bs ON e.experiment_id = bs.experiment_id
WHERE e.status = 'active'
ORDER BY e.experiment_id, bs.variant_id;

-- =====================================================
-- View: Sequence Performance by Campaign Type
-- Which sequences work best for each campaign type
-- =====================================================
CREATE OR REPLACE VIEW sequence_performance_by_type AS
SELECT 
    ct.name AS campaign_type,
    cs.sequence_order,
    cs.action_description,
    ch.name AS channel_name,
    cs.day_offset,
    COUNT(dc.communication_id) AS times_executed,
    COUNT(CASE WHEN dc.opened THEN 1 END) AS total_opens,
    COUNT(CASE WHEN dc.donated THEN 1 END) AS total_donations,
    ROUND(COUNT(CASE WHEN dc.opened THEN 1 END)::NUMERIC / NULLIF(COUNT(dc.communication_id), 0) * 100, 2) AS open_rate_pct,
    ROUND(COUNT(CASE WHEN dc.donated THEN 1 END)::NUMERIC / NULLIF(COUNT(dc.communication_id), 0) * 100, 2) AS conversion_rate_pct,
    COALESCE(SUM(dc.donation_amount), 0) AS total_revenue,
    COALESCE(AVG(dc.cost), 0) AS avg_cost_per_contact
FROM campaign_sequences cs
JOIN campaign_types ct ON cs.campaign_type_id = ct.campaign_type_id
JOIN campaign_channels ch ON cs.channel_id = ch.channel_id
LEFT JOIN donor_communications dc ON cs.sequence_id = dc.sequence_id
WHERE cs.active = TRUE
GROUP BY ct.name, cs.sequence_order, cs.action_description, ch.name, cs.day_offset
ORDER BY ct.name, cs.sequence_order;

-- =====================================================
-- View: Issue Heat Map Dashboard
-- Shows top candidates by issue intensity
-- =====================================================
CREATE OR REPLACE VIEW issue_heat_map_dashboard AS
SELECT 
    ic.name AS issue_name,
    c.first_name || ' ' || c.last_name AS candidate_name,
    c.office_type,
    c.district,
    ihm.intensity_score,
    ihm.news_prominence_30d,
    ihm.legislative_activity_count,
    ihm.committee_chair,
    ihm.last_updated
FROM issue_heat_map ihm
JOIN candidates c ON ihm.candidate_id = c.candidate_id
JOIN issue_categories ic ON ihm.issue_id = ic.issue_id
WHERE ihm.intensity_score >= 60
ORDER BY ic.name, ihm.intensity_score DESC;

-- =====================================================
-- Function: Get Optimal Sequence for Donor
-- Retrieves ML-recommended sequence for specific donor + campaign type
-- =====================================================
CREATE OR REPLACE FUNCTION get_optimal_sequence(
    p_donor_id INT,
    p_campaign_type_id INT
) RETURNS TABLE (
    channel_name VARCHAR,
    day_offset INT,
    action_description TEXT,
    estimated_cost NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ch.name,
        seq->>'day' AS day_offset_int,
        seq->>'description' AS action_desc,
        ch.avg_cost
    FROM donors d
    CROSS JOIN LATERAL (
        SELECT recommended_sequence
        FROM ml_channel_recommendations
        WHERE campaign_type_id = p_campaign_type_id
        AND donor_segment = d.tier
        LIMIT 1
    ) rec
    CROSS JOIN LATERAL jsonb_array_elements(rec.recommended_sequence) AS seq
    JOIN campaign_channels ch ON ch.name = seq->>'channel'
    WHERE d.donor_id = p_donor_id;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON MATERIALIZED VIEW channel_cost_effectiveness IS 'Real-time cost/benefit metrics by channel and campaign type';
COMMENT ON VIEW campaign_performance_dashboard IS 'Candidate dashboard showing all campaign metrics';
COMMENT ON VIEW donor_engagement_summary IS '360-degree donor interaction history';
COMMENT ON VIEW ml_experiment_dashboard IS 'Real-time A/B test and bandit experiment results';
COMMENT ON FUNCTION get_optimal_sequence IS 'Returns ML-optimized sequence for specific donor and campaign type';
