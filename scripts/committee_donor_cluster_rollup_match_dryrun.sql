-- =============================================================================
-- Committee Donor Cluster Rollup → DataTrust Match (read-only dry-run)
-- =============================================================================
-- Purpose: Layer 2 (rollup view) + Layer 3 (cluster-level match proposals).
-- Replaces the deprecated row/proposal CSV path.
-- READ-ONLY. No INSERT/UPDATE/DELETE/DDL except CREATE OR REPLACE VIEW.
-- =============================================================================
-- AUTHORIZATION:
--   This file does NOT perform Phase B apply. No rnc_regid_v2 / state_voter_id_v2
--   writes happen here. Match proposals are SELECTed for review only.
--   Apply requires Ed's exact phrase per the Phase C protocol shape.
-- =============================================================================
-- SCHEMA VERIFICATION REQUIRED before first run:
--   \d staging.ncboe_party_committee_donations
--   \d core.datatrust_voter_nc
--   Reconcile any column-name drift (e.g. norm_first vs norm_name_first)
--   before executing.
-- =============================================================================

SET statement_timeout = 0;
SET lock_timeout      = '5s';
BEGIN READ ONLY;


-- ============================================================================
-- Pre-flight (read-only). Stop if any of these fail expected values.
-- ============================================================================
-- 1. spine integrity
SELECT  COUNT(*)                          AS spine_rows,           -- expect 321,348
        COUNT(DISTINCT cluster_id)        AS spine_clusters        -- expect 98,303
FROM    raw.ncboe_donations;

-- 2. spine canary cluster 372171
SELECT  cluster_id,
        COUNT(*)                          AS txns,                 -- expect 147
        SUM(norm_amount)                  AS total,                -- expect 332631.30
        MAX(rnc_regid)                    AS rnc,                  -- expect c45eeea9-663f-40e1-b0e7-a473baee794e
        MAX(personal_email)               AS p_email               -- expect ed@broyhill.net
FROM    raw.ncboe_donations
WHERE   cluster_id = 372171
GROUP   BY cluster_id;

-- 3. committee staging integrity
SELECT  COUNT(*)                                                                                                  AS staging_rows,           -- expect 293,396
        COUNT(*) FILTER (WHERE cluster_id_v2 IS NULL)                                                             AS v2_nulls,               -- expect 0
        COUNT(DISTINCT cluster_id_v2)                                                                             AS v2_clusters,            -- expect 60,238
        COUNT(*) FILTER (WHERE committee_name_resolved IS NULL)                                                   AS resolved_nulls          -- expect 0 (Phase C complete)
FROM    staging.ncboe_party_committee_donations;

-- 4. multi-rnc_regid_v2 clusters (must be 0)
SELECT  COUNT(*) AS multi_rnc_clusters                                                                            -- expect 0
FROM    (SELECT cluster_id_v2
         FROM   staging.ncboe_party_committee_donations
         WHERE  cluster_id_v2 IS NOT NULL AND rnc_regid_v2 IS NOT NULL
         GROUP  BY cluster_id_v2
         HAVING COUNT(DISTINCT rnc_regid_v2) > 1) z;

-- 5. Ed committee canary
SELECT  COUNT(*)                                                                AS ed_rows,        -- expect 40
        SUM(norm_amount)                                                        AS ed_total,       -- expect 155945.45
        COUNT(*) FILTER (WHERE upper(trim(coalesce(norm_first,''))) = 'MELANIE') AS mel_count       -- expect 0
FROM    staging.ncboe_party_committee_donations
WHERE   cluster_id_v2 = 5005999;

-- 6. Pope committee canary
SELECT  COUNT(*)                                                                  AS pope_rows,    -- expect 22
        SUM(norm_amount)                                                          AS pope_total,   -- expect 378114.05
        COUNT(*) FILTER (WHERE upper(trim(coalesce(norm_first,''))) = 'KATHERINE') AS kat_count     -- expect 0
FROM    staging.ncboe_party_committee_donations
WHERE   cluster_id_v2 = 5037665;

COMMIT;


