-- ============================================================================
-- BROYHILLGOP MASTER DONOR TABLE SCHEMA
-- Complete Supabase/PostgreSQL Schema for 112,609 Donors
-- ============================================================================
-- Created: December 1, 2024
-- Source: BroyhillGOP_Donors_MASTER_Merged_Deduplicated.csv
-- Records: 112,609 unique donors
-- Columns: 49 comprehensive fields
-- ============================================================================

-- Drop existing table if needed (BACKUP FIRST!)
-- DROP TABLE IF EXISTS donors CASCADE;

CREATE TABLE IF NOT EXISTS donors (
    -- ========================================================================
    -- PRIMARY KEY
    -- ========================================================================
    id BIGSERIAL PRIMARY KEY,
    donor_id VARCHAR(50) UNIQUE NOT NULL,  -- DONOR_ED_BROYHILL, DONOR_000001, etc.
    
    -- ========================================================================
    -- IDENTITY FIELDS (8 columns)
    -- ========================================================================
    full_name VARCHAR(255) NOT NULL,
    first_name_clean VARCHAR(100),
    middle_name_clean VARCHAR(100),
    last_name_clean VARCHAR(100) NOT NULL,
    suffix_clean VARCHAR(20),
    preferred_name VARCHAR(100),
    salutation VARCHAR(50),  -- Mr., Mrs., Ms., Dr., Senator, Judge, etc.
    
    -- ========================================================================
    -- RATINGS & RANKINGS (4 columns) - STATE AND COUNTY
    -- ========================================================================
    grade_state VARCHAR(10),  -- A++, A+, A, A-, B+, B, B-, C+, C, C-, D, U
    grade_county VARCHAR(10),
    donation_rank INTEGER,  -- Statewide rank (1 = highest)
    donation_rank_county INTEGER,  -- County rank
    
    -- ========================================================================
    -- ADDRESS FIELDS (6 columns)
    -- ========================================================================
    street_line_1 VARCHAR(255),
    street_line_2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),  -- NC
    zip_code VARCHAR(10),
    county VARCHAR(100),
    
    -- ========================================================================
    -- SPOUSE INFORMATION (8 columns)
    -- ========================================================================
    spouse_full_name VARCHAR(255),
    spouse_first_name VARCHAR(100),
    spouse_middle_name VARCHAR(100),
    spouse_last_name VARCHAR(100),
    spouse_suffix VARCHAR(20),
    spouse_preferred_name VARCHAR(100),
    spouse_salutation VARCHAR(50),
    spouse_donor_id VARCHAR(50),  -- References another donor record
    
    -- ========================================================================
    -- CONTACT INFORMATION (10 columns)
    -- ========================================================================
    home_phone VARCHAR(50),
    home_phone_source VARCHAR(50),
    mobile_phone VARCHAR(50),
    mobile_phone_source VARCHAR(50),
    other_phone VARCHAR(50),
    other_phone_source VARCHAR(50),
    email VARCHAR(255),
    email_source VARCHAR(50),
    home_phone_formatted VARCHAR(20),
    mobile_phone_formatted VARCHAR(20),
    other_phone_formatted VARCHAR(20),
    
    -- ========================================================================
    -- DONATION FIELDS (4 columns)
    -- ========================================================================
    donations_total NUMERIC(12, 2),  -- Original from file
    total_donations_aggregated NUMERIC(12, 2),  -- Sum of duplicates
    last_donation_date VARCHAR(20),  -- Store as text, convert as needed
    donation_count INTEGER DEFAULT 1,
    
    -- ========================================================================
    -- PROFESSIONAL FIELDS (2 columns)
    -- ========================================================================
    employer VARCHAR(255),
    occupation VARCHAR(255),
    
    -- ========================================================================
    -- METADATA FIELDS (7 columns)
    -- ========================================================================
    analysis_year_range VARCHAR(20),  -- 2020-2025
    merged_record_count INTEGER DEFAULT 1,
    original_indices TEXT,  -- Comma-separated list
    normalized_address TEXT,
    normalized_name TEXT,
    row_index INTEGER,
    
    -- ========================================================================
    -- SYSTEM FIELDS
    -- ========================================================================
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    data_quality_score INTEGER,  -- 0-100, calculated based on completeness
    
    -- ========================================================================
    -- CONSTRAINTS
    -- ========================================================================
    CONSTRAINT chk_grade_state CHECK (
        grade_state IN ('A++', 'A+', 'A', 'A-', 'B+', 'B', 'B-', 
                        'C+', 'C', 'C-', 'D', 'U')
    ),
    CONSTRAINT chk_grade_county CHECK (
        grade_county IN ('A++', 'A+', 'A', 'A-', 'B+', 'B', 'B-', 
                         'C+', 'C', 'C-', 'D', 'U')
    ),
    CONSTRAINT chk_state CHECK (state = 'NC'),  -- North Carolina only
    CONSTRAINT chk_email_format CHECK (
        email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    )
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Primary lookup indexes
CREATE INDEX idx_donors_donor_id ON donors(donor_id);
CREATE INDEX idx_donors_last_name ON donors(last_name_clean);
CREATE INDEX idx_donors_email ON donors(email) WHERE email IS NOT NULL;

