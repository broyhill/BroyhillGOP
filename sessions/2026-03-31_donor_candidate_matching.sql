-- ============================================================================
-- DONOR → CANDIDATE MATCHING ENGINE
-- BroyhillGOP — March 31, 2026
-- Authority: Ed Broyhill
--
-- PURPOSE: Link every donation in nc_boe_donations_raw to the candidate
-- it benefits, using the full chain:
--
--   nc_boe_donations_raw.committee_sboe_id
--       → committee_registry.sboe_id
--           → committee_registry.candidate_name + committee_type
--               → ncsbe_candidates (office, district, party, county, cycle)
--
-- OUTPUT: staging.boe_donation_candidate_map
--   One row per donation with full candidate attribution.
--   Used for:
--     - donor_political_footprint tier breakdown
--     - office_pac_affinity scoring
--     - Pass 5 committee loyalty fingerprint enrichment
--     - Clout scoring (which offices, which districts, how many cycles)
--
-- TABLES USED:
--   public.nc_boe_donations_raw    — 338,223 clean rows
--   public.committee_registry      — 10,975 rows (sboe_id → candidate + type)
--   public.ncsbe_candidates        — 55,985 rows (candidate → office + district)
-- ============================================================================

-- ============================================================================
-- STEP 0 — Baseline check
-- ============================================================================
SELECT
  count(*)                                                     AS total_boe_rows,
  count(DISTINCT committee_sboe_id)                           AS distinct_committees,
  count(*) FILTER (WHERE committee_sboe_id IS NOT NULL)       AS has_sboe_id
FROM public.nc_boe_donations_raw
WHERE transaction_type = 'Individual'
  AND date_occurred >= '2015-01-01'
  AND date_occurred <= '2026-12-31';

-- How many committees match the registry?
SELECT
  count(DISTINCT r.committee_sboe_id)                         AS boe_committees,
  count(DISTINCT cr.sboe_id)                                  AS matched_in_registry,
  count(DISTINCT r.committee_sboe_id) FILTER (
    WHERE cr.sboe_id IS NULL
  )                                                           AS unmatched
FROM public.nc_boe_donations_raw r
LEFT JOIN public.committee_registry cr ON cr.sboe_id = r.committee_sboe_id
WHERE r.transaction_type = 'Individual'
  AND r.date_occurred >= '2015-01-01';

-- ============================================================================
-- STEP 1 — Build donation → candidate map
-- ============================================================================
DROP TABLE IF EXISTS staging.boe_donation_candidate_map;

