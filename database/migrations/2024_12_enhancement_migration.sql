-- ============================================================================
-- BROYHILLGOP DECEMBER 2024 ENHANCEMENT MIGRATION
-- Triple Grading + Office Context + Cultivation Intelligence + Event Timing
-- ============================================================================
-- Run this migration to add all new features
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 1: TRIPLE GRADING SCHEMA
-- ============================================================================

-- Add district columns to persons table
ALTER TABLE persons ADD COLUMN IF NOT EXISTS district_state_house VARCHAR(10);
ALTER TABLE persons ADD COLUMN IF NOT EXISTS district_state_senate VARCHAR(10);
ALTER TABLE persons ADD COLUMN IF NOT EXISTS district_us_house VARCHAR(10);
ALTER TABLE persons ADD COLUMN IF NOT EXISTS district_judicial VARCHAR(20);

ALTER TABLE persons ADD COLUMN IF NOT EXISTS donor_grade_district VARCHAR(3);
ALTER TABLE persons ADD COLUMN IF NOT EXISTS donor_rank_district INTEGER;
ALTER TABLE persons ADD COLUMN IF NOT EXISTS donor_percentile_district DECIMAL(6,3);

-- Indexes for district lookups
CREATE INDEX IF NOT EXISTS idx_persons_district_house ON persons(district_state_house);
CREATE INDEX IF NOT EXISTS idx_persons_district_senate ON persons(district_state_senate);
CREATE INDEX IF NOT EXISTS idx_persons_district_us ON persons(district_us_house);
CREATE INDEX IF NOT EXISTS idx_persons_grade_district ON persons(donor_grade_district);

