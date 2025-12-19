-- ============================================================================
-- BROYHILLGOP DEPLOYMENT - CHUNK 3 of 3
-- Volunteer/Event Tables + Views + Functions
-- ============================================================================
-- 
-- INSTRUCTIONS:
-- 1. Make sure CHUNK_1 and CHUNK_2 completed successfully first
-- 2. Copy this ENTIRE file
-- 3. Paste into Supabase SQL Editor
-- 4. Click "Run"
-- 5. Wait for success message
-- 6. Deployment complete! ✅
--
-- ============================================================================

SET search_path TO broyhillgop, public;

-- ============================================================================
-- TABLE: volunteers
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteers (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Foreign Key (optional - can be volunteer without being donor)
    donor_id UUID REFERENCES donors(id) ON DELETE SET NULL,
    
    -- Basic Information
    first_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    
    -- Volunteer Details
    volunteer_since DATE,
    total_hours DECIMAL(8,2) DEFAULT 0,
    last_volunteer_date DATE,
    
    -- Skills and Availability
    skills TEXT[],
    availability TEXT,
    interests TEXT[],
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    background_check BOOLEAN DEFAULT FALSE,
    background_check_date DATE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    notes TEXT
);

-- Indexes for volunteers
CREATE INDEX idx_volunteers_donor ON volunteers(donor_id);
CREATE INDEX idx_volunteers_active ON volunteers(active);
CREATE INDEX idx_volunteers_email ON volunteers(email);

-- ============================================================================
-- TABLE: events
-- ============================================================================

CREATE TABLE IF NOT EXISTS events (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id VARCHAR(50) UNIQUE NOT NULL,
    
    -- Event Information
    name VARCHAR(200) NOT NULL,
    description TEXT,
    event_type VARCHAR(50),
    
    -- Scheduling
    event_date DATE NOT NULL,
    event_time TIME,
    end_time TIME,
    
    -- Location
    location VARCHAR(255),
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),
    
    -- Capacity
    capacity INTEGER,
    registered_count INTEGER DEFAULT 0,
    attended_count INTEGER DEFAULT 0,
    waitlist_count INTEGER DEFAULT 0,
    
    -- Cost
    cost DECIMAL(8,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(50) DEFAULT 'SCHEDULED',
    cancelled BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    
    notes TEXT,
    tags TEXT[]
);

-- Indexes for events
CREATE INDEX idx_events_date ON events(event_date);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_status ON events(status);

-- ============================================================================
-- TABLE: event_attendance
-- ============================================================================

CREATE TABLE IF NOT EXISTS event_attendance (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Foreign Keys
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Registration
    registered BOOLEAN DEFAULT TRUE,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Attendance
    attended BOOLEAN DEFAULT FALSE,
    checked_in_at TIMESTAMP,
    
    -- Additional
    guests INTEGER DEFAULT 0,
    donation_amount DECIMAL(10,2),
    
    notes TEXT,
    
    UNIQUE(event_id, donor_id)
);

-- Indexes for event_attendance
CREATE INDEX idx_attendance_event ON event_attendance(event_id);
CREATE INDEX idx_attendance_donor ON event_attendance(donor_id);
CREATE INDEX idx_attendance_attended ON event_attendance(attended);

-- ============================================================================
-- TABLE: enrichment_history
-- ============================================================================

CREATE TABLE IF NOT EXISTS enrichment_history (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Foreign Key
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Enrichment Details
    enrichment_type VARCHAR(50) NOT NULL,
    enrichment_source VARCHAR(100),
    provider VARCHAR(100),
    
    -- Fields Updated
    fields_updated TEXT[],
    
    -- Results
    success BOOLEAN DEFAULT TRUE,
    confidence_score DECIMAL(5,4),
    
    -- Cost
    cost DECIMAL(6,4),
    
    -- Metadata
    enriched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    enriched_by VARCHAR(100),
    
    notes TEXT
);

-- Indexes for enrichment_history
CREATE INDEX idx_enrichment_donor ON enrichment_history(donor_id);
CREATE INDEX idx_enrichment_type ON enrichment_history(enrichment_type);
CREATE INDEX idx_enrichment_date ON enrichment_history(enriched_at);

-- ============================================================================
-- TABLE: verification_history
-- ============================================================================

CREATE TABLE IF NOT EXISTS verification_history (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Foreign Key
    donor_id UUID REFERENCES donors(id) ON DELETE CASCADE,
    
    -- Verification Details
    verification_type VARCHAR(50) NOT NULL,
    field_verified VARCHAR(50),
    previous_value TEXT,
    new_value TEXT,
    
    -- Status
    status VARCHAR(20) CHECK (status IN ('VERIFIED', 'FAILED', 'PENDING', 'UPDATED')),
    
    -- Provider
    provider VARCHAR(100),
    confidence_score DECIMAL(5,4),
    
    -- Metadata
    verified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_by VARCHAR(100),
    
    notes TEXT
);

