-- ============================================================================
-- CANDIDATE-BASED VOLUNTEER RECRUITMENT MARKETPLACE
-- White-Label System: Issue-Based Matching & Revenue Tracking
-- ============================================================================
-- Created: December 1, 2024
-- Purpose: Match recruited volunteers to paying candidates by issue + geography
-- ============================================================================

-- ============================================================================
-- CANDIDATES TABLE (Your Customers)
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidates (
    id BIGSERIAL PRIMARY KEY,
    candidate_id VARCHAR(50) UNIQUE NOT NULL,
    
    -- Basic Info
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    preferred_name VARCHAR(100),
    
    -- Office/Position
    office_type VARCHAR(50), -- County Commissioner, State House, State Senate, School Board, etc.
    district VARCHAR(50), -- District 22, At-Large, etc.
    county VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, SUSPENDED
    
    -- Geographic Coverage
    coverage_counties TEXT[], -- Array of counties they serve
    coverage_zip_codes TEXT[], -- Specific zip codes
    coverage_cities TEXT[], -- Specific cities
    
    -- Issue Focus (What issues they champion)
    primary_issues TEXT[], -- ['EDUCATION', 'CHRISTIAN_VALUES', '2ND_AMENDMENT', 'PRO_LIFE', 'ECONOMY', etc.]
    issue_intensity_scores JSONB, -- {"EDUCATION": 95, "CHRISTIAN_VALUES": 90, "2ND_AMENDMENT": 75}
    
    -- Contact
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    campaign_website VARCHAR(255),
    
    -- Service Level
    subscription_tier VARCHAR(20) DEFAULT 'BASIC', -- BASIC, PRO, PREMIUM
    monthly_fee NUMERIC(10, 2),
    volunteer_allocation_cap INTEGER, -- Max volunteers they can receive per month
    priority_score INTEGER DEFAULT 50, -- Higher = more volunteers allocated (50-100)
    
    -- Billing
    billing_status VARCHAR(20) DEFAULT 'CURRENT', -- CURRENT, PAST_DUE, SUSPENDED
    last_payment_date DATE,
    next_billing_date DATE,
    
    -- Performance
    volunteers_allocated INTEGER DEFAULT 0,
    volunteers_activated INTEGER DEFAULT 0, -- Actually followed up
    activation_rate NUMERIC(5, 2), -- % of allocated volunteers who become active
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    subscription_start_date DATE,
    subscription_end_date DATE,
    
    CONSTRAINT chk_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    CONSTRAINT chk_subscription_tier CHECK (subscription_tier IN ('BASIC', 'PRO', 'PREMIUM')),
    CONSTRAINT chk_billing_status CHECK (billing_status IN ('CURRENT', 'PAST_DUE', 'SUSPENDED'))
);

-- ============================================================================
-- ISSUES TABLE (Master List of Issues)
-- ============================================================================

