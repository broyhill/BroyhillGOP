-- ============================================================================
-- BRAIN CONTROL SYSTEM - CRM INTEGRATION
-- ============================================================================
-- File: 007_brain_crm.sql
-- CRM systems registry, field mappings, sync tracking
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: CRM SYSTEMS REGISTRY
-- ============================================================================

-- CRM systems
CREATE TABLE crm_systems (
    crm_id SERIAL PRIMARY KEY,
    crm_code VARCHAR(50) UNIQUE NOT NULL,
    crm_name VARCHAR(100) NOT NULL,
    crm_type VARCHAR(50) NOT NULL,
    
    -- API configuration
    api_base_url VARCHAR(500),
    api_version VARCHAR(20),
    auth_type VARCHAR(50) DEFAULT 'oauth2',
    
    -- Sync configuration
    sync_enabled BOOLEAN DEFAULT true,
    sync_frequency VARCHAR(20) DEFAULT 'hourly',
    sync_direction sync_direction DEFAULT 'bidirectional',
    
    -- Batch settings
    batch_size INTEGER DEFAULT 100,
    max_records_per_sync INTEGER DEFAULT 10000,
    
    -- Retry settings
    retry_count INTEGER DEFAULT 3,
    retry_delay_seconds INTEGER DEFAULT 60,
    
    -- Priority (lower = higher priority)
    priority INTEGER DEFAULT 100,
    is_primary BOOLEAN DEFAULT false,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active',
    last_sync_at TIMESTAMPTZ,
    last_sync_status VARCHAR(20),
    
    -- Connection info
    org_id VARCHAR(100),
    tenant_id VARCHAR(100),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- CRM entity types
CREATE TABLE crm_entity_types (
    entity_type_id SERIAL PRIMARY KEY,
    crm_code VARCHAR(50) NOT NULL REFERENCES crm_systems(crm_code) ON DELETE CASCADE,
    
    -- Entity details
    entity_name VARCHAR(100) NOT NULL,
    entity_label VARCHAR(100),
    crm_entity_name VARCHAR(100) NOT NULL,
    
    -- Sync settings
    sync_enabled BOOLEAN DEFAULT true,
    sync_direction sync_direction DEFAULT 'bidirectional',
    
    -- Key field
    brain_key_field VARCHAR(100),
    crm_key_field VARCHAR(100),
    
    -- Deduplication
    dedupe_fields TEXT[],
    
    -- Priority
    sync_priority INTEGER DEFAULT 100,
    
    CONSTRAINT uq_crm_entity UNIQUE (crm_code, entity_name)
);

-- ============================================================================
-- SECTION 2: FIELD MAPPINGS
-- ============================================================================

-- CRM field mappings
CREATE TABLE crm_field_mappings (
    mapping_id SERIAL PRIMARY KEY,
    crm_code VARCHAR(50) NOT NULL REFERENCES crm_systems(crm_code) ON DELETE CASCADE,
    entity_name VARCHAR(100) NOT NULL,
    
    -- Field mapping
    brain_field VARCHAR(100) NOT NULL,
    brain_table VARCHAR(100),
    crm_field VARCHAR(100) NOT NULL,
    
    -- Data types
    brain_data_type VARCHAR(50),
    crm_data_type VARCHAR(50),
    
    -- Direction
    sync_direction sync_direction DEFAULT 'bidirectional',
    
    -- Transformation
    transform_to_crm TEXT,
    transform_from_crm TEXT,
    
    -- Validation
    validation_rules JSONB,
    
    -- Settings
    is_required BOOLEAN DEFAULT false,
    is_key_field BOOLEAN DEFAULT false,
    default_value TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_field_mapping UNIQUE (crm_code, entity_name, brain_field)
);

-- Field mapping versions
CREATE TABLE crm_field_mapping_history (
    history_id SERIAL PRIMARY KEY,
    mapping_id INTEGER NOT NULL REFERENCES crm_field_mappings(mapping_id) ON DELETE CASCADE,
    
    -- Previous values
    previous_crm_field VARCHAR(100),
    previous_transform_to_crm TEXT,
    previous_transform_from_crm TEXT,
    
    -- Change info
    changed_by VARCHAR(100),
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    change_reason TEXT
);

-- ============================================================================
-- SECTION 3: SYNC TRACKING
-- ============================================================================

-- Sync jobs
CREATE TABLE crm_sync_jobs (
    job_id SERIAL PRIMARY KEY,
    job_uuid UUID DEFAULT gen_random_uuid(),
    crm_code VARCHAR(50) NOT NULL REFERENCES crm_systems(crm_code) ON DELETE CASCADE,
    
    -- Job configuration
    sync_direction sync_direction NOT NULL,
    entity_types TEXT[],
    is_full_sync BOOLEAN DEFAULT false,
    
    -- Timing
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    -- Progress
    status VARCHAR(20) DEFAULT 'running',
    progress_pct DECIMAL(5,2) DEFAULT 0,
    current_entity VARCHAR(100),
    
    -- Totals
    total_records INTEGER DEFAULT 0,
    records_processed INTEGER DEFAULT 0,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_deleted INTEGER DEFAULT 0,
    records_skipped INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    
    -- Performance
    duration_seconds INTEGER,
    records_per_second DECIMAL(10,2),
    
    -- Errors
    error_count INTEGER DEFAULT 0,
    last_error TEXT,
    
    -- Triggered by
    triggered_by VARCHAR(50) DEFAULT 'scheduler',
    triggered_by_user VARCHAR(100),
    
    -- Metadata
    metadata JSONB
);

-- Sync job details (per entity)
CREATE TABLE crm_sync_job_details (
    detail_id SERIAL PRIMARY KEY,
    job_id INTEGER NOT NULL REFERENCES crm_sync_jobs(job_id) ON DELETE CASCADE,
    
    -- Entity
    entity_name VARCHAR(100) NOT NULL,
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Counts
    records_processed INTEGER DEFAULT 0,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_deleted INTEGER DEFAULT 0,
    records_skipped INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending',
    error_message TEXT
);

-- Individual record sync log
CREATE TABLE crm_sync_records (
    record_id BIGSERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES crm_sync_jobs(job_id) ON DELETE SET NULL,
    
    -- Record identification
    crm_code VARCHAR(50) NOT NULL,
    entity_name VARCHAR(100) NOT NULL,
    brain_id VARCHAR(100),
    crm_id VARCHAR(100),
    
    -- Sync details
    sync_direction sync_direction NOT NULL,
    sync_action VARCHAR(20) NOT NULL,
    
    -- Timing
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Result
    success BOOLEAN NOT NULL,
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Data (for debugging)
    brain_data JSONB,
    crm_data JSONB,
    changes JSONB,
    
    -- Retry info
    retry_count INTEGER DEFAULT 0,
    next_retry_at TIMESTAMPTZ
);

-- Sync conflicts
CREATE TABLE crm_sync_conflicts (
    conflict_id SERIAL PRIMARY KEY,
    
    -- Record info
    crm_code VARCHAR(50) NOT NULL REFERENCES crm_systems(crm_code) ON DELETE CASCADE,
    entity_name VARCHAR(100) NOT NULL,
    brain_id VARCHAR(100),
    crm_id VARCHAR(100),
    
    -- Conflict details
    conflict_type VARCHAR(50) NOT NULL,
    field_name VARCHAR(100),
    brain_value TEXT,
    crm_value TEXT,
    
    -- Resolution
    status VARCHAR(20) DEFAULT 'pending',
    resolution VARCHAR(50),
    resolved_value TEXT,
    resolved_by VARCHAR(100),
    resolved_at TIMESTAMPTZ,
    
    -- Metadata
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

-- ============================================================================
-- SECTION 4: SYNC STATISTICS
-- ============================================================================

-- Daily sync statistics
CREATE TABLE crm_sync_statistics_daily (
    stat_id SERIAL PRIMARY KEY,
    crm_code VARCHAR(50) NOT NULL REFERENCES crm_systems(crm_code) ON DELETE CASCADE,
    stat_date DATE NOT NULL,
    
    -- Job counts
    total_jobs INTEGER DEFAULT 0,
    successful_jobs INTEGER DEFAULT 0,
    failed_jobs INTEGER DEFAULT 0,
    
    -- Record counts
    total_records_synced INTEGER DEFAULT 0,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_deleted INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    
    -- By direction
    to_crm_records INTEGER DEFAULT 0,
    from_crm_records INTEGER DEFAULT 0,
    
    -- Performance
    avg_sync_duration_seconds INTEGER,
    avg_records_per_second DECIMAL(10,2),
    
    -- Errors
    total_errors INTEGER DEFAULT 0,
    conflict_count INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_crm_sync_stats UNIQUE (crm_code, stat_date)
);

-- ============================================================================
-- SECTION 5: CRM WEBHOOKS
-- ============================================================================

-- Webhook configurations
CREATE TABLE crm_webhooks (
    webhook_id SERIAL PRIMARY KEY,
    crm_code VARCHAR(50) NOT NULL REFERENCES crm_systems(crm_code) ON DELETE CASCADE,
    
    -- Webhook details
    webhook_name VARCHAR(100) NOT NULL,
    webhook_url VARCHAR(500),
    webhook_secret VARCHAR(200),
    
    -- Events
    event_types TEXT[] NOT NULL,
    entity_types TEXT[],
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_crm_webhook UNIQUE (crm_code, webhook_name)
);

-- Webhook events log
CREATE TABLE crm_webhook_events (
    event_id BIGSERIAL PRIMARY KEY,
    webhook_id INTEGER REFERENCES crm_webhooks(webhook_id) ON DELETE SET NULL,
    crm_code VARCHAR(50) NOT NULL,
    
    -- Event details
    event_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(100),
    entity_id VARCHAR(100),
    
    -- Payload
    payload JSONB,
    
    -- Processing
    received_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'pending',
    
    -- Result
    success BOOLEAN,
    error_message TEXT,
    
    -- Actions taken
    actions_taken JSONB
);

-- ============================================================================
-- SECTION 6: INDEXES
-- ============================================================================

-- CRM systems
CREATE INDEX idx_crm_systems_type ON crm_systems(crm_type);
CREATE INDEX idx_crm_systems_status ON crm_systems(status);

-- Field mappings
CREATE INDEX idx_field_mappings_crm ON crm_field_mappings(crm_code);
CREATE INDEX idx_field_mappings_entity ON crm_field_mappings(entity_name);

-- Sync jobs
CREATE INDEX idx_sync_jobs_crm ON crm_sync_jobs(crm_code);
CREATE INDEX idx_sync_jobs_status ON crm_sync_jobs(status);
CREATE INDEX idx_sync_jobs_started ON crm_sync_jobs(started_at DESC);

-- Sync records
CREATE INDEX idx_sync_records_crm ON crm_sync_records(crm_code);
CREATE INDEX idx_sync_records_entity ON crm_sync_records(entity_name);
CREATE INDEX idx_sync_records_brain ON crm_sync_records(brain_id);
CREATE INDEX idx_sync_records_timestamp ON crm_sync_records(synced_at DESC);

-- Sync conflicts
CREATE INDEX idx_sync_conflicts_crm ON crm_sync_conflicts(crm_code);
CREATE INDEX idx_sync_conflicts_status ON crm_sync_conflicts(status);

-- Webhook events
CREATE INDEX idx_webhook_events_crm ON crm_webhook_events(crm_code);
CREATE INDEX idx_webhook_events_status ON crm_webhook_events(status);

-- ============================================================================
-- SECTION 7: COMMENTS
-- ============================================================================

COMMENT ON TABLE crm_systems IS 'Registry of connected CRM systems (Dynamics 365, EspoCRM)';
COMMENT ON TABLE crm_field_mappings IS 'Field-level mappings between BRAIN and CRM';
COMMENT ON TABLE crm_sync_jobs IS 'CRM synchronization job tracking';
COMMENT ON TABLE crm_sync_records IS 'Individual record sync audit log';
COMMENT ON TABLE crm_sync_conflicts IS 'Sync conflict detection and resolution';
