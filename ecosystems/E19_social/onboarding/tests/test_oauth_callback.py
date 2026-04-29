"""
ecosystems/E19_social/onboarding/tests/test_oauth_callback.py

Tests for ecosystems/E19_social/onboarding/business_login_handler.py.

Uses fakes for CandidateAccountStore, AuditLogger, and Meta API responses.
No network calls. No database calls.

Run with: pytest ecosystems/E19_social/onboarding/tests/test_oauth_callback.py
"""

from __future__ import annotations

import base64
import os
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
from uuid import uuid4

import pytest

from shared.security.token_vault import reload_keys


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _setup_env(monkeypatch):
    """Stand up minimal env for the handler module."""
    monkeypatch.setenv("FACEBOOK_APP_ID", "test_app_id")
    monkeypatch.setenv("FACEBOOK_APP_SECRET", "test_app_secret")
    monkeypatch.setenv("META_BUSINESS_LOGIN_CONFIG_ID", "test_config_id")
    monkeypatch.setenv(
        "META_OAUTH_CALLBACK_URL",
        "https://api.broyhillgop.org/v1/webhooks/meta/oauth_callback",
    )
    # Token vault key
    monkeypatch.setenv(
        "META_TOKEN_KEY_v1",
        base64.b64encode(os.urandom(32)).decode("ascii"),
    )
    monkeypatch.setenv("META_TOKEN_ACTIVE_KEY_ID", "v1")
    reload_keys()
    yield
    reload_keys()


@pytest.fixture
def fake_audit():
    audit = MagicMock()
    audit.events = []
    def emit(**kwargs):
        audit.events.append(kwargs)
    audit.emit.side_effect = emit
    return audit


@pytest.fixture
def fake_accounts():
    """In-memory CandidateAccountStore."""
    store = MagicMock()
    store.rows = {}

    def get_status(candidate_id):
        return store.rows.get(candidate_id, {}).get("bm_provisioning_status")

    def upsert_provisioning(**kwargs):
        store.rows[kwargs["candidate_id"]] = kwargs

    def update_status(candidate_id, status, oauth_revoked_at=None):
        if candidate_id in store.rows:
            store.rows[candidate_id]["bm_provisioning_status"] = status
            if oauth_revoked_at:
                store.rows[candidate_id]["oauth_revoked_at"] = oauth_revoked_at

    store.get_status.side_effect = get_status
    store.upsert_provisioning.side_effect = upsert_provisioning
    store.update_status.side_effect = update_status
    return store


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mock_response(json_data, status_code=200, text=None):
    resp = MagicMock()
    resp.status_code = status_code
    resp.json.return_value = json_data
    resp.text = text or str(json_data)
    return resp


# ---------------------------------------------------------------------------
# Initiation
# ---------------------------------------------------------------------------

class TestInitiateOAuth:
    def test_returns_authorize_url_with_required_params(self, fake_audit):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        candidate_id = uuid4()
        result = h.initiate_oauth(candidate_id, audit=fake_audit)
        assert result.state_token
        assert "client_id=test_app_id" in result.authorize_url
        assert "redirect_uri=" in result.authorize_url
        assert "config_id=test_config_id" in result.authorize_url
        assert "pages_messaging" in result.authorize_url
        # Audit emitted
        assert fake_audit.events[-1]["event_type"] == "oauth_initiated"

    def test_state_token_is_random_per_call(self, fake_audit):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        candidate_id = uuid4()
        a = h.initiate_oauth(candidate_id, audit=fake_audit)
        b = h.initiate_oauth(candidate_id, audit=fake_audit)
        assert a.state_token != b.state_token

    def test_raises_without_app_id(self, fake_audit, monkeypatch):
        monkeypatch.setenv("FACEBOOK_APP_ID", "")
        # Module-level constant captured at import; reload via direct call instead
        from ecosystems.E19_social.onboarding import business_login_handler as h
        # Force re-read
        h.FACEBOOK_APP_ID = ""
        with pytest.raises(h.OAuthError, match="FACEBOOK_APP_ID"):
            h.initiate_oauth(uuid4(), audit=fake_audit)


# ---------------------------------------------------------------------------
# Callback flow — happy path
# ---------------------------------------------------------------------------

