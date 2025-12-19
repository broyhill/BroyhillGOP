-- =====================================================
-- BROYHILLGOP SUPABASE DATABASE SCHEMA
-- Adaptive Multi-Channel Campaign Sequence Engine
-- File 1: Core Tables
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- =====================================================
-- SECTION 1: CORE DONOR & CANDIDATE TABLES
-- =====================================================

-- Table: candidates
-- Stores all Republican candidates across NC (House, Senate, local offices)
CREATE TABLE IF NOT EXISTS candidates (
    candidate_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    office_type VARCHAR(50) NOT NULL, -- 'State House', 'State Senate', 'Sheriff', 'School Board', etc.
    district VARCHAR(50),
    county VARCHAR(100),
    party VARCHAR(20) DEFAULT 'Republican',
    email VARCHAR(255),
    phone VARCHAR(20),
    campaign_website VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for fast candidate lookups
CREATE INDEX idx_candidates_office_district ON candidates(office_type, district);

-- Table: donors
-- Central donor database (150,000 NC Republican donors)
CREATE TABLE IF NOT EXISTS donors (
    donor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    tier VARCHAR(10) NOT NULL, -- 'A', 'B', 'C', 'D', 'U'
    age INT,
    gender VARCHAR(20),
    occupation VARCHAR(200),
    employer VARCHAR(200),
    household_income INT,
    contribution_total_2yr NUMERIC(12,2) DEFAULT 0,
    lifetime_contribution NUMERIC(12,2) DEFAULT 0,
    issue_scores JSONB, -- {healthcare: 90, education: 75, crime: 85, ...}
    geographic_district VARCHAR(50),
    county VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for donor queries
CREATE INDEX idx_donors_tier ON donors(tier);
CREATE INDEX idx_donors_county ON donors(county);
CREATE INDEX idx_donors_issue_scores ON donors USING GIN(issue_scores);

-- Table: phone_numbers
-- One-to-many relationship (donors can have multiple phone numbers)
CREATE TABLE IF NOT EXISTS phone_numbers (
    phone_id SERIAL PRIMARY KEY,
    donor_id INT REFERENCES donors(donor_id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    phone_type VARCHAR(20), -- 'Mobile', 'Home', 'Business'
    is_primary BOOLEAN DEFAULT FALSE,
    confidence_score INT DEFAULT 0, -- 0-100
    carrier_verified BOOLEAN DEFAULT FALSE,
    source VARCHAR(50), -- 'DataTrust', 'BetterContact', 'Manual'
    last_engagement_date TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'inactive', 'archived'
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_phone_donor ON phone_numbers(donor_id);
CREATE INDEX idx_phone_primary ON phone_numbers(is_primary) WHERE is_primary = TRUE;

-- Table: email_addresses
-- One-to-many relationship
CREATE TABLE IF NOT EXISTS email_addresses (
    email_id SERIAL PRIMARY KEY,
    donor_id INT REFERENCES donors(donor_id) ON DELETE CASCADE,
    email_address VARCHAR(255) NOT NULL,
    email_type VARCHAR(20), -- 'Personal', 'Business'
    is_primary BOOLEAN DEFAULT FALSE,
    confidence_score INT DEFAULT 0, -- 0-100
    smtp_verified BOOLEAN DEFAULT FALSE,
    bounce_count INT DEFAULT 0,
    last_open_date TIMESTAMP,
    source VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_email_donor ON email_addresses(donor_id);
CREATE INDEX idx_email_primary ON email_addresses(is_primary) WHERE is_primary = TRUE;

-- Table: physical_addresses
-- One-to-many relationship
CREATE TABLE IF NOT EXISTS physical_addresses (
    address_id SERIAL PRIMARY KEY,
    donor_id INT REFERENCES donors(donor_id) ON DELETE CASCADE,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(2) DEFAULT 'NC',
    zip VARCHAR(10) NOT NULL,
    county VARCHAR(100),
    is_primary BOOLEAN DEFAULT FALSE,
    confidence_score INT DEFAULT 0,
    usps_verified BOOLEAN DEFAULT FALSE,
    ncoa_verified_date TIMESTAMP, -- National Change of Address
    source VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_address_donor ON physical_addresses(donor_id);
CREATE INDEX idx_address_primary ON physical_addresses(is_primary) WHERE is_primary = TRUE;

-- =====================================================
-- SECTION 2: ISSUE HEAT MAP TABLES
-- =====================================================

-- Table: issue_categories
-- 15 core policy issues tracked across all candidates
CREATE TABLE IF NOT EXISTS issue_categories (
    issue_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE, -- 'Healthcare', 'Education', 'Crime', etc.
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Seed data for 15 core issues
INSERT INTO issue_categories (name, description) VALUES
    ('Healthcare', 'Healthcare access, insurance, and medical policy'),
    ('Education', 'Public schools, teacher pay, curriculum standards'),
    ('Crime & Public Safety', 'Law enforcement, criminal justice, police funding'),
    ('Economy & Jobs', 'Economic development, unemployment, business growth'),
    ('Tax Policy', 'Income tax, property tax, corporate taxation'),
    ('Immigration & Border Security', 'Border policy, illegal immigration, sanctuary cities'),
    ('Second Amendment', 'Gun rights, firearm regulations, concealed carry'),
    ('Agriculture', 'Farm subsidies, rural development, crop insurance'),
    ('Environment', 'Conservation, climate policy, natural resources'),
    ('Transportation & Infrastructure', 'Roads, bridges, public transit'),
    ('Family Values & Abortion', 'Pro-life policy, parental rights, religious freedom'),
    ('School Choice & Vouchers', 'Charter schools, education savings accounts'),
    ('Opioid Crisis', 'Drug abuse prevention, treatment programs'),
    ('Veterans Affairs', 'Military benefits, VA healthcare, veterans services'),
    ('Small Business Support', 'Regulatory relief, small business loans, entrepreneurship')
ON CONFLICT (name) DO NOTHING;

-- Table: issue_heat_map
-- Dynamic intensity scores (0-100) for each candidate-issue pairing
CREATE TABLE IF NOT EXISTS issue_heat_map (
    heat_map_id SERIAL PRIMARY KEY,
    candidate_id INT REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    issue_id INT REFERENCES issue_categories(issue_id),
    intensity_score INT DEFAULT 0 CHECK (intensity_score >= 0 AND intensity_score <= 100),
    weight_source JSONB, -- {'legislative': 40, 'news': 30, 'social': 15, 'donor_response': 15}
    news_prominence_30d INT DEFAULT 0, -- News mentions in last 30 days
    legislative_activity_count INT DEFAULT 0, -- Bills sponsored/co-sponsored
    committee_chair BOOLEAN DEFAULT FALSE,
    last_updated TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_heat_map_candidate ON issue_heat_map(candidate_id);
CREATE INDEX idx_heat_map_intensity ON issue_heat_map(intensity_score DESC);
CREATE UNIQUE INDEX idx_heat_map_unique ON issue_heat_map(candidate_id, issue_id);

-- =====================================================
-- SECTION 3: CAMPAIGN TYPE & CHANNEL TABLES
-- =====================================================

-- Table: campaign_types
-- 20 campaign event types (fundraisers, rallies, announcements, etc.)
CREATE TABLE IF NOT EXISTS campaign_types (
    campaign_type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL, -- 'Fundraising', 'Cultivation', 'Mobilization', 'Announcement', 'Crisis'
    description TEXT,
    typical_goal NUMERIC(12,2), -- Expected revenue goal
    default_duration_days INT DEFAULT 30,
    requires_venue BOOLEAN DEFAULT FALSE,
    avg_historical_roi NUMERIC(10,2), -- Calculated from past events
    created_at TIMESTAMP DEFAULT NOW()
);

-- Seed data for 20 campaign types
INSERT INTO campaign_types (name, category, description, typical_goal, requires_venue) VALUES
    ('Private Donor Home Reception', 'Fundraising', 'High-dollar event at donor home', 100000, TRUE),
    ('Country Club Luncheon', 'Fundraising', 'Business lunch at prestige venue', 50000, TRUE),
    ('High-Dollar Intimate Dinner', 'Fundraising', 'Ultra-exclusive Tier A++ dinner', 250000, TRUE),
    ('Virtual Fundraiser', 'Fundraising', 'Online Zoom event (scalable)', 25000, FALSE),
    ('Business Leader Breakfast', 'Fundraising', 'Small business owner networking', 30000, TRUE),
    ('Meet-and-Greet', 'Cultivation', 'Free introductory event for unknown donors', 10000, TRUE),
    ('Town Hall', 'Cultivation', 'Issue-focused public forum', 15000, TRUE),
    ('Coffee with Candidate', 'Cultivation', 'Small group intimate setting', 5000, TRUE),
    ('Volunteer Kickoff Rally', 'Mobilization', 'Recruit campaign volunteers', 5000, TRUE),
    ('Door-Knocking Event', 'Mobilization', 'Grassroots canvassing', 2000, FALSE),
    ('President Trump Rally', 'Fundraising', 'Major national figure appearance', 500000, TRUE),
    ('Governor/Senator Joint Event', 'Fundraising', 'Multi-candidate synergy', 150000, TRUE),
    ('Celebrity Endorsement Event', 'Fundraising', 'Athlete/actor/business leader draw', 75000, TRUE),
    ('Campaign Launch Announcement', 'Announcement', 'Kickoff press conference', 50000, FALSE),
    ('Endorsement Announcement', 'Announcement', 'Prominent figure endorses candidate', 25000, FALSE),
    ('Legislative Victory Announcement', 'Announcement', 'Celebrate bill passage', 30000, FALSE),
    ('Quarterly Progress Update', 'Announcement', 'Donor stewardship newsletter', 10000, FALSE),
    ('FEC Deadline Push', 'Announcement', 'End-of-quarter urgency campaign', 100000, FALSE),
    ('Rapid Response', 'Crisis', 'Emergency defense/counter-attack', 75000, FALSE),
    ('Contrast Campaign', 'Crisis', 'Highlight opponent weakness', 50000, FALSE)
ON CONFLICT (name) DO NOTHING;

-- Table: campaign_channels
-- All communication methods available
CREATE TABLE IF NOT EXISTS campaign_channels (
    channel_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE, -- 'Email', 'SMS', 'Print', 'Call', 'WhatsApp', 'Social Media'
    description TEXT,
    avg_cost NUMERIC(10,2), -- Average cost per send/call
    avg_delivery_rate NUMERIC(5,2) DEFAULT 95.0, -- Percentage
    avg_open_rate NUMERIC(5,2) DEFAULT 20.0, -- Percentage
    avg_response_rate NUMERIC(5,2) DEFAULT 3.0, -- Percentage
    created_at TIMESTAMP DEFAULT NOW()
);

-- Seed data for channels
INSERT INTO campaign_channels (name, avg_cost, avg_delivery_rate, avg_open_rate, avg_response_rate) VALUES
    ('Email', 0.10, 98.0, 22.0, 0.8),
    ('SMS', 0.08, 98.5, 98.0, 2.1),
    ('Print Mail', 1.50, 95.0, 65.0, 2.5),
    ('Phone Call', 15.00, 35.0, 35.0, 12.0),
    ('WhatsApp', 0.05, 99.0, 95.0, 3.5)
ON CONFLICT (name) DO NOTHING;

-- Table: psychological_tones
-- 22 AI-generated communication tones
CREATE TABLE IF NOT EXISTS psychological_tones (
    tone_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    recommended_use_case TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Seed key tones
INSERT INTO psychological_tones (name, description, recommended_use_case) VALUES
    ('Urgent', 'Time-sensitive, action-oriented', 'FEC deadlines, breaking news'),
    ('Appreciative', 'Grateful, thankful, recognizing support', 'Thank-you messages, stewardship'),
    ('Exclusive', 'VIP access, limited availability', 'High-dollar events, Tier A invitations'),
    ('Informative', 'Educational, policy-focused', 'Town halls, issue updates'),
    ('Empowering', 'Motivational, mobilizing', 'Volunteer recruitment')
ON CONFLICT (name) DO NOTHING;

-- Comments for documentation
COMMENT ON TABLE candidates IS 'All Republican candidates across NC offices';
COMMENT ON TABLE donors IS 'Central 150,000 donor database with tier classification';
COMMENT ON TABLE issue_heat_map IS 'Dynamic 0-100 intensity scores for candidate-issue alignment';
COMMENT ON TABLE campaign_types IS '20 campaign event categories with historical performance';
COMMENT ON TABLE campaign_channels IS 'Multi-channel communication methods with cost metrics';
