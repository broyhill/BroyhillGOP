-- =====================================================================
-- Stage 1b Business-Address + SIC/NAICS Bridge — POPULATE
-- =====================================================================
-- Target: Hetzner Postgres 37.27.169.232, schema `core`
-- Author: Nexus, 2026-04-18
-- Deadline: Monday 2026-04-20
--
-- Purpose
-- -------
-- Populates the industry + business-address columns added by 01b_bridge_ddl.sql.
-- Unlocks the 17,698 dark-donor clusters by classifying their employer text
-- into SIC/NAICS + flagging donation addresses as business addresses so
-- Stage 2 matching can use them.
--
-- Reads ONLY from:
--   core.donor_profile                        (populated by 02_populate_donor_profile.sql)
--   donor_intelligence.sic_keyword_patterns   (272 rows, from donor_sic_classification_engine.sql)
--   donor_intelligence.profession_sic_patterns(74 rows)
--   donor_intelligence.sic_divisions          (80 rows)
--   core.datatrust_voter_nc                   (7,727,637 rows, for res_street_address + zip)
--
-- Writes ONLY to:
--   core.donor_profile (UPDATE in place, IS NULL guards on first source wins)
--   core.donor_profile_audit (one audit row per bridge run)
--
-- Authorization: UPDATE-only on a non-sacred table. Row count preserved.
-- Run DRY RUN first (ROLLBACK at the end). Ed must type
-- `I AUTHORIZE THIS ACTION` once on DRY RUN output before COMMIT.
--
-- IS NULL guards
-- --------------
-- Every UPDATE checks the target column IS NULL. First source wins.
-- Running this script a second time is a no-op (except for the audit log).
-- Ed can re-run safely if a future stage adds more patterns.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Step 0 — pre-flight counts
-- ---------------------------------------------------------------------
DO $$
DECLARE
    n_profile INT;
    n_patterns INT;
    n_professions INT;
BEGIN
    SELECT COUNT(*) INTO n_profile  FROM core.donor_profile;
    SELECT COUNT(*) INTO n_patterns FROM donor_intelligence.sic_keyword_patterns;
    SELECT COUNT(*) INTO n_professions FROM donor_intelligence.profession_sic_patterns;
    IF n_profile = 0 THEN
        RAISE EXCEPTION 'core.donor_profile is empty. Run 02_populate_donor_profile.sql first.';
    END IF;
    IF n_patterns = 0 THEN
        RAISE EXCEPTION 'donor_intelligence.sic_keyword_patterns is empty. Run donor_sic_classification_engine.sql migration first.';
    END IF;
    IF n_professions = 0 THEN
        RAISE EXCEPTION 'donor_intelligence.profession_sic_patterns is empty. Run donor_sic_classification_engine.sql migration first.';
    END IF;
    RAISE NOTICE 'Pre-flight: profile rows=%, sic_keywords=%, profession_patterns=%',
                 n_profile, n_patterns, n_professions;
END $$;

-- ---------------------------------------------------------------------
-- Step 1 — normalize employer text (IS NULL guard)
--   Uses core.normalize_employer() from 01b_bridge_ddl.sql.
-- ---------------------------------------------------------------------
UPDATE core.donor_profile
   SET employer_normalized = core.normalize_employer(employer)
 WHERE employer_normalized IS NULL
   AND employer IS NOT NULL;