class TestCallbackHappyPath:
    @patch("ecosystems.E19_social.onboarding.business_login_handler.requests")
    def test_full_provisioning_with_existing_bm(
        self, mock_requests, fake_accounts, fake_audit
    ):
        from ecosystems.E19_social.onboarding import business_login_handler as h

        candidate_id = uuid4()
        state = "the_state_token"

        # Sequence of Meta API calls and their mocked responses
        mock_requests.get.side_effect = [
            # Step 1: code exchange
            _mock_response({"access_token": "short_lived_user_tok"}),
            # Step 2: long-lived exchange
            _mock_response({"access_token": "long_lived_user_tok", "expires_in": 5184000}),
            # Step 3: list pages
            _mock_response({"data": [
                {
                    "id": "page_001",
                    "name": "Test Candidate Page",
                    "access_token": "page_tok_001",
                    "instagram_business_account": {"id": "ig_001"},
                    "perms": ["MANAGE", "MESSAGING"],
                }
            ]}),
            # Step 4a: page business lookup -> existing BM
            _mock_response({"business": {"id": "bm_existing_001"}}),
            # Step 4b: BM owner check -> success (user owns the BM)
            _mock_response({"id": "bm_existing_001", "name": "Candidate's BM"}),
        ]
        mock_requests.post.side_effect = [
            # Step 5: create system user
            _mock_response({"id": "system_user_001"}),
            # Step 6: issue system user token
            _mock_response({"access_token": "system_user_tok_001", "expires_in": 5184000}),
            # Step 7: subscribe webhooks
            _mock_response({"success": True}),
        ]
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        result = h.handle_oauth_callback(
            candidate_id=candidate_id,
            code="auth_code_xyz",
            state=state,
            expected_state=state,
            accounts=fake_accounts,
            audit=fake_audit,
        )

        assert result.business_manager_id == "bm_existing_001"
        assert result.system_user_id == "system_user_001"
        assert result.bm_was_auto_created is False
        assert len(result.pages) == 1
        assert result.pages[0].page_id == "page_001"

        # Persisted to store with provisioned status
        stored = fake_accounts.rows[candidate_id]
        assert stored["bm_provisioning_status"] == "provisioned"
        assert stored["business_manager_id"] == "bm_existing_001"
        assert stored["facebook_page_id"] == "page_001"
        assert stored["instagram_business_account_id"] == "ig_001"
        # Token blob is bytes, not plaintext
        assert isinstance(stored["system_user_token_blob"], bytes)
        assert b"system_user_tok_001" not in stored["system_user_token_blob"]

        # Audit trail covers each step
        event_types = [e["event_type"] for e in fake_audit.events]
        assert "oauth_callback_received" in event_types
        assert "pages_granted" in event_types
        assert "bm_existing_selected" in event_types
        assert "system_user_created" in event_types
        assert "token_issued" in event_types
        assert "webhook_subscribed" in event_types


# ---------------------------------------------------------------------------
# State validation
# ---------------------------------------------------------------------------

class TestStateValidation:
    def test_mismatched_state_raises(self, fake_accounts, fake_audit):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        with pytest.raises(h.OAuthError, match="state mismatch"):
            h.handle_oauth_callback(
                candidate_id=uuid4(),
                code="some_code",
                state="actual_state",
                expected_state="different_state",
                accounts=fake_accounts,
                audit=fake_audit,
            )

    def test_missing_state_raises(self, fake_accounts, fake_audit):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        with pytest.raises(h.OAuthError, match="state mismatch"):
            h.handle_oauth_callback(
                candidate_id=uuid4(),
                code="some_code",
                state="",
                expected_state="expected",
                accounts=fake_accounts,
                audit=fake_audit,
            )

    def test_missing_code_raises(self, fake_accounts, fake_audit):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        with pytest.raises(h.OAuthError, match="missing code"):
            h.handle_oauth_callback(
                candidate_id=uuid4(),
                code="",
                state="ok",
                expected_state="ok",
                accounts=fake_accounts,
                audit=fake_audit,
            )


# ---------------------------------------------------------------------------
# Edge case: transfer required
# ---------------------------------------------------------------------------

