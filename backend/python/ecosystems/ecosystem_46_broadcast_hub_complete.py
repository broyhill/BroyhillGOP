#!/usr/bin/env python3
"""
================================================================================
ECOSYSTEM 46: BROADCAST HUB - LIVE STREAMING & AUDIENCE ENGAGEMENT
================================================================================
Multi-platform LIVE streaming with text-to-capture (50155), live donations,
reactions, team viral growth, and clip extraction.

This handles LIVE EVENTS only - not production (E16) or recording (E45).
Candidate camera/video enhancement is shared via E45 Video Studio.

Features:
- Multi-platform simulcast (Facebook Live, YouTube Live, Rumble, LinkedIn)
- Text-to-capture (50155 keywords: EDDIE, DONATE, SIGN, VOLUNTEER)
- Live donation integration (QR codes, thermometer, matching gifts)
- Reaction/polling system across platforms
- Team Builder viral growth
- Clip extraction for other ecosystems
- Podcast live recording with interaction

Development Value: $125,000
================================================================================
"""

import os
import json
import logging
import asyncio
import uuid
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import hashlib
import hmac

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem46.broadcast_hub')

# ============================================================================
# ENUMS
# ============================================================================

class Platform(Enum):
    FACEBOOK = 'facebook'
    YOUTUBE = 'youtube'
    RUMBLE = 'rumble'
    LINKEDIN = 'linkedin'
    TWITTER_X = 'twitter_x'
    TWITCH = 'twitch'
    CUSTOM_RTMP = 'custom_rtmp'

class BroadcastStatus(Enum):
    SCHEDULED = 'scheduled'
    PREPARING = 'preparing'
    LIVE = 'live'
    PAUSED = 'paused'
    ENDED = 'ended'
    FAILED = 'failed'

class CaptureKeyword(Enum):
    DONATE = 'DONATE'
    SIGN = 'SIGN'
    VOLUNTEER = 'VOLUNTEER'
    JOIN = 'JOIN'
    VOTE = 'VOTE'
    SHARE = 'SHARE'
    CALL = 'CALL'
    TEXT = 'TEXT'

class ReactionType(Enum):
    LIKE = 'like'
    LOVE = 'love'
    HAHA = 'haha'
    WOW = 'wow'
    SAD = 'sad'
    ANGRY = 'angry'
    FIRE = 'fire'
    CLAP = 'clap'
    USA = 'usa'
    MAGA = 'maga'

class PollType(Enum):
    SINGLE_CHOICE = 'single_choice'
    MULTIPLE_CHOICE = 'multiple_choice'
    SLIDER = 'slider'
    YES_NO = 'yes_no'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class StreamDestination:
    destination_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    platform: Platform = Platform.FACEBOOK
    stream_key: str = ''
    rtmp_url: str = ''
    page_id: Optional[str] = None
    is_active: bool = True
    status: str = 'disconnected'
    viewer_count: int = 0
    error_message: Optional[str] = None

@dataclass
class TextCapture:
    capture_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    broadcast_id: str = ''
    phone_number: str = ''
    keyword: CaptureKeyword = CaptureKeyword.DONATE
    message_text: str = ''
    platform_source: Optional[Platform] = None
    donor_id: Optional[str] = None
    processed: bool = False
    response_sent: bool = False
    captured_at: datetime = field(default_factory=datetime.now)

@dataclass
class LiveDonation:
    donation_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    broadcast_id: str = ''
    donor_name: str = ''
    donor_id: Optional[str] = None
    amount: float = 0.0
    message: Optional[str] = None
    is_matched: bool = False
    match_multiplier: float = 1.0
    platform_source: Platform = Platform.FACEBOOK
    displayed_on_stream: bool = False
    created_at: datetime = field(default_factory=datetime.now)

@dataclass
class LivePoll:
    poll_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    broadcast_id: str = ''
    question: str = ''
    poll_type: PollType = PollType.SINGLE_CHOICE
    options: List[str] = field(default_factory=list)
    votes: Dict[str, int] = field(default_factory=dict)
    is_active: bool = False
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    duration_seconds: int = 60

