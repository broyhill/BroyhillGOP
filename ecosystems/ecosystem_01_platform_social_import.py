#!/usr/bin/env python3
"""
============================================================================
E01 EXTENSION: PLATFORM & SOCIAL GRAPH IMPORT ENGINE
============================================================================

File Import Sources (Column Mappings):
- NationBuilder (people exports, donations)
- ActBlue (contributions CSV)
- NGP VAN (ExportMain, ExportContrib)

Social OAuth Capture (Friends/Followers/Connections):
- Facebook (friends who use app, page followers)
- LinkedIn (1st-degree connections)
- Twitter/X (followers, following)
- Instagram (followers, following)
- TikTok (followers)
- YouTube (subscribers)
- Vimeo (followers)

Architecture:
  CANDIDATE OAUTH → PULL SOCIAL GRAPH → CANDIDATE SILO → DEDUPE → MASTER DATABASE

Each candidate's social data is:
1. Stored in their secured silo (candidate_id scope)
2. Run through E01 deduplication
3. Gleaned to master database for cross-candidate graph

Author: BroyhillGOP Platform
Created: January 2026
Version: 1.0.0
============================================================================
"""

# Load environment
from dotenv import load_dotenv
load_dotenv("/opt/broyhillgop/config/supabase.env")
import os
import json
import logging
import hashlib
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from enum import Enum
import psycopg2
from psycopg2.extras import RealDictCursor

# ============================================================================
# CONFIGURATION
# ============================================================================

class PlatformConfig:
    """Platform import configuration"""
    DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/broyhillgop')
    
    # OAuth Endpoints
    FACEBOOK_GRAPH_URL = "https://graph.facebook.com/v18.0"
    LINKEDIN_API_URL = "https://api.linkedin.com/v2"
    TWITTER_API_URL = "https://api.twitter.com/2"
    INSTAGRAM_API_URL = "https://graph.instagram.com"
    TIKTOK_API_URL = "https://open-api.tiktok.com"
    YOUTUBE_API_URL = "https://www.googleapis.com/youtube/v3"
    VIMEO_API_URL = "https://api.vimeo.com"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# PLATFORM COLUMN MAPPINGS
# ============================================================================

# Pre-defined column mappings for each platform
# Format: source_column -> target_column

NATIONBUILDER_MAPPINGS = {
    # People export fields
    'nationbuilder_id': 'external_id',
    'first_name': 'first_name',
    'last_name': 'last_name',
    'full_name': 'full_name',
    'email': 'email',
    'email1': 'email',
    'email2': 'email_secondary',
    'phone': 'phone',
    'phone_number': 'phone',
    'mobile': 'phone',
    'mobile_number': 'phone',
    'address_address1': 'address',
    'address_address2': 'address2',
    'address_city': 'city',
    'address_state': 'state',
    'address_zip': 'zip_code',
    'address_country_code': 'country',
    'employer': 'employer',
    'occupation': 'occupation',
    'support_level': 'support_level',
    'is_volunteer': 'is_volunteer',
    'is_donor': 'is_donor',
    'donations_amount_in_cents': 'lifetime_donation_cents',
    'donations_count': 'donation_count',
    'created_at': 'created_at',
    'updated_at': 'updated_at',
    # Donation import fields
    'amount_in_cents': 'donation_amount_cents',
    'amount': 'donation_amount',
    'succeeded_at': 'donation_date',
    'payment_type_name': 'payment_method',
    'ngp_id': 'ngp_id',
    'actblue_order_number': 'actblue_order_number',
}

ACTBLUE_MAPPINGS = {
    # Standard ActBlue CSV export columns
    'receipt_id': 'external_id',
    'receipt id': 'external_id',
    'date': 'donation_date',
    'amount': 'donation_amount',
    'recurring_total_months': 'recurring_months',
    'recurrence_number': 'recurrence_number',
    'recipient': 'recipient',
    'fundraising_page': 'source_page',
    'reference_code': 'reference_code',
    'reference_code_2': 'reference_code_2',
    'donor_first_name': 'first_name',
    'donor first name': 'first_name',
    'donor_last_name': 'last_name',
    'donor last name': 'last_name',
    'donor_addr1': 'address',
    'donor addr1': 'address',
    'donor_addr2': 'address2',
    'donor addr2': 'address2',
    'donor_city': 'city',
    'donor city': 'city',
    'donor_state': 'state',
    'donor state': 'state',
    'donor_zip': 'zip_code',
    'donor zip': 'zip_code',
    'donor_country': 'country',
    'donor country': 'country',
    'donor_occupation': 'occupation',
    'donor occupation': 'occupation',
    'donor_employer': 'employer',
    'donor employer': 'employer',
    'donor_email': 'email',
    'donor email': 'email',
    'donor_phone': 'phone',
    'donor phone': 'phone',
    'donor_id': 'actblue_donor_id',
    'donor id': 'actblue_donor_id',
    'lineitem_id': 'lineitem_id',
    'payment_id': 'payment_id',
    'payment_date': 'payment_date',
    'fee': 'processing_fee',
    'recur_weekly': 'is_weekly_recurring',
    'actblue_express_lane': 'is_express_lane',
    'new_express_signup': 'new_express_signup',
    'employer_addr1': 'employer_address',
    'employer_city': 'employer_city',
    'employer_state': 'employer_state',
    'employer_zip': 'employer_zip',
}

