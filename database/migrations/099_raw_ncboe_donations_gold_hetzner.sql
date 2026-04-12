-- Phase D (April 12, 2026): NCBOE GOLD staging on Hetzner / any Postgres with raw schema.
-- NCBOE CSV headers include intentional typos — columns transction_type / date_occured preserve them.
-- DO NOT correct typos in source files; map headers exactly in pipeline Python.

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.ncboe_donations (
    id BIGSERIAL PRIMARY KEY,
    source_file TEXT NOT NULL,
    -- Original NCBOE columns (snake_case in DB; typos only where NCBOE misspelled)
    name TEXT,
    street_line_1 TEXT,
    street_line_2 TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    profession_job_title TEXT,
    employer_name TEXT,
    transction_type TEXT,       -- NCBOE typo: missing 'a' in Transaction
    committee_name TEXT,
    committee_sboe_id TEXT,
    committee_street_1 TEXT,
    committee_street_2 TEXT,
    committee_city TEXT,
    committee_state TEXT,
    committee_zip_code TEXT,
    report_name TEXT,
    date_occured TEXT,          -- NCBOE typo: missing 'r' in Occurred (stored raw; use norm_date for logic)
    account_code TEXT,
    amount TEXT,
    form_of_payment TEXT,
    purpose TEXT,
    candidate_referendum_name TEXT,
    declaration TEXT,
    -- Enrichment (normalization pipeline)
    norm_last TEXT,
    norm_first TEXT,
    norm_middle TEXT,
    norm_suffix TEXT,
    norm_prefix TEXT,
    norm_nickname TEXT,
    norm_zip5 TEXT,
    norm_city TEXT,
    norm_employer TEXT,
    employer_sic_code TEXT,
    employer_naics_code TEXT,
    norm_amount NUMERIC(12, 2),
    norm_date DATE,
    address_numbers TEXT[],
    all_addresses TEXT[],
    year_donated INTEGER,
    is_unitemized BOOLEAN DEFAULT FALSE,
    -- Dedup (Stage 1)
    cluster_id BIGINT,
    cluster_profile JSONB,
    rnc_regid TEXT,
    match_pass INTEGER,
    match_confidence NUMERIC(5, 2),
    is_matched BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE raw.ncboe_donations IS
'NCBOE GOLD donor CSV staging. Headers Transction Type and Date Occured match NCBOE exports (typos intentional).';

CREATE INDEX IF NOT EXISTS idx_ncboe_name ON raw.ncboe_donations (norm_last, norm_first);
CREATE INDEX IF NOT EXISTS idx_ncboe_zip ON raw.ncboe_donations (norm_zip5);
CREATE INDEX IF NOT EXISTS idx_ncboe_employer ON raw.ncboe_donations (norm_employer);
CREATE INDEX IF NOT EXISTS idx_ncboe_sic ON raw.ncboe_donations (employer_sic_code);
CREATE INDEX IF NOT EXISTS idx_ncboe_committee ON raw.ncboe_donations (committee_sboe_id);
CREATE INDEX IF NOT EXISTS idx_ncboe_date ON raw.ncboe_donations (norm_date);
CREATE INDEX IF NOT EXISTS idx_ncboe_cluster ON raw.ncboe_donations (cluster_id);
CREATE INDEX IF NOT EXISTS idx_ncboe_rnc ON raw.ncboe_donations (rnc_regid);
CREATE INDEX IF NOT EXISTS idx_ncboe_source ON raw.ncboe_donations (source_file);
CREATE INDEX IF NOT EXISTS idx_ncboe_candidate ON raw.ncboe_donations (candidate_referendum_name);
CREATE INDEX IF NOT EXISTS idx_ncboe_last_zip ON raw.ncboe_donations (norm_last, norm_zip5);

-- Optional: local copy of employer → SIC (pg_dump from Supabase donor_intelligence.employer_sic_master when authorized)
CREATE SCHEMA IF NOT EXISTS donor_intelligence;

CREATE TABLE IF NOT EXISTS donor_intelligence.employer_sic_master (
    employer_raw TEXT PRIMARY KEY,
    employer_normalized TEXT,
    sic_code TEXT,
    naics_code TEXT,
    industry_sector TEXT,
    match_confidence NUMERIC(5, 2)
);

CREATE INDEX IF NOT EXISTS idx_esm_norm ON donor_intelligence.employer_sic_master (employer_normalized);
CREATE INDEX IF NOT EXISTS idx_esm_sic ON donor_intelligence.employer_sic_master (sic_code);
