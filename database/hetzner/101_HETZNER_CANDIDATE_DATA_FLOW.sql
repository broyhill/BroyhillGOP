-- =============================================================================
-- BroyhillGOP Hetzner — Candidate Data Flow & Vendor Integration Schema
-- =============================================================================
-- Server:    Hetzner AX162 (96 CPU, 251 GB RAM, NVMe RAID1)
-- Database:  PostgreSQL 16
-- Generated: 2026-04-13
--
-- PURPOSE: Creates the complete real-time data flow infrastructure for
--          per-candidate operations. Handles:
--            - Candidate profiles (E03 273-field spec, JSONB-extensible)
--            - Campaign lifecycle management
--            - Data source registry (Acxiom, DataTrust, FEC, NCBOE, any vendor)
--            - Real-time inbound data feeds per candidate
--            - Third-party vendor plug-and-play integration
--            - Candidate enrichment pipeline (raw → enriched profile)
--            - Per-candidate trigger assignments (Brain integration)
--            - Candidate ecosystem metrics & KPI tracking
--
-- DEPENDS ON (already deployed, NOT touched):
--   donor_intelligence.person_master
--   brain.event_queue
--   brain.triggers
--   brain.decisions
--   audit.activity_log
--   pipeline.loaded_files
--
-- SAFE TO RE-RUN: All statements use IF NOT EXISTS or CREATE OR REPLACE.
-- =============================================================================


