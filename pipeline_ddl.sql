-- pipeline_ddl.sql
-- BroyhillGOP Ingestion Pipeline — DDL
-- Generated from docs/INGESTION_PIPELINE_MASTER_PLAN.md Section 2 (Pipeline Schema)
-- DO NOT RUN until reviewed. Execute via MCP when approved.
--
-- Pre-run: pipeline.ingestion_jobs, pipeline.batch_manifest, pipeline.person_groups
-- exist (prior incomplete install, zero rows). Safe to drop and recreate.
-- archive schema exists with 4 old backup tables — not touched; archive_log uses
-- CREATE TABLE IF NOT EXISTS.

-- =============================================================================
-- 0. DROP EXISTING PIPELINE OBJECTS (clean recreate)
-- =============================================================================
DROP VIEW IF EXISTS pipeline.vw_job_status;
DROP VIEW IF EXISTS pipeline.vw_identity_status;
DROP TABLE IF EXISTS pipeline.ingestion_batches CASCADE;
DROP TABLE IF EXISTS pipeline.ingestion_errors CASCADE;
DROP TABLE IF EXISTS pipeline.ingestion_jobs CASCADE;
DROP TABLE IF EXISTS pipeline.batch_manifest CASCADE;   -- old name; master plan uses file_manifest
DROP TABLE IF EXISTS pipeline.file_manifest CASCADE;
DROP TABLE IF EXISTS pipeline.person_groups CASCADE;    -- leftover, not in master plan
DROP TABLE IF EXISTS pipeline.source_schemas CASCADE;
DROP TABLE IF EXISTS pipeline.dedup_rules CASCADE;
DROP TABLE IF EXISTS pipeline.source_quality_rules CASCADE;
DROP TABLE IF EXISTS pipeline.norm_readiness_rules CASCADE;
DROP TABLE IF EXISTS pipeline.canary_checks CASCADE;
DROP TABLE IF EXISTS pipeline.expected_indexes CASCADE;
DROP TABLE IF EXISTS pipeline.identity_pass_log CASCADE;

-- =============================================================================
-- 1. SCHEMAS
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS pipeline;
CREATE SCHEMA IF NOT EXISTS archive;

-- =============================================================================
-- 2. JOB AND BATCH TRACKING (2.1)
-- =============================================================================

CREATE TABLE pipeline.ingestion_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_type TEXT,
    source_system TEXT,
    file_path TEXT,
    file_hash_sha256 TEXT,
    file_size_bytes BIGINT,
    row_count_estimate BIGINT,
    status TEXT,
    manifest_id UUID,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    last_error TEXT,
    approved_by TEXT
);

COMMENT ON TABLE pipeline.ingestion_jobs IS 'Job tracking: ARCHIVE_AND_RESET, ingest_nc_boe, ingest_fec_schedule_a, etc.';

