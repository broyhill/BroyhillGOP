"""Pentad contract: E30 honors PersonalizedMessage in, SendOutcome out,
CostEvent out, RuleFired in."""
from __future__ import annotations
import sys, unittest, uuid
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / "ecosystems"))
import ecosystem_30_email as e30
from shared.brain_pentad_contracts import (
    PersonalizedMessage, SendOutcome, CostEvent, RuleFired,
    MatchTier, Channel, CostType,
)


def _msg() -> PersonalizedMessage:
    return PersonalizedMessage(
        donor_id="RNC-PENTAD-E30", variant_id="v1", channel=Channel.EMAIL,
        subject="Subject", body="<p>Body</p>", cta_url="https://x",
        expires_at=datetime.utcnow().replace(year=datetime.utcnow().year + 1),
        grade_at_personalization="A", match_tier=MatchTier.A_EXACT,
    )


class PentadContractTest(unittest.TestCase):
    def setUp(self):
        with patch.object(e30.EmailMarketingSystem, "_instance", None):
            with patch.object(e30.EmailMarketingSystem, "__init__", return_value=None):
                self.sender = e30.EnterpriseEmailSender(db_url="postgresql://fake")
        self._suppress = patch.object(self.sender.suppression, "is_suppressed", return_value=False)
        self._consent = patch.object(self.sender.consent, "has_consent",
                                      return_value={"consented": True, "reason": "ok", "row": {}})
        self._suppress.start(); self._consent.start()

    def tearDown(self):
        self._suppress.stop(); self._consent.stop()

    def test_send_consumes_personalized_message_returns_send_outcome(self):
        outcome = self.sender.send_personalized_message(_msg(), "ok@example.com")
        self.assertIsInstance(outcome, SendOutcome)
        self.assertEqual(outcome.donor_id, "RNC-PENTAD-E30")
        self.assertEqual(outcome.channel, Channel.EMAIL)

    def test_build_cost_event_for_returns_valid_cost_event(self):
        outcome = self.sender.send_personalized_message(_msg(), "ok@example.com")
        cost = self.sender.build_cost_event_for(outcome, vendor="sendgrid")
        self.assertIsInstance(cost, CostEvent)
        self.assertEqual(cost.source_ecosystem, "E30")
        self.assertEqual(cost.cost_type, CostType.SEND)
        self.assertEqual(cost.vendor, "sendgrid")
        self.assertEqual(cost.unit_cost_cents, outcome.cost_cents)
        self.assertEqual(cost.quantity, 1)
        self.assertEqual(cost.total_cost_cents, outcome.cost_cents)
        self.assertEqual(cost.donor_id, outcome.donor_id)

    def test_cost_event_id_is_stable_per_send_id(self):
        """Same send_id MUST produce same event_id (E60 idempotency contract)."""
        outcome = self.sender.send_personalized_message(_msg(), "ok@example.com")
        c1 = self.sender.build_cost_event_for(outcome)
        c2 = self.sender.build_cost_event_for(outcome)
        self.assertEqual(c1.event_id, c2.event_id)

    def test_handle_rule_fired_pause_action(self):
        fired = RuleFired(
            rule_id="daily_budget_exceeded", target_ecosystem="E30",
            action="pause_sends", payload={}, audit_trail_id=str(uuid.uuid4()),
        )
        result = self.sender.handle_rule_fired(fired)
        self.assertTrue(result["acted"])
        self.assertEqual(result["applied"], "paused")

    def test_handle_rule_fired_throttle_action(self):
        fired = RuleFired(
            rule_id="hourly_warning", target_ecosystem="E30",
            action="throttle_sends", payload={"throttle_pct": 50},
            audit_trail_id=str(uuid.uuid4()),
        )
        result = self.sender.handle_rule_fired(fired)
        self.assertTrue(result["acted"])
        self.assertEqual(result["applied"], "throttled")

    def test_handle_rule_fired_ignores_other_targets(self):
        fired = RuleFired(
            rule_id="x", target_ecosystem="E31",  # SMS, not email
            action="pause_sends", payload={}, audit_trail_id=str(uuid.uuid4()),
        )
        result = self.sender.handle_rule_fired(fired)
        self.assertFalse(result["acted"])
        self.assertEqual(result["reason"], "not_for_e30")

    def test_handle_rule_fired_unknown_action(self):
        fired = RuleFired(
            rule_id="x", target_ecosystem="E30",
            action="explode_planet", payload={}, audit_trail_id=str(uuid.uuid4()),
        )
        result = self.sender.handle_rule_fired(fired)
        self.assertFalse(result["acted"])
        self.assertIn("unknown_action", result["reason"])

    def test_e30_does_not_import_other_ecosystems(self):
        """Rule P-1: E30 imports ONLY from shared.brain_pentad_contracts."""
        import ast
        src = open("ecosystems/ecosystem_30_email.py").read()
        tree = ast.parse(src)
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    self.assertFalse(
                        alias.name.startswith("ecosystem_") and alias.name != "ecosystem_30_email",
                        f"Direct import of another ecosystem: {alias.name}",
                    )
            elif isinstance(node, ast.ImportFrom):
                mod = node.module or ""
                # Allow shared.* and ecosystem_30_*; forbid other ecosystem_NN_*
                if mod.startswith("ecosystems.ecosystem_") and "ecosystem_30" not in mod:
                    self.fail(f"Direct cross-ecosystem import: from {mod}")
                if mod.startswith("ecosystem_") and not mod.startswith("ecosystem_30"):
                    self.fail(f"Direct cross-ecosystem import: from {mod}")


