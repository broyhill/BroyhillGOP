#!/usr/bin/env python3
"""
ECOSYSTEM 19 — News-Trigger Loop

Subscribes to E42 News Intelligence event bus. When a story breaks matching
the candidate's issue lanes, generates 5 ranked response variants within a
90-minute SLA, posts to E24 approval queue, and on approval bandit-picks the
optimal time + platform to fire.

Public API:
  evaluate_news_event(event, candidate_lanes) -> {go: bool, reason: str}
  NewsTriggerLoop(candidate_id, ...).handle_event(event) -> dict
  NewsTriggerLoop.on_approval(approval_id, post_payload) -> dict
"""
from __future__ import annotations

import logging
import os
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Sequence

import psycopg2
from psycopg2.extras import RealDictCursor, Json

logger = logging.getLogger("ecosystem19.news_trigger")

# Lazy local import to avoid hard dependency at module load
try:
    from ecosystems.ecosystem_19_content_optimizer import (
        generate_hook as _generate_hook, rank_variants as _rank_variants,
        CadenceBandit as _CadenceBandit,
    )
except ImportError:  # pragma: no cover
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from ecosystem_19_content_optimizer import (
        generate_hook as _generate_hook, rank_variants as _rank_variants,
        CadenceBandit as _CadenceBandit,
    )


# Hard SLA per spec: 90 minutes from event to approval queue.
SLA_MINUTES = 90


# ============================================================================
# Event evaluation (go/no-go decision)
# ============================================================================

def evaluate_news_event(event: dict, candidate_lanes: Sequence[str]) -> dict:
    """Decide go/no-go on a news event based on the candidate's issue lanes.

    `event` shape (from E42):
      {
          "event_id": "...",
          "event_type": "news.crisis_detected" | "news.opponent_gaffe" |
                         "news.endorsement_coverage" | "news.positive_coverage" |
                         "news.issue_trending",
          "issue_tags": ["healthcare", "border", ...],
          "sentiment": "pos" | "neg" | "neutral",
          "urgency": "low" | "med" | "high",
          "headline": "...",
          "summary": "...",
          "source_url": "...",
          "occurred_at": "ISO-8601",
      }
    `candidate_lanes` is the list of issue-tags the candidate has explicitly
    chosen to engage on (from candidate-preferences).

    Returns {"go": True, "reason": "lane_match"} or
            {"go": False, "reason": "off_lane" | "stale" | "low_urgency_off_topic"}
    """
    if event.get("urgency") == "high":
        # High-urgency always at least gets a draft for approval; staff decide.
        return {"go": True, "reason": "high_urgency"}
    issue_tags = set(event.get("issue_tags", []))
    lanes = set(candidate_lanes)
    if issue_tags & lanes:
        return {"go": True, "reason": "lane_match"}
    # Trending hashtag harvester rule: don't ride a trend that's not authentic
    # to the candidate's positions. Unless URGENT, off-lane = no-go.
    if event.get("event_type") == "news.issue_trending":
        return {"go": False, "reason": "off_lane_trending"}
    return {"go": False, "reason": "off_lane"}


# ============================================================================
# NewsTriggerLoop — the 90-min SLA orchestrator
# ============================================================================

@dataclass
class _PendingDraft:
    draft_id: str
    event_id: str
    candidate_id: str
    variants: List[dict] = field(default_factory=list)
    submitted_to_queue_at: Optional[datetime] = None
    approval_status: str = "pending"


class NewsTriggerLoop:
    """Orchestrates the 90-min SLA from event to approval queue to fire."""

    def __init__(self, candidate_id: str, candidate_lanes: Sequence[str],
                  voice_profile: Optional[dict] = None,
                  db_url: Optional[str] = None):
        self.candidate_id = candidate_id
        self.candidate_lanes = list(candidate_lanes)
        self.voice_profile = voice_profile or {}
        self.db_url = db_url or os.getenv("DATABASE_URL",
                                           "postgresql://localhost/broyhillgop")
        self.cadence = _CadenceBandit(db_url=self.db_url)

    def handle_event(self, event: dict,
                      submit_to_approval_queue=None) -> dict:
        """Main entry point. Generates 5 ranked variants and posts to E24.

        `submit_to_approval_queue` is a callable injected for testing — in
        production it's the real E24 client. Called as
        submit_to_approval_queue(candidate_id, draft_id, variants_payload).

        Returns a dict with: {decision, draft_id (if go), variants_count, sla_seconds}.
        """
        start = time.monotonic()
        decision = evaluate_news_event(event, self.candidate_lanes)
        if not decision["go"]:
            return {"decision": "no_go", "reason": decision["reason"],
                    "sla_seconds": time.monotonic() - start}

        draft_id = str(uuid.uuid4())
        # Build a content brief for the hook generator
        brief = {
            "topic": event.get("headline", "current event"),
            "audience": event.get("target_audience", "voters"),
            "verbs": ["respond", "address", "speak to"],
            "nouns": event.get("issue_tags", ["the issue"]),
            "benefits": ["set the record straight", "tell the truth", "lead"],
        }
        # Generate variants per platform — 5 per platform target
        variants_payload: List[dict] = []
        for platform in ("meta_fb", "x", "tiktok", "linkedin", "meta_ig"):
            hooks = _generate_hook(brief, platform, count_range=(20, 30))
            ranked = _rank_variants(hooks, platform)[:5]
            for r in ranked:
                variants_payload.append({
                    "variant_id": r.variant_id,
                    "platform": platform,
                    "text": r.text,
                    "score": round(r.score, 4),
                    "components": r.components,
                })
        # Submit to approval queue (E24)
        if submit_to_approval_queue is not None:
            submit_to_approval_queue(self.candidate_id, draft_id,
                                      {"event_id": event.get("event_id"),
                                       "variants": variants_payload})
        sla_seconds = time.monotonic() - start
        sla_within = (sla_seconds / 60.0) <= SLA_MINUTES
        logger.info(
            f"NewsTriggerLoop.handle_event draft={draft_id} variants={len(variants_payload)} "
            f"sla_seconds={sla_seconds:.2f} within_sla={sla_within}"
        )
        return {
            "decision": "go", "draft_id": draft_id,
            "variants_count": len(variants_payload),
            "sla_seconds": sla_seconds,
            "sla_within_window": sla_within,
        }

    def on_approval(self, approval_id: str, draft: _PendingDraft,
                     publish=None) -> dict:
        """Called when E24 returns an approval. Bandit-picks platform + time, fires.

        `publish` is a callable injected for testing — in production it's the
        platform publisher. Called as publish(platform, post_text, scheduled_at).
        """
        if not draft.variants:
            return {"fired": False, "reason": "no_variants"}
        # Pick top-ranked variant per platform (already ranked at draft time)
        per_platform_top = {}
        for v in draft.variants:
            p = v["platform"]
            if p not in per_platform_top or v["score"] > per_platform_top[p]["score"]:
                per_platform_top[p] = v
        scheduled = []
        for platform, variant in per_platform_top.items():
            target_time = self.cadence.recommend_post_time(self.candidate_id, platform)
            if publish is not None:
                publish(platform, variant["text"], target_time, variant["variant_id"])
            scheduled.append({"platform": platform,
                               "variant_id": variant["variant_id"],
                               "scheduled_at": target_time.isoformat()})
        return {"fired": True, "scheduled": scheduled}


__all__ = ["evaluate_news_event", "NewsTriggerLoop", "SLA_MINUTES"]
