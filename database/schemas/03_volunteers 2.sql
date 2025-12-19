-- ============================================================================
-- VOLUNTEER PROFILE SCHEMA
-- 150+ Qualifiers for Matching
-- BroyhillGOP Platform
-- ============================================================================

-- ============================================================================
-- TABLE: volunteers (Master Pool)
-- ============================================================================

CREATE TABLE volunteers (
  -- Primary Key
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Link to donor (if also a donor)
  donor_id                UUID REFERENCES donors(id),
  
  -- =========================================================================
  -- CATEGORY 1: IDENTITY (20 fields)
  -- =========================================================================
  
  -- Name
  first_name              VARCHAR(100),
  last_name               VARCHAR(100) NOT NULL,
  full_name               VARCHAR(250),
  nickname                VARCHAR(50),
  
  -- Contact
  email                   VARCHAR(200),
  email_verified          BOOLEAN DEFAULT false,
  phone                   VARCHAR(20),
  phone_type              VARCHAR(10),
  phone_verified          BOOLEAN DEFAULT false,
  sms_opt_in              BOOLEAN DEFAULT true,
  
  -- Address
  address_line1           VARCHAR(200),
  city                    VARCHAR(100),
  state                   VARCHAR(2) DEFAULT 'NC',
  zip                     VARCHAR(10),
  county                  VARCHAR(50),
  
  -- Geo
  congressional_district  VARCHAR(10),
  nc_senate_district      VARCHAR(10),
  nc_house_district       VARCHAR(10),
  precinct                VARCHAR(50),
  
  -- =========================================================================
  -- CATEGORY 2: DEMOGRAPHICS (20 fields)
  -- =========================================================================
  
  gender                  VARCHAR(10),
  birth_year              INTEGER,
  age                     INTEGER,
  age_range               VARCHAR(20),
  
  -- Employment
  occupation              VARCHAR(100),
  employer                VARCHAR(200),
  employment_status       VARCHAR(20),
  retired                 BOOLEAN DEFAULT false,
  student                 BOOLEAN DEFAULT false,
  
  -- Personal
  marital_status          VARCHAR(20),
  children_present        BOOLEAN,
  homeowner               BOOLEAN,
  
  -- Background
  education_level         VARCHAR(50),
  veteran                 BOOLEAN DEFAULT false,
  military_branch         VARCHAR(50),
  first_responder         BOOLEAN DEFAULT false,
  first_responder_type    VARCHAR(50),  -- Police, Fire, EMS
  gun_owner               BOOLEAN,
  religion                VARCHAR(50),
  
  -- =========================================================================
  -- CATEGORY 3: ISSUE PASSIONS (45 fields - 15 issues × 3)
  -- PRIMARY DRIVER FOR VOLUNTEERS
  -- =========================================================================
  
  -- 2nd Amendment
  issue_2a_intensity      INTEGER CHECK (issue_2a_intensity BETWEEN 1 AND 5),
  issue_2a_source         VARCHAR(20),
  issue_2a_will_work      BOOLEAN DEFAULT false,  -- Will volunteer for this issue
  
  -- Abortion/Pro-Life
  issue_abortion_intensity INTEGER CHECK (issue_abortion_intensity BETWEEN 1 AND 5),
  issue_abortion_source   VARCHAR(20),
  issue_abortion_will_work BOOLEAN DEFAULT false,
  
  -- CRT/Education
  issue_crt_intensity     INTEGER CHECK (issue_crt_intensity BETWEEN 1 AND 5),
  issue_crt_source        VARCHAR(20),
  issue_crt_will_work     BOOLEAN DEFAULT false,
  
  -- Election Integrity
  issue_election_intensity INTEGER CHECK (issue_election_intensity BETWEEN 1 AND 5),
  issue_election_source   VARCHAR(20),
  issue_election_will_work BOOLEAN DEFAULT false,
  
  -- Immigration/Border
  issue_border_intensity  INTEGER CHECK (issue_border_intensity BETWEEN 1 AND 5),
  issue_border_source     VARCHAR(20),
  issue_border_will_work  BOOLEAN DEFAULT false,
  
  -- Taxes
  issue_taxes_intensity   INTEGER CHECK (issue_taxes_intensity BETWEEN 1 AND 5),
  issue_taxes_source      VARCHAR(20),
  issue_taxes_will_work   BOOLEAN DEFAULT false,
  
  -- Government Spending
  issue_spending_intensity INTEGER CHECK (issue_spending_intensity BETWEEN 1 AND 5),
  issue_spending_source   VARCHAR(20),
  issue_spending_will_work BOOLEAN DEFAULT false,
  
  -- Crime/Law Enforcement
  issue_crime_intensity   INTEGER CHECK (issue_crime_intensity BETWEEN 1 AND 5),
  issue_crime_source      VARCHAR(20),
  issue_crime_will_work   BOOLEAN DEFAULT false,
  
  -- Religious Liberty
  issue_religion_intensity INTEGER CHECK (issue_religion_intensity BETWEEN 1 AND 5),
  issue_religion_source   VARCHAR(20),
  issue_religion_will_work BOOLEAN DEFAULT false,
  
  -- Parental Rights
  issue_parental_intensity INTEGER CHECK (issue_parental_intensity BETWEEN 1 AND 5),
  issue_parental_source   VARCHAR(20),
  issue_parental_will_work BOOLEAN DEFAULT false,
  
  -- School Choice
  issue_school_choice_intensity INTEGER CHECK (issue_school_choice_intensity BETWEEN 1 AND 5),
  issue_school_choice_source VARCHAR(20),
  issue_school_choice_will_work BOOLEAN DEFAULT false,
  
  -- Energy
  issue_energy_intensity  INTEGER CHECK (issue_energy_intensity BETWEEN 1 AND 5),
  issue_energy_source     VARCHAR(20),
  issue_energy_will_work  BOOLEAN DEFAULT false,
  
  -- Healthcare
  issue_healthcare_intensity INTEGER CHECK (issue_healthcare_intensity BETWEEN 1 AND 5),
  issue_healthcare_source VARCHAR(20),
  issue_healthcare_will_work BOOLEAN DEFAULT false,
  
  -- Veterans
  issue_veterans_intensity INTEGER CHECK (issue_veterans_intensity BETWEEN 1 AND 5),
  issue_veterans_source   VARCHAR(20),
  issue_veterans_will_work BOOLEAN DEFAULT false,
  
  -- Agriculture
  issue_agriculture_intensity INTEGER CHECK (issue_agriculture_intensity BETWEEN 1 AND 5),
  issue_agriculture_source VARCHAR(20),
  issue_agriculture_will_work BOOLEAN DEFAULT false,
  
  -- Issue Summary
  issue_passion_avg       DECIMAL(3,2),  -- Calculated average
  issue_top_3             TEXT[],  -- Top 3 issue slugs
  issue_will_work_count   INTEGER DEFAULT 0,
  
  -- =========================================================================
  -- CATEGORY 4: FACTION ALIGNMENT (10 fields)
  -- =========================================================================
  
  faction_trump_maga      INTEGER CHECK (faction_trump_maga BETWEEN 0 AND 100),
  faction_tea_party       INTEGER CHECK (faction_tea_party BETWEEN 0 AND 100),
  faction_establishment   INTEGER CHECK (faction_establishment BETWEEN 0 AND 100),
  faction_libertarian     INTEGER CHECK (faction_libertarian BETWEEN 0 AND 100),
  faction_moderate        INTEGER CHECK (faction_moderate BETWEEN 0 AND 100),
  faction_religious_right INTEGER CHECK (faction_religious_right BETWEEN 0 AND 100),
  
  faction_primary         VARCHAR(30),
  faction_secondary       VARCHAR(30),
  faction_source          VARCHAR(20),
  faction_confidence      INTEGER,
  
  -- =========================================================================
  -- CATEGORY 5: AVAILABILITY (20 fields)
  -- =========================================================================
  
  -- Regular Availability
  avail_weekday_morning   BOOLEAN DEFAULT false,
  avail_weekday_afternoon BOOLEAN DEFAULT false,
  avail_weekday_evening   BOOLEAN DEFAULT false,
  avail_saturday_morning  BOOLEAN DEFAULT false,
  avail_saturday_afternoon BOOLEAN DEFAULT false,
  avail_saturday_evening  BOOLEAN DEFAULT false,
  avail_sunday_morning    BOOLEAN DEFAULT false,
  avail_sunday_afternoon  BOOLEAN DEFAULT false,
  
  -- Special Availability
  avail_election_day      BOOLEAN DEFAULT false,
  avail_early_voting      BOOLEAN DEFAULT false,
  avail_any_time          BOOLEAN DEFAULT false,
  avail_on_call           BOOLEAN DEFAULT false,
  
  -- Constraints
  avail_hours_per_week    INTEGER,  -- Max hours available per week
  avail_travel_radius     INTEGER,  -- Miles willing to travel
  avail_start_date        DATE,  -- When can they start
  avail_end_date          DATE,  -- Any end date constraint
  avail_blackout_dates    DATE[],  -- Dates not available
  avail_notes             TEXT,
  
  -- Calculated Score
  availability_score      INTEGER CHECK (availability_score BETWEEN 0 AND 100),
  availability_slots_count INTEGER DEFAULT 0,
  
  -- =========================================================================
  -- CATEGORY 6: SKILLS (30 fields)
  -- =========================================================================
  
  -- Core Campaign Skills
  skill_phone_banking     BOOLEAN DEFAULT false,
  skill_phone_banking_exp INTEGER,  -- Years experience
  skill_door_knocking     BOOLEAN DEFAULT false,
  skill_door_knocking_exp INTEGER,
  skill_lit_drop          BOOLEAN DEFAULT false,
  skill_sign_placement    BOOLEAN DEFAULT false,
  skill_poll_greeting     BOOLEAN DEFAULT false,
  
  -- Election Operations
  skill_poll_observer     BOOLEAN DEFAULT false,
  skill_poll_observer_certified BOOLEAN DEFAULT false,
  skill_poll_worker       BOOLEAN DEFAULT false,
  skill_ballot_chase      BOOLEAN DEFAULT false,
  skill_voter_registration BOOLEAN DEFAULT false,
  
  -- Events
  skill_event_setup       BOOLEAN DEFAULT false,
  skill_event_registration BOOLEAN DEFAULT false,
  skill_event_security    BOOLEAN DEFAULT false,
  skill_parade_participant BOOLEAN DEFAULT false,
  skill_fair_booth        BOOLEAN DEFAULT false,
  
  -- Communication
  skill_public_speaking   BOOLEAN DEFAULT false,
  skill_social_media      BOOLEAN DEFAULT false,
  skill_writing           BOOLEAN DEFAULT false,
  skill_graphic_design    BOOLEAN DEFAULT false,
  skill_photography       BOOLEAN DEFAULT false,
  skill_video             BOOLEAN DEFAULT false,
  
  -- Office/Admin
  skill_data_entry        BOOLEAN DEFAULT false,
  skill_receptionist      BOOLEAN DEFAULT false,
  skill_mailings          BOOLEAN DEFAULT false,
  
  -- Special
  skill_driving           BOOLEAN DEFAULT false,
  skill_has_vehicle       BOOLEAN DEFAULT false,
  skill_bilingual         BOOLEAN DEFAULT false,
  skill_languages         TEXT[],
  skill_leadership        BOOLEAN DEFAULT false,
  skill_training_others   BOOLEAN DEFAULT false,
  
  -- Calculated
  skills_score            INTEGER CHECK (skills_score BETWEEN 0 AND 100),
  skills_list             TEXT[],
  skills_count            INTEGER DEFAULT 0,
  
  -- =========================================================================
  -- CATEGORY 7: VOLUNTEER HISTORY (15 fields)
  -- =========================================================================
  
  history_first_volunteer DATE,
  history_last_volunteer  DATE,
  history_total_hours     DECIMAL(8,1) DEFAULT 0,
  history_total_events    INTEGER DEFAULT 0,
  history_total_shifts    INTEGER DEFAULT 0,
  
  -- By Activity Type
  history_hours_phone     DECIMAL(6,1) DEFAULT 0,
  history_hours_doors     DECIMAL(6,1) DEFAULT 0,
  history_hours_events    DECIMAL(6,1) DEFAULT 0,
  history_hours_office    DECIMAL(6,1) DEFAULT 0,
  history_hours_election  DECIMAL(6,1) DEFAULT 0,
  
  -- Reliability
  history_shifts_completed INTEGER DEFAULT 0,
  history_shifts_missed   INTEGER DEFAULT 0,
  history_show_rate       DECIMAL(5,4),  -- Completed / Scheduled
  
  -- Performance
  history_contacts_made   INTEGER DEFAULT 0,  -- Doors knocked, calls made
  history_json            JSONB,  -- Full activity history
  
  -- =========================================================================
  -- CATEGORY 8: LEADERSHIP & ROLES (10 fields)
  -- =========================================================================
  
  is_captain_material     BOOLEAN DEFAULT false,
  is_current_captain      BOOLEAN DEFAULT false,
  captain_precinct        VARCHAR(50),
  captain_since           DATE,
  
  leadership_role         VARCHAR(50),  -- Precinct Captain, County Lead, etc.
  leadership_level        VARCHAR(20),  -- Precinct, County, District, State
  leadership_appointed_by VARCHAR(100),
  
  recruiter_active        BOOLEAN DEFAULT false,
  recruits_count          INTEGER DEFAULT 0,
  recruits_list           UUID[],  -- IDs of recruited volunteers
  
  -- =========================================================================
  -- CATEGORY 9: DONOR CROSSOVER (10 fields)
  -- =========================================================================
  
  is_donor                BOOLEAN DEFAULT false,
  donor_grade             VARCHAR(4),  -- B+, C, etc.
  donor_amount_lifetime   DECIMAL(10,2) DEFAULT 0,
  donor_amount_ytd        DECIMAL(8,2) DEFAULT 0,
  donor_last_gift_date    DATE,
  donor_capacity_flag     VARCHAR(4),
  
  -- Combined Value
  dual_value_score        INTEGER,  -- Combined donor + volunteer value
  donor_volunteer_overlap BOOLEAN DEFAULT false,
  
  -- =========================================================================
  -- CATEGORY 10: ENGAGEMENT (10 fields)
  -- =========================================================================
  
  engagement_email_subscribed BOOLEAN DEFAULT true,
  engagement_sms_subscribed BOOLEAN DEFAULT true,
  engagement_email_open_rate DECIMAL(5,4),
  engagement_response_rate DECIMAL(5,4),  -- Response to volunteer asks
  
  engagement_events_rsvp  INTEGER DEFAULT 0,
  engagement_events_attended INTEGER DEFAULT 0,
  engagement_last_contact DATE,
  
  engagement_score        INTEGER CHECK (engagement_score BETWEEN 0 AND 100),
  engagement_level        VARCHAR(20),
  
  -- =========================================================================
  -- CATEGORY 11: SOURCE & STATUS (10 fields)
  -- =========================================================================
  
  source                  VARCHAR(50),  -- Website, Event, Referral, etc.
  source_detail           VARCHAR(200),
  source_event            VARCHAR(100),
  referred_by             UUID,
  
  status                  VARCHAR(20) DEFAULT 'Active',  -- Active, Inactive, Banned
  status_reason           VARCHAR(200),
  status_date             DATE,
  
  signup_date             DATE DEFAULT CURRENT_DATE,
  last_active_date        DATE,
  
  -- =========================================================================
  -- METADATA
  -- =========================================================================
  
  notes                   TEXT,
  tags                    TEXT[],
  
  created_at              TIMESTAMP DEFAULT NOW(),
  updated_at              TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_volunteers_county ON volunteers(county);
CREATE INDEX idx_volunteers_email ON volunteers(email);
CREATE INDEX idx_volunteers_status ON volunteers(status);
CREATE INDEX idx_volunteers_donor ON volunteers(is_donor);
CREATE INDEX idx_volunteers_captain ON volunteers(is_captain_material);
CREATE INDEX idx_volunteers_faction ON volunteers(faction_primary);
CREATE INDEX idx_volunteers_election_day ON volunteers(avail_election_day);
CREATE INDEX idx_volunteers_cd ON volunteers(congressional_district);
CREATE INDEX idx_volunteers_skills ON volunteers USING GIN(skills_list);

-- Issue indexes
CREATE INDEX idx_vol_issue_2a ON volunteers(issue_2a_intensity);
CREATE INDEX idx_vol_issue_crt ON volunteers(issue_crt_intensity);
CREATE INDEX idx_vol_issue_election ON volunteers(issue_election_intensity);
CREATE INDEX idx_vol_issue_abortion ON volunteers(issue_abortion_intensity);

-- ============================================================================
-- TRIGGER: Update timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_volunteer_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER volunteers_updated
  BEFORE UPDATE ON volunteers
  FOR EACH ROW
  EXECUTE FUNCTION update_volunteer_timestamp();
