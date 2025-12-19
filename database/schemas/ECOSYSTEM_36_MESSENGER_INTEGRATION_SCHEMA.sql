-- ============================================================================
-- ECOSYSTEM 36: MESSENGER & INSTAGRAM DM INTEGRATION
-- Complete Database Schema for Facebook Messenger & Instagram Direct Messages
-- ============================================================================
-- Version: 1.0.0
-- Created: December 18, 2025
-- Author: BroyhillGOP Platform
-- 
-- Features:
--   - Multi-platform support (Messenger, Instagram DM)
--   - Keyword automation & triggers
--   - Comment-to-DM automation
--   - AI-powered responses (Claude integration)
--   - Conversation flows & sequences
--   - Broadcast messaging
--   - User segmentation & tagging
--   - Analytics & reporting
--
-- Integration Points:
--   - E0 DataHub: candidates table
--   - E1 Donor Intelligence: donor_id linking
--   - E13 AI Hub: AI response generation
--   - E20 Intelligence Brain: event triggers
-- ============================================================================

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS broyhillgop;
SET search_path TO broyhillgop, public;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- TABLE 1: messenger_accounts
-- Connected Facebook Pages and Instagram Business accounts
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_accounts (
    account_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    candidate_id UUID NOT NULL REFERENCES candidates(candidate_id),
    
    -- Platform info
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('messenger', 'instagram')),
    platform_page_id VARCHAR(100) NOT NULL,
    platform_page_name VARCHAR(255),
    
    -- Authentication
    access_token TEXT NOT NULL, -- Encrypted
    access_token_expires_at TIMESTAMP WITH TIME ZONE,
    page_access_token TEXT, -- For Messenger
    instagram_business_id VARCHAR(100), -- For Instagram
    
    -- Welcome Experience
    welcome_message TEXT,
    welcome_buttons JSONB DEFAULT '[]',
    get_started_payload VARCHAR(100) DEFAULT 'GET_STARTED',
    
    -- Persistent Menu
    persistent_menu JSONB DEFAULT '[]',
    
    -- AI Settings
    ai_enabled BOOLEAN DEFAULT false,
    ai_model VARCHAR(50) DEFAULT 'claude-3-haiku',
    ai_system_prompt TEXT,
    ai_response_delay_seconds INTEGER DEFAULT 3,
    ai_fallback_message TEXT DEFAULT 'Thanks for your message! A team member will respond shortly.',
    
    -- Business Hours
    business_hours_enabled BOOLEAN DEFAULT false,
    business_hours JSONB DEFAULT '{}', -- {"mon": {"start": "09:00", "end": "17:00"}, ...}
    after_hours_message TEXT,
    
    -- Default Settings
    default_response_delay_seconds INTEGER DEFAULT 0,
    typing_indicator_enabled BOOLEAN DEFAULT true,
    read_receipts_enabled BOOLEAN DEFAULT true,
    
    -- Stats
    total_conversations INTEGER DEFAULT 0,
    total_messages_sent INTEGER DEFAULT 0,
    total_messages_received INTEGER DEFAULT 0,
    total_subscribers INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'disconnected')),
    last_webhook_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(platform, platform_page_id)
);

-- ============================================================================
-- TABLE 2: messenger_users
-- Users who have interacted via Messenger/Instagram
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    
    -- Platform identifiers
    platform VARCHAR(20) NOT NULL,
    platform_user_id VARCHAR(100) NOT NULL,
    
    -- Profile info (from Facebook/Instagram API)
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    profile_pic_url TEXT,
    locale VARCHAR(20),
    timezone INTEGER,
    gender VARCHAR(20),
    
    -- Contact linking
    donor_id UUID REFERENCES donors(donor_id),
    email VARCHAR(255),
    phone VARCHAR(20),
    
    -- Engagement
    subscription_status VARCHAR(20) DEFAULT 'subscribed' CHECK (subscription_status IN ('subscribed', 'unsubscribed', 'blocked')),
    first_interaction_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_interaction_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_messages INTEGER DEFAULT 0,
    total_conversations INTEGER DEFAULT 0,
    
    -- Segmentation
    tags JSONB DEFAULT '[]',
    custom_fields JSONB DEFAULT '{}',
    
    -- Sequences
    current_sequence_id UUID,
    sequence_step INTEGER,
    sequence_paused BOOLEAN DEFAULT false,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(platform_user_id, platform)
);

