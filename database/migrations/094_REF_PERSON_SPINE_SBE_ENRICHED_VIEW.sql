-- 094_REF_PERSON_SPINE_SBE_ENRICHED_VIEW.sql
-- Active spine rows joined to authoritative nc_voters (NCSBE) for reconciliation.
-- Use to spot drift between spine.voter_* fields and current SBE file.
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/094_REF_PERSON_SPINE_SBE_ENRICHED_VIEW.sql

CREATE SCHEMA IF NOT EXISTS ref;

CREATE OR REPLACE VIEW ref.v_person_spine_sbe_enriched AS
SELECT
  s.person_id,
  s.voter_ncid,
  s.is_registered_voter,
  s.voter_status AS spine_voter_status,
  s.voter_party AS spine_voter_party,
  s.voter_county AS spine_voter_county,
  v.status_cd AS sbe_status_cd,
  v.party_cd AS sbe_party_cd,
  v.county_desc AS sbe_county,
  (v.status_cd = 'A') AS sbe_is_active,
  (v.ncid IS NULL) AS sbe_row_missing
FROM core.person_spine s
LEFT JOIN public.nc_voters v
  ON TRIM(s.voter_ncid::text) = TRIM(v.ncid::text)
WHERE s.is_active = true;

COMMENT ON VIEW ref.v_person_spine_sbe_enriched IS
  'person_spine (active) + nc_voters join on ncid. Compare spine_voter_* vs sbe_*; sbe_row_missing when NCID on spine has no SBE row.';
