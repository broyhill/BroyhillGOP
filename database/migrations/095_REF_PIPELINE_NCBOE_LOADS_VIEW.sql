-- 095_REF_PIPELINE_NCBOE_LOADS_VIEW.sql
-- Inspect NCBOE file loads (hash idempotency registry).
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/095_REF_PIPELINE_NCBOE_LOADS_VIEW.sql

CREATE SCHEMA IF NOT EXISTS ref;

CREATE OR REPLACE VIEW ref.v_pipeline_ncboe_loads AS
SELECT
  file_hash,
  source_file,
  loaded_at,
  row_count
FROM pipeline.loaded_ncboe_files;

COMMENT ON VIEW ref.v_pipeline_ncboe_loads IS
  'NCBOE raw loads from import_ncboe_raw.py. Query: SELECT * FROM ref.v_pipeline_ncboe_loads ORDER BY loaded_at DESC;';