-- ============================================================================
-- Layer 2 — Cluster identity rollup view
-- One row per cluster_id_v2. Read-only; CREATE OR REPLACE VIEW only.
-- ============================================================================
CREATE OR REPLACE VIEW staging.v_committee_donor_identity_rollup_v1 AS
WITH addr_tokens AS (
  -- Numeric tokens extracted from address line 1 AND line 2
  SELECT s.cluster_id_v2,
         s.norm_zip5,
         m.token
  FROM   staging.ncboe_party_committee_donations s
         CROSS JOIN LATERAL (
           SELECT (regexp_matches(coalesce(s.street_line_1,'') || ' ' || coalesce(s.street_line_2,''), '\d+', 'g'))[1] AS token
         ) m
  WHERE  s.cluster_id_v2 IS NOT NULL AND m.token IS NOT NULL
),
addr_token_set AS (
  SELECT cluster_id_v2,
         array_agg(DISTINCT token ORDER BY token) AS address_numeric_token_set,
         array_agg(DISTINCT token || ':' || coalesce(norm_zip5,'') ORDER BY token || ':' || coalesce(norm_zip5,'')) AS address_token_zip_pair_set
  FROM   addr_tokens
  GROUP  BY cluster_id_v2
),
base AS (
  SELECT
    cluster_id_v2,

    -- Counts
    COUNT(*)::int                                                                              AS row_count,

    -- QA / blast-radius context (not scoring)
    SUM(norm_amount)::numeric                                                                  AS total_amount,
    MIN(norm_date)                                                                             AS first_donation_date,
    MAX(norm_date)                                                                             AS last_donation_date,

    -- Identity evidence sets
    array_agg(DISTINCT name) FILTER (WHERE name IS NOT NULL AND btrim(name) <> '')                                                 AS legal_name_variants,
    array_agg(DISTINCT upper(btrim(norm_first)))   FILTER (WHERE norm_first   IS NOT NULL AND btrim(norm_first)   <> '')           AS first_set,
    array_agg(DISTINCT upper(btrim(norm_middle)))  FILTER (WHERE norm_middle  IS NOT NULL AND btrim(norm_middle)  <> '')           AS middle_set,
    array_agg(DISTINCT upper(btrim(norm_last)))    FILTER (WHERE norm_last    IS NOT NULL AND btrim(norm_last)    <> '')           AS last_set,
    array_agg(DISTINCT upper(btrim(norm_suffix)))  FILTER (WHERE norm_suffix  IS NOT NULL AND btrim(norm_suffix)  <> '')           AS suffix_set,

    -- Address sets
    array_agg(DISTINCT norm_zip5)                  FILTER (WHERE norm_zip5    IS NOT NULL AND btrim(norm_zip5)    <> '')           AS zip5_set,
    array_agg(DISTINCT upper(btrim(city)))         FILTER (WHERE city         IS NOT NULL AND btrim(city)         <> '')           AS city_set,
    array_agg(DISTINCT upper(btrim(street_line_1))) FILTER (WHERE street_line_1 IS NOT NULL AND btrim(street_line_1) <> '')        AS street1_set,
    array_agg(DISTINCT upper(btrim(street_line_2))) FILTER (WHERE street_line_2 IS NOT NULL AND btrim(street_line_2) <> '')        AS street2_set,

    -- Recipient sets
    array_agg(DISTINCT committee_sboe_id)              FILTER (WHERE committee_sboe_id          IS NOT NULL AND btrim(committee_sboe_id) <> '')          AS recipient_committee_id_set,
    array_agg(DISTINCT committee_name_resolved)        FILTER (WHERE committee_name_resolved    IS NOT NULL AND btrim(committee_name_resolved) <> '')   AS recipient_committee_name_set,
    array_agg(DISTINCT candidate_referendum_name)      FILTER (WHERE candidate_referendum_name  IS NOT NULL AND btrim(candidate_referendum_name) <> '') AS recipient_candidate_name_set,

    -- Variation counts
    COUNT(DISTINCT upper(btrim(coalesce(norm_first,'')   || '|' || coalesce(norm_middle,'') || '|' || coalesce(norm_last,'')   || '|' || coalesce(norm_suffix,''))))                                                                                                                                                  AS name_variation_count,
    COUNT(DISTINCT upper(btrim(coalesce(street_line_1,'') || '|' || coalesce(street_line_2,'') || '|' || coalesce(norm_zip5,''))))                                                                                                                                                                                    AS address_variation_count,
    COUNT(DISTINCT norm_zip5)                                                                                                                                                                                                                                                                                          AS zip5_count,
    COUNT(DISTINCT committee_sboe_id)                                                                                                                                                                                                                                                                                  AS committee_count,
    COUNT(DISTINCT upper(btrim(norm_first)))                                                                                                                                                                                                                                                                          AS first_variation_count,
    COUNT(DISTINCT upper(btrim(norm_last)))                                                                                                                                                                                                                                                                           AS last_variation_count,

    -- Existing-match diagnostics
    array_agg(DISTINCT rnc_regid_v2)        FILTER (WHERE rnc_regid_v2        IS NOT NULL)        AS existing_rnc_regid_set,
    array_agg(DISTINCT state_voter_id_v2)   FILTER (WHERE state_voter_id_v2   IS NOT NULL)        AS existing_state_voter_id_set,
    COUNT(DISTINCT rnc_regid_v2)            FILTER (WHERE rnc_regid_v2        IS NOT NULL)        AS existing_rnc_count,
    bool_or(rnc_regid_v2 IS NOT NULL)                                                              AS already_matched,

    -- Distinct first-letter initials across norm_first (used in household_conflict heuristic)
    COUNT(DISTINCT left(upper(btrim(norm_first)), 1)) FILTER (WHERE norm_first IS NOT NULL AND btrim(norm_first) <> '')            AS first_letter_count,

    -- Suffix conflict signal
    (COUNT(DISTINCT upper(btrim(norm_suffix))) FILTER (WHERE norm_suffix IS NOT NULL AND btrim(norm_suffix) <> '') > 1)             AS suffix_conflict,

    -- Nonperson / aggregate signal
    bool_or(
      upper(coalesce(name,'')) ~ '\m(CASH|AGGREGATED|UNITEMIZED|PAC|LLC|L\.L\.C\.?|CORP|CORPORATION|COMMITTEE|FOUNDATION|TRUST|INC\.?|LP\.?|LLP|PLLC|FUND)\M'
      OR coalesce(is_unitemized, FALSE) = TRUE
    )                                                                                              AS nonperson_or_aggregate_signal

  FROM   staging.ncboe_party_committee_donations
  WHERE  cluster_id_v2 IS NOT NULL
  GROUP  BY cluster_id_v2
)
SELECT
  b.cluster_id_v2,
  b.row_count,
  b.total_amount,
  b.first_donation_date,
  b.last_donation_date,

  b.legal_name_variants,
  b.first_set,
  b.middle_set,
  b.last_set,
  b.suffix_set,

  b.zip5_set,
  b.city_set,
  b.street1_set,
  b.street2_set,
  COALESCE(at.address_numeric_token_set, ARRAY[]::text[])    AS address_numeric_token_set,
  COALESCE(at.address_token_zip_pair_set, ARRAY[]::text[])   AS address_token_zip_pair_set,

  b.recipient_committee_id_set,
  b.recipient_committee_name_set,
  b.recipient_candidate_name_set,

  b.name_variation_count,
  b.address_variation_count,
  b.zip5_count,
  b.committee_count,
  b.first_variation_count,
  b.last_variation_count,

  b.existing_rnc_regid_set,
  b.existing_state_voter_id_set,
  b.existing_rnc_count,
  b.already_matched,

  b.suffix_conflict,

  -- likely_household_conflict (conservative): >= 3 distinct first-letter initials
  -- AND single last name AND a single address — likely a household over-merged into one cluster
  (b.first_letter_count >= 3 AND b.last_variation_count = 1 AND b.address_variation_count = 1)  AS likely_household_conflict,

  b.nonperson_or_aggregate_signal,

  -- needs_review aggregates the above flags
  (b.suffix_conflict
   OR (b.first_letter_count >= 3 AND b.last_variation_count = 1 AND b.address_variation_count = 1)
   OR b.nonperson_or_aggregate_signal)                                                          AS needs_review,

  -- review_reason as text array
  ARRAY(SELECT unnest(reasons) WHERE unnest IS NOT NULL)
    AS review_reason
  FROM (SELECT ARRAY[
    CASE WHEN b.suffix_conflict THEN 'suffix_conflict' END,
    CASE WHEN (b.first_letter_count >= 3 AND b.last_variation_count = 1 AND b.address_variation_count = 1) THEN 'likely_household_conflict' END,
    CASE WHEN b.nonperson_or_aggregate_signal THEN 'nonperson_or_aggregate_signal' END
  ] AS reasons) r

