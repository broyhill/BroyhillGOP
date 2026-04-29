"""
ecosystems/E19_social/onboarding/webhook_subscription_manager.py

Manages the lifecycle of Meta webhook subscriptions per candidate.

Subscription is created at provisioning time by business_login_handler.
This module handles:
  - Verifying a subscription is still active (health check)
  - Re-subscribing if Meta auto-disabled it (happens after 7 days of webhook failures)
  - Unsubscribing on candidate revocation
  - Bulk re-subscription after platform outage recovery

The webhook endpoint itself (the HTTP handler that receives Meta's POSTs)
lives in ecosystems/E19_social/dm/webhook_handler.py and is not part of this file.
This file only manages the subscription lifecycle on Meta's side.

Phase: Step 5 of 8. Dry-run only.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from datetime import datetime
from typing import Optional
from uuid import UUID

import requests

from shared.security.token_vault import (
    decrypt_token,
    redact_tokens,
)
from shared.event_bus import EventPublisher, NullEventPublisher
from shared.brain_control.governance import (
    CostAccountant,
    NullCostAccountant,
    FunctionCallRecord,
)


logger = logging.getLogger("e19_social.onboarding.webhook_subscription_manager")


META_GRAPH_VERSION = os.environ.get("META_GRAPH_API_VERSION", "v19.0")
META_GRAPH_BASE = f"https://graph.facebook.com/{META_GRAPH_VERSION}"
HTTP_TIMEOUT = 30

# Fields we subscribe to. Must match what we want to receive in webhooks.
DEFAULT_SUBSCRIBED_FIELDS = [
    "messages",
    "messaging_postbacks",
    "messaging_optins",
    "feed",
    "mention",
    "comments",
    "message_reactions",
    "messaging_referrals",
]


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

class SubscriptionError(Exception):
    pass


class SubscriptionDisabledByMeta(SubscriptionError):
    """Meta has disabled this subscription. Re-subscribe required."""


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class SubscriptionStatus:
    page_id: str
    is_active: bool
    subscribed_fields: list[str]
    last_checked_at: datetime


# ---------------------------------------------------------------------------
# Persistence interface
# ---------------------------------------------------------------------------

class SubscriptionStore:
    """Persistence for webhook subscription state. Concrete impl wraps psycopg2."""

    def read_token_for_candidate(self, candidate_id: UUID) -> tuple[bytes, str, str]:
        """Return (encrypted_token_blob, key_id, page_id)."""
        raise NotImplementedError

    def write_subscription_id(
        self, candidate_id: UUID, subscription_id: str
    ) -> None:
        raise NotImplementedError

    def clear_subscription_id(self, candidate_id: UUID) -> None:
        raise NotImplementedError


class AuditLogger:
    def emit(
        self, *, candidate_id: UUID, event_type: str, metadata: Optional[dict] = None
    ) -> None:
        raise NotImplementedError


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def check_subscription(
    candidate_id: UUID, store: SubscriptionStore
) -> SubscriptionStatus:
    """Query Meta to confirm the candidate's webhook subscription is active."""
    blob, key_id, page_id = store.read_token_for_candidate(candidate_id)
    token = decrypt_token(blob, key_id)

    resp = requests.get(
        f"{META_GRAPH_BASE}/{page_id}/subscribed_apps",
        params={"access_token": token},
        timeout=HTTP_TIMEOUT,
    )
    if resp.status_code != 200:
        raise SubscriptionError(
            f"subscription check failed: HTTP {resp.status_code} body={redact_tokens(resp.text)[:200]}"
        )

    data = resp.json().get("data", [])
    is_active = False
    subscribed_fields: list[str] = []
    for entry in data:
        if entry.get("id") == os.environ.get("FACEBOOK_APP_ID", ""):
            is_active = True
            subscribed_fields = entry.get("subscribed_fields", []) or []
            break

    return SubscriptionStatus(
        page_id=page_id,
        is_active=is_active,
        subscribed_fields=subscribed_fields,
        last_checked_at=datetime.utcnow(),
    )


def resubscribe(
    candidate_id: UUID,
    store: SubscriptionStore,
    audit: AuditLogger,
    fields: Optional[list[str]] = None,
) -> str:
    """Re-subscribe a candidate's Page after Meta disabled the subscription."""
    blob, key_id, page_id = store.read_token_for_candidate(candidate_id)
    token = decrypt_token(blob, key_id)

    fields_to_subscribe = fields or DEFAULT_SUBSCRIBED_FIELDS

    resp = requests.post(
        f"{META_GRAPH_BASE}/{page_id}/subscribed_apps",
        data={
            "subscribed_fields": ",".join(fields_to_subscribe),
            "access_token": token,
        },
        timeout=HTTP_TIMEOUT,
    )
    if resp.status_code != 200:
        raise SubscriptionError(
            f"resubscribe failed: HTTP {resp.status_code} body={redact_tokens(resp.text)[:200]}"
        )
    if not resp.json().get("success"):
        raise SubscriptionError("resubscribe returned success=false")

    sub_id = f"page_{page_id}"
    store.write_subscription_id(candidate_id, sub_id)
    audit.emit(
        candidate_id=candidate_id,
        event_type="webhook_subscribed",
        metadata={
            "page_id": page_id,
            "subscription_id": sub_id,
            "subscribed_fields": fields_to_subscribe,
            "context": "resubscribe",
        },
    )
    return sub_id


def unsubscribe(
    candidate_id: UUID, store: SubscriptionStore, audit: AuditLogger
) -> None:
    """Unsubscribe webhook on candidate revocation or removal."""
    blob, key_id, page_id = store.read_token_for_candidate(candidate_id)
    token = decrypt_token(blob, key_id)

    resp = requests.delete(
        f"{META_GRAPH_BASE}/{page_id}/subscribed_apps",
        params={"access_token": token},
        timeout=HTTP_TIMEOUT,
    )
    # If the token is already invalid we get 4xx; treat that as "already unsubscribed"
    if resp.status_code not in (200, 400, 401, 403):
        raise SubscriptionError(f"unsubscribe failed: HTTP {resp.status_code}")

    store.clear_subscription_id(candidate_id)
    audit.emit(
        candidate_id=candidate_id,
        event_type="webhook_unsubscribed",
        metadata={"page_id": page_id},
    )
    logger.info("unsubscribed candidate=%s page=%s", candidate_id, page_id)


def handle_meta_disabled_notification(
    candidate_id: UUID,
    store: SubscriptionStore,
    audit: AuditLogger,
    publisher: Optional[EventPublisher] = None,
) -> None:
    """
    Called when Meta tells us a subscription was auto-disabled
    (typically after 7 days of failed webhook deliveries).
    Logs the event; staff may re-enable manually after fixing the endpoint.

    Brain integration:
      - Publishes 'social.webhook.subscription_disabled' so Brain can decide
        whether to attempt resubscription, alert staff, or trigger reconnect.
    """
    pub = publisher or NullEventPublisher()

    audit.emit(
        candidate_id=candidate_id,
        event_type="webhook_disabled_by_meta",
        metadata={"detected_at": datetime.utcnow().isoformat()},
    )
    pub.publish(
        "social.webhook.subscription_disabled",
        candidate_id=candidate_id,
        payload={"detected_at": datetime.utcnow().isoformat()},
    )
    logger.warning("Meta disabled webhook for candidate=%s", candidate_id)
