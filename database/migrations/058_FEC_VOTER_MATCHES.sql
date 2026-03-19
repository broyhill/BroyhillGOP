-- 058_FEC_VOTER_MATCHES.sql
-- FEC contributor → NC voter matches (output of fec_voter_matcher.py)
-- Run: psql $SUPABASE_DB_URL -f database/migrations/058_FEC_VOTER_MATCHES.sql

-- =============================================================================
-- fec_voter_matches — one row per FEC contributor matched to nc_voters.ncid
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.fec_voter_matches (
    id                  BIGSERIAL PRIMARY KEY,
    fec_contributor_id  TEXT NOT NULL,
    ncid                TEXT NOT NULL,
    match_tier          SMALLINT NOT NULL CHECK (match_tier IN (1, 2, 3)),
    match_score         NUMERIC(5,4),
    matched_at          TIMESTAMPTZ DEFAULT now(),
    UNIQUE (fec_contributor_id)
);

COMMENT ON TABLE public.fec_voter_matches IS 'FEC contributor → NC voter matches. Tier 1=address+name+zip, Tier 2=name+zip+city, Tier 3=name+zip only.';

CREATE INDEX IF NOT EXISTS idx_fec_voter_matches_contributor ON public.fec_voter_matches(fec_contributor_id);
CREATE INDEX IF NOT EXISTS idx_fec_voter_matches_ncid ON public.fec_voter_matches(ncid);
CREATE INDEX IF NOT EXISTS idx_fec_voter_matches_tier ON public.fec_voter_matches(match_tier);
