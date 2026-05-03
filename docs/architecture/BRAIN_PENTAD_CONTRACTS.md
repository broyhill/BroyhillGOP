# Brain Pentad Contracts — Constitution

**Version:** Brain Pentad v1.0.0
**Authoritative module:** `shared/brain_pentad_contracts.py`
**Adopted:** 2026-05-02
**Owner:** Ed Broyhill (the platform owner; Claude is a maintainer)

This document is the **constitution** for the five co-equal Brain modules of
the BroyhillGOP platform. It tells you which payloads cross which boundaries,
how the modules can and cannot talk to each other, and how the contracts
evolve.

If you are about to make a change that crosses any of the boundaries
described here, read this document first. If anything in your PR conflicts
with this constitution, the constitution wins.

---

## 1. The Pentad

Five Brain modules. Four sit on a linear loop; the fifth (E60) is a peer
that observes and acts across all four.

```
                          ┌──────────────────────┐
                          │       E60            │
                          │   Nervous Net        │
                          │  (cost ledger,       │
                          │   IFTTT engine,      │
                          │   LP optimizer)      │
                          └──────────┬───────────┘
                                     │ peer to all
              ┌──────────────────────┼─────────────────────┐
              │                      │                     │
              ▼                      ▼                     ▼
     ┌──────────────┐        ┌──────────────┐      ┌──────────────┐
     │     E01      │───────▶│     E19      │─────▶│     E30      │
     │  Donor       │        │  Personal-   │      │   Email      │
     │  Intelligence│        │  ization     │      │  Sender      │
     │ (grade_donor)│        │              │      │              │
     └──────▲───────┘        └──────────────┘      └──────┬───────┘
            │                                              │
            │             SendOutcome / BudgetSignal       │
            │                  feedback loop               │
            │                                              ▼
            │                                      ┌──────────────┐
            └──────────────────────────────────────│     E11      │
                                                   │   Budget     │
                                                   │              │
                                                   └──────────────┘
```

### Linear loop

`E01 → E19 → E30 → E11 → E01` (feedback)

| Step | Payload | Source | Sink | Module schema |
|---|---|---|---|---|
| 1 | `GradedDonor` | E01 | E19 | `shared.brain_pentad_contracts.GradedDonor` |
| 2 | `PersonalizedMessage` | E19 | E30 | `…PersonalizedMessage` |
| 3 | `SendOutcome` | E30 | E11 | `…SendOutcome` |
| 4 | `BudgetSignal` | E11 | E01 | `…BudgetSignal` |

E31 (SMS), E32 (voice), E33 (direct mail), etc. are sender modules that
substitute for E30 on a per-channel basis. They emit the same `SendOutcome`
payload shape so E11 doesn't need to know which channel a send came from.

### Nervous Net (E60)

E60 is **peer to all four** modules. It plays three roles:

1. **Cost ledger.** Every Brain module emits a `CostEvent` to E60 on every
   spend event (every send, every GPU call, every API charge). E60
   persists those events idempotently and computes per-ecosystem,
   per-donor, per-channel rollups.

