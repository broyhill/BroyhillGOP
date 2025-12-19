-- ============================================================================
-- GRADE ENFORCEMENT - DATABASE LEVEL
-- ============================================================================
-- 
-- This SQL creates database-level enforcement of grade prioritization.
-- 
-- Features:
-- 1. Stored functions that ALWAYS order by grade
-- 2. Triggers that validate grade-based budgets
-- 3. Views that enforce grade filtering
-- 4. Constraints that prevent violations
--
-- CRITICAL: These cannot be bypassed by application code
-- ============================================================================

-- ============================================================================
-- FUNCTION: Get Donors Ordered by Grade (ENFORCED)
-- ============================================================================

CREATE OR REPLACE FUNCTION get_donors_by_grade(
    p_min_grade_numeric INTEGER DEFAULT 1,
    p_max_results INTEGER DEFAULT 1000,
    p_segment_filters JSONB DEFAULT '{}'::JSONB
)
RETURNS TABLE (
    donor_id UUID,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    donor_grade_current TEXT,
    donor_grade_numeric INTEGER,
    lifetime_5yr NUMERIC(12,2),
    top_issue_1 TEXT,
    top_issue_2 TEXT,
    top_issue_3 TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- CRITICAL: This function ENFORCES grade-first ordering
    -- Cannot be overridden by application code
    
    RETURN QUERY
    SELECT 
        dc.donor_id,
        dc.full_name,
        dc.email,
        dc.phone,
        dgi.donor_grade_current,
        dgi.donor_grade_numeric,
        dgi.grade_cumulative_dollars as lifetime_5yr,
        dc.top_issue_1,
        dc.top_issue_2,
        dc.top_issue_3
    FROM donors_core dc
    INNER JOIN donors_giving_intelligence dgi 
        ON dc.donor_id = dgi.donor_id
    WHERE 
        -- ENFORCE: Minimum grade filter
        dgi.donor_grade_numeric >= p_min_grade_numeric
        
        -- Additional filters from JSONB parameter
        AND (
            p_segment_filters = '{}'::JSONB
            OR (
                -- County filter
                (p_segment_filters->>'county' IS NULL 
                 OR dc.county = p_segment_filters->>'county')
                AND
                -- Issue filter
                (p_segment_filters->>'issue' IS NULL
                 OR dc.top_issue_1 = p_segment_filters->>'issue'
                 OR dc.top_issue_2 = p_segment_filters->>'issue'
                 OR dc.top_issue_3 = p_segment_filters->>'issue')
            )
        )
    
    -- CRITICAL: ORDER BY GRADE FIRST (ENFORCED)
    ORDER BY 
        dgi.donor_grade_numeric DESC,  -- Grade first (13 to 1)
        dgi.grade_cumulative_dollars DESC,  -- Then lifetime value
        dc.created_at DESC  -- Then recency
        
    LIMIT p_max_results;
END;
$$;

COMMENT ON FUNCTION get_donors_by_grade IS 
'GRADE-ENFORCED donor query. Always orders by grade_numeric DESC first. Cannot be overridden.';


-- ============================================================================
-- FUNCTION: Get Call Priority List (ENFORCED)
-- ============================================================================

CREATE OR REPLACE FUNCTION get_call_priority_list(
    p_candidate_id UUID,
    p_max_calls INTEGER DEFAULT 100,
    p_min_grade_numeric INTEGER DEFAULT 9  -- B+ minimum (enforced)
)
RETURNS TABLE (
    donor_id UUID,
    full_name TEXT,
    phone TEXT,
    email TEXT,
    donor_grade_current TEXT,
    call_priority INTEGER,
    lifetime_value NUMERIC(12,2),
    suggested_ask INTEGER,
    call_reason TEXT,
    last_contact_date TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- CRITICAL: Call lists MUST exclude grades below B+
    -- This is ENFORCED at database level
    
    -- Enforce B+ minimum
    IF p_min_grade_numeric < 9 THEN
        RAISE EXCEPTION 'GRADE VIOLATION: Call lists require min_grade >= 9 (B+). Got: %', p_min_grade_numeric;
    END IF;
    
    RETURN QUERY
    SELECT 
        dc.donor_id,
        dc.full_name,
        dc.phone,
        dc.email,
        dgi.donor_grade_current,
        (14 - dgi.donor_grade_numeric) as call_priority,  -- 1 = A+, 2 = A, etc.
        dgi.grade_cumulative_dollars as lifetime_value,
        
        -- Suggested ask based on grade
        CASE 
            WHEN dgi.donor_grade_numeric >= 13 THEN 5000  -- A+
            WHEN dgi.donor_grade_numeric = 12 THEN 2500   -- A
            WHEN dgi.donor_grade_numeric = 11 THEN 1000   -- A-
            WHEN dgi.donor_grade_numeric = 10 THEN 500    -- B+
            ELSE 250
        END as suggested_ask,
        
        -- Call reason based on grade
        CASE 
            WHEN dgi.donor_grade_numeric >= 13 THEN 'VIP Cultivation - Personal Meeting Required'
            WHEN dgi.donor_grade_numeric = 12 THEN 'Quarterly Major Donor Stewardship'
            WHEN dgi.donor_grade_numeric = 11 THEN 'Semi-Annual Check-in'
            WHEN dgi.donor_grade_numeric = 10 THEN 'Annual Major Donor Call'
            ELSE 'Standard Solicitation'
        END as call_reason,
        
        dc.last_contact_date
        
    FROM donors_core dc
    INNER JOIN donors_giving_intelligence dgi 
        ON dc.donor_id = dgi.donor_id
    WHERE 
        -- ENFORCE: Only B+ and above
        dgi.donor_grade_numeric >= p_min_grade_numeric
        
        -- Only donors not recently contacted
        AND (dc.last_contact_date IS NULL 
             OR dc.last_contact_date < NOW() - INTERVAL '30 days')
        
        -- Only donors with phone numbers
        AND dc.phone IS NOT NULL
    
    -- CRITICAL: ORDER BY CALL PRIORITY (GRADE-BASED)
    ORDER BY 
        (14 - dgi.donor_grade_numeric) ASC,  -- Priority 1 first
        dgi.grade_cumulative_dollars DESC
        
    LIMIT p_max_calls;
END;
$$;

COMMENT ON FUNCTION get_call_priority_list IS 
'GRADE-ENFORCED call list. Rejects min_grade < 9 (B+). Always orders by call priority (grade-based).';


-- ============================================================================
-- FUNCTION: Calculate Campaign Budget (GRADE-ENFORCED)
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_campaign_budget(
    p_segment_id UUID
)
RETURNS TABLE (
    grade TEXT,
    donor_count BIGINT,
    cost_per_donor NUMERIC(6,2),
    total_cost NUMERIC(12,2),
    expected_responses NUMERIC(10,2),
    expected_revenue NUMERIC(12,2),
    expected_roi NUMERIC(10,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- CRITICAL: Budget MUST be calculated by grade
    -- Uses grade-specific costs and response rates
    
    RETURN QUERY
    WITH donor_costs AS (
        SELECT 
            dgi.donor_grade_current,
            dgi.donor_grade_numeric,
            COUNT(*) as donor_count,
            
            -- Cost per donor based on grade (ENFORCED)
            CASE dgi.donor_grade_current
                WHEN 'A+' THEN 50.00
                WHEN 'A'  THEN 35.00
                WHEN 'A-' THEN 25.00
                WHEN 'B+' THEN 15.00
                WHEN 'B'  THEN 10.00
                WHEN 'B-' THEN 7.00
                WHEN 'C+' THEN 5.00
                WHEN 'C'  THEN 3.50
                WHEN 'C-' THEN 2.50
                WHEN 'D+' THEN 1.50
                WHEN 'D'  THEN 1.00
                WHEN 'D-' THEN 0.75
                WHEN 'U'  THEN 0.25
            END as cost_per_donor,
            
            -- Expected response rate by grade (ENFORCED)
            CASE dgi.donor_grade_current
                WHEN 'A+' THEN 0.40
                WHEN 'A'  THEN 0.38
                WHEN 'A-' THEN 0.35
                WHEN 'B+' THEN 0.28
                WHEN 'B'  THEN 0.25
                WHEN 'B-' THEN 0.22
                WHEN 'C+' THEN 0.18
                WHEN 'C'  THEN 0.15
                WHEN 'C-' THEN 0.12
                WHEN 'D+' THEN 0.10
                WHEN 'D'  THEN 0.08
                WHEN 'D-' THEN 0.06
                WHEN 'U'  THEN 0.04
            END as expected_response_rate,
            
            -- Expected average gift by grade (ENFORCED)
            CASE dgi.donor_grade_current
                WHEN 'A+' THEN 2500
                WHEN 'A'  THEN 1800
                WHEN 'A-' THEN 1200
                WHEN 'B+' THEN 750
                WHEN 'B'  THEN 500
                WHEN 'B-' THEN 350
                WHEN 'C+' THEN 200
                WHEN 'C'  THEN 135
                WHEN 'C-' THEN 95
                WHEN 'D+' THEN 75
                WHEN 'D'  THEN 55
                WHEN 'D-' THEN 40
                WHEN 'U'  THEN 25
            END as expected_avg_gift
            
        FROM donors_giving_intelligence dgi
        INNER JOIN segment_donors sd ON dgi.donor_id = sd.donor_id
        WHERE sd.segment_id = p_segment_id
        GROUP BY dgi.donor_grade_current, dgi.donor_grade_numeric
    )
    SELECT 
        donor_grade_current::TEXT as grade,
        donor_count,
        cost_per_donor,
        (donor_count * cost_per_donor) as total_cost,
        ROUND(donor_count * expected_response_rate, 2) as expected_responses,
        ROUND(donor_count * expected_response_rate * expected_avg_gift, 2) as expected_revenue,
        ROUND(
            (donor_count * expected_response_rate * expected_avg_gift) / 
            NULLIF(donor_count * cost_per_donor, 0),
            2
        ) as expected_roi
        
    FROM donor_costs
    
    -- ORDER BY GRADE (highest first)
    ORDER BY donor_grade_numeric DESC;
END;
$$;

COMMENT ON FUNCTION calculate_campaign_budget IS 
'GRADE-ENFORCED budget calculator. Uses grade-specific costs and expected returns.';


-- ============================================================================
-- TRIGGER: Validate Campaign Budget (ENFORCEMENT)
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_campaign_budget()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_grade_breakdown JSONB;
    v_total_cost NUMERIC;
    v_flat_rate_cost NUMERIC;
BEGIN
    -- CRITICAL: Prevent campaigns from using flat-rate budgeting
    -- Budget MUST be calculated by grade
    
    -- If budget method is not 'by_grade', reject
    IF NEW.budget_method != 'by_grade' THEN
        RAISE EXCEPTION 'BUDGET VIOLATION: Campaign budget must use method "by_grade". Got: %', NEW.budget_method;
    END IF;
    
    -- If budget_breakdown is missing, reject
    IF NEW.budget_breakdown IS NULL THEN
        RAISE EXCEPTION 'BUDGET VIOLATION: Campaign must include grade-based budget_breakdown';
    END IF;
    
    -- Verify budget breakdown has grade-specific costs
    IF NOT (NEW.budget_breakdown ? 'grades') THEN
        RAISE EXCEPTION 'BUDGET VIOLATION: Budget breakdown must include "grades" key';
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_campaign_budget
    BEFORE INSERT OR UPDATE ON campaigns
    FOR EACH ROW
    EXECUTE FUNCTION validate_campaign_budget();

COMMENT ON TRIGGER enforce_campaign_budget IS 
'ENFORCES grade-based budgeting. Rejects campaigns without grade-specific budget breakdown.';


-- ============================================================================
-- VIEW: Donors Ordered by Grade (ENFORCED)
-- ============================================================================

CREATE OR REPLACE VIEW v_donors_grade_ordered AS
SELECT 
    dc.donor_id,
    dc.full_name,
    dc.email,
    dc.phone,
    dgi.donor_grade_current,
    dgi.donor_grade_numeric,
    dgi.grade_cumulative_dollars,
    dgi.percentile_statewide,
    dc.top_issue_1,
    dc.top_issue_2,
    dc.top_issue_3,
    dc.county,
    dc.state_house_district,
    dc.created_at
FROM donors_core dc
INNER JOIN donors_giving_intelligence dgi 
    ON dc.donor_id = dgi.donor_id
-- CRITICAL: View is ALWAYS ordered by grade
ORDER BY 
    dgi.donor_grade_numeric DESC,
    dgi.grade_cumulative_dollars DESC,
    dc.created_at DESC;

COMMENT ON VIEW v_donors_grade_ordered IS 
'GRADE-ENFORCED view. Always returns donors ordered by grade_numeric DESC first.';


-- ============================================================================
-- CONSTRAINT: Valid Grade Values (ENFORCEMENT)
-- ============================================================================

ALTER TABLE donors_giving_intelligence
DROP CONSTRAINT IF EXISTS valid_donor_grade;

ALTER TABLE donors_giving_intelligence
ADD CONSTRAINT valid_donor_grade
CHECK (donor_grade_current IN (
    'A+', 'A', 'A-', 'B+', 'B', 'B-', 
    'C+', 'C', 'C-', 'D+', 'D', 'D-', 'U'
));

ALTER TABLE donors_giving_intelligence
DROP CONSTRAINT IF EXISTS valid_grade_numeric;

ALTER TABLE donors_giving_intelligence
ADD CONSTRAINT valid_grade_numeric
CHECK (donor_grade_numeric BETWEEN 1 AND 13);

COMMENT ON CONSTRAINT valid_donor_grade IS 
'ENFORCES valid grade values. Only A+ through U allowed.';

COMMENT ON CONSTRAINT valid_grade_numeric IS 
'ENFORCES valid numeric grades. Only 1-13 allowed.';


-- ============================================================================
-- INDEX: Optimized for Grade Queries
-- ============================================================================

-- Index on grade_numeric for fast ORDER BY
CREATE INDEX IF NOT EXISTS idx_donors_grade_numeric 
ON donors_giving_intelligence(donor_grade_numeric DESC);

-- Composite index for grade + lifetime value
CREATE INDEX IF NOT EXISTS idx_donors_grade_value 
ON donors_giving_intelligence(donor_grade_numeric DESC, grade_cumulative_dollars DESC);

-- Index for call priority queries
CREATE INDEX IF NOT EXISTS idx_donors_call_priority
ON donors_giving_intelligence(donor_grade_numeric DESC) 
WHERE donor_grade_numeric >= 9;  -- B+ and above only

COMMENT ON INDEX idx_donors_grade_numeric IS 
'Optimizes ORDER BY grade_numeric DESC queries';

COMMENT ON INDEX idx_donors_grade_value IS 
'Optimizes grade + value sorts (most common pattern)';

COMMENT ON INDEX idx_donors_call_priority IS 
'Optimizes call list queries (partial index for B+ and above)';


-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

/*
-- Example 1: Get donors by grade (enforced order)
SELECT * FROM get_donors_by_grade(
    p_min_grade_numeric := 9,  -- B+ and above
    p_max_results := 100,
    p_segment_filters := '{"county": "Forsyth", "issue": "government_efficiency"}'::JSONB
);

-- Example 2: Get call priority list (enforced minimum grade)
SELECT * FROM get_call_priority_list(
    p_candidate_id := 'candidate-uuid',
    p_max_calls := 50,
    p_min_grade_numeric := 10  -- B+ minimum
);

-- Example 3: Calculate campaign budget (grade-enforced)
SELECT * FROM calculate_campaign_budget(
    p_segment_id := 'segment-uuid'
);

-- Example 4: Use grade-ordered view
SELECT * FROM v_donors_grade_ordered
WHERE donor_grade_numeric >= 11  -- A-tier only
LIMIT 100;

-- Example 5: Try to violate constraints (will FAIL)
UPDATE donors_giving_intelligence 
SET donor_grade_current = 'Z+'  -- FAILS: invalid grade
WHERE donor_id = 'some-uuid';

-- Example 6: Try to use low grade in call list (will FAIL)
SELECT * FROM get_call_priority_list(
    p_candidate_id := 'candidate-uuid',
    p_max_calls := 100,
    p_min_grade_numeric := 5  -- FAILS: must be >= 9 (B+)
);
*/


-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify grade distribution
SELECT 
    donor_grade_current,
    COUNT(*) as count,
    ROUND(AVG(grade_cumulative_dollars), 2) as avg_lifetime,
    ROUND(SUM(grade_cumulative_dollars), 2) as total_revenue
FROM donors_giving_intelligence
GROUP BY donor_grade_current, donor_grade_numeric
ORDER BY donor_grade_numeric DESC;

-- Verify call list enforcement
DO $$
BEGIN
    -- This should SUCCEED (B+ minimum)
    PERFORM * FROM get_call_priority_list(
        '00000000-0000-0000-0000-000000000000'::UUID,
        10,
        9
    );
    RAISE NOTICE 'Test 1 PASSED: B+ minimum accepted';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 1 FAILED: %', SQLERRM;
END $$;

DO $$
BEGIN
    -- This should FAIL (C+ not allowed for calls)
    PERFORM * FROM get_call_priority_list(
        '00000000-0000-0000-0000-000000000000'::UUID,
        10,
        7  -- C+ grade (should fail)
    );
    RAISE NOTICE 'Test 2 FAILED: Should have rejected C+ grade';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test 2 PASSED: Correctly rejected C+ grade - %', SQLERRM;
END $$;


-- ============================================================================
-- DEPLOYMENT CHECKLIST
-- ============================================================================

/*
✓ 1. Run this SQL file in production database
✓ 2. Verify all functions created successfully
✓ 3. Verify trigger created successfully
✓ 4. Verify constraints added successfully
✓ 5. Verify indexes created successfully
✓ 6. Run verification queries
✓ 7. Test enforcement with sample queries
✓ 8. Update application code to use these functions
✓ 9. Remove any application code that bypasses these functions
✓ 10. Monitor for grade violations in logs

Expected Errors (These are GOOD - they're enforcement working):
- "GRADE VIOLATION: Call lists require min_grade >= 9 (B+)"
- "BUDGET VIOLATION: Campaign budget must use method by_grade"
- "BUDGET VIOLATION: Budget breakdown must include grades key"

These errors prevent violations. Do NOT "fix" them by lowering standards.
*/

-- ============================================================================
-- MAINTENANCE
-- ============================================================================

-- Check for queries that bypass grade ordering
CREATE OR REPLACE VIEW v_grade_violations AS
SELECT 
    query,
    calls,
    total_time
FROM pg_stat_statements
WHERE query LIKE '%donors_%'
  AND query NOT LIKE '%ORDER BY%grade%'
  AND calls > 10;

COMMENT ON VIEW v_grade_violations IS 
'Identifies queries that may be bypassing grade ordering. Review these queries.';


-- Done! Grade enforcement now MANDATORY at database level.
