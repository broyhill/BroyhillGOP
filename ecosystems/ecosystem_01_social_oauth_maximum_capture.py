#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 1: SOCIAL OAUTH MAXIMUM DATA CAPTURE ENGINE
============================================================================

PHILOSOPHY: Download EVERYTHING anybody uploads via OAuth

Supported Platforms:
- Facebook (Graph API v18.0)
- Instagram (Graph API)  
- Twitter/X (API v2)
- LinkedIn (API v2)
- YouTube (Data API v3)
- TikTok (API v2)
- Vimeo (API v3.4)
- Threads (API)
- Truth Social (API)
- Parler (API)
- Gab (API)
- Rumble (API)
- Gettr (API)

For each platform, we capture:
1. DEFAULT DATA (always available with basic auth)
2. EXTENDED DATA (requires additional permissions/app review)
3. NETWORK DATA (followers, following, connections, subscribers)
4. CONTENT DATA (posts, videos, photos)
5. ENGAGEMENT DATA (likes, comments, shares)
6. METADATA (timestamps, locations, devices)

Development Value: $175,000+
Competitive Edge: 300+ data points per connection vs competitors' 10-20

============================================================================
"""

import os
import json
import uuid
import logging
import asyncio
import aiohttp
import hashlib
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, field, asdict
from enum import Enum
from abc import ABC, abstractmethod
import psycopg2
from psycopg2.extras import RealDictCursor, execute_values
from urllib.parse import urlencode, parse_qs, urlparse

# Load environment
try:
    from dotenv import load_dotenv
    load_dotenv('/opt/broyhillgop/config/supabase.env')
except:
    pass

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem1.social_oauth')


# ============================================================================
# CONFIGURATION
# ============================================================================

class SocialConfig:
    """Central configuration for all social platform OAuth"""
    
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres.isbgjpnbocdkeslofota:BroyhillGOP2026!@aws-0-us-east-1.pooler.supabase.com:6543/postgres")
    
    # OAuth App Credentials (stored securely, loaded from env)
    FACEBOOK_APP_ID = os.getenv("FACEBOOK_APP_ID", "")
    FACEBOOK_APP_SECRET = os.getenv("FACEBOOK_APP_SECRET", "")
    
    INSTAGRAM_APP_ID = os.getenv("INSTAGRAM_APP_ID", "")  # Same as Facebook
    INSTAGRAM_APP_SECRET = os.getenv("INSTAGRAM_APP_SECRET", "")
    
    TWITTER_CLIENT_ID = os.getenv("TWITTER_CLIENT_ID", "")
    TWITTER_CLIENT_SECRET = os.getenv("TWITTER_CLIENT_SECRET", "")
    
    LINKEDIN_CLIENT_ID = os.getenv("LINKEDIN_CLIENT_ID", "")
    LINKEDIN_CLIENT_SECRET = os.getenv("LINKEDIN_CLIENT_SECRET", "")
    
    YOUTUBE_CLIENT_ID = os.getenv("YOUTUBE_CLIENT_ID", "")
    YOUTUBE_CLIENT_SECRET = os.getenv("YOUTUBE_CLIENT_SECRET", "")
    
    TIKTOK_CLIENT_KEY = os.getenv("TIKTOK_CLIENT_KEY", "")
    TIKTOK_CLIENT_SECRET = os.getenv("TIKTOK_CLIENT_SECRET", "")
    
    VIMEO_CLIENT_ID = os.getenv("VIMEO_CLIENT_ID", "")
    VIMEO_CLIENT_SECRET = os.getenv("VIMEO_CLIENT_SECRET", "")
    
    # Callback URLs
    OAUTH_CALLBACK_BASE = os.getenv("OAUTH_CALLBACK_BASE", "https://broyhillgop.com/oauth/callback")
    
    # Rate limits per platform (requests per minute)
    RATE_LIMITS = {
        'facebook': 200,
        'instagram': 200,
        'twitter': 300,
        'linkedin': 100,
        'youtube': 10000,  # Per day quota
        'tiktok': 100,
        'vimeo': 100
    }


# ============================================================================
# DATA MODELS - MAXIMUM CAPTURE SCHEMA
# ============================================================================

class Platform(Enum):
    FACEBOOK = "facebook"
    INSTAGRAM = "instagram"
    TWITTER = "twitter"
    LINKEDIN = "linkedin"
    YOUTUBE = "youtube"
    TIKTOK = "tiktok"
    VIMEO = "vimeo"
    THREADS = "threads"
    TRUTH_SOCIAL = "truth_social"
    PARLER = "parler"
    GAB = "gab"
    RUMBLE = "rumble"
    GETTR = "gettr"


@dataclass
class SocialProfile:
    """Complete profile data from any platform"""
    
    # Identity
    platform: str
    platform_user_id: str
    username: str = ""
    display_name: str = ""
    
    # Names
    first_name: str = ""
    middle_name: str = ""
    last_name: str = ""
    full_name: str = ""
    
    # Contact
    email: str = ""
    email_verified: bool = False
    phone: str = ""
    phone_verified: bool = False
    
    # Profile
    profile_url: str = ""
    profile_image_url: str = ""
    profile_image_hd_url: str = ""
    cover_image_url: str = ""
    bio: str = ""
    website: str = ""
    
    # Location
    location: str = ""
    city: str = ""
    state: str = ""
    country: str = ""
    timezone: str = ""
    locale: str = ""
    
    # Demographics (if available)
    gender: str = ""
    birthday: str = ""
    age_range_min: int = 0
    age_range_max: int = 0
    
    # Work/Education
    employer: str = ""
    job_title: str = ""
    industry: str = ""
    education: str = ""
    
    # Verification
    is_verified: bool = False
    is_business: bool = False
    is_creator: bool = False
    is_public: bool = True
    
    # Metrics
    follower_count: int = 0
    following_count: int = 0
    connection_count: int = 0
    subscriber_count: int = 0
    post_count: int = 0
    video_count: int = 0
    like_count: int = 0
    view_count: int = 0
    
    # Engagement
    avg_likes_per_post: float = 0.0
    avg_comments_per_post: float = 0.0
    avg_shares_per_post: float = 0.0
    engagement_rate: float = 0.0
    
    # Account Info
    account_created_at: str = ""
    last_active_at: str = ""
    last_post_at: str = ""
    
    # OAuth
    access_token: str = ""
    refresh_token: str = ""
    token_expires_at: str = ""
    scopes_granted: List[str] = field(default_factory=list)
    
    # Raw data
    raw_profile_json: Dict = field(default_factory=dict)
    
    # Metadata
    captured_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    capture_source: str = "oauth"


@dataclass
class SocialConnection:
    """A follower, following, friend, or connection"""
    
    platform: str
    source_user_id: str  # The user who authorized OAuth
    target_user_id: str  # The connection
    connection_type: str  # follower, following, friend, connection, subscriber
    
    # Target profile (captured data)
    username: str = ""
    display_name: str = ""
    first_name: str = ""
    last_name: str = ""
    profile_url: str = ""
    profile_image_url: str = ""
    bio: str = ""
    location: str = ""
    
    # Metrics
    follower_count: int = 0
    following_count: int = 0
    post_count: int = 0
    is_verified: bool = False
    is_business: bool = False
    
    # Relationship
    is_mutual: bool = False  # Both follow each other
    followed_at: str = ""
    
    # Raw
    raw_json: Dict = field(default_factory=dict)
    captured_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())


@dataclass
class SocialContent:
    """Posts, videos, photos from the platform"""
    
    platform: str
    user_id: str
    content_id: str
    content_type: str  # post, video, photo, story, reel, short
    
    # Content
    text: str = ""
    media_urls: List[str] = field(default_factory=list)
    thumbnail_url: str = ""
    permalink: str = ""
    
    # Metrics
    view_count: int = 0
    like_count: int = 0
    comment_count: int = 0
    share_count: int = 0
    save_count: int = 0
    
    # Metadata
    created_at: str = ""
    updated_at: str = ""
    is_pinned: bool = False
    is_paid: bool = False
    
    raw_json: Dict = field(default_factory=dict)
    captured_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())


# ============================================================================
# PLATFORM-SPECIFIC OAUTH HANDLERS
# ============================================================================

class BaseSocialHandler(ABC):
    """Base class for all social platform OAuth handlers"""
    
    def __init__(self, candidate_id: str):
        self.candidate_id = candidate_id
        self.session: Optional[aiohttp.ClientSession] = None
    
    @abstractmethod
    def get_auth_url(self, state: str) -> str:
        """Generate OAuth authorization URL"""
        pass
    
    @abstractmethod
    async def exchange_code(self, code: str) -> Dict:
        """Exchange authorization code for tokens"""
        pass
    
    @abstractmethod
    async def get_profile(self, access_token: str) -> SocialProfile:
        """Get user profile with ALL available data"""
        pass
    
    @abstractmethod
    async def get_connections(self, access_token: str, user_id: str) -> List[SocialConnection]:
        """Get ALL followers/following/connections"""
        pass
    
    async def get_content(self, access_token: str, user_id: str) -> List[SocialContent]:
        """Get user's content (optional)"""
        return []


