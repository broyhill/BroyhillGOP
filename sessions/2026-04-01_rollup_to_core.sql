/*
 * NC BOE → core.contribution_map ROLLUP
 * Session: 2026-04-01
 *
 * CURSOR: Please audit this file, run STEP 1 (read-only), confirm counts match
 * expectations, then run STEP 2+3 inside Cursor with your own rollback protection.
 * Report back on Step 4 canary results.
 *
 * Prerequisites (all confirmed complete as of 2026-04-01 23:00 EDT):
 *   ✅ staging.boe_donation_candidate_map: 338,213 rows, 100% partisan_flag=R
 *   ✅ candidate_name match rate: 99.7% (337,108 / 338,213)
 *   ✅ staging.sboe_committee_master loaded: 13,237 rows
 *   ✅ committee_registry.candidate_name: 1,690 rows filled
 *   ✅ Match methods: exact=52.1%, sboe_registry=33.1%, null=14.3%, fuzzy=0.5%
 *
 * What this script does:
 *   Step 1 — COUNT check (read-only, run first, confirm before proceeding)
 *   Step 2+3 — DELETE stale NC_BOE rows + INSERT 338,213 fresh rows (transactional)
 *   Step 4 — Post-commit verification including Ed Broyhill canary
 *
 * Known state going in:
 *   core.contribution_map NC_BOE rows: 108,943 (stale, from before candidate fix)
 *   Expected after rollup: ~338,213 rows where person_id IS NOT NULL
 *   Ed Broyhill person_id: 26451
 *   Ed Broyhill expected total_contributed: ~$478,632 (canary benchmark)
 */

-- ============================================================
-- STEP 1: COUNT CHECK (READ-ONLY — run this, confirm, then proceed)
-- ============================================================

SELECT
  'staging total rows'         AS label, COUNT(*)                    AS n
FROM staging.boe_donation_candidate_map
UNION ALL
SELECT
  'staging with candidate_name' AS label, COUNT(candidate_name)      AS n
FROM staging.boe_donation_candidate_map
UNION ALL
SELECT
  'staging partisan_flag=R'    AS label, COUNT(*)                    AS n
FROM staging.boe_donation_candidate_map WHERE partisan_flag = 'R'
UNION ALL
SELECT
  'staging with person_id'     AS label, COUNT(*)                    AS n
FROM staging.boe_donation_candidate_map WHERE person_id IS NOT NULL
UNION ALL
SELECT
  'core NC_BOE rows (stale)'   AS label, COUNT(*)                    AS n
FROM core.contribution_map WHERE source_system = 'NC_BOE'
UNION ALL
SELECT
  'core total rows'            AS label, COUNT(*)                    AS n
FROM core.contribution_map;

/*
 CURSOR AUDIT CHECKPOINT — before running Step 2+3, confirm:
   □ staging total rows     = 338,213
   □ staging partisan_flag  = 338,213  (all R)
   □ staging candidate_name ≥ 337,000  (99%+)
   □ staging with person_id > 0        (if 0, person matching hasn't run — STOP)
   □ core NC_BOE rows       = 108,943  (expected stale count)
 If any check fails, DO NOT proceed. Report back.
*/


-- ============================================================
-- STEP 2+3: DELETE stale + INSERT fresh (transactional)
-- ============================================================

BEGIN;

-- 2. Remove stale NC_BOE rows
DELETE FROM core.contribution_map
WHERE source_system = 'NC_BOE';

-- 3. Insert fresh from staging (only person-resolved rows)
INSERT INTO core.contribution_map (
    person_id,
    source_system,
    source_id,
    amount,
    transaction_date,
    committee_id,
    party_flag
)
SELECT
    m.person_id,
    'NC_BOE'                        AS source_system,
    m.boe_id::bigint                AS source_id,
    m.amount_numeric                AS amount,
    m.date_occurred::date           AS transaction_date,
    m.committee_sboe_id             AS committee_id,
    m.partisan_flag                 AS party_flag
FROM staging.boe_donation_candidate_map m
WHERE m.person_id IS NOT NULL;

-- Count check inside transaction — review before committing
SELECT
  'rows inserted (NC_BOE)'  AS label, COUNT(*) AS n
FROM core.contribution_map WHERE source_system = 'NC_BOE'
UNION ALL
SELECT
  'core total after insert'  AS label, COUNT(*) AS n
FROM core.contribution_map;

/*
 CURSOR AUDIT CHECKPOINT — before COMMIT:
   □ rows inserted (NC_BOE) should be > 108,943 (the old stale count)
   □ rows inserted (NC_BOE) should be ≤ 338,213 (bounded by person_id IS NOT NULL)
   □ core total should be (prior non-BOE rows) + new BOE rows
 If counts look wrong → ROLLBACK and report.
*/

COMMIT;
-- or: ROLLBACK;


-- ============================================================
-- STEP 4: POST-COMMIT VERIFICATION
-- ============================================================

-- 4a. Source breakdown
SELECT source_system, COUNT(*) AS rows, SUM(amount) AS total_amount
FROM core.contribution_map
GROUP BY source_system
ORDER BY rows DESC;

-- 4b. Ed Broyhill canary (person_id=26451)
--     Previous person_spine.total_contributed = $478,632
--     Previous contribution_map SUM           = $709,767  (delta -$231,135)
--     After rollup, the SUM should move closer to $478,632
--     Report both numbers so we can see if the delta closed.
SELECT
  person_id,
  COUNT(*)        AS tx_count,
  SUM(amount)     AS contribution_map_total
FROM core.contribution_map
WHERE person_id = 26451
GROUP BY person_id;

-- 4c. Party flag sanity (all NC_BOE should be R)
SELECT party_flag, COUNT(*) AS n
FROM core.contribution_map
WHERE source_system = 'NC_BOE'
GROUP BY party_flag;

-- 4d. Year distribution sanity check
SELECT
  EXTRACT(YEAR FROM transaction_date)::int AS yr,
  COUNT(*) AS n,
  SUM(amount) AS total
FROM core.contribution_map
WHERE source_system = 'NC_BOE'
GROUP BY yr
ORDER BY yr DESC
LIMIT 10;
