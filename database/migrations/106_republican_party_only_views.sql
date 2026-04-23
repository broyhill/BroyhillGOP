-- 106_republican_party_only_views.sql
-- Purpose:
--   Re-focus processing on Republican Party committee records only.
--   Creates dedicated views scoped to GOP/Republican party committee rows.
-- Depends on:
--   104_committee_id_fullname_machine.sql
--   105_committee_name_machine_refresh_and_enriched_views.sql

CREATE SCHEMA IF NOT EXISTS committee;

-- Ensure canonical name machine is fresh before party-only projections.
SELECT committee.refresh_committee_id_canonical_name();

-- ============================================================
-- 1) User-facing Republican party donations only
-- ============================================================
CREATE OR REPLACE VIEW committee.v_republican_party_individual_donors AS
SELECT
  v.*
FROM committee.v_party_committee_individual_donors v
LEFT JOIN committee.registry cr
  ON cr.sboe_id = v.committee_sboe_id
WHERE
  (
    upper(v.committee_name) LIKE '%REPUBLICAN%'
    OR upper(v.committee_name) LIKE '%GOP%'
    OR upper(v.committee_name) LIKE '%NCGOP%'
  )
  AND COALESCE(cr.committee_type, '') IN ('PARTY', 'COUNTY_PARTY', 'CAUCUS', 'COUNTY_REC');

COMMENT ON VIEW committee.v_republican_party_individual_donors IS
  'Republican/GOP party-committee individual donations only (party-scoped projection).';

-- ============================================================
-- 2) Enriched Republican party donor rows only
-- ============================================================
CREATE OR REPLACE VIEW committee.v_republican_party_donor_enriched AS
SELECT
  p.*
FROM committee.party_donor_enriched p
WHERE
  (
    upper(p.committee_name) LIKE '%REPUBLICAN%'
    OR upper(p.committee_name) LIKE '%GOP%'
    OR upper(p.committee_name) LIKE '%NCGOP%'
  )
  AND COALESCE(p.committee_type, '') IN ('PARTY', 'COUNTY_PARTY', 'CAUCUS', 'COUNTY_REC');

COMMENT ON VIEW committee.v_republican_party_donor_enriched IS
  'Republican/GOP party committee-only subset of party_donor_enriched.';
