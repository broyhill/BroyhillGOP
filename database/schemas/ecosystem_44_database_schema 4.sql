-- =====================================================================
-- ECOSYSTEM 44: SOCIAL INTELLIGENCE & PROSPECT DISCOVERY
-- Complete PostgreSQL Schema for Supabase
-- =====================================================================
-- 
-- PURPOSE:
--   - Store scraped social media prospects
--   - Track enrichment from FREE government data sources
--   - Score and grade prospects for import to donors table
--   - Audit all activity for compliance
--
-- TABLES (8):
--   1. scraping_targets - Social accounts to monitor
--   2. discovered_prospects - Raw profiles from scraping
--   3. enrichment_queue - Prospects awaiting enrichment
--   4. enriched_prospects - Complete profiles after enrichment
--   5. data_sources - FREE and premium source configs
--   6. enrichment_audit_log - Complete audit trail
--   7. scraping_activity_log - Scraping audit
--   8. import_batches - Import history to donors table
--
-- INTEGRATION:
--   - Ecosystem 0 (DataHub) - Imports to broyhillgop.donors
--   - Ecosystem 1 (Donor Intelligence) - Uses same scoring
--   - Ecosystem 20 (Intelligence Brain) - Triggers workflows
--   - Event Bus - Publishes prospect.* events
--
-- AUTHOR: Claude (Anthropic)
-- DATE: December 13, 2025
-- VERSION: 1.0.0
-- =====================================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS social_intelligence;

-- Set search path
SET search_path TO social_intelligence, public;

-- =====================================================================
-- TABLE 1: SCRAPING TARGETS
-- Social media accounts/pages to scrape for prospects
-- =====================================================================

CREATE TABLE social_intelligence.scraping_targets (
    -- Primary key
    target_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Platform info
    platform VARCHAR(50) NOT NULL CHECK (platform IN ('twitter', 'facebook', 'linkedin', 'instagram', 'truth_social', 'parler', 'gab')),
    target_type VARCHAR(50) NOT NULL CHECK (target_type IN ('user', 'page', 'group', 'hashtag', 'company')),
    
    -- Target identifiers (use appropriate field based on platform)
    handle VARCHAR(255),           -- Twitter/Instagram username
    page_id VARCHAR(255),          -- Facebook page ID
    group_id VARCHAR(255),         -- Facebook group ID
    company_id VARCHAR(255),       -- LinkedIn company ID
    hashtag VARCHAR(255),          -- Hashtag to track
    
    -- Display info
    target_name VARCHAR(255) NOT NULL,
    target_description TEXT,
    target_url VARCHAR(500),
    
    -- Scraping configuration
    scrape_frequency VARCHAR(50) DEFAULT 'daily' CHECK (scrape_frequency IN ('hourly', 'daily', 'weekly', 'monthly')),
    scrape_type VARCHAR(50) DEFAULT 'followers' CHECK (scrape_type IN ('followers', 'likers', 'members', 'commenters', 'retweeters', 'connections')),
    max_results_per_scrape INTEGER DEFAULT 1000,
    min_conservative_score DECIMAL(3,1) DEFAULT 6.0,
    
    -- Scheduling
    next_scrape_at TIMESTAMPTZ,
    last_scraped_at TIMESTAMPTZ,
    
    -- Performance tracking
    total_scrapes INTEGER DEFAULT 0,
    total_prospects_found INTEGER DEFAULT 0,
    avg_prospects_per_scrape DECIMAL(10,2) DEFAULT 0,
    success_rate DECIMAL(5,2) DEFAULT 100.00,
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(255) DEFAULT 'system',
    notes TEXT
);

-- Indexes for scraping_targets
CREATE INDEX idx_targets_platform ON social_intelligence.scraping_targets(platform);
CREATE INDEX idx_targets_active ON social_intelligence.scraping_targets(active) WHERE active = TRUE;
CREATE INDEX idx_targets_next_scrape ON social_intelligence.scraping_targets(next_scrape_at) WHERE active = TRUE;
CREATE INDEX idx_targets_priority ON social_intelligence.scraping_targets(priority DESC, next_scrape_at ASC);

-- =====================================================================
-- TABLE 2: DISCOVERED PROSPECTS
-- Raw profiles scraped from social media
-- =====================================================================

