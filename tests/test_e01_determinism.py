"""
Test: grade_donor() is deterministic.

Same input row -> same (grade, match_tier, confidence, inputs_hash).
graded_at is metadata only and is NOT folded into inputs_hash.
"""

from __future__ import annotations

import sys
import unittest
from datetime import date, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_01_donor_intelligence as e01  # noqa: E402
from shared.brain_pentad_contracts import GradedDonor, MatchTier  # noqa: E402


# A representative trusted-view row for Ed's canary cluster (372171).
# 147 transactions, $332,631.30 lifetime, exact match to ed@broyhill.net.
ED_CANARY_ROW = {
    "rnc_regid":        "RNC-372171-ED-BROYHILL",
    "txn_count":        147,
    "lifetime_total":   332631.30,
    "largest_gift":     50000.00,
    "first_gift_date":  date(2014, 6, 12),
    "last_gift_date":   date(2025, 11, 18),
    "committee_count":  23,
    "candidate_count":  41,
    "match_tier":       "A_EXACT",
    "personal_email":   "ed@broyhill.net",
}

# A B-tier alias-matched donor with mid-range giving.
B_TIER_ROW = {
    "rnc_regid":        "RNC-555-MARGARET-W",
    "txn_count":        12,
    "lifetime_total":   2400.00,
    "largest_gift":     500.00,
    "first_gift_date":  date(2018, 3, 1),
    "last_gift_date":   date(2025, 4, 22),
    "committee_count":  3,
    "candidate_count":  5,
    "match_tier":       "B_ALIAS",
}


class DeterminismTest(unittest.TestCase):
    def test_same_row_produces_same_grade_match_tier_confidence_hash(self):
        g1 = e01.grade_donor(ED_CANARY_ROW["rnc_regid"], row=ED_CANARY_ROW)
        g2 = e01.grade_donor(ED_CANARY_ROW["rnc_regid"], row=ED_CANARY_ROW)
        # Every deterministic field matches
        self.assertEqual(g1.rnc_regid, g2.rnc_regid)
        self.assertEqual(g1.grade, g2.grade)
        self.assertEqual(g1.match_tier, g2.match_tier)
        self.assertEqual(g1.confidence, g2.confidence)
        self.assertEqual(g1.inputs_hash, g2.inputs_hash)

    def test_graded_at_is_NOT_in_inputs_hash(self):
        """Calling twice produces different graded_at but identical inputs_hash."""
        g1 = e01.grade_donor("RNC-X", row=B_TIER_ROW)
        g2 = e01.grade_donor("RNC-X", row=B_TIER_ROW)
        self.assertEqual(g1.inputs_hash, g2.inputs_hash)
        # graded_at MAY or MAY NOT be exactly equal depending on clock resolution,
        # but the two values must reflect "now" (utcnow), so they should be
        # within seconds of each other.
        self.assertIsInstance(g1.graded_at, datetime)
        self.assertIsInstance(g2.graded_at, datetime)
        self.assertLess(abs((g2.graded_at - g1.graded_at).total_seconds()), 5.0)

    def test_changing_lifetime_total_changes_inputs_hash(self):
        row_a = dict(B_TIER_ROW)
        row_b = dict(B_TIER_ROW)
        row_b["lifetime_total"] = row_a["lifetime_total"] + 0.01  # one cent
        g_a = e01.grade_donor("X", row=row_a)
        g_b = e01.grade_donor("X", row=row_b)
        self.assertNotEqual(g_a.inputs_hash, g_b.inputs_hash,
                            "Even one-cent input change must change the hash")

    def test_changing_only_irrelevant_field_does_NOT_change_hash(self):
        """personal_email is NOT in _GRADE_INPUT_FIELDS, so it can't affect the hash."""
        row_a = dict(ED_CANARY_ROW)
        row_b = dict(ED_CANARY_ROW)
        row_b["personal_email"] = "different@example.com"
        g_a = e01.grade_donor("X", row=row_a)
        g_b = e01.grade_donor("X", row=row_b)
        self.assertEqual(g_a.inputs_hash, g_b.inputs_hash,
                         "Fields outside _GRADE_INPUT_FIELDS must not affect determinism")

    def test_inputs_hash_is_64_char_sha256_hex(self):
        g = e01.grade_donor("X", row=B_TIER_ROW)
        self.assertEqual(len(g.inputs_hash), 64)
        # Confirm it's hex
        int(g.inputs_hash, 16)


if __name__ == "__main__":
    unittest.main()
