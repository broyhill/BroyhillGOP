Got it. Now I have the full architecture picture from your platform files. Here is the **complete, untruncated 5-layer Heat Map SQL schema** — starting with `nc_office_tiers` exactly where your GOD file was building it, carried all the way through Layer 5.

------

# The Complete 5-Layer Heat Map Schema

This picks up from `nc_office_tiers` (Layer 1) and builds all the way to the donor-candidate match score engine (Layer 5) — the full schema the GOD file was generating before Perplexity's HTML renderer truncated it.

------

## Layer 1 — `nc_office_tiers`

The foundational classification table. Every other layer foreign-keys into this.

```
sql
-- ============================================================
-- LAYER 1: NC OFFICE TIERS
-- The top of the hierarchy. Every office in NC belongs to one tier.
-- ============================================================

CREATE TABLE nc_office_tiers (
    tier_id         SERIAL PRIMARY KEY,
    tier_code       VARCHAR(10) NOT NULL UNIQUE,  -- FED, COS, GA, JUD, CTY, SCH, MUN, SPC
    tier_name       TEXT NOT NULL,
    tier_level      INTEGER NOT NULL,             -- 1=Federal, 2=Council of State, 3=GA, etc.
    is_partisan     BOOLEAN NOT NULL DEFAULT true,
    fec_regulated   BOOLEAN NOT NULL DEFAULT false,
    ncboe_regulated BOOLEAN NOT NULL DEFAULT true,
    candidate_count_estimate INTEGER,             -- approx # of R candidates per cycle
    notes           TEXT
);

INSERT INTO nc_office_tiers (tier_code, tier_name, tier_level, is_partisan, fec_regulated, ncboe_regulated, candidate_count_estimate, notes) VALUES
('FED',  'Federal',                        1, true,  true,  true,  50,   'US Senate, US House — FEC regulated, NCBOE also tracks'),
('COS',  'Council of State',               2, true,  false, true,  35,   '10 statewide offices: Governor through Supt of Public Instruction'),
('GA',   'General Assembly',               3, true,  false, true,  170,  'NC Senate 50 seats, NC House 120 seats'),
('JUD',  'Judicial',                       4, true,  false, true,  150,  'NC Supreme Court, Court of Appeals, Superior, District — partisan since 2018'),
('CTY',  'County',                         5, true,  false, true,  500,  'County Commissioners, Sheriff, Register of Deeds, Tax Assessor, Clerk'),
('SCH',  'School Board',                   6, true,  false, true,  200,  'County BOE and City BOE — highly evangelical donor activated'),
('MUN',  'Municipal',                      7, true,  false, true,  500,  'Mayor, City/Town Council, Town Board of Commissioners'),
('SPC',  'Special District',               8, false, false, true,  100,  'Soil & Water, Fire District, Sanitary, Hospital, Water/Sewer boards');
```

------

## Layer 2 — `nc_office_types`

One row per distinct office type (17 types across all 8 tiers).

