-- =====================================================================
-- Stage 1 Donor Identity — DDL (additive only; no mutation of sacred)
-- =====================================================================
-- Target: Hetzner Postgres 37.27.169.232, schema `core`
-- Authorship: Nexus, 2026-04-18
-- Contract: This script creates tables only. It does NOT touch
--           raw.ncboe_donations or any existing row anywhere.
--           Safe to run without `I AUTHORIZE THIS ACTION`.
--
-- Tables created:
--   core.donor_profile          one row per cluster_id (real human rollup)
--   core.donor_profile_audit    every rebuild logged
--   core.donor_address_book     Broyhill family canonical address registry
--   core.person_canonical       stub for Stage 1b (name/identity)
--   core.person_alias           stub for Stage 1b (name variants)
--   core.donor_attribution      Layer-2 rollup (seeded later w/ authorization)
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- core.donor_profile : the unified per-cluster rollup table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.donor_profile (
    cluster_id                 INTEGER      PRIMARY KEY,

    -- Identity
    display_name               TEXT,
    norm_first                 TEXT,
    norm_middle                TEXT,
    norm_last                  TEXT,
    suffix                     TEXT,
    rnc_regid                  BIGINT,
    ncid                       TEXT,
    has_voter_match            BOOLEAN      NOT NULL DEFAULT FALSE,

    -- Donations (all sourced from the already-deduped spine)
    txn_count                  INTEGER      NOT NULL DEFAULT 0,
    lifetime_total             NUMERIC(14,2) NOT NULL DEFAULT 0,
    largest_gift               NUMERIC(14,2),
    first_gift_date            DATE,
    last_gift_date             DATE,

    -- Recipient surface
    committees_sboe_ids        TEXT[]       NOT NULL DEFAULT '{}',
    committee_count            INTEGER      NOT NULL DEFAULT 0,
    candidates_given_to        TEXT[]       NOT NULL DEFAULT '{}',
    candidate_count            INTEGER      NOT NULL DEFAULT 0,

    -- Contact (first-source-wins; already stamped on raw.ncboe_donations)
    cell_phone                 TEXT,
    home_phone                 TEXT,
    personal_email             TEXT,
    business_email             TEXT,

    -- Address (most-recent non-null)
    street_line_1              TEXT,
    street_line_2              TEXT,
    city                       TEXT,
    state                      TEXT,
    zip5                       TEXT,

    -- Employer / business
    employer                   TEXT,
    job_title                  TEXT,
    sic_code                   TEXT,

    -- Flags
    trump_rally_donor          BOOLEAN      NOT NULL DEFAULT FALSE,
    is_volunteer               BOOLEAN      NOT NULL DEFAULT FALSE,
    is_military                BOOLEAN      NOT NULL DEFAULT FALSE,

    -- Grade placeholder (filled later from Acxiom + donation history)
    grade                      TEXT,

    -- Audit
    profile_version            TEXT         NOT NULL DEFAULT 'v1.0',
    built_at                   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    source_spine_rowcount      INTEGER
);

CREATE INDEX IF NOT EXISTS idx_donor_profile_rnc_regid
    ON core.donor_profile (rnc_regid) WHERE rnc_regid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_donor_profile_last_first
    ON core.donor_profile (norm_last, norm_first);
CREATE INDEX IF NOT EXISTS idx_donor_profile_zip5
    ON core.donor_profile (zip5);
CREATE INDEX IF NOT EXISTS idx_donor_profile_total_desc
    ON core.donor_profile (lifetime_total DESC);

COMMENT ON TABLE core.donor_profile IS
'Stage 1 v1 unified donor rollup. One row per cluster_id from raw.ncboe_donations. Totals come from the already-deduped spine (321,348 rows / 98,303 clusters). Contact columns already passed the 17-source cascade with IS NULL guards on raw.';

-- ---------------------------------------------------------------------
-- core.donor_profile_audit : every rebuild logged
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.donor_profile_audit (
    id                  BIGSERIAL PRIMARY KEY,
    run_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    profile_version     TEXT,
    rows_before         INTEGER,
    rows_after          INTEGER,
    ed_canary_txns      INTEGER,
    ed_canary_total     NUMERIC(14,2),
    ed_canary_email     TEXT,
    notes               TEXT
);

