-- ECOSYSTEM_19_SOCIAL_MEDIA_SCHEMA.sql
-- Database schema for Ecosystem 19: Social Media Manager
-- BroyhillGOP Platform - Integrates with E0 DataHub
-- Replaces previous 65% complete version with 100% complete system

-- ================================================================
-- INTEGRATION NOTES
-- ================================================================
-- This schema integrates with:
-- - E0 DataHub: candidates table (foreign key reference)
-- - E3 Marketing Automation: social_approval_requests
-- - E20 Intelligence Brain: intelligence_brain_events
-- - E13 AI Hub: candidate_voice_profiles
--
-- Run this after MASTER_DATABASE_COMPLETE.sql
-- ================================================================

-- ================================================================
-- CANDIDATE SOCIAL ACCOUNTS
-- Links candidates to their social media platforms
-- ================================================================

CREATE TABLE IF NOT EXISTS candidate_social_accounts (
    candidate_id UUID PRIMARY KEY REFERENCES candidates(candidate_id),
    
    -- Facebook
    facebook_page_id VARCHAR(255),
    facebook_page_token TEXT,  -- Encrypted
    facebook_political_auth_status VARCHAR(50) DEFAULT 'not_authorized',
    facebook_auth_completed_at TIMESTAMP,
    facebook_disclaimer VARCHAR(500),
    
    -- Twitter/X
    twitter_user_id VARCHAR(255),
    twitter_access_token TEXT,  -- Encrypted
    twitter_access_token_secret TEXT,  -- Encrypted
    
    -- Instagram
    instagram_business_id VARCHAR(255),
    instagram_connected BOOLEAN DEFAULT false,
    
    -- LinkedIn
    linkedin_organization_id VARCHAR(255),
    linkedin_access_token TEXT,  -- Encrypted
    
    -- Settings
    auto_approve_enabled BOOLEAN DEFAULT true,
    approval_phone VARCHAR(20),
    approval_email VARCHAR(255),
    notification_preferences JSONB DEFAULT '{"sms": true, "email": true}'::jsonb,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_social_accounts_facebook_auth 
    ON candidate_social_accounts(facebook_political_auth_status);
CREATE INDEX IF NOT EXISTS idx_social_accounts_auto_approve 
    ON candidate_social_accounts(auto_approve_enabled);

COMMENT ON TABLE candidate_social_accounts IS 
    'E19: Stores social media credentials and settings for each candidate';

-- ================================================================
-- CANDIDATE STYLE PROFILES
-- AI-learned writing styles for voice matching
-- ================================================================

CREATE TABLE IF NOT EXISTS candidate_style_profiles (
    candidate_id UUID PRIMARY KEY REFERENCES candidates(candidate_id),
    
    -- Voice Analysis
    common_phrases TEXT[],
    signature_words TEXT[],
    opening_lines TEXT[],
    closing_lines TEXT[],
    
    -- Sentence Structure
    avg_sentence_length DECIMAL(5,2),
    uses_fragments BOOLEAN,
    uses_questions_pct DECIMAL(5,2),
    uses_exclamations_pct DECIMAL(5,2),
    
    -- Emotional Tone
    primary_emotions TEXT[],
    intensity_level INTEGER CHECK (intensity_level BETWEEN 1 AND 10),
    formality_level INTEGER CHECK (formality_level BETWEEN 1 AND 10),
    
    -- Formatting Preferences
    avg_post_length INTEGER,
    uses_emojis BOOLEAN,
    favorite_emojis TEXT[],
    emoji_frequency DECIMAL(5,2),
    emoji_placement VARCHAR(20),  -- 'inline', 'end', 'both'
    
    -- Hashtag Style
    avg_hashtags INTEGER,
    hashtag_placement VARCHAR(20),  -- 'inline', 'end'
    typical_hashtags TEXT[],
    
    -- Emphasis Style
    uses_caps BOOLEAN,
    uses_bold BOOLEAN,
    emphasis_frequency DECIMAL(5,2),
    
    -- Content Themes
    favorite_topics TEXT[],
    typical_cta_style TEXT,
    personal_reference_types TEXT[],
    
    -- Analysis Metadata
    analyzed_at TIMESTAMP DEFAULT NOW(),
    sample_size INTEGER,
    confidence_score DECIMAL(5,2),
    
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_style_profiles_analyzed 
    ON candidate_style_profiles(analyzed_at);

COMMENT ON TABLE candidate_style_profiles IS 
    'E19: AI-learned writing style profiles for voice-matched content generation';

-- ================================================================
-- CANDIDATE VOICE PROFILES (Full JSON storage)
-- Complete voice analysis from Personalization Engine
-- ================================================================

CREATE TABLE IF NOT EXISTS candidate_voice_profiles (
    profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    profile_data JSONB NOT NULL,  -- Complete style profile
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_voice_profiles_candidate 
    ON candidate_voice_profiles(candidate_id);
CREATE INDEX IF NOT EXISTS idx_voice_profiles_created 
    ON candidate_voice_profiles(created_at DESC);

COMMENT ON TABLE candidate_voice_profiles IS 
    'E19: Complete JSON voice profiles from Personalization Engine';

-- ================================================================
-- SOCIAL POSTS (All Posted Content)
-- ================================================================

CREATE TABLE IF NOT EXISTS social_posts (
    post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    
    -- Post Content
    caption TEXT NOT NULL,
    content_hash VARCHAR(64),  -- MD5 hash for duplicate detection
    media_url TEXT,
    media_type VARCHAR(20),  -- 'image', 'video', 'none'
    
    -- Platform Info
    platform VARCHAR(20) NOT NULL,  -- 'facebook', 'twitter', 'instagram', 'linkedin'
    platform_post_id VARCHAR(255),  -- ID from platform
    
    -- Metadata
    posted_at TIMESTAMP,
    scheduled_for TIMESTAMP,
    status VARCHAR(20) DEFAULT 'draft',  -- 'draft', 'scheduled', 'published', 'failed'
    
    -- Engagement
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    engagement_score DECIMAL(10,2),
    
    -- Approval Info (links to E3 Marketing Automation)
    approval_request_id UUID,
    approval_method VARCHAR(50),  -- 'manual_approve', 'auto_approve', 'edit_approved'
    approved_by UUID REFERENCES candidates(candidate_id),
    approved_at TIMESTAMP,
    
    -- Compliance
    has_disclaimer BOOLEAN DEFAULT false,
    has_ai_disclosure BOOLEAN DEFAULT false,
    compliance_checked BOOLEAN DEFAULT false,
    compliance_issues JSONB,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_posts_candidate ON social_posts(candidate_id);
CREATE INDEX IF NOT EXISTS idx_posts_platform ON social_posts(platform);
CREATE INDEX IF NOT EXISTS idx_posts_status ON social_posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_scheduled ON social_posts(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_posts_posted ON social_posts(posted_at);
CREATE INDEX IF NOT EXISTS idx_posts_content_hash ON social_posts(content_hash);

-- Prevent duplicate content
CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_unique_content 
    ON social_posts(candidate_id, content_hash, platform)
    WHERE status IN ('scheduled', 'published');

COMMENT ON TABLE social_posts IS 
    'E19: All social media posts (scheduled and published)';

-- ================================================================
-- SOCIAL APPROVAL REQUESTS
-- Nightly approval workflow (integrates with E3)
-- ================================================================

CREATE TABLE IF NOT EXISTS social_approval_requests (
    approval_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    event_id UUID,  -- From intelligence_brain_events (E20)
    
    -- Draft Posts (3 options)
    draft_posts JSONB NOT NULL,  -- Array of 3 post variations
    
    -- Approval Status
    status VARCHAR(20) DEFAULT 'pending',  -- 'pending', 'approved', 'rejected', 'edited', 'expired'
    selected_option INTEGER,  -- 1, 2, or 3
    final_post JSONB,  -- Approved version
    
    -- Approval Details
    approval_method VARCHAR(50),  -- 'manual_option_1', 'manual_approve_best', 'auto_approved', 'edited'
    response_text TEXT,  -- Actual text candidate sent
    response_received_at TIMESTAMP,
    approved_at TIMESTAMP,
    
    -- Notification
    sent_via_sms BOOLEAN DEFAULT false,
    sent_via_email BOOLEAN DEFAULT false,
    sent_at TIMESTAMP,
    
    -- Scheduling
    scheduled BOOLEAN DEFAULT false,
    scheduled_at TIMESTAMP,
    
    -- Deadline
    auto_approve_deadline TIMESTAMP,  -- Usually 11:00 PM same day
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_approvals_candidate ON social_approval_requests(candidate_id);
CREATE INDEX IF NOT EXISTS idx_approvals_status ON social_approval_requests(status);
CREATE INDEX IF NOT EXISTS idx_approvals_deadline ON social_approval_requests(auto_approve_deadline);
CREATE INDEX IF NOT EXISTS idx_approvals_created ON social_approval_requests(created_at);

COMMENT ON TABLE social_approval_requests IS 
    'E19: Nightly approval requests sent to candidates (integrates with E3 Marketing)';

-- ================================================================
-- INTELLIGENCE BRAIN EVENTS (For Social Triggers)
-- Events from E20 that trigger social posts
-- ================================================================

CREATE TABLE IF NOT EXISTS intelligence_brain_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Event Info
    title VARCHAR(500) NOT NULL,
    summary TEXT,
    category VARCHAR(100),  -- 'crisis', 'endorsement', 'town_hall', 'fundraising', etc.
    
    -- Urgency
    urgency INTEGER CHECK (urgency BETWEEN 1 AND 10),
    requires_immediate_response BOOLEAN DEFAULT false,
    
    -- Geographic Scope
    scope VARCHAR(50),  -- 'local', 'county', 'district', 'statewide', 'national'
    county VARCHAR(100),
    district VARCHAR(100),
    
    -- Social Media Trigger
    requires_social_post BOOLEAN DEFAULT false,
    recommended_platforms TEXT[],
    
    -- Source
    source_type VARCHAR(50),  -- 'news', 'user_input', 'automated_detection'
    source_url TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_brain_events_date ON intelligence_brain_events(created_at);
CREATE INDEX IF NOT EXISTS idx_brain_events_social ON intelligence_brain_events(requires_social_post);
CREATE INDEX IF NOT EXISTS idx_brain_events_urgency ON intelligence_brain_events(urgency);
CREATE INDEX IF NOT EXISTS idx_brain_events_scope ON intelligence_brain_events(scope, county);

COMMENT ON TABLE intelligence_brain_events IS 
    'E19/E20: Events from Intelligence Brain requiring social posts';

-- ================================================================
-- CANDIDATE MEDIA LIBRARY
-- Photos/videos for social posts
-- ================================================================

CREATE TABLE IF NOT EXISTS candidate_media_library (
    media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    
    -- Media Info
    media_type VARCHAR(20),  -- 'photo', 'video', 'graphic'
    media_url TEXT NOT NULL,
    thumbnail_url TEXT,
    
    -- Categorization
    category VARCHAR(50),  -- 'professional', 'casual', 'event', 'family', 'action'
    tone VARCHAR(50),  -- 'serious', 'friendly', 'energetic', 'thoughtful'
    subjects TEXT[],  -- Who/what is in the media
    
    -- Usage
    times_used INTEGER DEFAULT 0,
    last_used_at TIMESTAMP,
    performance_score DECIMAL(5,2),  -- Based on engagement when used
    
    -- Metadata
    uploaded_at TIMESTAMP DEFAULT NOW(),
    uploaded_by UUID,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_media_candidate ON candidate_media_library(candidate_id);
CREATE INDEX IF NOT EXISTS idx_media_category ON candidate_media_library(category);
CREATE INDEX IF NOT EXISTS idx_media_performance ON candidate_media_library(performance_score DESC);

COMMENT ON TABLE candidate_media_library IS 
    'E19: Photos/videos available for social media posts';

-- ================================================================
-- SOCIAL ENGAGEMENT TRACKING
-- ================================================================

CREATE TABLE IF NOT EXISTS social_engagement_log (
    engagement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES social_posts(post_id),
    
    -- Engagement Type
    engagement_type VARCHAR(20),  -- 'like', 'comment', 'share', 'click', 'view'
    
    -- User Info (if available)
    user_platform_id VARCHAR(255),
    user_name VARCHAR(255),
    
    -- Comment Content (if applicable)
    comment_text TEXT,
    sentiment VARCHAR(20),  -- 'positive', 'negative', 'neutral'
    
    -- Metadata
    engaged_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_engagement_post ON social_engagement_log(post_id);
CREATE INDEX IF NOT EXISTS idx_engagement_type ON social_engagement_log(engagement_type);
CREATE INDEX IF NOT EXISTS idx_engagement_date ON social_engagement_log(engaged_at);

COMMENT ON TABLE social_engagement_log IS 
    'E19: Tracks all engagement (likes, comments, shares)';

-- ================================================================
-- FACEBOOK COMPLIANCE TRACKING
-- ================================================================

CREATE TABLE IF NOT EXISTS facebook_compliance_log (
    compliance_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES social_posts(post_id),
    candidate_id UUID REFERENCES candidates(candidate_id),
    
    -- Compliance Checks
    rate_limit_check BOOLEAN,
    spacing_check BOOLEAN,
    duplicate_check BOOLEAN,
    hashtag_check BOOLEAN,
    disclaimer_check BOOLEAN,
    ai_disclosure_check BOOLEAN,
    engagement_bait_check BOOLEAN,
    
    -- Results
    passed_all_checks BOOLEAN,
    issues JSONB,
    warnings JSONB,
    
    -- Actions Taken
    auto_fixed BOOLEAN DEFAULT false,
    fixes_applied JSONB,
    
    -- Timing
    checked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_compliance_post ON facebook_compliance_log(post_id);
CREATE INDEX IF NOT EXISTS idx_compliance_passed ON facebook_compliance_log(passed_all_checks);
CREATE INDEX IF NOT EXISTS idx_compliance_date ON facebook_compliance_log(checked_at);

COMMENT ON TABLE facebook_compliance_log IS 
    'E19: Facebook political ad compliance checks';

-- ================================================================
-- POST PERFORMANCE ANALYTICS
-- ================================================================

CREATE TABLE IF NOT EXISTS social_post_performance (
    performance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES social_posts(post_id),
    
    -- Reach
    impressions INTEGER DEFAULT 0,
    reach INTEGER DEFAULT 0,
    
    -- Engagement
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    
    -- Rates
    engagement_rate DECIMAL(5,2),  -- (likes + comments + shares) / reach
    click_through_rate DECIMAL(5,2),  -- clicks / impressions
    
    -- Conversions (Attribution to E2 Donation Tracking)
    donations_attributed INTEGER DEFAULT 0,
    donation_amount_attributed DECIMAL(10,2),
    volunteer_signups_attributed INTEGER DEFAULT 0,
    
    -- Cost
    estimated_reach_value DECIMAL(10,2),
    roi DECIMAL(10,2),
    
    -- Update Timestamp
    last_updated TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_performance_post ON social_post_performance(post_id);
CREATE INDEX IF NOT EXISTS idx_performance_engagement ON social_post_performance(engagement_rate DESC);
CREATE INDEX IF NOT EXISTS idx_performance_roi ON social_post_performance(roi DESC);

COMMENT ON TABLE social_post_performance IS 
    'E19: Analytics and ROI tracking for social media posts';

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_e19_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
DROP TRIGGER IF EXISTS update_social_accounts_updated_at ON candidate_social_accounts;
CREATE TRIGGER update_social_accounts_updated_at 
    BEFORE UPDATE ON candidate_social_accounts
    FOR EACH ROW EXECUTE FUNCTION update_e19_updated_at();

DROP TRIGGER IF EXISTS update_style_profiles_updated_at ON candidate_style_profiles;
CREATE TRIGGER update_style_profiles_updated_at 
    BEFORE UPDATE ON candidate_style_profiles
    FOR EACH ROW EXECUTE FUNCTION update_e19_updated_at();

DROP TRIGGER IF EXISTS update_posts_updated_at ON social_posts;
CREATE TRIGGER update_posts_updated_at 
    BEFORE UPDATE ON social_posts
    FOR EACH ROW EXECUTE FUNCTION update_e19_updated_at();

DROP TRIGGER IF EXISTS update_approvals_updated_at ON social_approval_requests;
CREATE TRIGGER update_approvals_updated_at 
    BEFORE UPDATE ON social_approval_requests
    FOR EACH ROW EXECUTE FUNCTION update_e19_updated_at();

-- ================================================================
-- VIEWS FOR COMMON QUERIES
-- ================================================================

-- Daily posting summary
CREATE OR REPLACE VIEW v_e19_daily_posting_summary AS
SELECT 
    DATE(posted_at) as post_date,
    platform,
    COUNT(*) as total_posts,
    COUNT(DISTINCT candidate_id) as unique_candidates,
    SUM(likes_count) as total_likes,
    SUM(comments_count) as total_comments,
    SUM(shares_count) as total_shares,
    AVG(engagement_score) as avg_engagement
FROM social_posts
WHERE status = 'published'
GROUP BY DATE(posted_at), platform
ORDER BY post_date DESC, platform;

-- Candidate social health
CREATE OR REPLACE VIEW v_e19_candidate_social_health AS
SELECT 
    c.candidate_id,
    c.name as candidate_name,
    csa.facebook_political_auth_status,
    csa.auto_approve_enabled,
    COUNT(sp.post_id) as posts_30_days,
    AVG(sp.engagement_score) as avg_engagement,
    MAX(sp.posted_at) as last_post_date
FROM candidates c
LEFT JOIN candidate_social_accounts csa ON c.candidate_id = csa.candidate_id
LEFT JOIN social_posts sp ON c.candidate_id = sp.candidate_id 
    AND sp.posted_at >= NOW() - INTERVAL '30 days'
    AND sp.status = 'published'
GROUP BY c.candidate_id, c.name, csa.facebook_political_auth_status, csa.auto_approve_enabled;

-- Compliance summary
CREATE OR REPLACE VIEW v_e19_compliance_summary AS
SELECT 
    DATE(checked_at) as check_date,
    COUNT(*) as total_checks,
    SUM(CASE WHEN passed_all_checks THEN 1 ELSE 0 END) as passed,
    SUM(CASE WHEN NOT passed_all_checks THEN 1 ELSE 0 END) as failed,
    ROUND(100.0 * SUM(CASE WHEN passed_all_checks THEN 1 ELSE 0 END) / COUNT(*), 2) as pass_rate
FROM facebook_compliance_log
GROUP BY DATE(checked_at)
ORDER BY check_date DESC;

-- ================================================================
-- SCHEMA COMPLETE
-- ================================================================

-- Summary comment
COMMENT ON SCHEMA public IS 
    'BroyhillGOP Platform - Ecosystem 19: Social Media Manager schema added. 
     10 tables, 25+ indexes, 3 views. 
     Integrates with E0 DataHub, E3 Marketing, E13 AI Hub, E20 Intelligence Brain.';
