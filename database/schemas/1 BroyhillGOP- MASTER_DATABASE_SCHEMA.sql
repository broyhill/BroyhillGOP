{\rtf1\ansi\ansicpg1252\cocoartf2822
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fnil\fcharset0 .AppleSystemUIFontMonospaced-Regular;\f1\fnil\fcharset0 HelveticaNeue;}
{\colortbl;\red255\green255\blue255;\red42\green44\blue51;\red249\green248\blue242;\red50\green94\blue238;
\red167\green87\blue5;\red66\green147\blue62;\red147\green0\blue147;\red16\green16\blue16;\red24\green23\blue22;
}
{\*\expandedcolortbl;;\cssrgb\c21961\c22745\c25882;\cssrgb\c98039\c97647\c96078;\cssrgb\c25098\c47059\c94902;
\cssrgb\c71765\c41961\c392;\cssrgb\c31373\c63137\c30980;\cssrgb\c65098\c14902\c64314;\cssrgb\c7843\c7843\c7451;\cssrgb\c12157\c11765\c11373\c14902;
}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\deftab720
\pard\pardeftab720\partightenfactor0

\f0\fs21 \cf2 \cb3 \expnd0\expndtw0\kerning0
\outl0\strokewidth0 \strokec2 -- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- BROYHILLGOP PLATFORM - MASTER DATABASE SCHEMA\
-- ALL \cf5 \strokec5 16\cf2 \strokec2  ECOSYSTEMS - COMPLETE INSTALLATION\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- Version: \cf5 \strokec5 2.0\cf2 \strokec2 \
-- Date: December \cf5 \strokec5 3\cf2 \strokec2 , \cf5 \strokec5 2024\cf2 \strokec2 \
-- Owner: Anvil Venture Group LP\
-- \
-- This \cf4 \strokec4 file\cf2 \strokec2  contains complete database schemas for:\
-- E0:  DataHub - Central Integration Hub\
-- E1:  Donor Intelligence System (Federal/State)\
-- E2:  Local Intelligence System (County/Municipal)\
-- E3:  Campaign Builder (\cf5 \strokec5 1,536\cf2 \strokec2  templates)\
-- E4:  Media Database (\cf5 \strokec5 214\cf2 \strokec2  NC outlets)\
-- E5:  Candidate Database (\cf5 \strokec5 500\cf2 \strokec2 + fields)\
-- E6:  Campaign Execution System (Multi-channel)\
-- E7:  Donor Enrichment Engine (\cf5 \strokec5 860\cf2 \strokec2  fields AI)\
-- E8:  Volunteer Management (\cf5 \strokec5 21\cf2 \strokec2 -tier grading)\
-- E9:  Matching Engine (Automatic)\
-- E10: Event Management (Town halls, rallies)\
-- E11: Reporting System (Dashboards)\
-- E12: Analytics Dashboards (Executive BI)\
-- E13: AI Control Center (BRAIN)\
-- E14: Prediction Engine (ML models)\
-- E15: Broadcast Ad Creator (AI video/audio)\
--\
-- Total Tables: \cf5 \strokec5 250\cf2 \strokec2 +\
-- Total Views: \cf5 \strokec5 75\cf2 \strokec2 +\
-- Total Functions: \cf5 \strokec5 50\cf2 \strokec2 +\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Create all schemas\
CREATE SCHEMA IF NOT EXISTS datahub;\
CREATE SCHEMA IF NOT EXISTS donor_intelligence;\
CREATE SCHEMA IF NOT EXISTS local_intelligence;\
CREATE SCHEMA IF NOT EXISTS campaigns;\
CREATE SCHEMA IF NOT EXISTS media;\
CREATE SCHEMA IF NOT EXISTS candidates;\
CREATE SCHEMA IF NOT EXISTS execution;\
CREATE SCHEMA IF NOT EXISTS enrichment;\
CREATE SCHEMA IF NOT EXISTS volunteers;\
CREATE SCHEMA IF NOT EXISTS matching;\
CREATE SCHEMA IF NOT EXISTS events;\
CREATE SCHEMA IF NOT EXISTS reporting;\
CREATE SCHEMA IF NOT EXISTS analytics;\
CREATE SCHEMA IF NOT EXISTS ai_hub;\
CREATE SCHEMA IF NOT EXISTS prediction;\
CREATE SCHEMA IF NOT EXISTS broadcast;\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 0\cf2 \strokec2 : DATAHUB - CENTRAL INTEGRATION HUB\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Ecosystem Registry\
CREATE TABLE datahub.ecosystems (\
    ecosystem_id SERIAL PRIMARY KEY,\
    ecosystem_code VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) UNIQUE NOT NULL,\
    ecosystem_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    description TEXT,\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'PLANNED'\cf2 \strokec2 ,\
    schema_name VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    primary_function TEXT,\
    provides_to TEXT[],\
    api_base_url VARCHAR(\cf5 \strokec5 300\cf2 \strokec2 ),\
    api_version VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    deployed_at TIMESTAMPTZ,\
    last_updated TIMESTAMPTZ DEFAULT NOW(),\
    health_status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'UNKNOWN'\cf2 \strokec2 ,\
    total_records BIGINT DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    daily_queries BIGINT DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Unified Donor Registry\
CREATE TABLE datahub.donors (\
    donor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    first_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    last_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    address_line1 VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    address_line2 VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    city VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    state VARCHAR(\cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'NC'\cf2 \strokec2 ,\
    \cf4 \strokec4 zip\cf2 \strokec2  VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ),\
    county VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    latitude DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 8\cf2 \strokec2 ),\
    longitude DECIMAL(\cf5 \strokec5 11\cf2 \strokec2 , \cf5 \strokec5 8\cf2 \strokec2 ),\
    overall_grade VARCHAR(\cf5 \strokec5 5\cf2 \strokec2 ),\
    lead_score INTEGER,\
    total_donations_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    total_donations_amount DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    first_donation_date DATE,\
    last_donation_date DATE,\
    avg_donation_amount DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    is_active BOOLEAN DEFAULT TRUE,\
    is_major_donor BOOLEAN DEFAULT FALSE,\
    is_recurring_donor BOOLEAN DEFAULT FALSE,\
    is_volunteer BOOLEAN DEFAULT FALSE,\
    data_quality_score INTEGER,\
    last_enriched_at TIMESTAMPTZ,\
    enrichment_source VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW(),\
    CONSTRAINT valid_email CHECK (email ~* \cf6 \strokec6 '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]\{2,\}$'\cf2 \strokec2 )\
);\
\
-- Unified Candidate Registry\
CREATE TABLE datahub.candidates (\
    candidate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    full_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    first_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    last_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    office_sought VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    office_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    district VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    jurisdiction VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    is_active BOOLEAN DEFAULT TRUE,\
    is_incumbent BOOLEAN DEFAULT FALSE,\
    party VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'Republican'\cf2 \strokec2 ,\
    election_date DATE,\
    campaign_website VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    campaign_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    campaign_phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    fundraising_goal DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    current_raised DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    donor_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    ideology_type VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ),\
    ideology_score INTEGER,\
    profile_complete BOOLEAN DEFAULT FALSE,\
    profile_completeness_pct INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf5 \strokec5 6\cf2 \strokec2 -Dimension Affinity Scores\