```
sql
-- ============================================================
-- LAYER 2: NC OFFICE TYPES
-- 17 distinct office types — each belongs to one tier.
-- Carries partisan_viability_grade (A/B/C/D/F per region).
-- ============================================================

CREATE TABLE nc_office_types (
    office_id               SERIAL PRIMARY KEY,
    tier_id                 INTEGER NOT NULL REFERENCES nc_office_tiers(tier_id),
    office_code             VARCHAR(20) NOT NULL UNIQUE,
    office_name             TEXT NOT NULL,
    branch                  VARCHAR(15) CHECK (branch IN ('EXECUTIVE','LEGISLATIVE','JUDICIAL','ADMIN')),
    term_years              INTEGER,
    fec_contribution_limit  INTEGER,              -- per-election in dollars; NULL if state-regulated
    ncboe_contribution_limit INTEGER,             -- NC state limit per election cycle
    is_at_large             BOOLEAN DEFAULT false,
    partisan_viability_grade_coastal_rural    CHAR(1),
    partisan_viability_grade_coastal_urban    CHAR(1),
    partisan_viability_grade_piedmont_rural   CHAR(1),
    partisan_viability_grade_piedmont_suburban CHAR(1),
    partisan_viability_grade_piedmont_urban   CHAR(1),
    partisan_viability_grade_appalachian_rural  CHAR(1),
    partisan_viability_grade_appalachian_urban  CHAR(1),
    donor_activation_tier   CHAR(1) CHECK (donor_activation_tier IN ('A','B','C','D')),
    -- A = highest donor mobilization; D = lowest
    primary_donor_archetype VARCHAR(30),          -- dominant segment for this office
    notes                   TEXT
);

INSERT INTO nc_office_types (
    tier_id, office_code, office_name, branch, term_years,
    fec_contribution_limit, ncboe_contribution_limit, is_at_large,
    partisan_viability_grade_coastal_rural, partisan_viability_grade_coastal_urban,
    partisan_viability_grade_piedmont_rural, partisan_viability_grade_piedmont_suburban,
    partisan_viability_grade_piedmont_urban, partisan_viability_grade_appalachian_rural,
    partisan_viability_grade_appalachian_urban,
    donor_activation_tier, primary_donor_archetype, notes
) VALUES

-- FEDERAL
(1,'US_SENATE',     'U.S. Senate',                   'LEGISLATIVE', 6, 3300, NULL, true,  'A','B','A','B','C','A','B', 'A', 'ESTABLISHMENT',   'Two seats; statewide race'),
(1,'US_HOUSE',      'U.S. House of Representatives', 'LEGISLATIVE', 2, 3300, NULL, false, 'A','B','A','B','C','A','B', 'A', 'MAGA',             '14 districts'),

-- COUNCIL OF STATE
(2,'GOVERNOR',      'Governor',                      'EXECUTIVE',   4, NULL, 10400, true, 'A','B','A','B','C','A','B', 'A', 'ESTABLISHMENT',   'Highest-value statewide race'),
(2,'LT_GOV',        'Lieutenant Governor',           'EXECUTIVE',   4, NULL, 10400, true, 'A','B','A','B','C','A','B', 'B', 'ESTABLISHMENT',   ''),
(2,'AG',            'Attorney General',              'EXECUTIVE',   4, NULL, 10400, true, 'A','B','A','B','C','A','B', 'A', 'ESTABLISHMENT',   'High judicial/business donor activation'),
(2,'SOS',           'Secretary of State',            'EXECUTIVE',   4, NULL, 10400, true, 'B','C','B','C','D','B','C', 'C', 'ESTABLISHMENT',   ''),
(2,'STATE_TREAS',   'State Treasurer',               'EXECUTIVE',   4, NULL, 10400, true, 'B','C','B','C','D','B','C', 'B', 'LIBERTARIAN',     'Fiscal hawk donor activation'),
(2,'STATE_AUD',     'State Auditor',                 'EXECUTIVE',   4, NULL, 10400, true, 'B','C','B','C','D','B','C', 'C', 'ESTABLISHMENT',   ''),
(2,'COMM_AGRIC',    'Commissioner of Agriculture',   'EXECUTIVE',   4, NULL, 10400, true, 'A','C','A','C','D','A','C', 'B', 'RURAL_AG',        'Farm Bureau PAC primary donor'),
(2,'COMM_INS',      'Commissioner of Insurance',     'EXECUTIVE',   4, NULL, 10400, true, 'B','C','B','C','D','B','C', 'B', 'HEALTHCARE_PROF',  'Insurance industry activation'),
(2,'COMM_LABOR',    'Commissioner of Labor',         'EXECUTIVE',   4, NULL, 10400, true, 'B','C','B','C','D','B','C', 'C', 'ESTABLISHMENT',   'Business/tort reform angle'),
(2,'SUPT_PI',       'Superintendent of Public Instruction','EXECUTIVE',4,NULL,10400,true, 'A','B','A','B','C','A','B', 'A', 'EVANGELICAL',     'Highest evangelical/parental rights activation of all COS'),

-- GENERAL ASSEMBLY
(3,'NC_SENATE',     'NC Senate',                     'LEGISLATIVE', 2, NULL, 6200, false, 'A','B','A','B','C','A','B', 'B', 'ANTI_WOKE',       '50 districts'),
(3,'NC_HOUSE',      'NC House of Representatives',   'LEGISLATIVE', 2, NULL, 5200, false, 'A','B','A','B','C','A','B', 'B', 'ANTI_WOKE',       '120 districts'),

-- JUDICIAL
(4,'NC_SUP_CT',     'NC Supreme Court',              'JUDICIAL',    8, NULL, 10400, true, 'A','B','A','B','C','A','B', 'A', 'ESTABLISHMENT',   'Highest judicial donor activation; partisan since 2018'),
(4,'NC_CT_APP',     'NC Court of Appeals',           'JUDICIAL',    8, NULL, 5200, false, 'A','B','A','B','C','A','B', 'B', 'ESTABLISHMENT',   '15 judges'),
(4,'SUPERIOR_CT',   'Superior Court Judge',          'JUDICIAL',    8, NULL, 5200, false, 'B','C','B','C','D','B','C', 'B', 'ESTABLISHMENT',   'Prosecutorial district-based'),
(4,'DISTRICT_CT',   'District Court Judge',          'JUDICIAL',    4, NULL, 5200, false, 'B','C','B','C','D','B','C', 'C', 'EVANGELICAL',     'Family court/parental rights angle'),

-- COUNTY
(5,'COUNTY_COMM',   'County Commissioner',           'LEGISLATIVE', 4, NULL, 5200, false, 'A','B','A','B','C','A','B', 'A', 'RURAL_AG',        'Most powerful local body in NC'),
(5,'SHERIFF',       'County Sheriff',                'EXECUTIVE',   4, NULL, 5200, false, 'A','A','A','A','B','A','B', 'A', 'MAGA',            'Highest-intensity local R race'),
(5,'REG_DEEDS',     'Register of Deeds',             'ADMIN',       4, NULL, 5200, false, 'B','C','B','C','D','B','C', 'C', 'ESTABLISHMENT',   'Real estate/title industry activation'),
(5,'TAX_ASSESSOR',  'Tax Assessor / Assessor of Property','ADMIN',  4, NULL, 5200, false, 'B','C','B','C','D','B','C', 'C', 'ESTABLISHMENT',   ''),
(5,'CLERK_SUP_CT',  'Clerk of Superior Court',       'ADMIN',       4, NULL, 5200, false, 'B','C','B','C','D','B','C', 'C', 'ESTABLISHMENT',   'Election integrity association'),

-- SCHOOL BOARD
(6,'COUNTY_BOE',    'County Board of Education',     'LEGISLATIVE', 4, NULL, 1000, false, 'A','A','A','A','B','A','B', 'A', 'EVANGELICAL',     'Highest evangelical activation local race'),
(6,'CITY_BOE',      'City Board of Education',       'LEGISLATIVE', 4, NULL, 1000, false, 'B','A','B','A','C','B','C', 'A', 'EVANGELICAL',     'Charlotte-Mecklenburg, Winston-Salem/Forsyth separate systems'),

-- MUNICIPAL
(7,'MAYOR',         'Mayor',                         'EXECUTIVE',   2, NULL, 1000, true,  'B','B','B','B','C','B','C', 'B', 'ESTABLISHMENT',   'Business/chamber network primary'),
(7,'CITY_COUNCIL',  'City/Town Council Member',      'LEGISLATIVE', 2, NULL, 1000, false, 'B','B','B','B','C','B','C', 'B', 'ESTABLISHMENT',   'Zoning/real estate primary donor'),
(7,'TOWN_COMM',     'Town Board of Commissioners',   'LEGISLATIVE', 2, NULL, 1000, false, 'A','C','A','C','D','A','C', 'C', 'RURAL_AG',        'Rural town governance'),

-- SPECIAL DISTRICT
(8,'SOIL_WATER',    'Soil & Water Conservation District Supervisor','ADMIN',4,NULL,NULL,false,'A','D','A','D','D','A','D','C','RURAL_AG',         'Nearly invisible to urban donors; highest rural ag activation'),
(8,'FIRE_DIST',     'Fire District Commissioner',    'ADMIN',       4, NULL, NULL, false, 'A','C','A','C','D','A','C', 'C', 'DEFENSE_LEO',     'Volunteer fire community activation'),
(8,'HOSP_DIST',     'Hospital District Board',       'ADMIN',       4, NULL, NULL, false, 'B','C','B','C','D','B','C', 'C', 'HEALTHCARE_PROF',  'Rural hospital governance'),
(8,'WATER_SEWER',   'Water & Sewer District Board',  'ADMIN',       4, NULL, NULL, false, 'A','C','A','C','D','A','C', 'C', 'RURAL_AG',        'WOTUS/EPA resistance activation'),
(8,'SANIT_DIST',    'Sanitary District Board',       'ADMIN',       4, NULL, NULL, false, 'B','D','B','D','D','B','D', 'D', 'RURAL_AG',        'Lowest visibility race');
```

