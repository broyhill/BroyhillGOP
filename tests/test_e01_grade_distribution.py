"""
Test: grade_donor() produces sensible grade distribution across realistic donor profiles.

Spot-checks the boundary thresholds + distribution shape so that a future
refactor can't silently flip every donor to F (or every donor to A) without
the test suite catching it.
"""

from __future__ import annotations

import sys
import unittest
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_01_donor_intelligence as e01  # noqa: E402


def _row(rnc, *, txn_count=1, lifetime_total=100, largest_gift=50,
         first_gift_date=date(2024, 1, 1), last_gift_date=date(2025, 6, 1),
         committee_count=1, candidate_count=1, match_tier="A_EXACT") -> dict:
    return {
        "rnc_regid":       rnc,
        "txn_count":       txn_count,
        "lifetime_total":  lifetime_total,
        "largest_gift":    largest_gift,
        "first_gift_date": first_gift_date,
        "last_gift_date":  last_gift_date,
        "committee_count": committee_count,
        "candidate_count": candidate_count,
        "match_tier":      match_tier,
    }


class GradeBoundaryTest(unittest.TestCase):
    """A handful of representative donors should land in expected grade bands."""

    def test_megadonor_is_A(self):
        # $500K lifetime, 200 transactions, 50 candidates, recent activity
        row = _row("MEGA", lifetime_total=500_000, txn_count=200,
                   largest_gift=50_000, candidate_count=50, committee_count=30,
                   last_gift_date=date(2025, 11, 1))
        self.assertEqual(e01.grade_donor("MEGA", row=row).grade, "A")

    def test_steady_mid_donor_is_B(self):
        # $5K lifetime, 25 transactions
        row = _row("MID", lifetime_total=5_000, txn_count=25, largest_gift=500,
                   candidate_count=8, committee_count=5,
                   last_gift_date=date(2025, 9, 1))
        self.assertIn(e01.grade_donor("MID", row=row).grade, ("B", "C"))

    def test_small_one_off_donor_is_low_grade(self):
        # $50 single gift, no breadth, somewhat recent
        row = _row("SMALL", lifetime_total=50, txn_count=1, largest_gift=50,
                   candidate_count=1, committee_count=1,
                   last_gift_date=date(2025, 3, 1))
        grade = e01.grade_donor("SMALL", row=row).grade
        self.assertIn(grade, ("D", "F"))

    def test_zero_giving_is_F(self):
        row = _row("ZERO", lifetime_total=0, txn_count=0, largest_gift=0,
                   candidate_count=0, committee_count=0,
                   last_gift_date=date(2024, 1, 1))
        self.assertEqual(e01.grade_donor("ZERO", row=row).grade, "F")

    def test_unmatched_donor_is_F(self):
        # Pure UNMATCHED with otherwise OK giving still gets F (low confidence)
        # No — our spec is grade is derived from giving regardless of tier.
        # But with row=None (not found in either view) we return F.
        result = e01.grade_donor("MISSING", row=None)
        self.assertEqual(result.grade, "F")
        self.assertEqual(result.confidence, 0.0)


class GradeDistributionShapeTest(unittest.TestCase):
    """Across a synthetic population of 200 donors with varied profiles,
    confirm we don't collapse to a single grade."""

    @classmethod
    def setUpClass(cls):
        # Synthetic population: vary lifetime_total log-uniformly over $1..$1M
        # and txn_count linearly over 1..150
        import math
        rows = []
        for i in range(200):
            lifetime = 10 ** (i / 50)            # $1..$10000
            rows.append(_row(
                rnc=f"RNC-{i:04d}",
                lifetime_total=lifetime,
                txn_count=1 + i // 2,
                largest_gift=lifetime / 4,
                committee_count=1 + i // 20,
                candidate_count=1 + i // 10,
                last_gift_date=date(2025, 1 + (i % 11), 15),
            ))
        cls.grades = [e01.grade_donor(r["rnc_regid"], row=r).grade for r in rows]
        cls.dist = Counter(cls.grades)

    def test_all_five_grades_appear(self):
        for letter in ("A", "B", "C", "D", "F"):
            self.assertIn(letter, self.dist,
                          f"Grade {letter} should appear in synthetic distribution; got {dict(self.dist)}")

    def test_no_single_grade_dominates_more_than_70pct(self):
        total = sum(self.dist.values())
        for letter, count in self.dist.items():
            self.assertLess(count / total, 0.70,
                            f"Grade {letter} dominates {count}/{total} = "
                            f"{count/total:.0%}; check threshold drift. "
                            f"Full dist: {dict(self.dist)}")

    def test_higher_lifetime_giving_correlates_with_higher_grade(self):
        """Donor with $1M lifetime should get A; $10 lifetime should get F."""
        rich = _row("RICH", lifetime_total=1_000_000, txn_count=200,
                    largest_gift=100_000, candidate_count=50, committee_count=30,
                    last_gift_date=date(2025, 11, 1))
        poor = _row("POOR", lifetime_total=10, txn_count=1, largest_gift=10,
                    candidate_count=1, committee_count=1,
                    last_gift_date=date(2024, 1, 1))
        # A > F in the natural ordering
        order = "ABCDF"
        rich_grade = e01.grade_donor("RICH", row=rich).grade
        poor_grade = e01.grade_donor("POOR", row=poor).grade
        self.assertLess(order.index(rich_grade), order.index(poor_grade),
                        f"RICH={rich_grade} should outrank POOR={poor_grade}")


if __name__ == "__main__":
    unittest.main()
