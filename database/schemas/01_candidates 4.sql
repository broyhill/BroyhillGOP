-- ============================================================================
-- CANDIDATE PROFILE SCHEMA
-- 200+ Qualifiers for Matching
-- BroyhillGOP Platform
-- ============================================================================

-- ============================================================================
-- TABLE: candidates (Master)
-- ============================================================================

CREATE TABLE candidates (
  -- Primary Key
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- =========================================================================
  -- CATEGORY 1: BASIC INFO (20 fields)
  -- =========================================================================
  
  -- Identity
  first_name              VARCHAR(100) NOT NULL,
  last_name               VARCHAR(100) NOT NULL,
  full_name               VARCHAR(200) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
  nickname                VARCHAR(50),
  suffix                  VARCHAR(10),  -- Jr., Sr., III, etc.
  
  -- Office
  office_type             VARCHAR(20) NOT NULL,  -- Federal, State, Local
  office_level            VARCHAR(50),  -- US Senate, US Congress, NC Senate, NC House, County Commission, etc.
  office_title            VARCHAR(100),  -- Full title: "US Representative, NC District 5"
  district                VARCHAR(50),  -- District number or name
  seat                    VARCHAR(20),  -- Seat A/B for multi-seat
  
  -- Status
  incumbent               BOOLEAN DEFAULT false,
  election_year           INTEGER,
  election_type           VARCHAR(20),  -- General, Primary, Special
  filing_status           VARCHAR(20),  -- Filed, Declared, Exploratory, Rumored
  campaign_status         VARCHAR(20),  -- Active, Suspended, Won, Lost
  
  -- Party
  party                   VARCHAR(20) DEFAULT 'Republican',
  party_registration_date DATE,
  
  -- IDs
  fec_candidate_id        VARCHAR(20),
  ncsbe_candidate_id      VARCHAR(20),
  
  -- =========================================================================
  -- CATEGORY 2: GEOGRAPHY (25 fields)
  -- =========================================================================
  
  -- Home
  home_county             VARCHAR(50),
  home_city               VARCHAR(100),
  home_zip                VARCHAR(10),
  
  -- District Coverage
  district_counties       TEXT[],  -- Array of county names
  district_county_count   INTEGER,
  district_population     INTEGER,
  district_registered_r   INTEGER,  -- Registered Republicans
  district_registered_d   INTEGER,  -- Registered Democrats
  district_registered_u   INTEGER,  -- Unaffiliated
  
  -- Regional Classification
  region                  VARCHAR(50),  -- Piedmont, Mountain, Coast, etc.
  urban_rural_mix         VARCHAR(20),  -- Urban, Suburban, Rural, Mixed
  media_market            VARCHAR(50),  -- Charlotte, Raleigh, Triad, etc.
  
  -- Key Geographies
  bellwether_counties     TEXT[],  -- Bellwether counties in district
  swing_precincts         TEXT[],  -- Key swing precincts
  base_precincts          TEXT[],  -- Strong R precincts
  target_precincts        TEXT[],  -- Growth opportunity precincts
  
  -- Previous Performance by Area
  county_performance_json JSONB,  -- {county: {2020: %, 2022: %}}
  precinct_performance_json JSONB,
  
  -- Neighboring Districts
  adjacent_districts      TEXT[],
  shared_media_candidates TEXT[],  -- Other candidates in same media market
  
  -- =========================================================================
  -- CATEGORY 3: ISSUE POSITIONS (45 fields - 15 issues × 3)
  -- =========================================================================
  
  -- 2nd Amendment
  issue_2a_stance         VARCHAR(20),  -- Pro, Anti, Moderate, Unknown
  issue_2a_intensity      INTEGER CHECK (issue_2a_intensity BETWEEN 1 AND 5),  -- 1=Weak, 5=Champion
  issue_2a_notes          TEXT,
  
  -- Abortion/Pro-Life
  issue_abortion_stance   VARCHAR(20),
  issue_abortion_intensity INTEGER CHECK (issue_abortion_intensity BETWEEN 1 AND 5),
  issue_abortion_notes    TEXT,
  
  -- CRT/Education
  issue_crt_stance        VARCHAR(20),
  issue_crt_intensity     INTEGER CHECK (issue_crt_intensity BETWEEN 1 AND 5),
  issue_crt_notes         TEXT,
  
  -- Election Integrity
  issue_election_stance   VARCHAR(20),
  issue_election_intensity INTEGER CHECK (issue_election_intensity BETWEEN 1 AND 5),
  issue_election_notes    TEXT,
  
  -- Immigration/Border
  issue_border_stance     VARCHAR(20),
  issue_border_intensity  INTEGER CHECK (issue_border_intensity BETWEEN 1 AND 5),
  issue_border_notes      TEXT,
  
  -- Taxes
  issue_taxes_stance      VARCHAR(20),
  issue_taxes_intensity   INTEGER CHECK (issue_taxes_intensity BETWEEN 1 AND 5),
  issue_taxes_notes       TEXT,
  
  -- Government Spending
  issue_spending_stance   VARCHAR(20),
  issue_spending_intensity INTEGER CHECK (issue_spending_intensity BETWEEN 1 AND 5),
  issue_spending_notes    TEXT,
  
  -- Crime/Law Enforcement
  issue_crime_stance      VARCHAR(20),
  issue_crime_intensity   INTEGER CHECK (issue_crime_intensity BETWEEN 1 AND 5),
  issue_crime_notes       TEXT,
  
  -- Religious Liberty
  issue_religion_stance   VARCHAR(20),
  issue_religion_intensity INTEGER CHECK (issue_religion_intensity BETWEEN 1 AND 5),
  issue_religion_notes    TEXT,
  
  -- Parental Rights
  issue_parental_stance   VARCHAR(20),
  issue_parental_intensity INTEGER CHECK (issue_parental_intensity BETWEEN 1 AND 5),
  issue_parental_notes    TEXT,
  
  -- School Choice
  issue_school_choice_stance VARCHAR(20),
  issue_school_choice_intensity INTEGER CHECK (issue_school_choice_intensity BETWEEN 1 AND 5),
  issue_school_choice_notes TEXT,
  
  -- Energy
  issue_energy_stance     VARCHAR(20),
  issue_energy_intensity  INTEGER CHECK (issue_energy_intensity BETWEEN 1 AND 5),
  issue_energy_notes      TEXT,
  
  -- Healthcare
  issue_healthcare_stance VARCHAR(20),
  issue_healthcare_intensity INTEGER CHECK (issue_healthcare_intensity BETWEEN 1 AND 5),
  issue_healthcare_notes  TEXT,
  
  -- Veterans
  issue_veterans_stance   VARCHAR(20),
  issue_veterans_intensity INTEGER CHECK (issue_veterans_intensity BETWEEN 1 AND 5),
  issue_veterans_notes    TEXT,
  
  -- Agriculture
  issue_agriculture_stance VARCHAR(20),
  issue_agriculture_intensity INTEGER CHECK (issue_agriculture_intensity BETWEEN 1 AND 5),
  issue_agriculture_notes TEXT,
  
  -- =========================================================================
  -- CATEGORY 4: ENDORSEMENTS & RATINGS (40 fields)
  -- =========================================================================
  
  -- Gun Rights
  endorsement_nra_rating  VARCHAR(10),  -- A+, A, A-, B, C, D, F
  endorsement_nra_endorsed BOOLEAN,
  endorsement_goa_rating  VARCHAR(10),  -- Gun Owners of America
  endorsement_goa_endorsed BOOLEAN,
  
  -- Pro-Life
  endorsement_nrlc_rating VARCHAR(10),  -- National Right to Life
  endorsement_nrlc_endorsed BOOLEAN,
  endorsement_sba_endorsed BOOLEAN,  -- Susan B. Anthony List
  endorsement_nc_rtl_endorsed BOOLEAN,  -- NC Right to Life
  
  -- Fiscal
  endorsement_club_growth_endorsed BOOLEAN,
  endorsement_club_growth_rating INTEGER,  -- Percentage
  endorsement_americans_for_prosperity BOOLEAN,
  endorsement_nc_chamber_rating INTEGER,
  endorsement_nfib_endorsed BOOLEAN,  -- Small business
  
  -- Conservative Movement
  endorsement_heritage_score INTEGER,
  endorsement_acuf_rating INTEGER,  -- ACU Conservative Rating
  endorsement_freedomworks_endorsed BOOLEAN,
  endorsement_freedomworks_score INTEGER,
  
  -- Trump/MAGA
  endorsement_trump_endorsed BOOLEAN,
  endorsement_trump_endorsed_date DATE,
  endorsement_maga_inc_endorsed BOOLEAN,
  
  -- Tea Party/Grassroots
  endorsement_tea_party_endorsed BOOLEAN,
  endorsement_nc_grassroots BOOLEAN,
  
  -- Law Enforcement
  endorsement_fop_endorsed BOOLEAN,  -- Fraternal Order of Police
  endorsement_nc_sheriffs_endorsed BOOLEAN,
  endorsement_nc_troopers_endorsed BOOLEAN,
  
  -- Veterans
  endorsement_vfw_endorsed BOOLEAN,
  endorsement_american_legion_endorsed BOOLEAN,
  endorsement_veterans_rating INTEGER,
  
  -- Agriculture
  endorsement_farm_bureau_endorsed BOOLEAN,
  endorsement_farm_bureau_rating INTEGER,
  
  -- Education
  endorsement_nc_school_choice BOOLEAN,
  endorsement_parents_rights_endorsed BOOLEAN,
  
  -- Other Key Endorsements
  endorsement_nc_gop_endorsed BOOLEAN,
  endorsement_sitting_governor BOOLEAN,
  endorsement_sitting_senators TEXT[],  -- Array of senator names
  endorsement_other_notable TEXT[],  -- Other notable endorsements
  
  -- Endorsement JSON (overflow)
  endorsements_json       JSONB,  -- Full endorsement details
  
  -- =========================================================================
  -- CATEGORY 5: FACTION ALIGNMENT (15 fields)
  -- =========================================================================
  
  -- Faction Scores (0-100)
  faction_trump_maga      INTEGER CHECK (faction_trump_maga BETWEEN 0 AND 100),
  faction_tea_party       INTEGER CHECK (faction_tea_party BETWEEN 0 AND 100),
  faction_establishment   INTEGER CHECK (faction_establishment BETWEEN 0 AND 100),
  faction_libertarian     INTEGER CHECK (faction_libertarian BETWEEN 0 AND 100),
  faction_moderate        INTEGER CHECK (faction_moderate BETWEEN 0 AND 100),
  faction_religious_right INTEGER CHECK (faction_religious_right BETWEEN 0 AND 100),
  faction_business_wing   INTEGER CHECK (faction_business_wing BETWEEN 0 AND 100),
  
  -- Faction Classification
  faction_primary         VARCHAR(30),  -- Dominant faction
  faction_secondary       VARCHAR(30),  -- Secondary faction
  faction_coalition       TEXT[],  -- Array of aligned factions
  
  -- Intra-party Dynamics
  faction_rivals          TEXT[],  -- Factions that oppose
  faction_allies          TEXT[],  -- Natural allies
  faction_notes           TEXT,
  
  -- =========================================================================
  -- CATEGORY 6: DEMOGRAPHIC APPEAL (25 fields)
  -- =========================================================================
  
  -- Geographic Appeal (0-100)
  appeal_rural            INTEGER CHECK (appeal_rural BETWEEN 0 AND 100),
  appeal_suburban         INTEGER CHECK (appeal_suburban BETWEEN 0 AND 100),
  appeal_urban            INTEGER CHECK (appeal_urban BETWEEN 0 AND 100),
  
  -- Age Appeal
  appeal_seniors          INTEGER CHECK (appeal_seniors BETWEEN 0 AND 100),  -- 65+
  appeal_middle_age       INTEGER CHECK (appeal_middle_age BETWEEN 0 AND 100),  -- 45-64
  appeal_young_adults     INTEGER CHECK (appeal_young_adults BETWEEN 0 AND 100),  -- 25-44
  appeal_youth            INTEGER CHECK (appeal_youth BETWEEN 0 AND 100),  -- 18-24
  
  -- Group Appeal
  appeal_veterans         INTEGER CHECK (appeal_veterans BETWEEN 0 AND 100),
  appeal_military_families INTEGER CHECK (appeal_military_families BETWEEN 0 AND 100),
  appeal_small_business   INTEGER CHECK (appeal_small_business BETWEEN 0 AND 100),
  appeal_farmers          INTEGER CHECK (appeal_farmers BETWEEN 0 AND 100),
  appeal_evangelicals     INTEGER CHECK (appeal_evangelicals BETWEEN 0 AND 100),
  appeal_catholics        INTEGER CHECK (appeal_catholics BETWEEN 0 AND 100),
  appeal_women            INTEGER CHECK (appeal_women BETWEEN 0 AND 100),
  appeal_men              INTEGER CHECK (appeal_men BETWEEN 0 AND 100),
  appeal_parents          INTEGER CHECK (appeal_parents BETWEEN 0 AND 100),
  appeal_retirees         INTEGER CHECK (appeal_retirees BETWEEN 0 AND 100),
  appeal_gun_owners       INTEGER CHECK (appeal_gun_owners BETWEEN 0 AND 100),
  appeal_hunters          INTEGER CHECK (appeal_hunters BETWEEN 0 AND 100),
  appeal_first_responders INTEGER CHECK (appeal_first_responders BETWEEN 0 AND 100),
  
  -- Occupation Appeal
  appeal_blue_collar      INTEGER CHECK (appeal_blue_collar BETWEEN 0 AND 100),
  appeal_white_collar     INTEGER CHECK (appeal_white_collar BETWEEN 0 AND 100),
  appeal_professionals    INTEGER CHECK (appeal_professionals BETWEEN 0 AND 100),
  appeal_entrepreneurs    INTEGER CHECK (appeal_entrepreneurs BETWEEN 0 AND 100),
  
  -- =========================================================================
  -- CATEGORY 7: CAMPAIGN FOCUS (15 fields)
  -- =========================================================================
  
  -- Theme Priorities
  campaign_theme_primary  VARCHAR(50),
  campaign_theme_secondary VARCHAR(50),
  campaign_theme_tertiary VARCHAR(50),
  campaign_themes_json    JSONB,  -- Full theme breakdown
  
  -- Messaging
  campaign_slogan         VARCHAR(200),
  campaign_tagline        VARCHAR(100),
  campaign_key_messages   TEXT[],
  
  -- Strategy
  campaign_target_voters  TEXT[],  -- Target voter descriptions
  campaign_persuasion_targets TEXT[],
  campaign_base_motivation TEXT[],
  
  -- Budget Focus
  campaign_channel_priority TEXT[],  -- [TV, Digital, Mail, Radio]
  campaign_county_priority TEXT[],  -- Priority counties
  
  -- =========================================================================
  -- CATEGORY 8: PREVIOUS PERFORMANCE (20 fields)
  -- =========================================================================
  
  -- Last Election
  prev_election_year      INTEGER,
  prev_election_type      VARCHAR(20),
  prev_election_office    VARCHAR(100),
  prev_election_result    VARCHAR(10),  -- Won, Lost
  prev_election_votes     INTEGER,
  prev_election_pct       DECIMAL(5,2),
  prev_election_opponent  VARCHAR(100),
  prev_election_margin    DECIMAL(5,2),
  
  -- Primary Performance
  prev_primary_year       INTEGER,
  prev_primary_votes      INTEGER,
  prev_primary_pct        DECIMAL(5,2),
  prev_primary_opponents  INTEGER,  -- Number of opponents
  
  -- Fundraising History
  prev_raised_total       DECIMAL(12,2),
  prev_raised_individual  DECIMAL(12,2),
  prev_raised_pac         DECIMAL(12,2),
  prev_donors_count       INTEGER,
  prev_avg_donation       DECIMAL(8,2),
  
  -- Historical JSON
  election_history_json   JSONB,  -- Full election history
  fundraising_history_json JSONB,
  
  -- =========================================================================
  -- CATEGORY 9: CANDIDATE ATTRIBUTES (20 fields)
  -- =========================================================================
  
  -- Personal
  birth_year              INTEGER,
  age                     INTEGER,
  gender                  VARCHAR(10),
  education_level         VARCHAR(50),
  education_school        VARCHAR(100),
  military_service        BOOLEAN,
  military_branch         VARCHAR(50),
  military_rank           VARCHAR(50),
  
  -- Professional
  occupation              VARCHAR(100),
  employer                VARCHAR(100),
  industry                VARCHAR(50),
  business_owner          BOOLEAN,
  
  -- Community
  years_in_district       INTEGER,
  community_involvement   TEXT[],
  church_affiliation      VARCHAR(100),
  civic_memberships       TEXT[],
  
  -- Family
  marital_status          VARCHAR(20),
  children                INTEGER,
  family_notes            TEXT,
  
  -- =========================================================================
  -- CATEGORY 10: COMPETITIVE LANDSCAPE (15 fields)
  -- =========================================================================
  
  -- Opponents
  general_opponent_name   VARCHAR(100),
  general_opponent_party  VARCHAR(20),
  general_opponent_incumbent BOOLEAN,
  primary_opponents       JSONB,  -- Array of primary opponents
  
  -- Race Ratings
  race_rating_cook        VARCHAR(20),  -- Safe R, Likely R, Lean R, Toss-up, etc.
  race_rating_sabato      VARCHAR(20),
  race_rating_inside      VARCHAR(20),
  race_rating_internal    VARCHAR(20),  -- Our internal rating
  
  -- Competitiveness
  competitive_index       INTEGER CHECK (competitive_index BETWEEN 0 AND 100),
  vulnerability_index     INTEGER CHECK (vulnerability_index BETWEEN 0 AND 100),
  opportunity_index       INTEGER CHECK (opportunity_index BETWEEN 0 AND 100),
  
  -- Strategic Notes
  competitive_advantages  TEXT[],
  competitive_weaknesses  TEXT[],
  win_path_notes          TEXT,
  
  -- =========================================================================
  -- METADATA
  -- =========================================================================
  
  profile_complete        BOOLEAN DEFAULT false,
  profile_completeness    INTEGER CHECK (profile_completeness BETWEEN 0 AND 100),
  last_profile_update     TIMESTAMP,
  profile_updated_by      VARCHAR(100),
  notes                   TEXT,
  
  created_at              TIMESTAMP DEFAULT NOW(),
  updated_at              TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_candidates_office_type ON candidates(office_type);
CREATE INDEX idx_candidates_status ON candidates(campaign_status);
CREATE INDEX idx_candidates_county ON candidates(home_county);
CREATE INDEX idx_candidates_district ON candidates(district);
CREATE INDEX idx_candidates_faction ON candidates(faction_primary);
CREATE INDEX idx_candidates_trump ON candidates(endorsement_trump_endorsed);

-- ============================================================================
-- TRIGGER: Update timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_candidate_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER candidates_updated
  BEFORE UPDATE ON candidates
  FOR EACH ROW
  EXECUTE FUNCTION update_candidate_timestamp();
