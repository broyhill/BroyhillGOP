# Section 3 — E19 Social Media Merge (Design + Rationale)

**Merged:** 2026-05-02 as commit `060ab67` into `main`.
**Branch:** `claude/section-3-e19-social-media-merge-2026-05-02` (now defunct).
**Result:** 4 source files removed (3 E19 + 1 personalization stub), 1 merged file added (2,388 lines), 19 smoke tests added.

---

## The problem

Three E19 files lived under `ecosystems/` — none was a strict superset:

| File | Lines | Real content |
|---|---:|---|
| `ecosystem_19_social_media_integration_patch.py` | 1,066 | `SocialMediaIntegrationEngine` — brain integration, AI video orchestration via E16b/E45, nightly workflow, SMS approval flow |
| `ecosystem_19_social_media_enhanced.py` | 1,142 | `SocialMediaEngine` — carousel/single posts, compliance checks, engagement tracking, click recording, analytics |
| `ecosystem_19_social_media_manager.py` | 903 | `SocialMediaManager` — REAL Facebook GraphAPI / tweepy / linkedin_v2 calls, per-candidate token storage |

`_integration_patch` had brain hooks but no posting engine. `_enhanced` had carousel/post code but no real platform API calls. `_manager` had the real API calls but no brain hooks. **Each file was missing what the others had.**

## Decision: pragmatic co-resident merge, not full fusion

Two architectural styles were on the table:

**Full fusion:** Take the three engines, identify every method, eliminate duplicates, build a single unified class with all the responsibilities. **Rejected** because it would require deep behavioral testing of every method to confirm semantic equivalence — and we don't have integration tests to backstop that. High risk for a long-running political campaign tool.

**Co-resident:** Take the three engines, rename to make their responsibilities clear, put them all in one file, designate ONE as the "entry point" that delegates to the others when needed. **Picked** because it preserves all existing behavior verbatim while consolidating the file count and clarifying the public API.

## The new structure

One file, three classes, one entry point:

```
ecosystems/ecosystem_19_social_media.py  (2,388 lines)
├── SocialMediaEngine        (UNIFIED ENTRY POINT — was SocialMediaIntegrationEngine)
│   28 methods, 488 body lines.
│   Brain event handlers (handle_crisis_response, handle_positive_news,
│   handle_opponent_gaffe, handle_endorsement, handle_trending_topic).
│   AI video orchestration (request_ai_video, handle_video_post_request,
│   handle_video_ready).
│   Nightly workflow (run_nightly_workflow, generate_nightly_posts).
│   SMS approval flow (send_approval_sms, handle_sms_reply, auto_approve_pending).
│
├── CarouselPostEngine       (was _enhanced.SocialMediaEngine)
│   16 methods, 484 body lines.
│   Carousel + single posts, compliance, engagement, analytics.
│   create_carousel_post, create_single_post, publish_post,
│   _publish_carousel, _publish_single, check_compliance,
│   record_engagement, record_click, get_carousel_analytics.
│
└── PlatformPublisher        (was SocialMediaManager)
    23 methods, 653 body lines.
    Real Facebook Graph API, tweepy, linkedin_v2 calls.
    Per-candidate token storage and retrieval.
    publish_to_facebook, publish_to_twitter, publish_to_instagram,
    publish_to_linkedin (and their token getters).
```

Plus the helper clients (`VoiceEngineClient`, `VideoSynthesisClient`) that talk to E16b/E45, plus the enums (`Platform`, `PostType`, `MediaType`, `PostPriority`, `PostStatus`, `VideoStatus`) and dataclasses (`SocialVideoRequest`, `NightlyPost`, `CarouselSlide`).

## API surface

The public entry point is **`SocialMediaEngine`**:

```python
from ecosystem_19_social_media import SocialMediaEngine

engine = SocialMediaEngine()
engine.start_event_listener()  # subscribes to E20 brain events
engine.run_nightly_workflow()  # 8 PM generate, 11 PM auto-approve
engine.send_approval_sms(post)
engine.handle_sms_reply(phone, message)
```

For direct posting work (carousel, single posts, engagement tracking), use `CarouselPostEngine`. For per-platform raw API calls (when you need to bypass the brain orchestration layer), use `PlatformPublisher` — but you almost certainly shouldn't need to.

## Integration contract

E19 is the second stop on the Brain Pentad linear loop: `E01 → E19 → E30 → ...`. After the Pentad PR lands, E19 will consume `GradedDonor` from E01 and emit `PersonalizedMessage` to E30 (and also to E31 / E32 / etc. depending on channel).

Today (Section 3 as merged), E19 is NOT yet wired to consume `GradedDonor` — it still uses its existing brain-event subscription mechanism. The Pentad rewire is a separate follow-up PR.

## What was deleted

- `ecosystems/ecosystem_19_social_media_integration_patch.py` (became the base of the merge)
- `ecosystems/ecosystem_19_social_media_enhanced.py` (extracted into `CarouselPostEngine`)
- `ecosystems/ecosystem_19_social_media_manager.py` (extracted into `PlatformPublisher`)
- `backend/python/ecosystems/ecosystem_19_personalization_engine.py` (was 828 lines of error stubs only — confirmed dead, no callers)

## Smoke tests (tests/test_e19_social_media.py — 19 tests)

These are AST-based structural tests, not behavioral tests. They verify:

- The unified entry point `SocialMediaEngine` is present.
- The renamed `CarouselPostEngine` and `PlatformPublisher` are present.
- Helper clients (`VoiceEngineClient`, `VideoSynthesisClient`) are present.
- All 6 enums and 3 dataclasses are present.
- Old class names (`SocialMediaIntegrationEngine`, `SocialMediaManager`) are NOT present (confirms the rename applied).
- The brain event handlers, carousel methods, platform publishers, compliance + token getters all survived.

**They do NOT** test that any of the platform handlers actually post to Facebook, etc. Real platform API calls require live tokens (per-candidate) and aren't safe to run in CI.

## Known limits

- The `SocialMediaEngine.__init__` does NOT yet instantiate `CarouselPostEngine` or `PlatformPublisher`. The three engines coexist in the file but don't yet delegate to each other automatically. If you need brain-driven posts to actually publish via the real API, you currently have to wire them up at the call site. **This wiring is a logical follow-up PR**, not in scope for Section 3.
- `PlatformPublisher` imports `facebook` (Graph API), `tweepy`, `linkedin_v2`. These libraries need to be in `requirements.txt` for the module to actually run. Confirm before deploy.
- E60 Nervous Net cost emission is not wired into E19 yet. Section 8 wired it into E30 and E31 only.

## Migration notes

If any code was importing classes by their old names (`SocialMediaIntegrationEngine`, `SocialMediaManager`, or the old `SocialMediaEngine` from `_enhanced.py`), it will break. **Verified before merge** that no Python imports referenced the old names outside of the source files themselves.

The 4 deleted files might still be referenced by stale auto-generated indices (json, html); those will refresh on the next pipeline run.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02. Merge committed as `eee6ff4`, merged to main as `060ab67`.*
