"""Test: DM-style sub-weapons honor Meta's 24-hour messaging window.

Meta's policy: businesses can DM a user for 24 hours after the user's last
inbound message, then they need a Message Tag (utility/account update/
post-purchase update) or it bounces.

E19 doesn't have an active DM sub-weapon in this PR (E19-Engage is STUBBED),
but the window-check function should exist so it's ready when E19-Engage builds.
"""
from __future__ import annotations
import sys, unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

import ecosystem_19_social_media as e19


def _within_24h_window(last_inbound_at: datetime, now: datetime) -> bool:
    """Reference implementation. Real impl will move into ecosystem_19_listening_inbox
    when E19-Engage builds. Test here pins the contract shape."""
    return (now - last_inbound_at) <= timedelta(hours=24)


class Meta24HourWindowTest(unittest.TestCase):
    def test_within_window_allows_send(self):
        now = datetime.now(timezone.utc)
        last_in = now - timedelta(hours=12)
        self.assertTrue(_within_24h_window(last_in, now))

    def test_at_24h_boundary_still_within(self):
        now = datetime.now(timezone.utc)
        last_in = now - timedelta(hours=24)
        self.assertTrue(_within_24h_window(last_in, now))

    def test_past_24h_blocked(self):
        now = datetime.now(timezone.utc)
        last_in = now - timedelta(hours=24, minutes=1)
        self.assertFalse(_within_24h_window(last_in, now))

    def test_e19_engage_is_stubbed(self):
        """The E19-Engage sub-weapon (DM automation) is STUBBED in this PR."""
        self.assertEqual(e19.SUB_WEAPONS_STATUS["E19-Engage"], "STUB")
        with self.assertRaises(NotImplementedError):
            e19._e19_engage_stub()


if __name__ == "__main__":
    unittest.main()
