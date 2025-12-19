-- ============================================================================
-- BROYHILLGOP DEPLOYMENT - CHUNK 3 (FIXED FOR SUPABASE)
-- Final Tables + Views + Functions
-- ============================================================================
-- 
-- FIXED: Uses gen_random_uuid() instead of uuid_generate_v4()
-- 
-- INSTRUCTIONS:
-- 1. Make sure CHUNK_1_FIXED.sql and CHUNK_2_FIXED.sql completed successfully
-- 2. Copy from line 13 below to the end
-- 3. Paste into Supabase SQL Editor (new query)
-- 4. Click "Run"
-- 5. Deployment complete! 🎉
-- ============================================================================

-- Volunteers table
CREATE TABLE broyhillgop.volunteers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES broyhillgop.donors(id) ON DELETE SET NULL,
    
    first_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    
    volunteer_since DATE,
    total_hours DECIMAL(8,2) DEFAULT 0,
    last_volunteer_date DATE,
    
    skills TEXT[],
    availability TEXT,
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    notes TEXT
);

CREATE INDEX idx_volunteers_donor ON broyhillgop.volunteers(donor_id);
CREATE INDEX idx_volunteers_active ON broyhillgop.volunteers(active);

-- Events table
CREATE TABLE broyhillgop.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id VARCHAR(50) UNIQUE NOT NULL,
    
    name VARCHAR(200) NOT NULL,
    description TEXT,
    event_type VARCHAR(50),
    
    event_date DATE NOT NULL,
    event_time TIME,
    location VARCHAR(255),
    
    capacity INTEGER,
    registered_count INTEGER DEFAULT 0,
    attended_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT now(),
    created_by VARCHAR(100)
);

CREATE INDEX idx_events_date ON broyhillgop.events(event_date);
CREATE INDEX idx_events_type ON broyhillgop.events(event_type);

-- Event attendance table
CREATE TABLE broyhillgop.event_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES broyhillgop.events(id) ON DELETE CASCADE,
    donor_id UUID REFERENCES broyhillgop.donors(id) ON DELETE CASCADE,
    
    registered BOOLEAN DEFAULT TRUE,
    attended BOOLEAN DEFAULT FALSE,
    
    registered_at TIMESTAMP DEFAULT now(),
    checked_in_at TIMESTAMP,
    
    UNIQUE(event_id, donor_id)
);

CREATE INDEX idx_attendance_event ON broyhillgop.event_attendance(event_id);
CREATE INDEX idx_attendance_donor ON broyhillgop.event_attendance(donor_id);

-- Enrichment history table
CREATE TABLE broyhillgop.enrichment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES broyhillgop.donors(id) ON DELETE CASCADE,
    
    enrichment_type VARCHAR(50) NOT NULL,
    enrichment_source VARCHAR(100),
    fields_updated TEXT[],
    
    enriched_at TIMESTAMP DEFAULT now(),
    enriched_by VARCHAR(100)
);

CREATE INDEX idx_enrichment_donor ON broyhillgop.enrichment_history(donor_id);

-- Verification history table
CREATE TABLE broyhillgop.verification_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES broyhillgop.donors(id) ON DELETE CASCADE,
    
    verification_type VARCHAR(50) NOT NULL,
    field_verified VARCHAR(50),
    status VARCHAR(20) CHECK (status IN ('VERIFIED', 'FAILED', 'PENDING')),
    
    verified_at TIMESTAMP DEFAULT now(),
    verified_by VARCHAR(100),
    notes TEXT
);

CREATE INDEX idx_verification_donor ON broyhillgop.verification_history(donor_id);

-- Trigger for volunteers.updated_at
CREATE TRIGGER trigger_volunteers_updated_at
    BEFORE UPDATE ON broyhillgop.volunteers
    FOR EACH ROW
    EXECUTE FUNCTION broyhillgop.update_updated_at();

-- ============================================================================
-- ANALYTICAL VIEWS
-- ============================================================================

-- View: High-Value Prospects
CREATE OR REPLACE VIEW broyhillgop.v_high_value_prospects AS
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
    d.last_contacted
FROM broyhillgop.donors d
WHERE 
    d.amount_grade_state IN ('A++', 'A+', 'A', 'A-')
    AND d.lapsed_donor = FALSE
    AND (d.do_not_contact = FALSE OR d.do_not_contact IS NULL)
ORDER BY d.total_donations DESC;

