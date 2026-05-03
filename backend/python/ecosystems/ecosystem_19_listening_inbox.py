#!/usr/bin/env python3
"""
ECOSYSTEM 19 — Listening Inbox

Receives inbound messages from all 5 platforms (FB, IG, X, LinkedIn, TikTok) —
comments, mentions, quote-tweets, and DMs. Classifies sentiment + intent +
urgency. Drafts a reply using the candidate's voice profile (from E48).
Routes to E24 approval queue OR to comms staff (press) OR to mute/block
(hostile).

Public API:
  ListeningInbox(candidate_id, ...).ingest(platform, source_type, ...)
  ListeningInbox.classify(message_text) -> dict
  ListeningInbox.draft_reply(inbox_row) -> str
  ListeningInbox.policy_routing(inbox_row) -> dict
"""
from __future__ import annotations

import logging
import os
import re
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional, Sequence

import psycopg2
from psycopg2.extras import RealDictCursor, Json

logger = logging.getLogger("ecosystem19.listening_inbox")


# ============================================================================
# Classifier — heuristic stub (real impl uses Claude via prompt)
#
# The classifier returns sentiment, intent, urgency. Heuristics are intentionally
# transparent so tests can assert behavior. Production wires to an LLM.
# ============================================================================

_HOSTILE_PATTERNS = [
    r"\b(fuck|shit|bitch|asshole|moron|idiot|retard|scumbag)\b",
    r"\b(kill yourself|kys|drop dead)\b",
    r"\b(traitor|fraud|liar)\b",
]
_SPAM_PATTERNS = [
    r"\b(free crypto|guaranteed return|click here for|earn \$\d+)\b",
    r"https?://[^\s]+\.(ru|tk|ml|cn)/",
]
_PRESS_KEYWORDS = [
    "press inquiry", "media request", "for comment", "deadline", "story i'm working on",
    "reporting on", "fact check",
]
_QUESTION_INDICATORS = ["?", "what is", "how do", "why does", "when will",
                         "where can", "can you explain"]
_PRAISE_INDICATORS = ["thank you", "thanks", "great job", "amazing", "love it",
                       "well said", "spot on", "true that"]
_COMPLAINT_INDICATORS = ["disappointed", "frustrated", "wrong about",
                          "doesn't make sense", "you should", "stop", "won't vote"]
_DONATION_INTENT_INDICATORS = ["donate", "contribute", "give to", "support financially",
                                 "where do I send"]
_URGENCY_HIGH = ["breaking", "urgent", "today", "right now", "asap", "deadline"]


def _matches_any(text: str, patterns: Sequence[str]) -> bool:
    lower = text.lower()
    return any(re.search(p, lower) for p in patterns)


def _contains_any(text: str, indicators: Sequence[str]) -> bool:
    lower = text.lower()
    return any(ind in lower for ind in indicators)


# ============================================================================
# Inbox row dataclass
# ============================================================================

@dataclass
class InboxRow:
    inbox_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    platform: str = ""
    source_type: str = "comment"
    source_user_id: Optional[str] = None
    rnc_regid: Optional[str] = None
    content: str = ""
    sentiment: Optional[str] = None
    intent: Optional[str] = None
    urgency: Optional[str] = None
    ai_draft_reply: Optional[str] = None
    approval_status: str = "pending"
    created_at: datetime = field(default_factory=datetime.utcnow)


# ============================================================================
# ListeningInbox
# ============================================================================

