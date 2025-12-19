-- ============================================================================
-- DONOR PROFILE SCHEMA
-- 200+ Qualifiers for Matching
-- BroyhillGOP Platform
-- ============================================================================

-- ============================================================================
-- TABLE: donors (Master Pool)
-- ============================================================================

CREATE TABLE donors (
  -- Primary Key
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- =========================================================================
  -- CATEGORY 1: IDENTITY (25 fields)
  -- =========================================================================
  
  -- Name
  first_name              VARCHAR(100),
  middle_name             VARCHAR(100),
  last_name               VARCHAR(100) NOT NULL,
  full_name               VARCHAR(250),
  suffix                  VARCHAR(10),
  salutation              VARCHAR(50),  -- Mr., Mrs., Dr., etc.
  
  -- Contact
  email                   VARCHAR(200),
  email_verified          BOOLEAN DEFAULT false,
  phone                   VARCHAR(20),
  phone_type              VARCHAR(10),  -- Mobile, Home, Work
  phone_verified          BOOLEAN DEFAULT false,
  
  -- Address
  address_line1           VARCHAR(200),
  address_line2           VARCHAR(100),
  city                    VARCHAR(100),
  state                   VARCHAR(2) DEFAULT 'NC',
  zip                     VARCHAR(10),
  zip4                    VARCHAR(4),
  county                  VARCHAR(50),
  
  -- Geo
  latitude                DECIMAL(10,7),
  longitude               DECIMAL(10,7),
  precinct                VARCHAR(50),
  congressional_district  VARCHAR(10),
  nc_senate_district      VARCHAR(10),
  nc_house_district       VARCHAR(10),
  
  -- =========================================================================
  -- CATEGORY 2: DEMOGRAPHICS (25 fields)
  -- =========================================================================
  
  -- Personal
  gender                  VARCHAR(10),
  birth_year              INTEGER,
  age                     INTEGER,
  age_range               VARCHAR(20),  -- 18-24, 25-34, 35-44, etc.
  
  -- Household
  marital_status          VARCHAR(20),
  household_size          INTEGER,
  children_present        BOOLEAN,
  homeowner               BOOLEAN,
  home_value_range        VARCHAR(30),
  length_of_residence     INTEGER,  -- Years
  
  -- Education
  education_level         VARCHAR(50),  -- High School, Some College, Bachelor's, etc.
  
  -- Employment
  occupation              VARCHAR(100),
  employer                VARCHAR(200),
  industry                VARCHAR(50),
  job_title               VARCHAR(100),
  employment_status       VARCHAR(20),  -- Employed, Retired, Self-Employed, etc.
  
  -- Income/Wealth
  income_range            VARCHAR(30),
  net_worth_range         VARCHAR(30),
  wealth_tier             VARCHAR(20),  -- Mega, Major, Mid, Grassroots
  
  -- Lifestyle
  religion                VARCHAR(50),
  church_attendance       VARCHAR(20),  -- Weekly, Monthly, Occasional, None
  veteran                 BOOLEAN,
  military_branch         VARCHAR(50),
  gun_owner               BOOLEAN,
  hunter                  BOOLEAN,
  
  -- =========================================================================
  -- CATEGORY 3: VOTER DATA (20 fields)
  -- =========================================================================
  
  -- Registration
  voter_status            VARCHAR(20),  -- Active, Inactive, Unregistered
  party_registration      VARCHAR(20),  -- Republican, Democrat, Unaffiliated
  registration_date       DATE,
  registration_county     VARCHAR(50),
  
  -- Voting History
  vote_2024_general       BOOLEAN,
  vote_2024_primary       BOOLEAN,
  vote_2024_primary_party VARCHAR(20),
  vote_2022_general       BOOLEAN,
  vote_2022_primary       BOOLEAN,
  vote_2020_general       BOOLEAN,
  vote_2020_primary       BOOLEAN,
  vote_2020_primary_party VARCHAR(20),
  vote_2018_general       BOOLEAN,
  vote_2016_general       BOOLEAN,
  vote_2016_primary       BOOLEAN,
  
  -- Vote Score
  general_vote_frequency  INTEGER,  -- Out of last 5 generals
  primary_vote_frequency  INTEGER,  -- Out of last 5 primaries
  r_primary_voter         BOOLEAN,  -- Votes in R primaries
  voter_score             INTEGER CHECK (voter_score BETWEEN 0 AND 100),
  
  -- =========================================================================
  -- CATEGORY 4: GIVING HISTORY - CANDIDATES (30 fields)
  -- =========================================================================
  
  -- Totals
  giving_candidate_lifetime DECIMAL(12,2) DEFAULT 0,
  giving_candidate_ytd    DECIMAL(10,2) DEFAULT 0,
  giving_candidate_last12 DECIMAL(10,2) DEFAULT 0,
  
  -- By Level
  giving_federal_lifetime DECIMAL(12,2) DEFAULT 0,
  giving_federal_ytd      DECIMAL(10,2) DEFAULT 0,
  giving_federal_count    INTEGER DEFAULT 0,
  giving_state_lifetime   DECIMAL(12,2) DEFAULT 0,
  giving_state_ytd        DECIMAL(10,2) DEFAULT 0,
  giving_state_count      INTEGER DEFAULT 0,
  giving_local_lifetime   DECIMAL(12,2) DEFAULT 0,
  giving_local_ytd        DECIMAL(10,2) DEFAULT 0,
  giving_local_count      INTEGER DEFAULT 0,
  
  -- Patterns
  giving_donation_count   INTEGER DEFAULT 0,
  giving_avg_donation     DECIMAL(8,2),
  giving_max_donation     DECIMAL(10,2),
  giving_first_date       DATE,
  giving_last_date        DATE,
  giving_days_since_last  INTEGER,
  giving_frequency        VARCHAR(20),  -- Monthly, Quarterly, Annual, Occasional
  
  -- Candidates Supported
  giving_candidates_supported INTEGER DEFAULT 0,
  giving_candidates_federal INTEGER DEFAULT 0,
  giving_candidates_state INTEGER DEFAULT 0,
  giving_candidates_local INTEGER DEFAULT 0,
  giving_multi_level      BOOLEAN DEFAULT false,  -- Gave Fed + State + Local
  giving_multi_cycle      BOOLEAN DEFAULT false,  -- Gave 3+ consecutive cycles
  
  -- By Election Cycle
  giving_2024_cycle       DECIMAL(10,2) DEFAULT 0,
  giving_2022_cycle       DECIMAL(10,2) DEFAULT 0,
  giving_2020_cycle       DECIMAL(10,2) DEFAULT 0,
  giving_2018_cycle       DECIMAL(10,2) DEFAULT 0,
  giving_history_json     JSONB,  -- Full donation history
  
  -- =========================================================================
  -- CATEGORY 5: GIVING HISTORY - PARTY & PAC (20 fields)
  -- =========================================================================
  
  -- Party Committees
  giving_ncgop_lifetime   DECIMAL(10,2) DEFAULT 0,
  giving_ncgop_ytd        DECIMAL(10,2) DEFAULT 0,
  giving_rnc_lifetime     DECIMAL(10,2) DEFAULT 0,
  giving_rnc_ytd          DECIMAL(10,2) DEFAULT 0,
  giving_nrsc_lifetime    DECIMAL(10,2) DEFAULT 0,
  giving_nrcc_lifetime    DECIMAL(10,2) DEFAULT 0,
  giving_county_gop_lifetime DECIMAL(10,2) DEFAULT 0,
  
  -- PACs
  giving_pac_total        DECIMAL(12,2) DEFAULT 0,
  giving_pac_list         TEXT[],  -- Names of PACs given to
  
  -- Combined Party
  giving_party_lifetime   DECIMAL(12,2) DEFAULT 0,
  giving_party_ytd        DECIMAL(10,2) DEFAULT 0,
  
  -- =========================================================================
  -- CATEGORY 6: GIVING HISTORY - ORGANIZATIONS (25 fields)
  -- =========================================================================
  
  -- Gun Rights
  giving_nra_lifetime     DECIMAL(10,2) DEFAULT 0,
  giving_nra_member       BOOLEAN DEFAULT false,
  giving_nra_last_date    DATE,
  giving_goa_lifetime     DECIMAL(10,2) DEFAULT 0,
  
  -- Pro-Life
  giving_nrlc_lifetime    DECIMAL(10,2) DEFAULT 0,
  giving_sba_list_lifetime DECIMAL(10,2) DEFAULT 0,
  giving_nc_rtl_lifetime  DECIMAL(10,2) DEFAULT 0,
  
  -- Fiscal
  giving_club_growth_lifetime DECIMAL(10,2) DEFAULT 0,
  giving_afp_lifetime     DECIMAL(10,2) DEFAULT 0,  -- Americans for Prosperity
  giving_freedomworks_lifetime DECIMAL(10,2) DEFAULT 0,
  
  -- Other Conservative
  giving_heritage_lifetime DECIMAL(10,2) DEFAULT 0,
  giving_other_conservative DECIMAL(10,2) DEFAULT 0,
  
  -- Organization Totals
  giving_org_lifetime     DECIMAL(12,2) DEFAULT 0,
  giving_org_ytd          DECIMAL(10,2) DEFAULT 0,
  giving_org_count        INTEGER DEFAULT 0,
  giving_org_list         TEXT[],  -- All orgs given to
  giving_org_json         JSONB,  -- Full org giving detail
  
  -- Capacity Indicator
  capacity_flag           VARCHAR(4),  -- A+, A, A-, B+, etc. based on org giving
  capacity_amount         DECIMAL(12,2) DEFAULT 0,  -- Highest single org gift
  capacity_proven         BOOLEAN DEFAULT false,  -- Org giving > Candidate giving
  untapped_potential      DECIMAL(12,2) DEFAULT 0,  -- Org giving - Candidate giving
  
  -- =========================================================================
  -- CATEGORY 7: ISSUE PASSIONS (45 fields - 15 issues × 3)
  -- =========================================================================
  
  -- 2nd Amendment
  issue_2a_intensity      INTEGER CHECK (issue_2a_intensity BETWEEN 1 AND 5),
  issue_2a_source         VARCHAR(20),  -- Survey, Inferred, Behavioral
  issue_2a_confidence     INTEGER CHECK (issue_2a_confidence BETWEEN 0 AND 100),
  
  -- Abortion/Pro-Life
  issue_abortion_intensity INTEGER CHECK (issue_abortion_intensity BETWEEN 1 AND 5),
  issue_abortion_source   VARCHAR(20),
  issue_abortion_confidence INTEGER CHECK (issue_abortion_confidence BETWEEN 0 AND 100),
  
  -- CRT/Education
  issue_crt_intensity     INTEGER CHECK (issue_crt_intensity BETWEEN 1 AND 5),
  issue_crt_source        VARCHAR(20),
  issue_crt_confidence    INTEGER CHECK (issue_crt_confidence BETWEEN 0 AND 100),
  
  -- Election Integrity
  issue_election_intensity INTEGER CHECK (issue_election_intensity BETWEEN 1 AND 5),
  issue_election_source   VARCHAR(20),
  issue_election_confidence INTEGER CHECK (issue_election_confidence BETWEEN 0 AND 100),
  
  -- Immigration/Border
  issue_border_intensity  INTEGER CHECK (issue_border_intensity BETWEEN 1 AND 5),
  issue_border_source     VARCHAR(20),
  issue_border_confidence INTEGER CHECK (issue_border_confidence BETWEEN 0 AND 100),
  
  -- Taxes
  issue_taxes_intensity   INTEGER CHECK (issue_taxes_intensity BETWEEN 1 AND 5),
  issue_taxes_source      VARCHAR(20),
  issue_taxes_confidence  INTEGER CHECK (issue_taxes_confidence BETWEEN 0 AND 100),
  
  -- Government Spending
  issue_spending_intensity INTEGER CHECK (issue_spending_intensity BETWEEN 1 AND 5),
  issue_spending_source   VARCHAR(20),
  issue_spending_confidence INTEGER CHECK (issue_spending_confidence BETWEEN 0 AND 100),
  
  -- Crime/Law Enforcement
  issue_crime_intensity   INTEGER CHECK (issue_crime_intensity BETWEEN 1 AND 5),
  issue_crime_source      VARCHAR(20),
  issue_crime_confidence  INTEGER CHECK (issue_crime_confidence BETWEEN 0 AND 100),
  
  -- Religious Liberty
  issue_religion_intensity INTEGER CHECK (issue_religion_intensity BETWEEN 1 AND 5),
  issue_religion_source   VARCHAR(20),
  issue_religion_confidence INTEGER CHECK (issue_religion_confidence BETWEEN 0 AND 100),
  
  -- Parental Rights
  issue_parental_intensity INTEGER CHECK (issue_parental_intensity BETWEEN 1 AND 5),
  issue_parental_source   VARCHAR(20),
  issue_parental_confidence INTEGER CHECK (issue_parental_confidence BETWEEN 0 AND 100),
  
  -- School Choice
  issue_school_choice_intensity INTEGER CHECK (issue_school_choice_intensity BETWEEN 1 AND 5),
  issue_school_choice_source VARCHAR(20),
  issue_school_choice_confidence INTEGER CHECK (issue_school_choice_confidence BETWEEN 0 AND 100),
  
  -- Energy
  issue_energy_intensity  INTEGER CHECK (issue_energy_intensity BETWEEN 1 AND 5),
  issue_energy_source     VARCHAR(20),
  issue_energy_confidence INTEGER CHECK (issue_energy_confidence BETWEEN 0 AND 100),
  
  -- Healthcare
  issue_healthcare_intensity INTEGER CHECK (issue_healthcare_intensity BETWEEN 1 AND 5),
  issue_healthcare_source VARCHAR(20),
  issue_healthcare_confidence INTEGER CHECK (issue_healthcare_confidence BETWEEN 0 AND 100),
  
  -- Veterans
  issue_veterans_intensity INTEGER CHECK (issue_veterans_intensity BETWEEN 1 AND 5),
  issue_veterans_source   VARCHAR(20),
  issue_veterans_confidence INTEGER CHECK (issue_veterans_confidence BETWEEN 0 AND 100),
  
  -- Agriculture
  issue_agriculture_intensity INTEGER CHECK (issue_agriculture_intensity BETWEEN 1 AND 5),
  issue_agriculture_source VARCHAR(20),
  issue_agriculture_confidence INTEGER CHECK (issue_agriculture_confidence BETWEEN 0 AND 100),
  
  -- =========================================================================
  -- CATEGORY 8: FACTION ALIGNMENT (10 fields)
  -- =========================================================================
  
  faction_trump_maga      INTEGER CHECK (faction_trump_maga BETWEEN 0 AND 100),
  faction_tea_party       INTEGER CHECK (faction_tea_party BETWEEN 0 AND 100),
  faction_establishment   INTEGER CHECK (faction_establishment BETWEEN 0 AND 100),
  faction_libertarian     INTEGER CHECK (faction_libertarian BETWEEN 0 AND 100),
  faction_moderate        INTEGER CHECK (faction_moderate BETWEEN 0 AND 100),
  faction_religious_right INTEGER CHECK (faction_religious_right BETWEEN 0 AND 100),
  
  faction_primary         VARCHAR(30),
  faction_secondary       VARCHAR(30),
  faction_source          VARCHAR(20),  -- Inferred, Survey, Behavioral
  faction_confidence      INTEGER CHECK (faction_confidence BETWEEN 0 AND 100),
  
  -- =========================================================================
  -- CATEGORY 9: ENGAGEMENT (20 fields)
  -- =========================================================================
  
  -- Email
  engagement_email_subscribed BOOLEAN DEFAULT true,
  engagement_email_opens  INTEGER DEFAULT 0,
  engagement_email_sent   INTEGER DEFAULT 0,
  engagement_email_open_rate DECIMAL(5,4),
  engagement_email_clicks INTEGER DEFAULT 0,
  engagement_email_click_rate DECIMAL(5,4),
  engagement_email_last_open DATE,
  
  -- Events
  engagement_events_attended INTEGER DEFAULT 0,
  engagement_events_list  TEXT[],
  engagement_last_event_date DATE,
  
  -- Volunteer
  engagement_volunteered  BOOLEAN DEFAULT false,
  engagement_volunteer_hours DECIMAL(6,1) DEFAULT 0,
  engagement_volunteer_activities TEXT[],
  
  -- Digital
  engagement_website_visits INTEGER DEFAULT 0,
  engagement_social_follows TEXT[],  -- Which platforms
  engagement_petition_signer BOOLEAN DEFAULT false,
  engagement_survey_responder BOOLEAN DEFAULT false,
  
  -- Overall
  engagement_score        INTEGER CHECK (engagement_score BETWEEN 0 AND 100),
  engagement_level        VARCHAR(20),  -- Super, High, Medium, Low, None
  
  -- =========================================================================
  -- CATEGORY 10: SEGMENTS & TAGS (15 fields)
  -- =========================================================================
  
  -- Primary Segments
  segment_primary         VARCHAR(50),
  segment_secondary       VARCHAR(50),
  segment_list            TEXT[],
  
  -- Donor Tags
  tag_major_donor         BOOLEAN DEFAULT false,
  tag_recurring_donor     BOOLEAN DEFAULT false,
  tag_lapsed_donor        BOOLEAN DEFAULT false,
  tag_first_time_donor    BOOLEAN DEFAULT false,
  tag_max_out_risk        BOOLEAN DEFAULT false,  -- Close to FEC max
  tag_bundler             BOOLEAN DEFAULT false,
  
  -- Behavioral Tags
  tag_event_attendee      BOOLEAN DEFAULT false,
  tag_activist            BOOLEAN DEFAULT false,
  tag_influencer          BOOLEAN DEFAULT false,
  
  -- Custom Tags
  tags_custom             TEXT[],
  tags_json               JSONB,
  
  -- =========================================================================
  -- CATEGORY 11: DATA SOURCES (10 fields)
  -- =========================================================================
  
  source_fec              BOOLEAN DEFAULT false,
  source_ncsbe            BOOLEAN DEFAULT false,
  source_l2               BOOLEAN DEFAULT false,
  source_targetsmart      BOOLEAN DEFAULT false,
  source_internal         BOOLEAN DEFAULT false,
  source_enrichment       TEXT[],  -- BetterContact, etc.
  
  data_quality_score      INTEGER CHECK (data_quality_score BETWEEN 0 AND 100),
  last_enriched           TIMESTAMP,
  last_verified           TIMESTAMP,
  
  -- =========================================================================
  -- METADATA
  -- =========================================================================
  
  created_at              TIMESTAMP DEFAULT NOW(),
  updated_at              TIMESTAMP DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' OR email IS NULL)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_donors_county ON donors(county);
CREATE INDEX idx_donors_zip ON donors(zip);
CREATE INDEX idx_donors_email ON donors(email);
CREATE INDEX idx_donors_giving_lifetime ON donors(giving_candidate_lifetime DESC);
CREATE INDEX idx_donors_giving_last ON donors(giving_last_date DESC);
CREATE INDEX idx_donors_capacity ON donors(capacity_flag);
CREATE INDEX idx_donors_faction ON donors(faction_primary);
CREATE INDEX idx_donors_segment ON donors(segment_primary);
CREATE INDEX idx_donors_cd ON donors(congressional_district);
CREATE INDEX idx_donors_nc_senate ON donors(nc_senate_district);
CREATE INDEX idx_donors_nc_house ON donors(nc_house_district);

-- Issue indexes for news triggers
CREATE INDEX idx_donors_issue_2a ON donors(issue_2a_intensity);
CREATE INDEX idx_donors_issue_crt ON donors(issue_crt_intensity);
CREATE INDEX idx_donors_issue_election ON donors(issue_election_intensity);
CREATE INDEX idx_donors_issue_abortion ON donors(issue_abortion_intensity);
CREATE INDEX idx_donors_issue_border ON donors(issue_border_intensity);

-- ============================================================================
-- TRIGGER: Update timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_donor_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER donors_updated
  BEFORE UPDATE ON donors
  FOR EACH ROW
  EXECUTE FUNCTION update_donor_timestamp();
