-- 066_PHASE1_SPINE_DEDUP.sql
-- Identity Resolution Phase 1: Deduplicate core.person_spine
-- Merges fragmented records (e.g., Art Pope = 4-5 records → 1)
-- Uses fn_normalize_donor_name for canonical name resolution
-- Uses union-find for transitive clustering
--
-- PREREQUISITE: Run 065 first (nc_voters indexes needed for Phase 2)
-- CRITICAL: Never delete spine records. Mark merged as is_active = false.
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: Create staging schema if not exists
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS staging;

-- =============================================================================
-- STEP 2: Precompute canonical_first for all active spine records
-- This avoids calling fn_normalize_donor_name in every join
-- =============================================================================
DROP TABLE IF EXISTS staging.spine_canonical;
CREATE TABLE staging.spine_canonical AS
SELECT 
  person_id,
  norm_last,
  norm_first,
  zip5,
  city,
  employer,
  voter_ncid,
  contribution_count,
  total_contributed,
  is_active,
  (fn_normalize_donor_name(
    COALESCE(first_name, norm_first) || ' ' || COALESCE(last_name, norm_last)
  )).canonical_first_name AS canonical_first
FROM core.person_spine
WHERE is_active = true;

CREATE INDEX idx_sc_last_canon_zip ON staging.spine_canonical(norm_last, canonical_first, zip5);
CREATE INDEX idx_sc_voter ON staging.spine_canonical(voter_ncid) WHERE voter_ncid IS NOT NULL;
CREATE INDEX idx_sc_last_employer ON staging.spine_canonical(norm_last, employer, city);

SELECT count(*) AS active_spine_records FROM staging.spine_canonical;

-- =============================================================================
-- STEP 3: Build merge candidate pairs using 3 strategies
-- =============================================================================
DROP TABLE IF EXISTS staging.spine_merge_candidates;
CREATE TABLE staging.spine_merge_candidates (
  keep_id   INTEGER NOT NULL,
  merge_id  INTEGER NOT NULL,
  match_method TEXT NOT NULL,
  confidence NUMERIC(3,2) NOT NULL
);

-- Strategy A: Same canonical_first + last + zip5
-- Example: ART POPE (canonical=ARTHUR) + ARTHUR POPE + JAMES ARTHUR POPE → all ARTHUR
INSERT INTO staging.spine_merge_candidates (keep_id, merge_id, match_method, confidence)
SELECT 
  CASE WHEN a.contribution_count >= COALESCE(b.contribution_count,0) 
       THEN a.person_id ELSE b.person_id END,
  CASE WHEN a.contribution_count >= COALESCE(b.contribution_count,0) 
       THEN b.person_id ELSE a.person_id END,
  'canonical_name_zip',
  0.90
FROM staging.spine_canonical a
JOIN staging.spine_canonical b
  ON a.norm_last = b.norm_last
  AND a.canonical_first = b.canonical_first
  AND a.zip5 = b.zip5
  AND a.zip5 IS NOT NULL
  AND a.canonical_first IS NOT NULL
  AND a.canonical_first != ''
  AND a.person_id < b.person_id
  AND a.is_active AND b.is_active;

SELECT 'Strategy A (canonical+zip)' AS strategy, count(*) AS pairs FROM staging.spine_merge_candidates;

-- Strategy B: Same voter_ncid (definitive match)
INSERT INTO staging.spine_merge_candidates (keep_id, merge_id, match_method, confidence)
SELECT 
  CASE WHEN a.contribution_count >= COALESCE(b.contribution_count,0)
       THEN a.person_id ELSE b.person_id END,
  CASE WHEN a.contribution_count >= COALESCE(b.contribution_count,0)
       THEN b.person_id ELSE a.person_id END,
  'voter_ncid',
  1.00
FROM staging.spine_canonical a
JOIN staging.spine_canonical b
  ON a.voter_ncid = b.voter_ncid
  AND a.voter_ncid IS NOT NULL
  AND a.person_id < b.person_id
  AND a.is_active AND b.is_active
WHERE NOT EXISTS (
  SELECT 1 FROM staging.spine_merge_candidates m
  WHERE (m.keep_id = LEAST(a.person_id, b.person_id) 
    AND m.merge_id = GREATEST(a.person_id, b.person_id))
);

SELECT 'Strategy B (voter_ncid)' AS strategy, count(*) AS total_pairs FROM staging.spine_merge_candidates;

-- Strategy C: Same last + first initial + employer + city (no voter_ncid)
INSERT INTO staging.spine_merge_candidates (keep_id, merge_id, match_method, confidence)
SELECT 
  CASE WHEN a.contribution_count >= COALESCE(b.contribution_count,0)
       THEN a.person_id ELSE b.person_id END,
  CASE WHEN a.contribution_count >= COALESCE(b.contribution_count,0)
       THEN b.person_id ELSE a.person_id END,
  'employer_city',
  0.75
