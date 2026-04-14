# BroyhillGOP Ingestion Pipeline — Master Plan

**Version:** 1.0  
**Date:** March 2026  
**Status:** Build specification — no execution until approved  
**Authority:** This document is the single source of truth for the Hetzner/Mac ingestion and identity pipeline. All code and DDL must align with it.

---

## 0. Prerequisites (Must Be True Before Any Pipeline Work)

### 0.1 Foundation Tables: Indexed and Analyzed

The pipeline assumes two tables are **queryable** before identity resolution or norm backfill:

| Table | Rows | Requirement |
|-------|------|-------------|
| `public.nc_voters` | ~9.1M | Index on `ncid` (unique), indexes on `last_name`, `zip_code`, `county_desc`. `ANALYZE public.nc_voters` run. Filtered lookups return in milliseconds. |
| `public.nc_datatrust` | ~7.65M | Index on `statevoterid`. `ANALYZE public.nc_datatrust` run (and VACUUM if needed). Single-row lookup by `statevoterid` returns instantly; planner uses index, not seq scan. |

**Verification:** Run `EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM nc_datatrust WHERE statevoterid = 'BN94856';` — must show Index Scan, not Seq Scan. If not, run ANALYZE (and if necessary VACUUM) via **direct Postgres connection (port 5432)**, not the Supabase SQL editor (2-minute timeout will kill long ANALYZE).

**Link:** `nc_datatrust.statevoterid` = `nc_voters.ncid`. This is the primary identity join for Pass 1.

### 0.2 No AI-Driven Writes to Production

- No Claude/Cursor/Perplexity session runs TRUNCATE, DELETE, or bulk INSERT/UPDATE against production.
- All pipeline execution is either: (a) you running scripts/commands yourself, or (b) a human-approved orchestrator (Mac or Hetzner) using a dedicated DB role with known credentials.

---

## 1. Architecture Overview

### 1.1 Components

- **Orchestrator:** Single Python service. Runs on **Eddie's Mac** for jobs ≤30 minutes or ≤1M rows; runs on **Hetzner** for longer/larger jobs (files transferred via SCP/rsync to `/data/incoming/...` first).
- **Database:** Supabase Postgres. Orchestrator uses **direct connection (port 5432)** for all ingestion and identity work — never the pooler (port 6543). Session settings: `statement_timeout = 0`, `idle_in_transaction_session_timeout = 0`, `tcp_keepalives_idle = 60`.
- **Schemas:** `raw` (immutable source copies or views), `norm` (cleaned, deduped, with `person_id` nullable until resolution), `core` (person_spine, contribution_map, identity_clusters, etc.), `staging` (per-job scratch), `archive` (pre-destructive snapshots), `pipeline` (job/batch/error/metadata).

### 1.2 Data Flow (Conceptual)

```
File (Mac or Hetzner)
  → Validate schema + hash (no double-load)
  → Staging (parse, dedup key, dollar check)
  → Raw (COPY/insert by batch, tag job_id)
  → [Archive-before-reset when replacing a table]
  → Norm ETL (add voter_ncid, email, employer from nc_voters, donor_contacts, etc.)
  → Norm readiness checks (per-source rules)
  → Identity resolution (6 passes, stored procedures only)
  → Core (person_spine, contribution_map, identity_clusters, person_names, etc.)
  → Validation + canary checks
```

---

## 2. Pipeline Schema (pipeline.*)

All tables live in schema `pipeline`. No application logic outside the orchestrator and stored procedures writes here.

### 2.1 Job and Batch Tracking

**pipeline.ingestion_jobs**

| Column | Type | Purpose |
|--------|------|---------|
| job_id | UUID PRIMARY KEY | Unique job |
| job_type | TEXT | `ARCHIVE_AND_RESET`, `ingest_nc_boe`, `ingest_fec_schedule_a`, `ingest_fec_party`, `norm_etl_nc_boe`, `identity_pass_1_ncid`, … |
| source_system | TEXT | nc_boe, fec_individual, fec_party, nc_voters, nc_datatrust |
| file_path | TEXT | Path to file (Mac or Hetzner) |
| file_hash_sha256 | TEXT | SHA-256 of file; used to prevent double-load |
| file_size_bytes | BIGINT | |
| row_count_estimate | BIGINT | From dry-run or manifest |
| status | TEXT | pending, running, completed, failed, partial_failed, completed_with_warnings |
| manifest_id | UUID | FK to pipeline.file_manifest when applicable |
| started_at | TIMESTAMPTZ | |
| finished_at | TIMESTAMPTZ | |
| last_error | TEXT | |
| approved_by | TEXT | For ARCHIVE_AND_RESET: human identifier |

