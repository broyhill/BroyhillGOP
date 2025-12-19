-- ============================================================================
-- BROYHILLGOP LOCAL CANDIDATE INTELLIGENCE SYSTEM - PART 3
-- Campaign Automation, ML Optimization, Templates
-- November 28, 2025
-- ============================================================================

-- ============================================================================
-- PART 15: LOCAL CAMPAIGN TEMPLATES (Office-Specific)
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_campaign_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Template Identity
    template_name VARCHAR(255) NOT NULL,
    template_code VARCHAR(50) UNIQUE NOT NULL,
    
    -- Office & Campaign Type
    office_type VARCHAR(10) REFERENCES local_office_types(code),
    campaign_type VARCHAR(50) NOT NULL,
    -- Types: 'announcement', 'endorsement', 'issue_response', 'fundraising',
    --        'event_invite', 'volunteer_recruit', 'gotv', 'thank_you',
    --        'news_response', 'opposition_contrast', 'vacancy_opportunity'
    
    -- Faction Targeting
    primary_faction VARCHAR(4) REFERENCES faction_types(code),
    faction_intensity_min INT DEFAULT 50,
    
    -- Channel Configuration
    channels JSONB DEFAULT '["email"]'::jsonb,
    email_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT FALSE,
    mail_enabled BOOLEAN DEFAULT FALSE,
    call_enabled BOOLEAN DEFAULT FALSE,
    
    -- Email Template
    email_subject VARCHAR(255),
    email_preheader VARCHAR(255),
    email_body TEXT,
    email_cta_text VARCHAR(100),
    email_cta_url VARCHAR(500),
    email_ps_line TEXT,
    
    -- SMS Template (160 char limit)
    sms_template VARCHAR(500),
    
    -- Call Script
    call_script_intro TEXT,
    call_script_body TEXT,
    call_script_ask TEXT,
    call_script_close TEXT,
    
    -- Personalization
    personalization_fields JSONB DEFAULT '[]'::jsonb,
    dynamic_content_rules JSONB DEFAULT '{}'::jsonb,
    
    -- Tone Configuration
    tone_profile VARCHAR(50), -- 'fighter', 'faith_values', 'professional', 'honor_duty', 'grassroots'
    formality_level VARCHAR(20) DEFAULT 'standard',
    urgency_level VARCHAR(20) DEFAULT 'medium',
    
    -- Audience Defaults
    default_audience_criteria JSONB DEFAULT '{}'::jsonb,
    min_affinity_score INT DEFAULT 50,
    geographic_scope VARCHAR(20) DEFAULT 'county', -- 'precinct', 'county', 'district', 'statewide'
    
    -- Timing Configuration
    recommended_response_hours INT DEFAULT 24,
    optimal_send_days JSONB DEFAULT '["tuesday", "wednesday", "thursday"]'::jsonb,
    optimal_send_times JSONB DEFAULT '["9:00", "10:00", "14:00"]'::jsonb,
    
    -- Media Integration
    include_press_release BOOLEAN DEFAULT FALSE,
    press_release_template TEXT,
    social_post_template VARCHAR(500),
    
    -- Performance Tracking
    times_used INT DEFAULT 0,
    avg_open_rate DECIMAL(5,4) DEFAULT 0,
    avg_click_rate DECIMAL(5,4) DEFAULT 0,
    avg_donation_rate DECIMAL(5,4) DEFAULT 0,
    avg_donation_amount NUMERIC(10,2),
    total_raised NUMERIC(12,2) DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    approved_by VARCHAR(100),
    approved_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert office-specific templates
INSERT INTO local_campaign_templates (template_code, template_name, office_type, campaign_type, primary_faction, email_subject, email_body, email_cta_text, tone_profile) VALUES

