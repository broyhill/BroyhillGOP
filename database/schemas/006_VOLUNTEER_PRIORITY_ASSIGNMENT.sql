-- ============================================================================
-- LOCAL VOLUNTEER PRIORITY ASSIGNMENT SYSTEM
-- Matching Volunteers to Local Candidates by Priority
-- November 28, 2025
-- ============================================================================

-- ============================================================================
-- PART 1: VOLUNTEER-CANDIDATE ASSIGNMENT TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteer_candidate_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Relationships
    volunteer_id UUID NOT NULL,
    candidate_id UUID NOT NULL REFERENCES local_candidates(id) ON DELETE CASCADE,
    
    -- Assignment Details
    assignment_type VARCHAR(50) NOT NULL,
    -- Types: 'primary', 'secondary', 'backup', 'special_project', 'event_only'
    
    -- Priority Level (1 = highest priority)
    priority_level INT NOT NULL CHECK (priority_level BETWEEN 1 AND 10),
    
    -- Match Scores
    total_match_score DECIMAL(5,2) NOT NULL,
    issue_match_score DECIMAL(5,2),
    office_pref_score DECIMAL(5,2),
    geographic_score DECIMAL(5,2),
    availability_score DECIMAL(5,2),
    faction_match_score DECIMAL(5,2),
    
    -- Assignment Reason
    assignment_reason TEXT,
    matching_factors JSONB DEFAULT '[]'::jsonb,
    
    -- Role Assignment
    assigned_role VARCHAR(100),
    -- Roles: 'door_knocker', 'phone_banker', 'poll_greeter', 'event_staff', 
    --        'data_entry', 'social_media', 'precinct_captain', 'team_lead'
    
    -- Hours Commitment
    committed_hours_total INT DEFAULT 0,
    committed_hours_weekly INT DEFAULT 0,
    hours_completed INT DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'proposed',
    -- Status: 'proposed', 'accepted', 'active', 'completed', 'declined', 'removed'
    
    -- Volunteer Response
    volunteer_accepted BOOLEAN,
    volunteer_response_date TIMESTAMP,
    volunteer_notes TEXT,
    
    -- Candidate/Campaign Response
    campaign_approved BOOLEAN,
    campaign_approved_by VARCHAR(100),
    campaign_approved_date TIMESTAMP,
    
    -- Activity Tracking
    first_activity_date DATE,
    last_activity_date DATE,
    activities_completed INT DEFAULT 0,
    no_shows INT DEFAULT 0,
    reliability_score DECIMAL(5,2) DEFAULT 100.00,
    
    -- Performance
    doors_knocked INT DEFAULT 0,
    calls_made INT DEFAULT 0,
    events_worked INT DEFAULT 0,
    voter_contacts INT DEFAULT 0,
    donations_generated NUMERIC(10,2) DEFAULT 0,
    referrals_made INT DEFAULT 0,
    
    -- Metadata
    assigned_by VARCHAR(100),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_vol_cand_assign UNIQUE (volunteer_id, candidate_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vca_volunteer ON volunteer_candidate_assignments(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_vca_candidate ON volunteer_candidate_assignments(candidate_id);
CREATE INDEX IF NOT EXISTS idx_vca_priority ON volunteer_candidate_assignments(priority_level);
CREATE INDEX IF NOT EXISTS idx_vca_status ON volunteer_candidate_assignments(status);
CREATE INDEX IF NOT EXISTS idx_vca_score ON volunteer_candidate_assignments(total_match_score DESC);

-- ============================================================================
-- PART 2: PRIORITY CALCULATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION assign_volunteers_to_candidate(
    p_candidate_id UUID,
    p_max_volunteers INT DEFAULT 100,
    p_min_match_score DECIMAL DEFAULT 50.0
) RETURNS INT AS $$
DECLARE
    v_candidate RECORD;
    v_volunteer RECORD;
    v_match RECORD;
    v_assigned INT := 0;
    v_priority INT := 1;
BEGIN
    -- Get candidate info
    SELECT * INTO v_candidate FROM local_candidates WHERE id = p_candidate_id;
    
    IF v_candidate IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Find and rank volunteers
    FOR v_volunteer IN
        SELECT 
            lvp.*,
            d.first_name,
            d.last_name,
            d.email
        FROM local_volunteer_profile lvp
        LEFT JOIN donors d ON lvp.donor_id = d.id
        WHERE lvp.county_name = v_candidate.county_name
        AND NOT EXISTS (
            SELECT 1 FROM volunteer_candidate_assignments vca
            WHERE vca.volunteer_id = lvp.volunteer_id
            AND vca.candidate_id = p_candidate_id
        )
        ORDER BY lvp.local_volunteer_score DESC
        LIMIT p_max_volunteers * 2
    LOOP
        -- Calculate match score
        SELECT * INTO v_match 
        FROM calculate_volunteer_candidate_match(v_volunteer.volunteer_id, p_candidate_id);
        
        IF v_match.total_score >= p_min_match_score THEN
            -- Determine role based on strengths
            DECLARE
                v_role VARCHAR(100);
            BEGIN
                IF v_volunteer.phone_bank_hours > 20 THEN
                    v_role := 'phone_banker';
                ELSIF v_volunteer.door_knock_hours > 20 THEN
                    v_role := 'door_knocker';
                ELSIF v_volunteer.precinct_captain THEN
                    v_role := 'precinct_captain';
                ELSIF v_volunteer.event_coordinator THEN
                    v_role := 'event_staff';
                ELSIF v_volunteer.has_data_skills THEN
                    v_role := 'data_entry';
                ELSIF v_volunteer.has_social_media_skills THEN
                    v_role := 'social_media';
                ELSE
                    v_role := 'general_volunteer';
                END IF;
                
                -- Create assignment
                INSERT INTO volunteer_candidate_assignments (
                    volunteer_id, candidate_id,
                    assignment_type, priority_level,
                    total_match_score, issue_match_score, office_pref_score,
                    geographic_score, availability_score, faction_match_score,
                    assigned_role, committed_hours_weekly,
                    assignment_reason, matching_factors, status
                ) VALUES (
                    v_volunteer.volunteer_id, p_candidate_id,
                    CASE 
                        WHEN v_match.total_score >= 80 THEN 'primary'
                        WHEN v_match.total_score >= 65 THEN 'secondary'
                        ELSE 'backup'
                    END,
                    v_priority,
                    v_match.total_score, v_match.issue_match, v_match.office_pref_match,
                    v_match.geographic_match, v_match.availability_score, v_match.faction_match,
                    v_role, v_volunteer.hours_per_week_available,
                    'Auto-assigned based on match algorithm',
                    jsonb_build_array(
                        CASE WHEN v_match.geographic_match >= 80 THEN 'Same county' END,
                        CASE WHEN v_match.issue_match >= 80 THEN 'Strong issue alignment' END,
                        CASE WHEN v_match.office_pref_match >= 80 THEN 'Prefers this office type' END
                    ),
                    'proposed'
                );
                
                v_assigned := v_assigned + 1;
                v_priority := v_priority + 1;
                
                IF v_assigned >= p_max_volunteers THEN
                    EXIT;
                END IF;
            END;
        END IF;
    END LOOP;
    
    RETURN v_assigned;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 3: BATCH ASSIGNMENT FOR ALL LOCAL CANDIDATES
-- ============================================================================

CREATE OR REPLACE FUNCTION batch_assign_volunteers_all_candidates(
    p_county VARCHAR DEFAULT NULL,
    p_office_type VARCHAR DEFAULT NULL,
    p_max_per_candidate INT DEFAULT 50
) RETURNS TABLE (
    candidate_id UUID,
    candidate_name VARCHAR,
    office_type VARCHAR,
    volunteers_assigned INT
) AS $$
DECLARE
    v_candidate RECORD;
BEGIN
    FOR v_candidate IN
        SELECT id, full_name, office_type, county_name
        FROM local_candidates
        WHERE status IN ('filed', 'active')
        AND (p_county IS NULL OR county_name = p_county)
        AND (p_office_type IS NULL OR local_candidates.office_type = p_office_type)
        ORDER BY election_year, county_name, office_type
    LOOP
        candidate_id := v_candidate.id;
        candidate_name := v_candidate.full_name;
        office_type := v_candidate.office_type;
        volunteers_assigned := assign_volunteers_to_candidate(v_candidate.id, p_max_per_candidate);
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 4: VOLUNTEER PRIORITY VIEW
-- ============================================================================

CREATE OR REPLACE VIEW v_volunteer_priorities AS
SELECT 
    vca.id AS assignment_id,
    vca.volunteer_id,
    COALESCE(d.first_name || ' ' || d.last_name, 'Unknown') AS volunteer_name,
    d.email AS volunteer_email,
    d.phone AS volunteer_phone,
    lvp.county_name AS volunteer_county,
    
    vca.candidate_id,
    lc.full_name AS candidate_name,
    lc.office_type,
    lot.name AS office_name,
    lc.county_name AS candidate_county,
    lc.election_year,
    
    vca.priority_level,
    vca.assignment_type,
    vca.total_match_score,
    vca.assigned_role,
    vca.committed_hours_weekly,
    
    vca.status,
    vca.volunteer_accepted,
    vca.campaign_approved,
    
    vca.hours_completed,
    vca.activities_completed,
    vca.doors_knocked,
    vca.calls_made,
    vca.reliability_score,
    
    vca.assigned_at
FROM volunteer_candidate_assignments vca
JOIN local_candidates lc ON vca.candidate_id = lc.id
JOIN local_office_types lot ON lc.office_type = lot.code
LEFT JOIN local_volunteer_profile lvp ON vca.volunteer_id = lvp.volunteer_id
LEFT JOIN donors d ON lvp.donor_id = d.id
ORDER BY lc.county_name, lc.office_type, vca.priority_level;

-- ============================================================================
-- PART 5: CANDIDATE VOLUNTEER SUMMARY VIEW
-- ============================================================================

CREATE OR REPLACE VIEW v_candidate_volunteer_summary AS
SELECT 
    lc.id AS candidate_id,
    lc.full_name AS candidate_name,
    lc.office_type,
    lot.name AS office_name,
    lc.county_name,
    lc.election_year,
    lc.status AS candidate_status,
    
    -- Volunteer Counts
    COUNT(vca.id) AS total_volunteers,
    COUNT(CASE WHEN vca.assignment_type = 'primary' THEN 1 END) AS primary_volunteers,
    COUNT(CASE WHEN vca.assignment_type = 'secondary' THEN 1 END) AS secondary_volunteers,
    COUNT(CASE WHEN vca.status = 'active' THEN 1 END) AS active_volunteers,
    COUNT(CASE WHEN vca.status = 'accepted' THEN 1 END) AS accepted_volunteers,
    COUNT(CASE WHEN vca.status = 'proposed' THEN 1 END) AS pending_volunteers,
    
    -- Hours
    SUM(vca.committed_hours_weekly) AS weekly_hours_committed,
    SUM(vca.hours_completed) AS total_hours_worked,
    
    -- Activity Summary
    SUM(vca.doors_knocked) AS total_doors_knocked,
    SUM(vca.calls_made) AS total_calls_made,
    SUM(vca.events_worked) AS total_events_worked,
    SUM(vca.voter_contacts) AS total_voter_contacts,
    
    -- Role Distribution
    COUNT(CASE WHEN vca.assigned_role = 'door_knocker' THEN 1 END) AS door_knockers,
    COUNT(CASE WHEN vca.assigned_role = 'phone_banker' THEN 1 END) AS phone_bankers,
    COUNT(CASE WHEN vca.assigned_role = 'precinct_captain' THEN 1 END) AS precinct_captains,
    COUNT(CASE WHEN vca.assigned_role = 'event_staff' THEN 1 END) AS event_staff,
    
    -- Match Quality
    ROUND(AVG(vca.total_match_score), 2) AS avg_match_score,
    MAX(vca.total_match_score) AS best_match_score,
    MIN(vca.total_match_score) AS lowest_match_score,
    
    -- Reliability
    ROUND(AVG(vca.reliability_score), 2) AS avg_reliability
    
FROM local_candidates lc
JOIN local_office_types lot ON lc.office_type = lot.code
LEFT JOIN volunteer_candidate_assignments vca ON lc.id = vca.candidate_id
WHERE lc.status IN ('filed', 'active')
GROUP BY lc.id, lc.full_name, lc.office_type, lot.name, lc.county_name, 
         lc.election_year, lc.status
ORDER BY lc.county_name, lot.display_order, lc.full_name;

-- ============================================================================
-- PART 6: VOLUNTEER WORKLOAD BALANCING
-- ============================================================================

CREATE OR REPLACE VIEW v_volunteer_workload AS
SELECT 
    lvp.volunteer_id,
    COALESCE(d.first_name || ' ' || d.last_name, 'Unknown') AS volunteer_name,
    lvp.county_name,
    lvp.hours_per_week_available,
    lvp.local_volunteer_grade,
    lvp.local_volunteer_score,
    
    -- Assignment Summary
    COUNT(vca.id) AS total_assignments,
    COUNT(CASE WHEN vca.status = 'active' THEN 1 END) AS active_assignments,
    STRING_AGG(DISTINCT lc.office_type, ', ') AS office_types_assigned,
    
    -- Hours Analysis
    SUM(vca.committed_hours_weekly) AS total_committed_hours,
    lvp.hours_per_week_available - COALESCE(SUM(vca.committed_hours_weekly), 0) AS available_hours_remaining,
    
    -- Performance
    SUM(vca.hours_completed) AS total_hours_worked,
    ROUND(AVG(vca.reliability_score), 2) AS avg_reliability,
    
    -- Capacity Status
    CASE 
        WHEN SUM(vca.committed_hours_weekly) >= lvp.hours_per_week_available * 0.9 THEN 'FULL'
        WHEN SUM(vca.committed_hours_weekly) >= lvp.hours_per_week_available * 0.7 THEN 'NEAR_CAPACITY'
        WHEN SUM(vca.committed_hours_weekly) >= lvp.hours_per_week_available * 0.4 THEN 'MODERATE'
        WHEN SUM(vca.committed_hours_weekly) > 0 THEN 'LIGHT'
        ELSE 'UNASSIGNED'
    END AS capacity_status
    
FROM local_volunteer_profile lvp
LEFT JOIN volunteer_candidate_assignments vca ON lvp.volunteer_id = vca.volunteer_id
LEFT JOIN local_candidates lc ON vca.candidate_id = lc.id
LEFT JOIN donors d ON lvp.donor_id = d.id
GROUP BY lvp.volunteer_id, d.first_name, d.last_name, lvp.county_name,
         lvp.hours_per_week_available, lvp.local_volunteer_grade, lvp.local_volunteer_score
ORDER BY lvp.county_name, lvp.local_volunteer_score DESC;

-- ============================================================================
-- PART 7: PRIORITY TAG SYSTEM
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteer_priority_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID NOT NULL,
    candidate_id UUID REFERENCES local_candidates(id) ON DELETE CASCADE,
    
    -- Tag Type
    tag_type VARCHAR(50) NOT NULL,
    -- Types: 'high_priority', 'vip', 'specialist', 'leadership', 'new_recruit',
    --        'needs_training', 'experienced', 'reliable', 'unreliable', 'inactive'
    
    tag_value VARCHAR(100),
    tag_reason TEXT,
    
    -- Priority Boost/Penalty
    priority_modifier INT DEFAULT 0, -- Positive = higher priority, negative = lower
    
    -- Validity
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_until DATE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    tagged_by VARCHAR(100),
    tagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_vol_tag UNIQUE (volunteer_id, candidate_id, tag_type)
);

-- Function to get effective priority for a volunteer-candidate pair
CREATE OR REPLACE FUNCTION get_effective_priority(
    p_volunteer_id UUID,
    p_candidate_id UUID
) RETURNS INT AS $$
DECLARE
    v_base_priority INT;
    v_modifier INT := 0;
BEGIN
    -- Get base priority
    SELECT priority_level INTO v_base_priority
    FROM volunteer_candidate_assignments
    WHERE volunteer_id = p_volunteer_id AND candidate_id = p_candidate_id;
    
    IF v_base_priority IS NULL THEN
        RETURN 999; -- Not assigned
    END IF;
    
    -- Sum all active modifiers
    SELECT COALESCE(SUM(priority_modifier), 0) INTO v_modifier
    FROM volunteer_priority_tags
    WHERE volunteer_id = p_volunteer_id
    AND (candidate_id = p_candidate_id OR candidate_id IS NULL)
    AND is_active = TRUE
    AND (effective_until IS NULL OR effective_until >= CURRENT_DATE);
    
    -- Return adjusted priority (lower = higher priority)
    RETURN GREATEST(1, v_base_priority - v_modifier);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- PART 8: VOLUNTEER DEPLOYMENT RECOMMENDATIONS
-- ============================================================================

CREATE OR REPLACE VIEW v_deployment_recommendations AS
WITH candidate_needs AS (
    SELECT 
        lc.id AS candidate_id,
        lc.full_name,
        lc.office_type,
        lc.county_name,
        lot.voters_per_race,
        lot.typical_donors_needed,
        -- Calculate needed volunteers based on office
        CASE 
            WHEN lc.office_type = 'SHERIFF' THEN 50
            WHEN lc.office_type = 'COMMISH' THEN 30
            WHEN lc.office_type = 'SCHBRD' THEN 25
            WHEN lc.office_type = 'DA' THEN 60
            WHEN lc.office_type = 'MAYOR' THEN 25
            WHEN lc.office_type = 'COUNCIL' THEN 10
            ELSE 20
        END AS target_volunteers,
        COALESCE(assigned.cnt, 0) AS current_volunteers
    FROM local_candidates lc
    JOIN local_office_types lot ON lc.office_type = lot.code
    LEFT JOIN (
        SELECT candidate_id, COUNT(*) AS cnt
        FROM volunteer_candidate_assignments
        WHERE status IN ('accepted', 'active')
        GROUP BY candidate_id
    ) assigned ON lc.id = assigned.candidate_id
    WHERE lc.status IN ('filed', 'active')
)
SELECT 
    cn.candidate_id,
    cn.full_name AS candidate_name,
    cn.office_type,
    cn.county_name,
    cn.target_volunteers,
    cn.current_volunteers,
    cn.target_volunteers - cn.current_volunteers AS volunteers_needed,
    ROUND((cn.current_volunteers::DECIMAL / NULLIF(cn.target_volunteers, 0)) * 100, 1) AS coverage_pct,
    CASE 
        WHEN cn.current_volunteers >= cn.target_volunteers THEN 'FULLY_STAFFED'
        WHEN cn.current_volunteers >= cn.target_volunteers * 0.75 THEN 'NEARLY_STAFFED'
        WHEN cn.current_volunteers >= cn.target_volunteers * 0.50 THEN 'NEEDS_HELP'
        WHEN cn.current_volunteers >= cn.target_volunteers * 0.25 THEN 'URGENT_NEED'
        ELSE 'CRITICAL_NEED'
    END AS staffing_status,
    -- Recommendation
    CASE 
        WHEN cn.current_volunteers < cn.target_volunteers * 0.25 THEN 
            'URGENT: Recruit ' || (cn.target_volunteers - cn.current_volunteers) || ' volunteers immediately'
        WHEN cn.current_volunteers < cn.target_volunteers * 0.50 THEN 
            'HIGH: Need ' || (cn.target_volunteers - cn.current_volunteers) || ' more volunteers'
        WHEN cn.current_volunteers < cn.target_volunteers * 0.75 THEN 
            'MODERATE: Could use ' || (cn.target_volunteers - cn.current_volunteers) || ' more volunteers'
        WHEN cn.current_volunteers < cn.target_volunteers THEN 
            'LOW: ' || (cn.target_volunteers - cn.current_volunteers) || ' positions remaining'
        ELSE 'NONE: Fully staffed'
    END AS recommendation
FROM candidate_needs cn
ORDER BY 
    CASE 
        WHEN cn.current_volunteers < cn.target_volunteers * 0.25 THEN 1
        WHEN cn.current_volunteers < cn.target_volunteers * 0.50 THEN 2
        WHEN cn.current_volunteers < cn.target_volunteers * 0.75 THEN 3
        ELSE 4
    END,
    cn.county_name,
    cn.office_type;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE volunteer_candidate_assignments IS 'Maps volunteers to local candidates with priority levels and match scores';
COMMENT ON TABLE volunteer_priority_tags IS 'Tags for adjusting volunteer priority (VIP, specialist, reliable, etc.)';
COMMENT ON FUNCTION assign_volunteers_to_candidate IS 'Auto-assigns volunteers to a candidate based on match algorithm';
COMMENT ON VIEW v_volunteer_priorities IS 'Complete view of volunteer-candidate assignments with details';
COMMENT ON VIEW v_candidate_volunteer_summary IS 'Summary of volunteer coverage for each candidate';
COMMENT ON VIEW v_volunteer_workload IS 'Shows volunteer capacity and workload balance';
COMMENT ON VIEW v_deployment_recommendations IS 'Identifies candidates needing more volunteer support';
