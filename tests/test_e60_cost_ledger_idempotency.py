"""Test: same event_id is never double-counted."""
from __future__ import annotations
import sys, unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch, MagicMock

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from ecosystems.e60.cost_ledger import CostLedger
from shared.brain_pentad_contracts import CostEvent, CostType


def _ev(eid="E30:send:abc"):
    return CostEvent(
        event_id=eid, source_ecosystem="E30", donor_id="RNC-1",
        cost_type=CostType.SEND, vendor="sendgrid",
        unit_cost_cents=12, quantity=1, total_cost_cents=12,
        revenue_attributed_cents=0, occurred_at=datetime.utcnow(),
    )


class _FakeCursor:
    def __init__(self, rowcount_seq):
        self.rowcounts = list(rowcount_seq)
        self.calls = []

    def __enter__(self): return self
    def __exit__(self, *a): return False

    def execute(self, sql, params=None):
        self.calls.append((sql, params))
        self.rowcount = self.rowcounts.pop(0) if self.rowcounts else 0


class _FakeConn:
    def __init__(self, rowcount_seq):
        self.cursor_obj = _FakeCursor(rowcount_seq)
        self.committed = False
        self.closed = False

    def cursor(self): return self.cursor_obj
    def commit(self): self.committed = True
    def close(self): self.closed = True


class IdempotencyTest(unittest.TestCase):
    def test_first_write_returns_true(self):
        fake = _FakeConn([1])  # row created
        with patch("ecosystems.e60.cost_ledger.psycopg2.connect", return_value=fake):
            result = CostLedger("postgresql://fake").write(_ev())
        self.assertTrue(result)
        self.assertTrue(fake.committed)

    def test_duplicate_write_returns_false(self):
        fake = _FakeConn([0])  # ON CONFLICT DO NOTHING returns 0 rows
        with patch("ecosystems.e60.cost_ledger.psycopg2.connect", return_value=fake):
            result = CostLedger("postgresql://fake").write(_ev())
        self.assertFalse(result)

    def test_same_event_id_is_only_persisted_once(self):
        # 1st call: row created (rowcount=1). 2nd call: ON CONFLICT (rowcount=0).
        responses = [_FakeConn([1]), _FakeConn([0])]
        with patch("ecosystems.e60.cost_ledger.psycopg2.connect",
                   side_effect=lambda *a, **k: responses.pop(0)):
            ledger = CostLedger("postgresql://fake")
            self.assertTrue(ledger.write(_ev("DUP-12345678")))
            self.assertFalse(ledger.write(_ev("DUP-12345678")))

    def test_insert_uses_on_conflict_do_nothing(self):
        fake = _FakeConn([1])
        with patch("ecosystems.e60.cost_ledger.psycopg2.connect", return_value=fake):
            CostLedger("postgresql://fake").write(_ev())
        sql, params = fake.cursor_obj.calls[0]
        self.assertIn("ON CONFLICT (event_id) DO NOTHING", sql)
        self.assertEqual(params[0], "E30:send:abc")  # event_id is first param


if __name__ == "__main__":
    unittest.main()
