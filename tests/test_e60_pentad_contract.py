"""Test: E60 honors CostEvent in, RuleFired out, OptimizerDecision out."""
from __future__ import annotations
import sys, unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from ecosystems.e60.cost_ledger import CostLedger
from ecosystems.e60.iftt_engine import IFTTEngine
from ecosystems.e60.ml_optimizer import MLOptimizer
from shared.brain_pentad_contracts import (
    CostEvent, CostType, RuleFired, OptimizerDecision,
)


class _FakeConn:
    def __init__(self, rowcount=1):
        class _Cur:
            def __init__(s): s.rowcount = rowcount
            def __enter__(s): return s
            def __exit__(s, *a): return False
            def execute(s, sql, params=None): pass
        self._cur = _Cur()
    def cursor(self, **kw): return self._cur
    def commit(self): pass
    def close(self): pass


class PentadContractTest(unittest.TestCase):
    def test_cost_ledger_consumes_cost_event_in(self):
        ev = CostEvent(
            event_id="E30:send:test1", source_ecosystem="E30",
            cost_type=CostType.SEND, vendor="sendgrid",
            unit_cost_cents=12, quantity=1, total_cost_cents=12,
            occurred_at=datetime.utcnow(),
        )
        with patch("ecosystems.e60.cost_ledger.psycopg2.connect", return_value=_FakeConn()):
            result = CostLedger("postgresql://fake").write(ev)
        self.assertTrue(result)

    def test_iftt_engine_emits_rule_fired_out(self):
        engine = IFTTEngine("postgresql://fake")
        with patch.object(engine, "_persist_fire", return_value="audit-uuid-1"):
            fires = engine.evaluate({"bounce_type": "hard", "email": "x@y.com",
                                     "rnc_regid": "R"})
        self.assertGreater(len(fires), 0)
        for f in fires:
            self.assertIsInstance(f, RuleFired)

    def test_iftt_engine_evaluate_cost_event_returns_rule_fired_list(self):
        engine = IFTTEngine("postgresql://fake")
        with patch.object(engine, "_persist_fire", return_value="audit-uuid-2"):
            ev = CostEvent(
                event_id="E30:send:budget-test", source_ecosystem="E30",
                cost_type=CostType.SEND, vendor="sendgrid",
                unit_cost_cents=12, quantity=1, total_cost_cents=12,
                occurred_at=datetime.utcnow(),
            )
            fires = engine.evaluate_cost_event(ev)
        # CostEvent dict won't match any of our 4 seed rules' payloads
        # (no bounce_type, no match_tier, no daily_burn_cents). Should produce 0 fires.
        self.assertEqual(len(fires), 0)

    def test_optimizer_emits_optimizer_decision_out(self):
        decision = MLOptimizer().decide()
        self.assertIsInstance(decision, OptimizerDecision)
        self.assertTrue(decision.constraints_satisfied)

    def test_e60_modules_only_import_from_shared(self):
        """Rule P-1: E60 imports shared, not other ecosystems."""
        import ast
        for f in (
            "ecosystems/e60/cost_ledger.py",
            "ecosystems/e60/iftt_engine.py",
            "ecosystems/e60/ml_optimizer.py",
        ):
            tree = ast.parse(open(f).read())
            for node in ast.walk(tree):
                if isinstance(node, ast.ImportFrom):
                    mod = node.module or ""
                    if mod.startswith("ecosystems.ecosystem_") or mod.startswith("ecosystem_0") \
                       or mod.startswith("ecosystem_1") or mod.startswith("ecosystem_2") \
                       or mod.startswith("ecosystem_3") or mod.startswith("ecosystem_5"):
                        self.fail(f"{f} imports from cross-ecosystem {mod} — Rule P-1 violation")


if __name__ == "__main__":
    unittest.main()
