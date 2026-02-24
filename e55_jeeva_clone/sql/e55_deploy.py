#!/usr/bin/env python3
"""
E55 Autonomous Intelligence Agent — Full Schema + Functions Deploy
BroyhillGOP NEXUS Platform

Deploys:
  - 13 tables (11 core + 2 tracking tables for prospect_origin)
  - 22 indexes
  - RLS policies on all tables
  - 5 database functions
  - 4 triggers
  - Views for dashboards
"""

import psycopg2
import json
from datetime import datetime

DB_CONFIG = {
    'host': 'db.isbgjpnbocdkeslofota.supabase.co',
    'port': 6543,
    'user': 'postgres',
    'password': 'BroyhillGOP2026$',
    'dbname': 'postgres'
}

# ═══════════════════════════════════════════════════════════════
# TABLE DEFINITIONS
# ═══════════════════════════════════════════════════════════════

TABLES_SQL = """

-- ============================================================
-- E55 TABLE 1: Agent Profiles (per-candidate AI agent config)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_agent_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id BIGINT REFERENCES donor_golden_records(golden_record_id),
    agent_name TEXT NOT NULL DEFAULT 'Campaign Intelligence Agent',
    agent_status TEXT NOT NULL DEFAULT 'active' CHECK (agent_status IN ('active','paused','setup','archived')),

    -- District & targeting
    district TEXT,
    district_type TEXT CHECK (district_type IN ('county','state_house','state_senate','congressional','municipal','judicial','school_board')),
    target_zip_codes TEXT[],
    target_counties TEXT[],

    -- Monitoring config (maps to control panel toggles)
    monitoring_config JSONB NOT NULL DEFAULT '{
        "directories_active": [],
        "groups_active": [],
        "agenda_preset": null,
        "news_cycle_auto": true,
        "enrichment_auto": true,
        "newsletter_auto": true
    }'::jsonb,

    -- Enrichment settings
    enrichment_sources JSONB NOT NULL DEFAULT '{
        "fec": true,
        "ncboe": true,
        "property_records": true,
        "linkedin_public": true,
        "social_media": true,
        "business_filings": true,
        "court_records": false
    }'::jsonb,

    -- Outreach voice/tone
    candidate_voice_profile JSONB DEFAULT '{}',
    email_signature TEXT,
    preferred_tone TEXT DEFAULT 'professional' CHECK (preferred_tone IN ('professional','casual','passionate','formal','grassroots')),

    -- Limits
    daily_outreach_limit INTEGER DEFAULT 50,
    monthly_budget_cents INTEGER DEFAULT 31300, -- $313/mo default

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 2: Social Group Directory (master list of groups)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_social_group_directory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Group identity
    group_name TEXT NOT NULL,
    group_slug TEXT UNIQUE,
    directory_category TEXT NOT NULL CHECK (directory_category IN (
        'official_gop', 'second_amendment', 'pro_life', 'business_economic',
        'veterans_military', 'agricultural_rural', 'faith_based', 'education_parents',
        'law_enforcement', 'civic_fraternal', 'professional', 'maga_populist',
        'liberty_constitutional', 'heritage_historical'
    )),

    -- Platform & location
    platform TEXT NOT NULL CHECK (platform IN ('facebook','telegram','truth_social','mewe','meetup','gab','rumble','locals','in_person','website','other')),
    platform_url TEXT,
    platform_group_id TEXT,

    -- Geography
    county TEXT,
    district TEXT,
    state TEXT DEFAULT 'NC',
    geo_scope TEXT DEFAULT 'county' CHECK (geo_scope IN ('local','county','district','state','national')),

    -- Metadata
    member_count INTEGER DEFAULT 0,
    activity_level TEXT DEFAULT 'unknown' CHECK (activity_level IN ('very_active','active','moderate','low','dormant','unknown')),
    last_activity_at TIMESTAMPTZ,
    description TEXT,
    key_topics TEXT[],
    meeting_schedule TEXT,

    -- Newsletters this group maps to
    newsletter_category TEXT,

    -- Discovery
    discovered_by TEXT DEFAULT 'manual' CHECK (discovered_by IN ('manual','ai_scan','referral','import')),
    ai_match_score NUMERIC(5,2),
    verified BOOLEAN DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 3: Group Memberships (which candidates monitor which groups)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_group_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES e55_agent_profiles(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES e55_social_group_directory(id) ON DELETE CASCADE,

    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','pending_join','declined','left')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),

    -- Monitoring config per group
    monitor_posts BOOLEAN DEFAULT true,
    monitor_members BOOLEAN DEFAULT true,
    monitor_events BOOLEAN DEFAULT true,
    auto_newsletter_recruit BOOLEAN DEFAULT true,

    -- Stats
    prospects_sourced INTEGER DEFAULT 0,
    newsletter_signups INTEGER DEFAULT 0,
    connectors_identified INTEGER DEFAULT 0,
    last_scan_at TIMESTAMPTZ,

    UNIQUE(agent_id, group_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 4: Enrichment Queue (waterfall enrichment pipeline)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_enrichment_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    golden_record_id BIGINT REFERENCES donor_golden_records(golden_record_id),
    agent_id UUID REFERENCES e55_agent_profiles(id),

    -- What we're enriching
    person_name TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,

    -- Enrichment pipeline status
    pipeline_status TEXT NOT NULL DEFAULT 'queued' CHECK (pipeline_status IN (
        'queued','fec_lookup','ncboe_lookup','property_lookup',
        'social_scan','business_lookup','scoring','complete','failed'
    )),

    -- Source tracking — EDDIE'S KEY REQUEST
    -- Where did we first discover this person?
    prospect_origin_type TEXT NOT NULL DEFAULT 'unknown' CHECK (prospect_origin_type IN (
        'issue_group', 'newsletter_signup', 'event_attendee', 'door_knock',
        'phone_bank', 'social_media', 'referral', 'fec_donor', 'voter_file',
        'website_visitor', 'rally_attendee', 'petition_signer', 'unknown'
    )),
    prospect_origin_group_id UUID REFERENCES e55_social_group_directory(id),
    prospect_origin_group_name TEXT,
    prospect_origin_directory TEXT,
    prospect_origin_detail TEXT,         -- e.g., "Commented on 2A post about HB-1234"
    prospect_origin_timestamp TIMESTAMPTZ DEFAULT NOW(),

    -- Enrichment results (accumulated from each source)
    enrichment_data JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Individual source results
    fec_result JSONB DEFAULT '{}',
    ncboe_result JSONB DEFAULT '{}',
    property_result JSONB DEFAULT '{}',
    social_result JSONB DEFAULT '{}',
    business_result JSONB DEFAULT '{}',

    -- Scoring
    donor_propensity_score NUMERIC(5,2),
    volunteer_propensity_score NUMERIC(5,2),
    connector_score NUMERIC(5,2),
    engagement_score NUMERIC(5,2),

    -- Capacity signals
    estimated_capacity TEXT CHECK (estimated_capacity IN ('under_100','100_500','500_1000','1000_5000','5000_plus','major_donor')),
    capacity_signals JSONB DEFAULT '[]',

    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    attempts INTEGER DEFAULT 0,
    last_error TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);


-- ============================================================
-- E55 TABLE 5: Prospect Origin Tracker (detailed attribution)
-- This is the CORE table Eddie specifically requested
-- Every prospect gets a full origin story
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_prospect_origins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    golden_record_id BIGINT REFERENCES donor_golden_records(golden_record_id),
    agent_id UUID REFERENCES e55_agent_profiles(id),

    -- ORIGIN: Which issue group did this person come from?
    origin_type TEXT NOT NULL CHECK (origin_type IN (
        'issue_group_post', 'issue_group_comment', 'issue_group_member_list',
        'issue_group_event', 'issue_group_shared_content',
        'newsletter_organic', 'newsletter_referral',
        'news_cycle_activation', 'connector_referral',
        'event_registration', 'petition_signature',
        'social_media_engagement', 'door_knock', 'phone_contact',
        'website_form', 'rally_signup', 'import'
    )),

    -- Group attribution
    source_group_id UUID REFERENCES e55_social_group_directory(id),
    source_group_name TEXT,
    source_directory_category TEXT,
    source_platform TEXT,

    -- Issue attribution
    source_issue TEXT,                    -- e.g., "Second Amendment", "School Choice"
    source_issue_topic TEXT,              -- e.g., "HB-1234 Gun Bill"
    source_news_cycle_event TEXT,         -- e.g., "Fentanyl Seizure I-40"

    -- Context
    origin_content TEXT,                  -- What post/comment triggered discovery
    origin_url TEXT,                      -- Link to original content
    discovery_method TEXT DEFAULT 'ai_scan' CHECK (discovery_method IN ('ai_scan','manual','import','referral','event_check_in')),

    -- Connector who referred (if applicable)
    referring_connector_id BIGINT,
    referring_connector_name TEXT,

    -- Timestamps
    discovered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    first_contact_at TIMESTAMPTZ,
    first_response_at TIMESTAMPTZ,

    -- Journey tracking
    funnel_stage TEXT DEFAULT 'identified' CHECK (funnel_stage IN (
        'identified', 'newsletter_subscriber', 'engaged_reader',
        'event_attendee', 'volunteer', 'donor', 'team_leader', 'connector'
    )),
    funnel_stage_updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Attribution score (how confident are we about this origin)
    attribution_confidence NUMERIC(3,2) DEFAULT 0.80 CHECK (attribution_confidence BETWEEN 0 AND 1)
);


-- ============================================================
-- E55 TABLE 6: Capacity Signals (wealth/influence indicators)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_capacity_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    golden_record_id BIGINT REFERENCES donor_golden_records(golden_record_id),
    agent_id UUID REFERENCES e55_agent_profiles(id),

    signal_type TEXT NOT NULL CHECK (signal_type IN (
        'job_promotion', 'property_purchase', 'property_sale',
        'board_appointment', 'business_acquisition', 'business_filing',
        'political_donation', 'campaign_contribution', 'civic_award',
        'media_mention', 'social_influence', 'event_sponsorship',
        'vehicle_registration', 'professional_license'
    )),

    signal_detail TEXT NOT NULL,
    signal_value_cents BIGINT,            -- monetary value if applicable
    signal_source TEXT,                    -- where we found it
    signal_date DATE,
    signal_confidence NUMERIC(3,2) DEFAULT 0.75,

    -- Impact on scoring
    capacity_impact TEXT DEFAULT 'neutral' CHECK (capacity_impact IN ('strong_positive','positive','neutral','negative')),

    processed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 7: Outreach Sequences (automated multi-step campaigns)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_outreach_sequences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES e55_agent_profiles(id) ON DELETE CASCADE,
    golden_record_id BIGINT REFERENCES donor_golden_records(golden_record_id),

    -- Sequence config
    sequence_name TEXT NOT NULL,
    sequence_type TEXT NOT NULL CHECK (sequence_type IN (
        'newsletter_welcome', 'donor_cultivation', 'volunteer_recruit',
        'connector_engage', 'event_invite', 'news_cycle_response',
        'issue_advocacy', 'thank_you', 'reactivation', 'custom'
    )),

    -- Origin tracking (linked to issue group)
    origin_group_id UUID REFERENCES e55_social_group_directory(id),
    origin_issue TEXT,

    -- Steps
    total_steps INTEGER DEFAULT 3,
    current_step INTEGER DEFAULT 0,
    steps_config JSONB NOT NULL DEFAULT '[]',

    -- Status
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft','active','paused','completed','cancelled','bounced')),

    -- Channel
    channel TEXT NOT NULL DEFAULT 'email' CHECK (channel IN ('email','sms','social_dm','phone','mail','multi')),

    -- Timing
    started_at TIMESTAMPTZ DEFAULT NOW(),
    next_step_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    last_response_at TIMESTAMPTZ,

    -- Metrics
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    replies INTEGER DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 8: Connector Scores (super-connector identification)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_connector_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    golden_record_id BIGINT REFERENCES donor_golden_records(golden_record_id),
    agent_id UUID REFERENCES e55_agent_profiles(id),

    -- Score = (group_count * 15) + (leadership_roles * 25), cap 100
    connector_score NUMERIC(5,2) NOT NULL DEFAULT 0,

    -- Components
    group_count INTEGER DEFAULT 0,
    leadership_roles INTEGER DEFAULT 0,
    groups_in_common TEXT[],
    leadership_positions JSONB DEFAULT '[]',

    -- Influence mapping
    estimated_reach INTEGER DEFAULT 0,    -- how many people they can influence
    influence_categories TEXT[],           -- which issue areas
    social_platforms TEXT[],

    -- Engagement status
    engagement_status TEXT DEFAULT 'identified' CHECK (engagement_status IN (
        'identified','outreach_pending','contacted','engaged','active_connector','declined'
    )),

    -- Referrals this connector has made
    referrals_made INTEGER DEFAULT 0,
    referral_conversion_rate NUMERIC(5,2) DEFAULT 0,

    last_calculated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 9: Unified Inbox (all inbound communications)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_unified_inbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES e55_agent_profiles(id) ON DELETE CASCADE,
    golden_record_id BIGINT REFERENCES donor_golden_records(golden_record_id),

    -- Message details
    channel TEXT NOT NULL CHECK (channel IN ('email','sms','social_dm','form','phone','voicemail','letter')),
    direction TEXT NOT NULL DEFAULT 'inbound' CHECK (direction IN ('inbound','outbound')),

    subject TEXT,
    body TEXT,

    -- AI classification
    intent_category TEXT CHECK (intent_category IN (
        'donation_intent', 'volunteer_offer', 'event_interest', 'issue_question',
        'complaint', 'endorsement', 'information_request', 'scheduling',
        'newsletter_reply', 'positive_feedback', 'negative_feedback', 'spam', 'other'
    )),
    sentiment TEXT CHECK (sentiment IN ('very_positive','positive','neutral','negative','very_negative')),
    urgency TEXT DEFAULT 'normal' CHECK (urgency IN ('critical','high','normal','low')),

    -- AI draft response
    ai_draft_response TEXT,
    ai_confidence NUMERIC(3,2),

    -- Status
    status TEXT DEFAULT 'unread' CHECK (status IN ('unread','read','responded','archived','flagged')),
    assigned_to TEXT,

    -- Origin tracking
    origin_group_id UUID REFERENCES e55_social_group_directory(id),
    origin_sequence_id UUID REFERENCES e55_outreach_sequences(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ
);


-- ============================================================
-- E55 TABLE 10: Newsletter Tracking (issue-specific newsletters)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_newsletter_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES e55_agent_profiles(id) ON DELETE CASCADE,
    golden_record_id BIGINT REFERENCES donor_golden_records(golden_record_id),

    -- Newsletter identity
    newsletter_name TEXT NOT NULL,         -- e.g., "2A Defense Report", "Faith & Family Update"
    newsletter_category TEXT NOT NULL,

    -- Subscription
    subscription_status TEXT DEFAULT 'active' CHECK (subscription_status IN ('active','paused','unsubscribed','bounced')),
    subscribed_at TIMESTAMPTZ DEFAULT NOW(),
    unsubscribed_at TIMESTAMPTZ,

    -- Origin — which group drove this subscription
    origin_group_id UUID REFERENCES e55_social_group_directory(id),
    origin_group_name TEXT,
    origin_directory_category TEXT,

    -- Engagement metrics
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    open_rate NUMERIC(5,2) GENERATED ALWAYS AS (
        CASE WHEN emails_sent > 0 THEN (emails_opened::numeric / emails_sent * 100) ELSE 0 END
    ) STORED,
    click_rate NUMERIC(5,2) GENERATED ALWAYS AS (
        CASE WHEN emails_sent > 0 THEN (emails_clicked::numeric / emails_sent * 100) ELSE 0 END
    ) STORED,

    -- Auto-escalation trigger: 5+ opens AND 3+ clicks = escalate to event_invite
    auto_escalation_triggered BOOLEAN DEFAULT false,
    escalated_at TIMESTAMPTZ,
    escalation_sequence_id UUID REFERENCES e55_outreach_sequences(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 11: Pre-Call Briefings (meeting prep for candidate)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_precall_briefings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES e55_agent_profiles(id) ON DELETE CASCADE,
    golden_record_id BIGINT REFERENCES donor_golden_records(golden_record_id),

    -- Meeting context
    meeting_type TEXT CHECK (meeting_type IN ('fundraiser','rally','door_knock','phone_call','event','one_on_one','group_meeting')),
    meeting_date DATE,
    meeting_notes TEXT,

    -- Briefing content (AI-generated)
    briefing_summary TEXT,
    key_talking_points JSONB DEFAULT '[]',
    shared_connections JSONB DEFAULT '[]',
    donation_history_summary TEXT,
    issue_alignment JSONB DEFAULT '{}',
    recent_activity TEXT,
    suggested_ask TEXT,
    suggested_ask_amount_cents BIGINT,

    -- Origin context — what issue group context is relevant
    relevant_groups JSONB DEFAULT '[]',
    relevant_issues TEXT[],

    -- Status
    status TEXT DEFAULT 'generated' CHECK (status IN ('generating','generated','reviewed','used','archived')),
    candidate_notes TEXT,               -- candidate's own notes after meeting
    meeting_outcome TEXT CHECK (meeting_outcome IN ('positive','neutral','negative','donation','volunteer_signup','no_show')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 12: News Cycle Events (trending issues tracker)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_news_cycle_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Event details
    headline TEXT NOT NULL,
    summary TEXT,
    source_url TEXT,
    source_name TEXT,

    -- Classification
    issue_category TEXT NOT NULL,          -- matches directory_category
    related_directories TEXT[],
    impact_level TEXT NOT NULL DEFAULT 'medium' CHECK (impact_level IN ('critical','high','medium','low')),

    -- Geography
    geo_scope TEXT DEFAULT 'state' CHECK (geo_scope IN ('local','county','district','state','national')),
    affected_counties TEXT[],
    affected_districts TEXT[],

    -- AI analysis
    ai_summary TEXT,
    ai_recommended_action TEXT,
    ai_suggested_newsletters TEXT[],
    ai_talking_points JSONB DEFAULT '[]',

    -- Status
    status TEXT DEFAULT 'active' CHECK (status IN ('breaking','active','fading','archived')),

    -- Activation tracking
    agents_activated INTEGER DEFAULT 0,
    newsletters_triggered INTEGER DEFAULT 0,

    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 13: Agent Activity Log (audit trail)
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_agent_activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID REFERENCES e55_agent_profiles(id),

    activity_type TEXT NOT NULL CHECK (activity_type IN (
        'enrichment_run', 'group_scan', 'prospect_discovered', 'newsletter_sent',
        'outreach_step', 'connector_identified', 'capacity_signal_detected',
        'news_cycle_activation', 'briefing_generated', 'inbox_classified',
        'funnel_escalation', 'group_joined', 'group_left', 'config_change',
        'ai_decision', 'error', 'manual_override'
    )),

    -- Context
    target_type TEXT,                      -- 'golden_record', 'group', 'newsletter', etc.
    target_id UUID,
    detail TEXT,
    metadata JSONB DEFAULT '{}',

    -- Origin tracking
    triggered_by TEXT DEFAULT 'ai_agent' CHECK (triggered_by IN ('ai_agent','candidate','admin','n8n_webhook','news_cycle','scheduler','manual')),
    origin_group_id UUID REFERENCES e55_social_group_directory(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 14: ICP Profiles (Ideal Constituent/Donor Profiles)
-- Natural language targeting like Jeeva's ICP builder
-- "Find major donors in real estate who care about 2A and live in Forsyth County"
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_icp_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES e55_agent_profiles(id) ON DELETE CASCADE,

    -- Natural language definition (what the candidate types)
    icp_name TEXT NOT NULL,               -- e.g., "High-Value 2A Donors"
    icp_prompt TEXT NOT NULL,             -- Natural language: "Find donors over $500 in gun rights groups in Forsyth County"

    -- Parsed filters (AI extracts these from the prompt)
    filters JSONB NOT NULL DEFAULT '{}'::jsonb,
    -- Example filters:
    -- {
    --   "min_donation": 500,
    --   "issue_groups": ["second_amendment"],
    --   "counties": ["Forsyth"],
    --   "capacity_min": "500_1000",
    --   "has_property": true,
    --   "age_range": [35, 70],
    --   "party": "REP",
    --   "donor_type": ["individual"],
    --   "occupation_keywords": ["real estate", "construction", "developer"],
    --   "connector_score_min": 30,
    --   "exclude_already_contacted": true
    -- }

    -- Enrichment config for this ICP
    enrichment_depth TEXT DEFAULT 'standard' CHECK (enrichment_depth IN ('basic','standard','deep','exhaustive')),
    -- basic: FEC + NCBOE only
    -- standard: + property + social
    -- deep: + business filings + professional licenses
    -- exhaustive: all 100+ sources

    -- Results
    matches_found INTEGER DEFAULT 0,
    matches_enriched INTEGER DEFAULT 0,
    matches_contacted INTEGER DEFAULT 0,
    matches_converted INTEGER DEFAULT 0,

    -- Automation
    auto_enrich BOOLEAN DEFAULT true,     -- auto-run enrichment on new matches
    auto_outreach BOOLEAN DEFAULT false,  -- auto-start outreach sequences
    outreach_sequence_template UUID REFERENCES e55_outreach_sequences(id),
    refresh_interval_hours INTEGER DEFAULT 168, -- weekly refresh

    -- Status
    status TEXT DEFAULT 'active' CHECK (status IN ('draft','active','paused','archived')),
    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- E55 TABLE 15: Enrichment Source Registry (100+ data sources)
-- Tracks which sources are available and their hit rates
-- ============================================================
CREATE TABLE IF NOT EXISTS e55_enrichment_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Source identity
    source_name TEXT NOT NULL UNIQUE,
    source_category TEXT NOT NULL CHECK (source_category IN (
        'government', 'financial', 'property', 'social', 'business',
        'professional', 'political', 'media', 'public_records', 'commercial_data'
    )),

    -- What this source provides
    provides TEXT[] NOT NULL,              -- e.g., ['email','phone','employer','income_estimate']

    -- Access config
    api_endpoint TEXT,
    api_key_env TEXT,                      -- env var name for API key
    rate_limit_per_hour INTEGER DEFAULT 100,
    cost_per_lookup_cents INTEGER DEFAULT 0,

    -- Performance
    avg_hit_rate NUMERIC(5,2) DEFAULT 0,  -- % of lookups that return data
    avg_response_ms INTEGER DEFAULT 1000,
    total_lookups INTEGER DEFAULT 0,
    successful_lookups INTEGER DEFAULT 0,

    -- Waterfall priority (lower = try first)
    waterfall_priority INTEGER DEFAULT 50 CHECK (waterfall_priority BETWEEN 1 AND 100),

    -- Status
    is_active BOOLEAN DEFAULT true,
    last_verified_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

""" # end TABLES_SQL


