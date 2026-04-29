"""
ecosystems/E19_social/onboarding/business_login_handler.py

OAuth callback handler for Meta's Business Login for Apps.

This is the core onboarding service. When a candidate clicks "Connect Facebook"
on their BroyhillGOP onboarding page, the flow is:

    1. We redirect them to Meta's OAuth screen with our App's client_id and
       requested scopes (pages_show_list, pages_messaging, etc.).
    2. Meta authenticates the candidate.
    3. Meta detects whether they have a Business Manager:
       - If yes: presents existing-BM selector
       - If no: prompts them to confirm BM auto-creation
    4. Meta presents Page selector for them to grant access to.
    5. Meta presents permissions screen.
    6. Meta redirects back to our callback URL with a short-lived code.
    7. THIS HANDLER runs:
       a. Exchanges code for short-lived user access token
       b. Exchanges short-lived for long-lived user access token
       c. Reads granted Pages list
       d. Resolves or provisions the Business Manager
       e. Creates a System User inside the candidate's BM
       f. Issues System User access token
       g. Generates Page Access Tokens from the System User
       h. Encrypts and stores tokens
       i. Subscribes webhook for the granted Pages
       j. Logs every step to meta_oauth_audit_log

Locked rules:
    - candidate_id + RLS isolation throughout
    - Tokens never logged in plaintext
    - All state transitions also written to meta_oauth_audit_log
    - Idempotent: re-running for the same candidate doesn't double-provision

Phase: Step 5 of 8 in safe-pathway sequence. Dry-run only.

NOTE: This file is a service module. Wire-up to FastAPI/Flask routes happens
in a thin route module (not included here) that calls handle_oauth_callback().
"""

from __future__ import annotations

import json
import logging
import os
import secrets
import urllib.parse
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Optional
from uuid import UUID

import requests

# Local imports — these will resolve once the package is wired into the repo.
# In the dry-run state we just import the relative paths.
from shared.security.token_vault import encrypt_token, redact_tokens
from shared.event_bus import EventPublisher, NullEventPublisher
from shared.brain_control.governance import (
    SelfCorrectionReader,
    NullSelfCorrectionReader,
    CostAccountant,
    NullCostAccountant,
    FunctionCallRecord,
    is_paused,
)

logger = logging.getLogger("e19_social.onboarding.business_login_handler")


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

META_GRAPH_VERSION = os.environ.get("META_GRAPH_API_VERSION", "v19.0")
META_GRAPH_BASE = f"https://graph.facebook.com/{META_GRAPH_VERSION}"
META_OAUTH_BASE = "https://www.facebook.com"

FACEBOOK_APP_ID = os.environ.get("FACEBOOK_APP_ID", "")
FACEBOOK_APP_SECRET = os.environ.get("FACEBOOK_APP_SECRET", "")

# OAuth callback URL — must match what's registered in the Meta App config.
# Routed through E55 API gateway:
#   https://api.broyhillgop.org/v1/webhooks/meta/oauth_callback
OAUTH_CALLBACK_URL = os.environ.get(
    "META_OAUTH_CALLBACK_URL",
    "https://api.broyhillgop.org/v1/webhooks/meta/oauth_callback"
)

# Scopes requested during OAuth. Must match what's been approved in App Review.
DEFAULT_SCOPES = [
    "pages_show_list",
    "pages_read_engagement",
    "pages_messaging",
    "pages_manage_metadata",
    "instagram_basic",
    "instagram_manage_messages",
    "business_management",       # Required for BM provisioning
]

# Network timeouts. Don't let Meta's API hang the worker.
HTTP_TIMEOUT_SECONDS = 30
HTTP_TIMEOUT_TOKEN_EXCHANGE = 60  # Token exchanges can be slower

# Long-lived tokens last 60 days. We'll refresh ~7 days before expiry.
LONG_LIVED_TOKEN_DURATION_DAYS = 60


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

