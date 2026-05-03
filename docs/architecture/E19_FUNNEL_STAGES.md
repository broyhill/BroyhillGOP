# E19 Funnel Stages — Donor Lifecycle for Social Content Targeting

**Version:** 1.0 (2026-05-03)
**Owner:** Ed Broyhill
**Authoritative module:** `ecosystems/ecosystem_19_funnel_sequencer.py`
**Persistence:** `core.e19_donor_funnel`

This document is the source of truth for **what content a donor sees at what stage of their relationship with the candidate.** Content gets tagged with a `content_stage`. Donors get tagged with a `funnel_stage`. The serving rule is a **hard gate** — stranger-stage donors NEVER receive bundler-stage content, no matter who told the system to send it.

If you change a stage definition, transition rule, or content mapping, **update this file in the same PR.** A stage doc that disagrees with the live code is worse than no doc.

---

## 1. Stage definitions (7 stages)

| Stage | Code | Definition | Typical signal that puts a donor here |
|---|---|---|---|
| **Stranger** | `STRANGER` | Has never interacted with the candidate. May not even know who the candidate is. Lookalike or cold-list match only. | No record in `core.donor_profile`; came in via E56 visitor de-anon or E04 activist network match |
| **Aware** | `AWARE` | Knows the candidate exists. Has seen content. Has not yet engaged. | Has had ≥3 ad impressions or ≥1 social engagement (like, follow); zero donation history |
| **Engaged** | `ENGAGED` | Has clicked, replied, watched a video to completion, or visited the campaign site. Demonstrates active interest. | ≥1 click in last 90 days OR ≥1 video completion OR ≥1 inbound message; zero donation history |
| **Subscriber** | `SUBSCRIBER` | Opted into email or SMS. Receives owned-channel communications. | Row in `core.email_consent` with `opted_in_at` set OR row in `messaging_consent` with `sms_status='opted_in'` |
| **Small donor** | `SMALL_DONOR` | Has given ≥1 donation under $250 lifetime. | `core.donor_profile.lifetime_total > 0 AND lifetime_total < 25000` (cents) |
| **Repeat donor** | `REPEAT_DONOR` | Has given ≥3 donations OR ≥$500 lifetime. | `txn_count >= 3 OR lifetime_total >= 50000` (cents) |
| **Bundler** | `BUNDLER` | Has either (a) given ≥$2,500 lifetime, (b) been tagged as a bundler in `core.donor_profile`, or (c) hosted/co-hosted ≥1 fundraising event. | `lifetime_total >= 250000` (cents) OR `is_bundler = TRUE` in donor_profile OR appears in event-host tables |

The Python enum lives at `ecosystems/ecosystem_19_funnel_sequencer.py:FunnelStage`.

---

## 2. Stage transitions (one-way only, with re-evaluation)

Donors can only move FORWARD in the funnel. They never move backward. If a donor in `REPEAT_DONOR` lapses for 12+ months, they stay tagged `REPEAT_DONOR` (lapsed) — they don't become `STRANGER` again. Backward demotion would create absurd content (sending "no_ask issue education" to someone who's already given $5,000 nine months ago) and is explicitly forbidden.

Re-evaluation cadence: `core.e19_donor_funnel.last_evaluated_at` is touched whenever a donor's stage is recomputed. The recompute job runs nightly. A donor whose `lifetime_total` changes during the day gets re-evaluated on the next run. Stage changes write a new value to `funnel_stage` AND update `stage_entered_at`.

Lapsed donors are tagged via a separate `lapsed_at` timestamp (NOT in this PR's schema; backlog'd). Content for lapsed donors goes through a re-engagement track that's NOT yet built.

---

## 3. Content stage mapping (the hard gate)

Every content asset MUST be tagged with one or more `content_stage` values. Every audience MUST resolve to a `funnel_stage`. The serving function `allowed_content_stages(donor_stage)` returns the SET of content stages a donor at that stage is allowed to receive.

### Per-stage content rules

#### `STRANGER` → allowed: `issue_education`, `no_ask`, `no_candidate_face`

Strangers have no relationship with the candidate. Showing them the candidate's face or an ask cold-converts at near-zero rate AND wastes spend. Content is issue-first, candidate-anonymous, no donation ask. Examples: "NC needs better roads — here's the current state of road funding." Educational, factual, share-worthy.

**Hard NO:** photos of the candidate's face above the fold, donation buttons, "join our team" recruiting, anything tagged as `donor_focused_content`.

#### `AWARE` → allowed: `candidate_humanization`, `story`, `family`, `values`, `issue_education`, `no_ask`

Now they know the candidate exists. Goal is humanization — make the candidate someone the viewer would want to have coffee with. Personal story content, family content (with consent), values-based content. Still no donation ask.

