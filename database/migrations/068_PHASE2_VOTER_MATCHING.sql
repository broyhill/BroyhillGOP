-- 068_PHASE2_VOTER_MATCHING.sql
-- Identity Resolution Phase 2: Voter-match the unlinked ~143K spine records
-- Also creates spine records for General Fund donors
-- PREREQUISITE: 065 (nc_voters indexes MUST exist), 066+067 (spine deduped)
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 0: Baseline
-- =============================================================================
SELECT 'BEFORE voter matching' AS label,
  count(*) AS active_spine,
  count(voter_ncid) AS with_ncid,
  round(100.0 * count(voter_ncid) / count(*), 1) AS pct
FROM core.person_spine WHERE is_active = true;

-- =============================================================================
-- STEP 1: PASS 1 — Exact last + first + zip5 (confidence 0.95)
-- Only match to active voters, prefer exact matches
-- =============================================================================
UPDATE core.person_spine s SET
  voter_ncid = sub.ncid,
  is_registered_voter = true,
  voter_status = sub.status_cd,
  voter_party = sub.party_cd,
  voter_county = sub.county_desc,
  updated_at = NOW()
FROM (
  SELECT DISTINCT ON (sp.person_id)
    sp.person_id,
    v.ncid,
    v.status_cd,
    v.party_cd,
    v.county_desc
  FROM core.person_spine sp
  JOIN nc_voters v
    ON UPPER(v.last_name) = sp.norm_last
    AND UPPER(v.first_name) = sp.norm_first
    AND v.zip_code = sp.zip5
  WHERE sp.voter_ncid IS NULL
    AND sp.is_active = true
    AND sp.zip5 IS NOT NULL
    AND v.status_cd = 'A'
  ORDER BY sp.person_id, v.ncid
) sub
WHERE s.person_id = sub.person_id;

SELECT 'After Pass 1 (exact name+zip)' AS label,
  count(voter_ncid) AS with_ncid,
  round(100.0 * count(voter_ncid) / count(*), 1) AS pct
FROM core.person_spine WHERE is_active = true;

-- =============================================================================
-- STEP 2: PASS 2 — Canonical first + last + zip5 (confidence 0.85)
-- Uses fn_normalize_donor_name to resolve nicknames: ART→ARTHUR, BILL→WILLIAM
-- =============================================================================

-- First, build a temp mapping of voter canonical names
DROP TABLE IF EXISTS staging.voter_canonical;
CREATE TABLE staging.voter_canonical AS
SELECT 
  ncid,
  UPPER(last_name) AS norm_last,
  UPPER(first_name) AS norm_first,
  (fn_normalize_donor_name(first_name || ' ' || last_name)).canonical_first_name AS canonical_first,
  zip_code,
  status_cd,
  party_cd,
  county_desc
FROM nc_voters
WHERE status_cd = 'A'
  AND last_name IS NOT NULL
  AND first_name IS NOT NULL;

CREATE INDEX idx_vc_last_canon_zip ON staging.voter_canonical(norm_last, canonical_first, zip_code);

-- Now match spine records using canonical_first
UPDATE core.person_spine s SET
  voter_ncid = sub.ncid,
  is_registered_voter = true,
  voter_status = sub.status_cd,
  voter_party = sub.party_cd,
  voter_county = sub.county_desc,
  updated_at = NOW()
FROM (
  SELECT DISTINCT ON (sp.person_id)
    sp.person_id,
    vc.ncid,
    vc.status_cd,
    vc.party_cd,
    vc.county_desc
  FROM core.person_spine sp
  JOIN staging.spine_canonical sc ON sp.person_id = sc.person_id
  JOIN staging.voter_canonical vc
    ON vc.norm_last = sp.norm_last
    AND vc.canonical_first = sc.canonical_first
    AND vc.zip_code = sp.zip5
  WHERE sp.voter_ncid IS NULL
    AND sp.is_active = true
    AND sp.zip5 IS NOT NULL
    AND sc.canonical_first IS NOT NULL
    AND sc.canonical_first != ''
  ORDER BY sp.person_id, vc.ncid
) sub
WHERE s.person_id = sub.person_id;

SELECT 'After Pass 2 (canonical+zip)' AS label,
  count(voter_ncid) AS with_ncid,
  round(100.0 * count(voter_ncid) / count(*), 1) AS pct
FROM core.person_spine WHERE is_active = true;

-- =============================================================================
-- STEP 3: PASS 3 — Last + first initial + zip5 + party=REP (confidence 0.70)
-- More aggressive, only for Republican voters to reduce false positives
-- =============================================================================
UPDATE core.person_spine s SET
  voter_ncid = sub.ncid,
  is_registered_voter = true,
  voter_status = sub.status_cd,
  voter_party = sub.party_cd,
  voter_county = sub.county_desc,
  updated_at = NOW()
