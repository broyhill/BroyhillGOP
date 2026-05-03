"""FEC: fundraising emails carry the 'paid for by' disclaimer."""
from __future__ import annotations
import sys, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / "ecosystems"))
import ecosystem_30_email as e30


class FecDisclaimerTest(unittest.TestCase):
    def test_fundraising_email_renders_paid_for_by(self):
        footer = e30.ComplianceFooter(
            sender_org_name="BroyhillGOP",
            physical_address="PO Box 1234, Raleigh, NC 27601",
            paid_for_by="Broyhill for State Auditor",
        )
        rendered = footer.render_html("don@example.com", "tok-X", is_fundraising=True)
        self.assertIn("Paid for by Broyhill for State Auditor", rendered)

    def test_non_fundraising_email_does_NOT_render_paid_for_by(self):
        footer = e30.ComplianceFooter(
            sender_org_name="BroyhillGOP",
            physical_address="PO Box 1234, Raleigh, NC 27601",
            paid_for_by="Broyhill for State Auditor",
        )
        rendered = footer.render_html("don@example.com", "tok-X", is_fundraising=False)
        self.assertNotIn("Paid for by", rendered)

    def test_validate_rejects_fundraising_without_paid_for_by(self):
        footer = e30.ComplianceFooter(
            sender_org_name="BroyhillGOP",
            physical_address="PO Box 1234, Raleigh, NC 27601",
            paid_for_by="Broyhill for State Auditor",
        )
        # Build a body that has the address+unsubscribe but NOT the 'paid for by'
        body = footer.render_html("x@example.com", "tok-X", is_fundraising=False)
        result = footer.validate_message(body, "tok-X", is_fundraising=True)
        self.assertFalse(result["compliant"])
        self.assertTrue(any("paid for by" in v.lower() for v in result["violations"]))

    def test_not_authorized_disclaimer_when_set(self):
        footer = e30.ComplianceFooter(
            sender_org_name="Independent Group",
            physical_address="PO Box 5555, Raleigh, NC 27601",
            paid_for_by="Independent Voters PAC",
            not_authorized_disclaimer=True,
        )
        rendered = footer.render_html("v@example.com", "tok-Y", is_fundraising=True)
        self.assertIn("Not authorized by any candidate", rendered)


if __name__ == "__main__":
    unittest.main()