CREATE TABLE staging.boe_donation_candidate_map AS
SELECT
  -- Donation fields
  r.id                                                         AS boe_id,
  r.donor_name,
  r.norm_last,
  r.norm_first,
  r.norm_zip5,
  r.amount_numeric,
  r.date_occurred,
  EXTRACT(year FROM r.date_occurred)::int                     AS election_year,

  -- Committee fields (from committee_registry)
  r.committee_sboe_id,
  cr.committee_name,
  cr.committee_type,                -- CANDIDATE, COUNTY_REC, PAC, PARTY, etc.
  cr.source_level,                  -- STATE / FEDERAL
  cr.total_received                 AS committee_total_received,
  cr.fec_committee_id,              -- FEC bridge if federal

  -- Candidate fields (from ncsbe_candidates)
  nc.candidate_name,
  nc.contest_name,                  -- "NC SENATE DISTRICT 30" etc.
  nc.county                         AS candidate_county,
  nc.party                          AS candidate_party,
  nc.filing_date,
  nc.election_date,

  -- Derived fields
  CASE
    WHEN upper(nc.contest_name) LIKE '%U.S. SENATE%'
      OR upper(nc.contest_name) LIKE '%US SENATE%'           THEN 'FEDERAL_SENATE'
    WHEN upper(nc.contest_name) LIKE '%U.S. HOUSE%'
      OR upper(nc.contest_name) LIKE '%US HOUSE%'
      OR upper(nc.contest_name) LIKE '%CONGRESS%'            THEN 'FEDERAL_HOUSE'
    WHEN upper(nc.contest_name) LIKE '%NC SENATE%'
      OR upper(nc.contest_name) LIKE '%STATE SENATE%'        THEN 'STATE_SENATE'
    WHEN upper(nc.contest_name) LIKE '%NC HOUSE%'
      OR upper(nc.contest_name) LIKE '%STATE HOUSE%'         THEN 'STATE_HOUSE'
    WHEN upper(nc.contest_name) LIKE '%GOVERNOR%'            THEN 'STATE_GOVERNOR'
    WHEN upper(nc.contest_name) LIKE '%ATTORNEY GENERAL%'    THEN 'STATE_AG'
    WHEN upper(nc.contest_name) LIKE '%TREASURER%'           THEN 'STATE_TREASURER'
    WHEN upper(nc.contest_name) LIKE '%AUDITOR%'             THEN 'STATE_AUDITOR'
    WHEN upper(nc.contest_name) LIKE '%LIEUTENANT%'          THEN 'STATE_LT_GOV'
    WHEN upper(nc.contest_name) LIKE '%SUPERINTENDENT%'      THEN 'STATE_SUPER'
    WHEN upper(nc.contest_name) LIKE '%COMMISSIONER%'
      AND upper(nc.contest_name) LIKE '%AGRICULTURE%'        THEN 'STATE_AG_COMM'
    WHEN upper(nc.contest_name) LIKE '%COMMISSIONER%'
      AND upper(nc.contest_name) LIKE '%INSURANCE%'          THEN 'STATE_INS_COMM'
    WHEN upper(nc.contest_name) LIKE '%COMMISSIONER%'
      AND upper(nc.contest_name) LIKE '%LABOR%'              THEN 'STATE_LABOR'
    WHEN upper(cr.committee_type) LIKE '%COUNTY%REC%'
      OR upper(cr.committee_name) LIKE '%REPUBLICAN%COUNTY%' THEN 'COUNTY_PARTY'
    WHEN upper(cr.committee_type) LIKE '%PAC%'               THEN 'PAC'
    WHEN upper(cr.committee_type) LIKE '%PARTY%'             THEN 'STATE_PARTY'
    WHEN upper(nc.contest_name) LIKE '%JUDGE%'
      OR upper(nc.contest_name) LIKE '%JUSTICE%'
      OR upper(nc.contest_name) LIKE '%COURT%'               THEN 'JUDICIAL'
    WHEN upper(nc.contest_name) LIKE '%SHERIFF%'             THEN 'LOCAL_SHERIFF'
    WHEN upper(nc.contest_name) LIKE '%COMMISSIONER%'        THEN 'LOCAL_COMMISSIONER'
    WHEN upper(nc.contest_name) LIKE '%SCHOOL%'              THEN 'SCHOOL_BOARD'
    WHEN nc.contest_name IS NOT NULL                         THEN 'LOCAL_OTHER'
    ELSE 'UNCLASSIFIED'
  END                                                         AS office_level,

  -- District number extraction (NC SENATE DISTRICT 30 → 30)
  regexp_replace(nc.contest_name, '[^0-9]', '', 'g')         AS district_number,

  -- Partisan lean flag
  CASE
    WHEN upper(nc.party) LIKE '%REP%'                        THEN 'R'
    WHEN upper(nc.party) LIKE '%DEM%'                        THEN 'D'
    WHEN upper(cr.committee_type) IN ('COUNTY_REC','NCGOP_AUXILIARY','OFFICIAL_STATE_PARTY') THEN 'R'
    ELSE 'U'
  END                                                         AS partisan_flag

FROM public.nc_boe_donations_raw r
-- Join to committee registry
LEFT JOIN public.committee_registry cr
  ON cr.sboe_id = r.committee_sboe_id
-- Join to candidate registry on candidate name
LEFT JOIN LATERAL (
  SELECT nc2.candidate_name, nc2.contest_name, nc2.county,
         nc2.party, nc2.filing_date, nc2.election_date
  FROM public.ncsbe_candidates nc2
  WHERE upper(trim(nc2.candidate_name)) = upper(trim(cr.candidate_name))
    AND cr.candidate_name IS NOT NULL
    AND cr.candidate_name != ''
  ORDER BY nc2.election_date DESC  -- most recent cycle first
  LIMIT 1
) nc ON true
WHERE r.transaction_type = 'Individual'
  AND r.amount_numeric > 0
  AND r.date_occurred >= '2015-01-01'
  AND r.date_occurred <= '2026-12-31';

-- ============================================================================
-- STEP 2 — Validation
-- ============================================================================

-- Overall match rate
SELECT
  count(*)                                                     AS total_donations,
  count(*) FILTER (WHERE committee_name IS NOT NULL)          AS matched_committee,
  count(*) FILTER (WHERE candidate_name IS NOT NULL)          AS matched_candidate,
  count(*) FILTER (WHERE office_level != 'UNCLASSIFIED')      AS classified_office,
  round(100.0 * count(*) FILTER (WHERE candidate_name IS NOT NULL)
    / count(*), 1)                                            AS candidate_match_pct
FROM staging.boe_donation_candidate_map;

-- Office level breakdown
SELECT office_level, count(*) AS donations, round(sum(amount_numeric)) AS total_dollars
FROM staging.boe_donation_candidate_map
GROUP BY 1
ORDER BY 2 DESC;