CREATE TABLE social_intelligence.discovered_prospects (
    -- Primary key
    prospect_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source tracking
    discovered_from_target_id UUID REFERENCES social_intelligence.scraping_targets(target_id),
    discovered_at TIMESTAMPTZ DEFAULT NOW(),
    discovery_method VARCHAR(50),  -- 'followers', 'likers', 'members', etc.
    
    -- Platform info
    platform VARCHAR(50) NOT NULL,
    social_handle VARCHAR(255),
    social_user_id VARCHAR(255),
    profile_url VARCHAR(500),
    
    -- Profile data (raw from social media)
    display_name VARCHAR(255),
    bio TEXT,
    location VARCHAR(255),
    website VARCHAR(500),
    
    -- Social metrics
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    post_count INTEGER DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    account_created_at TIMESTAMPTZ,
    
    -- Conservative scoring (from bio/profile analysis)
    conservative_score DECIMAL(4,2) DEFAULT 0.00 CHECK (conservative_score BETWEEN 0 AND 10),
    political_keywords TEXT[],
    political_signals JSONB DEFAULT '{}',
    
    -- Parsed contact info (if available in profile)
    parsed_email VARCHAR(255),
    parsed_phone VARCHAR(50),
    parsed_city VARCHAR(100),
    parsed_state VARCHAR(50),
    
    -- Enrichment status
    enrichment_status VARCHAR(50) DEFAULT 'pending' CHECK (enrichment_status IN ('pending', 'queued', 'in_progress', 'enriched', 'failed', 'skipped')),
    enrichment_priority INTEGER DEFAULT 5,
    enrichment_attempts INTEGER DEFAULT 0,
    enrichment_started_at TIMESTAMPTZ,
    enrichment_completed_at TIMESTAMPTZ,
    enrichment_confidence DECIMAL(5,4),
    
    -- Processing flags
    processed BOOLEAN DEFAULT FALSE,
    imported_to_donors BOOLEAN DEFAULT FALSE,
    imported_at TIMESTAMPTZ,
    imported_donor_id UUID,
    
    -- Deduplication
    fingerprint VARCHAR(64),  -- Hash for deduplication
    duplicate_of UUID REFERENCES social_intelligence.discovered_prospects(prospect_id),
    
    -- Raw data storage
    raw_data JSONB,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for discovered_prospects
CREATE INDEX idx_prospects_target ON social_intelligence.discovered_prospects(discovered_from_target_id);
CREATE INDEX idx_prospects_platform ON social_intelligence.discovered_prospects(platform);
CREATE INDEX idx_prospects_platform_user ON social_intelligence.discovered_prospects(platform, social_user_id);
CREATE INDEX idx_prospects_enrichment_status ON social_intelligence.discovered_prospects(enrichment_status);
CREATE INDEX idx_prospects_pending ON social_intelligence.discovered_prospects(enrichment_status, conservative_score DESC) 
    WHERE enrichment_status = 'pending';
CREATE INDEX idx_prospects_conservative_score ON social_intelligence.discovered_prospects(conservative_score DESC);
CREATE INDEX idx_prospects_discovered_at ON social_intelligence.discovered_prospects(discovered_at DESC);
CREATE INDEX idx_prospects_not_imported ON social_intelligence.discovered_prospects(enrichment_status, imported_to_donors) 
    WHERE enrichment_status = 'enriched' AND imported_to_donors = FALSE;
CREATE INDEX idx_prospects_fingerprint ON social_intelligence.discovered_prospects(fingerprint);

-- =====================================================================
-- TABLE 3: ENRICHMENT QUEUE
-- Queue for prospects awaiting enrichment processing
-- =====================================================================

CREATE TABLE social_intelligence.enrichment_queue (
    -- Primary key
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference to prospect
    prospect_id UUID NOT NULL REFERENCES social_intelligence.discovered_prospects(prospect_id),
    
    -- Queue management
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    queued_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(50) DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'skipped')),
    
    -- Processing info
    worker_id VARCHAR(100),
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    last_attempt_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    
    -- Error tracking
    error_message TEXT,
    error_code VARCHAR(50),
    
    -- Source tracking
    sources_to_query TEXT[] DEFAULT ARRAY['voter_file', 'fec', 'nc_sboe', 'property_gis', 'nc_sos_business'],
    sources_completed TEXT[] DEFAULT '{}',
    sources_failed TEXT[] DEFAULT '{}',
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for enrichment_queue
CREATE INDEX idx_queue_status ON social_intelligence.enrichment_queue(status);
CREATE INDEX idx_queue_priority ON social_intelligence.enrichment_queue(priority DESC, queued_at ASC) WHERE status = 'queued';
CREATE INDEX idx_queue_prospect ON social_intelligence.enrichment_queue(prospect_id);
CREATE INDEX idx_queue_retry ON social_intelligence.enrichment_queue(next_retry_at) WHERE status = 'failed' AND attempts < max_attempts;

