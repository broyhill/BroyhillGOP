-- ============================================================================
-- BROYHILLGOP ECOSYSTEMS 46-49: DATABASE SCHEMA
-- Broadcast Hub, AI Scripts, Communication DNA, Interview System
-- ============================================================================

-- ============================================================================
-- ECOSYSTEM 46: BROADCAST HUB - LIVE STREAMING & ENGAGEMENT
-- ============================================================================

-- Broadcast Events
CREATE TABLE IF NOT EXISTS broadcast_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(50) NOT NULL, -- town_hall, endorsement, celebrity_guest, q_and_a, rally, live_podcast
    scheduled_start TIMESTAMP NOT NULL,
    scheduled_end TIMESTAMP NOT NULL,
    platforms JSONB DEFAULT '[]', -- ["zoom", "facebook", "youtube", "rumble"]
    text_keywords JSONB DEFAULT '["EDDIE", "DONATE", "SIGN", "VOLUNTEER"]',
    enable_donations BOOLEAN DEFAULT true,
    donation_goal DECIMAL(12,2) DEFAULT 10000,
    enable_reactions BOOLEAN DEFAULT true,
    enable_polls BOOLEAN DEFAULT true,
    enable_team_builder BOOLEAN DEFAULT true,
    zoom_meeting_id VARCHAR(100),
    registration_url TEXT,
    status VARCHAR(50) DEFAULT 'draft', -- draft, scheduled, live, ended, cancelled
    total_viewers INTEGER DEFAULT 0,
    peak_viewers INTEGER DEFAULT 0,
    total_texts INTEGER DEFAULT 0,
    total_leads INTEGER DEFAULT 0,
    total_donations DECIMAL(12,2) DEFAULT 0,
    actual_start TIMESTAMP,
    actual_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_broadcast_events_status ON broadcast_events(status);
CREATE INDEX idx_broadcast_events_scheduled ON broadcast_events(scheduled_start);
CREATE INDEX idx_broadcast_events_campaign ON broadcast_events(campaign_id);

