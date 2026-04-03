# Highlights for Perplexity — BroyhillGOP (read this first)

**Canonical path:** `sessions/PERPLEXITY_HIGHLIGHTS.md` — **commit and push this file** so GitHub / Perplexity / other machines see it. (A dated duplicate may exist only in some worktrees.)

**Stop:** Read `sessions/SESSION_START_READ_ME_FIRST.md` first — every session, every assistant (Cursor, Perplexity, etc.). We lost ~6 hours when handoffs were skipped.

**Purpose:** One-page orientation. Full detail: `sessions/2026-04-01_session_transcript_todos.md` (or latest `*_session_transcript_todos.md`).

---

## 1. Staged dedupe / rollup (NC BOE → spine) — **where it lives**

| What | Path |
|------|------|
| **Main multi-pass SQL** (builds `staging.staging_pass1` … `pass7`) | `sessions/donor_rollup_execute.sql` |
| **Patches** (Pass 1 spouse-safe, Pass 3 employer, Pass 5 fingerprint) | `sessions/2026-03-31_donor_rollup_patches.sql` |
| **Spec / brief** | `sessions/2026-03-31_DONOR_ROLLUP_CURSOR_BRIEF.md`, `sessions/2026-03-31_DONOR_ROLLUP_IDENTITY_SPEC.md` |

**Important:** `donor_rollup_execute.sql` does **not** `INSERT` into `core.contribution_map`. It only materializes **staging pass tables** + canary `SELECT`s. The **commit** step (INSERT + spine aggregate refresh) is a **separate** script — must be supplied (e.g. from audit response doc) before "rollup" is complete.

---

## 2. Don't confuse with **person merge queue**

| What | Path |
|------|------|
| **7-pass merge candidates** (queue only, no spine merge executed) | `sessions/2026-04-01_donor_merge_7pass_queue.sql` → `staging.donor_merge_candidates` |

That is **spine dedupe proposals**, not the BOE→DataTrust rollup passes.

---

## 3. Candidate / committee matching (BOE donation map)

| What | Path / table |
|------|----------------|
| Rebuild staging map + partisan fix | `sessions/2026-04-01_partisan_flag_fix.sql` → `staging.boe_donation_candidate_map` |
| Fuzzy / cleaned name bridge | `sessions/2026-03-31_committee_candidate_fuzzy_match.sql`, `sessions/2026-04-01_committee_name_clean_patch.sql` → `staging.committee_candidate_bridge` |
| CSV / SBOE staging | `staging.csv_candidate_committee_master`, `staging.sboe_committee_master` |

**Fact check:** High `candidate_name` fill on `boe_donation_candidate_map` came from **rebuild join logic**, not from `committee_registry` alone unless the rebuild uses it.

---

## 4. Rollup execution status (Cursor)

- Ed authorized rollup with gates: **`will_insert` > 108,943**, **Broyhill canary** vs **$478,632**, **spine refresh** after commit.
- **Not run** from Cursor: authorized SQL body not in worktree; user said **stop**.
- **Baselines captured (read-only):** `NC_BOE` rows in `core.contribution_map` = **108,943**; Ed `person_id` **26451** NC_BOE sum in CM ≈ **$132,763.36** (54 txns); raw rows without CM row ≈ **229,270** (eligible slice).

---

## 5. P0 TODOs for whoever runs rollup

1. Obtain full SQL: `will_insert` + `INSERT INTO core.contribution_map` + spine `UPDATE` from `contribution_map` aggregates (pattern: `database/migrations/086_completion_fixes.sql` Block B).
2. Re-confirm with Ed before agents run writes.
3. Run gates; then rollup; then merge queue only if separately authorized.

---

## 6. Other dedupe in repo (different layer)

- `pipeline/dedup.py`, `docs/PIPELINE_DEDUP_ARCHITECTURE.md` — pipeline / `dedup_key` / identity clusters, **not** the same as `donor_rollup_execute.sql` passes.

---

*BroyhillGOP handoff — keep this file in version control.*