FROM   base b
       LEFT JOIN addr_token_set at ON at.cluster_id_v2 = b.cluster_id_v2;

-- Alternative simpler review_reason if the lateral above causes parser issues:
-- (Reviewer: choose ONE of the review_reason expressions and remove the other.)
COMMENT ON VIEW staging.v_committee_donor_identity_rollup_v1 IS
  'Layer 2 cluster identity rollup. One row per cluster_id_v2. Read-only. Used as input to cluster-level DataTrust match dry-run. Not a scoring/rating/microsegment table — total_amount and date fields are QA/blast-radius context only.';


-- ============================================================================
-- Rollup health summary (read-only)
-- ============================================================================
SELECT
  COUNT(*)                                            AS total_clusters,
  COUNT(*) FILTER (WHERE already_matched)             AS already_matched_clusters,
  COUNT(*) FILTER (WHERE NOT already_matched)         AS unmatched_clusters,
  COUNT(*) FILTER (WHERE suffix_conflict)              AS suffix_conflict_clusters,
  COUNT(*) FILTER (WHERE likely_household_conflict)    AS household_conflict_clusters,
  COUNT(*) FILTER (WHERE nonperson_or_aggregate_signal) AS nonperson_aggregate_clusters,
  COUNT(*) FILTER (WHERE needs_review)                 AS needs_review_clusters
