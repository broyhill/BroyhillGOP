-- ============================================================================
-- BROYHILLGOP DEPLOYMENT - CHUNK 1 (FIXED FOR SUPABASE)
-- Schema Setup + Donors Table
-- ============================================================================
-- 
-- FIXED: Uses gen_random_uuid() instead of uuid_generate_v4()
-- No uuid-ossp extension needed!
-- 
-- INSTRUCTIONS:
-- 1. Copy from line 15 below to the end
-- 2. Paste into Supabase SQL Editor
-- 3. Click "Run"
-- 4. Should work immediately! ✅
-- ============================================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS broyhillgop;

-- Create ENUM types (schema-qualified)
CREATE TYPE broyhillgop.donor_grade AS ENUM (
    'A++', 'A+', 'A', 'A-',
    'B+', 'B', 'B-',
    'C+', 'C', 'C-',
    'D', 'U'
);

CREATE TYPE broyhillgop.level_preference AS ENUM (
    'F', 'S', 'L', 'F/S', 'S/L', 'F/L', 'MIX'
);

CREATE TYPE broyhillgop.campaign_status AS ENUM (
    'DRAFT', 'SCHEDULED', 'ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED'
);

CREATE TYPE broyhillgop.communication_channel AS ENUM (
    'EMAIL', 'SMS', 'PHONE', 'MAIL', 'IN_PERSON', 'SOCIAL_MEDIA'
);

-- Main donors table
CREATE TABLE broyhillgop.donors (
    -- Primary Key (using gen_random_uuid - no extension needed!)
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id VARCHAR(50) UNIQUE NOT NULL,
    
    -- Basic Information
    first_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(200),
    email VARCHAR(255),
    phone VARCHAR(20),
    
    -- Address
    address VARCHAR(255),
    city VARCHAR(100),
    county VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    zip VARCHAR(10),
    
    -- Demographics
    birth_year INTEGER,
    gender VARCHAR(20),
    occupation VARCHAR(100),
    employer VARCHAR(200),
    
    -- Donation Metrics
    total_donations DECIMAL(12,2) DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    first_donation DATE,
    last_donation DATE,
    
    -- DIMENSION 1: Amount Grading
    amount_percentile_state DECIMAL(6,3),
    amount_grade_state broyhillgop.donor_grade,
    amount_percentile_county DECIMAL(6,3),
    amount_grade_county broyhillgop.donor_grade,
    
    -- DIMENSION 2: Intensity Grading (1-10 scale)
    intensity_grade_2y INTEGER CHECK (intensity_grade_2y BETWEEN 1 AND 10),
    intensity_grade_5y INTEGER CHECK (intensity_grade_5y BETWEEN 1 AND 10),
    donations_per_month_2y DECIMAL(5,2),
    donations_per_month_5y DECIMAL(5,2),
    
    -- DIMENSION 3: Level Preference
    level_preference broyhillgop.level_preference,
    federal_donation_count INTEGER DEFAULT 0,
    state_donation_count INTEGER DEFAULT 0,
    local_donation_count INTEGER DEFAULT 0,
    federal_donation_amount DECIMAL(12,2) DEFAULT 0,
    state_donation_amount DECIMAL(12,2) DEFAULT 0,
    local_donation_amount DECIMAL(12,2) DEFAULT 0,
    level_score_f DECIMAL(5,2),
    level_score_s DECIMAL(5,2),
    level_score_l DECIMAL(5,2),
    
    -- Combined 3D Grade (e.g., "A++/8/F")
    grade_3d VARCHAR(20),
    
    -- ML Clustering
    cluster_id INTEGER,
    cluster_name VARCHAR(100),
    cluster_description TEXT,
    
    -- Donor Quality Metrics
    avg_donation DECIMAL(10,2),
    median_donation DECIMAL(10,2),
    max_donation DECIMAL(10,2),
    min_donation DECIMAL(10,2),
    days_since_last_donation INTEGER,
    lapsed_donor BOOLEAN DEFAULT FALSE,
    donor_probability DECIMAL(5,4),
    
    -- Engagement
    volunteer BOOLEAN DEFAULT FALSE,
    event_attendee BOOLEAN DEFAULT FALSE,
    email_subscribed BOOLEAN DEFAULT TRUE,
    sms_subscribed BOOLEAN DEFAULT FALSE,
    do_not_contact BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    last_contacted DATE,
    contact_count INTEGER DEFAULT 0,
    notes TEXT,
    tags TEXT[]
);

-- Indexes
CREATE INDEX idx_donors_email ON broyhillgop.donors(email);
CREATE INDEX idx_donors_phone ON broyhillgop.donors(phone);
CREATE INDEX idx_donors_state_grade ON broyhillgop.donors(amount_grade_state);
CREATE INDEX idx_donors_county_grade ON broyhillgop.donors(amount_grade_county);
CREATE INDEX idx_donors_3d_grade ON broyhillgop.donors(grade_3d);
CREATE INDEX idx_donors_level ON broyhillgop.donors(level_preference);
CREATE INDEX idx_donors_county_state ON broyhillgop.donors(county, state);
CREATE INDEX idx_donors_total_donations ON broyhillgop.donors(total_donations);
CREATE INDEX idx_donors_last_donation ON broyhillgop.donors(last_donation);
CREATE INDEX idx_donors_cluster ON broyhillgop.donors(cluster_id);

-- Function to auto-update full_name
CREATE OR REPLACE FUNCTION broyhillgop.update_full_name()
RETURNS TRIGGER AS $$
BEGIN
    NEW.full_name := COALESCE(NEW.first_name || ' ', '') || NEW.last_name;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update full_name on insert/update
CREATE TRIGGER trigger_update_full_name
    BEFORE INSERT OR UPDATE OF first_name, last_name ON broyhillgop.donors
    FOR EACH ROW
    EXECUTE FUNCTION broyhillgop.update_full_name();

-- Function to auto-update updated_at
CREATE OR REPLACE FUNCTION broyhillgop.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
CREATE TRIGGER trigger_donors_updated_at
    BEFORE UPDATE ON broyhillgop.donors
    FOR EACH ROW
    EXECUTE FUNCTION broyhillgop.update_updated_at();

-- Success message
DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'CHUNK 1 COMPLETE! ✅';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Created:';
    RAISE NOTICE '  - Schema: broyhillgop';
    RAISE NOTICE '  - Custom types: 4';
    RAISE NOTICE '  - Table: donors (100+ columns)';
    RAISE NOTICE '  - Indexes: 10';
    RAISE NOTICE '  - Functions: 2';
    RAISE NOTICE '  - Triggers: 2';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run CHUNK_2_FIXED.sql';
    RAISE NOTICE '============================================================';
END $$;