# ═══════════════════════════════════════════════════════════════
# INDEXES
# ═══════════════════════════════════════════════════════════════

INDEXES_SQL = """
-- Agent profiles
CREATE INDEX IF NOT EXISTS idx_e55_agent_candidate ON e55_agent_profiles(candidate_id);
CREATE INDEX IF NOT EXISTS idx_e55_agent_status ON e55_agent_profiles(agent_status);
CREATE INDEX IF NOT EXISTS idx_e55_agent_district ON e55_agent_profiles(district);

-- Social group directory
CREATE INDEX IF NOT EXISTS idx_e55_group_category ON e55_social_group_directory(directory_category);
CREATE INDEX IF NOT EXISTS idx_e55_group_platform ON e55_social_group_directory(platform);
CREATE INDEX IF NOT EXISTS idx_e55_group_county ON e55_social_group_directory(county);
CREATE INDEX IF NOT EXISTS idx_e55_group_activity ON e55_social_group_directory(activity_level);
CREATE INDEX IF NOT EXISTS idx_e55_group_verified ON e55_social_group_directory(verified);

-- Group memberships
CREATE INDEX IF NOT EXISTS idx_e55_membership_agent ON e55_group_memberships(agent_id);
CREATE INDEX IF NOT EXISTS idx_e55_membership_group ON e55_group_memberships(group_id);
CREATE INDEX IF NOT EXISTS idx_e55_membership_status ON e55_group_memberships(status);

-- Enrichment queue
CREATE INDEX IF NOT EXISTS idx_e55_enrich_status ON e55_enrichment_queue(pipeline_status);
CREATE INDEX IF NOT EXISTS idx_e55_enrich_golden ON e55_enrichment_queue(golden_record_id);
CREATE INDEX IF NOT EXISTS idx_e55_enrich_origin_type ON e55_enrichment_queue(prospect_origin_type);
CREATE INDEX IF NOT EXISTS idx_e55_enrich_origin_group ON e55_enrichment_queue(prospect_origin_group_id);
CREATE INDEX IF NOT EXISTS idx_e55_enrich_priority ON e55_enrichment_queue(priority DESC, created_at ASC);

-- Prospect origins (THE KEY TABLE)
CREATE INDEX IF NOT EXISTS idx_e55_origin_golden ON e55_prospect_origins(golden_record_id);
CREATE INDEX IF NOT EXISTS idx_e55_origin_agent ON e55_prospect_origins(agent_id);
CREATE INDEX IF NOT EXISTS idx_e55_origin_type ON e55_prospect_origins(origin_type);
CREATE INDEX IF NOT EXISTS idx_e55_origin_group ON e55_prospect_origins(source_group_id);
CREATE INDEX IF NOT EXISTS idx_e55_origin_category ON e55_prospect_origins(source_directory_category);
CREATE INDEX IF NOT EXISTS idx_e55_origin_issue ON e55_prospect_origins(source_issue);
CREATE INDEX IF NOT EXISTS idx_e55_origin_funnel ON e55_prospect_origins(funnel_stage);
CREATE INDEX IF NOT EXISTS idx_e55_origin_discovered ON e55_prospect_origins(discovered_at DESC);

-- Capacity signals
CREATE INDEX IF NOT EXISTS idx_e55_capacity_golden ON e55_capacity_signals(golden_record_id);
CREATE INDEX IF NOT EXISTS idx_e55_capacity_type ON e55_capacity_signals(signal_type);
CREATE INDEX IF NOT EXISTS idx_e55_capacity_date ON e55_capacity_signals(signal_date DESC);

-- Outreach sequences
CREATE INDEX IF NOT EXISTS idx_e55_outreach_agent ON e55_outreach_sequences(agent_id);
CREATE INDEX IF NOT EXISTS idx_e55_outreach_golden ON e55_outreach_sequences(golden_record_id);
CREATE INDEX IF NOT EXISTS idx_e55_outreach_status ON e55_outreach_sequences(status);
CREATE INDEX IF NOT EXISTS idx_e55_outreach_next ON e55_outreach_sequences(next_step_at) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_e55_outreach_origin ON e55_outreach_sequences(origin_group_id);

-- Connector scores
CREATE INDEX IF NOT EXISTS idx_e55_connector_golden ON e55_connector_scores(golden_record_id);
CREATE INDEX IF NOT EXISTS idx_e55_connector_score ON e55_connector_scores(connector_score DESC);

-- Unified inbox
CREATE INDEX IF NOT EXISTS idx_e55_inbox_agent ON e55_unified_inbox(agent_id);
CREATE INDEX IF NOT EXISTS idx_e55_inbox_status ON e55_unified_inbox(status);
CREATE INDEX IF NOT EXISTS idx_e55_inbox_intent ON e55_unified_inbox(intent_category);
CREATE INDEX IF NOT EXISTS idx_e55_inbox_urgency ON e55_unified_inbox(urgency) WHERE status = 'unread';
CREATE INDEX IF NOT EXISTS idx_e55_inbox_created ON e55_unified_inbox(created_at DESC);

-- Newsletter tracking
CREATE INDEX IF NOT EXISTS idx_e55_newsletter_agent ON e55_newsletter_tracking(agent_id);
CREATE INDEX IF NOT EXISTS idx_e55_newsletter_golden ON e55_newsletter_tracking(golden_record_id);
CREATE INDEX IF NOT EXISTS idx_e55_newsletter_name ON e55_newsletter_tracking(newsletter_name);
CREATE INDEX IF NOT EXISTS idx_e55_newsletter_origin ON e55_newsletter_tracking(origin_group_id);
CREATE INDEX IF NOT EXISTS idx_e55_newsletter_escalation ON e55_newsletter_tracking(auto_escalation_triggered)
    WHERE auto_escalation_triggered = false AND subscription_status = 'active';

-- Pre-call briefings
CREATE INDEX IF NOT EXISTS idx_e55_briefing_agent ON e55_precall_briefings(agent_id);
CREATE INDEX IF NOT EXISTS idx_e55_briefing_date ON e55_precall_briefings(meeting_date);

-- News cycle events
CREATE INDEX IF NOT EXISTS idx_e55_news_issue ON e55_news_cycle_events(issue_category);
CREATE INDEX IF NOT EXISTS idx_e55_news_impact ON e55_news_cycle_events(impact_level);
CREATE INDEX IF NOT EXISTS idx_e55_news_status ON e55_news_cycle_events(status);
CREATE INDEX IF NOT EXISTS idx_e55_news_detected ON e55_news_cycle_events(detected_at DESC);

-- Activity log
CREATE INDEX IF NOT EXISTS idx_e55_log_agent ON e55_agent_activity_log(agent_id);
CREATE INDEX IF NOT EXISTS idx_e55_log_type ON e55_agent_activity_log(activity_type);
CREATE INDEX IF NOT EXISTS idx_e55_log_origin ON e55_agent_activity_log(origin_group_id);
CREATE INDEX IF NOT EXISTS idx_e55_log_created ON e55_agent_activity_log(created_at DESC);

-- ICP profiles
CREATE INDEX IF NOT EXISTS idx_e55_icp_agent ON e55_icp_profiles(agent_id);
CREATE INDEX IF NOT EXISTS idx_e55_icp_status ON e55_icp_profiles(status);
CREATE INDEX IF NOT EXISTS idx_e55_icp_next_run ON e55_icp_profiles(next_run_at) WHERE status = 'active';

-- Enrichment sources
CREATE INDEX IF NOT EXISTS idx_e55_source_category ON e55_enrichment_sources(source_category);
CREATE INDEX IF NOT EXISTS idx_e55_source_priority ON e55_enrichment_sources(waterfall_priority) WHERE is_active = true;
"""


