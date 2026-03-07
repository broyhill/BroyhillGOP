-- pipeline/seed_fec_2015_2016.sql
-- Seed pipeline control tables for FEC 2015_2016 source.
-- Staging table: public.fec_2015_2016_a_staging
--
-- Run: psql $DATABASE_URL -f pipeline/seed_fec_2015_2016.sql
-- Or execute via Supabase SQL editor.

-- Ensure fuzzystrmatch for dedup dmetaphone
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

-- -----------------------------------------------------------------------------
-- 1. SOURCE QUALITY RULES (fec)
-- rule_sql_condition: returns count of VIOLATING rows (rows that fail the rule).
-- {staging_table} is replaced by ingest with schema.table identifier.
-- committee_id is the critical join key; rows without it are useless.
-- -----------------------------------------------------------------------------
INSERT INTO pipeline.source_quality_rules
  (source_system, rule_name, rule_sql_condition, severity, description)
VALUES
  ('fec', 'require_committee_id',
   'SELECT COUNT(*) FROM {staging_table} WHERE committee_id IS NULL OR TRIM(COALESCE(committee_id::TEXT, '''')) = ''''',
   'fatal', 'committee_id required (critical join key)'),
  ('fec', 'require_contributor_last_name',
   'SELECT COUNT(*) FROM {staging_table} WHERE contributor_last_name IS NULL OR TRIM(COALESCE(contributor_last_name, '''')) = ''''',
   'fatal', 'contributor_last_name required (for dedup)'),
  ('fec', 'require_contribution_amount',
   'SELECT COUNT(*) FROM {staging_table} WHERE contribution_receipt_amount IS NULL OR contribution_receipt_amount::TEXT = ''''',
   'fatal', 'contribution_receipt_amount required'),
  ('fec', 'require_contributor_zip',
   'SELECT COUNT(*) FROM {staging_table} WHERE contributor_zip IS NULL OR TRIM(COALESCE(contributor_zip, '''')) = ''''',
   'fatal', 'contributor_zip required'),
  ('fec', 'require_contributor_state',
   'SELECT COUNT(*) FROM {staging_table} WHERE contributor_state IS NULL OR TRIM(COALESCE(contributor_state, '''')) = ''''',
   'fatal', 'contributor_state required to verify NC filter'),
  ('fec', 'require_entity_type',
   'SELECT COUNT(*) FROM {staging_table} WHERE entity_type IS NULL AND entity_type_desc IS NULL',
   'warn', 'entity_type or entity_type_desc recommended for filtering')
ON CONFLICT (source_system, rule_name) DO UPDATE SET
  rule_sql_condition = EXCLUDED.rule_sql_condition,
  severity = EXCLUDED.severity,
  description = EXCLUDED.description;

-- -----------------------------------------------------------------------------
-- 2. NORM READINESS RULES (fec)
-- min_non_null_pct: column must have >= this % non-null. Based on actual data
-- (has_last 99.93%, zip 100%, amount ~99%).
-- -----------------------------------------------------------------------------
INSERT INTO pipeline.norm_readiness_rules
  (source_system, column_name, min_non_null_pct, notes)
VALUES
  ('fec', 'contributor_last_name', 99.5, 'Last name for dedup/match (actual ~99.93%%)'),
  ('fec', 'contributor_zip', 99, 'Zip for dedup/match'),
  ('fec', 'contribution_receipt_amount', 99, 'Amount required for totals')
ON CONFLICT (source_system, column_name) DO UPDATE SET
  min_non_null_pct = EXCLUDED.min_non_null_pct,
  notes = EXCLUDED.notes;

-- -----------------------------------------------------------------------------
-- 3. DEDUP RULES (fec)
-- exact: last_name + zip5; fuzzy: first_name via dmetaphone.
-- notes JSON: weights, columns.
-- -----------------------------------------------------------------------------
INSERT INTO pipeline.dedup_rules
  (source_system, dedup_function_name, notes)
VALUES
  ('fec', 'fec_last_zip_first_dmetaphone',
   '{"weights": {"exact": 1.0, "fuzzy": 0.85}, "columns": {"last_name": "contributor_last_name", "zip": "contributor_zip", "first_name": "contributor_first_name"}}')
ON CONFLICT (source_system) DO UPDATE SET
  dedup_function_name = EXCLUDED.dedup_function_name,
  notes = EXCLUDED.notes;

-- -----------------------------------------------------------------------------
-- 4. IDENTITY_CLUSTERS (dedup writes here; not in pipeline_ddl.sql)
-- Full column list for pipeline.identity_clusters:
--   cluster_id       UUID PRIMARY KEY DEFAULT gen_random_uuid()
--   source_system    TEXT NOT NULL
--   staging_schema   TEXT NOT NULL
--   staging_table    TEXT NOT NULL
--   cluster_key      TEXT NOT NULL
--   member_count     INT NOT NULL
--   member_refs      JSONB
--   match_score_avg  NUMERIC
--   status           TEXT DEFAULT 'pending_review'
--   created_at       TIMESTAMPTZ DEFAULT NOW()
-- person_id / source linkage filled later by identity passes (Master Plan §7).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pipeline.identity_clusters (
    cluster_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_system TEXT NOT NULL,
    staging_schema TEXT NOT NULL,
    staging_table TEXT NOT NULL,
    cluster_key TEXT NOT NULL,
    member_count INT NOT NULL,
    member_refs JSONB,
    match_score_avg NUMERIC,
    status TEXT DEFAULT 'pending_review',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 5. AUDIT COLUMNS ON STAGING (Master Plan 4.7 — mandatory)
-- -----------------------------------------------------------------------------
ALTER TABLE public.fec_2015_2016_a_staging ADD COLUMN IF NOT EXISTS _job_id UUID;
ALTER TABLE public.fec_2015_2016_a_staging ADD COLUMN IF NOT EXISTS _batch_number INT;
ALTER TABLE public.fec_2015_2016_a_staging ADD COLUMN IF NOT EXISTS _loaded_at TIMESTAMPTZ;
ALTER TABLE public.fec_2015_2016_a_staging ADD COLUMN IF NOT EXISTS _file_hash TEXT;

-- -----------------------------------------------------------------------------
-- 6. EXPECTED INDEXES (cycle-specific: 2015_2016 only)
-- For 2017-2018, add new rows for public.fec_2017_2018_a_staging.
-- -----------------------------------------------------------------------------
ALTER TABLE pipeline.expected_indexes
  ADD COLUMN IF NOT EXISTS index_definition TEXT;

INSERT INTO pipeline.expected_indexes
  (table_name, index_name, index_definition)
VALUES
  ('public.fec_2015_2016_a_staging', 'idx_fec_contrib_last_zip',
   'CREATE INDEX IF NOT EXISTS idx_fec_contrib_last_zip ON public.fec_2015_2016_a_staging (contributor_last_name, contributor_zip)'),
  ('public.fec_2015_2016_a_staging', 'idx_fec_contrib_first',
   'CREATE INDEX IF NOT EXISTS idx_fec_contrib_first ON public.fec_2015_2016_a_staging (contributor_first_name)')
ON CONFLICT (table_name, index_name) DO UPDATE SET
  index_definition = EXCLUDED.index_definition;

-- -----------------------------------------------------------------------------
-- 7. CANARY CHECKS (post-load validation)
-- phase: post_load. query_sql returns single value (row count).
-- -----------------------------------------------------------------------------
INSERT INTO pipeline.canary_checks
  (check_name, phase, query_sql, expected_min_rows, severity)
VALUES
  ('fec_2015_2016_row_count', 'post_load',
   'SELECT COUNT(*)::int FROM public.fec_2015_2016_a_staging',
   1, 'error'),
  ('fec_2015_2016_has_amounts', 'post_load',
   'SELECT COUNT(*)::int FROM public.fec_2015_2016_a_staging WHERE contribution_receipt_amount IS NOT NULL AND contribution_receipt_amount > 0',
   1, 'warn')
ON CONFLICT (check_name, phase) DO UPDATE SET
  query_sql = EXCLUDED.query_sql,
  expected_min_rows = EXCLUDED.expected_min_rows,
  severity = EXCLUDED.severity;
