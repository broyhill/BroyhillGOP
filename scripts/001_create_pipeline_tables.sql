-- NCBOE + NCGOP Pipeline — Full DDL
-- Run: psql "$SUPABASE_DB_URL" -f scripts/001_create_pipeline_tables.sql
--
-- Table names MUST match Python scripts (WITH underscores):
--   nc_voters, nc_boe_donations_raw, nc_data_committee.donors, nc_data_committee.contributions
-- NOT: ncvoters, ncboe_donations_raw, ncdatacommittee (those are wrong)

-- =============================================================================
-- SCHEMAS
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS norm;
CREATE SCHEMA IF NOT EXISTS nc_data_committee;
CREATE SCHEMA IF NOT EXISTS pipeline;

-- =============================================================================
-- 1. public.nc_voters — NC voter registration file (~9M rows)
-- Columns for matching: statevoterid, last_name, first_name, zip_code, res_city_desc
-- Load your NCSBE voter file; map voter_reg_num → statevoterid if needed
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.nc_voters (
    statevoterid VARCHAR(50) PRIMARY KEY,
    voter_reg_num VARCHAR(50),
    last_name VARCHAR(255),
    first_name VARCHAR(255),
    canonical_first_name TEXT,
    zip_code VARCHAR(20),
    res_city_desc VARCHAR(100),
    mail_city VARCHAR(100),
    mail_zipcode VARCHAR(20),
    voter_status_desc VARCHAR(100),
    voter_status_reason_desc VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS idx_nc_voters_last_first_zip 
  ON public.nc_voters (LOWER(last_name), LOWER(first_name), zip_code);
CREATE INDEX IF NOT EXISTS idx_nc_voters_last_first_city 
  ON public.nc_voters (LOWER(last_name), LOWER(first_name), LOWER(res_city_desc));

-- =============================================================================
-- 2. public.nc_boe_donations_raw — NCBOE contribution data
-- Populated by import_ncboe_raw.py or bulk load from NCBOE CSVs
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.nc_boe_donations_raw (
    id BIGSERIAL PRIMARY KEY,
    donor_name VARCHAR(500),
    street_line_1 VARCHAR(255),
    street_line_2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(10),
    zip_code VARCHAR(20),
    profession_job_title VARCHAR(255),
    employer_name VARCHAR(255),
    transaction_type VARCHAR(50) DEFAULT 'Individual',
    committee_name VARCHAR(255),
    committee_sboe_id VARCHAR(50),
    date_occured_raw VARCHAR(50),
    amount_raw VARCHAR(50),
    amount_numeric NUMERIC(12,2),
    date_occurred DATE,
    form_of_payment VARCHAR(100),
    purpose TEXT,
    source_file VARCHAR(255),
    loaded_at TIMESTAMPTZ DEFAULT now(),
    -- Pre-computed by previous pipeline (normalize reads these)
    norm_last VARCHAR(255),
    norm_first VARCHAR(255),
    norm_addr VARCHAR(500),
    norm_zip5 VARCHAR(10),
    norm_city VARCHAR(100),
    norm_state VARCHAR(2)
);

CREATE INDEX IF NOT EXISTS idx_ncboe_raw_source_donor_amount_date 
  ON public.nc_boe_donations_raw (source_file, donor_name, amount_numeric, date_occurred);

-- =============================================================================
-- 3. norm.nc_boe_donations — Normalized NCBOE (output of normalize_ncboe.py)
-- =============================================================================
CREATE TABLE IF NOT EXISTS norm.nc_boe_donations (
    id BIGSERIAL PRIMARY KEY,
    raw_donor_name VARCHAR(500),
    raw_street_1 VARCHAR(255),
    raw_street_2 VARCHAR(255),
    norm_street VARCHAR(500),
    norm_city VARCHAR(100),
    norm_state VARCHAR(2),
    norm_zip5 VARCHAR(10),
    norm_last VARCHAR(255),
    norm_first VARCHAR(255),
    employer_raw VARCHAR(255),
    amount NUMERIC(12,2),
    transaction_date DATE,
    transaction_type VARCHAR(50),
    form_of_payment VARCHAR(100),
    purpose TEXT,
    committee_sboe_id VARCHAR(50),
    committee_name VARCHAR(255),
    source_file VARCHAR(255),
    dedup_key VARCHAR(255),
    statevoterid VARCHAR(50),
    normalized_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_norm_ncboe_dedup_key ON norm.nc_boe_donations (dedup_key);
CREATE INDEX IF NOT EXISTS idx_norm_ncboe_statevoterid ON norm.nc_boe_donations (statevoterid);

-- =============================================================================
-- 4. staging.ncgop_winred — NCGOP WinRed staging (import_ncgop_staging.py)
-- =============================================================================
CREATE TABLE IF NOT EXISTS staging.ncgop_winred (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(10),
    zip5 VARCHAR(10),
    zip9 VARCHAR(15),
    employer VARCHAR(255),
    occupation VARCHAR(255),
    amount NUMERIC(12,2),
    contribution_date DATE,
    statevoterid VARCHAR(50),
    source_file VARCHAR(255),
    loaded_at TIMESTAMPTZ DEFAULT now(),
    file_hash VARCHAR(64) UNIQUE
);

-- =============================================================================
-- 5. nc_data_committee.donors — Golden donor records (build_donor_golden_records.py)
-- =============================================================================
CREATE TABLE IF NOT EXISTS nc_data_committee.donors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email_primary VARCHAR(255),
    phone_mobile VARCHAR(50),
    voter_id VARCHAR(50),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(10),
    zip VARCHAR(10),
    employer VARCHAR(255),
    dedup_key VARCHAR(255),
    source VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_donors_dedup_key ON nc_data_committee.donors (dedup_key);

-- =============================================================================
-- 6. nc_data_committee.contributions — Linked contributions (build_contributions.py)
-- =============================================================================
CREATE TABLE IF NOT EXISTS nc_data_committee.contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL REFERENCES nc_data_committee.donors(id),
    norm_id BIGINT NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    transaction_date DATE,
    committee_sboe_id VARCHAR(50),
    committee_name VARCHAR(255),
    source_file VARCHAR(255),
    source VARCHAR(50) DEFAULT 'ncboe',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(norm_id)
);

-- =============================================================================
-- 7. pipeline.loaded_ncboe_files — SHA-256 idempotency for NCBOE imports
-- =============================================================================
CREATE TABLE IF NOT EXISTS pipeline.loaded_ncboe_files (
    file_hash VARCHAR(64) PRIMARY KEY,
    source_file VARCHAR(255),
    loaded_at TIMESTAMPTZ DEFAULT now(),
    row_count INT
);
