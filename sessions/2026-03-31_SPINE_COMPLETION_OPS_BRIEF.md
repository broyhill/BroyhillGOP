# Spine Completion Ops Brief
## BroyhillGOP — March 31, 2026
## Authored by Perplexity after Ed's critique

---

## CRITICAL — READ BEFORE DOING ANYTHING

This brief replaces any prior task list. Every step has a pre-flight check,
an explicit authorization gate, and a defined verification query.
No production UPDATE/DELETE without Ed saying **"I authorize this action."**

---

## PRE-FLIGHT: nc_boe_donations_raw dependency map

Before TRUNCATE, the following must be understood:

### Views built on nc_boe_donations_raw (not materialized — no MV refresh needed)
- `public.donation_search_ncboe` — migration 055 — SELECT only, no cascade risk
- `public.vw_donor_analysis_consolidated` — migration 057 — SELECT only
- `public.vw_donor_datatrust_base` — migration 060 — SELECT only

**Finding: No materialized views. No foreign keys pointing INTO nc_boe_donations_raw.
TRUNCATE will not cascade or fail due to FK constraints.**

### Tables populated FROM nc_boe_donations_raw (must be rebuilt after reload)
1. `public.donor_contribution_map` WHERE source_system = 'NC_BOE' — migration 070 Step 1
2. `core.contribution_map` WHERE source_system = 'nc_boe' — migration 086 Block D logic
3. `core.person_spine` aggregates (total_contributed, contribution_count, first/last dates) — migration 070 Step 2 / 086 Block B
4. `public.person_master.boe_donor_id` + `is_donor` — migration 070 Step 3
5. `public.person_source_links` (spine bridge rows) — migration 070 Step 4
6. `public.nc_boe_donations_raw.rncid` + `voter_ncid` write-back — function `apply_rncid_resolutions_v2()` in migration 087

### Triggers
- No triggers found on nc_boe_donations_raw in migrations 055–087.

### Jobs / pg_cron
- Unknown — Cursor must run: `SELECT * FROM cron.job WHERE command ILIKE '%nc_boe%';`

### Pre-flight SQL (Cursor runs BEFORE truncate)
```sql
-- 1. Confirm no FK constraints point to nc_boe_donations_raw
SELECT conrelid::regclass AS child_table, conname
FROM pg_constraint
WHERE confrelid = 'public.nc_boe_donations_raw'::regclass
  AND contype = 'f';
-- Expected: 0 rows

-- 2. Confirm no triggers
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table = 'nc_boe_donations_raw';
-- Expected: 0 rows

-- 3. Check pg_cron jobs referencing nc_boe
SELECT jobid, schedule, command FROM cron.job
WHERE command ILIKE '%nc_boe%';
-- If any found: pause them before truncate, resume after

-- 4. Snapshot current donor_contribution_map NC_BOE rows
SELECT count(*) AS current_ncboe_in_dcm
FROM public.donor_contribution_map
WHERE source_system = 'NC_BOE';
-- Record this number — after reload it should go UP (more clean rows to map)

-- 5. Snapshot current spine aggregate for NC_BOE
SELECT count(*) AS spine_rows,
       round(sum(total_contributed)) AS spine_total
FROM core.person_spine
WHERE is_active = true;
-- Record baseline — after rebuild this should increase
```

---

## STEP 1 — NCBOE RELOAD
**Agent: Cursor | Requires: "I authorize this action" from Ed**

### 1a. Archive wrong files (no auth needed)
```sql
DROP TABLE IF EXISTS staging.ncboe_archive_wrong_files;
CREATE TABLE staging.ncboe_archive_wrong_files
AS SELECT * FROM public.nc_boe_donations_raw;
-- Verify: SELECT count(*) FROM staging.ncboe_archive_wrong_files;
-- Expected: 282,096
```

### 1b. TRUNCATE — AUTHORIZED ONLY
```sql
-- ⛔ DO NOT RUN without Ed saying "I authorize this action"
TRUNCATE public.nc_boe_donations_raw;
```

### 1c. Load file 1
```
\copy public.nc_boe_donations_raw FROM
  '/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/AAA DONOR CONTACT INFO/2015-2019-ncboe.csv'
  WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');
-- Verify: SELECT count(*) FROM public.nc_boe_donations_raw;
-- Expected: 95,967
```

### 1d. Load file 2
```
\copy public.nc_boe_donations_raw FROM
  '/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/AAA DONOR CONTACT INFO/2020-2026-ncboe.csv'
  WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');
-- Verify: SELECT count(*) FROM public.nc_boe_donations_raw;
-- Expected: 338,223
```

