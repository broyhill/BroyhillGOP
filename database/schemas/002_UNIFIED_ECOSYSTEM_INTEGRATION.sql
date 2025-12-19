-- ============================================================================
-- BROYHILLGOP MASTER UNIFIED ECOSYSTEM INTEGRATION
-- Run AFTER base faction schema and Laravel migrations complete
-- November 27, 2025
-- ============================================================================
-- 
-- PREREQUISITES (must be done first):
--   1. psql -f sql/001_UNIFIED_FACTION_SCHEMA.sql
--   2. php artisan migrate
--   3. php artisan db:seed --class=CandidateProfileQuestionSeeder
--
-- THIS FILE integrates:
--   • Ecosystem 1: Donor Intelligence (860 fields)
--   • Ecosystem 7: Candidate Profiles (273 fields)  
--   • Ecosystem 3: Campaign Engine (22 campaign types)
--   • Ecosystem 4: ML Optimization
--   • Ecosystem 5: EAGLE Execution
--   • Ecosystem 6: DATAHUB Central
--
-- ============================================================================

-- ============================================================================
-- PART 1: ADD FACTION COLUMNS TO EXISTING TABLES
-- ============================================================================

-- Add faction columns to candidate_profiles (Ecosystem 7)
ALTER TABLE candidate_profiles 
ADD COLUMN IF NOT EXISTS primary_type VARCHAR(4),
ADD COLUMN IF NOT EXISTS secondary_type VARCHAR(4),
ADD COLUMN IF NOT EXISTS tertiary_type VARCHAR(4),
ADD COLUMN IF NOT EXISTS maga_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS evan_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS trad_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS fisc_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS libt_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS busi_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS laws_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS popf_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS modg_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS vets_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS chna_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS rual_intensity DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS faction_assigned_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS faction_assigned_by VARCHAR(50) DEFAULT 'questionnaire';

-- Add faction columns to donors table (Ecosystem 1)
ALTER TABLE donors
ADD COLUMN IF NOT EXISTS primary_faction VARCHAR(4),
ADD COLUMN IF NOT EXISTS secondary_faction VARCHAR(4),
ADD COLUMN IF NOT EXISTS tertiary_faction VARCHAR(4),
ADD COLUMN IF NOT EXISTS faction_confidence DECIMAL(3,2) DEFAULT 0.50,
ADD COLUMN IF NOT EXISTS faction_calculated_at TIMESTAMP;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_candidate_primary_type ON candidate_profiles(primary_type);
CREATE INDEX IF NOT EXISTS idx_candidate_faction_assigned ON candidate_profiles(faction_assigned_at);
CREATE INDEX IF NOT EXISTS idx_donor_primary_faction ON donors(primary_faction);
CREATE INDEX IF NOT EXISTS idx_donor_faction_calculated ON donors(faction_calculated_at);

-- ============================================================================
-- PART 2: CAMPAIGN ENGINE INTEGRATION (Ecosystem 3)
-- ============================================================================

-- Faction-specific message templates
CREATE TABLE IF NOT EXISTS faction_message_templates (
    id BIGSERIAL PRIMARY KEY,
    faction_code VARCHAR(4) NOT NULL REFERENCES faction_types(code),
    template_type VARCHAR(50) NOT NULL, -- 'email', 'sms', 'print', 'call_script', 'social'
    campaign_type VARCHAR(50) NOT NULL, -- 'solicitation', 'event_invite', 'thank_you', etc.
    
    -- Template content
    subject_line TEXT,
    opening_hook TEXT,
    body_template TEXT,
    cta_text VARCHAR(255),
    closing_text TEXT,
    ps_line TEXT,
    
    -- Tone and style
    tone_profile VARCHAR(50), -- 'fighter', 'faith_values', 'professional', 'honor_duty'
    formality_level VARCHAR(20) DEFAULT 'standard', -- 'casual', 'standard', 'formal'
    urgency_level VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    
    -- Personalization slots
    personalization_slots JSONB DEFAULT '[]'::jsonb,
    
    -- Performance tracking
    times_used INT DEFAULT 0,
    avg_open_rate DECIMAL(5,4) DEFAULT 0,
    avg_click_rate DECIMAL(5,4) DEFAULT 0,
    avg_conversion_rate DECIMAL(5,4) DEFAULT 0,
    
    -- Metadata
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_faction_template UNIQUE (faction_code, template_type, campaign_type)
);

