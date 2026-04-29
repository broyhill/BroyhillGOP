# BroyhillGOP Meta Tech Provider Build

**Phase:** Step 5b of 8 in safe-pathway sequence — Brain integration complete. Dry-run only.
**Status:** All files written. 87 tests passing. Nothing applied. Nothing pushed.
**Date:** 2026-04-29

---

## What this is

The Meta Tech Provider architecture for BroyhillGOP — the answer to "how do we get per-candidate Meta-layer cascade-ban isolation without 3,200 separate App Reviews?"

**The architectural answer:** BroyhillGOP runs as a single Meta Tech Provider App, installed as a partner inside each candidate's own Business Manager via a 90-second OAuth flow. Each candidate gets their own System User and tokens, scoped to their own BM. When Meta enforcement targets a BM, blast radius = one candidate. Same isolation as per-candidate Apps; same 1-Review onboarding cost as today.

**The Brain integration answer:** The Tech Provider registers as `E19_TECH_PROVIDER` in the `brain_control` governance schema, publishes 10 event types to E20 Intelligence Brain via Redis, subscribes to 4 `intelligence.*` decision types from Brain, registers 5 automation workflows for TriggerRouter to fire, reports health to `brain_control.ecosystem_health`, tracks costs through 4 registered functions (F901-F904), and honors Brain pause/resume directives through the SelfCorrectionReader.

The Tech Provider pattern is used by HubSpot, Sprout Social, ManyChat, and Hootsuite at scale. The Brain integration follows the canonical pattern from `053_NEXUS_PLATFORM_INTEGRATION.sql` (governance) and `ecosystem_20_intelligence_brain.py` (event format).

---

## File structure

```
meta_tech_provider_design/
├── README.md                                    ← this file
├── META_TECH_PROVIDER_ARCHITECTURE.md           ← 14 sections; Part 13 covers Brain integration
│
├── migrations/
│   ├── 102_meta_tech_provider.sql               ← Tech Provider schema + replay queue
│   └── 103_brain_control_registration.sql       ← Brain governance: ecosystem + 4 functions + 5 workflows
│
├── shared/
│   ├── security/
│   │   └── token_vault.py                       ← AES-256-GCM, key rotation, redaction
│   ├── event_bus/
│   │   ├── publisher.py                         ← Redis publisher with replay queue fallback
│   │   └── consumer.py                          ← Subscriber with pattern matching + dedup
│   └── brain_control/
│       └── governance.py                        ← HealthReporter, CostAccountant, SelfCorrectionReader
│
├── ecosystems/E19_social/onboarding/
│   ├── business_login_handler.py                ← OAuth callback + BM provisioning + event emission
│   ├── token_refresh_worker.py                  ← Daily refresh cron + health reporting
│   ├── webhook_subscription_manager.py          ← Subscription lifecycle + event emission
│   ├── brain_consumer.py                        ← Subscribes to intelligence.* Brain decisions
│   └── tests/
│       ├── test_token_vault.py                  ← 20 tests
│       ├── test_oauth_callback.py               ← 12 tests
│       ├── test_token_refresh.py                ← 7 tests
│       ├── test_event_bus.py                    ← 19 tests
│       ├── test_brain_consumer.py               ← 14 tests
│       └── test_brain_governance.py             ← 15 tests
│
└── control_panel/
    ├── candidate_onboarding_spec.md             ← 7-screen candidate UI spec
    └── master_app_health_spec.md                ← Master-tier monitoring dashboard spec
```

**Total: 19 files. 87 tests. All passing.**

---

## Locked rules audit

- [x] **TWO-PHASE PROTOCOL** — Both migrations are dry-run only. Nothing applied.
- [x] **Silo isolation** — Every candidate-scoped table has `candidate_id` + RLS policy.
- [x] **No FEC/NCBOE files touched.**
- [x] **No identity resolver changes.**
- [x] **All paths route through E55 API Gateway** at `https://api.broyhillgop.org/v1/webhooks/meta/...`.
- [x] **TCPA gate non-bypassable** — this build doesn't touch compliance gates.
- [x] **Idempotent migrations** — every CREATE/ALTER/INSERT uses IF NOT EXISTS or ON CONFLICT DO UPDATE.
- [x] **Tokens never plaintext** — AES-256-GCM with KMS-style key rotation. Log redaction enforced.
- [x] **Append-only audit log** — `meta_oauth_audit_log` triggers block UPDATE/DELETE.
- [x] **Brain governance integration** — registered in `brain_control.ecosystems` + 4 functions (F901-F904) + 3 dependencies + 5 automation_workflows. Events published in canonical format on `broyhillgop.events`. SelfCorrectionReader honored before all automation actions.
- [x] **Existing E19 code preserved** — no modifications to existing `ecosystem_19_social_media_*.py` files.
- [x] **No NEXUS table mutations** — Tech Provider doesn't touch `nexus_*` tables.
- [x] **All 87 tests pass.**

---

## Brain integration — what's wired

### Layer 1: Ecosystem registration

`E19_TECH_PROVIDER` registered in `brain_control.ecosystems` with:
- Dependencies: `E0_DATAHUB`, `E20_BRAIN`, `E55_API_GATEWAY`
- Provides to: `E19_SOCIAL`, `E20_BRAIN`, `E35_INBOX`, `E51_NEXUS`
- Cost center: `TECH_PROVIDER`, monthly budget: $50
- Criticality: HIGH