-- Indexes for verification_history
CREATE INDEX idx_verification_donor ON verification_history(donor_id);
CREATE INDEX idx_verification_type ON verification_history(verification_type);
CREATE INDEX idx_verification_status ON verification_history(status);
CREATE INDEX idx_verification_date ON verification_history(verified_at);

-- ============================================================================
-- ANALYTICAL VIEWS
-- ============================================================================

-- View: High-Value Donor Prospects
CREATE OR REPLACE VIEW v_high_value_prospects AS
SELECT 
    d.id,
    d.donor_id,
    d.full_name,
    d.email,
    d.phone,
    d.county,
    d.state,
    d.total_donations,
    d.amount_grade_state,
    d.intensity_grade_2y,
    d.level_preference,
    d.grade_3d,
    d.cluster_name,
    d.days_since_last_donation,
    d.lapsed_donor,
    d.last_contacted
FROM donors d
WHERE 
    d.amount_grade_state IN ('A++', 'A+', 'A', 'A-')
    AND d.lapsed_donor = FALSE
    AND (d.do_not_contact = FALSE OR d.do_not_contact IS NULL)
ORDER BY d.total_donations DESC;

-- View: Active Volunteers
CREATE OR REPLACE VIEW v_active_volunteers AS
SELECT 
    v.id,
    v.first_name,
    v.last_name,
    v.email,
    v.phone,
    v.volunteer_since,
    v.total_hours,
    v.last_volunteer_date,
    v.skills,
    d.donor_id,
    d.total_donations,
    d.amount_grade_state
FROM volunteers v
LEFT JOIN donors d ON v.donor_id = d.id
WHERE v.active = TRUE
ORDER BY v.total_hours DESC;

-- View: Donor-Volunteers (people who both donate AND volunteer)
CREATE OR REPLACE VIEW v_donor_volunteers AS
SELECT 
    d.id,
    d.donor_id,
    d.full_name,
    d.email,
    d.total_donations,
    d.amount_grade_state,
    v.total_hours,
    v.skills,
    v.volunteer_since
FROM donors d
INNER JOIN volunteers v ON d.id = v.donor_id
WHERE 
    d.total_donations > 0
    AND v.active = TRUE
ORDER BY d.total_donations DESC, v.total_hours DESC;

-- View: Campaign Performance Summary
CREATE OR REPLACE VIEW v_campaign_performance AS
SELECT 
    c.id,
    c.campaign_id,
    c.name,
    c.campaign_type,
    c.status,
    c.start_date,
    c.end_date,
    c.target_amount,
    c.total_raised,
    c.target_donor_count,
    c.total_donors,
    COUNT(ct.id) as total_targets,
    SUM(CASE WHEN ct.contacted THEN 1 ELSE 0 END) as contacted_count,
    SUM(CASE WHEN ct.responded THEN 1 ELSE 0 END) as responded_count,
    SUM(CASE WHEN ct.donated THEN 1 ELSE 0 END) as donated_count,
    CASE 
        WHEN COUNT(ct.id) > 0 
        THEN ROUND(100.0 * SUM(CASE WHEN ct.responded THEN 1 ELSE 0 END) / COUNT(ct.id), 2)
        ELSE 0 
    END as response_rate,
    CASE 
        WHEN c.target_amount > 0 
        THEN ROUND(100.0 * c.total_raised / c.target_amount, 2)
        ELSE 0 
    END as goal_progress
FROM campaigns c
LEFT JOIN campaign_targets ct ON c.id = ct.campaign_id
GROUP BY c.id, c.campaign_id, c.name, c.campaign_type, c.status, 
         c.start_date, c.end_date, c.target_amount, c.total_raised,
         c.target_donor_count, c.total_donors;

-- View: Donor Full Profile (comprehensive view)
CREATE OR REPLACE VIEW v_donor_full_profile AS
SELECT 
    d.*,
    COUNT(DISTINCT dn.id) as actual_donation_count,
    SUM(dn.amount) as actual_total_donations,
    MAX(dn.donation_date) as actual_last_donation,
    COUNT(DISTINCT ct.campaign_id) as campaigns_targeted,
    COUNT(DISTINCT CASE WHEN ct.donated THEN ct.campaign_id END) as campaigns_donated,
    COUNT(DISTINCT ea.event_id) as events_registered,
    COUNT(DISTINCT CASE WHEN ea.attended THEN ea.event_id END) as events_attended,
    v.id as volunteer_id,
    v.total_hours as volunteer_hours
FROM donors d
LEFT JOIN donations dn ON d.id = dn.donor_id
LEFT JOIN campaign_targets ct ON d.id = ct.donor_id
LEFT JOIN event_attendance ea ON d.id = ea.donor_id
LEFT JOIN volunteers v ON d.id = v.donor_id
GROUP BY d.id, v.id, v.total_hours;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function: Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate days since last donation and lapsed status
CREATE OR REPLACE FUNCTION update_days_since_last_donation()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.last_donation IS NOT NULL THEN
        NEW.days_since_last_donation := CURRENT_DATE - NEW.last_donation;
        NEW.lapsed_donor := (NEW.days_since_last_donation > 730);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function: Get top donors by grade
