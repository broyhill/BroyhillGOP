-- ============================================================================
-- DONOR ROLLUP — PATCH SET
-- BroyhillGOP — March 31, 2026
-- Fixes three issues from Cursor's execution report:
--   1. Pass 1: Add first-name tiebreaker to resolve 525-address household ties
--   2. Pass 3: Rewrite employer match using BOE self-join (no DataTrust employer)
--   3. Pass 5: Replace norm_last with true_last in fingerprint CTE
-- Run AFTER tmp_boe_street is built (it already has true_last + true_first)
-- ============================================================================

-- ============================================================================
-- PATCH 1 — TRUE_LAST suffix handling (ensure II/III/JR/SR stripped)
-- Add this to tmp_boe_street creation if not already applied by runner
-- ============================================================================

-- Verify suffix stripping is working:
SELECT donor_name, true_last, true_first
FROM tmp_boe_street
WHERE donor_name ILIKE '%BROYHILL%'
  AND norm_zip5 IN ('27104','27012')
  AND street_num = '525'
ORDER BY donor_name;
-- Every row must show true_last = 'BROYHILL'
-- true_first must NOT contain II, III, JR, SR

-- ============================================================================
-- PATCH 2 — PASS 1 REBUILD with first-name tiebreaker
-- Resolves Ed vs Melanie at 525 Hawthorne
-- Key insight: add canonical first name to match key
-- Ed's canonical: JAMES/EDGAR/ED/J  ≠  Melanie's: MELANIE
-- ============================================================================

DROP TABLE IF EXISTS staging.staging_pass1_street_match;

CREATE TABLE staging.staging_pass1_street_match AS
SELECT
  b.boe_id,
  b.donor_name                                                 AS boe_name,
  b.true_last                                                  AS boe_last,
  b.true_first                                                 AS boe_first,
  -- Canonical first via name_variants (BOB→ROBERT etc)
  COALESCE(nv.canonical, b.true_first)                         AS boe_canonical_first,
  b.street_num                                                 AS boe_street_num,
  b.norm_zip5                                                  AS boe_zip,
  b.employer_name                                              AS boe_employer,
  d.statevoterid,
  d.rncid,
  d.firstname                                                  AS dt_first,
  d.lastname                                                   AS dt_last,
  d.street_num                                                 AS dt_street_num,
  LEFT(d.regzip5,5)                                            AS dt_zip,
  d.age                                                        AS dt_age,
  -- Match count: how many DataTrust people share this street+zip+last+first_canonical
  count(*) OVER (
    PARTITION BY
      b.street_num,
      LEFT(b.norm_zip5, 5),
      LEFT(b.true_last, 3),
      COALESCE(nv.canonical, b.true_first)   -- first name in match key
  )                                                            AS match_count
FROM tmp_boe_street b
LEFT JOIN public.name_variants nv ON nv.nickname = b.true_first
JOIN tmp_dt_street d
  ON b.street_num              = d.street_num
  AND LEFT(b.norm_zip5, 5)     = LEFT(d.regzip5, 5)
  AND LEFT(b.true_last, 3)     = LEFT(d.lastname, 3)
  -- First name must be compatible: canonical match or DataTrust firstname fuzzy
  AND (
    -- Exact canonical match
    COALESCE(nv.canonical, b.true_first) = d.firstname
    -- OR DataTrust firstname resolves to same canonical
    OR EXISTS (
      SELECT 1 FROM public.name_variants nv2
      WHERE nv2.nickname  = d.firstname
        AND nv2.canonical = COALESCE(nv.canonical, b.true_first)
    )
    -- OR first 2 chars match (J EDGAR → JAMES, ED → EDGAR)
    OR LEFT(COALESCE(nv.canonical, b.true_first), 2) = LEFT(d.firstname, 2)
  )
WHERE NOT EXISTS (
  SELECT 1 FROM core.contribution_map cm
  JOIN core.person_spine sp ON sp.person_id = cm.person_id
  WHERE cm.source_system = 'NC_BOE'
    AND cm.source_id = b.boe_id
    AND sp.voter_ncid IS NOT NULL
);

-- Verify distribution
SELECT match_count, count(*) AS boe_rows
FROM staging.staging_pass1_street_match
GROUP BY 1 ORDER BY 1;

-- Canary: Ed should now be clean single, Melanie separate clean single
SELECT boe_name, boe_canonical_first, statevoterid, rncid, match_count
FROM staging.staging_pass1_street_match
WHERE boe_zip IN ('27104','27012')
  AND boe_street_num = '525'
  AND boe_last = 'BROYHILL'
