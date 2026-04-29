"""
ecosystems/E19_social/onboarding/tests/test_token_refresh.py

Tests for ecosystems/E19_social/onboarding/token_refresh_worker.py.

Run with: pytest ecosystems/E19_social/onboarding/tests/test_token_refresh.py
"""

from __future__ import annotations

import base64
import os
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
from uuid import uuid4

import pytest

from shared.security.token_vault import (
    encrypt_token,
    reload_keys,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _setup_env(monkeypatch):
    monkeypatch.setenv("FACEBOOK_APP_ID", "test_app_id")
    monkeypatch.setenv("FACEBOOK_APP_SECRET", "test_app_secret")
    monkeypatch.setenv(
        "META_TOKEN_KEY_v1",
        base64.b64encode(os.urandom(32)).decode("ascii"),
    )
    monkeypatch.setenv("META_TOKEN_ACTIVE_KEY_ID", "v1")
    reload_keys()
    yield
    reload_keys()


def _make_candidate(days_until_expiry: int = 5):
    from ecosystems.E19_social.onboarding.token_refresh_worker import RefreshCandidate
    return RefreshCandidate(
        candidate_id=uuid4(),
        business_manager_id="bm_test",
        system_user_id="sys_test",
        system_user_token_expires_at=datetime.utcnow() + timedelta(days=days_until_expiry),
        days_until_expiry=days_until_expiry,
    )


def _make_store(candidate, current_token: str = "current_tok"):
    """Return a fake RefreshStore with one candidate seeded."""
    blob, key_id = encrypt_token(current_token)
    store = MagicMock()
    store.list_candidates_needing_refresh.return_value = [candidate]
    store.read_encrypted_token.return_value = (blob, key_id)
    store.consecutive_failure_count.return_value = 0
    store.persisted = []
    store.attempts = []
    store.expired = set()

    def write_refreshed(**kwargs):
        store.persisted.append(kwargs)
    store.write_refreshed_token.side_effect = write_refreshed

    def log(**kwargs):
        store.attempts.append(kwargs)
    store.log_attempt.side_effect = log

    def expire(cid):
        store.expired.add(cid)
    store.mark_expired.side_effect = expire

    return store


def _mock_response(json_data, status_code=200, text=None):
    resp = MagicMock()
    resp.status_code = status_code
    resp.json.return_value = json_data
    resp.text = text or str(json_data)
    return resp


# ---------------------------------------------------------------------------
# Success path
# ---------------------------------------------------------------------------

class TestSuccess:
    @patch("ecosystems.E19_social.onboarding.token_refresh_worker.requests")
    def test_successful_refresh_persists_new_token_and_logs(self, mock_requests):
        from ecosystems.E19_social.onboarding.token_refresh_worker import run_refresh_pass

        candidate = _make_candidate(days_until_expiry=3)
        store = _make_store(candidate)
        mock_requests.post.return_value = _mock_response({
            "access_token": "new_long_lived_tok",
            "expires_in": 5184000,
        })
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        summary = run_refresh_pass(store=store, rate_limit_pause=0)

        assert summary["total"] == 1
        assert summary["succeeded"] == 1
        assert summary["failed"] == 0
        assert summary["expired"] == 0

        # New token persisted
        assert len(store.persisted) == 1
        persisted = store.persisted[0]
        assert persisted["candidate_id"] == candidate.candidate_id
        # Token blob should not contain plaintext
        assert b"new_long_lived_tok" not in persisted["token_blob"]
        # Expiry roughly 60 days out
        delta = persisted["expires_at"] - datetime.utcnow()
        assert delta > timedelta(days=58)

        # Attempt logged with success
        assert len(store.attempts) == 1
        assert store.attempts[0]["outcome"] == "success"


# ---------------------------------------------------------------------------
# Revocation detection
# ---------------------------------------------------------------------------

class TestRevocation:
    @patch("ecosystems.E19_social.onboarding.token_refresh_worker.requests")
    def test_meta_error_190_marks_access_revoked(self, mock_requests):
        from ecosystems.E19_social.onboarding.token_refresh_worker import run_refresh_pass

        candidate = _make_candidate()
        store = _make_store(candidate)
        # 3 prior failures already on record — this one will trip the threshold
        store.consecutive_failure_count.return_value = 3
        mock_requests.post.return_value = _mock_response(
            {"error": {"code": 190, "message": "OAuth token invalid"}},
            status_code=400,
        )
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        summary = run_refresh_pass(store=store, rate_limit_pause=0)

        assert summary["failed"] == 1
        assert summary["expired"] == 1
        assert candidate.candidate_id in store.expired
        assert store.attempts[0]["outcome"] == "access_revoked"
        assert store.attempts[0]["error_code"] == "190"


# ---------------------------------------------------------------------------
# Rate limiting
# ---------------------------------------------------------------------------

class TestRateLimit:
    @patch("ecosystems.E19_social.onboarding.token_refresh_worker.requests")
    def test_429_aborts_pass_early(self, mock_requests):
        from ecosystems.E19_social.onboarding.token_refresh_worker import run_refresh_pass

        candidates = [_make_candidate() for _ in range(5)]
        store = _make_store(candidates[0])
        store.list_candidates_needing_refresh.return_value = candidates

        # Simulate: rate-limited on the first call
        mock_requests.post.return_value = _mock_response({}, status_code=429)
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        summary = run_refresh_pass(store=store, rate_limit_pause=0)

        # Only 1 candidate processed before abort
        assert summary["rate_limited"] == 1
        assert summary["succeeded"] == 0
        # No expirations triggered
        assert summary["expired"] == 0


# ---------------------------------------------------------------------------
# Network errors
# ---------------------------------------------------------------------------

class TestNetworkErrors:
    @patch("ecosystems.E19_social.onboarding.token_refresh_worker.requests")
    def test_timeout_logged_as_network_error(self, mock_requests):
        from ecosystems.E19_social.onboarding.token_refresh_worker import run_refresh_pass
        import requests as real_requests

        candidate = _make_candidate()
        store = _make_store(candidate)
        mock_requests.Timeout = real_requests.Timeout
        mock_requests.RequestException = real_requests.RequestException
        mock_requests.post.side_effect = real_requests.Timeout("timeout")

        summary = run_refresh_pass(store=store, rate_limit_pause=0)

        assert summary["failed"] == 1
        assert store.attempts[0]["outcome"] == "network_error"
        assert store.attempts[0]["error_code"] == "timeout"


# ---------------------------------------------------------------------------
# Persistent failure threshold
# ---------------------------------------------------------------------------

class TestPersistentFailure:
    @patch("ecosystems.E19_social.onboarding.token_refresh_worker.requests")
    def test_threshold_triggers_expiration_and_alert(self, mock_requests):
        from ecosystems.E19_social.onboarding.token_refresh_worker import run_refresh_pass

        candidate = _make_candidate()
        store = _make_store(candidate)
        store.consecutive_failure_count.return_value = 3  # at threshold
        notifier = MagicMock()
        notifier.alerted = []

        def alert(cid, msg):
            notifier.alerted.append((cid, msg))
        notifier.alert_token_expired.side_effect = alert

        mock_requests.post.return_value = _mock_response(
            {"error": {"code": 100, "message": "some error"}}, status_code=400
        )
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        summary = run_refresh_pass(store=store, notifier=notifier, rate_limit_pause=0)

        assert summary["expired"] == 1
        assert candidate.candidate_id in store.expired
        assert len(notifier.alerted) == 1
        assert notifier.alerted[0][0] == candidate.candidate_id

    @patch("ecosystems.E19_social.onboarding.token_refresh_worker.requests")
    def test_below_threshold_does_not_expire(self, mock_requests):
        from ecosystems.E19_social.onboarding.token_refresh_worker import run_refresh_pass

        candidate = _make_candidate()
        store = _make_store(candidate)
        store.consecutive_failure_count.return_value = 1  # below threshold of 3
        mock_requests.post.return_value = _mock_response(
            {"error": {"code": 100}}, status_code=400
        )
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        summary = run_refresh_pass(store=store, rate_limit_pause=0)

        assert summary["failed"] == 1
        assert summary["expired"] == 0
        assert candidate.candidate_id not in store.expired


# ---------------------------------------------------------------------------
# Empty queue
# ---------------------------------------------------------------------------

class TestEmptyQueue:
    def test_no_candidates_no_op(self):
        from ecosystems.E19_social.onboarding.token_refresh_worker import run_refresh_pass
        store = MagicMock()
        store.list_candidates_needing_refresh.return_value = []

        summary = run_refresh_pass(store=store, rate_limit_pause=0)

        assert summary["total"] == 0
        assert summary["succeeded"] == 0
        assert summary["failed"] == 0
        assert store.log_attempt.call_count == 0
