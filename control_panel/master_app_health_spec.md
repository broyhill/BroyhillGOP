# Master Tier Dashboard Spec — Meta App Health

**Phase:** Step 5 of 8. UI not implemented; spec only.
**Tier:** Master only (`platform_admin` role)
**Template base:** Inspinia HTML, extends `donors.html` canonical layout
**Route:** `/master/meta/app_health`

---

## Purpose

Single pane of glass for monitoring the BroyhillGOP Meta App's health and the population of connected candidates. Lets platform admins detect:

- App-level cascade risk warning signs (rate limits being approached, App Review status changes)
- Aggregate provisioning trends (how many candidates connected this week, churn rate)
- Per-candidate token health (who's about to expire, who failed to refresh, who revoked)
- Webhook delivery health
- Emergency revoke capability for a specific candidate

---

## Top-of-page status banner

Single horizontal banner showing app-wide state at a glance.

```
+----------------------------------------------------------------------+
|  Meta App Status: ● Standard Access  |  Verification: ✓ Verified   |
|  Connected candidates: 47/50         |  Pending refreshes: 3        |
|  Last check: 14 minutes ago          |  Health alerts: 0            |
+----------------------------------------------------------------------+
```

### Color coding

- Green dot (●): Standard or Advanced Access; verified; no alerts
- Yellow dot: Pending review or 1+ low-severity alerts
- Red dot: Restricted, suspended, or 1+ high-severity alerts

### Data source

Single row from `meta_app_health` table. Updated by daily monitoring worker.

---

## Section 1: App-Level Metrics

### Cards row (4 cards)

```
┌───────────────────┬───────────────────┬───────────────────┬───────────────────┐
│ Connected         │ At Capacity?      │ 7-Day Token       │ Webhook Health   │
│   47 / 50         │   94% used        │ Refresh Rate      │   100%           │
│   ↑ 3 this week   │   ⚠ Apply for     │   100%            │   0 disabled     │
│                   │     Advanced      │   (47/47 success) │                  │
└───────────────────┴───────────────────┴───────────────────┴───────────────────┘
```

### Source

- Connected: `COUNT(*) FROM candidate_social_accounts WHERE bm_provisioning_status = 'provisioned'`
- At Capacity: `connected / current_rate_limit_tier_account_cap`
- Token Refresh Rate: `meta_token_refresh_attempts WHERE outcome = 'success' / total attempts in last 7 days`
- Webhook Health: percentage of pages with active subscriptions

---

## Section 2: Candidate Status Table

Master-tier view showing all candidates' Meta connection state. Filterable, sortable.

### Columns

| Column | Source |
|---|---|
| Candidate Name | `candidates.name` |
| Status | `candidate_social_accounts.bm_provisioning_status` |
| Page | `candidate_social_accounts.facebook_page_id` (linked to Meta) |
| Token Expires | `system_user_token_expires_at` |
| Health Score | `account_health_score` (Meta's account quality score) |
| Last Refresh | `last_token_refresh_at` |
| Webhook | green/red icon based on subscription status |
| Actions | [View activity] [Force refresh] [Emergency revoke] |

### Status badges

- `provisioned` → green "Active"
- `oauth_revoked` → red "Revoked by candidate"
- `oauth_expired` → orange "Expired — needs reconnect"
- `transfer_required` → yellow "Page transfer needed"
- `pending`, `oauth_initiated`, `auto_created` → gray "In progress"

### Filters

- Status (multi-select)
- Health score < threshold
- Token expiring within N days
- Last refresh failed

### Default sort

Sort by `system_user_token_expires_at ASC` so soonest-to-expire surfaces first.

---

## Section 3: 30-Day Activity Trend

Time-series chart showing daily counts over the last 30 days:

- OAuth initiations
- OAuth completions (provisioned)
- OAuth failures
- Revocations

### Chart type

Stacked bar chart, one bar per day, 30 bars total.

### Source

`meta_oauth_audit_log`, grouped by `DATE(event_at)` and `event_type`.

---

## Section 4: Health Alerts

Live list of alerts surfaced from the daily monitoring worker. Each alert has:

- Severity (info / warning / critical)
- Type (e.g., "App Review status changed", "Rate limit approaching", "Multiple token refresh failures")
- Description
- Affected candidates (if applicable)
- Acknowledged y/n
- Created at

### Source

`meta_app_health.health_alerts` JSONB column.

### Alert types and triggers

| Alert | Trigger | Severity |
|---|---|---|
| Rate limit approaching | At 90% of `current_rate_limit_tier` | warning |
| Rate limit reached | At 100% — new candidates can't onboard | critical |
| App review status changed | `app_review_status` field changed since last check | info |
| Verification expiring | `business_verification_status` shows expiry within 30 days | warning |
| Token refresh failures | 5+ failures in last 24h | warning |
| Webhook deliveries failing | <80% delivery rate over last 6h | warning |
| Mass revocation | 5+ revocations in last 24h | warning |

---

## Section 5: Emergency Actions

Master-tier-only buttons gated by additional confirmation modal.

### Emergency Revoke Candidate

- Input: candidate ID or candidate name search
- Confirmation modal: "This will mark the candidate as revoked, halt all automation for them, and unsubscribe their webhook. Type the candidate's name to confirm."
- Calls `business_login_handler.handle_revocation(revoked_by='admin')`

### Force Token Refresh

- Bypass the daily refresh schedule for one or more candidates
- Useful when a token-related issue is detected and you don't want to wait for the cron
- Confirmation modal listing affected candidates

### App-Wide Pause

- Stop all outbound automation (DMs, comments, posts) without revoking tokens
- Used during incident response (e.g., "we got a Meta warning, pause everything for 24h")
- Sets a flag readable by all dispatchers in the platform
- Clearable only by master tier with explicit confirmation

---

## Access control

- Page rendered only for users with `current_role = 'platform_admin'`
- All API endpoints behind RLS — `meta_app_health` table policy enforces
- Read-only by default; mutating actions require additional 2FA challenge

---

## API endpoints required

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/master/meta/app_health` | Top banner state |
| GET | `/api/v1/master/meta/candidates` | Candidate status table |
| GET | `/api/v1/master/meta/activity_trend?days=30` | Stacked bar source |
| GET | `/api/v1/master/meta/alerts` | Active health alerts |
| POST | `/api/v1/master/meta/emergency_revoke` | Per-candidate revoke |
| POST | `/api/v1/master/meta/force_refresh` | Bulk force refresh |
| POST | `/api/v1/master/meta/app_wide_pause` | Toggle pause |

---

## Required backend services (out of scope for Step 5)

These services are referenced by the dashboard but not built in this phase:

- **App health check worker** — daily cron that queries Meta's `/{app_id}` endpoint to read App Review status, verification status, current rate limit tier; updates `meta_app_health` row
- **Aggregate metrics worker** — every 15 min, recomputes connected/revoked/expired counts and 24h OAuth metrics
- **Health alert generator** — runs after each metric refresh; evaluates trigger conditions; updates `health_alerts` JSONB

---

*End of master tier UI spec. No frontend code written. No backend services beyond what's in Step 5.*