@dataclass
class ViewerReaction:
    reaction_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    broadcast_id: str = ''
    reaction_type: ReactionType = ReactionType.LIKE
    platform: Platform = Platform.FACEBOOK
    viewer_name: Optional[str] = None
    timestamp: datetime = field(default_factory=datetime.now)

@dataclass
class StreamClip:
    clip_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    broadcast_id: str = ''
    title: str = ''
    start_time_seconds: int = 0
    end_time_seconds: int = 0
    duration_seconds: int = 0
    file_path: Optional[str] = None
    thumbnail_url: Optional[str] = None
    tags: List[str] = field(default_factory=list)
    auto_generated: bool = False
    created_at: datetime = field(default_factory=datetime.now)

@dataclass
class Broadcast:
    broadcast_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    title: str = ''
    description: str = ''
    candidate_id: str = ''
    scheduled_start: datetime = field(default_factory=datetime.now)
    actual_start: Optional[datetime] = None
    actual_end: Optional[datetime] = None
    status: BroadcastStatus = BroadcastStatus.SCHEDULED
    destinations: List[StreamDestination] = field(default_factory=list)
    captures: List[TextCapture] = field(default_factory=list)
    donations: List[LiveDonation] = field(default_factory=list)
    polls: List[LivePoll] = field(default_factory=list)
    reactions: List[ViewerReaction] = field(default_factory=list)
    clips: List[StreamClip] = field(default_factory=list)
    
    # Metrics
    peak_viewers: int = 0
    total_viewers: int = 0
    total_reactions: int = 0
    total_donations: float = 0.0
    total_captures: int = 0
    
    # Settings
    donation_goal: float = 0.0
    matching_enabled: bool = False
    match_multiplier: float = 2.0
    match_cap: float = 10000.0
    
    # Recording
    recording_enabled: bool = True
    recording_path: Optional[str] = None
    
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

# ============================================================================
# BROADCAST HUB CORE
# ============================================================================

