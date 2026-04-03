-- ============================================================================
-- COMMITTEE → CANDIDATE FUZZY NAME MATCH
-- BroyhillGOP — March 31, 2026
--
-- PROBLEM: 425 committees have candidate_name in committee_registry but
-- don't exact-match name_on_ballot in ncsbe_candidates.
-- Cause: name format differences (BERGER, PHILIP vs PHILIP BERGER, etc.)
--
-- SOLUTION: Build a committee_candidate_bridge table using tiered matching:
--   Tier 1: Exact match (already working — 556 committees)
--   Tier 2: Last name exact + first 3 chars first name (catches initials/abbreviations)
--   Tier 3: pg_trgm similarity > 0.6 (catches format differences)
--   Tier 4: Last name exact only + single match (rare names)
--
-- OUTPUT: staging.committee_candidate_bridge
--   Maps committee_sboe_id → ncsbe_candidates row with confidence score
--   Used to replace the LATERAL join in boe_donation_candidate_map
-- ============================================================================

SET statement_timeout = 0;

-- Ensure pg_trgm is available
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================================
-- STEP 1 — Build the bridge table
-- ============================================================================
DROP TABLE IF EXISTS staging.committee_candidate_bridge;

CREATE TABLE staging.committee_candidate_bridge AS

-- TIER 1: Exact match on name_on_ballot (already working 556 committees)
WITH exact_match AS (
  SELECT DISTINCT ON (cr.sboe_id)
    cr.sboe_id                                                 AS committee_sboe_id,
    cr.committee_name,
    cr.candidate_name                                          AS registry_candidate_name,
    nc.name_on_ballot,
    nc.contest_name,
    nc.county_name,
    nc.party_candidate,
    nc.election_dt,
    1.000                                                      AS match_confidence,
    'exact'                                                    AS match_method
  FROM public.committee_registry cr
  JOIN public.ncsbe_candidates nc
    ON upper(trim(nc.name_on_ballot)) = upper(trim(cr.candidate_name))
    AND nc.party_candidate ILIKE '%REP%'
  WHERE cr.candidate_name IS NOT NULL AND cr.candidate_name != ''
  ORDER BY cr.sboe_id, nc.election_dt DESC
),

-- Remaining unmatched committees after Tier 1
unmatched AS (
  SELECT cr.sboe_id, cr.committee_name, cr.candidate_name
  FROM public.committee_registry cr
  WHERE cr.candidate_name IS NOT NULL AND cr.candidate_name != ''
    AND cr.sboe_id NOT IN (SELECT committee_sboe_id FROM exact_match)
),

-- TIER 2: Last name exact + first 3 chars
-- Handles: "BERGER, PHILIP" vs "PHILIP BERGER", "PHIL BERGER" vs "PHILIP BERGER"
tier2 AS (
  SELECT DISTINCT ON (u.sboe_id)
    u.sboe_id                                                  AS committee_sboe_id,
    u.committee_name,
    u.candidate_name                                           AS registry_candidate_name,
    nc.name_on_ballot,
    nc.contest_name,
    nc.county_name,
    nc.party_candidate,
    nc.election_dt,
    0.850                                                      AS match_confidence,
    'last_first3'                                              AS match_method,
    count(*) OVER (PARTITION BY u.sboe_id)                    AS match_count
  FROM unmatched u
  JOIN public.ncsbe_candidates nc
    ON nc.party_candidate ILIKE '%REP%'
    -- Last name: try both "LAST, FIRST" and "FIRST LAST" formats in registry
    AND (
      -- Registry format: "BERGER, PHILIP" → last = BERGER
      (
        u.candidate_name LIKE '%,%'
        AND upper(trim(split_part(u.candidate_name, ',', 1)))
          = upper(trim(split_part(nc.name_on_ballot, ' ',
              array_length(string_to_array(trim(nc.name_on_ballot), ' '), 1))))
        AND LEFT(upper(trim(split_part(u.candidate_name, ',', 2))), 3)
          = LEFT(upper(trim(split_part(nc.name_on_ballot, ' ', 1))), 3)
      )
      OR
      -- Registry format: "PHILIP BERGER" → last = BERGER (last word)
      (
        u.candidate_name NOT LIKE '%,%'
        AND upper(trim(split_part(u.candidate_name, ' ',
            array_length(string_to_array(trim(u.candidate_name), ' '), 1))))
          = upper(trim(split_part(nc.name_on_ballot, ' ',
              array_length(string_to_array(trim(nc.name_on_ballot), ' '), 1))))
        AND LEFT(upper(trim(split_part(u.candidate_name, ' ', 1))), 3)
          = LEFT(upper(trim(split_part(nc.name_on_ballot, ' ', 1))), 3)
      )
    )
  ORDER BY u.sboe_id, nc.election_dt DESC
),

