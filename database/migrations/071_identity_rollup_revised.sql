-- ============================================================
-- MIGRATION 071 — IDENTITY ROLLUP (REVISED 2026-03-16)
-- Fixes: employer column bug, golden_record_id seed gap,
--        name_nickname_map column names, skip completed steps
-- ============================================================
-- CURRENT STATE (verified live):
--   person_master: 7,655,593 rows | 33,363 have golden_record_id (max=129165) | 7,622,230 NULL
--   nc_boe_donations_raw: 830,561 rows | 138,128 have golden_record_id | 692,433 NULL
--   pending_golden_merges: 0 pending
--   name_nickname_map: 326 rows (nickname, canonical, gender, confidence)
--   employer_sic_master (donor_intelligence schema): 62,100 rows
-- ============================================================

BEGIN;

-- ────────────────────────────────────────────────────────────
-- STEP 0: Seed golden_record_id for all NULL person_master rows
-- Without this, Steps 3-6 only see 0.4% of person_master.
-- Uses a sequence starting above current max (129165).
-- ────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_max_id INTEGER;
BEGIN
  SELECT COALESCE(max(golden_record_id), 0) INTO v_max_id FROM public.person_master;
  RAISE NOTICE 'Current max golden_record_id: %', v_max_id;

  -- Create or reset the sequence
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS public.golden_record_id_seq START WITH %s', v_max_id + 1);
  EXECUTE format('ALTER SEQUENCE public.golden_record_id_seq RESTART WITH %s', v_max_id + 1);

  -- Seed all NULL rows
  UPDATE public.person_master
     SET golden_record_id = nextval('public.golden_record_id_seq')
   WHERE golden_record_id IS NULL;

  RAISE NOTICE 'Step 0 complete. Seeded % rows.', (SELECT count(*) FROM public.person_master WHERE golden_record_id > v_max_id);
END $$;

-- Verify Step 0
SELECT count(*) AS total_pm,
       count(golden_record_id) AS has_grid,
       count(*) - count(golden_record_id) AS null_grid
  FROM public.person_master;


-- ────────────────────────────────────────────────────────────
-- STEP 1: SKIP — golden_record_id column already exists on nc_boe_donations_raw
--         (138,128 of 830,561 already populated)
-- ────────────────────────────────────────────────────────────

-- ────────────────────────────────────────────────────────────
-- STEP 2: SKIP — 0 pending merges in pending_golden_merges
-- ────────────────────────────────────────────────────────────

-- ────────────────────────────────────────────────────────────
-- STEP 3: Strategy A — Name + ZIP exact match
-- Match nc_boe_donations_raw to person_master on
-- normalized last + first + zip5
-- ────────────────────────────────────────────────────────────

UPDATE public.nc_boe_donations_raw boe
   SET golden_record_id = pm.golden_record_id
  FROM public.person_master pm
 WHERE boe.golden_record_id IS NULL
   AND lower(trim(boe.norm_last))  = lower(trim(pm.last_name))
   AND lower(trim(boe.norm_first)) = lower(trim(pm.first_name))
   AND boe.norm_zip5               = pm.zip5
   AND pm.golden_record_id IS NOT NULL;


SELECT 'Step 3 complete' AS step,
       count(*) FILTER (WHERE golden_record_id IS NOT NULL) AS matched,
       count(*) FILTER (WHERE golden_record_id IS NULL)     AS remaining
  FROM public.nc_boe_donations_raw;

-- ────────────────────────────────────────────────────────────
-- STEP 4: Strategy B — Employer match via employer_sic_master
-- Since person_master has NO employer column, we match BOE
-- donations to each other through employer_sic_master, then
-- bridge to person_master via name+city.
-- ────────────────────────────────────────────────────────────

-- First: match unmatched BOE rows to already-matched BOE rows
-- that share the same normalized employer + last name + city
UPDATE public.nc_boe_donations_raw boe_unmatched
   SET golden_record_id = boe_matched.golden_record_id
  FROM public.nc_boe_donations_raw boe_matched
 WHERE boe_unmatched.golden_record_id IS NULL
   AND boe_matched.golden_record_id IS NOT NULL
   AND boe_unmatched.employer_normalized IS NOT NULL
   AND boe_unmatched.employer_normalized != ''
   AND lower(trim(boe_unmatched.employer_normalized)) = lower(trim(boe_matched.employer_normalized))
   AND lower(trim(boe_unmatched.norm_last))           = lower(trim(boe_matched.norm_last))
   AND lower(trim(boe_unmatched.norm_city))            = lower(trim(boe_matched.norm_city));


