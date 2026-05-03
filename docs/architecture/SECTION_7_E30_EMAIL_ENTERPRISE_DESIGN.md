# Section 7 — E30 Email Enterprise Rewrite (Design + Rationale)

**Status:** PR pushed, NOT merged. Branch `claude/section-7-e30-email-enterprise-2026-05-02` (commit `fa515d7`).
**Brain Pentad role:** E30 — third node in the Pentad linear loop.
**Compliance class:** ⚠️ CAN-SPAM + FEC + TCPA-adjacent. The compliance gate added here is the primary legal safeguard for fundraising email.
**Tests:** 45 unit tests, all passing across 6 test files.

---

## Why this PR existed

Pre-rewrite, `ecosystems/ecosystem_30_email.py` was 1,879 lines of "Marketo-clone scaffolding." It had:

- ✅ A/B testing engine (good — kept)
- ✅ Drip sequences (good — kept)
- ✅ Send-time optimizer (good — kept)
- ✅ Personalization engine (good — kept)
- ✅ Provider abstraction (SendGrid + mock — kept)
- ✅ Template + campaign + recipient management (good — kept)
- ❌ **Zero CAN-SPAM compliance footer**
- ❌ **Zero FEC "paid for by" disclaimer**
- ❌ **Zero consent ledger** — sends went out to anyone in the campaign's recipient list, no opt-in check
- ❌ **Zero suppression list** — hard bounces and unsubscribes weren't blocked from future sends
- ❌ **Zero DKIM/SPF/DMARC validation** — sending domain reputation was uninstrumented
- ❌ **Zero IP warmup schedule** — new sender IPs would have hit volume limits immediately
- ❌ **Zero bounce classifier** — hard vs soft was undifferentiated
- ❌ **Zero spine integration** — sends were keyed on raw email, not `rnc_regid`; no `match_tier` gate
- ❌ **Zero fatigue tracking** — no per-grade caps on send volume
- ❌ **Zero Pentad wiring** — couldn't consume `PersonalizedMessage` or emit `SendOutcome`/`CostEvent`

The combination is the textbook profile of a system that gets the campaign **sued under CAN-SPAM** ($43,792 per non-compliant email per recent FTC enforcement) **or blacklisted by major mailbox providers** before the first real fundraising push.

## Decision: augment in place, don't rewrite

The "good pieces" listed above represent real engineering work — A/B, drips, send-time optimization, personalization. Tearing them down to rebuild a compliant version would **discard known-working code** with no behavior tests to backstop a rewrite.

**Picked: augment in place.** Keep the existing classes verbatim. Add a parallel set of compliance + spine + Pentad classes (`ConsentLedger`, `SuppressionList`, `ComplianceFooter`, `DeliverabilityConfig`, `BounceClassifier`, `EnterpriseEmailSender`). The new `EnterpriseEmailSender.send_personalized_message()` becomes the canonical public entry point. The legacy `EmailMarketingSystem` is composed in but its public methods are NOT re-exposed.

Net diff: +450 lines, no deletions of existing logic.

## What was added

### 1. ComplianceFooter

```python
ComplianceFooter(
    sender_org_name: str,
    physical_address: str,                    # CAN-SPAM mandate; min 10 chars
    unsubscribe_url_template: str = "https://bgop.email/unsubscribe/{token}",
    paid_for_by: Optional[str] = None,        # FEC "paid for by ..."
    not_authorized_disclaimer: bool = False,  # FEC if not from a candidate's committee
)
```

Two methods:
- `render_html(recipient_email, recipient_token, is_fundraising) → str` — produces the footer block with physical address, unsubscribe link (with per-recipient token), and (if fundraising) paid-for-by + optional not-authorized.
- `validate_message(body_html, recipient_token, is_fundraising) → {compliant: bool, violations: list[str]}` — inspects a fully-rendered email body for the four compliance markers.

The constructor enforces a non-empty sender_org_name and a min-10-char physical_address. There's no graceful degradation here — sending without a real address is a CAN-SPAM violation.

### 2. ConsentLedger

```python
ConsentLedger(db_url=...)
   .has_consent(email, require_double_opt_in=False) → {consented: bool, reason: str, row: dict|None}
```

Reads `core.email_consent` (assumed schema, not created in this PR). Returns `consented=False` for `no_consent_record`, `consent_revoked`, or `double_opt_in_pending`.