class BroadcastHub:
    """Core broadcast hub for multi-platform live streaming."""
    
    # Text-to-capture shortcode
    CAPTURE_SHORTCODE = '50155'
    
    def __init__(self, supabase_client=None, redis_client=None):
        self.supabase = supabase_client
        self.redis = redis_client
        self.broadcasts: Dict[str, Broadcast] = {}
        self.active_broadcast_id: Optional[str] = None
        
        # Callback handlers
        self.on_donation: Optional[Callable] = None
        self.on_capture: Optional[Callable] = None
        self.on_reaction: Optional[Callable] = None
        self.on_viewer_milestone: Optional[Callable] = None
    
    # =========================================================================
    # BROADCAST MANAGEMENT
    # =========================================================================
    
    async def create_broadcast(
        self,
        title: str,
        description: str,
        candidate_id: str,
        scheduled_start: datetime,
        platforms: List[Platform],
        donation_goal: float = 0.0,
        matching_enabled: bool = False,
        match_multiplier: float = 2.0
    ) -> Broadcast:
        """Create a new scheduled broadcast."""
        broadcast = Broadcast(
            title=title,
            description=description,
            candidate_id=candidate_id,
            scheduled_start=scheduled_start,
            donation_goal=donation_goal,
            matching_enabled=matching_enabled,
            match_multiplier=match_multiplier
        )
        
        # Add stream destinations for each platform
        for platform in platforms:
            destination = StreamDestination(
                platform=platform,
                rtmp_url=self._get_rtmp_url(platform)
            )
            broadcast.destinations.append(destination)
        
        self.broadcasts[broadcast.broadcast_id] = broadcast
        
        if self.supabase:
            await self._save_broadcast_to_db(broadcast)
        
        logger.info(f"Created broadcast: {title} scheduled for {scheduled_start}")
        return broadcast
    
    async def start_broadcast(self, broadcast_id: str) -> Broadcast:
        """Start a live broadcast."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast:
            raise ValueError(f"Broadcast {broadcast_id} not found")
        
        broadcast.status = BroadcastStatus.PREPARING
        broadcast.actual_start = datetime.now()
        
        # Initialize stream destinations
        for dest in broadcast.destinations:
            try:
                await self._connect_platform(dest)
                dest.status = 'connected'
            except Exception as e:
                dest.status = 'error'
                dest.error_message = str(e)
                logger.error(f"Failed to connect to {dest.platform.value}: {e}")
        
        # Check if at least one platform connected
        connected = [d for d in broadcast.destinations if d.status == 'connected']
        if not connected:
            broadcast.status = BroadcastStatus.FAILED
            raise Exception("Failed to connect to any streaming platform")
        
        broadcast.status = BroadcastStatus.LIVE
        self.active_broadcast_id = broadcast_id
        
        # Start background tasks
        asyncio.create_task(self._poll_viewer_counts(broadcast))
        asyncio.create_task(self._monitor_reactions(broadcast))
        
        if self.supabase:
            await self._save_broadcast_to_db(broadcast)
        
        logger.info(f"Broadcast LIVE: {broadcast.title} on {len(connected)} platforms")
        return broadcast
    
    async def end_broadcast(self, broadcast_id: str) -> Broadcast:
        """End a live broadcast."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast:
            raise ValueError(f"Broadcast {broadcast_id} not found")
        
        broadcast.status = BroadcastStatus.ENDED
        broadcast.actual_end = datetime.now()
        
        # Disconnect all platforms
        for dest in broadcast.destinations:
            await self._disconnect_platform(dest)
            dest.status = 'disconnected'
        
        if self.active_broadcast_id == broadcast_id:
            self.active_broadcast_id = None
        
        # Calculate final metrics
        broadcast.total_donations = sum(d.amount * (d.match_multiplier if d.is_matched else 1) 
                                        for d in broadcast.donations)
        broadcast.total_captures = len(broadcast.captures)
        broadcast.total_reactions = len(broadcast.reactions)
        
        if self.supabase:
            await self._save_broadcast_to_db(broadcast)
        
        duration = (broadcast.actual_end - broadcast.actual_start).total_seconds() / 60
        logger.info(
            f"Broadcast ENDED: {broadcast.title} - {duration:.1f} min, "
            f"${broadcast.total_donations:,.2f} raised, {broadcast.peak_viewers} peak viewers"
        )
        
        return broadcast
    
    # =========================================================================
    # TEXT-TO-CAPTURE (50155)
    # =========================================================================
    
    async def process_sms_capture(
        self,
        phone_number: str,
        message_text: str,
        broadcast_id: Optional[str] = None
    ) -> Optional[TextCapture]:
        """Process incoming SMS to 50155 shortcode."""
        # Use active broadcast if not specified
        broadcast_id = broadcast_id or self.active_broadcast_id
        if not broadcast_id:
            logger.warning("No active broadcast for SMS capture")
            return None
        
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast or broadcast.status != BroadcastStatus.LIVE:
            return None
        
        # Parse keyword from message
        keyword = self._parse_capture_keyword(message_text)
        if not keyword:
            # Send help response
            await self._send_capture_response(
                phone_number,
                f"Text one of these keywords: DONATE, SIGN, VOLUNTEER, JOIN"
            )
            return None
        
        # Create capture record
        capture = TextCapture(
            broadcast_id=broadcast_id,
            phone_number=phone_number,
            keyword=keyword,
            message_text=message_text
        )
        
        broadcast.captures.append(capture)
        
        # Process based on keyword
        response = await self._process_capture_keyword(capture, broadcast)
        
        # Send response
        await self._send_capture_response(phone_number, response)
        capture.response_sent = True
        capture.processed = True
        
        if self.supabase:
            await self._save_capture_to_db(capture)
        
        # Trigger callback
        if self.on_capture:
            await self.on_capture(capture)
        
        logger.info(f"Processed capture: {keyword.value} from {phone_number[-4:]}")
        return capture
    
    def _parse_capture_keyword(self, message: str) -> Optional[CaptureKeyword]:
        """Parse keyword from SMS message."""
        message_upper = message.strip().upper()
        
        for keyword in CaptureKeyword:
            if message_upper.startswith(keyword.value):
                return keyword
        
        return None
    
    async def _process_capture_keyword(
        self,
        capture: TextCapture,
        broadcast: Broadcast
    ) -> str:
        """Process capture and return response message."""
        responses = {
            CaptureKeyword.DONATE: (
                f"Thank you for supporting {broadcast.title}! "
                f"Donate securely at: https://broyhillgop.com/donate/{broadcast.candidate_id}"
            ),
            CaptureKeyword.SIGN: (
                f"Sign our petition now: https://broyhillgop.com/petition/{broadcast.candidate_id}"
            ),
            CaptureKeyword.VOLUNTEER: (
                f"Join our team! Sign up to volunteer: "
                f"https://broyhillgop.com/volunteer/{broadcast.candidate_id}"
            ),
            CaptureKeyword.JOIN: (
                f"Welcome! You've joined our movement. "
                f"We'll keep you updated on {broadcast.title}."
            ),
            CaptureKeyword.VOTE: (
                f"Find your polling place: https://broyhillgop.com/vote "
                f"Make sure you're registered!"
            ),
            CaptureKeyword.SHARE: (
                f"Share our live stream: https://broyhillgop.com/live/{broadcast.broadcast_id}"
            ),
            CaptureKeyword.CALL: (
                f"Our campaign hotline: (336) 555-VOTE (8683). "
                f"We're here to help!"
            ),
            CaptureKeyword.TEXT: (
                f"You're now subscribed to campaign updates! "
                f"Reply STOP to unsubscribe."
            )
        }
        
        return responses.get(
            capture.keyword,
            f"Thanks for reaching out! Visit https://broyhillgop.com/{broadcast.candidate_id}"
        )
    
    async def _send_capture_response(self, phone_number: str, message: str):
        """Send SMS response via E31 SMS system."""
        # Integration with E31 SMS
        if self.redis:
            await self.redis.publish('e31:sms:send', json.dumps({
                'to': phone_number,
                'message': message,
                'source': 'broadcast_hub'
            }))
        logger.debug(f"Sent capture response to {phone_number[-4:]}")
    
    # =========================================================================
    # LIVE DONATIONS
    # =========================================================================
    
    async def process_donation(
        self,
        broadcast_id: str,
        donor_name: str,
        amount: float,
        message: Optional[str] = None,
        donor_id: Optional[str] = None,
        platform: Platform = Platform.FACEBOOK
    ) -> LiveDonation:
        """Process an incoming live donation."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast:
            raise ValueError(f"Broadcast {broadcast_id} not found")
        
        # Check matching
        is_matched = False
        match_multiplier = 1.0
        
        if broadcast.matching_enabled:
            current_matched = sum(
                d.amount for d in broadcast.donations if d.is_matched
            )
            if current_matched < broadcast.match_cap:
                is_matched = True
                match_multiplier = broadcast.match_multiplier
        
        donation = LiveDonation(
            broadcast_id=broadcast_id,
            donor_name=donor_name,
            donor_id=donor_id,
            amount=amount,
            message=message,
            is_matched=is_matched,
            match_multiplier=match_multiplier,
            platform_source=platform
        )
        
        broadcast.donations.append(donation)
        broadcast.total_donations += amount * match_multiplier
        
        if self.supabase:
            await self._save_donation_to_db(donation)
        
        # Trigger callback for OBS/stream overlay
        if self.on_donation:
            await self.on_donation(donation)
        
        # Publish to Redis for real-time overlay
        if self.redis:
            await self.redis.publish('broadcast:donation', json.dumps({
                'broadcast_id': broadcast_id,
                'donor_name': donor_name,
                'amount': amount,
                'effective_amount': amount * match_multiplier,
                'is_matched': is_matched,
                'message': message,
                'total_raised': broadcast.total_donations,
                'goal': broadcast.donation_goal,
                'goal_pct': (broadcast.total_donations / broadcast.donation_goal * 100) 
                           if broadcast.donation_goal > 0 else 0
            }))
        
        logger.info(
            f"Donation received: ${amount:.2f} from {donor_name} "
            f"{'(MATCHED!)' if is_matched else ''} - Total: ${broadcast.total_donations:,.2f}"
        )
        
        return donation
    
    def get_donation_thermometer(self, broadcast_id: str) -> Dict[str, Any]:
        """Get donation thermometer data for overlay."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast:
            return {}
        
        return {
            'total_raised': broadcast.total_donations,
            'goal': broadcast.donation_goal,
            'percentage': min(100, (broadcast.total_donations / broadcast.donation_goal * 100)
                            if broadcast.donation_goal > 0 else 0),
            'donor_count': len(broadcast.donations),
            'matching_active': broadcast.matching_enabled,
            'match_multiplier': broadcast.match_multiplier,
            'recent_donations': [
                {
                    'name': d.donor_name,
                    'amount': d.amount,
                    'effective_amount': d.amount * d.match_multiplier,
                    'is_matched': d.is_matched,
                    'message': d.message
                }
                for d in sorted(broadcast.donations, key=lambda x: x.created_at, reverse=True)[:5]
            ]
        }
    
    # =========================================================================
    # LIVE POLLS
    # =========================================================================
    
    async def create_poll(
        self,
        broadcast_id: str,
        question: str,
        options: List[str],
        poll_type: PollType = PollType.SINGLE_CHOICE,
        duration_seconds: int = 60
    ) -> LivePoll:
        """Create a live poll."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast:
            raise ValueError(f"Broadcast {broadcast_id} not found")
        
        poll = LivePoll(
            broadcast_id=broadcast_id,
            question=question,
            poll_type=poll_type,
            options=options,
            votes={opt: 0 for opt in options},
            duration_seconds=duration_seconds
        )
        
        broadcast.polls.append(poll)
        
        logger.info(f"Created poll: {question} ({len(options)} options)")
        return poll
    
    async def start_poll(self, poll_id: str) -> LivePoll:
        """Start a poll and begin accepting votes."""
        poll = self._find_poll(poll_id)
        if not poll:
            raise ValueError(f"Poll {poll_id} not found")
        
        poll.is_active = True
        poll.started_at = datetime.now()
        
        # Publish to all platforms
        if self.redis:
            await self.redis.publish('broadcast:poll:start', json.dumps({
                'poll_id': poll.poll_id,
                'question': poll.question,
                'options': poll.options,
                'duration': poll.duration_seconds
            }))
        
        # Schedule auto-end
        asyncio.create_task(self._auto_end_poll(poll))
        
        logger.info(f"Poll started: {poll.question}")
        return poll
    
    async def vote_poll(self, poll_id: str, option: str, voter_id: Optional[str] = None) -> bool:
        """Submit a vote to an active poll."""
        poll = self._find_poll(poll_id)
        if not poll or not poll.is_active:
            return False
        
        if option in poll.votes:
            poll.votes[option] += 1
            
            # Publish update
            if self.redis:
                await self.redis.publish('broadcast:poll:update', json.dumps({
                    'poll_id': poll.poll_id,
                    'votes': poll.votes,
                    'total_votes': sum(poll.votes.values())
                }))
            
            return True
        
        return False
    
    async def end_poll(self, poll_id: str) -> LivePoll:
        """End a poll and get results."""
        poll = self._find_poll(poll_id)
        if not poll:
            raise ValueError(f"Poll {poll_id} not found")
        
        poll.is_active = False
        poll.ended_at = datetime.now()
        
        # Publish results
        if self.redis:
            total = sum(poll.votes.values())
            await self.redis.publish('broadcast:poll:end', json.dumps({
                'poll_id': poll.poll_id,
                'question': poll.question,
                'results': {
                    opt: {'votes': v, 'percentage': (v / total * 100) if total > 0 else 0}
                    for opt, v in poll.votes.items()
                },
                'total_votes': total,
                'winner': max(poll.votes, key=poll.votes.get) if poll.votes else None
            }))
        
        logger.info(f"Poll ended: {poll.question} - {sum(poll.votes.values())} total votes")
        return poll
    
    async def _auto_end_poll(self, poll: LivePoll):
        """Auto-end poll after duration."""
        await asyncio.sleep(poll.duration_seconds)
        if poll.is_active:
            await self.end_poll(poll.poll_id)
    
    def _find_poll(self, poll_id: str) -> Optional[LivePoll]:
        """Find poll by ID across all broadcasts."""
        for broadcast in self.broadcasts.values():
            for poll in broadcast.polls:
                if poll.poll_id == poll_id:
                    return poll
        return None
    
    # =========================================================================
    # REACTIONS & ENGAGEMENT
    # =========================================================================
    
    async def record_reaction(
        self,
        broadcast_id: str,
        reaction_type: ReactionType,
        platform: Platform,
        viewer_name: Optional[str] = None
    ) -> ViewerReaction:
        """Record a viewer reaction."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast:
            raise ValueError(f"Broadcast {broadcast_id} not found")
        
        reaction = ViewerReaction(
            broadcast_id=broadcast_id,
            reaction_type=reaction_type,
            platform=platform,
            viewer_name=viewer_name
        )
        
        broadcast.reactions.append(reaction)
        
        # Aggregate reactions for overlay (last 10 seconds)
        recent_cutoff = datetime.now() - timedelta(seconds=10)
        recent_reactions = [
            r for r in broadcast.reactions
            if r.timestamp > recent_cutoff
        ]
        
        if self.redis:
            await self.redis.publish('broadcast:reactions', json.dumps({
                'broadcast_id': broadcast_id,
                'recent_count': len(recent_reactions),
                'by_type': {
                    rt.value: sum(1 for r in recent_reactions if r.reaction_type == rt)
                    for rt in ReactionType
                }
            }))
        
        return reaction
    
    # =========================================================================
    # CLIP EXTRACTION
    # =========================================================================
    
    async def create_clip(
        self,
        broadcast_id: str,
        title: str,
        start_time_seconds: int,
        end_time_seconds: int,
        tags: Optional[List[str]] = None
    ) -> StreamClip:
        """Create a clip from the broadcast recording."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast:
            raise ValueError(f"Broadcast {broadcast_id} not found")
        
        clip = StreamClip(
            broadcast_id=broadcast_id,
            title=title,
            start_time_seconds=start_time_seconds,
            end_time_seconds=end_time_seconds,
            duration_seconds=end_time_seconds - start_time_seconds,
            tags=tags or []
        )
        
        broadcast.clips.append(clip)
        
        # Queue clip extraction job
        if self.redis:
            await self.redis.publish('broadcast:clip:extract', json.dumps({
                'clip_id': clip.clip_id,
                'broadcast_id': broadcast_id,
                'recording_path': broadcast.recording_path,
                'start': start_time_seconds,
                'end': end_time_seconds,
                'title': title
            }))
        
        logger.info(f"Clip queued: {title} ({clip.duration_seconds}s)")
        return clip
    
    async def auto_generate_clips(self, broadcast_id: str) -> List[StreamClip]:
        """Auto-generate clips from high-engagement moments."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast or not broadcast.reactions:
            return []
        
        # Find reaction peaks
        # Group reactions by 30-second windows
        window_size = 30
        reaction_windows: Dict[int, int] = {}
        
        for reaction in broadcast.reactions:
            if broadcast.actual_start:
                seconds = int((reaction.timestamp - broadcast.actual_start).total_seconds())
                window = (seconds // window_size) * window_size
                reaction_windows[window] = reaction_windows.get(window, 0) + 1
        
        # Find top 5 windows
        sorted_windows = sorted(reaction_windows.items(), key=lambda x: x[1], reverse=True)[:5]
        
        clips = []
        for window_start, reaction_count in sorted_windows:
            if reaction_count >= 10:  # Minimum threshold
                clip = await self.create_clip(
                    broadcast_id,
                    f"Highlight - {reaction_count} reactions",
                    max(0, window_start - 10),
                    window_start + window_size + 10,
                    tags=['auto-generated', 'highlight']
                )
                clip.auto_generated = True
                clips.append(clip)
        
        logger.info(f"Auto-generated {len(clips)} highlight clips")
        return clips
    
    # =========================================================================
    # PLATFORM INTEGRATION
    # =========================================================================
    
    def _get_rtmp_url(self, platform: Platform) -> str:
        """Get RTMP URL for platform."""
        rtmp_urls = {
            Platform.FACEBOOK: 'rtmps://live-api-s.facebook.com:443/rtmp/',
            Platform.YOUTUBE: 'rtmp://a.rtmp.youtube.com/live2/',
            Platform.RUMBLE: 'rtmp://live.rumble.com/live/',
            Platform.LINKEDIN: 'rtmps://prod-rtmp-publish.linkedin.com/prod/',
            Platform.TWITTER_X: 'rtmps://live.twitter.com/rtmp/',
            Platform.TWITCH: 'rtmp://live.twitch.tv/app/'
        }
        return rtmp_urls.get(platform, '')
    
    async def _connect_platform(self, destination: StreamDestination):
        """Connect to streaming platform."""
        # In production, this would initiate actual RTMP connection
        logger.info(f"Connecting to {destination.platform.value}...")
        await asyncio.sleep(0.5)  # Simulate connection
        destination.is_active = True
    
    async def _disconnect_platform(self, destination: StreamDestination):
        """Disconnect from streaming platform."""
        logger.info(f"Disconnecting from {destination.platform.value}...")
        destination.is_active = False
    
    async def _poll_viewer_counts(self, broadcast: Broadcast):
        """Background task to poll viewer counts."""
        while broadcast.status == BroadcastStatus.LIVE:
            total_viewers = 0
            
            for dest in broadcast.destinations:
                if dest.is_active:
                    # In production, would call platform APIs
                    dest.viewer_count = dest.viewer_count  # Placeholder
                    total_viewers += dest.viewer_count
            
            broadcast.total_viewers = total_viewers
            if total_viewers > broadcast.peak_viewers:
                broadcast.peak_viewers = total_viewers
                
                # Check milestones
                if self.on_viewer_milestone:
                    milestones = [100, 500, 1000, 5000, 10000]
                    for milestone in milestones:
                        if broadcast.peak_viewers >= milestone:
                            await self.on_viewer_milestone(milestone)
            
            await asyncio.sleep(10)
    
    async def _monitor_reactions(self, broadcast: Broadcast):
        """Background task to monitor platform reactions."""
        while broadcast.status == BroadcastStatus.LIVE:
            # In production, would poll platform APIs for reactions
            await asyncio.sleep(5)
    
    # =========================================================================
    # DATABASE OPERATIONS
    # =========================================================================
    
    async def _save_broadcast_to_db(self, broadcast: Broadcast):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e46_broadcasts').upsert({
                'broadcast_id': broadcast.broadcast_id,
                'title': broadcast.title,
                'description': broadcast.description,
                'candidate_id': broadcast.candidate_id,
                'status': broadcast.status.value,
                'scheduled_start': broadcast.scheduled_start.isoformat(),
                'actual_start': broadcast.actual_start.isoformat() if broadcast.actual_start else None,
                'actual_end': broadcast.actual_end.isoformat() if broadcast.actual_end else None,
                'peak_viewers': broadcast.peak_viewers,
                'total_viewers': broadcast.total_viewers,
                'total_donations': broadcast.total_donations,
                'total_captures': broadcast.total_captures,
                'donation_goal': broadcast.donation_goal,
                'matching_enabled': broadcast.matching_enabled,
                'updated_at': datetime.now().isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save broadcast: {e}")
    
    async def _save_capture_to_db(self, capture: TextCapture):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e46_captures').insert({
                'capture_id': capture.capture_id,
                'broadcast_id': capture.broadcast_id,
                'phone_number': capture.phone_number,
                'keyword': capture.keyword.value,
                'message_text': capture.message_text,
                'processed': capture.processed,
                'captured_at': capture.captured_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save capture: {e}")
    
    async def _save_donation_to_db(self, donation: LiveDonation):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e46_live_donations').insert({
                'donation_id': donation.donation_id,
                'broadcast_id': donation.broadcast_id,
                'donor_name': donation.donor_name,
                'donor_id': donation.donor_id,
                'amount': donation.amount,
                'message': donation.message,
                'is_matched': donation.is_matched,
                'match_multiplier': donation.match_multiplier,
                'platform_source': donation.platform_source.value,
                'created_at': donation.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save donation: {e}")
    
    # =========================================================================
    # ANALYTICS
    # =========================================================================
    
    def get_broadcast_analytics(self, broadcast_id: str) -> Dict[str, Any]:
        """Get comprehensive broadcast analytics."""
        broadcast = self.broadcasts.get(broadcast_id)
        if not broadcast:
            return {}
        
        duration_minutes = 0
        if broadcast.actual_start and broadcast.actual_end:
            duration_minutes = (broadcast.actual_end - broadcast.actual_start).total_seconds() / 60
        
        return {
            'broadcast_id': broadcast_id,
            'title': broadcast.title,
            'status': broadcast.status.value,
            'duration_minutes': duration_minutes,
            'viewership': {
                'peak': broadcast.peak_viewers,
                'total_unique': broadcast.total_viewers,
                'by_platform': {
                    d.platform.value: d.viewer_count
                    for d in broadcast.destinations
                }
            },
            'engagement': {
                'total_reactions': len(broadcast.reactions),
                'reactions_by_type': {
                    rt.value: sum(1 for r in broadcast.reactions if r.reaction_type == rt)
                    for rt in ReactionType
                },
                'polls_conducted': len(broadcast.polls),
                'total_poll_votes': sum(sum(p.votes.values()) for p in broadcast.polls)
            },
            'fundraising': {
                'total_raised': broadcast.total_donations,
                'goal': broadcast.donation_goal,
                'goal_percentage': (broadcast.total_donations / broadcast.donation_goal * 100)
                                  if broadcast.donation_goal > 0 else 0,
                'donor_count': len(broadcast.donations),
                'average_donation': (broadcast.total_donations / len(broadcast.donations))
                                   if broadcast.donations else 0,
                'matched_amount': sum(d.amount * (d.match_multiplier - 1)
                                     for d in broadcast.donations if d.is_matched)
            },
            'captures': {
                'total': len(broadcast.captures),
                'by_keyword': {
                    kw.value: sum(1 for c in broadcast.captures if c.keyword == kw)
                    for kw in CaptureKeyword
                }
            },
            'clips': {
                'total': len(broadcast.clips),
                'auto_generated': sum(1 for c in broadcast.clips if c.auto_generated)
            }
        }


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

async def main():
    """Demo the broadcast hub."""
    hub = BroadcastHub()
    
    # Create a broadcast
    broadcast = await hub.create_broadcast(
        title="Dave Boliek Town Hall - Live Q&A",
        description="Join Dave Boliek for a live town hall discussing judicial reform",
        candidate_id='dave-boliek-001',
        scheduled_start=datetime.now() + timedelta(hours=1),
        platforms=[Platform.FACEBOOK, Platform.YOUTUBE, Platform.RUMBLE],
        donation_goal=10000.0,
        matching_enabled=True,
        match_multiplier=2.0
    )
    
    print(f"\nCreated broadcast: {broadcast.title}")
    print(f"Broadcast ID: {broadcast.broadcast_id}")
    print(f"Platforms: {[d.platform.value for d in broadcast.destinations]}")
    
    # Simulate going live
    await hub.start_broadcast(broadcast.broadcast_id)
    print(f"\nBroadcast is LIVE!")
    
    # Simulate some activity
    await hub.process_donation(
        broadcast.broadcast_id,
        "John Smith",
        100.0,
        "Go Dave!",
        platform=Platform.FACEBOOK
    )
    
    await hub.process_donation(
        broadcast.broadcast_id,
        "Jane Doe",
        250.0,
        "Judicial integrity matters!",
        platform=Platform.YOUTUBE
    )
    
    # Create a poll
    poll = await hub.create_poll(
        broadcast.broadcast_id,
        "What issue matters most to you?",
        ["Judicial Reform", "Public Safety", "Economic Growth", "Education"],
        duration_seconds=30
    )
    await hub.start_poll(poll.poll_id)
    
    # Simulate votes
    await hub.vote_poll(poll.poll_id, "Judicial Reform")
    await hub.vote_poll(poll.poll_id, "Judicial Reform")
    await hub.vote_poll(poll.poll_id, "Public Safety")
    
    # Process SMS capture
    await hub.process_sms_capture("+13365551234", "DONATE")
    
    # Get thermometer
    thermo = hub.get_donation_thermometer(broadcast.broadcast_id)
    print(f"\nDonation Thermometer:")
    print(f"  Raised: ${thermo['total_raised']:,.2f} / ${thermo['goal']:,.2f} ({thermo['percentage']:.1f}%)")
    
    # End broadcast
    await asyncio.sleep(1)
    await hub.end_broadcast(broadcast.broadcast_id)
    
    # Get analytics
    analytics = hub.get_broadcast_analytics(broadcast.broadcast_id)
    print(f"\n=== BROADCAST ANALYTICS ===")
    print(json.dumps(analytics, indent=2, default=str))


if __name__ == '__main__':
    asyncio.run(main())
