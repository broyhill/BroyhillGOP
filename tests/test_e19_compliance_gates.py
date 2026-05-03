"""Test: every gate logs its decision to compliance_audit."""
from __future__ import annotations
import sys, unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_19_social_media as e19


class ComplianceAuditTest(unittest.TestCase):
    """Each gate must call _log_compliance_decision exactly once per invocation."""

    def setUp(self):
        self._patcher = patch.object(e19, "_log_compliance_decision")
        self.mock_log = self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_meta_political_authorization_logs(self):
        # Note: when _verified_accounts is None we DEFAULT-ALLOW to avoid false positives
        # in environments without the table. The log still fires.
        e19.check_meta_political_authorization("acct-1", is_paid=True,
                                                  _verified_accounts=set())
        self.assertEqual(self.mock_log.call_count, 1)

    def test_fec_paid_for_by_logs_only_when_paid(self):
        # Organic skip path doesn't log (returns early).
        e19.check_fec_paid_for_by({"is_paid": False})
        self.assertEqual(self.mock_log.call_count, 0)
        # Paid path logs.
        e19.check_fec_paid_for_by({"is_paid": True, "body": "Donate"})
        self.assertEqual(self.mock_log.call_count, 1)

    def test_state_ai_disclosure_logs_only_for_ai_in_regulated_state(self):
        # Non-AI: returns early, no log.
        e19.check_state_ai_disclosure({"ai_generated": False}, "CA")
        self.assertEqual(self.mock_log.call_count, 0)
        # AI in unregulated state: returns early, no log.
        e19.check_state_ai_disclosure({"ai_generated": True}, "ND")
        self.assertEqual(self.mock_log.call_count, 0)
        # AI in regulated state: logs.
        e19.check_state_ai_disclosure({"ai_generated": True, "body": "Vote!"}, "CA")
        self.assertEqual(self.mock_log.call_count, 1)

    def test_match_tier_gate_always_logs(self):
        e19.check_match_tier_gate("A_EXACT")
        e19.check_match_tier_gate("UNMATCHED")
        self.assertEqual(self.mock_log.call_count, 2)

    def test_funnel_stage_gate_logs(self):
        e19.check_funnel_stage_gate(
            {"content_stage": "issue_education"}, "STRANGER"
        )
        self.assertEqual(self.mock_log.call_count, 1)

    def test_fatigue_cap_logs(self):
        e19.check_fatigue_cap("STRANGER", recent_send_count=0)
        e19.check_fatigue_cap("STRANGER", recent_send_count=5)  # exceeds cap of 3
        self.assertEqual(self.mock_log.call_count, 2)

    def test_funnel_gate_blocks_stranger_from_bundler_content(self):
        result = e19.check_funnel_stage_gate(
            {"content_stage": "vip_access"}, "STRANGER"
        )
        self.assertFalse(result["allow"])

    def test_surrogate_disclosure_skips_when_not_surrogate(self):
        # Not-surrogate path returns early, no log.
        e19.check_surrogate_disclosure({"is_surrogate": False})
        self.assertEqual(self.mock_log.call_count, 0)
        # Surrogate without disclosure logs.
        e19.check_surrogate_disclosure({"is_surrogate": True})
        self.assertEqual(self.mock_log.call_count, 1)


if __name__ == "__main__":
    unittest.main()