-- Text Keywords (50155)
CREATE TABLE IF NOT EXISTS text_keywords (
    keyword_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    keyword VARCHAR(50) NOT NULL UNIQUE,
    keyword_type VARCHAR(50) NOT NULL, -- general, donation, yard_sign, volunteer, rsvp, poll
    reply_message TEXT NOT NULL,
    link_url TEXT NOT NULL,
    lead_tags JSONB DEFAULT '[]',
    event_id UUID REFERENCES broadcast_events(event_id),
    total_texts INTEGER DEFAULT 0,
    total_clicks INTEGER DEFAULT 0,
    total_conversions INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_text_keywords_keyword ON text_keywords(keyword);
CREATE INDEX idx_text_keywords_active ON text_keywords(is_active);

-- Incoming Texts (50155)
CREATE TABLE IF NOT EXISTS incoming_texts (
    text_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) NOT NULL,
    message_body TEXT,
    keyword_matched VARCHAR(50),
    keyword_id UUID REFERENCES text_keywords(keyword_id),
    event_id UUID REFERENCES broadcast_events(event_id),
    referrer_member_id UUID,
    reply_sent BOOLEAN DEFAULT false,
    reply_message TEXT,
    link_sent TEXT,
    link_clicked BOOLEAN DEFAULT false,
    link_clicked_at TIMESTAMP,
    form_completed BOOLEAN DEFAULT false,
    form_completed_at TIMESTAMP,
    contact_id UUID, -- E1 Donor Intelligence link
    received_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_incoming_texts_phone ON incoming_texts(phone_number);
CREATE INDEX idx_incoming_texts_keyword ON incoming_texts(keyword_matched);
CREATE INDEX idx_incoming_texts_event ON incoming_texts(event_id);

-- Live Donations
CREATE TABLE IF NOT EXISTS live_donations (
    donation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES broadcast_events(event_id),
    amount DECIMAL(10,2) NOT NULL,
    donor_name VARCHAR(255),
    donor_email VARCHAR(255),
    message TEXT,
    source VARCHAR(50) DEFAULT 'direct', -- qr_code, text, facebook, youtube
    is_anonymous BOOLEAN DEFAULT false,
    matched BOOLEAN DEFAULT false,
    matched_amount DECIMAL(10,2) DEFAULT 0,
    referrer_member_id UUID,
    contact_id UUID,
    displayed_on_screen BOOLEAN DEFAULT false,
    donated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_live_donations_event ON live_donations(event_id);
CREATE INDEX idx_live_donations_donated ON live_donations(donated_at);

-- Matching Gifts
CREATE TABLE IF NOT EXISTS matching_gifts (
    matching_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES broadcast_events(event_id),
    matcher_name VARCHAR(255) NOT NULL,
    match_ratio DECIMAL(4,2) DEFAULT 1.0,
    max_amount DECIMAL(12,2) NOT NULL,
    amount_used DECIMAL(12,2) DEFAULT 0,
    start_time TIMESTAMP DEFAULT NOW(),
    end_time TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Live Polls
CREATE TABLE IF NOT EXISTS live_polls (
    poll_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES broadcast_events(event_id) NOT NULL,
    question TEXT NOT NULL,
    options JSONB NOT NULL, -- ["Jobs", "Taxes", "Crime"]
    vote_keywords JSONB DEFAULT '{}', -- {"JOBS": 0, "TAXES": 1}
    votes JSONB DEFAULT '{}', -- {"0": 100, "1": 50}
    total_votes INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT false,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_live_polls_event ON live_polls(event_id);
CREATE INDEX idx_live_polls_active ON live_polls(is_active);

-- Live Reactions
CREATE TABLE IF NOT EXISTS live_reactions (
    reaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES broadcast_events(event_id) NOT NULL,
    viewer_phone VARCHAR(20),
    viewer_platform VARCHAR(50),
    viewer_name VARCHAR(255),
    reaction_type VARCHAR(50) NOT NULL, -- agree, love, funny, wow, angry, clap
    event_timestamp_seconds DECIMAL(10,2) DEFAULT 0,
    reacted_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_live_reactions_event ON live_reactions(event_id);

-- Team Members (Viral Growth)
CREATE TABLE IF NOT EXISTS team_members (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL, -- E1 link
    display_name VARCHAR(255) NOT NULL,
    display_location VARCHAR(255),
    unique_code VARCHAR(50) UNIQUE NOT NULL,
    referral_link TEXT NOT NULL,
    recruited_by_id UUID REFERENCES team_members(member_id),
    recruitment_source VARCHAR(50),
    total_recruits INTEGER DEFAULT 0,
    total_recruit_donations DECIMAL(12,2) DEFAULT 0,
    total_invites_sent INTEGER DEFAULT 0,
    tier VARCHAR(50) DEFAULT 'supporter', -- supporter, bronze, silver, gold, platinum
    joined_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_team_members_contact ON team_members(contact_id);
CREATE INDEX idx_team_members_code ON team_members(unique_code);
CREATE INDEX idx_team_members_tier ON team_members(tier);

-- Team Invitations
CREATE TABLE IF NOT EXISTS team_invitations (
    invitation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_member_id UUID REFERENCES team_members(member_id) NOT NULL,
    recipient_email VARCHAR(255),
    recipient_phone VARCHAR(20),
    recipient_name VARCHAR(255),
    channel VARCHAR(50) DEFAULT 'email',
    link TEXT NOT NULL,
    sent_at TIMESTAMP DEFAULT NOW(),
    clicked_at TIMESTAMP,
    converted_at TIMESTAMP,
    status VARCHAR(50) DEFAULT 'sent'
);

CREATE INDEX idx_team_invitations_sender ON team_invitations(sender_member_id);

-- Event Clips
CREATE TABLE IF NOT EXISTS event_clips (
    clip_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES broadcast_events(event_id),
    title VARCHAR(255) NOT NULL,
    start_seconds DECIMAL(10,2) NOT NULL,
    end_seconds DECIMAL(10,2) NOT NULL,
    duration_seconds DECIMAL(10,2),
    transcript TEXT,
    quotability_score INTEGER DEFAULT 0,
    sentiment VARCHAR(50) DEFAULT 'neutral',
    topics JSONB DEFAULT '[]',
    video_url TEXT,
    audio_url TEXT,
    thumbnail_url TEXT,
    exported_to JSONB DEFAULT '[]', -- ["E16", "E19", "E30"]
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_event_clips_event ON event_clips(event_id);
CREATE INDEX idx_event_clips_quotability ON event_clips(quotability_score DESC);


-- ============================================================================
-- ECOSYSTEM 47: AI SCRIPT GENERATOR
-- ============================================================================

-- Issue Profiles
CREATE TABLE IF NOT EXISTS script_issue_profiles (
    issue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_code VARCHAR(50) UNIQUE NOT NULL, -- taxes, crime, immigration, etc.
    issue_name VARCHAR(100) NOT NULL,
    position_summary TEXT,
    key_stats JSONB DEFAULT '[]',
    talking_points JSONB DEFAULT '[]',
    opponent_weakness TEXT,
    personal_stories JSONB DEFAULT '[]',
    positive_keywords JSONB DEFAULT '[]',
    avoid_keywords JSONB DEFAULT '[]',
    default_tone VARCHAR(50) DEFAULT 'warm_personal',
    default_intensity INTEGER DEFAULT 50, -- 0-100
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_issue_profiles_code ON script_issue_profiles(issue_code);

-- Generated Scripts
CREATE TABLE IF NOT EXISTS generated_scripts (
    script_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID,
    issue_code VARCHAR(50) NOT NULL,
    tone VARCHAR(50) NOT NULL, -- warm_personal, attack_contrast, fired_up, etc.
    intensity INTEGER DEFAULT 50, -- 0-100
    audience VARCHAR(50) DEFAULT 'general',
    format VARCHAR(50) NOT NULL, -- tv_30, radio_60, rvm_20, email, etc.
    script_text TEXT NOT NULL,
    word_count INTEGER,
    estimated_seconds DECIMAL(6,2),
    reading_level INTEGER,
    version INTEGER DEFAULT 1,
    parent_script_id UUID REFERENCES generated_scripts(script_id),
    status VARCHAR(50) DEFAULT 'draft', -- draft, pending, approved, rejected
    approved_by UUID,
    approved_at TIMESTAMP,
    ai_voice_url TEXT,
    candidate_voice_url TEXT,
    communication_dna_id UUID,
    used_in_campaigns JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_scripts_issue ON generated_scripts(issue_code);
CREATE INDEX idx_scripts_format ON generated_scripts(format);
CREATE INDEX idx_scripts_status ON generated_scripts(status);

-- Voice Clones
CREATE TABLE IF NOT EXISTS voice_clones (
    voice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    voice_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) DEFAULT 'elevenlabs',
    provider_voice_id VARCHAR(255),
    training_audio_urls JSONB DEFAULT '[]',
    training_minutes DECIMAL(6,2) DEFAULT 0,
    quality_score INTEGER DEFAULT 0, -- 0-100
    status VARCHAR(50) DEFAULT 'training', -- training, ready, needs_retraining
    consent_signed BOOLEAN DEFAULT false,
    consent_signed_at TIMESTAMP,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_voice_clones_candidate ON voice_clones(candidate_id);


-- ============================================================================
-- ECOSYSTEM 48: COMMUNICATION DNA
-- ============================================================================

-- Communication DNA Profiles
CREATE TABLE IF NOT EXISTS communication_dna (
    dna_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    candidate_name VARCHAR(255) NOT NULL,
    
    -- Primary style
    primary_tone VARCHAR(50) NOT NULL, -- warm_authoritative, passionate_fighter, etc.
    
    -- Tone profile (0-100 each)
    warmth_level INTEGER DEFAULT 70,
    authority_level INTEGER DEFAULT 60,
    passion_level INTEGER DEFAULT 50,
    humor_level INTEGER DEFAULT 25,
    formality_level INTEGER DEFAULT 30,
    urgency_level INTEGER DEFAULT 40,
    
    -- Style markers (booleans)
    uses_personal_stories BOOLEAN DEFAULT true,
    uses_short_sentences BOOLEAN DEFAULT true,
    references_family BOOLEAN DEFAULT true,
    references_faith BOOLEAN DEFAULT false,
    avoids_jargon BOOLEAN DEFAULT true,
    uses_rhetorical_questions BOOLEAN DEFAULT true,
    pauses_for_emphasis BOOLEAN DEFAULT true,
    addresses_audience_directly BOOLEAN DEFAULT true,
    
    -- Signature phrases
    signature_phrases JSONB DEFAULT '[]', -- [{phrase, context, frequency}]
    
    -- Speaking patterns
    speaking_speed VARCHAR(20) DEFAULT 'moderate', -- slow, moderate, fast
    pause_frequency VARCHAR(20) DEFAULT 'frequent', -- rare, occasional, frequent
    
    -- Analysis metadata
    analyzed_audio_minutes DECIMAL(8,2) DEFAULT 0,
    last_analyzed TIMESTAMP,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_dna_candidate ON communication_dna(candidate_id);

-- DNA Issue Profiles (how candidate sounds on each issue)
CREATE TABLE IF NOT EXISTS dna_issue_profiles (
    profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dna_id UUID REFERENCES communication_dna(dna_id) NOT NULL,
    issue_code VARCHAR(50) NOT NULL,
    primary_tone VARCHAR(50) NOT NULL,
    intensity INTEGER DEFAULT 50, -- 0-100
    preferred_keywords JSONB DEFAULT '[]',
    avoid_keywords JSONB DEFAULT '[]',
    sample_audio_url TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(dna_id, issue_code)
);

CREATE INDEX idx_dna_issue_dna ON dna_issue_profiles(dna_id);

-- DNA Channel Presets (default style per channel)
CREATE TABLE IF NOT EXISTS dna_channel_presets (
    preset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dna_id UUID REFERENCES communication_dna(dna_id) NOT NULL,
    channel VARCHAR(50) NOT NULL, -- tv_ad, rvm, email, sms, twitter, etc.
    primary_tone VARCHAR(50) NOT NULL,
    intensity INTEGER DEFAULT 50,
    max_words INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(dna_id, channel)
);

CREATE INDEX idx_dna_channel_dna ON dna_channel_presets(dna_id);

-- DNA Audience Presets (adjustments per audience)
CREATE TABLE IF NOT EXISTS dna_audience_presets (
    preset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dna_id UUID REFERENCES communication_dna(dna_id) NOT NULL,
    audience VARCHAR(50) NOT NULL, -- seniors, young_voters, veterans, etc.
    tone_adjustment VARCHAR(50), -- more_formal, more_casual, etc.
    intensity_adjustment INTEGER DEFAULT 0, -- -30 to +30
    focus_topics JSONB DEFAULT '[]',
    avoid_topics JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(dna_id, audience)
);

CREATE INDEX idx_dna_audience_dna ON dna_audience_presets(dna_id);


-- ============================================================================
-- ECOSYSTEM 49: INTERVIEW SYSTEM
-- ============================================================================

-- Interview Sessions
CREATE TABLE IF NOT EXISTS interview_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID,
    mode VARCHAR(20) NOT NULL, -- conduct, prep
    interview_type VARCHAR(50) NOT NULL, -- endorser, testimonial, mock_interview, etc.
    
    -- Guest info (conduct mode)
    guest_name VARCHAR(255),
    guest_title VARCHAR(255),
    guest_bio TEXT,
    guest_photo_url TEXT,
    
    -- Host info (prep mode)
    host_name VARCHAR(255),
    outlet_name VARCHAR(255),
    host_style VARCHAR(50), -- friendly, neutral, hostile
    host_profile_id UUID,
    
    -- Content
    topics JSONB DEFAULT '[]',
    
    -- Recording
    recording_url TEXT,
    transcript TEXT,
    duration_seconds INTEGER DEFAULT 0,
    
    -- Results
    performance_score INTEGER, -- 0-100
    
    -- Status
    status VARCHAR(50) DEFAULT 'scheduled', -- scheduled, in_progress, completed, published
    scheduled_at TIMESTAMP,
    completed_at TIMESTAMP,
    published_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_interview_sessions_mode ON interview_sessions(mode);
CREATE INDEX idx_interview_sessions_type ON interview_sessions(interview_type);
CREATE INDEX idx_interview_sessions_status ON interview_sessions(status);

-- Interview Questions
CREATE TABLE IF NOT EXISTS interview_questions (
    question_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES interview_sessions(session_id) NOT NULL,
    question_order INTEGER NOT NULL,
    question_text TEXT NOT NULL,
    question_type VARCHAR(50), -- opening, main, follow_up, closing, attack
    goal TEXT,
    follow_ups JSONB DEFAULT '[]',
    suggested_response TEXT,
    actual_response TEXT,
    response_score INTEGER, -- 0-100
    timestamp_start DECIMAL(10,2),
    timestamp_end DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_interview_questions_session ON interview_questions(session_id);

-- Host Profiles (for prep mode)
CREATE TABLE IF NOT EXISTS host_profiles (
    host_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    outlet VARCHAR(255) NOT NULL,
    style VARCHAR(50) DEFAULT 'neutral', -- friendly, neutral, hostile, debate
    bio TEXT,
    photo_url TEXT,
    interrupts_frequently BOOLEAN DEFAULT false,
    uses_gotcha_questions BOOLEAN DEFAULT false,
    cites_fact_checks BOOLEAN DEFAULT false,
    favorite_topics JSONB DEFAULT '[]',
    attack_angles JSONB DEFAULT '[]',
    likely_questions JSONB DEFAULT '[]',
    past_interview_clips JSONB DEFAULT '[]',
    strategy_notes JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_host_profiles_outlet ON host_profiles(outlet);

-- Attack Responses
CREATE TABLE IF NOT EXISTS attack_responses (
    attack_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50) NOT NULL, -- personal, policy, flip_flop, experience, scandal
    attack_text TEXT NOT NULL,
    responses JSONB NOT NULL, -- [{style, text, audio_url}]
    recommended_style VARCHAR(50),
    communication_dna_applied BOOLEAN DEFAULT false,
    effectiveness_rating INTEGER, -- 0-100
    times_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_attack_responses_category ON attack_responses(category);

-- Interview Clips
CREATE TABLE IF NOT EXISTS interview_clips (
    clip_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES interview_sessions(session_id) NOT NULL,
    title VARCHAR(255) NOT NULL,
    start_seconds DECIMAL(10,2) NOT NULL,
    end_seconds DECIMAL(10,2) NOT NULL,
    duration_seconds DECIMAL(10,2),
    transcript TEXT,
    quotability_score INTEGER DEFAULT 0, -- 0-100
    sentiment VARCHAR(50) DEFAULT 'positive',
    video_url TEXT,
    audio_url TEXT,
    thumbnail_url TEXT,
    used_in JSONB DEFAULT '[]', -- ["tv_ad", "social", "email"]
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_interview_clips_session ON interview_clips(session_id);
CREATE INDEX idx_interview_clips_quotability ON interview_clips(quotability_score DESC);

-- Debate Simulations
CREATE TABLE IF NOT EXISTS debate_simulations (
    simulation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    debate_name VARCHAR(255) NOT NULL,
    debate_format VARCHAR(50) NOT NULL, -- moderated, town_hall, lincoln_douglas
    opponents JSONB NOT NULL, -- [{name, is_ai, profile_id}]
    moderator_style VARCHAR(50) DEFAULT 'neutral',
    topics JSONB DEFAULT '[]',
    duration_minutes INTEGER,
    recording_url TEXT,
    transcript TEXT,
    overall_score INTEGER, -- 0-100
    category_scores JSONB DEFAULT '{}', -- {message_discipline: 85, attack_effectiveness: 78}
    exchange_analysis JSONB DEFAULT '[]',
    recommendations JSONB DEFAULT '[]',
    status VARCHAR(50) DEFAULT 'scheduled', -- scheduled, in_progress, completed
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_debate_simulations_candidate ON debate_simulations(candidate_id);
CREATE INDEX idx_debate_simulations_status ON debate_simulations(status);

-- Performance History (track improvement over time)
CREATE TABLE IF NOT EXISTS interview_performance_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    session_id UUID REFERENCES interview_sessions(session_id),
    simulation_id UUID REFERENCES debate_simulations(simulation_id),
    session_type VARCHAR(50) NOT NULL, -- mock_interview, debate
    overall_score INTEGER,
    category_scores JSONB,
    strengths JSONB DEFAULT '[]',
    improvements JSONB DEFAULT '[]',
    recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_performance_history_candidate ON interview_performance_history(candidate_id);
CREATE INDEX idx_performance_history_recorded ON interview_performance_history(recorded_at);


-- ============================================================================
-- CROSS-ECOSYSTEM INTEGRATION VIEWS
-- ============================================================================

-- View: All leads captured from broadcasts
CREATE OR REPLACE VIEW broadcast_leads AS
SELECT 
    t.text_id,
    t.phone_number,
    t.keyword_matched,
    k.keyword_type,
    k.lead_tags,
    e.event_id,
    e.title AS event_title,
    e.event_type,
    t.contact_id,
    t.received_at
FROM incoming_texts t
LEFT JOIN text_keywords k ON t.keyword_id = k.keyword_id
LEFT JOIN broadcast_events e ON t.event_id = e.event_id
WHERE t.form_completed = true;

-- View: Team member leaderboard
CREATE OR REPLACE VIEW team_leaderboard AS
SELECT 
    member_id,
    display_name,
    total_recruits,
    total_recruit_donations,
    tier,
    joined_at,
    RANK() OVER (ORDER BY total_recruits DESC) AS recruit_rank,
    RANK() OVER (ORDER BY total_recruit_donations DESC) AS donation_rank
FROM team_members
ORDER BY total_recruits DESC;

-- View: Script library by issue
CREATE OR REPLACE VIEW script_library AS
SELECT 
    s.script_id,
    s.issue_code,
    i.issue_name,
    s.tone,
    s.intensity,
    s.audience,
    s.format,
    s.word_count,
    s.estimated_seconds,
    s.status,
    s.ai_voice_url IS NOT NULL AS has_ai_voice,
    s.candidate_voice_url IS NOT NULL AS has_candidate_voice,
    s.created_at
FROM generated_scripts s
LEFT JOIN script_issue_profiles i ON s.issue_code = i.issue_code
WHERE s.status = 'approved'
ORDER BY s.issue_code, s.format;

-- View: Candidate interview prep progress
CREATE OR REPLACE VIEW interview_prep_progress AS
SELECT 
    s.session_id,
    s.host_name,
    s.outlet_name,
    s.host_style,
    s.performance_score,
    s.status,
    s.scheduled_at,
    s.completed_at,
    COUNT(DISTINCT c.clip_id) AS clips_extracted
FROM interview_sessions s
LEFT JOIN interview_clips c ON s.session_id = c.session_id
WHERE s.mode = 'prep'
GROUP BY s.session_id
ORDER BY s.scheduled_at DESC;


-- ============================================================================
-- DEFAULT DATA
-- ============================================================================

-- Insert default text keywords
INSERT INTO text_keywords (keyword, keyword_type, reply_message, link_url) VALUES
    ('EDDIE', 'general', 'Thanks for joining Team Broyhill! Get updates: {link}', 'https://broyhill2024.com/join'),
    ('DONATE', 'donation', 'Thank you! Support Eddie here: {link}', 'https://broyhill2024.com/donate'),
    ('SIGN', 'yard_sign', 'Get your FREE yard sign: {link}', 'https://broyhill2024.com/sign'),
    ('VOLUNTEER', 'volunteer', 'Join our volunteer team: {link}', 'https://broyhill2024.com/volunteer'),
    ('RALLY', 'rsvp', 'RSVP for the next rally: {link}', 'https://broyhill2024.com/events')
ON CONFLICT (keyword) DO NOTHING;

-- Insert default issue profiles
INSERT INTO script_issue_profiles (issue_code, issue_name, position_summary, default_tone, default_intensity) VALUES
    ('taxes', 'Taxes', 'Cut taxes for NC families', 'warm_personal', 55),
    ('crime', 'Crime & Safety', 'Back the blue, tough on crime', 'passionate_fighter', 75),
    ('immigration', 'Immigration', 'Secure border, legal immigration', 'strong_confident', 70),
    ('education', 'Education', 'Parents rights, school choice', 'warm_personal', 65),
    ('economy', 'Economy & Jobs', 'Pro-business, cut regulations', 'strong_confident', 50),
    ('healthcare', 'Healthcare', 'Lower costs, more choices', 'warm_personal', 55),
    ('second_amendment', '2nd Amendment', 'Protect gun rights', 'passionate_fighter', 70),
    ('family_values', 'Family Values', 'Faith, family, freedom', 'warm_personal', 40),
    ('veterans', 'Veterans', 'Honor service, support vets', 'warm_personal', 60),
    ('inflation', 'Inflation', 'Fight rising prices', 'concerned_urgent', 65)
ON CONFLICT (issue_code) DO NOTHING;

-- Insert default attack responses
INSERT INTO attack_responses (category, attack_text, responses, recommended_style) VALUES
    ('personal', 'You are wealthy and out of touch',
     '[{"style": "personal_story", "text": "My father started with nothing. I know what it takes to build something."},
       {"style": "bridge_pivot", "text": "What I am is someone who creates jobs. My opponent? Career politician."}]',
     'personal_story'),
    ('experience', 'You have no political experience',
     '[{"style": "strength", "text": "Exactly - I am not a career politician. I have actually run things."},
       {"style": "contrast", "text": "My opponent has 20 years in Raleigh. What do we have to show for it?"}]',
     'strength'),
    ('policy', 'Your tax plan will hurt the middle class',
     '[{"style": "factual", "text": "My plan cuts taxes for 90% of NC families. Average savings: $1,200."},
       {"style": "redirect", "text": "My opponent raised taxes 3 times. I will cut them. That is the choice."}]',
     'factual')
ON CONFLICT DO NOTHING;


-- ============================================================================
-- SUMMARY
-- ============================================================================
-- E46 Broadcast Hub: 12 tables
-- E47 AI Script Generator: 3 tables  
-- E48 Communication DNA: 4 tables
-- E49 Interview System: 8 tables
-- Cross-ecosystem views: 4 views
-- Total: 27 tables + 4 views
-- ============================================================================
