-- 093_REF_NC_VOTERS_ACTIVE_VIEW.sql
-- Convenience view: NC voters with SBE active status only (status_cd = 'A').
-- Use for joins where REMOVED/INACTIVE/DENIED must be excluded.
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/093_REF_NC_VOTERS_ACTIVE_VIEW.sql

CREATE SCHEMA IF NOT EXISTS ref;

CREATE OR REPLACE VIEW ref.v_nc_voters_active AS
SELECT v.*
FROM public.nc_voters v
WHERE v.status_cd = 'A';

COMMENT ON VIEW ref.v_nc_voters_active IS
  'NC SBE active registrations only (status_cd = A). For full file use public.nc_voters or ref.v_nc_voter_canonical.';