class TestTransferRequired:
    @patch("ecosystems.E19_social.onboarding.business_login_handler.requests")
    def test_page_in_third_party_bm_raises_transfer_required(
        self, mock_requests, fake_accounts, fake_audit
    ):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        candidate_id = uuid4()

        mock_requests.get.side_effect = [
            _mock_response({"access_token": "short"}),
            _mock_response({"access_token": "long", "expires_in": 5184000}),
            _mock_response({"data": [
                {"id": "page_001", "name": "Page", "access_token": "tok", "perms": []}
            ]}),
            # page business lookup returns a BM
            _mock_response({"business": {"id": "bm_third_party"}}),
            # owner check returns 403 — BM not visible to this user
            _mock_response({}, status_code=403, text="cannot view BM"),
        ]
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        with pytest.raises(h.TransferRequiredError):
            h.handle_oauth_callback(
                candidate_id=candidate_id,
                code="code",
                state="s",
                expected_state="s",
                accounts=fake_accounts,
                audit=fake_audit,
            )

        # Transfer event audited
        assert any(
            e["event_type"] == "transfer_required_detected"
            for e in fake_audit.events
        )
        # No provisioning row written
        assert candidate_id not in fake_accounts.rows


# ---------------------------------------------------------------------------
# Edge case: no Pages granted
# ---------------------------------------------------------------------------

class TestNoPagesGranted:
    @patch("ecosystems.E19_social.onboarding.business_login_handler.requests")
    def test_empty_pages_list_raises(self, mock_requests, fake_accounts, fake_audit):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        mock_requests.get.side_effect = [
            _mock_response({"access_token": "short"}),
            _mock_response({"access_token": "long", "expires_in": 5184000}),
            _mock_response({"data": []}),
        ]
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        with pytest.raises(h.OAuthError, match="no Pages"):
            h.handle_oauth_callback(
                candidate_id=uuid4(),
                code="c",
                state="s",
                expected_state="s",
                accounts=fake_accounts,
                audit=fake_audit,
            )


# ---------------------------------------------------------------------------
# Edge case: code exchange fails
# ---------------------------------------------------------------------------

class TestCodeExchangeFailure:
    @patch("ecosystems.E19_social.onboarding.business_login_handler.requests")
    def test_meta_returns_400_on_code_exchange(
        self, mock_requests, fake_accounts, fake_audit
    ):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        mock_requests.get.side_effect = [
            _mock_response({"error": "invalid"}, status_code=400, text="invalid code"),
        ]
        mock_requests.Timeout = Exception
        mock_requests.RequestException = Exception

        with pytest.raises(h.OAuthCodeExchangeError, match="HTTP 400"):
            h.handle_oauth_callback(
                candidate_id=uuid4(),
                code="bad_code",
                state="s",
                expected_state="s",
                accounts=fake_accounts,
                audit=fake_audit,
            )


# ---------------------------------------------------------------------------
# Revocation
# ---------------------------------------------------------------------------

class TestRevocation:
    def test_handle_revocation_marks_status_and_audits(self, fake_accounts, fake_audit):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        candidate_id = uuid4()
        # Pre-seed a provisioned row
        fake_accounts.rows[candidate_id] = {
            "candidate_id": candidate_id,
            "bm_provisioning_status": "provisioned",
        }

        h.handle_revocation(
            candidate_id=candidate_id,
            accounts=fake_accounts,
            audit=fake_audit,
            revoked_by="candidate",
        )

        assert fake_accounts.rows[candidate_id]["bm_provisioning_status"] == "oauth_revoked"
        assert fake_accounts.rows[candidate_id].get("oauth_revoked_at")
        assert any(
            e["event_type"] == "access_revoked_by_candidate"
            for e in fake_audit.events
        )

    def test_handle_revocation_by_admin_uses_admin_event_type(self, fake_accounts, fake_audit):
        from ecosystems.E19_social.onboarding import business_login_handler as h
        candidate_id = uuid4()
        fake_accounts.rows[candidate_id] = {
            "candidate_id": candidate_id,
            "bm_provisioning_status": "provisioned",
        }

        h.handle_revocation(
            candidate_id=candidate_id,
            accounts=fake_accounts,
            audit=fake_audit,
            revoked_by="admin",
        )

        assert any(
            e["event_type"] == "access_revoked_by_admin"
            for e in fake_audit.events
        )
