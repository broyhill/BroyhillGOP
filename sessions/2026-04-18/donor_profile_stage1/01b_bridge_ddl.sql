-- =====================================================================
-- Stage 1b Business-Address + SIC/NAICS Bridge — DDL (additive)
-- =====================================================================
-- Target:  Hetzner Postgres 37.27.169.232, schema `core`
-- Author:  Nexus, 2026-04-18
-- Deadline: Monday 2026-04-20
--
-- Contract
-- --------
-- * Additive only. No DROP. No ALTER of existing columns. No DELETE.
-- * Extends core.donor_profile with industry / business-address columns.
-- * Adds one IMMUTABLE SQL function: core.normalize_employer().
-- * Depends on existing infrastructure (already on Hetzner):
--     donor_intelligence.sic_divisions        (80 rows)
--     donor_intelligence.sic_keyword_patterns (272 rows)
--     donor_intelligence.profession_sic_patterns (74 rows)
--   These were built by database/migrations/donor_sic_classification_engine.sql.
--
-- Safe to run without `I AUTHORIZE THIS ACTION` — creates no rows, changes
-- no existing column, writes no data.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Add columns to core.donor_profile (additive; IF NOT EXISTS everywhere)
-- ---------------------------------------------------------------------
-- Industry classification (SIC/NAICS)
ALTER TABLE core.donor_profile
    ADD COLUMN IF NOT EXISTS employer_normalized  TEXT,
    ADD COLUMN IF NOT EXISTS naics_code            VARCHAR(6),
    ADD COLUMN IF NOT EXISTS sic_division          VARCHAR(2),
    ADD COLUMN IF NOT EXISTS sic_description       TEXT,
    ADD COLUMN IF NOT EXISTS industry_sector       TEXT,
    ADD COLUMN IF NOT EXISTS sic_match_method      VARCHAR(20),     -- EMPLOYER_KEYWORD | PROFESSION | MANUAL | NULL
    ADD COLUMN IF NOT EXISTS sic_match_confidence  INTEGER,         -- match_priority of the rule that hit
    ADD COLUMN IF NOT EXISTS sic_matched_pattern   TEXT;

-- Business vs home address attribution
ALTER TABLE core.donor_profile
    ADD COLUMN IF NOT EXISTS voter_home_street     TEXT,            -- copied from nc_voters.res_street_address
    ADD COLUMN IF NOT EXISTS voter_home_zip5       TEXT,
    ADD COLUMN IF NOT EXISTS home_matches_voter    BOOLEAN,         -- donation street vs voter street
    ADD COLUMN IF NOT EXISTS address_class         VARCHAR(16),     -- HOME | BUSINESS | UNKNOWN
    ADD COLUMN IF NOT EXISTS business_street_line_1 TEXT,           -- copy of donation address if classified BUSINESS
    ADD COLUMN IF NOT EXISTS business_city         TEXT,
    ADD COLUMN IF NOT EXISTS business_state        TEXT,
    ADD COLUMN IF NOT EXISTS business_zip5         TEXT,
    ADD COLUMN IF NOT EXISTS dark_donor_business_likely BOOLEAN NOT NULL DEFAULT FALSE;

-- Audit of the bridge run itself
ALTER TABLE core.donor_profile
    ADD COLUMN IF NOT EXISTS bridge_version        TEXT,
    ADD COLUMN IF NOT EXISTS bridge_built_at       TIMESTAMPTZ;

-- Index surface for the new columns (CREATE INDEX IF NOT EXISTS — additive)
CREATE INDEX IF NOT EXISTS idx_donor_profile_sic_code
    ON core.donor_profile (sic_code) WHERE sic_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_donor_profile_naics_code
    ON core.donor_profile (naics_code) WHERE naics_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_donor_profile_industry_sector
    ON core.donor_profile (industry_sector) WHERE industry_sector IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_donor_profile_address_class
    ON core.donor_profile (address_class);
CREATE INDEX IF NOT EXISTS idx_donor_profile_dark_business
    ON core.donor_profile (dark_donor_business_likely) WHERE dark_donor_business_likely;
CREATE INDEX IF NOT EXISTS idx_donor_profile_employer_normalized
    ON core.donor_profile (employer_normalized) WHERE employer_normalized IS NOT NULL;

