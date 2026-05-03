"""Test: only A_EXACT/B_ALIAS allowed for individualized targeting."""
from __future__ import annotations
import sys, unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_19_social_media as e19


class MatchTierGateTest(unittest.TestCase):
    def setUp(self):
        self._patcher = patch.object(e19, "_log_compliance_decision")
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_a_exact_allowed(self):
        self.assertTrue(e19.check_match_tier_gate("A_EXACT")["allow"])

    def test_b_alias_allowed(self):
        self.assertTrue(e19.check_match_tier_gate("B_ALIAS")["allow"])

    def test_c_first3_blocked(self):
        result = e19.check_match_tier_gate("C_FIRST3")
        self.assertFalse(result["allow"])
        self.assertEqual(result["reason"], "match_tier_below_threshold")

    def test_d_household_blocked(self):
        self.assertFalse(e19.check_match_tier_gate("D_HOUSEHOLD")["allow"])

    def test_e_wrong_last_blocked(self):
        self.assertFalse(e19.check_match_tier_gate("E_WRONG_LAST")["allow"])

    def test_unmatched_blocked(self):
        self.assertFalse(e19.check_match_tier_gate("UNMATCHED")["allow"])

    def test_invalid_tier_blocked(self):
        self.assertFalse(e19.check_match_tier_gate("THIS_IS_NOT_A_TIER")["allow"])

    def test_none_blocked(self):
        self.assertFalse(e19.check_match_tier_gate(None)["allow"])

    def test_individualized_allowed_tiers_constant(self):
        from ecosystems._e19_contracts import MatchTier
        self.assertIn(MatchTier.A_EXACT, e19.INDIVIDUALIZED_ALLOWED_TIERS)
        self.assertIn(MatchTier.B_ALIAS, e19.INDIVIDUALIZED_ALLOWED_TIERS)
        for blocked in (MatchTier.C_FIRST3, MatchTier.D_HOUSEHOLD,
                        MatchTier.E_WRONG_LAST, MatchTier.UNMATCHED):
            self.assertNotIn(blocked, e19.INDIVIDUALIZED_ALLOWED_TIERS)


if __name__ == "__main__":
    unittest.main()
