#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 59: MICROSEGMENT INTELLIGENCE
============================================================================

Segment-specific media monitoring, issue scoring, and nurture intelligence
for donor/supporter microsegments. NOT general news — this is the engine
that powers targeted communications to specific groups of people.

PURPOSE: When a candidate activates the "Farmers" microsegment, this
ecosystem feeds them agriculture news, scores farming issues by relevance,
generates segment-specific CTAs, and triggers nurture campaigns through
E30 (Email), E31 (SMS), E19 (Social), E09 (Content AI).

The E42 News Intelligence engine scans for "Did a reporter write about
our candidate?" — CRISIS detection, candidate mentions, breaking news.

THIS ecosystem scans for "What's happening in the world that farmers/
doctors/nurses/hunters care about?" — NURTURE intelligence. You prove
you understand THEIR world, and they become YOUR supporters.

INTEGRATIONS:
- E42 News Intelligence — shared RSS/article ingestion engine
- E09 Content Creation AI — generates segment-specific copy from articles
- E20 Intelligence Brain — routes segment intelligence to candidates
- E21 Machine Learning — cost/benefit/variance scoring, topic trending
- E19 Social Media — pushes segment content to targeted social audiences
- E30 Email Campaigns — triggers segment nurture email sequences
- E31 SMS Marketing — alert pushes for high-urgency segment news
- E48 Communication DNA — tone/voice per segment

Development Value: $200,000+
Powers: Microsegment nurture campaigns, targeted donor cultivation

============================================================================
"""

import os
import json
import uuid
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, field
from enum import Enum
import re
import hashlib

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem59.microsegment_intel')


class MsIntelConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    NEWS_API_KEY = os.getenv("NEWS_API_KEY", "")

    # Scoring thresholds
    HIGH_RELEVANCE_THRESHOLD = 0.75
    TRIGGER_THRESHOLD = 0.60
    STALE_ARTICLE_DAYS = 30


# ============================================================================
# ENUMS
# ============================================================================

class SegmentTag(Enum):
    FARMERS = "farmers"
    DOCTORS = "doctors"
    NURSES = "nurses"
    HUNTERS_FISHERMEN = "hunters_fishermen"
    LAW_ENFORCEMENT = "law_enforcement"
    TEACHERS_SCHOOL_BOARD = "teachers_school_board"
    FINANCE_BANKING = "finance_banking"
    REAL_ESTATE_BUILDERS = "real_estate_builders"
    FAITH_PASTORS = "faith_pastors"
    DAIRY_SPECIALTY_AG = "dairy_specialty_ag"
    SENIORS = "seniors"
    SUBURBAN_WOMEN = "suburban_women"
    VETERANS = "veterans"
    ENERGY_UTILITIES = "energy_utilities"
    ATTORNEYS_LEGAL = "attorneys_legal"
    INSURANCE = "insurance"
    TECH_ENTREPRENEURS = "tech_entrepreneurs"
    SMALL_BUSINESS = "small_business"
    MANUFACTURERS = "manufacturers"
    TRUCKING_LOGISTICS = "trucking_logistics"
    FIREARMS_2A = "firearms_2a"
    HOMESCHOOL = "homeschool"

class SourceType(Enum):
    PROFESSIONAL_ASSOCIATION = "professional_association"
    TRADE_PUBLICATION = "trade_publication"
    GOVERNMENT = "government"
    UNIVERSITY = "university"
    SOCIAL_RSS = "social_rss"
    JOURNAL = "journal"
    ADVOCACY_ORG = "advocacy_org"
    PODCAST = "podcast"
    NEWSLETTER = "newsletter"

class ArticlePriority(Enum):
    URGENT = "urgent"        # Legislation vote THIS WEEK
    HIGH = "high"            # Major policy change, regulation
    MEDIUM = "medium"        # Industry trend, notable event
    LOW = "low"              # General interest, background
    INFO = "info"            # Reference material

class NurtureAction(Enum):
    EMAIL_BLAST = "email_blast"
    SMS_ALERT = "sms_alert"
    SOCIAL_POST = "social_post"
    NEWSLETTER_INCLUDE = "newsletter_include"
    TALKING_POINT = "talking_point"
    EVENT_TRIGGER = "event_trigger"
    FUNDRAISE_ASK = "fundraise_ask"
    PETITION_LAUNCH = "petition_launch"


# ============================================================================
# SQL SCHEMA — MICROSEGMENT INTELLIGENCE TABLES
# ============================================================================

MS_INTEL_SCHEMA = """
-- ============================================================================
-- ECOSYSTEM 59: MICROSEGMENT INTELLIGENCE
-- Segment-specific media monitoring, issue scoring, nurture triggers
-- ============================================================================

-- -----------------------------------------------------------------------
-- 1. SEGMENT MEDIA SOURCES
-- Trade publications, professional associations, government feeds
-- that matter to specific microsegments. NOT general news.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_segment_media_sources (
    source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_tag VARCHAR(50) NOT NULL,           -- 'farmers', 'doctors', 'nurses', etc.
    name VARCHAR(255) NOT NULL,
    url VARCHAR(500),
    feed_url VARCHAR(500),                      -- RSS/Atom feed URL if available
    source_type VARCHAR(50),                    -- professional_association, trade_publication, government, etc.
    credibility_score DECIMAL(3,2) DEFAULT 0.70,
    bias_rating VARCHAR(20),                    -- conservative, neutral, liberal, unknown
    reach_estimate INTEGER,                     -- est. audience size
    check_frequency_minutes INTEGER DEFAULT 60, -- how often to poll
    is_active BOOLEAN DEFAULT true,
    last_checked TIMESTAMP,
    last_article_found TIMESTAMP,
    articles_ingested INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(segment_tag, url)
);

CREATE INDEX IF NOT EXISTS idx_ms_media_segment ON ms_segment_media_sources(segment_tag);
CREATE INDEX IF NOT EXISTS idx_ms_media_active ON ms_segment_media_sources(is_active);
CREATE INDEX IF NOT EXISTS idx_ms_media_type ON ms_segment_media_sources(source_type);