-- Insert base faction templates
INSERT INTO faction_message_templates (faction_code, template_type, campaign_type, subject_line, opening_hook, cta_text, tone_profile) VALUES
-- MAGA templates
('MAGA', 'email', 'solicitation', '🇺🇸 {candidate_name} is Fighting for America First', 'The establishment doesn''t want {candidate_name} to win. That''s exactly why we need your help.', 'Join the MAGA movement', 'fighter'),
('MAGA', 'sms', 'solicitation', NULL, 'PATRIOT ALERT: Trump-endorsed {candidate_name} needs you. Fight back: {link}', 'Donate now', 'fighter'),
('MAGA', 'email', 'event_invite', 'Rally with {candidate_name} - America First Event', 'President Trump knows {candidate_name} will fight for us. Join fellow patriots at our upcoming rally.', 'RSVP for the rally', 'fighter'),

-- EVAN templates
('EVAN', 'email', 'solicitation', 'Defending Faith & Family: {candidate_name} for {office}', 'As believers, we''re called to be salt and light. {candidate_name} shares our commitment to protecting the unborn and defending religious liberty.', 'Stand for life', 'faith_values'),
('EVAN', 'sms', 'solicitation', NULL, 'PRAYER REQUEST: Pro-life champion {candidate_name} needs your support. Help defend our values: {link}', 'Give today', 'faith_values'),
('EVAN', 'email', 'event_invite', 'Faith & Freedom Event with {candidate_name}', 'Join fellow believers as {candidate_name} shares their vision for protecting our Christian values in {district}.', 'Register for event', 'faith_values'),

-- TRAD templates
('TRAD', 'email', 'solicitation', '{candidate_name}: Proven Conservative Leadership for {district}', '{candidate_name} has a proven track record of conservative governance. In uncertain times, experience matters.', 'Support proven leadership', 'professional'),
('TRAD', 'sms', 'solicitation', NULL, '{candidate_name} for {office}: Conservative leadership you can trust. Support today: {link}', 'Contribute', 'professional'),
('TRAD', 'email', 'event_invite', 'Reception with {candidate_name}', 'You''re invited to an exclusive reception with {candidate_name}, a proven conservative leader for {district}.', 'RSVP now', 'professional'),

-- FISC templates
('FISC', 'email', 'solicitation', '{candidate_name}: Fighting for Fiscal Responsibility', 'Every dollar matters. {candidate_name} is committed to cutting wasteful spending and lowering your taxes.', 'Invest in fiscal sanity', 'data_driven'),
('FISC', 'sms', 'solicitation', NULL, 'TAX FIGHTER: {candidate_name} has a plan to cut spending. Help elect a fiscal conservative: {link}', 'Donate', 'data_driven'),

-- BUSI templates
('BUSI', 'email', 'solicitation', '{candidate_name}: Pro-Business Leadership for {district}', 'As a business leader, you understand the importance of pro-growth policies. {candidate_name} will fight for lower taxes and less regulation.', 'Back business-friendly leadership', 'professional'),
('BUSI', 'sms', 'solicitation', NULL, 'BUSINESS ALERT: {candidate_name} supports pro-growth policies. Help elect a business ally: {link}', 'Support now', 'professional'),

-- LAWS templates
('LAWS', 'email', 'solicitation', '{candidate_name}: Backing the Blue in {district}', 'Law and order starts with leaders who support our police. {candidate_name} stands with law enforcement.', 'Back the Blue', 'honor_duty'),
('LAWS', 'sms', 'solicitation', NULL, 'POLICE ENDORSED: {candidate_name} stands with law enforcement. Support a Law & Order candidate: {link}', 'Donate', 'honor_duty'),

