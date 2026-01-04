-- ============================================================================
-- ECOSYSTEM 5 & 26: VOLUNTEER MANAGEMENT COMPLETE SQL SCHEMA
-- ============================================================================
-- For Supabase PostgreSQL 15+
-- Integrates with E20 Brain Hub
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- E05: CORE VOLUNTEER TABLES
-- ============================================================================

-- Core Volunteers Table
CREATE TABLE IF NOT EXISTS volunteers (
    volunteer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID,
    donor_id UUID,
    candidate_id UUID,
    
    -- Personal Info
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    county VARCHAR(100),
    
    -- 3D Grading
    capacity_grade VARCHAR(2) DEFAULT 'U',        -- H/M/L/U
    reliability_grade VARCHAR(3) DEFAULT 'C',     -- A+/A/B/C/D/F
    skill_level INTEGER DEFAULT 1,                -- 1-5
    composite_score INTEGER DEFAULT 50,           -- 0-100
    
    -- Experience
    total_hours DECIMAL(10,2) DEFAULT 0,
    total_shifts INTEGER DEFAULT 0,
    shifts_completed INTEGER DEFAULT 0,
    no_shows INTEGER DEFAULT 0,
    cancellations INTEGER DEFAULT 0,
    
    -- Activity Stats
    doors_knocked INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    texts_sent INTEGER DEFAULT 0,
    voters_registered INTEGER DEFAULT 0,
    
    -- Gamification
    total_points INTEGER DEFAULT 0,
    current_level INTEGER DEFAULT 1,
    badges_earned INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    
    -- ML Predictions
    churn_risk DECIMAL(4,3) DEFAULT 0.5,
    engagement_score DECIMAL(4,3) DEFAULT 0.5,
    leadership_potential DECIMAL(4,3) DEFAULT 0.3,
    predicted_monthly_hours DECIMAL(5,2),
    
    -- Preferences
    preferred_activities JSONB DEFAULT '[]',
    preferred_days JSONB DEFAULT '[]',
    preferred_times JSONB DEFAULT '[]',
    preferred_locations JSONB DEFAULT '[]',
    skills JSONB DEFAULT '[]',
    languages JSONB DEFAULT '["English"]',
    has_vehicle BOOLEAN DEFAULT false,
    can_drive_others BOOLEAN DEFAULT false,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active',  -- active, inactive, suspended, banned
    team_id UUID,
    is_team_leader BOOLEAN DEFAULT false,
    
    -- Onboarding
    recruitment_source VARCHAR(100),
    recruited_by UUID,
    onboarded_at TIMESTAMP,
    training_completed JSONB DEFAULT '[]',
    
    -- E20 Brain Integration
    last_contact_date DATE,
    next_contact_date DATE,
    contact_fatigue_score INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vol_email ON volunteers(email);
CREATE INDEX IF NOT EXISTS idx_vol_phone ON volunteers(phone);
CREATE INDEX IF NOT EXISTS idx_vol_status ON volunteers(status);
CREATE INDEX IF NOT EXISTS idx_vol_team ON volunteers(team_id);
CREATE INDEX IF NOT EXISTS idx_vol_candidate ON volunteers(candidate_id);
CREATE INDEX IF NOT EXISTS idx_vol_composite ON volunteers(composite_score DESC);
CREATE INDEX IF NOT EXISTS idx_vol_churn ON volunteers(churn_risk DESC);

-- Volunteer Shifts
CREATE TABLE IF NOT EXISTS volunteer_shifts (
    shift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID,
    candidate_id UUID,
    event_id UUID,
    
    title VARCHAR(255) NOT NULL,
    description TEXT,
    activity_code VARCHAR(20) NOT NULL,
    
    location_name VARCHAR(255),
    location_address TEXT,
    is_virtual BOOLEAN DEFAULT false,
    virtual_link TEXT,
    
    shift_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    
    slots_total INTEGER DEFAULT 10,
    slots_filled INTEGER DEFAULT 0,
    slots_waitlist INTEGER DEFAULT 0,
    min_volunteers INTEGER DEFAULT 1,
    
    min_skill_level INTEGER DEFAULT 1,
    training_required JSONB DEFAULT '[]',
    equipment_provided JSONB DEFAULT '[]',
    
    base_points INTEGER DEFAULT 10,
    bonus_multiplier DECIMAL(3,2) DEFAULT 1.0,
    
    status VARCHAR(20) DEFAULT 'scheduled',
    
    coordinator_name VARCHAR(255),
    coordinator_phone VARCHAR(20),
    coordinator_email VARCHAR(255),
    
    total_doors INTEGER DEFAULT 0,
    total_calls INTEGER DEFAULT 0,
    total_contacts INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shift_date ON volunteer_shifts(shift_date);
CREATE INDEX IF NOT EXISTS idx_shift_activity ON volunteer_shifts(activity_code);
CREATE INDEX IF NOT EXISTS idx_shift_status ON volunteer_shifts(status);
CREATE INDEX IF NOT EXISTS idx_shift_campaign ON volunteer_shifts(campaign_id);
CREATE INDEX IF NOT EXISTS idx_shift_candidate ON volunteer_shifts(candidate_id);

-- Shift Assignments
CREATE TABLE IF NOT EXISTS shift_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id UUID REFERENCES volunteer_shifts(shift_id) ON DELETE CASCADE,
    volunteer_id UUID REFERENCES volunteers(volunteer_id) ON DELETE CASCADE,
    
    status VARCHAR(20) DEFAULT 'confirmed',
    waitlist_position INTEGER,
    
    checked_in BOOLEAN DEFAULT false,
    check_in_time TIMESTAMP,
    check_in_method VARCHAR(20),
    checked_out BOOLEAN DEFAULT false,
    check_out_time TIMESTAMP,
    
    hours_worked DECIMAL(5,2) DEFAULT 0,
    doors_knocked INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    texts_sent INTEGER DEFAULT 0,
    contacts_made INTEGER DEFAULT 0,
    voters_registered INTEGER DEFAULT 0,
    
    points_earned INTEGER DEFAULT 0,
    bonus_earned INTEGER DEFAULT 0,
    
    verified BOOLEAN DEFAULT false,
    verified_by UUID,
    verified_at TIMESTAMP,
    
    volunteer_notes TEXT,
    supervisor_notes TEXT,
    rating INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(shift_id, volunteer_id)
);

CREATE INDEX IF NOT EXISTS idx_assign_shift ON shift_assignments(shift_id);
CREATE INDEX IF NOT EXISTS idx_assign_volunteer ON shift_assignments(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_assign_status ON shift_assignments(status);

-- Volunteer Teams
CREATE TABLE IF NOT EXISTS volunteer_teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    
    name VARCHAR(100) NOT NULL,
    description TEXT,
    team_type VARCHAR(50) DEFAULT 'general',
    
    team_leader_id UUID REFERENCES volunteers(volunteer_id),
    co_leader_ids JSONB DEFAULT '[]',
    
    member_count INTEGER DEFAULT 0,
    total_hours DECIMAL(10,2) DEFAULT 0,
    total_points INTEGER DEFAULT 0,
    avg_reliability VARCHAR(3) DEFAULT 'C',
    
    is_competing BOOLEAN DEFAULT true,
    competition_rank INTEGER,
    
    assigned_area VARCHAR(255),
    assigned_precincts JSONB DEFAULT '[]',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_team_candidate ON volunteer_teams(candidate_id);
CREATE INDEX IF NOT EXISTS idx_team_leader ON volunteer_teams(team_leader_id);

-- Team Memberships
CREATE TABLE IF NOT EXISTS volunteer_team_members (
    membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES volunteer_teams(team_id) ON DELETE CASCADE,
    volunteer_id UUID REFERENCES volunteers(volunteer_id) ON DELETE CASCADE,
    
    role VARCHAR(20) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(team_id, volunteer_id)
);

-- Volunteer Hours Log
CREATE TABLE IF NOT EXISTS volunteer_hours_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID REFERENCES volunteers(volunteer_id),
    shift_id UUID REFERENCES volunteer_shifts(shift_id),
    assignment_id UUID REFERENCES shift_assignments(assignment_id),
    
    log_date DATE NOT NULL,
    hours DECIMAL(5,2) NOT NULL,
    activity_code VARCHAR(20),
    
    doors INTEGER DEFAULT 0,
    calls INTEGER DEFAULT 0,
    texts INTEGER DEFAULT 0,
    contacts INTEGER DEFAULT 0,
    
    points_earned INTEGER DEFAULT 0,
    
    verified BOOLEAN DEFAULT false,
    verified_by UUID,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hours_volunteer ON volunteer_hours_log(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_hours_date ON volunteer_hours_log(log_date);

-- Badge Definitions
CREATE TABLE IF NOT EXISTS volunteer_badge_definitions (
    badge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT,
    
    badge_type VARCHAR(30),
    criteria_field VARCHAR(50),
    criteria_value INTEGER,
    activity_code VARCHAR(20),
    
    points_reward INTEGER DEFAULT 0,
    rarity VARCHAR(20) DEFAULT 'common',
    
    is_active BOOLEAN DEFAULT true
);

-- Badge Earnings
CREATE TABLE IF NOT EXISTS volunteer_badge_earnings (
    earning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID REFERENCES volunteers(volunteer_id),
    badge_id UUID REFERENCES volunteer_badge_definitions(badge_id),
    
    earned_at TIMESTAMP DEFAULT NOW(),
    notified BOOLEAN DEFAULT false,
    
    UNIQUE(volunteer_id, badge_id)
);

CREATE INDEX IF NOT EXISTS idx_badge_volunteer ON volunteer_badge_earnings(volunteer_id);

-- Leaderboards
CREATE TABLE IF NOT EXISTS volunteer_leaderboards (
    leaderboard_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    period_type VARCHAR(20) NOT NULL,
    period_start DATE,
    period_end DATE,
    
    category VARCHAR(30) NOT NULL,
    scope VARCHAR(20) DEFAULT 'all',
    scope_id UUID,
    
    rankings JSONB DEFAULT '[]',
    
    calculated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lb_period ON volunteer_leaderboards(period_type, category);

-- ============================================================================
-- E26: VOLUNTEER PORTAL TABLES
-- ============================================================================

-- Portal Accounts
CREATE TABLE IF NOT EXISTS volunteer_accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID NOT NULL REFERENCES volunteers(volunteer_id),
    contact_id UUID,
    
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255),
    
    email_verified BOOLEAN DEFAULT false,
    verification_token VARCHAR(255),
    
    display_name VARCHAR(255),
    avatar_url TEXT,
    bio TEXT,
    
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}',
    availability JSONB DEFAULT '{}',
    preferred_activities JSONB DEFAULT '[]',
    preferred_locations JSONB DEFAULT '[]',
    
    points INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vol_account_volunteer ON volunteer_accounts(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_vol_account_email ON volunteer_accounts(email);

-- Portal Sessions
CREATE TABLE IF NOT EXISTS volunteer_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    
    token_hash VARCHAR(255) NOT NULL,
    device_type VARCHAR(50),
    ip_address VARCHAR(50),
    
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

-- Volunteer Opportunities (public-facing shifts)
CREATE TABLE IF NOT EXISTS volunteer_opportunities (
    opportunity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    event_id UUID,
    campaign_id UUID,
    candidate_id UUID,
    
    title VARCHAR(500) NOT NULL,
    description TEXT,
    activity_type VARCHAR(100) NOT NULL,
    
    location_name VARCHAR(255),
    location_address TEXT,
    is_virtual BOOLEAN DEFAULT false,
    virtual_url TEXT,
    
    start_datetime TIMESTAMP NOT NULL,
    end_datetime TIMESTAMP NOT NULL,
    
    max_volunteers INTEGER,
    current_signups INTEGER DEFAULT 0,
    waitlist_enabled BOOLEAN DEFAULT true,
    
    skills_required JSONB DEFAULT '[]',
    training_required JSONB DEFAULT '[]',
    min_age INTEGER,
    
    points_value INTEGER DEFAULT 10,
    bonus_points INTEGER DEFAULT 0,
    
    status VARCHAR(50) DEFAULT 'open',
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_opportunity_date ON volunteer_opportunities(start_datetime);
CREATE INDEX IF NOT EXISTS idx_opportunity_type ON volunteer_opportunities(activity_type);
CREATE INDEX IF NOT EXISTS idx_opportunity_status ON volunteer_opportunities(status);

-- Portal Signups
CREATE TABLE IF NOT EXISTS volunteer_signups (
    signup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_id UUID REFERENCES volunteer_opportunities(opportunity_id),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    volunteer_id UUID,
    
    status VARCHAR(50) DEFAULT 'confirmed',
    waitlist_position INTEGER,
    
    checked_in BOOLEAN DEFAULT false,
    check_in_time TIMESTAMP,
    check_in_method VARCHAR(50),
    check_in_location JSONB,
    
    checked_out BOOLEAN DEFAULT false,
    check_out_time TIMESTAMP,
    
    hours_worked DECIMAL(5,2),
    doors_knocked INTEGER DEFAULT 0,
    calls_made INTEGER DEFAULT 0,
    texts_sent INTEGER DEFAULT 0,
    voters_registered INTEGER DEFAULT 0,
    
    points_earned INTEGER DEFAULT 0,
    bonus_earned INTEGER DEFAULT 0,
    
    volunteer_notes TEXT,
    supervisor_notes TEXT,
    
    hours_verified BOOLEAN DEFAULT false,
    verified_by VARCHAR(255),
    verified_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_signup_opportunity ON volunteer_signups(opportunity_id);
CREATE INDEX IF NOT EXISTS idx_signup_account ON volunteer_signups(account_id);
CREATE INDEX IF NOT EXISTS idx_signup_status ON volunteer_signups(status);

-- Portal Achievements
CREATE TABLE IF NOT EXISTS volunteer_achievements (
    achievement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT,
    
    achievement_type VARCHAR(50),
    criteria_type VARCHAR(50),
    criteria_value INTEGER,
    activity_type VARCHAR(100),
    
    points_reward INTEGER DEFAULT 0,
    rarity VARCHAR(20) DEFAULT 'common',
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Achievement Earnings
CREATE TABLE IF NOT EXISTS volunteer_achievement_earnings (
    earning_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    achievement_id UUID REFERENCES volunteer_achievements(achievement_id),
    
    earned_at TIMESTAMP DEFAULT NOW(),
    notified BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_achievement_account ON volunteer_achievement_earnings(account_id);

-- Portal Teams
CREATE TABLE IF NOT EXISTS volunteer_portal_teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name VARCHAR(255) NOT NULL,
    description TEXT,
    avatar_url TEXT,
    
    captain_account_id UUID REFERENCES volunteer_accounts(account_id),
    
    member_count INTEGER DEFAULT 0,
    total_hours DECIMAL(10,2) DEFAULT 0,
    total_points INTEGER DEFAULT 0,
    
    is_competing BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Portal Team Members
CREATE TABLE IF NOT EXISTS volunteer_portal_team_members (
    membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES volunteer_portal_teams(team_id),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_portal_team_member_team ON volunteer_portal_team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_portal_team_member_account ON volunteer_portal_team_members(account_id);

-- Portal Messages
CREATE TABLE IF NOT EXISTS volunteer_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    target_type VARCHAR(50) NOT NULL,
    target_id UUID,
    
    subject VARCHAR(500),
    message TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'announcement',
    
    sender_name VARCHAR(255),
    
    is_pinned BOOLEAN DEFAULT false,
    expires_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Message Reads
CREATE TABLE IF NOT EXISTS volunteer_message_reads (
    read_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES volunteer_messages(message_id),
    account_id UUID REFERENCES volunteer_accounts(account_id),
    
    read_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- E20 BRAIN INTEGRATION: VOLUNTEER EVENTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteer_brain_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID REFERENCES volunteers(volunteer_id),
    
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB NOT NULL,
    
    processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP,
    brain_decision VARCHAR(20),
    brain_action TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vbe_volunteer ON volunteer_brain_events(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_vbe_type ON volunteer_brain_events(event_type);
CREATE INDEX IF NOT EXISTS idx_vbe_processed ON volunteer_brain_events(processed);

-- ============================================================================
-- VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW v_volunteer_summary AS
SELECT 
    v.volunteer_id,
    v.first_name,
    v.last_name,
    v.email,
    v.phone,
    v.city,
    v.county,
    
    v.capacity_grade || '-' || v.reliability_grade || '-' || v.skill_level::TEXT as grade_3d,
    v.composite_score,
    
    v.total_hours,
    v.total_shifts,
    v.shifts_completed,
    v.no_shows,
    CASE WHEN v.total_shifts > 0 
         THEN ROUND((v.shifts_completed::DECIMAL / v.total_shifts) * 100, 1)
         ELSE 0 END as completion_rate,
    
    v.doors_knocked,
    v.calls_made,
    v.texts_sent,
    v.voters_registered,
    
    v.total_points,
    v.current_level,
    v.badges_earned,
    v.current_streak,
    
    v.churn_risk,
    v.engagement_score,
    v.leadership_potential,
    
    t.name as team_name,
    v.is_team_leader,
    
    v.status,
    v.last_contact_date,
    v.created_at as joined_at

FROM volunteers v
LEFT JOIN volunteer_teams t ON v.team_id = t.team_id;

CREATE OR REPLACE VIEW v_shift_availability AS
SELECT 
    s.shift_id,
    s.title,
    s.activity_code,
    s.shift_date,
    s.start_time,
    s.end_time,
    s.location_name,
    s.is_virtual,
    s.slots_total,
    s.slots_filled,
    s.slots_total - s.slots_filled as slots_available,
    s.base_points,
    s.status
FROM volunteer_shifts s
WHERE s.status = 'scheduled'
  AND s.shift_date >= CURRENT_DATE
  AND s.slots_filled < s.slots_total
ORDER BY s.shift_date, s.start_time;

CREATE OR REPLACE VIEW v_top_volunteers AS
SELECT 
    v.volunteer_id,
    v.first_name || ' ' || v.last_name as name,
    v.composite_score,
    v.total_hours,
    v.total_points,
    v.doors_knocked,
    v.calls_made,
    v.badges_earned,
    v.current_streak,
    ROW_NUMBER() OVER (ORDER BY v.total_points DESC) as points_rank,
    ROW_NUMBER() OVER (ORDER BY v.total_hours DESC) as hours_rank,
    ROW_NUMBER() OVER (ORDER BY v.doors_knocked DESC) as doors_rank
FROM volunteers v
WHERE v.status = 'active'
ORDER BY v.total_points DESC;

CREATE OR REPLACE VIEW v_volunteer_dashboard AS
SELECT 
    va.account_id,
    va.volunteer_id,
    va.display_name,
    va.points,
    va.level,
    va.current_streak,
    
    COALESCE(SUM(vs.hours_worked), 0) as total_hours,
    COUNT(DISTINCT vs.signup_id) FILTER (WHERE vs.status = 'completed') as shifts_completed,
    COALESCE(SUM(vs.doors_knocked), 0) as total_doors,
    COALESCE(SUM(vs.calls_made), 0) as total_calls,
    COALESCE(SUM(vs.points_earned), 0) as total_points_earned,
    
    (SELECT COUNT(*) FROM volunteer_achievement_earnings ae 
     WHERE ae.account_id = va.account_id) as badge_count,
    
    (SELECT COUNT(*) FROM volunteer_signups s 
     JOIN volunteer_opportunities o ON s.opportunity_id = o.opportunity_id
     WHERE s.account_id = va.account_id 
     AND s.status = 'confirmed'
     AND o.start_datetime > NOW()) as upcoming_shifts

FROM volunteer_accounts va
LEFT JOIN volunteer_signups vs ON va.account_id = vs.account_id
GROUP BY va.account_id;

CREATE OR REPLACE VIEW v_volunteer_leaderboard AS
SELECT 
    va.account_id,
    va.display_name,
    va.points,
    va.level,
    COALESCE(SUM(vs.hours_worked), 0) as total_hours,
    COALESCE(SUM(vs.doors_knocked), 0) as total_doors,
    COALESCE(SUM(vs.calls_made), 0) as total_calls,
    COUNT(DISTINCT vs.signup_id) FILTER (WHERE vs.status = 'completed') as shifts_completed,
    ROW_NUMBER() OVER (ORDER BY va.points DESC) as rank
FROM volunteer_accounts va
LEFT JOIN volunteer_signups vs ON va.account_id = vs.account_id
GROUP BY va.account_id
ORDER BY va.points DESC;

CREATE OR REPLACE VIEW v_available_opportunities AS
SELECT 
    o.*,
    o.max_volunteers - o.current_signups as spots_remaining
FROM volunteer_opportunities o
WHERE o.status = 'open'
  AND o.start_datetime > NOW()
  AND (o.max_volunteers IS NULL OR o.current_signups < o.max_volunteers)
ORDER BY o.start_datetime;

-- ============================================================================
-- SEED DATA: BADGES
-- ============================================================================

INSERT INTO volunteer_badge_definitions (code, name, description, badge_type, criteria_field, criteria_value, points_reward, rarity)
VALUES
    ('FIRST_SHIFT', 'First Shift', 'Complete your first volunteer shift', 'milestone', 'shifts_completed', 1, 50, 'common'),
    ('HOURS_10', '10 Hour Club', 'Log 10 volunteer hours', 'milestone', 'total_hours', 10, 100, 'common'),
    ('HOURS_50', '50 Hour Hero', 'Log 50 volunteer hours', 'milestone', 'total_hours', 50, 250, 'uncommon'),
    ('HOURS_100', 'Century Volunteer', 'Log 100 volunteer hours', 'milestone', 'total_hours', 100, 500, 'rare'),
    ('HOURS_500', 'Elite Volunteer', 'Log 500 volunteer hours', 'milestone', 'total_hours', 500, 2000, 'epic'),
    ('DOORS_100', 'Door Dasher', 'Knock 100 doors', 'activity', 'doors_knocked', 100, 200, 'uncommon'),
    ('DOORS_500', 'Neighborhood Champion', 'Knock 500 doors', 'activity', 'doors_knocked', 500, 500, 'rare'),
    ('DOORS_1000', 'Door Warrior', 'Knock 1000 doors', 'activity', 'doors_knocked', 1000, 1000, 'epic'),
    ('CALLS_100', 'Phone Pro', 'Make 100 calls', 'activity', 'calls_made', 100, 200, 'uncommon'),
    ('CALLS_500', 'Call Center Champion', 'Make 500 calls', 'activity', 'calls_made', 500, 500, 'rare'),
    ('STREAK_7', 'Weekly Warrior', '7-day volunteer streak', 'streak', 'current_streak', 7, 300, 'uncommon'),
    ('STREAK_30', 'Monthly Master', '30-day volunteer streak', 'streak', 'current_streak', 30, 1000, 'epic'),
    ('POINTS_1000', 'Point Collector', 'Earn 1000 points', 'milestone', 'total_points', 1000, 100, 'common'),
    ('POINTS_5000', 'Point Champion', 'Earn 5000 points', 'milestone', 'total_points', 5000, 300, 'uncommon'),
    ('POINTS_10000', 'Point Legend', 'Earn 10000 points', 'milestone', 'total_points', 10000, 500, 'legendary'),
    ('RECRUITER', 'Recruiter', 'Recruit 5 new volunteers', 'special', 'recruits', 5, 500, 'rare'),
    ('TEAM_LEADER', 'Team Leader', 'Become a team leader', 'special', 'is_team_leader', 1, 1000, 'rare')
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- SEED DATA: ACHIEVEMENTS (Portal)
-- ============================================================================

INSERT INTO volunteer_achievements (name, description, achievement_type, criteria_type, criteria_value, points_reward, rarity)
VALUES
    ('Getting Started', 'Sign up for your first shift', 'milestone', 'shifts', 1, 25, 'common'),
    ('Regular', 'Complete 5 shifts', 'milestone', 'shifts', 5, 100, 'common'),
    ('Dedicated', 'Complete 25 shifts', 'milestone', 'shifts', 25, 500, 'uncommon'),
    ('Super Volunteer', 'Complete 100 shifts', 'milestone', 'shifts', 100, 2000, 'epic'),
    ('Time Keeper', 'Log 50 hours', 'milestone', 'hours', 50, 300, 'uncommon'),
    ('Door Opener', 'Knock 200 doors', 'activity', 'doors', 200, 400, 'uncommon'),
    ('Caller ID', 'Make 200 calls', 'activity', 'calls', 200, 400, 'uncommon')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- END SCHEMA
-- ============================================================================
