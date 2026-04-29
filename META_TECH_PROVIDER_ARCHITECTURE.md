# Meta Tech Provider Architecture for BroyhillGOP

**Status:** Design proposal — review only. Nothing built, nothing applied.
**Author:** Claude (architecture write-up)
**For:** Eddie Broyhill
**Date:** 2026-04-29
**Phase:** Step 1 of 8 in safe-pathway sequence

---

## Why this document exists

You asked for a clever way to get per-candidate Meta-layer isolation without per-candidate App Reviews. This document explains the pattern, the schema implications, the onboarding flow, the security model, the failure modes, and the two collisions that need resolving before any code lands.

If you read this and the approach is wrong, we revise prose. If it's right, we move to Step 3 (write the migration as a dry-run file). Nothing else gets written until you approve.

---

## Part 1: The problem in plain language

### What you have today

Each BroyhillGOP candidate has:
- Their own Facebook Page (they own it)
- Their own Instagram Business account
- BroyhillGOP added as a Page-level co-admin
- A Page Access Token stored in `candidate_social_accounts.facebook_page_token`
- All API calls flow through one BroyhillGOP Meta App

### What's good about today's setup

When Candidate A's Page gets a content strike from Meta, the strike attaches to Candidate A's Page and Candidate A's owner account. Candidate B's Page is unaffected. **Page-level enforcement is already isolated.**

### What's still risky

The **Meta App** is shared across all 3,200 candidates. If Meta restricts the App for any reason — coordinated-inauthentic-behavior detection, an accidental rate-limit breach across candidates, a policy violation in how the App is being used — *every candidate's API access stops at the same time.*

The Pages stay alive (the candidates can still post manually from their phones). But BroyhillGOP's automation stops for everyone, simultaneously, until Meta clears the App. That can take days to weeks.

This is a single point of failure. The platform's whole value proposition is automation. If the App goes down, the platform goes silent.

### What "per-candidate Apps" would solve and why nobody does it

If each candidate had their own Meta App registration:
- Meta restricting one App affects only one candidate
- Per-App rate limits compound (200 DMs/hr × 3,200 apps = a lot)
- Strikes on one App don't follow the developer to another App

But:
- Each App needs its own Meta App Review for `pages_messaging`, `instagram_manage_messages`, advanced permissions — that's a 2–4 week external gate **per candidate**
- Each App needs Meta Business Verification (4–8 weeks)
- Each App needs a privacy policy URL, terms URL, app icon
- Onboarding goes from 90 seconds to 6+ weeks
- 3,200 App Reviews is operationally impossible

So nobody does it that way. The big SaaS platforms (HubSpot, Sprout, ManyChat, Hootsuite) all use one App.

---

## Part 2: The Tech Provider pattern

Meta has a specific architectural designation for SaaS platforms that manage many businesses' Pages and Instagram accounts: **Tech Provider System Users living inside client Business Managers.**

This is the path Meta documents and intends for multi-tenant SaaS. ManyChat, HubSpot, Sprout Social, Hootsuite all operate this way. It's not an exotic pattern.

### How it works at the Meta layer

```
BroyhillGOP App           ← ONE App, ONE Review, ONE Verification
       |
       | (installed as Tech Provider into each candidate's BM)
       |
       +---- Candidate A's Business Manager
       |       +---- System User (created inside Candidate A's BM)
       |       +---- Page Access Tokens issued from Candidate A's BM context
       |       +---- Webhook subscription tagged to Candidate A's BM
       |       +---- Candidate A's Page lives in Candidate A's BM
       |
       +---- Candidate B's Business Manager
       |       +---- Separate System User inside Candidate B's BM
       |       +---- Tokens isolated to Candidate B's context
       |       +---- Candidate B's Page lives in Candidate B's BM
       |
       +---- ... 3,200 Business Managers
```

### Why this gives the isolation you want

Meta enforcement actions can target any of these levels:

| Level | What it affects | How likely | Cascade today | Cascade with Tech Provider |
|---|---|---|---|---|
| Single Page | One candidate's Page | Common | One candidate | One candidate |
| Single Page Token | One candidate's API access | Common | One candidate | One candidate |
| **Business Manager** | All Pages in that BM | Uncommon | **All candidates** | **One candidate** |
| **Meta App** | All API calls from the App | Rare but catastrophic | All candidates | All candidates |

