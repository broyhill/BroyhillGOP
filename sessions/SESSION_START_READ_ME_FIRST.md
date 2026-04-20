# SESSION START — READ THIS ENTIRE FILE BEFORE DOING ANYTHING
**BroyhillGOP | Last updated: 2026-04-20 10:30 AM EDT by Nexus**
**Authority: Ed Broyhill | NC National Committeeman | ed.broyhill@gmail.com**

---

## ⚡ ORIENTATION — READ FIRST (2 minutes)

**Hetzner is the truth source. Supabase is legacy.**
The full donor/voter database (238 GB, 321,348 NCBOE spine rows, 7.7M DataTrust voters) lives on Hetzner `37.27.169.232`. Supabase only holds `brain.agent_messages`, `brain.decisions`, and the Storage bucket. Do not query Supabase for donor data and present numbers as authoritative.

**Ed is EDGAR, not EDWARD.** Full legal name: James Edgar Broyhill II. Always.

**The canary.** Before touching anything, verify cluster 372171 on `raw.ncboe_donations`:
- Expected: `txns=147` | `total=$332,631.30` | `p_email=ed@broyhill.net`
- If you see 627 txns or $1.3M → you are on an old inflated table. Stop.
- If you see `jsneeden@msn.com` → Apollo bad data. Clear it before proceeding.

---

## 🚨 NIGHTMARE HISTORY — DO NOT REPEAT

This database has been corrupted **13+ times** by AI agents. The incidents:

1. **7.4x Transaction Inflation (April 14-15):** Naive loading without cross-file dedup inflated $162M to $1.2B. Ed's canary went from $332K to $1.3M.
2. **53,636 Records Deactivated (April 7):** Claude bulk-flipped 53K spine records with no audit trail.
3. **$417K Contribution Loss (March 27–April 6):** Rollup operations deleted contribution_map rows.
4. **NCBOE Contamination (13 incidents):** Files loaded without TRUNCATE-first protocol.
5. **April 18 schema errors:** Agent wrote DDL with wrong column types (BIGINT vs TEXT for rnc_regid) and wrong column names (ncid vs state_voter_id) without running information_schema lookups first.

**Pattern:** Every incident was caused by writing SQL from memory instead of querying the real schema. Verify before writing. Always.

---

## 🔌 CONNECTING TO HETZNER

### Method A — Bore tunnel (fastest for Nexus/sandbox)
Ed runs this on the server (`root@broyhillgop-db` via Tailscale):
```bash
curl -sL https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz | tar xz -C /tmp && /tmp/bore local 5432 --to bore.pub
```
Ed pastes back `bore.pub:XXXXX`. Nexus connects: `psql -h bore.pub -p XXXXX -U postgres -d postgres`

### Method B — Direct (after Hetzner network lock lifts)
```
psql -h 37.27.169.232 -p 5432 -U postgres -d postgres
Password: XanypdTxZb3qRE8bUdGXFGGK
```
UFW + pg_hba.conf already configured for sandbox IP `136.109.176.148`.

### Method C — Relay (fallback, no setup)
Ed runs on his Mac: `ssh root@hetzner-1 "sudo -u postgres psql -d postgres -c '...'"` and pastes output.

### SSH to server
```bash
ssh root@hetzner-1       # From Ed's Mac via Tailscale (Tailscale IP: 100.108.229.41)
ssh root@37.27.169.232   # BLOCKED — Hetzner network lock on public IP
```

### ⚠️ Tailscale cannot work from Perplexity sandbox
The sandbox has a `169.254.x.x` APIPA interface. Tailscale sees `v4=false` and auth never completes. This is a hard constraint — do not spend session time on it.

---

## ✅ MANDATORY PRE-FLIGHT (every session, no exceptions)

### Step 1 — Session state
```sql
SELECT state_md FROM public.session_state ORDER BY id DESC LIMIT 1;
```

### Step 2 — Row counts
```sql
SELECT
  (SELECT COUNT(*) FROM raw.ncboe_donations)                                  AS ncboe_rows,
  (SELECT COUNT(DISTINCT cluster_id) FROM raw.ncboe_donations)                AS clusters,
  (SELECT COUNT(*) FROM raw.ncboe_donations WHERE rnc_regid IS NOT NULL)      AS voter_matched,
  (SELECT COUNT(*) FROM raw.ncboe_donations WHERE cell_phone IS NOT NULL)     AS cell_populated,
  (SELECT COUNT(*) FROM raw.ncboe_donations WHERE personal_email IS NOT NULL) AS email_populated;
```
**Expected: ncboe_rows=321,348 | clusters=98,303. If off — STOP.**

