# Stage 1 — Unified Donor Profile — RUNBOOK (Mac-driven)

**Goal:** populate `core.donor_profile` with one row per real donor cluster (98,303 rows) so Ed has a single queryable donor rollup by Monday April 20, 2026.

**Who runs what:**
- **Ed** drives his Mac Terminal (one-line copy/paste commands over tailnet to `hetzner-1`).
- **Nexus** authored the SQL, watches the output, and gates each step.

**Why this path:** Sandbox is not on the tailnet, UFW on `37.27.169.232` does not whitelist sandbox egress, and Ed said no more open-terminal work. So Nexus ships the package and Ed runs three one-liners.

---

## Files in this package

| File | Purpose | Mutates? |
|---|---|---|
| `01_ddl_donor_profile.sql` | Create `core.donor_profile` + 5 companion tables | Creates tables only (no existing data touched) |
| `02_populate_donor_profile.sql` | Fill `core.donor_profile` from `raw.ncboe_donations` | Populates only the new table; sacred spine is read-only |
| `01b_bridge_ddl.sql` | Additive `ALTER TABLE` on `core.donor_profile` adding SIC/NAICS + business-address columns and `core.normalize_employer()` function | Adds columns + function; no row data touched |
| `02b_business_address_bridge.sql` | SIC/NAICS classifier (keyword + profession fallback) + HOME/BUSINESS address classifier + dark-donor business-likely flag | UPDATE-only on `core.donor_profile`; IS NULL guards throughout; row count preserved |
| `03_canary_verify.sql` | Read-only verification of the populated profile AND the bridge outputs | None |

All SQL targets Hetzner Postgres at `37.27.169.232` over the tailnet as `hetzner-1`.

---

## Pre-flight (Ed, Mac Terminal — all one-liners)

```bash
# 1. Sanity — am I still on the tailnet?
tailscale status | head -5

# 2. Can I reach Postgres as postgres?
ssh root@hetzner-1 "sudo -u postgres psql -Atc \"SELECT now(), version()\""

# 3. Confirm sacred canary BEFORE we touch anything
ssh root@hetzner-1 "sudo -u postgres psql -Atc \"SELECT COUNT(*) FROM raw.ncboe_donations; SELECT COUNT(*) AS txns, SUM(norm_amount) AS total, MAX(personal_email) AS email FROM raw.ncboe_donations WHERE cluster_id = 372171\""
```

**Expected for step 3:**
```
321348
147|332631.30|ed@broyhill.net
```

If row count is not `321348` or Ed canary is not `147 / 332631.30 / ed@broyhill.net`, **STOP** and message Nexus. Do not run the next step.

---

## Step 1 — create the tables (no mutation)

```bash
scp /Users/ed/BroyhillGOP/sessions/2026-04-18/donor_profile_stage1/01_ddl_donor_profile.sql hetzner-1:/tmp/01_ddl.sql
ssh root@hetzner-1 "sudo -u postgres psql -f /tmp/01_ddl.sql"
```

Expected output: six `CREATE TABLE` lines + six `CREATE INDEX` lines + one `COMMIT`. Zero rows touched anywhere.

*If you don't have the repo on the Mac yet, use this one-liner to pull it:*
```bash
cd /Users/ed && [ -d BroyhillGOP ] && (cd BroyhillGOP && git pull) || git clone https://github.com/broyhill/BroyhillGOP.git
```

---

## Step 2 — DRY RUN the populate (rolled back)

This is the authorization-gate step. We run the whole populate inside a transaction and let it validate the canary, then ROLLBACK so nothing actually persists yet.

```bash
scp /Users/ed/BroyhillGOP/sessions/2026-04-18/donor_profile_stage1/02_populate_donor_profile.sql hetzner-1:/tmp/02_pop.sql
# Swap COMMIT for ROLLBACK for dry run
ssh root@hetzner-1 "sed 's/^COMMIT;$/ROLLBACK;/' /tmp/02_pop.sql > /tmp/02_pop_dry.sql && sudo -u postgres psql -f /tmp/02_pop_dry.sql"
```

**What you should see at the end:**
```
NOTICE:  CANARY PASS: donor_profile rows=98303 | Ed canary txns=147 total=332631.30 email=ed@broyhill.net
ROLLBACK
```

If you see `CANARY FAIL: ...` — stop. Send Nexus the output verbatim. Do not proceed.

**At this point send Nexus the phrase `I AUTHORIZE THIS ACTION` to gate Step 3.** Do not send it until the DRY RUN above printed `CANARY PASS`.

---

## Step 3 — commit the populate (permanent)

Only after `I AUTHORIZE THIS ACTION`:

```bash
ssh root@hetzner-1 "sudo -u postgres psql -f /tmp/02_pop.sql"
```

Expected tail:
```
NOTICE:  CANARY PASS: donor_profile rows=98303 | Ed canary txns=147 total=332631.30 email=ed@broyhill.net
COMMIT
```

---

## Step 3b — run the business-address bridge

This extends `core.donor_profile` with SIC/NAICS industry, HOME vs BUSINESS address classification, and a dark-donor business-likely flag. Required before Stage 2 matching can use business addresses on the 17,698 unmatched clusters.