**The middle two rows are where Tech Provider helps.** Today, BM-level enforcement (when it happens) cascades because all candidate Pages might be co-administered through BroyhillGOP-related infrastructure. With Tech Provider, BM-level enforcement is contained to that candidate's BM only.

You still have App-level cascade risk. That's true for everyone, including HubSpot. The mitigation is operational discipline: don't let one candidate's bad behavior burn the App. We discuss the App Review phasing in Part 7.

### Why this isn't per-candidate Apps

| Approach | App Reviews | Dev accounts | Onboarding/candidate | BM-level isolation | App-level isolation |
|---|---|---|---|---|---|
| Today: Page co-admin, one App | 1 | 0 | 30 sec | No | No |
| Naive per-candidate Apps | 3,200 | 3,200 | weeks each | Yes | Yes |
| **Tech Provider + per-candidate BM** | **1** | **0** | **90 sec** | **Yes** | **No** |

You get 95% of the isolation benefit with 0% of the per-candidate Review friction. That's the cleverness.

---

## Part 3: The onboarding flow (the part that has to be invisible)

### Today's friction

Most candidates don't have a Business Manager. They have a personal FB account that owns a Page. The naive Tech Provider flow makes them go to `business.facebook.com`, create a BM, claim their Page, then come back and connect to BroyhillGOP. That loses people.

### The fix: Meta's Business Login API auto-provisions the BM

Meta provides a flow called **Business Login for Apps** that lets a SaaS app:
1. Detect during OAuth whether the user has a Business Manager
2. If not, create one in their name with one extra confirmation screen
3. Install the SaaS app as a Tech Provider partner inside that BM
4. Issue System User tokens scoped to that BM
5. Subscribe webhooks to that BM's Pages

The candidate sees one Meta-rendered confirmation flow. They don't know what a Business Manager is. They don't go to business.facebook.com. They click "Connect Facebook," confirm a few things, and they're done.

### What the candidate experiences

```
Step 1  →  Candidate clicks "Connect Facebook" on BroyhillGOP onboarding page
Step 2  →  Lands on Meta-hosted OAuth screen
Step 3  →  Logs in with their personal FB credentials (Meta handles this; BroyhillGOP never sees the password)
Step 4  →  Meta detects: "this user has no Business Manager"
Step 5  →  Meta presents: "BroyhillGOP wants to create a Business account for [Candidate Name]"
Step 6  →  Candidate clicks "Continue"
Step 7  →  Meta presents: "Which Pages should BroyhillGOP have access to?"
Step 8  →  Candidate selects their campaign Page
Step 9  →  Meta presents: "BroyhillGOP is requesting these permissions: [list]"
Step 10 →  Candidate clicks "Allow"
Step 11 →  Meta redirects back to BroyhillGOP with an authorization code
Step 12 →  Backend exchanges the code for a long-lived System User token
Step 13 →  Backend stores token (encrypted) in candidate_social_accounts
Step 14 →  Backend registers webhook subscription for the candidate's Page
Step 15 →  Candidate sees: "Connected ✓"
```

Total clicks: ~5. Total time: ~90 seconds. They've done harder onboarding for Mailchimp.

### What the candidate doesn't experience

- They don't visit business.facebook.com
- They don't fill out a Meta Business Verification form (BroyhillGOP did that once for the App; the candidate's BM inherits the relationship)
- They don't submit any government ID to Meta (BroyhillGOP did that once for the App)
- They don't pick permissions individually (the App requests them as a bundle)
- They don't generate or copy/paste any tokens (the OAuth flow handles it)

### Edge cases the flow has to handle

**Edge case 1: Candidate already has a Business Manager.**
Some candidates will have set up a BM previously (running ads, managing other Pages). The flow detects this and skips Step 5–6, going straight to "which BM do you want to use?"

