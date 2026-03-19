-- pipeline/seed_nc_boe.sql
-- Seed NC BOE control tables (source_quality_rules, norm_readiness_rules, dedup_rules).
-- Per NC BOE State Donor File Ingestion Pipeline instruction document.
-- Run: psql $DATABASE_URL -f pipeline/seed_nc_boe.sql

-- Quality rules (NC BOE specific — NOT FEC)
INSERT INTO pipeline.source_quality_rules
  (source_system, rule_name, rule_sql_condition, severity, description)
VALUES
  ('nc_boe', 'q1_donor_name', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE donor_name IS NULL OR TRIM(COALESCE(donor_name, '''')) = ''''', 'fatal', 'donor_name required'),
  ('nc_boe', 'q2_amount', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE amount_numeric IS NULL', 'fatal', 'amount_numeric required'),
  ('nc_boe', 'q3_date', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE date_occurred IS NULL', 'fatal', 'date_occurred required'),
  ('nc_boe', 'q4_date_range', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE date_occurred < ''1991-01-01'' OR date_occurred > CURRENT_DATE + INTERVAL ''1 year''', 'fatal', 'date_occurred must be 1991-01-01 to now+1yr'),
  ('nc_boe', 'q5_committee', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE committee_sboe_id IS NULL OR TRIM(COALESCE(committee_sboe_id, '''')) = ''''', 'fatal', 'committee_sboe_id required'),
  ('nc_boe', 'q6_transaction_type', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE transaction_type IS NULL', 'fatal', 'transaction_type required'),
  ('nc_boe', 'q7_norm_last', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE transaction_type IN (''Individual'', ''General'') AND (norm_last IS NULL OR TRIM(COALESCE(norm_last, '''')) = ''''')', 'warn', 'norm_last required after parse for person types')
ON CONFLICT (source_system, rule_name) DO UPDATE SET
  rule_sql_condition = EXCLUDED.rule_sql_condition,
  severity = EXCLUDED.severity,
  description = EXCLUDED.description;

-- Dedup rule: identity clustering (last_name + zip5 + dmetaphone first_name)
-- Columns for pipeline/dedup.py: norm_last, norm_zip5, canonical_first on nc_boe_donations_raw
INSERT INTO pipeline.dedup_rules
  (source_system, dedup_function_name, notes)
VALUES
  ('nc_boe', 'dedup_key_ncboe', '{"weights": {"exact": 1.0, "fuzzy": 0.85}, "columns": {"last_name": "norm_last", "zip": "norm_zip5", "first_name": "canonical_first"}, "id_column": "id", "zip_required": false}')
ON CONFLICT (source_system) DO UPDATE SET
  dedup_function_name = EXCLUDED.dedup_function_name,
  notes = EXCLUDED.notes;
