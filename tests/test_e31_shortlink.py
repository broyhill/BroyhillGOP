"""
Unit tests for Section 4: ShortlinkEngine.

Covers code generation alphabet, length, click recording, device detection,
and atomic counter increment.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_31_sms as e31  # noqa: E402


class _FakeCursor:
    def __init__(self, queued_rows=None):
        self._queued = list(queued_rows or [])
        self.calls = []

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
        self._cursor = _FakeCursor(queued_rows)
        self.committed = False
        self.closed = False
        self.rolled_back = False

    def cursor(self, cursor_factory=None):
        return self._cursor

    def commit(self):
        self.committed = True

    def close(self):
        self.closed = True

    def rollback(self):
        self.rolled_back = True


class ShortCodeAlphabetTest(unittest.TestCase):
    def test_alphabet_is_url_safe_no_ambiguous(self):
        # No characters that get confused: no 0/O, no 1/l/I
        for bad in '0OlI1':
            self.assertNotIn(bad, e31.ShortlinkEngine.SHORT_CODE_ALPHABET)

    def test_default_length_is_six(self):
        self.assertEqual(e31.ShortlinkEngine.SHORT_CODE_LENGTH, 6)

    def test_generated_code_uses_alphabet(self):
        eng = e31.ShortlinkEngine(db_url="postgresql://fake")
        code = eng._generate_code()
        self.assertEqual(len(code), 6)
        for c in code:
            self.assertIn(c, e31.ShortlinkEngine.SHORT_CODE_ALPHABET)


class ShortlinkClickTrackingTest(unittest.TestCase):
    def test_record_click_increments_counter(self):
        # Queue: SELECT lookup returns a known shortlink_id + url
        fake_conn = _FakeConn(queued_rows=[("abc-uuid", "https://example.com/donate")])
        eng = e31.ShortlinkEngine(db_url="postgresql://fake")
        with patch("ecosystem_31_sms.psycopg2.connect", return_value=fake_conn):
            url = eng.record_click(
                "abc123",
                ip_address="1.2.3.4",
                user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
                phone_number="+19195551212",
            )

        self.assertEqual(url, "https://example.com/donate")
        # 3 SQL calls: SELECT, INSERT click, UPDATE counter
        sqls = [c[0] for c in fake_conn._cursor.calls]
        self.assertEqual(len(sqls), 3)
        self.assertIn("SELECT", sqls[0])
        self.assertIn("INSERT INTO messaging_click_events", sqls[1])
        self.assertIn("UPDATE messaging_shortlinks", sqls[2])
        self.assertTrue(fake_conn.committed)
        self.assertTrue(fake_conn.closed)

    def test_record_click_unknown_code_returns_none(self):
        fake_conn = _FakeConn(queued_rows=[None])
        eng = e31.ShortlinkEngine(db_url="postgresql://fake")
        with patch("ecosystem_31_sms.psycopg2.connect", return_value=fake_conn):
            url = eng.record_click("nope")
        self.assertIsNone(url)
        # Only the SELECT was called; no INSERT, no UPDATE
        self.assertEqual(len(fake_conn._cursor.calls), 1)

    def test_record_click_detects_mobile(self):
        cases = [
            ("Mozilla/5.0 (iPhone; CPU iPhone OS)", "mobile"),
            ("Mozilla/5.0 (Linux; Android 11; ...)", "mobile"),
            ("Mozilla/5.0 (Macintosh; Intel Mac OS X)", "desktop"),
            ("", "desktop"),
        ]
        for ua, expected in cases:
            fake_conn = _FakeConn(queued_rows=[("uuid", "https://x")])
            eng = e31.ShortlinkEngine(db_url="postgresql://fake")
            with patch("ecosystem_31_sms.psycopg2.connect", return_value=fake_conn):
                eng.record_click("xyz", user_agent=ua)
            insert_sql, insert_params = fake_conn._cursor.calls[1]
            self.assertEqual(insert_params[3], expected, f"UA={ua!r}")


if __name__ == "__main__":
    unittest.main()
