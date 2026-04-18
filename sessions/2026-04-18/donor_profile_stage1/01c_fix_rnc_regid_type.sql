-- 01c_fix_rnc_regid_type.sql
-- Patch: align core.donor_profile.rnc_regid with rest of DB (TEXT, not BIGINT)
-- Issue caught during dry run 2026-04-18 19:16 EDT — raw.ncboe_donations.rnc_regid is TEXT,
-- as is every other rnc_regid column across core.person_spine, core.datatrust_voter_nc,
-- nc_unified_voters, acxiom_*, etc. The Stage 1 DDL incorrectly declared it BIGINT.
--
-- Safe to run because core.donor_profile and core.donor_profile_audit are empty (0 rows)
-- at this point — DDL just ran, populate never committed.

BEGIN;

ALTER TABLE core.donor_profile
    ALTER COLUMN rnc_regid TYPE TEXT USING rnc_regid::TEXT;

ALTER TABLE core.donor_profile_audit
    ALTER COLUMN rnc_regid TYPE TEXT USING rnc_regid::TEXT;

-- Partial index on rnc_regid rebuilds automatically after ALTER COLUMN TYPE.
-- Verify:
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'core'
  AND table_name IN ('donor_profile', 'donor_profile_audit')
  AND column_name = 'rnc_regid';

COMMIT;