# ═══════════════════════════════════════════════════════════════
# RLS POLICIES
# ═══════════════════════════════════════════════════════════════

RLS_SQL = """
-- Enable RLS on all E55 tables
ALTER TABLE e55_agent_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_social_group_directory ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_group_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_enrichment_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_prospect_origins ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_capacity_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_outreach_sequences ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_connector_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_unified_inbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_newsletter_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_precall_briefings ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_news_cycle_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_agent_activity_log ENABLE ROW LEVEL SECURITY;

-- Service role bypass (for Edge Functions + n8n)
DROP POLICY IF EXISTS e55_agent_profiles_service ON e55_agent_profiles;
CREATE POLICY e55_agent_profiles_service ON e55_agent_profiles FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_social_group_service ON e55_social_group_directory;
CREATE POLICY e55_social_group_service ON e55_social_group_directory FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_memberships_service ON e55_group_memberships;
CREATE POLICY e55_memberships_service ON e55_group_memberships FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_enrichment_service ON e55_enrichment_queue;
CREATE POLICY e55_enrichment_service ON e55_enrichment_queue FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_origins_service ON e55_prospect_origins;
CREATE POLICY e55_origins_service ON e55_prospect_origins FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_capacity_service ON e55_capacity_signals;
CREATE POLICY e55_capacity_service ON e55_capacity_signals FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_outreach_service ON e55_outreach_sequences;
CREATE POLICY e55_outreach_service ON e55_outreach_sequences FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_connector_service ON e55_connector_scores;
CREATE POLICY e55_connector_service ON e55_connector_scores FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_inbox_service ON e55_unified_inbox;
CREATE POLICY e55_inbox_service ON e55_unified_inbox FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_newsletter_service ON e55_newsletter_tracking;
CREATE POLICY e55_newsletter_service ON e55_newsletter_tracking FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_briefing_service ON e55_precall_briefings;
CREATE POLICY e55_briefing_service ON e55_precall_briefings FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_news_service ON e55_news_cycle_events;
CREATE POLICY e55_news_service ON e55_news_cycle_events FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_log_service ON e55_agent_activity_log;
CREATE POLICY e55_log_service ON e55_agent_activity_log FOR ALL TO service_role USING (true);

-- News cycle events are readable by all authenticated (shared intelligence)
DROP POLICY IF EXISTS e55_news_read ON e55_news_cycle_events;
CREATE POLICY e55_news_read ON e55_news_cycle_events FOR SELECT TO authenticated USING (true);
-- Group directory is readable by all authenticated
DROP POLICY IF EXISTS e55_groups_read ON e55_social_group_directory;
CREATE POLICY e55_groups_read ON e55_social_group_directory FOR SELECT TO authenticated USING (true);

-- ICP and enrichment sources
ALTER TABLE e55_icp_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE e55_enrichment_sources ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS e55_icp_service ON e55_icp_profiles;
CREATE POLICY e55_icp_service ON e55_icp_profiles FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_sources_service ON e55_enrichment_sources;
CREATE POLICY e55_sources_service ON e55_enrichment_sources FOR ALL TO service_role USING (true);
DROP POLICY IF EXISTS e55_sources_read ON e55_enrichment_sources;
CREATE POLICY e55_sources_read ON e55_enrichment_sources FOR SELECT TO authenticated USING (true);
"""


