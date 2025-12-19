-- ============================================================================
-- BROYHILLGOP DEPLOYMENT - CHUNK 1 of 3
-- Schema Setup + Donors Table
-- ============================================================================
-- 
-- INSTRUCTIONS:
-- 1. Copy this ENTIRE file
-- 2. Paste into Supabase SQL Editor
-- 3. Click "Run"
-- 4. Wait for success message
-- 5. Then move to CHUNK_2.sql
--
-- ============================================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create main schema
CREATE SCHEMA IF NOT EXISTS broyhillgop;
SET search_path TO broyhillgop, public;

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================

-- Donor grade enumeration (12 grades)
CREATE TYPE donor_grade AS ENUM (
    'A++', 'A+', 'A', 'A-',
    'B+', 'B', 'B-',
    'C+', 'C', 'C-',
    'D',
    'U'
);

-- Level preference
CREATE TYPE level_preference AS ENUM (
    'F',    -- Federal
    'S',    -- State
    'L',    -- Local
    'F/S',  -- Federal/State mix
    'S/L',  -- State/Local mix
    'F/L',  -- Federal/Local mix
    'MIX'   -- All levels
);

-- Campaign status
CREATE TYPE campaign_status AS ENUM (
    'DRAFT',
    'SCHEDULED',
    'ACTIVE',
    'PAUSED',
    'COMPLETED',
    'CANCELLED'
);

-- Communication channel
CREATE TYPE communication_channel AS ENUM (
    'EMAIL',
    'SMS',
    'PHONE',
    'MAIL',
    'IN_PERSON',
    'SOCIAL_MEDIA'
);

-- ============================================================================
-- TABLE: donors (MASTER TABLE)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donors (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donor_id VARCHAR(50) UNIQUE NOT NULL,
    
    -- Basic Information
    first_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(200) GENERATED ALWAYS AS (
        COALESCE(first_name || ' ', '') || last_name
    ) STORED,
    preferred_name VARCHAR(100),
    salutation VARCHAR(20),
    suffix VARCHAR(10),
    
    -- Contact Information
    email VARCHAR(255),
    phone VARCHAR(20),
    mobile VARCHAR(20),
    
    -- Address
    address VARCHAR(255),
    address_2 VARCHAR(255),
    city VARCHAR(100),
    county VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    zip VARCHAR(10),
    
    -- Demographics
    birth_year INTEGER,
    gender VARCHAR(20),
    occupation VARCHAR(100),
    employer VARCHAR(200),
    
    -- =================================================================
    -- 3D GRADING FIELDS
    -- =================================================================
    
    -- Core donation metrics
    total_donations DECIMAL(12,2) DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    first_donation DATE,
    last_donation DATE,
    
    -- DIMENSION 1: Amount Grading (State Level)
    amount_percentile_state DECIMAL(6,3),
    amount_grade_state donor_grade,
    
    -- Amount Grading (County Level)
    amount_percentile_county DECIMAL(6,3),
    amount_grade_county donor_grade,
    
    -- DIMENSION 2: Intensity Grading (1-10 scale)
    intensity_grade_2y INTEGER CHECK (intensity_grade_2y BETWEEN 1 AND 10),
    intensity_grade_5y INTEGER CHECK (intensity_grade_5y BETWEEN 1 AND 10),
    intensity_grade_all INTEGER CHECK (intensity_grade_all BETWEEN 1 AND 10),
    donations_per_month_2y DECIMAL(5,2),
    donations_per_month_5y DECIMAL(5,2),
    
    -- DIMENSION 3: Level Preference
    level_preference level_preference,
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
    
    -- =================================================================
    -- ML CLUSTERING
    -- =================================================================
    cluster_id INTEGER,
    cluster_name VARCHAR(100),
    cluster_description TEXT,
    
    -- =================================================================
    -- DONOR QUALITY METRICS
    -- =================================================================
    avg_donation DECIMAL(10,2),
    median_donation DECIMAL(10,2),
    max_donation DECIMAL(10,2),
    min_donation DECIMAL(10,2),
    
    days_since_last_donation INTEGER,
    lapsed_donor BOOLEAN DEFAULT FALSE,
    
    donor_probability DECIMAL(5,4),
    predicted_next_donation DECIMAL(10,2),
    
    -- =================================================================
    -- ENGAGEMENT TRACKING
    -- =================================================================
    volunteer BOOLEAN DEFAULT FALSE,
    event_attendee BOOLEAN DEFAULT FALSE,
    
    email_subscribed BOOLEAN DEFAULT TRUE,
    sms_subscribed BOOLEAN DEFAULT FALSE,
    do_not_contact BOOLEAN DEFAULT FALSE,
    
    -- =================================================================
    -- METADATA
    -- =================================================================
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_contacted DATE,
    contact_count INTEGER DEFAULT 0,
    
    notes TEXT,
    tags TEXT[],
    
    -- External system IDs
    external_id VARCHAR(100),
    ngp_van_id VARCHAR(50),
    salesforce_id VARCHAR(50)
);

-- ============================================================================
-- INDEXES FOR DONORS TABLE
-- ============================================================================

-- Primary lookup indexes
CREATE INDEX idx_donors_donor_id ON donors(donor_id);
CREATE INDEX idx_donors_email ON donors(email);
CREATE INDEX idx_donors_phone ON donors(phone);
CREATE INDEX idx_donors_full_name ON donors(full_name);

-- 3D Grading indexes
CREATE INDEX idx_donors_state_grade ON donors(amount_grade_state);
CREATE INDEX idx_donors_county_grade ON donors(amount_grade_county);
CREATE INDEX idx_donors_3d_grade ON donors(grade_3d);
CREATE INDEX idx_donors_level ON donors(level_preference);
CREATE INDEX idx_donors_intensity ON donors(intensity_grade_2y);

-- Geographic indexes
CREATE INDEX idx_donors_county_state ON donors(county, state);
CREATE INDEX idx_donors_zip ON donors(zip);
CREATE INDEX idx_donors_city ON donors(city);

-- Donation metrics indexes
CREATE INDEX idx_donors_total_donations ON donors(total_donations);
CREATE INDEX idx_donors_last_donation ON donors(last_donation);
CREATE INDEX idx_donors_lapsed ON donors(lapsed_donor);

-- ML clustering index
CREATE INDEX idx_donors_cluster ON donors(cluster_id);

-- Search optimization
CREATE INDEX idx_donors_name_trgm ON donors USING gin (full_name gin_trgm_ops);
CREATE INDEX idx_donors_email_trgm ON donors USING gin (email gin_trgm_ops);

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'CHUNK 1 of 3 COMPLETE!';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Created:';
    RAISE NOTICE '  - Schema: broyhillgop';
    RAISE NOTICE '  - Custom types: 4';
    RAISE NOTICE '  - Table: donors (80+ columns)';
    RAISE NOTICE '  - Indexes: 18';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run CHUNK_2.sql';
    RAISE NOTICE '============================================================';
END $$;