tier2_clean AS (
  SELECT * FROM tier2 WHERE match_count = 1
),

-- TIER 3: pg_trgm similarity > 0.6
tier3_unmatched AS (
  SELECT sboe_id, committee_name, candidate_name
  FROM unmatched
  WHERE sboe_id NOT IN (SELECT committee_sboe_id FROM tier2_clean)
),

tier3 AS (
  SELECT DISTINCT ON (u.sboe_id)
    u.sboe_id                                                  AS committee_sboe_id,
    u.committee_name,
    u.candidate_name                                           AS registry_candidate_name,
    nc.name_on_ballot,
    nc.contest_name,
    nc.county_name,
    nc.party_candidate,
    nc.election_dt,
    similarity(upper(trim(u.candidate_name)),
               upper(trim(nc.name_on_ballot)))                AS match_confidence,
    'fuzzy_trgm'                                               AS match_method,
    count(*) OVER (PARTITION BY u.sboe_id)                    AS match_count
  FROM tier3_unmatched u
  JOIN public.ncsbe_candidates nc
    ON similarity(upper(trim(u.candidate_name)),
                  upper(trim(nc.name_on_ballot))) > 0.6
    AND nc.party_candidate ILIKE '%REP%'
  ORDER BY u.sboe_id,
           similarity(upper(trim(u.candidate_name)),
                      upper(trim(nc.name_on_ballot))) DESC,
           nc.election_dt DESC
),

tier3_clean AS (
  SELECT * FROM tier3
  WHERE match_confidence > 0.6
    AND match_count = 1
),

-- TIER 4: Last name exact only — single match among all REP candidates
tier4_unmatched AS (
  SELECT sboe_id, committee_name, candidate_name
  FROM unmatched
  WHERE sboe_id NOT IN (SELECT committee_sboe_id FROM tier2_clean)
    AND sboe_id NOT IN (SELECT committee_sboe_id FROM tier3_clean)
),

tier4 AS (
  SELECT DISTINCT ON (u.sboe_id)
    u.sboe_id                                                  AS committee_sboe_id,
    u.committee_name,
    u.candidate_name                                           AS registry_candidate_name,
    nc.name_on_ballot,
    nc.contest_name,
    nc.county_name,
    nc.party_candidate,
    nc.election_dt,
    0.700                                                      AS match_confidence,
    'last_only'                                                AS match_method,
    count(*) OVER (PARTITION BY u.sboe_id)                    AS match_count
  FROM tier4_unmatched u
  JOIN public.ncsbe_candidates nc
    ON nc.party_candidate ILIKE '%REP%'
    AND (
      -- Last word of registry name = last word of ballot name
      upper(trim(split_part(
        CASE WHEN u.candidate_name LIKE '%,%'
             THEN trim(split_part(u.candidate_name,',',1))
             ELSE u.candidate_name END,
        ' ',
        array_length(string_to_array(trim(
          CASE WHEN u.candidate_name LIKE '%,%'
               THEN trim(split_part(u.candidate_name,',',1))
               ELSE u.candidate_name END
        ), ' '), 1)
      )))
      = upper(trim(split_part(nc.name_on_ballot, ' ',
          array_length(string_to_array(trim(nc.name_on_ballot), ' '), 1))))
    )
  ORDER BY u.sboe_id,
           nc.election_dt DESC
),

tier4_clean AS (
  SELECT * FROM tier4 WHERE match_count = 1
)

-- Combine all tiers — each committee gets best match
SELECT committee_sboe_id, committee_name, registry_candidate_name,
       name_on_ballot, contest_name, county_name, party_candidate,
       election_dt, match_confidence, match_method
FROM exact_match

UNION ALL
SELECT committee_sboe_id, committee_name, registry_candidate_name,
       name_on_ballot, contest_name, county_name, party_candidate,
       election_dt, match_confidence, match_method
