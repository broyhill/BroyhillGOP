# BroyhillGOP SESSION STATE
## Updated: 2026-04-03 (overnight) EDT — Claude name+zip match + column migration design

---

## CRITICAL: READ THIS BEFORE DOING ANYTHING

The old SESSION-STATE.md (dated 2026-03-24) is obsolete. Ignore all numbers and task lists from that version. This is the authoritative current state.

---

## DATABASE: TRUE CURRENT STATE (2026-04-03)

### Core Tables — Verified Row Counts (COUNT(*), not pg_stat estimates)

| Table | Rows | Status |
|-------|------|--------|
| public.contacts | 226,541 | ✅ Primary masterfile — nc_donor_summary purged |
| public.nc_datatrust | 7,661,978 | ✅ SACRED — do not touch |
| public.fec_donations | 2,591,933 | ✅ NC individual donors, all cycles 2015-2026 |
| public.nc_boe_donations_raw | 338,223 | ✅ Reload complete (Mar 31, 2026) — Individual only; prior wrong-file batch **282,096** rows in `staging.ncboe_archive_wrong_files` |
| public.winred_donors | ~194,278 | ✅ Clean |
| public.nc_donor_summary | 195,317 | 🗑️ PURGED from contacts — Letha Davis file, not canonical data |
| public.person_source_links | 2,055,703 | ✅ |
| core.person_spine | 128,043 active | ✅ Merge executor ran 2026-04-03 — 4 genuine duplicates merged; $426,949,676 total (unchanged ballpark) |
| core.contribution_map | 4,137,549 | ✅ party_flag stamped, 733K rows attributed to candidates |
| core.candidate_committee_map | 3,733 rows | ✅ 99.97% FEC committee coverage (fix_09) |
| candidate_profiles | 3,630 | ✅ All Republican, faction scores |
| staging.nc_voters_fresh | 7,708,542 | ✅ March 2026 DataTrust NC full file loaded via Hetzner relay; indexes: `idx_nvf_rncid`, `idx_nvf_statevoterid`, `idx_nvf_name_zip` |

### SACRED TABLES — DO NOT TOUCH UNDER ANY CIRCUMSTANCES
- `nc_voters`
- `nc_datatrust`
- `rnc_voter_staging`
- `person_source_links` (pre-existing rows)

---

## nc_donor_summary PURGE — COMPLETE (March 31, 4:14 PM EDT)

- **84,326 contacts deleted** from `public.contacts` WHERE source = 'nc_donor_summary'
- **6,497 orphan rows** also removed from `core.contact_spine_bridge`
- **Archive:** `staging.ncboe_archive_nc_donor_summary` (84,326 rows — restore path if ever needed)
- **New contacts total: 226,541**

| source | count |
|--------|------:|
| nc_datatrust | 132,613 |
| fec_donations | 39,024 |
| winred_donors | 38,060 |
| nc_boe_donations_raw | 16,844 |

**Rationale:** nc_donor_summary was an external summary rollup (Letha Davis, Oct 2024) — not canonical BroyhillGOP data. No streets, not our production, not part of the spine.

---

## NCBOE RELOAD — COMPLETE ✅ (March 31, 9:08 PM EDT)

**Status:** DONE. 338,223 rows. 100% Individual. Validated by Cursor.

| File | Rows | Loaded at (UTC) |
|------|------|-----------------|
| 2015-2019-ncboe.csv | 95,967 | 2026-03-31 21:44 |
| 2020-2026-ncboe.csv | 242,256 | 2026-04-01 00:44 |

**Validation results:**
- transaction_type: Individual = 338,223 (only value) ✅
- date range: 2015-01-01 → 2026-02-17 ✅
- norm_last/norm_first/norm_zip5: populated by trigger ✅
- null/blank norm_zip5: 5,851 rows (1.7%) — known SBOE source gap, not reload issue
- null/zero amount_numeric: 10 rows — minor, spot-check source data
- Wrong-file archive: staging.ncboe_archive_wrong_files (282,096 rows preserved)

**core.contribution_map NC_BOE rebuild — COMPLETE ✅ (March 31, 9:18 PM EDT)**
- Deleted 351,129 stale NC_BOE rows
- Re-inserted 108,943 rows via name+zip match to person_spine
- Spine aggregates recomputed from all sources
- is_donor flag refreshed