ORDER BY statevoterid, boe_name;
-- Expected: BN94856 rows (Ed) + BN9956 rows (Melanie) — each match_count = 1

-- ============================================================================
-- PATCH 3 — PASS 3 REBUILD: Employer self-join on BOE data
-- No DataTrust employer column — use nc_boe_donations_raw itself
-- Same canonical employer + zip + last prefix across different donor_name = same person
-- ============================================================================

DROP TABLE IF EXISTS staging.staging_pass3_employer;

CREATE TABLE staging.staging_pass3_employer AS
WITH boe_employer_canonical AS (
  -- Tag each BOE row with its canonical employer (via employer_aliases)
  SELECT
    b.boe_id,
    b.donor_name,
    b.true_last,
    b.true_first,
    b.norm_zip5,
    b.street_num,
    b.boe_employer,
    ea.canonical_employer,
    ea.sic_code
  FROM tmp_boe_street b
  JOIN public.employer_aliases ea
    ON upper(trim(b.boe_employer)) = upper(trim(ea.alias_employer))
  WHERE b.boe_employer IS NOT NULL
    AND upper(trim(b.boe_employer)) NOT IN (
      'RETIRED','SELF-EMPLOYED','SELF EMPLOYED','N/A','','NO EMPLOYER',
      'INFORMATION REQUESTED','NOT EMPLOYED','HOMEMAKER','STUDENT'
    )
),
-- Find pairs: same canonical employer + zip + last prefix, different donor_name
employer_pairs AS (
  SELECT
    a.boe_id                                                   AS boe_id_a,
    b2.boe_id                                                  AS boe_id_b,
    a.donor_name                                               AS name_a,
    b2.donor_name                                              AS name_b,
    a.true_last,
    a.canonical_employer,
    a.sic_code,
    LEFT(a.norm_zip5,5)                                        AS zip5,
    count(*) OVER (
      PARTITION BY a.canonical_employer, LEFT(a.norm_zip5,5), LEFT(a.true_last,3)
    )                                                          AS pair_count
  FROM boe_employer_canonical a
  JOIN boe_employer_canonical b2
    ON a.canonical_employer        = b2.canonical_employer
    AND LEFT(a.norm_zip5,5)        = LEFT(b2.norm_zip5,5)
    AND LEFT(a.true_last,3)        = LEFT(b2.true_last,3)
    AND a.donor_name               != b2.donor_name
    AND a.boe_id                   < b2.boe_id
)
-- Join both BOE IDs to DataTrust to get statevoterid/rncid
SELECT
  ep.boe_id_a,
  ep.boe_id_b,
  ep.name_a,
  ep.name_b,
  ep.true_last,
  ep.canonical_employer,
  ep.sic_code,
  ep.zip5,
  ep.pair_count,
  d.statevoterid,
  d.rncid,
  d.firstname                                                  AS dt_first,
  d.lastname                                                   AS dt_last
FROM employer_pairs ep
JOIN tmp_dt_street d
  ON LEFT(d.lastname, 3)   = LEFT(ep.true_last, 3)
  AND LEFT(d.regzip5, 5)   = ep.zip5
WHERE ep.pair_count = 1;  -- unambiguous employer+zip+last combination only

SELECT
  pair_count,
  count(*)                                                     AS pairs
FROM staging.staging_pass3_employer
GROUP BY 1 ORDER BY 1;

SELECT
  count(*) FILTER (WHERE pair_count = 1)                       AS clean_employer_pairs,
  count(DISTINCT canonical_employer)                           AS distinct_employers
FROM staging.staging_pass3_employer;

-- ============================================================================
-- PATCH 4 — PASS 5 REBUILD: Use true_last instead of norm_last
-- Fixes J EDGAR BROYHILL → true_last = BROYHILL (not norm_last = J EDGAR BROYHILL)
-- ============================================================================

DROP TABLE IF EXISTS staging.staging_pass5_fingerprint;

