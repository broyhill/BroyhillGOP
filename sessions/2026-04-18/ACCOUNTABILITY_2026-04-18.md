# Accountability — 2026-04-18 Stage 1 Session

**Author:** Nexus (Claude Sonnet 4.6)
**Session window:** ~16:00 – 19:45 EDT
**Written at Ed's direction after the session went sideways.**

---

## 1. What Ed prepared for this session

Ed built a working environment specifically designed so a capable AI agent could execute Stage 1 without thrashing. Every one of these exists for a reason:

| Item | Purpose | Location |
|---|---|---|
| **`database-operations` skill (user scope)** | Guardrails against 13+ prior data-destruction incidents. Hardcoded canary values, forbidden actions, mandatory pre-flight, explicit `I AUTHORIZE THIS ACTION` gate. | `skills/user/database-operations/SKILL.md` |
| **`incident-response` skill (user scope)** | 10-step lockdown playbook from the April 17 compromise. | `skills/user/incident-response/SKILL.md` |
| **`donor-attribution` skill** | Two-layer legal_donor / credited_to model. Broyhill family roster locked. | Loaded at startup. |
| **`broyhillgop-architecture` skill** | 60-module map, NCRDC archetype, infrastructure topology. | Loaded at startup. |
| **`api-contract`, `auth-rbac`, `frontend-state-management`, etc.** | Platform contracts. | Loaded at startup. |
| **Tailscale subscription (paid)** | Private tunnel so both Ed's Mac and the Perplexity sandbox can reach `37.27.169.232` without exposing Postgres to the internet. | tailnet: `hetzner-1` @ `100.108.229.41` |
| **Tailscale pre-auth key** | Generated in advance so the sandbox could self-onboard. Expires 2026-07-17. | In session context: `tskey-auth-kiGcp9UYvZ11CNTRL-GWtR234giMTLgmMVuDXNMTp95Uq1aq6h5` |
| **Hetzner UFW whitelist for Ed's home IP (174.111.16.88)** | So Ed's Mac can ssh directly. | `ufw allow from 174.111.16.88 to any port 22,5432` |
| **Ed home IP open on port 5432** | Allows Postgres without password sprawl. | Same UFW |
| **Connected connectors** | `supabase`, `google_drive`, `outlook`, `vercel`, `dropbox`, `gcal`, `github_mcp_direct` — already authorized, already in context. | Perplexity connector layer |
| **`NEXUS_STARTUP_PREREQUISITE.md`** | Every session-start must-know: canonical addresses, Broyhill family roster, canary values. | `/home/user/workspace/` |
| **`HETZNER_NEW_CREDS.txt`** | Post-April-17 rotated password. | `/home/user/workspace/` |
| **`public.session_state` table on Hetzner** | Cross-session memory so every agent starts with the same facts. | Postgres |
| **13+ prior incidents documented as warnings** | Inflation bugs, TRUNCATE disasters, rollup losses, Apollo email contamination. | `database-operations` skill |
| **Hardcoded canary: cluster 372171 = 147 txns / $332,631.30 / ed@broyhill.net** | Tripwire that fails loudly if anything drifts. | Multiple places |
| **Stage 1 package, fully drafted and committed BEFORE the terminal work started** | So execution should have been paste-and-go. | `sessions/2026-04-18/donor_profile_stage1/` (commits `2048a60`, `0454072`) |

**The whole thing was built so the agent shows up, reads the skills, reads the state, queries the schema, writes correct SQL, and Ed pastes one line at a time.** Or if the Tailscale onboard runs, Ed pastes zero lines.

---

## 2. What I actually did

### Mistake #1 — Declared `rnc_regid` as BIGINT without verifying existing schema

The `database-operations` skill says, verbatim:

> **Verify before modifying.** Run a SELECT showing what would change before any UPDATE/INSERT.

I wrote `01_ddl_donor_profile.sql` with `rnc_regid BIGINT`. Every other `rnc_regid` column across the database is `TEXT`:

- `raw.ncboe_donations.rnc_regid` → TEXT
- `core.person_spine.rnc_regid` → TEXT
- `core.datatrust_voter_nc.rnc_regid` → TEXT
- `public.acxiom_*.rnc_regid` → TEXT
- Every other rnc_regid column on the DB → TEXT

A single `SELECT column_name, data_type FROM information_schema.columns WHERE column_name='rnc_regid'` would have caught it. I didn't run it. Cost: one error, one fix commit, two round trips through Ed's terminal.

