-- ============================================================================
-- PROBABILITY ENGINES - DATABASE SCHEMA ENHANCEMENT
-- Two-Way Conversion System: Donors → Volunteers & Volunteers → Donors
-- ============================================================================
-- Created: December 1, 2024
-- Purpose: Add volunteer probability and donor probability scoring to database
-- ============================================================================

-- ============================================================================
-- ADD PROBABILITY SCORING COLUMNS TO DONORS TABLE
-- ============================================================================

ALTER TABLE donors ADD COLUMN IF NOT EXISTS volunteer_probability_score INTEGER DEFAULT 0;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS volunteer_scoring_factors TEXT;
ALTER TABLE donors ADD COLUMN IF NOT EXISTS volunteer_probability_tier VARCHAR(20);
ALTER TABLE donors ADD COLUMN IF NOT EXISTS volunteer_recruitment_priority VARCHAR(10);

COMMENT ON COLUMN donors.volunteer_probability_score IS 'Probability score (0-100) for donor to become volunteer';
COMMENT ON COLUMN donors.volunteer_scoring_factors IS 'Factors contributing to volunteer probability (Trump/MAGA, Education, Christian Right, etc.)';
COMMENT ON COLUMN donors.volunteer_probability_tier IS 'VERY_HIGH (60+), HIGH (40-59), MODERATE (20-39), LOWER (<20)';
COMMENT ON COLUMN donors.volunteer_recruitment_priority IS 'HIGH, MEDIUM, LOW based on score and current status';

-- ============================================================================
-- ADD PROBABILITY SCORING COLUMNS TO VOLUNTEERS TABLE (if exists)
-- ============================================================================

-- If you have a separate volunteers table:
-- ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS donor_probability_score INTEGER DEFAULT 0;
-- ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS donor_scoring_factors TEXT;
-- ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS donor_probability_tier VARCHAR(20);
-- ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS donor_recruitment_priority VARCHAR(10);

-- ============================================================================
-- VOLUNTEER PROBABILITY TIER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_volunteer_probability_tier(score INTEGER)
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE
        WHEN score >= 60 THEN 'VERY_HIGH'
        WHEN score >= 40 THEN 'HIGH'
        WHEN score >= 20 THEN 'MODERATE'
        ELSE 'LOWER'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- DONOR PROBABILITY TIER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_donor_probability_tier(score INTEGER)
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE
        WHEN score >= 80 THEN 'VERY_HIGH'
        WHEN score >= 60 THEN 'HIGH'
        WHEN score >= 40 THEN 'MODERATE'
        ELSE 'LOWER'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- VOLUNTEER RECRUITMENT PRIORITY FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_volunteer_recruitment_priority(
    score INTEGER,
    is_already_volunteer BOOLEAN
)
RETURNS VARCHAR(10) AS $$
BEGIN
    IF is_already_volunteer THEN
        RETURN 'N/A';
    ELSIF score >= 60 THEN
        RETURN 'HIGH';
    ELSIF score >= 40 THEN
        RETURN 'MEDIUM';
    ELSE
        RETURN 'LOW';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- DONOR RECRUITMENT PRIORITY FUNCTION  
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_donor_recruitment_priority(
    score INTEGER,
    is_already_donor BOOLEAN
)
RETURNS VARCHAR(10) AS $$
BEGIN
    IF is_already_donor THEN
        RETURN 'N/A';
    ELSIF score >= 80 THEN
        RETURN 'HIGH';
    ELSIF score >= 60 THEN
        RETURN 'MEDIUM';
    ELSE
        RETURN 'LOW';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- TRIGGER TO AUTO-CALCULATE VOLUNTEER PROBABILITY TIER
-- ============================================================================

