-- ============================================================================
-- CAMPAIGN COMMUNICATIONS LIBRARY SCHEMA
-- Complete Repository with AI Search & Performance Tracking
-- November 30, 2025
-- ============================================================================

-- ============================================================================
-- TABLE 1: LIBRARY CONTENT MASTER (All Communications)
-- ============================================================================

CREATE TABLE IF NOT EXISTS library_content (
    id BIGSERIAL PRIMARY KEY,
    library_id BIGINT NOT NULL,
    
    -- Content Identification
    content_uuid UUID UNIQUE DEFAULT gen_random_uuid(),
    content_code VARCHAR(50) UNIQUE,
    
    -- Location
    folder_path VARCHAR(500) NOT NULL,
    folder_category VARCHAR(50) NOT NULL,
    folder_subcategory VARCHAR(50),
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(1000) NOT NULL,
    
    -- Content Type
    channel VARCHAR(20) NOT NULL,
    content_type VARCHAR(50) NOT NULL,
    sub_type VARCHAR(50),
    
    -- File Details
    file_format VARCHAR(20) NOT NULL,
    file_size_bytes BIGINT,
    file_hash VARCHAR(64),
    
    -- Classification
    purpose VARCHAR(50),
    sub_purpose VARCHAR(50),
    
    -- Targeting
    issue_codes VARCHAR(10)[] DEFAULT '{}',
    faction_codes VARCHAR(4)[] DEFAULT '{}',
    donor_grade_targets VARCHAR(5)[] DEFAULT '{}',
    occasion_codes VARCHAR(50)[] DEFAULT '{}',
    event_types VARCHAR(50)[] DEFAULT '{}',
    
    -- Content Metadata
    title VARCHAR(255),
    description TEXT,
    subject_line VARCHAR(500),
    preview_text VARCHAR(300),
    
    -- For Video
    duration_seconds INT,
    video_length_category VARCHAR(20),
    
    -- Flags
    is_evergreen BOOLEAN DEFAULT FALSE,
    is_news_driven BOOLEAN DEFAULT FALSE,
    is_template BOOLEAN DEFAULT FALSE,
    is_drip_part BOOLEAN DEFAULT FALSE,
    
    -- AI
    ai_indexed BOOLEAN DEFAULT FALSE,
    ai_description TEXT,
    ai_keywords TEXT[],
    ai_sentiment VARCHAR(20),
    
    -- Performance Score (0-1000)
    performance_score INT DEFAULT 0,
    performance_rank_overall INT,
    performance_rank_category INT,
    
    -- Version Control
    version INT DEFAULT 1,
    previous_version_id BIGINT,
    is_current BOOLEAN DEFAULT TRUE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE',
    is_approved BOOLEAN DEFAULT TRUE,
    approved_by VARCHAR(100),
    approved_at TIMESTAMP,
    
    -- Audit
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_channel CHECK (channel IN ('TEXT', 'EMAIL', 'PRINT', 'CALL', 'SOCIAL', 'VIDEO'))
);

CREATE INDEX idx_content_library ON library_content(library_id);
CREATE INDEX idx_content_channel ON library_content(channel);
CREATE INDEX idx_content_purpose ON library_content(purpose);
CREATE INDEX idx_content_issues ON library_content USING GIN(issue_codes);
CREATE INDEX idx_content_factions ON library_content USING GIN(faction_codes);
CREATE INDEX idx_content_grades ON library_content USING GIN(donor_grade_targets);
CREATE INDEX idx_content_occasions ON library_content USING GIN(occasion_codes);
CREATE INDEX idx_content_score ON library_content(performance_score DESC);
CREATE INDEX idx_content_status ON library_content(status);

