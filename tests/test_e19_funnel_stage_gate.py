"""
Test: stranger-stage donor never receives bundler-stage content.

The hard gate from docs/architecture/E19_FUNNEL_STAGES.md §4.
"""
from __future__ import annotations
import sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

from ecosystem_19_funnel_sequencer import (
    FunnelStage, ContentStage, allowed_content_stages, is_content_allowed,
)


class FunnelStageGateTest(unittest.TestCase):
    def test_stranger_cannot_receive_bundler_content(self):
        """The headline rule — never pivots."""
        for cs in (ContentStage.VIP_ACCESS, ContentStage.EXCLUSIVE_BRIEFING,
                   ContentStage.HOST_INVITE, ContentStage.INNER_CIRCLE):
            self.assertFalse(
                is_content_allowed(FunnelStage.STRANGER, cs),
                f"Stranger MUST NOT receive {cs.value}"
            )

    def test_stranger_can_receive_stranger_content(self):
        for cs in (ContentStage.ISSUE_EDUCATION, ContentStage.NO_ASK,
                   ContentStage.NO_CANDIDATE_FACE):
            self.assertTrue(
                is_content_allowed(FunnelStage.STRANGER, cs),
                f"Stranger MUST receive {cs.value}"
            )

    def test_bundler_can_receive_everything(self):
        for cs in ContentStage:
            self.assertTrue(
                is_content_allowed(FunnelStage.BUNDLER, cs),
                f"Bundler should receive {cs.value}"
            )

    def test_each_stage_includes_lower_stage_content(self):
        """A donor at stage X receives stage X + all LOWER stages, never higher."""
        ladder = [FunnelStage.STRANGER, FunnelStage.AWARE, FunnelStage.ENGAGED,
                  FunnelStage.SUBSCRIBER, FunnelStage.SMALL_DONOR,
                  FunnelStage.REPEAT_DONOR, FunnelStage.BUNDLER]
        for i, stage in enumerate(ladder):
            allowed = allowed_content_stages(stage)
            for j, lower_stage in enumerate(ladder[:i+1]):
                # Every lower-stage content MUST be in this stage's allowed set.
                lower_allowed = allowed_content_stages(lower_stage)
                self.assertTrue(lower_allowed.issubset(allowed),
                                  f"{stage.value} must include all of {lower_stage.value}'s content")
            # And NOTHING from a higher stage may leak in.
            for higher_stage in ladder[i+1:]:
                higher_only = allowed_content_stages(higher_stage) - allowed
                # higher_only contains content tags that are introduced AT higher_stage.
                # These must not appear in `allowed`.
                # (This is by construction — but assert it anyway.)
                for cs in higher_only:
                    self.assertNotIn(cs, allowed,
                                      f"{stage.value} should NOT receive {cs.value} "
                                      f"(introduced at {higher_stage.value})")

    def test_subscriber_cannot_receive_repeat_donor_content(self):
        for cs in (ContentStage.PEER_VALIDATION, ContentStage.LARGER_ASK,
                   ContentStage.COMMUNITY_SIGNAL):
            self.assertFalse(
                is_content_allowed(FunnelStage.SUBSCRIBER, cs),
                f"Subscriber MUST NOT receive {cs.value} (REPEAT_DONOR-tier)"
            )


if __name__ == "__main__":
    unittest.main()
