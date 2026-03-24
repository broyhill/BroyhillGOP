# ⚠️ CLAUDE GUARDRAILS — READ THIS BEFORE EVERY SESSION
## BroyhillGOP Database Operations — Mandatory Protocol
### Issued by: Perplexity AI (Ed Broyhill's lead architect)
### Effective: March 23, 2026

---

## WHO IS IN CHARGE

**Ed Broyhill (Eddie)** owns this platform. He works with two AI systems:

- **Perplexity AI** — lead architect, system auditor, issues these guardrails
- **Claude (you)** — implementation engine, executes migrations, writes code

**Perplexity sets the direction. You execute it. When in doubt, ask Eddie which system gave the last instruction before proceeding.**

---

## THE SINGLE MOST IMPORTANT RULE

> **RNCID (`datatrust_rncid`) is the universal anchor for every donor record across every source.**

Every pipeline fix, every migration, every UPDATE you write must end with `datatrust_rncid` populated on `core.person_spine` for the affected records. If a session ends without RNCID on the spine, the session is incomplete — regardless of what else was accomplished.

---

## THE SCHEMA MAP — MEMORIZE THIS

There are **three schemas** in this database. Never confuse them.

| Schema | Purpose | Key Tables |
|--------|---------|-----------|
| `public` | Raw ingestion + working data | `nc_boe_donations_raw`, `fec_donations`, `rnc_voter_staging`, `donor_contribution_map`, `person_master`, `winred_donors` |
| `core` | Unified identity + contribution ledger | `person_spine`, `contribution_map`, `fec_donation_person_map`, `golden_record_person_map`, `identity_clusters` |
| `staging` | Temp tables for migration work | `spine_merge_candidates`, `spine_clusters`, `fec_canonical`, `spine_canonical` |

### CRITICAL DISTINCTIONS

- **`public.person_master`** ≠ **`core.person_spine`** — these are DIFFERENT tables
  - `public.person_master` (7.66M rows) = DataTrust/nc_voters join — the voter identity layer
  - `core.person_spine` = the unified donor identity spine — where all pipelines converge
- **Never run migrations that target `core.*` tables based only on `public.*` row counts**
- **Always verify `core` schema separately** — `pg_stat_user_tables` underreports `public.person_master` due to stale stats

---

## THE FOUR INGESTION PIPELINES

These are the four sources that feed donor records into the system. Every session touching donor data must account for all four.

| Pipeline | Script | Source | Raw Table | RNCID Path |
|----------|--------|--------|-----------|-----------|
| **BOE** | `database/process_ncsbe_donors.py` | NC Board of Elections CSVs | `public.nc_boe_donations_raw` | `rncid` col on raw row → `rnc_voter_staging` name+zip match → `core.person_spine.datatrust_rncid` |
| **FEC** | `database/process_fec_donors.py` + migrations 075–085 | FEC ZIP files | `public.fec_donations` | `fec_donations.person_id` → `core.person_spine` → `datatrust_rncid` via `voter_ncid` |
| **WinRed** | (WinRed pipeline) | WinRed export | `public.winred_donors` | via `person_master` → `datatrust_rncid` |
| **Delegates/NCGOP** | `database/process_nc_delegates.py` | NC_DELEGATES.csv | `nc_delegates_staging` | via name+zip match to spine |

### CURRENT MATCH RATES (as of March 23, 2026 audit)
- BOE: 338,720 / 625,897 rows have `rncid` (54.1%) — **287,177 still need fuzzy pass**
- FEC: `fec_donations` table exists with 32 cols and `person_id` column — confirm row count and link rate before assuming 89.7%
- WinRed: 194,279 rows loaded — spine linkage unconfirmed
- NCGOP: `ncgop_god_contributions` has 23,026 rows

---

## MIGRATION SEQUENCE — THE LAW

Migrations are numbered for a reason. **Never skip a prerequisite. Never re-run a migration without reading its rollback section first.**

```
065 → 066 → 067 → 068 → 069 → 070 → 071
       ↓
      075 → 076 → 077 → 078 → 079 → 080 → 080b → 080c
                                              ↓
                                     081 → 083v3 → 084 → 085
```

