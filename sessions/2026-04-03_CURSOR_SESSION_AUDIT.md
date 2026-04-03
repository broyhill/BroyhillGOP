# CURSOR SESSION AUDIT — April 2-3, 2026
## Written by Cursor — authoritative record of tonight's work

---

## 1. DataTrust NC Full File → Postgres Staging

- File: `/opt/broyhillgop/data/voter_file/NC_VoterFile_FULL_20260312.csv`
- Format: pipe-delimited (`|`), 251 columns, HEADER true
- Load method: `psql` from Hetzner 5.9.99.109, PGPASSWORD + PGSSLMODE=require
- Fix required: `SET statement_timeout = 0` BEFORE `\copy` in same session
- Result: **COPY 7,708,542** — verified COUNT(*) = 7,708,542
- Table: `staging.nc_voters_fresh`
- `public.nc_voters` NOT touched

## 2. Indexes Built on staging.nc_voters_fresh

- `idx_nvf_rncid` on `(rncid)` — ~1m 45s
- `idx_nvf_statevoterid` on `(statevoterid)` — ~1m 33s
- `idx_nvf_name_zip` on `(lastname, firstname, regzip5)` — ~1m 27s

## 3. RNCID Match — Why Direct Join Was Zero

- `contacts.voter_id = nv.rncid` → 0 matches
- Root cause: contacts hold OLD RNCIDs; new March 2026 file has NEW RNCIDs
- `prev_rncid` only covered 2 contacts
- **Bridge that worked:**
  `contacts` → `nc_datatrust` on `dt.rncid = c.voter_id`
  → `nc_voters_fresh` on `nv.statevoterid = dt.statevoterid`
  → **132,036 distinct contacts matchable**

## 4. Enrichment Staging Table

- Built: `staging.staging_claude_contact_enrichment` (132,036 rows)
- Contains: new March 2026 rncid, phones, scores, coalitions, districts, vote history
- Rerunnable: DROP TABLE IF EXISTS before CREATE TABLE AS

## 5. Production UPDATE on public.contacts (Authorized)

**Schema mismatch discovered:** Perplexity's intended columns (cell_phone, republican_score, coalition_*) did not exist on live contacts table.

**Actual mapping used:**
| Intended | Actual column used |
|----------|-------------------|
| cell_phone | phone_mobile |
| landline | phone |
| All scores + coalitions + vote history | custom_fields.datatrust_2026 (JSON) |
| household_id (bigint) | household_id_datatrust in JSON only |
| birth_year | date_of_birth (Jan 1 placeholder) |
| sex | gender |

- Result: UPDATE 132,036
- voter_id updated to new March 2026 RNCID on all 132,036
- public.nc_voters NOT modified

## 6. Post-Enrichment Contact Metrics

| Metric | Value |
|--------|------:|
| Total contacts | 226,541 |
| Has cell (phone_mobile) | 122,394 (54%) |
| Has rep score (JSON) | 127,817 (56%) |
| Has congressional district | 132,613 (59%) |
| Has coalition data (JSON) | 132,036 (58%) |

## 7. Spine / Dedup

- 4 genuine duplicates merged via MERGE_EXECUTOR_V1.sql
- core.person_spine active: 128,043

## 8. Documentation

- ROOT SESSION-STATE.md updated and pushed (commit 89e184b)
- CONTACTS_COLUMN_MIGRATION.sql committed — design only, not executed

## 9. What Was NOT Done

- No ALTER TABLE for score/coalition columns (deferred to Claude migration)
- No WinRed phone/email backfill for ~94K gap
- No new FEC file download (existing 2,591,933 rows unchanged)
- No changes to sacred tables

---

## Known Issues to Fix Tomorrow

1. SESSION-STATE top table shows nc_boe_donations_raw as 282,096 (wrong)
   Live count is 338,223 — reconcile with COUNT(*) and patch SESSION-STATE

2. Spine linked % may be off — recount after 128,043 active confirmed

---

## Tomorrow's Recommended Plan (Cursor's View)

### Phase A — Morning hygiene (30-45 min)
- Live COUNT(*) on all key tables
- Patch SESSION-STATE.md top table to match live numbers
- Confirm guardrails

### Phase B — Claude column migration (MSG #224)
- Review sessions/CONTACTS_COLUMN_MIGRATION.sql
- Dry run: row counts, null rates, type casts, idempotency check
- Execute with statement_timeout = 0, batched if needed
- Decision: keep custom_fields.datatrust_2026 as audit copy or trim after backfill

### Phase C — WinRed backfill (~94K contacts)
- Match keys: email, name+zip, WinRed donor id
- Staging table → counts → Ed/Perplexity authorize → UPDATE
- Re-run coverage metrics to measure improvement

### Phase D — FEC donor files install (core task)
This is a small project requiring explicit artifacts:

1. Source of truth: confirm which pipeline — raw.fec_donations first then ETL,
   or direct to public.fec_donations (repo has both patterns)
   Key files: pipeline/fec_raw_import.py, database/process_fec_donors.py,
   scripts/import_all_donations.py

2. Pre-flight:
   - List files + row counts + date range
   - --dry-run on chosen importer if supported
   - Confirm disk/network path (Hetzner relay has worked well)

3. Load:
   - Run import with dedupe key = sub_id (safe reruns)
   - Log inserted / skipped / errors per file

4. Post-load validation:
   - COUNT(*), min/max contribution_receipt_date, NC filter, null zip/name rates
   - Spot-check 10 random rows against fec.gov

5. Downstream refresh:
   - Rebuild/extend core.contribution_map for new fec_donations rows
   - Re-stamp party_flag / committee maps
   - Recompute spine aggregates (dollars, donor flags)

6. Update SESSION-STATE: fec_donations row count, filing window, contribution_map delta

### Phase E — Optional same-day
- Name+zip pass for ~9,799 contacts still missing voter_id (staging only first)
- Improves FEC ↔ contact alignment

---

## FEC Pipeline Decision Needed

**Ed/Perplexity must decide:** Does FEC land in `raw.fec_donations` first then ETL
to `public.fec_donations`, OR direct to `public.fec_donations`?

Once decided, next step is a single numbered runbook (commands + SQL order).

---

## Key Technical Notes for Future Sessions

- ALWAYS `SET statement_timeout = 0` before heavy queries on 7M+ row tables
- ALWAYS use PGPASSWORD env var — never embed password with @ in connection URL
- The DataTrust bridge is: contacts.voter_id → nc_datatrust.rncid → nc_datatrust.statevoterid → nc_voters_fresh.statevoterid → new rncid
- custom_fields.datatrust_2026 is current system of record for scores/coalitions until migration runs
- staging.nc_voters_fresh uses pipe delimiter (|) not comma
- nc_voters_fresh idx_nvf_name_zip expects RAW values (data is already uppercase) — no UPPER(TRIM()) needed, hits index directly
