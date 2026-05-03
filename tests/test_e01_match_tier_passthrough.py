"""
Test: grade_donor() passes through match_tier from the source view unchanged.

E01 does not re-derive match_tier — that's the spine's job. E01 simply reads
it and propagates it into the GradedDonor payload that flows to E19.
"""

from __future__ import annotations

import sys
import unittest
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_01_donor_intelligence as e01  # noqa: E402
from shared.brain_pentad_contracts import MatchTier  # noqa: E402


def _row(match_tier_value: str, **overrides) -> dict:
    """Build a complete donor row with the requested match_tier."""
    base = {
        "rnc_regid":        "RNC-TEST-1",
        "txn_count":        10,
        "lifetime_total":   1500.00,
        "largest_gift":     250.00,
        "first_gift_date":  date(2020, 1, 1),
        "last_gift_date":   date(2025, 6, 1),
        "committee_count":  4,
        "candidate_count":  6,
        "match_tier":       match_tier_value,
    }
    base.update(overrides)
    return base


class MatchTierPassthroughTest(unittest.TestCase):
    def test_a_exact_passthrough(self):
        g = e01.grade_donor("RNC-1", row=_row("A_EXACT"))
        self.assertEqual(g.match_tier, MatchTier.A_EXACT)

    def test_b_alias_passthrough(self):
        g = e01.grade_donor("RNC-2", row=_row("B_ALIAS"))
        self.assertEqual(g.match_tier, MatchTier.B_ALIAS)

    def test_c_first3_passthrough(self):
        g = e01.grade_donor("RNC-3", row=_row("C_FIRST3"))
        self.assertEqual(g.match_tier, MatchTier.C_FIRST3)

    def test_d_household_passthrough(self):
        g = e01.grade_donor("RNC-4", row=_row("D_HOUSEHOLD"))
        self.assertEqual(g.match_tier, MatchTier.D_HOUSEHOLD)

    def test_e_wrong_last_passthrough(self):
        g = e01.grade_donor("RNC-5", row=_row("E_WRONG_LAST"))
        self.assertEqual(g.match_tier, MatchTier.E_WRONG_LAST)

    def test_unmatched_passthrough(self):
        g = e01.grade_donor("RNC-6", row=_row("UNMATCHED"))
        self.assertEqual(g.match_tier, MatchTier.UNMATCHED)

    def test_missing_match_tier_defaults_to_unmatched(self):
        row = _row("ignored")
        del row["match_tier"]
        g = e01.grade_donor("RNC-7", row=row)
        self.assertEqual(g.match_tier, MatchTier.UNMATCHED)

    def test_invalid_match_tier_value_falls_back_to_unmatched(self):
        """Defensive: a bad value in the view must not crash grading."""
        g = e01.grade_donor("RNC-8", row=_row("THIS_IS_NOT_A_VALID_TIER"))
        self.assertEqual(g.match_tier, MatchTier.UNMATCHED)

    def test_unmatched_donor_returns_zero_confidence_and_F(self):
        g = e01.grade_donor("RNC-NOT-FOUND", row=None)
        self.assertEqual(g.match_tier, MatchTier.UNMATCHED)
        self.assertEqual(g.grade, "F")
        self.assertEqual(g.confidence, 0.0)

    def test_higher_tier_confidence_floor_holds(self):
        """An A_EXACT row must produce strictly higher confidence than the
        same row tagged D_HOUSEHOLD (everything else equal)."""
        a = e01.grade_donor("RNC-A", row=_row("A_EXACT"))
        d = e01.grade_donor("RNC-A", row=_row("D_HOUSEHOLD"))
        self.assertGreater(a.confidence, d.confidence)

    def test_tier_pass_through_does_not_change_grade_letter(self):
        """The grade letter is derived from giving/engagement, not from match_tier.
        Two rows differing only in match_tier should produce the same grade."""
        a = e01.grade_donor("RNC-A", row=_row("A_EXACT"))
        d = e01.grade_donor("RNC-A", row=_row("D_HOUSEHOLD"))
        self.assertEqual(a.grade, d.grade)


if __name__ == "__main__":
    unittest.main()
