-- Migration 100: Create public schema views for archive.donor_golden_records
--               and archive.donor_master
-- Authorized by: Ed Broyhill, April 8, 2026
-- Purpose: archive schema tables silently fail when queried without prefix.
--          Public views give safe transparent access.

-- View 1: donor_golden_records
CREATE OR REPLACE VIEW public.donor_golden_records AS
SELECT * FROM archive.donor_golden_records;

-- View 2: donor_master
CREATE OR REPLACE VIEW public.donor_master AS
SELECT * FROM archive.donor_master;

-- These are read-only views — all writes must go to archive.donor_golden_records
-- and archive.donor_master directly.

-- Post-check:
-- SELECT COUNT(*) FROM public.donor_golden_records;  -- Expected: 393,334
-- SELECT COUNT(*) FROM public.donor_master;          -- Expected: 393,334