CREATE TABLE IF NOT EXISTS issues (
    id BIGSERIAL PRIMARY KEY,
    issue_code VARCHAR(50) UNIQUE NOT NULL,
    issue_name VARCHAR(100) NOT NULL,
    issue_category VARCHAR(50), -- SOCIAL, ECONOMIC, EDUCATION, SECURITY, etc.
    description TEXT,
    keywords TEXT[], -- For matching volunteer scoring factors
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Populate issues
INSERT INTO issues (issue_code, issue_name, issue_category, keywords) VALUES
('EDUCATION', 'Education Freedom / Parental Rights', 'EDUCATION', ARRAY['EDUCATION', 'SCHOOL', 'PARENTAL RIGHTS', 'SCHOOL BOARD', 'CRT', 'TEACHER']),
('CHRISTIAN_VALUES', 'Christian Values / Religious Liberty', 'SOCIAL', ARRAY['CHRISTIAN', 'FAITH', 'CHURCH', 'RELIGIOUS', 'MINISTRY', 'PASTOR']),
('2ND_AMENDMENT', '2nd Amendment / Gun Rights', 'SECURITY', ARRAY['GUN', '2ND AMENDMENT', 'FIREARMS', 'NRA', 'RIFLE']),
('PRO_LIFE', 'Pro-Life / Family Values', 'SOCIAL', ARRAY['PRO LIFE', 'PRO-LIFE', 'ABORTION', 'FAMILY VALUES', 'SANCTITY OF LIFE']),
('TRUMP_MAGA', 'Trump / MAGA / America First', 'POLITICAL', ARRAY['TRUMP', 'MAGA', 'AMERICA FIRST']),
('ECONOMY', 'Economy / Tax Reform', 'ECONOMIC', ARRAY['ECONOMY', 'TAX', 'BUSINESS', 'ENTREPRENEUR', 'SMALL BUSINESS']),
('BORDER_SECURITY', 'Border Security / Immigration', 'SECURITY', ARRAY['BORDER', 'IMMIGRATION', 'ILLEGAL']),
('LAW_ORDER', 'Law & Order / Police Support', 'SECURITY', ARRAY['POLICE', 'LAW ENFORCEMENT', 'CRIME', 'SHERIFF']),
('ELECTION_INTEGRITY', 'Election Integrity', 'POLITICAL', ARRAY['ELECTION', 'VOTING', 'FRAUD', 'INTEGRITY']),
('MEDICAL_FREEDOM', 'Medical Freedom / Health', 'SOCIAL', ARRAY['MEDICAL', 'HEALTH', 'VACCINE', 'FREEDOM'])
ON CONFLICT (issue_code) DO NOTHING;

-- ============================================================================
-- VOLUNTEER ALLOCATIONS TABLE (Track who gets which volunteer)
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteer_allocations (
    id BIGSERIAL PRIMARY KEY,
    
    -- Volunteer Info
    volunteer_donor_id VARCHAR(50), -- If existing donor
    volunteer_email VARCHAR(255) NOT NULL,
    volunteer_name VARCHAR(255),
    volunteer_phone VARCHAR(50),
    volunteer_county VARCHAR(100),
    volunteer_zip VARCHAR(10),
    
    -- How they were recruited
    recruited_via_campaign_id INTEGER, -- Which recruitment campaign
    recruited_via_issue VARCHAR(50), -- Which issue campaign (EDUCATION, etc.)
    recruited_date TIMESTAMPTZ DEFAULT NOW(),
    
    -- Volunteer Profile
    volunteer_probability_score INTEGER,
    volunteer_scoring_factors TEXT,
    issue_match_scores JSONB, -- {"EDUCATION": 90, "CHRISTIAN_VALUES": 75}
    
    -- Allocation
    allocated_to_candidate_id VARCHAR(50) REFERENCES candidates(candidate_id),
    allocation_date TIMESTAMPTZ DEFAULT NOW(),
    allocation_method VARCHAR(50), -- ISSUE_MATCH, GEOGRAPHIC, MANUAL, PRIORITY_BOOST
    match_score INTEGER, -- How good is this match (0-100)
    
    -- Status
    status VARCHAR(20) DEFAULT 'ALLOCATED', -- ALLOCATED, CONTACTED, ACTIVE, INACTIVE, DECLINED
    contacted_by_candidate BOOLEAN DEFAULT FALSE,
    contacted_date TIMESTAMPTZ,
    activated_date TIMESTAMPTZ,
    
    -- Revenue Attribution
    revenue_credited NUMERIC(10, 2), -- Portion of candidate's fee attributed to this volunteer
    
    -- Metadata
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT chk_allocation_status CHECK (status IN ('ALLOCATED', 'CONTACTED', 'ACTIVE', 'INACTIVE', 'DECLINED'))
);

-- ============================================================================
-- RECRUITMENT CAMPAIGNS TABLE (Issue-Based Campaigns)
-- ============================================================================

CREATE TABLE IF NOT EXISTS recruitment_campaigns (
    id BIGSERIAL PRIMARY KEY,
    campaign_id VARCHAR(50) UNIQUE NOT NULL,
    
    -- Campaign Info
    campaign_name VARCHAR(255) NOT NULL,
    campaign_message TEXT, -- "Stop Porn in Schools", "Protect Gun Rights", etc.
    primary_issue VARCHAR(50) REFERENCES issues(issue_code),
    secondary_issues TEXT[], -- Additional issues this campaign addresses
    
    -- Targeting
    target_counties TEXT[],
    target_demographics JSONB, -- Age ranges, etc.
    
    -- Media
    ad_copy TEXT,
    landing_page_url VARCHAR(255),
    creative_assets JSONB, -- Links to images, videos, etc.
    
    -- Budget & Performance
    budget NUMERIC(10, 2),
    cost_per_volunteer NUMERIC(10, 2),
    volunteers_recruited INTEGER DEFAULT 0,
    volunteers_allocated INTEGER DEFAULT 0,
    conversion_rate NUMERIC(5, 2),
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, PAUSED, COMPLETED
    start_date DATE,
    end_date DATE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT chk_campaign_status CHECK (status IN ('ACTIVE', 'PAUSED', 'COMPLETED', 'DRAFT'))
);

-- ============================================================================
-- CANDIDATE BILLING TABLE (Revenue Tracking)
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_billing (
    id BIGSERIAL PRIMARY KEY,
    
    candidate_id VARCHAR(50) REFERENCES candidates(candidate_id),
    
    -- Billing Period
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    
    -- Services
    subscription_fee NUMERIC(10, 2),
    volunteers_allocated INTEGER DEFAULT 0,
    cost_per_volunteer NUMERIC(10, 2),
    volunteer_recruitment_fee NUMERIC(10, 2),
    
    -- Total
    total_amount NUMERIC(10, 2),
    
    -- Payment
    invoice_number VARCHAR(50) UNIQUE,
    invoice_date DATE,
    due_date DATE,
    paid_date DATE,
    payment_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, PAID, PAST_DUE, CANCELED
    payment_method VARCHAR(50),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT chk_payment_status CHECK (payment_status IN ('PENDING', 'PAID', 'PAST_DUE', 'CANCELED', 'REFUNDED'))
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_candidates_county ON candidates(county);
CREATE INDEX idx_candidates_status ON candidates(status) WHERE status = 'ACTIVE';
CREATE INDEX idx_candidates_subscription_tier ON candidates(subscription_tier);
CREATE INDEX idx_candidates_billing_status ON candidates(billing_status);

CREATE INDEX idx_volunteer_alloc_candidate ON volunteer_allocations(allocated_to_candidate_id);
CREATE INDEX idx_volunteer_alloc_status ON volunteer_allocations(status);
CREATE INDEX idx_volunteer_alloc_email ON volunteer_allocations(volunteer_email);
CREATE INDEX idx_volunteer_alloc_date ON volunteer_allocations(allocation_date);
CREATE INDEX idx_volunteer_alloc_issue ON volunteer_allocations(recruited_via_issue);

CREATE INDEX idx_campaigns_status ON recruitment_campaigns(status) WHERE status = 'ACTIVE';
CREATE INDEX idx_campaigns_issue ON recruitment_campaigns(primary_issue);

CREATE INDEX idx_billing_candidate ON candidate_billing(candidate_id);
CREATE INDEX idx_billing_status ON candidate_billing(payment_status);
CREATE INDEX idx_billing_due_date ON candidate_billing(due_date) WHERE payment_status = 'PENDING';

-- ============================================================================
-- VOLUNTEER MATCHING ALGORITHM FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION match_volunteer_to_candidates(
    p_volunteer_email VARCHAR,
    p_volunteer_county VARCHAR,
    p_volunteer_issue_scores JSONB,
    p_recruited_via_issue VARCHAR
)
RETURNS TABLE (
    candidate_id VARCHAR,
    candidate_name VARCHAR,
    match_score INTEGER,
    match_reasons TEXT
) AS $$
DECLARE
    v_candidate RECORD;
    v_match_score INTEGER;
    v_match_reasons TEXT;
    v_issue_match INTEGER;
    v_geo_match INTEGER;
    v_capacity_available BOOLEAN;
BEGIN
    -- Find matching candidates
    FOR v_candidate IN 
        SELECT 
            c.candidate_id,
            c.full_name,
            c.county,
            c.coverage_counties,
            c.primary_issues,
            c.issue_intensity_scores,
            c.volunteer_allocation_cap,
            c.volunteers_allocated,
            c.priority_score,
            c.subscription_tier
        FROM candidates c
        WHERE c.status = 'ACTIVE'
        AND c.billing_status = 'CURRENT'
    LOOP
        v_match_score := 0;
        v_match_reasons := '';
        
        -- 1. GEOGRAPHIC MATCH (40 points)
        v_geo_match := 0;
        IF v_candidate.county = p_volunteer_county THEN
            v_geo_match := 40;
            v_match_reasons := v_match_reasons || 'Same County(40); ';
        ELSIF p_volunteer_county = ANY(v_candidate.coverage_counties) THEN
            v_geo_match := 30;
            v_match_reasons := v_match_reasons || 'Coverage County(30); ';
        ELSE
            v_geo_match := 0;
            v_match_reasons := v_match_reasons || 'Different County(0); ';
        END IF;
        v_match_score := v_match_score + v_geo_match;
        
        -- 2. ISSUE MATCH (40 points)
        v_issue_match := 0;
        IF p_recruited_via_issue = ANY(v_candidate.primary_issues) THEN
            v_issue_match := 40;
            v_match_reasons := v_match_reasons || 'Primary Issue Match(40); ';
        ELSIF v_candidate.issue_intensity_scores ? p_recruited_via_issue THEN
            v_issue_match := (v_candidate.issue_intensity_scores->>p_recruited_via_issue)::INTEGER * 0.3;
            v_match_reasons := v_match_reasons || format('Issue Intensity(%s); ', v_issue_match);
        ELSE
            v_issue_match := 0;
            v_match_reasons := v_match_reasons || 'No Issue Match(0); ';
        END IF;
        v_match_score := v_match_score + v_issue_match;
        
        -- 3. CAPACITY CHECK (Required)
        v_capacity_available := FALSE;
        IF v_candidate.volunteer_allocation_cap IS NULL THEN
            v_capacity_available := TRUE;
        ELSIF v_candidate.volunteers_allocated < v_candidate.volunteer_allocation_cap THEN
            v_capacity_available := TRUE;
        END IF;
        
        IF NOT v_capacity_available THEN
            v_match_reasons := v_match_reasons || 'AT CAPACITY - SKIP; ';
            CONTINUE; -- Skip this candidate
        END IF;
        
        -- 4. PRIORITY BOOST (20 points max)
        v_match_score := v_match_score + (v_candidate.priority_score * 0.2);
        v_match_reasons := v_match_reasons || format('Priority Boost(%s); ', ROUND(v_candidate.priority_score * 0.2));
        
        -- 5. SUBSCRIPTION TIER BOOST (bonus)
        IF v_candidate.subscription_tier = 'PREMIUM' THEN
            v_match_score := v_match_score + 10;
            v_match_reasons := v_match_reasons || 'Premium(+10); ';
        ELSIF v_candidate.subscription_tier = 'PRO' THEN
            v_match_score := v_match_score + 5;
            v_match_reasons := v_match_reasons || 'Pro(+5); ';
        END IF;
        
        -- Return this candidate as a match
        candidate_id := v_candidate.candidate_id;
        candidate_name := v_candidate.full_name;
        match_score := v_match_score;
        match_reasons := v_match_reasons;
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION match_volunteer_to_candidates IS 'Matches a volunteer to candidates based on geography, issue alignment, capacity, and priority';

-- ============================================================================
-- AUTO-ALLOCATE VOLUNTEER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION auto_allocate_volunteer(
    p_volunteer_email VARCHAR,
    p_volunteer_name VARCHAR,
    p_volunteer_county VARCHAR,
    p_recruited_via_issue VARCHAR,
    p_volunteer_scoring_factors TEXT,
    p_campaign_id INTEGER DEFAULT NULL
)
RETURNS VARCHAR AS $$
DECLARE
    v_best_candidate RECORD;
    v_allocation_id INTEGER;
    v_issue_scores JSONB;
BEGIN
    -- Build issue match scores from scoring factors
    v_issue_scores := '{}';
    
    IF p_volunteer_scoring_factors LIKE '%EDUCATION%' THEN
        v_issue_scores := jsonb_set(v_issue_scores, '{EDUCATION}', '90');
    END IF;
    IF p_volunteer_scoring_factors LIKE '%CHRISTIAN%' THEN
        v_issue_scores := jsonb_set(v_issue_scores, '{CHRISTIAN_VALUES}', '85');
    END IF;
    IF p_volunteer_scoring_factors LIKE '%TRUMP%' OR p_volunteer_scoring_factors LIKE '%MAGA%' THEN
        v_issue_scores := jsonb_set(v_issue_scores, '{TRUMP_MAGA}', '95');
    END IF;
    IF p_volunteer_scoring_factors LIKE '%2ND_AMENDMENT%' THEN
        v_issue_scores := jsonb_set(v_issue_scores, '{2ND_AMENDMENT}', '90');
    END IF;
    
    -- Find best matching candidate
    SELECT * INTO v_best_candidate
    FROM match_volunteer_to_candidates(
        p_volunteer_email,
        p_volunteer_county,
        v_issue_scores,
        p_recruited_via_issue
    )
    ORDER BY match_score DESC
    LIMIT 1;
    
    -- If no match found
    IF v_best_candidate IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Create allocation
    INSERT INTO volunteer_allocations (
        volunteer_email,
        volunteer_name,
        volunteer_county,
        recruited_via_campaign_id,
        recruited_via_issue,
        volunteer_scoring_factors,
        issue_match_scores,
        allocated_to_candidate_id,
        allocation_method,
        match_score,
        status
    ) VALUES (
        p_volunteer_email,
        p_volunteer_name,
        p_volunteer_county,
        p_campaign_id,
        p_recruited_via_issue,
        p_volunteer_scoring_factors,
        v_issue_scores,
        v_best_candidate.candidate_id,
        'ISSUE_MATCH',
        v_best_candidate.match_score,
        'ALLOCATED'
    ) RETURNING id INTO v_allocation_id;
    
    -- Update candidate volunteer count
    UPDATE candidates
    SET volunteers_allocated = volunteers_allocated + 1,
        updated_at = NOW()
    WHERE candidate_id = v_best_candidate.candidate_id;
    
    -- Return allocated candidate
    RETURN v_best_candidate.candidate_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION auto_allocate_volunteer IS 'Automatically allocates a volunteer to the best-matching candidate';

-- ============================================================================
-- VIEWS FOR CANDIDATE DASHBOARDS
-- ============================================================================

-- View: Candidate Performance Dashboard
CREATE OR REPLACE VIEW v_candidate_dashboard AS
SELECT 
    c.candidate_id,
    c.full_name,
    c.county,
    c.office_type,
    c.subscription_tier,
    c.volunteers_allocated,
    c.volunteers_activated,
    c.activation_rate,
    c.volunteer_allocation_cap,
    c.billing_status,
    COUNT(va.id) FILTER (WHERE va.status = 'ALLOCATED') as pending_volunteers,
    COUNT(va.id) FILTER (WHERE va.status = 'CONTACTED') as contacted_volunteers,
    COUNT(va.id) FILTER (WHERE va.status = 'ACTIVE') as active_volunteers,
    ROUND(AVG(va.match_score), 2) as avg_match_score
FROM candidates c
LEFT JOIN volunteer_allocations va ON c.candidate_id = va.allocated_to_candidate_id
GROUP BY c.candidate_id, c.full_name, c.county, c.office_type, c.subscription_tier,
         c.volunteers_allocated, c.volunteers_activated, c.activation_rate,
         c.volunteer_allocation_cap, c.billing_status;

-- View: Revenue Summary
CREATE OR REPLACE VIEW v_revenue_summary AS
SELECT 
    DATE_TRUNC('month', cb.billing_period_start) as month,
    COUNT(DISTINCT cb.candidate_id) as active_candidates,
    SUM(cb.subscription_fee) as subscription_revenue,
    SUM(cb.volunteer_recruitment_fee) as recruitment_revenue,
    SUM(cb.total_amount) as total_revenue,
    SUM(cb.volunteers_allocated) as total_volunteers_allocated
FROM candidate_billing cb
WHERE cb.payment_status = 'PAID'
GROUP BY DATE_TRUNC('month', cb.billing_period_start)
ORDER BY month DESC;

-- View: Issue Performance
CREATE OR REPLACE VIEW v_issue_performance AS
SELECT 
    va.recruited_via_issue,
    COUNT(*) as volunteers_recruited,
    COUNT(DISTINCT va.allocated_to_candidate_id) as candidates_receiving,
    ROUND(AVG(va.match_score), 2) as avg_match_quality,
    COUNT(*) FILTER (WHERE va.status = 'ACTIVE') as activated_count,
    ROUND(COUNT(*) FILTER (WHERE va.status = 'ACTIVE')::NUMERIC / COUNT(*)::NUMERIC * 100, 2) as activation_rate
FROM volunteer_allocations va
GROUP BY va.recruited_via_issue
ORDER BY volunteers_recruited DESC;

-- ============================================================================
-- SAMPLE QUERIES
-- ============================================================================

/*
-- Add a new candidate
INSERT INTO candidates (
    candidate_id, first_name, last_name, full_name, office_type, district, county,
    primary_issues, issue_intensity_scores, email, subscription_tier, monthly_fee,
    volunteer_allocation_cap, priority_score
) VALUES (
    'CAND_001', 'John', 'Smith', 'John Smith', 'County Commissioner', 'District 3', 
    'Wake County', ARRAY['EDUCATION', 'ECONOMY'], 
    '{"EDUCATION": 95, "ECONOMY": 85, "PRO_LIFE": 70}', 
    'john.smith@example.com', 'PRO', 500.00, 50, 75
);

-- Match a volunteer to candidates
SELECT * FROM match_volunteer_to_candidates(
    'volunteer@email.com',
    'Wake County',
    '{"EDUCATION": 90, "CHRISTIAN_VALUES": 80}',
    'EDUCATION'
);

-- Auto-allocate a volunteer
SELECT auto_allocate_volunteer(
    'newvolunteer@email.com',
    'Jane Doe',
    'Forsyth County',
    'EDUCATION',
    'EDUCATION_ACTIVIST; CHRISTIAN_RIGHT;',
    123
);

-- View candidate dashboard
SELECT * FROM v_candidate_dashboard WHERE county = 'Wake County';

-- View revenue summary
SELECT * FROM v_revenue_summary;

-- View issue performance
SELECT * FROM v_issue_performance;

-- Get volunteers for a specific candidate
SELECT * FROM volunteer_allocations 
WHERE allocated_to_candidate_id = 'CAND_001'
ORDER BY allocation_date DESC;
*/

-- ============================================================================
-- SCHEMA COMPLETE
-- ============================================================================

SELECT 'Candidate-based volunteer marketplace schema created!' as status;
