-- 070_PHASE4_BRIDGE_AND_AGGREGATES.sql
-- Identity Resolution Phase 4: Bridge person_master ↔ spine + close NC BOE gaps + rebuild aggregates
-- PREREQUISITE: 065-069 all complete
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: Close NC BOE contribution map gap (147K unmapped donations)
-- =============================================================================

-- Find unmapped NC BOE donations
SELECT 'NC BOE unmapped donations' AS label, count(*) AS gap
FROM nc_boe_donations_raw r
WHERE r.transaction_type IN ('Individual', 'General')
  AND NOT EXISTS (
    SELECT 1 FROM donor_contribution_map m
    WHERE m.source_system = 'NC_BOE' AND m.source_id = r.id::text
  );

-- Map via spine: match on norm_last + norm_first + zip5
INSERT INTO donor_contribution_map (
  source_id, source_system, golden_record_id,
  contribution_receipt_amount, contribution_receipt_date, committee_id
)
SELECT
  r.id::text,
  'NC_BOE',
  sp.person_id,
  r.amount_numeric,
  r.date_occurred,
  r.committee_sboe_id
FROM nc_boe_donations_raw r
JOIN core.person_spine sp
  ON sp.norm_last = r.norm_last
  AND sp.norm_first = r.norm_first
  AND sp.zip5 = LEFT(r.zip, 5)
  AND sp.is_active = true
WHERE r.transaction_type IN ('Individual', 'General')
  AND r.norm_last IS NOT NULL AND r.norm_last != ''
  AND NOT EXISTS (
    SELECT 1 FROM donor_contribution_map m
    WHERE m.source_system = 'NC_BOE' AND m.source_id = r.id::text
  );

-- Also try voter_ncid match for remaining
INSERT INTO donor_contribution_map (
  source_id, source_system, golden_record_id,
  contribution_receipt_amount, contribution_receipt_date, committee_id
)
SELECT
  r.id::text,
  'NC_BOE',
  sp.person_id,
  r.amount_numeric,
  r.date_occurred,
  r.committee_sboe_id
FROM nc_boe_donations_raw r
JOIN core.person_spine sp
  ON sp.voter_ncid = r.voter_ncid
  AND sp.is_active = true
WHERE r.transaction_type IN ('Individual', 'General')
  AND r.voter_ncid IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM donor_contribution_map m
    WHERE m.source_system = 'NC_BOE' AND m.source_id = r.id::text
  );

SELECT 'NC BOE after gap close' AS label,
  (SELECT count(*) FROM donor_contribution_map WHERE source_system = 'NC_BOE') AS mapped,
  (SELECT count(*) FROM nc_boe_donations_raw WHERE transaction_type IN ('Individual','General')) AS total;

-- =============================================================================
-- STEP 2: Rebuild aggregate metrics on spine from ALL contribution sources
-- =============================================================================
UPDATE core.person_spine s SET
  total_contributed = agg.total_amt,
  contribution_count = agg.txn_count,
  first_contribution = agg.first_dt,
  last_contribution = agg.last_dt,
  max_single_gift = agg.max_gift,
  avg_gift = CASE WHEN agg.txn_count > 0 THEN agg.total_amt / agg.txn_count ELSE 0 END,
  updated_at = NOW()
FROM (
  SELECT 
    golden_record_id,
    SUM(contribution_receipt_amount) AS total_amt,
    COUNT(*) AS txn_count,
    MIN(contribution_receipt_date) AS first_dt,
    MAX(contribution_receipt_date) AS last_dt,
    MAX(contribution_receipt_amount) AS max_gift
  FROM donor_contribution_map
  GROUP BY golden_record_id
) agg
WHERE s.person_id = agg.golden_record_id
  AND s.is_active = true;

-- =============================================================================
-- STEP 3: Bridge person_master ↔ core.person_spine
-- Set boe_donor_id and is_donor on person_master for all spine-matched voters
-- =============================================================================

-- Clear any stale links first
UPDATE person_master SET boe_donor_id = NULL, is_donor = false
WHERE boe_donor_id IS NOT NULL;

-- Set new links
UPDATE person_master pm SET
  boe_donor_id = s.person_id::text,
  is_donor = true