-- SHERIFF TEMPLATES
('SHERIFF_ANNOUNCE', 'Sheriff Candidate Announcement', 'SHERIFF', 'announcement', 'LAWS',
 '🚔 {candidate_name} is Running for {county} Sheriff',
 'Dear {donor_name},

I''m writing to share exciting news: {candidate_name} has announced their candidacy for {county} County Sheriff.

With {experience_years} years of law enforcement experience, {candidate_first_name} knows what it takes to keep our community safe. As a {endorsement_highlight}, {he_she} has earned the trust of officers and citizens alike.

{county} County deserves a Sheriff who will:
• Back the Blue and support our deputies
• Crack down on drug trafficking
• Protect our 2nd Amendment rights
• Enforce ALL laws, including immigration

Will you be one of the first to support this campaign?

{cta_button}

Your early contribution of {ask_amount} will help {candidate_first_name} build the campaign infrastructure needed to win.

For {county} County,
{signature}

P.S. {candidate_name} has been endorsed by {endorsement_list}. Join them in supporting law and order in {county} County.',
 'Back {candidate_first_name}', 'honor_duty'),

('SHERIFF_CRIME', 'Sheriff Crime Response', 'SHERIFF', 'news_response', 'LAWS',
 '⚠️ Crime in {county} - We Need {candidate_name}',
 'Dear {donor_name},

Did you see the news? {news_headline}

This is exactly why {county} County needs strong leadership in the Sheriff''s office.

{candidate_name} has a plan to:
• Increase patrol presence in affected areas
• Work with federal agencies on serious crimes
• Support deputies with proper resources
• Hold criminals accountable

The current approach isn''t working. {candidate_first_name} will bring real change.

{cta_button}

Your gift of {ask_amount} will help us get this message to every voter in {county} County.

Stay safe,
{signature}',
 'Donate Now', 'fighter'),

-- SCHOOL BOARD TEMPLATES
('SCHBRD_ANNOUNCE', 'School Board Candidate Announcement', 'SCHBRD', 'announcement', 'EVAN',
 '📚 {candidate_name} for {county} School Board - Parents First',
 'Dear {donor_name},

As a parent and concerned citizen, I''m thrilled that {candidate_name} is running for the {county} School Board.

{candidate_first_name} believes that PARENTS - not bureaucrats - should have the final say in their children''s education.

{he_she_cap} will fight for:
• Curriculum transparency for parents
• Removing inappropriate materials from schools
• Academic excellence over political agendas
• Protecting parental rights

{children_detail}

Will you stand with {candidate_first_name} for our children?

{cta_button}

Every dollar helps us reach more parents with this message.

For our kids,
{signature}

P.S. School board races are decided by just a few hundred votes. Your support RIGHT NOW can make the difference.',
 'Protect Our Schools', 'faith_values'),

('SCHBRD_CURRICULUM', 'School Board Curriculum Response', 'SCHBRD', 'news_response', 'EVAN',
 '🚨 {county} Parents - Have You Seen What''s in Our Schools?',
 'Dear {donor_name},

Shocking news: {news_headline}

This is EXACTLY why we need {candidate_name} on the {county} School Board.

{candidate_first_name} will:
• Demand full transparency in curriculum
• Give parents the right to review ALL materials
• Remove age-inappropriate content
• Focus on reading, math, and real education

Our children deserve better. {candidate_first_name} will fight for them.

{cta_button}

Please give {ask_amount} today to help us win this fight for our kids.

Standing for families,
{signature}',
 'Take Action', 'fighter'),

-- COUNTY COMMISSIONER TEMPLATES
('COMMISH_ANNOUNCE', 'Commissioner Candidate Announcement', 'COMMISH', 'announcement', 'FISC',
 '{candidate_name} for {county} Commissioner - Lower Taxes, Better Services',
 'Dear {donor_name},

I''m pleased to share that {candidate_name} is running for {county} County Commissioner.

With a background in {occupation}, {candidate_first_name} understands that every tax dollar must be spent wisely.

{he_she_cap} will work to:
• Hold the line on property taxes
• Streamline county government
• Support local businesses
• Protect rural character while managing growth

{county} County needs commissioners who respect YOUR money.

{cta_button}

Your contribution of {ask_amount} will help us reach voters across {county} County.

For responsible government,
{signature}',
 'Support Fiscal Responsibility', 'professional'),

