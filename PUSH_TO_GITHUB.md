# PUSH_TO_GITHUB — Step 8 Instructions

**Status:** Step 7 complete. Ready for Step 8 only when you authorize.

This document describes how to push the Step 5b Meta Tech Provider build to GitHub `broyhill/BroyhillGOP`.

⚠️ **DO NOT PUSH YET** unless I (Claude) have explicit `Authorize Step 8` from you.

The DEPLOY BLOCK protocol from your memory mandates explicit approval before any GitHub operation.

---

## What gets pushed

A single git commit with 28 tracked files representing Step 5b complete:

```
commit 9cd090f
"feat: Meta Tech Provider with full Brain integration"

19 source files + 9 __init__.py files = 28 tracked files
1,640 lines of test code
1,274 lines of SQL across 2 migrations
3,005 lines of Python services
2 architecture docs (README + META_TECH_PROVIDER_ARCHITECTURE.md)
2 control panel UI specs

Total: ~7,091 lines of new content
```

**Tests:** 87 passing.
**Migrations:** Both dry-run only — no DB schema applied.

---

## Two ways to push

### Option A: I push from my container (requires PAT)

You paste a fine-grained PAT scoped to `broyhill/BroyhillGOP` with 1-day expiry. I run a single push command. The PAT never persists past the session.

**Constraints:**
- PAT scope: `Contents: Read and write` on `broyhill/BroyhillGOP` only
- PAT expiry: ≤24 hours
- I will NOT save the PAT to any file
- I will run exactly: `git push https://x-access-token:${PAT}@github.com/broyhill/BroyhillGOP.git step5b-meta-tech-provider:step5b-meta-tech-provider`
- After push completes I confirm push succeeded and you immediately revoke the PAT in GitHub settings

### Option B: You push from your Mac (more conservative)

I produce a git bundle (`meta_tech_provider_design.bundle`) which you fetch on your Mac. You inspect everything, then push under your own credentials. No token needed from me.

**On your Mac:**

```bash
# 1. Get the bundle (already in /mnt/user-data/outputs/)
# Download meta_tech_provider_design.bundle to your Mac.

# 2. Clone the bundle into a working directory
cd ~/Documents
git clone meta_tech_provider_design.bundle meta-tech-provider-review
cd meta-tech-provider-review

# Bundles sometimes don't auto-checkout main; do it explicitly.
# This is harmless if main is already checked out.
git checkout main

# 3. Inspect everything you want
git log --stat
ls -R
cat README.md
cat META_TECH_PROVIDER_ARCHITECTURE.md
# ... read whatever you want

# 4. Run the test suite locally (optional but recommended)
python3 -m pytest ecosystems/E19_social/onboarding/tests/ -v
# Should output: 87 passed

# 5. Add the BroyhillGOP repo as a remote
git remote add origin https://github.com/broyhill/BroyhillGOP.git

# 6. Push as a NEW BRANCH (not main — protect main)
git push origin main:step5b-meta-tech-provider

# 7. Open a PR on GitHub
# Web: https://github.com/broyhill/BroyhillGOP/compare/main...step5b-meta-tech-provider
# Review the diff carefully. Merge when satisfied.
```

**Recommended:** Option B unless you specifically want me to push.

---

## Pre-push checks

Before either option:

- [ ] Locked rules verified (see README.md "Locked rules audit")
- [ ] All 87 tests passing locally
- [ ] No `__pycache__` or `.pytest_cache` directories in tarball/bundle
- [ ] Both migrations are idempotent (`ON CONFLICT DO UPDATE` everywhere)
- [ ] No real Meta App credentials in any file
- [ ] No real Postgres connection strings in any file
- [ ] No FEC/NCBOE files modified
- [ ] No identity resolver changes
- [ ] No mods to existing `ecosystem_19_social_media_*.py` files (Tech Provider runs alongside)

You can verify the last three with:

```bash
cd meta-tech-provider-review
grep -rn "FEC\|NCBOE" --include="*.py" --include="*.sql"
# Should show only "[x] No FEC/NCBOE touched" comments

grep -rn "edward\|normalize.*ed" --include="*.py"
# Should show 0 results (no identity resolver code)

# Existing E19 files NOT in this commit:
git ls-files | grep "ecosystem_19_social_media"
# Should show 0 results (we don't modify them)
```

---

## Post-push (whichever option)

Once pushed and merged to main:

1. **Branch protection check:** Ensure `step5b-meta-tech-provider` PR was reviewed before merge to main
2. **DO NOT apply migrations to production yet** — Step 8 push is just the code, not DB changes
3. **Migration application is a separate step (Step 9, not authorized)** that requires:
   - Meta Business Verification submitted (calendar gate)
   - Meta App Review submitted for `pages_messaging` + `instagram_manage_messages` (calendar gate)
   - Concrete `psycopg2`-backed implementations of abstract interfaces written
   - HTTP routes wiring OAuth handler to `/v1/webhooks/meta/*` written
   - At least one pilot candidate identified for end-to-end test
4. **Consider:** Tag the commit `step5b-tech-provider-v1` for clear deployment lineage

---

## What to look for during your review

### High-risk areas

1. **`migrations/102_meta_tech_provider.sql`** — Adds 13 columns to `candidate_social_accounts`. Verify no column name collision with existing E19 columns. Check RLS policies match your existing pattern.
2. **`migrations/103_brain_control_registration.sql`** — Pre-flight checks gracefully handle missing tables. Verify ecosystem code `E19_TECH_PROVIDER` doesn't conflict with anything in your existing `brain_control.ecosystems`.
3. **`shared/security/token_vault.py`** — AES-256-GCM impl. Audit the AAD construction (uses candidate_id as authentication tag) and key derivation. This is crypto code; reading carefully matters.
4. **`shared/event_bus/publisher.py`** — Verify the canonical event format matches what `ecosystem_20_intelligence_brain.py` actually expects. If your Brain consumer requires different field names, update before merge.
5. **`ecosystems/E19_social/onboarding/business_login_handler.py`** — The big one. 797 lines. The 11-step OAuth flow. Read top to bottom.

### Locked rules to spot-check

- Every event published includes `event_id`, `ecosystem`, `candidate_id`, `timestamp` (canonical format)
- Every Meta API call has a try/except that publishes a `social.*.failed` or `social.token.refresh_failed` event
- Every automation entry point calls `is_paused(reader, candidate_id)` before acting
- Every audit log INSERT happens BEFORE the corresponding action (so even if the action crashes, the attempt is logged)

### Easy mis-reads to avoid

- **F901-F904** are NOT existing function codes — they're new, in the unused 900s range. They will not collide with NEXUS's NX01-NX08 or production F001-F899.
- **`automation_workflows`** registration is best-effort. If your production doesn't have that table yet, migration 103 prints a notice and skips that block. The migration succeeds anyway.
- **Replay queue** (`meta_event_bus_replay_queue`) is in migration 102, not 103. It's a Tech Provider table, not a brain_control table.
- **No drop of `facebook_page_token` column.** Existing code keeps reading it. New code reads from `meta_page_tokens` (which doesn't exist yet — that's Step 9, not in this push).

---

## Files in this bundle

```
meta_tech_provider_design.tar.gz   ← Full directory tree (browsable on Mac)
meta_tech_provider_design.bundle   ← Single-file git repo (`git clone <bundle>`)
```

Both contain the same content. The tarball lets you browse files. The bundle lets you `git clone` into a real repo for inspection and pushing.

---

## Decision checkpoint

Reply with:

- **`Authorize Step 8 — option A`** → I push from my container; you paste a 1-day PAT
- **`Authorize Step 8 — option B`** → You push from your Mac using the bundle (recommended)
- **`Hold`** → Just inspect locally; we'll come back to push later
- **`Stop`** → Close this work entirely

---

*Step 7 complete. No GitHub interaction yet. Awaiting Step 8 authorization.*
