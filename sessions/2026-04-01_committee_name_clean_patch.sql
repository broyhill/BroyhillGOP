-- ============================================================================
-- COMMITTEE CANDIDATE NAME CLEANING PATCH
-- BroyhillGOP — April 1, 2026
--
-- PROBLEM: 397 committees have candidate_name in committee_registry that
-- don't match ncsbe_candidates because of noise:
--   "ROBERT (BOB) CHILMONIK" → should match "Robert Chilmonik"
--   "TIM HYATT TO NC HOUSE 114" → should match "Tim Hyatt"
--   "DR AUMULLER" → should match "Aumuller, ..."
--   "RAY 4 SENATE" → slogan, not matchable
--   "DEVIN KING NC STATE SENATE" → append noise
--
-- SOLUTION: Create cleaned candidate name for matching only
-- Do NOT alter committee_registry — add a derived column for matching
-- ============================================================================

SET statement_timeout = 0;

-- ============================================================================
-- STEP 1 — Build cleaned name lookup from committee_registry
-- ============================================================================
DROP TABLE IF EXISTS staging.committee_registry_clean_names;

CREATE TABLE staging.committee_registry_clean_names AS
SELECT
  sboe_id,
  candidate_name                                               AS raw_candidate_name,
  -- Step 1: Remove parenthetical nicknames: "ROBERT (BOB) CHILMONIK" → "ROBERT CHILMONIK"
  -- Step 2: Remove office/district noise: "TIM HYATT TO NC HOUSE 114" → "TIM HYATT"
  -- Step 3: Remove titles: "DR ", "REV ", "SGT ", "CPT "
  -- Step 4: Trim and normalize spaces
  upper(trim(regexp_replace(
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            candidate_name,
            '\s*\([^)]*\)', '', 'g'           -- remove (BOB), (TIM), etc.
          ),
          '\s+(TO|FOR|NC|4)\s+(NC\s+)?(HOUSE|SENATE|CONGRESS|DISTRICT|SEAT)\s*\d*.*$',
          '', 'gi'                             -- remove "TO NC HOUSE 114", "FOR NC SENATE" etc.
        ),
        '^\s*(DR|REV|SGT|CPT|LT|COL|GEN|HON|SEN|REP|JUDGE|JUSTICE)\.?\s+',
        '', 'gi'                               -- remove title prefixes
      ),
      '\s+NC\s+(STATE\s+)?(HOUSE|SENATE|CONGRESS)\s*\d*\s*$',
      '', 'gi'                                -- remove trailing " NC HOUSE 30" etc.
    ),
    '\s{2,}', ' ', 'g'                        -- collapse multiple spaces
  )))                                          AS clean_candidate_name
FROM public.committee_registry
WHERE candidate_name IS NOT NULL
  AND candidate_name != ''
  -- Skip obvious slogans (no space = one word, or contains digits mid-name)
  AND candidate_name ~ '[A-Za-z]{2,}\s+[A-Za-z]{2,}';  -- at least two words

-- Show sample of cleaning results
SELECT raw_candidate_name, clean_candidate_name
FROM staging.committee_registry_clean_names
WHERE raw_candidate_name != clean_candidate_name
ORDER BY raw_candidate_name
LIMIT 40;

-- ============================================================================
-- STEP 2 — Rebuild bridge using cleaned names
-- ============================================================================
DROP TABLE IF EXISTS staging.committee_candidate_bridge;

CREATE TABLE staging.committee_candidate_bridge AS

-- TIER 1: Exact match on clean name
WITH exact_match AS (
  SELECT DISTINCT ON (cn.sboe_id)
    cn.sboe_id                                                 AS committee_sboe_id,
    cr.committee_name,
    cn.raw_candidate_name                                      AS registry_candidate_name,
    nc.name_on_ballot,
    nc.contest_name,
    nc.county_name,
    nc.party_candidate,
    nc.election_dt,
    1.000::numeric                                             AS match_confidence,
    'exact'                                                    AS match_method
  FROM staging.committee_registry_clean_names cn
  JOIN public.committee_registry cr ON cr.sboe_id = cn.sboe_id
  JOIN public.ncsbe_candidates nc
    ON upper(trim(nc.name_on_ballot)) = cn.clean_candidate_name
    AND nc.party_candidate ILIKE '%REP%'
  ORDER BY cn.sboe_id, nc.election_dt DESC NULLS LAST
),

unmatched AS (
  SELECT cn.sboe_id, cr.committee_name, cn.raw_candidate_name, cn.clean_candidate_name
  FROM staging.committee_registry_clean_names cn
  JOIN public.committee_registry cr ON cr.sboe_id = cn.sboe_id
  WHERE cn.sboe_id NOT IN (SELECT committee_sboe_id FROM exact_match)
),