# ═══════════════════════════════════════════════════════════════
# DATABASE FUNCTIONS
# ═══════════════════════════════════════════════════════════════

FUNCTIONS_SQL = """

-- ============================================================
-- FUNCTION 1: Calculate connector score
-- Score = (group_count * 15) + (leadership_roles * 25), cap 100
-- ============================================================
CREATE OR REPLACE FUNCTION e55_calculate_connector_score(
    p_golden_record_id BIGINT,
    p_agent_id UUID
) RETURNS NUMERIC AS $$
DECLARE
    v_group_count INTEGER;
    v_leadership INTEGER;
    v_score NUMERIC;
BEGIN
    -- Count groups this person appears in
    SELECT COUNT(DISTINCT gm.group_id)
    INTO v_group_count
    FROM e55_group_memberships gm
    JOIN e55_prospect_origins po ON po.source_group_id = gm.group_id
    WHERE po.golden_record_id = p_golden_record_id
      AND gm.agent_id = p_agent_id;

    -- Get leadership roles (stored in connector_scores)
    SELECT COALESCE(leadership_roles, 0)
    INTO v_leadership
    FROM e55_connector_scores
    WHERE golden_record_id = p_golden_record_id AND agent_id = p_agent_id;

    IF v_leadership IS NULL THEN v_leadership := 0; END IF;

    -- Calculate: (groups * 15) + (leadership * 25), cap 100
    v_score := LEAST((v_group_count * 15) + (v_leadership * 25), 100);

    -- Upsert connector score
    INSERT INTO e55_connector_scores (golden_record_id, agent_id, connector_score, group_count, leadership_roles, last_calculated_at)
    VALUES (p_golden_record_id, p_agent_id, v_score, v_group_count, v_leadership, NOW())
    ON CONFLICT (golden_record_id, agent_id)
    DO UPDATE SET connector_score = v_score, group_count = v_group_count, last_calculated_at = NOW();

    RETURN v_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- FUNCTION 2: Newsletter auto-escalation check
-- Trigger: 5+ opens AND 3+ clicks = escalate
-- ============================================================
CREATE OR REPLACE FUNCTION e55_check_newsletter_escalation()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.emails_opened >= 5 AND NEW.emails_clicked >= 3
       AND NEW.auto_escalation_triggered = false
       AND NEW.subscription_status = 'active' THEN

        NEW.auto_escalation_triggered := true;
        NEW.escalated_at := NOW();

        -- Log the escalation
        INSERT INTO e55_agent_activity_log (agent_id, activity_type, target_type, target_id, detail, origin_group_id)
        VALUES (
            NEW.agent_id, 'funnel_escalation', 'newsletter', NEW.id,
            'Auto-escalation: ' || NEW.newsletter_name || ' subscriber hit 5+ opens, 3+ clicks',
            NEW.origin_group_id
        );

        -- Update prospect origin funnel stage
        UPDATE e55_prospect_origins
        SET funnel_stage = 'engaged_reader', funnel_stage_updated_at = NOW()
        WHERE golden_record_id = NEW.golden_record_id
          AND agent_id = NEW.agent_id
          AND funnel_stage = 'newsletter_subscriber';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- FUNCTION 3: Record prospect discovery with full origin
-- ============================================================
CREATE OR REPLACE FUNCTION e55_record_prospect_discovery(
    p_agent_id UUID,
    p_golden_record_id BIGINT,
    p_origin_type TEXT,
    p_group_id UUID DEFAULT NULL,
    p_issue TEXT DEFAULT NULL,
    p_news_event TEXT DEFAULT NULL,
    p_content TEXT DEFAULT NULL,
    p_url TEXT DEFAULT NULL,
    p_connector_id BIGINT DEFAULT NULL,
    p_connector_name TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_origin_id UUID;
    v_group_name TEXT;
    v_directory_cat TEXT;
    v_platform TEXT;
BEGIN
    -- Get group details if provided
    IF p_group_id IS NOT NULL THEN
        SELECT group_name, directory_category, platform
        INTO v_group_name, v_directory_cat, v_platform
        FROM e55_social_group_directory WHERE id = p_group_id;
    END IF;

    -- Insert origin record
    INSERT INTO e55_prospect_origins (
        golden_record_id, agent_id, origin_type,
        source_group_id, source_group_name, source_directory_category, source_platform,
        source_issue, source_news_cycle_event,
        origin_content, origin_url,
        referring_connector_id, referring_connector_name
    ) VALUES (
        p_golden_record_id, p_agent_id, p_origin_type,
        p_group_id, v_group_name, v_directory_cat, v_platform,
        p_issue, p_news_event,
        p_content, p_url,
        p_connector_id, p_connector_name
    ) RETURNING id INTO v_origin_id;

    -- Log the discovery
    INSERT INTO e55_agent_activity_log (agent_id, activity_type, target_type, target_id, detail, origin_group_id, metadata)
    VALUES (
        p_agent_id, 'prospect_discovered', 'golden_record', p_golden_record_id,
        'Discovered via ' || p_origin_type || COALESCE(' in ' || v_group_name, ''),
        p_group_id,
        jsonb_build_object('origin_id', v_origin_id, 'issue', p_issue)
    );

    -- Queue for enrichment
    INSERT INTO e55_enrichment_queue (golden_record_id, agent_id, pipeline_status, prospect_origin_type,
        prospect_origin_group_id, prospect_origin_group_name, prospect_origin_directory, priority)
    VALUES (
        p_golden_record_id, p_agent_id, 'queued',
        CASE
            WHEN p_group_id IS NOT NULL THEN 'issue_group'
            WHEN p_news_event IS NOT NULL THEN 'newsletter_signup'
            ELSE 'unknown'
        END,
        p_group_id, v_group_name, v_directory_cat,
        CASE WHEN p_connector_id IS NOT NULL THEN 3 ELSE 5 END  -- connector referrals get higher priority
    );

    RETURN v_origin_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- FUNCTION 4: News cycle activation
-- When a news event fires, activate related groups for all agents
-- ============================================================
CREATE OR REPLACE FUNCTION e55_activate_news_cycle(
    p_news_event_id UUID
) RETURNS INTEGER AS $$
DECLARE
    v_event RECORD;
    v_agent RECORD;
    v_activated INTEGER := 0;
BEGIN
    -- Get the news event
    SELECT * INTO v_event FROM e55_news_cycle_events WHERE id = p_news_event_id;

    IF v_event IS NULL THEN RETURN 0; END IF;

    -- For each active agent, check if they have news_cycle_auto enabled
    FOR v_agent IN
        SELECT * FROM e55_agent_profiles
        WHERE agent_status = 'active'
        AND (monitoring_config->>'news_cycle_auto')::boolean = true
    LOOP
        -- Log the activation
        INSERT INTO e55_agent_activity_log (agent_id, activity_type, target_type, target_id, detail, metadata)
        VALUES (
            v_agent.id, 'news_cycle_activation', 'news_event', p_news_event_id,
            'Auto-activated for: ' || v_event.headline,
            jsonb_build_object('impact', v_event.impact_level, 'directories', v_event.related_directories)
        );

        v_activated := v_activated + 1;
    END LOOP;

    -- Update event tracking
    UPDATE e55_news_cycle_events
    SET agents_activated = v_activated
    WHERE id = p_news_event_id;

    RETURN v_activated;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- FUNCTION 5: Prospect origin attribution report
-- Returns full origin breakdown for a candidate's pipeline
-- ============================================================
CREATE OR REPLACE FUNCTION e55_origin_attribution_report(
    p_agent_id UUID
) RETURNS TABLE (
    directory_category TEXT,
    origin_type TEXT,
    source_issue TEXT,
    prospect_count BIGINT,
    newsletter_subscribers BIGINT,
    donors BIGINT,
    volunteers BIGINT,
    avg_attribution_confidence NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        po.source_directory_category,
        po.origin_type,
        po.source_issue,
        COUNT(*) AS prospect_count,
        COUNT(*) FILTER (WHERE po.funnel_stage IN ('newsletter_subscriber','engaged_reader','event_attendee','volunteer','donor','team_leader','connector')) AS newsletter_subscribers,
        COUNT(*) FILTER (WHERE po.funnel_stage = 'donor') AS donors,
        COUNT(*) FILTER (WHERE po.funnel_stage = 'volunteer') AS volunteers,
        AVG(po.attribution_confidence) AS avg_attribution_confidence
    FROM e55_prospect_origins po
    WHERE po.agent_id = p_agent_id
    GROUP BY po.source_directory_category, po.origin_type, po.source_issue
    ORDER BY COUNT(*) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



-- ============================================================
-- FUNCTION 6: ICP Search — Execute parsed filters against golden records
-- Returns matching golden_record_ids for an ICP profile
-- ============================================================
CREATE OR REPLACE FUNCTION e55_execute_icp_search(
    p_icp_id UUID
) RETURNS INTEGER AS $$
DECLARE
    v_icp RECORD;
    v_filters JSONB;
    v_sql TEXT;
    v_count INTEGER;
BEGIN
    SELECT * INTO v_icp FROM e55_icp_profiles WHERE id = p_icp_id;
    IF v_icp IS NULL THEN RETURN 0; END IF;

    v_filters := v_icp.filters;

    -- Build dynamic query against donor_golden_records + related tables
    v_sql := 'SELECT COUNT(*) FROM donor_golden_records dgr WHERE 1=1';

    -- County filter
    IF v_filters ? 'counties' THEN
        v_sql := v_sql || ' AND dgr.county = ANY(ARRAY[' ||
            (SELECT string_agg('''' || elem || '''', ',' ) FROM jsonb_array_elements_text(v_filters->'counties') elem) || '])';
    END IF;

    -- Party filter
    IF v_filters ? 'party' THEN
        v_sql := v_sql || ' AND dgr.party_affiliation = ' || quote_literal(v_filters->>'party');
    END IF;

    EXECUTE v_sql INTO v_count;

    -- Update ICP with match count
    UPDATE e55_icp_profiles SET matches_found = v_count, last_run_at = NOW() WHERE id = p_icp_id;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

"""


