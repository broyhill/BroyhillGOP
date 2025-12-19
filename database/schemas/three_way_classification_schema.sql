-- ============================================================================
-- BROYHILLGOP THREE-WAY CLASSIFICATION SYSTEM
-- ============================================================================
-- Classifications:
--   1. DONOR ONLY (is_donor = TRUE, is_volunteer = FALSE)
--   2. VOLUNTEER ONLY (is_donor = FALSE, is_volunteer = TRUE)
--   3. DONOR & VOLUNTEER (is_donor = TRUE, is_volunteer = TRUE)
-- ============================================================================

-- ============================================================================
-- STEP 1: ADD CLASSIFICATION COLUMNS TO EXISTING DONORS TABLE
-- ============================================================================

ALTER TABLE donors 
ADD COLUMN IF NOT EXISTS is_donor BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS is_volunteer BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS person_type VARCHAR(20) GENERATED ALWAYS AS (
    CASE 
        WHEN is_donor AND is_volunteer THEN 'DONOR_VOLUNTEER'
        WHEN is_donor AND NOT is_volunteer THEN 'DONOR_ONLY'
        WHEN NOT is_donor AND is_volunteer THEN 'VOLUNTEER_ONLY'
        ELSE 'UNKNOWN'
    END
) STORED;

-- Add index for person_type queries
CREATE INDEX idx_donors_person_type ON donors(person_type);
CREATE INDEX idx_donors_is_volunteer ON donors(is_volunteer) WHERE is_volunteer = TRUE;

COMMENT ON COLUMN donors.is_donor IS 'TRUE if person has donation history';
COMMENT ON COLUMN donors.is_volunteer IS 'TRUE if person has volunteer activity';
COMMENT ON COLUMN donors.person_type IS 'Auto-calculated: DONOR_ONLY, VOLUNTEER_ONLY, or DONOR_VOLUNTEER';

