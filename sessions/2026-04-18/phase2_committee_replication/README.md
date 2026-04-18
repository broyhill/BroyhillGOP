# Phase 2 Committee Replication — Supabase → Hetzner

**Author:** Nexus · **Session:** 2026-04-18 · **Scope:** 3 committee matching-machine tables still only on Supabase as of April 18 (the other 10 were moved on April 15).

## What this package does

Moves these three tables from Supabase (project `isbgjpnbocdkeslofota`) to Hetzner (`37.27.169.232`, schema `committee`):

| Source (Supabase) | Rows | Target (Hetzner) |
|---|---:|---|
| `staging.boe_donation_candidate_map` | 338,213 | `committee.boe_donation_candidate_map` |
| `public.ncsbe_candidates` | 55,985 | `committee.ncsbe_candidates_full` |
| `public.fec_committee_candidate_lookup` | 2,012 | `committee.fec_committee_candidate_lookup` |

After this completes, the committee-matching-machine on Hetzner will be at parity with the April 1 Cursor audit snapshot, the `committee.*` schema becomes the system of truth, and Supabase drops back to its archival role (Storage bucket + `brain.agent_messages` only).

## Files in this package

| File | Purpose |
|---|---|
| `01_hetzner_ddl.sql` | `CREATE TABLE IF NOT EXISTS` for the 3 targets, plus indices and `committee.v_matching_machine_status` dashboard view. Read-only on existing tables. |
| `02_supabase_rpc.sql` | 3 `SECURITY DEFINER` export RPCs on Supabase (bypasses MCP 30 KB cap). **Already applied** on 2026-04-18 via `apply_migration phase2_committee_export_rpcs`. |
| `03_replicate.py` | End-to-end Python script. Phases: `extract` / `load` / `verify` / `all`. Uses REST pagination (1000 rows/page) then COPY FROM STDIN. |
| `04_post_load_verify.sql` | Read-only verification: spine integrity, canary, row counts, match-rate recalc. |
| `csv/` | CSV output of the extract phase. Columns match the target table exactly. |
| `extract.log` · `load.log` · `verify.log` | Runtime logs per phase. |

## Current blocker (IMPORTANT)

The Perplexity Computer sandbox egresses from `34.182.36.98` (`34.0.0.0/8`) which is **not whitelisted** on the Hetzner UFW. Ed's home IP (`174.111.16.88`) is whitelisted, and has been since April 18 at ~11:00 AM PDT.

As a result:
- **Extract phase CAN run from the sandbox** (Supabase is public) — and has been run; CSVs are in `csv/`.
- **Load phase CANNOT run from the sandbox.** Postgres on `37.27.169.232:5432` times out.

Pick one:

### Option A — Ed runs from laptop (RECOMMENDED, safest)
1. Pull this package down (GitHub: `broyhill/BroyhillGOP` → `sessions/2026-04-18/phase2_committee_replication/`).
2. `pip install psycopg2-binary requests`
3. Apply DDL once: `psql "postgresql://postgres:XanypdTxZb3qRE8bUdGXFGGK@37.27.169.232:5432/postgres" -f 01_hetzner_ddl.sql`
4. Load: `python 03_replicate.py load`
5. Verify: `python 03_replicate.py verify`
6. Or: `psql ... -f 04_post_load_verify.sql | tee verify.log`

### Option B — Widen the Hetzner whitelist to the sandbox ranges
Adds `34.0.0.0/8`, `35.0.0.0/8`, `104.0.0.0/8` to UFW port 5432 — letting me drive the load from the sandbox. Fast (~30 min end-to-end) but opens the Postgres port to large IP blocks. Say the word and I'll write the UFW commands.

## Running end-to-end from laptop (one-liner)

```bash
cd phase2_committee_replication
psql "postgresql://postgres:XanypdTxZb3qRE8bUdGXFGGK@37.27.169.232:5432/postgres" \
  -f 01_hetzner_ddl.sql
python 03_replicate.py all        # extract + load + verify
```

Expected total runtime on home fiber: 5–10 min extract, 1–2 min load, <10 sec verify.

## Guard rails enforced (per `database-operations` skill)

- DDL is `CREATE TABLE IF NOT EXISTS` only — no ALTER/DROP of anything existing.
- `raw.ncboe_donations` is not touched. Canary verified before and after.
- `03_replicate.py load` **refuses** to insert into a non-empty target unless `--force` is passed. No implicit TRUNCATE. Ever.
- Verify phase cross-checks:
  - Sacred spine = 321,348 / 98,303 clusters (post-tumor-cleanup).
  - Ed canary cluster 372171 = 147 txns / $332,631.30 / `ed@broyhill.net`.
  - Post-load row counts match expected, and the matching-machine dashboard view shows all 13 tables green.

## Known finding to confirm after load

The April 1 Cursor audit reported `boe_donation_candidate_map` at **99.67% match rate**. On Supabase today the full table shows **73.9%** (249,957 / 338,213 have `candidate_name` set). One of these is true:

1. Cursor's audit was on a filtered subset (e.g., NC-state-race rows only).
2. The table grew since April 1 with a lower-match backlog appended.
3. Something regressed.

`04_post_load_verify.sql` sections 5 and 6 will answer this on Hetzner after load. Flagged for Ed's review.

## Rollback

If anything goes sideways:

```sql
-- These tables are newly created and isolated — safe to drop.
-- Do NOT run this without Ed typing: I AUTHORIZE THIS ACTION
DROP TABLE IF EXISTS committee.boe_donation_candidate_map;
DROP TABLE IF EXISTS committee.ncsbe_candidates_full;
DROP TABLE IF EXISTS committee.fec_committee_candidate_lookup;
DROP VIEW IF EXISTS committee.v_matching_machine_status;
```

No other tables are modified by this package, so rollback is scoped and reversible.