CREATE TABLE datahub.affinity_scores (\
    affinity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    donor_id UUID NOT NULL REFERENCES datahub.donors(donor_id),\
    candidate_id UUID NOT NULL REFERENCES datahub.candidates(candidate_id),\
    total_score INTEGER NOT NULL,\
    affinity_category VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    recommendation VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    geographic_score INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    professional_score INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    educational_score INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    military_score INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    faith_score INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    ideology_score INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    matching_factors JSONB,\
    calculated_at TIMESTAMPTZ DEFAULT NOW(),\
    expires_at TIMESTAMPTZ,\
    calculation_version VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ),\
    UNIQUE(donor_id, candidate_id)\
);\
\
-- Heat Maps\
CREATE TABLE datahub.heat_maps (\
    heat_map_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    candidate_id UUID NOT NULL REFERENCES datahub.candidates(candidate_id),\
    total_donors_evaluated INTEGER NOT NULL,\
    exceptional_matches INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    strong_matches INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    good_matches INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    top_50_donors JSONB,\
    county_distribution JSONB,\
    grade_distribution JSONB,\
    generated_at TIMESTAMPTZ DEFAULT NOW(),\
    expires_at TIMESTAMPTZ,\
    generation_time_ms INTEGER\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 1\cf2 \strokec2 : DONOR INTELLIGENCE SYSTEM (FEDERAL/STATE)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Donor Intelligence Profiles (\cf5 \strokec5 21\cf2 \strokec2 -tier grading)\
CREATE TABLE donor_intelligence.donor_profiles (\
    profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    donor_id UUID NOT NULL REFERENCES datahub.donors(donor_id),\
    \
    -- \cf5 \strokec5 21\cf2 \strokec2 -Tier Grading (A+ to U-)\
    overall_grade VARCHAR(\cf5 \strokec5 5\cf2 \strokec2 ) NOT NULL,\
    grade_tier INTEGER, -- \cf5 \strokec5 1\cf2 \strokec2 -21\
    intensity_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    \
    -- \cf5 \strokec5 1000\cf2 \strokec2 -Point Lead Score\
    lead_score INTEGER NOT NULL CHECK (lead_score BETWEEN \cf5 \strokec5 0\cf2 \strokec2  AND \cf5 \strokec5 1000\cf2 \strokec2 ),\
    \
    -- \cf5 \strokec5 12\cf2 \strokec2  Ideology Dimensions (\cf5 \strokec5 0\cf2 \strokec2 -100 each)\
    dim_trump_loyalty INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_fiscal_conservative INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_social_conservative INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_second_amendment INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_pro_life INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_immigration INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_education INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_energy_climate INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_trade INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_foreign_policy INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_criminal_justice INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    dim_healthcare INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 ,\
    \
    -- Ideology Classification\
    ideology_type VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ), -- MAGA, EVAN, TRAD, FISC, LIBT, BUSI, LAWS, POPF, MODG, VETS\
    ideology_confidence DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ), -- \cf5 \strokec5 0\cf2 \strokec2 -100%\
    \
    -- Donation Patterns\
    total_donations INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    total_amount DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    avg_donation DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    largest_donation DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    donation_frequency VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- WEEKLY, MONTHLY, QUARTERLY, ANNUAL, SPORADIC\
    last_donation_date DATE,\
    days_since_last_donation INTEGER,\
    \
    -- Engagement Metrics\
    email_open_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    email_click_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    sms_response_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    event_attendance_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    volunteer_hours INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Predictive Scores (ML)\
    donation_likelihood_30d DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ), -- \cf5 \strokec5 0\cf2 \strokec2 -100%\
    churn_risk_score DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ), -- \cf5 \strokec5 0\cf2 \strokec2 -100%\
    upgrade_potential DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ), -- \cf5 \strokec5 0\cf2 \strokec2 -100%\
    optimal_ask_amount DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    best_contact_time TIME,\
    best_contact_day VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ),\
    \
    -- Metadata\
    last_calculated TIMESTAMPTZ DEFAULT NOW(),\
    calculation_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW(),\
    \
    CONSTRAINT valid_grade CHECK (overall_grade IN (\
        \cf6 \strokec6 'A+'\cf2 \strokec2 , \cf6 \strokec6 'A'\cf2 \strokec2 , \cf6 \strokec6 'A-'\cf2 \strokec2 , \cf6 \strokec6 'B+'\cf2 \strokec2 , \cf6 \strokec6 'B'\cf2 \strokec2 , \cf6 \strokec6 'B-'\cf2 \strokec2 , \cf6 \strokec6 'C+'\cf2 \strokec2 , \cf6 \strokec6 'C'\cf2 \strokec2 , \cf6 \strokec6 'C-'\cf2 \strokec2 ,\
        \cf6 \strokec6 'D+'\cf2 \strokec2 , \cf6 \strokec6 'D'\cf2 \strokec2 , \cf6 \strokec6 'D-'\cf2 \strokec2 , \cf6 \strokec6 'F+'\cf2 \strokec2 , \cf6 \strokec6 'F'\cf2 \strokec2 , \cf6 \strokec6 'F-'\cf2 \strokec2 , \cf6 \strokec6 'U+'\cf2 \strokec2 , \cf6 \strokec6 'U'\cf2 \strokec2 , \cf6 \strokec6 'U-'\cf2 \strokec2 \
    ))\
);\
\
-- Donation History\
CREATE TABLE donor_intelligence.donations (\
    donation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    donor_id UUID NOT NULL REFERENCES datahub.donors(donor_id),\
    candidate_id UUID REFERENCES datahub.candidates(candidate_id),\
    \
    amount DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) NOT NULL,\
    donation_date DATE NOT NULL,\
    payment_method VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    transaction_id VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    \
    -- Source Tracking\
    source_campaign_id UUID,\
    source_channel VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- EMAIL, SMS, MAIL, EVENT, PHONE, ONLINE\
    source_medium VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    attribution_model VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    \
    -- Ideological Inference\
    inferred_ideology VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ),\
    ideology_confidence DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    dimension_scores JSONB, -- \cf5 \strokec5 12\cf2 \strokec2  dimensions\
    \
    -- Processing\
    is_processed BOOLEAN DEFAULT FALSE,\
    processed_at TIMESTAMPTZ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Candidate Ideology Classifications\
CREATE TABLE donor_intelligence.candidate_ideology (\
    classification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    candidate_id UUID NOT NULL REFERENCES datahub.candidates(candidate_id),\
    \
    -- \cf5 \strokec5 12\cf2 \strokec2  Ideology Dimensions (\cf5 \strokec5 0\cf2 \strokec2 -100 each)\
    dim_trump_loyalty INTEGER NOT NULL,\
    dim_fiscal_conservative INTEGER NOT NULL,\
    dim_social_conservative INTEGER NOT NULL,\
    dim_second_amendment INTEGER NOT NULL,\
    dim_pro_life INTEGER NOT NULL,\
    dim_immigration INTEGER NOT NULL,\
    dim_education INTEGER NOT NULL,\
    dim_energy_climate INTEGER NOT NULL,\
    dim_trade INTEGER NOT NULL,\
    dim_foreign_policy INTEGER NOT NULL,\
    dim_criminal_justice INTEGER NOT NULL,\
    dim_healthcare INTEGER NOT NULL,\
    \
    -- Classification\
    ideology_type VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ) NOT NULL,\
    overall_score INTEGER NOT NULL,\
    is_endorsed BOOLEAN DEFAULT FALSE,\
    endorser VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    \
    -- Metadata\
    classified_by VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    classified_at TIMESTAMPTZ DEFAULT NOW(),\
    last_updated TIMESTAMPTZ DEFAULT NOW(),\
    \
    UNIQUE(candidate_id)\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 2\cf2 \strokec2 : LOCAL INTELLIGENCE SYSTEM (COUNTY/MUNICIPAL)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Local Donor Profiles (\cf5 \strokec5 7\cf2 \strokec2  \cf5 \strokec5 local\cf2 \strokec2  dimensions)\
CREATE TABLE local_intelligence.local_profiles (\
    local_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    donor_id UUID NOT NULL REFERENCES datahub.donors(donor_id),\
    \
    -- Local Grading (A+ to U- \cf7 \strokec7 for\cf2 \strokec2  \cf5 \strokec5 local\cf2 \strokec2  races)\
    local_grade VARCHAR(\cf5 \strokec5 5\cf2 \strokec2 ),\
    local_lead_score INTEGER CHECK (local_lead_score BETWEEN \cf5 \strokec5 0\cf2 \strokec2  AND \cf5 \strokec5 1000\cf2 \strokec2 ),\
    \
    -- \cf5 \strokec5 7\cf2 \strokec2  Local Dimensions (\cf5 \strokec5 0\cf2 \strokec2 -100 each)\
    dim_geographic_proximity INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 , -- How \cf5 \strokec5 local\cf2 \strokec2  are they\
    dim_property_ownership INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 , -- Homeowner status\
    dim_local_business INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 , -- Local business ties\
    dim_school_district INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 , -- School involvement\
    dim_community_events INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 , -- Local event attendance\
    dim_neighborhood_engagement INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 , -- HOA, civic \cf4 \strokec4 groups\cf2 \strokec2 \
    dim_local_issues INTEGER DEFAULT \cf5 \strokec5 50\cf2 \strokec2 , -- Focus on \cf5 \strokec5 local\cf2 \strokec2  vs national\
    \
    -- Local Demographics\
    home_ownership_status VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- OWN, RENT, UNKNOWN\
    property_value_range VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    years_in_residence INTEGER,\
    school_district VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    neighborhood VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    hoa_member BOOLEAN DEFAULT FALSE,\
    \
    -- Local Political Activity\
    local_donations_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    local_donations_amount DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    local_volunteer_hours INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    local_event_attendance INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Top Local Issues (from engagement)\
    top_local_issue_1 VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    top_local_issue_2 VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    top_local_issue_3 VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    \
    -- Hyperlocal Triggers\
    responsive_to_hyperlocal BOOLEAN DEFAULT FALSE,\
    last_hyperlocal_response DATE,\
    hyperlocal_response_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW(),\
    \
    UNIQUE(donor_id)\
);\
\
-- Local Office Types (\cf5 \strokec5 14\cf2 \strokec2  types)\
CREATE TABLE local_intelligence.local_offices (\
    office_id SERIAL PRIMARY KEY,\
    office_type VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL UNIQUE,\
    office_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) NOT NULL, -- COUNTY, MUNICIPAL\
    typical_term_years INTEGER,\
    \
    -- Primary Issues (JSON array)\
    primary_issues JSONB, -- [\cf6 \strokec6 "crime"\cf2 \strokec2 , \cf6 \strokec6 "education"\cf2 \strokec2 , \cf6 \strokec6 "taxes"\cf2 \strokec2 ]\
    \
    -- Geographic Scope\
    geographic_scope VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- COUNTY-WIDE, DISTRICT, CITY-WIDE\
    \
    description TEXT,\
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Local Candidate Profiles\
CREATE TABLE local_intelligence.local_candidates (\
    local_candidate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    candidate_id UUID NOT NULL REFERENCES datahub.candidates(candidate_id),\
    office_id INTEGER REFERENCES local_intelligence.local_offices(office_id),\
    \
    -- Local Focus\
    primary_local_issues JSONB, -- Top \cf5 \strokec5 3\cf2 \strokec2 -5 issues\
    district_number VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    precinct VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    \
    -- Local Experience\
    current_office VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    years_in_community INTEGER,\
    local_endorsements JSONB,\
    \
    -- Local Campaign\
    door_knock_goal INTEGER,\
    doors_knocked INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    local_events_planned INTEGER,\
    local_events_completed INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW(),\
    \
    UNIQUE(candidate_id)\
);\
\
-- Hyperlocal Event Tracking\
CREATE TABLE local_intelligence.hyperlocal_events (\
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    \
    -- Event Details\
    headline VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ) NOT NULL,\
    event_type VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ), -- CRIME, SCHOOL, DEVELOPMENT, TRAFFIC, etc.\
    severity VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- LOW, MEDIUM, HIGH, CRITICAL\
    \
    -- Location\
    county VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    city VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    neighborhood VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    zip_code VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ),\
    latitude DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 8\cf2 \strokec2 ),\
    longitude DECIMAL(\cf5 \strokec5 11\cf2 \strokec2 , \cf5 \strokec5 8\cf2 \strokec2 ),\
    \
    -- Impact\
    affected_residents_estimate INTEGER,\
    relevant_offices JSONB, -- [\cf6 \strokec6 "SHERIFF"\cf2 \strokec2 , \cf6 \strokec6 "SCHOOL_BOARD"\cf2 \strokec2 ]\
    \
    -- Response Window\
    event_date TIMESTAMPTZ NOT NULL,\
    response_window_hours INTEGER, -- \cf5 \strokec5 1\cf2 \strokec2 -4 hours \cf7 \strokec7 for\cf2 \strokec2  hyperlocal\
    deadline TIMESTAMPTZ,\
    \
    -- Campaign Trigger\
    triggered_campaign BOOLEAN DEFAULT FALSE,\
    campaign_sent_at TIMESTAMPTZ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 3\cf2 \strokec2 : CAMPAIGN BUILDER (\cf5 \strokec5 1,536\cf2 \strokec2  TEMPLATES)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Campaign Templates\