**Final spine metrics (active rows only):**
| Metric | Value |
|--------|-------|
| Active spine rows | 128,043 |
| Voter linked | 127,670 (99.7%) — spot-verify after merge |
| Has RNCID | 128,043 (100%) |
| Has contribution > 0 | 127,945 (99.9%) |
| Total dollars | $426,949,676 |

**contribution_map breakdown:**
| Source | Rows | Dollars |
|--------|------|---------|
| fec_donations | 2,330,166 | $298,509,526 |
| fec_party | 1,387,942 | $198,006,706 |
| NC_BOE | 108,943 | $64,105,742 |
| winred | 57,793 | $10,731,459 |
| ncgop_god | 10,519 | $1,172,879 |

**Note:** 338,223 raw NC_BOE rows → 108,943 mapped to spine (32% match rate).
Remaining ~229K rows have no active spine match (blank norm_zip5, name mismatch, or donor not yet in spine).
This is expected — RNCID backfill will improve match rate in next session.
---

## CONTACTS TABLE — ADDRESS COVERAGE (True Current State)

| Source | Total | Has Address | Missing |
|--------|-------|-------------|---------|
| nc_datatrust | 132,613 | 132,612 | 1 ✅ |
| winred_donors | 38,060 | 38,057 | 3 ✅ |
| fec_donations | 39,024 | 38,285 | 739 ✅ (blank at FEC source) |
| nc_boe_donations_raw | 16,844 | 16,697 | 147 ✅ (blank at BOE source) |

**nc_donor_summary contacts were purged (March 31)** — no longer in `public.contacts`.

---

## DATATRUST MARCH 2026 — STAGING + CONTACT ENRICHMENT (2026-04-03) ✅

- **7,708,542** DataTrust voter rows downloaded and `\copy` loaded into **`staging.nc_voters_fresh`** (pipe-delimited `NC_VoterFile_FULL_20260312.csv` on Hetzner relay).
- **Three indexes** on staging: `rncid`, `statevoterid`, `(lastname, firstname, regzip5)`.
- **Bridge:** `contacts.voter_id` (legacy RNCID) → `public.nc_datatrust.rncid` → `staging.nc_voters_fresh.statevoterid` → new March 2026 `rncid`.
- **Staging table:** `staging.staging_claude_contact_enrichment` (132,036 rows) — Perplexity reviewed; **`UPDATE public.contacts` executed** from enrichment.
- **Storage model (temporary):** Scores, coalition flags, vote history, phone metadata, and sources live under **`custom_fields.datatrust_2026`**; **mapped columns** updated where they exist (`voter_id`, `phone_mobile`, `phone`, districts, `precinct`, `gender`, `date_of_birth` from year, `estimated_income_range`). Full top-level column parity awaits **Claude’s migration script** (see below).

### Contacts — metrics after enrichment (table-wide)

| Metric | Value |
|--------|------:|
| Total contacts | 226,541 |
| Has phone (any) | 142,012 (63%) |
| Has cell phone (`phone_mobile` non-empty) | 123,120 (54%) |
| Has email | 32,777 (14%) |
| Has Republican score (`custom_fields.datatrust_2026.republican_score`) | 127,817 (56%) |
| Has turnout score | 127,817 (56%) |
| Has congressional district (non-empty) | 132,613 (59%) |
| Has coalition data (`datatrust_2026.coalition_veteran` present) | 132,036 (58%) |
| Missing voter_id (unmatched contacts) | 93,928 (41%) |

**Rows enriched this session:** 132,036 (all matched via `nc_datatrust` bridge). **`public.nc_voters` was not modified.**

### Merge + dedup (same night)

- **Merge executor** ran — **4** genuine duplicates merged; spine **128,043** active.
- **Dedup V3** bundle with false-positive guards **committed to GitHub** (e.g. `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql`, deploy runbooks under `sessions/`).

---

## CLAUDE — COLUMN MIGRATION ASSIGNMENT (relay **MSG #224**)

**Goal:** Promote DataTrust enrichment from JSON to first-class `public.contacts` columns (design + migration SQL).

