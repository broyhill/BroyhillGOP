-- =============================================================================
-- BroyhillGOP Hetzner — Ecosystem Registry & Feature Evolution Schema
-- =============================================================================
-- Server:    Hetzner AX162 (96 CPU, 251 GB RAM, NVMe RAID1)
-- Database:  PostgreSQL 16
-- Generated: 2026-04-13
--
-- PURPOSE: Creates the ecosystem management infrastructure. Handles:
--   - Universe definitions (5-7 universes consolidating ~60 ecosystems)
--   - Ecosystem registry (every E## ecosystem as a first-class entity)
--   - Feature tracking per ecosystem (add/revise/deprecate features over time)
--   - Ecosystem version history (snapshots as ecosystems evolve)
--   - Inter-ecosystem dependencies
--   - Per-candidate ecosystem activation (which ecosystems serve which candidate)
--   - Real-time ecosystem health & metrics
--
-- DEPENDS ON (already deployed, NOT touched):
--   core.candidates
--   core.campaigns
--   brain.event_queue
--   brain.triggers
--   audit.activity_log
--   pipeline.data_sources
--   pipeline.inbound_data_queue
--
-- SAFE TO RE-RUN: All statements use IF NOT EXISTS or CREATE OR REPLACE.
-- =============================================================================


-- =============================================================================
-- LAYER A: UNIVERSE DEFINITIONS
-- =============================================================================
-- Universes group related ecosystems for consolidated management.
-- Ed's plan: consolidate ~60 ecosystems into 5-7 universes.

BEGIN;

-- ---------------------------------------------------------------------------
-- A.1  platform.universes
--      Top-level grouping. Each universe contains multiple ecosystems that
--      share a functional domain. Supports the 60→5-7 consolidation.
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS platform;

CREATE TABLE IF NOT EXISTS platform.universes (

    universe_id             UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    universe_code           TEXT            NOT NULL UNIQUE,
        -- Short code used in event_queue.source_universe, audit.activity_log.universe
        -- e.g. 'DATA', 'COMMS', 'MEDIA', 'OPS', 'INTEL', 'PORTAL', 'INFRA'
    universe_name           TEXT            NOT NULL,
    description             TEXT,

    -- Ordering / Display
    display_order           INTEGER         NOT NULL DEFAULT 0,
    color_hex               TEXT,           -- UI color for this universe

    -- Status
    status                  TEXT            NOT NULL DEFAULT 'active'
                                CHECK (status IN ('active','planning','deprecated','archived')),
    is_default              BOOLEAN         NOT NULL DEFAULT FALSE,
        -- One universe can be the default for unassigned ecosystems

    -- Config
    config                  JSONB           NOT NULL DEFAULT '{}',
        -- { "max_ecosystems": 15, "resource_pool": "shared",
        --   "budget_allocation_pct": 25.0, "priority_level": 1 }

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

CREATE OR REPLACE TRIGGER trg_universes_updated_at
    BEFORE UPDATE ON platform.universes
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

COMMENT ON TABLE platform.universes IS
  'Top-level grouping of ecosystems into 5-7 universes. '
  'universe_code is the canonical identifier used in brain.event_queue.source_universe '
  'and audit.activity_log.universe. Supports the 60→5-7 consolidation plan.';


COMMIT;


-- =============================================================================
-- LAYER B: ECOSYSTEM REGISTRY
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- B.1  platform.ecosystems
--      Every E## ecosystem in the platform. This is the master registry.
--      Links to a universe. Tracks lifecycle, versioning, and configuration.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS platform.ecosystems (

    ecosystem_id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    ecosystem_code          TEXT            NOT NULL UNIQUE,
        -- The canonical E## code: 'E00','E01','E02',...'E60'
    ecosystem_name          TEXT            NOT NULL,
        -- Human-readable: 'Donor Intelligence', 'Donation Processing', etc.
    short_name              TEXT,
        -- Abbreviated: 'DonorIntel', 'DonProc', etc.
    description             TEXT,

    -- Universe assignment (supports consolidation)
    universe_id             UUID
                                REFERENCES platform.universes (universe_id)
                                ON DELETE SET NULL ON UPDATE CASCADE,

    -- Tier / Classification
    tier                    INTEGER         NOT NULL DEFAULT 1
                                CHECK (tier BETWEEN 1 AND 10),
        -- From the inventory: Tier 1 (Core Data) through Tier 8 (GPU/AI)
    tier_name               TEXT,
        -- 'Core Data', 'Content & AI', 'Media & Advertising', etc.
    category                TEXT,
        -- 'data','content','media','portal','communication','operations',
        -- 'analytics','automation','video','infrastructure','special'

    -- Status & Lifecycle
    status                  TEXT            NOT NULL DEFAULT 'active'
                                CHECK (status IN (
                                    'concept','development','testing','active',
                                    'maintenance','deprecated','archived','merged'
                                )),
    is_core                 BOOLEAN         NOT NULL DEFAULT FALSE,
        -- TRUE for ecosystems that are foundational (E00, E01, E20, E51, etc.)

    -- Versioning
    current_version         TEXT            NOT NULL DEFAULT '1.0.0',
        -- Semantic versioning: major.minor.patch
    version_date            DATE,
    next_version            TEXT,
    next_version_eta        DATE,

    -- Valuation (from inventory)
    estimated_value         NUMERIC(12,2),

    -- Technical
    python_module           TEXT,
        -- Primary Python file: 'ecosystem_01_donor_intelligence.py'
    python_variants         TEXT[],
        -- Variant files: ['ecosystem_01_donor_intelligence.py']
    api_endpoint            TEXT,
        -- Base API path if applicable: '/api/v1/donor-intelligence'
    has_frontend            BOOLEAN         NOT NULL DEFAULT FALSE,
    has_api                 BOOLEAN         NOT NULL DEFAULT FALSE,
    has_background_jobs     BOOLEAN         NOT NULL DEFAULT FALSE,

    -- AI Integration
    ai_model_required       TEXT,
        -- Which AI model this ecosystem needs: 'gpt-4', 'claude-3', 'local-llm'
    ai_capabilities         JSONB           NOT NULL DEFAULT '[]',
        -- ['content_generation','scoring','matching','classification','prediction']

    -- Resource requirements
    resource_profile        JSONB           NOT NULL DEFAULT '{}',
        -- { "cpu_cores": 2, "memory_gb": 4, "gpu_required": false,
        --   "storage_gb": 10, "estimated_qps": 100 }

    -- Dependencies on other ecosystems (lightweight — detailed in ecosystem_dependencies)
    depends_on              TEXT[],
        -- ['E00','E01','E20'] — ecosystem codes this one requires

    -- Configuration
    default_config          JSONB           NOT NULL DEFAULT '{}',
        -- Default configuration applied to all candidates unless overridden
    feature_flags           JSONB           NOT NULL DEFAULT '{}',
        -- { "new_scoring_model": true, "beta_ui": false, "v2_pipeline": true }

    -- Metadata
    owner                   TEXT,
        -- Team or person responsible
    documentation_url       TEXT,
    notes                   TEXT,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

CREATE OR REPLACE TRIGGER trg_ecosystems_updated_at
    BEFORE UPDATE ON platform.ecosystems
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE INDEX IF NOT EXISTS idx_eco_universe
    ON platform.ecosystems (universe_id);

CREATE INDEX IF NOT EXISTS idx_eco_status
    ON platform.ecosystems (status);

CREATE INDEX IF NOT EXISTS idx_eco_tier
    ON platform.ecosystems (tier);

CREATE INDEX IF NOT EXISTS idx_eco_category
    ON platform.ecosystems (category);

CREATE INDEX IF NOT EXISTS idx_eco_core
    ON platform.ecosystems (ecosystem_code)
    WHERE is_core = TRUE;

CREATE INDEX IF NOT EXISTS idx_eco_feature_flags_gin
    ON platform.ecosystems USING GIN (feature_flags);

COMMENT ON TABLE platform.ecosystems IS
  'Master registry of all E## ecosystems. One row per ecosystem. '
  'ecosystem_code is the canonical E## identifier (E00-E60+). '
  'Links to platform.universes for the 60→5-7 consolidation. '
  'Tracks version history, AI capabilities, resource needs, and dependencies. '
  'feature_flags JSONB controls runtime feature toggling per ecosystem.';


-- ---------------------------------------------------------------------------
-- B.2  platform.ecosystem_dependencies
--      Explicit dependency graph between ecosystems. Which ecosystems
--      require which other ecosystems to function.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS platform.ecosystem_dependencies (

    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    ecosystem_id            UUID            NOT NULL
                                REFERENCES platform.ecosystems (ecosystem_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    depends_on_id           UUID            NOT NULL
                                REFERENCES platform.ecosystems (ecosystem_id)
                                ON DELETE RESTRICT ON UPDATE CASCADE,

    dependency_type         TEXT            NOT NULL DEFAULT 'required'
                                CHECK (dependency_type IN (
                                    'required',     -- hard dependency, cannot function without
                                    'optional',     -- enhanced by, but works without
                                    'data_feed',    -- receives data from
                                    'event_source', -- listens to events from
                                    'ui_embed'      -- embeds UI components from
                                )),

    description             TEXT,
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_ecosystem_dep UNIQUE (ecosystem_id, depends_on_id)

);

CREATE INDEX IF NOT EXISTS idx_edep_ecosystem
    ON platform.ecosystem_dependencies (ecosystem_id);

CREATE INDEX IF NOT EXISTS idx_edep_depends_on
    ON platform.ecosystem_dependencies (depends_on_id);

COMMENT ON TABLE platform.ecosystem_dependencies IS
  'Dependency graph between ecosystems. ecosystem_id depends on depends_on_id. '
  'dependency_type controls whether the dependency is hard (required) or soft (optional). '
  'Used by the deployment pipeline to determine startup order and by the Brain to '
  'understand which ecosystems must be active for a candidate.';


COMMIT;


-- =============================================================================
-- LAYER C: FEATURE TRACKING
-- =============================================================================
-- Features are the individual capabilities within each ecosystem.
-- They can be added, revised, deprecated, and toggled per candidate.

BEGIN;

-- ---------------------------------------------------------------------------
-- C.1  platform.ecosystem_features
--      Individual features within each ecosystem. The unit of work
--      that gets added, revised, or deprecated over time.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS platform.ecosystem_features (

    feature_id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    ecosystem_id            UUID            NOT NULL
                                REFERENCES platform.ecosystems (ecosystem_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    -- Identity
    feature_code            TEXT            NOT NULL,
        -- Short code within the ecosystem: 'dual_grading', 'cluster_scoring',
        -- 'ai_content_gen', 'realtime_dashboard', 'webhook_intake', etc.
    feature_name            TEXT            NOT NULL,
    description             TEXT,

    -- Classification
    feature_type            TEXT            NOT NULL DEFAULT 'core'
                                CHECK (feature_type IN (
                                    'core',         -- essential to the ecosystem
                                    'enhancement',  -- adds capability
                                    'integration',  -- connects to external system
                                    'ai_powered',   -- requires AI model
                                    'experimental', -- beta / testing
                                    'deprecated'    -- being phased out
                                )),
    category                TEXT,
        -- 'data_processing','ui','api','reporting','automation','scoring',
        -- 'communication','analytics','compliance','content','field_ops'

    -- Status & Lifecycle
    status                  TEXT            NOT NULL DEFAULT 'active'
                                CHECK (status IN (
                                    'planned','development','testing','active',
                                    'paused','deprecated','removed'
                                )),
    introduced_version      TEXT,
        -- Which ecosystem version added this feature: '1.0.0', '2.1.0'
    deprecated_version      TEXT,
        -- Which version deprecated it (NULL if still active)
    removed_version         TEXT,

    -- Priority / Importance
    priority                INTEGER         NOT NULL DEFAULT 50
                                CHECK (priority BETWEEN 1 AND 100),
        -- 100 = critical, 1 = nice-to-have

    -- Configuration
    default_enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    config_schema           JSONB           NOT NULL DEFAULT '{}',
        -- JSON Schema defining the configuration options for this feature
        -- { "type": "object", "properties": {
        --     "threshold": {"type": "number", "default": 0.8},
        --     "model": {"type": "string", "enum": ["gpt-4","claude-3"]},
        --     "max_daily": {"type": "integer", "default": 1000}
        -- }}
    default_config          JSONB           NOT NULL DEFAULT '{}',
        -- Default configuration values

    -- Resource impact
    resource_impact         TEXT            NOT NULL DEFAULT 'low'
                                CHECK (resource_impact IN ('minimal','low','medium','high','critical')),
    requires_gpu            BOOLEAN         NOT NULL DEFAULT FALSE,
    estimated_cost_monthly  NUMERIC(10,2),
        -- Estimated monthly cost to run this feature per candidate

    -- Dependencies
    depends_on_features     UUID[],
        -- Other feature_ids this feature requires (within same or other ecosystem)
    conflicts_with          UUID[],
        -- Features that cannot be active simultaneously

    -- Metadata
    documentation_url       TEXT,
    release_notes           TEXT,
    owner                   TEXT,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_ecosystem_feature UNIQUE (ecosystem_id, feature_code)

);

CREATE OR REPLACE TRIGGER trg_eco_features_updated_at
    BEFORE UPDATE ON platform.ecosystem_features
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE INDEX IF NOT EXISTS idx_ef_ecosystem
    ON platform.ecosystem_features (ecosystem_id);

CREATE INDEX IF NOT EXISTS idx_ef_status
    ON platform.ecosystem_features (status);

CREATE INDEX IF NOT EXISTS idx_ef_type
    ON platform.ecosystem_features (feature_type);

CREATE INDEX IF NOT EXISTS idx_ef_active
    ON platform.ecosystem_features (ecosystem_id, feature_code)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_ef_config_gin
    ON platform.ecosystem_features USING GIN (config_schema);

COMMENT ON TABLE platform.ecosystem_features IS
  'Individual features within each ecosystem. The unit of evolution. '
  'Features are added, revised, deprecated over time. Each has a config_schema '
  '(JSON Schema) defining how it can be configured per candidate. '
  'default_enabled controls whether new candidates get this feature by default. '
  'resource_impact and estimated_cost help with capacity planning.';


-- ---------------------------------------------------------------------------
-- C.2  platform.ecosystem_versions
--      Version history for each ecosystem. Every time an ecosystem is
--      revised (features added/changed/removed), a version snapshot is
--      recorded here.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS platform.ecosystem_versions (

    version_id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    ecosystem_id            UUID            NOT NULL
                                REFERENCES platform.ecosystems (ecosystem_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    -- Version info
    version                 TEXT            NOT NULL,
        -- Semantic version: '1.0.0', '1.1.0', '2.0.0'
    version_type            TEXT            NOT NULL DEFAULT 'minor'
                                CHECK (version_type IN ('major','minor','patch','hotfix')),
    release_date            DATE            NOT NULL DEFAULT CURRENT_DATE,

    -- Change summary
    summary                 TEXT,
    changelog               JSONB           NOT NULL DEFAULT '[]',
        -- [{ "type": "added", "feature": "dual_grading", "description": "..." },
        --  { "type": "changed", "feature": "scoring", "description": "..." },
        --  { "type": "deprecated", "feature": "old_pipeline", "description": "..." },
        --  { "type": "removed", "feature": "legacy_import", "description": "..." }]

    -- Snapshot of feature state at this version
    features_snapshot       JSONB           NOT NULL DEFAULT '{}',
        -- { "active": ["feature_a","feature_b"], "deprecated": ["feature_c"],
        --   "total_features": 12, "ai_features": 4 }

    -- Migration info
    migration_file          TEXT,
        -- Path to migration SQL if any: 'database/migrations/102_e01_v2.sql'
    requires_restart        BOOLEAN         NOT NULL DEFAULT FALSE,
    breaking_changes        BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Approval
    approved_by             TEXT,
    approved_at             TIMESTAMPTZ,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_ecosystem_version UNIQUE (ecosystem_id, version)

);

CREATE INDEX IF NOT EXISTS idx_ev_ecosystem
    ON platform.ecosystem_versions (ecosystem_id, release_date DESC);

CREATE INDEX IF NOT EXISTS idx_ev_date
    ON platform.ecosystem_versions (release_date DESC);

COMMENT ON TABLE platform.ecosystem_versions IS
  'Version history for each ecosystem. Records every revision with a changelog, '
  'feature snapshot, and migration reference. Enables rollback tracking and '
  'audit of how each ecosystem evolved over time.';


COMMIT;


-- =============================================================================
-- LAYER D: PER-CANDIDATE ECOSYSTEM ACTIVATION
-- =============================================================================
-- Which ecosystems and features are active for which candidates.

BEGIN;

-- ---------------------------------------------------------------------------
-- D.1  platform.candidate_ecosystems
--      Per-candidate ecosystem activation. Controls which ecosystems
--      are active for each candidate, with per-candidate config overrides.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS platform.candidate_ecosystems (

    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    candidate_id            UUID            NOT NULL
                                REFERENCES core.candidates (candidate_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    ecosystem_id            UUID            NOT NULL
                                REFERENCES platform.ecosystems (ecosystem_id)
                                ON DELETE RESTRICT ON UPDATE CASCADE,

    campaign_id             UUID
                                REFERENCES core.campaigns (campaign_id)
                                ON DELETE SET NULL ON UPDATE CASCADE,

    -- Activation
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    activated_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deactivated_at          TIMESTAMPTZ,

    -- Configuration override (merges with ecosystem.default_config)
    config_override         JSONB           NOT NULL DEFAULT '{}',
        -- Per-candidate config that overrides ecosystem defaults

    -- Feature toggles for this candidate (overrides feature.default_enabled)
    feature_overrides       JSONB           NOT NULL DEFAULT '{}',
        -- { "dual_grading": true, "beta_ui": false, "v2_pipeline": true }
        -- NULL/missing key = use ecosystem feature default

    -- Subscription tier controls available features
    tier_override           TEXT,
        -- NULL = use candidate's subscription_tier from core.candidates
        -- Allows per-ecosystem tier upgrade: candidate is 'basic' overall
        -- but 'premium' for E01 Donor Intelligence

    -- Metrics (cached)
    events_processed        BIGINT          NOT NULL DEFAULT 0,
    last_event_at           TIMESTAMPTZ,
    error_count             INTEGER         NOT NULL DEFAULT 0,
    last_error              TEXT,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_candidate_ecosystem UNIQUE (candidate_id, ecosystem_id)

);

CREATE OR REPLACE TRIGGER trg_ce_updated_at
    BEFORE UPDATE ON platform.candidate_ecosystems
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE INDEX IF NOT EXISTS idx_ce_candidate
    ON platform.candidate_ecosystems (candidate_id);

CREATE INDEX IF NOT EXISTS idx_ce_ecosystem
    ON platform.candidate_ecosystems (ecosystem_id);

CREATE INDEX IF NOT EXISTS idx_ce_campaign
    ON platform.candidate_ecosystems (campaign_id)
    WHERE campaign_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ce_active
    ON platform.candidate_ecosystems (candidate_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_ce_feature_overrides_gin
    ON platform.candidate_ecosystems USING GIN (feature_overrides);

COMMENT ON TABLE platform.candidate_ecosystems IS
  'Per-candidate ecosystem activation. Controls which ecosystems are active for '
  'each candidate with config overrides and feature toggles. '
  'feature_overrides JSONB allows per-candidate feature control without modifying '
  'the global ecosystem feature definitions. tier_override enables per-ecosystem '
  'subscription tier upgrades.';


-- ---------------------------------------------------------------------------
-- D.2  platform.candidate_feature_config
--      Granular per-candidate, per-feature configuration.
--      For features that need detailed per-candidate settings beyond
--      the simple enable/disable in candidate_ecosystems.feature_overrides.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS platform.candidate_feature_config (

    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    candidate_id            UUID            NOT NULL
                                REFERENCES core.candidates (candidate_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    feature_id              UUID            NOT NULL
                                REFERENCES platform.ecosystem_features (feature_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    campaign_id             UUID
                                REFERENCES core.campaigns (campaign_id)
                                ON DELETE SET NULL ON UPDATE CASCADE,

    -- Activation
    is_enabled              BOOLEAN         NOT NULL DEFAULT TRUE,

    -- Per-candidate feature configuration (validated against feature.config_schema)
    config                  JSONB           NOT NULL DEFAULT '{}',
        -- e.g. for E09 Content Creation AI:
        -- { "model": "gpt-4", "tone": "aggressive", "max_daily_posts": 5,
        --   "topics_focus": ["economy","border"], "topics_avoid": ["abortion"] }

    -- Scheduling (some features run on schedules)
    schedule                TEXT,
        -- Cron expression: '0 8 * * *' = daily at 8am

    -- Metadata
    configured_by           TEXT,
    notes                   TEXT,

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_candidate_feature UNIQUE (candidate_id, feature_id)

);

CREATE OR REPLACE TRIGGER trg_cfc_updated_at
    BEFORE UPDATE ON platform.candidate_feature_config
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE INDEX IF NOT EXISTS idx_cfc_candidate
    ON platform.candidate_feature_config (candidate_id);

CREATE INDEX IF NOT EXISTS idx_cfc_feature
    ON platform.candidate_feature_config (feature_id);

CREATE INDEX IF NOT EXISTS idx_cfc_active
    ON platform.candidate_feature_config (candidate_id)
    WHERE is_enabled = TRUE;

COMMENT ON TABLE platform.candidate_feature_config IS
  'Granular per-candidate, per-feature configuration. For features needing '
  'detailed settings beyond enable/disable. config JSONB is validated against '
  'the feature config_schema. Allows each candidate to customize AI models, '
  'thresholds, schedules, and behavior per feature.';


COMMIT;


-- =============================================================================
-- LAYER E: ECOSYSTEM HEALTH & METRICS
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- E.1  platform.ecosystem_health
--      Real-time health monitoring for each ecosystem. Updated by the
--      pipeline and monitoring agents. Powers the operations dashboard.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS platform.ecosystem_health (

    health_id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    ecosystem_id            UUID            NOT NULL
                                REFERENCES platform.ecosystems (ecosystem_id)
                                ON DELETE CASCADE ON UPDATE CASCADE,

    -- Time period
    check_time              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Health status
    status                  TEXT            NOT NULL DEFAULT 'healthy'
                                CHECK (status IN ('healthy','degraded','critical','offline','maintenance')),
    uptime_pct              NUMERIC(5,2),   -- 0-100
    response_time_ms        INTEGER,        -- avg response time
    error_rate_pct          NUMERIC(5,2),   -- 0-100

    -- Volume metrics
    events_in               BIGINT          NOT NULL DEFAULT 0,
    events_out              BIGINT          NOT NULL DEFAULT 0,
    events_failed           BIGINT          NOT NULL DEFAULT 0,
    queue_depth             INTEGER         NOT NULL DEFAULT 0,

    -- Resource usage
    cpu_pct                 NUMERIC(5,2),
    memory_mb               INTEGER,
    active_connections      INTEGER,

    -- Feature health
    features_active         INTEGER         NOT NULL DEFAULT 0,
    features_degraded       INTEGER         NOT NULL DEFAULT 0,
    features_offline        INTEGER         NOT NULL DEFAULT 0,

    -- Candidate coverage
    candidates_active       INTEGER         NOT NULL DEFAULT 0,
    candidates_with_errors  INTEGER         NOT NULL DEFAULT 0,

    -- Alerts
    active_alerts           JSONB           NOT NULL DEFAULT '[]',
        -- [{"severity":"warning","message":"Queue depth > 1000","since":"..."}]

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()

);

CREATE INDEX IF NOT EXISTS idx_eh_ecosystem
    ON platform.ecosystem_health (ecosystem_id, check_time DESC);

CREATE INDEX IF NOT EXISTS idx_eh_status
    ON platform.ecosystem_health (status, check_time DESC);

CREATE INDEX IF NOT EXISTS idx_eh_time
    ON platform.ecosystem_health (check_time DESC);

-- Keep only latest per ecosystem for fast lookups
CREATE UNIQUE INDEX IF NOT EXISTS uidx_eh_latest
    ON platform.ecosystem_health (ecosystem_id, check_time);

COMMENT ON TABLE platform.ecosystem_health IS
  'Real-time health monitoring for each ecosystem. Written by the monitoring '
  'pipeline on a schedule (every 5-15 minutes for active ecosystems). '
  'Powers the E51 PRIME COMMAND operations dashboard and alerting.';


COMMIT;


-- =============================================================================
-- LAYER F: SEED DATA — UNIVERSE + ECOSYSTEM REGISTRY
-- =============================================================================

BEGIN;

-- Seed the 7 universes
INSERT INTO platform.universes (universe_code, universe_name, description, display_order)
VALUES
    ('DATA',    'Data & Intelligence',      'Core data infrastructure, donor intelligence, analytics, ML clustering. E00-E06, E21.', 1),
    ('COMMS',   'Communications & Outreach','All communication channels: email, SMS, phone, direct mail, messenger, unified inbox. E30-E36, E48, E57.', 2),
    ('MEDIA',   'Media & Content',          'Content creation, video, broadcast, TV/radio, social media, print. E08-E09, E14, E16-E19, E45-E47.', 3),
    ('OPS',     'Campaign Operations',      'Campaign management, field ops, events, volunteer coordination, automation. E05, E12, E34, E37-E41, E43.', 4),
    ('INTEL',   'Intelligence & Brain',     'AI Brain, compliance, issue tracking, news intelligence, A/B testing, engagement psychology. E07, E10, E13, E20, E22, E42, E60.', 5),
    ('PORTAL',  'Portals & Dashboards',     'User-facing portals and dashboards: candidate, donor, volunteer, analytics, financial, realtime. E24-E29.', 6),
    ('INFRA',   'Infrastructure & Platform','API gateway, GPU orchestration, NEXUS AI, vendor management, calendar, prime command. E11, E23, E28, E44, E50-E55.', 7)
ON CONFLICT (universe_code) DO NOTHING;


-- Seed the full ecosystem registry (59 ecosystems from inventory + newer ones)
-- Note: universe_id will be updated in a second pass after both tables exist

INSERT INTO platform.ecosystems (ecosystem_code, ecosystem_name, tier, tier_name, category, status, is_core, estimated_value, python_module)
VALUES
    -- Tier 1: Core Data Infrastructure
    ('E00', 'DataHub',                    1, 'Core Data', 'data',           'active', TRUE,  150000, 'ecosystem_00_datahub.py'),
    ('E01', 'Donor Intelligence',         1, 'Core Data', 'data',           'active', TRUE,  120000, 'ecosystem_01_donor_intelligence.py'),
    ('E02', 'Donation Processing',        1, 'Core Data', 'data',           'active', TRUE,   90000, 'ecosystem_02_donation_processing.py'),
    ('E03', 'Candidate Management',       1, 'Core Data', 'data',           'active', TRUE,   80000, 'ecosystem_03_candidate_profiles.py'),
    ('E04', 'Activist Network',           1, 'Core Data', 'data',           'active', FALSE,  85000, 'ecosystem_04_activist_network.py'),
    ('E05', 'Volunteer Management',       1, 'Core Data', 'operations',     'active', FALSE,  75000, 'ecosystem_05_volunteer_management.py'),
    ('E06', 'Analytics Engine',           1, 'Core Data', 'analytics',      'active', TRUE,   95000, 'ecosystem_06_analytics_engine.py'),
    ('E07', 'Issue Tracking',             1, 'Core Data', 'analytics',      'active', FALSE,  65000, 'ecosystem_07_issue_tracking.py'),

    -- Tier 2: Content & AI
    ('E08', 'Communications Library',     2, 'Content & AI', 'content',     'active', FALSE,  55000, 'ecosystem_08_communications_library.py'),
    ('E09', 'Content Creation AI',        2, 'Content & AI', 'content',     'active', FALSE,  70000, 'ecosystem_09_content_creation_ai.py'),
    ('E10', 'Compliance Manager',         2, 'Content & AI', 'compliance',  'active', TRUE,   60000, 'ecosystem_10_compliance_manager.py'),
    ('E11', 'Budget Management',          2, 'Content & AI', 'operations',  'active', FALSE,  65000, 'ecosystem_11_budget_management.py'),
    ('E12', 'Campaign Operations',        2, 'Content & AI', 'operations',  'active', FALSE,  70000, 'ecosystem_12_campaign_operations.py'),
    ('E13', 'AI Hub',                     2, 'Content & AI', 'automation',  'active', TRUE,   85000, 'ecosystem_13_ai_hub.py'),
    ('E14', 'Print Production',           2, 'Content & AI', 'media',       'active', FALSE,  50000, 'ecosystem_14_print_production.py'),
    ('E15', 'Contact Management',         2, 'Content & AI', 'data',        'active', FALSE,  40000, 'ecosystem_15_contact_directory.py'),

    -- Tier 3: Media & Advertising
    ('E16', 'TV/Radio AI',                3, 'Media & Advertising', 'media', 'active', FALSE, 120000, 'ecosystem_16_tv_radio.py'),
    ('E17', 'RVM System',                 3, 'Media & Advertising', 'communication', 'active', FALSE, 55000, 'ecosystem_17_rvm.py'),
    ('E18', 'VDP Composition',            3, 'Media & Advertising', 'media', 'active', FALSE,  65000, 'ecosystem_18_vdp_composition_engine.py'),
    ('E19', 'Social Media',               3, 'Media & Advertising', 'media', 'active', FALSE,  80000, 'ecosystem_19_social_media_manager.py'),
    ('E20', 'Intelligence Brain',         3, 'Media & Advertising', 'automation', 'active', TRUE, 150000, 'ecosystem_20_intelligence_brain.py'),
    ('E21', 'ML Clustering',              3, 'Media & Advertising', 'analytics', 'active', FALSE, 85000, 'ecosystem_21_ml_clustering.py'),

    -- Tier 4: Dashboards & Portals
    ('E22', 'A/B Testing Engine',         4, 'Dashboards & Portals', 'analytics', 'active', FALSE, 60000, 'ecosystem_22_ab_testing_engine.py'),
    ('E23', 'Creative Asset 3D',          4, 'Dashboards & Portals', 'media', 'active', FALSE,  75000, 'ecosystem_23_creative_asset_3d_engine.py'),
    ('E24', 'Candidate Portal',           4, 'Dashboards & Portals', 'portal', 'active', FALSE,  65000, 'ecosystem_24_candidate_portal.py'),
    ('E25', 'Donor Portal',              4, 'Dashboards & Portals', 'portal', 'active', FALSE,  55000, 'ecosystem_25_donor_portal.py'),
    ('E26', 'Volunteer Portal',           4, 'Dashboards & Portals', 'portal', 'active', FALSE,  50000, 'ecosystem_26_volunteer_portal.py'),
    ('E27', 'Realtime Dashboard',         4, 'Dashboards & Portals', 'portal', 'active', FALSE,  70000, 'ecosystem_27_realtime_dashboard.py'),
    ('E28', 'Financial Dashboard',        4, 'Dashboards & Portals', 'portal', 'active', FALSE,  55000, 'ecosystem_28_financial_dashboard.py'),
    ('E29', 'Analytics Dashboard',        4, 'Dashboards & Portals', 'portal', 'active', FALSE,  60000, 'ecosystem_29_analytics_dashboard.py'),

    -- Tier 5: Communication Channels
    ('E30', 'Email Campaigns',            5, 'Communication Channels', 'communication', 'active', FALSE, 75000, 'ecosystem_30_email.py'),
    ('E31', 'SMS Marketing',              5, 'Communication Channels', 'communication', 'active', FALSE, 55000, 'ecosystem_31_sms.py'),
    ('E32', 'Phone Call Center',          5, 'Communication Channels', 'communication', 'active', FALSE, 65000, 'ecosystem_32_phone_banking.py'),
    ('E33', 'Direct Mail',               5, 'Communication Channels', 'communication', 'active', FALSE, 70000, 'ecosystem_33_direct_mail.py'),
    ('E34', 'Events',                     5, 'Communication Channels', 'operations', 'active', FALSE,  50000, 'ecosystem_34_events.py'),
    ('E35', 'Unified Inbox',             5, 'Communication Channels', 'communication', 'active', FALSE, 60000, 'ecosystem_35_interactive_comm_hub.py'),
    ('E36', 'Messenger',                  5, 'Communication Channels', 'communication', 'active', FALSE, 45000, 'ecosystem_36_messenger_integration.py'),

    -- Tier 6: Advanced Features
    ('E37', 'Event Management',           6, 'Advanced Features', 'operations', 'active', FALSE,  55000, 'ecosystem_37_event_management.py'),
    ('E38', 'Field Operations',           6, 'Advanced Features', 'operations', 'active', FALSE,  50000, 'ecosystem_38_volunteer_coordination.py'),
    ('E39', 'P2P Fundraising',           6, 'Advanced Features', 'operations', 'active', FALSE,  65000, 'ecosystem_39_p2p_fundraising.py'),
    ('E40', 'Automation Control',         6, 'Advanced Features', 'automation', 'active', FALSE,  70000, 'ecosystem_40_automation_control_panel.py'),
    ('E41', 'Campaign Builder',           6, 'Advanced Features', 'operations', 'active', FALSE,  75000, 'ecosystem_41_campaign_builder.py'),
    ('E42', 'News Intelligence',          6, 'Advanced Features', 'analytics', 'active', FALSE,  85000, 'ecosystem_42_news_intelligence.py'),
    ('E43', 'Advocacy',                   6, 'Advanced Features', 'operations', 'active', FALSE,  55000, 'ecosystem_43_advocacy_tools.py'),
    ('E44', 'Vendor Management',          6, 'Advanced Features', 'infrastructure', 'active', FALSE, 60000, 'ecosystem_44_vendor_compliance_security.py'),

    -- Tier 7: Video & Broadcast
    ('E45', 'Video Studio',              7, 'Video & Broadcast', 'media',  'active', FALSE,  95000, 'ecosystem_45_video_studio.py'),
    ('E46', 'Broadcast Hub',             7, 'Video & Broadcast', 'media',  'active', FALSE,  70000, 'ecosystem_46_broadcast_hub.py'),
    ('E47', 'AI Script Generator',       7, 'Video & Broadcast', 'content','active', FALSE,  55000, 'ecosystem_47_ai_script_generator.py'),
    ('E48', 'Communication DNA',         7, 'Video & Broadcast', 'communication', 'active', FALSE, 65000, 'ecosystem_48_communication_dna.py'),
    ('E49', 'Interview System',          7, 'Video & Broadcast', 'media',  'active', FALSE,  65000, 'ecosystem_49_interview_system.py'),

    -- Tier 8: GPU & AI Orchestration
    ('E50', 'GPU Orchestrator',          8, 'GPU & AI Orchestration', 'infrastructure', 'active', FALSE, 85000, 'ecosystem_50_gpu_orchestrator.py'),
    ('E51', 'NEXUS AI / Prime Command',  8, 'GPU & AI Orchestration', 'infrastructure', 'active', TRUE, 150000, 'ecosystem_51_nexus.py'),

    -- Tier 9: Extended Platform (E52+)
    ('E52', 'Contact Intelligence',      9, 'Extended Platform', 'data',   'active', FALSE, NULL, NULL),
    ('E53', 'Document Generation',       9, 'Extended Platform', 'content','active', FALSE, NULL, NULL),
    ('E54', 'Calendar',                  9, 'Extended Platform', 'operations', 'active', FALSE, NULL, NULL),
    ('E55', 'API Gateway',              9, 'Extended Platform', 'infrastructure', 'active', TRUE, NULL, NULL),
    ('E56', 'Visitor Deanonymization',   9, 'Extended Platform', 'analytics', 'development', FALSE, NULL, NULL),
    ('E57', 'Messaging Center',          9, 'Extended Platform', 'communication', 'active', FALSE, NULL, NULL),
    ('E59', 'Microsegment Intelligence', 9, 'Extended Platform', 'analytics', 'development', FALSE, NULL, NULL),
    ('E60', 'Psychology Engagement',     9, 'Extended Platform', 'automation', 'development', FALSE, NULL, NULL)

ON CONFLICT (ecosystem_code) DO NOTHING;


-- Link ecosystems to universes
UPDATE platform.ecosystems e
SET universe_id = u.universe_id
FROM platform.universes u
WHERE
    (e.ecosystem_code IN ('E00','E01','E02','E03','E04','E06','E15','E21','E52') AND u.universe_code = 'DATA')
    OR (e.ecosystem_code IN ('E30','E31','E32','E33','E35','E36','E48','E57','E17') AND u.universe_code = 'COMMS')
    OR (e.ecosystem_code IN ('E08','E09','E14','E16','E18','E19','E23','E45','E46','E47','E49','E53') AND u.universe_code = 'MEDIA')
    OR (e.ecosystem_code IN ('E05','E12','E34','E37','E38','E39','E41','E43','E54') AND u.universe_code = 'OPS')
    OR (e.ecosystem_code IN ('E07','E10','E13','E20','E22','E42','E56','E59','E60') AND u.universe_code = 'INTEL')
    OR (e.ecosystem_code IN ('E24','E25','E26','E27','E28','E29') AND u.universe_code = 'PORTAL')
    OR (e.ecosystem_code IN ('E11','E40','E44','E50','E51','E55') AND u.universe_code = 'INFRA');


COMMIT;


-- =============================================================================
-- VERIFICATION BLOCK
-- =============================================================================

DO $$
DECLARE
    v_universes     INTEGER;
    v_ecosystems    INTEGER;
    v_tables        INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_universes FROM platform.universes;
    SELECT COUNT(*) INTO v_ecosystems FROM platform.ecosystems;

    SELECT COUNT(*) INTO v_tables
    FROM information_schema.tables
    WHERE table_schema = 'platform'
      AND table_type = 'BASE TABLE';

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Ecosystem Registry Migration — VERIFY';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Tables in platform schema  : % / 7 expected', v_tables;
    RAISE NOTICE 'Universes registered       : % / 7 expected', v_universes;
    RAISE NOTICE 'Ecosystems registered      : % / 59 expected', v_ecosystems;

    IF v_tables < 7 THEN
        RAISE WARNING 'Expected 7 tables; only % found.', v_tables;
    ELSE
        RAISE NOTICE 'All 7 tables confirmed.';
    END IF;

    IF v_ecosystems < 50 THEN
        RAISE WARNING 'Expected ~59 ecosystems; only % found.', v_ecosystems;
    ELSE
        RAISE NOTICE 'Ecosystem count looks good.';
    END IF;

    RAISE NOTICE '=================================================';
END;
$$;


-- =============================================================================
-- END OF MIGRATION
-- =============================================================================
-- Summary of objects created:
--
-- NEW SCHEMA: platform
--
-- LAYER A — UNIVERSE DEFINITIONS (1 table):
--   platform.universes                     — 7 universe groups (DATA/COMMS/MEDIA/OPS/INTEL/PORTAL/INFRA)
--
-- LAYER B — ECOSYSTEM REGISTRY (2 tables):
--   platform.ecosystems                    — 59 ecosystem registrations (E00-E60)
--   platform.ecosystem_dependencies        — Inter-ecosystem dependency graph
--
-- LAYER C — FEATURE TRACKING (2 tables):
--   platform.ecosystem_features            — Individual features per ecosystem
--   platform.ecosystem_versions            — Version history / changelog
--
-- LAYER D — PER-CANDIDATE ACTIVATION (2 tables):
--   platform.candidate_ecosystems          — Which ecosystems active per candidate
--   platform.candidate_feature_config      — Per-candidate per-feature configuration
--
-- LAYER E — HEALTH MONITORING (1 table):
--   platform.ecosystem_health              — Real-time health metrics
--
-- SEED DATA:
--   7 universes, 59 ecosystems, universe→ecosystem linkage
--
-- EXISTING TABLES UNCHANGED.
-- =============================================================================
