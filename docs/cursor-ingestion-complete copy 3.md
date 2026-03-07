

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

SUPABASE (PostgreSQL)          ← Source of truth
  ├── pgvector (embeddings)    ← AI/ML, microsegments  
  ├── Supabase Storage (files) ← PDFs, audio, images
  ├── Partitioned tables       ← Events (early stage)
  │
  ├──→ UPSTASH (Redis)         ← Brain's fast memory, hot data cache
  │     Brain reads Redis for speed
  │     Redis rebuilds from PostgreSQL if flushed
  │
  ├──→ MEILISEARCH CLOUD       ← News intelligence search
  │     Articles indexed in real-time
  │     Cross-references candidates + donors + issues
  │
  └──→ TIMESCALE CLOUD         ← Event store (at scale)
        Millions of brain decisions/day
        Activity logs for 1,000 candidates
        Campaign deployment events → triggers billing in Blueprint 2

# BroyhillGOP / NC First — Master Session Reference

## Session Date: March 6, 2026

## Author: Perplexity Comet + Ed Broyhill

------

# SECTION 1: CURRENT DATABASE STATE

**Supabase Project:** isbgjpnbocdkeslofota (BroyhillGOP-claude, PRO tier, PRODUCTION)

**Core data already loaded:**

- `nc_voters`: 9,082,810 rows (251 columns, 15 indexes, verified NC voter file)
- `datatrust_profiles`: 7,655,593 rows (synced with DataTrust)
- `nc_datatrust`: 7,655,593 rows (11 GB)
- `person_master`: 7,655,593 rows
- `acxiom_consumer_data`: 7,619,966 rows
- `rnc_voter_core`: 1,106,000 rows
- `donor_golden_records`: 304,212 rows (known identity resolution problem — JAMES BROYHILL appears 11 times)
- `donor_contribution_map`: 2,523,766 rows
- `fec_party_committee_donations`: 2,221,781 rows
- Total donations tracked: ~$630M across 2,895,499 linked donations

**FEC staging tables in public schema:**

- `fec_2015_2016_a_staging`: 35,339 rows (individual donors, PACs quarantined, NC contributors to H/P/S committees)
- `fec_2015_2016_b_staging`: exists (cycle B)
- `fec_2015_2016_a_filtered`: exists (cleaned subset)
- `fec_pac_staging_hold_a`: quarantined PACs from 2015-2016 A
- `fec_pac_staging_hold_b`: quarantined PACs from 2015-2016 B
- `fec_2017_2018_a_staging`: 80 columns, EMPTY (truncated after partial 19,414-row load, ready for full reload)
- `fec_candidates`: 161 rows (REP only, 2015-2016 cycle only)
- `fec_committee_candidate_lookup`: exists
- `fec_god_contributions`: 197,077 rows
- Total of 14 FEC-related tables in public schema

**Pipeline schema (11 tables, all created this session):**

1. `pipeline.source_schemas` — column registry per source system + version, indexed on (source_system, version)
2. `pipeline.dedup_rules` — deduplication rule definitions (match fields, thresholds, weight configs)
3. `pipeline.source_quality_rules` — data quality validation rules per source, supports {staging_table} placeholder
4. `pipeline.norm_readiness_rules` — normalization readiness gate checks (column, min_non_null_pct)
5. `pipeline.expected_indexes` — index verification registry (index_name, table, definition)
6. `pipeline.canary_checks` — post-load data quality canary queries with thresholds
7. `pipeline.ingestion_batches` — batch-level tracking (batch_id PK, source_system, status, row counts, timestamps)
8. `pipeline.ingestion_errors` — per-row error logging (FK to ingestion_batches.batch_id)
9. `pipeline.ingestion_jobs` — job orchestration (FK to file_manifest.manifest_id)
10. `pipeline.file_manifest` — file tracking with SHA-256 hash, row count, approved_by
11. `pipeline.identity_pass_log` — identity matching pass tracking (pass_name PK, status, rows_matched, rows_remaining)

**Key FK relationships:**

- `pipeline.ingestion_jobs.manifest_id` → `pipeline.file_manifest.manifest_id`
- `pipeline.ingestion_errors.batch_id` → `pipeline.ingestion_batches.batch_id`