### Layer 2: Function registration (`brain_control.functions`)

| Code | Function | Quality floor | Latency p99 |
|---|---|---|---|
| F901 | OAuth Provisioning | 95% | 30s |
| F902 | Token Refresh | 99% | 5s |
| F903 | Webhook Subscription | 99% | 5s |
| F904 | Token Vault Crypto | 99.99% | 50ms |

### Layer 3: Events published (Redis `broyhillgop.events`)

`social.oauth.{initiated,completed,failed,revoked}`, `social.token.{refreshed,refresh_failed,expired}`, `social.webhook.subscription_disabled`, `social.app_health.{degraded,restored}`

### Layer 4: Events subscribed (from E20 Brain)

`intelligence.candidate.connect_required`, `intelligence.automation.{pause,resume}`, `intelligence.token.force_refresh`

### Layer 5: Automation workflows registered for TriggerRouter

| Trigger | Workflow | Cross-ecosystem actions |
|---|---|---|
| `social.oauth.completed` | `tech_provider_oauth_completed_welcome` | E30 + E31 + E20 enable automation |
| `social.oauth.failed` | `tech_provider_oauth_failed_assist` | E35 staff ticket + E15 flag |
| `social.oauth.revoked` | `tech_provider_oauth_revoked_reengage` | E20 priority + E30 + E31 delayed |
| `social.token.expired` | `tech_provider_token_expired_alert` | E35 urgent + E31 urgent SMS |
| `social.app_health.degraded` | `tech_provider_app_health_degraded_pause` | E20 pause app-wide + E35 master alert (manual mode) |

### Layer 6: Health reporting

`HealthReporter.report()` writes to `brain_control.ecosystem_health` from the refresh worker.

### Layer 7: Cost accounting

Every Meta API call records via `CostAccountant.record_call(FunctionCallRecord(...))`.

### Self-correction enforcement

Before any automation action, services call `is_paused(reader, candidate_id)`. App-wide PAUSED halts everything. Per-candidate PAUSED halts just that candidate.

### Replay queue

When Redis is down, events fall back to `meta_event_bus_replay_queue` table (added by migration 102). Replay worker (deferred) re-publishes when Redis recovers. Events never lost.

---

## What's deferred

- **Migration application** — Step 8, after explicit authorization
- **GitHub push** — bundle for review only
- Existing E19 social files — untouched
- E62 Cost/Benefit/Variance, E35 Unified Inbox extension, Funnel submodule
- Frontend implementation of UI specs
- Meta Business Verification + App Review submissions (calendar gates)
- Concrete `psycopg2`-backed implementations of abstract Store/Reporter/Reader interfaces
- FastAPI/Flask routes wiring the OAuth handler to HTTP endpoints
- Replay worker that drains `meta_event_bus_replay_queue`
- DM submodule (webhook handler that publishes `social.webhook.received`)

---

## Reading order for review

1. `META_TECH_PROVIDER_ARCHITECTURE.md` — Part 13 covers all 7 Brain integration layers
2. `migrations/102_meta_tech_provider.sql` — Tech Provider schema
3. `migrations/103_brain_control_registration.sql` — Brain governance registration
4. `shared/security/token_vault.py`
5. `shared/event_bus/publisher.py` then `consumer.py`
6. `shared/brain_control/governance.py`
7. `ecosystems/E19_social/onboarding/business_login_handler.py`
8. `ecosystems/E19_social/onboarding/token_refresh_worker.py`
9. `ecosystems/E19_social/onboarding/webhook_subscription_manager.py`
10. `ecosystems/E19_social/onboarding/brain_consumer.py`
11. All 6 test files
12. `control_panel/candidate_onboarding_spec.md`
13. `control_panel/master_app_health_spec.md`

---

## Environment variables required (at deploy time, not now)

| Variable | Purpose |
|---|---|
| `FACEBOOK_APP_ID` | The single BroyhillGOP Meta App ID |
| `FACEBOOK_APP_SECRET` | Server-side, never to browsers |
| `META_BUSINESS_LOGIN_CONFIG_ID` | Tech Provider config ID from Meta dashboard |
| `META_OAUTH_CALLBACK_URL` | `https://api.broyhillgop.org/v1/webhooks/meta/oauth_callback` |
| `META_GRAPH_API_VERSION` | Default `v19.0` |
| `META_TOKEN_ACTIVE_KEY_ID` | Which key for new encryptions (e.g. `v1`) |
| `META_TOKEN_KEY_v1` | Base64-encoded 32 bytes for AES-256 |
| `REDIS_HOST` / `REDIS_PORT` | Event bus — defaults localhost:6379 |

Generate encryption key: `openssl rand -base64 32`

---

## Next decisions

When ready to proceed:

- **`Authorize Step 7`** — bundle this directory as tarball + git bundle for inspection on your Mac. No push.
- **`Authorize Step 7 + 8`** — also push to GitHub via PAT-based push.
- **`Stop`** — close out.

---

*End of README. Step 5b complete: Brain integration with all 7 governance layers wired and tested.*
