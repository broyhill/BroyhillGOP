# Section 8 — E60 Nervous Net (Design + Rationale)

**Status:** PR pushed, NOT merged. Branch `claude/section-8-e60-nervous-net-2026-05-02` (commit `36145cc`).
**Brain Pentad role:** E60 — peer to the four linear-loop modules (E01, E19, E30, E11).
**DDL status:** ⚠️ Three new tables in the `core` schema. Migration staged at `database/migrations/200_e60_nervous_net.sql` — **REQUIRES `I AUTHORIZE THIS ACTION` from Ed before applying.**
**Tests:** 29 unit tests, all passing across 4 test files.

---

## Why this PR existed

The Brain Pentad architecture (defined in `docs/architecture/BRAIN_PENTAD_CONTRACTS.md`) calls for a fifth module — the "nervous net" — that doesn't fit on the linear E01→E19→E30→E11 loop. It's a peer to all four, with three responsibilities:

1. **Universal cost ledger.** Every Brain module emits a `CostEvent` on every spend (per send, per GPU minute, per API token). The cost ledger persists them idempotently and computes rollups.
2. **IFTTT rules engine.** Watches for trouble (hard bounces, budget overruns, low-confidence donor matches) and fires actions into the right module via `RuleFired` payloads.
3. **LP optimizer.** Decides where to put the next dollar — allocates spend across (channel × segment) cells subject to fatigue / grade / TCPA / budget constraints. Emits `OptimizerDecision` to E11.

Without E60, the Brain Pentad has no observability, no cross-cutting governance, and no allocation optimization. Each linear-loop module would have to reinvent its own cost tracking and threshold rules.

## Architectural decision: peer, not gatekeeper

E60 is a **peer**, not a **gatekeeper**. The other Brain modules don't have to ask E60 for permission to act — they emit events and continue. E60 observes asynchronously and may fire `RuleFired` payloads back to direct an action, but the target module is authoritative over its own internals (per Pentad Rule P-3) and may refuse the action with audit-logged reasoning.

This separation is critical: if E60 went down, the other Brain modules would keep running. They'd lose observability and rule-driven adaptive behavior, but the linear loop would still execute.

## What was built — three sub-modules

```
ecosystems/e60/
├── __init__.py
├── cost_ledger.py     (150 lines)
├── iftt_engine.py     (202 lines)
└── ml_optimizer.py    (227 lines)
```

### cost_ledger.py

```python
ledger = CostLedger(db_url)
ledger.write(cost_event) → bool          # True if persisted, False if duplicate
ledger.rollup_per_ecosystem(since=...) → list[dict]
ledger.daily_burn_cents(on_date=...) → int

# Convenience helper:
log_cost(cost_event, db_url) → bool
```

**Idempotency:** writes use `ON CONFLICT (event_id) DO NOTHING`. Same `event_id` is a no-op on re-write. This is critical because in production, network retries on the emit-side WILL produce duplicate events. The `event_id` convention per Pentad spec is `f"{source_ecosystem}:{cost_type}:{vendor_id}:{occurred_at_iso}"` or a UUID derived from the underlying provider's idempotency key — either way, stable per logical event.

### iftt_engine.py

```python
engine = IFTTEngine(db_url, rules=SEED_RULES)
fires: list[RuleFired] = engine.evaluate(payload)
fires = engine.evaluate_cost_event(cost_event)
```

Each `IFTTRule` has a `predicate(payload) → bool` and a `payload_builder(payload) → dict`. When `predicate` returns True, the engine builds a `RuleFired` with the constructed payload, persists an audit row to `core.iftt_rule_fires`, and returns the fire to the caller (who is responsible for actually delivering it to the target ecosystem).

**Four seed rules** (the spec mandates these exact four):

| `rule_id` | Predicate | Action | Target |
|---|---|---|---|
| `hard_bounce_suppress_and_regrade` | `bounce_type == 'hard'` | `add_to_suppression` (with `follow_up.target=E01, action=rerun_grading`) | E30 |
| `high_confidence_cluster_recommend` | `cross_spine_match_confidence > 0.95` | `recommend_rnc_regid_stamp` (recommend only; never auto-stamps) | E01 |
| `low_match_tier_block_outbound` | `match_tier IN ('E_WRONG_LAST', 'UNMATCHED')` | `add_to_suppression` | E30 |
| `daily_budget_breach_pause_sends` | `daily_burn_cents > daily_cap_cents` | `pause_sends` | E30 |

