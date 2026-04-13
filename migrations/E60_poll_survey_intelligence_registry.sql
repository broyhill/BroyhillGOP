-- E60 Poll & Survey Intelligence — Registry Entry
-- Run against Supabase: INSERT into framework_document_registry
-- This catalogs E60 as a documented ecosystem. No tables created.

INSERT INTO framework_document_registry (
  document_name,
  file_name,
  category,
  subcategory,
  description,
  key_deliverables,
  database_objects_created,
  integration_status,
  priority,
  created_date,
  document_date,
  location,
  ecosystem_codes,
  ecosystems_text,
  notes
) VALUES (
  'E60_POLL_SURVEY_INTELLIGENCE',
  'ECOSYSTEM_REPORTS/E60_POLL_SURVEY_INTELLIGENCE.docx',
  'ecosystem_blueprints',
  'intelligence',
  'County-level poll & survey intelligence ecosystem. Ingests 6 NC poll sources (Catawba-YouGov, Meredith, HPU, ECU, JLF/Civitas, Cygnal). Computes per-county issue intensity scores across 8 voter archetypes. Feeds E20 Intelligence Brain with calibration weights for wave trigger optimization.',
  ARRAY[
    'nc_county_issue_intensity — per-issue intensity score for all 100 NC counties by archetype',
    'archetype_poll_calibration — activation weights for E20 Brain wave triggers',
    'nc_county_race_tracking — horse race polling time series',
    'poll_alerts — swing detection and archetype shift notifications',
    'Inspinia admin panel with choropleth map, race tracking, calibration grid'
  ],
  ARRAY[
    'poll_sources',
    'nc_counties',
    'voter_archetypes',
    'polls',
    'poll_questions',
    'poll_responses',
    'poll_crosstabs',
    'nc_county_issue_intensity',
    'nc_county_race_tracking',
    'archetype_poll_calibration',
    'poll_fetch_schedule',
    'poll_alerts'
  ],
  'blocked',
  'high',
  '2026-04-13',
  '2026-04-13',
  'GitHub: ECOSYSTEM_REPORTS/E60_POLL_SURVEY_INTELLIGENCE.docx | DDL: migrations/E60_ddl.sql',
  ARRAY['E60'],
  'E60 Poll & Survey Intelligence — BLOCKED pending Golden Record Stages 0-5. Upstream: E20, E42, E06. Downstream: E01, E03, E48.',
  'BLOCKED: Do not execute DDL until Golden Record Stages 0-5 complete. Tables reference golden_record_id from E01. user_roles table required for RLS. DDL stored in migrations/E60_ddl.sql ready for deployment when unblocked.'
);