**Other schemas that exist:** archive, core, norm, raw, staging (staging schema is currently empty — FEC data is in public schema)

------

# SECTION 2: PIPELINE MODULES BUILT IN CURSOR

**Completed (Tasks 1-4):**

- `pipeline/__init__.py` — package init with version
- `pipeline/db.py` — shared DB layer: loads .env, ThreadedConnectionPool (1-5 connections), get_connection() context manager, get_cursor(), all DB ops in try/except with logging
- `pipeline/ingest.py` — ingestion orchestrator: run_ingest(file_path, source_system, cycle, chunk_size=10000), SHA-256 hash, duplicate-load detection, inserts into file_manifest and ingestion_jobs, chunked CSV reads with pandas, inserts ingestion_batches per chunk, quality rules from source_quality_rules (supports {staging_table}), fatal rule failure → rollback and batch marked failed, errors logged to ingestion_errors, parameterized SQL via psycopg2.sql, logging instead of print, docstrings and type hints
- `pipeline/schema_check.py` — schema validator: ColumnSpec and SchemaCheckResult dataclasses, _normalize_type() for PostgreSQL type comparison (varchar→text, etc.), reads source_schemas for expected, reads information_schema.columns for actual, reports missing/extra columns and type mismatches, auto-populates source_schemas when auto_populate=True, returns pass/fail
- `pipeline/norm_gate.py` — normalization gate: RuleResult and GateResult dataclasses, reads norm_readiness_rules, runs column readiness queries using psycopg2.sql.Identifier, computes actual_pct = 100 * non_null / total vs min_non_null_pct, gate passes only if ALL rules pass, logs per-rule results
- `pipeline/dedup.py` — dedup engine: reads dedup_rules for source system, exact match on last_name + zip5, fuzzy match on first_name via dmetaphone(), configurable weights from dedup_rules.notes JSON, groups matches into pipeline.identity_clusters with status='pending_review' (NO auto-merge), writes to pipeline.identity_pass_log, returns DedupResult

**Also created:**

- `requirements.txt` — psycopg2-binary, click, pandas, python-dotenv
- `.env.example` — template for SUPABASE_DB_URL
- `pipeline/seed_fec_2015_2016.sql` — seed SQL for control tables
- `pipeline/test_2015_2016.py` — test script for pipeline validation
- `pipeline/run_seed.py` — seed runner (uses psql)

**Not yet built (Tasks 5-7):**

- `pipeline/index_check.py` — reads expected_indexes, checks pg_indexes, creates missing indexes
- `pipeline/canary.py` — reads canary_checks, executes canary queries, compares to thresholds, alerts on failures
- `pipeline/cli.py` — Click/argparse CLI tying all modules together

------

# SECTION 3: SEVEN HOLES IN CURSOR'S TEST PLAN

These must be fixed before running the pipeline test:

1. **Quality rules too thin** — only 3 rules (last_name, amount, zip NOT NULL). Missing: committee_id NOT NULL (critical join key), entity_type NOT NULL. Without committee_id, rows are useless for party filtering.
2. **Norm readiness thresholds are rubber stamps** — contributor_last_name set at 90% but actual data is 99.93%. contributor_zip at 99% but actual is 100%. Thresholds so low they'll never fail. Tighten to match actual data expectations: last_name >= 99%, zip >= 99.5%, amount >= 99.9%.
3. **dmetaphone not validated** — seed creates fuzzystrmatch extension but doesn't verify it works on Supabase managed platform. Must run `SELECT dmetaphone('test')` to confirm before relying on it in dedup.
4. **expected_indexes hardcoded to 2015-2016** — idx_fec_contrib_last_zip and idx_fec_contrib_first only defined for fec_2015_2016_a_staging. Need parameterized or per-cycle index entries.
5. **run_seed.py shells out to psql** — fragile, may not be installed on Mac. Should use pipeline/db.py connection pool to execute seed SQL directly.
6. **pipeline.identity_clusters table does not exist** — dedup.py writes to it but the DDL we installed only has 11 tables. identity_clusters is not among them. Will crash. Must CREATE TABLE pipeline.identity_clusters before running dedup.
7. **ingest.py is completely untested** — the test script runs schema_check, norm_gate, and dedup but skips ingest.py entirely. The most complex module with file hashing, manifest tracking, chunked loading, batch/job records is never exercised. Also canary.py and index_check.py aren't built yet so they can't be tested either.

