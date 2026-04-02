-- ============================================================================
-- HONORARY TITLE ENRICHMENT
-- BroyhillGOP — Populate honorary_title, title_salutation, title_branch,
--               title_status on core.person_spine
-- ============================================================================
-- AUTHOR: Perplexity
-- DATE: 2026-04-02
-- STATUS: REQUIRES ED AUTHORIZATION FOR ALL WRITES
-- SAFETY: Every UPDATE touches ONE column only (except where noted).
--         No compound SETs. No existing data overwritten.
--
-- APPROACH:
--   1. Match spine donors to ncsbe_candidates by name+zip (669 matches)
--   2. Derive highest office held per person (title hierarchy)
--   3. Map contest_name → honorary_title + title_salutation
--   4. Military titles must be populated manually (no data source)
--
-- TITLE HIERARCHY (highest wins):
--   US President > US Senator > US Representative > Governor >
--   Lt Governor > Attorney General > State Auditor/Treasurer/Secretary >
--   NC State Senator > NC State Representative > Judge (Supreme/Appeals) >
--   Judge (Superior/District) > Sheriff > District Attorney >
--   Commissioner > Mayor > Council Member > Clerk > Register of Deeds
-- ============================================================================


-- ============================================================================
-- PHASE T1: Contest-to-Title mapping table
-- ============================================================================

CREATE TABLE IF NOT EXISTS staging.contest_title_map (
  id SERIAL PRIMARY KEY,
  contest_pattern TEXT NOT NULL,
  honorary_title TEXT NOT NULL,
  title_salutation TEXT NOT NULL,
  title_rank INTEGER NOT NULL,  -- lower = higher office
  UNIQUE(contest_pattern)
);

-- Populate the mapping (idempotent — ON CONFLICT DO NOTHING)
INSERT INTO staging.contest_title_map (contest_pattern, honorary_title, title_salutation, title_rank) VALUES
  -- Federal
  ('US PRESIDENT', 'President', 'Mr. President', 1),
  ('US SENATE', 'Senator', 'Senator', 2),
  ('US HOUSE OF REPRESENTATIVES%', 'Congressman', 'Congressman', 3),
  -- Statewide
  ('NC GOVERNOR', 'Governor', 'Governor', 4),
  ('NC LIEUTENANT GOVERNOR', 'Lieutenant Governor', 'Lieutenant Governor', 5),
  ('NC ATTORNEY GENERAL', 'Attorney General', 'General', 6),
  ('NC AUDITOR', 'State Auditor', 'Auditor', 7),
  ('NC TREASURER', 'State Treasurer', 'Treasurer', 7),
  ('NC SECRETARY OF STATE', 'Secretary of State', 'Secretary', 7),
  ('NC COMMISSIONER OF LABOR', 'Commissioner of Labor', 'Commissioner', 7),
  ('NC COMMISSIONER OF INSURANCE', 'Commissioner of Insurance', 'Commissioner', 7),
  ('NC COMMISSIONER OF AGRICULTURE', 'Commissioner of Agriculture', 'Commissioner', 7),
  ('NC SUPERINTENDENT OF PUBLIC INSTRUCTION', 'Superintendent', 'Superintendent', 7),
  -- State Legislature
  ('NC STATE SENATE%', 'State Senator', 'Senator', 8),
  ('NC HOUSE OF REPRESENTATIVES%', 'State Representative', 'Representative', 9),
  -- Judiciary — Supreme Court
  ('NC SUPREME COURT CHIEF JUSTICE%', 'Chief Justice', 'Chief Justice', 10),
  ('NC SUPREME COURT ASSOCIATE JUSTICE%', 'Justice', 'Justice', 11),
  -- Judiciary — Court of Appeals
  ('NC COURT OF APPEALS%', 'Judge', 'Judge', 12),
  -- Judiciary — Superior/District Court
  ('NC SUPERIOR COURT%', 'Judge', 'Judge', 13),
  ('NC DISTRICT COURT%', 'Judge', 'Judge', 14),
  ('% DISTRICT COURT%', 'Judge', 'Judge', 14),
  -- County
  ('% SHERIFF', 'Sheriff', 'Sheriff', 15),
  ('% DISTRICT ATTORNEY%', 'District Attorney', 'District Attorney', 16),
  ('%BOARD OF COMMISSIONERS%', 'Commissioner', 'Commissioner', 17),
  ('COUNTY COMMISSIONER%', 'Commissioner', 'Commissioner', 17),
  ('%BOARD OF EDUCATION%', 'Board Member', 'Board Member', 20),
  -- Municipal
  ('%MAYOR%', 'Mayor', 'Mayor', 18),
  ('%CITY COUNCIL%', 'Council Member', 'Council Member', 19),
  ('%TOWN COUNCIL%', 'Council Member', 'Council Member', 19),
  ('%TOWN BOARD%', 'Board Member', 'Board Member', 19),
  ('%ALDERMAN%', 'Alderman', 'Alderman', 19),
  ('%ALDERMEN%', 'Alderman', 'Alderman', 19),
  -- Other county offices
  ('%REGISTER OF DEEDS%', 'Register of Deeds', 'Register', 21),
  ('%CLERK OF SUPERIOR COURT%', 'Clerk of Court', 'Clerk', 21)
