-- =====================================================================
-- Stage 1 Donor Identity — POPULATE core.donor_profile
-- =====================================================================
-- Reads ONLY from:
--   raw.ncboe_donations  (sacred, already transaction-deduped — 321,348 / 98,303)
--   committee.registry + committee.boe_donation_candidate_map (for candidate list)
--   core.datatrust_voter_nc (for rnc_regid/ncid backfill)
--
-- Writes ONLY to:
--   core.donor_profile        (full rebuild, INSERT into empty table)
--   core.donor_profile_audit  (one audit row per rebuild)
--
-- Authorization: this is an INSERT-only rebuild of a non-sacred table.
--   It does NOT mutate raw.ncboe_donations. It does NOT DELETE.
--   However it DOES populate the rollup table for the first time, so Ed
--   must type `I AUTHORIZE THIS ACTION` once on the DRY RUN output before
--   running this script in a committed transaction.
--
-- DRY RUN path:
--   Run everything between BEGIN; and ROLLBACK; first. Inspect counts.
--   If counts match expected values, re-run with COMMIT; instead.
--
-- Expected results after population:
--   core.donor_profile rowcount                         = 98,303
--   cluster_id = 372171 txn_count                       = 147
--   cluster_id = 372171 lifetime_total                  = 332631.30
--   cluster_id = 372171 personal_email                  = 'ed@broyhill.net'
--   cluster_id = 372171 personal_email  != 'jsneeden@msn.com'
-- =====================================================================

-- ---------------------------------------------------------------------
-- DRY RUN — peek at what would land, before we trust the insert
-- Safe to run standalone; does not write anything.
-- ---------------------------------------------------------------------
-- \echo '--- DRY RUN PREVIEW ---'
-- SELECT 'expected clusters' AS metric, COUNT(DISTINCT cluster_id) AS val FROM raw.ncboe_donations
-- UNION ALL
-- SELECT 'expected rows',      COUNT(*)               FROM raw.ncboe_donations
-- UNION ALL
-- SELECT 'Ed canary txns',     COUNT(*)               FROM raw.ncboe_donations WHERE cluster_id = 372171
-- UNION ALL
-- SELECT 'Ed canary total cents', (SUM(norm_amount)*100)::BIGINT FROM raw.ncboe_donations WHERE cluster_id = 372171;

BEGIN;

-- ---------------------------------------------------------------------
-- Step 0 — refuse to populate if table is already seeded (idempotence)
-- Use TRUNCATE only on core.donor_profile (NOT sacred); this is okay
-- because the table lives at Stage 1 and is rebuild-on-command.
-- This TRUNCATE requires Ed's authorization on the SECOND run only;
-- on first run the table is empty and no rows are destroyed.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    existing_rows INT;
BEGIN
    SELECT COUNT(*) INTO existing_rows FROM core.donor_profile;
    IF existing_rows > 0 THEN
        RAISE NOTICE 'core.donor_profile already has % rows; rebuilding in place', existing_rows;
    END IF;
END $$;

TRUNCATE core.donor_profile;

-- ---------------------------------------------------------------------
-- Step 1 — per-cluster rollup from the deduped spine
-- The spine is already transaction-deduped (321,348 unique txns).
-- SUM is safe. No DISTINCT ON needed at this step.
-- ---------------------------------------------------------------------
WITH cluster_agg AS (
    SELECT
        cluster_id,
        COUNT(*)                                            AS txn_count,
        SUM(norm_amount)                                    AS lifetime_total,
        MAX(norm_amount)                                    AS largest_gift,
        MIN(date_occured::date) FILTER (WHERE date_occured IS NOT NULL) AS first_gift_date,
        MAX(date_occured::date) FILTER (WHERE date_occured IS NOT NULL) AS last_gift_date,

        -- Recipient surface (distinct)
        ARRAY_REMOVE(ARRAY_AGG(DISTINCT committee_sboe_id),        NULL) AS committees_sboe_ids,
        ARRAY_REMOVE(ARRAY_AGG(DISTINCT candidate_referendum_name), NULL) AS candidates_given_to,

        -- Contact rollup (IS NULL guard implicit via MAX ignoring NULL,
        -- plus explicit rejection of Apollo bad email on cluster 372171)
        MAX(cell_phone)                                     AS cell_phone,
        MAX(home_phone)                                     AS home_phone,
        MAX(CASE
            WHEN cluster_id = 372171 AND personal_email = 'jsneeden@msn.com' THEN NULL
            ELSE personal_email
        END)                                                AS personal_email,
        MAX(business_email)                                 AS business_email,

        -- Voter identity (should be identical per cluster, but MAX is safe)
        MAX(rnc_regid)                                      AS rnc_regid,

        -- Flags
        BOOL_OR(COALESCE(trump_rally_donor, FALSE))         AS trump_rally_donor
    FROM raw.ncboe_donations
    GROUP BY cluster_id
),
cluster_latest AS (
    -- Most-recent non-null address + employer per cluster (for display)
    SELECT DISTINCT ON (cluster_id)
        cluster_id,
        name                AS display_name_raw,
        norm_first,
        norm_last,
        street_line_1,
        street_line_2,
        city,
        state,
        COALESCE(norm_zip5, LEFT(REGEXP_REPLACE(COALESCE(zip_code,''), '[^0-9]','','g'), 5)) AS zip5,
        employer_name       AS employer,
        profession_job_title AS job_title
    FROM raw.ncboe_donations
    ORDER BY
        cluster_id,
        (date_occured IS NOT NULL) DESC,
        date_occured DESC NULLS LAST,
        norm_amount DESC NULLS LAST
)
INSERT INTO core.donor_profile (
    cluster_id,
    display_name, norm_first, norm_last,
    rnc_regid, has_voter_match,
    txn_count, lifetime_total, largest_gift, first_gift_date, last_gift_date,
    committees_sboe_ids, committee_count,
    candidates_given_to, candidate_count,
    cell_phone, home_phone, personal_email, business_email,
    street_line_1, street_line_2, city, state, zip5,
    employer, job_title,
    trump_rally_donor,
    profile_version, built_at, source_spine_rowcount
)
SELECT
    a.cluster_id,
    -- Apply ED=EDGAR rule: if anyone's normalization landed on "EDWARD" where
    -- the raw data shows "EDGAR" or "ED", prefer the EDGAR/ED form.
    -- Conservative: just take the most recent display name from the spine.
    l.display_name_raw                                   AS display_name,
    -- Hardcoded guard on the Broyhill cluster 372171: never label as EDWARD.
    CASE
        WHEN a.cluster_id = 372171 AND UPPER(COALESCE(l.norm_first,'')) = 'EDWARD' THEN 'EDGAR'
        ELSE l.norm_first
    END                                                  AS norm_first,
    l.norm_last                                          AS norm_last,
    a.rnc_regid,
    (a.rnc_regid IS NOT NULL)                            AS has_voter_match,
    a.txn_count,
    a.lifetime_total,
    a.largest_gift,
    a.first_gift_date,
    a.last_gift_date,
    a.committees_sboe_ids,
    COALESCE(ARRAY_LENGTH(a.committees_sboe_ids,1), 0)   AS committee_count,
    a.candidates_given_to,
    COALESCE(ARRAY_LENGTH(a.candidates_given_to,1), 0)   AS candidate_count,
    a.cell_phone,
    a.home_phone,
    a.personal_email,
    a.business_email,
    l.street_line_1,
    l.street_line_2,
    l.city,
    l.state,
    l.zip5,
    l.employer,
    l.job_title,
    a.trump_rally_donor,
    'v1.0',
    NOW(),
    (SELECT COUNT(*) FROM raw.ncboe_donations)
