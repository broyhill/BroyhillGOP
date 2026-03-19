-- pipeline/nc_boe_ddl_rollback.sql
-- Full teardown — run to reverse nc_boe_ddl.sql
-- Source: docs/NCBOE_INGESTION_PIPELINE_MASTER_PLAN_V2.md

DROP TABLE IF EXISTS staging.ncboe_committee_transfers CASCADE;
DROP TABLE IF EXISTS staging.ncboe_archive CASCADE;
DROP TABLE IF EXISTS core.ncboe_committee_registry CASCADE;
DROP TABLE IF EXISTS core.ncboe_committee_type_lookup CASCADE;
DROP TABLE IF EXISTS core.ncboe_donations_processed CASCADE;
DROP FUNCTION IF EXISTS pipeline.parse_ncboe_name(TEXT);
DROP FUNCTION IF EXISTS pipeline.content_hash_ncboe(TEXT,TEXT,TEXT,DATE,NUMERIC);
DROP FUNCTION IF EXISTS pipeline.dedup_key_ncboe(TEXT,BIGINT);
DROP FUNCTION IF EXISTS pipeline.dedup_key_ncboe(TEXT,TEXT);
DROP FUNCTION IF EXISTS pipeline.employer_normalize_ncboe(TEXT);
