-- =============================================================================
-- BroyhillGOP Hetzner Production Database — Platform Schema Migration
-- =============================================================================
-- Server: Hetzner (96 CPU, 251 GB RAM, 1.5 TB free disk)
-- Database: PostgreSQL
-- Generated: 2026-04-13
--
-- SCOPE: New tables, views, and supporting objects only.
--        This script does NOT alter, drop, or depend on existing tables:
--          raw.ncboe_donations
--          core.datatrust_voter_nc
--          core.acxiom_ap_models
--          core.acxiom_ibe
--          core.acxiom_consumer_nc
--          core.acxiom_market_indices
--          donor_intelligence.employer_sic_master
--
-- STRUCTURE:
--   Layer 0 — Extensions, schemas, shared trigger function
--   Layer 1 — Data tables (raw.fec_donations, donor_intelligence.*, pipeline.*)
--   Layer 2 — Brain / Event Bus (brain.*)
--   Layer 3 — Audit activity log (audit.activity_log, partitioned)
--   Layer 4 — Materialized views and full-text search
--   Verify  — Row count check of all newly created tables
--
-- SAFE TO RE-RUN: All CREATE statements use IF NOT EXISTS or are guarded.
-- =============================================================================


-- =============================================================================
-- LAYER 0: EXTENSIONS, SCHEMAS, AND SHARED FUNCTIONS
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 0.1  Extensions
-- ---------------------------------------------------------------------------

-- UUID generation (gen_random_uuid() requires pgcrypto or PG 13+ built-in)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- pgcrypto for gen_random_uuid() on older PG versions + digest() functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Trigram similarity for fuzzy name/employer matching
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- GIN support for btree-sortable composite indexes
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- ---------------------------------------------------------------------------
-- 0.2  Schemas (create any that may not yet exist)
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS donor_intelligence;
CREATE SCHEMA IF NOT EXISTS pipeline;
CREATE SCHEMA IF NOT EXISTS brain;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS norm;
CREATE SCHEMA IF NOT EXISTS archive;
CREATE SCHEMA IF NOT EXISTS volunteer;
CREATE SCHEMA IF NOT EXISTS public;

-- ---------------------------------------------------------------------------
-- 0.3  Shared trigger function: auto-update updated_at on row changes
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_timestamp() IS
  'Generic trigger function that sets updated_at = NOW() before any UPDATE. '
  'Attach with: CREATE TRIGGER trg_<table>_updated_at BEFORE UPDATE ON <table> '
  'FOR EACH ROW EXECUTE FUNCTION update_timestamp();';

COMMIT;