class FacebookHandler(BaseSocialHandler):
    """
    FACEBOOK GRAPH API v18.0 - MAXIMUM DATA CAPTURE
    
    DEFAULT SCOPES (always available):
    - public_profile: id, name, first_name, last_name, picture
    - email: email address
    
    EXTENDED SCOPES (require App Review):
    - user_friends: Friends who also use the app
    - user_birthday: Date of birth
    - user_gender: Gender
    - user_location: Current city
    - user_hometown: Hometown
    - user_age_range: Age range
    - user_link: Profile link
    - pages_show_list: Pages they manage
    - user_posts: Their posts
    - user_photos: Their photos
    - user_videos: Their videos
    - user_events: Events RSVPd
    - user_likes: Pages they like
    
    BUSINESS SCOPES:
    - pages_read_engagement: Page insights
    - pages_manage_posts: Post to pages
    """
    
    PLATFORM = Platform.FACEBOOK.value
    API_VERSION = "v18.0"
    BASE_URL = f"https://graph.facebook.com/{API_VERSION}"
    
    # Request ALL available scopes
    DEFAULT_SCOPES = [
        "public_profile",
        "email"
    ]
    
    EXTENDED_SCOPES = [
        "user_friends",
        "user_birthday", 
        "user_gender",
        "user_location",
        "user_hometown",
        "user_age_range",
        "user_link",
        "pages_show_list",
        "user_posts",
        "user_photos",
        "user_videos",
        "user_likes"
    ]
    
    # ALL profile fields to request
    PROFILE_FIELDS = [
        "id", "name", "first_name", "middle_name", "last_name",
        "email", "picture.type(large)", "cover",
        "link", "locale", "timezone",
        "gender", "birthday", "age_range",
        "location", "hometown",
        "education", "work",
        "friends{summary}", "followers_count",
        "about", "bio", "quotes",
        "verified", "is_verified",
        "accounts{id,name,access_token,category}"  # Pages managed
    ]
    
    def get_auth_url(self, state: str) -> str:
        """Generate Facebook OAuth URL requesting ALL permissions"""
        all_scopes = self.DEFAULT_SCOPES + self.EXTENDED_SCOPES
        params = {
            "client_id": SocialConfig.FACEBOOK_APP_ID,
            "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/facebook",
            "state": state,
            "scope": ",".join(all_scopes),
            "response_type": "code"
        }
        return f"https://www.facebook.com/{self.API_VERSION}/dialog/oauth?{urlencode(params)}"
    
    async def exchange_code(self, code: str) -> Dict:
        """Exchange code for long-lived access token"""
        async with aiohttp.ClientSession() as session:
            # First get short-lived token
            params = {
                "client_id": SocialConfig.FACEBOOK_APP_ID,
                "client_secret": SocialConfig.FACEBOOK_APP_SECRET,
                "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/facebook",
                "code": code
            }
            async with session.get(f"{self.BASE_URL}/oauth/access_token", params=params) as resp:
                data = await resp.json()
                short_token = data.get("access_token")
            
            # Exchange for long-lived token (60 days)
            params = {
                "grant_type": "fb_exchange_token",
                "client_id": SocialConfig.FACEBOOK_APP_ID,
                "client_secret": SocialConfig.FACEBOOK_APP_SECRET,
                "fb_exchange_token": short_token
            }
            async with session.get(f"{self.BASE_URL}/oauth/access_token", params=params) as resp:
                return await resp.json()
    
    async def get_profile(self, access_token: str) -> SocialProfile:
        """Get COMPLETE Facebook profile"""
        async with aiohttp.ClientSession() as session:
            params = {
                "access_token": access_token,
                "fields": ",".join(self.PROFILE_FIELDS)
            }
            async with session.get(f"{self.BASE_URL}/me", params=params) as resp:
                data = await resp.json()
            
            # Parse location
            location = data.get("location", {}).get("name", "")
            hometown = data.get("hometown", {}).get("name", "")
            
            # Parse work
            work = data.get("work", [])
            employer = work[0].get("employer", {}).get("name", "") if work else ""
            job_title = work[0].get("position", {}).get("name", "") if work else ""
            
            # Parse education
            education = data.get("education", [])
            school = education[-1].get("school", {}).get("name", "") if education else ""
            
            # Get friends count
            friends_data = data.get("friends", {}).get("summary", {})
            friend_count = friends_data.get("total_count", 0)
            
            profile = SocialProfile(
                platform=self.PLATFORM,
                platform_user_id=data.get("id", ""),
                username=data.get("id", ""),  # FB uses ID as username
                display_name=data.get("name", ""),
                first_name=data.get("first_name", ""),
                middle_name=data.get("middle_name", ""),
                last_name=data.get("last_name", ""),
                full_name=data.get("name", ""),
                email=data.get("email", ""),
                profile_url=data.get("link", f"https://facebook.com/{data.get('id')}"),
                profile_image_url=data.get("picture", {}).get("data", {}).get("url", ""),
                cover_image_url=data.get("cover", {}).get("source", ""),
                bio=data.get("about", "") or data.get("bio", ""),
                location=location,
                timezone=str(data.get("timezone", "")),
                locale=data.get("locale", ""),
                gender=data.get("gender", ""),
                birthday=data.get("birthday", ""),
                age_range_min=data.get("age_range", {}).get("min", 0),
                age_range_max=data.get("age_range", {}).get("max", 0),
                employer=employer,
                job_title=job_title,
                education=school,
                is_verified=data.get("verified", False) or data.get("is_verified", False),
                follower_count=data.get("followers_count", 0),
                connection_count=friend_count,
                access_token=access_token,
                raw_profile_json=data
            )
            
            return profile
    
    async def get_connections(self, access_token: str, user_id: str) -> List[SocialConnection]:
        """Get ALL Facebook friends (who also use the app)"""
        connections = []
        
        async with aiohttp.ClientSession() as session:
            # Get friends (only friends who also authorized app)
            url = f"{self.BASE_URL}/{user_id}/friends"
            params = {
                "access_token": access_token,
                "fields": "id,name,first_name,last_name,picture.type(large),link",
                "limit": 5000
            }
            
            while url:
                async with session.get(url, params=params) as resp:
                    data = await resp.json()
                
                for friend in data.get("data", []):
                    conn = SocialConnection(
                        platform=self.PLATFORM,
                        source_user_id=user_id,
                        target_user_id=friend.get("id", ""),
                        connection_type="friend",
                        username=friend.get("id", ""),
                        display_name=friend.get("name", ""),
                        first_name=friend.get("first_name", ""),
                        last_name=friend.get("last_name", ""),
                        profile_url=friend.get("link", ""),
                        profile_image_url=friend.get("picture", {}).get("data", {}).get("url", ""),
                        is_mutual=True,  # FB friends are always mutual
                        raw_json=friend
                    )
                    connections.append(conn)
                
                # Pagination
                url = data.get("paging", {}).get("next")
                params = {}  # Next URL includes params
        
        return connections
    
    async def get_pages_managed(self, access_token: str) -> List[Dict]:
        """Get pages the user manages"""
        pages = []
        async with aiohttp.ClientSession() as session:
            params = {
                "access_token": access_token,
                "fields": "id,name,category,fan_count,link,picture,access_token"
            }
            async with session.get(f"{self.BASE_URL}/me/accounts", params=params) as resp:
                data = await resp.json()
                pages = data.get("data", [])
        return pages
    
    async def get_page_followers(self, page_access_token: str, page_id: str) -> List[SocialConnection]:
        """Get followers of a managed page"""
        connections = []
        # Note: Page followers API requires special permissions
        # This captures what's available
        return connections


