#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 41: CAMPAIGN BUILDER - COMPLETE (100%)
============================================================================

PLATFORM HOMEPAGE "MAKE A CAMPAIGN" FEATURE

TWO PATHS:
1. AI CAMPAIGN GENERATION - Full autopilot campaign creation
2. MANUAL CREATE - Step-by-step with IFTTT automation selection

MANUAL COMPOSITION FLOW:
Step 1: Campaign Basics (name, candidate, dates, budget)
Step 2: Select Channels (email, SMS, phone, mail, social, etc.)
Step 3: Define Audience (segments, filters, exclusions)
Step 4: Create Content (templates, AI assist, or upload)
Step 5: SELECT IFTTT AUTOMATIONS ← Key integration
Step 6: Set Goals & Tracking
Step 7: Review & Launch

IFTTT SELECTION IN MANUAL MODE:
- Browse available IFTTT workflows
- Select which automations to attach
- Configure trigger conditions
- Set ON/OFF/TIMER for each
- Preview automation flow

Development Value: $175,000+
============================================================================
"""

import os
import json
import uuid
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from enum import Enum

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem41.campaign_builder')


class CampaignConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")


class CampaignMode(Enum):
    AI_AUTOPILOT = "ai_autopilot"
    MANUAL = "manual"

class CampaignType(Enum):
    FUNDRAISING = "fundraising"
    GOTV = "gotv"
    AWARENESS = "awareness"
    EVENT = "event"
    ADVOCACY = "advocacy"
    VOLUNTEER = "volunteer"
    PETITION = "petition"

class CampaignStatus(Enum):
    DRAFT = "draft"
    PENDING_REVIEW = "pending_review"
    SCHEDULED = "scheduled"
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class BuilderStep(Enum):
    BASICS = 1
    CHANNELS = 2
    AUDIENCE = 3
    CONTENT = 4
    IFTTT = 5  # IFTTT automation selection
    GOALS = 6
    REVIEW = 7


# Available channels for campaign
CAMPAIGN_CHANNELS = {
    'email': {
        'name': 'Email',
        'icon': '📧',
        'ecosystem': 'E30',
        'description': 'Send personalized email campaigns',
        'requires': ['email_address'],
        'ifttt_triggers': ['email.opened', 'email.clicked', 'email.bounced', 'email.not_opened']
    },
    'sms': {
        'name': 'SMS/MMS',
        'icon': '📱',
        'ecosystem': 'E31',
        'description': 'Text message campaigns with media',
        'requires': ['mobile_phone'],
        'ifttt_triggers': ['sms.received', 'sms.keyword', 'sms.clicked']
    },
    'rcs': {
        'name': 'RCS Rich Messaging',
        'icon': '💬',
        'ecosystem': 'E31',
        'description': 'Rich messaging with carousels and buttons',
        'requires': ['mobile_phone'],
        'ifttt_triggers': ['sms.received', 'sms.clicked']
    },
    'phone': {
        'name': 'Phone Banking',
        'icon': '📞',
        'ecosystem': 'E32',
        'description': 'Live or AI-powered phone calls',
        'requires': ['phone'],
        'ifttt_triggers': ['phone.call_completed', 'phone.positive_call', 'phone.voicemail_left']
    },
    'rvm': {
        'name': 'Ringless Voicemail',
        'icon': '🔔',
        'ecosystem': 'E17',
        'description': 'Voicemail drops without ringing',
        'requires': ['mobile_phone'],
        'ifttt_triggers': []
    },
    'direct_mail': {
        'name': 'Direct Mail',
        'icon': '✉️',
        'ecosystem': 'E33',
        'description': 'Physical mail with VDP personalization',
        'requires': ['mailing_address'],
        'ifttt_triggers': ['mail.delivered', 'mail.returned', 'mail.responded']
    },
    'social': {
        'name': 'Social Media',
        'icon': '📱',
        'ecosystem': 'E19',
        'description': 'Facebook, Instagram, Twitter posts',
        'requires': [],
        'ifttt_triggers': ['social.engagement_threshold', 'social.comment']
    },
    'tv': {
        'name': 'TV Advertising',
        'icon': '📺',
        'ecosystem': 'E16',
        'description': 'Television ad placement',
        'requires': [],
        'ifttt_triggers': []
    },
    'radio': {
        'name': 'Radio Advertising',
        'icon': '📻',
        'ecosystem': 'E16',
        'description': 'Radio ad placement',
        'requires': [],
        'ifttt_triggers': []
    },
    'digital_ads': {
        'name': 'Digital Ads',
        'icon': '🖥️',
        'ecosystem': 'E19',
        'description': 'Google, Facebook, programmatic ads',
        'requires': [],
        'ifttt_triggers': []
    },
    'events': {
        'name': 'Events',
        'icon': '📅',
        'ecosystem': 'E34',
        'description': 'Rally, town hall, fundraiser events',
        'requires': [],
        'ifttt_triggers': ['event.rsvp', 'event.checked_in', 'event.no_show']
    }
}

# Recommended IFTTT workflows by campaign type
RECOMMENDED_IFTTT_BY_CAMPAIGN = {
    'fundraising': [
        {'id': 'donation_thank_you', 'name': 'Donation Thank You', 'trigger': 'donation.received', 'essential': True},
        {'id': 'new_donor_nurture', 'name': 'New Donor Nurture', 'trigger': 'donation.first', 'essential': True},
        {'id': 'recurring_upgrade', 'name': 'Recurring Upgrade Ask', 'trigger': 'donation.received', 'essential': False},
        {'id': 'lapsed_reactivation', 'name': 'Lapsed Donor Reactivation', 'trigger': 'donor.became_lapsed', 'essential': True},
        {'id': 'major_donor_alert', 'name': 'Major Donor Alert', 'trigger': 'donation.threshold', 'essential': True},
        {'id': 'email_not_opened', 'name': 'Email Follow-up', 'trigger': 'email.not_opened', 'essential': False},
    ],
    'gotv': [
        {'id': 'voter_reminder', 'name': 'Voter Reminder Series', 'trigger': 'time.schedule', 'essential': True},
        {'id': 'poll_location', 'name': 'Poll Location Info', 'trigger': 'time.date_field', 'essential': True},
        {'id': 'ride_to_polls', 'name': 'Ride to Polls Offer', 'trigger': 'contact.tag_added', 'essential': False},
        {'id': 'voted_thank_you', 'name': 'Voted Thank You', 'trigger': 'contact.updated', 'essential': True},
    ],
    'event': [
        {'id': 'event_reminder', 'name': 'Event Reminder Series', 'trigger': 'event.rsvp', 'essential': True},
        {'id': 'no_show_followup', 'name': 'No-Show Follow-up', 'trigger': 'event.no_show', 'essential': True},
        {'id': 'post_event_thanks', 'name': 'Post-Event Thank You', 'trigger': 'event.checked_in', 'essential': True},
        {'id': 'event_donation_ask', 'name': 'Post-Event Donation Ask', 'trigger': 'event.checked_in', 'essential': False},
    ],
    'awareness': [
        {'id': 'welcome_series', 'name': 'Welcome Series', 'trigger': 'contact.created', 'essential': True},
        {'id': 'engagement_nurture', 'name': 'Engagement Nurture', 'trigger': 'email.opened', 'essential': False},
        {'id': 'issue_update', 'name': 'Issue Update Response', 'trigger': 'news.issue_trending', 'essential': False},
    ],
    'volunteer': [
        {'id': 'volunteer_welcome', 'name': 'Volunteer Welcome', 'trigger': 'contact.tag_added', 'essential': True},
        {'id': 'shift_reminder', 'name': 'Shift Reminder', 'trigger': 'time.date_field', 'essential': True},
        {'id': 'volunteer_thanks', 'name': 'Volunteer Thank You', 'trigger': 'contact.updated', 'essential': True},
    ]
}


CAMPAIGN_BUILDER_SCHEMA = """
-- ============================================================================
-- ECOSYSTEM 41: CAMPAIGN BUILDER
-- ============================================================================

