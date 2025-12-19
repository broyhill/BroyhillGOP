-- BroyhillGOP Platform - Frontend Database Schema
-- Created: December 19, 2025 | Version: 2.0
-- Database: Supabase PostgreSQL

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS frontend;

-- Ecosystem Status Table
CREATE TABLE IF NOT EXISTS frontend.ecosystem_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ecosystem_key VARCHAR(50) UNIQUE NOT NULL,
    ecosystem_name VARCHAR(100) NOT NULL,
    ecosystem_number INTEGER NOT NULL,
    icon_name VARCHAR(50) NOT NULL,
    color_theme VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_visible BOOLEAN DEFAULT TRUE,
    sort_order INTEGER NOT NULL,
    description TEXT,
    primary_metric_label VARCHAR(50),
    primary_metric_value VARCHAR(50),
    secondary_metric_label VARCHAR(50),
    secondary_metric_value VARCHAR(50),
    last_activity_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert 15 ecosystems
INSERT INTO frontend.ecosystem_status (ecosystem_key, ecosystem_name, ecosystem_number, icon_name, color_theme, sort_order, description, primary_metric_label, primary_metric_value) VALUES
('donor_intelligence', 'Donor Intelligence', 1, 'users', 'blue', 1, '21-tier grading, 1000-point lead scoring', 'Donors Scored', '243,575'),
('email_studio', 'Email Studio', 30, 'mail', 'green', 2, 'AI-powered email campaigns', 'Campaigns', '847'),
('sms_center', 'SMS Center', 31, 'message', 'purple', 3, 'Bulk SMS/MMS with personalization', 'Messages', '124K'),
('voice_ultra', 'ULTRA Voice', 16, 'waveform', 'red', 4, 'Voice synthesis at 102-108% ElevenLabs quality', 'Calls', '8.5K'),
('video_studio', 'Video Studio', 45, 'video', 'pink', 5, 'HeyGen-style personalized video', 'Videos', '2.4K'),
('direct_mail', 'Direct Mail', 33, 'mail-forward', 'orange', 6, 'Variable data printing', 'Pieces', '45K'),
('donations', 'Donations', 2, 'currency-dollar', 'success', 7, 'Payment processing with fraud detection', 'Processed', '$847K'),
('events', 'Events & RSVP', 34, 'calendar-event', 'indigo', 8, 'Event management', 'Events', '24'),
('volunteers', 'Volunteers', 5, 'users-group', 'cyan', 9, 'Volunteer management with referrals', 'Active', '847'),
('social_media', 'Social Media', 19, 'brand-instagram', 'pink', 10, 'Multi-platform publishing', 'Followers', '24.8K'),
('compliance', 'Compliance & FEC', 10, 'shield-check', 'success', 11, 'Automated FEC compliance', 'Score', '100%'),
('analytics', 'Analytics', 6, 'chart-dots-3', 'teal', 12, '403+ metrics with BvA tracking', 'Metrics', '403'),
('ai_hub', 'AI Hub', 13, 'brain', 'gradient', 13, 'Central AI gateway', 'Tasks', '847K'),
('budget', 'Budget Management', 11, 'wallet', 'mint', 14, 'Financial tracking', 'Budget', '$1.2M'),
('canvassing', 'Canvassing', 38, 'walk', 'lime', 15, 'Door-to-door tracking', 'Doors', '12.4K')
ON CONFLICT (ecosystem_key) DO NOTHING;

-- Control Panel Settings
CREATE TABLE IF NOT EXISTS frontend.control_panel_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    candidate_id UUID NOT NULL,
    ecosystem_key VARCHAR(50) NOT NULL REFERENCES frontend.ecosystem_status(ecosystem_key),
    setting_key VARCHAR(50) NOT NULL,
    setting_label VARCHAR(100) NOT NULL,
    setting_state VARCHAR(10) DEFAULT 'on' CHECK (setting_state IN ('off', 'on', 'timer')),
    timer_start TIME,
    timer_end TIME,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(candidate_id, ecosystem_key, setting_key)
);

-- Activity Feed
CREATE TABLE IF NOT EXISTS frontend.activity_feed (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    candidate_id UUID NOT NULL,
    ecosystem_key VARCHAR(50) REFERENCES frontend.ecosystem_status(ecosystem_key),
    activity_type VARCHAR(50) NOT NULL,
    icon_name VARCHAR(50) NOT NULL,
    color_theme VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_feed_candidate ON frontend.activity_feed(candidate_id);
CREATE INDEX IF NOT EXISTS idx_activity_feed_created ON frontend.activity_feed(created_at DESC);

-- User Preferences
CREATE TABLE IF NOT EXISTS frontend.user_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    theme VARCHAR(20) DEFAULT 'light' CHECK (theme IN ('light', 'dark', 'auto')),
    sidebar_collapsed BOOLEAN DEFAULT FALSE,
    pricing_panel_visible BOOLEAN DEFAULT TRUE,
    default_ecosystem VARCHAR(50) REFERENCES frontend.ecosystem_status(ecosystem_key),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION frontend.update_updated_at()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER update_ecosystem_status_timestamp
    BEFORE UPDATE ON frontend.ecosystem_status
    FOR EACH ROW EXECUTE FUNCTION frontend.update_updated_at();

-- Dashboard stats function
CREATE OR REPLACE FUNCTION frontend.get_dashboard_stats(p_candidate_id UUID)
RETURNS TABLE (total_donors BIGINT, total_raised NUMERIC, active_campaigns INTEGER, conversion_rate NUMERIC) AS \$\$
BEGIN
    RETURN QUERY SELECT 243575::BIGINT, 847235::NUMERIC, 47::INTEGER, 4.8::NUMERIC;
END;
\$\$ LANGUAGE plpgsql;

-- View for ecosystem cards
CREATE OR REPLACE VIEW frontend.v_ecosystem_cards AS
SELECT ecosystem_key, ecosystem_name, ecosystem_number, icon_name, color_theme, is_active, sort_order, description, primary_metric_label, primary_metric_value
FROM frontend.ecosystem_status WHERE is_visible = TRUE ORDER BY sort_order;
