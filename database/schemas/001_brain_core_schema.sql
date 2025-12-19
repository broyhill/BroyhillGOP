-- ============================================================================
-- BRAIN CONTROL SYSTEM - CORE SCHEMA
-- ============================================================================
-- File: 001_brain_core_schema.sql
-- Ecosystems, Functions, Configuration, and Audit Trail
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: ECOSYSTEM MANAGEMENT
-- ============================================================================

-- Master ecosystem registry (all 16 ecosystems)
CREATE TABLE ecosystems (
    ecosystem_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) UNIQUE NOT NULL,
    ecosystem_name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Technical configuration
    schema_name VARCHAR(50),
    api_prefix VARCHAR(100),
    api_base_url VARCHAR(500),
    port INTEGER,
    health_endpoint VARCHAR(200) DEFAULT '/health',
    
    -- Status & criticality
    status ecosystem_status DEFAULT 'ACTIVE',
    criticality criticality_level DEFAULT 'MEDIUM',
    
    -- Dependencies
    dependencies TEXT[] DEFAULT '{}',
    provides_to TEXT[] DEFAULT '{}',
    
    -- AI configuration
    ai_powered BOOLEAN DEFAULT false,
    ai_provider VARCHAR(50),
    ai_primary_model VARCHAR(100),
    
    -- Budget
    monthly_budget DECIMAL(12,2) DEFAULT 0,
    cost_center VARCHAR(50),
    
    -- Metrics
    tables_count INTEGER DEFAULT 0,
    functions_count INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100) DEFAULT 'system',
    
    -- Constraints
    CONSTRAINT chk_ecosystem_code CHECK (ecosystem_code ~ '^[A-Z_]+$')
);

-- Ecosystem health tracking (time-series)
CREATE TABLE ecosystem_health (
    health_id BIGSERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) NOT NULL REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    check_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- Status
    status ecosystem_status NOT NULL,
    
    -- Performance metrics
    response_time_ms INTEGER,
    throughput_rps DECIMAL(10,2),
    
    -- Resource utilization
    cpu_usage DECIMAL(5,2),
    memory_usage DECIMAL(5,2),
    disk_usage DECIMAL(5,2),
    
    -- Connections & queues
    active_connections INTEGER DEFAULT 0,
    max_connections INTEGER,
    queue_depth INTEGER DEFAULT 0,
    queue_latency_ms INTEGER,
    
    -- Error tracking
    error_rate DECIMAL(7,6) DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    last_error TEXT,
    last_error_at TIMESTAMPTZ,
    
    -- Degraded functions
    degraded_functions TEXT[] DEFAULT '{}',
    
    -- Index for efficient queries
    CONSTRAINT pk_ecosystem_health UNIQUE (ecosystem_code, check_timestamp)
);

-- Ecosystem configuration (key-value pairs)
CREATE TABLE ecosystem_config (
    config_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) NOT NULL REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    config_key VARCHAR(100) NOT NULL,
    config_value TEXT,
    value_type VARCHAR(20) DEFAULT 'string',
    description TEXT,
    is_sensitive BOOLEAN DEFAULT false,
    is_editable BOOLEAN DEFAULT true,
    requires_restart BOOLEAN DEFAULT false,
    validation_rules JSONB,
    version INTEGER DEFAULT 1,
    modified_at TIMESTAMPTZ DEFAULT NOW(),
    modified_by VARCHAR(100),
    
    CONSTRAINT uq_ecosystem_config UNIQUE (ecosystem_code, config_key)
);

-- Ecosystem dependencies tracking
CREATE TABLE ecosystem_dependencies (
    dependency_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(20) NOT NULL REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    depends_on VARCHAR(20) NOT NULL REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    dependency_type VARCHAR(50) DEFAULT 'required',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_ecosystem_dependency UNIQUE (ecosystem_code, depends_on),
    CONSTRAINT chk_no_self_dependency CHECK (ecosystem_code != depends_on)
);

-- ============================================================================
-- SECTION 2: FUNCTION MANAGEMENT
-- ============================================================================

-- Master function registry (all 35+ functions)
CREATE TABLE functions (
    function_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) UNIQUE NOT NULL,
    function_name VARCHAR(200) NOT NULL,
    ecosystem_code VARCHAR(20) NOT NULL REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    description TEXT,
    
    -- AI configuration
    is_ai_powered BOOLEAN DEFAULT false,
    ai_provider VARCHAR(50),
    ai_model VARCHAR(100),
    ai_fallback_model VARCHAR(100),
    
    -- Cost configuration
    cost_type cost_type DEFAULT 'per_call',
    unit_cost DECIMAL(10,6) DEFAULT 0,
    monthly_forecast_calls INTEGER,
    monthly_forecast_records INTEGER,
    monthly_forecast_cost DECIMAL(12,2) DEFAULT 0,
    
    -- Quality thresholds
    quality_floor DECIMAL(5,2) DEFAULT 80.00,
    effectiveness_floor DECIMAL(5,2) DEFAULT 80.00,
    latency_threshold_ms INTEGER DEFAULT 5000,
    error_rate_threshold DECIMAL(5,4) DEFAULT 0.05,
    
    -- Operational settings
    is_active BOOLEAN DEFAULT true,
    is_critical BOOLEAN DEFAULT false,
    requires_approval BOOLEAN DEFAULT false,
    batch_size INTEGER DEFAULT 100,
    timeout_seconds INTEGER DEFAULT 30,
    retry_count INTEGER DEFAULT 3,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100) DEFAULT 'system',
    
    -- Constraints
    CONSTRAINT chk_function_code CHECK (function_code ~ '^F[0-9]{3}$'),
    CONSTRAINT chk_quality_floor CHECK (quality_floor BETWEEN 0 AND 100),
    CONSTRAINT chk_effectiveness_floor CHECK (effectiveness_floor BETWEEN 0 AND 100)
);

