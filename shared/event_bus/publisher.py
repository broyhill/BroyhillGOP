"""
shared/event_bus/publisher.py

Publishes events to the Redis event bus on the canonical broyhillgop.events
channel. When Redis is unavailable, falls back to the meta_event_bus_replay_queue
table so events are never lost.

Canonical event format (matches ecosystem_20_intelligence_brain.py):
    {
        'event_id': str (UUID v4),       # for Brain-side idempotency
        'event_type': str,                # e.g. 'social.oauth.completed'
        'ecosystem': str,                 # 'E19_TECH_PROVIDER' for this app
        'candidate_id': str | None,       # nullable for app-wide events
        'timestamp': str,                 # ISO 8601 UTC
        ... payload fields ...
    }

Channel: 'broyhillgop.events'

Phase: Step 5b in safe-pathway sequence. Dry-run only.
"""

from __future__ import annotations

import json
import logging
import os
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional, Protocol
from uuid import UUID


logger = logging.getLogger("shared.event_bus.publisher")


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CANONICAL_CHANNEL = "broyhillgop.events"
DEFAULT_ECOSYSTEM = "E19_TECH_PROVIDER"
MAX_REPLAY_ATTEMPTS = int(os.environ.get("EVENT_BUS_MAX_REPLAY_ATTEMPTS", "10"))


# ---------------------------------------------------------------------------
# Errors and result types
# ---------------------------------------------------------------------------

class PublishFailure(Exception):
    """Raised when publish fails AND fallback enqueue also fails."""


@dataclass(frozen=True)
class PublishResult:
    event_id: UUID
    event_type: str
    delivered: bool             # True = published to Redis successfully
    fell_back_to_queue: bool    # True = Redis failed but enqueued for replay
    error: Optional[str] = None


# ---------------------------------------------------------------------------
# Helper: build canonical event dict
# ---------------------------------------------------------------------------

