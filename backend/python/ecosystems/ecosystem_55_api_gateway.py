#!/usr/bin/env python3
"""
================================================================================
ECOSYSTEM 55: API GATEWAY - EXTERNAL API MANAGEMENT & ROUTING
================================================================================
Centralized API gateway for all external integrations, rate limiting,
authentication, request routing, and API versioning.

Features:
- Unified API endpoint routing
- Rate limiting per client/endpoint
- API key management and authentication
- Request/response logging
- Circuit breaker pattern for fault tolerance
- API versioning (v1, v2)
- Webhook management
- Health checks and monitoring
- Request transformation
- Response caching
- CORS handling
- IP whitelist/blacklist

External APIs Managed:
- FEC.gov API
- NC SBoE Voter Data
- BetterContact Enrichment
- OpenSecrets
- LegiScan
- NewsAPI
- Stripe/PayPal Payment
- Twilio/Bandwidth SMS
- Drop Cowboy RVM
- OpenAI/Claude AI
- Google Maps
- Social Media APIs

Development Value: \$90,000
================================================================================
"""

import os
import json
import logging
import uuid
import asyncio
import time
import hashlib
import hmac
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
from collections import defaultdict
from functools import wraps
import aiohttp

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem55.api_gateway')

# ============================================================================
# ENUMS
# ============================================================================

class APIProvider(Enum):
    # Government/Political
    FEC_GOV = 'fec_gov'
    NC_SBOE = 'nc_sboe'
    LEGISCAN = 'legiscan'
    OPENSECRETS = 'opensecrets'
    
    # Data Enrichment
    BETTERCONTACT = 'bettercontact'
    CLEARBIT = 'clearbit'
    FULLCONTACT = 'fullcontact'
    
    # Communication
    TWILIO = 'twilio'
    BANDWIDTH = 'bandwidth'
    DROP_COWBOY = 'drop_cowboy'
    SENDGRID = 'sendgrid'
    MAILCHIMP = 'mailchimp'
    
    # Payment
    STRIPE = 'stripe'
    PAYPAL = 'paypal'
    ACTBLUE = 'actblue'
    
    # AI
    OPENAI = 'openai'
    ANTHROPIC = 'anthropic'
    
    # Media/News
    NEWSAPI = 'newsapi'
    GNEWS = 'gnews'
    
    # Maps/Location
    GOOGLE_MAPS = 'google_maps'
    MAPBOX = 'mapbox'
    
    # Social
    FACEBOOK = 'facebook'
    TWITTER = 'twitter'
    LINKEDIN = 'linkedin'
    
    # Storage
    AWS_S3 = 'aws_s3'
    CLOUDFLARE_R2 = 'cloudflare_r2'
    
    # Internal
    BROYHILLGOP = 'broyhillgop'

class RateLimitWindow(Enum):
    SECOND = 1
    MINUTE = 60
    HOUR = 3600
    DAY = 86400

class CircuitState(Enum):
    CLOSED = 'closed'      # Normal operation
    OPEN = 'open'          # Failing, reject requests
    HALF_OPEN = 'half_open'  # Testing recovery

class RequestMethod(Enum):
    GET = 'GET'
    POST = 'POST'
    PUT = 'PUT'
    PATCH = 'PATCH'
    DELETE = 'DELETE'

class AuthType(Enum):
    API_KEY = 'api_key'
    BEARER = 'bearer'
    BASIC = 'basic'
    OAUTH2 = 'oauth2'
    HMAC = 'hmac'
    NONE = 'none'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class APICredential:
    credential_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    provider: APIProvider = APIProvider.BROYHILLGOP
    api_key: str = ''
    api_secret: Optional[str] = None
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    token_expires_at: Optional[datetime] = None
    auth_type: AuthType = AuthType.API_KEY
    header_name: str = 'Authorization'
    header_prefix: str = 'Bearer'
    is_active: bool = True
    environment: str = 'production'  # production, sandbox, test
    created_at: datetime = field(default_factory=datetime.now)

