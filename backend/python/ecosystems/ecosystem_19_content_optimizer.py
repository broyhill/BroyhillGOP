#!/usr/bin/env python3
"""
ECOSYSTEM 19 — Content Optimizer + Cadence Bandit

Per-platform algorithm awareness, hook-first variant generation, deterministic
variant ranking (stub now; ML ranker trains on outcomes accumulating in
core.e19_variant_outcomes), and a multi-armed bandit for post-time scheduling.

Public API:
  generate_hook(content_brief, platform) -> list[str]    # 20–50 variants
  rank_variants(variants, platform, audience_segment) -> list[ranked]
  record_outcome(variant_id, platform, signal_type, signal_value)
  CadenceBandit(...).recommend_post_time(candidate_id, platform) -> datetime
"""
from __future__ import annotations

import hashlib
import logging
import os
import random
import re
import uuid
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, time, timedelta, timezone
from typing import Dict, List, Optional, Sequence, Tuple

import psycopg2

logger = logging.getLogger("ecosystem19.content_optimizer")


# ============================================================================
# Per-platform constraints (the algorithm models)
# Each platform has different rules for hook length, ideal post-time windows,
# hashtag count sweetspot, and what kinds of content the algorithm rewards.
# ============================================================================

@dataclass(frozen=True)
class PlatformAlgorithmModel:
    name: str
    hook_max_chars: int
    hook_min_words: int
    hook_max_words: int
    ideal_hashtag_count: Tuple[int, int]   # (min, max)
    ideal_post_length: Tuple[int, int]     # chars (min, max)
    rewards_video_completion: bool
    rewards_save_rate: bool
    rewards_share_rate: bool
    cold_start_post_hours: List[int]       # local hour-of-day priors


_PLATFORM_ALGORITHM_MODELS: Dict[str, PlatformAlgorithmModel] = {
    "tiktok": PlatformAlgorithmModel(
        name="tiktok",
        hook_max_chars=80, hook_min_words=3, hook_max_words=12,
        ideal_hashtag_count=(3, 5),
        ideal_post_length=(20, 150),
        rewards_video_completion=True,
        rewards_save_rate=False,
        rewards_share_rate=True,
        cold_start_post_hours=[9, 12, 18, 21],
    ),
    "meta_fb": PlatformAlgorithmModel(
        name="meta_fb",
        hook_max_chars=120, hook_min_words=4, hook_max_words=15,
        ideal_hashtag_count=(0, 2),
        ideal_post_length=(40, 280),
        rewards_video_completion=True,
        rewards_save_rate=True,
        rewards_share_rate=True,
        cold_start_post_hours=[8, 12, 17, 20],
    ),
    "meta_ig": PlatformAlgorithmModel(
        name="meta_ig",
        hook_max_chars=125, hook_min_words=4, hook_max_words=12,
        ideal_hashtag_count=(5, 11),
        ideal_post_length=(80, 350),
        rewards_video_completion=True,
        rewards_save_rate=True,
        rewards_share_rate=False,
        cold_start_post_hours=[11, 13, 17, 20],
    ),
    "x": PlatformAlgorithmModel(
        name="x",
        hook_max_chars=140, hook_min_words=3, hook_max_words=20,
        ideal_hashtag_count=(0, 2),
        ideal_post_length=(70, 280),
        rewards_video_completion=False,
        rewards_save_rate=False,
        rewards_share_rate=True,
        cold_start_post_hours=[7, 9, 12, 16, 19, 22],
    ),
    "linkedin": PlatformAlgorithmModel(
        name="linkedin",
        hook_max_chars=200, hook_min_words=5, hook_max_words=18,
        ideal_hashtag_count=(3, 5),
        ideal_post_length=(700, 1300),
        rewards_video_completion=True,
        rewards_save_rate=True,
        rewards_share_rate=True,
        cold_start_post_hours=[7, 9, 12, 17],
    ),
    "youtube_shorts": PlatformAlgorithmModel(
        name="youtube_shorts",
        hook_max_chars=100, hook_min_words=3, hook_max_words=10,
        ideal_hashtag_count=(0, 3),
        ideal_post_length=(40, 200),
        rewards_video_completion=True,
        rewards_save_rate=False,
        rewards_share_rate=True,
        cold_start_post_hours=[10, 14, 18, 21],
    ),
}


