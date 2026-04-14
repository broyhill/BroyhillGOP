-- 092_DONOR_VOTER_LINKS_TRUSTED_INDEX.sql
-- Partial index for joins that exclude orphaned / uuid-format donor_id rows (Wave 1).
-- Prerequisite: 090 (donor_id_format, is_orphaned populated).
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/092_DONOR_VOTER_LINKS_TRUSTED_INDEX.sql

CREATE INDEX IF NOT EXISTS idx_donor_voter_links_trusted_ncid
  ON public.donor_voter_links (ncid)
  WHERE donor_id_format = 'integer'
    AND COALESCE(is_orphaned, FALSE) = FALSE
    AND ncid IS NOT NULL;

COMMENT ON INDEX idx_donor_voter_links_trusted_ncid IS
  'Speed joins from NC voter id to trusted donor_voter_links only.';