The "high_confidence_cluster" rule is intentionally a recommendation only — it does NOT auto-stamp `rnc_regid` onto a cluster. E01 may apply or reject; never auto-writes. This preserves the human-in-the-loop expectation Ed has voiced repeatedly about not auto-modifying his stamps.

### ml_optimizer.py

```python
optimizer = MLOptimizer(db_url=...)
decision: OptimizerDecision = optimizer.decide(lp_problem)
```

The `LPProblemStatement` is a frozen dataclass that carries:

```
OBJECTIVE
    max  Σ_{c, s}  spend[c,s] * predicted_revenue_per_cent[c,s]

CONSTRAINTS
    1. Daily budget cap            Σ spend ≤ daily_cap_cents
    2. Per-channel fatigue cap     Σ_s spend[c,s]/unit_cost[c] ≤ max_sends_per_day[c]
    3. Per-grade fatigue cap       Σ_{(c,s) where s.grade=g} spend/unit_cost ≤ max_sends_per_grade_per_day[g]
    4. TCPA/channel compliance     spend[email, s] = 0 if s.match_tier ∉ {A_EXACT, B_ALIAS}, etc.
    5. Non-negativity              spend[c,s] ≥ 0
```

Trivial feasible point: `spend = 0` everywhere (objective = 0). The optimizer's job is to find a non-trivial maximum.

**`decide()` is a placeholder allocator** in this PR — even split across the first 3×3 cells, then enforce the daily cap and Rule P-5 channel/tier compliance. **Real LP solving (scipy.optimize.linprog) lands in a follow-up PR** alongside trained predictive models.

**Predictive interfaces are stubs** that raise `NotImplementedError` — this is intentional per the spec ("Stub predictive model interfaces (no trained models yet)"):

- `p_donate(inputs)` — calibrated GBM classifier on (donor × channel × time-of-day × time-of-week × past-send-history)
- `p_unsubscribe(inputs)` — sequence-aware (RNN/transformer) over recent send history
- `expected_gift_amount(inputs)` — regression on (lifetime_total × largest_gift × match_tier × channel × time-since-last-gift)
- `optimal_send_time(inputs)` — per-donor GMM over historical open/click times

Training data sources, scheduled retraining, and model versioning are documented in code comments and tracked for the follow-up PR. Don't implement training in this PR.

## DDL — three new tables (additive only)

`database/migrations/200_e60_nervous_net.sql` — **NOT applied to the live DB; staged for Ed's `I AUTHORIZE THIS ACTION`.**

```sql
core.cost_ledger (
    event_id, source_ecosystem, donor_id, cost_type, vendor,
    unit_cost_cents, quantity, total_cost_cents, revenue_attributed_cents,
    occurred_at, created_at
)
-- 3 indexes: source_ecosystem, donor_id (partial WHERE NOT NULL), occurred_at

core.iftt_rules (
    rule_id, name, condition_sql, action_payload (jsonb),
    target_ecosystem, enabled, created_by, created_at
)

core.iftt_rule_fires (
    fire_id, rule_id, fired_at, target_payload (jsonb), outcome
)
-- 2 indexes: rule_id, fired_at
```

**Safety constraints:**
- All `CREATE TABLE IF NOT EXISTS` — idempotent.
- All on the `core` schema (not `raw`).
- Does NOT touch `raw.ncboe_donations` or any `core.donor_profile*` table or view.
- Seeded with the 4 mandated rules (`ON CONFLICT (rule_id) DO NOTHING`).
- Rollback plan included as a SQL comment block at the bottom of the migration file.

## Cross-wiring into E30 and E31

Section 8 also added one-line cost-emission helpers into the two sender ecosystems:

**E30** (added to `EnterpriseEmailSender`):
```python
sender.emit_cost_to_e60(outcome, vendor="sendgrid", db_url=...)
# Calls e60.log_cost() with the CostEvent built from the SendOutcome.
```