CREATE TABLE pipeline.ingestion_batches (
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES pipeline.ingestion_jobs(job_id) ON DELETE CASCADE,
    batch_number INT,
    offset_start BIGINT,
    offset_end BIGINT,
    status TEXT,
    rows_read INT,
    rows_inserted INT,
    rows_duplicate_within_file INT,
    rows_duplicate_vs_raw INT,
    amount_sum_file NUMERIC,
    amount_sum_db NUMERIC,
    error_message TEXT,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ingestion_batches_job_id ON pipeline.ingestion_batches(job_id);

CREATE TABLE pipeline.ingestion_errors (
    id BIGSERIAL PRIMARY KEY,
    job_id UUID,
    batch_id UUID,
    row_offset BIGINT,
    error_type TEXT,
    error_message TEXT,
    sample_data JSONB
);

CREATE INDEX IF NOT EXISTS idx_ingestion_errors_job_id ON pipeline.ingestion_errors(job_id);

-- =============================================================================
-- 3. FILE MANIFEST (2.2)
-- =============================================================================

CREATE TABLE pipeline.file_manifest (
    manifest_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_system TEXT,
    file_pattern TEXT,
    expected_row_count BIGINT,
    expected_amount_total NUMERIC,
    expected_date_range_start DATE,
    expected_date_range_end DATE,
    status TEXT,
    dry_run_job_id UUID,
    approved_at TIMESTAMPTZ,
    approved_by TEXT
);

-- FK: ingestion_jobs.manifest_id -> file_manifest (add after both exist)
ALTER TABLE pipeline.ingestion_jobs
    DROP CONSTRAINT IF EXISTS fk_ingestion_jobs_manifest_id;
ALTER TABLE pipeline.ingestion_jobs
    ADD CONSTRAINT fk_ingestion_jobs_manifest_id
    FOREIGN KEY (manifest_id) REFERENCES pipeline.file_manifest(manifest_id);

-- =============================================================================
-- 4. SCHEMA AND DEDUP REGISTRY (2.3)
-- =============================================================================

CREATE TABLE pipeline.source_schemas (
    id BIGSERIAL PRIMARY KEY,
    source_system TEXT NOT NULL,
    version TEXT NOT NULL,
    valid_from DATE,
    valid_to DATE,
    column_name TEXT NOT NULL,
    position INT,
    data_type TEXT,
    nullable BOOLEAN
);

CREATE INDEX IF NOT EXISTS idx_source_schemas_source_version ON pipeline.source_schemas(source_system, version);

CREATE TABLE pipeline.dedup_rules (
    source_system TEXT PRIMARY KEY,
    dedup_function_name TEXT NOT NULL,
    notes TEXT
);

-- =============================================================================
-- 5. QUALITY AND READINESS RULES (2.4)
-- =============================================================================

CREATE TABLE pipeline.source_quality_rules (
    source_system TEXT NOT NULL,
    rule_name TEXT NOT NULL,
    rule_sql_condition TEXT,
    severity TEXT,
    description TEXT,
    PRIMARY KEY (source_system, rule_name)
);

CREATE TABLE pipeline.norm_readiness_rules (
    source_system TEXT NOT NULL,
    column_name TEXT NOT NULL,
    min_non_null_pct NUMERIC NOT NULL,
    notes TEXT,
    PRIMARY KEY (source_system, column_name)
);

-- =============================================================================
-- 6. CANARY CHECKS (2.5)
-- =============================================================================

CREATE TABLE pipeline.canary_checks (
    check_name TEXT NOT NULL,
    phase TEXT NOT NULL,
    query_sql TEXT,
    expected_min_rows INT,
    severity TEXT,
    PRIMARY KEY (check_name, phase)
);

-- =============================================================================
-- 7. ARCHIVE LOG (2.6)
-- =============================================================================

CREATE TABLE IF NOT EXISTS archive.archive_log (
    id BIGSERIAL PRIMARY KEY,
    source_schema TEXT NOT NULL,
    source_table TEXT NOT NULL,
    archive_table TEXT NOT NULL,
    archived_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    row_count BIGINT NOT NULL,
    job_id UUID
);

CREATE INDEX IF NOT EXISTS idx_archive_log_job_id ON archive.archive_log(job_id);

-- =============================================================================
-- 8. INDEX VERIFICATION (2.7)
-- =============================================================================

CREATE TABLE pipeline.expected_indexes (
    table_name TEXT NOT NULL,
    index_name TEXT NOT NULL,
    PRIMARY KEY (table_name, index_name)
);

-- =============================================================================
-- 9. IDENTITY PASS LOG (backing table for vw_identity_status)
-- =============================================================================

CREATE TABLE pipeline.identity_pass_log (
    pass_name TEXT PRIMARY KEY,
    status TEXT,
    rows_matched BIGINT,
    rows_remaining BIGINT,
    last_run_at TIMESTAMPTZ
);

-- =============================================================================
-- 10. STORED PROCEDURES / FUNCTIONS
-- =============================================================================

-- 10.1 employer_normalize(employer_raw TEXT) — §6.1
-- Strip legal suffixes; collapse whitespace; trim.
CREATE OR REPLACE FUNCTION pipeline.employer_normalize(employer_raw TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT TRIM(REGEXP_REPLACE(
        REGEXP_REPLACE(
            COALESCE(employer_raw, ''),
            '\s*(Inc\.?|LLC|L\.L\.C\.?|Co\.?|Corp\.?|Corporation|Company|Ltd\.?|Limited)\s*$',
            '',
            'i'
        ),
        '\s+', ' ', 'g'
    ));
$$;

-- 10.2 dedup_key_ncboe — §5.3
-- Deterministic key from last_name, first_name, committee_name, contribution_date, amount.
CREATE OR REPLACE FUNCTION pipeline.dedup_key_ncboe(
    p_last_name TEXT,
    p_first_name TEXT,
    p_committee_name TEXT,
    p_contribution_date DATE,
    p_amount NUMERIC,
    p_report_id TEXT DEFAULT NULL,
    p_line_number TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT MD5(
        UPPER(TRIM(COALESCE(p_last_name, ''))) || '|' ||
        UPPER(TRIM(COALESCE(p_first_name, ''))) || '|' ||
        UPPER(TRIM(COALESCE(p_committee_name, ''))) || '|' ||
        COALESCE(p_contribution_date::TEXT, '') || '|' ||
        COALESCE(p_amount::TEXT, '') || '|' ||
        COALESCE(p_report_id, '') || '|' ||
        COALESCE(p_line_number, '')
    );
$$;

-- 10.2b dedup_key_fec_individual — §5.3, Master Plan (FEC Schedule A)
-- Deterministic key for transaction-level dedup: same report line / donor+committee+date+amount.
-- Staging tables should have dedup_key set by this function (or equivalent).
CREATE OR REPLACE FUNCTION pipeline.dedup_key_fec_individual(
    p_contributor_last_name TEXT,
    p_contributor_first_name TEXT,
    p_contributor_zip TEXT,
    p_committee_id TEXT,
    p_contribution_receipt_amount NUMERIC,
    p_contribution_receipt_date DATE,
    p_report_id TEXT DEFAULT NULL,
    p_line_number TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT MD5(
        UPPER(TRIM(COALESCE(p_contributor_last_name, ''))) || '|' ||
        UPPER(TRIM(COALESCE(p_contributor_first_name, ''))) || '|' ||
        UPPER(TRIM(COALESCE(p_contributor_zip, ''))) || '|' ||
        UPPER(TRIM(COALESCE(p_committee_id, ''))) || '|' ||
        COALESCE(p_contribution_receipt_amount::TEXT, '') || '|' ||
        COALESCE(p_contribution_receipt_date::TEXT, '') || '|' ||
        COALESCE(p_report_id, '') || '|' ||
        COALESCE(p_line_number, '')
    );
$$;

-- 10.3 job_cleanup(job_id) — §4.3
-- Updates batches to rolled_back, job to failed. Raw table DELETE is orchestrator responsibility
-- (requires source_system -> raw table mapping; not in schema).
CREATE OR REPLACE FUNCTION pipeline.job_cleanup(p_job_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE pipeline.ingestion_batches
    SET status = 'rolled_back'
    WHERE job_id = p_job_id;
    UPDATE pipeline.ingestion_jobs
    SET status = 'failed'
    WHERE job_id = p_job_id;
END;
$$;

-- 10.4 verify_indexes(table_name) — §2.7
-- Returns TRUE if all expected indexes exist for the table.
CREATE OR REPLACE FUNCTION pipeline.verify_indexes(p_table_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_missing INT;
BEGIN
    SELECT COUNT(*) INTO v_missing
    FROM pipeline.expected_indexes ei
    WHERE ei.table_name = p_table_name
    AND NOT EXISTS (
        SELECT 1 FROM pg_indexes pi
        WHERE pi.tablename = ei.table_name
        AND pi.indexname = ei.index_name
    );
    RETURN v_missing = 0;
END;
$$;

-- =============================================================================
-- 11. VIEWS (2.8)
-- =============================================================================

CREATE OR REPLACE VIEW pipeline.vw_job_status AS
SELECT
    j.job_id,
    j.job_type,
    j.source_system,
    j.status,
    (SELECT COUNT(*) FROM pipeline.ingestion_batches b WHERE b.job_id = j.job_id) AS batches_total,
    (SELECT COUNT(*) FROM pipeline.ingestion_batches b WHERE b.job_id = j.job_id AND b.status = 'completed') AS batches_completed,
    CASE
        WHEN (SELECT COUNT(*) FROM pipeline.ingestion_batches b WHERE b.job_id = j.job_id) = 0
        THEN 0
        ELSE 100.0 * (SELECT COUNT(*) FROM pipeline.ingestion_batches b WHERE b.job_id = j.job_id AND b.status = 'completed')
             / NULLIF((SELECT COUNT(*) FROM pipeline.ingestion_batches b WHERE b.job_id = j.job_id), 0)
    END::NUMERIC(5,2) AS pct_complete,
    (SELECT COALESCE(SUM(rows_inserted), 0) FROM pipeline.ingestion_batches b WHERE b.job_id = j.job_id) AS rows_loaded,
    j.last_error,
    j.started_at,
    j.finished_at,
    'OK'::TEXT AS index_status  -- placeholder; orchestrator can update based on pipeline.verify_indexes()
FROM pipeline.ingestion_jobs j
ORDER BY j.started_at DESC NULLS LAST;

CREATE OR REPLACE VIEW pipeline.vw_identity_status AS
SELECT
    pass_name,
    status,
    rows_matched,
    rows_remaining,
    last_run_at
FROM pipeline.identity_pass_log
ORDER BY last_run_at DESC NULLS LAST;

-- =============================================================================
-- END
-- =============================================================================
