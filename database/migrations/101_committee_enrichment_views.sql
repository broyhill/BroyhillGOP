-- 101_committee_enrichment_views.sql
-- Created: 2026-04-15
-- Purpose: Enrichment views that join spine/party donations with committee infrastructure tables
-- Depends on: committee schema (committee.registry, committee.office_type_map, committee.party_map)
--             raw.ncboe_donations, staging.ncboe_party_committee_donations

-- ============================================================
-- View 1: Spine donation rows enriched with committee metadata
-- ============================================================
-- Joins every spine donation with committee type, office type, 
-- office level, and party flag from the committee infrastructure tables.
--
-- Usage:
--   SELECT * FROM committee.spine_committee_enriched WHERE cluster_id = 372171;
--   SELECT office_type, SUM(norm_amount) FROM committee.spine_committee_enriched GROUP BY office_type;

CREATE OR REPLACE VIEW committee.spine_committee_enriched AS
SELECT 
  d.cluster_id,
  d.committee_sboe_id,
  d.committee_name,
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
) pm ON d.committee_sboe_id = pm.committee_id;


-- ============================================================
-- View 2: Party committee donor rows enriched with committee metadata
-- ============================================================
-- Joins party committee donations (staging.ncboe_party_committee_donations)
-- with committee type, donor_subtype, and party flag.
--
-- Usage:
--   SELECT * FROM committee.party_donor_enriched WHERE cluster_id = 372171;
--   SELECT committee_type, COUNT(*), SUM(norm_amount) FROM committee.party_donor_enriched GROUP BY committee_type;

CREATE OR REPLACE VIEW committee.party_donor_enriched AS
SELECT 
  pcd.cluster_id,
  pcd.committee_sboe_id,
  pcd.committee_name,
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
  pcd.transaction_type
FROM staging.ncboe_party_committee_donations pcd
LEFT JOIN committee.registry cr ON pcd.committee_sboe_id = cr.sboe_id
LEFT JOIN (
  SELECT DISTINCT committee_id, party_flag 
  FROM committee.party_map
) pm ON pcd.committee_sboe_id = pm.committee_id;