-- TIER 2: Last name + first 3 chars on cleaned names
tier2 AS (
  SELECT DISTINCT ON (u.sboe_id)
    u.sboe_id                                                  AS committee_sboe_id,
    u.committee_name,
    u.raw_candidate_name                                       AS registry_candidate_name,
    nc.name_on_ballot,
    nc.contest_name,
    nc.county_name,
    nc.party_candidate,
    nc.election_dt,
    0.850::numeric                                             AS match_confidence,
    'last_first3'                                              AS match_method,
    count(*) OVER (PARTITION BY u.sboe_id)                    AS match_count
  FROM unmatched u
  JOIN public.ncsbe_candidates nc
    ON nc.party_candidate ILIKE '%REP%'
    AND (
      -- Clean name in "FIRST LAST" format — last word matches
      upper(trim(split_part(u.clean_candidate_name, ' ',
        array_length(string_to_array(trim(u.clean_candidate_name),' '),1))))
      = upper(trim(split_part(nc.name_on_ballot, ' ',
        array_length(string_to_array(trim(nc.name_on_ballot),' '),1))))
      -- First 3 chars of first word match
      AND LEFT(upper(trim(split_part(u.clean_candidate_name,' ',1))),3)
        = LEFT(upper(trim(split_part(nc.name_on_ballot,' ',1))),3)
    )
  ORDER BY u.sboe_id, nc.election_dt DESC NULLS LAST
),

tier2_clean AS (SELECT * FROM tier2 WHERE match_count = 1),

-- TIER 3: pg_trgm similarity on cleaned names
tier3_unmatched AS (
  SELECT sboe_id, committee_name, raw_candidate_name, clean_candidate_name
  FROM unmatched WHERE sboe_id NOT IN (SELECT committee_sboe_id FROM tier2_clean)
),

tier3 AS (
  SELECT DISTINCT ON (u.sboe_id)
    u.sboe_id                                                  AS committee_sboe_id,
    u.committee_name,
    u.raw_candidate_name                                       AS registry_candidate_name,
    nc.name_on_ballot,
    nc.contest_name,
    nc.county_name,
    nc.party_candidate,
    nc.election_dt,
    similarity(u.clean_candidate_name, upper(trim(nc.name_on_ballot)))::numeric AS match_confidence,
    'fuzzy_trgm'                                               AS match_method,
    count(*) OVER (PARTITION BY u.sboe_id)                    AS match_count
  FROM tier3_unmatched u
  JOIN public.ncsbe_candidates nc
    ON similarity(u.clean_candidate_name, upper(trim(nc.name_on_ballot))) > 0.55
    AND nc.party_candidate ILIKE '%REP%'
  ORDER BY u.sboe_id,
    similarity(u.clean_candidate_name, upper(trim(nc.name_on_ballot))) DESC,
    nc.election_dt DESC NULLS LAST
),

tier3_clean AS (SELECT * FROM tier3 WHERE match_confidence > 0.55 AND match_count = 1)

-- Combine all tiers
SELECT committee_sboe_id, committee_name, registry_candidate_name,
       name_on_ballot, contest_name, county_name, party_candidate,
       election_dt, match_confidence, match_method
FROM exact_match
UNION ALL
SELECT committee_sboe_id, committee_name, registry_candidate_name,
       name_on_ballot, contest_name, county_name, party_candidate,
       election_dt, match_confidence, match_method
FROM tier2_clean
UNION ALL
SELECT committee_sboe_id, committee_name, registry_candidate_name,
       name_on_ballot, contest_name, county_name, party_candidate,
       election_dt, match_confidence, match_method
FROM tier3_clean;

CREATE INDEX idx_ccb_sboe ON staging.committee_candidate_bridge (committee_sboe_id);

-- ============================================================================
-- STEP 3 — Results
-- ============================================================================
SELECT match_method,
       count(*)                                                AS committees,
       round(avg(match_confidence)::numeric, 3)               AS avg_confidence
FROM staging.committee_candidate_bridge
GROUP BY 1 ORDER BY 2 DESC;

SELECT
  (SELECT count(*) FROM staging.committee_registry_clean_names) AS had_candidate_name,
  (SELECT count(*) FROM staging.committee_candidate_bridge)     AS now_matched,
  (SELECT count(*) FROM staging.committee_registry_clean_names)
  - (SELECT count(*) FROM staging.committee_candidate_bridge)   AS still_unmatched;

-- Sample new matches from cleaning
SELECT ccb.registry_candidate_name, ccb.name_on_ballot,
       ccb.match_confidence, ccb.match_method, ccb.contest_name
FROM staging.committee_candidate_bridge ccb
JOIN staging.committee_registry_clean_names cn
  ON cn.sboe_id = ccb.committee_sboe_id
WHERE cn.raw_candidate_name != cn.clean_candidate_name
ORDER BY ccb.match_method, ccb.match_confidence DESC
LIMIT 30;

-- ============================================================================
-- STEP 4 — Final donation match rate
-- ============================================================================
SELECT
  count(*)                                                     AS total_donations,
  count(*) FILTER (WHERE b.name_on_ballot IS NOT NULL)        AS matched_candidate,
  round(100.0 * count(*) FILTER (WHERE b.name_on_ballot IS NOT NULL)
    / count(*), 1)                                            AS candidate_match_pct
FROM public.nc_boe_donations_raw r
LEFT JOIN public.committee_registry cr ON cr.sboe_id = r.committee_sboe_id
LEFT JOIN staging.committee_candidate_bridge b ON b.committee_sboe_id = r.committee_sboe_id
WHERE r.transaction_type = 'Individual'
  AND r.amount_numeric > 0
  AND r.date_occurred >= '2015-01-01'
  AND r.date_occurred <= '2026-12-31';

-- Report results and stop. No production writes.
