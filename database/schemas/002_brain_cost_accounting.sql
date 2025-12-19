-- ============================================================================
-- BRAIN CONTROL SYSTEM - COST/BENEFIT ACCOUNTING
-- ============================================================================
-- File: 002_brain_cost_accounting.sql
-- Budget forecasts, actual costs, variance analysis, bookkeeping
-- ============================================================================

SET search_path TO brain_control, public;

-- ============================================================================
-- SECTION 1: BUDGET FORECASTING
-- ============================================================================

-- Budget forecasts by function
CREATE TABLE budget_forecasts (
    forecast_id SERIAL PRIMARY KEY,
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    
    -- Period
    period_type VARCHAR(20) NOT NULL DEFAULT 'monthly',
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    fiscal_year INTEGER,
    fiscal_quarter INTEGER,
    fiscal_month INTEGER,
    
    -- Volume forecasts
    forecast_calls INTEGER,
    forecast_records INTEGER,
    forecast_transactions INTEGER,
    
    -- Cost forecasts
    forecast_cost DECIMAL(12,2) NOT NULL,
    forecast_ai_cost DECIMAL(12,2) DEFAULT 0,
    forecast_vendor_cost DECIMAL(12,2) DEFAULT 0,
    forecast_infrastructure_cost DECIMAL(12,2) DEFAULT 0,
    
    -- Benefit forecasts
    forecast_benefit DECIMAL(12,2),
    forecast_revenue DECIMAL(12,2),
    forecast_donations DECIMAL(12,2),
    forecast_conversions INTEGER,
    
    -- ROI calculations
    forecast_roi DECIMAL(8,2),
    forecast_margin DECIMAL(8,2),
    
    -- Forecast metadata
    assumptions JSONB,
    forecast_model VARCHAR(100),
    forecast_confidence DECIMAL(3,2),
    sensitivity_analysis JSONB,
    
    -- Approval
    status VARCHAR(20) DEFAULT 'draft',
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    
    -- Constraints
    CONSTRAINT uq_budget_forecast UNIQUE (function_code, period_type, period_start),
    CONSTRAINT chk_period_dates CHECK (period_end > period_start),
    CONSTRAINT chk_forecast_confidence CHECK (forecast_confidence BETWEEN 0 AND 1)
);

-- Ecosystem-level budget allocations
CREATE TABLE budget_allocations (
    allocation_id SERIAL PRIMARY KEY,
    
    -- Period
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    
    -- Scope
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    cost_category VARCHAR(50) NOT NULL,
    
    -- Amounts
    allocated_amount DECIMAL(12,2) NOT NULL,
    reserved_amount DECIMAL(12,2) DEFAULT 0,
    contingency_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Notes
    notes TEXT,
    justification TEXT,
    
    -- Approval
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_budget_allocation UNIQUE (fiscal_year, fiscal_month, ecosystem_code, cost_category)
);

-- ============================================================================
-- SECTION 2: ACTUAL COST TRACKING
-- ============================================================================

