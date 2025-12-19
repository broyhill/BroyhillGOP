-- ============================================================================
-- BRAIN CONTROL SYSTEM - VENDOR MANAGEMENT
-- ============================================================================
-- File: 006_brain_vendors.sql
-- Vendor registry, health tracking, usage, and quotas
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: VENDOR REGISTRY
-- ============================================================================

-- Master vendor registry
CREATE TABLE vendors (
    vendor_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) UNIQUE NOT NULL,
    vendor_name VARCHAR(100) NOT NULL,
    vendor_type vendor_type NOT NULL,
    
    -- Company info
    company_name VARCHAR(200),
    website_url VARCHAR(500),
    support_email VARCHAR(200),
    support_phone VARCHAR(50),
    
    -- API configuration
    api_base_url VARCHAR(500),
    api_version VARCHAR(20),
    api_docs_url VARCHAR(500),
    auth_type VARCHAR(50) DEFAULT 'api_key',
    
    -- Rate limits
    rate_limit_requests INTEGER,
    rate_limit_period VARCHAR(20) DEFAULT 'minute',
    rate_limit_burst INTEGER,
    
    -- Quotas
    monthly_quota INTEGER,
    quota_unit VARCHAR(30),
    
    -- Budget
    monthly_budget DECIMAL(12,2) DEFAULT 0,
    
    -- Pricing
    pricing_model VARCHAR(50),
    base_cost DECIMAL(10,4),
    cost_per_unit DECIMAL(10,6),
    cost_unit VARCHAR(30),
    
    -- Health monitoring
    health_check_endpoint VARCHAR(500),
    health_check_interval_seconds INTEGER DEFAULT 60,
    
    -- Features
    features JSONB,
    capabilities JSONB,
    
    -- Contract
    contract_start_date DATE,
    contract_end_date DATE,
    contract_terms JSONB,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active',
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vendor credentials (encrypted storage reference)
CREATE TABLE vendor_credentials (
    credential_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) NOT NULL REFERENCES vendors(vendor_code) ON DELETE CASCADE,
    
    -- Credential info
    credential_name VARCHAR(100) NOT NULL,
    credential_type VARCHAR(50) DEFAULT 'api_key',
    
    -- Storage reference (actual secrets in vault)
    vault_path VARCHAR(500),
    vault_key VARCHAR(100),
    
    -- Environment
    environment VARCHAR(20) DEFAULT 'production',
    
    -- Rotation
    last_rotated_at TIMESTAMPTZ,
    rotation_interval_days INTEGER,
    next_rotation_at TIMESTAMPTZ,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_vendor_credential UNIQUE (vendor_code, credential_name, environment)
);

-- Vendor endpoints
CREATE TABLE vendor_endpoints (
    endpoint_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) NOT NULL REFERENCES vendors(vendor_code) ON DELETE CASCADE,
    
    -- Endpoint details
    endpoint_name VARCHAR(100) NOT NULL,
    endpoint_path VARCHAR(500) NOT NULL,
    http_method VARCHAR(10) DEFAULT 'GET',
    
    -- Description
    description TEXT,
    
    -- Rate limits (endpoint-specific)
    rate_limit INTEGER,
    rate_limit_period VARCHAR(20),
    
    -- Cost
    cost_per_call DECIMAL(10,6),
    
    -- Parameters
    required_params JSONB,
    optional_params JSONB,
    
    -- Response
    response_schema JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    CONSTRAINT uq_vendor_endpoint UNIQUE (vendor_code, endpoint_name)
);

-- ============================================================================
-- SECTION 2: VENDOR HEALTH TRACKING
-- ============================================================================

-- Vendor health checks
CREATE TABLE vendor_health (
    health_id BIGSERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) NOT NULL REFERENCES vendors(vendor_code) ON DELETE CASCADE,
    
    -- Check timing
    check_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- Status
    status VARCHAR(20) NOT NULL,
    
    -- Performance
    response_time_ms INTEGER,
    
    -- Availability
    is_available BOOLEAN DEFAULT true,
    
    -- Error tracking
    error_rate DECIMAL(7,6) DEFAULT 0,
    last_error TEXT,
    last_error_at TIMESTAMPTZ,
    consecutive_failures INTEGER DEFAULT 0,
    
    -- Quota tracking
    quota_used DECIMAL(12,2) DEFAULT 0,
    quota_limit DECIMAL(12,2),
    quota_remaining DECIMAL(12,2),
    quota_reset_at TIMESTAMPTZ,
    
    -- Budget tracking
    budget_used DECIMAL(12,2) DEFAULT 0,
    budget_limit DECIMAL(12,2),
    budget_remaining DECIMAL(12,2),
    
    -- Rate limit tracking
    rate_limit_remaining INTEGER,
    rate_limit_reset_at TIMESTAMPTZ,
    
    -- Metadata
    check_metadata JSONB
);