-- Function configuration (editable parameters)
CREATE TABLE function_config (
    config_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    config_key VARCHAR(100) NOT NULL,
    config_value TEXT,
    value_type VARCHAR(20) DEFAULT 'string',
    description TEXT,
    default_value TEXT,
    min_value TEXT,
    max_value TEXT,
    allowed_values TEXT[],
    is_ai_prompt BOOLEAN DEFAULT false,
    is_editable BOOLEAN DEFAULT true,
    requires_restart BOOLEAN DEFAULT false,
    validation_rules JSONB,
    version INTEGER DEFAULT 1,
    modified_at TIMESTAMPTZ DEFAULT NOW(),
    modified_by VARCHAR(100),
    
    CONSTRAINT uq_function_config UNIQUE (function_code, config_key)
);

-- Function parameters history
CREATE TABLE function_parameters_history (
    history_id BIGSERIAL PRIMARY KEY,
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    parameter_snapshot JSONB NOT NULL,
    snapshot_reason VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100)
);

-- Function execution metrics (rolling aggregates)
CREATE TABLE function_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    period_type VARCHAR(20) DEFAULT 'hourly',
    
    -- Volume metrics
    total_calls INTEGER DEFAULT 0,
    total_records INTEGER DEFAULT 0,
    successful_calls INTEGER DEFAULT 0,
    failed_calls INTEGER DEFAULT 0,
    
    -- Performance metrics
    avg_latency_ms DECIMAL(10,2),
    p50_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    p99_latency_ms INTEGER,
    max_latency_ms INTEGER,
    
    -- Quality metrics
    quality_score DECIMAL(5,2),
    effectiveness_score DECIMAL(5,2),
    error_rate DECIMAL(7,6),
    
    -- Cost metrics
    total_cost DECIMAL(12,4) DEFAULT 0,
    avg_cost_per_call DECIMAL(10,6),
    
    -- AI-specific metrics
    ai_tokens_input INTEGER DEFAULT 0,
    ai_tokens_output INTEGER DEFAULT 0,
    ai_cost DECIMAL(10,4) DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_function_metrics UNIQUE (function_code, period_start, period_type)
);

-- ============================================================================
-- SECTION 3: AUDIT TRAIL
-- ============================================================================

-- Comprehensive audit log
CREATE TABLE audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    audit_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- What changed
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(100),
    action_type VARCHAR(20) NOT NULL,
    
    -- Context
    ecosystem_code VARCHAR(20),
    function_code VARCHAR(10),
    
    -- Change details
    field_changed VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    change_summary TEXT,
    
    -- Who changed it
    changed_by VARCHAR(100) NOT NULL,
    change_reason TEXT,
    
    -- Source information
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),
    
    -- Metadata
    metadata JSONB
);

-- ============================================================================
-- SECTION 4: INDEXES
-- ============================================================================

-- Ecosystem indexes
CREATE INDEX idx_ecosystems_status ON ecosystems(status);
CREATE INDEX idx_ecosystems_criticality ON ecosystems(criticality);

-- Ecosystem health indexes
CREATE INDEX idx_ecosystem_health_code ON ecosystem_health(ecosystem_code);
CREATE INDEX idx_ecosystem_health_timestamp ON ecosystem_health(check_timestamp DESC);
CREATE INDEX idx_ecosystem_health_status ON ecosystem_health(status);

-- Function indexes
CREATE INDEX idx_functions_ecosystem ON functions(ecosystem_code);
CREATE INDEX idx_functions_ai ON functions(is_ai_powered) WHERE is_ai_powered = true;
CREATE INDEX idx_functions_active ON functions(is_active) WHERE is_active = true;

-- Function metrics indexes
CREATE INDEX idx_function_metrics_code ON function_metrics(function_code);
CREATE INDEX idx_function_metrics_period ON function_metrics(period_start, period_end);
CREATE INDEX idx_function_metrics_type ON function_metrics(period_type);

-- Audit log indexes
CREATE INDEX idx_audit_log_timestamp ON audit_log(audit_timestamp DESC);
CREATE INDEX idx_audit_log_table ON audit_log(table_name);
CREATE INDEX idx_audit_log_ecosystem ON audit_log(ecosystem_code);
CREATE INDEX idx_audit_log_function ON audit_log(function_code);
CREATE INDEX idx_audit_log_user ON audit_log(changed_by);

-- ============================================================================
-- SECTION 5: COMMENTS
-- ============================================================================

COMMENT ON TABLE ecosystems IS 'Master registry of all 16 BroyhillGOP ecosystems';
COMMENT ON TABLE ecosystem_health IS 'Time-series health metrics for each ecosystem';
COMMENT ON TABLE functions IS 'Master registry of all platform functions';
COMMENT ON TABLE function_metrics IS 'Aggregated performance metrics for functions';
COMMENT ON TABLE audit_log IS 'Comprehensive audit trail for all changes';
