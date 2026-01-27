-- ============================================================================
-- E19 SOCIAL MEDIA INTEGRATION SCHEMA
-- ============================================================================

-- Video generation requests
CREATE TABLE IF NOT EXISTS social_video_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    script_text TEXT NOT NULL,
    voice_profile_id VARCHAR(100),
    portrait_image_url TEXT,
    motion_preset VARCHAR(50) DEFAULT 'conversational',
    emotion VARCHAR(50) DEFAULT 'neutral',
    platforms JSONB DEFAULT '["facebook", "twitter"]',
    status VARCHAR(50) DEFAULT 'requested',
    voice_audio_url TEXT,
    video_url TEXT,
    thumbnail_url TEXT,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_video_requests_candidate ON social_video_requests(candidate_id);
CREATE INDEX IF NOT EXISTS idx_video_requests_status ON social_video_requests(status);

-- Nightly approval queue
CREATE TABLE IF NOT EXISTS social_nightly_posts (
    post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    content_type VARCHAR(50) DEFAULT 'text',
    caption TEXT NOT NULL,
    media_url TEXT,
    platforms JSONB DEFAULT '[]',
    trigger_event VARCHAR(100),
    priority INTEGER DEFAULT 5,
    status VARCHAR(50) DEFAULT 'draft',
    approval_sms_sent BOOLEAN DEFAULT false,
    approval_sms_sent_at TIMESTAMP,
    approved_at TIMESTAMP,
    approved_by VARCHAR(50),
    rejection_reason TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nightly_posts_candidate ON social_nightly_posts(candidate_id);
CREATE INDEX IF NOT EXISTS idx_nightly_posts_status ON social_nightly_posts(status);

-- E19 event subscriptions tracking
CREATE TABLE IF NOT EXISTS social_event_subscriptions (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL UNIQUE,
    priority VARCHAR(20) DEFAULT 'NORMAL',
    action VARCHAR(100) NOT NULL,
    auto_approve BOOLEAN DEFAULT false,
    description TEXT,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert default subscriptions
INSERT INTO social_event_subscriptions (event_type, priority, action, auto_approve, description) VALUES
    ('news.crisis_detected', 'URGENT', 'generate_rapid_response', false, 'Crisis detected - generate defensive social post'),
    ('news.positive_coverage', 'HIGH', 'amplify_positive_news', true, 'Positive press - amplify with social post'),
    ('news.opponent_gaffe', 'HIGH', 'generate_contrast_post', false, 'Opponent mistake - generate contrast content'),
    ('news.endorsement_coverage', 'NORMAL', 'share_endorsement', true, 'Endorsement news - share across platforms'),
    ('news.issue_trending', 'NORMAL', 'join_trending_topic', false, 'Issue trending - create relevant content'),
    ('brain.social_post_requested', 'NORMAL', 'generate_and_schedule', false, 'Brain requested social post generation'),
    ('brain.video_post_requested', 'HIGH', 'generate_ai_video_post', false, 'Brain requested AI video post'),
    ('video.synthesis_complete', 'HIGH', 'post_generated_video', false, 'AI video ready - post to social'),
    ('video.export_ready', 'NORMAL', 'post_recorded_video', false, 'Recorded video ready for social'),
    ('broadcast.clip_extracted', 'NORMAL', 'post_broadcast_clip', true, 'Live broadcast clip ready')
ON CONFLICT (event_type) DO NOTHING;

-- E40 Control Panel features for E19
CREATE TABLE IF NOT EXISTS control_panel_features (
    feature_id VARCHAR(100) PRIMARY KEY,
    ecosystem VARCHAR(10) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    feature_type VARCHAR(50) DEFAULT 'toggle',
    default_value TEXT,
    current_value TEXT,
    category VARCHAR(50),
    enabled BOOLEAN DEFAULT true,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert E19 control panel features
INSERT INTO control_panel_features (feature_id, ecosystem, name, description, feature_type, default_value, category) VALUES
    ('social_auto_generate', 'E19', 'Auto-Generate Posts', 'AI automatically generates social posts from news and events', 'toggle', 'true', 'automation'),
    ('social_nightly_workflow', 'E19', 'Nightly Approval Workflow', 'Generate posts at 8PM, send for approval, auto-approve at 11PM', 'schedule', '20:00', 'automation'),
    ('social_auto_approve_11pm', 'E19', 'Auto-Approve at 11PM', 'Automatically approve pending posts at 11PM if no response', 'toggle', 'true', 'automation'),
    ('social_facebook_enabled', 'E19', 'Facebook Posting', 'Enable posting to Facebook Pages', 'toggle', 'true', 'platforms'),
    ('social_twitter_enabled', 'E19', 'Twitter/X Posting', 'Enable posting to Twitter/X', 'toggle', 'true', 'platforms'),
    ('social_instagram_enabled', 'E19', 'Instagram Posting', 'Enable posting to Instagram', 'toggle', 'true', 'platforms'),
    ('social_linkedin_enabled', 'E19', 'LinkedIn Posting', 'Enable posting to LinkedIn', 'toggle', 'true', 'platforms'),
    ('social_ai_video_enabled', 'E19', 'AI Video Generation', 'Generate AI talking head videos for posts', 'toggle', 'true', 'ai'),
    ('social_voice_clone_enabled', 'E19', 'Voice Cloning', 'Use AI voice cloning for video posts', 'toggle', 'true', 'ai'),
    ('social_strict_compliance', 'E19', 'Strict Compliance Mode', 'Enforce all Facebook political ad rules', 'toggle', 'true', 'compliance'),
    ('social_crisis_response_enabled', 'E19', 'Crisis Auto-Response', 'Automatically generate posts for crisis events', 'toggle', 'true', 'automation')
ON CONFLICT (feature_id) DO NOTHING;

-- Voice profiles for candidates
CREATE TABLE IF NOT EXISTS candidate_voice_profiles (
    profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL UNIQUE,
    voice_id VARCHAR(100) NOT NULL,
    reference_audio_url TEXT,
    quality_score INTEGER DEFAULT 95,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Candidate portrait images
CREATE TABLE IF NOT EXISTS candidate_portraits (
    portrait_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    image_url TEXT NOT NULL,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE social_video_requests IS 'E19 Integration: AI video generation requests via E47/E48 pipeline';
COMMENT ON TABLE social_nightly_posts IS 'E19 Integration: Nightly approval workflow queue';
COMMENT ON TABLE social_event_subscriptions IS 'E19 Integration: Event subscriptions from E42/E20/E45/E46/E48';
COMMENT ON TABLE control_panel_features IS 'E40: Control Panel feature toggles for all ecosystems';
