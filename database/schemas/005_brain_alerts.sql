-- ============================================================================
-- BRAIN CONTROL SYSTEM - ALERTS & NOTIFICATIONS
-- ============================================================================
-- File: 005_brain_alerts.sql
-- Alert definitions, subscriptions, notifications, escalations
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: ALERT DEFINITIONS
-- ============================================================================

-- Alert type definitions
CREATE TABLE alert_types (
    alert_type_id SERIAL PRIMARY KEY,
    alert_type_code VARCHAR(50) UNIQUE NOT NULL,
    alert_type_name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Default severity
    default_severity alert_severity DEFAULT 'MEDIUM',
    
    -- Category
    category VARCHAR(50),
    
    -- Auto-acknowledgement
    auto_acknowledge_minutes INTEGER,
    auto_resolve_minutes INTEGER,
    
    -- Escalation
    escalation_enabled BOOLEAN DEFAULT false,
    escalation_after_minutes INTEGER DEFAULT 30,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Alert rules (when to create alerts)
CREATE TABLE alert_rules (
    rule_id SERIAL PRIMARY KEY,
    rule_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Identification
    rule_code VARCHAR(50) UNIQUE NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Scope
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    vendor_code VARCHAR(50),
    
    -- Alert type
    alert_type_code VARCHAR(50) NOT NULL REFERENCES alert_types(alert_type_code),
    severity alert_severity NOT NULL,
    
    -- Trigger condition
    metric_name VARCHAR(100) NOT NULL,
    operator VARCHAR(10) NOT NULL,
    threshold_value DECIMAL(12,4) NOT NULL,
    threshold_unit VARCHAR(30),
    
    -- Evaluation
    evaluation_window_minutes INTEGER DEFAULT 5,
    consecutive_violations INTEGER DEFAULT 1,
    
    -- Cooldown
    cooldown_minutes INTEGER DEFAULT 15,
    
    -- Auto-correction link
    auto_correction_rule_id INTEGER REFERENCES self_correction_rules(rule_id),
    
    -- Priority
    priority INTEGER DEFAULT 100,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100)
);

-- ============================================================================
-- SECTION 2: ALERTS
-- ============================================================================

-- Main alerts table
CREATE TABLE alerts (
    alert_id SERIAL PRIMARY KEY,
    alert_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Alert identification
    alert_type_code VARCHAR(50) REFERENCES alert_types(alert_type_code),
    rule_id INTEGER REFERENCES alert_rules(rule_id) ON DELETE SET NULL,
    
    -- Severity
    severity alert_severity NOT NULL,
    original_severity alert_severity,
    
    -- Scope
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE SET NULL,
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE SET NULL,
    vendor_code VARCHAR(50),
    
    -- Alert content
    alert_title VARCHAR(300) NOT NULL,
    alert_message TEXT NOT NULL,
    alert_summary TEXT,
    
    -- Trigger details
    threshold_name VARCHAR(100),
    threshold_value DECIMAL(12,4),
    actual_value DECIMAL(12,4),
    metric_unit VARCHAR(30),
    
    -- Additional data
    alert_data JSONB,
    context JSONB,
    
    -- Suggested actions
    suggested_action TEXT,
    action_url VARCHAR(500),
    runbook_url VARCHAR(500),
    
    -- Auto-correction
    auto_correctable BOOLEAN DEFAULT false,
    auto_correction_applied BOOLEAN DEFAULT false,
    correction_id INTEGER REFERENCES self_correction_log(correction_id),
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'open',
    
    -- Acknowledgement
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by VARCHAR(100),
    acknowledgement_notes TEXT,
    
    -- Resolution
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_type VARCHAR(50),
    resolution_notes TEXT,
    
    -- Escalation
    escalation_level INTEGER DEFAULT 0,
    escalated_at TIMESTAMPTZ,
    escalated_to VARCHAR(200),
    
    -- Timing
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    
    -- Deduplication
    fingerprint VARCHAR(64),
    duplicate_count INTEGER DEFAULT 0,
    first_occurrence_at TIMESTAMPTZ,
    last_occurrence_at TIMESTAMPTZ
);

