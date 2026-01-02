#!/usr/bin/env python3
"""
================================================================================
MASTER COMMUNICATION ORCHESTRATOR - E00 INTELLIGENCE HUB COMMAND CENTER
================================================================================
Central orchestration layer connecting E00 Intelligence Hub to ALL communication
ecosystems for coordinated multi-channel deployment.

COMMUNICATION CHANNELS (18 Total):
┌─────────────────────────────────────────────────────────────────────────────┐
│                     E00 INTELLIGENCE HUB (BRAIN)                            │
│              Orchestrates ALL Communication Deployments                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    │           DIGITAL             │           VOICE               │
    ├───────────────────────────────┼───────────────────────────────┤
    │ E30 Email                     │ E17 RVM (Ringless Voicemail)  │
    │ E31 SMS/MMS                   │ E32 Phone Banking             │
    │ E19 Social Media              │ E16 TV/Radio Ads              │
    │ E36 Messenger (FB/WhatsApp)   │ E16b Voice Synthesis          │
    │ E52 Portal Messaging          │ E47 AI Voice Scripts          │
    │ E43 Advocacy Alerts           │ E46 Live Broadcast            │
    └───────────────────────────────┼───────────────────────────────┘
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    │           PRINT               │           VIDEO               │
    ├───────────────────────────────┼───────────────────────────────┤
    │ E33 Direct Mail               │ E45 Video Studio              │
    │ E14 Print Production          │ E46 Broadcast Hub             │
    │ E18 Print Advertising         │ E50 GPU Video Processing      │
    │ E18 VDP (Variable Data)       │ E23 3D Creative Assets        │
    └───────────────────────────────┴───────────────────────────────┘
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    │       CONTENT GENERATION      │       AUDIENCE TARGETING      │
    ├───────────────────────────────┼───────────────────────────────┤
    │ E09 Content Creation AI       │ E01 Donor Intelligence        │
    │ E47 AI Script Generator       │ E04 Activist Network          │
    │ E48 Communication DNA         │ E05 Volunteer Management      │
    │ E08 Communications Library    │ E21 ML Clustering             │
    └───────────────────────────────┴───────────────────────────────┘
                                    │
                        ┌───────────┴───────────┐
                        │ E54 CALENDAR          │
                        │ Schedule/Immediate    │
                        └───────────────────────┘

Development Value: \$100,000
================================================================================
"""

import json
import logging
import uuid
import asyncio
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Set, Union
from dataclasses import dataclass, field
from enum import Enum
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('master_communication_orchestrator')

# ============================================================================
# CHANNEL DEFINITIONS
# ============================================================================

class CommunicationChannel(Enum):
    """All 18 communication channels available in BroyhillGOP."""
    # Digital
    EMAIL = 'email'                    # E30
    SMS = 'sms'                        # E31
    MMS = 'mms'                        # E31
    SOCIAL_FACEBOOK = 'social_fb'     # E19
    SOCIAL_TWITTER = 'social_twitter' # E19
    SOCIAL_INSTAGRAM = 'social_ig'    # E19
    MESSENGER_FB = 'messenger_fb'     # E36
    MESSENGER_WHATSAPP = 'whatsapp'   # E36
    PORTAL_MESSAGE = 'portal_msg'     # E52
    PUSH_NOTIFICATION = 'push'        # E43
    
    # Voice
    RVM = 'rvm'                        # E17
    PHONE_BANK = 'phone_bank'         # E32
    ROBOCALL = 'robocall'             # E32
    LIVE_CALL = 'live_call'           # E32
    TV_AD = 'tv_ad'                   # E16
    RADIO_AD = 'radio_ad'             # E16
    
    # Print
    DIRECT_MAIL = 'direct_mail'       # E33
    POSTCARD = 'postcard'             # E33
    LETTER = 'letter'                 # E33
    PRINT_AD = 'print_ad'             # E18
    DOOR_HANGER = 'door_hanger'       # E14
    PALM_CARD = 'palm_card'           # E14
    YARD_SIGN = 'yard_sign'           # E14
    
    # Video/Broadcast
    VIDEO_AD = 'video_ad'             # E45
    LIVE_STREAM = 'live_stream'       # E46
    YOUTUBE_AD = 'youtube_ad'         # E45
    OTT_AD = 'ott_ad'                 # E16 (streaming TV)

class AudienceSegment(Enum):
    """Audience segments for targeting."""
    ALL = 'all'
    DONORS = 'donors'
    DONORS_MAJOR = 'donors_major'
    DONORS_LAPSED = 'donors_lapsed'
    VOLUNTEERS = 'volunteers'
    VOLUNTEERS_ACTIVE = 'volunteers_active'
    ACTIVISTS = 'activists'
    VETERANS = 'veterans'
    SENIORS = 'seniors'
    YOUNG_VOTERS = 'young_voters'
    WOMEN = 'women'
    MEN = 'men'
    PARENTS = 'parents'
    BUSINESS_OWNERS = 'business_owners'
    HEALTHCARE_WORKERS = 'healthcare_workers'
    EDUCATORS = 'educators'
    FIRST_RESPONDERS = 'first_responders'
    FAITH_COMMUNITY = 'faith_community'
    RURAL = 'rural'
    URBAN = 'urban'
    SUBURBAN = 'suburban'
    REPUBLICAN = 'republican'
    INDEPENDENT = 'independent'
    COUNTY_SPECIFIC = 'county_specific'
    DISTRICT_SPECIFIC = 'district_specific'
    CUSTOM = 'custom'

class DeploymentPriority(Enum):
    IMMEDIATE = 'immediate'     # Deploy NOW
    HIGH = 'high'               # Within 1 hour
    MEDIUM = 'medium'           # Within 4 hours
    LOW = 'low'                 # Within 24 hours
    SCHEDULED = 'scheduled'     # Use E54 Calendar time

