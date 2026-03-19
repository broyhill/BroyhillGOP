-- 056_VOTER_PROFILE_DATATRUST.sql
-- Extends get_voter_profile to include nc_datatrust enrichment data
-- Join: nc_voters.ncid = nc_datatrust.StateVoterID (or nc_datatrust.SourceID if StateVoterID format differs)
-- Run: psql $SUPABASE_DB_URL -f database/migrations/056_VOTER_PROFILE_DATATRUST.sql

-- =============================================================================
-- Helper: Get DataTrust row for a voter (by ncid)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_datatrust_for_ncid(p_ncid TEXT)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT to_jsonb(d.*)
  FROM public.nc_datatrust d
  WHERE TRIM(COALESCE(d.statevoterid::text, '')) = TRIM(p_ncid)
     OR TRIM(COALESCE(d.sourceid::text, '')) = TRIM(p_ncid)
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.get_datatrust_for_ncid IS 'Returns nc_datatrust row as JSONB for voter profile enrichment. Join key: StateVoterID or SourceID = ncid.';

-- =============================================================================
-- INSTRUCTIONS: Add datatrust to your get_voter_profile(p_ncid) RPC
-- =============================================================================
-- In your get_voter_profile function, add a 'datatrust' key to the returned JSON:
--
--   result := result || jsonb_build_object(
--     'datatrust', COALESCE(public.get_datatrust_for_ncid(p_ncid), 'null'::jsonb)
--   );
--
-- Or if building the object from scratch:
--   'datatrust', (SELECT public.get_datatrust_for_ncid(p_ncid))
--
-- Join key: nc_voters.ncid = nc_datatrust.StateVoterID (or SourceID)
-- =============================================================================

-- Grant execute to anon and authenticated
GRANT EXECUTE ON FUNCTION public.get_datatrust_for_ncid(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_datatrust_for_ncid(TEXT) TO authenticated;