**pipeline.ingestion_batches**

| Column | Type | Purpose |
|--------|------|---------|
| batch_id | UUID PRIMARY KEY | |
| job_id | UUID | FK |
| batch_number | INT | 1, 2, 3, … |
| offset_start | BIGINT | Row offset in file |
| offset_end | BIGINT | |
| status | TEXT | pending, running, completed, failed, rolled_back |
| rows_read | INT | |
| rows_inserted | INT | After dedup |
| rows_duplicate_within_file | INT | |
| rows_duplicate_vs_raw | INT | |
| amount_sum_file | NUMERIC | Sum of amount in this batch (from file) |
| amount_sum_db | NUMERIC | Sum of amount inserted (must match) |
| error_message | TEXT | |
| started_at | TIMESTAMPTZ | |
| finished_at | TIMESTAMPTZ | |

**pipeline.ingestion_errors**

| Column | Type | Purpose |
|--------|------|---------|
| id | BIGSERIAL PRIMARY KEY | |
| job_id | UUID | |
| batch_id | UUID | |
| row_offset | BIGINT | Approximate row in file |
| error_type | TEXT | parse_error, constraint_violation, dedup_mismatch, amount_mismatch |
| error_message | TEXT | |
| sample_data | JSONB | First few values for debugging |

### 2.2 File Manifest (Dry-Run → Approve → Load)

**pipeline.file_manifest**

| Column | Type | Purpose |
|--------|------|---------|
| manifest_id | UUID PRIMARY KEY | |
| source_system | TEXT | |
| file_pattern | TEXT | e.g. nc_boe_*.csv |
| expected_row_count | BIGINT | Populated by dry-run |
| expected_amount_total | NUMERIC | |
| expected_date_range_start | DATE | |
| expected_date_range_end | DATE | |
| status | TEXT | draft, approved |
| dry_run_job_id | UUID | Job that produced this draft |
| approved_at | TIMESTAMPTZ | |
| approved_by | TEXT | |

**Workflow:** (1) Run ingest with `dry_run = true` → orchestrator creates a row with `status = draft` and reports row count + dollar total. (2) Human reviews; sets `status = approved`. (3) Real run: orchestrator looks up approved manifest, validates actual file against it; if mismatch, job fails before any insert.

### 2.3 Schema and Dedup Registry

**pipeline.source_schemas**

| Column | Type | Purpose |
|--------|------|---------|
| source_system | TEXT | |
| version | TEXT | e.g. v1, v2 |
| valid_from | DATE | NCBOE 2015–2018 → v1 |
| valid_to | DATE | |
| column_name | TEXT | |
| position | INT | Order in CSV if positional |
| data_type | TEXT | |
| nullable | BOOLEAN | |

**pipeline.dedup_rules**

| Column | Type | Purpose |
|--------|------|---------|
| source_system | TEXT | |
| dedup_function_name | TEXT | e.g. pipeline.dedup_key_ncboe — a Postgres function, not raw SQL string |
| notes | TEXT | |

Dedup key is computed by a **stable Postgres function** per source (e.g. `pipeline.dedup_key_ncboe(record) RETURNS text`), unit-testable. Staging tables have a column `dedup_key` set by that function.

### 2.4 Quality and Readiness Rules

**pipeline.source_quality_rules**

| Column | Type | Purpose |
|--------|------|---------|
| source_system | TEXT | |
| rule_name | TEXT | e.g. require_contributor_address |
| rule_sql_condition | TEXT | Query that returns a single count (e.g. rows where contributor_street_1 IS NULL) |
| severity | TEXT | warn, fatal |
| description | TEXT | |

Example: FEC Schedule A — rule "require_contributor_address": if `COUNT(*) WHERE contributor_street_1 IS NULL` > 0, job fails with message that file may be bulk-download without addresses.

**pipeline.norm_readiness_rules**

| Column | Type | Purpose |
|--------|------|---------|
| source_system | TEXT | |
| column_name | TEXT | voter_ncid, email, employer |
| min_non_null_pct | NUMERIC | 0.25 = 25% |
| notes | TEXT | e.g. "~35% of BOE donors are registered NC voters" |