-- =====================================================================
-- TABLE 4: ENRICHED PROSPECTS
-- Complete prospect profiles after enrichment
-- =====================================================================

CREATE TABLE social_intelligence.enriched_prospects (
    -- Primary key
    enriched_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference to original prospect
    prospect_id UUID NOT NULL REFERENCES social_intelligence.discovered_prospects(prospect_id),
    
    -- Contact info (from enrichment)
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    email_verified BOOLEAN DEFAULT FALSE,
    phone VARCHAR(50),
    phone_verified BOOLEAN DEFAULT FALSE,
    phone_type VARCHAR(20),  -- mobile, landline, voip
    
    -- Address (from enrichment)
    address VARCHAR(255),
    address_2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50) DEFAULT 'NC',
    zip VARCHAR(20),
    county VARCHAR(100),
    
    -- Voter registration (from Data Trust / NC SBoE - FREE)
    voter_registered BOOLEAN DEFAULT FALSE,
    voter_party VARCHAR(50),
    voter_status VARCHAR(50),
    voter_registration_date DATE,
    voter_history_elections INTEGER DEFAULT 0,
    voter_history_primaries INTEGER DEFAULT 0,
    likely_voter_score DECIMAL(4,2),
    precinct VARCHAR(50),
    congressional_district VARCHAR(10),
    state_senate_district VARCHAR(10),
    state_house_district VARCHAR(10),
    
    -- Federal donations (from FEC - FREE)
    has_federal_donations BOOLEAN DEFAULT FALSE,
    federal_donation_total DECIMAL(12,2) DEFAULT 0.00,
    federal_donation_count INTEGER DEFAULT 0,
    federal_donation_avg DECIMAL(10,2) DEFAULT 0.00,
    federal_donation_max DECIMAL(10,2) DEFAULT 0.00,
    first_federal_donation_date DATE,
    last_federal_donation_date DATE,
    federal_recipient_committees TEXT[],
    
    -- State donations (from NC SBoE - FREE)
    has_state_donations BOOLEAN DEFAULT FALSE,
    state_donation_total DECIMAL(12,2) DEFAULT 0.00,
    state_donation_count INTEGER DEFAULT 0,
    state_donation_avg DECIMAL(10,2) DEFAULT 0.00,
    first_state_donation_date DATE,
    last_state_donation_date DATE,
    
    -- Property data (from County GIS - FREE)
    owns_property BOOLEAN DEFAULT FALSE,
    property_value DECIMAL(14,2) DEFAULT 0.00,
    property_address VARCHAR(255),
    property_city VARCHAR(100),
    property_county VARCHAR(100),
    property_type VARCHAR(100),
    property_year_built INTEGER,
    property_sqft INTEGER,
    
    -- Business ownership (from NC SoS - FREE)
    owns_business BOOLEAN DEFAULT FALSE,
    business_name VARCHAR(255),
    business_type VARCHAR(100),
    business_status VARCHAR(50),
    business_formation_date DATE,
    is_registered_agent BOOLEAN DEFAULT FALSE,
    
    -- Premium data (Apollo/ZoomInfo - optional)
    premium_enriched BOOLEAN DEFAULT FALSE,
    job_title VARCHAR(255),
    company_name VARCHAR(255),
    company_size VARCHAR(50),
    linkedin_url VARCHAR(500),
    
    -- Calculated scores (same as Ecosystem 1 donor scoring)
    political_score DECIMAL(6,2) DEFAULT 0.00,      -- 0-200 scale
    donation_score DECIMAL(6,2) DEFAULT 0.00,       -- 0-250 scale
    wealth_score DECIMAL(6,2) DEFAULT 0.00,         -- 0-150 scale
    composite_score DECIMAL(6,2) DEFAULT 0.00,      -- 0-1000 scale
    predicted_grade VARCHAR(3),                      -- A+ to U-
    
    -- Data quality
    data_completeness DECIMAL(5,4) DEFAULT 0.00,    -- 0.00-1.00
    confidence_score DECIMAL(5,4) DEFAULT 0.00,     -- 0.00-1.00
    
    -- Enrichment metadata
    enrichment_sources TEXT[],
    free_sources_used INTEGER DEFAULT 0,
    premium_sources_used INTEGER DEFAULT 0,
    enrichment_cost DECIMAL(10,4) DEFAULT 0.00,
    enrichment_duration_seconds INTEGER,
    
    -- Import readiness
    ready_for_import BOOLEAN DEFAULT FALSE,
    import_blocked_reason VARCHAR(255),
    
    -- Full data snapshot
    data_snapshot JSONB,
    
    -- Metadata
    enriched_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for enriched_prospects
