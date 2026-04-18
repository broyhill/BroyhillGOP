-- ============================================================================
-- PHASE 2 — Supabase SECURITY DEFINER RPC functions for large table export
-- Apply via apply_migration on Supabase project isbgjpnbocdkeslofota
--
-- Pattern from April 15 replication session (bypasses the MCP 30KB cap).
-- Each function returns a JSONB array of up to `p_limit` rows starting at
-- `p_offset`.  Client does REST API pagination at 1000 rows/page.
-- ============================================================================

-- 1) staging.boe_donation_candidate_map — 338,213 rows
CREATE OR REPLACE FUNCTION public.export_boe_donation_candidate_map(
    p_offset integer DEFAULT 0,
    p_limit  integer DEFAULT 1000
) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public, staging
AS $$
  SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.boe_id), '[]'::jsonb)
  FROM (
    SELECT * FROM staging.boe_donation_candidate_map
    ORDER BY boe_id
    OFFSET p_offset LIMIT p_limit
  ) t;
$$;

GRANT EXECUTE ON FUNCTION public.export_boe_donation_candidate_map(integer,integer) TO anon, authenticated;

-- 2) public.ncsbe_candidates — 55,985 rows
CREATE OR REPLACE FUNCTION public.export_ncsbe_candidates_full(
    p_offset integer DEFAULT 0,
    p_limit  integer DEFAULT 1000
) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.id), '[]'::jsonb)
  FROM (
    SELECT * FROM public.ncsbe_candidates
    ORDER BY id
    OFFSET p_offset LIMIT p_limit
  ) t;
$$;

GRANT EXECUTE ON FUNCTION public.export_ncsbe_candidates_full(integer,integer) TO anon, authenticated;

-- 3) public.fec_committee_candidate_lookup — 2,012 rows
CREATE OR REPLACE FUNCTION public.export_fec_committee_candidate_lookup(
    p_offset integer DEFAULT 0,
    p_limit  integer DEFAULT 1000
) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.id), '[]'::jsonb)
  FROM (
    SELECT * FROM public.fec_committee_candidate_lookup
    ORDER BY id
    OFFSET p_offset LIMIT p_limit
  ) t;
$$;

GRANT EXECUTE ON FUNCTION public.export_fec_committee_candidate_lookup(integer,integer) TO anon, authenticated;
