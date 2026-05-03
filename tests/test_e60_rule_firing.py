"""Test: seed rules fire on synthetic events."""
from __future__ import annotations
import sys, unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from ecosystems.e60.iftt_engine import IFTTEngine, SEED_RULES
from shared.brain_pentad_contracts import RuleFired


class SeedRulesTest(unittest.TestCase):
    def setUp(self):
        # Patch the audit-log persist to avoid DB calls
        self.engine = IFTTEngine("postgresql://fake")
        self._patcher = patch.object(self.engine, "_persist_fire",
                                      return_value="00000000-0000-0000-0000-000000000000")
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_hard_bounce_rule_fires(self):
        fires = self.engine.evaluate({"bounce_type": "hard", "email": "x@y.com",
                                       "rnc_regid": "RNC-1"})
        rule_ids = {f.rule_id for f in fires}
        self.assertIn("hard_bounce_suppress_and_regrade", rule_ids)
        # Confirm payload has the email
        for f in fires:
            if f.rule_id == "hard_bounce_suppress_and_regrade":
                self.assertEqual(f.payload["email"], "x@y.com")
                self.assertEqual(f.payload["reason"], "hard_bounce")
                self.assertEqual(f.target_ecosystem, "E30")

    def test_soft_bounce_does_NOT_fire_hard_bounce_rule(self):
        fires = self.engine.evaluate({"bounce_type": "soft", "email": "x@y.com"})
        rule_ids = {f.rule_id for f in fires}
        self.assertNotIn("hard_bounce_suppress_and_regrade", rule_ids)

    def test_high_confidence_cluster_rule_fires(self):
        fires = self.engine.evaluate({"cross_spine_match_confidence": 0.97,
                                       "cluster_id": 12345,
                                       "proposed_rnc_regid": "RNC-PROPOSED"})
        rule_ids = {f.rule_id for f in fires}
        self.assertIn("high_confidence_cluster_recommend", rule_ids)
        for f in fires:
            if f.rule_id == "high_confidence_cluster_recommend":
                self.assertEqual(f.target_ecosystem, "E01")
                # Recommendation only — never auto-stamps
                self.assertEqual(f.action, "recommend_rnc_regid_stamp")

    def test_low_match_tier_blocks_outbound(self):
        for tier in ("E_WRONG_LAST", "UNMATCHED"):
            fires = self.engine.evaluate({"match_tier": tier, "email": "low@y.com"})
            rule_ids = {f.rule_id for f in fires}
            self.assertIn("low_match_tier_block_outbound", rule_ids,
                          f"low_match_tier rule must fire for {tier}")

    def test_high_match_tier_does_NOT_fire_block_rule(self):
        for tier in ("A_EXACT", "B_ALIAS", "C_FIRST3", "D_HOUSEHOLD"):
            fires = self.engine.evaluate({"match_tier": tier, "email": "ok@y.com"})
            rule_ids = {f.rule_id for f in fires}
            self.assertNotIn("low_match_tier_block_outbound", rule_ids,
                             f"low_match_tier rule must NOT fire for {tier}")

    def test_daily_budget_breach_pauses(self):
        fires = self.engine.evaluate({"daily_burn_cents": 12_000,
                                       "daily_cap_cents": 10_000,
                                       "until_iso": "2026-05-03T00:00:00Z"})
        rule_ids = {f.rule_id for f in fires}
        self.assertIn("daily_budget_breach_pause_sends", rule_ids)
        for f in fires:
            if f.rule_id == "daily_budget_breach_pause_sends":
                self.assertEqual(f.action, "pause_sends")
                self.assertEqual(f.target_ecosystem, "E30")

    def test_daily_budget_under_cap_does_NOT_pause(self):
        fires = self.engine.evaluate({"daily_burn_cents": 5_000,
                                       "daily_cap_cents": 10_000})
        rule_ids = {f.rule_id for f in fires}
        self.assertNotIn("daily_budget_breach_pause_sends", rule_ids)

    def test_seed_rule_count(self):
        # Spec mandates exactly 4 seed rules
        self.assertEqual(len(SEED_RULES), 4)

    def test_all_fires_return_rule_fired_payloads(self):
        fires = self.engine.evaluate({"bounce_type": "hard", "email": "x@y.com",
                                       "rnc_regid": "R"})
        for f in fires:
            self.assertIsInstance(f, RuleFired)
            # audit_trail_id is patched to a stub UUID
            self.assertIsInstance(f.audit_trail_id, str)


if __name__ == "__main__":
    unittest.main()
