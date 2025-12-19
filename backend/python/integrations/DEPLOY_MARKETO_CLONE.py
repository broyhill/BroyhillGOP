#!/usr/bin/env python3
"""
============================================================================
MARKETO CLONE DEPLOYMENT SCRIPT
============================================================================

Deploys E30 Email Marketing + E31 SMS/MMS Marketing systems

Usage:
    python DEPLOY_MARKETO_CLONE.py              # Deploy all
    python DEPLOY_MARKETO_CLONE.py --test       # Test connections only
    python DEPLOY_MARKETO_CLONE.py --e30-only   # Email only
    python DEPLOY_MARKETO_CLONE.py --e31-only   # SMS only
    python DEPLOY_MARKETO_CLONE.py --status     # Check deployment status

============================================================================
"""

import os
import sys
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

# Configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")

# ============================================================================
# E30 EMAIL MARKETING SCHEMA
# ============================================================================

E30_EMAIL_SCHEMA = """
-- ============================================================================
-- ECOSYSTEM 30: EMAIL MARKETING SYSTEM
-- ============================================================================

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
    recipient_id UUID,
    variant_id VARCHAR(100),
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

-- Email Opens
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

-- Email Clicks
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

-- A/B Tests (UNLIMITED VARIANTS)
CREATE TABLE IF NOT EXISTS email_ab_tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES email_campaigns(campaign_id),
    name VARCHAR(255),
    test_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'running',
    winner_variant_id VARCHAR(100),
    confidence_level DECIMAL(5,4),
    min_sample_size INTEGER DEFAULT 100,
    auto_select_winner BOOLEAN DEFAULT true,
    winner_criteria VARCHAR(50) DEFAULT 'open_rate',
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_email_ab_tests_campaign ON email_ab_tests(campaign_id);

-- A/B Test Variants (UNLIMITED)
CREATE TABLE IF NOT EXISTS email_ab_variants (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES email_ab_tests(test_id),
    variant_code VARCHAR(10) NOT NULL,
    name VARCHAR(255),
    value TEXT NOT NULL,
    allocation_pct DECIMAL(5,2) DEFAULT 50.00,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    open_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    conversion_count INTEGER DEFAULT 0,
    revenue DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_ab_variants_test ON email_ab_variants(test_id);

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
    condition_type VARCHAR(50),
    condition_value TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_drip_steps_sequence ON email_drip_steps(sequence_id);

-- Drip Enrollments
CREATE TABLE IF NOT EXISTS email_drip_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_id UUID REFERENCES email_drip_sequences(sequence_id),
    recipient_id UUID NOT NULL,
    recipient_email VARCHAR(255) NOT NULL,
    current_step INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'active',
    enrolled_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    next_send_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_email_drip_enrollments_sequence ON email_drip_enrollments(sequence_id);
CREATE INDEX IF NOT EXISTS idx_email_drip_enrollments_next ON email_drip_enrollments(next_send_at);

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
    best_day_of_week INTEGER,
    best_hour INTEGER,
    avg_open_time_hours DECIMAL(5,2),
    total_sends INTEGER DEFAULT 0,
    total_opens INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_email_send_time_email ON email_send_time_stats(recipient_email);

-- Engagement Scores
CREATE TABLE IF NOT EXISTS email_engagement_scores (
    score_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_email VARCHAR(255) NOT NULL,
    engagement_score DECIMAL(5,2) DEFAULT 50.00,
    open_rate DECIMAL(5,4),
    click_rate DECIMAL(5,4),
    total_received INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    last_opened_at TIMESTAMP,
    last_clicked_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_email_engagement_email ON email_engagement_scores(recipient_email);

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
CREATE OR REPLACE VIEW v_email_ab_test_results AS
SELECT 
    t.test_id,
    t.campaign_id,
    t.test_type,
    t.status,
    v.variant_code,
    v.name as variant_name,
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
"""

# ============================================================================
# E31 SMS/MMS MARKETING SCHEMA
# ============================================================================

