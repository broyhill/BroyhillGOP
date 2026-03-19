-- 060_DATATRUST_DONOR_CANDIDATE_AFFINITY.sql
-- Donor–candidate affinity via nc_datatrust (251 cols)
-- Matches donor DataTrust variables against candidate DataTrust variables for commonality.
--
-- Architecture: Raw tables frozen. Uses nc_datatrust (canonical), enrichment views,
-- entity layer. See docs/DATABASE_ARCHITECTURE_RULES.md, docs/CANONICAL_TABLES_AUDIT.md.
--
-- Run: psql $SUPABASE_DB_URL -f database/migrations/060_DATATRUST_DONOR_CANDIDATE_AFFINITY.sql

-- =============================================================================
-- 1. Donor DataTrust base (donors with voter_ncid → nc_datatrust)
--    Source: vw_donor_analysis_consolidated OR donor_contribution_map + nc_datatrust
-- =============================================================================
CREATE OR REPLACE VIEW public.vw_donor_datatrust_base AS
SELECT
  COALESCE(d.voter_ncid, 'noid_' || md5(COALESCE(d.norm_last,'') || '|' || COALESCE(d.canonical_first,'') || '|' || COALESCE(d.norm_zip5,''))) AS donor_key,
  d.voter_ncid,
  d.norm_last AS last_name,
  d.canonical_first AS first_name,
  d.norm_zip5 AS zip5,
  d.norm_city AS city,
  COUNT(*) AS donation_count,
  SUM(d.amount_numeric) AS total_amount,
  MODE() WITHIN GROUP (ORDER BY d.candidate_referendum_name) AS top_candidate,
  -- DataTrust (nc_datatrust canonical)
  dt.rncid AS dt_rncid,
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
  dt.congressionaldistrict AS dt_cong_district,
  dt.statelegupperdistrict AS dt_state_senate,
  dt.stateleglowerdistrict AS dt_state_house,
  dt.coalitionid_2ndamendment::int AS dt_2nd_amendment,
  dt.coalitionid_prolife::int AS dt_prolife,
  dt.coalitionid_veteran::int AS dt_veteran,
  dt.donorflag AS dt_donor_flag,
  dt.cell AS dt_cell,
  dt.landline AS dt_landline,
  dt.email AS dt_email
FROM public.nc_boe_donations_raw d
LEFT JOIN public.nc_datatrust dt
  ON TRIM(COALESCE(d.voter_ncid::text, '')) = TRIM(COALESCE(dt.statevoterid::text, ''))
  AND d.voter_ncid IS NOT NULL
WHERE d.transaction_type = 'Individual'
  AND d.amount_numeric IS NOT NULL AND d.amount_numeric > 0
  AND d.date_occurred IS NOT NULL
GROUP BY d.voter_ncid, d.norm_last, d.canonical_first, d.norm_zip5, d.norm_city,
  dt.rncid, dt.statevoterid, dt.registeredparty, dt.age, dt.sex, dt.countyname,
  dt.regcity, dt.regzip5, dt.republicanpartyscore, dt.democraticpartyscore,
  dt.turnoutgeneralscore, dt.voterregularitygeneral, dt.householdincomemodeled,
  dt.educationmodeled, dt.ethnicitymodeled, dt.religionmodeled, dt.metrotype,
  dt.mediamarket, dt.congressionaldistrict, dt.statelegupperdistrict,
  dt.stateleglowerdistrict, dt.coalitionid_2ndamendment, dt.coalitionid_prolife,
  dt.coalitionid_veteran, dt.donorflag, dt.cell, dt.landline, dt.email;

COMMENT ON VIEW public.vw_donor_datatrust_base IS 'Donors with nc_datatrust enrichment. Use for donor–candidate affinity.';

-- =============================================================================
-- 2. Affinity function: donor DataTrust vs candidate DataTrust
--    Candidate DataTrust: from nc_datatrust where candidate has voter_ncid
--    Or: candidate_profiles / ncsbe_candidates matched to nc_voters → nc_datatrust
-- =============================================================================
CREATE OR REPLACE FUNCTION public.calc_donor_candidate_datatrust_affinity(
  p_donor_voter_ncid TEXT,
  p_candidate_voter_ncid TEXT
) RETURNS TABLE (
  affinity_score NUMERIC(5,2),
  score_breakdown JSONB,
  matching_factors TEXT[]
) AS $$
DECLARE
  v_donor RECORD;
  v_candidate RECORD;
  v_score NUMERIC := 0;
  v_weights NUMERIC := 0;
  v_breakdown JSONB := '{}'::JSONB;
  v_factors TEXT[] := ARRAY[]::TEXT[];
  v_part NUMERIC;
