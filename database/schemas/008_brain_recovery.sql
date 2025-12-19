-- ============================================================================
-- BRAIN CONTROL SYSTEM - CRASH RECOVERY
-- ============================================================================
-- File: 008_brain_recovery.sql
-- Crash detection, recovery procedures, execution tracking
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: CRASH EVENTS
-- ============================================================================

-- Crash events log
CREATE TABLE crash_events (
    crash_id SERIAL PRIMARY KEY,
    crash_uuid UUID DEFAULT gen_random_uuid(),
    
    -- What crashed
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE SET NULL,
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE SET NULL,
    service_name VARCHAR(100),
    host_name VARCHAR(100),
    
    -- Crash details
    crash_type VARCHAR(50) NOT NULL,
    severity alert_severity NOT NULL,
    
    -- Error information
    error_code VARCHAR(100),
    error_message TEXT,
    stack_trace TEXT,
    
    -- Impact
    affected_functions TEXT[],
    affected_users INTEGER,
    estimated_impact TEXT,
    
    -- Timeline
    crash_timestamp TIMESTAMPTZ NOT NULL,
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    detection_method VARCHAR(50),
    detection_latency_seconds INTEGER,
    
    -- Recovery tracking
    recovery_attempted BOOLEAN DEFAULT false,
    recovery_started_at TIMESTAMPTZ,
    recovery_completed_at TIMESTAMPTZ,
    recovery_successful BOOLEAN,
    recovery_method VARCHAR(100),
    recovery_duration_seconds INTEGER,
    
    -- Manual intervention
    manual_intervention_required BOOLEAN DEFAULT false,
    manual_intervention_by VARCHAR(100),
    manual_intervention_at TIMESTAMPTZ,
    
    -- Resolution
    resolved_at TIMESTAMPTZ,
    resolution_type VARCHAR(50),
    resolution_notes TEXT,
    
    -- Alert reference
    alert_id INTEGER REFERENCES alerts(alert_id),
    
    -- Root cause analysis
    root_cause TEXT,
    contributing_factors TEXT[],
    prevention_measures TEXT,
    
    -- Metadata
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Crash event timeline (detailed event history)
CREATE TABLE crash_event_timeline (
    timeline_id SERIAL PRIMARY KEY,
    crash_id INTEGER NOT NULL REFERENCES crash_events(crash_id) ON DELETE CASCADE,
    
    -- Event details
    event_timestamp TIMESTAMPTZ DEFAULT NOW(),
    event_type VARCHAR(50) NOT NULL,
    event_description TEXT NOT NULL,
    
    -- Actor
    actor_type VARCHAR(20),
    actor_id VARCHAR(100),
    
    -- Metadata
    metadata JSONB
);

-- ============================================================================
-- SECTION 2: RECOVERY PROCEDURES
-- ============================================================================

-- Recovery procedure definitions
CREATE TABLE recovery_procedures (
    procedure_id SERIAL PRIMARY KEY,
    procedure_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Identification
    procedure_code VARCHAR(50) UNIQUE NOT NULL,
    procedure_name VARCHAR(200) NOT NULL,
    procedure_description TEXT,
    
    -- Scope
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    crash_types TEXT[],
    
    -- Procedure steps (JSON array)
    steps JSONB NOT NULL,
    
    -- Configuration
    timeout_minutes INTEGER DEFAULT 10,
    retry_count INTEGER DEFAULT 3,
    retry_delay_seconds INTEGER DEFAULT 30,
    
    -- Dependencies
    required_services TEXT[],
    required_permissions TEXT[],
    
    -- Approval
    requires_approval BOOLEAN DEFAULT false,
    approval_roles TEXT[],
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    
    -- Metrics
    times_executed INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    avg_duration_seconds INTEGER,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100)
);