-- =============================================================================
-- LAYER 1: DATA TABLES
-- =============================================================================
-- Tables:
--   1. raw.fec_donations          — Federal FEC individual contribution records
--   2. donor_intelligence.person_master    — Golden record: one row per human
--   3. donor_intelligence.contribution_map — Links donations → person_master
--   4. donor_intelligence.committee_candidate_map — Committee → candidate map
--   5. pipeline.loaded_files      — Idempotency guard for all file ingestion
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1.1  raw.fec_donations
--      Federal election contribution records downloaded from FEC bulk data.
--      Mirrors the FEC individual contributions (indiv*.txt) file structure,
--      augmented with normalized/pipeline columns and matching results.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS raw.fec_donations (

    -- Primary key
    id                      BIGSERIAL       PRIMARY KEY,

    -- Source tracking
    source_file             TEXT            NOT NULL,

    -- -----------------------------------------------------------------------
    -- FEC standard columns (raw, as received from FEC bulk files)
    -- -----------------------------------------------------------------------
    cmte_id                 TEXT,           -- FEC committee ID (C00...)
    amndt_ind               TEXT,           -- Amendment indicator (N/A/T)
    rpt_tp                  TEXT,           -- Report type (Q1, M3, YE, etc.)
    transaction_pgi         TEXT,           -- Primary/general indicator (P/G/R/S/E/O)
    image_num               TEXT,           -- FEC image number
    transaction_tp          TEXT,           -- Transaction type code (15, 15E, etc.)
    entity_tp               TEXT,           -- Entity type (IND, ORG, PAC, PTY, CCM, CAN)

    -- Contributor (raw, as filed)
    name                    TEXT,           -- Full name as submitted to FEC
    city                    TEXT,
    state                   TEXT,
    zip_code                TEXT,           -- May be 5 or 9 digit
    employer                TEXT,
    occupation              TEXT,

    -- Parsed contributor name fields (from FEC structured data or name parser)
    contributor_last        TEXT,
    contributor_first       TEXT,
    contributor_middle      TEXT,
    contributor_prefix      TEXT,
    contributor_suffix      TEXT,

    -- Transaction details
    transaction_dt          DATE,           -- Transaction date (MMDDYYYY parsed to DATE)
    transaction_amt         NUMERIC(12,2),  -- Dollar amount
    other_id                TEXT,           -- Other committee ID if transfer
    tran_id                 TEXT,           -- FEC transaction ID (unique within filing)
    file_num                TEXT,           -- FEC filing number
    memo_cd                 TEXT,           -- X = memo entry (not itemized in total)
    memo_text               TEXT,
    sub_id                  TEXT,           -- FEC unique record identifier

    -- Committee enrichment (from FEC committee master file)
    cmte_nm                 TEXT,           -- Committee name
    cmte_tp                 TEXT,           -- Committee type (H, S, P, X, Y, Z, N, Q, I, O, U, V, W)
    cmte_pty_affiliation    TEXT,           -- Party affiliation (REP, DEM, etc.)

    -- Candidate enrichment (from FEC candidate master file)
    cand_id                 TEXT,           -- FEC candidate ID (P/H/S...)
    cand_name               TEXT,           -- Candidate name
    cand_pty_affiliation    TEXT,           -- Candidate party
    cand_office             TEXT,           -- P=President, S=Senate, H=House
    cand_office_st          TEXT,           -- State for House/Senate
    cand_office_district    TEXT,           -- District for House

    -- -----------------------------------------------------------------------
    -- Normalized pipeline columns (produced by norm/ schema ETL)
    -- -----------------------------------------------------------------------
    norm_last               TEXT,           -- Normalized last name (uppercase, cleaned)
    norm_first              TEXT,           -- Normalized first name
    norm_middle             TEXT,
    norm_zip5               TEXT,           -- 5-digit normalized ZIP
    norm_city               TEXT,           -- Normalized city name
    norm_employer           TEXT,           -- Normalized employer string
    norm_amount             NUMERIC(12,2),  -- Cleaned/validated amount
    address_number          TEXT,           -- Parsed street number for address matching

    -- -----------------------------------------------------------------------
    -- Dedup and voter-file matching
    -- -----------------------------------------------------------------------
    cluster_id              BIGINT,         -- Dedup cluster (parallel to ncboe cluster_id)
    rnc_regid               TEXT,           -- Matched RNC voter registration ID
    state_voter_id          TEXT,           -- Matched NC state voter ID (ncid)
    match_method            TEXT,           -- 'exact_name_zip', 'fuzzy_name_addr', 'rnc_key', etc.
    match_confidence        NUMERIC(5,4),   -- 0.0000 – 1.0000

    -- -----------------------------------------------------------------------
    -- Cycle / memo flags
    -- -----------------------------------------------------------------------
    election_cycle          TEXT,           -- e.g. '2023-2024', '2025-2026'
    is_memo                 BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Audit
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Indexes for raw.fec_donations
-- Name search (most common donor lookup pattern)
CREATE INDEX IF NOT EXISTS idx_fec_donations_name
    ON raw.fec_donations (norm_last, norm_first);

-- ZIP-code-only lookup
CREATE INDEX IF NOT EXISTS idx_fec_donations_zip
    ON raw.fec_donations (norm_zip5);

-- Address matching (number + zip)
CREATE INDEX IF NOT EXISTS idx_fec_donations_addr
    ON raw.fec_donations (address_number, norm_zip5);

-- Committee queries
CREATE INDEX IF NOT EXISTS idx_fec_donations_cmte
    ON raw.fec_donations (cmte_id);

-- Candidate queries
CREATE INDEX IF NOT EXISTS idx_fec_donations_cand
    ON raw.fec_donations (cand_id);

-- Voter file cross-reference
CREATE INDEX IF NOT EXISTS idx_fec_donations_rnc
    ON raw.fec_donations (rnc_regid);

-- Dedup cluster cross-reference
CREATE INDEX IF NOT EXISTS idx_fec_donations_cluster
    ON raw.fec_donations (cluster_id);

-- Ingestion / reload tracking
CREATE INDEX IF NOT EXISTS idx_fec_donations_source_file
    ON raw.fec_donations (source_file);

-- Date range queries and trending
CREATE INDEX IF NOT EXISTS idx_fec_donations_date
    ON raw.fec_donations (transaction_dt);

-- Employer network analysis
CREATE INDEX IF NOT EXISTS idx_fec_donations_employer
    ON raw.fec_donations (norm_employer);

-- Election cycle filtering
CREATE INDEX IF NOT EXISTS idx_fec_donations_cycle
    ON raw.fec_donations (election_cycle);

-- Combined name + ZIP (fastest donor identity lookup)
CREATE INDEX IF NOT EXISTS idx_fec_donations_name_zip
    ON raw.fec_donations (norm_last, norm_zip5);

COMMENT ON TABLE raw.fec_donations IS
  'Federal Election Commission individual contribution records. '
  'Loaded from FEC bulk files (indiv*.txt) via pipeline. '
  'Raw FEC columns are preserved verbatim; norm_* columns are produced by the '
  'normalization ETL in the norm/ schema. cluster_id / rnc_regid populated by '
  'the dedup/matching pipeline. Do NOT use is_memo=TRUE rows in financial totals.';

-- ---------------------------------------------------------------------------
-- 1.2  donor_intelligence.person_master
--      The single golden record for every human being in the platform.
--      Fuses: NC voter file (DataTrust), NCBOE donations, FEC donations,
--      Acxiom consumer/model data, volunteer records, and party data.
--      One row = one person.  All other tables reference person_id.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS donor_intelligence.person_master (

    -- Primary key
    person_id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- -----------------------------------------------------------------------
    -- Names
    -- -----------------------------------------------------------------------
    prefix                  TEXT,           -- Mr., Mrs., Dr., Hon., etc.
    first_name              TEXT            NOT NULL,
    middle_name             TEXT,
    last_name               TEXT            NOT NULL,
    suffix                  TEXT,           -- Jr., Sr., III, Esq., etc.
    preferred_name          TEXT,           -- Nickname / goes-by name
    full_legal_name         TEXT,           -- Computed or manually set full name
    formal_salutation       TEXT,           -- e.g. "Dear Senator Smith"

    -- -----------------------------------------------------------------------
    -- Address (primary physical address)
    -- -----------------------------------------------------------------------
    address_number          TEXT,           -- Parsed street number
    address_street          TEXT,           -- Street name + type (e.g. "OAK ST")
    address_full            TEXT,           -- Full street line (e.g. "123 OAK ST")
    address_line_2          TEXT,           -- Apt, Suite, Unit, etc.
    city                    TEXT,
    state                   TEXT            NOT NULL DEFAULT 'NC',
    zip5                    TEXT,
    zip4                    TEXT,
    county                  TEXT,

    -- -----------------------------------------------------------------------
    -- Contact
    -- -----------------------------------------------------------------------
    cell_phone              TEXT,
    cell_phone_source       TEXT,           -- 'datatrust', 'acxiom', 'manual', etc.
    home_phone              TEXT,
    email                   TEXT,
    email_source            TEXT,

    -- -----------------------------------------------------------------------
    -- Professional
    -- -----------------------------------------------------------------------
    employer                TEXT,
    occupation              TEXT,
    employer_sic_code       TEXT,           -- FK hint to donor_intelligence.employer_sic_master

    -- -----------------------------------------------------------------------
    -- Role flags — what universes/ecosystems this person participates in
    -- -----------------------------------------------------------------------
    is_donor                BOOLEAN         NOT NULL DEFAULT FALSE,
    is_candidate            BOOLEAN         NOT NULL DEFAULT FALSE,
    is_volunteer            BOOLEAN         NOT NULL DEFAULT FALSE,
    is_delegate             BOOLEAN         NOT NULL DEFAULT FALSE,
    is_elected_official     BOOLEAN         NOT NULL DEFAULT FALSE,
    is_party_official       BOOLEAN         NOT NULL DEFAULT FALSE,
    is_fec_donor            BOOLEAN         NOT NULL DEFAULT FALSE,
    is_ncboe_donor          BOOLEAN         NOT NULL DEFAULT FALSE,

    -- -----------------------------------------------------------------------
    -- Voter file link (DataTrust / NCSBE)
    -- -----------------------------------------------------------------------
    rnc_regid               TEXT,           -- RNC voter registration ID (unique per person)
    state_voter_id          TEXT,           -- NC state voter ID (ncid)
    voter_status            TEXT,           -- A=Active, I=Inactive, D=Denied, etc.
    registered_party        TEXT,           -- REP, DEM, UNA, LIB, GRE, etc.
    registration_date       DATE,
    birth_year              INTEGER,
    sex                     TEXT,           -- M, F, U

    -- -----------------------------------------------------------------------
    -- Household
    -- -----------------------------------------------------------------------
    household_id            TEXT,           -- Links members of the same household
    household_position      TEXT,           -- 'head', 'spouse', 'dependent', 'other'

    -- -----------------------------------------------------------------------
    -- DataTrust / Acxiom enrichment (modeled attributes)
    -- -----------------------------------------------------------------------
    modeled_income          TEXT,           -- Income bracket from DataTrust model
    modeled_education       TEXT,           -- Education level model
    modeled_ethnicity       TEXT,           -- Modeled ethnicity (for targeting compliance)
    republican_ballot_score INTEGER,        -- 0–100 GOP ballot propensity
    turnout_score           INTEGER,        -- 0–100 turnout propensity

    -- -----------------------------------------------------------------------
    -- Dedup / identity resolution
    -- -----------------------------------------------------------------------
    match_key               TEXT,           -- Canonical match key used during dedup
    name_variants           TEXT[],         -- Array of known name variations
    ncboe_cluster_id        BIGINT,         -- Links to raw.ncboe_donations.cluster_id
    fec_cluster_id          BIGINT,         -- Links to fec dedup cluster

    -- -----------------------------------------------------------------------
    -- Cached donation aggregates (refreshed by materialized view or trigger)
    -- -----------------------------------------------------------------------
    donations_total         NUMERIC(12,2)   NOT NULL DEFAULT 0,
    donations_ncboe         NUMERIC(12,2)   NOT NULL DEFAULT 0,
    donations_fec           NUMERIC(12,2)   NOT NULL DEFAULT 0,
    donation_count          INTEGER         NOT NULL DEFAULT 0,
    first_donation_date     DATE,
    last_donation_date      DATE,
    donation_years          INTEGER[],      -- Array of years in which a donation was made
    household_total         NUMERIC(12,2)   NOT NULL DEFAULT 0,

    -- -----------------------------------------------------------------------
    -- Scoring / grading
    -- -----------------------------------------------------------------------
    donor_grade             TEXT,           -- A+, A, B+, B, C, D, F, Prospect, etc.
    total_score             NUMERIC(6,2)    NOT NULL DEFAULT 0,

    -- -----------------------------------------------------------------------
    -- Free-form tagging
    -- -----------------------------------------------------------------------
    custom_tags             JSONB           NOT NULL DEFAULT '[]',

    -- -----------------------------------------------------------------------
    -- Source tracking
    -- -----------------------------------------------------------------------
    source_systems          TEXT[],         -- ['datatrust','ncboe','fec','acxiom', ...]
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Trigger: keep updated_at current on every row change
CREATE OR REPLACE TRIGGER trg_person_master_updated_at
    BEFORE UPDATE ON donor_intelligence.person_master
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- Indexes for donor_intelligence.person_master
-- Most-common search: name lookup
CREATE INDEX IF NOT EXISTS idx_pm_name
    ON donor_intelligence.person_master (last_name, first_name);

-- Dedup / matching pipeline lookup
CREATE INDEX IF NOT EXISTS idx_pm_match_key
    ON donor_intelligence.person_master (match_key);

-- Geographic filtering
CREATE INDEX IF NOT EXISTS idx_pm_zip5
    ON donor_intelligence.person_master (zip5);

-- Address matching (cross with fec/ncboe addr lookup)
CREATE INDEX IF NOT EXISTS idx_pm_addr
    ON donor_intelligence.person_master (address_number, zip5);

-- Voter file join — unique: one person_master per rnc_regid (when present)
CREATE UNIQUE INDEX IF NOT EXISTS uidx_pm_rnc_regid
    ON donor_intelligence.person_master (rnc_regid)
    WHERE rnc_regid IS NOT NULL;

-- NC state voter ID lookup
CREATE INDEX IF NOT EXISTS idx_pm_state_voter_id
    ON donor_intelligence.person_master (state_voter_id);

-- County-level reporting
CREATE INDEX IF NOT EXISTS idx_pm_county
    ON donor_intelligence.person_master (county);

-- Contact info lookups
CREATE INDEX IF NOT EXISTS idx_pm_cell_phone
    ON donor_intelligence.person_master (cell_phone);

CREATE INDEX IF NOT EXISTS idx_pm_email
    ON donor_intelligence.person_master (email);

-- Scoring / tiering queries
CREATE INDEX IF NOT EXISTS idx_pm_donor_grade
    ON donor_intelligence.person_master (donor_grade);

-- Household rollups
CREATE INDEX IF NOT EXISTS idx_pm_household_id
    ON donor_intelligence.person_master (household_id);

-- Dedup cluster cross-reference
CREATE INDEX IF NOT EXISTS idx_pm_ncboe_cluster
    ON donor_intelligence.person_master (ncboe_cluster_id);

CREATE INDEX IF NOT EXISTS idx_pm_fec_cluster
    ON donor_intelligence.person_master (fec_cluster_id);

-- Partial indexes: role-flag filtered subsets (avoids full-table scans for donor queries)
CREATE INDEX IF NOT EXISTS idx_pm_is_donor
    ON donor_intelligence.person_master (person_id)
    WHERE is_donor = TRUE;

CREATE INDEX IF NOT EXISTS idx_pm_is_candidate
    ON donor_intelligence.person_master (person_id)
    WHERE is_candidate = TRUE;

CREATE INDEX IF NOT EXISTS idx_pm_is_volunteer
    ON donor_intelligence.person_master (person_id)
    WHERE is_volunteer = TRUE;

CREATE INDEX IF NOT EXISTS idx_pm_is_fec_donor
    ON donor_intelligence.person_master (person_id)
    WHERE is_fec_donor = TRUE;

COMMENT ON TABLE donor_intelligence.person_master IS
  'Golden record: one row per human being in the platform. '
  'Fuses NC voter file (DataTrust), NCBOE donations, FEC donations, '
  'Acxiom consumer / model data, and volunteer / party data. '
  'All other tables that relate to a person MUST reference person_id. '
  'cached donation aggregates (donations_total etc.) are refreshed by '
  'mv_donation_summary or by the batch pipeline — treat as eventually consistent.';

-- ---------------------------------------------------------------------------
-- 1.3  donor_intelligence.contribution_map
--      Junction table: links every donation row (from any source system) to
--      exactly one person_master record.  The authoritative join table for
--      "all donations by this person".
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS donor_intelligence.contribution_map (

    id                      BIGSERIAL       PRIMARY KEY,

    -- Person this donation belongs to
    person_id               UUID            NOT NULL
                                REFERENCES donor_intelligence.person_master (person_id)
                                ON DELETE RESTRICT
                                ON UPDATE CASCADE,

    -- Source system and row pointer
    source_system           TEXT            NOT NULL
                                CHECK (source_system IN ('ncboe', 'fec')),
    source_row_id           BIGINT          NOT NULL,   -- id from raw.ncboe_donations or raw.fec_donations

    -- Cached donation fields (avoid joins for common display/aggregation)
    amount                  NUMERIC(12,2),
    donation_date           DATE,
    committee_id            TEXT,
    committee_name          TEXT,
    candidate_name          TEXT,

    -- Match quality
    match_method            TEXT,
    match_confidence        NUMERIC(5,4),

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- One donation row → one person_master link
    CONSTRAINT uq_contribution_map_source UNIQUE (source_system, source_row_id)

);

-- Indexes for contribution_map
CREATE INDEX IF NOT EXISTS idx_cmap_person_id
    ON donor_intelligence.contribution_map (person_id);

CREATE INDEX IF NOT EXISTS idx_cmap_source
    ON donor_intelligence.contribution_map (source_system, source_row_id);

CREATE INDEX IF NOT EXISTS idx_cmap_date
    ON donor_intelligence.contribution_map (donation_date);

CREATE INDEX IF NOT EXISTS idx_cmap_committee
    ON donor_intelligence.contribution_map (committee_id);

COMMENT ON TABLE donor_intelligence.contribution_map IS
  'Junction table linking every donation record (from raw.ncboe_donations or '
  'raw.fec_donations) to a donor_intelligence.person_master record. '
  'source_row_id is the integer PK of the raw table row. '
  'UNIQUE (source_system, source_row_id) enforces one-link-per-donation-row.';

-- ---------------------------------------------------------------------------
-- 1.4  donor_intelligence.committee_candidate_map
--      Maps committee IDs (FEC or NCBOE) to their associated candidate in
--      person_master.  Used to annotate donations with candidate context and
--      for candidate-level reporting.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS donor_intelligence.committee_candidate_map (

    id                      BIGSERIAL       PRIMARY KEY,

    -- Committee identity
    committee_id            TEXT            NOT NULL,
    committee_name          TEXT,
    committee_type          TEXT,           -- 'Principal', 'PAC', 'Party', 'JFC'
    committee_source        TEXT            NOT NULL
                                CHECK (committee_source IN ('fec', 'ncboe')),

    -- Linked candidate (optional — not all committees have a single candidate)
    candidate_person_id     UUID
                                REFERENCES donor_intelligence.person_master (person_id)
                                ON DELETE SET NULL
                                ON UPDATE CASCADE,
    candidate_name          TEXT,
    fec_candidate_id        TEXT,           -- FEC cand_id (P/H/S + digits)

    -- Office context
    office_type             TEXT,           -- 'President', 'Senate', 'House', 'Governor', etc.
    office_state            TEXT,
    office_district         TEXT,
    party                   TEXT,
    election_year           INTEGER,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Functional unique index: one committee record per source per election year
-- Uses COALESCE to treat NULL election_year as 0 for uniqueness purposes
CREATE UNIQUE INDEX IF NOT EXISTS uidx_committee_map
    ON donor_intelligence.committee_candidate_map (
        committee_id, committee_source, COALESCE(election_year, 0)
    );

-- Indexes for committee_candidate_map
CREATE INDEX IF NOT EXISTS idx_ccmap_committee_id
    ON donor_intelligence.committee_candidate_map (committee_id);

CREATE INDEX IF NOT EXISTS idx_ccmap_candidate_pid
    ON donor_intelligence.committee_candidate_map (candidate_person_id);

CREATE INDEX IF NOT EXISTS idx_ccmap_fec_cand
    ON donor_intelligence.committee_candidate_map (fec_candidate_id);

COMMENT ON TABLE donor_intelligence.committee_candidate_map IS
  'Maps committee IDs from FEC and NCBOE to their associated candidate record '
  'in person_master. Used for candidate-level donation reporting and Brain trigger '
  'context. election_year=NULL means the record applies to all cycles.';

-- ---------------------------------------------------------------------------
-- 1.5  pipeline.loaded_files
--      Idempotency guard.  Every ingestion pipeline checks this table before
--      processing a file.  If (file_hash, file_source) already exists with
--      status=''complete'', the file is skipped.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pipeline.loaded_files (

    id                      SERIAL          PRIMARY KEY,

    -- File identity
    file_name               TEXT            NOT NULL,
    file_hash               TEXT            NOT NULL,   -- SHA-256 of file contents
    file_source             TEXT            NOT NULL
                                CHECK (file_source IN (
                                    'ncboe_gold',
                                    'fec_individual',
                                    'fec_committee',
                                    'fec_candidate',
                                    'datatrust',
                                    'acxiom'
                                )),

    -- Load results
    row_count               INTEGER,        -- Total rows in file
    net_row_count           INTEGER,        -- Rows actually inserted (after dedup)
    loaded_at               TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    loaded_by               TEXT            NOT NULL DEFAULT 'system',
    status                  TEXT            NOT NULL DEFAULT 'complete',
    notes                   TEXT,

    -- Idempotency constraint
    CONSTRAINT uq_loaded_files UNIQUE (file_hash, file_source)

);

COMMENT ON TABLE pipeline.loaded_files IS
  'Idempotency guard for all file ingestion pipelines. '
  'Before loading a file, compute its SHA-256 hash and check for an existing '
  'row with (file_hash, file_source). If found with status=''complete'', skip. '
  'Insert a row with status=''loading'' before starting, update to ''complete'' or '
  '''failed'' when done. Supports safe re-runs and duplicate detection.';

COMMIT;


-- =============================================================================
-- LAYER 2: BRAIN / EVENT BUS
-- =============================================================================
-- Central intelligence layer shared across all universes and ecosystems.
-- Tables:
--   6.  brain.event_queue      — Central event bus (partitioned by created_at)
--   7.  brain.decisions        — GO/NO-GO decisions produced by the Brain
--   8.  brain.triggers         — 905+ trigger definitions
--   9.  brain.contact_fatigue  — Per-contact per-channel contact limits
--   10. brain.budgets          — Per-candidate per-channel budget tracking
--   11. brain.learning         — ML/RL feedback loop signal store
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 6.  brain.event_queue  (PARTITIONED BY RANGE on created_at — monthly)
--     Central event bus. Every ecosystem writes events here; the Brain
--     processor reads them, evaluates triggers, and writes decisions.
--     Partitioning keeps query times fast as volume grows.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brain.event_queue (

    event_id                UUID            NOT NULL DEFAULT gen_random_uuid(),

    -- Event classification
    event_type              TEXT            NOT NULL,   -- e.g. 'donation.received', 'news.candidate_mentioned'
    source_universe         TEXT,                       -- e.g. 'donor_intelligence', 'field_ops'
    source_ecosystem        TEXT,                       -- e.g. 'E42', 'E30', 'E01'

    -- Entity this event concerns
    entity_type             TEXT,                       -- 'person', 'candidate', 'campaign', 'committee'
    entity_id               TEXT,                       -- UUID or natural key of the entity

    -- Payload
    event_data              JSONB           NOT NULL DEFAULT '{}',

    -- Processing control
    priority                INTEGER         NOT NULL DEFAULT 50
                                CHECK (priority BETWEEN 1 AND 100),
    status                  TEXT            NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','processing','completed','failed','expired')),
    attempts                INTEGER         NOT NULL DEFAULT 0,
    max_attempts            INTEGER         NOT NULL DEFAULT 3,
    scheduled_for           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    processed_at            TIMESTAMPTZ,
    error_message           TEXT,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (event_id, created_at)  -- Partition key must be in PK for declarative partitioning

) PARTITION BY RANGE (created_at);

-- Monthly partitions: April 2026 – July 2026
CREATE TABLE IF NOT EXISTS brain.event_queue_2026_04
    PARTITION OF brain.event_queue
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE IF NOT EXISTS brain.event_queue_2026_05
    PARTITION OF brain.event_queue
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE IF NOT EXISTS brain.event_queue_2026_06
    PARTITION OF brain.event_queue
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE IF NOT EXISTS brain.event_queue_2026_07
    PARTITION OF brain.event_queue
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

-- Indexes on the partitioned parent (PostgreSQL propagates to partitions)
-- Primary work queue: pull pending events in priority + schedule order
CREATE INDEX IF NOT EXISTS idx_eq_pending
    ON brain.event_queue (scheduled_for, priority DESC)
    WHERE status = 'pending';

-- Entity-level event history
CREATE INDEX IF NOT EXISTS idx_eq_entity
    ON brain.event_queue (entity_type, entity_id);

-- Universe-level monitoring / replay
CREATE INDEX IF NOT EXISTS idx_eq_universe
    ON brain.event_queue (source_universe);

-- Event type filtering (trigger matching)
CREATE INDEX IF NOT EXISTS idx_eq_type
    ON brain.event_queue (event_type);

-- Time-series / TTL queries
CREATE INDEX IF NOT EXISTS idx_eq_created_at
    ON brain.event_queue (created_at);

COMMENT ON TABLE brain.event_queue IS
  'Central event bus shared across all universes and ecosystems. '
  'Producers write events; the Brain processor polls pending rows in '
  '(scheduled_for, priority DESC) order, evaluates brain.triggers, and '
  'writes results to brain.decisions. '
  'Partitioned monthly — add a new partition before the end of each month. '
  'Completed/expired events should be archived (moved to archive schema) '
  'rather than deleted, for audit trail integrity.';

-- ---------------------------------------------------------------------------
-- 7.  brain.decisions
--     Every GO/NO-GO decision the Brain makes in response to an event.
--     Stores the full execution plan, channels selected, budget allocated,
--     and post-execution result metrics for the learning feedback loop.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brain.decisions (

    decision_id             UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Context
    trigger_name            TEXT,           -- Name of the brain.triggers row that fired
    event_id                UUID,           -- FK hint to brain.event_queue.event_id (not enforced across partition)
    candidate_id            UUID,           -- person_master.person_id of the candidate context
    campaign_id             UUID,           -- future campaigns table

    -- Input classification
    event_type              TEXT,           -- Mirrors event_queue.event_type for fast filtering

    -- Decision output
    decision                TEXT            NOT NULL
                                CHECK (decision IN ('go', 'no_go', 'review', 'defer')),
    score                   INTEGER,        -- 0–100 overall signal score
    score_breakdown         JSONB           NOT NULL DEFAULT '{}',   -- per-factor scores

    -- Execution plan
    channels_selected       TEXT[],         -- e.g. ['email', 'sms', 'direct_mail']
    targets_count           INTEGER         NOT NULL DEFAULT 0,
    budget_allocated        NUMERIC(12,2)   NOT NULL DEFAULT 0,
    execution_plan          JSONB           NOT NULL DEFAULT '{}',   -- full plan blob

    -- Execution state
    executed                BOOLEAN         NOT NULL DEFAULT FALSE,
    executed_at             TIMESTAMPTZ,
    result_metrics          JSONB           NOT NULL DEFAULT '{}',   -- opens, clicks, conversions, revenue

    -- Performance
    processing_ms           INTEGER,        -- Time taken to produce this decision

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Indexes for brain.decisions
CREATE INDEX IF NOT EXISTS idx_decisions_event
    ON brain.decisions (event_id);

CREATE INDEX IF NOT EXISTS idx_decisions_candidate
    ON brain.decisions (candidate_id);

CREATE INDEX IF NOT EXISTS idx_decisions_decision
    ON brain.decisions (decision);

CREATE INDEX IF NOT EXISTS idx_decisions_created
    ON brain.decisions (created_at);

COMMENT ON TABLE brain.decisions IS
  'Every GO/NO-GO decision produced by the Brain in response to an event. '
  'execution_plan JSONB contains the full channel/message/timing plan. '
  'result_metrics is populated after execution by the reporting pipeline, '
  'then read by brain.learning for the ML feedback loop.';

-- ---------------------------------------------------------------------------
-- 8.  brain.triggers
--     Declarative trigger definitions.  The Brain processor evaluates each
--     active trigger against incoming events and fires matching ones.
--     Supports 905+ triggers across all universes.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brain.triggers (

    trigger_id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    name                    TEXT            UNIQUE NOT NULL,
    category                TEXT            NOT NULL,   -- e.g. 'donation', 'news', 'engagement', 'field'
    description             TEXT,
    universe                TEXT,           -- Which universe owns / primarily uses this trigger

    -- Logic (evaluated by the Brain processor)
    conditions              JSONB           NOT NULL DEFAULT '{}',  -- condition tree
    actions                 JSONB           NOT NULL DEFAULT '[]',  -- action list

    -- Control
    priority                INTEGER         NOT NULL DEFAULT 50,    -- 1 (highest) – 100 (lowest)
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    cooldown_minutes        INTEGER         NOT NULL DEFAULT 60,    -- Minimum minutes between fires for same entity

    -- Runtime stats
    last_fired              TIMESTAMPTZ,
    fire_count              BIGINT          NOT NULL DEFAULT 0,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Indexes for brain.triggers
CREATE INDEX IF NOT EXISTS idx_triggers_category
    ON brain.triggers (category);

CREATE INDEX IF NOT EXISTS idx_triggers_active_cat
    ON brain.triggers (is_active, category);

COMMENT ON TABLE brain.triggers IS
  'Declarative trigger definitions evaluated by the Brain processor. '
  'conditions is a JSON logic tree (e.g. {"and": [{">=": ["$.score", 75]}, ...]}) '
  'evaluated against event_data + entity context. '
  'actions is an ordered list of action objects ({type, params}). '
  'cooldown_minutes prevents the same trigger from firing again for the same '
  'entity within the cooldown window.';

-- ---------------------------------------------------------------------------
-- 9.  brain.contact_fatigue
--     Prevents donor and contact burnout by tracking contact frequency.
--     One row per (contact_id, channel).  Updated by every send action.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brain.contact_fatigue (

    contact_id              UUID            NOT NULL,   -- person_master.person_id
    channel                 TEXT            NOT NULL,   -- 'email', 'sms', 'direct_mail', 'phone', 'push'

    -- Recency
    last_contact            TIMESTAMPTZ     NOT NULL,

    -- Rolling frequency counters (reset by scheduled job)
    contacts_today          INTEGER         NOT NULL DEFAULT 1,
    contacts_this_week      INTEGER         NOT NULL DEFAULT 1,
    contacts_this_month     INTEGER         NOT NULL DEFAULT 1,
    total_contacts          BIGINT          NOT NULL DEFAULT 1,

    -- Computed burnout signal (0=fresh, 100=burned out)
    fatigue_score           NUMERIC(5,2)    NOT NULL DEFAULT 0,

    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (contact_id, channel)

);

-- Additional index: look up all channels for a single contact
CREATE INDEX IF NOT EXISTS idx_fatigue_contact
    ON brain.contact_fatigue (contact_id);

COMMENT ON TABLE brain.contact_fatigue IS
  'Tracks contact frequency per person per channel to prevent donor burnout. '
  'Brain trigger evaluation checks this table before selecting a channel. '
  'contacts_today / contacts_this_week / contacts_this_month are reset by a '
  'scheduled cron job (e.g. midnight / Monday 00:00 / 1st of month). '
  'fatigue_score is computed as a weighted function of the rolling counters.';

-- ---------------------------------------------------------------------------
-- 10. brain.budgets
--     Per-candidate per-channel budget tracking with daily/weekly/monthly
--     spend limits.  Updated by the execution pipeline on every send.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brain.budgets (

    budget_id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Scope
    candidate_id            UUID,           -- person_master.person_id of the candidate
    campaign_id             UUID,           -- future campaigns table
    channel                 TEXT,           -- 'email', 'sms', 'direct_mail', 'digital_ads', etc.

    -- Budget limits
    daily_budget            NUMERIC(12,2),
    weekly_budget           NUMERIC(12,2),
    monthly_budget          NUMERIC(12,2),

    -- Running spend
    daily_spent             NUMERIC(12,2)   NOT NULL DEFAULT 0,
    weekly_spent            NUMERIC(12,2)   NOT NULL DEFAULT 0,
    monthly_spent           NUMERIC(12,2)   NOT NULL DEFAULT 0,

    -- Reset tracking (used by the spend-reset cron job)
    last_reset              DATE            NOT NULL DEFAULT CURRENT_DATE,

    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Indexes for brain.budgets
CREATE INDEX IF NOT EXISTS idx_budgets_campaign
    ON brain.budgets (campaign_id);

CREATE INDEX IF NOT EXISTS idx_budgets_candidate
    ON brain.budgets (candidate_id);

COMMENT ON TABLE brain.budgets IS
  'Per-candidate per-channel daily/weekly/monthly budget tracking. '
  'Brain decisions check available budget before committing to a channel. '
  'daily_spent / weekly_spent / monthly_spent are incremented by the execution '
  'pipeline and reset by a scheduled cron job. last_reset tracks when the '
  'most recent reset occurred.';

-- ---------------------------------------------------------------------------
-- 11. brain.learning
--     Aggregated ML/RL feedback signal store.  The reporting pipeline
--     populates this from brain.decisions.result_metrics.  Used by the
--     Brain to tune trigger thresholds and channel selection over time.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brain.learning (

    learning_id             UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Segment dimensions
    trigger_category        TEXT,           -- Matches brain.triggers.category
    channel                 TEXT,
    donor_segment           TEXT,           -- e.g. 'major_donor', 'lapsed', 'prospect'
    content_type            TEXT,           -- 'fundraising_ask', 'event_invite', 'news', etc.

    -- Volume metrics
    sends                   BIGINT          NOT NULL DEFAULT 0,
    opens                   BIGINT          NOT NULL DEFAULT 0,
    clicks                  BIGINT          NOT NULL DEFAULT 0,
    conversions             BIGINT          NOT NULL DEFAULT 0,

    -- Financial metrics
    revenue                 NUMERIC(14,2)   NOT NULL DEFAULT 0,
    avg_roi                 NUMERIC(10,4),  -- revenue / cost

    -- Model confidence in these estimates
    confidence_score        NUMERIC(5,2),   -- 0–100, grows with sample size

    last_updated            TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Composite index for Brain lookup by segment
CREATE INDEX IF NOT EXISTS idx_learning_segment
    ON brain.learning (trigger_category, channel, donor_segment);

COMMENT ON TABLE brain.learning IS
  'Aggregated ML/RL feedback signal store. Each row represents cumulative '
  'performance for a (trigger_category, channel, donor_segment, content_type) '
  'combination. The Brain uses these metrics to rank channel selection and '
  'tune trigger thresholds over time. Updated by the reporting pipeline '
  'after each execution cycle.';

COMMIT;


-- =============================================================================
-- LAYER 3: AUDIT / ACTIVITY LOG
-- =============================================================================
-- Table:
--   12. audit.activity_log  — Unified audit trail for every action across all
--                             universes and ecosystems (partitioned monthly)
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 12. audit.activity_log  (PARTITIONED BY RANGE on created_at — monthly)
--     Immutable record of every significant action in the platform:
--     emails sent, SMS sent, calls made, donations received, profile views,
--     grade changes, data matches, event creations, etc.
--     Partitioned for query performance and future archival TTL.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit.activity_log (

    id                      BIGSERIAL       NOT NULL,

    -- Action classification
    action_type             TEXT            NOT NULL,
        -- e.g. 'email_sent', 'sms_sent', 'call_made', 'letter_mailed',
        --      'donation_received', 'profile_viewed', 'grade_changed',
        --      'match_created', 'news_published', 'event_created'

    -- Universe / ecosystem context
    universe                TEXT,           -- e.g. 'donor_intelligence', 'field_ops'
    ecosystem               TEXT,           -- e.g. 'E42', 'E30'

    -- Who performed the action
    actor_type              TEXT,           -- 'system', 'ai', 'user', 'candidate', 'volunteer'
    actor_id                TEXT,           -- UUID or username of actor

    -- What the action was performed on
    entity_type             TEXT,           -- 'person', 'campaign', 'committee', 'donation'
    entity_id               TEXT,           -- UUID or natural key of entity

    -- Convenience link to person_master (denormalized for common queries)
    person_id               UUID,           -- person_master.person_id (if action relates to a person)

    -- Full action payload
    details                 JSONB           NOT NULL DEFAULT '{}',

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id, created_at)    -- Partition key must be in PK

) PARTITION BY RANGE (created_at);

-- Monthly partitions: April 2026 – July 2026
CREATE TABLE IF NOT EXISTS audit.activity_log_2026_04
    PARTITION OF audit.activity_log
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE IF NOT EXISTS audit.activity_log_2026_05
    PARTITION OF audit.activity_log
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE IF NOT EXISTS audit.activity_log_2026_06
    PARTITION OF audit.activity_log
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE IF NOT EXISTS audit.activity_log_2026_07
    PARTITION OF audit.activity_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

-- Indexes on the partitioned parent
-- Entity history: "show me everything that happened to this person / campaign"
CREATE INDEX IF NOT EXISTS idx_alog_entity
    ON audit.activity_log (entity_type, entity_id);

-- Person-specific timeline (most common display query)
CREATE INDEX IF NOT EXISTS idx_alog_person
    ON audit.activity_log (person_id);

-- Action type filtering for compliance / reporting
CREATE INDEX IF NOT EXISTS idx_alog_action_type
    ON audit.activity_log (action_type);

-- Chronological range queries
CREATE INDEX IF NOT EXISTS idx_alog_created
    ON audit.activity_log (created_at);

-- Universe-level monitoring
CREATE INDEX IF NOT EXISTS idx_alog_universe
    ON audit.activity_log (universe);

COMMENT ON TABLE audit.activity_log IS
  'Immutable unified audit trail for every significant platform action. '
  'Written to by all universes and ecosystems. NEVER UPDATE or DELETE rows; '
  'use a separate archival process to move old partitions to the archive schema. '
  'Partitioned monthly — create the next month''s partition before month-end. '
  'details JSONB stores action-specific payload (e.g. subject line for email_sent, '
  'amount for donation_received).';

COMMIT;


-- =============================================================================
-- LAYER 4: SEARCH / PROFILE VIEWS
-- =============================================================================
-- Objects:
--   13. donor_intelligence.mv_donor_profile    — Pre-computed donor profile
--   14. donor_intelligence.mv_donation_summary — Per-person donation rollup
--   15. Full-text search GIN index on person_master
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 15. Full-text search support on person_master
--     GIN index over name + preferred_name + employer text vector.
--     Enables: WHERE to_tsvector(...) @@ plainto_tsquery('John Smith MD')
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_pm_fulltext
    ON donor_intelligence.person_master
    USING GIN (
        to_tsvector(
            'english',
            COALESCE(first_name,    '') || ' ' ||
            COALESCE(last_name,     '') || ' ' ||
            COALESCE(preferred_name,'') || ' ' ||
            COALESCE(employer,      '')
        )
    );

-- Trigram index for ILIKE / fuzzy partial-name search
CREATE INDEX IF NOT EXISTS idx_pm_last_trgm
    ON donor_intelligence.person_master
    USING GIN (last_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_pm_first_trgm
    ON donor_intelligence.person_master
    USING GIN (first_name gin_trgm_ops);

COMMIT;

-- ---------------------------------------------------------------------------
-- 13. donor_intelligence.mv_donor_profile
--     Materialized view: fully assembled donor profile for the 3,000-
--     concurrent-user search UI.  Refreshed CONCURRENTLY after batch
--     pipeline runs or on a scheduled basis (e.g. nightly).
--
--     Depends on:
--       donor_intelligence.person_master        (new table — Layer 1)
--       raw.ncboe_donations                     (existing table — NOT touched)
--       core.datatrust_voter_nc                 (existing table — NOT touched)
--       audit.activity_log                      (new table — Layer 3)
--
--     NOTE: This view is created without data (WITH NO DATA) so the migration
--     can run even before the referenced existing tables have data.
--     Run: REFRESH MATERIALIZED VIEW CONCURRENTLY donor_intelligence.mv_donor_profile;
-- ---------------------------------------------------------------------------

CREATE MATERIALIZED VIEW IF NOT EXISTS donor_intelligence.mv_donor_profile AS
SELECT
    -- All person_master columns
    pm.person_id,
    pm.prefix,
    pm.first_name,
    pm.middle_name,
    pm.last_name,
    pm.suffix,
    pm.preferred_name,
    pm.full_legal_name,
    pm.formal_salutation,
    pm.address_number,
    pm.address_street,
    pm.address_full,
    pm.address_line_2,
    pm.city,
    pm.state,
    pm.zip5,
    pm.zip4,
    pm.county,
    pm.cell_phone,
    pm.cell_phone_source,
    pm.home_phone,
    pm.email,
    pm.email_source,
    pm.employer,
    pm.occupation,
    pm.employer_sic_code,
    pm.is_donor,
    pm.is_candidate,
    pm.is_volunteer,
    pm.is_delegate,
    pm.is_elected_official,
    pm.is_party_official,
    pm.is_fec_donor,
    pm.is_ncboe_donor,
    pm.rnc_regid,
    pm.state_voter_id,
    pm.voter_status,
    pm.registered_party,
    pm.registration_date,
    pm.birth_year,
    pm.sex,
    pm.household_id,
    pm.household_position,
    pm.modeled_income,
    pm.modeled_education,
    pm.modeled_ethnicity,
    pm.republican_ballot_score,
    pm.turnout_score,
    pm.match_key,
    pm.name_variants,
    pm.ncboe_cluster_id,
    pm.fec_cluster_id,
    pm.donations_total,
    pm.donations_ncboe,
    pm.donations_fec,
    pm.donation_count,
    pm.first_donation_date,
    pm.last_donation_date,
    pm.donation_years,
    pm.household_total,
    pm.donor_grade,
    pm.total_score,
    pm.custom_tags,
    pm.source_systems,
    pm.created_at,
    pm.updated_at,

    -- NCBOE cluster aggregates (from cluster_profile JSONB on the canonical cluster row)
    cp.cluster_profile->>'n_rows'               AS ncboe_row_count,
    cp.cluster_profile->>'total_amount'         AS ncboe_total,
    cp.cluster_profile->'employers'             AS ncboe_employers,
    cp.cluster_profile->'committees'            AS ncboe_committees,
    cp.cluster_profile->>'year_min'             AS first_ncboe_year,
    cp.cluster_profile->>'year_max'             AS last_ncboe_year,
    cp.cluster_profile->>'household_total'      AS ncboe_household_total,
    cp.cluster_profile->>'household_n_clusters' AS household_members,

    -- Voter file key fields (live join to existing table)
    dv.registered_party                         AS registered_party_current,
    dv.voter_status                             AS dt_voter_status,
    dv.ethnicity_reported                       AS dt_ethnicity_reported,
    dv.ethnic_group_modeled                      AS dt_ethnic_group_modeled,
    dv.sex                                       AS dt_sex,
    dv.birth_year                               AS voter_birth_year,

    -- Rolling 90-day activity count from audit log
    (
        SELECT COUNT(*)
        FROM audit.activity_log al
        WHERE al.person_id = pm.person_id
          AND al.created_at > NOW() - INTERVAL '90 days'
    )                                           AS recent_activity_count

FROM donor_intelligence.person_master pm

-- NCBOE cluster profile — lateral fetch of one row per cluster_id
LEFT JOIN LATERAL (
    SELECT cluster_profile
    FROM raw.ncboe_donations
    WHERE cluster_id = pm.ncboe_cluster_id
    LIMIT 1
) cp ON TRUE

-- DataTrust voter file join
LEFT JOIN core.datatrust_voter_nc dv
    ON dv.rnc_regid = pm.rnc_regid

WHERE pm.is_donor = TRUE

WITH NO DATA;

-- Unique index required for CONCURRENT refresh
CREATE UNIQUE INDEX IF NOT EXISTS uidx_mvdp_person_id
    ON donor_intelligence.mv_donor_profile (person_id);

-- Search/filter indexes on materialized view
CREATE INDEX IF NOT EXISTS idx_mvdp_name
    ON donor_intelligence.mv_donor_profile (last_name, first_name);

CREATE INDEX IF NOT EXISTS idx_mvdp_zip5
    ON donor_intelligence.mv_donor_profile (zip5);

CREATE INDEX IF NOT EXISTS idx_mvdp_county
    ON donor_intelligence.mv_donor_profile (county);

CREATE INDEX IF NOT EXISTS idx_mvdp_grade
    ON donor_intelligence.mv_donor_profile (donor_grade);

CREATE INDEX IF NOT EXISTS idx_mvdp_household
    ON donor_intelligence.mv_donor_profile (household_id);

CREATE INDEX IF NOT EXISTS idx_mvdp_rnc
    ON donor_intelligence.mv_donor_profile (rnc_regid);

COMMENT ON MATERIALIZED VIEW donor_intelligence.mv_donor_profile IS
  'Pre-computed donor profile view for the donor search UI (3,000 concurrent users). '
  'Fuses person_master, NCBOE cluster_profile JSONB, DataTrust voter file fields '
  '(registered_party, voter_status, ethnicity_reported, ethnic_group_modeled, sex, birth_year), '
  'and 90-day audit activity count. '
  'Refresh: REFRESH MATERIALIZED VIEW CONCURRENTLY donor_intelligence.mv_donor_profile; '
  'Schedule: nightly + after each major batch pipeline run. '
  'Created WITH NO DATA — run REFRESH before first use.';

-- ---------------------------------------------------------------------------
-- 14. donor_intelligence.mv_donation_summary
--     Per-person donation rollup across both NCBOE and FEC sources.
--     Used to update cached aggregate columns on person_master and to
--     drive the donor grading / scoring pipeline.
-- ---------------------------------------------------------------------------

CREATE MATERIALIZED VIEW IF NOT EXISTS donor_intelligence.mv_donation_summary AS
SELECT
    cm.person_id,
    COUNT(*)                                                            AS total_donations,
    SUM(cm.amount)                                                      AS total_amount,
    SUM(cm.amount)  FILTER (WHERE cm.source_system = 'ncboe')          AS ncboe_total,
    SUM(cm.amount)  FILTER (WHERE cm.source_system = 'fec')            AS fec_total,
    COUNT(*)        FILTER (WHERE cm.source_system = 'ncboe')          AS ncboe_count,
    COUNT(*)        FILTER (WHERE cm.source_system = 'fec')            AS fec_count,
    MIN(cm.donation_date)                                               AS first_donation,
    MAX(cm.donation_date)                                               AS last_donation,
    COUNT(DISTINCT cm.committee_id)                                     AS unique_committees,
    COUNT(DISTINCT EXTRACT(YEAR FROM cm.donation_date))                 AS active_years,
    array_agg(
        DISTINCT EXTRACT(YEAR FROM cm.donation_date)::INT
        ORDER BY EXTRACT(YEAR FROM cm.donation_date)::INT
    )                                                                   AS donation_years

FROM donor_intelligence.contribution_map cm

GROUP BY cm.person_id

WITH NO DATA;

-- Unique index required for CONCURRENT refresh
CREATE UNIQUE INDEX IF NOT EXISTS uidx_mvds_person_id
    ON donor_intelligence.mv_donation_summary (person_id);

COMMENT ON MATERIALIZED VIEW donor_intelligence.mv_donation_summary IS
  'Per-person donation rollup across NCBOE and FEC sources. '
  'Drives the batch that refreshes cached aggregate columns on person_master '
  '(donations_total, donation_count, first_donation_date, etc.) and the '
  'donor grading / scoring pipeline. '
  'Refresh: REFRESH MATERIALIZED VIEW CONCURRENTLY donor_intelligence.mv_donation_summary; '
  'Created WITH NO DATA — run REFRESH before first use.';


-- =============================================================================
-- VERIFICATION BLOCK
-- Count every new table/view created by this migration.
-- Run after psql applies the file: confirms all objects exist.
-- =============================================================================

DO $$
DECLARE
    v_table_count   INTEGER;
    v_view_count    INTEGER;
    v_index_count   INTEGER;
BEGIN
    -- Count new BASE tables (excludes partition children, existing tables)
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.tables t
    WHERE t.table_schema IN ('raw','donor_intelligence','pipeline','brain','audit')
      AND t.table_type = 'BASE TABLE'
      AND t.table_name IN (
          'fec_donations',
          'person_master',
          'contribution_map',
          'committee_candidate_map',
          'loaded_files',
          'event_queue',
          'decisions',
          'triggers',
          'contact_fatigue',
          'budgets',
          'learning',
          'activity_log'
      );

    -- Count materialized views
    SELECT COUNT(*) INTO v_view_count
    FROM pg_matviews
    WHERE schemaname = 'donor_intelligence'
      AND matviewname IN ('mv_donor_profile','mv_donation_summary');

    -- Count indexes created by this migration (sample check)
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname IN ('raw','donor_intelligence','pipeline','brain','audit')
      AND (indexname LIKE 'idx_%' OR indexname LIKE 'uidx_%');

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'BroyhillGOP Platform Schema Migration — VERIFY';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'New base tables found     : % / 12 expected', v_table_count;
    RAISE NOTICE 'Materialized views found  : % / 2  expected', v_view_count;
    RAISE NOTICE 'Indexes found (idx/uidx)  : %',               v_index_count;

    IF v_table_count < 12 THEN
        RAISE WARNING 'Expected 12 new tables; only % found. Check error output above.', v_table_count;
    ELSE
        RAISE NOTICE 'All 12 new tables confirmed.';
    END IF;

    IF v_view_count < 2 THEN
        RAISE WARNING 'Expected 2 materialized views; only % found.', v_view_count;
    ELSE
        RAISE NOTICE 'Both materialized views confirmed.';
    END IF;

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'IMPORTANT: Materialized views were created WITH NO DATA.';
    RAISE NOTICE 'Run the following to populate them before first use:';
    RAISE NOTICE '  REFRESH MATERIALIZED VIEW donor_intelligence.mv_donation_summary;';
    RAISE NOTICE '  REFRESH MATERIALIZED VIEW CONCURRENTLY donor_intelligence.mv_donor_profile;';
    RAISE NOTICE '  (Run mv_donation_summary first; mv_donor_profile may run CONCURRENTLY)';
    RAISE NOTICE '=================================================';
END;
$$;


-- =============================================================================
-- END OF MIGRATION
-- =============================================================================
-- Summary of objects created:
--
-- EXTENSIONS (4):  uuid-ossp, pgcrypto, pg_trgm, btree_gin
--
-- SCHEMAS (11):    raw, core, donor_intelligence, pipeline, brain, audit,
--                  staging, norm, archive, volunteer, public
--
-- FUNCTIONS (1):   update_timestamp()  — shared updated_at trigger function
--
-- LAYER 1 — DATA TABLES (5 tables):
--   raw.fec_donations                          — FEC contribution records
--   donor_intelligence.person_master           — Golden record per human
--   donor_intelligence.contribution_map        — Donations → person link
--   donor_intelligence.committee_candidate_map — Committee → candidate map
--   pipeline.loaded_files                      — Ingestion idempotency guard
--
-- LAYER 2 — BRAIN / EVENT BUS (6 tables + 4 partitions):
--   brain.event_queue          (+ partitions 2026-04 through 2026-07)
--   brain.decisions
--   brain.triggers
--   brain.contact_fatigue
--   brain.budgets
--   brain.learning
--
-- LAYER 3 — AUDIT (1 table + 4 partitions):
--   audit.activity_log         (+ partitions 2026-04 through 2026-07)
--
-- LAYER 4 — VIEWS & SEARCH (2 materialized views + GIN indexes):
--   donor_intelligence.mv_donor_profile        (WITH NO DATA — refresh required)
--   donor_intelligence.mv_donation_summary     (WITH NO DATA — refresh required)
--   idx_pm_fulltext    — GIN tsvector index on person_master
--   idx_pm_last_trgm   — trigram index on last_name
--   idx_pm_first_trgm  — trigram index on first_name
--
-- EXISTING TABLES UNCHANGED:
--   raw.ncboe_donations                (2.4M rows, 59 cols)
--   core.datatrust_voter_nc            (7.7M rows, 252 cols)
--   core.acxiom_ap_models              (7.6M rows)
--   core.acxiom_ibe                    (~5.5M of 7.6M loading)
--   core.acxiom_consumer_nc            (7.6M rows)
--   core.acxiom_market_indices         (0 rows, pending)
--   donor_intelligence.employer_sic_master  (0 rows, pending)
-- =============================================================================