FROM   staging.v_committee_donor_identity_rollup_v1;


-- ============================================================================
-- Layer 3 — Cluster-level DataTrust match dry-run (read-only)
-- ============================================================================
-- Inputs: rollup rows where NOT already_matched AND NOT needs_review.
-- Output: SELECTed proposals only. NO writes.
-- ============================================================================

WITH eligible AS (
  SELECT *
  FROM   staging.v_committee_donor_identity_rollup_v1
  WHERE  NOT already_matched
    AND  NOT needs_review
),
candidates AS (
  -- For each eligible cluster, find DataTrust candidate rows whose last_name
  -- is in the cluster's last_set AND whose first_name is in the cluster's
  -- first_set OR whose first-letter initial appears in any first_set entry.
  SELECT
    e.cluster_id_v2,
    dt.rnc_regid,
    dt.state_voter_id,
    dt.last_name                                   AS dt_last_name,
    dt.first_name                                  AS dt_first_name,
    dt.middle_name                                 AS dt_middle_name,
    dt.name_suffix                                 AS dt_suffix,
    dt.reg_zip5                                    AS dt_reg_zip5,
    dt.mail_zip5                                   AS dt_mail_zip5
  FROM   eligible e
         JOIN core.datatrust_voter_nc dt
              -- last-name strict anchor: DataTrust last_name MUST be in cluster last_set
              ON upper(btrim(dt.last_name)) = ANY (e.last_set)
              -- first-name evidence: full match OR initial overlap
              AND (
                upper(btrim(dt.first_name)) = ANY (e.first_set)
                OR EXISTS (SELECT 1 FROM unnest(e.first_set) f WHERE left(f, 1) = left(upper(btrim(dt.first_name)), 1))
              )
),
filtered AS (
  -- Apply middle and suffix compatibility.
  SELECT c.*,
         e.middle_set, e.suffix_set, e.zip5_set, e.address_token_zip_pair_set,
         e.recipient_committee_id_set,
         -- middle_compat: NULL on either side is unknown-not-conflict; concrete sides must align (full or initial)
         (
           c.dt_middle_name IS NULL OR e.middle_set IS NULL OR array_length(e.middle_set, 1) IS NULL
           OR upper(btrim(c.dt_middle_name)) = ANY (e.middle_set)
           OR EXISTS (SELECT 1 FROM unnest(e.middle_set) m WHERE left(m, 1) = left(upper(btrim(c.dt_middle_name)), 1))
         )                                                                                AS middle_compat,
         -- suffix_compat: concrete vs concrete must equal; NULL vs anything is unknown-not-conflict
         (
           c.dt_suffix IS NULL OR e.suffix_set IS NULL OR array_length(e.suffix_set, 1) IS NULL
           OR upper(btrim(c.dt_suffix)) = ANY (e.suffix_set)
         )                                                                                AS suffix_compat,
         -- zip overlap (any of cluster zip5_set in DataTrust reg or mail)
         (c.dt_reg_zip5 = ANY (e.zip5_set) OR c.dt_mail_zip5 = ANY (e.zip5_set))          AS zip5_overlap
  FROM   candidates c
         JOIN eligible e ON e.cluster_id_v2 = c.cluster_id_v2
  WHERE  TRUE
),
proposals_pre AS (
  -- Per cluster: the surviving filtered candidates after middle/suffix compatibility.
  SELECT cluster_id_v2,
         COUNT(*)                                  AS surviving_rows,
         COUNT(DISTINCT rnc_regid)                 AS distinct_rnc,
         (array_agg(rnc_regid                ORDER BY rnc_regid))[1]      AS proposed_rnc_regid_v2,
         (array_agg(state_voter_id           ORDER BY rnc_regid))[1]      AS proposed_state_voter_id_v2,
         (array_agg(dt_last_name             ORDER BY rnc_regid))[1]      AS dt_last_name,
         (array_agg(dt_first_name            ORDER BY rnc_regid))[1]      AS dt_first_name,
         (array_agg(dt_middle_name           ORDER BY rnc_regid))[1]      AS dt_middle_name,
         (array_agg(dt_suffix                ORDER BY rnc_regid))[1]      AS dt_suffix,
         bool_or(zip5_overlap)                                            AS any_zip5_overlap
  FROM   filtered
  WHERE  middle_compat AND suffix_compat
  GROUP  BY cluster_id_v2
),
cluster_rnc_dedup AS (
  -- Cross-cluster uniqueness: count how many clusters propose the same rnc.
  SELECT proposed_rnc_regid_v2, COUNT(*) AS reused_rnc_group_count
  FROM   proposals_pre
  WHERE  distinct_rnc = 1
  GROUP  BY proposed_rnc_regid_v2
)
SELECT
  pp.cluster_id_v2,
  e.row_count                                                                    AS cluster_row_count,
  e.total_amount                                                                 AS cluster_total_amount,             -- QA / blast-radius context only
  e.first_set, e.middle_set, e.last_set, e.suffix_set,
  e.zip5_set,
  e.recipient_committee_id_set,
  pp.proposed_rnc_regid_v2,
  pp.proposed_state_voter_id_v2,
  pp.dt_last_name, pp.dt_first_name, pp.dt_middle_name, pp.dt_suffix,
  pp.any_zip5_overlap,
  -- Tier
  CASE
    WHEN pp.any_zip5_overlap                                       THEN 'T_zip'
    ELSE                                                                'T_cross_zip'
  END                                                                            AS proposed_match_tier_v2,
  -- Cross-cluster reuse
  COALESCE(crd.reused_rnc_group_count, 1)                                        AS reused_rnc_group_count,
  -- apply_eligible: provisional. Cross-cluster reuse without recipient-overlap evidence still requires review.
  CASE
    WHEN pp.distinct_rnc <> 1                                                                                                  THEN 'NO'
    WHEN COALESCE(crd.reused_rnc_group_count, 1) > 1                                                                            THEN 'REVIEW'
    ELSE                                                                                                                            'PROVISIONAL_YES'
  END                                                                            AS apply_eligible_provisional,
  -- Diagnostic columns (NOT scoring)
  e.first_donation_date, e.last_donation_date,
  e.name_variation_count, e.address_variation_count, e.zip5_count, e.committee_count
