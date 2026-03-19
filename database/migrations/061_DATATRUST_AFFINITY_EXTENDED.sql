-- 061_DATATRUST_AFFINITY_EXTENDED.sql
-- Extended donor–candidate affinity using broad nc_datatrust variable overlap
-- Matches donor DataTrust variables against candidate DataTrust variables for commonality.
-- Uses 40+ variables (scores, geography, coalitions, demographics, vote history).
--
-- Prerequisite: 060_DATATRUST_DONOR_CANDIDATE_AFFINITY.sql
-- Run: psql $SUPABASE_DB_URL -f database/migrations/061_DATATRUST_AFFINITY_EXTENDED.sql

-- =============================================================================
-- 1. Extended affinity function: broad variable overlap (40+ nc_datatrust cols)
--    Weights: scores 30%, geography 25%, coalitions 20%, demographics 15%, vote history 10%
-- =============================================================================
CREATE OR REPLACE FUNCTION public.calc_donor_candidate_datatrust_affinity_extended(
  p_donor_voter_ncid TEXT,
  p_candidate_voter_ncid TEXT,
  p_weights JSONB DEFAULT NULL  -- optional override: {"scores":0.30,"geo":0.25,"coalitions":0.20,"demo":0.15,"votehist":0.10}
) RETURNS TABLE (
  affinity_score NUMERIC(5,2),
  score_breakdown JSONB,
  matching_factors TEXT[]
) AS $$
DECLARE
  v_donor RECORD;
  v_candidate RECORD;
  v_score NUMERIC := 0;
  v_breakdown JSONB := '{}'::JSONB;
  v_factors TEXT[] := ARRAY[]::TEXT[];
  v_part NUMERIC;
  v_w_scores NUMERIC := 0.30;
  v_w_geo NUMERIC := 0.25;
  v_w_coal NUMERIC := 0.20;
  v_w_demo NUMERIC := 0.15;
  v_w_vh NUMERIC := 0.10;
  v_match_cnt INT := 0;
  v_total_vh INT := 0;