class ListeningInbox:
    """Inbound listener. One per candidate."""

    def __init__(self, candidate_id: str,
                  voice_profile: Optional[dict] = None,
                  candidate_policy: Optional[dict] = None,
                  db_url: Optional[str] = None):
        self.candidate_id = candidate_id
        self.voice_profile = voice_profile or {}
        # candidate_policy carries flags like {"engage_with_hostile": False}
        self.candidate_policy = candidate_policy or {"engage_with_hostile": False}
        self.db_url = db_url or os.getenv("DATABASE_URL",
                                           "postgresql://localhost/broyhillgop")

    # ------------------------------------------------------------------
    # Classification (pure function — no DB)
    # ------------------------------------------------------------------

    def classify(self, message_text: str) -> dict:
        """Return {sentiment, intent, urgency} for the message text.

        Order matters: hostile/spam beat all other intents (defensive).
        """
        text = message_text or ""
        # Sentiment
        sentiment = "neutral"
        if _matches_any(text, _HOSTILE_PATTERNS):
            sentiment = "neg"
        elif _contains_any(text, _PRAISE_INDICATORS):
            sentiment = "pos"
        elif _contains_any(text, _COMPLAINT_INDICATORS):
            sentiment = "neg"
        # Intent — order matters
        if _matches_any(text, _SPAM_PATTERNS):
            intent = "spam"
        elif _matches_any(text, _HOSTILE_PATTERNS):
            intent = "hostile"
        elif _contains_any(text, _PRESS_KEYWORDS):
            intent = "press"
        elif _contains_any(text, _DONATION_INTENT_INDICATORS):
            intent = "donation_intent"
        elif _contains_any(text, _PRAISE_INDICATORS):
            intent = "praise"
        elif _contains_any(text, _COMPLAINT_INDICATORS):
            intent = "complaint"
        elif _contains_any(text, _QUESTION_INDICATORS):
            intent = "question"
        else:
            intent = "question"  # default — better to err on side of "human staff should look"
        # Urgency
        if _contains_any(text, _URGENCY_HIGH) or intent == "press":
            urgency = "high"
        elif intent in ("hostile", "complaint"):
            urgency = "med"
        else:
            urgency = "low"
        return {"sentiment": sentiment, "intent": intent, "urgency": urgency}

    # ------------------------------------------------------------------
    # AI reply drafter — real impl calls Claude with voice profile in prompt.
    # Stub returns a deterministic, voice-flavored response by intent.
    # ------------------------------------------------------------------

    def draft_reply(self, row: InboxRow) -> str:
        """Draft a reply for the inbound row using the candidate's voice."""
        candidate_first = self.voice_profile.get("first_name", "the candidate")
        signature = self.voice_profile.get("signature_phrase", "Thanks for reaching out.")
        if row.intent == "question":
            return (f"Good question. Here's where I stand on this: "
                    f"<<TODO: factual answer drawn from candidate's positions>>. "
                    f"{signature}")
        if row.intent == "praise":
            return f"Thanks for the support — it means a lot. {signature}"
        if row.intent == "complaint":
            return (f"I hear you. Let me address this directly: "
                    f"<<TODO: address the specific complaint>>. {signature}")
        if row.intent == "donation_intent":
            return (f"Thank you — every contribution helps. "
                    f"You can donate at <<DONATION_URL>>. {signature}")
        if row.intent == "press":
            return ("PRESS HOLD — auto-routed to comms staff; do not reply publicly. "
                    "Response will come from press@broyhillgop.")
        # hostile / spam never get auto-drafted public replies
        return ""

    # ------------------------------------------------------------------
    # Policy routing — what to do with each row
    # ------------------------------------------------------------------

    def policy_routing(self, row: InboxRow) -> dict:
        """Decide what to do: queue for approval, route to press, mute, or block.

        Returns {"action": str, "target": str} where action ∈
            queue_for_approval | route_to_press | mute | block | ignore
        """
        if row.intent == "spam":
            return {"action": "ignore", "target": "drop"}
        if row.intent == "hostile":
            if self.candidate_policy.get("engage_with_hostile", False):
                return {"action": "queue_for_approval", "target": "E24"}
            # Default: mute (hide on platform). Block only on repeat or threat.
            if any(kw in row.content.lower()
                   for kw in ("kill yourself", "kys", "drop dead")):
                return {"action": "block", "target": row.source_user_id}
            return {"action": "mute", "target": row.source_user_id}
        if row.intent == "press":
            return {"action": "route_to_press", "target": "comms_staff"}
        # praise, complaint, question, donation_intent → AI draft → queue for approval
        return {"action": "queue_for_approval", "target": "E24"}

    # ------------------------------------------------------------------
    # Ingest path — combines classify + draft + persist + route
    # ------------------------------------------------------------------

    def ingest(self, platform: str, source_type: str,
                content: str, source_user_id: Optional[str] = None,
                rnc_regid: Optional[str] = None,
                submit_to_approval_queue=None) -> InboxRow:
        """Full ingest. Returns the persisted InboxRow with classification + draft.

        `submit_to_approval_queue` is a callable injected for testing — in
        production it's the real E24 client.
        """
        cls = self.classify(content)
        row = InboxRow(
            platform=platform, source_type=source_type, content=content,
            source_user_id=source_user_id, rnc_regid=rnc_regid,
            sentiment=cls["sentiment"], intent=cls["intent"], urgency=cls["urgency"],
        )
        # Draft (skipped for hostile/spam/press)
        if row.intent not in ("hostile", "spam", "press"):
            row.ai_draft_reply = self.draft_reply(row)
        elif row.intent == "press":
            row.ai_draft_reply = self.draft_reply(row)  # internal note
        routing = self.policy_routing(row)
        if routing["action"] == "queue_for_approval" and submit_to_approval_queue:
            submit_to_approval_queue(self.candidate_id, row.inbox_id,
                                      {"draft_reply": row.ai_draft_reply,
                                       "platform": row.platform,
                                       "source_type": row.source_type,
                                       "intent": row.intent,
                                       "urgency": row.urgency})
        # Persist (best-effort; failure logged but not raised)
        self._persist(row)
        logger.info(
            f"listening_inbox.ingest platform={platform} intent={row.intent} "
            f"urgency={row.urgency} action={routing['action']}"
        )
        return row

    def _persist(self, row: InboxRow) -> None:
        try:
            conn = psycopg2.connect(self.db_url)
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "INSERT INTO core.e19_inbox "
                        "    (inbox_id, platform, source_type, source_user_id, "
                        "     rnc_regid, content, sentiment, intent, urgency, "
                        "     ai_draft_reply, approval_status) "
                        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                        (row.inbox_id, row.platform, row.source_type,
                         row.source_user_id, row.rnc_regid, row.content,
                         row.sentiment, row.intent, row.urgency,
                         row.ai_draft_reply, row.approval_status),
                    )
                conn.commit()
            finally:
                conn.close()
        except Exception as e:
            logger.warning(f"listening_inbox.persist failed (non-fatal): {e}")


__all__ = ["InboxRow", "ListeningInbox"]