------

## Layer 3 — `nc_hot_button_issues` + `nc_office_issue_matrix`

Issues table plus the junction that stores intensity (1–5) per office × geo segment.

```
sql
-- ============================================================
-- LAYER 3A: NC HOT BUTTON ISSUES
-- 42 issues drawn from the CONSERVATIVE_HOT_BUTTON_ISSUES research.
-- ============================================================

CREATE TABLE nc_hot_button_issues (
    issue_id        SERIAL PRIMARY KEY,
    issue_code      VARCHAR(30) NOT NULL UNIQUE,
    issue_name      TEXT NOT NULL,
    issue_family    VARCHAR(30) NOT NULL,          -- CULTURE_WAR, FISCAL, SECURITY, EDUCATION, etc.
    is_federal      BOOLEAN DEFAULT true,
    is_state        BOOLEAN DEFAULT true,
    is_local        BOOLEAN DEFAULT true,
    activates_archetypes TEXT[],                   -- array of archetype codes this issue fires
    notes           TEXT
);

INSERT INTO nc_hot_button_issues (issue_code, issue_name, issue_family, is_federal, is_state, is_local, activates_archetypes) VALUES
-- CULTURE WAR
('PARENTAL_RIGHTS',  'Parental Rights / Curriculum Control',       'CULTURE_WAR',   false, true,  true,  ARRAY['EVANGELICAL','ANTI_WOKE']),
('ANTI_CRT',         'Anti-CRT / Anti-DEI in Schools',             'CULTURE_WAR',   true,  true,  true,  ARRAY['ANTI_WOKE','MAGA']),
('TRANS_ATHLETES',   'Opposition to Transgender Athlete Policies',  'CULTURE_WAR',   true,  true,  true,  ARRAY['EVANGELICAL','ANTI_WOKE','MAGA']),
('GENDER_IDEOLOGY',  'Anti-Gender Ideology in Curriculum',         'CULTURE_WAR',   false, true,  true,  ARRAY['EVANGELICAL','MAGA']),
('LIBRARY_CONTENT',  'Library Book Content Restrictions',          'CULTURE_WAR',   false, false, true,  ARRAY['EVANGELICAL']),
('PRAYER_SCHOOLS',   'Prayer in Schools / Religious Expression',   'CULTURE_WAR',   true,  false, true,  ARRAY['EVANGELICAL']),
('SCHOOL_CHOICE',    'School Choice / Opportunity Scholarships',   'EDUCATION',     true,  true,  true,  ARRAY['EVANGELICAL','LIBERTARIAN']),
-- SECURITY & LAW ENFORCEMENT
('SECOND_AMEND',     'Second Amendment / No Permit Carry',         'SECURITY',      true,  true,  true,  ARRAY['MAGA','DEFENSE_LEO','RURAL_AG']),
('ICE_287G',         'ICE/287(g) Cooperation (Anti-Sanctuary)',    'SECURITY',      false, false, true,  ARRAY['MAGA','DEFENSE_LEO']),
('ANTI_DRUG',        'Anti-Drug Trafficking / Fentanyl Enforcement','SECURITY',     false, false, true,  ARRAY['MAGA','DEFENSE_LEO','EVANGELICAL']),
('BAIL_REFORM',      'Opposition to Bail Reform',                  'SECURITY',      false, true,  true,  ARRAY['MAGA','DEFENSE_LEO','ANTI_WOKE']),
('BORDER_SECURITY',  'Border Security',                            'SECURITY',      true,  false, false, ARRAY['MAGA','DEFENSE_LEO']),
('CONST_SHERIFF',    'Constitutional Sheriff Doctrine',            'SECURITY',      false, false, true,  ARRAY['MAGA','RURAL_AG']),
-- FISCAL
('PROPERTY_TAX',     'Property Tax Rate Control',                  'FISCAL',        false, false, true,  ARRAY['ESTABLISHMENT','RURAL_AG','LIBERTARIAN']),
('ANTI_RENEWABLE',   'Anti-Wind/Solar Farm Siting on Ag Land',     'FISCAL',        false, true,  true,  ARRAY['RURAL_AG','MAGA']),
('CORP_TAX',         'Corporate Tax Cuts / Capital Gains',         'FISCAL',        true,  false, false, ARRAY['ESTABLISHMENT','LIBERTARIAN']),
('SPENDING_CUTS',    'Spending Cuts / Balanced Budget',            'FISCAL',        true,  true,  false, ARRAY['LIBERTARIAN','ESTABLISHMENT']),
('INCOME_TAX_ELIM',  'Income Tax Elimination (NC)',                'FISCAL',        false, true,  false, ARRAY['LIBERTARIAN','ESTABLISHMENT']),
('TORT_REFORM',      'Tort Reform / Business Liability',           'FISCAL',        false, true,  false, ARRAY['ESTABLISHMENT','HEALTHCARE_PROF']),
-- AGRICULTURE & RURAL
('WOTUS',            'WOTUS / Federal Water Regulation Resistance', 'RURAL',        true,  false, true,  ARRAY['RURAL_AG']),
('FARM_BILL',        'Farm Bill / Agricultural Subsidies',         'RURAL',        true,  false, false, ARRAY['RURAL_AG']),
('PROPERTY_RIGHTS',  'Property Rights / Eminent Domain Opposition', 'RURAL',       false, true,  true,  ARRAY['RURAL_AG','LIBERTARIAN']),
('RIGHT_TO_FARM',    'Right-to-Farm Laws',                         'RURAL',        false, true,  false, ARRAY['RURAL_AG']),
('HELENE_RECOVERY',  'Disaster Recovery / Helene Infrastructure',  'RURAL',        true,  true,  true,  ARRAY['RURAL_AG','MAGA']),
-- JUDICIAL
('ORIGINALISM',      'Originalist / Textualist Judicial Philosophy','JUDICIAL',     true,  true,  false, ARRAY['ESTABLISHMENT','EVANGELICAL']),
('TOUGH_ON_CRIME',   'Tough-on-Crime Sentencing',                  'JUDICIAL',     false, false, true,  ARRAY['MAGA','DEFENSE_LEO','ESTABLISHMENT']),
('ANTI_ACTIVIST_JUD','Anti-Activist Judicial Decisions',           'JUDICIAL',     true,  true,  false, ARRAY['ESTABLISHMENT','MAGA']),
-- HEALTHCARE
('ACA_REPEAL',       'ACA Repeal / Replacement',                   'HEALTHCARE',   true,  false, false, ARRAY['HEALTHCARE_PROF','LIBERTARIAN']),
('MEDICAID_OPP',     'Medicaid Expansion Opposition',              'HEALTHCARE',   false, true,  false, ARRAY['LIBERTARIAN','HEALTHCARE_PROF']),
('MALPRACTICE_CAPS', 'Medical Malpractice Caps',                   'HEALTHCARE',   false, true,  false, ARRAY['HEALTHCARE_PROF','ESTABLISHMENT']),
-- SOCIAL / MORAL
('ABORTION_LIFE',    'Abortion / Pro-Life',                        'SOCIAL',       true,  true,  false, ARRAY['EVANGELICAL','MAGA']),
('RELIGIOUS_LIBERTY','Religious Liberty Exemptions',               'SOCIAL',       true,  true,  false, ARRAY['EVANGELICAL']),
('ELECTION_INTEGRITY','Election Integrity / Voter ID',             'SOCIAL',       true,  true,  false, ARRAY['MAGA','ANTI_WOKE']),
-- DEFENSE
('DEFENSE_SPEND',    'Defense Spending / Military',                'DEFENSE',      true,  false, false, ARRAY['DEFENSE_LEO','MAGA']),
('VA_BENEFITS',      'VA Benefits / Veterans',                     'DEFENSE',      true,  false, false, ARRAY['DEFENSE_LEO','MAGA']),
('ANTI_CHINA',       'Anti-China / Russia Hawkishness',            'DEFENSE',      true,  false, false, ARRAY['DEFENSE_LEO','ESTABLISHMENT']),
-- GROWTH / ZONING
('CONTROLLED_GROWTH','Controlled Growth / Anti-Overdevelopment',   'ZONING',       false, false, true,  ARRAY['ESTABLISHMENT','RURAL_AG']),
('STR_RULES',        'Short-Term Rental (Airbnb) Regulation',      'ZONING',       false, false, true,  ARRAY['RURAL_AG','ESTABLISHMENT']),
('ANNEXATION',       'Annexation Resistance',                      'ZONING',       false, false, true,  ARRAY['RURAL_AG','LIBERTARIAN']),
('ANTI_EMINENT',     'Eminent Domain / Property Rights',           'ZONING',       false, true,  true,  ARRAY['LIBERTARIAN','RURAL_AG']),
-- EDUCATION ADMIN
('ANTI_NCAE',        'Anti-NCAE (Teachers Union)',                 'EDUCATION',    false, true,  true,  ARRAY['EVANGELICAL','ANTI_WOKE']),
('SCHOOL_SAFETY',    'School Safety / Resource Officers',          'SECURITY',     false, false, true,  ARRAY['EVANGELICAL','DEFENSE_LEO','MAGA']);


-- ============================================================
-- LAYER 3B: OFFICE × ISSUE INTENSITY MATRIX
-- Stores intensity 1–5 per (office, issue, geo_region, urban_rural)
-- This is the core heat map data — one row per cell.
-- ============================================================

CREATE TABLE nc_office_issue_matrix (
    matrix_id       BIGSERIAL PRIMARY KEY,
    office_id       INTEGER NOT NULL REFERENCES nc_office_types(office_id),
    issue_id        INTEGER NOT NULL REFERENCES nc_hot_button_issues(issue_id),
    geo_region      VARCHAR(15) NOT NULL CHECK (geo_region IN ('COASTAL','PIEDMONT','APPALACHIAN','ALL')),
    urban_rural     VARCHAR(10) NOT NULL CHECK (urban_rural IN ('RURAL','URBAN','SUBURBAN','ALL')),
    intensity       SMALLINT NOT NULL CHECK (intensity BETWEEN 1 AND 5),
    -- 1=Low/Background, 2=Moderate, 3=Significant, 4=Very High, 5=Dominant/Defining
    is_primary_issue BOOLEAN DEFAULT false,   -- marks the top 1–2 issues per office×geo cell
    source_notes    TEXT,
    UNIQUE (office_id, issue_id, geo_region, urban_rural)
);

-- Index for fast heat map rendering
CREATE INDEX idx_oim_office_geo ON nc_office_issue_matrix (office_id, geo_region, urban_rural);
CREATE INDEX idx_oim_issue      ON nc_office_issue_matrix (issue_id);
CREATE INDEX idx_oim_intensity  ON nc_office_issue_matrix (intensity DESC);
```

