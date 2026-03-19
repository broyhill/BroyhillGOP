-- pipeline/nc_boe_ddl.sql
-- NCBOE Ingestion Pipeline — DDL
-- Source: docs/NCBOE_INGESTION_PIPELINE_MASTER_PLAN_V2.md
--
-- REQUIRES (run first):
--   pipeline_ddl.sql: pipeline schema, source_quality_rules, dedup_rules
--   pipeline.employer_normalize exists (FEC version; we add employer_normalize_ncboe for NCBOE)
--   core.nick_group table (seeded from public.name_nickname_map)
--   public.nc_boe_donations_raw
--
-- Rollback: pipeline/nc_boe_ddl_rollback.sql

-- =============================================================================
-- 1. SCHEMAS
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;

-- =============================================================================
-- 2. ALTER TABLE: Add required norm/voter columns to raw (add if missing)
-- =============================================================================
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS content_hash TEXT;  -- duplicate detection (same for true dupes)
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS dedup_key TEXT;    -- unique row id (content_hash || id)
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS voter_ncid TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS zip9 TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS voter_party_cd TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS employer_normalized TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS middle_name TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS name_suffix TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS street_number TEXT;   -- parsed from street_line_1 (Eddie's rule)
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS address_block_key TEXT;  -- f(street_number, norm_last, zip5)

-- =============================================================================
-- 3. ARCHIVE TABLE (receives orphan, bad-date, no-voter-match, dedup-collision rows)
-- =============================================================================
CREATE TABLE IF NOT EXISTS staging.ncboe_archive (
    LIKE public.nc_boe_donations_raw INCLUDING DEFAULTS,
    archive_reason TEXT,
    archived_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- 4. COMMITTEE TRANSFERS (non-individual off-ramp)
-- =============================================================================
CREATE TABLE IF NOT EXISTS staging.ncboe_committee_transfers (
    LIKE public.nc_boe_donations_raw INCLUDING DEFAULTS,
    transferred_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- 5. COMMITTEE REGISTRY
-- =============================================================================
CREATE TABLE IF NOT EXISTS core.ncboe_committee_registry (
    committee_sboe_id TEXT PRIMARY KEY,
    committee_name TEXT,
    committee_type TEXT,
    first_seen_year INT,
    last_seen_year INT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- 6. COMMITTEE TYPE LOOKUP — MUST be populated from NCBOE official committee registry
-- DO NOT use split_part(committee_sboe_id, '-', 3) — SBOE IDs are opaque.
-- Import from NCBOE Campaign Finance (cf.ncsbe.gov/CFOrgLkup) or dl.ncsbe.gov
-- Run: python3 -m pipeline.import_ncboe_committee_registry path/to/committees.csv
-- =============================================================================
CREATE TABLE IF NOT EXISTS core.ncboe_committee_type_lookup (
    committee_sboe_id TEXT PRIMARY KEY,
    committee_type TEXT NOT NULL,
    notes TEXT
);

-- =============================================================================
-- 7. PROCESSED TABLE (handoff target)
-- =============================================================================
CREATE TABLE IF NOT EXISTS core.ncboe_donations_processed (
    id BIGSERIAL PRIMARY KEY,
    raw_id BIGINT,
    donor_id BIGINT,
    committee_sboe_id TEXT,
    date_occurred DATE,
    amount NUMERIC(12,2),
    norm_last TEXT,
    canonical_first TEXT,
    norm_zip5 TEXT,
    norm_addr TEXT,
    employer_normalized TEXT,
    voter_ncid TEXT,
    voter_party_cd TEXT,
    zip9 TEXT,
    dedup_key TEXT UNIQUE,
    source_cycle TEXT,
    ingested_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- 8. FUNCTIONS
-- =============================================================================

-- Drop old dedup signatures first
DROP FUNCTION IF EXISTS pipeline.dedup_key_ncboe(TEXT, TEXT, TEXT, DATE, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS pipeline.dedup_key_ncboe(TEXT, TEXT, DATE, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS pipeline.dedup_key_ncboe(TEXT, BIGINT);

-- Name parser: "LAST, FIRST MIDDLE" with fallback for no-comma
CREATE OR REPLACE FUNCTION pipeline.parse_ncboe_name(p_donor_name TEXT)
RETURNS TABLE(norm_last TEXT, norm_first TEXT, middle_name TEXT, name_suffix TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_clean TEXT;
    v_left TEXT;
    v_right TEXT;
    v_suffix TEXT;
    v_words TEXT[];
BEGIN
    v_clean := upper(trim(coalesce(p_donor_name, '')));
    IF v_clean = '' THEN
        norm_last := NULL; norm_first := NULL; middle_name := NULL; name_suffix := NULL;
        RETURN NEXT; RETURN;
    END IF;

    IF position(',' IN v_clean) > 0 THEN
        v_left := trim(split_part(v_clean, ',', 1));
        v_right := trim(split_part(v_clean, ',', 2));
        -- Suffix on last name: JONES JR
        IF v_left ~ '\s+(JR|SR|II|III|IV)\.?$' THEN
            v_suffix := (regexp_match(v_left, '\s+(JR|SR|II|III|IV)\.?$', 'i'))[1];
            v_left := trim(regexp_replace(v_left, '\s+(JR|SR|II|III|IV)\.?$', '', 'i'));
        END IF;
        -- Suffix on first: ROBERT JR
        IF v_right ~ '\s+(JR|SR|II|III|IV)\.?$' THEN
            v_suffix := coalesce(v_suffix, (regexp_match(v_right, '\s+(JR|SR|II|III|IV)\.?$', 'i'))[1]);
            v_right := trim(regexp_replace(v_right, '\s+(JR|SR|II|III|IV)\.?$', '', 'i'));
        END IF;
        -- Strip titles: DR. MR. MRS. REV.
        v_right := regexp_replace(v_right, '^\s*(DR|MR|MRS|MS|REV|HON)\.?\s+', '', 'i');
        norm_last := v_left;
        v_words := string_to_array(trim(v_right), ' ');
        norm_first := v_words[1];
        middle_name := CASE WHEN array_length(v_words, 1) > 1
            THEN array_to_string(v_words[2:array_length(v_words, 1)], ' ') ELSE NULL END;
        name_suffix := v_suffix;
    ELSE
        -- No comma: "FIRST LAST" — treat first word as first, rest as last
        norm_first := split_part(v_clean, ' ', 1);
        norm_last := trim(substring(v_clean from length(split_part(v_clean, ' ', 1)) + 2));
        middle_name := NULL;
        name_suffix := NULL;
    END IF;
    RETURN NEXT;
END;
$$;

-- NCBOE-specific employer normalizer (separate from FEC employer_normalize)
CREATE OR REPLACE FUNCTION pipeline.employer_normalize_ncboe(p_emp TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN p_emp IS NULL OR trim(p_emp) = '' THEN NULL
        WHEN upper(trim(p_emp)) IN ('N/A','NA','NONE','NOT EMPLOYED','RETIRED','SELF') THEN upper(trim(p_emp))
        ELSE trim(regexp_replace(upper(coalesce(p_emp,'')), '\s+', ' ', 'g'))
    END;
$$;

-- content_hash: SAME for true duplicate transactions (used for duplicate detection in Step 8)
CREATE OR REPLACE FUNCTION pipeline.content_hash_ncboe(
    p_norm_last TEXT,
    p_canonical_first TEXT,
    p_norm_zip5 TEXT,
    p_date_occurred DATE,
    p_amount NUMERIC
) RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT md5(
        coalesce(p_norm_last,'') || '|' ||
        coalesce(p_canonical_first,'') || '|' ||
        coalesce(p_norm_zip5,'') || '|' ||
        coalesce(p_date_occurred::text,'') || '|' ||
        coalesce(p_amount::text,'')
    );
$$;

-- dedup_key: UNIQUE per row (content_hash || id). Used as PK surrogate in processed table.
-- p_row_id: pass id::text from ETL — works with BIGINT, INTEGER, SERIAL, UUID
CREATE OR REPLACE FUNCTION pipeline.dedup_key_ncboe(
    p_content_hash TEXT,
    p_row_id TEXT
) RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT md5(coalesce(p_content_hash,'') || '|' || coalesce(p_row_id,''));
$$;