-- -----------------------------------------------------------------------
-- 2. SEGMENT ARTICLES
-- Articles ingested from segment media sources.
-- Separate from E42 news_articles — different purpose, different scoring.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_segment_articles (
    article_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES ms_segment_media_sources(source_id),
    segment_tag VARCHAR(50) NOT NULL,
    url VARCHAR(1000) NOT NULL,
    url_hash VARCHAR(64) UNIQUE,                -- SHA256 for dedup
    title VARCHAR(1000) NOT NULL,
    description TEXT,
    content TEXT,
    author VARCHAR(255),
    published_at TIMESTAMP,
    discovered_at TIMESTAMP DEFAULT NOW(),
    priority VARCHAR(20) DEFAULT 'medium',      -- urgent/high/medium/low/info
    relevance_score DECIMAL(4,3) DEFAULT 0.500, -- 0.000-1.000
    sentiment VARCHAR(20),                      -- positive/negative/neutral/mixed
    sentiment_score DECIMAL(4,3),
    is_actionable BOOLEAN DEFAULT false,        -- triggers nurture action?
    action_taken BOOLEAN DEFAULT false,
    action_type VARCHAR(50),                    -- email_blast, sms_alert, social_post, etc.
    action_taken_at TIMESTAMP,
    word_count INTEGER,
    tags JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ms_articles_segment ON ms_segment_articles(segment_tag);
CREATE INDEX IF NOT EXISTS idx_ms_articles_source ON ms_segment_articles(source_id);
CREATE INDEX IF NOT EXISTS idx_ms_articles_published ON ms_segment_articles(published_at);
CREATE INDEX IF NOT EXISTS idx_ms_articles_priority ON ms_segment_articles(priority);
CREATE INDEX IF NOT EXISTS idx_ms_articles_actionable ON ms_segment_articles(is_actionable);
CREATE INDEX IF NOT EXISTS idx_ms_articles_url_hash ON ms_segment_articles(url_hash);

-- -----------------------------------------------------------------------
-- 3. SEGMENT TOPICS — The issues each microsegment cares about
-- Top 10-20 issues per segment, scored by importance.
-- These drive content matching and relevance scoring.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_segment_topics (
    topic_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_tag VARCHAR(50) NOT NULL,
    topic_name VARCHAR(255) NOT NULL,           -- 'crop insurance', 'water rights', 'farm labor'
    topic_category VARCHAR(100),                -- 'regulation', 'economics', 'legislation', 'policy'
    importance_score DECIMAL(4,2) DEFAULT 50.00, -- 1-100 static importance to this segment
    trending_score DECIMAL(4,2) DEFAULT 0.00,   -- 0-100 dynamic trending (ML-updated)
    composite_score DECIMAL(4,2) DEFAULT 50.00, -- (importance * 0.6) + (trending * 0.4)
    keywords JSONB DEFAULT '[]',                -- search keywords for article matching
    subtopics JSONB DEFAULT '[]',               -- nested issue breakdown
    is_active BOOLEAN DEFAULT true,
    articles_matched INTEGER DEFAULT 0,
    last_article_match TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(segment_tag, topic_name)
);

CREATE INDEX IF NOT EXISTS idx_ms_topics_segment ON ms_segment_topics(segment_tag);
CREATE INDEX IF NOT EXISTS idx_ms_topics_composite ON ms_segment_topics(composite_score DESC);
CREATE INDEX IF NOT EXISTS idx_ms_topics_trending ON ms_segment_topics(trending_score DESC);

-- -----------------------------------------------------------------------
-- 4. ARTICLE-TOPIC MATCHES
-- Links articles to the topics they cover, with relevance scoring.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_article_topic_matches (
    match_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID REFERENCES ms_segment_articles(article_id),
    topic_id UUID REFERENCES ms_segment_topics(topic_id),
    match_score DECIMAL(4,3) DEFAULT 0.500,     -- how well article matches topic
    match_method VARCHAR(50),                   -- 'keyword', 'ml_classifier', 'manual'
    context_snippet TEXT,                        -- relevant excerpt
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ms_atm_article ON ms_article_topic_matches(article_id);
CREATE INDEX IF NOT EXISTS idx_ms_atm_topic ON ms_article_topic_matches(topic_id);

-- -----------------------------------------------------------------------
-- 5. SEGMENT CTAs — Calls to Action per segment
-- Pre-built CTAs that get attached to outbound content.
-- "Share with your county Farm Bureau group"
-- "Alert: school board vote THIS WEEK — show up"
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_segment_ctas (
    cta_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_tag VARCHAR(50) NOT NULL,
    cta_text TEXT NOT NULL,                     -- the actual call to action
    cta_type VARCHAR(50),                       -- 'share', 'forward', 'alert', 'sign', 'attend', 'donate'
    priority_level VARCHAR(20) DEFAULT 'medium',
    topic_id UUID REFERENCES ms_segment_topics(topic_id), -- optional topic link
    use_count INTEGER DEFAULT 0,
    last_used TIMESTAMP,
    conversion_rate DECIMAL(5,4) DEFAULT 0.0000, -- ML-tracked effectiveness
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ms_ctas_segment ON ms_segment_ctas(segment_tag);
CREATE INDEX IF NOT EXISTS idx_ms_ctas_type ON ms_segment_ctas(cta_type);

-- -----------------------------------------------------------------------
-- 6. SEGMENT NURTURE TRIGGERS
-- When an article + topic + score crosses a threshold, fire a nurture
-- action through E30 (email), E31 (SMS), E19 (social), E09 (content).
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_nurture_triggers (
    trigger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_tag VARCHAR(50) NOT NULL,
    trigger_name VARCHAR(255) NOT NULL,
    trigger_condition JSONB NOT NULL,           -- {"topic_id": "...", "min_score": 0.75, "priority": "urgent"}
    action_type VARCHAR(50) NOT NULL,           -- email_blast, sms_alert, social_post, etc.
    action_config JSONB DEFAULT '{}',           -- ecosystem-specific config (email template, SMS template, etc.)
    target_ecosystem VARCHAR(10),               -- 'E30', 'E31', 'E19', 'E09'
    cooldown_hours INTEGER DEFAULT 24,          -- don't re-fire for same topic within N hours
    last_fired TIMESTAMP,
    fire_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ms_triggers_segment ON ms_nurture_triggers(segment_tag);
CREATE INDEX IF NOT EXISTS idx_ms_triggers_action ON ms_nurture_triggers(action_type);

-- -----------------------------------------------------------------------
-- 7. SEGMENT PERFORMANCE — ML cost/benefit/variance tracking
-- Tracks effectiveness of segment nurture campaigns over time.
-- Fed by E21 Machine Learning for optimization.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_segment_performance (
    perf_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_tag VARCHAR(50) NOT NULL,
    candidate_id VARCHAR(50),                   -- which candidate's segment activation
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    -- Content metrics
    articles_ingested INTEGER DEFAULT 0,
    articles_actioned INTEGER DEFAULT 0,
    content_pieces_generated INTEGER DEFAULT 0,
    -- Outreach metrics
    emails_sent INTEGER DEFAULT 0,
    email_open_rate DECIMAL(5,4),
    email_click_rate DECIMAL(5,4),
    sms_sent INTEGER DEFAULT 0,
    sms_response_rate DECIMAL(5,4),
    social_posts INTEGER DEFAULT 0,
    social_engagement_rate DECIMAL(5,4),
    -- Outcome metrics
    donations_attributed DECIMAL(12,2) DEFAULT 0.00,
    donors_acquired INTEGER DEFAULT 0,
    donors_retained INTEGER DEFAULT 0,
    volunteers_recruited INTEGER DEFAULT 0,
    event_attendees INTEGER DEFAULT 0,
    -- Cost/benefit
    cost_total DECIMAL(10,2) DEFAULT 0.00,
    revenue_total DECIMAL(12,2) DEFAULT 0.00,
    roi_ratio DECIMAL(8,4),                    -- revenue / cost
    -- ML variance
    predicted_revenue DECIMAL(12,2),
    actual_revenue DECIMAL(12,2),
    variance_pct DECIMAL(6,3),                  -- (actual - predicted) / predicted * 100
    ml_confidence DECIMAL(4,3),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ms_perf_segment ON ms_segment_performance(segment_tag);
CREATE INDEX IF NOT EXISTS idx_ms_perf_candidate ON ms_segment_performance(candidate_id);
CREATE INDEX IF NOT EXISTS idx_ms_perf_period ON ms_segment_performance(period_start, period_end);

-- -----------------------------------------------------------------------
-- 8. SEGMENT SOCIAL MEDIA TARGETS
-- Social accounts, hashtags, groups per segment for E19 integration.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_segment_social_targets (
    target_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_tag VARCHAR(50) NOT NULL,
    platform VARCHAR(30) NOT NULL,              -- 'twitter', 'facebook', 'instagram', 'nextdoor'
    target_type VARCHAR(30),                    -- 'account', 'hashtag', 'group', 'page'
    target_handle VARCHAR(255) NOT NULL,        -- @NCFarmBureau, #NCFarming, group URL
    follower_count INTEGER,
    engagement_rate DECIMAL(5,4),
    is_monitor_only BOOLEAN DEFAULT true,       -- true = read only, false = post to
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(segment_tag, platform, target_handle)
);

CREATE INDEX IF NOT EXISTS idx_ms_social_segment ON ms_segment_social_targets(segment_tag);
CREATE INDEX IF NOT EXISTS idx_ms_social_platform ON ms_segment_social_targets(platform);

-- -----------------------------------------------------------------------
-- 9. CANDIDATE SEGMENT ACTIVATION
-- Which candidates have activated which segments.
-- Links to E09 Campaign Control Panel.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ms_candidate_segment_activation (
    activation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id VARCHAR(50) NOT NULL,
    segment_tag VARCHAR(50) NOT NULL,
    intensity INTEGER DEFAULT 5 CHECK (intensity BETWEEN 1 AND 10), -- 1=passive, 10=aggressive
    is_active BOOLEAN DEFAULT true,
    activated_at TIMESTAMP DEFAULT NOW(),
    deactivated_at TIMESTAMP,
    activated_by VARCHAR(50),                   -- 'candidate', 'manager', 'ai'
    override_topics JSONB DEFAULT '[]',         -- topic overrides for this candidate
    override_ctas JSONB DEFAULT '[]',           -- CTA overrides
    notes TEXT,
    UNIQUE(candidate_id, segment_tag)
);

CREATE INDEX IF NOT EXISTS idx_ms_activation_candidate ON ms_candidate_segment_activation(candidate_id);
CREATE INDEX IF NOT EXISTS idx_ms_activation_segment ON ms_candidate_segment_activation(segment_tag);
CREATE INDEX IF NOT EXISTS idx_ms_activation_active ON ms_candidate_segment_activation(is_active);

-- -----------------------------------------------------------------------
-- VIEWS
-- -----------------------------------------------------------------------

-- Active segment dashboard — what each candidate sees
CREATE OR REPLACE VIEW v_ms_candidate_dashboard AS
SELECT
    csa.candidate_id,
    csa.segment_tag,
    csa.intensity,
    (SELECT COUNT(*) FROM ms_segment_articles sa
     WHERE sa.segment_tag = csa.segment_tag
     AND sa.discovered_at > NOW() - INTERVAL '7 days') as articles_this_week,
    (SELECT COUNT(*) FROM ms_segment_articles sa
     WHERE sa.segment_tag = csa.segment_tag
     AND sa.is_actionable = true
     AND sa.action_taken = false) as pending_actions,
    (SELECT json_agg(json_build_object('topic', t.topic_name, 'score', t.composite_score))
     FROM ms_segment_topics t
     WHERE t.segment_tag = csa.segment_tag AND t.is_active = true
     ORDER BY t.composite_score DESC
     LIMIT 5) as top_5_topics
FROM ms_candidate_segment_activation csa
WHERE csa.is_active = true;

-- Trending topics across all segments
CREATE OR REPLACE VIEW v_ms_trending_topics AS
SELECT
    t.segment_tag,
    t.topic_name,
    t.importance_score,
    t.trending_score,
    t.composite_score,
    t.articles_matched,
    t.last_article_match
FROM ms_segment_topics t
WHERE t.is_active = true
ORDER BY t.trending_score DESC;

-- Source performance — which sources are producing actionable content
CREATE OR REPLACE VIEW v_ms_source_performance AS
SELECT
    s.segment_tag,
    s.name,
    s.source_type,
    s.credibility_score,
    s.articles_ingested,
    s.last_article_found,
    (SELECT COUNT(*) FROM ms_segment_articles a
     WHERE a.source_id = s.source_id AND a.is_actionable = true) as actionable_articles,
    CASE WHEN s.articles_ingested > 0
         THEN ROUND((SELECT COUNT(*)::numeric FROM ms_segment_articles a
                      WHERE a.source_id = s.source_id AND a.is_actionable = true)
                     / s.articles_ingested, 3)
         ELSE 0 END as actionable_rate
FROM ms_segment_media_sources s
WHERE s.is_active = true
ORDER BY s.segment_tag, actionable_articles DESC;

-- Segment ROI leaderboard
CREATE OR REPLACE VIEW v_ms_segment_roi AS
SELECT
    segment_tag,
    SUM(donations_attributed) as total_donations,
    SUM(donors_acquired) as total_donors_acquired,
    SUM(cost_total) as total_cost,
    SUM(revenue_total) as total_revenue,
    CASE WHEN SUM(cost_total) > 0
         THEN ROUND(SUM(revenue_total) / SUM(cost_total), 2)
         ELSE 0 END as roi_ratio,
    AVG(variance_pct) as avg_variance_pct
FROM ms_segment_performance
GROUP BY segment_tag
ORDER BY total_donations DESC;
"""


# ============================================================================
# SEED DATA — ALL 12 MICROSEGMENT MEDIA SOURCES
# From docs/MICROSEGMENT_INFLUENCER_MAP.md (March 31, 2026)
# ============================================================================

SEGMENT_MEDIA_SOURCES = {
    "farmers": [
        ("NC Farm Bureau — Social + RSS", "https://www.ncfb.org", "https://www.ncfb.org/feed/", "social_rss", 0.90),
        ("NC Dept of Agriculture", "https://www.ncagr.gov", "https://www.ncagr.gov/feed/", "government", 0.95),
        ("Southeast Farm Press", "https://www.farmprogress.com/southeast-farm-press", None, "trade_publication", 0.85),
        ("Farm Journal", "https://www.agweb.com/farm-journal", None, "trade_publication", 0.85),
        ("USDA NASS NC Crop Reports", "https://www.nass.usda.gov/Statistics_by_State/North_Carolina/", None, "government", 0.95),
        ("NC State Extension Newsletters", "https://content.ces.ncsu.edu", None, "university", 0.90),
        ("AgWeb.com", "https://www.agweb.com", "https://www.agweb.com/rss/news", "trade_publication", 0.80),
    ],
    "doctors": [
        ("NC Medical Society — Newsletter + Social", "https://www.ncmedsoc.org", None, "professional_association", 0.90),
        ("NC Medical Journal", "https://www.ncmedicaljournal.com", None, "journal", 0.92),
        ("Modern Healthcare Southeast", "https://www.modernhealthcare.com", None, "trade_publication", 0.85),
        ("Becker's Hospital Review", "https://www.beckershospitalreview.com", "https://www.beckershospitalreview.com/rss/", "trade_publication", 0.85),
        ("AMA Wire", "https://www.ama-assn.org/news", None, "professional_association", 0.88),
        ("Healthcare Dive", "https://www.healthcaredive.com", "https://www.healthcaredive.com/feeds/news/", "trade_publication", 0.83),
        ("NCGA Health Committee News", "https://www.ncleg.gov", None, "government", 0.95),
    ],
    "nurses": [
        ("NC Nurses Association Newsletter", "https://www.ncnurses.org", None, "professional_association", 0.90),
        ("NursingCenter.com", "https://www.nursingcenter.com", None, "trade_publication", 0.83),
        ("Nurse.com Southeast", "https://www.nurse.com", None, "trade_publication", 0.82),
        ("NC Board of Nursing Updates", "https://www.ncbon.com", None, "government", 0.95),
        ("NCNA Nurse Practitioner News", "https://www.ncnurses.org/np", None, "professional_association", 0.88),
        ("Healthcare Dive — Nursing", "https://www.healthcaredive.com", "https://www.healthcaredive.com/feeds/news/", "trade_publication", 0.83),
        ("NCGA Health Committee News", "https://www.ncleg.gov", None, "government", 0.95),
    ],
    "hunters_fishermen": [
        ("NC Wildlife Resources Commission", "https://www.ncwildlife.org", None, "government", 0.95),
        ("Ducks Unlimited NC Chapter", "https://www.ducks.org/north-carolina", None, "advocacy_org", 0.85),
        ("Outdoor Life Southeast", "https://www.outdoorlife.com", None, "trade_publication", 0.80),
        ("Field & Stream", "https://www.fieldandstream.com", None, "trade_publication", 0.80),
        ("Sportsmen's Alliance Alerts", "https://www.sportsmensalliance.org", None, "advocacy_org", 0.85),
        ("NRA-ILA Alerts", "https://www.nraila.org", "https://www.nraila.org/rss/", "advocacy_org", 0.82),
        ("BassFan.com Tournament News", "https://www.bassfan.com", None, "trade_publication", 0.78),
        ("CCA NC — Coastal Conservation", "https://www.joincca.org/north-carolina", None, "advocacy_org", 0.83),
    ],
    "law_enforcement": [
        ("NC Sheriffs' Association Newsletter", "https://www.ncsheriffs.org", None, "professional_association", 0.92),
        ("NC Justice Academy News", "https://www.ncdoj.gov/ncja/", None, "government", 0.90),
        ("PoliceOne.com", "https://www.policeone.com", None, "trade_publication", 0.82),
        ("Law Enforcement Today", "https://www.lawenforcementtoday.com", None, "trade_publication", 0.78),
        ("FBI Crime Statistics Releases", "https://www.fbi.gov/how-we-can-help-you/more-fbi-services-and-information/ucr", None, "government", 0.95),
        ("NCGA Judiciary Committee News", "https://www.ncleg.gov", None, "government", 0.95),
        ("NC Police Benevolent Association", "https://www.ncpba.org", None, "professional_association", 0.88),
    ],
    "teachers_school_board": [
        ("Moms for Liberty NC — Social", "https://www.momsforliberty.org", None, "advocacy_org", 0.82),
        ("Parents Defending Education Alerts", "https://www.defendinged.org", None, "advocacy_org", 0.80),
        ("NC Charter School Alliance Newsletter", "https://www.nccharterschools.org", None, "professional_association", 0.85),
        ("Education Week", "https://www.edweek.org", None, "trade_publication", 0.88),
        ("NCGA Education Committee News", "https://www.ncleg.gov", None, "government", 0.95),
        ("Local School Board Meeting Agendas", "https://www.ncsba.org", None, "government", 0.90),
        ("NCAE Social — Monitor Opposition", "https://www.ncae.org", None, "professional_association", 0.75),
    ],
    "finance_banking": [
        ("NC Bankers Association Newsletter", "https://www.ncbankers.org", None, "professional_association", 0.90),
        ("American Banker Southeast", "https://www.americanbanker.com", None, "trade_publication", 0.85),
        ("Charlotte Business Journal — Finance", "https://www.bizjournals.com/charlotte", None, "trade_publication", 0.83),
        ("Triangle Business Journal — Finance", "https://www.bizjournals.com/triangle", None, "trade_publication", 0.83),
        ("NC Association of CPAs Updates", "https://www.ncacpa.org", None, "professional_association", 0.88),
        ("FDIC/OCC Regulatory News", "https://www.fdic.gov", None, "government", 0.95),
    ],
    "real_estate_builders": [
        ("NC Association of Realtors News", "https://www.ncrealtors.org", None, "professional_association", 0.90),
        ("NC Home Builders Association Newsletter", "https://www.nchba.org", None, "professional_association", 0.88),
        ("CoStar NC Market Reports", "https://www.costar.com", None, "trade_publication", 0.85),
        ("Charlotte Business Journal — Real Estate", "https://www.bizjournals.com/charlotte", None, "trade_publication", 0.83),
        ("NAHB Policy News", "https://www.nahb.org", None, "professional_association", 0.85),
        ("Zoning/Planning Board Agendas", "https://www.ncleg.gov", None, "government", 0.90),
    ],
    "faith_pastors": [
        ("NC Values Coalition Alerts", "https://www.ncvalues.org", None, "advocacy_org", 0.85),
        ("NC Baptist State Convention News", "https://ncbaptist.org", None, "professional_association", 0.88),
        ("Christian Post Southeast", "https://www.christianpost.com", None, "trade_publication", 0.80),
        ("Christianity Today", "https://www.christianitytoday.com", None, "trade_publication", 0.82),
        ("NCGA Religious Liberty Filtered News", "https://www.ncleg.gov", None, "government", 0.95),
        ("Faith & Freedom Coalition NC", "https://www.ffcoalition.com", None, "advocacy_org", 0.83),
        ("Christian Radio NC — WCCM, WMIT, WBAJ", None, None, "newsletter", 0.78),
    ],
    "dairy_specialty_ag": [
        ("NC Dairy Producers Association", "https://www.ncdairy.org", None, "professional_association", 0.88),
        ("Dairy Herd Management", "https://www.dairyherd.com", None, "trade_publication", 0.83),
        ("Hoard's Dairyman", "https://hoards.com", None, "trade_publication", 0.85),
        ("USDA NASS Dairy Reports", "https://www.nass.usda.gov", None, "government", 0.95),
        ("Farm Credit News", "https://www.farmcredit.com", None, "trade_publication", 0.83),
        ("NC State Animal Science", "https://cals.ncsu.edu/animal-science/", None, "university", 0.88),
    ],
    "seniors": [
        ("AARP NC — Monitor", "https://states.aarp.org/north-carolina", None, "advocacy_org", 0.75),
        ("Medicare.gov News", "https://www.medicare.gov", None, "government", 0.95),
        ("Social Security Administration Announcements", "https://www.ssa.gov", None, "government", 0.95),
        ("Senior Living Magazine", "https://www.seniorlivingmag.com", None, "trade_publication", 0.78),
        ("McKnight's Senior Living", "https://www.mcknightsseniorliving.com", None, "trade_publication", 0.82),
    ],
    "suburban_women": [
        ("Moms for Liberty NC — Social", "https://www.momsforliberty.org", None, "advocacy_org", 0.82),
        ("Local School Board Meeting Agendas", "https://www.ncsba.org", None, "government", 0.90),
        ("NextDoor Public Posts — Suburban Towns", "https://www.nextdoor.com", None, "social_rss", 0.75),
        ("Local PTA Newsletters", None, None, "newsletter", 0.78),
        ("Suburban Neighborhood Facebook Groups", "https://www.facebook.com", None, "social_rss", 0.72),
    ],
}


# ============================================================================
# SEED DATA — SEGMENT TOPICS (Top 10-20 issues per segment)
# ============================================================================

SEGMENT_TOPICS = {
    "farmers": [
        ("Crop Insurance & Farm Bill", "legislation", 95, ["crop insurance", "farm bill", "USDA", "commodity support"]),
        ("Water Rights & Irrigation", "regulation", 88, ["water rights", "irrigation", "water quality", "WOTUS"]),
        ("Farm Labor & Immigration", "policy", 85, ["H-2A visa", "farm labor", "ag workers", "migrant"]),
        ("Property Tax — Agricultural Use", "taxation", 90, ["property tax", "present use value", "ag exemption", "farmland"]),
        ("Ethanol & Biofuels Mandates", "regulation", 72, ["ethanol", "biofuel", "RFS", "renewable fuel"]),
        ("Solar Farms on Farmland", "policy", 80, ["solar farm", "farmland conversion", "solar lease", "ag preservation"]),
        ("NCDA Regulations & Inspections", "regulation", 78, ["inspection", "NCDA", "food safety", "animal welfare"]),
        ("Commodity Prices & Markets", "economics", 92, ["commodity price", "corn price", "soybean", "tobacco", "market"]),
        ("Rural Broadband", "infrastructure", 70, ["rural broadband", "internet access", "connectivity"]),
        ("Estate Tax & Farm Succession", "taxation", 85, ["estate tax", "death tax", "farm succession", "step-up basis"]),
        ("Drought & Disaster Relief", "policy", 82, ["drought", "disaster relief", "crop loss", "USDA assistance"]),
        ("Environmental Regulations", "regulation", 88, ["EPA", "environmental", "wetlands", "nutrient management"]),
    ],
    "doctors": [
        ("Medicaid Expansion & Reimbursement", "policy", 95, ["medicaid", "reimbursement", "expansion", "provider rates"]),
        ("Scope of Practice — NP/PA", "regulation", 90, ["scope of practice", "nurse practitioner", "physician assistant", "supervision"]),
        ("Medical Malpractice Reform", "legislation", 88, ["malpractice", "tort reform", "liability cap", "medical negligence"]),
        ("Certificate of Need (CON)", "regulation", 85, ["certificate of need", "CON", "hospital expansion", "facility"]),
        ("Physician Burnout & Workforce", "policy", 78, ["physician burnout", "doctor shortage", "workforce", "residency"]),
        ("Telehealth Regulations", "regulation", 82, ["telehealth", "telemedicine", "virtual care", "remote patient"]),
        ("Prior Authorization Reform", "regulation", 92, ["prior authorization", "prior auth", "insurance denial", "utilization review"]),
        ("Prescription Drug Pricing", "legislation", 80, ["drug pricing", "PBM", "pharmacy benefit", "prescription cost"]),
        ("Healthcare Consolidation", "economics", 75, ["hospital merger", "acquisition", "consolidation", "antitrust"]),
        ("Mental Health Parity", "legislation", 72, ["mental health", "parity", "behavioral health", "substance abuse"]),
    ],
    "nurses": [
        ("Nurse Staffing Ratios", "legislation", 95, ["staffing ratio", "nurse patient ratio", "safe staffing"]),
        ("Scope of Practice Expansion", "regulation", 92, ["scope of practice", "full practice authority", "NP independence"]),
        ("Nursing Shortage & Recruitment", "policy", 88, ["nursing shortage", "nurse recruitment", "nursing school"]),
        ("Workplace Violence Protection", "legislation", 85, ["workplace violence", "nurse assault", "hospital security"]),
        ("Mandatory Overtime Restrictions", "regulation", 82, ["mandatory overtime", "forced overtime", "nurse fatigue"]),
        ("Nursing License Compact", "regulation", 80, ["nurse license compact", "NLC", "multistate license"]),
        ("Travel Nurse Regulations", "regulation", 78, ["travel nurse", "agency nurse", "temporary staffing"]),
        ("Mental Health for Healthcare Workers", "policy", 75, ["burnout", "mental health", "healthcare worker wellness"]),
    ],
    "hunters_fishermen": [
        ("Second Amendment — Federal & State", "legislation", 98, ["2A", "second amendment", "gun rights", "firearms"]),
        ("NC Wildlife Regulations", "regulation", 92, ["hunting season", "bag limit", "NCWRC", "wildlife regulation"]),
        ("Public Land Access", "policy", 88, ["public land", "game lands", "access", "BLM"]),
        ("Concealed Carry & Permitless Carry", "legislation", 90, ["concealed carry", "permitless carry", "constitutional carry"]),
        ("Fishing Regulations & Licenses", "regulation", 85, ["fishing license", "creel limit", "fishing regulation"]),
        ("Endangered Species Impact on Hunting", "regulation", 80, ["endangered species", "ESA", "habitat", "hunting restriction"]),
        ("Boat & Marina Regulations", "regulation", 72, ["boating", "marina", "waterway", "boat registration"]),
        ("Conservation Funding", "policy", 78, ["Pittman-Robertson", "conservation fund", "wildlife funding"]),
        ("Sunday Hunting", "legislation", 75, ["Sunday hunting", "Sunday restriction"]),
        ("CWD & Wildlife Disease", "policy", 82, ["chronic wasting", "CWD", "wildlife disease", "deer"]),
    ],
    "law_enforcement": [
        ("Qualified Immunity", "legislation", 95, ["qualified immunity", "police liability", "officer protection"]),
        ("Bail Reform & Pretrial Release", "legislation", 92, ["bail reform", "pretrial release", "cash bail"]),
        ("Police Funding & Equipment", "policy", 90, ["defund police", "police funding", "equipment", "budget"]),
        ("Fentanyl & Drug Trafficking", "policy", 95, ["fentanyl", "drug trafficking", "opioid", "cartel"]),
        ("Body Camera & Use of Force Policy", "regulation", 82, ["body camera", "use of force", "bodycam"]),
        ("Officer Recruitment & Retention", "policy", 88, ["officer recruitment", "retention", "police academy", "staffing"]),
        ("Gang Task Forces", "policy", 78, ["gang", "task force", "organized crime"]),
        ("DA Election & Prosecution Policy", "policy", 85, ["district attorney", "prosecution", "plea bargain", "soft on crime"]),
        ("Immigration Enforcement — 287(g)", "legislation", 80, ["287g", "ICE", "immigration enforcement", "sanctuary"]),
        ("Juvenile Justice Reform", "legislation", 75, ["juvenile justice", "raise the age", "youth offender"]),
    ],
    "teachers_school_board": [
        ("School Choice & Vouchers", "legislation", 95, ["school choice", "voucher", "opportunity scholarship", "ESA"]),
        ("Parental Rights in Education", "legislation", 92, ["parental rights", "parents bill of rights", "curriculum transparency"]),
        ("Critical Race Theory / DEI", "policy", 88, ["CRT", "critical race", "DEI", "diversity equity"]),
        ("Teacher Pay & Benefits", "policy", 85, ["teacher pay", "teacher salary", "benefit", "retirement"]),
        ("Charter School Expansion", "legislation", 82, ["charter school", "charter cap", "charter expansion"]),
        ("Gender Policy in Schools", "policy", 90, ["gender policy", "transgender", "bathroom", "pronoun"]),
        ("Book Challenges & Library Policy", "policy", 78, ["book challenge", "library", "inappropriate material"]),
        ("Homeschool Regulations", "regulation", 80, ["homeschool", "home education", "DNPE"]),
        ("School Safety & SROs", "policy", 85, ["school safety", "SRO", "school resource officer", "school shooting"]),
        ("Sex Ed & Health Curriculum", "policy", 75, ["sex education", "health curriculum", "abstinence"]),
    ],
    "finance_banking": [
        ("Dodd-Frank & Banking Regulation", "regulation", 92, ["Dodd-Frank", "banking regulation", "financial regulation"]),
        ("Interest Rate Policy", "economics", 90, ["interest rate", "Fed rate", "monetary policy"]),
        ("Community Bank Regulations", "regulation", 88, ["community bank", "small bank", "regulatory burden"]),
        ("Tax Policy — Corporate & Capital Gains", "taxation", 95, ["corporate tax", "capital gains", "tax rate"]),
        ("Fintech Regulation", "regulation", 78, ["fintech", "cryptocurrency", "digital banking"]),
        ("SBA Lending Programs", "policy", 80, ["SBA", "small business loan", "PPP"]),
        ("Anti-Money Laundering / BSA", "regulation", 75, ["AML", "BSA", "bank secrecy", "compliance"]),
        ("ESG & Investment Mandates", "regulation", 85, ["ESG", "environmental social governance", "fiduciary"]),
    ],
    "real_estate_builders": [
        ("Zoning & Land Use Regulations", "regulation", 95, ["zoning", "land use", "rezoning", "planning"]),
        ("Building Code Changes", "regulation", 90, ["building code", "IRC", "energy code"]),
        ("Impact Fees & Developer Charges", "taxation", 88, ["impact fee", "developer fee", "infrastructure charge"]),
        ("Affordable Housing Mandates", "policy", 82, ["affordable housing", "inclusionary zoning", "workforce housing"]),
        ("Lumber & Material Costs", "economics", 85, ["lumber price", "material cost", "supply chain"]),
        ("Property Tax Assessments", "taxation", 90, ["property tax", "assessment", "revaluation"]),
        ("Wetlands & Environmental Permits", "regulation", 80, ["wetland permit", "environmental review", "404 permit"]),
        ("Real Estate Transfer Tax", "taxation", 78, ["transfer tax", "excise tax", "deed stamp"]),
    ],
    "faith_pastors": [
        ("Religious Liberty Legislation", "legislation", 98, ["religious liberty", "religious freedom", "RFRA", "conscience"]),
        ("Abortion — Pro-Life Policy", "legislation", 95, ["abortion", "pro-life", "heartbeat", "Dobbs"]),
        ("School Prayer & Religious Expression", "legislation", 85, ["school prayer", "religious expression", "First Amendment"]),
        ("Church Tax Exemption", "taxation", 88, ["tax exempt", "501c3", "Johnson Amendment", "church tax"]),
        ("Marriage & Family Policy", "policy", 82, ["marriage", "family", "parental rights"]),
        ("Israel Policy & Support", "policy", 80, ["Israel", "Jerusalem", "foreign aid", "antisemitism"]),
        ("Human Trafficking", "policy", 78, ["human trafficking", "sex trafficking", "modern slavery"]),
        ("Gambling Expansion Opposition", "legislation", 75, ["gambling", "casino", "sports betting", "lottery"]),
    ],
    "dairy_specialty_ag": [
        ("Milk Pricing & Federal Orders", "regulation", 95, ["milk price", "federal milk marketing order", "FMMO"]),
        ("USDA Dairy Support Programs", "policy", 90, ["dairy margin", "DMC", "dairy support"]),
        ("Animal Welfare Regulations", "regulation", 85, ["animal welfare", "USDA inspection", "confinement"]),
        ("Feed Costs & Crop Prices", "economics", 88, ["feed cost", "corn price", "hay price"]),
        ("Environmental Compliance — CAFO", "regulation", 82, ["CAFO", "concentrated animal", "manure management"]),
        ("Dairy Trade — Imports/Exports", "economics", 78, ["dairy import", "dairy export", "trade agreement"]),
    ],
    "seniors": [
        ("Social Security Reform", "legislation", 98, ["social security", "retirement age", "COLA", "benefits"]),
        ("Medicare Changes", "legislation", 95, ["medicare", "part D", "advantage plan", "premium"]),
        ("Prescription Drug Costs", "policy", 92, ["drug cost", "prescription price", "drug pricing"]),
        ("Property Tax Relief for Seniors", "taxation", 88, ["senior tax relief", "homestead exemption", "property tax freeze"]),
        ("Elder Abuse & Fraud Protection", "policy", 82, ["elder abuse", "senior fraud", "scam"]),
        ("Long-Term Care & Nursing Homes", "policy", 85, ["long-term care", "nursing home", "assisted living"]),
        ("Veterans Benefits", "policy", 80, ["veteran benefit", "VA", "military retirement"]),
        ("Caregiver Support", "policy", 75, ["caregiver", "family caregiver", "respite"]),
    ],
    "suburban_women": [
        ("School Safety", "policy", 95, ["school safety", "school shooting", "SRO", "security"]),
        ("Parental Rights in Education", "legislation", 92, ["parental rights", "curriculum", "transparency"]),
        ("Child Care Costs & Availability", "policy", 88, ["child care", "daycare", "childcare cost"]),
        ("Property Taxes & Local Spending", "taxation", 85, ["property tax", "school budget", "local spending"]),
        ("Neighborhood Safety & Crime", "policy", 90, ["crime", "break-in", "theft", "neighborhood safety"]),
        ("Gender Policy in Schools", "policy", 88, ["gender policy", "transgender", "girls sports"]),
        ("Grocery & Gas Prices", "economics", 82, ["grocery price", "gas price", "inflation", "cost of living"]),
        ("Healthcare Access & Costs", "policy", 80, ["healthcare cost", "insurance premium", "pediatric"]),
    ],
}


# ============================================================================
# SEED DATA — SEGMENT CTAs
# ============================================================================

SEGMENT_CTAS = {
    "farmers": [
        ("Share with your county Farm Bureau group", "share"),
        ("Forward to your commodity committee", "forward"),
        ("Invite to farm field day event", "attend"),
        ("Alert: legislation affects YOUR farm — call your rep", "alert"),
        ("Sign: petition to protect ag property tax exemptions", "sign"),
    ],
    "doctors": [
        ("Forward to your practice partners", "forward"),
        ("Share with your department at grand rounds", "share"),
        ("Invite to physician policy roundtable", "attend"),
        ("Alert: scope of practice bill THIS WEEK", "alert"),
    ],
    "nurses": [
        ("Share in your hospital's nurse group", "share"),
        ("Forward to your unit manager", "forward"),
        ("Invite to nurse policy briefing", "attend"),
        ("Alert: staffing ratio bill needs YOUR voice", "alert"),
    ],
    "hunters_fishermen": [
        ("Share with your hunting club", "share"),
        ("Forward to your DU chapter", "forward"),
        ("Alert: NCWRC regulation change affects YOU", "alert"),
        ("Sign: petition against anti-hunting bill", "sign"),
        ("Invite to sportsmen's policy dinner", "attend"),
    ],
    "law_enforcement": [
        ("Endorse: add your name to Sheriffs for [Candidate]", "sign"),
        ("Alert: bail reform bill threatens your county", "alert"),
        ("Share with your department", "share"),
        ("Forward to your county sheriff", "forward"),
    ],
    "teachers_school_board": [
        ("Share with your school's parent group", "share"),
        ("Forward to homeschool co-op", "forward"),
        ("Alert: school board vote on curriculum THIS WEEK", "alert"),
        ("Sign: parental rights petition", "sign"),
        ("Bring a friend to school board meeting", "attend"),
    ],
    "finance_banking": [
        ("Forward to your banking colleagues", "forward"),
        ("Alert: new financial regulation affects your clients", "alert"),
        ("Invite to financial policy briefing", "attend"),
    ],
    "real_estate_builders": [
        ("Alert: zoning bill affects your listings", "alert"),
        ("Share with your brokerage", "share"),
        ("Forward to your builder clients", "forward"),
    ],
    "faith_pastors": [
        ("Share from the pulpit", "share"),
        ("Include in church newsletter", "forward"),
        ("Alert: religious freedom bill THIS WEEK", "alert"),
        ("Bring congregation to candidate forum", "attend"),
        ("Donate: protect our values", "donate"),
    ],
    "dairy_specialty_ag": [
        ("Forward to your co-op members", "forward"),
        ("Alert: milk pricing order under review", "alert"),
        ("Share with your Farm Credit lender", "share"),
    ],
    "seniors": [
        ("Forward to your senior center", "forward"),
        ("Alert: Social Security changes affect YOUR benefit", "alert"),
        ("Share with your VFW/Legion post", "share"),
        ("Invite neighbor to candidate coffee", "attend"),
    ],
    "suburban_women": [
        ("Share in your neighborhood Facebook group", "share"),
        ("Forward to your school's parent group", "forward"),
        ("Alert: school board vote THIS WEEK — show up", "alert"),
        ("Bring a friend to meet the candidate", "attend"),
    ],
}


# ============================================================================
# ENGINE CLASS
# ============================================================================

class MicrosegmentIntelligenceEngine:
    """
    Microsegment Intelligence Engine — segment-specific media monitoring,
    topic scoring, and nurture trigger system.

    Uses the SAME article ingestion mechanics as E42 News Intelligence
    but routes content to segment-specific tables and scoring.
    """

    def __init__(self, db_url: str = None):
        self.db_url = db_url or MsIntelConfig.DATABASE_URL
        self._initialized = False

    def initialize(self):
        """Deploy schema and seed data"""
        conn = self._get_db()
        cur = conn.cursor()

        # Deploy schema
        cur.execute(MS_INTEL_SCHEMA)
        conn.commit()

        # Seed media sources
        self._seed_media_sources(cur, conn)

        # Seed topics
        self._seed_topics(cur, conn)

        # Seed CTAs
        self._seed_ctas(cur, conn)

        conn.close()
        self._initialized = True
        logger.info("Microsegment Intelligence Engine initialized")

    def _get_db(self):
        return psycopg2.connect(self.db_url)

    # ========================================================================
    # SEEDING
    # ========================================================================

    def _seed_media_sources(self, cur, conn):
        """Seed all microsegment media sources"""
        count = 0
        for segment_tag, sources in SEGMENT_MEDIA_SOURCES.items():
            for name, url, feed_url, source_type, credibility in sources:
                cur.execute("""
                    INSERT INTO ms_segment_media_sources
                        (segment_tag, name, url, feed_url, source_type, credibility_score)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (segment_tag, url) DO NOTHING
                """, (segment_tag, name, url, feed_url, source_type, credibility))
                count += 1
        conn.commit()
        logger.info(f"Seeded {count} media sources across {len(SEGMENT_MEDIA_SOURCES)} segments")

    def _seed_topics(self, cur, conn):
        """Seed all microsegment topics with keywords"""
        count = 0
        for segment_tag, topics in SEGMENT_TOPICS.items():
            for topic_name, category, importance, keywords in topics:
                cur.execute("""
                    INSERT INTO ms_segment_topics
                        (segment_tag, topic_name, topic_category, importance_score,
                         composite_score, keywords)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (segment_tag, topic_name) DO NOTHING
                """, (segment_tag, topic_name, category, importance,
                      importance * 0.6, json.dumps(keywords)))
                count += 1
        conn.commit()
        logger.info(f"Seeded {count} topics across {len(SEGMENT_TOPICS)} segments")

    def _seed_ctas(self, cur, conn):
        """Seed all segment CTAs"""
        count = 0
        for segment_tag, ctas in SEGMENT_CTAS.items():
            for cta_text, cta_type in ctas:
                cur.execute("""
                    INSERT INTO ms_segment_ctas (segment_tag, cta_text, cta_type)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                """, (segment_tag, cta_text, cta_type))
                count += 1
        conn.commit()
        logger.info(f"Seeded {count} CTAs across {len(SEGMENT_CTAS)} segments")

    # ========================================================================
    # ARTICLE INGESTION — Reuses E42 pattern, routes to segment tables
    # ========================================================================

    def ingest_article(self, url: str, title: str, segment_tag: str,
                      source_id: str = None, content: str = None,
                      description: str = None, published_at: datetime = None,
                      author: str = None) -> Optional[str]:
        """
        Ingest an article into the segment intelligence system.
        Same mechanics as E42 but routes to ms_segment_articles.
        """
        conn = self._get_db()
        cur = conn.cursor()

        # Dedup by URL hash
        url_hash = hashlib.sha256(url.encode()).hexdigest()
        cur.execute("SELECT article_id FROM ms_segment_articles WHERE url_hash = %s", (url_hash,))
        if cur.fetchone():
            conn.close()
            return None  # Duplicate

        word_count = len(content.split()) if content else 0

        # Score relevance against segment topics
        relevance_score = self._score_article_relevance(
            cur, segment_tag, title, content or description or ""
        )

        # Determine priority based on relevance + keywords
        priority = self._determine_priority(relevance_score, title, content or "")

        # Is this actionable?
        is_actionable = relevance_score >= MsIntelConfig.TRIGGER_THRESHOLD

        cur.execute("""
            INSERT INTO ms_segment_articles
                (source_id, segment_tag, url, url_hash, title, description, content,
                 author, published_at, priority, relevance_score, is_actionable, word_count)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING article_id
        """, (source_id, segment_tag, url, url_hash, title, description, content,
              author, published_at, priority, relevance_score, is_actionable, word_count))

        article_id = str(cur.fetchone()[0])

        # Update source stats
        if source_id:
            cur.execute("""
                UPDATE ms_segment_media_sources
                SET articles_ingested = articles_ingested + 1,
                    last_article_found = NOW()
                WHERE source_id = %s
            """, (source_id,))

        # Match article to topics
        self._match_article_to_topics(cur, article_id, segment_tag, title, content or description or "")

        conn.commit()
        conn.close()

        # Fire nurture triggers if actionable
        if is_actionable:
            self._check_nurture_triggers(article_id, segment_tag, relevance_score, priority)

        logger.info(f"Ingested article for {segment_tag}: {title[:60]}... "
                    f"(relevance={relevance_score:.3f}, priority={priority})")
        return article_id

    def _score_article_relevance(self, cur, segment_tag: str,
                                  title: str, content: str) -> float:
        """Score article relevance against segment topics using keyword matching"""
        cur.execute("""
            SELECT topic_id, topic_name, keywords, importance_score
            FROM ms_segment_topics
            WHERE segment_tag = %s AND is_active = true
        """, (segment_tag,))
        topics = cur.fetchall()

        if not topics:
            return 0.500

        text = (title + " " + content).lower()
        max_score = 0.0

        for topic_id, topic_name, keywords_json, importance in topics:
            keywords = json.loads(keywords_json) if isinstance(keywords_json, str) else keywords_json
            matches = sum(1 for kw in keywords if kw.lower() in text)
            if matches > 0:
                # Score = (keyword match ratio) * (importance / 100)
                kw_ratio = min(matches / max(len(keywords), 1), 1.0)
                topic_score = kw_ratio * (importance / 100.0)
                max_score = max(max_score, topic_score)

        # Normalize to 0-1 range
        return min(max_score, 1.0)

    def _determine_priority(self, relevance: float, title: str, content: str) -> str:
        """Determine article priority"""
        text = (title + " " + content).lower()

        # Urgent keywords
        urgent_kw = ["this week", "vote today", "emergency", "breaking", "deadline",
                     "passes committee", "floor vote", "signed into law"]
        if any(kw in text for kw in urgent_kw) and relevance >= 0.6:
            return "urgent"

        if relevance >= 0.75:
            return "high"
        elif relevance >= 0.50:
            return "medium"
        elif relevance >= 0.25:
            return "low"
        return "info"

    def _match_article_to_topics(self, cur, article_id: str, segment_tag: str,
                                  title: str, content: str):
        """Match article to relevant topics and create linkage records"""
        cur.execute("""
            SELECT topic_id, topic_name, keywords, importance_score
            FROM ms_segment_topics
            WHERE segment_tag = %s AND is_active = true
        """, (segment_tag,))
        topics = cur.fetchall()

        text = (title + " " + content).lower()

        for topic_id, topic_name, keywords_json, importance in topics:
            keywords = json.loads(keywords_json) if isinstance(keywords_json, str) else keywords_json
            matches = [kw for kw in keywords if kw.lower() in text]
            if matches:
                kw_ratio = min(len(matches) / max(len(keywords), 1), 1.0)
                match_score = kw_ratio * (importance / 100.0)

                # Find best snippet
                snippet = ""
                for kw in matches:
                    idx = text.find(kw.lower())
                    if idx >= 0:
                        start = max(0, idx - 100)
                        end = min(len(text), idx + len(kw) + 100)
                        snippet = text[start:end]
                        break

                cur.execute("""
                    INSERT INTO ms_article_topic_matches
                        (article_id, topic_id, match_score, match_method, context_snippet)
                    VALUES (%s, %s, %s, 'keyword', %s)
                """, (article_id, topic_id, match_score, snippet))

                # Update topic stats
                cur.execute("""
                    UPDATE ms_segment_topics
                    SET articles_matched = articles_matched + 1,
                        last_article_match = NOW()
                    WHERE topic_id = %s
                """, (topic_id,))

    # ========================================================================
    # NURTURE TRIGGERS — Fire actions through other ecosystems
    # ========================================================================

    def _check_nurture_triggers(self, article_id: str, segment_tag: str,
                                 relevance: float, priority: str):
        """
        Check if article should fire nurture actions.
        Routes to E30 (Email), E31 (SMS), E19 (Social), E09 (Content).
        """
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("""
            SELECT * FROM ms_nurture_triggers
            WHERE segment_tag = %s AND is_active = true
        """, (segment_tag,))
        triggers = cur.fetchall()

        for trigger in triggers:
            condition = trigger['trigger_condition']
            min_score = condition.get('min_score', 0.6)
            min_priority = condition.get('priority', 'medium')

            priority_rank = {'urgent': 4, 'high': 3, 'medium': 2, 'low': 1, 'info': 0}
            if relevance >= min_score and priority_rank.get(priority, 0) >= priority_rank.get(min_priority, 0):
                # Check cooldown
                if trigger['last_fired']:
                    cooldown = timedelta(hours=trigger['cooldown_hours'])
                    if datetime.now() - trigger['last_fired'] < cooldown:
                        continue

                # Fire trigger
                self._fire_nurture_action(
                    trigger['trigger_id'],
                    trigger['action_type'],
                    trigger['target_ecosystem'],
                    trigger['action_config'],
                    article_id,
                    segment_tag
                )

                # Update trigger stats
                cur.execute("""
                    UPDATE ms_nurture_triggers
                    SET last_fired = NOW(), fire_count = fire_count + 1
                    WHERE trigger_id = %s
                """, (trigger['trigger_id'],))

        conn.commit()
        conn.close()

    def _fire_nurture_action(self, trigger_id: str, action_type: str,
                              target_ecosystem: str, config: dict,
                              article_id: str, segment_tag: str):
        """
        Fire a nurture action to the appropriate ecosystem.
        This is the integration point — each ecosystem has its own API.
        """
        logger.info(f"NURTURE TRIGGER FIRED: {action_type} -> {target_ecosystem} "
                    f"for segment {segment_tag}, article {article_id}")

        # Integration dispatch — each ecosystem handles differently
        if target_ecosystem == 'E30':
            # Email Campaign — queue segment email blast
            logger.info(f"  -> E30 Email: Queue segment blast for {segment_tag}")
            # TODO: Call E30 email campaign API
            # email_engine.queue_segment_blast(segment_tag, article_id, config)

        elif target_ecosystem == 'E31':
            # SMS Marketing — send alert to segment
            logger.info(f"  -> E31 SMS: Alert {segment_tag} subscribers")
            # TODO: Call E31 SMS API
            # sms_engine.send_segment_alert(segment_tag, article_id, config)

        elif target_ecosystem == 'E19':
            # Social Media — post to segment social targets
            logger.info(f"  -> E19 Social: Post to {segment_tag} channels")
            # TODO: Call E19 social media API
            # social_engine.post_to_segment(segment_tag, article_id, config)

        elif target_ecosystem == 'E09':
            # Content Creation AI — generate segment-specific copy
            logger.info(f"  -> E09 Content AI: Generate copy for {segment_tag}")
            # TODO: Call E09 content creation API
            # content_engine.generate_segment_content(segment_tag, article_id, config)

        elif target_ecosystem == 'E48':
            # Communication DNA — apply tone/voice for segment
            logger.info(f"  -> E48 Comm DNA: Apply {segment_tag} tone")
            # TODO: Call E48 communication DNA API

    # ========================================================================
    # TOPIC SCORING — ML integration via E21
    # ========================================================================

    def update_trending_scores(self):
        """
        Recalculate trending scores based on recent article matches.
        Called periodically by E21 Machine Learning or cron.
        """
        conn = self._get_db()
        cur = conn.cursor()

        # Trending = articles matched in last 7 days, normalized to 0-100
        cur.execute("""
            WITH recent_matches AS (
                SELECT
                    atm.topic_id,
                    COUNT(*) as match_count,
                    AVG(atm.match_score) as avg_score
                FROM ms_article_topic_matches atm
                JOIN ms_segment_articles sa ON sa.article_id = atm.article_id
                WHERE sa.discovered_at > NOW() - INTERVAL '7 days'
                GROUP BY atm.topic_id
            ),
            max_matches AS (
                SELECT COALESCE(MAX(match_count), 1) as max_count FROM recent_matches
            )
            UPDATE ms_segment_topics t
            SET
                trending_score = COALESCE(
                    (rm.match_count::numeric / mm.max_count) * rm.avg_score * 100,
                    0
                ),
                composite_score = (t.importance_score * 0.6) + (
                    COALESCE((rm.match_count::numeric / mm.max_count) * rm.avg_score * 100, 0) * 0.4
                ),
                updated_at = NOW()
            FROM max_matches mm
            LEFT JOIN recent_matches rm ON rm.topic_id = t.topic_id
        """)

        conn.commit()
        updated = cur.rowcount
        conn.close()
        logger.info(f"Updated trending scores for {updated} topics")
        return updated

    # ========================================================================
    # QUERY METHODS
    # ========================================================================

    def get_segment_dashboard(self, segment_tag: str, days: int = 7) -> Dict:
        """Get full dashboard for a microsegment"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        # Top topics
        cur.execute("""
            SELECT topic_name, importance_score, trending_score, composite_score,
                   articles_matched, last_article_match
            FROM ms_segment_topics
            WHERE segment_tag = %s AND is_active = true
            ORDER BY composite_score DESC LIMIT 10
        """, (segment_tag,))
        top_topics = [dict(r) for r in cur.fetchall()]

        # Recent articles
        cur.execute("""
            SELECT title, url, priority, relevance_score, is_actionable,
                   published_at, discovered_at
            FROM ms_segment_articles
            WHERE segment_tag = %s AND discovered_at > NOW() - INTERVAL '%s days'
            ORDER BY relevance_score DESC LIMIT 20
        """, (segment_tag, days))
        recent_articles = [dict(r) for r in cur.fetchall()]

        # Pending actions
        cur.execute("""
            SELECT COUNT(*) as count FROM ms_segment_articles
            WHERE segment_tag = %s AND is_actionable = true AND action_taken = false
        """, (segment_tag,))
        pending = cur.fetchone()['count']

        # Media sources
        cur.execute("""
            SELECT name, source_type, credibility_score, articles_ingested, last_article_found
            FROM ms_segment_media_sources
            WHERE segment_tag = %s AND is_active = true
            ORDER BY credibility_score DESC
        """, (segment_tag,))
        sources = [dict(r) for r in cur.fetchall()]

        # CTAs
        cur.execute("""
            SELECT cta_text, cta_type, use_count, conversion_rate
            FROM ms_segment_ctas
            WHERE segment_tag = %s AND is_active = true
            ORDER BY conversion_rate DESC
        """, (segment_tag,))
        ctas = [dict(r) for r in cur.fetchall()]

        conn.close()

        return {
            "segment": segment_tag,
            "top_topics": top_topics,
            "recent_articles": recent_articles,
            "pending_actions": pending,
            "media_sources": sources,
            "ctas": ctas,
        }

    def get_top_topics(self, segment_tag: str, limit: int = 10) -> List[Dict]:
        """Get top N topics for a segment by composite score"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT topic_name, topic_category, importance_score,
                   trending_score, composite_score, keywords,
                   articles_matched, last_article_match
            FROM ms_segment_topics
            WHERE segment_tag = %s AND is_active = true
            ORDER BY composite_score DESC
            LIMIT %s
        """, (segment_tag, limit))
        topics = [dict(r) for r in cur.fetchall()]
        conn.close()
        return topics

    def get_actionable_articles(self, segment_tag: str = None) -> List[Dict]:
        """Get articles pending nurture action"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        sql = """
            SELECT sa.*, s.name as source_name
            FROM ms_segment_articles sa
            LEFT JOIN ms_segment_media_sources s ON s.source_id = sa.source_id
            WHERE sa.is_actionable = true AND sa.action_taken = false
        """
        params = []
        if segment_tag:
            sql += " AND sa.segment_tag = %s"
            params.append(segment_tag)
        sql += " ORDER BY sa.relevance_score DESC"

        cur.execute(sql, params)
        articles = [dict(r) for r in cur.fetchall()]
        conn.close()
        return articles


# ============================================================================
# DEPLOYMENT
# ============================================================================

def deploy_microsegment_intelligence():
    """Deploy Microsegment Intelligence ecosystem"""
    print("=" * 70)
    print("  ECOSYSTEM 59: MICROSEGMENT INTELLIGENCE — DEPLOYMENT")
    print("=" * 70)

    try:
        engine = MicrosegmentIntelligenceEngine()
        engine.initialize()

        # Count what was seeded
        source_count = sum(len(v) for v in SEGMENT_MEDIA_SOURCES.values())
        topic_count = sum(len(v) for v in SEGMENT_TOPICS.values())
        cta_count = sum(len(v) for v in SEGMENT_CTAS.values())

        print(f"\n   TABLES:")
        print(f"   ✅ ms_segment_media_sources")
        print(f"   ✅ ms_segment_articles")
        print(f"   ✅ ms_segment_topics")
        print(f"   ✅ ms_article_topic_matches")
        print(f"   ✅ ms_segment_ctas")
        print(f"   ✅ ms_nurture_triggers")
        print(f"   ✅ ms_segment_performance")
        print(f"   ✅ ms_segment_social_targets")
        print(f"   ✅ ms_candidate_segment_activation")

        print(f"\n   VIEWS:")
        print(f"   ✅ v_ms_candidate_dashboard")
        print(f"   ✅ v_ms_trending_topics")
        print(f"   ✅ v_ms_source_performance")
        print(f"   ✅ v_ms_segment_roi")

        print(f"\n   SEED DATA:")
        print(f"   ✅ {source_count} media sources across {len(SEGMENT_MEDIA_SOURCES)} segments")
        print(f"   ✅ {topic_count} topics across {len(SEGMENT_TOPICS)} segments")
        print(f"   ✅ {cta_count} CTAs across {len(SEGMENT_CTAS)} segments")

        print(f"\n   INTEGRATIONS:")
        print(f"   → E42 News Intelligence (shared ingestion engine)")
        print(f"   → E09 Content Creation AI (segment copy generation)")
        print(f"   → E20 Intelligence Brain (routing & decisions)")
        print(f"   → E21 Machine Learning (cost/benefit/variance)")
        print(f"   → E19 Social Media (segment social targeting)")
        print(f"   → E30 Email Campaigns (segment nurture blasts)")
        print(f"   → E31 SMS Marketing (segment alerts)")
        print(f"   → E48 Communication DNA (tone/voice per segment)")

        print(f"\n" + "=" * 70)
        print(f"  ✅ MICROSEGMENT INTELLIGENCE DEPLOYED!")
        print(f"  💰 Powers: Targeted donor cultivation through segment-specific intelligence")
        print(f"=" * 70)

        return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    deploy_microsegment_intelligence()
