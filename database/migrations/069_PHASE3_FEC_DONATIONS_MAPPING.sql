-- 069_PHASE3_FEC_DONATIONS_MAPPING.sql
-- Identity Resolution Phase 3: Map fec_donations (1.13M rows) to person_spine
-- This table is currently a complete island — no person/voter linkage at all
-- PREREQUISITE: 066-068 (spine deduped and voter-matched)
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: Add person_spine linkage column to fec_donations
-- =============================================================================
ALTER TABLE fec_donations ADD COLUMN IF NOT EXISTS spine_person_id INTEGER;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fd_spine ON fec_donations(spine_person_id) 
  WHERE spine_person_id IS NOT NULL;

-- =============================================================================
-- STEP 2: Normalize FEC contributor names for matching
-- fec_donations has: contributor_last_norm, contributor_first_norm, 
--   contributor_zip5, contributor_state, contributor_employer, employer_normalized
-- =============================================================================

-- Check what we have
SELECT 
  count(*) AS total,
  count(contributor_last_norm) AS has_last,
  count(contributor_first_norm) AS has_first,
  count(contributor_zip5) AS has_zip5,
  count(contributor_state) AS has_state
FROM fec_donations;

-- =============================================================================
-- STEP 3: Match FEC donors to existing spine records
-- Strategy: last_norm + first_norm + zip5 → spine.norm_last + norm_first + zip5
-- =============================================================================

-- Pass 1: Exact name + zip (high confidence)
UPDATE fec_donations fd SET
  spine_person_id = sub.person_id
FROM (
  SELECT DISTINCT ON (fd2.id)
    fd2.id AS fec_id,
    sp.person_id
  FROM fec_donations fd2
  JOIN core.person_spine sp
    ON UPPER(fd2.contributor_last_norm) = sp.norm_last
    AND UPPER(fd2.contributor_first_norm) = sp.norm_first
    AND fd2.contributor_zip5 = sp.zip5
  WHERE fd2.spine_person_id IS NULL
    AND sp.is_active = true
    AND fd2.contributor_last_norm IS NOT NULL
    AND fd2.contributor_zip5 IS NOT NULL
  ORDER BY fd2.id, sp.contribution_count DESC
) sub
WHERE fd.id = sub.fec_id;

SELECT 'FEC Pass 1 (exact name+zip)' AS label,
  count(spine_person_id) AS matched,
  round(100.0 * count(spine_person_id) / count(*), 1) AS pct
FROM fec_donations;

-- Pass 2: Canonical first + last + zip5
UPDATE fec_donations fd SET
  spine_person_id = sub.person_id
FROM (
  SELECT DISTINCT ON (fd2.id)
    fd2.id AS fec_id,
    sp.person_id
  FROM fec_donations fd2
  JOIN staging.spine_canonical sc ON true
  JOIN core.person_spine sp ON sc.person_id = sp.person_id
  WHERE UPPER(fd2.contributor_last_norm) = sp.norm_last
    AND (fn_normalize_donor_name(
      fd2.contributor_first_norm || ' ' || fd2.contributor_last_norm
    )).canonical_first_name = sc.canonical_first
    AND fd2.contributor_zip5 = sp.zip5
    AND fd2.spine_person_id IS NULL
    AND sp.is_active = true
    AND fd2.contributor_last_norm IS NOT NULL
    AND fd2.contributor_zip5 IS NOT NULL
    AND sc.canonical_first IS NOT NULL
  ORDER BY fd2.id, sp.contribution_count DESC
) sub
WHERE fd.id = sub.fec_id;

SELECT 'FEC Pass 2 (canonical+zip)' AS label,
  count(spine_person_id) AS matched,
  round(100.0 * count(spine_person_id) / count(*), 1) AS pct
FROM fec_donations;

-- =============================================================================
-- STEP 4: Create NEW spine records for unmatched FEC donors
-- These are people who donated via FEC but have no NC BOE record
-- Many will be out-of-state donors to NC committees
-- =============================================================================
INSERT INTO core.person_spine (
  last_name, first_name, norm_last, norm_first, 
  city, state, zip5, employer, occupation,
  contribution_count, total_contributed, first_contribution, last_contribution,
  is_active, created_at, updated_at
)
SELECT
  UPPER(r.contributor_last_norm),
  UPPER(r.contributor_first_norm),
  UPPER(r.contributor_last_norm),
  UPPER(r.contributor_first_norm),
  r.contributor_city,
  r.contributor_state,
  r.contributor_zip5,
  r.employer_normalized,
  r.contributor_occupation,
  r.txn_count,
  r.total_amt,
  r.first_dt,
  r.last_dt,
  true, NOW(), NOW()
FROM (
  SELECT 
    contributor_last_norm, contributor_first_norm,
    (ARRAY_AGG(contributor_city ORDER BY contribution_receipt_date DESC))[1] AS contributor_city,
    (ARRAY_AGG(contributor_state ORDER BY contribution_receipt_date DESC))[1] AS contributor_state,
    contributor_zip5,
    (ARRAY_AGG(employer_normalized ORDER BY contribution_receipt_date DESC))[1] AS employer_normalized,
    (ARRAY_AGG(contributor_occupation ORDER BY contribution_receipt_date DESC))[1] AS contributor_occupation,
    count(*) AS txn_count,
    sum(contribution_receipt_amount) AS total_amt,
    min(contribution_receipt_date) AS first_dt,
    max(contribution_receipt_date) AS last_dt
  FROM fec_donations
  WHERE spine_person_id IS NULL
    AND contributor_last_norm IS NOT NULL AND contributor_last_norm != ''
    AND contributor_first_norm IS NOT NULL AND contributor_first_norm != ''
  GROUP BY contributor_last_norm, contributor_first_norm, contributor_zip5
) r
WHERE r.txn_count >= 1;  -- include all donors

-- Now link the newly created spine records back to fec_donations
UPDATE fec_donations fd SET
  spine_person_id = sp.person_id
FROM core.person_spine sp
WHERE fd.spine_person_id IS NULL
  AND UPPER(fd.contributor_last_norm) = sp.norm_last
  AND UPPER(fd.contributor_first_norm) = sp.norm_first
  AND fd.contributor_zip5 = sp.zip5
  AND sp.is_active = true
  AND fd.contributor_last_norm IS NOT NULL;

SELECT 'FEC final linkage' AS label,
  count(spine_person_id) AS matched,
  count(*) - count(spine_person_id) AS unmatched,
  round(100.0 * count(spine_person_id) / count(*), 1) AS pct
FROM fec_donations;

-- =============================================================================
-- STEP 5: Add fec_donations to donor_contribution_map
-- =============================================================================
INSERT INTO donor_contribution_map (
  source_id, source_system, golden_record_id,
  contribution_receipt_amount, contribution_receipt_date, committee_id
)
SELECT 
  fd.id::text,
  'fec_donations',
  fd.spine_person_id,
  fd.contribution_receipt_amount,
  fd.contribution_receipt_date,
  fd.committee_id
FROM fec_donations fd
WHERE fd.spine_person_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM donor_contribution_map m
    WHERE m.source_system = 'fec_donations' AND m.source_id = fd.id::text
  );

SELECT 'donor_contribution_map after FEC add' AS label,
  source_system, count(*) AS rows
FROM donor_contribution_map
GROUP BY source_system ORDER BY count(*) DESC;

COMMIT;