------

# SECTION 4: 2015-2016 DATA BASELINE

From live query against `fec_2015_2016_a_staging` (35,339 rows):

| Column                      | Non-null count | Coverage                 |
| :-------------------------- | :------------- | :----------------------- |
| committee_id                | 35,339         | 100%                     |
| contributor_name            | 35,335         | 99.99%                   |
| contributor_last_name       | 35,315         | 99.93%                   |
| contributor_first_name      | 35,320         | 99.95%                   |
| contributor_zip             | 35,339         | 100%                     |
| contributor_state           | 35,339         | 100%                     |
| contributor_city            | 35,338         | 99.997%                  |
| contribution_receipt_amount | 35,339         | 100%                     |
| contribution_receipt_date   | 35,339         | 100%                     |
| candidate_id                | 10             | 0.03% (virtually empty)  |
| candidate_name              | 3              | 0.008% (virtually empty) |
| candidate_office_state      | 3              | 0.008% (virtually empty) |
| Unique committees           | varies         | —                        |
| Unique contributor states   | varies         | —                        |

**Critical finding:** candidate_id, candidate_name, and candidate_office_state are almost entirely NULL. Party and state filtering MUST use committee_id → fec_committee_candidate_lookup → fec_candidates JOIN path, not direct column filtering.

------

# SECTION 5: 2017-2018 FILE STATUS

**File:** `2017-2018-FEC-Raw-dem-rep-ind.csv`
**Source:** FEC.gov individual contributions export: `contributor_state=NC`, `recipient_committee_type=H,P,S`, `two_year_transaction_period=2018`
**Total rows:** 66,901
**Columns:** 80 (full FEC Schedule A schema — all columns match fec_2017_2018_a_staging perfectly, 0 missing)
**Contains:** Democrats, Republicans, Independents mixed (all parties). NC contributors only. House, Presidential, Senate committees only (no PACs in the export filter).
**Out-of-state candidates:** YES — NC donors contributing to candidates in ANY state are included. Must filter.

**Confirmed present (from partial 19,414-row load before truncation):**

- DONALD J. TRUMP FOR PRESIDENT, INC. — 6,201 rows
- THOM TILLIS COMMITTEE — 92 rows
- MCHENRY FOR CONGRESS — 15 rows
- VIRGINIA FOXX FOR CONGRESS — 6 rows
- RICHARD BURR COMMITTEE; THE — 2 rows

**Current state:** `fec_2017_2018_a_staging` exists with 80 columns, is EMPTY (truncated). Ready for full reload.

**Filtering plan (after full load):**

1. Quarantine Democrats — identify via committee_id → candidate party lookup
2. Quarantine Independents — same method
3. Quarantine out-of-state candidates — identify via committee_id → candidate_office_state lookup
4. Quarantine PACs — already excluded by FEC export filter (H/P/S only), but verify
5. Keep only NC Republican individual donor contributions

**Blocking issue:** `fec_candidates` table only has 161 REP candidates from 2015-2016. Need 2017-2018 candidate data loaded to filter by party and state for that cycle.

------

# SECTION 6: PLATFORM SCALE ARCHITECTURE

## 6A: Table Estimates by Category

