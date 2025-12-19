-- ============================================================================
-- LOCAL CANDIDATE INTELLIGENCE QUESTIONNAIRE & PROFILING SYSTEM
-- Complete 500+ Field Candidate Profile with Local Focus
-- November 28, 2025
-- ============================================================================

-- ============================================================================
-- PART 1: LOCAL CANDIDATE QUESTIONNAIRE (273 Questions)
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_candidate_questionnaire (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL REFERENCES local_candidates(id) ON DELETE CASCADE,
    
    -- =========================================================================
    -- SECTION A: LOCAL ENGAGEMENT HISTORY (45 questions)
    -- =========================================================================
    
    -- A1: Years in Community
    q_years_in_county INT,
    q_years_in_municipality INT,
    q_years_in_precinct INT,
    q_generations_in_county INT, -- How many generations family in county
    q_born_in_county BOOLEAN,
    q_where_grew_up VARCHAR(200),
    
    -- A2: Property Ownership
    q_owns_home_in_district BOOLEAN,
    q_years_at_current_address INT,
    q_owns_other_property_county BOOLEAN,
    q_owns_farmland BOOLEAN,
    q_farm_acres INT,
    q_owns_business_property BOOLEAN,
    
    -- A3: Local Government Engagement
    q_attended_commissioner_mtgs INT, -- Past 2 years
    q_attended_school_board_mtgs INT,
    q_attended_city_council_mtgs INT,
    q_attended_planning_board_mtgs INT,
    q_spoken_at_public_hearings INT,
    q_filed_public_records_requests INT,
    q_served_on_county_board TEXT, -- Which boards
    q_served_on_municipal_board TEXT,
    q_appointed_positions_held TEXT,
    
    -- A4: Community Organizations
    q_rotary_member BOOLEAN,
    q_rotary_leadership VARCHAR(100),
    q_lions_member BOOLEAN,
    q_kiwanis_member BOOLEAN,
    q_jaycees_member BOOLEAN,
    q_chamber_member BOOLEAN,
    q_chamber_leadership VARCHAR(100),
    q_farm_bureau_member BOOLEAN,
    q_homeowners_assoc_role VARCHAR(100),
    q_neighborhood_watch BOOLEAN,
    q_volunteer_fire_dept BOOLEAN,
    q_auxiliary_police BOOLEAN,
    
    -- A5: Local Volunteer History
    q_volunteer_hours_yearly INT,
    q_volunteer_organizations JSONB DEFAULT '[]'::jsonb,
    q_volunteer_leadership_roles JSONB DEFAULT '[]'::jsonb,
    q_disaster_relief_volunteer BOOLEAN,
    q_food_bank_volunteer BOOLEAN,
    q_habitat_humanity_volunteer BOOLEAN,
    q_youth_coach BOOLEAN,
    q_youth_coach_sports TEXT,
    q_scout_leader BOOLEAN,
    q_scout_leader_years INT,
    
    -- =========================================================================
    -- SECTION B: REPUBLICAN PARTY ENGAGEMENT (40 questions)
    -- =========================================================================
    
    -- B1: Party Registration
    q_party_registration VARCHAR(20),
    q_years_registered_republican INT,
    q_previously_other_party BOOLEAN,
    q_previous_party VARCHAR(20),
    q_year_switched_to_gop INT,
    q_why_republican TEXT,
    
    -- B2: Local GOP Involvement
    q_county_gop_member BOOLEAN,
    q_county_gop_member_years INT,
    q_county_gop_officer BOOLEAN,
    q_county_gop_position VARCHAR(100),
    q_county_gop_committee VARCHAR(100),
    q_precinct_chair BOOLEAN,
    q_precinct_chair_years INT,
    q_district_convention_delegate BOOLEAN,
    q_district_convention_years TEXT,
    q_state_convention_delegate BOOLEAN,
    q_state_convention_years TEXT,
    q_national_convention_delegate BOOLEAN,
    q_national_convention_year INT,
    
    -- B3: GOP Volunteer History
    q_gop_volunteer_campaigns INT, -- Number of campaigns
    q_gop_campaigns_volunteered JSONB DEFAULT '[]'::jsonb,
    q_gop_phone_bank_hours INT,
    q_gop_door_knock_hours INT,
    q_gop_poll_greeter BOOLEAN,
    q_gop_poll_observer BOOLEAN,
    q_gop_hq_volunteer BOOLEAN,
    q_gop_event_organizer BOOLEAN,
    
    -- B4: GOP Donor History
    q_donated_to_ncgop BOOLEAN,
    q_ncgop_lifetime_giving NUMERIC(10,2),
    q_donated_to_county_gop BOOLEAN,
    q_county_gop_lifetime_giving NUMERIC(10,2),
    q_rnc_donor BOOLEAN,
    q_rnc_lifetime_giving NUMERIC(10,2),
    q_lincoln_club_member BOOLEAN,
    q_eagle_club_member BOOLEAN,
    
    -- B5: Candidate Support History
    q_local_candidates_supported JSONB DEFAULT '[]'::jsonb,
    q_local_candidates_donated JSONB DEFAULT '[]'::jsonb,
    q_state_candidates_supported JSONB DEFAULT '[]'::jsonb,
    q_federal_candidates_supported JSONB DEFAULT '[]'::jsonb,
    q_trump_supporter_2016 BOOLEAN,
    q_trump_supporter_2020 BOOLEAN,
    q_trump_supporter_2024 BOOLEAN,
    q_trump_rally_attended BOOLEAN,
    q_trump_rally_count INT,
    
    -- =========================================================================
    -- SECTION C: IDEOLOGY & ISSUE POSITIONS (50 questions)
    -- =========================================================================
    
    -- C1: Self-Identification (1-10 scale, 10 = most conservative)
    q_ideology_self_rating INT CHECK (q_ideology_self_rating BETWEEN 1 AND 10),
    q_fiscal_conservative_rating INT CHECK (q_fiscal_conservative_rating BETWEEN 1 AND 10),
    q_social_conservative_rating INT CHECK (q_social_conservative_rating BETWEEN 1 AND 10),
    q_populist_rating INT CHECK (q_populist_rating BETWEEN 1 AND 10),
    q_libertarian_rating INT CHECK (q_libertarian_rating BETWEEN 1 AND 10),
    
    -- C2: National Issues (1-10, 10 = most conservative position)
    q_pos_abortion INT CHECK (q_pos_abortion BETWEEN 1 AND 10),
    q_pos_abortion_detail TEXT,
    q_pos_guns INT CHECK (q_pos_guns BETWEEN 1 AND 10),
    q_pos_guns_detail TEXT,
    q_nra_member BOOLEAN,
    q_concealed_carry_permit BOOLEAN,
    q_pos_immigration INT CHECK (q_pos_immigration BETWEEN 1 AND 10),
    q_pos_immigration_detail TEXT,
    q_pos_border_wall INT CHECK (q_pos_border_wall BETWEEN 1 AND 10),
    q_pos_federal_spending INT CHECK (q_pos_federal_spending BETWEEN 1 AND 10),
    q_pos_healthcare INT CHECK (q_pos_healthcare BETWEEN 1 AND 10),
    q_pos_climate INT CHECK (q_pos_climate BETWEEN 1 AND 10),
    q_pos_trade INT CHECK (q_pos_trade BETWEEN 1 AND 10),
    q_pos_foreign_policy INT CHECK (q_pos_foreign_policy BETWEEN 1 AND 10),
    
    -- C3: State Issues
    q_pos_nc_taxes INT CHECK (q_pos_nc_taxes BETWEEN 1 AND 10),
    q_pos_nc_education INT CHECK (q_pos_nc_education BETWEEN 1 AND 10),
    q_pos_school_choice INT CHECK (q_pos_school_choice BETWEEN 1 AND 10),
    q_pos_nc_medicaid INT CHECK (q_pos_nc_medicaid BETWEEN 1 AND 10),
    q_pos_nc_lottery INT CHECK (q_pos_nc_lottery BETWEEN 1 AND 10),
    
    -- C4: Local Issues (Most Important for Local Races)
    q_pos_local_taxes INT CHECK (q_pos_local_taxes BETWEEN 1 AND 10),
    q_pos_local_taxes_detail TEXT,
    q_pos_local_schools INT CHECK (q_pos_local_schools BETWEEN 1 AND 10),
    q_pos_local_schools_detail TEXT,
    q_pos_local_crime INT CHECK (q_pos_local_crime BETWEEN 1 AND 10),
    q_pos_local_crime_detail TEXT,
    q_pos_local_growth INT CHECK (q_pos_local_growth BETWEEN 1 AND 10),
    q_pos_local_growth_detail TEXT,
    q_pos_local_zoning INT CHECK (q_pos_local_zoning BETWEEN 1 AND 10),
    q_pos_local_environment INT CHECK (q_pos_local_environment BETWEEN 1 AND 10),
    q_pos_local_infrastructure INT CHECK (q_pos_local_infrastructure BETWEEN 1 AND 10),
    
    -- C5: Hot Button Local Issues
    q_pos_masks_mandates INT CHECK (q_pos_masks_mandates BETWEEN 1 AND 10),
    q_pos_vaccine_mandates INT CHECK (q_pos_vaccine_mandates BETWEEN 1 AND 10),
    q_pos_dei_programs INT CHECK (q_pos_dei_programs BETWEEN 1 AND 10),
    q_pos_crt_schools INT CHECK (q_pos_crt_schools BETWEEN 1 AND 10),
    q_pos_transgender_policies INT CHECK (q_pos_transgender_policies BETWEEN 1 AND 10),
    q_pos_library_materials INT CHECK (q_pos_library_materials BETWEEN 1 AND 10),
    q_pos_sanctuary_policies INT CHECK (q_pos_sanctuary_policies BETWEEN 1 AND 10),
    q_pos_287g_program INT CHECK (q_pos_287g_program BETWEEN 1 AND 10),
    
    -- C6: Priority Issues (Rank top 5)
    q_priority_issue_1 VARCHAR(100),
    q_priority_issue_2 VARCHAR(100),
    q_priority_issue_3 VARCHAR(100),
    q_priority_issue_4 VARCHAR(100),
    q_priority_issue_5 VARCHAR(100),
    
    -- =========================================================================
    -- SECTION D: FAITH & VALUES (25 questions)
    -- =========================================================================
    
    q_religious_affiliation VARCHAR(100),
    q_denomination VARCHAR(100),
    q_church_name VARCHAR(200),
    q_church_city VARCHAR(100),
    q_church_member_years INT,
    q_church_attendance VARCHAR(50), -- 'weekly', 'monthly', 'occasionally'
    q_church_leadership_role VARCHAR(200),
    q_sunday_school_teacher BOOLEAN,
    q_deacon_elder BOOLEAN,
    q_choir_member BOOLEAN,
    q_small_group_leader BOOLEAN,
    q_mission_trips INT,
    q_mission_trip_locations TEXT,
    q_faith_testimony TEXT,
    q_faith_influences_politics BOOLEAN,
    q_faith_influences_how TEXT,
    q_pro_life_activism BOOLEAN,
    q_pro_life_activities TEXT,
    q_crisis_pregnancy_volunteer BOOLEAN,
    q_march_for_life_attended INT,
    q_religious_liberty_important INT CHECK (q_religious_liberty_important BETWEEN 1 AND 10),
    q_prayer_in_schools INT CHECK (q_prayer_in_schools BETWEEN 1 AND 10),
    q_ten_commandments_display INT CHECK (q_ten_commandments_display BETWEEN 1 AND 10),
    q_christian_nation_belief INT CHECK (q_christian_nation_belief BETWEEN 1 AND 10),
    
    -- =========================================================================
    -- SECTION E: LIFESTYLE & DEMOGRAPHICS (30 questions)
    -- =========================================================================
    
    -- E1: Family
    q_marital_status VARCHAR(50),
    q_spouse_name VARCHAR(200),
    q_spouse_occupation VARCHAR(200),
    q_spouse_employer VARCHAR(200),
    q_spouse_political_active BOOLEAN,
    q_years_married INT,
    q_children_count INT,
    q_children_ages TEXT,
    q_children_public_school BOOLEAN,
    q_children_private_school BOOLEAN,
    q_children_homeschool BOOLEAN,
    q_grandchildren_count INT,
    q_extended_family_in_county INT,
    
    -- E2: Lifestyle Indicators
    q_gun_owner BOOLEAN,
    q_guns_owned_count INT,
    q_hunting_license BOOLEAN,
    q_fishing_license BOOLEAN,
    q_pickup_truck_owner BOOLEAN,
    q_american_flag_display BOOLEAN,
    q_trump_flag_display BOOLEAN,
    q_thin_blue_line_support BOOLEAN,
    q_conservative_bumper_stickers BOOLEAN,
    q_yard_signs_displayed INT, -- Past elections
    
    -- E3: Media Consumption
    q_primary_news_source VARCHAR(100),
    q_watches_fox_news BOOLEAN,
    q_watches_newsmax BOOLEAN,
    q_watches_oan BOOLEAN,
    q_listens_talk_radio BOOLEAN,
    q_talk_radio_shows TEXT,
    q_reads_local_paper BOOLEAN,
    q_local_paper_name VARCHAR(100),
    q_podcast_listener BOOLEAN,
    q_conservative_podcasts TEXT,
    
    -- =========================================================================
    -- SECTION F: LOCAL CHARITABLE & CIVIC CONTRIBUTIONS (25 questions)
    -- =========================================================================
    
    q_local_charity_donations NUMERIC(10,2), -- Annual
    q_local_charities_supported JSONB DEFAULT '[]'::jsonb,
    q_united_way_donor BOOLEAN,
    q_community_foundation_donor BOOLEAN,
    q_scholarship_fund_donor BOOLEAN,
    q_local_scholarship_name VARCHAR(200),
    q_hospital_foundation_donor BOOLEAN,
    q_fire_dept_supporter BOOLEAN,
    q_sheriff_foundation_donor BOOLEAN,
    q_fop_supporter BOOLEAN,
    q_veterans_charity_donor BOOLEAN,
    q_veterans_charities TEXT,
    q_crisis_pregnancy_donor BOOLEAN,
    q_crisis_pregnancy_name VARCHAR(200),
    q_food_bank_donor BOOLEAN,
    q_homeless_shelter_donor BOOLEAN,
    q_animal_shelter_donor BOOLEAN,
    q_arts_culture_donor BOOLEAN,
    q_local_museum_supporter BOOLEAN,
    q_historical_society_member BOOLEAN,
    q_conservation_easement BOOLEAN,
    q_land_trust_donor BOOLEAN,
    q_4h_supporter BOOLEAN,
    q_ffa_supporter BOOLEAN,
    q_youth_sports_sponsor BOOLEAN,
    
    -- =========================================================================
    -- SECTION G: EDUCATION LOCAL ENGAGEMENT (20 questions)
    -- =========================================================================
    
    q_pta_member BOOLEAN,
    q_pta_officer BOOLEAN,
    q_pta_position VARCHAR(100),
    q_school_volunteer BOOLEAN,
    q_school_volunteer_hours INT, -- Yearly
    q_school_booster_club BOOLEAN,
    q_booster_club_position VARCHAR(100),
    q_school_board_attendee BOOLEAN,
    q_school_board_speaker BOOLEAN,
    q_school_issues_spoken TEXT,
    q_homeschool_coop_member BOOLEAN,
    q_private_school_board BOOLEAN,
    q_charter_school_supporter BOOLEAN,
    q_school_choice_advocate BOOLEAN,
    q_moms_for_liberty_member BOOLEAN,
    q_parents_rights_group BOOLEAN,
    q_curriculum_reviewer BOOLEAN,
    q_library_review_committee BOOLEAN,
    q_education_advocacy_groups JSONB DEFAULT '[]'::jsonb,
    
    -- =========================================================================
    -- SECTION H: FAMILY LOCAL ENGAGEMENT (15 questions)
    -- =========================================================================
    
    q_spouse_civic_involvement TEXT,
    q_spouse_political_involvement TEXT,
    q_spouse_church_leadership BOOLEAN,
    q_children_school_activities JSONB DEFAULT '[]'::jsonb,
    q_family_business_community BOOLEAN,
    q_family_business_employees INT,
    q_family_employs_local BOOLEAN,
    q_family_generations_business INT,
    q_family_farm BOOLEAN,
    q_family_farm_generations INT,
    q_family_charitable_foundation BOOLEAN,
    q_family_political_legacy TEXT,
    q_relatives_held_office TEXT,
    q_family_endorsements TEXT,
    q_family_campaign_help BOOLEAN,
    
    -- =========================================================================
    -- SECTION I: SOCIAL MEDIA & ONLINE PRESENCE (30 questions)
    -- =========================================================================
    
    -- I1: Personal Accounts
    q_facebook_personal VARCHAR(500),
    q_facebook_followers INT,
    q_facebook_posts_political BOOLEAN,
    q_twitter_personal VARCHAR(100),
    q_twitter_followers INT,
    q_instagram_personal VARCHAR(100),
    q_instagram_followers INT,
    q_truth_social VARCHAR(100),
    q_truth_social_followers INT,
    q_parler_account VARCHAR(100),
    q_gab_account VARCHAR(100),
    q_linkedin_url VARCHAR(500),
    q_youtube_channel VARCHAR(500),
    q_tiktok_account VARCHAR(100),
    q_podcast_host BOOLEAN,
    q_podcast_name VARCHAR(200),
    q_blog_author BOOLEAN,
    q_blog_url VARCHAR(500),
    
    -- I2: Political Social Media Activity
    q_shares_political_content BOOLEAN,
    q_political_content_frequency VARCHAR(50), -- 'daily', 'weekly', 'monthly'
    q_conservative_pages_followed JSONB DEFAULT '[]'::jsonb,
    q_local_political_groups JSONB DEFAULT '[]'::jsonb,
    q_engaged_local_fb_groups JSONB DEFAULT '[]'::jsonb,
    q_twitter_political_follows INT,
    q_viral_political_posts INT,
    q_controversial_posts_deleted BOOLEAN,
    q_social_media_attacks_received BOOLEAN,
    q_doxxing_concerns BOOLEAN,
    
    -- =========================================================================
    -- SECTION J: LOCAL CONSERVATIVE GROUPS (20 questions)
    -- =========================================================================
    
    q_tea_party_member BOOLEAN,
    q_tea_party_years INT,
    q_912_project_member BOOLEAN,
    q_local_conservative_club BOOLEAN,
    q_conservative_club_name VARCHAR(200),
    q_conservative_club_role VARCHAR(100),
    q_federalist_society_member BOOLEAN,
    q_heritage_foundation_member BOOLEAN,
    q_turning_point_involved BOOLEAN,
    q_young_republicans BOOLEAN,
    q_college_republicans_past BOOLEAN,
    q_american_legion_member BOOLEAN,
    q_vfw_member BOOLEAN,
    q_oath_keepers_member BOOLEAN,
    q_three_percenters_member BOOLEAN,
    q_constitutional_sheriff BOOLEAN,
    q_second_amendment_groups JSONB DEFAULT '[]'::jsonb,
    q_pro_life_organizations JSONB DEFAULT '[]'::jsonb,
    q_christian_political_groups JSONB DEFAULT '[]'::jsonb,
    
    -- =========================================================================
    -- SECTION K: PRESS & PUBLIC RECORD (20 questions)
    -- =========================================================================
    
    -- K1: Positive Press
    q_positive_press_mentions INT,
    q_positive_press_articles JSONB DEFAULT '[]'::jsonb,
    q_awards_received JSONB DEFAULT '[]'::jsonb,
    q_community_recognition TEXT,
    q_business_awards TEXT,
    q_military_awards TEXT,
    q_civic_awards TEXT,
    q_endorsement_press TEXT,
    
    -- K2: Negative Press / Vulnerabilities
    q_negative_press_mentions INT,
    q_negative_press_articles JSONB DEFAULT '[]'::jsonb,
    q_lawsuits_involved INT,
    q_lawsuit_details TEXT,
    q_bankruptcies INT,
    q_foreclosures INT,
    q_tax_liens BOOLEAN,
    q_criminal_record BOOLEAN,
    q_criminal_details TEXT,
    q_civil_judgments INT,
    q_dui_arrests INT,
    q_domestic_issues BOOLEAN,
    q_ethics_complaints INT,
    q_controversial_statements TEXT,
    q_opposition_research_concerns TEXT,
    
    -- =========================================================================
    -- SECTION L: PAST ELECTIONS & FUNDRAISING (25 questions)
    -- =========================================================================
    
    -- L1: Past Campaigns
    q_previous_campaigns INT,
    q_previous_campaigns_detail JSONB DEFAULT '[]'::jsonb,
    -- Format: [{"year": 2020, "office": "Commissioner", "result": "won", "votes": 15000, "pct": 52.3}]
    q_previous_wins INT,
    q_previous_losses INT,
    q_closest_race_margin DECIMAL(5,2),
    q_best_race_margin DECIMAL(5,2),
    q_total_votes_received_career INT,
    
    -- L2: Fundraising History
    q_total_raised_career NUMERIC(12,2),
    q_total_donors_career INT,
    q_max_single_campaign NUMERIC(12,2),
    q_avg_donation_career NUMERIC(10,2),
    q_self_funded_amount NUMERIC(12,2),
    q_pac_contributions NUMERIC(12,2),
    q_party_contributions NUMERIC(12,2),
    q_major_donors JSONB DEFAULT '[]'::jsonb,
    -- Format: [{"name": "John Smith", "total": 5000, "relationship": "business partner"}]
    q_bundlers JSONB DEFAULT '[]'::jsonb,
    q_fundraising_events_hosted INT,
    q_fundraising_network_strength INT CHECK (q_fundraising_network_strength BETWEEN 1 AND 10),
    
    -- L3: Donor Base Analysis
    q_donor_retention_rate DECIMAL(5,2),
    q_recurring_donors INT,
    q_donor_geographic_spread VARCHAR(50), -- 'local', 'regional', 'statewide'
    q_corporate_donors_pct DECIMAL(5,2),
    q_small_donor_pct DECIMAL(5,2),
    q_grassroots_strength INT CHECK (q_grassroots_strength BETWEEN 1 AND 10),
    
    -- =========================================================================
    -- METADATA
    -- =========================================================================
    
    questionnaire_version VARCHAR(10) DEFAULT '1.0',
    completion_pct INT DEFAULT 0,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    verified_by VARCHAR(100),
    verified_at TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_candidate_questionnaire UNIQUE (candidate_id)
);