BEGIN
  -- Get donor DataTrust
  SELECT * INTO v_donor FROM public.nc_datatrust
  WHERE TRIM(COALESCE(statevoterid::text, '')) = TRIM(COALESCE(p_donor_voter_ncid, ''))
  LIMIT 1;

  -- Get candidate DataTrust
  SELECT * INTO v_candidate FROM public.nc_datatrust
  WHERE TRIM(COALESCE(statevoterid::text, '')) = TRIM(COALESCE(p_candidate_voter_ncid, ''))
  LIMIT 1;

  IF v_donor IS NULL OR v_candidate IS NULL THEN
    RETURN QUERY SELECT 0::NUMERIC(5,2), '{}'::JSONB, ARRAY['no_datatrust_match']::TEXT[];
    RETURN;
  END IF;

  -- 1. Republican party score (0–1) — 25% weight
  IF v_donor.republicanpartyscore IS NOT NULL AND v_candidate.republicanpartyscore IS NOT NULL THEN
    v_part := 100 * (1 - ABS(COALESCE(v_donor.republicanpartyscore::float, 0) - COALESCE(v_candidate.republicanpartyscore::float, 0)));
    v_score := v_score + GREATEST(0, LEAST(100, v_part)) * 0.25;
    v_weights := v_weights + 0.25;
    v_breakdown := v_breakdown || jsonb_build_object('republican_score', v_part);
    IF v_part > 70 THEN v_factors := array_append(v_factors, 'party_score_match'); END IF;
  END IF;

  -- 2. Turnout score — 15% weight
  IF v_donor.turnoutgeneralscore IS NOT NULL AND v_candidate.turnoutgeneralscore IS NOT NULL THEN
    v_part := 100 * (1 - ABS(COALESCE(v_donor.turnoutgeneralscore::float, 0) - COALESCE(v_candidate.turnoutgeneralscore::float, 0)));
    v_score := v_score + GREATEST(0, LEAST(100, v_part)) * 0.15;
    v_weights := v_weights + 0.15;
    v_breakdown := v_breakdown || jsonb_build_object('turnout_score', v_part);
  END IF;

  -- 3. Same county — 20% weight
  IF v_donor.countyname IS NOT NULL AND v_candidate.countyname IS NOT NULL THEN
    IF LOWER(TRIM(v_donor.countyname)) = LOWER(TRIM(v_candidate.countyname)) THEN
      v_part := 100;
      v_factors := array_append(v_factors, 'same_county');
    ELSE
      v_part := 0;
    END IF;
    v_score := v_score + v_part * 0.20;
    v_weights := v_weights + 0.20;
    v_breakdown := v_breakdown || jsonb_build_object('county_match', v_part);
  END IF;

  -- 4. Same district (state senate) — 15% weight
  IF v_donor.statelegupperdistrict IS NOT NULL AND v_candidate.statelegupperdistrict IS NOT NULL THEN
    IF TRIM(COALESCE(v_donor.statelegupperdistrict::text, '')) = TRIM(COALESCE(v_candidate.statelegupperdistrict::text, '')) THEN
      v_part := 100;
      v_factors := array_append(v_factors, 'same_state_senate');
    ELSE
      v_part := 0;
    END IF;
    v_score := v_score + v_part * 0.15;
    v_weights := v_weights + 0.15;
    v_breakdown := v_breakdown || jsonb_build_object('state_senate_match', v_part);
  END IF;

  -- 5. Coalition flags (2nd Amendment, Pro-Life, Veteran) — 25% total
  v_part := 0;
  IF v_donor.coalitionid_2ndamendment IS NOT NULL AND v_candidate.coalitionid_2ndamendment IS NOT NULL
     AND v_donor.coalitionid_2ndamendment = v_candidate.coalitionid_2ndamendment AND v_donor.coalitionid_2ndamendment > 0 THEN
    v_part := v_part + 33.33;
    v_factors := array_append(v_factors, '2nd_amendment_affinity');
  END IF;
  IF v_donor.coalitionid_prolife IS NOT NULL AND v_candidate.coalitionid_prolife IS NOT NULL
     AND v_donor.coalitionid_prolife = v_candidate.coalitionid_prolife AND v_donor.coalitionid_prolife > 0 THEN
    v_part := v_part + 33.33;
    v_factors := array_append(v_factors, 'prolife_affinity');
  END IF;
  IF v_donor.coalitionid_veteran IS NOT NULL AND v_candidate.coalitionid_veteran IS NOT NULL
     AND v_donor.coalitionid_veteran = v_candidate.coalitionid_veteran AND v_donor.coalitionid_veteran > 0 THEN
    v_part := v_part + 33.34;
    v_factors := array_append(v_factors, 'veteran_affinity');
  END IF;
  v_score := v_score + v_part * 0.25;
  v_weights := v_weights + 0.25;
  v_breakdown := v_breakdown || jsonb_build_object('coalition_match', v_part);

  -- Normalize by weights applied
  IF v_weights > 0 THEN
    v_score := v_score / v_weights * 100;
  END IF;
  v_score := LEAST(100, GREATEST(0, v_score));

  RETURN QUERY SELECT v_score::NUMERIC(5,2), v_breakdown, v_factors;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.calc_donor_candidate_datatrust_affinity IS 'Donor–candidate affinity from nc_datatrust. Pass voter_ncid for donor and candidate.';

-- =============================================================================
-- 3. Batch affinity: use as a function for specific candidate
--    Example: SELECT * FROM donor_candidates_affinity_for_candidate('BN94856');
-- =============================================================================
CREATE OR REPLACE FUNCTION public.donor_candidates_affinity_for_candidate(
  p_candidate_ncid TEXT,
  p_limit INT DEFAULT 500
) RETURNS TABLE (
  donor_key TEXT,
  donor_ncid TEXT,
  donor_last TEXT,
  donor_first TEXT,
  total_amount NUMERIC,
  donation_count BIGINT,
  affinity_score NUMERIC(5,2),
  matching_factors TEXT[]
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    dd.donor_key,
    dd.voter_ncid,
    dd.last_name,
    dd.first_name,
    dd.total_amount,
    dd.donation_count,
    (r.affinity_score)::NUMERIC(5,2),
    r.matching_factors
  FROM public.vw_donor_datatrust_base dd
  CROSS JOIN LATERAL calc_donor_candidate_datatrust_affinity(dd.voter_ncid, p_candidate_ncid) r
  WHERE dd.voter_ncid IS NOT NULL
    AND dd.dt_statevoterid IS NOT NULL
  ORDER BY r.affinity_score DESC NULLS LAST
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.donor_candidates_affinity_for_candidate IS 'Donors ranked by DataTrust affinity to a candidate (by candidate voter ncid).';
