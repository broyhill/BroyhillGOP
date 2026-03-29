-- =============================================================================
-- FIX 10: Republican-only contribution filter & spine recompute
-- Project: BroyhillGOP-Claude | isbgjpnbocdkeslofota
-- Date: 2026-03-29
-- Prepared by: Perplexity Computer
-- Reviewed by: Claude Anthropic (staging.committee_party_map_v2)
-- =============================================================================
-- DESIGN INTENT (per Ed Broyhill 2026-03-28):
--   - One row per human who has ever donated to a Republican candidate/committee
--   - Donor's own party registration is irrelevant — welcome regardless
--   - Filter is on the RECEIVING committee, not the donor
--   - Democratic committee donations → set aside, NOT deleted
--   - UNKNOWN committee donations → set aside, NOT deleted  
--   - PAC donations → included (supporting Republican candidates)
--   - No donor is removed from the spine — all are preserved
--   - total_contributed = Republican + PAC money only
--   - total_contributed_other = D + UNKNOWN + OTHER (new column, tracked separately)
-- =============================================================================
-- DO NOT RUN AS A SINGLE BATCH.
-- Run each step, validate, paste results to Ed before proceeding.
-- Sacred tables: nc_voters, nc_datatrust, rnc_voter_staging, person_source_links
-- Destructive steps require: "I authorize this action" from Ed
-- =============================================================================

-- -----------------------------------------------------------------------
-- DIAGNOSTIC — Run first, verify all numbers before touching anything
-- -----------------------------------------------------------------------

-- 1. Verify staging.committee_party_map_v2 is ready
SELECT party_flag, COUNT(*) AS committees
FROM staging.committee_party_map_v2
GROUP BY party_flag ORDER BY COUNT(*) DESC;
-- Expected: R=8201, D=6829, OTHER=2712, UNKNOWN=2217, PAC=23

-- 2. Dollar breakdown by party in contribution_map (using v2)
SELECT
    COALESCE(cpm.party_flag, 'UNCLASSIFIED') AS party,
    COUNT(*) AS transactions,
    ROUND(SUM(cm.amount)::numeric, 0) AS total_dollars
FROM core.contribution_map cm
LEFT JOIN staging.committee_party_map_v2 cpm ON cm.committee_id = cpm.committee_id
GROUP BY 1 ORDER BY total_dollars DESC;

-- 3. Current spine totals (before any changes)
SELECT
    COUNT(*) AS total_spine_rows,
    COUNT(total_contributed) AS has_total,
    ROUND(SUM(total_contributed)::numeric, 0) AS current_grand_total,
    MAX(total_contributed) AS max_single_donor
FROM core.person_spine;

-- 4. Snapshot tables exist?
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_name IN ('core_contribution_map_pre_fix','core_person_spine_pre_fix')
ORDER BY table_name;
-- Expected: both exist in audit schema (Claude created these)

-- -----------------------------------------------------------------------
-- STEP 1: Swap committee_party_map (staging v2 → production)
-- Safe: additive classification improvement, no data deleted
-- -----------------------------------------------------------------------

-- Pre-flight: confirm v2 has more R than current production
SELECT
    (SELECT COUNT(*) FROM staging.committee_party_map_v2 WHERE party_flag='R') AS v2_R,
    (SELECT COUNT(*) FROM committee_party_map WHERE party_flag='R') AS prod_R;
-- Expected: v2_R=8201, prod_R=2093 — v2 is 4x better

BEGIN;

-- Archive current production table
ALTER TABLE public.committee_party_map RENAME TO committee_party_map_old;

-- Promote v2 to production
ALTER TABLE staging.committee_party_map_v2 SET SCHEMA public;
ALTER TABLE public.committee_party_map_v2 RENAME TO committee_party_map;

-- Validate
SELECT party_flag, COUNT(*) FROM committee_party_map
GROUP BY party_flag ORDER BY COUNT(*) DESC;
-- Expected: R=8201, D=6829, OTHER=2712, UNKNOWN=2217, PAC=23

COMMIT;
-- ROLLBACK; -- if anything looks wrong

-- -----------------------------------------------------------------------
-- STEP 2: Add party_flag column to core.contribution_map
-- Non-destructive — additive column only
-- -----------------------------------------------------------------------

ALTER TABLE core.contribution_map
    ADD COLUMN IF NOT EXISTS party_flag TEXT;

COMMENT ON COLUMN core.contribution_map.party_flag IS
    'Party classification of the receiving committee. '
    'R=Republican, D=Democrat, PAC=PAC, OTHER=third party, UNKNOWN=unclassified. '
    'Populated by fix_10 (2026-03-29). NULL = not yet stamped.';

-- Verify column added
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='core' AND table_name='contribution_map'
AND column_name='party_flag';

-- -----------------------------------------------------------------------
-- STEP 3: Stamp party_flag on all contribution_map rows
-- ~4.1M rows — run with statement_timeout = 0
-- Rerun-safe: WHERE party_flag IS NULL
-- -----------------------------------------------------------------------

SET statement_timeout = 0;

UPDATE core.contribution_map cm
SET party_flag = COALESCE(cpm.party_flag, 'UNKNOWN')
FROM staging.committee_party_map_v2 cpm  -- use v2 directly in case Step 1 swap hasn't run
WHERE cm.committee_id = cpm.committee_id
  AND cm.party_flag IS NULL;

