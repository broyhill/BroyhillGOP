-- 091_REF_DONOR_VOTER_LINKS_TRUSTED_VIEW.sql
-- Wave 1: Analyst view — donor_voter_links rows that resolve to donor_contacts (integer ids, not orphaned).
-- Prerequisite: 090_WAVE1_DONOR_VOTER_LINKS_ORPHAN_TAG.sql (columns donor_id_format, is_orphaned).
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/091_REF_DONOR_VOTER_LINKS_TRUSTED_VIEW.sql

CREATE SCHEMA IF NOT EXISTS ref;

CREATE OR REPLACE VIEW ref.v_donor_voter_links_trusted AS
SELECT dvl.*
FROM public.donor_voter_links dvl
WHERE dvl.donor_id_format = 'integer'
  AND COALESCE(dvl.is_orphaned, FALSE) = FALSE;

COMMENT ON VIEW ref.v_donor_voter_links_trusted IS
  'NCBOE/Wave1: links whose donor_id matches donor_contacts. Excludes uuid-format donor_ids and integer orphans.';
