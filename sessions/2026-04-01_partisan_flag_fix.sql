-- ============================================================================
-- PARTISAN FLAG FIX
-- BroyhillGOP — April 1, 2026
--
-- PROBLEM: Ed's r_pct shows 33-39% when it should be 90%+
-- ROOT CAUSE: County party, state party, and PAC donations are getting
-- partisan_flag = 'U' because they have no candidate match.
-- These are overwhelmingly Republican committees.
--
-- SOLUTION: Expand partisan_flag = 'R' logic using:
--   1. committee_registry.committee_name contains REPUBLICAN/GOP/REC
--   2. committee_registry.committee_type = COUNTY_REC/COUNTY_PARTY/PARTY
--   3. Known Republican committee name patterns from nc_boe_donations_raw
-- ============================================================================

SET statement_timeout = 0;

-- ============================================================================
-- STEP 1 — Audit current partisan_flag distribution
-- ============================================================================
SELECT
  partisan_flag,
  count(*)                                                     AS donations,
  round(sum(amount_numeric))                                   AS total_dollars,
  round(100.0 * count(*) / sum(count(*)) OVER (), 1)          AS pct
FROM staging.boe_donation_candidate_map
GROUP BY 1 ORDER BY 2 DESC;

-- ============================================================================
-- STEP 2 — Identify R committees currently getting 'U'
-- ============================================================================
SELECT
  cr.committee_type,
  r.committee_name                                             AS boe_committee_name,
  count(*)                                                     AS donations,
  round(sum(r.amount_numeric))                                 AS dollars
FROM staging.boe_donation_candidate_map m
JOIN public.nc_boe_donations_raw r ON r.id = m.boe_id
LEFT JOIN public.committee_registry cr ON cr.sboe_id = m.committee_sboe_id
WHERE m.partisan_flag = 'U'
  AND (
    r.committee_name ILIKE '%REPUBLICAN%'
    OR r.committee_name ILIKE '%GOP%'
    OR r.committee_name ILIKE '% REC'
    OR r.committee_name ILIKE '%NCGOP%'
    OR r.committee_name ILIKE '%NC GOP%'
    OR cr.committee_type IN ('COUNTY_REC','COUNTY_PARTY','PARTY')
  )
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 30;

