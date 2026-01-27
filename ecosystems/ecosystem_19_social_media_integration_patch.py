#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 19: SOCIAL MEDIA INTEGRATION PATCH
============================================================================

This patch EXTENDS the existing E19 Social Media Manager with:
- E42 News Intelligence event subscriptions
- E47 Voice Engine integration (AI voice for video posts)
- E48 Video Synthesis integration (talking head generation)
- E20 Brain orchestration hooks
- E40 Control Panel feature registry
- Nightly approval workflow (8PM generate → 11PM auto-approve)

DOES NOT REPLACE - EXTENDS existing ecosystem_19_social_media_manager.py

============================================================================
"""

import os
import json
import redis
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from enum import Enum
import uuid
import hashlib

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem19.integration')


# ============================================================================
# CONFIGURATION
# ============================================================================

class IntegrationConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:Melanie2026$@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres")
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
    
    # RunPod AI Endpoints
    RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY", "rpa_ACAEJKYCMH2JST9HPQIK0IA6T4G3E0G2DMUXBTEW10a2x")
    VOICE_ENDPOINT = os.getenv("VOICE_ENDPOINT", "ebctno9p73twoa")
    VIDEO_ENDPOINT = os.getenv("VIDEO_ENDPOINT", "qsqdjzzpatxwn1")
    FULLBODY_ENDPOINT = os.getenv("FULLBODY_ENDPOINT", "ju6mx6fnseu7hi")
    
    # Nightly workflow
    NIGHTLY_GENERATE_HOUR = 20  # 8 PM
    NIGHTLY_AUTOAPPROVE_HOUR = 23  # 11 PM
    APPROVAL_SMS_WINDOW_MINUTES = 180  # 3 hours
    
    # Bandwidth SMS (not Twilio)
    BANDWIDTH_ACCOUNT_ID = os.getenv("BANDWIDTH_ACCOUNT_ID", "")
    BANDWIDTH_API_TOKEN = os.getenv("BANDWIDTH_API_TOKEN", "")
    BANDWIDTH_API_SECRET = os.getenv("BANDWIDTH_API_SECRET", "")


# ============================================================================
# EVENT SUBSCRIPTIONS - What E19 listens for
# ============================================================================

E19_EVENT_SUBSCRIPTIONS = {
    # From E42 News Intelligence
    "news.crisis_detected": {
        "priority": "URGENT",
        "action": "generate_rapid_response",
        "auto_approve": False,
        "description": "Crisis detected - generate defensive social post"
    },
    "news.positive_coverage": {
        "priority": "HIGH",
        "action": "amplify_positive_news",
        "auto_approve": True,
        "description": "Positive press - amplify with social post"
    },
    "news.opponent_gaffe": {
        "priority": "HIGH",
        "action": "generate_contrast_post",
        "auto_approve": False,
        "description": "Opponent mistake - generate contrast content"
    },
    "news.endorsement_coverage": {
        "priority": "NORMAL",
        "action": "share_endorsement",
        "auto_approve": True,
        "description": "Endorsement news - share across platforms"
    },
    "news.issue_trending": {
        "priority": "NORMAL",
        "action": "join_trending_topic",
        "auto_approve": False,
        "description": "Issue trending - create relevant content"
    },
    
    # From E20 Intelligence Brain
    "brain.social_post_requested": {
        "priority": "NORMAL",
        "action": "generate_and_schedule",
        "auto_approve": False,
        "description": "Brain requested social post generation"
    },
    "brain.video_post_requested": {
        "priority": "HIGH",
        "action": "generate_ai_video_post",
        "auto_approve": False,
        "description": "Brain requested AI video post"
    },
    
    # From E48 Video Synthesis
    "video.synthesis_complete": {
        "priority": "HIGH",
        "action": "post_generated_video",
        "auto_approve": False,
        "description": "AI video ready - post to social"
    },
    
    # From E45 Video Studio
    "video.export_ready": {
        "priority": "NORMAL",
        "action": "post_recorded_video",
        "auto_approve": False,
        "description": "Recorded video ready for social"
    },
    
    # From E46 Broadcast Hub
    "broadcast.clip_extracted": {
        "priority": "NORMAL",
        "action": "post_broadcast_clip",
        "auto_approve": True,
        "description": "Live broadcast clip ready"
    }
}


# ============================================================================
# E40 CONTROL PANEL FEATURE REGISTRY
# ============================================================================

E19_CONTROL_PANEL_FEATURES = {
    "social_auto_generate": {
        "name": "Auto-Generate Posts",
        "description": "AI automatically generates social posts from news and events",
        "type": "toggle",
        "default": True,
        "category": "automation"
    },
    "social_nightly_workflow": {
        "name": "Nightly Approval Workflow",
        "description": "Generate posts at 8PM, send for approval, auto-approve at 11PM",
        "type": "schedule",
        "default": "20:00",
        "category": "automation"
    },
    "social_auto_approve_11pm": {
        "name": "Auto-Approve at 11PM",
        "description": "Automatically approve pending posts at 11PM if no response",
        "type": "toggle",
        "default": True,
        "category": "automation"
    },
    "social_facebook_enabled": {
        "name": "Facebook Posting",
        "description": "Enable posting to Facebook Pages",
        "type": "toggle",
        "default": True,
        "category": "platforms"
    },
    "social_twitter_enabled": {
        "name": "Twitter/X Posting",
        "description": "Enable posting to Twitter/X",
        "type": "toggle",
        "default": True,
        "category": "platforms"
    },
    "social_instagram_enabled": {
        "name": "Instagram Posting",
        "description": "Enable posting to Instagram",
        "type": "toggle",
        "default": True,
        "category": "platforms"
    },
    "social_linkedin_enabled": {
        "name": "LinkedIn Posting",
        "description": "Enable posting to LinkedIn",
        "type": "toggle",
        "default": True,
        "category": "platforms"
    },
    "social_ai_video_enabled": {
        "name": "AI Video Generation",
        "description": "Generate AI talking head videos for posts",
        "type": "toggle",
        "default": True,
        "category": "ai"
    },
    "social_voice_clone_enabled": {
        "name": "Voice Cloning",
        "description": "Use AI voice cloning for video posts",
        "type": "toggle",
        "default": True,
        "category": "ai"
    },
    "social_strict_compliance": {
        "name": "Strict Compliance Mode",
        "description": "Enforce all Facebook political ad rules",
        "type": "toggle",
        "default": True,
        "category": "compliance"
    },
    "social_crisis_response_enabled": {
        "name": "Crisis Auto-Response",
        "description": "Automatically generate posts for crisis events",
        "type": "toggle",
        "default": True,
        "category": "automation"
    }
}


# ============================================================================
# DATA CLASSES
# ============================================================================

class PostPriority(Enum):
    CRISIS = 10
    URGENT = 9
    HIGH = 7
    NORMAL = 5
    LOW = 3
    SCHEDULED = 1

class PostStatus(Enum):
    DRAFT = "draft"
    PENDING_APPROVAL = "pending_approval"
    APPROVED = "approved"
    SCHEDULED = "scheduled"
    PUBLISHING = "publishing"
    PUBLISHED = "published"
    FAILED = "failed"
    REJECTED = "rejected"

class VideoStatus(Enum):
    REQUESTED = "requested"
    VOICE_GENERATING = "voice_generating"
    VOICE_COMPLETE = "voice_complete"
    VIDEO_GENERATING = "video_generating"
    VIDEO_COMPLETE = "video_complete"
    FAILED = "failed"

@dataclass
class SocialVideoRequest:
    """Request for AI video generation"""
    request_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ""
    script_text: str = ""
    voice_profile_id: Optional[str] = None
    portrait_image_url: Optional[str] = None
    motion_preset: str = "conversational"  # podium, conversational, passionate, serious, friendly, urgent
    emotion: str = "neutral"  # neutral, passionate, urgent, empathetic, authoritative, warm
    platforms: List[str] = field(default_factory=lambda: ["facebook", "twitter"])
    status: VideoStatus = VideoStatus.REQUESTED
    voice_audio_url: Optional[str] = None
    video_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.now)
    
@dataclass
class NightlyPost:
    """Post in nightly approval queue"""
    post_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ""
    content_type: str = "text"  # text, image, video
    caption: str = ""
    media_url: Optional[str] = None
    platforms: List[str] = field(default_factory=list)
    trigger_event: str = ""
    priority: PostPriority = PostPriority.NORMAL
    status: PostStatus = PostStatus.DRAFT
    approval_sms_sent: bool = False
    approval_sms_sent_at: Optional[datetime] = None
    approved_at: Optional[datetime] = None
    approved_by: Optional[str] = None  # "candidate", "auto", "manager"
    rejection_reason: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.now)


# ============================================================================
# E47 VOICE ENGINE CLIENT
# ============================================================================

class VoiceEngineClient:
    """Client for E47 Voice Engine (Chatterbox TTS)"""
    
    def __init__(self):
        self.api_key = IntegrationConfig.RUNPOD_API_KEY
        self.endpoint = IntegrationConfig.VOICE_ENDPOINT
        self.base_url = f"https://api.runpod.ai/v2/{self.endpoint}"
        
    async def generate_voice(
        self,
        text: str,
        voice_profile_id: str,
        emotion: str = "neutral",
        speed: float = 1.0
    ) -> Dict:
        """
        Generate voice audio using Chatterbox TTS
        
        Returns: {
            "audio_url": "https://...",
            "duration_seconds": 45.2,
            "quality_score": 95
        }
        """
        import aiohttp
        
        payload = {
            "input": {
                "text": text,
                "voice_id": voice_profile_id,
                "emotion": emotion,
                "speed": speed,
                "model": "chatterbox"
            }
        }
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                # Submit job
                async with session.post(
                    f"{self.base_url}/runsync",
                    json=payload,
                    headers=headers
                ) as response:
                    result = await response.json()
                    
                    if result.get("status") == "COMPLETED":
                        return {
                            "audio_url": result["output"]["audio_url"],
                            "duration_seconds": result["output"].get("duration", 0),
                            "quality_score": result["output"].get("quality_score", 95)
                        }
                    else:
                        logger.error(f"Voice generation failed: {result}")
                        return {"error": result.get("error", "Unknown error")}
                        
        except Exception as e:
            logger.error(f"Voice engine error: {e}")
            return {"error": str(e)}
    
    async def clone_voice(
        self,
        reference_audio_url: str,
        candidate_id: str
    ) -> Dict:
        """Clone voice from reference audio (30 seconds minimum)"""
        import aiohttp
        
        payload = {
            "input": {
                "action": "clone",
                "reference_audio": reference_audio_url,
                "candidate_id": candidate_id
            }
        }
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/runsync",
                    json=payload,
                    headers=headers
                ) as response:
                    result = await response.json()
                    return result.get("output", {})
        except Exception as e:
            logger.error(f"Voice cloning error: {e}")
            return {"error": str(e)}


# ============================================================================
# E48 VIDEO SYNTHESIS CLIENT
# ============================================================================

class VideoSynthesisClient:
    """Client for E48 Video Synthesis (Hallo/Wav2Lip)"""
    
    def __init__(self):
        self.api_key = IntegrationConfig.RUNPOD_API_KEY
        self.endpoint = IntegrationConfig.VIDEO_ENDPOINT
        self.base_url = f"https://api.runpod.ai/v2/{self.endpoint}"
        
    async def generate_talking_head(
        self,
        audio_url: str,
        portrait_image_url: str,
        motion_preset: str = "conversational"
    ) -> Dict:
        """
        Generate talking head video using Hallo
        
        motion_preset: podium, conversational, passionate, serious, friendly, urgent
        
        Returns: {
            "video_url": "https://...",
            "thumbnail_url": "https://...",
            "duration_seconds": 45.2,
            "quality_score": 85
        }
        """
        import aiohttp
        
        # Motion preset parameters
        motion_params = {
            "podium": {"head_motion": 0.3, "expression": 0.5},
            "conversational": {"head_motion": 0.6, "expression": 0.7},
            "passionate": {"head_motion": 0.8, "expression": 0.9},
            "serious": {"head_motion": 0.2, "expression": 0.3},
            "friendly": {"head_motion": 0.5, "expression": 0.6, "smile": 0.3},
            "urgent": {"head_motion": 0.4, "expression": 0.7, "blink": 0.2}
        }
        
        params = motion_params.get(motion_preset, motion_params["conversational"])
        
        payload = {
            "input": {
                "audio_url": audio_url,
                "portrait_url": portrait_image_url,
                "model": "hallo",
                "output_quality": "1080p",
                **params
            }
        }
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/runsync",
                    json=payload,
                    headers=headers,
                    timeout=aiohttp.ClientTimeout(total=300)  # 5 min timeout for video
                ) as response:
                    result = await response.json()
                    
                    if result.get("status") == "COMPLETED":
                        return {
                            "video_url": result["output"]["video_url"],
                            "thumbnail_url": result["output"].get("thumbnail_url"),
                            "duration_seconds": result["output"].get("duration", 0),
                            "quality_score": result["output"].get("quality_score", 85)
                        }
                    else:
                        logger.error(f"Video generation failed: {result}")
                        return {"error": result.get("error", "Unknown error")}
                        
        except Exception as e:
            logger.error(f"Video synthesis error: {e}")
            return {"error": str(e)}


# ============================================================================
# SOCIAL MEDIA INTEGRATION ENGINE
# ============================================================================

class SocialMediaIntegrationEngine:
    """
    Extends E19 with E42/E47/E48 integrations
    """
    
    def __init__(self):
        self.redis = redis.Redis(
            host=IntegrationConfig.REDIS_HOST,
            port=IntegrationConfig.REDIS_PORT,
            decode_responses=True
        )
        self.voice_client = VoiceEngineClient()
        self.video_client = VideoSynthesisClient()
        self.pending_posts: Dict[str, NightlyPost] = {}
        self.video_requests: Dict[str, SocialVideoRequest] = {}
        
        logger.info("🔗 E19 Integration Engine initialized")
        logger.info(f"   Subscribed to {len(E19_EVENT_SUBSCRIPTIONS)} event types")
        
    # ========================================================================
    # EVENT HANDLERS
    # ========================================================================
    
    async def start_event_listener(self):
        """Listen for events from E42, E20, E45, E46, E48"""
        pubsub = self.redis.pubsub()
        
        # Subscribe to all relevant channels
        channels = list(E19_EVENT_SUBSCRIPTIONS.keys())
        for channel in channels:
            pubsub.subscribe(channel)
            
        logger.info(f"👂 Listening for {len(channels)} event types...")
        
        for message in pubsub.listen():
            if message['type'] == 'message':
                await self.handle_event(message['channel'], message['data'])
    
    async def handle_event(self, event_type: str, data: str):
        """Route event to appropriate handler"""
        try:
            event_data = json.loads(data)
            subscription = E19_EVENT_SUBSCRIPTIONS.get(event_type)
            
            if not subscription:
                logger.warning(f"Unknown event type: {event_type}")
                return
                
            logger.info(f"📥 Event: {event_type} | Priority: {subscription['priority']}")
            
            action = subscription['action']
            
            # Route to handler
            if action == "generate_rapid_response":
                await self.handle_crisis_response(event_data)
            elif action == "amplify_positive_news":
                await self.handle_positive_news(event_data)
            elif action == "generate_contrast_post":
                await self.handle_opponent_gaffe(event_data)
            elif action == "share_endorsement":
                await self.handle_endorsement(event_data)
            elif action == "join_trending_topic":
                await self.handle_trending_topic(event_data)
            elif action == "generate_and_schedule":
                await self.handle_brain_post_request(event_data)
            elif action == "generate_ai_video_post":
                await self.handle_video_post_request(event_data)
            elif action == "post_generated_video":
                await self.handle_video_ready(event_data)
            elif action == "post_recorded_video":
                await self.handle_export_ready(event_data)
            elif action == "post_broadcast_clip":
                await self.handle_broadcast_clip(event_data)
            else:
                logger.warning(f"Unknown action: {action}")
                
        except json.JSONDecodeError:
            logger.error(f"Invalid JSON in event: {data}")
        except Exception as e:
            logger.error(f"Event handler error: {e}")
    
    # ========================================================================
    # NEWS EVENT HANDLERS (E42)
    # ========================================================================
    
    async def handle_crisis_response(self, event: Dict):
        """
        Handle news.crisis_detected from E42
        Generate rapid response social post
        """
        logger.warning(f"🚨 CRISIS: {event.get('article_title', 'Unknown')}")
        
        candidate_id = event.get('candidate_id')
        issue = event.get('issue', 'general')
        urgency = event.get('urgency', 5)
        
        # Request content from E9 Content AI
        script = await self.request_crisis_script(candidate_id, issue, event)
        
        if not script:
            logger.error("Failed to generate crisis response script")
            return
        
        # For high urgency, generate AI video
        if urgency >= 8:
            await self.request_ai_video(
                candidate_id=candidate_id,
                script=script,
                motion_preset="urgent",
                emotion="authoritative",
                platforms=["facebook", "twitter", "instagram"]
            )
        else:
            # Text-only post
            post = NightlyPost(
                candidate_id=candidate_id,
                content_type="text",
                caption=script,
                platforms=["facebook", "twitter"],
                trigger_event="news.crisis_detected",
                priority=PostPriority.CRISIS,
                status=PostStatus.PENDING_APPROVAL
            )
            self.pending_posts[post.post_id] = post
            
            # Send approval SMS immediately for crisis
            await self.send_approval_sms(post)
    
    async def handle_positive_news(self, event: Dict):
        """Handle news.positive_coverage from E42"""
        logger.info(f"📰 POSITIVE NEWS: {event.get('article_title', 'Unknown')}")
        
        candidate_id = event.get('candidate_id')
        article_url = event.get('article_url')
        
        # Generate amplification post
        caption = f"Great coverage! {event.get('summary', '')} Read more: {article_url}"
        
        post = NightlyPost(
            candidate_id=candidate_id,
            content_type="text",
            caption=caption,
            platforms=["facebook", "twitter", "linkedin"],
            trigger_event="news.positive_coverage",
            priority=PostPriority.HIGH,
            status=PostStatus.APPROVED  # Auto-approve positive news
        )
        
        # Queue for immediate posting
        await self.queue_for_posting(post)
    
    async def handle_opponent_gaffe(self, event: Dict):
        """Handle news.opponent_gaffe from E42"""
        logger.info(f"🎯 OPPONENT GAFFE: {event.get('opponent_name', 'Unknown')}")
        
        # Generate contrast content - requires approval
        candidate_id = event.get('candidate_id')
        
        post = NightlyPost(
            candidate_id=candidate_id,
            content_type="text",
            caption=f"[CONTRAST POST DRAFT] - Regarding {event.get('topic', 'recent events')}",
            platforms=["facebook", "twitter"],
            trigger_event="news.opponent_gaffe",
            priority=PostPriority.HIGH,
            status=PostStatus.PENDING_APPROVAL
        )
        self.pending_posts[post.post_id] = post
    
    async def handle_endorsement(self, event: Dict):
        """Handle news.endorsement_coverage from E42"""
        logger.info(f"⭐ ENDORSEMENT: {event.get('endorser_name', 'Unknown')}")
        
        candidate_id = event.get('candidate_id')
        endorser = event.get('endorser_name', '')
        
        caption = f"Honored to receive the endorsement of {endorser}! #Endorsed"
        
        post = NightlyPost(
            candidate_id=candidate_id,
            content_type="text",
            caption=caption,
            platforms=["facebook", "twitter", "instagram", "linkedin"],
            trigger_event="news.endorsement_coverage",
            priority=PostPriority.NORMAL,
            status=PostStatus.APPROVED
        )
        
        await self.queue_for_posting(post)
    
    async def handle_trending_topic(self, event: Dict):
        """Handle news.issue_trending from E42"""
        logger.info(f"📈 TRENDING: {event.get('issue', 'Unknown')}")
        
        # Queue for nightly approval workflow
        candidate_id = event.get('candidate_id')
        issue = event.get('issue')
        
        post = NightlyPost(
            candidate_id=candidate_id,
            content_type="text",
            caption=f"[TRENDING TOPIC DRAFT] - {issue}",
            platforms=["facebook", "twitter"],
            trigger_event="news.issue_trending",
            priority=PostPriority.NORMAL,
            status=PostStatus.DRAFT
        )
        self.pending_posts[post.post_id] = post
    
    # ========================================================================
    # AI VIDEO GENERATION
    # ========================================================================
    
    async def request_ai_video(
        self,
        candidate_id: str,
        script: str,
        motion_preset: str = "conversational",
        emotion: str = "neutral",
        platforms: List[str] = None
    ) -> str:
        """
        Request AI video generation via E47/E48 pipeline
        
        Flow: Script → E47 Voice → E48 Video → E19 Post
        """
        request = SocialVideoRequest(
            candidate_id=candidate_id,
            script_text=script,
            motion_preset=motion_preset,
            emotion=emotion,
            platforms=platforms or ["facebook", "twitter"],
            status=VideoStatus.REQUESTED
        )
        
        self.video_requests[request.request_id] = request
        
        logger.info(f"🎬 Video request created: {request.request_id}")
        
        # Get candidate's voice profile and portrait
        voice_profile = await self.get_voice_profile(candidate_id)
        portrait_url = await self.get_portrait_image(candidate_id)
        
        if not voice_profile or not portrait_url:
            logger.error("Missing voice profile or portrait image")
            request.status = VideoStatus.FAILED
            return request.request_id
        
        request.voice_profile_id = voice_profile['voice_id']
        request.portrait_image_url = portrait_url
        
        # Step 1: Generate voice
        request.status = VideoStatus.VOICE_GENERATING
        logger.info(f"   🎤 Generating voice...")
        
        voice_result = await self.voice_client.generate_voice(
            text=script,
            voice_profile_id=voice_profile['voice_id'],
            emotion=emotion
        )
        
        if "error" in voice_result:
            logger.error(f"Voice generation failed: {voice_result['error']}")
            request.status = VideoStatus.FAILED
            return request.request_id
        
        request.voice_audio_url = voice_result['audio_url']
        request.status = VideoStatus.VOICE_COMPLETE
        logger.info(f"   ✅ Voice complete ({voice_result['duration_seconds']}s)")
        
        # Step 2: Generate video
        request.status = VideoStatus.VIDEO_GENERATING
        logger.info(f"   🎥 Generating talking head video...")
        
        video_result = await self.video_client.generate_talking_head(
            audio_url=request.voice_audio_url,
            portrait_image_url=portrait_url,
            motion_preset=motion_preset
        )
        
        if "error" in video_result:
            logger.error(f"Video generation failed: {video_result['error']}")
            request.status = VideoStatus.FAILED
            return request.request_id
        
        request.video_url = video_result['video_url']
        request.thumbnail_url = video_result.get('thumbnail_url')
        request.status = VideoStatus.VIDEO_COMPLETE
        logger.info(f"   ✅ Video complete!")
        
        # Create post with video
        post = NightlyPost(
            candidate_id=candidate_id,
            content_type="video",
            caption=self.truncate_for_social(script),
            media_url=request.video_url,
            platforms=platforms or ["facebook", "twitter"],
            trigger_event="ai_video_generated",
            priority=PostPriority.HIGH,
            status=PostStatus.PENDING_APPROVAL
        )
        self.pending_posts[post.post_id] = post
        
        # Send approval SMS
        await self.send_approval_sms(post)
        
        # Publish event
        self.redis.publish('social.video_post_ready', json.dumps({
            'request_id': request.request_id,
            'post_id': post.post_id,
            'video_url': request.video_url,
            'candidate_id': candidate_id,
            'ecosystem': 'E19'
        }))
        
        return request.request_id
    
    async def handle_video_post_request(self, event: Dict):
        """Handle brain.video_post_requested from E20"""
        await self.request_ai_video(
            candidate_id=event.get('candidate_id'),
            script=event.get('script'),
            motion_preset=event.get('motion_preset', 'conversational'),
            emotion=event.get('emotion', 'neutral'),
            platforms=event.get('platforms', ['facebook', 'twitter'])
        )
    
    async def handle_video_ready(self, event: Dict):
        """Handle video.synthesis_complete from E48"""
        video_url = event.get('video_url')
        candidate_id = event.get('candidate_id')
        
        post = NightlyPost(
            candidate_id=candidate_id,
            content_type="video",
            caption=event.get('caption', ''),
            media_url=video_url,
            platforms=event.get('platforms', ['facebook']),
            trigger_event="video.synthesis_complete",
            priority=PostPriority.HIGH,
            status=PostStatus.PENDING_APPROVAL
        )
        self.pending_posts[post.post_id] = post
        await self.send_approval_sms(post)
    
    async def handle_export_ready(self, event: Dict):
        """Handle video.export_ready from E45"""
        # Similar to handle_video_ready
        pass
    
    async def handle_broadcast_clip(self, event: Dict):
        """Handle broadcast.clip_extracted from E46"""
        # Auto-approve broadcast clips
        post = NightlyPost(
            candidate_id=event.get('candidate_id'),
            content_type="video",
            caption=event.get('clip_title', 'Live moment!'),
            media_url=event.get('clip_url'),
            platforms=["facebook", "twitter"],
            trigger_event="broadcast.clip_extracted",
            priority=PostPriority.NORMAL,
            status=PostStatus.APPROVED
        )
        await self.queue_for_posting(post)
    
    async def handle_brain_post_request(self, event: Dict):
        """Handle brain.social_post_requested from E20"""
        post = NightlyPost(
            candidate_id=event.get('candidate_id'),
            content_type=event.get('content_type', 'text'),
            caption=event.get('caption'),
            media_url=event.get('media_url'),
            platforms=event.get('platforms', ['facebook']),
            trigger_event="brain.social_post_requested",
            priority=PostPriority(event.get('priority', 5)),
            status=PostStatus.PENDING_APPROVAL if not event.get('auto_approve') else PostStatus.APPROVED
        )
        
        if post.status == PostStatus.APPROVED:
            await self.queue_for_posting(post)
        else:
            self.pending_posts[post.post_id] = post
            await self.send_approval_sms(post)
    
    # ========================================================================
    # NIGHTLY APPROVAL WORKFLOW
    # ========================================================================
    
    async def run_nightly_workflow(self):
        """
        Nightly workflow:
        1. 8 PM: Generate posts from day's events
        2. 8:05 PM: Send approval SMS to candidates
        3. Candidates reply "OK" to approve
        4. 11 PM: Auto-approve remaining posts
        5. Next day: Posts publish according to schedule
        """
        current_hour = datetime.now().hour
        
        if current_hour == IntegrationConfig.NIGHTLY_GENERATE_HOUR:
            logger.info("🌙 8 PM: Starting nightly post generation...")
            await self.generate_nightly_posts()
            await self.send_all_approval_sms()
            
        elif current_hour == IntegrationConfig.NIGHTLY_AUTOAPPROVE_HOUR:
            logger.info("🌙 11 PM: Auto-approving remaining posts...")
            await self.auto_approve_pending()
    
    async def generate_nightly_posts(self):
        """Generate posts from day's events"""
        # Get today's news events that haven't been posted
        # This would query E42 for today's relevant news
        pass
    
    async def send_all_approval_sms(self):
        """Send approval SMS for all pending posts"""
        for post_id, post in self.pending_posts.items():
            if post.status == PostStatus.PENDING_APPROVAL and not post.approval_sms_sent:
                await self.send_approval_sms(post)
    
    async def send_approval_sms(self, post: NightlyPost):
        """Send SMS approval request to candidate"""
        # Get candidate phone
        candidate_phone = await self.get_candidate_phone(post.candidate_id)
        
        if not candidate_phone:
            logger.warning(f"No phone for candidate {post.candidate_id}")
            return
        
        # Truncate caption for SMS
        preview = post.caption[:100] + "..." if len(post.caption) > 100 else post.caption
        
        message = f"BroyhillGOP: New post pending approval:\n\n{preview}\n\nReply OK to approve or SKIP to reject."
        
        # Send via Bandwidth (not Twilio)
        success = await self.send_sms_bandwidth(candidate_phone, message)
        
        if success:
            post.approval_sms_sent = True
            post.approval_sms_sent_at = datetime.now()
            logger.info(f"📱 Approval SMS sent for post {post.post_id}")
    
    async def handle_sms_reply(self, phone: str, message: str):
        """Handle incoming SMS reply"""
        message_upper = message.strip().upper()
        
        # Find pending post for this candidate
        candidate_id = await self.get_candidate_by_phone(phone)
        
        for post_id, post in self.pending_posts.items():
            if post.candidate_id == candidate_id and post.status == PostStatus.PENDING_APPROVAL:
                if message_upper in ["OK", "YES", "APPROVE", "Y"]:
                    post.status = PostStatus.APPROVED
                    post.approved_at = datetime.now()
                    post.approved_by = "candidate"
                    logger.info(f"✅ Post {post_id} APPROVED by candidate")
                    await self.queue_for_posting(post)
                    
                elif message_upper in ["SKIP", "NO", "REJECT", "N"]:
                    post.status = PostStatus.REJECTED
                    post.rejection_reason = "Candidate rejected via SMS"
                    logger.info(f"❌ Post {post_id} REJECTED by candidate")
                    
                break
    
    async def auto_approve_pending(self):
        """Auto-approve all pending posts at 11 PM"""
        approved_count = 0
        
        for post_id, post in self.pending_posts.items():
            if post.status == PostStatus.PENDING_APPROVAL:
                post.status = PostStatus.APPROVED
                post.approved_at = datetime.now()
                post.approved_by = "auto"
                approved_count += 1
                await self.queue_for_posting(post)
        
        logger.info(f"🤖 Auto-approved {approved_count} posts")
    
    # ========================================================================
    # POSTING QUEUE
    # ========================================================================
    
    async def queue_for_posting(self, post: NightlyPost):
        """Queue approved post for publishing via existing E19"""
        post.status = PostStatus.SCHEDULED
        
        # Publish to E19's existing channel
        self.redis.publish('social.schedule_post', json.dumps({
            'candidate_id': post.candidate_id,
            'content': {
                'caption': post.caption,
                'media_url': post.media_url,
                'media_type': post.content_type
            },
            'platforms': post.platforms,
            'scheduled_time': (datetime.now() + timedelta(minutes=5)).isoformat(),
            'authorization': 'approved_by_candidate' if post.approved_by == 'candidate' else 'auto_approved',
            'approval_method': post.approved_by or 'auto',
            'source': 'E19_integration_patch'
        }))
        
        logger.info(f"📤 Post {post.post_id} queued for publishing")
    
    # ========================================================================
    # HELPERS
    # ========================================================================
    
    async def request_crisis_script(self, candidate_id: str, issue: str, event: Dict) -> Optional[str]:
        """Request crisis response script from E9 Content AI"""
        # In production, this would call E9
        return f"Statement regarding {issue}: We take this matter seriously and are committed to transparency."
    
    async def get_voice_profile(self, candidate_id: str) -> Optional[Dict]:
        """Get candidate's voice profile from database"""
        # In production, query Supabase
        return {"voice_id": f"voice_{candidate_id}"}
    
    async def get_portrait_image(self, candidate_id: str) -> Optional[str]:
        """Get candidate's portrait image URL"""
        # In production, query Supabase
        return f"https://storage.supabase.co/portraits/{candidate_id}.jpg"
    
    async def get_candidate_phone(self, candidate_id: str) -> Optional[str]:
        """Get candidate's phone number"""
        # In production, query Supabase
        return None
    
    async def get_candidate_by_phone(self, phone: str) -> Optional[str]:
        """Get candidate ID by phone number"""
        # In production, query Supabase
        return None
    
    async def send_sms_bandwidth(self, to: str, message: str) -> bool:
        """Send SMS via Bandwidth API"""
        # In production, use Bandwidth SDK
        logger.info(f"📱 [BANDWIDTH] Would send to {to}: {message[:50]}...")
        return True
    
    def truncate_for_social(self, text: str, max_length: int = 280) -> str:
        """Truncate text for social media"""
        if len(text) <= max_length:
            return text
        return text[:max_length-3] + "..."


# ============================================================================
# DEPLOYMENT
# ============================================================================

async def run_integration_engine():
    """Run the integration engine"""
    print("=" * 70)
    print("🔗 E19 SOCIAL MEDIA INTEGRATION PATCH")
    print("=" * 70)
    print()
    print("Event Subscriptions:")
    for event, config in E19_EVENT_SUBSCRIPTIONS.items():
        print(f"  • {event} → {config['action']}")
    print()
    print("Control Panel Features:")
    for feature_id, feature in E19_CONTROL_PANEL_FEATURES.items():
        print(f"  • {feature['name']} ({feature['type']})")
    print()
    print("=" * 70)
    
    engine = SocialMediaIntegrationEngine()
    
    # Start event listener
    await engine.start_event_listener()


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        print("Deploying E19 Integration Patch...")
        # Would deploy to Hetzner
    elif len(sys.argv) > 1 and sys.argv[1] == "--nightly":
        engine = SocialMediaIntegrationEngine()
        asyncio.run(engine.run_nightly_workflow())
    else:
        asyncio.run(run_integration_engine())
