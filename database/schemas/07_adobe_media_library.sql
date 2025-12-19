-- =====================================================
-- BROYHILLGOP SUPABASE DATABASE SCHEMA
-- Adobe Creative Cloud Enterprise Integration
-- File 7: Adobe Media Library Tables
-- =====================================================

-- =====================================================
-- SECTION 1: ADOBE ASSET MANAGEMENT TABLES
-- =====================================================

-- Table: adobe_aem_assets
-- Tracks all assets stored in Adobe Experience Manager
CREATE TABLE IF NOT EXISTS adobe_aem_assets (
    aem_asset_id SERIAL PRIMARY KEY,
    candidate_id INT REFERENCES candidates(candidate_id),
    aem_dam_path VARCHAR(500) NOT NULL, -- /content/dam/broyhillgop/candidates/...
    aem_asset_uuid VARCHAR(100) UNIQUE, -- Adobe's internal asset ID
    asset_type VARCHAR(50) NOT NULL, -- 'photo', 'logo', 'template', 'psd', 'ai', 'pdf'
    asset_name VARCHAR(255) NOT NULL,
    file_size BIGINT, -- bytes
    mime_type VARCHAR(100),
    width INT, -- pixels
    height INT,
    color_space VARCHAR(20), -- 'RGB', 'CMYK', 'sRGB'
    dpi INT, -- dots per inch (for print assets)
    has_transparency BOOLEAN DEFAULT FALSE,
    processing_profile VARCHAR(100), -- Name of AEM processing profile applied
    renditions JSONB, -- {"thumbnail": "url", "1200x1200": "url", "600x600": "url"}
    metadata JSONB, -- Custom metadata (keywords, tags, copyright, etc.)
    uploaded_by VARCHAR(100),
    uploaded_at TIMESTAMP DEFAULT NOW(),
    last_modified TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_aem_assets_candidate ON adobe_aem_assets(candidate_id);
CREATE INDEX idx_aem_assets_type ON adobe_aem_assets(asset_type);
CREATE INDEX idx_aem_assets_dam_path ON adobe_aem_assets(aem_dam_path);
CREATE INDEX idx_aem_assets_uuid ON adobe_aem_assets(aem_asset_uuid);

-- Table: adobe_brand_kits
-- Stores brand kit definitions for each candidate
CREATE TABLE IF NOT EXISTS adobe_brand_kits (
    brand_kit_id SERIAL PRIMARY KEY,
    candidate_id INT REFERENCES candidates(candidate_id) UNIQUE,
    adobe_express_library_id VARCHAR(100), -- Adobe Express brand kit library ID
    primary_color_hex VARCHAR(7) NOT NULL, -- #FF0000
    secondary_color_hex VARCHAR(7),
    accent_color_hex VARCHAR(7),
    primary_font_family VARCHAR(100), -- 'Arial', 'Georgia', etc.
    secondary_font_family VARCHAR(100),
    logo_primary_url VARCHAR(500),
    logo_stacked_url VARCHAR(500),
    logo_horizontal_url VARCHAR(500),
    brand_guidelines_url VARCHAR(500), -- Link to brand guidelines PDF
    approved_messaging JSONB, -- {tagline, bio_short, bio_long, issue_positions}
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_brand_kits_candidate ON adobe_brand_kits(candidate_id);

-- Table: adobe_firefly_custom_models
-- Tracks Firefly Custom Models trained per candidate
CREATE TABLE IF NOT EXISTS adobe_firefly_custom_models (
    model_id SERIAL PRIMARY KEY,
    candidate_id INT REFERENCES candidates(candidate_id),
    firefly_model_id VARCHAR(100) UNIQUE NOT NULL, -- Adobe's model ID
    model_name VARCHAR(255) NOT NULL,
    model_description TEXT,
    training_images_count INT,
    training_images_urls TEXT[], -- Array of training image URLs
    training_cost NUMERIC(10,2) DEFAULT 500.00, -- $500 per model
    training_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'training', 'completed', 'failed'
    trained_at TIMESTAMP,
    usage_count INT DEFAULT 0,
    last_used TIMESTAMP,
    performance_metrics JSONB, -- {avg_quality_score, consistency_score, generation_speed_ms}
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_firefly_models_candidate ON adobe_firefly_custom_models(candidate_id);
CREATE INDEX idx_firefly_models_adobe_id ON adobe_firefly_custom_models(firefly_model_id);

-- =====================================================
-- SECTION 2: ADOBE TEMPLATE MANAGEMENT
-- =====================================================

-- Update existing media_templates table with Adobe fields
ALTER TABLE media_templates 
ADD COLUMN IF NOT EXISTS adobe_template_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS adobe_express_template_url VARCHAR(500),
ADD COLUMN IF NOT EXISTS adobe_firefly_model_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS aem_template_path VARCHAR(500),
ADD COLUMN IF NOT EXISTS requires_firefly_generation BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS requires_photoshop_api BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS requires_illustrator_api BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS adobe_apis_required TEXT[], -- ARRAY['firefly', 'photoshop', 'express']
ADD COLUMN IF NOT EXISTS template_format VARCHAR(50), -- 'psd', 'ai', 'indd', 'express', 'html'
ADD COLUMN IF NOT EXISTS adobe_processing_time_ms INT; -- Average time to generate

-- Table: adobe_template_variables
-- Defines all variable fields in each template
CREATE TABLE IF NOT EXISTS adobe_template_variables (
    variable_id SERIAL PRIMARY KEY,
    template_id INT REFERENCES media_templates(template_id),
    variable_name VARCHAR(100) NOT NULL, -- 'candidate_name', 'district', 'event_date'
    variable_type VARCHAR(50) NOT NULL, -- 'text', 'image', 'color', 'date', 'number'
    data_source VARCHAR(100), -- 'candidates.first_name', 'campaign_events.event_date'
    default_value TEXT,
    is_required BOOLEAN DEFAULT TRUE,
    validation_rules JSONB, -- {"min_length": 5, "max_length": 50, "pattern": "^[A-Z]"}
    adobe_layer_name VARCHAR(100), -- For PSD/AI: layer to replace
    position JSONB, -- {"x": 100, "y": 200, "width": 300, "height": 50}
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_template_vars_template ON adobe_template_variables(template_id);

-- =====================================================
-- SECTION 3: ADOBE API USAGE TRACKING
-- =====================================================

-- Table: adobe_api_usage_log
-- Comprehensive log of all Adobe API calls
CREATE TABLE IF NOT EXISTS adobe_api_usage_log (
    log_id SERIAL PRIMARY KEY,
    api_service VARCHAR(50) NOT NULL, -- 'firefly', 'photoshop', 'illustrator', 'express', 'pdf_services', 'aem'
    api_endpoint VARCHAR(200) NOT NULL, -- '/v3/images/generate', '/pie/psdService/smartObject'
    http_method VARCHAR(10), -- 'GET', 'POST', 'PUT'
    request_params JSONB, -- Full request payload
    response_status INT, -- HTTP status code (200, 400, 500, etc.)
    response_body JSONB, -- API response
    response_time_ms INT,
    api_cost NUMERIC(10,4), -- Cost per API call
    campaign_event_id INT REFERENCES campaign_events(campaign_event_id),
    template_id INT REFERENCES media_templates(template_id),
    error_message TEXT,
    called_by VARCHAR(100), -- 'system', 'user_email@domain.com'
    called_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_adobe_api_log_service ON adobe_api_usage_log(api_service);
CREATE INDEX idx_adobe_api_log_endpoint ON adobe_api_usage_log(api_endpoint);
CREATE INDEX idx_adobe_api_log_date ON adobe_api_usage_log(called_at DESC);
CREATE INDEX idx_adobe_api_log_campaign ON adobe_api_usage_log(campaign_event_id);

-- Table: adobe_firefly_generations
-- Specific tracking for Firefly AI generations
CREATE TABLE IF NOT EXISTS adobe_firefly_generations (
    generation_id SERIAL PRIMARY KEY,
    campaign_event_id INT REFERENCES campaign_events(campaign_event_id),
    donor_id INT REFERENCES donors(donor_id),
    firefly_api_endpoint VARCHAR(100) NOT NULL, -- 'text-to-image', 'generative-fill', 'generative-expand'
    firefly_model_id VARCHAR(100), -- If using custom model
    input_prompt TEXT NOT NULL,
    prompt_metadata JSONB, -- {style, contentClass, size, negativePrompt}
    output_image_url VARCHAR(500),
    output_format VARCHAR(10), -- 'png', 'jpg', 'webp'
    output_size_width INT,
    output_size_height INT,
    generation_time_ms INT,
    generation_cost NUMERIC(10,4), -- $0.10 per generation typical
    quality_score NUMERIC(3,2), -- AI-assessed quality (0.0 to 1.0)
    used_in_final_output BOOLEAN DEFAULT FALSE,
    generated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_firefly_gen_campaign ON adobe_firefly_generations(campaign_event_id);
CREATE INDEX idx_firefly_gen_donor ON adobe_firefly_generations(donor_id);
CREATE INDEX idx_firefly_gen_model ON adobe_firefly_generations(firefly_model_id);
CREATE INDEX idx_firefly_gen_date ON adobe_firefly_generations(generated_at DESC);

-- =====================================================
-- SECTION 4: GENERATED MEDIA ASSETS WITH ADOBE INTEGRATION
-- =====================================================

-- Update existing generated_media_assets table with Adobe fields
ALTER TABLE generated_media_assets
ADD COLUMN IF NOT EXISTS aem_asset_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS aem_dam_path VARCHAR(500),
ADD COLUMN IF NOT EXISTS r2_bucket VARCHAR(100) DEFAULT 'broyhillgop-generated',
ADD COLUMN IF NOT EXISTS r2_key VARCHAR(500),
ADD COLUMN IF NOT EXISTS r2_public_url VARCHAR(500),
ADD COLUMN IF NOT EXISTS adobe_apis_used TEXT[], -- ARRAY['firefly-text-to-image', 'express-template-generate']
ADD COLUMN IF NOT EXISTS total_adobe_api_cost NUMERIC(10,4),
ADD COLUMN IF NOT EXISTS generation_time_total_ms INT,
ADD COLUMN IF NOT EXISTS adobe_processing_log JSONB; -- Detailed log of each Adobe API call

-- Table: adobe_batch_jobs
-- Tracks batch generation jobs (e.g., 500 personalized emails in one job)
CREATE TABLE IF NOT EXISTS adobe_batch_jobs (
    job_id SERIAL PRIMARY KEY,
    campaign_event_id INT REFERENCES campaign_events(campaign_event_id),
    template_id INT REFERENCES media_templates(template_id),
    job_type VARCHAR(50), -- 'email_generation', 'postcard_generation', 'social_media_generation'
    total_assets_requested INT,
    assets_completed INT DEFAULT 0,
    assets_failed INT DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    total_cost NUMERIC(12,2),
    average_generation_time_ms INT,
    error_log JSONB, -- Array of errors encountered
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_batch_jobs_campaign ON adobe_batch_jobs(campaign_event_id);
CREATE INDEX idx_batch_jobs_status ON adobe_batch_jobs(status);
CREATE INDEX idx_batch_jobs_date ON adobe_batch_jobs(created_at DESC);

-- =====================================================
-- SECTION 5: CANDIDATE MEDIA ARCHIVE WITH ADOBE
-- =====================================================

-- Update existing candidate_media_archive table
ALTER TABLE candidate_media_archive
ADD COLUMN IF NOT EXISTS aem_reference VARCHAR(500),
ADD COLUMN IF NOT EXISTS aem_asset_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS adobe_apis_used TEXT[],
ADD COLUMN IF NOT EXISTS adobe_generation_cost NUMERIC(10,4),
ADD COLUMN IF NOT EXISTS r2_public_url VARCHAR(500),
ADD COLUMN IF NOT EXISTS performance_vs_template_baseline NUMERIC(5,2); -- +22% better than template average

-- Table: adobe_asset_versions
-- Track version history of archived assets
CREATE TABLE IF NOT EXISTS adobe_asset_versions (
    version_id SERIAL PRIMARY KEY,
    archive_id INT REFERENCES candidate_media_archive(archive_id),
    aem_version_id VARCHAR(100), -- AEM's internal version ID
    version_number INT NOT NULL,
    changed_by VARCHAR(100),
    change_description TEXT,
    aem_asset_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_asset_versions_archive ON adobe_asset_versions(archive_id);

-- =====================================================
-- SECTION 6: ADOBE COST TRACKING & REPORTING
-- =====================================================

-- Table: adobe_monthly_costs
-- Aggregate monthly Adobe API costs by service
CREATE TABLE IF NOT EXISTS adobe_monthly_costs (
    cost_id SERIAL PRIMARY KEY,
    month_year VARCHAR(7) NOT NULL, -- '2025-11'
    api_service VARCHAR(50) NOT NULL, -- 'firefly', 'photoshop', 'express', etc.
    total_api_calls INT DEFAULT 0,
    total_cost NUMERIC(12,2) DEFAULT 0,
    avg_cost_per_call NUMERIC(10,4),
    top_campaign_type_id INT REFERENCES campaign_types(campaign_type_id), -- Which campaign type used most
    top_candidate_id INT REFERENCES candidates(candidate_id), -- Which candidate used most
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (month_year, api_service)
);

CREATE INDEX idx_monthly_costs_month ON adobe_monthly_costs(month_year DESC);
CREATE INDEX idx_monthly_costs_service ON adobe_monthly_costs(api_service);

-- Function: Calculate monthly Adobe costs
CREATE OR REPLACE FUNCTION calculate_adobe_monthly_costs()
RETURNS void AS $$
BEGIN
    INSERT INTO adobe_monthly_costs (month_year, api_service, total_api_calls, total_cost, avg_cost_per_call)
    SELECT 
        TO_CHAR(called_at, 'YYYY-MM') AS month_year,
        api_service,
        COUNT(*) AS total_api_calls,
        COALESCE(SUM(api_cost), 0) AS total_cost,
        COALESCE(AVG(api_cost), 0) AS avg_cost_per_call
    FROM adobe_api_usage_log
    WHERE called_at >= DATE_TRUNC('month', NOW() - INTERVAL '1 month')
      AND called_at < DATE_TRUNC('month', NOW())
    GROUP BY TO_CHAR(called_at, 'YYYY-MM'), api_service
    ON CONFLICT (month_year, api_service) 
    DO UPDATE SET 
        total_api_calls = EXCLUDED.total_api_calls,
        total_cost = EXCLUDED.total_cost,
        avg_cost_per_call = EXCLUDED.avg_cost_per_call;
END;
$$ LANGUAGE plpgsql;

-- Schedule monthly cost calculation (runs on 1st of each month)
SELECT cron.schedule('calculate-adobe-costs', '0 2 1 * *', 'SELECT calculate_adobe_monthly_costs()');

-- =====================================================
-- SECTION 7: ADOBE PERFORMANCE ANALYTICS VIEWS
-- =====================================================

-- View: Adobe API Performance Dashboard
CREATE OR REPLACE VIEW adobe_api_performance_dashboard AS
SELECT 
    api_service,
    api_endpoint,
    COUNT(*) AS total_calls,
    COUNT(CASE WHEN response_status = 200 THEN 1 END) AS successful_calls,
    COUNT(CASE WHEN response_status != 200 THEN 1 END) AS failed_calls,
    ROUND(COUNT(CASE WHEN response_status = 200 THEN 1 END)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2) AS success_rate_pct,
    ROUND(AVG(response_time_ms), 0) AS avg_response_time_ms,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms), 0) AS p95_response_time_ms,
    COALESCE(SUM(api_cost), 0) AS total_cost,
    ROUND(AVG(api_cost), 4) AS avg_cost_per_call
FROM adobe_api_usage_log
WHERE called_at >= NOW() - INTERVAL '30 days'
GROUP BY api_service, api_endpoint
ORDER BY total_calls DESC;

-- View: Firefly Custom Model Performance
CREATE OR REPLACE VIEW firefly_model_performance AS
SELECT 
    m.model_id,
    m.model_name,
    c.first_name || ' ' || c.last_name AS candidate_name,
    c.office_type,
    m.training_cost,
    m.usage_count,
    COUNT(g.generation_id) AS total_generations,
    COALESCE(SUM(g.generation_cost), 0) AS total_generation_cost,
    ROUND(AVG(g.quality_score), 2) AS avg_quality_score,
    ROUND(AVG(g.generation_time_ms), 0) AS avg_generation_time_ms,
    m.trained_at,
    m.last_used
FROM adobe_firefly_custom_models m
JOIN candidates c ON m.candidate_id = c.candidate_id
LEFT JOIN adobe_firefly_generations g ON m.firefly_model_id = g.firefly_model_id
WHERE m.training_status = 'completed'
GROUP BY m.model_id, m.model_name, c.first_name, c.last_name, c.office_type, m.training_cost, m.usage_count, m.trained_at, m.last_used
ORDER BY total_generations DESC;

-- View: Template Generation Cost Analysis
CREATE OR REPLACE VIEW template_generation_cost_analysis AS
SELECT 
    mt.template_name,
    mt.office_type,
    ct.name AS campaign_type,
    COUNT(gma.generated_id) AS times_generated,
    COALESCE(SUM(gma.total_adobe_api_cost), 0) AS total_adobe_cost,
    ROUND(AVG(gma.total_adobe_api_cost), 4) AS avg_cost_per_generation,
    ROUND(AVG(gma.generation_time_total_ms), 0) AS avg_generation_time_ms,
    COUNT(DISTINCT gma.campaign_event_id) AS campaigns_used_in,
    COALESCE(SUM(dc.donation_amount), 0) AS total_revenue_generated,
    ROUND((COALESCE(SUM(dc.donation_amount), 0) - COALESCE(SUM(gma.total_adobe_api_cost), 0)) / NULLIF(SUM(gma.total_adobe_api_cost), 0) * 100, 2) AS roi_pct
FROM media_templates mt
LEFT JOIN generated_media_assets gma ON mt.template_id = gma.template_id
LEFT JOIN campaign_events ce ON gma.campaign_event_id = ce.campaign_event_id
LEFT JOIN campaign_types ct ON ce.campaign_type_id = ct.campaign_type_id
LEFT JOIN donor_communications dc ON gma.campaign_event_id = dc.campaign_event_id AND dc.donated = TRUE
WHERE gma.generated_at >= NOW() - INTERVAL '90 days'
GROUP BY mt.template_name, mt.office_type, ct.name
ORDER BY total_revenue_generated DESC;

-- Comments
COMMENT ON TABLE adobe_aem_assets IS 'All assets stored in Adobe Experience Manager with metadata';
COMMENT ON TABLE adobe_brand_kits IS 'Brand kit definitions per candidate for Adobe Express';
COMMENT ON TABLE adobe_firefly_custom_models IS 'Firefly AI Custom Models trained on candidate brands';
COMMENT ON TABLE adobe_api_usage_log IS 'Comprehensive log of all Adobe API calls with cost tracking';
COMMENT ON TABLE adobe_firefly_generations IS 'Specific tracking for Firefly AI image generations';
COMMENT ON TABLE adobe_batch_jobs IS 'Batch generation jobs (e.g., 500 personalized emails)';
COMMENT ON TABLE adobe_monthly_costs IS 'Aggregate monthly Adobe API costs by service';
COMMENT ON VIEW adobe_api_performance_dashboard IS 'Real-time Adobe API performance metrics';
COMMENT ON VIEW firefly_model_performance IS 'Firefly Custom Model usage and performance analysis';
COMMENT ON VIEW template_generation_cost_analysis IS 'Cost-benefit analysis per template with Adobe costs';
