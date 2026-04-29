"""
ecosystems/E19_social/onboarding/tests/test_brain_consumer.py

Tests for ecosystems/E19_social/onboarding/brain_consumer.py.

Verifies that intelligence.* events from the Brain dispatch to the right
TechProviderActionHandler methods with the right arguments.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from shared.event_bus import EventConsumer
from ecosystems.E19_social.onboarding.brain_consumer import (
    TechProviderBrainConsumer,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def consumer():
    pubsub = MagicMock()
    return EventConsumer(pubsub=pubsub, consumer_name="test_brain_consumer")


@pytest.fixture
def handler():
    """MagicMock handler — checks methods are called with the right args."""
    return MagicMock()


@pytest.fixture
def wired(consumer, handler):
    wiring = TechProviderBrainConsumer(consumer=consumer, handler=handler)
    wiring.attach_handlers()
    return consumer, handler


# ---------------------------------------------------------------------------
# intelligence.candidate.connect_required
# ---------------------------------------------------------------------------

class TestConnectRequired:
    def test_dispatches_send_oauth_invite_with_default_channel(self, wired):
        consumer, handler = wired
        cid = uuid4()
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.candidate.connect_required",
            "candidate_id": str(cid),
            "reason": "new_candidate_registered",
        })
        handler.send_oauth_invite.assert_called_once()
        args, kwargs = handler.send_oauth_invite.call_args
        # First positional arg is candidate UUID
        assert args[0] == cid
        assert kwargs["channel"] == "sms"
        assert kwargs["reason"] == "new_candidate_registered"

    def test_email_channel_respected(self, wired):
        consumer, handler = wired
        cid = uuid4()
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.candidate.connect_required",
            "candidate_id": str(cid),
            "channel": "email",
        })
        handler.send_oauth_invite.assert_called_once()
        assert handler.send_oauth_invite.call_args.kwargs["channel"] == "email"

    def test_unknown_channel_defaults_to_sms(self, wired):
        consumer, handler = wired
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.candidate.connect_required",
            "candidate_id": str(uuid4()),
            "channel": "carrier_pigeon",
        })
        handler.send_oauth_invite.assert_called_once()
        assert handler.send_oauth_invite.call_args.kwargs["channel"] == "sms"

    def test_missing_candidate_id_skipped(self, wired):
        consumer, handler = wired
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.candidate.connect_required",
            # No candidate_id
        })
        handler.send_oauth_invite.assert_not_called()

    def test_invalid_uuid_skipped(self, wired):
        consumer, handler = wired
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.candidate.connect_required",
            "candidate_id": "not-a-uuid",
        })
        handler.send_oauth_invite.assert_not_called()


# ---------------------------------------------------------------------------
# intelligence.automation.pause
# ---------------------------------------------------------------------------

class TestPause:
    def test_per_candidate_pause(self, wired):
        consumer, handler = wired
        cid = uuid4()
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.automation.pause",
            "candidate_id": str(cid),
            "reason": "donor_complaint",
        })
        handler.pause_automation.assert_called_once()
        args, kwargs = handler.pause_automation.call_args
        assert args[0] == cid
        assert kwargs["reason"] == "donor_complaint"

    def test_app_wide_pause_passes_none_candidate(self, wired):
        consumer, handler = wired
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.automation.pause",
            "candidate_id": None,
            "reason": "rate_limit_event",
        })
        handler.pause_automation.assert_called_once()
        args, kwargs = handler.pause_automation.call_args
        assert args[0] is None

    def test_expires_at_parsed(self, wired):
        consumer, handler = wired
        future = datetime(2099, 12, 31, 12, 0, 0).isoformat()
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.automation.pause",
            "candidate_id": str(uuid4()),
            "expires_at": future,
        })
        handler.pause_automation.assert_called_once()
        kwargs = handler.pause_automation.call_args.kwargs
        assert kwargs["expires_at"] == datetime(2099, 12, 31, 12, 0, 0)


# ---------------------------------------------------------------------------
# intelligence.automation.resume
# ---------------------------------------------------------------------------

class TestResume:
    def test_per_candidate_resume(self, wired):
        consumer, handler = wired
        cid = uuid4()
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.automation.resume",
            "candidate_id": str(cid),
            "reason": "issue_resolved",
        })
        handler.resume_automation.assert_called_once()
        assert handler.resume_automation.call_args.args[0] == cid

    def test_app_wide_resume(self, wired):
        consumer, handler = wired
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.automation.resume",
            "candidate_id": None,
        })
        handler.resume_automation.assert_called_once()
        assert handler.resume_automation.call_args.args[0] is None


# ---------------------------------------------------------------------------
# intelligence.token.force_refresh
# ---------------------------------------------------------------------------

class TestForceRefresh:
    def test_dispatches_with_candidate_id(self, wired):
        consumer, handler = wired
        cid = uuid4()
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.token.force_refresh",
            "candidate_id": str(cid),
            "reason": "scheduled_refresh_skipped",
        })
        handler.enqueue_force_refresh.assert_called_once()
        assert handler.enqueue_force_refresh.call_args.args[0] == cid

    def test_app_wide_force_refresh_skipped(self, wired):
        consumer, handler = wired
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "intelligence.token.force_refresh",
            "candidate_id": None,
        })
        # No-op: force_refresh requires a candidate_id
        handler.enqueue_force_refresh.assert_not_called()


# ---------------------------------------------------------------------------
# Cross-cutting: events not destined for Tech Provider are ignored
# ---------------------------------------------------------------------------

class TestUnrelatedEvents:
    def test_social_oauth_completed_not_dispatched(self, wired):
        consumer, handler = wired
        # social.* is not in our subscription list
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "social.oauth.completed",
            "candidate_id": str(uuid4()),
        })
        handler.send_oauth_invite.assert_not_called()
        handler.pause_automation.assert_not_called()
        handler.resume_automation.assert_not_called()
        handler.enqueue_force_refresh.assert_not_called()

    def test_news_events_not_dispatched(self, wired):
        consumer, handler = wired
        consumer.dispatch({
            "event_id": str(uuid4()),
            "event_type": "news.crisis_detected",
        })
        # No Tech Provider handler should fire
        handler.send_oauth_invite.assert_not_called()
        handler.pause_automation.assert_not_called()