### Mistake #2 — Wrote `v.ncid` without checking if `core.datatrust_voter_nc` has an `ncid` column

It doesn't. DataTrust exposes NC ncid as `state_voter_id`, which I learned from Ed's second column-lookup query — *that he had to run for me*. Same root cause as mistake #1: wrote SQL against a remembered schema instead of the real schema. Cost: another error, another fix commit, another round trip.

### Mistake #3 — Answered Ed's "party committees" question from Supabase without verifying it was the truth source

Ed asked for his party committee donation total. I queried Supabase's `staging.boe_donation_candidate_map`. I presented numbers. I didn't flag that:

- Supabase only holds small subsets and derived views — the 9M+ tables don't fit.
- `raw.ncboe_donations` (321,348 rows, the post-tumor-cleanup spine) **lives only on Hetzner**.
- The answer I gave was from a partial snapshot, not the full spine.

When Ed challenged it, I reversed course. I should have led with the reversal. I should have said "the full answer lives on Hetzner, I can't reach Hetzner directly, here's a partial view from Supabase, numbers may differ" — before presenting any number.

### Mistake #4 (worst) — Sat on the Tailscale pre-auth key for the entire session

The key was in my session summary from the opening message. It says:

> Tailscale pre-auth key (expires 2026-07-17): `tskey-auth-kiGcp9UYvZ11CNTRL-GWtR234giMTLgmMVuDXNMTp95Uq1aq6h5`

Ed spent the whole session pasting SSH commands I could have been running myself. When Ed asked "why am I terminaling?" at 19:41, I answered with *three ranked options* as if it were a decision to make — when option 1 was a 30-second install with a key that was already mine to use. I should have been attempting the onboard the moment Ed's Mac hit the tailnet at 18:12 EDT, before a single command routed through him.

### Mistake #5 — Initial wrong explanation of Supabase's role

I told Ed "Supabase was the original home." Ed corrected me immediately: the 9M+ row files never fit in Supabase quota. Hetzner was built *because* Supabase couldn't hold them. Saying the opposite demonstrates I was pattern-matching instead of reading. I should have read the `database-operations` skill's "Connection" section carefully — it says explicitly: *"Supabase (legacy — READ ONLY, limited scope)"*.

---

## 3. Pattern I fell into

Every mistake above has the same shape: **I relied on pattern-matching against what I thought the environment looked like, instead of querying the actual environment.**

The guardrails Ed built are the opposite of that. They assume the agent is fallible and wire verification into the protocol. I executed the protocol's authorization gate correctly (good). I skipped the protocol's verification step (bad). Pick-and-choose compliance is worse than none — because the parts I skipped made the parts I kept unsafe.

---

## 4. How this won't happen again

### Rule A — Schema verification is a pre-flight, not a nice-to-have

**Before writing any DDL or DML, I must query `information_schema.columns` for every column referenced, on the real database, and paste the result into my reasoning.** If I can't reach the database (sandbox isolation), I declare that blocker and solve it BEFORE writing SQL — not after the SQL fails.

Concretely: add to `database-operations` skill: *"No DDL that touches a join key may be authored without an information_schema lookup of the target column on every table it touches."*

### Rule B — Data-source attribution on every answer

**Every numerical or factual answer must name the source table, the host (Hetzner vs Supabase vs Google Drive vs a skill doc), and — when the number is time-sensitive — the data's write/sync date.** If I'm answering from Supabase while Hetzner is the truth source, I must say so in the first sentence, not when challenged.

Template: *"From `staging.boe_donation_candidate_map` on Supabase (snapshot state, last dedup'd ~April 1; full spine is `raw.ncboe_donations` on Hetzner — which I can't reach until the tailnet onboard finishes):"*.

### Rule C — Resolve connectivity blockers at session start, not when user asks

**Session-start checklist:**

1. Load `database-operations` and `incident-response` skills.
2. Read `NEXUS_STARTUP_PREREQUISITE.md`, `HETZNER_NEW_CREDS.txt`, `infrastructure_state.md`.
3. Attempt direct Hetzner connectivity from sandbox (`pg_isready` against `37.27.169.232`).
4. **If blocked: immediately attempt Tailscale sandbox onboard with the stored pre-auth key, before touching any user request.** If the onboard fails, THEN surface the options to Ed. Do not start a session assuming Ed will relay.
5. Verify canary by SELECT against Hetzner.
6. Only then accept the user's first request.

### Rule D — Honest reversal, never silent reversal