### 3. SuppressionList

```python
SuppressionList(db_url=...)
   .is_suppressed(email) → bool
   .add(email, reason, source_send_id=None, permanent=True) → bool
```

Reads/writes `core.email_suppression` (assumed schema, not created in this PR). Reasons constrained to `HARD_BOUNCE`, `COMPLAINT`, `UNSUBSCRIBE`, `MANUAL` — others raise `ValueError`. Idempotent UPSERT on email.

### 4. DeliverabilityConfig

Two static helpers:
- `daily_cap(days_in_use) → int` — enforces an industry-standard IP warmup schedule. Day 1: 50 emails. Day 7: 1,000. Day 14: 10,000. Day 21: 25,000. Day 30+: 50,000 (full volume).
- `validate_dns(sending_domain) → {spf_ok, dkim_ok, dmarc_ok, ready_to_send, ...}` — a stub for now. In production this calls dnspython to verify SPF (`v=spf1 include:...`), DKIM (`v=DKIM1;...`), and DMARC (`v=DMARC1;...`) records.

### 5. BounceClassifier

- `classify(provider_response) → 'hard' | 'soft' | 'none'` — based on SMTP code (5xx = hard, 4xx = soft, 2xx = none).
- `should_suppress(bounce_type, soft_retry_count) → bool` — hard always; soft after 3 retries.

### 6. EnterpriseEmailSender (the public entry point)

```python
sender = EnterpriseEmailSender(
    db_url=...,
    sender_org_name="BroyhillGOP",
    physical_address="PO Box 1234, Raleigh, NC 27601",
    paid_for_by="Broyhill for State Auditor",
    sending_domain="bgop.email",
)

# Pentad-facing public API:
outcome: SendOutcome = sender.send_personalized_message(
    msg=personalized_message,    # PersonalizedMessage from E19
    recipient_email="ed@broyhill.net",
    is_fundraising=True,
    force=False,                 # set True only for transactional / legal-required emails
)

# Cost emission to E60:
cost: CostEvent = sender.build_cost_event_for(outcome, vendor="sendgrid")
sender.emit_cost_to_e60(outcome, vendor="sendgrid")  # added by Section 8

# RuleFired subscription from E60:
result = sender.handle_rule_fired(rule_fired_payload)  # supports pause_sends, throttle_sends, add_to_suppression
```

## The send gate (the most important behavior change)

`send_personalized_message()` runs **four gates in order**. Any failed gate returns a no-charge SendOutcome with `delivered=False` and `blocked_by` set. No DB write to `messaging_sends`, no provider call, no cost.

1. **match_tier gate.** Per Brain Pentad Rule P-5, only `A_EXACT` and `B_ALIAS` are sendable for email. C/D/E/F/UNMATCHED are blocked. (`EMAIL_ALLOWED_TIERS = frozenset({A_EXACT, B_ALIAS})`)
2. **Suppression gate.** Global suppression list check. Hard bounces, complaints, unsubscribes block all future sends.
3. **Consent gate.** `core.email_consent` must have an opted-in row that's not revoked. If `require_double_opt_in=True` is configured, the row must also have `double_opt_in_confirmed=True`.
4. **Compliance footer gate.** The rendered body MUST contain the physical address + unsubscribe token + (if fundraising) the paid-for-by disclaimer. Built and verified by `ComplianceFooter`.

The `force=True` parameter bypasses gates 2, 3, and 4 (but NOT gate 1 — match_tier is non-bypassable). Reserve `force=True` for transactional sends mandated by law (e.g., a 1099 receipt).

## Brain Pentad integration

- **Imports ONLY from `shared.brain_pentad_contracts`** (Rule P-1 — verified by an AST test in `test_e30_pentad_contract.py`).
- **Consumes** `PersonalizedMessage` from E19.
- **Produces** `SendOutcome` (returned to caller; E11 picks up via the rollup pipeline).
- **Produces** `CostEvent` via `build_cost_event_for()` / `emit_cost_to_e60()`. Per-send-id idempotent (`event_id = f"E30:send:{send_id}"`).
- **Subscribes** to `RuleFired` with `target_ecosystem='E30'` via `handle_rule_fired()`. Supported actions: `pause_sends`, `throttle_sends`, `add_to_suppression`.

