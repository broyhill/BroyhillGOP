-- 088_WAVE1_VOTER_DATATRUST_FOUNDATION.sql
-- Wave 1 (approved 2026-04-07): voter file + DataTrust integration layer — no FEC.
-- Adds reference views and upgrades staging id columns to BIGINT (person_spine uses bigint).
-- Number 088 avoids collision with 086_completion_fixes.sql.
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/088_WAVE1_VOTER_DATATRUST_FOUNDATION.sql
--
-- Prerequisites: public.nc_voters, public.nc_datatrust exist (Supabase isbgjpnbocdkeslofota).

-- =============================================================================
-- 1. Reference schema + NC voter canonical view (NCSBE is authority for status)
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS ref;

COMMENT ON SCHEMA ref IS
  'Reference views for Wave 1 voter/DataTrust alignment (BroyhillGOP spine).';

CREATE OR REPLACE VIEW ref.v_nc_voter_canonical AS
SELECT
  v.ncid::text AS ncid,
  v.status_cd::text AS status_cd,
  v.party_cd::text AS party_cd,
  v.county_desc::text AS county_desc,
  v.zip_code::text AS zip_code,
  v.last_name::text AS last_name,
  v.first_name::text AS first_name,
  (v.status_cd = 'A') AS is_active_sbe,
  CASE
    WHEN v.status_cd = 'A' THEN 'registered_active'
    WHEN v.status_cd = 'I' THEN 'registered_inactive'
    WHEN v.status_cd = 'R' THEN 'removed'
    WHEN v.status_cd = 'D' THEN 'denied'
    ELSE COALESCE('unknown_' || v.status_cd::text, 'unknown')
  END AS registration_canonical
FROM public.nc_voters v;

COMMENT ON VIEW ref.v_nc_voter_canonical IS
  'NC voter rows with canonical registration bucket. status_cd per existing pipeline (068): A/I/R/D.';

-- =============================================================================
-- 2. DataTrust status view (thin model: A/I only — map to same vocabulary)
-- =============================================================================
CREATE OR REPLACE VIEW ref.v_datatrust_registration AS
SELECT
  dt.rncid::text AS rncid,
  NULLIF(TRIM(dt.statevoterid::text), '') AS statevoterid,
  NULLIF(TRIM(dt.rnc_regid::text), '') AS rnc_regid,
  dt.voterstatus::text AS voterstatus_raw,
  CASE
    WHEN UPPER(TRIM(COALESCE(dt.voterstatus::text, ''))) = 'A' THEN 'datatrust_active'
    WHEN UPPER(TRIM(COALESCE(dt.voterstatus::text, ''))) = 'I' THEN 'datatrust_inactive'
    ELSE 'datatrust_unknown'
  END AS registration_canonical_dt
FROM public.nc_datatrust dt;

COMMENT ON VIEW ref.v_datatrust_registration IS
  'DataTrust registration flags. Does not include SBE REMOVED/DENIED; compare to ref.v_nc_voter_canonical for conflicts.';

-- =============================================================================
-- 3. Upgrade staging spine id columns to BIGINT (safe if already bigint)
-- =============================================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'staging' AND table_name = 'spine_merge_candidates'
  ) THEN
    ALTER TABLE staging.spine_merge_candidates
      ALTER COLUMN keep_id TYPE BIGINT USING keep_id::bigint,
      ALTER COLUMN merge_id TYPE BIGINT USING merge_id::bigint;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'staging' AND table_name = 'spine_clusters'
  ) THEN
    ALTER TABLE staging.spine_clusters
      ALTER COLUMN person_id TYPE BIGINT USING person_id::bigint,
      ALTER COLUMN cluster_root TYPE BIGINT USING cluster_root::bigint;
  END IF;
END $$;

-- =============================================================================
-- 4. Optional: pipeline metadata for snapshot dating (idempotent)
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS pipeline;

CREATE TABLE IF NOT EXISTS pipeline.wave1_source_snapshots (
  id              BIGSERIAL PRIMARY KEY,
  source_name     TEXT NOT NULL,
  snapshot_label  TEXT NOT NULL,
  row_count       BIGINT,
  loaded_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes           TEXT,
  UNIQUE (source_name, snapshot_label)
);

COMMENT ON TABLE pipeline.wave1_source_snapshots IS
  'Record nc_voters / nc_datatrust / GOLD NCBOE load dates for Wave 1 audits.';