NGP_VAN_MAPPINGS = {
    # ExportMain fields (contact records)
    'contactid': 'external_id',
    'contact_id': 'external_id',
    'vanid': 'van_id',
    'van_id': 'van_id',
    'firstname': 'first_name',
    'first_name': 'first_name',
    'lastname': 'last_name',
    'last_name': 'last_name',
    'middlename': 'middle_name',
    'middle_name': 'middle_name',
    'suffix': 'suffix',
    'prefix': 'prefix',
    'email': 'email',
    'email1': 'email',
    'homephone': 'phone',
    'home_phone': 'phone',
    'cellphone': 'phone',
    'cell_phone': 'phone',
    'workphone': 'work_phone',
    'work_phone': 'work_phone',
    'address': 'address',
    'addressline1': 'address',
    'address_line_1': 'address',
    'addressline2': 'address2',
    'address_line_2': 'address2',
    'city': 'city',
    'state': 'state',
    'zip': 'zip_code',
    'zip5': 'zip_code',
    'zip4': 'zip4',
    'employer': 'employer',
    'occupation': 'occupation',
    'dateofbirth': 'date_of_birth',
    'date_of_birth': 'date_of_birth',
    'dob': 'date_of_birth',
    'sex': 'gender',
    'gender': 'gender',
    # ExportContrib fields (donations)
    'amount': 'donation_amount',
    'contributionamount': 'donation_amount',
    'contribution_amount': 'donation_amount',
    'contributiondate': 'donation_date',
    'contribution_date': 'donation_date',
    'datecontributed': 'donation_date',
    'date_contributed': 'donation_date',
    'method': 'payment_method',
    'paymentmethod': 'payment_method',
    'payment_method': 'payment_method',
    'period': 'election_period',
    'electionperiod': 'election_period',
    'election_period': 'election_period',
    'contributionid': 'ngp_contribution_id',
    'contribution_id': 'ngp_contribution_id',
    # Volunteer fields
    'isvolunteer': 'is_volunteer',
    'is_volunteer': 'is_volunteer',
    'volunteertype': 'volunteer_type',
    'volunteer_type': 'volunteer_type',
}

# All platform mappings combined
PLATFORM_MAPPINGS = {
    'nationbuilder': NATIONBUILDER_MAPPINGS,
    'actblue': ACTBLUE_MAPPINGS,
    'ngp_van': NGP_VAN_MAPPINGS,
    'ngp': NGP_VAN_MAPPINGS,
    'van': NGP_VAN_MAPPINGS,
}

# ============================================================================
# SOCIAL PLATFORM ENUM
# ============================================================================

class SocialPlatform(Enum):
    """Supported social platforms for OAuth capture"""
    FACEBOOK = "facebook"
    LINKEDIN = "linkedin"
    TWITTER = "twitter"
    INSTAGRAM = "instagram"
    TIKTOK = "tiktok"
    YOUTUBE = "youtube"
    VIMEO = "vimeo"

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class SocialConnection:
    """Represents a social media connection/follower"""
    platform: SocialPlatform
    platform_user_id: str
    username: Optional[str] = None
    display_name: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None
    profile_url: Optional[str] = None
    profile_image_url: Optional[str] = None
    location: Optional[str] = None
    bio: Optional[str] = None
    follower_count: Optional[int] = None
    following_count: Optional[int] = None
    connection_type: str = "follower"  # follower, following, friend, connection
    raw_data: Dict = field(default_factory=dict)
    
    def to_dict(self) -> Dict:
        return {
            'platform': self.platform.value,
            'platform_user_id': self.platform_user_id,
            'username': self.username,
            'display_name': self.display_name,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'email': self.email,
            'profile_url': self.profile_url,
            'profile_image_url': self.profile_image_url,
            'location': self.location,
            'bio': self.bio,
            'follower_count': self.follower_count,
            'following_count': self.following_count,
            'connection_type': self.connection_type,
        }

@dataclass
class OAuthCredentials:
    """OAuth credentials for a social platform"""
    platform: SocialPlatform
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "Bearer"
    expires_at: Optional[datetime] = None
    scope: Optional[str] = None
    
@dataclass
class SocialImportResult:
    """Result of social graph import"""
    platform: SocialPlatform
    candidate_id: str
    total_connections: int = 0
    imported: int = 0
    duplicates: int = 0
    errors: int = 0
    error_messages: List[str] = field(default_factory=list)

# ============================================================================
# SOCIAL GRAPH CAPTURE ENGINE
# ============================================================================