-- Grade and ranking indexes (CRITICAL for grade-driven operations)
CREATE INDEX idx_donors_grade_state ON donors(grade_state);
CREATE INDEX idx_donors_grade_county ON donors(grade_county);
CREATE INDEX idx_donors_donation_rank ON donors(donation_rank);
CREATE INDEX idx_donors_donation_rank_county ON donors(donation_rank_county);

-- Composite index for grade-driven queries
CREATE INDEX idx_donors_grade_donations ON donors(
    grade_state, 
    total_donations_aggregated DESC
);

-- Geographic indexes
CREATE INDEX idx_donors_county ON donors(county);
CREATE INDEX idx_donors_city ON donors(city);
CREATE INDEX idx_donors_zip ON donors(zip_code);

-- Spouse relationship index
CREATE INDEX idx_donors_spouse_id ON donors(spouse_donor_id) 
    WHERE spouse_donor_id IS NOT NULL;

-- Contact information indexes
CREATE INDEX idx_donors_mobile ON donors(mobile_phone) 
    WHERE mobile_phone IS NOT NULL;
CREATE INDEX idx_donors_has_email ON donors(email) 
    WHERE email IS NOT NULL AND email != '';

-- Full text search index on names
CREATE INDEX idx_donors_fulltext_name ON donors 
    USING GIN(to_tsvector('english', 
        COALESCE(full_name, '') || ' ' || 
        COALESCE(first_name_clean, '') || ' ' || 
        COALESCE(last_name_clean, '')
    ));

-- ============================================================================
-- FOREIGN KEY CONSTRAINTS
-- ============================================================================

-- Spouse relationship (self-referencing)
ALTER TABLE donors 
ADD CONSTRAINT fk_donors_spouse 
FOREIGN KEY (spouse_donor_id) 
REFERENCES donors(donor_id) 
ON DELETE SET NULL;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_donors_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_donors_updated_at
    BEFORE UPDATE ON donors
    FOR EACH ROW
    EXECUTE FUNCTION update_donors_updated_at();

-- Calculate data quality score
CREATE OR REPLACE FUNCTION calculate_donor_quality_score()
RETURNS TRIGGER AS $$
DECLARE
    score INTEGER := 0;
BEGIN
    -- Basic info (20 points)
    IF NEW.full_name IS NOT NULL THEN score := score + 5; END IF;
    IF NEW.last_name_clean IS NOT NULL THEN score := score + 5; END IF;
    IF NEW.preferred_name IS NOT NULL THEN score := score + 5; END IF;
    IF NEW.salutation IS NOT NULL THEN score := score + 5; END IF;
    
    -- Address (20 points)
    IF NEW.street_line_1 IS NOT NULL THEN score := score + 5; END IF;
    IF NEW.city IS NOT NULL THEN score := score + 5; END IF;
    IF NEW.state IS NOT NULL THEN score := score + 5; END IF;
    IF NEW.zip_code IS NOT NULL THEN score := score + 5; END IF;
    
    -- Contact (30 points)
    IF NEW.email IS NOT NULL AND NEW.email != '' THEN score := score + 15; END IF;
    IF NEW.mobile_phone IS NOT NULL THEN score := score + 10; END IF;
    IF NEW.home_phone IS NOT NULL THEN score := score + 5; END IF;
    
    -- Ratings (20 points)
    IF NEW.grade_state IS NOT NULL THEN score := score + 10; END IF;
    IF NEW.donation_rank IS NOT NULL THEN score := score + 10; END IF;
    
    -- Professional (10 points)
    IF NEW.employer IS NOT NULL THEN score := score + 5; END IF;
    IF NEW.occupation IS NOT NULL THEN score := score + 5; END IF;
    
    NEW.data_quality_score := score;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_donors_quality_score
    BEFORE INSERT OR UPDATE ON donors
    FOR EACH ROW
    EXECUTE FUNCTION calculate_donor_quality_score();

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: A-tier donors only
CREATE OR REPLACE VIEW v_donors_a_tier AS
SELECT *
FROM donors
WHERE grade_state LIKE 'A%'
ORDER BY total_donations_aggregated DESC;