CREATE OR REPLACE FUNCTION get_top_donors(
    grade_filter donor_grade DEFAULT NULL,
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE (
    donor_id VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    total_donations DECIMAL,
    amount_grade_state donor_grade,
    grade_3d VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.donor_id,
        d.full_name,
        d.email,
        d.total_donations,
        d.amount_grade_state,
        d.grade_3d
    FROM donors d
    WHERE 
        (grade_filter IS NULL OR d.amount_grade_state = grade_filter)
        AND d.do_not_contact = FALSE
    ORDER BY d.total_donations DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate campaign ROI
CREATE OR REPLACE FUNCTION calculate_campaign_roi(campaign_uuid UUID)
RETURNS TABLE (
    campaign_name VARCHAR,
    total_cost DECIMAL,
    total_raised DECIMAL,
    roi_percentage DECIMAL,
    donors_targeted INTEGER,
    donors_donated INTEGER,
    conversion_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.name::VARCHAR,
        SUM(cl.cost)::DECIMAL as total_cost,
        c.total_raised::DECIMAL,
        CASE 
            WHEN SUM(cl.cost) > 0 
            THEN ROUND((c.total_raised / SUM(cl.cost) - 1) * 100, 2)
            ELSE 0 
        END::DECIMAL as roi_percentage,
        COUNT(DISTINCT ct.donor_id)::INTEGER as donors_targeted,
        COUNT(DISTINCT CASE WHEN ct.donated THEN ct.donor_id END)::INTEGER as donors_donated,
        CASE 
            WHEN COUNT(DISTINCT ct.donor_id) > 0 
            THEN ROUND(100.0 * COUNT(DISTINCT CASE WHEN ct.donated THEN ct.donor_id END) / COUNT(DISTINCT ct.donor_id), 2)
            ELSE 0 
        END::DECIMAL as conversion_rate
    FROM campaigns c
    LEFT JOIN campaign_targets ct ON c.id = ct.campaign_id
    LEFT JOIN communication_log cl ON c.id = cl.campaign_id
    WHERE c.id = campaign_uuid
    GROUP BY c.name, c.total_raised;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger: Auto-update donors.updated_at
CREATE TRIGGER update_donors_updated_at 
    BEFORE UPDATE ON donors
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update campaigns.updated_at
CREATE TRIGGER update_campaigns_updated_at 
    BEFORE UPDATE ON campaigns
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update volunteers.updated_at
CREATE TRIGGER update_volunteers_updated_at 
    BEFORE UPDATE ON volunteers
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-calculate days since last donation
CREATE TRIGGER calculate_days_since_donation 
    BEFORE INSERT OR UPDATE ON donors
    FOR EACH ROW 
    EXECUTE FUNCTION update_days_since_last_donation();

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA broyhillgop TO anon, authenticated, service_role;

-- Grant table permissions
GRANT ALL ON ALL TABLES IN SCHEMA broyhillgop TO authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA broyhillgop TO anon;

-- Grant sequence permissions
GRANT USAGE ON ALL SEQUENCES IN SCHEMA broyhillgop TO authenticated, service_role;

-- Grant function permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA broyhillgop TO authenticated, service_role;

-- ============================================================================
-- FINAL SUCCESS MESSAGE
-- ============================================================================

DO $$
DECLARE
    table_count INTEGER;
    index_count INTEGER;
    view_count INTEGER;
    function_count INTEGER;
    trigger_count INTEGER;
BEGIN
    -- Count objects
    SELECT COUNT(*) INTO table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'broyhillgop';
    
    SELECT COUNT(*) INTO index_count 
    FROM pg_indexes 
    WHERE schemaname = 'broyhillgop';
    
    SELECT COUNT(*) INTO view_count 
    FROM information_schema.views 
    WHERE table_schema = 'broyhillgop';
    
    SELECT COUNT(*) INTO function_count 
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'broyhillgop';
    
    SELECT COUNT(*) INTO trigger_count 
    FROM information_schema.triggers 
    WHERE trigger_schema = 'broyhillgop';
    
    -- Display success message
    RAISE NOTICE '============================================================';
    RAISE NOTICE '🎉 BROYHILLGOP DEPLOYMENT COMPLETE! 🎉';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Successfully created:';
    RAISE NOTICE '  ✓ Tables: % ', table_count;
    RAISE NOTICE '  ✓ Indexes: %', index_count;
    RAISE NOTICE '  ✓ Views: %', view_count;
    RAISE NOTICE '  ✓ Functions: %', function_count;
    RAISE NOTICE '  ✓ Triggers: %', trigger_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Import your donor data';
    RAISE NOTICE '  2. Calculate 3D grades';
    RAISE NOTICE '  3. Run ML clustering';
    RAISE NOTICE '  4. Configure web portals';
    RAISE NOTICE '';
    RAISE NOTICE 'Your $150,000+ donor intelligence platform is ready!';
    RAISE NOTICE '============================================================';
END $$;