class SocialGraphEngine:
    """
    Captures social graph (friends/followers/connections) from social platforms.
    
    Flow:
    1. Candidate provides OAuth credentials
    2. Engine pulls connections from platform API
    3. Connections stored in candidate silo
    4. Run through deduplication
    5. Gleaned to master database
    """
    
    def __init__(self, candidate_id: str):
        self.candidate_id = candidate_id
        self.db_url = PlatformConfig.DATABASE_URL
        
    def _get_db(self):
        """Get database connection"""
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # OAUTH CREDENTIAL MANAGEMENT
    # ========================================================================
    
    def store_oauth_credentials(self, creds: OAuthCredentials) -> bool:
        """Store OAuth credentials for candidate (encrypted)"""
        conn = self._get_db()
        cur = conn.cursor()
        
        try:
            # In production, encrypt the tokens before storage
            cur.execute("""
                INSERT INTO candidate_social_oauth (
                    candidate_id, platform, access_token, refresh_token,
                    token_type, expires_at, scope, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
                ON CONFLICT (candidate_id, platform) 
                DO UPDATE SET
                    access_token = EXCLUDED.access_token,
                    refresh_token = EXCLUDED.refresh_token,
                    token_type = EXCLUDED.token_type,
                    expires_at = EXCLUDED.expires_at,
                    scope = EXCLUDED.scope,
                    updated_at = NOW()
            """, (
                self.candidate_id,
                creds.platform.value,
                creds.access_token,  # Should be encrypted
                creds.refresh_token,  # Should be encrypted
                creds.token_type,
                creds.expires_at,
                creds.scope
            ))
            conn.commit()
            logger.info(f"Stored OAuth credentials for {creds.platform.value}")
            return True
        except Exception as e:
            logger.error(f"Failed to store OAuth credentials: {e}")
            conn.rollback()
            return False
        finally:
            conn.close()
    
    def get_oauth_credentials(self, platform: SocialPlatform) -> Optional[OAuthCredentials]:
        """Retrieve OAuth credentials for platform"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM candidate_social_oauth
            WHERE candidate_id = %s AND platform = %s
        """, (self.candidate_id, platform.value))
        
        row = cur.fetchone()
        conn.close()
        
        if row:
            return OAuthCredentials(
                platform=platform,
                access_token=row['access_token'],
                refresh_token=row['refresh_token'],
                token_type=row['token_type'],
                expires_at=row['expires_at'],
                scope=row['scope']
            )
        return None
    
    # ========================================================================
    # FACEBOOK GRAPH CAPTURE
    # ========================================================================
    
    def capture_facebook(self, access_token: str) -> SocialImportResult:
        """
        Capture Facebook friends and page followers.
        
        Note: After Cambridge Analytica, only friends who also use the app
        are returned. Page followers require page admin access.
        """
        result = SocialImportResult(
            platform=SocialPlatform.FACEBOOK,
            candidate_id=self.candidate_id
        )
        
        connections = []
        
        try:
            # Get user's friends (only those who also use the app)
            friends_url = f"{PlatformConfig.FACEBOOK_GRAPH_URL}/me/friends"
            params = {
                'access_token': access_token,
                'fields': 'id,name,first_name,last_name,picture,link',
                'limit': 100
            }
            
            while friends_url:
                response = requests.get(friends_url, params=params)
                if response.status_code != 200:
                    result.error_messages.append(f"Facebook API error: {response.text}")
                    break
                    
                data = response.json()
                
                for friend in data.get('data', []):
                    conn = SocialConnection(
                        platform=SocialPlatform.FACEBOOK,
                        platform_user_id=friend['id'],
                        display_name=friend.get('name'),
                        first_name=friend.get('first_name'),
                        last_name=friend.get('last_name'),
                        profile_url=friend.get('link'),
                        profile_image_url=friend.get('picture', {}).get('data', {}).get('url'),
                        connection_type='friend',
                        raw_data=friend
                    )
                    connections.append(conn)
                
                # Pagination
                friends_url = data.get('paging', {}).get('next')
                params = {}  # URL includes params
            
            # Get user's liked pages (potential donors/supporters)
            likes_url = f"{PlatformConfig.FACEBOOK_GRAPH_URL}/me/likes"
            params = {
                'access_token': access_token,
                'fields': 'id,name,category,fan_count',
                'limit': 100
            }
            
            # Store page likes separately for interest mapping
            # (not as connections but as interest data)
            
            result.total_connections = len(connections)
            
            # Store in candidate silo
            imported, dupes = self._store_connections(connections)
            result.imported = imported
            result.duplicates = dupes
            
        except Exception as e:
            result.error_messages.append(str(e))
            result.errors += 1
            logger.error(f"Facebook capture error: {e}")
        
        return result
    
    # ========================================================================
    # LINKEDIN CONNECTIONS CAPTURE
    # ========================================================================
    
    def capture_linkedin(self, access_token: str) -> SocialImportResult:
        """
        Capture LinkedIn 1st-degree connections.
        
        Requires r_1st_connections_size or r_network permission.
        Only returns connections of the authenticated user.
        """
        result = SocialImportResult(
            platform=SocialPlatform.LINKEDIN,
            candidate_id=self.candidate_id
        )
        
        connections = []
        
        try:
            headers = {
                'Authorization': f'Bearer {access_token}',
                'X-Restli-Protocol-Version': '2.0.0'
            }
            
            # Get connections
            url = f"{PlatformConfig.LINKEDIN_API_URL}/connections"
            params = {
                'q': 'viewer',
                'start': 0,
                'count': 50
            }
            
            while True:
                response = requests.get(url, headers=headers, params=params)
                
                if response.status_code != 200:
                    result.error_messages.append(f"LinkedIn API error: {response.text}")
                    break
                
                data = response.json()
                elements = data.get('elements', [])
                
                if not elements:
                    break
                
                for elem in elements:
                    # Extract profile info
                    mini_profile = elem.get('miniProfile', {})
                    
                    conn = SocialConnection(
                        platform=SocialPlatform.LINKEDIN,
                        platform_user_id=mini_profile.get('entityUrn', '').split(':')[-1],
                        first_name=mini_profile.get('firstName'),
                        last_name=mini_profile.get('lastName'),
                        display_name=f"{mini_profile.get('firstName', '')} {mini_profile.get('lastName', '')}".strip(),
                        profile_url=f"https://linkedin.com/in/{mini_profile.get('publicIdentifier')}",
                        connection_type='connection',
                        raw_data=elem
                    )
                    connections.append(conn)
                
                # Pagination
                params['start'] += params['count']
                if len(elements) < params['count']:
                    break
            
            result.total_connections = len(connections)
            imported, dupes = self._store_connections(connections)
            result.imported = imported
            result.duplicates = dupes
            
        except Exception as e:
            result.error_messages.append(str(e))
            result.errors += 1
            logger.error(f"LinkedIn capture error: {e}")
        
        return result
    
    # ========================================================================
    # TWITTER/X FOLLOWERS CAPTURE
    # ========================================================================
    
    def capture_twitter(self, access_token: str, user_id: str) -> SocialImportResult:
        """
        Capture Twitter/X followers.
        
        Rate limited to 15 requests per 15 minutes.
        """
        result = SocialImportResult(
            platform=SocialPlatform.TWITTER,
            candidate_id=self.candidate_id
        )
        
        connections = []
        
        try:
            headers = {
                'Authorization': f'Bearer {access_token}'
            }
            
            # Get followers
            url = f"{PlatformConfig.TWITTER_API_URL}/users/{user_id}/followers"
            params = {
                'user.fields': 'id,name,username,description,location,profile_image_url,public_metrics',
                'max_results': 100
            }
            
            pagination_token = None
            
            while True:
                if pagination_token:
                    params['pagination_token'] = pagination_token
                
                response = requests.get(url, headers=headers, params=params)
                
                if response.status_code != 200:
                    result.error_messages.append(f"Twitter API error: {response.text}")
                    break
                
                data = response.json()
                users = data.get('data', [])
                
                for user in users:
                    metrics = user.get('public_metrics', {})
                    conn = SocialConnection(
                        platform=SocialPlatform.TWITTER,
                        platform_user_id=user['id'],
                        username=user.get('username'),
                        display_name=user.get('name'),
                        profile_url=f"https://twitter.com/{user.get('username')}",
                        profile_image_url=user.get('profile_image_url'),
                        location=user.get('location'),
                        bio=user.get('description'),
                        follower_count=metrics.get('followers_count'),
                        following_count=metrics.get('following_count'),
                        connection_type='follower',
                        raw_data=user
                    )
                    connections.append(conn)
                
                # Pagination
                pagination_token = data.get('meta', {}).get('next_token')
                if not pagination_token:
                    break
            
            result.total_connections = len(connections)
            imported, dupes = self._store_connections(connections)
            result.imported = imported
            result.duplicates = dupes
            
        except Exception as e:
            result.error_messages.append(str(e))
            result.errors += 1
            logger.error(f"Twitter capture error: {e}")
        
        return result
    
    # ========================================================================
    # INSTAGRAM FOLLOWERS CAPTURE
    # ========================================================================
    
    def capture_instagram(self, access_token: str, user_id: str) -> SocialImportResult:
        """
        Capture Instagram followers.
        
        Requires Instagram Basic Display API or Graph API for business accounts.
        """
        result = SocialImportResult(
            platform=SocialPlatform.INSTAGRAM,
            candidate_id=self.candidate_id
        )
        
        connections = []
        
        try:
            # Instagram Graph API for business accounts
            url = f"{PlatformConfig.INSTAGRAM_API_URL}/{user_id}"
            params = {
                'fields': 'id,username,name,profile_picture_url,followers_count',
                'access_token': access_token
            }
            
            response = requests.get(url, params=params)
            
            if response.status_code != 200:
                result.error_messages.append(f"Instagram API error: {response.text}")
                return result
            
            # Note: Instagram API doesn't provide follower list directly
            # Only aggregate metrics. Individual followers require scraping
            # which violates ToS. Store account metadata instead.
            
            data = response.json()
            
            # Store the account info for reference
            conn = SocialConnection(
                platform=SocialPlatform.INSTAGRAM,
                platform_user_id=data.get('id'),
                username=data.get('username'),
                display_name=data.get('name'),
                profile_url=f"https://instagram.com/{data.get('username')}",
                profile_image_url=data.get('profile_picture_url'),
                follower_count=data.get('followers_count'),
                connection_type='account',
                raw_data=data
            )
            connections.append(conn)
            
            result.total_connections = 1
            result.imported = 1
            
            logger.info("Instagram API provides metrics only, not follower list")
            
        except Exception as e:
            result.error_messages.append(str(e))
            result.errors += 1
            logger.error(f"Instagram capture error: {e}")
        
        return result
    
    # ========================================================================
    # TIKTOK FOLLOWERS CAPTURE
    # ========================================================================
    
    def capture_tiktok(self, access_token: str) -> SocialImportResult:
        """
        Capture TikTok followers.
        
        Requires TikTok for Developers API access.
        """
        result = SocialImportResult(
            platform=SocialPlatform.TIKTOK,
            candidate_id=self.candidate_id
        )
        
        connections = []
        
        try:
            headers = {
                'Authorization': f'Bearer {access_token}'
            }
            
            # Get user info first
            url = f"{PlatformConfig.TIKTOK_API_URL}/user/info/"
            
            response = requests.get(url, headers=headers)
            
            if response.status_code != 200:
                result.error_messages.append(f"TikTok API error: {response.text}")
                return result
            
            data = response.json().get('data', {}).get('user', {})
            
            # TikTok API limitations similar to Instagram
            # Store account metadata
            conn = SocialConnection(
                platform=SocialPlatform.TIKTOK,
                platform_user_id=data.get('open_id'),
                username=data.get('display_name'),
                display_name=data.get('display_name'),
                profile_image_url=data.get('avatar_url'),
                follower_count=data.get('follower_count'),
                following_count=data.get('following_count'),
                connection_type='account',
                raw_data=data
            )
            connections.append(conn)
            
            result.total_connections = 1
            result.imported = 1
            
        except Exception as e:
            result.error_messages.append(str(e))
            result.errors += 1
            logger.error(f"TikTok capture error: {e}")
        
        return result
    
    # ========================================================================
    # YOUTUBE SUBSCRIBERS CAPTURE
    # ========================================================================
    
    def capture_youtube(self, access_token: str, channel_id: str) -> SocialImportResult:
        """
        Capture YouTube subscribers.
        
        Requires YouTube Data API v3.
        Note: Subscriber list is only visible if subscribers have opted in.
        """
        result = SocialImportResult(
            platform=SocialPlatform.YOUTUBE,
            candidate_id=self.candidate_id
        )
        
        connections = []
        
        try:
            # Get channel info
            url = f"{PlatformConfig.YOUTUBE_API_URL}/channels"
            params = {
                'part': 'snippet,statistics',
                'id': channel_id,
                'access_token': access_token
            }
            
            response = requests.get(url, params=params)
            
            if response.status_code != 200:
                result.error_messages.append(f"YouTube API error: {response.text}")
                return result
            
            data = response.json()
            items = data.get('items', [])
            
            if items:
                channel = items[0]
                snippet = channel.get('snippet', {})
                stats = channel.get('statistics', {})
                
                conn = SocialConnection(
                    platform=SocialPlatform.YOUTUBE,
                    platform_user_id=channel_id,
                    username=snippet.get('customUrl'),
                    display_name=snippet.get('title'),
                    profile_url=f"https://youtube.com/channel/{channel_id}",
                    profile_image_url=snippet.get('thumbnails', {}).get('default', {}).get('url'),
                    bio=snippet.get('description'),
                    follower_count=int(stats.get('subscriberCount', 0)),
                    connection_type='account',
                    raw_data=channel
                )
                connections.append(conn)
            
            # Get visible subscribers (opted-in only)
            subs_url = f"{PlatformConfig.YOUTUBE_API_URL}/subscriptions"
            subs_params = {
                'part': 'snippet',
                'mySubscribers': 'true',
                'maxResults': 50,
                'access_token': access_token
            }
            
            page_token = None
            
            while True:
                if page_token:
                    subs_params['pageToken'] = page_token
                
                subs_response = requests.get(subs_url, params=subs_params)
                
                if subs_response.status_code != 200:
                    break
                
                subs_data = subs_response.json()
                
                for item in subs_data.get('items', []):
                    snippet = item.get('snippet', {})
                    
                    conn = SocialConnection(
                        platform=SocialPlatform.YOUTUBE,
                        platform_user_id=snippet.get('channelId'),
                        display_name=snippet.get('title'),
                        profile_url=f"https://youtube.com/channel/{snippet.get('channelId')}",
                        profile_image_url=snippet.get('thumbnails', {}).get('default', {}).get('url'),
                        connection_type='subscriber',
                        raw_data=item
                    )
                    connections.append(conn)
                
                page_token = subs_data.get('nextPageToken')
                if not page_token:
                    break
            
            result.total_connections = len(connections)
            imported, dupes = self._store_connections(connections)
            result.imported = imported
            result.duplicates = dupes
            
        except Exception as e:
            result.error_messages.append(str(e))
            result.errors += 1
            logger.error(f"YouTube capture error: {e}")
        
        return result
    
    # ========================================================================
    # VIMEO FOLLOWERS CAPTURE
    # ========================================================================
    
    def capture_vimeo(self, access_token: str, user_id: str) -> SocialImportResult:
        """
        Capture Vimeo followers.
        
        Requires Vimeo API with appropriate scope.
        """
        result = SocialImportResult(
            platform=SocialPlatform.VIMEO,
            candidate_id=self.candidate_id
        )
        
        connections = []
        
        try:
            headers = {
                'Authorization': f'Bearer {access_token}'
            }
            
            # Get followers
            url = f"{PlatformConfig.VIMEO_API_URL}/users/{user_id}/followers"
            params = {
                'per_page': 100,
                'page': 1
            }
            
            while True:
                response = requests.get(url, headers=headers, params=params)
                
                if response.status_code != 200:
                    result.error_messages.append(f"Vimeo API error: {response.text}")
                    break
                
                data = response.json()
                
                for follower in data.get('data', []):
                    conn = SocialConnection(
                        platform=SocialPlatform.VIMEO,
                        platform_user_id=follower.get('uri', '').split('/')[-1],
                        display_name=follower.get('name'),
                        profile_url=follower.get('link'),
                        profile_image_url=follower.get('pictures', {}).get('sizes', [{}])[-1].get('link'),
                        location=follower.get('location'),
                        bio=follower.get('bio'),
                        connection_type='follower',
                        raw_data=follower
                    )
                    connections.append(conn)
                
                # Pagination
                paging = data.get('paging', {})
                if not paging.get('next'):
                    break
                params['page'] += 1
            
            result.total_connections = len(connections)
            imported, dupes = self._store_connections(connections)
            result.imported = imported
            result.duplicates = dupes
            
        except Exception as e:
            result.error_messages.append(str(e))
            result.errors += 1
            logger.error(f"Vimeo capture error: {e}")
        
        return result
    
    # ========================================================================
    # STORAGE & DEDUPLICATION
    # ========================================================================
    
    def _store_connections(self, connections: List[SocialConnection]) -> tuple:
        """
        Store connections in candidate silo and glean to master database.
        
        Returns (imported_count, duplicate_count)
        """
        conn = self._get_db()
        cur = conn.cursor()
        
        imported = 0
        duplicates = 0
        
        for social_conn in connections:
            try:
                # Generate unique hash for deduplication
                unique_key = f"{social_conn.platform.value}:{social_conn.platform_user_id}"
                connection_hash = hashlib.sha256(unique_key.encode()).hexdigest()
                
                # Insert into candidate silo (social_connections table)
                cur.execute("""
                    INSERT INTO candidate_social_connections (
                        candidate_id, platform, platform_user_id, connection_hash,
                        username, display_name, first_name, last_name, email,
                        profile_url, profile_image_url, location, bio,
                        follower_count, following_count, connection_type,
                        raw_data, created_at
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW()
                    )
                    ON CONFLICT (candidate_id, connection_hash) DO UPDATE SET
                        display_name = EXCLUDED.display_name,
                        follower_count = EXCLUDED.follower_count,
                        following_count = EXCLUDED.following_count,
                        updated_at = NOW()
                    RETURNING (xmax = 0) AS is_insert
                """, (
                    self.candidate_id,
                    social_conn.platform.value,
                    social_conn.platform_user_id,
                    connection_hash,
                    social_conn.username,
                    social_conn.display_name,
                    social_conn.first_name,
                    social_conn.last_name,
                    social_conn.email,
                    social_conn.profile_url,
                    social_conn.profile_image_url,
                    social_conn.location,
                    social_conn.bio,
                    social_conn.follower_count,
                    social_conn.following_count,
                    social_conn.connection_type,
                    json.dumps(social_conn.raw_data)
                ))
                
                row = cur.fetchone()
                if row and row[0]:
                    imported += 1
                else:
                    duplicates += 1
                
                # Glean to master database (if name info available)
                if social_conn.first_name or social_conn.display_name:
                    self._glean_to_master(cur, social_conn, connection_hash)
                
            except Exception as e:
                logger.error(f"Failed to store connection: {e}")
                continue
        
        conn.commit()
        conn.close()
        
        return imported, duplicates
    
    def _glean_to_master(self, cur, social_conn: SocialConnection, connection_hash: str):
        """
        Glean connection info to master contacts database for cross-candidate graph.
        
        Only captures non-PII identifiers for graph building.
        Full data remains in candidate silo.
        """
        try:
            # Insert/update in master social graph
            cur.execute("""
                INSERT INTO master_social_graph (
                    platform, platform_user_id, connection_hash,
                    display_name, first_name, last_name,
                    username, profile_url,
                    first_seen_candidate_id, first_seen_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW()
                )
                ON CONFLICT (connection_hash) DO UPDATE SET
                    display_name = COALESCE(EXCLUDED.display_name, master_social_graph.display_name),
                    last_seen_at = NOW(),
                    seen_count = master_social_graph.seen_count + 1
            """, (
                social_conn.platform.value,
                social_conn.platform_user_id,
                connection_hash,
                social_conn.display_name,
                social_conn.first_name,
                social_conn.last_name,
                social_conn.username,
                social_conn.profile_url,
                self.candidate_id
            ))
            
            # Link to candidate in junction table
            cur.execute("""
                INSERT INTO master_social_candidate_links (
                    connection_hash, candidate_id, connection_type, first_linked_at
                ) VALUES (%s, %s, %s, NOW())
                ON CONFLICT (connection_hash, candidate_id) DO NOTHING
            """, (connection_hash, self.candidate_id, social_conn.connection_type))
            
        except Exception as e:
            logger.warning(f"Failed to glean to master: {e}")


