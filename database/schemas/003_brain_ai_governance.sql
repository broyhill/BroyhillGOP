-- ============================================================================
-- BRAIN CONTROL SYSTEM - AI GOVERNANCE
-- ============================================================================
-- File: 003_brain_ai_governance.sql
-- AI models, prompts, usage tracking, and governance
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: AI PROVIDER & MODEL REGISTRY
-- ============================================================================

-- AI providers
CREATE TABLE ai_providers (
    provider_id SERIAL PRIMARY KEY,
    provider_code VARCHAR(50) UNIQUE NOT NULL,
    provider_name VARCHAR(100) NOT NULL,
    
    -- API configuration
    api_base_url VARCHAR(500),
    api_version VARCHAR(20),
    auth_type VARCHAR(50) DEFAULT 'api_key',
    
    -- Rate limits
    rate_limit_rpm INTEGER,
    rate_limit_tpm INTEGER,
    rate_limit_daily INTEGER,
    
    -- Budget
    monthly_budget DECIMAL(12,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active',
    health_endpoint VARCHAR(500),
    
    -- Features
    supports_streaming BOOLEAN DEFAULT true,
    supports_function_calling BOOLEAN DEFAULT true,
    supports_vision BOOLEAN DEFAULT false,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI models
CREATE TABLE ai_models (
    model_id SERIAL PRIMARY KEY,
    provider_code VARCHAR(50) NOT NULL REFERENCES ai_providers(provider_code) ON DELETE CASCADE,
    model_code VARCHAR(100) UNIQUE NOT NULL,
    model_name VARCHAR(200) NOT NULL,
    model_version VARCHAR(50),
    
    -- Tier & capabilities
    model_tier VARCHAR(20) DEFAULT 'standard',
    capabilities JSONB,
    
    -- Context limits
    max_context_tokens INTEGER,
    max_output_tokens INTEGER,
    
    -- Pricing
    cost_per_1k_input DECIMAL(10,6),
    cost_per_1k_output DECIMAL(10,6),
    cost_per_image DECIMAL(10,6),
    
    -- Performance benchmarks
    avg_latency_ms INTEGER,
    quality_benchmark DECIMAL(5,2),
    
    -- Rate limits (model-specific overrides)
    rate_limit_rpm INTEGER,
    rate_limit_tpm INTEGER,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_deprecated BOOLEAN DEFAULT false,
    deprecation_date DATE,
    replacement_model VARCHAR(100),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Model selection rules (which model for which function)
CREATE TABLE ai_model_assignments (
    assignment_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) NOT NULL REFERENCES functions(function_code) ON DELETE CASCADE,
    
    -- Model hierarchy
    primary_model VARCHAR(100) REFERENCES ai_models(model_code),
    fallback_model VARCHAR(100) REFERENCES ai_models(model_code),
    economy_model VARCHAR(100) REFERENCES ai_models(model_code),
    
    -- Selection criteria
    use_economy_when JSONB,
    use_fallback_when JSONB,
    
    -- Quality requirements
    min_quality_score DECIMAL(5,2),
    max_latency_ms INTEGER,
    
    -- Cost controls
    max_cost_per_call DECIMAL(10,4),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_model_assignment UNIQUE (function_code)
);

-- ============================================================================
-- SECTION 2: PROMPT LIBRARY
-- ============================================================================

-- Prompt templates
CREATE TABLE ai_prompts (
    prompt_id SERIAL PRIMARY KEY,
    prompt_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Identification
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    prompt_name VARCHAR(100) NOT NULL,
    prompt_key VARCHAR(100) UNIQUE,
    
    -- Prompt content
    system_prompt TEXT,
    user_prompt_template TEXT NOT NULL,
    assistant_prefill TEXT,
    
    -- Variables
    required_variables TEXT[] DEFAULT '{}',
    optional_variables TEXT[] DEFAULT '{}',
    variable_defaults JSONB,
    
    -- Model preferences
    preferred_model VARCHAR(100) REFERENCES ai_models(model_code),
    allowed_models TEXT[] DEFAULT '{}',
    
    -- Generation parameters
    temperature DECIMAL(2,1) DEFAULT 0.7,
    max_tokens INTEGER DEFAULT 4000,
    top_p DECIMAL(3,2) DEFAULT 1.0,
    frequency_penalty DECIMAL(3,2) DEFAULT 0,
    presence_penalty DECIMAL(3,2) DEFAULT 0,
    stop_sequences TEXT[],
    
    -- Output format
    output_format VARCHAR(50) DEFAULT 'text',
    json_schema JSONB,
    
    -- Quality tracking
    avg_quality_score DECIMAL(5,2),
    usage_count INTEGER DEFAULT 0,
    success_rate DECIMAL(5,4),
    
    -- Versioning
    version INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    
    -- Approval
    status VARCHAR(20) DEFAULT 'draft',
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    
    -- Constraints
    CONSTRAINT chk_temperature CHECK (temperature BETWEEN 0 AND 2),
    CONSTRAINT chk_top_p CHECK (top_p BETWEEN 0 AND 1)
);

-- Prompt versions history
CREATE TABLE ai_prompt_versions (
    version_id SERIAL PRIMARY KEY,
    prompt_id INTEGER NOT NULL REFERENCES ai_prompts(prompt_id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    
    -- Content snapshot
    system_prompt TEXT,
    user_prompt_template TEXT NOT NULL,
    generation_params JSONB,
    
    -- Change tracking
    change_summary TEXT,
    changed_by VARCHAR(100),
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Metrics at time of change
    quality_score_at_change DECIMAL(5,2),
    usage_count_at_change INTEGER,
    
    CONSTRAINT uq_prompt_version UNIQUE (prompt_id, version_number)
);

-- Prompt clarifications (additional context)
CREATE TABLE ai_clarifications (
    clarification_id SERIAL PRIMARY KEY,
    prompt_id INTEGER NOT NULL REFERENCES ai_prompts(prompt_id) ON DELETE CASCADE,
    
    -- Clarification content
    clarification_type VARCHAR(50) DEFAULT 'context',
    clarification_text TEXT NOT NULL,
    
    -- Conditions
    apply_when JSONB,
    
    -- Priority (lower = applied first)
    priority INTEGER DEFAULT 100,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    added_by VARCHAR(100) NOT NULL,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    reason TEXT
);

-- ============================================================================
-- SECTION 3: AI USAGE TRACKING
-- ============================================================================

-- Individual AI requests
CREATE TABLE ai_requests (
    request_id BIGSERIAL PRIMARY KEY,
    request_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Timing
    request_timestamp TIMESTAMPTZ DEFAULT NOW(),
    response_timestamp TIMESTAMPTZ,
    
    -- Context
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE SET NULL,
    prompt_id INTEGER REFERENCES ai_prompts(prompt_id) ON DELETE SET NULL,
    
    -- Model used
    provider_code VARCHAR(50),
    model_code VARCHAR(100),
    
    -- Input
    input_tokens INTEGER,
    input_characters INTEGER,
    
    -- Output
    output_tokens INTEGER,
    output_characters INTEGER,
    
    -- Totals
    total_tokens INTEGER,
    
    -- Costs
    input_cost DECIMAL(10,6),
    output_cost DECIMAL(10,6),
    total_cost DECIMAL(10,6),
    
    -- Performance
    latency_ms INTEGER,
    time_to_first_token_ms INTEGER,
    
    -- Result
    success BOOLEAN DEFAULT true,
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Quality
    quality_score DECIMAL(5,2),
    quality_feedback VARCHAR(20),
    
    -- Metadata
    request_metadata JSONB,
    response_metadata JSONB
);

-- Hourly AI usage aggregates
CREATE TABLE ai_usage_hourly (
    usage_id SERIAL PRIMARY KEY,
    hour_start TIMESTAMPTZ NOT NULL,
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    provider_code VARCHAR(50),
    model_code VARCHAR(100),
    
    -- Volume
    request_count INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    
    -- Tokens
    total_input_tokens BIGINT DEFAULT 0,
    total_output_tokens BIGINT DEFAULT 0,
    total_tokens BIGINT DEFAULT 0,
    
    -- Costs
    total_cost DECIMAL(12,4) DEFAULT 0,
    avg_cost_per_request DECIMAL(10,6),
    
    -- Performance
    avg_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    max_latency_ms INTEGER,
    
    -- Quality
    avg_quality_score DECIMAL(5,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_ai_usage_hourly UNIQUE (hour_start, function_code, model_code)
);

-- Daily AI usage aggregates
CREATE TABLE ai_usage_daily (
    usage_id SERIAL PRIMARY KEY,
    usage_date DATE NOT NULL,
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    provider_code VARCHAR(50),
    model_code VARCHAR(100),
    
    -- Volume
    request_count INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    
    -- Tokens
    total_input_tokens BIGINT DEFAULT 0,
    total_output_tokens BIGINT DEFAULT 0,
    total_tokens BIGINT DEFAULT 0,
    
    -- Costs
    total_cost DECIMAL(12,4) DEFAULT 0,
    avg_cost_per_request DECIMAL(10,6),
    
    -- Performance
    avg_latency_ms INTEGER,
    p50_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    p99_latency_ms INTEGER,
    
    -- Quality
    avg_quality_score DECIMAL(5,2),
    quality_score_distribution JSONB,
    
    -- Error analysis
    error_rate DECIMAL(5,4),
    error_distribution JSONB,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_ai_usage_daily UNIQUE (usage_date, function_code, model_code)
);

-- ============================================================================
-- SECTION 4: AI QUALITY EVALUATION
-- ============================================================================

-- Quality evaluations
CREATE TABLE ai_quality_evaluations (
    evaluation_id BIGSERIAL PRIMARY KEY,
    request_id BIGINT REFERENCES ai_requests(request_id) ON DELETE CASCADE,
    
    -- Evaluation timing
    evaluated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Scores (0-100)
    overall_score DECIMAL(5,2),
    accuracy_score DECIMAL(5,2),
    relevance_score DECIMAL(5,2),
    coherence_score DECIMAL(5,2),
    completeness_score DECIMAL(5,2),
    safety_score DECIMAL(5,2),
    
    -- Evaluation method
    evaluation_method VARCHAR(50),
    evaluator_type VARCHAR(20),
    evaluator_id VARCHAR(100),
    
    -- Details
    evaluation_notes TEXT,
    improvement_suggestions TEXT,
    
    -- Metadata
    metadata JSONB
);

-- Quality benchmarks
CREATE TABLE ai_quality_benchmarks (
    benchmark_id SERIAL PRIMARY KEY,
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    model_code VARCHAR(100) REFERENCES ai_models(model_code) ON DELETE CASCADE,
    
    -- Benchmark period
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Quality metrics
    avg_overall_score DECIMAL(5,2),
    avg_accuracy_score DECIMAL(5,2),
    avg_relevance_score DECIMAL(5,2),
    
    -- Performance metrics
    avg_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    
    -- Volume
    sample_size INTEGER,
    
    -- Status
    meets_quality_floor BOOLEAN,
    quality_trend VARCHAR(20),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_quality_benchmark UNIQUE (function_code, model_code, period_start)
);

-- ============================================================================
-- SECTION 5: AI RATE LIMITING & QUOTAS
-- ============================================================================

-- Rate limit tracking
CREATE TABLE ai_rate_limits (
    limit_id SERIAL PRIMARY KEY,
    provider_code VARCHAR(50) NOT NULL REFERENCES ai_providers(provider_code),
    
    -- Window
    window_start TIMESTAMPTZ NOT NULL,
    window_type VARCHAR(20) NOT NULL,
    
    -- Limits
    limit_type VARCHAR(20) NOT NULL,
    limit_value INTEGER NOT NULL,
    current_usage INTEGER DEFAULT 0,
    
    -- Status
    limit_reached BOOLEAN DEFAULT false,
    limit_reached_at TIMESTAMPTZ,
    
    -- Metadata
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_rate_limit UNIQUE (provider_code, window_start, window_type, limit_type)
);

-- Quota tracking
CREATE TABLE ai_quotas (
    quota_id SERIAL PRIMARY KEY,
    
    -- Scope
    provider_code VARCHAR(50) REFERENCES ai_providers(provider_code),
    function_code VARCHAR(10) REFERENCES functions(function_code),
    
    -- Period
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    
    -- Quotas
    token_quota BIGINT,
    token_used BIGINT DEFAULT 0,
    cost_quota DECIMAL(12,2),
    cost_used DECIMAL(12,2) DEFAULT 0,
    request_quota INTEGER,
    request_used INTEGER DEFAULT 0,
    
    -- Alerts
    alert_threshold_pct DECIMAL(5,2) DEFAULT 80,
    alert_sent BOOLEAN DEFAULT false,
    alert_sent_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_ai_quota UNIQUE (provider_code, function_code, fiscal_year, fiscal_month)
);

-- ============================================================================
-- SECTION 6: INDEXES
-- ============================================================================

-- AI providers & models
CREATE INDEX idx_ai_models_provider ON ai_models(provider_code);
CREATE INDEX idx_ai_models_tier ON ai_models(model_tier);
CREATE INDEX idx_ai_models_active ON ai_models(is_active) WHERE is_active = true;

-- Prompts
CREATE INDEX idx_ai_prompts_function ON ai_prompts(function_code);
CREATE INDEX idx_ai_prompts_active ON ai_prompts(is_active) WHERE is_active = true;
CREATE INDEX idx_ai_prompts_key ON ai_prompts(prompt_key);

-- AI requests
CREATE INDEX idx_ai_requests_timestamp ON ai_requests(request_timestamp);
CREATE INDEX idx_ai_requests_function ON ai_requests(function_code);
CREATE INDEX idx_ai_requests_model ON ai_requests(model_code);
CREATE INDEX idx_ai_requests_success ON ai_requests(success);

-- AI usage
CREATE INDEX idx_ai_usage_hourly_time ON ai_usage_hourly(hour_start);
CREATE INDEX idx_ai_usage_daily_date ON ai_usage_daily(usage_date);
CREATE INDEX idx_ai_usage_daily_function ON ai_usage_daily(function_code);

-- Quality
CREATE INDEX idx_quality_eval_request ON ai_quality_evaluations(request_id);
CREATE INDEX idx_quality_benchmark_function ON ai_quality_benchmarks(function_code);

-- ============================================================================
-- SECTION 7: COMMENTS
-- ============================================================================

COMMENT ON TABLE ai_providers IS 'Registry of AI service providers (Anthropic, OpenAI, Perplexity)';
COMMENT ON TABLE ai_models IS 'Detailed model registry with pricing and capabilities';
COMMENT ON TABLE ai_prompts IS 'Versioned prompt templates with quality tracking';
COMMENT ON TABLE ai_requests IS 'Individual AI request log for auditing and analysis';
COMMENT ON TABLE ai_usage_daily IS 'Daily AI usage aggregates for cost tracking';
COMMENT ON TABLE ai_quality_evaluations IS 'Quality scores for AI outputs';