**E31** (module-level helper):
```python
from ecosystem_31_sms import emit_send_cost_to_e60
emit_send_cost_to_e60(send_outcome_dict, vendor="twilio", db_url=...)
```

Both wires use **lazy imports** of `e60` (at call time, not module load time). This keeps Pentad Rule P-1 honest: if E60 is down or hasn't been deployed, the sender ecosystems still load and run; they just lose cost-tracking until E60 comes back.

## Tests (29 across 4 files)

**`test_e60_cost_ledger_idempotency.py` (4):** First write returns True. Duplicate write returns False. Same event_id only persisted once. SQL uses `ON CONFLICT (event_id) DO NOTHING`.

**`test_e60_rule_firing.py` (9):** All 4 seed rules fire on the right inputs and only those. Hard bounce → fires hard rule, NOT on soft. High-confidence rule recommends only (never auto-stamps). Low-match-tier rule fires on `E_WRONG_LAST`/`UNMATCHED`, NOT on `A`/`B`/`C`/`D`. Daily-budget rule fires when burn > cap, NOT when under. `SEED_RULES` contains exactly 4 rules. All fires are `RuleFired` Pydantic instances.

**`test_e60_lp_problem_well_formed.py` (10):** Default statement has positive budget, ≥1 channel, ≥1 segment. Unit costs defined per channel. Max-sends-per-grade defined for A/B/C/D/F. Statement is immutable (frozen). Trivial feasible point exists. `decide()` returns `OptimizerDecision`. `decide()` honors budget cap. `decide()` excludes electronic channels for low-tier segments (Rule P-5). `decide()` carries `model_version`.

**`test_e60_pentad_contract.py` (6):** Cost ledger consumes `CostEvent` in. IFTTT engine emits `RuleFired` out (raw + via `evaluate_cost_event`). Optimizer emits `OptimizerDecision` out. **Rule P-1 verified by AST scan** — E60 modules import only from `shared`, not from any other ecosystem.

## What this PR did NOT change

- The four other Brain modules (E01, E19, E30, E11) — except for the one-line cost-emission wiring in E30 and E31.
- Any existing schema tables.
- Any existing data.
- The `raw.ncboe_donations` spine.

## Migration order

This PR depends on the Pentad contracts PR (defines `CostEvent`, `RuleFired`, `OptimizerDecision`). Recommended merge order:

1. Pentad contracts PR
2. Section 1 (E01)
3. Section 7 (E30)
4. **This PR** (Section 8 E60 — depends on Pentad + does light wiring into E30/E31)
5. **Then** authorize the E60 DDL migration

## Known limits / explicitly deferred

- **No real LP solver yet.** `decide()` returns a placeholder allocation. Plug in `scipy.optimize.linprog` in the follow-up PR.
- **No trained predictive models.** `p_donate`, `p_unsubscribe`, `expected_gift_amount`, `optimal_send_time` all `raise NotImplementedError`. Training pipeline + scheduled retraining are tracked for the follow-up PR.
- **No periodic tick yet.** The IFTTT engine evaluates rules when `evaluate()` is called (typically per CostEvent). The spec also calls for a 60-second tick — that needs a background worker (cron, systemd timer, or in-process scheduler), not in scope here.
- **Per-rule SQL conditions not yet evaluated.** `core.iftt_rules.condition_sql` is stored but not yet executed by the engine. The Python predicates (`SEED_RULES`) are the live evaluation path. Wiring SQL evaluation is a follow-up.
- **No `RuleFired` delivery layer.** `evaluate()` returns a list of `RuleFired` payloads but doesn't push them to the target ecosystem. The caller is responsible for routing — typically a small dispatcher that maps `target_ecosystem='E30'` to a queue or HTTP call.

## ⚠️ DDL authorization required

Reply with `I AUTHORIZE THIS ACTION` to apply `database/migrations/200_e60_nervous_net.sql` to Hetzner. Until then, the E60 modules will still load and parse, but `CostLedger.write()` will throw at the first invocation because `core.cost_ledger` doesn't exist yet.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02. PR pushed but NOT merged.*