-- ============================================================================
-- PART 2: LOCAL FACEBOOK/SOCIAL GROUPS DATABASE
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_conservative_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Group Identity
    group_name VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL, -- 'facebook', 'telegram', 'parler', 'truth_social', 'gab', 'discord'
    group_url VARCHAR(500),
    group_type VARCHAR(50), -- 'county_gop', 'tea_party', 'moms_liberty', 'gun_rights', 'pro_life', 'general_conservative'
    
    -- Geographic Scope
    county VARCHAR(100),
    municipality VARCHAR(100),
    geographic_scope VARCHAR(50), -- 'precinct', 'municipal', 'county', 'regional', 'statewide'
    
    -- Group Details
    description TEXT,
    member_count INT,
    admin_names JSONB DEFAULT '[]'::jsonb,
    founding_year INT,
    meeting_frequency VARCHAR(50),
    meeting_location VARCHAR(200),
    
    -- Political Classification
    primary_focus VARCHAR(100), -- 'general_conservative', 'pro_life', 'gun_rights', 'education', 'local_issues'
    faction_alignment VARCHAR(4) REFERENCES faction_types(code),
    activism_level VARCHAR(20), -- 'low', 'moderate', 'high', 'very_high'
    influence_rating INT CHECK (influence_rating BETWEEN 1 AND 10),
    
    -- Topics Supported (For)
    topics_for JSONB DEFAULT '[]'::jsonb,
    -- Format: ["2nd Amendment", "School Choice", "Lower Taxes", "Back the Blue", "Pro-Life"]
    
    -- Topics Opposed (Against)
    topics_against JSONB DEFAULT '[]'::jsonb,
    -- Format: ["CRT", "Mask Mandates", "Tax Increases", "Gun Control", "Abortion"]
    
    -- Engagement Metrics
    avg_post_engagement INT,
    avg_event_attendance INT,
    endorsements_made JSONB DEFAULT '[]'::jsonb,
    candidates_supported JSONB DEFAULT '[]'::jsonb,
    
    -- Campaign Value
    campaign_outreach_value INT CHECK (campaign_outreach_value BETWEEN 1 AND 10),
    volunteer_source_rating INT CHECK (volunteer_source_rating BETWEEN 1 AND 10),
    donor_source_rating INT CHECK (donor_source_rating BETWEEN 1 AND 10),
    
    -- Relationship Status
    relationship_status VARCHAR(20) DEFAULT 'unknown', -- 'unknown', 'cold', 'warm', 'hot', 'allied'
    primary_contact_name VARCHAR(200),
    primary_contact_email VARCHAR(255),
    primary_contact_phone VARCHAR(50),
    last_contact_date DATE,
    
    -- Metadata
    verified BOOLEAN DEFAULT FALSE,
    last_verified DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Candidate membership in local groups