```bash
# Additive ALTER TABLE + core.normalize_employer() function (no row writes)
scp /Users/ed/BroyhillGOP/sessions/2026-04-18/donor_profile_stage1/01b_bridge_ddl.sql hetzner-1:/tmp/01b_ddl.sql
ssh root@hetzner-1 "sudo -u postgres psql -f /tmp/01b_ddl.sql"

# DRY RUN the bridge (rolled back)
scp /Users/ed/BroyhillGOP/sessions/2026-04-18/donor_profile_stage1/02b_business_address_bridge.sql hetzner-1:/tmp/02b_bridge.sql
ssh root@hetzner-1 "sed 's/^COMMIT;$/ROLLBACK;/' /tmp/02b_bridge.sql > /tmp/02b_bridge_dry.sql && sudo -u postgres psql -f /tmp/02b_bridge_dry.sql"
```

**Expected tail:**
```
NOTICE:  Ed 372171 bridge result: sic=..., method=..., address_class=...
NOTICE:  Bridge summary: rows=98303, sic_hit=<non-zero>, dark_biz=<positive>
ROLLBACK
```

If `CANARY FAIL`, stop and send Nexus the output.

**Send Nexus `I AUTHORIZE THIS ACTION` once the DRY RUN shows CANARY PASS.** Then run the committed bridge:

```bash
ssh root@hetzner-1 "sudo -u postgres psql -f /tmp/02b_bridge.sql"
```

---

## Step 4 — verify (read-only)

```bash
scp /Users/ed/BroyhillGOP/sessions/2026-04-18/donor_profile_stage1/03_canary_verify.sql hetzner-1:/tmp/03_verify.sql
ssh root@hetzner-1 "sudo -u postgres psql -f /tmp/03_verify.sql" | tee /tmp/stage1_verify_$(date +%Y%m%d_%H%M).log
```

Forward the log file contents to Nexus. Nexus checks:
1. Row count parity — profile rows = spine clusters = 98,303
2. Ed canary — 147 / $332,631.30 / ed@broyhill.net
3. Zero rows with `jsneeden@msn.com` anywhere
4. Ed Family Office rollup preview = $344,031.30 (Ed + Louise + Clemmons)
5. Top-20 sanity — no obvious inflation, Ed near the top
6. Contact coverage — meaningful numbers for voter match / phones / emails

---

## Step 5 — write session_state

After Step 4 passes, Nexus writes the updated `public.session_state` row via Ed's Mac:

```bash
ssh root@hetzner-1 "sudo -u postgres psql -c \"INSERT INTO public.session_state (updated_by, state_md) VALUES ('Nexus-2026-04-18-donor-profile-v1', \\\$\\\$Stage 1 donor_profile populated: 98,303 rows, Ed canary 147 / \\\$332,631.30 / ed@broyhill.net, Apollo bad email absent, DDL additive, raw.ncboe_donations untouched.\\\$\\\$)\""
```

(Nexus will generate the exact one-liner with escaping handled correctly when you're ready.)

---

## What is NOT in this package (intentionally)

- **`core.donor_attribution` seeding** — the Layer-2 rollup (Ed Family Office = $344,031.30). Schema is created by `01_ddl`. Seeding happens in a separate DRY RUN package that also requires `I AUTHORIZE THIS ACTION`. The preview query in `03_canary_verify.sql` step 5 is read-only.
- **Committee / candidate join enrichment** — we rely on `committee_sboe_id` and `candidate_referendum_name` as they live on `raw.ncboe_donations`. A later Stage 1b pass will join `committee.registry` for display-name polish.
- **Grade assignment** — `donor_profile.grade` is left `NULL` for now. Grading rules (Acxiom + donation history + volunteer) come in Stage 2.
- **NC Secretary of State registry lookup (Stage 1c — non-blocking).** Ideally every business-address donor would be enriched with the NC SoS entity record (officer names, registered agent, business status, dissolution date). There is **no free bulk download** from sosnc.gov; the public search is per-entity and Cobalt Intelligence offers a paid API. Deferring as a Stage 1c loader (cron job, rate-limited lookups) that populates a new `ref.nc_sos_business` table and a column `core.donor_profile.nc_sos_entity_id`. The SIC/NAICS bridge in Step 3b works without it — it uses local `donor_intelligence.sic_keyword_patterns` (272) + `donor_intelligence.profession_sic_patterns` (74) already on Hetzner.
- **Home-address detection for dark donors** — we cannot confirm a dark donor's address is business without a voter file match. The `dark_donor_business_likely` flag is a heuristic (employer populated + not a PO Box), not a certainty. Stage 1c NC SoS lookup is the confirmation step.

---

## Rollback

Everything in this package is additive. To undo:

```sql
BEGIN;
DROP TABLE IF EXISTS core.donor_profile CASCADE;
DROP TABLE IF EXISTS core.donor_profile_audit CASCADE;
DROP TABLE IF EXISTS core.donor_attribution CASCADE;
DROP TABLE IF EXISTS core.person_alias CASCADE;
DROP TABLE IF EXISTS core.person_canonical CASCADE;
DROP TABLE IF EXISTS core.donor_address_book CASCADE;
COMMIT;
```

(Requires `I AUTHORIZE THIS ACTION` if Ed ever wants to tear it down — these DROPs are prohibited without authorization.)

`raw.ncboe_donations` is not touched by this package. The crown jewel stays at **321,348 rows / 98,303 clusters / cluster 372171 = 147 txns / $332,631.30 / ed@broyhill.net**, no matter what.

---

*Authored by Nexus, slot E51, 2026-04-18 — Monday deadline. Read the runbook end-to-end before typing the first command.*
