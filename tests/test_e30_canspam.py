"""CAN-SPAM: every outbound has footer (physical address + unsubscribe + sender ID)."""
from __future__ import annotations
import sys, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / "ecosystems"))
import ecosystem_30_email as e30


class CanSpamFooterTest(unittest.TestCase):
    def setUp(self):
        self.footer = e30.ComplianceFooter(
            sender_org_name="BroyhillGOP",
            physical_address="PO Box 1234, Raleigh, NC 27601",
        )

    def test_footer_includes_physical_address(self):
        rendered = self.footer.render_html("test@example.com", "tok123")
        self.assertIn("PO Box 1234, Raleigh, NC 27601", rendered)

    def test_footer_includes_sender_org_name(self):
        rendered = self.footer.render_html("test@example.com", "tok123")
        self.assertIn("BroyhillGOP", rendered)

    def test_footer_includes_unsubscribe_link(self):
        rendered = self.footer.render_html("test@example.com", "tok123")
        self.assertIn("Unsubscribe", rendered)
        self.assertIn("tok123", rendered)  # token in URL

    def test_validate_message_rejects_missing_address(self):
        body = "<p>Donate now!</p><p>Unsubscribe link here</p>"  # no address
        result = self.footer.validate_message(body, "tok123", is_fundraising=True)
        self.assertFalse(result["compliant"])
        self.assertTrue(any("address" in v.lower() for v in result["violations"]))

    def test_validate_message_rejects_missing_unsubscribe(self):
        body = "<p>Hi from BroyhillGOP, PO Box 1234, Raleigh, NC 27601.</p>"
        result = self.footer.validate_message(body, "tok123", is_fundraising=False)
        self.assertFalse(result["compliant"])

    def test_validate_message_passes_compliant_body(self):
        body = self.footer.render_html("test@example.com", "tok123")
        result = self.footer.validate_message(body, "tok123", is_fundraising=False)
        self.assertTrue(result["compliant"], f"violations={result['violations']}")

    def test_constructor_rejects_empty_address(self):
        with self.assertRaises(ValueError):
            e30.ComplianceFooter("BroyhillGOP", "")

    def test_constructor_rejects_short_address(self):
        with self.assertRaises(ValueError):
            e30.ComplianceFooter("BroyhillGOP", "PO Box 1")  # too short


if __name__ == "__main__":
    unittest.main()