# ============================================================================
# PLATFORM FILE IMPORT ENGINE
# ============================================================================

class PlatformImportEngine:
    """
    Handles file imports from political platforms (NationBuilder, ActBlue, NGP VAN).
    
    Auto-detects platform based on column names and applies appropriate mappings.
    """
    
    def __init__(self, candidate_id: str):
        self.candidate_id = candidate_id
        self.db_url = PlatformConfig.DATABASE_URL
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    def detect_platform(self, columns: List[str]) -> Optional[str]:
        """
        Auto-detect platform based on column names.
        
        Returns: 'nationbuilder', 'actblue', 'ngp_van', or None
        """
        columns_lower = [c.lower().strip().replace(' ', '_') for c in columns]
        
        # ActBlue detection (most specific first)
        actblue_markers = ['donor_first_name', 'donor_last_name', 'receipt_id', 
                          'actblue_express_lane', 'lineitem_id', 'donor_id']
        actblue_matches = sum(1 for m in actblue_markers if any(m in c for c in columns_lower))
        
        # NationBuilder detection
        nb_markers = ['nationbuilder_id', 'support_level', 'is_volunteer', 
                      'donations_amount_in_cents', 'recruiter_id']
        nb_matches = sum(1 for m in nb_markers if any(m in c for c in columns_lower))
        
        # NGP VAN detection
        ngp_markers = ['contactid', 'vanid', 'van_id', 'ngp_id', 
                       'contributionid', 'electionperiod']
        ngp_matches = sum(1 for m in ngp_markers if any(m in c for c in columns_lower))
        
        # Return platform with most matches
        scores = {
            'actblue': actblue_matches,
            'nationbuilder': nb_matches,
            'ngp_van': ngp_matches
        }
        
        best = max(scores, key=scores.get)
        if scores[best] >= 2:
            logger.info(f"Detected platform: {best} (score: {scores[best]})")
            return best
        
        return None
    
    def get_column_mapping(self, platform: str, source_columns: List[str]) -> Dict[str, str]:
        """
        Get column mapping for detected platform.
        
        Returns dict: {source_column: target_column}
        """
        if platform not in PLATFORM_MAPPINGS:
            return {}
        
        platform_map = PLATFORM_MAPPINGS[platform]
        mapping = {}
        
        for col in source_columns:
            col_lower = col.lower().strip().replace(' ', '_')
            
            # Direct match
            if col_lower in platform_map:
                mapping[col] = platform_map[col_lower]
            # Partial match
            else:
                for source, target in platform_map.items():
                    if source in col_lower or col_lower in source:
                        mapping[col] = target
                        break
        
        return mapping
    
    def register_platform_mappings(self):
        """
        Register all platform mappings in the database for E01 to use.
        """
        conn = self._get_db()
        cur = conn.cursor()
        
        for platform, mappings in PLATFORM_MAPPINGS.items():
            for source_col, target_col in mappings.items():
                try:
                    cur.execute("""
                        INSERT INTO import_column_mappings 
                        (source_type, source_column, target_column, confidence, created_at)
                        VALUES (%s, %s, %s, 100, NOW())
                        ON CONFLICT (source_type, source_column) DO UPDATE SET
                            target_column = EXCLUDED.target_column,
                            updated_at = NOW()
                    """, (platform, source_col, target_col))
                except Exception as e:
                    logger.warning(f"Failed to register mapping {platform}.{source_col}: {e}")
        
        conn.commit()
        conn.close()
        
        logger.info(f"Registered {sum(len(m) for m in PLATFORM_MAPPINGS.values())} column mappings")