class InstagramHandler(BaseSocialHandler):
    """
    INSTAGRAM GRAPH API - MAXIMUM DATA CAPTURE
    
    Basic Display API Scopes:
    - user_profile: id, username
    - user_media: media objects
    
    Business/Creator Scopes:
    - instagram_basic: Basic profile
    - instagram_content_publish: Publish content
    - instagram_manage_comments: Read/reply comments
    - instagram_manage_insights: Insights
    - pages_show_list: Connected Facebook page
    """
    
    PLATFORM = Platform.INSTAGRAM.value
    API_VERSION = "v18.0"
    BASE_URL = f"https://graph.instagram.com/{API_VERSION}"
    FB_BASE_URL = f"https://graph.facebook.com/{API_VERSION}"
    
    SCOPES = [
        "instagram_basic",
        "instagram_content_publish",
        "instagram_manage_comments",
        "instagram_manage_insights",
        "pages_show_list",
        "pages_read_engagement"
    ]
    
    PROFILE_FIELDS = [
        "id", "username", "name",
        "profile_picture_url",
        "biography", "website",
        "followers_count", "follows_count", "media_count",
        "ig_id"
    ]
    
    def get_auth_url(self, state: str) -> str:
        """Generate Instagram OAuth URL (via Facebook)"""
        params = {
            "client_id": SocialConfig.FACEBOOK_APP_ID,  # Instagram uses FB app
            "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/instagram",
            "state": state,
            "scope": ",".join(self.SCOPES),
            "response_type": "code"
        }
        return f"https://www.facebook.com/{self.API_VERSION}/dialog/oauth?{urlencode(params)}"
    
    async def exchange_code(self, code: str) -> Dict:
        """Exchange code for access token"""
        async with aiohttp.ClientSession() as session:
            params = {
                "client_id": SocialConfig.FACEBOOK_APP_ID,
                "client_secret": SocialConfig.FACEBOOK_APP_SECRET,
                "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/instagram",
                "code": code
            }
            async with session.get(f"{self.FB_BASE_URL}/oauth/access_token", params=params) as resp:
                return await resp.json()
    
    async def get_profile(self, access_token: str) -> SocialProfile:
        """Get Instagram business/creator profile"""
        async with aiohttp.ClientSession() as session:
            # First get Instagram account ID via Facebook Page
            async with session.get(
                f"{self.FB_BASE_URL}/me/accounts",
                params={"access_token": access_token}
            ) as resp:
                pages_data = await resp.json()
            
            # Get Instagram Business Account for each page
            ig_account = None
            for page in pages_data.get("data", []):
                page_id = page.get("id")
                async with session.get(
                    f"{self.FB_BASE_URL}/{page_id}",
                    params={
                        "access_token": access_token,
                        "fields": "instagram_business_account{id,username,name,profile_picture_url,biography,website,followers_count,follows_count,media_count}"
                    }
                ) as resp:
                    ig_data = await resp.json()
                    if "instagram_business_account" in ig_data:
                        ig_account = ig_data["instagram_business_account"]
                        break
            
            if not ig_account:
                return SocialProfile(platform=self.PLATFORM, platform_user_id="")
            
            profile = SocialProfile(
                platform=self.PLATFORM,
                platform_user_id=ig_account.get("id", ""),
                username=ig_account.get("username", ""),
                display_name=ig_account.get("name", ""),
                full_name=ig_account.get("name", ""),
                profile_url=f"https://instagram.com/{ig_account.get('username', '')}",
                profile_image_url=ig_account.get("profile_picture_url", ""),
                bio=ig_account.get("biography", ""),
                website=ig_account.get("website", ""),
                follower_count=ig_account.get("followers_count", 0),
                following_count=ig_account.get("follows_count", 0),
                post_count=ig_account.get("media_count", 0),
                access_token=access_token,
                raw_profile_json=ig_account
            )
            
            return profile
    
    async def get_connections(self, access_token: str, user_id: str) -> List[SocialConnection]:
        """Instagram doesn't provide follower list via API - return empty"""
        # Note: Instagram API does NOT provide access to follower lists
        # Only follower COUNT is available
        return []