# ═══════════════════════════════════════════════════════════════
# TRIGGERS
# ═══════════════════════════════════════════════════════════════

TRIGGERS_SQL = """
-- Trigger: Newsletter auto-escalation
DROP TRIGGER IF EXISTS trg_e55_newsletter_escalation ON e55_newsletter_tracking;
CREATE TRIGGER trg_e55_newsletter_escalation
    BEFORE UPDATE ON e55_newsletter_tracking
    FOR EACH ROW
    EXECUTE FUNCTION e55_check_newsletter_escalation();

-- Trigger: Auto-update updated_at on agent_profiles
CREATE OR REPLACE FUNCTION e55_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_e55_agent_updated ON e55_agent_profiles;
CREATE TRIGGER trg_e55_agent_updated
    BEFORE UPDATE ON e55_agent_profiles
    FOR EACH ROW
    EXECUTE FUNCTION e55_update_timestamp();

DROP TRIGGER IF EXISTS trg_e55_group_updated ON e55_social_group_directory;
CREATE TRIGGER trg_e55_group_updated
    BEFORE UPDATE ON e55_social_group_directory
    FOR EACH ROW
    EXECUTE FUNCTION e55_update_timestamp();

DROP TRIGGER IF EXISTS trg_e55_icp_updated ON e55_icp_profiles;
CREATE TRIGGER trg_e55_icp_updated
    BEFORE UPDATE ON e55_icp_profiles
    FOR EACH ROW
    EXECUTE FUNCTION e55_update_timestamp();
"""