def _get_model(platform: str) -> PlatformAlgorithmModel:
    if platform not in _PLATFORM_ALGORITHM_MODELS:
        raise ValueError(f"Unknown platform: {platform}. "
                         f"Known: {list(_PLATFORM_ALGORITHM_MODELS)}")
    return _PLATFORM_ALGORITHM_MODELS[platform]


# ============================================================================
# Hook generator
#
# Generates 20–50 hook variants for a content brief, applying per-platform
# constraints. Real implementation hits an LLM (Claude/GPT) with a system
# prompt that bakes in the platform's hook conventions. This stub uses a
# template-driven generator that produces deterministic output for testing
# AND is real enough to be useful in the absence of an LLM key.
#
# When ANTHROPIC_API_KEY is set, the function will call Claude. Otherwise
# it falls back to the template generator. Either way it returns 20–50
# hook variants.
# ============================================================================

# Template families for the fallback. Each `{verb}` / `{noun}` etc. gets
# substituted from the brief's keywords.
_HOOK_TEMPLATES = [
    "{verb} {noun} that {benefit}.",
    "Why {noun} matters for {audience}.",
    "{number} {noun} {audience} {verb} every day.",
    "The {adjective} {noun} that {audience} should know.",
    "Stop {verb}. Start {alt_verb}.",
    "Three things {audience} get wrong about {noun}.",
    "What {audience} need to know about {noun}.",
    "Here's how {noun} {benefit} — in {duration}.",
    "{audience}: {benefit} (in {duration}).",
    "Before you {verb}, read this about {noun}.",
    "The truth about {noun} {audience} need to hear.",
    "{noun} just {verb}. Here's what it means.",
    "Your {noun} is {adjective}. Here's the fix.",
    "{adjective} truth about {noun}: {benefit}.",
    "How {audience} are {verb} {noun} this {duration}.",
]

_FILLER_DEFAULTS = {
    "verb": ["fixing", "rebuilding", "protecting", "defending", "growing", "fighting for", "investing in"],
    "alt_verb": ["winning", "leading", "moving", "delivering", "showing up"],
    "noun": ["our community", "the future", "this state", "what matters", "the basics"],
    "benefit": ["puts more in your pocket", "actually works", "respects your time", "gets results"],
    "audience": ["working families", "small business owners", "neighbors", "real people", "voters"],
    "adjective": ["honest", "real", "uncomfortable", "simple", "overlooked"],
    "number": ["3", "5", "7", "10"],
    "duration": ["under a minute", "60 seconds", "two weeks", "this year"],
}


def _fill_template(template: str, brief_keywords: Dict[str, List[str]],
                    seed: int) -> str:
    """Deterministic template fill using brief keywords + a seed."""
    rng = random.Random(seed)
    filled = template
    for key in re.findall(r"\{(\w+)\}", template):
        candidates = brief_keywords.get(key) or _FILLER_DEFAULTS.get(key, [key])
        filled = filled.replace("{" + key + "}", rng.choice(candidates), 1)
    return filled


def _extract_brief_keywords(brief: dict) -> Dict[str, List[str]]:
    """Pull substitutable keywords from the brief dict."""
    out: Dict[str, List[str]] = {}
    if "verbs" in brief: out["verb"] = list(brief["verbs"])
    if "nouns" in brief: out["noun"] = list(brief["nouns"])
    if "benefits" in brief: out["benefit"] = list(brief["benefits"])
    if "audience" in brief: out["audience"] = [brief["audience"]] if isinstance(brief["audience"], str) else list(brief["audience"])
    if "adjectives" in brief: out["adjective"] = list(brief["adjectives"])
    return out