### Step 3 — Canary
```sql
SELECT cluster_id, COUNT(*) AS txns, SUM(norm_amount) AS total,
  MAX(cell_phone) AS cell, MAX(home_phone) AS home,
  MAX(personal_email) AS p_email, MAX(business_email) AS b_email,
  BOOL_OR(trump_rally_donor) AS rally
FROM raw.ncboe_donations WHERE cluster_id = 372171 GROUP BY cluster_id;
```
**Expected: txns=147 | total=$332,631.30 | p_email=ed@broyhill.net**

### Step 4 — Schema verify (NEW — added after April 18 incident)
Before writing any DDL or DML that touches a join key, run:
```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE column_name IN ('<your_columns>')
ORDER BY table_schema, table_name, column_name;
```
Do not write SQL against a remembered schema. Query the real schema.

### Step 5 — Report to Ed
State counts, canary result, and connection method used. Wait for Ed to say what to work on.

---

## ⛔ ABSOLUTE PROHIBITIONS

These require Ed to type exactly: **`I AUTHORIZE THIS ACTION`**
"Yes", "go ahead", "do it" are NOT authorization.

| Prohibited Action | Why |
|---|---|
| TRUNCATE any table | Destroyed 2.4M rows + 5 hours of work |
| DROP TABLE or DROP COLUMN | Irreversible |
| DELETE without WHERE clause | Full-table wipe |
| ALTER TABLE removing/renaming columns | Breaks all dependent queries |
| Any DDL on `raw.ncboe_donations` | Sacred spine |
| Re-run `ncboe_dedup_v2.py` | Already ran — output is the 321,348 spine |
| Re-run `datatrust_enrich.py` | Already ran |
| Bulk UPDATE > 10,000 rows | Must be reviewed first |
| Aggregate/rollup without verification | Caused 7.4x inflation |

---

## 📋 CURRENT STATE (as of 2026-04-20)

### Complete
- NCBOE dedup → 321,348 rows / 98,303 clusters ✅
- DataTrust voter enrichment ✅
- `core.donor_profile` Stage 1: 98,303 rows, 80,605 voter-matched ✅

### Pending (priority order)
1. Bore tunnel / Hetzner lock lift → direct Nexus DB access
2. Committee party rollup for cluster 372171
3. Stage 1b business-address bridge (files at `sessions/2026-04-18/donor_profile_stage1/01b_bridge_ddl.sql`)
4. Fix Dropbox nightly backup (rclone config broken since April 14)
5. Backfill candidate_name on 88,256 downballot 'U' rows
6. Update `public.session_state` on Hetzner

---

## 🔑 KEY TABLES

| Schema.Table | Rows | Purpose |
|---|---|---|
| `raw.ncboe_donations` | **321,348** | NCBOE spine — SACRED |
| `core.datatrust_voter_nc` | 7,727,637 | DataTrust voter file |
| `core.donor_profile` | **98,303** | Stage 1 complete |
| `core.acxiom_ap_models` | 7,655,593 | Acxiom scores |
| `core.republican_power_brokers` | 2,664 | Power-broker scorecard |

**Join chain:** `nc_voters.ncid = DataTrust.StateVoterID → DataTrust.RNC_RegID = Acxiom.RNC_RegID`
**All rnc_regid columns are TEXT** — never cast to BIGINT.
**DataTrust NC voter ID column is `state_voter_id`** — not `ncid`.

---

## 📚 KEY DOCUMENTS

| File | Purpose |
|---|---|
| `SESSION-STATE.md` (root) | Current state snapshot — read this |
| `sessions/2026-04-18/ACCOUNTABILITY_2026-04-18.md` | What went wrong April 18 + rules |
| `sessions/2026-04-18/donor_profile_stage1/04_runbook.md` | Stage 1 runbook |
| `sessions/2026-04-18/phase2_committee_replication/MATCH_RATE_DIAGNOSIS.md` | Committee match rate issue |
| `sessions/DONOR_DEDUP_PIPELINE_V2.md` | 7-stage dedup reference |

---

*This file supersedes all prior versions. Previous versions referenced Supabase as primary truth source — that is incorrect as of April 2026. Hetzner is primary.*