1. **Design** `ALTER TABLE public.contacts ADD COLUMN …` (or equivalent) for: modeled scores, coalition flags, cell/landline source columns, religion, education, etc., aligned with how **`custom_fields.datatrust_2026`** is structured today.
2. **`UPDATE`** backfill from `custom_fields->'datatrust_2026'` into new columns (idempotent, batched if needed; `statement_timeout = 0` on Supabase).
3. **Document** nullable defaults, type choices (`numeric` vs `text` for scores), and whether JSON remains a mirror or is trimmed after backfill.
4. **Handoff:** Ed/Perplexity review migration **before** production `ALTER` + mass `UPDATE`.

**Next session (authorized after review):** run Claude’s migration; then **WinRed phone/email backfill** for the remaining ~**94K** contacts without mobile coverage.

---

## CONTACTS TABLE — VOTER_ID (RNCID) COVERAGE

| Source | Total | Has voter_id (RNCID) | Missing |
|--------|-------|----------------------|---------|
| nc_datatrust | 132,613 | 132,613 | 0 ✅ |
| nc_donor_summary | 84,326 | 0 | 84,326 |
| fec_donations | 39,024 | 0 | 39,024 |
| winred_donors | 38,060 | 0 | 38,060 |
| nc_boe_donations_raw | 16,844 | 0 | 16,844 |

**Note:** `contacts.voter_id` stores RNCID (e.g. 24234683774), NOT NC SBOE statevoterid (e.g. AN130350).
`nc_datatrust.statevoterid` contains the NC SBOE voter registration number for every record.

**2026-04-03:** 132,036 nc_datatrust-sourced contacts now have **`voter_id` = March 2026 file `rncid`** (via bridge above).

---

## FIXES COMPLETED (fix_01 through fix_11)

| Fix | Description | Status |
|-----|-------------|--------|
| fix_01 | FEC committees party column | ✅ |
| fix_02 | Donor-voter links orphans | ✅ |
| fix_03 | RNC volunteer score backfill | ✅ |
| fix_04 | FEC corrupt dates | ✅ |
| fix_05 | nc_donor_summary dates | ✅ |
| fix_06 | WinRed large amounts | ✅ |
| fix_07 | FEC party committee date cast + table rename | ✅ |
| fix_08 | Contacts masterfile build (310,867 rows) | ✅ |
| fix_09 | Committee-candidate linkage (3,733 rows, 99.97%) | ✅ |
| fix_10 | Republican-only spine totals ($495M) | ✅ |
| fix_11 | FEC address backfill (38,285 contacts fixed) | ✅ |

---

## ACTIVE WORK ITEMS

### NCBOE Reload + contribution_map rebuild — ✅ COMPLETE (March 31, 9:18 PM EDT)
- 338,223 rows loaded, 100% Individual
- 108,943 NC_BOE rows mapped to spine, $64M
- Spine aggregates recomputed: $426.9M total

### DataTrust staging + contact enrichment — ✅ COMPLETE (April 3, 2026)
- See section **DATATRUST MARCH 2026 — STAGING + CONTACT ENRICHMENT** above.

### Name+Zip Voter Match (93K unmatched contacts) — ⏳ Staged, awaiting Perplexity approval (April 3 overnight)
- **Dry run complete:** 9,799 distinct contacts matched via `last_name + first_name + LEFT(zip_code,5)` to `staging.nc_voters_fresh` (lastname, firstname, regzip5)
- **11,203 total join rows** before DISTINCT ON (some contacts match multiple voters)
- **Breakdown:** WinRed=8,773 | NC_BOE=983 | FEC=43
- **Staging table:** `staging.staging_claude_namez_match` (9,799 rows) — includes nv_rncid, nv_ncid, nv_party, nv_sex, districts, phone data, scores, income
- **Relay message #226** sent to Perplexity with counts — **NO UPDATE executed yet**
- **Remaining unmatched after this pass:** ~84,129 contacts (93,928 - 9,799)