-- Stamp remaining unmatched rows as UNKNOWN
UPDATE core.contribution_map
SET party_flag = 'UNKNOWN'
WHERE party_flag IS NULL;

-- Validation
SELECT party_flag, COUNT(*) AS rows, ROUND(SUM(amount)::numeric,0) AS dollars
FROM core.contribution_map
GROUP BY party_flag ORDER BY dollars DESC;
-- Expected: R rows dominant, D and UNKNOWN visible but separate

SELECT COUNT(*) AS still_null FROM core.contribution_map WHERE party_flag IS NULL;
-- Expected: 0

-- -----------------------------------------------------------------------
-- STEP 4: Add total_contributed_other to person_spine
-- Tracks D+UNKNOWN+OTHER money separately — never lost, just not in R total
-- -----------------------------------------------------------------------

ALTER TABLE core.person_spine
    ADD COLUMN IF NOT EXISTS total_contributed_republican NUMERIC DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_contributed_other      NUMERIC DEFAULT 0,
    ADD COLUMN IF NOT EXISTS contribution_count_republican INTEGER DEFAULT 0;

COMMENT ON COLUMN core.person_spine.total_contributed_republican IS
    'Sum of donations to Republican + PAC committees only. '
    'The authoritative fundraising total for this platform. fix_10 (2026-03-29).';

COMMENT ON COLUMN core.person_spine.total_contributed_other IS
    'Sum of donations to D + UNKNOWN + OTHER committees. '
    'Tracked but excluded from Republican totals. fix_10 (2026-03-29).';

COMMENT ON COLUMN core.person_spine.contribution_count_republican IS
    'Count of Republican + PAC contributions only. fix_10 (2026-03-29).';

-- -----------------------------------------------------------------------
-- STEP 5: Recompute spine totals — Republican-only
-- STOP HERE — requires "I authorize this action" from Ed before executing
-- -----------------------------------------------------------------------
-- This UPDATE overwrites total_contributed with Republican-only money.
-- The old total_contributed values are preserved in audit.core_person_spine_pre_fix.
-- Rollback: restore from audit.core_person_spine_pre_fix (see rollback section)

-- *** DO NOT RUN UNTIL ED SAYS: I authorize this action ***

BEGIN;

-- Republican + PAC total (new primary total)
UPDATE core.person_spine ps
SET
    total_contributed_republican = COALESCE(agg.rep_total, 0),
    contribution_count_republican = COALESCE(agg.rep_count, 0),
    total_contributed_other = COALESCE(agg.other_total, 0),
    -- Overwrite total_contributed with Republican-only money
    total_contributed = COALESCE(agg.rep_total, 0),
    contribution_count = COALESCE(agg.rep_count, 0),
    first_contribution = agg.rep_first,
    last_contribution = agg.rep_last
FROM (
    SELECT
        person_id,
        SUM(CASE WHEN party_flag IN ('R','PAC') THEN amount ELSE 0 END) AS rep_total,
        COUNT(CASE WHEN party_flag IN ('R','PAC') THEN 1 END) AS rep_count,
        MIN(CASE WHEN party_flag IN ('R','PAC') THEN transaction_date END) AS rep_first,
        MAX(CASE WHEN party_flag IN ('R','PAC') THEN transaction_date END) AS rep_last,
        SUM(CASE WHEN party_flag NOT IN ('R','PAC') THEN amount ELSE 0 END) AS other_total
    FROM core.contribution_map
    GROUP BY person_id
) agg
WHERE ps.person_id = agg.person_id;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- STEP 6: Final validation
-- -----------------------------------------------------------------------

-- Grand totals after recompute
SELECT
    COUNT(*) AS spine_rows,
    COUNT(CASE WHEN total_contributed > 0 THEN 1 END) AS active_republican_donors,
    ROUND(SUM(total_contributed)::numeric, 0) AS total_republican_dollars,
    ROUND(SUM(total_contributed_other)::numeric, 0) AS total_other_dollars,
    MAX(total_contributed) AS max_single_donor_republican
FROM core.person_spine;

-- Top 10 donors after fix (should be real people, not committees)
SELECT person_id, last_name, first_name, total_contributed, total_contributed_other,
       contribution_count_republican
FROM core.person_spine
ORDER BY total_contributed DESC
LIMIT 10;

-- Verify no org names slipped through
SELECT last_name, COUNT(*) FROM core.person_spine
WHERE last_name ILIKE ANY(ARRAY['%COMMITTEE%','%FUND%','%PAC%','%PARTY%','%CAUCUS%','%CORP%'])
GROUP BY last_name ORDER BY COUNT(*) DESC;
-- Expected: 0 rows

-- Confirm Republican total < previous total (Democratic money removed)
SELECT
    (SELECT ROUND(SUM(total_contributed)::numeric,0) FROM core.person_spine) AS new_republican_total,
    (SELECT ROUND(SUM(total_contributed)::numeric,0) FROM audit.core_person_spine_pre_fix) AS old_contaminated_total;

-- -----------------------------------------------------------------------
-- ROLLBACK (if Step 5 results look wrong)
-- -----------------------------------------------------------------------
-- BEGIN;
-- UPDATE core.person_spine ps
-- SET
--     total_contributed = pre.total_contributed,
--     contribution_count = pre.contribution_count,
--     first_contribution = pre.first_contribution,
--     last_contribution = pre.last_contribution
-- FROM audit.core_person_spine_pre_fix pre
-- WHERE ps.person_id = pre.person_id;
-- COMMIT;