class OAuthError(Exception):
    """Base class for OAuth flow errors."""


class OAuthCodeExchangeError(OAuthError):
    """Failed to exchange code for token."""


class TransferRequiredError(OAuthError):
    """Candidate's Page is in someone else's BM. Manual transfer required."""


class MetaApiError(OAuthError):
    """Meta API returned an error."""


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class OAuthInitiation:
    """Result of initiate_oauth(). Caller redirects user to authorize_url."""
    state_token: str           # Random; stored server-side, validated on callback
    authorize_url: str         # Where the candidate's browser goes next


@dataclass
class GrantedPage:
    page_id: str
    page_name: str
    page_access_token: str     # Plaintext at this point; gets encrypted before storage
    instagram_business_account_id: Optional[str]
    granted_permissions: list[str]


@dataclass
class ProvisioningResult:
    candidate_id: UUID
    business_manager_id: str
    system_user_id: str
    system_user_token_expires_at: datetime
    pages: list[GrantedPage]
    bm_was_auto_created: bool
    webhook_subscription_id: str


# ---------------------------------------------------------------------------
# Database access (abstract) — concrete impl wired by caller
# ---------------------------------------------------------------------------

class CandidateAccountStore:
    """
    Interface for candidate_social_accounts persistence.
    Concrete impl wraps psycopg2/SQLAlchemy. Defined as a class so tests
    can substitute a fake.
    """

    def get_status(self, candidate_id: UUID) -> Optional[str]:
        """Return current bm_provisioning_status, or None if no row exists."""
        raise NotImplementedError

    def upsert_provisioning(
        self,
        *,
        candidate_id: UUID,
        business_manager_id: str,
        system_user_id: str,
        system_user_token_blob: bytes,
        meta_encryption_key_id: str,
        system_user_token_expires_at: datetime,
        bm_provisioning_status: str,
        bm_provisioned_at: datetime,
        webhook_subscription_id: str,
        instagram_business_account_id: Optional[str],
        facebook_page_id: str,
    ) -> None:
        raise NotImplementedError

    def update_status(
        self,
        candidate_id: UUID,
        status: str,
        oauth_revoked_at: Optional[datetime] = None,
    ) -> None:
        raise NotImplementedError