CREATE INDEX idx_enriched_prospect ON social_intelligence.enriched_prospects(prospect_id);
CREATE INDEX idx_enriched_grade ON social_intelligence.enriched_prospects(predicted_grade);
CREATE INDEX idx_enriched_composite ON social_intelligence.enriched_prospects(composite_score DESC);
CREATE INDEX idx_enriched_ready ON social_intelligence.enriched_prospects(ready_for_import) WHERE ready_for_import = TRUE;
CREATE INDEX idx_enriched_voter_party ON social_intelligence.enriched_prospects(voter_party) WHERE voter_registered = TRUE;
CREATE INDEX idx_enriched_has_donations ON social_intelligence.enriched_prospects(has_federal_donations, has_state_donations);
CREATE INDEX idx_enriched_high_value ON social_intelligence.enriched_prospects(composite_score DESC, confidence_score DESC) 
    WHERE composite_score >= 600 AND confidence_score >= 0.70;
CREATE INDEX idx_enriched_county ON social_intelligence.enriched_prospects(county);
CREATE INDEX idx_enriched_email ON social_intelligence.enriched_prospects(email) WHERE email IS NOT NULL;

-- =====================================================================
-- TABLE 5: DATA SOURCES
-- Configuration for FREE and premium data sources
-- =====================================================================

CREATE TABLE social_intelligence.data_sources (
    -- Primary key
    source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Source identification
    source_name VARCHAR(100) NOT NULL UNIQUE,
    source_type VARCHAR(50) NOT NULL CHECK (source_type IN ('free', 'premium', 'internal')),
    source_category VARCHAR(50) NOT NULL CHECK (source_category IN ('voter', 'donation', 'property', 'business', 'contact', 'social', 'other')),
    
    -- API configuration
    api_url VARCHAR(500),
    api_version VARCHAR(20),
    auth_type VARCHAR(50) CHECK (auth_type IN ('none', 'api_key', 'oauth', 'basic', 'bearer')),
    auth_config JSONB DEFAULT '{}',  -- Store credentials securely
    
    -- Cost tracking
    cost_per_lookup DECIMAL(10,6) DEFAULT 0.00,
    cost_per_batch DECIMAL(10,6) DEFAULT 0.00,
    monthly_cost_cap DECIMAL(10,2),
    monthly_cost_current DECIMAL(10,2) DEFAULT 0.00,
    
    -- Rate limiting
    rate_limit_requests INTEGER,
    rate_limit_window_seconds INTEGER,
    current_window_requests INTEGER DEFAULT 0,
    window_reset_at TIMESTAMPTZ,
    
    -- Performance tracking
    total_lookups INTEGER DEFAULT 0,
    successful_lookups INTEGER DEFAULT 0,
    failed_lookups INTEGER DEFAULT 0,
    avg_response_time_ms INTEGER DEFAULT 0,
    success_rate DECIMAL(5,2) DEFAULT 100.00,
    
    -- Data quality
    avg_confidence_score DECIMAL(5,4) DEFAULT 0.00,
    data_freshness_days INTEGER,  -- How old is the underlying data?
    
    -- Status
    enabled BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    
    -- Metadata
    description TEXT,
    documentation_url VARCHAR(500),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_used_at TIMESTAMPTZ
);

-- Indexes for data_sources
CREATE INDEX idx_sources_type ON social_intelligence.data_sources(source_type);
CREATE INDEX idx_sources_enabled ON social_intelligence.data_sources(enabled, priority DESC) WHERE enabled = TRUE;
CREATE INDEX idx_sources_category ON social_intelligence.data_sources(source_category);