BEGIN
  IF p_weights IS NOT NULL THEN
    v_w_scores := COALESCE((p_weights->>'scores')::float, v_w_scores);
    v_w_geo := COALESCE((p_weights->>'geo')::float, v_w_geo);
    v_w_coal := COALESCE((p_weights->>'coalitions')::float, v_w_coal);
    v_w_demo := COALESCE((p_weights->>'demo')::float, v_w_demo);
    v_w_vh := COALESCE((p_weights->>'votehist')::float, v_w_vh);
  END IF;

  SELECT * INTO v_donor FROM public.nc_datatrust
  WHERE TRIM(COALESCE(statevoterid::text, '')) = TRIM(COALESCE(p_donor_voter_ncid, ''))
  LIMIT 1;

  SELECT * INTO v_candidate FROM public.nc_datatrust
  WHERE TRIM(COALESCE(statevoterid::text, '')) = TRIM(COALESCE(p_candidate_voter_ncid, ''))
  LIMIT 1;

  IF v_donor IS NULL OR v_candidate IS NULL THEN
    RETURN QUERY SELECT 0::NUMERIC(5,2), '{}'::JSONB, ARRAY['no_datatrust_match']::TEXT[];
    RETURN;
  END IF;

  -- === SCORES (30%) ===
  v_part := 0;
  IF v_donor.republicanpartyscore IS NOT NULL AND v_candidate.republicanpartyscore IS NOT NULL THEN
    v_part := v_part + 100 * (1 - LEAST(1, ABS(COALESCE(v_donor.republicanpartyscore::float, 0) - COALESCE(v_candidate.republicanpartyscore::float, 0))));
    IF v_part > 70 THEN v_factors := array_append(v_factors, 'party_score_match'); END IF;
  END IF;
  IF v_donor.turnoutgeneralscore IS NOT NULL AND v_candidate.turnoutgeneralscore IS NOT NULL THEN
    v_part := v_part + 100 * (1 - LEAST(1, ABS(COALESCE(v_donor.turnoutgeneralscore::float, 0) - COALESCE(v_candidate.turnoutgeneralscore::float, 0))));
  END IF;
  IF v_donor.voterregularitygeneral IS NOT NULL AND v_candidate.voterregularitygeneral IS NOT NULL THEN
    v_part := v_part + 100 * (1 - LEAST(1, ABS(COALESCE(v_donor.voterregularitygeneral::float, 0) - COALESCE(v_candidate.voterregularitygeneral::float, 0))));
  END IF;
  v_part := LEAST(100, v_part / 3.0);  -- avg of up to 3 scores
  v_score := v_score + v_part * v_w_scores;
  v_breakdown := v_breakdown || jsonb_build_object('scores', ROUND(v_part, 2));

  -- === GEOGRAPHY (25%) ===
  v_part := 0;
  IF v_donor.countyname IS NOT NULL AND v_candidate.countyname IS NOT NULL
     AND LOWER(TRIM(v_donor.countyname)) = LOWER(TRIM(v_candidate.countyname)) THEN
    v_part := v_part + 40;
    v_factors := array_append(v_factors, 'same_county');
  END IF;
  IF v_donor.statelegupperdistrict IS NOT NULL AND v_candidate.statelegupperdistrict IS NOT NULL
     AND TRIM(COALESCE(v_donor.statelegupperdistrict::text, '')) = TRIM(COALESCE(v_candidate.statelegupperdistrict::text, '')) THEN
    v_part := v_part + 30;
    v_factors := array_append(v_factors, 'same_state_senate');
  END IF;
  IF v_donor.stateleglowerdistrict IS NOT NULL AND v_candidate.stateleglowerdistrict IS NOT NULL
     AND TRIM(COALESCE(v_donor.stateleglowerdistrict::text, '')) = TRIM(COALESCE(v_candidate.stateleglowerdistrict::text, '')) THEN
    v_part := v_part + 20;
    v_factors := array_append(v_factors, 'same_state_house');
  END IF;
  IF v_donor.congressionaldistrict IS NOT NULL AND v_candidate.congressionaldistrict IS NOT NULL
     AND TRIM(COALESCE(v_donor.congressionaldistrict::text, '')) = TRIM(COALESCE(v_candidate.congressionaldistrict::text, '')) THEN
    v_part := v_part + 10;
    v_factors := array_append(v_factors, 'same_congressional');
  END IF;
  v_part := LEAST(100, v_part);
  v_score := v_score + v_part * v_w_geo;
  v_breakdown := v_breakdown || jsonb_build_object('geography', ROUND(v_part, 2));

  -- === COALITIONS (20%) ===
  v_part := 0;
  IF v_donor.coalitionid_2ndamendment IS NOT NULL AND v_candidate.coalitionid_2ndamendment IS NOT NULL
     AND v_donor.coalitionid_2ndamendment = v_candidate.coalitionid_2ndamendment AND v_donor.coalitionid_2ndamendment > 0 THEN
    v_part := v_part + 25; v_factors := array_append(v_factors, '2nd_amendment_affinity');
  END IF;
  IF v_donor.coalitionid_prolife IS NOT NULL AND v_candidate.coalitionid_prolife IS NOT NULL
     AND v_donor.coalitionid_prolife = v_candidate.coalitionid_prolife AND v_donor.coalitionid_prolife > 0 THEN
    v_part := v_part + 25; v_factors := array_append(v_factors, 'prolife_affinity');
  END IF;
  IF v_donor.coalitionid_veteran IS NOT NULL AND v_candidate.coalitionid_veteran IS NOT NULL
     AND v_donor.coalitionid_veteran = v_candidate.coalitionid_veteran AND v_donor.coalitionid_veteran > 0 THEN
    v_part := v_part + 25; v_factors := array_append(v_factors, 'veteran_affinity');
  END IF;
  -- Additional coalitions if columns exist (wrap in block to avoid errors if missing)
  BEGIN
    IF v_donor.coalitionid_socialconservative IS NOT NULL AND v_candidate.coalitionid_socialconservative IS NOT NULL
       AND v_donor.coalitionid_socialconservative = v_candidate.coalitionid_socialconservative AND v_donor.coalitionid_socialconservative > 0 THEN
      v_part := v_part + 12.5; v_factors := array_append(v_factors, 'social_conservative_affinity');
    END IF;
  EXCEPTION WHEN undefined_column THEN NULL;
  END;
  BEGIN
    IF v_donor.coalitionid_fiscalconservative IS NOT NULL AND v_candidate.coalitionid_fiscalconservative IS NOT NULL
       AND v_donor.coalitionid_fiscalconservative = v_candidate.coalitionid_fiscalconservative AND v_donor.coalitionid_fiscalconservative > 0 THEN
      v_part := v_part + 12.5; v_factors := array_append(v_factors, 'fiscal_conservative_affinity');
    END IF;
  EXCEPTION WHEN undefined_column THEN NULL;
  END;
  v_part := LEAST(100, v_part);
  v_score := v_score + v_part * v_w_coal;
  v_breakdown := v_breakdown || jsonb_build_object('coalitions', ROUND(v_part, 2));

  -- === DEMOGRAPHICS (15%) ===
  v_part := 0;
  IF v_donor.age IS NOT NULL AND v_candidate.age IS NOT NULL THEN
    v_part := v_part + 100 * (1 - LEAST(1, ABS((v_donor.age::int - v_candidate.age::int) / 30.0)));
  END IF;
  IF v_donor.sex IS NOT NULL AND v_candidate.sex IS NOT NULL
     AND LOWER(TRIM(v_donor.sex)) = LOWER(TRIM(v_candidate.sex)) THEN
    v_part := v_part + 50;
  END IF;
  IF v_donor.educationmodeled IS NOT NULL AND v_candidate.educationmodeled IS NOT NULL
     AND LOWER(TRIM(v_donor.educationmodeled)) = LOWER(TRIM(v_candidate.educationmodeled)) THEN
    v_part := v_part + 50; v_factors := array_append(v_factors, 'education_match');
  END IF;
  IF v_donor.householdincomemodeled IS NOT NULL AND v_candidate.householdincomemodeled IS NOT NULL
     AND LOWER(TRIM(v_donor.householdincomemodeled)) = LOWER(TRIM(v_candidate.householdincomemodeled)) THEN
    v_part := v_part + 50; v_factors := array_append(v_factors, 'income_match');
  END IF;
  IF v_donor.registeredparty IS NOT NULL AND v_candidate.registeredparty IS NOT NULL
     AND LOWER(TRIM(v_donor.registeredparty)) = LOWER(TRIM(v_candidate.registeredparty)) THEN
    v_part := v_part + 50; v_factors := array_append(v_factors, 'registered_party_match');
  END IF;
  v_part := LEAST(100, v_part / 2.5);  -- normalize (up to 5 factors, avg)
  v_score := v_score + v_part * v_w_demo;
  v_breakdown := v_breakdown || jsonb_build_object('demographics', ROUND(v_part, 2));

  -- === VOTE HISTORY (10%) - match vh* columns where both voted same way ===
  -- Uses jsonb to discover vh06g, vh08g, ... vh24g dynamically (handles schema variation)
  SELECT COUNT(*) INTO v_match_cnt FROM (
    SELECT 1
    FROM jsonb_each_text(to_jsonb(v_donor)) d
    JOIN jsonb_each_text(to_jsonb(v_candidate)) c ON d.key = c.key
    WHERE d.key ~ '^vh[0-9]{2}[gp]$'
      AND d.value IS NOT NULL AND TRIM(d.value) != ''
      AND c.value IS NOT NULL AND TRIM(c.value) != ''
      AND LOWER(TRIM(d.value)) = LOWER(TRIM(c.value))
  ) x;
  SELECT COUNT(*) INTO v_total_vh FROM (
    SELECT 1
    FROM jsonb_each_text(to_jsonb(v_donor)) d
    JOIN jsonb_each_text(to_jsonb(v_candidate)) c ON d.key = c.key
    WHERE d.key ~ '^vh[0-9]{2}[gp]$'
      AND d.value IS NOT NULL AND TRIM(d.value) != ''
      AND c.value IS NOT NULL AND TRIM(c.value) != ''
  ) x;
  IF v_total_vh > 0 THEN
    v_part := 100.0 * v_match_cnt / v_total_vh;
  ELSE
    v_part := 50;  -- neutral if no vote history
  END IF;
  v_score := v_score + v_part * v_w_vh;
  v_breakdown := v_breakdown || jsonb_build_object('vote_history', ROUND(v_part, 2), 'vh_matched', v_match_cnt, 'vh_total', v_total_vh);

  v_score := LEAST(100, GREATEST(0, v_score * 100 / (v_w_scores + v_w_geo + v_w_coal + v_w_demo + v_w_vh)));

  RETURN QUERY SELECT v_score::NUMERIC(5,2), v_breakdown, v_factors;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.calc_donor_candidate_datatrust_affinity_extended IS 'Extended donor–candidate affinity using 40+ nc_datatrust variables. Pass optional p_weights JSONB to tune category weights.';

