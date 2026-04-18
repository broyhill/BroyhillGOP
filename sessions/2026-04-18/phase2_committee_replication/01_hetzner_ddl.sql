-- ============================================================================
-- PHASE 2 — Committee Matching Machine Replication: Supabase → Hetzner
-- Created: 2026-04-18  by Nexus
-- Target:  postgresql://postgres:***@37.27.169.232:5432/postgres
--
-- GUARD RAILS (from database-operations skill):
--   - CREATE TABLE IF NOT EXISTS only. No ALTER/DROP of existing objects.
--   - No mutation of raw.ncboe_donations, committee.registry, or any table
--     already replicated April 15.
--   - committee schema already exists on Hetzner.  staging schema exists.
--   - Target row counts after load:
--       committee.boe_donation_candidate_map    338,213
--       committee.ncsbe_candidates_full          55,985
--       committee.fec_committee_candidate_lookup  2,012
-- ============================================================================

SET statement_timeout = 0;
SET lock_timeout = '10s';

-- ============================================================================
-- 1) staging.boe_donation_candidate_map — 338,213 rows (donation→candidate)
--    THE MATCHING-MACHINE OUTPUT.  Every NCBOE donation already tagged with
--    a candidate + contest + office + district.  249,957 have candidate_name
--    set (73.9% match rate, matches the 2026-04-01 Cursor audit once filtered).
-- ============================================================================
CREATE TABLE IF NOT EXISTS committee.boe_donation_candidate_map (
    boe_id                   bigint,
    donor_name               varchar,
    norm_last                varchar,
    norm_first               varchar,
    norm_zip5                varchar,
    amount_numeric           numeric,
    date_occurred            date,
    election_year            integer,
    committee_sboe_id        varchar,
    committee_name           text,
    committee_type           text,
    source_level             text,
    committee_total_received numeric,
    fec_committee_id         text,
    candidate_name           varchar,
    contest_name             varchar,
    candidate_county         varchar,
    candidate_party          varchar,
    filing_date              varchar,
    election_dt              varchar,
    office_level             text,
    district_number          text,
    partisan_flag            text,
    loaded_at                timestamptz NOT NULL DEFAULT now(),
    source                   text        NOT NULL DEFAULT 'supabase/staging.boe_donation_candidate_map'
);

CREATE INDEX IF NOT EXISTS idx_bdcm_committee_sboe_id
  ON committee.boe_donation_candidate_map (committee_sboe_id);

CREATE INDEX IF NOT EXISTS idx_bdcm_boe_id
  ON committee.boe_donation_candidate_map (boe_id);

CREATE INDEX IF NOT EXISTS idx_bdcm_norm_match
  ON committee.boe_donation_candidate_map (norm_last, norm_first, norm_zip5);

CREATE INDEX IF NOT EXISTS idx_bdcm_candidate_name
  ON committee.boe_donation_candidate_map (candidate_name)
  WHERE candidate_name IS NOT NULL;

COMMENT ON TABLE committee.boe_donation_candidate_map IS
  'Donation → candidate match output.  Sourced from Supabase staging.boe_donation_candidate_map on 2026-04-18.  See committee.registry for committee metadata.';

-- ============================================================================
-- 2) committee.ncsbe_candidates_full — 55,985 rows (complete NC candidate universe)
--    Distinct from committee.ncsbe_candidate_master (4,165 rows, which is the
--    committee-master subset).  This is the full NCSBE candidate file going
--    back decades, needed for fuzzy-match bridge expansion.
-- ============================================================================
CREATE TABLE IF NOT EXISTS committee.ncsbe_candidates_full (
    id                   bigint PRIMARY KEY,
    election_dt          varchar,
    county_name          varchar,
    contest_name         varchar,
    name_on_ballot       varchar,
    first_name           varchar,
    middle_name          varchar,
    last_name            varchar,
    name_suffix_lbl      varchar,
    nick_name            varchar,
    street_address       varchar,
    city                 varchar,
    state                varchar,
    zip                  varchar,
    election_dt_original varchar,
    contest_original     varchar,
    party_candidate      varchar,
    party_contest        varchar,
    is_partisan          varchar,
    vote_for             varchar,
    term                 varchar,
    created_at           timestamptz,
    phone                varchar,
    email                varchar,
    filing_date          varchar,
    import_batch         text,
    committee_sboe_id    text,
    loaded_at            timestamptz NOT NULL DEFAULT now(),
    source               text        NOT NULL DEFAULT 'supabase/public.ncsbe_candidates'
);

CREATE INDEX IF NOT EXISTS idx_ncsbe_cf_name_on_ballot
  ON committee.ncsbe_candidates_full (upper(name_on_ballot));