-- Recovery procedure steps (detailed)
CREATE TABLE recovery_procedure_steps (
    step_id SERIAL PRIMARY KEY,
    procedure_id INTEGER NOT NULL REFERENCES recovery_procedures(procedure_id) ON DELETE CASCADE,
    
    -- Step details
    step_number INTEGER NOT NULL,
    step_name VARCHAR(100) NOT NULL,
    step_description TEXT,
    
    -- Action
    action_type VARCHAR(50) NOT NULL,
    action_config JSONB,
    
    -- Conditions
    preconditions JSONB,
    skip_conditions JSONB,
    
    -- Error handling
    on_error VARCHAR(50) DEFAULT 'stop',
    fallback_step INTEGER,
    
    -- Timing
    timeout_seconds INTEGER DEFAULT 60,
    
    -- Validation
    validation_checks JSONB,
    
    CONSTRAINT uq_procedure_step UNIQUE (procedure_id, step_number)
);

-- ============================================================================
-- SECTION 3: RECOVERY EXECUTIONS
-- ============================================================================

-- Recovery execution log
CREATE TABLE recovery_executions (
    execution_id SERIAL PRIMARY KEY,
    execution_uuid UUID DEFAULT gen_random_uuid(),
    
    -- References
    crash_id INTEGER REFERENCES crash_events(crash_id) ON DELETE SET NULL,
    procedure_id INTEGER REFERENCES recovery_procedures(procedure_id) ON DELETE SET NULL,
    
    -- Scope
    ecosystem_code VARCHAR(20),
    service_name VARCHAR(100),
    
    -- Execution details
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    -- Progress
    status VARCHAR(20) DEFAULT 'running',
    current_step INTEGER,
    progress_pct DECIMAL(5,2) DEFAULT 0,
    
    -- Steps tracking
    steps_total INTEGER,
    steps_completed INTEGER DEFAULT 0,
    steps_skipped INTEGER DEFAULT 0,
    steps_failed INTEGER DEFAULT 0,
    
    -- Result
    success BOOLEAN,
    result_message TEXT,
    
    -- Metrics
    duration_seconds INTEGER,
    
    -- Errors
    error_count INTEGER DEFAULT 0,
    last_error TEXT,
    
    -- Approval
    approval_required BOOLEAN DEFAULT false,
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Actor
    executed_by VARCHAR(100),
    execution_method VARCHAR(50) DEFAULT 'automatic',
    
    -- Metadata
    metadata JSONB
);

-- Recovery execution steps
CREATE TABLE recovery_execution_steps (
    exec_step_id SERIAL PRIMARY KEY,
    execution_id INTEGER NOT NULL REFERENCES recovery_executions(execution_id) ON DELETE CASCADE,
    step_id INTEGER REFERENCES recovery_procedure_steps(step_id),
    
    -- Step info
    step_number INTEGER NOT NULL,
    step_name VARCHAR(100),
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    
    -- Result
    status VARCHAR(20) NOT NULL,
    result_data JSONB,
    
    -- Errors
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Retries
    retry_count INTEGER DEFAULT 0
);

-- ============================================================================
-- SECTION 4: HEALTH CHECKS
-- ============================================================================