Identity jobs do not start until, for each relevant source, the actual non-null percentage for each column is >= min_non_null_pct. Example: nc_boe voter_ncid >= 25%, employer >= 60%; fec_individual employer >= 90%, voter_ncid >= 1%.

### 2.5 Canary Checks

**pipeline.canary_checks**

| Column | Type | Purpose |
|--------|------|---------|
| check_name | TEXT | e.g. broyhill_raw_nc_boe |
| phase | TEXT | after_raw_nc_boe, after_norm_nc_boe, after_identity_pass_1 |
| query_sql | TEXT | e.g. SELECT * FROM raw.nc_boe_donations WHERE last_name = 'BROYHILL' ORDER BY contribution_date DESC LIMIT 3 |
| expected_min_rows | INT | If result rows < this, trigger severity behavior |
| severity | TEXT | warn, fatal |

After each phase, orchestrator runs canaries for that phase. If `rows_returned < expected_min_rows`: **warn** → log in job report, mark job `completed_with_warnings`; **fatal** → mark job `failed`, stop downstream.

### 2.6 Archive Log

**archive.archive_log**

| Column | Type | Purpose |
|--------|------|---------|
| id | BIGSERIAL PRIMARY KEY | |
| source_schema | TEXT | public, norm, raw |
| source_table | TEXT | |
| archive_table | TEXT | e.g. archive.nc_boe_donations_raw_20260305 |
| archived_at | TIMESTAMPTZ | |
| row_count | BIGINT | Must match source before truncate |
| job_id | UUID | ARCHIVE_AND_RESET job that created it |

### 2.7 Index Verification

**pipeline.expected_indexes**

| Column | Type | Purpose |
|--------|------|---------|
| table_name | TEXT | |
| index_name | TEXT | |

After any job that drops and recreates indexes, run: for each (table_name, index_name) in this table, verify that `pg_indexes` contains it. If any missing, mark job `index_incomplete` and surface in pipeline.vw_job_status.

### 2.8 Views for Visibility

**pipeline.vw_job_status**

One row per job: job_id, job_type, source_system, status, batches_total, batches_completed, pct_complete, rows_loaded, last_error, started_at, finished_at, index_status (OK / incomplete).

**pipeline.vw_identity_status**

One row per identity pass: pass_name, status, rows_matched, rows_remaining, last_run_at.

These are the **primary** way you monitor the pipeline — run in Supabase SQL editor. Email alerts are optional backup.

---

## 3. Step 0: ARCHIVE_AND_RESET

Before any new data is loaded into tables that will be replaced, the first pipeline job is always:

**Job type:** `ARCHIVE_AND_RESET`  
**Status:** Requires manual approval in pipeline UI or config; then `running` → `completed` or `failed`.

**Target tables (example list; adjust to your restored state):**

- public.nc_boe_donations_raw  
- public.donor_contribution_map  
- norm.nc_boe_donations  
- norm.fec_individual  
- norm.fec_party  
- (Optional) public.donor_golden_records — only if you explicitly decide to reset it.

**Actions per table:**

1. `CREATE TABLE archive.{table_name}_{YYYYMMDD} AS SELECT * FROM {schema}.{table_name};`
2. Verify `(SELECT COUNT(*) FROM source) = (SELECT COUNT(*) FROM archive table)`; if not, abort job.
3. `TRUNCATE TABLE {schema}.{table_name};`
4. Insert row into `archive.archive_log` with source_table, archive_table, row_count, job_id.

Only after this job is **completed** does the orchestrator allow ingestion jobs for those sources.

---

## 4. Ingestion Per Source (Common Pattern)

### 4.1 Preconditions

- File hash not already in pipeline.ingestion_jobs with status completed (no double-load).
- For first load: dry-run has been run and manifest entry approved.
- ARCHIVE_AND_RESET already completed if this load is replacing existing data.

### 4.2 Per-File Flow