## Tests (45 across 6 files)

**`test_e30_canspam.py` (8):** physical address, unsubscribe link, sender ID rendered correctly; constructor validation rejects empty/short addresses; body validation rejects non-compliant bodies.

**`test_e30_fec_disclaimer.py` (4):** "paid for by" rendered for fundraising emails, NOT for non-fundraising; "not authorized by candidate" disclaimer when set; validation rejects fundraising email without paid-for-by.

**`test_e30_suppression.py` (3):** suppressed addresses blocked; only the 4 valid reasons are accepted; reasons constants exist.

**`test_e30_consent.py` (5):** no consent / revoked / double-opt-in-pending all block; valid consent allows; force=True bypasses consent.

**`test_e30_match_tier_gate.py` (7):** A_EXACT / B_ALIAS allowed; C_FIRST3 / D_HOUSEHOLD / E_WRONG_LAST / UNMATCHED all blocked; module constant `EMAIL_ALLOWED_TIERS` is correct.

**`test_e30_pentad_contract.py` (18):** `PersonalizedMessage` consumed correctly; `SendOutcome` produced with right channel + donor; `CostEvent` shape valid; `event_id` stable per send_id; `handle_rule_fired` actions; bounce classifier behavior; deliverability schedule; DNS validation stub; **AST scan verifies E30 imports ONLY from `shared.brain_pentad_contracts`** (Rule P-1 verifier).

All tests mock the DB via `unittest.mock`. No Postgres required.

## Schema dependencies (NOT created by this PR)

This PR assumes two tables exist in `core`:

```sql
core.email_consent (
    email TEXT PRIMARY KEY,
    rnc_regid TEXT,
    source TEXT NOT NULL,
    opted_in_at TIMESTAMP NOT NULL,
    source_ip TEXT,
    double_opt_in_confirmed BOOLEAN DEFAULT false,
    revoked_at TIMESTAMP
)

core.email_suppression (
    email TEXT PRIMARY KEY,
    reason TEXT NOT NULL,
    source_send_id TEXT,
    suppressed_at TIMESTAMP DEFAULT NOW(),
    permanent BOOLEAN DEFAULT true
)
```

If these don't exist on Hetzner, **someone must type `I AUTHORIZE THIS ACTION` and apply the DDL separately.** This PR does NOT include the DDL — that's a separate auth checkpoint per `nexus-platform/procedures/RULES.md`.

## What this PR did NOT change

- `EmailMarketingSystem` (the legacy entry point) — composed in, but its `send_campaign()` path is NOT used by `EnterpriseEmailSender`. Legacy code paths still work for any pre-rewrite caller, but the path is "deprecated by composition" — the new gate doesn't run on those calls.
- The personalization, A/B, drip, send-time-optimization classes — kept as-is.
- The provider abstraction (SendGrid + Mock) — kept as-is.

## Migration notes

If anything in the codebase calls `EmailMarketingSystem.send_campaign(...)` directly, **those calls bypass the compliance gate.** A pre-merge audit (grep for `send_campaign` outside this file) is recommended; deprecating the legacy path is a follow-up PR.

## Known limits

- The `messaging_pause_state` flag (referenced by `handle_rule_fired('pause_sends')`) is logged but not yet flipped in any persistence layer. Real implementation needs a `core.email_pause_state` table or a feature-flag service.
- DKIM/SPF/DMARC validation is a stub. Real implementation requires `dnspython` and a per-domain configuration table.
- IP warmup is a daily cap — not a per-IP-per-day cap. If you have multiple sending IPs, each one needs its own counter; that's not yet modeled.
- Cost is hardcoded at 12 cents per email. Should be sourced from a per-vendor pricing table (E60's cost ledger has the right shape; wiring is one PR away).

## ⚠️ Pre-deploy compliance checklist for Ed (or counsel)

1. Verify `core.email_consent` and `core.email_suppression` schemas match the assumed shape.
2. Spot-check `send_personalized_message()` blocks correctly for: no consent, suppressed, low match_tier, missing footer.
3. Confirm `ComplianceFooter.physical_address` is the **real** registered address of the sending org.
4. Confirm `paid_for_by` matches the FEC-registered committee name.
5. Confirm DKIM/SPF/DMARC records exist for the sending domain (separate from this PR's stub validation).

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02. PR pushed but NOT merged.*