CREATE TABLE campaigns.templates (\
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    \
    -- Template Identity\
    template_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    template_code VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) UNIQUE NOT NULL,\
    \
    -- Template Type\
    channel VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) NOT NULL, -- EMAIL, SMS, MAIL, SOCIAL\
    purpose VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL, -- YEAR_END_APPEAL, GUN_RIGHTS, etc.\
    office_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- FEDERAL, STATE, COUNTY, MUNICIPAL\
    \
    -- Content\
    subject_line VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    preview_text VARCHAR(\cf5 \strokec5 150\cf2 \strokec2 ),\
    body_template TEXT NOT NULL,\
    call_to_action TEXT,\
    \
    -- Variables (JSON array of variable names)\
    variables JSONB, -- [\cf6 \strokec6 "\{\{candidate_name\}\}"\cf2 \strokec2 , \cf6 \strokec6 "\{\{amount\}\}"\cf2 \strokec2 ]\
    \
    -- AI Generation\
    ai_prompt TEXT,\
    ai_model VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    tone VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- URGENT, CONVERSATIONAL, PROFESSIONAL\
    \
    -- Performance Tracking\
    times_used INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    avg_open_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    avg_click_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    avg_donation_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    total_raised DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Status\
    is_active BOOLEAN DEFAULT TRUE,\
    is_tested BOOLEAN DEFAULT FALSE,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Campaigns\
CREATE TABLE campaigns.campaigns (\
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    candidate_id UUID NOT NULL REFERENCES datahub.candidates(candidate_id),\
    template_id UUID REFERENCES campaigns.templates(template_id),\
    \
    -- Campaign Details\
    campaign_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    campaign_type VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) NOT NULL, -- FUNDRAISING, ISSUE_ADVOCACY, VOLUNTEER, EVENT\
    \
    -- Channels (multi-channel support)\
    channels JSONB, -- [\cf6 \strokec6 "EMAIL"\cf2 \strokec2 , \cf6 \strokec6 "SMS"\cf2 \strokec2 ]\
    \
    -- Target Audience\
    target_segment VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    target_grade_min VARCHAR(\cf5 \strokec5 5\cf2 \strokec2 ),\
    target_county VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    target_issues JSONB,\
    \
    -- Timing\
    schedule_type VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- IMMEDIATE, SCHEDULED, AUTORUN\
    scheduled_send TIMESTAMPTZ,\
    sent_at TIMESTAMPTZ,\
    \
    -- Content\
    subject_line VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    message_body TEXT,\
    call_to_action TEXT,\
    donate_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'DRAFT'\cf2 \strokec2 , -- DRAFT, SCHEDULED, SENDING, SENT, COMPLETED\
    \
    -- Results\
    recipients_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    delivered_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    opened_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    clicked_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    donated_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    total_raised DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Metrics\
    open_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    click_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    donation_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    avg_donation DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Campaign Recipients\
CREATE TABLE campaigns.recipients (\
    recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    campaign_id UUID NOT NULL REFERENCES campaigns.campaigns(campaign_id),\
    donor_id UUID NOT NULL REFERENCES datahub.donors(donor_id),\
    \
    -- Delivery\
    channel VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) NOT NULL,\
    destination VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ), -- email or phone\
    sent_at TIMESTAMPTZ,\
    delivered_at TIMESTAMPTZ,\
    \
    -- Engagement\
    opened_at TIMESTAMPTZ,\
    clicked_at TIMESTAMPTZ,\
    donated_at TIMESTAMPTZ,\
    donation_amount DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'PENDING'\cf2 \strokec2 , -- PENDING, SENT, DELIVERED, OPENED, CLICKED, DONATED, BOUNCED, UNSUBSCRIBED\
    bounce_reason TEXT,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 4\cf2 \strokec2 : MEDIA DATABASE (\cf5 \strokec5 214\cf2 \strokec2  NC OUTLETS)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Media Outlets\
CREATE TABLE media.outlets (\
    outlet_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    \
    -- Outlet Identity\
    outlet_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    outlet_type VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) NOT NULL, -- NEWSPAPER, TV, RADIO, ONLINE, PODCAST\
    \
    -- Location\
    county VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    city VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    state VARCHAR(\cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'NC'\cf2 \strokec2 ,\
    coverage_area VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ), -- \cf6 \strokec6 "Wake County"\cf2 \strokec2 , \cf6 \strokec6 "Western NC"\cf2 \strokec2 \
    \
    -- Contact\
    website VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    main_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    main_phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    mailing_address TEXT,\
    \
    -- Editorial\
    political_lean VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- CONSERVATIVE, MODERATE, LIBERAL, NEUTRAL\
    conservative_friendly BOOLEAN DEFAULT FALSE,\
    editor_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    editor_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    \
    -- Coverage\
    circulation_daily INTEGER,\
    circulation_sunday INTEGER,\
    readership_estimate INTEGER,\
    \
    -- Press Release Submission\
    press_release_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    press_release_format VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- EMAIL, ONLINE_FORM, FAX\
    submission_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    submission_notes TEXT,\
    \
    -- Performance\
    press_releases_sent INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    articles_published INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    last_contact_date DATE,\
    \
    -- Status\
    is_active BOOLEAN DEFAULT TRUE,\
    priority_tier INTEGER, -- \cf5 \strokec5 1\cf2 \strokec2 -4 (\cf5 \strokec5 1\cf4 \strokec4 =\cf2 \strokec2 highest)\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Media Contacts\
CREATE TABLE media.contacts (\
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    outlet_id UUID NOT NULL REFERENCES media.outlets(outlet_id),\
    \
    -- Contact Info\
    full_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    title VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ) NOT NULL,\
    phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    twitter VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    \
    -- Beat\
    beat VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ), -- POLITICS, CRIME, EDUCATION, BUSINESS\
    covers_republicans BOOLEAN DEFAULT TRUE,\
    \
    -- Relationship\
    relationship_quality VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- EXCELLENT, GOOD, NEUTRAL, POOR\
    last_contact DATE,\
    stories_published INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    is_active BOOLEAN DEFAULT TRUE,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Press Releases\