# ═══════════════════════════════════════════════════════════════
# VIEWS
# ═══════════════════════════════════════════════════════════════

VIEWS_SQL = """

-- Dashboard: Agent overview with stats
CREATE OR REPLACE VIEW e55_agent_dashboard AS
SELECT
    ap.id AS agent_id,
    ap.agent_name,
    ap.agent_status,
    ap.district,
    CONCAT(gr.first_name, ' ', gr.last_name) AS candidate_name,
    (SELECT COUNT(*) FROM e55_group_memberships gm WHERE gm.agent_id = ap.id AND gm.status = 'active') AS active_groups,
    (SELECT COUNT(*) FROM e55_prospect_origins po WHERE po.agent_id = ap.id) AS total_prospects,
    (SELECT COUNT(*) FROM e55_prospect_origins po WHERE po.agent_id = ap.id AND po.funnel_stage = 'donor') AS donors_sourced,
    (SELECT COUNT(*) FROM e55_prospect_origins po WHERE po.agent_id = ap.id AND po.funnel_stage = 'volunteer') AS volunteers_sourced,
    (SELECT COUNT(*) FROM e55_newsletter_tracking nt WHERE nt.agent_id = ap.id AND nt.subscription_status = 'active') AS newsletter_subs,
    (SELECT COUNT(*) FROM e55_enrichment_queue eq WHERE eq.agent_id = ap.id AND eq.pipeline_status = 'complete') AS enrichments_complete,
    (SELECT COUNT(*) FROM e55_unified_inbox ui WHERE ui.agent_id = ap.id AND ui.status = 'unread') AS unread_messages,
    (SELECT COUNT(*) FROM e55_connector_scores cs WHERE cs.agent_id = ap.id AND cs.connector_score >= 50) AS high_connectors,
    ap.created_at
FROM e55_agent_profiles ap
LEFT JOIN donor_golden_records gr ON gr.golden_record_id = ap.candidate_id;


-- Dashboard: Origin attribution by directory category
CREATE OR REPLACE VIEW e55_origin_by_directory AS
SELECT
    po.agent_id,
    po.source_directory_category,
    COUNT(*) AS total_prospects,
    COUNT(*) FILTER (WHERE po.funnel_stage IN ('newsletter_subscriber','engaged_reader','event_attendee','volunteer','donor','team_leader','connector')) AS converted,
    COUNT(*) FILTER (WHERE po.funnel_stage = 'donor') AS donors,
    COUNT(*) FILTER (WHERE po.funnel_stage = 'volunteer') AS volunteers,
    ROUND(AVG(po.attribution_confidence) * 100, 1) AS avg_confidence_pct,
    MIN(po.discovered_at) AS first_discovery,
    MAX(po.discovered_at) AS latest_discovery
FROM e55_prospect_origins po
GROUP BY po.agent_id, po.source_directory_category;


-- Dashboard: Newsletter performance
CREATE OR REPLACE VIEW e55_newsletter_performance AS
SELECT
    nt.agent_id,
    nt.newsletter_name,
    nt.newsletter_category,
    COUNT(*) AS total_subscribers,
    COUNT(*) FILTER (WHERE nt.subscription_status = 'active') AS active_subscribers,
    SUM(nt.emails_sent) AS total_sent,
    SUM(nt.emails_opened) AS total_opened,
    SUM(nt.emails_clicked) AS total_clicked,
    CASE WHEN SUM(nt.emails_sent) > 0
        THEN ROUND(SUM(nt.emails_opened)::numeric / SUM(nt.emails_sent) * 100, 1)
        ELSE 0
    END AS overall_open_rate,
    COUNT(*) FILTER (WHERE nt.auto_escalation_triggered) AS escalated
FROM e55_newsletter_tracking nt
GROUP BY nt.agent_id, nt.newsletter_name, nt.newsletter_category;


-- Dashboard: Enrichment pipeline status
CREATE OR REPLACE VIEW e55_enrichment_pipeline AS
SELECT
    eq.agent_id,
    eq.pipeline_status,
    eq.prospect_origin_type,
    eq.prospect_origin_directory,
    COUNT(*) AS queue_count,
    AVG(eq.donor_propensity_score) AS avg_donor_score,
    AVG(eq.connector_score) AS avg_connector_score
FROM e55_enrichment_queue eq
GROUP BY eq.agent_id, eq.pipeline_status, eq.prospect_origin_type, eq.prospect_origin_directory;


-- Dashboard: News cycle impact
CREATE OR REPLACE VIEW e55_news_impact AS
SELECT
    nce.id,
    nce.headline,
    nce.issue_category,
    nce.impact_level,
    nce.status,
    nce.agents_activated,
    nce.newsletters_triggered,
    nce.detected_at,
    nce.related_directories,
    (SELECT COUNT(*) FROM e55_agent_activity_log al
     WHERE al.activity_type = 'news_cycle_activation'
     AND al.metadata->>'news_event' = nce.id::text) AS total_activations
FROM e55_news_cycle_events nce
ORDER BY nce.detected_at DESC;

"""