-- VETS templates
('VETS', 'email', 'solicitation', 'Fellow Veteran {candidate_name} Needs Your Support', 'As veterans, we know what service means. {candidate_name} served our nation with honor - now they serve {district}.', 'Support a fellow veteran', 'honor_duty'),
('VETS', 'sms', 'solicitation', NULL, 'VETERANS: {candidate_name} served our country. Now help them serve {district}: {link}', 'Mission support', 'honor_duty'),

-- POPF templates  
('POPF', 'email', 'solicitation', '{candidate_name}: No More Politics as Usual', 'The career politicians have failed us. {candidate_name} is an outsider who will shake up the system.', 'Join the fight', 'fighter'),
('POPF', 'sms', 'solicitation', NULL, 'OUTSIDER ALERT: {candidate_name} is taking on the establishment. Join the fight: {link}', 'Fight back', 'fighter'),

-- MODG templates
('MODG', 'email', 'solicitation', '{candidate_name}: Common-Sense Conservative for {district}', '{candidate_name} believes in finding practical solutions that work for everyone in {district}.', 'Support pragmatic leadership', 'balanced'),
('MODG', 'sms', 'solicitation', NULL, '{candidate_name}: A reasonable conservative for {district}. Support common-sense leadership: {link}', 'Contribute', 'balanced'),

-- CHNA templates
('CHNA', 'email', 'solicitation', '{candidate_name}: Restoring America''s Christian Heritage', 'America was founded on Christian principles. {candidate_name} will fight to restore our nation''s moral foundation.', 'Defend our heritage', 'faith_nation'),
('CHNA', 'sms', 'solicitation', NULL, 'FAITH & FLAG: {candidate_name} stands for Christian values in government. Support the cause: {link}', 'Stand up', 'faith_nation'),

-- RUAL templates
('RUAL', 'email', 'solicitation', '{candidate_name}: Standing Up for Rural {state}', 'Our rural communities deserve a voice. {candidate_name} understands agriculture and will fight for our way of life.', 'Support rural values', 'down_to_earth'),
('RUAL', 'sms', 'solicitation', NULL, 'FARM BUREAU ENDORSED: {candidate_name} fights for rural NC. Support agriculture: {link}', 'Help today', 'down_to_earth')

ON CONFLICT (faction_code, template_type, campaign_type) DO UPDATE SET
    subject_line = EXCLUDED.subject_line,
    opening_hook = EXCLUDED.opening_hook,
    cta_text = EXCLUDED.cta_text,
    tone_profile = EXCLUDED.tone_profile;

-- Personal connection insertion templates
CREATE TABLE IF NOT EXISTS personal_connection_templates (
    id SERIAL PRIMARY KEY,
    connection_type VARCHAR(50) NOT NULL, -- 'geographic', 'military', 'educational', 'faith', 'professional'
    match_pattern VARCHAR(100) NOT NULL, -- 'same_county', 'same_branch', 'same_school', etc.
    template_text TEXT NOT NULL,
    priority INT DEFAULT 5,
    
    CONSTRAINT unique_connection_template UNIQUE (connection_type, match_pattern)
);

INSERT INTO personal_connection_templates (connection_type, match_pattern, template_text, priority) VALUES
-- Geographic connections
('geographic', 'same_county', 'As a fellow {county} County resident, you know the issues that matter here.', 1),
('geographic', 'same_city', 'Living in {city}, you understand what {candidate_name} is fighting for.', 2),
('geographic', 'in_district', 'As a constituent of {district}, your voice matters in this race.', 3),

-- Military connections
('military', 'both_veterans', 'Like you, {candidate_name} served our nation in uniform.', 1),
('military', 'same_branch', 'As fellow {branch} veterans, you and {candidate_name} share a special bond.', 2),
('military', 'combat_veterans', 'Both you and {candidate_name} know the sacrifice of combat service.', 1),