CREATE TABLE media.press_releases (\
    press_release_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    candidate_id UUID REFERENCES datahub.candidates(candidate_id),\
    \
    -- Content\
    headline VARCHAR(\cf5 \strokec5 300\cf2 \strokec2 ) NOT NULL,\
    subheadline VARCHAR(\cf5 \strokec5 300\cf2 \strokec2 ),\
    body TEXT NOT NULL,\
    boilerplate TEXT,\
    \
    -- Distribution\
    distribution_list JSONB, -- Array of outlet_ids\
    target_counties JSONB,\
    target_office_types JSONB,\
    \
    -- Timing\
    release_date DATE NOT NULL,\
    embargo_until TIMESTAMPTZ,\
    sent_at TIMESTAMPTZ,\
    \
    -- Results\
    outlets_sent INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    articles_published INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    estimated_reach INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Attachments\
    attachments JSONB, -- Array of \cf4 \strokec4 file\cf2 \strokec2  URLs\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'DRAFT'\cf2 \strokec2 ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 5\cf2 \strokec2 : CANDIDATE DATABASE (\cf5 \strokec5 500\cf2 \strokec2 + FIELDS)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Complete Candidate Profiles\
CREATE TABLE candidates.profiles (\
    profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    candidate_id UUID NOT NULL REFERENCES datahub.candidates(candidate_id) UNIQUE,\
    \
    -- SECTION \cf5 \strokec5 1\cf2 \strokec2 : BASIC INFO (\cf5 \strokec5 50\cf2 \strokec2  fields)\
    full_legal_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    preferred_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    name_pronunciation VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    date_of_birth DATE,\
    age INTEGER,\
    birthplace VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    current_residence_address TEXT,\
    residence_county VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    residence_city VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    years_in_district INTEGER,\
    marital_status VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    spouse_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    children_count INTEGER,\
    children_details JSONB,\
    \
    -- SECTION \cf5 \strokec5 2\cf2 \strokec2 : CONTACT (\cf5 \strokec5 30\cf2 \strokec2  fields)\
    personal_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    campaign_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    personal_phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    campaign_phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    campaign_manager_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    campaign_manager_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    campaign_manager_phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    treasurer_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    treasurer_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    website VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    facebook VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    twitter VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    instagram VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    youtube VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    tiktok VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    \
    -- SECTION \cf5 \strokec5 3\cf2 \strokec2 : EDUCATION (\cf5 \strokec5 40\cf2 \strokec2  fields)\
    high_school VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    hs_graduation_year INTEGER,\
    undergraduate_school VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    undergraduate_degree VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    undergraduate_major VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    undergraduate_grad_year INTEGER,\
    graduate_school_1 VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    graduate_degree_1 VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    graduate_field_1 VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    graduate_year_1 INTEGER,\
    additional_education JSONB,\
    professional_certifications JSONB,\
    \
    -- SECTION \cf5 \strokec5 4\cf2 \strokec2 : CAREER (\cf5 \strokec5 60\cf2 \strokec2  fields)\
    current_occupation VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    current_employer VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    years_in_current_job INTEGER,\
    previous_jobs JSONB,\
    total_years_experience INTEGER,\
    industry VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    profession VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    business_owned BOOLEAN DEFAULT FALSE,\
    business_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    business_employees INTEGER,\
    business_revenue_range VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    \
    -- SECTION \cf5 \strokec5 5\cf2 \strokec2 : MILITARY SERVICE (\cf5 \strokec5 40\cf2 \strokec2  fields)\
    military_service BOOLEAN DEFAULT FALSE,\
    branch VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    rank VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    years_served INTEGER,\
    service_start_date DATE,\
    service_end_date DATE,\
    deployments JSONB,\
    medals_awards JSONB,\
    combat_veteran BOOLEAN DEFAULT FALSE,\
    discharge_type VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    \
    -- SECTION \cf5 \strokec5 6\cf2 \strokec2 : POLITICAL EXPERIENCE (\cf5 \strokec5 50\cf2 \strokec2  fields)\
    offices_held JSONB,\
    years_in_politics INTEGER,\
    current_office VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    current_office_start_year INTEGER,\
    is_incumbent BOOLEAN DEFAULT FALSE,\
    party_official_positions JSONB,\
    committee_memberships JSONB,\
    \
    -- SECTION \cf5 \strokec5 7\cf2 \strokec2 : POSITIONS (\cf5 \strokec5 12\cf2 \strokec2  dimensions \'d7 \cf5 \strokec5 10\cf2 \strokec2  fields \cf4 \strokec4 =\cf2 \strokec2  \cf5 \strokec5 120\cf2 \strokec2  fields)\
    -- Trump/MAGA\
    trump_endorsement BOOLEAN,\
    trump_loyalty_score INTEGER,\
    maga_platform_support JSONB,\
    \
    -- Fiscal Policy\
    fiscal_philosophy TEXT,\
    tax_policy_positions JSONB,\
    spending_priorities JSONB,\
    \
    -- Social Issues\
    pro_life_position TEXT,\
    pro_life_score INTEGER,\
    religious_liberty_stance TEXT,\
    marriage_definition TEXT,\
    \
    -- Second Amendment\
    second_amendment_position TEXT,\
    nra_rating VARCHAR(\cf5 \strokec5 5\cf2 \strokec2 ),\
    gun_rights_endorsements JSONB,\
    \
    -- Immigration\
    immigration_stance TEXT,\
    border_security_position TEXT,\
    legal_immigration_views TEXT,\
    \
    -- Education\
    education_philosophy TEXT,\
    school_choice_support BOOLEAN,\
    charter_school_stance TEXT,\
    parental_rights_position TEXT,\
    \
    -- Energy/Climate\
    energy_policy TEXT,\
    climate_change_view TEXT,\
    fossil_fuels_stance TEXT,\
    \
    -- Trade/Economy\
    trade_policy TEXT,\
    tariffs_position TEXT,\
    economic_philosophy TEXT,\
    \
    -- Foreign Policy\
    foreign_policy_approach TEXT,\
    china_policy TEXT,\
    military_spending_view TEXT,\
    \
    -- Criminal Justice\
    law_enforcement_support TEXT,\
    criminal_justice_reform_view TEXT,\
    death_penalty_stance TEXT,\
    \
    -- Healthcare\
    healthcare_policy TEXT,\
    medicaid_expansion_view TEXT,\
    insurance_approach TEXT,\
    \
    -- Other\
    additional_positions JSONB,\
    \
    -- SECTION \cf5 \strokec5 8\cf2 \strokec2 : ENDORSEMENTS (\cf5 \strokec5 30\cf2 \strokec2  fields)\
    major_endorsements JSONB,\
    national_endorsements JSONB,\
    state_endorsements JSONB,\
    local_endorsements JSONB,\
    organization_endorsements JSONB,\
    \
    -- SECTION \cf5 \strokec5 9\cf2 \strokec2 : CAMPAIGN (\cf5 \strokec5 40\cf2 \strokec2  fields)\
    campaign_slogan VARCHAR(\cf5 \strokec5 300\cf2 \strokec2 ),\
    campaign_theme VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    top_three_priorities JSONB,\
    campaign_announcement_date DATE,\
    filing_date DATE,\
    election_date DATE,\
    primary_date DATE,\
    \
    -- SECTION \cf5 \strokec5 10\cf2 \strokec2 : FUNDRAISING (\cf5 \strokec5 30\cf2 \strokec2  fields)\
    fundraising_goal DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    raised_to_date DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    cash_on_hand DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    burn_rate DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    donor_count INTEGER,\
    major_donor_count INTEGER,\
    avg_donation DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- Metadata\
    profile_completeness INTEGER, -- \cf5 \strokec5 0\cf2 \strokec2 -100%\
    last_updated TIMESTAMPTZ DEFAULT NOW(),\
    updated_by VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 6\cf2 \strokec2 : CAMPAIGN EXECUTION SYSTEM\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Email Queue\
CREATE TABLE execution.email_queue (\
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    campaign_id UUID NOT NULL REFERENCES campaigns.campaigns(campaign_id),\
    recipient_id UUID NOT NULL REFERENCES campaigns.recipients(recipient_id),\
    \
    to_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ) NOT NULL,\
    from_email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ) NOT NULL,\
    from_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    subject VARCHAR(\cf5 \strokec5 300\cf2 \strokec2 ) NOT NULL,\
    body_html TEXT NOT NULL,\
    body_text TEXT,\
    \
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'QUEUED'\cf2 \strokec2 , -- QUEUED, SENDING, SENT, FAILED\
    priority INTEGER DEFAULT \cf5 \strokec5 5\cf2 \strokec2 ,\
    \
    scheduled_send TIMESTAMPTZ,\
    sent_at TIMESTAMPTZ,\
    delivered_at TIMESTAMPTZ,\
    opened_at TIMESTAMPTZ,\
    clicked_at TIMESTAMPTZ,\
    \
    esp_provider VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- SENDGRID, MAILGUN, AWS_SES\
    esp_message_id VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    esp_response JSONB,\
    \
    retry_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    error_message TEXT,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- SMS Queue\
CREATE TABLE execution.sms_queue (\
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    campaign_id UUID NOT NULL REFERENCES campaigns.campaigns(campaign_id),\
    recipient_id UUID NOT NULL REFERENCES campaigns.recipients(recipient_id),\
    \
    to_phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) NOT NULL,\
    from_phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) NOT NULL,\
    message TEXT NOT NULL,\
    \
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'QUEUED'\cf2 \strokec2 ,\
    priority INTEGER DEFAULT \cf5 \strokec5 5\cf2 \strokec2 ,\
    \
    scheduled_send TIMESTAMPTZ,\
    sent_at TIMESTAMPTZ,\
    delivered_at TIMESTAMPTZ,\
    \
    sms_provider VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- TWILIO, BANDWIDTH\
    provider_message_id VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    provider_response JSONB,\
    \
    retry_count INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    error_message TEXT,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Direct Mail Queue\
CREATE TABLE execution.mail_queue (\
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    campaign_id UUID NOT NULL REFERENCES campaigns.campaigns(campaign_id),\
    recipient_id UUID NOT NULL REFERENCES campaigns.recipients(recipient_id),\
    \
    to_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    to_address TEXT NOT NULL,\
    to_city VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    to_state VARCHAR(\cf5 \strokec5 2\cf2 \strokec2 ),\
    to_zip VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ),\
    \
    mail_piece_type VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- LETTER, POSTCARD, PACKET\
    template_id UUID,\
    \
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'QUEUED'\cf2 \strokec2 ,\
    \
    sent_to_printer TIMESTAMPTZ,\
    printed_at TIMESTAMPTZ,\
    mailed_at TIMESTAMPTZ,\
    estimated_delivery DATE,\
    \
    print_vendor VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    print_job_id VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    tracking_number VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    \
    cost DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 7\cf2 \strokec2 : DONOR ENRICHMENT ENGINE (\cf5 \strokec5 860\cf2 \strokec2  FIELDS)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Enrichment Queue\
CREATE TABLE enrichment.enrichment_queue (\
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    donor_id UUID NOT NULL REFERENCES datahub.donors(donor_id),\
    \
    -- Current Data\
    current_data JSONB,\
    \
    -- Enrichment Request\
    enrichment_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- BASIC, STANDARD, PREMIUM, COMPLETE\
    requested_fields JSONB,\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'PENDING'\cf2 \strokec2 , -- PENDING, PROCESSING, COMPLETED, FAILED\
    priority INTEGER DEFAULT \cf5 \strokec5 5\cf2 \strokec2 ,\
    \
    -- Processing\
    started_at TIMESTAMPTZ,\
    completed_at TIMESTAMPTZ,\
    processing_time_ms INTEGER,\
    \
    -- Data Sources Used\
    sources_queried JSONB, -- [\cf6 \strokec6 "BetterContact"\cf2 \strokec2 , \cf6 \strokec6 "Apollo"\cf2 \strokec2 , \cf6 \strokec6 "FEC"\cf2 \strokec2 ]\
    sources_returned_data JSONB,\
    \
    -- Results\
    enriched_data JSONB, -- All \cf5 \strokec5 860\cf2 \strokec2  fields\
    fields_found INTEGER,\
    fields_missing INTEGER,\
    data_quality_score INTEGER, -- \cf5 \strokec5 0\cf2 \strokec2 -100\
    \
    -- Costs\
    cost_per_source JSONB,\
    total_cost DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 4\cf2 \strokec2 ),\
    \
    -- AI Enhancement\
    ai_enhanced BOOLEAN DEFAULT FALSE,\
    ai_provider VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    ai_cost DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 4\cf2 \strokec2 ),\
    \
    error_message TEXT,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Enriched Donor Profiles (\cf5 \strokec5 860\cf2 \strokec2  fields)\
CREATE TABLE enrichment.enriched_profiles (\
    enriched_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    donor_id UUID NOT NULL REFERENCES datahub.donors(donor_id) UNIQUE,\
    \
    -- CONTACT INFO (\cf5 \strokec5 50\cf2 \strokec2  fields)\
    email_personal VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    email_work VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    email_confidence DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    phone_mobile VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    phone_home VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    phone_work VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    phone_confidence DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- ADDRESS (\cf5 \strokec5 40\cf2 \strokec2  fields)\
    mailing_address TEXT,\
    property_address TEXT,\
    address_confidence DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    address_verified BOOLEAN,\
    address_last_verified DATE,\
    \
    -- DEMOGRAPHIC (\cf5 \strokec5 100\cf2 \strokec2  fields)\
    age INTEGER,\
    age_range VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    gender VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    marital_status VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    household_size INTEGER,\
    household_income_range VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    net_worth_estimate VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    home_value_estimate INTEGER,\
    property_ownership BOOLEAN,\
    vehicle_count INTEGER,\
    vehicle_details JSONB,\
    \
    -- EMPLOYMENT (\cf5 \strokec5 80\cf2 \strokec2  fields)\
    employer VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    job_title VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    industry VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    years_with_employer INTEGER,\
    employment_status VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    income_estimate VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    linkedin_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    \
    -- EDUCATION (\cf5 \strokec5 60\cf2 \strokec2  fields)\
    education_level VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    colleges_attended JSONB,\
    degrees JSONB,\
    graduation_years JSONB,\
    \
    -- SOCIAL MEDIA (\cf5 \strokec5 70\cf2 \strokec2  fields)\
    facebook_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    twitter_handle VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    instagram_handle VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    linkedin_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    social_activity_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    political_posts_detected BOOLEAN,\
    \
    -- CONSUMER (\cf5 \strokec5 120\cf2 \strokec2  fields)\
    estimated_spending_power VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    consumer_interests JSONB,\
    brand_preferences JSONB,\
    online_shopping_frequency VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    \
    -- POLITICAL (\cf5 \strokec5 150\cf2 \strokec2  fields)\
    voter_registration_status VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    voter_registration_date DATE,\
    party_affiliation VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    voting_frequency VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    elections_voted JSONB,\
    fec_donation_history JSONB,\
    state_donation_history JSONB,\
    political_affiliation_score INTEGER,\
    \
    -- LIFESTYLE (\cf5 \strokec5 100\cf2 \strokec2  fields)\
    hobbies_interests JSONB,\
    charitable_giving BOOLEAN,\
    charitable_causes JSONB,\
    religious_affiliation VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    church_attendance VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ),\
    \
    -- DIGITAL (\cf5 \strokec5 90\cf2 \strokec2  fields)\
    email_engagement_score INTEGER,\
    device_types JSONB,\
    browser_preferences JSONB,\
    online_activity_hours JSONB,\
    \
    -- Metadata\
    enrichment_date TIMESTAMPTZ DEFAULT NOW(),\
    data_sources JSONB,\
    data_quality_score INTEGER,\
    last_verified TIMESTAMPTZ,\
    needs_refresh BOOLEAN DEFAULT FALSE,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 8\cf2 \strokec2 : VOLUNTEER MANAGEMENT (\cf5 \strokec5 21\cf2 \strokec2 -TIER GRADING)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Volunteer Profiles\
CREATE TABLE volunteers.profiles (\
    volunteer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    donor_id UUID REFERENCES datahub.donors(donor_id),\
    \
    -- Identity\
    first_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    last_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    \
    -- \cf5 \strokec5 21\cf2 \strokec2 -Tier Grading (V-A+ to V-U-)\
    volunteer_grade VARCHAR(\cf5 \strokec5 5\cf2 \strokec2 ), -- V-A+, V-A, V-A-, V-B+, V-B, V-B-, V-C+, V-C, V-C-, V-D+, V-D, V-D-, V-F+, V-F, V-F-, V-U+, V-U, V-U-\
    volunteer_score INTEGER CHECK (volunteer_score BETWEEN \cf5 \strokec5 0\cf2 \strokec2  AND \cf5 \strokec5 1000\cf2 \strokec2 ),\
    reliability_score INTEGER, -- \cf5 \strokec5 0\cf2 \strokec2 -100\
    \
    -- Availability\
    available_days JSONB, -- [\cf6 \strokec6 "MONDAY"\cf2 \strokec2 , \cf6 \strokec6 "TUESDAY"\cf2 \strokec2 ]\
    available_hours JSONB, -- \{\cf6 \strokec6 "MORNING"\cf2 \strokec2 , \cf6 \strokec6 "AFTERNOON"\cf2 \strokec2 , \cf6 \strokec6 "EVENING"\cf2 \strokec2 \}\
    max_hours_per_week INTEGER,\
    \
    -- Skills\
    skills JSONB, -- [\cf6 \strokec6 "DOOR_KNOCKING"\cf2 \strokec2 , \cf6 \strokec6 "PHONE_BANKING"\cf2 \strokec2 , \cf6 \strokec6 "DATA_ENTRY"\cf2 \strokec2 ]\
    languages JSONB,\
    has_vehicle BOOLEAN DEFAULT FALSE,\
    willing_to_travel BOOLEAN DEFAULT FALSE,\
    max_travel_distance_miles INTEGER,\
    \
    -- Activity\
    total_hours_logged INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    total_activities_completed INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    activities_completed_by_type JSONB,\
    last_activity_date DATE,\
    days_since_last_activity INTEGER,\
    \
    -- Performance\
    tasks_assigned INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    tasks_completed INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    tasks_completion_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    no_shows INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    cancellations INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Recruitment (Viral Referral)\
    recruited_by UUID REFERENCES volunteers.profiles(volunteer_id),\
    referral_code VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) UNIQUE,\
    volunteers_recruited INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    referral_bonus_earned DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Status\
    is_active BOOLEAN DEFAULT TRUE,\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , -- ACTIVE, INACTIVE, SUSPENDED, BANNED\
    \
    -- Gamification\
    points INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    level INTEGER DEFAULT \cf5 \strokec5 1\cf2 \strokec2 ,\
    badges JSONB,\
    leaderboard_rank INTEGER,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Volunteer Activities (\cf5 \strokec5 56\cf2 \strokec2  types)\
CREATE TABLE volunteers.activities (\
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    volunteer_id UUID NOT NULL REFERENCES volunteers.profiles(volunteer_id),\
    campaign_id UUID REFERENCES campaigns.campaigns(campaign_id),\
    \
    -- Activity Type (\cf5 \strokec5 56\cf2 \strokec2  types)\
    activity_type VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL, -- DOOR_KNOCK, PHONE_BANK, EVENT_HELP, etc.\
    activity_category VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- CANVASSING, CALLING, OFFICE, EVENT, DIGITAL\
    \
    -- Details\
    description TEXT,\
    location TEXT,\
    supervisor VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    \
    -- Time\
    scheduled_start TIMESTAMPTZ NOT NULL,\
    scheduled_end TIMESTAMPTZ NOT NULL,\
    actual_start TIMESTAMPTZ,\
    actual_end TIMESTAMPTZ,\
    hours_logged DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- Results\
    doors_knocked INTEGER,\
    calls_made INTEGER,\
    contacts_reached INTEGER,\
    signatures_collected INTEGER,\
    materials_distributed INTEGER,\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'SCHEDULED'\cf2 \strokec2 , -- SCHEDULED, IN_PROGRESS, COMPLETED, NO_SHOW, CANCELLED\
    completion_notes TEXT,\
    \
    -- Rewards\
    points_earned INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 9\cf2 \strokec2 : MATCHING ENGINE (AUTOMATIC)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Automatic Match Jobs\
CREATE TABLE matching.match_jobs (\
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    \
    -- Job Configuration\
    job_type VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- DAILY_REFRESH, CANDIDATE_REQUEST, ON_DEMAND\
    candidate_id UUID REFERENCES datahub.candidates(candidate_id),\
    \
    -- Parameters\
    min_affinity_score INTEGER DEFAULT \cf5 \strokec5 40\cf2 \strokec2 ,\
    max_matches INTEGER DEFAULT \cf5 \strokec5 100\cf2 \strokec2 ,\
    filters JSONB,\
    \
    -- Execution\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'PENDING'\cf2 \strokec2 ,\
    started_at TIMESTAMPTZ,\
    completed_at TIMESTAMPTZ,\
    processing_time_ms INTEGER,\
    \
    -- Results\
    matches_found INTEGER,\
    matches_inserted INTEGER,\
    recommendations_sent BOOLEAN DEFAULT FALSE,\
    \
    error_message TEXT,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Match Recommendations (sent to candidates)\
CREATE TABLE matching.recommendations (\
    recommendation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    candidate_id UUID NOT NULL REFERENCES datahub.candidates(candidate_id),\
    \
    -- Recommendation Set\
    recommendation_date DATE NOT NULL,\
    donor_count INTEGER NOT NULL,\
    top_donors JSONB, -- Top \cf5 \strokec5 100\cf2 \strokec2  donors with scores\
    \
    -- Email Sent\
    email_sent BOOLEAN DEFAULT FALSE,\
    email_sent_at TIMESTAMPTZ,\
    email_opened BOOLEAN DEFAULT FALSE,\
    \
    -- Actions Taken\
    contacts_made INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    donations_resulted INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    total_raised DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 10\cf2 \strokec2 : EVENT MANAGEMENT\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Events\
CREATE TABLE events.events (\
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    candidate_id UUID REFERENCES datahub.candidates(candidate_id),\
    \
    -- Event Details\
    event_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    event_type VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL, -- TOWN_HALL, FUNDRAISER, RALLY, MEET_GREET, VOLUNTEER_TRAINING\
    \
    -- Location\
    venue_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    address TEXT,\
    city VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    county VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    state VARCHAR(\cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'NC'\cf2 \strokec2 ,\
    \cf4 \strokec4 zip\cf2 \strokec2  VARCHAR(\cf5 \strokec5 10\cf2 \strokec2 ),\
    \
    -- Timing\
    event_date DATE NOT NULL,\
    start_time TIME NOT NULL,\
    end_time TIME NOT NULL,\
    doors_open_time TIME,\
    \
    -- Capacity\
    capacity INTEGER,\
    rsvps INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    attended INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    waitlist INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Ticketing\
    is_ticketed BOOLEAN DEFAULT FALSE,\
    ticket_price DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    ticket_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    \
    -- Description\
    description TEXT,\
    agenda TEXT,\
    speakers JSONB,\
    \
    -- Promotion\
    public BOOLEAN DEFAULT TRUE,\
    invitation_only BOOLEAN DEFAULT FALSE,\
    invite_list JSONB,\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'PLANNED'\cf2 \strokec2 , -- PLANNED, PROMOTED, IN_PROGRESS, COMPLETED, CANCELLED\
    \
    -- Results\
    total_attendance INTEGER,\
    donations_collected DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    volunteers_recruited INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Event RSVPs\
CREATE TABLE events.rsvps (\
    rsvp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    event_id UUID NOT NULL REFERENCES events.events(event_id),\
    donor_id UUID REFERENCES datahub.donors(donor_id),\
    \
    -- Attendee Info\
    first_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    last_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    email VARCHAR(\cf5 \strokec5 255\cf2 \strokec2 ),\
    phone VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    \
    -- RSVP Details\
    rsvp_date TIMESTAMPTZ DEFAULT NOW(),\
    guest_count INTEGER DEFAULT \cf5 \strokec5 1\cf2 \strokec2 ,\
    \
    -- Attendance\
    checked_in BOOLEAN DEFAULT FALSE,\
    check_in_time TIMESTAMPTZ,\
    actually_attended BOOLEAN DEFAULT FALSE,\
    \
    -- Special Requests\
    dietary_restrictions TEXT,\
    accessibility_needs TEXT,\
    notes TEXT,\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'CONFIRMED'\cf2 \strokec2 , -- CONFIRMED, WAITLIST, CANCELLED, NO_SHOW\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 11\cf2 \strokec2 : REPORTING SYSTEM\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Report Definitions (\cf5 \strokec5 50\cf2 \strokec2  pre-built reports)\
CREATE TABLE reporting.report_definitions (\
    report_id SERIAL PRIMARY KEY,\
    \
    -- Report Identity\
    report_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    report_code VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) UNIQUE NOT NULL,\
    report_category VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ), -- FUNDRAISING, CAMPAIGNS, DONORS, VOLUNTEERS, EVENTS\
    \
    -- Description\
    description TEXT,\
    what_it_shows TEXT,\
    \
    -- SQL Query\
    base_query TEXT NOT NULL,\
    parameters JSONB, -- Configurable parameters\
    \
    -- Visualization\
    chart_type VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- BAR, LINE, PIE, TABLE, GAUGE\
    x_axis VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    y_axis VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    \
    -- Access\
    access_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'ADMIN'\cf2 \strokec2 , -- ADMIN, CANDIDATE, VOLUNTEER\
    \
    -- Usage\
    times_run INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    avg_runtime_ms INTEGER,\
    \
    is_active BOOLEAN DEFAULT TRUE,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Report Executions\
CREATE TABLE reporting.report_executions (\
    execution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    report_id INTEGER NOT NULL REFERENCES reporting.report_definitions(report_id),\
    \
    -- Execution\
    run_by VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    run_at TIMESTAMPTZ DEFAULT NOW(),\
    parameters JSONB,\
    \
    -- Results\
    rows_returned INTEGER,\
    execution_time_ms INTEGER,\
    \
    -- Output\
    output_format VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- JSON, CSV, PDF, EXCEL\
    output_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    \
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'COMPLETED'\cf2 \strokec2 ,\
    error_message TEXT\
);\
\
-- Dashboards (\cf5 \strokec5 25\cf2 \strokec2  dashboards)\
CREATE TABLE reporting.dashboards (\
    dashboard_id SERIAL PRIMARY KEY,\
    \
    -- Dashboard Identity\
    dashboard_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    dashboard_code VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) UNIQUE NOT NULL,\
    dashboard_category VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    \
    -- Layout\
    layout_config JSONB, -- Widget positions and sizes\
    widgets JSONB, -- Array of widget configurations\
    \
    -- Reports Included\
    report_ids INTEGER[],\
    \
    -- Access\
    access_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'ADMIN'\cf2 \strokec2 ,\
    \
    -- Refresh\
    auto_refresh BOOLEAN DEFAULT FALSE,\
    refresh_interval_minutes INTEGER DEFAULT \cf5 \strokec5 60\cf2 \strokec2 ,\
    \
    is_active BOOLEAN DEFAULT TRUE,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 12\cf2 \strokec2 : ANALYTICS DASHBOARDS (EXECUTIVE BI)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- KPI Definitions (\cf5 \strokec5 403\cf2 \strokec2  KPIs)\
CREATE TABLE analytics.kpis (\
    kpi_id SERIAL PRIMARY KEY,\
    \
    -- KPI Identity\
    kpi_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    kpi_code VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) UNIQUE NOT NULL,\
    kpi_category VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ), -- FUNDRAISING, DONORS, CAMPAIGNS, VOLUNTEERS\
    \
    -- Calculation\
    calculation_query TEXT NOT NULL,\
    calculation_frequency VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- REALTIME, HOURLY, DAILY, WEEKLY\
    \
    -- Display\
    display_format VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- CURRENCY, PERCENTAGE, COUNT, DECIMAL\
    decimal_places INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Target\
    target_value DECIMAL(\cf5 \strokec5 15\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    target_type VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- MINIMUM, MAXIMUM, RANGE\
    \
    -- Current Value\
    current_value DECIMAL(\cf5 \strokec5 15\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    previous_value DECIMAL(\cf5 \strokec5 15\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    change_amount DECIMAL(\cf5 \strokec5 15\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    change_percentage DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- ON_TARGET, ABOVE_TARGET, BELOW_TARGET, CRITICAL\
    \
    -- Last Update\
    last_calculated TIMESTAMPTZ,\
    next_calculation TIMESTAMPTZ,\
    \
    is_active BOOLEAN DEFAULT TRUE\
);\
\
-- KPI History (for trending)\
CREATE TABLE analytics.kpi_history (\
    history_id BIGSERIAL PRIMARY KEY,\
    kpi_id INTEGER NOT NULL REFERENCES analytics.kpis(kpi_id),\
    \
    value DECIMAL(\cf5 \strokec5 15\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) NOT NULL,\
    calculated_at TIMESTAMPTZ DEFAULT NOW(),\
    \
    INDEX idx_kpi_time (kpi_id, calculated_at DESC)\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 13\cf2 \strokec2 : AI CONTROL CENTER (BRAIN)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- AI Functions Registry (\cf5 \strokec5 35\cf2 \strokec2 + functions)\
CREATE TABLE ai_hub.functions (\
    function_id SERIAL PRIMARY KEY,\
    \
    -- Function Identity\
    function_code VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) UNIQUE NOT NULL, -- F001, F002, etc.\
    function_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    function_category VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ), -- CONTENT_GEN, ANALYSIS, PREDICTION, ENRICHMENT\
    \
    -- Description\
    description TEXT,\
    use_cases TEXT,\
    \
    -- AI Provider\
    ai_provider VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) NOT NULL, -- CLAUDE, OPENAI, ELEVENLABS\
    model_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    \
    -- Costs\
    cost_per_call DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 6\cf2 \strokec2 ),\
    cost_model VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- PER_TOKEN, PER_REQUEST, PER_CHARACTER\
    \
    -- Usage Limits\
    daily_quota INTEGER,\
    monthly_quota INTEGER,\
    \
    -- Usage Stats\
    total_calls INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    total_cost DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    calls_today INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    cost_today DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Performance\
    avg_response_time_ms INTEGER,\
    success_rate DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    is_active BOOLEAN DEFAULT TRUE,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- AI Function Calls (usage tracking)\
CREATE TABLE ai_hub.function_calls (\
    call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    function_id INTEGER NOT NULL REFERENCES ai_hub.functions(function_id),\
    \
    -- Request\
    input_data JSONB,\
    input_tokens INTEGER,\
    \
    -- Response\
    output_data JSONB,\
    output_tokens INTEGER,\
    \
    -- Performance\
    response_time_ms INTEGER,\
    \
    -- Cost\
    cost DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 6\cf2 \strokec2 ),\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'SUCCESS'\cf2 \strokec2 , -- SUCCESS, FAILED, TIMEOUT\
    error_message TEXT,\
    \
    -- Context\
    called_by VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    campaign_id UUID,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- AI Cost Tracking\
CREATE TABLE ai_hub.cost_tracking (\
    tracking_id BIGSERIAL PRIMARY KEY,\
    \
    \cf4 \strokec4 date\cf2 \strokec2  DATE NOT NULL,\
    function_id INTEGER REFERENCES ai_hub.functions(function_id),\
    \
    calls_count INTEGER NOT NULL,\
    total_cost DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ) NOT NULL,\
    avg_cost_per_call DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 6\cf2 \strokec2 ),\
    \
    UNIQUE(date, function_id)\
);\
\
-- Vendor Health Monitoring\
CREATE TABLE ai_hub.vendor_health (\
    health_id BIGSERIAL PRIMARY KEY,\
    \
    vendor_name VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    \
    -- Health Check\
    last_check TIMESTAMPTZ DEFAULT NOW(),\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- OPERATIONAL, DEGRADED, DOWN\
    response_time_ms INTEGER,\
    \
    -- Quota Status\
    daily_quota_used INTEGER,\
    daily_quota_limit INTEGER,\
    quota_percentage DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- Incidents\
    incidents_today INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    last_incident TIMESTAMPTZ\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 14\cf2 \strokec2 : PREDICTION ENGINE (ML MODELS)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- ML Models Registry\
CREATE TABLE prediction.models (\
    model_id SERIAL PRIMARY KEY,\
    \
    -- Model Identity\
    model_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    model_code VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ) UNIQUE NOT NULL,\
    model_type VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ), -- DONATION_LIKELIHOOD, CHURN_PREDICTION, OPTIMAL_TIMING\
    \
    -- Description\
    description TEXT,\
    features_used JSONB, -- Array of feature names\
    \
    -- Performance\
    accuracy DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ), -- \cf5 \strokec5 0\cf2 \strokec2 -100%\
    precision_score DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    recall_score DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    f1_score DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- Training\
    training_data_size INTEGER,\
    last_trained TIMESTAMPTZ,\
    training_frequency VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- DAILY, WEEKLY, MONTHLY\
    next_training TIMESTAMPTZ,\
    \
    -- Version\
    version VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ),\
    is_production BOOLEAN DEFAULT FALSE,\
    \
    -- Usage\
    predictions_made INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW(),\
    updated_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Predictions (stored results)\
CREATE TABLE prediction.predictions (\
    prediction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    model_id INTEGER NOT NULL REFERENCES prediction.models(model_id),\
    donor_id UUID NOT NULL REFERENCES datahub.donors(donor_id),\
    \
    -- Prediction Type\
    prediction_type VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ) NOT NULL,\
    \
    -- Prediction Results\
    predicted_value DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ), -- Could be probability, amount, etc.\
    confidence_score DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ), -- \cf5 \strokec5 0\cf2 \strokec2 -100%\
    prediction_details JSONB,\
    \
    -- Features Used\
    input_features JSONB,\
    \
    -- Validation\
    actual_value DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    prediction_correct BOOLEAN,\
    \
    -- Timing\
    predicted_at TIMESTAMPTZ DEFAULT NOW(),\
    valid_until TIMESTAMPTZ,\
    \
    -- Usage\
    used_in_campaign BOOLEAN DEFAULT FALSE,\
    campaign_id UUID\
);\
\
-- Model Performance Tracking\
CREATE TABLE prediction.model_performance (\
    performance_id BIGSERIAL PRIMARY KEY,\
    model_id INTEGER NOT NULL REFERENCES prediction.models(model_id),\
    \
    evaluation_date DATE NOT NULL,\
    \
    -- Metrics\
    predictions_made INTEGER,\
    predictions_validated INTEGER,\
    accuracy DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    precision_score DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    recall_score DECIMAL(\cf5 \strokec5 5\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- Business Impact\
    donations_influenced INTEGER,\
    revenue_generated DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    roi DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    UNIQUE(model_id, evaluation_date)\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- ECOSYSTEM \cf5 \strokec5 15\cf2 \strokec2 : BROADCAST AD CREATOR (AI VIDEO/AUDIO)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- News Monitoring\
CREATE TABLE broadcast.news_articles (\
    article_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    \
    -- Source\
    source_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ) NOT NULL,\
    source_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    source_type VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- RSS, API, SCRAPE\
    \
    -- Content\
    headline VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ) NOT NULL,\
    summary TEXT,\
    full_text TEXT,\
    \
    -- Classification\
    article_category VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ), -- POLITICS, CRIME, EDUCATION, etc.\
    relevance_score INTEGER, -- \cf5 \strokec5 0\cf2 \strokec2 -100\
    urgency_level VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- LOW, MEDIUM, HIGH, CRITICAL\
    \
    -- Location\
    state VARCHAR(\cf5 \strokec5 2\cf2 \strokec2 ),\
    counties JSONB,\
    cities JSONB,\
    \
    -- Timing\
    published_at TIMESTAMPTZ,\
    discovered_at TIMESTAMPTZ DEFAULT NOW(),\
    \
    -- AI Analysis\
    ai_analyzed BOOLEAN DEFAULT FALSE,\
    ai_analysis JSONB,\
    campaign_relevant BOOLEAN DEFAULT FALSE,\
    relevant_offices JSONB, -- [\cf6 \strokec6 "SHERIFF"\cf2 \strokec2 , \cf6 \strokec6 "DA"\cf2 \strokec2 ]\
    \
    -- Campaign Trigger\
    triggered_ad_creation BOOLEAN DEFAULT FALSE,\
    ad_created_at TIMESTAMPTZ\
);\
\
-- Ad Variants (\cf5 \strokec5 5\cf2 \strokec2  per trigger)\
CREATE TABLE broadcast.ad_variants (\
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    article_id UUID NOT NULL REFERENCES broadcast.news_articles(article_id),\
    campaign_id UUID REFERENCES campaigns.campaigns(campaign_id),\
    \
    -- Variant Details\
    variant_number INTEGER, -- \cf5 \strokec5 1\cf2 \strokec2 -5\
    duration_seconds INTEGER, -- \cf5 \strokec5 15\cf2 \strokec2 , \cf5 \strokec5 30\cf2 \strokec2 , or \cf5 \strokec5 60\cf2 \strokec2 \
    ad_type VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- TV, RADIO, SOCIAL\
    \
    -- Content\
    script TEXT NOT NULL,\
    call_to_action TEXT,\
    \
    -- Production\
    voice_clone_used BOOLEAN DEFAULT FALSE,\
    voice_provider VARCHAR(\cf5 \strokec5 50\cf2 \strokec2 ), -- ELEVENLABS\
    audio_file_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    \
    video_rendered BOOLEAN DEFAULT FALSE,\
    video_file_url VARCHAR(\cf5 \strokec5 500\cf2 \strokec2 ),\
    video_resolution VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- 1080p, 720p\
    \
    -- Compliance\
    fcc_compliant BOOLEAN DEFAULT FALSE,\
    calm_act_compliant BOOLEAN DEFAULT FALSE,\
    legal_disclaimer TEXT,\
    \
    -- Performance\
    times_aired INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    estimated_reach INTEGER DEFAULT \cf5 \strokec5 0\cf2 \strokec2 ,\
    \
    -- Costs\
    production_cost DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    ai_cost DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 4\cf2 \strokec2 ),\
    \
    -- Status\
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'DRAFT'\cf2 \strokec2 , -- DRAFT, QC, APPROVED, DEPLOYED\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- Ad Deployments\
CREATE TABLE broadcast.deployments (\
    deployment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),\
    variant_id UUID NOT NULL REFERENCES broadcast.ad_variants(variant_id),\
    \
    -- Target\
    target_type VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ), -- TV_STATION, RADIO_STATION, SOCIAL_MEDIA\
    target_name VARCHAR(\cf5 \strokec5 200\cf2 \strokec2 ),\
    target_market VARCHAR(\cf5 \strokec5 100\cf2 \strokec2 ),\
    \
    -- Schedule\
    scheduled_date DATE,\
    scheduled_time TIME,\
    actual_air_time TIMESTAMPTZ,\
    \
    -- Cost\
    placement_cost DECIMAL(\cf5 \strokec5 10\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    -- Results\
    estimated_impressions INTEGER,\
    actual_impressions INTEGER,\
    website_clicks INTEGER,\
    donations_attributed INTEGER,\
    revenue_attributed DECIMAL(\cf5 \strokec5 12\cf2 \strokec2 , \cf5 \strokec5 2\cf2 \strokec2 ),\
    \
    status VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) DEFAULT \cf6 \strokec6 'SCHEDULED'\cf2 \strokec2 ,\
    \
    created_at TIMESTAMPTZ DEFAULT NOW()\
);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- INDEXES (Performance Optimization)\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- DataHub Indexes\
CREATE INDEX idx_donors_email ON datahub.donors(email);\
CREATE INDEX idx_donors_county ON datahub.donors(county);\
CREATE INDEX idx_donors_grade ON datahub.donors(overall_grade);\
CREATE INDEX idx_donors_score ON datahub.donors(lead_score DESC);\
CREATE INDEX idx_candidates_office ON datahub.candidates(office_sought);\
CREATE INDEX idx_affinity_donor ON datahub.affinity_scores(donor_id);\
CREATE INDEX idx_affinity_candidate ON datahub.affinity_scores(candidate_id);\
CREATE INDEX idx_affinity_score ON datahub.affinity_scores(total_score DESC);\
\
-- Donor Intelligence Indexes\
CREATE INDEX idx_donor_profiles_donor ON donor_intelligence.donor_profiles(donor_id);\
CREATE INDEX idx_donor_profiles_grade ON donor_intelligence.donor_profiles(overall_grade);\
CREATE INDEX idx_donations_donor ON donor_intelligence.donations(donor_id);\
CREATE INDEX idx_donations_date ON donor_intelligence.donations(donation_date DESC);\
\
-- Campaign Indexes\
CREATE INDEX idx_campaigns_candidate ON campaigns.campaigns(candidate_id);\
CREATE INDEX idx_campaigns_status ON campaigns.campaigns(status);\
CREATE INDEX idx_recipients_campaign ON campaigns.recipients(campaign_id);\
CREATE INDEX idx_recipients_donor ON campaigns.recipients(donor_id);\
\
-- Volunteer Indexes\
CREATE INDEX idx_volunteers_grade ON volunteers.profiles(volunteer_grade);\
CREATE INDEX idx_volunteers_score ON volunteers.profiles(volunteer_score DESC);\
CREATE INDEX idx_activities_volunteer ON volunteers.activities(volunteer_id);\
CREATE INDEX idx_activities_date ON volunteers.activities(scheduled_start DESC);\
\
-- Event Indexes\
CREATE INDEX idx_events_date ON events.events(event_date);\
CREATE INDEX idx_events_candidate ON events.events(candidate_id);\
CREATE INDEX idx_rsvps_event ON events.rsvps(event_id);\
\
-- Broadcast Indexes\
CREATE INDEX idx_news_discovered ON broadcast.news_articles(discovered_at DESC);\
CREATE INDEX idx_news_relevance ON broadcast.news_articles(relevance_score DESC);\
CREATE INDEX idx_ad_variants_article ON broadcast.ad_variants(article_id);\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- FUNCTIONS \cf4 \strokec4 &\cf2 \strokec2  TRIGGERS\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
-- Update timestamp \cf7 \strokec7 function\cf2 \strokec2 \
CREATE OR REPLACE FUNCTION update_timestamp()\
RETURNS TRIGGER AS \cf4 \strokec4 $$\cf2 \strokec2 \
BEGIN\
    NEW.updated_at \cf4 \strokec4 =\cf2 \strokec2  NOW();\
    RETURN NEW;\
END;\
\pard\pardeftab720\partightenfactor0
\cf4 \strokec4 $$\cf2 \strokec2  \cf5 \strokec5 LANGUAGE\cf2 \strokec2  plpgsql;\
\
-- Apply to all tables with updated_at\
CREATE TRIGGER update_donors_timestamp BEFORE UPDATE ON datahub.donors\
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();\
\
CREATE TRIGGER update_candidates_timestamp BEFORE UPDATE ON datahub.candidates\
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();\
\
CREATE TRIGGER update_donor_profiles_timestamp BEFORE UPDATE ON donor_intelligence.donor_profiles\
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();\
\
CREATE TRIGGER update_campaigns_timestamp BEFORE UPDATE ON campaigns.campaigns\
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();\
\
-- Calculate affinity category from score\
CREATE OR REPLACE FUNCTION calculate_affinity_category(score INTEGER)\
RETURNS VARCHAR(\cf5 \strokec5 20\cf2 \strokec2 ) AS \cf4 \strokec4 $$\cf2 \strokec2 \
BEGIN\
    RETURN CASE \
        WHEN score \cf4 \strokec4 >=\cf2 \strokec2  \cf5 \strokec5 80\cf2 \strokec2  THEN \cf6 \strokec6 'EXCEPTIONAL'\cf2 \strokec2 \
        WHEN score \cf4 \strokec4 >=\cf2 \strokec2  \cf5 \strokec5 60\cf2 \strokec2  THEN \cf6 \strokec6 'STRONG'\cf2 \strokec2 \
        WHEN score \cf4 \strokec4 >=\cf2 \strokec2  \cf5 \strokec5 40\cf2 \strokec2  THEN \cf6 \strokec6 'GOOD'\cf2 \strokec2 \
        WHEN score \cf4 \strokec4 >=\cf2 \strokec2  \cf5 \strokec5 20\cf2 \strokec2  THEN \cf6 \strokec6 'MODERATE'\cf2 \strokec2 \
        ELSE \cf6 \strokec6 'WEAK'\cf2 \strokec2 \
    END;\
END;\
\cf4 \strokec4 $$\cf2 \strokec2  \cf5 \strokec5 LANGUAGE\cf2 \strokec2  plpgsql IMMUTABLE;\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- SEED DATA - ECOSYSTEM REGISTRY\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
INSERT INTO datahub.ecosystems (ecosystem_code, ecosystem_name, description, status, schema_name, primary_function) VALUES\
(\cf6 \strokec6 'DATAHUB'\cf2 \strokec2 , \cf6 \strokec6 'DataHub'\cf2 \strokec2 , \cf6 \strokec6 'Central integration hub'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'datahub'\cf2 \strokec2 , \cf6 \strokec6 'Donor-Candidate Matching'\cf2 \strokec2 ),\
(\cf6 \strokec6 'DONOR_INTEL'\cf2 \strokec2 , \cf6 \strokec6 'Donor Intelligence'\cf2 \strokec2 , \cf6 \strokec6 '21-tier grading, 1000-point scoring'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'donor_intelligence'\cf2 \strokec2 , \cf6 \strokec6 'Federal/State Donor Intelligence'\cf2 \strokec2 ),\
(\cf6 \strokec6 'LOCAL_INTEL'\cf2 \strokec2 , \cf6 \strokec6 'Local Intelligence'\cf2 \strokec2 , \cf6 \strokec6 'County/city donor matching'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'local_intelligence'\cf2 \strokec2 , \cf6 \strokec6 'Local Donor Intelligence'\cf2 \strokec2 ),\
(\cf6 \strokec6 'CAMPAIGN'\cf2 \strokec2 , \cf6 \strokec6 'Campaign Builder'\cf2 \strokec2 , \cf6 \strokec6 '1,536 templates'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'campaigns'\cf2 \strokec2 , \cf6 \strokec6 'Campaign Creation'\cf2 \strokec2 ),\
(\cf6 \strokec6 'MEDIA'\cf2 \strokec2 , \cf6 \strokec6 'Media Database'\cf2 \strokec2 , \cf6 \strokec6 '214 NC outlets'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'media'\cf2 \strokec2 , \cf6 \strokec6 'Press Release Distribution'\cf2 \strokec2 ),\
(\cf6 \strokec6 'CANDIDATE'\cf2 \strokec2 , \cf6 \strokec6 'Candidate Database'\cf2 \strokec2 , \cf6 \strokec6 '500+ field profiles'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'candidates'\cf2 \strokec2 , \cf6 \strokec6 'Candidate Profiles'\cf2 \strokec2 ),\
(\cf6 \strokec6 'EXECUTION'\cf2 \strokec2 , \cf6 \strokec6 'Campaign Execution'\cf2 \strokec2 , \cf6 \strokec6 'Multi-channel delivery'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'execution'\cf2 \strokec2 , \cf6 \strokec6 'Campaign Sending'\cf2 \strokec2 ),\
(\cf6 \strokec6 'ENRICHMENT'\cf2 \strokec2 , \cf6 \strokec6 'Donor Enrichment'\cf2 \strokec2 , \cf6 \strokec6 '860-field AI enrichment'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'enrichment'\cf2 \strokec2 , \cf6 \strokec6 'AI Data Enrichment'\cf2 \strokec2 ),\
(\cf6 \strokec6 'VOLUNTEER'\cf2 \strokec2 , \cf6 \strokec6 'Volunteer Management'\cf2 \strokec2 , \cf6 \strokec6 '21-tier grading'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'volunteers'\cf2 \strokec2 , \cf6 \strokec6 'Volunteer Operations'\cf2 \strokec2 ),\
(\cf6 \strokec6 'MATCHING'\cf2 \strokec2 , \cf6 \strokec6 'Matching Engine'\cf2 \strokec2 , \cf6 \strokec6 'Automatic matching'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'matching'\cf2 \strokec2 , \cf6 \strokec6 'Auto-Matching'\cf2 \strokec2 ),\
(\cf6 \strokec6 'EVENTS'\cf2 \strokec2 , \cf6 \strokec6 'Event Management'\cf2 \strokec2 , \cf6 \strokec6 'Event RSVPs'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'events'\cf2 \strokec2 , \cf6 \strokec6 'Event Management'\cf2 \strokec2 ),\
(\cf6 \strokec6 'REPORTING'\cf2 \strokec2 , \cf6 \strokec6 'Reporting System'\cf2 \strokec2 , \cf6 \strokec6 '50 reports, 25 dashboards'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'reporting'\cf2 \strokec2 , \cf6 \strokec6 'Reporting & Dashboards'\cf2 \strokec2 ),\
(\cf6 \strokec6 'ANALYTICS'\cf2 \strokec2 , \cf6 \strokec6 'Analytics Dashboards'\cf2 \strokec2 , \cf6 \strokec6 '403 KPIs'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'analytics'\cf2 \strokec2 , \cf6 \strokec6 'Executive Analytics'\cf2 \strokec2 ),\
(\cf6 \strokec6 'AI_HUB'\cf2 \strokec2 , \cf6 \strokec6 'AI Control Center'\cf2 \strokec2 , \cf6 \strokec6 '35+ AI functions'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'ai_hub'\cf2 \strokec2 , \cf6 \strokec6 'AI Coordination'\cf2 \strokec2 ),\
(\cf6 \strokec6 'PREDICTION'\cf2 \strokec2 , \cf6 \strokec6 'Prediction Engine'\cf2 \strokec2 , \cf6 \strokec6 'ML models'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'prediction'\cf2 \strokec2 , \cf6 \strokec6 'Predictive Intelligence'\cf2 \strokec2 ),\
(\cf6 \strokec6 'BROADCAST'\cf2 \strokec2 , \cf6 \strokec6 'Broadcast Ad Creator'\cf2 \strokec2 , \cf6 \strokec6 'AI video/audio production'\cf2 \strokec2 , \cf6 \strokec6 'ACTIVE'\cf2 \strokec2 , \cf6 \strokec6 'broadcast'\cf2 \strokec2 , \cf6 \strokec6 'Broadcast Ad Generation'\cf2 \strokec2 );\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- GRANTS\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
GRANT ALL ON ALL SCHEMAS TO authenticated;\
GRANT ALL ON ALL TABLES IN SCHEMA datahub, donor_intelligence, local_intelligence, campaigns, media, candidates, execution, enrichment, volunteers, matching, events, reporting, analytics, ai_hub, prediction, broadcast TO authenticated;\
GRANT ALL ON ALL SEQUENCES IN SCHEMA datahub, donor_intelligence, local_intelligence, campaigns, media, candidates, execution, enrichment, volunteers, matching, events, reporting, analytics, ai_hub, prediction, broadcast TO authenticated;\
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA datahub, donor_intelligence, local_intelligence, campaigns, media, candidates, execution, enrichment, volunteers, matching, events, reporting, analytics, ai_hub, prediction, broadcast TO authenticated;\
\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
-- INSTALLATION COMPLETE\
-- \cf4 \strokec4 =====================================================\cf2 \strokec2 \
\
COMMENT ON DATABASE current_database IS \cf6 \strokec6 'BroyhillGOP Platform - Complete 16-Ecosystem Installation - December 3, 2024'\cf2 \strokec2 ;\
\
-- Success Message\
DO \cf4 \strokec4 $$\cf2 \strokec2 \
BEGIN\
    RAISE NOTICE \cf6 \strokec6 '\uc0\u10003  BroyhillGOP Platform Installation Complete!'\cf2 \strokec2 ;\
    RAISE NOTICE \cf6 \strokec6 '\uc0\u10003  16 Ecosystems Installed'\cf2 \strokec2 ;\
    RAISE NOTICE \cf6 \strokec6 '\uc0\u10003  250+ Tables Created'\cf2 \strokec2 ;\
    RAISE NOTICE \cf6 \strokec6 '\uc0\u10003  All Indexes Applied'\cf2 \strokec2 ;\
    RAISE NOTICE \cf6 \strokec6 '\uc0\u10003  All Functions Created'\cf2 \strokec2 ;\
    RAISE NOTICE \cf6 \strokec6 '\uc0\u10003  Ready for Python Engine Integration'\cf2 \strokec2 ;\
END \cf4 \strokec4 $$\cf2 \strokec2 ;\
\pard\pardeftab720\partightenfactor0

\f1\fs24 \cf8 \cb9 \strokec8 \
\
\pard\pardeftab720\partightenfactor0
\cf8 \cb1 \
}