-- =====================================================================
-- TABLE 6: ENRICHMENT AUDIT LOG
-- Complete audit trail of all enrichment lookups
-- =====================================================================

CREATE TABLE social_intelligence.enrichment_audit_log (
    -- Primary key
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- References
    prospect_id UUID REFERENCES social_intelligence.discovered_prospects(prospect_id),
    enriched_id UUID REFERENCES social_intelligence.enriched_prospects(enriched_id),
    source_id UUID REFERENCES social_intelligence.data_sources(source_id),
    
    -- Lookup details
    source_name VARCHAR(100) NOT NULL,
    lookup_type VARCHAR(50),  -- 'voter', 'donation', 'property', etc.
    
    -- Request info
    request_timestamp TIMESTAMPTZ DEFAULT NOW(),
    request_params JSONB,
    
    -- Response info
    response_timestamp TIMESTAMPTZ,
    response_time_ms INTEGER,
    response_status VARCHAR(50) CHECK (response_status IN ('success', 'not_found', 'error', 'rate_limited', 'timeout')),
    response_data JSONB,
    
    -- Match quality
    match_found BOOLEAN DEFAULT FALSE,
    match_confidence DECIMAL(5,4),
    match_type VARCHAR(50),  -- 'exact', 'fuzzy', 'partial'
    
    -- Cost tracking
    lookup_cost DECIMAL(10,6) DEFAULT 0.00,
    
    -- Error info
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for enrichment_audit_log
CREATE INDEX idx_audit_prospect ON social_intelligence.enrichment_audit_log(prospect_id);
CREATE INDEX idx_audit_source ON social_intelligence.enrichment_audit_log(source_name);
CREATE INDEX idx_audit_timestamp ON social_intelligence.enrichment_audit_log(request_timestamp DESC);
CREATE INDEX idx_audit_status ON social_intelligence.enrichment_audit_log(response_status);
CREATE INDEX idx_audit_date ON social_intelligence.enrichment_audit_log(DATE(request_timestamp));

-- Partitioning hint: Consider partitioning by month for large volumes
-- CREATE TABLE social_intelligence.enrichment_audit_log_2025_12 PARTITION OF enrichment_audit_log
--     FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

-- =====================================================================
-- TABLE 7: SCRAPING ACTIVITY LOG
-- Audit trail of all scraping sessions
-- =====================================================================

CREATE TABLE social_intelligence.scraping_activity_log (
    -- Primary key
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference to target
    target_id UUID REFERENCES social_intelligence.scraping_targets(target_id),
    
    -- Session timing
    scrape_started_at TIMESTAMPTZ DEFAULT NOW(),
    scrape_completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Status
    status VARCHAR(50) DEFAULT 'running' CHECK (status IN ('running', 'success', 'partial', 'failed', 'rate_limited')),
    
    -- Results
    prospects_discovered INTEGER DEFAULT 0,
    prospects_qualified INTEGER DEFAULT 0,  -- Met conservative score threshold
    prospects_new INTEGER DEFAULT 0,         -- Not duplicates
    prospects_duplicate INTEGER DEFAULT 0,
    
    -- API usage
    api_calls_made INTEGER DEFAULT 0,
    api_calls_failed INTEGER DEFAULT 0,
    rate_limit_hits INTEGER DEFAULT 0,
    
    -- Execution info
    execution_method VARCHAR(50) CHECK (execution_method IN ('scheduled', 'manual', 'backfill')),
    worker_id VARCHAR(100),
    
    -- Error info
    error_message TEXT,
    error_details JSONB,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for scraping_activity_log
CREATE INDEX idx_activity_target ON social_intelligence.scraping_activity_log(target_id);
CREATE INDEX idx_activity_status ON social_intelligence.scraping_activity_log(status);
CREATE INDEX idx_activity_started ON social_intelligence.scraping_activity_log(scrape_started_at DESC);
CREATE INDEX idx_activity_date ON social_intelligence.scraping_activity_log(DATE(scrape_started_at));

-- =====================================================================
-- TABLE 8: IMPORT BATCHES
-- Track imports from enriched_prospects to broyhillgop.donors
-- =====================================================================

CREATE TABLE social_intelligence.import_batches (
    -- Primary key
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Batch timing
    import_started_at TIMESTAMPTZ DEFAULT NOW(),
    import_completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Selection criteria
    min_composite_score DECIMAL(6,2),
    min_confidence_score DECIMAL(5,4),
    min_grade VARCHAR(3),
    additional_filters JSONB,
    
    -- Results
    prospects_selected INTEGER DEFAULT 0,
    prospects_imported INTEGER DEFAULT 0,
    prospects_updated INTEGER DEFAULT 0,  -- Existing donors updated
    prospects_skipped INTEGER DEFAULT 0,
    prospects_failed INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(50) DEFAULT 'running' CHECK (status IN ('running', 'completed', 'partial', 'failed')),
    
    -- Execution info
    execution_method VARCHAR(50) CHECK (execution_method IN ('scheduled', 'manual', 'triggered')),
    triggered_by VARCHAR(255),
    
    -- Error info
    error_message TEXT,
    failed_prospect_ids UUID[],
    
    -- Event bus
    events_published INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT
);

-- Indexes for import_batches
CREATE INDEX idx_batches_status ON social_intelligence.import_batches(status);
CREATE INDEX idx_batches_started ON social_intelligence.import_batches(import_started_at DESC);

-- =====================================================================
-- VIEWS
-- =====================================================================

-- View 1: High-value prospects ready for import
CREATE OR REPLACE VIEW social_intelligence.v_high_value_prospects AS
SELECT 
    ep.enriched_id,
    ep.prospect_id,
    ep.first_name,
    ep.last_name,
    ep.email,
    ep.phone,
    ep.city,
    ep.county,
    ep.voter_party,
    ep.political_score,
    ep.donation_score,
    ep.wealth_score,
    ep.composite_score,
    ep.predicted_grade,
    ep.confidence_score,
    ep.data_completeness,
    ep.federal_donation_total + ep.state_donation_total AS total_donations,
    ep.property_value,
    ep.owns_business,
    dp.platform,
    dp.social_handle,
    dp.conservative_score,
    dp.discovered_at
FROM social_intelligence.enriched_prospects ep
JOIN social_intelligence.discovered_prospects dp ON ep.prospect_id = dp.prospect_id
WHERE ep.ready_for_import = TRUE
  AND ep.composite_score >= 400
  AND ep.confidence_score >= 0.70
ORDER BY ep.composite_score DESC, ep.confidence_score DESC;

-- View 2: Enrichment queue status
CREATE OR REPLACE VIEW social_intelligence.v_enrichment_queue_status AS
SELECT 
    status,
    COUNT(*) as count,
    AVG(attempts) as avg_attempts,
    MIN(queued_at) as oldest_queued,
    MAX(queued_at) as newest_queued
FROM social_intelligence.enrichment_queue
GROUP BY status
ORDER BY 
    CASE status 
        WHEN 'processing' THEN 1 
        WHEN 'queued' THEN 2 
        WHEN 'failed' THEN 3 
        ELSE 4 
    END;

-- View 3: Daily discovery metrics
CREATE OR REPLACE VIEW social_intelligence.v_daily_metrics AS
SELECT 
    DATE(discovered_at) as discovery_date,
    COUNT(*) as total_discovered,
    COUNT(*) FILTER (WHERE enrichment_status = 'enriched') as enriched_count,
    COUNT(*) FILTER (WHERE imported_to_donors = TRUE) as imported_count,
    AVG(conservative_score) as avg_conservative_score,
    COUNT(*) FILTER (WHERE conservative_score >= 8.0) as high_conservative_count,
    COUNT(DISTINCT discovered_from_target_id) as targets_scraped
FROM social_intelligence.discovered_prospects
WHERE discovered_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(discovered_at)
ORDER BY discovery_date DESC;

-- View 4: Data source performance
CREATE OR REPLACE VIEW social_intelligence.v_source_performance AS
SELECT 
    ds.source_name,
    ds.source_type,
    ds.source_category,
    ds.enabled,
    ds.cost_per_lookup,
    ds.total_lookups,
    ds.successful_lookups,
    ds.success_rate,
    ds.avg_response_time_ms,
    ds.avg_confidence_score,
    ds.monthly_cost_current,
    ds.monthly_cost_cap,
    ds.last_used_at
FROM social_intelligence.data_sources ds
ORDER BY ds.source_type, ds.priority DESC;

-- =====================================================================
-- FUNCTIONS
-- =====================================================================

-- Function 1: Calculate prospect fingerprint for deduplication
CREATE OR REPLACE FUNCTION social_intelligence.calculate_fingerprint(
    p_platform VARCHAR,
    p_user_id VARCHAR,
    p_handle VARCHAR
) RETURNS VARCHAR(64) AS $$
BEGIN
    RETURN encode(
        sha256(
            (COALESCE(p_platform, '') || '|' || 
             COALESCE(p_user_id, '') || '|' || 
             LOWER(COALESCE(p_handle, '')))::bytea
        ),
        'hex'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function 2: Update target next_scrape_at based on frequency
CREATE OR REPLACE FUNCTION social_intelligence.update_next_scrape()
RETURNS TRIGGER AS $$
BEGIN
    NEW.next_scrape_at := CASE NEW.scrape_frequency
        WHEN 'hourly' THEN NOW() + INTERVAL '1 hour'
        WHEN 'daily' THEN NOW() + INTERVAL '1 day'
        WHEN 'weekly' THEN NOW() + INTERVAL '7 days'
        WHEN 'monthly' THEN NOW() + INTERVAL '30 days'
        ELSE NOW() + INTERVAL '1 day'
    END;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Auto-queue prospect for enrichment
CREATE OR REPLACE FUNCTION social_intelligence.auto_queue_enrichment()
RETURNS TRIGGER AS $$
BEGIN
    -- Only queue if conservative score meets threshold
    IF NEW.conservative_score >= 6.0 AND NEW.enrichment_status = 'pending' THEN
        INSERT INTO social_intelligence.enrichment_queue (
            prospect_id,
            priority,
            sources_to_query
        ) VALUES (
            NEW.prospect_id,
            CASE 
                WHEN NEW.conservative_score >= 9.0 THEN 10
                WHEN NEW.conservative_score >= 8.0 THEN 8
                WHEN NEW.conservative_score >= 7.0 THEN 6
                ELSE 5
            END,
            ARRAY['voter_file', 'fec', 'nc_sboe', 'property_gis', 'nc_sos_business']
        );
        
        -- Update status
        NEW.enrichment_status := 'queued';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- TRIGGERS
-- =====================================================================

-- Trigger 1: Update next_scrape_at after successful scrape
CREATE TRIGGER trg_update_next_scrape
    BEFORE UPDATE OF last_scraped_at ON social_intelligence.scraping_targets
    FOR EACH ROW
    WHEN (NEW.last_scraped_at IS DISTINCT FROM OLD.last_scraped_at)
    EXECUTE FUNCTION social_intelligence.update_next_scrape();

-- Trigger 2: Auto-queue prospects for enrichment
CREATE TRIGGER trg_auto_queue_enrichment
    BEFORE INSERT ON social_intelligence.discovered_prospects
    FOR EACH ROW
    EXECUTE FUNCTION social_intelligence.auto_queue_enrichment();

-- Trigger 3: Set fingerprint on insert
CREATE OR REPLACE FUNCTION social_intelligence.set_fingerprint()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fingerprint := social_intelligence.calculate_fingerprint(
        NEW.platform,
        NEW.social_user_id,
        NEW.social_handle
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_fingerprint
    BEFORE INSERT ON social_intelligence.discovered_prospects
    FOR EACH ROW
    EXECUTE FUNCTION social_intelligence.set_fingerprint();

-- =====================================================================
-- SEED DATA: FREE DATA SOURCES
-- =====================================================================

INSERT INTO social_intelligence.data_sources (
    source_name, source_type, source_category,
    api_url, auth_type, cost_per_lookup,
    priority, enabled, description
) VALUES
-- FREE Sources
(
    'data_trust_voter',
    'free',
    'voter',
    'https://datatrust.com/api/v1',
    'api_key',
    0.00,
    10,
    TRUE,
    'Data Trust voter file - FREE for campaigns via NCGOP partnership'
),
(
    'fec_donations',
    'free',
    'donation',
    'https://api.open.fec.gov/v1',
    'api_key',
    0.00,
    10,
    TRUE,
    'FEC federal donation records - FREE public API'
),
(
    'nc_sboe_donations',
    'free',
    'donation',
    'https://cf.ncsbe.gov/CFOrgLkup/',
    'none',
    0.00,
    10,
    TRUE,
    'NC State Board of Elections campaign finance - FREE public data'
),
(
    'county_gis_property',
    'free',
    'property',
    'https://services.wake.gov/realdata/api',
    'none',
    0.00,
    9,
    TRUE,
    'County GIS property records - FREE public data (varies by county)'
),
(
    'nc_sos_business',
    'free',
    'business',
    'https://www.sosnc.gov/online_services',
    'none',
    0.00,
    8,
    TRUE,
    'NC Secretary of State business records - FREE public search'
),

-- PREMIUM Sources (disabled by default)
(
    'apollo_contact',
    'premium',
    'contact',
    'https://api.apollo.io/v1',
    'api_key',
    0.01,
    5,
    FALSE,
    'Apollo.io contact enrichment - $0.01/lookup'
),
(
    'zoominfo_contact',
    'premium',
    'contact',
    'https://api.zoominfo.com/lookup',
    'api_key',
    0.05,
    4,
    FALSE,
    'ZoomInfo contact enrichment - $0.05/lookup'
),
(
    'neverbounce_email',
    'premium',
    'contact',
    'https://api.neverbounce.com/v4',
    'api_key',
    0.003,
    6,
    FALSE,
    'NeverBounce email verification - $0.003/verify'
),
(
    'melissa_address',
    'premium',
    'contact',
    'https://api.melissa.com/v3',
    'api_key',
    0.005,
    5,
    FALSE,
    'Melissa Data address verification - $0.005/verify'
),
(
    'bettercontact_phone',
    'premium',
    'contact',
    'https://api.bettercontact.io/v1',
    'api_key',
    0.02,
    5,
    FALSE,
    'BetterContact phone verification - $0.02/verify'
);

-- =====================================================================
-- SEED DATA: INITIAL SCRAPING TARGETS
-- =====================================================================

INSERT INTO social_intelligence.scraping_targets (
    platform, target_type, handle, target_name,
    scrape_frequency, scrape_type, max_results_per_scrape,
    min_conservative_score, priority, active
) VALUES
-- Twitter/X targets
(
    'twitter',
    'user',
    'NCGOP',
    'North Carolina Republican Party',
    'daily',
    'followers',
    1000,
    6.0,
    10,
    TRUE
),
(
    'twitter',
    'user',
    'NCHouseGOP',
    'NC House Republicans',
    'daily',
    'followers',
    1000,
    6.0,
    9,
    TRUE
),
(
    'twitter',
    'user',
    'NCSenateGOP',
    'NC Senate Republicans',
    'daily',
    'followers',
    1000,
    6.0,
    9,
    TRUE
),
(
    'twitter',
    'user',
    'NCRP',
    'NC Republican Party (alt)',
    'weekly',
    'followers',
    500,
    6.0,
    7,
    TRUE
);

-- =====================================================================
-- GRANTS (adjust for your Supabase roles)
-- =====================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA social_intelligence TO authenticated;
GRANT USAGE ON SCHEMA social_intelligence TO service_role;

-- Grant access to tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA social_intelligence TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA social_intelligence TO authenticated;

-- Grant access to sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA social_intelligence TO service_role;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
DECLARE
    table_count INTEGER;
    index_count INTEGER;
    source_count INTEGER;
    target_count INTEGER;
BEGIN
    -- Count tables
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables 
    WHERE table_schema = 'social_intelligence' 
    AND table_type = 'BASE TABLE';
    
    -- Count indexes
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE schemaname = 'social_intelligence';
    
    -- Count data sources
    SELECT COUNT(*) INTO source_count
    FROM social_intelligence.data_sources;
    
    -- Count scraping targets
    SELECT COUNT(*) INTO target_count
    FROM social_intelligence.scraping_targets;
    
    RAISE NOTICE '';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'ECOSYSTEM 44 DEPLOYMENT COMPLETE';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Schema: social_intelligence';
    RAISE NOTICE 'Tables created: %', table_count;
    RAISE NOTICE 'Indexes created: %', index_count;
    RAISE NOTICE 'FREE data sources configured: % (of %)', 
        (SELECT COUNT(*) FROM social_intelligence.data_sources WHERE source_type = 'free'),
        source_count;
    RAISE NOTICE 'Premium sources available: % (disabled)', 
        (SELECT COUNT(*) FROM social_intelligence.data_sources WHERE source_type = 'premium');
    RAISE NOTICE 'Scraping targets configured: %', target_count;
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Ready to scrape! Run ecosystem_44_scraper.py to start.';
    RAISE NOTICE '=====================================================';
END $$;

-- =====================================================================
-- END OF SCHEMA
-- =====================================================================