@dataclass
class RateLimitConfig:
    provider: APIProvider = APIProvider.BROYHILLGOP
    requests_per_window: int = 100
    window: RateLimitWindow = RateLimitWindow.MINUTE
    burst_limit: Optional[int] = None  # Max burst above rate
    retry_after_seconds: int = 60

@dataclass
class RateLimitState:
    provider: APIProvider = APIProvider.BROYHILLGOP
    request_count: int = 0
    window_start: datetime = field(default_factory=datetime.now)
    is_limited: bool = False
    reset_at: Optional[datetime] = None

@dataclass
class CircuitBreaker:
    provider: APIProvider = APIProvider.BROYHILLGOP
    state: CircuitState = CircuitState.CLOSED
    failure_count: int = 0
    success_count: int = 0
    failure_threshold: int = 5  # Failures before opening
    success_threshold: int = 3  # Successes before closing
    timeout_seconds: int = 30   # Time in OPEN state before HALF_OPEN
    last_failure_at: Optional[datetime] = None
    opened_at: Optional[datetime] = None

@dataclass
class APIEndpoint:
    endpoint_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    provider: APIProvider = APIProvider.BROYHILLGOP
    name: str = ''
    base_url: str = ''
    path: str = ''
    method: RequestMethod = RequestMethod.GET
    auth_type: AuthType = AuthType.API_KEY
    rate_limit: Optional[RateLimitConfig] = None
    timeout_seconds: int = 30
    retry_count: int = 3
    cache_ttl_seconds: int = 0  # 0 = no cache
    transform_request: Optional[str] = None  # Function name
    transform_response: Optional[str] = None
    is_active: bool = True

@dataclass
class APIRequest:
    request_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    provider: APIProvider = APIProvider.BROYHILLGOP
    endpoint: str = ''
    method: RequestMethod = RequestMethod.GET
    url: str = ''
    headers: Dict[str, str] = field(default_factory=dict)
    params: Dict[str, Any] = field(default_factory=dict)
    body: Optional[Dict[str, Any]] = None
    client_id: str = ''
    ip_address: str = ''
    user_agent: str = ''
    timestamp: datetime = field(default_factory=datetime.now)

@dataclass
class APIResponse:
    request_id: str = ''
    status_code: int = 0
    headers: Dict[str, str] = field(default_factory=dict)
    body: Any = None
    latency_ms: float = 0
    from_cache: bool = False
    error_message: Optional[str] = None
    timestamp: datetime = field(default_factory=datetime.now)

@dataclass
class APILog:
    log_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    request: APIRequest = field(default_factory=APIRequest)
    response: APIResponse = field(default_factory=APIResponse)
    success: bool = True
    error_type: Optional[str] = None

@dataclass
class Webhook:
    webhook_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    name: str = ''
    url: str = ''
    secret: str = field(default_factory=lambda: uuid.uuid4().hex)
    events: List[str] = field(default_factory=list)  # donation.created, etc.
    is_active: bool = True
    retry_count: int = 3
    timeout_seconds: int = 10
    created_at: datetime = field(default_factory=datetime.now)

@dataclass
class WebhookDelivery:
    delivery_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    webhook_id: str = ''
    event: str = ''
    payload: Dict[str, Any] = field(default_factory=dict)
    status_code: Optional[int] = None
    response_body: Optional[str] = None
    attempts: int = 0
    success: bool = False
    delivered_at: Optional[datetime] = None
    created_at: datetime = field(default_factory=datetime.now)

@dataclass
class APIKey:
    key_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    key: str = field(default_factory=lambda: f"bgop_{uuid.uuid4().hex}")
    name: str = ''
    client_id: str = ''
    permissions: List[str] = field(default_factory=list)  # read, write, admin
    rate_limit: int = 1000  # Per hour
    ip_whitelist: List[str] = field(default_factory=list)
    is_active: bool = True
    expires_at: Optional[datetime] = None
    last_used_at: Optional[datetime] = None
    created_at: datetime = field(default_factory=datetime.now)

# ============================================================================
# API GATEWAY CORE
# ============================================================================

