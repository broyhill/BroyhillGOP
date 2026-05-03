"""Consent: no send without an opted-in row in core.email_consent."""
from __future__ import annotations
import sys, unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / "ecosystems"))
import ecosystem_30_email as e30
from shared.brain_pentad_contracts import PersonalizedMessage, MatchTier, Channel


def _msg() -> PersonalizedMessage:
    return PersonalizedMessage(
        donor_id="RNC-CONSENT-1", variant_id="v1", channel=Channel.EMAIL,
        subject="S", body="<p>B</p>", cta_url="https://x",
        expires_at=datetime.utcnow().replace(year=datetime.utcnow().year + 1),
        grade_at_personalization="A", match_tier=MatchTier.A_EXACT,
    )


class ConsentGateTest(unittest.TestCase):
    def setUp(self):
        with patch.object(e30.EmailMarketingSystem, "_instance", None):
            with patch.object(e30.EmailMarketingSystem, "__init__", return_value=None):
                self.sender = e30.EnterpriseEmailSender(db_url="postgresql://fake")

    def test_no_consent_row_blocks_send(self):
        with patch.object(self.sender.suppression, "is_suppressed", return_value=False), \
             patch.object(self.sender.consent, "has_consent",
                          return_value={"consented": False, "reason": "no_consent_record", "row": None}):
            outcome = self.sender.send_personalized_message(_msg(), "new@example.com")
        self.assertFalse(outcome.delivered)
        self.assertEqual(outcome.cost_cents, 0)

    def test_revoked_consent_blocks_send(self):
        with patch.object(self.sender.suppression, "is_suppressed", return_value=False), \
             patch.object(self.sender.consent, "has_consent",
                          return_value={"consented": False, "reason": "consent_revoked", "row": {}}):
            outcome = self.sender.send_personalized_message(_msg(), "revoked@example.com")
        self.assertFalse(outcome.delivered)

    def test_double_opt_in_pending_blocks_send_when_required(self):
        result = {"consented": False, "reason": "double_opt_in_pending", "row": {}}
        with patch.object(self.sender.suppression, "is_suppressed", return_value=False), \
             patch.object(self.sender.consent, "has_consent", return_value=result):
            outcome = self.sender.send_personalized_message(_msg(), "pending@example.com")
        self.assertFalse(outcome.delivered)

    def test_valid_consent_allows_send(self):
        with patch.object(self.sender.suppression, "is_suppressed", return_value=False), \
             patch.object(self.sender.consent, "has_consent",
                          return_value={"consented": True, "reason": "ok", "row": {"email": "ok@example.com"}}):
            outcome = self.sender.send_personalized_message(_msg(), "ok@example.com")
        self.assertTrue(outcome.delivered)
        self.assertGreater(outcome.cost_cents, 0)

    def test_force_bypasses_consent_gate(self):
        # force=True is for transactional / legal-required emails that bypass the consent gate.
        # All other gates still apply through the codepath, but force short-circuits the
        # consent ledger check too.
        with patch.object(self.sender.suppression, "is_suppressed", return_value=False):
            outcome = self.sender.send_personalized_message(_msg(), "forced@example.com", force=True)
        self.assertTrue(outcome.delivered)


if __name__ == "__main__":
    unittest.main()
