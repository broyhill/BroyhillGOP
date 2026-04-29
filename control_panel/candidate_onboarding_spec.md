# Candidate Onboarding UI Spec — Meta Tech Provider Connection

**Phase:** Step 5 of 8. UI not implemented; spec only.
**Tier:** Candidate-facing (within E26 Candidate Portal)
**Template base:** Inspinia HTML template, mobile-responsive

---

## Purpose

Provide a 90-second flow for a candidate to connect their Facebook + Instagram presence to BroyhillGOP, triggering Tech Provider provisioning under the hood.

The candidate should never need to:
- Visit business.facebook.com
- Understand what a Business Manager is
- Generate or copy any tokens
- Submit ID to Meta separately (BroyhillGOP App handles verification once)

---

## Screen 1: Connection landing page

**Route:** `/candidate/social/connect`

**State trigger:** Candidate has no row in `candidate_social_accounts`, or row has `bm_provisioning_status = 'pending'`.

### Layout

```
+------------------------------------------------+
|  [BroyhillGOP logo]                  [profile] |
+------------------------------------------------+
|                                                |
|        Connect Your Facebook & Instagram       |
|                                                |
|   To enable BroyhillGOP's social automation,   |
|   connect the Facebook Page and Instagram      |
|   account for your campaign.                   |
|                                                |
|   What we'll do:                               |
|   • Auto-respond to comments and DMs           |
|   • Personalize messages by donor history      |
|   • Track engagement back to donations         |
|   • Stay TCPA + FEC compliant automatically    |
|                                                |
|   What we won't do:                            |
|   • Post anything without your approval        |
|   • Access your personal messages              |
|   • Share your data with other candidates      |
|                                                |
|   ┌──────────────────────────────────────┐    |
|   │  [FB icon]  Connect Facebook & IG    │    |
|   └──────────────────────────────────────┘    |
|                                                |
|   Estimated time: 90 seconds                   |
|                                                |
|   [Why we need a Business Account →]           |
|                                                |
+------------------------------------------------+
```

### Behavior

- "Connect Facebook & IG" button calls `POST /api/v1/social/oauth/initiate`
- Response body contains `authorize_url`; frontend redirects window to it
- "Why we need a Business Account" expands an inline help section explaining the Tech Provider model in plain language

### Inline help text (when expanded)

> When you click Connect, Facebook will create a Business Account in your name (or use one you already have). This is what lets us manage your Page on your behalf — securely and reversibly.
>
> Your Business Account belongs to you, not to BroyhillGOP. You can revoke our access at any time from your Facebook settings. Each candidate's account is separate; nothing is shared.

---

## Screen 2: Meta-hosted OAuth

This screen is rendered by Meta, not by us. The candidate sees:

1. Facebook login (or already logged in — passes through)
2. "Continue as [Candidate Name]"
3. "BroyhillGOP would like to set up your business with Facebook"
   - One confirmation: "Continue"
4. "Choose a Business Portfolio"
   - Existing portfolios shown with radio buttons
   - "Create a new business portfolio for [Candidate Name]" pre-selected if none exist
5. "Choose Pages BroyhillGOP can manage"
   - Checkboxes for each Page they admin
   - Their campaign Page should already be selected if recognizable
6. "Choose Instagram accounts BroyhillGOP can manage"
   - Lists IG Business accounts linked to their selected Pages
7. "Permissions"
   - Lists requested permissions in plain language
   - "Allow" button

After Allow, Meta redirects to `https://api.broyhillgop.org/v1/webhooks/meta/oauth_callback?code=...&state=...`

---

## Screen 3: Connecting (loading state)

**Route:** `/candidate/social/connecting?state=...`

**State trigger:** OAuth callback received, provisioning in progress (typically 5–15 seconds).

### Layout

```
+------------------------------------------------+
|  [BroyhillGOP logo]                            |
+------------------------------------------------+
|                                                |
|              [animated spinner]                |
|                                                |
|        Setting up your account...              |
|                                                |
|   ✓ Connected to Facebook                      |
|   ✓ Found your Page: Smith for State Senate   |
|   ✓ Created secure access tokens               |
|   ⟳ Subscribing to messages and comments...   |
|                                                |
|   This usually takes about 10 seconds.         |
|                                                |
+------------------------------------------------+
```

### Behavior

- Backend processes callback (calls `business_login_handler.handle_oauth_callback`)
- Frontend polls `GET /api/v1/social/oauth/status?candidate_id=...` every 2 seconds
- Status field returned matches `bm_provisioning_status` column values
- When status becomes `provisioned`, redirect to Screen 4
- If status becomes `transfer_required`, redirect to Screen 5
- If status becomes `oauth_error`, redirect to Screen 6
- Hard 60-second timeout — if no terminal state by then, show error with retry

---

## Screen 4: Connected (success)

**Route:** `/candidate/social/connected`

**State trigger:** `bm_provisioning_status = 'provisioned'`

### Layout