CREATE TABLE IF NOT EXISTS candidate_group_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL REFERENCES local_candidates(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES local_conservative_groups(id) ON DELETE CASCADE,
    
    membership_status VARCHAR(20) DEFAULT 'member', -- 'member', 'admin', 'founder', 'supporter'
    member_since DATE,
    activity_level VARCHAR(20), -- 'inactive', 'occasional', 'active', 'very_active'
    posts_count INT DEFAULT 0,
    events_attended INT DEFAULT 0,
    leadership_role VARCHAR(100),
    endorsement_received BOOLEAN DEFAULT FALSE,
    endorsement_date DATE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_candidate_group UNIQUE (candidate_id, group_id)
);

-- ============================================================================
-- PART 3: CANDIDATE SOCIAL MEDIA MONITORING
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_social_mentions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL REFERENCES local_candidates(id) ON DELETE CASCADE,
    
    -- Source
    platform VARCHAR(50) NOT NULL, -- 'facebook', 'twitter', 'instagram', 'youtube', 'news', 'blog'
    source_url VARCHAR(500),
    source_account VARCHAR(200),
    source_follower_count INT,
    
    -- Mention Details
    mention_date TIMESTAMP NOT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    mention_type VARCHAR(50), -- 'endorsement', 'attack', 'news', 'discussion', 'tag', 'share'
    
    -- Content
    headline VARCHAR(500),
    content_snippet TEXT,
    full_content TEXT,
    media_type VARCHAR(50), -- 'text', 'image', 'video', 'article'
    media_url VARCHAR(500),
    
    -- Sentiment Analysis
    sentiment VARCHAR(20), -- 'positive', 'negative', 'neutral', 'mixed'
    sentiment_score DECIMAL(5,2), -- -1.0 to 1.0
    
    -- Engagement Metrics
    likes INT DEFAULT 0,
    shares INT DEFAULT 0,
    comments INT DEFAULT 0,
    views INT DEFAULT 0,
    engagement_total INT GENERATED ALWAYS AS (likes + shares + comments) STORED,
    
    -- Political Classification
    issue_tags JSONB DEFAULT '[]'::jsonb,
    faction_relevance VARCHAR(4) REFERENCES faction_types(code),
    
    -- Impact Assessment
    reach_estimate INT,
    impact_rating INT CHECK (impact_rating BETWEEN 1 AND 10),
    response_needed BOOLEAN DEFAULT FALSE,
    response_urgency VARCHAR(20), -- 'low', 'medium', 'high', 'critical'
    
    -- Status
    reviewed BOOLEAN DEFAULT FALSE,
    reviewed_by VARCHAR(100),
    reviewed_at TIMESTAMP,
    action_taken TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_social_mentions_candidate ON candidate_social_mentions(candidate_id);
CREATE INDEX IF NOT EXISTS idx_social_mentions_date ON candidate_social_mentions(mention_date DESC);
CREATE INDEX IF NOT EXISTS idx_social_mentions_sentiment ON candidate_social_mentions(sentiment);
CREATE INDEX IF NOT EXISTS idx_social_mentions_platform ON candidate_social_mentions(platform);