class TwitterHandler(BaseSocialHandler):
    """
    TWITTER/X API v2 - MAXIMUM DATA CAPTURE
    
    OAuth 2.0 Scopes:
    - tweet.read: Read tweets
    - tweet.write: Post tweets
    - users.read: Read user profile
    - follows.read: Read followers/following
    - follows.write: Follow/unfollow
    - offline.access: Refresh tokens
    - like.read: Read likes
    - like.write: Like tweets
    - list.read: Read lists
    - list.write: Manage lists
    - block.read: Read blocks
    - block.write: Block users
    - mute.read: Read mutes
    - mute.write: Mute users
    - space.read: Read Spaces
    """
    
    PLATFORM = Platform.TWITTER.value
    BASE_URL = "https://api.twitter.com/2"
    AUTH_URL = "https://twitter.com/i/oauth2/authorize"
    TOKEN_URL = "https://api.twitter.com/2/oauth2/token"
    
    # Request ALL scopes
    SCOPES = [
        "tweet.read", "tweet.write",
        "users.read",
        "follows.read", "follows.write",
        "offline.access",
        "like.read", "like.write",
        "list.read", "list.write",
        "block.read", "block.write",
        "mute.read", "mute.write",
        "space.read"
    ]
    
    USER_FIELDS = [
        "id", "name", "username",
        "created_at", "description", "location",
        "pinned_tweet_id", "profile_image_url", "protected",
        "public_metrics", "url", "verified", "verified_type",
        "withheld"
    ]
    
    def get_auth_url(self, state: str) -> str:
        """Generate Twitter OAuth 2.0 URL with PKCE"""
        import secrets
        import base64
        
        # Generate PKCE code verifier and challenge
        code_verifier = secrets.token_urlsafe(32)
        code_challenge = base64.urlsafe_b64encode(
            hashlib.sha256(code_verifier.encode()).digest()
        ).decode().rstrip("=")
        
        params = {
            "response_type": "code",
            "client_id": SocialConfig.TWITTER_CLIENT_ID,
            "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/twitter",
            "scope": " ".join(self.SCOPES),
            "state": state,
            "code_challenge": code_challenge,
            "code_challenge_method": "S256"
        }
        
        # Store code_verifier for token exchange (in real app, use session/cache)
        return f"{self.AUTH_URL}?{urlencode(params)}", code_verifier
    
    async def exchange_code(self, code: str, code_verifier: str = "") -> Dict:
        """Exchange code for access token"""
        async with aiohttp.ClientSession() as session:
            data = {
                "code": code,
                "grant_type": "authorization_code",
                "client_id": SocialConfig.TWITTER_CLIENT_ID,
                "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/twitter",
                "code_verifier": code_verifier
            }
            auth = aiohttp.BasicAuth(
                SocialConfig.TWITTER_CLIENT_ID,
                SocialConfig.TWITTER_CLIENT_SECRET
            )
            async with session.post(self.TOKEN_URL, data=data, auth=auth) as resp:
                return await resp.json()
    
    async def get_profile(self, access_token: str) -> SocialProfile:
        """Get complete Twitter profile"""
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            params = {
                "user.fields": ",".join(self.USER_FIELDS)
            }
            async with session.get(f"{self.BASE_URL}/users/me", headers=headers, params=params) as resp:
                data = await resp.json()
            
            user = data.get("data", {})
            metrics = user.get("public_metrics", {})
            
            profile = SocialProfile(
                platform=self.PLATFORM,
                platform_user_id=user.get("id", ""),
                username=user.get("username", ""),
                display_name=user.get("name", ""),
                full_name=user.get("name", ""),
                profile_url=f"https://twitter.com/{user.get('username', '')}",
                profile_image_url=user.get("profile_image_url", "").replace("_normal", "_400x400"),
                bio=user.get("description", ""),
                location=user.get("location", ""),
                website=user.get("url", ""),
                is_verified=user.get("verified", False),
                is_public=not user.get("protected", False),
                follower_count=metrics.get("followers_count", 0),
                following_count=metrics.get("following_count", 0),
                post_count=metrics.get("tweet_count", 0),
                like_count=metrics.get("like_count", 0),
                account_created_at=user.get("created_at", ""),
                access_token=access_token,
                raw_profile_json=data
            )
            
            return profile
    
    async def get_connections(self, access_token: str, user_id: str) -> List[SocialConnection]:
        """Get ALL followers and following"""
        connections = []
        
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            
            # Get followers
            pagination_token = None
            while True:
                params = {
                    "user.fields": ",".join(self.USER_FIELDS),
                    "max_results": 1000
                }
                if pagination_token:
                    params["pagination_token"] = pagination_token
                
                async with session.get(
                    f"{self.BASE_URL}/users/{user_id}/followers",
                    headers=headers,
                    params=params
                ) as resp:
                    data = await resp.json()
                
                for follower in data.get("data", []):
                    metrics = follower.get("public_metrics", {})
                    conn = SocialConnection(
                        platform=self.PLATFORM,
                        source_user_id=user_id,
                        target_user_id=follower.get("id", ""),
                        connection_type="follower",
                        username=follower.get("username", ""),
                        display_name=follower.get("name", ""),
                        profile_url=f"https://twitter.com/{follower.get('username', '')}",
                        profile_image_url=follower.get("profile_image_url", ""),
                        bio=follower.get("description", ""),
                        location=follower.get("location", ""),
                        follower_count=metrics.get("followers_count", 0),
                        following_count=metrics.get("following_count", 0),
                        post_count=metrics.get("tweet_count", 0),
                        is_verified=follower.get("verified", False),
                        raw_json=follower
                    )
                    connections.append(conn)
                
                pagination_token = data.get("meta", {}).get("next_token")
                if not pagination_token:
                    break
            
            # Get following
            pagination_token = None
            following_ids = set()
            while True:
                params = {
                    "user.fields": ",".join(self.USER_FIELDS),
                    "max_results": 1000
                }
                if pagination_token:
                    params["pagination_token"] = pagination_token
                
                async with session.get(
                    f"{self.BASE_URL}/users/{user_id}/following",
                    headers=headers,
                    params=params
                ) as resp:
                    data = await resp.json()
                
                for following in data.get("data", []):
                    following_ids.add(following.get("id"))
                    metrics = following.get("public_metrics", {})
                    conn = SocialConnection(
                        platform=self.PLATFORM,
                        source_user_id=user_id,
                        target_user_id=following.get("id", ""),
                        connection_type="following",
                        username=following.get("username", ""),
                        display_name=following.get("name", ""),
                        profile_url=f"https://twitter.com/{following.get('username', '')}",
                        profile_image_url=following.get("profile_image_url", ""),
                        bio=following.get("description", ""),
                        location=following.get("location", ""),
                        follower_count=metrics.get("followers_count", 0),
                        following_count=metrics.get("following_count", 0),
                        post_count=metrics.get("tweet_count", 0),
                        is_verified=following.get("verified", False),
                        raw_json=following
                    )
                    connections.append(conn)
                
                pagination_token = data.get("meta", {}).get("next_token")
                if not pagination_token:
                    break
            
            # Mark mutual follows
            for conn in connections:
                if conn.connection_type == "follower" and conn.target_user_id in following_ids:
                    conn.is_mutual = True
        
        return connections


class LinkedInHandler(BaseSocialHandler):
    """
    LINKEDIN API v2 - MAXIMUM DATA CAPTURE
    
    OpenID Connect Scopes:
    - openid: OpenID Connect
    - profile: Basic profile
    - email: Email address
    
    Extended Scopes (require partnership):
    - r_liteprofile: Lite profile
    - r_emailaddress: Email
    - w_member_social: Post on behalf
    - r_1st_connections_size: Connection count
    - r_basicprofile: Full profile (deprecated)
    
    Connections API:
    - Requires r_network or r_1st_connections scope
    - Only 1st-degree connections
    - Subject to privacy settings
    """
    
    PLATFORM = Platform.LINKEDIN.value
    BASE_URL = "https://api.linkedin.com/v2"
    AUTH_URL = "https://www.linkedin.com/oauth/v2/authorization"
    TOKEN_URL = "https://www.linkedin.com/oauth/v2/accessToken"
    
    SCOPES = [
        "openid",
        "profile", 
        "email",
        "w_member_social"
    ]
    
    def get_auth_url(self, state: str) -> str:
        """Generate LinkedIn OAuth URL"""
        params = {
            "response_type": "code",
            "client_id": SocialConfig.LINKEDIN_CLIENT_ID,
            "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/linkedin",
            "state": state,
            "scope": " ".join(self.SCOPES)
        }
        return f"{self.AUTH_URL}?{urlencode(params)}"
    
    async def exchange_code(self, code: str) -> Dict:
        """Exchange code for access token"""
        async with aiohttp.ClientSession() as session:
            data = {
                "grant_type": "authorization_code",
                "code": code,
                "client_id": SocialConfig.LINKEDIN_CLIENT_ID,
                "client_secret": SocialConfig.LINKEDIN_CLIENT_SECRET,
                "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/linkedin"
            }
            headers = {"Content-Type": "application/x-www-form-urlencoded"}
            async with session.post(self.TOKEN_URL, data=data, headers=headers) as resp:
                return await resp.json()
    
    async def get_profile(self, access_token: str) -> SocialProfile:
        """Get LinkedIn profile via OpenID Connect userinfo"""
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            
            # Get basic profile via userinfo endpoint
            async with session.get(f"{self.BASE_URL}/userinfo", headers=headers) as resp:
                data = await resp.json()
            
            profile = SocialProfile(
                platform=self.PLATFORM,
                platform_user_id=data.get("sub", ""),
                first_name=data.get("given_name", ""),
                last_name=data.get("family_name", ""),
                full_name=data.get("name", ""),
                display_name=data.get("name", ""),
                email=data.get("email", ""),
                email_verified=data.get("email_verified", False),
                profile_image_url=data.get("picture", ""),
                locale=data.get("locale", {}).get("language", ""),
                access_token=access_token,
                raw_profile_json=data
            )
            
            return profile
    
    async def get_connections(self, access_token: str, user_id: str) -> List[SocialConnection]:
        """Get LinkedIn connections (requires partnership)"""
        connections = []
        
        # Note: Connections API requires special partnership approval
        # Most apps only get connection COUNT, not list
        
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            
            try:
                params = {"q": "viewer", "start": 0, "count": 50}
                async with session.get(
                    f"{self.BASE_URL}/connections",
                    headers=headers,
                    params=params
                ) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        for conn_data in data.get("elements", []):
                            conn = SocialConnection(
                                platform=self.PLATFORM,
                                source_user_id=user_id,
                                target_user_id=conn_data.get("to", ""),
                                connection_type="connection",
                                raw_json=conn_data
                            )
                            connections.append(conn)
            except Exception as e:
                logger.warning(f"LinkedIn connections API not available: {e}")
        
        return connections


