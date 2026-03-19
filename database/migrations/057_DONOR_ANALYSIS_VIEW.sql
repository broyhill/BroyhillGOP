-- 057_DONOR_ANALYSIS_VIEW.sql
-- Consolidated donor view for correlations, clustering, ML
-- Joins NCBOE donations + DataTrust enrichment via voter_ncid = statevoterid
-- Run: psql $SUPABASE_DB_URL -f database/migrations/057_DONOR_ANALYSIS_VIEW.sql

-- =============================================================================
-- Donor-level aggregation with DataTrust enrichment
-- One row per donor: giving stats + demographics/scores for analysis
-- =============================================================================
CREATE OR REPLACE VIEW public.vw_donor_analysis_consolidated AS
WITH donor_agg AS (
  SELECT
    COALESCE(d.voter_ncid, 'noid_' || md5(COALESCE(d.norm_last,'') || '|' || COALESCE(d.canonical_first,'') || '|' || COALESCE(d.norm_zip5,''))) AS donor_key,
    d.voter_ncid,
    d.norm_last AS last_name,
    d.canonical_first AS first_name,
    d.norm_zip5 AS zip5,
    d.norm_city AS city,
    d.voter_party_cd AS party_raw,
    COUNT(*) AS donation_count,
    SUM(d.amount_numeric) AS total_amount,
    MIN(d.date_occurred) AS first_donation_date,
    MAX(d.date_occurred) AS last_donation_date,
    AVG(d.amount_numeric) AS avg_amount,
    MAX(d.amount_numeric) AS max_amount,
    COUNT(DISTINCT d.candidate_referendum_name) AS candidate_count,
    MODE() WITHIN GROUP (ORDER BY d.candidate_referendum_name) AS top_candidate,
    MODE() WITHIN GROUP (ORDER BY d.committee_name) AS top_committee
  FROM public.nc_boe_donations_raw d
  WHERE d.transaction_type = 'Individual'
    AND d.amount_numeric IS NOT NULL
    AND d.amount_numeric > 0
    AND d.date_occurred IS NOT NULL
  GROUP BY d.voter_ncid, d.norm_last, d.canonical_first, d.norm_zip5, d.norm_city, d.voter_party_cd
)
SELECT
  da.donor_key,
  da.voter_ncid,
  da.last_name,
  da.first_name,
  da.zip5,
  da.city,
  da.party_raw,
  da.donation_count,
  da.total_amount,
  da.first_donation_date,
  da.last_donation_date,
  da.avg_amount,
  da.max_amount,
  da.candidate_count,
  da.top_candidate,
  da.top_committee,
  -- DataTrust enrichment (when voter_ncid matches)
  dt.statevoterid AS dt_statevoterid,
  dt.registeredparty AS dt_party,
  dt.age::int AS dt_age,
  dt.sex AS dt_sex,
  dt.countyname AS dt_county,
  dt.regcity AS dt_city,
  dt.regzip5::text AS dt_zip5,
  dt.republicanpartyscore::float AS dt_republican_score,
  dt.democraticpartyscore::float AS dt_democratic_score,
  dt.turnoutgeneralscore::float AS dt_turnout_score,
  dt.voterregularitygeneral::float AS dt_voter_regularity,
  dt.householdincomemodeled AS dt_income,
  dt.educationmodeled AS dt_education,
  dt.ethnicitymodeled AS dt_ethnicity,
  dt.religionmodeled AS dt_religion,
  dt.metrotype AS dt_metro_type,
  dt.mediamarket AS dt_media_market,
  dt.congressionaldistrict AS dt_congressional_district,
  dt.statelegupperdistrict AS dt_state_senate,
  dt.stateleglowerdistrict AS dt_state_house,
  dt.coalitionid_2ndamendment::int AS dt_2nd_amendment,
  dt.coalitionid_prolife::int AS dt_prolife,
  dt.coalitionid_veteran::int AS dt_veteran,
  dt.donorflag AS dt_donor_flag,
  dt.cell AS dt_cell,
  dt.landline AS dt_landline,
  dt.email AS dt_email
FROM donor_agg da
LEFT JOIN public.nc_datatrust dt
  ON TRIM(COALESCE(da.voter_ncid::text, '')) = TRIM(COALESCE(dt.statevoterid::text, ''))
  AND da.voter_ncid IS NOT NULL;

COMMENT ON VIEW public.vw_donor_analysis_consolidated IS 'Donor-level view for ML/clustering: NCBOE donations + DataTrust demographics/scores. Use for correlations, K-means, propensity models.';
