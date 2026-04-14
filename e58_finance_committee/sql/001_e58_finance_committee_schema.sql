-- ============================================================================
-- E58 FINANCE COMMITTEE ECOSYSTEM
-- BroyhillGOP Platform — Campaign Fundraising Leadership Management
-- ============================================================================
-- PURPOSE: Identify, recruit, deploy, and track Finance Committee teams for
-- every candidate at every office level. Integrates district audit data,
-- budget estimation algorithms, and daily fundraising pace tracking with
-- AI-recommended committee composition and weekly performance reporting.
-- ============================================================================

-- ============================================================================
-- TABLE 1: fc_office_tiers
-- Maps every office type to its Finance Committee sizing parameters
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_office_tiers (
    tier_id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tier_code           VARCHAR(20) NOT NULL UNIQUE,       -- 'federal','statewide','state_leg','county','municipal_lg','municipal_sm','judicial','special'
    tier_name           VARCHAR(100) NOT NULL,
    office_types        TEXT[] NOT NULL,                     -- {'us_senate','us_house'} or {'sheriff','county_commission','clerk_of_court'}
    min_committee_size  INT NOT NULL DEFAULT 3,
    max_committee_size  INT NOT NULL DEFAULT 75,
    bundler_tier_1_name VARCHAR(50),                        -- 'Founders Circle', 'Leadership Team', etc.
    bundler_tier_1_min  NUMERIC(12,2) DEFAULT 0,
    bundler_tier_2_name VARCHAR(50),
    bundler_tier_2_min  NUMERIC(12,2) DEFAULT 0,
    bundler_tier_3_name VARCHAR(50),
    bundler_tier_3_min  NUMERIC(12,2) DEFAULT 0,
    min_events_per_host INT DEFAULT 1,
    typical_event_revenue_low   NUMERIC(12,2),
    typical_event_revenue_high  NUMERIC(12,2),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Seed the 8 tiers
INSERT INTO public.fc_office_tiers (tier_code, tier_name, office_types, min_committee_size, max_committee_size,
    bundler_tier_1_name, bundler_tier_1_min, bundler_tier_2_name, bundler_tier_2_min, bundler_tier_3_name, bundler_tier_3_min,
    min_events_per_host, typical_event_revenue_low, typical_event_revenue_high)
VALUES
('federal',      'Federal (US Senate/House)',
 ARRAY['us_senate','us_house'], 25, 75,
 'Founders Circle', 100000, 'Leadership Council', 50000, 'Champions', 25000,
 2, 25000, 100000),

('statewide',    'Statewide (Governor, Council of State)',
 ARRAY['governor','lt_governor','attorney_general','treasurer','auditor','insurance_commissioner','superintendent','labor_commissioner','secretary_of_state','agriculture_commissioner'], 15, 40,
 'Chairmans Circle', 50000, 'Leadership Team', 25000, 'Supporters', 10000,
 1, 10000, 50000),

('state_leg',    'State Legislature (NC Senate/House)',
 ARRAY['nc_senate','nc_house'], 8, 20,
 'Leadership Team', 10000, 'Supporters', 5000, 'Contributors', 2500,
 1, 5000, 20000),

('county',       'County (Commissioner, Sheriff, DA, Clerk, Register)',
 ARRAY['county_commission','sheriff','district_attorney','clerk_of_court','register_of_deeds','county_manager'], 5, 12,
 'Leadership', 5000, 'Supporters', 2500, 'Contributors', 1000,
 1, 2000, 10000),

('municipal_lg', 'Large Municipal (Charlotte, Raleigh, Greensboro)',
 ARRAY['mayor_lg','city_council_lg','municipal_judge_lg'], 5, 15,
 'Leadership', 5000, 'Supporters', 2500, 'Contributors', 1000,
 1, 1000, 10000),

('municipal_sm', 'Small Municipal (Towns, Villages)',
 ARRAY['mayor_sm','town_council','village_board'], 3, 10,
 'Leaders', 2000, 'Supporters', 1000, 'Friends', 500,
 1, 500, 5000),

('judicial',     'Judicial (Supreme Court, Court of Appeals, Superior, District)',
 ARRAY['nc_supreme_court','nc_court_of_appeals','superior_court','district_court'], 5, 15,
 'Leadership', 10000, 'Supporters', 5000, 'Contributors', 2500,
 1, 5000, 25000),

('special',      'Special Districts (School Board, Soil & Water, Hospital Board)',
 ARRAY['school_board','soil_water','sanitary_district','hospital_board'], 2, 5,
 'Leaders', 1000, 'Supporters', 500, 'Friends', 250,
 1, 250, 2000)
ON CONFLICT (tier_code) DO NOTHING;


-- ============================================================================
-- TABLE 2: fc_district_audit
-- Pre-computed district analysis: D1-D10 difficulty, R1-R10 baseline,
-- voter targets, microsegment dominance, estimated budget to win
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_district_audit (
    audit_id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    district_code       VARCHAR(30) NOT NULL,               -- 'NC-SD-01', 'NC-HD-45', 'MECK-CC-03', etc.
    office_type         VARCHAR(50) NOT NULL,
    tier_code           VARCHAR(20) NOT NULL REFERENCES public.fc_office_tiers(tier_code),
    election_cycle      VARCHAR(10) NOT NULL,               -- '2026', '2028'

    -- Scoring
    difficulty_score    INT CHECK (difficulty_score BETWEEN 1 AND 10),   -- D1 (easy) to D10 (impossible)
    republican_baseline INT CHECK (republican_baseline BETWEEN 1 AND 10), -- R1 (weak) to R10 (dominant)
    partisan_lean       NUMERIC(5,2),                       -- +5.3 = R+5.3, -2.1 = D+2.1
    swing_index         NUMERIC(5,2),                       -- volatility measure

    -- Voter targets
    total_registered    INT,
    republican_reg      INT,
    democrat_reg        INT,
    unaffiliated_reg    INT,
    turnout_estimate    NUMERIC(5,2),                       -- % expected turnout
    vote_target_to_win  INT,                                -- votes needed
    voter_contacts_needed INT,                              -- touches required

    -- Budget estimation
    estimated_budget_low    NUMERIC(12,2),
    estimated_budget_mid    NUMERIC(12,2),
    estimated_budget_high   NUMERIC(12,2),
    budget_by_category      JSONB,                          -- {"mail":25000,"digital":15000,"media":50000,"field":10000,"events":8000,"overhead":12000}

    -- Microsegment dominance (top 10 for this district)
    top_microsegments   JSONB,                              -- [{"segment":"hunters","rank":82},{"segment":"farmers","rank":76}]

    -- Opponent intelligence
    opponent_name       VARCHAR(200),
    opponent_party      VARCHAR(20),
    opponent_incumbent  BOOLEAN DEFAULT FALSE,
    opponent_war_chest  NUMERIC(12,2),
    opponent_strength   INT CHECK (opponent_strength BETWEEN 1 AND 10),

    -- Donor pool in district
    known_r_donors      INT,                                -- Republican donors in district from person_spine
    total_donor_dollars NUMERIC(14,2),                      -- total R giving in district
    major_donors_50k    INT,                                -- donors who've given $50K+ lifetime
    mid_donors_5k       INT,                                -- $5K-$50K lifetime
    grassroots_donors   INT,                                -- under $5K lifetime

    computed_at         TIMESTAMPTZ DEFAULT NOW(),
    data_sources        TEXT[],                              -- {'nc_datatrust','fec_donations','nc_boe','person_spine'}

    UNIQUE(district_code, office_type, election_cycle)
);

-- ============================================================================
-- TABLE 3: fc_budget_plan
-- Daily/weekly fundraising plan derived from district audit
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_budget_plan (
    plan_id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    candidate_id        VARCHAR(50) NOT NULL,               -- matches candidate_profiles.candidate_id
    audit_id            UUID REFERENCES public.fc_district_audit(audit_id),
    election_cycle      VARCHAR(10) NOT NULL,
    election_date       DATE NOT NULL,

    -- Budget targets
    total_budget_target NUMERIC(12,2) NOT NULL,
    raised_to_date      NUMERIC(12,2) DEFAULT 0,
    remaining           NUMERIC(12,2) GENERATED ALWAYS AS (total_budget_target - raised_to_date) STORED,
    days_remaining      INT,
    daily_target        NUMERIC(10,2),                      -- recalculated daily

    -- Pace tracking
    pace_status         VARCHAR(20) DEFAULT 'on_track',     -- 'ahead','on_track','behind','critical'
    pace_percentage     NUMERIC(5,2),                       -- % of where they should be by this date
    weekly_target       NUMERIC(10,2),
    this_week_raised    NUMERIC(10,2) DEFAULT 0,

    -- Budget allocation by source
    budget_from_bundlers    NUMERIC(12,2),
    budget_from_events      NUMERIC(12,2),
    budget_from_direct_ask  NUMERIC(12,2),
    budget_from_online      NUMERIC(12,2),
    budget_from_pac         NUMERIC(12,2),
    budget_from_self        NUMERIC(12,2),

    -- Finance Committee sizing (calculated)
    recommended_committee_size  INT,
    recommended_bundlers        INT,
    recommended_hosts           INT,
    recommended_vice_chairs     INT,
    avg_bundler_goal            NUMERIC(10,2),

    plan_status         VARCHAR(20) DEFAULT 'draft',        -- 'draft','active','revised','completed'
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(candidate_id, election_cycle)
);

-- ============================================================================
-- TABLE 4: fc_committees
-- One Finance Committee per candidate per cycle
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_committees (
    committee_id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    candidate_id        VARCHAR(50) NOT NULL,
    plan_id             UUID REFERENCES public.fc_budget_plan(plan_id),
    election_cycle      VARCHAR(10) NOT NULL,
    committee_name      VARCHAR(200),                       -- "Friends of John Smith Finance Committee"
    tier_code           VARCHAR(20) NOT NULL REFERENCES public.fc_office_tiers(tier_code),

    -- Status
    status              VARCHAR(20) DEFAULT 'forming',      -- 'forming','active','paused','completed','disbanded'
    formation_date      DATE,
    activation_date     DATE,

    -- Targets (copied from budget plan, can be overridden)
    fundraising_goal    NUMERIC(12,2),
    total_raised        NUMERIC(12,2) DEFAULT 0,
    pct_to_goal         NUMERIC(5,2) DEFAULT 0,

    -- Meeting schedule
    weekly_call_day     VARCHAR(10),                        -- 'tuesday'
    weekly_call_time    TIME,
    monthly_meeting_day INT,                                -- day of month (1-28)
    next_meeting        TIMESTAMPTZ,

    -- Settings
    show_member_names_on_scoreboard BOOLEAN DEFAULT TRUE,
    ai_recommendations_enabled      BOOLEAN DEFAULT TRUE,
    auto_adjust_targets             BOOLEAN DEFAULT FALSE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(candidate_id, election_cycle)
);

-- ============================================================================
-- TABLE 5: fc_roles
-- Role definitions with task checklists
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_roles (
    role_id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    role_code           VARCHAR(30) NOT NULL UNIQUE,        -- 'finance_chair','vice_chair','bundler','event_host','member'
    role_name           VARCHAR(100) NOT NULL,
    role_description    TEXT,
    seniority_rank      INT NOT NULL,                       -- 1=chair, 2=vice_chair, 3=bundler, 4=host, 5=member
    min_personal_gift   BOOLEAN DEFAULT TRUE,               -- must give before asking
    can_recruit         BOOLEAN DEFAULT FALSE,              -- can recruit other members
    can_solicit         BOOLEAN DEFAULT TRUE,               -- can make direct asks
    weekly_tasks        JSONB,                              -- [{"task":"outreach_3_prospects","description":"..."},...]
    monthly_tasks       JSONB,
    per_event_tasks     JSONB,
    weekly_deliverables JSONB,                              -- [{"deliverable":"prospect_pipeline_update","description":"..."}]
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Seed roles
INSERT INTO public.fc_roles (role_code, role_name, role_description, seniority_rank, can_recruit, weekly_tasks, monthly_tasks, weekly_deliverables)
VALUES
('finance_chair', 'Finance Chair', 'Top fundraising leader. Sets the standard with personal giving, recruits Vice Chairs, leads weekly calls, personally solicits top 10-15 major prospects, co-signs all major fundraising communications.', 1, TRUE,
 '[{"task":"solicit_major_prospects","count":3,"description":"Personal outreach to 3-5 major donor prospects"},{"task":"review_committee_progress","description":"Review committee-wide progress vs weekly target"},{"task":"update_prospect_list","description":"Update top-25 prospect list with status and next action"},{"task":"lead_weekly_call","description":"Lead 30-minute weekly Finance Committee call"}]'::jsonb,
 '[{"task":"recognition_report","description":"Recognize top performers at monthly full committee meeting"},{"task":"recruitment_review","description":"Review unfilled roles and recruit replacements"},{"task":"target_adjustment","description":"Recommend target adjustments based on race conditions"}]'::jsonb,
 '[{"deliverable":"weekly_progress_report","description":"Committee-wide raised vs target with member breakdown"},{"deliverable":"prospect_pipeline","description":"Top 25 prospects with status codes"},{"deliverable":"escalation_list","description":"Prospects needing candidate personal call"}]'::jsonb),

('vice_chair', 'Finance Vice Chair', 'Owns a fundraising segment — geographic region, industry sector, or donor tier. Recruits and manages bundlers and hosts within their segment.', 2, TRUE,
 '[{"task":"segment_outreach","count":5,"description":"Outreach to 5+ prospects in assigned segment"},{"task":"manage_bundlers","description":"Check in with bundlers in segment on progress"},{"task":"segment_report","description":"Report segment performance to Finance Chair"}]'::jsonb,
 '[{"task":"host_event","description":"Host or co-host at least one fundraising event per cycle"},{"task":"segment_pipeline_review","description":"Full pipeline review with new prospects identified"}]'::jsonb,
 '[{"deliverable":"segment_report","description":"Raised this week, cumulative, pct to goal for segment"},{"deliverable":"prospect_pipeline","description":"New names added, asks made, commitments, declines"},{"deliverable":"candidate_call_list","description":"Prospects needing candidate personal attention"}]'::jsonb),

('bundler', 'Bundler', 'Commits to raising a specific dollar amount from their personal network. Identifies 20-50 prospects, makes direct asks, collects contributions, reports weekly.', 3, FALSE,
 '[{"task":"make_asks","count":5,"description":"Make 5+ direct personal asks this week"},{"task":"collect_contributions","description":"Deliver collected contributions to campaign"},{"task":"report_progress","description":"Report asks made, commitments, dollars delivered"}]'::jsonb,
 '[{"task":"host_gathering","description":"Host or co-host at least one small gathering per cycle"},{"task":"attend_committee_meeting","description":"Attend monthly full committee meeting"}]'::jsonb,
 '[{"deliverable":"asks_made","description":"Number of asks made this week"},{"deliverable":"dollars_committed","description":"New commitments this week"},{"deliverable":"dollars_delivered","description":"Contributions received and delivered"},{"deliverable":"running_total","description":"Cumulative vs pledge goal"},{"deliverable":"needs_candidate","description":"Prospects needing candidate involvement"}]'::jsonb),

('event_host', 'Event Host', 'Provides venue and guest list for fundraising events. Sends personal invitations, handles logistics, introduces candidate, follows up with non-givers after event.', 4, FALSE,
 '[]'::jsonb,
 '[]'::jsonb,
 '[]'::jsonb),

('member', 'Finance Committee Member', 'Broader team. Gives personally, attends events, provides prospect names, makes warm introductions, shares campaign appeals through personal channels.', 5, FALSE,
 '[{"task":"share_appeals","description":"Share campaign fundraising content through personal channels"}]'::jsonb,
 '[{"task":"attend_meeting","description":"Attend monthly committee meeting"},{"task":"provide_prospects","description":"Provide 5-10 prospect names from personal network"},{"task":"attend_events","count":2,"description":"Attend at least 2 fundraising events per cycle"}]'::jsonb,
 '[]'::jsonb)
ON CONFLICT (role_code) DO NOTHING;

-- ============================================================================
-- TABLE 6: fc_members
-- Every person assigned to a Finance Committee with their role and targets
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_members (
    member_id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    committee_id        UUID NOT NULL REFERENCES public.fc_committees(committee_id),
    person_id           UUID,                               -- references core.person_spine if known donor/voter
    contact_id          UUID,                               -- references public.contacts if in contacts table
    role_id             UUID NOT NULL REFERENCES public.fc_roles(role_id),

    -- Person info (denormalized for display — source of truth is person_spine/contacts)
    full_name           VARCHAR(200) NOT NULL,
    email               VARCHAR(200),
    phone               VARCHAR(30),
    employer            VARCHAR(200),
    title               VARCHAR(200),
    city                VARCHAR(100),
    county              VARCHAR(100),

    -- Assignment
    segment_assigned    VARCHAR(100),                       -- 'mecklenburg_county', 'healthcare', 'agriculture', etc.
    recruited_by        UUID REFERENCES public.fc_members(member_id),
    source              VARCHAR(30) DEFAULT 'candidate',    -- 'candidate','ai_recommended','vice_chair','self_nominated'

    -- Targets
    personal_gift_amount    NUMERIC(10,2) DEFAULT 0,
    personal_gift_date      DATE,
    personal_gift_status    VARCHAR(20) DEFAULT 'pending',  -- 'pending','pledged','received'
    fundraising_pledge      NUMERIC(10,2) DEFAULT 0,        -- total they commit to raise from others
    weekly_target           NUMERIC(10,2) DEFAULT 0,
    fundraising_raised      NUMERIC(10,2) DEFAULT 0,        -- total raised from their network
    pct_to_pledge           NUMERIC(5,2) DEFAULT 0,

    -- Performance
    total_asks_made         INT DEFAULT 0,
    total_commitments       INT DEFAULT 0,
    total_introductions     INT DEFAULT 0,
    events_hosted           INT DEFAULT 0,
    events_attended         INT DEFAULT 0,
    meetings_attended       INT DEFAULT 0,
    meetings_missed         INT DEFAULT 0,
    performance_score       NUMERIC(5,2) DEFAULT 0,         -- 0-100 composite
    performance_status      VARCHAR(20) DEFAULT 'new',      -- 'star','on_track','behind','inactive','new'

    -- Status
    status              VARCHAR(20) DEFAULT 'invited',      -- 'invited','accepted','active','paused','declined','removed'
    invited_at          TIMESTAMPTZ DEFAULT NOW(),
    accepted_at         TIMESTAMPTZ,
    activated_at        TIMESTAMPTZ,

    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TABLE 7: fc_ai_recommendations
-- AI-suggested Finance Committee candidates from donor/voter data
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_ai_recommendations (
    rec_id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    committee_id        UUID NOT NULL REFERENCES public.fc_committees(committee_id),
    person_id           UUID,                               -- from person_spine
    contact_id          UUID,                               -- from contacts

    full_name           VARCHAR(200) NOT NULL,
    recommended_role    VARCHAR(30) NOT NULL,                -- 'finance_chair','vice_chair','bundler','event_host','member'

    -- Why recommended
    recommendation_score    NUMERIC(5,2),                   -- 0-100 composite
    reason_codes            TEXT[],                          -- {'high_donor','event_host_history','industry_leader','network_size'}
    reason_narrative        TEXT,                            -- "Gave $45K lifetime to R candidates. Hosted 3 events in 2024. Connected to 12 major donors in district."

    -- Supporting data
    lifetime_giving         NUMERIC(12,2),
    giving_in_district      NUMERIC(12,2),
    events_hosted_prior     INT DEFAULT 0,
    network_size_estimate   INT,                            -- how many donors in their likely network
    influencer_score        NUMERIC(5,2),                   -- from influencer tracking if available
    industry_sector         VARCHAR(100),
    microsegments           TEXT[],                          -- segments they connect to

    -- Candidate action
    candidate_action    VARCHAR(20) DEFAULT 'pending',      -- 'pending','accepted','rejected','deferred','contacted'
    candidate_notes     TEXT,
    actioned_at         TIMESTAMPTZ,

    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TABLE 8: fc_weekly_reports
-- Auto-generated weekly performance snapshots per member
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_weekly_reports (
    report_id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    member_id           UUID NOT NULL REFERENCES public.fc_members(member_id),
    committee_id        UUID NOT NULL REFERENCES public.fc_committees(committee_id),
    week_start          DATE NOT NULL,
    week_end            DATE NOT NULL,

    -- Activity
    asks_made           INT DEFAULT 0,
    dollars_committed   NUMERIC(10,2) DEFAULT 0,
    dollars_received    NUMERIC(10,2) DEFAULT 0,
    introductions_made  INT DEFAULT 0,
    events_this_week    INT DEFAULT 0,
    meeting_attended    BOOLEAN DEFAULT FALSE,

    -- Cumulative
    cumulative_raised   NUMERIC(10,2) DEFAULT 0,
    pct_to_pledge       NUMERIC(5,2) DEFAULT 0,
    weekly_target       NUMERIC(10,2) DEFAULT 0,
    weekly_variance     NUMERIC(10,2) DEFAULT 0,            -- positive = ahead, negative = behind

    -- Status
    performance_grade   VARCHAR(5),                         -- 'A+','A','B','C','D','F'
    status_color        VARCHAR(10),                        -- 'green','yellow','red'
    notes               TEXT,

    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(member_id, week_start)
);

-- ============================================================================
-- TABLE 9: fc_events
-- Fundraising events tied to Finance Committee
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_events (
    event_id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    committee_id        UUID NOT NULL REFERENCES public.fc_committees(committee_id),
    host_member_id      UUID REFERENCES public.fc_members(member_id),
    co_host_member_ids  UUID[],

    event_name          VARCHAR(200) NOT NULL,
    event_type          VARCHAR(50),                        -- 'private_dinner','reception','bbq','breakfast','house_party','virtual','office_reception'
    event_date          DATE,
    event_time          TIME,
    venue_name          VARCHAR(200),
    venue_address       TEXT,
    venue_type          VARCHAR(50),                        -- 'home','business','restaurant','farm','club','church','virtual'

    -- Financials
    ticket_price_low    NUMERIC(10,2),                      -- range for tiered events
    ticket_price_high   NUMERIC(10,2),
    revenue_goal        NUMERIC(10,2),
    revenue_actual      NUMERIC(10,2) DEFAULT 0,
    expenses            NUMERIC(10,2) DEFAULT 0,
    net_revenue         NUMERIC(10,2) GENERATED ALWAYS AS (COALESCE(revenue_actual, 0) - COALESCE(expenses, 0)) STORED,

    -- Guest tracking
    guests_invited      INT DEFAULT 0,
    guests_rsvp_yes     INT DEFAULT 0,
    guests_attended     INT DEFAULT 0,
    guests_donated      INT DEFAULT 0,
    new_prospects_from_event INT DEFAULT 0,

    -- Timeline
    guest_list_due      DATE,                               -- 3 weeks before
    invitations_sent    DATE,                               -- 2 weeks before
    rsvp_deadline       DATE,                               -- 1 week before
    post_event_report   DATE,                               -- 48 hours after

    status              VARCHAR(20) DEFAULT 'planning',     -- 'planning','confirmed','invitations_sent','completed','cancelled'

    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TABLE 10: fc_prospect_pipeline
-- Every prospect being worked by a committee member
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_prospect_pipeline (
    prospect_id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    committee_id        UUID NOT NULL REFERENCES public.fc_committees(committee_id),
    assigned_member_id  UUID NOT NULL REFERENCES public.fc_members(member_id),
    person_id           UUID,
    contact_id          UUID,

    prospect_name       VARCHAR(200) NOT NULL,
    prospect_email      VARCHAR(200),
    prospect_phone      VARCHAR(30),
    prospect_employer   VARCHAR(200),

    -- Pipeline status
    stage               VARCHAR(30) DEFAULT 'identified',   -- 'identified','contacted','cultivating','ask_scheduled','asked','committed','received','declined','deferred'
    ask_amount          NUMERIC(10,2),
    committed_amount    NUMERIC(10,2),
    received_amount     NUMERIC(10,2),
    estimated_capacity  NUMERIC(10,2),                      -- AI estimate of what they could give

    -- Activity
    first_contact_date  DATE,
    last_contact_date   DATE,
    next_action         VARCHAR(200),
    next_action_date    DATE,
    contact_count       INT DEFAULT 0,
    needs_candidate_call BOOLEAN DEFAULT FALSE,

    -- Source
    source              VARCHAR(30),                        -- 'personal_network','ai_recommended','event_attendee','referral','database'
    referred_by         UUID REFERENCES public.fc_members(member_id),

    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TABLE 11: fc_candidate_questionnaire
-- Candidate onboarding answers that seed the Finance Committee
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_candidate_questionnaire (
    questionnaire_id    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    candidate_id        VARCHAR(50) NOT NULL,
    election_cycle      VARCHAR(10) NOT NULL,

    -- Finance Chair nomination
    proposed_chair_name     VARCHAR(200),
    proposed_chair_email    VARCHAR(200),
    proposed_chair_phone    VARCHAR(30),
    proposed_chair_relationship TEXT,                        -- "business partner", "family friend", "former employer"
    proposed_chair_why      TEXT,                            -- why this person

    -- Proposed committee members (up to 10)
    proposed_members        JSONB,                          -- [{"name":"...","email":"...","phone":"...","relationship":"...","strength":"..."}]

    -- Event host nominations
    proposed_hosts          JSONB,                          -- [{"name":"...","venue_type":"home","capacity":50,"location":"..."}]

    -- Campaign context
    fundraising_goal        NUMERIC(12,2),
    self_fund_amount        NUMERIC(12,2) DEFAULT 0,
    prior_campaign_experience BOOLEAN DEFAULT FALSE,
    existing_donor_list     BOOLEAN DEFAULT FALSE,
    donor_list_size         INT,

    -- District knowledge
    strongest_industries    TEXT[],                          -- ['agriculture','real_estate','healthcare']
    strongest_communities   TEXT[],                          -- ['rotary_club','farm_bureau','chamber_of_commerce']
    key_relationships       TEXT,                            -- free-form: who do you know

    -- Opponent assessment
    opponent_known          BOOLEAN DEFAULT FALSE,
    opponent_incumbent      BOOLEAN DEFAULT FALSE,
    opponent_estimated_budget NUMERIC(12,2),

    submitted_at            TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at             TIMESTAMPTZ,
    reviewed_by             VARCHAR(100),

    UNIQUE(candidate_id, election_cycle)
);

-- ============================================================================
-- TABLE 12: fc_performance_snapshots
-- Committee-level daily snapshots for pace tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_performance_snapshots (
    snapshot_id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    committee_id        UUID NOT NULL REFERENCES public.fc_committees(committee_id),
    snapshot_date       DATE NOT NULL,

    -- Dollars
    total_raised        NUMERIC(12,2) DEFAULT 0,
    raised_today        NUMERIC(10,2) DEFAULT 0,
    daily_target        NUMERIC(10,2),
    weekly_target       NUMERIC(10,2),
    total_target        NUMERIC(12,2),

    -- Pace
    days_elapsed        INT,
    days_remaining      INT,
    pct_of_goal         NUMERIC(5,2),
    pct_of_timeline     NUMERIC(5,2),
    pace_ratio          NUMERIC(5,2),                       -- >1.0 = ahead, <1.0 = behind
    pace_status         VARCHAR(20),                        -- 'ahead','on_track','behind','critical'

    -- Committee health
    active_members      INT,
    members_on_track    INT,
    members_behind      INT,
    members_inactive    INT,
    open_roles          INT,                                -- unfilled positions

    -- Pipeline
    total_prospects     INT,
    prospects_in_ask    INT,                                -- 'asked' or 'ask_scheduled'
    committed_pipeline  NUMERIC(12,2),                      -- dollars committed but not yet received
    expected_events_revenue NUMERIC(12,2),                  -- upcoming event goals

    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(committee_id, snapshot_date)
);

-- ============================================================================
-- TABLE 13: fc_brain_directives
-- E20 Intelligence Brain actions on Finance Committees
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fc_brain_directives (
    directive_id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    committee_id        UUID NOT NULL REFERENCES public.fc_committees(committee_id),
    directive_type      VARCHAR(50) NOT NULL,               -- 'adjust_target','recommend_recruit','flag_underperformer','suggest_event','reallocate_goals','escalate_to_candidate'
    priority            VARCHAR(10) DEFAULT 'normal',       -- 'critical','high','normal','low'

    directive_detail    JSONB NOT NULL,                     -- {"action":"increase_weekly_target","member_id":"...","from":5000,"to":7500,"reason":"pace behind 15%"}
    narrative           TEXT,                               -- human-readable explanation

    -- Approval
    requires_approval   BOOLEAN DEFAULT TRUE,
    approved_by         VARCHAR(100),
    approved_at         TIMESTAMPTZ,
    auto_executed       BOOLEAN DEFAULT FALSE,
    executed_at         TIMESTAMPTZ,

    -- ML context
    model_name          VARCHAR(100),                       -- 'pace_predictor_v2','committee_optimizer_v1'
    confidence          NUMERIC(5,2),
    input_features      JSONB,                              -- what data drove this recommendation

    created_at          TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================================
-- INDEXES
-- ============================================================================

-- District audit lookups
CREATE INDEX IF NOT EXISTS idx_fc_audit_district ON public.fc_district_audit(district_code, election_cycle);
CREATE INDEX IF NOT EXISTS idx_fc_audit_tier ON public.fc_district_audit(tier_code);
CREATE INDEX IF NOT EXISTS idx_fc_audit_difficulty ON public.fc_district_audit(difficulty_score);

-- Budget plan by candidate
CREATE INDEX IF NOT EXISTS idx_fc_plan_candidate ON public.fc_budget_plan(candidate_id, election_cycle);
CREATE INDEX IF NOT EXISTS idx_fc_plan_pace ON public.fc_budget_plan(pace_status);

-- Committee lookups
CREATE INDEX IF NOT EXISTS idx_fc_committee_candidate ON public.fc_committees(candidate_id, election_cycle);
CREATE INDEX IF NOT EXISTS idx_fc_committee_status ON public.fc_committees(status);

-- Member lookups
CREATE INDEX IF NOT EXISTS idx_fc_member_committee ON public.fc_members(committee_id);
CREATE INDEX IF NOT EXISTS idx_fc_member_person ON public.fc_members(person_id) WHERE person_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fc_member_status ON public.fc_members(status);
CREATE INDEX IF NOT EXISTS idx_fc_member_performance ON public.fc_members(performance_status);
CREATE INDEX IF NOT EXISTS idx_fc_member_role ON public.fc_members(role_id);

-- AI recommendations
CREATE INDEX IF NOT EXISTS idx_fc_rec_committee ON public.fc_ai_recommendations(committee_id);
CREATE INDEX IF NOT EXISTS idx_fc_rec_action ON public.fc_ai_recommendations(candidate_action);
CREATE INDEX IF NOT EXISTS idx_fc_rec_score ON public.fc_ai_recommendations(recommendation_score DESC);

-- Weekly reports
CREATE INDEX IF NOT EXISTS idx_fc_weekly_member ON public.fc_weekly_reports(member_id, week_start);
CREATE INDEX IF NOT EXISTS idx_fc_weekly_committee ON public.fc_weekly_reports(committee_id, week_start);
CREATE INDEX IF NOT EXISTS idx_fc_weekly_grade ON public.fc_weekly_reports(performance_grade);

-- Events
CREATE INDEX IF NOT EXISTS idx_fc_event_committee ON public.fc_events(committee_id);
CREATE INDEX IF NOT EXISTS idx_fc_event_host ON public.fc_events(host_member_id);
CREATE INDEX IF NOT EXISTS idx_fc_event_date ON public.fc_events(event_date);
CREATE INDEX IF NOT EXISTS idx_fc_event_status ON public.fc_events(status);

-- Prospect pipeline
CREATE INDEX IF NOT EXISTS idx_fc_prospect_committee ON public.fc_prospect_pipeline(committee_id);
CREATE INDEX IF NOT EXISTS idx_fc_prospect_member ON public.fc_prospect_pipeline(assigned_member_id);
CREATE INDEX IF NOT EXISTS idx_fc_prospect_stage ON public.fc_prospect_pipeline(stage);
CREATE INDEX IF NOT EXISTS idx_fc_prospect_candidate_call ON public.fc_prospect_pipeline(needs_candidate_call) WHERE needs_candidate_call = TRUE;

-- Questionnaire
CREATE INDEX IF NOT EXISTS idx_fc_quest_candidate ON public.fc_candidate_questionnaire(candidate_id, election_cycle);

-- Performance snapshots
CREATE INDEX IF NOT EXISTS idx_fc_snapshot_committee ON public.fc_performance_snapshots(committee_id, snapshot_date);
CREATE INDEX IF NOT EXISTS idx_fc_snapshot_pace ON public.fc_performance_snapshots(pace_status);

-- Brain directives
CREATE INDEX IF NOT EXISTS idx_fc_brain_committee ON public.fc_brain_directives(committee_id);
CREATE INDEX IF NOT EXISTS idx_fc_brain_type ON public.fc_brain_directives(directive_type);
CREATE INDEX IF NOT EXISTS idx_fc_brain_pending ON public.fc_brain_directives(requires_approval) WHERE approved_at IS NULL AND requires_approval = TRUE;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamps
CREATE OR REPLACE FUNCTION fc_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fc_budget_plan_updated BEFORE UPDATE ON public.fc_budget_plan FOR EACH ROW EXECUTE FUNCTION fc_update_timestamp();
CREATE TRIGGER trg_fc_committees_updated BEFORE UPDATE ON public.fc_committees FOR EACH ROW EXECUTE FUNCTION fc_update_timestamp();
CREATE TRIGGER trg_fc_members_updated BEFORE UPDATE ON public.fc_members FOR EACH ROW EXECUTE FUNCTION fc_update_timestamp();
CREATE TRIGGER trg_fc_events_updated BEFORE UPDATE ON public.fc_events FOR EACH ROW EXECUTE FUNCTION fc_update_timestamp();
CREATE TRIGGER trg_fc_prospect_updated BEFORE UPDATE ON public.fc_prospect_pipeline FOR EACH ROW EXECUTE FUNCTION fc_update_timestamp();

-- Auto-recalculate member pct_to_pledge when fundraising_raised changes
CREATE OR REPLACE FUNCTION fc_recalc_member_pct()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fundraising_pledge > 0 THEN
        NEW.pct_to_pledge = ROUND((NEW.fundraising_raised / NEW.fundraising_pledge) * 100, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fc_member_pct BEFORE UPDATE OF fundraising_raised ON public.fc_members FOR EACH ROW EXECUTE FUNCTION fc_recalc_member_pct();

-- Auto-update committee total_raised when member fundraising changes
CREATE OR REPLACE FUNCTION fc_recalc_committee_totals()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.fc_committees
    SET total_raised = (
        SELECT COALESCE(SUM(fundraising_raised + personal_gift_amount), 0)
        FROM public.fc_members
        WHERE committee_id = NEW.committee_id AND status = 'active'
    ),
    pct_to_goal = CASE
        WHEN fundraising_goal > 0 THEN ROUND(
            (SELECT COALESCE(SUM(fundraising_raised + personal_gift_amount), 0)
             FROM public.fc_members
             WHERE committee_id = NEW.committee_id AND status = 'active')
            / fundraising_goal * 100, 2)
        ELSE 0
    END
    WHERE committee_id = NEW.committee_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fc_committee_totals AFTER UPDATE OF fundraising_raised, personal_gift_amount ON public.fc_members FOR EACH ROW EXECUTE FUNCTION fc_recalc_committee_totals();

-- Auto-update budget plan raised_to_date from committee
CREATE OR REPLACE FUNCTION fc_sync_budget_raised()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.fc_budget_plan
    SET raised_to_date = NEW.total_raised,
        this_week_raised = (
            SELECT COALESCE(SUM(dollars_received), 0)
            FROM public.fc_weekly_reports
            WHERE committee_id = NEW.committee_id
            AND week_start = date_trunc('week', CURRENT_DATE)::date
        )
    WHERE plan_id = NEW.plan_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fc_sync_budget AFTER UPDATE OF total_raised ON public.fc_committees FOR EACH ROW EXECUTE FUNCTION fc_sync_budget_raised();


-- ============================================================================
-- VIEWS
-- ============================================================================

-- Committee dashboard view
CREATE OR REPLACE VIEW public.v_fc_committee_dashboard AS
SELECT
    c.committee_id,
    c.candidate_id,
    c.committee_name,
    c.election_cycle,
    c.status,
    c.tier_code,
    t.tier_name,
    c.fundraising_goal,
    c.total_raised,
    c.pct_to_goal,
    bp.daily_target,
    bp.weekly_target,
    bp.days_remaining,
    bp.pace_status,
    bp.pace_percentage,
    bp.recommended_committee_size,
    (SELECT COUNT(*) FROM public.fc_members m WHERE m.committee_id = c.committee_id AND m.status = 'active') AS active_members,
    (SELECT COUNT(*) FROM public.fc_members m WHERE m.committee_id = c.committee_id AND m.performance_status = 'star') AS star_performers,
    (SELECT COUNT(*) FROM public.fc_members m WHERE m.committee_id = c.committee_id AND m.performance_status = 'behind') AS members_behind,
    (SELECT COUNT(*) FROM public.fc_events e WHERE e.committee_id = c.committee_id AND e.event_date >= CURRENT_DATE) AS upcoming_events,
    (SELECT COUNT(*) FROM public.fc_prospect_pipeline p WHERE p.committee_id = c.committee_id AND p.stage IN ('ask_scheduled','asked')) AS active_asks,
    (SELECT COALESCE(SUM(p.committed_amount), 0) FROM public.fc_prospect_pipeline p WHERE p.committee_id = c.committee_id AND p.stage = 'committed') AS pipeline_committed,
    (SELECT COUNT(*) FROM public.fc_brain_directives d WHERE d.committee_id = c.committee_id AND d.requires_approval = TRUE AND d.approved_at IS NULL) AS pending_directives,
    c.next_meeting
FROM public.fc_committees c
JOIN public.fc_office_tiers t ON c.tier_code = t.tier_code
LEFT JOIN public.fc_budget_plan bp ON c.plan_id = bp.plan_id;

-- Member performance leaderboard
CREATE OR REPLACE VIEW public.v_fc_member_leaderboard AS
SELECT
    m.member_id,
    m.committee_id,
    m.full_name,
    r.role_name,
    r.seniority_rank,
    m.segment_assigned,
    m.personal_gift_amount,
    m.personal_gift_status,
    m.fundraising_pledge,
    m.fundraising_raised,
    m.pct_to_pledge,
    m.total_asks_made,
    m.total_commitments,
    m.events_hosted,
    m.events_attended,
    m.meetings_attended,
    m.meetings_missed,
    m.performance_score,
    m.performance_status,
    m.status,
    m.source
FROM public.fc_members m
JOIN public.fc_roles r ON m.role_id = r.role_id
ORDER BY m.fundraising_raised DESC;


-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE public.fc_office_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_district_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_budget_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_committees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_ai_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_weekly_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_prospect_pipeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_candidate_questionnaire ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_performance_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fc_brain_directives ENABLE ROW LEVEL SECURITY;

-- Service role has full access (for API and backend)
CREATE POLICY fc_service_all ON public.fc_office_tiers FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_district_audit FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_budget_plan FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_committees FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_roles FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_members FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_ai_recommendations FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_weekly_reports FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_events FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_prospect_pipeline FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_candidate_questionnaire FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_performance_snapshots FOR ALL USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY fc_service_all ON public.fc_brain_directives FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- NOTE: Role-based RLS (candidate sees only their committee, member sees only their data)
-- will be implemented when user_roles table is created per the dependency note.


-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Calculate recommended committee size from budget
CREATE OR REPLACE FUNCTION fc_calculate_committee_size(
    p_budget NUMERIC,
    p_tier_code VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    v_tier RECORD;
    v_bundlers INT;
    v_hosts INT;
    v_vice_chairs INT;
    v_members INT;
    v_total INT;
    v_avg_bundler_goal NUMERIC;
BEGIN
    SELECT * INTO v_tier FROM public.fc_office_tiers WHERE tier_code = p_tier_code;

    -- Estimate bundler count: 60% of budget from bundlers, each raises tier midpoint
    v_avg_bundler_goal = (v_tier.bundler_tier_1_min + v_tier.bundler_tier_3_min) / 2;
    IF v_avg_bundler_goal > 0 THEN
        v_bundlers = GREATEST(1, CEIL((p_budget * 0.6) / v_avg_bundler_goal));
    ELSE
        v_bundlers = 2;
    END IF;

    -- Hosts: 1 per $15K of event revenue target (30% of budget)
    v_hosts = GREATEST(1, CEIL((p_budget * 0.3) / GREATEST(v_tier.typical_event_revenue_low, 1)));

    -- Vice Chairs: 1 per 4-5 bundlers
    v_vice_chairs = GREATEST(1, CEIL(v_bundlers::NUMERIC / 4.5));

    -- General members: 20% of total committee
    v_members = GREATEST(1, CEIL((v_bundlers + v_hosts + v_vice_chairs) * 0.25));

    v_total = 1 + v_vice_chairs + v_bundlers + v_hosts + v_members; -- +1 for chair
    v_total = LEAST(GREATEST(v_total, v_tier.min_committee_size), v_tier.max_committee_size);

    RETURN jsonb_build_object(
        'total', v_total,
        'chair', 1,
        'vice_chairs', v_vice_chairs,
        'bundlers', v_bundlers,
        'event_hosts', v_hosts,
        'members', v_members,
        'avg_bundler_goal', v_avg_bundler_goal
    );
END;
$$ LANGUAGE plpgsql;

-- Calculate daily/weekly fundraising targets with early-weighting
CREATE OR REPLACE FUNCTION fc_calculate_pace(
    p_total_budget NUMERIC,
    p_raised_to_date NUMERIC,
    p_election_date DATE
)
RETURNS JSONB AS $$
DECLARE
    v_days_remaining INT;
    v_remaining NUMERIC;
    v_daily NUMERIC;
    v_weekly NUMERIC;
    v_pct_timeline NUMERIC;
    v_pct_goal NUMERIC;
    v_pace_ratio NUMERIC;
    v_pace_status VARCHAR;
BEGIN
    v_days_remaining = GREATEST(1, p_election_date - CURRENT_DATE);
    v_remaining = p_total_budget - p_raised_to_date;
    v_pct_goal = CASE WHEN p_total_budget > 0 THEN (p_raised_to_date / p_total_budget) * 100 ELSE 0 END;

    -- Early-weight: first 60% of timeline should raise 70% of budget
    v_pct_timeline = 100.0 - ((v_days_remaining::NUMERIC / GREATEST(1, v_days_remaining + (CURRENT_DATE - (p_election_date - INTERVAL '365 days')::date))) * 100);

    -- Daily target: remaining / days, with 1.15x multiplier for catch-up pressure
    v_daily = v_remaining / v_days_remaining;
    v_weekly = v_daily * 7;

    -- Pace ratio
    v_pace_ratio = CASE WHEN v_pct_timeline > 0 THEN v_pct_goal / v_pct_timeline ELSE 1.0 END;

    v_pace_status = CASE
        WHEN v_pace_ratio >= 1.1 THEN 'ahead'
        WHEN v_pace_ratio >= 0.9 THEN 'on_track'
        WHEN v_pace_ratio >= 0.7 THEN 'behind'
        ELSE 'critical'
    END;

    RETURN jsonb_build_object(
        'days_remaining', v_days_remaining,
        'remaining', v_remaining,
        'daily_target', ROUND(v_daily, 2),
        'weekly_target', ROUND(v_weekly, 2),
        'pct_goal', ROUND(v_pct_goal, 2),
        'pct_timeline', ROUND(v_pct_timeline, 2),
        'pace_ratio', ROUND(v_pace_ratio, 2),
        'pace_status', v_pace_status
    );
END;
$$ LANGUAGE plpgsql;

-- Score a member's performance (0-100)
CREATE OR REPLACE FUNCTION fc_score_member(p_member_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_member RECORD;
    v_score NUMERIC := 0;
BEGIN
    SELECT * INTO v_member FROM public.fc_members WHERE member_id = p_member_id;
    IF NOT FOUND THEN RETURN 0; END IF;

    -- Personal gift (20 points)
    IF v_member.personal_gift_status = 'received' THEN v_score := v_score + 20;
    ELSIF v_member.personal_gift_status = 'pledged' THEN v_score := v_score + 10;
    END IF;

    -- Fundraising progress (40 points)
    IF v_member.fundraising_pledge > 0 THEN
        v_score := v_score + LEAST(40, (v_member.fundraising_raised / v_member.fundraising_pledge) * 40);
    END IF;

    -- Activity (20 points)
    v_score := v_score + LEAST(5, v_member.events_attended * 2.5);
    v_score := v_score + LEAST(5, v_member.events_hosted * 5);
    v_score := v_score + LEAST(5, v_member.total_asks_made * 0.5);
    v_score := v_score + LEAST(5, v_member.total_introductions * 1);

    -- Meeting attendance (10 points)
    IF (v_member.meetings_attended + v_member.meetings_missed) > 0 THEN
        v_score := v_score + (v_member.meetings_attended::NUMERIC / (v_member.meetings_attended + v_member.meetings_missed)) * 10;
    END IF;

    -- Engagement (10 points) — bonus for consistency
    v_score := v_score + LEAST(10, (
        SELECT COUNT(*) FROM public.fc_weekly_reports
        WHERE member_id = p_member_id AND dollars_received > 0
    ) * 2);

    RETURN ROUND(LEAST(100, v_score), 2);
END;
$$ LANGUAGE plpgsql;