('COMMISH_TAX', 'Commissioner Tax Issue Response', 'COMMISH', 'news_response', 'FISC',
 '💰 {county} County Tax Hike? Not If We Can Help It!',
 'Dear {donor_name},

Breaking news: {news_headline}

{county} County families can''t afford another tax increase. {candidate_name} will fight to stop wasteful spending and protect your wallet.

As your Commissioner, {candidate_first_name} will:
• Vote NO on unnecessary tax increases
• Conduct a full audit of county spending
• Find efficiencies before asking for more money
• Prioritize essential services

{cta_button}

Help us send a fiscal conservative to the board. Give {ask_amount} today.

Protecting your hard-earned money,
{signature}',
 'Stop the Tax Hike', 'data_driven'),

-- DA TEMPLATES
('DA_ANNOUNCE', 'DA Candidate Announcement', 'DA', 'announcement', 'LAWS',
 '⚖️ {candidate_name} for District Attorney - Justice for Victims',
 'Dear {donor_name},

{candidate_name} has announced their candidacy for District Attorney in {district}.

As a prosecutor with {experience_years} years of experience, {candidate_first_name} has put dangerous criminals behind bars and stood up for victims.

Unlike soft-on-crime prosecutors in other districts, {he_she} will:
• Prosecute violent criminals to the fullest extent
• Oppose no-cash bail for dangerous offenders  
• Support law enforcement, not undermine them
• Prioritize victim rights

{cta_button}

Help us elect a DA who believes in REAL justice. Give {ask_amount} today.

For law and order,
{signature}',
 'Support Real Justice', 'honor_duty'),

-- MAYOR TEMPLATES
('MAYOR_ANNOUNCE', 'Mayor Candidate Announcement', 'MAYOR', 'announcement', 'BUSI',
 '{candidate_name} for Mayor of {municipality} - Growth & Prosperity',
 'Dear {donor_name},

{candidate_name} is running for Mayor of {municipality}, and I wanted you to be among the first to know.

{candidate_first_name} has the business experience and vision to lead {municipality} into a prosperous future.

{he_she_cap} will focus on:
• Attracting new businesses and jobs
• Keeping taxes competitive
• Maintaining public safety
• Managing growth responsibly

{municipality} needs a mayor who understands economics, not just politics.

{cta_button}

Your investment of {ask_amount} will help us build a winning campaign.

For {municipality}''s future,
{signature}',
 'Invest in Our City', 'professional'),

-- CITY COUNCIL TEMPLATES
('COUNCIL_ANNOUNCE', 'Council Candidate Announcement', 'COUNCIL', 'announcement', 'BUSI',
 '{candidate_name} for {municipality} City Council',
 'Dear {donor_name},

{candidate_name} is running for {municipality} City Council, and {he_she} needs your support.

As a {occupation} and longtime {municipality} resident, {candidate_first_name} knows our community''s needs.

{he_she_cap} will vote to:
• Keep property taxes low
• Support local businesses
• Maintain safe neighborhoods
• Ensure responsible development

{cta_button}

Even a small gift of {ask_amount} makes a big difference in local races.

For our neighborhood,
{signature}',
 'Support Local Leadership', 'grassroots'),

-- JUDGE TEMPLATES
('JUDGE_ANNOUNCE', 'Judge Candidate Announcement', 'JUDGE_SUP', 'announcement', 'TRAD',
 'Judge {candidate_name} for Superior Court',
 'Dear {donor_name},

{candidate_name} is seeking election to the Superior Court bench in {district}.

With {experience_years} years of legal experience, {candidate_first_name} has the temperament, knowledge, and conservative judicial philosophy our courts need.

{he_she_cap} believes in:
• Strict interpretation of the Constitution
• Holding criminals accountable
• Respecting the rule of law
• Judicial restraint, not activism

{cta_button}

Help elect a judge who will uphold the law, not rewrite it.

For justice,
{signature}',
 'Support Conservative Justice', 'professional')

ON CONFLICT (template_code) DO UPDATE SET
    template_name = EXCLUDED.template_name,
    email_subject = EXCLUDED.email_subject,
    email_body = EXCLUDED.email_body,
    updated_at = CURRENT_TIMESTAMP;

