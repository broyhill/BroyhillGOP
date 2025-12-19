-- ============================================================================
-- NEXUS HARVEST ENRICHMENT SYSTEM - DATABASE MIGRATION
-- ============================================================================
-- Manages 150K harvest records for social media lookup and enrichment
-- Controlled by E20 Intelligence Brain
-- 
-- RUN AFTER: 001_NEXUS_SOCIAL_EXTENSION.sql
-- ============================================================================

-- ============================================================================
-- ENRICHMENT WATERFALL CONFIGURATION
-- Defines order of free data sources to query
-- ============================================================================

CREATE TABLE IF NOT EXISTS nexus_enrichment_waterfall (
    waterfall_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    waterfall_name VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    enrichment_goal VARCHAR(100) NOT NULL,
    steps JSONB NOT NULL DEFAULT '[]',
    stop_on_success BOOLEAN DEFAULT FALSE,
    max_sources INT DEFAULT 5,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Default waterfall for donor enrichment
INSERT INTO nexus_enrichment_waterfall (waterfall_name, target_type, enrichment_goal, steps) VALUES
('donor_political_profile', 'donor', 'political_data', 
 '[
   {"order": 1, "source": "nc_sboe", "fields": ["voter_status", "party", "primary_history"]},
   {"order": 2, "source": "fec_api", "fields": ["fec_total", "fec_committees", "fec_employers"]},
   {"order": 3, "source": "opensecrets", "fields": ["total_contributions"]}
 ]'::jsonb),
('donor_wealth_indicators', 'donor', 'wealth_data',
 '[
   {"order": 1, "source": "county_property", "fields": ["property_value", "property_count"]},
   {"order": 2, "source": "nc_sos", "fields": ["business_names", "business_owner"]},
   {"order": 3, "source": "sec_edgar", "fields": ["sec_executive"]}
 ]'::jsonb),
('harvest_social_lookup', 'harvest', 'social_profiles',
 '[
   {"order": 1, "source": "internal_match", "fields": ["matched_donor_id", "matched_volunteer_id"]},
   {"order": 2, "source": "nc_sboe", "fields": ["voter_record"]},
   {"order": 3, "source": "fec_api", "fields": ["fec_record"]}
 ]'::jsonb)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- MATCH SCORING FUNCTION
-- Used by E20 Brain to prioritize enrichment
-- ============================================================================

CREATE OR REPLACE FUNCTION nexus_calculate_match_score(
    p_harvest_id UUID
) RETURNS INT AS $$
DECLARE
    v_score INT := 0;
    v_record nexus_harvest_records%ROWTYPE;
BEGIN
    SELECT * INTO v_record FROM nexus_harvest_records WHERE harvest_id = p_harvest_id;
    
    IF NOT FOUND THEN RETURN 0; END IF;
    
    -- Email present: +30
    IF v_record.raw_email IS NOT NULL THEN v_score := v_score + 30; END IF;
    
    -- Phone present: +20
    IF v_record.raw_phone IS NOT NULL THEN v_score := v_score + 20; END IF;
    
    -- Full name present: +15
    IF v_record.raw_first_name IS NOT NULL AND v_record.raw_last_name IS NOT NULL THEN 
        v_score := v_score + 15; 
    END IF;
    
    -- Address present: +10
    IF v_record.raw_address IS NOT NULL THEN v_score := v_score + 10; END IF;
    
    -- Social ID present: +25 each
    IF v_record.facebook_id IS NOT NULL THEN v_score := v_score + 25; END IF;
    IF v_record.twitter_handle IS NOT NULL THEN v_score := v_score + 25; END IF;
    IF v_record.linkedin_url IS NOT NULL THEN v_score := v_score + 25; END IF;
    
    RETURN LEAST(100, v_score);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- APPLY ENRICHMENT TO DONOR
-- Moves data from enrichment results to donor record
-- ============================================================================

CREATE OR REPLACE FUNCTION nexus_apply_enrichment_to_donor(
    p_donor_id UUID,
    p_harvest_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_harvest nexus_harvest_records%ROWTYPE;
    v_updated BOOLEAN := FALSE;
BEGIN
    -- Get harvest record if provided
    IF p_harvest_id IS NOT NULL THEN
        SELECT * INTO v_harvest FROM nexus_harvest_records WHERE harvest_id = p_harvest_id;
        
        IF FOUND THEN
            -- Apply social profiles from harvest
            UPDATE donors SET
                social_facebook_url = COALESCE(social_facebook_url, v_harvest.facebook_url),
                social_facebook_id = COALESCE(social_facebook_id, v_harvest.facebook_id),
                social_twitter_handle = COALESCE(social_twitter_handle, v_harvest.twitter_handle),
                social_instagram_handle = COALESCE(social_instagram_handle, v_harvest.instagram_handle),
                social_linkedin_url = COALESCE(social_linkedin_url, v_harvest.linkedin_url),
                nexus_harvest_id = p_harvest_id,
                nexus_enriched = TRUE,
                nexus_enriched_at = NOW()
            WHERE donor_id = p_donor_id;
            
            v_updated := TRUE;
        END IF;
    END IF;
    
    -- Mark donor as enriched
    UPDATE donors SET
        nexus_enriched = TRUE,
        nexus_enriched_at = NOW()
    WHERE donor_id = p_donor_id;
    
    RETURN v_updated;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- APPLY ENRICHMENT TO VOLUNTEER
-- ============================================================================

CREATE OR REPLACE FUNCTION nexus_apply_enrichment_to_volunteer(
    p_volunteer_id UUID,
    p_harvest_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_harvest nexus_harvest_records%ROWTYPE;
BEGIN
    IF p_harvest_id IS NOT NULL THEN
        SELECT * INTO v_harvest FROM nexus_harvest_records WHERE harvest_id = p_harvest_id;
        
        IF FOUND THEN
            UPDATE volunteers SET
                social_facebook_url = COALESCE(social_facebook_url, v_harvest.facebook_url),
                social_twitter_handle = COALESCE(social_twitter_handle, v_harvest.twitter_handle),
                social_instagram_handle = COALESCE(social_instagram_handle, v_harvest.instagram_handle),
                social_linkedin_url = COALESCE(social_linkedin_url, v_harvest.linkedin_url),
                nexus_harvest_id = p_harvest_id,
                nexus_enriched = TRUE,
                nexus_enriched_at = NOW()
            WHERE volunteer_id = p_volunteer_id;
            
            RETURN TRUE;
        END IF;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- BATCH PROCESSING VIEWS
-- ============================================================================

-- Harvest records ready for matching
CREATE OR REPLACE VIEW v_nexus_harvest_ready_to_match AS
SELECT 
    h.harvest_id,
    h.raw_email,
    h.raw_phone,
    h.raw_first_name,
    h.raw_last_name,
    h.facebook_id,
    h.twitter_handle,
    nexus_calculate_match_score(h.harvest_id) AS match_score,
    h.enrichment_priority
FROM nexus_harvest_records h
WHERE h.enrichment_status = 'pending'
AND h.matched_donor_id IS NULL
AND h.matched_volunteer_id IS NULL
AND (h.raw_email IS NOT NULL OR h.raw_phone IS NOT NULL OR h.facebook_id IS NOT NULL)
ORDER BY h.enrichment_priority DESC, match_score DESC
LIMIT 1000;

-- Donors needing enrichment
CREATE OR REPLACE VIEW v_nexus_donors_need_enrichment AS
SELECT 
    d.donor_id,
    d.first_name,
    d.last_name,
    d.email,
    d.phone,
    d.nexus_enriched,
    CASE 
        WHEN d.nexus_fec_total IS NULL THEN 'fec_check'
        WHEN d.nexus_property_value IS NULL THEN 'property_check'
        WHEN d.nexus_primary_voter_score IS NULL THEN 'voter_check'
        WHEN d.social_facebook_url IS NULL AND d.social_twitter_handle IS NULL THEN 'social_lookup'
        ELSE 'complete'
    END AS next_enrichment_type
FROM donors d
WHERE d.nexus_enriched = FALSE
OR (d.nexus_fec_total IS NULL AND d.email IS NOT NULL)
OR (d.nexus_property_value IS NULL AND d.address IS NOT NULL)
ORDER BY d.lifetime_value DESC NULLS LAST
LIMIT 500;

-- Enrichment queue dashboard
CREATE OR REPLACE VIEW v_nexus_enrichment_dashboard AS
SELECT 
    target_type,
    enrichment_type,
    status,
    COUNT(*) AS count,
    AVG(attempts) AS avg_attempts,
    MIN(created_at) AS oldest,
    MAX(created_at) AS newest
FROM nexus_enrichment_queue
GROUP BY target_type, enrichment_type, status
ORDER BY target_type, enrichment_type, status;

-- ============================================================================
-- SCHEMA COMPLETE
-- ============================================================================

SELECT 'NEXUS Harvest Enrichment migration complete!' AS status;