-- Vendor incidents
CREATE TABLE vendor_incidents (
    incident_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) NOT NULL REFERENCES vendors(vendor_code) ON DELETE CASCADE,
    
    -- Incident details
    incident_type VARCHAR(50) NOT NULL,
    severity alert_severity NOT NULL,
    title VARCHAR(300) NOT NULL,
    description TEXT,
    
    -- Timing
    started_at TIMESTAMPTZ NOT NULL,
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    
    -- Impact
    affected_functions TEXT[],
    affected_ecosystems TEXT[],
    estimated_impact TEXT,
    
    -- Response
    mitigation_actions TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'open',
    
    -- Communication
    vendor_acknowledged BOOLEAN DEFAULT false,
    vendor_ticket_id VARCHAR(100),
    
    -- Alert link
    alert_id INTEGER REFERENCES alerts(alert_id),
    
    -- Metadata
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SECTION 3: VENDOR USAGE TRACKING
-- ============================================================================

-- Individual vendor API calls
CREATE TABLE vendor_requests (
    request_id BIGSERIAL PRIMARY KEY,
    request_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Vendor & endpoint
    vendor_code VARCHAR(50) NOT NULL,
    endpoint_name VARCHAR(100),
    
    -- Function context
    function_code VARCHAR(10),
    ecosystem_code VARCHAR(20),
    
    -- Request details
    request_timestamp TIMESTAMPTZ DEFAULT NOW(),
    http_method VARCHAR(10),
    request_path VARCHAR(1000),
    
    -- Request size
    request_size_bytes INTEGER,
    request_units INTEGER DEFAULT 1,
    
    -- Response
    response_timestamp TIMESTAMPTZ,
    response_size_bytes INTEGER,
    status_code INTEGER,
    
    -- Performance
    latency_ms INTEGER,
    
    -- Result
    success BOOLEAN DEFAULT true,
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Cost
    cost DECIMAL(10,6) DEFAULT 0,
    
    -- Retry info
    retry_count INTEGER DEFAULT 0,
    original_request_id BIGINT,
    
    -- Metadata
    metadata JSONB
);

-- Hourly vendor usage aggregates
CREATE TABLE vendor_usage_hourly (
    usage_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) NOT NULL REFERENCES vendors(vendor_code) ON DELETE CASCADE,
    hour_start TIMESTAMPTZ NOT NULL,
    
    -- Volume
    request_count INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    
    -- Size
    total_request_bytes BIGINT DEFAULT 0,
    total_response_bytes BIGINT DEFAULT 0,
    
    -- Cost
    total_cost DECIMAL(12,4) DEFAULT 0,
    
    -- Performance
    avg_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    max_latency_ms INTEGER,
    
    -- Error rate
    error_rate DECIMAL(7,6),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_vendor_usage_hourly UNIQUE (vendor_code, hour_start)
);

-- Daily vendor usage aggregates
CREATE TABLE vendor_usage_daily (
    usage_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) NOT NULL REFERENCES vendors(vendor_code) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    
    -- Volume
    request_count INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    
    -- Quota
    quota_used DECIMAL(12,2) DEFAULT 0,
    quota_limit DECIMAL(12,2),
    quota_used_pct DECIMAL(5,2),
    
    -- Cost
    total_cost DECIMAL(12,2) DEFAULT 0,
    budget_limit DECIMAL(12,2),
    budget_used_pct DECIMAL(5,2),
    
    -- Performance
    avg_latency_ms INTEGER,
    p50_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    p99_latency_ms INTEGER,
    
    -- Availability
    availability_pct DECIMAL(5,2),
    downtime_minutes INTEGER DEFAULT 0,
    
    -- Incidents
    incident_count INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_vendor_usage_daily UNIQUE (vendor_code, usage_date)
);

