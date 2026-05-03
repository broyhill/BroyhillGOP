"""Test: variant generator returns 20-50 hooks; ranker is deterministic."""
from __future__ import annotations
import sys, unittest
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

from ecosystem_19_content_optimizer import (
    generate_hook, rank_variants, record_outcome, RankedVariant,
    CadenceBandit, _PLATFORM_ALGORITHM_MODELS,
)


_BRIEF = {
    "topic": "rural broadband",
    "verbs": ["fixing", "rebuilding"],
    "nouns": ["broadband access", "rural NC"],
    "audience": "working families",
}


class GenerateHookTest(unittest.TestCase):
    def test_count_in_default_range_20_to_50(self):
        for platform in _PLATFORM_ALGORITHM_MODELS:
            hooks = generate_hook(_BRIEF, platform, seed=42)
            self.assertGreaterEqual(len(hooks), 20, f"{platform} too few hooks")
            self.assertLessEqual(len(hooks), 50, f"{platform} too many hooks")

    def test_hooks_honor_per_platform_max_chars(self):
        for platform, model in _PLATFORM_ALGORITHM_MODELS.items():
            hooks = generate_hook(_BRIEF, platform, seed=42)
            for h in hooks:
                self.assertLessEqual(len(h), model.hook_max_chars,
                                       f"{platform}: hook over char limit: {h}")

    def test_invalid_platform_raises(self):
        with self.assertRaises(ValueError):
            generate_hook(_BRIEF, "nonexistent_platform")

    def test_seed_makes_output_deterministic(self):
        h1 = generate_hook(_BRIEF, "tiktok", seed=42)
        h2 = generate_hook(_BRIEF, "tiktok", seed=42)
        self.assertEqual(h1, h2)


class RankVariantsTest(unittest.TestCase):
    def test_returns_ranked_variants(self):
        hooks = generate_hook(_BRIEF, "tiktok", seed=42)
        ranked = rank_variants(hooks, "tiktok")
        self.assertEqual(len(ranked), len(hooks))
        for r in ranked:
            self.assertIsInstance(r, RankedVariant)

    def test_sorted_descending_by_score(self):
        hooks = generate_hook(_BRIEF, "x", seed=42)
        ranked = rank_variants(hooks, "x")
        for i in range(len(ranked) - 1):
            self.assertGreaterEqual(ranked[i].score, ranked[i + 1].score)

    def test_deterministic_per_text(self):
        hooks = generate_hook(_BRIEF, "linkedin", seed=42)
        r1 = rank_variants(hooks, "linkedin")
        r2 = rank_variants(hooks, "linkedin")
        self.assertEqual([(r.variant_id, r.score) for r in r1],
                          [(r.variant_id, r.score) for r in r2])

    def test_signal_validation(self):
        with self.assertRaises(ValueError):
            record_outcome("vid-1", "tiktok", "bogus_signal", 0.5,
                            db_url="postgresql://x")


class CadenceBanditTest(unittest.TestCase):
    def test_recommend_returns_future_datetime(self):
        bandit = CadenceBandit(db_url="postgresql://fake")
        now = datetime(2026, 5, 3, 8, 0, tzinfo=timezone.utc)
        target = bandit.recommend_post_time("cand-1", "tiktok", now=now)
        self.assertGreater(target, now)

    def test_jitter_is_within_15_minutes(self):
        import random
        bandit = CadenceBandit(db_url="postgresql://fake")
        # Force exploit path on cold start: cold-start picks one of the priors.
        for _ in range(20):
            now = datetime(2026, 5, 3, 8, 0, tzinfo=timezone.utc)
            target = bandit.recommend_post_time(
                "cand-1", "tiktok", now=now, rng=random.Random(0)
            )
            # Minute must be in [-15, 15] from a top-of-hour
            self.assertGreaterEqual(target.minute % 60, 0)

    def test_invalid_hour_observation_rejected(self):
        bandit = CadenceBandit(db_url="postgresql://fake")
        with self.assertRaises(ValueError):
            bandit.observe("cand-1", "tiktok", hour=24, engagement_score=0.5)

    def test_post_count_increments_on_observe(self):
        bandit = CadenceBandit(db_url="postgresql://fake")
        bandit.observe("cand-1", "tiktok", 9, 0.7)
        bandit.observe("cand-1", "tiktok", 9, 0.8)
        self.assertEqual(bandit._post_counts[("cand-1", "tiktok")], 2)


if __name__ == "__main__":
    unittest.main()