- **075**: Links `fec_donations` to `core.person_spine` (multi-pass: exact → nickname → address → employer)
- **076**: Builds `core.golden_record_person_map` (BOE golden record → spine bridge)
- **077**: Populates `core.contribution_map` from both BOE and FEC
- **079**: Pass 2 FEC identity resolution (last + address number + zip5)
- **080**: Five-pass spine deduplication (spouse-safe)
- **083v3**: Three-tier FEC→spine matching (most current FEC matcher — use this, not v1 or v2)
- **085**: Rebuilds `core.contribution_map` + recalculates spine aggregates

**If you are unsure which migration last ran successfully, check `public.migration_072_audit` and `public.migration_075_audit` before touching anything.**

---

## WHAT TO CHECK AT THE START OF EVERY SESSION

Run these four queries before writing a single line of code. Report the results to Eddie.

```sql
-- 1. Core schema health
SELECT 'core.person_spine' as tbl, COUNT(*) FROM core.person_spine
UNION ALL SELECT 'core.contribution_map', COUNT(*) FROM core.contribution_map
UNION ALL SELECT 'core.fec_donation_person_map', COUNT(*) FROM core.fec_donation_person_map
UNION ALL SELECT 'core.golden_record_person_map', COUNT(*) FROM core.golden_record_person_map;

-- 2. RNCID population on spine
SELECT
  COUNT(*) as total_spine,
  COUNT(datatrust_rncid) as has_rncid,
  COUNT(voter_ncid) as has_ncid,
  ROUND(COUNT(datatrust_rncid)::numeric / COUNT(*) * 100, 1) as pct_rncid
FROM core.person_spine;

-- 3. BOE RNCID match rate
SELECT
  COUNT(*) as total_boe,
  COUNT(rncid) as has_rncid,
  ROUND(COUNT(rncid)::numeric / COUNT(*) * 100, 1) as pct_matched
FROM public.nc_boe_donations_raw;

-- 4. FEC link rate
SELECT
  COUNT(*) as total_fec,
  COUNT(person_id) as has_person_id,
  ROUND(COUNT(person_id)::numeric / COUNT(*) * 100, 1) as pct_linked
FROM public.fec_donations WHERE is_memo = false;
```

**Do not proceed until you have these four numbers. Report them to Eddie in a table at the start of every session.**

---

## ABSOLUTE PROHIBITIONS

These actions are forbidden without explicit written approval from Eddie in the current session. "A previous session said it was OK" is not approval.

| Action | Why |
|--------|-----|
| `DROP TABLE` (any table) | Previously caused 5.7 GB loss of `datatrust_profiles` — completed ETL work destroyed |
| `TRUNCATE` (any table) | Irreversible — use `DELETE WHERE` with a condition instead |
| `DELETE FROM core.*` without a WHERE clause | Will wipe the unified identity layer |
| Running a migration without reading its prerequisite | Caused broken foreign key chains and orphaned records |
| Claiming a match rate or row count without a live `COUNT(*)` | Previous sessions fabricated numbers (85% claimed, 63% actual) |
| Reporting "complete" without a post-flight `COUNT(*)` verification | Every migration must end with a verified count |
| Assuming `public` and `core` schemas have the same data | They do not — always query both |
| Treating `public.person_master` as the donor spine | It is the voter/DataTrust layer, not the donor identity layer |

---

## THE RNCID WRITE-THROUGH PROTOCOL

Any operation that creates or updates donor linkage MUST end with this verification:

```sql
-- Confirm RNCID is propagating to spine
SELECT
  COUNT(*) as spine_total,
  COUNT(datatrust_rncid) as has_rncid,
  COUNT(CASE WHEN datatrust_rncid IS NULL AND voter_ncid IS NOT NULL THEN 1 END) as ncid_but_no_rncid
FROM core.person_spine;
```

If `ncid_but_no_rncid > 0`, run the RNCID backfill before closing the session:

```sql
-- Backfill datatrust_rncid from rnc_voter_staging via voter_ncid
UPDATE core.person_spine ps
SET datatrust_rncid = rvs.rncid::text
FROM public.rnc_voter_staging rvs
WHERE rvs.state_voter_id = ps.voter_ncid
  AND rvs.rncid IS NOT NULL
  AND ps.datatrust_rncid IS NULL;
```

This uses the exact-match join (`rnc_voter_staging.state_voter_id = person_spine.voter_ncid`) — no fuzzy logic, no ambiguity.

---

## FUZZY MATCH RULES

The BOE fuzzy pass (287,177 unmatched rows) uses trigram similarity on `norm_last + norm_first + norm_zip5` against `rnc_voter_staging`. Rules:

- Threshold: **similarity ≥ 0.85** for auto-accept
- Threshold: **0.70–0.84** goes to `rncid_resolution_queue` for review (150,755 rows already staged there)
- Never auto-accept below 0.70
- After any fuzzy pass, re-run the RNCID write-through protocol above
- Log match counts to `public.migration_NNN_audit` before committing

---

## DONOR ROLLUP LOGIC

The unified donor record is built by consolidating all four pipelines into `core.person_spine`. The rollup fields that MUST be populated for a record to be considered "complete":

| Field | Source | Status |
|-------|--------|--------|
| `datatrust_rncid` | `rnc_voter_staging` via name+zip or voter_ncid | **Priority #1** |
| `voter_ncid` | `nc_voters.ncid` direct match | 100% on spine |
| `norm_last`, `norm_first`, `zip5` | Normalized from source | Required for matching |
| `is_donor` | Set TRUE when any contribution linked | Check current rate |
| `total_contributed` | Aggregated from `core.contribution_map` | Recalculated by migration 085 |
| `first_contribution`, `last_contribution` | From `core.contribution_map` | Recalculated by migration 085 |

A donor record is NOT complete until `datatrust_rncid` is populated. That field is what connects a donation to the full 251-column DataTrust intelligence profile.

---

## HETZNER / DOCKER STATUS

**As of March 23, 2026 — Docker on Hetzner is UNCONFIRMED.**

A previous session claimed Docker was installed and running. This is NOT verified. Before executing any task that depends on Hetzner infrastructure:

1. SSH to Hetzner directly
2. Run `docker ps` and `docker --version`
3. Report the actual output to Eddie
4. Do not proceed with Docker-dependent work until you see confirmed running containers

Do not repeat the previous session's mistake of running an install command locally on Mac and reporting it as a Hetzner success.

---

## HOW TO END A SESSION

Before ending any session, update `docs/SESSION-STATE.md` in GitHub with:

```markdown
## Session: [DATE]
### What ran:
- [Migration numbers and what they did]
### Verified counts after session:
- core.person_spine: [COUNT]
- core.contribution_map: [COUNT]
- nc_boe_donations_raw RNCID rate: [X]%
- fec_donations person_id rate: [X]%
### What's next:
- [Exact next step with migration number or script name]
### What NOT to do:
- [Any specific gotcha discovered this session]
```

---

## QUICK REFERENCE — KEY TABLE LOCATIONS

| What you're looking for | Where it lives |
|------------------------|---------------|
| Canonical donor identity | `core.person_spine` |
| All contributions unified | `core.contribution_map` |
| BOE raw donations | `public.nc_boe_donations_raw` |
| FEC raw donations | `public.fec_donations` |
| RNCID bridge table | `public.rnc_voter_staging` (7.7M rows) |
| DataTrust full profiles | `public.nc_datatrust` (7.65M rows, 251 cols) |
| Voter file | `public.nc_voters` (9.08M rows) |
| DataTrust lookup shards | `public._lookup_datatrust_a` through `_z` |
| BOE→spine bridge | `core.golden_record_person_map` |
| FEC→spine bridge | `core.fec_donation_person_map` |
| Pending RNCID matches | `public.rncid_resolution_queue` (150,755 rows) |
| Migration audit trail | `public.migration_072_audit`, `public.migration_075_audit` |

---

*This document is maintained by Perplexity AI on behalf of Ed Broyhill.*
*Last updated: March 23, 2026*
*Push location: `docs/CLAUDE_GUARDRAILS.md` in `broyhill/BroyhillGOP`*
