"""Test: 90-min SLA from news event to approval queue."""
from __future__ import annotations
import sys, time, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

from ecosystem_19_news_trigger import (
    evaluate_news_event, NewsTriggerLoop, SLA_MINUTES,
)


class EvaluateNewsEventTest(unittest.TestCase):
    def test_high_urgency_always_goes(self):
        d = evaluate_news_event(
            {"urgency": "high", "issue_tags": ["random"], "event_type": "news.crisis_detected"},
            candidate_lanes=["healthcare"]
        )
        self.assertTrue(d["go"])
        self.assertEqual(d["reason"], "high_urgency")

    def test_lane_match_goes(self):
        d = evaluate_news_event(
            {"urgency": "med", "issue_tags": ["healthcare"],
             "event_type": "news.opponent_gaffe"},
            candidate_lanes=["healthcare", "border"]
        )
        self.assertTrue(d["go"])
        self.assertEqual(d["reason"], "lane_match")

    def test_off_lane_no_go(self):
        d = evaluate_news_event(
            {"urgency": "low", "issue_tags": ["climate"], "event_type": "news.positive_coverage"},
            candidate_lanes=["healthcare"]
        )
        self.assertFalse(d["go"])

    def test_trending_off_lane_blocked(self):
        d = evaluate_news_event(
            {"urgency": "med", "issue_tags": ["random_meme"],
             "event_type": "news.issue_trending"},
            candidate_lanes=["healthcare"]
        )
        self.assertFalse(d["go"])
        self.assertEqual(d["reason"], "off_lane_trending")


class NewsTriggerLoopSLATest(unittest.TestCase):
    def setUp(self):
        self.loop = NewsTriggerLoop(
            candidate_id="cand-1",
            candidate_lanes=["healthcare", "border", "broadband"],
            db_url="postgresql://fake",
        )

    def test_handle_event_meets_sla(self):
        captured = []
        def fake_submit(candidate_id, draft_id, payload):
            captured.append((candidate_id, draft_id, payload))
        result = self.loop.handle_event(
            {"event_id": "evt-1", "event_type": "news.opponent_gaffe",
             "headline": "Opponent flip-flops on broadband", "issue_tags": ["broadband"],
             "urgency": "med", "sentiment": "neg",
             "occurred_at": "2026-05-03T10:00:00Z"},
            submit_to_approval_queue=fake_submit,
        )
        self.assertEqual(result["decision"], "go")
        self.assertGreater(result["variants_count"], 0)
        # SLA: 90 minutes. Real generation should be <10s in tests.
        self.assertLess(result["sla_seconds"], 60.0,
                          "Variant generation should be sub-minute in tests")
        self.assertTrue(result["sla_within_window"])
        self.assertEqual(len(captured), 1, "submit_to_approval_queue must be called once")

    def test_off_lane_event_does_not_submit(self):
        captured = []
        def fake_submit(*args, **kw): captured.append(args)
        result = self.loop.handle_event(
            {"event_id": "evt-2", "event_type": "news.positive_coverage",
             "issue_tags": ["climate"], "urgency": "low",
             "headline": "Off-lane story",
             "occurred_at": "2026-05-03T10:00:00Z"},
            submit_to_approval_queue=fake_submit,
        )
        self.assertEqual(result["decision"], "no_go")
        self.assertEqual(captured, [])

    def test_sla_constant_is_90(self):
        self.assertEqual(SLA_MINUTES, 90)


if __name__ == "__main__":
    unittest.main()