-- ============================================================================
-- TABLE 3: messenger_conversations
-- Individual conversation threads
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_conversations (
    conversation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES messenger_users(user_id) ON DELETE CASCADE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'closed', 'archived', 'spam')),
    
    -- Assignment
    assigned_to VARCHAR(100), -- Staff member
    assigned_at TIMESTAMP WITH TIME ZONE,
    
    -- Flow tracking
    current_flow_id UUID,
    current_step VARCHAR(100),
    flow_data JSONB DEFAULT '{}',
    
    -- Stats
    message_count INTEGER DEFAULT 0,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_message_direction VARCHAR(10), -- 'inbound' or 'outbound'
    
    -- Tags & notes
    tags JSONB DEFAULT '[]',
    internal_notes TEXT,
    
    -- Response tracking
    first_response_at TIMESTAMP WITH TIME ZONE,
    avg_response_time_seconds INTEGER,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- TABLE 4: messenger_messages
-- Individual messages within conversations
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES messenger_conversations(conversation_id) ON DELETE CASCADE,
    
    -- Message info
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    message_type VARCHAR(30) NOT NULL DEFAULT 'text' CHECK (message_type IN (
        'text', 'image', 'video', 'audio', 'file', 'sticker',
        'template', 'quick_reply', 'postback', 'referral'
    )),
    
    -- Content
    text_content TEXT,
    media_url TEXT,
    media_type VARCHAR(50),
    
    -- Rich content
    buttons JSONB DEFAULT '[]',
    quick_replies JSONB DEFAULT '[]',
    template_type VARCHAR(50), -- generic, button, receipt, etc.
    template_payload JSONB,
    
    -- Platform message ID
    platform_message_id VARCHAR(100),
    
    -- Delivery status
    delivery_status VARCHAR(20) DEFAULT 'sent' CHECK (delivery_status IN (
        'pending', 'sent', 'delivered', 'read', 'failed'
    )),
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    
    -- Source tracking
    sent_by VARCHAR(100), -- staff member, automation, AI
    is_ai_generated BOOLEAN DEFAULT false,
    automation_source VARCHAR(100), -- keyword, flow, sequence, broadcast
    automation_id UUID,
    
    -- Error handling
    error_code VARCHAR(50),
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- TABLE 5: messenger_keywords
-- Keyword automation triggers
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_keywords (
    keyword_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    
    -- Keyword settings
    keyword VARCHAR(100) NOT NULL,
    match_type VARCHAR(20) DEFAULT 'contains' CHECK (match_type IN ('exact', 'contains', 'starts_with', 'regex')),
    case_sensitive BOOLEAN DEFAULT false,
    
    -- Response type
    response_type VARCHAR(20) DEFAULT 'respond' CHECK (response_type IN (
        'respond', 'start_flow', 'add_tag', 'remove_tag', 'subscribe', 'unsubscribe'
    )),
    
    -- Response content
    response_text TEXT,
    response_buttons JSONB DEFAULT '[]',
    response_quick_replies JSONB DEFAULT '[]',
    response_media_url TEXT,
    
    -- Flow trigger
    flow_id UUID REFERENCES messenger_flows(flow_id),
    
    -- Tag actions
    tags_to_add JSONB DEFAULT '[]',
    tags_to_remove JSONB DEFAULT '[]',
    
    -- Timer/expiration
    mode VARCHAR(20) DEFAULT 'always' CHECK (mode IN ('always', 'once_per_user', 'timed', 'off')),
    timer_minutes INTEGER,
    timer_expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Priority (lower = higher priority)
    priority INTEGER DEFAULT 100,
    
    -- Stats
    times_triggered INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- TABLE 6: messenger_flows
-- Automation flows (multi-step conversations)
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_flows (
    flow_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    
    -- Flow info
    flow_name VARCHAR(255) NOT NULL,
    description TEXT,
    trigger_type VARCHAR(30) CHECK (trigger_type IN (
        'keyword', 'postback', 'referral', 'comment', 'welcome', 'manual', 'api'
    )),
    
    -- Flow structure (JSON array of steps)
    steps JSONB NOT NULL DEFAULT '[]',
    /*
    Steps structure:
    [
        {
            "step_id": "start",
            "type": "message",
            "content": {"text": "Welcome!", "buttons": [...]},
            "delay_seconds": 0,
            "next_step": "ask_interest"
        },
        {
            "step_id": "ask_interest",
            "type": "question",
            "content": {"text": "What interests you?", "quick_replies": [...]},
            "save_to": "interest",
            "conditions": [
                {"value": "donate", "next_step": "donate_flow"},
                {"value": "volunteer", "next_step": "volunteer_flow"}
            ]
        }
    ]
    */
    
    -- Settings
    restart_on_keyword BOOLEAN DEFAULT false,
    restart_keyword VARCHAR(100),
    timeout_minutes INTEGER DEFAULT 1440, -- 24 hours
    timeout_step VARCHAR(100),
    
    -- Timer/expiration
    mode VARCHAR(20) DEFAULT 'always' CHECK (mode IN ('always', 'timed', 'off')),
    timer_minutes INTEGER,
    timer_expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Stats
    times_triggered INTEGER DEFAULT 0,
    times_completed INTEGER DEFAULT 0,
    avg_completion_rate DECIMAL(5,2),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- TABLE 7: messenger_sequences
-- Drip sequences (time-delayed message series)
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_sequences (
    sequence_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    
    -- Sequence info
    sequence_name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Trigger
    trigger_type VARCHAR(30) CHECK (trigger_type IN (
        'manual', 'tag_added', 'keyword', 'flow_completed', 'api'
    )),
    trigger_value VARCHAR(255), -- tag name, keyword, etc.
    
    -- Sequence steps (JSON array)
    steps JSONB NOT NULL DEFAULT '[]',
    /*
    Steps structure:
    [
        {
            "step_number": 1,
            "delay_minutes": 0,
            "message": {"text": "...", "buttons": [...]},
            "conditions": {"has_tag": "interested", "not_tag": "converted"}
        },
        {
            "step_number": 2,
            "delay_minutes": 1440,
            "message": {...}
        }
    ]
    */
    
    -- Settings
    stop_on_reply BOOLEAN DEFAULT true,
    stop_on_unsubscribe BOOLEAN DEFAULT true,
    respect_business_hours BOOLEAN DEFAULT false,
    
    -- Stats
    total_enrolled INTEGER DEFAULT 0,
    total_completed INTEGER DEFAULT 0,
    total_stopped INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- TABLE 8: messenger_sequence_enrollments
-- Users enrolled in sequences
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_sequence_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sequence_id UUID NOT NULL REFERENCES messenger_sequences(sequence_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES messenger_users(user_id) ON DELETE CASCADE,
    
    -- Progress
    current_step INTEGER DEFAULT 1,
    next_send_at TIMESTAMP WITH TIME ZONE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'paused', 'completed', 'stopped', 'failed'
    )),
    stopped_reason VARCHAR(100),
    
    -- Stats
    messages_sent INTEGER DEFAULT 0,
    messages_opened INTEGER DEFAULT 0,
    
    -- Metadata
    enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(sequence_id, user_id)
);

-- ============================================================================
-- TABLE 9: messenger_broadcasts
-- One-time broadcast messages
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_broadcasts (
    broadcast_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    
    -- Broadcast info
    broadcast_name VARCHAR(255) NOT NULL,
    message_tag VARCHAR(50), -- CONFIRMED_EVENT_UPDATE, POST_PURCHASE_UPDATE, etc.
    
    -- Content
    message_text TEXT NOT NULL,
    message_buttons JSONB DEFAULT '[]',
    message_quick_replies JSONB DEFAULT '[]',
    message_media_url TEXT,
    
    -- Audience
    audience_type VARCHAR(30) DEFAULT 'all' CHECK (audience_type IN (
        'all', 'tag', 'custom_field', 'segment', 'manual'
    )),
    audience_filter JSONB DEFAULT '{}', -- {"tag": "donors", "custom_field": {"state": "NC"}}
    audience_user_ids JSONB DEFAULT '[]', -- For manual selection
    
    -- Scheduling
    scheduled_at TIMESTAMP WITH TIME ZONE,
    send_immediately BOOLEAN DEFAULT false,
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN (
        'draft', 'scheduled', 'sending', 'sent', 'cancelled', 'failed'
    )),
    
    -- Stats
    total_recipients INTEGER DEFAULT 0,
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_read INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    total_failed INTEGER DEFAULT 0,
    
    -- Timing
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    created_by VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- TABLE 10: messenger_comment_triggers
-- Comment-to-DM automation (post comments trigger DMs)
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_comment_triggers (
    trigger_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    
    -- Post targeting
    target_type VARCHAR(20) DEFAULT 'any' CHECK (target_type IN ('any', 'specific', 'keyword_in_post')),
    target_post_id VARCHAR(100), -- Specific post ID
    target_keyword VARCHAR(255), -- Keyword in post text
    
    -- Comment matching
    comment_keyword VARCHAR(255), -- Keyword to match in comment
    comment_match_type VARCHAR(20) DEFAULT 'contains' CHECK (comment_match_type IN ('exact', 'contains', 'any')),
    
    -- Response
    dm_message TEXT NOT NULL,
    dm_buttons JSONB DEFAULT '[]',
    dm_delay_seconds INTEGER DEFAULT 5,
    
    -- Comment reply (optional)
    reply_to_comment BOOLEAN DEFAULT false,
    comment_reply_text TEXT,
    
    -- Flow trigger
    start_flow BOOLEAN DEFAULT false,
    flow_id UUID REFERENCES messenger_flows(flow_id),
    
    -- Tag actions
    tags_to_add JSONB DEFAULT '[]',
    
    -- Timer/expiration
    mode VARCHAR(20) DEFAULT 'always' CHECK (mode IN ('always', 'timed', 'off')),
    timer_minutes INTEGER,
    timer_expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Limits
    max_triggers_per_user INTEGER DEFAULT 1,
    max_triggers_per_post INTEGER,
    
    -- Stats
    times_triggered INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- TABLE 11: messenger_user_tags
-- User tagging for segmentation
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_user_tags (
    tag_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    
    tag_name VARCHAR(100) NOT NULL,
    tag_color VARCHAR(7) DEFAULT '#3B82F6',
    description TEXT,
    
    user_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(account_id, tag_name)
);

-- ============================================================================
-- TABLE 12: messenger_templates
-- Reusable message templates
-- ============================================================================
CREATE TABLE IF NOT EXISTS messenger_templates (
    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES messenger_accounts(account_id) ON DELETE CASCADE,
    
    template_name VARCHAR(255) NOT NULL,
    category VARCHAR(50), -- welcome, support, donation_ask, event, etc.
    
    -- Content
    message_text TEXT NOT NULL,
    buttons JSONB DEFAULT '[]',
    quick_replies JSONB DEFAULT '[]',
    media_url TEXT,
    
    -- Variables
    variables JSONB DEFAULT '[]', -- ["first_name", "donation_amount", "event_name"]
    
    -- Stats
    times_used INTEGER DEFAULT 0,
    
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Accounts
CREATE INDEX idx_messenger_accounts_candidate ON messenger_accounts(candidate_id);
CREATE INDEX idx_messenger_accounts_platform ON messenger_accounts(platform);
CREATE INDEX idx_messenger_accounts_status ON messenger_accounts(status);

-- Users
CREATE INDEX idx_messenger_users_account ON messenger_users(account_id);
CREATE INDEX idx_messenger_users_platform_id ON messenger_users(platform_user_id);
CREATE INDEX idx_messenger_users_donor ON messenger_users(donor_id);
CREATE INDEX idx_messenger_users_subscription ON messenger_users(subscription_status);
CREATE INDEX idx_messenger_users_last_interaction ON messenger_users(last_interaction_at DESC);
CREATE INDEX idx_messenger_users_tags ON messenger_users USING GIN(tags);

-- Conversations
CREATE INDEX idx_messenger_conversations_account ON messenger_conversations(account_id);
CREATE INDEX idx_messenger_conversations_user ON messenger_conversations(user_id);
CREATE INDEX idx_messenger_conversations_status ON messenger_conversations(status);
CREATE INDEX idx_messenger_conversations_assigned ON messenger_conversations(assigned_to);
CREATE INDEX idx_messenger_conversations_last_message ON messenger_conversations(last_message_at DESC);

-- Messages
CREATE INDEX idx_messenger_messages_conversation ON messenger_messages(conversation_id);
CREATE INDEX idx_messenger_messages_direction ON messenger_messages(direction);
CREATE INDEX idx_messenger_messages_created ON messenger_messages(created_at DESC);
CREATE INDEX idx_messenger_messages_platform_id ON messenger_messages(platform_message_id);

-- Keywords
CREATE INDEX idx_messenger_keywords_account ON messenger_keywords(account_id);
CREATE INDEX idx_messenger_keywords_keyword ON messenger_keywords(keyword);
CREATE INDEX idx_messenger_keywords_active ON messenger_keywords(is_active);

-- Flows
CREATE INDEX idx_messenger_flows_account ON messenger_flows(account_id);
CREATE INDEX idx_messenger_flows_active ON messenger_flows(is_active);

-- Sequences
CREATE INDEX idx_messenger_sequences_account ON messenger_sequences(account_id);
CREATE INDEX idx_messenger_sequences_active ON messenger_sequences(is_active);

-- Sequence enrollments
CREATE INDEX idx_messenger_enrollments_sequence ON messenger_sequence_enrollments(sequence_id);
CREATE INDEX idx_messenger_enrollments_user ON messenger_sequence_enrollments(user_id);
CREATE INDEX idx_messenger_enrollments_status ON messenger_sequence_enrollments(status);
CREATE INDEX idx_messenger_enrollments_next_send ON messenger_sequence_enrollments(next_send_at);

-- Broadcasts
CREATE INDEX idx_messenger_broadcasts_account ON messenger_broadcasts(account_id);
CREATE INDEX idx_messenger_broadcasts_status ON messenger_broadcasts(status);
CREATE INDEX idx_messenger_broadcasts_scheduled ON messenger_broadcasts(scheduled_at);

-- Comment triggers
CREATE INDEX idx_messenger_comment_triggers_account ON messenger_comment_triggers(account_id);
CREATE INDEX idx_messenger_comment_triggers_active ON messenger_comment_triggers(is_active);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Account statistics view
CREATE OR REPLACE VIEW v_messenger_stats AS
SELECT 
    a.account_id,
    a.candidate_id,
    a.platform,
    a.platform_page_name,
    a.total_conversations,
    a.total_messages_sent,
    a.total_messages_received,
    a.total_subscribers,
    
    -- Active users (last 30 days)
    (SELECT COUNT(*) FROM messenger_users u 
     WHERE u.account_id = a.account_id 
     AND u.last_interaction_at > NOW() - INTERVAL '30 days') AS active_users_30d,
    
    -- New users (last 7 days)
    (SELECT COUNT(*) FROM messenger_users u 
     WHERE u.account_id = a.account_id 
     AND u.created_at > NOW() - INTERVAL '7 days') AS new_users_7d,
    
    -- Messages today
    (SELECT COUNT(*) FROM messenger_messages m
     JOIN messenger_conversations c ON m.conversation_id = c.conversation_id
     WHERE c.account_id = a.account_id
     AND m.created_at > CURRENT_DATE) AS messages_today,
    
    -- Active flows
    (SELECT COUNT(*) FROM messenger_flows f 
     WHERE f.account_id = a.account_id AND f.is_active) AS active_flows,
    
    -- Active keywords
    (SELECT COUNT(*) FROM messenger_keywords k 
     WHERE k.account_id = a.account_id AND k.is_active) AS active_keywords,
    
    -- Pending broadcasts
    (SELECT COUNT(*) FROM messenger_broadcasts b 
     WHERE b.account_id = a.account_id AND b.status = 'scheduled') AS pending_broadcasts

FROM messenger_accounts a
WHERE a.status = 'active';

-- Flow performance view
CREATE OR REPLACE VIEW v_flow_performance AS
SELECT 
    f.flow_id,
    f.account_id,
    f.flow_name,
    f.times_triggered,
    f.times_completed,
    CASE WHEN f.times_triggered > 0 
         THEN ROUND((f.times_completed::DECIMAL / f.times_triggered) * 100, 2)
         ELSE 0 
    END AS completion_rate,
    f.is_active,
    f.created_at
FROM messenger_flows f;

-- Conversation inbox view
CREATE OR REPLACE VIEW v_messenger_inbox AS
SELECT 
    c.conversation_id,
    c.account_id,
    c.status,
    c.assigned_to,
    c.message_count,
    c.last_message_at,
    c.last_message_direction,
    u.user_id,
    u.first_name,
    u.last_name,
    u.profile_pic_url,
    u.platform,
    u.subscription_status,
    u.tags AS user_tags,
    (SELECT text_content FROM messenger_messages m 
     WHERE m.conversation_id = c.conversation_id 
     ORDER BY m.created_at DESC LIMIT 1) AS last_message_preview
FROM messenger_conversations c
JOIN messenger_users u ON c.user_id = u.user_id
WHERE c.status IN ('active', 'closed')
ORDER BY c.last_message_at DESC;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to update account stats
CREATE OR REPLACE FUNCTION update_messenger_account_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'messenger_users' THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE messenger_accounts SET 
                total_subscribers = total_subscribers + 1,
                updated_at = NOW()
            WHERE account_id = NEW.account_id;
        ELSIF TG_OP = 'DELETE' THEN
            UPDATE messenger_accounts SET 
                total_subscribers = total_subscribers - 1,
                updated_at = NOW()
            WHERE account_id = OLD.account_id;
        END IF;
    END IF;
    
    IF TG_TABLE_NAME = 'messenger_conversations' THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE messenger_accounts SET 
                total_conversations = total_conversations + 1,
                updated_at = NOW()
            WHERE account_id = NEW.account_id;
        END IF;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to update user tag counts
CREATE OR REPLACE FUNCTION update_user_tag_counts()
RETURNS TRIGGER AS $$
BEGIN
    -- Update tag counts when user tags change
    UPDATE messenger_user_tags t
    SET user_count = (
        SELECT COUNT(*) FROM messenger_users u 
        WHERE u.account_id = t.account_id 
        AND u.tags ? t.tag_name
    )
    WHERE t.account_id = COALESCE(NEW.account_id, OLD.account_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Update account stats on user changes
CREATE TRIGGER trg_messenger_user_stats
AFTER INSERT OR DELETE ON messenger_users
FOR EACH ROW EXECUTE FUNCTION update_messenger_account_stats();

-- Update account stats on conversation changes
CREATE TRIGGER trg_messenger_conversation_stats
AFTER INSERT ON messenger_conversations
FOR EACH ROW EXECUTE FUNCTION update_messenger_account_stats();

-- Update tag counts on user tag changes
CREATE TRIGGER trg_messenger_user_tags
AFTER INSERT OR UPDATE OF tags OR DELETE ON messenger_users
FOR EACH ROW EXECUTE FUNCTION update_user_tag_counts();

-- ============================================================================
-- SAMPLE DATA (for testing)
-- ============================================================================

-- Sample keywords
/*
INSERT INTO messenger_keywords (account_id, keyword, response_text, response_buttons) VALUES
('{account_id}', 'donate', 'Thank you for your interest in donating! 🙏', 
 '[{"type": "web_url", "title": "Donate Now", "url": "https://secure.actblue.com/..."}]'),
('{account_id}', 'volunteer', 'We''d love your help! Here are ways to get involved:', 
 '[{"type": "postback", "title": "Phone Bank", "payload": "VOLUNTEER_PHONE"},
   {"type": "postback", "title": "Canvass", "payload": "VOLUNTEER_CANVASS"},
   {"type": "postback", "title": "Events", "payload": "VOLUNTEER_EVENTS"}]'),
('{account_id}', 'events', 'Here are our upcoming events! 📅', '[]'),
('{account_id}', 'stop', 'You have been unsubscribed. Reply START to resubscribe.', '[]');
*/

-- ============================================================================
-- GRANTS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA broyhillgop TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA broyhillgop TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA broyhillgop TO anon;

-- ============================================================================
-- END OF ECOSYSTEM 36 SCHEMA
-- ============================================================================