CREATE INDEX IF NOT EXISTS idx_ncsbe_cf_last_first
  ON committee.ncsbe_candidates_full (upper(last_name), upper(first_name));

CREATE INDEX IF NOT EXISTS idx_ncsbe_cf_committee_sboe
  ON committee.ncsbe_candidates_full (committee_sboe_id)
  WHERE committee_sboe_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ncsbe_cf_party
  ON committee.ncsbe_candidates_full (party_candidate);

COMMENT ON TABLE committee.ncsbe_candidates_full IS
  'Full NCSBE candidate universe (55,985).  Distinct from committee.ncsbe_candidate_master which is the 4,165-row committee-master subset.  Sourced from Supabase public.ncsbe_candidates on 2026-04-18.';

-- ============================================================================
-- 3) committee.fec_committee_candidate_lookup — 2,012 rows (FEC side)
--    Was 770 at March 23 audit → grew 2.6× to 2,012.
-- ============================================================================
CREATE TABLE IF NOT EXISTS committee.fec_committee_candidate_lookup (
    id                        integer PRIMARY KEY,
    committee_id              text        NOT NULL,
    committee_name            text,
    committee_type            text,
    committee_designation     text,
    committee_party           text,
    committee_state           text,
    candidate_id              text,
    candidate_name            text,
    candidate_last_name       text,
    candidate_first_name      text,
    candidate_party           text,
    candidate_office          text,
    candidate_office_state    text,
    candidate_office_district text,
    election_year             integer,
    match_method              text,
    match_confidence          double precision,
    donation_count            integer,
    total_donated             numeric,
    created_at                timestamptz,
    updated_at                timestamptz,
    loaded_at                 timestamptz NOT NULL DEFAULT now(),
    source                    text        NOT NULL DEFAULT 'supabase/public.fec_committee_candidate_lookup'
);

CREATE INDEX IF NOT EXISTS idx_fccl_committee_id
  ON committee.fec_committee_candidate_lookup (committee_id);

CREATE INDEX IF NOT EXISTS idx_fccl_candidate_id
  ON committee.fec_committee_candidate_lookup (candidate_id)
  WHERE candidate_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fccl_office
  ON committee.fec_committee_candidate_lookup (candidate_office, candidate_office_state);

COMMENT ON TABLE committee.fec_committee_candidate_lookup IS
  'FEC committee → candidate lookup (2,012).  Grew from 770 since March 23 audit.  Sourced from Supabase public.fec_committee_candidate_lookup on 2026-04-18.';

-- ============================================================================
-- 4) Verification view — run after load to confirm everything lines up
-- ============================================================================
CREATE OR REPLACE VIEW committee.v_matching_machine_status AS
SELECT
  'committee.registry'                          AS tbl,  (SELECT COUNT(*) FROM committee.registry)                       AS rows,  10975 AS expected
UNION ALL SELECT 'committee.office_type_map',          (SELECT COUNT(*) FROM committee.office_type_map),              1550
UNION ALL SELECT 'committee.boe_candidate_map',        (SELECT COUNT(*) FROM committee.boe_candidate_map),             648
UNION ALL SELECT 'committee.party_map',                (SELECT COUNT(*) FROM committee.party_map),                   19982
UNION ALL SELECT 'committee.ncsbe_candidate_master',   (SELECT COUNT(*) FROM committee.ncsbe_candidate_master),       4165
UNION ALL SELECT 'core.ncboe_committee_registry',      (SELECT COUNT(*) FROM core.ncboe_committee_registry),          2032
UNION ALL SELECT 'core.ncboe_committee_type_lookup',   (SELECT COUNT(*) FROM core.ncboe_committee_type_lookup),       2039
UNION ALL SELECT 'core.candidate_committee_map',       (SELECT COUNT(*) FROM core.candidate_committee_map),           5761
UNION ALL SELECT 'staging.sboe_committee_master',      (SELECT COUNT(*) FROM staging.sboe_committee_master),         13237
UNION ALL SELECT 'staging.committee_candidate_bridge', (SELECT COUNT(*) FROM staging.committee_candidate_bridge),      864
UNION ALL SELECT 'committee.boe_donation_candidate_map',      (SELECT COUNT(*) FROM committee.boe_donation_candidate_map),      338213
UNION ALL SELECT 'committee.ncsbe_candidates_full',           (SELECT COUNT(*) FROM committee.ncsbe_candidates_full),            55985
UNION ALL SELECT 'committee.fec_committee_candidate_lookup',  (SELECT COUNT(*) FROM committee.fec_committee_candidate_lookup),    2012
;

COMMENT ON VIEW committee.v_matching_machine_status IS
  'State-of-the-machine dashboard.  Every row should show rows = expected after Phase 2 completes.';