-- =============================================================================
-- 2. Batch affinity (extended): donors ranked by extended affinity to candidate
-- =============================================================================
CREATE OR REPLACE FUNCTION public.donor_candidates_affinity_extended_for_candidate(
  p_candidate_ncid TEXT,
  p_limit INT DEFAULT 500,
  p_weights JSONB DEFAULT NULL
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
  CROSS JOIN LATERAL calc_donor_candidate_datatrust_affinity_extended(dd.voter_ncid, p_candidate_ncid, p_weights) r
  WHERE dd.voter_ncid IS NOT NULL
    AND dd.dt_statevoterid IS NOT NULL
  ORDER BY r.affinity_score DESC NULLS LAST
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.donor_candidates_affinity_extended_for_candidate IS 'Donors ranked by extended DataTrust affinity (40+ vars) to a candidate. Use p_weights to tune category weights.';

-- =============================================================================
-- 3. Dynamic all-column affinity: compare ALL overlapping nc_datatrust columns
--    Excludes id/keys; numeric = proximity, categorical = exact match
-- =============================================================================
CREATE OR REPLACE FUNCTION public.calc_donor_candidate_datatrust_affinity_all_cols(
  p_donor_voter_ncid TEXT,
  p_candidate_voter_ncid TEXT,
  p_exclude_pattern TEXT DEFAULT '^(statevoterid|rncid|sourceid|firstname|lastname|regcity|regzip|regstreet)'  -- exclude identifiers
) RETURNS TABLE (
  affinity_score NUMERIC(5,2),
  cols_compared INT,
  cols_matched INT,
  score_breakdown JSONB
) AS $$
DECLARE
  v_donor JSONB;
  v_candidate JSONB;
  v_d_keys TEXT[];
  v_score NUMERIC := 0;
  v_compared INT := 0;
  v_matched INT := 0;
  v_key TEXT;
  v_d_val TEXT;
  v_c_val TEXT;
  v_part NUMERIC;
BEGIN
  SELECT to_jsonb(d.*) INTO v_donor FROM public.nc_datatrust d
  WHERE TRIM(COALESCE(d.statevoterid::text, '')) = TRIM(COALESCE(p_donor_voter_ncid, '')) LIMIT 1;

  SELECT to_jsonb(c.*) INTO v_candidate FROM public.nc_datatrust c
  WHERE TRIM(COALESCE(c.statevoterid::text, '')) = TRIM(COALESCE(p_candidate_voter_ncid, '')) LIMIT 1;

  IF v_donor IS NULL OR v_candidate IS NULL THEN
    RETURN QUERY SELECT 0::NUMERIC(5,2), 0, 0, '{}'::JSONB;
    RETURN;
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(v_donor)
  LOOP
    IF v_key !~ p_exclude_pattern AND v_candidate ? v_key THEN
      v_d_val := v_donor->>v_key;
      v_c_val := v_candidate->>v_key;
      IF v_d_val IS NOT NULL AND TRIM(v_d_val) != '' AND v_c_val IS NOT NULL AND TRIM(v_c_val) != '' THEN
        v_compared := v_compared + 1;
        IF v_d_val ~ '^-?[0-9]+\.?[0-9]*$' AND v_c_val ~ '^-?[0-9]+\.?[0-9]*$' THEN
          v_part := 100 * (1 - LEAST(1, ABS(v_d_val::float - v_c_val::float) / NULLIF(1 + GREATEST(ABS(v_d_val::float), ABS(v_c_val::float)), 0)));
          v_score := v_score + GREATEST(0, v_part);
        ELSIF LOWER(TRIM(v_d_val)) = LOWER(TRIM(v_c_val)) THEN
          v_score := v_score + 100;
          v_matched := v_matched + 1;
        END IF;
      END IF;
    END IF;
  END LOOP;

  IF v_compared > 0 THEN
    v_score := LEAST(100, v_score / v_compared);
  END IF;

  RETURN QUERY SELECT
    v_score::NUMERIC(5,2),
    v_compared,
    v_matched,
    jsonb_build_object('compared', v_compared, 'matched', v_matched);
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.calc_donor_candidate_datatrust_affinity_all_cols IS 'Dynamic affinity across ALL overlapping nc_datatrust columns. Numeric=proximity, categorical=exact match. Excludes identifier columns by default.';