class ContentType(Enum):
    CRISIS_RESPONSE = 'crisis_response'
    FUNDRAISING_APPEAL = 'fundraising_appeal'
    EVENT_INVITATION = 'event_invitation'
    EVENT_REMINDER = 'event_reminder'
    VOTER_OUTREACH = 'voter_outreach'
    GOTV = 'gotv'
    THANK_YOU = 'thank_you'
    ISSUE_ADVOCACY = 'issue_advocacy'
    ATTACK_RESPONSE = 'attack_response'
    ENDORSEMENT = 'endorsement'
    ANNOUNCEMENT = 'announcement'
    NEWSLETTER = 'newsletter'
    SURVEY = 'survey'
    PETITION = 'petition'
    VOLUNTEER_RECRUITMENT = 'volunteer_recruitment'
    DONATION_RECEIPT = 'donation_receipt'
    CUSTOM = 'custom'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class ChannelConfig:
    """Configuration for a communication channel."""
    channel: CommunicationChannel
    ecosystem: str  # E30, E31, etc.
    redis_channel: str
    supports_personalization: bool = True
    supports_scheduling: bool = True
    supports_attachments: bool = False
    max_length: Optional[int] = None
    cost_per_unit: float = 0.0
    requires_opt_in: bool = True

@dataclass
class AudienceQuery:
    """Query to select audience from ecosystems."""
    segments: List[AudienceSegment] = field(default_factory=list)
    counties: List[str] = field(default_factory=list)
    districts: List[str] = field(default_factory=list)
    donor_grades: List[str] = field(default_factory=list)  # A+, A, B+, etc.
    volunteer_grades: List[str] = field(default_factory=list)
    min_donation_amount: Optional[float] = None
    max_donation_amount: Optional[float] = None
    has_email: bool = False
    has_phone: bool = False
    has_address: bool = False
    custom_sql: Optional[str] = None
    exclude_ids: List[str] = field(default_factory=list)

@dataclass
class ContentPackage:
    """Content to be deployed across channels."""
    package_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    content_type: ContentType = ContentType.CUSTOM
    
    # Core content
    subject: str = ''
    headline: str = ''
    body: str = ''
    call_to_action: str = ''
    
    # Channel-specific content
    email_html: Optional[str] = None
    email_plain: Optional[str] = None
    sms_text: Optional[str] = None
    mms_media_url: Optional[str] = None
    rvm_script: Optional[str] = None
    rvm_audio_url: Optional[str] = None
    phone_script: Optional[str] = None
    social_post: Optional[str] = None
    video_url: Optional[str] = None
    print_pdf_url: Optional[str] = None
    
    # Candidate assets
    candidate_photo_url: Optional[str] = None
    candidate_voice_id: Optional[str] = None
    candidate_signature_url: Optional[str] = None
    
    # Personalization tokens
    personalization_fields: List[str] = field(default_factory=list)
    
    # Communication DNA
    use_candidate_dna: bool = True
    tone: str = 'authentic'
    
    created_at: datetime = field(default_factory=datetime.now)

@dataclass
class DeploymentRequest:
    """Request to deploy communication across channels."""
    request_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    
    # Content
    content: ContentPackage = field(default_factory=ContentPackage)
    
    # Channels
    channels: List[CommunicationChannel] = field(default_factory=list)
    
    # Audience
    audience: AudienceQuery = field(default_factory=AudienceQuery)
    
    # Timing
    priority: DeploymentPriority = DeploymentPriority.MEDIUM
    scheduled_start: Optional[datetime] = None
    scheduled_end: Optional[datetime] = None
    
    # Options
    use_ab_testing: bool = False
    ab_test_variants: int = 2
    require_approval: bool = False
    
    # Metadata
    created_by: str = ''
    created_at: datetime = field(default_factory=datetime.now)
    
    # Status
    status: str = 'pending'
    approved_by: Optional[str] = None
    approved_at: Optional[datetime] = None

@dataclass
class DeploymentResult:
    """Result of a deployment execution."""
    request_id: str = ''
    channel: CommunicationChannel = CommunicationChannel.EMAIL
    
    # Counts
    total_targeted: int = 0
    total_sent: int = 0
    total_delivered: int = 0
    total_failed: int = 0
    total_opted_out: int = 0
    
    # Cost
    estimated_cost: float = 0.0
    
    # Timing
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    
    # Status
    status: str = 'pending'
    error_message: Optional[str] = None

# ============================================================================
# CHANNEL REGISTRY
# ============================================================================