def canonical_event(
    *,
    event_type: str,
    ecosystem: str = DEFAULT_ECOSYSTEM,
    candidate_id: Optional[UUID] = None,
    payload: Optional[dict[str, Any]] = None,
    event_id: Optional[UUID] = None,
) -> dict[str, Any]:
    """
    Build a canonical event dict ready to publish or persist.

    Always includes:
      - event_id (auto-generated UUID v4 if not provided)
      - event_type
      - ecosystem
      - candidate_id (or None)
      - timestamp (now, UTC, ISO 8601)

    Plus any payload fields the caller supplies. Payload keys must not
    collide with the reserved keys above.
    """
    if not event_type:
        raise ValueError("event_type is required")

    reserved = {"event_id", "event_type", "ecosystem", "candidate_id", "timestamp"}
    payload = payload or {}
    overlap = reserved & payload.keys()
    if overlap:
        raise ValueError(f"payload may not contain reserved keys: {sorted(overlap)}")

    event = {
        "event_id": str(event_id or uuid.uuid4()),
        "event_type": event_type,
        "ecosystem": ecosystem,
        "candidate_id": str(candidate_id) if candidate_id else None,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    event.update(payload)
    return event


# ---------------------------------------------------------------------------
# Persistence interface for fallback queue
# ---------------------------------------------------------------------------

class ReplayQueueStore(Protocol):
    """Concrete impl writes to public.meta_event_bus_replay_queue."""

    def enqueue(
        self,
        *,
        event_id: UUID,
        event_type: str,
        candidate_id: Optional[UUID],
        event_payload: dict[str, Any],
        last_error: Optional[str] = None,
    ) -> None: ...


# ---------------------------------------------------------------------------
# Redis client interface (minimal — what we actually use)
# ---------------------------------------------------------------------------

class RedisClient(Protocol):
    """Subset of redis.Redis we depend on. Tests substitute a fake."""

    def publish(self, channel: str, message: str) -> int: ...


# ---------------------------------------------------------------------------
# Publisher
# ---------------------------------------------------------------------------

class EventPublisher:
    """
    Publishes events to the BroyhillGOP event bus.

    Behavior:
      1. Build canonical event dict
      2. Attempt Redis publish
      3. If Redis fails, write to replay queue (Postgres)
      4. Return PublishResult describing what happened

    Never raises on Redis failure — only on misconfiguration or replay-queue
    failure. Callers should treat PublishFailure as a deploy-blocking issue.
    """

    def __init__(
        self,
        *,
        redis_client: Optional[RedisClient],
        replay_store: ReplayQueueStore,
        ecosystem: str = DEFAULT_ECOSYSTEM,
        channel: str = CANONICAL_CHANNEL,
    ):
        self._redis = redis_client
        self._replay = replay_store
        self._ecosystem = ecosystem
        self._channel = channel

    @property
    def ecosystem(self) -> str:
        return self._ecosystem

    def publish(
        self,
        event_type: str,
        *,
        candidate_id: Optional[UUID] = None,
        payload: Optional[dict[str, Any]] = None,
        event_id: Optional[UUID] = None,
    ) -> PublishResult:
        """Publish an event. See canonical_event() for the format."""
        event = canonical_event(
            event_type=event_type,
            ecosystem=self._ecosystem,
            candidate_id=candidate_id,
            payload=payload,
            event_id=event_id,
        )
        return self._publish_event(event)

    def _publish_event(self, event: dict[str, Any]) -> PublishResult:
        event_id = UUID(event["event_id"])
        event_type = event["event_type"]
        candidate_id = UUID(event["candidate_id"]) if event["candidate_id"] else None

        # Try Redis first
        if self._redis is not None:
            try:
                payload_str = json.dumps(event)
                self._redis.publish(self._channel, payload_str)
                logger.debug("published event_type=%s event_id=%s", event_type, event_id)
                return PublishResult(
                    event_id=event_id,
                    event_type=event_type,
                    delivered=True,
                    fell_back_to_queue=False,
                )
            except Exception as exc:
                logger.warning(
                    "Redis publish failed for event_type=%s event_id=%s: %s",
                    event_type, event_id, exc,
                )
                redis_error = f"{type(exc).__name__}: {str(exc)[:200]}"
        else:
            redis_error = "redis client is None"

        # Fall back to replay queue
        try:
            self._replay.enqueue(
                event_id=event_id,
                event_type=event_type,
                candidate_id=candidate_id,
                event_payload=event,
                last_error=redis_error,
            )
            logger.info(
                "Enqueued event_type=%s event_id=%s for replay (Redis unavailable)",
                event_type, event_id,
            )
            return PublishResult(
                event_id=event_id,
                event_type=event_type,
                delivered=False,
                fell_back_to_queue=True,
                error=redis_error,
            )
        except Exception as queue_exc:
            # Both Redis and replay queue failed. This is a deploy block.
            logger.exception(
                "BOTH Redis and replay queue failed for event_id=%s — event LOST",
                event_id,
            )
            raise PublishFailure(
                f"event {event_id} not delivered: redis={redis_error}, "
                f"queue={type(queue_exc).__name__}: {queue_exc}"
            ) from queue_exc


# ---------------------------------------------------------------------------
# No-op publisher for tests / when event bus is disabled
# ---------------------------------------------------------------------------

class NullEventPublisher:
    """
    Publisher that drops all events to the floor. Useful for tests, or when
    event bus is intentionally disabled (e.g. local dev without Redis).
    Returns PublishResult with delivered=False, fell_back_to_queue=False.
    """

    ecosystem = "NULL"

    def publish(
        self,
        event_type: str,
        *,
        candidate_id: Optional[UUID] = None,
        payload: Optional[dict[str, Any]] = None,
        event_id: Optional[UUID] = None,
    ) -> PublishResult:
        return PublishResult(
            event_id=event_id or uuid.uuid4(),
            event_type=event_type,
            delivered=False,
            fell_back_to_queue=False,
            error="null publisher (events suppressed)",
        )


__all__ = [
    "EventPublisher",
    "NullEventPublisher",
    "PublishResult",
    "PublishFailure",
    "canonical_event",
    "CANONICAL_CHANNEL",
    "DEFAULT_ECOSYSTEM",
    "ReplayQueueStore",
    "RedisClient",
]
