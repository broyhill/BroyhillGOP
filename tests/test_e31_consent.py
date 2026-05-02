"""
Unit tests for Section 4: ConsentManager (TCPA/10DLC gate).

These tests use unittest.mock to avoid hitting a real Postgres instance.
They exercise the contract of ConsentManager and the consent gate inside
OmnichannelMessagingEngine.send_message — i.e. that no message goes out
without explicit channel-level opt-in.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# Allow `import ecosystem_31_sms` from repo-relative location
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_31_sms as e31  # noqa: E402


class _FakeCursor:
    """Minimal cursor fake for psycopg2 — captures (sql, params) and replays a queued result."""

    def __init__(self, queued_rows=None):
        self._queued = list(queued_rows or [])
        self.calls = []  # list of (sql, params)

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def execute(self, sql, params=None):
        self.calls.append((sql, params))

    def fetchone(self):
        return self._queued.pop(0) if self._queued else None


class _FakeConn:
    def __init__(self, queued_rows=None):
        self.cursor_arg = None
        self._cursor = _FakeCursor(queued_rows)
        self.committed = False
        self.closed = False

    def cursor(self, cursor_factory=None):
        self.cursor_arg = cursor_factory
        return self._cursor

    def commit(self):
        self.committed = True

    def close(self):
        self.closed = True


class ConsentManagerNormalizationTest(unittest.TestCase):
    def test_normalizes_10_digit_us_phone(self):
        self.assertEqual(e31.ConsentManager._normalize_phone("9195551212"), "+19195551212")

    def test_normalizes_already_e164(self):
        # "+1..." -> strip non-digits -> "1..." 11 digits -> "+1..."
        self.assertEqual(e31.ConsentManager._normalize_phone("+1 (919) 555-1212"), "+19195551212")

    def test_normalizes_with_punctuation(self):
        self.assertEqual(e31.ConsentManager._normalize_phone("(919) 555-1212"), "+19195551212")

    def test_stop_keyword_detected(self):
        self.assertTrue(e31.ConsentManager.is_stop_keyword("STOP"))
        self.assertTrue(e31.ConsentManager.is_stop_keyword("stop please"))
        self.assertTrue(e31.ConsentManager.is_stop_keyword("Unsubscribe"))
        self.assertFalse(e31.ConsentManager.is_stop_keyword("I love your campaign"))
        self.assertFalse(e31.ConsentManager.is_stop_keyword(""))


class ConsentManagerCheckTest(unittest.TestCase):
    def setUp(self):
        self.mgr = e31.ConsentManager(db_url="postgresql://fake")

    def test_check_consent_returns_false_when_no_record(self):
        fake_conn = _FakeConn(queued_rows=[None])
        with patch("ecosystem_31_sms.psycopg2.connect", return_value=fake_conn):
            result = self.mgr.check_consent("9195551212", channel="sms")
        self.assertFalse(result["has_consent"])
        self.assertEqual(result["status"], "never_subscribed")
        self.assertEqual(result["channel"], "sms")
        self.assertTrue(fake_conn.closed)

    def test_check_consent_returns_true_when_opted_in(self):
        fake_conn = _FakeConn(queued_rows=[
            {"status": "opted_in", "consent_type": "express", "opt_out_timestamp": None},
        ])
        with patch("ecosystem_31_sms.psycopg2.connect", return_value=fake_conn):
            result = self.mgr.check_consent("9195551212", channel="sms")
        self.assertTrue(result["has_consent"])
        self.assertEqual(result["status"], "opted_in")

    def test_check_consent_returns_false_when_opted_out(self):
        fake_conn = _FakeConn(queued_rows=[
            {"status": "opted_out", "consent_type": "express", "opt_out_timestamp": "2026-01-01"},
        ])
        with patch("ecosystem_31_sms.psycopg2.connect", return_value=fake_conn):
            result = self.mgr.check_consent("9195551212", channel="sms")
        self.assertFalse(result["has_consent"])
        self.assertEqual(result["status"], "opted_out")

    def test_check_consent_unknown_channel(self):
        result = self.mgr.check_consent("9195551212", channel="fax")
        self.assertFalse(result["has_consent"])
        self.assertEqual(result["status"], "unknown_channel")


class OptOutPersistenceTest(unittest.TestCase):
    def test_opt_out_writes_per_channel_status(self):
        mgr = e31.ConsentManager(db_url="postgresql://fake")
        fake_conn = _FakeConn()
        with patch("ecosystem_31_sms.psycopg2.connect", return_value=fake_conn):
            mgr.opt_out("9195551212", channel="rcs", reason="user_request")

        # Confirm the SQL hit the rcs_status column, not sms_status
        sql, params = fake_conn._cursor.calls[0]
        self.assertIn("rcs_status", sql)
        self.assertNotIn("sms_status", sql)
        self.assertEqual(params[0], "+19195551212")
        self.assertEqual(params[1], "user_request")
        self.assertTrue(fake_conn.committed)

    def test_opt_in_writes_consent_text_when_provided(self):
        mgr = e31.ConsentManager(db_url="postgresql://fake")
        fake_conn = _FakeConn()
        with patch("ecosystem_31_sms.psycopg2.connect", return_value=fake_conn):
            mgr.opt_in("9195551212", source="signup_form", channel="sms",
                       consent_text_shown="I agree to receive texts")
        sql, params = fake_conn._cursor.calls[0]
        self.assertIn("sms_status", sql)
        self.assertIn("consent_text_shown", sql)
        self.assertEqual(params[-1], "I agree to receive texts")


if __name__ == "__main__":
    unittest.main()
