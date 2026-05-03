# Section 4 — E31 SMS Merge with TCPA Consent Gate (Design + Rationale)

**Merged:** 2026-05-02 as commit `49ac122` into `main`.
**Branch:** `claude/section-4-e31-sms-merge-2026-05-02` (now defunct).
**Compliance class:** ⚠️ TCPA-sensitive. The consent gate added in this PR is the primary legal safeguard.
**Tests:** 16 unit tests, all passing (`tests/test_e31_consent.py`, `tests/test_e31_shortlink.py`).

---

## Why this PR existed

Two engines under E31, neither one a strict superset:

| File | Lines | What it had |
|---|---:|---|
| `ecosystems/ecosystem_31_sms.py` | 861 | `ConsentManager` (TCPA), `ShortlinkEngine`, `SMSABTestingEngine`, `SMSMarketingSystem`, `SMSConfig`, `SMSProvider` |
| `ecosystems/ecosystem_31_sms_enhanced.py` | 1,344 | `OmnichannelMessagingEngine` (SMS+RCS+WhatsApp), full `messaging_*` schema for consent / shortlinks / A/B, but **no matching code** |

The schema for consent/shortlinks/A/B was already in `_enhanced.py` (per its docstring and the embedded SQL), but the implementing classes lived only in the older `_sms.py`. Sending via the omnichannel engine **bypassed every compliance check** because the relevant classes weren't wired in.

That's a **TCPA violation waiting to happen** — every non-consented send would have been a $500–$1,500 violation per text per the statute.

## The merge

Three classes ported from `_sms.py` into `_sms_enhanced.py`, with a table-name remap to align with the new schema:

| Source class | Source table | Target class | Target table |
|---|---|---|---|
| `ConsentManager` | `sms_consent` (single `status` column) | `ConsentManager` | `messaging_consent` (per-channel `sms_status` / `mms_status` / `rcs_status` / `whatsapp_status`) |
| `ShortlinkEngine` | `sms_shortlinks`, `sms_shortlink_clicks` | `ShortlinkEngine` | `messaging_shortlinks`, `messaging_click_events` |
| `SMSABTestingEngine` | `sms_ab_tests`, `sms_ab_variants` (column `value`) | `MessagingABTestingEngine` | `messaging_ab_tests`, `messaging_ab_variants` (column renamed `value` → `content_value`) |

Then wired into `OmnichannelMessagingEngine.__init__`:

```python
self.consent      = ConsentManager(self.db_url)
self.shortlinks   = ShortlinkEngine(self.db_url)
self.ab_testing   = MessagingABTestingEngine(self.db_url)
```

## The TCPA gate (the most important behavior change)

`OmnichannelMessagingEngine.send_message()` now CHECKS CONSENT before sending. The block is non-negotiable:

```python
gate_channel = 'sms' if campaign['primary_channel'] in ('sms', 'rcs') else campaign['primary_channel']
consent_check = self.consent.check_consent(phone, channel=gate_channel)
if not consent_check['has_consent']:
    return {
        'success': False,
        'blocked_by': 'consent',
        'consent_status': consent_check['status'],
        'channel': gate_channel,
        'error': f"No opt-in for {gate_channel} on {phone}",
    }
```

**Important:** RCS upgrade rides on SMS consent. The TCPA treats RCS as an SMS-class send for consent purposes. We treat the campaign's `primary_channel` as the gate — if it's `sms` or `rcs`, we check `sms_status`. Only if the campaign starts as `whatsapp` or `mms` do we check the channel-specific status.

## STOP keyword detection

