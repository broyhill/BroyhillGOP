-- ============================================================================
-- BROYHILLGOP TRIPLE GRADING ALGORITHM
-- Upgrade from Dual (State/County) to Triple (State/District/County)
-- December 2024
-- ============================================================================

-- ============================================================================
-- STEP 0: ADD DISTRICT COLUMNS IF NOT EXISTS
-- ============================================================================

ALTER TABLE persons ADD COLUMN IF NOT EXISTS district_state_house VARCHAR(10);
ALTER TABLE persons ADD COLUMN IF NOT EXISTS district_state_senate VARCHAR(10);
ALTER TABLE persons ADD COLUMN IF NOT EXISTS district_us_house VARCHAR(10);
ALTER TABLE persons ADD COLUMN IF NOT EXISTS district_judicial VARCHAR(20);

ALTER TABLE persons ADD COLUMN IF NOT EXISTS donor_grade_district VARCHAR(3);
ALTER TABLE persons ADD COLUMN IF NOT EXISTS donor_rank_district INTEGER;
ALTER TABLE persons ADD COLUMN IF NOT EXISTS donor_percentile_district DECIMAL(6,3);

-- Create index for district lookups
CREATE INDEX IF NOT EXISTS idx_persons_district_house ON persons(district_state_house);
CREATE INDEX IF NOT EXISTS idx_persons_district_senate ON persons(district_state_senate);
CREATE INDEX IF NOT EXISTS idx_persons_district_us ON persons(district_us_house);

-- ============================================================================
-- STEP 1: CALCULATE STATEWIDE RANKS (unchanged from dual grading)
-- ============================================================================

WITH ranked AS (
    SELECT id,
           ROW_NUMBER() OVER (ORDER BY donation_total DESC NULLS LAST) as rank_state,
           PERCENT_RANK() OVER (ORDER BY donation_total DESC NULLS LAST) as pct_rank
    FROM persons
    WHERE is_donor = TRUE AND donation_total > 0
)
UPDATE persons p
SET 
    donor_rank_state = r.rank_state,
    donor_percentile_state = ROUND((1 - r.pct_rank) * 100, 3)
FROM ranked r
WHERE p.id = r.id;

-- ============================================================================
-- STEP 2: CALCULATE COUNTY RANKS (unchanged from dual grading)
-- ============================================================================

WITH ranked_by_county AS (
    SELECT id,
           county,
           ROW_NUMBER() OVER (PARTITION BY county ORDER BY donation_total DESC NULLS LAST) as rank_county,
           PERCENT_RANK() OVER (PARTITION BY county ORDER BY donation_total DESC NULLS LAST) as pct_rank
    FROM persons
    WHERE is_donor = TRUE AND donation_total > 0 AND county IS NOT NULL
)
UPDATE persons p
SET 
    donor_rank_county = r.rank_county,
    donor_percentile_county = ROUND((1 - r.pct_rank) * 100, 3)
FROM ranked_by_county r
WHERE p.id = r.id;

-- ============================================================================
-- STEP 3: CALCULATE DISTRICT RANKS (NEW - State House Districts)
-- ============================================================================

-- NC State House Districts (170 districts, HD-01 through HD-120)
WITH ranked_by_district AS (
    SELECT id,
           district_state_house,
           ROW_NUMBER() OVER (PARTITION BY district_state_house ORDER BY donation_total DESC NULLS LAST) as rank_district,
           PERCENT_RANK() OVER (PARTITION BY district_state_house ORDER BY donation_total DESC NULLS LAST) as pct_rank
    FROM persons
    WHERE is_donor = TRUE 
      AND donation_total > 0 
      AND district_state_house IS NOT NULL
)
UPDATE persons p
SET 
    donor_rank_district = r.rank_district,
    donor_percentile_district = ROUND((1 - r.pct_rank) * 100, 3)
FROM ranked_by_district r
WHERE p.id = r.id;

