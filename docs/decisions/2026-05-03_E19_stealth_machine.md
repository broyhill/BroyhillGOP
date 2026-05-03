# ADR — E19 Stealth Machine (2026-05-03)

**Status:** Accepted
**Owner:** Ed Broyhill
**Implementation branch:** `claude/section-12-e19-stealth-machine-2026-05-03`
**Supersedes:** Section 3 E19 Social Media Merge (2026-05-02). Section 3 was a cleanup pass; this is the enterprise rebuild.

---

## Context

E19 was three conflicting Python files until the Section 3 merge earlier today. After the merge, E19 was a single 2,388-line file with `SocialMediaEngine` (entry point), `CarouselPostEngine` (carousel/posts), and `PlatformPublisher` (platform API calls) co-resident under one roof. **But** the engines didn't actually delegate to each other, the brain event handlers were stubs, the AI-driven generation didn't exist, the funnel-aware sequencing didn't exist, the audience builder didn't exist, the news-trigger loop didn't exist, the listening inbox didn't exist, and the compliance gates were limited to TCPA on SMS only.

Ed's directive (verbatim): *"the very best ai driven social machine with communication funnels that fly under the radar but are effective."*

Operating principle, also Ed's: **push to the legal edge, never over it.** The candidate is the final approval gate on every aggressive move. The platform's existing approval queue (E24), brain triggers (E20), ethical guardrails skill, and candidate preferences skill enforce compliance. Don't reinvent them; inherit them.

Stealth-machine here means: extracting the maximum political effect from each engagement without violating laws, platform policies, or the candidate's stated red lines. Not subterfuge. Not fake accounts. Not undisclosed AI. Sophisticated targeting + sequencing + cadence + content-quality optimization, all gated by candidate approval and platform-policy compliance.

## Decision

**Scope:** rewrite E19 as 8 sub-weapons under one ecosystem. Build the first 4 in this PR. Stub the last 4 with `NotImplementedError("backlog")` and TODO links.

| Sub-weapon | Built this PR? | Purpose |
|---|---|---|
| **E19-Organic** | ✅ Built | Algorithm-optimized free posts (FB/IG/Twitter/LinkedIn/TikTok/YouTube Shorts) |
| **E19-PaidAds** | ✅ Built | Meta/Google/X/TikTok ads API integration with FEC + state-AI disclosure gates |
| **E19-Retarget** | ✅ Built | Custom audience retargeting (Meta hashed-email, Google CMatch, X TA, TikTok CA) |
| **E19-Lookalike** | ✅ Built | Lookalike audiences seeded from donor list, gated by `match_tier IN ('A_EXACT','B_ALIAS')` |
| **E19-PaidBoost** | 🟡 Stub | Boost-post automation (algorithmic; backlog) |
| **E19-Live** | 🟡 Stub | Live-stream orchestration (backlog) |
| **E19-Surrogate** | 🟡 Stub | Surrogate-account coordination with full disclosure (backlog; needs legal sign-off) |
| **E19-Engage** | 🟡 Stub | Reply automation in inbound conversations (backlog; high abuse risk) |

**File structure** (5 new modules, 1 rewrite, all under `ecosystems/`):

```
ecosystems/
├── ecosystem_19_social_media.py        (rewritten — entry point + 7 compliance gates + Pentad integration)
├── ecosystem_19_audience_builder.py    (new)
├── ecosystem_19_content_optimizer.py   (new — variants + ranking + CadenceBandit)
├── ecosystem_19_funnel_sequencer.py    (new — funnel stages + content gate)
├── ecosystem_19_news_trigger.py        (new — E42 subscription + 90-min SLA)
└── ecosystem_19_listening_inbox.py     (new — inbound classification + AI-drafted replies)
```

Mirror the same files to `backend/python/ecosystems/` (per existing duplicate-folder convention).

**Database:** five schema changes in `migrations/2026-05-03_e19_social_schema.sql` — NOT executed in this PR. Ed authorizes execution separately via `I AUTHORIZE THIS ACTION`.

**Brain Pentad integration:** E19 is a sender ecosystem on the Pentad. It consumes `PersonalizedMessage` from upstream and emits `SendOutcome` (E11) + `CostEvent` (E60). Subscribes to `RuleFired` from E60 for pause/throttle. If `shared/brain_pentad_contracts.py` isn't on the branch yet (it's in a separate pending PR), the contract shapes are inlined as Pydantic models in `ecosystems/_e19_contracts.py` with a TODO link to the future shared module.

## Alternatives considered

### A. Single monolithic E19 file with internal modules

**Rejected.** Would have ballooned `ecosystem_19_social_media.py` past 5,000 lines. Hard to navigate, hard to test in isolation, hard for future agents to modify one sub-weapon without touching the others. The 8-sub-weapon split makes ownership explicit.

### B. Build all 8 sub-weapons in this PR

