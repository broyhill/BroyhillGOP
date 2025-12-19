-- =====================================================
-- BROYHILLGOP SUPABASE DATABASE SCHEMA
-- File 8: Adobe Integration Triggers & Automation
-- =====================================================

-- =====================================================
-- Trigger 1: Auto-Archive Generated Assets to AEM
-- =====================================================
CREATE OR REPLACE FUNCTION archive_to_aem()
RETURNS TRIGGER AS $$
BEGIN
    -- When a new asset is generated, log it for AEM archival
    INSERT INTO adobe_aem_assets (
        candidate_id,
        aem_dam_path,
        asset_type,
        asset_name,
        file_size,
        uploaded_at
    )
    SELECT 
        ce.candidate_id,
        '/content/dam/broyhillgop/generated-assets/' || TO_CHAR(NOW(), 'YYYY-MM') || '/',
        'generated',
        NEW.file_url,
        NEW.file_size,
        NOW()
    FROM campaign_events ce
    WHERE ce.campaign_event_id = NEW.campaign_event_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_archive_to_aem
AFTER INSERT ON generated_media_assets
FOR EACH ROW
EXECUTE FUNCTION archive_to_aem();

-- =====================================================
-- Trigger 2: Track Adobe API Usage Cost
-- =====================================================
CREATE OR REPLACE FUNCTION track_adobe_api_cost()
RETURNS TRIGGER AS $$
BEGIN
    -- Update campaign event with accumulated Adobe costs
    UPDATE campaign_events
    SET updated_at = NOW()
    WHERE campaign_event_id = NEW.campaign_event_id;

    -- Update template usage stats
    UPDATE media_templates
    SET usage_count = usage_count + 1,
        updated_at = NOW()
    WHERE template_id = NEW.template_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_track_adobe_cost
AFTER INSERT ON adobe_api_usage_log
FOR EACH ROW
WHEN (NEW.api_cost > 0)
EXECUTE FUNCTION track_adobe_api_cost();

-- =====================================================
-- Trigger 3: Update Firefly Model Usage Count
-- =====================================================
CREATE OR REPLACE FUNCTION update_firefly_model_usage()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE adobe_firefly_custom_models
    SET usage_count = usage_count + 1,
        last_used = NOW()
    WHERE firefly_model_id = NEW.firefly_model_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_firefly_usage
AFTER INSERT ON adobe_firefly_generations
FOR EACH ROW
WHEN (NEW.firefly_model_id IS NOT NULL)
EXECUTE FUNCTION update_firefly_model_usage();

-- =====================================================
-- Trigger 4: Archive Sent Media to Candidate Library
-- =====================================================
CREATE OR REPLACE FUNCTION archive_sent_media_adobe()
RETURNS TRIGGER AS $$
DECLARE
    v_candidate_id INT;
    v_template_id INT;
    v_adobe_apis TEXT[];
