-- =============================================================================
-- CANDIDATE PERSONALIZATION - EXTENDS EXISTING SCHEMAS
-- =============================================================================
--
-- CRITICAL: This file EXTENDS your existing schemas, does NOT create new ones!
--
-- Existing schemas we're working with:
-- 1. intelligence_brain.candidates (from Intelligence Brain Ecosystem 20)
-- 2. broyhillgop.candidate_news_routing_config (from News Monitor Ecosystem 42)
-- 3. broyhillgop.donors (from DataHub Ecosystem 0)
--
-- This file ONLY adds missing personalization fields to existing tables
--
-- =============================================================================

-- =============================================================================
-- EXTEND EXISTING intelligence_brain.candidates TABLE
-- =============================================================================

-- Add personalization fields to EXISTING table (if they don't exist)
DO $$
BEGIN
    -- Campaign/Contact Information
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='email') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN email TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='phone') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN phone TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='campaign_website') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN campaign_website TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='donation_url') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN donation_url TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='volunteer_url') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN volunteer_url TEXT;
    END IF;
    
    -- Biography fields
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='biography') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN biography TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='military_service') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN military_service TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='business_background') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN business_background TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='education') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN education TEXT[];
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='family') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN family TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='previous_offices') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN previous_offices TEXT[];
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='endorsements') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN endorsements TEXT[];
    END IF;
    
    -- Opponent information
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='opponent_name') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN opponent_name TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='opponent_party') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN opponent_party TEXT;
    END IF;
    
    -- Media assets
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='voice_sample_path') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN voice_sample_path TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='headshot_formal_path') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN headshot_formal_path TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='headshot_casual_path') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN headshot_casual_path TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='action_photos') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN action_photos TEXT[];
    END IF;
    
    -- Social media
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='social_media') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN social_media JSONB DEFAULT '{}';
    END IF;
    
    -- Messaging preferences
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='messaging_tone') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN messaging_tone TEXT DEFAULT 'balanced';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='voice_emotion_default') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN voice_emotion_default TEXT DEFAULT 'confident';
    END IF;
    
    -- User account link
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='user_id') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN user_id TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='last_login') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN last_login TIMESTAMP;
    END IF;
    
    -- Preferred name (if not exists)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='preferred_name') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN preferred_name TEXT;
    END IF;
    
    -- Party affiliation (if not exists)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='party') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN party TEXT;
    END IF;
    
    -- Incumbent status (if not exists)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='incumbent') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN incumbent BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- County (if not exists - for local races)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='county') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN county TEXT;
    END IF;
    
    -- Counties covered (for multi-county districts)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='counties_covered') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN counties_covered TEXT[];
    END IF;
    
    -- Cities covered
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema='intelligence_brain' 
                   AND table_name='candidates' 
                   AND column_name='cities_covered') THEN
        ALTER TABLE intelligence_brain.candidates ADD COLUMN cities_covered TEXT[];
    END IF;
END $$;

COMMENT ON TABLE intelligence_brain.candidates IS 'Extended with personalization fields for AI context injection';


-- =============================================================================
-- NEW TABLE: District Intelligence (this is truly new data)
-- =============================================================================