-- Top 20 candidates by total donations received
SELECT
  candidate_name,
  contest_name,
  office_level,
  count(*)                                                     AS gifts,
  count(DISTINCT norm_last || norm_zip5)                      AS unique_donors,
  round(sum(amount_numeric))                                  AS total_received
FROM staging.boe_donation_candidate_map
WHERE candidate_name IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY total_received DESC
LIMIT 20;

-- Canary: Ed Broyhill's donations — all should have candidate attribution
SELECT
  date_occurred,
  donor_name,
  committee_name,
  candidate_name,
  office_level,
  contest_name,
  amount_numeric
FROM staging.boe_donation_candidate_map
WHERE norm_zip5 IN ('27104','27012')
  AND norm_last ILIKE '%BROYHILL%'
  AND donor_name ILIKE '%ED%'
ORDER BY date_occurred DESC
LIMIT 20;

-- ============================================================================
-- STEP 3 — Donor political footprint (aggregated view per donor)
-- ============================================================================
DROP TABLE IF EXISTS staging.donor_political_footprint;

CREATE TABLE staging.donor_political_footprint AS
SELECT
  -- Donor identity (will be replaced by person_id after rollup merges)
  norm_last,
  norm_zip5                                                    AS zip5,

  -- Total giving across ALL committees
  count(*)                                                     AS total_transactions,
  round(sum(amount_numeric))                                  AS total_all_giving,
  count(DISTINCT committee_sboe_id)                           AS committees_funded,
  count(DISTINCT candidate_name)                              AS candidates_funded,
  count(DISTINCT election_year)                               AS active_cycles,
  min(date_occurred)                                          AS first_gift,
  max(date_occurred)                                          AS last_gift,

  -- By office level
  round(sum(amount_numeric) FILTER (WHERE office_level LIKE 'FEDERAL%'))   AS federal_giving,
  round(sum(amount_numeric) FILTER (WHERE office_level LIKE 'STATE_%'))    AS state_giving,
  round(sum(amount_numeric) FILTER (WHERE office_level LIKE 'LOCAL%'))     AS local_giving,
  round(sum(amount_numeric) FILTER (WHERE office_level = 'COUNTY_PARTY'))  AS county_party_giving,
  round(sum(amount_numeric) FILTER (WHERE office_level = 'PAC'))           AS pac_giving,
  round(sum(amount_numeric) FILTER (WHERE office_level = 'JUDICIAL'))      AS judicial_giving,
  round(sum(amount_numeric) FILTER (WHERE office_level = 'STATE_SENATE'))  AS state_senate_giving,
  round(sum(amount_numeric) FILTER (WHERE office_level = 'STATE_HOUSE'))   AS state_house_giving,

  -- Partisan lean
  round(sum(amount_numeric) FILTER (WHERE partisan_flag = 'R'))            AS r_giving,
  round(sum(amount_numeric) FILTER (WHERE partisan_flag = 'D'))            AS d_giving,
  round(100.0 * sum(amount_numeric) FILTER (WHERE partisan_flag = 'R')
    / NULLIF(sum(amount_numeric), 0), 1)                      AS r_pct,

  -- Sophistication signals
  count(DISTINCT office_level)                                AS office_levels_funded,
  count(DISTINCT district_number) FILTER (
    WHERE district_number != ''
  )                                                           AS districts_funded,
  max(amount_numeric)                                         AS largest_single_gift,

  -- Top candidate (by dollars given)
  (SELECT candidate_name FROM staging.boe_donation_candidate_map sub
   WHERE sub.norm_last = m.norm_last AND sub.norm_zip5 = m.norm_zip5
     AND sub.candidate_name IS NOT NULL
   GROUP BY candidate_name ORDER BY sum(amount_numeric) DESC LIMIT 1
  )                                                           AS top_candidate

FROM staging.boe_donation_candidate_map m
GROUP BY norm_last, norm_zip5;

-- Top 30 donors by total giving (pre-rollup)
SELECT
  norm_last, zip5, total_all_giving, total_transactions,
  committees_funded, candidates_funded, active_cycles,
  federal_giving, state_giving, r_pct, top_candidate
FROM staging.donor_political_footprint
ORDER BY total_all_giving DESC
LIMIT 30;

-- Canary: Ed Broyhill footprint
SELECT *
FROM staging.donor_political_footprint
WHERE norm_last ILIKE '%BROYHILL%'
  AND zip5 IN ('27104','27012')
ORDER BY total_all_giving DESC;

-- ============================================================================
-- Report back:
-- 1. total_donations, matched_candidate, candidate_match_pct
-- 2. Office level breakdown table
-- 3. Top 20 candidates by dollars received
-- 4. Ed Broyhill canary (20 rows)
-- 5. Ed Broyhill footprint row
-- STOP — await Ed authorization before any production writes
-- ============================================================================
