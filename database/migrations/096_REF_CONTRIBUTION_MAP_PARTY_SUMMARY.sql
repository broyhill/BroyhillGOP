-- 096_REF_CONTRIBUTION_MAP_PARTY_SUMMARY.sql
-- Roll-up of core.contribution_map by party_flag (R / OTHER / PAC / etc.).
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/096_REF_CONTRIBUTION_MAP_PARTY_SUMMARY.sql

CREATE SCHEMA IF NOT EXISTS ref;

CREATE OR REPLACE VIEW ref.v_contribution_map_party_summary AS
SELECT
  COALESCE(party_flag, '(null)') AS party_flag,
  COUNT(*) AS transaction_count,
  SUM(COALESCE(amount, 0))::numeric(20, 2) AS total_amount,
  COUNT(DISTINCT person_id) AS distinct_persons
FROM core.contribution_map
GROUP BY party_flag;

COMMENT ON VIEW ref.v_contribution_map_party_summary IS
  'High-level GOP pipeline check: contribution_map totals by party_flag.';
