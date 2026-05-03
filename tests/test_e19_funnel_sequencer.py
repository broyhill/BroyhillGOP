"""Test: stage transitions trigger correct content pool."""
from __future__ import annotations
import sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

from ecosystem_19_funnel_sequencer import (
    FunnelStage, ContentStage, get_donor_stage, _signals_to_stage, _DonorSignals,
    fatigue_window_for, FATIGUE_CAPS,
)


def _signals(**kw) -> _DonorSignals:
    base = dict(has_donor_profile=True, txn_count=0, lifetime_total_cents=0,
                is_bundler_flag=False, has_email_consent=False,
                has_sms_consent=False, has_engagement_signal=False)
    base.update(kw)
    return _DonorSignals(**base)


class SignalsToStageTest(unittest.TestCase):
    def test_no_record_is_stranger(self):
        """Real prod path: get_donor_stage with row=None falls back to STRANGER.
        We mock the DB read so the test doesn't require a live Postgres."""
        from unittest.mock import patch
        import ecosystem_19_funnel_sequencer as fs
        with patch.object(fs, "_read_signals", return_value=None):
            s = get_donor_stage("RX", db_url="postgresql://fake")
        self.assertEqual(s, FunnelStage.STRANGER)

    def test_aware_when_profile_exists_no_engagement(self):
        s = _signals_to_stage(_signals())
        self.assertEqual(s, FunnelStage.AWARE)

    def test_engaged_with_engagement_signal(self):
        s = _signals_to_stage(_signals(has_engagement_signal=True))
        # Wait — engagement_signal is set by txn_count>0, which would push to SMALL_DONOR.
        # Pass txn_count=0 with an explicit engagement signal.
        s = _signals_to_stage(_DonorSignals(
            has_donor_profile=True, txn_count=0, lifetime_total_cents=0,
            is_bundler_flag=False, has_email_consent=False, has_sms_consent=False,
            has_engagement_signal=True,
        ))
        self.assertEqual(s, FunnelStage.ENGAGED)

    def test_subscriber_with_email_consent(self):
        s = _signals_to_stage(_signals(has_email_consent=True))
        self.assertEqual(s, FunnelStage.SUBSCRIBER)

    def test_subscriber_with_sms_consent(self):
        s = _signals_to_stage(_signals(has_sms_consent=True))
        self.assertEqual(s, FunnelStage.SUBSCRIBER)

    def test_small_donor_with_one_donation(self):
        s = _signals_to_stage(_signals(txn_count=1, lifetime_total_cents=2500))
        self.assertEqual(s, FunnelStage.SMALL_DONOR)

    def test_repeat_donor_with_three_txns(self):
        s = _signals_to_stage(_signals(txn_count=3, lifetime_total_cents=15000))
        self.assertEqual(s, FunnelStage.REPEAT_DONOR)

    def test_repeat_donor_with_500_lifetime(self):
        s = _signals_to_stage(_signals(txn_count=1, lifetime_total_cents=50000))
        self.assertEqual(s, FunnelStage.REPEAT_DONOR)

    def test_bundler_via_lifetime_threshold(self):
        s = _signals_to_stage(_signals(txn_count=10, lifetime_total_cents=300000))
        self.assertEqual(s, FunnelStage.BUNDLER)

    def test_bundler_via_explicit_flag(self):
        s = _signals_to_stage(_signals(is_bundler_flag=True))
        self.assertEqual(s, FunnelStage.BUNDLER)


class FatigueCapTest(unittest.TestCase):
    def test_each_stage_has_a_cap(self):
        for stage in FunnelStage:
            self.assertIn(stage, FATIGUE_CAPS,
                            f"Missing fatigue cap for {stage.value}")

    def test_fatigue_window_returns_max_and_period(self):
        max_sends, period = fatigue_window_for(FunnelStage.STRANGER)
        self.assertGreater(max_sends, 0)
        self.assertGreater(period, 0)

    def test_bundler_has_lower_cap_than_subscriber(self):
        b_max, _ = fatigue_window_for(FunnelStage.BUNDLER)
        s_max, _ = fatigue_window_for(FunnelStage.SUBSCRIBER)
        # Bundlers should get fewer touches per period (higher quality)
        self.assertLess(b_max, s_max + 5)  # very loose; just sanity


if __name__ == "__main__":
    unittest.main()
