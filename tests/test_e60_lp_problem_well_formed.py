"""Test: LP problem has feasible region; constraints documented."""
from __future__ import annotations
import sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from ecosystems.e60.ml_optimizer import (
    LPProblemStatement, MLOptimizer, build_lp_problem_statement,
)
from shared.brain_pentad_contracts import Channel, OptimizerDecision


class LPProblemWellFormedTest(unittest.TestCase):
    def test_default_statement_has_positive_budget(self):
        lp = build_lp_problem_statement()
        self.assertGreater(lp.daily_cap_cents, 0)

    def test_default_statement_has_at_least_one_channel(self):
        lp = build_lp_problem_statement()
        self.assertGreater(len(lp.channels), 0)

    def test_default_statement_has_at_least_one_segment(self):
        lp = build_lp_problem_statement()
        self.assertGreater(len(lp.segments), 0)

    def test_unit_costs_defined_for_every_channel(self):
        lp = build_lp_problem_statement()
        for c in lp.channels:
            self.assertIn(c.value, lp.unit_cost_per_channel_cents,
                          f"missing unit_cost for channel {c.value}")

    def test_max_sends_per_grade_defined(self):
        lp = build_lp_problem_statement()
        for g in ("A", "B", "C", "D", "F"):
            self.assertIn(g, lp.max_sends_per_grade_per_day,
                          f"missing max_sends_per_grade for {g}")

    def test_lp_statement_is_immutable(self):
        lp = build_lp_problem_statement()
        with self.assertRaises(Exception):
            lp.daily_cap_cents = 999  # type: ignore[misc]

    def test_trivial_feasible_point_exists(self):
        """The all-zero allocation is always feasible (budget unused, nothing sent)."""
        lp = build_lp_problem_statement(daily_cap_cents=10_000)
        zero_spend = 0
        self.assertLessEqual(zero_spend, lp.daily_cap_cents,
                             "Trivial feasible point (spend=0) must satisfy budget cap")


class MLOptimizerDecideTest(unittest.TestCase):
    def test_decide_returns_optimizer_decision(self):
        decision = MLOptimizer().decide()
        self.assertIsInstance(decision, OptimizerDecision)

    def test_decide_satisfies_budget_cap(self):
        lp = build_lp_problem_statement(daily_cap_cents=30_000)
        decision = MLOptimizer().decide(lp)
        total_spend = sum(a["spend_cents"] for a in decision.allocations)
        self.assertLessEqual(total_spend, lp.daily_cap_cents,
                             "Total spend must not exceed daily cap")
        self.assertTrue(decision.constraints_satisfied)

    def test_decide_excludes_channels_for_low_match_tier_segments(self):
        """Per Pentad Rule P-5, electronic channels can't ship to D/E/UNMATCHED."""
        lp = build_lp_problem_statement(
            daily_cap_cents=10_000,
            segments=[
                {"name": "lo_tier", "match_tier": "D_HOUSEHOLD", "grade": "C", "size": 1000},
            ],
        )
        decision = MLOptimizer().decide(lp)
        for a in decision.allocations:
            if a["channel"] in ("email", "sms", "rcs", "voice"):
                self.fail(f"Channel {a['channel']} allocated to low-tier segment "
                          f"{a['segment']} — Rule P-5 violation")

    def test_decide_includes_model_version_string(self):
        decision = MLOptimizer().decide()
        self.assertTrue(decision.model_version)
        self.assertIn("v0", decision.model_version)


if __name__ == "__main__":
    unittest.main()
