-- 063_NCBOE_GENERAL_FUND_INGESTION.sql
-- One-time load of General Fund donations (178,682 rows / ~$402M)
-- Per Cursor-General-Fund-Ingestion-Instructions.docx
--
-- Run from project root: psql $DATABASE_URL -f database/migrations/063_NCBOE_GENERAL_FUND_INGESTION.sql
-- CSVs: 2015-2020-ncboe-general-funds.csv, 2020-2026-ncboe-donors-general-fund.csv

-- Part 1: Create staging (must commit so Python can see it)
BEGIN;
CREATE SCHEMA IF NOT EXISTS staging;

-- =============================================================================
-- Step 1: Create staging table (matches NC BOE TransInq 24-column format)
-- =============================================================================
CREATE TABLE IF NOT EXISTS staging.staging_general_fund (
    donor_name TEXT,
    street_line_1 TEXT,
    street_line_2 TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    profession_job_title TEXT,
    employer_name TEXT,
    transaction_type TEXT,
    committee_name TEXT,
    committee_sboe_id TEXT,
    committee_street_1 TEXT,
    committee_street_2 TEXT,
    committee_city TEXT,
    committee_state TEXT,
    committee_zip_code TEXT,
    report_name TEXT,
    date_occured_raw TEXT,
    account_code TEXT,
    amount_raw TEXT,
    form_of_payment TEXT,
    purpose TEXT,
    candidate_referendum_name TEXT,
    declaration TEXT,
    source_file TEXT
);

TRUNCATE staging.staging_general_fund;
COMMIT;

-- Step 2 & 3: Load both CSVs via Python (handles quoted commas, variable rows)
\echo 'Loading CSVs via Python...'
\! python3 scripts/load_general_fund_csv.py

-- Part 2: Process staging and insert into nc_boe_donations_raw
BEGIN;

-- =============================================================================
-- Step 4: Add parsed columns and deduplicate staging
-- =============================================================================
ALTER TABLE staging.staging_general_fund ADD COLUMN IF NOT EXISTS amount_numeric NUMERIC(12,2);
ALTER TABLE staging.staging_general_fund ADD COLUMN IF NOT EXISTS date_occurred DATE;

UPDATE staging.staging_general_fund
SET
    amount_numeric = NULLIF(REGEXP_REPLACE(TRIM(COALESCE(amount_raw, '')), '[^0-9.]', '', 'g')::NUMERIC, 0),
    date_occurred = CASE
        WHEN TRIM(COALESCE(date_occured_raw, '')) ~ '^\d{1,2}/\d{1,2}/\d{4}$'
        THEN to_date(TRIM(date_occured_raw), 'MM/DD/YYYY')
        WHEN TRIM(COALESCE(date_occured_raw, '')) ~ '^\d{4}-\d{2}-\d{2}$'
        THEN to_date(TRIM(date_occured_raw), 'YYYY-MM-DD')
        ELSE NULL
    END;

-- Deduplicate: keep one row per (donor_name, committee_sboe_id, date_occurred, amount_numeric)
DELETE FROM staging.staging_general_fund a
USING staging.staging_general_fund b
WHERE a.ctid > b.ctid
  AND COALESCE(a.donor_name, '') = COALESCE(b.donor_name, '')
  AND COALESCE(a.committee_sboe_id, '') = COALESCE(b.committee_sboe_id, '')
  AND a.date_occurred IS NOT DISTINCT FROM b.date_occurred
  AND a.amount_numeric IS NOT DISTINCT FROM b.amount_numeric;

-- =============================================================================
-- Step 5: Drop non-PK indexes on nc_boe_donations_raw (for faster INSERT)
-- =============================================================================
\echo 'Dropping non-PK indexes on nc_boe_donations_raw...'
DROP INDEX IF EXISTS public.idx_boe_amount_numeric;
DROP INDEX IF EXISTS public.idx_boe_city;
DROP INDEX IF EXISTS public.idx_boe_committee_name;
DROP INDEX IF EXISTS public.idx_boe_committee_sboe_id;
DROP INDEX IF EXISTS public.idx_boe_date_occurred;
DROP INDEX IF EXISTS public.idx_boe_donor_name;
DROP INDEX IF EXISTS public.idx_boe_donor_name_trgm;
DROP INDEX IF EXISTS public.idx_boe_employer;
DROP INDEX IF EXISTS public.idx_boe_norm_first_last;
DROP INDEX IF EXISTS public.idx_boe_norm_last;
DROP INDEX IF EXISTS public.idx_boe_norm_last_first_zip;
DROP INDEX IF EXISTS public.idx_boe_norm_last_zip;
DROP INDEX IF EXISTS public.idx_boe_source_file;
DROP INDEX IF EXISTS public.idx_boe_state;
DROP INDEX IF EXISTS public.idx_boe_transaction_type;
DROP INDEX IF EXISTS public.idx_boe_zip5;
DROP INDEX IF EXISTS public.idx_donations_match;
DROP INDEX IF EXISTS public.idx_nc_boe_dedup_key_null;
DROP INDEX IF EXISTS public.idx_ncboe_content_hash;
DROP INDEX IF EXISTS public.idx_ncboe_dedup_block;
DROP INDEX IF EXISTS public.idx_ncboe_dedup_key;
DROP INDEX IF EXISTS public.idx_ncboe_norm_addr;
DROP INDEX IF EXISTS public.idx_ncboe_norm_last;
DROP INDEX IF EXISTS public.idx_ncboe_norm_last_first;
DROP INDEX IF EXISTS public.idx_ncboe_norm_match;
DROP INDEX IF EXISTS public.idx_ncboe_norm_zip5;
DROP INDEX IF EXISTS public.idx_ncboe_raw_source_donor_amount_date;