-- View: Spouse households (both donors)
CREATE OR REPLACE VIEW v_donor_households AS
SELECT 
    d1.donor_id as donor1_id,
    d1.full_name as donor1_name,
    d1.grade_state as donor1_grade,
    d1.total_donations_aggregated as donor1_donations,
    d2.donor_id as donor2_id,
    d2.full_name as donor2_name,
    d2.grade_state as donor2_grade,
    d2.total_donations_aggregated as donor2_donations,
    (d1.total_donations_aggregated + d2.total_donations_aggregated) as household_total,
    d1.street_line_1,
    d1.city,
    d1.state,
    d1.zip_code
FROM donors d1
INNER JOIN donors d2 ON d1.spouse_donor_id = d2.donor_id
WHERE d1.id < d2.id  -- Avoid duplicates
ORDER BY household_total DESC;

-- View: County leaders (high county rank, lower state rank)
CREATE OR REPLACE VIEW v_county_leaders AS
SELECT 
    donor_id,
    full_name,
    preferred_name,
    grade_state,
    grade_county,
    donation_rank,
    donation_rank_county,
    county,
    total_donations_aggregated,
    (donation_rank - donation_rank_county) as rank_difference
FROM donors
WHERE 
    donation_rank_county <= 10  -- Top 10 in county
    AND donation_rank > 50  -- Not top 50 statewide
    AND grade_county LIKE 'A%'
ORDER BY county, donation_rank_county;

-- View: Missing critical contact info
CREATE OR REPLACE VIEW v_donors_missing_contact AS
SELECT 
    donor_id,
    full_name,
    grade_state,
    total_donations_aggregated,
    CASE 
        WHEN email IS NULL OR email = '' THEN 'Missing Email'
        ELSE NULL
    END as missing_email,
    CASE 
        WHEN mobile_phone IS NULL THEN 'Missing Mobile'
        ELSE NULL
    END as missing_mobile
FROM donors
WHERE 
    (email IS NULL OR email = '')
    OR mobile_phone IS NULL
ORDER BY 
    CASE grade_state
        WHEN 'A++' THEN 1
        WHEN 'A+' THEN 2
        WHEN 'A' THEN 3
        WHEN 'A-' THEN 4
        ELSE 5
    END,
    total_donations_aggregated DESC;

-- ============================================================================
-- GRADE ENFORCEMENT FUNCTIONS (FROM YOUR EXISTING SYSTEM)
-- ============================================================================