CREATE OR REPLACE FUNCTION update_volunteer_probability_tier()
RETURNS TRIGGER AS $$
BEGIN
    NEW.volunteer_probability_tier := calculate_volunteer_probability_tier(NEW.volunteer_probability_score);
    NEW.volunteer_recruitment_priority := calculate_volunteer_recruitment_priority(
        NEW.volunteer_probability_score, 
        NEW.is_volunteer
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_volunteer_probability_tier
    BEFORE INSERT OR UPDATE OF volunteer_probability_score, is_volunteer ON donors
    FOR EACH ROW
    EXECUTE FUNCTION update_volunteer_probability_tier();

-- ============================================================================
-- INDEXES FOR PROBABILITY QUERIES
-- ============================================================================

CREATE INDEX idx_donors_volunteer_prob_score ON donors(volunteer_probability_score DESC);
CREATE INDEX idx_donors_volunteer_prob_tier ON donors(volunteer_probability_tier);
CREATE INDEX idx_donors_volunteer_recruitment ON donors(volunteer_recruitment_priority) 
    WHERE volunteer_recruitment_priority IN ('HIGH', 'MEDIUM');

-- Composite index for targeted recruitment
CREATE INDEX idx_donors_volunteer_targeting ON donors(
    volunteer_recruitment_priority,
    volunteer_probability_score DESC,
    grade_state
) WHERE is_volunteer = FALSE;

-- ============================================================================
-- VIEWS FOR PROBABILITY-BASED TARGETING
-- ============================================================================

-- View: High-priority volunteer recruitment targets
CREATE OR REPLACE VIEW v_volunteer_recruitment_high_priority AS
SELECT 
    donor_id,
    full_name,
    preferred_name,
    grade_state,
    total_donations_aggregated,
    volunteer_probability_score,
    volunteer_scoring_factors,
    email,
    mobile_phone_formatted,
    county
FROM donors
WHERE 
    is_volunteer = FALSE
    AND volunteer_probability_score >= 60
ORDER BY volunteer_probability_score DESC, total_donations_aggregated DESC;

COMMENT ON VIEW v_volunteer_recruitment_high_priority IS 'Donors with 60+ volunteer probability score who are not yet volunteers - immediate recruitment targets';

-- View: U Grade volunteer prospects
CREATE OR REPLACE VIEW v_u_grade_volunteer_prospects AS
SELECT 
    donor_id,
    full_name,
    preferred_name,
    grade_state,
    total_donations_aggregated,
    volunteer_probability_score,
    volunteer_probability_tier,
    volunteer_scoring_factors,
    email,
    mobile_phone_formatted,
    county,
    employer,
    occupation
FROM donors
WHERE 
    grade_state = 'U'
    AND is_volunteer = FALSE
ORDER BY volunteer_probability_score DESC;

COMMENT ON VIEW v_u_grade_volunteer_prospects IS 'U grade donors scored for volunteer probability - the 53,520 grassroots engaged donors';

-- View: A-tier donors to recruit as volunteers
CREATE OR REPLACE VIEW v_a_tier_volunteer_prospects AS
SELECT 
    donor_id,
    full_name,
    preferred_name,
    grade_state,
    total_donations_aggregated,
    volunteer_probability_score,
    volunteer_scoring_factors,
    email,
    mobile_phone_formatted,
    county
FROM donors
WHERE 
    grade_state LIKE 'A%'
    AND is_volunteer = FALSE
    AND volunteer_probability_score > 0
ORDER BY volunteer_probability_score DESC, total_donations_aggregated DESC;

COMMENT ON VIEW v_a_tier_volunteer_prospects IS 'A-tier donors with volunteer potential - high-value targets';

-- View: Volunteer probability by tier summary
CREATE OR REPLACE VIEW v_volunteer_probability_summary AS
SELECT 
    volunteer_probability_tier,
    COUNT(*) as donor_count,
    COUNT(*) FILTER (WHERE is_volunteer = FALSE) as not_yet_volunteer,
    ROUND(AVG(volunteer_probability_score), 2) as avg_score,
    SUM(total_donations_aggregated) as total_donations,
    ROUND(AVG(total_donations_aggregated), 2) as avg_donation
FROM donors
WHERE volunteer_probability_score > 0
GROUP BY volunteer_probability_tier
ORDER BY 
    CASE volunteer_probability_tier
        WHEN 'VERY_HIGH' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MODERATE' THEN 3
        WHEN 'LOWER' THEN 4
    END;

COMMENT ON VIEW v_volunteer_probability_summary IS 'Summary statistics by volunteer probability tier';

-- View: Issue-based volunteer recruitment
CREATE OR REPLACE VIEW v_volunteer_prospects_by_issue AS
SELECT 
    donor_id,
    full_name,
    preferred_name,
    grade_state,
    total_donations_aggregated,
    volunteer_probability_score,
    volunteer_scoring_factors,
    email,
    mobile_phone_formatted,
    county,
    employer,
    occupation,
    CASE 
        WHEN volunteer_scoring_factors LIKE '%TRUMP_MAGA%' THEN 'TRUMP_MAGA'
        WHEN volunteer_scoring_factors LIKE '%CHRISTIAN_RIGHT%' THEN 'CHRISTIAN_RIGHT'
        WHEN volunteer_scoring_factors LIKE '%EDUCATION_ACTIVIST%' THEN 'EDUCATION_ACTIVIST'
        WHEN volunteer_scoring_factors LIKE '%2ND_AMENDMENT%' THEN '2ND_AMENDMENT'
        WHEN volunteer_scoring_factors LIKE '%PRO_LIFE%' THEN 'PRO_LIFE'
        WHEN volunteer_scoring_factors LIKE '%SMALL_BUSINESS%' THEN 'SMALL_BUSINESS'
        ELSE 'OTHER'
    END as primary_issue
FROM donors
WHERE 
    is_volunteer = FALSE
    AND volunteer_probability_score >= 40
ORDER BY volunteer_probability_score DESC;

COMMENT ON VIEW v_volunteer_prospects_by_issue IS 'Volunteer prospects categorized by primary issue for targeted messaging';

-- ============================================================================
-- FUNCTIONS FOR RECRUITMENT TARGETING
-- ============================================================================

-- Get volunteer recruitment targets by score range
CREATE OR REPLACE FUNCTION get_volunteer_recruitment_targets(
    min_score INTEGER DEFAULT 60,
    max_score INTEGER DEFAULT 100,
    result_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    donor_id VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    mobile_phone VARCHAR,
    volunteer_probability_score INTEGER,
    volunteer_scoring_factors TEXT,
    grade_state VARCHAR,
    total_donations_aggregated NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.donor_id,
        d.full_name,
        d.email,
        d.mobile_phone_formatted as mobile_phone,
        d.volunteer_probability_score,
        d.volunteer_scoring_factors,
        d.grade_state,
        d.total_donations_aggregated
    FROM donors d
    WHERE 
        d.is_volunteer = FALSE
        AND d.volunteer_probability_score >= min_score
        AND d.volunteer_probability_score <= max_score
    ORDER BY d.volunteer_probability_score DESC, d.total_donations_aggregated DESC
    LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_volunteer_recruitment_targets IS 'Get volunteer recruitment targets by probability score range';

-- Get volunteer prospects by issue
CREATE OR REPLACE FUNCTION get_volunteer_prospects_by_issue(
    issue_keyword VARCHAR,
    min_score INTEGER DEFAULT 40
)
RETURNS TABLE (
    donor_id VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    mobile_phone VARCHAR,
    volunteer_probability_score INTEGER,
    county VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.donor_id,
        d.full_name,
        d.email,
        d.mobile_phone_formatted as mobile_phone,
        d.volunteer_probability_score,
        d.county
    FROM donors d
    WHERE 
        d.is_volunteer = FALSE
        AND d.volunteer_probability_score >= min_score
        AND d.volunteer_scoring_factors ILIKE '%' || issue_keyword || '%'
    ORDER BY d.volunteer_probability_score DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_volunteer_prospects_by_issue IS 'Get volunteer prospects filtered by issue (TRUMP_MAGA, CHRISTIAN_RIGHT, EDUCATION_ACTIVIST, etc.)';

-- Calculate expected volunteer conversions
CREATE OR REPLACE FUNCTION calculate_volunteer_conversion_projections()
RETURNS TABLE (
    tier VARCHAR,
    donor_count BIGINT,
    expected_conversion_rate NUMERIC,
    expected_new_volunteers INTEGER,
    expected_volunteer_hours INTEGER,
    campaign_cost NUMERIC,
    cost_per_volunteer NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH tier_data AS (
        SELECT 
            volunteer_probability_tier,
            COUNT(*) FILTER (WHERE is_volunteer = FALSE) as count_not_volunteer,
            CASE volunteer_probability_tier
                WHEN 'VERY_HIGH' THEN 0.45
                WHEN 'HIGH' THEN 0.30
                WHEN 'MODERATE' THEN 0.20
                ELSE 0.10
            END as conversion_rate,
            CASE volunteer_probability_tier
                WHEN 'VERY_HIGH' THEN 30.00
                WHEN 'HIGH' THEN 15.00
                WHEN 'MODERATE' THEN 5.00
                ELSE 2.00
            END as cost_per_contact
        FROM donors
        WHERE volunteer_probability_score > 0
        GROUP BY volunteer_probability_tier
    )
    SELECT 
        volunteer_probability_tier::VARCHAR as tier,
        count_not_volunteer as donor_count,
        conversion_rate as expected_conversion_rate,
        ROUND(count_not_volunteer * conversion_rate)::INTEGER as expected_new_volunteers,
        ROUND(count_not_volunteer * conversion_rate * 25)::INTEGER as expected_volunteer_hours,
        (count_not_volunteer * cost_per_contact) as campaign_cost,
        cost_per_contact as cost_per_volunteer
    FROM tier_data
    ORDER BY 
        CASE volunteer_probability_tier
            WHEN 'VERY_HIGH' THEN 1
            WHEN 'HIGH' THEN 2
            WHEN 'MODERATE' THEN 3
            ELSE 4
        END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_volunteer_conversion_projections IS 'Calculate expected volunteer conversions and costs by probability tier';

-- ============================================================================
-- SAMPLE QUERIES FOR USING THE PROBABILITY ENGINE
-- ============================================================================

/*
-- Get all high-priority volunteer recruitment targets
SELECT * FROM v_volunteer_recruitment_high_priority LIMIT 100;

-- Get U grade volunteer prospects
SELECT * FROM v_u_grade_volunteer_prospects WHERE volunteer_probability_score >= 40;

-- Get education activists to recruit
SELECT * FROM get_volunteer_prospects_by_issue('EDUCATION_ACTIVIST', 50);

-- Get Trump/MAGA supporters to recruit
SELECT * FROM get_volunteer_prospects_by_issue('TRUMP_MAGA', 40);

-- Get Christian Right activists to recruit
SELECT * FROM get_volunteer_prospects_by_issue('CHRISTIAN_RIGHT', 50);

-- Calculate volunteer conversion projections
SELECT * FROM calculate_volunteer_conversion_projections();

-- Get volunteer probability summary
SELECT * FROM v_volunteer_probability_summary;

-- Get specific score range
SELECT * FROM get_volunteer_recruitment_targets(60, 100, 500);

-- Count by recruitment priority
SELECT 
    volunteer_recruitment_priority,
    COUNT(*) as count,
    SUM(total_donations_aggregated) as total_value
FROM donors
GROUP BY volunteer_recruitment_priority
ORDER BY 
    CASE volunteer_recruitment_priority
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        WHEN 'LOW' THEN 3
        WHEN 'N/A' THEN 4
    END;
*/

-- ============================================================================
-- GRANT PERMISSIONS (adjust as needed)
-- ============================================================================

-- GRANT SELECT ON v_volunteer_recruitment_high_priority TO authenticated;
-- GRANT SELECT ON v_u_grade_volunteer_prospects TO authenticated;
-- GRANT SELECT ON v_volunteer_probability_summary TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_volunteer_recruitment_targets TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_volunteer_prospects_by_issue TO authenticated;

-- ============================================================================
-- PROBABILITY ENGINES SCHEMA COMPLETE
-- ============================================================================

SELECT 
    'Probability engines schema created successfully!' as status,
    'Use views and functions above for targeted recruitment' as next_step;