FROM staging.spine_canonical a
JOIN staging.spine_canonical b
  ON a.norm_last = b.norm_last
  AND LEFT(a.norm_first, 1) = LEFT(b.norm_first, 1)
  AND a.employer = b.employer
  AND a.employer IS NOT NULL AND a.employer != ''
  AND a.city = b.city
  AND a.city IS NOT NULL
  AND a.person_id < b.person_id
  AND a.is_active AND b.is_active
  AND a.voter_ncid IS NULL AND b.voter_ncid IS NULL
WHERE NOT EXISTS (
  SELECT 1 FROM staging.spine_merge_candidates m
  WHERE (m.keep_id = LEAST(a.person_id, b.person_id)
    AND m.merge_id = GREATEST(a.person_id, b.person_id))
);

SELECT 'All strategies combined' AS label, count(*) AS total_pairs FROM staging.spine_merge_candidates;
SELECT match_method, count(*), round(avg(confidence),2) AS avg_conf 
FROM staging.spine_merge_candidates GROUP BY match_method ORDER BY count(*) DESC;

-- =============================================================================
-- STEP 4: Union-Find Clustering (transitive closure)
-- If A→B and B→C, then A,B,C are all one cluster
-- =============================================================================
DROP TABLE IF EXISTS staging.spine_clusters;

-- Recursive CTE to find connected components
WITH RECURSIVE edges AS (
  -- Normalize to undirected edges
  SELECT keep_id AS a, merge_id AS b FROM staging.spine_merge_candidates
  UNION
  SELECT merge_id, keep_id FROM staging.spine_merge_candidates
),
-- Find the minimum reachable node for each node (flood fill)
flood AS (
  SELECT a AS node, a AS root FROM edges
  UNION
  SELECT e.b, LEAST(f.root, e.a)
  FROM flood f
  JOIN edges e ON f.node = e.a
  WHERE LEAST(f.root, e.a) < f.root
),
-- Take the minimum root per node
components AS (
  SELECT node AS person_id, MIN(root) AS cluster_root
  FROM flood
  GROUP BY node
)
SELECT person_id, cluster_root
INTO staging.spine_clusters
FROM components;

-- Add singleton info
ALTER TABLE staging.spine_clusters ADD COLUMN is_canonical BOOLEAN DEFAULT false;
ALTER TABLE staging.spine_clusters ADD COLUMN cluster_size INTEGER;

-- Pick canonical = the cluster_root member with highest contribution_count
-- First, compute cluster sizes
UPDATE staging.spine_clusters sc
SET cluster_size = cs.sz
FROM (SELECT cluster_root, count(*) AS sz FROM staging.spine_clusters GROUP BY cluster_root) cs
WHERE sc.cluster_root = cs.cluster_root;

-- Mark the canonical record per cluster (highest contribution_count wins)
WITH ranked AS (
  SELECT sc.person_id, sc.cluster_root,
    ROW_NUMBER() OVER (
      PARTITION BY sc.cluster_root 
      ORDER BY COALESCE(sp.contribution_count,0) DESC, 
               CASE WHEN sp.voter_ncid IS NOT NULL THEN 0 ELSE 1 END,
               sp.person_id
    ) AS rn
  FROM staging.spine_clusters sc
  JOIN core.person_spine sp ON sc.person_id = sp.person_id
)
UPDATE staging.spine_clusters sc
SET is_canonical = true
FROM ranked r
WHERE sc.person_id = r.person_id AND r.rn = 1;

SELECT 'Clusters found' AS label, count(DISTINCT cluster_root) AS cluster_count,
       sum(cluster_size) AS total_records_in_clusters
FROM staging.spine_clusters WHERE is_canonical;

-- Show multi-member clusters (actual merges needed)
SELECT cluster_size, count(*) AS num_clusters
FROM staging.spine_clusters WHERE is_canonical AND cluster_size > 1
GROUP BY cluster_size ORDER BY cluster_size;

COMMIT;

-- =============================================================================
-- STEP 5: Preview Art Pope cluster BEFORE executing merge
-- =============================================================================
SELECT sc.cluster_root, sc.person_id, sc.is_canonical, sc.cluster_size,
       sp.norm_first, sp.norm_last, sp.voter_ncid, sp.contribution_count, sp.total_contributed
FROM staging.spine_clusters sc
JOIN core.person_spine sp ON sc.person_id = sp.person_id
WHERE sc.cluster_root IN (
  SELECT sc2.cluster_root FROM staging.spine_clusters sc2
  JOIN core.person_spine sp2 ON sc2.person_id = sp2.person_id
  WHERE sp2.norm_last = 'POPE' AND sp2.norm_first IN ('ART','ARTHUR','JAMES')
)
ORDER BY sc.cluster_root, sc.is_canonical DESC, sp.contribution_count DESC;

-- =============================================================================
-- MANUAL CHECKPOINT: Review the Art Pope cluster above.
-- The canonical record should be the one with voter_ncid = EH34831 and ~134 txns.
-- ART POPE, ARTHRU POPE, ARTHUR POPE should be in the same cluster.
-- Other JAMES POPEs with different voter_ncids should be SEPARATE clusters.
-- If this looks wrong, DO NOT proceed. Adjust strategies above.
-- =============================================================================