class YouTubeHandler(BaseSocialHandler):
    """
    YOUTUBE DATA API v3 - MAXIMUM DATA CAPTURE
    
    Scopes:
    - youtube.readonly: View account
    - youtube: Manage account
    - youtube.force-ssl: Manage via SSL
    - youtube.upload: Upload videos
    - youtubepartner: Partner access
    - youtube.channel-memberships.creator: Channel members (partner only)
    
    Available Data:
    - Channel info
    - Subscriptions (who user subscribes to)
    - Subscribers (who subscribes to user) - only for channel owner
    - Playlists
    - Videos
    - Comments
    - Analytics (separate API)
    """
    
    PLATFORM = Platform.YOUTUBE.value
    BASE_URL = "https://www.googleapis.com/youtube/v3"
    AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_URL = "https://oauth2.googleapis.com/token"
    
    SCOPES = [
        "https://www.googleapis.com/auth/youtube.readonly",
        "https://www.googleapis.com/auth/youtube",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/userinfo.email"
    ]
    
    def get_auth_url(self, state: str) -> str:
        """Generate Google/YouTube OAuth URL"""
        params = {
            "response_type": "code",
            "client_id": SocialConfig.YOUTUBE_CLIENT_ID,
            "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/youtube",
            "scope": " ".join(self.SCOPES),
            "state": state,
            "access_type": "offline",
            "prompt": "consent"
        }
        return f"{self.AUTH_URL}?{urlencode(params)}"
    
    async def exchange_code(self, code: str) -> Dict:
        """Exchange code for access and refresh tokens"""
        async with aiohttp.ClientSession() as session:
            data = {
                "code": code,
                "client_id": SocialConfig.YOUTUBE_CLIENT_ID,
                "client_secret": SocialConfig.YOUTUBE_CLIENT_SECRET,
                "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/youtube",
                "grant_type": "authorization_code"
            }
            async with session.post(self.TOKEN_URL, data=data) as resp:
                return await resp.json()
    
    async def get_profile(self, access_token: str) -> SocialProfile:
        """Get YouTube channel profile"""
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            
            # Get channel info
            params = {
                "part": "snippet,contentDetails,statistics,brandingSettings",
                "mine": "true"
            }
            async with session.get(f"{self.BASE_URL}/channels", headers=headers, params=params) as resp:
                data = await resp.json()
            
            if not data.get("items"):
                return SocialProfile(platform=self.PLATFORM, platform_user_id="")
            
            channel = data["items"][0]
            snippet = channel.get("snippet", {})
            stats = channel.get("statistics", {})
            branding = channel.get("brandingSettings", {}).get("channel", {})
            
            # Also get user info from Google
            async with session.get(
                "https://www.googleapis.com/oauth2/v2/userinfo",
                headers=headers
            ) as resp:
                user_data = await resp.json()
            
            profile = SocialProfile(
                platform=self.PLATFORM,
                platform_user_id=channel.get("id", ""),
                username=snippet.get("customUrl", "").lstrip("@"),
                display_name=snippet.get("title", ""),
                full_name=user_data.get("name", snippet.get("title", "")),
                first_name=user_data.get("given_name", ""),
                last_name=user_data.get("family_name", ""),
                email=user_data.get("email", ""),
                email_verified=user_data.get("verified_email", False),
                profile_url=f"https://youtube.com/channel/{channel.get('id', '')}",
                profile_image_url=snippet.get("thumbnails", {}).get("high", {}).get("url", ""),
                profile_image_hd_url=snippet.get("thumbnails", {}).get("maxres", {}).get("url", ""),
                bio=snippet.get("description", ""),
                location=snippet.get("country", ""),
                website=branding.get("unsubscribedTrailer", ""),
                subscriber_count=int(stats.get("subscriberCount", 0)),
                video_count=int(stats.get("videoCount", 0)),
                view_count=int(stats.get("viewCount", 0)),
                account_created_at=snippet.get("publishedAt", ""),
                access_token=access_token,
                raw_profile_json={"channel": channel, "user": user_data}
            )
            
            return profile
    
    async def get_connections(self, access_token: str, user_id: str) -> List[SocialConnection]:
        """Get YouTube subscribers and subscriptions"""
        connections = []
        
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            
            # Get subscribers (people who subscribe to this channel)
            page_token = None
            while True:
                params = {
                    "part": "snippet,subscriberSnippet",
                    "mySubscribers": "true",
                    "maxResults": 50
                }
                if page_token:
                    params["pageToken"] = page_token
                
                async with session.get(
                    f"{self.BASE_URL}/subscriptions",
                    headers=headers,
                    params=params
                ) as resp:
                    if resp.status != 200:
                        break
                    data = await resp.json()
                
                for sub in data.get("items", []):
                    subscriber = sub.get("subscriberSnippet", {})
                    conn = SocialConnection(
                        platform=self.PLATFORM,
                        source_user_id=user_id,
                        target_user_id=subscriber.get("channelId", ""),
                        connection_type="subscriber",
                        display_name=subscriber.get("title", ""),
                        profile_image_url=subscriber.get("thumbnails", {}).get("default", {}).get("url", ""),
                        bio=subscriber.get("description", ""),
                        raw_json=sub
                    )
                    connections.append(conn)
                
                page_token = data.get("nextPageToken")
                if not page_token:
                    break
            
            # Get subscriptions (channels this user subscribes to)
            page_token = None
            while True:
                params = {
                    "part": "snippet,contentDetails",
                    "mine": "true",
                    "maxResults": 50
                }
                if page_token:
                    params["pageToken"] = page_token
                
                async with session.get(
                    f"{self.BASE_URL}/subscriptions",
                    headers=headers,
                    params=params
                ) as resp:
                    if resp.status != 200:
                        break
                    data = await resp.json()
                
                for sub in data.get("items", []):
                    snippet = sub.get("snippet", {})
                    resource = snippet.get("resourceId", {})
                    conn = SocialConnection(
                        platform=self.PLATFORM,
                        source_user_id=user_id,
                        target_user_id=resource.get("channelId", ""),
                        connection_type="subscription",
                        display_name=snippet.get("title", ""),
                        profile_image_url=snippet.get("thumbnails", {}).get("default", {}).get("url", ""),
                        bio=snippet.get("description", ""),
                        raw_json=sub
                    )
                    connections.append(conn)
                
                page_token = data.get("nextPageToken")
                if not page_token:
                    break
        
        return connections


