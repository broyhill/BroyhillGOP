-- ============================================================================
-- BRAIN CONTROL SYSTEM - COMPREHENSIVE REPORTING VIEWS
-- ============================================================================
-- File: 010e_brain_reports_donor_analytics.sql
-- Donor intelligence, fundraising analytics, candidate performance
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: DONOR INTELLIGENCE ANALYTICS
-- ============================================================================

-- Note: These views are designed to integrate with the PATRIOT Intelligence
-- and DONOR_ENRICH ecosystems. Actual donor data resides in those systems.

-- Donor grading distribution (connects to PATRIOT)
CREATE OR REPLACE VIEW v_donor_grade_distribution AS
WITH grade_tiers AS (
    SELECT 
        unnest(ARRAY['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'D-', 'E+', 'E', 'E-', 'F+', 'F', 'F-', 'U+', 'U', 'U-']) as grade,
        generate_series(1, 21) as sort_order
)
SELECT 
    gt.grade,
    gt.sort_order,
    -- Placeholder counts - would connect to PATRIOT data
    0 as donor_count,
    0.0 as pct_of_total,
    0.0 as total_donations,
    0.0 as avg_donation,
    0.0 as avg_lead_score
FROM grade_tiers gt
ORDER BY gt.sort_order;

-- Donor acquisition funnel
CREATE OR REPLACE VIEW v_donor_acquisition_funnel AS
SELECT 
    'Prospects Identified' as stage,
    1 as stage_order,
    0 as count,
    100.0 as conversion_rate_pct
UNION ALL
SELECT 'Contacted', 2, 0, 0.0
UNION ALL
SELECT 'Engaged', 3, 0, 0.0
UNION ALL
SELECT 'First Donation', 4, 0, 0.0
UNION ALL
SELECT 'Repeat Donor', 5, 0, 0.0
UNION ALL
SELECT 'Major Donor', 6, 0, 0.0
ORDER BY stage_order;

-- Donor lifetime value analysis
CREATE OR REPLACE VIEW v_donor_ltv_analysis AS
WITH ltv_buckets AS (
    SELECT 
        unnest(ARRAY['$0-$100', '$100-$500', '$500-$1000', '$1000-$5000', '$5000-$10000', '$10000+']) as ltv_bucket,
        generate_series(1, 6) as sort_order
)
SELECT 
    ltv.ltv_bucket,
    ltv.sort_order,
    0 as donor_count,
    0.0 as total_ltv,
    0.0 as avg_ltv,
    0.0 as pct_of_donors,
    0.0 as pct_of_revenue
FROM ltv_buckets ltv
ORDER BY ltv.sort_order;

-- ============================================================================
-- SECTION 2: FUNDRAISING PERFORMANCE
-- ============================================================================

-- Daily fundraising metrics
CREATE OR REPLACE VIEW v_daily_fundraising AS
SELECT 
    m.metric_date,
    
    -- Volume
    COALESCE(SUM(m.donations_count), 0) as donations_count,
    COALESCE(SUM(m.donations_amount), 0) as donations_amount,
    
    -- Averages
    CASE WHEN SUM(m.donations_count) > 0 
        THEN ROUND((SUM(m.donations_amount) / SUM(m.donations_count))::NUMERIC, 2)
        ELSE 0 
    END as avg_donation,
    
    -- Campaign metrics
    COUNT(DISTINCT m.campaign_id) as active_campaigns,
    
    -- Email metrics
    COALESCE(SUM(m.emails_sent), 0) as emails_sent,
    COALESCE(SUM(m.emails_opened), 0) as emails_opened,
    COALESCE(SUM(m.emails_clicked), 0) as emails_clicked,
    
    -- Conversion
    CASE WHEN SUM(m.emails_sent) > 0 
        THEN ROUND((SUM(m.donations_count)::DECIMAL / SUM(m.emails_sent) * 100)::NUMERIC, 4)
        ELSE 0 
    END as email_to_donation_rate_pct,
    
    -- Cost
    COALESCE(SUM(m.cost), 0) as total_cost,
    
    -- ROI
    CASE WHEN SUM(m.cost) > 0 
        THEN ROUND(((SUM(m.donations_amount) - SUM(m.cost)) / SUM(m.cost) * 100)::NUMERIC, 2)
        ELSE 0 
    END as daily_roi_pct,
    
    -- 7-day moving averages
    ROUND(AVG(SUM(m.donations_amount)) OVER (
        ORDER BY m.metric_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::NUMERIC, 2) as donations_7day_ma,
    
    ROUND(AVG(SUM(m.donations_count)) OVER (
        ORDER BY m.metric_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::NUMERIC, 0) as count_7day_ma

FROM campaign_metrics_daily m
WHERE m.metric_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY m.metric_date
ORDER BY m.metric_date DESC;

-- Monthly fundraising summary
CREATE OR REPLACE VIEW v_monthly_fundraising AS
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', m.metric_date) as month_start,
        EXTRACT(YEAR FROM m.metric_date) as fiscal_year,
        EXTRACT(MONTH FROM m.metric_date) as fiscal_month,
        SUM(m.donations_count) as donations_count,
        SUM(m.donations_amount) as donations_amount,
        SUM(m.cost) as total_cost,
        COUNT(DISTINCT m.campaign_id) as campaigns
    FROM campaign_metrics_daily m
    WHERE m.metric_date >= DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '1 year'
    GROUP BY DATE_TRUNC('month', m.metric_date), EXTRACT(YEAR FROM m.metric_date), EXTRACT(MONTH FROM m.metric_date)
)
SELECT 
    md.month_start,
    TO_CHAR(md.month_start, 'Mon YYYY') as month_name,
    md.fiscal_year,
    md.fiscal_month,
    
    -- Volume
    md.donations_count,
    md.donations_amount,
    
    -- Average
    CASE WHEN md.donations_count > 0 
        THEN ROUND((md.donations_amount / md.donations_count)::NUMERIC, 2)
        ELSE 0 
    END as avg_donation,
    
    -- Cost & ROI
    md.total_cost,
    CASE WHEN md.total_cost > 0 
        THEN ROUND(((md.donations_amount - md.total_cost) / md.total_cost * 100)::NUMERIC, 2)
        ELSE 0 
    END as roi_pct,
    
    -- Campaigns
    md.campaigns,
    
    -- Month-over-month change
    md.donations_amount - LAG(md.donations_amount) OVER (ORDER BY md.month_start) as mom_change,
    CASE WHEN LAG(md.donations_amount) OVER (ORDER BY md.month_start) > 0 
        THEN ROUND(((md.donations_amount - LAG(md.donations_amount) OVER (ORDER BY md.month_start)) / 
                   LAG(md.donations_amount) OVER (ORDER BY md.month_start) * 100)::NUMERIC, 2)
        ELSE 0 
    END as mom_change_pct,
    
    -- Year-over-year change
    md.donations_amount - LAG(md.donations_amount, 12) OVER (ORDER BY md.month_start) as yoy_change,
    CASE WHEN LAG(md.donations_amount, 12) OVER (ORDER BY md.month_start) > 0 
        THEN ROUND(((md.donations_amount - LAG(md.donations_amount, 12) OVER (ORDER BY md.month_start)) / 
                   LAG(md.donations_amount, 12) OVER (ORDER BY md.month_start) * 100)::NUMERIC, 2)
        ELSE 0 
    END as yoy_change_pct

FROM monthly_data md
ORDER BY md.month_start DESC;

-- Fundraising by channel
CREATE OR REPLACE VIEW v_fundraising_by_channel AS
SELECT 
    cc.channel_type,
    
    -- Volume (MTD)
    COALESCE(SUM(cc.sends), 0) as total_sends,
    COALESCE(SUM(cc.delivered), 0) as total_delivered,
    COALESCE(SUM(cc.opened), 0) as total_opened,
    COALESCE(SUM(cc.clicked), 0) as total_clicked,
    COALESCE(SUM(cc.converted), 0) as total_conversions,
    
    -- Rates
    CASE WHEN SUM(cc.delivered) > 0 
        THEN ROUND((SUM(cc.opened)::DECIMAL / SUM(cc.delivered) * 100)::NUMERIC, 2)
        ELSE 0 
    END as open_rate_pct,
    CASE WHEN SUM(cc.opened) > 0 
        THEN ROUND((SUM(cc.clicked)::DECIMAL / SUM(cc.opened) * 100)::NUMERIC, 2)
        ELSE 0 
    END as click_to_open_rate_pct,
    CASE WHEN SUM(cc.clicked) > 0 
        THEN ROUND((SUM(cc.converted)::DECIMAL / SUM(cc.clicked) * 100)::NUMERIC, 2)
        ELSE 0 
    END as click_to_convert_rate_pct,
    
    -- Cost
    COALESCE(SUM(cc.budget_spent), 0) as total_cost,
    CASE WHEN SUM(cc.sends) > 0 
        THEN ROUND((SUM(cc.budget_spent) / SUM(cc.sends))::NUMERIC, 4)
        ELSE 0 
    END as cost_per_send,
    CASE WHEN SUM(cc.converted) > 0 
        THEN ROUND((SUM(cc.budget_spent) / SUM(cc.converted))::NUMERIC, 2)
        ELSE 0 
    END as cost_per_conversion,
    
    -- Campaign count
    COUNT(DISTINCT cc.campaign_id) as campaigns

FROM campaign_channels cc
JOIN campaigns c ON cc.campaign_id = c.campaign_id
WHERE c.actual_start_date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY cc.channel_type
ORDER BY total_conversions DESC;

-- ============================================================================
-- SECTION 3: CANDIDATE PERFORMANCE
-- ============================================================================

-- Candidate fundraising leaderboard
CREATE OR REPLACE VIEW v_candidate_leaderboard AS
SELECT 
    c.candidate_name,
    c.candidate_id,
    
    -- Campaign metrics
    COUNT(DISTINCT c.campaign_id) as campaigns,
    COUNT(DISTINCT c.campaign_id) FILTER (WHERE c.status = 'active') as active_campaigns,
    
    -- Fundraising (MTD)
    COALESCE(SUM(m.donations_count), 0) as mtd_donations_count,
    COALESCE(SUM(m.donations_amount), 0) as mtd_donations_amount,
    
    -- Average donation
    CASE WHEN SUM(m.donations_count) > 0 
        THEN ROUND((SUM(m.donations_amount) / SUM(m.donations_count))::NUMERIC, 2)
        ELSE 0 
    END as avg_donation,
    
    -- Email performance
    COALESCE(SUM(m.emails_sent), 0) as mtd_emails_sent,
    CASE WHEN SUM(m.emails_delivered) > 0 
        THEN ROUND((SUM(m.emails_opened)::DECIMAL / SUM(m.emails_delivered) * 100)::NUMERIC, 2)
        ELSE 0 
    END as open_rate_pct,
    CASE WHEN SUM(m.emails_delivered) > 0 
        THEN ROUND((SUM(m.emails_clicked)::DECIMAL / SUM(m.emails_delivered) * 100)::NUMERIC, 2)
        ELSE 0 
    END as click_rate_pct,
    
    -- Cost efficiency
    COALESCE(SUM(m.cost), 0) as mtd_cost,
    CASE WHEN SUM(m.cost) > 0 
        THEN ROUND(((SUM(m.donations_amount) - SUM(m.cost)) / SUM(m.cost) * 100)::NUMERIC, 2)
        ELSE 0 
    END as roi_pct,
    
    -- Ranking
    RANK() OVER (ORDER BY SUM(m.donations_amount) DESC) as amount_rank,
    RANK() OVER (ORDER BY SUM(m.donations_count) DESC) as count_rank

FROM campaigns c
LEFT JOIN campaign_metrics_daily m ON c.campaign_id = m.campaign_id
    AND m.metric_date >= DATE_TRUNC('month', CURRENT_DATE)
WHERE c.candidate_name IS NOT NULL
GROUP BY c.candidate_name, c.candidate_id
ORDER BY mtd_donations_amount DESC;

-- Candidate performance trends
CREATE OR REPLACE VIEW v_candidate_trends AS
SELECT 
    c.candidate_name,
    c.candidate_id,
    DATE_TRUNC('week', m.metric_date) as week_start,
    
    -- Weekly metrics
    COUNT(DISTINCT m.campaign_id) as campaigns,
    SUM(m.donations_count) as donations_count,
    SUM(m.donations_amount) as donations_amount,
    
    -- Week-over-week
    SUM(m.donations_amount) - LAG(SUM(m.donations_amount)) OVER (
        PARTITION BY c.candidate_name ORDER BY DATE_TRUNC('week', m.metric_date)
    ) as wow_change,
    
    -- 4-week moving average
    ROUND(AVG(SUM(m.donations_amount)) OVER (
        PARTITION BY c.candidate_name 
        ORDER BY DATE_TRUNC('week', m.metric_date) 
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    )::NUMERIC, 2) as amount_4week_ma

FROM campaigns c
JOIN campaign_metrics_daily m ON c.campaign_id = m.campaign_id
WHERE c.candidate_name IS NOT NULL
  AND m.metric_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.candidate_name, c.candidate_id, DATE_TRUNC('week', m.metric_date)
ORDER BY c.candidate_name, week_start DESC;

-- ============================================================================
-- SECTION 4: AI-POWERED INSIGHTS TRACKING
-- ============================================================================

-- AI function performance for donor operations
CREATE OR REPLACE VIEW v_ai_donor_operations AS
SELECT 
    f.function_code,
    f.function_name,
    f.ai_provider,
    f.ai_model,
    
    -- Usage (MTD)
    COALESCE(SUM(aud.request_count), 0) as mtd_requests,
    COALESCE(SUM(aud.total_tokens), 0) as mtd_tokens,
    COALESCE(SUM(aud.total_cost), 0) as mtd_cost,
    
    -- Quality
    ROUND(AVG(aud.avg_quality_score)::NUMERIC, 2) as avg_quality_score,
    
    -- Performance
    ROUND(AVG(aud.avg_latency_ms)::NUMERIC, 0) as avg_latency_ms,
    
    -- Effectiveness for donor functions
    CASE 
        WHEN f.function_code = 'F004' THEN 'Donor Grading'
        WHEN f.function_code = 'F005' THEN 'Lead Scoring'
        WHEN f.function_code = 'F006' THEN 'Ideology Analysis'
        WHEN f.function_code = 'F012' THEN 'Campaign Generation'
        WHEN f.function_code = 'F013' THEN 'Email Personalization'
        WHEN f.function_code = 'F015' THEN 'Donor-Candidate Matching'
        ELSE 'Other'
    END as function_category

FROM functions f
LEFT JOIN ai_usage_daily aud ON f.function_code = aud.function_code
    AND aud.usage_date >= DATE_TRUNC('month', CURRENT_DATE)
WHERE f.is_ai_powered
  AND f.ecosystem_code IN ('PATRIOT', 'LIBERTY', 'EAGLE', 'SUMMIT', 'DONOR_ENRICH')
GROUP BY f.function_code, f.function_name, f.ai_provider, f.ai_model
ORDER BY mtd_cost DESC;

-- Donor matching effectiveness
CREATE OR REPLACE VIEW v_donor_matching_effectiveness AS
SELECT 
    f.function_code,
    f.function_name,
    
    -- Volume
    COALESCE(SUM(fm.total_calls), 0) as matches_generated,
    COALESCE(SUM(fm.total_records), 0) as donors_matched,
    
    -- Quality
    f.quality_floor,
    ROUND(AVG(qm.overall_quality)::NUMERIC, 2) as avg_quality_score,
    AVG(qm.overall_quality) >= f.quality_floor as meets_quality_floor,
    
    -- Cost
    COALESCE(SUM(fm.total_cost), 0) as total_cost,
    CASE WHEN SUM(fm.total_records) > 0 
        THEN ROUND((SUM(fm.total_cost) / SUM(fm.total_records))::NUMERIC, 4)
        ELSE 0 
    END as cost_per_match

FROM functions f
LEFT JOIN function_metrics fm ON f.function_code = fm.function_code
    AND fm.period_start >= DATE_TRUNC('month', CURRENT_DATE)
LEFT JOIN quality_measurements qm ON f.function_code = qm.function_code
    AND qm.measurement_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
WHERE f.function_code IN ('F002', 'F015', 'F016') -- Matching functions
GROUP BY f.function_code, f.function_name, f.quality_floor;

-- ============================================================================
-- SECTION 5: CAMPAIGN EFFECTIVENESS BY FACTION
-- ============================================================================

-- Note: Faction-specific templates (MAGA, EVAN, VETS) from Creative Media Machine

-- Faction template performance (placeholder for actual faction data)
CREATE OR REPLACE VIEW v_faction_template_performance AS
SELECT 
    'MAGA' as faction,
    'America First' as faction_description,
    0 as templates_used,
    0 as campaigns,
    0.0 as avg_open_rate_pct,
    0.0 as avg_click_rate_pct,
    0.0 as avg_conversion_rate_pct,
    0.0 as total_donations
UNION ALL
SELECT 'EVAN', 'Evangelical Conservative', 0, 0, 0.0, 0.0, 0.0, 0.0
UNION ALL
SELECT 'VETS', 'Veterans & Military', 0, 0, 0.0, 0.0, 0.0, 0.0
UNION ALL
SELECT 'GENERIC', 'General Republican', 0, 0, 0.0, 0.0, 0.0, 0.0
ORDER BY faction;

-- ============================================================================
-- SECTION 6: VOLUNTEER IMPACT ANALYTICS
-- ============================================================================

-- Volunteer contribution to fundraising
CREATE OR REPLACE VIEW v_volunteer_fundraising_impact AS
WITH volunteer_metrics AS (
    SELECT 
        DATE_TRUNC('month', NOW()) as month_start,
        0 as active_volunteers,
        0 as volunteer_hours,
        0 as calls_made,
        0 as emails_assisted,
        0 as events_supported
)
SELECT 
    vm.month_start,
    vm.active_volunteers,
    vm.volunteer_hours,
    vm.calls_made,
    vm.emails_assisted,
    vm.events_supported,
    
    -- Fundraising attribution (placeholder)
    0.0 as donations_attributed,
    0.0 as volunteer_roi
FROM volunteer_metrics vm;

-- ============================================================================
-- SECTION 7: DATA ENRICHMENT ANALYTICS
-- ============================================================================

-- Data enrichment effectiveness
CREATE OR REPLACE VIEW v_data_enrichment_effectiveness AS
SELECT 
    v.vendor_code,
    v.vendor_name,
    
    -- Volume (MTD)
    COALESCE(vud.request_count, 0) as mtd_requests,
    COALESCE(vud.total_cost, 0) as mtd_cost,
    
    -- Quota
    v.monthly_quota,
    COALESCE(vud.quota_used, 0) as quota_used,
    ROUND((COALESCE(vud.quota_used, 0) / NULLIF(v.monthly_quota, 0) * 100)::NUMERIC, 2) as quota_used_pct,
    
    -- Performance
    vud.avg_latency_ms,
    vud.availability_pct,
    
    -- Cost efficiency
    CASE WHEN vud.request_count > 0 
        THEN ROUND((vud.total_cost / vud.request_count)::NUMERIC, 4)
        ELSE v.cost_per_unit 
    END as actual_cost_per_record,
    v.cost_per_unit as expected_cost_per_record

FROM vendors v
LEFT JOIN vendor_usage_daily vud ON v.vendor_code = vud.vendor_code
    AND vud.usage_date = CURRENT_DATE
WHERE v.vendor_type = 'data_enrichment'
ORDER BY mtd_cost DESC;

-- ============================================================================
-- SECTION 8: SUMMARY VIEWS FOR PLATFORM TOTALS
-- ============================================================================

-- Platform totals view (key metrics from context)
CREATE OR REPLACE VIEW v_platform_totals AS
SELECT 
    -- Donor metrics
    243575 as total_donors,
    72 as total_candidates,
    59110 as total_volunteers,
    
    -- Financial metrics
    593000.00 as current_arr,
    7700000.00 as revenue_potential,
    
    -- Platform ROI
    ROUND(((7700000.00 - 109800.00) / 109800.00 * 100)::NUMERIC, 0) as projected_roi_pct,
    
    -- Ecosystem counts
    16 as total_ecosystems,
    17 as total_vendors,
    35 as total_functions,
    
    -- Monthly costs
    39500.00 as monthly_ecosystem_cost,
    24100.00 as monthly_vendor_cost,
    63600.00 as total_monthly_cost,
    
    -- Timestamp
    NOW() as as_of;

-- ============================================================================
-- SECTION 9: COMMENTS
-- ============================================================================

COMMENT ON VIEW v_donor_grade_distribution IS 'Distribution of donors by 21-tier grading system';
COMMENT ON VIEW v_donor_acquisition_funnel IS 'Donor acquisition funnel stages';
COMMENT ON VIEW v_donor_ltv_analysis IS 'Donor lifetime value bucket analysis';
COMMENT ON VIEW v_daily_fundraising IS 'Daily fundraising metrics with trends';
COMMENT ON VIEW v_monthly_fundraising IS 'Monthly fundraising summary with MoM/YoY';
COMMENT ON VIEW v_fundraising_by_channel IS 'Fundraising performance by channel type';
COMMENT ON VIEW v_candidate_leaderboard IS 'Candidate fundraising rankings';
COMMENT ON VIEW v_candidate_trends IS 'Weekly candidate performance trends';
COMMENT ON VIEW v_ai_donor_operations IS 'AI function performance for donor operations';
COMMENT ON VIEW v_data_enrichment_effectiveness IS 'Data enrichment vendor effectiveness';
COMMENT ON VIEW v_platform_totals IS 'Key platform total metrics';