COMMENT ON TABLE core.donor_profile_audit IS
'Every build/rebuild of core.donor_profile logs row counts + Ed canary here. If Ed canary deviates from 147 / 332631.30 / ed@broyhill.net the rebuild is rejected.';

-- ---------------------------------------------------------------------
-- core.donor_address_book : Broyhill family canonical addresses
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.donor_address_book (
    address_id         SERIAL PRIMARY KEY,
    label              TEXT UNIQUE NOT NULL,
    street_line_1      TEXT NOT NULL,
    city               TEXT NOT NULL,
    state              TEXT NOT NULL,
    zip5               TEXT NOT NULL,
    owner_cluster_id   INTEGER,
    notes              TEXT
);

COMMENT ON TABLE core.donor_address_book IS
'Canonical Broyhill family addresses per NEXUS_STARTUP_PREREQUISITE.md section 7. Do not modify without Ed.';

-- ---------------------------------------------------------------------
-- core.person_canonical + core.person_alias : stubs for Stage 1b
-- (created empty so later stages can populate without a new migration)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.person_canonical (
    person_id          BIGSERIAL PRIMARY KEY,
    display_name       TEXT NOT NULL,
    norm_first         TEXT,
    norm_middle        TEXT,
    norm_last          TEXT,
    suffix             TEXT,
    dob                DATE,
    rnc_regid          BIGINT,
    ncid               TEXT,
    primary_cluster_id INTEGER,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS core.person_alias (
    alias_id           BIGSERIAL PRIMARY KEY,
    person_id          BIGINT NOT NULL REFERENCES core.person_canonical(person_id),
    alias_text         TEXT NOT NULL,
    alias_kind         TEXT CHECK (alias_kind IN ('nickname','formal','initial','typo','pre_marriage','misspelling','other')),
    source             TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_person_alias_lookup
    ON core.person_alias (lower(alias_text));

-- ---------------------------------------------------------------------
-- core.donor_attribution : Layer-2 rollup (Ed Family Office etc.)
-- This table stays EMPTY until Ed types `I AUTHORIZE THIS ACTION` on
-- the seed DRY RUN. Creating the table is safe.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.donor_attribution (
    attribution_id     BIGSERIAL PRIMARY KEY,
    legal_donor_cluster INTEGER NOT NULL,     -- the cluster that actually wrote the check
    credited_to        TEXT    NOT NULL,      -- rollup label: 'ed_family_office', etc.
    weight             NUMERIC(5,4) NOT NULL DEFAULT 1.0 CHECK (weight >= 0 AND weight <= 1),
    reason             TEXT,
    authorized_by      TEXT NOT NULL,
    authorized_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_attr_legal_donor
    ON core.donor_attribution (legal_donor_cluster);
CREATE INDEX IF NOT EXISTS idx_attr_credited_to
    ON core.donor_attribution (credited_to);

COMMENT ON TABLE core.donor_attribution IS
'Layer-2 donor attribution per donor-attribution skill. legal_donor_cluster is immutable (matches NCSBE filing). credited_to is the family-office rollup label. Every row requires Ed authorization; authorized_by = ''ed.broyhill''.';

COMMIT;

-- =====================================================================
-- Post-create sanity check (read-only; run same session)
-- =====================================================================
SELECT 'core.donor_profile'         AS tbl, 0 AS rows WHERE NOT EXISTS (SELECT 1 FROM core.donor_profile)
UNION ALL SELECT 'core.donor_profile_audit', 0 WHERE NOT EXISTS (SELECT 1 FROM core.donor_profile_audit)
UNION ALL SELECT 'core.donor_address_book', 0 WHERE NOT EXISTS (SELECT 1 FROM core.donor_address_book)
UNION ALL SELECT 'core.person_canonical',    0 WHERE NOT EXISTS (SELECT 1 FROM core.person_canonical)
UNION ALL SELECT 'core.person_alias',        0 WHERE NOT EXISTS (SELECT 1 FROM core.person_alias)
UNION ALL SELECT 'core.donor_attribution',   0 WHERE NOT EXISTS (SELECT 1 FROM core.donor_attribution);