CHANNEL_REGISTRY: Dict[CommunicationChannel, ChannelConfig] = {
    # Digital Channels
    CommunicationChannel.EMAIL: ChannelConfig(
        channel=CommunicationChannel.EMAIL,
        ecosystem='E30',
        redis_channel='e30:email:send',
        supports_attachments=True,
        max_length=None,
        cost_per_unit=0.001
    ),
    CommunicationChannel.SMS: ChannelConfig(
        channel=CommunicationChannel.SMS,
        ecosystem='E31',
        redis_channel='e31:sms:send',
        max_length=160,
        cost_per_unit=0.0075  # Bandwidth rate
    ),
    CommunicationChannel.MMS: ChannelConfig(
        channel=CommunicationChannel.MMS,
        ecosystem='E31',
        redis_channel='e31:mms:send',
        supports_attachments=True,
        max_length=1600,
        cost_per_unit=0.02
    ),
    CommunicationChannel.RVM: ChannelConfig(
        channel=CommunicationChannel.RVM,
        ecosystem='E17',
        redis_channel='e17:rvm:drop',
        max_length=None,  # Audio length
        cost_per_unit=0.004  # Drop Cowboy rate
    ),
    CommunicationChannel.PHONE_BANK: ChannelConfig(
        channel=CommunicationChannel.PHONE_BANK,
        ecosystem='E32',
        redis_channel='e32:phonebank:call',
        cost_per_unit=0.05
    ),
    CommunicationChannel.ROBOCALL: ChannelConfig(
        channel=CommunicationChannel.ROBOCALL,
        ecosystem='E32',
        redis_channel='e32:robocall:send',
        cost_per_unit=0.02
    ),
    CommunicationChannel.DIRECT_MAIL: ChannelConfig(
        channel=CommunicationChannel.DIRECT_MAIL,
        ecosystem='E33',
        redis_channel='e33:directmail:queue',
        supports_scheduling=True,
        cost_per_unit=0.75
    ),
    CommunicationChannel.POSTCARD: ChannelConfig(
        channel=CommunicationChannel.POSTCARD,
        ecosystem='E33',
        redis_channel='e33:postcard:queue',
        cost_per_unit=0.45
    ),
    CommunicationChannel.SOCIAL_FACEBOOK: ChannelConfig(
        channel=CommunicationChannel.SOCIAL_FACEBOOK,
        ecosystem='E19',
        redis_channel='e19:social:post',
        max_length=63206,
        cost_per_unit=0.0
    ),
    CommunicationChannel.SOCIAL_TWITTER: ChannelConfig(
        channel=CommunicationChannel.SOCIAL_TWITTER,
        ecosystem='E19',
        redis_channel='e19:social:post',
        max_length=280,
        cost_per_unit=0.0
    ),
    CommunicationChannel.SOCIAL_INSTAGRAM: ChannelConfig(
        channel=CommunicationChannel.SOCIAL_INSTAGRAM,
        ecosystem='E19',
        redis_channel='e19:social:post',
        max_length=2200,
        cost_per_unit=0.0
    ),
    CommunicationChannel.MESSENGER_FB: ChannelConfig(
        channel=CommunicationChannel.MESSENGER_FB,
        ecosystem='E36',
        redis_channel='e36:messenger:send',
        max_length=2000,
        cost_per_unit=0.0
    ),
    CommunicationChannel.MESSENGER_WHATSAPP: ChannelConfig(
        channel=CommunicationChannel.MESSENGER_WHATSAPP,
        ecosystem='E36',
        redis_channel='e36:whatsapp:send',
        max_length=4096,
        cost_per_unit=0.005
    ),
    CommunicationChannel.PORTAL_MESSAGE: ChannelConfig(
        channel=CommunicationChannel.PORTAL_MESSAGE,
        ecosystem='E52',
        redis_channel='e52:portal:notify',
        cost_per_unit=0.0
    ),
    CommunicationChannel.PUSH_NOTIFICATION: ChannelConfig(
        channel=CommunicationChannel.PUSH_NOTIFICATION,
        ecosystem='E43',
        redis_channel='e43:push:send',
        max_length=256,
        cost_per_unit=0.0
    ),
    CommunicationChannel.VIDEO_AD: ChannelConfig(
        channel=CommunicationChannel.VIDEO_AD,
        ecosystem='E45',
        redis_channel='e45:video:deploy',
        cost_per_unit=0.10
    ),
    CommunicationChannel.LIVE_STREAM: ChannelConfig(
        channel=CommunicationChannel.LIVE_STREAM,
        ecosystem='E46',
        redis_channel='e46:broadcast:start',
        cost_per_unit=0.0
    ),
    CommunicationChannel.TV_AD: ChannelConfig(
        channel=CommunicationChannel.TV_AD,
        ecosystem='E16',
        redis_channel='e16:tv:schedule',
        cost_per_unit=500.0  # Per spot
    ),
    CommunicationChannel.RADIO_AD: ChannelConfig(
        channel=CommunicationChannel.RADIO_AD,
        ecosystem='E16',
        redis_channel='e16:radio:schedule',
        cost_per_unit=50.0  # Per spot
    ),
    CommunicationChannel.PRINT_AD: ChannelConfig(
        channel=CommunicationChannel.PRINT_AD,
        ecosystem='E18',
        redis_channel='e18:print:queue',
        cost_per_unit=200.0
    ),
    CommunicationChannel.DOOR_HANGER: ChannelConfig(
        channel=CommunicationChannel.DOOR_HANGER,
        ecosystem='E14',
        redis_channel='e14:print:queue',
        cost_per_unit=0.15
    ),
    CommunicationChannel.PALM_CARD: ChannelConfig(
        channel=CommunicationChannel.PALM_CARD,
        ecosystem='E14',
        redis_channel='e14:print:queue',
        cost_per_unit=0.08
    ),
}

# ============================================================================
# MASTER ORCHESTRATOR
# ============================================================================