-- Health check definitions
CREATE TABLE health_checks (
    check_id SERIAL PRIMARY KEY,
    check_code VARCHAR(50) UNIQUE NOT NULL,
    check_name VARCHAR(100) NOT NULL,
    
    -- Scope
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    service_name VARCHAR(100),
    
    -- Check configuration
    check_type VARCHAR(50) NOT NULL,
    check_config JSONB,
    
    -- Endpoint (for HTTP checks)
    endpoint_url VARCHAR(500),
    http_method VARCHAR(10) DEFAULT 'GET',
    expected_status INTEGER DEFAULT 200,
    expected_response JSONB,
    
    -- Timing
    interval_seconds INTEGER DEFAULT 60,
    timeout_seconds INTEGER DEFAULT 10,
    
    -- Alerting
    alert_after_failures INTEGER DEFAULT 3,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Health check results
CREATE TABLE health_check_results (
    result_id BIGSERIAL PRIMARY KEY,
    check_id INTEGER NOT NULL REFERENCES health_checks(check_id) ON DELETE CASCADE,
    
    -- Timing
    checked_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Result
    status VARCHAR(20) NOT NULL,
    response_time_ms INTEGER,
    
    -- Details
    status_code INTEGER,
    response_body TEXT,
    
    -- Errors
    error_message TEXT,
    
    -- Metadata
    metadata JSONB
);

-- ============================================================================
-- SECTION 5: SERVICE DEPENDENCIES
-- ============================================================================

-- Service dependency map
CREATE TABLE service_dependencies (
    dependency_id SERIAL PRIMARY KEY,
    
    -- Service
    service_name VARCHAR(100) NOT NULL,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    
    -- Dependency
    depends_on_service VARCHAR(100) NOT NULL,
    depends_on_ecosystem VARCHAR(20),
    
    -- Dependency type
    dependency_type VARCHAR(50) DEFAULT 'required',
    
    -- Health impact
    impact_if_down VARCHAR(50) DEFAULT 'degraded',
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_service_dependency UNIQUE (service_name, depends_on_service)
);

-- ============================================================================
-- SECTION 6: RECOVERY STATISTICS
-- ============================================================================

-- Daily recovery statistics
CREATE TABLE recovery_statistics_daily (
    stat_id SERIAL PRIMARY KEY,
    stat_date DATE NOT NULL,
    
    -- Scope
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code),
    
    -- Crash counts
    total_crashes INTEGER DEFAULT 0,
    critical_crashes INTEGER DEFAULT 0,
    high_crashes INTEGER DEFAULT 0,
    medium_crashes INTEGER DEFAULT 0,
    
    -- Recovery counts
    recovery_attempts INTEGER DEFAULT 0,
    successful_recoveries INTEGER DEFAULT 0,
    failed_recoveries INTEGER DEFAULT 0,
    manual_interventions INTEGER DEFAULT 0,
    
    -- Timing
    avg_detection_latency_seconds INTEGER,
    avg_recovery_duration_seconds INTEGER,
    total_downtime_minutes INTEGER DEFAULT 0,
    
    -- Impact
    affected_users_total INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_recovery_stats UNIQUE (stat_date, ecosystem_code)
);

-- ============================================================================
-- SECTION 7: INDEXES
-- ============================================================================

-- Crash events
CREATE INDEX idx_crash_events_ecosystem ON crash_events(ecosystem_code);
CREATE INDEX idx_crash_events_type ON crash_events(crash_type);
CREATE INDEX idx_crash_events_timestamp ON crash_events(crash_timestamp DESC);
CREATE INDEX idx_crash_events_unresolved ON crash_events(resolved_at) WHERE resolved_at IS NULL;

-- Recovery procedures
CREATE INDEX idx_recovery_procedures_ecosystem ON recovery_procedures(ecosystem_code);
CREATE INDEX idx_recovery_procedures_active ON recovery_procedures(is_active) WHERE is_active = true;

-- Recovery executions
CREATE INDEX idx_recovery_executions_crash ON recovery_executions(crash_id);
CREATE INDEX idx_recovery_executions_status ON recovery_executions(status);
CREATE INDEX idx_recovery_executions_started ON recovery_executions(started_at DESC);

-- Health checks
CREATE INDEX idx_health_checks_ecosystem ON health_checks(ecosystem_code);
CREATE INDEX idx_health_check_results_check ON health_check_results(check_id);
CREATE INDEX idx_health_check_results_time ON health_check_results(checked_at DESC);

-- ============================================================================
-- SECTION 8: COMMENTS
-- ============================================================================

COMMENT ON TABLE crash_events IS 'Log of all crash events across the platform';
COMMENT ON TABLE recovery_procedures IS 'Configurable recovery procedure definitions';
COMMENT ON TABLE recovery_executions IS 'Recovery execution audit log';
COMMENT ON TABLE health_checks IS 'Service health check definitions';