FROM tier2_clean

UNION ALL
SELECT committee_sboe_id, committee_name, registry_candidate_name,
       name_on_ballot, contest_name, county_name, party_candidate,
       election_dt, match_confidence, match_method
FROM tier3_clean

UNION ALL
SELECT committee_sboe_id, committee_name, registry_candidate_name,
       name_on_ballot, contest_name, county_name, party_candidate,
       election_dt, match_confidence, match_method
FROM tier4_clean;

CREATE INDEX idx_ccb_sboe ON staging.committee_candidate_bridge (committee_sboe_id);

-- ============================================================================
-- STEP 2 — Results
-- ============================================================================
SELECT match_method, count(*) AS committees, round(avg(match_confidence),3) AS avg_confidence
FROM staging.committee_candidate_bridge
GROUP BY 1 ORDER BY 2 DESC;

SELECT
  981                                                          AS had_candidate_name,
  (SELECT count(*) FROM staging.committee_candidate_bridge)   AS now_matched,
  981 - (SELECT count(*) FROM staging.committee_candidate_bridge) AS still_unmatched;

-- Sample of fuzzy matches for review
SELECT registry_candidate_name, name_on_ballot, match_confidence, match_method, contest_name
FROM staging.committee_candidate_bridge
WHERE match_method IN ('fuzzy_trgm','last_first3','last_only')
ORDER BY match_confidence DESC
LIMIT 30;

-- ============================================================================
-- STEP 3 — Rebuild boe_donation_candidate_map using the bridge
-- ============================================================================
DROP TABLE IF EXISTS staging.boe_donation_candidate_map;

CREATE TABLE staging.boe_donation_candidate_map AS
SELECT
  r.id                                                         AS boe_id,
  r.donor_name,
  r.norm_last,
  r.norm_first,
  r.norm_zip5,
  r.amount_numeric,
  r.date_occurred,
  EXTRACT(year FROM r.date_occurred)::int                     AS election_year,
  r.committee_sboe_id,
  cr.committee_name,
  cr.committee_type,
  cr.source_level,
  cr.fec_committee_id,
  -- Candidate from bridge (all 4 tiers)
  b.name_on_ballot                                             AS candidate_name,
  b.contest_name,
  b.county_name                                               AS candidate_county,
  b.party_candidate                                           AS candidate_party,
  b.election_dt                                               AS election_date,
  b.match_confidence,
  b.match_method,
  -- Office level classification
  CASE
    WHEN upper(b.contest_name) LIKE '%U.S. SENATE%'
      OR upper(b.contest_name) LIKE '%US SENATE%'             THEN 'FEDERAL_SENATE'
    WHEN upper(b.contest_name) LIKE '%U.S. HOUSE%'
      OR upper(b.contest_name) LIKE '%US HOUSE%'
      OR upper(b.contest_name) LIKE '%CONGRESS%'              THEN 'FEDERAL_HOUSE'
    WHEN upper(b.contest_name) LIKE '%NC SENATE%'
      OR upper(b.contest_name) LIKE '%STATE SENATE%'          THEN 'STATE_SENATE'
    WHEN upper(b.contest_name) LIKE '%NC HOUSE%'
      OR upper(b.contest_name) LIKE '%STATE HOUSE%'           THEN 'STATE_HOUSE'
    WHEN upper(b.contest_name) LIKE '%GOVERNOR%'              THEN 'STATE_GOVERNOR'
    WHEN upper(b.contest_name) LIKE '%ATTORNEY GENERAL%'      THEN 'STATE_AG'
    WHEN upper(b.contest_name) LIKE '%TREASURER%'             THEN 'STATE_TREASURER'
    WHEN upper(b.contest_name) LIKE '%AUDITOR%'               THEN 'STATE_AUDITOR'
    WHEN upper(b.contest_name) LIKE '%LIEUTENANT%'            THEN 'STATE_LT_GOV'
    WHEN upper(b.contest_name) LIKE '%SUPERINTENDENT%'        THEN 'STATE_SUPER'
    WHEN upper(b.contest_name) LIKE '%INSURANCE%'             THEN 'STATE_INS_COMM'
    WHEN upper(b.contest_name) LIKE '%LABOR%'
      AND upper(b.contest_name) LIKE '%COMMISSIONER%'         THEN 'STATE_LABOR'
    WHEN upper(b.contest_name) LIKE '%AGRICULTURE%'           THEN 'STATE_AG_COMM'
    WHEN upper(b.contest_name) LIKE '%COMMISSIONER%'          THEN 'STATE_COMMISSIONER'
    WHEN upper(cr.committee_type) LIKE '%COUNTY%REC%'
      OR upper(cr.committee_name) LIKE '%REPUBLICAN%COUNTY%'
      OR upper(cr.committee_name) LIKE '% REC'
      OR upper(cr.committee_name) LIKE '%COUNTY%REC%'         THEN 'COUNTY_PARTY'
    WHEN upper(cr.committee_type) LIKE '%PAC%'               THEN 'PAC'
    WHEN upper(cr.committee_type) LIKE '%PARTY%'             THEN 'STATE_PARTY'
    WHEN upper(b.contest_name) LIKE '%JUDGE%'
      OR upper(b.contest_name) LIKE '%JUSTICE%'
      OR upper(b.contest_name) LIKE '%COURT%'                 THEN 'JUDICIAL'
    WHEN upper(b.contest_name) LIKE '%SHERIFF%'              THEN 'LOCAL_SHERIFF'
    WHEN upper(b.contest_name) LIKE '%SCHOOL%'               THEN 'SCHOOL_BOARD'
    WHEN b.contest_name IS NOT NULL                          THEN 'LOCAL_OTHER'
    WHEN cr.committee_type IS NOT NULL                       THEN 'PARTY_INFRA'
    ELSE 'UNCLASSIFIED'
  END                                                         AS office_level,
  regexp_replace(coalesce(b.contest_name,''), '[^0-9]', '', 'g') AS district_number,
  CASE
    WHEN upper(b.party_candidate) LIKE '%REP%'               THEN 'R'
    WHEN upper(b.party_candidate) LIKE '%DEM%'               THEN 'D'
    WHEN upper(cr.committee_type) IN (
      'COUNTY_REC','NCGOP_AUXILIARY','OFFICIAL_STATE_PARTY')   THEN 'R'
    WHEN cr.committee_name ILIKE '%REPUBLICAN%'
      OR cr.committee_name ILIKE '% REC'
      OR cr.committee_name ILIKE '%GOP%'                      THEN 'R'
    ELSE 'U'
  END                                                         AS partisan_flag
