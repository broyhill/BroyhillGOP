"""
ecosystems/E19_social/onboarding/tests/test_event_bus.py

Tests for shared/event_bus/publisher.py and shared/event_bus/consumer.py.

Run with: pytest ecosystems/E19_social/onboarding/tests/test_event_bus.py
"""

from __future__ import annotations

import json
import uuid
from unittest.mock import MagicMock
from uuid import UUID, uuid4

import pytest

from shared.event_bus import (
    EventPublisher,
    NullEventPublisher,
    EventConsumer,
    PublishFailure,
    canonical_event,
)


# ---------------------------------------------------------------------------
# canonical_event() helper
# ---------------------------------------------------------------------------

class TestCanonicalEvent:
    def test_includes_required_fields(self):
        event = canonical_event(event_type="social.test")
        assert "event_id" in event
        assert UUID(event["event_id"])  # parses
        assert event["event_type"] == "social.test"
        assert event["ecosystem"] == "E19_TECH_PROVIDER"
        assert event["candidate_id"] is None
        assert "timestamp" in event

    def test_candidate_id_serialized_as_string(self):
        cid = uuid4()
        event = canonical_event(event_type="social.test", candidate_id=cid)
        assert event["candidate_id"] == str(cid)

    def test_payload_merged(self):
        event = canonical_event(
            event_type="social.test",
            payload={"foo": 1, "bar": "baz"},
        )
        assert event["foo"] == 1
        assert event["bar"] == "baz"

    def test_payload_cannot_override_reserved_keys(self):
        with pytest.raises(ValueError, match="reserved keys"):
            canonical_event(
                event_type="social.test",
                payload={"event_id": "spoofed"},
            )
        with pytest.raises(ValueError, match="reserved keys"):
            canonical_event(
                event_type="social.test",
                payload={"timestamp": "spoofed"},
            )

    def test_explicit_event_id_used(self):
        eid = uuid4()
        event = canonical_event(event_type="x", event_id=eid)
        assert event["event_id"] == str(eid)

    def test_empty_event_type_rejected(self):
        with pytest.raises(ValueError):
            canonical_event(event_type="")


# ---------------------------------------------------------------------------
# EventPublisher — Redis success path
# ---------------------------------------------------------------------------

class TestPublisherSuccess:
    def test_publishes_to_canonical_channel(self):
        redis_client = MagicMock()
        replay_store = MagicMock()
        pub = EventPublisher(redis_client=redis_client, replay_store=replay_store)

        cid = uuid4()
        result = pub.publish(
            "social.oauth.completed",
            candidate_id=cid,
            payload={"business_manager_id": "bm_123"},
        )

        assert result.delivered is True
        assert result.fell_back_to_queue is False
        # Verify Redis was called on the right channel
        redis_client.publish.assert_called_once()
        channel, message = redis_client.publish.call_args[0]
        assert channel == "broyhillgop.events"
        # Verify message format
        event = json.loads(message)
        assert event["event_type"] == "social.oauth.completed"
        assert event["ecosystem"] == "E19_TECH_PROVIDER"
        assert event["candidate_id"] == str(cid)
        assert event["business_manager_id"] == "bm_123"
        # Replay store should not be touched
        replay_store.enqueue.assert_not_called()


# ---------------------------------------------------------------------------
# EventPublisher — fallback to replay queue
# ---------------------------------------------------------------------------

class TestPublisherFallback:
    def test_redis_failure_falls_back_to_queue(self):
        redis_client = MagicMock()
        redis_client.publish.side_effect = ConnectionError("Redis unreachable")
        replay_store = MagicMock()
        pub = EventPublisher(redis_client=redis_client, replay_store=replay_store)

        result = pub.publish(
            "social.oauth.completed",
            candidate_id=uuid4(),
        )

        assert result.delivered is False
        assert result.fell_back_to_queue is True
        assert "ConnectionError" in (result.error or "")
        replay_store.enqueue.assert_called_once()
        # Verify the enqueued args
        call_kwargs = replay_store.enqueue.call_args.kwargs
        assert call_kwargs["event_type"] == "social.oauth.completed"
        assert isinstance(call_kwargs["event_id"], UUID)
        assert "ConnectionError" in (call_kwargs["last_error"] or "")

    def test_no_redis_client_falls_back_to_queue(self):
        replay_store = MagicMock()
        pub = EventPublisher(redis_client=None, replay_store=replay_store)

        result = pub.publish("social.test", candidate_id=uuid4())

        assert result.delivered is False
        assert result.fell_back_to_queue is True
        replay_store.enqueue.assert_called_once()


