"""Test: inbound classification + AI draft + queue routing."""
from __future__ import annotations
import sys, unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

from ecosystem_19_listening_inbox import ListeningInbox, InboxRow


class InboxClassifierTest(unittest.TestCase):
    def setUp(self):
        self.inbox = ListeningInbox(candidate_id="cand-1",
                                      voice_profile={"first_name": "Dave",
                                                      "signature_phrase": "— Dave"})

    def test_classifies_question(self):
        c = self.inbox.classify("What is your position on healthcare?")
        self.assertEqual(c["intent"], "question")

    def test_classifies_praise(self):
        c = self.inbox.classify("Thank you for fighting for us! Spot on.")
        self.assertEqual(c["intent"], "praise")
        self.assertEqual(c["sentiment"], "pos")

    def test_classifies_complaint(self):
        c = self.inbox.classify("Disappointed in your stance. You should think again.")
        self.assertEqual(c["intent"], "complaint")
        self.assertEqual(c["sentiment"], "neg")

    def test_classifies_hostile(self):
        c = self.inbox.classify("You're a fraud and a moron")
        self.assertEqual(c["intent"], "hostile")
        self.assertEqual(c["sentiment"], "neg")

    def test_classifies_press(self):
        c = self.inbox.classify(
            "Hi, I'm a reporter at NYT working on a story. Press inquiry — deadline tomorrow."
        )
        self.assertEqual(c["intent"], "press")
        self.assertEqual(c["urgency"], "high")

    def test_classifies_donation_intent(self):
        c = self.inbox.classify("Where do I send a contribution? I want to donate.")
        self.assertEqual(c["intent"], "donation_intent")

    def test_classifies_spam(self):
        c = self.inbox.classify("Earn $5000 weekly! Free crypto guaranteed.")
        self.assertEqual(c["intent"], "spam")

    def test_high_urgency_keyword_bumps_urgency(self):
        c = self.inbox.classify("URGENT need a response right now")
        self.assertEqual(c["urgency"], "high")


class InboxRoutingTest(unittest.TestCase):
    def setUp(self):
        self.inbox = ListeningInbox(candidate_id="cand-1")

    def _route(self, content, **kw):
        cls = self.inbox.classify(content)
        row = InboxRow(content=content, **cls, **kw)
        return self.inbox.policy_routing(row)

    def test_question_routes_to_approval_queue(self):
        r = self._route("What is your stance?")
        self.assertEqual(r["action"], "queue_for_approval")
        self.assertEqual(r["target"], "E24")

    def test_press_routes_to_press_staff(self):
        r = self._route("Press inquiry — deadline tomorrow")
        self.assertEqual(r["action"], "route_to_press")

    def test_hostile_default_mutes(self):
        r = self._route("You moron", source_user_id="user-X")
        self.assertEqual(r["action"], "mute")
        self.assertEqual(r["target"], "user-X")

    def test_hostile_threat_blocks(self):
        r = self._route("kill yourself", source_user_id="user-Y")
        self.assertEqual(r["action"], "block")

    def test_spam_ignored(self):
        r = self._route("Earn $5000 weekly free crypto")
        self.assertEqual(r["action"], "ignore")

    def test_engage_with_hostile_policy_overrides(self):
        inbox = ListeningInbox(candidate_id="cand-1",
                                candidate_policy={"engage_with_hostile": True})
        cls = inbox.classify("You moron")
        row = InboxRow(content="You moron", **cls, source_user_id="user-X")
        r = inbox.policy_routing(row)
        self.assertEqual(r["action"], "queue_for_approval")


class InboxIngestTest(unittest.TestCase):
    def setUp(self):
        self.inbox = ListeningInbox(candidate_id="cand-1",
                                      voice_profile={"first_name": "Dave",
                                                      "signature_phrase": "— Dave"})
        # Suppress DB persist
        self._patcher = patch.object(self.inbox, "_persist")
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_ingest_question_drafts_reply_and_queues(self):
        captured = []
        def fake_submit(*args): captured.append(args)
        row = self.inbox.ingest("x", "comment", "What is your healthcare plan?",
                                  source_user_id="u1",
                                  submit_to_approval_queue=fake_submit)
        self.assertEqual(row.intent, "question")
        self.assertIsNotNone(row.ai_draft_reply)
        self.assertIn("— Dave", row.ai_draft_reply)
        self.assertEqual(len(captured), 1)

    def test_ingest_hostile_does_not_draft_or_queue(self):
        captured = []
        def fake_submit(*args): captured.append(args)
        row = self.inbox.ingest("x", "comment", "you're a moron",
                                  source_user_id="u2",
                                  submit_to_approval_queue=fake_submit)
        self.assertEqual(row.intent, "hostile")
        self.assertEqual(captured, [])  # nothing queued

    def test_ingest_press_marks_for_internal_routing(self):
        captured = []
        def fake_submit(*args): captured.append(args)
        row = self.inbox.ingest("x", "dm", "Press inquiry — deadline tomorrow",
                                  submit_to_approval_queue=fake_submit)
        self.assertEqual(row.intent, "press")
        # Press goes to comms staff — NOT through E24 approval queue
        self.assertEqual(captured, [])


if __name__ == "__main__":
    unittest.main()