# ═══════════════════════════════════════════════════════════════
# UNIQUE CONSTRAINTS (needed for upserts)
# ═══════════════════════════════════════════════════════════════

CONSTRAINTS_SQL = """
-- Connector scores need unique constraint for upsert
CREATE UNIQUE INDEX IF NOT EXISTS idx_e55_connector_unique
ON e55_connector_scores(golden_record_id, agent_id);
"""

# ═══════════════════════════════════════════════════════════════
# SEED DATA: Enrichment Sources (waterfall of 100+ sources)
# ═══════════════════════════════════════════════════════════════

SEED_SQL = """
INSERT INTO e55_enrichment_sources (source_name, source_category, provides, waterfall_priority, avg_hit_rate, cost_per_lookup_cents) VALUES
-- TIER 1: Government / Free (priority 1-10)
('FEC Contributions', 'government', ARRAY['donation_history','employer','occupation','address'], 1, 85.0, 0),
('NC Board of Elections', 'government', ARRAY['voter_registration','party','address','vote_history','ncid'], 2, 92.0, 0),
('NC Property Records', 'property', ARRAY['property_value','address','property_type','purchase_date'], 3, 68.0, 0),
('NC Secretary of State', 'business', ARRAY['business_name','registered_agent','incorporation_date'], 4, 35.0, 0),
('NC Court Records', 'public_records', ARRAY['court_cases','judgments'], 5, 22.0, 0),
('NCBOE Campaign Finance', 'political', ARRAY['state_donations','committee_affiliations'], 6, 45.0, 0),
('County Tax Records', 'property', ARRAY['property_value','tax_assessment','acreage'], 7, 72.0, 0),
('Census/ACS Data', 'government', ARRAY['demographics','income_estimate','education_level'], 8, 95.0, 0),
('FCC License Search', 'government', ARRAY['broadcast_license','telecom_ownership'], 9, 5.0, 0),
('SEC EDGAR Filings', 'financial', ARRAY['company_officer','insider_trades','10k_filings'], 10, 8.0, 0),

-- TIER 2: Social Media / Free-Low Cost (priority 11-25)
('Facebook Public Profiles', 'social', ARRAY['facebook_url','groups','interests','location'], 11, 55.0, 0),
('LinkedIn Public', 'social', ARRAY['linkedin_url','job_title','employer','education','skills'], 12, 42.0, 0),
('Truth Social', 'social', ARRAY['truth_social_handle','posts','followers'], 13, 15.0, 0),
('X/Twitter Public', 'social', ARRAY['twitter_handle','bio','followers','political_tweets'], 14, 38.0, 0),
('Instagram Public', 'social', ARRAY['instagram_handle','followers','bio'], 15, 30.0, 0),
('YouTube Channels', 'social', ARRAY['youtube_channel','subscribers','content_type'], 16, 12.0, 0),
('Rumble Channels', 'social', ARRAY['rumble_handle','followers'], 17, 8.0, 0),
('Gab Profiles', 'social', ARRAY['gab_handle','followers'], 18, 6.0, 0),
('Telegram Public Groups', 'social', ARRAY['telegram_groups','membership'], 19, 10.0, 0),
('MeWe Groups', 'social', ARRAY['mewe_groups','membership'], 20, 7.0, 0),
('Meetup Groups', 'social', ARRAY['meetup_groups','events_attended','interests'], 21, 25.0, 0),
('Locals Communities', 'social', ARRAY['locals_memberships','subscriptions'], 22, 5.0, 0),
('Nextdoor Activity', 'social', ARRAY['neighborhood','local_activity','verified_address'], 23, 20.0, 0),
('Church/Faith Directories', 'social', ARRAY['church_membership','denomination','leadership_role'], 24, 18.0, 0),
('Volunteer Match', 'social', ARRAY['volunteer_history','causes','hours'], 25, 12.0, 0),

-- TIER 3: Commercial Data Providers (priority 26-45)
('People Data Labs (PDL)', 'commercial_data', ARRAY['email','phone','employer','job_title','linkedin_url','education'], 26, 78.0, 3),
('Proxycurl', 'commercial_data', ARRAY['linkedin_full_profile','email','phone','company_details'], 27, 72.0, 5),
('Hunter.io', 'commercial_data', ARRAY['work_email','email_verification','domain_search'], 28, 65.0, 2),
('Clearbit', 'commercial_data', ARRAY['email','company','role','seniority','tech_stack'], 29, 58.0, 5),
('ZoomInfo (via API)', 'commercial_data', ARRAY['direct_phone','email','company_revenue','employee_count'], 30, 70.0, 10),
('Apollo.io', 'commercial_data', ARRAY['email','phone','company','title','department'], 31, 62.0, 3),
('Lusha', 'commercial_data', ARRAY['phone','email','company','title'], 32, 55.0, 4),
('RocketReach', 'commercial_data', ARRAY['email','phone','social_links','employer'], 33, 60.0, 4),
('Snov.io', 'commercial_data', ARRAY['email','email_verification','tech_stack'], 34, 50.0, 2),
('Kaspr', 'commercial_data', ARRAY['phone','email','linkedin_enrichment'], 35, 48.0, 3),
('Dropcontact', 'commercial_data', ARRAY['email','phone','company','cleaning'], 36, 55.0, 2),
('Cognism', 'commercial_data', ARRAY['phone','email','intent_data','technographics'], 37, 52.0, 8),
('LeadIQ', 'commercial_data', ARRAY['email','phone','company_signals'], 38, 50.0, 5),
('Seamless.AI', 'commercial_data', ARRAY['email','phone','company','social_profiles'], 39, 58.0, 4),
('FullContact', 'commercial_data', ARRAY['email','phone','social_profiles','demographics'], 40, 62.0, 3),
('Pipl', 'commercial_data', ARRAY['email','phone','social_links','address','age'], 41, 65.0, 6),
('BeenVerified', 'commercial_data', ARRAY['phone','email','address','relatives','assets'], 42, 70.0, 5),
('Spokeo', 'commercial_data', ARRAY['phone','email','address','social_profiles'], 43, 68.0, 4),
('Whitepages Pro', 'commercial_data', ARRAY['phone','address','identity_verification'], 44, 72.0, 3),
('TowerData', 'commercial_data', ARRAY['email_append','demographics','interests'], 45, 45.0, 2),

-- TIER 4: Political/Nonprofit Specific (priority 46-60)
('DataTrust Voter File', 'political', ARRAY['voter_score','modeled_party','issue_priorities','vote_propensity'], 46, 88.0, 1),
('L2 Political', 'political', ARRAY['voter_registration','demographics','consumer_data','modeled_scores'], 47, 85.0, 2),
('TargetSmart', 'political', ARRAY['voter_file','issue_scores','donor_scores','volunteer_propensity'], 48, 82.0, 3),
('Aristotle', 'political', ARRAY['donor_history','political_giving','pac_connections'], 49, 60.0, 5),
('OpenSecrets/CRP', 'political', ARRAY['federal_donations','pac_donations','lobbying_data'], 50, 55.0, 0),
('FollowTheMoney', 'political', ARRAY['state_donations','campaign_finance'], 51, 50.0, 0),
('Ballotpedia', 'political', ARRAY['election_results','candidate_info','ballot_measures'], 52, 40.0, 0),
('VoteSmart', 'political', ARRAY['voting_records','positions','endorsements'], 53, 35.0, 0),
('NCGOP Voter Vault', 'political', ARRAY['party_score','volunteer_history','event_attendance'], 54, 75.0, 0),
('Conservative Scorecards', 'political', ARRAY['nra_rating','heritage_score','aclu_rating','planned_parenthood_rating'], 55, 30.0, 0),

-- TIER 5: Business/Professional (priority 61-75)
('Dun & Bradstreet', 'business', ARRAY['company_revenue','employee_count','sic_code','duns_number'], 61, 45.0, 8),
('Crunchbase', 'business', ARRAY['company_funding','investors','board_members'], 62, 20.0, 5),
('Bloomberg (via terminal)', 'financial', ARRAY['net_worth_estimate','investments','board_seats'], 63, 15.0, 25),
('GuideStar/Candid', 'business', ARRAY['nonprofit_financials','board_members','990_data'], 64, 35.0, 3),
('BBB Listings', 'business', ARRAY['business_owner','accreditation','complaints'], 65, 40.0, 0),
('Chamber of Commerce Dirs', 'business', ARRAY['business_membership','leadership_role'], 66, 30.0, 0),
('State Bar Directory', 'professional', ARRAY['law_license','firm','specialization'], 67, 25.0, 0),
('Medical License Board', 'professional', ARRAY['medical_license','specialty','practice'], 68, 20.0, 0),
('Real Estate License', 'professional', ARRAY['re_license','brokerage','active_listings'], 69, 28.0, 0),
('CPA License Board', 'professional', ARRAY['cpa_license','firm','specialization'], 70, 15.0, 0),

-- TIER 6: Media/Public Presence (priority 76-90)
('Google News Mentions', 'media', ARRAY['news_mentions','media_appearances','quotes'], 76, 25.0, 0),
('Local Newspaper Archives', 'media', ARRAY['local_news','letters_to_editor','op_eds'], 77, 15.0, 0),
('Podcast Appearances', 'media', ARRAY['podcast_guest','topics_discussed'], 78, 8.0, 0),
('Book Authorship', 'media', ARRAY['published_books','amazon_author_page'], 79, 5.0, 0),
('Event Speaker Lists', 'media', ARRAY['speaking_engagements','conferences','panels'], 80, 10.0, 0),

-- TIER 7: Wealth/Capacity Indicators (priority 91-100)
('Zillow/Redfin Estimates', 'property', ARRAY['home_value_estimate','property_type','neighborhood'], 91, 65.0, 0),
('Vehicle Registration', 'public_records', ARRAY['vehicle_make','vehicle_year','fleet_size'], 92, 30.0, 2),
('Boat/Aircraft Registry', 'public_records', ARRAY['boat_ownership','aircraft_ownership'], 93, 5.0, 0),
('Country Club Memberships', 'social', ARRAY['club_membership','club_name','membership_tier'], 94, 12.0, 0),
('Charitable Foundation 990s', 'financial', ARRAY['foundation_assets','annual_giving','board_role'], 95, 18.0, 0),
('Political Event Photos', 'social', ARRAY['event_attendance','photos_with_officials','vip_access'], 96, 15.0, 0),
('HOA/Community Boards', 'social', ARRAY['board_membership','community_role'], 97, 10.0, 0),
('Alumni Association', 'social', ARRAY['university','graduation_year','alumni_role','giving_level'], 98, 22.0, 0),
('Hunting/Fishing License', 'public_records', ARRAY['license_type','county','renewal_history'], 99, 35.0, 0),
('Gun Permit Records', 'public_records', ARRAY['permit_type','permit_date','county'], 100, 20.0, 0)

ON CONFLICT (source_name) DO NOTHING;
"""