**Edge case 2: Candidate's Page is currently in someone else's BM.**
Sometimes a campaign manager or previous consultant claimed the Page in their own BM. The flow detects this and prompts: "Your Page is in [Manager Name]'s Business account. To proceed, transfer the Page to your own Business account." Provides Meta-documented transfer instructions. This is the highest-friction edge case but it's relatively rare and unavoidable.

**Edge case 3: Candidate has multiple Pages (campaign + personal + non-profit).**
Step 7 lets them pick which Pages to connect. Default is the campaign Page only. Multi-Page is supported but defaults to single-Page to reduce surface area.

**Edge case 4: Candidate revokes access later.**
If the candidate goes to their FB settings and removes BroyhillGOP, the System User token immediately invalidates. Webhook subscriptions stop firing. The token refresh worker detects the invalid token on next refresh attempt and marks the candidate's silo as `oauth_revoked`. Staff get notified.

**Edge case 5: Token expires (60-day window).**
System User tokens are long-lived but not eternal. Meta currently issues 60-day tokens with refresh capability. A daily token refresh worker checks expiry and refreshes per-candidate. If a token has been unused for too long and refresh fails, the candidate goes into `oauth_expired` state and gets prompted to reconnect.

**Edge case 6: Meta revokes Tech Provider designation.**
Catastrophic. Same as today's App-level cascade. No structural mitigation. Operational discipline only.

---

## Part 4: Schema changes (described, not written)

This section describes what the migration *would* contain. The migration itself is not written until Step 3.

### Additions to existing `candidate_social_accounts` table

The existing table already has `candidate_id`, `facebook_page_id`, `facebook_page_token`. Adding:

| Column | Type | Purpose |
|---|---|---|
| `business_manager_id` | VARCHAR(255) | Meta-assigned BM ID for this candidate |
| `system_user_id` | VARCHAR(255) | Meta-assigned System User ID inside that BM |
| `system_user_token_encrypted` | BYTEA | Long-lived System User token, encrypted at rest |
| `system_user_token_expires_at` | TIMESTAMP | When the current token expires |
| `bm_provisioning_status` | VARCHAR(50) | `pending`, `auto_created`, `existing_bm_used`, `transfer_required`, `provisioned`, `revoked`, `expired` |
| `bm_provisioned_at` | TIMESTAMP | When provisioning completed |
| `webhook_subscription_id` | VARCHAR(255) | Meta-assigned subscription ID for this candidate's Page |
| `instagram_business_account_id` | VARCHAR(255) | Linked IG account if any |
| `last_token_refresh_at` | TIMESTAMP | For monitoring refresh worker health |
| `last_health_check_at` | TIMESTAMP | For monitoring Account Quality dashboard |
| `account_health_score` | INT | Most recent health score from Meta |

### New table: `meta_oauth_audit_log`

Append-only log of every OAuth event for compliance and debugging.

| Column | Purpose |
|---|---|
| `event_id` | UUID PK |
| `candidate_id` | FK, RLS-isolated |
| `event_type` | `oauth_initiated`, `bm_created`, `bm_existing_selected`, `pages_granted`, `permissions_granted`, `token_issued`, `token_refreshed`, `token_expired`, `access_revoked`, `webhook_subscribed`, `webhook_unsubscribed` |
| `event_metadata` | JSONB |
| `event_at` | TIMESTAMP |
| `ip_address` | INET (for audit) |
| `user_agent` | TEXT |

### New table: `meta_app_health`

Single-row table tracking the BroyhillGOP App's overall health. Populated by daily monitoring worker. Master-tier control panel reads this.

| Column | Purpose |
|---|---|
| `checked_at` | TIMESTAMP |
| `app_id` | VARCHAR(255) |
| `app_review_status` | `under_review`, `standard_access`, `advanced_access`, `restricted` |
| `business_verification_status` | `pending`, `verified`, `expired` |
| `current_rate_limit_tier` | INT |
| `connected_candidates_count` | INT |
| `revoked_candidates_count` | INT |
| `pending_token_refreshes_count` | INT |
| `health_alerts` | JSONB |

### RLS (Row-Level Security)

Every new column on `candidate_social_accounts` inherits the table's existing `candidate_isolation` RLS policy.

`meta_oauth_audit_log` gets its own `candidate_isolation` policy on `candidate_id`.