```
+------------------------------------------------+
|  [BroyhillGOP logo]                  [profile] |
+------------------------------------------------+
|                                                |
|              ✓                                 |
|                                                |
|        You're connected!                       |
|                                                |
|   Connected accounts:                          |
|   • Smith for State Senate (Facebook Page)     |
|   • @smith_senate (Instagram Business)         |
|                                                |
|   What happens next:                           |
|   1. We'll start watching for comments and    |
|      DMs on your Page (within minutes)         |
|   2. Auto-responses follow your approval rules |
|   3. You'll see metrics in your dashboard      |
|                                                |
|   ┌──────────────────────────────────────┐    |
|   │   Go to Social Dashboard →           │    |
|   └──────────────────────────────────────┘    |
|                                                |
|   [Manage what's automated →]                  |
|                                                |
+------------------------------------------------+
```

---

## Screen 5: Transfer Required

**Route:** `/candidate/social/transfer-required`

**State trigger:** `bm_provisioning_status = 'transfer_required'`

### Layout

```
+------------------------------------------------+
|  [BroyhillGOP logo]                            |
+------------------------------------------------+
|                                                |
|         Page Transfer Needed                   |
|                                                |
|   Your Facebook Page is currently in someone   |
|   else's Business Account. To connect to       |
|   BroyhillGOP, the Page needs to be in your    |
|   own Business Account.                        |
|                                                |
|   Detected:                                    |
|   • Page: Smith for State Senate               |
|   • Currently in: [name redacted]              |
|                                                |
|   Two options:                                 |
|                                                |
|   ┌──────────────────────────────────────┐    |
|   │  Walk me through the transfer        │    |
|   └──────────────────────────────────────┘    |
|                                                |
|   ┌──────────────────────────────────────┐    |
|   │  Contact campaign support            │    |
|   └──────────────────────────────────────┘    |
|                                                |
|   This is the only manual step in the flow.   |
|   Once your Page is in your own Business      |
|   Account, click "Try Again" below.           |
|                                                |
|   [Try Again]                                  |
|                                                |
+------------------------------------------------+
```

The "Walk me through the transfer" button opens a step-by-step guide referencing Meta's documented Page transfer flow (link out to `business.facebook.com/help/...`).

---

## Screen 6: Connection Error

**Route:** `/candidate/social/error`

**State trigger:** `bm_provisioning_status = 'oauth_error'`

### Layout

```
+------------------------------------------------+
|  [BroyhillGOP logo]                            |
+------------------------------------------------+
|                                                |
|         Connection Didn't Complete             |
|                                                |
|   Something went wrong setting up your         |
|   connection. We've logged the issue and       |
|   our team has been notified.                  |
|                                                |
|   What you can do:                             |
|   1. Try again — most issues are temporary     |
|   2. Contact campaign support                  |
|                                                |
|   ┌──────────────────────────────────────┐    |
|   │  Try Again                            │    |
|   └──────────────────────────────────────┘    |
|                                                |
|   ┌──────────────────────────────────────┐    |
|   │  Contact Support                      │    |
|   └──────────────────────────────────────┘    |
|                                                |
|   Error reference: [audit log event_id]        |
|                                                |
+------------------------------------------------+
```

---

## Screen 7: Connection Status (ongoing)

**Route:** `/candidate/social/status`

Available from the candidate dashboard at any time after initial connection.

### Layout

```
+------------------------------------------------+
|  Social Connections                            |
+------------------------------------------------+
|                                                |
|   Facebook & Instagram                         |
|                                                |
|   Status: ✓ Connected                          |
|   Page: Smith for State Senate                 |
|   Instagram: @smith_senate                     |
|   Connected: April 12, 2026                    |
|   Token refresh: Daily, last successful 6h ago|
|                                                |
|   [Disconnect] [Re-authorize] [View activity]  |
|                                                |
|   ──────────────────────────────────────       |
|                                                |
|   Activity log (last 30 days):                 |
|                                                |
|   • Apr 28: Token refreshed successfully       |
|   • Apr 27: Webhook subscription verified      |
|   • Apr 21: Token refreshed successfully       |
|   • Apr 12: Initial connection                 |
|                                                |
+------------------------------------------------+
```

Activity log is read from `meta_oauth_audit_log` filtered to `candidate_id`.

---

## API endpoints required

These are the routes the frontend calls. They're not implemented in Step 5 — that's a separate piece of work for the route module that wires `business_login_handler.py` into FastAPI/Flask.

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/social/oauth/initiate` | Returns `authorize_url`, `state_token`. Calls `initiate_oauth()`. |
| GET | `/v1/webhooks/meta/oauth_callback` | OAuth callback. Calls `handle_oauth_callback()`. |
| GET | `/api/v1/social/oauth/status` | Returns current `bm_provisioning_status` for the candidate. |
| POST | `/api/v1/social/oauth/disconnect` | Calls `handle_revocation()`. |
| GET | `/api/v1/social/oauth/audit_log` | Returns recent audit log entries. RLS-isolated. |

---

## Accessibility

- All buttons keyboard-reachable
- Loading states announced via `aria-live="polite"`
- Error messages via `role="alert"`
- Focus management: after redirect, focus moves to the primary heading on each new screen

---

## Mobile considerations

Onboarding flow MUST work end-to-end on a phone:
- Meta's OAuth screens are mobile-responsive (controlled by Meta)
- Our screens use Inspinia's mobile-first responsive grid
- Spinner / status polling continues working when the user puts the phone down for a few seconds

---

*End of UI spec. No frontend code written. No routes wired up.*