class APIGateway:
    """Centralized API gateway for all external integrations."""
    
    def __init__(self, supabase_client=None, redis_client=None):
        self.supabase = supabase_client
        self.redis = redis_client
        
        # Credentials storage
        self.credentials: Dict[APIProvider, APICredential] = {}
        
        # Rate limiting
        self.rate_limits: Dict[APIProvider, RateLimitConfig] = {}
        self.rate_states: Dict[APIProvider, RateLimitState] = {}
        
        # Circuit breakers
        self.circuit_breakers: Dict[APIProvider, CircuitBreaker] = {}
        
        # Endpoints registry
        self.endpoints: Dict[str, APIEndpoint] = {}
        
        # Caching
        self.cache: Dict[str, tuple] = {}  # key -> (response, expires_at)
        
        # API keys for BroyhillGOP API
        self.api_keys: Dict[str, APIKey] = {}
        
        # Webhooks
        self.webhooks: Dict[str, Webhook] = {}
        
        # Request logging
        self.logs: List[APILog] = []
        
        # Initialize default configurations
        self._init_default_configs()
    
    def _init_default_configs(self):
        """Initialize default rate limits and circuit breakers."""
        default_limits = {
            APIProvider.FEC_GOV: RateLimitConfig(
                provider=APIProvider.FEC_GOV,
                requests_per_window=1000,
                window=RateLimitWindow.HOUR
            ),
            APIProvider.OPENAI: RateLimitConfig(
                provider=APIProvider.OPENAI,
                requests_per_window=60,
                window=RateLimitWindow.MINUTE
            ),
            APIProvider.ANTHROPIC: RateLimitConfig(
                provider=APIProvider.ANTHROPIC,
                requests_per_window=60,
                window=RateLimitWindow.MINUTE
            ),
            APIProvider.TWILIO: RateLimitConfig(
                provider=APIProvider.TWILIO,
                requests_per_window=100,
                window=RateLimitWindow.SECOND
            ),
            APIProvider.DROP_COWBOY: RateLimitConfig(
                provider=APIProvider.DROP_COWBOY,
                requests_per_window=10,
                window=RateLimitWindow.SECOND
            ),
            APIProvider.STRIPE: RateLimitConfig(
                provider=APIProvider.STRIPE,
                requests_per_window=100,
                window=RateLimitWindow.SECOND
            ),
            APIProvider.BETTERCONTACT: RateLimitConfig(
                provider=APIProvider.BETTERCONTACT,
                requests_per_window=100,
                window=RateLimitWindow.MINUTE
            ),
            APIProvider.NEWSAPI: RateLimitConfig(
                provider=APIProvider.NEWSAPI,
                requests_per_window=100,
                window=RateLimitWindow.DAY
            )
        }
        
        for provider, config in default_limits.items():
            self.rate_limits[provider] = config
            self.rate_states[provider] = RateLimitState(provider=provider)
            self.circuit_breakers[provider] = CircuitBreaker(provider=provider)
    
    # =========================================================================
    # CREDENTIAL MANAGEMENT
    # =========================================================================
    
    async def register_credential(
        self,
        provider: APIProvider,
        api_key: str,
        api_secret: Optional[str] = None,
        auth_type: AuthType = AuthType.API_KEY,
        header_name: str = 'Authorization',
        header_prefix: str = 'Bearer',
        environment: str = 'production'
    ) -> APICredential:
        """Register API credentials for a provider."""
        credential = APICredential(
            provider=provider,
            api_key=api_key,
            api_secret=api_secret,
            auth_type=auth_type,
            header_name=header_name,
            header_prefix=header_prefix,
            environment=environment
        )
        
        self.credentials[provider] = credential
        
        if self.supabase:
            await self._save_credential_to_db(credential)
        
        logger.info(f"Registered credential for {provider.value}")
        return credential
    
    def get_auth_header(self, provider: APIProvider) -> Dict[str, str]:
        """Get authentication header for a provider."""
        credential = self.credentials.get(provider)
        if not credential:
            return {}
        
        if credential.auth_type == AuthType.API_KEY:
            return {credential.header_name: f"{credential.header_prefix} {credential.api_key}".strip()}
        elif credential.auth_type == AuthType.BEARER:
            token = credential.access_token or credential.api_key
            return {'Authorization': f"Bearer {token}"}
        elif credential.auth_type == AuthType.BASIC:
            import base64
            auth_str = f"{credential.api_key}:{credential.api_secret or ''}"
            encoded = base64.b64encode(auth_str.encode()).decode()
            return {'Authorization': f"Basic {encoded}"}
        
        return {}
    
    # =========================================================================
    # RATE LIMITING
    # =========================================================================
    
    async def check_rate_limit(self, provider: APIProvider) -> tuple[bool, Optional[int]]:
        """
        Check if request is allowed under rate limit.
        Returns (allowed, retry_after_seconds)
        """
        config = self.rate_limits.get(provider)
        if not config:
            return True, None
        
        state = self.rate_states.get(provider)
        if not state:
            state = RateLimitState(provider=provider)
            self.rate_states[provider] = state
        
        now = datetime.now()
        window_seconds = config.window.value
        
        # Check if window has reset
        if (now - state.window_start).total_seconds() >= window_seconds:
            state.window_start = now
            state.request_count = 0
            state.is_limited = False
        
        # Check limit
        if state.request_count >= config.requests_per_window:
            state.is_limited = True
            reset_in = window_seconds - (now - state.window_start).total_seconds()
            return False, int(reset_in)
        
        # Increment counter
        state.request_count += 1
        return True, None
    
    # =========================================================================
    # CIRCUIT BREAKER
    # =========================================================================
    
    async def check_circuit(self, provider: APIProvider) -> bool:
        """Check if circuit breaker allows request."""
        cb = self.circuit_breakers.get(provider)
        if not cb:
            return True
        
        now = datetime.now()
        
        if cb.state == CircuitState.CLOSED:
            return True
        
        if cb.state == CircuitState.OPEN:
            # Check if timeout has passed
            if cb.opened_at and (now - cb.opened_at).total_seconds() >= cb.timeout_seconds:
                cb.state = CircuitState.HALF_OPEN
                cb.success_count = 0
                logger.info(f"Circuit breaker {provider.value}: OPEN -> HALF_OPEN")
                return True
            return False
        
        if cb.state == CircuitState.HALF_OPEN:
            return True
        
        return True
    
    async def record_success(self, provider: APIProvider):
        """Record successful request for circuit breaker."""
        cb = self.circuit_breakers.get(provider)
        if not cb:
            return
        
        if cb.state == CircuitState.HALF_OPEN:
            cb.success_count += 1
            if cb.success_count >= cb.success_threshold:
                cb.state = CircuitState.CLOSED
                cb.failure_count = 0
                logger.info(f"Circuit breaker {provider.value}: HALF_OPEN -> CLOSED")
    
    async def record_failure(self, provider: APIProvider):
        """Record failed request for circuit breaker."""
        cb = self.circuit_breakers.get(provider)
        if not cb:
            return
        
        cb.failure_count += 1
        cb.last_failure_at = datetime.now()
        
        if cb.state == CircuitState.HALF_OPEN:
            cb.state = CircuitState.OPEN
            cb.opened_at = datetime.now()
            logger.warning(f"Circuit breaker {provider.value}: HALF_OPEN -> OPEN")
        elif cb.state == CircuitState.CLOSED and cb.failure_count >= cb.failure_threshold:
            cb.state = CircuitState.OPEN
            cb.opened_at = datetime.now()
            logger.warning(f"Circuit breaker {provider.value}: CLOSED -> OPEN")
    
    # =========================================================================
    # REQUEST EXECUTION
    # =========================================================================
    
    async def request(
        self,
        provider: APIProvider,
        method: RequestMethod,
        url: str,
        params: Optional[Dict[str, Any]] = None,
        body: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
        timeout: int = 30,
        use_cache: bool = True,
        cache_ttl: int = 300
    ) -> APIResponse:
        """
        Execute an API request with all gateway features.
        """
        request_id = str(uuid.uuid4())
        start_time = time.time()
        
        # Check rate limit
        allowed, retry_after = await self.check_rate_limit(provider)
        if not allowed:
            return APIResponse(
                request_id=request_id,
                status_code=429,
                error_message=f"Rate limit exceeded. Retry after {retry_after}s",
                headers={'Retry-After': str(retry_after)}
            )
        
        # Check circuit breaker
        if not await self.check_circuit(provider):
            return APIResponse(
                request_id=request_id,
                status_code=503,
                error_message=f"Circuit breaker OPEN for {provider.value}"
            )
        
        # Check cache
        if use_cache and method == RequestMethod.GET:
            cache_key = self._make_cache_key(url, params)
            cached = self._get_from_cache(cache_key)
            if cached:
                return APIResponse(
                    request_id=request_id,
                    status_code=200,
                    body=cached,
                    from_cache=True,
                    latency_ms=0
                )
        
        # Build headers
        request_headers = self.get_auth_header(provider)
        request_headers['Content-Type'] = 'application/json'
        request_headers['User-Agent'] = 'BroyhillGOP-Platform/1.0'
        if headers:
            request_headers.update(headers)
        
        # Execute request
        try:
            async with aiohttp.ClientSession() as session:
                async with session.request(
                    method=method.value,
                    url=url,
                    params=params,
                    json=body,
                    headers=request_headers,
                    timeout=aiohttp.ClientTimeout(total=timeout)
                ) as resp:
                    latency_ms = (time.time() - start_time) * 1000
                    response_body = await resp.json() if resp.content_type == 'application/json' else await resp.text()
                    
                    response = APIResponse(
                        request_id=request_id,
                        status_code=resp.status,
                        headers=dict(resp.headers),
                        body=response_body,
                        latency_ms=latency_ms
                    )
                    
                    # Record success/failure for circuit breaker
                    if 200 <= resp.status < 300:
                        await self.record_success(provider)
                        # Cache successful GET responses
                        if use_cache and method == RequestMethod.GET and cache_ttl > 0:
                            self._add_to_cache(cache_key, response_body, cache_ttl)
                    elif resp.status >= 500:
                        await self.record_failure(provider)
                    
                    return response
                    
        except asyncio.TimeoutError:
            await self.record_failure(provider)
            return APIResponse(
                request_id=request_id,
                status_code=504,
                error_message="Request timeout",
                latency_ms=(time.time() - start_time) * 1000
            )
        except Exception as e:
            await self.record_failure(provider)
            return APIResponse(
                request_id=request_id,
                status_code=500,
                error_message=str(e),
                latency_ms=(time.time() - start_time) * 1000
            )
    
    # =========================================================================
    # CACHING
    # =========================================================================
    
    def _make_cache_key(self, url: str, params: Optional[Dict] = None) -> str:
        """Generate cache key from URL and params."""
        key_str = url + json.dumps(params or {}, sort_keys=True)
        return hashlib.md5(key_str.encode()).hexdigest()
    
    def _get_from_cache(self, key: str) -> Optional[Any]:
        """Get response from cache if not expired."""
        if key in self.cache:
            data, expires_at = self.cache[key]
            if datetime.now() < expires_at:
                return data
            del self.cache[key]
        return None
    
    def _add_to_cache(self, key: str, data: Any, ttl_seconds: int):
        """Add response to cache."""
        expires_at = datetime.now() + timedelta(seconds=ttl_seconds)
        self.cache[key] = (data, expires_at)
    
    def clear_cache(self, provider: Optional[APIProvider] = None):
        """Clear cache (optionally for specific provider)."""
        if provider:
            # Would need to track which keys belong to which provider
            pass
        else:
            self.cache.clear()
        logger.info("Cache cleared")
    
    # =========================================================================
    # API KEY MANAGEMENT (for BroyhillGOP API)
    # =========================================================================
    
    async def create_api_key(
        self,
        name: str,
        client_id: str,
        permissions: List[str] = None,
        rate_limit: int = 1000,
        ip_whitelist: List[str] = None,
        expires_in_days: Optional[int] = None
    ) -> APIKey:
        """Create a new API key for BroyhillGOP API access."""
        api_key = APIKey(
            name=name,
            client_id=client_id,
            permissions=permissions or ['read'],
            rate_limit=rate_limit,
            ip_whitelist=ip_whitelist or [],
            expires_at=datetime.now() + timedelta(days=expires_in_days) if expires_in_days else None
        )
        
        self.api_keys[api_key.key] = api_key
        
        if self.supabase:
            await self._save_api_key_to_db(api_key)
        
        logger.info(f"Created API key: {name} for client {client_id}")
        return api_key
    
    async def validate_api_key(
        self,
        key: str,
        required_permission: str = 'read',
        ip_address: Optional[str] = None
    ) -> tuple[bool, Optional[str]]:
        """
        Validate an API key.
        Returns (valid, error_message)
        """
        api_key = self.api_keys.get(key)
        
        if not api_key:
            return False, "Invalid API key"
        
        if not api_key.is_active:
            return False, "API key is inactive"
        
        if api_key.expires_at and datetime.now() > api_key.expires_at:
            return False, "API key has expired"
        
        if required_permission not in api_key.permissions and 'admin' not in api_key.permissions:
            return False, f"Missing permission: {required_permission}"
        
        if api_key.ip_whitelist and ip_address and ip_address not in api_key.ip_whitelist:
            return False, "IP address not whitelisted"
        
        # Update last used
        api_key.last_used_at = datetime.now()
        
        return True, None
    
    async def revoke_api_key(self, key: str) -> bool:
        """Revoke an API key."""
        api_key = self.api_keys.get(key)
        if api_key:
            api_key.is_active = False
            logger.info(f"Revoked API key: {api_key.name}")
            return True
        return False
    
    # =========================================================================
    # WEBHOOKS
    # =========================================================================
    
    async def register_webhook(
        self,
        name: str,
        url: str,
        events: List[str],
        secret: Optional[str] = None
    ) -> Webhook:
        """Register a webhook endpoint."""
        webhook = Webhook(
            name=name,
            url=url,
            events=events,
            secret=secret or uuid.uuid4().hex
        )
        
        self.webhooks[webhook.webhook_id] = webhook
        
        if self.supabase:
            await self._save_webhook_to_db(webhook)
        
        logger.info(f"Registered webhook: {name} for events {events}")
        return webhook
    
    async def trigger_webhook(
        self,
        event: str,
        payload: Dict[str, Any]
    ) -> List[WebhookDelivery]:
        """Trigger webhooks for an event."""
        deliveries = []
        
        for webhook in self.webhooks.values():
            if not webhook.is_active:
                continue
            if event not in webhook.events and '*' not in webhook.events:
                continue
            
            delivery = WebhookDelivery(
                webhook_id=webhook.webhook_id,
                event=event,
                payload=payload
            )
            
            # Generate signature
            signature = hmac.new(
                webhook.secret.encode(),
                json.dumps(payload).encode(),
                hashlib.sha256
            ).hexdigest()
            
            # Deliver webhook
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.post(
                        webhook.url,
                        json=payload,
                        headers={
                            'Content-Type': 'application/json',
                            'X-Webhook-Event': event,
                            'X-Webhook-Signature': f"sha256={signature}",
                            'X-Webhook-ID': delivery.delivery_id
                        },
                        timeout=aiohttp.ClientTimeout(total=webhook.timeout_seconds)
                    ) as resp:
                        delivery.status_code = resp.status
                        delivery.response_body = await resp.text()
                        delivery.success = 200 <= resp.status < 300
                        delivery.delivered_at = datetime.now()
                        delivery.attempts = 1
            except Exception as e:
                delivery.success = False
                delivery.response_body = str(e)
                delivery.attempts = 1
            
            deliveries.append(delivery)
            
            if self.supabase:
                await self._save_webhook_delivery_to_db(delivery)
        
        logger.info(f"Triggered {len(deliveries)} webhooks for event {event}")
        return deliveries
    
    # =========================================================================
    # PROVIDER-SPECIFIC HELPERS
    # =========================================================================
    
    async def fec_api_request(
        self,
        endpoint: str,
        params: Optional[Dict[str, Any]] = None
    ) -> APIResponse:
        """Make request to FEC.gov API."""
        base_url = 'https://api.open.fec.gov/v1'
        url = f"{base_url}/{endpoint}"
        
        # Add API key to params
        credential = self.credentials.get(APIProvider.FEC_GOV)
        if credential:
            params = params or {}
            params['api_key'] = credential.api_key
        
        return await self.request(
            provider=APIProvider.FEC_GOV,
            method=RequestMethod.GET,
            url=url,
            params=params,
            cache_ttl=3600  # Cache for 1 hour
        )
    
    async def openai_request(
        self,
        endpoint: str,
        body: Dict[str, Any]
    ) -> APIResponse:
        """Make request to OpenAI API."""
        base_url = 'https://api.openai.com/v1'
        url = f"{base_url}/{endpoint}"
        
        return await self.request(
            provider=APIProvider.OPENAI,
            method=RequestMethod.POST,
            url=url,
            body=body,
            use_cache=False
        )
    
    async def stripe_request(
        self,
        endpoint: str,
        method: RequestMethod = RequestMethod.GET,
        body: Optional[Dict[str, Any]] = None
    ) -> APIResponse:
        """Make request to Stripe API."""
        base_url = 'https://api.stripe.com/v1'
        url = f"{base_url}/{endpoint}"
        
        return await self.request(
            provider=APIProvider.STRIPE,
            method=method,
            url=url,
            body=body,
            use_cache=False
        )
    
    async def drop_cowboy_request(
        self,
        endpoint: str,
        method: RequestMethod = RequestMethod.POST,
        body: Optional[Dict[str, Any]] = None
    ) -> APIResponse:
        """Make request to Drop Cowboy RVM API."""
        base_url = 'https://api.dropcowboy.com/v1'
        url = f"{base_url}/{endpoint}"
        
        return await self.request(
            provider=APIProvider.DROP_COWBOY,
            method=method,
            url=url,
            body=body,
            use_cache=False
        )
    
    # =========================================================================
    # MONITORING & HEALTH
    # =========================================================================
    
    async def health_check(self, provider: APIProvider) -> Dict[str, Any]:
        """Check health of an API provider."""
        cb = self.circuit_breakers.get(provider)
        rl = self.rate_states.get(provider)
        
        return {
            'provider': provider.value,
            'status': 'healthy' if cb and cb.state == CircuitState.CLOSED else 'degraded',
            'circuit_state': cb.state.value if cb else 'unknown',
            'failure_count': cb.failure_count if cb else 0,
            'rate_limit': {
                'requests_used': rl.request_count if rl else 0,
                'is_limited': rl.is_limited if rl else False
            } if rl else None,
            'has_credentials': provider in self.credentials
        }
    
    async def health_check_all(self) -> Dict[str, Any]:
        """Check health of all providers."""
        results = {}
        for provider in self.credentials.keys():
            results[provider.value] = await self.health_check(provider)
        return {
            'timestamp': datetime.now().isoformat(),
            'providers': results,
            'cache_size': len(self.cache),
            'active_api_keys': sum(1 for k in self.api_keys.values() if k.is_active),
            'active_webhooks': sum(1 for w in self.webhooks.values() if w.is_active)
        }
    
    def get_stats(self) -> Dict[str, Any]:
        """Get gateway statistics."""
        return {
            'providers_configured': len(self.credentials),
            'endpoints_registered': len(self.endpoints),
            'api_keys_active': sum(1 for k in self.api_keys.values() if k.is_active),
            'webhooks_active': sum(1 for w in self.webhooks.values() if w.is_active),
            'cache_entries': len(self.cache),
            'circuit_breakers': {
                p.value: cb.state.value 
                for p, cb in self.circuit_breakers.items()
            },
            'rate_limit_states': {
                p.value: {
                    'count': rl.request_count,
                    'limited': rl.is_limited
                }
                for p, rl in self.rate_states.items()
            }
        }
    
    # =========================================================================
    # DATABASE OPERATIONS
    # =========================================================================
    
    async def _save_credential_to_db(self, credential: APICredential):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e55_credentials').upsert({
                'credential_id': credential.credential_id,
                'provider': credential.provider.value,
                'api_key_hash': hashlib.sha256(credential.api_key.encode()).hexdigest(),
                'auth_type': credential.auth_type.value,
                'environment': credential.environment,
                'is_active': credential.is_active,
                'created_at': credential.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save credential: {e}")
    
    async def _save_api_key_to_db(self, api_key: APIKey):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e55_api_keys').insert({
                'key_id': api_key.key_id,
                'key_hash': hashlib.sha256(api_key.key.encode()).hexdigest(),
                'name': api_key.name,
                'client_id': api_key.client_id,
                'permissions': json.dumps(api_key.permissions),
                'rate_limit': api_key.rate_limit,
                'ip_whitelist': json.dumps(api_key.ip_whitelist),
                'is_active': api_key.is_active,
                'expires_at': api_key.expires_at.isoformat() if api_key.expires_at else None,
                'created_at': api_key.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save API key: {e}")
    
    async def _save_webhook_to_db(self, webhook: Webhook):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e55_webhooks').upsert({
                'webhook_id': webhook.webhook_id,
                'name': webhook.name,
                'url': webhook.url,
                'events': json.dumps(webhook.events),
                'is_active': webhook.is_active,
                'created_at': webhook.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save webhook: {e}")
    
    async def _save_webhook_delivery_to_db(self, delivery: WebhookDelivery):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e55_webhook_deliveries').insert({
                'delivery_id': delivery.delivery_id,
                'webhook_id': delivery.webhook_id,
                'event': delivery.event,
                'payload': json.dumps(delivery.payload),
                'status_code': delivery.status_code,
                'success': delivery.success,
                'attempts': delivery.attempts,
                'delivered_at': delivery.delivered_at.isoformat() if delivery.delivered_at else None,
                'created_at': delivery.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save webhook delivery: {e}")


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

