# Session transcript + TODOs (Cursor) — 2026-04-01

**Before anything else:** `sessions/SESSION_START_READ_ME_FIRST.md` + `sessions/PERPLEXITY_HIGHLIGHTS.md` (mandatory every session). **Commit `sessions/` to GitHub** or handoffs stay invisible outside Cursor.

**Audience:** Ed, Perplexity, Claude — anyone with repo access.  
**Location:** `sessions/2026-04-01_session_transcript_todos.md`

---

## Transcript (condensed)

### Candidate / committee matching

- **`committee_registry`:** Split clarified: **~9,773** NULL `candidate_name` = **~793** (have `sboe_id`, missing name) + **~8,980** (no `sboe_id` — party/PAC, different problem). After backfills, live **`sboe_id` + no name** count dropped (Cursor audit: **305** with type breakdown — OTHER/COUNTY_REC/COUNTY_PARTY/etc.).
- **`staging.boe_donation_candidate_map`:** Post-rebuild, **~99.67%** non-empty `candidate_name`; top names spot-check as real NC candidates (not garbage). Older **~66.6%** baseline referred to **pre-session** state.
- **`boe_donation_candidate_map` join:** `candidate_name` comes from rebuild SQL (e.g. `committee_registry` / staging paths in `sessions/2026-04-01_partisan_flag_fix.sql`) — **not** automatically from `committee_registry` alone unless bridge/rebuild includes it.
- **Steps A/B (map → NCSBE → registry):** Step A backfilled `ncsbe_candidates.committee_sboe_id` from `boe_committee_candidate_map`; Step B updated `committee_registry.candidate_name` from NCSBE pick — **193** registry rows updated initially; later work improved registry further.
- **`republican_candidate_committee_master` / CSV:** Staging tables present: `staging.csv_candidate_committee_master` (**1,091** rows), `staging.sboe_committee_master` (**13,237** rows). CSV ↔ registry still-null overlap nearly exhausted (**1** row) after tonight's work.
- **Donations still missing `candidate_name`:** **1,105** rows — **420** have registry row but no name path; **685** `committee_sboe_id` not in registry (not "113K" on current map).

### Donor merge queue (7-pass)

- Script: `sessions/2026-04-01_donor_merge_7pass_queue.sql` — **queue only** → `staging.donor_merge_candidates`; **no** spine merges executed.
- Passes 1–6 designed to run in **one** SQL session (temp tables). Pass 7 (committee overlap) may need performance tuning.
- **Ed / Melanie safety check** still required before any merge **execution**.

### Rollup authorization (stopped)

- Ed authorized rollup with gates: **`will_insert` > 108,943**, **Broyhill canary** `SUM(amount)` vs **$478,632**, **spine aggregate refresh** after commit.
- **Cursor did not execute rollup:** `sessions/2026-04-01_CURSOR_AUDIT_RESPONSE.md` was not in worktree; no `will_insert` / `INSERT INTO core.contribution_map` body in repo for that run. **`sessions/donor_rollup_execute.sql`** builds staging passes only — **no** final INSERT.
- User said **stop** — no mutating rollup run from Cursor after that.
- **Pre-rollup baselines captured (read-only):** `NC_BOE` rows in `core.contribution_map` = **108,943**; raw eligible ~**338,213**; ~**229,270** raw rows without `NC_BOE` map row; Ed `person_id` **26451** NC_BOE sum in CM ≈ **$132,763.36** (54 txns); all sources CM ≈ **$352,415.86**.

### Tooling

- Supabase `execute_sql` sometimes read-only for `UPDATE` in some sessions; writable at other times — if writes fail, use SQL editor or direct DB.

---

## TODOs

### P0 — Before rollup (Ed)

- [ ] **Sync** `sessions/2026-04-01_CURSOR_AUDIT_RESPONSE.md` (or equivalent) into this repo with the **exact** rollup SQL: `will_insert` preflight, `INSERT INTO core.contribution_map`, **spine aggregate `UPDATE`**.
- [ ] **Confirm** interpretation of **`will_insert > 108,943`** (new rows this run vs total after vs diagnostic name).
- [ ] **Run rollup** in Supabase (or Cursor once SQL is present) and record:
  - [ ] `will_insert` / post-insert **NC_BOE** row count **> 108,943**
  - [ ] Ed canary: **NC_BOE** `SUM(amount)` for `person_id = 26451` before vs after; delta vs **$478,632** target
  - [ ] **Spine aggregates** refreshed immediately after commit
- [ ] User said **stop** on Cursor executing rollup — **re-confirm** with Ed before any agent runs writes.

### P1 — Candidate data

- [ ] Reconcile **305** (or current) **`sboe_id` + no `candidate_name`** — party vs OTHER vs true gaps; design: attribute party donations to committee label vs "candidate name."
- [ ] **685** donations: `committee_sboe_id` missing from `committee_registry` — backfill registry or accept unmatched.

### P2 — Donor merge queue

- [ ] Finish **Pass 7** + **row counts by `match_method`** on `staging.donor_merge_candidates`.
- [ ] Run **Broyhill safety** query (Ed vs Melanie not paired) on merge candidates before execution.
- [ ] **Do not** execute merges until Ed signs off.

### P3 — Hygiene

- [ ] Reconcile **338,223** raw vs **338,213** staging map row count (10 rows).
- [ ] Document whether **`donor_rollup_execute.sql`** should gain a final **INSERT** block or stay staging-only with a separate "commit" script.

---

## Related files (this repo)

| File | Purpose |
|------|--------|
| `sessions/2026-03-30_session_wrapup.md` | Earlier wrap-up |
| `sessions/2026-04-01_donor_merge_7pass_queue.sql` | Merge **queue** only |
| `sessions/2026-04-01_partisan_flag_fix.sql` | Rebuild `boe_donation_candidate_map` + partisan flag |
| `sessions/donor_rollup_execute.sql` | Staging passes + canary SELECTs; **no** CM insert |
| `sessions/2026-03-31_donor_rollup_patches.sql` | Pass 1/3/5 patches |
| `database/migrations/086_completion_fixes.sql` | Spine aggregate refresh pattern (Block B) |

---

*Generated by Cursor for handoff to Perplexity / team.*