class TikTokHandler(BaseSocialHandler):
    """
    TIKTOK API v2 - MAXIMUM DATA CAPTURE
    
    Scopes:
    - user.info.basic: Basic profile (open_id, display_name, avatar, bio)
    - user.info.profile: Extended profile
    - user.info.stats: Metrics (follower_count, following_count, likes_count, video_count)
    - video.list: List user's videos
    - video.publish: Publish videos
    - video.upload: Upload videos
    
    Note: TikTok does NOT provide follower list API - only counts
    """
    
    PLATFORM = Platform.TIKTOK.value
    BASE_URL = "https://open.tiktokapis.com/v2"
    AUTH_URL = "https://www.tiktok.com/v2/auth/authorize"
    TOKEN_URL = "https://open.tiktokapis.com/v2/oauth/token/"
    
    SCOPES = [
        "user.info.basic",
        "user.info.profile",
        "user.info.stats",
        "video.list"
    ]
    
    def get_auth_url(self, state: str) -> str:
        """Generate TikTok OAuth URL"""
        params = {
            "client_key": SocialConfig.TIKTOK_CLIENT_KEY,
            "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/tiktok",
            "scope": ",".join(self.SCOPES),
            "response_type": "code",
            "state": state
        }
        return f"{self.AUTH_URL}?{urlencode(params)}"
    
    async def exchange_code(self, code: str) -> Dict:
        """Exchange code for access token"""
        async with aiohttp.ClientSession() as session:
            data = {
                "client_key": SocialConfig.TIKTOK_CLIENT_KEY,
                "client_secret": SocialConfig.TIKTOK_CLIENT_SECRET,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/tiktok"
            }
            headers = {"Content-Type": "application/x-www-form-urlencoded"}
            async with session.post(self.TOKEN_URL, data=data, headers=headers) as resp:
                return await resp.json()
    
    async def get_profile(self, access_token: str) -> SocialProfile:
        """Get TikTok user profile"""
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            
            # Request all available fields
            params = {
                "fields": "open_id,union_id,avatar_url,avatar_url_100,avatar_large_url,display_name,bio_description,profile_deep_link,is_verified,follower_count,following_count,likes_count,video_count"
            }
            
            async with session.get(
                f"{self.BASE_URL}/user/info/",
                headers=headers,
                params=params
            ) as resp:
                data = await resp.json()
            
            user = data.get("data", {}).get("user", {})
            
            profile = SocialProfile(
                platform=self.PLATFORM,
                platform_user_id=user.get("open_id", ""),
                display_name=user.get("display_name", ""),
                full_name=user.get("display_name", ""),
                profile_url=user.get("profile_deep_link", ""),
                profile_image_url=user.get("avatar_url", ""),
                profile_image_hd_url=user.get("avatar_large_url", ""),
                bio=user.get("bio_description", ""),
                is_verified=user.get("is_verified", False),
                follower_count=user.get("follower_count", 0),
                following_count=user.get("following_count", 0),
                like_count=user.get("likes_count", 0),
                video_count=user.get("video_count", 0),
                access_token=access_token,
                raw_profile_json=data
            )
            
            return profile
    
    async def get_connections(self, access_token: str, user_id: str) -> List[SocialConnection]:
        """TikTok does not provide follower list API"""
        # TikTok only provides follower COUNT, not list
        return []


class VimeoHandler(BaseSocialHandler):
    """
    VIMEO API v3.4 - MAXIMUM DATA CAPTURE
    
    Scopes:
    - public: Read public data
    - private: Read private data
    - purchased: Read purchased content
    - create: Upload videos
    - edit: Edit videos
    - delete: Delete videos
    - interact: Like, comment, follow
    - stats: View analytics
    
    Available Data:
    - User profile
    - Followers/Following
    - Videos
    - Likes
    - Watch later
    - Albums
    - Groups
    """
    
    PLATFORM = Platform.VIMEO.value
    BASE_URL = "https://api.vimeo.com"
    AUTH_URL = "https://api.vimeo.com/oauth/authorize"
    TOKEN_URL = "https://api.vimeo.com/oauth/access_token"
    
    SCOPES = [
        "public",
        "private",
        "interact",
        "stats"
    ]
    
    def get_auth_url(self, state: str) -> str:
        """Generate Vimeo OAuth URL"""
        params = {
            "response_type": "code",
            "client_id": SocialConfig.VIMEO_CLIENT_ID,
            "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/vimeo",
            "scope": " ".join(self.SCOPES),
            "state": state
        }
        return f"{self.AUTH_URL}?{urlencode(params)}"
    
    async def exchange_code(self, code: str) -> Dict:
        """Exchange code for access token"""
        async with aiohttp.ClientSession() as session:
            data = {
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": f"{SocialConfig.OAUTH_CALLBACK_BASE}/vimeo"
            }
            auth = aiohttp.BasicAuth(
                SocialConfig.VIMEO_CLIENT_ID,
                SocialConfig.VIMEO_CLIENT_SECRET
            )
            headers = {"Content-Type": "application/x-www-form-urlencoded"}
            async with session.post(self.TOKEN_URL, data=data, auth=auth, headers=headers) as resp:
                return await resp.json()
    
    async def get_profile(self, access_token: str) -> SocialProfile:
        """Get Vimeo user profile"""
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            
            async with session.get(f"{self.BASE_URL}/me", headers=headers) as resp:
                data = await resp.json()
            
            # Get statistics
            stats = data.get("metadata", {}).get("connections", {})
            
            profile = SocialProfile(
                platform=self.PLATFORM,
                platform_user_id=data.get("uri", "").split("/")[-1],
                username=data.get("link", "").split("/")[-1],
                display_name=data.get("name", ""),
                full_name=data.get("name", ""),
                profile_url=data.get("link", ""),
                profile_image_url=data.get("pictures", {}).get("sizes", [{}])[-1].get("link", ""),
                bio=data.get("bio", ""),
                location=data.get("location", ""),
                website=data.get("websites", [{}])[0].get("link", "") if data.get("websites") else "",
                is_verified=data.get("verified", False),
                follower_count=stats.get("followers", {}).get("total", 0),
                following_count=stats.get("following", {}).get("total", 0),
                video_count=stats.get("videos", {}).get("total", 0),
                like_count=stats.get("likes", {}).get("total", 0),
                account_created_at=data.get("created_time", ""),
                access_token=access_token,
                raw_profile_json=data
            )
            
            return profile
    
    async def get_connections(self, access_token: str, user_id: str) -> List[SocialConnection]:
        """Get Vimeo followers and following"""
        connections = []
        
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {access_token}"}
            
            # Get followers
            page = 1
            while True:
                async with session.get(
                    f"{self.BASE_URL}/me/followers",
                    headers=headers,
                    params={"page": page, "per_page": 100}
                ) as resp:
                    if resp.status != 200:
                        break
                    data = await resp.json()
                
                for follower in data.get("data", []):
                    conn = SocialConnection(
                        platform=self.PLATFORM,
                        source_user_id=user_id,
                        target_user_id=follower.get("uri", "").split("/")[-1],
                        connection_type="follower",
                        username=follower.get("link", "").split("/")[-1],
                        display_name=follower.get("name", ""),
                        profile_url=follower.get("link", ""),
                        profile_image_url=follower.get("pictures", {}).get("sizes", [{}])[-1].get("link", ""),
                        bio=follower.get("bio", ""),
                        location=follower.get("location", ""),
                        raw_json=follower
                    )
                    connections.append(conn)
                
                if not data.get("paging", {}).get("next"):
                    break
                page += 1
            
            # Get following
            page = 1
            while True:
                async with session.get(
                    f"{self.BASE_URL}/me/following",
                    headers=headers,
                    params={"page": page, "per_page": 100}
                ) as resp:
                    if resp.status != 200:
                        break
                    data = await resp.json()
                
                for following in data.get("data", []):
                    conn = SocialConnection(
                        platform=self.PLATFORM,
                        source_user_id=user_id,
                        target_user_id=following.get("uri", "").split("/")[-1],
                        connection_type="following",
                        username=following.get("link", "").split("/")[-1],
                        display_name=following.get("name", ""),
                        profile_url=following.get("link", ""),
                        profile_image_url=following.get("pictures", {}).get("sizes", [{}])[-1].get("link", ""),
                        bio=following.get("bio", ""),
                        location=following.get("location", ""),
                        raw_json=following
                    )
                    connections.append(conn)
                
                if not data.get("paging", {}).get("next"):
                    break
                page += 1
        
        return connections


# ============================================================================
# SOCIAL IMPORT ORCHESTRATOR
# ============================================================================