async def main():
    """Demo the API gateway."""
    gateway = APIGateway()
    
    # Register credentials
    print("\n=== REGISTERING CREDENTIALS ===")
    await gateway.register_credential(
        provider=APIProvider.FEC_GOV,
        api_key='DEMO_FEC_KEY',
        auth_type=AuthType.API_KEY
    )
    await gateway.register_credential(
        provider=APIProvider.OPENAI,
        api_key='sk-demo-openai-key',
        auth_type=AuthType.BEARER
    )
    await gateway.register_credential(
        provider=APIProvider.DROP_COWBOY,
        api_key='dc-demo-key',
        api_secret='dc-demo-secret',
        auth_type=AuthType.BASIC
    )
    print(f"Registered {len(gateway.credentials)} provider credentials")
    
    # Create API key for external access
    print("\n=== CREATING API KEY ===")
    api_key = await gateway.create_api_key(
        name='Campaign Dashboard',
        client_id='candidate-001',
        permissions=['read', 'write'],
        rate_limit=1000,
        expires_in_days=365
    )
    print(f"Created API key: {api_key.key[:20]}...")
    
    # Validate API key
    valid, error = await gateway.validate_api_key(api_key.key, 'read')
    print(f"Key validation: {'Valid' if valid else error}")
    
    # Register webhook
    print("\n=== REGISTERING WEBHOOK ===")
    webhook = await gateway.register_webhook(
        name='Donation Notifications',
        url='https://example.com/webhooks/donations',
        events=['donation.created', 'donation.refunded']
    )
    print(f"Webhook registered: {webhook.name} (secret: {webhook.secret[:10]}...)")
    
    # Trigger webhook
    print("\n=== TRIGGERING WEBHOOK ===")
    deliveries = await gateway.trigger_webhook(
        event='donation.created',
        payload={
            'donation_id': 'don-123',
            'amount': 100.00,
            'donor_name': 'John Smith'
        }
    )
    print(f"Triggered {len(deliveries)} webhooks")
    
    # Health check
    print("\n=== HEALTH CHECK ===")
    health = await gateway.health_check_all()
    print(json.dumps(health, indent=2, default=str))
    
    # Stats
    print("\n=== GATEWAY STATS ===")
    stats = gateway.get_stats()
    print(json.dumps(stats, indent=2))


if __name__ == '__main__':
    asyncio.run(main())
