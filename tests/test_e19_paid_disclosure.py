"""Test: paid posts carry FEC paid-for-by disclaimer."""
from __future__ import annotations
import sys, unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_19_social_media as e19


class FECPaidDisclosureTest(unittest.TestCase):
    def setUp(self):
        # Suppress DB writes from compliance audit logging
        self._patcher = patch.object(e19, "_log_compliance_decision")
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_organic_post_skips_gate(self):
        result = e19.check_fec_paid_for_by({"is_paid": False, "body": "Hello"})
        self.assertTrue(result["allow"])
        self.assertEqual(result["reason"], "organic_skip")

    def test_paid_post_without_disclaimer_blocked(self):
        result = e19.check_fec_paid_for_by({"is_paid": True, "body": "Donate now!"})
        self.assertFalse(result["allow"])
        self.assertEqual(result["reason"], "fec_disclaimer_missing")

    def test_paid_post_with_disclaimer_in_body_allowed(self):
        result = e19.check_fec_paid_for_by({
            "is_paid": True,
            "body": "Vote Tuesday! Paid for by Broyhill for State Auditor.",
        })
        self.assertTrue(result["allow"])

    def test_paid_post_with_disclaimer_in_separate_field_allowed(self):
        result = e19.check_fec_paid_for_by({
            "is_paid": True,
            "body": "Vote Tuesday!",
            "disclaimer": "Paid for by Broyhill for State Auditor",
        })
        self.assertTrue(result["allow"])

    def test_disclaimer_check_is_case_insensitive(self):
        result = e19.check_fec_paid_for_by({
            "is_paid": True,
            "body": "Vote Tuesday! PAID FOR BY Broyhill for State Auditor.",
        })
        self.assertTrue(result["allow"])


if __name__ == "__main__":
    unittest.main()