-- =============================================================================
-- LAYER A: CANDIDATE REGISTRY + CAMPAIGN LIFECYCLE
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- A.1  core.candidates
--      The central candidate registry. Every candidate in the platform gets
--      one row here. Links to person_master via person_id (the candidate IS
--      a person). Contains the E03 273-field profile compressed into
--      structured columns + extensible JSONB sections.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.candidates (

    candidate_id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Link to person_master (the candidate is a person)
    person_id               UUID            NOT NULL
                                REFERENCES donor_intelligence.person_master (person_id)
                                ON DELETE RESTRICT ON UPDATE CASCADE,

    -- -----------------------------------------------------------------------
    -- Identity
    -- -----------------------------------------------------------------------
    first_name              TEXT            NOT NULL,
    middle_name             TEXT,
    last_name               TEXT            NOT NULL,
    suffix                  TEXT,
    preferred_name          TEXT,           -- "Ed" for Edgar, "Bobby" for Robert
    legal_name              TEXT,           -- Full legal name
    formal_salutation       TEXT,           -- "Dear Senator Smith"

    -- -----------------------------------------------------------------------
    -- Office / Election
    -- -----------------------------------------------------------------------
    office_type             TEXT,           -- 'President','Senate','House','Governor','State Senate',
                                           -- 'State House','County Commissioner','Council','Mayor',etc.
    office_level            TEXT,           -- 'federal','state','local'
    office_title            TEXT,           -- e.g. "NC House District 74"
    office_state            TEXT            NOT NULL DEFAULT 'NC',
    office_district         TEXT,
    county                  TEXT,
    is_incumbent            BOOLEAN         NOT NULL DEFAULT FALSE,
    incumbent_since         DATE,

    -- -----------------------------------------------------------------------
    -- Election context
    -- -----------------------------------------------------------------------
    election_year           INTEGER,
    primary_election_date   DATE,
    general_election_date   DATE,
    filing_date             DATE,
    ballot_name             TEXT,
    race_rating             TEXT,           -- 'safe_r','likely_r','lean_r','toss_up','lean_d','likely_d','safe_d'

    -- -----------------------------------------------------------------------
    -- Party / Ideology
    -- -----------------------------------------------------------------------
    party                   TEXT            NOT NULL DEFAULT 'REP',
    faction                 TEXT,           -- e.g. 'Freedom Caucus','Establishment','MAGA'
    ideology_score          INTEGER,        -- 0-100 conservative scale

    -- -----------------------------------------------------------------------
    -- Status & Subscription
    -- -----------------------------------------------------------------------
    status                  TEXT            NOT NULL DEFAULT 'prospect'
                                CHECK (status IN (
                                    'prospect','recruited','onboarding','active',
                                    'suspended','withdrawn','lost','won','termed'
                                )),
    subscription_tier       TEXT            NOT NULL DEFAULT 'basic'
                                CHECK (subscription_tier IN ('basic','standard','premium','enterprise')),
    onboarding_stage        TEXT,           -- from E03 pipeline stages

    -- -----------------------------------------------------------------------
    -- FEC / Filing IDs
    -- -----------------------------------------------------------------------
    fec_candidate_id        TEXT,           -- P/H/S + digits
    fec_committee_id        TEXT,           -- C00... (principal campaign committee)
    state_committee_id      TEXT,           -- NCBOE committee ID

    -- -----------------------------------------------------------------------
    -- Campaign Staff (key contacts)
    -- -----------------------------------------------------------------------
    campaign_manager        TEXT,
    campaign_manager_email  TEXT,
    campaign_manager_phone  TEXT,
    finance_director        TEXT,
    communications_director TEXT,
    field_director          TEXT,
    digital_director        TEXT,
    treasurer               TEXT,

    -- -----------------------------------------------------------------------
    -- Online Presence
    -- -----------------------------------------------------------------------
    campaign_website        TEXT,
    donation_url            TEXT,
    volunteer_url           TEXT,
    social_media            JSONB           NOT NULL DEFAULT '{}',
        -- { "facebook": {"url":"...", "handle":"..."}, "twitter": {...},
        --   "instagram": {...}, "youtube": {...}, "tiktok": {...},
        --   "linkedin": {...}, "truth_social": {...}, "rumble": {...} }

    -- -----------------------------------------------------------------------
    -- Branding
    -- -----------------------------------------------------------------------
    brand_primary_color     TEXT,
    brand_secondary_color   TEXT,
    brand_font              TEXT,
    headshot_url            TEXT,
    logo_url                TEXT,
    banner_url              TEXT,

    -- -----------------------------------------------------------------------
    -- AI Context (for content generation across all ecosystems)
    -- -----------------------------------------------------------------------
    ai_context              JSONB           NOT NULL DEFAULT '{}',
        -- { "voice_description": "...", "messaging_tone": "...",
        --   "topics_avoid": [...], "key_phrases": [...],
        --   "attack_lines": [...], "defense_points": [...],
        --   "accomplishments": [...], "call_to_action": "...",
        --   "donation_ask": "...", "volunteer_ask": "...", "vote_ask": "..." }

    -- -----------------------------------------------------------------------
    -- District Demographics (from E03 spec)
    -- -----------------------------------------------------------------------
    district_demographics   JSONB           NOT NULL DEFAULT '{}',
        -- { "population": 750000, "registered_voters": 500000,
        --   "republican_pct": 55.2, "democrat_pct": 38.1,
        --   "median_income": 62000, "median_age": 42,
        --   "urban_pct": 45, "suburban_pct": 40, "rural_pct": 15,
        --   "trump_2020_pct": 56.3, "pvi": "R+8", "top_issues": [...] }

    -- -----------------------------------------------------------------------
    -- Biography / Personal (JSONB for the 30+ bio fields from E03)
    -- -----------------------------------------------------------------------
    biography               JSONB           NOT NULL DEFAULT '{}',
        -- { "bio_short": "...", "bio_full": "...", "tagline": "...",
        --   "birth_city": "...", "hometown": "...", "years_in_district": 12,
        --   "marital_status": "married", "spouse_name": "...",
        --   "children_count": 3, "education": [...], "career_history": [...],
        --   "military": {...}, "religion": "...", "community_involvement": "..." }

    -- -----------------------------------------------------------------------
    -- Issue Positions (from E03 spec — 60 issues)
    -- -----------------------------------------------------------------------
    issue_positions         JSONB           NOT NULL DEFAULT '{}',
        -- { "gun_rights": {"position":"strong_support","priority":1,"talking_points":[...]},
        --   "immigration": {...}, "taxes": {...}, ... }
    priority_issues         JSONB           NOT NULL DEFAULT '[]',
    signature_issue         TEXT,

    -- -----------------------------------------------------------------------
    -- Scoring (1000-point E03 system)
    -- -----------------------------------------------------------------------
    attribute_score_total   INTEGER         NOT NULL DEFAULT 0,
    attribute_scores        JSONB           NOT NULL DEFAULT '{}',
        -- { "professional_experience": 42, "legislative_knowledge": 68,
        --   "media_presence": 55, "district_alignment": 110,
        --   "constituent_appeal": 85, "campaign_readiness": 60,
        --   "team_collaboration": 65, "ideological_alignment": 130,
        --   "leadership_potential": 100, "financial_stability": 50 }

    -- -----------------------------------------------------------------------
    -- Endorsements
    -- -----------------------------------------------------------------------
    endorsements            JSONB           NOT NULL DEFAULT '{}',
        -- { "trump_endorsed": true, "trump_endorsed_date": "2026-01-15",
        --   "nra_grade": "A+", "nra_endorsed": true,
        --   "right_to_life": true, "chamber": false,
        --   "other": [{"org":"NC Farm Bureau","date":"2026-02-01"}] }

    -- -----------------------------------------------------------------------
    -- Finance (cached from FEC/NCBOE — refreshed by pipeline)
    -- -----------------------------------------------------------------------
    raised_total            NUMERIC(14,2)   NOT NULL DEFAULT 0,
    raised_this_cycle       NUMERIC(14,2)   NOT NULL DEFAULT 0,
    cash_on_hand            NUMERIC(14,2)   NOT NULL DEFAULT 0,
    debt_total              NUMERIC(14,2)   NOT NULL DEFAULT 0,
    donor_count             INTEGER         NOT NULL DEFAULT 0,
    avg_donation            NUMERIC(10,2)   NOT NULL DEFAULT 0,
    small_dollar_pct        NUMERIC(5,2)    NOT NULL DEFAULT 0,

    -- -----------------------------------------------------------------------
    -- Custom / Extensible
    -- -----------------------------------------------------------------------
    custom_fields           JSONB           NOT NULL DEFAULT '{}',
    custom_tags             JSONB           NOT NULL DEFAULT '[]',

    -- -----------------------------------------------------------------------
    -- Audit
    -- -----------------------------------------------------------------------
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- updated_at trigger
CREATE OR REPLACE TRIGGER trg_candidates_updated_at
    BEFORE UPDATE ON core.candidates
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS uidx_candidates_person
    ON core.candidates (person_id);

CREATE INDEX IF NOT EXISTS idx_candidates_name
    ON core.candidates (last_name, first_name);

CREATE INDEX IF NOT EXISTS idx_candidates_status
    ON core.candidates (status);

CREATE INDEX IF NOT EXISTS idx_candidates_office
    ON core.candidates (office_type, office_state, office_district);

CREATE INDEX IF NOT EXISTS idx_candidates_party
    ON core.candidates (party);

CREATE INDEX IF NOT EXISTS idx_candidates_election_year
    ON core.candidates (election_year);

CREATE INDEX IF NOT EXISTS idx_candidates_fec_id
    ON core.candidates (fec_candidate_id)
    WHERE fec_candidate_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_candidates_state_cmte
    ON core.candidates (state_committee_id)
    WHERE state_committee_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_candidates_tier
    ON core.candidates (subscription_tier);

CREATE INDEX IF NOT EXISTS idx_candidates_county
    ON core.candidates (county);

-- GIN indexes on JSONB for fast search
CREATE INDEX IF NOT EXISTS idx_candidates_social_gin
    ON core.candidates USING GIN (social_media);

CREATE INDEX IF NOT EXISTS idx_candidates_tags_gin
    ON core.candidates USING GIN (custom_tags);

CREATE INDEX IF NOT EXISTS idx_candidates_issues_gin
    ON core.candidates USING GIN (issue_positions);

COMMENT ON TABLE core.candidates IS
  'Central candidate registry. One row per political candidate in the platform. '
  'Links to person_master via person_id (a candidate IS a person). '
  'Contains the E03 273-field spec compressed into structured columns + JSONB sections. '
  'Status tracks the full lifecycle from prospect through won/lost. '
  'AI context JSONB drives content generation across all 58 ecosystems.';


-- ---------------------------------------------------------------------------
-- A.2  core.campaigns
--      A candidate can have multiple campaigns (primary, general, runoff,
--      re-election). Each campaign links to brain.budgets, brain.triggers,
--      and the data feed system.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.campaigns (

    campaign_id             UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    candidate_id            UUID            NOT NULL
                                REFERENCES core.candidates (candidate_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    -- Campaign identity
    campaign_name           TEXT            NOT NULL,
    campaign_type           TEXT            NOT NULL DEFAULT 'general'
                                CHECK (campaign_type IN (
                                    'primary','general','runoff','special',
                                    'reelection','recall','referendum'
                                )),
    election_cycle          TEXT,           -- '2025-2026'
    election_date           DATE,

    -- Status
    status                  TEXT            NOT NULL DEFAULT 'planning'
                                CHECK (status IN (
                                    'planning','active','paused','completed','won','lost','withdrawn'
                                )),

    -- Budget (top-level — detail in brain.budgets per channel)
    total_budget            NUMERIC(14,2)   NOT NULL DEFAULT 0,
    total_raised            NUMERIC(14,2)   NOT NULL DEFAULT 0,
    total_spent             NUMERIC(14,2)   NOT NULL DEFAULT 0,

    -- Campaign slogan / messaging
    campaign_slogan         TEXT,
    campaign_theme          TEXT,
    campaign_priorities     JSONB           NOT NULL DEFAULT '[]',

    -- Contact
    campaign_email          TEXT,
    campaign_phone          TEXT,
    campaign_address        TEXT,

    -- Metrics (cached, refreshed by pipeline)
    metrics                 JSONB           NOT NULL DEFAULT '{}',
        -- { "emails_sent": 50000, "sms_sent": 12000, "calls_made": 8000,
        --   "doors_knocked": 15000, "yard_signs": 2500,
        --   "social_impressions": 1200000, "website_visits": 45000,
        --   "volunteer_hours": 3200, "events_held": 42 }

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

CREATE OR REPLACE TRIGGER trg_campaigns_updated_at
    BEFORE UPDATE ON core.campaigns
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE INDEX IF NOT EXISTS idx_campaigns_candidate
    ON core.campaigns (candidate_id);

CREATE INDEX IF NOT EXISTS idx_campaigns_status
    ON core.campaigns (status);

CREATE INDEX IF NOT EXISTS idx_campaigns_cycle
    ON core.campaigns (election_cycle);

CREATE INDEX IF NOT EXISTS idx_campaigns_type
    ON core.campaigns (campaign_type);

COMMENT ON TABLE core.campaigns IS
  'Per-candidate campaign records. A candidate can run multiple campaigns '
  '(primary, general, runoff, reelection). Links to brain.budgets for per-channel '
  'spending and brain.triggers for campaign-scoped trigger activation. '
  'metrics JSONB is refreshed by the nightly pipeline from ecosystem activity.';


COMMIT;


-- =============================================================================
-- LAYER B: DATA SOURCE REGISTRY + VENDOR MANAGEMENT
-- =============================================================================
-- The plug-and-play vendor system. Every data source — internal (Acxiom,
-- DataTrust, FEC, NCBOE) and external (any third-party vendor) — registers
-- here. Candidates are then subscribed to specific data sources.

BEGIN;

-- ---------------------------------------------------------------------------
-- B.1  pipeline.data_sources
--      Master registry of every data source in the platform. Internal
--      sources (Acxiom, DataTrust) AND external vendors (news APIs,
--      social media, polling firms, etc.). Plug-and-play: add a row here
--      and the pipeline picks it up.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pipeline.data_sources (

    source_id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    source_name             TEXT            NOT NULL UNIQUE,
    source_type             TEXT            NOT NULL
                                CHECK (source_type IN (
                                    -- Internal / first-party
                                    'voter_file',       -- DataTrust, NCSBE
                                    'donation_file',    -- FEC bulk, NCBOE gold
                                    'consumer_data',    -- Acxiom IBE, consumer, market
                                    'model_scores',     -- Acxiom AP models, DataTrust scores
                                    -- External / third-party
                                    'news_feed',        -- RSS, news APIs
                                    'social_media',     -- Twitter/X, Facebook, Instagram APIs
                                    'polling',          -- polling firm data
                                    'ad_platform',      -- Google Ads, Meta Ads, programmatic
                                    'email_platform',   -- Mailchimp, SendGrid, etc.
                                    'sms_platform',     -- Twilio, SlickText, etc.
                                    'payment_processor',-- WinRed, Stripe, etc.
                                    'crm',              -- external CRM sync
                                    'compliance',       -- FEC filing API, state filing APIs
                                    'enrichment',       -- WealthEngine, DonorSearch, FullContact
                                    'field_ops',        -- canvassing apps, MiniVAN
                                    'event_platform',   -- Eventbrite, Mobilize
                                    'analytics',        -- Google Analytics, Mixpanel
                                    'custom'            -- anything else
                                )),
    category                TEXT,           -- 'acxiom','datatrust','fec','ncboe','vendor','internal'

    -- Vendor details (for third-party sources)
    vendor_name             TEXT,
    vendor_contact_name     TEXT,
    vendor_contact_email    TEXT,
    vendor_contract_id      TEXT,
    vendor_contract_expires DATE,

    -- Connection configuration
    connection_type         TEXT            NOT NULL DEFAULT 'file_upload'
                                CHECK (connection_type IN (
                                    'file_upload',      -- manual or scheduled file drops
                                    'api_pull',         -- we pull from their API
                                    'api_push',         -- they push to our webhook
                                    'webhook',          -- real-time webhook notifications
                                    'database_sync',    -- direct DB replication
                                    'sftp',             -- scheduled SFTP fetch
                                    'stream'            -- real-time streaming (Kafka, Redis pub/sub)
                                )),
    connection_config       JSONB           NOT NULL DEFAULT '{}',
        -- { "api_url": "...", "api_key_ref": "vault:acxiom_key",
        --   "auth_type": "bearer", "poll_interval_minutes": 60,
        --   "sftp_host": "...", "sftp_path": "/incoming/",
        --   "webhook_secret": "vault:webhook_secret_123" }

    -- Data contract
    data_format             TEXT,           -- 'csv','json','xml','parquet','api_json'
    data_schema_version     TEXT,           -- version tracking for schema changes
    expected_fields         JSONB           NOT NULL DEFAULT '[]',
        -- ["rnc_regid","first_name","last_name","zip5","score_1","score_2",...]

    -- Scheduling
    refresh_schedule        TEXT,           -- cron expression: '0 2 * * *' = 2am daily
    last_refresh_at         TIMESTAMPTZ,
    next_refresh_at         TIMESTAMPTZ,

    -- Quality / SLA
    expected_row_count      BIGINT,         -- expected rows per refresh (for anomaly detection)
    sla_freshness_hours     INTEGER,        -- data must be refreshed within N hours
    reliability_score       NUMERIC(5,2)    NOT NULL DEFAULT 100.0,  -- 0-100, degraded on failures

    -- Status
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    is_verified             BOOLEAN         NOT NULL DEFAULT FALSE,  -- security audit passed?
    compliance_status       TEXT            NOT NULL DEFAULT 'pending'
                                CHECK (compliance_status IN (
                                    'pending','approved','restricted','revoked'
                                )),

    -- Metadata
    notes                   TEXT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

CREATE OR REPLACE TRIGGER trg_data_sources_updated_at
    BEFORE UPDATE ON pipeline.data_sources
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE INDEX IF NOT EXISTS idx_ds_type
    ON pipeline.data_sources (source_type);

CREATE INDEX IF NOT EXISTS idx_ds_category
    ON pipeline.data_sources (category);

CREATE INDEX IF NOT EXISTS idx_ds_active
    ON pipeline.data_sources (is_active);

CREATE INDEX IF NOT EXISTS idx_ds_vendor
    ON pipeline.data_sources (vendor_name)
    WHERE vendor_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ds_compliance
    ON pipeline.data_sources (compliance_status);

CREATE INDEX IF NOT EXISTS idx_ds_next_refresh
    ON pipeline.data_sources (next_refresh_at)
    WHERE is_active = TRUE;

COMMENT ON TABLE pipeline.data_sources IS
  'Master registry of every data source in the platform — internal (Acxiom, DataTrust, '
  'FEC, NCBOE) and external (news APIs, social media, polling, ad platforms, etc.). '
  'Plug-and-play: add a row here and the pipeline picks it up. '
  'connection_config stores API keys by vault reference, never in plaintext. '
  'reliability_score degrades automatically on failures and recovers on success.';


-- ---------------------------------------------------------------------------
-- B.2  pipeline.candidate_data_subscriptions
--      Which candidates are subscribed to which data sources.
--      This is the per-candidate plug-and-play control plane.
--      When a new vendor is added, subscribe candidates to it here.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pipeline.candidate_data_subscriptions (

    subscription_id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    candidate_id            UUID            NOT NULL
                                REFERENCES core.candidates (candidate_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    source_id               UUID            NOT NULL
                                REFERENCES pipeline.data_sources (source_id)
                                ON DELETE RESTRICT ON UPDATE CASCADE,

    campaign_id             UUID
                                REFERENCES core.campaigns (campaign_id)
                                ON DELETE SET NULL ON UPDATE CASCADE,

    -- Subscription config
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    priority                INTEGER         NOT NULL DEFAULT 50
                                CHECK (priority BETWEEN 1 AND 100),

    -- Filters (which subset of the source data applies to this candidate)
    filter_config           JSONB           NOT NULL DEFAULT '{}',
        -- { "state": "NC", "district": "05", "keywords": ["broyhill","watauga"],
        --   "committee_ids": ["C00123456"], "geo_radius_miles": 50 }

    -- Scheduling override (overrides data_source default if set)
    custom_schedule         TEXT,           -- cron override
    last_sync_at            TIMESTAMPTZ,
    next_sync_at            TIMESTAMPTZ,
    sync_status             TEXT            NOT NULL DEFAULT 'idle'
                                CHECK (sync_status IN ('idle','syncing','error','disabled')),
    last_error              TEXT,

    -- Volume tracking
    total_records_received  BIGINT          NOT NULL DEFAULT 0,
    total_records_processed BIGINT          NOT NULL DEFAULT 0,
    total_records_failed    BIGINT          NOT NULL DEFAULT 0,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Functional unique index: one subscription per candidate per source per campaign
CREATE UNIQUE INDEX IF NOT EXISTS uidx_cds_candidate_source_campaign
    ON pipeline.candidate_data_subscriptions (
        candidate_id, source_id,
        COALESCE(campaign_id, '00000000-0000-0000-0000-000000000000'::uuid)
    );

CREATE OR REPLACE TRIGGER trg_cds_updated_at
    BEFORE UPDATE ON pipeline.candidate_data_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE INDEX IF NOT EXISTS idx_cds_candidate
    ON pipeline.candidate_data_subscriptions (candidate_id);

CREATE INDEX IF NOT EXISTS idx_cds_source
    ON pipeline.candidate_data_subscriptions (source_id);

CREATE INDEX IF NOT EXISTS idx_cds_campaign
    ON pipeline.candidate_data_subscriptions (campaign_id)
    WHERE campaign_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cds_active
    ON pipeline.candidate_data_subscriptions (is_active)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_cds_next_sync
    ON pipeline.candidate_data_subscriptions (next_sync_at)
    WHERE is_active = TRUE AND sync_status != 'disabled';

COMMENT ON TABLE pipeline.candidate_data_subscriptions IS
  'Per-candidate subscription to data sources. Controls which data flows to which '
  'candidate. filter_config narrows broad sources (e.g., national news feed) to '
  'candidate-relevant data (keywords, district, geo). The pipeline reads this table '
  'to decide what data to route where.';


COMMIT;


-- =============================================================================
-- LAYER C: REAL-TIME DATA INGEST + ENRICHMENT PIPELINE
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- C.1  pipeline.inbound_data_queue
--      The universal intake table for ALL real-time data flowing into the
--      platform. Every data source — Acxiom batch files, DataTrust updates,
--      FEC filings, news articles, social posts, webhook events, vendor
--      pushes — lands here first. Partitioned for volume.
--
--      Processing flow:
--        1. Data arrives → INSERT into inbound_data_queue (status='pending')
--        2. Router reads pending rows, matches to candidate subscriptions
--        3. Enrichment pipeline processes the record
--        4. Results flow to candidate_enrichment_log + brain.event_queue
--        5. Status updated to 'completed' or 'failed'
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pipeline.inbound_data_queue (

    record_id               UUID            NOT NULL DEFAULT gen_random_uuid(),

    -- Source identification
    source_id               UUID            NOT NULL,    -- FK to pipeline.data_sources
    source_name             TEXT,                        -- Denormalized for fast reads
    source_record_id        TEXT,                        -- External system's record ID

    -- Routing
    candidate_id            UUID,                        -- NULL = unrouted, needs matching
    campaign_id             UUID,
    subscription_id         UUID,                        -- Which subscription matched

    -- Payload
    data_type               TEXT            NOT NULL,
        -- 'voter_update','donation','news_article','social_post','poll_result',
        -- 'ad_metric','email_metric','sms_metric','enrichment_result',
        -- 'compliance_alert','field_report','event_rsvp','webhook_event',
        -- 'score_update','file_record','api_response','custom'
    payload                 JSONB           NOT NULL DEFAULT '{}',
        -- The actual data — structure varies by data_type

    -- Processing state
    status                  TEXT            NOT NULL DEFAULT 'pending'
                                CHECK (status IN (
                                    'pending','routing','processing','enriching',
                                    'completed','failed','skipped','duplicate'
                                )),
    priority                INTEGER         NOT NULL DEFAULT 50,
    attempts                INTEGER         NOT NULL DEFAULT 0,
    max_attempts            INTEGER         NOT NULL DEFAULT 3,
    error_message           TEXT,
    processed_at            TIMESTAMPTZ,

    -- Lineage
    batch_id                TEXT,           -- Groups records from same file/API call
    parent_record_id        UUID,           -- Chain records (e.g., enrichment spawned from donation)

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (record_id, created_at)

) PARTITION BY RANGE (created_at);

-- Monthly partitions
CREATE TABLE IF NOT EXISTS pipeline.inbound_data_queue_2026_04
    PARTITION OF pipeline.inbound_data_queue
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE IF NOT EXISTS pipeline.inbound_data_queue_2026_05
    PARTITION OF pipeline.inbound_data_queue
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE IF NOT EXISTS pipeline.inbound_data_queue_2026_06
    PARTITION OF pipeline.inbound_data_queue
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE IF NOT EXISTS pipeline.inbound_data_queue_2026_07
    PARTITION OF pipeline.inbound_data_queue
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

-- Primary work queue: pull pending records in priority order
CREATE INDEX IF NOT EXISTS idx_idq_pending
    ON pipeline.inbound_data_queue (priority DESC, created_at)
    WHERE status = 'pending';

-- Candidate-level data history
CREATE INDEX IF NOT EXISTS idx_idq_candidate
    ON pipeline.inbound_data_queue (candidate_id, created_at DESC)
    WHERE candidate_id IS NOT NULL;

-- Source monitoring
CREATE INDEX IF NOT EXISTS idx_idq_source
    ON pipeline.inbound_data_queue (source_id, created_at DESC);

-- Data type filtering
CREATE INDEX IF NOT EXISTS idx_idq_type
    ON pipeline.inbound_data_queue (data_type);

-- Batch tracking
CREATE INDEX IF NOT EXISTS idx_idq_batch
    ON pipeline.inbound_data_queue (batch_id)
    WHERE batch_id IS NOT NULL;

-- Dedup: external record ID per source
CREATE INDEX IF NOT EXISTS idx_idq_source_record
    ON pipeline.inbound_data_queue (source_id, source_record_id)
    WHERE source_record_id IS NOT NULL;

COMMENT ON TABLE pipeline.inbound_data_queue IS
  'Universal intake for ALL real-time data flowing into the platform. '
  'Acxiom batch files, DataTrust updates, FEC filings, news articles, social posts, '
  'webhook events, vendor pushes — everything lands here first. '
  'Partitioned monthly. Add partitions before month-end. '
  'Processing: pending → routing → processing → enriching → completed/failed.';


-- ---------------------------------------------------------------------------
-- C.2  pipeline.candidate_enrichment_log
--      Tracks every enrichment action applied to a candidate or their
--      contacts. When Acxiom scores arrive, when DataTrust updates hit,
--      when a news article is matched, when a donation is processed —
--      every data enrichment event is logged here.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pipeline.candidate_enrichment_log (

    enrichment_id           UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- What was enriched
    candidate_id            UUID            NOT NULL,
    person_id               UUID,           -- If enrichment applies to a specific person
    campaign_id             UUID,

    -- Source of enrichment
    source_id               UUID,           -- FK to pipeline.data_sources
    source_name             TEXT,
    inbound_record_id       UUID,           -- FK hint to inbound_data_queue.record_id

    -- Enrichment details
    enrichment_type         TEXT            NOT NULL,
        -- 'acxiom_score_update','datatrust_voter_update','fec_filing_update',
        -- 'donation_matched','news_article_matched','social_mention_detected',
        -- 'poll_result_added','ad_performance_updated','email_metrics_updated',
        -- 'wealth_score_updated','contact_appended','address_updated',
        -- 'phone_appended','email_appended','household_linked',
        -- 'voter_status_changed','party_registration_changed',
        -- 'compliance_flag_added','field_report_processed','custom'
    enrichment_data         JSONB           NOT NULL DEFAULT '{}',
        -- Before/after values, scores, matched data, etc.

    -- Impact assessment
    fields_updated          TEXT[],         -- Which fields were touched
    confidence_score        NUMERIC(5,2),   -- 0-100 confidence in the enrichment
    is_significant          BOOLEAN         NOT NULL DEFAULT FALSE,
        -- TRUE if this should trigger a brain event

    -- Status
    status                  TEXT            NOT NULL DEFAULT 'applied'
                                CHECK (status IN ('applied','pending_review','rejected','rolled_back')),

    -- Brain integration: did this enrichment trigger an event?
    triggered_event_id      UUID,           -- FK hint to brain.event_queue.event_id

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

CREATE INDEX IF NOT EXISTS idx_cel_candidate
    ON pipeline.candidate_enrichment_log (candidate_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cel_person
    ON pipeline.candidate_enrichment_log (person_id, created_at DESC)
    WHERE person_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cel_source
    ON pipeline.candidate_enrichment_log (source_id);

CREATE INDEX IF NOT EXISTS idx_cel_type
    ON pipeline.candidate_enrichment_log (enrichment_type);

CREATE INDEX IF NOT EXISTS idx_cel_significant
    ON pipeline.candidate_enrichment_log (candidate_id, created_at DESC)
    WHERE is_significant = TRUE;

CREATE INDEX IF NOT EXISTS idx_cel_created
    ON pipeline.candidate_enrichment_log (created_at);

COMMENT ON TABLE pipeline.candidate_enrichment_log IS
  'Tracks every enrichment action applied to a candidate or their contacts. '
  'Acxiom scores, DataTrust updates, FEC filings, news matches, donations — '
  'everything. is_significant=TRUE rows fire brain.event_queue events. '
  'enrichment_data JSONB stores before/after values for audit trail.';


COMMIT;


-- =============================================================================
-- LAYER D: PER-CANDIDATE BRAIN INTEGRATION
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- D.1  brain.candidate_triggers
--      Junction table: which brain.triggers are active for which candidate
--      and/or campaign. Allows per-candidate trigger configuration without
--      modifying the global trigger definitions.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brain.candidate_triggers (

    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    candidate_id            UUID            NOT NULL
                                REFERENCES core.candidates (candidate_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    trigger_id              UUID            NOT NULL
                                REFERENCES brain.triggers (trigger_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    campaign_id             UUID
                                REFERENCES core.campaigns (campaign_id)
                                ON DELETE SET NULL ON UPDATE CASCADE,

    -- Override settings (override global trigger defaults for this candidate)
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    priority_override       INTEGER,        -- NULL = use global priority
    cooldown_override       INTEGER,        -- NULL = use global cooldown_minutes
    custom_conditions       JSONB,          -- NULL = use global conditions
    custom_actions          JSONB,          -- NULL = use global actions

    -- Channel restrictions for this candidate
    allowed_channels        TEXT[],         -- NULL = all channels allowed
    blocked_channels        TEXT[],         -- e.g. ['sms'] if candidate opts out of SMS

    -- Stats
    fire_count              BIGINT          NOT NULL DEFAULT 0,
    last_fired              TIMESTAMPTZ,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_candidate_trigger UNIQUE (candidate_id, trigger_id)

);

CREATE OR REPLACE TRIGGER trg_ct_updated_at
    BEFORE UPDATE ON brain.candidate_triggers
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE INDEX IF NOT EXISTS idx_ct_candidate
    ON brain.candidate_triggers (candidate_id);

CREATE INDEX IF NOT EXISTS idx_ct_trigger
    ON brain.candidate_triggers (trigger_id);

CREATE INDEX IF NOT EXISTS idx_ct_campaign
    ON brain.candidate_triggers (campaign_id)
    WHERE campaign_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ct_active
    ON brain.candidate_triggers (candidate_id)
    WHERE is_active = TRUE;

COMMENT ON TABLE brain.candidate_triggers IS
  'Per-candidate trigger assignments. Links brain.triggers to specific candidates '
  'with optional overrides for priority, cooldown, conditions, actions, and channel '
  'restrictions. Allows candidate A to use trigger X with different settings than '
  'candidate B without modifying the global trigger definition.';


-- ---------------------------------------------------------------------------
-- D.2  brain.candidate_metrics
--      Real-time KPI dashboard for each candidate. Updated by the pipeline
--      and Brain decisions. Powers the E27 real-time dashboard and E29
--      analytics dashboard.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS brain.candidate_metrics (

    metric_id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    candidate_id            UUID            NOT NULL
                                REFERENCES core.candidates (candidate_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    campaign_id             UUID
                                REFERENCES core.campaigns (campaign_id)
                                ON DELETE SET NULL ON UPDATE CASCADE,

    -- Time period
    period_type             TEXT            NOT NULL
                                CHECK (period_type IN ('hourly','daily','weekly','monthly','cycle')),
    period_start            TIMESTAMPTZ     NOT NULL,
    period_end              TIMESTAMPTZ     NOT NULL,

    -- Fundraising metrics
    donations_received      INTEGER         NOT NULL DEFAULT 0,
    donation_amount         NUMERIC(14,2)   NOT NULL DEFAULT 0,
    avg_donation_size       NUMERIC(10,2)   NOT NULL DEFAULT 0,
    new_donors              INTEGER         NOT NULL DEFAULT 0,
    recurring_donors        INTEGER         NOT NULL DEFAULT 0,
    lapsed_donors_reactivated INTEGER       NOT NULL DEFAULT 0,

    -- Communication metrics
    emails_sent             INTEGER         NOT NULL DEFAULT 0,
    emails_opened           INTEGER         NOT NULL DEFAULT 0,
    emails_clicked          INTEGER         NOT NULL DEFAULT 0,
    sms_sent                INTEGER         NOT NULL DEFAULT 0,
    sms_responses           INTEGER         NOT NULL DEFAULT 0,
    calls_made              INTEGER         NOT NULL DEFAULT 0,
    calls_connected         INTEGER         NOT NULL DEFAULT 0,
    mail_pieces_sent        INTEGER         NOT NULL DEFAULT 0,

    -- Digital metrics
    social_impressions      BIGINT          NOT NULL DEFAULT 0,
    social_engagements      INTEGER         NOT NULL DEFAULT 0,
    website_visits          INTEGER         NOT NULL DEFAULT 0,
    ad_impressions          BIGINT          NOT NULL DEFAULT 0,
    ad_clicks               INTEGER         NOT NULL DEFAULT 0,
    ad_spend                NUMERIC(12,2)   NOT NULL DEFAULT 0,

    -- Field metrics
    doors_knocked           INTEGER         NOT NULL DEFAULT 0,
    voter_contacts          INTEGER         NOT NULL DEFAULT 0,
    volunteer_hours         NUMERIC(10,2)   NOT NULL DEFAULT 0,
    events_held             INTEGER         NOT NULL DEFAULT 0,
    event_attendees         INTEGER         NOT NULL DEFAULT 0,
    yard_signs_placed       INTEGER         NOT NULL DEFAULT 0,

    -- News / PR metrics
    news_mentions           INTEGER         NOT NULL DEFAULT 0,
    news_sentiment_avg      NUMERIC(5,2),   -- -1.0 to 1.0
    crisis_alerts           INTEGER         NOT NULL DEFAULT 0,
    endorsements_received   INTEGER         NOT NULL DEFAULT 0,

    -- Brain metrics
    brain_events_processed  INTEGER         NOT NULL DEFAULT 0,
    brain_decisions_go      INTEGER         NOT NULL DEFAULT 0,
    brain_decisions_no_go   INTEGER         NOT NULL DEFAULT 0,
    triggers_fired          INTEGER         NOT NULL DEFAULT 0,

    -- Enrichment metrics
    records_ingested        BIGINT          NOT NULL DEFAULT 0,
    records_enriched        BIGINT          NOT NULL DEFAULT 0,
    data_sources_active     INTEGER         NOT NULL DEFAULT 0,

    -- Compliance
    compliance_flags        INTEGER         NOT NULL DEFAULT 0,
    contribution_limit_warnings INTEGER     NOT NULL DEFAULT 0,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

-- Functional unique index for candidate metrics
CREATE UNIQUE INDEX IF NOT EXISTS uidx_cm_candidate_period
    ON brain.candidate_metrics (
        candidate_id,
        COALESCE(campaign_id, '00000000-0000-0000-0000-000000000000'::uuid),
        period_type,
        period_start
    );

CREATE INDEX IF NOT EXISTS idx_cm_candidate
    ON brain.candidate_metrics (candidate_id, period_type, period_start DESC);

CREATE INDEX IF NOT EXISTS idx_cm_campaign
    ON brain.candidate_metrics (campaign_id, period_type, period_start DESC)
    WHERE campaign_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cm_period
    ON brain.candidate_metrics (period_type, period_start DESC);

COMMENT ON TABLE brain.candidate_metrics IS
  'Real-time KPI dashboard for each candidate. Updated by the pipeline and Brain. '
  'Powers E27 (real-time dashboard), E29 (analytics dashboard), and E06 (analytics engine). '
  'Rows at hourly/daily granularity for active campaigns; weekly/monthly for historical. '
  'The pipeline aggregates raw events into this table on a schedule.';


COMMIT;


-- =============================================================================
-- LAYER E: SEED DATA — REGISTER BUILT-IN DATA SOURCES
-- =============================================================================

BEGIN;

-- Register the core internal data sources that already exist
INSERT INTO pipeline.data_sources (source_name, source_type, category, connection_type, data_format, notes)
VALUES
    ('DataTrust NC Voter File', 'voter_file', 'datatrust', 'file_upload', 'csv',
     'NC voter file from DataTrust/RNC. 7.7M rows. Key: rnc_regid. Loaded to core.datatrust_voter_nc'),

    ('NCBOE Donation Records', 'donation_file', 'ncboe', 'file_upload', 'csv',
     'NC Board of Elections gold file. 2.4M rows. Loaded to raw.ncboe_donations. Dedup FINALIZED.'),

    ('FEC Individual Contributions', 'donation_file', 'fec', 'file_upload', 'csv',
     'FEC bulk individual contributions (indiv*.txt). Loaded to raw.fec_donations.'),

    ('FEC Committee Master', 'donation_file', 'fec', 'file_upload', 'csv',
     'FEC committee master file. Maps committee IDs to names/types.'),

    ('FEC Candidate Master', 'donation_file', 'fec', 'file_upload', 'csv',
     'FEC candidate master file. Maps candidate IDs to names/offices.'),

    ('Acxiom InfoBase Enhancement', 'consumer_data', 'acxiom', 'file_upload', 'csv',
     'Acxiom IBE consumer data. 7.6M rows. Loaded to core.acxiom_ibe.'),

    ('Acxiom AP Models', 'model_scores', 'acxiom', 'file_upload', 'csv',
     'Acxiom predictive model scores. 7.6M rows. Loaded to core.acxiom_ap_models.'),

    ('Acxiom Consumer NC', 'consumer_data', 'acxiom', 'file_upload', 'csv',
     'Acxiom consumer demographics. 7.6M rows. Loaded to core.acxiom_consumer_nc.'),

    ('Acxiom Market Indices', 'consumer_data', 'acxiom', 'file_upload', 'csv',
     'Acxiom market-level indices. Loaded to core.acxiom_market_indices.')

ON CONFLICT (source_name) DO NOTHING;

COMMIT;


-- =============================================================================
-- VERIFICATION BLOCK
-- =============================================================================

DO $$
DECLARE
    v_tables    INTEGER;
    v_indexes   INTEGER;
    v_sources   INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_tables
    FROM information_schema.tables
    WHERE table_schema IN ('core','pipeline','brain')
      AND table_type = 'BASE TABLE'
      AND table_name IN (
          'candidates','campaigns',
          'data_sources','candidate_data_subscriptions',
          'inbound_data_queue','candidate_enrichment_log',
          'candidate_triggers','candidate_metrics'
      );

    SELECT COUNT(*) INTO v_indexes
    FROM pg_indexes
    WHERE (indexname LIKE 'idx_candidates_%'
        OR indexname LIKE 'uidx_candidates_%'
        OR indexname LIKE 'idx_campaigns_%'
        OR indexname LIKE 'idx_ds_%'
        OR indexname LIKE 'idx_cds_%'
        OR indexname LIKE 'idx_idq_%'
        OR indexname LIKE 'idx_cel_%'
        OR indexname LIKE 'idx_ct_%'
        OR indexname LIKE 'idx_cm_%');

    SELECT COUNT(*) INTO v_sources
    FROM pipeline.data_sources;

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Candidate Data Flow Migration — VERIFY';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'New tables found           : % / 8 expected', v_tables;
    RAISE NOTICE 'New indexes found          : %', v_indexes;
    RAISE NOTICE 'Registered data sources    : %', v_sources;

    IF v_tables < 8 THEN
        RAISE WARNING 'Expected 8 new tables; only % found.', v_tables;
    ELSE
        RAISE NOTICE 'All 8 tables confirmed.';
    END IF;

    RAISE NOTICE '=================================================';
END;
$$;


-- =============================================================================
-- END OF MIGRATION
-- =============================================================================
-- Summary of objects created:
--
-- LAYER A — CANDIDATE REGISTRY (2 tables):
--   core.candidates                           — Full E03 candidate profile
--   core.campaigns                            — Per-candidate campaign lifecycle
--
-- LAYER B — DATA SOURCE REGISTRY (2 tables):
--   pipeline.data_sources                     — Master vendor/source registry
--   pipeline.candidate_data_subscriptions     — Per-candidate source subscriptions
--
-- LAYER C — REAL-TIME DATA INGEST (2 tables):
--   pipeline.inbound_data_queue  (partitioned) — Universal data intake
--   pipeline.candidate_enrichment_log          — Enrichment audit trail
--
-- LAYER D — BRAIN INTEGRATION (2 tables):
--   brain.candidate_triggers                  — Per-candidate trigger assignments
--   brain.candidate_metrics                   — Real-time KPI dashboard
--
-- SEED DATA:
--   9 internal data sources registered in pipeline.data_sources
--
-- EXISTING TABLES UNCHANGED.
-- =============================================================================