-- ---------------------------------------------------------------------
-- Step 2 — Layer 1: employer KEYWORD match
--   For each profile, pick the HIGHEST match_priority pattern that hits
--   the normalized employer. Ties broken by longest keyword_pattern
--   (more specific wins).
--   IS NULL guard on sic_code: if a prior run already classified, skip.
-- ---------------------------------------------------------------------
WITH ranked AS (
    SELECT
        p.cluster_id,
        k.sic_code,
        k.sic_division,
        k.sic_description,
        k.naics_code,
        k.match_priority,
        k.keyword_pattern,
        ROW_NUMBER() OVER (
            PARTITION BY p.cluster_id
            ORDER BY k.match_priority DESC,
                     LENGTH(k.keyword_pattern) DESC,
                     k.pattern_id ASC
        ) AS rn
    FROM core.donor_profile p
    JOIN donor_intelligence.sic_keyword_patterns k
      ON p.employer_normalized IS NOT NULL
     AND p.employer_normalized ILIKE k.keyword_pattern
    WHERE p.sic_code IS NULL
      AND p.employer_normalized NOT IN ('RETIRED','SELF-EMPLOYED')
)
UPDATE core.donor_profile p
   SET sic_code             = r.sic_code,
       sic_division         = r.sic_division,
       sic_description      = r.sic_description,
       naics_code           = r.naics_code,
       sic_match_method     = 'EMPLOYER_KEYWORD',
       sic_match_confidence = r.match_priority,
       sic_matched_pattern  = r.keyword_pattern
  FROM ranked r
 WHERE r.rn = 1
   AND p.cluster_id = r.cluster_id
   AND p.sic_code IS NULL;           -- double-guard (idempotence)

-- Fill industry_sector from sic_divisions
UPDATE core.donor_profile p
   SET industry_sector = d.division_name
  FROM donor_intelligence.sic_divisions d
 WHERE p.sic_division = d.sic_division
   AND p.industry_sector IS NULL;

-- ---------------------------------------------------------------------
-- Step 3 — Layer 2: profession FALLBACK
--   Only fires where employer_normalized is RETIRED / SELF-EMPLOYED / NULL
--   AND sic_code is still NULL.
-- ---------------------------------------------------------------------
WITH prof_ranked AS (
    SELECT
        p.cluster_id,
        pr.sic_code,
        pr.sic_description,
        LEFT(pr.sic_code, 2) AS sic_division,
        pr.naics_code,
        pr.industry_sector,
        pr.match_priority,
        pr.profession_pattern,
        ROW_NUMBER() OVER (
            PARTITION BY p.cluster_id
            ORDER BY pr.match_priority DESC,
                     LENGTH(pr.profession_pattern) DESC,
                     pr.pattern_id ASC
        ) AS rn
    FROM core.donor_profile p
    JOIN donor_intelligence.profession_sic_patterns pr
      ON p.job_title IS NOT NULL
     AND UPPER(TRIM(p.job_title)) = pr.profession_pattern
    WHERE p.sic_code IS NULL
      AND (p.employer_normalized IS NULL
           OR p.employer_normalized IN ('RETIRED','SELF-EMPLOYED'))
)
UPDATE core.donor_profile p
   SET sic_code             = r.sic_code,
       sic_division         = r.sic_division,
       sic_description      = r.sic_description,
       naics_code           = r.naics_code,
       industry_sector      = r.industry_sector,
       sic_match_method     = 'PROFESSION',
       sic_match_confidence = r.match_priority,
       sic_matched_pattern  = r.profession_pattern
  FROM prof_ranked r
 WHERE r.rn = 1
   AND p.cluster_id = r.cluster_id
   AND p.sic_code IS NULL;

-- Fallback layer 2b: profession contains pattern (ILIKE) when no exact hit.
-- Kept strictly second so exact matches always win.
WITH prof_ranked_like AS (
    SELECT
        p.cluster_id,
        pr.sic_code,
        pr.sic_description,
        LEFT(pr.sic_code, 2) AS sic_division,
        pr.naics_code,
        pr.industry_sector,
        pr.match_priority,
        pr.profession_pattern,
        ROW_NUMBER() OVER (
            PARTITION BY p.cluster_id
            ORDER BY pr.match_priority DESC,
                     LENGTH(pr.profession_pattern) DESC,
                     pr.pattern_id ASC
        ) AS rn
    FROM core.donor_profile p
    JOIN donor_intelligence.profession_sic_patterns pr
      ON p.job_title IS NOT NULL
     AND UPPER(TRIM(p.job_title)) LIKE '%' || pr.profession_pattern || '%'
    WHERE p.sic_code IS NULL
)
UPDATE core.donor_profile p
   SET sic_code             = r.sic_code,
       sic_division         = r.sic_division,
       sic_description      = r.sic_description,
       naics_code           = r.naics_code,
       industry_sector      = r.industry_sector,
       sic_match_method     = 'PROFESSION',
       sic_match_confidence = r.match_priority,
       sic_matched_pattern  = r.profession_pattern
  FROM prof_ranked_like r
 WHERE r.rn = 1
   AND p.cluster_id = r.cluster_id
   AND p.sic_code IS NULL;