**Hard NO:** donation asks, bundler-tier content, peer-validation content ("others like you are giving").

#### `ENGAGED` → allowed: everything from AWARE plus `issue_alignment`, `position_clarification`, `policy_deep_dive`

The viewer is actively interested. Now we can talk policy and align on issues. Issue alignment = which of the 60 hot-button issues the viewer has indicated interest in (via E07 issue tracking). Content matches inferred concerns — climate-anxious viewer gets climate content; second-amendment viewer gets 2A content.

**Hard NO:** donation asks (still — they haven't subscribed yet), bundler content.

#### `SUBSCRIBER` → allowed: everything from ENGAGED plus `behind_the_scenes`, `intimacy`, `low_friction_ask`

The viewer opted in. They've consented to ongoing communication. Content can now be more intimate (behind-the-scenes from the candidate's day, personal video selfies). First-ask content is allowed but must be low-friction ($5, $10, $25 buttons; not big asks).

**Hard NO:** bundler content, peer-validation that names specific other donors (privacy violation).

#### `SMALL_DONOR` → allowed: everything from SUBSCRIBER plus `impact_report`, `funded_this`, `medium_ask`

The viewer gave money. Show them what their money funded. "Your $25 funded the canvass that knocked 200 doors in Mecklenburg County last weekend." Concrete impact. Medium asks ($50, $100, $250) are allowed.

**Hard NO:** bundler-tier requests, "host an event for me" content.

#### `REPEAT_DONOR` → allowed: everything from SMALL_DONOR plus `peer_validation`, `larger_ask`, `community_signal`

The viewer is committed. Peer-validation content is now appropriate ("3 others in your zip code gave $500 this week"). Larger asks ($500–$1,000) are allowed. Community-signal content reinforces that they're part of a serious cohort.

**Hard NO:** sharing other named donors without consent (always anonymized in peer-validation copy).

#### `BUNDLER` → allowed: everything plus `vip_access`, `exclusive_briefing`, `host_invite`, `inner_circle`

The viewer is a leader. Content is exclusive — invite-only briefings, candidate's personal cell access, host-an-event invitations, inner-circle policy previews. The "ask" is no longer just money; it's the bundler's network and time.

---

## 4. The serving rule (hard gate)

```python
def allowed_content_stages(donor_stage: FunnelStage) -> set[ContentStage]:
    """Returns the set of content stages a donor at `donor_stage` MAY receive.
    Anything outside this set is BLOCKED at the gate, not warned."""

# Rule: a donor at stage X may receive content tagged for stage X or any LOWER stage.
# A bundler may receive everything. A stranger may receive ONLY stranger-tier content.
```

A serving call that violates this rule MUST be blocked at `check_funnel_stage_gate(asset, donor)` in `ecosystem_19_social_media.py`. The block emits a row to `core.compliance_audit` with `decision='block'` and `reason='funnel_stage_violation'`.

---

## 5. Asset tagging conventions

Every social asset gets a `content_stage` (the lowest stage it's appropriate for) AND a `funnel_stage_targets` array (the stages it's specifically optimized for). An asset tagged `content_stage='issue_education'` with `funnel_stage_targets=['STRANGER', 'AWARE']` is appropriate for both stages but optimized for stranger-tier acquisition.

The tag lives in `social_posts.content_stage` (single value) and `social_posts.funnel_stage_targets` (JSONB array). Both columns added in `migrations/2026-05-03_e19_social_schema.sql`.

---

## 6. Examples (real assets, real stages)

| Asset | Content stage | Funnel target | Why |
|---|---|---|---|
| 30-sec issue video on rural broadband (no candidate face) | `issue_education` | `STRANGER`, `AWARE` | Strangers can engage; doesn't push the candidate yet |
| Candidate selfie video at his daughter's soccer game | `family` | `AWARE`, `ENGAGED` | Humanization; not appropriate for strangers (too intimate cold) |
| "Here's what your $25 bought us last week" post with photos of the canvass | `funded_this` | `SMALL_DONOR`, `REPEAT_DONOR` | Donors only — meaningless to non-donors |
| Invite to an off-the-record briefing on the 2026 strategy | `inner_circle` | `BUNDLER` | Bundler-only — sending this to a small donor would feel weird and burn the asset's exclusivity |
| Quote tweet of a positive press story | `issue_alignment` | `ENGAGED`, `SUBSCRIBER` | Engaged viewers will share; strangers won't recognize the news cycle reference |

---

## 7. Editing this document

When you propose a new content stage, add a new row in §3 with the rule. When you change which stages a donor can move between, update §2. When the recompute logic changes, update the cadence in §2.

Test coverage for stage gating lives at `tests/test_e19_funnel_stage_gate.py`. If you change the rule, the test breaks first — that's the canary.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-03. Section 12 of the E19 stealth-machine build.*