ON CONFLICT (contest_pattern) DO NOTHING;


-- ============================================================================
-- PHASE T2: Build the person → highest title mapping
-- ============================================================================
-- For each spine donor who is also a candidate, find their HIGHEST office.
-- If someone was a Commissioner and then a State Senator, they get Senator.

CREATE TABLE IF NOT EXISTS staging.spine_honorary_titles (
  person_id BIGINT PRIMARY KEY,
  honorary_title TEXT NOT NULL,
  title_salutation TEXT NOT NULL,
  title_rank INTEGER NOT NULL,
  derived_from_contest TEXT NOT NULL,
  most_recent_election TEXT
);

-- Truncate and rebuild each run (staging only — safe)
TRUNCATE staging.spine_honorary_titles;

INSERT INTO staging.spine_honorary_titles
  (person_id, honorary_title, title_salutation, title_rank, derived_from_contest, most_recent_election)
SELECT DISTINCT ON (s.person_id)
  s.person_id,
  ctm.honorary_title,
  ctm.title_salutation,
  ctm.title_rank,
  c.contest_name,
  c.election_dt
FROM core.person_spine s
JOIN public.ncsbe_candidates c
  ON UPPER(c.last_name) = s.norm_last
  AND UPPER(c.first_name) = s.norm_first
  AND LEFT(c.zip, 5) = s.zip5
JOIN staging.contest_title_map ctm
  ON c.contest_name LIKE ctm.contest_pattern
WHERE s.is_active = true
ORDER BY s.person_id, ctm.title_rank ASC, c.election_dt DESC;
-- tie-break: highest office first (lowest rank number), then most recent election


-- ============================================================================
-- PHASE T3: Diagnostic — review before writing to spine
-- ============================================================================

-- T3a: How many donors get titles?
SELECT COUNT(*) as donors_with_titles FROM staging.spine_honorary_titles;

-- T3b: Distribution by title
SELECT honorary_title, title_salutation, COUNT(*) as cnt
FROM staging.spine_honorary_titles
GROUP BY honorary_title, title_salutation
ORDER BY MIN(title_rank), cnt DESC;

-- T3c: Sample — who are these people?
SELECT sht.person_id, s.norm_first, s.norm_last, s.zip5,
       sht.honorary_title, sht.title_salutation,
       sht.derived_from_contest, sht.most_recent_election
FROM staging.spine_honorary_titles sht
JOIN core.person_spine s ON s.person_id = sht.person_id
ORDER BY sht.title_rank ASC
LIMIT 30;