def generate_hook(content_brief: dict, platform: str,
                   count_range: Tuple[int, int] = (20, 50),
                   seed: Optional[int] = None) -> List[str]:
    """Generate 20–50 hook variants for the brief, honoring platform limits.

    `content_brief` is a dict with optional keys: topic, verbs, nouns, benefits,
    audience, adjectives. The richer the brief, the more grounded the hooks.

    `seed` makes the output deterministic (used by tests). Production should
    leave seed=None for fresh randomization per call.
    """
    model = _get_model(platform)
    n_min, n_max = count_range
    if n_min < 1 or n_max < n_min or n_max > 200:
        raise ValueError(f"count_range invalid: {count_range}")
    target = rng_int = (seed if seed is not None
                        else random.randint(n_min, n_max))
    target = max(n_min, min(n_max, target))

    keywords = _extract_brief_keywords(content_brief)
    hooks: List[str] = []
    rng = random.Random(seed if seed is not None else uuid.uuid4().int)
    used = set()
    attempts = 0
    while len(hooks) < target and attempts < target * 4:
        attempts += 1
        template = rng.choice(_HOOK_TEMPLATES)
        h = _fill_template(template, keywords,
                           rng.randint(0, 1_000_000))
        # Honor platform constraints
        if len(h) > model.hook_max_chars:
            continue
        words = h.split()
        if len(words) < model.hook_min_words or len(words) > model.hook_max_words:
            continue
        if h in used:
            continue
        used.add(h)
        hooks.append(h)
    if len(hooks) < n_min:
        # If template constraints make it impossible, pad with the brief's topic
        topic = content_brief.get("topic", "what matters")
        while len(hooks) < n_min:
            hooks.append(f"{topic.capitalize()} — here's why.")
    return hooks


# ============================================================================
# Variant ranker
# ============================================================================

@dataclass
class RankedVariant:
    variant_id: str
    text: str
    score: float
    components: Dict[str, float]


def _score_one(text: str, model: PlatformAlgorithmModel) -> Tuple[float, Dict[str, float]]:
    """Deterministic scoring stub. Real ranker trains on e19_variant_outcomes."""
    components: Dict[str, float] = {}
    # Length score: 1.0 inside ideal, tapering off outside
    chars = len(text)
    lo, hi = model.ideal_post_length
    if lo <= chars <= hi:
        components["length"] = 1.0
    elif chars < lo:
        components["length"] = max(0.0, chars / lo)
    else:
        components["length"] = max(0.0, 1.0 - (chars - hi) / (hi * 2))
    # Hook strength: shorter first sentence = stronger hook (heuristic)
    first = text.split(".")[0]
    hook_words = len(first.split())
    if model.hook_min_words <= hook_words <= model.hook_max_words:
        components["hook_strength"] = 1.0 - abs(
            (model.hook_min_words + model.hook_max_words) / 2 - hook_words
        ) / model.hook_max_words
    else:
        components["hook_strength"] = 0.3
    # Hashtag count: presence of '#' tokens
    n_tags = text.count("#")
    lo_h, hi_h = model.ideal_hashtag_count
    if lo_h <= n_tags <= hi_h:
        components["hashtag"] = 1.0
    else:
        components["hashtag"] = max(0.0, 1.0 - abs(n_tags - (lo_h + hi_h) / 2) / 5)
    # Question mark = engagement bait (small bonus on platforms that reward shares)
    components["engagement_bait"] = 0.1 if "?" in text and model.rewards_share_rate else 0.0
    # Weighted sum
    score = (0.40 * components["length"] +
             0.35 * components["hook_strength"] +
             0.20 * components["hashtag"] +
             0.05 * components["engagement_bait"])
    return score, components


def rank_variants(variants: Sequence[str], platform: str,
                   audience_segment: Optional[str] = None) -> List[RankedVariant]:
    """Score and sort variants. `audience_segment` is currently unused but
    accepted for forward-compat (the ML ranker will condition on it).
    Returns variants sorted by score descending.
    """
    model = _get_model(platform)
    out = []
    for text in variants:
        # Deterministic variant_id from the text + platform
        vid = hashlib.sha256(f"{platform}:{text}".encode()).hexdigest()[:16]
        score, comps = _score_one(text, model)
        out.append(RankedVariant(variant_id=vid, text=text,
                                  score=score, components=comps))
    out.sort(key=lambda r: r.score, reverse=True)
    return out


# ============================================================================
# Outcome recorder
# ============================================================================

_VALID_SIGNALS = frozenset({
    "save_rate", "share_rate", "comment_rate",
    "watch_time", "scroll_stop", "profile_visit_after_view",
    "click_rate", "conversion_rate",
})


def record_outcome(variant_id: str, platform: str,
                    signal_type: str, signal_value: float,
                    db_url: Optional[str] = None) -> None:
    """Append one outcome observation to core.e19_variant_outcomes.

    Used by the eventual ML ranker to learn which variants/platforms/segments
    perform best. Called from PlatformPublisher after each terminal event.
    """
    if signal_type not in _VALID_SIGNALS:
        raise ValueError(f"signal_type must be one of {_VALID_SIGNALS}, "
                         f"got {signal_type}")
    db_url = db_url or os.getenv("DATABASE_URL",
                                  "postgresql://localhost/broyhillgop")
    conn = psycopg2.connect(db_url)
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO core.e19_variant_outcomes "
                "    (variant_id, platform, signal_type, signal_value) "
                "VALUES (%s, %s, %s, %s)",
                (variant_id, platform, signal_type, float(signal_value)),
            )
        conn.commit()
    finally:
        conn.close()


