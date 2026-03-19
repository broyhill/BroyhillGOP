-- 062_DATATRUST_FULL_2500_AFFINITY.sql
-- Affinity using full DataTrust: nc_datatrust (251) + acxiom_consumer_data (149) = ~400 variables
-- The "2,500" DataTrust concept: VoterFile 251 + Acxiom 149 + Issue Positions 46+ + other API fields
-- Join: nc_datatrust.rncid = acxiom_consumer_data.rnc_regid (Acxiom API uses RNC_RegID)
--
-- Prerequisite: 060, 061. Requires acxiom_consumer_data table.
-- Run: psql $SUPABASE_DB_URL -f database/migrations/062_DATATRUST_FULL_2500_AFFINITY.sql

-- =============================================================================
-- 1. Function: get full DataTrust JSONB for a voter (nc_datatrust + acxiom)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_datatrust_full_for_ncid(p_ncid TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_dt JSONB;
  v_ax JSONB;
  v_rncid TEXT;
BEGIN
  SELECT to_jsonb(dt.*), dt.rncid INTO v_dt, v_rncid
  FROM public.nc_datatrust dt
  WHERE TRIM(COALESCE(dt.statevoterid::text, '')) = TRIM(COALESCE(p_ncid, ''))
  LIMIT 1;

  IF v_dt IS NULL THEN
    RETURN NULL;
  END IF;

  -- Try to get acxiom data (join on rnc_regid = rncid; column may be rnc_regid or rnc_reg_id)
  BEGIN
    SELECT jsonb_object_agg('ax_' || key, value) INTO v_ax
    FROM jsonb_each_text(
      (SELECT to_jsonb(a.*) FROM public.acxiom_consumer_data a
       WHERE TRIM(COALESCE(a.rnc_regid::text, '')) = TRIM(COALESCE(v_rncid, ''))
          OR TRIM(COALESCE(a.rnc_reg_id::text, '')) = TRIM(COALESCE(v_rncid, ''))
          OR TRIM(COALESCE(a.rncid::text, '')) = TRIM(COALESCE(v_rncid, ''))
       LIMIT 1)
    );
  EXCEPTION WHEN undefined_table OR undefined_column THEN
    v_ax := '{}'::jsonb;
  END;

  RETURN v_dt || COALESCE(v_ax, '{}'::jsonb);
END;
$$;

COMMENT ON FUNCTION public.get_datatrust_full_for_ncid IS 'Returns merged nc_datatrust + acxiom_consumer_data as JSONB for affinity. ~400 variables when acxiom exists.';

-- =============================================================================
-- 2. Affinity using ALL DataTrust variables (nc_datatrust + acxiom)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.calc_donor_candidate_datatrust_affinity_full(
  p_donor_voter_ncid TEXT,
  p_candidate_voter_ncid TEXT,
  p_exclude_pattern TEXT DEFAULT '^(statevoterid|rncid|sourceid|firstname|lastname|regcity|regzip|regstreet|ax_statevoterid|ax_rnc_regid|ax_rnc_reg_id|ax_rncid)'
) RETURNS TABLE (
  affinity_score NUMERIC(5,2),
  cols_compared INT,
  cols_matched INT,
  score_breakdown JSONB
) AS $$
DECLARE
  v_donor JSONB;
  v_candidate JSONB;
  v_compared INT := 0;
  v_matched INT := 0;
  v_score NUMERIC := 0;
  v_key TEXT;
  v_d_val TEXT;
  v_c_val TEXT;
  v_part NUMERIC;
BEGIN
  v_donor := public.get_datatrust_full_for_ncid(p_donor_voter_ncid);
  v_candidate := public.get_datatrust_full_for_ncid(p_candidate_voter_ncid);

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
    jsonb_build_object('compared', v_compared, 'matched', v_matched, 'source', 'nc_datatrust+acxiom');
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.calc_donor_candidate_datatrust_affinity_full IS 'Affinity across ALL DataTrust variables: nc_datatrust (251) + acxiom_consumer_data (149). Uses get_datatrust_full_for_ncid.';

-- =============================================================================
-- 3. Batch: donors ranked by full DataTrust affinity to candidate
-- =============================================================================
CREATE OR REPLACE FUNCTION public.donor_candidates_affinity_full_for_candidate(
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
  cols_compared INT,
  cols_matched INT
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
    r.cols_compared,
    r.cols_matched
  FROM public.vw_donor_datatrust_base dd
  CROSS JOIN LATERAL calc_donor_candidate_datatrust_affinity_full(dd.voter_ncid, p_candidate_ncid) r
  WHERE dd.voter_ncid IS NOT NULL
    AND dd.dt_statevoterid IS NOT NULL
  ORDER BY r.affinity_score DESC NULLS LAST
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.donor_candidates_affinity_full_for_candidate IS 'Donors ranked by full DataTrust affinity (~400 vars: nc_datatrust + acxiom).';