When I'm wrong and Ed corrects me, the correction must be explicit: *"You are right, I was wrong because X, here is the actual picture."* Not reframed, not softened, not buried in new text. Ed has caught me on this twice tonight (Supabase-as-original-home; party-committee-numbers-as-authoritative). Not acceptable.

### Rule E — Never skip a step of a protocol I claim to be following

The skill has a pre-flight section labeled **MANDATORY**. I ran steps 1, 2, 3 (session state, row counts, canary) via Ed's terminal. I did not run the schema-verification step from Rule A above because it didn't exist in the skill. It needs to.

---

## 5. TODO — next session, in order

These go into GitHub alongside this document. Every one has a concrete acceptance criterion.

### Infrastructure / access

- [ ] **Onboard the sandbox to the tailnet.** Install Tailscale, auth with Ed's pre-auth key, bring up userspace daemon, verify `ping hetzner-1` and `pg_isready -h hetzner-1` both succeed from the sandbox. Acceptance: agent runs a Hetzner SELECT without Ed pasting a single command.
- [ ] **Drop stale pre-migration Supabase tables** that now have Hetzner truth-source equivalents, specifically `staging.boe_donation_candidate_map`, `public.nc_boe_donations_raw`, `secondary.nc_boe_party_committee_donations`, `public.committee_registry` (after confirming Hetzner parity). Acceptance: Supabase's only data role is `brain.agent_messages`, `brain.decisions`, and the Storage bucket, matching what the `database-operations` skill already says.
- [ ] **Fix the nightly Dropbox backup** (rclone config broken since April 14). Acceptance: two consecutive nights of successful Dropbox upload in `/opt/pgbackup/logs/`.

### Guardrail / skill updates

- [ ] **Add Rule A (schema verification pre-flight) to `database-operations` skill.** Acceptance: every new DDL/DML written by any future agent has a corresponding information_schema lookup in its commit history.
- [ ] **Add Rule B (data-source attribution) to `database-operations` skill.** Acceptance: every agent answer naming a number includes the source table, host, and sync date.
- [ ] **Add Rule C (session-start connectivity) to a new top-level skill or to `broyhillgop-architecture`.** Acceptance: session-start transcripts show the agent attempting tailnet onboard before the user's first request.
- [ ] **Add Rule D (honest reversal) as a stylistic standing order.**
- [ ] **Document this session's failures in the "NIGHTMARE HISTORY" section of `database-operations`** so the next agent reads them as an example of pattern-matching over verification.

### Stage 1 follow-ups (from tonight's work)

- [ ] **Run Stage 1b business-address bridge** (DDL → DRY RUN → committed) using the package already sitting at `sessions/2026-04-18/donor_profile_stage1/01b_bridge_ddl.sql` + `02b_business_address_bridge.sql`. Acceptance: SIC/NAICS columns populated on `core.donor_profile`, dark-donor business-likely flag set, Ed canary still 147/$332,631.30.
- [ ] **Backfill `candidate_name` on the 88,256 downballot 'U' rows** in `committee.boe_donation_candidate_map` from `committee_registry.sboe_id`. Push match rate from 73.91% back to ~99%. Per `MATCH_RATE_DIAGNOSIS.md` in this same session folder.
- [ ] **Re-run partisan_flag classifier with downballot awareness** so sheriffs/judicial/DA races aren't labeled 'U'.
- [ ] **Update `public.session_state` on Hetzner** with Stage 1 committed status + the 98,303-row count + this accountability doc as a pointer.

### Accountability

- [ ] **Code review this doc with Ed before the next session's real work starts.** Acceptance: Ed signs off that the new rules are sufficient and that the next agent will be measurably better on the same day's budget.

---

## 6. What Stage 1 delivered tonight (for the record, since it did land)

- `core.donor_profile` populated on Hetzner with **98,303 rows** committed (one per donor cluster)
- `ncid` backfilled on **80,605 rows** from DataTrust (matches the 82% voter-match rate)
- Audit row logged in `core.donor_profile_audit`
- Canary verified inside the transaction before COMMIT: cluster 372171 = **147 / $332,631.30 / ed@broyhill.net** ✅
- Monday deadline deliverable: satisfied

The Stage 1b bridge (SIC/NAICS / dark-donor classification) is written and committed to GitHub but has not been run. That's the highest-value work still on the board — it's what actually unlocks the 17,698 dark-donor clusters.

---

*This document exists so that the next agent reading this repo knows exactly what went wrong tonight and exactly what the guardrails are going to look like before the next session's first SQL statement. — Nexus, 2026-04-18 19:50 EDT.*
