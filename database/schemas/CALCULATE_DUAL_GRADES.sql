-- ============================================================================
-- BROYHILLGOP DUAL GRADING ALGORITHM
-- Run this AFTER importing persons data to calculate all ranks and grades
-- December 2024
-- ============================================================================

-- ============================================================================
-- STEP 1: CALCULATE STATEWIDE RANKS
-- ============================================================================

-- Update statewide rank (1 = top donor in NC)
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
-- STEP 2: CALCULATE COUNTY RANKS (for each of 100 NC counties)
-- ============================================================================

-- Update county rank (1 = top donor in THEIR county)
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
-- STEP 3: ASSIGN STATE GRADES (based on statewide percentile)
-- ============================================================================

UPDATE persons
SET donor_grade_state = CASE
    -- A++ = Top 0.1% (rank 1-130 of 130,000)
    WHEN donor_percentile_state >= 99.9 THEN 'A++'
    -- A+ = Top 1% (rank 131-1,300)
    WHEN donor_percentile_state >= 99.0 THEN 'A+'
    -- A = Top 5% (rank 1,301-6,500)
    WHEN donor_percentile_state >= 95.0 THEN 'A'
    -- A- = Top 10% (rank 6,501-13,000)
    WHEN donor_percentile_state >= 90.0 THEN 'A-'
    -- B+ = Top 20%
    WHEN donor_percentile_state >= 80.0 THEN 'B+'
    -- B = Top 30%
    WHEN donor_percentile_state >= 70.0 THEN 'B'
    -- B- = Top 40%
    WHEN donor_percentile_state >= 60.0 THEN 'B-'
    -- C+ = Top 50%
    WHEN donor_percentile_state >= 50.0 THEN 'C+'
    -- C = Top 60%
    WHEN donor_percentile_state >= 40.0 THEN 'C'
    -- C- = Top 70%
    WHEN donor_percentile_state >= 30.0 THEN 'C-'
    -- D = Bottom 30%
    WHEN donor_percentile_state >= 0 THEN 'D'
    ELSE 'U'
END
WHERE is_donor = TRUE AND donor_rank_state IS NOT NULL;

-- ============================================================================
-- STEP 4: ASSIGN COUNTY GRADES (based on county percentile)
-- ============================================================================

UPDATE persons
SET donor_grade_county = CASE
    -- A++ = Top 0.1% in county
    WHEN donor_percentile_county >= 99.9 THEN 'A++'
    -- A+ = Top 1% in county
    WHEN donor_percentile_county >= 99.0 THEN 'A+'
    -- A = Top 5% in county
    WHEN donor_percentile_county >= 95.0 THEN 'A'
    -- A- = Top 10% in county
    WHEN donor_percentile_county >= 90.0 THEN 'A-'
    -- B+ = Top 20% in county
    WHEN donor_percentile_county >= 80.0 THEN 'B+'
    -- B = Top 30% in county
    WHEN donor_percentile_county >= 70.0 THEN 'B'
    -- B- = Top 40% in county
    WHEN donor_percentile_county >= 60.0 THEN 'B-'
    -- C+ = Top 50% in county
    WHEN donor_percentile_county >= 50.0 THEN 'C+'
    -- C = Top 60% in county
    WHEN donor_percentile_county >= 40.0 THEN 'C'
    -- C- = Top 70% in county
    WHEN donor_percentile_county >= 30.0 THEN 'C-'
    -- D = Bottom 30% in county
    WHEN donor_percentile_county >= 0 THEN 'D'
    ELSE 'U'
END
WHERE is_donor = TRUE AND donor_rank_county IS NOT NULL;

-- ============================================================================
-- STEP 5: SET U GRADE FOR NON-DONORS
-- ============================================================================

UPDATE persons
SET 
    donor_grade_state = 'U',
    donor_grade_county = 'U'
WHERE is_donor = FALSE OR donation_total IS NULL OR donation_total = 0;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check statewide grade distribution
SELECT 'STATE GRADE DISTRIBUTION' as report;
SELECT donor_grade_state as grade, 
       COUNT(*) as count,
       MIN(donor_rank_state) as min_rank,
       MAX(donor_rank_state) as max_rank,
       ROUND(MIN(donation_total)::numeric, 2) as min_donation,
       ROUND(MAX(donation_total)::numeric, 2) as max_donation
FROM persons 
WHERE is_donor = TRUE
GROUP BY donor_grade_state
ORDER BY MIN(donor_rank_state);

-- Check county grade distribution (sample: Forsyth)
SELECT 'FORSYTH COUNTY TOP 20' as report;
SELECT person_id, full_name, 
       donation_total,
       donor_grade_state, donor_rank_state,
       donor_grade_county, donor_rank_county
FROM persons 
WHERE county = 'Forsyth' AND is_donor = TRUE
ORDER BY donor_rank_county
LIMIT 20;

-- Check all 100 counties have been ranked
SELECT 'COUNTY SUMMARY' as report;
SELECT county, 
       COUNT(*) as donors,
       COUNT(*) FILTER (WHERE donor_grade_county = 'A++') as a_plus_plus,
       COUNT(*) FILTER (WHERE donor_grade_county IN ('A+', 'A', 'A-')) as a_tier,
       ROUND(SUM(donation_total)::numeric, 2) as total
FROM persons 
WHERE is_donor = TRUE AND county IS NOT NULL
GROUP BY county
ORDER BY total DESC;

-- Show example: Same donor, different grades
SELECT 'DUAL GRADE EXAMPLES' as report;
SELECT full_name, county, donation_total,
       donor_grade_state || ' (#' || donor_rank_state || ')' as state_ranking,
       donor_grade_county || ' (#' || donor_rank_county || ')' as county_ranking
FROM persons
WHERE is_donor = TRUE 
  AND donor_grade_state != donor_grade_county
  AND donation_total > 10000
ORDER BY donation_total DESC
LIMIT 20;

SELECT 'DUAL GRADING ALGORITHM COMPLETE!' as status;
