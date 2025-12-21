-- ============================================================================
-- BROYHILLGOP PERSONS TABLE SCHEMA
-- DUAL GRADING: State Grade + County Grade
-- December 2024
-- ============================================================================

-- Drop existing if needed (comment out for production)
-- DROP TABLE IF EXISTS donation_transactions CASCADE;
-- DROP TABLE IF EXISTS persons CASCADE;

-- ============================================================================
-- TABLE: PERSONS (Master Contact Table)
-- ============================================================================

CREATE TABLE IF NOT EXISTS persons (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id VARCHAR(20) UNIQUE,
    
    -- MATCH KEYS (Deduplication)
    match_key VARCHAR(255),
    match_type VARCHAR(20),
    
    -- IDENTITY
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(255),
    prefix VARCHAR(20),
    suffix VARCHAR(20),
    preferred_name VARCHAR(100),
    
    -- CONTACT
    email VARCHAR(255),
    phone VARCHAR(20),
    home_phone VARCHAR(20),
    mobile_phone VARCHAR(20),
    
    -- ADDRESS
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2) DEFAULT 'NC',
    zip_code VARCHAR(10),
    county VARCHAR(100),
    
    -- EMPLOYMENT
    employer VARCHAR(255),
    occupation VARCHAR(255),
    apollo_title VARCHAR(255),
    apollo_company VARCHAR(255),
    apollo_linkedin VARCHAR(500),
    
    -- FLAGS
    is_donor BOOLEAN DEFAULT FALSE,
    is_volunteer BOOLEAN DEFAULT FALSE,
    is_delegate BOOLEAN DEFAULT FALSE,
    is_ncgop_donor BOOLEAN DEFAULT FALSE,
    is_military BOOLEAN DEFAULT FALSE,
    is_apollo_enriched BOOLEAN DEFAULT FALSE,
    
    -- =========================================================================
    -- DUAL GRADING SYSTEM
    -- =========================================================================
    
    -- STATE LEVEL (Rank 1 = A++ statewide)
    donor_grade_state VARCHAR(5),
    donor_rank_state INTEGER,
    donor_percentile_state DECIMAL(6,3),
    
    -- COUNTY LEVEL (Rank 1 = A++ in county)
    donor_grade_county VARCHAR(5),
    donor_rank_county INTEGER,
    donor_percentile_county DECIMAL(6,3),
    
    -- INTENSITY (1-10)
    intensity_score INTEGER,
    
    -- LEVEL PREFERENCE (F/S/L)
    level_preference VARCHAR(5),
    
    -- COMPOSITE
    composite_grade VARCHAR(20),
    composite_score DECIMAL(5,2),
    
    -- =========================================================================
    -- DONATION SUMMARY
    -- =========================================================================
    donation_total DECIMAL(12,2) DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    first_donation_date DATE,
    last_donation_date DATE,
    largest_donation DECIMAL(12,2),
    average_donation DECIMAL(12,2),
    donation_rank INTEGER,
    
    -- NCGOP
    ncgop_donor_id VARCHAR(50),
    delegate_id VARCHAR(50),
    delegate_status VARCHAR(50),
    
    -- SPOUSE/HOUSEHOLD
    spouse_id UUID REFERENCES persons(id),
    household_id VARCHAR(50),
    
    -- TAGS
    tags TEXT[],
    source VARCHAR(100),
    
    -- =========================================================================
    -- DATATRUST FIELDS (Future)
    -- =========================================================================
    datatrust_id VARCHAR(50),
    voter_id VARCHAR(50),
    voter_status VARCHAR(20),
    party_registration VARCHAR(20),
    
    -- MERGE TRACKING
    is_merged BOOLEAN DEFAULT FALSE,
    records_merged INTEGER DEFAULT 0,
    source_systems JSONB,
    
    -- TIMESTAMPS
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_enriched_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- TABLE: DONATION_TRANSACTIONS (Future - 10 years quarterly from DataTrust)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donation_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE,
    person_match_key VARCHAR(255),
    
    transaction_id VARCHAR(50) UNIQUE,
    amount DECIMAL(12,2) NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_quarter VARCHAR(10),
    transaction_year INTEGER,
    
    recipient_type VARCHAR(50),
    recipient_name VARCHAR(255),
    office_level VARCHAR(20),
    
    data_source VARCHAR(50),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR DUAL GRADING QUERIES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_persons_match_key ON persons(match_key);
CREATE INDEX IF NOT EXISTS idx_persons_email ON persons(email);
CREATE INDEX IF NOT EXISTS idx_persons_county ON persons(county);
CREATE INDEX IF NOT EXISTS idx_persons_grade_state ON persons(donor_grade_state);
CREATE INDEX IF NOT EXISTS idx_persons_grade_county ON persons(donor_grade_county);
CREATE INDEX IF NOT EXISTS idx_persons_rank_state ON persons(donor_rank_state);
CREATE INDEX IF NOT EXISTS idx_persons_rank_county ON persons(donor_rank_county);
CREATE INDEX IF NOT EXISTS idx_persons_donation_total ON persons(donation_total DESC);
CREATE INDEX IF NOT EXISTS idx_persons_is_donor ON persons(is_donor);
CREATE INDEX IF NOT EXISTS idx_persons_county_grade ON persons(county, donor_grade_county);
CREATE INDEX IF NOT EXISTS idx_persons_county_rank ON persons(county, donor_rank_county);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS persons_updated ON persons;
CREATE TRIGGER persons_updated
    BEFORE UPDATE ON persons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- VIEWS FOR ECOSYSTEM QUERIES
