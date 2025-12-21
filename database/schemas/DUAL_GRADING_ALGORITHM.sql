-- ============================================================================
-- BROYHILLGOP DUAL GRADING FOR DONORS TABLE
-- Run AFTER data import to calculate state + county rankings
-- December 2024
-- ============================================================================

-- STEP 1: Add the new ranking columns
ALTER TABLE donors ADD COLUMN IF NOT EXISTS donor_rank_state INTEGER;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS donor_rank_county INTEGER;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS donor_percentile_state DECIMAL(6,3);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS donor_percentile_county DECIMAL(6,3);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS donor_grade_state VARCHAR(5);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS donor_grade_county VARCHAR(5);

-- STEP 2: Calculate STATEWIDE ranks (1 = top donor in NC)
WITH ranked AS (
    SELECT donor_id,
           ROW_NUMBER() OVER (ORDER BY total_donations DESC NULLS LAST) as rank_state,
           PERCENT_RANK() OVER (ORDER BY total_donations DESC NULLS LAST) as pct_rank
    FROM donors
    WHERE total_donations > 0
)
UPDATE donors d
SET 
    donor_rank_state = r.rank_state,
    donor_percentile_state = ROUND(((1 - r.pct_rank) * 100)::NUMERIC, 3)
FROM ranked r
WHERE d.donor_id = r.donor_id;

-- STEP 3: Calculate COUNTY ranks (1 = top donor in THEIR county)
WITH ranked_by_county AS (
    SELECT donor_id,
           ROW_NUMBER() OVER (PARTITION BY county ORDER BY total_donations DESC NULLS LAST) as rank_county,
           PERCENT_RANK() OVER (PARTITION BY county ORDER BY total_donations DESC NULLS LAST) as pct_rank
    FROM donors
    WHERE total_donations > 0 AND county IS NOT NULL
)
UPDATE donors d
SET 
    donor_rank_county = r.rank_county,
    donor_percentile_county = ROUND(((1 - r.pct_rank) * 100)::NUMERIC, 3)
FROM ranked_by_county r
WHERE d.donor_id = r.donor_id;

-- STEP 4: Assign STATE grades based on percentile
UPDATE donors
SET donor_grade_state = CASE
    WHEN donor_percentile_state >= 99.9 THEN 'A++'  -- Top 0.1%
    WHEN donor_percentile_state >= 99.0 THEN 'A+'   -- Top 1%
    WHEN donor_percentile_state >= 95.0 THEN 'A'    -- Top 5%
    WHEN donor_percentile_state >= 90.0 THEN 'A-'   -- Top 10%
    WHEN donor_percentile_state >= 80.0 THEN 'B+'   -- Top 20%
    WHEN donor_percentile_state >= 70.0 THEN 'B'    -- Top 30%
    WHEN donor_percentile_state >= 60.0 THEN 'B-'   -- Top 40%
    WHEN donor_percentile_state >= 50.0 THEN 'C+'   -- Top 50%
    WHEN donor_percentile_state >= 40.0 THEN 'C'    -- Top 60%
    WHEN donor_percentile_state >= 30.0 THEN 'C-'   -- Top 70%
    ELSE 'D'                                         -- Bottom 30%
END
WHERE donor_rank_state IS NOT NULL;

-- STEP 5: Assign COUNTY grades based on percentile
UPDATE donors
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
    ELSE 'D'
END
WHERE donor_rank_county IS NOT NULL;

-- ============================================================================
-- INDEXES FOR FAST QUERIES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_donors_grade_state ON donors(donor_grade_state);
CREATE INDEX IF NOT EXISTS idx_donors_grade_county ON donors(donor_grade_county);
CREATE INDEX IF NOT EXISTS idx_donors_rank_state ON donors(donor_rank_state);
CREATE INDEX IF NOT EXISTS idx_donors_rank_county ON donors(donor_rank_county);
CREATE INDEX IF NOT EXISTS idx_donors_county_grade ON donors(county, donor_grade_county);
CREATE INDEX IF NOT EXISTS idx_donors_county_rank ON donors(county, donor_rank_county);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Grade distribution
SELECT donor_grade_state as grade, COUNT(*) as count
FROM donors WHERE donor_grade_state IS NOT NULL
GROUP BY donor_grade_state
ORDER BY CASE donor_grade_state
    WHEN 'A++' THEN 1 WHEN 'A+' THEN 2 WHEN 'A' THEN 3 WHEN 'A-' THEN 4
    WHEN 'B+' THEN 5 WHEN 'B' THEN 6 WHEN 'B-' THEN 7
    WHEN 'C+' THEN 8 WHEN 'C' THEN 9 WHEN 'C-' THEN 10
    WHEN 'D' THEN 11 ELSE 12 END;

-- Top 10 statewide
SELECT full_name, county, total_donations,
       donor_grade_state, donor_rank_state,
       donor_grade_county, donor_rank_county
FROM donors ORDER BY donor_rank_state LIMIT 10;

-- County summary
SELECT county, COUNT(*) as donors,
       COUNT(*) FILTER (WHERE donor_grade_county IN ('A++','A+','A')) as a_tier
FROM donors WHERE county IS NOT NULL
GROUP BY county ORDER BY donors DESC;

SELECT 'DUAL GRADING COMPLETE!' as status;
