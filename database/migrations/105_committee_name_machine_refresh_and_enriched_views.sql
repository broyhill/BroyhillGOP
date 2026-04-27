-- 105_committee_name_machine_refresh_and_enriched_views.sql
-- Purpose:
--   1) Add reusable refresh function for committee ID canonical-name machine.
--   2) Ensure enrichment views expose canonical full committee names consistently.
-- Depends on:
--   102_committee_name_affix_map.sql
--   104_committee_id_fullname_machine.sql

CREATE SCHEMA IF NOT EXISTS committee;

-- ============================================================
-- 1) Refresh function for ID -> canonical full committee name machine
-- ============================================================
CREATE OR REPLACE FUNCTION committee.refresh_committee_id_canonical_name()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  affected_rows integer := 0;
BEGIN
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
  ),
  upserted AS (
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
        updated_at          = now()
    RETURNING 1
  )
  SELECT COUNT(*) INTO affected_rows FROM upserted;

  RETURN affected_rows;
END;
$$;

COMMENT ON FUNCTION committee.refresh_committee_id_canonical_name()
IS 'Refreshes deterministic committee_sboe_id -> canonical full committee name machine.';

-- Run once at migration time.
SELECT committee.refresh_committee_id_canonical_name();

-- ============================================================
-- 2) Canonical-name enriched views
-- ============================================================
CREATE OR REPLACE VIEW committee.spine_committee_enriched AS
SELECT
  d.cluster_id,
  d.committee_sboe_id,
  COALESCE(cn.canonical_name, committee.affix_committee_name(d.committee_name)) AS committee_name,
  cr.committee_type,
  cr.candidate_name AS registry_candidate_name,
  cr.candidate_norm_last,
  cr.candidate_norm_first,
  otm.office_type,
  otm.office_level,
  pm.party_flag,
  cr.source_level,
  cr.role AS committee_role,
  cr.total_received AS committee_total_received,
  cr.unique_donors AS committee_unique_donors,
  cr.is_client_subscriber,
  cr.client_tier,
  d.norm_amount,
  d.norm_date
FROM raw.ncboe_donations d
LEFT JOIN committee.registry cr ON d.committee_sboe_id = cr.sboe_id
LEFT JOIN committee.office_type_map otm ON d.committee_name = otm.committee_name
LEFT JOIN (
  SELECT DISTINCT committee_id, party_flag
  FROM committee.party_map
) pm ON d.committee_sboe_id = pm.committee_id
LEFT JOIN committee.committee_id_canonical_name cn
  ON cn.committee_sboe_id = d.committee_sboe_id;

CREATE OR REPLACE VIEW committee.party_donor_enriched AS
SELECT
  pcd.cluster_id,
  pcd.committee_sboe_id,
  COALESCE(cn.canonical_name, committee.affix_committee_name(pcd.committee_name)) AS committee_name,
  cr.committee_type,
  cr.donor_subtype,
  pm.party_flag,
  pcd.name,
  pcd.norm_last,
  pcd.norm_first,
  pcd.norm_zip5,
  pcd.norm_amount,
  pcd.norm_date,
  pcd.is_aggregated,
  pcd.transaction_type,
  pcd.norm_last_core,
  pcd.norm_suffix,
  pcd.norm_first_core,
  pcd.norm_middle_initial,
  pcd.addr_numeric_tokens,
  pcd.identity_block_key,
  pcd.identity_key_loose,
  pcd.identity_anomaly_short_last,
  pcd.identity_norm_version
FROM staging.ncboe_party_committee_donations pcd
LEFT JOIN committee.registry cr ON pcd.committee_sboe_id = cr.sboe_id
LEFT JOIN (
  SELECT DISTINCT committee_id, party_flag
  FROM committee.party_map
) pm ON pcd.committee_sboe_id = pm.committee_id
LEFT JOIN committee.committee_id_canonical_name cn
  ON cn.committee_sboe_id = pcd.committee_sboe_id;
