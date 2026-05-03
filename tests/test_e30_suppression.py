"""Suppression: suppressed addresses never receive sends."""
from __future__ import annotations
import sys, unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / "ecosystems"))
import ecosystem_30_email as e30
from shared.brain_pentad_contracts import (
    PersonalizedMessage, MatchTier, Channel,
)


def _msg(donor_id="RNC-1", match_tier=MatchTier.A_EXACT) -> PersonalizedMessage:
    return PersonalizedMessage(
        donor_id=donor_id, variant_id="v1", channel=Channel.EMAIL,
        subject="Subject", body="<p>Hello</p>", cta_url="https://example.com",
        expires_at=datetime.utcnow().replace(year=datetime.utcnow().year + 1),
        grade_at_personalization="A", match_tier=match_tier,
    )


class SuppressionGateTest(unittest.TestCase):
    def setUp(self):
        # Mock the legacy EmailMarketingSystem singleton init so the sender constructs
        with patch.object(e30.EmailMarketingSystem, "_instance", None):
            with patch.object(e30.EmailMarketingSystem, "__init__", return_value=None):
                self.sender = e30.EnterpriseEmailSender(db_url="postgresql://fake")

    def test_suppressed_email_blocked(self):
        msg = _msg()
        with patch.object(self.sender.suppression, "is_suppressed", return_value=True):
            outcome = self.sender.send_personalized_message(msg, "blocked@example.com")
        self.assertFalse(outcome.delivered)
        self.assertEqual(outcome.cost_cents, 0)

    def test_suppression_add_with_invalid_reason_raises(self):
        with patch.object(self.sender.suppression, "_get_db"):
            with self.assertRaises(ValueError):
                self.sender.suppression.add("test@example.com", "bogus_reason")

    def test_suppression_valid_reasons(self):
        for reason in (
            e30.SuppressionList.HARD_BOUNCE,
            e30.SuppressionList.COMPLAINT,
            e30.SuppressionList.UNSUBSCRIBE,
            e30.SuppressionList.MANUAL,
        ):
            self.assertIsNotNone(reason)
            self.assertIsInstance(reason, str)


if __name__ == "__main__":
    unittest.main()