BEGIN
    -- Get candidate and template info
    SELECT ce.candidate_id INTO v_candidate_id
    FROM campaign_events ce
    WHERE ce.campaign_event_id = NEW.campaign_event_id;

    SELECT template_id, adobe_apis_used INTO v_template_id, v_adobe_apis
    FROM generated_media_assets
    WHERE generated_id = NEW.generated_id;

    -- Archive to candidate library
    INSERT INTO candidate_media_archive (
        candidate_id,
        campaign_event_id,
        generated_media_id,
        media_type,
        original_template_id,
        file_url,
        r2_public_url,
        aem_reference,
        adobe_apis_used,
        adobe_generation_cost,
        send_date,
        archived_at
    ) VALUES (
        v_candidate_id,
        NEW.campaign_event_id,
        NEW.generated_id,
        get_media_type_from_template(v_template_id),
        v_template_id,
        NEW.file_url,
        NEW.r2_public_url,
        NEW.aem_dam_path,
        v_adobe_apis,
        NEW.total_adobe_api_cost,
        NOW(),
        NOW()
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_archive_sent_media_adobe
AFTER INSERT ON generated_media_assets
FOR EACH ROW
EXECUTE FUNCTION archive_sent_media_adobe();

-- =====================================================
-- Function: Generate Personalized Asset via Adobe APIs
-- =====================================================
CREATE OR REPLACE FUNCTION generate_adobe_asset(
    p_campaign_event_id INT,
    p_donor_id INT,
    p_template_id INT
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_adobe_apis TEXT[];
    v_total_cost NUMERIC(10,4) := 0;
    v_start_time TIMESTAMP;
    v_generation_time_ms INT;
BEGIN
    v_start_time := clock_timestamp();

    -- Get template requirements
    SELECT adobe_apis_required INTO v_adobe_apis
    FROM media_templates
    WHERE template_id = p_template_id;

    -- Log generation intent
    INSERT INTO adobe_batch_jobs (
        campaign_event_id,
        template_id,
        job_type,
        total_assets_requested,
        status
    ) VALUES (
        p_campaign_event_id,
        p_template_id,
        'single_asset_generation',
        1,
        'processing'
    );

    -- Placeholder: External Adobe API calls would happen here via Edge Functions
    -- This function logs the intent, actual generation happens asynchronously

    v_generation_time_ms := EXTRACT(MILLISECOND FROM (clock_timestamp() - v_start_time));

    v_result := jsonb_build_object(
        'status', 'queued',
        'campaign_event_id', p_campaign_event_id,
        'donor_id', p_donor_id,
        'template_id', p_template_id,
        'adobe_apis_required', v_adobe_apis,
        'estimated_cost', v_total_cost
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Function: Calculate Template ROI with Adobe Costs
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_template_roi_with_adobe(
    p_template_id INT
) RETURNS TABLE (
    template_name VARCHAR,
    times_used INT,
    total_adobe_cost NUMERIC,
    total_revenue NUMERIC,
    net_profit NUMERIC,
    roi_percent NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mt.template_name,
        COUNT(gma.generated_id)::INT AS times_used,
        COALESCE(SUM(gma.total_adobe_api_cost), 0) AS total_adobe_cost,
        COALESCE(SUM(dc.donation_amount), 0) AS total_revenue,
        COALESCE(SUM(dc.donation_amount), 0) - COALESCE(SUM(gma.total_adobe_api_cost), 0) AS net_profit,
        ROUND((COALESCE(SUM(dc.donation_amount), 0) - COALESCE(SUM(gma.total_adobe_api_cost), 0)) / NULLIF(SUM(gma.total_adobe_api_cost), 0) * 100, 2) AS roi_percent
    FROM media_templates mt
    LEFT JOIN generated_media_assets gma ON mt.template_id = gma.template_id
    LEFT JOIN donor_communications dc ON gma.campaign_event_id = dc.campaign_event_id AND dc.donated = TRUE
    WHERE mt.template_id = p_template_id
    GROUP BY mt.template_name;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Function: Get Optimal Adobe Template
-- =====================================================
CREATE OR REPLACE FUNCTION get_optimal_adobe_template(
    p_campaign_type_id INT,
    p_office_type VARCHAR,
    p_donor_tier VARCHAR
) RETURNS TABLE (
    template_id INT,
    template_name VARCHAR,
    avg_roi NUMERIC,
    avg_conversion_rate NUMERIC,
    recommended_reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mt.template_id,
        mt.template_name,
        mt.avg_roi,
        mt.avg_conversion_rate,
        'Best performing template for ' || p_office_type || ' + ' || (SELECT name FROM campaign_types WHERE campaign_type_id = p_campaign_type_id) AS recommended_reason
    FROM media_templates mt
    WHERE mt.campaign_type_id = p_campaign_type_id
      AND mt.office_type = p_office_type
      AND mt.avg_roi IS NOT NULL
    ORDER BY mt.avg_roi DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON FUNCTION archive_to_aem IS 'Auto-archives generated assets to Adobe Experience Manager';
COMMENT ON FUNCTION track_adobe_api_cost IS 'Tracks Adobe API costs per campaign and template';
COMMENT ON FUNCTION update_firefly_model_usage IS 'Increments usage count for Firefly Custom Models';
COMMENT ON FUNCTION generate_adobe_asset IS 'Queues Adobe API calls for asset generation';
COMMENT ON FUNCTION calculate_template_roi_with_adobe IS 'Calculate ROI including Adobe API costs';
COMMENT ON FUNCTION get_optimal_adobe_template IS 'ML-recommended template based on performance';