### Contacts column migration — ✅ DESIGNED, awaiting review (April 3 overnight)
- Migration SQL committed to GitHub: `sessions/CONTACTS_COLUMN_MIGRATION.sql`
- **14 new columns** to add: ethnicity, religion, education_level, household_party, household_id_datatrust, cell_source, landline_source, dt_cell_dnc, dt_cell_source, dt_cell_reliability, dt_landline_dnc, dt_landline_source, dt_landline_reliability, dt_enriched_at
- **Existing columns** updated via COALESCE (scores, vote history, coalition flags, dt_rncid)
- **132,036 contacts** affected (all with datatrust_2026 JSON)
- **DESIGN ONLY — not executed.** Awaiting Ed/Perplexity review.

### WinRed phone/email backfill — ⏳ NEXT after migration review
- Target ~**94K** contacts still without mobile after DataTrust pass.

### Phase 1-7 Architecture Build (QUEUED for Claude)
- 20+ new tables designed in March 31 master architecture session
- Full spec in: sessions/2026-03-31_MASTER_ARCHITECTURE_SESSION.md
- Has NOT been executed yet — design only
- Start with Phase 1: person_district_map, volunteer_profiles, community_profiles

### Deep Audit v2 (QUEUED for Claude + Cursor)
- `pipeline/deep_audit_v2.py` pushed to GitHub main at 1:01 PM EDT
- Claude: relay message #207 queued
- Cursor: run `git pull && python3 -m pipeline.deep_audit_v2`
- Reports: party contamination, 21-point column quality, pipeline status, reload readiness

---

## KEY FACTS / GUARDRAILS

### Authorization Protocol
- Any UPDATE/DELETE on core tables requires exact phrase: **"I authorize this action"**
- TWO PHASE protocol always: DRY RUN showing counts → EXECUTION after authorization
- Fix_07: TWO MANUAL PASSES ONLY rule still applies

### Data Rules
- **FEC bulk downloads — DO NOT USE:** Do not select, download, or ingest **FEC bulk Schedule A / “bulk export”** files for BroyhillGOP. **Not approved:** contributor physical-address requirements for this program are **not** satisfied via that path. Use other approved FEC sources (e.g. curated pipelines with full address validation) only per Ed/Perplexity spec — never `pipeline/fec_raw_import.py` unless Ed sets **`BROYHILL_ALLOW_FEC_BULK_IMPORT=1`** for a documented exception.
- Ed = ED BROYHILL in all systems — never map to Edward
- No out-of-state candidate donations in individual donor files
- nc_donor_summary: PURGED — do not re-import, do not reference, archive only
- Democratic donations: in archive.democratic_candidate_donor_records (906,609 rows) — preserved
- NCBOE raw column header typo: `Transction Type` (not `Transaction Type`) — single 'a'
- nc_donor_summary is PURGED — not canonical, do not re-import, do not reference
- Letha Davis file = external summary rollup, never had streets, not our data

### MAY NOT (Claude guardrails)
- **Ingest FEC bulk download / bulk Schedule A files** (see Data Rules — blocked)
- DROP/ALTER tables in core/public/archive/norm/raw/staging/audit schemas
- UPDATE/DELETE from core.person_spine, core.contribution_map, public.contacts,
  public.person_source_links, public.nc_datatrust, public.nc_boe_donations_raw
- Touch views starting with v_individual_donations or v_transactions_with_candidate
- Touch auth tables or RLS

### MAY (Claude guardrails)
- CREATE TEMP TABLEs
- CREATE in staging schema only (names starting staging_claude_)
- INSERT into staging
- SELECT anywhere

---

## INFRASTRUCTURE

| Resource | Value |
|----------|-------|
| Supabase Project | BroyhillGOP-Claude |
| Project ID | isbgjpnbocdkeslofota |
| Region | us-east-1 |
| Postgres | 17.6 |
| Hetzner server 1 | 5.9.99.109 |
| Hetzner server 2 | 144.76.219.24 (needs DataTrust IP whitelist) |
| GitHub | broyhill/BroyhillGOP |

---

## KEY FINANCIAL FIGURES
- Republican spine total: $495,429,453
- Archived Democratic + Unknown: $220,708,080
- Old contaminated total (before fix_10): $726,630,745

---

## PENDING WITH DATATRUST (Danny Gustafson — dgustafson@gop.com)
- Email sent requesting: fresh voter file SAS token, RNCID in API responses,
  IP whitelist for 144.76.219.24, composite key guidance for identity matching