class BounceClassifierTest(unittest.TestCase):
    """BounceClassifier supports the SendOutcome.bounce_type contract."""

    def test_5xx_is_hard(self):
        self.assertEqual(e30.BounceClassifier.classify({"smtp_code": "550"}), "hard")
        self.assertEqual(e30.BounceClassifier.classify({"smtp_code": "552"}), "hard")

    def test_4xx_is_soft(self):
        self.assertEqual(e30.BounceClassifier.classify({"smtp_code": "421"}), "soft")
        self.assertEqual(e30.BounceClassifier.classify({"smtp_code": "452"}), "soft")

    def test_2xx_is_none(self):
        self.assertEqual(e30.BounceClassifier.classify({"smtp_code": "250"}), "none")

    def test_hard_always_suppress(self):
        self.assertTrue(e30.BounceClassifier.should_suppress("hard", soft_retry_count=0))

    def test_soft_suppresses_after_max_retries(self):
        self.assertFalse(e30.BounceClassifier.should_suppress("soft", soft_retry_count=0))
        self.assertFalse(e30.BounceClassifier.should_suppress("soft", soft_retry_count=2))
        self.assertTrue(e30.BounceClassifier.should_suppress("soft", soft_retry_count=3))

    def test_none_never_suppresses(self):
        self.assertFalse(e30.BounceClassifier.should_suppress("none", soft_retry_count=10))


class DeliverabilityTest(unittest.TestCase):
    """DKIM/SPF/DMARC scaffolding + IP warmup schedule."""

    def test_warmup_schedule_progresses(self):
        cap_d1 = e30.DeliverabilityConfig.daily_cap(1)
        cap_d7 = e30.DeliverabilityConfig.daily_cap(7)
        cap_d30 = e30.DeliverabilityConfig.daily_cap(30)
        cap_d60 = e30.DeliverabilityConfig.daily_cap(60)
        self.assertEqual(cap_d1, 50)
        self.assertEqual(cap_d7, 1_000)
        self.assertEqual(cap_d30, 50_000)
        self.assertEqual(cap_d60, 50_000)  # capped at top of schedule

    def test_warmup_zero_days_returns_zero(self):
        self.assertEqual(e30.DeliverabilityConfig.daily_cap(0), 0)

    def test_dns_validate_accepts_well_formed_domain(self):
        result = e30.DeliverabilityConfig.validate_dns("bgop.email")
        self.assertTrue(result["ready_to_send"])
        self.assertTrue(result["spf_ok"])
        self.assertTrue(result["dkim_ok"])
        self.assertTrue(result["dmarc_ok"])

    def test_dns_validate_rejects_malformed_domain(self):
        result = e30.DeliverabilityConfig.validate_dns("not a domain")
        self.assertFalse(result["ready_to_send"])


if __name__ == "__main__":
    unittest.main()