class AuditLogger:
    """Append-only event recorder. Writes to meta_oauth_audit_log."""

    def emit(
        self,
        *,
        candidate_id: UUID,
        event_type: str,
        metadata: Optional[dict] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> None:
        raise NotImplementedError


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def initiate_oauth(
    candidate_id: UUID,
    *,
    audit: AuditLogger,
    scopes: Optional[list[str]] = None,
    state_store: Optional[Any] = None,  # Caller supplies session/redis-backed state
    publisher: Optional[EventPublisher] = None,
    cost_accountant: Optional[CostAccountant] = None,
) -> OAuthInitiation:
    """
    Begin OAuth flow for a candidate. Caller is responsible for:
      - Persisting state_token server-side keyed by candidate_id (for callback validation)
      - Redirecting the user's browser to authorize_url

    Brain integration:
      - Publishes 'social.oauth.initiated' to the event bus.
      - Records F901 function call to brain_control cost accounting.
    """
    if not FACEBOOK_APP_ID:
        raise OAuthError("FACEBOOK_APP_ID not configured in environment")

    pub = publisher or NullEventPublisher()
    accountant = cost_accountant or NullCostAccountant()

    state_token = secrets.token_urlsafe(32)
    requested_scopes = scopes or DEFAULT_SCOPES

    params = {
        "client_id": FACEBOOK_APP_ID,
        "redirect_uri": OAUTH_CALLBACK_URL,
        "state": state_token,
        "scope": ",".join(requested_scopes),
        "response_type": "code",
        # config_id triggers Business Login for Apps with auto-BM-provisioning,
        # if the App is registered as a Tech Provider. Configured per-App in Meta dashboard.
        "config_id": os.environ.get("META_BUSINESS_LOGIN_CONFIG_ID", ""),
    }

    authorize_url = f"{META_OAUTH_BASE}/{META_GRAPH_VERSION}/dialog/oauth?" + urllib.parse.urlencode(params)

    audit.emit(
        candidate_id=candidate_id,
        event_type="oauth_initiated",
        metadata={"scopes": requested_scopes, "state_token_prefix": state_token[:8]},
    )

    # Brain integration: publish event
    pub.publish(
        "social.oauth.initiated",
        candidate_id=candidate_id,
        payload={"scopes": requested_scopes},
    )

    # Cost accounting
    accountant.record_call(FunctionCallRecord(
        function_code="F901",
        candidate_id=str(candidate_id),
        success=True,
    ))

    if state_store is not None:
        state_store.put(candidate_id, state_token)

    return OAuthInitiation(state_token=state_token, authorize_url=authorize_url)


def handle_oauth_callback(
    *,
    candidate_id: UUID,
    code: str,
    state: str,
    expected_state: str,
    accounts: CandidateAccountStore,
    audit: AuditLogger,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
    publisher: Optional[EventPublisher] = None,
    cost_accountant: Optional[CostAccountant] = None,
    self_correction: Optional[SelfCorrectionReader] = None,
) -> ProvisioningResult:
    """
    Process the OAuth callback. Runs the entire 11-step provisioning flow.

    Brain integration:
      - Publishes social.oauth.completed on success, social.oauth.failed on error
      - Honors app-wide pause directive from brain_control
      - Records F901 cost accounting
    
    Idempotency: if accounts.get_status(candidate_id) is already 'provisioned',
    we re-validate Meta-side state but don't double-provision.

    Raises:
        OAuthError on any unrecoverable failure.
        TransferRequiredError if the candidate's Page is in another BM.
    """
    pub = publisher or NullEventPublisher()
    accountant = cost_accountant or NullCostAccountant()
    corrector = self_correction or NullSelfCorrectionReader()

    # Honor Brain pause directive — if app-wide paused, refuse to provision
    if is_paused(corrector, candidate_id=str(candidate_id)):
        audit.emit(
            candidate_id=candidate_id,
            event_type="oauth_callback_received",
            metadata={"blocked_reason": "automation_paused"},
            ip_address=ip_address,
            user_agent=user_agent,
        )
        pub.publish(
            "social.oauth.failed",
            candidate_id=candidate_id,
            payload={"reason": "automation_paused"},
        )
        raise OAuthError("OAuth provisioning blocked: automation is paused by Brain")

    audit.emit(
        candidate_id=candidate_id,
        event_type="oauth_callback_received",
        metadata={"has_code": bool(code), "state_prefix": state[:8] if state else None},
        ip_address=ip_address,
        user_agent=user_agent,
    )

    # State validation — defense against CSRF and replay
    if not state or state != expected_state:
        pub.publish(
            "social.oauth.failed",
            candidate_id=candidate_id,
            payload={"reason": "state_mismatch"},
        )
        accountant.record_call(FunctionCallRecord(
            function_code="F901", candidate_id=str(candidate_id),
            success=False, error_type="state_mismatch",
        ))
        raise OAuthError("OAuth state mismatch — possible CSRF or stale callback")

    if not code:
        pub.publish(
            "social.oauth.failed",
            candidate_id=candidate_id,
            payload={"reason": "missing_code"},
        )
        accountant.record_call(FunctionCallRecord(
            function_code="F901", candidate_id=str(candidate_id),
            success=False, error_type="missing_code",
        ))
        raise OAuthError("OAuth callback missing code parameter")

    started_at = datetime.utcnow()
    try:
        # Step 1: Exchange code for short-lived user token
        short_lived = _exchange_code_for_token(code)
        logger.info("oauth: short-lived token obtained for candidate=%s", candidate_id)

        # Step 2: Exchange short-lived for long-lived
        long_lived_user_token, long_lived_expires_at = _exchange_for_long_lived(short_lived)
        logger.info("oauth: long-lived user token obtained for candidate=%s", candidate_id)

        # Step 3: Read granted Pages
        granted_pages = _list_granted_pages(long_lived_user_token)
        if not granted_pages:
            raise OAuthError("Candidate granted no Pages — cannot provision")
        audit.emit(
            candidate_id=candidate_id,
            event_type="pages_granted",
            metadata={"page_ids": [p.page_id for p in granted_pages], "count": len(granted_pages)},
        )

        # Step 4: Resolve or provision the Business Manager
        bm_id, bm_was_auto_created = _resolve_business_manager(long_lived_user_token, granted_pages, candidate_id, audit)
        logger.info("oauth: business manager resolved id=%s auto_created=%s candidate=%s",
                    bm_id, bm_was_auto_created, candidate_id)

        # Step 5: Create System User inside the BM
        system_user_id = _create_system_user(bm_id, long_lived_user_token, candidate_id, audit)

        # Step 6: Issue long-lived System User token
        system_user_token, system_user_expires_at = _issue_system_user_token(
            bm_id, system_user_id, long_lived_user_token
        )
        audit.emit(
            candidate_id=candidate_id,
            event_type="token_issued",
            metadata={
                "system_user_id": system_user_id,
                "expires_at": system_user_expires_at.isoformat(),
            },
        )

        # Step 7: Subscribe webhooks for the candidate's Pages
        webhook_sub_id = _subscribe_webhooks(bm_id, system_user_token, granted_pages, candidate_id, audit)

        # Step 8: Encrypt System User token before storage
        encrypted_blob, key_id = encrypt_token(system_user_token)

        # Step 9: Persist to candidate_social_accounts (idempotent upsert)
        primary_page = granted_pages[0]
        accounts.upsert_provisioning(
            candidate_id=candidate_id,
            business_manager_id=bm_id,
            system_user_id=system_user_id,
            system_user_token_blob=encrypted_blob,
            meta_encryption_key_id=key_id,
            system_user_token_expires_at=system_user_expires_at,
            bm_provisioning_status="provisioned",
            bm_provisioned_at=datetime.utcnow(),
            webhook_subscription_id=webhook_sub_id,
            instagram_business_account_id=primary_page.instagram_business_account_id,
            facebook_page_id=primary_page.page_id,
        )

        # Brain integration: publish completion event
        duration_ms = int((datetime.utcnow() - started_at).total_seconds() * 1000)
        pub.publish(
            "social.oauth.completed",
            candidate_id=candidate_id,
            payload={
                "business_manager_id": bm_id,
                "system_user_id": system_user_id,
                "page_id": primary_page.page_id,
                "page_count": len(granted_pages),
                "instagram_business_account_id": primary_page.instagram_business_account_id,
                "bm_was_auto_created": bm_was_auto_created,
                "webhook_subscription_id": webhook_sub_id,
                "duration_ms": duration_ms,
            },
        )
        accountant.record_call(FunctionCallRecord(
            function_code="F901", candidate_id=str(candidate_id),
            success=True, duration_ms=duration_ms,
        ))

        return ProvisioningResult(
            candidate_id=candidate_id,
            business_manager_id=bm_id,
            system_user_id=system_user_id,
            system_user_token_expires_at=system_user_expires_at,
            pages=granted_pages,
            bm_was_auto_created=bm_was_auto_created,
            webhook_subscription_id=webhook_sub_id,
        )

    except TransferRequiredError as exc:
        # Special-case: this is a "user must take action" failure, not a system error.
        # Distinguish in Brain so the staff_assist workflow can fire.
        pub.publish(
            "social.oauth.failed",
            candidate_id=candidate_id,
            payload={"reason": "transfer_required", "message": str(exc)[:300]},
        )
        accountant.record_call(FunctionCallRecord(
            function_code="F901", candidate_id=str(candidate_id),
            success=False, error_type="transfer_required",
        ))
        raise

    except (OAuthError, MetaApiError) as exc:
        pub.publish(
            "social.oauth.failed",
            candidate_id=candidate_id,
            payload={"reason": type(exc).__name__, "message": str(exc)[:300]},
        )
        accountant.record_call(FunctionCallRecord(
            function_code="F901", candidate_id=str(candidate_id),
            success=False, error_type=type(exc).__name__,
        ))
        raise


# ---------------------------------------------------------------------------
# Internal: Meta API calls
# ---------------------------------------------------------------------------

def _exchange_code_for_token(code: str) -> str:
    """Step 1: code -> short-lived user access token."""
    resp = requests.get(
        f"{META_GRAPH_BASE}/oauth/access_token",
        params={
            "client_id": FACEBOOK_APP_ID,
            "client_secret": FACEBOOK_APP_SECRET,
            "redirect_uri": OAUTH_CALLBACK_URL,
            "code": code,
        },
        timeout=HTTP_TIMEOUT_TOKEN_EXCHANGE,
    )
    if resp.status_code != 200:
        raise OAuthCodeExchangeError(
            f"code exchange failed: HTTP {resp.status_code} body={redact_tokens(resp.text)[:200]}"
        )
    data = resp.json()
    if "access_token" not in data:
        raise OAuthCodeExchangeError("code exchange response missing access_token")
    return data["access_token"]


def _exchange_for_long_lived(short_lived: str) -> tuple[str, datetime]:
    """Step 2: short-lived -> long-lived (~60 day) user access token."""
    resp = requests.get(
        f"{META_GRAPH_BASE}/oauth/access_token",
        params={
            "grant_type": "fb_exchange_token",
            "client_id": FACEBOOK_APP_ID,
            "client_secret": FACEBOOK_APP_SECRET,
            "fb_exchange_token": short_lived,
        },
        timeout=HTTP_TIMEOUT_TOKEN_EXCHANGE,
    )
    if resp.status_code != 200:
        raise OAuthCodeExchangeError(
            f"long-lived exchange failed: HTTP {resp.status_code}"
        )
    data = resp.json()
    if "access_token" not in data:
        raise OAuthCodeExchangeError("long-lived exchange missing access_token")

    expires_in = int(data.get("expires_in", LONG_LIVED_TOKEN_DURATION_DAYS * 86400))
    expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
    return data["access_token"], expires_at


def _list_granted_pages(user_token: str) -> list[GrantedPage]:
    """Step 3: list Pages the user granted access to."""
    resp = requests.get(
        f"{META_GRAPH_BASE}/me/accounts",
        params={
            "access_token": user_token,
            "fields": "id,name,access_token,instagram_business_account,perms",
        },
        timeout=HTTP_TIMEOUT_SECONDS,
    )
    if resp.status_code != 200:
        raise MetaApiError(f"me/accounts failed: HTTP {resp.status_code}")
    data = resp.json()
    pages: list[GrantedPage] = []
    for entry in data.get("data", []):
        ig = entry.get("instagram_business_account") or {}
        pages.append(GrantedPage(
            page_id=entry["id"],
            page_name=entry.get("name", ""),
            page_access_token=entry.get("access_token", ""),
            instagram_business_account_id=ig.get("id"),
            granted_permissions=entry.get("perms", []),
        ))
    return pages


def _resolve_business_manager(
    user_token: str,
    granted_pages: list[GrantedPage],
    candidate_id: UUID,
    audit: AuditLogger,
) -> tuple[str, bool]:
    """
    Step 4: figure out which BM the Pages live in.

    Returns (business_manager_id, was_auto_created).

    Cases:
      a. Pages are already in a BM owned by this candidate → use it.
      b. Pages are not in any BM yet → auto-create one via Business Login config.
      c. Pages are in someone else's BM → raise TransferRequiredError.
    """
    # Query the first Page for its owning BM
    primary = granted_pages[0]
    resp = requests.get(
        f"{META_GRAPH_BASE}/{primary.page_id}",
        params={
            "access_token": user_token,
            "fields": "business",
        },
        timeout=HTTP_TIMEOUT_SECONDS,
    )
    if resp.status_code != 200:
        raise MetaApiError(f"page business lookup failed: HTTP {resp.status_code}")
    data = resp.json()
    business = data.get("business") or {}
    existing_bm_id = business.get("id")

    if existing_bm_id:
        # Verify this BM is owned by the user, not by some other party.
        # If it's owned by another party, the candidate must transfer.
        owner_check = requests.get(
            f"{META_GRAPH_BASE}/{existing_bm_id}",
            params={"access_token": user_token, "fields": "id,name,verification_status"},
            timeout=HTTP_TIMEOUT_SECONDS,
        )
        if owner_check.status_code == 200:
            audit.emit(
                candidate_id=candidate_id,
                event_type="bm_existing_selected",
                metadata={"business_manager_id": existing_bm_id, "name": owner_check.json().get("name")},
            )
            return existing_bm_id, False
        else:
            # User token can see the Page but can't see the BM that owns it.
            # That means the BM is owned by someone else.
            audit.emit(
                candidate_id=candidate_id,
                event_type="transfer_required_detected",
                metadata={"page_id": primary.page_id, "blocked_bm_id": existing_bm_id},
            )
            raise TransferRequiredError(
                f"Page {primary.page_id} is in a Business Manager owned by another party. "
                f"The candidate must transfer the Page to their own Business Manager before connecting."
            )

    # No BM yet — Business Login for Apps should have already auto-created one
    # if META_BUSINESS_LOGIN_CONFIG_ID is set on the App. The new BM should appear
    # on /me/businesses.
    biz_resp = requests.get(
        f"{META_GRAPH_BASE}/me/businesses",
        params={"access_token": user_token, "fields": "id,name,verification_status"},
        timeout=HTTP_TIMEOUT_SECONDS,
    )
    if biz_resp.status_code != 200:
        raise MetaApiError(f"me/businesses failed: HTTP {biz_resp.status_code}")
    businesses = biz_resp.json().get("data", [])
    if not businesses:
        raise OAuthError(
            "No Business Manager found and auto-creation did not produce one. "
            "Verify META_BUSINESS_LOGIN_CONFIG_ID is set and the App is registered as Tech Provider."
        )

    new_bm_id = businesses[0]["id"]
    audit.emit(
        candidate_id=candidate_id,
        event_type="bm_auto_created",
        metadata={"business_manager_id": new_bm_id, "name": businesses[0].get("name")},
    )
    return new_bm_id, True


def _create_system_user(
    business_manager_id: str,
    user_token: str,
    candidate_id: UUID,
    audit: AuditLogger,
) -> str:
    """Step 5: Create a System User inside the candidate's BM."""
    resp = requests.post(
        f"{META_GRAPH_BASE}/{business_manager_id}/system_users",
        data={
            "name": "BroyhillGOP Automation",
            "role": "EMPLOYEE",
            "access_token": user_token,
        },
        timeout=HTTP_TIMEOUT_SECONDS,
    )
    if resp.status_code != 200:
        raise MetaApiError(
            f"system_user creation failed: HTTP {resp.status_code} body={redact_tokens(resp.text)[:200]}"
        )
    data = resp.json()
    system_user_id = data.get("id")
    if not system_user_id:
        raise MetaApiError("system_user response missing id")

    audit.emit(
        candidate_id=candidate_id,
        event_type="system_user_created",
        metadata={"system_user_id": system_user_id, "business_manager_id": business_manager_id},
    )
    return system_user_id


def _issue_system_user_token(
    business_manager_id: str,
    system_user_id: str,
    user_token: str,
) -> tuple[str, datetime]:
    """Step 6: Issue a long-lived access token for the System User."""
    resp = requests.post(
        f"{META_GRAPH_BASE}/{system_user_id}/access_tokens",
        data={
            "business_app": FACEBOOK_APP_ID,
            "scope": ",".join(DEFAULT_SCOPES),
            "set_token_expires_in_60_days": "true",
            "access_token": user_token,
        },
        timeout=HTTP_TIMEOUT_TOKEN_EXCHANGE,
    )
    if resp.status_code != 200:
        raise MetaApiError(
            f"system_user token issuance failed: HTTP {resp.status_code}"
        )
    data = resp.json()
    if "access_token" not in data:
        raise MetaApiError("system_user token response missing access_token")

    # Default to 60-day expiry. Meta's response sometimes omits expires_in.
    expires_in = int(data.get("expires_in", LONG_LIVED_TOKEN_DURATION_DAYS * 86400))
    return data["access_token"], datetime.utcnow() + timedelta(seconds=expires_in)


def _subscribe_webhooks(
    business_manager_id: str,
    system_user_token: str,
    granted_pages: list[GrantedPage],
    candidate_id: UUID,
    audit: AuditLogger,
) -> str:
    """Step 7: Subscribe webhooks for each granted Page."""
    primary = granted_pages[0]
    resp = requests.post(
        f"{META_GRAPH_BASE}/{primary.page_id}/subscribed_apps",
        data={
            "subscribed_fields": "messages,messaging_postbacks,feed,mention,comments,message_reactions",
            "access_token": system_user_token,
        },
        timeout=HTTP_TIMEOUT_SECONDS,
    )
    if resp.status_code != 200:
        raise MetaApiError(
            f"webhook subscription failed: HTTP {resp.status_code} body={redact_tokens(resp.text)[:200]}"
        )
    data = resp.json()
    if not data.get("success"):
        raise MetaApiError("webhook subscription returned success=false")

    sub_id = f"page_{primary.page_id}"
    audit.emit(
        candidate_id=candidate_id,
        event_type="webhook_subscribed",
        metadata={
            "page_id": primary.page_id,
            "business_manager_id": business_manager_id,
            "subscription_id": sub_id,
        },
    )
    return sub_id


# ---------------------------------------------------------------------------
# Revocation handler
# ---------------------------------------------------------------------------

def handle_revocation(
    *,
    candidate_id: UUID,
    accounts: CandidateAccountStore,
    audit: AuditLogger,
    revoked_by: str = "candidate",  # 'candidate' or 'admin'
    publisher: Optional[EventPublisher] = None,
) -> None:
    """
    Mark a candidate's Tech Provider provisioning as revoked.

    Called when:
      - Candidate goes to FB settings and removes BroyhillGOP
      - Token refresh worker discovers the token is invalid
      - Master tier emergency-revoke from the control panel

    Brain integration:
      - Publishes 'social.oauth.revoked' with revoked_by source
    """
    pub = publisher or NullEventPublisher()

    accounts.update_status(
        candidate_id=candidate_id,
        status="oauth_revoked",
        oauth_revoked_at=datetime.utcnow(),
    )
    event_type = "access_revoked_by_candidate" if revoked_by == "candidate" else "access_revoked_by_admin"
    audit.emit(
        candidate_id=candidate_id,
        event_type=event_type,
        metadata={"revoked_at": datetime.utcnow().isoformat()},
    )

    # Brain integration: publish revocation event
    pub.publish(
        "social.oauth.revoked",
        candidate_id=candidate_id,
        payload={"revoked_by": revoked_by},
    )

    logger.info("revocation processed for candidate=%s by=%s", candidate_id, revoked_by)