FROM (
  SELECT DISTINCT ON (sp.person_id)
    sp.person_id,
    v.ncid,
    v.status_cd,
    v.party_cd,
    v.county_desc
  FROM core.person_spine sp
  JOIN nc_voters v
    ON UPPER(v.last_name) = sp.norm_last
    AND LEFT(UPPER(v.first_name), 1) = LEFT(sp.norm_first, 1)
    AND v.zip_code = sp.zip5
    AND v.party_cd = 'REP'
  WHERE sp.voter_ncid IS NULL
    AND sp.is_active = true
    AND sp.zip5 IS NOT NULL
    AND v.status_cd = 'A'
    -- Avoid ambiguous matches: only if there's exactly 1 REP voter with this initial
    AND (SELECT count(*) FROM nc_voters v2 
         WHERE UPPER(v2.last_name) = sp.norm_last 
         AND LEFT(UPPER(v2.first_name), 1) = LEFT(sp.norm_first, 1)
         AND v2.zip_code = sp.zip5 AND v2.party_cd = 'REP' AND v2.status_cd = 'A') = 1
  ORDER BY sp.person_id, v.ncid
) sub
WHERE s.person_id = sub.person_id;

SELECT 'After Pass 3 (initial+zip+REP)' AS label,
  count(voter_ncid) AS with_ncid,
  round(100.0 * count(voter_ncid) / count(*), 1) AS pct
FROM core.person_spine WHERE is_active = true;

-- =============================================================================
-- STEP 4: Backfill voter_rncid from person_master for newly matched
-- =============================================================================
UPDATE core.person_spine s SET
  voter_rncid = pm.datatrust_rncid
FROM person_master pm
WHERE s.voter_ncid = pm.ncvoter_ncid
  AND s.voter_rncid IS NULL
  AND s.voter_ncid IS NOT NULL
  AND s.is_active = true;

-- =============================================================================
-- STEP 5: Create spine records for General Fund donors not yet in spine
-- transaction_type = 'General' in nc_boe_donations_raw = individual persons
-- =============================================================================
INSERT INTO core.person_spine (
  last_name, first_name, norm_last, norm_first, nickname_canonical,
  city, state, zip5, employer, occupation,
  contribution_count, total_contributed, first_contribution, last_contribution,
  is_active, created_at, updated_at
)
SELECT 
  r.norm_last, r.norm_first, r.norm_last, r.norm_first, r.canonical_first,
  r.city, r.state, r.zip5, r.employer, r.occupation,
  r.txn_count, r.total_amt, r.first_dt, r.last_dt,
  true, NOW(), NOW()
FROM (
  SELECT 
    norm_last, norm_first, canonical_first,
    city, state, 
    LEFT(zip, 5) AS zip5,
    employer, occupation,
    count(*) AS txn_count,
    sum(amount_numeric) AS total_amt,
    min(date_occurred) AS first_dt,
    max(date_occurred) AS last_dt
  FROM nc_boe_donations_raw
  WHERE transaction_type = 'General'
    AND is_organization = false
    AND norm_last IS NOT NULL AND norm_last != ''
  GROUP BY norm_last, norm_first, canonical_first, city, state, LEFT(zip, 5), employer, occupation
) r
WHERE NOT EXISTS (
  SELECT 1 FROM core.person_spine sp
  WHERE sp.norm_last = r.norm_last 
    AND sp.norm_first = r.norm_first
    AND sp.zip5 = r.zip5
    AND sp.is_active = true
);

SELECT 'General Fund donors added to spine' AS label, 
  count(*) - (SELECT count(*) FROM core.person_spine WHERE is_active = true) AS new_records
FROM core.person_spine WHERE is_active = true;

-- =============================================================================
-- STEP 6: Voter-match the new General Fund spine records (run passes 1-2 again)
-- =============================================================================
-- Pass 1 for new records
UPDATE core.person_spine s SET
  voter_ncid = sub.ncid,
  is_registered_voter = true,
  voter_status = sub.status_cd,
  voter_party = sub.party_cd,
  voter_county = sub.county_desc,
  updated_at = NOW()
FROM (
  SELECT DISTINCT ON (sp.person_id)
    sp.person_id, v.ncid, v.status_cd, v.party_cd, v.county_desc
  FROM core.person_spine sp
  JOIN nc_voters v
    ON UPPER(v.last_name) = sp.norm_last
    AND UPPER(v.first_name) = sp.norm_first
    AND v.zip_code = sp.zip5
  WHERE sp.voter_ncid IS NULL AND sp.is_active = true AND sp.zip5 IS NOT NULL
    AND v.status_cd = 'A'
    AND sp.created_at > NOW() - INTERVAL '1 hour'  -- only new records
  ORDER BY sp.person_id, v.ncid
) sub
WHERE s.person_id = sub.person_id;

-- =============================================================================
-- STEP 7: Final tally
-- =============================================================================
SELECT 'FINAL after Phase 2' AS label,
  count(*) AS active_spine,
  count(voter_ncid) AS with_ncid,
  round(100.0 * count(voter_ncid) / count(*), 1) AS pct,
  count(*) - count(voter_ncid) AS still_unlinked
FROM core.person_spine WHERE is_active = true;

COMMIT;