2. **IFTTT rules engine.** E60 evaluates rules on every `CostEvent` and on
   a periodic tick. When a rule fires, E60 emits a `RuleFired` payload
   into the target ecosystem (e.g. "pause E30 sends — daily budget
   exceeded"; "add this address to suppression — hard bounce").

3. **LP optimizer.** E60 runs a linear-program optimizer that allocates
   spend across (channel × segment) cells subject to fatigue, grade,
   compliance, and budget constraints, and emits an `OptimizerDecision`
   to E11.

E60 NEVER overrides E11's actual budget tables; it only recommends.

---

## 2. The seven payloads

All seven live in `shared/brain_pentad_contracts.py` as **frozen Pydantic v2
models**. They are immutable after construction and serialize via
`.model_dump_json()`.

### 2.1 `GradedDonor` — E01 → E19

```python
GradedDonor(
    rnc_regid: str
    grade: Literal["A", "B", "C", "D", "F"]
    match_tier: MatchTier      # A_EXACT … UNMATCHED
    confidence: float          # 0.0 – 1.0
    inputs_hash: str           # 64-char SHA-256 hex
    graded_at: datetime        # metadata only — NOT in inputs_hash
)
```

**Determinism contract.** Same input row from `core.v_donor_profile_trusted`
or `core.v_donor_profile_needs_review` MUST produce the same
`(grade, match_tier, confidence, inputs_hash)` tuple. `graded_at` is
metadata and is intentionally excluded from `inputs_hash`.

### 2.2 `PersonalizedMessage` — E19 → E30 (or E31, E32, …)

```python
PersonalizedMessage(
    donor_id: str              # rnc_regid
    variant_id: str
    channel: Channel           # email / sms / mms / rcs / whatsapp / voice / direct_mail
    subject: Optional[str]     # required for email; None otherwise
    body: str
    cta_url: Optional[str]
    expires_at: datetime
    grade_at_personalization: GradeLetter
    match_tier: MatchTier
)
```

E30 (and E31, E32, …) MUST honor `expires_at` and MUST refuse to send if
`match_tier` is below the channel's compliance floor (see §3 hard rules).

### 2.3 `SendOutcome` — E30 / E31 / E32 → E11

```python
SendOutcome(
    send_id: str
    donor_id: str              # rnc_regid
    channel: Channel
    cost_cents: int
    delivered: bool
    opened: bool
    clicked: bool
    revenue_cents: int
    fatigue_delta: float
    sent_at: datetime
    bounce_type: Optional[Literal["hard","soft","none"]]
    complaint: bool
    unsubscribed: bool
)
```

Sender modules emit one `SendOutcome` per terminal event (delivered,
opened, clicked, bounced, complained, unsubscribed, conversion).

### 2.4 `BudgetSignal` — E11 → E01

```python
BudgetSignal(
    period: Literal["1d","7d","30d","90d"]
    per_grade_roi: Dict[GradeLetter, float]
    per_tier_roi: Dict[MatchTier, float]
    reallocation_flags: List[str]
    computed_at: datetime
)
```

E01 may use this to recalibrate scoring or to recommend
re-engagement / suppression in the next grading pass. E01 MUST NOT
write the BudgetSignal back into the donor view.

### 2.5 `CostEvent` — any Brain module → E60

```python
CostEvent(
    event_id: str              # stable; same logical event => same id
    source_ecosystem: str      # E01 / E19 / E30 / E31 / E50 / E60 / etc.
    donor_id: Optional[str]    # rnc_regid if attributable; None for shared infra
    cost_type: CostType        # send / print / gpu / ai_inference / …
    vendor: str                # 'twilio', 'sendgrid', 'openai', 'hetzner', …
    unit_cost_cents: int
    quantity: int
    total_cost_cents: int      # MUST equal unit_cost_cents * quantity
    revenue_attributed_cents: int
    occurred_at: datetime
)
```

`event_id` MUST be stable for the same logical event so E60's cost ledger
can deduplicate on replay. `total_cost_cents` is denormalized but validated
by the Pydantic model.

### 2.6 `RuleFired` — E60 → any Brain module

```python
RuleFired(
    rule_id: str               # 'block_unmatched_outbound', etc.
    target_ecosystem: str
    action: str                # 'pause_sends', 'add_to_suppression', 'rerun_grading'
    payload: Dict[str, Any]
    fired_at: datetime
    audit_trail_id: str        # UUID into core.iftt_rule_fires
)
```

The target ecosystem MUST audit the `RuleFired` and MAY refuse the action
(with explanation in its own audit log). Targets are NOT obligated to act
on every RuleFired — they're authoritative over their own internals.

### 2.7 `OptimizerDecision` — E60 → E11

```python
OptimizerDecision(
    allocations: List[Dict[str, Any]]   # per (channel, segment) recommendations
    expected_revenue_cents: int
    constraints_satisfied: bool
    model_version: str
    decided_at: datetime
)
```

E11 is the authoritative budget owner — `OptimizerDecision` is a
recommendation E11 may apply or reject.

---

## 3. Hard rules

These are non-negotiable. Violations should fail PR review.

### Rule P-1 — Boundary discipline

The five Brain ecosystems **NEVER import each other**. They only import
from `shared.brain_pentad_contracts`.

```python
# OK
from shared.brain_pentad_contracts import GradedDonor

# NOT OK — boundary violation
from ecosystems.ecosystem_01_donor_intelligence import grade_donor
```

If E19 wants a graded donor, it consumes a `GradedDonor` from a queue or
event bus. It does NOT reach into E01's process and call `grade_donor()`
directly.

### Rule P-2 — Coordinated versioning

Contract changes require a coordinated PR across all five ecosystems. Bump
`BRAIN_PENTAD_VERSION` together with each affected ecosystem's compatibility
pin (see §5 version table).

### Rule P-3 — Encapsulation

Each ecosystem owns its internals. Do not reach across boundaries to inspect
another ecosystem's tables, call its private methods, or mutate its state.
The only authorized signaling is via the seven payloads above.

### Rule P-4 — E60 is the only rule-firer

Other Brain modules may emit `CostEvent` to E60 freely, but only E60 is
allowed to fire `RuleFired` payloads INTO other Brain modules. Other modules
NEVER call each other's pause / throttle / rerun primitives directly.

### Rule P-5 — Sender compliance gate

`PersonalizedMessage.match_tier` is the spine match confidence band. Sender
ecosystems (E30, E31, E32, …) MUST refuse to send if `match_tier` is below
the channel's compliance floor:

| Channel | Allowed tiers |
|---|---|
| Email | A_EXACT, B_ALIAS |
| SMS / MMS / RCS | A_EXACT, B_ALIAS (per TCPA) |
| WhatsApp | A_EXACT only (per WhatsApp Business policy) |
| Voice | A_EXACT, B_ALIAS (per TCPA) |
| Direct mail | A_EXACT, B_ALIAS, C_FIRST3 (lower bar — postage waste, not legal risk) |

D_HOUSEHOLD, E_WRONG_LAST, UNMATCHED are blocked at the sender for all
electronic channels.

---

## 4. Joint test harness

Located at `tests/test_brain_pentad_loop.py`. Runs a synthetic donor through
the full loop and asserts every contract holds.

The harness exercises:

1. **E01.grade_donor** produces a valid `GradedDonor` from a synthetic row.
2. **E19** would consume it and produce a `PersonalizedMessage` (stubbed).
3. **E30** would consume that and produce a `SendOutcome` (stubbed).
4. **E11** rolls `SendOutcome`s into a `BudgetSignal` (stubbed).
5. **E60** observes every step:
   - Receives a `CostEvent` for each send.
   - Fires at least one `RuleFired` (e.g. budget threshold).
   - Emits an `OptimizerDecision` for E11.

Every PR that touches any of the five ecosystems MUST keep
`tests/test_brain_pentad_loop.py` passing. If your PR breaks the loop,
either (a) fix it in your PR, or (b) coordinate a cross-ecosystem
contract bump and update the harness.

---

## 5. Version table

| Brain Pentad | E01 ver. | E19 ver. | E30 ver. | E11 ver. | E60 ver. | Notes |
|---|---|---|---|---|---|---|
| **v1.0.0** | 1.0+ | TBD | TBD | TBD | TBD | Initial constitution. `GradedDonor`, `PersonalizedMessage`, `SendOutcome`, `BudgetSignal`, `CostEvent`, `RuleFired`, `OptimizerDecision`. |

To add a row: bump `BRAIN_PENTAD_VERSION` in `shared/brain_pentad_contracts.py`,
update each ecosystem's compatibility pin, and append a row above with the new
version + breaking-change summary.

---

## 6. Anti-patterns

Things not to do. Each of these is a smell that the constitution is being
worked around rather than evolved.

| Anti-pattern | Why it's bad | What to do instead |
|---|---|---|
| Importing another Brain ecosystem directly | Breaks Rule P-1 | Use the shared payload via queue / event bus |
| Adding a field to a payload without bumping version | Silent breakage downstream | Coordinated PR + version bump |
| Calling another ecosystem's pause / throttle method | Breaks Rule P-4 | Emit a `CostEvent` to E60 and let E60 fire a `RuleFired` |
| Sender ignoring `match_tier` gate | Breaks Rule P-5 (and TCPA / FEC) | Enforce the gate in `send()` |
| Storing a `RuleFired` payload as a side-effect of another action | Loses audit trail | Only E60 writes to `core.iftt_rule_fires` |
| Mutating a payload after construction | Can't — they're frozen | Build a new payload |

---

## 7. Out of scope (for v1.0.0)

These are tracked but not addressed by the v1.0.0 constitution:

- **Schema migrations.** Payload field additions; nothing here defines how
  to migrate persisted historical events when a payload changes.
- **Cross-language clients.** The constitution is Python-only at v1.0. If a
  non-Python client (e.g. a JS dashboard) needs to consume payloads, we'll
  need a JSON Schema export — straightforward via Pydantic but separate work.
- **Event bus choice.** This document is about wire format, not transport.
  The current implementation uses Postgres `LISTEN/NOTIFY` and direct
  function calls; a future PR may move to Redis Streams or NATS without
  changing the contracts.

---

*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02.*
*Authorized by Ed Broyhill — STEP 3 of `CLAUDE_NEXT_STEPS_2026-05-02`.*