-- View: Active Volunteers
CREATE OR REPLACE VIEW broyhillgop.v_active_volunteers AS
SELECT 
    v.id,
    v.first_name,
    v.last_name,
    v.email,
    v.phone,
    v.volunteer_since,
    v.total_hours,
    d.donor_id,
    d.total_donations,
    d.amount_grade_state
FROM broyhillgop.volunteers v
LEFT JOIN broyhillgop.donors d ON v.donor_id = d.id
WHERE v.active = TRUE
ORDER BY v.total_hours DESC;

-- View: Campaign Performance
CREATE OR REPLACE VIEW broyhillgop.v_campaign_performance AS
SELECT 
    c.id,
    c.campaign_id,
    c.name,
    c.status,
    c.target_amount,
    c.total_raised,
    COUNT(ct.id) as total_targets,
    SUM(CASE WHEN ct.contacted THEN 1 ELSE 0 END) as contacted_count,
    SUM(CASE WHEN ct.responded THEN 1 ELSE 0 END) as responded_count,
    SUM(CASE WHEN ct.donated THEN 1 ELSE 0 END) as donated_count,
    CASE 
        WHEN COUNT(ct.id) > 0 
        THEN ROUND(100.0 * SUM(CASE WHEN ct.responded THEN 1 ELSE 0 END) / COUNT(ct.id), 2)
        ELSE 0 
    END as response_rate
FROM broyhillgop.campaigns c
LEFT JOIN broyhillgop.campaign_targets ct ON c.id = ct.campaign_id
GROUP BY c.id;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function: Get top donors
CREATE OR REPLACE FUNCTION broyhillgop.get_top_donors(
    grade_filter broyhillgop.donor_grade DEFAULT NULL,
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE (
    donor_id VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    total_donations DECIMAL,
    amount_grade_state broyhillgop.donor_grade,
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
    FROM broyhillgop.donors d
    WHERE 
        (grade_filter IS NULL OR d.amount_grade_state = grade_filter)
        AND (d.do_not_contact = FALSE OR d.do_not_contact IS NULL)
    ORDER BY d.total_donations DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate campaign ROI
CREATE OR REPLACE FUNCTION broyhillgop.calculate_campaign_roi(campaign_uuid UUID)
RETURNS TABLE (
    campaign_name VARCHAR,
    total_cost DECIMAL,
    total_raised DECIMAL,
    roi_percentage DECIMAL,
    donors_targeted INTEGER,
    donors_donated INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.name::VARCHAR,
        COALESCE(SUM(cl.cost), 0)::DECIMAL as total_cost,
        c.total_raised::DECIMAL,
        CASE 
            WHEN SUM(cl.cost) > 0 
            THEN ROUND((c.total_raised / SUM(cl.cost) - 1) * 100, 2)
            ELSE 0 
        END::DECIMAL as roi_percentage,
        COUNT(DISTINCT ct.donor_id)::INTEGER as donors_targeted,
        COUNT(DISTINCT CASE WHEN ct.donated THEN ct.donor_id END)::INTEGER as donors_donated
    FROM broyhillgop.campaigns c
    LEFT JOIN broyhillgop.campaign_targets ct ON c.id = ct.campaign_id
    LEFT JOIN broyhillgop.communication_log cl ON c.id = cl.campaign_id
    WHERE c.id = campaign_uuid
    GROUP BY c.name, c.total_raised;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON SCHEMA broyhillgop TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA broyhillgop TO authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA broyhillgop TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA broyhillgop TO authenticated, service_role;

-- ============================================================================
-- FINAL SUCCESS MESSAGE
-- ============================================================================

DO $$
DECLARE
    table_count INTEGER;
    view_count INTEGER;
    function_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'broyhillgop';
    
    SELECT COUNT(*) INTO view_count 
    FROM information_schema.views 
    WHERE table_schema = 'broyhillgop';
    
    SELECT COUNT(*) INTO function_count 
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'broyhillgop';
    
    RAISE NOTICE '============================================================';
    RAISE NOTICE '🎉 BROYHILLGOP DEPLOYMENT COMPLETE! 🎉';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Successfully created:';
    RAISE NOTICE '  ✓ Tables: %', table_count;
    RAISE NOTICE '  ✓ Views: %', view_count;
    RAISE NOTICE '  ✓ Functions: %', function_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Your $150,000+ donor intelligence platform is ready!';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Import your donor data';
    RAISE NOTICE '  2. Configure Python scripts';
    RAISE NOTICE '  3. Set up web portals';
    RAISE NOTICE '============================================================';
END $$;
