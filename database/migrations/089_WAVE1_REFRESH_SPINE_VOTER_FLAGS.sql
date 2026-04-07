-- 089_WAVE1_REFRESH_SPINE_VOTER_FLAGS.sql
-- Wave 1: Align core.person_spine.is_registered_voter with NCSBE nc_voters.status_cd.
-- Fixes undercount where voter_ncid is set but is_registered_voter was never refreshed.
-- Number 089 avoids collision with 087_exec_and_remaining_fixes.sql.
--
-- Definition: is_registered_voter = TRUE only when SBE status_cd = 'A' (ACTIVE).
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/089_WAVE1_REFRESH_SPINE_VOTER_FLAGS.sql
--
-- Prerequisites: 088 (optional), nc_voters indexed on ncid (see 065).

BEGIN;

-- Rows with a voter_ncid that matches nc_voters: set flag + enrich from SBE
UPDATE core.person_spine s
SET
  is_registered_voter = (v.status_cd = 'A'),
  voter_status = v.status_cd::text,
  voter_party = v.party_cd::text,
  voter_county = v.county_desc::text,
  updated_at = NOW()
FROM public.nc_voters v
WHERE s.is_active = true
  AND s.voter_ncid IS NOT NULL
  AND TRIM(s.voter_ncid::text) = TRIM(v.ncid::text);

-- voter_ncid present but no matching nc_voters row: cannot be "registered" in SBE sense
UPDATE core.person_spine s
SET
  is_registered_voter = false,
  updated_at = NOW()
WHERE s.is_active = true
  AND s.voter_ncid IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.nc_voters v
    WHERE TRIM(v.ncid::text) = TRIM(s.voter_ncid::text)
  );

COMMIT;

-- Post-check (informational)
SELECT
  'person_spine voter flags after 089' AS label,
  COUNT(*) FILTER (WHERE is_active) AS active_spine,
  COUNT(*) FILTER (WHERE is_active AND voter_ncid IS NOT NULL) AS with_ncid,
  COUNT(*) FILTER (WHERE is_active AND is_registered_voter = true) AS registered_true,
  COUNT(*) FILTER (WHERE is_active AND voter_ncid IS NOT NULL AND is_registered_voter = true) AS ncid_and_registered
FROM core.person_spine;