**Rejected.** Three of the unbuilt four (PaidBoost, Surrogate, Engage) have meaningful abuse risk that needs legal/policy sign-off before code lands. Surrogate-account coordination requires careful disclosure language. Engage automation could cross into harassment if not bounded carefully. Live-stream orchestration is mostly an integration with E46 Broadcast Hub and would inflate this PR. Stubbing them is the safer pace.

### C. No funnel sequencing — let candidates manually decide what content goes where

**Rejected.** That's what the platform does today and the result is that bundler-tier asks go out to strangers, donor-only impact reports get blasted to non-donors, and the campaign looks tone-deaf. The funnel gate is a hard rule precisely so individual content authors can't accidentally violate it.

### D. Use a real LP solver / trained ML for variant ranking right now

**Rejected for this PR.** No labeled training data exists yet. Would build fake credibility around a stub model. Variant ranker uses a deterministic scoring stub (length, hook strength, hashtag count) and writes outcomes to `e19_variant_outcomes` so the future ML model can train on real campaign data. The wire shape is correct; the math is honest about being a stub.

### E. Auto-fire content without candidate approval

**Rejected — red line.** Every aggressive move (paid ad, news-triggered response, inbound reply) goes through E24 approval queue. Auto-approval on timer is ONLY for the nightly post batch and ONLY when the candidate explicitly opts in.

## Consequences

### What gets easier

- Adding a new sub-weapon is a new file in the same conventional shape.
- Per-platform algorithm tuning lives in one place (`content_optimizer.py`) instead of scattered.
- Compliance gates are centralized; adding a new gate (e.g., new state AI-disclosure law) is a one-method addition.
- Funnel-aware content tagging means content authors can focus on quality without re-asking "should this go to this audience?" every time.
- The variant outcomes ledger (`e19_variant_outcomes`) creates the training data for the eventual ML ranker.

### What gets harder

- Five new files mean five new maintenance surfaces. The doc gate (this PR + the two siblings) is meant to keep them legible.
- Backend-folder mirroring doubles the touch surface for every change. The duplicate-folder cleanup is still out-of-scope.
- News-trigger loop creates a 24/7 listener responsibility — needs an E42 News Intelligence cron that's not yet running in production.
- The compliance audit table (`core.compliance_audit`) becomes a high-write log; if the campaign sends 10K posts/day with 7 gates each, that's 70K rows/day. Index strategy in the migration accounts for this; partitioning is backlog'd.

## Red lines enforced (mechanically, in code)

These aren't policy preferences — they're hard prevention.

| Red line | How code prevents it |
|---|---|
| **Fake accounts / sock puppets** | `tests/test_e19_no_fake_accounts.py` asserts every `poster_id` resolves to a row in a `registered_identities` table with a non-NULL `verified_human_owner` field. CI fails if any unverified `poster_id` appears in a fire path. |
| **Hidden paid promotion** | `check_fec_paid_for_by(post)` blocks any paid fire that doesn't carry the FEC disclaimer. Logged to `core.compliance_audit`. |
| **Undisclosed surrogate content** | E19-Surrogate is STUBBED in this PR. When built, surrogate fires require a `coordination_disclosure` field. The check function is scaffolded as `check_surrogate_disclosure(post)`. |
| **Undisclosed AI political content** | `check_state_ai_disclosure(post, audience_geography)` reads the audience's geography and applies CA AB-2655 / TX SB-751 / MI election AI law. AI-generated content posted to those states without disclosure is blocked. |
| **Sending bundler content to a stranger** | `check_funnel_stage_gate(asset, donor)` enforces the funnel rule from `E19_FUNNEL_STAGES.md` §4. |
| **Sending paid messaging to UNMATCHED donors** | `check_match_tier_gate(donor)` blocks anything not in `A_EXACT` or `B_ALIAS`. |
| **Over-frequency to high-grade donors** | `check_fatigue_cap(donor, period)` uses fatigue caps from `shared/fatigue_caps.py` (or inlined rules until that module lands). |

Every gate is a function with a single signature: returns `{allow: bool, reason: str}`. Every call writes a row to `core.compliance_audit`. The audit table is the paper trail for FEC inquiries, platform-policy disputes, and internal post-mortems.

## Out of scope (intentionally NOT in this PR)

- Trained ML models for variant ranking or send-time optimization (use stubs that log outcomes for future training)
- Cross-ecosystem refactors (don't touch E20, E24, E30, E31, E36, E42, E56)
- Brain Pentad shared module merge (use local `_e19_contracts.py` if shared isn't on the branch yet)
- Backend-folder duplicate cleanup (out-of-scope per platform-wide policy)
- E19-PaidBoost, E19-Live, E19-Surrogate, E19-Engage sub-weapon implementations
- Live deployment or DDL execution (Ed authorizes separately)
- Hardcoded credentials anywhere (use `os.getenv()`)

---
*ADR authored by Claude (Cowork session, Opus 4.7), 2026-05-03.*
*This decision record is permanent. To change a decision above, write a new ADR that supersedes this one.*