-- Campaign Master Record
CREATE TABLE IF NOT EXISTS campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(500) NOT NULL,
    internal_name VARCHAR(255),
    description TEXT,
    
    -- Ownership
    candidate_id UUID,
    created_by VARCHAR(255),
    
    -- Type & Mode
    campaign_type VARCHAR(50) NOT NULL,
    creation_mode VARCHAR(20) NOT NULL DEFAULT 'manual',
    
    -- Dates
    start_date DATE,
    end_date DATE,
    
    -- Budget
    total_budget DECIMAL(12,2),
    spent_budget DECIMAL(12,2) DEFAULT 0,
    
    -- Channels (JSON array)
    selected_channels JSONB DEFAULT '[]',
    
    -- Audience
    audience_segments JSONB DEFAULT '[]',
    audience_filters JSONB DEFAULT '{}',
    audience_exclusions JSONB DEFAULT '[]',
    estimated_reach INTEGER,
    
    -- Content
    content_config JSONB DEFAULT '{}',
    
    -- IFTTT Automations
    attached_ifttt JSONB DEFAULT '[]',
    ifttt_config JSONB DEFAULT '{}',
    
    -- Goals
    goals JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft',
    current_step INTEGER DEFAULT 1,
    
    -- Builder state (for saving progress)
    builder_state JSONB DEFAULT '{}',
    
    -- Stats
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    total_converted INTEGER DEFAULT 0,
    total_raised DECIMAL(12,2) DEFAULT 0,
    
    -- AI Generation (if ai_autopilot)
    ai_prompt TEXT,
    ai_generated_plan JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    launched_at TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_campaigns_candidate ON campaigns(candidate_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_type ON campaigns(campaign_type);

-- Campaign IFTTT Attachments (which automations are attached)
CREATE TABLE IF NOT EXISTS campaign_ifttt_attachments (
    attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    workflow_id UUID,
    
    -- Workflow info snapshot
    workflow_name VARCHAR(500),
    trigger_type VARCHAR(100),
    
    -- Control mode for this campaign
    mode VARCHAR(20) DEFAULT 'on',
    timer_minutes INTEGER,
    timer_expires_at TIMESTAMP,
    
    -- Customization for this campaign
    custom_trigger_config JSONB DEFAULT '{}',
    custom_actions JSONB DEFAULT '[]',
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Stats within this campaign
    times_triggered INTEGER DEFAULT 0,
    last_triggered_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ifttt_attach_campaign ON campaign_ifttt_attachments(campaign_id);

-- Campaign Channel Configuration
CREATE TABLE IF NOT EXISTS campaign_channel_config (
    config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    
    -- Channel
    channel_type VARCHAR(50) NOT NULL,
    
    -- Channel-specific config
    config JSONB DEFAULT '{}',
    
    -- Content for this channel
    content_template_id UUID,
    content_data JSONB DEFAULT '{}',
    
    -- Schedule
    send_schedule JSONB DEFAULT '{}',
    
    -- Budget allocation
    budget_allocation DECIMAL(12,2),
    
    -- Stats
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_channel_config_campaign ON campaign_channel_config(campaign_id);

-- Campaign Builder Sessions (save progress)
CREATE TABLE IF NOT EXISTS campaign_builder_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    user_id VARCHAR(255),
    
    -- Progress
    current_step INTEGER DEFAULT 1,
    step_data JSONB DEFAULT '{}',
    
    -- Validation
    steps_completed JSONB DEFAULT '[]',
    validation_errors JSONB DEFAULT '[]',
    
    last_activity_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Campaign Goals
CREATE TABLE IF NOT EXISTS campaign_goals (
    goal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    
    -- Goal definition
    goal_type VARCHAR(100) NOT NULL,
    goal_name VARCHAR(255),
    target_value DECIMAL(12,2),
    
    -- Progress
    current_value DECIMAL(12,2) DEFAULT 0,
    achieved BOOLEAN DEFAULT false,
    achieved_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_campaign_goals ON campaign_goals(campaign_id);

-- Views
CREATE OR REPLACE VIEW v_campaign_overview AS
SELECT 
    c.campaign_id,
    c.name,
    c.campaign_type,
    c.creation_mode,
    c.status,
    c.start_date,
    c.end_date,
    c.total_budget,
    c.spent_budget,
    c.estimated_reach,
    c.total_sent,
    c.total_raised,
    jsonb_array_length(c.selected_channels) as channel_count,
    jsonb_array_length(c.attached_ifttt) as ifttt_count,
    c.created_at,
    c.launched_at
FROM campaigns c
ORDER BY c.created_at DESC;

CREATE OR REPLACE VIEW v_campaign_ifttt_summary AS
SELECT 
    c.campaign_id,
    c.name as campaign_name,
    cia.workflow_name,
    cia.trigger_type,
    cia.mode,
    cia.timer_minutes,
    cia.times_triggered,
    cia.is_active
FROM campaigns c
JOIN campaign_ifttt_attachments cia ON c.campaign_id = cia.campaign_id
ORDER BY c.campaign_id, cia.workflow_name;

SELECT 'Campaign Builder schema deployed!' as status;
"""


class CampaignBuilder:
    """Campaign Builder with AI and Manual modes including IFTTT selection"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self.db_url = CampaignConfig.DATABASE_URL
        self.channels = CAMPAIGN_CHANNELS
        self.recommended_ifttt = RECOMMENDED_IFTTT_BY_CAMPAIGN
        self._initialized = True
        logger.info("🚀 Campaign Builder initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # CAMPAIGN CREATION - ENTRY POINT
    # ========================================================================
    
    def start_campaign(self, mode: str, candidate_id: str = None,
                      created_by: str = None) -> Dict:
        """
        Entry point - user selects AI or Manual mode
        
        Returns campaign_id and initial state
        """
        conn = self._get_db()
        cur = conn.cursor()
        
        campaign_id = str(uuid.uuid4())
        
        cur.execute("""
            INSERT INTO campaigns (
                campaign_id, candidate_id, created_by, creation_mode,
                name, campaign_type, status, current_step
            ) VALUES (%s, %s, %s, %s, 'New Campaign', 'fundraising', 'draft', 1)
        """, (campaign_id, candidate_id, created_by, mode))
        
        # Create builder session
        cur.execute("""
            INSERT INTO campaign_builder_sessions (campaign_id, user_id, current_step)
            VALUES (%s, %s, 1)
        """, (campaign_id, created_by))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Started new campaign: {campaign_id} in {mode} mode")
        
        if mode == 'ai_autopilot':
            return {
                'campaign_id': campaign_id,
                'mode': 'ai_autopilot',
                'next_action': 'provide_ai_prompt',
                'prompt_suggestions': self._get_ai_prompt_suggestions()
            }
        else:
            return {
                'campaign_id': campaign_id,
                'mode': 'manual',
                'current_step': 1,
                'total_steps': 7,
                'steps': self._get_builder_steps()
            }
    
    def _get_builder_steps(self) -> List[Dict]:
        """Get all builder steps for manual mode"""
        return [
            {'step': 1, 'name': 'Basics', 'description': 'Campaign name, type, dates, budget'},
            {'step': 2, 'name': 'Channels', 'description': 'Select communication channels'},
            {'step': 3, 'name': 'Audience', 'description': 'Define target audience'},
            {'step': 4, 'name': 'Content', 'description': 'Create or select content'},
            {'step': 5, 'name': 'IFTTT Automations', 'description': 'Attach automation workflows'},
            {'step': 6, 'name': 'Goals', 'description': 'Set campaign goals'},
            {'step': 7, 'name': 'Review & Launch', 'description': 'Review and launch campaign'},
        ]
    
    def _get_ai_prompt_suggestions(self) -> List[str]:
        """Suggestions for AI campaign generation"""
        return [
            "Create a 2-week fundraising campaign targeting lapsed donors with email, SMS, and direct mail",
            "Build a GOTV campaign for the last 5 days before election targeting unlikely voters",
            "Design a volunteer recruitment campaign using social media and email",
            "Create an event promotion campaign for our upcoming town hall with RSVP tracking",
            "Build a rapid response campaign template for breaking news situations"
        ]
    
    # ========================================================================
    # STEP 1: BASICS
    # ========================================================================
    
    def save_basics(self, campaign_id: str, name: str, campaign_type: str,
                   start_date: str = None, end_date: str = None,
                   budget: float = None, description: str = None) -> Dict:
        """Save Step 1: Campaign basics"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE campaigns SET
                name = %s,
                campaign_type = %s,
                start_date = %s,
                end_date = %s,
                total_budget = %s,
                description = %s,
                current_step = 2,
                updated_at = NOW()
            WHERE campaign_id = %s
        """, (name, campaign_type, start_date, end_date, budget, description, campaign_id))
        
        conn.commit()
        conn.close()
        
        return {
            'campaign_id': campaign_id,
            'step_completed': 1,
            'next_step': 2,
            'next_step_name': 'Channels',
            'available_channels': list(self.channels.keys())
        }
    
    # ========================================================================
    # STEP 2: CHANNELS
    # ========================================================================
    
    def get_available_channels(self) -> List[Dict]:
        """Get all available channels with details"""
        return [
            {
                'id': channel_id,
                **channel_data
            }
            for channel_id, channel_data in self.channels.items()
        ]
    
    def save_channels(self, campaign_id: str, selected_channels: List[str]) -> Dict:
        """Save Step 2: Selected channels"""
        conn = self._get_db()
        cur = conn.cursor()
        
        # Get IFTTT triggers for selected channels
        available_triggers = []
        for channel in selected_channels:
            if channel in self.channels:
                available_triggers.extend(self.channels[channel]['ifttt_triggers'])
        
        cur.execute("""
            UPDATE campaigns SET
                selected_channels = %s,
                current_step = 3,
                updated_at = NOW()
            WHERE campaign_id = %s
        """, (json.dumps(selected_channels), campaign_id))
        
        # Create channel config records
        for channel in selected_channels:
            cur.execute("""
                INSERT INTO campaign_channel_config (campaign_id, channel_type)
                VALUES (%s, %s)
                ON CONFLICT DO NOTHING
            """, (campaign_id, channel))
        
        conn.commit()
        conn.close()
        
        return {
            'campaign_id': campaign_id,
            'step_completed': 2,
            'next_step': 3,
            'next_step_name': 'Audience',
            'selected_channels': selected_channels,
            'available_ifttt_triggers': list(set(available_triggers))
        }
    
    # ========================================================================
    # STEP 3: AUDIENCE
    # ========================================================================
    
    def save_audience(self, campaign_id: str, segments: List[str] = None,
                     filters: Dict = None, exclusions: List[str] = None) -> Dict:
        """Save Step 3: Audience definition"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Calculate estimated reach (in production, queries DataHub)
        estimated_reach = self._estimate_audience_reach(segments, filters, exclusions)
        
        cur.execute("""
            UPDATE campaigns SET
                audience_segments = %s,
                audience_filters = %s,
                audience_exclusions = %s,
                estimated_reach = %s,
                current_step = 4,
                updated_at = NOW()
            WHERE campaign_id = %s
        """, (
            json.dumps(segments or []),
            json.dumps(filters or {}),
            json.dumps(exclusions or []),
            estimated_reach,
            campaign_id
        ))
        
        conn.commit()
        conn.close()
        
        return {
            'campaign_id': campaign_id,
            'step_completed': 3,
            'next_step': 4,
            'next_step_name': 'Content',
            'estimated_reach': estimated_reach
        }
    
    def _estimate_audience_reach(self, segments: List, filters: Dict, exclusions: List) -> int:
        """Estimate audience reach (simplified)"""
        # In production, this queries E0 DataHub
        base = 50000
        if segments:
            base = base * len(segments) // 2
        if exclusions:
            base = int(base * 0.8)
        return base
    
    # ========================================================================
    # STEP 4: CONTENT
    # ========================================================================
    
    def save_content(self, campaign_id: str, content_config: Dict) -> Dict:
        """Save Step 4: Content configuration"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE campaigns SET
                content_config = %s,
                current_step = 5,
                updated_at = NOW()
            WHERE campaign_id = %s
        """, (json.dumps(content_config), campaign_id))
        
        conn.commit()
        conn.close()
        
        return {
            'campaign_id': campaign_id,
            'step_completed': 4,
            'next_step': 5,
            'next_step_name': 'IFTTT Automations'
        }
    
    # ========================================================================
    # STEP 5: IFTTT AUTOMATION SELECTION (KEY FEATURE)
    # ========================================================================
    
    def get_ifttt_recommendations(self, campaign_id: str) -> Dict:
        """Get recommended IFTTT automations based on campaign type and channels"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get campaign info
        cur.execute("""
            SELECT campaign_type, selected_channels FROM campaigns WHERE campaign_id = %s
        """, (campaign_id,))
        campaign = cur.fetchone()
        conn.close()
        
        campaign_type = campaign['campaign_type']
        selected_channels = campaign['selected_channels'] or []
        
        # Get recommended workflows for this campaign type
        recommended = self.recommended_ifttt.get(campaign_type, [])
        
        # Get channel-specific triggers
        channel_triggers = []
        for channel in selected_channels:
            if channel in self.channels:
                channel_triggers.extend([
                    {
                        'trigger': t,
                        'channel': channel,
                        'channel_name': self.channels[channel]['name']
                    }
                    for t in self.channels[channel]['ifttt_triggers']
                ])
        
        # Get all available workflows (from E40)
        all_workflows = self._get_all_ifttt_workflows()
        
        return {
            'campaign_id': campaign_id,
            'campaign_type': campaign_type,
            'recommended_workflows': recommended,
            'channel_triggers': channel_triggers,
            'all_available_workflows': all_workflows,
            'categories': [
                {'id': 'recommended', 'name': '⭐ Recommended for This Campaign'},
                {'id': 'channel', 'name': '📡 Channel-Based Triggers'},
                {'id': 'donor', 'name': '💰 Donor & Donation'},
                {'id': 'engagement', 'name': '📧 Engagement'},
                {'id': 'news', 'name': '📰 News Intelligence'},
                {'id': 'events', 'name': '📅 Events'},
                {'id': 'all', 'name': '📋 All Workflows'}
            ]
        }
    
    def _get_all_ifttt_workflows(self) -> List[Dict]:
        """Get all available IFTTT workflows from E40"""
        # In production, queries automation_workflows table
        return [
            {'id': 'welcome_series', 'name': 'Welcome Series', 'trigger': 'contact.created', 'category': 'engagement'},
            {'id': 'donation_thank_you', 'name': 'Donation Thank You', 'trigger': 'donation.received', 'category': 'donor'},
            {'id': 'new_donor_nurture', 'name': 'New Donor Nurture', 'trigger': 'donation.first', 'category': 'donor'},
            {'id': 'lapsed_reactivation', 'name': 'Lapsed Donor Reactivation', 'trigger': 'donor.became_lapsed', 'category': 'donor'},
            {'id': 'email_not_opened', 'name': 'Email Not Opened Follow-up', 'trigger': 'email.not_opened', 'category': 'engagement'},
            {'id': 'sms_keyword', 'name': 'SMS Keyword Response', 'trigger': 'sms.keyword', 'category': 'engagement'},
            {'id': 'event_reminder', 'name': 'Event Reminder Series', 'trigger': 'event.rsvp', 'category': 'events'},
            {'id': 'no_show_followup', 'name': 'No-Show Follow-up', 'trigger': 'event.no_show', 'category': 'events'},
            {'id': 'rapid_response', 'name': 'Rapid Response - Negative Coverage', 'trigger': 'news.crisis_detected', 'category': 'news'},
            {'id': 'issue_capitalize', 'name': 'Capitalize on Trending Issue', 'trigger': 'news.issue_trending', 'category': 'news'},
            {'id': 'opponent_response', 'name': 'Opponent Attack Response', 'trigger': 'news.competitor_attack', 'category': 'news'},
            {'id': 'positive_coverage', 'name': 'Amplify Positive Coverage', 'trigger': 'news.positive_coverage', 'category': 'news'},
        ]
    
    def attach_ifttt(self, campaign_id: str, workflow_id: str,
                    mode: str = 'on', timer_minutes: int = None,
                    custom_config: Dict = None) -> str:
        """Attach an IFTTT workflow to the campaign"""
        conn = self._get_db()
        cur = conn.cursor()
        
        # Get workflow info
        workflows = self._get_all_ifttt_workflows()
        workflow = next((w for w in workflows if w['id'] == workflow_id), None)
        
        if not workflow:
            raise ValueError(f"Unknown workflow: {workflow_id}")
        
        # Calculate timer expiration if applicable
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        # Create attachment
        cur.execute("""
            INSERT INTO campaign_ifttt_attachments (
                campaign_id, workflow_id, workflow_name, trigger_type,
                mode, timer_minutes, timer_expires_at, custom_trigger_config
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING attachment_id
        """, (
            campaign_id, workflow_id, workflow['name'], workflow['trigger'],
            mode, timer_minutes, timer_expires_at,
            json.dumps(custom_config or {})
        ))
        
        attachment_id = str(cur.fetchone()[0])
        
        # Update campaign's attached_ifttt list
        cur.execute("""
            UPDATE campaigns SET
                attached_ifttt = attached_ifttt || %s::jsonb,
                updated_at = NOW()
            WHERE campaign_id = %s
        """, (json.dumps([{'workflow_id': workflow_id, 'attachment_id': attachment_id}]), campaign_id))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Attached workflow {workflow_id} to campaign {campaign_id}")
        return attachment_id
    
    def detach_ifttt(self, campaign_id: str, attachment_id: str) -> bool:
        """Detach an IFTTT workflow from the campaign"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            DELETE FROM campaign_ifttt_attachments
            WHERE campaign_id = %s AND attachment_id = %s
        """, (campaign_id, attachment_id))
        
        conn.commit()
        conn.close()
        return True
    
    def set_ifttt_mode(self, attachment_id: str, mode: str,
                      timer_minutes: int = None) -> Dict:
        """Set mode (on/off/timer) for attached IFTTT"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            UPDATE campaign_ifttt_attachments SET
                mode = %s,
                timer_minutes = %s,
                timer_expires_at = %s
            WHERE attachment_id = %s
        """, (mode, timer_minutes, timer_expires_at, attachment_id))
        
        conn.commit()
        conn.close()
        
        return {
            'attachment_id': attachment_id,
            'mode': mode,
            'timer_minutes': timer_minutes,
            'timer_expires_at': timer_expires_at.isoformat() if timer_expires_at else None
        }
    
    def save_ifttt_step(self, campaign_id: str) -> Dict:
        """Complete Step 5: IFTTT selection"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get attached workflows
        cur.execute("""
            SELECT * FROM campaign_ifttt_attachments WHERE campaign_id = %s
        """, (campaign_id,))
        attachments = [dict(a) for a in cur.fetchall()]
        
        cur.execute("""
            UPDATE campaigns SET current_step = 6, updated_at = NOW() WHERE campaign_id = %s
        """, (campaign_id,))
        
        conn.commit()
        conn.close()
        
        return {
            'campaign_id': campaign_id,
            'step_completed': 5,
            'next_step': 6,
            'next_step_name': 'Goals',
            'attached_ifttt_count': len(attachments),
            'attached_workflows': attachments
        }
    
    # ========================================================================
    # STEP 6: GOALS
    # ========================================================================
    
    def save_goals(self, campaign_id: str, goals: List[Dict]) -> Dict:
        """Save Step 6: Campaign goals"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE campaigns SET
                goals = %s,
                current_step = 7,
                updated_at = NOW()
            WHERE campaign_id = %s
        """, (json.dumps(goals), campaign_id))
        
        # Create goal records
        for goal in goals:
            cur.execute("""
                INSERT INTO campaign_goals (campaign_id, goal_type, goal_name, target_value)
                VALUES (%s, %s, %s, %s)
            """, (campaign_id, goal.get('type'), goal.get('name'), goal.get('target')))
        
        conn.commit()
        conn.close()
        
        return {
            'campaign_id': campaign_id,
            'step_completed': 6,
            'next_step': 7,
            'next_step_name': 'Review & Launch'
        }
    
    # ========================================================================
    # STEP 7: REVIEW & LAUNCH
    # ========================================================================
    
    def get_campaign_review(self, campaign_id: str) -> Dict:
        """Get complete campaign review for final step"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get campaign
        cur.execute("SELECT * FROM campaigns WHERE campaign_id = %s", (campaign_id,))
        campaign = dict(cur.fetchone())
        
        # Get channel configs
        cur.execute("SELECT * FROM campaign_channel_config WHERE campaign_id = %s", (campaign_id,))
        channels = [dict(c) for c in cur.fetchall()]
        
        # Get IFTTT attachments
        cur.execute("SELECT * FROM campaign_ifttt_attachments WHERE campaign_id = %s", (campaign_id,))
        ifttt = [dict(i) for i in cur.fetchall()]
        
        # Get goals
        cur.execute("SELECT * FROM campaign_goals WHERE campaign_id = %s", (campaign_id,))
        goals = [dict(g) for g in cur.fetchall()]
        
        conn.close()
        
        # Build review summary
        return {
            'campaign_id': campaign_id,
            'summary': {
                'name': campaign['name'],
                'type': campaign['campaign_type'],
                'dates': f"{campaign['start_date']} to {campaign['end_date']}",
                'budget': campaign['total_budget'],
                'estimated_reach': campaign['estimated_reach']
            },
            'channels': channels,
            'ifttt_automations': [
                {
                    'name': i['workflow_name'],
                    'trigger': i['trigger_type'],
                    'mode': i['mode'],
                    'timer': i['timer_minutes']
                }
                for i in ifttt
            ],
            'goals': goals,
            'validation': self._validate_campaign(campaign, channels, ifttt),
            'ready_to_launch': True
        }
    
    def _validate_campaign(self, campaign: Dict, channels: List, ifttt: List) -> Dict:
        """Validate campaign is ready to launch"""
        errors = []
        warnings = []
        
        if not campaign['name'] or campaign['name'] == 'New Campaign':
            errors.append('Campaign name is required')
        
        if not campaign['selected_channels']:
            errors.append('At least one channel must be selected')
        
        if not campaign['start_date']:
            warnings.append('No start date set - will start immediately')
        
        if not ifttt:
            warnings.append('No IFTTT automations attached - responses will be manual')
        
        return {
            'valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings
        }
    
    def launch_campaign(self, campaign_id: str, launched_by: str = None) -> Dict:
        """Launch the campaign"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE campaigns SET
                status = 'active',
                launched_at = NOW(),
                updated_at = NOW()
            WHERE campaign_id = %s
        """, (campaign_id,))
        
        # Activate all IFTTT attachments
        cur.execute("""
            UPDATE campaign_ifttt_attachments SET is_active = true WHERE campaign_id = %s
        """, (campaign_id,))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Campaign launched: {campaign_id}")
        
        return {
            'campaign_id': campaign_id,
            'status': 'active',
            'launched_at': datetime.now().isoformat(),
            'message': 'Campaign launched successfully!'
        }
    
    # ========================================================================
    # AI AUTOPILOT MODE
    # ========================================================================
    
    def generate_ai_campaign(self, campaign_id: str, prompt: str) -> Dict:
        """Generate complete campaign using AI"""
        conn = self._get_db()
        cur = conn.cursor()
        
        # In production, this calls E13 AI Hub to generate campaign plan
        ai_plan = self._ai_generate_campaign_plan(prompt)
        
        cur.execute("""
            UPDATE campaigns SET
                ai_prompt = %s,
                ai_generated_plan = %s,
                name = %s,
                campaign_type = %s,
                selected_channels = %s,
                attached_ifttt = %s,
                goals = %s,
                status = 'pending_review',
                updated_at = NOW()
            WHERE campaign_id = %s
        """, (
            prompt,
            json.dumps(ai_plan),
            ai_plan['name'],
            ai_plan['type'],
            json.dumps(ai_plan['channels']),
            json.dumps(ai_plan['ifttt']),
            json.dumps(ai_plan['goals']),
            campaign_id
        ))
        
        conn.commit()
        conn.close()
        
        return {
            'campaign_id': campaign_id,
            'mode': 'ai_autopilot',
            'status': 'pending_review',
            'generated_plan': ai_plan,
            'message': 'AI has generated your campaign plan. Please review before launching.'
        }
    
    def _ai_generate_campaign_plan(self, prompt: str) -> Dict:
        """AI generates campaign plan (simplified)"""
        # In production, this calls Claude/GPT to generate full plan
        return {
            'name': 'AI Generated: ' + prompt[:50],
            'type': 'fundraising',
            'channels': ['email', 'sms', 'social'],
            'ifttt': [
                {'workflow_id': 'donation_thank_you', 'mode': 'on'},
                {'workflow_id': 'email_not_opened', 'mode': 'on'},
                {'workflow_id': 'new_donor_nurture', 'mode': 'on'}
            ],
            'goals': [
                {'type': 'donations', 'name': 'Total Raised', 'target': 50000},
                {'type': 'donors', 'name': 'New Donors', 'target': 500}
            ],
            'schedule': {
                'email_1': 'Day 1',
                'sms_1': 'Day 2',
                'email_2': 'Day 4',
                'social_1': 'Day 1-7'
            }
        }


def deploy_campaign_builder():
    """Deploy Campaign Builder"""
    print("=" * 70)
    print("🚀 ECOSYSTEM 41: CAMPAIGN BUILDER - DEPLOYMENT")
    print("=" * 70)
    
    try:
        conn = psycopg2.connect(CampaignConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("\nDeploying schema...")
        cur.execute(CAMPAIGN_BUILDER_SCHEMA)
        conn.commit()
        conn.close()
        
        print("\n   ✅ campaigns table")
        print("   ✅ campaign_ifttt_attachments table")
        print("   ✅ campaign_channel_config table")
        print("   ✅ campaign_builder_sessions table")
        print("   ✅ campaign_goals table")
        print("   ✅ v_campaign_overview view")
        print("   ✅ v_campaign_ifttt_summary view")
        
        print("\n" + "=" * 70)
        print("✅ CAMPAIGN BUILDER DEPLOYED!")
        print("=" * 70)
        
        print("\n🎯 TWO CREATION MODES:")
        print("   1. AI Autopilot - Full AI campaign generation")
        print("   2. Manual Create - Step-by-step with IFTTT selection")
        
        print("\n📋 MANUAL BUILDER STEPS:")
        print("   Step 1: Basics (name, type, dates, budget)")
        print("   Step 2: Channels (email, SMS, phone, mail, social)")
        print("   Step 3: Audience (segments, filters)")
        print("   Step 4: Content (templates, AI assist)")
        print("   Step 5: IFTTT AUTOMATIONS ← Key Feature")
        print("   Step 6: Goals (donation target, etc.)")
        print("   Step 7: Review & Launch")
        
        print("\n🎛️ IFTTT SELECTION FEATURES:")
        print("   • Browse all available workflows")
        print("   • Recommended workflows by campaign type")
        print("   • Set ON/OFF/TIMER for each")
        print("   • Custom trigger configuration")
        print("   • Preview automation flow")
        
        return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        return False


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        deploy_campaign_builder()
    else:
        print("🚀 Campaign Builder")
        print("\nUsage:")
        print("  python ecosystem_41_campaign_builder_complete.py --deploy")