**NOTE:** Raw column header is `Transction Type` (SBOE typo). If the table schema
uses `transaction_type`, the COPY will fail unless the column mapping handles it.
Cursor must check: `SELECT column_name FROM information_schema.columns
WHERE table_name = 'nc_boe_donations_raw' AND column_name ILIKE '%transact%';`
and adjust COPY column list or use a staging table + INSERT if needed.

### 1e. Post-load SQL validation
```sql
-- Row count
SELECT count(*) FROM public.nc_boe_donations_raw;
-- Expected: 338,223

-- 100% Individual
SELECT transaction_type, count(*)
FROM public.nc_boe_donations_raw
GROUP BY 1;
-- Expected: exactly 1 row: Individual = 338,223

-- NULL zip check
SELECT count(*) FROM public.nc_boe_donations_raw
WHERE norm_zip5 IS NULL OR trim(norm_zip5) = '';

-- NULL amount check
SELECT count(*) FROM public.nc_boe_donations_raw
WHERE amount_numeric IS NULL OR amount_numeric <= 0;

-- Organization-like donor names (should be ~0 in Individual file)
SELECT count(*) FROM public.nc_boe_donations_raw
WHERE contributor_name ILIKE '%LLC%'
   OR contributor_name ILIKE '%INC%'
   OR contributor_name ILIKE '%PAC%'
   OR contributor_name ILIKE '%COMMITTEE%'
   OR contributor_name ILIKE '%CORP%';

-- NC zip check (non-NC zips are suspicious in BOE file)
SELECT count(*) FROM public.nc_boe_donations_raw
WHERE LEFT(norm_zip5, 2) NOT IN ('27','28');

-- Date range sanity
SELECT min(date_occurred), max(date_occurred)
FROM public.nc_boe_donations_raw;
-- Expected: ~2015-01-01 → ~2026-12-31

-- Dedup key uniqueness
SELECT count(*) total, count(DISTINCT dedup_key) unique_keys
FROM public.nc_boe_donations_raw
WHERE dedup_key IS NOT NULL;
```

---

## STEP 2 — REBUILD DOWNSTREAM FROM CLEAN NCBOE DATA
**Agent: Cursor | No additional Ed auth required (these are INSERT/UPDATE rebuilds, not DELETE)**

### Exact rebuild path (confirmed from migrations 070, 086, 087):

```
nc_boe_donations_raw (clean 338K)
    ↓  migration 070 Step 1
public.donor_contribution_map  (INSERT NC_BOE rows keyed on source_id=r.id::text)
    ↓  migration 070 Step 2 / migration 086 Block B
core.person_spine  (UPDATE: total_contributed, contribution_count, first/last dates, max/avg gift)
    ↓  migration 086 Block A
core.person_spine.is_donor  (UPDATE: set true where person_id in contribution_map)
    ↓  migration 070 Step 3
public.person_master.boe_donor_id + is_donor  (UPDATE from spine via voter_ncid)
    ↓  migration 070 Step 4
public.person_source_links  (INSERT new spine bridge rows)
    ↓  migration 087 Block 2 (function backfill_spine_rncid_from_boe)
core.person_spine.voter_rncid  (UPDATE from nc_boe_donations_raw.rncid via voter_ncid)
```

**Execute in this order:**
1. Delete stale NC_BOE rows from donor_contribution_map (wrong-file rows keyed on old IDs):
```sql
-- Stage first — show count to Ed before deleting
SELECT count(*) FROM public.donor_contribution_map WHERE source_system = 'NC_BOE';
-- REQUIRES Ed auth to delete: DELETE FROM public.donor_contribution_map WHERE source_system = 'NC_BOE';
```
2. Run migration 070 Step 1 (INSERT NC_BOE → donor_contribution_map)
3. Run migration 070 Step 2 (UPDATE spine aggregates from donor_contribution_map)
4. Run migration 086 Block A (UPDATE spine is_donor flag)
5. Run migration 070 Step 3 (UPDATE person_master bridge)
6. Run migration 087 Block 2 function (`SELECT * FROM backfill_spine_rncid_from_boe();`)

**NOTE: core.contribution_map is a SEPARATE table from donor_contribution_map.**
Migration 086 Block B updates spine from `core.contribution_map` using columns
`amount` and `transaction_date`. Migration 070 Step 2 updates spine from
`donor_contribution_map` using columns `contribution_receipt_amount` and
`contribution_receipt_date`. Cursor must confirm which table is the current
source of truth for NC_BOE rows by running:
```sql
SELECT source_system, count(*) FROM core.contribution_map GROUP BY 1 ORDER BY 2 DESC;
SELECT source_system, count(*) FROM donor_contribution_map GROUP BY 1 ORDER BY 2 DESC;
```
If `core.contribution_map` has NC_BOE rows, those stale rows need the same
delete-and-rebuild treatment. Report counts before touching.