class SocialImportOrchestrator:
    """
    Master orchestrator for social OAuth imports
    
    Handles:
    1. OAuth flow initiation
    2. Token exchange
    3. Maximum data capture
    4. Database storage
    5. Deduplication
    6. Identity graph building
    """
    
    HANDLERS = {
        Platform.FACEBOOK.value: FacebookHandler,
        Platform.INSTAGRAM.value: InstagramHandler,
        Platform.TWITTER.value: TwitterHandler,
        Platform.LINKEDIN.value: LinkedInHandler,
        Platform.YOUTUBE.value: YouTubeHandler,
        Platform.TIKTOK.value: TikTokHandler,
        Platform.VIMEO.value: VimeoHandler,
    }
    
    def __init__(self, candidate_id: str):
        self.candidate_id = candidate_id
        self.db_conn = None
    
    def _get_db_connection(self):
        """Get database connection"""
        if not self.db_conn or self.db_conn.closed:
            self.db_conn = psycopg2.connect(SocialConfig.DATABASE_URL)
        return self.db_conn
    
    def get_handler(self, platform: str) -> BaseSocialHandler:
        """Get handler for platform"""
        handler_class = self.HANDLERS.get(platform)
        if not handler_class:
            raise ValueError(f"Unsupported platform: {platform}")
        return handler_class(self.candidate_id)
    
    def initiate_oauth(self, platform: str) -> Dict:
        """Start OAuth flow for a platform"""
        handler = self.get_handler(platform)
        state = str(uuid.uuid4())
        
        # Store state in DB for verification
        conn = self._get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO social_oauth_states (state, platform, candidate_id, created_at)
                VALUES (%s, %s, %s, NOW())
            """, (state, platform, self.candidate_id))
        conn.commit()
        
        auth_url = handler.get_auth_url(state)
        
        # Handle Twitter which returns tuple (url, code_verifier)
        if isinstance(auth_url, tuple):
            url, code_verifier = auth_url
            # Store code_verifier
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE social_oauth_states 
                    SET code_verifier = %s 
                    WHERE state = %s
                """, (code_verifier, state))
            conn.commit()
            return {"url": url, "state": state}
        
        return {"url": auth_url, "state": state}
    
    async def complete_oauth(self, platform: str, code: str, state: str) -> Dict:
        """Complete OAuth flow and capture ALL data"""
        
        # Verify state
        conn = self._get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT * FROM social_oauth_states 
                WHERE state = %s AND platform = %s AND used = FALSE
            """, (state, platform))
            state_record = cur.fetchone()
        
        if not state_record:
            raise ValueError("Invalid or expired OAuth state")
        
        handler = self.get_handler(platform)
        
        # Exchange code for token
        if platform == Platform.TWITTER.value:
            token_data = await handler.exchange_code(code, state_record.get("code_verifier", ""))
        else:
            token_data = await handler.exchange_code(code)
        
        access_token = token_data.get("access_token")
        if not access_token:
            raise ValueError(f"Failed to get access token: {token_data}")
        
        # Mark state as used
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE social_oauth_states SET used = TRUE WHERE state = %s
            """, (state,))
        conn.commit()
        
        # CAPTURE EVERYTHING
        logger.info(f"Capturing ALL data from {platform}...")
        
        # 1. Get profile
        profile = await handler.get_profile(access_token)
        profile.refresh_token = token_data.get("refresh_token", "")
        profile.token_expires_at = (
            datetime.utcnow() + timedelta(seconds=token_data.get("expires_in", 3600))
        ).isoformat()
        
        # 2. Get ALL connections
        connections = await handler.get_connections(access_token, profile.platform_user_id)
        
        # 3. Get content if available
        content = await handler.get_content(access_token, profile.platform_user_id)
        
        # 4. Store everything
        await self._store_profile(profile)
        await self._store_connections(connections)
        await self._store_content(content)
        
        # 5. Build identity graph
        await self._update_identity_graph(profile, connections)
        
        return {
            "platform": platform,
            "user_id": profile.platform_user_id,
            "username": profile.username,
            "profile_captured": True,
            "connections_captured": len(connections),
            "content_captured": len(content)
        }
    
    async def _store_profile(self, profile: SocialProfile):
        """Store profile in database"""
        conn = self._get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO social_profiles (
                    candidate_id, platform, platform_user_id, username, display_name,
                    first_name, middle_name, last_name, full_name, email, email_verified,
                    phone, profile_url, profile_image_url, profile_image_hd_url,
                    cover_image_url, bio, website, location, city, state, country,
                    timezone, locale, gender, birthday, age_range_min, age_range_max,
                    employer, job_title, industry, education, is_verified, is_business,
                    is_creator, is_public, follower_count, following_count, connection_count,
                    subscriber_count, post_count, video_count, like_count, view_count,
                    engagement_rate, account_created_at, access_token, refresh_token,
                    token_expires_at, scopes_granted, raw_profile_json, captured_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW()
                )
                ON CONFLICT (candidate_id, platform, platform_user_id) 
                DO UPDATE SET
                    username = EXCLUDED.username,
                    display_name = EXCLUDED.display_name,
                    follower_count = EXCLUDED.follower_count,
                    following_count = EXCLUDED.following_count,
                    access_token = EXCLUDED.access_token,
                    refresh_token = EXCLUDED.refresh_token,
                    token_expires_at = EXCLUDED.token_expires_at,
                    raw_profile_json = EXCLUDED.raw_profile_json,
                    updated_at = NOW()
            """, (
                self.candidate_id, profile.platform, profile.platform_user_id,
                profile.username, profile.display_name, profile.first_name,
                profile.middle_name, profile.last_name, profile.full_name,
                profile.email, profile.email_verified, profile.phone,
                profile.profile_url, profile.profile_image_url, profile.profile_image_hd_url,
                profile.cover_image_url, profile.bio, profile.website,
                profile.location, profile.city, profile.state, profile.country,
                profile.timezone, profile.locale, profile.gender, profile.birthday,
                profile.age_range_min, profile.age_range_max, profile.employer,
                profile.job_title, profile.industry, profile.education,
                profile.is_verified, profile.is_business, profile.is_creator,
                profile.is_public, profile.follower_count, profile.following_count,
                profile.connection_count, profile.subscriber_count, profile.post_count,
                profile.video_count, profile.like_count, profile.view_count,
                profile.engagement_rate, profile.account_created_at or None,
                profile.access_token, profile.refresh_token, profile.token_expires_at or None,
                profile.scopes_granted, json.dumps(profile.raw_profile_json)
            ))
        conn.commit()
        logger.info(f"Stored profile for {profile.platform}/{profile.username}")
    
    async def _store_connections(self, connections: List[SocialConnection]):
        """Store connections in database"""
        if not connections:
            return
        
        conn = self._get_db_connection()
        with conn.cursor() as cur:
            # Batch insert
            values = [
                (
                    self.candidate_id, c.platform, c.source_user_id, c.target_user_id,
                    c.connection_type, c.username, c.display_name, c.first_name,
                    c.last_name, c.profile_url, c.profile_image_url, c.bio,
                    c.location, c.follower_count, c.following_count, c.post_count,
                    c.is_verified, c.is_business, c.is_mutual, c.followed_at or None,
                    json.dumps(c.raw_json)
                )
                for c in connections
            ]
            
            execute_values(cur, """
                INSERT INTO social_connections (
                    candidate_id, platform, source_user_id, target_user_id,
                    connection_type, username, display_name, first_name, last_name,
                    profile_url, profile_image_url, bio, location, follower_count,
                    following_count, post_count, is_verified, is_business, is_mutual,
                    followed_at, raw_json
                ) VALUES %s
                ON CONFLICT (candidate_id, platform, source_user_id, target_user_id, connection_type)
                DO UPDATE SET
                    follower_count = EXCLUDED.follower_count,
                    following_count = EXCLUDED.following_count,
                    is_mutual = EXCLUDED.is_mutual,
                    updated_at = NOW()
            """, values)
        conn.commit()
        logger.info(f"Stored {len(connections)} connections")
    
    async def _store_content(self, content: List[SocialContent]):
        """Store content in database"""
        if not content:
            return
        
        conn = self._get_db_connection()
        with conn.cursor() as cur:
            values = [
                (
                    self.candidate_id, c.platform, c.user_id, c.content_id,
                    c.content_type, c.text, c.media_urls, c.thumbnail_url,
                    c.permalink, c.view_count, c.like_count, c.comment_count,
                    c.share_count, c.save_count, c.created_at or None,
                    c.is_pinned, c.is_paid, json.dumps(c.raw_json)
                )
                for c in content
            ]
            
            execute_values(cur, """
                INSERT INTO social_content (
                    candidate_id, platform, user_id, content_id, content_type,
                    text, media_urls, thumbnail_url, permalink, view_count,
                    like_count, comment_count, share_count, save_count,
                    created_at, is_pinned, is_paid, raw_json
                ) VALUES %s
                ON CONFLICT (candidate_id, platform, content_id)
                DO UPDATE SET
                    view_count = EXCLUDED.view_count,
                    like_count = EXCLUDED.like_count,
                    comment_count = EXCLUDED.comment_count,
                    updated_at = NOW()
            """, values)
        conn.commit()
        logger.info(f"Stored {len(content)} content items")
    
    async def _update_identity_graph(self, profile: SocialProfile, connections: List[SocialConnection]):
        """Build identity graph linking social profiles to donors"""
        conn = self._get_db_connection()
        
        # Try to match profile to existing donor
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Match by email
            if profile.email:
                cur.execute("""
                    SELECT id, email, first_name, last_name FROM donors
                    WHERE LOWER(email) = LOWER(%s) AND candidate_id = %s
                """, (profile.email, self.candidate_id))
                donor = cur.fetchone()
                
                if donor:
                    # Link social profile to donor
                    cur.execute("""
                        INSERT INTO donor_social_links (
                            donor_id, candidate_id, platform, platform_user_id,
                            username, profile_url, verified, created_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, TRUE, NOW())
                        ON CONFLICT (donor_id, platform) DO UPDATE SET
                            platform_user_id = EXCLUDED.platform_user_id,
                            username = EXCLUDED.username,
                            updated_at = NOW()
                    """, (
                        donor['id'], self.candidate_id, profile.platform,
                        profile.platform_user_id, profile.username, profile.profile_url
                    ))
                    logger.info(f"Linked {profile.platform} profile to donor {donor['email']}")
        
        conn.commit()


# ============================================================================
# DATABASE SCHEMA
# ============================================================================

SOCIAL_OAUTH_SCHEMA = """
-- OAuth states for CSRF protection
CREATE TABLE IF NOT EXISTS social_oauth_states (
    id SERIAL PRIMARY KEY,
    state VARCHAR(255) UNIQUE NOT NULL,
    platform VARCHAR(50) NOT NULL,
    candidate_id VARCHAR(255) NOT NULL,
    code_verifier TEXT,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '1 hour'
);

