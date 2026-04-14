-- 097_INTEGRATION_DATATRUST_CONTACT_LINK.sql
-- Sidecar for DataTrust ↔ unified_contacts linkage. nc_datatrust is canonical raw
-- (no contact_id / sync columns). Apply before refreshing database/schemas/datatrust_matching_procedures.sql.
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/097_INTEGRATION_DATATRUST_CONTACT_LINK.sql

BEGIN;

CREATE SCHEMA IF NOT EXISTS integration;

CREATE TABLE IF NOT EXISTS integration.datatrust_contact_link (
  rncid TEXT PRIMARY KEY,
  contact_id BIGINT,
  synced_to_unified_contacts BOOLEAN NOT NULL DEFAULT FALSE,
  sync_date TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_datatrust_contact_link_unsynced
  ON integration.datatrust_contact_link (synced_to_unified_contacts, contact_id);

COMMENT ON TABLE integration.datatrust_contact_link IS
  'Maps public.nc_datatrust.rncid → unified_contacts.contact_id. Replaces deprecated datatrust_profiles link columns.';

COMMIT;
