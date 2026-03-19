-- 065_IDENTITY_RESOLUTION_OVERHAUL_PHASE0.sql
-- Per Cursor-Identity-Resolution-Overhaul.docx (Claude → Cursor, March 14, 2026)
-- Phase 0: Database Health — VACUUM, drop unused indexes, create nc_voters indexes
--
-- Run: psql $DATABASE_URL -f database/migrations/065_IDENTITY_RESOLUTION_OVERHAUL_PHASE0.sql

-- =============================================================================
-- 4.1 VACUUM Bloated Tables
-- =============================================================================
VACUUM ANALYZE nc_boe_donations_raw;      -- 60K dead tuples
VACUUM ANALYZE ncsbe_candidates;         -- 4.5K dead tuples
VACUUM ANALYZE staging_committee_ref;    -- 141 dead tuples
VACUUM ANALYZE boe_committee_candidate_map;  -- 114 dead tuples
VACUUM ANALYZE candidate_profiles;       -- 123 dead tuples

-- =============================================================================
-- 4.2 Drop Unused Indexes (~1.8 GB recoverable)
-- VERIFY FIRST: SELECT indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
--               FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY pg_relation_size(indexrelid) DESC;
-- =============================================================================
DROP INDEX IF EXISTS idx_nc_voters_last_first_city;   -- 357 MB
DROP INDEX IF EXISTS idx_nc_voters_last_first_zip;   -- 334 MB
DROP INDEX IF EXISTS idx_pm_name_zip;               -- 294 MB
DROP INDEX IF EXISTS idx_dt_last_first_zip;          -- 294 MB
DROP INDEX IF EXISTS idx_datatrust_full_name;        -- 289 MB
DROP INDEX IF EXISTS idx_pm_datatrust;               -- 230 MB

-- =============================================================================
-- 4.3 Create nc_voters Indexes (CRITICAL — 9.45M rows, ZERO indexes)
-- =============================================================================
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nv_ncid ON nc_voters(ncid);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nv_last_first ON nc_voters(last_name, first_name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nv_last_zip ON nc_voters(last_name, zip_code);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nv_last_county ON nc_voters(last_name, county_desc);
