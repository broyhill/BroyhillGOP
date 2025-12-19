-- ============================================
-- BROYHILLGOP DATAHUB - Complete SQL Schema
-- MySQL/MariaDB Compatible
-- ============================================
-- 
-- Run this file to create all tables in order
-- Then use seeders to populate data
--
-- Tables:
-- 1. nc_counties (100)
-- 2. nc_districts (184)
-- 3. district_county_map (~400)
-- 4. officials (122+)
-- 5. official_counties
-- 6. campaigns (~150)
-- 7. donors (243,575)
-- 8. donor_matches (auto-generated)
-- 9. donations (transactions)
-- 10. volunteers
-- 11. campaign_volunteers
-- 12. users (multi-tenant auth)
-- ============================================

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================
-- TABLE 1: NC Counties (Foundation)
-- ============================================
DROP TABLE IF EXISTS nc_counties;
CREATE TABLE nc_counties (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    county_code VARCHAR(3) NOT NULL UNIQUE COMMENT 'MEK, WAK, GUI',
    county_name VARCHAR(50) NOT NULL,
    fips_code VARCHAR(5) NULL,
    region ENUM('mountain', 'piedmont', 'coastal') NOT NULL,
    
    -- Demographics
    population INT UNSIGNED NULL,
    registered_voters INT UNSIGNED NULL,
    republican_voters INT UNSIGNED NULL,
    democrat_voters INT UNSIGNED NULL,
    unaffiliated_voters INT UNSIGNED NULL,
    gop_percentage DECIMAL(5,2) NULL,
    
    -- GOP Leadership
    gop_chair_name VARCHAR(100) NULL,
    gop_chair_email VARCHAR(100) NULL,
    gop_chair_phone VARCHAR(20) NULL,
    gop_hq_address TEXT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_region (region),
    INDEX idx_gop_pct (gop_percentage)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 2: Officials (Elected Officials & Candidates)
-- ============================================
DROP TABLE IF EXISTS officials;
CREATE TABLE officials (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    datahub_id VARCHAR(20) NOT NULL UNIQUE COMMENT 'NCHOUSE-001, NCSC-003',
    
    -- Classification
    official_type ENUM(
        'us_senate', 'us_house', 
        'nc_senate', 'nc_house',
        'council_of_state', 
        'supreme_court', 'court_of_appeals',
        'superior_court', 'district_court',
        'county', 'municipal', 'candidate'
    ) NOT NULL,
    status ENUM('incumbent', 'candidate', 'former', 'defeated') DEFAULT 'incumbent',
    
    -- Identity
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    preferred_name VARCHAR(50) NULL,
    suffix VARCHAR(10) NULL COMMENT 'Jr., III',
    party VARCHAR(20) DEFAULT 'Republican',
    
    -- Position
    position_title VARCHAR(100) NOT NULL,
    district_number VARCHAR(10) NULL,
    seat_number VARCHAR(10) NULL COMMENT 'For judges',
    
    -- Contact - Official
    office_phone VARCHAR(20) NULL,
    office_email VARCHAR(100) NULL,
    office_address TEXT NULL,
    office_room VARCHAR(20) NULL,
    
    -- Location
    home_county_id BIGINT UNSIGNED NULL,
    home_city VARCHAR(100) NULL,
    
    -- Digital
    website_official VARCHAR(255) NULL,
    website_campaign VARCHAR(255) NULL,
    twitter_handle VARCHAR(50) NULL,
    facebook_url VARCHAR(255) NULL,
    photo_url VARCHAR(255) NULL,
    
    -- Background
    birth_year YEAR NULL,
    birthplace VARCHAR(100) NULL,
    education TEXT NULL,
    occupation VARCHAR(200) NULL,
    prior_career TEXT NULL,
    military_service TEXT NULL,
    
    -- Service
    first_elected VARCHAR(20) NULL,
    years_in_office TINYINT UNSIGNED NULL,
    term_ends YEAR NULL,
    leadership_role VARCHAR(100) NULL,
    
    -- Personal
    family TEXT NULL,
    religion VARCHAR(100) NULL,
    
    -- Judicial only
    judicial_philosophy VARCHAR(100) NULL,
    bar_certifications TEXT NULL,
    
    -- Bio
    bio_short TEXT NULL,
    bio_full TEXT NULL,
    notable_accomplishments TEXT NULL,
    
    -- Scoring
    fundraising_tier ENUM('A', 'B', 'C', 'D') DEFAULT 'C',
    priority_level TINYINT UNSIGNED DEFAULT 5,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    
    INDEX idx_type (official_type),
    INDEX idx_status (status),
    INDEX idx_last_name (last_name),
    INDEX idx_county (home_county_id),
    INDEX idx_district (district_number),
    
    CONSTRAINT fk_official_county FOREIGN KEY (home_county_id) 
        REFERENCES nc_counties(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 3: NC Districts
-- ============================================
DROP TABLE IF EXISTS nc_districts;
CREATE TABLE nc_districts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    district_code VARCHAR(20) NOT NULL UNIQUE COMMENT 'NC-HD-098, US-CD-08',
    district_type ENUM('us_senate', 'us_house', 'nc_senate', 'nc_house', 'judicial', 'statewide') NOT NULL,
    district_number VARCHAR(10) NULL,
    district_name VARCHAR(100) NOT NULL,
    
    -- Current holder
    current_holder_id BIGINT UNSIGNED NULL,
    party_control ENUM('R', 'D', 'I', 'Vacant') DEFAULT 'Vacant',
    
    -- Electoral data
    cook_pvi VARCHAR(10) NULL COMMENT 'R+8, D+3',
    last_margin DECIMAL(5,2) NULL,
    competitiveness ENUM('safe_r', 'likely_r', 'lean_r', 'tossup', 'lean_d', 'likely_d', 'safe_d') NULL,
    
    -- Map info
    map_effective_date DATE NULL,
    next_election_year YEAR NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_type (district_type),
    INDEX idx_competitiveness (competitiveness),
    INDEX idx_party (party_control),
    
    CONSTRAINT fk_district_holder FOREIGN KEY (current_holder_id) 
        REFERENCES officials(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 4: District-County Mapping
-- ============================================
DROP TABLE IF EXISTS district_county_map;
CREATE TABLE district_county_map (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    district_id BIGINT UNSIGNED NOT NULL,
    county_id BIGINT UNSIGNED NOT NULL,
    county_portion ENUM('full', 'partial') DEFAULT 'full',
    population_in_district INT UNSIGNED NULL,
    
    UNIQUE KEY uk_district_county (district_id, county_id),
    INDEX idx_county (county_id),
    
    CONSTRAINT fk_dcm_district FOREIGN KEY (district_id) 
        REFERENCES nc_districts(id) ON DELETE CASCADE,
    CONSTRAINT fk_dcm_county FOREIGN KEY (county_id) 
        REFERENCES nc_counties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 5: Official-County Mapping (represents/resides)
-- ============================================
DROP TABLE IF EXISTS official_counties;
CREATE TABLE official_counties (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    official_id BIGINT UNSIGNED NOT NULL,
    county_id BIGINT UNSIGNED NOT NULL,
    relationship_type ENUM('represents', 'resides', 'born') NOT NULL,
    
    UNIQUE KEY uk_official_county_rel (official_id, county_id, relationship_type),
    INDEX idx_county (county_id),
    
    CONSTRAINT fk_oc_official FOREIGN KEY (official_id) 
        REFERENCES officials(id) ON DELETE CASCADE,
    CONSTRAINT fk_oc_county FOREIGN KEY (county_id) 
        REFERENCES nc_counties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 6: Campaigns (Multi-Tenant Core)
-- ============================================
DROP TABLE IF EXISTS campaigns;
CREATE TABLE campaigns (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    campaign_code VARCHAR(30) NOT NULL UNIQUE COMMENT 'BROYHILL-HD98-2026',
    
    -- Link to official
    official_id BIGINT UNSIGNED NOT NULL,
    election_year YEAR NOT NULL,
    election_type ENUM('primary', 'general', 'special', 'runoff') DEFAULT 'general',
    
    -- Status
    campaign_status ENUM('exploratory', 'active', 'suspended', 'won', 'lost') DEFAULT 'active',
    
    -- Goals
    fundraising_goal DECIMAL(12,2) NULL,
    fundraising_current DECIMAL(12,2) DEFAULT 0,
    volunteer_goal INT UNSIGNED NULL,
    volunteer_current INT UNSIGNED DEFAULT 0,
    
    -- Platform Access
    user_id BIGINT UNSIGNED NULL COMMENT 'Login user for this campaign',
    access_level ENUM('full', 'limited', 'readonly') DEFAULT 'full',
    
    -- Dates
    launch_date DATE NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_year (election_year),
    INDEX idx_status (campaign_status),
    INDEX idx_official (official_id),
    
    CONSTRAINT fk_campaign_official FOREIGN KEY (official_id) 
        REFERENCES officials(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 7: Donors (Core Asset - 243,575 records)
-- ============================================
DROP TABLE IF EXISTS donors;
CREATE TABLE donors (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    donor_code VARCHAR(20) NOT NULL UNIQUE COMMENT 'DNR-000001',
    
    -- Identity
    first_name VARCHAR(50) NULL,
    last_name VARCHAR(50) NULL,
    preferred_name VARCHAR(50) NULL,
    gender ENUM('M', 'F', 'U') DEFAULT 'U',
    
    -- Contact
    email VARCHAR(100) NULL,
    phone_mobile VARCHAR(20) NULL,
    phone_home VARCHAR(20) NULL,
    
    -- Address
    street_address VARCHAR(200) NULL,
    city VARCHAR(100) NULL,
    state VARCHAR(2) DEFAULT 'NC',
    zip_code VARCHAR(10) NULL,
    county_id BIGINT UNSIGNED NULL COMMENT 'Critical for matching',
    
    -- Professional
    employer VARCHAR(200) NULL,
    occupation VARCHAR(200) NULL,
    industry VARCHAR(100) NULL,
    
    -- Scoring (PATRIOT Intelligence)
    grade ENUM('A+','A','A-','B+','B','B-','C+','C','C-','D+','D','D-','F','U') DEFAULT 'U',
    lead_score SMALLINT UNSIGNED DEFAULT 0 COMMENT '0-1000',
    wealth_estimate DECIMAL(14,2) NULL,
    giving_capacity DECIMAL(12,2) NULL,
    
    -- Donation History (denormalized for performance)
    total_donated DECIMAL(12,2) DEFAULT 0,
    donation_count INT UNSIGNED DEFAULT 0,
    last_donation_date DATE NULL,
    largest_donation DECIMAL(12,2) NULL,
    avg_donation DECIMAL(10,2) NULL,
    
    -- Engagement Preferences
    email_opt_in BOOLEAN DEFAULT TRUE,
    sms_opt_in BOOLEAN DEFAULT FALSE,
    mail_opt_in BOOLEAN DEFAULT TRUE,
    call_opt_in BOOLEAN DEFAULT FALSE,
    do_not_contact BOOLEAN DEFAULT FALSE,
    
    -- Source Tracking
    source VARCHAR(50) NULL COMMENT 'Apollo, FEC, Event',
    source_date DATE NULL,
    apollo_id VARCHAR(50) NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    
    INDEX idx_county (county_id),
    INDEX idx_grade (grade),
    INDEX idx_score (lead_score),
    INDEX idx_zip (zip_code),
    INDEX idx_email (email),
    INDEX idx_last_name (last_name),
    INDEX idx_total_donated (total_donated),
    
    CONSTRAINT fk_donor_county FOREIGN KEY (county_id) 
        REFERENCES nc_counties(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 8: Donor Matches (DATAHUB Core Function)
-- ============================================
DROP TABLE IF EXISTS donor_matches;
CREATE TABLE donor_matches (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    donor_id BIGINT UNSIGNED NOT NULL,
    campaign_id BIGINT UNSIGNED NOT NULL,
    
    -- Match Quality
    match_type ENUM('district', 'county', 'statewide', 'affinity', 'manual') NOT NULL,
    match_score TINYINT UNSIGNED DEFAULT 50 COMMENT '0-100',
    match_reason VARCHAR(255) NULL,
    
    -- Assignment
    assigned_to_campaign BOOLEAN DEFAULT FALSE,
    assigned_date DATETIME NULL,
    assigned_by BIGINT UNSIGNED NULL,
    
    -- Outcome Tracking
    contacted BOOLEAN DEFAULT FALSE,
    contact_date DATETIME NULL,
    donated BOOLEAN DEFAULT FALSE,
    donation_amount DECIMAL(12,2) NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_donor_campaign (donor_id, campaign_id),
    INDEX idx_campaign (campaign_id),
    INDEX idx_score (match_score),
    INDEX idx_assigned (assigned_to_campaign),
    INDEX idx_match_type (match_type),
    
    CONSTRAINT fk_dm_donor FOREIGN KEY (donor_id) 
        REFERENCES donors(id) ON DELETE CASCADE,
    CONSTRAINT fk_dm_campaign FOREIGN KEY (campaign_id) 
        REFERENCES campaigns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 9: Donations (LIBERTY Ledger)
-- ============================================
DROP TABLE IF EXISTS donations;
CREATE TABLE donations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    donation_code VARCHAR(20) NOT NULL UNIQUE COMMENT 'DON-2025-00001',
    
    donor_id BIGINT UNSIGNED NOT NULL,
    campaign_id BIGINT UNSIGNED NOT NULL,
    
    -- Transaction
    amount DECIMAL(12,2) NOT NULL,
    donation_date DATE NOT NULL,
    donation_type ENUM('online', 'check', 'cash', 'in_kind', 'event', 'recurring') DEFAULT 'online',
    payment_method VARCHAR(50) NULL,
    
    -- Compliance
    fec_reportable BOOLEAN DEFAULT TRUE,
    employer_disclosed VARCHAR(200) NULL,
    occupation_disclosed VARCHAR(200) NULL,
    
    -- Source tracking
    source_code VARCHAR(50) NULL COMMENT 'Email campaign ID, event ID',
    utm_source VARCHAR(100) NULL,
    utm_campaign VARCHAR(100) NULL,
    
    -- Status
    status ENUM('pending', 'cleared', 'refunded', 'bounced', 'cancelled') DEFAULT 'pending',
    
    -- Notes
    notes TEXT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_campaign (campaign_id),
    INDEX idx_donor (donor_id),
    INDEX idx_date (donation_date),
    INDEX idx_amount (amount),
    INDEX idx_status (status),
    
    CONSTRAINT fk_don_donor FOREIGN KEY (donor_id) 
        REFERENCES donors(id) ON DELETE RESTRICT,
    CONSTRAINT fk_don_campaign FOREIGN KEY (campaign_id) 
        REFERENCES campaigns(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 10: Volunteers (FREEDOM Force)
-- ============================================
DROP TABLE IF EXISTS volunteers;
CREATE TABLE volunteers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    volunteer_code VARCHAR(20) NOT NULL UNIQUE COMMENT 'VOL-00001',
    
    -- Link to donor (if applicable)
    donor_id BIGINT UNSIGNED NULL,
    
    -- Identity
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NULL,
    phone VARCHAR(20) NULL,
    
    -- Location
    county_id BIGINT UNSIGNED NULL,
    zip_code VARCHAR(10) NULL,
    
    -- Skills & Availability (JSON)
    skills JSON NULL COMMENT '["phone_banking","door_knocking"]',
    availability JSON NULL COMMENT '{"weekdays":true,"evenings":false}',
    
    -- Status
    status ENUM('active', 'inactive', 'pending', 'blocked') DEFAULT 'pending',
    hours_contributed DECIMAL(8,2) DEFAULT 0,
    
    -- Source
    referral_source VARCHAR(100) NULL,
    referral_code VARCHAR(20) NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_county (county_id),
    INDEX idx_status (status),
    INDEX idx_donor (donor_id),
    
    CONSTRAINT fk_vol_donor FOREIGN KEY (donor_id) 
        REFERENCES donors(id) ON DELETE SET NULL,
    CONSTRAINT fk_vol_county FOREIGN KEY (county_id) 
        REFERENCES nc_counties(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 11: Campaign-Volunteer Assignment
-- ============================================
DROP TABLE IF EXISTS campaign_volunteers;
CREATE TABLE campaign_volunteers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    campaign_id BIGINT UNSIGNED NOT NULL,
    volunteer_id BIGINT UNSIGNED NOT NULL,
    
    role VARCHAR(100) NULL,
    assigned_date DATE NULL,
    hours_for_campaign DECIMAL(8,2) DEFAULT 0,
    status ENUM('active', 'inactive', 'completed') DEFAULT 'active',
    
    UNIQUE KEY uk_campaign_volunteer (campaign_id, volunteer_id),
    INDEX idx_volunteer (volunteer_id),
    
    CONSTRAINT fk_cv_campaign FOREIGN KEY (campaign_id) 
        REFERENCES campaigns(id) ON DELETE CASCADE,
    CONSTRAINT fk_cv_volunteer FOREIGN KEY (volunteer_id) 
        REFERENCES volunteers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLE 12: Users (Multi-Tenant Auth)
-- ============================================
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    email_verified_at TIMESTAMP NULL,
    password VARCHAR(255) NOT NULL,
    
    -- Role-based access
    role ENUM('super_admin', 'platform_admin', 'campaign_admin', 'campaign_staff', 'volunteer', 'readonly') DEFAULT 'readonly',
    
    -- Multi-tenant: Campaign assignment
    campaign_id BIGINT UNSIGNED NULL COMMENT 'NULL for super/platform admins',
    
    -- Profile
    phone VARCHAR(20) NULL,
    avatar_url VARCHAR(255) NULL,
    
    remember_token VARCHAR(100) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    
    INDEX idx_role (role),
    INDEX idx_campaign (campaign_id),
    
    CONSTRAINT fk_user_campaign FOREIGN KEY (campaign_id) 
        REFERENCES campaigns(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================
-- VIEWS for Ecosystem Access
-- ============================================

-- PATRIOT Intelligence: Donor Profiles
CREATE OR REPLACE VIEW v_patriot_donors AS
SELECT 
    d.*,
    c.county_name,
    c.region,
    c.gop_percentage as county_gop_pct
FROM donors d
LEFT JOIN nc_counties c ON d.county_id = c.id;

-- SUMMIT Match: Donor-Campaign Matches
CREATE OR REPLACE VIEW v_summit_matches AS
SELECT 
    dm.*,
    CONCAT(d.first_name, ' ', d.last_name) as donor_name,
    d.email as donor_email,
    d.grade as donor_grade,
    d.giving_capacity,
    d.total_donated,
    CONCAT(o.first_name, ' ', o.last_name) as candidate_name,
    o.position_title,
    o.district_number,
    c.fundraising_goal,
    c.fundraising_current,
    c.campaign_status
FROM donor_matches dm
JOIN donors d ON dm.donor_id = d.id
JOIN campaigns c ON dm.campaign_id = c.id
JOIN officials o ON c.official_id = o.id;

-- LIBERTY Ledger: Campaign Financials
CREATE OR REPLACE VIEW v_liberty_ledger AS
SELECT 
    c.id as campaign_id,
    c.campaign_code,
    CONCAT(o.first_name, ' ', o.last_name) as candidate_name,
    o.position_title,
    c.election_year,
    c.fundraising_goal,
    c.fundraising_current,
    ROUND((c.fundraising_current / NULLIF(c.fundraising_goal, 0) * 100), 1) as goal_percentage,
    COUNT(DISTINCT don.id) as donation_count,
    COUNT(DISTINCT don.donor_id) as unique_donors,
    COALESCE(AVG(don.amount), 0) as avg_donation,
    COALESCE(MAX(don.amount), 0) as largest_donation,
    MAX(don.donation_date) as last_donation
FROM campaigns c
JOIN officials o ON c.official_id = o.id
LEFT JOIN donations don ON c.id = don.campaign_id AND don.status = 'cleared'
GROUP BY c.id;

-- Campaign Portal: Multi-Tenant Dashboard
CREATE OR REPLACE VIEW v_campaign_dashboard AS
SELECT 
    c.id as campaign_id,
    c.campaign_code,
    c.user_id,
    CONCAT(o.first_name, ' ', o.last_name) as candidate_name,
    o.position_title,
    o.district_number,
    
    -- Donor Stats
    (SELECT COUNT(*) FROM donor_matches dm 
     WHERE dm.campaign_id = c.id) as total_matched_donors,
    (SELECT COUNT(*) FROM donor_matches dm 
     WHERE dm.campaign_id = c.id AND dm.assigned_to_campaign = TRUE) as assigned_donors,
    
    -- Financial Stats
    c.fundraising_goal,
    c.fundraising_current,
    (SELECT COUNT(*) FROM donations WHERE campaign_id = c.id AND status = 'cleared') as donation_count,
    
    -- Volunteer Stats
    c.volunteer_goal,
    c.volunteer_current,
    (SELECT COUNT(*) FROM campaign_volunteers cv WHERE cv.campaign_id = c.id) as volunteer_count,
    
    c.campaign_status
FROM campaigns c
JOIN officials o ON c.official_id = o.id;

-- ============================================
-- STORED PROCEDURE: Auto-Match Donors to Campaigns
-- This is the CORE DATAHUB matching function
-- ============================================

DELIMITER //

CREATE PROCEDURE sp_match_donors_to_campaigns()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_campaign_id BIGINT;
    DECLARE v_official_id BIGINT;
    DECLARE v_district_type VARCHAR(20);
    DECLARE v_district_number VARCHAR(10);
    DECLARE v_home_county_id BIGINT;
    
    -- Cursor for active campaigns
    DECLARE campaign_cursor CURSOR FOR 
        SELECT c.id, c.official_id, o.official_type, o.district_number, o.home_county_id
        FROM campaigns c
        JOIN officials o ON c.official_id = o.id
        WHERE c.campaign_status = 'active';
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Clear previous auto-matches (keep manual)
    DELETE FROM donor_matches WHERE match_type != 'manual';
    
    OPEN campaign_cursor;
    
    campaign_loop: LOOP
        FETCH campaign_cursor INTO v_campaign_id, v_official_id, v_district_type, v_district_number, v_home_county_id;
        IF done THEN
            LEAVE campaign_loop;
        END IF;
        
        -- STATEWIDE RACES (Supreme Court, Court of Appeals, Council of State)
        IF v_district_type IN ('supreme_court', 'court_of_appeals', 'council_of_state') THEN
            INSERT INTO donor_matches (donor_id, campaign_id, match_type, match_score, match_reason)
            SELECT 
                d.id,
                v_campaign_id,
                'statewide',
                50 + (d.lead_score / 20), -- Base 50 + bonus for lead score
                'Statewide race - all NC donors'
            FROM donors d
            WHERE d.state = 'NC'
            AND d.do_not_contact = FALSE
            ON DUPLICATE KEY UPDATE 
                match_score = GREATEST(match_score, 50 + (d.lead_score / 20));
        
        -- DISTRICT RACES (NC House, NC Senate, US House)
        ELSEIF v_district_type IN ('nc_house', 'nc_senate', 'us_house') THEN
            -- Match by district (highest priority)
            INSERT INTO donor_matches (donor_id, campaign_id, match_type, match_score, match_reason)
            SELECT 
                d.id,
                v_campaign_id,
                'district',
                90 + (d.lead_score / 100),
                CONCAT('Donor resides in ', v_district_type, ' ', v_district_number)
            FROM donors d
            JOIN district_county_map dcm ON d.county_id = dcm.county_id
            JOIN nc_districts dist ON dcm.district_id = dist.id
            WHERE dist.district_type = v_district_type
            AND dist.district_number = v_district_number
            AND d.do_not_contact = FALSE
            ON DUPLICATE KEY UPDATE 
                match_score = GREATEST(match_score, 90);
            
            -- Match by county (medium priority)
            IF v_home_county_id IS NOT NULL THEN
                INSERT INTO donor_matches (donor_id, campaign_id, match_type, match_score, match_reason)
                SELECT 
                    d.id,
                    v_campaign_id,
                    'county',
                    70 + (d.lead_score / 100),
                    'Donor in candidate home county'
                FROM donors d
                WHERE d.county_id = v_home_county_id
                AND d.do_not_contact = FALSE
                AND NOT EXISTS (
                    SELECT 1 FROM donor_matches dm 
                    WHERE dm.donor_id = d.id AND dm.campaign_id = v_campaign_id
                )
                ON DUPLICATE KEY UPDATE 
                    match_score = GREATEST(match_score, 70);
            END IF;
        END IF;
        
    END LOOP;
    
    CLOSE campaign_cursor;
    
    -- Return summary
    SELECT 
        COUNT(*) as total_matches,
        COUNT(DISTINCT donor_id) as unique_donors,
        COUNT(DISTINCT campaign_id) as campaigns_matched
    FROM donor_matches;
    
END //

DELIMITER ;

-- ============================================
-- TRIGGERS: Keep denormalized data in sync
-- ============================================

DELIMITER //

-- Update donor totals when donation is added
CREATE TRIGGER tr_donation_after_insert
AFTER INSERT ON donations
FOR EACH ROW
BEGIN
    IF NEW.status = 'cleared' THEN
        UPDATE donors SET
            total_donated = total_donated + NEW.amount,
            donation_count = donation_count + 1,
            last_donation_date = NEW.donation_date,
            largest_donation = GREATEST(COALESCE(largest_donation, 0), NEW.amount),
            avg_donation = (total_donated + NEW.amount) / (donation_count + 1)
        WHERE id = NEW.donor_id;
        
        -- Update campaign totals
        UPDATE campaigns SET
            fundraising_current = fundraising_current + NEW.amount
        WHERE id = NEW.campaign_id;
        
        -- Update match record
        UPDATE donor_matches SET
            donated = TRUE,
            donation_amount = COALESCE(donation_amount, 0) + NEW.amount
        WHERE donor_id = NEW.donor_id AND campaign_id = NEW.campaign_id;
    END IF;
END //

DELIMITER ;

-- ============================================
-- SAMPLE DATA: Insert this after schema
-- ============================================

-- Will be populated by seeders from:
-- - NC_Counties_2025.csv (100 records)
-- - NC_GOP_DATAHUB_MASTER_2025.csv (122 officials)
-- - BroyhillGOP_100K_Final.csv (243,575 donors)
