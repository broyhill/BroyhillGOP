-- ECOSYSTEM_38_SOCIAL_MEDIA_COMPLETE_SCHEMA.sql
-- Database schema for Social Media Arsenal & Marketing Automation
-- BroyhillGOP Platform

-- ================================================================
-- CANDIDATE SOCIAL ACCOUNTS
-- ================================================================

CREATE TABLE candidate_social_accounts (
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

CREATE INDEX idx_social_accounts_facebook_auth ON candidate_social_accounts(facebook_political_auth_status);
CREATE INDEX idx_social_accounts_auto_approve ON candidate_social_accounts(auto_approve_enabled);

-- ================================================================
-- CANDIDATE STYLE PROFILES
-- ================================================================

CREATE TABLE candidate_style_profiles (
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

CREATE INDEX idx_style_profiles_analyzed ON candidate_style_profiles(analyzed_at);

-- ================================================================
-- SOCIAL POSTS (Posted Content)
-- ================================================================

CREATE TABLE social_posts (
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
    
    -- Approval Info
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

CREATE INDEX idx_posts_candidate ON social_posts(candidate_id);
CREATE INDEX idx_posts_platform ON social_posts(platform);
CREATE INDEX idx_posts_status ON social_posts(status);
CREATE INDEX idx_posts_scheduled ON social_posts(scheduled_for);
CREATE INDEX idx_posts_posted ON social_posts(posted_at);
CREATE INDEX idx_posts_content_hash ON social_posts(content_hash);

-- Prevent duplicate content
CREATE UNIQUE INDEX idx_posts_unique_content ON social_posts(candidate_id, content_hash, platform)
WHERE status IN ('scheduled', 'published');

-- ================================================================
-- SOCIAL APPROVAL REQUESTS
-- ================================================================

CREATE TABLE social_approval_requests (
    approval_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES candidates(candidate_id),
    event_id UUID,  -- From intelligence_brain_events
    
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

CREATE INDEX idx_approvals_candidate ON social_approval_requests(candidate_id);
CREATE INDEX idx_approvals_status ON social_approval_requests(status);
CREATE INDEX idx_approvals_deadline ON social_approval_requests(auto_approve_deadline);
CREATE INDEX idx_approvals_created ON social_approval_requests(created_at);

-- ================================================================
-- INTELLIGENCE BRAIN EVENTS (For Social Triggers)
-- ================================================================

CREATE TABLE intelligence_brain_events (
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

CREATE INDEX idx_brain_events_date ON intelligence_brain_events(created_at);
CREATE INDEX idx_brain_events_social ON intelligence_brain_events(requires_social_post);
CREATE INDEX idx_brain_events_urgency ON intelligence_brain_events(urgency);
CREATE INDEX idx_brain_events_scope ON intelligence_brain_events(scope, county);

-- ================================================================
-- CANDIDATE MEDIA LIBRARY
-- ================================================================

CREATE TABLE candidate_media_library (
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

CREATE INDEX idx_media_candidate ON candidate_media_library(candidate_id);
CREATE INDEX idx_media_category ON candidate_media_library(category);
CREATE INDEX idx_media_performance ON candidate_media_library(performance_score DESC);

-- ================================================================
-- SOCIAL ENGAGEMENT TRACKING
-- ================================================================

CREATE TABLE social_engagement_log (
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

CREATE INDEX idx_engagement_post ON social_engagement_log(post_id);
CREATE INDEX idx_engagement_type ON social_engagement_log(engagement_type);
CREATE INDEX idx_engagement_date ON social_engagement_log(engaged_at);

-- ================================================================
-- FACEBOOK COMPLIANCE TRACKING
-- ================================================================

CREATE TABLE facebook_compliance_log (
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

CREATE INDEX idx_compliance_post ON facebook_compliance_log(post_id);
CREATE INDEX idx_compliance_passed ON facebook_compliance_log(passed_all_checks);
CREATE INDEX idx_compliance_date ON facebook_compliance_log(checked_at);

-- ================================================================
-- POST PERFORMANCE ANALYTICS
-- ================================================================

CREATE TABLE social_post_performance (
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
    
    -- Conversions
    donations_attributed INTEGER DEFAULT 0,
    donation_amount_attributed DECIMAL(10,2),
    volunteer_signups_attributed INTEGER DEFAULT 0,
    
    -- Cost
    estimated_reach_value DECIMAL(10,2),
    roi DECIMAL(10,2),
    
    -- Update Timestamp
    last_updated TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_performance_post ON social_post_performance(post_id);
CREATE INDEX idx_performance_engagement ON social_post_performance(engagement_rate DESC);
CREATE INDEX idx_performance_roi ON social_post_performance(roi DESC);

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

-- Update timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables
CREATE TRIGGER update_social_accounts_updated_at BEFORE UPDATE ON candidate_social_accounts
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_style_profiles_updated_at BEFORE UPDATE ON candidate_style_profiles
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON social_posts
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_approvals_updated_at BEFORE UPDATE ON social_approval_requests
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- SAMPLE DATA FOR TESTING
-- ================================================================

-- Insert sample candidate social account
INSERT INTO candidate_social_accounts (candidate_id, facebook_page_id, facebook_political_auth_status, auto_approve_enabled, approval_phone, approval_email)
VALUES (
    '123e4567-e89b-12d3-a456-426614174000'::uuid,  -- Sample candidate ID
    '123456789',
    'approved',
    true,
    '+19195551234',
    'john.smith@example.com'
);

-- Insert sample style profile
INSERT INTO candidate_style_profiles (candidate_id, common_phrases, primary_emotions, formality_level, uses_emojis, favorite_emojis)
VALUES (
    '123e4567-e89b-12d3-a456-426614174000'::uuid,
    ARRAY['folks', 'here''s the thing', 'bottom line', 'let''s be clear'],
    ARRAY['determined', 'urgent', 'hopeful'],
    6,
    true,
    ARRAY['🇺🇸', '🔥', '💪']
);

COMMENT ON TABLE candidate_social_accounts IS 'Stores social media credentials and settings for each candidate';
COMMENT ON TABLE candidate_style_profiles IS 'AI-learned writing style profiles for content generation';
COMMENT ON TABLE social_posts IS 'All social media posts (scheduled and published)';
COMMENT ON TABLE social_approval_requests IS 'Nightly approval requests sent to candidates';
COMMENT ON TABLE intelligence_brain_events IS 'Events detected by Intelligence Brain requiring social posts';
COMMENT ON TABLE candidate_media_library IS 'Photos/videos available for social posts';
COMMENT ON TABLE social_engagement_log IS 'Tracks all engagement (likes, comments, shares)';
COMMENT ON TABLE facebook_compliance_log IS 'Facebook political ad compliance checks';
COMMENT ON TABLE social_post_performance IS 'Analytics and ROI tracking for posts';