-- ---------------------------------------------------------------------
-- Step 4 — pull voter home address for matched donors
--   IS NULL guard: only stamp if not already set.
-- ---------------------------------------------------------------------
UPDATE core.donor_profile p
   SET voter_home_street = UPPER(TRIM(v.res_street_address)),
       voter_home_zip5   = LEFT(REGEXP_REPLACE(COALESCE(v.zip_code,''), '[^0-9]','','g'), 5)
  FROM core.datatrust_voter_nc v
 WHERE p.rnc_regid = v.rnc_regid
   AND p.has_voter_match = TRUE
   AND p.voter_home_street IS NULL;

-- ---------------------------------------------------------------------
-- Step 5 — classify address as HOME / BUSINESS / UNKNOWN
--   Mirrors scripts/audit_top100_home_vs_business_address.py logic:
--     HOME     = donation street ≈ voter residence street (same number+zip or
--                leading-25-char overlap or substring)
--     BUSINESS = voter file known AND donation street ≠ voter residence
--     UNKNOWN  = no voter match OR missing donation street
-- ---------------------------------------------------------------------
WITH norm AS (
    SELECT
        cluster_id,
        has_voter_match,
        -- Donation address bits
        UPPER(TRIM(
            REGEXP_REPLACE(
                REGEXP_REPLACE(COALESCE(street_line_1,''), '\s*(APT|SUITE|#|UNIT|STE|FL)\s*.*$', '', 'i'),
                '\s+', ' ', 'g')
        )) AS d_norm,
        -- Donation leading street number (or PO Box number)
        COALESCE(
            (REGEXP_MATCHES(UPPER(COALESCE(street_line_1,'')), 'P\.?O\.?\s*BOX\s*(\d+)'))[1],
            (REGEXP_MATCHES(COALESCE(street_line_1,''), '^(\d+[A-Za-z]?)\s'))[1]
        ) AS d_num,
        zip5 AS d_zip5,
        -- Voter address bits
        UPPER(TRIM(
            REGEXP_REPLACE(
                REGEXP_REPLACE(COALESCE(voter_home_street,''), '\s*(APT|SUITE|#|UNIT|STE|FL)\s*.*$', '', 'i'),
                '\s+', ' ', 'g')
        )) AS v_norm,
        COALESCE(
            (REGEXP_MATCHES(UPPER(COALESCE(voter_home_street,'')), 'P\.?O\.?\s*BOX\s*(\d+)'))[1],
            (REGEXP_MATCHES(COALESCE(voter_home_street,''), '^(\d+[A-Za-z]?)\s'))[1]
        ) AS v_num,
        voter_home_zip5 AS v_zip5,
        -- PO-box signal on donation address
        (COALESCE(street_line_1,'') ~* 'P\.?O\.?\s*BOX') AS d_is_pobox
    FROM core.donor_profile
),
classified AS (
    SELECT
        cluster_id,
        has_voter_match,
        d_is_pobox,
        d_norm,
        CASE
            WHEN NOT has_voter_match                THEN 'UNKNOWN'
            WHEN d_norm = '' OR v_norm = ''         THEN 'UNKNOWN'
            WHEN d_norm = v_norm                    THEN 'HOME'
            WHEN d_num IS NOT NULL AND v_num IS NOT NULL
                 AND d_num = v_num
                 AND COALESCE(d_zip5,'') = COALESCE(v_zip5,'')  THEN 'HOME'
            WHEN d_num IS NOT NULL AND v_num IS NOT NULL
                 AND d_num = v_num                  THEN 'HOME'
            WHEN LENGTH(d_norm) >= 15 AND LENGTH(v_norm) >= 15
                 AND LEFT(d_norm, 25) = LEFT(v_norm, 25)        THEN 'HOME'
            WHEN LENGTH(d_norm) >= 15 AND LENGTH(v_norm) >= 15
                 AND (d_norm LIKE '%' || v_norm || '%'
                      OR v_norm LIKE '%' || d_norm || '%')       THEN 'HOME'
            ELSE 'BUSINESS'
        END AS address_class_new
    FROM norm
)
UPDATE core.donor_profile p
   SET address_class      = c.address_class_new,
       home_matches_voter = (c.address_class_new = 'HOME')
  FROM classified c
 WHERE p.cluster_id = c.cluster_id
   AND p.address_class IS NULL;

