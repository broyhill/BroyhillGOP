-- 059_FEC_SEPARATE_COMMITTEES.sql
-- Move non-individual (committee/PAC/ORG) contributions OUT of norm.fec_individual
-- before running fec_voter_matcher. Committees cannot be matched to nc_voters.
--
-- Prerequisites: raw.fec_donations and norm.fec_individual must exist (from fec_raw_import + fec_norm_populate).
-- Run BEFORE: backend/python/matching/fec_voter_matcher.py
-- Run: psql $SUPABASE_DB_URL -f database/migrations/059_FEC_SEPARATE_COMMITTEES.sql
--
-- FEC entity_type: IND=individual, PAC, ORG, COM (committee), etc.
-- is_individual: 'Y' = individual

-- Ensure staging schema exists
CREATE SCHEMA IF NOT EXISTS staging;

-- =============================================================================
-- 1. Create staging table for FEC non-individual contributions
-- =============================================================================
CREATE TABLE IF NOT EXISTS staging.fec_non_individual_contributions (
    id                  BIGSERIAL PRIMARY KEY,
    sub_id              BIGINT,
    load_id             BIGINT,
    norm_last           TEXT,
    norm_first          TEXT,
    norm_middle         TEXT,
    norm_suffix         TEXT,
    norm_prefix         TEXT,
    raw_contributor_name TEXT,
    contributor_id      TEXT,
    norm_street         TEXT,
    norm_city           TEXT,
    norm_state          TEXT,
    norm_zip5           TEXT,
    norm_employer       TEXT,
    norm_occupation     TEXT,
    amount              NUMERIC(12,2),
    transaction_date    DATE,
    committee_id        TEXT,
    candidate_id        TEXT,
    candidate_name      TEXT,
    fec_cycle           INTEGER,
    entity_type         TEXT,
    entity_type_desc    TEXT,
    is_individual       TEXT,
    moved_at            TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE staging.fec_non_individual_contributions IS 'FEC Schedule A rows where contributor is PAC/ORG/committee — moved from norm.fec_individual before voter matching.';

-- =============================================================================
-- 2. Move non-individual rows from norm.fec_individual to staging
--    Only move when we have POSITIVE evidence it's a committee (conservative:
--    NULL entity_type/is_individual stays in fec_individual)
-- =============================================================================
INSERT INTO staging.fec_non_individual_contributions (
    sub_id, load_id, norm_last, norm_first, norm_middle, norm_suffix, norm_prefix,
    raw_contributor_name, contributor_id, norm_street, norm_city, norm_state, norm_zip5,
    norm_employer, norm_occupation, amount, transaction_date,
    committee_id, candidate_id, candidate_name, fec_cycle,
    entity_type, entity_type_desc, is_individual
)
SELECT
    f.sub_id, f.load_id, f.norm_last, f.norm_first, f.norm_middle, f.norm_suffix, f.norm_prefix,
    f.raw_contributor_name, f.contributor_id, f.norm_street, f.norm_city, f.norm_state, f.norm_zip5,
    f.norm_employer, f.norm_occupation, f.amount, f.transaction_date,
    f.committee_id, f.candidate_id, f.candidate_name, f.fec_cycle,
    r.entity_type, r.entity_type_desc, r.is_individual
FROM norm.fec_individual f
JOIN raw.fec_donations r ON r.sub_id::BIGINT = f.sub_id
WHERE r.entity_type IN ('PAC', 'ORG', 'COM')  -- explicit committee types
   OR UPPER(COALESCE(r.is_individual, '')) IN ('N', 'F', 'NO', 'FALSE')  -- explicit non-individual
   OR UPPER(COALESCE(r.entity_type_desc, '')) LIKE '%COMMITTEE%'
   OR UPPER(COALESCE(r.entity_type_desc, '')) LIKE '%PAC%'
   OR UPPER(COALESCE(r.entity_type_desc, '')) LIKE '%ORGANIZATION%';

-- =============================================================================
-- 3. Delete those rows from norm.fec_individual
-- =============================================================================
DELETE FROM norm.fec_individual f
USING raw.fec_donations r
WHERE r.sub_id::BIGINT = f.sub_id
  AND (
      r.entity_type IN ('PAC', 'ORG', 'COM')
      OR UPPER(COALESCE(r.is_individual, '')) IN ('N', 'F', 'NO', 'FALSE')
      OR UPPER(COALESCE(r.entity_type_desc, '')) LIKE '%COMMITTEE%'
      OR UPPER(COALESCE(r.entity_type_desc, '')) LIKE '%PAC%'
      OR UPPER(COALESCE(r.entity_type_desc, '')) LIKE '%ORGANIZATION%'
  );

-- =============================================================================
-- 4. Report
-- =============================================================================
-- Run after: SELECT COUNT(*) FROM staging.fec_non_individual_contributions;
--            SELECT COUNT(*) FROM norm.fec_individual;