FROM public.nc_boe_donations_raw r
LEFT JOIN public.committee_registry cr ON cr.sboe_id = r.committee_sboe_id
LEFT JOIN staging.committee_candidate_bridge b ON b.committee_sboe_id = r.committee_sboe_id
WHERE r.transaction_type = 'Individual'
  AND r.amount_numeric > 0
  AND r.date_occurred >= '2015-01-01'
  AND r.date_occurred <= '2026-12-31';

-- ============================================================================
-- STEP 4 — Final validation
-- ============================================================================
SELECT
  count(*)                                                     AS total_donations,
  count(*) FILTER (WHERE candidate_name IS NOT NULL)          AS matched_candidate,
  round(100.0 * count(*) FILTER (WHERE candidate_name IS NOT NULL)
    / count(*), 1)                                            AS candidate_match_pct,
  count(*) FILTER (WHERE office_level != 'UNCLASSIFIED')      AS classified_office,
  round(100.0 * count(*) FILTER (WHERE partisan_flag = 'R')
    / count(*), 1)                                            AS r_flag_pct
FROM staging.boe_donation_candidate_map;

-- Office level breakdown
SELECT office_level, count(*) AS donations, round(sum(amount_numeric)) AS total_dollars
FROM staging.boe_donation_candidate_map
GROUP BY 1 ORDER BY 2 DESC;

-- Ed Broyhill r_pct check
SELECT
  round(sum(amount_numeric)) AS total,
  round(sum(amount_numeric) FILTER (WHERE partisan_flag='R')) AS r_total,
  round(100.0 * sum(amount_numeric) FILTER (WHERE partisan_flag='R')
    / sum(amount_numeric), 1) AS r_pct
FROM staging.boe_donation_candidate_map
WHERE norm_zip5 IN ('27104','27012')
  AND norm_last ILIKE '%BROYHILL%'
  AND donor_name ILIKE '%ED%';

-- Report all results. STOP — no production writes.