class TestPublisherCatastrophicFailure:
    def test_both_redis_and_queue_fail_raises(self):
        redis_client = MagicMock()
        redis_client.publish.side_effect = ConnectionError("Redis down")
        replay_store = MagicMock()
        replay_store.enqueue.side_effect = RuntimeError("DB also down")
        pub = EventPublisher(redis_client=redis_client, replay_store=replay_store)

        with pytest.raises(PublishFailure, match="not delivered"):
            pub.publish("social.test", candidate_id=uuid4())


# ---------------------------------------------------------------------------
# NullEventPublisher
# ---------------------------------------------------------------------------

class TestNullEventPublisher:
    def test_drops_all_events(self):
        pub = NullEventPublisher()
        result = pub.publish("social.test", candidate_id=uuid4())
        assert result.delivered is False
        assert result.fell_back_to_queue is False
        assert "null publisher" in (result.error or "")


# ---------------------------------------------------------------------------
# EventConsumer — handler registration and routing
# ---------------------------------------------------------------------------

class TestConsumerRouting:
    def test_dispatch_routes_exact_match(self):
        pubsub = MagicMock()
        consumer = EventConsumer(pubsub=pubsub, consumer_name="test")
        received = []
        consumer.on("intelligence.automation.pause", lambda e: received.append(e))

        event = {
            "event_id": str(uuid4()),
            "event_type": "intelligence.automation.pause",
            "candidate_id": str(uuid4()),
        }
        consumer.dispatch(event)

        assert len(received) == 1
        assert received[0]["event_type"] == "intelligence.automation.pause"

    def test_dispatch_wildcard_matches(self):
        pubsub = MagicMock()
        consumer = EventConsumer(pubsub=pubsub)
        received = []
        consumer.on("intelligence.*", lambda e: received.append(e["event_type"]))

        consumer.dispatch({
            "event_id": str(uuid4()), "event_type": "intelligence.candidate.connect_required",
        })
        consumer.dispatch({
            "event_id": str(uuid4()), "event_type": "intelligence.token.force_refresh",
        })
        consumer.dispatch({
            "event_id": str(uuid4()), "event_type": "social.oauth.completed",
        })

        assert "intelligence.candidate.connect_required" in received
        assert "intelligence.token.force_refresh" in received
        assert "social.oauth.completed" not in received

    def test_unmatched_event_silently_dropped(self):
        pubsub = MagicMock()
        consumer = EventConsumer(pubsub=pubsub)
        received = []
        consumer.on("intelligence.*", lambda e: received.append(e))

        consumer.dispatch({
            "event_id": str(uuid4()), "event_type": "social.oauth.completed",
        })
        assert len(received) == 0

    def test_handler_exception_does_not_crash_consumer(self):
        pubsub = MagicMock()
        consumer = EventConsumer(pubsub=pubsub)

        good_received = []

        def bad_handler(event):
            raise ValueError("intentional test failure")

        consumer.on("test.*", bad_handler)
        consumer.on("test.*", lambda e: good_received.append(e))

        # Should not raise
        consumer.dispatch({
            "event_id": str(uuid4()), "event_type": "test.event",
        })
        # Good handler still fired
        assert len(good_received) == 1


# ---------------------------------------------------------------------------
# EventConsumer — idempotency
# ---------------------------------------------------------------------------

class TestConsumerIdempotency:
    def test_duplicate_event_id_dispatched_only_once(self):
        pubsub = MagicMock()
        consumer = EventConsumer(pubsub=pubsub)
        received = []
        consumer.on("test.*", lambda e: received.append(e))

        eid = str(uuid4())
        evt = {"event_id": eid, "event_type": "test.event"}
        consumer.dispatch(evt)
        consumer.dispatch(evt)
        consumer.dispatch(evt)

        assert len(received) == 1


# ---------------------------------------------------------------------------
# EventConsumer — bad message handling
# ---------------------------------------------------------------------------

class TestConsumerBadMessages:
    def test_event_without_event_type_skipped(self):
        pubsub = MagicMock()
        consumer = EventConsumer(pubsub=pubsub)
        received = []
        consumer.on("*", lambda e: received.append(e))

        consumer.dispatch({"event_id": str(uuid4())})  # No event_type
        assert len(received) == 0

    def test_invalid_json_in_raw_message_handled(self):
        pubsub = MagicMock()
        consumer = EventConsumer(pubsub=pubsub)
        received = []
        consumer.on("*", lambda e: received.append(e))

        # Simulate a Redis pubsub message with bad JSON
        consumer._handle_raw_message({"type": "message", "data": "not json{{"})
        assert len(received) == 0  # No crash, no dispatch

    def test_subscribe_message_type_ignored(self):
        pubsub = MagicMock()
        consumer = EventConsumer(pubsub=pubsub)
        received = []
        consumer.on("*", lambda e: received.append(e))

        # 'subscribe' messages are administrative, not events
        consumer._handle_raw_message({"type": "subscribe", "data": 1})
        assert len(received) == 0