-- NC Districts lookup table
CREATE TABLE IF NOT EXISTS nc_districts (
    district_id VARCHAR(20) PRIMARY KEY,
    district_type VARCHAR(20) NOT NULL,
    district_number INTEGER,
    district_name VARCHAR(255),
    counties_covered JSONB DEFAULT '[]',
    representative_name VARCHAR(255),
    representative_party VARCHAR(20),
    total_donors INTEGER DEFAULT 0,
    total_donation_value DECIMAL(14,2) DEFAULT 0,
    avg_donation DECIMAL(10,2) DEFAULT 0,
    last_calculated TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert NC State House Districts (120)
INSERT INTO nc_districts (district_id, district_type, district_number, district_name)
SELECT 
    'HD-' || LPAD(n::text, 3, '0'),
    'state_house',
    n,
    'NC House District ' || n
FROM generate_series(1, 120) n
ON CONFLICT (district_id) DO NOTHING;

-- Insert NC State Senate Districts (50)
INSERT INTO nc_districts (district_id, district_type, district_number, district_name)
SELECT 
    'SD-' || LPAD(n::text, 2, '0'),
    'state_senate',
    n,
    'NC Senate District ' || n
FROM generate_series(1, 50) n
ON CONFLICT (district_id) DO NOTHING;

-- Insert US Congressional Districts (14)
INSERT INTO nc_districts (district_id, district_type, district_number, district_name)
SELECT 
    'CD-' || LPAD(n::text, 2, '0'),
    'us_house',
    n,
    'NC Congressional District ' || n
FROM generate_series(1, 14) n
ON CONFLICT (district_id) DO NOTHING;


-- ============================================================================
-- PART 2: OFFICE CONTEXT MAPPING
-- ============================================================================

CREATE TABLE IF NOT EXISTS nc_office_types (
    office_type VARCHAR(50) PRIMARY KEY,
    office_name VARCHAR(255) NOT NULL,
    office_category VARCHAR(50) NOT NULL,
    grade_context VARCHAR(20) NOT NULL DEFAULT 'county',
    is_statewide BOOLEAN DEFAULT FALSE,
    election_cycle INTEGER DEFAULT 4,
    filing_fee DECIMAL(10,2),
    max_contribution DECIMAL(10,2) DEFAULT 6400,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert all NC office types with grade context
INSERT INTO nc_office_types (office_type, office_name, office_category, grade_context, is_statewide) VALUES
-- Federal
('us_senate', 'US Senate', 'federal', 'state', TRUE),
('us_house', 'US House of Representatives', 'federal', 'district', FALSE),

-- NC Council of State
('governor', 'Governor', 'council_of_state', 'state', TRUE),
('lt_governor', 'Lieutenant Governor', 'council_of_state', 'state', TRUE),
('attorney_general', 'Attorney General', 'council_of_state', 'state', TRUE),
('secretary_of_state', 'Secretary of State', 'council_of_state', 'state', TRUE),
('state_auditor', 'State Auditor', 'council_of_state', 'state', TRUE),
('state_treasurer', 'State Treasurer', 'council_of_state', 'state', TRUE),
('superintendent_public_instruction', 'Superintendent of Public Instruction', 'council_of_state', 'state', TRUE),
('commissioner_agriculture', 'Commissioner of Agriculture', 'council_of_state', 'state', TRUE),
('commissioner_insurance', 'Commissioner of Insurance', 'council_of_state', 'state', TRUE),
('commissioner_labor', 'Commissioner of Labor', 'council_of_state', 'state', TRUE),

-- NC General Assembly
('state_senate', 'NC State Senate', 'general_assembly', 'district', FALSE),
('state_house', 'NC State House', 'general_assembly', 'district', FALSE),

-- Judicial Statewide
('nc_supreme_court', 'NC Supreme Court', 'judicial', 'state', TRUE),
('nc_court_of_appeals', 'NC Court of Appeals', 'judicial', 'state', TRUE),

-- Judicial District
('superior_court', 'Superior Court Judge', 'judicial', 'district', FALSE),
('district_court', 'District Court Judge', 'judicial', 'district', FALSE),

-- County
('county_commissioner', 'County Commissioner', 'county', 'county', FALSE),
('sheriff', 'Sheriff', 'county', 'county', FALSE),
('register_of_deeds', 'Register of Deeds', 'county', 'county', FALSE),
('clerk_of_court', 'Clerk of Superior Court', 'county', 'county', FALSE),

-- Municipal
('mayor', 'Mayor', 'municipal', 'county', FALSE),
('city_council', 'City Council', 'municipal', 'county', FALSE),
('town_board', 'Town Board', 'municipal', 'county', FALSE),

-- Local Boards
('school_board', 'School Board', 'local_board', 'county', FALSE),
('soil_water_conservation', 'Soil & Water Conservation', 'local_board', 'county', FALSE)

ON CONFLICT (office_type) DO UPDATE SET
    grade_context = EXCLUDED.grade_context,
    is_statewide = EXCLUDED.is_statewide;


-- ============================================================================
-- PART 3: DONATION MENU MAPPING
-- ============================================================================

CREATE TABLE IF NOT EXISTS donation_menu_levels (
    level_id SERIAL PRIMARY KEY,
    amount DECIMAL(10,2) NOT NULL,
    level_name VARCHAR(100),
    grades_targeted VARCHAR(50)[], -- Array of grades that map to this level
    display_order INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO donation_menu_levels (amount, level_name, grades_targeted, display_order) VALUES
(6800, 'Leadership Circle', ARRAY['A++'], 1),
(5000, 'Chairman''s Club', ARRAY['A+'], 2),
(2500, 'Patriot Level', ARRAY['A', 'A-'], 3),
(1000, 'Founder Level', ARRAY['B+', 'B'], 4),
(500, 'Supporter Level', ARRAY['B-', 'C+'], 5),
(100, 'Friend Level', ARRAY['C', 'C-', 'D+', 'D', 'D-', 'U'], 6)
ON CONFLICT DO NOTHING;


-- ============================================================================
-- PART 4: CULTIVATION INTELLIGENCE TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS microsegment_performance (
    segment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_definition JSONB NOT NULL,
    candidate_id UUID,
    
    -- Investment tracking
    total_invested DECIMAL(12,2) DEFAULT 0,
    investment_period_start DATE,
    investment_period_end DATE,
    
    -- Results
    total_revenue DECIMAL(14,2) DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    donations_count INTEGER DEFAULT 0,
    
    -- Engagement metrics
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    sms_sent INTEGER DEFAULT 0,
    sms_replied INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    calls_connected INTEGER DEFAULT 0,
    mail_sent INTEGER DEFAULT 0,
    mail_responded INTEGER DEFAULT 0,
    
    -- Calculated metrics (updated by trigger)
    roi DECIMAL(10,4),
    open_rate DECIMAL(6,4),
    click_rate DECIMAL(6,4),
    conversion_rate DECIMAL(6,4),
    cost_per_conversion DECIMAL(10,2),
    
    -- AI strategy
    current_strategy VARCHAR(50) DEFAULT 'testing',
    investment_modifier DECIMAL(4,2) DEFAULT 1.0,
    last_strategy_update TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_microsegment_candidate ON microsegment_performance(candidate_id);
CREATE INDEX IF NOT EXISTS idx_microsegment_strategy ON microsegment_performance(current_strategy);
CREATE INDEX IF NOT EXISTS idx_microsegment_roi ON microsegment_performance(roi DESC);

-- Function to update calculated metrics
CREATE OR REPLACE FUNCTION update_microsegment_metrics()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate ROI
    IF NEW.total_invested > 0 THEN
        NEW.roi := (NEW.total_revenue - NEW.total_invested) / NEW.total_invested;
    ELSE
        NEW.roi := 0;
    END IF;
    
    -- Calculate rates
    IF NEW.emails_sent > 0 THEN
        NEW.open_rate := NEW.emails_opened::DECIMAL / NEW.emails_sent;
        NEW.click_rate := NEW.emails_clicked::DECIMAL / NEW.emails_sent;
        NEW.conversion_rate := NEW.conversions::DECIMAL / NEW.emails_sent;
    END IF;
    
    -- Cost per conversion
    IF NEW.conversions > 0 THEN
        NEW.cost_per_conversion := NEW.total_invested / NEW.conversions;
    END IF;
    
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_microsegment_metrics ON microsegment_performance;
CREATE TRIGGER trg_update_microsegment_metrics
    BEFORE INSERT OR UPDATE ON microsegment_performance
    FOR EACH ROW EXECUTE FUNCTION update_microsegment_metrics();


-- ============================================================================
-- PART 5: EVENT TIMING DISCIPLINE
-- ============================================================================

-- Add event phase tracking
ALTER TABLE events ADD COLUMN IF NOT EXISTS current_phase VARCHAR(50) DEFAULT 'planning';
ALTER TABLE events ADD COLUMN IF NOT EXISTS undersell_recovery_activated BOOLEAN DEFAULT FALSE;
ALTER TABLE events ADD COLUMN IF NOT EXISTS volunteer_invites_sent INTEGER DEFAULT 0;
ALTER TABLE events ADD COLUMN IF NOT EXISTS sold_seats INTEGER DEFAULT 0;
ALTER TABLE events ADD COLUMN IF NOT EXISTS comped_seats INTEGER DEFAULT 0;
ALTER TABLE events ADD COLUMN IF NOT EXISTS fill_rate DECIMAL(5,2) DEFAULT 0;

-- Volunteer grades table
CREATE TABLE IF NOT EXISTS volunteer_grades (
    volunteer_id UUID PRIMARY KEY,
    person_id UUID REFERENCES persons(id),
    candidate_id UUID,
    
    -- V-Grade
    v_grade VARCHAR(10) DEFAULT 'V-U',
    v_rank INTEGER,
    
    -- Activity metrics
    hours_logged DECIMAL(10,2) DEFAULT 0,
    shifts_completed INTEGER DEFAULT 0,
    events_attended INTEGER DEFAULT 0,
    events_hosted INTEGER DEFAULT 0,
    
    -- Conversion tracking (volunteer → donor)
    has_donated BOOLEAN DEFAULT FALSE,
    first_donation_date DATE,
    total_donated DECIMAL(12,2) DEFAULT 0,
    donation_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_volunteer_grades_grade ON volunteer_grades(v_grade);
CREATE INDEX IF NOT EXISTS idx_volunteer_grades_candidate ON volunteer_grades(candidate_id);

-- Event invitation tracking
CREATE TABLE IF NOT EXISTS event_invitations (
    invitation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL,
    person_id UUID NOT NULL,
    
    -- Invitation details
    invitation_type VARCHAR(20) NOT NULL, -- 'paid', 'free', 'comp'
    audience_source VARCHAR(20) NOT NULL, -- 'donor_file', 'volunteer_file'
    
    -- Timing
    sent_at TIMESTAMP DEFAULT NOW(),
    event_phase VARCHAR(50),
    days_before_event INTEGER,
    
    -- Grade at time of invitation
    donor_grade_used VARCHAR(3),
    grade_context VARCHAR(20), -- 'state', 'district', 'county'
    ask_amount DECIMAL(10,2),
    
    -- Response
    response VARCHAR(20), -- 'accepted', 'declined', 'no_response'
    response_at TIMESTAMP,
    amount_paid DECIMAL(10,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_invitations_event ON event_invitations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_invitations_person ON event_invitations(person_id);
CREATE INDEX IF NOT EXISTS idx_event_invitations_type ON event_invitations(invitation_type);


-- ============================================================================
-- PART 6: SPECIAL GUEST MULTIPLIERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS special_guest_types (
    guest_type VARCHAR(50) PRIMARY KEY,
    guest_title VARCHAR(255),
    multiplier DECIMAL(4,2) NOT NULL,
    description TEXT,
    typical_fee_range JSONB, -- {'min': 0, 'max': 50000}
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO special_guest_types (guest_type, guest_title, multiplier, description) VALUES
('us_senator', 'US Senator', 4.0, 'Current US Senator - highest draw'),
('governor', 'Governor', 3.5, 'Current or Former Governor'),
('us_congressman', 'US Congressman', 2.5, 'Current US House Member'),
('state_speaker', 'Speaker of the House', 2.0, 'NC House Speaker'),
('lt_governor', 'Lieutenant Governor', 2.0, 'Current Lt. Governor'),
('celebrity', 'Celebrity', 2.0, 'Notable celebrity endorser'),
('state_senate_leader', 'Senate Leader', 1.5, 'NC Senate Pro Tem or Leader'),
('state_senator', 'State Senator', 1.3, 'NC State Senator'),
('state_house_leader', 'House Leader', 1.3, 'NC House Majority/Minority Leader'),
('former_governor', 'Former Governor', 1.5, 'Former NC Governor'),
('former_senator', 'Former Senator', 1.3, 'Former US Senator')
ON CONFLICT (guest_type) DO UPDATE SET multiplier = EXCLUDED.multiplier;


-- ============================================================================
-- PART 7: CAMPAIGN WIZARD ENHANCEMENTS
-- ============================================================================

-- Add new columns to campaigns table
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS office_type VARCHAR(50);
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS grade_context VARCHAR(20) DEFAULT 'county';
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS special_guest_type VARCHAR(50);
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS special_guest_name VARCHAR(255);
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS capacity_multiplier DECIMAL(4,2) DEFAULT 1.0;
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS realistic_capacity DECIMAL(14,2);
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS requires_special_guest BOOLEAN DEFAULT FALSE;

-- Campaign audience with contextual grading
CREATE TABLE IF NOT EXISTS campaign_audience_grades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL,
    person_id UUID NOT NULL,
    
    -- Grade used for this campaign
    grade_context VARCHAR(20) NOT NULL,
    contextual_grade VARCHAR(3) NOT NULL,
    contextual_rank INTEGER,
    
    -- Donation level assigned
    donation_menu_level INTEGER,
    ask_amount DECIMAL(10,2),
    
    -- Status
    invitation_sent BOOLEAN DEFAULT FALSE,
    invitation_sent_at TIMESTAMP,
    response VARCHAR(20),
    amount_donated DECIMAL(10,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_campaign_audience_campaign ON campaign_audience_grades(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_audience_grade ON campaign_audience_grades(contextual_grade);


-- ============================================================================
-- PART 8: VIEWS FOR REPORTING
-- ============================================================================

-- Triple grade view
CREATE OR REPLACE VIEW v_donor_triple_grades AS
SELECT 
    p.id,
    p.full_name,
    p.email,
    p.county,
    p.district_state_house,
    p.district_state_senate,
    p.district_us_house,
    p.donation_total,
    p.donor_grade_state,
    p.donor_rank_state,
    p.donor_grade_district,
    p.donor_rank_district,
    p.donor_grade_county,
    p.donor_rank_county,
    CASE 
        WHEN p.donor_grade_state != p.donor_grade_county THEN TRUE
        ELSE FALSE
    END as grades_differ
FROM persons p
WHERE p.is_donor = TRUE;

-- District summary view
CREATE OR REPLACE VIEW v_district_summary AS
SELECT 
    d.district_id,
    d.district_type,
    d.district_name,
    d.representative_name,
    COUNT(p.id) as total_donors,
    SUM(p.donation_total) as total_donations,
    AVG(p.donation_total) as avg_donation,
    COUNT(p.id) FILTER (WHERE p.donor_grade_district IN ('A++', 'A+', 'A', 'A-')) as a_tier_donors,
    COUNT(p.id) FILTER (WHERE p.donor_grade_district = 'U') as unknown_donors
FROM nc_districts d
LEFT JOIN persons p ON p.district_state_house = d.district_id 
    OR p.district_state_senate = d.district_id
    OR p.district_us_house = d.district_id
GROUP BY d.district_id, d.district_type, d.district_name, d.representative_name;

-- Microsegment performance view
CREATE OR REPLACE VIEW v_microsegment_performance AS
SELECT 
    segment_id,
    segment_definition,
    total_invested,
    total_revenue,
    roi,
    conversions,
    open_rate,
    conversion_rate,
    current_strategy,
    investment_modifier,
    CASE 
        WHEN roi >= 5.0 THEN 'excellent'
        WHEN roi >= 2.0 THEN 'good'
        WHEN roi >= 1.0 THEN 'acceptable'
        WHEN roi >= 0.0 THEN 'poor'
        ELSE 'negative'
    END as performance_tier
FROM microsegment_performance
ORDER BY roi DESC;

-- Event timing view
CREATE OR REPLACE VIEW v_event_timing_status AS
SELECT 
    e.event_id,
    e.name,
    e.event_date,
    e.capacity,
    e.sold_seats,
    e.comped_seats,
    e.fill_rate,
    e.current_phase,
    e.undersell_recovery_activated,
    EXTRACT(DAY FROM e.event_date - NOW()) as days_until_event,
    CASE 
        WHEN EXTRACT(DAY FROM e.event_date - NOW()) > 4 THEN 'paid_solicitation'
        WHEN EXTRACT(DAY FROM e.event_date - NOW()) BETWEEN 1 AND 4 THEN 'undersell_recovery'
        WHEN EXTRACT(DAY FROM e.event_date - NOW()) = 0 THEN 'event_day'
        ELSE 'post_event'
    END as calculated_phase,
    CASE 
        WHEN e.fill_rate < 0.80 THEN TRUE
        ELSE FALSE
    END as is_undersold
FROM events e
WHERE e.event_date >= CURRENT_DATE - INTERVAL '7 days';


-- ============================================================================
-- PART 9: FUNCTIONS
-- ============================================================================

-- Function to get contextual grade for a donor based on office type
CREATE OR REPLACE FUNCTION get_contextual_grade(
    p_person_id UUID,
    p_office_type VARCHAR(50)
) RETURNS TABLE (
    grade VARCHAR(3),
    rank INTEGER,
    context VARCHAR(20)
) AS $$
DECLARE
    v_context VARCHAR(20);
BEGIN
    -- Get grade context for this office type
    SELECT ot.grade_context INTO v_context
    FROM nc_office_types ot
    WHERE ot.office_type = p_office_type;
    
    -- Default to county if not found
    IF v_context IS NULL THEN
        v_context := 'county';
    END IF;
    
    -- Return appropriate grade
    RETURN QUERY
    SELECT 
        CASE v_context
            WHEN 'state' THEN p.donor_grade_state
            WHEN 'district' THEN COALESCE(p.donor_grade_district, p.donor_grade_county)
            ELSE p.donor_grade_county
        END as grade,
        CASE v_context
            WHEN 'state' THEN p.donor_rank_state
            WHEN 'district' THEN COALESCE(p.donor_rank_district, p.donor_rank_county)
            ELSE p.donor_rank_county
        END as rank,
        v_context as context
    FROM persons p
    WHERE p.id = p_person_id;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate realistic event capacity
CREATE OR REPLACE FUNCTION calculate_event_capacity(
    p_candidate_id UUID,
    p_office_type VARCHAR(50),
    p_special_guest_type VARCHAR(50) DEFAULT NULL
) RETURNS TABLE (
    total_donors INTEGER,
    realistic_max DECIMAL(14,2),
    conservative_estimate DECIMAL(14,2),
    aggressive_estimate DECIMAL(14,2),
    multiplier DECIMAL(4,2),
    requires_guest BOOLEAN
) AS $$
DECLARE
    v_base_capacity DECIMAL(14,2) := 0;
    v_multiplier DECIMAL(4,2) := 1.0;
    v_context VARCHAR(20);
BEGIN
    -- Get grade context
    SELECT ot.grade_context INTO v_context
    FROM nc_office_types ot
    WHERE ot.office_type = p_office_type;
    
    -- Calculate base capacity from donor universe
    SELECT 
        COUNT(*),
        SUM(
            CASE 
                WHEN (CASE v_context 
                    WHEN 'state' THEN p.donor_grade_state
                    WHEN 'district' THEN p.donor_grade_district
                    ELSE p.donor_grade_county
                END) IN ('A++', 'A+') THEN 5000 * 0.30
                WHEN (CASE v_context 
                    WHEN 'state' THEN p.donor_grade_state
                    WHEN 'district' THEN p.donor_grade_district
                    ELSE p.donor_grade_county
                END) IN ('A', 'A-') THEN 1500 * 0.22
                WHEN (CASE v_context 
                    WHEN 'state' THEN p.donor_grade_state
                    WHEN 'district' THEN p.donor_grade_district
                    ELSE p.donor_grade_county
                END) IN ('B+', 'B') THEN 750 * 0.15
                ELSE 100 * 0.05
            END
        )
    INTO total_donors, v_base_capacity
    FROM persons p;
    
    -- Get special guest multiplier
    IF p_special_guest_type IS NOT NULL THEN
        SELECT sg.multiplier INTO v_multiplier
        FROM special_guest_types sg
        WHERE sg.guest_type = p_special_guest_type;
    END IF;
    
    v_multiplier := COALESCE(v_multiplier, 1.0);
    
    RETURN QUERY SELECT
        total_donors,
        ROUND(v_base_capacity * v_multiplier, 2) as realistic_max,
        ROUND(v_base_capacity * v_multiplier * 0.7, 2) as conservative_estimate,
        ROUND(v_base_capacity * v_multiplier * 1.3, 2) as aggressive_estimate,
        v_multiplier as multiplier,
        (v_multiplier > 1.0) as requires_guest;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- PART 10: RECALCULATE DISTRICT GRADES
-- ============================================================================

-- This should be run after district assignments are populated
CREATE OR REPLACE FUNCTION recalculate_district_grades()
RETURNS void AS $$
BEGIN
    -- Calculate district ranks for State House
    WITH ranked AS (
        SELECT id,
               district_state_house,
               ROW_NUMBER() OVER (PARTITION BY district_state_house ORDER BY donation_total DESC NULLS LAST) as rank_district,
               PERCENT_RANK() OVER (PARTITION BY district_state_house ORDER BY donation_total DESC NULLS LAST) as pct_rank
        FROM persons
        WHERE is_donor = TRUE AND donation_total > 0 AND district_state_house IS NOT NULL
    )
    UPDATE persons p
    SET 
        donor_rank_district = r.rank_district,
        donor_percentile_district = ROUND((1 - r.pct_rank) * 100, 3)
    FROM ranked r
    WHERE p.id = r.id;
    
    -- Assign district grades based on percentile
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
    
    -- Set U for non-donors
    UPDATE persons
    SET donor_grade_district = 'U'
    WHERE (is_donor = FALSE OR donation_total IS NULL OR donation_total = 0)
    AND district_state_house IS NOT NULL;
    
    -- Update district statistics
    UPDATE nc_districts d
    SET 
        total_donors = stats.donor_count,
        total_donation_value = stats.total_value,
        avg_donation = stats.avg_value,
        last_calculated = NOW()
    FROM (
        SELECT 
            district_state_house as district_id,
            COUNT(*) as donor_count,
            SUM(donation_total) as total_value,
            AVG(donation_total) as avg_value
        FROM persons
        WHERE is_donor = TRUE AND district_state_house IS NOT NULL
        GROUP BY district_state_house
    ) stats
    WHERE d.district_id = stats.district_id;
END;
$$ LANGUAGE plpgsql;


COMMIT;

-- ============================================================================
-- POST-MIGRATION: Run these after data is populated
-- ============================================================================

-- SELECT recalculate_district_grades();

SELECT 'December 2024 Enhancement Migration Complete!' as status;