-- Educational connections
('educational', 'same_school', 'Fellow {school} alumni like yourself are rallying behind {candidate_name}.', 1),
('educational', 'same_conference', 'As a {conference} school alum, you''ll appreciate {candidate_name}''s background.', 3),

-- Faith connections
('faith', 'same_denomination', 'As fellow {denomination} members, we share {candidate_name}''s values.', 1),
('faith', 'same_tradition', 'Your shared {tradition} faith background connects you with {candidate_name}.', 2),
('faith', 'same_church', 'As members of {church_name}, you know {candidate_name}''s character firsthand.', 1),

-- Professional connections
('professional', 'same_industry', 'Working in {industry}, you understand why {candidate_name}''s policies matter.', 2),
('professional', 'same_profession', 'As a fellow {profession}, you appreciate {candidate_name}''s expertise.', 1),
('professional', 'business_owner', 'As business owners, you and {candidate_name} know what it takes to succeed.', 2)

ON CONFLICT (connection_type, match_pattern) DO NOTHING;

-- ============================================================================
-- PART 3: ML OPTIMIZATION ENGINE (Ecosystem 4)
-- ============================================================================

-- Campaign performance tracking by faction
CREATE TABLE IF NOT EXISTS campaign_faction_performance (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT,
    message_id BIGINT,
    
    -- Donor/Candidate context
    donor_id BIGINT REFERENCES donors(id),
    candidate_id BIGINT,
    donor_faction VARCHAR(4) REFERENCES faction_types(code),
    candidate_type VARCHAR(4) REFERENCES faction_types(code),
    affinity_score DECIMAL(5,2),
    match_quality VARCHAR(15),
    
    -- Campaign details
    channel VARCHAR(20) NOT NULL, -- 'email', 'sms', 'print', 'call'
    template_id BIGINT REFERENCES faction_message_templates(id),
    tone_profile VARCHAR(50),
    
    -- Timing
    sent_at TIMESTAMP NOT NULL,
    day_of_week INT, -- 0=Sunday, 6=Saturday
    hour_of_day INT, -- 0-23
    
    -- A/B test variants
    subject_variant VARCHAR(255),
    cta_variant VARCHAR(100),
    
    -- Engagement metrics
    delivered BOOLEAN DEFAULT FALSE,
    delivered_at TIMESTAMP,
    opened BOOLEAN DEFAULT FALSE,
    opened_at TIMESTAMP,
    clicked BOOLEAN DEFAULT FALSE,
    clicked_at TIMESTAMP,
    
    -- Conversion metrics
    responded BOOLEAN DEFAULT FALSE,
    responded_at TIMESTAMP,
    donated BOOLEAN DEFAULT FALSE,
    donated_at TIMESTAMP,
    donation_amount DECIMAL(10,2) DEFAULT 0,
    
    -- Unsubscribe/bounce
    bounced BOOLEAN DEFAULT FALSE,
    unsubscribed BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for ML queries
CREATE INDEX IF NOT EXISTS idx_cfp_faction_channel ON campaign_faction_performance(donor_faction, channel);
CREATE INDEX IF NOT EXISTS idx_cfp_performance ON campaign_faction_performance(donor_faction, donated, donation_amount);
CREATE INDEX IF NOT EXISTS idx_cfp_timing ON campaign_faction_performance(donor_faction, day_of_week, hour_of_day);
CREATE INDEX IF NOT EXISTS idx_cfp_sent_at ON campaign_faction_performance(sent_at);

-- ML optimization parameters by faction
CREATE TABLE IF NOT EXISTS faction_optimization_params (
    id SERIAL PRIMARY KEY,
    faction_code VARCHAR(4) NOT NULL REFERENCES faction_types(code),
    
    -- Optimal channel (learned from data)
    optimal_channel VARCHAR(20) DEFAULT 'email',
    channel_confidence DECIMAL(3,2) DEFAULT 0.50,
    
    -- Email stats
    email_open_rate DECIMAL(5,4) DEFAULT 0.20,
    email_click_rate DECIMAL(5,4) DEFAULT 0.03,
    email_conversion_rate DECIMAL(5,4) DEFAULT 0.01,
    email_avg_donation DECIMAL(10,2) DEFAULT 50.00,
    
    -- SMS stats
    sms_response_rate DECIMAL(5,4) DEFAULT 0.05,
    sms_conversion_rate DECIMAL(5,4) DEFAULT 0.02,
    sms_avg_donation DECIMAL(10,2) DEFAULT 35.00,
    
    -- Print stats
    print_response_rate DECIMAL(5,4) DEFAULT 0.02,
    print_conversion_rate DECIMAL(5,4) DEFAULT 0.015,
    print_avg_donation DECIMAL(10,2) DEFAULT 100.00,
    
    -- Call stats
    call_answer_rate DECIMAL(5,4) DEFAULT 0.15,
    call_conversion_rate DECIMAL(5,4) DEFAULT 0.08,
    call_avg_donation DECIMAL(10,2) DEFAULT 150.00,
    
    -- Optimal timing
    optimal_day_of_week INT DEFAULT 2, -- Tuesday
    optimal_hour INT DEFAULT 18, -- 6 PM
    timing_confidence DECIMAL(3,2) DEFAULT 0.50,
    
    -- Optimal frequency
    min_days_between_contacts INT DEFAULT 7,
    max_contacts_per_month INT DEFAULT 4,
    
    -- Sample size
    total_sends INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_faction_params UNIQUE (faction_code)
);

-- Insert default optimization parameters
INSERT INTO faction_optimization_params (faction_code, optimal_channel, optimal_day_of_week, optimal_hour) VALUES
('MAGA', 'sms', 2, 19),      -- Tuesday 7pm, SMS preferred
('EVAN', 'email', 0, 14),    -- Sunday 2pm (after church), Email preferred
('TRAD', 'email', 3, 10),    -- Wednesday 10am, Email preferred
('FISC', 'email', 1, 8),     -- Monday 8am, Email preferred
('LIBT', 'email', 4, 20),    -- Thursday 8pm, Email preferred
('BUSI', 'email', 2, 9),     -- Tuesday 9am, Email preferred
('LAWS', 'sms', 2, 18),      -- Tuesday 6pm, SMS preferred
('POPF', 'sms', 2, 20),      -- Tuesday 8pm, SMS preferred
('MODG', 'email', 3, 12),    -- Wednesday noon, Email preferred
('VETS', 'sms', 2, 18),      -- Tuesday 6pm, SMS preferred
('CHNA', 'email', 0, 15),    -- Sunday 3pm, Email preferred
('RUAL', 'sms', 6, 7)        -- Saturday 7am, SMS preferred
ON CONFLICT (faction_code) DO NOTHING;

-- ============================================================================
-- PART 4: EAGLE EXECUTION INTEGRATION (Ecosystem 5)
-- ============================================================================

-- Campaign queue with faction optimization
CREATE TABLE IF NOT EXISTS campaign_queue (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT NOT NULL,
    
    -- Target
    donor_id BIGINT NOT NULL REFERENCES donors(id),
    candidate_id BIGINT,
    
    -- Faction context
    donor_faction VARCHAR(4) REFERENCES faction_types(code),
    candidate_type VARCHAR(4) REFERENCES faction_types(code),
    affinity_score DECIMAL(5,2),
    
    -- Delivery settings (from ML optimization)
    channel VARCHAR(20) NOT NULL,
    template_id BIGINT REFERENCES faction_message_templates(id),
    scheduled_at TIMESTAMP NOT NULL,
    priority INT DEFAULT 5, -- 1=highest, 5=lowest
    
    -- Generated content
    subject_line TEXT,
    message_body TEXT,
    cta_url VARCHAR(500),
    
    -- Personal connections to include
    personal_connections JSONB DEFAULT '[]'::jsonb,
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'processing', 'sent', 'failed', 'cancelled'
    attempts INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    
    -- Delivery confirmation
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    delivery_id VARCHAR(255), -- External delivery service ID
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for queue processing
CREATE INDEX IF NOT EXISTS idx_queue_status ON campaign_queue(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_queue_donor ON campaign_queue(donor_id);
CREATE INDEX IF NOT EXISTS idx_queue_priority ON campaign_queue(priority, scheduled_at);

-- ============================================================================
-- PART 5: DATAHUB INTEGRATION (Ecosystem 6)
-- ============================================================================

-- Unified donor-candidate matching view
CREATE OR REPLACE VIEW v_donor_candidate_matches AS
SELECT 
    d.id AS donor_id,
    CONCAT(d.first_name, ' ', d.last_name) AS donor_name,
    d.email AS donor_email,
    d.county AS donor_county,
    d.primary_faction,
    dfs.maga_score, dfs.evan_score, dfs.trad_score, dfs.fisc_score,
    dfs.libt_score, dfs.busi_score, dfs.laws_score, dfs.popf_score,
    dfs.modg_score, dfs.vets_score, dfs.chna_score, dfs.rual_score,
    
    cp.id AS candidate_id,
    cp.full_name AS candidate_name,
    cp.target_office,
    cp.district AS candidate_district,
    cp.primary_type AS candidate_type,
    
    -- Affinity scores (from cache or calculated)
    COALESCE(dca.faction_affinity_score, 
        (SELECT affinity_score FROM faction_affinity_matrix 
         WHERE donor_faction = d.primary_faction 
         AND candidate_type = cp.primary_type)) AS faction_affinity,
    COALESCE(dca.personal_affinity_score, 50) AS personal_affinity,
    COALESCE(dca.combined_affinity_score,
        (COALESCE(dca.faction_affinity_score, 50) * 0.60) + 
        (COALESCE(dca.personal_affinity_score, 50) * 0.40)) AS combined_affinity,
    COALESCE(dca.match_quality, 'PENDING') AS match_quality,
    
    -- Optimal campaign settings
    fop.optimal_channel,
    fop.optimal_day_of_week,
    fop.optimal_hour
    
FROM donors d
LEFT JOIN donor_faction_scores dfs ON d.id = dfs.donor_id
CROSS JOIN candidate_profiles cp
LEFT JOIN donor_candidate_affinity dca ON d.id = dca.donor_id AND cp.id = dca.candidate_id
LEFT JOIN faction_optimization_params fop ON d.primary_faction = fop.faction_code
WHERE d.primary_faction IS NOT NULL
  AND cp.primary_type IS NOT NULL;

-- Campaign performance summary by faction
CREATE OR REPLACE VIEW v_faction_campaign_performance AS
SELECT 
    ft.code AS faction_code,
    ft.name AS faction_name,
    cfp.channel,
    COUNT(*) AS total_sends,
    SUM(CASE WHEN cfp.opened THEN 1 ELSE 0 END) AS opens,
    SUM(CASE WHEN cfp.clicked THEN 1 ELSE 0 END) AS clicks,
    SUM(CASE WHEN cfp.donated THEN 1 ELSE 0 END) AS conversions,
    SUM(cfp.donation_amount) AS total_raised,
    ROUND(AVG(CASE WHEN cfp.opened THEN 1.0 ELSE 0.0 END) * 100, 2) AS open_rate_pct,
    ROUND(AVG(CASE WHEN cfp.clicked THEN 1.0 ELSE 0.0 END) * 100, 2) AS click_rate_pct,
    ROUND(AVG(CASE WHEN cfp.donated THEN 1.0 ELSE 0.0 END) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(cfp.donation_amount) FILTER (WHERE cfp.donated), 2) AS avg_donation
FROM faction_types ft
LEFT JOIN campaign_faction_performance cfp ON ft.code = cfp.donor_faction
GROUP BY ft.code, ft.name, cfp.channel
ORDER BY ft.code, cfp.channel;

-- ============================================================================
-- PART 6: STORED PROCEDURES FOR UNIFIED OPERATIONS
-- ============================================================================

-- Function: Generate optimal campaign for donor-candidate pair
CREATE OR REPLACE FUNCTION generate_campaign_message(
    p_donor_id BIGINT,
    p_candidate_id BIGINT
) RETURNS TABLE (
    channel VARCHAR(20),
    subject_line TEXT,
    opening_hook TEXT,
    personal_connections TEXT[],
    cta_text VARCHAR(255),
    tone_profile VARCHAR(50),
    scheduled_day INT,
    scheduled_hour INT
) AS $$
DECLARE
    v_donor_faction VARCHAR(4);
    v_candidate_type VARCHAR(4);
    v_template RECORD;
    v_params RECORD;
    v_connections TEXT[] := '{}';
BEGIN
    -- Get faction info
    SELECT primary_faction INTO v_donor_faction FROM donors WHERE id = p_donor_id;
    SELECT primary_type INTO v_candidate_type FROM candidate_profiles WHERE id = p_candidate_id;
    
    -- Get optimal parameters
    SELECT * INTO v_params FROM faction_optimization_params WHERE faction_code = v_donor_faction;
    
    -- Get template
    SELECT * INTO v_template 
    FROM faction_message_templates 
    WHERE faction_code = v_donor_faction 
      AND template_type = v_params.optimal_channel
      AND campaign_type = 'solicitation'
      AND active = TRUE
    LIMIT 1;
    
    -- Build personal connections array
    -- (In production, this would query actual matches)
    
    RETURN QUERY SELECT 
        v_params.optimal_channel,
        v_template.subject_line,
        v_template.opening_hook,
        v_connections,
        v_template.cta_text,
        v_template.tone_profile,
        v_params.optimal_day_of_week,
        v_params.optimal_hour;
END;
$$ LANGUAGE plpgsql;

-- Function: Update ML parameters from performance data
CREATE OR REPLACE FUNCTION update_faction_optimization_params(
    p_faction_code VARCHAR(4)
) RETURNS VOID AS $$
DECLARE
    v_stats RECORD;
BEGIN
    -- Calculate stats from last 90 days
    SELECT 
        -- Email stats
        AVG(CASE WHEN channel = 'email' AND opened THEN 1.0 ELSE 0.0 END) AS email_open,
        AVG(CASE WHEN channel = 'email' AND clicked THEN 1.0 ELSE 0.0 END) AS email_click,
        AVG(CASE WHEN channel = 'email' AND donated THEN 1.0 ELSE 0.0 END) AS email_conv,
        AVG(donation_amount) FILTER (WHERE channel = 'email' AND donated) AS email_avg,
        -- SMS stats
        AVG(CASE WHEN channel = 'sms' AND clicked THEN 1.0 ELSE 0.0 END) AS sms_resp,
        AVG(CASE WHEN channel = 'sms' AND donated THEN 1.0 ELSE 0.0 END) AS sms_conv,
        AVG(donation_amount) FILTER (WHERE channel = 'sms' AND donated) AS sms_avg,
        -- Best timing
        MODE() WITHIN GROUP (ORDER BY day_of_week) FILTER (WHERE donated) AS best_day,
        MODE() WITHIN GROUP (ORDER BY hour_of_day) FILTER (WHERE donated) AS best_hour,
        -- Sample size
        COUNT(*) AS total
    INTO v_stats
    FROM campaign_faction_performance
    WHERE donor_faction = p_faction_code
      AND sent_at > NOW() - INTERVAL '90 days';
    
    -- Update if enough data
    IF v_stats.total >= 100 THEN
        UPDATE faction_optimization_params SET
            email_open_rate = COALESCE(v_stats.email_open, email_open_rate),
            email_click_rate = COALESCE(v_stats.email_click, email_click_rate),
            email_conversion_rate = COALESCE(v_stats.email_conv, email_conversion_rate),
            email_avg_donation = COALESCE(v_stats.email_avg, email_avg_donation),
            sms_response_rate = COALESCE(v_stats.sms_resp, sms_response_rate),
            sms_conversion_rate = COALESCE(v_stats.sms_conv, sms_conversion_rate),
            sms_avg_donation = COALESCE(v_stats.sms_avg, sms_avg_donation),
            optimal_day_of_week = COALESCE(v_stats.best_day, optimal_day_of_week),
            optimal_hour = COALESCE(v_stats.best_hour, optimal_hour),
            total_sends = v_stats.total,
            last_updated = NOW()
        WHERE faction_code = p_faction_code;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Queue campaign for donor
CREATE OR REPLACE FUNCTION queue_donor_campaign(
    p_campaign_id BIGINT,
    p_donor_id BIGINT,
    p_candidate_id BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_donor RECORD;
    v_candidate RECORD;
    v_params RECORD;
    v_template RECORD;
    v_affinity DECIMAL(5,2);
    v_scheduled TIMESTAMP;
    v_queue_id BIGINT;
BEGIN
    -- Get donor info
    SELECT * INTO v_donor FROM donors WHERE id = p_donor_id;
    
    -- Get candidate info
    SELECT * INTO v_candidate FROM candidate_profiles WHERE id = p_candidate_id;
    
    -- Get optimization params
    SELECT * INTO v_params FROM faction_optimization_params WHERE faction_code = v_donor.primary_faction;
    
    -- Get template
    SELECT * INTO v_template 
    FROM faction_message_templates 
    WHERE faction_code = v_donor.primary_faction 
      AND template_type = v_params.optimal_channel
      AND campaign_type = 'solicitation'
    LIMIT 1;
    
    -- Get affinity score
    SELECT affinity_score INTO v_affinity
    FROM faction_affinity_matrix
    WHERE donor_faction = v_donor.primary_faction 
      AND candidate_type = v_candidate.primary_type;
    
    -- Calculate scheduled time (next optimal day/hour)
    v_scheduled := NOW() + INTERVAL '1 day'; -- Simplified; would calculate actual optimal time
    
    -- Insert into queue
    INSERT INTO campaign_queue (
        campaign_id, donor_id, candidate_id,
        donor_faction, candidate_type, affinity_score,
        channel, template_id, scheduled_at, priority,
        subject_line, message_body
    ) VALUES (
        p_campaign_id, p_donor_id, p_candidate_id,
        v_donor.primary_faction, v_candidate.primary_type, v_affinity,
        v_params.optimal_channel, v_template.id, v_scheduled,
        CASE WHEN v_affinity >= 85 THEN 1 WHEN v_affinity >= 70 THEN 2 ELSE 3 END,
        v_template.subject_line, v_template.opening_hook
    )
    RETURNING id INTO v_queue_id;
    
    RETURN v_queue_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 7: GRANT PERMISSIONS
-- ============================================================================

-- Uncomment and adjust for your environment
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO app_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_user;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check all tables created
SELECT 'Tables created:' AS status;
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'faction_message_templates',
    'personal_connection_templates', 
    'campaign_faction_performance',
    'faction_optimization_params',
    'campaign_queue'
);

-- Check templates loaded
SELECT 'Message templates by faction:' AS status;
SELECT faction_code, COUNT(*) as template_count 
FROM faction_message_templates 
GROUP BY faction_code 
ORDER BY faction_code;

-- Check optimization params
SELECT 'Optimization params:' AS status;
SELECT faction_code, optimal_channel, optimal_day_of_week, optimal_hour 
FROM faction_optimization_params 
ORDER BY faction_code;

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- 
-- NEXT STEPS:
--   1. Run batch donor faction scoring: php artisan donors:calculate-faction-scores
--   2. Run batch candidate faction inference: php artisan candidates:infer-factions  
--   3. Build affinity cache: php artisan affinity:calculate-all
--   4. Test campaign generation: SELECT * FROM generate_campaign_message(donor_id, candidate_id);
--
-- ============================================================================