E31_SMS_SCHEMA = """
-- ============================================================================
-- ECOSYSTEM 31: SMS/MMS MARKETING SYSTEM
-- ============================================================================

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
    total_segments INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_campaigns_status ON sms_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_sms_campaigns_candidate ON sms_campaigns(candidate_id);

-- SMS Templates
CREATE TABLE IF NOT EXISTS sms_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    message_type VARCHAR(10) DEFAULT 'sms',
    media_url TEXT,
    variables JSONB DEFAULT '[]',
    category VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Individual SMS Sends
CREATE TABLE IF NOT EXISTS sms_sends (
    send_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES sms_campaigns(campaign_id),
    recipient_phone VARCHAR(20) NOT NULL,
    recipient_id UUID,
    variant_id VARCHAR(100),
    message TEXT NOT NULL,
    message_type VARCHAR(10) DEFAULT 'sms',
    media_url TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    segments INTEGER DEFAULT 1,
    cost DECIMAL(10,4),
    provider_message_id VARCHAR(255),
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    error_code VARCHAR(50),
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_sends_campaign ON sms_sends(campaign_id);
CREATE INDEX IF NOT EXISTS idx_sms_sends_phone ON sms_sends(recipient_phone);
CREATE INDEX IF NOT EXISTS idx_sms_sends_status ON sms_sends(status);

-- Shortlinks for Click Tracking
CREATE TABLE IF NOT EXISTS sms_shortlinks (
    shortlink_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_code VARCHAR(20) UNIQUE NOT NULL,
    original_url TEXT NOT NULL,
    campaign_id UUID,
    send_id UUID,
    click_count INTEGER DEFAULT 0,
    first_clicked_at TIMESTAMP,
    last_clicked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_shortlinks_code ON sms_shortlinks(short_code);
CREATE INDEX IF NOT EXISTS idx_sms_shortlinks_campaign ON sms_shortlinks(campaign_id);

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

CREATE INDEX IF NOT EXISTS idx_sms_shortlink_clicks_link ON sms_shortlink_clicks(shortlink_id);

-- TCPA Consent Management
CREATE TABLE IF NOT EXISTS sms_consent (
    consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    consent_type VARCHAR(50) DEFAULT 'express',
    opted_in_at TIMESTAMP,
    opted_out_at TIMESTAMP,
    opt_in_source VARCHAR(255),
    opt_in_keyword VARCHAR(50),
    opt_out_keyword VARCHAR(50),
    consent_text TEXT,
    ip_address VARCHAR(45),
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
    forward_to VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    trigger_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sms_keywords_unique ON sms_keywords(keyword, candidate_id);

-- Inbound Messages (Two-Way)
CREATE TABLE IF NOT EXISTS sms_inbound (
    inbound_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_phone VARCHAR(20) NOT NULL,
    to_phone VARCHAR(20) NOT NULL,
    message TEXT,
    media_urls JSONB,
    matched_keyword VARCHAR(50),
    auto_replied BOOLEAN DEFAULT false,
    provider_message_id VARCHAR(255),
    received_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_inbound_from ON sms_inbound(from_phone);
CREATE INDEX IF NOT EXISTS idx_sms_inbound_received ON sms_inbound(received_at);

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

CREATE INDEX IF NOT EXISTS idx_sms_ab_tests_campaign ON sms_ab_tests(campaign_id);

-- A/B Test Variants (UNLIMITED)
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

-- SMS Drip Sequences
CREATE TABLE IF NOT EXISTS sms_drip_sequences (
    sequence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    trigger_event VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    total_enrolled INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- SMS Drip Steps
CREATE TABLE IF NOT EXISTS sms_drip_steps (
    step_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_id UUID REFERENCES sms_drip_sequences(sequence_id),
    step_number INTEGER NOT NULL,
    message TEXT NOT NULL,
    delay_minutes INTEGER DEFAULT 0,
    delay_hours INTEGER DEFAULT 0,
    delay_days INTEGER DEFAULT 0,
    condition_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_drip_steps_sequence ON sms_drip_steps(sequence_id);

-- SMS Drip Enrollments
CREATE TABLE IF NOT EXISTS sms_drip_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_id UUID REFERENCES sms_drip_sequences(sequence_id),
    recipient_phone VARCHAR(20) NOT NULL,
    recipient_id UUID,
    current_step INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'active',
    enrolled_at TIMESTAMP DEFAULT NOW(),
    next_send_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sms_drip_enrollments_next ON sms_drip_enrollments(next_send_at);

-- Daily Cost Summary
CREATE TABLE IF NOT EXISTS sms_daily_costs (
    date DATE PRIMARY KEY,
    total_sms INTEGER DEFAULT 0,
    total_mms INTEGER DEFAULT 0,
    total_segments INTEGER DEFAULT 0,
    total_cost DECIMAL(10,4) DEFAULT 0,
    total_clicks INTEGER DEFAULT 0,
    total_replies INTEGER DEFAULT 0
);

-- Campaign Performance View
CREATE OR REPLACE VIEW v_sms_campaign_performance AS
SELECT 
    c.campaign_id,
    c.name,
    c.status,
    c.message_type,
    c.sent_at,
    c.total_recipients,
    c.sent_count,
    c.delivered_count,
    c.failed_count,
    c.click_count,
    c.reply_count,
    c.opt_out_count,
    c.total_cost,
    CASE WHEN c.sent_count > 0 THEN ROUND(c.delivered_count::DECIMAL / c.sent_count * 100, 2) ELSE 0 END as delivery_rate,
    CASE WHEN c.delivered_count > 0 THEN ROUND(c.click_count::DECIMAL / c.delivered_count * 100, 2) ELSE 0 END as click_rate,
    CASE WHEN c.delivered_count > 0 THEN ROUND(c.reply_count::DECIMAL / c.delivered_count * 100, 2) ELSE 0 END as reply_rate,
    CASE WHEN c.sent_count > 0 THEN ROUND(c.total_cost / c.sent_count, 4) ELSE 0 END as cost_per_message
FROM sms_campaigns c
ORDER BY c.created_at DESC;

-- Consent Summary View
CREATE OR REPLACE VIEW v_sms_consent_summary AS
SELECT 
    status,
    consent_type,
    COUNT(*) as count,
    MIN(created_at) as first_consent,
    MAX(updated_at) as last_update
FROM sms_consent
GROUP BY status, consent_type;
"""


