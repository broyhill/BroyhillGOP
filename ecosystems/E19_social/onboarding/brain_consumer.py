"""
ecosystems/E19_social/onboarding/brain_consumer.py

Subscribes to intelligence.* events from E20 Brain and dispatches them to
Tech Provider handlers.

Brain decisions the Tech Provider listens for:
  - intelligence.candidate.connect_required → Brain decided this candidate
        should be prompted to connect (new candidate, reconnect after revoke).
        Action: send candidate the OAuth initiation URL via configured channel.
  - intelligence.automation.pause → Pause automation for a candidate or app-wide.
        Action: future automation actions check pause flag before running.
  - intelligence.automation.resume → Lift the pause.
  - intelligence.token.force_refresh → Refresh now, don't wait for daily cron.
        Action: enqueue immediate refresh for the named candidate.

Pattern: Uses shared.event_bus.EventConsumer for routing.

Phase: Step 5b. Dry-run only.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Callable, Optional, Protocol
from uuid import UUID

from shared.event_bus import EventConsumer


logger = logging.getLogger("e19_social.onboarding.brain_consumer")


# ---------------------------------------------------------------------------
# Handler interface — concrete impl is wired by app startup code
# ---------------------------------------------------------------------------

class TechProviderActionHandler(Protocol):
    """
    Concrete impl performs the actual side effects when Brain decides things.
    The consumer is just the routing layer; this protocol does the work.
    """

    def send_oauth_invite(
        self, candidate_id: UUID, channel: str, reason: Optional[str] = None
    ) -> None:
        """Send OAuth initiation URL to the candidate via 'sms' or 'email' channel."""
        ...

    def pause_automation(
        self,
        candidate_id: Optional[UUID],   # None = app-wide
        reason: Optional[str] = None,
        expires_at: Optional[datetime] = None,
    ) -> None:
        ...

    def resume_automation(
        self, candidate_id: Optional[UUID], reason: Optional[str] = None
    ) -> None:
        ...

    def enqueue_force_refresh(
        self, candidate_id: UUID, reason: Optional[str] = None
    ) -> None:
        ...


# ---------------------------------------------------------------------------
# Brain consumer for Tech Provider
# ---------------------------------------------------------------------------

class TechProviderBrainConsumer:
    """
    Wires up handlers for the four Brain decision types Tech Provider cares about.

    Usage at app startup:
        consumer = EventConsumer(pubsub=redis.pubsub(), consumer_name='tech_provider_brain')
        wiring = TechProviderBrainConsumer(consumer=consumer, handler=concrete_handler)
        wiring.attach_handlers()
        consumer.start()  # blocks
    """

    def __init__(
        self,
        *,
        consumer: EventConsumer,
        handler: TechProviderActionHandler,
    ):
        self._consumer = consumer
        self._handler = handler

    def attach_handlers(self) -> None:
        """Register handlers with the underlying EventConsumer."""
        self._consumer.on(
            "intelligence.candidate.connect_required",
            self._on_connect_required,
        )
        self._consumer.on(
            "intelligence.automation.pause",
            self._on_pause,
        )
        self._consumer.on(
            "intelligence.automation.resume",
            self._on_resume,
        )
        self._consumer.on(
            "intelligence.token.force_refresh",
            self._on_force_refresh,
        )
        logger.info("TechProviderBrainConsumer: 4 handlers attached")

    # -------- Handlers --------

    def _on_connect_required(self, event: dict[str, Any]) -> None:
        candidate_id = self._candidate_id(event)
        if not candidate_id:
            logger.warning("connect_required event missing candidate_id: event_id=%s",
                           event.get("event_id"))
            return
        channel = event.get("channel", "sms")
        if channel not in ("sms", "email"):
            logger.warning("connect_required event has unknown channel='%s'; defaulting to sms", channel)
            channel = "sms"
        reason = event.get("reason")
        self._handler.send_oauth_invite(candidate_id, channel=channel, reason=reason)
        logger.info(
            "Brain decision applied: send_oauth_invite candidate=%s channel=%s reason=%s",
            candidate_id, channel, reason,
        )

    def _on_pause(self, event: dict[str, Any]) -> None:
        candidate_id = self._candidate_id(event)        # None = app-wide
        reason = event.get("reason")
        expires_at = self._parse_iso(event.get("expires_at"))
        self._handler.pause_automation(candidate_id, reason=reason, expires_at=expires_at)
        logger.info(
            "Brain decision applied: pause %s reason=%s expires=%s",
            "app-wide" if candidate_id is None else f"candidate={candidate_id}",
            reason, expires_at,
        )

    def _on_resume(self, event: dict[str, Any]) -> None:
        candidate_id = self._candidate_id(event)
        reason = event.get("reason")
        self._handler.resume_automation(candidate_id, reason=reason)
        logger.info(
            "Brain decision applied: resume %s reason=%s",
            "app-wide" if candidate_id is None else f"candidate={candidate_id}",
            reason,
        )

    def _on_force_refresh(self, event: dict[str, Any]) -> None:
        candidate_id = self._candidate_id(event)
        if not candidate_id:
            logger.warning("force_refresh event missing candidate_id: event_id=%s",
                           event.get("event_id"))
            return
        reason = event.get("reason")
        self._handler.enqueue_force_refresh(candidate_id, reason=reason)
        logger.info(
            "Brain decision applied: enqueue_force_refresh candidate=%s reason=%s",
            candidate_id, reason,
        )

    # -------- helpers --------

    @staticmethod
    def _candidate_id(event: dict[str, Any]) -> Optional[UUID]:
        raw = event.get("candidate_id")
        if not raw:
            return None
        try:
            return UUID(raw)
        except (ValueError, TypeError) as exc:
            logger.warning("event %s has invalid candidate_id %r: %s",
                           event.get("event_id"), raw, exc)
            return None

    @staticmethod
    def _parse_iso(raw: Any) -> Optional[datetime]:
        if not raw:
            return None
        try:
            return datetime.fromisoformat(raw)
        except (ValueError, TypeError):
            return None


__all__ = [
    "TechProviderBrainConsumer",
    "TechProviderActionHandler",
]