| Category                        | Estimated Tables | Description                                                  |
| :------------------------------ | :--------------- | :----------------------------------------------------------- |
| Core Identity Layer             | ~15              | person_master, voter_core, voter_registration, voter_history, donor_golden_records, donor_contributions, datatrust_profiles (grouped into 5-8 tables for 2,500 variables), identity_links, household_links |
| Political Structure             | ~10              | candidates (5,000 rows), offices, districts, precincts, committees, committee_candidate_map, elections, election_cycles, party_organizations |
| Fundraising/Donations           | ~8               | donations, pledges, recurring_gifts, contribution_limits, compliance_checks, fundraising_events, event_attendees |
| Financial/Cost Accounting       | ~40-60           | Budget per ecosystem/candidate/function, cost/benefit/variance tracking per campaign action/channel/cycle, invoice/commission/payment/reconciliation, ROI per donor touchpoint, linear programming constraints/optimization runs/allocation results across directory tree |
| Activity & Client Management    | ~50-80           | Activity logs for 5,000 candidate clients, client onboarding/subscription/usage metering, admin panel state, user permissions per ecosystem per candidate, session tracking, audit trails, compliance logs |
| News Intelligence / E20 Brain   | ~60-100          | Media outlet registry (hundreds of sources), article ingestion/entity extraction/sentiment, candidate-article links, donor-issue links, hot issue tracking, alert triggers/notification queues/escalation rules, brain stimulus/response tables, trigger definitions/condition evaluations/action logs/feedback loops/model retraining |
| Social Media                    | ~30-40           | Platform connections per candidate, post tracking/engagement/comment analysis, content calendar/approval workflows, influencer tracking, live feed aggregation |
| Microsegmentation & Testing     | ~40-60           | 1,000 microsegment definitions/membership/scoring/performance history, infinite A/B testing: test definitions/variant configs/assignment/outcome tracking/statistical significance/winner determination, segment x channel x message x timing matrices |
| Security & Candidate Protection | ~20-30           | Encryption key management, ACLs, data compartmentalization rules per ecosystem, threat detection, PII masking, candidate firewall configurations |
| DataTrust Deep Integration      | ~30-50           | 2,500 variables organized into relational groups: voter scores (dozens of model types), consumer data, demographic segments, contact channels, modeled behaviors, issue affinities, turnout predictions, persuadability. Model definitions/score runs/results/history. Cross-reference to 1,000 microsegments |
| E20 Brain Orchestration         | ~50-80           | Decision engine: rules/conditions/actions/outcomes. Model registry/versions/training snapshots. Trigger catalog (hundreds of stimulus types). Execution queue/priority management. Inter-ecosystem message bus (events/subscriptions/routing — respecting coordination walls). Performance feedback. Learning: pattern recognition/anomaly detection/trend analysis |
| Per-Ecosystem Operations        | ~200-250         | ~3-5 tables per ecosystem x 67 ecosystems: GOTV (targets/canvass/walk_lists/turf), Email (campaigns/sends/opens/clicks/bounces), SMS (campaigns/messages/responses), Volunteer (shifts/assignments/hours/skills), Events (registrations/attendance/follow_ups), Polling (surveys/responses/crosstabs) |
| Pipeline & Infrastructure       | ~20              | 11 pipeline tables (built), audit logs, job queues, error tracking, AI decision logs, model versioning |
| Staging/Raw/Archive             | ~30              | Raw ingest tables per source per cycle, hold/quarantine tables, archive snapshots |

**TOTAL: 1,200-1,800 tables, 3,000-5,000 indexes**

## 6B: Conc

you review databse needs here. are rthese different server companie or all hetzner . if different where does each function best be stored and operated from? At the scale you're describing, one PostgreSQL database is a single point of failure and a bottleneck. Here's what the architecture actually needs: 1. The Core Relational Database (PostgreSQL/Supabase) — what you have now. This holds the identity spine, donor records, voter files, candidate data, contributions, the structured relational data. This is the source of truth. It's where foreign keys and coordination walls live. 2. A Time-Series / Event Store — for the 24/7 activity streams. The E20 brain making thousands of decisions per hour, news intelligence monitoring hundreds of outlets, social media feeds, activity logs for 1,000 candidates — that's write-heavy, append-only data. PostgreSQL can do it, but it chokes when you're writing millions of events per day while also trying to run complex analytical queries. Something like TimescaleDB (runs on top of Postgres) or a dedicated event store handles this. 3. A Cache / Real-Time Layer (Redis) — the brain needs to respond fast. When it's deciding which donor to contact right now, it can't wait for a full table scan across 7.6M voters. Redis holds the hot data — current campaign state, active triggers, recent scores, the brain's working memory. This is where you solve the short-term memory problem architecturally. The brain's "memory" lives in Redis, persisted to Postgres. 4. A Search Engine (Elasticsearch or similar) — for the news intelligence ecosystem monitoring hundreds of media outlets and cross-referencing candidates and donors against hot issues. Full-text search across millions of articles, real-time indexing, fuzzy matching on names in news content. PostgreSQL's full-text search won't keep up at that volume. 5. A Vector Database (for AI/ML) — when you're running 1,000 microsegments and infinite A/B testing, the AI needs to store and query embeddings — donor behavior patterns, message similarity, segment affinity scores. Supabase has pgvector built in, which covers you initially, but at scale this may need its own store. 6. A Blob/File Store (Supabase Storage or S3) — PDFs, images, voice recordings from RVM campaigns, social media assets, uploaded documents. Not in the database.