# ============================================================================
# DEPLOYMENT FUNCTIONS
# ============================================================================

def test_connection():
    """Test database connection"""
    print("\n🔌 Testing database connection...")
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("SELECT version();")
        version = cur.fetchone()[0]
        conn.close()
        print(f"   ✅ PostgreSQL connected")
        print(f"   📦 {version[:50]}...")
        return True
    except Exception as e:
        print(f"   ❌ Connection failed: {e}")
        return False


def deploy_e30_email():
    """Deploy E30 Email Marketing schema"""
    print("\n📧 Deploying E30 Email Marketing...")
    
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute(E30_EMAIL_SCHEMA)
        conn.commit()
        conn.close()
        
        print("   ✅ email_campaigns table")
        print("   ✅ email_templates table")
        print("   ✅ email_sends tracking")
        print("   ✅ email_opens tracking")
        print("   ✅ email_clicks tracking")
        print("   ✅ email_ab_tests (UNLIMITED variants)")
        print("   ✅ email_ab_variants")
        print("   ✅ email_drip_sequences")
        print("   ✅ email_drip_steps")
        print("   ✅ email_drip_enrollments")
        print("   ✅ email_bounces")
        print("   ✅ email_unsubscribes")
        print("   ✅ email_send_time_stats")
        print("   ✅ email_engagement_scores")
        print("   ✅ v_email_campaign_performance view")
        print("   ✅ v_email_ab_test_results view")
        
        return True
    except Exception as e:
        print(f"   ❌ Deployment failed: {e}")
        return False


def deploy_e31_sms():
    """Deploy E31 SMS/MMS Marketing schema"""
    print("\n📱 Deploying E31 SMS/MMS Marketing...")
    
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute(E31_SMS_SCHEMA)
        conn.commit()
        conn.close()
        
        print("   ✅ sms_campaigns table")
        print("   ✅ sms_templates table")
        print("   ✅ sms_sends tracking")
        print("   ✅ sms_shortlinks (click tracking)")
        print("   ✅ sms_shortlink_clicks")
        print("   ✅ sms_consent (TCPA compliance)")
        print("   ✅ sms_keywords (two-way messaging)")
        print("   ✅ sms_inbound messages")
        print("   ✅ sms_ab_tests (UNLIMITED variants)")
        print("   ✅ sms_ab_variants")
        print("   ✅ sms_drip_sequences")
        print("   ✅ sms_drip_steps")
        print("   ✅ sms_drip_enrollments")
        print("   ✅ sms_daily_costs")
        print("   ✅ v_sms_campaign_performance view")
        print("   ✅ v_sms_consent_summary view")
        
        return True
    except Exception as e:
        print(f"   ❌ Deployment failed: {e}")
        return False