-- ============================================================================
-- STEP 3 — Rebuild boe_donation_candidate_map with fixed partisan_flag
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
  b.name_on_ballot                                             AS candidate_name,
  b.contest_name,
  b.county_name                                               AS candidate_county,
  b.party_candidate                                           AS candidate_party,
  b.election_dt                                               AS election_date,
  b.match_confidence,
  b.match_method,
  -- Office level classification (LIEUTENANT before GOVERNOR)
  CASE
    WHEN upper(b.contest_name) LIKE '%U.S. SENATE%'
      OR upper(b.contest_name) LIKE '%US SENATE%'             THEN 'FEDERAL_SENATE'
    WHEN upper(b.contest_name) LIKE '%U.S. HOUSE%'
      OR upper(b.contest_name) LIKE '%US HOUSE%'
      OR upper(b.contest_name) LIKE '%CONGRESS%'              THEN 'FEDERAL_HOUSE'
    WHEN upper(b.contest_name) LIKE '%NC SENATE%'
      OR upper(b.contest_name) LIKE '%STATE SENATE%'          THEN 'STATE_SENATE'
    WHEN upper(b.contest_name) LIKE '%NC HOUSE%'
      OR upper(b.contest_name) LIKE '%STATE HOUSE%'
      OR upper(b.contest_name) LIKE '%HOUSE OF REPRESENT%'    THEN 'STATE_HOUSE'
    WHEN upper(b.contest_name) LIKE '%LIEUTENANT%'            THEN 'STATE_LT_GOV'
    WHEN upper(b.contest_name) LIKE '%GOVERNOR%'              THEN 'STATE_GOVERNOR'
    WHEN upper(b.contest_name) LIKE '%ATTORNEY GENERAL%'      THEN 'STATE_AG'
    WHEN upper(b.contest_name) LIKE '%TREASURER%'             THEN 'STATE_TREASURER'
    WHEN upper(b.contest_name) LIKE '%AUDITOR%'               THEN 'STATE_AUDITOR'
    WHEN upper(b.contest_name) LIKE '%SUPERINTENDENT%'        THEN 'STATE_SUPER'
    WHEN upper(b.contest_name) LIKE '%INSURANCE%'             THEN 'STATE_INS_COMM'
    WHEN upper(b.contest_name) LIKE '%AGRICULTURE%'
      AND upper(b.contest_name) LIKE '%COMMISSIONER%'         THEN 'STATE_AG_COMM'
    WHEN upper(b.contest_name) LIKE '%LABOR%'
      AND upper(b.contest_name) LIKE '%COMMISSIONER%'         THEN 'STATE_LABOR'
    WHEN upper(b.contest_name) LIKE '%COMMISSIONER%'          THEN 'LOCAL_COMMISSIONER'
    WHEN upper(cr.committee_type) IN ('COUNTY_REC','COUNTY_PARTY')
      OR upper(cr.committee_name) LIKE '%REPUBLICAN%'
      OR upper(cr.committee_name) LIKE '% REC'
      OR upper(r.committee_name)  LIKE '%REPUBLICAN%'
      OR upper(r.committee_name)  LIKE '% REC'
      OR upper(r.committee_name)  LIKE '%NCGOP%'
      OR upper(r.committee_name)  LIKE '%NC GOP%'             THEN 'COUNTY_PARTY'
    WHEN upper(cr.committee_type) = 'PARTY'
      OR upper(r.committee_name) LIKE '%NCGOP%'
      OR upper(r.committee_name) LIKE '%NC GOP%'
      OR upper(r.committee_name) LIKE '%STATE REPUBLICAN%'    THEN 'STATE_PARTY'
    WHEN upper(cr.committee_type) = 'PAC'
      OR upper(r.committee_name) LIKE '%PAC%'                 THEN 'PAC'
    WHEN upper(b.contest_name) LIKE '%JUDGE%'
      OR upper(b.contest_name) LIKE '%JUSTICE%'
      OR upper(b.contest_name) LIKE '%COURT%'                 THEN 'JUDICIAL'
    WHEN upper(b.contest_name) LIKE '%SHERIFF%'               THEN 'LOCAL_SHERIFF'
    WHEN upper(b.contest_name) LIKE '%SCHOOL%'                THEN 'SCHOOL_BOARD'
    WHEN b.contest_name IS NOT NULL                           THEN 'LOCAL_OTHER'
    WHEN cr.committee_type IS NOT NULL
      OR cr.committee_name IS NOT NULL                        THEN 'PARTY_INFRA'
    ELSE 'UNCLASSIFIED'
  END                                                         AS office_level,
  regexp_replace(coalesce(b.contest_name,''), '[^0-9]', '', 'g') AS district_number,

  -- *** FIXED PARTISAN FLAG ***
  -- Priority: candidate party → committee type → committee name → BOE committee name
  CASE
    -- Candidate-level party (highest confidence)
    WHEN upper(b.party_candidate) LIKE '%REP%'                THEN 'R'
    WHEN upper(b.party_candidate) LIKE '%DEM%'                THEN 'D'
    -- Committee type from registry
    WHEN upper(cr.committee_type) IN (
      'COUNTY_REC','COUNTY_PARTY','PARTY')                     THEN 'R'
    -- Committee name contains Republican/GOP markers (registry name)
    WHEN cr.committee_name ILIKE '%REPUBLICAN%'
      OR cr.committee_name ILIKE '% REC'
      OR cr.committee_name ILIKE '%NCGOP%'
      OR cr.committee_name ILIKE '%NC GOP%'                   THEN 'R'
    -- BOE committee name (the name as filed on the donation)
    WHEN r.committee_name ILIKE '%REPUBLICAN%'
      OR r.committee_name ILIKE '% REC'
      OR r.committee_name ILIKE '%NCGOP%'
      OR r.committee_name ILIKE '%NC GOP%'
      OR r.committee_name ILIKE '%GOP%'                       THEN 'R'
    -- Democratic markers
    WHEN cr.committee_name ILIKE '%DEMOCRAT%'
      OR cr.committee_name ILIKE '%DNC%'
      OR r.committee_name ILIKE '%DEMOCRAT%'
      OR r.committee_name ILIKE '%DNC%'                       THEN 'D'
    -- Candidate committee with no party match → assume R
    -- (we only load Republican NCBOE data; candidate committees are R by default)
    WHEN cr.committee_type = 'CANDIDATE'
      AND b.party_candidate IS NULL                           THEN 'R'
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

-- Partisan flag distribution
SELECT
  partisan_flag,
  count(*)                                                     AS donations,
  round(sum(amount_numeric))                                   AS total_dollars,
  round(100.0 * count(*) / sum(count(*)) OVER (), 1)          AS pct
FROM staging.boe_donation_candidate_map
GROUP BY 1 ORDER BY 2 DESC;

-- Candidate match rate
SELECT
  count(*)                                                     AS total_donations,
  count(*) FILTER (WHERE candidate_name IS NOT NULL)          AS matched_candidate,
  round(100.0 * count(*) FILTER (WHERE candidate_name IS NOT NULL)
    / count(*), 1)                                            AS candidate_match_pct,
  count(*) FILTER (WHERE partisan_flag = 'R')                 AS r_donations,
  round(100.0 * count(*) FILTER (WHERE partisan_flag = 'R')
    / count(*), 1)                                            AS r_pct_overall
FROM staging.boe_donation_candidate_map;

-- Ed Broyhill r_pct — should now be 90%+
SELECT
  round(sum(amount_numeric))                                   AS total,
  round(sum(amount_numeric) FILTER (WHERE partisan_flag='R')) AS r_total,
  round(sum(amount_numeric) FILTER (WHERE partisan_flag='U')) AS u_total,
  round(100.0 * sum(amount_numeric) FILTER (WHERE partisan_flag='R')
    / NULLIF(sum(amount_numeric),0), 1)                       AS r_pct
FROM staging.boe_donation_candidate_map
WHERE norm_zip5 IN ('27104','27012')
  AND norm_last ILIKE '%BROYHILL%'
  AND donor_name ILIKE '%ED%';

-- Office level breakdown (STATE_GOVERNOR should still be large — Mark Robinson)
SELECT office_level,
       count(*)                                                AS donations,
       round(sum(amount_numeric))                             AS dollars
FROM staging.boe_donation_candidate_map
GROUP BY 1 ORDER BY 2 DESC;

-- Report all results. STOP — staging only, no production writes.