CREATE TABLE staging.staging_pass5_fingerprint AS
WITH fingerprints AS (
  SELECT
    -- Use same true_last extraction as tmp_boe_street
    CASE
      WHEN donor_name LIKE '%,%' THEN
        upper(trim(split_part(donor_name, ',', 1)))
      ELSE
        upper(trim(
          split_part(donor_name, ' ',
            array_length(string_to_array(trim(donor_name), ' '), 1)
          )
        ))
    END                                                        AS true_last,
    LEFT(norm_zip5, 5)                                         AS zip5,
    committee_sboe_id,
    -- Enrich with committee registry
    cr.committee_name,
    cr.committee_type,
    cr.candidate_name                                          AS committee_candidate,
    nc.contest_name                                            AS office,
    count(DISTINCT EXTRACT(year FROM date_occurred))           AS cycles,
    sum(amount_numeric)                                        AS total_given
  FROM public.nc_boe_donations_raw r
  LEFT JOIN public.committee_registry cr
    ON cr.sboe_id = r.committee_sboe_id
  LEFT JOIN public.ncsbe_candidates nc
    ON upper(trim(nc.candidate_name)) = upper(trim(cr.candidate_name))
    AND nc.party ILIKE '%REP%'
  WHERE transaction_type = 'Individual'
    AND norm_zip5 IS NOT NULL
    AND committee_sboe_id IS NOT NULL
    AND date_occurred >= '2015-01-01'
    AND date_occurred <= '2026-12-31'
    -- Strip suffixes from extracted last name
    AND CASE
      WHEN donor_name LIKE '%,%' THEN upper(trim(split_part(donor_name,',',1)))
      ELSE upper(trim(split_part(donor_name,' ',
        array_length(string_to_array(trim(donor_name),' '),1))))
    END NOT IN ('II','III','IV','JR','SR','JR.','SR.')
  GROUP BY 1, 2, 3, 4, 5, 6, 7
  HAVING count(DISTINCT EXTRACT(year FROM date_occurred)) >= 3
),
-- Find name variant pairs sharing 2+ anchor committees at same zip
shared AS (
  SELECT
    f1.true_last                                               AS name_a,
    f2.true_last                                               AS name_b,
    f1.zip5,
    count(DISTINCT f1.committee_sboe_id)                       AS shared_committees,
    array_agg(DISTINCT f1.committee_sboe_id
              ORDER BY f1.committee_sboe_id)                   AS committee_ids,
    array_agg(DISTINCT f1.committee_candidate
              ORDER BY f1.committee_candidate)                 AS candidates
  FROM fingerprints f1
  JOIN fingerprints f2
    ON f1.committee_sboe_id = f2.committee_sboe_id
    AND f1.zip5             = f2.zip5
    AND f1.true_last        != f2.true_last
    AND f1.true_last        < f2.true_last
  GROUP BY 1, 2, 3
  HAVING count(DISTINCT f1.committee_sboe_id) >= 2
)
SELECT * FROM shared ORDER BY shared_committees DESC;

-- Report top pairs
SELECT name_a, name_b, zip5, shared_committees, candidates
FROM staging.staging_pass5_fingerprint
ORDER BY shared_committees DESC
LIMIT 30;

-- Canary: Ed's variants should now share many committees
SELECT name_a, name_b, zip5, shared_committees
FROM staging.staging_pass5_fingerprint
WHERE (name_a ILIKE '%BROYHILL%' OR name_b ILIKE '%BROYHILL%')
  AND zip5 IN ('27104','27012')
ORDER BY shared_committees DESC;

-- ============================================================================
-- FINAL CANARY after all patches
-- ============================================================================

-- Ed Broyhill full resolution check
SELECT
  boe_name,
  boe_canonical_first,
  statevoterid,
  rncid,
  match_count,
  'pass1_street_patched' AS method
FROM staging.staging_pass1_street_match
WHERE boe_zip IN ('27104','27012')
  AND boe_street_num = '525'
  AND boe_last = 'BROYHILL'
ORDER BY statevoterid, boe_name;

-- Summary counts after patches
SELECT
  (SELECT count(*) FILTER (WHERE match_count=1) FROM staging.staging_pass1_street_match) AS pass1_clean,
  (SELECT count(*) FILTER (WHERE match_count>1) FROM staging.staging_pass1_street_match) AS pass1_ambiguous,
  (SELECT count(*) FROM staging.staging_pass3_employer WHERE pair_count=1)               AS pass3_clean_pairs,
  (SELECT count(*) FROM staging.staging_pass5_fingerprint WHERE shared_committees >= 2)  AS pass5_pairs,
  (SELECT count(*) FILTER (WHERE match_count=1) FROM staging.staging_pass6_nickname)     AS pass6_clean,
  (SELECT count(*) FILTER (WHERE match_count=1) FROM staging.staging_pass7_recency)      AS pass7_clean;

-- Report this table to Ed before any merge authorization.