------

## Layer 4 — `nc_donor_archetypes` + `nc_archetype_issue_weights`

The 8 donor segments with per-issue giving propensity weights.

```
sql
-- ============================================================
-- LAYER 4A: NC DONOR ARCHETYPES
-- 8 segments from the Pew/Cambridge/Bliss Institute research.
-- ============================================================

CREATE TABLE nc_donor_archetypes (
    archetype_id        SERIAL PRIMARY KEY,
    archetype_code      VARCHAR(20) NOT NULL UNIQUE,
    archetype_name      TEXT NOT NULL,
    pct_trump_2024_base DECIMAL(4,1),             -- % of Trump 2024 voter base
    typical_gift_min    INTEGER,                  -- typical donation floor in dollars
    typical_gift_max    INTEGER,                  -- typical donation ceiling
    trigger_type        VARCHAR(20) CHECK (trigger_type IN ('REACTIVE','DELIBERATE','STRATEGIC','RELATIONSHIP')),
    primary_channel     VARCHAR(15) CHECK (primary_channel IN ('WINRED','DIRECT_MAIL','PAC','BUNDLED','CHURCH_NETWORK')),
    federal_priority    VARCHAR(10) CHECK (federal_priority IN ('VERY_HIGH','HIGH','MEDIUM','LOW')),
    state_priority      VARCHAR(10) CHECK (state_priority IN ('VERY_HIGH','HIGH','MEDIUM','LOW')),
    local_priority      VARCHAR(10) CHECK (local_priority IN ('VERY_HIGH','HIGH','MEDIUM','LOW')),
    judicial_priority   VARCHAR(10) CHECK (judicial_priority IN ('VERY_HIGH','HIGH','MEDIUM','LOW')),
    occupation_signals  TEXT[],
    description         TEXT
);

INSERT INTO nc_donor_archetypes (
    archetype_code, archetype_name, pct_trump_2024_base,
    typical_gift_min, typical_gift_max, trigger_type, primary_channel,
    federal_priority, state_priority, local_priority, judicial_priority,
    occupation_signals, description
) VALUES
('MAGA',          'MAGA Hardliners',                    29.0,  25,   100,  'REACTIVE',     'WINRED',
 'VERY_HIGH','MEDIUM','LOW',   'LOW',
 ARRAY['truckers','construction','manufacturing','retail','military','law_enforcement'],
 'Fiercely loyal, deeply religious, animated by civilizational worldview. Almost exclusively small-dollar, high-frequency. Almost never give to local races unless culture-war proxy.'),

('ANTI_WOKE',     'Anti-Woke Conservatives',            25.0,  100,  500,  'DELIBERATE',   'WINRED',
 'HIGH','HIGH','MEDIUM','MEDIUM',
 ARRAY['corporate_managers','hr_professionals','suburban_small_business','media_tech'],
 'Educated, motivated by cultural backlash over Trump loyalty. Mid-range giving, issue-triggered. Will give to candidates they don''t know if cultural framing is strong.'),

('ESTABLISHMENT', 'Establishment / Country Club',        NULL,  1000, 10000,'RELATIONSHIP', 'BUNDLED',
 'HIGH','HIGH','MEDIUM','VERY_HIGH',
 ARRAY['finance_banking','real_estate','healthcare_exec','energy_exec','law_firm_partners'],
 'Traditional pre-Trump GOP. Highest judicial priority. Use LLCs, bundling, spouse giving. Most sophisticated about contribution limits.'),

('LIBERTARIAN',   'Libertarian / Fiscal Hawks',          NULL,  100,  5000, 'DELIBERATE',   'PAC',
 'HIGH','VERY_HIGH','MEDIUM','HIGH',
 ARRAY['tech_entrepreneurs','small_business_professional_svcs','financial_planners','realtors','physicians'],
 'Koch network ecosystem. Policy scorecard driven. Resist authoritarian messaging. Highly active in state legislative races for proximity to fiscal policy.'),

('EVANGELICAL',   'Evangelical / Faith-Based',           NULL,  50,   500,  'DELIBERATE',   'CHURCH_NETWORK',
 'HIGH','VERY_HIGH','VERY_HIGH','VERY_HIGH',
 ARRAY['pastors','christian_school_teachers','stay_at_home_parents','healthcare_pro_life','farming'],
 'Backbone of Southern/Midwestern GOP. Giving adjacent to tithing. Primary driver of school board and county commissioner giving. Most responsive to direct mail + church peer networks.'),

('DEFENSE_LEO',   'Defense / Law Enforcement / Veterans', NULL, 200,  2500, 'RELATIONSHIP', 'PAC',
 'VERY_HIGH','MEDIUM','HIGH','MEDIUM',
 ARRAY['defense_contractors','law_enforcement_unions','first_responders','private_security'],
 'Motivated by national security, law and order. Sheriff elections are single highest-priority local race. Mid-to-large dollar, often via employer PAC.'),

('RURAL_AG',      'Rural / Agricultural / Natural Resource', NULL, 50, 5000,'DELIBERATE',  'PAC',
 'HIGH','HIGH','VERY_HIGH','HIGH',
 ARRAY['farm_bureau','commodity_coop','rural_electric_coop','timber_pulp','mining'],
 'Most active at state/county level. Give in clusters around specific threats. County commission, soil/water boards matter more than Congress to daily life.'),

('HEALTHCARE_PROF','Healthcare / Professional Class',    NULL,  500,  5000, 'STRATEGIC',    'BUNDLED',
 'HIGH','VERY_HIGH','MEDIUM','HIGH',
 ARRAY['physicians','dentists','hospital_exec','pharma','insurance_industry'],
 'Give to state legislative races at higher rates. Physicians are one of top R-giving occupational categories in FEC data. Motivated by scope-of-practice, malpractice, Medicaid.');


-- ============================================================
-- LAYER 4B: ARCHETYPE × ISSUE GIVING WEIGHTS
-- How strongly each archetype responds to each issue (0.0–2.0 multiplier).
-- Used in the match score engine (Layer 5).
-- ============================================================

CREATE TABLE nc_archetype_issue_weights (
    weight_id       SERIAL PRIMARY KEY,
    archetype_id    INTEGER NOT NULL REFERENCES nc_donor_archetypes(archetype_id),
    issue_id        INTEGER NOT NULL REFERENCES nc_hot_button_issues(issue_id),
    weight          DECIMAL(3,2) NOT NULL DEFAULT 1.0 CHECK (weight BETWEEN 0.0 AND 2.0),
    -- 0.0 = this issue repels this donor
    -- 1.0 = neutral / baseline
    -- 2.0 = maximum activation multiplier
    geo_modifier_coastal_rural    DECIMAL(3,2) DEFAULT 1.0,
    geo_modifier_piedmont_suburban DECIMAL(3,2) DEFAULT 1.0,
    geo_modifier_appalachian_rural DECIMAL(3,2) DEFAULT 1.0,
    UNIQUE (archetype_id, issue_id)
);

-- Index for fast weight lookup during scoring
CREATE INDEX idx_aiw_archetype ON nc_archetype_issue_weights (archetype_id);
CREATE INDEX idx_aiw_issue     ON nc_archetype_issue_weights (issue_id);
```