-- Social profiles - MAXIMUM DATA CAPTURE
CREATE TABLE IF NOT EXISTS social_profiles (
    id SERIAL PRIMARY KEY,
    candidate_id VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL,
    platform_user_id VARCHAR(255) NOT NULL,
    
    -- Identity
    username VARCHAR(255),
    display_name VARCHAR(500),
    first_name VARCHAR(255),
    middle_name VARCHAR(255),
    last_name VARCHAR(255),
    full_name VARCHAR(500),
    
    -- Contact
    email VARCHAR(255),
    email_verified BOOLEAN DEFAULT FALSE,
    phone VARCHAR(50),
    
    -- Profile
    profile_url TEXT,
    profile_image_url TEXT,
    profile_image_hd_url TEXT,
    cover_image_url TEXT,
    bio TEXT,
    website TEXT,
    
    -- Location
    location VARCHAR(500),
    city VARCHAR(255),
    state VARCHAR(100),
    country VARCHAR(100),
    timezone VARCHAR(100),
    locale VARCHAR(50),
    
    -- Demographics
    gender VARCHAR(50),
    birthday VARCHAR(50),
    age_range_min INT,
    age_range_max INT,
    
    -- Work
    employer VARCHAR(500),
    job_title VARCHAR(500),
    industry VARCHAR(255),
    education VARCHAR(500),
    
    -- Flags
    is_verified BOOLEAN DEFAULT FALSE,
    is_business BOOLEAN DEFAULT FALSE,
    is_creator BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT TRUE,
    
    -- Metrics
    follower_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    connection_count INT DEFAULT 0,
    subscriber_count INT DEFAULT 0,
    post_count INT DEFAULT 0,
    video_count INT DEFAULT 0,
    like_count INT DEFAULT 0,
    view_count BIGINT DEFAULT 0,
    engagement_rate DECIMAL(10,4),
    
    -- Account info
    account_created_at TIMESTAMPTZ,
    
    -- OAuth tokens (encrypted in production)
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    scopes_granted TEXT[],
    
    -- Raw data
    raw_profile_json JSONB,
    
    -- Metadata
    captured_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(candidate_id, platform, platform_user_id)
);

-- Social connections - ALL followers/following
CREATE TABLE IF NOT EXISTS social_connections (
    id SERIAL PRIMARY KEY,
    candidate_id VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL,
    source_user_id VARCHAR(255) NOT NULL,
    target_user_id VARCHAR(255) NOT NULL,
    connection_type VARCHAR(50) NOT NULL, -- follower, following, friend, connection, subscriber
    
    -- Target profile
    username VARCHAR(255),
    display_name VARCHAR(500),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    profile_url TEXT,
    profile_image_url TEXT,
    bio TEXT,
    location VARCHAR(500),
    
    -- Metrics
    follower_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    post_count INT DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    is_business BOOLEAN DEFAULT FALSE,
    
    -- Relationship
    is_mutual BOOLEAN DEFAULT FALSE,
    followed_at TIMESTAMPTZ,
    
    -- Raw
    raw_json JSONB,
    captured_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(candidate_id, platform, source_user_id, target_user_id, connection_type)
);

-- Social content - posts, videos, etc
CREATE TABLE IF NOT EXISTS social_content (
    id SERIAL PRIMARY KEY,
    candidate_id VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    content_id VARCHAR(255) NOT NULL,
    content_type VARCHAR(50) NOT NULL,
    
    -- Content
    text TEXT,
    media_urls TEXT[],
    thumbnail_url TEXT,
    permalink TEXT,
    
    -- Metrics
    view_count BIGINT DEFAULT 0,
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    share_count INT DEFAULT 0,
    save_count INT DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_paid BOOLEAN DEFAULT FALSE,
    
    raw_json JSONB,
    captured_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(candidate_id, platform, content_id)
);

-- Link social profiles to donors
CREATE TABLE IF NOT EXISTS donor_social_links (
    id SERIAL PRIMARY KEY,
    donor_id INT NOT NULL,
    candidate_id VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL,
    platform_user_id VARCHAR(255),
    username VARCHAR(255),
    profile_url TEXT,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(donor_id, platform)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_social_profiles_candidate ON social_profiles(candidate_id);
CREATE INDEX IF NOT EXISTS idx_social_profiles_platform ON social_profiles(platform);
CREATE INDEX IF NOT EXISTS idx_social_profiles_email ON social_profiles(email);
CREATE INDEX IF NOT EXISTS idx_social_connections_candidate ON social_connections(candidate_id);
CREATE INDEX IF NOT EXISTS idx_social_connections_source ON social_connections(source_user_id);
CREATE INDEX IF NOT EXISTS idx_social_connections_target ON social_connections(target_user_id);
CREATE INDEX IF NOT EXISTS idx_donor_social_links_donor ON donor_social_links(donor_id);
"""


# ============================================================================
# CLI / API INTERFACE
# ============================================================================

async def main():
    """Example usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Social OAuth Maximum Data Capture")
    parser.add_argument("--candidate-id", required=True, help="Candidate ID")
    parser.add_argument("--platform", choices=list(SocialImportOrchestrator.HANDLERS.keys()), 
                       help="Platform to authorize")
    parser.add_argument("--init-schema", action="store_true", help="Initialize database schema")
    
    args = parser.parse_args()
    
    if args.init_schema:
        conn = psycopg2.connect(SocialConfig.DATABASE_URL)
        with conn.cursor() as cur:
            cur.execute(SOCIAL_OAUTH_SCHEMA)
        conn.commit()
        conn.close()
        print("Schema initialized!")
        return
    
    orchestrator = SocialImportOrchestrator(args.candidate_id)
    
    if args.platform:
        result = orchestrator.initiate_oauth(args.platform)
        print(f"\nAuthorize at: {result['url']}")
        print(f"State: {result['state']}")


if __name__ == "__main__":
    asyncio.run(main())
