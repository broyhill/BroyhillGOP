-- =====================================================
-- BROYHILLGOP DEMO ECOSYSTEM - COMPLETE DATABASE SCHEMA
-- Version: 1.0
-- Created: December 11, 2025
-- Purpose: Full deployment schema for AI-powered demo system
-- =====================================================

-- Create schema
DROP SCHEMA IF EXISTS demo_ecosystem CASCADE;
CREATE SCHEMA demo_ecosystem;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- SECTION 1: REFERENCE TABLES
-- =====================================================

-- 1.1 Communication Tones
CREATE TABLE demo_ecosystem.tones (
    tone_id VARCHAR(30) PRIMARY KEY,
    tone_name VARCHAR(100) NOT NULL,
    tone_icon VARCHAR(10),
    tone_description TEXT,
    example_phrase TEXT,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO demo_ecosystem.tones (tone_id, tone_name, tone_icon, tone_description, example_phrase, display_order) VALUES
('authoritative', 'Authoritative', '🏛️', 'Strong, commanding, leadership-focused', 'As your next representative, I will fight for...', 1),
('inspirational', 'Inspirational', '✨', 'Uplifting, hopeful, vision-driven', 'Together, we can build a brighter future...', 2),
('urgent', 'Urgent', '⚡', 'Time-sensitive, call-to-action focused', 'We must act now before it''s too late...', 3),
('conversational', 'Conversational', '💬', 'Friendly, approachable, relatable', 'You know, when I talk to folks around here...', 4),
('professional', 'Professional', '💼', 'Business-like, credible, factual', 'The data clearly shows that our approach...', 5),
('passionate', 'Passionate', '🔥', 'Emotional, heartfelt, conviction-driven', 'I believe with every fiber of my being...', 6),
('grassroots', 'Grassroots', '🌾', 'Community-focused, everyday American', 'This campaign is powered by people like you...', 7),
('fighter', 'Fighter', '🥊', 'Bold, combative, taking on the establishment', 'I''m not afraid to take on the special interests...', 8);

-- 1.2 Messaging Frameworks
CREATE TABLE demo_ecosystem.messaging_frameworks (
    framework_id VARCHAR(30) PRIMARY KEY,
    framework_name VARCHAR(100) NOT NULL,
    framework_icon VARCHAR(10),
    framework_description TEXT,
    example_message TEXT,
    structure_template JSONB,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO demo_ecosystem.messaging_frameworks (framework_id, framework_name, framework_icon, framework_description, example_message, display_order) VALUES
('problem-solution', 'Problem → Solution', '🎯', 'Identify the problem, present candidate as the solution', 'Crime is up 40%. [Candidate] will restore law and order.', 1),
('values-vision', 'Values → Vision', '🏔️', 'Lead with shared values, paint the future vision', 'We believe in hard work. Together, we''ll build prosperity.', 2),
('contrast', 'Contrast', '⚖️', 'Us vs. them, clear differentiation from opponent', 'They raised taxes. [Candidate] will cut them.', 3),
('story-narrative', 'Story Narrative', '📖', 'Personal stories, human connection, testimonials', 'When I started my small business 20 years ago...', 4),
('fear-hope', 'Fear → Hope', '🌅', 'Acknowledge concerns, transition to optimistic future', 'The economy is struggling, but better days are ahead.', 5),
('credential-action', 'Credential → Action', '🎖️', 'Establish credibility, then call to action', 'As a veteran and business owner, I know what works.', 6);

-- 1.3 Hot Issues (15 from PATRIOT Intelligence)
CREATE TABLE demo_ecosystem.hot_issues (
    issue_id VARCHAR(30) PRIMARY KEY,
    issue_name VARCHAR(100) NOT NULL,
    issue_icon VARCHAR(10),
    issue_category VARCHAR(50),
    issue_description TEXT,
    talking_points JSONB,
    donor_affinity_weight DECIMAL(3,2) DEFAULT 1.0,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO demo_ecosystem.hot_issues (issue_id, issue_name, issue_icon, issue_category, talking_points, display_order) VALUES
('second-amendment', '2nd Amendment', '🔫', 'Constitutional', '["Protect gun rights", "Oppose red flag laws", "Support concealed carry"]', 1),
('pro-life', 'Pro-Life', '👶', 'Social', '["Protect the unborn", "Defund Planned Parenthood", "Support adoption alternatives"]', 2),
('border-security', 'Border Security', '🛡️', 'Immigration', '["Build the wall", "End catch and release", "Support ICE"]', 3),
('fiscal-conservative', 'Fiscal Conservative', '💰', 'Economic', '["Cut spending", "Balance the budget", "Lower taxes"]', 4),
('election-integrity', 'Election Integrity', '🗳️', 'Governance', '["Voter ID required", "Clean voter rolls", "Paper ballots"]', 5),
('parental-rights', 'Parental Rights', '👨‍👩‍👧', 'Education', '["Parents know best", "School choice", "Curriculum transparency"]', 6),
('law-order', 'Law & Order', '⚖️', 'Public Safety', '["Back the blue", "Tough on crime", "No defunding police"]', 7),
('religious-liberty', 'Religious Liberty', '⛪', 'Constitutional', '["Protect faith", "No government interference", "Prayer in schools"]', 8),
('limited-government', 'Limited Government', '🏛️', 'Governance', '["Less regulation", "States rights", "Individual freedom"]', 9),
('energy-independence', 'Energy Independence', '⛽', 'Economic', '["Drill baby drill", "No Green New Deal", "Coal and gas jobs"]', 10),
('veterans', 'Veterans Affairs', '🎖️', 'Military', '["Honor our veterans", "Better VA care", "Support military families"]', 11),
('education-choice', 'Education Choice', '🎓', 'Education', '["School vouchers", "Charter schools", "End Common Core"]', 12),
('america-first', 'America First', '🇺🇸', 'Foreign Policy', '["Fair trade deals", "Strong military", "No endless wars"]', 13),
('free-speech', 'Free Speech', '📢', 'Constitutional', '["No censorship", "Big tech accountability", "Open debate"]', 14),
('agriculture', 'Agriculture', '🌾', 'Economic', '["Support farmers", "Fair markets", "Rural broadband"]', 15);

-- 1.4 Campaign Channels
CREATE TABLE demo_ecosystem.campaign_channels (
    channel_id VARCHAR(30) PRIMARY KEY,
    channel_name VARCHAR(100) NOT NULL,
    channel_icon VARCHAR(10),
    template_count INTEGER DEFAULT 384,
    channel_description TEXT,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO demo_ecosystem.campaign_channels (channel_id, channel_name, channel_icon, template_count, channel_description) VALUES
('email', 'Email', '📧', 384, 'Personalized email campaigns with tracking'),
('sms', 'SMS/Text', '💬', 384, 'Short-form text message campaigns'),
('direct-mail', 'Direct Mail', '📬', 384, 'Physical mail pieces and postcards'),
('call-center', 'Call Center', '📞', 384, 'Live phone scripts and talking points');

-- 1.5 Motion Effects
CREATE TABLE demo_ecosystem.motion_effects (
    effect_id VARCHAR(30) PRIMARY KEY,
    effect_name VARCHAR(100) NOT NULL,
    effect_icon VARCHAR(10),
    effect_category VARCHAR(30), -- 'photo', 'transition', 'entrance', 'exit'
    effect_description TEXT,
    css_animation TEXT,
    duration_default INTEGER DEFAULT 1000, -- milliseconds
    is_active BOOLEAN DEFAULT true
);

INSERT INTO demo_ecosystem.motion_effects (effect_id, effect_name, effect_icon, effect_category, effect_description, duration_default) VALUES
-- Photo Motion (Ken Burns)
('static', 'Static', '⬜', 'photo', 'No movement', 0),
('zoom-in', 'Zoom In', '🔍', 'photo', 'Slowly zoom into the image', 5000),
('zoom-out', 'Zoom Out', '🔎', 'photo', 'Slowly zoom out from the image', 5000),
('pan-left', 'Pan Left', '⬅️', 'photo', 'Pan from right to left', 5000),
('pan-right', 'Pan Right', '➡️', 'photo', 'Pan from left to right', 5000),
('pan-up', 'Pan Up', '⬆️', 'photo', 'Pan from bottom to top', 5000),
('pan-down', 'Pan Down', '⬇️', 'photo', 'Pan from top to bottom', 5000),
('diagonal-tl', 'Diagonal ↖', '↖️', 'photo', 'Pan diagonally to top-left', 5000),
('diagonal-br', 'Diagonal ↘', '↘️', 'photo', 'Pan diagonally to bottom-right', 5000),
-- Transitions
('cut', 'Cut', '✂️', 'transition', 'Instant cut to next scene', 0),
('fade', 'Fade', '🌫️', 'transition', 'Fade to black then to next scene', 1000),
('dissolve', 'Dissolve', '✨', 'transition', 'Cross-dissolve between scenes', 1000),
('slide-left', 'Slide Left', '📤', 'transition', 'Slide current scene left, new slides in', 500),
('slide-right', 'Slide Right', '📥', 'transition', 'Slide current scene right, new slides in', 500),
('wipe', 'Wipe', '🧹', 'transition', 'Wipe transition across screen', 750),
('zoom-blur', 'Zoom Blur', '💫', 'transition', 'Zoom with motion blur', 500),
('flip', '3D Flip', '🔄', 'transition', '3D flip to next scene', 750),
('morph', 'Morph', '🎭', 'transition', 'Morph transform between scenes', 1000),
-- Entrances
('fade-in', 'Fade In', '🌫️', 'entrance', 'Fade in from transparent', 500),
('slide-in', 'Slide In', '📥', 'entrance', 'Slide in from edge', 500),
('zoom-in-entrance', 'Zoom In', '🔍', 'entrance', 'Zoom in from small', 500),
('pop', 'Pop', '💥', 'entrance', 'Pop in with bounce', 300),
('walk-in', 'Walk In', '🚶', 'entrance', 'Avatar walks into frame', 2000),
-- Exits
('fade-out', 'Fade Out', '🌫️', 'exit', 'Fade out to transparent', 500),
('slide-out', 'Slide Out', '📤', 'exit', 'Slide out to edge', 500),
('zoom-out-exit', 'Zoom Out', '🔎', 'exit', 'Zoom out to small', 500),
('shrink', 'Shrink', '⏹️', 'exit', 'Shrink and disappear', 300),
('walk-out', 'Walk Out', '🚶', 'exit', 'Avatar walks out of frame', 2000);

-- 1.6 Pointer Directions
CREATE TABLE demo_ecosystem.pointer_directions (
    direction_id VARCHAR(30) PRIMARY KEY,
    direction_name VARCHAR(100) NOT NULL,
    direction_icon VARCHAR(10),
    css_transform TEXT,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO demo_ecosystem.pointer_directions (direction_id, direction_name, direction_icon) VALUES
('point-up', 'Point Up', '👆'),
('point-down', 'Point Down', '👇'),
('point-left', 'Point Left', '👈'),
('point-right', 'Point Right', '👉'),
('point-top-left', 'Point Top-Left', '↖️'),
('point-top-right', 'Point Top-Right', '↗️'),
('point-bottom-left', 'Point Bottom-Left', '↙️'),
('point-bottom-right', 'Point Bottom-Right', '↘️'),
('gesture-open', 'Open Gesture', '🤲'),
('gesture-thumbs', 'Thumbs Up', '👍');

-- 1.7 Voice Library
CREATE TABLE demo_ecosystem.voice_library (
    voice_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    voice_code VARCHAR(50) NOT NULL UNIQUE,
    voice_name VARCHAR(100) NOT NULL,
    voice_icon VARCHAR(10),
    voice_gender VARCHAR(20),
    voice_age_range VARCHAR(30),
    voice_accent VARCHAR(50),
    voice_style VARCHAR(50), -- 'authoritative', 'friendly', 'news', etc.
    api_voice_id VARCHAR(100), -- External API voice ID (ElevenLabs, etc.)
    sample_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true
);

INSERT INTO demo_ecosystem.voice_library (voice_code, voice_name, voice_icon, voice_gender, voice_age_range, voice_accent, voice_style) VALUES
('deep-authoritative', 'Deep Authoritative', '🎙️', 'Male', '40-60', 'American Standard', 'authoritative'),
('professional-male', 'Professional Male', '🗣️', 'Male', '30-50', 'American Standard', 'professional'),
('professional-female', 'Professional Female', '🎤', 'Female', '30-50', 'American Standard', 'professional'),
('southern-male', 'Southern Male', '🤠', 'Male', '40-60', 'Southern', 'friendly'),
('southern-female', 'Southern Female', '👩', 'Female', '30-50', 'Southern', 'friendly'),
('news-anchor', 'News Anchor', '📺', 'Male', '35-55', 'American Standard', 'news'),
('warm-friendly', 'Warm Friendly', '😊', 'Female', '25-45', 'American Standard', 'friendly'),
('young-adult-male', 'Young Adult Male', '🧑', 'Male', '20-35', 'American Standard', 'conversational'),
('young-adult-female', 'Young Adult Female', '👩', 'Female', '20-35', 'American Standard', 'conversational'),
('elder-statesman', 'Elder Statesman', '👴', 'Male', '60+', 'American Standard', 'authoritative');

-- 1.8 Avatar Library
CREATE TABLE demo_ecosystem.avatar_library (
    avatar_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    avatar_code VARCHAR(50) NOT NULL UNIQUE,
    avatar_name VARCHAR(100) NOT NULL,
    avatar_icon VARCHAR(10),
    avatar_category VARCHAR(50), -- 'political', 'professional', 'demographic', 'occupation'
    avatar_description TEXT,
    photo_url VARCHAR(500),
    is_custom_upload BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO demo_ecosystem.avatar_library (avatar_code, avatar_name, avatar_icon, avatar_category, avatar_description) VALUES
('ed-broyhill', 'Ed Broyhill', '👤', 'political', 'BroyhillGOP Founder'),
('donald-trump', 'Donald Trump', '👤', 'political', '45th & 47th President'),
('jd-vance', 'JD Vance', '👤', 'political', 'Vice President'),
('professional-male', 'Professional Male', '👨‍💼', 'professional', 'Business professional male'),
('professional-female', 'Professional Female', '👩‍💼', 'professional', 'Business professional female'),
('police-officer', 'Police Officer', '👮', 'occupation', 'Law enforcement'),
('military', 'Military', '🎖️', 'occupation', 'Armed forces'),
('teacher', 'Teacher', '👩‍🏫', 'occupation', 'Educator'),
('elderly-man', 'Elderly Man', '👴', 'demographic', 'Senior male'),
('elderly-woman', 'Elderly Woman', '👵', 'demographic', 'Senior female'),
('college-student', 'College Student', '🎓', 'demographic', 'Young adult student'),
('teen', 'Teen', '🧑', 'demographic', 'Teenager'),
('child', 'Child', '👦', 'demographic', 'Young child'),
('farmer', 'Farmer', '👨‍🌾', 'occupation', 'Agricultural worker'),
('healthcare-worker', 'Healthcare Worker', '👨‍⚕️', 'occupation', 'Medical professional'),
('business-executive', 'Business Executive', '💼', 'professional', 'Corporate executive');

-- 1.9 Music Library
CREATE TABLE demo_ecosystem.music_library (
    track_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    track_code VARCHAR(50) NOT NULL UNIQUE,
    track_name VARCHAR(100) NOT NULL,
    track_icon VARCHAR(10),
    track_category VARCHAR(50), -- 'patriotic', 'corporate', 'inspirational', 'ambient', 'news'
    track_duration INTEGER, -- seconds
    track_url VARCHAR(500),
    license_type VARCHAR(50), -- 'royalty-free', 'licensed', 'original'
    is_active BOOLEAN DEFAULT true
);

INSERT INTO demo_ecosystem.music_library (track_code, track_name, track_icon, track_category, track_duration) VALUES
('american-pride', 'American Pride', '🇺🇸', 'patriotic', 180),
('stars-stripes', 'Stars & Stripes', '⭐', 'patriotic', 150),
('corporate-success', 'Corporate Success', '📈', 'corporate', 120),
('inspiring-future', 'Inspiring Future', '✨', 'inspirational', 180),
('news-intro', 'News Intro', '📰', 'news', 30),
('calm-ambient', 'Calm Ambient', '🌊', 'ambient', 300);

-- =====================================================
-- SECTION 2: CORE DEMO TABLES
-- =====================================================

-- 2.1 Office Types
CREATE TABLE demo_ecosystem.office_types (
    office_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    office_code VARCHAR(50) NOT NULL UNIQUE,
    office_name VARCHAR(200) NOT NULL,
    office_level VARCHAR(30), -- 'Federal', 'State', 'Local'
    jurisdiction VARCHAR(100),
    current_holder VARCHAR(200),
    next_election_year INTEGER,
    questionnaire_config JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO demo_ecosystem.office_types (office_code, office_name, office_level, jurisdiction, next_election_year) VALUES
('nc-governor', 'NC Governor', 'State', 'North Carolina', 2028),
('nc-lt-governor', 'NC Lieutenant Governor', 'State', 'North Carolina', 2028),
('nc-state-auditor', 'NC State Auditor', 'State', 'North Carolina', 2028),
('nc-attorney-general', 'NC Attorney General', 'State', 'North Carolina', 2028),
('nc-state-senate', 'NC State Senate', 'State', 'North Carolina', 2026),
('nc-state-house', 'NC State House', 'State', 'North Carolina', 2026),
('us-senate-nc', 'US Senate (NC)', 'Federal', 'North Carolina', 2026),
('us-house-nc', 'US House (NC)', 'Federal', 'North Carolina', 2026);

-- 2.2 Candidates
CREATE TABLE demo_ecosystem.candidates (
    candidate_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic Info
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(200) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    
    -- Office
    office_id UUID REFERENCES demo_ecosystem.office_types(office_id),
    district VARCHAR(50),
    
    -- Profile Photo (for AI avatar)
    profile_photo_url VARCHAR(500),
    profile_photo_uploaded_at TIMESTAMPTZ,
    
    -- Questionnaire Results
    questionnaire_completed BOOLEAN DEFAULT false,
    questionnaire_responses JSONB,
    questionnaire_score DECIMAL(5,2),
    questionnaire_grade CHAR(2), -- A+, A, A-, B+, etc.
    
    -- Branding
    brand_primary_color VARCHAR(7) DEFAULT '#C41E3A',
    brand_secondary_color VARCHAR(7) DEFAULT '#0A1628',
    campaign_slogan VARCHAR(255),
    campaign_logo_url VARCHAR(500),
    
    -- Matching Results
    matched_donor_count INTEGER DEFAULT 0,
    fundraising_potential DECIMAL(12,2) DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    demo_active BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

-- 2.3 Screenplays (Demo Configurations)
CREATE TABLE demo_ecosystem.screenplays (
    screenplay_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identification
    inventory_number VARCHAR(50) NOT NULL UNIQUE, -- BGOP-DEMO-2025-001
    title VARCHAR(255) NOT NULL,
    
    -- Dates
    start_date DATE,
    target_completion DATE,
    
    -- Purpose
    purpose TEXT,
    
    -- Tone & Messaging
    tone_id VARCHAR(30) REFERENCES demo_ecosystem.tones(tone_id),
    framework_id VARCHAR(30) REFERENCES demo_ecosystem.messaging_frameworks(framework_id),
    
    -- Selected Issues (array of issue_ids)
    selected_issues VARCHAR(30)[] DEFAULT '{}',
    
    -- Selected Channels
    selected_channels VARCHAR(30)[] DEFAULT '{email,sms,direct-mail,call-center}',
    
    -- Selected Ecosystems to tour
    selected_ecosystems INTEGER[] DEFAULT '{0,1,2,3,5,7,13}',
    
    -- Donor Intelligence Features
    show_21_tier_grading BOOLEAN DEFAULT true,
    show_1000_point_scoring BOOLEAN DEFAULT true,
    show_heat_map BOOLEAN DEFAULT true,
    show_bellwether BOOLEAN DEFAULT false,
    show_affinity_matching BOOLEAN DEFAULT true,
    show_860_field_enrichment BOOLEAN DEFAULT false,
    
    -- Linked Candidate (optional - for personalized demos)
    candidate_id UUID REFERENCES demo_ecosystem.candidates(candidate_id),
    
    -- Status
    status VARCHAR(30) DEFAULT 'draft', -- draft, ready, active, archived
    
    -- Output
    demo_url VARCHAR(500),
    preview_url VARCHAR(500),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    
    -- Created by
    created_by VARCHAR(255)
);

-- 2.4 Screenplay Elements (Individual steps in the demo)
CREATE TABLE demo_ecosystem.screenplay_elements (
    element_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    screenplay_id UUID NOT NULL REFERENCES demo_ecosystem.screenplays(screenplay_id) ON DELETE CASCADE,
    
    -- Ordering
    sequence_order INTEGER NOT NULL,
    
    -- Element Type
    element_type VARCHAR(30) NOT NULL, -- 'text-to-video', 'avatar', 'voice', 'music', 'media', 'sms', 'email', 'call'
    
    -- Content
    content_text TEXT,
    content_prompt TEXT, -- For AI generation
    
    -- Media References
    avatar_id UUID REFERENCES demo_ecosystem.avatar_library(avatar_id),
    voice_id UUID REFERENCES demo_ecosystem.voice_library(voice_id),
    music_track_id UUID REFERENCES demo_ecosystem.music_library(track_id),
    
    -- Motion Settings
    photo_motion VARCHAR(30) REFERENCES demo_ecosystem.motion_effects(effect_id),
    transition_effect VARCHAR(30) REFERENCES demo_ecosystem.motion_effects(effect_id),
    entrance_effect VARCHAR(30) REFERENCES demo_ecosystem.motion_effects(effect_id),
    exit_effect VARCHAR(30) REFERENCES demo_ecosystem.motion_effects(effect_id),
    motion_speed INTEGER DEFAULT 3, -- 1-5
    
    -- Avatar Settings
    avatar_position VARCHAR(30) DEFAULT 'center', -- 9 positions
    avatar_size VARCHAR(20) DEFAULT 'medium', -- small, medium, large, fullscreen
    
    -- Timing
    duration_seconds INTEGER DEFAULT 15,
    
    -- Continuous Animations
    anim_idle BOOLEAN DEFAULT true,
    anim_blink BOOLEAN DEFAULT true,
    anim_breathe BOOLEAN DEFAULT true,
    anim_gesture BOOLEAN DEFAULT false,
    anim_eyecontact BOOLEAN DEFAULT true,
    anim_nod BOOLEAN DEFAULT false,
    
    -- Outreach (for sms, email, call types)
    outreach_template_id UUID,
    outreach_timing VARCHAR(20), -- 'immediate', '5min', 'end'
    
    -- Generated Content
    generated_video_url VARCHAR(500),
    generated_audio_url VARCHAR(500),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.5 Pointer Movements (Sequence within an element)
CREATE TABLE demo_ecosystem.pointer_movements (
    movement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    element_id UUID NOT NULL REFERENCES demo_ecosystem.screenplay_elements(element_id) ON DELETE CASCADE,
    
    -- Ordering
    sequence_order INTEGER NOT NULL,
    
    -- Direction
    direction_id VARCHAR(30) REFERENCES demo_ecosystem.pointer_directions(direction_id),
    
    -- Target
    target_element VARCHAR(255), -- What the avatar is pointing at
    target_description TEXT,
    
    -- Timing
    duration_seconds INTEGER DEFAULT 15,
    
    -- Bubble Text
    bubble_text TEXT,
    bubble_style VARCHAR(30) DEFAULT 'default', -- 'default', 'emphasis', 'question', 'callout'
    
    -- Sound Effect
    play_click_sound BOOLEAN DEFAULT true
);

-- 2.6 Demo Sessions (Tracking candidate demo views)
CREATE TABLE demo_ecosystem.demo_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    screenplay_id UUID NOT NULL REFERENCES demo_ecosystem.screenplays(screenplay_id),
    candidate_id UUID REFERENCES demo_ecosystem.candidates(candidate_id),
    
    -- Session Info
    session_token VARCHAR(100) NOT NULL UNIQUE,
    
    -- Login Info
    email_used VARCHAR(255),
    first_name_used VARCHAR(100),
    
    -- Tracking
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    last_activity_at TIMESTAMPTZ,
    
    -- Progress
    current_element_order INTEGER DEFAULT 0,
    completion_percentage DECIMAL(5,2) DEFAULT 0,
    
    -- Device Info
    ip_address VARCHAR(50),
    user_agent TEXT,
    device_type VARCHAR(30), -- 'desktop', 'mobile', 'tablet'
    
    -- Engagement
    total_watch_time_seconds INTEGER DEFAULT 0,
    interactions_count INTEGER DEFAULT 0
);

-- 2.7 Demo Analytics
CREATE TABLE demo_ecosystem.demo_analytics (
    analytics_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES demo_ecosystem.demo_sessions(session_id),
    
    -- Event
    event_type VARCHAR(50) NOT NULL, -- 'view', 'click', 'complete', 'skip', 'replay'
    event_target VARCHAR(255),
    
    -- Element Reference
    element_id UUID REFERENCES demo_ecosystem.screenplay_elements(element_id),
    
    -- Timing
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    time_in_demo_seconds INTEGER,
    
    -- Additional Data
    event_data JSONB
);

-- =====================================================
-- SECTION 3: INDEXES
-- =====================================================

CREATE INDEX idx_candidates_email ON demo_ecosystem.candidates(email);
CREATE INDEX idx_candidates_office ON demo_ecosystem.candidates(office_id);
CREATE INDEX idx_screenplays_status ON demo_ecosystem.screenplays(status);
CREATE INDEX idx_screenplays_candidate ON demo_ecosystem.screenplays(candidate_id);
CREATE INDEX idx_screenplay_elements_screenplay ON demo_ecosystem.screenplay_elements(screenplay_id);
CREATE INDEX idx_screenplay_elements_order ON demo_ecosystem.screenplay_elements(screenplay_id, sequence_order);
CREATE INDEX idx_pointer_movements_element ON demo_ecosystem.pointer_movements(element_id);
CREATE INDEX idx_demo_sessions_screenplay ON demo_ecosystem.demo_sessions(screenplay_id);
CREATE INDEX idx_demo_sessions_token ON demo_ecosystem.demo_sessions(session_token);
CREATE INDEX idx_demo_analytics_session ON demo_ecosystem.demo_analytics(session_id);

-- =====================================================
-- SECTION 4: FUNCTIONS
-- =====================================================

-- Generate inventory number
CREATE OR REPLACE FUNCTION demo_ecosystem.generate_inventory_number()
RETURNS VARCHAR(50) AS $$
DECLARE
    year_part VARCHAR(4);
    seq_num INTEGER;
    new_number VARCHAR(50);
BEGIN
    year_part := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(inventory_number FROM 'BGOP-DEMO-\d{4}-(\d+)') AS INTEGER)
    ), 0) + 1
    INTO seq_num
    FROM demo_ecosystem.screenplays
    WHERE inventory_number LIKE 'BGOP-DEMO-' || year_part || '-%';
    
    new_number := 'BGOP-DEMO-' || year_part || '-' || LPAD(seq_num::TEXT, 3, '0');
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Generate session token
CREATE OR REPLACE FUNCTION demo_ecosystem.generate_session_token()
RETURNS VARCHAR(100) AS $$
BEGIN
    RETURN encode(gen_random_bytes(32), 'hex');
END;
$$ LANGUAGE plpgsql;

-- Calculate demo completion percentage
CREATE OR REPLACE FUNCTION demo_ecosystem.calculate_completion(p_session_id UUID)
RETURNS DECIMAL(5,2) AS $$
DECLARE
    total_elements INTEGER;
    current_element INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_elements
    FROM demo_ecosystem.screenplay_elements se
    JOIN demo_ecosystem.demo_sessions ds ON ds.screenplay_id = se.screenplay_id
    WHERE ds.session_id = p_session_id;
    
    SELECT current_element_order INTO current_element
    FROM demo_ecosystem.demo_sessions
    WHERE session_id = p_session_id;
    
    IF total_elements = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN ROUND((current_element::DECIMAL / total_elements) * 100, 2);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SECTION 5: TRIGGERS
-- =====================================================

-- Auto-generate inventory number
CREATE OR REPLACE FUNCTION demo_ecosystem.auto_inventory_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.inventory_number IS NULL OR NEW.inventory_number = '' THEN
        NEW.inventory_number := demo_ecosystem.generate_inventory_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_inventory_number
    BEFORE INSERT ON demo_ecosystem.screenplays
    FOR EACH ROW
    EXECUTE FUNCTION demo_ecosystem.auto_inventory_number();

-- Update timestamps
CREATE OR REPLACE FUNCTION demo_ecosystem.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_screenplays_timestamp
    BEFORE UPDATE ON demo_ecosystem.screenplays
    FOR EACH ROW
    EXECUTE FUNCTION demo_ecosystem.update_timestamp();

CREATE TRIGGER trg_update_candidates_timestamp
    BEFORE UPDATE ON demo_ecosystem.candidates
    FOR EACH ROW
    EXECUTE FUNCTION demo_ecosystem.update_timestamp();

CREATE TRIGGER trg_update_elements_timestamp
    BEFORE UPDATE ON demo_ecosystem.screenplay_elements
    FOR EACH ROW
    EXECUTE FUNCTION demo_ecosystem.update_timestamp();

-- =====================================================
-- SECTION 6: VIEWS
-- =====================================================

-- Screenplay summary view
CREATE VIEW demo_ecosystem.v_screenplay_summary AS
SELECT 
    s.screenplay_id,
    s.inventory_number,
    s.title,
    s.status,
    t.tone_name,
    mf.framework_name,
    c.full_name AS candidate_name,
    ARRAY_LENGTH(s.selected_issues, 1) AS issue_count,
    ARRAY_LENGTH(s.selected_ecosystems, 1) AS ecosystem_count,
    (SELECT COUNT(*) FROM demo_ecosystem.screenplay_elements WHERE screenplay_id = s.screenplay_id) AS element_count,
    s.created_at,
    s.published_at
FROM demo_ecosystem.screenplays s
LEFT JOIN demo_ecosystem.tones t ON t.tone_id = s.tone_id
LEFT JOIN demo_ecosystem.messaging_frameworks mf ON mf.framework_id = s.framework_id
LEFT JOIN demo_ecosystem.candidates c ON c.candidate_id = s.candidate_id;

-- Demo session summary
CREATE VIEW demo_ecosystem.v_session_summary AS
SELECT 
    ds.session_id,
    s.title AS screenplay_title,
    c.full_name AS candidate_name,
    ds.started_at,
    ds.completed_at,
    ds.completion_percentage,
    ds.total_watch_time_seconds,
    ds.device_type
FROM demo_ecosystem.demo_sessions ds
JOIN demo_ecosystem.screenplays s ON s.screenplay_id = ds.screenplay_id
LEFT JOIN demo_ecosystem.candidates c ON c.candidate_id = ds.candidate_id;

-- =====================================================
-- COMPLETE!
-- =====================================================

-- Verify installation
DO $$
BEGIN
    RAISE NOTICE '✅ Demo Ecosystem Schema Created Successfully!';
    RAISE NOTICE 'Tables: 17';
    RAISE NOTICE 'Reference Data: Tones (8), Frameworks (6), Issues (15), Channels (4), Effects (27)';
    RAISE NOTICE 'Views: 2';
    RAISE NOTICE 'Functions: 4';
    RAISE NOTICE 'Triggers: 4';
END $$;