-- ============================================================================
-- STEP 2: CREATE VOLUNTEERS TABLE (LINKED TO DONORS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteers (
    -- Primary Key
    volunteer_id SERIAL PRIMARY KEY,
    
    -- Foreign Key (links to donors table - EVERY person is in donors table)
    donor_id VARCHAR(50) NOT NULL REFERENCES donors(donor_id) ON DELETE CASCADE,
    
    -- Volunteer Classification
    volunteer_tier VARCHAR(20) CHECK (volunteer_tier IN ('Bronze', 'Silver', 'Gold', 'Platinum')),
    
    -- Activity Tracking
    total_hours INTEGER DEFAULT 0,
    activities TEXT[], -- Array of activities: ['Phone Banking', 'Canvassing', 'Event Staff']
    skills TEXT[], -- Array of skills: ['Graphic Design', 'Social Media', 'Public Speaking']
    
    -- Leadership
    leadership_roles TEXT[], -- Array: ['County Chair', 'Precinct Captain', 'Event Coordinator']
    is_leader BOOLEAN DEFAULT FALSE,
    
    -- Preferences
    issue_preferences TEXT[], -- Issues they care about
    availability JSONB, -- {"weekday_evenings": true, "weekends": true, "daytime": false}
    preferred_activities TEXT[], -- What they prefer to do
    
    -- Contact Preferences
    contact_method VARCHAR(20), -- EMAIL, PHONE, TEXT
    contact_frequency VARCHAR(20), -- WEEKLY, MONTHLY, AS_NEEDED
    
    -- Engagement Tracking
    first_activity_date DATE,
    last_activity_date DATE,
    months_since_last_activity INTEGER,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, PAUSED
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    
    -- Constraints
    UNIQUE(donor_id) -- Each person can only have ONE volunteer record
);

-- Indexes for volunteers table
CREATE INDEX idx_volunteers_donor_id ON volunteers(donor_id);
CREATE INDEX idx_volunteers_tier ON volunteers(volunteer_tier);
CREATE INDEX idx_volunteers_is_leader ON volunteers(is_leader) WHERE is_leader = TRUE;
CREATE INDEX idx_volunteers_last_activity ON volunteers(last_activity_date);
CREATE INDEX idx_volunteers_status ON volunteers(status);

-- Full-text search on activities and skills
CREATE INDEX idx_volunteers_activities ON volunteers USING GIN(activities);
CREATE INDEX idx_volunteers_skills ON volunteers USING GIN(skills);

COMMENT ON TABLE volunteers IS 'Volunteer activity tracking - links to donors table via donor_id';
COMMENT ON COLUMN volunteers.donor_id IS 'Links to donors.donor_id (every person is in donors table)';

-- ============================================================================
-- STEP 3: TRIGGER TO AUTO-UPDATE is_volunteer FLAG
-- ============================================================================

CREATE OR REPLACE FUNCTION update_volunteer_flag()
RETURNS TRIGGER AS $$
BEGIN
    -- When volunteer record is created, set is_volunteer = TRUE in donors table
    IF (TG_OP = 'INSERT') THEN
        UPDATE donors SET is_volunteer = TRUE WHERE donor_id = NEW.donor_id;
        RETURN NEW;
    END IF;
    
    -- When volunteer record is deleted, set is_volunteer = FALSE in donors table
    IF (TG_OP = 'DELETE') THEN
        UPDATE donors SET is_volunteer = FALSE WHERE donor_id = OLD.donor_id;
        RETURN OLD;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_volunteer_flag
    AFTER INSERT OR DELETE ON volunteers
    FOR EACH ROW
    EXECUTE FUNCTION update_volunteer_flag();

-- ============================================================================
-- STEP 4: CREATE CLASSIFICATION VIEWS
-- ============================================================================

-- View 1: DONOR ONLY (has donations, no volunteer activity)
CREATE OR REPLACE VIEW v_donor_only AS
SELECT 
    d.*,
    'DONOR_ONLY' as classification
FROM donors d
WHERE d.is_donor = TRUE 
AND d.is_volunteer = FALSE
AND d.is_active = TRUE
ORDER BY d.total_donations_aggregated DESC;

COMMENT ON VIEW v_donor_only IS 'People who donate but do not volunteer (recruitment targets for volunteer activities)';

-- View 2: VOLUNTEER ONLY (volunteers, no donation history)
CREATE OR REPLACE VIEW v_volunteer_only AS
SELECT 
    d.*,
    v.volunteer_tier,
    v.total_hours,
    v.activities,
    v.skills,
    v.leadership_roles,
    v.last_activity_date,
    'VOLUNTEER_ONLY' as classification
FROM donors d
INNER JOIN volunteers v ON d.donor_id = v.donor_id
WHERE d.is_donor = FALSE
AND d.is_volunteer = TRUE
AND d.is_active = TRUE
ORDER BY v.total_hours DESC;

COMMENT ON VIEW v_volunteer_only IS 'People who volunteer but have not donated (recruitment targets for donations)';

-- View 3: DONOR & VOLUNTEER (both donate and volunteer - SUPER ENGAGED)
CREATE OR REPLACE VIEW v_donor_volunteer AS
SELECT 
    d.*,
    v.volunteer_tier,
    v.total_hours,
    v.activities,
    v.skills,
    v.leadership_roles,
    v.last_activity_date,
    v.is_leader,
    'DONOR_VOLUNTEER' as classification,
    -- Calculate super engagement score
    CASE d.grade_state
        WHEN 'A++' THEN 100
        WHEN 'A+' THEN 95
        WHEN 'A' THEN 90
        WHEN 'A-' THEN 85
        WHEN 'B+' THEN 80
        WHEN 'B' THEN 75
        WHEN 'B-' THEN 70
        WHEN 'C+' THEN 65
        WHEN 'C' THEN 60
        WHEN 'C-' THEN 55
        WHEN 'D' THEN 50
        ELSE 40
    END +
    CASE v.volunteer_tier
        WHEN 'Platinum' THEN 30
        WHEN 'Gold' THEN 25
        WHEN 'Silver' THEN 20
        WHEN 'Bronze' THEN 15
        ELSE 0
    END as engagement_score
FROM donors d
INNER JOIN volunteers v ON d.donor_id = v.donor_id
WHERE d.is_donor = TRUE
AND d.is_volunteer = TRUE
AND d.is_active = TRUE
ORDER BY engagement_score DESC;

COMMENT ON VIEW v_donor_volunteer IS 'Super-engaged people who both donate AND volunteer (highest priority)';

-- ============================================================================
-- STEP 5: CLASSIFICATION SUMMARY FUNCTIONS
-- ============================================================================

-- Get counts by classification
CREATE OR REPLACE FUNCTION get_classification_summary()
RETURNS TABLE (
    classification VARCHAR,
    count BIGINT,
    avg_donation NUMERIC,
    total_donations NUMERIC,
    avg_hours NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH classifications AS (
        SELECT 
            'DONOR_ONLY' as classification,
            COUNT(*) as count,
            AVG(d.total_donations_aggregated) as avg_donation,
            SUM(d.total_donations_aggregated) as total_donations,
            0::NUMERIC as avg_hours
        FROM v_donor_only d
        
        UNION ALL
        
        SELECT 
            'VOLUNTEER_ONLY' as classification,
            COUNT(*) as count,
            0::NUMERIC as avg_donation,
            0::NUMERIC as total_donations,
            AVG(v.total_hours) as avg_hours
        FROM v_volunteer_only v
        
        UNION ALL
        
        SELECT 
            'DONOR_VOLUNTEER' as classification,
            COUNT(*) as count,
            AVG(dv.total_donations_aggregated) as avg_donation,
            SUM(dv.total_donations_aggregated) as total_donations,
            AVG(dv.total_hours) as avg_hours
        FROM v_donor_volunteer dv
    )
    SELECT * FROM classifications;
END;
$$ LANGUAGE plpgsql;

-- Get top people by classification
CREATE OR REPLACE FUNCTION get_top_by_classification(
    classification_type VARCHAR,
    result_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    donor_id VARCHAR,
    full_name VARCHAR,
    person_type VARCHAR,
    grade_state VARCHAR,
    total_donations NUMERIC,
    volunteer_tier VARCHAR,
    total_hours INTEGER,
    engagement_score INTEGER
) AS $$
BEGIN
    IF classification_type = 'DONOR_ONLY' THEN
        RETURN QUERY
        SELECT 
            d.donor_id,
            d.full_name,
            d.person_type,
            d.grade_state,
            d.total_donations_aggregated,
            NULL::VARCHAR as volunteer_tier,
            NULL::INTEGER as total_hours,
            NULL::INTEGER as engagement_score
        FROM v_donor_only d
        LIMIT result_limit;
        
    ELSIF classification_type = 'VOLUNTEER_ONLY' THEN
        RETURN QUERY
        SELECT 
            v.donor_id,
            v.full_name,
            v.person_type,
            v.grade_state,
            v.total_donations_aggregated,
            v.volunteer_tier,
            v.total_hours,
            NULL::INTEGER as engagement_score
        FROM v_volunteer_only v
        LIMIT result_limit;
        
    ELSIF classification_type = 'DONOR_VOLUNTEER' THEN
        RETURN QUERY
        SELECT 
            dv.donor_id,
            dv.full_name,
            dv.person_type,
            dv.grade_state,
            dv.total_donations_aggregated,
            dv.volunteer_tier,
            dv.total_hours,
            dv.engagement_score
        FROM v_donor_volunteer dv
        LIMIT result_limit;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 6: RECRUITMENT TARGET IDENTIFICATION
-- ============================================================================

-- View: High-value donors who should be recruited as volunteers
CREATE OR REPLACE VIEW v_donor_to_volunteer_targets AS
SELECT 
    d.*,
    'RECRUIT_TO_VOLUNTEER' as opportunity,
    CASE d.grade_state
        WHEN 'A++' THEN 'CRITICAL'
        WHEN 'A+' THEN 'CRITICAL'
        WHEN 'A' THEN 'HIGH'
        WHEN 'A-' THEN 'HIGH'
        WHEN 'B+' THEN 'MEDIUM'
        ELSE 'LOW'
    END as recruitment_priority
FROM v_donor_only d
WHERE d.grade_state IN ('A++', 'A+', 'A', 'A-', 'B+')
ORDER BY d.total_donations_aggregated DESC;

COMMENT ON VIEW v_donor_to_volunteer_targets IS 'High-value donors (B+ or better) who should be recruited to volunteer';

-- View: Active volunteers who should be recruited as donors
CREATE OR REPLACE VIEW v_volunteer_to_donor_targets AS
SELECT 
    v.*,
    'RECRUIT_TO_DONOR' as opportunity,
    CASE v.volunteer_tier
        WHEN 'Platinum' THEN 'CRITICAL'
        WHEN 'Gold' THEN 'HIGH'
        WHEN 'Silver' THEN 'MEDIUM'
        ELSE 'LOW'
    END as recruitment_priority
FROM v_volunteer_only v
WHERE v.volunteer_tier IN ('Platinum', 'Gold', 'Silver')
AND v.is_active = TRUE
ORDER BY v.total_hours DESC;

COMMENT ON VIEW v_volunteer_to_donor_targets IS 'Active volunteers (Silver+) who should be recruited to donate';

-- ============================================================================
-- STEP 7: ENGAGEMENT SCORING FOR SUPER-ENGAGED
-- ============================================================================

-- View: Super-engaged ranked by engagement score
CREATE OR REPLACE VIEW v_super_engaged AS
SELECT 
    dv.*,
    CASE 
        WHEN dv.engagement_score >= 120 THEN 'ULTRA_VIP'
        WHEN dv.engagement_score >= 110 THEN 'SUPER_VIP'
        WHEN dv.engagement_score >= 100 THEN 'VIP'
        WHEN dv.engagement_score >= 90 THEN 'HIGH_ENGAGED'
        ELSE 'ENGAGED'
    END as vip_tier
FROM v_donor_volunteer dv
ORDER BY dv.engagement_score DESC;

COMMENT ON VIEW v_super_engaged IS 'Donor+Volunteers ranked by combined engagement score (donation grade + volunteer tier)';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check classification distribution
-- SELECT * FROM get_classification_summary();

-- Get top 10 in each classification
-- SELECT * FROM get_top_by_classification('DONOR_ONLY', 10);
-- SELECT * FROM get_top_by_classification('VOLUNTEER_ONLY', 10);
-- SELECT * FROM get_top_by_classification('DONOR_VOLUNTEER', 10);

-- View recruitment targets
-- SELECT * FROM v_donor_to_volunteer_targets LIMIT 20;
-- SELECT * FROM v_volunteer_to_donor_targets LIMIT 20;

-- View super-engaged
-- SELECT * FROM v_super_engaged WHERE vip_tier IN ('ULTRA_VIP', 'SUPER_VIP') LIMIT 20;

-- ============================================================================
-- SCHEMA COMPLETE - THREE-WAY CLASSIFICATION READY
-- ============================================================================

SELECT 'Three-way classification system created successfully!' as status;