------

## Layer 5 — `nc_donor_candidate_match_scores`

The computed output table — one row per donor × candidate pair, updated by the scoring engine.

```
sql
-- ============================================================
-- LAYER 5: DONOR × CANDIDATE MATCH SCORES
-- The output of the heat map engine. Drives communication triggers.
-- ============================================================

CREATE TABLE nc_donor_candidate_match_scores (
    match_id            BIGSERIAL PRIMARY KEY,
    donor_id            UUID NOT NULL,             -- FK to donors table (E01)
    candidate_id        UUID NOT NULL,             -- FK to candidates table (E03)
    office_id           INTEGER NOT NULL REFERENCES nc_office_types(office_id),
    archetype_id        INTEGER REFERENCES nc_donor_archetypes(archetype_id),
    -- Composite Score Components (each 0–100)
    issue_alignment_score     DECIMAL(5,2),        -- how well donor issues match office issues
    geo_affinity_score        DECIMAL(5,2),        -- donor geography × office geography
    giving_capacity_score     DECIMAL(5,2),        -- donor capacity vs. office typical gift range
    propensity_score          DECIMAL(5,2),        -- DataTrust donorscore (0–100)
    partisan_viability_score  DECIMAL(5,2),        -- office partisan_viability_grade converted 0–100
    -- Composite Output
    composite_match_score     DECIMAL(5,2),        -- weighted average of above 5 components
    match_tier                CHAR(1) CHECK (match_tier IN ('A','B','C','D','F')),
    -- Weights used in scoring run (stored for auditability)
    weight_issue_alignment    DECIMAL(3,2) DEFAULT 0.40,
    weight_geo_affinity       DECIMAL(3,2) DEFAULT 0.20,
    weight_capacity           DECIMAL(3,2) DEFAULT 0.15,
    weight_propensity         DECIMAL(3,2) DEFAULT 0.15,
    weight_viability          DECIMAL(3,2) DEFAULT 0.10,
    -- Metadata
    scored_at               TIMESTAMPTZ DEFAULT NOW(),
    scoring_run_id          UUID,                   -- batch run reference
    top_shared_issues       TEXT[],                 -- top 3 issue codes in common
    recommended_message_template VARCHAR(50),       -- maps to E08 Communications Library
    UNIQUE (donor_id, candidate_id, scoring_run_id)
);

-- Indexes for dashboard queries
CREATE INDEX idx_dcms_donor      ON nc_donor_candidate_match_scores (donor_id);
CREATE INDEX idx_dcms_candidate  ON nc_donor_candidate_match_scores (candidate_id);
CREATE INDEX idx_dcms_tier       ON nc_donor_candidate_match_scores (match_tier);
CREATE INDEX idx_dcms_composite  ON nc_donor_candidate_match_scores (composite_match_score DESC);
CREATE INDEX idx_dcms_office     ON nc_donor_candidate_match_scores (office_id);


-- ============================================================
-- SCORING FUNCTION
-- Called by E01 Donor Intelligence and E20 Intelligence Brain.
-- Recomputes composite_match_score for a donor × candidate pair.
-- ============================================================

CREATE OR REPLACE FUNCTION compute_donor_candidate_match(
    p_donor_id    UUID,
    p_candidate_id UUID
) RETURNS DECIMAL AS $$
DECLARE
    v_office_id             INTEGER;
    v_archetype_id          INTEGER;
    v_issue_alignment       DECIMAL := 0;
    v_geo_affinity          DECIMAL := 0;
    v_capacity              DECIMAL := 0;
    v_propensity            DECIMAL := 0;
    v_viability             DECIMAL := 0;
    v_composite             DECIMAL := 0;
BEGIN
    -- Get candidate's office
    SELECT office_type_id INTO v_office_id
    FROM candidates WHERE id = p_candidate_id;

    -- Get donor's primary archetype
    SELECT archetype_id INTO v_archetype_id
    FROM donor_archetype_assignments WHERE donor_id = p_donor_id
    ORDER BY confidence_score DESC LIMIT 1;

    -- COMPONENT 1: Issue Alignment (40% weight)
    -- Average of (intensity × weight) for all shared issues
    SELECT COALESCE(
        AVG(oim.intensity * aiw.weight) / 5.0 * 100, 0
    ) INTO v_issue_alignment
    FROM nc_office_issue_matrix oim
    JOIN nc_archetype_issue_weights aiw
        ON oim.issue_id = aiw.issue_id
        AND aiw.archetype_id = v_archetype_id
    WHERE oim.office_id = v_office_id
      AND oim.intensity >= 3;   -- only significant-or-higher issues

    -- COMPONENT 2: Geo Affinity (20% weight)
    -- Simplified: match donor county region to office partisan viability grade
    SELECT CASE partisan_viability_grade_piedmont_suburban  -- use actual donor geo in production
        WHEN 'A' THEN 100
        WHEN 'B' THEN 75
        WHEN 'C' THEN 50
        WHEN 'D' THEN 25
        ELSE 10
    END INTO v_geo_affinity
    FROM nc_office_types WHERE office_id = v_office_id;

    -- COMPONENT 3: Capacity Score (15% weight) — from DataTrust donorscore
    SELECT COALESCE(donorscore, 50) INTO v_propensity
    FROM datatrustprofiles WHERE statevoterid = (
        SELECT ncid FROM donors WHERE id = p_donor_id LIMIT 1
    );

    -- COMPONENT 4: Partisan Viability (10% weight) — already captured in geo_affinity
    v_viability := v_geo_affinity;

    -- COMPOSITE
    v_composite :=
        (v_issue_alignment * 0.40) +
        (v_geo_affinity    * 0.20) +
        (v_propensity      * 0.15) +   -- capacity proxy
        (v_propensity      * 0.15) +   -- propensity
        (v_viability       * 0.10);

    RETURN ROUND(v_composite, 2);
END;
$$ LANGUAGE plpgsql;
```

------

## Schema Summary

| Layer | Table(s)                                             | Rows (est.)                     | Purpose                                            |
| :---- | :--------------------------------------------------- | :------------------------------ | :------------------------------------------------- |
| 1     | `nc_office_tiers`                                    | 8                               | Top-level tier classification                      |
| 2     | `nc_office_types`                                    | 30                              | All office types with partisan grades + FEC limits |
| 3     | `nc_hot_button_issues` + `nc_office_issue_matrix`    | 42 issues + ~3,500 matrix cells | Heat map intensity grid                            |
| 4     | `nc_donor_archetypes` + `nc_archetype_issue_weights` | 8 archetypes + ~336 weights     | Donor segment → issue weight mapping               |
| 5     | `nc_donor_candidate_match_scores`                    | Millions (per scoring run)      | Computed match scores feeding E01 + E20            |

The scoring function at the bottom of Layer 5 is what `computeMatchScore(donorId, candidateId)` in the GOD HTML calls — it draws from `nc_office_issue_matrix` (intensity) × `nc_archetype_issue_weights` (weight) and outputs the composite score that drives the heat map cell colors and communication triggers in E20.

Prepared using Claude Sonnet 4.6 Thinking