-- Get donors by minimum grade
CREATE OR REPLACE FUNCTION get_donors_by_grade(
    min_grade_numeric INTEGER,
    result_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    donor_id VARCHAR,
    full_name VARCHAR,
    preferred_name VARCHAR,
    grade_state VARCHAR,
    total_donations_aggregated NUMERIC,
    email VARCHAR,
    mobile_phone VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.donor_id,
        d.full_name,
        d.preferred_name,
        d.grade_state,
        d.total_donations_aggregated,
        d.email,
        d.mobile_phone_formatted as mobile_phone
    FROM donors d
    WHERE 
        CASE d.grade_state
            WHEN 'A++' THEN 13
            WHEN 'A+' THEN 12
            WHEN 'A' THEN 11
            WHEN 'A-' THEN 10
            WHEN 'B+' THEN 9
            WHEN 'B' THEN 8
            WHEN 'B-' THEN 7
            WHEN 'C+' THEN 6
            WHEN 'C' THEN 5
            WHEN 'C-' THEN 4
            WHEN 'D' THEN 3
            WHEN 'U' THEN 2
            ELSE 1
        END >= min_grade_numeric
    ORDER BY 
        CASE d.grade_state
            WHEN 'A++' THEN 1
            WHEN 'A+' THEN 2
            WHEN 'A' THEN 3
            WHEN 'A-' THEN 4
            WHEN 'B+' THEN 5
            WHEN 'B' THEN 6
            WHEN 'B-' THEN 7
            WHEN 'C+' THEN 8
            WHEN 'C' THEN 9
            WHEN 'C-' THEN 10
            WHEN 'D' THEN 11
            WHEN 'U' THEN 12
        END,
        d.total_donations_aggregated DESC
    LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;

-- Calculate campaign budget by grade distribution
CREATE OR REPLACE FUNCTION calculate_campaign_budget(
    target_grade_min VARCHAR DEFAULT 'B+',
    target_grade_max VARCHAR DEFAULT 'A++'
)
RETURNS TABLE (
    grade VARCHAR,
    donor_count BIGINT,
    cost_per_contact NUMERIC,
    total_budget NUMERIC,
    expected_response_rate NUMERIC,
    estimated_revenue NUMERIC,
    estimated_roi NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH grade_costs AS (
        SELECT * FROM (VALUES
            ('A++', 50.00, 0.40),
            ('A+',  35.00, 0.38),
            ('A',   25.00, 0.35),
            ('A-',  15.00, 0.30),
            ('B+',  10.00, 0.28),
            ('B',    7.00, 0.25),
            ('B-',   5.00, 0.22),
            ('C+',   3.50, 0.18),
            ('C',    2.50, 0.15),
            ('C-',   1.50, 0.12),
            ('D',    1.00, 0.08),
            ('U',    0.25, 0.04)
        ) AS t(grade_level, cost, response)
    )
    SELECT 
        d.grade_state,
        COUNT(*) as donor_count,
        gc.cost as cost_per_contact,
        (COUNT(*) * gc.cost) as total_budget,
        gc.response as expected_response_rate,
        (COUNT(*) * gc.response * d_avg.avg_donation) as estimated_revenue,
        CASE 
            WHEN (COUNT(*) * gc.cost) > 0 
            THEN ((COUNT(*) * gc.response * d_avg.avg_donation) / (COUNT(*) * gc.cost))
            ELSE 0
        END as estimated_roi
    FROM donors d
    CROSS JOIN grade_costs gc
    CROSS JOIN (
        SELECT AVG(total_donations_aggregated / NULLIF(donation_count, 0)) as avg_donation
        FROM donors
    ) d_avg
    WHERE 
        d.grade_state = gc.grade_level
        AND d.is_active = TRUE
    GROUP BY d.grade_state, gc.cost, gc.response, d_avg.avg_donation
    ORDER BY 
        CASE d.grade_state
            WHEN 'A++' THEN 1
            WHEN 'A+' THEN 2
            WHEN 'A' THEN 3
            WHEN 'A-' THEN 4
            WHEN 'B+' THEN 5
            WHEN 'B' THEN 6
            WHEN 'B-' THEN 7
            WHEN 'C+' THEN 8
            WHEN 'C' THEN 9
            WHEN 'C-' THEN 10
            WHEN 'D' THEN 11
            WHEN 'U' THEN 12
        END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ROW LEVEL SECURITY (Optional - enable if needed)
-- ============================================================================

-- Enable RLS
-- ALTER TABLE donors ENABLE ROW LEVEL SECURITY;

-- Policy for authenticated users
-- CREATE POLICY donors_select_policy ON donors
--     FOR SELECT
--     USING (auth.role() = 'authenticated');

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE donors IS 'Master donor table with 112,609 unique donors including state/county ratings and spouse relationships';
COMMENT ON COLUMN donors.donor_id IS 'Unique donor identifier (DONOR_XXXXXX or DONOR_ED_BROYHILL)';
COMMENT ON COLUMN donors.grade_state IS 'Statewide donor grade (A++ through U)';
COMMENT ON COLUMN donors.grade_county IS 'County-level donor grade';
COMMENT ON COLUMN donors.donation_rank IS 'Statewide donation rank (1 = highest donor)';
COMMENT ON COLUMN donors.spouse_donor_id IS 'References spouse donor_id if spouse is also a donor';
COMMENT ON COLUMN donors.data_quality_score IS 'Auto-calculated 0-100 score based on data completeness';

-- ============================================================================
-- GRANT PERMISSIONS (adjust as needed)
-- ============================================================================

-- Grant to authenticated users
-- GRANT SELECT, INSERT, UPDATE ON donors TO authenticated;
-- GRANT USAGE ON SEQUENCE donors_id_seq TO authenticated;

-- ============================================================================
-- SCHEMA COMPLETE
-- ============================================================================

-- Verify table creation
SELECT 
    'Donors table created successfully!' as status,
    COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name = 'donors';