-- ============================================================================
-- PART 16: ML PERFORMANCE TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_campaign_performance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Campaign Identity
    campaign_id UUID,
    template_id UUID REFERENCES local_campaign_templates(id),
    candidate_id UUID REFERENCES local_candidates(id),
    
    -- Classification
    office_type VARCHAR(10) REFERENCES local_office_types(code),
    campaign_type VARCHAR(50),
    primary_faction VARCHAR(4) REFERENCES faction_types(code),
    
    -- Audience
    total_recipients INT DEFAULT 0,
    recipients_by_faction JSONB DEFAULT '{}'::jsonb,
    recipients_by_affinity JSONB DEFAULT '{}'::jsonb,
    avg_affinity_score DECIMAL(5,2),
    local_recipients_pct DECIMAL(5,2), -- % in same county
    
    -- Delivery Metrics
    emails_sent INT DEFAULT 0,
    emails_delivered INT DEFAULT 0,
    delivery_rate DECIMAL(5,4) DEFAULT 0,
    
    -- Engagement Metrics
    opens INT DEFAULT 0,
    open_rate DECIMAL(5,4) DEFAULT 0,
    unique_opens INT DEFAULT 0,
    clicks INT DEFAULT 0,
    click_rate DECIMAL(5,4) DEFAULT 0,
    click_to_open_rate DECIMAL(5,4) DEFAULT 0,
    
    -- Conversion Metrics
    donations INT DEFAULT 0,
    donation_rate DECIMAL(5,4) DEFAULT 0,
    total_raised NUMERIC(12,2) DEFAULT 0,
    avg_donation NUMERIC(10,2) DEFAULT 0,
    
    -- Performance by Faction
    performance_by_faction JSONB DEFAULT '{}'::jsonb,
    -- Format: {"MAGA": {"opens": 150, "clicks": 30, "donations": 5, "raised": 500}, ...}
    
    -- Performance by Affinity
    performance_by_affinity JSONB DEFAULT '{}'::jsonb,
    -- Format: {"EXCEPTIONAL": {...}, "STRONG": {...}, ...}
    
    -- Performance by Geography
    performance_by_county JSONB DEFAULT '{}'::jsonb,
    local_vs_outside_performance JSONB DEFAULT '{}'::jsonb,
    
    -- Timing Analysis
    best_open_hour INT,
    best_click_hour INT,
    best_donate_hour INT,
    
    -- Comparative Metrics
    vs_office_avg_open DECIMAL(5,2), -- % better/worse than office type avg
    vs_office_avg_donate DECIMAL(5,2),
    vs_faction_avg_open DECIMAL(5,2),
    vs_faction_avg_donate DECIMAL(5,2),
    
    -- ML Insights
    ml_effectiveness_score DECIMAL(5,2),
    ml_recommendations JSONB DEFAULT '[]'::jsonb,
    
    -- Metadata
    campaign_sent_at TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_campaign_performance UNIQUE (campaign_id)
);

-- ============================================================================
-- PART 17: ML OPTIMIZATION FUNCTIONS
-- ============================================================================