---

## STEP 3 — DEEP AUDIT v2 (AFTER Step 2 completes)
**Agent: Claude (relay msg #207 already queued) + Cursor**

Run AFTER reload is complete — not during — to get a clean post-reload baseline.

```bash
git pull origin main
python3 -m pipeline.deep_audit_v2 2>&1 | tee /tmp/deep_audit_v2_post_reload.log
```

Report back full output via relay.

---

## STEP 4 — fix_12: Address Enrichment for nc_donor_summary contacts
**Agent: Claude (staging only) | Requires Ed auth for the UPDATE**

84,326 contacts with `source = 'nc_donor_summary'` have no address.

### Stage (no auth needed)
```sql
CREATE TABLE IF NOT EXISTS staging.staging_claude_fix12_ncd_match AS
SELECT
  c.id AS contact_id,
  c.first_name, c.last_name, c.zip_code,
  d.registrationaddr1 AS reg_street,
  d.registrationcity  AS reg_city,
  d.registrationstate AS reg_state,
  d.registrationzip   AS reg_zip,
  d.mailingaddr1      AS mail_street,
  d.mailingcity       AS mail_city,
  d.mailingzip        AS mail_zip,
  count(*) OVER (PARTITION BY c.last_name, c.first_name, c.zip_code) AS match_count
FROM public.contacts c
JOIN public.nc_datatrust d
  ON upper(trim(d.lastname))  = upper(trim(c.last_name))
  AND upper(trim(d.firstname)) = upper(trim(c.first_name))
  AND left(trim(d.regzip5), 5) = left(trim(c.zip_code), 5)
WHERE c.source = 'nc_donor_summary'
  AND (c.address_line1 IS NULL OR trim(c.address_line1) = '');

-- Count results
SELECT
  count(*) AS total_staged,
  count(*) FILTER (WHERE match_count = 1) AS clean_single_match,
  count(*) FILTER (WHERE match_count > 1) AS ambiguous_multi_match,
  count(DISTINCT contact_id) AS unique_contacts_matched
FROM staging.staging_claude_fix12_ncd_match;
```

Report counts to Ed → Ed says "I authorize this action" → UPDATE only single-match rows.

---

## STEP 5 — RNCID Backfill (tiered matching, no mass auto-fill)
**Agent: Claude (staging) | Requires Ed auth per tier**

Ed's critique is correct: name+zip alone will collide on common names.
Use tiered matching with confidence scores. Only single-match rows auto-promote.

### Tier 1 — Exact: voter_ncid bridge (highest confidence, 0 false positives)
```sql
-- nc_boe_donations_raw has voter_ncid → nc_datatrust.statevoterid → rncid
-- Already done for nc_datatrust-sourced contacts (132K have RNCID)
-- After clean reload: check if new NCBOE rows have voter_ncid populated
SELECT count(*) FILTER (WHERE voter_ncid IS NOT NULL) AS with_ncid,
       count(*) FILTER (WHERE voter_ncid IS NULL)     AS without_ncid
FROM public.nc_boe_donations_raw;
```

### Tier 2 — Deterministic: last + first + zip + birth_year (if available)
```sql
-- Stage only, single match required
CREATE TABLE staging.staging_rncid_tier2 AS
SELECT
  c.id AS contact_id,
  c.source,
  d.rncid,
  d.statevoterid,
  count(*) OVER (PARTITION BY c.last_name, c.first_name, c.zip_code) AS match_count,
  0.90 AS match_confidence
FROM public.contacts c
JOIN public.nc_datatrust d
  ON upper(trim(d.lastname))  = upper(trim(c.last_name))
  AND upper(trim(d.firstname)) = upper(trim(c.first_name))
  AND left(d.regzip5, 5) = left(c.zip_code, 5)
WHERE c.voter_id IS NULL
  AND c.source IN ('nc_donor_summary','fec_donations','winred_donors','nc_boe_donations_raw');

-- Report breakdown before any write
SELECT source, match_count,
  count(*) AS contacts,
  round(100.0*count(*)/sum(count(*)) OVER (PARTITION BY source), 1) AS pct
FROM staging.staging_rncid_tier2
GROUP BY 1, 2 ORDER BY 1, 2;
```

### Tier 3 — Fuzzy: multi-match review queue (human or AI review)
Multi-match rows (match_count > 1) go to a review table — never auto-filled.
```sql
CREATE TABLE staging.staging_rncid_review_queue AS
SELECT * FROM staging.staging_rncid_tier2 WHERE match_count > 1;
```

### Expected outcomes
- Tier 1 (voter_ncid): near-100% precision, limited to NCBOE rows with ncid populated
- Tier 2 (name+zip single match): ~50-65% of unmapped contacts, ~97% precision
- Tier 3 (review queue): remainder — requires manual review or additional signals
- DO NOT project "178K → 178K filled" — realistic fill rate is 90K–120K clean matches

---

## STEP 6 — SPINE METRIC VERIFICATION
**Agent: Perplexity | No auth needed**

Run AFTER Steps 1–5 complete. These are the canonical 95% target queries.

**Denominator: `is_active = true AND merged_into IS NULL` — excludes merged/archived rows**

```sql
-- METRIC 1: Voter linkage (spine row linked to nc_datatrust/voter file)
SELECT
  count(*) AS active_spine,
  count(voter_ncid) AS voter_linked,
  round(100.0 * count(voter_ncid) / count(*), 1) AS pct_voter_linked
FROM core.person_spine
WHERE is_active = true;
-- Target: ≥80% (95% is aspirational given FEC-only donors who may not be NC registered voters)

-- METRIC 2: RNCID populated
SELECT
  count(*) AS active_spine,
  count(voter_rncid) AS has_rncid,
  round(100.0 * count(voter_rncid) / count(*), 1) AS pct_rncid
FROM core.person_spine
WHERE is_active = true;
-- Target: ≥85% after RNCID backfill

-- METRIC 3: Contribution total > 0
SELECT
  count(*) AS active_spine,
  count(*) FILTER (WHERE total_contributed > 0) AS has_contribution,
  round(100.0 * count(*) FILTER (WHERE total_contributed > 0) / count(*), 1) AS pct_contributed
FROM core.person_spine
WHERE is_active = true;
-- Target: ≥95% (spine members should all have at least 1 donation)

-- METRIC 4: Address available (via contacts join)
SELECT
  count(DISTINCT ps.person_id) AS active_spine,
  count(DISTINCT ps.person_id) FILTER (
    WHERE c.address_line1 IS NOT NULL AND trim(c.address_line1) != ''
  ) AS has_address,
  round(100.0 * count(DISTINCT ps.person_id) FILTER (
    WHERE c.address_line1 IS NOT NULL AND trim(c.address_line1) != ''
  ) / count(DISTINCT ps.person_id), 1) AS pct_address
FROM core.person_spine ps
LEFT JOIN public.contacts c ON c.voter_id = ps.voter_rncid::text OR c.ncid = ps.voter_ncid
WHERE ps.is_active = true;
-- Target: ≥85% after fix_12 address enrichment

-- SUMMARY SCORECARD
SELECT
  count(*) AS active_spine_rows,
  round(100.0*count(voter_ncid)/count(*),1)   AS pct_voter_linked,
  round(100.0*count(voter_rncid)/count(*),1)  AS pct_rncid,
  round(100.0*count(*) FILTER (WHERE total_contributed>0)/count(*),1) AS pct_contributed,
  round(sum(total_contributed)) AS total_dollars
FROM core.person_spine
WHERE is_active = true;
```

---

## LANE ASSIGNMENTS

| Step | Agent | Auth Gate | Estimated Time |
|------|-------|-----------|----------------|
| Pre-flight SQL checks | Cursor | None | 10 min |
| Step 1a: Archive wrong files | Cursor | None | 5 min |
| Step 1b–d: Truncate + load | Cursor | ✅ "I authorize this action" | 20 min |
| Step 1e: Post-load validation | Cursor | None | 10 min |
| Step 2: Rebuild donor_contribution_map | Cursor | ✅ auth for DELETE stale rows | 30 min |
| Step 2: Rebuild spine aggregates | Cursor | None (UPDATE rebuild) | 15 min |
| Step 3: Deep audit v2 | Claude + Cursor | None | 20 min |
| Step 4: fix_12 staging | Claude | None (staging only) | 20 min |
| Step 4: fix_12 UPDATE | Claude | ✅ "I authorize this action" | 10 min |
| Step 5: RNCID tier staging | Claude | None (staging only) | 30 min |
| Step 5: RNCID UPDATE (Tier 2 only) | Claude | ✅ "I authorize this action" | 15 min |
| Step 6: Spine metric verification | Perplexity | None | 10 min |

**Total: ~3 hours wall clock (Steps 1–3 can overlap with Steps 4–5 staging)**

---

## NUMBER RECONCILIATION (one canonical source)

- Contacts with no address: **85,216** (84,326 nc_donor_summary + 739 FEC + 147 NCBOE + 4 WinRed)
- Contacts with no RNCID: **178,254** (84,326 + 39,024 + 38,060 + 16,844)
- NCBOE reload target: **338,223** (95,967 + 242,256)
- Active spine rows: **200,383** (as of March 31 1:41 PM Cursor audit)
- Republican spine total: **$495,429,453**
