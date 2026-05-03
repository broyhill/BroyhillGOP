"""Spine match_tier gate: C/D/E/F/UNMATCHED blocked on email per Pentad Rule P-5."""
from __future__ import annotations
import sys, unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / "ecosystems"))
import ecosystem_30_email as e30
from shared.brain_pentad_contracts import PersonalizedMessage, MatchTier, Channel


def _msg(match_tier: MatchTier) -> PersonalizedMessage:
    return PersonalizedMessage(
        donor_id="RNC-1", variant_id="v1", channel=Channel.EMAIL,
        subject="S", body="<p>B</p>", cta_url="https://x",
        expires_at=datetime.utcnow().replace(year=datetime.utcnow().year + 1),
        grade_at_personalization="A", match_tier=match_tier,
    )


class MatchTierGateTest(unittest.TestCase):
    def setUp(self):
        with patch.object(e30.EmailMarketingSystem, "_instance", None):
            with patch.object(e30.EmailMarketingSystem, "__init__", return_value=None):
                self.sender = e30.EnterpriseEmailSender(db_url="postgresql://fake")
        # All other gates open
        self._suppress = patch.object(self.sender.suppression, "is_suppressed", return_value=False)
        self._consent = patch.object(self.sender.consent, "has_consent",
                                      return_value={"consented": True, "reason": "ok", "row": {}})
        self._suppress.start(); self._consent.start()

    def tearDown(self):
        self._suppress.stop(); self._consent.stop()

    def test_a_exact_allowed(self):
        outcome = self.sender.send_personalized_message(_msg(MatchTier.A_EXACT), "ok@example.com")
        self.assertTrue(outcome.delivered)

    def test_b_alias_allowed(self):
        outcome = self.sender.send_personalized_message(_msg(MatchTier.B_ALIAS), "ok@example.com")
        self.assertTrue(outcome.delivered)

    def test_c_first3_blocked(self):
        outcome = self.sender.send_personalized_message(_msg(MatchTier.C_FIRST3), "x@example.com")
        self.assertFalse(outcome.delivered)
        self.assertEqual(outcome.cost_cents, 0)

    def test_d_household_blocked(self):
        outcome = self.sender.send_personalized_message(_msg(MatchTier.D_HOUSEHOLD), "x@example.com")
        self.assertFalse(outcome.delivered)

    def test_e_wrong_last_blocked(self):
        outcome = self.sender.send_personalized_message(_msg(MatchTier.E_WRONG_LAST), "x@example.com")
        self.assertFalse(outcome.delivered)

    def test_unmatched_blocked(self):
        outcome = self.sender.send_personalized_message(_msg(MatchTier.UNMATCHED), "x@example.com")
        self.assertFalse(outcome.delivered)

    def test_email_allowed_tiers_module_constant(self):
        self.assertIn(MatchTier.A_EXACT, e30.EMAIL_ALLOWED_TIERS)
        self.assertIn(MatchTier.B_ALIAS, e30.EMAIL_ALLOWED_TIERS)
        for blocked in (MatchTier.C_FIRST3, MatchTier.D_HOUSEHOLD,
                        MatchTier.E_WRONG_LAST, MatchTier.UNMATCHED):
            self.assertNotIn(blocked, e30.EMAIL_ALLOWED_TIERS)


if __name__ == "__main__":
    unittest.main()