-- ---------------------------------------------------------------------
-- 2. Inline SQL mirror of pipeline/employer_normalizer.py
--    Keeps the bridge pure-Postgres (no Python cron, no brittle shell glue).
--    Pure function, IMMUTABLE, so it indexes well if we ever want to.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.normalize_employer(raw_in TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    s TEXT;
    u TEXT;
BEGIN
    IF raw_in IS NULL THEN
        RETURN NULL;
    END IF;
    s := TRIM(raw_in);
    IF s = '' THEN
        RETURN NULL;
    END IF;
    u := UPPER(s);

    -- Map "none-like" to NULL
    IF u IN ('NONE','N/A','NA','NULL','UNK','UNKNOWN') THEN
        RETURN NULL;
    END IF;

    -- Map retired/self to canonical tokens
    IF u IN ('RETIRED','RET','RET.') THEN
        RETURN 'RETIRED';
    END IF;
    IF u IN ('SELF','SELF-EMPLOYED','SELF EMPLOYED','SELFEMPLOYED')
       OR POSITION('SELF-EMPLOYED' IN REPLACE(u,' ','')) > 0 THEN
        RETURN 'SELF-EMPLOYED';
    END IF;

    -- Strip corporate noise (INC / LLC / CORP / CO / LTD / LP / LLP / PC / PA / PLLC / DBA)
    u := REGEXP_REPLACE(u, '\s+', ' ', 'g');
    u := REGEXP_REPLACE(
            u,
            '\m(INC\.?|LLC\.?|CORP\.?|CO\.?|LTD\.?|LP\.?|LLP\.?|PC\.?|PA\.?|PLLC\.?|DBA)\M',
            '',
            'gi'
         );
    u := REGEXP_REPLACE(u, '[,.\s]+$', '', 'g');
    u := REGEXP_REPLACE(u, '\s+', ' ', 'g');
    u := TRIM(u);

    -- Known variant groups — first element of each group is canonical
    IF u = 'ANVIL VENTURES' OR u = 'ANVIL VENTURE' OR u = 'ANVILE VENTURE'
       OR u LIKE 'ANVIL VENTURE %'
       OR u LIKE 'ANVIL VENTURES %'
       OR u LIKE 'ANVILE VENTURE %' THEN
        RETURN 'ANVIL VENTURE GROUP';
    END IF;
    IF u = 'VARIETY WHOLESALE' OR u LIKE 'VARIETY WHOLESALE %' THEN
        RETURN 'VARIETY WHOLESALERS';
    END IF;

    IF u = '' THEN
        RETURN NULL;
    END IF;
    RETURN u;
END;
$$;

COMMENT ON FUNCTION core.normalize_employer(TEXT) IS
'Mirror of pipeline/employer_normalizer.py::normalize_employer_text. IMMUTABLE. Uppercases, strips corporate noise, maps retired/self/none to canonical tokens, applies known variant groups (ANVIL VENTURE GROUP, VARIETY WHOLESALERS).';

-- ---------------------------------------------------------------------
-- 3. Self-test on the normalizer (read-only; aborts transaction on failure)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF core.normalize_employer('  anvil ventures llc  ') IS DISTINCT FROM 'ANVIL VENTURE GROUP' THEN
        RAISE EXCEPTION 'normalize_employer self-test FAIL: anvil ventures llc -> %',
            core.normalize_employer('  anvil ventures llc  ');
    END IF;
    IF core.normalize_employer('RETIRED') IS DISTINCT FROM 'RETIRED' THEN
        RAISE EXCEPTION 'normalize_employer self-test FAIL: RETIRED';
    END IF;
    IF core.normalize_employer('self employed') IS DISTINCT FROM 'SELF-EMPLOYED' THEN
        RAISE EXCEPTION 'normalize_employer self-test FAIL: self employed';
    END IF;
    IF core.normalize_employer('none') IS NOT NULL THEN
        RAISE EXCEPTION 'normalize_employer self-test FAIL: none should be NULL';
    END IF;
    RAISE NOTICE 'normalize_employer self-test: all 4 cases passed';
END $$;

COMMIT;

-- =====================================================================
-- Post-DDL sanity check (read-only)
-- =====================================================================
SELECT
    column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'core' AND table_name = 'donor_profile'
  AND column_name IN (
      'employer_normalized','sic_code','sic_division','naics_code',
      'industry_sector','sic_match_method','sic_match_confidence',
      'home_matches_voter','address_class','business_street_line_1',
      'business_zip5','dark_donor_business_likely','bridge_version','bridge_built_at'
  )
ORDER BY column_name;