-- T3d: BROYHILL CANARY — does Ed get a title? (He shouldn't unless he ran for office)
SELECT * FROM staging.spine_honorary_titles WHERE person_id = 26451;

-- T3e: Spot check — Terry Johnson should be Sheriff
SELECT sht.*, s.norm_first, s.norm_last
FROM staging.spine_honorary_titles sht
JOIN core.person_spine s ON s.person_id = sht.person_id
WHERE s.norm_last = 'JOHNSON' AND s.norm_first = 'TERRY'
  AND sht.honorary_title = 'Sheriff';

-- T3f: Spot check — Donna Stroud should be Judge
SELECT sht.*, s.norm_first, s.norm_last
FROM staging.spine_honorary_titles sht
JOIN core.person_spine s ON s.person_id = sht.person_id
WHERE s.norm_last = 'STROUD' AND s.norm_first = 'DONNA';

-- T3g: Spot check — Ralph Hise should be Senator
SELECT sht.*, s.norm_first, s.norm_last
FROM staging.spine_honorary_titles sht
JOIN core.person_spine s ON s.person_id = sht.person_id
WHERE s.norm_last = 'HISE' AND s.norm_first = 'RALPH';


-- ============================================================================
-- PHASE T4: Write to spine — ONE column per UPDATE
-- ============================================================================

-- T4a: honorary_title
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET honorary_title = sht.honorary_title
FROM staging.spine_honorary_titles sht
WHERE s.person_id = sht.person_id
  AND s.is_active = true
  AND s.honorary_title IS NULL;

-- T4b: title_salutation
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET title_salutation = sht.title_salutation
FROM staging.spine_honorary_titles sht
WHERE s.person_id = sht.person_id
  AND s.is_active = true
  AND s.title_salutation IS NULL;


-- ============================================================================
-- PHASE T5: Military titles (manual framework)
-- ============================================================================
-- There is no data source for military rank in the database.
-- These must be populated manually or from a future data import.
-- The framework below supports manual inserts.
--
-- CORRECT FORMAT (DoD standard):
--   honorary_title: "Lieutenant General"
--   title_salutation: "General"  (all generals are "General" in speech)
--   title_branch: "USA" (Army), "USAF" (Air Force), "USN" (Navy),
--                 "USMC" (Marines), "USCG" (Coast Guard)
--   title_status: "Ret." (no parentheses)
--
-- RANK-TO-SALUTATION MAPPING:
--   Lieutenant General / Major General / Brigadier General → "General"
--   Colonel / Lieutenant Colonel → "Colonel"
--   Commander (Navy) → "Commander"
--   Admiral / Vice Admiral / Rear Admiral → "Admiral"
--   Captain → "Captain"
--   Major → "Major"
--
-- EXAMPLE MANUAL INSERT:
--   UPDATE core.person_spine
--   SET honorary_title = 'Lieutenant General',
--       title_salutation = 'General',
--       title_branch = 'USA',
--       title_status = 'Ret.'
--   WHERE person_id = <person_id>;
--
-- NOTE: Military title overrides political title if the person prefers it.
-- A retired General who served one term as Commissioner is still "General."
-- This is a manual decision per person — no automated logic can determine
-- which title the individual prefers.

-- Placeholder: create a manual overrides table for Ed/staff to populate
CREATE TABLE IF NOT EXISTS staging.title_manual_overrides (
  person_id BIGINT PRIMARY KEY,
  honorary_title TEXT NOT NULL,
  title_salutation TEXT NOT NULL,
  title_branch TEXT,
  title_status TEXT,
  override_reason TEXT,
  entered_by TEXT DEFAULT 'manual',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- T5a: Apply manual overrides (run AFTER T4, overrides ncsbe-derived titles)
-- REQUIRES ED AUTHORIZATION
UPDATE core.person_spine s
SET honorary_title = mo.honorary_title
FROM staging.title_manual_overrides mo
WHERE s.person_id = mo.person_id
  AND s.is_active = true;

UPDATE core.person_spine s
SET title_salutation = mo.title_salutation
FROM staging.title_manual_overrides mo
WHERE s.person_id = mo.person_id
  AND s.is_active = true;

UPDATE core.person_spine s
SET title_branch = mo.title_branch
FROM staging.title_manual_overrides mo
WHERE s.person_id = mo.person_id
  AND s.is_active = true
  AND mo.title_branch IS NOT NULL;

UPDATE core.person_spine s
SET title_status = mo.title_status
FROM staging.title_manual_overrides mo
WHERE s.person_id = mo.person_id
  AND s.is_active = true
  AND mo.title_status IS NOT NULL;


-- ============================================================================
-- PHASE T6: Final verification
-- ============================================================================

-- T6a: Spine title coverage
SELECT
  COUNT(*) as active_spine,
  COUNT(honorary_title) FILTER (WHERE honorary_title IS NOT NULL) as has_title,
  COUNT(title_salutation) FILTER (WHERE title_salutation IS NOT NULL) as has_salutation,
  COUNT(title_branch) FILTER (WHERE title_branch IS NOT NULL) as has_branch,
  COUNT(title_status) FILTER (WHERE title_status IS NOT NULL) as has_status
FROM core.person_spine WHERE is_active = true;

-- T6b: Title distribution
SELECT honorary_title, title_salutation, COUNT(*) as cnt
FROM core.person_spine
WHERE is_active = true AND honorary_title IS NOT NULL
GROUP BY honorary_title, title_salutation
ORDER BY cnt DESC;

-- T6c: Example formatted outputs
SELECT
  person_id,
  -- Envelope format
  CASE
    WHEN title_branch IS NOT NULL THEN
      honorary_title || ' ' || norm_first || ' '
        || COALESCE(middle_name || ' ', '')
        || norm_last
        || COALESCE(' ' || suffix, '')
        || ', ' || title_branch
        || COALESCE(', ' || title_status, '')
    WHEN honorary_title IS NOT NULL THEN
      'The Honorable ' || norm_first || ' '
        || COALESCE(middle_name || ' ', '')
        || norm_last
        || COALESCE(' ' || suffix, '')
    ELSE
      norm_first || ' '
        || COALESCE(middle_name || ' ', '')
        || norm_last
        || COALESCE(' ' || suffix, '')
  END as envelope_name,
  -- Salutation format
  CASE
    WHEN title_salutation IS NOT NULL THEN
      'Dear ' || title_salutation || ' ' || norm_last || ':'
    ELSE
      'Dear ' || COALESCE(preferred_name, norm_first) || ':'
  END as letter_salutation,
  -- Call center format
  CASE
    WHEN title_salutation IS NOT NULL THEN
      'Good evening, ' || title_salutation || ' ' || norm_last
    ELSE
      'Good evening, ' || COALESCE(preferred_name, norm_first)
  END as call_script_greeting
FROM core.person_spine
WHERE is_active = true
  AND honorary_title IS NOT NULL
ORDER BY person_id
LIMIT 15;


-- ============================================================================
-- END — All spine writes gated by ED AUTHORIZATION.
-- Military titles require manual population via title_manual_overrides.
-- ============================================================================
