-- BROYHILLGOP COMPLETE DATABASE - ALL 49 ECOSYSTEMS
-- Extracted from Python ecosystem files
-- Generated: Thu Dec 18 00:29:30 UTC 2025


-- ================================================================
-- FROM: ecosystem_00_datahub_complete.py (E00)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 0: DATAHUB - PERFORMANCE OPTIMIZATION
-- The remaining 5% - indexes and query optimization
-- ============================================================================

-- High-traffic table indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_donors_county_grade 
    ON broyhillgop.donors(county, amount_grade_state);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_donors_last_donation 
    ON broyhillgop.donors(last_donation DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_donors_total_donations 
    ON broyhillgop.donors(total_donations DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_donors_intensity 
    ON broyhillgop.donors(intensity_grade_2y DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_donors_email_lower 
    ON broyhillgop.donors(LOWER(email));

-- Social media indexes (E19 integration)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_social_posts_scheduled_status 
    ON social_posts(scheduled_for, status) WHERE status = 'scheduled';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_social_posts_candidate_platform 
    ON social_posts(candidate_id, platform, posted_at DESC);

-- Event tracking indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_created_type 
    ON intelligence_brain_events(created_at DESC, category);

-- Composite indexes for common queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_donors_targeting 
    ON broyhillgop.donors(amount_grade_state, intensity_grade_2y, county)
    WHERE status = 'active';

-- Partial indexes for active records
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_candidates_active 
    ON candidates(county, office) WHERE status = 'active';

-- JSONB indexes for flexible queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_social_posts_compliance_gin 
    ON social_posts USING GIN (compliance_issues);

-- Analyze tables for query planner
ANALYZE broyhillgop.donors;
ANALYZE candidates;
ANALYZE social_posts;
ANALYZE social_approval_requests;

-- ============================================================================
-- QUERY PERFORMANCE VIEWS
-- ============================================================================

-- Slow query log view
CREATE OR REPLACE VIEW v_e0_slow_queries AS
SELECT 
    query,
    calls,
    mean_time,
    total_time,
    rows
FROM pg_stat_statements
WHERE mean_time > 100  -- ms
ORDER BY mean_time DESC
LIMIT 50;

-- Table sizes view
CREATE OR REPLACE VIEW v_e0_table_sizes AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) as table_size,
    pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename)) as index_size
FROM pg_tables
WHERE schemaname IN ('public', 'broyhillgop')
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;

-- Index usage view
CREATE OR REPLACE VIEW v_e0_index_usage AS
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

SELECT 'Performance optimization complete!' as status;


-- ============================================================================
-- ECOSYSTEM 0: DATAHUB - DATA GOVERNANCE
-- The remaining 3% - audit logging, retention policies
-- ============================================================================

-- Audit log table
CREATE TABLE IF NOT EXISTS datahub_audit_log (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(20) NOT NULL,  -- INSERT, UPDATE, DELETE
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(255),
    changed_at TIMESTAMP DEFAULT NOW(),
    ip_address INET
);

CREATE INDEX IF NOT EXISTS idx_audit_table ON datahub_audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_time ON datahub_audit_log(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_record ON datahub_audit_log(record_id);

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION datahub_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO datahub_audit_log (table_name, operation, record_id, old_data, changed_at)
        VALUES (TG_TABLE_NAME, 'DELETE', OLD.id, to_jsonb(OLD), NOW());
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO datahub_audit_log (table_name, operation, record_id, old_data, new_data, changed_at)
        VALUES (TG_TABLE_NAME, 'UPDATE', NEW.id, to_jsonb(OLD), to_jsonb(NEW), NOW());
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO datahub_audit_log (table_name, operation, record_id, new_data, changed_at)
        VALUES (TG_TABLE_NAME, 'INSERT', NEW.id, to_jsonb(NEW), NOW());
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to critical tables
DROP TRIGGER IF EXISTS audit_donors ON broyhillgop.donors;
CREATE TRIGGER audit_donors
    AFTER INSERT OR UPDATE OR DELETE ON broyhillgop.donors
    FOR EACH ROW EXECUTE FUNCTION datahub_audit_trigger();

-- Data retention policy table
CREATE TABLE IF NOT EXISTS datahub_retention_policies (
    policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    retention_days INTEGER NOT NULL,
    date_column VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_cleanup TIMESTAMP,
    rows_deleted INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert default retention policies
INSERT INTO datahub_retention_policies (table_name, retention_days, date_column) VALUES
    ('datahub_audit_log', 90, 'changed_at'),
    ('social_engagement_log', 180, 'engaged_at'),
    ('facebook_compliance_log', 365, 'checked_at'),
    ('intelligence_brain_events', 90, 'created_at')
ON CONFLICT DO NOTHING;

-- Retention cleanup function
CREATE OR REPLACE FUNCTION datahub_cleanup_old_data()
RETURNS TABLE(table_name TEXT, deleted_count INTEGER) AS $$
DECLARE
    policy RECORD;
    deleted INT;
BEGIN
    FOR policy IN 
        SELECT * FROM datahub_retention_policies WHERE is_active = true
    LOOP
        EXECUTE format(
            'DELETE FROM %I WHERE %I < NOW() - INTERVAL ''%s days''',
            policy.table_name,
            policy.date_column,
            policy.retention_days
        );
        GET DIAGNOSTICS deleted = ROW_COUNT;
        
        UPDATE datahub_retention_policies 
        SET last_cleanup = NOW(), rows_deleted = rows_deleted + deleted
        WHERE policy_id = policy.policy_id;
        
        table_name := policy.table_name;
        deleted_count := deleted;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Backup metadata table
CREATE TABLE IF NOT EXISTS datahub_backup_log (
    backup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    backup_type VARCHAR(50) NOT NULL,  -- 'full', 'incremental', 'schema'
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    size_bytes BIGINT,
    status VARCHAR(50),  -- 'running', 'completed', 'failed'
    storage_location TEXT,
    error_message TEXT
);

SELECT 'Data governance setup complete!' as status;


-- ============================================================================
-- ECOSYSTEM 0: DATAHUB - MONITORING & HEALTH CHECKS
-- The remaining 2% - real-time monitoring
-- ============================================================================

-- Health check table
CREATE TABLE IF NOT EXISTS datahub_health_checks (
    check_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,  -- 'healthy', 'warning', 'critical'
    details JSONB,
    checked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_time ON datahub_health_checks(checked_at DESC);

-- System metrics table
CREATE TABLE IF NOT EXISTS datahub_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(15,4) NOT NULL,
    unit VARCHAR(50),
    tags JSONB,
    recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_metrics_name_time ON datahub_metrics(metric_name, recorded_at DESC);

-- Health check function
CREATE OR REPLACE FUNCTION datahub_health_check()
RETURNS TABLE(check_name TEXT, status TEXT, details JSONB) AS $$
DECLARE
    conn_count INTEGER;
    db_size TEXT;
    oldest_event TIMESTAMP;
BEGIN
    -- Check 1: Database connections
    SELECT count(*) INTO conn_count FROM pg_stat_activity WHERE state = 'active';
    check_name := 'active_connections';
    IF conn_count < 50 THEN
        status := 'healthy';
    ELSIF conn_count < 80 THEN
        status := 'warning';
    ELSE
        status := 'critical';
    END IF;
    details := jsonb_build_object('count', conn_count, 'max', 100);
    RETURN NEXT;
    
    -- Check 2: Database size
    SELECT pg_size_pretty(pg_database_size(current_database())) INTO db_size;
    check_name := 'database_size';
    status := 'healthy';
    details := jsonb_build_object('size', db_size);
    RETURN NEXT;
    
    -- Check 3: Event bus lag
    SELECT MIN(created_at) INTO oldest_event 
    FROM intelligence_brain_events 
    WHERE created_at > NOW() - INTERVAL '1 hour';
    
    check_name := 'event_bus_lag';
    IF oldest_event IS NULL OR oldest_event > NOW() - INTERVAL '5 minutes' THEN
        status := 'healthy';
    ELSIF oldest_event > NOW() - INTERVAL '15 minutes' THEN
        status := 'warning';
    ELSE
        status := 'critical';
    END IF;
    details := jsonb_build_object('oldest_event', oldest_event);
    RETURN NEXT;
    
    -- Check 4: Pending approvals
    SELECT COUNT(*) INTO conn_count FROM social_approval_requests WHERE status = 'pending';
    check_name := 'pending_approvals';
    status := 'healthy';
    details := jsonb_build_object('count', conn_count);
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Record metrics function
CREATE OR REPLACE FUNCTION datahub_record_metrics()
RETURNS void AS $$
BEGIN
    -- Record key metrics
    INSERT INTO datahub_metrics (metric_name, metric_value, unit) VALUES
        ('active_connections', (SELECT count(*) FROM pg_stat_activity WHERE state = 'active'), 'count'),
        ('total_donors', (SELECT count(*) FROM broyhillgop.donors), 'count'),
        ('total_candidates', (SELECT count(*) FROM candidates), 'count'),
        ('posts_today', (SELECT count(*) FROM social_posts WHERE DATE(posted_at) = CURRENT_DATE), 'count'),
        ('approvals_pending', (SELECT count(*) FROM social_approval_requests WHERE status = 'pending'), 'count');
END;
$$ LANGUAGE plpgsql;

SELECT 'Monitoring setup complete!' as status;


-- ================================================================
-- FROM: ecosystem_01_donor_intelligence_complete.py (E01)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 1: DONOR INTELLIGENCE SYSTEM
-- ============================================================================

-- Donor Scores (3D Grading)
CREATE TABLE IF NOT EXISTS donor_scores (
    score_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    candidate_id UUID,
    
    -- Amount Dimension
    amount_grade VARCHAR(5) NOT NULL,
    amount_percentile INTEGER CHECK (amount_percentile BETWEEN 0 AND 1000),
    total_donated DECIMAL(12,2) DEFAULT 0,
    max_single_donation DECIMAL(12,2) DEFAULT 0,
    avg_donation DECIMAL(12,2) DEFAULT 0,
    
    -- Intensity Dimension (1-10)
    intensity_score INTEGER CHECK (intensity_score BETWEEN 1 AND 10),
    frequency_score DECIMAL(5,2),
    recency_score DECIMAL(5,2),
    consistency_score DECIMAL(5,2),
    growth_score DECIMAL(5,2),
    
    -- Level Dimension
    level_preference VARCHAR(1) CHECK (level_preference IN ('F', 'S', 'L')),
    federal_pct DECIMAL(5,2) DEFAULT 0,
    state_pct DECIMAL(5,2) DEFAULT 0,
    local_pct DECIMAL(5,2) DEFAULT 0,
    
    -- Combined Score
    composite_score DECIMAL(6,2),
    composite_grade VARCHAR(20),
    
    -- ML Predictions
    predicted_next_amount DECIMAL(12,2),
    predicted_churn_risk DECIMAL(5,4),
    predicted_lifetime_value DECIMAL(12,2),
    optimal_ask_amount DECIMAL(12,2),
    best_channel VARCHAR(50),
    
    -- RFM
    rfm_recency INTEGER,
    rfm_frequency INTEGER,
    rfm_monetary INTEGER,
    rfm_score INTEGER,
    rfm_segment VARCHAR(50),
    
    -- Lifecycle
    lifecycle_stage VARCHAR(50),
    days_as_donor INTEGER,
    days_since_last_donation INTEGER,
    
    -- Metadata
    calculation_version VARCHAR(20) DEFAULT '2.0',
    calculated_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, candidate_id)
);

CREATE INDEX IF NOT EXISTS idx_donor_scores_donor ON donor_scores(donor_id);
CREATE INDEX IF NOT EXISTS idx_donor_scores_candidate ON donor_scores(candidate_id);
CREATE INDEX IF NOT EXISTS idx_donor_scores_grade ON donor_scores(amount_grade);
CREATE INDEX IF NOT EXISTS idx_donor_scores_composite ON donor_scores(composite_score DESC);
CREATE INDEX IF NOT EXISTS idx_donor_scores_intensity ON donor_scores(intensity_score DESC);
CREATE INDEX IF NOT EXISTS idx_donor_scores_lifecycle ON donor_scores(lifecycle_stage);
CREATE INDEX IF NOT EXISTS idx_donor_scores_churn ON donor_scores(predicted_churn_risk DESC);

-- Grade Enforcement Log
CREATE TABLE IF NOT EXISTS grade_enforcement_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    donor_grade VARCHAR(5),
    action_type VARCHAR(50) NOT NULL,
    action_blocked BOOLEAN NOT NULL,
    reason TEXT,
    user_id UUID,
    approval_required BOOLEAN DEFAULT false,
    approved_by UUID,
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_grade_enforcement_donor ON grade_enforcement_log(donor_id);
CREATE INDEX IF NOT EXISTS idx_grade_enforcement_blocked ON grade_enforcement_log(action_blocked);

-- Donor Score History (for trend analysis)
CREATE TABLE IF NOT EXISTS donor_score_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    candidate_id UUID,
    amount_grade VARCHAR(5),
    intensity_score INTEGER,
    composite_score DECIMAL(6,2),
    total_donated DECIMAL(12,2),
    recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_score_history_donor ON donor_score_history(donor_id);
CREATE INDEX IF NOT EXISTS idx_score_history_date ON donor_score_history(recorded_at);

-- ML Clusters
CREATE TABLE IF NOT EXISTS donor_clusters (
    cluster_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    cluster_number INTEGER NOT NULL,
    cluster_name VARCHAR(255),
    cluster_description TEXT,
    donor_count INTEGER DEFAULT 0,
    avg_donation DECIMAL(12,2),
    avg_frequency DECIMAL(5,2),
    dominant_grade VARCHAR(5),
    dominant_level VARCHAR(1),
    centroid JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clusters_candidate ON donor_clusters(candidate_id);

-- Donor Cluster Assignments
CREATE TABLE IF NOT EXISTS donor_cluster_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    cluster_id UUID REFERENCES donor_clusters(cluster_id),
    confidence DECIMAL(5,4),
    assigned_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cluster_assignments_donor ON donor_cluster_assignments(donor_id);
CREATE INDEX IF NOT EXISTS idx_cluster_assignments_cluster ON donor_cluster_assignments(cluster_id);

-- Activist Network Memberships
CREATE TABLE IF NOT EXISTS activist_memberships (
    membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    organization_id UUID,
    organization_name VARCHAR(255) NOT NULL,
    organization_type VARCHAR(100),
    is_leadership BOOLEAN DEFAULT false,
    membership_level VARCHAR(50),
    joined_at DATE,
    verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activist_donor ON activist_memberships(donor_id);
CREATE INDEX IF NOT EXISTS idx_activist_org ON activist_memberships(organization_id);

-- Next Best Action Recommendations
CREATE TABLE IF NOT EXISTS next_best_actions (
    action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    candidate_id UUID,
    recommended_action VARCHAR(100) NOT NULL,
    recommended_channel VARCHAR(50),
    recommended_amount DECIMAL(12,2),
    recommended_message_type VARCHAR(100),
    confidence_score DECIMAL(5,4),
    reasoning TEXT,
    expires_at TIMESTAMP,
    acted_on BOOLEAN DEFAULT false,
    acted_on_at TIMESTAMP,
    outcome VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nba_donor ON next_best_actions(donor_id);
CREATE INDEX IF NOT EXISTS idx_nba_expires ON next_best_actions(expires_at);

-- Scoring Configuration (per candidate)
CREATE TABLE IF NOT EXISTS scoring_config (
    config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    config_name VARCHAR(100) NOT NULL,
    amount_thresholds JSONB,
    intensity_weights JSONB,
    blocked_grades JSONB,
    restricted_grades JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Performance View
CREATE OR REPLACE VIEW v_donor_intelligence_summary AS
SELECT 
    ds.candidate_id,
    ds.amount_grade,
    COUNT(*) as donor_count,
    SUM(ds.total_donated) as total_donated,
    AVG(ds.composite_score) as avg_composite_score,
    AVG(ds.intensity_score) as avg_intensity,
    AVG(ds.predicted_churn_risk) as avg_churn_risk,
    COUNT(CASE WHEN ds.lifecycle_stage = 'major_donor' THEN 1 END) as major_donors,
    COUNT(CASE WHEN ds.lifecycle_stage = 'at_risk' THEN 1 END) as at_risk_donors
FROM donor_scores ds
GROUP BY ds.candidate_id, ds.amount_grade
ORDER BY ds.candidate_id, ds.amount_grade;

-- Top Donors View
CREATE OR REPLACE VIEW v_top_donors AS
SELECT 
    ds.donor_id,
    ds.candidate_id,
    ds.composite_grade,
    ds.amount_grade,
    ds.intensity_score,
    ds.level_preference,
    ds.total_donated,
    ds.composite_score,
    ds.predicted_lifetime_value,
    ds.lifecycle_stage,
    ds.best_channel,
    ds.optimal_ask_amount,
    ds.days_since_last_donation
FROM donor_scores ds
WHERE ds.amount_grade IN ('A++', 'A+', 'A')
ORDER BY ds.composite_score DESC;

-- At Risk Donors View  
CREATE OR REPLACE VIEW v_at_risk_donors AS
SELECT 
    ds.donor_id,
    ds.candidate_id,
    ds.composite_grade,
    ds.total_donated,
    ds.predicted_churn_risk,
    ds.days_since_last_donation,
    ds.lifecycle_stage,
    nba.recommended_action,
    nba.recommended_channel
FROM donor_scores ds
LEFT JOIN next_best_actions nba ON ds.donor_id = nba.donor_id 
    AND nba.expires_at > NOW() AND nba.acted_on = false
WHERE ds.predicted_churn_risk >= 0.5
ORDER BY ds.predicted_churn_risk DESC;

SELECT 'Donor Intelligence schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_02_donation_processing_complete.py (E02)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 2: DONATION PROCESSING SYSTEM
-- ============================================================================

-- Donations
CREATE TABLE IF NOT EXISTS donations (
    donation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    candidate_id UUID,
    campaign_id UUID,
    
    -- Amount
    amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    fee_amount DECIMAL(10,4) DEFAULT 0,
    net_amount DECIMAL(12,2),
    
    -- Payment
    payment_method VARCHAR(50) NOT NULL,
    payment_gateway VARCHAR(50),
    gateway_transaction_id VARCHAR(255),
    gateway_customer_id VARCHAR(255),
    last_four VARCHAR(4),
    card_brand VARCHAR(50),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    status_message TEXT,
    
    -- Compliance
    election_type VARCHAR(50) DEFAULT 'general',
    election_year INTEGER,
    race_level VARCHAR(50),  -- federal, state, local
    is_itemized BOOLEAN DEFAULT false,
    fec_reported BOOLEAN DEFAULT false,
    fec_report_id VARCHAR(100),
    
    -- Donor info (for FEC)
    donor_name VARCHAR(255),
    donor_address TEXT,
    donor_city VARCHAR(100),
    donor_state VARCHAR(2),
    donor_zip VARCHAR(10),
    donor_employer VARCHAR(255),
    donor_occupation VARCHAR(255),
    
    -- Recurring
    is_recurring BOOLEAN DEFAULT false,
    recurring_id UUID,
    
    -- Refund
    refunded_amount DECIMAL(12,2) DEFAULT 0,
    refund_reason TEXT,
    refund_date TIMESTAMP,
    
    -- Metadata
    source VARCHAR(100),  -- web, email, sms, event
    utm_source VARCHAR(255),
    utm_campaign VARCHAR(255),
    device_type VARCHAR(50),
    ip_address VARCHAR(45),
    
    -- Timestamps
    donation_date TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donations_donor ON donations(donor_id);
CREATE INDEX IF NOT EXISTS idx_donations_candidate ON donations(candidate_id);
CREATE INDEX IF NOT EXISTS idx_donations_campaign ON donations(campaign_id);
CREATE INDEX IF NOT EXISTS idx_donations_status ON donations(status);
CREATE INDEX IF NOT EXISTS idx_donations_date ON donations(donation_date);
CREATE INDEX IF NOT EXISTS idx_donations_recurring ON donations(recurring_id);
CREATE INDEX IF NOT EXISTS idx_donations_fec ON donations(fec_reported, is_itemized);

-- Recurring Donations
CREATE TABLE IF NOT EXISTS recurring_donations (
    recurring_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    candidate_id UUID,
    campaign_id UUID,
    
    -- Amount
    amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Schedule
    frequency VARCHAR(20) NOT NULL,
    next_charge_date DATE NOT NULL,
    day_of_month INTEGER,
    
    -- Payment
    payment_method VARCHAR(50) NOT NULL,
    payment_gateway VARCHAR(50),
    gateway_subscription_id VARCHAR(255),
    gateway_customer_id VARCHAR(255),
    gateway_payment_method_id VARCHAR(255),
    
    -- Status
    status VARCHAR(50) DEFAULT 'active',
    failed_attempts INTEGER DEFAULT 0,
    last_failure_reason TEXT,
    last_successful_charge TIMESTAMP,
    
    -- Limits
    total_donated DECIMAL(12,2) DEFAULT 0,
    max_total DECIMAL(12,2),  -- Stop when reached
    charge_count INTEGER DEFAULT 0,
    max_charges INTEGER,  -- Stop after N charges
    
    -- Dates
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recurring_donor ON recurring_donations(donor_id);
CREATE INDEX IF NOT EXISTS idx_recurring_next ON recurring_donations(next_charge_date, status);
CREATE INDEX IF NOT EXISTS idx_recurring_status ON recurring_donations(status);

-- Payment Methods (stored cards)
CREATE TABLE IF NOT EXISTS payment_methods (
    payment_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    
    -- Gateway info
    payment_gateway VARCHAR(50) NOT NULL,
    gateway_payment_method_id VARCHAR(255) NOT NULL,
    gateway_customer_id VARCHAR(255),
    
    -- Card info
    card_brand VARCHAR(50),
    last_four VARCHAR(4),
    exp_month INTEGER,
    exp_year INTEGER,
    
    -- Bank info (ACH)
    bank_name VARCHAR(255),
    account_type VARCHAR(20),
    
    -- Status
    is_default BOOLEAN DEFAULT false,
    is_valid BOOLEAN DEFAULT true,
    
    -- Metadata
    billing_name VARCHAR(255),
    billing_address TEXT,
    billing_zip VARCHAR(10),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_donor ON payment_methods(donor_id);

-- Contribution Limits Tracking
CREATE TABLE IF NOT EXISTS contribution_limits (
    limit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    candidate_id UUID,
    recipient_type VARCHAR(50) NOT NULL,  -- candidate, pac, party
    
    -- Election cycle
    election_cycle VARCHAR(10) NOT NULL,  -- e.g., "2024"
    election_type VARCHAR(50),
    
    -- Amounts
    total_contributed DECIMAL(12,2) DEFAULT 0,
    contribution_limit DECIMAL(12,2) NOT NULL,
    remaining_limit DECIMAL(12,2),
    
    -- Race level
    race_level VARCHAR(50),  -- federal, state, local
    state VARCHAR(2),
    
    -- Last update
    last_donation_date TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, candidate_id, election_cycle, election_type)
);

CREATE INDEX IF NOT EXISTS idx_limits_donor ON contribution_limits(donor_id);
CREATE INDEX IF NOT EXISTS idx_limits_candidate ON contribution_limits(candidate_id);

-- Failed Payment Retries
CREATE TABLE IF NOT EXISTS payment_retries (
    retry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donation_id UUID REFERENCES donations(donation_id),
    recurring_id UUID REFERENCES recurring_donations(recurring_id),
    
    -- Retry info
    retry_number INTEGER NOT NULL,
    scheduled_date DATE NOT NULL,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    attempted_at TIMESTAMP,
    result VARCHAR(50),
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_retries_scheduled ON payment_retries(scheduled_date, status);

-- Receipts
CREATE TABLE IF NOT EXISTS donation_receipts (
    receipt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donation_id UUID REFERENCES donations(donation_id),
    
    -- Receipt info
    receipt_number VARCHAR(50) UNIQUE NOT NULL,
    receipt_type VARCHAR(50) DEFAULT 'standard',  -- standard, year_end, amended
    
    -- Content
    receipt_html TEXT,
    receipt_pdf_url TEXT,
    
    -- Delivery
    sent_to_email VARCHAR(255),
    sent_at TIMESTAMP,
    opened_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_receipts_donation ON donation_receipts(donation_id);

-- Refunds
CREATE TABLE IF NOT EXISTS donation_refunds (
    refund_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donation_id UUID REFERENCES donations(donation_id),
    
    -- Amount
    refund_amount DECIMAL(12,2) NOT NULL,
    fee_refunded DECIMAL(10,4) DEFAULT 0,
    
    -- Gateway
    gateway_refund_id VARCHAR(255),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    
    -- Reason
    reason VARCHAR(255),
    notes TEXT,
    
    -- FEC
    fec_reported BOOLEAN DEFAULT false,
    
    -- Processed
    processed_by UUID,
    processed_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_refunds_donation ON donation_refunds(donation_id);

-- FEC Reports
CREATE TABLE IF NOT EXISTS fec_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Report info
    report_type VARCHAR(50) NOT NULL,  -- quarterly, monthly, pre_primary, etc.
    report_period_start DATE,
    report_period_end DATE,
    filing_deadline DATE,
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    filed_at TIMESTAMP,
    fec_filing_id VARCHAR(100),
    
    -- Totals
    total_receipts DECIMAL(14,2),
    total_disbursements DECIMAL(14,2),
    itemized_contributions DECIMAL(14,2),
    unitemized_contributions DECIMAL(14,2),
    
    -- File
    report_file_url TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fec_reports_candidate ON fec_reports(candidate_id);
CREATE INDEX IF NOT EXISTS idx_fec_reports_deadline ON fec_reports(filing_deadline);

-- Donation Daily Summary
CREATE TABLE IF NOT EXISTS donation_daily_summary (
    date DATE PRIMARY KEY,
    total_donations INTEGER DEFAULT 0,
    total_amount DECIMAL(14,2) DEFAULT 0,
    total_fees DECIMAL(12,4) DEFAULT 0,
    total_net DECIMAL(14,2) DEFAULT 0,
    unique_donors INTEGER DEFAULT 0,
    new_donors INTEGER DEFAULT 0,
    recurring_donations INTEGER DEFAULT 0,
    recurring_amount DECIMAL(14,2) DEFAULT 0,
    avg_donation DECIMAL(12,2) DEFAULT 0,
    refunds INTEGER DEFAULT 0,
    refund_amount DECIMAL(12,2) DEFAULT 0
);

-- Performance Views
CREATE OR REPLACE VIEW v_donation_summary AS
SELECT 
    candidate_id,
    DATE(donation_date) as date,
    COUNT(*) as donation_count,
    SUM(amount) as total_amount,
    SUM(fee_amount) as total_fees,
    SUM(net_amount) as net_amount,
    COUNT(DISTINCT donor_id) as unique_donors,
    AVG(amount) as avg_donation,
    COUNT(CASE WHEN is_recurring THEN 1 END) as recurring_count,
    SUM(CASE WHEN is_recurring THEN amount ELSE 0 END) as recurring_amount
FROM donations
WHERE status = 'completed'
GROUP BY candidate_id, DATE(donation_date);

-- Donor Contribution Summary
CREATE OR REPLACE VIEW v_donor_contributions AS
SELECT 
    d.donor_id,
    d.candidate_id,
    d.election_type,
    SUM(d.amount) as total_contributed,
    COUNT(*) as donation_count,
    MAX(d.donation_date) as last_donation,
    MIN(d.donation_date) as first_donation,
    cl.contribution_limit,
    cl.remaining_limit
FROM donations d
LEFT JOIN contribution_limits cl ON d.donor_id = cl.donor_id 
    AND d.candidate_id = cl.candidate_id 
    AND d.election_type = cl.election_type
WHERE d.status = 'completed'
GROUP BY d.donor_id, d.candidate_id, d.election_type, cl.contribution_limit, cl.remaining_limit;

-- Recurring Health View
CREATE OR REPLACE VIEW v_recurring_health AS
SELECT 
    status,
    COUNT(*) as count,
    SUM(amount) as monthly_value,
    AVG(failed_attempts) as avg_failures,
    COUNT(CASE WHEN failed_attempts > 0 THEN 1 END) as with_failures
FROM recurring_donations
GROUP BY status;

SELECT 'Donation Processing schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_03_candidate_profiles_complete.py (E03)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 3: CANDIDATE PROFILES SYSTEM
-- ============================================================================

-- Main Candidates Table (273 fields)
CREATE TABLE IF NOT EXISTS candidates (
    candidate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- ==================== BASIC INFO (20 fields) ====================
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    suffix VARCHAR(20),
    preferred_name VARCHAR(100),
    legal_name VARCHAR(255),
    date_of_birth DATE,
    age INTEGER,
    gender VARCHAR(20),
    pronouns VARCHAR(50),
    
    -- Contact
    email VARCHAR(255),
    phone VARCHAR(20),
    mobile VARCHAR(20),
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),
    county VARCHAR(100),
    
    -- ==================== OFFICE INFO (25 fields) ====================
    office_type VARCHAR(50) NOT NULL,
    office_title VARCHAR(255),
    office_level VARCHAR(20),  -- federal, state, local
    
    -- Geographic
    district_id VARCHAR(50),
    district_name VARCHAR(255),
    district_type VARCHAR(50),  -- congressional, senate, house, county, city
    precinct VARCHAR(50),
    ward VARCHAR(50),
    
    -- Position
    is_incumbent BOOLEAN DEFAULT false,
    incumbent_since DATE,
    term_start_date DATE,
    term_end_date DATE,
    terms_served INTEGER DEFAULT 0,
    
    -- Election
    election_year INTEGER,
    election_date DATE,
    election_type VARCHAR(50),  -- primary, general, special, runoff
    filing_date DATE,
    ballot_name VARCHAR(255),
    ballot_order INTEGER,
    
    -- Opponent
    opponent_name VARCHAR(255),
    opponent_party VARCHAR(50),
    opponent_incumbent BOOLEAN,
    race_rating VARCHAR(50),  -- safe_r, likely_r, lean_r, toss_up, lean_d, etc.
    
    -- ==================== POLITICAL INFO (30 fields) ====================
    party VARCHAR(50) DEFAULT 'Republican',
    faction VARCHAR(50),
    faction_secondary VARCHAR(50),
    ideology_score INTEGER,  -- 0 (moderate) to 100 (very conservative)
    
    -- Endorsements
    trump_endorsed BOOLEAN DEFAULT false,
    trump_endorsed_date DATE,
    governor_endorsed BOOLEAN DEFAULT false,
    nra_grade VARCHAR(5),
    nra_endorsed BOOLEAN DEFAULT false,
    right_to_life_endorsed BOOLEAN DEFAULT false,
    chamber_endorsed BOOLEAN DEFAULT false,
    other_endorsements JSONB DEFAULT '[]',
    
    -- Committees
    committees JSONB DEFAULT '[]',
    committee_leadership JSONB DEFAULT '[]',
    caucus_memberships JSONB DEFAULT '[]',
    
    -- Voting Record
    lifetime_conservative_score INTEGER,
    current_session_score INTEGER,
    key_votes JSONB DEFAULT '[]',
    
    -- Legislative
    bills_sponsored INTEGER DEFAULT 0,
    bills_cosponsored INTEGER DEFAULT 0,
    bills_passed INTEGER DEFAULT 0,
    amendments_sponsored INTEGER DEFAULT 0,
    
    -- Ratings
    heritage_score INTEGER,
    aclu_score INTEGER,
    ntu_grade VARCHAR(5),
    
    -- ==================== CAMPAIGN INFO (35 fields) ====================
    campaign_name VARCHAR(255),
    campaign_slogan VARCHAR(500),
    campaign_theme VARCHAR(255),
    campaign_priorities JSONB DEFAULT '[]',
    
    -- Campaign Contact
    campaign_email VARCHAR(255),
    campaign_phone VARCHAR(20),
    campaign_address TEXT,
    campaign_city VARCHAR(100),
    campaign_state VARCHAR(2),
    campaign_zip VARCHAR(10),
    
    -- Online
    campaign_website VARCHAR(500),
    donation_url VARCHAR(500),
    volunteer_url VARCHAR(500),
    merchandise_url VARCHAR(500),
    
    -- Social Media
    facebook_url VARCHAR(500),
    facebook_handle VARCHAR(100),
    twitter_url VARCHAR(500),
    twitter_handle VARCHAR(100),
    instagram_url VARCHAR(500),
    instagram_handle VARCHAR(100),
    youtube_url VARCHAR(500),
    youtube_handle VARCHAR(100),
    tiktok_url VARCHAR(500),
    tiktok_handle VARCHAR(100),
    linkedin_url VARCHAR(500),
    truth_social_url VARCHAR(500),
    rumble_url VARCHAR(500),
    gettr_url VARCHAR(500),
    parler_url VARCHAR(500),
    gab_url VARCHAR(500),
    
    -- Staff
    campaign_manager VARCHAR(255),
    campaign_manager_email VARCHAR(255),
    campaign_manager_phone VARCHAR(20),
    finance_director VARCHAR(255),
    communications_director VARCHAR(255),
    field_director VARCHAR(255),
    digital_director VARCHAR(255),
    treasurer VARCHAR(255),
    
    -- ==================== FINANCE INFO (25 fields) ====================
    fec_candidate_id VARCHAR(50),
    fec_committee_id VARCHAR(50),
    state_committee_id VARCHAR(50),
    
    -- Fundraising
    raised_total DECIMAL(14,2) DEFAULT 0,
    raised_this_cycle DECIMAL(14,2) DEFAULT 0,
    raised_this_quarter DECIMAL(14,2) DEFAULT 0,
    raised_this_month DECIMAL(14,2) DEFAULT 0,
    
    cash_on_hand DECIMAL(14,2) DEFAULT 0,
    debt_total DECIMAL(14,2) DEFAULT 0,
    
    -- Spending
    spent_total DECIMAL(14,2) DEFAULT 0,
    spent_this_cycle DECIMAL(14,2) DEFAULT 0,
    spent_this_quarter DECIMAL(14,2) DEFAULT 0,
    
    -- Donors
    donor_count INTEGER DEFAULT 0,
    avg_donation DECIMAL(10,2) DEFAULT 0,
    small_dollar_pct DECIMAL(5,2) DEFAULT 0,  -- % under $200
    
    -- PAC Support
    pac_support_total DECIMAL(14,2) DEFAULT 0,
    pac_opposition_total DECIMAL(14,2) DEFAULT 0,
    super_pac_support JSONB DEFAULT '[]',
    
    -- Self-funding
    self_funded_amount DECIMAL(14,2) DEFAULT 0,
    personal_loan_amount DECIMAL(14,2) DEFAULT 0,
    
    -- ==================== BIOGRAPHY (30 fields) ====================
    biography TEXT,
    biography_short VARCHAR(500),
    tagline VARCHAR(255),
    
    -- Birth/Origin
    birth_city VARCHAR(100),
    birth_state VARCHAR(2),
    birth_country VARCHAR(50) DEFAULT 'USA',
    hometown VARCHAR(100),
    years_in_district INTEGER,
    
    -- Family
    marital_status VARCHAR(50),
    spouse_name VARCHAR(255),
    spouse_occupation VARCHAR(255),
    children_count INTEGER,
    children_names JSONB DEFAULT '[]',
    grandchildren_count INTEGER,
    
    -- Education
    education JSONB DEFAULT '[]',
    highest_degree VARCHAR(100),
    alma_mater VARCHAR(255),
    
    -- Career
    occupation VARCHAR(255),
    employer VARCHAR(255),
    business_owner BOOLEAN DEFAULT false,
    business_name VARCHAR(255),
    business_type VARCHAR(100),
    career_history JSONB DEFAULT '[]',
    
    -- Military
    military_service BOOLEAN DEFAULT false,
    military_branch VARCHAR(100),
    military_rank VARCHAR(100),
    military_years VARCHAR(50),
    military_awards JSONB DEFAULT '[]',
    veteran BOOLEAN DEFAULT false,
    
    -- Faith
    religion VARCHAR(100),
    church_name VARCHAR(255),
    church_city VARCHAR(100),
    
    -- ==================== ISSUE POSITIONS (60 fields - stored as JSONB) ====================
    issue_positions JSONB DEFAULT '{}',
    priority_issues JSONB DEFAULT '[]',
    signature_issue VARCHAR(255),
    
    -- ==================== MEDIA (20 fields) ====================
    headshot_url TEXT,
    headshot_formal_url TEXT,
    headshot_casual_url TEXT,
    family_photo_url TEXT,
    action_photo_url TEXT,
    logo_url TEXT,
    logo_dark_url TEXT,
    banner_url TEXT,
    
    -- Video
    intro_video_url TEXT,
    campaign_video_url TEXT,
    
    -- Voice
    voice_sample_url TEXT,
    voice_profile_id VARCHAR(100),
    
    -- Press
    press_kit_url TEXT,
    press_release_latest TEXT,
    
    -- Media appearances
    media_appearances JSONB DEFAULT '[]',
    
    -- Colors/Branding
    brand_primary_color VARCHAR(7),
    brand_secondary_color VARCHAR(7),
    brand_font VARCHAR(100),
    
    -- ==================== AI CONTEXT (15 fields) ====================
    ai_context TEXT,
    ai_voice_description TEXT,
    ai_messaging_tone VARCHAR(50),
    ai_topics_avoid JSONB DEFAULT '[]',
    ai_key_phrases JSONB DEFAULT '[]',
    ai_opponents_attack_lines JSONB DEFAULT '[]',
    ai_defense_points JSONB DEFAULT '[]',
    ai_accomplishments JSONB DEFAULT '[]',
    ai_future_vision TEXT,
    ai_call_to_action VARCHAR(500),
    ai_donation_ask VARCHAR(500),
    ai_volunteer_ask VARCHAR(500),
    ai_vote_ask VARCHAR(500),
    ai_last_updated TIMESTAMP,
    ai_generated_bio TEXT,
    
    -- ==================== DISTRICT INFO (20 fields) ====================
    district_population INTEGER,
    district_registered_voters INTEGER,
    district_republican_pct DECIMAL(5,2),
    district_democrat_pct DECIMAL(5,2),
    district_independent_pct DECIMAL(5,2),
    district_median_income INTEGER,
    district_median_age DECIMAL(4,1),
    district_urban_pct DECIMAL(5,2),
    district_suburban_pct DECIMAL(5,2),
    district_rural_pct DECIMAL(5,2),
    district_white_pct DECIMAL(5,2),
    district_black_pct DECIMAL(5,2),
    district_hispanic_pct DECIMAL(5,2),
    district_asian_pct DECIMAL(5,2),
    district_college_pct DECIMAL(5,2),
    district_trump_2020_pct DECIMAL(5,2),
    district_trump_2016_pct DECIMAL(5,2),
    district_pvi VARCHAR(10),  -- R+5, D+2, EVEN, etc.
    district_top_issues JSONB DEFAULT '[]',
    district_counties JSONB DEFAULT '[]',
    
    -- ==================== LOCAL CANDIDATE FIELDS (15 fields) ====================
    local_churches JSONB DEFAULT '[]',
    local_schools JSONB DEFAULT '[]',
    local_civic_groups JSONB DEFAULT '[]',
    local_sports_leagues JSONB DEFAULT '[]',
    local_businesses_owned JSONB DEFAULT '[]',
    local_boards_served JSONB DEFAULT '[]',
    local_volunteer_history JSONB DEFAULT '[]',
    neighborhood VARCHAR(255),
    hoa_name VARCHAR(255),
    years_homeowner INTEGER,
    community_involvement TEXT,
    local_newspaper VARCHAR(255),
    local_radio_station VARCHAR(100),
    local_tv_station VARCHAR(100),
    local_issues JSONB DEFAULT '[]',
    
    -- ==================== METADATA (13 fields) ====================
    status VARCHAR(50) DEFAULT 'active',  -- active, withdrawn, suspended, lost, won
    profile_completeness INTEGER DEFAULT 0,  -- 0-100
    last_activity_date TIMESTAMP,
    data_source VARCHAR(100),
    data_quality_score INTEGER,
    verified BOOLEAN DEFAULT false,
    verified_by UUID,
    verified_at TIMESTAMP,
    notes TEXT,
    internal_notes TEXT,
    tags JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_candidates_name ON candidates(last_name, first_name);
CREATE INDEX IF NOT EXISTS idx_candidates_office ON candidates(office_type, office_level);
CREATE INDEX IF NOT EXISTS idx_candidates_state ON candidates(state);
CREATE INDEX IF NOT EXISTS idx_candidates_county ON candidates(county);
CREATE INDEX IF NOT EXISTS idx_candidates_district ON candidates(district_id);
CREATE INDEX IF NOT EXISTS idx_candidates_party ON candidates(party);
CREATE INDEX IF NOT EXISTS idx_candidates_faction ON candidates(faction);
CREATE INDEX IF NOT EXISTS idx_candidates_status ON candidates(status);
CREATE INDEX IF NOT EXISTS idx_candidates_election ON candidates(election_year, election_type);
CREATE INDEX IF NOT EXISTS idx_candidates_incumbent ON candidates(is_incumbent);
CREATE INDEX IF NOT EXISTS idx_candidates_trump ON candidates(trump_endorsed);

-- Endorsements Table
CREATE TABLE IF NOT EXISTS candidate_endorsements (
    endorsement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    endorser_type VARCHAR(50) NOT NULL,  -- person, organization, official
    endorser_name VARCHAR(255) NOT NULL,
    endorser_title VARCHAR(255),
    endorser_organization VARCHAR(255),
    endorsement_date DATE,
    endorsement_quote TEXT,
    endorsement_url TEXT,
    is_notable BOOLEAN DEFAULT false,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_endorsements_candidate ON candidate_endorsements(candidate_id);

-- Candidate Events
CREATE TABLE IF NOT EXISTS candidate_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    event_type VARCHAR(50) NOT NULL,
    event_name VARCHAR(255) NOT NULL,
    event_date DATE,
    event_time TIME,
    venue_name VARCHAR(255),
    venue_address TEXT,
    venue_city VARCHAR(100),
    is_public BOOLEAN DEFAULT true,
    rsvp_required BOOLEAN DEFAULT false,
    rsvp_url TEXT,
    expected_attendance INTEGER,
    actual_attendance INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_candidate_events_date ON candidate_events(event_date);

-- Candidate News Mentions
CREATE TABLE IF NOT EXISTS candidate_news (
    news_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    headline TEXT NOT NULL,
    source VARCHAR(255),
    source_type VARCHAR(50),  -- newspaper, tv, radio, online
    url TEXT,
    published_at TIMESTAMP,
    sentiment VARCHAR(20),  -- positive, negative, neutral
    is_opinion BOOLEAN DEFAULT false,
    summary TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_candidate_news_date ON candidate_news(published_at);

-- Candidate Polling
CREATE TABLE IF NOT EXISTS candidate_polling (
    poll_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    pollster VARCHAR(255),
    poll_date DATE,
    sample_size INTEGER,
    margin_of_error DECIMAL(4,2),
    candidate_pct DECIMAL(5,2),
    opponent_pct DECIMAL(5,2),
    undecided_pct DECIMAL(5,2),
    lead DECIMAL(5,2),
    methodology VARCHAR(100),
    url TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_candidate_polling_date ON candidate_polling(poll_date);

-- Office Type Reference
CREATE TABLE IF NOT EXISTS office_types (
    office_type_code VARCHAR(50) PRIMARY KEY,
    office_title VARCHAR(255) NOT NULL,
    office_level VARCHAR(20) NOT NULL,
    term_years INTEGER,
    description TEXT,
    requirements TEXT,
    salary_range VARCHAR(100),
    is_partisan BOOLEAN DEFAULT true,
    is_elected BOOLEAN DEFAULT true
);

-- Faction Reference
CREATE TABLE IF NOT EXISTS factions (
    faction_code VARCHAR(50) PRIMARY KEY,
    faction_name VARCHAR(255) NOT NULL,
    description TEXT,
    priority_issues JSONB DEFAULT '[]',
    key_figures JSONB DEFAULT '[]'
);

-- Issue Reference
CREATE TABLE IF NOT EXISTS issues (
    issue_code VARCHAR(100) PRIMARY KEY,
    issue_name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    description TEXT,
    republican_position TEXT,
    democrat_position TEXT,
    talking_points JSONB DEFAULT '[]'
);

-- Views
CREATE OR REPLACE VIEW v_candidate_summary AS
SELECT 
    c.candidate_id,
    c.first_name || ' ' || c.last_name as full_name,
    c.office_type,
    c.office_title,
    c.office_level,
    c.district_id,
    c.county,
    c.state,
    c.party,
    c.faction,
    c.is_incumbent,
    c.trump_endorsed,
    c.cash_on_hand,
    c.donor_count,
    c.profile_completeness,
    c.status
FROM candidates c
WHERE c.status = 'active';

CREATE OR REPLACE VIEW v_federal_candidates AS
SELECT * FROM candidates 
WHERE office_level = 'federal' AND status = 'active'
ORDER BY office_type, state, district_id;

CREATE OR REPLACE VIEW v_state_candidates AS
SELECT * FROM candidates 
WHERE office_level = 'state' AND status = 'active'
ORDER BY state, office_type, district_id;

CREATE OR REPLACE VIEW v_local_candidates AS
SELECT * FROM candidates 
WHERE office_level = 'local' AND status = 'active'
ORDER BY state, county, office_type;

SELECT 'Candidate Profiles schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_04_activist_network_complete.py (E04)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 4: ACTIVIST INTELLIGENCE NETWORK
-- ============================================================================

-- Organizations Reference
CREATE TABLE IF NOT EXISTS activist_organizations (
    org_code VARCHAR(50) PRIMARY KEY,
    org_name VARCHAR(255) NOT NULL,
    tier VARCHAR(20) NOT NULL,
    org_type VARCHAR(50),
    focus_areas JSONB DEFAULT '[]',
    fec_committee_id VARCHAR(50),
    state_committee_id VARCHAR(50),
    website VARCHAR(500),
    description TEXT,
    grade_multiplier DECIMAL(4,2) DEFAULT 1.0,
    show_rate_boost DECIMAL(4,2) DEFAULT 0.0,
    member_count INTEGER,
    is_active BOOLEAN DEFAULT true,
    last_synced TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orgs_tier ON activist_organizations(tier);

-- Donor/Activist Memberships
CREATE TABLE IF NOT EXISTS activist_memberships (
    membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    org_code VARCHAR(50) REFERENCES activist_organizations(org_code),
    
    -- Membership details
    is_active BOOLEAN DEFAULT true,
    is_leadership BOOLEAN DEFAULT false,
    leadership_title VARCHAR(255),
    member_since DATE,
    membership_level VARCHAR(50),  -- basic, premium, lifetime
    
    -- Contribution history
    total_contributed DECIMAL(12,2) DEFAULT 0,
    last_contribution_date DATE,
    contribution_count INTEGER DEFAULT 0,
    
    -- Engagement
    events_attended INTEGER DEFAULT 0,
    last_event_date DATE,
    volunteer_hours INTEGER DEFAULT 0,
    
    -- Verification
    verified BOOLEAN DEFAULT false,
    verified_source VARCHAR(100),  -- fec, state, manual, api
    verified_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, org_code)
);

CREATE INDEX IF NOT EXISTS idx_memberships_donor ON activist_memberships(donor_id);
CREATE INDEX IF NOT EXISTS idx_memberships_org ON activist_memberships(org_code);
CREATE INDEX IF NOT EXISTS idx_memberships_leadership ON activist_memberships(is_leadership);

-- Activist Scores (aggregate per donor)
CREATE TABLE IF NOT EXISTS activist_scores (
    score_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL UNIQUE,
    
    -- Score components
    intensity_score INTEGER CHECK (intensity_score BETWEEN 1 AND 10),
    intensity_label VARCHAR(50),
    
    -- Organization counts
    total_orgs INTEGER DEFAULT 0,
    tier_1_orgs INTEGER DEFAULT 0,
    tier_2_orgs INTEGER DEFAULT 0,
    tier_3_orgs INTEGER DEFAULT 0,
    tier_4_orgs INTEGER DEFAULT 0,
    
    -- Leadership
    leadership_positions INTEGER DEFAULT 0,
    top_leadership_org VARCHAR(50),
    
    -- Multipliers
    grade_multiplier DECIMAL(4,2) DEFAULT 1.0,
    predicted_show_rate DECIMAL(4,2),
    network_influence_score INTEGER DEFAULT 0,
    
    -- Activity
    total_contributions DECIMAL(14,2) DEFAULT 0,
    total_events_attended INTEGER DEFAULT 0,
    total_volunteer_hours INTEGER DEFAULT 0,
    
    -- Top organizations
    primary_org VARCHAR(50),
    secondary_org VARCHAR(50),
    org_list JSONB DEFAULT '[]',
    
    -- Interests derived from orgs
    focus_areas JSONB DEFAULT '[]',
    
    calculated_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activist_scores_intensity ON activist_scores(intensity_score DESC);
CREATE INDEX IF NOT EXISTS idx_activist_scores_multiplier ON activist_scores(grade_multiplier DESC);

-- Network Connections (who knows who)
CREATE TABLE IF NOT EXISTS activist_network (
    connection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id_1 UUID NOT NULL,
    donor_id_2 UUID NOT NULL,
    
    -- Connection type
    connection_type VARCHAR(50) NOT NULL,  -- same_org, referred, attended_together, etc.
    connection_strength DECIMAL(4,2) DEFAULT 1.0,  -- 0-10 scale
    
    -- Details
    shared_orgs JSONB DEFAULT '[]',
    shared_events JSONB DEFAULT '[]',
    
    -- Referral
    referral_direction VARCHAR(10),  -- 1_to_2, 2_to_1, mutual
    referral_date DATE,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_network_donor1 ON activist_network(donor_id_1);
CREATE INDEX IF NOT EXISTS idx_network_donor2 ON activist_network(donor_id_2);

-- Show Rate Tracking
CREATE TABLE IF NOT EXISTS activist_show_rates (
    tracking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    
    -- Historical performance
    events_scheduled INTEGER DEFAULT 0,
    events_attended INTEGER DEFAULT 0,
    events_cancelled INTEGER DEFAULT 0,
    events_no_show INTEGER DEFAULT 0,
    
    -- Calculated rates
    historical_show_rate DECIMAL(4,2),
    predicted_show_rate DECIMAL(4,2),
    reliability_class VARCHAR(20),  -- highly_reliable, reliable, moderate, unreliable
    
    -- By event type
    rally_show_rate DECIMAL(4,2),
    canvass_show_rate DECIMAL(4,2),
    phone_bank_show_rate DECIMAL(4,2),
    
    -- Last activity
    last_scheduled DATE,
    last_attended DATE,
    
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_show_rates_donor ON activist_show_rates(donor_id);

-- PAC Contribution Tracking (FEC data)
CREATE TABLE IF NOT EXISTS pac_contributions (
    contribution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Donor info
    donor_id UUID,
    contributor_name VARCHAR(255),
    contributor_address TEXT,
    contributor_city VARCHAR(100),
    contributor_state VARCHAR(2),
    contributor_zip VARCHAR(10),
    contributor_employer VARCHAR(255),
    contributor_occupation VARCHAR(255),
    
    -- PAC info
    org_code VARCHAR(50),
    committee_id VARCHAR(50),
    committee_name VARCHAR(255),
    
    -- Contribution
    amount DECIMAL(12,2) NOT NULL,
    contribution_date DATE,
    contribution_type VARCHAR(50),
    
    -- FEC data
    fec_transaction_id VARCHAR(50),
    fec_report_type VARCHAR(20),
    fec_image_num VARCHAR(50),
    
    -- Processing
    matched_to_donor BOOLEAN DEFAULT false,
    match_confidence DECIMAL(4,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pac_contribs_donor ON pac_contributions(donor_id);
CREATE INDEX IF NOT EXISTS idx_pac_contribs_date ON pac_contributions(contribution_date);
CREATE INDEX IF NOT EXISTS idx_pac_contribs_org ON pac_contributions(org_code);

-- Event Attendance Tracking
CREATE TABLE IF NOT EXISTS activist_event_attendance (
    attendance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    event_id UUID,
    org_code VARCHAR(50),
    
    -- Event details
    event_name VARCHAR(255),
    event_type VARCHAR(50),
    event_date DATE,
    
    -- Attendance
    rsvp_status VARCHAR(20),  -- yes, no, maybe
    attended BOOLEAN,
    checked_in_at TIMESTAMP,
    
    -- Brought guests
    guests_count INTEGER DEFAULT 0,
    guests_converted INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_attendance_donor ON activist_event_attendance(donor_id);
CREATE INDEX IF NOT EXISTS idx_event_attendance_date ON activist_event_attendance(event_date);

-- Views
CREATE OR REPLACE VIEW v_activist_summary AS
SELECT 
    a.donor_id,
    a.intensity_score,
    a.intensity_label,
    a.total_orgs,
    a.tier_1_orgs,
    a.leadership_positions,
    a.grade_multiplier,
    a.predicted_show_rate,
    a.primary_org,
    o.org_name as primary_org_name,
    a.focus_areas,
    s.historical_show_rate,
    s.reliability_class
FROM activist_scores a
LEFT JOIN activist_organizations o ON a.primary_org = o.org_code
LEFT JOIN activist_show_rates s ON a.donor_id = s.donor_id
ORDER BY a.intensity_score DESC;

CREATE OR REPLACE VIEW v_elite_activists AS
SELECT 
    a.donor_id,
    a.intensity_score,
    a.intensity_label,
    a.total_orgs,
    a.tier_1_orgs,
    a.leadership_positions,
    a.grade_multiplier,
    a.predicted_show_rate,
    a.org_list
FROM activist_scores a
WHERE a.intensity_score >= 7
ORDER BY a.intensity_score DESC, a.leadership_positions DESC;

CREATE OR REPLACE VIEW v_org_membership_stats AS
SELECT 
    o.org_code,
    o.org_name,
    o.tier,
    COUNT(m.membership_id) as member_count,
    COUNT(CASE WHEN m.is_leadership THEN 1 END) as leadership_count,
    SUM(m.total_contributed) as total_contributions,
    AVG(a.intensity_score) as avg_member_intensity
FROM activist_organizations o
LEFT JOIN activist_memberships m ON o.org_code = m.org_code AND m.is_active
LEFT JOIN activist_scores a ON m.donor_id = a.donor_id
GROUP BY o.org_code, o.org_name, o.tier
ORDER BY o.tier, member_count DESC;

SELECT 'Activist Network schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_05_volunteer_management_complete.py (E05)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 5: VOLUNTEER MANAGEMENT SYSTEM
-- ============================================================================

-- Volunteers Table
CREATE TABLE IF NOT EXISTS volunteers (
    volunteer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID,  -- Link to donor if also a donor
    
    -- Basic Info
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    mobile VARCHAR(20),
    
    -- Address
    address_line1 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),
    county VARCHAR(100),
    
    -- Availability
    available_weekday_morning BOOLEAN DEFAULT false,
    available_weekday_afternoon BOOLEAN DEFAULT false,
    available_weekday_evening BOOLEAN DEFAULT false,
    available_weekend_morning BOOLEAN DEFAULT false,
    available_weekend_afternoon BOOLEAN DEFAULT false,
    available_weekend_evening BOOLEAN DEFAULT false,
    availability_notes TEXT,
    
    -- Skills
    skills JSONB DEFAULT '[]',
    primary_skill VARCHAR(50),
    skill_multiplier DECIMAL(4,2) DEFAULT 1.0,
    
    -- Interests
    interests JSONB DEFAULT '[]',
    preferred_activities JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(50) DEFAULT 'active',  -- active, inactive, suspended, blacklisted
    grade VARCHAR(10) DEFAULT 'V-F',
    grade_updated_at TIMESTAMP,
    
    -- Stats
    total_hours DECIMAL(10,2) DEFAULT 0,
    total_shifts INTEGER DEFAULT 0,
    completed_shifts INTEGER DEFAULT 0,
    no_show_count INTEGER DEFAULT 0,
    show_rate DECIMAL(5,4),
    reliability_class VARCHAR(20),
    
    -- Value
    value_score DECIMAL(10,2) DEFAULT 0,
    
    -- Activist integration
    activist_intensity INTEGER,
    activist_multiplier DECIMAL(4,2) DEFAULT 1.0,
    
    -- Team
    team_id UUID,
    zone_id VARCHAR(50),
    precinct VARCHAR(50),
    
    -- Referrals
    referred_by UUID,
    referrals_made INTEGER DEFAULT 0,
    
    -- Metadata
    joined_date DATE DEFAULT CURRENT_DATE,
    last_activity_date DATE,
    notes TEXT,
    tags JSONB DEFAULT '[]',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_volunteers_email ON volunteers(email);
CREATE INDEX IF NOT EXISTS idx_volunteers_phone ON volunteers(phone);
CREATE INDEX IF NOT EXISTS idx_volunteers_grade ON volunteers(grade);
CREATE INDEX IF NOT EXISTS idx_volunteers_status ON volunteers(status);
CREATE INDEX IF NOT EXISTS idx_volunteers_donor ON volunteers(donor_id);
CREATE INDEX IF NOT EXISTS idx_volunteers_team ON volunteers(team_id);

-- Shifts Table
CREATE TABLE IF NOT EXISTS volunteer_shifts (
    shift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Shift details
    shift_name VARCHAR(255),
    activity_code VARCHAR(50) NOT NULL,
    activity_name VARCHAR(255),
    
    -- Time
    shift_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    duration_hours DECIMAL(4,2),
    
    -- Location
    location_name VARCHAR(255),
    location_address TEXT,
    location_city VARCHAR(100),
    is_remote BOOLEAN DEFAULT false,
    
    -- Capacity
    slots_total INTEGER DEFAULT 1,
    slots_filled INTEGER DEFAULT 0,
    slots_available INTEGER GENERATED ALWAYS AS (slots_total - slots_filled) STORED,
    
    -- Assignment
    candidate_id UUID,
    campaign_id UUID,
    event_id UUID,
    
    -- Team
    team_id UUID,
    zone_id VARCHAR(50),
    shift_captain_id UUID,
    
    -- Status
    status VARCHAR(50) DEFAULT 'open',  -- open, full, completed, cancelled
    
    -- Metadata
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shifts_date ON volunteer_shifts(shift_date);
CREATE INDEX IF NOT EXISTS idx_shifts_activity ON volunteer_shifts(activity_code);
CREATE INDEX IF NOT EXISTS idx_shifts_status ON volunteer_shifts(status);
CREATE INDEX IF NOT EXISTS idx_shifts_campaign ON volunteer_shifts(campaign_id);

-- Shift Assignments
CREATE TABLE IF NOT EXISTS shift_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id UUID REFERENCES volunteer_shifts(shift_id),
    volunteer_id UUID REFERENCES volunteers(volunteer_id),
    
    -- Status
    status VARCHAR(50) DEFAULT 'assigned',  -- assigned, confirmed, completed, no_show, cancelled
    
    -- Time tracking
    scheduled_hours DECIMAL(4,2),
    actual_hours DECIMAL(4,2),
    check_in_time TIMESTAMP,
    check_out_time TIMESTAMP,
    
    -- Performance
    doors_knocked INTEGER,
    calls_made INTEGER,
    contacts_made INTEGER,
    pledges_collected INTEGER,
    
    -- Notes
    notes TEXT,
    supervisor_notes TEXT,
    
    -- Value
    value_earned DECIMAL(6,2),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(shift_id, volunteer_id)
);

CREATE INDEX IF NOT EXISTS idx_assignments_shift ON shift_assignments(shift_id);
CREATE INDEX IF NOT EXISTS idx_assignments_volunteer ON shift_assignments(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_assignments_status ON shift_assignments(status);

-- Volunteer Teams
CREATE TABLE IF NOT EXISTS volunteer_teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    team_name VARCHAR(255) NOT NULL,
    team_type VARCHAR(50),  -- canvass, phone, event, elite
    
    -- Leadership
    team_leader_id UUID REFERENCES volunteers(volunteer_id),
    
    -- Scope
    candidate_id UUID,
    zone_id VARCHAR(50),
    focus_activity VARCHAR(50),
    
    -- Stats
    member_count INTEGER DEFAULT 0,
    total_hours DECIMAL(10,2) DEFAULT 0,
    avg_show_rate DECIMAL(5,4),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_teams_leader ON volunteer_teams(team_leader_id);

-- Team Memberships
CREATE TABLE IF NOT EXISTS team_memberships (
    membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES volunteer_teams(team_id),
    volunteer_id UUID REFERENCES volunteers(volunteer_id),
    
    role VARCHAR(50) DEFAULT 'member',  -- member, co-leader, leader
    joined_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(team_id, volunteer_id)
);

-- Volunteer Hours Log
CREATE TABLE IF NOT EXISTS volunteer_hours (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID REFERENCES volunteers(volunteer_id),
    
    -- Time
    log_date DATE NOT NULL,
    hours DECIMAL(4,2) NOT NULL,
    
    -- Activity
    activity_code VARCHAR(50),
    activity_name VARCHAR(255),
    
    -- Source
    shift_id UUID,
    manual_entry BOOLEAN DEFAULT false,
    
    -- Value
    base_value DECIMAL(6,2),
    multiplied_value DECIMAL(6,2),
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hours_volunteer ON volunteer_hours(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_hours_date ON volunteer_hours(log_date);

-- Badges Earned
CREATE TABLE IF NOT EXISTS volunteer_badges (
    badge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID REFERENCES volunteers(volunteer_id),
    badge_code VARCHAR(50) NOT NULL,
    badge_name VARCHAR(100),
    earned_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(volunteer_id, badge_code)
);

CREATE INDEX IF NOT EXISTS idx_badges_volunteer ON volunteer_badges(volunteer_id);

-- Leaderboards (cached)
CREATE TABLE IF NOT EXISTS volunteer_leaderboards (
    leaderboard_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Scope
    period VARCHAR(20) NOT NULL,  -- weekly, monthly, quarterly, all_time
    period_start DATE,
    period_end DATE,
    
    -- Category
    category VARCHAR(50) NOT NULL,  -- hours, shifts, doors, calls, value
    
    -- Rankings (JSONB array of {volunteer_id, rank, value})
    rankings JSONB DEFAULT '[]',
    
    generated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leaderboards_period ON volunteer_leaderboards(period, category);

-- Referrals
CREATE TABLE IF NOT EXISTS volunteer_referrals (
    referral_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID REFERENCES volunteers(volunteer_id),
    referred_id UUID REFERENCES volunteers(volunteer_id),
    
    referred_at TIMESTAMP DEFAULT NOW(),
    converted BOOLEAN DEFAULT false,
    converted_at TIMESTAMP,
    
    bonus_awarded BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON volunteer_referrals(referrer_id);

-- Views
CREATE OR REPLACE VIEW v_volunteer_summary AS
SELECT 
    v.volunteer_id,
    v.first_name || ' ' || v.last_name as full_name,
    v.email,
    v.grade,
    v.total_hours,
    v.total_shifts,
    v.completed_shifts,
    v.show_rate,
    v.reliability_class,
    v.value_score,
    v.activist_intensity,
    v.team_id,
    t.team_name,
    v.status,
    v.last_activity_date
FROM volunteers v
LEFT JOIN volunteer_teams t ON v.team_id = t.team_id
WHERE v.status = 'active';

CREATE OR REPLACE VIEW v_shift_availability AS
SELECT 
    s.shift_id,
    s.shift_name,
    s.activity_name,
    s.shift_date,
    s.start_time,
    s.end_time,
    s.location_name,
    s.slots_total,
    s.slots_filled,
    s.slots_available,
    s.status
FROM volunteer_shifts s
WHERE s.status = 'open' AND s.shift_date >= CURRENT_DATE
ORDER BY s.shift_date, s.start_time;

CREATE OR REPLACE VIEW v_top_volunteers AS
SELECT 
    v.volunteer_id,
    v.first_name || ' ' || v.last_name as full_name,
    v.grade,
    v.total_hours,
    v.show_rate,
    v.value_score,
    COUNT(DISTINCT b.badge_code) as badge_count
FROM volunteers v
LEFT JOIN volunteer_badges b ON v.volunteer_id = b.volunteer_id
WHERE v.status = 'active' AND v.total_hours > 0
GROUP BY v.volunteer_id, v.first_name, v.last_name, v.grade, 
         v.total_hours, v.show_rate, v.value_score
ORDER BY v.value_score DESC
LIMIT 100;

SELECT 'Volunteer Management schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_06_analytics_engine_complete.py (E06)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 6: ANALYTICS ENGINE
-- ============================================================================

-- Campaign Performance Metrics (aggregated)
CREATE TABLE IF NOT EXISTS campaign_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL,
    candidate_id UUID,
    
    -- Campaign Info
    campaign_name VARCHAR(255),
    campaign_type VARCHAR(50),
    channel VARCHAR(50),
    
    -- Date Range
    start_date DATE,
    end_date DATE,
    metric_date DATE NOT NULL,  -- Date of this metric record
    
    -- Reach Metrics
    total_recipients INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    
    -- Engagement Metrics
    opens INTEGER DEFAULT 0,
    unique_opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    unique_clicks INTEGER DEFAULT 0,
    replies INTEGER DEFAULT 0,
    forwards INTEGER DEFAULT 0,
    
    -- Negative Metrics
    bounces INTEGER DEFAULT 0,
    unsubscribes INTEGER DEFAULT 0,
    complaints INTEGER DEFAULT 0,
    
    -- Conversion Metrics
    conversions INTEGER DEFAULT 0,
    conversion_value DECIMAL(14,2) DEFAULT 0,
    donations INTEGER DEFAULT 0,
    donation_amount DECIMAL(14,2) DEFAULT 0,
    
    -- Financial Metrics
    cost DECIMAL(12,2) DEFAULT 0,
    revenue DECIMAL(14,2) DEFAULT 0,
    profit DECIMAL(14,2) DEFAULT 0,
    
    -- Calculated Rates (stored for performance)
    delivery_rate DECIMAL(6,4),
    open_rate DECIMAL(6,4),
    click_rate DECIMAL(6,4),
    click_to_open_rate DECIMAL(6,4),
    conversion_rate DECIMAL(6,4),
    roi DECIMAL(10,2),
    cost_per_conversion DECIMAL(10,2),
    cost_per_click DECIMAL(10,2),
    revenue_per_recipient DECIMAL(10,4),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_campaign_metrics_campaign ON campaign_metrics(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_metrics_date ON campaign_metrics(metric_date);
CREATE INDEX IF NOT EXISTS idx_campaign_metrics_channel ON campaign_metrics(channel);
CREATE INDEX IF NOT EXISTS idx_campaign_metrics_candidate ON campaign_metrics(candidate_id);

-- Daily Summary Metrics
CREATE TABLE IF NOT EXISTS daily_metrics (
    date DATE PRIMARY KEY,
    candidate_id UUID,
    
    -- Communications Sent
    emails_sent INTEGER DEFAULT 0,
    sms_sent INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    mail_pieces_sent INTEGER DEFAULT 0,
    
    -- Engagement
    email_opens INTEGER DEFAULT 0,
    email_clicks INTEGER DEFAULT 0,
    sms_replies INTEGER DEFAULT 0,
    call_connects INTEGER DEFAULT 0,
    
    -- Donations
    donations_count INTEGER DEFAULT 0,
    donations_amount DECIMAL(14,2) DEFAULT 0,
    unique_donors INTEGER DEFAULT 0,
    new_donors INTEGER DEFAULT 0,
    recurring_donations INTEGER DEFAULT 0,
    
    -- Volunteer
    volunteer_hours DECIMAL(10,2) DEFAULT 0,
    volunteer_shifts INTEGER DEFAULT 0,
    events_held INTEGER DEFAULT 0,
    event_attendees INTEGER DEFAULT 0,
    
    -- Costs
    total_cost DECIMAL(12,2) DEFAULT 0,
    email_cost DECIMAL(10,2) DEFAULT 0,
    sms_cost DECIMAL(10,2) DEFAULT 0,
    call_cost DECIMAL(10,2) DEFAULT 0,
    mail_cost DECIMAL(10,2) DEFAULT 0,
    ad_cost DECIMAL(10,2) DEFAULT 0,
    
    -- Scores
    avg_donor_score DECIMAL(6,2),
    
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_daily_metrics_candidate ON daily_metrics(candidate_id);

-- Channel Performance
CREATE TABLE IF NOT EXISTS channel_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    channel VARCHAR(50) NOT NULL,
    period VARCHAR(20) NOT NULL,  -- daily, weekly, monthly, quarterly
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Volume
    campaigns_count INTEGER DEFAULT 0,
    messages_sent INTEGER DEFAULT 0,
    
    -- Engagement
    total_opens INTEGER DEFAULT 0,
    total_clicks INTEGER DEFAULT 0,
    total_responses INTEGER DEFAULT 0,
    
    -- Conversion
    total_conversions INTEGER DEFAULT 0,
    total_revenue DECIMAL(14,2) DEFAULT 0,
    
    -- Cost
    total_cost DECIMAL(12,2) DEFAULT 0,
    
    -- Rates
    avg_open_rate DECIMAL(6,4),
    avg_click_rate DECIMAL(6,4),
    avg_conversion_rate DECIMAL(6,4),
    avg_roi DECIMAL(10,2),
    
    -- Benchmarks
    vs_benchmark_open DECIMAL(6,4),
    vs_benchmark_click DECIMAL(6,4),
    vs_benchmark_conversion DECIMAL(6,4),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_channel_metrics_channel ON channel_metrics(channel);
CREATE INDEX IF NOT EXISTS idx_channel_metrics_period ON channel_metrics(period_start);
CREATE UNIQUE INDEX IF NOT EXISTS idx_channel_metrics_unique ON channel_metrics(candidate_id, channel, period, period_start);

-- Conversion Funnels
CREATE TABLE IF NOT EXISTS funnel_metrics (
    funnel_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    funnel_name VARCHAR(255) NOT NULL,
    campaign_id UUID,
    
    -- Stages
    stage_1_name VARCHAR(100),
    stage_1_count INTEGER DEFAULT 0,
    stage_2_name VARCHAR(100),
    stage_2_count INTEGER DEFAULT 0,
    stage_3_name VARCHAR(100),
    stage_3_count INTEGER DEFAULT 0,
    stage_4_name VARCHAR(100),
    stage_4_count INTEGER DEFAULT 0,
    stage_5_name VARCHAR(100),
    stage_5_count INTEGER DEFAULT 0,
    
    -- Conversion rates between stages
    stage_1_to_2_rate DECIMAL(6,4),
    stage_2_to_3_rate DECIMAL(6,4),
    stage_3_to_4_rate DECIMAL(6,4),
    stage_4_to_5_rate DECIMAL(6,4),
    
    -- Overall
    overall_conversion_rate DECIMAL(6,4),
    avg_time_to_convert INTERVAL,
    
    period_start DATE,
    period_end DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_funnel_campaign ON funnel_metrics(campaign_id);

-- Attribution Tracking
CREATE TABLE IF NOT EXISTS attribution_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    conversion_id UUID,  -- donation_id or action_id
    conversion_type VARCHAR(50),  -- donation, signup, rsvp
    conversion_value DECIMAL(12,2),
    conversion_date TIMESTAMP,
    
    -- Attribution
    attribution_model VARCHAR(50) DEFAULT 'last_touch',  -- first_touch, last_touch, linear, time_decay
    
    -- Touchpoints (JSON array of {channel, campaign_id, timestamp, weight})
    touchpoints JSONB DEFAULT '[]',
    touchpoint_count INTEGER DEFAULT 0,
    
    -- First/Last touch
    first_touch_channel VARCHAR(50),
    first_touch_campaign UUID,
    first_touch_date TIMESTAMP,
    last_touch_channel VARCHAR(50),
    last_touch_campaign UUID,
    last_touch_date TIMESTAMP,
    
    -- Time to convert
    days_to_convert INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_attribution_donor ON attribution_events(donor_id);
CREATE INDEX IF NOT EXISTS idx_attribution_conversion ON attribution_events(conversion_id);

-- Cohort Analysis
CREATE TABLE IF NOT EXISTS cohort_metrics (
    cohort_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    cohort_name VARCHAR(255),
    cohort_definition JSONB,  -- Rules that define the cohort
    
    -- Cohort date (when donors entered)
    cohort_month DATE NOT NULL,
    
    -- Size
    cohort_size INTEGER DEFAULT 0,
    
    -- Retention by period (months since cohort start)
    month_0_active INTEGER DEFAULT 0,
    month_1_active INTEGER DEFAULT 0,
    month_2_active INTEGER DEFAULT 0,
    month_3_active INTEGER DEFAULT 0,
    month_6_active INTEGER DEFAULT 0,
    month_12_active INTEGER DEFAULT 0,
    
    -- Value by period
    month_0_value DECIMAL(14,2) DEFAULT 0,
    month_1_value DECIMAL(14,2) DEFAULT 0,
    month_2_value DECIMAL(14,2) DEFAULT 0,
    month_3_value DECIMAL(14,2) DEFAULT 0,
    month_6_value DECIMAL(14,2) DEFAULT 0,
    month_12_value DECIMAL(14,2) DEFAULT 0,
    
    -- Retention rates
    month_1_retention DECIMAL(6,4),
    month_3_retention DECIMAL(6,4),
    month_6_retention DECIMAL(6,4),
    month_12_retention DECIMAL(6,4),
    
    -- Lifetime value
    avg_ltv DECIMAL(12,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cohort_month ON cohort_metrics(cohort_month);

-- Custom Reports
CREATE TABLE IF NOT EXISTS saved_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    user_id UUID,
    
    -- Report definition
    report_name VARCHAR(255) NOT NULL,
    report_type VARCHAR(50) NOT NULL,
    description TEXT,
    
    -- Configuration
    metrics JSONB DEFAULT '[]',  -- List of metrics to include
    dimensions JSONB DEFAULT '[]',  -- Group by dimensions
    filters JSONB DEFAULT '{}',  -- Filter conditions
    date_range JSONB,  -- Date range config
    
    -- Display
    chart_type VARCHAR(50),  -- bar, line, pie, table
    visualization_config JSONB,
    
    -- Scheduling
    is_scheduled BOOLEAN DEFAULT false,
    schedule_frequency VARCHAR(20),  -- daily, weekly, monthly
    schedule_day INTEGER,
    last_run_at TIMESTAMP,
    next_run_at TIMESTAMP,
    
    -- Delivery
    email_recipients JSONB DEFAULT '[]',
    
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_reports_candidate ON saved_reports(candidate_id);
CREATE INDEX IF NOT EXISTS idx_saved_reports_scheduled ON saved_reports(is_scheduled, next_run_at);

-- Report Results Cache
CREATE TABLE IF NOT EXISTS report_cache (
    cache_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID REFERENCES saved_reports(report_id),
    
    -- Cache key
    cache_key VARCHAR(255) NOT NULL,
    
    -- Results
    result_data JSONB NOT NULL,
    row_count INTEGER,
    
    -- Validity
    generated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    
    UNIQUE(report_id, cache_key)
);

CREATE INDEX IF NOT EXISTS idx_report_cache_expires ON report_cache(expires_at);

-- Benchmarks
CREATE TABLE IF NOT EXISTS industry_benchmarks (
    benchmark_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Scope
    channel VARCHAR(50) NOT NULL,
    campaign_type VARCHAR(50),
    race_type VARCHAR(50),  -- federal, state, local
    
    -- Metrics
    avg_open_rate DECIMAL(6,4),
    avg_click_rate DECIMAL(6,4),
    avg_conversion_rate DECIMAL(6,4),
    avg_roi DECIMAL(10,2),
    avg_cost_per_acquisition DECIMAL(10,2),
    
    -- Percentiles
    p25_open_rate DECIMAL(6,4),
    p50_open_rate DECIMAL(6,4),
    p75_open_rate DECIMAL(6,4),
    
    -- Source
    data_source VARCHAR(255),
    sample_size INTEGER,
    period VARCHAR(20),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_benchmarks_channel ON industry_benchmarks(channel);

-- Real-time Dashboard Metrics
CREATE TABLE IF NOT EXISTS realtime_metrics (
    metric_key VARCHAR(100) PRIMARY KEY,
    candidate_id UUID,
    
    metric_value DECIMAL(14,4),
    metric_type VARCHAR(20),  -- count, sum, rate, currency
    
    -- Time window
    window_start TIMESTAMP,
    window_end TIMESTAMP,
    
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_campaign_performance AS
SELECT 
    cm.campaign_id,
    cm.campaign_name,
    cm.channel,
    cm.candidate_id,
    SUM(cm.sent_count) as total_sent,
    SUM(cm.delivered_count) as total_delivered,
    SUM(cm.opens) as total_opens,
    SUM(cm.clicks) as total_clicks,
    SUM(cm.conversions) as total_conversions,
    SUM(cm.revenue) as total_revenue,
    SUM(cm.cost) as total_cost,
    SUM(cm.profit) as total_profit,
    CASE WHEN SUM(cm.sent_count) > 0 
         THEN SUM(cm.delivered_count)::DECIMAL / SUM(cm.sent_count) 
         ELSE 0 END as delivery_rate,
    CASE WHEN SUM(cm.delivered_count) > 0 
         THEN SUM(cm.opens)::DECIMAL / SUM(cm.delivered_count) 
         ELSE 0 END as open_rate,
    CASE WHEN SUM(cm.opens) > 0 
         THEN SUM(cm.clicks)::DECIMAL / SUM(cm.opens) 
         ELSE 0 END as click_to_open_rate,
    CASE WHEN SUM(cm.cost) > 0 
         THEN (SUM(cm.revenue) - SUM(cm.cost)) / SUM(cm.cost) 
         ELSE 0 END as roi
FROM campaign_metrics cm
GROUP BY cm.campaign_id, cm.campaign_name, cm.channel, cm.candidate_id;

CREATE OR REPLACE VIEW v_channel_summary AS
SELECT 
    channel,
    candidate_id,
    COUNT(DISTINCT campaign_id) as campaigns,
    SUM(sent_count) as total_sent,
    SUM(opens) as total_opens,
    SUM(clicks) as total_clicks,
    SUM(conversions) as total_conversions,
    SUM(revenue) as total_revenue,
    SUM(cost) as total_cost,
    CASE WHEN SUM(cost) > 0 THEN (SUM(revenue) - SUM(cost)) / SUM(cost) ELSE 0 END as roi
FROM campaign_metrics
WHERE metric_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY channel, candidate_id
ORDER BY total_revenue DESC;

CREATE OR REPLACE VIEW v_daily_summary AS
SELECT 
    date,
    candidate_id,
    donations_count,
    donations_amount,
    unique_donors,
    new_donors,
    emails_sent,
    email_opens,
    email_clicks,
    sms_sent,
    sms_replies,
    total_cost,
    CASE WHEN total_cost > 0 
         THEN (donations_amount - total_cost) / total_cost 
         ELSE 0 END as daily_roi
FROM daily_metrics
ORDER BY date DESC;

SELECT 'Analytics Engine schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_07_issue_tracking_complete.py (E07)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 7: ISSUE TRACKING SYSTEM
-- ============================================================================

-- Issues Reference Table
CREATE TABLE IF NOT EXISTS issues (
    issue_code VARCHAR(50) PRIMARY KEY,
    issue_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    
    -- Party positions
    republican_position VARCHAR(50) DEFAULT 'unknown',
    democrat_position VARCHAR(50) DEFAULT 'unknown',
    
    -- Keywords for detection
    keywords JSONB DEFAULT '[]',
    related_issues JSONB DEFAULT '[]',
    
    -- Metadata
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_issues_category ON issues(category);

-- Candidate Issue Positions
CREATE TABLE IF NOT EXISTS candidate_positions (
    position_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    issue_code VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Position
    position VARCHAR(50) NOT NULL,  -- strongly_support to strongly_oppose
    position_strength INTEGER CHECK (position_strength BETWEEN 1 AND 5),
    
    -- Evidence
    public_statement TEXT,
    statement_date DATE,
    statement_source VARCHAR(255),
    voting_record_support INTEGER DEFAULT 0,
    voting_record_oppose INTEGER DEFAULT 0,
    
    -- Display
    is_priority_issue BOOLEAN DEFAULT false,
    display_on_website BOOLEAN DEFAULT true,
    
    -- Verification
    verified BOOLEAN DEFAULT false,
    verified_by UUID,
    verified_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(candidate_id, issue_code)
);

CREATE INDEX IF NOT EXISTS idx_candidate_positions_candidate ON candidate_positions(candidate_id);
CREATE INDEX IF NOT EXISTS idx_candidate_positions_issue ON candidate_positions(issue_code);

-- Donor Issue Positions / Interests
CREATE TABLE IF NOT EXISTS donor_positions (
    position_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    issue_code VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Position
    position VARCHAR(50) NOT NULL,
    position_strength INTEGER CHECK (position_strength BETWEEN 1 AND 5),
    
    -- Salience (how much they care, 0-1)
    salience DECIMAL(4,3) DEFAULT 0.5,
    
    -- Evidence
    inferred_from VARCHAR(50),  -- survey, donation, petition, social, inferred
    evidence_strength DECIMAL(4,3),
    
    -- Activity
    donations_to_issue DECIMAL(12,2) DEFAULT 0,
    petitions_signed INTEGER DEFAULT 0,
    events_attended INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, issue_code)
);

CREATE INDEX IF NOT EXISTS idx_donor_positions_donor ON donor_positions(donor_id);
CREATE INDEX IF NOT EXISTS idx_donor_positions_issue ON donor_positions(issue_code);
CREATE INDEX IF NOT EXISTS idx_donor_positions_salience ON donor_positions(salience DESC);

-- Issue Concordance (candidate-donor alignment)
CREATE TABLE IF NOT EXISTS issue_concordance (
    concordance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    donor_id UUID NOT NULL,
    
    -- Overall concordance score (0-1)
    concordance_score DECIMAL(4,3),
    weighted_concordance DECIMAL(4,3),  -- Weighted by salience
    
    -- Breakdown
    matching_issues INTEGER DEFAULT 0,
    opposing_issues INTEGER DEFAULT 0,
    neutral_issues INTEGER DEFAULT 0,
    total_issues_compared INTEGER DEFAULT 0,
    
    -- Top matching/opposing
    top_matching_issues JSONB DEFAULT '[]',
    top_opposing_issues JSONB DEFAULT '[]',
    
    -- Recommendation
    recommendation VARCHAR(50),  -- strong_match, good_match, weak_match, mismatch
    
    calculated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_concordance_pair ON issue_concordance(candidate_id, donor_id);
CREATE INDEX IF NOT EXISTS idx_concordance_score ON issue_concordance(concordance_score DESC);

-- Issue Trends
CREATE TABLE IF NOT EXISTS issue_trends (
    trend_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_code VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Time period
    period_date DATE NOT NULL,
    period_type VARCHAR(20) DEFAULT 'daily',  -- daily, weekly, monthly
    
    -- Volume
    news_mentions INTEGER DEFAULT 0,
    social_mentions INTEGER DEFAULT 0,
    donor_activity INTEGER DEFAULT 0,
    
    -- Sentiment
    sentiment_positive INTEGER DEFAULT 0,
    sentiment_negative INTEGER DEFAULT 0,
    sentiment_neutral INTEGER DEFAULT 0,
    sentiment_score DECIMAL(4,3),  -- -1 to 1
    
    -- Trend
    trend_direction VARCHAR(20),  -- rising, falling, stable
    trend_velocity DECIMAL(6,3),  -- Rate of change
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_issue_trends_date ON issue_trends(period_date);
CREATE INDEX IF NOT EXISTS idx_issue_trends_issue ON issue_trends(issue_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_issue_trends_unique ON issue_trends(issue_code, period_date, period_type);

-- Issue Lifecycle
CREATE TABLE IF NOT EXISTS issue_lifecycle (
    lifecycle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_code VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Current stage
    lifecycle_stage VARCHAR(50),  -- emerging, rising, peak, declining, dormant
    stage_entered_at TIMESTAMP,
    
    -- Predictions
    predicted_peak_date DATE,
    predicted_decline_date DATE,
    days_to_peak INTEGER,
    
    -- Historical
    last_peak_date DATE,
    last_peak_intensity DECIMAL(4,3),
    cycle_count INTEGER DEFAULT 0,
    
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_issue_lifecycle_issue ON issue_lifecycle(issue_code);

-- Issue Correlations
CREATE TABLE IF NOT EXISTS issue_correlations (
    correlation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_code_1 VARCHAR(50) REFERENCES issues(issue_code),
    issue_code_2 VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Correlation
    correlation_coefficient DECIMAL(5,4),  -- -1 to 1
    correlation_strength VARCHAR(20),  -- strong, moderate, weak, none
    correlation_type VARCHAR(20),  -- positive, negative
    
    -- Evidence
    sample_size INTEGER,
    confidence_level DECIMAL(4,3),
    
    calculated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_issue_correlations_pair ON issue_correlations(issue_code_1, issue_code_2);

-- Views
CREATE OR REPLACE VIEW v_issue_summary AS
SELECT 
    i.issue_code,
    i.issue_name,
    i.category,
    i.republican_position,
    i.democrat_position,
    COUNT(DISTINCT cp.candidate_id) as candidates_with_position,
    COUNT(DISTINCT dp.donor_id) as donors_with_position,
    AVG(dp.salience) as avg_donor_salience,
    il.lifecycle_stage
FROM issues i
LEFT JOIN candidate_positions cp ON i.issue_code = cp.issue_code
LEFT JOIN donor_positions dp ON i.issue_code = dp.issue_code
LEFT JOIN issue_lifecycle il ON i.issue_code = il.issue_code
GROUP BY i.issue_code, i.issue_name, i.category, 
         i.republican_position, i.democrat_position, il.lifecycle_stage
ORDER BY i.category, i.issue_name;

CREATE OR REPLACE VIEW v_trending_issues AS
SELECT 
    i.issue_code,
    i.issue_name,
    i.category,
    t.news_mentions,
    t.social_mentions,
    t.sentiment_score,
    t.trend_direction,
    t.trend_velocity,
    il.lifecycle_stage
FROM issues i
JOIN issue_trends t ON i.issue_code = t.issue_code
LEFT JOIN issue_lifecycle il ON i.issue_code = il.issue_code
WHERE t.period_date = CURRENT_DATE
AND (t.trend_direction = 'rising' OR t.news_mentions > 10)
ORDER BY t.trend_velocity DESC;

CREATE OR REPLACE VIEW v_candidate_issue_profile AS
SELECT 
    cp.candidate_id,
    i.category,
    COUNT(*) as positions_count,
    COUNT(CASE WHEN cp.position IN ('strongly_support', 'support') THEN 1 END) as support_count,
    COUNT(CASE WHEN cp.position IN ('strongly_oppose', 'oppose') THEN 1 END) as oppose_count,
    COUNT(CASE WHEN cp.is_priority_issue THEN 1 END) as priority_issues
FROM candidate_positions cp
JOIN issues i ON cp.issue_code = i.issue_code
GROUP BY cp.candidate_id, i.category;

SELECT 'Issue Tracking schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_08_communications_library_complete.py (E08)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 8: COMMUNICATIONS LIBRARY
-- ============================================================================

-- Content Items
CREATE TABLE IF NOT EXISTS library_content (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    category VARCHAR(50) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    title VARCHAR(500),
    description TEXT,
    subject_line VARCHAR(500),
    preview_text VARCHAR(500),
    body TEXT,
    html_content TEXT,
    plain_text TEXT,
    media_url TEXT,
    thumbnail_url TEXT,
    template_vars JSONB DEFAULT '[]',
    status VARCHAR(50) DEFAULT 'draft',
    version INTEGER DEFAULT 1,
    parent_id UUID REFERENCES library_content(content_id),
    created_by VARCHAR(255),
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    tags JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    is_template BOOLEAN DEFAULT false,
    is_ai_generated BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_library_category ON library_content(category);
CREATE INDEX IF NOT EXISTS idx_library_type ON library_content(content_type);
CREATE INDEX IF NOT EXISTS idx_library_status ON library_content(status);
CREATE INDEX IF NOT EXISTS idx_library_candidate ON library_content(candidate_id);
CREATE INDEX IF NOT EXISTS idx_library_tags ON library_content USING gin(tags);

-- Content Versions
CREATE TABLE IF NOT EXISTS content_versions (
    version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID REFERENCES library_content(content_id),
    version_number INTEGER NOT NULL,
    body TEXT,
    html_content TEXT,
    changes_summary TEXT,
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_versions_content ON content_versions(content_id);

-- Content Folders
CREATE TABLE IF NOT EXISTS library_folders (
    folder_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    parent_folder_id UUID REFERENCES library_folders(folder_id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(20),
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_folders_parent ON library_folders(parent_folder_id);

-- Content Folder Assignments
CREATE TABLE IF NOT EXISTS content_folder_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID REFERENCES library_content(content_id),
    folder_id UUID REFERENCES library_folders(folder_id),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(content_id, folder_id)
);

-- Content Performance
CREATE TABLE IF NOT EXISTS content_performance (
    perf_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID REFERENCES library_content(content_id),
    channel VARCHAR(50),
    campaign_id UUID,
    sends INTEGER DEFAULT 0,
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    revenue DECIMAL(12,2) DEFAULT 0,
    open_rate DECIMAL(5,2),
    click_rate DECIMAL(5,2),
    conversion_rate DECIMAL(5,2),
    recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_perf_content ON content_performance(content_id);

-- A/B Tests
CREATE TABLE IF NOT EXISTS content_ab_tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    test_type VARCHAR(50),
    variant_a_id UUID REFERENCES library_content(content_id),
    variant_b_id UUID REFERENCES library_content(content_id),
    variant_c_id UUID REFERENCES library_content(content_id),
    status VARCHAR(50) DEFAULT 'draft',
    winner_id UUID REFERENCES library_content(content_id),
    test_size_pct DECIMAL(5,2) DEFAULT 20,
    confidence_threshold DECIMAL(5,2) DEFAULT 95,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    auto_select_winner BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_status ON content_ab_tests(status);

-- Content Requests (from other ecosystems)
CREATE TABLE IF NOT EXISTS content_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requesting_ecosystem VARCHAR(50) NOT NULL,
    content_type VARCHAR(100),
    context JSONB DEFAULT '{}',
    urgency VARCHAR(20) DEFAULT 'normal',
    status VARCHAR(50) DEFAULT 'pending',
    fulfilled_content_id UUID REFERENCES library_content(content_id),
    created_at TIMESTAMP DEFAULT NOW(),
    fulfilled_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_requests_status ON content_requests(status);

-- Views
CREATE OR REPLACE VIEW v_library_summary AS
SELECT 
    category,
    content_type,
    COUNT(*) as total_items,
    COUNT(*) FILTER (WHERE status = 'approved') as approved,
    COUNT(*) FILTER (WHERE status = 'published') as published,
    COUNT(*) FILTER (WHERE is_template = true) as templates
FROM library_content
GROUP BY category, content_type;

CREATE OR REPLACE VIEW v_top_performing AS
SELECT 
    lc.content_id,
    lc.name,
    lc.category,
    lc.content_type,
    AVG(cp.conversion_rate) as avg_conversion,
    SUM(cp.revenue) as total_revenue,
    COUNT(cp.perf_id) as times_used
FROM library_content lc
JOIN content_performance cp ON lc.content_id = cp.content_id
GROUP BY lc.content_id, lc.name, lc.category, lc.content_type
ORDER BY avg_conversion DESC
LIMIT 100;

SELECT 'Communications Library schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_09_content_creation_ai_complete.py (E09)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 9: CONTENT CREATION AI
-- ============================================================================

-- Generated Content
CREATE TABLE IF NOT EXISTS generated_content (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    content_type VARCHAR(50) NOT NULL,
    title VARCHAR(500),
    subject_line VARCHAR(500),
    body TEXT NOT NULL,
    preview_text VARCHAR(500),
    tone VARCHAR(50),
    target_audience VARCHAR(255),
    personalization_vars JSONB DEFAULT '[]',
    generation_prompt TEXT,
    ai_model VARCHAR(100),
    generation_params JSONB DEFAULT '{}',
    variants JSONB DEFAULT '[]',
    selected_variant INTEGER,
    status VARCHAR(50) DEFAULT 'draft',
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    performance_score DECIMAL(5,2),
    tags JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_content_type ON generated_content(content_type);
CREATE INDEX IF NOT EXISTS idx_content_candidate ON generated_content(candidate_id);
CREATE INDEX IF NOT EXISTS idx_content_status ON generated_content(status);
CREATE INDEX IF NOT EXISTS idx_content_created ON generated_content(created_at);

-- Content Templates (base templates for generation)
CREATE TABLE IF NOT EXISTS content_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    content_type VARCHAR(50) NOT NULL,
    description TEXT,
    prompt_template TEXT NOT NULL,
    default_tone VARCHAR(50),
    default_params JSONB DEFAULT '{}',
    example_output TEXT,
    is_active BOOLEAN DEFAULT true,
    usage_count INTEGER DEFAULT 0,
    avg_performance DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_templates_type ON content_templates(content_type);

-- Generation Jobs (track generation requests)
CREATE TABLE IF NOT EXISTS content_generation_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    content_type VARCHAR(50) NOT NULL,
    prompt TEXT NOT NULL,
    context JSONB DEFAULT '{}',
    num_variants INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'pending',
    ai_model VARCHAR(100),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    tokens_used INTEGER,
    cost_estimate DECIMAL(10,4),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON content_generation_jobs(status);

-- Content Performance (track how content performs)
CREATE TABLE IF NOT EXISTS content_performance (
    performance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID REFERENCES generated_content(content_id),
    channel VARCHAR(50),
    sends INTEGER DEFAULT 0,
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    revenue DECIMAL(12,2) DEFAULT 0,
    open_rate DECIMAL(5,2),
    click_rate DECIMAL(5,2),
    conversion_rate DECIMAL(5,2),
    recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_perf_content ON content_performance(content_id);

-- Personalization Variables
CREATE TABLE IF NOT EXISTS personalization_variables (
    var_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    default_value VARCHAR(500),
    example_value VARCHAR(500),
    data_source VARCHAR(255),
    is_required BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Style Guides (candidate voice/tone)
CREATE TABLE IF NOT EXISTS content_style_guides (
    guide_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    voice_description TEXT,
    tone_keywords JSONB DEFAULT '[]',
    avoid_words JSONB DEFAULT '[]',
    preferred_phrases JSONB DEFAULT '[]',
    example_content JSONB DEFAULT '[]',
    brand_guidelines TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_style_candidate ON content_style_guides(candidate_id);

-- Views
CREATE OR REPLACE VIEW v_content_summary AS
SELECT 
    content_type,
    COUNT(*) as total_generated,
    COUNT(*) FILTER (WHERE status = 'approved') as approved,
    COUNT(*) FILTER (WHERE status = 'published') as published,
    AVG(performance_score) as avg_performance
FROM generated_content
GROUP BY content_type;

CREATE OR REPLACE VIEW v_recent_content AS
SELECT 
    gc.content_id,
    gc.content_type,
    gc.title,
    gc.status,
    gc.created_at,
    cp.open_rate,
    cp.click_rate
FROM generated_content gc
LEFT JOIN content_performance cp ON gc.content_id = cp.content_id
ORDER BY gc.created_at DESC
LIMIT 100;

SELECT 'Content Creation AI schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_10_compliance_manager_complete.py (E10)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 10: FEC COMPLIANCE MANAGER
-- ============================================================================

-- Contribution Limits Configuration
CREATE TABLE IF NOT EXISTS compliance_limits (
    limit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Limit type
    limit_name VARCHAR(100) NOT NULL,
    contributor_type VARCHAR(50) NOT NULL,
    recipient_type VARCHAR(50) NOT NULL,
    election_type VARCHAR(50),
    
    -- Amount
    limit_amount DECIMAL(12,2) NOT NULL,
    
    -- Period
    period_type VARCHAR(50) NOT NULL,  -- per_election, annual, cycle
    
    -- Effective dates
    effective_date DATE NOT NULL,
    expiration_date DATE,
    
    -- Notes
    fec_citation VARCHAR(100),
    notes TEXT,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_limit_type ON compliance_limits(contributor_type, recipient_type);

-- Donor Compliance Records
CREATE TABLE IF NOT EXISTS donor_compliance (
    compliance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    
    -- Verification status
    citizenship_verified BOOLEAN DEFAULT false,
    citizenship_verified_at TIMESTAMP,
    citizenship_method VARCHAR(100),
    
    age_verified BOOLEAN DEFAULT false,
    date_of_birth DATE,
    
    -- Employment (Best Efforts)
    employer VARCHAR(255),
    occupation VARCHAR(255),
    employer_updated_at TIMESTAMP,
    best_efforts_attempts INTEGER DEFAULT 0,
    best_efforts_last_attempt TIMESTAMP,
    
    -- Prohibited source checks
    is_federal_contractor BOOLEAN DEFAULT false,
    federal_contractor_checked_at TIMESTAMP,
    is_foreign_national BOOLEAN DEFAULT false,
    foreign_national_checked_at TIMESTAMP,
    is_corporation BOOLEAN DEFAULT false,
    is_labor_org BOOLEAN DEFAULT false,
    
    -- Status
    compliance_status VARCHAR(50) DEFAULT 'pending_review',
    compliance_notes TEXT,
    last_review_at TIMESTAMP,
    reviewed_by VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donor_compliance ON donor_compliance(donor_id);
CREATE INDEX IF NOT EXISTS idx_compliance_status ON donor_compliance(compliance_status);

-- Contribution Tracking (for limit enforcement)
CREATE TABLE IF NOT EXISTS contribution_tracking (
    tracking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Contributor
    donor_id UUID NOT NULL,
    contributor_type VARCHAR(50) NOT NULL,
    
    -- Recipient
    candidate_id UUID,
    committee_id UUID,
    recipient_type VARCHAR(50) NOT NULL,
    
    -- Election
    election_type VARCHAR(50),
    election_year INTEGER,
    
    -- Contribution
    contribution_id UUID,
    amount DECIMAL(12,2) NOT NULL,
    contribution_date DATE NOT NULL,
    contribution_type VARCHAR(50),
    
    -- Aggregate tracking
    aggregate_to_date DECIMAL(12,2),
    limit_amount DECIMAL(12,2),
    remaining_capacity DECIMAL(12,2),
    
    -- Compliance
    compliance_status VARCHAR(50) DEFAULT 'compliant',
    excess_amount DECIMAL(12,2) DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tracking_donor ON contribution_tracking(donor_id);
CREATE INDEX IF NOT EXISTS idx_tracking_candidate ON contribution_tracking(candidate_id);
CREATE INDEX IF NOT EXISTS idx_tracking_election ON contribution_tracking(election_type, election_year);

-- Excessive Contribution Queue
CREATE TABLE IF NOT EXISTS excessive_contributions (
    excessive_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Original contribution
    contribution_id UUID NOT NULL,
    donor_id UUID NOT NULL,
    candidate_id UUID,
    
    -- Amounts
    original_amount DECIMAL(12,2) NOT NULL,
    allowable_amount DECIMAL(12,2) NOT NULL,
    excess_amount DECIMAL(12,2) NOT NULL,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',  -- pending, refunded, redesignated, returned
    
    -- Resolution
    resolution_type VARCHAR(50),
    resolution_date DATE,
    resolution_notes TEXT,
    refund_check_number VARCHAR(50),
    
    -- Tracking
    detected_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP,
    resolved_by VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_excessive_status ON excessive_contributions(status);

-- Prohibited Contributions
CREATE TABLE IF NOT EXISTS prohibited_contributions (
    prohibited_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Contribution
    contribution_id UUID NOT NULL,
    donor_id UUID NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    
    -- Reason
    prohibition_reason VARCHAR(100) NOT NULL,
    prohibition_details TEXT,
    fec_citation VARCHAR(100),
    
    -- Status
    status VARCHAR(50) DEFAULT 'flagged',  -- flagged, confirmed, cleared, returned
    
    -- Resolution
    resolution_date DATE,
    resolution_notes TEXT,
    
    detected_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_prohibited_status ON prohibited_contributions(status);

-- Disclaimer Templates
CREATE TABLE IF NOT EXISTS compliance_disclaimers (
    disclaimer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    committee_id UUID,
    
    -- Disclaimer type
    disclaimer_type VARCHAR(100) NOT NULL,
    communication_type VARCHAR(100),  -- tv, radio, print, digital, email, mail
    
    -- Content
    disclaimer_text TEXT NOT NULL,
    short_disclaimer TEXT,
    audio_script TEXT,
    
    -- Requirements
    min_duration_seconds INTEGER,
    min_font_size INTEGER,
    min_display_time_seconds INTEGER,
    
    -- Status
    is_approved BOOLEAN DEFAULT false,
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disclaimer_type ON compliance_disclaimers(disclaimer_type, communication_type);

-- FEC Filing Records
CREATE TABLE IF NOT EXISTS fec_filings (
    filing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    committee_id UUID,
    
    -- Filing info
    form_type VARCHAR(20) NOT NULL,  -- F3, F3X, F3P, F24, F5, F6
    filing_period VARCHAR(100),
    coverage_start_date DATE,
    coverage_end_date DATE,
    
    -- Amounts
    total_receipts DECIMAL(14,2),
    total_disbursements DECIMAL(14,2),
    cash_on_hand DECIMAL(14,2),
    debts_owed DECIMAL(14,2),
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',  -- draft, review, submitted, accepted, amended
    fec_id VARCHAR(50),
    
    -- Dates
    due_date DATE,
    submitted_at TIMESTAMP,
    accepted_at TIMESTAMP,
    
    -- Amendment
    is_amendment BOOLEAN DEFAULT false,
    amends_filing_id UUID,
    amendment_number INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_filing_committee ON fec_filings(committee_id);
CREATE INDEX IF NOT EXISTS idx_filing_type ON fec_filings(form_type);

-- 48-Hour Notices
CREATE TABLE IF NOT EXISTS notices_48_hour (
    notice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    committee_id UUID,
    
    -- Contribution
    contribution_id UUID NOT NULL,
    donor_name VARCHAR(255) NOT NULL,
    donor_address TEXT,
    donor_employer VARCHAR(255),
    donor_occupation VARCHAR(255),
    amount DECIMAL(12,2) NOT NULL,
    contribution_date DATE NOT NULL,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',  -- pending, submitted, confirmed
    due_datetime TIMESTAMP NOT NULL,
    submitted_at TIMESTAMP,
    fec_confirmation VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_48hr_status ON notices_48_hour(status);
CREATE INDEX IF NOT EXISTS idx_48hr_due ON notices_48_hour(due_datetime);

-- Bundler Tracking
CREATE TABLE IF NOT EXISTS bundler_tracking (
    bundler_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Bundler info
    contact_id UUID,
    name VARCHAR(255) NOT NULL,
    employer VARCHAR(255),
    occupation VARCHAR(255),
    
    -- Period tracking
    reporting_period VARCHAR(100),
    period_start DATE,
    period_end DATE,
    
    -- Amounts
    total_bundled DECIMAL(14,2) DEFAULT 0,
    contribution_count INTEGER DEFAULT 0,
    
    -- Disclosure
    requires_disclosure BOOLEAN DEFAULT false,
    disclosed_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bundler_period ON bundler_tracking(reporting_period);

-- Compliance Audit Log
CREATE TABLE IF NOT EXISTS compliance_audit_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    
    -- Action
    action VARCHAR(100) NOT NULL,
    action_details JSONB,
    
    -- User
    performed_by VARCHAR(255),
    
    -- Timestamp
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_entity ON compliance_audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON compliance_audit_log(action);

-- Views
CREATE OR REPLACE VIEW v_donor_limit_status AS
SELECT 
    ct.donor_id,
    ct.candidate_id,
    ct.election_type,
    ct.election_year,
    SUM(ct.amount) as total_contributed,
    MAX(ct.limit_amount) as contribution_limit,
    MAX(ct.limit_amount) - SUM(ct.amount) as remaining_capacity,
    CASE 
        WHEN SUM(ct.amount) > MAX(ct.limit_amount) THEN 'over_limit'
        WHEN SUM(ct.amount) > MAX(ct.limit_amount) * 0.9 THEN 'near_limit'
        ELSE 'under_limit'
    END as limit_status
FROM contribution_tracking ct
GROUP BY ct.donor_id, ct.candidate_id, ct.election_type, ct.election_year;

CREATE OR REPLACE VIEW v_compliance_dashboard AS
SELECT 
    dc.compliance_status,
    COUNT(*) as donor_count,
    COUNT(*) FILTER (WHERE dc.citizenship_verified = false) as unverified_citizenship,
    COUNT(*) FILTER (WHERE dc.employer IS NULL AND dc.best_efforts_attempts < 3) as missing_employer,
    COUNT(*) FILTER (WHERE dc.is_federal_contractor = true) as federal_contractors,
    COUNT(*) FILTER (WHERE dc.is_foreign_national = true) as foreign_nationals
FROM donor_compliance dc
GROUP BY dc.compliance_status;

CREATE OR REPLACE VIEW v_pending_48_hour AS
SELECT 
    n.*,
    EXTRACT(EPOCH FROM (n.due_datetime - NOW())) / 3600 as hours_until_due
FROM notices_48_hour n
WHERE n.status = 'pending'
ORDER BY n.due_datetime;

SELECT 'FEC Compliance Manager schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_11_budget_management_complete.py (E11)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 11: BUDGET MANAGEMENT
-- ============================================================================

-- Budgets (hierarchical)
CREATE TABLE IF NOT EXISTS budgets (
    budget_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    name VARCHAR(255) NOT NULL,
    level VARCHAR(50) NOT NULL,
    parent_budget_id UUID REFERENCES budgets(budget_id),
    category VARCHAR(50),
    channel VARCHAR(50),
    tier VARCHAR(20),
    fiscal_year INTEGER,
    fiscal_quarter INTEGER,
    fiscal_month INTEGER,
    budget_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    allocated_amount DECIMAL(14,2) DEFAULT 0,
    spent_amount DECIMAL(14,2) DEFAULT 0,
    committed_amount DECIMAL(14,2) DEFAULT 0,
    remaining_amount DECIMAL(14,2) GENERATED ALWAYS AS (budget_amount - spent_amount - committed_amount) STORED,
    status VARCHAR(20) DEFAULT 'ok',
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_budgets_candidate ON budgets(candidate_id);
CREATE INDEX IF NOT EXISTS idx_budgets_campaign ON budgets(campaign_id);
CREATE INDEX IF NOT EXISTS idx_budgets_level ON budgets(level);
CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category);
CREATE INDEX IF NOT EXISTS idx_budgets_status ON budgets(status);

-- Expenses (actual spending)
CREATE TABLE IF NOT EXISTS expenses (
    expense_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID REFERENCES budgets(budget_id),
    candidate_id UUID,
    campaign_id UUID,
    category VARCHAR(50) NOT NULL,
    channel VARCHAR(50),
    tier VARCHAR(20),
    vendor_id UUID,
    vendor_name VARCHAR(255),
    description TEXT,
    amount DECIMAL(12,2) NOT NULL,
    quantity INTEGER DEFAULT 1,
    unit_cost DECIMAL(10,2),
    expense_date DATE NOT NULL,
    payment_date DATE,
    payment_method VARCHAR(50),
    payment_reference VARCHAR(100),
    invoice_number VARCHAR(100),
    receipt_url TEXT,
    is_recurring BOOLEAN DEFAULT false,
    recurrence_rule VARCHAR(100),
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    tags JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_budget ON expenses(budget_id);
CREATE INDEX IF NOT EXISTS idx_expenses_candidate ON expenses(candidate_id);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_expenses_vendor ON expenses(vendor_id);
CREATE INDEX IF NOT EXISTS idx_expenses_status ON expenses(status);

-- Vendors
CREATE TABLE IF NOT EXISTS vendors (
    vendor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50),
    contact_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    address TEXT,
    tax_id VARCHAR(50),
    payment_terms VARCHAR(100),
    preferred_payment VARCHAR(50),
    total_spent DECIMAL(14,2) DEFAULT 0,
    total_invoices INTEGER DEFAULT 0,
    rating INTEGER,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendors_category ON vendors(category);

-- Invoices
CREATE TABLE IF NOT EXISTS invoices (
    invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID REFERENCES vendors(vendor_id),
    budget_id UUID REFERENCES budgets(budget_id),
    candidate_id UUID,
    invoice_number VARCHAR(100),
    invoice_date DATE NOT NULL,
    due_date DATE,
    amount DECIMAL(12,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL,
    paid_amount DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending',
    payment_date DATE,
    payment_reference VARCHAR(100),
    line_items JSONB DEFAULT '[]',
    notes TEXT,
    document_url TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoices_vendor ON invoices(vendor_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_due ON invoices(due_date);

-- Budget Alerts
CREATE TABLE IF NOT EXISTS budget_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID REFERENCES budgets(budget_id),
    candidate_id UUID,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    threshold_pct DECIMAL(5,2),
    current_pct DECIMAL(5,2),
    amount_over DECIMAL(12,2),
    status VARCHAR(50) DEFAULT 'active',
    acknowledged_at TIMESTAMP,
    acknowledged_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alerts_budget ON budget_alerts(budget_id);
CREATE INDEX IF NOT EXISTS idx_alerts_status ON budget_alerts(status);

-- Cost per Acquisition Tracking
CREATE TABLE IF NOT EXISTS cpa_tracking (
    tracking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    channel VARCHAR(50) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_spend DECIMAL(12,2) DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    donations_amount DECIMAL(14,2) DEFAULT 0,
    new_donors INTEGER DEFAULT 0,
    cpa_donation DECIMAL(10,2),
    cpa_new_donor DECIMAL(10,2),
    roi DECIMAL(10,4),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cpa_channel ON cpa_tracking(channel);
CREATE INDEX IF NOT EXISTS idx_cpa_period ON cpa_tracking(period_start, period_end);

-- Budget Forecasts
CREATE TABLE IF NOT EXISTS budget_forecasts (
    forecast_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID REFERENCES budgets(budget_id),
    forecast_date DATE NOT NULL,
    forecast_type VARCHAR(50),
    projected_spend DECIMAL(14,2),
    projected_remaining DECIMAL(14,2),
    days_until_depleted INTEGER,
    confidence_score DECIMAL(5,2),
    assumptions JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_forecasts_budget ON budget_forecasts(budget_id);

-- Views
CREATE OR REPLACE VIEW v_budget_summary AS
SELECT 
    b.budget_id,
    b.name,
    b.level,
    b.category,
    b.budget_amount,
    b.spent_amount,
    b.committed_amount,
    b.remaining_amount,
    CASE WHEN b.budget_amount > 0 
         THEN (b.spent_amount / b.budget_amount * 100)::DECIMAL(5,2)
         ELSE 0 END as pct_used,
    b.status,
    b.start_date,
    b.end_date
FROM budgets b
WHERE b.is_active = true;

CREATE OR REPLACE VIEW v_spend_by_channel AS
SELECT 
    channel,
    SUM(amount) as total_spend,
    COUNT(*) as transaction_count,
    AVG(amount) as avg_transaction,
    MIN(expense_date) as first_expense,
    MAX(expense_date) as last_expense
FROM expenses
WHERE status = 'approved'
GROUP BY channel;

CREATE OR REPLACE VIEW v_vendor_summary AS
SELECT 
    v.vendor_id,
    v.name,
    v.category,
    v.total_spent,
    v.total_invoices,
    COUNT(i.invoice_id) FILTER (WHERE i.status = 'pending') as pending_invoices,
    SUM(i.total_amount) FILTER (WHERE i.status = 'pending') as pending_amount
FROM vendors v
LEFT JOIN invoices i ON v.vendor_id = i.vendor_id
GROUP BY v.vendor_id, v.name, v.category, v.total_spent, v.total_invoices;

CREATE OR REPLACE VIEW v_upcoming_payments AS
SELECT 
    i.invoice_id,
    v.name as vendor_name,
    i.invoice_number,
    i.total_amount,
    i.due_date,
    i.due_date - CURRENT_DATE as days_until_due,
    CASE WHEN i.due_date < CURRENT_DATE THEN true ELSE false END as is_overdue
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
WHERE i.status = 'pending'
ORDER BY i.due_date;

SELECT 'Budget Management schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_11_training_lms_complete.py (E11)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 11B: TRAINING & LEARNING MANAGEMENT SYSTEM
-- ============================================================================

-- Courses
CREATE TABLE IF NOT EXISTS training_courses (
    course_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL,
    difficulty_level VARCHAR(50) DEFAULT 'beginner',
    duration_minutes INTEGER,
    thumbnail_url TEXT,
    instructor_name VARCHAR(255),
    is_required BOOLEAN DEFAULT false,
    required_for_roles JSONB DEFAULT '[]',
    prerequisites JSONB DEFAULT '[]',
    certification_id VARCHAR(100),
    points_value INTEGER DEFAULT 10,
    pass_threshold INTEGER DEFAULT 70,
    is_published BOOLEAN DEFAULT false,
    publish_date TIMESTAMP,
    expire_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_courses_category ON training_courses(category);
CREATE INDEX IF NOT EXISTS idx_courses_published ON training_courses(is_published);

-- Modules (sections within courses)
CREATE TABLE IF NOT EXISTS training_modules (
    module_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID REFERENCES training_courses(course_id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    sequence_order INTEGER NOT NULL,
    duration_minutes INTEGER,
    is_required BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_modules_course ON training_modules(course_id);

-- Content Items (videos, quizzes, PDFs within modules)
CREATE TABLE IF NOT EXISTS training_content (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID REFERENCES training_modules(module_id),
    title VARCHAR(500) NOT NULL,
    content_type VARCHAR(50) NOT NULL,
    sequence_order INTEGER NOT NULL,
    duration_minutes INTEGER,
    
    -- Video content
    video_url TEXT,
    video_provider VARCHAR(50),
    video_id VARCHAR(255),
    
    -- Quiz content
    quiz_questions JSONB DEFAULT '[]',
    quiz_time_limit_minutes INTEGER,
    quiz_attempts_allowed INTEGER DEFAULT 3,
    
    -- PDF/Article content
    document_url TEXT,
    article_body TEXT,
    
    -- Interactive content
    interactive_url TEXT,
    interactive_config JSONB DEFAULT '{}',
    
    points_value INTEGER DEFAULT 5,
    is_required BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_content_module ON training_content(module_id);
CREATE INDEX IF NOT EXISTS idx_content_type ON training_content(content_type);

-- User Enrollments
CREATE TABLE IF NOT EXISTS training_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    course_id UUID REFERENCES training_courses(course_id),
    status VARCHAR(50) DEFAULT 'enrolled',
    enrolled_at TIMESTAMP DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    progress_pct DECIMAL(5,2) DEFAULT 0,
    current_module_id UUID,
    current_content_id UUID,
    total_time_spent_minutes INTEGER DEFAULT 0,
    quiz_attempts INTEGER DEFAULT 0,
    highest_quiz_score INTEGER,
    points_earned INTEGER DEFAULT 0,
    certificate_issued BOOLEAN DEFAULT false,
    certificate_url TEXT,
    expires_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_enrollments_user ON training_enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON training_enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_status ON training_enrollments(status);

-- Content Progress (track each piece of content)
CREATE TABLE IF NOT EXISTS training_progress (
    progress_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrollment_id UUID REFERENCES training_enrollments(enrollment_id),
    content_id UUID REFERENCES training_content(content_id),
    status VARCHAR(50) DEFAULT 'not_started',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    time_spent_minutes INTEGER DEFAULT 0,
    video_progress_pct DECIMAL(5,2) DEFAULT 0,
    quiz_score INTEGER,
    quiz_answers JSONB DEFAULT '{}',
    attempts INTEGER DEFAULT 0,
    points_earned INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_progress_enrollment ON training_progress(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_progress_content ON training_progress(content_id);

-- Certifications
CREATE TABLE IF NOT EXISTS training_certifications (
    cert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    certification_type VARCHAR(100) NOT NULL,
    course_id UUID REFERENCES training_courses(course_id),
    issued_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    certificate_number VARCHAR(100) UNIQUE,
    certificate_url TEXT,
    score INTEGER,
    is_valid BOOLEAN DEFAULT true,
    renewed_from UUID
);

CREATE INDEX IF NOT EXISTS idx_certs_user ON training_certifications(user_id);
CREATE INDEX IF NOT EXISTS idx_certs_type ON training_certifications(certification_type);

-- Badges & Achievements
CREATE TABLE IF NOT EXISTS training_badges (
    badge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon_url TEXT,
    category VARCHAR(100),
    points_required INTEGER,
    courses_required JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_badges (
    user_badge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    badge_id UUID REFERENCES training_badges(badge_id),
    earned_at TIMESTAMP DEFAULT NOW(),
    shared_on_social BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_user_badges_user ON user_badges(user_id);

-- Leaderboard
CREATE TABLE IF NOT EXISTS training_leaderboard (
    leaderboard_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    total_points INTEGER DEFAULT 0,
    courses_completed INTEGER DEFAULT 0,
    certifications_earned INTEGER DEFAULT 0,
    badges_earned INTEGER DEFAULT 0,
    current_streak_days INTEGER DEFAULT 0,
    longest_streak_days INTEGER DEFAULT 0,
    last_activity_at TIMESTAMP DEFAULT NOW(),
    rank_position INTEGER,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_user ON training_leaderboard(user_id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_points ON training_leaderboard(total_points DESC);

-- Learning Paths
CREATE TABLE IF NOT EXISTS learning_paths (
    path_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    target_role VARCHAR(100),
    courses JSONB DEFAULT '[]',
    estimated_hours INTEGER,
    certification_awarded VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Webinars/Live Training
CREATE TABLE IF NOT EXISTS training_webinars (
    webinar_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    instructor_name VARCHAR(255),
    scheduled_at TIMESTAMP NOT NULL,
    duration_minutes INTEGER DEFAULT 60,
    max_attendees INTEGER,
    webinar_url TEXT,
    webinar_provider VARCHAR(50),
    recording_url TEXT,
    is_recorded BOOLEAN DEFAULT false,
    course_id UUID REFERENCES training_courses(course_id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS webinar_registrations (
    registration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webinar_id UUID REFERENCES training_webinars(webinar_id),
    user_id UUID NOT NULL,
    registered_at TIMESTAMP DEFAULT NOW(),
    attended BOOLEAN DEFAULT false,
    attended_minutes INTEGER DEFAULT 0
);

-- Views
CREATE OR REPLACE VIEW v_course_summary AS
SELECT 
    c.course_id,
    c.title,
    c.category,
    c.difficulty_level,
    c.duration_minutes,
    c.points_value,
    c.is_published,
    COUNT(DISTINCT m.module_id) as module_count,
    COUNT(DISTINCT tc.content_id) as content_count,
    COUNT(DISTINCT e.enrollment_id) as enrollments,
    COUNT(DISTINCT e.enrollment_id) FILTER (WHERE e.status = 'completed') as completions
FROM training_courses c
LEFT JOIN training_modules m ON c.course_id = m.course_id
LEFT JOIN training_content tc ON m.module_id = tc.module_id
LEFT JOIN training_enrollments e ON c.course_id = e.course_id
GROUP BY c.course_id;

CREATE OR REPLACE VIEW v_user_progress AS
SELECT 
    e.user_id,
    COUNT(DISTINCT e.course_id) as courses_enrolled,
    COUNT(DISTINCT e.course_id) FILTER (WHERE e.status = 'completed') as courses_completed,
    SUM(e.points_earned) as total_points,
    AVG(e.progress_pct) as avg_progress,
    SUM(e.total_time_spent_minutes) as total_time_minutes
FROM training_enrollments e
GROUP BY e.user_id;

CREATE OR REPLACE VIEW v_leaderboard_top AS
SELECT 
    l.user_id,
    l.total_points,
    l.courses_completed,
    l.certifications_earned,
    l.badges_earned,
    l.current_streak_days,
    ROW_NUMBER() OVER (ORDER BY l.total_points DESC) as rank
FROM training_leaderboard l
ORDER BY total_points DESC
LIMIT 100;

SELECT 'Training LMS schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_12_campaign_operations_complete.py (E12)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 12: CAMPAIGN OPERATIONS
-- ============================================================================

-- Campaign Team Members
CREATE TABLE IF NOT EXISTS campaign_team (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    user_id UUID,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    role VARCHAR(100),
    department VARCHAR(100),
    is_staff BOOLEAN DEFAULT true,
    hourly_rate DECIMAL(10,2),
    start_date DATE,
    end_date DATE,
    permissions JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_team_candidate ON campaign_team(candidate_id);
CREATE INDEX IF NOT EXISTS idx_team_role ON campaign_team(role);

-- Projects
CREATE TABLE IF NOT EXISTS campaign_projects (
    project_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    phase VARCHAR(50),
    status VARCHAR(50) DEFAULT 'active',
    owner_id UUID REFERENCES campaign_team(member_id),
    start_date DATE,
    target_date DATE,
    completed_date DATE,
    budget DECIMAL(12,2),
    spent DECIMAL(12,2) DEFAULT 0,
    progress_pct INTEGER DEFAULT 0,
    priority VARCHAR(20) DEFAULT 'medium',
    tags JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_projects_candidate ON campaign_projects(candidate_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON campaign_projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_phase ON campaign_projects(phase);

-- Tasks
CREATE TABLE IF NOT EXISTS campaign_tasks (
    task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES campaign_projects(project_id),
    candidate_id UUID,
    parent_task_id UUID REFERENCES campaign_tasks(task_id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    status VARCHAR(50) DEFAULT 'todo',
    priority VARCHAR(20) DEFAULT 'medium',
    assigned_to UUID REFERENCES campaign_team(member_id),
    created_by UUID REFERENCES campaign_team(member_id),
    due_date TIMESTAMP,
    start_date TIMESTAMP,
    completed_at TIMESTAMP,
    estimated_hours DECIMAL(6,2),
    actual_hours DECIMAL(6,2),
    is_recurring BOOLEAN DEFAULT false,
    recurrence_rule VARCHAR(100),
    dependencies JSONB DEFAULT '[]',
    tags JSONB DEFAULT '[]',
    attachments JSONB DEFAULT '[]',
    checklist JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_project ON campaign_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON campaign_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON campaign_tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due ON campaign_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON campaign_tasks(priority);

-- Task Comments
CREATE TABLE IF NOT EXISTS task_comments (
    comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES campaign_tasks(task_id),
    author_id UUID REFERENCES campaign_team(member_id),
    content TEXT NOT NULL,
    attachments JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_task ON task_comments(task_id);

-- Task History (audit trail)
CREATE TABLE IF NOT EXISTS task_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES campaign_tasks(task_id),
    changed_by UUID REFERENCES campaign_team(member_id),
    field_changed VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_history_task ON task_history(task_id);

-- Milestones
CREATE TABLE IF NOT EXISTS campaign_milestones (
    milestone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES campaign_projects(project_id),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    target_date DATE NOT NULL,
    completed_date DATE,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_milestones_project ON campaign_milestones(project_id);
CREATE INDEX IF NOT EXISTS idx_milestones_date ON campaign_milestones(target_date);

-- Calendar Events
CREATE TABLE IF NOT EXISTS campaign_calendar (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(50),
    location VARCHAR(500),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    all_day BOOLEAN DEFAULT false,
    attendees JSONB DEFAULT '[]',
    reminders JSONB DEFAULT '[]',
    recurrence_rule VARCHAR(100),
    related_task_id UUID REFERENCES campaign_tasks(task_id),
    related_project_id UUID REFERENCES campaign_projects(project_id),
    is_public BOOLEAN DEFAULT false,
    created_by UUID REFERENCES campaign_team(member_id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendar_candidate ON campaign_calendar(candidate_id);
CREATE INDEX IF NOT EXISTS idx_calendar_start ON campaign_calendar(start_time);
CREATE INDEX IF NOT EXISTS idx_calendar_type ON campaign_calendar(event_type);

-- Workflows (automation templates)
CREATE TABLE IF NOT EXISTS campaign_workflows (
    workflow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    trigger_type VARCHAR(50),
    trigger_config JSONB DEFAULT '{}',
    steps JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workflows_trigger ON campaign_workflows(trigger_type);

-- Messages (internal team communication)
CREATE TABLE IF NOT EXISTS campaign_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    sender_id UUID REFERENCES campaign_team(member_id),
    recipient_ids JSONB DEFAULT '[]',
    channel VARCHAR(50) DEFAULT 'general',
    subject VARCHAR(255),
    content TEXT NOT NULL,
    attachments JSONB DEFAULT '[]',
    is_read BOOLEAN DEFAULT false,
    related_task_id UUID REFERENCES campaign_tasks(task_id),
    parent_message_id UUID REFERENCES campaign_messages(message_id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_channel ON campaign_messages(channel);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON campaign_messages(sender_id);

-- Time Tracking
CREATE TABLE IF NOT EXISTS time_entries (
    entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES campaign_tasks(task_id),
    member_id UUID REFERENCES campaign_team(member_id),
    hours DECIMAL(6,2) NOT NULL,
    description TEXT,
    entry_date DATE DEFAULT CURRENT_DATE,
    billable BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_time_task ON time_entries(task_id);
CREATE INDEX IF NOT EXISTS idx_time_member ON time_entries(member_id);

-- Views
CREATE OR REPLACE VIEW v_task_summary AS
SELECT 
    ct.task_id,
    ct.title,
    ct.status,
    ct.priority,
    ct.due_date,
    ct.assigned_to,
    tm.name as assignee_name,
    cp.name as project_name,
    ct.category,
    CASE WHEN ct.due_date < NOW() AND ct.status NOT IN ('completed', 'cancelled') 
         THEN true ELSE false END as is_overdue
FROM campaign_tasks ct
LEFT JOIN campaign_team tm ON ct.assigned_to = tm.member_id
LEFT JOIN campaign_projects cp ON ct.project_id = cp.project_id;

CREATE OR REPLACE VIEW v_team_workload AS
SELECT 
    tm.member_id,
    tm.name,
    tm.role,
    COUNT(ct.task_id) FILTER (WHERE ct.status IN ('todo', 'in_progress')) as active_tasks,
    COUNT(ct.task_id) FILTER (WHERE ct.status = 'completed' AND ct.completed_at > NOW() - INTERVAL '7 days') as completed_this_week,
    SUM(ct.estimated_hours) FILTER (WHERE ct.status IN ('todo', 'in_progress')) as pending_hours
FROM campaign_team tm
LEFT JOIN campaign_tasks ct ON tm.member_id = ct.assigned_to
WHERE tm.is_active = true
GROUP BY tm.member_id, tm.name, tm.role;

CREATE OR REPLACE VIEW v_project_progress AS
SELECT 
    cp.project_id,
    cp.name,
    cp.status,
    cp.target_date,
    cp.budget,
    cp.spent,
    COUNT(ct.task_id) as total_tasks,
    COUNT(ct.task_id) FILTER (WHERE ct.status = 'completed') as completed_tasks,
    CASE WHEN COUNT(ct.task_id) > 0 
         THEN (COUNT(ct.task_id) FILTER (WHERE ct.status = 'completed')::DECIMAL / COUNT(ct.task_id) * 100)::INTEGER
         ELSE 0 END as progress_pct
FROM campaign_projects cp
LEFT JOIN campaign_tasks ct ON cp.project_id = ct.project_id
GROUP BY cp.project_id, cp.name, cp.status, cp.target_date, cp.budget, cp.spent;

SELECT 'Campaign Operations schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_13_ai_hub_complete.py (E13)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 13: AI HUB - COMPLETION SCHEMA
-- Cost tracking, caching metadata, model analytics
-- ============================================================================

-- AI Usage Tracking
CREATE TABLE IF NOT EXISTS ai_usage_log (
    usage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model VARCHAR(100) NOT NULL,
    prompt_tokens INTEGER NOT NULL,
    completion_tokens INTEGER NOT NULL,
    total_tokens INTEGER NOT NULL,
    input_cost_usd DECIMAL(10,6),
    output_cost_usd DECIMAL(10,6),
    total_cost_usd DECIMAL(10,6),
    cache_hit BOOLEAN DEFAULT false,
    response_time_ms INTEGER,
    candidate_id UUID,
    campaign_id UUID,
    use_case VARCHAR(100),  -- 'social_post', 'email', 'analysis', etc.
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_date ON ai_usage_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_model ON ai_usage_log(model);
CREATE INDEX IF NOT EXISTS idx_ai_usage_candidate ON ai_usage_log(candidate_id);
CREATE INDEX IF NOT EXISTS idx_ai_usage_usecase ON ai_usage_log(use_case);

-- Daily cost summary
CREATE TABLE IF NOT EXISTS ai_daily_costs (
    date DATE PRIMARY KEY,
    total_requests INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    total_cost_usd DECIMAL(10,4) DEFAULT 0,
    cache_hits INTEGER DEFAULT 0,
    cache_misses INTEGER DEFAULT 0,
    avg_response_time_ms INTEGER,
    by_model JSONB,
    by_use_case JSONB,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Budget alerts
CREATE TABLE IF NOT EXISTS ai_budget_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type VARCHAR(50) NOT NULL,  -- 'daily_threshold', 'monthly_threshold', 'spike'
    threshold_pct INTEGER,
    current_spend DECIMAL(10,4),
    budget DECIMAL(10,4),
    message TEXT,
    acknowledged BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Cache metadata (actual cache is in Redis)
CREATE TABLE IF NOT EXISTS ai_cache_metadata (
    cache_key VARCHAR(64) PRIMARY KEY,
    model VARCHAR(100),
    prompt_hash VARCHAR(64),
    tokens_saved INTEGER,
    cost_saved_usd DECIMAL(10,6),
    hit_count INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW(),
    last_hit_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cache_expires ON ai_cache_metadata(expires_at);

-- Model performance tracking
CREATE TABLE IF NOT EXISTS ai_model_performance (
    performance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model VARCHAR(100) NOT NULL,
    use_case VARCHAR(100),
    avg_response_time_ms DECIMAL(10,2),
    avg_tokens DECIMAL(10,2),
    avg_cost_usd DECIMAL(10,6),
    quality_score DECIMAL(5,2),  -- 0-10 based on user feedback
    sample_size INTEGER,
    period_start TIMESTAMP,
    period_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Cost summary view
CREATE OR REPLACE VIEW v_ai_cost_summary AS
SELECT 
    DATE(created_at) as date,
    model,
    use_case,
    COUNT(*) as requests,
    SUM(total_tokens) as tokens,
    SUM(total_cost_usd) as cost_usd,
    SUM(CASE WHEN cache_hit THEN 1 ELSE 0 END) as cache_hits,
    AVG(response_time_ms) as avg_response_ms
FROM ai_usage_log
GROUP BY DATE(created_at), model, use_case
ORDER BY date DESC, cost_usd DESC;

-- Monthly cost summary
CREATE OR REPLACE VIEW v_ai_monthly_costs AS
SELECT 
    DATE_TRUNC('month', created_at) as month,
    SUM(total_cost_usd) as total_cost,
    SUM(total_tokens) as total_tokens,
    COUNT(*) as total_requests,
    COUNT(DISTINCT candidate_id) as unique_candidates
FROM ai_usage_log
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

SELECT 'AI Hub schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_14_print_production_complete.py (E14)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 14: PRINT PRODUCTION
-- ============================================================================

-- Print Templates
CREATE TABLE IF NOT EXISTS print_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    document_type VARCHAR(50) NOT NULL,
    size VARCHAR(50),
    description TEXT,
    html_template TEXT,
    css_styles TEXT,
    variable_fields JSONB DEFAULT '[]',
    preview_url TEXT,
    thumbnail_url TEXT,
    is_active BOOLEAN DEFAULT true,
    version INTEGER DEFAULT 1,
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_print_templates_type ON print_templates(document_type);
CREATE INDEX IF NOT EXISTS idx_print_templates_candidate ON print_templates(candidate_id);

-- Print Jobs
CREATE TABLE IF NOT EXISTS print_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    template_id UUID REFERENCES print_templates(template_id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    document_type VARCHAR(50) NOT NULL,
    mail_class VARCHAR(50),
    quantity INTEGER NOT NULL,
    recipient_list_id UUID,
    recipient_count INTEGER,
    variable_data_file TEXT,
    output_files JSONB DEFAULT '[]',
    status VARCHAR(50) DEFAULT 'draft',
    vendor_id UUID,
    vendor_name VARCHAR(255),
    vendor_job_id VARCHAR(100),
    estimated_cost DECIMAL(12,2),
    actual_cost DECIMAL(12,2),
    cost_per_piece DECIMAL(8,4),
    postage_cost DECIMAL(12,2),
    production_cost DECIMAL(12,2),
    submitted_at TIMESTAMP,
    approved_at TIMESTAMP,
    approved_by VARCHAR(255),
    sent_to_vendor_at TIMESTAMP,
    in_production_at TIMESTAMP,
    shipped_at TIMESTAMP,
    estimated_delivery DATE,
    actual_delivery DATE,
    tracking_numbers JSONB DEFAULT '[]',
    proof_url TEXT,
    proof_approved BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON print_jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_candidate ON print_jobs(candidate_id);
CREATE INDEX IF NOT EXISTS idx_jobs_vendor ON print_jobs(vendor_id);

-- Print Recipients (for variable data)
CREATE TABLE IF NOT EXISTS print_recipients (
    recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES print_jobs(job_id),
    contact_id UUID,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(2) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    zip_plus4 VARCHAR(4),
    delivery_point VARCHAR(10),
    carrier_route VARCHAR(10),
    address_validated BOOLEAN DEFAULT false,
    address_valid BOOLEAN,
    validation_message TEXT,
    variable_data JSONB DEFAULT '{}',
    is_duplicate BOOLEAN DEFAULT false,
    is_excluded BOOLEAN DEFAULT false,
    exclude_reason VARCHAR(255),
    piece_generated BOOLEAN DEFAULT false,
    piece_url TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recipients_job ON print_recipients(job_id);
CREATE INDEX IF NOT EXISTS idx_recipients_contact ON print_recipients(contact_id);
CREATE INDEX IF NOT EXISTS idx_recipients_zip ON print_recipients(zip_code);

-- Print Vendors
CREATE TABLE IF NOT EXISTS print_vendors (
    vendor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    api_endpoint TEXT,
    api_key_encrypted TEXT,
    supported_types JSONB DEFAULT '[]',
    pricing JSONB DEFAULT '{}',
    turnaround_days INTEGER,
    minimum_quantity INTEGER,
    rating DECIMAL(3,2),
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Mail Tracking
CREATE TABLE IF NOT EXISTS mail_tracking (
    tracking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES print_jobs(job_id),
    recipient_id UUID REFERENCES print_recipients(recipient_id),
    imb_code VARCHAR(65),
    tracking_number VARCHAR(100),
    mail_class VARCHAR(50),
    status VARCHAR(50),
    status_date TIMESTAMP,
    delivery_date DATE,
    return_reason VARCHAR(255),
    scan_events JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tracking_job ON mail_tracking(job_id);
CREATE INDEX IF NOT EXISTS idx_tracking_status ON mail_tracking(status);

-- Print Cost Tracking
CREATE TABLE IF NOT EXISTS print_costs (
    cost_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES print_jobs(job_id),
    cost_type VARCHAR(50) NOT NULL,
    description VARCHAR(255),
    quantity INTEGER,
    unit_cost DECIMAL(10,4),
    total_cost DECIMAL(12,2) NOT NULL,
    vendor_invoice VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_costs_job ON print_costs(job_id);

-- Views
CREATE OR REPLACE VIEW v_job_summary AS
SELECT 
    pj.job_id,
    pj.name,
    pj.document_type,
    pj.status,
    pj.quantity,
    pj.estimated_cost,
    pj.actual_cost,
    pj.vendor_name,
    pj.created_at,
    COUNT(pr.recipient_id) as recipient_count,
    COUNT(pr.recipient_id) FILTER (WHERE pr.address_validated AND pr.address_valid) as valid_addresses
FROM print_jobs pj
LEFT JOIN print_recipients pr ON pj.job_id = pr.job_id
GROUP BY pj.job_id;

CREATE OR REPLACE VIEW v_delivery_status AS
SELECT 
    pj.job_id,
    pj.name,
    pj.quantity,
    COUNT(mt.tracking_id) as tracked_pieces,
    COUNT(mt.tracking_id) FILTER (WHERE mt.status = 'delivered') as delivered,
    COUNT(mt.tracking_id) FILTER (WHERE mt.status = 'in_transit') as in_transit,
    COUNT(mt.tracking_id) FILTER (WHERE mt.status = 'returned') as returned
FROM print_jobs pj
LEFT JOIN mail_tracking mt ON pj.job_id = mt.job_id
WHERE pj.status IN ('shipped', 'delivered')
GROUP BY pj.job_id, pj.name, pj.quantity;

SELECT 'Print Production schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_15_contact_directory_complete.py (E15)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 15: CONTACT DIRECTORY
-- ============================================================================

-- Master Contact Record
CREATE TABLE IF NOT EXISTS contacts (
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    prefix VARCHAR(20),
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100),
    suffix VARCHAR(20),
    nickname VARCHAR(100),
    full_name VARCHAR(255),
    
    -- Contact Types (can be multiple)
    contact_types JSONB DEFAULT '["prospect"]',
    primary_type VARCHAR(50) DEFAULT 'prospect',
    status VARCHAR(50) DEFAULT 'active',
    
    -- Contact Info
    email VARCHAR(255),
    email_secondary VARCHAR(255),
    phone VARCHAR(20),
    phone_mobile VARCHAR(20),
    phone_work VARCHAR(20),
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    county VARCHAR(100),
    congressional_district VARCHAR(10),
    state_house_district VARCHAR(10),
    state_senate_district VARCHAR(10),
    precinct VARCHAR(50),
    
    -- Demographics
    date_of_birth DATE,
    age INTEGER,
    gender VARCHAR(20),
    party_affiliation VARCHAR(50),
    voter_registration_status VARCHAR(50),
    voter_id VARCHAR(50),
    
    -- Employment
    employer VARCHAR(255),
    occupation VARCHAR(255),
    job_title VARCHAR(255),
    industry VARCHAR(100),
    
    -- Wealth Indicators
    estimated_wealth_tier VARCHAR(20),
    estimated_income_range VARCHAR(50),
    property_owner BOOLEAN,
    business_owner BOOLEAN,
    
    -- Engagement Scores
    overall_score INTEGER DEFAULT 0,
    donor_score INTEGER DEFAULT 0,
    volunteer_score INTEGER DEFAULT 0,
    engagement_score INTEGER DEFAULT 0,
    influence_score INTEGER DEFAULT 0,
    
    -- Communication Preferences
    email_opt_in BOOLEAN DEFAULT true,
    sms_opt_in BOOLEAN DEFAULT false,
    phone_opt_in BOOLEAN DEFAULT true,
    mail_opt_in BOOLEAN DEFAULT true,
    preferred_channel VARCHAR(50),
    best_time_to_contact VARCHAR(50),
    language_preference VARCHAR(50) DEFAULT 'en',
    
    -- Relationships
    household_id UUID,
    spouse_contact_id UUID,
    referred_by_contact_id UUID,
    
    -- Source Tracking
    source VARCHAR(100),
    source_detail VARCHAR(255),
    acquisition_date DATE DEFAULT CURRENT_DATE,
    
    -- Deduplication
    email_hash VARCHAR(64),
    phone_hash VARCHAR(64),
    name_address_hash VARCHAR(64),
    merged_into_id UUID,
    
    -- Metadata
    tags JSONB DEFAULT '[]',
    custom_fields JSONB DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_activity_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts(email);
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone);
CREATE INDEX IF NOT EXISTS idx_contacts_name ON contacts(last_name, first_name);
CREATE INDEX IF NOT EXISTS idx_contacts_zip ON contacts(zip_code);
CREATE INDEX IF NOT EXISTS idx_contacts_type ON contacts(primary_type);
CREATE INDEX IF NOT EXISTS idx_contacts_status ON contacts(status);
CREATE INDEX IF NOT EXISTS idx_contacts_household ON contacts(household_id);
CREATE INDEX IF NOT EXISTS idx_contacts_email_hash ON contacts(email_hash);
CREATE INDEX IF NOT EXISTS idx_contacts_tags ON contacts USING gin(tags);

-- Contact Activity History
CREATE TABLE IF NOT EXISTS contact_activities (
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID REFERENCES contacts(contact_id),
    activity_type VARCHAR(100) NOT NULL,
    activity_subtype VARCHAR(100),
    channel VARCHAR(50),
    direction VARCHAR(20),
    subject VARCHAR(500),
    description TEXT,
    outcome VARCHAR(100),
    campaign_id UUID,
    content_id UUID,
    amount DECIMAL(12,2),
    metadata JSONB DEFAULT '{}',
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activities_contact ON contact_activities(contact_id);
CREATE INDEX IF NOT EXISTS idx_activities_type ON contact_activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_created ON contact_activities(created_at);

-- Households
CREATE TABLE IF NOT EXISTS households (
    household_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_name VARCHAR(255),
    address_line1 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    member_count INTEGER DEFAULT 1,
    total_donations DECIMAL(14,2) DEFAULT 0,
    household_score INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_households_zip ON households(zip_code);

-- Relationships
CREATE TABLE IF NOT EXISTS contact_relationships (
    relationship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id_a UUID REFERENCES contacts(contact_id),
    contact_id_b UUID REFERENCES contacts(contact_id),
    relationship_type VARCHAR(50) NOT NULL,
    is_bidirectional BOOLEAN DEFAULT true,
    strength INTEGER DEFAULT 5,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_relationships_a ON contact_relationships(contact_id_a);
CREATE INDEX IF NOT EXISTS idx_relationships_b ON contact_relationships(contact_id_b);

-- Duplicate Candidates
CREATE TABLE IF NOT EXISTS duplicate_candidates (
    duplicate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id_a UUID REFERENCES contacts(contact_id),
    contact_id_b UUID REFERENCES contacts(contact_id),
    match_score DECIMAL(5,2),
    match_reasons JSONB DEFAULT '[]',
    status VARCHAR(50) DEFAULT 'pending',
    reviewed_by VARCHAR(255),
    reviewed_at TIMESTAMP,
    merged_into UUID,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_duplicates_status ON duplicate_candidates(status);

-- Communication Log
CREATE TABLE IF NOT EXISTS communication_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID REFERENCES contacts(contact_id),
    channel VARCHAR(50) NOT NULL,
    direction VARCHAR(20) NOT NULL,
    status VARCHAR(50),
    subject VARCHAR(500),
    content_preview TEXT,
    campaign_id UUID,
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    bounced BOOLEAN DEFAULT false,
    unsubscribed BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comm_contact ON communication_log(contact_id);
CREATE INDEX IF NOT EXISTS idx_comm_channel ON communication_log(channel);
CREATE INDEX IF NOT EXISTS idx_comm_sent ON communication_log(sent_at);

-- Views
CREATE OR REPLACE VIEW v_contact_360 AS
SELECT 
    c.*,
    h.household_name,
    h.total_donations as household_donations,
    (SELECT COUNT(*) FROM contact_activities ca WHERE ca.contact_id = c.contact_id) as activity_count,
    (SELECT MAX(created_at) FROM contact_activities ca WHERE ca.contact_id = c.contact_id) as last_activity,
    (SELECT COUNT(*) FROM communication_log cl WHERE cl.contact_id = c.contact_id) as comm_count
FROM contacts c
LEFT JOIN households h ON c.household_id = h.household_id
WHERE c.status = 'active';

CREATE OR REPLACE VIEW v_contact_summary AS
SELECT 
    primary_type,
    status,
    COUNT(*) as count,
    AVG(overall_score) as avg_score,
    COUNT(*) FILTER (WHERE email_opt_in) as email_opted_in,
    COUNT(*) FILTER (WHERE sms_opt_in) as sms_opted_in
FROM contacts
GROUP BY primary_type, status;

CREATE OR REPLACE VIEW v_recent_activities AS
SELECT 
    ca.activity_id,
    ca.activity_type,
    ca.channel,
    ca.created_at,
    c.full_name,
    c.email,
    ca.description
FROM contact_activities ca
JOIN contacts c ON ca.contact_id = c.contact_id
ORDER BY ca.created_at DESC
LIMIT 100;

SELECT 'Contact Directory schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_16_tv_radio_complete.py (E16)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 16: TV/RADIO AI PRODUCTION SYSTEM
-- ============================================================================

-- Ad Campaigns
CREATE TABLE IF NOT EXISTS tv_radio_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    budget DECIMAL(12,2),
    start_date DATE,
    end_date DATE,
    status VARCHAR(50) DEFAULT 'active',
    total_ads INTEGER DEFAULT 0,
    total_spent DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_campaigns_candidate ON tv_radio_campaigns(candidate_id);
CREATE INDEX IF NOT EXISTS idx_tv_campaigns_status ON tv_radio_campaigns(status);

-- Voice Profiles
CREATE TABLE IF NOT EXISTS tv_radio_voices (
    voice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    provider_voice_id VARCHAR(255),
    gender VARCHAR(20),
    tone VARCHAR(100),
    language VARCHAR(10) DEFAULT 'en-US',
    sample_url TEXT,
    is_default BOOLEAN DEFAULT false,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_voices_candidate ON tv_radio_voices(candidate_id);

-- Ad Scripts
CREATE TABLE IF NOT EXISTS tv_radio_scripts (
    script_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES tv_radio_campaigns(campaign_id),
    candidate_id UUID,
    ad_type VARCHAR(50) NOT NULL,
    duration INTEGER NOT NULL,
    tone VARCHAR(50),
    title VARCHAR(255),
    headline TEXT,
    body TEXT NOT NULL,
    call_to_action TEXT,
    disclaimer TEXT,
    word_count INTEGER,
    estimated_duration DECIMAL(5,2),
    ai_generated BOOLEAN DEFAULT false,
    ai_model VARCHAR(100),
    ai_prompt TEXT,
    status VARCHAR(50) DEFAULT 'draft',
    version INTEGER DEFAULT 1,
    parent_script_id UUID,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_scripts_campaign ON tv_radio_scripts(campaign_id);
CREATE INDEX IF NOT EXISTS idx_tv_scripts_status ON tv_radio_scripts(status);

-- Produced Ads
CREATE TABLE IF NOT EXISTS tv_radio_ads (
    ad_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    script_id UUID REFERENCES tv_radio_scripts(script_id),
    campaign_id UUID REFERENCES tv_radio_campaigns(campaign_id),
    candidate_id UUID,
    ad_type VARCHAR(50) NOT NULL,
    title VARCHAR(255),
    duration INTEGER NOT NULL,
    voice_id UUID REFERENCES tv_radio_voices(voice_id),
    status VARCHAR(50) DEFAULT 'production',
    
    -- File paths
    audio_file TEXT,
    video_file TEXT,
    thumbnail_file TEXT,
    
    -- Technical specs
    video_width INTEGER,
    video_height INTEGER,
    video_fps INTEGER,
    video_codec VARCHAR(50),
    audio_codec VARCHAR(50),
    audio_sample_rate INTEGER,
    audio_lufs DECIMAL(5,2),
    
    -- Production metadata
    production_started_at TIMESTAMP,
    production_completed_at TIMESTAMP,
    production_duration_seconds INTEGER,
    production_cost DECIMAL(10,4),
    
    -- Approval
    approved_by UUID,
    approved_at TIMESTAMP,
    rejection_reason TEXT,
    
    -- Publishing
    published_at TIMESTAMP,
    published_platforms JSONB DEFAULT '[]',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_ads_campaign ON tv_radio_ads(campaign_id);
CREATE INDEX IF NOT EXISTS idx_tv_ads_status ON tv_radio_ads(status);
CREATE INDEX IF NOT EXISTS idx_tv_ads_type ON tv_radio_ads(ad_type);

-- Media Assets (B-roll, images, music)
CREATE TABLE IF NOT EXISTS tv_radio_assets (
    asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    asset_type VARCHAR(50) NOT NULL,  -- video, image, audio, music
    name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    mime_type VARCHAR(100),
    duration DECIMAL(10,2),
    width INTEGER,
    height INTEGER,
    file_size BIGINT,
    tags JSONB DEFAULT '[]',
    license_type VARCHAR(100),
    license_expiry DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_assets_candidate ON tv_radio_assets(candidate_id);
CREATE INDEX IF NOT EXISTS idx_tv_assets_type ON tv_radio_assets(asset_type);

-- News Feed (for rapid response)
CREATE TABLE IF NOT EXISTS tv_radio_news_feed (
    news_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(255),
    title TEXT NOT NULL,
    description TEXT,
    url TEXT,
    published_at TIMESTAMP,
    relevance_score DECIMAL(5,4),
    sentiment VARCHAR(20),
    topics JSONB DEFAULT '[]',
    entities JSONB DEFAULT '[]',
    rapid_response_triggered BOOLEAN DEFAULT false,
    rapid_response_ad_id UUID,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_news_published ON tv_radio_news_feed(published_at);
CREATE INDEX IF NOT EXISTS idx_tv_news_relevance ON tv_radio_news_feed(relevance_score);

-- Production Queue
CREATE TABLE IF NOT EXISTS tv_radio_production_queue (
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ad_id UUID REFERENCES tv_radio_ads(ad_id),
    priority INTEGER DEFAULT 5,
    status VARCHAR(50) DEFAULT 'pending',
    worker_id VARCHAR(100),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_queue_status ON tv_radio_production_queue(status, priority);

-- FCC Compliance Log
CREATE TABLE IF NOT EXISTS tv_radio_compliance_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ad_id UUID REFERENCES tv_radio_ads(ad_id),
    check_type VARCHAR(100) NOT NULL,
    passed BOOLEAN NOT NULL,
    details JSONB,
    checked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_compliance_ad ON tv_radio_compliance_log(ad_id);

-- Cost Tracking
CREATE TABLE IF NOT EXISTS tv_radio_costs (
    cost_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ad_id UUID,
    cost_type VARCHAR(100) NOT NULL,  -- ai_generation, voice_synthesis, video_render, storage
    amount DECIMAL(10,4) NOT NULL,
    provider VARCHAR(100),
    details JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_costs_ad ON tv_radio_costs(ad_id);

-- Daily Production Stats
CREATE TABLE IF NOT EXISTS tv_radio_daily_stats (
    date DATE PRIMARY KEY,
    total_scripts_generated INTEGER DEFAULT 0,
    total_ads_produced INTEGER DEFAULT 0,
    total_tv_spots INTEGER DEFAULT 0,
    total_radio_spots INTEGER DEFAULT 0,
    total_digital INTEGER DEFAULT 0,
    total_production_time_seconds INTEGER DEFAULT 0,
    total_cost DECIMAL(10,4) DEFAULT 0,
    avg_production_time DECIMAL(10,2) DEFAULT 0
);

-- Campaign Performance View
CREATE OR REPLACE VIEW v_tv_radio_campaign_stats AS
SELECT 
    c.campaign_id,
    c.name,
    c.status,
    c.budget,
    c.total_spent,
    COUNT(DISTINCT a.ad_id) as total_ads,
    COUNT(DISTINCT CASE WHEN a.ad_type = 'tv_spot' THEN a.ad_id END) as tv_spots,
    COUNT(DISTINCT CASE WHEN a.ad_type = 'radio_spot' THEN a.ad_id END) as radio_spots,
    COUNT(DISTINCT CASE WHEN a.status = 'published' THEN a.ad_id END) as published_ads,
    AVG(a.production_duration_seconds) as avg_production_time,
    SUM(a.production_cost) as total_production_cost
FROM tv_radio_campaigns c
LEFT JOIN tv_radio_ads a ON c.campaign_id = a.campaign_id
GROUP BY c.campaign_id, c.name, c.status, c.budget, c.total_spent;

-- Ad Library View
CREATE OR REPLACE VIEW v_tv_radio_ad_library AS
SELECT 
    a.ad_id,
    a.title,
    a.ad_type,
    a.duration,
    a.status,
    s.tone,
    s.headline,
    s.body,
    s.call_to_action,
    v.name as voice_name,
    a.video_file,
    a.audio_file,
    a.thumbnail_file,
    a.production_completed_at,
    a.published_at,
    c.name as campaign_name
FROM tv_radio_ads a
LEFT JOIN tv_radio_scripts s ON a.script_id = s.script_id
LEFT JOIN tv_radio_voices v ON a.voice_id = v.voice_id
LEFT JOIN tv_radio_campaigns c ON a.campaign_id = c.campaign_id
ORDER BY a.created_at DESC;

SELECT 'TV/Radio AI schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_17_rvm_complete.py (E17)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 17: RINGLESS VOICEMAIL (RVM) - ENTERPRISE
-- Political Campaign Edition (DNC Exempt)
-- ============================================================================

-- AI Voice Profiles (for voice cloning)
CREATE TABLE IF NOT EXISTS rvm_voice_profiles (
    voice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Voice identity
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Source audio for cloning
    sample_audio_url TEXT,
    sample_duration_seconds INTEGER,
    
    -- AI model
    voice_model_id VARCHAR(255),
    voice_provider VARCHAR(50) DEFAULT 'elevenlabs',
    
    -- Characteristics
    gender VARCHAR(20),
    age_range VARCHAR(20),
    accent VARCHAR(50),
    tone VARCHAR(50),  -- friendly, professional, urgent
    
    -- Languages supported
    languages JSONB DEFAULT '["en"]',
    
    -- Status
    is_trained BOOLEAN DEFAULT false,
    trained_at TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_voice_candidate ON rvm_voice_profiles(candidate_id);

-- Audio Files (with AI generation support)
CREATE TABLE IF NOT EXISTS rvm_audio_files (
    audio_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    voice_id UUID REFERENCES rvm_voice_profiles(voice_id),
    
    -- File info
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Source type
    source_type VARCHAR(50) DEFAULT 'upload',  -- upload, recorded, ai_generated, ai_cloned
    
    -- Script (for AI generation)
    script_text TEXT,
    personalization_tokens JSONB DEFAULT '[]',  -- [{first_name}, {amount}, etc.]
    
    -- Generated audio
    file_url TEXT,
    file_size_bytes INTEGER,
    
    -- Audio properties
    duration_seconds INTEGER NOT NULL,
    format VARCHAR(20) DEFAULT 'mp3',
    sample_rate INTEGER DEFAULT 44100,
    bitrate INTEGER DEFAULT 128,
    
    -- AI generation settings
    ai_voice_settings JSONB DEFAULT '{}',
    language VARCHAR(10) DEFAULT 'en',
    
    -- Transcription
    transcript TEXT,
    
    -- Approval workflow
    approval_status VARCHAR(50) DEFAULT 'pending',
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    
    -- Performance stats
    times_used INTEGER DEFAULT 0,
    total_drops INTEGER DEFAULT 0,
    avg_callback_rate DECIMAL(5,2),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rvm_audio_candidate ON rvm_audio_files(candidate_id);

-- RVM Campaigns
CREATE TABLE IF NOT EXISTS rvm_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Campaign info
    name VARCHAR(500) NOT NULL,
    description TEXT,
    campaign_type VARCHAR(50) DEFAULT 'standard',  -- standard, drip, ab_test, gotv, fundraising
    
    -- Primary audio
    audio_id UUID REFERENCES rvm_audio_files(audio_id),
    
    -- Targeting (political specific)
    target_list_id UUID,
    target_query JSONB,
    voter_file_segment VARCHAR(255),  -- e.g., "likely_R_voters", "sporadic_voters"
    
    -- Scheduling
    scheduled_start TIMESTAMP,
    scheduled_end TIMESTAMP,
    
    -- Time zone handling
    time_zone VARCHAR(50) DEFAULT 'recipient',
    fixed_time_zone VARCHAR(50),
    
    -- Delivery windows (best practice, not legally required for political)
    delivery_start_hour INTEGER DEFAULT 9,
    delivery_end_hour INTEGER DEFAULT 20,
    days_of_week JSONB DEFAULT '[0,1,2,3,4,5,6]',  -- All days available for political
    
    -- Throttling for callback management
    drops_per_hour INTEGER DEFAULT 10000,
    max_callbacks_per_hour INTEGER,
    
    -- Drip settings
    is_drip BOOLEAN DEFAULT false,
    drip_days INTEGER DEFAULT 1,
    drip_daily_limit INTEGER,
    
    -- A/B Testing
    is_ab_test BOOLEAN DEFAULT false,
    ab_test_config JSONB DEFAULT '{}',
    
    -- Tracking
    tracking_number VARCHAR(20),
    vanity_url VARCHAR(255),
    
    -- Stats
    total_recipients INTEGER DEFAULT 0,
    drops_attempted INTEGER DEFAULT 0,
    drops_delivered INTEGER DEFAULT 0,
    drops_failed INTEGER DEFAULT 0,
    callbacks_received INTEGER DEFAULT 0,
    texts_received INTEGER DEFAULT 0,
    
    -- Carrier breakdown
    carrier_stats JSONB DEFAULT '{}',
    
    -- Cost
    estimated_cost DECIMAL(12,2),
    actual_cost DECIMAL(12,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    
    -- Timing
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    paused_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rvm_campaign_candidate ON rvm_campaigns(candidate_id);
CREATE INDEX IF NOT EXISTS idx_rvm_campaign_status ON rvm_campaigns(status);

-- A/B Test Variants
CREATE TABLE IF NOT EXISTS rvm_ab_variants (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES rvm_campaigns(campaign_id),
    
    variant_name VARCHAR(50) NOT NULL,
    variant_description TEXT,
    audio_id UUID REFERENCES rvm_audio_files(audio_id),
    traffic_percent INTEGER DEFAULT 50,
    
    -- Stats
    recipients INTEGER DEFAULT 0,
    drops_delivered INTEGER DEFAULT 0,
    callbacks INTEGER DEFAULT 0,
    callback_rate DECIMAL(5,2),
    conversions INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5,2),
    
    is_winner BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_variant_campaign ON rvm_ab_variants(campaign_id);

-- Recipients with carrier intelligence
CREATE TABLE IF NOT EXISTS rvm_recipients (
    recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES rvm_campaigns(campaign_id),
    
    -- Contact info
    contact_id UUID,
    voter_id VARCHAR(100),  -- State voter file ID
    phone_number VARCHAR(20) NOT NULL,
    phone_hash VARCHAR(64),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    
    -- Personalization data
    personalization_data JSONB DEFAULT '{}',
    
    -- Voter data (for political targeting)
    party_affiliation VARCHAR(20),
    voter_score INTEGER,
    precinct VARCHAR(50),
    congressional_district VARCHAR(10),
    state_house_district VARCHAR(10),
    state_senate_district VARCHAR(10),
    
    -- Carrier intelligence
    carrier VARCHAR(50),
    carrier_type VARCHAR(20),
    line_type VARCHAR(20),
    is_mobile BOOLEAN,
    
    -- Location
    time_zone VARCHAR(50),
    state VARCHAR(50),
    county VARCHAR(100),
    
    -- Scheduling
    scheduled_at TIMESTAMP,
    optimal_time TIMESTAMP,
    
    -- A/B assignment
    ab_variant VARCHAR(10),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    
    -- Delivery tracking
    queued_at TIMESTAMP,
    attempted_at TIMESTAMP,
    delivered_at TIMESTAMP,
    
    -- Carrier response
    carrier_response_code VARCHAR(50),
    carrier_response_message TEXT,
    delivery_duration_ms INTEGER,
    
    -- Response tracking
    callback_received BOOLEAN DEFAULT false,
    callback_at TIMESTAMP,
    text_received BOOLEAN DEFAULT false,
    text_at TIMESTAMP,
    
    -- Cost
    cost DECIMAL(6,4),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rvm_recipient_campaign ON rvm_recipients(campaign_id);
CREATE INDEX IF NOT EXISTS idx_rvm_recipient_status ON rvm_recipients(status);
CREATE INDEX IF NOT EXISTS idx_rvm_recipient_phone ON rvm_recipients(phone_number);
CREATE INDEX IF NOT EXISTS idx_rvm_recipient_voter ON rvm_recipients(voter_id);
CREATE INDEX IF NOT EXISTS idx_rvm_recipient_carrier ON rvm_recipients(carrier);

-- Callback Tracking
CREATE TABLE IF NOT EXISTS rvm_callbacks (
    callback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    campaign_id UUID REFERENCES rvm_campaigns(campaign_id),
    recipient_id UUID REFERENCES rvm_recipients(recipient_id),
    ab_variant VARCHAR(10),
    
    from_number VARCHAR(20) NOT NULL,
    to_number VARCHAR(20) NOT NULL,
    
    callback_time TIMESTAMP NOT NULL,
    time_since_drop_minutes INTEGER,
    
    duration_seconds INTEGER,
    recording_url TEXT,
    
    answered BOOLEAN DEFAULT false,
    answered_by VARCHAR(50),
    outcome VARCHAR(100),
    disposition VARCHAR(100),
    
    -- Political specific
    voter_contacted BOOLEAN DEFAULT false,
    pledge_received BOOLEAN DEFAULT false,
    volunteer_signup BOOLEAN DEFAULT false,
    donation_made BOOLEAN DEFAULT false,
    donation_amount DECIMAL(12,2),
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rvm_callback_campaign ON rvm_callbacks(campaign_id);

-- Text Replies
CREATE TABLE IF NOT EXISTS rvm_text_replies (
    reply_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    campaign_id UUID REFERENCES rvm_campaigns(campaign_id),
    recipient_id UUID REFERENCES rvm_recipients(recipient_id),
    
    from_number VARCHAR(20) NOT NULL,
    to_number VARCHAR(20) NOT NULL,
    message_text TEXT,
    
    received_at TIMESTAMP DEFAULT NOW(),
    time_since_drop_minutes INTEGER,
    
    auto_responded BOOLEAN DEFAULT false,
    auto_response_text TEXT,
    
    -- Best practice: honor explicit opt-outs even though not required
    is_opt_out BOOLEAN DEFAULT false,
    requires_followup BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rvm_text_campaign ON rvm_text_replies(campaign_id);

-- Opt-Out List (Best Practice - not legally required for political)
-- Honoring opt-outs reduces complaints and improves deliverability
CREATE TABLE IF NOT EXISTS rvm_optout_list (
    optout_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    phone_number VARCHAR(20) NOT NULL,
    phone_hash VARCHAR(64) UNIQUE,
    
    -- Source
    source VARCHAR(100) NOT NULL,  -- text_reply, callback_request, web_form, complaint
    
    -- Details
    optout_reason TEXT,
    
    added_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rvm_optout_hash ON rvm_optout_list(phone_hash);

-- Carrier Lookup Cache
CREATE TABLE IF NOT EXISTS rvm_carrier_cache (
    cache_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    phone_number VARCHAR(20) NOT NULL,
    phone_hash VARCHAR(64) UNIQUE,
    
    carrier VARCHAR(100),
    carrier_type VARCHAR(20),
    line_type VARCHAR(20),
    is_mobile BOOLEAN,
    is_ported BOOLEAN,
    original_carrier VARCHAR(100),
    
    country VARCHAR(10),
    
    lookup_provider VARCHAR(50),
    looked_up_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rvm_carrier_hash ON rvm_carrier_cache(phone_hash);

-- Virtual Assistant Scripts
CREATE TABLE IF NOT EXISTS rvm_ivr_scripts (
    script_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES rvm_campaigns(campaign_id),
    
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    greeting_audio_id UUID REFERENCES rvm_audio_files(audio_id),
    menu_options JSONB DEFAULT '[]',
    
    auto_text_reply TEXT,
    
    transfer_number VARCHAR(20),
    voicemail_enabled BOOLEAN DEFAULT true,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Delivery Batches
CREATE TABLE IF NOT EXISTS rvm_delivery_batches (
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES rvm_campaigns(campaign_id),
    
    batch_number INTEGER,
    batch_size INTEGER,
    
    provider VARCHAR(50),
    provider_batch_id VARCHAR(255),
    
    status VARCHAR(50) DEFAULT 'pending',
    
    created_at TIMESTAMP DEFAULT NOW(),
    submitted_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    delivered INTEGER DEFAULT 0,
    failed INTEGER DEFAULT 0,
    
    carrier_results JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_rvm_batch_campaign ON rvm_delivery_batches(campaign_id);

-- Views
CREATE OR REPLACE VIEW v_rvm_campaign_performance AS
SELECT 
    c.campaign_id,
    c.name,
    c.status,
    c.total_recipients,
    c.drops_attempted,
    c.drops_delivered,
    c.drops_failed,
    c.callbacks_received,
    c.texts_received,
    CASE WHEN c.drops_attempted > 0 
         THEN ROUND((c.drops_delivered::DECIMAL / c.drops_attempted) * 100, 2)
         ELSE 0 END as delivery_rate,
    CASE WHEN c.drops_delivered > 0
         THEN ROUND((c.callbacks_received::DECIMAL / c.drops_delivered) * 100, 2)
         ELSE 0 END as callback_rate,
    c.actual_cost,
    CASE WHEN c.callbacks_received > 0
         THEN ROUND(c.actual_cost / c.callbacks_received, 2)
         ELSE 0 END as cost_per_callback
FROM rvm_campaigns c;

CREATE OR REPLACE VIEW v_rvm_carrier_performance AS
SELECT 
    r.carrier,
    COUNT(*) as total_drops,
    COUNT(*) FILTER (WHERE r.status = 'delivered') as delivered,
    COUNT(*) FILTER (WHERE r.status IN ('carrier_rejected', 'mailbox_full', 'no_voicemail')) as failed,
    ROUND(AVG(CASE WHEN r.status = 'delivered' THEN 1 ELSE 0 END) * 100, 2) as delivery_rate,
    COUNT(*) FILTER (WHERE r.callback_received = true) as callbacks,
    ROUND(AVG(CASE WHEN r.callback_received THEN 1 ELSE 0 END) * 100, 2) as callback_rate
FROM rvm_recipients r
WHERE r.carrier IS NOT NULL
GROUP BY r.carrier
ORDER BY total_drops DESC;

CREATE OR REPLACE VIEW v_rvm_ab_test_results AS
SELECT 
    c.campaign_id,
    c.name as campaign_name,
    v.variant_name,
    v.audio_id,
    a.name as audio_name,
    v.traffic_percent,
    v.recipients,
    v.drops_delivered,
    v.callbacks,
    v.callback_rate,
    v.conversions,
    v.conversion_rate,
    v.is_winner
FROM rvm_ab_variants v
JOIN rvm_campaigns c ON v.campaign_id = c.campaign_id
JOIN rvm_audio_files a ON v.audio_id = a.audio_id
WHERE c.is_ab_test = true
ORDER BY c.campaign_id, v.variant_name;

SELECT 'RVM Enterprise (Political) schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_18_print_advertising_complete.py (E18)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 18: PRINT ADVERTISING
-- ============================================================================

-- Publications Database
CREATE TABLE IF NOT EXISTS publications (
    publication_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(500) NOT NULL,
    publication_type VARCHAR(50) NOT NULL,
    frequency VARCHAR(50),
    
    -- Contact Info
    contact_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address_line1 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    
    -- Circulation
    circulation INTEGER,
    readership INTEGER,
    
    -- Geographic Coverage
    coverage_area VARCHAR(255),
    counties_covered JSONB DEFAULT '[]',
    cities_covered JSONB DEFAULT '[]',
    
    -- Demographics
    demographic_profile JSONB DEFAULT '{}',
    political_lean VARCHAR(50),
    
    -- Deadlines
    space_deadline_days INTEGER DEFAULT 7,
    material_deadline_days INTEGER DEFAULT 3,
    
    -- Rates
    rate_card_url TEXT,
    base_rate_per_column_inch DECIMAL(10,2),
    political_rate_multiplier DECIMAL(4,2) DEFAULT 1.0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    last_used TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pubs_type ON publications(publication_type);
CREATE INDEX IF NOT EXISTS idx_pubs_state ON publications(state);
CREATE INDEX IF NOT EXISTS idx_pubs_active ON publications(is_active);

-- Rate Cards
CREATE TABLE IF NOT EXISTS publication_rates (
    rate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publication_id UUID REFERENCES publications(publication_id),
    ad_size VARCHAR(50) NOT NULL,
    ad_type VARCHAR(50) DEFAULT 'display',
    color_type VARCHAR(20) DEFAULT 'bw',
    placement VARCHAR(100),
    rate DECIMAL(12,2) NOT NULL,
    frequency_discount JSONB DEFAULT '{}',
    effective_date DATE DEFAULT CURRENT_DATE,
    expire_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rates_pub ON publication_rates(publication_id);
CREATE INDEX IF NOT EXISTS idx_rates_size ON publication_rates(ad_size);

-- Ad Creatives
CREATE TABLE IF NOT EXISTS print_ad_creatives (
    creative_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    name VARCHAR(500) NOT NULL,
    ad_size VARCHAR(50) NOT NULL,
    
    -- Artwork
    artwork_url TEXT,
    artwork_format VARCHAR(50),
    width_inches DECIMAL(6,2),
    height_inches DECIMAL(6,2),
    resolution_dpi INTEGER DEFAULT 300,
    color_mode VARCHAR(20) DEFAULT 'cmyk',
    bleed BOOLEAN DEFAULT false,
    
    -- Content
    headline TEXT,
    body_copy TEXT,
    call_to_action TEXT,
    disclaimer TEXT,
    
    -- Compliance
    has_disclaimer BOOLEAN DEFAULT false,
    disclaimer_text TEXT,
    paid_for_by TEXT,
    
    -- Approval
    status VARCHAR(50) DEFAULT 'draft',
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    
    -- Versions
    version INTEGER DEFAULT 1,
    parent_creative_id UUID,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_creatives_candidate ON print_ad_creatives(candidate_id);
CREATE INDEX IF NOT EXISTS idx_creatives_size ON print_ad_creatives(ad_size);

-- Insertion Orders
CREATE TABLE IF NOT EXISTS insertion_orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE,
    candidate_id UUID,
    campaign_id UUID,
    publication_id UUID REFERENCES publications(publication_id),
    
    -- Order Details
    status VARCHAR(50) DEFAULT 'draft',
    ad_type VARCHAR(50) DEFAULT 'display',
    ad_size VARCHAR(50) NOT NULL,
    color_type VARCHAR(20) DEFAULT 'bw',
    placement_preference TEXT,
    
    -- Schedule
    run_dates JSONB DEFAULT '[]',
    start_date DATE,
    end_date DATE,
    num_insertions INTEGER DEFAULT 1,
    
    -- Creative
    creative_id UUID REFERENCES print_ad_creatives(creative_id),
    
    -- Pricing
    rate_per_insertion DECIMAL(12,2),
    total_gross DECIMAL(14,2),
    agency_commission_pct DECIMAL(5,2) DEFAULT 15.0,
    agency_commission DECIMAL(12,2),
    total_net DECIMAL(14,2),
    
    -- Deadlines
    space_deadline DATE,
    material_deadline DATE,
    
    -- Tracking
    confirmation_number VARCHAR(100),
    po_number VARCHAR(100),
    
    -- Proof
    proof_url TEXT,
    proof_approved BOOLEAN DEFAULT false,
    proof_approved_by VARCHAR(255),
    proof_approved_at TIMESTAMP,
    
    -- Invoice
    invoice_number VARCHAR(100),
    invoice_amount DECIMAL(12,2),
    invoice_date DATE,
    paid_date DATE,
    
    notes TEXT,
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_candidate ON insertion_orders(candidate_id);
CREATE INDEX IF NOT EXISTS idx_orders_publication ON insertion_orders(publication_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON insertion_orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_dates ON insertion_orders(start_date, end_date);

-- Publication Calendar (track issue dates)
CREATE TABLE IF NOT EXISTS publication_calendar (
    calendar_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publication_id UUID REFERENCES publications(publication_id),
    issue_date DATE NOT NULL,
    issue_name VARCHAR(255),
    space_deadline DATE,
    material_deadline DATE,
    special_section VARCHAR(255),
    theme VARCHAR(255),
    bonus_distribution BOOLEAN DEFAULT false,
    circulation_boost INTEGER,
    rate_premium_pct DECIMAL(5,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendar_pub ON publication_calendar(publication_id);
CREATE INDEX IF NOT EXISTS idx_calendar_date ON publication_calendar(issue_date);

-- Ad Performance Tracking
CREATE TABLE IF NOT EXISTS print_ad_performance (
    performance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES insertion_orders(order_id),
    issue_date DATE,
    
    -- Reach
    circulation INTEGER,
    estimated_readership INTEGER,
    geographic_reach VARCHAR(255),
    
    -- Response (if trackable)
    unique_url VARCHAR(255),
    qr_code_url TEXT,
    tracking_phone VARCHAR(20),
    
    -- Measured Response
    url_visits INTEGER DEFAULT 0,
    qr_scans INTEGER DEFAULT 0,
    phone_calls INTEGER DEFAULT 0,
    donations_attributed INTEGER DEFAULT 0,
    donation_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Calculated Metrics
    cost_per_thousand DECIMAL(10,2),
    cost_per_response DECIMAL(10,2),
    roi_pct DECIMAL(8,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_perf_order ON print_ad_performance(order_id);

-- Views
CREATE OR REPLACE VIEW v_publication_summary AS
SELECT 
    p.publication_id,
    p.name,
    p.publication_type,
    p.state,
    p.circulation,
    p.is_active,
    COUNT(DISTINCT io.order_id) as total_orders,
    SUM(io.total_net) as total_spend,
    MAX(io.end_date) as last_ad_date
FROM publications p
LEFT JOIN insertion_orders io ON p.publication_id = io.publication_id
GROUP BY p.publication_id;

CREATE OR REPLACE VIEW v_active_orders AS
SELECT 
    io.*,
    p.name as publication_name,
    p.contact_email,
    pac.name as creative_name,
    pac.artwork_url
FROM insertion_orders io
JOIN publications p ON io.publication_id = p.publication_id
LEFT JOIN print_ad_creatives pac ON io.creative_id = pac.creative_id
WHERE io.status NOT IN ('cancelled', 'paid')
ORDER BY io.material_deadline;

CREATE OR REPLACE VIEW v_upcoming_deadlines AS
SELECT 
    io.order_id,
    io.order_number,
    p.name as publication_name,
    io.ad_size,
    io.space_deadline,
    io.material_deadline,
    io.status,
    CASE 
        WHEN io.material_deadline <= CURRENT_DATE THEN 'overdue'
        WHEN io.material_deadline <= CURRENT_DATE + 2 THEN 'urgent'
        WHEN io.material_deadline <= CURRENT_DATE + 7 THEN 'upcoming'
        ELSE 'scheduled'
    END as urgency
FROM insertion_orders io
JOIN publications p ON io.publication_id = p.publication_id
WHERE io.status IN ('draft', 'submitted', 'confirmed', 'creative_pending')
ORDER BY io.material_deadline;

CREATE OR REPLACE VIEW v_campaign_print_spend AS
SELECT 
    io.campaign_id,
    io.candidate_id,
    COUNT(*) as total_orders,
    SUM(io.num_insertions) as total_insertions,
    SUM(io.total_net) as total_spend,
    SUM(pap.circulation * io.num_insertions) as total_impressions,
    SUM(pap.donation_amount) as attributed_revenue
FROM insertion_orders io
LEFT JOIN print_ad_performance pap ON io.order_id = pap.order_id
WHERE io.status NOT IN ('cancelled', 'draft')
GROUP BY io.campaign_id, io.candidate_id;

SELECT 'Print Advertising schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_18_vdp_composition_engine_complete.py (E18)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 18: VDP COMPOSITION ENGINE
-- ============================================================================

-- Composition Templates
CREATE TABLE IF NOT EXISTS vdp_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(500) NOT NULL,
    description TEXT,
    piece_type VARCHAR(50) NOT NULL,
    size VARCHAR(50),
    
    -- Template files
    master_template_url TEXT,
    template_format VARCHAR(50),
    
    -- Variable zones defined in template
    variable_zones JSONB DEFAULT '[]',
    
    -- Default content
    default_headline TEXT,
    default_body TEXT,
    default_image_url TEXT,
    
    -- Compliance
    disclaimer_zone VARCHAR(100),
    disclaimer_text TEXT,
    paid_for_by TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vdp_templates_type ON vdp_templates(piece_type);

-- Personalization Rules
CREATE TABLE IF NOT EXISTS vdp_personalization_rules (
    rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES vdp_templates(template_id),
    rule_name VARCHAR(255) NOT NULL,
    variable_zone VARCHAR(100) NOT NULL,
    variable_type VARCHAR(50) NOT NULL,
    
    -- Conditions (when to apply this rule)
    conditions JSONB DEFAULT '{}',
    
    -- Content options
    content_options JSONB DEFAULT '[]',
    
    -- AI generation settings
    use_ai_generation BOOLEAN DEFAULT false,
    ai_prompt_template TEXT,
    
    -- Priority (higher = checked first)
    priority INTEGER DEFAULT 50,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vdp_rules_template ON vdp_personalization_rules(template_id);
CREATE INDEX IF NOT EXISTS idx_vdp_rules_zone ON vdp_personalization_rules(variable_zone);

-- Composition Jobs
CREATE TABLE IF NOT EXISTS vdp_composition_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_number VARCHAR(50) UNIQUE,
    campaign_id UUID,
    candidate_id UUID,
    template_id UUID REFERENCES vdp_templates(template_id),
    
    -- Job settings
    personalization_level VARCHAR(50) DEFAULT 'advanced',
    output_format VARCHAR(50) DEFAULT 'csv',
    
    -- Recipients
    total_recipients INTEGER DEFAULT 0,
    
    -- Processing
    status VARCHAR(50) DEFAULT 'pending',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Output
    output_file_url TEXT,
    proof_pdf_url TEXT,
    
    -- Stats
    unique_variants INTEGER DEFAULT 0,
    processing_time_seconds INTEGER,
    
    -- Vendor delivery
    vendor_id UUID,
    delivered_to_vendor BOOLEAN DEFAULT false,
    delivered_at TIMESTAMP,
    
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vdp_jobs_status ON vdp_composition_jobs(status);
CREATE INDEX IF NOT EXISTS idx_vdp_jobs_campaign ON vdp_composition_jobs(campaign_id);

-- Recipient Variable Data (generated output)
CREATE TABLE IF NOT EXISTS vdp_recipient_data (
    data_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES vdp_composition_jobs(job_id),
    recipient_id UUID NOT NULL,
    sequence_number INTEGER,
    
    -- Recipient info
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(255),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    zip4 VARCHAR(4),
    
    -- Intelligence data used
    donor_grade VARCHAR(10),
    ml_cluster VARCHAR(100),
    segment VARCHAR(50),
    top_issues JSONB DEFAULT '[]',
    
    -- Generated variable content
    variable_headline TEXT,
    variable_body TEXT,
    variable_image_url TEXT,
    variable_ask_low INTEGER,
    variable_ask_mid INTEGER,
    variable_ask_high INTEGER,
    variable_issue_content TEXT,
    
    -- Tracking
    unique_url VARCHAR(255),
    qr_code_url TEXT,
    tracking_code VARCHAR(50),
    imb_barcode VARCHAR(65),
    
    -- Postal
    delivery_point_barcode VARCHAR(12),
    carrier_route VARCHAR(10),
    presort_sequence INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vdp_data_job ON vdp_recipient_data(job_id);
CREATE INDEX IF NOT EXISTS idx_vdp_data_recipient ON vdp_recipient_data(recipient_id);

-- Image Library (variable images)
CREATE TABLE IF NOT EXISTS vdp_image_library (
    image_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    tags JSONB DEFAULT '[]',
    
    -- For segment matching
    target_segments JSONB DEFAULT '[]',
    target_issues JSONB DEFAULT '[]',
    target_clusters JSONB DEFAULT '[]',
    
    -- Image files
    image_url TEXT NOT NULL,
    thumbnail_url TEXT,
    
    -- Specs
    width_px INTEGER,
    height_px INTEGER,
    format VARCHAR(20),
    color_profile VARCHAR(50) DEFAULT 'CMYK',
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vdp_images_category ON vdp_image_library(category);

-- Content Library (variable text blocks)
CREATE TABLE IF NOT EXISTS vdp_content_library (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    content_type VARCHAR(50) NOT NULL,
    
    -- For segment matching
    target_segments JSONB DEFAULT '[]',
    target_issues JSONB DEFAULT '[]',
    target_clusters JSONB DEFAULT '[]',
    
    -- Content
    content_text TEXT NOT NULL,
    
    -- Tone/style
    tone VARCHAR(50),
    word_count INTEGER,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vdp_content_type ON vdp_content_library(content_type);

-- Vendor Integration
CREATE TABLE IF NOT EXISTS vdp_vendors (
    vendor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    vendor_type VARCHAR(50),
    
    -- API integration
    api_endpoint TEXT,
    api_key_encrypted TEXT,
    
    -- Supported formats
    supported_formats JSONB DEFAULT '[]',
    
    -- Contact
    contact_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    
    -- Capabilities
    max_pieces_per_job INTEGER,
    turnaround_days INTEGER,
    supports_pdf_vt BOOLEAN DEFAULT false,
    supports_ppml BOOLEAN DEFAULT false,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_job_summary AS
SELECT 
    j.job_id,
    j.job_number,
    j.status,
    j.personalization_level,
    j.total_recipients,
    j.unique_variants,
    t.name as template_name,
    t.piece_type,
    j.created_at,
    j.completed_at
FROM vdp_composition_jobs j
JOIN vdp_templates t ON j.template_id = t.template_id
ORDER BY j.created_at DESC;

CREATE OR REPLACE VIEW v_personalization_stats AS
SELECT 
    j.job_id,
    j.job_number,
    COUNT(DISTINCT rd.variable_headline) as unique_headlines,
    COUNT(DISTINCT rd.variable_image_url) as unique_images,
    COUNT(DISTINCT rd.donor_grade) as grade_segments,
    COUNT(DISTINCT rd.ml_cluster) as ml_clusters,
    AVG(rd.variable_ask_mid) as avg_ask_amount
FROM vdp_composition_jobs j
JOIN vdp_recipient_data rd ON j.job_id = rd.job_id
GROUP BY j.job_id, j.job_number;

SELECT 'VDP Composition Engine schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_19_personalization_engine.py (E19)
-- ================================================================

-- ================================================================
-- FROM: ecosystem_19_social_media_enhanced.py (E19)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 19: SOCIAL MEDIA MANAGER - ENHANCED WITH CAROUSELS
-- ============================================================================

-- Social Posts (supports all types including carousels)
CREATE TABLE IF NOT EXISTS social_posts (
    post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    
    -- Post type
    post_type VARCHAR(50) NOT NULL DEFAULT 'single_image',
    
    -- Content
    caption TEXT,
    hashtags JSONB DEFAULT '[]',
    
    -- Single media (for non-carousel)
    media_url TEXT,
    media_type VARCHAR(20),
    
    -- Carousel slides (for carousel posts)
    is_carousel BOOLEAN DEFAULT false,
    carousel_slides JSONB DEFAULT '[]',
    
    -- Targeting
    platforms JSONB DEFAULT '["facebook", "instagram"]',
    audience_targeting JSONB DEFAULT '{}',
    
    -- Scheduling
    status VARCHAR(50) DEFAULT 'draft',
    scheduled_for TIMESTAMP,
    published_at TIMESTAMP,
    
    -- Approval workflow
    requires_approval BOOLEAN DEFAULT true,
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    
    -- Compliance
    compliance_checked BOOLEAN DEFAULT false,
    compliance_status VARCHAR(50),
    compliance_issues JSONB DEFAULT '[]',
    has_political_disclaimer BOOLEAN DEFAULT false,
    disclaimer_text TEXT,
    ai_generated BOOLEAN DEFAULT false,
    ai_disclosure_added BOOLEAN DEFAULT false,
    
    -- A/B Testing
    ab_test_id UUID,
    variant_code VARCHAR(10),
    
    -- Metadata
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_social_posts_status ON social_posts(status);
CREATE INDEX IF NOT EXISTS idx_social_posts_candidate ON social_posts(candidate_id);
CREATE INDEX IF NOT EXISTS idx_social_posts_scheduled ON social_posts(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_social_posts_carousel ON social_posts(is_carousel);

-- Carousel Slides (detailed per-slide data)
CREATE TABLE IF NOT EXISTS carousel_slides (
    slide_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES social_posts(post_id),
    
    -- Slide position
    slide_order INTEGER NOT NULL,
    
    -- Media
    media_url TEXT NOT NULL,
    media_type VARCHAR(20) NOT NULL,
    thumbnail_url TEXT,
    
    -- Content
    headline TEXT,
    description TEXT,
    
    -- Call to Action
    cta_text VARCHAR(100),
    cta_url TEXT,
    cta_type VARCHAR(50),
    
    -- Tracking
    tracking_code VARCHAR(50),
    shortlink_url TEXT,
    
    -- Alt text for accessibility
    alt_text TEXT,
    
    -- Video-specific
    video_duration_seconds INTEGER,
    video_thumbnail_time DECIMAL(6,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_carousel_slides_post ON carousel_slides(post_id);

-- Platform Publications (track per-platform publishing)
CREATE TABLE IF NOT EXISTS social_publications (
    publication_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES social_posts(post_id),
    platform VARCHAR(50) NOT NULL,
    
    -- Platform-specific ID
    platform_post_id VARCHAR(255),
    platform_url TEXT,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    published_at TIMESTAMP,
    error_message TEXT,
    
    -- Platform-specific data
    platform_response JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_publications_post ON social_publications(post_id);
CREATE INDEX IF NOT EXISTS idx_publications_platform ON social_publications(platform);

-- Engagement Tracking (overall post)
CREATE TABLE IF NOT EXISTS social_engagement (
    engagement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES social_posts(post_id),
    publication_id UUID REFERENCES social_publications(publication_id),
    platform VARCHAR(50),
    
    -- Metrics
    impressions INTEGER DEFAULT 0,
    reach INTEGER DEFAULT 0,
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    saves INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    video_views INTEGER DEFAULT 0,
    video_watch_time_seconds INTEGER DEFAULT 0,
    
    -- Calculated
    engagement_rate DECIMAL(6,4),
    click_through_rate DECIMAL(6,4),
    
    -- Timing
    recorded_at TIMESTAMP DEFAULT NOW(),
    
    -- Raw data
    raw_metrics JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_engagement_post ON social_engagement(post_id);
CREATE INDEX IF NOT EXISTS idx_engagement_platform ON social_engagement(platform);

-- Carousel Slide Engagement (per-slide analytics)
CREATE TABLE IF NOT EXISTS carousel_slide_engagement (
    slide_engagement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slide_id UUID REFERENCES carousel_slides(slide_id),
    post_id UUID,
    platform VARCHAR(50),
    
    -- Slide-specific metrics
    slide_impressions INTEGER DEFAULT 0,
    slide_exits INTEGER DEFAULT 0,
    slide_swipe_forward INTEGER DEFAULT 0,
    slide_swipe_back INTEGER DEFAULT 0,
    slide_tap_forward INTEGER DEFAULT 0,
    slide_tap_back INTEGER DEFAULT 0,
    
    -- CTA metrics
    cta_clicks INTEGER DEFAULT 0,
    shortlink_clicks INTEGER DEFAULT 0,
    
    -- Calculated
    exit_rate DECIMAL(6,4),
    cta_click_rate DECIMAL(6,4),
    
    recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_slide_engagement_slide ON carousel_slide_engagement(slide_id);
CREATE INDEX IF NOT EXISTS idx_slide_engagement_post ON carousel_slide_engagement(post_id);

-- Click Tracking (for CTA links)
CREATE TABLE IF NOT EXISTS social_click_events (
    click_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source
    post_id UUID,
    slide_id UUID,
    platform VARCHAR(50),
    tracking_code VARCHAR(50),
    
    -- User info
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_type VARCHAR(50),
    
    -- Conversion
    converted BOOLEAN DEFAULT false,
    conversion_type VARCHAR(50),
    conversion_value DECIMAL(12,2),
    
    clicked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clicks_post ON social_click_events(post_id);
CREATE INDEX IF NOT EXISTS idx_clicks_slide ON social_click_events(slide_id);
CREATE INDEX IF NOT EXISTS idx_clicks_tracking ON social_click_events(tracking_code);

-- Shortlinks for tracking
CREATE TABLE IF NOT EXISTS social_shortlinks (
    shortlink_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_code VARCHAR(20) UNIQUE NOT NULL,
    destination_url TEXT NOT NULL,
    
    -- Attribution
    post_id UUID,
    slide_id UUID,
    platform VARCHAR(50),
    
    -- Metrics
    click_count INTEGER DEFAULT 0,
    unique_clicks INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_social_shortlinks_code ON social_shortlinks(short_code);

-- A/B Tests for social content
CREATE TABLE IF NOT EXISTS social_ab_tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255),
    test_type VARCHAR(50),
    
    -- What's being tested
    test_element VARCHAR(100),
    
    -- Status
    status VARCHAR(50) DEFAULT 'running',
    winner_variant VARCHAR(10),
    confidence DECIMAL(6,4),
    
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

-- Hashtag Performance
CREATE TABLE IF NOT EXISTS hashtag_performance (
    hashtag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hashtag VARCHAR(255) NOT NULL,
    platform VARCHAR(50),
    
    -- Usage
    times_used INTEGER DEFAULT 0,
    
    -- Performance
    avg_impressions DECIMAL(12,2),
    avg_engagement_rate DECIMAL(6,4),
    avg_reach DECIMAL(12,2),
    
    -- Trending
    is_trending BOOLEAN DEFAULT false,
    trend_score DECIMAL(6,2),
    
    last_used TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hashtags_tag ON hashtag_performance(hashtag);
CREATE INDEX IF NOT EXISTS idx_hashtags_platform ON hashtag_performance(platform);

-- Best Posting Times
CREATE TABLE IF NOT EXISTS posting_time_performance (
    time_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform VARCHAR(50),
    day_of_week INTEGER,
    hour_of_day INTEGER,
    
    -- Performance
    post_count INTEGER DEFAULT 0,
    avg_engagement_rate DECIMAL(6,4),
    avg_impressions DECIMAL(12,2),
    
    -- Recommendation
    recommended_score DECIMAL(6,2),
    
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_post_performance AS
SELECT 
    p.post_id,
    p.post_type,
    p.is_carousel,
    p.status,
    p.platforms,
    p.scheduled_for,
    p.published_at,
    COALESCE(SUM(e.impressions), 0) as total_impressions,
    COALESCE(SUM(e.reach), 0) as total_reach,
    COALESCE(SUM(e.likes), 0) as total_likes,
    COALESCE(SUM(e.comments), 0) as total_comments,
    COALESCE(SUM(e.shares), 0) as total_shares,
    COALESCE(SUM(e.clicks), 0) as total_clicks,
    COALESCE(AVG(e.engagement_rate), 0) as avg_engagement_rate
FROM social_posts p
LEFT JOIN social_engagement e ON p.post_id = e.post_id
GROUP BY p.post_id;

CREATE OR REPLACE VIEW v_carousel_slide_performance AS
SELECT 
    cs.slide_id,
    cs.post_id,
    cs.slide_order,
    cs.headline,
    cs.cta_text,
    COALESCE(SUM(cse.slide_impressions), 0) as impressions,
    COALESCE(SUM(cse.cta_clicks), 0) as cta_clicks,
    COALESCE(SUM(cse.slide_exits), 0) as exits,
    COALESCE(AVG(cse.exit_rate), 0) as avg_exit_rate,
    COALESCE(AVG(cse.cta_click_rate), 0) as avg_cta_rate
FROM carousel_slides cs
LEFT JOIN carousel_slide_engagement cse ON cs.slide_id = cse.slide_id
GROUP BY cs.slide_id;

CREATE OR REPLACE VIEW v_platform_performance AS
SELECT 
    platform,
    COUNT(DISTINCT post_id) as total_posts,
    AVG(impressions) as avg_impressions,
    AVG(engagement_rate) as avg_engagement_rate,
    SUM(clicks) as total_clicks
FROM social_engagement
GROUP BY platform;

SELECT 'Enhanced Social Media schema with Carousels deployed!' as status;


-- ================================================================
-- FROM: ecosystem_19_social_media_manager.py (E19)
-- ================================================================

-- ================================================================
-- FROM: ecosystem_20_intelligence_brain_complete.py (E20)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 20: INTELLIGENCE BRAIN
-- ============================================================================

-- Triggers (905 types)
CREATE TABLE IF NOT EXISTS brain_triggers (
    trigger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    conditions JSONB DEFAULT '{}',
    actions JSONB DEFAULT '[]',
    priority INTEGER DEFAULT 50,
    is_active BOOLEAN DEFAULT true,
    cooldown_minutes INTEGER DEFAULT 60,
    last_fired TIMESTAMP,
    fire_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_triggers_category ON brain_triggers(category);
CREATE INDEX IF NOT EXISTS idx_triggers_active ON brain_triggers(is_active);

-- Decisions
CREATE TABLE IF NOT EXISTS brain_decisions (
    decision_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trigger_id UUID REFERENCES brain_triggers(trigger_id),
    candidate_id UUID,
    campaign_id UUID,
    event_type VARCHAR(100),
    event_data JSONB DEFAULT '{}',
    decision VARCHAR(20) NOT NULL,
    score INTEGER,
    score_breakdown JSONB DEFAULT '{}',
    channels_selected JSONB DEFAULT '[]',
    targets_selected JSONB DEFAULT '[]',
    budget_allocated DECIMAL(12,2),
    content_selected UUID,
    execution_plan JSONB DEFAULT '{}',
    executed BOOLEAN DEFAULT false,
    executed_at TIMESTAMP,
    result_metrics JSONB DEFAULT '{}',
    processing_ms INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_decisions_trigger ON brain_decisions(trigger_id);
CREATE INDEX IF NOT EXISTS idx_decisions_candidate ON brain_decisions(candidate_id);
CREATE INDEX IF NOT EXISTS idx_decisions_decision ON brain_decisions(decision);
CREATE INDEX IF NOT EXISTS idx_decisions_created ON brain_decisions(created_at);

-- Contact Fatigue Tracking
CREATE TABLE IF NOT EXISTS contact_fatigue (
    fatigue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL,
    channel VARCHAR(50) NOT NULL,
    last_contact TIMESTAMP NOT NULL,
    contacts_today INTEGER DEFAULT 1,
    contacts_this_week INTEGER DEFAULT 1,
    contacts_this_month INTEGER DEFAULT 1,
    total_contacts INTEGER DEFAULT 1,
    fatigue_score DECIMAL(5,2) DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(contact_id, channel)
);

CREATE INDEX IF NOT EXISTS idx_fatigue_contact ON contact_fatigue(contact_id);
CREATE INDEX IF NOT EXISTS idx_fatigue_channel ON contact_fatigue(channel);

-- Budget Tracking (per campaign/channel)
CREATE TABLE IF NOT EXISTS brain_budgets (
    budget_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    channel VARCHAR(50),
    daily_budget DECIMAL(12,2),
    daily_spent DECIMAL(12,2) DEFAULT 0,
    weekly_budget DECIMAL(12,2),
    weekly_spent DECIMAL(12,2) DEFAULT 0,
    monthly_budget DECIMAL(12,2),
    monthly_spent DECIMAL(12,2) DEFAULT 0,
    last_reset DATE DEFAULT CURRENT_DATE,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_budgets_campaign ON brain_budgets(campaign_id);

-- Learning Database
CREATE TABLE IF NOT EXISTS brain_learning (
    learning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trigger_category VARCHAR(50),
    channel VARCHAR(50),
    donor_segment VARCHAR(50),
    content_type VARCHAR(50),
    sends INTEGER DEFAULT 0,
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    revenue DECIMAL(14,2) DEFAULT 0,
    avg_roi DECIMAL(10,4),
    confidence_score DECIMAL(5,2),
    last_updated TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_learning_segment ON brain_learning(donor_segment);

-- Event Queue
CREATE TABLE IF NOT EXISTS brain_event_queue (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB DEFAULT '{}',
    priority INTEGER DEFAULT 50,
    status VARCHAR(50) DEFAULT 'pending',
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    scheduled_for TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_queue_status ON brain_event_queue(status);
CREATE INDEX IF NOT EXISTS idx_queue_scheduled ON brain_event_queue(scheduled_for);

-- Views
CREATE OR REPLACE VIEW v_decision_summary AS
SELECT 
    DATE(created_at) as decision_date,
    decision,
    COUNT(*) as count,
    AVG(score) as avg_score,
    SUM(budget_allocated) as total_budget
FROM brain_decisions
GROUP BY DATE(created_at), decision
ORDER BY decision_date DESC;

CREATE OR REPLACE VIEW v_channel_performance AS
SELECT 
    channel,
    SUM(sends) as total_sends,
    SUM(conversions) as total_conversions,
    SUM(revenue) as total_revenue,
    CASE WHEN SUM(sends) > 0 
         THEN (SUM(conversions)::DECIMAL / SUM(sends) * 100)
         ELSE 0 END as conversion_rate,
    AVG(avg_roi) as avg_roi
FROM brain_learning
GROUP BY channel;

CREATE OR REPLACE VIEW v_trigger_stats AS
SELECT 
    bt.trigger_id,
    bt.name,
    bt.category,
    bt.fire_count,
    COUNT(bd.decision_id) as decisions_made,
    COUNT(bd.decision_id) FILTER (WHERE bd.decision = 'go') as go_decisions,
    AVG(bd.score) as avg_score
FROM brain_triggers bt
LEFT JOIN brain_decisions bd ON bt.trigger_id = bd.trigger_id
GROUP BY bt.trigger_id, bt.name, bt.category, bt.fire_count;

SELECT 'Intelligence Brain schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_21_ml_clustering_complete.py (E21)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 21: ML CLUSTERING & SEGMENTATION
-- ============================================================================

-- Cluster Definitions
CREATE TABLE IF NOT EXISTS donor_clusters (
    cluster_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Cluster Info
    cluster_number INTEGER NOT NULL,
    cluster_name VARCHAR(255),
    cluster_description TEXT,
    cluster_type VARCHAR(50) DEFAULT 'hybrid',
    
    -- Size and Value
    donor_count INTEGER DEFAULT 0,
    total_value DECIMAL(14,2) DEFAULT 0,
    avg_donation DECIMAL(12,2) DEFAULT 0,
    avg_lifetime_value DECIMAL(12,2) DEFAULT 0,
    
    -- Characteristics (what defines this cluster)
    characteristics JSONB DEFAULT '{}',
    centroid JSONB DEFAULT '[]',
    
    -- Tier assignment
    tier VARCHAR(50),
    
    -- Recommended actions
    recommended_channels JSONB DEFAULT '[]',
    recommended_frequency VARCHAR(50),
    optimal_ask_range JSONB DEFAULT '{}',
    
    -- Performance
    avg_response_rate DECIMAL(6,4),
    avg_conversion_rate DECIMAL(6,4),
    campaign_roi DECIMAL(10,2),
    
    -- Model info
    model_version VARCHAR(50),
    silhouette_score DECIMAL(6,4),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clusters_candidate ON donor_clusters(candidate_id);
CREATE INDEX IF NOT EXISTS idx_clusters_tier ON donor_clusters(tier);
CREATE INDEX IF NOT EXISTS idx_clusters_type ON donor_clusters(cluster_type);

-- Donor Cluster Assignments
CREATE TABLE IF NOT EXISTS donor_cluster_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    cluster_id UUID REFERENCES donor_clusters(cluster_id),
    candidate_id UUID,
    
    -- Assignment details
    assignment_confidence DECIMAL(4,3),  -- 0-1 confidence score
    distance_to_centroid DECIMAL(10,4),
    
    -- Alternative clusters (2nd, 3rd best fit)
    secondary_cluster_id UUID,
    tertiary_cluster_id UUID,
    
    -- Segment tier
    segment_tier VARCHAR(50),
    
    -- Feature snapshot at assignment time
    feature_snapshot JSONB DEFAULT '{}',
    
    assigned_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '90 days'
);

CREATE INDEX IF NOT EXISTS idx_assignments_donor ON donor_cluster_assignments(donor_id);
CREATE INDEX IF NOT EXISTS idx_assignments_cluster ON donor_cluster_assignments(cluster_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_assignments_unique ON donor_cluster_assignments(donor_id, candidate_id);

-- Segment Migration History
CREATE TABLE IF NOT EXISTS segment_migrations (
    migration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    
    -- Migration details
    from_cluster_id UUID,
    to_cluster_id UUID,
    from_cluster_name VARCHAR(255),
    to_cluster_name VARCHAR(255),
    from_tier VARCHAR(50),
    to_tier VARCHAR(50),
    
    -- Reason
    migration_reason VARCHAR(100),  -- upgrade, downgrade, churn, reactivation
    
    -- Trigger
    triggered_by VARCHAR(100),  -- scheduled, donation, inactivity, manual
    
    migrated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_migrations_donor ON segment_migrations(donor_id);
CREATE INDEX IF NOT EXISTS idx_migrations_date ON segment_migrations(migrated_at);

-- Clustering Jobs
CREATE TABLE IF NOT EXISTS clustering_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Job config
    cluster_type VARCHAR(50),
    n_clusters INTEGER,
    features_used JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Results
    donors_processed INTEGER DEFAULT 0,
    clusters_created INTEGER DEFAULT 0,
    silhouette_score DECIMAL(6,4),
    
    -- Model
    model_path TEXT,
    model_version VARCHAR(50),
    
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clustering_jobs_status ON clustering_jobs(status);

-- Look-alike Models
CREATE TABLE IF NOT EXISTS lookalike_models (
    model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Seed audience
    seed_cluster_id UUID,
    seed_donor_count INTEGER,
    seed_criteria JSONB DEFAULT '{}',
    
    -- Model
    model_type VARCHAR(50) DEFAULT 'knn',
    model_path TEXT,
    
    -- Results
    lookalike_count INTEGER DEFAULT 0,
    avg_similarity_score DECIMAL(6,4),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Propensity Scores
CREATE TABLE IF NOT EXISTS donor_propensity_scores (
    score_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    candidate_id UUID,
    
    -- Propensity scores (0-1)
    donation_propensity DECIMAL(4,3),
    upgrade_propensity DECIMAL(4,3),
    churn_propensity DECIMAL(4,3),
    event_attendance_propensity DECIMAL(4,3),
    volunteer_propensity DECIMAL(4,3),
    
    -- Predicted values
    predicted_next_amount DECIMAL(12,2),
    predicted_annual_value DECIMAL(12,2),
    predicted_lifetime_value DECIMAL(14,2),
    
    -- Model version
    model_version VARCHAR(50),
    
    calculated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '30 days'
);

CREATE INDEX IF NOT EXISTS idx_propensity_donor ON donor_propensity_scores(donor_id);
CREATE INDEX IF NOT EXISTS idx_propensity_donation ON donor_propensity_scores(donation_propensity DESC);

-- Views
CREATE OR REPLACE VIEW v_cluster_summary AS
SELECT 
    c.cluster_id,
    c.cluster_name,
    c.cluster_type,
    c.tier,
    c.donor_count,
    c.total_value,
    c.avg_donation,
    c.avg_response_rate,
    c.campaign_roi,
    c.characteristics,
    c.recommended_channels
FROM donor_clusters c
WHERE c.is_active = true
ORDER BY c.total_value DESC;

CREATE OR REPLACE VIEW v_donor_segments AS
SELECT 
    dca.donor_id,
    dca.candidate_id,
    c.cluster_name,
    c.tier as segment_tier,
    c.cluster_type,
    dca.assignment_confidence,
    c.recommended_channels,
    c.avg_donation as cluster_avg_donation
FROM donor_cluster_assignments dca
JOIN donor_clusters c ON dca.cluster_id = c.cluster_id
WHERE dca.expires_at > NOW();

CREATE OR REPLACE VIEW v_segment_performance AS
SELECT 
    c.cluster_id,
    c.cluster_name,
    c.tier,
    c.donor_count,
    c.total_value,
    c.avg_response_rate,
    c.avg_conversion_rate,
    c.campaign_roi,
    COUNT(sm.migration_id) as migrations_out
FROM donor_clusters c
LEFT JOIN segment_migrations sm ON c.cluster_id = sm.from_cluster_id
    AND sm.migrated_at > NOW() - INTERVAL '90 days'
WHERE c.is_active = true
GROUP BY c.cluster_id, c.cluster_name, c.tier, c.donor_count,
         c.total_value, c.avg_response_rate, c.avg_conversion_rate, c.campaign_roi;

SELECT 'ML Clustering schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_22_ab_testing_engine_complete.py (E22)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 22: UNIVERSAL A/B TESTING ENGINE
-- ============================================================================

-- Master Test Registry
CREATE TABLE IF NOT EXISTS ab_tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_number VARCHAR(50) UNIQUE,
    name VARCHAR(500) NOT NULL,
    description TEXT,
    
    -- Test configuration
    channel VARCHAR(50) NOT NULL,
    test_type VARCHAR(50) DEFAULT 'ab',
    elements_tested JSONB DEFAULT '[]',
    
    -- Campaign linkage
    campaign_id UUID,
    candidate_id UUID,
    
    -- Sample configuration
    total_sample_size INTEGER,
    test_percentage DECIMAL(5,2) DEFAULT 100,
    min_sample_per_variant INTEGER DEFAULT 100,
    
    -- Statistical settings
    confidence_level DECIMAL(4,2) DEFAULT 0.95,
    minimum_detectable_effect DECIMAL(6,4) DEFAULT 0.05,
    
    -- Primary metric
    primary_metric VARCHAR(100) DEFAULT 'conversion_rate',
    secondary_metrics JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    
    -- Winner
    winning_variant_id UUID,
    winner_confidence DECIMAL(6,4),
    winner_declared_at TIMESTAMP,
    auto_declared BOOLEAN DEFAULT false,
    
    -- Analysis
    statistical_significance DECIMAL(6,4),
    p_value DECIMAL(8,6),
    
    -- Metadata
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_tests_channel ON ab_tests(channel);
CREATE INDEX IF NOT EXISTS idx_ab_tests_status ON ab_tests(status);
CREATE INDEX IF NOT EXISTS idx_ab_tests_campaign ON ab_tests(campaign_id);

-- Test Variants (unlimited per test)
CREATE TABLE IF NOT EXISTS ab_variants (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES ab_tests(test_id),
    
    -- Variant identification
    variant_code VARCHAR(10) NOT NULL,
    variant_name VARCHAR(255),
    is_control BOOLEAN DEFAULT false,
    
    -- Content
    content JSONB NOT NULL,
    
    -- Traffic allocation
    allocation_percentage DECIMAL(5,2),
    
    -- Sample metrics
    sample_size INTEGER DEFAULT 0,
    
    -- Engagement metrics
    impressions INTEGER DEFAULT 0,
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    responses INTEGER DEFAULT 0,
    
    -- Conversion metrics
    conversions INTEGER DEFAULT 0,
    donations INTEGER DEFAULT 0,
    signups INTEGER DEFAULT 0,
    
    -- Value metrics
    total_value DECIMAL(12,2) DEFAULT 0,
    
    -- Calculated rates (updated periodically)
    open_rate DECIMAL(8,6),
    click_rate DECIMAL(8,6),
    conversion_rate DECIMAL(8,6),
    avg_value DECIMAL(12,2),
    
    -- Statistical analysis
    confidence_vs_control DECIMAL(6,4),
    lift_vs_control DECIMAL(8,4),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_variants_test ON ab_variants(test_id);
CREATE INDEX IF NOT EXISTS idx_ab_variants_code ON ab_variants(variant_code);

-- Individual Assignments (who got which variant)
CREATE TABLE IF NOT EXISTS ab_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES ab_tests(test_id),
    variant_id UUID REFERENCES ab_variants(variant_id),
    
    -- Recipient
    contact_id UUID,
    contact_hash VARCHAR(64),
    
    -- Channel-specific ID
    send_id UUID,
    job_id UUID,
    post_id UUID,
    
    -- Assignment method
    assignment_method VARCHAR(50) DEFAULT 'random',
    
    assigned_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_assignments_test ON ab_assignments(test_id);
CREATE INDEX IF NOT EXISTS idx_ab_assignments_contact ON ab_assignments(contact_id);
CREATE INDEX IF NOT EXISTS idx_ab_assignments_hash ON ab_assignments(contact_hash);

-- Event Tracking (all interactions)
CREATE TABLE IF NOT EXISTS ab_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES ab_tests(test_id),
    variant_id UUID REFERENCES ab_variants(variant_id),
    assignment_id UUID REFERENCES ab_assignments(assignment_id),
    
    -- Event details
    event_type VARCHAR(100) NOT NULL,
    event_value DECIMAL(12,2),
    
    -- Context
    contact_id UUID,
    channel VARCHAR(50),
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    occurred_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_events_test ON ab_events(test_id);
CREATE INDEX IF NOT EXISTS idx_ab_events_variant ON ab_events(variant_id);
CREATE INDEX IF NOT EXISTS idx_ab_events_type ON ab_events(event_type);

-- Statistical Snapshots (periodic analysis)
CREATE TABLE IF NOT EXISTS ab_analysis_snapshots (
    snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES ab_tests(test_id),
    
    -- Snapshot data
    variant_stats JSONB NOT NULL,
    
    -- Overall analysis
    current_winner VARCHAR(10),
    confidence DECIMAL(6,4),
    p_value DECIMAL(8,6),
    
    -- Recommendations
    recommended_action VARCHAR(100),
    days_to_significance INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_snapshots_test ON ab_analysis_snapshots(test_id);

-- Multivariate Test Elements
CREATE TABLE IF NOT EXISTS ab_multivariate_elements (
    element_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES ab_tests(test_id),
    
    element_type VARCHAR(100) NOT NULL,
    element_options JSONB NOT NULL,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Bandit Arms (for multi-armed bandit tests)
CREATE TABLE IF NOT EXISTS ab_bandit_arms (
    arm_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES ab_tests(test_id),
    variant_id UUID REFERENCES ab_variants(variant_id),
    
    -- Bandit statistics
    alpha DECIMAL(12,4) DEFAULT 1,
    beta DECIMAL(12,4) DEFAULT 1,
    
    -- Current allocation
    current_probability DECIMAL(6,4),
    
    -- History
    pulls INTEGER DEFAULT 0,
    rewards INTEGER DEFAULT 0,
    
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Test Templates (reusable configurations)
CREATE TABLE IF NOT EXISTS ab_test_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    channel VARCHAR(50),
    
    -- Default configuration
    default_elements JSONB DEFAULT '[]',
    default_metrics JSONB DEFAULT '[]',
    default_settings JSONB DEFAULT '{}',
    
    -- Usage
    times_used INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_test_performance AS
SELECT 
    t.test_id,
    t.test_number,
    t.name,
    t.channel,
    t.status,
    t.primary_metric,
    COUNT(v.variant_id) as variant_count,
    SUM(v.sample_size) as total_sample,
    MAX(v.conversion_rate) as best_conversion_rate,
    t.winning_variant_id,
    t.winner_confidence,
    t.started_at,
    t.ended_at
FROM ab_tests t
LEFT JOIN ab_variants v ON t.test_id = v.test_id
GROUP BY t.test_id;

CREATE OR REPLACE VIEW v_variant_comparison AS
SELECT 
    v.test_id,
    v.variant_id,
    v.variant_code,
    v.variant_name,
    v.is_control,
    v.sample_size,
    v.impressions,
    v.clicks,
    v.conversions,
    v.total_value,
    v.conversion_rate,
    v.lift_vs_control,
    v.confidence_vs_control
FROM ab_variants v
ORDER BY v.test_id, v.variant_code;

CREATE OR REPLACE VIEW v_channel_test_summary AS
SELECT 
    channel,
    COUNT(*) as total_tests,
    COUNT(*) FILTER (WHERE status = 'running') as active_tests,
    COUNT(*) FILTER (WHERE status = 'winner_declared') as completed_tests,
    AVG(winner_confidence) as avg_winner_confidence
FROM ab_tests
GROUP BY channel;

SELECT 'Universal A/B Testing Engine schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_23_creative_asset_3d_engine_complete.py (E23)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 23: CREATIVE ASSET & 3D ENGINE
-- ============================================================================

-- Asset Library
CREATE TABLE IF NOT EXISTS creative_assets (
    asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identification
    name VARCHAR(500) NOT NULL,
    asset_type VARCHAR(50) NOT NULL,
    category VARCHAR(100),
    tags JSONB DEFAULT '[]',
    
    -- Ownership
    candidate_id UUID,
    campaign_id UUID,
    
    -- Files
    original_file_url TEXT,
    processed_file_url TEXT,
    thumbnail_url TEXT,
    
    -- Dimensions
    width INTEGER,
    height INTEGER,
    depth INTEGER,  -- For 3D
    file_size_bytes BIGINT,
    format VARCHAR(20),
    
    -- 3D specific
    is_3d BOOLEAN DEFAULT false,
    polygon_count INTEGER,
    has_textures BOOLEAN DEFAULT false,
    has_animations BOOLEAN DEFAULT false,
    webgl_ready BOOLEAN DEFAULT false,
    
    -- AI generation
    ai_generated BOOLEAN DEFAULT false,
    ai_prompt TEXT,
    ai_model VARCHAR(100),
    generation_seed VARCHAR(100),
    
    -- Brand compliance
    brand_approved BOOLEAN DEFAULT false,
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    
    -- Usage tracking
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assets_type ON creative_assets(asset_type);
CREATE INDEX IF NOT EXISTS idx_assets_candidate ON creative_assets(candidate_id);
CREATE INDEX IF NOT EXISTS idx_assets_3d ON creative_assets(is_3d);
CREATE INDEX IF NOT EXISTS idx_assets_tags ON creative_assets USING GIN(tags);

-- 3D Scenes
CREATE TABLE IF NOT EXISTS scenes_3d (
    scene_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(500) NOT NULL,
    
    -- Scene configuration
    scene_type VARCHAR(100),
    environment_preset VARCHAR(100),
    
    -- Objects in scene
    objects JSONB DEFAULT '[]',
    
    -- Camera settings
    camera_position JSONB DEFAULT '{}',
    camera_target JSONB DEFAULT '{}',
    camera_fov DECIMAL(6,2) DEFAULT 45,
    
    -- Lighting
    lighting_preset VARCHAR(100),
    lights JSONB DEFAULT '[]',
    
    -- Background
    background_type VARCHAR(50),
    background_color VARCHAR(20),
    background_hdri_url TEXT,
    
    -- Render settings
    render_quality VARCHAR(50) DEFAULT 'standard',
    
    -- Output
    rendered_image_url TEXT,
    rendered_video_url TEXT,
    webgl_viewer_url TEXT,
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scenes_status ON scenes_3d(status);

-- Renders (2D outputs from 3D scenes)
CREATE TABLE IF NOT EXISTS scene_renders (
    render_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scene_id UUID REFERENCES scenes_3d(scene_id),
    
    -- Render configuration
    render_type VARCHAR(50),  -- still, animation, turntable
    quality VARCHAR(50),
    
    -- Dimensions
    width INTEGER,
    height INTEGER,
    frames INTEGER DEFAULT 1,
    fps INTEGER,
    
    -- Output
    output_url TEXT,
    output_format VARCHAR(20),
    file_size_bytes BIGINT,
    
    -- Render time
    render_started_at TIMESTAMP,
    render_completed_at TIMESTAMP,
    render_time_seconds INTEGER,
    
    -- Cost
    render_cost DECIMAL(10,4),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_renders_scene ON scene_renders(scene_id);

-- Landing Pages with 3D
CREATE TABLE IF NOT EXISTS landing_pages (
    page_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identification
    name VARCHAR(500) NOT NULL,
    slug VARCHAR(255) UNIQUE,
    url TEXT,
    
    -- Content
    headline TEXT,
    subheadline TEXT,
    body_content TEXT,
    
    -- 3D Integration
    has_3d_viewer BOOLEAN DEFAULT false,
    viewer_3d_scene_id UUID,
    viewer_config JSONB DEFAULT '{}',
    
    -- Design
    template VARCHAR(100),
    theme JSONB DEFAULT '{}',
    custom_css TEXT,
    custom_js TEXT,
    
    -- Form
    has_form BOOLEAN DEFAULT true,
    form_fields JSONB DEFAULT '[]',
    form_submit_action VARCHAR(255),
    
    -- CTA
    cta_text VARCHAR(255),
    cta_url TEXT,
    cta_style JSONB DEFAULT '{}',
    
    -- Assets
    hero_asset_id UUID,
    background_asset_id UUID,
    assets JSONB DEFAULT '[]',
    
    -- A/B Testing
    ab_test_id UUID,
    variant_code VARCHAR(10),
    
    -- Tracking
    tracking_code TEXT,
    facebook_pixel VARCHAR(100),
    google_analytics VARCHAR(100),
    
    -- Performance
    views INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    conversion_rate DECIMAL(8,6),
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    published_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pages_slug ON landing_pages(slug);
CREATE INDEX IF NOT EXISTS idx_pages_status ON landing_pages(status);

-- WebGL Viewers (embeddable 3D)
CREATE TABLE IF NOT EXISTS webgl_viewers (
    viewer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Configuration
    name VARCHAR(255),
    scene_id UUID REFERENCES scenes_3d(scene_id),
    
    -- Viewer settings
    auto_rotate BOOLEAN DEFAULT true,
    allow_zoom BOOLEAN DEFAULT true,
    allow_pan BOOLEAN DEFAULT false,
    show_controls BOOLEAN DEFAULT true,
    
    -- Loading
    loading_image_url TEXT,
    loading_progress BOOLEAN DEFAULT true,
    
    -- Branding
    watermark_url TEXT,
    watermark_position VARCHAR(50),
    
    -- Embed code
    embed_width INTEGER DEFAULT 800,
    embed_height INTEGER DEFAULT 600,
    embed_code TEXT,
    
    -- Performance
    load_count INTEGER DEFAULT 0,
    avg_interaction_seconds INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Asset Variants (for A/B testing)
CREATE TABLE IF NOT EXISTS asset_variants (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_asset_id UUID REFERENCES creative_assets(asset_id),
    ab_test_id UUID,
    variant_code VARCHAR(10),
    
    -- Variation
    variation_type VARCHAR(100),
    variation_params JSONB DEFAULT '{}',
    
    -- Generated asset
    variant_file_url TEXT,
    
    -- Performance
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_variants_original ON asset_variants(original_asset_id);
CREATE INDEX IF NOT EXISTS idx_variants_test ON asset_variants(ab_test_id);

-- AI Generation Queue
CREATE TABLE IF NOT EXISTS ai_generation_queue (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Request
    generation_type VARCHAR(50) NOT NULL,
    prompt TEXT NOT NULL,
    negative_prompt TEXT,
    
    -- Parameters
    model VARCHAR(100),
    style VARCHAR(100),
    width INTEGER DEFAULT 1024,
    height INTEGER DEFAULT 1024,
    
    -- 3D specific
    generate_3d BOOLEAN DEFAULT false,
    texture_prompt TEXT,
    
    -- Status
    status VARCHAR(50) DEFAULT 'queued',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Output
    output_asset_id UUID,
    output_url TEXT,
    
    -- Cost
    generation_cost DECIMAL(10,4),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_generation_status ON ai_generation_queue(status);

-- Brand Asset Kit
CREATE TABLE IF NOT EXISTS brand_asset_kit (
    kit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Logos
    logo_primary_url TEXT,
    logo_secondary_url TEXT,
    logo_icon_url TEXT,
    logo_3d_url TEXT,
    
    -- Colors
    primary_color VARCHAR(20),
    secondary_color VARCHAR(20),
    accent_color VARCHAR(20),
    text_color VARCHAR(20),
    background_color VARCHAR(20),
    color_palette JSONB DEFAULT '[]',
    
    -- Typography
    heading_font VARCHAR(255),
    body_font VARCHAR(255),
    font_urls JSONB DEFAULT '[]',
    
    -- Imagery
    approved_images JSONB DEFAULT '[]',
    image_style_guide TEXT,
    
    -- 3D
    approved_3d_models JSONB DEFAULT '[]',
    environment_preset VARCHAR(100),
    material_presets JSONB DEFAULT '[]',
    
    -- Guidelines
    brand_guidelines_url TEXT,
    
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_asset_performance AS
SELECT 
    a.asset_id,
    a.name,
    a.asset_type,
    a.is_3d,
    a.ai_generated,
    a.usage_count,
    COUNT(DISTINCT av.variant_id) as variant_count,
    SUM(av.impressions) as total_impressions,
    SUM(av.clicks) as total_clicks,
    SUM(av.conversions) as total_conversions
FROM creative_assets a
LEFT JOIN asset_variants av ON a.asset_id = av.original_asset_id
GROUP BY a.asset_id;

CREATE OR REPLACE VIEW v_landing_page_performance AS
SELECT 
    page_id,
    name,
    slug,
    has_3d_viewer,
    views,
    conversions,
    ROUND(conversions::DECIMAL / NULLIF(views, 0) * 100, 2) as conversion_rate,
    status,
    published_at
FROM landing_pages
ORDER BY views DESC;

CREATE OR REPLACE VIEW v_3d_asset_summary AS
SELECT 
    asset_type,
    COUNT(*) as total_assets,
    COUNT(*) FILTER (WHERE webgl_ready = true) as webgl_ready_count,
    AVG(polygon_count) as avg_polygons,
    SUM(usage_count) as total_usage
FROM creative_assets
WHERE is_3d = true
GROUP BY asset_type;

SELECT 'Creative Asset & 3D Engine schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_24_candidate_portal_complete.py (E24)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 24: CANDIDATE PORTAL
-- ============================================================================

-- Portal Users (candidates and their authorized staff)
CREATE TABLE IF NOT EXISTS portal_users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Identity
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(50),
    
    -- Authentication
    password_hash VARCHAR(255),
    mfa_enabled BOOLEAN DEFAULT false,
    mfa_secret VARCHAR(100),
    
    -- Role
    role VARCHAR(50) DEFAULT 'viewer',  -- candidate, manager, staff, viewer
    permissions JSONB DEFAULT '[]',
    
    -- Preferences
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    dashboard_layout JSONB DEFAULT '{}',
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_portal_user_candidate ON portal_users(candidate_id);
CREATE INDEX IF NOT EXISTS idx_portal_user_email ON portal_users(email);

-- Portal Sessions
CREATE TABLE IF NOT EXISTS portal_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES portal_users(user_id),
    
    -- Session data
    token_hash VARCHAR(255) NOT NULL,
    ip_address VARCHAR(50),
    user_agent TEXT,
    
    -- Timing
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    last_activity_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_user ON portal_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_session_expires ON portal_sessions(expires_at);

-- Dashboard Configurations
CREATE TABLE IF NOT EXISTS portal_dashboards (
    dashboard_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    user_id UUID REFERENCES portal_users(user_id),
    
    -- Dashboard
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT false,
    
    -- Layout
    layout_config JSONB DEFAULT '{}',
    widgets JSONB DEFAULT '[]',
    
    -- Sharing
    is_shared BOOLEAN DEFAULT false,
    shared_with JSONB DEFAULT '[]',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dashboard_candidate ON portal_dashboards(candidate_id);

-- Dashboard Widgets
CREATE TABLE IF NOT EXISTS portal_widgets (
    widget_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dashboard_id UUID REFERENCES portal_dashboards(dashboard_id),
    
    -- Widget config
    widget_type VARCHAR(100) NOT NULL,
    title VARCHAR(255),
    
    -- Position
    position_x INTEGER DEFAULT 0,
    position_y INTEGER DEFAULT 0,
    width INTEGER DEFAULT 4,
    height INTEGER DEFAULT 3,
    
    -- Data config
    data_source VARCHAR(100),
    data_config JSONB DEFAULT '{}',
    refresh_interval_seconds INTEGER DEFAULT 300,
    
    -- Display
    display_config JSONB DEFAULT '{}',
    
    is_visible BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_widget_dashboard ON portal_widgets(dashboard_id);

-- Portal Alerts
CREATE TABLE IF NOT EXISTS portal_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    user_id UUID REFERENCES portal_users(user_id),
    
    -- Alert
    alert_type VARCHAR(100) NOT NULL,
    priority VARCHAR(20) DEFAULT 'medium',
    title VARCHAR(500) NOT NULL,
    message TEXT,
    
    -- Source
    source_ecosystem VARCHAR(10),
    source_entity_type VARCHAR(100),
    source_entity_id UUID,
    
    -- Action
    action_url TEXT,
    action_label VARCHAR(100),
    requires_action BOOLEAN DEFAULT false,
    
    -- Status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP,
    is_dismissed BOOLEAN DEFAULT false,
    dismissed_at TIMESTAMP,
    
    -- Timing
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alert_candidate ON portal_alerts(candidate_id);
CREATE INDEX IF NOT EXISTS idx_alert_user ON portal_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_alert_priority ON portal_alerts(priority);
CREATE INDEX IF NOT EXISTS idx_alert_unread ON portal_alerts(is_read) WHERE is_read = false;

-- Approval Queue
CREATE TABLE IF NOT EXISTS portal_approvals (
    approval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Item to approve
    item_type VARCHAR(100) NOT NULL,  -- content, expense, email, ad, etc.
    item_id UUID NOT NULL,
    item_title VARCHAR(500),
    item_preview TEXT,
    item_data JSONB DEFAULT '{}',
    
    -- Workflow
    requested_by VARCHAR(255),
    requested_at TIMESTAMP DEFAULT NOW(),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',  -- pending, approved, rejected, expired
    reviewed_by UUID REFERENCES portal_users(user_id),
    reviewed_at TIMESTAMP,
    review_notes TEXT,
    
    -- Priority
    priority VARCHAR(20) DEFAULT 'normal',
    due_date TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_approval_candidate ON portal_approvals(candidate_id);
CREATE INDEX IF NOT EXISTS idx_approval_status ON portal_approvals(status);
CREATE INDEX IF NOT EXISTS idx_approval_pending ON portal_approvals(status) WHERE status = 'pending';

-- Quick Actions Log
CREATE TABLE IF NOT EXISTS portal_actions (
    action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES portal_users(user_id),
    candidate_id UUID,
    
    -- Action
    action_type VARCHAR(100) NOT NULL,
    action_description TEXT,
    action_data JSONB DEFAULT '{}',
    
    -- Result
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_action_user ON portal_actions(user_id);

-- Saved Reports
CREATE TABLE IF NOT EXISTS portal_saved_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    user_id UUID REFERENCES portal_users(user_id),
    
    -- Report
    name VARCHAR(255) NOT NULL,
    report_type VARCHAR(100),
    
    -- Configuration
    filters JSONB DEFAULT '{}',
    columns JSONB DEFAULT '[]',
    sort_config JSONB DEFAULT '{}',
    
    -- Schedule
    is_scheduled BOOLEAN DEFAULT false,
    schedule_cron VARCHAR(100),
    email_recipients JSONB DEFAULT '[]',
    
    last_generated_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Goal Tracking
CREATE TABLE IF NOT EXISTS portal_goals (
    goal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Goal
    name VARCHAR(255) NOT NULL,
    goal_type VARCHAR(100),  -- fundraising, volunteers, doors, calls, etc.
    
    -- Target
    target_value DECIMAL(12,2) NOT NULL,
    current_value DECIMAL(12,2) DEFAULT 0,
    
    -- Timing
    start_date DATE,
    end_date DATE,
    
    -- Display
    display_on_dashboard BOOLEAN DEFAULT true,
    color VARCHAR(20),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_goal_candidate ON portal_goals(candidate_id);

-- Competitor Tracking
CREATE TABLE IF NOT EXISTS portal_competitors (
    competitor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,  -- Our candidate tracking them
    
    -- Competitor info
    competitor_name VARCHAR(255) NOT NULL,
    party VARCHAR(50),
    office VARCHAR(100),
    
    -- Tracking
    social_handles JSONB DEFAULT '{}',
    website_url TEXT,
    
    -- Latest data
    latest_fundraising DECIMAL(12,2),
    latest_poll_number DECIMAL(5,2),
    latest_news_sentiment DECIMAL(3,2),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Poll Tracking
CREATE TABLE IF NOT EXISTS portal_polls (
    poll_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Poll info
    pollster VARCHAR(255),
    poll_date DATE,
    sample_size INTEGER,
    margin_of_error DECIMAL(4,2),
    
    -- Results
    candidate_percent DECIMAL(5,2),
    opponent_percent DECIMAL(5,2),
    undecided_percent DECIMAL(5,2),
    
    -- Source
    source_url TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_poll_candidate ON portal_polls(candidate_id);

-- Views for dashboard data
CREATE OR REPLACE VIEW v_candidate_dashboard_summary AS
SELECT 
    c.candidate_id,
    c.first_name || ' ' || c.last_name as candidate_name,
    c.office,
    
    -- Fundraising (from donations)
    COALESCE((SELECT SUM(amount) FROM donations WHERE candidate_id = c.candidate_id), 0) as total_raised,
    COALESCE((SELECT COUNT(*) FROM donations WHERE candidate_id = c.candidate_id), 0) as total_donations,
    COALESCE((SELECT COUNT(DISTINCT donor_id) FROM donations WHERE candidate_id = c.candidate_id), 0) as total_donors,
    
    -- Recent activity
    COALESCE((SELECT SUM(amount) FROM donations WHERE candidate_id = c.candidate_id 
              AND created_at > NOW() - INTERVAL '24 hours'), 0) as raised_24h,
    COALESCE((SELECT COUNT(*) FROM donations WHERE candidate_id = c.candidate_id 
              AND created_at > NOW() - INTERVAL '24 hours'), 0) as donations_24h
              
FROM candidates c
WHERE c.is_active = true;

CREATE OR REPLACE VIEW v_pending_approvals AS
SELECT 
    pa.approval_id,
    pa.candidate_id,
    pa.item_type,
    pa.item_title,
    pa.priority,
    pa.due_date,
    pa.requested_by,
    pa.requested_at,
    CASE 
        WHEN pa.due_date < NOW() THEN 'overdue'
        WHEN pa.due_date < NOW() + INTERVAL '24 hours' THEN 'urgent'
        ELSE 'normal'
    END as urgency
FROM portal_approvals pa
WHERE pa.status = 'pending'
ORDER BY 
    CASE pa.priority 
        WHEN 'critical' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'normal' THEN 3 
        ELSE 4 
    END,
    pa.due_date ASC NULLS LAST;

CREATE OR REPLACE VIEW v_unread_alerts AS
SELECT 
    pa.alert_id,
    pa.candidate_id,
    pa.alert_type,
    pa.priority,
    pa.title,
    pa.message,
    pa.action_url,
    pa.requires_action,
    pa.created_at
FROM portal_alerts pa
WHERE pa.is_read = false 
AND pa.is_dismissed = false
AND (pa.expires_at IS NULL OR pa.expires_at > NOW())
ORDER BY 
    CASE pa.priority 
        WHEN 'critical' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        ELSE 4 
    END,
    pa.created_at DESC;

SELECT 'Candidate Portal schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_25_donor_portal_complete.py (E25)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 25: DONOR PORTAL
-- ============================================================================

-- Donor Portal Accounts
CREATE TABLE IF NOT EXISTS donor_accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    contact_id UUID,
    
    -- Authentication
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255),
    
    -- Verification
    email_verified BOOLEAN DEFAULT false,
    email_verified_at TIMESTAMP,
    verification_token VARCHAR(255),
    
    -- Security
    mfa_enabled BOOLEAN DEFAULT false,
    mfa_secret VARCHAR(100),
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    
    -- Profile
    display_name VARCHAR(255),
    avatar_url TEXT,
    
    -- Preferences
    communication_preferences JSONB DEFAULT '{"email": true, "mail": true, "phone": false}',
    privacy_settings JSONB DEFAULT '{"show_name_publicly": true, "show_amount_publicly": false}',
    notification_settings JSONB DEFAULT '{"receipts": true, "updates": true, "events": true}',
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donor_account_donor ON donor_accounts(donor_id);
CREATE INDEX IF NOT EXISTS idx_donor_account_email ON donor_accounts(email);

-- Donor Sessions
CREATE TABLE IF NOT EXISTS donor_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES donor_accounts(account_id),
    
    token_hash VARCHAR(255) NOT NULL,
    ip_address VARCHAR(50),
    user_agent TEXT,
    device_type VARCHAR(50),
    
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    last_activity_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donor_session_account ON donor_sessions(account_id);

-- Saved Payment Methods
CREATE TABLE IF NOT EXISTS donor_payment_methods (
    method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES donor_accounts(account_id),
    
    -- Payment info (tokenized)
    payment_type VARCHAR(50) NOT NULL,  -- card, bank, paypal
    provider VARCHAR(50),  -- stripe, paypal, etc.
    provider_token VARCHAR(255),
    
    -- Display info
    display_name VARCHAR(100),
    last_four VARCHAR(4),
    card_brand VARCHAR(50),
    exp_month INTEGER,
    exp_year INTEGER,
    
    -- Status
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_method_account ON donor_payment_methods(account_id);

-- Recurring Donations (donor-managed)
CREATE TABLE IF NOT EXISTS donor_recurring_donations (
    recurring_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES donor_accounts(account_id),
    donor_id UUID,
    
    -- Donation details
    amount DECIMAL(10,2) NOT NULL,
    frequency VARCHAR(50) NOT NULL,  -- monthly, quarterly, annually
    
    -- Payment
    payment_method_id UUID REFERENCES donor_payment_methods(method_id),
    
    -- Designation
    fund_designation VARCHAR(255),
    campaign_id UUID,
    
    -- Schedule
    start_date DATE NOT NULL,
    next_charge_date DATE,
    end_date DATE,
    
    -- Status
    status VARCHAR(50) DEFAULT 'active',  -- active, paused, cancelled, failed
    paused_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT,
    
    -- Stats
    total_charges INTEGER DEFAULT 0,
    total_donated DECIMAL(12,2) DEFAULT 0,
    last_charge_date DATE,
    last_charge_status VARCHAR(50),
    consecutive_failures INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recurring_account ON donor_recurring_donations(account_id);
CREATE INDEX IF NOT EXISTS idx_recurring_status ON donor_recurring_donations(status);

-- Pledges
CREATE TABLE IF NOT EXISTS donor_pledges (
    pledge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES donor_accounts(account_id),
    donor_id UUID,
    
    -- Pledge details
    pledge_amount DECIMAL(12,2) NOT NULL,
    fulfilled_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Schedule
    pledge_date DATE DEFAULT CURRENT_DATE,
    due_date DATE,
    
    -- Fulfillment
    fulfillment_plan VARCHAR(50),  -- one_time, monthly, quarterly
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',  -- pending, partial, fulfilled, cancelled
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pledge_account ON donor_pledges(account_id);

-- Tax Receipts
CREATE TABLE IF NOT EXISTS donor_tax_receipts (
    receipt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES donor_accounts(account_id),
    donor_id UUID,
    
    -- Receipt details
    tax_year INTEGER NOT NULL,
    total_donations DECIMAL(12,2) NOT NULL,
    donation_count INTEGER,
    
    -- Document
    receipt_number VARCHAR(100),
    pdf_url TEXT,
    
    -- Status
    generated_at TIMESTAMP DEFAULT NOW(),
    downloaded_at TIMESTAMP,
    emailed_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_receipt_account ON donor_tax_receipts(account_id);
CREATE INDEX IF NOT EXISTS idx_receipt_year ON donor_tax_receipts(tax_year);

-- Donor Recognition/Badges
CREATE TABLE IF NOT EXISTS donor_badges (
    badge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT,
    
    -- Criteria
    badge_type VARCHAR(50),  -- milestone, streak, special
    criteria_type VARCHAR(50),  -- total_donated, donation_count, consecutive_months, etc.
    criteria_value DECIMAL(12,2),
    
    -- Display
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Badge Earnings
CREATE TABLE IF NOT EXISTS donor_badge_earnings (
    earning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES donor_accounts(account_id),
    badge_id UUID REFERENCES donor_badges(badge_id),
    
    earned_at TIMESTAMP DEFAULT NOW(),
    displayed BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_badge_earning_account ON donor_badge_earnings(account_id);

-- Donor Activity Log
CREATE TABLE IF NOT EXISTS donor_activity_log (
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES donor_accounts(account_id),
    
    activity_type VARCHAR(100) NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}',
    
    ip_address VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_account ON donor_activity_log(account_id);

-- Communication Preferences (granular)
CREATE TABLE IF NOT EXISTS donor_comm_preferences (
    pref_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES donor_accounts(account_id),
    
    -- Channel
    channel VARCHAR(50) NOT NULL,  -- email, sms, mail, phone
    
    -- Category
    category VARCHAR(100) NOT NULL,  -- receipts, updates, events, fundraising, newsletters
    
    -- Preference
    opted_in BOOLEAN DEFAULT true,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_comm_pref_unique ON donor_comm_preferences(account_id, channel, category);

-- Views
CREATE OR REPLACE VIEW v_donor_dashboard AS
SELECT 
    da.account_id,
    da.donor_id,
    da.email,
    da.display_name,
    
    -- Lifetime stats
    COALESCE(SUM(d.amount), 0) as lifetime_giving,
    COUNT(d.donation_id) as total_donations,
    COALESCE(AVG(d.amount), 0) as avg_donation,
    MAX(d.created_at) as last_donation_date,
    MIN(d.created_at) as first_donation_date,
    
    -- This year
    COALESCE(SUM(CASE WHEN EXTRACT(YEAR FROM d.created_at) = EXTRACT(YEAR FROM NOW()) 
                      THEN d.amount END), 0) as ytd_giving,
    
    -- Active recurring
    (SELECT COUNT(*) FROM donor_recurring_donations r 
     WHERE r.account_id = da.account_id AND r.status = 'active') as active_recurring_count,
    
    -- Badges
    (SELECT COUNT(*) FROM donor_badge_earnings be 
     WHERE be.account_id = da.account_id) as badge_count

FROM donor_accounts da
LEFT JOIN donations d ON da.donor_id = d.donor_id
GROUP BY da.account_id;

CREATE OR REPLACE VIEW v_donor_giving_history AS
SELECT 
    da.account_id,
    d.donation_id,
    d.amount,
    d.created_at as donation_date,
    d.payment_method,
    d.is_recurring,
    d.fund_designation,
    d.receipt_number,
    c.name as campaign_name
FROM donor_accounts da
JOIN donations d ON da.donor_id = d.donor_id
LEFT JOIN campaigns c ON d.campaign_id = c.campaign_id
ORDER BY d.created_at DESC;

SELECT 'Donor Portal schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_26_volunteer_portal_complete.py (E26)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 26: VOLUNTEER PORTAL
-- ============================================================================

-- Volunteer Portal Accounts
CREATE TABLE IF NOT EXISTS volunteer_accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID NOT NULL,
    contact_id UUID,
    
    -- Authentication
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255),
    
    -- Verification
    email_verified BOOLEAN DEFAULT false,
    verification_token VARCHAR(255),
    
    -- Profile
    display_name VARCHAR(255),
    avatar_url TEXT,
    bio TEXT,
    
    -- Preferences
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    availability JSONB DEFAULT '{}',
    preferred_activities JSONB DEFAULT '[]',
    preferred_locations JSONB DEFAULT '[]',
    
    -- Gamification
    points INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vol_account_volunteer ON volunteer_accounts(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_vol_account_email ON volunteer_accounts(email);

-- Volunteer Sessions
CREATE TABLE IF NOT EXISTS volunteer_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    
    token_hash VARCHAR(255) NOT NULL,
    device_type VARCHAR(50),
    ip_address VARCHAR(50),
    
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

-- Available Shifts (opportunities to sign up)
CREATE TABLE IF NOT EXISTS volunteer_opportunities (
    opportunity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Event/Campaign
    event_id UUID,
    campaign_id UUID,
    candidate_id UUID,
    
    -- Details
    title VARCHAR(500) NOT NULL,
    description TEXT,
    activity_type VARCHAR(100) NOT NULL,
    
    -- Location
    location_name VARCHAR(255),
    location_address TEXT,
    is_virtual BOOLEAN DEFAULT false,
    virtual_url TEXT,
    
    -- Timing
    start_datetime TIMESTAMP NOT NULL,
    end_datetime TIMESTAMP NOT NULL,
    
    -- Capacity
    max_volunteers INTEGER,
    current_signups INTEGER DEFAULT 0,
    waitlist_enabled BOOLEAN DEFAULT true,
    
    -- Requirements
    skills_required JSONB DEFAULT '[]',
    training_required JSONB DEFAULT '[]',
    min_age INTEGER,
    
    -- Points
    points_value INTEGER DEFAULT 10,
    bonus_points INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(50) DEFAULT 'open',  -- open, full, cancelled, completed
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_opportunity_date ON volunteer_opportunities(start_datetime);
CREATE INDEX IF NOT EXISTS idx_opportunity_type ON volunteer_opportunities(activity_type);
CREATE INDEX IF NOT EXISTS idx_opportunity_status ON volunteer_opportunities(status);

-- Shift Signups
CREATE TABLE IF NOT EXISTS volunteer_signups (
    signup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_id UUID REFERENCES volunteer_opportunities(opportunity_id),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    volunteer_id UUID,
    
    -- Status
    status VARCHAR(50) DEFAULT 'confirmed',  -- confirmed, waitlisted, cancelled, completed, no_show
    waitlist_position INTEGER,
    
    -- Check-in
    checked_in BOOLEAN DEFAULT false,
    check_in_time TIMESTAMP,
    check_in_method VARCHAR(50),  -- qr, manual, gps
    check_in_location JSONB,
    
    -- Check-out
    checked_out BOOLEAN DEFAULT false,
    check_out_time TIMESTAMP,
    
    -- Results
    hours_worked DECIMAL(5,2),
    doors_knocked INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    texts_sent INTEGER DEFAULT 0,
    voters_registered INTEGER DEFAULT 0,
    
    -- Points
    points_earned INTEGER DEFAULT 0,
    bonus_earned INTEGER DEFAULT 0,
    
    -- Notes
    volunteer_notes TEXT,
    supervisor_notes TEXT,
    
    -- Verification
    hours_verified BOOLEAN DEFAULT false,
    verified_by VARCHAR(255),
    verified_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_signup_opportunity ON volunteer_signups(opportunity_id);
CREATE INDEX IF NOT EXISTS idx_signup_account ON volunteer_signups(account_id);
CREATE INDEX IF NOT EXISTS idx_signup_status ON volunteer_signups(status);

-- Volunteer Achievements/Badges
CREATE TABLE IF NOT EXISTS volunteer_achievements (
    achievement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT,
    
    -- Criteria
    achievement_type VARCHAR(50),  -- milestone, streak, special, activity
    criteria_type VARCHAR(50),  -- hours, shifts, doors, calls, points, streak
    criteria_value INTEGER,
    activity_type VARCHAR(100),  -- for activity-specific badges
    
    -- Rewards
    points_reward INTEGER DEFAULT 0,
    
    -- Rarity
    rarity VARCHAR(20) DEFAULT 'common',  -- common, uncommon, rare, epic, legendary
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Achievement Earnings
CREATE TABLE IF NOT EXISTS volunteer_achievement_earnings (
    earning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    achievement_id UUID REFERENCES volunteer_achievements(achievement_id),
    
    earned_at TIMESTAMP DEFAULT NOW(),
    notified BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_achievement_account ON volunteer_achievement_earnings(account_id);

-- Volunteer Teams
CREATE TABLE IF NOT EXISTS volunteer_portal_teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name VARCHAR(255) NOT NULL,
    description TEXT,
    avatar_url TEXT,
    
    -- Leadership
    captain_account_id UUID REFERENCES volunteer_accounts(account_id),
    
    -- Stats
    member_count INTEGER DEFAULT 0,
    total_hours DECIMAL(10,2) DEFAULT 0,
    total_points INTEGER DEFAULT 0,
    
    -- Competition
    is_competing BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Team Memberships
CREATE TABLE IF NOT EXISTS volunteer_team_members (
    membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES volunteer_portal_teams(team_id),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    
    role VARCHAR(50) DEFAULT 'member',  -- captain, co-captain, member
    joined_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_team_member_team ON volunteer_team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_member_account ON volunteer_team_members(account_id);

-- Volunteer Messages/Announcements
CREATE TABLE IF NOT EXISTS volunteer_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Target
    target_type VARCHAR(50) NOT NULL,  -- all, team, individual
    target_id UUID,  -- team_id or account_id
    
    -- Content
    subject VARCHAR(500),
    message TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'announcement',
    
    -- Sender
    sender_name VARCHAR(255),
    
    -- Status
    is_pinned BOOLEAN DEFAULT false,
    expires_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Message Read Status
CREATE TABLE IF NOT EXISTS volunteer_message_reads (
    read_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES volunteer_messages(message_id),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    
    read_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_volunteer_dashboard AS
SELECT 
    va.account_id,
    va.volunteer_id,
    va.display_name,
    va.points,
    va.level,
    va.current_streak,
    
    -- Stats
    COALESCE(SUM(vs.hours_worked), 0) as total_hours,
    COUNT(DISTINCT vs.signup_id) FILTER (WHERE vs.status = 'completed') as shifts_completed,
    COALESCE(SUM(vs.doors_knocked), 0) as total_doors,
    COALESCE(SUM(vs.calls_made), 0) as total_calls,
    COALESCE(SUM(vs.points_earned), 0) as total_points_earned,
    
    -- Badges
    (SELECT COUNT(*) FROM volunteer_achievement_earnings ae 
     WHERE ae.account_id = va.account_id) as badge_count,
    
    -- Upcoming
    (SELECT COUNT(*) FROM volunteer_signups s 
     JOIN volunteer_opportunities o ON s.opportunity_id = o.opportunity_id
     WHERE s.account_id = va.account_id 
     AND s.status = 'confirmed'
     AND o.start_datetime > NOW()) as upcoming_shifts

FROM volunteer_accounts va
LEFT JOIN volunteer_signups vs ON va.account_id = vs.account_id
GROUP BY va.account_id;

CREATE OR REPLACE VIEW v_volunteer_leaderboard AS
SELECT 
    va.account_id,
    va.display_name,
    va.points,
    va.level,
    COALESCE(SUM(vs.hours_worked), 0) as total_hours,
    COALESCE(SUM(vs.doors_knocked), 0) as total_doors,
    COALESCE(SUM(vs.calls_made), 0) as total_calls,
    COUNT(DISTINCT vs.signup_id) FILTER (WHERE vs.status = 'completed') as shifts_completed,
    (SELECT COUNT(*) FROM volunteer_achievement_earnings ae WHERE ae.account_id = va.account_id) as badges,
    RANK() OVER (ORDER BY va.points DESC) as rank
FROM volunteer_accounts va
LEFT JOIN volunteer_signups vs ON va.account_id = vs.account_id AND vs.status = 'completed'
WHERE va.is_active = true
GROUP BY va.account_id
ORDER BY va.points DESC;

CREATE OR REPLACE VIEW v_team_leaderboard AS
SELECT 
    t.team_id,
    t.name,
    t.member_count,
    t.total_hours,
    t.total_points,
    RANK() OVER (ORDER BY t.total_points DESC) as rank
FROM volunteer_portal_teams t
WHERE t.is_competing = true
ORDER BY t.total_points DESC;

CREATE OR REPLACE VIEW v_available_opportunities AS
SELECT 
    o.*,
    o.max_volunteers - o.current_signups as spots_available,
    CASE 
        WHEN o.max_volunteers IS NULL THEN 'unlimited'
        WHEN o.current_signups >= o.max_volunteers THEN 'full'
        WHEN o.current_signups >= o.max_volunteers * 0.8 THEN 'filling'
        ELSE 'open'
    END as availability_status
FROM volunteer_opportunities o
WHERE o.status = 'open'
AND o.start_datetime > NOW()
ORDER BY o.start_datetime ASC;

SELECT 'Volunteer Portal schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_27_realtime_dashboard_complete.py (E27)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 27: REAL-TIME DASHBOARD
-- ============================================================================

-- Dashboard Configurations
CREATE TABLE IF NOT EXISTS realtime_dashboards (
    dashboard_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Identity
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Display
    layout_type VARCHAR(50) DEFAULT 'grid',  -- grid, freeform, presentation
    background_color VARCHAR(20) DEFAULT '#1a1a2e',
    theme VARCHAR(50) DEFAULT 'dark',
    
    -- Settings
    auto_rotate BOOLEAN DEFAULT false,
    rotate_interval_seconds INTEGER DEFAULT 30,
    refresh_interval_ms INTEGER DEFAULT 5000,
    
    -- Access
    is_public BOOLEAN DEFAULT false,
    access_code VARCHAR(50),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rt_dashboard_candidate ON realtime_dashboards(candidate_id);

-- Dashboard Widgets
CREATE TABLE IF NOT EXISTS realtime_widgets (
    widget_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dashboard_id UUID REFERENCES realtime_dashboards(dashboard_id),
    
    -- Widget type
    widget_type VARCHAR(50) NOT NULL,
    title VARCHAR(255),
    
    -- Position & Size
    position_x INTEGER DEFAULT 0,
    position_y INTEGER DEFAULT 0,
    width INTEGER DEFAULT 4,
    height INTEGER DEFAULT 3,
    z_index INTEGER DEFAULT 1,
    
    -- Data configuration
    metric_type VARCHAR(50),
    data_source VARCHAR(100),
    data_query TEXT,
    data_config JSONB DEFAULT '{}',
    
    -- Display configuration
    display_config JSONB DEFAULT '{}',
    animation VARCHAR(50) DEFAULT 'fade',
    
    -- Thresholds for alerts
    warning_threshold DECIMAL(12,2),
    critical_threshold DECIMAL(12,2),
    
    -- Refresh
    refresh_interval_ms INTEGER,
    
    is_visible BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rt_widget_dashboard ON realtime_widgets(dashboard_id);

-- Real-time Metrics Cache
CREATE TABLE IF NOT EXISTS realtime_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Metric identity
    metric_name VARCHAR(100) NOT NULL,
    metric_type VARCHAR(50) NOT NULL,
    
    -- Current value
    current_value DECIMAL(15,2),
    previous_value DECIMAL(15,2),
    
    -- Change tracking
    change_value DECIMAL(15,2),
    change_percent DECIMAL(8,2),
    change_direction VARCHAR(10),  -- up, down, flat
    
    -- Time tracking
    period_start TIMESTAMP,
    period_end TIMESTAMP,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_rt_metric_unique ON realtime_metrics(candidate_id, metric_name);
CREATE INDEX IF NOT EXISTS idx_rt_metric_updated ON realtime_metrics(updated_at);

-- Live Event Stream
CREATE TABLE IF NOT EXISTS realtime_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Event
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL,
    
    -- Display
    display_text TEXT,
    icon VARCHAR(50),
    color VARCHAR(20),
    
    -- Priority
    priority INTEGER DEFAULT 5,
    
    -- TTL
    expires_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rt_event_candidate ON realtime_events(candidate_id);
CREATE INDEX IF NOT EXISTS idx_rt_event_created ON realtime_events(created_at);
CREATE INDEX IF NOT EXISTS idx_rt_event_type ON realtime_events(event_type);

-- Goals for gauges
CREATE TABLE IF NOT EXISTS realtime_goals (
    goal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Goal
    name VARCHAR(255) NOT NULL,
    goal_type VARCHAR(50),
    
    -- Target
    target_value DECIMAL(15,2) NOT NULL,
    current_value DECIMAL(15,2) DEFAULT 0,
    
    -- Display
    display_format VARCHAR(50) DEFAULT 'number',  -- number, currency, percent
    color VARCHAR(20) DEFAULT '#4CAF50',
    
    -- Milestones
    milestones JSONB DEFAULT '[]',
    
    -- Time
    deadline TIMESTAMP,
    
    is_active BOOLEAN DEFAULT true,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rt_goal_candidate ON realtime_goals(candidate_id);

-- Countdown Timers
CREATE TABLE IF NOT EXISTS realtime_countdowns (
    countdown_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Countdown
    name VARCHAR(255) NOT NULL,
    target_datetime TIMESTAMP NOT NULL,
    
    -- Display
    display_format VARCHAR(50) DEFAULT 'dhms',  -- dhms, hms, days
    show_after_zero BOOLEAN DEFAULT false,
    
    -- Styling
    color VARCHAR(20),
    size VARCHAR(20) DEFAULT 'large',
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Geographic Data Points
CREATE TABLE IF NOT EXISTS realtime_geo_data (
    geo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Location
    location_type VARCHAR(50),  -- county, city, precinct, zip
    location_name VARCHAR(255),
    location_code VARCHAR(50),
    
    -- Coordinates
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    
    -- Metrics
    metric_name VARCHAR(100),
    metric_value DECIMAL(15,2),
    
    -- Display
    color VARCHAR(20),
    intensity DECIMAL(5,2),
    
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rt_geo_candidate ON realtime_geo_data(candidate_id);
CREATE INDEX IF NOT EXISTS idx_rt_geo_location ON realtime_geo_data(location_code);

-- Alert Rules
CREATE TABLE IF NOT EXISTS realtime_alert_rules (
    rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Rule
    name VARCHAR(255) NOT NULL,
    metric_name VARCHAR(100),
    
    -- Condition
    condition_type VARCHAR(50),  -- gt, lt, eq, change_pct
    condition_value DECIMAL(15,2),
    
    -- Alert
    alert_level VARCHAR(20) DEFAULT 'info',  -- info, warning, critical
    alert_message TEXT,
    
    -- Actions
    play_sound BOOLEAN DEFAULT false,
    sound_file VARCHAR(255),
    flash_screen BOOLEAN DEFAULT false,
    
    -- Cooldown
    cooldown_minutes INTEGER DEFAULT 5,
    last_triggered_at TIMESTAMP,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_live_donation_ticker AS
SELECT 
    d.donation_id,
    d.candidate_id,
    d.amount,
    d.created_at,
    c.first_name,
    c.last_name,
    c.city,
    c.state,
    CASE 
        WHEN d.is_first_donation THEN 'new_donor'
        WHEN d.amount >= 1000 THEN 'major'
        WHEN d.amount >= 500 THEN 'significant'
        ELSE 'standard'
    END as donation_tier
FROM donations d
LEFT JOIN contacts c ON d.donor_id = c.contact_id
WHERE d.created_at > NOW() - INTERVAL '24 hours'
ORDER BY d.created_at DESC;

CREATE OR REPLACE VIEW v_realtime_summary AS
SELECT 
    candidate_id,
    
    -- Today's donations
    COALESCE(SUM(CASE WHEN created_at::date = CURRENT_DATE THEN amount END), 0) as today_raised,
    COUNT(CASE WHEN created_at::date = CURRENT_DATE THEN 1 END) as today_donations,
    
    -- Last hour
    COALESCE(SUM(CASE WHEN created_at > NOW() - INTERVAL '1 hour' THEN amount END), 0) as hour_raised,
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 hour' THEN 1 END) as hour_donations,
    
    -- Last 24 hours
    COALESCE(SUM(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN amount END), 0) as day_raised,
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as day_donations
    
FROM donations
GROUP BY candidate_id;

SELECT 'Real-Time Dashboard schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_28_financial_dashboard_complete.py (E28)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 28: FINANCIAL DASHBOARD
-- ============================================================================

-- Financial Periods
CREATE TABLE IF NOT EXISTS financial_periods (
    period_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Period
    period_type VARCHAR(20) NOT NULL,  -- month, quarter, year, fec_period
    period_name VARCHAR(100),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- Status
    is_closed BOOLEAN DEFAULT false,
    closed_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fin_period_candidate ON financial_periods(candidate_id);
CREATE INDEX IF NOT EXISTS idx_fin_period_dates ON financial_periods(start_date, end_date);

-- Budget Categories
CREATE TABLE IF NOT EXISTS budget_categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Category
    category_code VARCHAR(50) NOT NULL,
    category_name VARCHAR(255) NOT NULL,
    parent_category_id UUID REFERENCES budget_categories(category_id),
    
    -- FEC mapping
    fec_category VARCHAR(100),
    
    -- Display
    display_order INTEGER DEFAULT 0,
    color VARCHAR(20),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_budget_cat_candidate ON budget_categories(candidate_id);

-- Budget Allocations
CREATE TABLE IF NOT EXISTS budget_allocations (
    allocation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    category_id UUID REFERENCES budget_categories(category_id),
    period_id UUID REFERENCES financial_periods(period_id),
    
    -- Budget
    budgeted_amount DECIMAL(12,2) NOT NULL,
    
    -- Actuals (updated by triggers/sync)
    actual_amount DECIMAL(12,2) DEFAULT 0,
    committed_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Variance
    variance_amount DECIMAL(12,2) GENERATED ALWAYS AS (budgeted_amount - actual_amount) STORED,
    variance_percent DECIMAL(8,2),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_budget_alloc_candidate ON budget_allocations(candidate_id);
CREATE INDEX IF NOT EXISTS idx_budget_alloc_category ON budget_allocations(category_id);
CREATE INDEX IF NOT EXISTS idx_budget_alloc_period ON budget_allocations(period_id);

-- Expenses
CREATE TABLE IF NOT EXISTS financial_expenses (
    expense_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    category_id UUID REFERENCES budget_categories(category_id),
    
    -- Expense details
    description TEXT NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    
    -- Vendor
    vendor_id UUID,
    vendor_name VARCHAR(255),
    
    -- Dates
    expense_date DATE NOT NULL,
    paid_date DATE,
    
    -- Payment
    payment_method VARCHAR(50),
    check_number VARCHAR(50),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',  -- pending, approved, paid, void
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    
    -- FEC
    fec_category VARCHAR(100),
    is_fec_reportable BOOLEAN DEFAULT true,
    
    -- Attachments
    receipt_url TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expense_candidate ON financial_expenses(candidate_id);
CREATE INDEX IF NOT EXISTS idx_expense_category ON financial_expenses(category_id);
CREATE INDEX IF NOT EXISTS idx_expense_date ON financial_expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_expense_status ON financial_expenses(status);

-- Vendor Summary
CREATE TABLE IF NOT EXISTS financial_vendors (
    vendor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Vendor
    name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    
    -- Type
    vendor_type VARCHAR(100),
    
    -- Totals
    total_paid DECIMAL(12,2) DEFAULT 0,
    total_committed DECIMAL(12,2) DEFAULT 0,
    transaction_count INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_candidate ON financial_vendors(candidate_id);

-- Cash Flow Entries
CREATE TABLE IF NOT EXISTS cash_flow_entries (
    entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Entry
    entry_type VARCHAR(20) NOT NULL,  -- inflow, outflow
    category VARCHAR(100),
    description TEXT,
    amount DECIMAL(12,2) NOT NULL,
    
    -- Date
    entry_date DATE NOT NULL,
    
    -- Status
    is_projected BOOLEAN DEFAULT false,
    is_recurring BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cashflow_candidate ON cash_flow_entries(candidate_id);
CREATE INDEX IF NOT EXISTS idx_cashflow_date ON cash_flow_entries(entry_date);

-- Financial Snapshots (daily/weekly)
CREATE TABLE IF NOT EXISTS financial_snapshots (
    snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Date
    snapshot_date DATE NOT NULL,
    
    -- Balances
    cash_on_hand DECIMAL(12,2),
    accounts_receivable DECIMAL(12,2),
    accounts_payable DECIMAL(12,2),
    
    -- Period totals
    period_receipts DECIMAL(12,2),
    period_disbursements DECIMAL(12,2),
    
    -- Cumulative
    total_raised DECIMAL(12,2),
    total_spent DECIMAL(12,2),
    
    -- Metrics
    burn_rate_daily DECIMAL(10,2),
    runway_days INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_snapshot_unique ON financial_snapshots(candidate_id, snapshot_date);

-- Fundraising Costs
CREATE TABLE IF NOT EXISTS fundraising_costs (
    cost_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Channel
    channel VARCHAR(100) NOT NULL,
    campaign_id UUID,
    
    -- Costs
    cost_amount DECIMAL(12,2) NOT NULL,
    
    -- Results
    amount_raised DECIMAL(12,2) DEFAULT 0,
    donor_count INTEGER DEFAULT 0,
    new_donor_count INTEGER DEFAULT 0,
    
    -- Calculated
    cost_per_dollar DECIMAL(8,4),
    cost_per_donor DECIMAL(10,2),
    roi_percent DECIMAL(8,2),
    
    -- Period
    period_start DATE,
    period_end DATE,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fund_cost_candidate ON fundraising_costs(candidate_id);

-- Views
CREATE OR REPLACE VIEW v_budget_vs_actual AS
SELECT 
    ba.candidate_id,
    bc.category_code,
    bc.category_name,
    fp.period_name,
    ba.budgeted_amount,
    ba.actual_amount,
    ba.committed_amount,
    ba.budgeted_amount - ba.actual_amount as variance,
    CASE WHEN ba.budgeted_amount > 0 
         THEN ROUND((ba.actual_amount / ba.budgeted_amount) * 100, 1)
         ELSE 0 END as pct_used,
    CASE 
        WHEN ba.actual_amount > ba.budgeted_amount THEN 'over_budget'
        WHEN ba.actual_amount > ba.budgeted_amount * 0.9 THEN 'warning'
        ELSE 'on_track'
    END as status
FROM budget_allocations ba
JOIN budget_categories bc ON ba.category_id = bc.category_id
JOIN financial_periods fp ON ba.period_id = fp.period_id;

CREATE OR REPLACE VIEW v_expense_summary AS
SELECT 
    candidate_id,
    category_id,
    DATE_TRUNC('month', expense_date) as month,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount
FROM financial_expenses
WHERE status != 'void'
GROUP BY candidate_id, category_id, DATE_TRUNC('month', expense_date);

CREATE OR REPLACE VIEW v_vendor_spending AS
SELECT 
    e.candidate_id,
    e.vendor_name,
    COUNT(*) as transaction_count,
    SUM(e.amount) as total_spent,
    MAX(e.expense_date) as last_expense_date,
    STRING_AGG(DISTINCT bc.category_name, ', ') as categories
FROM financial_expenses e
LEFT JOIN budget_categories bc ON e.category_id = bc.category_id
WHERE e.status != 'void'
GROUP BY e.candidate_id, e.vendor_name;

CREATE OR REPLACE VIEW v_cash_flow_summary AS
SELECT 
    candidate_id,
    DATE_TRUNC('week', entry_date) as week,
    SUM(CASE WHEN entry_type = 'inflow' THEN amount ELSE 0 END) as inflows,
    SUM(CASE WHEN entry_type = 'outflow' THEN amount ELSE 0 END) as outflows,
    SUM(CASE WHEN entry_type = 'inflow' THEN amount ELSE -amount END) as net_flow
FROM cash_flow_entries
WHERE is_projected = false
GROUP BY candidate_id, DATE_TRUNC('week', entry_date);

CREATE OR REPLACE VIEW v_fundraising_efficiency AS
SELECT 
    candidate_id,
    channel,
    SUM(cost_amount) as total_cost,
    SUM(amount_raised) as total_raised,
    SUM(donor_count) as total_donors,
    SUM(new_donor_count) as total_new_donors,
    CASE WHEN SUM(amount_raised) > 0 
         THEN ROUND(SUM(cost_amount) / SUM(amount_raised), 4)
         ELSE NULL END as cost_per_dollar,
    CASE WHEN SUM(donor_count) > 0
         THEN ROUND(SUM(cost_amount) / SUM(donor_count), 2)
         ELSE NULL END as cost_per_donor,
    CASE WHEN SUM(cost_amount) > 0
         THEN ROUND(((SUM(amount_raised) - SUM(cost_amount)) / SUM(cost_amount)) * 100, 1)
         ELSE NULL END as roi_percent
FROM fundraising_costs
GROUP BY candidate_id, channel;

SELECT 'Financial Dashboard schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_29_analytics_dashboard_complete.py (E29)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 29: ANALYTICS DASHBOARD
-- ============================================================================

-- KPI Definitions
CREATE TABLE IF NOT EXISTS analytics_kpis (
    kpi_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- KPI Definition
    kpi_code VARCHAR(100) NOT NULL,
    kpi_name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    
    -- Calculation
    calculation_type VARCHAR(50),  -- sum, avg, count, ratio, custom
    source_table VARCHAR(100),
    source_column VARCHAR(100),
    calculation_formula TEXT,
    
    -- Display
    display_format VARCHAR(50) DEFAULT 'number',  -- number, currency, percent, duration
    decimal_places INTEGER DEFAULT 0,
    
    -- Targets for variance
    target_value DECIMAL(15,2),
    target_type VARCHAR(20) DEFAULT 'fixed',  -- fixed, growth_rate, benchmark
    warning_threshold_pct DECIMAL(5,2) DEFAULT 10,
    critical_threshold_pct DECIMAL(5,2) DEFAULT 25,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kpi_candidate ON analytics_kpis(candidate_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_kpi_code ON analytics_kpis(candidate_id, kpi_code);

-- KPI Values (time series)
CREATE TABLE IF NOT EXISTS analytics_kpi_values (
    value_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kpi_id UUID REFERENCES analytics_kpis(kpi_id),
    candidate_id UUID,
    
    -- Period
    period_date DATE NOT NULL,
    period_type VARCHAR(20) DEFAULT 'daily',  -- daily, weekly, monthly
    
    -- Values
    actual_value DECIMAL(15,2),
    target_value DECIMAL(15,2),
    previous_value DECIMAL(15,2),
    
    -- Variance calculations
    variance_amount DECIMAL(15,2),
    variance_percent DECIMAL(8,2),
    variance_status VARCHAR(20),
    
    -- Period-over-period
    pop_change_amount DECIMAL(15,2),
    pop_change_percent DECIMAL(8,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kpi_value_kpi ON analytics_kpi_values(kpi_id);
CREATE INDEX IF NOT EXISTS idx_kpi_value_date ON analytics_kpi_values(period_date);
CREATE UNIQUE INDEX IF NOT EXISTS idx_kpi_value_unique ON analytics_kpi_values(kpi_id, period_date, period_type);

-- Channel Performance
CREATE TABLE IF NOT EXISTS analytics_channel_performance (
    perf_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Channel
    channel VARCHAR(100) NOT NULL,
    
    -- Period
    period_date DATE NOT NULL,
    period_type VARCHAR(20) DEFAULT 'daily',
    
    -- Metrics
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    revenue DECIMAL(12,2) DEFAULT 0,
    cost DECIMAL(12,2) DEFAULT 0,
    
    -- Calculated metrics
    ctr DECIMAL(8,4),
    conversion_rate DECIMAL(8,4),
    cpc DECIMAL(10,2),
    cpa DECIMAL(10,2),
    roas DECIMAL(8,2),
    
    -- Targets for variance
    target_conversions INTEGER,
    target_revenue DECIMAL(12,2),
    conversion_variance_pct DECIMAL(8,2),
    revenue_variance_pct DECIMAL(8,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_channel_perf_candidate ON analytics_channel_performance(candidate_id);
CREATE INDEX IF NOT EXISTS idx_channel_perf_channel ON analytics_channel_performance(channel);
CREATE INDEX IF NOT EXISTS idx_channel_perf_date ON analytics_channel_performance(period_date);

-- Funnel Stages
CREATE TABLE IF NOT EXISTS analytics_funnel_stages (
    stage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    funnel_name VARCHAR(100) NOT NULL,
    stage_name VARCHAR(100) NOT NULL,
    stage_order INTEGER NOT NULL,
    
    -- Period
    period_date DATE NOT NULL,
    
    -- Counts
    entered_count INTEGER DEFAULT 0,
    completed_count INTEGER DEFAULT 0,
    dropped_count INTEGER DEFAULT 0,
    
    -- Rates
    completion_rate DECIMAL(8,4),
    drop_rate DECIMAL(8,4),
    
    -- Time
    avg_time_in_stage_hours DECIMAL(10,2),
    
    -- Variance
    target_completion_rate DECIMAL(8,4),
    variance_pct DECIMAL(8,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_funnel_candidate ON analytics_funnel_stages(candidate_id);
CREATE INDEX IF NOT EXISTS idx_funnel_name ON analytics_funnel_stages(funnel_name);

-- Cohort Analysis
CREATE TABLE IF NOT EXISTS analytics_cohorts (
    cohort_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Cohort definition
    cohort_type VARCHAR(50) NOT NULL,  -- acquisition_month, first_channel, first_amount
    cohort_value VARCHAR(100) NOT NULL,
    cohort_date DATE,
    
    -- Size
    cohort_size INTEGER,
    
    -- Retention (by period number)
    period_number INTEGER,
    active_count INTEGER,
    retention_rate DECIMAL(8,4),
    
    -- Value
    period_revenue DECIMAL(12,2),
    cumulative_revenue DECIMAL(12,2),
    ltv_to_date DECIMAL(12,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cohort_candidate ON analytics_cohorts(candidate_id);
CREATE INDEX IF NOT EXISTS idx_cohort_type ON analytics_cohorts(cohort_type);

-- Geographic Performance
CREATE TABLE IF NOT EXISTS analytics_geo_performance (
    geo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Geography
    geo_level VARCHAR(50),  -- state, county, city, zip, precinct
    geo_code VARCHAR(50),
    geo_name VARCHAR(255),
    
    -- Period
    period_date DATE NOT NULL,
    
    -- Metrics
    donor_count INTEGER DEFAULT 0,
    donation_amount DECIMAL(12,2) DEFAULT 0,
    volunteer_count INTEGER DEFAULT 0,
    volunteer_hours DECIMAL(10,2) DEFAULT 0,
    doors_knocked INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    
    -- Targets & Variance
    target_donors INTEGER,
    target_amount DECIMAL(12,2),
    donor_variance_pct DECIMAL(8,2),
    amount_variance_pct DECIMAL(8,2),
    
    -- Penetration
    registered_voters INTEGER,
    penetration_rate DECIMAL(8,4),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_geo_candidate ON analytics_geo_performance(candidate_id);
CREATE INDEX IF NOT EXISTS idx_geo_code ON analytics_geo_performance(geo_code);

-- Custom Reports
CREATE TABLE IF NOT EXISTS analytics_saved_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Report
    name VARCHAR(255) NOT NULL,
    description TEXT,
    report_type VARCHAR(50),
    
    -- Configuration
    metrics JSONB DEFAULT '[]',
    dimensions JSONB DEFAULT '[]',
    filters JSONB DEFAULT '{}',
    sort_config JSONB DEFAULT '{}',
    
    -- Display
    chart_type VARCHAR(50),
    visualization_config JSONB DEFAULT '{}',
    
    -- Variance settings
    show_variance BOOLEAN DEFAULT true,
    variance_baseline VARCHAR(50),  -- target, previous_period, same_period_last_year
    
    -- Schedule
    is_scheduled BOOLEAN DEFAULT false,
    schedule_cron VARCHAR(100),
    recipients JSONB DEFAULT '[]',
    
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_report_candidate ON analytics_saved_reports(candidate_id);

-- Variance Alerts
CREATE TABLE IF NOT EXISTS analytics_variance_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Source
    kpi_id UUID REFERENCES analytics_kpis(kpi_id),
    metric_name VARCHAR(255),
    
    -- Variance
    actual_value DECIMAL(15,2),
    target_value DECIMAL(15,2),
    variance_amount DECIMAL(15,2),
    variance_percent DECIMAL(8,2),
    variance_status VARCHAR(20),
    
    -- Alert
    alert_message TEXT,
    severity VARCHAR(20),
    
    -- Status
    is_acknowledged BOOLEAN DEFAULT false,
    acknowledged_by VARCHAR(255),
    acknowledged_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_variance_alert_candidate ON analytics_variance_alerts(candidate_id);
CREATE INDEX IF NOT EXISTS idx_variance_alert_status ON analytics_variance_alerts(variance_status);

-- Views
CREATE OR REPLACE VIEW v_kpi_with_variance AS
SELECT 
    kv.value_id,
    k.candidate_id,
    k.kpi_code,
    k.kpi_name,
    k.category,
    kv.period_date,
    kv.actual_value,
    kv.target_value,
    kv.variance_amount,
    kv.variance_percent,
    kv.variance_status,
    kv.pop_change_percent,
    k.display_format,
    CASE 
        WHEN kv.variance_status = 'exceeding' THEN '#4CAF50'
        WHEN kv.variance_status = 'on_target' THEN '#2196F3'
        WHEN kv.variance_status = 'below' THEN '#FF9800'
        WHEN kv.variance_status = 'critical' THEN '#F44336'
        ELSE '#9E9E9E'
    END as status_color
FROM analytics_kpi_values kv
JOIN analytics_kpis k ON kv.kpi_id = k.kpi_id;

CREATE OR REPLACE VIEW v_channel_comparison AS
SELECT 
    candidate_id,
    channel,
    SUM(impressions) as total_impressions,
    SUM(clicks) as total_clicks,
    SUM(conversions) as total_conversions,
    SUM(revenue) as total_revenue,
    SUM(cost) as total_cost,
    CASE WHEN SUM(impressions) > 0 
         THEN ROUND(SUM(clicks)::DECIMAL / SUM(impressions) * 100, 2)
         ELSE 0 END as avg_ctr,
    CASE WHEN SUM(clicks) > 0
         THEN ROUND(SUM(conversions)::DECIMAL / SUM(clicks) * 100, 2)
         ELSE 0 END as avg_conv_rate,
    CASE WHEN SUM(cost) > 0
         THEN ROUND(SUM(revenue) / SUM(cost), 2)
         ELSE 0 END as overall_roas,
    -- Variance from target
    CASE WHEN SUM(target_revenue) > 0
         THEN ROUND((SUM(revenue) - SUM(target_revenue)) / SUM(target_revenue) * 100, 1)
         ELSE NULL END as revenue_variance_pct
FROM analytics_channel_performance
WHERE period_date > CURRENT_DATE - INTERVAL '30 days'
GROUP BY candidate_id, channel;

CREATE OR REPLACE VIEW v_variance_summary AS
SELECT 
    candidate_id,
    COUNT(*) FILTER (WHERE variance_status = 'exceeding') as exceeding_count,
    COUNT(*) FILTER (WHERE variance_status = 'on_target') as on_target_count,
    COUNT(*) FILTER (WHERE variance_status = 'below') as below_count,
    COUNT(*) FILTER (WHERE variance_status = 'critical') as critical_count,
    ROUND(AVG(variance_percent), 1) as avg_variance_pct
FROM analytics_kpi_values
WHERE period_date = CURRENT_DATE - 1
GROUP BY candidate_id;

SELECT 'Analytics Dashboard schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_30_email_complete.py (E30)
-- ================================================================

-- Email Campaigns
CREATE TABLE IF NOT EXISTS email_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(500),
    from_email VARCHAR(255),
    from_name VARCHAR(255),
    html_content TEXT,
    text_content TEXT,
    template_id UUID,
    status VARCHAR(50) DEFAULT 'draft',
    scheduled_for TIMESTAMP,
    sent_at TIMESTAMP,
    total_recipients INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    open_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    bounce_count INTEGER DEFAULT 0,
    unsubscribe_count INTEGER DEFAULT 0,
    complaint_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_campaigns_status ON email_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_email_campaigns_candidate ON email_campaigns(candidate_id);
CREATE INDEX IF NOT EXISTS idx_email_campaigns_scheduled ON email_campaigns(scheduled_for);

-- Email Templates
CREATE TABLE IF NOT EXISTS email_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(500),
    html_content TEXT NOT NULL,
    text_content TEXT,
    variables JSONB DEFAULT '[]',
    category VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_templates_candidate ON email_templates(candidate_id);

-- Individual Email Sends
CREATE TABLE IF NOT EXISTS email_sends (
    send_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES email_campaigns(campaign_id),
    recipient_email VARCHAR(255) NOT NULL,
    recipient_id UUID,  -- donor_id or contact_id
    variant_id VARCHAR(100),  -- For A/B testing
    status VARCHAR(50) DEFAULT 'pending',
    subject VARCHAR(500),
    personalized_content TEXT,
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    bounced_at TIMESTAMP,
    bounce_type VARCHAR(50),
    bounce_reason TEXT,
    unsubscribed_at TIMESTAMP,
    provider_message_id VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_sends_campaign ON email_sends(campaign_id);
CREATE INDEX IF NOT EXISTS idx_email_sends_recipient ON email_sends(recipient_email);
CREATE INDEX IF NOT EXISTS idx_email_sends_status ON email_sends(status);
CREATE INDEX IF NOT EXISTS idx_email_sends_variant ON email_sends(variant_id);

-- Email Opens (detailed tracking)
CREATE TABLE IF NOT EXISTS email_opens (
    open_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    send_id UUID REFERENCES email_sends(send_id),
    opened_at TIMESTAMP DEFAULT NOW(),
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_type VARCHAR(50),
    is_first_open BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_email_opens_send ON email_opens(send_id);

-- Email Clicks (detailed tracking)
CREATE TABLE IF NOT EXISTS email_clicks (
    click_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    send_id UUID REFERENCES email_sends(send_id),
    clicked_at TIMESTAMP DEFAULT NOW(),
    link_url TEXT,
    link_text VARCHAR(255),
    ip_address VARCHAR(45),
    user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_email_clicks_send ON email_clicks(send_id);

-- A/B Tests (UNLIMITED)
CREATE TABLE IF NOT EXISTS email_ab_tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES email_campaigns(campaign_id),
    name VARCHAR(255),
    test_type VARCHAR(50) NOT NULL,  -- subject, content, from_name, send_time, cta
    status VARCHAR(50) DEFAULT 'running',
    winner_variant_id VARCHAR(100),
    confidence_level DECIMAL(5,4),
    min_sample_size INTEGER DEFAULT 100,
    auto_select_winner BOOLEAN DEFAULT true,
    winner_criteria VARCHAR(50) DEFAULT 'open_rate',  -- open_rate, click_rate, conversion_rate
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ab_tests_campaign ON email_ab_tests(campaign_id);

-- A/B Test Variants (UNLIMITED per test)
CREATE TABLE IF NOT EXISTS email_ab_variants (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES email_ab_tests(test_id),
    variant_code VARCHAR(10) NOT NULL,  -- A, B, C, D, E, etc.
    name VARCHAR(255),
    value TEXT NOT NULL,  -- The actual variant content
    allocation_pct DECIMAL(5,2) DEFAULT 50.00,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    open_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    conversion_count INTEGER DEFAULT 0,
    revenue DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_variants_test ON email_ab_variants(test_id);

-- Drip Sequences
CREATE TABLE IF NOT EXISTS email_drip_sequences (
    sequence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    trigger_event VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    total_enrolled INTEGER DEFAULT 0,
    total_completed INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Drip Steps
CREATE TABLE IF NOT EXISTS email_drip_steps (
    step_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_id UUID REFERENCES email_drip_sequences(sequence_id),
    step_number INTEGER NOT NULL,
    template_id UUID REFERENCES email_templates(template_id),
    delay_days INTEGER DEFAULT 0,
    delay_hours INTEGER DEFAULT 0,
    condition_type VARCHAR(50),  -- none, opened_previous, clicked_previous, not_opened
    condition_value TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_drip_steps_sequence ON email_drip_steps(sequence_id);

-- Drip Enrollments
CREATE TABLE IF NOT EXISTS email_drip_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_id UUID REFERENCES email_drip_sequences(sequence_id),
    recipient_id UUID NOT NULL,
    recipient_email VARCHAR(255) NOT NULL,
    current_step INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'active',  -- active, completed, paused, cancelled
    enrolled_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    next_send_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_drip_enrollments_sequence ON email_drip_enrollments(sequence_id);
CREATE INDEX IF NOT EXISTS idx_drip_enrollments_next_send ON email_drip_enrollments(next_send_at);

-- Bounce Management
CREATE TABLE IF NOT EXISTS email_bounces (
    bounce_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_address VARCHAR(255) NOT NULL,
    bounce_type VARCHAR(50) NOT NULL,
    bounce_reason TEXT,
    bounced_at TIMESTAMP DEFAULT NOW(),
    campaign_id UUID,
    is_permanent BOOLEAN DEFAULT false
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_email_bounces_email ON email_bounces(email_address);

-- Unsubscribes
CREATE TABLE IF NOT EXISTS email_unsubscribes (
    unsubscribe_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_address VARCHAR(255) NOT NULL,
    reason VARCHAR(255),
    unsubscribed_at TIMESTAMP DEFAULT NOW(),
    campaign_id UUID
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_email_unsubscribes_email ON email_unsubscribes(email_address);

-- Send Time Optimization
CREATE TABLE IF NOT EXISTS email_send_time_stats (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_email VARCHAR(255) NOT NULL,
    best_day_of_week INTEGER,  -- 0=Monday, 6=Sunday
    best_hour INTEGER,  -- 0-23
    avg_open_time_hours DECIMAL(5,2),
    total_sends INTEGER DEFAULT 0,
    total_opens INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_send_time_email ON email_send_time_stats(recipient_email);

-- Engagement Scores
CREATE TABLE IF NOT EXISTS email_engagement_scores (
    score_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_email VARCHAR(255) NOT NULL,
    engagement_score DECIMAL(5,2) DEFAULT 50.00,  -- 0-100
    open_rate DECIMAL(5,4),
    click_rate DECIMAL(5,4),
    total_received INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    last_opened_at TIMESTAMP,
    last_clicked_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_engagement_email ON email_engagement_scores(recipient_email);

-- Campaign Performance View
CREATE OR REPLACE VIEW v_email_campaign_performance AS
SELECT 
    c.campaign_id,
    c.name,
    c.status,
    c.sent_at,
    c.total_recipients,
    c.sent_count,
    c.delivered_count,
    c.open_count,
    c.click_count,
    c.bounce_count,
    c.unsubscribe_count,
    CASE WHEN c.sent_count > 0 THEN ROUND(c.delivered_count::DECIMAL / c.sent_count * 100, 2) ELSE 0 END as delivery_rate,
    CASE WHEN c.delivered_count > 0 THEN ROUND(c.open_count::DECIMAL / c.delivered_count * 100, 2) ELSE 0 END as open_rate,
    CASE WHEN c.open_count > 0 THEN ROUND(c.click_count::DECIMAL / c.open_count * 100, 2) ELSE 0 END as click_to_open_rate,
    CASE WHEN c.delivered_count > 0 THEN ROUND(c.click_count::DECIMAL / c.delivered_count * 100, 2) ELSE 0 END as click_rate
FROM email_campaigns c
ORDER BY c.created_at DESC;

-- A/B Test Results View
CREATE OR REPLACE VIEW v_ab_test_results AS
SELECT 
    t.test_id,
    t.campaign_id,
    t.test_type,
    t.status,
    v.variant_code,
    v.name as variant_name,
    v.value as variant_value,
    v.sent_count,
    v.open_count,
    v.click_count,
    CASE WHEN v.sent_count > 0 THEN ROUND(v.open_count::DECIMAL / v.sent_count * 100, 2) ELSE 0 END as open_rate,
    CASE WHEN v.open_count > 0 THEN ROUND(v.click_count::DECIMAL / v.open_count * 100, 2) ELSE 0 END as click_rate,
    t.winner_variant_id,
    t.confidence_level
FROM email_ab_tests t
JOIN email_ab_variants v ON t.test_id = v.test_id
ORDER BY t.created_at DESC, v.variant_code;

SELECT 'Email Marketing schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_31_sms_complete.py (E31)
-- ================================================================

-- SMS Campaigns
CREATE TABLE IF NOT EXISTS sms_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    message_type VARCHAR(10) DEFAULT 'sms',
    media_url TEXT,
    from_number VARCHAR(20),
    status VARCHAR(50) DEFAULT 'draft',
    scheduled_for TIMESTAMP,
    sent_at TIMESTAMP,
    total_recipients INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    opt_out_count INTEGER DEFAULT 0,
    total_cost DECIMAL(10,4) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_campaigns_status ON sms_campaigns(status);

-- SMS Sends
CREATE TABLE IF NOT EXISTS sms_sends (
    send_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES sms_campaigns(campaign_id),
    recipient_phone VARCHAR(20) NOT NULL,
    recipient_id UUID,
    variant_id VARCHAR(100),
    message TEXT NOT NULL,
    message_type VARCHAR(10) DEFAULT 'sms',
    status VARCHAR(50) DEFAULT 'pending',
    segments INTEGER DEFAULT 1,
    cost DECIMAL(10,4),
    provider_message_id VARCHAR(255),
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_sends_campaign ON sms_sends(campaign_id);
CREATE INDEX IF NOT EXISTS idx_sms_sends_phone ON sms_sends(recipient_phone);
CREATE INDEX IF NOT EXISTS idx_sms_sends_status ON sms_sends(status);

-- Shortlinks
CREATE TABLE IF NOT EXISTS sms_shortlinks (
    shortlink_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_code VARCHAR(20) UNIQUE NOT NULL,
    original_url TEXT NOT NULL,
    campaign_id UUID,
    send_id UUID,
    click_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shortlinks_code ON sms_shortlinks(short_code);

-- Shortlink Clicks
CREATE TABLE IF NOT EXISTS sms_shortlink_clicks (
    click_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shortlink_id UUID REFERENCES sms_shortlinks(shortlink_id),
    send_id UUID,
    clicked_at TIMESTAMP DEFAULT NOW(),
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_type VARCHAR(50)
);

-- Consent Management (TCPA)
CREATE TABLE IF NOT EXISTS sms_consent (
    consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    consent_type VARCHAR(50) DEFAULT 'express',
    opted_in_at TIMESTAMP,
    opted_out_at TIMESTAMP,
    opt_in_source VARCHAR(255),
    opt_in_keyword VARCHAR(50),
    consent_text TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_consent_phone ON sms_consent(phone_number);
CREATE INDEX IF NOT EXISTS idx_sms_consent_status ON sms_consent(status);

-- Keyword Triggers
CREATE TABLE IF NOT EXISTS sms_keywords (
    keyword_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    keyword VARCHAR(50) NOT NULL,
    candidate_id UUID,
    response_message TEXT NOT NULL,
    action_type VARCHAR(50) DEFAULT 'reply',
    is_active BOOLEAN DEFAULT true,
    trigger_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sms_keywords_unique ON sms_keywords(keyword, candidate_id);

-- Inbound Messages
CREATE TABLE IF NOT EXISTS sms_inbound (
    inbound_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_phone VARCHAR(20) NOT NULL,
    to_phone VARCHAR(20) NOT NULL,
    message TEXT,
    matched_keyword VARCHAR(50),
    auto_replied BOOLEAN DEFAULT false,
    received_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_inbound_from ON sms_inbound(from_phone);

-- A/B Tests (UNLIMITED)
CREATE TABLE IF NOT EXISTS sms_ab_tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES sms_campaigns(campaign_id),
    name VARCHAR(255),
    test_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'running',
    winner_variant_id VARCHAR(100),
    confidence_level DECIMAL(5,4),
    min_sample_size INTEGER DEFAULT 100,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

-- A/B Variants (UNLIMITED per test)
CREATE TABLE IF NOT EXISTS sms_ab_variants (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES sms_ab_tests(test_id),
    variant_code VARCHAR(10) NOT NULL,
    name VARCHAR(255),
    value TEXT NOT NULL,
    allocation_pct DECIMAL(5,2) DEFAULT 50.00,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    conversion_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_ab_variants_test ON sms_ab_variants(test_id);

-- Drip Sequences
CREATE TABLE IF NOT EXISTS sms_drip_sequences (
    sequence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    trigger_event VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    total_enrolled INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Drip Steps
CREATE TABLE IF NOT EXISTS sms_drip_steps (
    step_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_id UUID REFERENCES sms_drip_sequences(sequence_id),
    step_number INTEGER NOT NULL,
    message TEXT NOT NULL,
    delay_minutes INTEGER DEFAULT 0,
    delay_hours INTEGER DEFAULT 0,
    delay_days INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Drip Enrollments
CREATE TABLE IF NOT EXISTS sms_drip_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_id UUID REFERENCES sms_drip_sequences(sequence_id),
    recipient_phone VARCHAR(20) NOT NULL,
    current_step INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'active',
    enrolled_at TIMESTAMP DEFAULT NOW(),
    next_send_at TIMESTAMP
);

-- Cost Tracking
CREATE TABLE IF NOT EXISTS sms_daily_costs (
    date DATE PRIMARY KEY,
    total_sms INTEGER DEFAULT 0,
    total_mms INTEGER DEFAULT 0,
    total_segments INTEGER DEFAULT 0,
    total_cost DECIMAL(10,4) DEFAULT 0
);

-- Performance View
CREATE OR REPLACE VIEW v_sms_campaign_performance AS
SELECT 
    c.campaign_id, c.name, c.status, c.message_type, c.sent_at,
    c.total_recipients, c.sent_count, c.delivered_count, c.failed_count,
    c.click_count, c.reply_count, c.total_cost,
    CASE WHEN c.sent_count > 0 THEN ROUND(c.delivered_count::DECIMAL / c.sent_count * 100, 2) ELSE 0 END as delivery_rate,
    CASE WHEN c.delivered_count > 0 THEN ROUND(c.click_count::DECIMAL / c.delivered_count * 100, 2) ELSE 0 END as click_rate
FROM sms_campaigns c ORDER BY c.created_at DESC;

SELECT 'SMS schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_31_sms_enhanced.py (E31)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 31: OMNICHANNEL MESSAGING SYSTEM - ENHANCED
-- ============================================================================

-- Multi-Channel Campaigns
CREATE TABLE IF NOT EXISTS messaging_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    
    -- Channel configuration
    primary_channel VARCHAR(20) DEFAULT 'sms',
    fallback_channel VARCHAR(20),
    enable_rcs BOOLEAN DEFAULT true,
    enable_whatsapp BOOLEAN DEFAULT false,
    
    -- Content
    message_text TEXT NOT NULL,
    media_url TEXT,
    media_type VARCHAR(50),
    
    -- RCS-specific content
    rcs_content JSONB DEFAULT '{}',
    rcs_suggestions JSONB DEFAULT '[]',
    rcs_carousel JSONB DEFAULT '[]',
    
    -- WhatsApp template
    whatsapp_template_name VARCHAR(255),
    whatsapp_template_params JSONB DEFAULT '[]',
    
    -- Scheduling
    status VARCHAR(50) DEFAULT 'draft',
    scheduled_for TIMESTAMP,
    sent_at TIMESTAMP,
    
    -- Metrics
    total_recipients INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    read_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    conversion_count INTEGER DEFAULT 0,
    opt_out_count INTEGER DEFAULT 0,
    total_cost DECIMAL(12,4) DEFAULT 0,
    
    -- Analytics
    avg_response_time_seconds INTEGER,
    sentiment_positive INTEGER DEFAULT 0,
    sentiment_negative INTEGER DEFAULT 0,
    sentiment_neutral INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_msg_campaigns_status ON messaging_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_msg_campaigns_channel ON messaging_campaigns(primary_channel);

-- Message Sends (all channels)
CREATE TABLE IF NOT EXISTS messaging_sends (
    send_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES messaging_campaigns(campaign_id),
    
    -- Recipient
    recipient_phone VARCHAR(20) NOT NULL,
    recipient_id UUID,
    recipient_name VARCHAR(255),
    
    -- Channel used
    channel_attempted VARCHAR(20) NOT NULL,
    channel_delivered VARCHAR(20),
    fallback_used BOOLEAN DEFAULT false,
    
    -- Content sent
    message_text TEXT,
    media_url TEXT,
    rcs_content_sent JSONB,
    
    -- Tracking
    variant_id UUID,
    shortlink_code VARCHAR(20),
    
    -- Provider
    provider VARCHAR(50),
    provider_message_id VARCHAR(255),
    
    -- Status tracking
    status VARCHAR(50) DEFAULT 'pending',
    queued_at TIMESTAMP,
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    failed_at TIMESTAMP,
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Cost
    segments INTEGER DEFAULT 1,
    cost DECIMAL(10,4),
    
    -- RCS-specific
    rcs_capabilities JSONB DEFAULT '{}',
    rcs_read_receipt BOOLEAN DEFAULT false,
    rcs_typing_indicator_sent BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_msg_sends_campaign ON messaging_sends(campaign_id);
CREATE INDEX IF NOT EXISTS idx_msg_sends_phone ON messaging_sends(recipient_phone);
CREATE INDEX IF NOT EXISTS idx_msg_sends_status ON messaging_sends(status);
CREATE INDEX IF NOT EXISTS idx_msg_sends_channel ON messaging_sends(channel_delivered);

-- RCS Capabilities Cache
CREATE TABLE IF NOT EXISTS rcs_capabilities (
    phone_number VARCHAR(20) PRIMARY KEY,
    rcs_enabled BOOLEAN DEFAULT false,
    capabilities JSONB DEFAULT '{}',
    carrier VARCHAR(100),
    device_model VARCHAR(255),
    last_checked TIMESTAMP DEFAULT NOW(),
    check_count INTEGER DEFAULT 1
);

-- Conversation Threading
CREATE TABLE IF NOT EXISTS messaging_conversations (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) NOT NULL,
    contact_id UUID,
    
    -- Status
    status VARCHAR(50) DEFAULT 'active',
    assigned_to VARCHAR(255),
    
    -- Metrics
    message_count INTEGER DEFAULT 0,
    last_inbound_at TIMESTAMP,
    last_outbound_at TIMESTAMP,
    avg_response_time_seconds INTEGER,
    
    -- AI Classification
    primary_intent VARCHAR(100),
    sentiment_score DECIMAL(4,2),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversations_phone ON messaging_conversations(phone_number);
CREATE INDEX IF NOT EXISTS idx_conversations_status ON messaging_conversations(status);

-- Inbound Messages (all channels)
CREATE TABLE IF NOT EXISTS messaging_inbound (
    inbound_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES messaging_conversations(conversation_id),
    
    -- Source
    from_phone VARCHAR(20) NOT NULL,
    to_phone VARCHAR(20) NOT NULL,
    channel VARCHAR(20) NOT NULL,
    
    -- Content
    message_text TEXT,
    media_urls JSONB DEFAULT '[]',
    
    -- RCS-specific
    rcs_suggestion_response VARCHAR(255),
    rcs_action_response JSONB,
    
    -- Provider
    provider VARCHAR(50),
    provider_message_id VARCHAR(255),
    
    -- AI Analysis
    ai_classified BOOLEAN DEFAULT false,
    detected_intent VARCHAR(100),
    detected_sentiment VARCHAR(50),
    sentiment_score DECIMAL(4,2),
    detected_entities JSONB DEFAULT '[]',
    requires_human BOOLEAN DEFAULT false,
    
    -- Auto-response
    auto_responded BOOLEAN DEFAULT false,
    auto_response_id UUID,
    matched_keyword VARCHAR(50),
    
    -- Timing
    received_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    response_time_seconds INTEGER
);

CREATE INDEX IF NOT EXISTS idx_inbound_from ON messaging_inbound(from_phone);
CREATE INDEX IF NOT EXISTS idx_inbound_conversation ON messaging_inbound(conversation_id);
CREATE INDEX IF NOT EXISTS idx_inbound_intent ON messaging_inbound(detected_intent);

-- RCS Rich Card Templates
CREATE TABLE IF NOT EXISTS rcs_card_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    
    -- Card content
    title VARCHAR(200),
    description TEXT,
    media_url TEXT,
    media_height VARCHAR(20) DEFAULT 'MEDIUM',
    
    -- Suggestions
    suggested_replies JSONB DEFAULT '[]',
    suggested_actions JSONB DEFAULT '[]',
    
    -- For carousels
    is_carousel_card BOOLEAN DEFAULT false,
    carousel_position INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- WhatsApp Templates (pre-approved)
CREATE TABLE IF NOT EXISTS whatsapp_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_name VARCHAR(255) NOT NULL,
    language VARCHAR(10) DEFAULT 'en',
    category VARCHAR(50),
    
    -- Template content
    header_type VARCHAR(20),
    header_text TEXT,
    body_text TEXT NOT NULL,
    footer_text TEXT,
    
    -- Parameters
    parameter_count INTEGER DEFAULT 0,
    parameter_examples JSONB DEFAULT '[]',
    
    -- Buttons
    buttons JSONB DEFAULT '[]',
    
    -- Status
    approval_status VARCHAR(50) DEFAULT 'pending',
    approved_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Shortlinks with enhanced tracking
CREATE TABLE IF NOT EXISTS messaging_shortlinks (
    shortlink_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_code VARCHAR(20) UNIQUE NOT NULL,
    original_url TEXT NOT NULL,
    
    -- Attribution
    campaign_id UUID,
    send_id UUID,
    
    -- Tracking
    click_count INTEGER DEFAULT 0,
    unique_clicks INTEGER DEFAULT 0,
    
    -- Conversion tracking
    conversion_goal VARCHAR(100),
    conversion_count INTEGER DEFAULT 0,
    conversion_value DECIMAL(12,2) DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Click events with full attribution
CREATE TABLE IF NOT EXISTS messaging_click_events (
    click_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shortlink_id UUID REFERENCES messaging_shortlinks(shortlink_id),
    send_id UUID,
    
    -- Attribution
    phone_number VARCHAR(20),
    contact_id UUID,
    
    -- Device info
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_type VARCHAR(50),
    os VARCHAR(50),
    browser VARCHAR(50),
    
    -- Geo (if available)
    city VARCHAR(100),
    region VARCHAR(100),
    country VARCHAR(2),
    
    -- Conversion
    converted BOOLEAN DEFAULT false,
    conversion_value DECIMAL(12,2),
    conversion_at TIMESTAMP,
    
    clicked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clicks_shortlink ON messaging_click_events(shortlink_id);
CREATE INDEX IF NOT EXISTS idx_clicks_phone ON messaging_click_events(phone_number);

-- AI Response Templates
CREATE TABLE IF NOT EXISTS ai_response_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intent VARCHAR(100) NOT NULL,
    
    -- Matching
    trigger_keywords JSONB DEFAULT '[]',
    trigger_sentiment VARCHAR(50),
    
    -- Response
    response_text TEXT NOT NULL,
    include_suggestions JSONB DEFAULT '[]',
    
    -- Workflow
    trigger_workflow VARCHAR(100),
    update_crm_field VARCHAR(100),
    
    priority INTEGER DEFAULT 50,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- A/B Tests (UNLIMITED)
CREATE TABLE IF NOT EXISTS messaging_ab_tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES messaging_campaigns(campaign_id),
    name VARCHAR(255),
    test_type VARCHAR(50) NOT NULL,
    
    -- Configuration
    test_percentage DECIMAL(5,2) DEFAULT 100,
    min_sample_size INTEGER DEFAULT 100,
    confidence_threshold DECIMAL(4,2) DEFAULT 0.95,
    
    -- Status
    status VARCHAR(50) DEFAULT 'running',
    winner_variant_id UUID,
    statistical_significance DECIMAL(6,4),
    
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

-- A/B Variants
CREATE TABLE IF NOT EXISTS messaging_ab_variants (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES messaging_ab_tests(test_id),
    variant_code VARCHAR(10) NOT NULL,
    name VARCHAR(255),
    
    -- Content
    content_type VARCHAR(50),
    content_value TEXT NOT NULL,
    
    -- Allocation
    allocation_pct DECIMAL(5,2) DEFAULT 50.00,
    
    -- Metrics
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    read_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    conversion_count INTEGER DEFAULT 0,
    
    -- Calculated
    delivery_rate DECIMAL(6,4),
    read_rate DECIMAL(6,4),
    click_rate DECIMAL(6,4),
    conversion_rate DECIMAL(6,4),
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Consent Management (TCPA + 10DLC)
CREATE TABLE IF NOT EXISTS messaging_consent (
    consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- Status per channel
    sms_status VARCHAR(50) DEFAULT 'pending',
    mms_status VARCHAR(50) DEFAULT 'pending',
    rcs_status VARCHAR(50) DEFAULT 'pending',
    whatsapp_status VARCHAR(50) DEFAULT 'pending',
    
    -- Consent details
    consent_type VARCHAR(50) DEFAULT 'express',
    opt_in_source VARCHAR(255),
    opt_in_keyword VARCHAR(50),
    opt_in_timestamp TIMESTAMP,
    
    -- Opt-out tracking
    opt_out_timestamp TIMESTAMP,
    opt_out_reason VARCHAR(255),
    
    -- Compliance
    tcpa_compliant BOOLEAN DEFAULT true,
    double_opt_in BOOLEAN DEFAULT false,
    consent_text_shown TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_consent_phone ON messaging_consent(phone_number);

-- Provider Configuration
CREATE TABLE IF NOT EXISTS messaging_providers (
    provider_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_name VARCHAR(50) NOT NULL,
    
    -- Capabilities
    supports_sms BOOLEAN DEFAULT true,
    supports_mms BOOLEAN DEFAULT true,
    supports_rcs BOOLEAN DEFAULT false,
    supports_whatsapp BOOLEAN DEFAULT false,
    
    -- Priority
    priority INTEGER DEFAULT 50,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    health_status VARCHAR(50) DEFAULT 'healthy',
    last_health_check TIMESTAMP,
    
    -- Costs
    cost_per_sms DECIMAL(8,4),
    cost_per_mms DECIMAL(8,4),
    cost_per_rcs DECIMAL(8,4),
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Real-time Analytics View
CREATE OR REPLACE VIEW v_campaign_realtime_analytics AS
SELECT 
    c.campaign_id,
    c.name,
    c.primary_channel,
    c.status,
    c.total_recipients,
    c.sent_count,
    c.delivered_count,
    c.read_count,
    c.click_count,
    c.reply_count,
    c.conversion_count,
    c.total_cost,
    ROUND(c.delivered_count::DECIMAL / NULLIF(c.sent_count, 0) * 100, 2) as delivery_rate,
    ROUND(c.read_count::DECIMAL / NULLIF(c.delivered_count, 0) * 100, 2) as read_rate,
    ROUND(c.click_count::DECIMAL / NULLIF(c.delivered_count, 0) * 100, 2) as click_rate,
    ROUND(c.reply_count::DECIMAL / NULLIF(c.delivered_count, 0) * 100, 2) as reply_rate,
    ROUND(c.conversion_count::DECIMAL / NULLIF(c.click_count, 0) * 100, 2) as conversion_rate,
    c.sentiment_positive,
    c.sentiment_negative,
    c.sentiment_neutral
FROM messaging_campaigns c
ORDER BY c.created_at DESC;

-- Channel Performance View
CREATE OR REPLACE VIEW v_channel_performance AS
SELECT 
    channel_delivered as channel,
    COUNT(*) as total_sent,
    COUNT(*) FILTER (WHERE status = 'delivered') as delivered,
    COUNT(*) FILTER (WHERE status = 'read') as read,
    COUNT(*) FILTER (WHERE status = 'failed') as failed,
    ROUND(AVG(cost), 4) as avg_cost,
    SUM(cost) as total_cost
FROM messaging_sends
WHERE channel_delivered IS NOT NULL
GROUP BY channel_delivered;

-- Conversation Analytics View
CREATE OR REPLACE VIEW v_conversation_analytics AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_conversations,
    COUNT(*) FILTER (WHERE status = 'active') as active,
    AVG(message_count) as avg_messages,
    AVG(avg_response_time_seconds) as avg_response_time
FROM messaging_conversations
GROUP BY DATE(created_at)
ORDER BY date DESC;

SELECT 'Enhanced Omnichannel Messaging schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_32_phone_banking_complete.py (E32)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 32: PHONE BANKING SYSTEM
-- ============================================================================

-- Phone Campaigns
CREATE TABLE IF NOT EXISTS phone_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    campaign_type VARCHAR(50),  -- gotv, fundraising, persuasion, survey, id
    dialer_mode VARCHAR(50) DEFAULT 'preview',
    script_id UUID,
    caller_id VARCHAR(20),
    status VARCHAR(50) DEFAULT 'draft',
    scheduled_start TIMESTAMP,
    scheduled_end TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    total_contacts INTEGER DEFAULT 0,
    contacts_called INTEGER DEFAULT 0,
    contacts_reached INTEGER DEFAULT 0,
    total_calls INTEGER DEFAULT 0,
    answered_calls INTEGER DEFAULT 0,
    voicemails INTEGER DEFAULT 0,
    avg_call_duration INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phone_campaigns_status ON phone_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_phone_campaigns_candidate ON phone_campaigns(candidate_id);

-- Call Scripts
CREATE TABLE IF NOT EXISTS call_scripts (
    script_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    script_type VARCHAR(50),  -- gotv, fundraising, persuasion, survey
    opening_text TEXT,
    main_body TEXT,
    closing_text TEXT,
    objection_handlers JSONB DEFAULT '{}',
    branch_logic JSONB DEFAULT '[]',
    talking_points JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scripts_type ON call_scripts(script_type);

-- Call Lists (contacts to call)
CREATE TABLE IF NOT EXISTS call_lists (
    list_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES phone_campaigns(campaign_id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    total_contacts INTEGER DEFAULT 0,
    remaining_contacts INTEGER DEFAULT 0,
    list_criteria JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_call_lists_campaign ON call_lists(campaign_id);

-- Call Queue (individual contacts to call)
CREATE TABLE IF NOT EXISTS call_queue (
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES phone_campaigns(campaign_id),
    list_id UUID REFERENCES call_lists(list_id),
    contact_id UUID NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    priority INTEGER DEFAULT 5,
    attempt_count INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    status VARCHAR(50) DEFAULT 'pending',
    assigned_to UUID,
    assigned_at TIMESTAMP,
    last_attempt_at TIMESTAMP,
    next_attempt_after TIMESTAMP,
    contact_data JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_queue_campaign ON call_queue(campaign_id);
CREATE INDEX IF NOT EXISTS idx_queue_status ON call_queue(status);
CREATE INDEX IF NOT EXISTS idx_queue_phone ON call_queue(phone_number);
CREATE INDEX IF NOT EXISTS idx_queue_assigned ON call_queue(assigned_to);
CREATE INDEX IF NOT EXISTS idx_queue_priority ON call_queue(priority DESC);

-- Call Records (individual calls made)
CREATE TABLE IF NOT EXISTS call_records (
    call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES phone_campaigns(campaign_id),
    queue_id UUID REFERENCES call_queue(queue_id),
    contact_id UUID,
    caller_id UUID,
    caller_name VARCHAR(255),
    phone_number VARCHAR(20),
    outbound_number VARCHAR(20),
    disposition VARCHAR(50),
    outcome VARCHAR(50),
    duration_seconds INTEGER DEFAULT 0,
    talk_time_seconds INTEGER DEFAULT 0,
    wait_time_seconds INTEGER DEFAULT 0,
    recording_url TEXT,
    notes TEXT,
    survey_responses JSONB DEFAULT '{}',
    donation_pledged DECIMAL(10,2),
    callback_requested BOOLEAN DEFAULT false,
    callback_time TIMESTAMP,
    dnc_requested BOOLEAN DEFAULT false,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calls_campaign ON call_records(campaign_id);
CREATE INDEX IF NOT EXISTS idx_calls_caller ON call_records(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_disposition ON call_records(disposition);
CREATE INDEX IF NOT EXISTS idx_calls_outcome ON call_records(outcome);
CREATE INDEX IF NOT EXISTS idx_calls_date ON call_records(created_at);

-- Callers (volunteers/staff making calls)
CREATE TABLE IF NOT EXISTS phone_callers (
    caller_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    caller_type VARCHAR(50) DEFAULT 'volunteer',
    status VARCHAR(50) DEFAULT 'available',
    current_campaign_id UUID,
    current_call_id UUID,
    skills JSONB DEFAULT '[]',
    total_calls INTEGER DEFAULT 0,
    total_talk_time INTEGER DEFAULT 0,
    avg_call_duration INTEGER DEFAULT 0,
    answer_rate DECIMAL(5,2) DEFAULT 0,
    conversion_rate DECIMAL(5,2) DEFAULT 0,
    shift_start TIMESTAMP,
    shift_end TIMESTAMP,
    last_active_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_callers_status ON phone_callers(status);
CREATE INDEX IF NOT EXISTS idx_callers_campaign ON phone_callers(current_campaign_id);

-- Do Not Call List
CREATE TABLE IF NOT EXISTS dnc_list (
    dnc_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    reason VARCHAR(100),
    source VARCHAR(100),
    added_by VARCHAR(255),
    added_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dnc_phone ON dnc_list(phone_number);

-- Call Sessions (caller work sessions)
CREATE TABLE IF NOT EXISTS call_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caller_id UUID REFERENCES phone_callers(caller_id),
    campaign_id UUID REFERENCES phone_campaigns(campaign_id),
    started_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    calls_made INTEGER DEFAULT 0,
    contacts_reached INTEGER DEFAULT 0,
    total_talk_time INTEGER DEFAULT 0,
    break_time INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_sessions_caller ON call_sessions(caller_id);
CREATE INDEX IF NOT EXISTS idx_sessions_campaign ON call_sessions(campaign_id);

-- Views
CREATE OR REPLACE VIEW v_campaign_stats AS
SELECT 
    pc.campaign_id,
    pc.name,
    pc.status,
    pc.dialer_mode,
    pc.total_contacts,
    pc.contacts_called,
    pc.contacts_reached,
    CASE WHEN pc.contacts_called > 0 
         THEN pc.contacts_reached::DECIMAL / pc.contacts_called * 100 
         ELSE 0 END as reach_rate,
    COUNT(DISTINCT cr.caller_id) as active_callers,
    COUNT(cr.call_id) as total_calls_today
FROM phone_campaigns pc
LEFT JOIN call_records cr ON pc.campaign_id = cr.campaign_id 
    AND cr.created_at > CURRENT_DATE
GROUP BY pc.campaign_id, pc.name, pc.status, pc.dialer_mode,
         pc.total_contacts, pc.contacts_called, pc.contacts_reached;

CREATE OR REPLACE VIEW v_caller_performance AS
SELECT 
    c.caller_id,
    c.name,
    c.total_calls,
    c.avg_call_duration,
    c.answer_rate,
    c.conversion_rate,
    COUNT(cr.call_id) FILTER (WHERE cr.created_at > CURRENT_DATE) as calls_today,
    SUM(cr.duration_seconds) FILTER (WHERE cr.created_at > CURRENT_DATE) as talk_time_today
FROM phone_callers c
LEFT JOIN call_records cr ON c.caller_id = cr.caller_id
GROUP BY c.caller_id, c.name, c.total_calls, c.avg_call_duration,
         c.answer_rate, c.conversion_rate;

SELECT 'Phone Banking schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_33_direct_mail_complete.py (E33)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 33: DIRECT MAIL SYSTEM
-- ============================================================================

-- Mail Campaigns
CREATE TABLE IF NOT EXISTS mail_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Campaign Info
    name VARCHAR(255) NOT NULL,
    description TEXT,
    campaign_type VARCHAR(50),  -- fundraising, voter_contact, gotv, announcement
    
    -- Piece Config
    piece_type VARCHAR(50) NOT NULL,
    postage_class VARCHAR(50) DEFAULT 'standard',
    
    -- Template
    template_id UUID,
    template_name VARCHAR(255),
    template_front_url TEXT,
    template_back_url TEXT,
    
    -- Variable fields used
    variable_fields JSONB DEFAULT '[]',
    
    -- Targeting
    audience_query TEXT,
    target_count INTEGER DEFAULT 0,
    
    -- Schedule
    scheduled_mail_date DATE,
    actual_mail_date DATE,
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    
    -- Counts
    total_pieces INTEGER DEFAULT 0,
    validated_count INTEGER DEFAULT 0,
    invalid_count INTEGER DEFAULT 0,
    submitted_count INTEGER DEFAULT 0,
    in_transit_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    returned_count INTEGER DEFAULT 0,
    
    -- Response tracking
    qr_scans INTEGER DEFAULT 0,
    responses INTEGER DEFAULT 0,
    response_donations INTEGER DEFAULT 0,
    response_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Cost
    estimated_cost DECIMAL(12,2),
    actual_cost DECIMAL(12,2),
    print_cost DECIMAL(12,2),
    postage_cost DECIMAL(12,2),
    
    -- Vendor
    vendor VARCHAR(50) DEFAULT 'manual',
    vendor_job_id VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mail_campaigns_candidate ON mail_campaigns(candidate_id);
CREATE INDEX IF NOT EXISTS idx_mail_campaigns_status ON mail_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_mail_campaigns_mail_date ON mail_campaigns(scheduled_mail_date);

-- Mail Pieces (individual recipients)
CREATE TABLE IF NOT EXISTS mail_pieces (
    piece_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES mail_campaigns(campaign_id),
    recipient_id UUID NOT NULL,
    
    -- Recipient Info
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    zip_plus_4 VARCHAR(4),
    
    -- Address Validation
    address_validated BOOLEAN DEFAULT false,
    address_standardized BOOLEAN DEFAULT false,
    deliverability VARCHAR(50),  -- deliverable, undeliverable, unknown
    dpv_code VARCHAR(10),  -- Delivery Point Validation
    ncoa_action VARCHAR(50),  -- move, forwardable, etc.
    
    -- Personalization Variables
    greeting VARCHAR(255),
    personalized_paragraph TEXT,
    ask_amount VARCHAR(50),
    custom_message TEXT,
    custom_image_url TEXT,
    donor_grade VARCHAR(10),
    donor_history_summary TEXT,
    
    -- QR Code
    qr_code_id VARCHAR(50),
    qr_code_url TEXT,
    qr_short_url VARCHAR(100),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    
    -- Tracking
    imb_code VARCHAR(50),  -- Intelligent Mail Barcode
    tracking_events JSONB DEFAULT '[]',
    
    -- Response
    qr_scanned BOOLEAN DEFAULT false,
    qr_scanned_at TIMESTAMP,
    responded BOOLEAN DEFAULT false,
    response_type VARCHAR(50),
    response_amount DECIMAL(12,2),
    response_date DATE,
    
    -- Cost
    print_cost DECIMAL(8,4),
    postage_cost DECIMAL(8,4),
    total_cost DECIMAL(8,4),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mail_pieces_campaign ON mail_pieces(campaign_id);
CREATE INDEX IF NOT EXISTS idx_mail_pieces_recipient ON mail_pieces(recipient_id);
CREATE INDEX IF NOT EXISTS idx_mail_pieces_status ON mail_pieces(status);
CREATE INDEX IF NOT EXISTS idx_mail_pieces_qr ON mail_pieces(qr_code_id);
CREATE INDEX IF NOT EXISTS idx_mail_pieces_zip ON mail_pieces(zip_code);

-- Mail Templates
CREATE TABLE IF NOT EXISTS mail_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    name VARCHAR(255) NOT NULL,
    description TEXT,
    piece_type VARCHAR(50) NOT NULL,
    
    -- Design files
    front_design_url TEXT,
    back_design_url TEXT,
    pdf_template_url TEXT,
    
    -- Variable field definitions
    variable_fields JSONB DEFAULT '[]',
    
    -- Static elements
    static_elements JSONB DEFAULT '{}',
    
    -- Specs
    width_inches DECIMAL(6,2),
    height_inches DECIMAL(6,2),
    bleed_inches DECIMAL(4,2) DEFAULT 0.125,
    color_mode VARCHAR(20) DEFAULT 'CMYK',
    paper_stock VARCHAR(100),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mail_templates_candidate ON mail_templates(candidate_id);

-- QR Code Tracking
CREATE TABLE IF NOT EXISTS mail_qr_codes (
    qr_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    piece_id UUID REFERENCES mail_pieces(piece_id),
    campaign_id UUID REFERENCES mail_campaigns(campaign_id),
    recipient_id UUID,
    
    -- QR Code
    short_code VARCHAR(20) UNIQUE NOT NULL,
    full_url TEXT NOT NULL,
    destination_url TEXT NOT NULL,
    
    -- Scans
    scan_count INTEGER DEFAULT 0,
    first_scan_at TIMESTAMP,
    last_scan_at TIMESTAMP,
    
    -- Conversion
    converted BOOLEAN DEFAULT false,
    conversion_type VARCHAR(50),
    conversion_value DECIMAL(12,2),
    conversion_date DATE,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qr_codes_short ON mail_qr_codes(short_code);
CREATE INDEX IF NOT EXISTS idx_qr_codes_campaign ON mail_qr_codes(campaign_id);

-- QR Scan Events
CREATE TABLE IF NOT EXISTS mail_qr_scans (
    scan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qr_id UUID REFERENCES mail_qr_codes(qr_id),
    
    -- Device info
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_type VARCHAR(50),
    
    -- Location (from IP)
    geo_city VARCHAR(100),
    geo_state VARCHAR(50),
    geo_country VARCHAR(50),
    
    scanned_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qr_scans_qr ON mail_qr_scans(qr_id);

-- Vendor Jobs
CREATE TABLE IF NOT EXISTS mail_vendor_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES mail_campaigns(campaign_id),
    
    vendor VARCHAR(50) NOT NULL,
    vendor_job_id VARCHAR(255),
    
    -- Job details
    piece_count INTEGER,
    data_file_url TEXT,
    template_file_url TEXT,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    submitted_at TIMESTAMP,
    accepted_at TIMESTAMP,
    production_started_at TIMESTAMP,
    production_completed_at TIMESTAMP,
    mailed_at TIMESTAMP,
    
    -- Cost
    quoted_cost DECIMAL(12,2),
    actual_cost DECIMAL(12,2),
    
    -- Response
    vendor_response JSONB,
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_jobs_campaign ON mail_vendor_jobs(campaign_id);
CREATE INDEX IF NOT EXISTS idx_vendor_jobs_vendor ON mail_vendor_jobs(vendor);

-- Address Validation Cache
CREATE TABLE IF NOT EXISTS address_validation_cache (
    cache_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Input address (hash for lookup)
    address_hash VARCHAR(64) UNIQUE NOT NULL,
    input_address JSONB NOT NULL,
    
    -- Validated address
    validated_address JSONB,
    
    -- Validation results
    is_valid BOOLEAN,
    deliverability VARCHAR(50),
    dpv_code VARCHAR(10),
    dpv_footnotes VARCHAR(50),
    
    -- NCOA (National Change of Address)
    ncoa_checked BOOLEAN DEFAULT false,
    ncoa_match_type VARCHAR(50),
    ncoa_new_address JSONB,
    
    validated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '90 days'
);

CREATE INDEX IF NOT EXISTS idx_address_cache_hash ON address_validation_cache(address_hash);

-- Views
CREATE OR REPLACE VIEW v_mail_campaign_summary AS
SELECT 
    mc.campaign_id,
    mc.name,
    mc.piece_type,
    mc.postage_class,
    mc.status,
    mc.scheduled_mail_date,
    mc.total_pieces,
    mc.validated_count,
    mc.delivered_count,
    mc.returned_count,
    mc.qr_scans,
    mc.responses,
    mc.response_amount,
    mc.estimated_cost,
    mc.actual_cost,
    CASE WHEN mc.total_pieces > 0 
         THEN mc.delivered_count::DECIMAL / mc.total_pieces 
         ELSE 0 END as delivery_rate,
    CASE WHEN mc.delivered_count > 0 
         THEN mc.responses::DECIMAL / mc.delivered_count 
         ELSE 0 END as response_rate,
    CASE WHEN mc.actual_cost > 0 
         THEN (mc.response_amount - mc.actual_cost) / mc.actual_cost 
         ELSE 0 END as roi
FROM mail_campaigns mc
ORDER BY mc.created_at DESC;

CREATE OR REPLACE VIEW v_mail_piece_status AS
SELECT 
    campaign_id,
    status,
    COUNT(*) as piece_count,
    SUM(total_cost) as total_cost
FROM mail_pieces
GROUP BY campaign_id, status
ORDER BY campaign_id, status;

SELECT 'Direct Mail schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_34_events_complete.py (E34)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 34: IN-PERSON EVENTS
-- ============================================================================

-- Events
CREATE TABLE IF NOT EXISTS events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'draft',
    venue_id UUID,
    venue_name VARCHAR(255),
    venue_address TEXT,
    venue_city VARCHAR(100),
    venue_state VARCHAR(2),
    venue_zip VARCHAR(10),
    venue_capacity INTEGER,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    doors_open TIMESTAMP,
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    is_public BOOLEAN DEFAULT true,
    is_virtual BOOLEAN DEFAULT false,
    virtual_url TEXT,
    registration_required BOOLEAN DEFAULT true,
    registration_url TEXT,
    max_attendees INTEGER,
    current_rsvps INTEGER DEFAULT 0,
    checked_in_count INTEGER DEFAULT 0,
    ticket_price DECIMAL(10,2) DEFAULT 0,
    fundraising_goal DECIMAL(12,2),
    amount_raised DECIMAL(12,2) DEFAULT 0,
    host_id UUID,
    host_name VARCHAR(255),
    cohost_ids JSONB DEFAULT '[]',
    tags JSONB DEFAULT '[]',
    image_url TEXT,
    created_by VARCHAR(255),
    published_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    cancel_reason TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_candidate ON events(candidate_id);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_start ON events(start_time);
CREATE INDEX IF NOT EXISTS idx_events_city ON events(venue_city);

-- Event Series (recurring events)
CREATE TABLE IF NOT EXISTS event_series (
    series_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(50),
    recurrence_rule VARCHAR(100),
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Event-Series Link
CREATE TABLE IF NOT EXISTS event_series_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    series_id UUID REFERENCES event_series(series_id),
    event_id UUID REFERENCES events(event_id),
    sequence_number INTEGER
);

-- RSVPs
CREATE TABLE IF NOT EXISTS event_rsvps (
    rsvp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(event_id),
    contact_id UUID,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    ticket_type VARCHAR(50) DEFAULT 'general',
    ticket_quantity INTEGER DEFAULT 1,
    ticket_price DECIMAL(10,2) DEFAULT 0,
    amount_paid DECIMAL(10,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'invited',
    source VARCHAR(100),
    invited_at TIMESTAMP,
    responded_at TIMESTAMP,
    confirmed_at TIMESTAMP,
    checked_in_at TIMESTAMP,
    checked_in_by VARCHAR(255),
    guest_names JSONB DEFAULT '[]',
    dietary_restrictions TEXT,
    special_requests TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rsvps_event ON event_rsvps(event_id);
CREATE INDEX IF NOT EXISTS idx_rsvps_contact ON event_rsvps(contact_id);
CREATE INDEX IF NOT EXISTS idx_rsvps_status ON event_rsvps(status);
CREATE INDEX IF NOT EXISTS idx_rsvps_email ON event_rsvps(email);

-- Venues
CREATE TABLE IF NOT EXISTS venues (
    venue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    capacity INTEGER,
    venue_type VARCHAR(50),
    contact_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    cost_per_hour DECIMAL(10,2),
    amenities JSONB DEFAULT '[]',
    parking_info TEXT,
    accessibility_info TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_venues_city ON venues(city);

-- Event Volunteers
CREATE TABLE IF NOT EXISTS event_volunteers (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(event_id),
    volunteer_id UUID,
    volunteer_name VARCHAR(255),
    role VARCHAR(100),
    shift_start TIMESTAMP,
    shift_end TIMESTAMP,
    status VARCHAR(50) DEFAULT 'assigned',
    checked_in_at TIMESTAMP,
    checked_out_at TIMESTAMP,
    hours_worked DECIMAL(5,2),
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vol_event ON event_volunteers(event_id);
CREATE INDEX IF NOT EXISTS idx_vol_volunteer ON event_volunteers(volunteer_id);

-- Event Communications
CREATE TABLE IF NOT EXISTS event_communications (
    comm_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(event_id),
    comm_type VARCHAR(50),
    subject VARCHAR(500),
    body TEXT,
    recipient_filter JSONB DEFAULT '{}',
    sent_at TIMESTAMP,
    sent_count INTEGER DEFAULT 0,
    open_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comm_event ON event_communications(event_id);

-- Event Donations
CREATE TABLE IF NOT EXISTS event_donations (
    donation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(event_id),
    rsvp_id UUID REFERENCES event_rsvps(rsvp_id),
    contact_id UUID,
    amount DECIMAL(12,2) NOT NULL,
    payment_method VARCHAR(50),
    payment_reference VARCHAR(100),
    is_pledge BOOLEAN DEFAULT false,
    pledge_fulfilled BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donations_event ON event_donations(event_id);

-- Views
CREATE OR REPLACE VIEW v_event_summary AS
SELECT 
    e.event_id,
    e.name,
    e.event_type,
    e.status,
    e.start_time,
    e.venue_name,
    e.venue_city,
    e.max_attendees,
    e.current_rsvps,
    e.checked_in_count,
    e.fundraising_goal,
    e.amount_raised,
    COUNT(r.rsvp_id) FILTER (WHERE r.status = 'confirmed') as confirmed_count,
    COUNT(r.rsvp_id) FILTER (WHERE r.status = 'checked_in') as actual_attendance
FROM events e
LEFT JOIN event_rsvps r ON e.event_id = r.event_id
GROUP BY e.event_id;

CREATE OR REPLACE VIEW v_upcoming_events AS
SELECT 
    e.event_id,
    e.name,
    e.event_type,
    e.start_time,
    e.venue_name,
    e.venue_city,
    e.current_rsvps,
    e.max_attendees,
    e.start_time - NOW() as time_until
FROM events e
WHERE e.status = 'published'
AND e.start_time > NOW()
ORDER BY e.start_time;

CREATE OR REPLACE VIEW v_event_fundraising AS
SELECT 
    e.event_id,
    e.name,
    e.event_type,
    e.start_time,
    e.fundraising_goal,
    COALESCE(SUM(d.amount), 0) as total_raised,
    COUNT(d.donation_id) as donation_count,
    CASE WHEN e.fundraising_goal > 0 
         THEN (COALESCE(SUM(d.amount), 0) / e.fundraising_goal * 100)::INTEGER
         ELSE 0 END as goal_pct
FROM events e
LEFT JOIN event_donations d ON e.event_id = d.event_id
WHERE e.event_type = 'fundraiser'
GROUP BY e.event_id;

SELECT 'Events schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_35_auto_response_enhancement.py (E35)
-- ================================================================

-- ============================================================================
-- AUTO-RESPONSE & THANK YOU SYSTEM
-- ============================================================================

-- Auto-Response Templates
CREATE TABLE IF NOT EXISTS auto_response_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(255) NOT NULL,
    candidate_id UUID,
    
    -- Trigger
    trigger_type VARCHAR(100) NOT NULL,
    trigger_intent VARCHAR(100),
    
    -- Timing
    delay_seconds INTEGER DEFAULT 60,
    send_immediately BOOLEAN DEFAULT false,
    
    -- Response channel
    response_channel VARCHAR(50) DEFAULT 'sms',
    
    -- Content
    message_template TEXT NOT NULL,
    subject_template VARCHAR(500),
    
    -- Personalization available:
    -- {{first_name}}, {{last_name}}, {{full_name}}
    -- {{donation_amount}}, {{event_name}}, {{event_date}}
    -- {{candidate_name}}, {{candidate_first_name}}
    -- {{callback_time}}, {{volunteer_role}}
    
    -- Signature
    include_signature BOOLEAN DEFAULT true,
    signature_name VARCHAR(255),
    signature_title VARCHAR(255),
    
    -- Media
    include_image BOOLEAN DEFAULT false,
    image_url TEXT,
    
    -- A/B Testing
    ab_test_id UUID,
    variant_code VARCHAR(10),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    priority INTEGER DEFAULT 50,
    
    -- Stats
    times_sent INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auto_templates_trigger ON auto_response_templates(trigger_type);
CREATE INDEX IF NOT EXISTS idx_auto_templates_candidate ON auto_response_templates(candidate_id);

-- Scheduled Auto-Responses (queued for sending)
CREATE TABLE IF NOT EXISTS auto_response_queue (
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Template
    template_id UUID REFERENCES auto_response_templates(template_id),
    
    -- Recipient
    recipient_phone VARCHAR(20),
    recipient_email VARCHAR(255),
    recipient_name VARCHAR(255),
    contact_id UUID,
    
    -- Personalization data
    personalization_data JSONB DEFAULT '{}',
    
    -- Rendered content
    rendered_message TEXT,
    rendered_subject VARCHAR(500),
    
    -- Source
    source_type VARCHAR(50),
    source_id UUID,
    voicemail_id UUID,
    donation_id UUID,
    rsvp_id UUID,
    
    -- Timing
    scheduled_for TIMESTAMP NOT NULL,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    
    -- Tracking
    provider_message_id VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auto_queue_scheduled ON auto_response_queue(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_auto_queue_status ON auto_response_queue(status);

-- Auto-Response Delivery Log
CREATE TABLE IF NOT EXISTS auto_response_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    queue_id UUID REFERENCES auto_response_queue(queue_id),
    template_id UUID,
    
    -- Recipient
    recipient_phone VARCHAR(20),
    recipient_email VARCHAR(255),
    contact_id UUID,
    
    -- Content sent
    channel VARCHAR(50),
    message_sent TEXT,
    
    -- Trigger info
    trigger_type VARCHAR(100),
    trigger_source_id UUID,
    
    -- Delivery
    status VARCHAR(50),
    delivered_at TIMESTAMP,
    
    -- Response (if any)
    recipient_replied BOOLEAN DEFAULT false,
    reply_message TEXT,
    reply_at TIMESTAMP,
    
    sent_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auto_log_trigger ON auto_response_log(trigger_type);

-- Default Templates (seeded on deployment)
INSERT INTO auto_response_templates (name, trigger_type, delay_seconds, message_template, signature_name)
VALUES 
-- Voicemail Thank You (60 second delay)
('Voicemail Thank You', 'voicemail', 60, 
'Hi {{first_name}}, thank you so much for your message! I personally review every voicemail and truly appreciate you taking the time to reach out. I''ll get back to you as soon as possible.

God bless,
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- Voicemail from VIP/Major Donor (immediate)
('VIP Voicemail Response', 'voicemail_vip', 0,
'{{first_name}}, thank you for calling! Your support means the world to me. I saw your message come in and wanted you to know I''ll be calling you back personally very soon.

With gratitude,
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- Donation Thank You (immediate)
('Donation Thank You', 'donation', 0,
'{{first_name}}, WOW! Thank you so much for your generous ${{donation_amount}} contribution! Patriots like you make this campaign possible. Your support gives me the strength to keep fighting for our community.

With deep gratitude,
{{candidate_first_name}}

P.S. - Your donation receipt has been emailed to you.', 'Sheriff Jim Davis'),

-- Major Donation Thank You ($500+)
('Major Donation Thank You', 'donation_major', 0,
'{{first_name}}, I am truly humbled by your incredible ${{donation_amount}} investment in our campaign. I would love to personally thank you - expect a call from me in the next day or two.

Your belief in our mission to keep our community safe means everything. Thank you for standing with me.

With sincere gratitude,
{{candidate_name}}', 'Sheriff Jim Davis'),

-- Recurring Donation Thank You
('Recurring Donation Thank You', 'donation_recurring', 0,
'{{first_name}}, thank you for becoming a sustaining supporter with your monthly ${{donation_amount}} contribution! Monthly donors are the backbone of our campaign, providing the steady support we need to win.

Welcome to the team!
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- RSVP Confirmation
('RSVP Confirmation', 'rsvp', 0,
'Great news, {{first_name}}! You''re confirmed for {{event_name}} on {{event_date}}! 

I can''t wait to meet you in person. Details and directions will be sent closer to the event.

See you there!
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- Callback Request Acknowledgment
('Callback Acknowledgment', 'callback_request', 0,
'Hi {{first_name}}, we received your request for a callback. A member of our team will call you back within 24 hours. If you need immediate assistance, please call us at {{campaign_phone}}.

Thank you for your patience!
Team {{candidate_last_name}}', 'Team Davis'),

-- Volunteer Welcome
('Volunteer Welcome', 'volunteer', 0,
'{{first_name}}, THANK YOU for volunteering! Patriots like you are the heart of our campaign. 

Our volunteer coordinator will reach out within 48 hours to discuss how you can make the biggest impact.

Together, we WILL win!
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- General SMS Response (60 second delay)
('General SMS Thank You', 'sms_general', 60,
'Hi {{first_name}}, thank you for reaching out! I appreciate every message from supporters like you. How can we help you today?

Reply DONATE, RSVP, VOLUNTEER, or CALL for more options.', 'Team Davis'),

-- After Hours Voicemail
('After Hours Response', 'voicemail_after_hours', 0,
'Hi {{first_name}}, thank you for your message! Our office is currently closed, but I wanted you to know your call is important to me. We''ll follow up with you during business hours.

Thank you for your support!
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- Question/Info Request
('Info Request Response', 'info_request', 30,
'Hi {{first_name}}, thank you for your interest! Here are some ways to learn more about our campaign:

🌐 Website: {{website_url}}
📧 Email: {{campaign_email}}
📞 Call: {{campaign_phone}}

What specific information can we help you with?', 'Team Davis')

ON CONFLICT DO NOTHING;

-- View for monitoring auto-responses
CREATE OR REPLACE VIEW v_auto_response_stats AS
SELECT 
    t.template_id,
    t.name,
    t.trigger_type,
    t.delay_seconds,
    t.times_sent,
    COUNT(l.log_id) as actual_sent,
    COUNT(l.log_id) FILTER (WHERE l.recipient_replied = true) as replies_received,
    ROUND(COUNT(l.log_id) FILTER (WHERE l.recipient_replied = true)::DECIMAL / 
          NULLIF(COUNT(l.log_id), 0) * 100, 2) as reply_rate
FROM auto_response_templates t
LEFT JOIN auto_response_log l ON t.template_id = l.template_id
GROUP BY t.template_id, t.name, t.trigger_type, t.delay_seconds, t.times_sent;


-- ================================================================
-- FROM: ecosystem_35_interactive_comm_hub_complete.py (E35)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 35: INTERACTIVE COMMUNICATION HUB
-- ============================================================================

-- AI Voice Agent Configuration (Retell AI Clone)
CREATE TABLE IF NOT EXISTS ai_voice_agents (
    agent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(255) NOT NULL,
    candidate_id UUID,
    
    -- Phone
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    
    -- Voice (ElevenLabs)
    voice_provider VARCHAR(50) DEFAULT 'elevenlabs',
    voice_id VARCHAR(100),
    voice_name VARCHAR(100),
    voice_style VARCHAR(50) DEFAULT 'professional',
    speaking_rate DECIMAL(4,2) DEFAULT 1.0,
    
    -- AI Model
    llm_provider VARCHAR(50) DEFAULT 'anthropic',
    llm_model VARCHAR(100) DEFAULT 'claude-3-sonnet',
    system_prompt TEXT,
    
    -- Greeting Scripts
    greeting_script TEXT NOT NULL,
    after_hours_greeting TEXT,
    holiday_greeting TEXT,
    
    -- IVR Menu
    ivr_enabled BOOLEAN DEFAULT true,
    ivr_prompt TEXT,
    ivr_options JSONB DEFAULT '{
        "1": {"label": "Leave a message", "action": "voicemail"},
        "2": {"label": "RSVP to event", "action": "rsvp"},
        "3": {"label": "Make a donation", "action": "donate"},
        "4": {"label": "Volunteer", "action": "volunteer"},
        "5": {"label": "Speak with someone", "action": "transfer"},
        "0": {"label": "Repeat options", "action": "repeat"}
    }',
    
    -- Voicemail
    voicemail_enabled BOOLEAN DEFAULT true,
    voicemail_prompt TEXT DEFAULT 'Please leave your message after the tone. Press pound when finished.',
    max_voicemail_seconds INTEGER DEFAULT 120,
    voicemail_transcription BOOLEAN DEFAULT true,
    
    -- Business Hours
    business_hours JSONB DEFAULT '{
        "monday": {"start": "09:00", "end": "17:00"},
        "tuesday": {"start": "09:00", "end": "17:00"},
        "wednesday": {"start": "09:00", "end": "17:00"},
        "thursday": {"start": "09:00", "end": "17:00"},
        "friday": {"start": "09:00", "end": "17:00"}
    }',
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    
    -- Transfer
    transfer_phone VARCHAR(20),
    transfer_announce BOOLEAN DEFAULT true,
    max_hold_seconds INTEGER DEFAULT 60,
    
    -- Analytics
    total_calls INTEGER DEFAULT 0,
    total_voicemails INTEGER DEFAULT 0,
    avg_call_duration_seconds INTEGER,
    avg_sentiment_score DECIMAL(4,2),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_voice_agents_phone ON ai_voice_agents(phone_number);
CREATE INDEX IF NOT EXISTS idx_voice_agents_candidate ON ai_voice_agents(candidate_id);

-- SMS Interactive Menu Configuration
CREATE TABLE IF NOT EXISTS sms_interactive_menus (
    menu_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Campaign
    name VARCHAR(255) NOT NULL,
    candidate_id UUID,
    sms_campaign_id UUID,
    
    -- Phone
    phone_number VARCHAR(20) NOT NULL,
    
    -- Menu prompt
    menu_prompt TEXT NOT NULL,
    
    -- Options (Press 1, 2, 3...)
    options JSONB DEFAULT '{
        "1": {
            "label": "Get more info",
            "action": "send_info",
            "response": "Thanks! Here''s more info: {{info_link}}"
        },
        "2": {
            "label": "RSVP to event",
            "action": "rsvp",
            "response": "Great! Reply YES to confirm your RSVP for {{event_name}}"
        },
        "3": {
            "label": "Make a donation",
            "action": "donate",
            "response": "Thank you! Donate securely here: {{donation_link}}"
        },
        "4": {
            "label": "Request callback",
            "action": "callback",
            "response": "We''ll call you back soon! What''s the best time?"
        }
    }',
    
    -- Keywords (alternative to numbers)
    keywords JSONB DEFAULT '{
        "DONATE": {"action": "donate", "response": "Thank you! Donate here: {{donation_link}}"},
        "RSVP": {"action": "rsvp", "response": "Reply YES to confirm attendance"},
        "YES": {"action": "confirm_rsvp", "response": "You''re confirmed! See you there!"},
        "CALL": {"action": "callback", "response": "We''ll call you shortly!"},
        "INFO": {"action": "send_info", "response": "Here''s more information: {{info_link}}"},
        "VOLUNTEER": {"action": "volunteer", "response": "Thanks for volunteering! Sign up: {{volunteer_link}}"},
        "STOP": {"action": "opt_out", "response": "You''ve been unsubscribed. Reply START to resubscribe."}
    }',
    
    -- Default response
    default_response TEXT DEFAULT 'Reply with 1, 2, 3, or 4, or text DONATE, RSVP, or CALL.',
    
    -- Links (for template replacement)
    donation_link TEXT,
    rsvp_link TEXT,
    info_link TEXT,
    volunteer_link TEXT,
    
    -- Settings
    auto_respond BOOLEAN DEFAULT true,
    conversation_timeout_minutes INTEGER DEFAULT 30,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_menus_phone ON sms_interactive_menus(phone_number);
CREATE INDEX IF NOT EXISTS idx_sms_menus_candidate ON sms_interactive_menus(candidate_id);

-- Inbound Calls
CREATE TABLE IF NOT EXISTS inbound_calls (
    call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_sid VARCHAR(100) UNIQUE,
    
    -- Phones
    from_phone VARCHAR(20) NOT NULL,
    to_phone VARCHAR(20) NOT NULL,
    
    -- Routing
    agent_id UUID REFERENCES ai_voice_agents(agent_id),
    
    -- Caller identification
    contact_id UUID,
    contact_name VARCHAR(255),
    is_known_contact BOOLEAN DEFAULT false,
    
    -- Source tracking
    source_channel VARCHAR(50),
    source_campaign_id UUID,
    source_email_id UUID,
    tracking_code VARCHAR(50),
    
    -- Call flow
    status VARCHAR(50) DEFAULT 'ringing',
    answered_at TIMESTAMP,
    
    -- AI Interaction
    ai_handled BOOLEAN DEFAULT true,
    ai_greeting_played BOOLEAN DEFAULT false,
    ai_conversation_transcript JSONB DEFAULT '[]',
    
    -- IVR
    ivr_selections JSONB DEFAULT '[]',
    final_ivr_action VARCHAR(100),
    
    -- Intent & Sentiment
    detected_intent VARCHAR(100),
    sentiment_score DECIMAL(4,2),
    sentiment_label VARCHAR(50),
    
    -- Voicemail
    has_voicemail BOOLEAN DEFAULT false,
    voicemail_recording_url TEXT,
    voicemail_duration_seconds INTEGER,
    voicemail_transcription TEXT,
    voicemail_summary TEXT,
    
    -- Transfer
    transferred BOOLEAN DEFAULT false,
    transferred_to VARCHAR(20),
    transfer_reason VARCHAR(255),
    
    -- Outcome
    outcome VARCHAR(100),
    follow_up_required BOOLEAN DEFAULT false,
    
    -- Timing
    started_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    ring_duration_seconds INTEGER,
    talk_duration_seconds INTEGER,
    
    -- Quality
    call_quality_score DECIMAL(4,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calls_from ON inbound_calls(from_phone);
CREATE INDEX IF NOT EXISTS idx_calls_agent ON inbound_calls(agent_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON inbound_calls(status);
CREATE INDEX IF NOT EXISTS idx_calls_intent ON inbound_calls(detected_intent);
CREATE INDEX IF NOT EXISTS idx_calls_voicemail ON inbound_calls(has_voicemail);

-- SMS Conversations (threaded)
CREATE TABLE IF NOT EXISTS sms_conversations (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Phones
    contact_phone VARCHAR(20) NOT NULL,
    system_phone VARCHAR(20) NOT NULL,
    
    -- Contact
    contact_id UUID,
    contact_name VARCHAR(255),
    
    -- Menu context
    menu_id UUID REFERENCES sms_interactive_menus(menu_id),
    current_state VARCHAR(100) DEFAULT 'initial',
    
    -- Pending actions
    pending_action VARCHAR(100),
    pending_data JSONB DEFAULT '{}',
    
    -- Stats
    message_count INTEGER DEFAULT 0,
    last_inbound_at TIMESTAMP,
    last_outbound_at TIMESTAMP,
    
    -- Status
    status VARCHAR(50) DEFAULT 'active',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sms_conv_phones ON sms_conversations(contact_phone, system_phone);

-- SMS Messages (in conversations)
CREATE TABLE IF NOT EXISTS sms_conversation_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES sms_conversations(conversation_id),
    
    -- Direction
    direction VARCHAR(10) NOT NULL,
    
    -- Content
    message_text TEXT NOT NULL,
    media_urls JSONB DEFAULT '[]',
    
    -- For inbound
    keyword_matched VARCHAR(50),
    option_selected VARCHAR(10),
    action_triggered VARCHAR(100),
    
    -- For outbound
    template_used VARCHAR(100),
    
    -- Delivery
    provider_message_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending',
    delivered_at TIMESTAMP,
    
    sent_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_messages_conv ON sms_conversation_messages(conversation_id);

-- Unified Message Center (All channels)
CREATE TABLE IF NOT EXISTS message_center_inbox (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source
    source_type VARCHAR(50) NOT NULL,
    source_id UUID,
    
    -- Call reference
    call_id UUID REFERENCES inbound_calls(call_id),
    sms_conversation_id UUID REFERENCES sms_conversations(conversation_id),
    
    -- Sender
    from_phone VARCHAR(20),
    from_email VARCHAR(255),
    from_name VARCHAR(255),
    contact_id UUID,
    
    -- Recipient
    candidate_id UUID,
    agent_id UUID,
    
    -- Content
    message_type VARCHAR(50),
    subject VARCHAR(500),
    body_text TEXT,
    audio_url TEXT,
    transcription TEXT,
    summary TEXT,
    
    -- Classification
    intent VARCHAR(100),
    sentiment VARCHAR(50),
    sentiment_score DECIMAL(4,2),
    
    -- Priority & Tags
    priority VARCHAR(20) DEFAULT 'normal',
    is_vip BOOLEAN DEFAULT false,
    tags JSONB DEFAULT '[]',
    
    -- Actions
    action_requested VARCHAR(100),
    callback_requested BOOLEAN DEFAULT false,
    callback_time VARCHAR(100),
    donation_amount DECIMAL(12,2),
    rsvp_event_id UUID,
    
    -- Assignment
    assigned_to VARCHAR(255),
    assigned_at TIMESTAMP,
    
    -- Status
    status VARCHAR(50) DEFAULT 'new',
    read_at TIMESTAMP,
    read_by VARCHAR(255),
    
    -- Response
    responded BOOLEAN DEFAULT false,
    responded_at TIMESTAMP,
    responded_by VARCHAR(255),
    response_channel VARCHAR(50),
    response_notes TEXT,
    
    -- Follow-up
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_date DATE,
    follow_up_notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inbox_candidate ON message_center_inbox(candidate_id);
CREATE INDEX IF NOT EXISTS idx_inbox_status ON message_center_inbox(status);
CREATE INDEX IF NOT EXISTS idx_inbox_priority ON message_center_inbox(priority);
CREATE INDEX IF NOT EXISTS idx_inbox_intent ON message_center_inbox(intent);
CREATE INDEX IF NOT EXISTS idx_inbox_assigned ON message_center_inbox(assigned_to);

-- Email Click-to-Call Buttons
CREATE TABLE IF NOT EXISTS email_call_buttons (
    button_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(255),
    candidate_id UUID,
    
    -- Phone to call
    phone_number VARCHAR(20) NOT NULL,
    agent_id UUID REFERENCES ai_voice_agents(agent_id),
    
    -- Display
    button_text VARCHAR(255) DEFAULT 'Call Now',
    button_subtext VARCHAR(255) DEFAULT 'Speak with our team',
    button_style JSONB DEFAULT '{"backgroundColor": "#1a365d", "textColor": "#ffffff"}',
    
    -- Avatar
    avatar_image_url TEXT,
    show_avatar BOOLEAN DEFAULT true,
    
    -- Personalization
    personalized_greeting BOOLEAN DEFAULT true,
    greeting_template TEXT DEFAULT 'Hello {{first_name}}, thank you for calling!',
    
    -- Tracking
    tracking_prefix VARCHAR(20),
    
    -- Stats
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    calls_initiated INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_call_buttons_candidate ON email_call_buttons(candidate_id);

-- Click Events (email buttons)
CREATE TABLE IF NOT EXISTS email_call_button_clicks (
    click_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    button_id UUID REFERENCES email_call_buttons(button_id),
    
    -- Source
    email_campaign_id UUID,
    email_send_id UUID,
    
    -- User
    contact_id UUID,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    contact_name VARCHAR(255),
    
    -- Tracking
    tracking_code VARCHAR(50),
    
    -- Device
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_type VARCHAR(50),
    
    -- Outcome
    call_initiated BOOLEAN DEFAULT false,
    call_id UUID,
    
    clicked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_call_clicks_button ON email_call_button_clicks(button_id);

-- RSVP Processing
CREATE TABLE IF NOT EXISTS interactive_rsvps (
    rsvp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source
    source_channel VARCHAR(50) NOT NULL,
    source_id UUID,
    
    -- Contact
    contact_id UUID,
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),
    contact_name VARCHAR(255),
    
    -- Event
    event_id UUID,
    event_name VARCHAR(255),
    
    -- RSVP details
    attending BOOLEAN DEFAULT true,
    guest_count INTEGER DEFAULT 1,
    dietary_restrictions TEXT,
    
    -- Confirmation
    confirmation_sent BOOLEAN DEFAULT false,
    confirmation_channel VARCHAR(50),
    confirmation_sent_at TIMESTAMP,
    
    -- Status
    status VARCHAR(50) DEFAULT 'confirmed',
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rsvps_event ON interactive_rsvps(event_id);
CREATE INDEX IF NOT EXISTS idx_rsvps_contact ON interactive_rsvps(contact_id);

-- Donation Processing (text-to-donate)
CREATE TABLE IF NOT EXISTS interactive_donations (
    donation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source
    source_channel VARCHAR(50) NOT NULL,
    source_id UUID,
    
    -- Donor
    contact_id UUID,
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),
    contact_name VARCHAR(255),
    
    -- Donation
    amount DECIMAL(12,2),
    is_recurring BOOLEAN DEFAULT false,
    frequency VARCHAR(50),
    
    -- Payment
    payment_link_sent BOOLEAN DEFAULT false,
    payment_link_url TEXT,
    payment_link_clicked BOOLEAN DEFAULT false,
    payment_completed BOOLEAN DEFAULT false,
    
    -- Processing
    processor VARCHAR(50),
    processor_transaction_id VARCHAR(255),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_donations_contact ON interactive_donations(contact_id);
CREATE INDEX IF NOT EXISTS idx_donations_status ON interactive_donations(status);

-- Analytics Views
CREATE OR REPLACE VIEW v_call_analytics AS
SELECT 
    DATE(started_at) as date,
    agent_id,
    COUNT(*) as total_calls,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_calls,
    COUNT(*) FILTER (WHERE has_voicemail = true) as voicemails,
    COUNT(*) FILTER (WHERE transferred = true) as transfers,
    AVG(duration_seconds) as avg_duration,
    AVG(sentiment_score) as avg_sentiment,
    COUNT(DISTINCT detected_intent) as unique_intents
FROM inbound_calls
GROUP BY DATE(started_at), agent_id;

CREATE OR REPLACE VIEW v_sms_menu_analytics AS
SELECT 
    m.menu_id,
    m.name,
    COUNT(msg.message_id) as total_interactions,
    COUNT(DISTINCT c.contact_phone) as unique_contacts,
    COUNT(*) FILTER (WHERE msg.action_triggered = 'donate') as donate_actions,
    COUNT(*) FILTER (WHERE msg.action_triggered = 'rsvp') as rsvp_actions,
    COUNT(*) FILTER (WHERE msg.action_triggered = 'callback') as callback_requests
FROM sms_interactive_menus m
LEFT JOIN sms_conversations c ON m.menu_id = c.menu_id
LEFT JOIN sms_conversation_messages msg ON c.conversation_id = msg.conversation_id
GROUP BY m.menu_id, m.name;

CREATE OR REPLACE VIEW v_message_center_summary AS
SELECT 
    candidate_id,
    COUNT(*) as total_messages,
    COUNT(*) FILTER (WHERE status = 'new') as unread,
    COUNT(*) FILTER (WHERE priority = 'urgent') as urgent,
    COUNT(*) FILTER (WHERE priority = 'vip') as vip,
    COUNT(*) FILTER (WHERE callback_requested = true AND NOT responded) as pending_callbacks,
    COUNT(*) FILTER (WHERE intent = 'donate') as donation_inquiries,
    COUNT(*) FILTER (WHERE intent = 'volunteer') as volunteer_inquiries
FROM message_center_inbox
GROUP BY candidate_id;

CREATE OR REPLACE VIEW v_channel_performance AS
SELECT 
    source_type as channel,
    COUNT(*) as total_interactions,
    COUNT(*) FILTER (WHERE responded = true) as responded,
    AVG(EXTRACT(EPOCH FROM (responded_at - created_at))/60) as avg_response_minutes,
    COUNT(*) FILTER (WHERE intent = 'donate') as donations,
    COUNT(*) FILTER (WHERE intent = 'rsvp') as rsvps
FROM message_center_inbox
GROUP BY source_type;

SELECT 'Interactive Communication Hub schema deployed!' as status;


-- Auto-Response Templates
CREATE TABLE IF NOT EXISTS auto_response_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    candidate_id UUID,
    trigger_type VARCHAR(100) NOT NULL,
    delay_seconds INTEGER DEFAULT 60,
    send_immediately BOOLEAN DEFAULT false,
    response_channel VARCHAR(50) DEFAULT 'sms',
    message_template TEXT NOT NULL,
    signature_name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    priority INTEGER DEFAULT 50,
    times_sent INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Scheduled Auto-Responses
CREATE TABLE IF NOT EXISTS auto_response_queue (
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID,
    recipient_phone VARCHAR(20),
    recipient_name VARCHAR(255),
    contact_id UUID,
    personalization_data JSONB DEFAULT '{}',
    rendered_message TEXT,
    scheduled_for TIMESTAMP NOT NULL,
    source_type VARCHAR(50),
    source_id UUID,
    status VARCHAR(50) DEFAULT 'pending',
    sent_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auto_queue_status ON auto_response_queue(status, scheduled_for);

-- Auto-Response Log
CREATE TABLE IF NOT EXISTS auto_response_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    queue_id UUID,
    template_id UUID,
    recipient_phone VARCHAR(20),
    contact_id UUID,
    channel VARCHAR(50),
    message_sent TEXT,
    trigger_type VARCHAR(100),
    status VARCHAR(50),
    recipient_replied BOOLEAN DEFAULT false,
    sent_at TIMESTAMP DEFAULT NOW()
);

-- Default Templates
INSERT INTO auto_response_templates (name, trigger_type, delay_seconds, message_template, signature_name) VALUES 
('Voicemail Thank You', 'voicemail', 60, 
'Hi {{first_name}}, thank you for your message! I personally review every voicemail and truly appreciate you reaching out. I''ll get back to you soon.

God bless,
{{candidate_first_name}}', 'Sheriff Jim Davis'),

('VIP Voicemail', 'voicemail_vip', 0,
'{{first_name}}, thank you for calling! Your support means the world to me. I''ll be calling you back personally very soon.

With gratitude,
{{candidate_first_name}}', 'Sheriff Jim Davis'),

('Donation Thank You', 'donation', 0,
'{{first_name}}, THANK YOU for your generous ${{donation_amount}} contribution! Patriots like you make this campaign possible.

With deep gratitude,
{{candidate_first_name}}', 'Sheriff Jim Davis'),

('Major Donation Thank You', 'donation_major', 0,
'{{first_name}}, I am truly humbled by your ${{donation_amount}} investment in our campaign. Expect a personal call from me soon.

With sincere gratitude,
{{candidate_name}}', 'Sheriff Jim Davis'),

('RSVP Confirmation', 'rsvp', 0,
'{{first_name}}, you''re confirmed for {{event_name}} on {{event_date}}! Can''t wait to see you there!

{{candidate_first_name}}', 'Sheriff Jim Davis'),

('Callback Acknowledgment', 'callback_request', 0,
'Hi {{first_name}}, we got your callback request! A team member will call within 24 hours.

Team {{candidate_last_name}}', 'Team Davis'),

('Volunteer Welcome', 'volunteer', 0,
'{{first_name}}, THANK YOU for volunteering! Our coordinator will reach out within 48 hours.

Together we win!
{{candidate_first_name}}', 'Sheriff Jim Davis')

ON CONFLICT DO NOTHING;


-- ================================================================
-- FROM: ecosystem_36_messenger_integration_complete.py (E36)
-- ================================================================

-- ================================================================
-- FROM: ecosystem_37_event_management_complete.py (E37)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 37: EVENT MANAGEMENT
-- ============================================================================

-- Venues
CREATE TABLE IF NOT EXISTS event_venues (
    venue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Venue info
    name VARCHAR(255) NOT NULL,
    venue_type VARCHAR(50),
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    county VARCHAR(100),
    
    -- Coordinates
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    
    -- Capacity
    max_capacity INTEGER,
    seated_capacity INTEGER,
    standing_capacity INTEGER,
    
    -- Amenities
    has_av_equipment BOOLEAN DEFAULT false,
    has_parking BOOLEAN DEFAULT false,
    parking_capacity INTEGER,
    is_accessible BOOLEAN DEFAULT true,
    amenities JSONB DEFAULT '[]',
    
    -- Contact
    contact_name VARCHAR(255),
    contact_phone VARCHAR(50),
    contact_email VARCHAR(255),
    
    -- Costs
    rental_cost DECIMAL(12,2),
    notes TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_venue_city ON event_venues(city);
CREATE INDEX IF NOT EXISTS idx_venue_county ON event_venues(county);

-- Events
CREATE TABLE IF NOT EXISTS campaign_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(500) NOT NULL,
    slug VARCHAR(255),
    description TEXT,
    short_description VARCHAR(500),
    
    -- Type
    event_type VARCHAR(50) NOT NULL,
    
    -- Ownership
    candidate_id UUID,
    host_contact_id UUID,
    created_by VARCHAR(255),
    
    -- Location
    venue_id UUID REFERENCES event_venues(venue_id),
    is_virtual BOOLEAN DEFAULT false,
    virtual_url TEXT,
    virtual_platform VARCHAR(100),
    location_override TEXT,
    
    -- Timing
    start_datetime TIMESTAMP NOT NULL,
    end_datetime TIMESTAMP,
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    doors_open_datetime TIMESTAMP,
    
    -- Capacity
    max_capacity INTEGER,
    current_rsvps INTEGER DEFAULT 0,
    waitlist_enabled BOOLEAN DEFAULT true,
    waitlist_count INTEGER DEFAULT 0,
    
    -- Ticketing
    is_ticketed BOOLEAN DEFAULT false,
    ticket_price DECIMAL(10,2),
    ticket_types JSONB DEFAULT '[]',
    
    -- Fundraising
    is_fundraiser BOOLEAN DEFAULT false,
    fundraising_goal DECIMAL(12,2),
    amount_raised DECIMAL(12,2) DEFAULT 0,
    suggested_donations JSONB DEFAULT '[]',
    
    -- Content
    image_url TEXT,
    banner_url TEXT,
    agenda JSONB DEFAULT '[]',
    speakers JSONB DEFAULT '[]',
    
    -- Settings
    require_approval BOOLEAN DEFAULT false,
    allow_guests BOOLEAN DEFAULT true,
    max_guests_per_rsvp INTEGER DEFAULT 2,
    send_reminders BOOLEAN DEFAULT true,
    reminder_schedule JSONB DEFAULT '["24h", "2h"]',
    
    -- IFTTT Control
    automation_mode VARCHAR(20) DEFAULT 'on',
    automation_timer_minutes INTEGER,
    automation_timer_expires_at TIMESTAMP,
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    published_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT,
    
    -- Stats
    total_rsvps INTEGER DEFAULT 0,
    total_attended INTEGER DEFAULT 0,
    total_no_shows INTEGER DEFAULT 0,
    check_in_count INTEGER DEFAULT 0,
    
    -- SEO
    meta_title VARCHAR(255),
    meta_description TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_type ON campaign_events(event_type);
CREATE INDEX IF NOT EXISTS idx_event_status ON campaign_events(status);
CREATE INDEX IF NOT EXISTS idx_event_date ON campaign_events(start_datetime);
CREATE INDEX IF NOT EXISTS idx_event_candidate ON campaign_events(candidate_id);
CREATE INDEX IF NOT EXISTS idx_event_venue ON campaign_events(venue_id);

-- RSVPs
CREATE TABLE IF NOT EXISTS event_rsvps (
    rsvp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES campaign_events(event_id),
    contact_id UUID,
    
    -- Contact info
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(50),
    
    -- RSVP details
    status VARCHAR(50) DEFAULT 'registered',
    guest_count INTEGER DEFAULT 0,
    guest_names JSONB DEFAULT '[]',
    
    -- Ticketing
    ticket_type VARCHAR(50),
    ticket_quantity INTEGER DEFAULT 1,
    amount_paid DECIMAL(10,2) DEFAULT 0,
    payment_status VARCHAR(50),
    
    -- Dietary/accessibility
    dietary_restrictions TEXT,
    accessibility_needs TEXT,
    notes TEXT,
    
    -- Check-in
    checked_in BOOLEAN DEFAULT false,
    checked_in_at TIMESTAMP,
    checked_in_by VARCHAR(255),
    
    -- Communication
    confirmation_sent BOOLEAN DEFAULT false,
    reminder_sent BOOLEAN DEFAULT false,
    
    -- Source tracking
    source VARCHAR(100),
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    
    -- Waitlist
    waitlist_position INTEGER,
    promoted_from_waitlist_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rsvp_event ON event_rsvps(event_id);
CREATE INDEX IF NOT EXISTS idx_rsvp_contact ON event_rsvps(contact_id);
CREATE INDEX IF NOT EXISTS idx_rsvp_status ON event_rsvps(status);
CREATE INDEX IF NOT EXISTS idx_rsvp_email ON event_rsvps(email);

-- Event Shifts (for volunteer events)
CREATE TABLE IF NOT EXISTS event_shifts (
    shift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES campaign_events(event_id),
    
    -- Shift details
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Timing
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    
    -- Capacity
    max_volunteers INTEGER,
    current_signups INTEGER DEFAULT 0,
    
    -- Role
    role_type VARCHAR(100),
    skills_required JSONB DEFAULT '[]',
    
    -- Location
    location_override TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shift_event ON event_shifts(event_id);

-- Shift Signups
CREATE TABLE IF NOT EXISTS event_shift_signups (
    signup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id UUID REFERENCES event_shifts(shift_id),
    contact_id UUID,
    
    -- Contact info
    volunteer_name VARCHAR(255),
    volunteer_email VARCHAR(255),
    volunteer_phone VARCHAR(50),
    
    -- Status
    status VARCHAR(50) DEFAULT 'confirmed',
    checked_in BOOLEAN DEFAULT false,
    checked_in_at TIMESTAMP,
    hours_worked DECIMAL(4,2),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_signup_shift ON event_shift_signups(shift_id);

-- Event Series (recurring events)
CREATE TABLE IF NOT EXISTS event_series (
    series_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Recurrence
    recurrence_pattern VARCHAR(50),
    recurrence_config JSONB DEFAULT '{}',
    
    -- Template
    event_template JSONB DEFAULT '{}',
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Event Check-in Codes
CREATE TABLE IF NOT EXISTS event_checkin_codes (
    code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES campaign_events(event_id),
    
    -- Code
    code VARCHAR(20) NOT NULL UNIQUE,
    code_type VARCHAR(50) DEFAULT 'qr',
    
    -- Usage
    is_active BOOLEAN DEFAULT true,
    max_uses INTEGER,
    times_used INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Event Donations
CREATE TABLE IF NOT EXISTS event_donations (
    donation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES campaign_events(event_id),
    rsvp_id UUID REFERENCES event_rsvps(rsvp_id),
    contact_id UUID,
    
    -- Donation
    amount DECIMAL(12,2) NOT NULL,
    donation_type VARCHAR(50),
    
    -- Payment
    payment_method VARCHAR(50),
    payment_status VARCHAR(50),
    transaction_id VARCHAR(255),
    
    -- FEC
    is_fec_compliant BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_donation_event ON event_donations(event_id);

-- Event Communications
CREATE TABLE IF NOT EXISTS event_communications (
    comm_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES campaign_events(event_id),
    
    -- Type
    comm_type VARCHAR(50) NOT NULL,
    
    -- Content
    subject VARCHAR(500),
    content TEXT,
    
    -- Targeting
    target_status JSONB DEFAULT '["registered", "confirmed"]',
    
    -- Scheduling
    send_at TIMESTAMP,
    sent_at TIMESTAMP,
    
    -- Stats
    recipients INTEGER DEFAULT 0,
    delivered INTEGER DEFAULT 0,
    opened INTEGER DEFAULT 0,
    clicked INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_upcoming_events AS
SELECT 
    e.event_id,
    e.name,
    e.event_type,
    e.start_datetime,
    e.end_datetime,
    e.status,
    e.max_capacity,
    e.current_rsvps,
    e.is_fundraiser,
    e.fundraising_goal,
    e.amount_raised,
    v.name as venue_name,
    v.city as venue_city,
    e.is_virtual,
    CASE WHEN e.max_capacity IS NOT NULL 
         THEN ROUND((e.current_rsvps::numeric / e.max_capacity) * 100, 1)
         ELSE 0 END as capacity_pct
FROM campaign_events e
LEFT JOIN event_venues v ON e.venue_id = v.venue_id
WHERE e.start_datetime > NOW()
AND e.status = 'published'
ORDER BY e.start_datetime ASC;

CREATE OR REPLACE VIEW v_event_performance AS
SELECT 
    e.event_id,
    e.name,
    e.event_type,
    e.start_datetime,
    e.total_rsvps,
    e.total_attended,
    e.total_no_shows,
    CASE WHEN e.total_rsvps > 0 
         THEN ROUND((e.total_attended::numeric / e.total_rsvps) * 100, 1)
         ELSE 0 END as attendance_rate,
    e.amount_raised,
    e.fundraising_goal,
    CASE WHEN e.fundraising_goal > 0 
         THEN ROUND((e.amount_raised / e.fundraising_goal) * 100, 1)
         ELSE 0 END as fundraising_pct
FROM campaign_events e
WHERE e.status = 'completed'
ORDER BY e.start_datetime DESC;

SELECT 'Event Management schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_38_volunteer_coordination_complete.py (E38)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 38: VOLUNTEER COORDINATION CENTER
-- ============================================================================

-- Field Offices
CREATE TABLE IF NOT EXISTS field_offices (
    office_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip VARCHAR(20),
    county VARCHAR(100),
    phone VARCHAR(50),
    email VARCHAR(255),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    max_capacity INTEGER,
    office_manager VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_field_office_candidate ON field_offices(candidate_id);

-- Turfs (geographic territories for canvassing)
CREATE TABLE IF NOT EXISTS volunteer_turfs (
    turf_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID REFERENCES field_offices(office_id),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    turf_type VARCHAR(50) DEFAULT 'canvass',
    precinct_ids JSONB DEFAULT '[]',
    zip_codes JSONB DEFAULT '[]',
    boundary_geojson JSONB,
    household_count INTEGER,
    voter_count INTEGER,
    door_count INTEGER,
    priority_score INTEGER DEFAULT 50,
    status VARCHAR(50) DEFAULT 'available',
    times_walked INTEGER DEFAULT 0,
    last_walked_at TIMESTAMP,
    completion_rate DECIMAL(5,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_turf_office ON volunteer_turfs(office_id);
CREATE INDEX IF NOT EXISTS idx_turf_status ON volunteer_turfs(status);

-- Turf Assignments
CREATE TABLE IF NOT EXISTS turf_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turf_id UUID REFERENCES volunteer_turfs(turf_id),
    volunteer_id UUID,
    shift_id UUID,
    assigned_at TIMESTAMP DEFAULT NOW(),
    assigned_by VARCHAR(255),
    status VARCHAR(50) DEFAULT 'assigned',
    doors_attempted INTEGER DEFAULT 0,
    doors_contacted INTEGER DEFAULT 0,
    not_home INTEGER DEFAULT 0,
    refused INTEGER DEFAULT 0,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_turf_assign_turf ON turf_assignments(turf_id);

-- Walk Lists
CREATE TABLE IF NOT EXISTS walk_lists (
    list_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turf_id UUID REFERENCES volunteer_turfs(turf_id),
    assignment_id UUID REFERENCES turf_assignments(assignment_id),
    name VARCHAR(255),
    voter_count INTEGER,
    household_count INTEGER,
    pdf_url TEXT,
    qr_code_url TEXT,
    generated_at TIMESTAMP DEFAULT NOW()
);

-- Volunteer Check-ins
CREATE TABLE IF NOT EXISTS volunteer_checkins (
    checkin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID REFERENCES field_offices(office_id),
    volunteer_id UUID,
    volunteer_name VARCHAR(255),
    phone VARCHAR(50),
    checkin_time TIMESTAMP DEFAULT NOW(),
    checkin_method VARCHAR(50),
    activity_type VARCHAR(100),
    turf_id UUID REFERENCES volunteer_turfs(turf_id),
    assigned_by VARCHAR(255),
    materials_issued JSONB DEFAULT '[]',
    checkout_time TIMESTAMP,
    hours_worked DECIMAL(5,2),
    doors_knocked INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    texts_sent INTEGER DEFAULT 0,
    volunteer_feedback TEXT,
    coordinator_notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_checkin_office ON volunteer_checkins(office_id);
CREATE INDEX IF NOT EXISTS idx_checkin_time ON volunteer_checkins(checkin_time);

-- Volunteer Certifications
CREATE TABLE IF NOT EXISTS volunteer_certifications (
    cert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID NOT NULL,
    certification_type VARCHAR(100) NOT NULL,
    certification_name VARCHAR(255),
    issued_date DATE,
    expiry_date DATE,
    issuing_authority VARCHAR(255),
    certificate_number VARCHAR(100),
    is_verified BOOLEAN DEFAULT false,
    verified_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cert_volunteer ON volunteer_certifications(volunteer_id);

-- Dispatch Queue
CREATE TABLE IF NOT EXISTS dispatch_queue (
    dispatch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID REFERENCES field_offices(office_id),
    volunteer_id UUID,
    volunteer_name VARCHAR(255),
    activity_type VARCHAR(100),
    priority INTEGER DEFAULT 5,
    status VARCHAR(50) DEFAULT 'waiting',
    queued_at TIMESTAMP DEFAULT NOW(),
    dispatched_at TIMESTAMP,
    dispatched_by VARCHAR(255),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_dispatch_status ON dispatch_queue(status);

-- Resource Inventory
CREATE TABLE IF NOT EXISTS office_inventory (
    inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID REFERENCES field_offices(office_id),
    item_name VARCHAR(255) NOT NULL,
    item_type VARCHAR(100),
    quantity_available INTEGER DEFAULT 0,
    quantity_issued INTEGER DEFAULT 0,
    reorder_threshold INTEGER,
    last_restocked TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Weather Alerts
CREATE TABLE IF NOT EXISTS weather_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID REFERENCES field_offices(office_id),
    alert_type VARCHAR(100),
    severity VARCHAR(50),
    message TEXT,
    effective_start TIMESTAMP,
    effective_end TIMESTAMP,
    canvass_suspended BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_office_daily_stats AS
SELECT 
    c.office_id,
    c.checkin_time::DATE as shift_date,
    COUNT(DISTINCT c.volunteer_id) as unique_volunteers,
    SUM(c.hours_worked) as total_hours,
    SUM(c.doors_knocked) as total_doors,
    SUM(c.calls_made) as total_calls
FROM volunteer_checkins c
WHERE c.checkout_time IS NOT NULL
GROUP BY c.office_id, c.checkin_time::DATE;

CREATE OR REPLACE VIEW v_turf_status AS
SELECT 
    t.turf_id,
    t.name,
    t.status,
    t.door_count,
    t.times_walked,
    t.completion_rate,
    COUNT(ta.assignment_id) as total_assignments,
    SUM(ta.doors_contacted) as total_contacts
FROM volunteer_turfs t
LEFT JOIN turf_assignments ta ON t.turf_id = ta.turf_id
GROUP BY t.turf_id;

SELECT 'Volunteer Coordination schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_39_p2p_fundraising_complete.py (E39)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 39: PEER-TO-PEER FUNDRAISING
-- ============================================================================

-- P2P Campaigns (umbrella campaigns that fundraisers join)
CREATE TABLE IF NOT EXISTS p2p_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    -- Campaign info
    name VARCHAR(500) NOT NULL,
    slug VARCHAR(255) UNIQUE,
    tagline VARCHAR(255),
    description TEXT,
    
    -- Type
    campaign_type VARCHAR(50) DEFAULT 'general',
    
    -- Goals
    goal_amount DECIMAL(14,2),
    minimum_fundraiser_goal DECIMAL(12,2) DEFAULT 100,
    suggested_goals JSONB DEFAULT '[250, 500, 1000, 2500]',
    
    -- Dates
    start_date DATE,
    end_date DATE,
    
    -- Branding
    hero_image_url TEXT,
    logo_url TEXT,
    primary_color VARCHAR(20),
    
    -- Matching
    has_matching BOOLEAN DEFAULT false,
    match_ratio DECIMAL(4,2) DEFAULT 1,
    match_cap DECIMAL(14,2),
    match_sponsor VARCHAR(255),
    
    -- Totals
    amount_raised DECIMAL(14,2) DEFAULT 0,
    matched_amount DECIMAL(14,2) DEFAULT 0,
    fundraiser_count INTEGER DEFAULT 0,
    team_count INTEGER DEFAULT 0,
    donor_count INTEGER DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    is_featured BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_p2p_campaign_candidate ON p2p_campaigns(candidate_id);
CREATE INDEX IF NOT EXISTS idx_p2p_campaign_status ON p2p_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_p2p_campaign_slug ON p2p_campaigns(slug);

-- Fundraising Teams
CREATE TABLE IF NOT EXISTS p2p_teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES p2p_campaigns(campaign_id),
    
    -- Team info
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255),
    description TEXT,
    
    -- Captain
    captain_id UUID,
    captain_name VARCHAR(255),
    captain_email VARCHAR(255),
    
    -- Goals
    team_goal DECIMAL(14,2),
    
    -- Branding
    image_url TEXT,
    
    -- Stats
    amount_raised DECIMAL(14,2) DEFAULT 0,
    member_count INTEGER DEFAULT 0,
    donor_count INTEGER DEFAULT 0,
    
    -- Rank
    rank INTEGER,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_p2p_team_campaign ON p2p_teams(campaign_id);

-- Individual Fundraiser Pages
CREATE TABLE IF NOT EXISTS p2p_fundraisers (
    fundraiser_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES p2p_campaigns(campaign_id),
    team_id UUID REFERENCES p2p_teams(team_id),
    
    -- Fundraiser info
    contact_id UUID,
    slug VARCHAR(255) UNIQUE,
    
    -- Personal info
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    
    -- Page content
    page_title VARCHAR(500),
    personal_story TEXT,
    why_support TEXT,
    
    -- Media
    profile_image_url TEXT,
    cover_image_url TEXT,
    video_url TEXT,
    
    -- Goals
    personal_goal DECIMAL(12,2) DEFAULT 500,
    stretch_goal DECIMAL(12,2),
    
    -- Stats
    amount_raised DECIMAL(12,2) DEFAULT 0,
    donor_count INTEGER DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    
    -- Sharing stats
    page_views INTEGER DEFAULT 0,
    unique_visitors INTEGER DEFAULT 0,
    share_count INTEGER DEFAULT 0,
    email_shares INTEGER DEFAULT 0,
    facebook_shares INTEGER DEFAULT 0,
    twitter_shares INTEGER DEFAULT 0,
    
    -- Engagement
    emails_sent INTEGER DEFAULT 0,
    thank_yous_sent INTEGER DEFAULT 0,
    
    -- Rank
    rank INTEGER,
    
    -- Milestones achieved
    milestones_achieved JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    published_at TIMESTAMP,
    
    -- Notifications
    notification_preferences JSONB DEFAULT '{"email_on_donation": true, "daily_summary": true}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_p2p_fundraiser_campaign ON p2p_fundraisers(campaign_id);
CREATE INDEX IF NOT EXISTS idx_p2p_fundraiser_team ON p2p_fundraisers(team_id);
CREATE INDEX IF NOT EXISTS idx_p2p_fundraiser_email ON p2p_fundraisers(email);
CREATE INDEX IF NOT EXISTS idx_p2p_fundraiser_slug ON p2p_fundraisers(slug);

-- P2P Donations
CREATE TABLE IF NOT EXISTS p2p_donations (
    donation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fundraiser_id UUID REFERENCES p2p_fundraisers(fundraiser_id),
    campaign_id UUID REFERENCES p2p_campaigns(campaign_id),
    team_id UUID REFERENCES p2p_teams(team_id),
    
    -- Master donation reference
    master_donation_id UUID,
    
    -- Donor info
    donor_name VARCHAR(255),
    donor_email VARCHAR(255),
    is_anonymous BOOLEAN DEFAULT false,
    
    -- Amount
    amount DECIMAL(12,2) NOT NULL,
    matched_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Message
    donor_message TEXT,
    display_message BOOLEAN DEFAULT true,
    
    -- Attribution
    referral_source VARCHAR(100),
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    
    -- Acknowledgment
    thank_you_sent BOOLEAN DEFAULT false,
    thank_you_sent_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_p2p_donation_fundraiser ON p2p_donations(fundraiser_id);
CREATE INDEX IF NOT EXISTS idx_p2p_donation_campaign ON p2p_donations(campaign_id);

-- Fundraiser Milestones
CREATE TABLE IF NOT EXISTS p2p_milestones (
    milestone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES p2p_campaigns(campaign_id),
    
    -- Milestone
    name VARCHAR(255) NOT NULL,
    description TEXT,
    threshold_amount DECIMAL(12,2) NOT NULL,
    threshold_type VARCHAR(50) DEFAULT 'amount',  -- amount, donors, percent
    
    -- Reward
    badge_image_url TEXT,
    reward_description TEXT,
    
    -- Display
    display_order INTEGER,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Milestone Achievements
CREATE TABLE IF NOT EXISTS p2p_milestone_achievements (
    achievement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fundraiser_id UUID REFERENCES p2p_fundraisers(fundraiser_id),
    milestone_id UUID REFERENCES p2p_milestones(milestone_id),
    
    achieved_at TIMESTAMP DEFAULT NOW(),
    notified BOOLEAN DEFAULT false
);

-- Fundraiser Activity Feed
CREATE TABLE IF NOT EXISTS p2p_activity_feed (
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fundraiser_id UUID REFERENCES p2p_fundraisers(fundraiser_id),
    campaign_id UUID REFERENCES p2p_campaigns(campaign_id),
    
    -- Activity
    activity_type VARCHAR(100) NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}',
    
    -- Visibility
    is_public BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_p2p_activity_fundraiser ON p2p_activity_feed(fundraiser_id);

-- Coaching Messages (tips for fundraisers)
CREATE TABLE IF NOT EXISTS p2p_coaching_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES p2p_campaigns(campaign_id),
    
    -- Trigger
    trigger_type VARCHAR(100),  -- signup, first_donation, 50_percent, stalled, etc.
    trigger_days INTEGER,
    
    -- Content
    subject VARCHAR(255),
    message_body TEXT,
    
    -- Channel
    channel VARCHAR(50) DEFAULT 'email',
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Social Share Tracking
CREATE TABLE IF NOT EXISTS p2p_shares (
    share_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fundraiser_id UUID REFERENCES p2p_fundraisers(fundraiser_id),
    
    -- Share info
    platform VARCHAR(50) NOT NULL,
    share_url TEXT,
    
    -- Results
    clicks INTEGER DEFAULT 0,
    donations_attributed INTEGER DEFAULT 0,
    amount_attributed DECIMAL(12,2) DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_p2p_leaderboard AS
SELECT 
    f.fundraiser_id,
    f.first_name,
    f.last_name,
    f.page_title,
    f.personal_goal,
    f.amount_raised,
    f.donor_count,
    f.profile_image_url,
    t.name as team_name,
    CASE WHEN f.personal_goal > 0 
         THEN ROUND((f.amount_raised / f.personal_goal) * 100, 1)
         ELSE 0 END as progress_percent,
    RANK() OVER (ORDER BY f.amount_raised DESC) as rank
FROM p2p_fundraisers f
LEFT JOIN p2p_teams t ON f.team_id = t.team_id
WHERE f.status = 'active'
ORDER BY f.amount_raised DESC;

CREATE OR REPLACE VIEW v_p2p_team_leaderboard AS
SELECT 
    t.team_id,
    t.name,
    t.team_goal,
    t.amount_raised,
    t.member_count,
    t.donor_count,
    t.image_url,
    CASE WHEN t.team_goal > 0 
         THEN ROUND((t.amount_raised / t.team_goal) * 100, 1)
         ELSE 0 END as progress_percent,
    RANK() OVER (ORDER BY t.amount_raised DESC) as rank
FROM p2p_teams t
WHERE t.is_active = true
ORDER BY t.amount_raised DESC;

CREATE OR REPLACE VIEW v_p2p_campaign_stats AS
SELECT 
    c.campaign_id,
    c.name,
    c.goal_amount,
    c.amount_raised,
    c.matched_amount,
    c.fundraiser_count,
    c.team_count,
    c.donor_count,
    CASE WHEN c.goal_amount > 0 
         THEN ROUND((c.amount_raised / c.goal_amount) * 100, 1)
         ELSE 0 END as progress_percent,
    AVG(f.amount_raised) as avg_fundraiser_amount,
    MAX(f.amount_raised) as top_fundraiser_amount
FROM p2p_campaigns c
LEFT JOIN p2p_fundraisers f ON c.campaign_id = f.campaign_id
GROUP BY c.campaign_id;

SELECT 'P2P Fundraising schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_40_automation_control_panel_complete.py (E40)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 40: AUTOMATION CONTROL PANEL
-- ============================================================================

-- Workflow Definitions
CREATE TABLE IF NOT EXISTS automation_workflows (
    workflow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(500) NOT NULL,
    description TEXT,
    
    -- Ownership
    candidate_id UUID,
    created_by VARCHAR(255),
    
    -- Configuration
    trigger_type VARCHAR(100) NOT NULL,
    trigger_config JSONB DEFAULT '{}',
    
    -- Workflow steps (JSON array of steps)
    steps JSONB DEFAULT '[]',
    
    -- Goals
    goals JSONB DEFAULT '[]',
    
    -- Settings
    status VARCHAR(50) DEFAULT 'draft',
    run_once_per_contact BOOLEAN DEFAULT true,
    max_enrollments INTEGER,
    
    -- A/B Testing
    ab_test_enabled BOOLEAN DEFAULT false,
    ab_test_config JSONB DEFAULT '{}',
    
    -- Stats
    total_enrollments INTEGER DEFAULT 0,
    total_completions INTEGER DEFAULT 0,
    total_goals_achieved INTEGER DEFAULT 0,
    
    -- AI Measurement
    ai_insights_enabled BOOLEAN DEFAULT true,
    last_ai_analysis TIMESTAMP,
    ai_performance_score DECIMAL(5,2),
    ai_recommendations JSONB DEFAULT '[]',
    
    -- Timing
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    activated_at TIMESTAMP,
    paused_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_workflows_status ON automation_workflows(status);
CREATE INDEX IF NOT EXISTS idx_workflows_trigger ON automation_workflows(trigger_type);
CREATE INDEX IF NOT EXISTS idx_workflows_candidate ON automation_workflows(candidate_id);

-- Workflow Steps (detailed)
CREATE TABLE IF NOT EXISTS automation_steps (
    step_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES automation_workflows(workflow_id),
    
    -- Position
    step_order INTEGER NOT NULL,
    parent_step_id UUID,
    branch_condition VARCHAR(50),
    
    -- Step type
    step_type VARCHAR(50) NOT NULL,
    action_type VARCHAR(100),
    action_config JSONB DEFAULT '{}',
    
    -- Conditions
    conditions JSONB DEFAULT '[]',
    
    -- Delay
    delay_type VARCHAR(50),
    delay_value INTEGER,
    delay_unit VARCHAR(20),
    
    -- Stats
    executions INTEGER DEFAULT 0,
    successes INTEGER DEFAULT 0,
    failures INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_steps_workflow ON automation_steps(workflow_id);

-- Workflow Enrollments
CREATE TABLE IF NOT EXISTS automation_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES automation_workflows(workflow_id),
    
    -- Contact
    contact_id UUID NOT NULL,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    
    -- Trigger context
    trigger_event JSONB DEFAULT '{}',
    
    -- Progress
    current_step_id UUID,
    current_step_order INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'active',
    
    -- Goal tracking
    goal_achieved BOOLEAN DEFAULT false,
    goal_achieved_at TIMESTAMP,
    goal_type VARCHAR(100),
    goal_value DECIMAL(12,2),
    
    -- Branch tracking
    branch_path JSONB DEFAULT '[]',
    ab_variant VARCHAR(10),
    
    -- Timing
    enrolled_at TIMESTAMP DEFAULT NOW(),
    next_step_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    -- Attribution
    conversion_value DECIMAL(12,2),
    attributed_revenue DECIMAL(12,2)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_workflow ON automation_enrollments(workflow_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_contact ON automation_enrollments(contact_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_status ON automation_enrollments(status);

-- Step Executions
CREATE TABLE IF NOT EXISTS automation_executions (
    execution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrollment_id UUID REFERENCES automation_enrollments(enrollment_id),
    step_id UUID REFERENCES automation_steps(step_id),
    
    -- Execution details
    action_type VARCHAR(100),
    action_input JSONB DEFAULT '{}',
    action_output JSONB DEFAULT '{}',
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Timing
    scheduled_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    duration_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_executions_enrollment ON automation_executions(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_executions_status ON automation_executions(status);

-- Workflow Goals
CREATE TABLE IF NOT EXISTS automation_goals (
    goal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES automation_workflows(workflow_id),
    
    -- Goal definition
    name VARCHAR(255) NOT NULL,
    goal_type VARCHAR(100) NOT NULL,
    goal_config JSONB DEFAULT '{}',
    
    -- Measurement
    target_value DECIMAL(12,2),
    current_value DECIMAL(12,2) DEFAULT 0,
    achievement_count INTEGER DEFAULT 0,
    
    -- Time window
    time_window_days INTEGER DEFAULT 30,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_goals_workflow ON automation_goals(workflow_id);

-- AI Analysis Results
CREATE TABLE IF NOT EXISTS automation_ai_analysis (
    analysis_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES automation_workflows(workflow_id),
    
    -- Analysis type
    analysis_type VARCHAR(100) NOT NULL,
    
    -- Results
    performance_score DECIMAL(5,2),
    insights JSONB DEFAULT '[]',
    recommendations JSONB DEFAULT '[]',
    anomalies JSONB DEFAULT '[]',
    predictions JSONB DEFAULT '{}',
    
    -- Metrics analyzed
    metrics_snapshot JSONB DEFAULT '{}',
    
    -- Natural language summary
    summary_text TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_analysis_workflow ON automation_ai_analysis(workflow_id);

-- Trigger Events Log
CREATE TABLE IF NOT EXISTS automation_trigger_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID,
    
    -- Trigger details
    trigger_type VARCHAR(100),
    trigger_data JSONB DEFAULT '{}',
    
    -- Result
    enrolled BOOLEAN DEFAULT false,
    enrollment_id UUID,
    skip_reason VARCHAR(255),
    
    triggered_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trigger_log_workflow ON automation_trigger_log(workflow_id);

-- Workflow Templates
CREATE TABLE IF NOT EXISTS automation_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    
    -- Template data
    trigger_type VARCHAR(100),
    trigger_config JSONB DEFAULT '{}',
    steps JSONB DEFAULT '[]',
    goals JSONB DEFAULT '[]',
    
    -- Usage
    times_used INTEGER DEFAULT 0,
    avg_performance_score DECIMAL(5,2),
    
    -- Status
    is_public BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_workflow_performance AS
SELECT 
    w.workflow_id,
    w.name,
    w.status,
    w.trigger_type,
    w.total_enrollments,
    w.total_completions,
    w.total_goals_achieved,
    ROUND(w.total_completions::DECIMAL / NULLIF(w.total_enrollments, 0) * 100, 2) as completion_rate,
    ROUND(w.total_goals_achieved::DECIMAL / NULLIF(w.total_enrollments, 0) * 100, 2) as goal_rate,
    w.ai_performance_score,
    w.activated_at,
    (SELECT COUNT(*) FROM automation_enrollments e WHERE e.workflow_id = w.workflow_id AND e.status = 'active') as active_enrollments
FROM automation_workflows w
ORDER BY w.total_enrollments DESC;

CREATE OR REPLACE VIEW v_step_performance AS
SELECT 
    s.step_id,
    s.workflow_id,
    s.step_order,
    s.action_type,
    s.executions,
    s.successes,
    s.failures,
    ROUND(s.successes::DECIMAL / NULLIF(s.executions, 0) * 100, 2) as success_rate
FROM automation_steps s
ORDER BY s.workflow_id, s.step_order;

CREATE OR REPLACE VIEW v_goal_achievement AS
SELECT 
    g.goal_id,
    g.workflow_id,
    g.name,
    g.goal_type,
    g.target_value,
    g.current_value,
    g.achievement_count,
    ROUND(g.current_value / NULLIF(g.target_value, 0) * 100, 2) as progress_pct
FROM automation_goals g;

CREATE OR REPLACE VIEW v_daily_automation_stats AS
SELECT 
    DATE(enrolled_at) as date,
    workflow_id,
    COUNT(*) as enrollments,
    COUNT(*) FILTER (WHERE goal_achieved = true) as goals,
    SUM(attributed_revenue) as revenue
FROM automation_enrollments
GROUP BY DATE(enrolled_at), workflow_id
ORDER BY date DESC;

SELECT 'Automation Control Panel schema deployed!' as status;


-- ============================================================================
-- WORKFLOW CONTROL MODES (ON/OFF/TIMER)
-- ============================================================================

-- Workflow Control State
CREATE TABLE IF NOT EXISTS workflow_control (
    control_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES automation_workflows(workflow_id),
    
    -- Control mode
    mode VARCHAR(20) NOT NULL DEFAULT 'on',
    
    -- Timer settings (when mode = 'timer')
    timer_duration_minutes INTEGER,
    timer_started_at TIMESTAMP,
    timer_expires_at TIMESTAMP,
    
    -- Auto-renewal
    auto_renew BOOLEAN DEFAULT false,
    renew_duration_minutes INTEGER,
    
    -- Override
    override_by VARCHAR(255),
    override_reason TEXT,
    
    -- History
    previous_mode VARCHAR(20),
    mode_changed_at TIMESTAMP DEFAULT NOW(),
    mode_changed_by VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workflow_control_workflow ON workflow_control(workflow_id);
CREATE INDEX IF NOT EXISTS idx_workflow_control_mode ON workflow_control(mode);
CREATE INDEX IF NOT EXISTS idx_workflow_control_expires ON workflow_control(timer_expires_at);

-- Issue Response Control (suspend AI for specific issues)
CREATE TABLE IF NOT EXISTS issue_response_control (
    control_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Issue identification
    issue_keywords JSONB NOT NULL,
    issue_name VARCHAR(255),
    
    -- Candidate scope
    candidate_id UUID,
    
    -- Control mode
    mode VARCHAR(20) NOT NULL DEFAULT 'active',
    
    -- Timer (when mode = 'timer_active')
    timer_duration_minutes INTEGER,
    timer_started_at TIMESTAMP,
    timer_expires_at TIMESTAMP,
    
    -- Suspension details
    suspended_at TIMESTAMP,
    suspended_by VARCHAR(255),
    suspension_reason TEXT,
    
    -- What to suspend
    suspend_email BOOLEAN DEFAULT true,
    suspend_sms BOOLEAN DEFAULT true,
    suspend_social BOOLEAN DEFAULT true,
    suspend_phone BOOLEAN DEFAULT true,
    suspend_ai_content BOOLEAN DEFAULT true,
    
    -- Notifications
    notify_on_expire BOOLEAN DEFAULT true,
    notify_channels JSONB DEFAULT '["slack", "email"]',
    
    -- Stats
    triggers_blocked INTEGER DEFAULT 0,
    last_blocked_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_issue_control_mode ON issue_response_control(mode);
CREATE INDEX IF NOT EXISTS idx_issue_control_expires ON issue_response_control(timer_expires_at);
CREATE INDEX IF NOT EXISTS idx_issue_control_candidate ON issue_response_control(candidate_id);

-- Control History Log
CREATE TABLE IF NOT EXISTS workflow_control_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference
    workflow_id UUID,
    issue_control_id UUID,
    
    -- Change
    action VARCHAR(50) NOT NULL,
    from_mode VARCHAR(20),
    to_mode VARCHAR(20),
    
    -- Timer info
    timer_duration_minutes INTEGER,
    timer_expires_at TIMESTAMP,
    
    -- Who/why
    changed_by VARCHAR(255),
    reason TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_control_history_workflow ON workflow_control_history(workflow_id);

-- Scheduled Control Changes
CREATE TABLE IF NOT EXISTS workflow_control_schedule (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Target
    workflow_id UUID,
    issue_control_id UUID,
    
    -- Scheduled change
    scheduled_mode VARCHAR(20) NOT NULL,
    scheduled_at TIMESTAMP NOT NULL,
    
    -- Timer settings if applicable
    timer_duration_minutes INTEGER,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending',
    executed_at TIMESTAMP,
    
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_control_schedule_time ON workflow_control_schedule(scheduled_at);

-- View for active timers
CREATE OR REPLACE VIEW v_active_timers AS
SELECT 
    'workflow' as type,
    wc.workflow_id as target_id,
    w.name as target_name,
    wc.mode,
    wc.timer_started_at,
    wc.timer_expires_at,
    wc.timer_duration_minutes,
    EXTRACT(EPOCH FROM (wc.timer_expires_at - NOW()))/60 as minutes_remaining,
    wc.mode_changed_by
FROM workflow_control wc
JOIN automation_workflows w ON wc.workflow_id = w.workflow_id
WHERE wc.mode = 'timer' AND wc.timer_expires_at > NOW()
UNION ALL
SELECT 
    'issue' as type,
    irc.control_id as target_id,
    irc.issue_name as target_name,
    irc.mode,
    irc.timer_started_at,
    irc.timer_expires_at,
    irc.timer_duration_minutes,
    EXTRACT(EPOCH FROM (irc.timer_expires_at - NOW()))/60 as minutes_remaining,
    irc.suspended_by
FROM issue_response_control irc
WHERE irc.mode = 'timer_active' AND irc.timer_expires_at > NOW()
ORDER BY minutes_remaining ASC;

-- View for expired timers needing action
CREATE OR REPLACE VIEW v_expired_timers AS
SELECT 
    'workflow' as type,
    wc.workflow_id as target_id,
    w.name as target_name,
    wc.timer_expires_at,
    wc.auto_renew,
    wc.renew_duration_minutes
FROM workflow_control wc
JOIN automation_workflows w ON wc.workflow_id = w.workflow_id
WHERE wc.mode = 'timer' AND wc.timer_expires_at <= NOW()
UNION ALL
SELECT 
    'issue' as type,
    irc.control_id as target_id,
    irc.issue_name as target_name,
    irc.timer_expires_at,
    false as auto_renew,
    null as renew_duration_minutes
FROM issue_response_control irc
WHERE irc.mode = 'timer_active' AND irc.timer_expires_at <= NOW();

SELECT 'Workflow control schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_41_campaign_builder_complete.py (E41)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 41: CAMPAIGN BUILDER
-- ============================================================================

-- Campaign Master Record
CREATE TABLE IF NOT EXISTS campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(500) NOT NULL,
    internal_name VARCHAR(255),
    description TEXT,
    
    -- Ownership
    candidate_id UUID,
    created_by VARCHAR(255),
    
    -- Type & Mode
    campaign_type VARCHAR(50) NOT NULL,
    creation_mode VARCHAR(20) NOT NULL DEFAULT 'manual',
    
    -- Dates
    start_date DATE,
    end_date DATE,
    
    -- Budget
    total_budget DECIMAL(12,2),
    spent_budget DECIMAL(12,2) DEFAULT 0,
    
    -- Channels (JSON array)
    selected_channels JSONB DEFAULT '[]',
    
    -- Audience
    audience_segments JSONB DEFAULT '[]',
    audience_filters JSONB DEFAULT '{}',
    audience_exclusions JSONB DEFAULT '[]',
    estimated_reach INTEGER,
    
    -- Content
    content_config JSONB DEFAULT '{}',
    
    -- IFTTT Automations
    attached_ifttt JSONB DEFAULT '[]',
    ifttt_config JSONB DEFAULT '{}',
    
    -- Goals
    goals JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    current_step INTEGER DEFAULT 1,
    
    -- Builder state (for saving progress)
    builder_state JSONB DEFAULT '{}',
    
    -- Stats
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    total_converted INTEGER DEFAULT 0,
    total_raised DECIMAL(12,2) DEFAULT 0,
    
    -- AI Generation (if ai_autopilot)
    ai_prompt TEXT,
    ai_generated_plan JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    launched_at TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_campaigns_candidate ON campaigns(candidate_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_type ON campaigns(campaign_type);

-- Campaign IFTTT Attachments (which automations are attached)
CREATE TABLE IF NOT EXISTS campaign_ifttt_attachments (
    attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    workflow_id UUID,
    
    -- Workflow info snapshot
    workflow_name VARCHAR(500),
    trigger_type VARCHAR(100),
    
    -- Control mode for this campaign
    mode VARCHAR(20) DEFAULT 'on',
    timer_minutes INTEGER,
    timer_expires_at TIMESTAMP,
    
    -- Customization for this campaign
    custom_trigger_config JSONB DEFAULT '{}',
    custom_actions JSONB DEFAULT '[]',
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Stats within this campaign
    times_triggered INTEGER DEFAULT 0,
    last_triggered_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ifttt_attach_campaign ON campaign_ifttt_attachments(campaign_id);

-- Campaign Channel Configuration
CREATE TABLE IF NOT EXISTS campaign_channel_config (
    config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    
    -- Channel
    channel_type VARCHAR(50) NOT NULL,
    
    -- Channel-specific config
    config JSONB DEFAULT '{}',
    
    -- Content for this channel
    content_template_id UUID,
    content_data JSONB DEFAULT '{}',
    
    -- Schedule
    send_schedule JSONB DEFAULT '{}',
    
    -- Budget allocation
    budget_allocation DECIMAL(12,2),
    
    -- Stats
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_channel_config_campaign ON campaign_channel_config(campaign_id);

-- Campaign Builder Sessions (save progress)
CREATE TABLE IF NOT EXISTS campaign_builder_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    user_id VARCHAR(255),
    
    -- Progress
    current_step INTEGER DEFAULT 1,
    step_data JSONB DEFAULT '{}',
    
    -- Validation
    steps_completed JSONB DEFAULT '[]',
    validation_errors JSONB DEFAULT '[]',
    
    last_activity_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Campaign Goals
CREATE TABLE IF NOT EXISTS campaign_goals (
    goal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    
    -- Goal definition
    goal_type VARCHAR(100) NOT NULL,
    goal_name VARCHAR(255),
    target_value DECIMAL(12,2),
    
    -- Progress
    current_value DECIMAL(12,2) DEFAULT 0,
    achieved BOOLEAN DEFAULT false,
    achieved_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_campaign_goals ON campaign_goals(campaign_id);

-- Views
CREATE OR REPLACE VIEW v_campaign_overview AS
SELECT 
    c.campaign_id,
    c.name,
    c.campaign_type,
    c.creation_mode,
    c.status,
    c.start_date,
    c.end_date,
    c.total_budget,
    c.spent_budget,
    c.estimated_reach,
    c.total_sent,
    c.total_raised,
    jsonb_array_length(c.selected_channels) as channel_count,
    jsonb_array_length(c.attached_ifttt) as ifttt_count,
    c.created_at,
    c.launched_at
FROM campaigns c
ORDER BY c.created_at DESC;

CREATE OR REPLACE VIEW v_campaign_ifttt_summary AS
SELECT 
    c.campaign_id,
    c.name as campaign_name,
    cia.workflow_name,
    cia.trigger_type,
    cia.mode,
    cia.timer_minutes,
    cia.times_triggered,
    cia.is_active
FROM campaigns c
JOIN campaign_ifttt_attachments cia ON c.campaign_id = cia.campaign_id
ORDER BY c.campaign_id, cia.workflow_name;

SELECT 'Campaign Builder schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_42_news_intelligence_complete.py (E42)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 42: NEWS INTELLIGENCE
-- ============================================================================

-- News Sources
CREATE TABLE IF NOT EXISTS news_sources (
    source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    url VARCHAR(500),
    feed_url VARCHAR(500),
    source_type VARCHAR(50),
    category VARCHAR(50),
    state VARCHAR(2),
    county VARCHAR(100),
    city VARCHAR(100),
    credibility_score DECIMAL(3,2) DEFAULT 0.7,
    bias_rating VARCHAR(20),
    reach_estimate INTEGER,
    is_active BOOLEAN DEFAULT true,
    last_checked TIMESTAMP,
    check_frequency_minutes INTEGER DEFAULT 15,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sources_state ON news_sources(state);
CREATE INDEX IF NOT EXISTS idx_sources_category ON news_sources(category);
CREATE INDEX IF NOT EXISTS idx_sources_active ON news_sources(is_active);

-- News Articles
CREATE TABLE IF NOT EXISTS news_articles (
    article_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES news_sources(source_id),
    external_id VARCHAR(255),
    url VARCHAR(1000) NOT NULL,
    url_hash VARCHAR(64) UNIQUE,
    title VARCHAR(1000) NOT NULL,
    description TEXT,
    content TEXT,
    author VARCHAR(255),
    published_at TIMESTAMP,
    discovered_at TIMESTAMP DEFAULT NOW(),
    category VARCHAR(50),
    tags JSONB DEFAULT '[]',
    image_url TEXT,
    is_breaking BOOLEAN DEFAULT false,
    is_opinion BOOLEAN DEFAULT false,
    word_count INTEGER,
    reading_time_minutes INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_articles_source ON news_articles(source_id);
CREATE INDEX IF NOT EXISTS idx_articles_published ON news_articles(published_at);
CREATE INDEX IF NOT EXISTS idx_articles_category ON news_articles(category);
CREATE INDEX IF NOT EXISTS idx_articles_url_hash ON news_articles(url_hash);

-- Candidate Mentions
CREATE TABLE IF NOT EXISTS candidate_mentions (
    mention_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID REFERENCES news_articles(article_id),
    candidate_id UUID,
    candidate_name VARCHAR(255),
    mention_count INTEGER DEFAULT 1,
    context_snippets JSONB DEFAULT '[]',
    sentiment VARCHAR(20),
    sentiment_score DECIMAL(4,3),
    is_primary_subject BOOLEAN DEFAULT false,
    tone VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mentions_article ON candidate_mentions(article_id);
CREATE INDEX IF NOT EXISTS idx_mentions_candidate ON candidate_mentions(candidate_id);
CREATE INDEX IF NOT EXISTS idx_mentions_sentiment ON candidate_mentions(sentiment);

-- Issue Mentions
CREATE TABLE IF NOT EXISTS issue_mentions (
    mention_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID REFERENCES news_articles(article_id),
    issue_id UUID,
    issue_name VARCHAR(255),
    relevance_score DECIMAL(4,3),
    context_snippet TEXT,
    position_indicated VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_issue_mentions_article ON issue_mentions(article_id);
CREATE INDEX IF NOT EXISTS idx_issue_mentions_issue ON issue_mentions(issue_id);

-- News Alerts
CREATE TABLE IF NOT EXISTS news_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    alert_level VARCHAR(20) NOT NULL,
    alert_type VARCHAR(50),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    article_ids JSONB DEFAULT '[]',
    trigger_reason TEXT,
    recommended_actions JSONB DEFAULT '[]',
    is_acknowledged BOOLEAN DEFAULT false,
    acknowledged_by VARCHAR(255),
    acknowledged_at TIMESTAMP,
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alerts_candidate ON news_alerts(candidate_id);
CREATE INDEX IF NOT EXISTS idx_alerts_level ON news_alerts(alert_level);
CREATE INDEX IF NOT EXISTS idx_alerts_acknowledged ON news_alerts(is_acknowledged);

-- Watch Lists (keywords, opponents, topics to monitor)
CREATE TABLE IF NOT EXISTS news_watch_lists (
    watch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    watch_type VARCHAR(50) NOT NULL,
    term VARCHAR(255) NOT NULL,
    is_opponent BOOLEAN DEFAULT false,
    alert_level VARCHAR(20) DEFAULT 'medium',
    is_active BOOLEAN DEFAULT true,
    match_count INTEGER DEFAULT 0,
    last_match TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_watch_candidate ON news_watch_lists(candidate_id);
CREATE INDEX IF NOT EXISTS idx_watch_type ON news_watch_lists(watch_type);

-- News Summaries (AI-generated)
CREATE TABLE IF NOT EXISTS news_summaries (
    summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    summary_type VARCHAR(50),
    period_start TIMESTAMP,
    period_end TIMESTAMP,
    summary_text TEXT,
    key_stories JSONB DEFAULT '[]',
    sentiment_overview JSONB DEFAULT '{}',
    recommendations JSONB DEFAULT '[]',
    article_count INTEGER,
    generated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_summaries_candidate ON news_summaries(candidate_id);

-- Geographic News Tracking
CREATE TABLE IF NOT EXISTS geo_news_tracking (
    tracking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state VARCHAR(2),
    county VARCHAR(100),
    city VARCHAR(100),
    article_id UUID REFERENCES news_articles(article_id),
    relevance_score DECIMAL(4,3),
    local_impact VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_geo_state ON geo_news_tracking(state);
CREATE INDEX IF NOT EXISTS idx_geo_county ON geo_news_tracking(county);

-- Views
CREATE OR REPLACE VIEW v_recent_mentions AS
SELECT 
    cm.candidate_id,
    cm.candidate_name,
    COUNT(*) as mention_count,
    COUNT(*) FILTER (WHERE cm.sentiment = 'positive') as positive,
    COUNT(*) FILTER (WHERE cm.sentiment = 'negative') as negative,
    COUNT(*) FILTER (WHERE cm.sentiment = 'neutral') as neutral,
    AVG(cm.sentiment_score) as avg_sentiment
FROM candidate_mentions cm
JOIN news_articles na ON cm.article_id = na.article_id
WHERE na.published_at >= NOW() - INTERVAL '24 hours'
GROUP BY cm.candidate_id, cm.candidate_name;

CREATE OR REPLACE VIEW v_trending_issues AS
SELECT 
    im.issue_name,
    COUNT(*) as mention_count,
    AVG(im.relevance_score) as avg_relevance,
    COUNT(*) FILTER (WHERE na.published_at >= NOW() - INTERVAL '1 hour') as last_hour
FROM issue_mentions im
JOIN news_articles na ON im.article_id = na.article_id
WHERE na.published_at >= NOW() - INTERVAL '24 hours'
GROUP BY im.issue_name
ORDER BY last_hour DESC, mention_count DESC;

CREATE OR REPLACE VIEW v_active_alerts AS
SELECT 
    na.*,
    COUNT(cm.mention_id) as related_mentions
FROM news_alerts na
LEFT JOIN candidate_mentions cm ON cm.candidate_id = na.candidate_id
WHERE na.is_resolved = false
GROUP BY na.alert_id
ORDER BY 
    CASE na.alert_level 
        WHEN 'crisis' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        ELSE 4 
    END,
    na.created_at DESC;

CREATE OR REPLACE VIEW v_source_performance AS
SELECT 
    ns.source_id,
    ns.name,
    ns.state,
    ns.credibility_score,
    COUNT(na.article_id) as articles_30d,
    COUNT(cm.mention_id) as mentions_generated
FROM news_sources ns
LEFT JOIN news_articles na ON ns.source_id = na.source_id 
    AND na.published_at >= NOW() - INTERVAL '30 days'
LEFT JOIN candidate_mentions cm ON na.article_id = cm.article_id
GROUP BY ns.source_id, ns.name, ns.state, ns.credibility_score;

SELECT 'News Intelligence schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_43_advocacy_tools_complete.py (E43)
-- ================================================================

-- Petitions
CREATE TABLE IF NOT EXISTS advocacy_petitions (
    petition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID, title VARCHAR(500) NOT NULL, slug VARCHAR(255) UNIQUE,
    description TEXT, target_description TEXT, goal_signatures INTEGER,
    current_signatures INTEGER DEFAULT 0, image_url TEXT,
    status VARCHAR(50) DEFAULT 'draft', start_date DATE, end_date DATE,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_petition_status ON advocacy_petitions(status);

-- Petition Signatures
CREATE TABLE IF NOT EXISTS petition_signatures (
    signature_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    petition_id UUID REFERENCES advocacy_petitions(petition_id),
    contact_id UUID, first_name VARCHAR(100), last_name VARCHAR(100),
    email VARCHAR(255), zip_code VARCHAR(20), city VARCHAR(100), state VARCHAR(50),
    comment TEXT, is_public BOOLEAN DEFAULT true,
    source VARCHAR(100), utm_source VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sig_petition ON petition_signatures(petition_id);

-- Action Alerts
CREATE TABLE IF NOT EXISTS action_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID, title VARCHAR(500) NOT NULL, slug VARCHAR(255),
    description TEXT, call_to_action TEXT, urgency VARCHAR(20) DEFAULT 'normal',
    action_type VARCHAR(100), target_type VARCHAR(100),
    target_info JSONB DEFAULT '{}', script_template TEXT,
    status VARCHAR(50) DEFAULT 'draft', start_date TIMESTAMP, end_date TIMESTAMP,
    total_actions INTEGER DEFAULT 0, created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_alert_status ON action_alerts(status);

-- Actions Taken
CREATE TABLE IF NOT EXISTS advocacy_actions (
    action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_id UUID REFERENCES action_alerts(alert_id),
    contact_id UUID, first_name VARCHAR(100), last_name VARCHAR(100),
    email VARCHAR(255), phone VARCHAR(50), zip_code VARCHAR(20),
    action_type VARCHAR(100), target_contacted VARCHAR(255),
    message_sent TEXT, outcome VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_action_alert ON advocacy_actions(alert_id);

-- Letter Campaigns
CREATE TABLE IF NOT EXISTS letter_campaigns (
    letter_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID, title VARCHAR(500) NOT NULL, description TEXT,
    recipient_type VARCHAR(100), recipient_lookup_method VARCHAR(100),
    letter_template TEXT, subject_line VARCHAR(500),
    delivery_method VARCHAR(50) DEFAULT 'email',
    status VARCHAR(50) DEFAULT 'draft', letters_sent INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Letters Sent
CREATE TABLE IF NOT EXISTS letters_sent (
    sent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    letter_id UUID REFERENCES letter_campaigns(letter_id),
    contact_id UUID, sender_name VARCHAR(255), sender_email VARCHAR(255),
    sender_zip VARCHAR(20), recipient_name VARCHAR(255), recipient_email VARCHAR(255),
    customized_message TEXT, sent_at TIMESTAMP DEFAULT NOW()
);

-- Voter Registration Drives
CREATE TABLE IF NOT EXISTS voter_reg_drives (
    drive_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID, name VARCHAR(255) NOT NULL, description TEXT,
    target_county VARCHAR(100), target_zip_codes JSONB DEFAULT '[]',
    goal_registrations INTEGER, actual_registrations INTEGER DEFAULT 0,
    start_date DATE, end_date DATE, status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Voter Registrations
CREATE TABLE IF NOT EXISTS voter_registrations (
    reg_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drive_id UUID REFERENCES voter_reg_drives(drive_id),
    contact_id UUID, first_name VARCHAR(100), last_name VARCHAR(100),
    email VARCHAR(255), phone VARCHAR(50), address VARCHAR(255),
    city VARCHAR(100), state VARCHAR(50), zip_code VARCHAR(20),
    date_of_birth DATE, party_affiliation VARCHAR(50),
    registration_status VARCHAR(50) DEFAULT 'pending',
    registered_by VARCHAR(255), created_at TIMESTAMP DEFAULT NOW()
);

-- Pledge Campaigns
CREATE TABLE IF NOT EXISTS pledge_campaigns (
    pledge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID, title VARCHAR(500) NOT NULL, description TEXT,
    pledge_text TEXT NOT NULL, goal_pledges INTEGER,
    current_pledges INTEGER DEFAULT 0, status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Pledges Made
CREATE TABLE IF NOT EXISTS pledges_made (
    made_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pledge_id UUID REFERENCES pledge_campaigns(pledge_id),
    contact_id UUID, name VARCHAR(255), email VARCHAR(255), zip_code VARCHAR(20),
    shared BOOLEAN DEFAULT false, created_at TIMESTAMP DEFAULT NOW()
);

-- Views
CREATE OR REPLACE VIEW v_petition_summary AS
SELECT p.petition_id, p.title, p.goal_signatures, p.current_signatures,
    CASE WHEN p.goal_signatures > 0 THEN ROUND((p.current_signatures::numeric / p.goal_signatures) * 100, 1) ELSE 0 END as pct_of_goal,
    p.status, p.created_at
FROM advocacy_petitions p ORDER BY p.created_at DESC;

SELECT 'Advocacy Tools deployed!' as status;


-- ================================================================
-- FROM: ecosystem_44_vendor_compliance_security_complete.py (E44)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 44: VENDOR COMPLIANCE & SECURITY
-- ============================================================================

-- Vendor Registry with compliance status
CREATE TABLE IF NOT EXISTS vendor_registry (
    vendor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(500) NOT NULL,
    vendor_type VARCHAR(100),
    
    -- Contact
    primary_contact VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address TEXT,
    
    -- Compliance certifications
    soc2_type1_certified BOOLEAN DEFAULT false,
    soc2_type1_date DATE,
    soc2_type1_report_url TEXT,
    soc2_type2_certified BOOLEAN DEFAULT false,
    soc2_type2_date DATE,
    soc2_type2_report_url TEXT,
    hipaa_compliant BOOLEAN DEFAULT false,
    pci_compliant BOOLEAN DEFAULT false,
    
    -- Security posture
    data_encryption_at_rest BOOLEAN DEFAULT false,
    data_encryption_in_transit BOOLEAN DEFAULT true,
    mfa_required BOOLEAN DEFAULT false,
    background_checks BOOLEAN DEFAULT false,
    physical_security_audit BOOLEAN DEFAULT false,
    
    -- Contract
    contract_start_date DATE,
    contract_end_date DATE,
    data_processing_agreement BOOLEAN DEFAULT false,
    nda_signed BOOLEAN DEFAULT false,
    
    -- Status
    compliance_status VARCHAR(50) DEFAULT 'pending_review',
    last_audit_date DATE,
    next_audit_date DATE,
    risk_score INTEGER DEFAULT 50,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_status ON vendor_registry(compliance_status);
CREATE INDEX IF NOT EXISTS idx_vendor_type ON vendor_registry(vendor_type);

-- Vendor Security Assessments
CREATE TABLE IF NOT EXISTS vendor_assessments (
    assessment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID REFERENCES vendor_registry(vendor_id),
    assessment_type VARCHAR(100) NOT NULL,
    assessor VARCHAR(255),
    
    -- Assessment details
    questionnaire_responses JSONB DEFAULT '{}',
    findings JSONB DEFAULT '[]',
    risk_items JSONB DEFAULT '[]',
    
    -- Scores
    overall_score INTEGER,
    technical_score INTEGER,
    administrative_score INTEGER,
    physical_score INTEGER,
    
    -- Status
    status VARCHAR(50) DEFAULT 'in_progress',
    remediation_required BOOLEAN DEFAULT false,
    remediation_deadline DATE,
    
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assessments_vendor ON vendor_assessments(vendor_id);

-- Data Access Audit Log
CREATE TABLE IF NOT EXISTS data_access_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Who
    user_id UUID,
    user_email VARCHAR(255),
    user_role VARCHAR(100),
    vendor_id UUID,
    
    -- What
    action_type VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id UUID,
    data_classification VARCHAR(50),
    
    -- Details
    records_accessed INTEGER,
    fields_accessed JSONB DEFAULT '[]',
    query_hash VARCHAR(64),
    
    -- Context
    ip_address VARCHAR(45),
    user_agent TEXT,
    session_id VARCHAR(100),
    
    -- Result
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_access_log_user ON data_access_log(user_id);
CREATE INDEX IF NOT EXISTS idx_access_log_vendor ON data_access_log(vendor_id);
CREATE INDEX IF NOT EXISTS idx_access_log_time ON data_access_log(created_at);
CREATE INDEX IF NOT EXISTS idx_access_log_resource ON data_access_log(resource_type, resource_id);

-- File Transfer Log
CREATE TABLE IF NOT EXISTS file_transfer_log (
    transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Transfer details
    direction VARCHAR(20) NOT NULL,  -- 'outbound', 'inbound'
    source_system VARCHAR(100),
    destination_system VARCHAR(100),
    destination_vendor_id UUID,
    
    -- File details
    file_name VARCHAR(500),
    file_hash_sha256 VARCHAR(64),
    file_size_bytes BIGINT,
    record_count INTEGER,
    
    -- Data classification
    data_classification VARCHAR(50),
    contains_pii BOOLEAN DEFAULT false,
    contains_financial BOOLEAN DEFAULT false,
    
    -- Security
    encrypted BOOLEAN DEFAULT true,
    encryption_method VARCHAR(100),
    transfer_protocol VARCHAR(50),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    delivered_at TIMESTAMP,
    acknowledged_at TIMESTAMP,
    
    -- Related job
    job_type VARCHAR(100),
    job_id UUID,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transfer_vendor ON file_transfer_log(destination_vendor_id);
CREATE INDEX IF NOT EXISTS idx_transfer_time ON file_transfer_log(created_at);
CREATE INDEX IF NOT EXISTS idx_transfer_job ON file_transfer_log(job_id);

-- Print Job Chain of Custody
CREATE TABLE IF NOT EXISTS print_chain_of_custody (
    custody_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL,
    
    -- Stage
    custody_stage VARCHAR(100) NOT NULL,
    sequence_order INTEGER,
    
    -- Handler
    handler_type VARCHAR(50),  -- 'system', 'vendor', 'usps'
    handler_name VARCHAR(255),
    handler_id UUID,
    
    -- Piece counts
    pieces_received INTEGER,
    pieces_processed INTEGER,
    pieces_transferred INTEGER,
    pieces_spoiled INTEGER DEFAULT 0,
    
    -- Verification
    verification_method VARCHAR(100),
    verification_data JSONB DEFAULT '{}',
    
    -- Timestamps
    received_at TIMESTAMP,
    processed_at TIMESTAMP,
    transferred_at TIMESTAMP,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_custody_job ON print_chain_of_custody(job_id);

-- Security Incidents
CREATE TABLE IF NOT EXISTS security_incidents (
    incident_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_number VARCHAR(50) UNIQUE,
    
    -- Classification
    severity VARCHAR(20) NOT NULL,
    incident_type VARCHAR(100) NOT NULL,
    
    -- Affected
    affected_vendor_id UUID,
    affected_job_ids JSONB DEFAULT '[]',
    affected_records_count INTEGER,
    data_classification VARCHAR(50),
    
    -- Description
    title VARCHAR(500) NOT NULL,
    description TEXT,
    root_cause TEXT,
    
    -- Timeline
    detected_at TIMESTAMP DEFAULT NOW(),
    reported_at TIMESTAMP,
    contained_at TIMESTAMP,
    resolved_at TIMESTAMP,
    
    -- Response
    response_actions JSONB DEFAULT '[]',
    notification_required BOOLEAN DEFAULT false,
    notifications_sent JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(50) DEFAULT 'open',
    assigned_to VARCHAR(255),
    
    -- Post-mortem
    lessons_learned TEXT,
    preventive_measures JSONB DEFAULT '[]',
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_incidents_severity ON security_incidents(severity);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON security_incidents(status);

-- Compliance Monitoring Rules
CREATE TABLE IF NOT EXISTS compliance_rules (
    rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Scope
    applies_to VARCHAR(100),  -- 'vendor', 'data_transfer', 'access'
    framework VARCHAR(50),
    
    -- Rule definition
    rule_type VARCHAR(50),
    conditions JSONB DEFAULT '{}',
    
    -- Actions
    alert_on_violation BOOLEAN DEFAULT true,
    block_on_violation BOOLEAN DEFAULT false,
    auto_remediate BOOLEAN DEFAULT false,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Compliance Violations
CREATE TABLE IF NOT EXISTS compliance_violations (
    violation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID REFERENCES compliance_rules(rule_id),
    
    -- Details
    violation_type VARCHAR(100),
    severity VARCHAR(20),
    description TEXT,
    
    -- Context
    vendor_id UUID,
    job_id UUID,
    user_id UUID,
    
    -- Evidence
    evidence JSONB DEFAULT '{}',
    
    -- Resolution
    status VARCHAR(50) DEFAULT 'open',
    resolved_at TIMESTAMP,
    resolution_notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_violations_status ON compliance_violations(status);

-- Encryption Key Management
CREATE TABLE IF NOT EXISTS encryption_keys (
    key_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key_name VARCHAR(255) NOT NULL,
    key_type VARCHAR(50) NOT NULL,
    
    -- Key material (encrypted)
    encrypted_key_material TEXT,
    key_version INTEGER DEFAULT 1,
    
    -- Usage
    purpose VARCHAR(100),
    allowed_operations JSONB DEFAULT '["encrypt", "decrypt"]',
    
    -- Lifecycle
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    rotated_at TIMESTAMP,
    retired_at TIMESTAMP,
    
    -- Status
    is_active BOOLEAN DEFAULT true
);

-- Views
CREATE OR REPLACE VIEW v_vendor_compliance_summary AS
SELECT 
    v.vendor_id,
    v.name,
    v.vendor_type,
    v.compliance_status,
    v.soc2_type2_certified,
    v.risk_score,
    v.last_audit_date,
    v.next_audit_date,
    COUNT(DISTINCT ft.transfer_id) as file_transfers_30d,
    COUNT(DISTINCT si.incident_id) as incidents_90d
FROM vendor_registry v
LEFT JOIN file_transfer_log ft ON v.vendor_id = ft.destination_vendor_id 
    AND ft.created_at >= NOW() - INTERVAL '30 days'
LEFT JOIN security_incidents si ON v.vendor_id = si.affected_vendor_id
    AND si.created_at >= NOW() - INTERVAL '90 days'
GROUP BY v.vendor_id;

CREATE OR REPLACE VIEW v_compliance_dashboard AS
SELECT 
    (SELECT COUNT(*) FROM vendor_registry WHERE compliance_status = 'approved') as approved_vendors,
    (SELECT COUNT(*) FROM vendor_registry WHERE compliance_status = 'pending_review') as pending_vendors,
    (SELECT COUNT(*) FROM security_incidents WHERE status = 'open') as open_incidents,
    (SELECT COUNT(*) FROM security_incidents WHERE severity = 'critical' AND status = 'open') as critical_incidents,
    (SELECT COUNT(*) FROM compliance_violations WHERE status = 'open') as open_violations,
    (SELECT COUNT(*) FROM file_transfer_log WHERE created_at >= NOW() - INTERVAL '24 hours') as transfers_24h;

CREATE OR REPLACE VIEW v_data_access_audit AS
SELECT 
    dal.log_id,
    dal.user_email,
    dal.action_type,
    dal.resource_type,
    dal.data_classification,
    dal.records_accessed,
    dal.success,
    dal.created_at,
    v.name as vendor_name
FROM data_access_log dal
LEFT JOIN vendor_registry v ON dal.vendor_id = v.vendor_id
ORDER BY dal.created_at DESC;

SELECT 'Vendor Compliance & Security schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_45_video_studio_complete.py (E45)
-- ================================================================

-- ============================================================================
-- ECOSYSTEM 45: VIDEO STUDIO SCHEMA
-- ============================================================================

-- Virtual backgrounds library
CREATE TABLE IF NOT EXISTS e45_virtual_backgrounds (
    background_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    image_url TEXT,
    video_url TEXT,
    is_video BOOLEAN DEFAULT false,
    blur_strength INTEGER DEFAULT 0,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Teleprompter scripts
CREATE TABLE IF NOT EXISTS e45_teleprompter_scripts (
    script_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    source_type VARCHAR(50),
    source_ecosystem VARCHAR(50),
    source_id UUID,
    estimated_duration_seconds INTEGER,
    words_per_minute INTEGER DEFAULT 150,
    cue_points JSONB DEFAULT '[]',
    category VARCHAR(100),
    tags JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMP,
    use_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Recording sessions
CREATE TABLE IF NOT EXISTS e45_recording_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    session_type VARCHAR(50),
    purpose VARCHAR(100),
    script_id UUID REFERENCES e45_teleprompter_scripts(script_id),
    background_id UUID REFERENCES e45_virtual_backgrounds(background_id),
    video_settings JSONB DEFAULT '{}',
    audio_settings JSONB DEFAULT '{}',
    scene_settings JSONB DEFAULT '{}',
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    raw_video_url TEXT,
    processed_video_url TEXT,
    audio_only_url TEXT,
    thumbnail_url TEXT,
    video_quality VARCHAR(20),
    audio_quality_score DECIMAL(5,2),
    status VARCHAR(50) DEFAULT 'draft',
    exported_to JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Recording takes
CREATE TABLE IF NOT EXISTS e45_recording_takes (
    take_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES e45_recording_sessions(session_id),
    take_number INTEGER NOT NULL,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    video_url TEXT,
    audio_url TEXT,
    audio_levels JSONB,
    video_analysis JSONB,
    speech_clarity_score DECIMAL(5,2),
    eye_contact_score DECIMAL(5,2),
    energy_score DECIMAL(5,2),
    is_selected BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Zoom meetings
CREATE TABLE IF NOT EXISTS e45_zoom_meetings (
    meeting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    zoom_meeting_id VARCHAR(100),
    zoom_meeting_uuid VARCHAR(255),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    agenda TEXT,
    meeting_type VARCHAR(50),
    scheduled_start TIMESTAMP,
    scheduled_end TIMESTAMP,
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    is_webinar BOOLEAN DEFAULT false,
    requires_registration BOOLEAN DEFAULT true,
    waiting_room_enabled BOOLEAN DEFAULT true,
    recording_enabled BOOLEAN DEFAULT true,
    join_url TEXT,
    registration_url TEXT,
    host_key VARCHAR(20),
    background_id UUID REFERENCES e45_virtual_backgrounds(background_id),
    actual_start TIMESTAMP,
    actual_end TIMESTAMP,
    actual_duration_minutes INTEGER,
    registrants_count INTEGER DEFAULT 0,
    attendees_count INTEGER DEFAULT 0,
    peak_attendees INTEGER DEFAULT 0,
    recording_url TEXT,
    recording_passcode VARCHAR(50),
    transcript_url TEXT,
    engagement_score DECIMAL(5,2),
    questions_asked INTEGER DEFAULT 0,
    polls_conducted INTEGER DEFAULT 0,
    chat_messages INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'scheduled',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Zoom registrants
CREATE TABLE IF NOT EXISTS e45_zoom_registrants (
    registrant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID REFERENCES e45_zoom_meetings(meeting_id),
    zoom_registrant_id VARCHAR(100),
    donor_id UUID REFERENCES donors(donor_id),
    email VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    registered_at TIMESTAMP DEFAULT NOW(),
    join_url TEXT,
    attended BOOLEAN DEFAULT false,
    joined_at TIMESTAMP,
    left_at TIMESTAMP,
    duration_minutes INTEGER,
    questions_asked INTEGER DEFAULT 0,
    polls_answered INTEGER DEFAULT 0,
    chat_messages INTEGER DEFAULT 0,
    follow_up_sent BOOLEAN DEFAULT false,
    follow_up_sent_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Enhancement presets
CREATE TABLE IF NOT EXISTS e45_enhancement_presets (
    preset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    video_settings JSONB DEFAULT '{}',
    audio_settings JSONB DEFAULT '{}',
    scene_settings JSONB DEFAULT '{}',
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Content exports
CREATE TABLE IF NOT EXISTS e45_content_exports (
    export_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type VARCHAR(50),
    source_id UUID,
    target_ecosystem VARCHAR(10) NOT NULL,
    target_type VARCHAR(50),
    target_id UUID,
    processing_applied JSONB DEFAULT '[]',
    output_format VARCHAR(20),
    output_url TEXT,
    exported_at TIMESTAMP DEFAULT NOW(),
    exported_by UUID
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_e45_recordings_candidate ON e45_recording_sessions(candidate_id);
CREATE INDEX IF NOT EXISTS idx_e45_recordings_status ON e45_recording_sessions(status);
CREATE INDEX IF NOT EXISTS idx_e45_zoom_scheduled ON e45_zoom_meetings(scheduled_start);
CREATE INDEX IF NOT EXISTS idx_e45_zoom_candidate ON e45_zoom_meetings(candidate_id);
CREATE INDEX IF NOT EXISTS idx_e45_registrants_meeting ON e45_zoom_registrants(meeting_id);
CREATE INDEX IF NOT EXISTS idx_e45_registrants_email ON e45_zoom_registrants(email);

SELECT 'E45 Video Studio schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_46_broadcast_hub_complete.py (E46)
-- ================================================================

-- ================================================================
-- FROM: ecosystem_47_ai_script_generator_complete.py (E47)
-- ================================================================

-- ================================================================
-- FROM: ecosystem_48_communication_dna_complete.py (E48)
-- ================================================================

-- ================================================================
-- FROM: ecosystem_49_interview_system_complete.py (E49)
-- ================================================================

-- ================================================================
-- FROM: ecosystem_demo_controller_complete.py (E)
-- ================================================================

-- Demo Controller Schema
CREATE TABLE IF NOT EXISTS demo_executions (
    execution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    demo_name VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    duration_seconds DECIMAL(10,2),
    recording_file TEXT,
    steps JSONB DEFAULT '[]',
    status VARCHAR(50) DEFAULT 'running'
);

CREATE TABLE IF NOT EXISTS demo_analytics (
    analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id UUID REFERENCES demo_executions(execution_id),
    viewer_id VARCHAR(255),
    watched_duration_seconds INTEGER,
    completion_rate DECIMAL(5,2),
    feedback_rating INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

SELECT 'Demo Controller schema deployed!' as status;


-- ================================================================
-- FROM: ecosystem_demo_video_production_complete.py (E)
-- ================================================================

-- ============================================================================
-- DEMO ECOSYSTEM: AI VIDEO PRODUCTION PLATFORM
-- ============================================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS demo_ecosystem;

-- Screenplays (video scripts)
CREATE TABLE IF NOT EXISTS demo_ecosystem.screenplays (
    screenplay_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    title VARCHAR(500) NOT NULL,
    screenplay_type VARCHAR(50) NOT NULL,
    tone VARCHAR(50) DEFAULT 'conversational',
    target_audience VARCHAR(255),
    duration_seconds INTEGER,
    script_text TEXT,
    talking_points JSONB DEFAULT '[]',
    call_to_action TEXT,
    messaging_framework VARCHAR(100),
    hot_issues JSONB DEFAULT '[]',
    personalization_vars JSONB DEFAULT '[]',
    status VARCHAR(50) DEFAULT 'draft',
    version INTEGER DEFAULT 1,
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_screenplays_candidate ON demo_ecosystem.screenplays(candidate_id);
CREATE INDEX IF NOT EXISTS idx_screenplays_type ON demo_ecosystem.screenplays(screenplay_type);

-- Screenplay Elements (scenes, shots)
CREATE TABLE IF NOT EXISTS demo_ecosystem.screenplay_elements (
    element_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    screenplay_id UUID REFERENCES demo_ecosystem.screenplays(screenplay_id),
    element_type VARCHAR(50) NOT NULL,
    sequence_order INTEGER NOT NULL,
    content TEXT,
    duration_seconds INTEGER,
    avatar_id UUID,
    voice_id UUID,
    background_url TEXT,
    music_track VARCHAR(255),
    motion_effect VARCHAR(100),
    transition_type VARCHAR(50),
    overlay_text TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_elements_screenplay ON demo_ecosystem.screenplay_elements(screenplay_id);

-- Avatars Library
CREATE TABLE IF NOT EXISTS demo_ecosystem.avatar_library (
    avatar_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    provider_avatar_id VARCHAR(255),
    gender VARCHAR(20),
    ethnicity VARCHAR(50),
    age_range VARCHAR(20),
    style VARCHAR(50),
    thumbnail_url TEXT,
    preview_url TEXT,
    is_custom BOOLEAN DEFAULT false,
    candidate_id UUID,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_avatars_provider ON demo_ecosystem.avatar_library(provider);

-- Voice Library
CREATE TABLE IF NOT EXISTS demo_ecosystem.voice_library (
    voice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    provider_voice_id VARCHAR(255),
    gender VARCHAR(20),
    accent VARCHAR(50),
    style VARCHAR(50),
    sample_url TEXT,
    is_cloned BOOLEAN DEFAULT false,
    source_audio_url TEXT,
    candidate_id UUID,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_voices_provider ON demo_ecosystem.voice_library(provider);

-- Rendering Jobs
CREATE TABLE IF NOT EXISTS demo_ecosystem.rendering_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    screenplay_id UUID REFERENCES demo_ecosystem.screenplays(screenplay_id),
    candidate_id UUID,
    provider VARCHAR(50) NOT NULL,
    provider_job_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending',
    progress_pct INTEGER DEFAULT 0,
    input_params JSONB DEFAULT '{}',
    output_url TEXT,
    thumbnail_url TEXT,
    duration_seconds INTEGER,
    file_size_bytes BIGINT,
    cost_cents INTEGER,
    error_message TEXT,
    webhook_received BOOLEAN DEFAULT false,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON demo_ecosystem.rendering_jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_screenplay ON demo_ecosystem.rendering_jobs(screenplay_id);

-- Demo Sessions (personalized viewing)
CREATE TABLE IF NOT EXISTS demo_ecosystem.demo_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID,
    screenplay_id UUID REFERENCES demo_ecosystem.screenplays(screenplay_id),
    job_id UUID REFERENCES demo_ecosystem.rendering_jobs(job_id),
    personalization_data JSONB DEFAULT '{}',
    access_token VARCHAR(100) UNIQUE,
    expires_at TIMESTAMP,
    view_count INTEGER DEFAULT 0,
    last_viewed_at TIMESTAMP,
    total_watch_time_seconds INTEGER DEFAULT 0,
    completion_rate DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_contact ON demo_ecosystem.demo_sessions(contact_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON demo_ecosystem.demo_sessions(access_token);

-- Demo Analytics
CREATE TABLE IF NOT EXISTS demo_ecosystem.demo_analytics (
    analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES demo_ecosystem.demo_sessions(session_id),
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB DEFAULT '{}',
    timestamp_seconds DECIMAL(10,2),
    client_info JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analytics_session ON demo_ecosystem.demo_analytics(session_id);
CREATE INDEX IF NOT EXISTS idx_analytics_event ON demo_ecosystem.demo_analytics(event_type);

-- Reference Tables
CREATE TABLE IF NOT EXISTS demo_ecosystem.tones (
    tone_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    example_phrases JSONB DEFAULT '[]'
);

INSERT INTO demo_ecosystem.tones (name, description) VALUES
    ('inspiring', 'Uplifting and motivational'),
    ('urgent', 'Time-sensitive, action-oriented'),
    ('conversational', 'Friendly and approachable'),
    ('formal', 'Professional and authoritative'),
    ('aggressive', 'Strong attack messaging'),
    ('emotional', 'Heart-felt, personal stories'),
    ('factual', 'Data-driven, evidence-based'),
    ('humorous', 'Light-hearted with humor')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS demo_ecosystem.messaging_frameworks (
    framework_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    structure JSONB DEFAULT '[]'
);

INSERT INTO demo_ecosystem.messaging_frameworks (name, description) VALUES
    ('problem_solution', 'Problem → Solution → Call to Action'),
    ('story_arc', 'Setup → Conflict → Resolution'),
    ('contrast', 'Us vs Them comparison'),
    ('testimonial', 'Personal story and endorsement'),
    ('data_driven', 'Statistics and evidence'),
    ('emotional_appeal', 'Connect through feelings')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS demo_ecosystem.hot_issues (
    issue_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    category VARCHAR(50),
    talking_points JSONB DEFAULT '[]'
);

INSERT INTO demo_ecosystem.hot_issues (name, category) VALUES
    ('inflation', 'economy'),
    ('immigration', 'border'),
    ('crime', 'public_safety'),
    ('education', 'social'),
    ('healthcare', 'social'),
    ('taxes', 'economy'),
    ('jobs', 'economy'),
    ('guns', 'rights'),
    ('abortion', 'social'),
    ('climate', 'environment'),
    ('election_integrity', 'governance'),
    ('veterans', 'military'),
    ('infrastructure', 'economy'),
    ('energy', 'economy'),
    ('religious_liberty', 'rights')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS demo_ecosystem.motion_effects (
    effect_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    provider_support JSONB DEFAULT '[]'
);

INSERT INTO demo_ecosystem.motion_effects (name, description) VALUES
    ('zoom_in', 'Gradual zoom into subject'),
    ('zoom_out', 'Gradual zoom out'),
    ('pan_left', 'Camera pans left'),
    ('pan_right', 'Camera pans right'),
    ('fade_in', 'Fade from black'),
    ('fade_out', 'Fade to black'),
    ('slide_left', 'Slide transition left'),
    ('slide_right', 'Slide transition right'),
    ('dissolve', 'Cross dissolve'),
    ('none', 'No motion effect')
ON CONFLICT DO NOTHING;

-- API Logs
CREATE TABLE IF NOT EXISTS demo_ecosystem.api_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider VARCHAR(50),
    endpoint VARCHAR(255),
    method VARCHAR(10),
    request_body JSONB,
    response_status INTEGER,
    response_body JSONB,
    duration_ms INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_api_logs_provider ON demo_ecosystem.api_logs(provider);

-- Webhook Logs
CREATE TABLE IF NOT EXISTS demo_ecosystem.webhook_logs (
    webhook_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider VARCHAR(50),
    event_type VARCHAR(100),
    payload JSONB,
    processed BOOLEAN DEFAULT false,
    job_id UUID,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webhook_provider ON demo_ecosystem.webhook_logs(provider);

-- Views
CREATE OR REPLACE VIEW demo_ecosystem.v_screenplay_summary AS
SELECT 
    s.screenplay_id,
    s.title,
    s.screenplay_type,
    s.tone,
    s.status,
    s.duration_seconds,
    COUNT(e.element_id) as element_count,
    COUNT(rj.job_id) as render_count,
    MAX(rj.completed_at) as last_rendered
FROM demo_ecosystem.screenplays s
LEFT JOIN demo_ecosystem.screenplay_elements e ON s.screenplay_id = e.screenplay_id
LEFT JOIN demo_ecosystem.rendering_jobs rj ON s.screenplay_id = rj.screenplay_id
GROUP BY s.screenplay_id;

CREATE OR REPLACE VIEW demo_ecosystem.v_rendering_stats AS
SELECT 
    provider,
    COUNT(*) as total_jobs,
    COUNT(*) FILTER (WHERE status = 'completed') as completed,
    COUNT(*) FILTER (WHERE status = 'failed') as failed,
    AVG(cost_cents) as avg_cost_cents,
    AVG(EXTRACT(EPOCH FROM (completed_at - started_at))) as avg_render_seconds
FROM demo_ecosystem.rendering_jobs
GROUP BY provider;

CREATE OR REPLACE VIEW demo_ecosystem.v_demo_engagement AS
SELECT 
    ds.session_id,
    ds.contact_id,
    s.title as screenplay_title,
    ds.view_count,
    ds.total_watch_time_seconds,
    ds.completion_rate,
    COUNT(da.analytics_id) as event_count
FROM demo_ecosystem.demo_sessions ds
JOIN demo_ecosystem.screenplays s ON ds.screenplay_id = s.screenplay_id
LEFT JOIN demo_ecosystem.demo_analytics da ON ds.session_id = da.session_id
GROUP BY ds.session_id, ds.contact_id, s.title, ds.view_count, 
         ds.total_watch_time_seconds, ds.completion_rate;

SELECT 'Demo Ecosystem schema deployed!' as status;

