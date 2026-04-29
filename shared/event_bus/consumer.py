"""
shared/event_bus/consumer.py

Subscriber base class for consuming events from the BroyhillGOP event bus.

Channel: broyhillgop.events (canonical)
Plus per-pattern channels (e.g. 'intelligence.*' for Brain decisions).

Design:
  - Register handlers keyed by event_type (or wildcard pattern)
  - Connect to Redis pub/sub, listen
  - Dispatch each message to all matching handlers
  - Idempotency: handlers receive event_id and should dedup
  - Resilient: handler exceptions don't crash the consumer

Phase: Step 5b. Dry-run only.
"""

from __future__ import annotations

import json
import logging
import threading
from dataclasses import dataclass
from typing import Any, Callable, Optional, Protocol


logger = logging.getLogger("shared.event_bus.consumer")


CANONICAL_CHANNEL = "broyhillgop.events"


# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

EventHandler = Callable[[dict[str, Any]], None]
"""Handler signature: takes the parsed event dict, returns None.

The dict contains the canonical fields:
    event_id, event_type, ecosystem, candidate_id, timestamp
plus whatever payload fields were on the event.
"""


class RedisPubSubClient(Protocol):
    """Subset of redis.Redis().pubsub() we depend on."""

    def subscribe(self, *channels: str) -> None: ...
    def listen(self) -> Any: ...
    def close(self) -> None: ...


# ---------------------------------------------------------------------------
# Pattern matching
# ---------------------------------------------------------------------------

def _matches_pattern(event_type: str, pattern: str) -> bool:
    """
    Match an event_type against a pattern. Supports trailing '*' wildcard.
    Examples:
        intelligence.*  matches  intelligence.candidate.connect_required
        social.oauth.completed  matches  social.oauth.completed
        *  matches  anything
    """
    if pattern == "*":
        return True
    if pattern.endswith(".*"):
        prefix = pattern[:-2]
        return event_type == prefix or event_type.startswith(prefix + ".")
    if pattern.endswith("*"):
        return event_type.startswith(pattern[:-1])
    return event_type == pattern


# ---------------------------------------------------------------------------
# Consumer
# ---------------------------------------------------------------------------

class EventConsumer:
    """
    Subscribes to the BroyhillGOP event bus and routes messages to handlers.

    Usage:
        consumer = EventConsumer(pubsub=redis.pubsub())
        consumer.on('intelligence.automation.pause', handle_pause)
        consumer.on('intelligence.automation.resume', handle_resume)
        consumer.on('intelligence.token.force_refresh', handle_force_refresh)
        consumer.start()  # blocks until stop() called
    """

    def __init__(
        self,
        *,
        pubsub: RedisPubSubClient,
        channel: str = CANONICAL_CHANNEL,
        consumer_name: str = "consumer",
    ):
        self._pubsub = pubsub
        self._channel = channel
        self._consumer_name = consumer_name
        self._handlers: list[tuple[str, EventHandler]] = []
        self._seen_event_ids: set[str] = set()       # Simple in-memory dedup; bounded
        self._seen_event_ids_max = 10000
        self._running = False
        self._lock = threading.Lock()

    def on(self, pattern: str, handler: EventHandler) -> None:
        """Register a handler for events matching pattern. Patterns support trailing *."""
        if not pattern:
            raise ValueError("pattern is required")
        if not callable(handler):
            raise TypeError("handler must be callable")
        with self._lock:
            self._handlers.append((pattern, handler))
        logger.debug("%s: registered handler for pattern '%s'", self._consumer_name, pattern)

    def start(self) -> None:
        """Subscribe and dispatch messages. Blocks until stop()."""
        if self._running:
            raise RuntimeError("consumer already running")
        self._running = True
        try:
            self._pubsub.subscribe(self._channel)
            logger.info("%s: subscribed to channel '%s'", self._consumer_name, self._channel)
            for message in self._pubsub.listen():
                if not self._running:
                    break
                self._handle_raw_message(message)
        finally:
            self._running = False
            try:
                self._pubsub.close()
            except Exception:
                pass

    def stop(self) -> None:
        self._running = False

    def dispatch(self, event: dict[str, Any]) -> None:
        """
        Dispatch a single parsed event to all matching handlers. Public so tests
        and replay workers can drive it directly without Redis.
        """
        event_id = event.get("event_id")
        event_type = event.get("event_type")
        if not event_type:
            logger.warning("%s: event missing event_type, skipping: %s",
                           self._consumer_name, event)
            return

        # Dedup on event_id
        if event_id:
            if event_id in self._seen_event_ids:
                logger.debug("%s: skipping duplicate event_id=%s", self._consumer_name, event_id)
                return
            self._seen_event_ids.add(event_id)
            # Bound memory: simple FIFO truncation
            if len(self._seen_event_ids) > self._seen_event_ids_max:
                # Drop arbitrary half — exact LRU not worth the cost here
                excess = len(self._seen_event_ids) - self._seen_event_ids_max // 2
                for _ in range(excess):
                    self._seen_event_ids.pop()

        # Find matching handlers
        with self._lock:
            handlers = [(pat, h) for pat, h in self._handlers if _matches_pattern(event_type, pat)]

        if not handlers:
            logger.debug("%s: no handlers for event_type=%s", self._consumer_name, event_type)
            return

        for pattern, handler in handlers:
            try:
                handler(event)
            except Exception:
                # Log and continue — one handler's failure must not crash the consumer
                logger.exception(
                    "%s: handler for pattern '%s' raised on event_type=%s event_id=%s",
                    self._consumer_name, pattern, event_type, event_id,
                )

    def _handle_raw_message(self, message: Any) -> None:
        """Parse and dispatch a Redis pubsub message dict."""
        if not isinstance(message, dict):
            return
        if message.get("type") != "message":
            return
        raw = message.get("data")
        if not raw:
            return
        try:
            event = json.loads(raw)
        except (ValueError, TypeError) as exc:
            logger.warning("%s: bad JSON on event bus: %s", self._consumer_name, exc)
            return
        if not isinstance(event, dict):
            logger.warning("%s: event payload not a dict: %s", self._consumer_name, type(event))
            return
        self.dispatch(event)


__all__ = [
    "EventConsumer",
    "EventHandler",
    "RedisPubSubClient",
    "CANONICAL_CHANNEL",
]