`ConsentManager.is_stop_keyword(message_text)` returns True for `STOP`, `UNSUBSCRIBE`, `CANCEL`, `END`, `QUIT`, `STOPALL` (case-insensitive, first-word match). This matches CTIA / TCPA standards. When inbound classification detects a STOP keyword, the system MUST call `opt_out(phone, channel)` immediately. (Inbound classification was already in `OmnichannelMessagingEngine`; this PR added the helper class but didn't change the routing.)

## File renames

- `ecosystems/ecosystem_31_sms_enhanced.py` → `ecosystems/ecosystem_31_sms.py` (overwriting the old one).
- Old `ecosystems/ecosystem_31_sms.py` (with the source classes) — **deleted**. Its 3 classes survive in the merged file under their new homes.
- Same pattern for the backend twins (`backend/python/ecosystems/`).

## API surface

```python
from ecosystem_31_sms import OmnichannelMessagingEngine

engine = OmnichannelMessagingEngine()  # singleton — composes consent, shortlinks, ab_testing

# All three sub-systems accessible as attributes:
engine.consent.opt_in(phone, source='website_form', channel='sms', consent_type='express')
engine.consent.check_consent(phone, channel='sms')  # -> {'has_consent': bool, 'status': str}
engine.shortlinks.create_shortlink(url, campaign_id=..., send_id=...)  # -> short URL
engine.ab_testing.create_test(campaign_id, test_type='subject', variants=[...])

# The high-level send goes through the gate automatically:
engine.send_message(campaign_id, phone, recipient_id=None)
# Returns {'success': True, 'send_id': ..., 'channel': ..., ...}
# OR     {'success': False, 'blocked_by': 'consent', 'consent_status': ..., ...}
```

## Integration contract — Brain Pentad

E31 is a sender ecosystem on the Pentad linear loop, alongside E30 and E32. The contract per `docs/architecture/BRAIN_PENTAD_CONTRACTS.md` (in the Pentad PR):

- **Input:** `PersonalizedMessage` from E19 with `channel` set to one of `sms` / `mms` / `rcs` / `whatsapp`.
- **Output:** `SendOutcome` to E11 for ROI rollup.
- **Cost emission:** Section 8 added `emit_send_cost_to_e60(send_outcome_dict, vendor)` which builds a `CostEvent` with `event_id = f"E31:send:{send_id}"` and persists via `e60.log_cost()`. Per-send-id idempotent.
- **Subscribes to:** `RuleFired` from E60 with `target_ecosystem='E31'`. Supports `pause_sends`, `throttle_sends`, `add_to_suppression` actions.

## Tests

**`tests/test_e31_consent.py` (10 tests)**
- Phone normalization: 10-digit US, E.164, with punctuation.
- STOP keyword detection: case-insensitive, first-word, all 6 mandated keywords.
- `check_consent`: never_subscribed / opted_in / opted_out / unknown_channel cases.
- `opt_out` writes to per-channel status column (NOT the legacy `status` column).
- `opt_in` writes `consent_text_shown` when provided (CAN-SPAM artifact for audit).

**`tests/test_e31_shortlink.py` (6 tests)**
- Short code alphabet excludes ambiguous chars (`0`/`O`/`l`/`I`/`1`).
- Default code length = 6.
- `record_click` issues SELECT + INSERT + UPDATE atomically (counter increment).
- `record_click` returns None for unknown codes (no orphan inserts).
- Mobile vs desktop classification from User-Agent.

These mock the DB via `unittest.mock`. They don't require Postgres to run.

## What this PR did NOT change

- The `messaging_*` tables themselves (already created by Nexus earlier).
- Provider integration (Twilio / Sinch / Bandwidth — those abstractions stayed in the omnichannel engine).
- RCS capability check or fallback logic.
- WhatsApp template handling.

## Known limits

- The cost gate threshold (currently $0.12/SMS in the unit cost) is hardcoded. Should be sourced from a per-vendor config table; that's a future PR.
- The opt-out flow currently doesn't differentiate "user texted STOP" from "user clicked unsubscribe link in MMS" — both end up as `opt_out(phone, channel)`. The `opt_out_reason` field captures the difference but the routing doesn't yet vary. Consider tightening if regulators ever ask for differentiated reporting.
- Section 8 added an `emit_send_cost_to_e60()` helper but it's a module-level function, not yet called from `send_message()`. Wiring it into the send path is a one-line change in a future PR.

## ⚠️ Compliance audit recommendation

Before this branch ships to a real candidate, **Ed (or counsel) should spot-check the consent gate logic in `send_message()`.** The gate is the single most important behavior change in this PR. TCPA penalty exposure for a state-level campaign with a 50K-person SMS list is in the seven-figure range if the gate has a hole.

Recommend manual test:
1. Insert a row into `messaging_consent` with `sms_status = 'opted_out'` for a test phone.
2. Trigger a send to that phone.
3. Confirm response is `{'success': False, 'blocked_by': 'consent', 'consent_status': 'opted_out', ...}`.
4. Confirm zero rows in `messaging_sends` for that phone.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02. Merge committed as `cd8acca`, merged to main as `49ac122`.*
