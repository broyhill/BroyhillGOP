# E19 — Social Media Stealth Machine

**Ecosystem code:** E19
**Status:** Section 12 build — first 4 of 8 sub-weapons live; remaining 4 stubbed
**Branch:** `claude/section-12-e19-stealth-machine-2026-05-03`
**Brain Pentad role:** Sender ecosystem (consumes `PersonalizedMessage`, emits `SendOutcome` + `CostEvent`)
**Owner:** Ed Broyhill

---

## What E19 does

E19 generates, schedules, and publishes social media content — organic posts, paid ads, retargeting, and lookalike audiences across Facebook, Instagram, X, LinkedIn, TikTok, and YouTube Shorts — under a strict funnel-aware gate that prevents wrong-content-to-wrong-audience mistakes. It listens for opponent-gaffe and breaking-news triggers, generates ranked variants of response content with a 90-minute SLA, queues them for candidate approval, and records every outcome to feed an in-house variant ranker. It does NOT post anything without (a) the candidate's standing approval rules being satisfied OR (b) explicit per-post approval via E24.

The ecosystem is bounded: it does NOT decide what messaging to use (E19 is a downstream consumer of `PersonalizedMessage` from E19's predecessor in the Pentad loop), does NOT charge for sends (E11 budget owns the budget; E60 nervous net owns the cost ledger), and does NOT generate the candidate's voice or video (E48 Communication DNA + E16B Voice Ultra + E45 Video Studio do that).

---

## Architecture — 8 sub-weapons

```
                      ┌──────────────────────────────────────────────┐
                      │       ecosystem_19_social_media.py           │
                      │   SocialMediaEngine (entry + 7 gates)        │
                      └────┬─────────┬─────────┬─────────┬──────────┘
                           │         │         │         │
            ┌──────────────┘         │         │         └──────────────┐
            ▼                        ▼         ▼                        ▼
    ┌───────────────┐       ┌───────────────┐ ┌────────────────┐ ┌──────────────┐
    │  Audience     │       │   Content     │ │   Funnel       │ │   News       │
    │  Builder      │       │   Optimizer   │ │   Sequencer    │ │   Trigger    │
    │ (E19-Retarget,│       │ (variants +   │ │ (stage gate)   │ │ (E42 sub +   │
    │  Lookalike,   │       │  ranker +     │ │                │ │  90-min SLA) │
    │  Custom)      │       │  bandit)      │ │                │ │              │
    └───────────────┘       └───────────────┘ └────────────────┘ └──────────────┘
                                       │
                                       ▼
                         ┌──────────────────────────────┐
                         │     Listening Inbox          │
                         │ (inbound classifier +        │
                         │  AI-drafted reply +          │
                         │  approval queue routing)     │
                         └──────────────────────────────┘

   Sub-weapons in this PR: E19-Organic, E19-PaidAds, E19-Retarget, E19-Lookalike
   Sub-weapons stubbed:    E19-PaidBoost, E19-Live, E19-Surrogate, E19-Engage
```

E19 sits between E20 Brain (event source) + E42 News Intelligence (event source) on the inbound side, and E11 Budget + E60 Nervous Net on the outbound side. E24 Approval Queue is the human-in-the-loop checkpoint between drafted content and a fire.

---

## Public API surface

### `ecosystem_19_social_media.py`

| Symbol | Type | Purpose |
|---|---|---|
| `SocialMediaEngine` | class | Entry point. Composes the 5 sub-modules + the `PlatformPublisher`. Runs all 7 compliance gates before any fire. |
| `SocialMediaEngine.publish(asset, audience, *, force=False)` | method | The single public publish path. Returns a `SendOutcome` whether the fire succeeded or was gated. |
| `SocialMediaEngine.handle_brain_event(event)` | method | Brain event dispatcher. Routes to the relevant handler (crisis, positive_news, opponent_gaffe, endorsement, trending). |
| `SocialMediaEngine.handle_rule_fired(rule_fired)` | method | Subscribe handler for E60 `RuleFired` payloads (pause / throttle / suppress). |
| `EMAIL_ALLOWED_TIERS` | constant | Wait — this is for E30. The E19 equivalent is `INDIVIDUALIZED_ALLOWED_TIERS`. |
| `INDIVIDUALIZED_ALLOWED_TIERS` | constant | `frozenset({MatchTier.A_EXACT, MatchTier.B_ALIAS})`. Anything below is BLOCKED for individualized targeting. |

### `ecosystem_19_audience_builder.py`

| Symbol | Type | Purpose |
|---|---|---|
| `CustomAudienceBuilder` | class | Builds platform-specific custom audiences from internal donor / visitor / engager lists. |
| `CustomAudienceBuilder.from_donor_list(rnc_regids, match_tier_filter='A_EXACT,B_ALIAS')` | method | Build from a donor list. Filters by match_tier (default: high-confidence only). |
| `CustomAudienceBuilder.from_web_visitors(days_back)` | method | Pulls from E56 visitor de-anonymization. |
| `CustomAudienceBuilder.from_email_engagers(action, days_back)` | method | Pulls from email engagement events (opens, clicks, replies). |
| `CustomAudienceBuilder.lookalike(seed_audience, similarity)` | method | Creates a lookalike audience seeded from another audience. Similarity 0.0–1.0; 0.0 = closest match (smaller pool); 1.0 = broadest (largest pool, lowest similarity). |
| `Audience` | dataclass | The output: carries `audience_id`, `audience_type`, `rnc_regid_count`, `platform_uploads` dict. |

### `ecosystem_19_content_optimizer.py`

| Symbol | Type | Purpose |
|---|---|---|
| `generate_hook(content_brief, platform)` | function | Returns 20–50 hook variants for the first 1.5s of video / first 7 words of post. Per-platform constraints honored. |
| `rank_variants(variants, platform, audience_segment)` | function | Returns variants sorted by predicted engagement (placeholder scoring; logs to `e19_variant_outcomes` for ML training). |
| `record_outcome(variant_id, platform, signal_type, signal_value)` | function | Persists one observation. `signal_type` ∈ {save_rate, share_rate, comment_rate, watch_time, scroll_stop, profile_visit_after_view}. |
| `CadenceBandit` | class | Multi-armed bandit (ε-greedy with cold-start priors) for `recommend_post_time(candidate_id, platform) → datetime`. Adds ±15min jitter. |

### `ecosystem_19_funnel_sequencer.py`

| Symbol | Type | Purpose |
|---|---|---|
| `FunnelStage` | enum | `STRANGER`, `AWARE`, `ENGAGED`, `SUBSCRIBER`, `SMALL_DONOR`, `REPEAT_DONOR`, `BUNDLER`. See `E19_FUNNEL_STAGES.md`. |
| `ContentStage` | enum | All content-stage tags (issue_education, candidate_humanization, family, values, behind_the_scenes, etc.). |
| `get_donor_stage(rnc_regid)` | function | Reads `core.donor_profile` + donation history; returns the donor's current funnel stage. |
| `allowed_content_stages(donor_stage)` | function | Returns the set of `ContentStage` values a donor at that stage MAY receive. |
| `evaluate_stage_transition(rnc_regid)` | function | Recomputes the donor's funnel stage and writes to `core.e19_donor_funnel`. |

### `ecosystem_19_news_trigger.py`

| Symbol | Type | Purpose |
|---|---|---|
| `evaluate_news_event(event)` | function | Decides go/no-go for a news event based on the candidate's issue lanes (from candidate-preferences). Returns `{go: bool, reason: str}`. |
| `NewsTriggerLoop` | class | The 90-minute SLA orchestrator. Generates 5 response variants → posts to E24 approval queue. |
| `NewsTriggerLoop.handle_event(event)` | method | The main entry; called by the E42 subscription. |
| `NewsTriggerLoop.on_approval(approval_id)` | method | Bandit-picks optimal time + platform; fires; records outcome. |

### `ecosystem_19_listening_inbox.py`

| Symbol | Type | Purpose |
|---|---|---|
| `ListeningInbox` | class | Inbound listener for comments / mentions / quote-tweets / DMs across all 5 platforms. |
| `ListeningInbox.classify(message)` | method | Returns `{sentiment, intent, urgency}`. Sentiment ∈ {pos, neg, neutral}; intent ∈ {question, complaint, praise, hostile, spam, press}; urgency ∈ {low, med, high}. |
| `ListeningInbox.draft_reply(inbox_row)` | method | AI-drafts a reply using the candidate's voice profile (from E48). Routes to E24 approval queue. |
| `ListeningInbox.policy_routing(inbox_row)` | method | Hostile/troll → mute or block per candidate policy. Press → comms staff. Policy question with answer → AI draft with citation. |

---

## Dependencies

### What E19 imports

- `psycopg2` — DB access
- `pydantic` — Pentad payload schemas
- `shared.brain_pentad_contracts` (or local fallback `_e19_contracts.py`) — `PersonalizedMessage`, `SendOutcome`, `CostEvent`, `RuleFired`, `MatchTier`, `Channel`
- Standard library: `os`, `re`, `uuid`, `hashlib`, `random`, `logging`, `datetime`, `dataclasses`, `enum`, `typing`

### What E19 depends on but does NOT import directly

Per Brain Pentad Rule P-1, E19 talks to other ecosystems via shared contracts and event bus, not direct imports.

- **E20 Intelligence Brain** — emits brain events that trigger handlers in `SocialMediaEngine.handle_brain_event`
- **E24 Approval Queue** — receives drafted content via the event bus; returns approval decisions
- **E42 News Intelligence** — emits news events that the `NewsTriggerLoop` subscribes to
- **E48 Communication DNA** — provides the candidate voice profile used by `ListeningInbox.draft_reply` and the content optimizer
- **E16B Voice Ultra + E45 Video Studio + E50 GPU Orchestrator** — generate the actual voice + video assets E19 publishes (E19 doesn't synthesize them; just orchestrates)
- **E56 Visitor De-anonymization** — source for `CustomAudienceBuilder.from_web_visitors`
- **E60 Nervous Net** — receives `CostEvent` on every paid fire; can fire `RuleFired` to E19 for pause/throttle
- **E11 Budget** — receives `SendOutcome` on every terminal event

### What calls E19

- E20 Brain (via brain events)
- E42 News Intelligence (via news events)
- E24 Approval Queue (via approval-decision events)
- The nightly post workflow (cron / scheduled job, not yet wired in this PR)
- Manual operator UI (out of scope; admin panel work lives in the Inspinia frontend repo)

---

## Compliance gates (the 7-gate pipeline)

Every fire runs through these gates in order. A failed gate BLOCKS the fire and writes a `decision='block'` row to `core.compliance_audit`. The fire returns a `SendOutcome` with `delivered=False, blocked_by=<gate_name>`.

| # | Gate | What it enforces | Block reason example |
|---|---|---|---|
| 1 | `check_meta_political_authorization(account_id)` | Meta requires per-account political-issue ad authorization. Without it, the ad rejects at the API. | `meta_political_auth_missing` |
| 2 | `check_fec_paid_for_by(post)` | Paid public communications require the FEC "paid for by" disclaimer. Organic posts to opt-in followers do NOT require it. | `fec_disclaimer_missing` |
| 3 | `check_state_ai_disclosure(post, audience_geography)` | CA AB-2655, TX SB-751, MI election AI law, NJ A4985, others. Applied based on the audience's primary geography. AI-generated content shipped to those states needs a disclosure tag. | `state_ai_disclosure_missing_ca` |
| 4 | `check_surrogate_disclosure(post)` | Coordinated content (E19-Surrogate sub-weapon, when built) requires a coordination disclosure. STUB in this PR (returns `{allow: True}` because surrogate fires don't exist yet). | `surrogate_disclosure_missing` |
| 5 | `check_funnel_stage_gate(asset, donor)` | The hard gate from `E19_FUNNEL_STAGES.md` §4. A donor at stage X may receive content tagged for stage X or any LOWER stage. | `funnel_stage_violation` |
| 6 | `check_match_tier_gate(donor)` | Individualized targeting requires `match_tier IN ('A_EXACT', 'B_ALIAS')`. C/D/E/UNMATCHED blocked. | `match_tier_below_threshold` |
| 7 | `check_fatigue_cap(donor, period)` | Per-donor send-frequency cap by funnel stage. From `shared/fatigue_caps.py` (or inlined in this PR if not yet created). | `fatigue_cap_exceeded` |

Every gate decision lands in `core.compliance_audit` with `(source_ecosystem, gate_name, decision, reason, context_jsonb, evaluated_at)`. The audit table is your FEC paper trail.

---

## Database tables

E19 reads from / writes to:

### Reads from
- `core.donor_profile` — donor identity, lifetime totals, match_tier
- `core.donor_profile_*` views — same, with computed flags
- `core.email_consent`, `messaging_consent` — for derived `SUBSCRIBER` stage
- `core.candidate_profiles` (E03) — candidate metadata, issue lanes
- `core.communication_dna` (E48) — candidate voice profile
- `social_posts` (existing E19 table) — published posts and their metadata

### Writes to
- `social_posts` — INSERT on every fire (existing table)
- `core.e19_variant_outcomes` — INSERT on every recorded outcome (NEW in `migrations/2026-05-03_e19_social_schema.sql`)
- `core.e19_audiences` — INSERT on every audience build (NEW)
- `core.e19_donor_funnel` — INSERT/UPSERT on every stage evaluation (NEW)
- `core.e19_inbox` — INSERT on every inbound message (NEW)
- `core.compliance_audit` — INSERT on every gate decision (extended in migration)

### Does NOT touch
- `raw.ncboe_donations` — sacred. E19 reads donor_profile (the rollup), not the spine.
- Anything in `audit.*` schema — owned by the audit-log subsystem, not E19.

---

## Funnel stages

See [`docs/architecture/E19_FUNNEL_STAGES.md`](../architecture/E19_FUNNEL_STAGES.md) for the full stage definitions, transition rules, and content-stage mapping.

---

## Known gaps (what's stubbed or backlog'd)

- **E19-PaidBoost, E19-Live, E19-Surrogate, E19-Engage**: stubbed with `NotImplementedError("backlog: see ADR 2026-05-03")`. Each has a TODO link in the source.
- **Variant ranker uses placeholder scoring**: deterministic stub (length + hook strength + hashtag count). Real ML model trains on data accumulating in `core.e19_variant_outcomes`. Backlog.
- **CadenceBandit cold-start priors**: hand-set from industry conventions in `ecosystems/_e19_cadence_priors.py`. Personalization activates after 30 posts per platform per candidate.
- **shared/fatigue_caps.py**: not yet built. Inlined in `funnel_sequencer.py` as a temporary `_FATIGUE_CAPS` dict. When the shared module lands, swap.
- **shared/brain_pentad_contracts.py**: in a separate pending PR. Local fallback `_e19_contracts.py` with the same shapes, swap when shared lands.
- **News-trigger 24/7 listener**: requires a running E42 cron that's not yet in production. The trigger function is callable; the listener thread isn't running.
- **State AI disclosure laws**: the ones in code (CA, TX, MI, NJ) are not exhaustive. As more states pass laws, add to `_STATE_AI_DISCLOSURE_RULES` in `social_media.py`.
- **Compliance audit table partitioning**: at scale this table will be large (10K posts/day × 7 gates = 70K rows/day). Partition by month is backlog'd.

---

## Test coverage

13 test files under `tests/test_e19_*.py`. See each test file for what it covers; the headline contracts:

| Test | What it asserts |
|---|---|
| `test_e19_no_fake_accounts.py` | Every `poster_id` resolves to a verified registered identity |
| `test_e19_funnel_stage_gate.py` | Stranger-stage donor never receives bundler-stage content |
| `test_e19_paid_disclosure.py` | Paid posts carry FEC paid-for-by |
| `test_e19_ai_disclosure.py` | AI content carries the `ai_generated=True` metadata flag and surfaces disclosure when the audience is in CA/TX/MI/NJ |
| `test_e19_meta_24h_window.py` | DM-style sub-weapons honor Meta's 24h messaging window |
| `test_e19_match_tier_gate.py` | Only A_EXACT / B_ALIAS allowed for individualized targeting |
| `test_e19_audience_builder.py` | Donor-list audience hashes correctly for Meta upload |
| `test_e19_content_optimizer.py` | `generate_hook()` returns 20–50 variants; `rank_variants()` is deterministic given the same input |
| `test_e19_funnel_sequencer.py` | Stage transitions trigger correct content pool |
| `test_e19_news_trigger.py` | 90-min SLA from event ingestion to approval-queue submission |
| `test_e19_listening_inbox.py` | Inbound classification + AI draft + queue routing |
| `test_e19_pentad_contract.py` | Payload schemas honored both directions |
| `test_e19_compliance_gates.py` | Every gate logs its decision to `core.compliance_audit` |

All tests use `unittest.mock` to stub DB and external API calls. None require live Postgres or live platform credentials.

---

## How to extend E19

1. **New sub-weapon** → new file `ecosystems/ecosystem_19_<sub-weapon>.py`. Mirror to `backend/python/ecosystems/`. Add an `IFTTRule`-equivalent registration in `social_media.py:SocialMediaEngine.__init__`. Add a `STUB` row to the ADR sub-weapon table.
2. **New compliance gate** → new method on `SocialMediaEngine`, signature `(self, ...) → {allow: bool, reason: str}`. Register it in `_GATE_PIPELINE`. Add a row to the gate table in this doc + a test in `test_e19_compliance_gates.py`.
3. **New funnel stage** → add to `FunnelStage` enum + update `E19_FUNNEL_STAGES.md` §1, §2, §3 + add a test in `test_e19_funnel_sequencer.py`.
4. **New platform** → add to `Platform` enum + add a publisher method in `PlatformPublisher` + add a row to `_PLATFORM_ALGORITHM_MODELS` in `content_optimizer.py` + update `_STATE_AI_DISCLOSURE_RULES` if relevant.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-03. Section 12 of the E19 stealth-machine build. See ADR `docs/decisions/2026-05-03_E19_stealth_machine.md` for the rationale.*