These are 6 different services — not all on one server. Based on last night's decision to go **managed services with no Hetzner**, here's exactly where each one lives and operates from:

| #     | System                           | Provider                                                     | Cost at Startup             | Cost at Scale (1,000 candidates) | Why This Provider                                            |
| :---- | :------------------------------- | :----------------------------------------------------------- | :-------------------------- | :------------------------------- | :----------------------------------------------------------- |
| **1** | **PostgreSQL** (Core relational) | **Supabase**                                                 | $25/mo (Pro)                | $75-150/mo (Pro+)                | Already have it. Built-in Auth, RLS for coordination walls, API layer, dashboard. Source of truth. |
| **2** | **Time-Series / Event Store**    | **Supabase** (partitioned tables initially) → **Timescale Cloud** at scale | $0 initially (use Supabase) | $30-100/mo                       | Start with PostgreSQL partitioned tables inside Supabase. When event volume exceeds what Supabase handles comfortably (millions/day), migrate to Timescale Cloud — fully managed, PostgreSQL-compatible, no server management. |
| **3** | **Redis Cache**                  | **Upstash**                                                  | $0 (free: 10K commands/day) | $10-50/mo                        | Serverless Redis. No server to manage. Auto-scales. REST API so it works from anywhere. The brain's fast working memory. Data persists across restarts. |
| **4** | **Search Engine**                | **Meilisearch Cloud** or **Typesense Cloud**                 | $0 (free tier) or $30/mo    | $50-200/mo                       | Full-text search for news intelligence. Real-time indexing. Faster and simpler than Elasticsearch for your use case. No server management. Meilisearch has better developer experience; Typesense has better typo tolerance. |
| **5** | **Vector Database**              | **Supabase pgvector** (already included) → **Pinecone** at scale | $0 (use Supabase)           | $70-200/mo                       | pgvector is already available in your Supabase instance — enable the extension and it works. Handles microsegment embeddings and AI similarity queries. If you hit millions of vectors, Pinecone is purpose-built and fully managed. |
| **6** | **File/Blob Storage**            | **Supabase Storage** (already included)                      | $0 (included in Pro)        | $25-50/mo                        | Already included in your Supabase plan. PDFs, images, RVM audio, social media assets. If you outgrow it, add Cloudflare R2 ($0.015/GB) — S3-compatible, no egress fees. |

**Starting monthly cost: $25** (just Supabase Pro — everything else starts free)

**At scale with 1,000 candidates: $200-750/month** across all 6 services

**No Hetzner. No SSH. No server management. No DevOps hire.**

**How they connect:**

```
text
SUPABASE (PostgreSQL)          ← Source of truth
  ├── pgvector (embeddings)    ← AI/ML, microsegments  
  ├── Supabase Storage (files) ← PDFs, audio, images
  ├── Partitioned tables       ← Events (early stage)
  │
  ├──→ UPSTASH (Redis)         ← Brain's fast memory, hot data cache
  │     Brain reads Redis for speed
  │     Redis rebuilds from PostgreSQL if flushed
  │
  ├──→ MEILISEARCH CLOUD       ← News intelligence search
  │     Articles indexed in real-time
  │     Cross-references candidates + donors + issues
  │
  └──→ TIMESCALE CLOUD         ← Event store (at scale)
        Millions of brain decisions/day
        Activity logs for 1,000 candidates
        Campaign deployment events → triggers billing in Blueprint 2
```

**The migration path is gradual:**

- **Day 1:** Supabase only ($25/mo) — PostgreSQL handles everything including events, vectors, and files
- **Month 3:** Add Upstash Redis ($0) when the brain needs sub-millisecond reads
- **Month 6:** Add Meilisearch ($0-30) when news intelligence goes live
- **Month 12+:** Move events to Timescale Cloud when volume demands it. Move vectors to Pinecone if pgvector slows down.

You never pay for capacity you don't need yet. Each service gets added when the load justifies it, and each one has a free tier to start.