FROM core.person_spine s
WHERE s.voter_ncid = pm.ncvoter_ncid
  AND s.voter_ncid IS NOT NULL
  AND s.is_active = true;

SELECT 'person_master donors linked' AS label,
  count(*) FILTER (WHERE is_donor) AS donors_linked,
  count(*) FILTER (WHERE boe_donor_id IS NOT NULL) AS with_boe_id,
  count(*) AS total_pm
FROM person_master;

-- =============================================================================
-- STEP 4: Update person_source_links for spine linkages
-- =============================================================================
INSERT INTO person_source_links (person_id, source_table, source_key, match_method, match_confidence, linked_at)
SELECT 
  pm.person_id,
  'core.person_spine',
  s.person_id::text,
  'voter_ncid_bridge',
  0.95,
  NOW()
FROM person_master pm
JOIN core.person_spine s ON s.voter_ncid = pm.ncvoter_ncid
WHERE s.is_active = true
  AND s.voter_ncid IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM person_source_links psl
    WHERE psl.person_id = pm.person_id AND psl.source_table = 'core.person_spine'
  );

COMMIT;

-- =============================================================================
-- STEP 5: COMPREHENSIVE VALIDATION
-- =============================================================================

-- V1: Art Pope golden record
SELECT '=== V1: Art Pope ===' AS test;
SELECT person_id, norm_first, norm_last, voter_ncid, voter_rncid,
  contribution_count, total_contributed, merged_from, is_active
FROM core.person_spine
WHERE norm_last = 'POPE'
  AND (norm_first IN ('ART','ARTHUR','JAMES') OR nickname_canonical IN ('ARTHUR','ART'))
  AND is_active = true;
-- Expected: 1 row, voter_ncid=EH34831, ~156 txns, ~$990K+

-- V2: No orphaned contributions
SELECT '=== V2: Orphaned contributions ===' AS test;
SELECT source_system, count(*) AS orphaned
FROM donor_contribution_map dcm
WHERE NOT EXISTS (
  SELECT 1 FROM core.person_spine sp
  WHERE sp.person_id = dcm.golden_record_id AND sp.is_active = true
)
GROUP BY source_system;
-- Expected: 0 rows

-- V3: Contribution map coverage
SELECT '=== V3: Contribution map coverage ===' AS test;
SELECT source_system, count(*) AS rows FROM donor_contribution_map GROUP BY source_system ORDER BY count(*) DESC;
-- Expected: NC_BOE ~800K+, fec_party ~2.2M, fec_god ~197K, fec_donations ~1M+

-- V4: Spine voter linkage rate
SELECT '=== V4: Spine voter linkage ===' AS test;
SELECT 
  count(*) AS active_spine,
  count(voter_ncid) AS voter_linked,
  round(100.0 * count(voter_ncid) / count(*), 1) AS pct_linked
FROM core.person_spine WHERE is_active = true;
-- Target: >80%

-- V5: person_master donor bridge
SELECT '=== V5: person_master bridge ===' AS test;
SELECT
  count(*) FILTER (WHERE is_donor) AS pm_donors,
  count(*) FILTER (WHERE boe_donor_id IS NOT NULL) AS pm_with_boe_id,
  (SELECT count(*) FROM core.person_spine WHERE is_active AND voter_ncid IS NOT NULL) AS spine_voter_linked
FROM person_master;
-- Expected: pm_donors ≈ spine_voter_linked

-- V6: Total donation dollars by source
SELECT '=== V6: Dollar totals ===' AS test;
SELECT source_system, 
  count(*) AS txns,
  round(sum(contribution_receipt_amount)::numeric, 2) AS total_dollars
FROM donor_contribution_map
GROUP BY source_system ORDER BY total_dollars DESC;

-- V7: Active spine record count
SELECT '=== V7: Spine summary ===' AS test;
SELECT
  count(*) AS total_records,
  count(*) FILTER (WHERE is_active) AS active,
  count(*) FILTER (WHERE NOT is_active) AS merged_away,
  count(*) FILTER (WHERE merged_from IS NOT NULL AND is_active) AS survivors_with_merges
FROM core.person_spine;