-- Function to get optimal audience for a local candidate
CREATE OR REPLACE FUNCTION get_optimal_local_audience(
    p_candidate_id UUID,
    p_campaign_type VARCHAR(50),
    p_max_recipients INT DEFAULT 1000
) RETURNS TABLE (
    donor_id BIGINT,
    donor_name VARCHAR,
    affinity_score DECIMAL(5,2),
    match_quality VARCHAR(15),
    faction VARCHAR(4),
    same_county BOOLEAN,
    predicted_response DECIMAL(5,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dlca.donor_id,
        d.first_name || ' ' || d.last_name,
        dlca.combined_score,
        dlca.match_quality,
        d.primary_faction,
        dlca.same_county,
        -- Predict response based on historical performance
        CASE 
            WHEN dlca.match_quality = 'EXCEPTIONAL' THEN 0.15
            WHEN dlca.match_quality = 'STRONG' THEN 0.10
            WHEN dlca.match_quality = 'GOOD' THEN 0.06
            WHEN dlca.match_quality = 'FAIR' THEN 0.03
            ELSE 0.01
        END * 
        CASE WHEN dlca.same_county THEN 1.5 ELSE 1.0 END
    FROM donor_local_candidate_affinity dlca
    JOIN donors d ON dlca.donor_id = d.id
    WHERE dlca.candidate_id = p_candidate_id
    AND dlca.combined_score >= 50
    ORDER BY 
        dlca.same_county DESC,  -- Prioritize local donors
        dlca.combined_score DESC
    LIMIT p_max_recipients;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get best template for candidate + audience
CREATE OR REPLACE FUNCTION get_best_template(
    p_candidate_id UUID,
    p_campaign_type VARCHAR(50)
) RETURNS UUID AS $$
DECLARE
    v_candidate RECORD;
    v_template_id UUID;
BEGIN
    SELECT * INTO v_candidate FROM local_candidates WHERE id = p_candidate_id;
    
    IF v_candidate IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Find best template by office type and faction
    SELECT id INTO v_template_id
    FROM local_campaign_templates
    WHERE is_active = TRUE
    AND campaign_type = p_campaign_type
    AND (office_type = v_candidate.office_type OR office_type IS NULL)
    AND (primary_faction = v_candidate.primary_faction OR primary_faction IS NULL)
    ORDER BY 
        CASE WHEN office_type = v_candidate.office_type THEN 1 ELSE 2 END,
        CASE WHEN primary_faction = v_candidate.primary_faction THEN 1 ELSE 2 END,
        avg_donation_rate DESC NULLS LAST
    LIMIT 1;
    
    RETURN v_template_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to calculate predicted campaign performance
CREATE OR REPLACE FUNCTION predict_campaign_performance(
    p_candidate_id UUID,
    p_template_id UUID,
    p_audience_size INT
) RETURNS TABLE (
    predicted_opens INT,
    predicted_clicks INT,
    predicted_donations INT,
    predicted_revenue NUMERIC(12,2),
    confidence DECIMAL(3,2)
) AS $$
DECLARE
    v_template RECORD;
    v_candidate RECORD;
    v_base_open_rate DECIMAL := 0.20;
    v_base_click_rate DECIMAL := 0.03;
    v_base_donate_rate DECIMAL := 0.02;
    v_base_avg_donation NUMERIC := 50;
BEGIN
    SELECT * INTO v_template FROM local_campaign_templates WHERE id = p_template_id;
    SELECT * INTO v_candidate FROM local_candidates WHERE id = p_candidate_id;
    
    -- Use historical performance if available
    IF v_template.times_used > 10 THEN
        v_base_open_rate := COALESCE(v_template.avg_open_rate, v_base_open_rate);
        v_base_click_rate := COALESCE(v_template.avg_click_rate, v_base_click_rate);
        v_base_donate_rate := COALESCE(v_template.avg_donation_rate, v_base_donate_rate);
        v_base_avg_donation := COALESCE(v_template.avg_donation_amount, v_base_avg_donation);
    END IF;
    
    -- Adjust based on candidate characteristics
    IF v_candidate.trump_endorsement THEN
        v_base_donate_rate := v_base_donate_rate * 1.3;
    END IF;
    
    IF v_candidate.is_incumbent THEN
        v_base_donate_rate := v_base_donate_rate * 1.2;
    END IF;
    
    RETURN QUERY SELECT
        (p_audience_size * v_base_open_rate)::INT,
        (p_audience_size * v_base_click_rate)::INT,
        (p_audience_size * v_base_donate_rate)::INT,
        (p_audience_size * v_base_donate_rate * v_base_avg_donation)::NUMERIC(12,2),
        CASE WHEN v_template.times_used > 50 THEN 0.85
             WHEN v_template.times_used > 10 THEN 0.70
             ELSE 0.50
        END::DECIMAL(3,2);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- PART 18: NEWS TRIGGER AUTOMATION
-- ============================================================================

-- Function to analyze news event and create triggers
CREATE OR REPLACE FUNCTION process_local_news_event(p_event_id UUID)
RETURNS INT AS $$
DECLARE
    v_event RECORD;
    v_candidates RECORD;
    v_trigger_count INT := 0;
    v_template RECORD;
BEGIN
    SELECT * INTO v_event FROM local_news_events WHERE id = p_event_id;
    
    IF v_event IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Find relevant candidates
    FOR v_candidates IN
        SELECT * FROM local_candidates
        WHERE county_name = v_event.county
        AND status IN ('filed', 'active')
        AND election_year >= EXTRACT(YEAR FROM CURRENT_DATE)
    LOOP
        -- Check if this event type is relevant to candidate's office
        IF v_event.event_type = 'crime_spike' AND v_candidates.office_type IN ('SHERIFF', 'DA') THEN
            -- Create trigger for crime response
            INSERT INTO local_news_triggers (
                news_event_id, trigger_name, trigger_type,
                target_county, target_office_type, target_candidate_id,
                primary_faction_target, faction_score_minimum,
                suggested_campaign_type, suggested_subject,
                response_window_hours, expires_at, priority, status
            ) VALUES (
                p_event_id, 
                'Crime Response: ' || v_event.headline,
                'crime_response',
                v_event.county, v_candidates.office_type, v_candidates.id,
                'LAWS', 60,
                'news_response',
                '⚠️ ' || v_event.county || ' Crime Alert - ' || v_candidates.full_name || ' Has a Plan',
                12,
                CURRENT_TIMESTAMP + INTERVAL '24 hours',
                8,
                'pending'
            );
            v_trigger_count := v_trigger_count + 1;
            
        ELSIF v_event.event_type = 'school_controversy' AND v_candidates.office_type = 'SCHBRD' THEN
            -- Create trigger for school issue response
            INSERT INTO local_news_triggers (
                news_event_id, trigger_name, trigger_type,
                target_county, target_office_type, target_candidate_id,
                primary_faction_target, faction_score_minimum,
                suggested_campaign_type, suggested_subject,
                response_window_hours, expires_at, priority, status
            ) VALUES (
                p_event_id,
                'School Response: ' || v_event.headline,
                'education_response',
                v_event.county, v_candidates.office_type, v_candidates.id,
                'EVAN', 60,
                'news_response',
                '🚨 ' || v_event.county || ' Parents - ' || v_candidates.full_name || ' Will Fight for Our Kids',
                12,
                CURRENT_TIMESTAMP + INTERVAL '24 hours',
                9,
                'pending'
            );
            v_trigger_count := v_trigger_count + 1;
            
        ELSIF v_event.event_type = 'tax_issue' AND v_candidates.office_type IN ('COMMISH', 'MAYOR', 'COUNCIL') THEN
            -- Create trigger for tax response
            INSERT INTO local_news_triggers (
                news_event_id, trigger_name, trigger_type,
                target_county, target_office_type, target_candidate_id,
                primary_faction_target, faction_score_minimum,
                suggested_campaign_type, suggested_subject,
                response_window_hours, expires_at, priority, status
            ) VALUES (
                p_event_id,
                'Tax Response: ' || v_event.headline,
                'tax_response',
                v_event.county, v_candidates.office_type, v_candidates.id,
                'FISC', 60,
                'news_response',
                '💰 ' || v_event.county || ' Tax Alert - ' || v_candidates.full_name || ' Will Fight for Taxpayers',
                24,
                CURRENT_TIMESTAMP + INTERVAL '48 hours',
                7,
                'pending'
            );
            v_trigger_count := v_trigger_count + 1;
            
        ELSIF v_event.event_type = 'resignation' OR v_event.event_type = 'retirement' THEN
            -- Vacancy opportunity
            INSERT INTO local_news_triggers (
                news_event_id, trigger_name, trigger_type,
                target_county, target_office_type, target_candidate_id,
                suggested_campaign_type, suggested_subject,
                response_window_hours, expires_at, priority, status
            ) VALUES (
                p_event_id,
                'Vacancy Opportunity: ' || v_event.headline,
                'vacancy_response',
                v_event.county, v_candidates.office_type, v_candidates.id,
                'announcement',
                v_event.county || ' Needs New Leadership - Support ' || v_candidates.full_name,
                6,
                CURRENT_TIMESTAMP + INTERVAL '12 hours',
                10,
                'pending'
            );
            v_trigger_count := v_trigger_count + 1;
        END IF;
    END LOOP;
    
    -- Update event status
    UPDATE local_news_events 
    SET status = 'processed', 
        processed_at = CURRENT_TIMESTAMP,
        triggers_created = v_trigger_count
    WHERE id = p_event_id;
    
    RETURN v_trigger_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 19: BATCH PROCESSING FUNCTIONS
-- ============================================================================

-- Batch calculate all local candidate grades
CREATE OR REPLACE FUNCTION batch_grade_local_candidates()
RETURNS INT AS $$
DECLARE
    v_count INT := 0;
    v_candidate RECORD;
BEGIN
    FOR v_candidate IN 
        SELECT id FROM local_candidates WHERE deleted_at IS NULL
    LOOP
        PERFORM calculate_local_candidate_grade(v_candidate.id);
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Batch calculate all local candidate scores
CREATE OR REPLACE FUNCTION batch_score_local_candidates()
RETURNS INT AS $$
DECLARE
    v_count INT := 0;
    v_candidate RECORD;
BEGIN
    FOR v_candidate IN 
        SELECT id FROM local_candidates WHERE deleted_at IS NULL
    LOOP
        PERFORM calculate_local_candidate_score(v_candidate.id);
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Batch calculate affinities for a candidate
CREATE OR REPLACE FUNCTION batch_calculate_local_affinities(
    p_candidate_id UUID,
    p_county_only BOOLEAN DEFAULT TRUE
) RETURNS INT AS $$
DECLARE
    v_count INT := 0;
    v_donor RECORD;
    v_candidate RECORD;
BEGIN
    SELECT * INTO v_candidate FROM local_candidates WHERE id = p_candidate_id;
    
    IF v_candidate IS NULL THEN
        RETURN 0;
    END IF;
    
    FOR v_donor IN 
        SELECT id FROM donors 
        WHERE (NOT p_county_only OR LOWER(county) = LOWER(v_candidate.county_name))
    LOOP
        PERFORM calculate_donor_local_affinity(v_donor.id, p_candidate_id);
        v_count := v_count + 1;
        
        IF v_count % 1000 = 0 THEN
            RAISE NOTICE 'Processed % donors for candidate %', v_count, v_candidate.full_name;
        END IF;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Process all pending news events
CREATE OR REPLACE FUNCTION process_pending_news_events()
RETURNS INT AS $$
DECLARE
    v_count INT := 0;
    v_event RECORD;
BEGIN
    FOR v_event IN 
        SELECT id FROM local_news_events 
        WHERE status = 'new' 
        AND is_campaign_opportunity = TRUE
    LOOP
        PERFORM process_local_news_event(v_event.id);
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 20: TRIGGERS FOR AUTO-CALCULATION
-- ============================================================================

-- Trigger to recalculate grade on candidate update
CREATE OR REPLACE FUNCTION trigger_recalc_local_candidate()
RETURNS TRIGGER AS $$
BEGIN
    -- Recalculate grade and score
    PERFORM calculate_local_candidate_grade(NEW.id);
    PERFORM calculate_local_candidate_score(NEW.id);
    
    -- Update profile completeness
    NEW.profile_completeness := (
        (CASE WHEN NEW.first_name IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.last_name IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.email IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.phone_mobile IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.bio_short IS NOT NULL THEN 10 ELSE 0 END) +
        (CASE WHEN NEW.bio_medium IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.headshot_url IS NOT NULL THEN 10 ELSE 0 END) +
        (CASE WHEN NEW.campaign_website IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.primary_faction IS NOT NULL THEN 10 ELSE 0 END) +
        (CASE WHEN NEW.position_abortion IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.position_guns IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.position_taxes IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.denomination IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.occupation IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.military_veteran IS NOT NULL THEN 5 ELSE 0 END) +
        (CASE WHEN NEW.education_level IS NOT NULL THEN 5 ELSE 0 END)
    );
    
    NEW.updated_at := CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER local_candidate_update_trigger
    BEFORE UPDATE ON local_candidates
    FOR EACH ROW
    EXECUTE FUNCTION trigger_recalc_local_candidate();

-- ============================================================================
-- COMPLETE
-- ============================================================================

COMMENT ON TABLE local_campaign_templates IS 'Office-specific campaign templates with faction targeting';
COMMENT ON TABLE local_campaign_performance IS 'ML performance tracking by office, faction, geography';
COMMENT ON FUNCTION get_optimal_local_audience IS 'Get best donors for local candidate campaign';
COMMENT ON FUNCTION process_local_news_event IS 'Analyze news and create campaign triggers';
COMMENT ON FUNCTION batch_calculate_local_affinities IS 'Calculate donor affinities for candidate';