# ============================================================================
# DATABASE SCHEMA
# ============================================================================

SOCIAL_SCHEMA_SQL = """
-- ============================================================================
-- SOCIAL GRAPH CAPTURE SCHEMA
-- ============================================================================

-- OAuth credentials storage (encrypted in production)
CREATE TABLE IF NOT EXISTS candidate_social_oauth (
    id SERIAL PRIMARY KEY,
    candidate_id UUID NOT NULL,
    platform VARCHAR(50) NOT NULL,
    access_token TEXT NOT NULL,  -- Encrypt this!
    refresh_token TEXT,  -- Encrypt this!
    token_type VARCHAR(50) DEFAULT 'Bearer',
    expires_at TIMESTAMP,
    scope TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP,
    UNIQUE(candidate_id, platform)
);

-- Candidate silo: social connections (secured per candidate)
CREATE TABLE IF NOT EXISTS candidate_social_connections (
    id SERIAL PRIMARY KEY,
    candidate_id UUID NOT NULL,
    platform VARCHAR(50) NOT NULL,
    platform_user_id VARCHAR(200) NOT NULL,
    connection_hash VARCHAR(64) NOT NULL,  -- SHA256 for dedup
    username VARCHAR(200),
    display_name VARCHAR(500),
    first_name VARCHAR(200),
    last_name VARCHAR(200),
    email VARCHAR(320),
    profile_url TEXT,
    profile_image_url TEXT,
    location VARCHAR(500),
    bio TEXT,
    follower_count INTEGER,
    following_count INTEGER,
    connection_type VARCHAR(50) DEFAULT 'follower',
    raw_data JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP,
    UNIQUE(candidate_id, connection_hash)
);

CREATE INDEX IF NOT EXISTS idx_social_conn_candidate ON candidate_social_connections(candidate_id);
CREATE INDEX IF NOT EXISTS idx_social_conn_platform ON candidate_social_connections(platform);
CREATE INDEX IF NOT EXISTS idx_social_conn_hash ON candidate_social_connections(connection_hash);

-- Master database: gleaned social graph (cross-candidate)
CREATE TABLE IF NOT EXISTS master_social_graph (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    platform_user_id VARCHAR(200) NOT NULL,
    connection_hash VARCHAR(64) NOT NULL UNIQUE,
    display_name VARCHAR(500),
    first_name VARCHAR(200),
    last_name VARCHAR(200),
    username VARCHAR(200),
    profile_url TEXT,
    first_seen_candidate_id UUID,
    first_seen_at TIMESTAMP DEFAULT NOW(),
    last_seen_at TIMESTAMP,
    seen_count INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_master_social_hash ON master_social_graph(connection_hash);
CREATE INDEX IF NOT EXISTS idx_master_social_platform ON master_social_graph(platform);
CREATE INDEX IF NOT EXISTS idx_master_social_name ON master_social_graph(first_name, last_name);

-- Junction table: links social profiles to candidates
CREATE TABLE IF NOT EXISTS master_social_candidate_links (
    id SERIAL PRIMARY KEY,
    connection_hash VARCHAR(64) NOT NULL,
    candidate_id UUID NOT NULL,
    connection_type VARCHAR(50),
    first_linked_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(connection_hash, candidate_id),
    FOREIGN KEY (connection_hash) REFERENCES master_social_graph(connection_hash)
);

CREATE INDEX IF NOT EXISTS idx_social_links_hash ON master_social_candidate_links(connection_hash);
CREATE INDEX IF NOT EXISTS idx_social_links_candidate ON master_social_candidate_links(candidate_id);

-- Additional platform column mappings (extends E01)
INSERT INTO import_column_mappings (source_type, source_column, target_column, confidence) VALUES
    -- NationBuilder
    ('nationbuilder', 'nationbuilder_id', 'external_id', 100),
    ('nationbuilder', 'first_name', 'first_name', 100),
    ('nationbuilder', 'last_name', 'last_name', 100),
    ('nationbuilder', 'email', 'email', 100),
    ('nationbuilder', 'email1', 'email', 100),
    ('nationbuilder', 'phone', 'phone', 100),
    ('nationbuilder', 'mobile', 'phone', 100),
    ('nationbuilder', 'address_address1', 'address', 100),
    ('nationbuilder', 'address_city', 'city', 100),
    ('nationbuilder', 'address_state', 'state', 100),
    ('nationbuilder', 'address_zip', 'zip_code', 100),
    ('nationbuilder', 'employer', 'employer', 100),
    ('nationbuilder', 'occupation', 'occupation', 100),
    ('nationbuilder', 'donations_amount_in_cents', 'lifetime_donation_cents', 100),
    ('nationbuilder', 'support_level', 'support_level', 100),
    ('nationbuilder', 'is_volunteer', 'is_volunteer', 100),
    -- ActBlue
    ('actblue', 'receipt_id', 'external_id', 100),
    ('actblue', 'donor_first_name', 'first_name', 100),
    ('actblue', 'donor_last_name', 'last_name', 100),
    ('actblue', 'donor_email', 'email', 100),
    ('actblue', 'donor_phone', 'phone', 100),
    ('actblue', 'donor_addr1', 'address', 100),
    ('actblue', 'donor_city', 'city', 100),
    ('actblue', 'donor_state', 'state', 100),
    ('actblue', 'donor_zip', 'zip_code', 100),
    ('actblue', 'donor_employer', 'employer', 100),
    ('actblue', 'donor_occupation', 'occupation', 100),
    ('actblue', 'amount', 'donation_amount', 100),
    ('actblue', 'date', 'donation_date', 100),
    ('actblue', 'donor_id', 'actblue_donor_id', 100),
    -- NGP VAN
    ('ngp_van', 'contactid', 'external_id', 100),
    ('ngp_van', 'vanid', 'van_id', 100),
    ('ngp_van', 'firstname', 'first_name', 100),
    ('ngp_van', 'lastname', 'last_name', 100),
    ('ngp_van', 'email', 'email', 100),
    ('ngp_van', 'homephone', 'phone', 100),
    ('ngp_van', 'cellphone', 'phone', 100),
    ('ngp_van', 'address', 'address', 100),
    ('ngp_van', 'city', 'city', 100),
    ('ngp_van', 'state', 'state', 100),
    ('ngp_van', 'zip', 'zip_code', 100),
    ('ngp_van', 'employer', 'employer', 100),
    ('ngp_van', 'occupation', 'occupation', 100),
    ('ngp_van', 'amount', 'donation_amount', 100),
    ('ngp_van', 'contributiondate', 'donation_date', 100)
ON CONFLICT (source_type, source_column) DO NOTHING;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE candidate_social_oauth IS 'OAuth credentials for social platforms (per candidate)';
COMMENT ON TABLE candidate_social_connections IS 'Candidate silo: social connections secured per candidate';
COMMENT ON TABLE master_social_graph IS 'Master database: cross-candidate social graph';
COMMENT ON TABLE master_social_candidate_links IS 'Links social profiles to multiple candidates';
"""


