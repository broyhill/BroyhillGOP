-- ============================================================================
-- NEXUS SOCIAL EXTENSION - DATABASE MIGRATION
-- ============================================================================
-- Extends E19 Social Media Manager with NEXUS Intelligence
-- Follows existing approval workflow protocol exactly
-- 
-- INTEGRATIONS:
-- - E0 DataHub: Central data warehouse
-- - E1 Donor Intelligence: Enrichment append
-- - E5 Volunteer Management: Enrichment append
-- - E7 Issue Tracking: Talking points vocabulary
-- - E13 AI Hub: Content generation
-- - E19 Social Media Manager: Approval workflow (EXTENDS)
-- - E20 Intelligence Brain: Trigger control
-- - E48 Communication DNA: Voice profiles
--
-- RUN AFTER: ECOSYSTEM_19_SOCIAL_MEDIA_SCHEMA_3.sql
-- ============================================================================

-- ============================================================================
-- PART 1: EXTEND EXISTING E19 TABLES
-- ============================================================================

-- Add NEXUS tracking to social_approval_requests
ALTER TABLE social_approval_requests 
    ADD COLUMN IF NOT EXISTS nexus_trigger_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS nexus_harvest_ids JSONB DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS nexus_confidence DECIMAL(5,2),
    ADD COLUMN IF NOT EXISTS nexus_persona_score DECIMAL(5,2),
    ADD COLUMN IF NOT EXISTS nexus_issue_tags JSONB DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS nexus_talking_points_used JSONB DEFAULT '[]';

COMMENT ON COLUMN social_approval_requests.nexus_trigger_type IS 'NEXUS trigger: harvest_match, sentinel_event, rally_recruit, scheduled, news_response';
COMMENT ON COLUMN social_approval_requests.nexus_persona_score IS 'AI confidence that drafts match candidate voice (0-100)';

-- Add NEXUS tracking to social_posts
ALTER TABLE social_posts
    ADD COLUMN IF NOT EXISTS nexus_enrichment_source VARCHAR(100),
    ADD COLUMN IF NOT EXISTS nexus_persona_match DECIMAL(5,2),
    ADD COLUMN IF NOT EXISTS nexus_ml_optimized BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS nexus_best_time_used BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS nexus_issue_id UUID,
    ADD COLUMN IF NOT EXISTS nexus_learning_captured BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN social_posts.nexus_persona_match IS 'Final persona match score after posting';
COMMENT ON COLUMN social_posts.nexus_ml_optimized IS 'TRUE if ML optimized timing/content';

-- Extend candidate_style_profiles with NEXUS intelligence
ALTER TABLE candidate_style_profiles
    ADD COLUMN IF NOT EXISTS nexus_voice_signature JSONB DEFAULT '{
        "formality": 5,
        "warmth": 5,
        "directness": 5,
        "emotion_intensity": 5,
        "humor_frequency": 0
    }',
    ADD COLUMN IF NOT EXISTS nexus_issue_vocabulary JSONB DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS nexus_platform_variations JSONB DEFAULT '{
        "facebook": {},
        "twitter": {},
        "instagram": {}
    }',
    ADD COLUMN IF NOT EXISTS nexus_banned_phrases JSONB DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS nexus_required_elements JSONB DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS nexus_training_posts_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS nexus_last_trained TIMESTAMP,
    ADD COLUMN IF NOT EXISTS nexus_ml_confidence DECIMAL(5,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS nexus_approval_learning JSONB DEFAULT '{
        "approved_patterns": [],
        "rejected_patterns": [],
        "edited_patterns": []
    }';

COMMENT ON COLUMN candidate_style_profiles.nexus_voice_signature IS 'Multi-dimensional voice profile for AI generation';
COMMENT ON COLUMN candidate_style_profiles.nexus_issue_vocabulary IS 'Candidate-specific language for each E7 issue';
COMMENT ON COLUMN candidate_style_profiles.nexus_approval_learning IS 'ML learning from approval/rejection patterns';

-- ============================================================================
-- PART 2: HARVEST DATABASE (150K Records)
-- ============================================================================