-- ---------------------------------------------------------------------
-- Step 6 — populate business_* address fields for BUSINESS-classified rows
--   These mirror street_line_1/city/state/zip5 but stored separately so
--   Stage 2 matching can distinguish "home" vs "business" attributes.
-- ---------------------------------------------------------------------
UPDATE core.donor_profile
   SET business_street_line_1 = street_line_1,
       business_city          = city,
       business_state         = state,
       business_zip5          = zip5
 WHERE address_class = 'BUSINESS'
   AND business_street_line_1 IS NULL;

-- ---------------------------------------------------------------------
-- Step 7 — dark-donor business-address flag
--   For clusters with NO voter match:
--     - If employer is populated (any form) AND donation address is not a
--       PO Box, flag business-likely (employer + non-residential address
--       cadence is the strongest signal we have pre-NC SoS).
--     - Conservative: only set to TRUE where flag is currently FALSE.
-- ---------------------------------------------------------------------
UPDATE core.donor_profile
   SET dark_donor_business_likely = TRUE
 WHERE has_voter_match = FALSE
   AND dark_donor_business_likely = FALSE
   AND employer IS NOT NULL
   AND TRIM(employer) <> ''
   AND employer_normalized IS NOT NULL
   AND employer_normalized NOT IN ('RETIRED','SELF-EMPLOYED')
   AND street_line_1 IS NOT NULL
   AND street_line_1 !~* 'P\.?O\.?\s*BOX';

-- For dark donors, also copy donation address into business_* if we marked
-- them business-likely and business_* is still empty.
UPDATE core.donor_profile
   SET business_street_line_1 = street_line_1,
       business_city          = city,
       business_state         = state,
       business_zip5          = zip5,
       address_class          = COALESCE(address_class, 'BUSINESS')
 WHERE dark_donor_business_likely = TRUE
   AND business_street_line_1 IS NULL;

-- ---------------------------------------------------------------------
-- Step 8 — stamp bridge version + build timestamp on every row touched
-- ---------------------------------------------------------------------
UPDATE core.donor_profile
   SET bridge_version  = 'v1.0-biz-bridge',
       bridge_built_at = NOW()
 WHERE bridge_version IS NULL;

-- ---------------------------------------------------------------------
-- Step 9 — audit log
-- ---------------------------------------------------------------------
INSERT INTO core.donor_profile_audit (
    profile_version, rows_before, rows_after,
    ed_canary_txns, ed_canary_total, ed_canary_email,
    notes
)
SELECT
    'v1.0-biz-bridge',
    (SELECT COUNT(*) FROM core.donor_profile),
    (SELECT COUNT(*) FROM core.donor_profile),
    (SELECT txn_count       FROM core.donor_profile WHERE cluster_id = 372171),
    (SELECT lifetime_total  FROM core.donor_profile WHERE cluster_id = 372171),
    (SELECT personal_email  FROM core.donor_profile WHERE cluster_id = 372171),
    FORMAT(
      'Bridge v1.0 run. SIC-classified: %s. Dark business-likely: %s. HOME: %s. BUSINESS: %s. UNKNOWN: %s.',
      (SELECT COUNT(*) FROM core.donor_profile WHERE sic_code IS NOT NULL),
      (SELECT COUNT(*) FROM core.donor_profile WHERE dark_donor_business_likely),
      (SELECT COUNT(*) FROM core.donor_profile WHERE address_class = 'HOME'),
      (SELECT COUNT(*) FROM core.donor_profile WHERE address_class = 'BUSINESS'),
      (SELECT COUNT(*) FROM core.donor_profile WHERE address_class = 'UNKNOWN')
    );