-- =============================================================================
-- Step 6: INSERT into nc_boe_donations_raw (skip rows that already exist by content_hash)
-- =============================================================================
\echo 'Inserting into nc_boe_donations_raw (content_hash dedup)...'

-- Ensure donor_type and is_organization columns exist
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS donor_type TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS is_organization BOOLEAN;

INSERT INTO public.nc_boe_donations_raw (
    donor_name, street_line_1, street_line_2, city, state, zip_code,
    profession_job_title, employer_name, transaction_type, committee_name,
    committee_sboe_id, committee_street_1, committee_street_2,
    committee_city, committee_state, committee_zip_code, report_name,
    date_occured_raw, account_code, amount_raw, amount_numeric, date_occurred,
    form_of_payment, purpose, candidate_referendum_name, declaration,
    source_file
)
SELECT
    s.donor_name, s.street_line_1, s.street_line_2, s.city, s.state, s.zip_code,
    s.profession_job_title, s.employer_name, s.transaction_type, s.committee_name,
    s.committee_sboe_id, s.committee_street_1, s.committee_street_2,
    s.committee_city, s.committee_state, s.committee_zip_code, s.report_name,
    s.date_occured_raw, s.account_code, s.amount_raw, s.amount_numeric, s.date_occurred,
    s.form_of_payment, s.purpose, s.candidate_referendum_name, s.declaration,
    s.source_file
FROM staging.staging_general_fund s
WHERE s.amount_numeric IS NOT NULL
  AND s.date_occurred IS NOT NULL
  AND s.committee_sboe_id IS NOT NULL
  AND TRIM(COALESCE(s.committee_sboe_id, '')) != ''
  AND NOT EXISTS (
      SELECT 1 FROM public.nc_boe_donations_raw r
      WHERE r.donor_name IS NOT DISTINCT FROM s.donor_name
        AND r.committee_sboe_id IS NOT DISTINCT FROM s.committee_sboe_id
        AND r.date_occurred IS NOT DISTINCT FROM s.date_occurred
        AND r.amount_numeric IS NOT DISTINCT FROM s.amount_numeric
  );

-- Dedup by (donor_name, committee_sboe_id, date_occurred, amount_numeric) to avoid re-inserting
-- rows already loaded from a previous run. content_hash is computed by norm ETL after insert.

-- =============================================================================
-- Step 7: Normalize Individual/General rows (person types) — run via norm ETL
-- Step 8: Set is_organization for org types — run via norm ETL
-- (Handled by updated norm_etl_ncboe.py)
-- =============================================================================

-- =============================================================================
-- Step 9: Rebuild indexes
-- =============================================================================
\echo 'Rebuilding indexes...'
CREATE INDEX IF NOT EXISTS idx_boe_amount_numeric ON public.nc_boe_donations_raw (amount_numeric);
CREATE INDEX IF NOT EXISTS idx_boe_city ON public.nc_boe_donations_raw (city);
CREATE INDEX IF NOT EXISTS idx_boe_committee_name ON public.nc_boe_donations_raw (committee_name);
CREATE INDEX IF NOT EXISTS idx_boe_committee_sboe_id ON public.nc_boe_donations_raw (committee_sboe_id);
CREATE INDEX IF NOT EXISTS idx_boe_date_occurred ON public.nc_boe_donations_raw (date_occurred);
CREATE INDEX IF NOT EXISTS idx_boe_donor_name ON public.nc_boe_donations_raw (donor_name);
CREATE INDEX IF NOT EXISTS idx_boe_source_file ON public.nc_boe_donations_raw (source_file);
CREATE INDEX IF NOT EXISTS idx_boe_state ON public.nc_boe_donations_raw (state);
CREATE INDEX IF NOT EXISTS idx_boe_transaction_type ON public.nc_boe_donations_raw (transaction_type);
CREATE INDEX IF NOT EXISTS idx_ncboe_raw_source_donor_amount_date ON public.nc_boe_donations_raw (source_file, donor_name, amount_numeric, date_occurred);

ANALYZE public.nc_boe_donations_raw;

-- =============================================================================
-- Step 10: Validation queries (run manually to verify)
-- =============================================================================
\echo ''
\echo '--- Validation: Row counts ---'
SELECT source_file, COUNT(*) FROM public.nc_boe_donations_raw GROUP BY source_file ORDER BY source_file;

\echo ''
\echo '--- Validation: Art Pope (expect ~157 txns / ~$1,156,519) ---'
SELECT COUNT(*), SUM(amount_numeric) FROM public.nc_boe_donations_raw
WHERE UPPER(donor_name) LIKE '%POPE%' AND UPPER(donor_name) LIKE '%ART%';

\echo ''
\echo '--- Validation: Transaction type breakdown ---'
SELECT transaction_type, COUNT(*), SUM(amount_numeric) FROM public.nc_boe_donations_raw
GROUP BY transaction_type ORDER BY COUNT(*) DESC;

-- =============================================================================
-- Step 12: DROP staging (optional — keep for audit, then drop)
-- =============================================================================
-- DROP TABLE IF EXISTS staging.staging_general_fund;

COMMIT;

\echo ''
\echo 'General Fund ingestion complete. Run: python3 -m pipeline.norm_etl_ncboe'