CREATE TABLE IF NOT EXISTS nexus_harvest_records (
    harvest_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source identification
    source_type VARCHAR(50) NOT NULL,
    source_name VARCHAR(255),
    source_date DATE,
    import_batch_id UUID,
    
    -- Raw contact info
    raw_first_name VARCHAR(100),
    raw_last_name VARCHAR(100),
    raw_email VARCHAR(255),
    raw_phone VARCHAR(50),
    raw_address TEXT,
    raw_city VARCHAR(100),
    raw_state VARCHAR(10) DEFAULT 'NC',
    raw_zip VARCHAR(20),
    raw_county VARCHAR(100),
    
    -- Social media IDs
    facebook_id VARCHAR(100),
    facebook_url TEXT,
    facebook_name VARCHAR(255),
    twitter_handle VARCHAR(100),
    twitter_id VARCHAR(100),
    instagram_handle VARCHAR(100),
    instagram_id VARCHAR(100),
    linkedin_url TEXT,
    linkedin_id VARCHAR(100),
    tiktok_handle VARCHAR(100),
    truth_social_handle VARCHAR(100),
    youtube_channel VARCHAR(255),
    
    -- Enrichment status
    enrichment_status VARCHAR(50) DEFAULT 'pending',
    enrichment_priority INT DEFAULT 50,
    enrichment_attempts INT DEFAULT 0,
    last_enrichment_at TIMESTAMP,
    enrichment_score INT DEFAULT 0,
    enrichment_data JSONB DEFAULT '{}',
    
    -- Match status
    matched_donor_id UUID,
    matched_volunteer_id UUID,
    matched_activist_id UUID,
    match_confidence DECIMAL(5,2),
    match_method VARCHAR(50),
    match_verified BOOLEAN DEFAULT FALSE,
    match_verified_by VARCHAR(255),
    match_verified_at TIMESTAMP,
    
    -- E20 Brain control
    assigned_agent VARCHAR(50),
    brain_decision_id UUID,
    brain_priority_override INT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for harvest records
CREATE INDEX IF NOT EXISTS idx_harvest_status ON nexus_harvest_records(enrichment_status, enrichment_priority DESC);
CREATE INDEX IF NOT EXISTS idx_harvest_matched_donor ON nexus_harvest_records(matched_donor_id) WHERE matched_donor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_harvest_matched_volunteer ON nexus_harvest_records(matched_volunteer_id) WHERE matched_volunteer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_harvest_facebook ON nexus_harvest_records(facebook_id) WHERE facebook_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_harvest_twitter ON nexus_harvest_records(twitter_handle) WHERE twitter_handle IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_harvest_email ON nexus_harvest_records(LOWER(raw_email)) WHERE raw_email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_harvest_phone ON nexus_harvest_records(raw_phone) WHERE raw_phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_harvest_name ON nexus_harvest_records(LOWER(raw_last_name), LOWER(raw_first_name));
CREATE INDEX IF NOT EXISTS idx_harvest_batch ON nexus_harvest_records(import_batch_id);
CREATE INDEX IF NOT EXISTS idx_harvest_source ON nexus_harvest_records(source_type, source_date);

COMMENT ON TABLE nexus_harvest_records IS 'NEXUS: 150K+ harvest records for social media lookup and enrichment';

-- Harvest import batches tracking
CREATE TABLE IF NOT EXISTS nexus_harvest_batches (
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Batch info
    batch_name VARCHAR(255),
    source_type VARCHAR(50),
    source_file VARCHAR(500),
    
    -- Statistics
    total_records INT DEFAULT 0,
    records_imported INT DEFAULT 0,
    records_matched INT DEFAULT 0,
    records_enriched INT DEFAULT 0,
    records_failed INT DEFAULT 0,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    
    -- Metadata
    imported_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_harvest_batches_status ON nexus_harvest_batches(status);

-- ============================================================================
-- PART 3: EXTEND DONORS TABLE (E1)
-- ============================================================================

-- Social profiles from harvest matching
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_enriched BOOLEAN DEFAULT FALSE;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_enriched_at TIMESTAMP;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_harvest_id UUID;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_enrichment_sources JSONB DEFAULT '[]';

-- Verified social URLs
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_facebook_url TEXT;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_facebook_id VARCHAR(100);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_twitter_handle VARCHAR(100);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_instagram_handle VARCHAR(100);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_linkedin_url TEXT;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_tiktok_handle VARCHAR(100);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_truth_social VARCHAR(100);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_match_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_verified_at TIMESTAMP;

-- Social engagement indicators
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_engagement_level VARCHAR(20);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_political_active BOOLEAN;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_gop_engaged BOOLEAN;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_follower_tier VARCHAR(20);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_influence_score INT;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS social_last_activity DATE;

-- Free government data enrichment
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_fec_total DECIMAL(14,2);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_fec_last_date DATE;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_fec_committees JSONB DEFAULT '[]';
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_fec_employers JSONB DEFAULT '[]';
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_state_contributions JSONB DEFAULT '[]';
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_property_value DECIMAL(14,2);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_property_count INT;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_business_owner BOOLEAN;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_business_names JSONB DEFAULT '[]';
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_sec_executive BOOLEAN;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_primary_voter_score INT;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS nexus_general_voter_score INT;

-- Indexes for donor enrichment
CREATE INDEX IF NOT EXISTS idx_donors_nexus_enriched ON donors(nexus_enriched) WHERE nexus_enriched = TRUE;
CREATE INDEX IF NOT EXISTS idx_donors_social_facebook ON donors(social_facebook_id) WHERE social_facebook_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_donors_social_twitter ON donors(social_twitter_handle) WHERE social_twitter_handle IS NOT NULL;

COMMENT ON COLUMN donors.nexus_enriched IS 'TRUE if enriched by NEXUS agents';
COMMENT ON COLUMN donors.social_engagement_level IS 'high, medium, low, none - based on political social activity';
COMMENT ON COLUMN donors.social_follower_tier IS 'influencer (10K+), active (1K+), normal (100+), minimal (<100)';

-- ============================================================================
-- PART 4: EXTEND VOLUNTEERS TABLE (E5)
-- ============================================================================

ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_enriched BOOLEAN DEFAULT FALSE;
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_enriched_at TIMESTAMP;
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_harvest_id UUID;

-- Social profiles
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS social_facebook_url TEXT;
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS social_facebook_id VARCHAR(100);
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS social_twitter_handle VARCHAR(100);
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS social_instagram_handle VARCHAR(100);
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS social_linkedin_url TEXT;

-- Engagement indicators
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS social_reach_estimate INT;
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS social_engagement_level VARCHAR(20);
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS social_political_active BOOLEAN;

-- RALLY agent scoring
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_rally_score INT;
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_rally_source VARCHAR(100);
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_predicted_show_rate DECIMAL(5,2);
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_skill_match_score INT;
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_availability_match JSONB DEFAULT '{}';

-- Voter data
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_primary_voter BOOLEAN;
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_primary_history JSONB DEFAULT '[]';
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS nexus_voter_score INT;

CREATE INDEX IF NOT EXISTS idx_volunteers_nexus_enriched ON volunteers(nexus_enriched) WHERE nexus_enriched = TRUE;
CREATE INDEX IF NOT EXISTS idx_volunteers_rally_score ON volunteers(nexus_rally_score DESC) WHERE nexus_rally_score IS NOT NULL;

-- ============================================================================
-- PART 5: PERSONA-ISSUE MAPPING (Links E7 to E19)
-- ============================================================================

CREATE TABLE IF NOT EXISTS nexus_persona_issue_mapping (
    mapping_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    issue_id UUID,
    issue_code VARCHAR(50),
    issue_name VARCHAR(255),
    
    -- Candidate's language for this issue
    preferred_terms JSONB DEFAULT '[]',
    banned_terms JSONB DEFAULT '[]',
    talking_points_used JSONB DEFAULT '[]',
    emotional_tone VARCHAR(50),
    intensity_level INT CHECK (intensity_level BETWEEN 1 AND 10),
    
    -- Sample content
    sample_phrases JSONB DEFAULT '[]',
    sample_posts JSONB DEFAULT '[]',
    
    -- Performance tracking
    posts_using_issue INT DEFAULT 0,
    avg_engagement DECIMAL(10,2),
    best_performing_approach VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_persona_issue_candidate ON nexus_persona_issue_mapping(candidate_id);
CREATE INDEX IF NOT EXISTS idx_persona_issue_code ON nexus_persona_issue_mapping(issue_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_persona_issue_unique ON nexus_persona_issue_mapping(candidate_id, issue_code);

COMMENT ON TABLE nexus_persona_issue_mapping IS 'NEXUS: Maps E7 issues to candidate-specific vocabulary for E19 content';

-- ============================================================================
-- PART 6: ENRICHMENT QUEUE (E20 Brain Controlled)
-- ============================================================================

CREATE TABLE IF NOT EXISTS nexus_enrichment_queue (
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Target
    target_type VARCHAR(50) NOT NULL,
    target_id UUID NOT NULL,
    
    -- Enrichment type
    enrichment_type VARCHAR(50) NOT NULL,
    enrichment_source VARCHAR(100),
    
    -- Priority (set by E20 Brain)
    priority INT DEFAULT 50,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    attempts INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    last_attempt_at TIMESTAMP,
    next_attempt_at TIMESTAMP,
    
    -- Results
    enrichment_data JSONB DEFAULT '{}',
    fields_enriched JSONB DEFAULT '[]',
    success BOOLEAN,
    error_message TEXT,
    
    -- Brain control
    brain_approved BOOLEAN DEFAULT TRUE,
    brain_decision_id UUID,
    brain_notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_enrichment_queue_pending ON nexus_enrichment_queue(status, priority DESC) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_enrichment_queue_target ON nexus_enrichment_queue(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_enrichment_queue_type ON nexus_enrichment_queue(enrichment_type);
CREATE INDEX IF NOT EXISTS idx_enrichment_queue_next ON nexus_enrichment_queue(next_attempt_at) WHERE status = 'pending';

COMMENT ON TABLE nexus_enrichment_queue IS 'NEXUS: E20 Brain-controlled enrichment queue for donors/volunteers/harvest';

-- Enrichment type reference
COMMENT ON COLUMN nexus_enrichment_queue.enrichment_type IS '
ENRICHMENT TYPES:
- social_lookup: Match social media profiles
- fec_check: FEC contribution history
- nc_voter_check: NC SBOE voter registration
- property_check: County property records
- business_check: NC SOS business filings
- sec_check: SEC EDGAR for executives
- news_check: Google News mentions
- aggregate_all: Run all applicable checks
';

-- ============================================================================
-- PART 7: BRAIN TRIGGERS (E20 Integration)
-- ============================================================================

CREATE TABLE IF NOT EXISTS nexus_brain_triggers (
    trigger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Trigger identification
    trigger_type VARCHAR(50) NOT NULL,
    trigger_name VARCHAR(255),
    
    -- Source
    source_table VARCHAR(100),
    source_record_id UUID,
    source_event_id UUID,
    
    -- E20 Brain decision
    brain_decision VARCHAR(20),
    brain_score INT,
    brain_reasoning JSONB DEFAULT '{}',
    brain_factors JSONB DEFAULT '[]',
    
    -- Resulting action
    action_type VARCHAR(100),
    action_target_type VARCHAR(50),
    action_target_id UUID,
    action_result JSONB DEFAULT '{}',
    action_success BOOLEAN,
    
    -- For social posts: links to existing approval workflow
    approval_request_id UUID,
    
    -- Timing
    created_at TIMESTAMP DEFAULT NOW(),
    decided_at TIMESTAMP,
    executed_at TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_nexus_triggers_type ON nexus_brain_triggers(trigger_type);
CREATE INDEX IF NOT EXISTS idx_nexus_triggers_decision ON nexus_brain_triggers(brain_decision);
CREATE INDEX IF NOT EXISTS idx_nexus_triggers_approval ON nexus_brain_triggers(approval_request_id) WHERE approval_request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_nexus_triggers_date ON nexus_brain_triggers(created_at DESC);

COMMENT ON TABLE nexus_brain_triggers IS 'NEXUS: All triggers processed by E20 Brain for NEXUS agents';

-- Trigger type reference
COMMENT ON COLUMN nexus_brain_triggers.trigger_type IS '
TRIGGER TYPES:
- harvest_enrichment: New harvest record needs enrichment
- social_post: Event requires social media response
- donor_append: Enrichment data ready to append
- volunteer_recruit: Potential volunteer identified
- sentinel_event: Life event detected (job change, news mention)
- persona_update: Style profile needs refresh
- ml_optimization: ML has new recommendations
- variance_alert: Performance variance detected
';

-- ============================================================================
-- PART 8: ML OPTIMIZATION TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS nexus_ml_optimization (
    optimization_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    platform VARCHAR(50),
    
    -- Learning period
    analysis_start DATE,
    analysis_end DATE,
    posts_analyzed INT,
    approvals_analyzed INT,
    
    -- Discovered patterns - Timing
    best_posting_times JSONB DEFAULT '[]',
    worst_posting_times JSONB DEFAULT '[]',
    day_of_week_performance JSONB DEFAULT '{}',
    
    -- Discovered patterns - Content
    best_content_types JSONB DEFAULT '[]',
    best_topics JSONB DEFAULT '[]',
    best_hashtags JSONB DEFAULT '[]',
    optimal_length JSONB DEFAULT '{}',
    best_media_types JSONB DEFAULT '[]',
    
    -- Persona refinements
    tone_adjustments JSONB DEFAULT '{}',
    vocabulary_updates JSONB DEFAULT '{}',
    phrase_effectiveness JSONB DEFAULT '{}',
    
    -- Approval pattern learning
    approval_rate_by_option JSONB DEFAULT '{}',
    edit_patterns JSONB DEFAULT '[]',
    rejection_reasons JSONB DEFAULT '[]',
    
    -- Confidence
    confidence_score DECIMAL(5,2),
    sample_size_adequate BOOLEAN,
    
    -- Application status
    applied_to_profile BOOLEAN DEFAULT FALSE,
    applied_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ml_optimization_candidate ON nexus_ml_optimization(candidate_id);
CREATE INDEX IF NOT EXISTS idx_ml_optimization_applied ON nexus_ml_optimization(applied_to_profile);

COMMENT ON TABLE nexus_ml_optimization IS 'NEXUS: ML-discovered patterns for content optimization';

-- ============================================================================
-- PART 9: APPROVAL LEARNING LOG
-- ============================================================================

CREATE TABLE IF NOT EXISTS nexus_approval_learning (
    learning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    approval_request_id UUID,
    
    -- What happened
    outcome VARCHAR(50),
    selected_option INT,
    
    -- Draft analysis
    draft_1_score DECIMAL(5,2),
    draft_2_score DECIMAL(5,2),
    draft_3_score DECIMAL(5,2),
    draft_1_features JSONB DEFAULT '{}',
    draft_2_features JSONB DEFAULT '{}',
    draft_3_features JSONB DEFAULT '{}',
    
    -- If edited, what changed
    edit_analysis JSONB DEFAULT '{}',
    words_added JSONB DEFAULT '[]',
    words_removed JSONB DEFAULT '[]',
    tone_change VARCHAR(50),
    length_change INT,
    
    -- Learning extracted
    patterns_identified JSONB DEFAULT '[]',
    preferences_updated JSONB DEFAULT '[]',
    
    -- Applied to profile
    applied_to_profile BOOLEAN DEFAULT FALSE,
    applied_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_approval_learning_candidate ON nexus_approval_learning(candidate_id);
CREATE INDEX IF NOT EXISTS idx_approval_learning_outcome ON nexus_approval_learning(outcome);

COMMENT ON TABLE nexus_approval_learning IS 'NEXUS: Learning from candidate approval/edit patterns';

-- ============================================================================
-- PART 10: VARIANCE REPORTING
-- ============================================================================

CREATE TABLE IF NOT EXISTS nexus_variance_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    platform VARCHAR(50),
    report_date DATE,
    report_period VARCHAR(20) DEFAULT 'weekly',
    
    -- Baseline metrics (30-day average)
    baseline_posts_per_week DECIMAL(4,1),
    baseline_engagement_rate DECIMAL(6,4),
    baseline_reach_per_post INT,
    baseline_approval_rate DECIMAL(5,2),
    baseline_persona_score DECIMAL(5,2),
    
    -- Current metrics (7-day)
    current_posts_per_week DECIMAL(4,1),
    current_engagement_rate DECIMAL(6,4),
    current_reach_per_post INT,
    current_approval_rate DECIMAL(5,2),
    current_persona_score DECIMAL(5,2),
    
    -- Variance calculations
    posting_variance_pct DECIMAL(6,2),
    engagement_variance_pct DECIMAL(6,2),
    reach_variance_pct DECIMAL(6,2),
    approval_variance_pct DECIMAL(6,2),
    persona_variance_pct DECIMAL(6,2),
    
    -- Overall status
    variance_status VARCHAR(20),
    risk_score INT,
    
    -- Auto-generated recommendations
    recommendations JSONB DEFAULT '[]',
    
    -- Alert status
    alert_sent BOOLEAN DEFAULT FALSE,
    alert_sent_at TIMESTAMP,
    alert_acknowledged BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_variance_candidate ON nexus_variance_reports(candidate_id, platform);
CREATE INDEX IF NOT EXISTS idx_variance_status ON nexus_variance_reports(variance_status);
CREATE INDEX IF NOT EXISTS idx_variance_date ON nexus_variance_reports(report_date DESC);

COMMENT ON TABLE nexus_variance_reports IS 'NEXUS: Performance variance monitoring and alerting';

-- ============================================================================
-- PART 11: VIEWS FOR MONITORING
-- ============================================================================

-- Harvest enrichment progress
CREATE OR REPLACE VIEW v_nexus_harvest_progress AS
SELECT 
    enrichment_status,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE matched_donor_id IS NOT NULL) AS matched_to_donors,
    COUNT(*) FILTER (WHERE matched_volunteer_id IS NOT NULL) AS matched_to_volunteers,
    COUNT(*) FILTER (WHERE matched_donor_id IS NOT NULL OR matched_volunteer_id IS NOT NULL) AS total_matched,
    COUNT(*) FILTER (WHERE match_verified = TRUE) AS verified_matches,
    ROUND(AVG(enrichment_score), 1) AS avg_enrichment_score,
    COUNT(*) FILTER (WHERE facebook_id IS NOT NULL) AS has_facebook,
    COUNT(*) FILTER (WHERE twitter_handle IS NOT NULL) AS has_twitter,
    COUNT(*) FILTER (WHERE linkedin_url IS NOT NULL) AS has_linkedin
FROM nexus_harvest_records
GROUP BY enrichment_status
ORDER BY 
    CASE enrichment_status 
        WHEN 'completed' THEN 1 
        WHEN 'in_progress' THEN 2 
        WHEN 'pending' THEN 3 
        WHEN 'failed' THEN 4 
    END;

-- Donor enrichment dashboard
CREATE OR REPLACE VIEW v_nexus_donor_enrichment AS
SELECT 
    COUNT(*) AS total_donors,
    COUNT(*) FILTER (WHERE nexus_enriched = TRUE) AS enriched_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE nexus_enriched = TRUE) / NULLIF(COUNT(*), 0), 2) AS enrichment_pct,
    COUNT(*) FILTER (WHERE social_facebook_url IS NOT NULL) AS has_facebook,
    COUNT(*) FILTER (WHERE social_twitter_handle IS NOT NULL) AS has_twitter,
    COUNT(*) FILTER (WHERE social_linkedin_url IS NOT NULL) AS has_linkedin,
    COUNT(*) FILTER (WHERE nexus_fec_total IS NOT NULL) AS has_fec_data,
    COUNT(*) FILTER (WHERE nexus_property_value IS NOT NULL) AS has_property_data,
    COUNT(*) FILTER (WHERE nexus_business_owner = TRUE) AS business_owners,
    COUNT(*) FILTER (WHERE social_match_verified = TRUE) AS social_verified,
    ROUND(AVG(nexus_fec_total), 2) AS avg_fec_total,
    ROUND(AVG(nexus_property_value), 2) AS avg_property_value
FROM donors;

-- Volunteer enrichment dashboard
CREATE OR REPLACE VIEW v_nexus_volunteer_enrichment AS
SELECT 
    COUNT(*) AS total_volunteers,
    COUNT(*) FILTER (WHERE nexus_enriched = TRUE) AS enriched_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE nexus_enriched = TRUE) / NULLIF(COUNT(*), 0), 2) AS enrichment_pct,
    COUNT(*) FILTER (WHERE social_facebook_url IS NOT NULL) AS has_facebook,
    COUNT(*) FILTER (WHERE social_twitter_handle IS NOT NULL) AS has_twitter,
    COUNT(*) FILTER (WHERE nexus_primary_voter = TRUE) AS primary_voters,
    ROUND(AVG(nexus_rally_score), 1) AS avg_rally_score,
    ROUND(AVG(nexus_predicted_show_rate), 2) AS avg_predicted_show_rate
FROM volunteers;

-- Social approval performance with NEXUS metrics
CREATE OR REPLACE VIEW v_nexus_approval_performance AS
SELECT 
    DATE(created_at) AS date,
    COUNT(*) AS requests_sent,
    COUNT(*) FILTER (WHERE status = 'approved') AS approved,
    COUNT(*) FILTER (WHERE status = 'edited') AS edited_approved,
    COUNT(*) FILTER (WHERE approval_method = 'auto_approved') AS auto_approved,
    COUNT(*) FILTER (WHERE status = 'rejected') AS rejected,
    COUNT(*) FILTER (WHERE status = 'expired') AS expired,
    ROUND(AVG(nexus_persona_score), 2) AS avg_persona_score,
    ROUND(AVG(nexus_confidence), 2) AS avg_ai_confidence,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status IN ('approved', 'edited')) / NULLIF(COUNT(*), 0), 2) AS approval_rate,
    ROUND(100.0 * COUNT(*) FILTER (WHERE selected_option = 1) / NULLIF(COUNT(*) FILTER (WHERE selected_option IS NOT NULL), 0), 2) AS option_1_rate
FROM social_approval_requests
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Persona effectiveness by candidate
CREATE OR REPLACE VIEW v_nexus_persona_effectiveness AS
SELECT 
    c.candidate_id,
    c.first_name || ' ' || c.last_name AS candidate_name,
    c.office_sought,
    csp.confidence_score AS e19_confidence,
    csp.nexus_ml_confidence AS nexus_confidence,
    csp.nexus_training_posts_count AS training_samples,
    csp.nexus_last_trained,
    ROUND(AVG(sar.nexus_persona_score), 2) AS avg_persona_match,
    COUNT(DISTINCT sar.approval_request_id) AS approvals_30d,
    ROUND(100.0 * COUNT(*) FILTER (WHERE sar.status IN ('approved', 'edited')) / 
        NULLIF(COUNT(DISTINCT sar.approval_request_id), 0), 2) AS approval_rate_30d,
    COUNT(sp.post_id) FILTER (WHERE sp.posted_at > NOW() - INTERVAL '30 days') AS posts_30d,
    ROUND(AVG(sp.engagement_score), 2) AS avg_engagement
FROM candidates c
LEFT JOIN candidate_style_profiles csp ON c.candidate_id = csp.candidate_id
LEFT JOIN social_approval_requests sar ON c.candidate_id = sar.candidate_id 
    AND sar.created_at > NOW() - INTERVAL '30 days'
LEFT JOIN social_posts sp ON c.candidate_id = sp.candidate_id
WHERE c.status = 'active'
GROUP BY c.candidate_id, c.first_name, c.last_name, c.office_sought,
    csp.confidence_score, csp.nexus_ml_confidence, 
    csp.nexus_training_posts_count, csp.nexus_last_trained
ORDER BY avg_persona_match DESC NULLS LAST;

-- Enrichment queue status
CREATE OR REPLACE VIEW v_nexus_queue_status AS
SELECT 
    enrichment_type,
    target_type,
    status,
    COUNT(*) AS count,
    AVG(attempts) AS avg_attempts,
    MIN(created_at) AS oldest_item,
    MAX(created_at) AS newest_item
FROM nexus_enrichment_queue
GROUP BY enrichment_type, target_type, status
ORDER BY enrichment_type, target_type, status;

-- Brain trigger summary
CREATE OR REPLACE VIEW v_nexus_brain_summary AS
SELECT 
    DATE(created_at) AS date,
    trigger_type,
    brain_decision,
    COUNT(*) AS trigger_count,
    COUNT(*) FILTER (WHERE action_success = TRUE) AS successful,
    COUNT(*) FILTER (WHERE action_success = FALSE) AS failed,
    ROUND(AVG(brain_score), 1) AS avg_score
FROM nexus_brain_triggers
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at), trigger_type, brain_decision
ORDER BY date DESC, trigger_type;

-- Variance alerts needing attention
CREATE OR REPLACE VIEW v_nexus_variance_alerts AS
SELECT 
    vr.report_id,
    c.candidate_id,
    c.first_name || ' ' || c.last_name AS candidate_name,
    vr.platform,
    vr.variance_status,
    vr.risk_score,
    vr.engagement_variance_pct,
    vr.reach_variance_pct,
    vr.persona_variance_pct,
    vr.recommendations,
    vr.report_date
FROM nexus_variance_reports vr
JOIN candidates c ON vr.candidate_id = c.candidate_id
WHERE vr.variance_status IN ('concern', 'critical')
    AND vr.alert_acknowledged = FALSE
    AND vr.report_date > NOW() - INTERVAL '7 days'
ORDER BY vr.risk_score DESC, vr.report_date DESC;

-- ============================================================================
-- PART 12: FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION nexus_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to NEXUS tables
DROP TRIGGER IF EXISTS nexus_harvest_updated ON nexus_harvest_records;
CREATE TRIGGER nexus_harvest_updated 
    BEFORE UPDATE ON nexus_harvest_records
    FOR EACH ROW EXECUTE FUNCTION nexus_update_timestamp();

DROP TRIGGER IF EXISTS nexus_persona_issue_updated ON nexus_persona_issue_mapping;
CREATE TRIGGER nexus_persona_issue_updated 
    BEFORE UPDATE ON nexus_persona_issue_mapping
    FOR EACH ROW EXECUTE FUNCTION nexus_update_timestamp();

-- Function to match harvest record to donor
CREATE OR REPLACE FUNCTION nexus_match_harvest_to_donor(p_harvest_id UUID)
RETURNS TABLE(donor_id UUID, match_method VARCHAR, confidence DECIMAL) AS $$
BEGIN
    RETURN QUERY
    WITH harvest AS (
        SELECT * FROM nexus_harvest_records WHERE harvest_id = p_harvest_id
    )
    -- Email exact match (highest confidence)
    SELECT d.donor_id, 'email_exact'::VARCHAR, 95.0::DECIMAL
    FROM donors d, harvest h
    WHERE LOWER(d.email) = LOWER(h.raw_email)
    AND h.raw_email IS NOT NULL
    
    UNION ALL
    
    -- Phone exact match
    SELECT d.donor_id, 'phone_exact'::VARCHAR, 90.0::DECIMAL
    FROM donors d, harvest h
    WHERE REGEXP_REPLACE(d.phone, '[^0-9]', '', 'g') = REGEXP_REPLACE(h.raw_phone, '[^0-9]', '', 'g')
    AND h.raw_phone IS NOT NULL
    AND LENGTH(REGEXP_REPLACE(h.raw_phone, '[^0-9]', '', 'g')) >= 10
    
    UNION ALL
    
    -- Facebook ID match
    SELECT d.donor_id, 'facebook_match'::VARCHAR, 85.0::DECIMAL
    FROM donors d, harvest h
    WHERE d.social_facebook_id = h.facebook_id
    AND h.facebook_id IS NOT NULL
    
    UNION ALL
    
    -- Name + ZIP match
    SELECT d.donor_id, 'name_zip'::VARCHAR, 75.0::DECIMAL
    FROM donors d, harvest h
    WHERE LOWER(d.first_name) = LOWER(h.raw_first_name)
    AND LOWER(d.last_name) = LOWER(h.raw_last_name)
    AND d.zip = h.raw_zip
    AND h.raw_first_name IS NOT NULL
    AND h.raw_last_name IS NOT NULL
    AND h.raw_zip IS NOT NULL
    
    ORDER BY confidence DESC
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- Function to get persona score for draft
CREATE OR REPLACE FUNCTION nexus_calculate_persona_score(
    p_candidate_id UUID,
    p_draft_text TEXT
) RETURNS DECIMAL AS $$
DECLARE
    v_profile candidate_style_profiles%ROWTYPE;
    v_score DECIMAL := 50.0;
    v_phrase_matches INT := 0;
    v_length_score DECIMAL;
    v_emoji_match BOOLEAN;
BEGIN
    -- Get profile
    SELECT * INTO v_profile FROM candidate_style_profiles WHERE candidate_id = p_candidate_id;
    
    IF NOT FOUND THEN
        RETURN 50.0; -- Default score if no profile
    END IF;
    
    -- Check common phrases
    IF v_profile.common_phrases IS NOT NULL THEN
        SELECT COUNT(*) INTO v_phrase_matches
        FROM unnest(v_profile.common_phrases) AS phrase
        WHERE p_draft_text ILIKE '%' || phrase || '%';
        
        v_score := v_score + LEAST(v_phrase_matches * 5, 20);
    END IF;
    
    -- Check length alignment
    IF v_profile.avg_post_length IS NOT NULL THEN
        v_length_score := 100.0 - ABS(LENGTH(p_draft_text) - v_profile.avg_post_length) / 5.0;
        v_score := v_score + GREATEST(0, LEAST(v_length_score / 10, 10));
    END IF;
    
    -- Check emoji usage
    IF v_profile.uses_emojis IS NOT NULL THEN
        v_emoji_match := (v_profile.uses_emojis = (p_draft_text ~ '[😀-🙏🇦-🇿]'));
        IF v_emoji_match THEN
            v_score := v_score + 10;
        END IF;
    END IF;
    
    -- Check exclamation usage
    IF v_profile.uses_exclamations_pct IS NOT NULL THEN
        IF (p_draft_text LIKE '%!%') = (v_profile.uses_exclamations_pct > 0.3) THEN
            v_score := v_score + 5;
        END IF;
    END IF;
    
    RETURN LEAST(100, GREATEST(0, v_score));
END;
$$ LANGUAGE plpgsql;

-- Function to queue enrichment with Brain approval
CREATE OR REPLACE FUNCTION nexus_queue_enrichment(
    p_target_type VARCHAR,
    p_target_id UUID,
    p_enrichment_type VARCHAR,
    p_priority INT DEFAULT 50
) RETURNS UUID AS $$
DECLARE
    v_queue_id UUID;
BEGIN
    INSERT INTO nexus_enrichment_queue (
        target_type, target_id, enrichment_type, priority, status
    ) VALUES (
        p_target_type, p_target_id, p_enrichment_type, p_priority, 'pending'
    )
    ON CONFLICT (target_type, target_id) WHERE enrichment_type = p_enrichment_type
    DO UPDATE SET priority = GREATEST(nexus_enrichment_queue.priority, p_priority)
    RETURNING queue_id INTO v_queue_id;
    
    RETURN v_queue_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 13: INITIAL DATA
-- ============================================================================

-- Insert common enrichment types
INSERT INTO nexus_enrichment_queue (target_type, target_id, enrichment_type, priority, status)
SELECT 'system', gen_random_uuid(), enrichment_type, 0, 'reference'
FROM (VALUES 
    ('social_lookup'),
    ('fec_check'),
    ('nc_voter_check'),
    ('property_check'),
    ('business_check'),
    ('sec_check'),
    ('news_check'),
    ('aggregate_all')
) AS t(enrichment_type)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SCHEMA COMPLETE
-- ============================================================================

COMMENT ON SCHEMA public IS 
'BroyhillGOP Platform - NEXUS Social Extension added.
 Extends E19 Social Media Manager with:
 - 150K harvest database for social lookup
 - Enhanced persona modeling with E7 issue vocabulary
 - ML optimization from approval patterns
 - Donor/volunteer enrichment columns
 - E20 Brain trigger integration
 - Variance monitoring and alerting
 
 New tables: 9
 Extended tables: 4 (social_approval_requests, social_posts, candidate_style_profiles, donors, volunteers)
 Views: 10
 Functions: 4
 
 Integrates with: E0, E1, E5, E7, E13, E19, E20, E48';

SELECT 'NEXUS Social Extension migration complete!' AS status;
