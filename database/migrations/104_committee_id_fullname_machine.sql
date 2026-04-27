-- 104_committee_id_fullname_machine.sql
-- Purpose:
--   Build deterministic committee ID -> canonical full-name machine and
--   apply it to the user-facing donation view.
-- Depends on:
--   102_committee_name_affix_map.sql (committee.affix_committee_name)

CREATE SCHEMA IF NOT EXISTS committee;

-- ============================================================
-- 1) Committee ID machine (one canonical full name per SBOE id)
-- ============================================================
CREATE TABLE IF NOT EXISTS committee.committee_id_canonical_name (
  committee_sboe_id   text PRIMARY KEY,
  canonical_name      text NOT NULL,
  source_table        text NOT NULL,
  source_priority     integer NOT NULL,
  source_observations integer NOT NULL DEFAULT 0,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS committee_id_canonical_name_name_idx
  ON committee.committee_id_canonical_name (canonical_name);

WITH candidates AS (
  -- Highest priority: committee registry authoritative names
  SELECT
    r.sboe_id AS committee_sboe_id,
    committee.affix_committee_name(r.committee_name) AS canonical_name,
    'committee.registry'::text AS source_table,
    1 AS source_priority,
    COUNT(*)::int AS source_observations
  FROM committee.registry r
  WHERE r.sboe_id IS NOT NULL
    AND btrim(r.sboe_id) <> ''
    AND r.committee_name IS NOT NULL
    AND btrim(r.committee_name) <> ''
  GROUP BY r.sboe_id, committee.affix_committee_name(r.committee_name)

  UNION ALL

  -- Secondary: raw party-donor staging committee names
  SELECT
    p.committee_sboe_id,
    committee.affix_committee_name(p.committee_name) AS canonical_name,
    'staging.ncboe_party_committee_donations'::text AS source_table,
    2 AS source_priority,
    COUNT(*)::int AS source_observations
  FROM staging.ncboe_party_committee_donations p
  WHERE p.committee_sboe_id IS NOT NULL
    AND btrim(p.committee_sboe_id) <> ''
    AND p.committee_name IS NOT NULL
    AND btrim(p.committee_name) <> ''
  GROUP BY p.committee_sboe_id, committee.affix_committee_name(p.committee_name)
),
ranked AS (
  SELECT
    c.*,
    ROW_NUMBER() OVER (
      PARTITION BY c.committee_sboe_id
      ORDER BY c.source_priority ASC, c.source_observations DESC, c.canonical_name ASC
    ) AS rn
  FROM candidates c
)
INSERT INTO committee.committee_id_canonical_name (
  committee_sboe_id,
  canonical_name,
  source_table,
  source_priority,
  source_observations,
  updated_at
)
SELECT
  committee_sboe_id,
  canonical_name,
  source_table,
  source_priority,
  source_observations,
  now()
FROM ranked
WHERE rn = 1
ON CONFLICT (committee_sboe_id) DO UPDATE
SET canonical_name      = EXCLUDED.canonical_name,
    source_table        = EXCLUDED.source_table,
    source_priority     = EXCLUDED.source_priority,
    source_observations = EXCLUDED.source_observations,
    updated_at          = now();

-- ============================================================
-- 2) User-facing donation view now resolves by committee ID first
-- ============================================================
CREATE OR REPLACE VIEW committee.v_party_committee_individual_donors AS
SELECT
    p.id,
    p.source_file,
    p.name,
    p.street_line_1,
    p.street_line_2,
    p.city,
    p.state,
    p.zip_code,
    p.profession_job_title,
    p.employer_name,
    p.transaction_type,
    COALESCE(cn.canonical_name, committee.affix_committee_name(p.committee_name)) AS committee_name,
    p.committee_sboe_id,
    p.committee_street_1,
    p.committee_street_2,
    p.committee_city,
    p.committee_state,
    p.committee_zip_code,
    p.report_name,
    p.date_occured,
    p.account_code,
    p.amount,
    p.form_of_payment,
    p.purpose,
    p.candidate_referendum_name,
    p.declaration,
    p.norm_last,
    p.norm_first,
    p.norm_middle,
    p.norm_suffix,
    p.norm_prefix,
    p.norm_zip5,
    p.norm_amount,
    p.norm_date,
    p.address_numbers,
    p.is_aggregated,
    p.cluster_id,
    p.created_at,
    p.norm_last_core,
    p.norm_first_core,
    p.norm_middle_initial,
    p.addr_numeric_tokens,
    p.identity_block_key,
    p.identity_key_loose,
    p.identity_anomaly_short_last,
    p.identity_norm_version
FROM staging.ncboe_party_committee_donations p
LEFT JOIN committee.committee_id_canonical_name cn
  ON cn.committee_sboe_id = p.committee_sboe_id
WHERE p.transaction_type = 'Individual'
  AND COALESCE(p.is_aggregated, false) = false
  AND upper(COALESCE(p.name, '')) NOT LIKE '%AGGREGAT%'
  AND NOT (
    p.name ~* '\mPAC\M'
    OR p.name ~* '\mLLC\M'
    OR p.name ~* '\mL\.L\.C\M'
    OR p.name ~* '\mLLP\M'
    OR p.name ~* '\mINC\M'
    OR p.name ~* '\mCORP\M'
    OR p.name ~* '\mCORPORATION\M'
    OR p.name ~* '\mCOMMITTEE\M'
    OR p.name ~* '\mFOUNDATION\M'
    OR p.name ~* '\mFEDERATION\M'
    OR p.name ~* '\mTRUST\M'
    OR p.name ~* '\mHOLDINGS\M'
    OR p.name ~* '\mPARTNERSHIP\M'
    OR p.name ~* '\mASSOCIATION\M'
    OR p.name ~* '\mGUILD\M'
    OR p.name ~* 'CAMPAIGN[[:space:]]+FUND'
    OR p.name ~* '\mPOLITICAL\M'
  )
  AND upper(COALESCE(p.norm_last, '')) <> ALL (
    ARRAY[
      'PAC',
      'LLC',
      'INC',
      'CORP',
      'CORPORATION',
      'COMMITTEE',
      'FUND',
      'TRUST',
      'FOUNDATION',
      'FEDERATION',
      'GROUP',
      'HOLDINGS',
      'ASSOCIATION',
      'GUILD',
      'COMPANY',
      'PARTNERSHIP',
      'CONTRIBUTION',
      'INDIVIDUAL'
    ]
  )
  AND upper(COALESCE(p.norm_first, '')) <> ALL (
    ARRAY['AGGREGATED', 'PAC', 'LLC', 'COMMITTEE']
  );