FROM   proposals_pre pp
       JOIN staging.v_committee_donor_identity_rollup_v1 e ON e.cluster_id_v2 = pp.cluster_id_v2
       LEFT JOIN cluster_rnc_dedup crd ON crd.proposed_rnc_regid_v2 = pp.proposed_rnc_regid_v2
ORDER  BY apply_eligible_provisional, pp.cluster_id_v2;


-- ============================================================================
-- Match summary (read-only, intended for the dry-run report)
-- ============================================================================
WITH eligible AS (
  SELECT * FROM staging.v_committee_donor_identity_rollup_v1
  WHERE NOT already_matched AND NOT needs_review
),
... -- (re-declare proposals_pre and cluster_rnc_dedup as above for use here in production; omitted to keep this file readable)
SELECT
  COUNT(*) FILTER (WHERE apply_eligible_provisional = 'PROVISIONAL_YES')         AS provisional_yes_clusters,
  COUNT(*) FILTER (WHERE apply_eligible_provisional = 'REVIEW')                  AS review_required_clusters,
  COUNT(*) FILTER (WHERE apply_eligible_provisional = 'NO')                      AS rejected_clusters,
  SUM(cluster_row_count) FILTER (WHERE apply_eligible_provisional = 'PROVISIONAL_YES') AS provisional_yes_rows,
  SUM(cluster_row_count) FILTER (WHERE apply_eligible_provisional = 'REVIEW')     AS review_required_rows,
  SUM(cluster_row_count) FILTER (WHERE apply_eligible_provisional = 'NO')         AS rejected_rows
FROM   /* the proposals output above, materialized into a CTE in the runner script */ proposals_output;


-- ============================================================================
-- HARD NO-GO REMINDERS
-- ============================================================================
-- Do NOT run UPDATE staging.ncboe_party_committee_donations SET rnc_regid_v2 = ...
-- Do NOT run UPDATE ... SET state_voter_id_v2 = ...
-- Do NOT run UPDATE ... SET match_tier_v2 = ...
-- Do NOT run UPDATE ... SET is_matched_v2 = ...
-- Do NOT run Stage 4 propagation.
-- Do NOT swap _v2 to canonical.
-- Do NOT touch raw.ncboe_donations.
-- Do NOT touch attribution / person_master / FEC / Acxiom.
-- Do NOT touch scoring / rating / microsegment / model / Brain / dashboards.
-- Apply requires Ed's exact authorization phrase per the Phase C protocol.
-- ============================================================================