-- ============================================================================

-- State Leaderboard (Top donors statewide)
CREATE OR REPLACE VIEW v_donor_leaderboard_state AS
SELECT person_id, full_name, city, county, donation_total,
       donor_grade_state, donor_rank_state, 
       donor_grade_county, donor_rank_county,
       employer, occupation
FROM persons WHERE is_donor = TRUE
ORDER BY donor_rank_state ASC;

-- County Leaderboard (Top donors per county)
CREATE OR REPLACE VIEW v_donor_leaderboard_by_county AS
SELECT county, person_id, full_name, donation_total,
       donor_grade_state, donor_grade_county, donor_rank_county
FROM persons WHERE is_donor = TRUE
ORDER BY county, donor_rank_county ASC;

-- County Summary Stats
CREATE OR REPLACE VIEW v_county_summary AS
SELECT county,
       COUNT(*) as donor_count,
       SUM(donation_total) as total_donations,
       AVG(donation_total) as avg_donation,
       COUNT(*) FILTER (WHERE donor_grade_county IN ('A++', 'A+', 'A')) as a_grade_count,
       COUNT(*) FILTER (WHERE donor_grade_county IN ('A-', 'B+', 'B')) as b_grade_count
FROM persons WHERE is_donor = TRUE AND county IS NOT NULL
GROUP BY county ORDER BY total_donations DESC;

-- Grade Distribution (for analytics dashboard)
CREATE OR REPLACE VIEW v_grade_distribution AS
SELECT 
    donor_grade_state as grade,
    COUNT(*) as count,
    SUM(donation_total) as total_donations,
    AVG(donation_total) as avg_donation
FROM persons WHERE is_donor = TRUE
GROUP BY donor_grade_state
ORDER BY 
    CASE donor_grade_state
        WHEN 'A++' THEN 1 WHEN 'A+' THEN 2 WHEN 'A' THEN 3 WHEN 'A-' THEN 4
        WHEN 'B+' THEN 5 WHEN 'B' THEN 6 WHEN 'B-' THEN 7
        WHEN 'C+' THEN 8 WHEN 'C' THEN 9 WHEN 'C-' THEN 10
        WHEN 'D' THEN 11 WHEN 'U' THEN 12
        ELSE 99
    END;

-- ============================================================================
-- FUNCTIONS FOR ECOSYSTEM USE
-- ============================================================================

-- Get top N donors for a specific county
CREATE OR REPLACE FUNCTION get_county_top_donors(
    p_county VARCHAR,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    person_id VARCHAR,
    full_name VARCHAR,
    donation_total DECIMAL,
    donor_grade_county VARCHAR,
    donor_rank_county INTEGER,
    email VARCHAR,
    phone VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.person_id, p.full_name, p.donation_total,
           p.donor_grade_county, p.donor_rank_county,
           p.email, p.phone
    FROM persons p
    WHERE p.county = p_county AND p.is_donor = TRUE
    ORDER BY p.donor_rank_county ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Get donors by grade (state or county)
CREATE OR REPLACE FUNCTION get_donors_by_grade(
    p_grade VARCHAR,
    p_grade_type VARCHAR DEFAULT 'state', -- 'state' or 'county'
    p_county VARCHAR DEFAULT NULL,
    p_limit INTEGER DEFAULT 1000
)
RETURNS TABLE (
    person_id VARCHAR,
    full_name VARCHAR,
    county VARCHAR,
    donation_total DECIMAL,
    donor_grade_state VARCHAR,
    donor_grade_county VARCHAR,
    email VARCHAR
) AS $$
BEGIN
    IF p_grade_type = 'county' THEN
        RETURN QUERY
        SELECT p.person_id, p.full_name, p.county, p.donation_total,
               p.donor_grade_state, p.donor_grade_county, p.email
        FROM persons p
        WHERE p.donor_grade_county = p_grade 
          AND p.is_donor = TRUE
          AND (p_county IS NULL OR p.county = p_county)
        ORDER BY p.donation_total DESC
        LIMIT p_limit;
    ELSE
        RETURN QUERY
        SELECT p.person_id, p.full_name, p.county, p.donation_total,
               p.donor_grade_state, p.donor_grade_county, p.email
        FROM persons p
        WHERE p.donor_grade_state = p_grade AND p.is_donor = TRUE
        ORDER BY p.donation_total DESC
        LIMIT p_limit;
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT 'Dual Grading Schema created successfully!' as status;