-- ============================================================================
-- STEP 4: ASSIGN STATE GRADES (based on statewide percentile)
-- ============================================================================

UPDATE persons
SET donor_grade_state = CASE
    WHEN donor_percentile_state >= 99.9 THEN 'A++'
    WHEN donor_percentile_state >= 99.0 THEN 'A+'
    WHEN donor_percentile_state >= 95.0 THEN 'A'
    WHEN donor_percentile_state >= 90.0 THEN 'A-'
    WHEN donor_percentile_state >= 80.0 THEN 'B+'
    WHEN donor_percentile_state >= 70.0 THEN 'B'
    WHEN donor_percentile_state >= 60.0 THEN 'B-'
    WHEN donor_percentile_state >= 50.0 THEN 'C+'
    WHEN donor_percentile_state >= 40.0 THEN 'C'
    WHEN donor_percentile_state >= 30.0 THEN 'C-'
    WHEN donor_percentile_state >= 20.0 THEN 'D+'
    WHEN donor_percentile_state >= 10.0 THEN 'D'
    WHEN donor_percentile_state >= 0 THEN 'D-'
    ELSE 'U'
END
WHERE is_donor = TRUE AND donor_rank_state IS NOT NULL;

-- ============================================================================
-- STEP 5: ASSIGN COUNTY GRADES (based on county percentile)
-- ============================================================================

UPDATE persons
SET donor_grade_county = CASE
    WHEN donor_percentile_county >= 99.9 THEN 'A++'
    WHEN donor_percentile_county >= 99.0 THEN 'A+'
    WHEN donor_percentile_county >= 95.0 THEN 'A'
    WHEN donor_percentile_county >= 90.0 THEN 'A-'
    WHEN donor_percentile_county >= 80.0 THEN 'B+'
    WHEN donor_percentile_county >= 70.0 THEN 'B'
    WHEN donor_percentile_county >= 60.0 THEN 'B-'
    WHEN donor_percentile_county >= 50.0 THEN 'C+'
    WHEN donor_percentile_county >= 40.0 THEN 'C'
    WHEN donor_percentile_county >= 30.0 THEN 'C-'
    WHEN donor_percentile_county >= 20.0 THEN 'D+'
    WHEN donor_percentile_county >= 10.0 THEN 'D'
    WHEN donor_percentile_county >= 0 THEN 'D-'
    ELSE 'U'
END
WHERE is_donor = TRUE AND donor_rank_county IS NOT NULL;

-- ============================================================================
-- STEP 6: ASSIGN DISTRICT GRADES (NEW - based on district percentile)
-- ============================================================================

UPDATE persons
SET donor_grade_district = CASE
    WHEN donor_percentile_district >= 99.9 THEN 'A++'
    WHEN donor_percentile_district >= 99.0 THEN 'A+'
    WHEN donor_percentile_district >= 95.0 THEN 'A'
    WHEN donor_percentile_district >= 90.0 THEN 'A-'
    WHEN donor_percentile_district >= 80.0 THEN 'B+'
    WHEN donor_percentile_district >= 70.0 THEN 'B'
    WHEN donor_percentile_district >= 60.0 THEN 'B-'
    WHEN donor_percentile_district >= 50.0 THEN 'C+'
    WHEN donor_percentile_district >= 40.0 THEN 'C'
    WHEN donor_percentile_district >= 30.0 THEN 'C-'
    WHEN donor_percentile_district >= 20.0 THEN 'D+'
    WHEN donor_percentile_district >= 10.0 THEN 'D'
    WHEN donor_percentile_district >= 0 THEN 'D-'
    ELSE 'U'
END
WHERE is_donor = TRUE AND donor_rank_district IS NOT NULL;

-- ============================================================================
-- STEP 7: SET U GRADE FOR NON-DONORS
-- ============================================================================

UPDATE persons
SET 
    donor_grade_state = 'U',
    donor_grade_county = 'U',
    donor_grade_district = 'U'