# ═══════════════════════════════════════════════════════════════
# DEPLOYMENT EXECUTION
# ═══════════════════════════════════════════════════════════════

def deploy():
    print("=" * 65)
    print("E55 AUTONOMOUS INTELLIGENCE AGENT — FULL DEPLOYMENT")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 65)

    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True
    cur = conn.cursor()

    steps = [
        ("Creating 13 tables", TABLES_SQL),
        ("Creating indexes", INDEXES_SQL),
        ("Enabling RLS + policies", RLS_SQL),
        ("Deploying functions", FUNCTIONS_SQL),
        ("Creating triggers", TRIGGERS_SQL),
        ("Creating views", VIEWS_SQL),
        ("Adding constraints", CONSTRAINTS_SQL),
        ("Seeding enrichment sources (100+)", SEED_SQL),
    ]

    for step_name, sql in steps:
        print(f"\n{'─' * 50}")
        print(f"  {step_name}...")
        try:
            cur.execute(sql)
            print(f"  ✅ {step_name} — SUCCESS")
        except Exception as e:
            print(f"  ❌ {step_name} — ERROR: {e}")
            # Try to recover by rolling back and continuing
            conn.rollback()
            conn.autocommit = True

    # Verify deployment
    print(f"\n{'═' * 65}")
    print("VERIFICATION")
    print(f"{'═' * 65}")

    cur.execute("SELECT tablename FROM pg_tables WHERE tablename LIKE 'e55%' ORDER BY tablename")
    tables = [r[0] for r in cur.fetchall()]
    print(f"\n  Tables deployed: {len(tables)}")
    for t in tables:
        cur.execute(f"SELECT COUNT(*) FROM {t}")
        cnt = cur.fetchone()[0]
        print(f"    ✓ {t} ({cnt} rows)")

    cur.execute("SELECT indexname FROM pg_indexes WHERE indexname LIKE 'idx_e55%' ORDER BY indexname")
    indexes = cur.fetchall()
    print(f"\n  Indexes created: {len(indexes)}")

    cur.execute("SELECT policyname FROM pg_policies WHERE tablename LIKE 'e55%'")
    policies = cur.fetchall()
    print(f"  RLS policies: {len(policies)}")

    cur.execute("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'e55%' ORDER BY routine_name")
    funcs = [r[0] for r in cur.fetchall()]
    print(f"  Functions: {len(funcs)}")
    for f in funcs:
        print(f"    ✓ {f}()")

    cur.execute("SELECT viewname FROM pg_views WHERE viewname LIKE 'e55%' ORDER BY viewname")
    views = [r[0] for r in cur.fetchall()]
    print(f"  Views: {len(views)}")
    for v in views:
        print(f"    ✓ {v}")

    cur.execute("SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_e55%'")
    triggers = cur.fetchall()
    print(f"  Triggers: {len(triggers)}")

    # Total table count
    cur.execute("SELECT count(*) FROM pg_tables WHERE schemaname='public'")
    total = cur.fetchone()[0]
    print(f"\n  Total public tables: {total} (was 634)")

    cur.close()
    conn.close()

    print(f"\n{'═' * 65}")
    print(f"DEPLOYMENT COMPLETE — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'═' * 65}")


if __name__ == '__main__':
    deploy()