class MasterCommunicationOrchestrator:
    """
    Central orchestration engine connecting E00 Intelligence Hub
    to ALL communication ecosystems.
    """
    
    def __init__(self, redis_client, supabase_client=None):
        self.redis = redis_client
        self.supabase = supabase_client
        self.pending_deployments: Dict[str, DeploymentRequest] = {}
        self.deployment_results: Dict[str, List[DeploymentResult]] = defaultdict(list)
    
    # =========================================================================
    # E00 INTELLIGENCE HUB INTERFACE
    # =========================================================================
    
    async def receive_hub_command(self, command: Dict[str, Any]):
        """
        Receive deployment command from E00 Intelligence Hub.
        This is the BRAIN telling us to deploy communications.
        """
        action = command.get('action')
        
        if action == 'deploy_multichannel':
            return await self.deploy_multichannel(command)
        elif action == 'deploy_crisis_response':
            return await self.deploy_crisis_response(command)
        elif action == 'schedule_campaign':
            return await self.schedule_campaign(command)
        elif action == 'cancel_deployment':
            return await self.cancel_deployment(command.get('request_id'))
        elif action == 'get_deployment_status':
            return await self.get_deployment_status(command.get('request_id'))
        
        logger.warning(f"Unknown hub command: {action}")
        return None
    
    async def notify_hub(self, event_type: str, data: Dict[str, Any]):
        """Notify E00 Intelligence Hub of orchestrator events."""
        payload = {
            'source': 'MasterCommunicationOrchestrator',
            'event_type': event_type,
            'timestamp': datetime.now().isoformat(),
            'data': data
        }
        await self.redis.publish('e00:intelligence:communications', json.dumps(payload))
    
    # =========================================================================
    # MULTI-CHANNEL DEPLOYMENT
    # =========================================================================
    
    async def deploy_multichannel(
        self,
        request: Union[DeploymentRequest, Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Deploy content across multiple channels simultaneously.
        This is the core orchestration method.
        """
        if isinstance(request, dict):
            request = self._dict_to_deployment_request(request)
        
        logger.info(f"Starting multi-channel deployment {request.request_id}")
        logger.info(f"Channels: {[c.value for c in request.channels]}")
        
        # Store request
        self.pending_deployments[request.request_id] = request
        
        # Notify hub of deployment start
        await self.notify_hub('deployment_started', {
            'request_id': request.request_id,
            'channels': [c.value for c in request.channels],
            'candidate_id': request.candidate_id
        })
        
        results = []
        
        # 1. Get audience from targeting ecosystems
        audience_list = await self._get_audience(request.audience, request.candidate_id)
        logger.info(f"Audience size: {len(audience_list)}")
        
        # 2. Generate content for each channel (using E47, E48, E09)
        channel_content = await self._generate_channel_content(
            request.content,
            request.channels,
            request.candidate_id
        )
        
        # 3. Check scheduling
        if request.priority == DeploymentPriority.SCHEDULED and request.scheduled_start:
            # Schedule via E54 Calendar
            await self._schedule_deployment(request)
            return {
                'request_id': request.request_id,
                'status': 'scheduled',
                'scheduled_start': request.scheduled_start.isoformat(),
                'channels': [c.value for c in request.channels],
                'audience_size': len(audience_list)
            }
        
        # 4. Deploy to each channel
        for channel in request.channels:
            result = await self._deploy_to_channel(
                channel=channel,
                content=channel_content.get(channel, request.content),
                audience=audience_list,
                request=request
            )
            results.append(result)
            self.deployment_results[request.request_id].append(result)
        
        # 5. Calculate totals
        total_sent = sum(r.total_sent for r in results)
        total_cost = sum(r.estimated_cost for r in results)
        
        # 6. Notify hub of completion
        await self.notify_hub('deployment_completed', {
            'request_id': request.request_id,
            'total_sent': total_sent,
            'total_cost': total_cost,
            'channel_results': [
                {'channel': r.channel.value, 'sent': r.total_sent, 'cost': r.estimated_cost}
                for r in results
            ]
        })
        
        # 7. Log to E10 Compliance
        await self._log_to_compliance(request, results)
        
        # 8. Log to E11 Budget
        await self._log_to_budget(request, total_cost)
        
        request.status = 'completed'
        
        return {
            'request_id': request.request_id,
            'status': 'completed',
            'total_sent': total_sent,
            'total_cost': total_cost,
            'results': [
                {
                    'channel': r.channel.value,
                    'sent': r.total_sent,
                    'delivered': r.total_delivered,
                    'failed': r.total_failed,
                    'cost': r.estimated_cost
                }
                for r in results
            ]
        }
    
    async def deploy_crisis_response(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """
        Special high-priority deployment for crisis situations.
        E00 Hub calls this for immediate multi-channel crisis response.
        """
        candidate_id = command.get('candidate_id')
        crisis_type = command.get('crisis_type')
        subject = command.get('subject')
        message = command.get('message')
        audience_segments = command.get('audience_segments', ['all'])
        channels = command.get('channels', ['sms', 'email', 'rvm'])
        
        logger.info(f"CRISIS RESPONSE: {crisis_type} - deploying to {channels}")
        
        # Build deployment request
        request = DeploymentRequest(
            candidate_id=candidate_id,
            content=ContentPackage(
                content_type=ContentType.CRISIS_RESPONSE,
                subject=subject,
                headline=subject,
                body=message,
                call_to_action=command.get('call_to_action', 'Learn more'),
                use_candidate_dna=True
            ),
            channels=[CommunicationChannel(c) for c in channels],
            audience=AudienceQuery(
                segments=[AudienceSegment(s) for s in audience_segments],
                counties=command.get('counties', []),
                has_email='email' in channels,
                has_phone='sms' in channels or 'rvm' in channels
            ),
            priority=DeploymentPriority.IMMEDIATE,
            created_by='E00_Intelligence_Hub'
        )
        
        # Generate voice/video if requested
        if command.get('generate_voice'):
            request.content.rvm_script = await self._generate_voice_script(
                candidate_id, subject, message
            )
            request.content.rvm_audio_url = await self._generate_voice_audio(
                candidate_id, request.content.rvm_script
            )
        
        if command.get('generate_video'):
            request.content.video_url = await self._generate_video(
                candidate_id, subject, message,
                command.get('candidate_photo_url')
            )
        
        return await self.deploy_multichannel(request)
    
    # =========================================================================
    # AUDIENCE TARGETING
    # =========================================================================
    
    async def _get_audience(
        self,
        query: AudienceQuery,
        candidate_id: str
    ) -> List[Dict[str, Any]]:
        """
        Get audience list from targeting ecosystems (E01, E04, E05).
        """
        audience = []
        
        # Request from E01 Donor Intelligence
        if AudienceSegment.DONORS in query.segments or 
           AudienceSegment.DONORS_MAJOR in query.segments or 
           query.donor_grades:
            donors = await self._query_donors(query, candidate_id)
            audience.extend(donors)
        
        # Request from E05 Volunteer Management
        if AudienceSegment.VOLUNTEERS in query.segments or 
           AudienceSegment.VOLUNTEERS_ACTIVE in query.segments:
            volunteers = await self._query_volunteers(query, candidate_id)
            audience.extend(volunteers)
        
        # Request from E04 Activist Network
        if AudienceSegment.ACTIVISTS in query.segments:
            activists = await self._query_activists(query, candidate_id)
            audience.extend(activists)
        
        # Segment-specific queries
        segment_queries = {
            AudienceSegment.VETERANS: "is_veteran = true",
            AudienceSegment.SENIORS: "age >= 65",
            AudienceSegment.YOUNG_VOTERS: "age BETWEEN 18 AND 35",
            AudienceSegment.WOMEN: "gender = 'F'",
            AudienceSegment.MEN: "gender = 'M'",
            AudienceSegment.PARENTS: "has_children = true",
            AudienceSegment.BUSINESS_OWNERS: "is_business_owner = true",
            AudienceSegment.HEALTHCARE_WORKERS: "occupation_category = 'healthcare'",
            AudienceSegment.EDUCATORS: "occupation_category = 'education'",
            AudienceSegment.FIRST_RESPONDERS: "is_first_responder = true",
            AudienceSegment.FAITH_COMMUNITY: "faith_affiliation IS NOT NULL",
            AudienceSegment.RURAL: "area_type = 'rural'",
            AudienceSegment.URBAN: "area_type = 'urban'",
            AudienceSegment.SUBURBAN: "area_type = 'suburban'",
        }
        
        for segment in query.segments:
            if segment in segment_queries and segment not in [
                AudienceSegment.DONORS, AudienceSegment.VOLUNTEERS, 
                AudienceSegment.ACTIVISTS, AudienceSegment.ALL
            ]:
                segment_audience = await self._query_segment(
                    segment_queries[segment], query, candidate_id
                )
                audience.extend(segment_audience)
        
        # ALL segment - get everyone
        if AudienceSegment.ALL in query.segments:
            all_contacts = await self._query_all_contacts(query, candidate_id)
            audience = all_contacts
        
        # County filter
        if query.counties:
            audience = [a for a in audience if a.get('county') in query.counties]
        
        # Contact info filters
        if query.has_email:
            audience = [a for a in audience if a.get('email')]
        if query.has_phone:
            audience = [a for a in audience if a.get('phone')]
        if query.has_address:
            audience = [a for a in audience if a.get('address')]
        
        # Exclude IDs
        if query.exclude_ids:
            audience = [a for a in audience if a.get('id') not in query.exclude_ids]
        
        # Deduplicate
        seen_ids = set()
        unique_audience = []
        for person in audience:
            if person.get('id') not in seen_ids:
                seen_ids.add(person.get('id'))
                unique_audience.append(person)
        
        return unique_audience
    
    async def _query_donors(self, query: AudienceQuery, candidate_id: str) -> List[Dict]:
        """Query E01 Donor Intelligence for donors."""
        payload = {
            'action': 'query_donors',
            'candidate_id': candidate_id,
            'grades': query.donor_grades or ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-'],
            'min_amount': query.min_donation_amount,
            'max_amount': query.max_donation_amount,
            'counties': query.counties
        }
        
        # In production, this would be async request/response
        # For now, publish and expect response on callback channel
        await self.redis.publish('e01:donor:query', json.dumps(payload))
        
        # Simulated response - in production use Redis response pattern
        return []  # Populated by E01 response
    
    async def _query_volunteers(self, query: AudienceQuery, candidate_id: str) -> List[Dict]:
        """Query E05 Volunteer Management for volunteers."""
        payload = {
            'action': 'query_volunteers',
            'candidate_id': candidate_id,
            'grades': query.volunteer_grades,
            'active_only': AudienceSegment.VOLUNTEERS_ACTIVE in query.segments,
            'counties': query.counties
        }
        await self.redis.publish('e05:volunteer:query', json.dumps(payload))
        return []
    
    async def _query_activists(self, query: AudienceQuery, candidate_id: str) -> List[Dict]:
        """Query E04 Activist Network for activists."""
        payload = {
            'action': 'query_activists',
            'candidate_id': candidate_id,
            'counties': query.counties
        }
        await self.redis.publish('e04:activist:query', json.dumps(payload))
        return []
    
    async def _query_segment(
        self,
        sql_condition: str,
        query: AudienceQuery,
        candidate_id: str
    ) -> List[Dict]:
        """Query specific segment from unified contacts."""
        if not self.supabase:
            return []
        
        try:
            result = await self.supabase.rpc('query_contacts_segment', {
                'p_candidate_id': candidate_id,
                'p_condition': sql_condition,
                'p_counties': query.counties or []
            }).execute()
            return result.data or []
        except Exception as e:
            logger.error(f"Segment query failed: {e}")
            return []
    
    async def _query_all_contacts(self, query: AudienceQuery, candidate_id: str) -> List[Dict]:
        """Get all contacts for candidate."""
        if not self.supabase:
            return []
        
        try:
            result = await self.supabase.table('unified_contacts').select(
                'id, first_name, last_name, email, phone, address, city, state, zip, county'
            ).eq('candidate_id', candidate_id).execute()
            return result.data or []
        except Exception as e:
            logger.error(f"All contacts query failed: {e}")
            return []
    
    # =========================================================================
    # CONTENT GENERATION
    # =========================================================================
    
    async def _generate_channel_content(
        self,
        base_content: ContentPackage,
        channels: List[CommunicationChannel],
        candidate_id: str
    ) -> Dict[CommunicationChannel, ContentPackage]:
        """
        Generate channel-specific content using E47, E48, E09.
        """
        content_map = {}
        
        # Get Communication DNA from E48
        dna = await self._get_communication_dna(candidate_id)
        
        for channel in channels:
            channel_content = ContentPackage(
                package_id=str(uuid.uuid4()),
                content_type=base_content.content_type,
                subject=base_content.subject,
                headline=base_content.headline,
                body=base_content.body,
                call_to_action=base_content.call_to_action,
                candidate_photo_url=base_content.candidate_photo_url,
                candidate_voice_id=base_content.candidate_voice_id
            )
            
            # Generate channel-specific content
            if channel == CommunicationChannel.EMAIL:
                channel_content.email_html = await self._generate_email_html(
                    base_content, dna, candidate_id
                )
                channel_content.email_plain = base_content.body
                
            elif channel == CommunicationChannel.SMS:
                channel_content.sms_text = await self._generate_sms_text(
                    base_content, dna, max_length=160
                )
                
            elif channel == CommunicationChannel.RVM:
                channel_content.rvm_script = await self._generate_voice_script(
                    candidate_id, base_content.subject, base_content.body
                )
                channel_content.rvm_audio_url = await self._generate_voice_audio(
                    candidate_id, channel_content.rvm_script
                )
                
            elif channel in [CommunicationChannel.SOCIAL_FACEBOOK, 
                            CommunicationChannel.SOCIAL_TWITTER,
                            CommunicationChannel.SOCIAL_INSTAGRAM]:
                config = CHANNEL_REGISTRY.get(channel)
                max_len = config.max_length if config else 280
                channel_content.social_post = await self._generate_social_post(
                    base_content, channel, max_len
                )
            
            content_map[channel] = channel_content
        
        return content_map
    
    async def _get_communication_dna(self, candidate_id: str) -> Dict[str, Any]:
        """Get candidate's Communication DNA from E48."""
        payload = {
            'action': 'get_dna',
            'candidate_id': candidate_id
        }
        await self.redis.publish('e48:dna:get', json.dumps(payload))
        
        # Default DNA if not available
        return {
            'tone': 'authentic',
            'formality': 'conversational',
            'voice_style': 'warm',
            'greeting': 'personal'
        }
    
    async def _generate_email_html(
        self,
        content: ContentPackage,
        dna: Dict,
        candidate_id: str
    ) -> str:
        """Generate HTML email using E09 Content Creation AI."""
        payload = {
            'action': 'generate_email',
            'candidate_id': candidate_id,
            'subject': content.subject,
            'body': content.body,
            'cta': content.call_to_action,
            'dna': dna
        }
        await self.redis.publish('e09:content:generate', json.dumps(payload))
        
        # Return basic HTML template (E09 would enhance)
        return f"""
        <html>
        <body style="font-family: Georgia, serif; max-width: 600px; margin: 0 auto;">
            <h1>{content.headline}</h1>
            <p>{content.body}</p>
            <p><a href="#">{content.call_to_action}</a></p>
        </body>
        </html>
        """
    
    async def _generate_sms_text(
        self,
        content: ContentPackage,
        dna: Dict,
        max_length: int = 160
    ) -> str:
        """Generate SMS text within character limit."""
        text = f"{content.headline}: {content.body} {content.call_to_action}"
        if len(text) > max_length:
            text = text[:max_length-3] + "..."
        return text
    
    async def _generate_voice_script(
        self,
        candidate_id: str,
        subject: str,
        body: str
    ) -> str:
        """Generate voice script using E47 AI Script Generator."""
        payload = {
            'action': 'generate_script',
            'candidate_id': candidate_id,
            'script_type': 'rvm',
            'subject': subject,
            'body': body
        }
        await self.redis.publish('e47:script:generate', json.dumps(payload))
        
        # Basic script template
        return f"Hi, this is an important message. {body} Thank you for your support."
    
    async def _generate_voice_audio(
        self,
        candidate_id: str,
        script: str
    ) -> str:
        """Generate voice audio using E16b Voice Synthesis (Chatterbox TTS)."""
        payload = {
            'action': 'synthesize',
            'candidate_id': candidate_id,
            'text': script,
            'voice_id': 'candidate_clone',
            'output_format': 'mp3'
        }
        await self.redis.publish('e16b:voice:synthesize', json.dumps(payload))
        
        # Return URL where audio will be stored
        return f"https://storage.broyhillgop.com/voice/{candidate_id}/{uuid.uuid4()}.mp3"
    
    async def _generate_video(
        self,
        candidate_id: str,
        subject: str,
        body: str,
        photo_url: Optional[str] = None
    ) -> str:
        """Generate video using E45 Video Studio."""
        payload = {
            'action': 'generate_video',
            'candidate_id': candidate_id,
            'type': 'talking_head',
            'subject': subject,
            'script': body,
            'photo_url': photo_url,
            'duration': 60
        }
        await self.redis.publish('e45:video:generate', json.dumps(payload))
        
        return f"https://storage.broyhillgop.com/video/{candidate_id}/{uuid.uuid4()}.mp4"
    
    async def _generate_social_post(
        self,
        content: ContentPackage,
        channel: CommunicationChannel,
        max_length: int
    ) -> str:
        """Generate social media post."""
        post = f"{content.headline}\n\n{content.body}"
        if len(post) > max_length:
            post = post[:max_length-3] + "..."
        return post
    
    # =========================================================================
    # CHANNEL DEPLOYMENT
    # =========================================================================
    
    async def _deploy_to_channel(
        self,
        channel: CommunicationChannel,
        content: ContentPackage,
        audience: List[Dict],
        request: DeploymentRequest
    ) -> DeploymentResult:
        """Deploy content to a specific channel."""
        config = CHANNEL_REGISTRY.get(channel)
        if not config:
            return DeploymentResult(
                request_id=request.request_id,
                channel=channel,
                status='failed',
                error_message=f"Unknown channel: {channel.value}"
            )
        
        result = DeploymentResult(
            request_id=request.request_id,
            channel=channel,
            total_targeted=len(audience),
            started_at=datetime.now()
        )
        
        # Filter audience for channel requirements
        channel_audience = self._filter_audience_for_channel(audience, channel)
        result.total_targeted = len(channel_audience)
        
        # Build channel-specific payload
        payload = self._build_channel_payload(channel, content, channel_audience, request)
        
        # Publish to channel's Redis queue
        try:
            await self.redis.publish(config.redis_channel, json.dumps(payload))
            result.total_sent = len(channel_audience)
            result.estimated_cost = len(channel_audience) * config.cost_per_unit
            result.status = 'sent'
            logger.info(f"Deployed to {channel.value}: {result.total_sent} recipients")
        except Exception as e:
            result.status = 'failed'
            result.error_message = str(e)
            logger.error(f"Failed to deploy to {channel.value}: {e}")
        
        result.completed_at = datetime.now()
        return result
    
    def _filter_audience_for_channel(
        self,
        audience: List[Dict],
        channel: CommunicationChannel
    ) -> List[Dict]:
        """Filter audience to those who can receive via this channel."""
        if channel in [CommunicationChannel.EMAIL]:
            return [a for a in audience if a.get('email')]
        elif channel in [CommunicationChannel.SMS, CommunicationChannel.MMS,
                        CommunicationChannel.RVM, CommunicationChannel.PHONE_BANK,
                        CommunicationChannel.ROBOCALL]:
            return [a for a in audience if a.get('phone')]
        elif channel in [CommunicationChannel.DIRECT_MAIL, CommunicationChannel.POSTCARD,
                        CommunicationChannel.LETTER, CommunicationChannel.DOOR_HANGER]:
            return [a for a in audience if a.get('address')]
        else:
            return audience
    
    def _build_channel_payload(
        self,
        channel: CommunicationChannel,
        content: ContentPackage,
        audience: List[Dict],
        request: DeploymentRequest
    ) -> Dict[str, Any]:
        """Build channel-specific payload for deployment."""
        base_payload = {
            'request_id': request.request_id,
            'candidate_id': request.candidate_id,
            'content_type': content.content_type.value,
            'source': 'MasterCommunicationOrchestrator',
            'timestamp': datetime.now().isoformat()
        }
        
        if channel == CommunicationChannel.EMAIL:
            return {
                **base_payload,
                'recipients': [{'email': a['email'], 'name': f"{a.get('first_name', '')} {a.get('last_name', '')}"} for a in audience],
                'subject': content.subject,
                'html': content.email_html,
                'plain': content.email_plain or content.body
            }
        
        elif channel == CommunicationChannel.SMS:
            return {
                **base_payload,
                'recipients': [a['phone'] for a in audience],
                'message': content.sms_text or content.body[:160]
            }
        
        elif channel == CommunicationChannel.RVM:
            return {
                **base_payload,
                'recipients': [a['phone'] for a in audience],
                'audio_url': content.rvm_audio_url,
                'script': content.rvm_script
            }
        
        elif channel == CommunicationChannel.DIRECT_MAIL:
            return {
                **base_payload,
                'recipients': [
                    {
                        'name': f"{a.get('first_name', '')} {a.get('last_name', '')}",
                        'address': a.get('address'),
                        'city': a.get('city'),
                        'state': a.get('state'),
                        'zip': a.get('zip')
                    }
                    for a in audience
                ],
                'template': 'standard_letter',
                'content': {
                    'headline': content.headline,
                    'body': content.body,
                    'cta': content.call_to_action
                }
            }
        
        elif channel in [CommunicationChannel.SOCIAL_FACEBOOK,
                        CommunicationChannel.SOCIAL_TWITTER,
                        CommunicationChannel.SOCIAL_INSTAGRAM]:
            return {
                **base_payload,
                'platform': channel.value.replace('social_', ''),
                'post': content.social_post or content.body,
                'media_url': content.video_url or content.candidate_photo_url
            }
        
        elif channel == CommunicationChannel.VIDEO_AD:
            return {
                **base_payload,
                'video_url': content.video_url,
                'targeting': {
                    'audience_ids': [a.get('id') for a in audience]
                }
            }
        
        return {**base_payload, 'content': content.body, 'audience_size': len(audience)}
    
    # =========================================================================
    # SCHEDULING (E54 CALENDAR INTEGRATION)
    # =========================================================================
    
    async def _schedule_deployment(self, request: DeploymentRequest):
        """Schedule deployment via E54 Calendar."""
        payload = {
            'action': 'schedule_communication',
            'request_id': request.request_id,
            'candidate_id': request.candidate_id,
            'scheduled_start': request.scheduled_start.isoformat(),
            'scheduled_end': request.scheduled_end.isoformat() if request.scheduled_end else None,
            'channels': [c.value for c in request.channels],
            'content_type': request.content.content_type.value,
            'subject': request.content.subject
        }
        
        await self.redis.publish('e54:calendar:schedule', json.dumps(payload))
        logger.info(f"Scheduled deployment {request.request_id} for {request.scheduled_start}")
    
    async def schedule_campaign(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """
        Schedule a multi-day campaign with E54 Calendar.
        E00 Hub can schedule campaigns spanning days/weeks.
        """
        campaign_id = str(uuid.uuid4())
        candidate_id = command.get('candidate_id')
        start_date = datetime.fromisoformat(command.get('start_date'))
        end_date = datetime.fromisoformat(command.get('end_date'))
        daily_schedule = command.get('daily_schedule', [])  # List of channel/time pairs
        
        scheduled_deployments = []
        current_date = start_date
        
        while current_date <= end_date:
            for schedule_item in daily_schedule:
                deploy_time = datetime.combine(
                    current_date.date(),
                    datetime.strptime(schedule_item['time'], '%H:%M').time()
                )
                
                request = DeploymentRequest(
                    candidate_id=candidate_id,
                    content=ContentPackage(**command.get('content', {})),
                    channels=[CommunicationChannel(c) for c in schedule_item.get('channels', [])],
                    audience=AudienceQuery(**command.get('audience', {})),
                    priority=DeploymentPriority.SCHEDULED,
                    scheduled_start=deploy_time
                )
                
                await self._schedule_deployment(request)
                scheduled_deployments.append({
                    'request_id': request.request_id,
                    'scheduled_time': deploy_time.isoformat(),
                    'channels': schedule_item.get('channels', [])
                })
            
            current_date += timedelta(days=1)
        
        return {
            'campaign_id': campaign_id,
            'total_scheduled': len(scheduled_deployments),
            'start_date': start_date.isoformat(),
            'end_date': end_date.isoformat(),
            'deployments': scheduled_deployments
        }
    
    # =========================================================================
    # COMPLIANCE & BUDGET LOGGING
    # =========================================================================
    
    async def _log_to_compliance(
        self,
        request: DeploymentRequest,
        results: List[DeploymentResult]
    ):
        """Log deployment to E10 Compliance Manager."""
        payload = {
            'action': 'log_communication',
            'request_id': request.request_id,
            'candidate_id': request.candidate_id,
            'content_type': request.content.content_type.value,
            'channels': [c.value for c in request.channels],
            'total_sent': sum(r.total_sent for r in results),
            'timestamp': datetime.now().isoformat()
        }
        await self.redis.publish('e10:compliance:log', json.dumps(payload))
    
    async def _log_to_budget(self, request: DeploymentRequest, total_cost: float):
        """Log deployment cost to E11 Budget Management."""
        payload = {
            'action': 'log_expense',
            'candidate_id': request.candidate_id,
            'category': 'communications',
            'subcategory': request.content.content_type.value,
            'amount': total_cost,
            'description': f"Multi-channel deployment: {request.content.subject}",
            'request_id': request.request_id,
            'timestamp': datetime.now().isoformat()
        }
        await self.redis.publish('e11:budget:expense', json.dumps(payload))
    
    # =========================================================================
    # STATUS & MANAGEMENT
    # =========================================================================
    
    async def get_deployment_status(self, request_id: str) -> Dict[str, Any]:
        """Get status of a deployment."""
        request = self.pending_deployments.get(request_id)
        results = self.deployment_results.get(request_id, [])
        
        if not request:
            return {'error': 'Deployment not found'}
        
        return {
            'request_id': request_id,
            'status': request.status,
            'channels': [c.value for c in request.channels],
            'created_at': request.created_at.isoformat(),
            'results': [
                {
                    'channel': r.channel.value,
                    'status': r.status,
                    'sent': r.total_sent,
                    'delivered': r.total_delivered,
                    'failed': r.total_failed,
                    'cost': r.estimated_cost
                }
                for r in results
            ]
        }
    
    async def cancel_deployment(self, request_id: str) -> bool:
        """Cancel a pending/scheduled deployment."""
        request = self.pending_deployments.get(request_id)
        if not request:
            return False
        
        if request.status in ['completed', 'cancelled']:
            return False
        
        request.status = 'cancelled'
        
        # Notify calendar to cancel scheduled items
        await self.redis.publish('e54:calendar:cancel', json.dumps({
            'request_id': request_id
        }))
        
        logger.info(f"Cancelled deployment {request_id}")
        return True
    
    def _dict_to_deployment_request(self, data: Dict[str, Any]) -> DeploymentRequest:
        """Convert dictionary to DeploymentRequest."""
        content_data = data.get('content', {})
        audience_data = data.get('audience', {})
        
        return DeploymentRequest(
            candidate_id=data.get('candidate_id', ''),
            content=ContentPackage(
                content_type=ContentType(content_data.get('content_type', 'custom')),
                subject=content_data.get('subject', ''),
                headline=content_data.get('headline', ''),
                body=content_data.get('body', ''),
                call_to_action=content_data.get('call_to_action', ''),
                candidate_photo_url=content_data.get('candidate_photo_url'),
                candidate_voice_id=content_data.get('candidate_voice_id')
            ),
            channels=[CommunicationChannel(c) for c in data.get('channels', [])],
            audience=AudienceQuery(
                segments=[AudienceSegment(s) for s in audience_data.get('segments', ['all'])],
                counties=audience_data.get('counties', []),
                donor_grades=audience_data.get('donor_grades', []),
                has_email=audience_data.get('has_email', False),
                has_phone=audience_data.get('has_phone', False),
                has_address=audience_data.get('has_address', False)
            ),
            priority=DeploymentPriority(data.get('priority', 'medium')),
            scheduled_start=datetime.fromisoformat(data['scheduled_start']) if data.get('scheduled_start') else None,
            scheduled_end=datetime.fromisoformat(data['scheduled_end']) if data.get('scheduled_end') else None,
            created_by=data.get('created_by', 'api')
        )

# ============================================================================
# E00 HUB LISTENER
# ============================================================================

class HubCommandListener:
    """Listen for commands from E00 Intelligence Hub."""
    
    def __init__(self, orchestrator: MasterCommunicationOrchestrator, redis_client):
        self.orchestrator = orchestrator
        self.redis = redis_client
        self.is_running = False
    
    async def start(self):
        """Start listening for hub commands."""
        self.is_running = True
        pubsub = self.redis.pubsub()
        await pubsub.subscribe('e00:orchestrator:command')
        
        logger.info("Master Communication Orchestrator: Listening for E00 Hub commands...")
        
        while self.is_running:
            message = await pubsub.get_message(ignore_subscribe_messages=True)
            if message:
                try:
                    command = json.loads(message['data'])
                    result = await self.orchestrator.receive_hub_command(command)
                    
                    # Send response back to hub
                    if result:
                        await self.redis.publish('e00:orchestrator:response', json.dumps(result))
                except Exception as e:
                    logger.error(f"Failed to process hub command: {e}")
            
            await asyncio.sleep(0.1)
    
    async def stop(self):
        self.is_running = False


# ============================================================================
# MAIN / DEMO
# ============================================================================

async def main():
    """Demonstrate the Master Communication Orchestrator."""
    print("="*80)
    print("MASTER COMMUNICATION ORCHESTRATOR - E00 INTELLIGENCE HUB INTEGRATION")
    print("="*80)
    print()
    print("COMMUNICATION CHANNELS (18 Total):"
    print("─"*80)
    print()
    print("DIGITAL CHANNELS:")
    print("  • E30 Email           • E31 SMS/MMS         • E19 Social Media")
    print("  • E36 Messenger       • E52 Portal Messages • E43 Push Notifications")
    print()
    print("VOICE CHANNELS:")
    print("  • E17 RVM (Ringless)  • E32 Phone Banking   • E16 TV/Radio Ads")
    print("  • E16b Voice Synthesis (Chatterbox TTS)")
    print()
    print("PRINT CHANNELS:")
    print("  • E33 Direct Mail     • E14 Print Production • E18 Print Advertising")
    print("  • E18 VDP (Variable Data Printing)")
    print()
    print("VIDEO CHANNELS:")
    print("  • E45 Video Studio    • E46 Live Broadcast  • E50 GPU Processing")
    print()
    print("CONTENT GENERATION:")
    print("  • E09 Content AI      • E47 Script Generator • E48 Communication DNA")
    print()
    print("AUDIENCE TARGETING:")
    print("  • E01 Donor Intelligence  • E04 Activist Network  • E05 Volunteer Mgmt")
    print()
    print("SCHEDULING:")
    print("  • E54 Calendar - Schedule deployments with start/end times")
    print()
    print("─"*80)
    print()
    print("EXAMPLE CRISIS RESPONSE WORKFLOW:")
    print()
    print("1. E00 Hub receives news alert: 'Veteran benefits under threat in Forsyth County'")
    print("2. E00 commands Orchestrator: deploy_crisis_response")
    print("3. Orchestrator:")
    print("   a) Queries E01/E04/E05 for VETERANS segment in Forsyth County")
    print("   b) Commands E47 to generate crisis response script")
    print("   c) Commands E16b to generate candidate voice audio (Chatterbox TTS)")
    print("   d) Commands E45 to generate video with candidate photo")
    print("   e) Deploys simultaneously to:")
    print("      - E30 Email (HTML with video embed)")
    print("      - E31 SMS (short text alert)")
    print("      - E17 RVM (voice message in candidate's cloned voice)")
    print("   f) Logs to E10 Compliance and E11 Budget")
    print("   g) Reports back to E00 Hub")
    print()
    print("Total deployment time: < 5 minutes")
    print()


if __name__ == '__main__':
    asyncio.run(main())