WHERE is_donor = FALSE OR donation_total IS NULL OR donation_total = 0;

-- ============================================================================
-- STEP 8: CREATE DISTRICT LOOKUP TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS nc_districts (
    district_id VARCHAR(20) PRIMARY KEY,
    district_type VARCHAR(20) NOT NULL, -- 'state_house', 'state_senate', 'us_house', 'judicial'
    district_number INTEGER,
    district_name VARCHAR(255),
    counties_covered JSONB DEFAULT '[]',
    total_donors INTEGER DEFAULT 0,
    total_donation_value DECIMAL(14,2) DEFAULT 0,
    last_calculated TIMESTAMP DEFAULT NOW()
);

-- Insert NC State House Districts (120 districts)
INSERT INTO nc_districts (district_id, district_type, district_number, district_name)
SELECT 
    'HD-' || LPAD(n::text, 3, '0'),
    'state_house',
    n,
    'NC House District ' || n
FROM generate_series(1, 120) n
ON CONFLICT (district_id) DO NOTHING;

-- Insert NC State Senate Districts (50 districts)
INSERT INTO nc_districts (district_id, district_type, district_number, district_name)
SELECT 
    'SD-' || LPAD(n::text, 2, '0'),
    'state_senate',
    n,
    'NC Senate District ' || n
FROM generate_series(1, 50) n
ON CONFLICT (district_id) DO NOTHING;

-- Insert US House Districts (14 districts)
INSERT INTO nc_districts (district_id, district_type, district_number, district_name)
SELECT 
    'CD-' || LPAD(n::text, 2, '0'),
    'us_house',
    n,
    'NC Congressional District ' || n
FROM generate_series(1, 14) n
ON CONFLICT (district_id) DO NOTHING;

-- ============================================================================
-- STEP 9: UPDATE DISTRICT STATISTICS
-- ============================================================================

UPDATE nc_districts d
SET 
    total_donors = stats.donor_count,
    total_donation_value = stats.total_value,
    last_calculated = NOW()
FROM (
    SELECT 
        district_state_house as district_id,
        COUNT(*) as donor_count,
        SUM(donation_total) as total_value
    FROM persons
    WHERE is_donor = TRUE AND district_state_house IS NOT NULL
    GROUP BY district_state_house
) stats
WHERE d.district_id = stats.district_id;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check triple grade distribution
SELECT 'TRIPLE GRADE DISTRIBUTION' as report;
SELECT 
    donor_grade_state as state_grade,
    COUNT(*) as state_count,
    donor_grade_county as county_grade,
    COUNT(*) as county_count,
    donor_grade_district as district_grade,
    COUNT(*) as district_count
FROM persons 
WHERE is_donor = TRUE
GROUP BY donor_grade_state, donor_grade_county, donor_grade_district
ORDER BY state_count DESC
LIMIT 20;

-- Show example: Same donor, THREE different grades
SELECT 'TRIPLE GRADE EXAMPLES' as report;
SELECT 
    full_name, 
    county, 
    district_state_house,
    donation_total,
    donor_grade_state || ' (#' || donor_rank_state || ')' as state_ranking,
    donor_grade_county || ' (#' || donor_rank_county || ')' as county_ranking,
    donor_grade_district || ' (#' || donor_rank_district || ')' as district_ranking
FROM persons
WHERE is_donor = TRUE 
  AND donor_grade_state IS DISTINCT FROM donor_grade_county
  AND donor_grade_district IS NOT NULL
  AND donation_total > 1000
ORDER BY donation_total DESC
LIMIT 20;

-- District summary
SELECT 'DISTRICT SUMMARY' as report;
SELECT 
    district_id,
    district_name,
    total_donors,
    total_donation_value
FROM nc_districts
WHERE district_type = 'state_house'
ORDER BY total_donation_value DESC
LIMIT 20;

SELECT 'TRIPLE GRADING ALGORITHM COMPLETE!' as status;