`meta_app_health` is master-only — RLS policy allows reads only for `role = 'platform_admin'`.

### Migration numbering

Production repo's migrations folder runs to 101. Next safe number is **102**. The migration would be named `102_meta_tech_provider.sql`. It's idempotent (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ADD COLUMN IF NOT EXISTS`) so re-running is safe.

---

## Part 5: Token security model

Tokens are the keys to the kingdom. If a System User token leaks, an attacker can read DMs, post on the candidate's Page, message the candidate's followers — until the token is revoked.

### Storage

- **Never plaintext.** Tokens are encrypted at application layer before insertion.
- **Encryption key from environment.** A 32-byte key in Hetzner's `/opt/broyhillgop/config/.env`, never in code, never in git.
- **AES-GCM (authenticated encryption).** Detects tampering. Standard library, no novel crypto.
- **Key rotation supported.** Schema versions encryption-key-id alongside ciphertext so old tokens can be decrypted while new tokens use the rotated key.

### Access

- Application reads token from DB → decrypts in memory → uses for API call → discards from memory after call.
- No token ever logged. Logging middleware redacts any value matching the System User token pattern.
- No token ever sent to client browsers. The OAuth callback handler exchanges the code for a token server-side; the browser only sees the redirect.

### Revocation

- Candidate can revoke at any time via FB settings → Apps and Websites.
- Token refresh worker detects revocation on next refresh attempt.
- Master tier control panel has emergency-revoke button: marks status `revoked`, deletes encrypted token, halts all automation for that candidate.

### Audit

- Every token issuance, refresh, and revocation logged to `meta_oauth_audit_log`.
- Daily report to master tier: tokens issued today, tokens refreshed today, tokens expired today, candidates in `oauth_revoked` state.

### Threat model — what this protects against

| Threat | Mitigation |
|---|---|
| DB dump leak | Tokens encrypted, attacker needs key from env |
| Env file leak | Tokens encrypted with a key, but if env leaks, key leaks too — operational defense (file permissions, no env in git) |
| Application memory dump | Token visible briefly during use; out-of-scope (host security) |
| Insider with DB access | Logged; encrypted; key not in DB |
| Compromised candidate account | Candidate revokes via FB settings; refresh worker detects; staff alerted |
| Compromised BroyhillGOP staff account | Master-tier emergency revoke; rotate App secret; alert all candidates |

### Threat model — what this does NOT protect against

- Loss of the BroyhillGOP App itself (Meta-side compromise, App secret leak): catastrophic. Mitigation is operational only.
- Compromise of the Hetzner server: tokens decryptable by attacker who reads DB + env. Mitigation is host security, not architecture.
- Malicious BroyhillGOP staff with platform-admin role: by design, master tier can revoke and access. This is a trust assumption, same as any SaaS.

---

## Part 6: Failure modes and what happens

### Failure mode 1: Candidate's Page gets a content strike

- Meta marks the Page with a strike
- BroyhillGOP API access to that Page may be temporarily reduced (post limits, DM throttles)
- Other candidates: unaffected
- Recovery: candidate appeals via FB; BroyhillGOP automation auto-throttles until strike clears

### Failure mode 2: Candidate's BM gets restricted

- Meta restricts the BM (rare, usually requires repeated Page strikes within the BM)
- All Pages in that BM lose programmatic access from BroyhillGOP App
- Other candidates' BMs: unaffected
- Recovery: candidate works with Meta directly to resolve BM restriction

### Failure mode 3: BroyhillGOP App gets restricted

- All candidate API access stops
- Pages stay alive (manual posting still works)
- BroyhillGOP loses all DM/comment automation simultaneously
- Recovery: BroyhillGOP works with Meta partner support; can take days to weeks
- **This is the unmitigable risk.** Same as every SaaS platform on Meta.
- Mitigation is operational: don't let one candidate's bad behavior generate App-level patterns Meta classifies as abuse

### Failure mode 4: Token refresh worker dies for a day

- Tokens close to expiry might lapse
- Affected candidates show `oauth_expired` status
- Recovery: re-run worker, refresh tokens; for candidates whose tokens fully expired, prompt reconnect
- Monitoring: daily metric `pending_token_refreshes_count` in `meta_app_health`

### Failure mode 5: Webhook endpoint at BroyhillGOP goes down

- Meta retries webhook deliveries for 7 days with exponential backoff
- After 7 days of failure, Meta auto-disables the subscription
- For all candidates simultaneously, since they all subscribe via the same App
- Recovery: bring endpoint back up, re-subscribe webhooks for affected candidates
- Monitoring: webhook delivery success rate per candidate

### Failure mode 6: Meta changes the Business Login API

- Cleverness #1 (auto-provisioning BMs during OAuth) depends on a specific Meta API endpoint
- If Meta deprecates or changes it, onboarding breaks
- Detection: integration tests run weekly against Meta's API
- Recovery: update OAuth handler to match new API
- Worst case: revert to manual BM creation (candidate friction returns to current state)

### Failure mode 7: Candidate's account gets phished, attacker removes BroyhillGOP from their BM

- BroyhillGOP loses all access to that candidate's silo
- Other candidates: unaffected (this is the whole point of the architecture)
- Recovery: candidate recovers their FB account, re-authorizes BroyhillGOP
- Mitigation: recommend candidates enable 2FA on personal FB during onboarding

---

## Part 7: App Review phasing — getting through Meta's gates

The single Meta App needs Meta Business Verification + App Review. These are calendar gates, not engineering work. Phase the submissions to minimize blocked-time.

### Phase 1: Standard Access (Week 1, parallel to engineering)

Submit App Review for the minimum permission set:
- `pages_show_list` (see which Pages a user manages)
- `pages_read_engagement` (read comments, post stats)
- `pages_messaging` (send and receive DMs)
- `instagram_basic` (read IG account info)
- `instagram_manage_messages` (send and receive IG DMs)

Standard Access tier supports roughly 50 connected accounts. Enough for pilot.

Meta Business Verification: submitted in parallel. 4–8 week external turnaround.

### Phase 2: Advanced Access (Week 6, after pilot data)

After the Standard Access pilot has 4+ weeks of real usage data, submit for Advanced Access. Meta's reviewers want:
- Screenshots of actual conversation flows
- Evidence the App does what it claims
- Real metrics (DM volume, response rates, candidate satisfaction)

Approval likelihood is much higher with real data than with a hypothetical use case.

Advanced Access removes the 50-account cap. The 200 DMs/hour per Page rate limit still applies.

### Phase 3: Cloud API + Partner relationship (Week 12+)

Once at scale (100+ candidates), apply for:
- **Cloud API** access (better rate limits than Graph API for messaging)
- **Direct Partner relationship** with Meta (gets dedicated support, higher rate limits, advance notice of API changes)
- ManyChat, HubSpot, Sprout all have this. Eligibility is based on volume and good standing.

This is where the platform stops being rate-limited by Meta's defaults and starts operating at the tier the big platforms operate at.

### What submitting reviews actually requires

- Privacy policy URL (publicly accessible, mentions Meta data handling)
- Terms of service URL
- App icon (1024×1024 PNG)
- Demo video (Meta wants to see the OAuth flow + a sample conversation)
- Test credentials for Meta's reviewers
- Detailed use case description (1-2 pages)

None of this is engineering. It's documentation + a video recording. Plan ~8 hours of work to assemble.

---

## Part 8: The two collisions that need resolving

These were caught by reading the production repo on 2026-04-29, after the 4/26 dry-run scaffold was authored.

### Collision 1: E61

- **4/26 scaffold:** `E61 = Cost/Benefit/Variance ML Brain Control` (proposed new ecosystem)
- **Production repo (committed 2026-04-29):** `E61 = Campaign Funnel Engine` (different ecosystem, already cataloged)

**Resolution:** Renumber the Cost/Benefit/Variance ecosystem to **E62**. E62 is currently free in the production registry.

This affects ~15 files in the 4/26 scaffold. The renumbering is mechanical (find/replace `E61` → `E62`, `e61` schema → `e62` schema). A renumbering script would handle it idempotently.

The Tech Provider piece (this document's subject) doesn't depend on Cost/Benefit/Variance, so the collision can be resolved later as a separate piece of work. **For the Tech Provider build alone, this collision can be ignored.**

### Collision 2: E35 vs E36

- **4/26 scaffold:** "E36 Unified Inbox extension"
- **Production repo:** `E35 = UNIFIED_INBOX`, `E36 = MESSENGER` (two separate ecosystems)

**Resolution:** The unified-inbox-of-DMs concept belongs to **E35 (Unified Inbox)**, not E36. E36 Messenger is for outbound campaign messaging.

Same as above: doesn't affect the Tech Provider build. Resolved later.

---

## Part 9: What we are NOT doing in this build

To keep scope tight and avoid mistakes:

- **Not touching production database.** No migrations applied. No tables created.
- **Not pushing to GitHub.** Bundle for review only.
- **Not modifying existing E19 social files.** The 140KB of existing code in `ecosystems/ecosystem_19_social_media_*.py` stays untouched. New code goes in a new submodule.
- **Not implementing Cost/Benefit/Variance (E62).** That's separate, deferred.
- **Not implementing E35 Unified Inbox extension.** Separate, deferred.
- **Not implementing the Funnel submodule.** Q3 build, deferred.
- **Not submitting Meta Business Verification or App Review.** That's a calendar gate, you initiate it manually when ready.
- **Not loading FEC, NCBOE, or any voter data.** Sacred tables untouched.
- **Not modifying the identity resolver.** "Ed"≠"Edward" rule preserved.

---

## Part 10: What this build WILL produce (when authorized)

When you authorize Step 3 onward:

**Step 3 deliverable:** One SQL file, `migrations/102_meta_tech_provider.sql`. Idempotent. RLS policies included. Sitting in `/home/claude/` for review. Not applied.

**Step 5 deliverable:** Python services in `ecosystems/E19_social/onboarding/`:
- `business_login_handler.py` — OAuth callback, BM provisioning
- `system_user_provisioner.py` — System User creation, token issuance
- `token_refresh_worker.py` — daily refresh cron
- `webhook_subscription_manager.py` — per-BM webhook lifecycle
- Tests for each

**Step 5 also includes:**
- `shared/security/token_vault.py` — encrypted token storage helpers
- `control_panel/candidate_onboarding_spec.md` — UI spec for the candidate-facing flow
- `control_panel/master_app_health_spec.md` — UI spec for the master-tier monitoring dashboard

**Step 7 deliverable:** Tarball + git bundle for download. Inspected on your Mac.

**Step 8:** Push to GitHub via PAT (paste at that point, scoped 1-day expiration).

---

## Part 11: Questions for Eddie before Step 3

These are the design questions that need answers before I write the migration. None require immediate action — just thinking.

1. **Is the existing token storage in `candidate_social_accounts.facebook_page_token` currently encrypted?** If yes, the migration just adds the new columns alongside the existing pattern. If no, the migration is a good moment to add encryption to existing tokens too — but that's a destructive change that requires careful migration of existing data.

2. **Where should the encryption key live?** Suggested: Hetzner `/opt/broyhillgop/config/.env` as `META_TOKEN_ENCRYPTION_KEY`. But you may have a preferred secret-management pattern.

3. **Should the master-tier control panel for App health be a new Inspinia page, or extend an existing one?** Suggested: new page at `/master/meta/app_health` extending the donors.html canonical template.

4. **Do you have a preferred webhook endpoint URL pattern?** Suggested: `https://api.broyhillgop.org/v1/webhooks/meta/[event_type]` routed through E55 API Gateway. Confirm this matches your existing routing.

5. **Should I write a one-shot migration of existing co-admin candidates onto the new Tech Provider model, or is that handled as candidates re-onboard?** Suggested: handled at re-onboard time. Migrating existing candidates to the new model requires them to re-grant OAuth, which is friction-positive (they have to consent to the new BM-based access pattern anyway under the new flow).

---

## Part 12: Authorization checkpoint

This document is the entirety of Step 1.

**To proceed to Step 3 (write the migration as a dry-run file):**

Reply with `Authorize Step 3` and any answers to Part 11 questions you want me to incorporate. If no answers, I'll use the suggestions in Part 11 as defaults and flag them as defaults in the migration comments.

**To revise this document:**

Tell me what's wrong and I'll rewrite. No code touched.

**To stop entirely:**

Say "stop" and I'll close the working directory. Nothing built persists beyond your session storage.

---

## Part 13: Brain Integration (added in Step 5b)

The Tech Provider integrates with the Brain via 7 governance layers. This section
documents each layer and the events / function codes / workflow registrations.

### 13.1 Ecosystem registration in `brain_control.ecosystems`

Tech Provider registers as `E19_TECH_PROVIDER` (separate from E19_SOCIAL to keep
the boundary clean and allow independent health/cost tracking).

| Field | Value |
|---|---|
| ecosystem_code | `E19_TECH_PROVIDER` |
| ecosystem_name | `E19 Meta Tech Provider` |
| schema_name | `public` |
| api_prefix | `/v1/webhooks/meta` |
| status | `ACTIVE` |
| criticality | `HIGH` |
| dependencies | `E0_DATAHUB`, `E20_BRAIN`, `E55_API_GATEWAY` |
| provides_to | `E19_SOCIAL`, `E20_BRAIN`, `E35_INBOX`, `E51_NEXUS` |
| ai_powered | `FALSE` (this layer is plumbing; AI happens upstream/downstream) |
| monthly_budget | $50 |
| cost_center | `TECH_PROVIDER` |

Registered by migration `103_brain_control_registration.sql`.

### 13.2 Function registration in `brain_control.functions`

Four functions, codes F901-F904 (chosen high to avoid collision with existing
F001-F899 numeric range, while complying with the `^F[0-9]{3}$` CHECK constraint).

| Code | Function | Cost type | Quality floor | Critical? |
|---|---|---|---|---|
| F901 | OAuth Provisioning | per_call | 95% | Yes |
| F902 | Token Refresh | per_call | 99% | Yes |
| F903 | Webhook Subscription Manager | per_call | 99% | No |
| F904 | Token Vault Operations | per_call | 99.99% | Yes |

Forecasts assume 500 onboardings/mo, 90,000 token refreshes/mo, 10,000 subscription
operations/mo, and 1M token vault operations/mo at full scale (3,000 candidates).

### 13.3 Events PUBLISHED to the bus

Channel: `broyhillgop.events` (Redis pub/sub, canonical channel)
Format: JSON with `event_id`, `event_type`, `ecosystem`, `candidate_id`, `timestamp`, plus payload.

| Event | When | Payload fields |
|---|---|---|
| `social.oauth.initiated` | Candidate clicks Connect Facebook | scopes |
| `social.oauth.completed` | Provisioning succeeds | business_manager_id, system_user_id, page_id, page_count, instagram_business_account_id, bm_was_auto_created, webhook_subscription_id, duration_ms |
| `social.oauth.failed` | Any error path including transfer_required | reason, message |
| `social.oauth.revoked` | Candidate or admin revokes | revoked_by |
| `social.token.refreshed` | Daily refresh succeeds | new_expires_at |
| `social.token.refresh_failed` | Single refresh attempt fails (not yet at threshold) | outcome, error_code |
| `social.token.expired` | 3 consecutive failures → marked expired | consecutive_failures, last_error |
| `social.webhook.subscription_disabled` | Meta auto-disables after 7d failures | detected_at |
| `social.app_health.degraded` | Rate limit hit, mass revocation, or App Review status drop | reason, halted_pass_at (optional) |
| `social.app_health.restored` | Recovered from degraded | (no required payload) |

Failure mode: if Redis is unavailable, events go to `meta_event_bus_replay_queue`
table. A replay worker re-publishes when Redis recovers.

### 13.4 Events SUBSCRIBED from the bus

Subscribes to `intelligence.*` channels for Brain decisions.

| Event | What Tech Provider does |
|---|---|
| `intelligence.candidate.connect_required` | Sends candidate the OAuth invite via SMS or email |
| `intelligence.automation.pause` | Sets pause flag (per-candidate or app-wide) |
| `intelligence.automation.resume` | Clears pause flag |
| `intelligence.token.force_refresh` | Enqueues immediate token refresh for the named candidate |

Implemented in `ecosystems/E19_social/onboarding/brain_consumer.py`.

### 13.5 Automation workflow registration in `automation_workflows`

These wire up the TriggerRouter so it fires registered workflows when our events
publish. Five workflows total. All registered by migration 103.

| Workflow | Trigger event | Actions | Mode |
|---|---|---|---|
| `tech_provider_oauth_completed_welcome` | `social.oauth.completed` | E30 welcome email + E31 SMS + E20 enables nightly approval | auto |
| `tech_provider_oauth_failed_assist` | `social.oauth.failed` | E35 staff ticket + E15 flag candidate | auto |
| `tech_provider_oauth_revoked_reengage` | `social.oauth.revoked` | E20 prioritize + E30 reconnect email + E31 SMS (24h delayed) | auto |
| `tech_provider_token_expired_alert` | `social.token.expired` | E35 urgent ticket + E31 urgent reconnect SMS | auto |
| `tech_provider_app_health_degraded_pause` | `social.app_health.degraded` | E20 pause app-wide + E35 master alert | manual (master must approve resume) |

If `automation_workflows` table doesn't exist at apply time, migration 103 logs a
notice and skips workflow registration without failing. Re-run migration after the
table is created.

### 13.6 Health reporting to `brain_control.ecosystem_health`

The token refresh worker reports a snapshot at the end of each daily pass:
- `status` = ACTIVE / DEGRADED based on rate-limit and error-rate thresholds
- `response_time_ms` = pass duration
- `error_rate` = failed / total
- `error_count` = failures
- `queue_depth` = total queue size

Master tier reads this for the Tech Provider row in the App Health dashboard.

### 13.7 Cost accounting via `CostAccountant`

Every Meta API call records a `FunctionCallRecord` with function_code, candidate_id,
success, duration_ms, error_type. Aggregated daily into brain_control variance/forecast
tables, feeding the cost variance reports.

### 13.8 Self-correction directives via `SelfCorrectionReader`

Service code calls `is_paused(reader, candidate_id)` before performing automation
actions. The reader returns app-wide and per-candidate directives from brain_control.

When app-wide is `PAUSED`, the refresh worker skips the entire pass. When per-candidate
is `PAUSED`, the refresh worker skips just that candidate. When OAuth provisioning is
attempted while paused, it raises `OAuthError("blocked: automation paused")` and
publishes a `social.oauth.failed` event with reason=`automation_paused`.

### 13.9 Brain-adjacent ecosystems Tech Provider integrates with

- **E0 DataHub** — hosts the Redis pub/sub channel and replay queue table
- **E13 AI Hub** — used in DM submodule (deferred) for voiced auto-responses
- **E20 Intelligence Brain** — central decision engine; bidirectional event flow
- **E42 News Intelligence** — indirect: news-triggered campaigns flow through E20 to E19_TECH_PROVIDER if candidate Pages are reachable
- **E51 Nexus** — `social_approval_requests.nexus_*` columns are populated by Nexus, not Tech Provider; we provide the underlying Page connectivity Nexus relies on
- **E55 API Gateway** — all OAuth callback URLs and webhook endpoints route through `https://api.broyhillgop.org/v1/webhooks/meta/...`
- **TriggerRouter** (in MASTER_ECOSYSTEM_ORCHESTRATOR) — picks up our events and fires the 5 automation workflows we registered

### 13.10 What the Brain integration does NOT do

- **No direct calls to E20 internals.** All communication is event-driven via the bus.
- **No reading of raw Brain state.** We only consume directives via the documented
  `SelfCorrectionReader` interface.
- **No bypass of E55 API Gateway** for any external traffic.
- **No mutation of NEXUS tables.** We don't touch `nexus_*` columns or tables;
  Nexus owns its own data.

---

## Part 14: Authorization checkpoint (current)

This document now reflects the post-Step-5b state.

**To bundle for review and proceed to Step 7:**

Reply with `Authorize Step 7`.

**To stop:**

Say "stop".

---

*End of architecture document. No code written. No migrations applied. No git interaction. Step 1 of 8 complete.*