-- Alert status history
CREATE TABLE alert_status_history (
    history_id BIGSERIAL PRIMARY KEY,
    alert_id INTEGER NOT NULL REFERENCES alerts(alert_id) ON DELETE CASCADE,
    
    -- Status change
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    
    -- Who changed it
    changed_by VARCHAR(100) NOT NULL,
    change_reason TEXT,
    
    -- Timing
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Alert comments/notes
CREATE TABLE alert_comments (
    comment_id SERIAL PRIMARY KEY,
    alert_id INTEGER NOT NULL REFERENCES alerts(alert_id) ON DELETE CASCADE,
    
    -- Comment content
    comment_text TEXT NOT NULL,
    
    -- Author
    author VARCHAR(100) NOT NULL,
    
    -- Type
    comment_type VARCHAR(20) DEFAULT 'note',
    
    -- Visibility
    is_internal BOOLEAN DEFAULT false,
    
    -- Timing
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Related alerts (grouping)
CREATE TABLE alert_relations (
    relation_id SERIAL PRIMARY KEY,
    parent_alert_id INTEGER NOT NULL REFERENCES alerts(alert_id) ON DELETE CASCADE,
    child_alert_id INTEGER NOT NULL REFERENCES alerts(alert_id) ON DELETE CASCADE,
    relation_type VARCHAR(50) DEFAULT 'related',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_alert_relation UNIQUE (parent_alert_id, child_alert_id)
);

-- ============================================================================
-- SECTION 3: SUBSCRIPTIONS
-- ============================================================================

-- Alert subscribers
CREATE TABLE alert_subscribers (
    subscriber_id SERIAL PRIMARY KEY,
    subscriber_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Identification
    user_id VARCHAR(100) NOT NULL,
    user_name VARCHAR(200),
    user_email VARCHAR(200),
    user_phone VARCHAR(30),
    
    -- Notification preferences
    notification_email BOOLEAN DEFAULT true,
    notification_sms BOOLEAN DEFAULT false,
    notification_push BOOLEAN DEFAULT false,
    notification_dashboard BOOLEAN DEFAULT true,
    notification_slack BOOLEAN DEFAULT false,
    notification_teams BOOLEAN DEFAULT false,
    
    -- Slack/Teams config
    slack_user_id VARCHAR(50),
    slack_channel VARCHAR(100),
    teams_user_id VARCHAR(100),
    teams_channel VARCHAR(100),
    
    -- Quiet hours
    quiet_hours_enabled BOOLEAN DEFAULT false,
    quiet_hours_start TIME DEFAULT '22:00',
    quiet_hours_end TIME DEFAULT '07:00',
    quiet_hours_timezone VARCHAR(50) DEFAULT 'America/New_York',
    override_for_critical BOOLEAN DEFAULT true,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_subscriber_user UNIQUE (user_id)
);

-- Alert subscriptions (what each user subscribes to)
CREATE TABLE alert_subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    subscriber_id INTEGER NOT NULL REFERENCES alert_subscribers(subscriber_id) ON DELETE CASCADE,
    
    -- Scope (NULL means all)
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    alert_type_code VARCHAR(50) REFERENCES alert_types(alert_type_code) ON DELETE CASCADE,
    
    -- Minimum severity to notify
    min_severity alert_severity DEFAULT 'HIGH',
    
    -- Notification channel overrides
    channel_override JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_subscription UNIQUE (subscriber_id, ecosystem_code, function_code, alert_type_code)
);

-- ============================================================================
-- SECTION 4: NOTIFICATIONS
-- ============================================================================

-- Notification queue
CREATE TABLE notification_queue (
    queue_id BIGSERIAL PRIMARY KEY,
    
    -- Alert reference
    alert_id INTEGER NOT NULL REFERENCES alerts(alert_id) ON DELETE CASCADE,
    subscription_id INTEGER REFERENCES alert_subscriptions(subscription_id) ON DELETE SET NULL,
    subscriber_id INTEGER REFERENCES alert_subscribers(subscriber_id) ON DELETE SET NULL,
    
    -- Channel
    channel VARCHAR(20) NOT NULL,
    
    -- Recipient
    recipient VARCHAR(300) NOT NULL,
    recipient_type VARCHAR(20),
    
    -- Content
    subject VARCHAR(500),
    message_body TEXT NOT NULL,
    message_html TEXT,
    message_data JSONB,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending',
    
    -- Scheduling
    scheduled_for TIMESTAMPTZ DEFAULT NOW(),
    priority INTEGER DEFAULT 100,
    
    -- Retry handling
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    next_retry_at TIMESTAMPTZ,
    
    -- Delivery tracking
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    delivery_status VARCHAR(50),
    delivery_details JSONB,
    
    -- Error handling
    last_error TEXT,
    
    -- Engagement tracking
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notification delivery log
CREATE TABLE notification_log (
    log_id BIGSERIAL PRIMARY KEY,
    queue_id BIGINT REFERENCES notification_queue(queue_id) ON DELETE SET NULL,
    alert_id INTEGER REFERENCES alerts(alert_id) ON DELETE SET NULL,
    
    -- Delivery details
    channel VARCHAR(20) NOT NULL,
    recipient VARCHAR(300) NOT NULL,
    
    -- Timing
    attempted_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Result
    success BOOLEAN NOT NULL,
    status_code INTEGER,
    response_message TEXT,
    
    -- External references
    external_message_id VARCHAR(200),
    
    -- Metadata
    metadata JSONB
);

-- ============================================================================
-- SECTION 5: ESCALATION
-- ============================================================================

-- Escalation policies
CREATE TABLE escalation_policies (
    policy_id SERIAL PRIMARY KEY,
    policy_name VARCHAR(100) NOT NULL,
    policy_description TEXT,
    
    -- Scope
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    severity_minimum alert_severity DEFAULT 'HIGH',
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Escalation levels
CREATE TABLE escalation_levels (
    level_id SERIAL PRIMARY KEY,
    policy_id INTEGER NOT NULL REFERENCES escalation_policies(policy_id) ON DELETE CASCADE,
    
    -- Level details
    level_number INTEGER NOT NULL,
    level_name VARCHAR(100),
    
    -- Timing
    escalate_after_minutes INTEGER NOT NULL,
    
    -- Who to notify
    notify_subscribers TEXT[],
    notify_roles TEXT[],
    notify_external JSONB,
    
    -- Actions
    actions JSONB,
    
    CONSTRAINT uq_escalation_level UNIQUE (policy_id, level_number)
);

-- Escalation history
CREATE TABLE escalation_history (
    history_id SERIAL PRIMARY KEY,
    alert_id INTEGER NOT NULL REFERENCES alerts(alert_id) ON DELETE CASCADE,
    policy_id INTEGER REFERENCES escalation_policies(policy_id),
    
    -- Escalation details
    from_level INTEGER,
    to_level INTEGER NOT NULL,
    
    -- Notification
    notified_subscribers TEXT[],
    notifications_sent INTEGER DEFAULT 0,
    
    -- Timing
    escalated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Reason
    escalation_reason TEXT
);

-- ============================================================================
-- SECTION 6: ALERT AGGREGATION & STATISTICS
-- ============================================================================

-- Daily alert statistics
CREATE TABLE alert_statistics_daily (
    stat_id SERIAL PRIMARY KEY,
    stat_date DATE NOT NULL,
    
    -- Scope
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    
    -- Counts by severity
    critical_count INTEGER DEFAULT 0,
    high_count INTEGER DEFAULT 0,
    medium_count INTEGER DEFAULT 0,
    low_count INTEGER DEFAULT 0,
    info_count INTEGER DEFAULT 0,
    total_count INTEGER DEFAULT 0,
    
    -- Resolution metrics
    acknowledged_count INTEGER DEFAULT 0,
    resolved_count INTEGER DEFAULT 0,
    auto_resolved_count INTEGER DEFAULT 0,
    
    -- Timing metrics
    avg_time_to_acknowledge_minutes INTEGER,
    avg_time_to_resolve_minutes INTEGER,
    
    -- Auto-correction
    auto_corrected_count INTEGER DEFAULT 0,
    
    -- Notification metrics
    notifications_sent INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_alert_stats_daily UNIQUE (stat_date, ecosystem_code)
);

-- ============================================================================
-- SECTION 7: INDEXES
-- ============================================================================

-- Alerts
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_ecosystem ON alerts(ecosystem_code);
CREATE INDEX idx_alerts_function ON alerts(function_code);
CREATE INDEX idx_alerts_created ON alerts(created_at DESC);
CREATE INDEX idx_alerts_fingerprint ON alerts(fingerprint);
CREATE INDEX idx_alerts_open ON alerts(status, severity) WHERE status = 'open';

-- Alert rules
CREATE INDEX idx_alert_rules_ecosystem ON alert_rules(ecosystem_code);
CREATE INDEX idx_alert_rules_function ON alert_rules(function_code);
CREATE INDEX idx_alert_rules_active ON alert_rules(is_active) WHERE is_active = true;

-- Subscriptions
CREATE INDEX idx_subscriptions_subscriber ON alert_subscriptions(subscriber_id);
CREATE INDEX idx_subscriptions_ecosystem ON alert_subscriptions(ecosystem_code);

-- Notification queue
CREATE INDEX idx_notif_queue_status ON notification_queue(status);
CREATE INDEX idx_notif_queue_scheduled ON notification_queue(scheduled_for) WHERE status = 'pending';
CREATE INDEX idx_notif_queue_alert ON notification_queue(alert_id);

-- Alert statistics
CREATE INDEX idx_alert_stats_date ON alert_statistics_daily(stat_date);

-- ============================================================================
-- SECTION 8: COMMENTS
-- ============================================================================

COMMENT ON TABLE alerts IS 'Central alert repository for all system alerts';
COMMENT ON TABLE alert_rules IS 'Configurable rules for automatic alert generation';
COMMENT ON TABLE alert_subscribers IS 'Users who can receive alert notifications';
COMMENT ON TABLE alert_subscriptions IS 'Subscription preferences for each user';
COMMENT ON TABLE notification_queue IS 'Queue for outbound notifications';
COMMENT ON TABLE escalation_policies IS 'Policies for escalating unresolved alerts';