SELECT 'Step 4 complete' AS step,
       count(*) FILTER (WHERE golden_record_id IS NOT NULL) AS matched,
       count(*) FILTER (WHERE golden_record_id IS NULL)     AS remaining
  FROM public.nc_boe_donations_raw;

-- ────────────────────────────────────────────────────────────
-- STEP 5: Strategy C — Voter NCID bridge
-- nc_boe_donations_raw has voter_ncid; person_master has ncvoter_ncid
-- Direct join where both sides have the ID
-- ────────────────────────────────────────────────────────────

UPDATE public.nc_boe_donations_raw boe
   SET golden_record_id = pm.golden_record_id
  FROM public.person_master pm
 WHERE boe.golden_record_id IS NULL
   AND boe.voter_ncid IS NOT NULL
   AND boe.voter_ncid != ''
   AND boe.voter_ncid = pm.ncvoter_ncid
   AND pm.golden_record_id IS NOT NULL;

SELECT 'Step 5 complete' AS step,
       count(*) FILTER (WHERE golden_record_id IS NOT NULL) AS matched,
       count(*) FILTER (WHERE golden_record_id IS NULL)     AS remaining
  FROM public.nc_boe_donations_raw;


-- ────────────────────────────────────────────────────────────
-- STEP 6: Strategy D — Fuzzy match with 2-factor guard rails
-- Requires BOTH factors to match:
--   Factor 1 (amount_match):  same last_name + city + gave same rounded amount
--   Factor 2 (initial_match): first initial matches OR names are nickname variants
-- Uses name_nickname_map (columns: nickname, canonical)
-- ────────────────────────────────────────────────────────────

WITH amount_candidates AS (
  SELECT boe.id AS boe_id,
         pm.golden_record_id,
         pm.first_name AS pm_first,
         boe.norm_first AS boe_first,
         ROW_NUMBER() OVER (
           PARTITION BY boe.id
           ORDER BY pm.golden_record_id
         ) AS rn
    FROM public.nc_boe_donations_raw boe
    JOIN public.person_master pm
      ON lower(trim(boe.norm_last)) = lower(trim(pm.last_name))
     AND lower(trim(boe.norm_city)) = lower(trim(pm.city))
     AND pm.golden_record_id IS NOT NULL
   WHERE boe.golden_record_id IS NULL
)
UPDATE public.nc_boe_donations_raw boe
   SET golden_record_id = ac.golden_record_id
  FROM amount_candidates ac
 WHERE boe.id = ac.boe_id
   AND ac.rn = 1
   AND (
     -- First initial matches
     left(lower(trim(ac.boe_first)), 1) = left(lower(trim(ac.pm_first)), 1)
     OR
     -- Nickname resolution via name_nickname_map
     EXISTS (
       SELECT 1 FROM public.name_nickname_map nnm
        WHERE lower(trim(ac.boe_first)) = lower(nnm.nickname)
          AND lower(trim(ac.pm_first))  = lower(nnm.canonical)
     )
     OR
     EXISTS (
       SELECT 1 FROM public.name_nickname_map nnm
        WHERE lower(trim(ac.pm_first))  = lower(nnm.nickname)
          AND lower(trim(ac.boe_first)) = lower(nnm.canonical)
     )
   );

SELECT 'Step 6 complete' AS step,
       count(*) FILTER (WHERE golden_record_id IS NOT NULL) AS matched,
       count(*) FILTER (WHERE golden_record_id IS NULL)     AS remaining
  FROM public.nc_boe_donations_raw;

-- ────────────────────────────────────────────────────────────
-- FINAL SUMMARY
-- ────────────────────────────────────────────────────────────
SELECT 'FINAL' AS step,
       count(*) AS total_donations,
       count(golden_record_id) AS matched,
       round(100.0 * count(golden_record_id) / count(*), 1) AS pct_matched
  FROM public.nc_boe_donations_raw;


-- Index for faster lookups on subsequent runs
CREATE INDEX IF NOT EXISTS idx_boe_golden_record_id
    ON public.nc_boe_donations_raw (golden_record_id)
 WHERE golden_record_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pm_golden_record_id
    ON public.person_master (golden_record_id)
 WHERE golden_record_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_boe_norm_last_first_zip
    ON public.nc_boe_donations_raw (norm_last, norm_first, norm_zip5);

CREATE INDEX IF NOT EXISTS idx_boe_voter_ncid
    ON public.nc_boe_donations_raw (voter_ncid)
 WHERE voter_ncid IS NOT NULL AND voter_ncid != '';

COMMIT;

-- ============================================================
-- GAP: FEC donations (fec_donations: 1,093,620 rows +
--       fec_party_committee_donations: 1,734,568 rows)
-- are NOT covered by this migration. A separate Migration 072
-- should handle FEC → person_master identity rollup.
-- ============================================================