def check_status():
    """Check deployment status"""
    print("\n📊 Checking Marketo Clone deployment status...")
    
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        
        # Check E30 tables
        e30_tables = [
            'email_campaigns', 'email_templates', 'email_sends', 'email_opens',
            'email_clicks', 'email_ab_tests', 'email_ab_variants', 'email_drip_sequences',
            'email_drip_steps', 'email_drip_enrollments', 'email_bounces', 
            'email_unsubscribes', 'email_send_time_stats', 'email_engagement_scores'
        ]
        
        e31_tables = [
            'sms_campaigns', 'sms_templates', 'sms_sends', 'sms_shortlinks',
            'sms_shortlink_clicks', 'sms_consent', 'sms_keywords', 'sms_inbound',
            'sms_ab_tests', 'sms_ab_variants', 'sms_drip_sequences', 'sms_drip_steps',
            'sms_drip_enrollments', 'sms_daily_costs'
        ]
        
        print("\n📧 E30 Email Marketing:")
        e30_count = 0
        for table in e30_tables:
            cur.execute(f"SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '{table}')")
            exists = cur.fetchone()[0]
            status = "✅" if exists else "❌"
            print(f"   {status} {table}")
            if exists:
                e30_count += 1
        
        print(f"\n   E30 Status: {e30_count}/{len(e30_tables)} tables ({round(e30_count/len(e30_tables)*100)}%)")
        
        print("\n📱 E31 SMS/MMS Marketing:")
        e31_count = 0
        for table in e31_tables:
            cur.execute(f"SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '{table}')")
            exists = cur.fetchone()[0]
            status = "✅" if exists else "❌"
            print(f"   {status} {table}")
            if exists:
                e31_count += 1
        
        print(f"\n   E31 Status: {e31_count}/{len(e31_tables)} tables ({round(e31_count/len(e31_tables)*100)}%)")
        
        conn.close()
        
        total = e30_count + e31_count
        total_expected = len(e30_tables) + len(e31_tables)
        
        print("\n" + "=" * 60)
        if total == total_expected:
            print("✅ MARKETO CLONE FULLY DEPLOYED!")
        else:
            print(f"⚠️  PARTIAL DEPLOYMENT: {total}/{total_expected} tables")
        print("=" * 60)
        
        return total == total_expected
        
    except Exception as e:
        print(f"   ❌ Status check failed: {e}")
        return False


def show_summary():
    """Show deployment summary"""
    print("\n" + "=" * 70)
    print("📧📱 MARKETO CLONE - DEPLOYMENT COMPLETE")
    print("=" * 70)
    print()
    print("SYSTEMS DEPLOYED:")
    print("   • E30 Email Marketing (14 tables)")
    print("   • E31 SMS/MMS Marketing (14 tables)")
    print()
    print("EMAIL FEATURES:")
    print("   • Campaign management")
    print("   • UNLIMITED A/B testing")
    print("   • 20+ personalization variables")
    print("   • Drip sequences")
    print("   • Send time optimization")
    print("   • Engagement scoring")
    print("   • Bounce/unsubscribe handling")
    print()
    print("SMS/MMS FEATURES:")
    print("   • SMS + MMS campaigns")
    print("   • UNLIMITED A/B testing")
    print("   • Shortlink click tracking")
    print("   • TCPA-compliant consent")
    print("   • Two-way messaging (keywords)")
    print("   • Drip sequences")
    print("   • Cost tracking")
    print()
    print("COST COMPARISON:")
    print("   • Marketo: $3,000 - $10,000/month")
    print("   • BroyhillGOP: ~$25/month (SendGrid)")
    print("   • Annual Savings: $35,000 - $120,000")
    print()
    print("NEXT STEPS:")
    print("   1. Configure email provider (SendGrid/SES)")
    print("   2. Configure SMS provider (Twilio)")
    print("   3. Import recipient lists")
    print("   4. Create templates")
    print("   5. Launch campaigns!")
    print()
    print("=" * 70)


def main():
    """Main deployment function"""
    print("=" * 70)
    print("🚀 MARKETO CLONE DEPLOYMENT")
    print("   E30 Email Marketing + E31 SMS/MMS Marketing")
    print("=" * 70)
    print(f"   Database: {DATABASE_URL[:50]}...")
    print(f"   Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Parse arguments
    args = sys.argv[1:] if len(sys.argv) > 1 else []
    
    if '--test' in args:
        test_connection()
        return
    
    if '--status' in args:
        check_status()
        return
    
    if '--e30-only' in args:
        if test_connection():
            deploy_e30_email()
            check_status()
        return
    
    if '--e31-only' in args:
        if test_connection():
            deploy_e31_sms()
            check_status()
        return
    
    # Full deployment
    if not test_connection():
        print("\n❌ Cannot proceed without database connection")
        return
    
    e30_ok = deploy_e30_email()
    e31_ok = deploy_e31_sms()
    
    if e30_ok and e31_ok:
        show_summary()
    else:
        print("\n⚠️  Deployment completed with errors")
        check_status()


if __name__ == "__main__":
    main()