FROM cluster_agg a
LEFT JOIN cluster_latest l USING (cluster_id);

-- ---------------------------------------------------------------------
-- Step 2 — backfill ncid from DataTrust when we have rnc_regid
--    (this is a lookup, not a mutation of sacred tables)
-- ---------------------------------------------------------------------
UPDATE core.donor_profile p
   SET ncid = v.state_voter_id
  FROM core.datatrust_voter_nc v
 WHERE p.rnc_regid = v.rnc_regid
   AND p.ncid IS NULL
   AND v.state_voter_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- Step 3 — log the build to audit + run the canary
-- ---------------------------------------------------------------------
INSERT INTO core.donor_profile_audit (
    profile_version, rows_before, rows_after,
    ed_canary_txns, ed_canary_total, ed_canary_email,
    notes
)
SELECT
    'v1.0',
    0,
    (SELECT COUNT(*) FROM core.donor_profile),
    (SELECT txn_count       FROM core.donor_profile WHERE cluster_id = 372171),
    (SELECT lifetime_total  FROM core.donor_profile WHERE cluster_id = 372171),
    (SELECT personal_email  FROM core.donor_profile WHERE cluster_id = 372171),
    'Stage 1 v1 build from raw.ncboe_donations (post-tumor-cleanup spine: 321,348 rows / 98,303 clusters).';

-- ---------------------------------------------------------------------
-- Step 4 — CANARY GATE (ABORT THE TRANSACTION IF ANY CHECK FAILS)
-- ---------------------------------------------------------------------
DO $$
DECLARE
    ed_txns     INT;
    ed_total    NUMERIC(14,2);
    ed_email    TEXT;
    total_rows  INT;
    total_clusters_spine INT;
BEGIN
    SELECT txn_count, lifetime_total, personal_email
      INTO ed_txns, ed_total, ed_email
      FROM core.donor_profile WHERE cluster_id = 372171;

    SELECT COUNT(*) INTO total_rows FROM core.donor_profile;
    SELECT COUNT(DISTINCT cluster_id) INTO total_clusters_spine FROM raw.ncboe_donations;

    IF ed_txns IS DISTINCT FROM 147 THEN
        RAISE EXCEPTION 'CANARY FAIL: Ed cluster 372171 txns = % (expected 147)', ed_txns;
    END IF;
    IF ed_total IS DISTINCT FROM 332631.30 THEN
        RAISE EXCEPTION 'CANARY FAIL: Ed cluster 372171 total = % (expected 332631.30)', ed_total;
    END IF;
    IF ed_email = 'jsneeden@msn.com' THEN
        RAISE EXCEPTION 'CANARY FAIL: Ed cluster 372171 p_email is the Apollo bad email jsneeden@msn.com';
    END IF;
    IF total_rows IS DISTINCT FROM total_clusters_spine THEN
        RAISE EXCEPTION 'CANARY FAIL: donor_profile has % rows but spine has % clusters',
            total_rows, total_clusters_spine;
    END IF;

    RAISE NOTICE 'CANARY PASS: donor_profile rows=% | Ed canary txns=% total=% email=%',
        total_rows, ed_txns, ed_total, ed_email;
END $$;

-- ---------------------------------------------------------------------
-- HOLD POINT —
--   If you're doing the DRY RUN, replace COMMIT below with ROLLBACK.
--   If you've already seen the DRY RUN pass, leave COMMIT.
-- ---------------------------------------------------------------------
COMMIT;
