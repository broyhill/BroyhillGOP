-- ============================================================
-- Migration 087: exec_sql helper + remaining completion fixes
-- BroyhillGOP — March 23, 2026
-- Run in Supabase SQL Editor ONE BLOCK AT A TIME
-- ============================================================

-- ============================================================
-- BLOCK 0: Create exec_sql helper (run this FIRST)
-- Allows arbitrary SQL execution via REST API
-- ============================================================
CREATE OR REPLACE FUNCTION public.exec_sql(query text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  EXECUTE query;
  result := '{"status":"ok"}'::jsonb;
  RETURN result;
EXCEPTION WHEN OTHERS THEN
  result := jsonb_build_object('status','error','message', SQLERRM, 'code', SQLSTATE);
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.query_sql(query text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  EXECUTE 'SELECT jsonb_agg(row_to_json(t)) FROM (' || query || ') t' INTO result;
  RETURN COALESCE(result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('status','error','message', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- Verify:
SELECT exec_sql('SELECT 1') AS test_exec, query_sql('SELECT 42 AS answer') AS test_query;

-- ============================================================
-- BLOCK 1: Fix apply_rncid_resolutions type mismatch
-- Creates corrected version as apply_rncid_resolutions_v2
-- ============================================================
CREATE OR REPLACE FUNCTION public.apply_rncid_resolutions_v2()
RETURNS TABLE(rows_updated bigint, boe_rncid_pct numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated bigint;
  v_pct numeric;
BEGIN
  -- Write resolved RNCIDs from queue back to nc_boe_donations_raw
  UPDATE public.nc_boe_donations_raw boe
  SET
    rncid      = q.resolved_rncid,
    voter_ncid = COALESCE(boe.voter_ncid, q.resolved_voter_ncid)
  FROM public.rncid_resolution_queue q
  WHERE q.source_table = 'nc_boe_donations_raw'
    AND q.source_id::text = boe.id::text
    AND q.resolved_rncid IS NOT NULL
    AND boe.rncid IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  SELECT ROUND(COUNT(rncid)::numeric / COUNT(*) * 100, 1)
  INTO v_pct
  FROM public.nc_boe_donations_raw;

  RETURN QUERY SELECT v_updated, v_pct;
END;
$$;

-- Verify:
SELECT * FROM apply_rncid_resolutions_v2();

-- ============================================================
-- BLOCK 2: BOE → spine RNCID write-back (Block H)
-- Stamps new BOE-matched RNCIDs onto core.person_spine
-- ============================================================
CREATE OR REPLACE FUNCTION public.backfill_spine_rncid_from_boe()
RETURNS TABLE(rows_updated bigint, spine_rncid_pct numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated bigint;
  v_pct numeric;
BEGIN
  UPDATE core.person_spine ps
  SET voter_rncid = boe.rncid, updated_at = NOW()
  FROM (
    SELECT DISTINCT ON (voter_ncid) voter_ncid, rncid
    FROM public.nc_boe_donations_raw
    WHERE voter_ncid IS NOT NULL AND rncid IS NOT NULL
    ORDER BY voter_ncid, rncid
  ) boe
  WHERE boe.voter_ncid = ps.voter_ncid
    AND ps.voter_rncid IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  SELECT ROUND(COUNT(voter_rncid)::numeric / COUNT(*) * 100, 1)
  INTO v_pct
  FROM core.person_spine;

  RETURN QUERY SELECT v_updated, v_pct;
END;
$$;

-- Verify:
SELECT * FROM backfill_spine_rncid_from_boe();

-- ============================================================
-- BLOCK 3: WinRed RNCID backfill from rnc_voter_staging
-- ============================================================
CREATE OR REPLACE FUNCTION public.backfill_winred_rncid()
RETURNS TABLE(rows_updated bigint, winred_rncid_pct numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated bigint;
  v_pct numeric;
BEGIN
  UPDATE public.winred_donors wd
  SET rncid = rvs.rncid::text
  FROM public.rnc_voter_staging rvs
  WHERE rvs.state_voter_id = wd.voter_ncid
    AND wd.rncid IS NULL
    AND wd.voter_ncid IS NOT NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  SELECT ROUND(COUNT(rncid)::numeric / COUNT(*) * 100, 1)
  INTO v_pct
  FROM public.winred_donors;

  RETURN QUERY SELECT v_updated, v_pct;
END;
$$;

-- Verify:
SELECT * FROM backfill_winred_rncid();

-- ============================================================
-- BLOCK 4: Fuzzy RNCID pass on unresolved queue (batched 20K)
-- Run this block UP TO 4 TIMES until rows_resolved = 0
-- ============================================================
CREATE OR REPLACE FUNCTION public.fuzzy_rncid_pass(batch_size int DEFAULT 20000)
RETURNS TABLE(rows_resolved bigint, still_unresolved bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_resolved bigint;
  v_unresolved bigint;
BEGIN
  SET LOCAL statement_timeout = '110000';

  UPDATE public.rncid_resolution_queue q
  SET
    resolved_rncid      = m.rncid::text,
    resolved_voter_ncid = m.state_voter_id,
    match_confidence    = m.sim,
    match_method        = 'fuzzy_last_zip',
    status              = 'resolved',
    resolved_at         = NOW()
  FROM (
    SELECT DISTINCT ON (q2.id)
      q2.id  AS queue_id,
      rvs.rncid,
      rvs.state_voter_id,
      similarity(rvs.norm_last, q2.input_last_name) AS sim
    FROM (
      SELECT * FROM public.rncid_resolution_queue
      WHERE resolved_rncid IS NULL ORDER BY id LIMIT batch_size
    ) q2
    JOIN public.rnc_voter_staging rvs
      ON rvs.zip5 = q2.input_zip
     AND rvs.norm_last % q2.input_last_name
    WHERE similarity(rvs.norm_last, q2.input_last_name) >= 0.82
    ORDER BY q2.id, similarity(rvs.norm_last, q2.input_last_name) DESC
  ) m
  WHERE q.id = m.queue_id AND q.resolved_rncid IS NULL;

  GET DIAGNOSTICS v_resolved = ROW_COUNT;

  SELECT COUNT(*) INTO v_unresolved
  FROM public.rncid_resolution_queue
  WHERE resolved_rncid IS NULL;

  RETURN QUERY SELECT v_resolved, v_unresolved;
END;
$$;

-- First fuzzy pass (run up to 4 times):
SELECT * FROM fuzzy_rncid_pass(20000);

-- ============================================================
-- BLOCK 5: Rebuild golden_record_clusters from person_spine
-- Maps BOE golden_record_id → spine person_id via voter_ncid
-- ============================================================
CREATE OR REPLACE FUNCTION public.rebuild_golden_record_clusters()
RETURNS TABLE(rows_inserted bigint, rows_total bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted bigint;
  v_total bigint;
BEGIN
  -- Insert cluster rows: each BOE golden_record_id maps to a canonical person_id
  -- via the voter_ncid → core.person_spine join
  INSERT INTO public.golden_record_clusters (golden_record_id, canonical_id, cluster_method, confidence, created_at)
  SELECT DISTINCT ON (boe.golden_record_id)
    boe.golden_record_id,
    ps.person_id,
    'spine_voter_ncid_match',
    1.0,
    NOW()
  FROM public.nc_boe_donations_raw boe
  JOIN core.person_spine ps ON ps.voter_ncid = boe.voter_ncid
  WHERE boe.golden_record_id IS NOT NULL
    AND boe.voter_ncid IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.golden_record_clusters gc
      WHERE gc.golden_record_id = boe.golden_record_id
    )
  ORDER BY boe.golden_record_id, ps.person_id
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  SELECT COUNT(*) INTO v_total FROM public.golden_record_clusters;

  RETURN QUERY SELECT v_inserted, v_total;
END;
$$;

-- Verify:
SELECT * FROM rebuild_golden_record_clusters();

-- ============================================================
-- BLOCK 6: Stamp is_donor on core.person_spine
-- ============================================================
CREATE OR REPLACE FUNCTION public.stamp_is_donor_spine()
RETURNS TABLE(total_spine bigint, is_donor_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total bigint;
  v_donor bigint;
BEGIN
  -- Add column if missing
  ALTER TABLE core.person_spine ADD COLUMN IF NOT EXISTS is_donor boolean DEFAULT false;

  -- Stamp true for anyone in contribution_map
  UPDATE core.person_spine ps
  SET is_donor = true
  FROM (SELECT DISTINCT person_id FROM core.contribution_map) cm
  WHERE cm.person_id = ps.person_id
    AND (ps.is_donor IS NULL OR ps.is_donor = false);

  SELECT COUNT(*), COUNT(CASE WHEN is_donor = true THEN 1 END)
  INTO v_total, v_donor
  FROM core.person_spine;

  RETURN QUERY SELECT v_total, v_donor;
END;
$$;

-- Verify:
SELECT * FROM stamp_is_donor_spine();

-- ============================================================
-- BLOCK 7: Insert WinRed donors into core.person_spine
-- ============================================================
CREATE OR REPLACE FUNCTION public.insert_winred_to_spine()
RETURNS TABLE(rows_inserted bigint, total_spine bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted bigint;
  v_total bigint;
BEGIN
  INSERT INTO core.person_spine (
    last_name, first_name, norm_last, norm_first, zip5,
    voter_ncid, voter_rncid, is_donor, total_contributed,
    created_at, updated_at, is_active, version
  )
  SELECT DISTINCT ON (wd.voter_ncid)
    wd.norm_last, wd.norm_first, wd.norm_last, wd.norm_first, wd.zip5,
    wd.voter_ncid,
    wd.rncid,
    true,
    wd.cash_amount,
    NOW(), NOW(), true, 1
  FROM public.winred_donors wd
  WHERE wd.voter_ncid IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM core.person_spine ps WHERE ps.voter_ncid = wd.voter_ncid
    )
  ORDER BY wd.voter_ncid, wd.id
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  SELECT COUNT(*) INTO v_total FROM core.person_spine;

  RETURN QUERY SELECT v_inserted, v_total;
END;
$$;

-- Verify:
SELECT * FROM insert_winred_to_spine();

-- ============================================================
-- BLOCK 8: Add WinRed to core.contribution_map
-- ============================================================
CREATE OR REPLACE FUNCTION public.insert_winred_to_contribution_map()
RETURNS TABLE(rows_inserted bigint, total_map bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted bigint;
  v_total bigint;
BEGIN
  INSERT INTO core.contribution_map (
    person_id, source_system, source_id, amount, transaction_date, created_at
  )
  SELECT
    ps.person_id,
    'winred',
    wd.id,
    wd.cash_amount,
    wd.donation_date,
    NOW()
  FROM public.winred_donors wd
  JOIN core.person_spine ps ON ps.voter_ncid = wd.voter_ncid
  WHERE wd.voter_ncid IS NOT NULL
  ON CONFLICT (source_system, source_id) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  SELECT COUNT(*) INTO v_total FROM core.contribution_map;

  RETURN QUERY SELECT v_inserted, v_total;
END;
$$;

-- Verify:
SELECT * FROM insert_winred_to_contribution_map();

-- ============================================================
-- BLOCK 9: Final state audit
-- ============================================================
SELECT
  'core.person_spine'              AS tbl, COUNT(*) AS rows FROM core.person_spine
UNION ALL SELECT 'core.contribution_map',       COUNT(*) FROM core.contribution_map
UNION ALL SELECT 'core.fec_donation_person_map',COUNT(*) FROM core.fec_donation_person_map
UNION ALL SELECT 'core.golden_record_person_map',COUNT(*) FROM core.golden_record_person_map
UNION ALL SELECT 'public.fec_committees',        COUNT(*) FROM public.fec_committees
UNION ALL SELECT 'public.nc_boe_donations_raw',  COUNT(*) FROM public.nc_boe_donations_raw
UNION ALL SELECT 'public.fec_donations',         COUNT(*) FROM public.fec_donations
UNION ALL SELECT 'public.winred_donors',         COUNT(*) FROM public.winred_donors
UNION ALL SELECT 'public.rnc_voter_staging',     COUNT(*) FROM public.rnc_voter_staging
UNION ALL SELECT 'public.rncid_resolution_queue',COUNT(*) FROM public.rncid_resolution_queue
UNION ALL SELECT 'public.golden_record_clusters',COUNT(*) FROM public.golden_record_clusters
ORDER BY tbl;

-- RNCID + donor coverage:
SELECT
  COUNT(*) AS total_spine,
  COUNT(voter_rncid) AS has_rncid,
  ROUND(COUNT(voter_rncid)::numeric/COUNT(*)*100,1) AS pct_rncid,
  COUNT(CASE WHEN is_donor=true THEN 1 END) AS is_donor_true,
  COUNT(CASE WHEN total_contributed>0 THEN 1 END) AS has_contributions,
  ROUND(SUM(total_contributed)) AS total_dollars
FROM core.person_spine;
