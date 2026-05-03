"""Test: payload schemas honored both directions."""
from __future__ import annotations
import sys, unittest, uuid
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_19_social_media as e19
from ecosystems._e19_contracts import (
    PersonalizedMessage, SendOutcome, CostEvent, RuleFired,
    Channel, MatchTier, CostType,
)


class PentadContractShapeTest(unittest.TestCase):
    def test_emit_send_outcome_returns_send_outcome(self):
        out = e19.emit_send_outcome(
            send_id="s1", donor_id="d1", channel_value="social_fb",
            cost_cents=200, delivered=True,
        )
        self.assertIsInstance(out, SendOutcome)
        self.assertEqual(out.donor_id, "d1")
        self.assertEqual(out.channel, Channel.SOCIAL_FB)

    def test_emit_send_outcome_blocked_by_field(self):
        out = e19.emit_send_outcome(
            send_id="s2", donor_id="d2", channel_value="social_x",
            cost_cents=0, delivered=False, blocked_by="match_tier_below_threshold",
        )
        self.assertFalse(out.delivered)
        self.assertEqual(out.blocked_by, "match_tier_below_threshold")

    def test_emit_cost_event_idempotent_event_id(self):
        c1 = e19.emit_cost_event(send_id="ABCDEFGH", donor_id="d1",
                                   vendor="meta_ads", unit_cost_cents=500)
        c2 = e19.emit_cost_event(send_id="ABCDEFGH", donor_id="d1",
                                   vendor="meta_ads", unit_cost_cents=500)
        self.assertEqual(c1.event_id, c2.event_id)
        self.assertEqual(c1.event_id, "E19:send:ABCDEFGH")

    def test_emit_cost_event_organic_uses_labor_costtype(self):
        c = e19.emit_cost_event(send_id="ORG12345", donor_id="d1",
                                  vendor="organic", unit_cost_cents=0)
        self.assertEqual(c.cost_type, CostType.LABOR)

    def test_emit_cost_event_paid_uses_ad_spend(self):
        c = e19.emit_cost_event(send_id="PAID1234", donor_id="d1",
                                  vendor="meta_ads", unit_cost_cents=500)
        self.assertEqual(c.cost_type, CostType.AD_SPEND)

    def test_handle_rule_fired_pause(self):
        rf = RuleFired(rule_id="x", target_ecosystem="E19",
                        action="pause_sends", payload={},
                        audit_trail_id=str(uuid.uuid4()))
        result = e19.handle_rule_fired_e19(rf)
        self.assertTrue(result["acted"])
        self.assertEqual(result["applied"], "paused")

    def test_handle_rule_fired_throttle(self):
        rf = RuleFired(rule_id="x", target_ecosystem="E19",
                        action="throttle_sends", payload={"throttle_pct": 50},
                        audit_trail_id=str(uuid.uuid4()))
        result = e19.handle_rule_fired_e19(rf)
        self.assertTrue(result["acted"])
        self.assertEqual(result["applied"], "throttled")

    def test_handle_rule_fired_ignores_other_targets(self):
        rf = RuleFired(rule_id="x", target_ecosystem="E30",
                        action="pause_sends", payload={},
                        audit_trail_id=str(uuid.uuid4()))
        result = e19.handle_rule_fired_e19(rf)
        self.assertFalse(result["acted"])
        self.assertEqual(result["reason"], "not_for_e19")

    def test_e19_only_imports_from_local_or_shared_contracts(self):
        """Pentad Rule P-1: E19 imports ONLY from shared (or _e19_contracts fallback)."""
        import ast
        for path in ("ecosystems/ecosystem_19_social_media.py",
                     "ecosystems/ecosystem_19_audience_builder.py",
                     "ecosystems/ecosystem_19_content_optimizer.py",
                     "ecosystems/ecosystem_19_funnel_sequencer.py",
                     "ecosystems/ecosystem_19_news_trigger.py",
                     "ecosystems/ecosystem_19_listening_inbox.py"):
            tree = ast.parse(open(ROOT / path).read())
            for node in ast.walk(tree):
                if isinstance(node, ast.ImportFrom):
                    mod = node.module or ""
                    # Allow ecosystem_19_*, _e19_contracts, shared.*, and stdlib
                    if mod.startswith("ecosystems.ecosystem_") and "ecosystem_19" not in mod:
                        if "_e19_contracts" not in mod:
                            self.fail(f"{path}: cross-ecosystem import {mod}")


if __name__ == "__main__":
    unittest.main()