-- ---------------------------------------------------------------------
-- Step 10 — CANARY GATE (abort the transaction on any red flag)
-- ---------------------------------------------------------------------
DO $$
DECLARE
    ed_txns     INT;
    ed_total    NUMERIC(14,2);
    ed_email    TEXT;
    ed_sic      TEXT;
    ed_method   TEXT;
    ed_address  TEXT;
    total_rows  INT;
    sic_hit     INT;
    dark_biz    INT;
BEGIN
    SELECT txn_count, lifetime_total, personal_email, sic_code, sic_match_method, address_class
      INTO ed_txns, ed_total, ed_email, ed_sic, ed_method, ed_address
      FROM core.donor_profile WHERE cluster_id = 372171;

    SELECT COUNT(*) INTO total_rows FROM core.donor_profile;
    SELECT COUNT(*) INTO sic_hit FROM core.donor_profile WHERE sic_code IS NOT NULL;
    SELECT COUNT(*) INTO dark_biz FROM core.donor_profile WHERE dark_donor_business_likely;

    -- Base Stage-1 canaries (must still match after the bridge)
    IF ed_txns IS DISTINCT FROM 147 THEN
        RAISE EXCEPTION 'CANARY FAIL: Ed cluster 372171 txns=% (expected 147)', ed_txns;
    END IF;
    IF ed_total IS DISTINCT FROM 332631.30 THEN
        RAISE EXCEPTION 'CANARY FAIL: Ed cluster 372171 total=% (expected 332631.30)', ed_total;
    END IF;
    IF ed_email = 'jsneeden@msn.com' THEN
        RAISE EXCEPTION 'CANARY FAIL: Ed cluster 372171 personal_email is Apollo bad data (jsneeden@msn.com)';
    END IF;

    -- Bridge-specific canaries
    IF total_rows IS DISTINCT FROM 98303 THEN
        RAISE EXCEPTION 'CANARY FAIL: donor_profile row count=% (expected 98303)', total_rows;
    END IF;
    IF sic_hit = 0 THEN
        RAISE EXCEPTION 'CANARY FAIL: SIC classifier hit 0 rows. Check employer_normalized + sic_keyword_patterns joined properly.';
    END IF;
    IF dark_biz = 0 THEN
        RAISE WARNING 'Bridge warning: 0 dark-donor business-likely rows. That is unusual (expected ~thousands); inspect dark-donor employer column.';
    END IF;

    -- Sanity-note for Ed: his employer "Anvil Venture Group" should land on
    -- a holding/investment SIC via keyword or profession. Don't RAISE
    -- EXCEPTION — Anvil isn't in the 272 keyword list; it falls through
    -- to profession (INVESTOR / BUSINESS OWNER / etc). Show the result.
    RAISE NOTICE 'Ed 372171 bridge result: sic=%, method=%, address_class=%', ed_sic, ed_method, ed_address;
    RAISE NOTICE 'Bridge summary: rows=%, sic_hit=%, dark_biz=%', total_rows, sic_hit, dark_biz;
END $$;

-- ---------------------------------------------------------------------
-- HOLD POINT
--   DRY RUN: replace COMMIT with ROLLBACK and run to see summary.
--   If counts look sane, re-run with COMMIT.
-- ---------------------------------------------------------------------
COMMIT;
