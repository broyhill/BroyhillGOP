## PROJECT CONTEXT

You are building a Python-based FEC donor data ingestion pipeline for the BroyhillGOP political CRM platform. The pipeline runs on a local Mac (primary) with Supabase PostgreSQL as the database backend.

## DATABASE CONNECTION
- Supabase project: isbgjpnbocdkeslofota
- Schemas in use: pipeline, staging, core, norm, raw, archive
- Connection via Supabase MCP or direct psycopg2/asyncpg

## PIPELINE SCHEMA (already installed — DO NOT recreate these tables)

The following 11 tables exist in the `pipeline` schema:

1. source_schemas — column registry per source system + version
2. dedup_rules — deduplication rule definitions (match fields, thresholds)
3. source_quality_rules — data quality validation rules per source
4. norm_readiness_rules — normalization readiness gate checks
5. expected_indexes — index verification registry
6. canary_checks — post-load data quality canary queries
7. ingestion_batches — batch-level tracking (batch_id PK, source_system, status, row counts, timestamps)
8. ingestion_errors — per-row error logging (FK to batch_id)
9. ingestion_jobs — job orchestration (FK to file_manifest.manifest_id)
10. file_manifest — file tracking with hash, row count, approved_by
11. identity_pass_log — identity matching pass tracking (pass_name PK, status, rows_matched, rows_remaining)

Key relationships:
- ingestion_jobs.manifest_id → file_manifest.manifest_id (FK)
- ingestion_errors.batch_id → ingestion_batches.batch_id (FK)

## STAGING DATA ALREADY LOADED

In the `staging` schema, the following FEC tables contain cleaned data (PACs already quarantined to staging.hold_*):
- staging.fec_2015_2016_a_staging (~57K rows, individual donors only)
- Additional FEC cycle tables as they arrive

PAC rows are held in:
- staging.hold_fec_2015_2016_pacs (and similar per cycle)

## BUILD TASKS — implement in this order:

### Task 1: Ingestion Orchestrator (pipeline/ingest.py)
Build a Python module that:
- Accepts a source file path + source_system name + cycle label
- Computes file SHA-256 hash → inserts into pipeline.file_manifest
- Creates a pipeline.ingestion_jobs record linked to the manifest
- Creates a pipeline.ingestion_batches record
- Reads the file in chunks (default 10,000 rows)
- For each chunk: validates against pipeline.source_quality_rules, logs errors to pipeline.ingestion_errors, inserts clean rows into the appropriate staging table
- Updates batch/job status and row counts on completion
- Uses Python logging, not print statements

### Task 2: Schema Validator (pipeline/schema_check.py)
Build a module that:
- Reads pipeline.source_schemas for the given source_system + version
- Compares expected columns vs actual columns in the target staging table
- Reports missing columns, extra columns, type mismatches
- Returns pass/fail boolean
- Populates pipeline.source_schemas if a new version is detected

### Task 3: Normalization Gate (pipeline/norm_gate.py)
Build a module that:
- Reads pipeline.norm_readiness_rules for the source
- Runs each rule query against the staging table
- All rules must pass before data moves from staging → norm schema
- Logs results to console and updates rule status

### Task 4: Dedup Engine (pipeline/dedup.py)
Build a module that:
- Reads pipeline.dedup_rules for active rules
- Applies matching logic (exact on last_name+zip, fuzzy on first_name using dmetaphone — already installed in Supabase)
- Scores matches and groups into pipeline identity clusters
- Logs pass results to pipeline.identity_pass_log
- Does NOT auto-merge — flags candidates for review

### Task 5: Index Verifier (pipeline/index_check.py)
Build a module that:
- Reads pipeline.expected_indexes
- Checks pg_indexes for existence
- Creates any missing indexes
- Reports status

### Task 6: Canary Runner (pipeline/canary.py)
Build a module that:
- Reads pipeline.canary_checks
- Executes each canary query
- Compares result to expected threshold
- Alerts (log warning) on failures
- Updates last_run timestamp

### Task 7: CLI Entry Point (pipeline/cli.py)
Build a Click or argparse CLI that ties it all together:
- `python -m pipeline ingest <file> --source fec --cycle 2015_2016`
- `python -m pipeline validate --source fec --cycle 2015_2016`
- `python -m pipeline normalize --source fec --cycle 2015_2016`
- `python -m pipeline dedup --source fec`
- `python -m pipeline canary`
- `python -m pipeline check-indexes`

## IMPORTANT CONSTRAINTS
- All SQL must use parameterized queries (no f-strings for SQL)
- Use connection pooling (asyncpg or psycopg2 pool)
- Every module must have docstrings and type hints
- Create a requirements.txt (psycopg2-binary, click, pandas, python-dotenv)
- Use .env for SUPABASE_DB_URL — never hardcode credentials
- Create a pipeline/__init__.py and pipeline/db.py for shared DB connection
- Write a README.md explaining setup and usage
- DO NOT truncate any file — write complete implementations for every module
- DO NOT use placeholder comments like "# TODO: implement" — write real code
- DO NOT skip error handling — every DB operation needs try/except
- Target Python 3.11+