-- ============================================================================
-- TABLE 2: CONTENT PERFORMANCE TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS content_performance (
    id BIGSERIAL PRIMARY KEY,
    content_id BIGINT NOT NULL REFERENCES library_content(id) ON DELETE CASCADE,
    
    -- Usage Statistics
    times_used INT DEFAULT 0,
    first_used TIMESTAMP,
    last_used TIMESTAMP,
    total_recipients INT DEFAULT 0,
    
    -- Engagement Metrics (Channel Specific)
    -- Email
    email_sends INT DEFAULT 0,
    email_opens INT DEFAULT 0,
    email_clicks INT DEFAULT 0,
    email_unsubscribes INT DEFAULT 0,
    email_bounces INT DEFAULT 0,
    email_open_rate DECIMAL(7,6),
    email_click_rate DECIMAL(7,6),
    
    -- SMS
    sms_sends INT DEFAULT 0,
    sms_delivered INT DEFAULT 0,
    sms_replies INT DEFAULT 0,
    sms_opt_outs INT DEFAULT 0,
    sms_reply_rate DECIMAL(7,6),
    
    -- Print
    print_mailed INT DEFAULT 0,
    print_returned INT DEFAULT 0,
    print_responses INT DEFAULT 0,
    print_response_rate DECIMAL(7,6),
    
    -- Call
    call_attempts INT DEFAULT 0,
    call_connects INT DEFAULT 0,
    call_pledges INT DEFAULT 0,
    call_connect_rate DECIMAL(7,6),
    call_pledge_rate DECIMAL(7,6),
    
    -- Social
    social_impressions INT DEFAULT 0,
    social_reach INT DEFAULT 0,
    social_engagements INT DEFAULT 0,
    social_link_clicks INT DEFAULT 0,
    social_shares INT DEFAULT 0,
    social_engagement_rate DECIMAL(7,6),
    
    -- Video
    video_views INT DEFAULT 0,
    video_completions INT DEFAULT 0,
    video_completion_rate DECIMAL(7,6),
    
    -- Financial Metrics
    total_revenue DECIMAL(12,2) DEFAULT 0,
    total_cost DECIMAL(12,2) DEFAULT 0,
    roi DECIMAL(10,4),
    cost_per_conversion DECIMAL(10,4),
    average_gift DECIMAL(10,2),
    total_conversions INT DEFAULT 0,
    
    -- Calculated Scores
    response_rate_score INT DEFAULT 0,
    conversion_rate_score INT DEFAULT 0,
    roi_score INT DEFAULT 0,
    reuse_value_score INT DEFAULT 0,
    freshness_score INT DEFAULT 0,
    consistency_score INT DEFAULT 0,
    total_performance_score INT DEFAULT 0,
    
    -- Period Performance (JSONB for flexibility)
    performance_today JSONB DEFAULT '{}'::jsonb,
    performance_this_week JSONB DEFAULT '{}'::jsonb,
    performance_this_month JSONB DEFAULT '{}'::jsonb,
    performance_this_quarter JSONB DEFAULT '{}'::jsonb,
    performance_ytd JSONB DEFAULT '{}'::jsonb,
    performance_all_time JSONB DEFAULT '{}'::jsonb,
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_performance_content ON content_performance(content_id);
CREATE INDEX idx_performance_score ON content_performance(total_performance_score DESC);
CREATE INDEX idx_performance_roi ON content_performance(roi DESC);
CREATE INDEX idx_performance_revenue ON content_performance(total_revenue DESC);

-- ============================================================================
-- TABLE 3: CONTENT CONTEXT EFFECTIVENESS
-- ============================================================================

CREATE TABLE IF NOT EXISTS content_context_effectiveness (
    id BIGSERIAL PRIMARY KEY,
    content_id BIGINT NOT NULL REFERENCES library_content(id) ON DELETE CASCADE,
    
    context_type VARCHAR(50) NOT NULL,
    context_value VARCHAR(100) NOT NULL,
    
    -- Performance in this context
    sample_size INT DEFAULT 0,
    conversion_rate DECIMAL(7,6),
    average_gift DECIMAL(10,2),
    roi DECIMAL(10,4),
    
    -- Ranking within context
    rank_in_context INT,
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_content_context UNIQUE (content_id, context_type, context_value)
);

CREATE INDEX idx_context_content ON content_context_effectiveness(content_id);
CREATE INDEX idx_context_type ON content_context_effectiveness(context_type, context_value);
CREATE INDEX idx_context_performance ON content_context_effectiveness(conversion_rate DESC);

-- ============================================================================
-- TABLE 4: CONTENT USAGE LOG
-- ============================================================================

CREATE TABLE IF NOT EXISTS content_usage_log (
    id BIGSERIAL PRIMARY KEY,
    content_id BIGINT NOT NULL REFERENCES library_content(id),
    
    -- Usage Details
    campaign_id BIGINT,
    campaign_name VARCHAR(200),
    used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    used_by VARCHAR(100),
    
    -- Target Context
    target_segment VARCHAR(100),
    target_grades VARCHAR(5)[],
    target_factions VARCHAR(4)[],
    target_issue VARCHAR(10),
    
    -- Results
    recipients INT DEFAULT 0,
    revenue DECIMAL(12,2) DEFAULT 0,
    cost DECIMAL(12,2) DEFAULT 0,
    conversions INT DEFAULT 0,
    
    -- Metrics (channel specific)
    metrics JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_usage_content ON content_usage_log(content_id);
CREATE INDEX idx_usage_date ON content_usage_log(used_at DESC);
CREATE INDEX idx_usage_campaign ON content_usage_log(campaign_id);

-- ============================================================================
-- TABLE 5: DRIP CAMPAIGN TEMPLATES
-- ============================================================================

CREATE TABLE IF NOT EXISTS drip_campaigns (
    id BIGSERIAL PRIMARY KEY,
    library_id BIGINT NOT NULL,
    
    -- Campaign Identification
    campaign_uuid UUID UNIQUE DEFAULT gen_random_uuid(),
    campaign_code VARCHAR(50) UNIQUE,
    campaign_name VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Classification
    audience_type VARCHAR(50) NOT NULL,
    purpose VARCHAR(50) NOT NULL,
    channel_strategy VARCHAR(20) NOT NULL,
    
    -- Configuration
    total_touches INT NOT NULL,
    duration_days INT NOT NULL,
    sequence_config JSONB NOT NULL,
    
    -- Performance
    times_deployed INT DEFAULT 0,
    total_recipients INT DEFAULT 0,
    overall_conversion_rate DECIMAL(7,6),
    overall_roi DECIMAL(10,4),
    performance_score INT DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_drip_library ON drip_campaigns(library_id);
CREATE INDEX idx_drip_audience ON drip_campaigns(audience_type);
CREATE INDEX idx_drip_purpose ON drip_campaigns(purpose);

-- ============================================================================
-- TABLE 6: DRIP CAMPAIGN MESSAGES
-- ============================================================================

CREATE TABLE IF NOT EXISTS drip_campaign_messages (
    id BIGSERIAL PRIMARY KEY,
    drip_campaign_id BIGINT NOT NULL REFERENCES drip_campaigns(id) ON DELETE CASCADE,
    content_id BIGINT REFERENCES library_content(id),
    
    -- Sequence
    sequence_number INT NOT NULL,
    trigger_type VARCHAR(50) NOT NULL,
    delay_days INT DEFAULT 0,
    delay_hours INT DEFAULT 0,
    
    -- Channel
    channel VARCHAR(20) NOT NULL,
    
    -- Conditions
    conditions JSONB DEFAULT '{}'::jsonb,
    
    -- Performance in sequence
    conversion_rate DECIMAL(7,6),
    drop_off_rate DECIMAL(7,6),
    
    CONSTRAINT unique_drip_sequence UNIQUE (drip_campaign_id, sequence_number)
);

CREATE INDEX idx_drip_msg_campaign ON drip_campaign_messages(drip_campaign_id);
CREATE INDEX idx_drip_msg_content ON drip_campaign_messages(content_id);

-- ============================================================================
-- TABLE 7: UPLOAD QUEUE
-- ============================================================================

CREATE TABLE IF NOT EXISTS upload_queue (
    id BIGSERIAL PRIMARY KEY,
    library_id BIGINT NOT NULL,
    
    -- Upload Identification
    upload_uuid UUID UNIQUE DEFAULT gen_random_uuid(),
    batch_id UUID,
    
    -- File Details
    original_filename VARCHAR(255) NOT NULL,
    file_size_bytes BIGINT,
    file_type VARCHAR(50),
    file_hash VARCHAR(64),
    temp_path VARCHAR(1000),
    
    -- AI Classification
    ai_classification JSONB,
    ai_confidence DECIMAL(5,4),
    ai_suggested_folder VARCHAR(500),
    ai_suggested_category VARCHAR(50),
    
    -- User Override
    user_classification JSONB,
    user_folder VARCHAR(500),
    user_category VARCHAR(50),
    user_notes TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDING',
    error_message TEXT,
    
    -- Processing
    processing_started_at TIMESTAMP,
    processing_completed_at TIMESTAMP,
    final_file_path VARCHAR(1000),
    final_content_id BIGINT,
    
    -- Archive
    archive_path VARCHAR(1000),
    
    -- Audit
    uploaded_by VARCHAR(100),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_by VARCHAR(100)
);

CREATE INDEX idx_upload_library ON upload_queue(library_id);
CREATE INDEX idx_upload_status ON upload_queue(status);
CREATE INDEX idx_upload_date ON upload_queue(uploaded_at DESC);
CREATE INDEX idx_upload_batch ON upload_queue(batch_id);

-- ============================================================================
-- TABLE 8: ARCHIVE RECORDS
-- ============================================================================

CREATE TABLE IF NOT EXISTS archive_records (
    id BIGSERIAL PRIMARY KEY,
    
    -- Original Reference
    original_content_id BIGINT,
    original_file_path VARCHAR(1000) NOT NULL,
    original_folder_category VARCHAR(50),
    
    -- Archive Location
    archive_path VARCHAR(1000) NOT NULL,
    archive_metadata_path VARCHAR(1000),
    
    -- Archive Type
    archive_type VARCHAR(20) NOT NULL,
    archive_reason TEXT,
    
    -- Action Details
    action_performed_by VARCHAR(100),
    action_performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action_ip_address VARCHAR(50),
    
    -- Retention
    retention_policy VARCHAR(50) DEFAULT '90_DAYS',
    expires_at TIMESTAMP,
    is_restored BOOLEAN DEFAULT FALSE,
    restored_at TIMESTAMP,
    restored_by VARCHAR(100),
    restored_to_path VARCHAR(1000),
    
    -- Original Metadata
    original_metadata JSONB
);

CREATE INDEX idx_archive_original ON archive_records(original_content_id);
CREATE INDEX idx_archive_type ON archive_records(archive_type);
CREATE INDEX idx_archive_expires ON archive_records(expires_at);
CREATE INDEX idx_archive_restored ON archive_records(is_restored);

-- ============================================================================
-- TABLE 9: NOTIFICATIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS library_notifications (
    id BIGSERIAL PRIMARY KEY,
    library_id BIGINT NOT NULL,
    
    -- Notification Details
    notification_type VARCHAR(50) NOT NULL,
    notification_priority VARCHAR(20) DEFAULT 'NORMAL',
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    
    -- Related Entity
    related_entity_type VARCHAR(50),
    related_entity_id BIGINT,
    
    -- Delivery Status
    email_sent BOOLEAN DEFAULT FALSE,
    email_sent_at TIMESTAMP,
    sms_sent BOOLEAN DEFAULT FALSE,
    sms_sent_at TIMESTAMP,
    dashboard_shown BOOLEAN DEFAULT FALSE,
    
    -- Acknowledgement
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMP,
    acknowledged_by VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notification_library ON library_notifications(library_id);
CREATE INDEX idx_notification_type ON library_notifications(notification_type);
CREATE INDEX idx_notification_ack ON library_notifications(acknowledged);
CREATE INDEX idx_notification_date ON library_notifications(created_at DESC);

-- ============================================================================
-- TABLE 10: PERFORMANCE REPORTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS library_performance_reports (
    id BIGSERIAL PRIMARY KEY,
    library_id BIGINT NOT NULL,
    
    -- Report Period
    report_period VARCHAR(20) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Summary Metrics
    total_content_items INT,
    total_uses INT,
    total_recipients INT,
    total_revenue DECIMAL(12,2),
    total_cost DECIMAL(12,2),
    overall_roi DECIMAL(10,4),
    
    -- Channel Breakdown
    channel_performance JSONB,
    
    -- Top Performers
    top_performers JSONB,
    bottom_performers JSONB,
    
    -- Trending
    trending_up JSONB,
    trending_down JSONB,
    
    -- Recommendations
    ai_recommendations JSONB,
    
    -- Report Document
    report_path VARCHAR(1000),
    
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_report_library ON library_performance_reports(library_id);
CREATE INDEX idx_report_period ON library_performance_reports(report_period);
CREATE INDEX idx_report_date ON library_performance_reports(period_end DESC);

-- ============================================================================
-- TABLE 11: SOCIAL MEDIA LIBRARY
-- ============================================================================

CREATE TABLE IF NOT EXISTS social_media_content (
    id BIGSERIAL PRIMARY KEY,
    library_id BIGINT NOT NULL,
    content_id BIGINT REFERENCES library_content(id),
    
    -- Platform
    platform VARCHAR(20) NOT NULL,
    post_type VARCHAR(50) NOT NULL,
    
    -- Content
    post_text TEXT,
    post_media_paths TEXT[],
    hashtags TEXT[],
    mentions TEXT[],
    link_url VARCHAR(2000),
    
    -- Classification
    topic VARCHAR(100),
    subject VARCHAR(100),
    purpose VARCHAR(50),
    issue_code VARCHAR(10),
    
    -- AI Generated
    is_ai_generated BOOLEAN DEFAULT FALSE,
    ai_prompt_used TEXT,
    
    -- Performance
    impressions INT DEFAULT 0,
    reach INT DEFAULT 0,
    engagements INT DEFAULT 0,
    likes INT DEFAULT 0,
    comments INT DEFAULT 0,
    shares INT DEFAULT 0,
    link_clicks INT DEFAULT 0,
    engagement_rate DECIMAL(7,6),
    performance_score INT DEFAULT 0,
    cost_benefit_rank INT,
    
    -- Ad Performance (if promoted)
    is_promoted BOOLEAN DEFAULT FALSE,
    ad_spend DECIMAL(10,2),
    ad_impressions INT,
    ad_clicks INT,
    ad_conversions INT,
    ad_cpc DECIMAL(10,4),
    ad_cpm DECIMAL(10,4),
    ad_roas DECIMAL(10,4),
    
    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT',
    published_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_social_library ON social_media_content(library_id);
CREATE INDEX idx_social_platform ON social_media_content(platform);
CREATE INDEX idx_social_topic ON social_media_content(topic);
CREATE INDEX idx_social_issue ON social_media_content(issue_code);
CREATE INDEX idx_social_score ON social_media_content(performance_score DESC);
CREATE INDEX idx_social_ai ON social_media_content(is_ai_generated);

-- ============================================================================
-- TABLE 12: VIDEO LIBRARY
-- ============================================================================

CREATE TABLE IF NOT EXISTS video_library (
    id BIGSERIAL PRIMARY KEY,
    library_id BIGINT NOT NULL,
    content_id BIGINT REFERENCES library_content(id),
    
    -- Video Details
    video_path VARCHAR(1000) NOT NULL,
    thumbnail_path VARCHAR(1000),
    transcript_path VARCHAR(1000),
    
    -- Length Category
    duration_seconds INT NOT NULL,
    length_category VARCHAR(20) NOT NULL,
    
    -- Classification
    purpose VARCHAR(50) NOT NULL,
    subject VARCHAR(100),
    issue_code VARCHAR(10),
    topic VARCHAR(100),
    
    -- Technical
    resolution VARCHAR(20),
    format VARCHAR(20),
    file_size_bytes BIGINT,
    
    -- Usage Tracking
    used_in_newsletters INT DEFAULT 0,
    used_in_social INT DEFAULT 0,
    used_in_email INT DEFAULT 0,
    used_in_sms_links INT DEFAULT 0,
    used_in_ads INT DEFAULT 0,
    
    -- Performance
    total_views INT DEFAULT 0,
    total_completions INT DEFAULT 0,
    completion_rate DECIMAL(7,6),
    total_engagement INT DEFAULT 0,
    attributed_revenue DECIMAL(12,2) DEFAULT 0,
    performance_score INT DEFAULT 0,
    
    status VARCHAR(20) DEFAULT 'ACTIVE',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_length_category CHECK (length_category IN ('6_SEC', '15_SEC', '30_SEC', '45_SEC', '60_SEC', '90_SEC', 'LONG_FORM'))
);

CREATE INDEX idx_video_library ON video_library(library_id);
CREATE INDEX idx_video_length ON video_library(length_category);
CREATE INDEX idx_video_purpose ON video_library(purpose);
CREATE INDEX idx_video_issue ON video_library(issue_code);
CREATE INDEX idx_video_score ON video_library(performance_score DESC);

-- ============================================================================
-- TABLE 13: AI SEARCH INDEX
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_search_index (
    id BIGSERIAL PRIMARY KEY,
    content_id BIGINT NOT NULL REFERENCES library_content(id) ON DELETE CASCADE,
    
    -- Text Content for Search
    searchable_text TEXT,
    
    -- Keywords & Tags
    keywords TEXT[],
    
    -- Context Tags
    best_for_grades VARCHAR(5)[],
    best_for_factions VARCHAR(4)[],
    best_for_issues VARCHAR(10)[],
    best_for_occasions VARCHAR(50)[],
    best_for_channels VARCHAR(20)[],
    
    -- Performance Context
    performance_tier VARCHAR(20),
    roi_tier VARCHAR(20),
    
    -- Vector Embedding (if using pgvector)
    -- embedding VECTOR(1536),
    
    indexed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_search_content UNIQUE (content_id)
);

CREATE INDEX idx_search_content ON ai_search_index(content_id);
CREATE INDEX idx_search_keywords ON ai_search_index USING GIN(keywords);
CREATE INDEX idx_search_grades ON ai_search_index USING GIN(best_for_grades);
CREATE INDEX idx_search_factions ON ai_search_index USING GIN(best_for_factions);
CREATE INDEX idx_search_issues ON ai_search_index USING GIN(best_for_issues);
CREATE INDEX idx_search_occasions ON ai_search_index USING GIN(best_for_occasions);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Top Performers by Channel
CREATE OR REPLACE VIEW v_top_performers_by_channel AS
SELECT 
    lc.channel,
    lc.id AS content_id,
    lc.title,
    lc.purpose,
    cp.total_performance_score,
    cp.roi,
    cp.total_revenue,
    cp.times_used,
    ROW_NUMBER() OVER (PARTITION BY lc.channel ORDER BY cp.total_performance_score DESC) AS rank
FROM library_content lc
JOIN content_performance cp ON lc.id = cp.content_id
WHERE lc.status = 'ACTIVE' AND cp.times_used >= 5;

-- Best Content for Context
CREATE OR REPLACE VIEW v_best_content_for_context AS
SELECT 
    cce.context_type,
    cce.context_value,
    lc.id AS content_id,
    lc.channel,
    lc.title,
    lc.purpose,
    cce.conversion_rate,
    cce.roi,
    cce.sample_size,
    cce.rank_in_context
FROM content_context_effectiveness cce
JOIN library_content lc ON cce.content_id = lc.id
WHERE lc.status = 'ACTIVE' AND cce.sample_size >= 10
ORDER BY cce.context_type, cce.context_value, cce.rank_in_context;

-- Daily Performance Summary
CREATE OR REPLACE VIEW v_daily_performance_summary AS
SELECT 
    DATE(cul.used_at) AS usage_date,
    lc.channel,
    COUNT(DISTINCT cul.id) AS usage_count,
    SUM(cul.recipients) AS total_recipients,
    SUM(cul.revenue) AS total_revenue,
    SUM(cul.cost) AS total_cost,
    CASE WHEN SUM(cul.cost) > 0 THEN SUM(cul.revenue) / SUM(cul.cost) ELSE 0 END AS roi,
    SUM(cul.conversions) AS total_conversions
FROM content_usage_log cul
JOIN library_content lc ON cul.content_id = lc.id
GROUP BY DATE(cul.used_at), lc.channel
ORDER BY usage_date DESC, lc.channel;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Calculate Performance Score
CREATE OR REPLACE FUNCTION calculate_performance_score(p_content_id BIGINT)
RETURNS INT AS $$
DECLARE
    v_perf content_performance%ROWTYPE;
    v_response_rate_score INT;
    v_conversion_rate_score INT;
    v_roi_score INT;
    v_reuse_score INT;
    v_freshness_score INT;
    v_consistency_score INT;
    v_total_score INT;
BEGIN
    SELECT * INTO v_perf FROM content_performance WHERE content_id = p_content_id;
    
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    
    -- Response Rate Score (max 200)
    v_response_rate_score := LEAST(200, COALESCE(
        CASE 
            WHEN v_perf.email_open_rate IS NOT NULL THEN (v_perf.email_open_rate * v_perf.email_click_rate * 10000)::INT
            WHEN v_perf.sms_reply_rate IS NOT NULL THEN (v_perf.sms_reply_rate * 10000)::INT
            WHEN v_perf.print_response_rate IS NOT NULL THEN (v_perf.print_response_rate * 10000)::INT
            WHEN v_perf.call_pledge_rate IS NOT NULL THEN (v_perf.call_pledge_rate * 10000)::INT
            WHEN v_perf.social_engagement_rate IS NOT NULL THEN (v_perf.social_engagement_rate * 10000)::INT
            ELSE 0
        END, 0
    ));
    
    -- Conversion Rate Score (max 250)
    v_conversion_rate_score := LEAST(250, 
        CASE WHEN v_perf.total_recipients > 0 
        THEN ((v_perf.total_conversions::DECIMAL / v_perf.total_recipients) * 5000)::INT
        ELSE 0 END
    );
    
    -- ROI Score (max 300)
    v_roi_score := LEAST(300, 
        CASE WHEN v_perf.roi IS NOT NULL AND v_perf.roi > 0 
        THEN (v_perf.roi * 10)::INT
        ELSE 0 END
    );
    
    -- Reuse Score (max 100)
    v_reuse_score := LEAST(100, v_perf.times_used * 5);
    
    -- Freshness Score (max 50)
    v_freshness_score := CASE 
        WHEN v_perf.last_used >= NOW() - INTERVAL '7 days' THEN 50
        WHEN v_perf.last_used >= NOW() - INTERVAL '30 days' THEN 40
        WHEN v_perf.last_used >= NOW() - INTERVAL '90 days' THEN 25
        ELSE 10
    END;
    
    -- Consistency Score (max 100)
    v_consistency_score := 50; -- Placeholder - would calculate variance
    
    v_total_score := v_response_rate_score + v_conversion_rate_score + v_roi_score + 
                     v_reuse_score + v_freshness_score + v_consistency_score;
    
    -- Update the record
    UPDATE content_performance SET
        response_rate_score = v_response_rate_score,
        conversion_rate_score = v_conversion_rate_score,
        roi_score = v_roi_score,
        reuse_value_score = v_reuse_score,
        freshness_score = v_freshness_score,
        consistency_score = v_consistency_score,
        total_performance_score = v_total_score,
        updated_at = NOW()
    WHERE content_id = p_content_id;
    
    -- Update library_content
    UPDATE library_content SET
        performance_score = v_total_score,
        updated_at = NOW()
    WHERE id = p_content_id;
    
    RETURN v_total_score;
END;
$$ LANGUAGE plpgsql;

-- Find Best Content for Context
CREATE OR REPLACE FUNCTION find_best_content(
    p_library_id BIGINT,
    p_channel VARCHAR(20) DEFAULT NULL,
    p_purpose VARCHAR(50) DEFAULT NULL,
    p_donor_grades VARCHAR(5)[] DEFAULT NULL,
    p_factions VARCHAR(4)[] DEFAULT NULL,
    p_issues VARCHAR(10)[] DEFAULT NULL,
    p_min_score INT DEFAULT 500,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    content_id BIGINT,
    title VARCHAR(255),
    channel VARCHAR(20),
    purpose VARCHAR(50),
    performance_score INT,
    roi DECIMAL(10,4),
    match_score INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        lc.id AS content_id,
        lc.title,
        lc.channel,
        lc.purpose,
        lc.performance_score,
        cp.roi,
        (
            lc.performance_score +
            CASE WHEN p_donor_grades IS NOT NULL AND lc.donor_grade_targets && p_donor_grades THEN 100 ELSE 0 END +
            CASE WHEN p_factions IS NOT NULL AND lc.faction_codes && p_factions THEN 100 ELSE 0 END +
            CASE WHEN p_issues IS NOT NULL AND lc.issue_codes && p_issues THEN 100 ELSE 0 END
        ) AS match_score
    FROM library_content lc
    LEFT JOIN content_performance cp ON lc.id = cp.content_id
    WHERE 
        lc.library_id = p_library_id
        AND lc.status = 'ACTIVE'
        AND lc.performance_score >= p_min_score
        AND (p_channel IS NULL OR lc.channel = p_channel)
        AND (p_purpose IS NULL OR lc.purpose = p_purpose)
    ORDER BY match_score DESC, lc.performance_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Record Content Usage
CREATE OR REPLACE FUNCTION record_content_usage(
    p_content_id BIGINT,
    p_campaign_id BIGINT,
    p_recipients INT,
    p_revenue DECIMAL(12,2),
    p_cost DECIMAL(12,2),
    p_conversions INT,
    p_metrics JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID AS $$
BEGIN
    -- Insert usage log
    INSERT INTO content_usage_log (content_id, campaign_id, recipients, revenue, cost, conversions, metrics)
    VALUES (p_content_id, p_campaign_id, p_recipients, p_revenue, p_cost, p_conversions, p_metrics);
    
    -- Update performance
    UPDATE content_performance SET
        times_used = times_used + 1,
        last_used = NOW(),
        total_recipients = total_recipients + p_recipients,
        total_revenue = total_revenue + p_revenue,
        total_cost = total_cost + p_cost,
        total_conversions = total_conversions + p_conversions,
        roi = CASE WHEN (total_cost + p_cost) > 0 THEN (total_revenue + p_revenue) / (total_cost + p_cost) ELSE 0 END,
        updated_at = NOW()
    WHERE content_id = p_content_id;
    
    -- Recalculate performance score
    PERFORM calculate_performance_score(p_content_id);
END;
$$ LANGUAGE plpgsql;

-- Archive Content
CREATE OR REPLACE FUNCTION archive_content(
    p_content_id BIGINT,
    p_archive_type VARCHAR(20),
    p_reason TEXT,
    p_performed_by VARCHAR(100)
)
RETURNS BIGINT AS $$
DECLARE
    v_content library_content%ROWTYPE;
    v_archive_id BIGINT;
    v_archive_path VARCHAR(1000);
BEGIN
    SELECT * INTO v_content FROM library_content WHERE id = p_content_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Content not found: %', p_content_id;
    END IF;
    
    -- Generate archive path
    v_archive_path := '/_ARCHIVE/' || p_archive_type || '/' || 
                      TO_CHAR(NOW(), 'YYYY/MM/DD') || '/' ||
                      v_content.file_name;
    
    -- Create archive record
    INSERT INTO archive_records (
        original_content_id,
        original_file_path,
        original_folder_category,
        archive_path,
        archive_type,
        archive_reason,
        action_performed_by,
        expires_at,
        original_metadata
    ) VALUES (
        p_content_id,
        v_content.file_path,
        v_content.folder_category,
        v_archive_path,
        p_archive_type,
        p_reason,
        p_performed_by,
        NOW() + INTERVAL '90 days',
        row_to_json(v_content)::jsonb
    )
    RETURNING id INTO v_archive_id;
    
    -- Mark content as archived
    UPDATE library_content SET
        status = 'ARCHIVED',
        updated_at = NOW()
    WHERE id = p_content_id;
    
    RETURN v_archive_id;
END;
$$ LANGUAGE plpgsql;

-- Send Notification
CREATE OR REPLACE FUNCTION send_notification(
    p_library_id BIGINT,
    p_type VARCHAR(50),
    p_priority VARCHAR(20),
    p_title VARCHAR(200),
    p_message TEXT,
    p_entity_type VARCHAR(50) DEFAULT NULL,
    p_entity_id BIGINT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_notification_id BIGINT;
BEGIN
    INSERT INTO library_notifications (
        library_id,
        notification_type,
        notification_priority,
        title,
        message,
        related_entity_type,
        related_entity_id
    ) VALUES (
        p_library_id,
        p_type,
        p_priority,
        p_title,
        p_message,
        p_entity_type,
        p_entity_id
    )
    RETURNING id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-create performance record on content insert
CREATE OR REPLACE FUNCTION trigger_create_performance_record()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO content_performance (content_id)
    VALUES (NEW.id)
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_content_performance
AFTER INSERT ON library_content
FOR EACH ROW EXECUTE FUNCTION trigger_create_performance_record();

-- Update rankings periodically
CREATE OR REPLACE FUNCTION update_content_rankings()
RETURNS VOID AS $$
BEGIN
    -- Update overall rankings
    WITH ranked AS (
        SELECT id, ROW_NUMBER() OVER (ORDER BY performance_score DESC) AS rank
        FROM library_content WHERE status = 'ACTIVE'
    )
    UPDATE library_content lc SET
        performance_rank_overall = r.rank
    FROM ranked r WHERE lc.id = r.id;
    
    -- Update category rankings
    WITH ranked AS (
        SELECT id, 
               ROW_NUMBER() OVER (PARTITION BY channel, purpose ORDER BY performance_score DESC) AS rank
        FROM library_content WHERE status = 'ACTIVE'
    )
    UPDATE library_content lc SET
        performance_rank_category = r.rank
    FROM ranked r WHERE lc.id = r.id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE library_content IS 'Master table for all campaign communications content';
COMMENT ON TABLE content_performance IS 'Performance metrics and scoring for each content item';
COMMENT ON TABLE content_context_effectiveness IS 'How well content performs in specific contexts';
COMMENT ON TABLE content_usage_log IS 'Log of every time content is used in a campaign';
COMMENT ON TABLE drip_campaigns IS 'Multi-touch drip campaign templates';
COMMENT ON TABLE upload_queue IS 'Queue for processing candidate uploads';
COMMENT ON TABLE archive_records IS 'Records of archived/deleted content for recovery';
COMMENT ON TABLE library_notifications IS 'Notification queue for candidates';
COMMENT ON TABLE social_media_content IS 'Social media posts with platform analytics';
COMMENT ON TABLE video_library IS 'Video content organized by length and purpose';
COMMENT ON TABLE ai_search_index IS 'AI-optimized search index for content retrieval';