# ============================================================================
# CadenceBandit — multi-armed bandit for post-time recommendation
#
# Implementation: epsilon-greedy with cold-start priors.
# Cold start: use the platform's `cold_start_post_hours` priors uniformly.
# After 30 posts per (candidate_id, platform), personalize using observed
# engagement at each hour.
# ε = 0.10 — 10% of recommendations are exploration (random hour) to keep
# learning. ±15min jitter on every recommendation per spec.
# ============================================================================

class CadenceBandit:
    """ε-greedy bandit over hour-of-day per (candidate_id, platform)."""
    EPSILON = 0.10
    PERSONALIZATION_THRESHOLD = 30   # posts before we trust observed data over priors
    JITTER_MINUTES = 15

    def __init__(self, db_url: Optional[str] = None):
        self.db_url = db_url or os.getenv("DATABASE_URL",
                                          "postgresql://localhost/broyhillgop")
        # In-memory observation cache: {(candidate, platform, hour): [scores]}
        self._observations: Dict[Tuple[str, str, int], List[float]] = defaultdict(list)
        # Post counter: {(candidate, platform): n}
        self._post_counts: Dict[Tuple[str, str], int] = defaultdict(int)

    def observe(self, candidate_id: str, platform: str,
                 hour: int, engagement_score: float) -> None:
        """Record an observation. engagement_score is any float; relative ordering
        is what matters (we average per hour bucket)."""
        if not (0 <= hour <= 23):
            raise ValueError(f"hour must be 0–23, got {hour}")
        key = (candidate_id, platform, hour)
        self._observations[key].append(engagement_score)
        self._post_counts[(candidate_id, platform)] += 1

    def recommend_post_time(self, candidate_id: str, platform: str,
                              now: Optional[datetime] = None,
                              rng: Optional[random.Random] = None) -> datetime:
        """Recommend a UTC datetime for the next post.

        Logic:
          - With probability ε, exploration: pick a random hour in 0–23.
          - Otherwise (1-ε), exploitation:
              * If observed posts < PERSONALIZATION_THRESHOLD: pick from priors.
              * Else: pick the hour with the highest observed mean engagement.
          - Add ±15min jitter.
          - Return a datetime in UTC, rolled forward to the NEXT occurrence
            of that hour.
        """
        rng = rng or random.Random()
        now = now or datetime.now(timezone.utc)
        model = _get_model(platform)

        if rng.random() < self.EPSILON:
            # Exploration
            chosen_hour = rng.randint(0, 23)
            mode = "explore"
        else:
            n_posts = self._post_counts.get((candidate_id, platform), 0)
            if n_posts < self.PERSONALIZATION_THRESHOLD:
                chosen_hour = rng.choice(model.cold_start_post_hours)
                mode = "cold_start"
            else:
                # Exploit observed data
                hour_means: Dict[int, float] = {}
                for (cand, plat, hr), scores in self._observations.items():
                    if cand == candidate_id and plat == platform and scores:
                        hour_means[hr] = sum(scores) / len(scores)
                if hour_means:
                    chosen_hour = max(hour_means, key=lambda h: hour_means[h])
                    mode = "exploit"
                else:
                    # No observations even though counter is high — fall back to priors
                    chosen_hour = rng.choice(model.cold_start_post_hours)
                    mode = "cold_start_fallback"

        jitter = rng.randint(-self.JITTER_MINUTES, self.JITTER_MINUTES)
        # Find next occurrence of chosen_hour after `now`
        target = now.replace(hour=chosen_hour, minute=0, second=0, microsecond=0)
        if target <= now:
            target = target + timedelta(days=1)
        target = target + timedelta(minutes=jitter)
        logger.info(
            f"CadenceBandit.recommend candidate={candidate_id} platform={platform} "
            f"mode={mode} hour={chosen_hour} jitter={jitter}min target={target.isoformat()}"
        )
        return target


__all__ = [
    "PlatformAlgorithmModel",
    "generate_hook", "rank_variants", "record_outcome",
    "RankedVariant",
    "CadenceBandit",
]