1. **Open file** (local Mac or Hetzner path). Compute SHA-256 (streaming). Check pipeline.ingestion_jobs for existing file_hash_sha256 → if found completed, reject.
2. **Schema validation:** Read header; match to pipeline.source_schemas for this source_system and file date/version. If no match, fail job before any insert.
3. **Quality rules:** Run pipeline.source_quality_rules for this source (e.g. FEC contributor_street_1 NOT NULL). If any fatal rule fails, fail job.
4. **Create job row** (status = running) and batch rows (pending).
5. **Chunk file** into batches (e.g. 100k rows for COPY). For each batch:
   - Parse → staging table (with dedup_key from pipeline dedup function).
   - Dedup: count rows that would be new vs duplicate vs existing in raw (by dedup_key). Optionally log duplicate counts to batch row.
   - **Dollar check:** Sum amount in batch from file; after INSERT into raw (tagged job_id, batch_number), sum amount for that batch in raw. If difference beyond tolerance (e.g. 0 for batch 1, configurable later), rollback batch, mark batch failed, mark job partial_failed.
   - **Error tolerance:** Batch 1 must have 0 row-level errors. Later batches: 0 or configurable (e.g. max 0.01%). Any parse/constraint error goes to pipeline.ingestion_errors.
   - Commit batch. Update batch status and job progress.
6. **Full-file reconciliation:** Sum(amount) from file vs Sum(amount) in raw for this job_id. Must match. If not, mark job failed.
7. **Canary:** Run pipeline.canary_checks for this phase. Fatal canary failure → job failed.
8. Mark job completed (or completed_with_warnings). If any batch failed and not resumable, mark job partial_failed.

### 4.3 Rollback of Partial Job

If job is partial_failed and human decides not to resume:

- Call **pipeline.job_cleanup(job_id)**:
  - `DELETE FROM raw.{source_table} WHERE _job_id = job_id;`
  - Update all batches for this job to status = rolled_back.
  - Job status set to failed (or cleaned).

### 4.4 Resume

If job partial_failed due to transient error (e.g. connection drop), fix cause and **resume from first failed batch**. Do not re-insert batches already completed. Each batch is independent; reconnection between batches is allowed.

### 4.5 Load Method by Size

- **≤ 100k rows:** Batched INSERT acceptable.
- **> 100k rows:** Use **COPY FROM STDIN** into staging (chunk file into 100k-row chunks, feed each chunk as one COPY). Then from staging → raw with dedup and dollar check as above.

### 4.6 Index Management for Bulk Loads

For target tables with > 100k rows: before job starts, **drop** indexes listed in pipeline.expected_indexes for that table (or a dedicated "drop for bulk" list). After job completes, **CREATE INDEX CONCURRENTLY** for each. Then run index verification; if any missing, mark job index_incomplete.

### 4.7 Audit Columns on Raw Tables

Every raw table must have:

- _job_id UUID  
- _batch_number INT  
- _loaded_at TIMESTAMPTZ  
- _file_hash TEXT (SHA-256)

So any row can be traced back to the exact file and job.

---

## 5. Dedup and Cross-Year Overlap

### 5.1 Within-File Dedup

Staging table has dedup_key. Before insert into raw, discard or count duplicate dedup_key within staging for this batch.

### 5.2 Cross-File and Cross-Year

Before insert into raw, for each row in staging: check if dedup_key already exists in raw (any prior job). If yes, do not insert (or insert into a "duplicate" log only). Count as rows_duplicate_vs_raw. NCBOE year-overlap: 2025 file may contain 2024 transactions; dedup_key includes enough fields (e.g. report_id, line_number, or name+committee+date+amount) so that re-loading 2024 then 2025 does not double-count.

### 5.3 Dedup Key Examples (Function Logic)

- **NCBOE:** Deterministic key from last_name, first_name, committee_name, contribution_date, amount (and report_id/line if available).
- **FEC Schedule A:** fec_report_id || line_number or equivalent stable row ID.

---

## 6. Norm ETL (Before Identity)

Norm tables (e.g. norm.nc_boe_donations, norm.fec_individual, norm.fec_party) must be populated and **enriched** with:

- voter_ncid (from nc_voters / donor_voter_links by matching logic)
- email (from donor_contacts_staging, donor_golden_records, FEC where present)
- employer, occupation (from BOE/FEC raw)
- phone (where available)

Orchestrator runs **norm_etl_*** jobs that:

- Read from raw (and from nc_voters, nc_datatrust, donor_voter_links, donor_contacts_staging as needed).
- Write into norm with person_id = NULL.
- Norm readiness is then checked against pipeline.norm_readiness_rules; identity jobs do not start until readiness passes.

---

## 7. Identity Resolution (6 Passes)

Only after norm has required columns and readiness checks pass:

- **Pass 1:** voter_ncid exact match (norm.voter_ncid = core.person_spine.voter_ncid).
- **Pass 2:** email exact (lower(norm.email) = lower(core.person_spine.email)).
- **Pass 3:** norm_last + norm_first + zip5.
- **Pass 4:** norm_last + nickname_canonical + zip5 (using core.nick_group).
- **Pass 5:** norm_last + first_initial + zip5 + employer.
- **Pass 6:** Cross-zip with secondary signal (email/phone/ncid/employer).

**Rules:**

- core.person_spine is **never** seeded from donor_golden_records or person_master. Only the dedicated stored procedures (e.g. core.create_person_from_norm, core.merge_norm_into_person) may insert/update spine; they accept only norm source_system/source_id.
- Identity runs as **jobs with batches** (chunked by norm primary key or hash). Checkpoint/resume: if a pass fails mid-way, resume from first failed batch.
- Each batch runs in a stored procedure that: finds matches, updates core.identity_clusters, sets norm.person_id, or creates new spine row.

---

## 8. Core Population

After identity passes:

- **core.contribution_map:** From norm + core.candidate_committee_map (committee_id → candidate_id, tenant_id).
- **core.person_names:** From norm and raw name variants.
- **core.person_addresses:** From norm/raw address history.
- **core.preferred_name_cache:** From inference (source-weighted) and core.vip_overrides.

All driven by orchestrator calling stored procedures; no ad-hoc SQL from AI.

---

## 9. Dry-Run Mode

For any ingest_* job, run with **dry_run = true**:

- Parse and validate file.
- Run schema match and quality rules.
- Compute dedup stats (how many new vs duplicate).
- Compute row count and dollar total.
- **Write pipeline.file_manifest row** with status = draft and dry_run_job_id.
- **Commit nothing** to staging, raw, or norm.

Human reviews draft manifest; approves. Real run then validates file against approved manifest.

---

## 10. Connection and Runtime Policy

- **Orchestrator → Postgres:** Direct connection, port 5432. Session: `statement_timeout = 0`, `idle_in_transaction_session_timeout = 0`, `tcp_keepalives_idle = 60`.
- **Where to run:** Jobs ≤30 min and ≤1M rows → Eddie's Mac. Jobs >30 min or >1M rows → Hetzner (file transferred first via SCP/rsync to /data/incoming/...).
- **Statement timeout:** Supabase SQL editor (2 min) is not used for ANALYZE, long COPY, or multi-batch jobs; use direct connection only.

---

## 11. Build Order (Implementation Sequence)

1. **pipeline.* DDL** — Create schema pipeline; all tables and views above; stored procedures: pipeline.job_cleanup(job_id), pipeline.dedup_key_* functions, index verification helper.
2. **archive.archive_log** and ARCHIVE_AND_RESET job logic (no execution until approved).
3. **NCBOE end-to-end** — One source: staging table, raw table, dedup function, quality rules, canary checks, dry-run → manifest → real run with COPY/batch, dollar reconciliation, canary run. Validate with BROYHILL canary.
4. **FEC Schedule A** — Same pattern; add FEC-specific quality rule (contributor_street_1). Use COPY for >100k rows.
5. **FEC Party** — Same; run on Hetzner if >1M rows.
6. **Norm ETL** for nc_boe, fec_individual, fec_party (with voter_ncid, email, employer backfill from nc_voters, donor_voter_links, donor_contacts_staging, raw).
7. **Norm readiness rules** and gate for identity.
8. **Identity passes** as stored procedures + orchestrator jobs (checkpoint/resume).
9. **Core population** (contribution_map, person_names, person_addresses, etc.) and validation queries.

---

## 12. Success Criteria (Before Calling the Pipeline “Done”)

- ARCHIVE_AND_RESET documented and run once (or explicitly skipped with approval).
- NCBOE load: no double-load (hash check), no duplicate rows in raw (dedup), file sum = db sum (batch + job), canary BROYHILL returns expected rows.
- nc_voters and nc_datatrust joinable and used in norm backfill and Pass 1.
- Identity: spine built only from norm; no rows from golden_records/person_master; resolution rates reported per source (BOE, FEC individual, FEC party).
- core.contribution_map populated with person_id, candidate_id, tenant_id; validation queries (RFC-001 Section 4) pass.

---

*End of Master Plan. All implementation must follow this document; any deviation requires explicit approval and update to this plan.*