CREATE TABLE IF NOT EXISTS intelligence_brain.district_intelligence (
    district_id TEXT PRIMARY KEY,  -- e.g. "nc_house_72" or "us_house_13"
    office_type TEXT NOT NULL,
    
    -- Demographics
    total_population INTEGER,
    total_registered_voters INTEGER,
    party_registration JSONB,  -- {"R": 45000, "D": 38000, "U": 22000}
    age_breakdown JSONB,
    racial_breakdown JSONB,
    median_income INTEGER,
    urban_rural_split JSONB,
    
    -- Electoral History
    last_election_results JSONB,
    last_election_year INTEGER,
    voter_turnout_last_cycle NUMERIC(4,3),
    swing_precincts TEXT[],
    
    -- Key Issues
    top_local_issues JSONB DEFAULT '[]',
    
    -- Geographic
    counties TEXT[],
    cities TEXT[],
    major_employers TEXT[],
    
    -- Media
    local_newspapers JSONB DEFAULT '[]',
    local_tv_stations JSONB DEFAULT '[]',
    local_radio JSONB DEFAULT '[]',
    
    -- Political
    competitive_rating TEXT,
    cook_pvi TEXT,
    previous_rep TEXT,
    previous_rep_party TEXT,
    
    -- Metadata
    last_updated TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_district_office_type ON intelligence_brain.district_intelligence(office_type);


-- =============================================================================
-- NEW TABLE: Candidate AI Configurations (personalization state)
-- =============================================================================

CREATE TABLE IF NOT EXISTS intelligence_brain.candidate_ai_config (
    candidate_id UUID PRIMARY KEY REFERENCES intelligence_brain.candidates(candidate_id) ON DELETE CASCADE,
    
    -- AI Context (injected into every AI call)
    ai_context JSONB NOT NULL,
    
    -- Ecosystem Configurations
    ecosystem_configs JSONB DEFAULT '{}',
    
    -- Enabled Ecosystems
    enabled_ecosystems INTEGER[],
    
    -- Configuration metadata
    configured_at TIMESTAMP DEFAULT NOW(),
    configuration_version TEXT DEFAULT '1.0',
    
    -- Usage tracking
    last_content_generated TIMESTAMP,
    total_content_generated INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE intelligence_brain.candidate_ai_config IS 'Auto-generated AI personalization configuration per candidate';


-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Function to get complete candidate profile for AI context
CREATE OR REPLACE FUNCTION get_candidate_ai_context(p_candidate_id UUID)
RETURNS JSONB AS $$
DECLARE
    context JSONB;
BEGIN
    SELECT jsonb_build_object(
        'candidate_name', preferred_name || ' ' || last_name,
        'candidate_full_name', first_name || ' ' || last_name,
        'candidate_party', party,
        'office_formal', office_type,
        'office_district_full', office_type || ' District ' || district_id,
        'incumbent_status', CASE WHEN incumbent THEN 'incumbent' ELSE 'challenger' END,
        'primary_geography', county,
        'all_counties', COALESCE(array_to_string(counties_covered, ', '), county),
        'all_cities', array_to_string(cities_covered, ', '),
        'opponent_name', COALESCE(opponent_name, 'my opponent'),
        'opponent_party', COALESCE(opponent_party, 'Democrat'),
        'biography_summary', LEFT(biography, 200),
        'military_service', COALESCE(military_service, 'N/A'),
        'business_background', COALESCE(business_background, 'N/A'),
        'family', family,
        'donation_url', donation_url,
        'volunteer_url', volunteer_url,
        'website_url', campaign_website,
        'tone_preference', messaging_tone,
        'voice_emotion', voice_emotion_default,
        'issue_1', campaign_priorities->0,
        'issue_2', campaign_priorities->1,
        'issue_3', campaign_priorities->2
    ) INTO context
    FROM intelligence_brain.candidates
    WHERE candidate_id = p_candidate_id;
    
    RETURN context;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_candidate_ai_context IS 'Generate AI context injection for candidate - used by personalization system';


-- Function to update AI config on candidate update
CREATE OR REPLACE FUNCTION update_candidate_ai_config()
RETURNS TRIGGER AS $$
BEGIN
    -- Regenerate AI context when candidate details change
    INSERT INTO intelligence_brain.candidate_ai_config (candidate_id, ai_context)
    VALUES (NEW.candidate_id, get_candidate_ai_context(NEW.candidate_id))
    ON CONFLICT (candidate_id) DO UPDATE
    SET ai_context = get_candidate_ai_context(NEW.candidate_id),
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update AI config
DROP TRIGGER IF EXISTS trigger_update_ai_config ON intelligence_brain.candidates;
CREATE TRIGGER trigger_update_ai_config
    AFTER INSERT OR UPDATE ON intelligence_brain.candidates
    FOR EACH ROW
    EXECUTE FUNCTION update_candidate_ai_config();


-- =============================================================================
-- SAMPLE DATA UPDATE (extends existing John Smith if he exists)
-- =============================================================================

-- Update existing candidate with personalization data (if exists)
DO $$
BEGIN
    -- Check if we have any candidates to update
    IF EXISTS (SELECT 1 FROM intelligence_brain.candidates LIMIT 1) THEN
        -- Just add sample district intelligence
        INSERT INTO intelligence_brain.district_intelligence (
            district_id, office_type, total_population, total_registered_voters,
            party_registration, median_income, counties, cities, competitive_rating
        ) VALUES (
            'nc_house_72', 'NC_HOUSE', 94500, 68000,
            '{"R": 32000, "D": 28000, "U": 8000}'::jsonb,
            65000,
            ARRAY['Forsyth', 'Stokes'],
            ARRAY['Winston-Salem', 'Kernersville'],
            'Lean R'
        ) ON CONFLICT (district_id) DO NOTHING;
    END IF;
END $$;


-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Check what fields exist in candidates table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'intelligence_brain' 
AND table_name = 'candidates'
ORDER BY ordinal_position;

-- Check if AI config table exists
SELECT COUNT(*) as ai_config_count 
FROM intelligence_brain.candidate_ai_config;

-- Check if district intelligence exists
SELECT COUNT(*) as district_count 
FROM intelligence_brain.district_intelligence;