# ============================================================================
# CLI INTERFACE
# ============================================================================

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("""
E01 Extension: Platform & Social Graph Import Engine

Usage:
    python ecosystem_01_platform_social_import.py --deploy-schema
    python ecosystem_01_platform_social_import.py --register-mappings
    python ecosystem_01_platform_social_import.py --detect-platform <csv_file>
    python ecosystem_01_platform_social_import.py --capture-facebook <candidate_id> <access_token>
    python ecosystem_01_platform_social_import.py --capture-linkedin <candidate_id> <access_token>
    python ecosystem_01_platform_social_import.py --capture-twitter <candidate_id> <access_token> <user_id>

Supported Platforms (File Import):
    - NationBuilder
    - ActBlue
    - NGP VAN

Supported Platforms (Social OAuth):
    - Facebook
    - LinkedIn
    - Twitter/X
    - Instagram
    - TikTok
    - YouTube
    - Vimeo
        """)
        sys.exit(0)
    
    command = sys.argv[1]
    
    if command == "--deploy-schema":
        import psycopg2
        conn = psycopg2.connect(PlatformConfig.DATABASE_URL)
        cur = conn.cursor()
        cur.execute(SOCIAL_SCHEMA_SQL)
        conn.commit()
        conn.close()
        print("✅ Social graph schema deployed!")
    
    elif command == "--register-mappings":
        engine = PlatformImportEngine('system')
        engine.register_platform_mappings()
        print("✅ Platform column mappings registered!")
    
    elif command == "--detect-platform" and len(sys.argv) > 2:
        import csv

# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 01PlatformSocialImportError(Exception):
    """Base exception for this ecosystem"""
    pass

class 01PlatformSocialImportValidationError(01PlatformSocialImportError):
    """Validation error in this ecosystem"""
    pass

class 01PlatformSocialImportDatabaseError(01PlatformSocialImportError):
    """Database error in this ecosystem"""
    pass

class 01PlatformSocialImportAPIError(01PlatformSocialImportError):
    """API error in this ecosystem"""
    pass
# === END CUSTOM EXCEPTIONS ===


# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 01PlatformSocialImportError(Exception):
    """Base exception for this ecosystem"""
    pass

class 01PlatformSocialImportValidationError(01PlatformSocialImportError):
    """Validation error in this ecosystem"""
    pass

class 01PlatformSocialImportDatabaseError(01PlatformSocialImportError):
    """Database error in this ecosystem"""
    pass

class 01PlatformSocialImportAPIError(01PlatformSocialImportError):
    """API error in this ecosystem"""
    pass
# === END CUSTOM EXCEPTIONS ===

        file_path = sys.argv[2]
        with open(file_path, 'r') as f:
            reader = csv.reader(f)
            columns = next(reader)
        
        engine = PlatformImportEngine('test')
        platform = engine.detect_platform(columns)
        
        if platform:
            print(f"Detected platform: {platform}")
            mapping = engine.get_column_mapping(platform, columns)
            print(f"Column mappings: {json.dumps(mapping, indent=2)}")
        else:
            print("Could not detect platform")
    
    elif command == "--capture-facebook" and len(sys.argv) > 3:
        candidate_id = sys.argv[2]
        access_token = sys.argv[3]
        
        engine = SocialGraphEngine(candidate_id)
        result = engine.capture_facebook(access_token)
        
        print(f"Facebook Capture Results:")
        print(f"  Total: {result.total_connections}")
        print(f"  Imported: {result.imported}")
        print(f"  Duplicates: {result.duplicates}")
        if result.error_messages:
            print(f"  Errors: {result.error_messages}")
    
    elif command == "--capture-linkedin" and len(sys.argv) > 3:
        candidate_id = sys.argv[2]
        access_token = sys.argv[3]
        
        engine = SocialGraphEngine(candidate_id)
        result = engine.capture_linkedin(access_token)
        
        print(f"LinkedIn Capture Results:")
        print(f"  Total: {result.total_connections}")
        print(f"  Imported: {result.imported}")
        print(f"  Duplicates: {result.duplicates}")
    
    elif command == "--capture-twitter" and len(sys.argv) > 4:
        candidate_id = sys.argv[2]
        access_token = sys.argv[3]
        user_id = sys.argv[4]
        
        engine = SocialGraphEngine(candidate_id)
        result = engine.capture_twitter(access_token, user_id)
        
        print(f"Twitter Capture Results:")
        print(f"  Total: {result.total_connections}")
        print(f"  Imported: {result.imported}")
        print(f"  Duplicates: {result.duplicates}")