-- Individual cost transactions
CREATE TABLE cost_transactions (
    transaction_id BIGSERIAL PRIMARY KEY,
    transaction_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Timing
    transaction_date DATE NOT NULL,
    transaction_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE SET NULL,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE SET NULL,
    vendor_code VARCHAR(50),
    
    -- Cost details
    cost_type cost_type,
    cost_category VARCHAR(50),
    unit_count INTEGER DEFAULT 1,
    unit_cost DECIMAL(10,6),
    total_cost DECIMAL(12,4) NOT NULL,
    
    -- Currency
    currency VARCHAR(3) DEFAULT 'USD',
    exchange_rate DECIMAL(10,6) DEFAULT 1,
    
    -- Cost breakdown
    ai_cost DECIMAL(10,4) DEFAULT 0,
    vendor_cost DECIMAL(10,4) DEFAULT 0,
    infrastructure_cost DECIMAL(10,4) DEFAULT 0,
    
    -- Reference
    external_reference VARCHAR(200),
    invoice_number VARCHAR(100),
    
    -- Metadata
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily cost aggregates
CREATE TABLE daily_costs (
    daily_id SERIAL PRIMARY KEY,
    cost_date DATE NOT NULL,
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    
    -- Volume
    call_count INTEGER DEFAULT 0,
    record_count INTEGER DEFAULT 0,
    transaction_count INTEGER DEFAULT 0,
    
    -- Costs
    total_cost DECIMAL(12,2) DEFAULT 0,
    ai_cost DECIMAL(12,2) DEFAULT 0,
    vendor_cost DECIMAL(12,2) DEFAULT 0,
    infrastructure_cost DECIMAL(12,2) DEFAULT 0,
    
    -- Per-unit costs
    avg_cost_per_call DECIMAL(10,6),
    avg_cost_per_record DECIMAL(10,6),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_daily_costs UNIQUE (cost_date, function_code)
);

-- Monthly cost summaries
CREATE TABLE monthly_costs (
    monthly_id SERIAL PRIMARY KEY,
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    
    -- Volume
    total_calls INTEGER DEFAULT 0,
    total_records INTEGER DEFAULT 0,
    total_transactions INTEGER DEFAULT 0,
    
    -- Costs
    total_cost DECIMAL(12,2) DEFAULT 0,
    ai_cost DECIMAL(12,2) DEFAULT 0,
    vendor_cost DECIMAL(12,2) DEFAULT 0,
    infrastructure_cost DECIMAL(12,2) DEFAULT 0,
    
    -- Per-unit costs
    avg_cost_per_call DECIMAL(10,6),
    avg_cost_per_record DECIMAL(10,6),
    
    -- Comparison to forecast
    forecast_cost DECIMAL(12,2),
    cost_variance DECIMAL(12,2),
    cost_variance_pct DECIMAL(6,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_monthly_costs UNIQUE (fiscal_year, fiscal_month, function_code)
);

-- ============================================================================
-- SECTION 3: BENEFIT TRACKING
-- ============================================================================

-- Benefit transactions
CREATE TABLE benefit_transactions (
    benefit_id BIGSERIAL PRIMARY KEY,
    benefit_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Timing
    benefit_date DATE NOT NULL,
    benefit_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE SET NULL,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE SET NULL,
    campaign_id INTEGER,
    
    -- Benefit details
    benefit_type VARCHAR(50) NOT NULL,
    benefit_category VARCHAR(50),
    benefit_amount DECIMAL(12,2) NOT NULL,
    
    -- Attribution
    attribution_method VARCHAR(100),
    attribution_confidence DECIMAL(3,2),
    attribution_factors JSONB,
    
    -- Reference
    source_system VARCHAR(50),
    source_reference VARCHAR(200),
    
    -- Metadata
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Monthly benefit summaries
CREATE TABLE monthly_benefits (
    monthly_id SERIAL PRIMARY KEY,
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    
    -- Benefits by type
    total_benefit DECIMAL(12,2) DEFAULT 0,
    revenue_benefit DECIMAL(12,2) DEFAULT 0,
    donation_benefit DECIMAL(12,2) DEFAULT 0,
    efficiency_benefit DECIMAL(12,2) DEFAULT 0,
    conversion_benefit DECIMAL(12,2) DEFAULT 0,
    
    -- Volume metrics
    conversions INTEGER DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    donations_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Comparison to forecast
    forecast_benefit DECIMAL(12,2),
    benefit_variance DECIMAL(12,2),
    benefit_variance_pct DECIMAL(6,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_monthly_benefits UNIQUE (fiscal_year, fiscal_month, function_code)
);

-- ============================================================================
-- SECTION 4: VARIANCE ANALYSIS
-- ============================================================================

-- Variance analysis results
CREATE TABLE variance_analysis (
    variance_id SERIAL PRIMARY KEY,
    analysis_uuid UUID DEFAULT gen_random_uuid(),
    
    -- Scope
    function_code VARCHAR(10) REFERENCES functions(function_code) ON DELETE CASCADE,
    ecosystem_code VARCHAR(20) REFERENCES ecosystems(ecosystem_code) ON DELETE CASCADE,
    
    -- Period
    period_type VARCHAR(20) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Cost variance
    forecast_cost DECIMAL(12,2),
    actual_cost DECIMAL(12,2),
    cost_variance DECIMAL(12,2),
    cost_variance_pct DECIMAL(6,2),
    cost_variance_status variance_status,
    
    -- Benefit variance
    forecast_benefit DECIMAL(12,2),
    actual_benefit DECIMAL(12,2),
    benefit_variance DECIMAL(12,2),
    benefit_variance_pct DECIMAL(6,2),
    
    -- ROI variance
    forecast_roi DECIMAL(8,2),
    actual_roi DECIMAL(8,2),
    roi_variance DECIMAL(8,2),
    
    -- Volume variance
    forecast_volume INTEGER,
    actual_volume INTEGER,
    volume_variance INTEGER,
    volume_variance_pct DECIMAL(6,2),
    
    -- Analysis details
    variance_drivers JSONB,
    root_cause TEXT,
    impact_assessment TEXT,
    
    -- Self-correction
    auto_correction_eligible BOOLEAN DEFAULT false,
    auto_correction_applied BOOLEAN DEFAULT false,
    correction_id INTEGER,
    
    -- Review
    reviewed_by VARCHAR(100),
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    
    -- Metadata
    analyzed_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_variance_analysis UNIQUE (function_code, period_type, period_start)
);

-- ============================================================================
-- SECTION 5: COST CATEGORIES & CHART OF ACCOUNTS
-- ============================================================================

-- Cost categories (chart of accounts)
CREATE TABLE cost_categories (
    category_id SERIAL PRIMARY KEY,
    category_code VARCHAR(50) UNIQUE NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    parent_category VARCHAR(50) REFERENCES cost_categories(category_code),
    description TEXT,
    
    -- Accounting
    gl_account VARCHAR(20),
    cost_center VARCHAR(20),
    
    -- Budget controls
    budget_cap DECIMAL(12,2),
    requires_approval_above DECIMAL(12,2),
    
    -- Metadata
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 100,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SECTION 6: FINANCIAL REPORTING
-- ============================================================================

-- Monthly financial summaries (P&L style)
CREATE TABLE financial_summaries (
    summary_id SERIAL PRIMARY KEY,
    
    -- Period
    fiscal_year INTEGER NOT NULL,
    fiscal_month INTEGER NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Revenue / Benefits
    total_revenue DECIMAL(12,2) DEFAULT 0,
    total_donations DECIMAL(12,2) DEFAULT 0,
    total_benefits DECIMAL(12,2) DEFAULT 0,
    
    -- Costs
    total_costs DECIMAL(12,2) DEFAULT 0,
    ai_costs DECIMAL(12,2) DEFAULT 0,
    vendor_costs DECIMAL(12,2) DEFAULT 0,
    infrastructure_costs DECIMAL(12,2) DEFAULT 0,
    payment_processor_costs DECIMAL(12,2) DEFAULT 0,
    communication_costs DECIMAL(12,2) DEFAULT 0,
    
    -- Margins
    gross_margin DECIMAL(12,2),
    gross_margin_pct DECIMAL(6,2),
    net_margin DECIMAL(12,2),
    net_margin_pct DECIMAL(6,2),
    
    -- Budget comparison
    total_budget DECIMAL(12,2),
    budget_variance DECIMAL(12,2),
    budget_variance_pct DECIMAL(6,2),
    
    -- ROI metrics
    platform_roi DECIMAL(8,2),
    ai_roi DECIMAL(8,2),
    
    -- Key metrics
    cost_per_donor DECIMAL(10,2),
    cost_per_donation DECIMAL(10,2),
    revenue_per_donor DECIMAL(10,2),
    
    -- Health indicators
    ecosystems_healthy INTEGER,
    ecosystems_degraded INTEGER,
    functions_over_budget INTEGER,
    self_corrections_count INTEGER,
    
    -- Recommendations
    recommendations JSONB,
    
    -- Metadata
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    generated_by VARCHAR(100) DEFAULT 'system',
    
    CONSTRAINT uq_financial_summary UNIQUE (fiscal_year, fiscal_month)
);

-- ============================================================================
-- SECTION 7: INDEXES
-- ============================================================================

-- Budget forecasts
CREATE INDEX idx_budget_forecast_function ON budget_forecasts(function_code);
CREATE INDEX idx_budget_forecast_ecosystem ON budget_forecasts(ecosystem_code);
CREATE INDEX idx_budget_forecast_period ON budget_forecasts(period_start, period_end);

-- Cost transactions
CREATE INDEX idx_cost_trans_date ON cost_transactions(transaction_date);
CREATE INDEX idx_cost_trans_function ON cost_transactions(function_code);
CREATE INDEX idx_cost_trans_ecosystem ON cost_transactions(ecosystem_code);
CREATE INDEX idx_cost_trans_vendor ON cost_transactions(vendor_code);
CREATE INDEX idx_cost_trans_category ON cost_transactions(cost_category);

-- Daily costs
CREATE INDEX idx_daily_costs_date ON daily_costs(cost_date);
CREATE INDEX idx_daily_costs_function ON daily_costs(function_code);

-- Monthly costs
CREATE INDEX idx_monthly_costs_period ON monthly_costs(fiscal_year, fiscal_month);
CREATE INDEX idx_monthly_costs_function ON monthly_costs(function_code);

-- Variance analysis
CREATE INDEX idx_variance_status ON variance_analysis(cost_variance_status);
CREATE INDEX idx_variance_function ON variance_analysis(function_code);
CREATE INDEX idx_variance_period ON variance_analysis(period_start, period_end);

-- Financial summaries
CREATE INDEX idx_financial_period ON financial_summaries(fiscal_year, fiscal_month);

-- ============================================================================
-- SECTION 8: COMMENTS
-- ============================================================================

COMMENT ON TABLE budget_forecasts IS 'Budget and volume forecasts by function and period';
COMMENT ON TABLE cost_transactions IS 'Individual cost transaction records';
COMMENT ON TABLE daily_costs IS 'Daily cost aggregates by function';
COMMENT ON TABLE monthly_costs IS 'Monthly cost summaries with forecast comparison';
COMMENT ON TABLE variance_analysis IS 'Cost and benefit variance analysis results';
COMMENT ON TABLE financial_summaries IS 'Monthly P&L style financial reports';