-- Monthly vendor summaries
CREATE TABLE vendor_usage_monthly (
    usage_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) NOT NULL REFERENCES vendors(vendor_code) ON DELETE CASCADE,
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    
    -- Volume
    total_requests INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    
    -- Quota
    quota_used DECIMAL(12,2) DEFAULT 0,
    quota_limit DECIMAL(12,2),
    
    -- Cost
    total_cost DECIMAL(12,2) DEFAULT 0,
    budget_limit DECIMAL(12,2),
    cost_variance DECIMAL(12,2),
    cost_variance_pct DECIMAL(6,2),
    
    -- Performance
    avg_latency_ms INTEGER,
    availability_pct DECIMAL(5,2),
    
    -- Incidents
    total_incidents INTEGER DEFAULT 0,
    critical_incidents INTEGER DEFAULT 0,
    
    -- ROI (if calculable)
    value_generated DECIMAL(12,2),
    roi DECIMAL(8,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_vendor_usage_monthly UNIQUE (vendor_code, fiscal_year, fiscal_month)
);

-- ============================================================================
-- SECTION 4: VENDOR QUOTAS & BUDGETS
-- ============================================================================

-- Vendor quota allocations
CREATE TABLE vendor_quotas (
    quota_id SERIAL PRIMARY KEY,
    vendor_code VARCHAR(50) NOT NULL REFERENCES vendors(vendor_code) ON DELETE CASCADE,
    
    -- Period
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    
    -- Quota
    quota_type VARCHAR(30) NOT NULL,
    allocated_quota DECIMAL(12,2) NOT NULL,
    reserved_quota DECIMAL(12,2) DEFAULT 0,
    used_quota DECIMAL(12,2) DEFAULT 0,
    remaining_quota DECIMAL(12,2),
    
    -- Budget
    allocated_budget DECIMAL(12,2),
    used_budget DECIMAL(12,2) DEFAULT 0,
    remaining_budget DECIMAL(12,2),
    
    -- Alerts
    alert_at_pct DECIMAL(5,2) DEFAULT 80,
    alert_sent BOOLEAN DEFAULT false,
    alert_sent_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_vendor_quota UNIQUE (vendor_code, fiscal_year, fiscal_month, quota_type)
);

-- ============================================================================
-- SECTION 5: VENDOR COMPARISONS
-- ============================================================================

-- Vendor comparison (for similar vendors)
CREATE TABLE vendor_comparisons (
    comparison_id SERIAL PRIMARY KEY,
    
    -- Comparison setup
    comparison_name VARCHAR(200) NOT NULL,
    vendor_type vendor_type NOT NULL,
    vendors_compared TEXT[] NOT NULL,
    
    -- Period
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Comparison metrics
    metrics_compared TEXT[],
    comparison_results JSONB NOT NULL,
    
    -- Recommendation
    recommended_vendor VARCHAR(50),
    recommendation_reason TEXT,
    potential_savings DECIMAL(12,2),
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft',
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100)
);

-- ============================================================================
-- SECTION 6: INDEXES
-- ============================================================================

-- Vendors
CREATE INDEX idx_vendors_type ON vendors(vendor_type);
CREATE INDEX idx_vendors_status ON vendors(status);

-- Vendor health
CREATE INDEX idx_vendor_health_code ON vendor_health(vendor_code);
CREATE INDEX idx_vendor_health_timestamp ON vendor_health(check_timestamp DESC);

-- Vendor requests
CREATE INDEX idx_vendor_requests_code ON vendor_requests(vendor_code);
CREATE INDEX idx_vendor_requests_timestamp ON vendor_requests(request_timestamp);
CREATE INDEX idx_vendor_requests_function ON vendor_requests(function_code);

-- Vendor usage
CREATE INDEX idx_vendor_usage_hourly_code ON vendor_usage_hourly(vendor_code);
CREATE INDEX idx_vendor_usage_hourly_time ON vendor_usage_hourly(hour_start);
CREATE INDEX idx_vendor_usage_daily_code ON vendor_usage_daily(vendor_code);
CREATE INDEX idx_vendor_usage_daily_date ON vendor_usage_daily(usage_date);

-- Vendor quotas
CREATE INDEX idx_vendor_quotas_code ON vendor_quotas(vendor_code);
CREATE INDEX idx_vendor_quotas_period ON vendor_quotas(fiscal_year, fiscal_month);

-- ============================================================================
-- SECTION 7: COMMENTS
-- ============================================================================

COMMENT ON TABLE vendors IS 'Master registry of all external vendors and services';
COMMENT ON TABLE vendor_health IS 'Time-series health metrics for vendors';
COMMENT ON TABLE vendor_requests IS 'Individual vendor API call log';
COMMENT ON TABLE vendor_usage_daily IS 'Daily vendor usage aggregates';
COMMENT ON TABLE vendor_quotas IS 'Vendor quota and budget allocations';
