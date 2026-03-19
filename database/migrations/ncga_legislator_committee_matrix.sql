-- ============================================================================
-- NCGA LEGISLATOR COMMITTEE MATRIX
-- BroyhillGOP Platform — Candidate Ideology via Verifiable Committee Data
-- Generated: 2026-03-15
-- 
-- PURPOSE: Map NC General Assembly legislators to their committee assignments,
-- then derive ideology/faction scores from committee membership. Committee
-- assignments are PUBLIC RECORD from ncleg.gov — fully verifiable.
--
-- ARCHITECTURE:
--   state_legislature.ncga_members        → 170 legislators (50 Senate + 120 House)
--   state_legislature.ncga_committees     → 52 standing committees  
--   state_legislature.ncga_assignments    → ~800 member-committee-role rows
--   state_legislature.committee_faction_map → committee → 12-faction weight matrix
--   state_legislature.legislator_faction_scores → derived scores per legislator
-- ============================================================================

-- SECTION 0: Schema
CREATE SCHEMA IF NOT EXISTS state_legislature;

-- SECTION 1: Members Table
CREATE TABLE IF NOT EXISTS state_legislature.ncga_members (
    member_id    SERIAL PRIMARY KEY,
    full_name    TEXT NOT NULL,
    chamber      TEXT NOT NULL CHECK (chamber IN ('SENATE','HOUSE')),
    district     INT NOT NULL,
    party        TEXT NOT NULL CHECK (party IN ('R','D')),
    county       TEXT,
    status       TEXT DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','RESIGNED','DECEASED','APPOINTED')),
    created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ncga_member_name_chamber 
    ON state_legislature.ncga_members(full_name, chamber);

-- SECTION 2: Committees Table
CREATE TABLE IF NOT EXISTS state_legislature.ncga_committees (
    committee_id   SERIAL PRIMARY KEY,
    committee_name TEXT NOT NULL,
    chamber        TEXT NOT NULL CHECK (chamber IN ('SENATE','HOUSE')),
    ncleg_code     INT,  -- the ID from ncleg.gov URL
    policy_domain  TEXT, -- broad category: AGRICULTURE, FINANCE, JUDICIARY, etc.
    created_at     TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ncga_committee_name_chamber
    ON state_legislature.ncga_committees(committee_name, chamber);

-- SECTION 3: Committee Assignments (the core join table)
CREATE TABLE IF NOT EXISTS state_legislature.ncga_assignments (
    assignment_id  SERIAL PRIMARY KEY,
    member_id      INT NOT NULL REFERENCES state_legislature.ncga_members(member_id),
    committee_id   INT NOT NULL REFERENCES state_legislature.ncga_committees(committee_id),
    role           TEXT NOT NULL DEFAULT 'MEMBER' 
                   CHECK (role IN ('CHAIR','VICE_CHAIR','SENIOR_CHAIR','ADVISORY','MEMBER')),
    session_year   TEXT DEFAULT '2025-2026',
    created_at     TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ncga_assign_member_committee
    ON state_legislature.ncga_assignments(member_id, committee_id);

-- SECTION 4: Committee-to-Faction Weight Matrix
-- Each committee maps to the 12 BroyhillGOP factions with weights 0-100
-- A legislator who CHAIRS Agriculture gets full agriculture weight;
-- a regular member gets 60% weight; these are configurable multipliers.
CREATE TABLE IF NOT EXISTS state_legislature.committee_faction_map (
    map_id         SERIAL PRIMARY KEY,
    committee_id   INT NOT NULL REFERENCES state_legislature.ncga_committees(committee_id),
    maga           INT DEFAULT 0 CHECK (maga BETWEEN 0 AND 100),
    evan           INT DEFAULT 0 CHECK (evan BETWEEN 0 AND 100),
    trad           INT DEFAULT 0 CHECK (trad BETWEEN 0 AND 100),
    fisc           INT DEFAULT 0 CHECK (fisc BETWEEN 0 AND 100),
    libt           INT DEFAULT 0 CHECK (libt BETWEEN 0 AND 100),
    busi           INT DEFAULT 0 CHECK (busi BETWEEN 0 AND 100),
    laws           INT DEFAULT 0 CHECK (laws BETWEEN 0 AND 100),
    popf           INT DEFAULT 0 CHECK (popf BETWEEN 0 AND 100),
    modg           INT DEFAULT 0 CHECK (modg BETWEEN 0 AND 100),
    vets           INT DEFAULT 0 CHECK (vets BETWEEN 0 AND 100),
    chna           INT DEFAULT 0 CHECK (chna BETWEEN 0 AND 100),
    rual           INT DEFAULT 0 CHECK (rual BETWEEN 0 AND 100),
    created_at     TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_cfm_committee
    ON state_legislature.committee_faction_map(committee_id);

-- SECTION 5: Derived Legislator Faction Scores (populated by scoring query)
CREATE TABLE IF NOT EXISTS state_legislature.legislator_faction_scores (
    score_id           SERIAL PRIMARY KEY,
    member_id          INT NOT NULL REFERENCES state_legislature.ncga_members(member_id),
    maga_score         NUMERIC(5,2) DEFAULT 0,
    evan_score         NUMERIC(5,2) DEFAULT 0,
    trad_score         NUMERIC(5,2) DEFAULT 0,
    fisc_score         NUMERIC(5,2) DEFAULT 0,
    libt_score         NUMERIC(5,2) DEFAULT 0,
    busi_score         NUMERIC(5,2) DEFAULT 0,
    laws_score         NUMERIC(5,2) DEFAULT 0,
    popf_score         NUMERIC(5,2) DEFAULT 0,
    modg_score         NUMERIC(5,2) DEFAULT 0,
    vets_score         NUMERIC(5,2) DEFAULT 0,
    chna_score         NUMERIC(5,2) DEFAULT 0,
    rual_score         NUMERIC(5,2) DEFAULT 0,
    primary_faction    TEXT,
    secondary_faction  TEXT,
    tertiary_faction   TEXT,
    committee_count    INT DEFAULT 0,
    chair_count        INT DEFAULT 0,
    calculated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_lfs_member
    ON state_legislature.legislator_faction_scores(member_id);

-- ============================================================================
-- SECTION 6: SEED DATA — NC SENATE MEMBERS (50 seats)
-- Source: ncleg.gov/Members/MemberList/S — scraped 2026-03-15
-- ============================================================================
INSERT INTO state_legislature.ncga_members (full_name, chamber, district, party, county, status)
VALUES
('Gale Adcock', 'SENATE', 16, 'D', 'Wake', 'ACTIVE'),
('W. Ted Alexander', 'SENATE', 44, 'R', 'Cleveland, Gaston, Lincoln', 'ACTIVE'),
('Val Applewhite', 'SENATE', 19, 'D', 'Cumberland', 'ACTIVE'),
('Lisa S. Barnes', 'SENATE', 11, 'R', 'Franklin, Nash, Vance', 'ACTIVE'),
('Sydney Batch', 'SENATE', 17, 'D', 'Wake', 'ACTIVE'),
('Phil Berger', 'SENATE', 26, 'R', 'Guilford, Rockingham', 'ACTIVE'),
('Dan Blue', 'SENATE', 14, 'D', 'Wake', 'ACTIVE'),
('Woodson Bradley', 'SENATE', 42, 'D', 'Mecklenburg', 'ACTIVE'),
('Bob Brinson', 'SENATE', 3, 'R', 'Beaufort, Craven, Lenoir', 'ACTIVE'),
('Danny Earl Britt, Jr.', 'SENATE', 24, 'R', 'Hoke, Robeson, Scotland', 'ACTIVE'),
('Jim Burgin', 'SENATE', 12, 'R', 'Harnett, Lee, Sampson', 'ACTIVE'),
('Jay J. Chaudhuri', 'SENATE', 15, 'D', 'Wake', 'ACTIVE'),
('Sophia Chitlik', 'SENATE', 22, 'D', 'Durham', 'ACTIVE'),
('Kevin Corbin', 'SENATE', 50, 'R', 'Western NC (multiple)', 'ACTIVE'),
('David W. Craven, Jr.', 'SENATE', 29, 'R', 'Anson, Montgomery, Randolph, Richmond, Union', 'ACTIVE'),
('Warren Daniel', 'SENATE', 46, 'R', 'Buncombe, Burke, McDowell', 'ACTIVE'),
('Terence Everitt', 'SENATE', 18, 'D', 'Granville, Wake', 'ACTIVE'),
('Carl Ford', 'SENATE', 33, 'R', 'Rowan, Stanly', 'ACTIVE'),
('Amy S. Galey', 'SENATE', 25, 'R', 'Alamance, Randolph', 'ACTIVE'),
('Michael Garrett', 'SENATE', 27, 'D', 'Guilford', 'ACTIVE'),
('Lisa Grafstein', 'SENATE', 13, 'D', 'Wake', 'ACTIVE'),
('Bobby Hanig', 'SENATE', 1, 'R', 'Coastal NC (multiple)', 'ACTIVE'),
('Ralph Hise', 'SENATE', 47, 'R', 'Mountain NC (multiple)', 'ACTIVE'),
('Mark Hollo', 'SENATE', 45, 'R', 'Caldwell, Catawba', 'ACTIVE'),
('Brent Jackson', 'SENATE', 9, 'R', 'Bladen, Duplin, Jones, Pender, Sampson', 'ACTIVE'),
('Steve Jarvis', 'SENATE', 30, 'R', 'Davidson, Davie', 'ACTIVE'),
('Todd Johnson', 'SENATE', 35, 'R', 'Cabarrus, Union', 'ACTIVE'),
('Dana Jones', 'SENATE', 31, 'R', 'Forsyth, Stokes', 'ACTIVE'),
('Michael A. Lazzara', 'SENATE', 6, 'R', 'Onslow', 'ACTIVE'),
('Michael V. Lee', 'SENATE', 7, 'R', 'New Hanover', 'ACTIVE'),
('Paul A. Lowe, Jr.', 'SENATE', 32, 'D', 'Forsyth', 'ACTIVE'),
('Julie Mayfield', 'SENATE', 49, 'D', 'Buncombe', 'ACTIVE'),
('Tom McInnis', 'SENATE', 21, 'R', 'Cumberland, Moore', 'ACTIVE'),
('Chris Measmer', 'SENATE', 34, 'R', 'Cabarrus', 'APPOINTED'),
('Graig Meyer', 'SENATE', 23, 'D', 'Caswell, Orange, Person', 'ACTIVE'),
('Timothy D. Moffitt', 'SENATE', 48, 'R', 'Henderson, Polk, Rutherford', 'ACTIVE'),
('Mujtaba A. Mohammed', 'SENATE', 38, 'D', 'Mecklenburg', 'ACTIVE'),
('Natalie S. Murdock', 'SENATE', 20, 'D', 'Chatham, Durham', 'ACTIVE'),
('Buck Newton', 'SENATE', 4, 'R', 'Greene, Wayne, Wilson', 'ACTIVE'),
('Brad Overcash', 'SENATE', 43, 'R', 'Gaston', 'ACTIVE'),
('Bill Rabon', 'SENATE', 8, 'R', 'Brunswick, Columbus, New Hanover', 'ACTIVE'),
('Gladys A. Robinson', 'SENATE', 28, 'D', 'Guilford', 'ACTIVE'),
('DeAndrea Salvador', 'SENATE', 39, 'D', 'Mecklenburg', 'ACTIVE'),
('Norman W. Sanderson', 'SENATE', 2, 'R', 'Eastern NC (multiple)', 'ACTIVE'),
('Benton G. Sawrey', 'SENATE', 10, 'R', 'Johnston', 'ACTIVE'),
('Vickie Sawyer', 'SENATE', 37, 'R', 'Iredell, Mecklenburg', 'ACTIVE'),
('Eddie D. Settle', 'SENATE', 36, 'R', 'Alexander, Surry, Wilkes, Yadkin', 'ACTIVE'),
('Kandie D. Smith', 'SENATE', 5, 'D', 'Edgecombe, Pitt', 'ACTIVE'),
('Caleb Theodros', 'SENATE', 41, 'D', 'Mecklenburg', 'ACTIVE'),
('Joyce Waddell', 'SENATE', 40, 'D', 'Mecklenburg', 'ACTIVE')
ON CONFLICT (full_name, chamber) DO NOTHING;

-- ============================================================================
-- SECTION 7: SEED DATA — NC HOUSE MEMBERS (120 seats)
-- Source: ncleg.gov/Members/MemberList/H — scraped 2026-03-15
-- ============================================================================
INSERT INTO state_legislature.ncga_members (full_name, chamber, district, party, county, status)
VALUES
('Jay Adams', 'HOUSE', 96, 'R', 'Catawba', 'ACTIVE'),
('Eric Ager', 'HOUSE', 114, 'D', 'Buncombe', 'ACTIVE'),
('Jonathan L. Almond', 'HOUSE', 73, 'R', 'Cabarrus', 'ACTIVE'),
('Vernetta Alston', 'HOUSE', 29, 'D', 'Durham', 'ACTIVE'),
('Dean Arp', 'HOUSE', 69, 'R', 'Union', 'ACTIVE'),
('Amber M. Baker', 'HOUSE', 72, 'D', 'Forsyth', 'ACTIVE'),
('Jennifer Balkcom', 'HOUSE', 117, 'R', 'Henderson', 'ACTIVE'),
('Cynthia Ball', 'HOUSE', 49, 'D', 'Wake', 'ACTIVE'),
('Mary Belk', 'HOUSE', 88, 'D', 'Mecklenburg', 'ACTIVE'),
('John R. Bell, IV', 'HOUSE', 10, 'R', 'Wayne', 'ACTIVE'),
('Brian Biggs', 'HOUSE', 70, 'R', 'Randolph', 'ACTIVE'),
('Hugh Blackwell', 'HOUSE', 86, 'R', 'Burke', 'ACTIVE'),
('John M. Blust', 'HOUSE', 62, 'R', 'Guilford', 'ACTIVE'),
('Jerry Alan Branson', 'HOUSE', 59, 'R', 'Guilford', 'ACTIVE'),
('William D. Brisson', 'HOUSE', 22, 'R', 'Bladen, Sampson', 'ACTIVE'),
('Cecil Brockman', 'HOUSE', 60, 'D', 'Guilford', 'RESIGNED'),
('Gloristine Brown', 'HOUSE', 8, 'D', 'Pitt', 'ACTIVE'),
('Kanika Brown', 'HOUSE', 71, 'D', 'Forsyth', 'ACTIVE'),
('Terry M. Brown Jr.', 'HOUSE', 92, 'D', 'Mecklenburg', 'ACTIVE'),
('Allen Buansi', 'HOUSE', 56, 'D', 'Orange', 'ACTIVE'),
('Laura Budd', 'HOUSE', 103, 'D', 'Mecklenburg', 'ACTIVE'),
('Deb Butler', 'HOUSE', 18, 'D', 'New Hanover', 'ACTIVE'),
('Celeste C. Cairns', 'HOUSE', 13, 'R', 'Carteret, Craven', 'ACTIVE'),
('Grant L. Campbell, MD', 'HOUSE', 83, 'R', 'Cabarrus, Rowan', 'ACTIVE'),
('Becky Carney', 'HOUSE', 102, 'D', 'Mecklenburg', 'ACTIVE'),
('Todd Carver', 'HOUSE', 95, 'R', 'Iredell', 'ACTIVE'),
('Maria Cervania', 'HOUSE', 41, 'D', 'Wake', 'ACTIVE'),
('Allen Chesser', 'HOUSE', 25, 'R', 'Nash', 'ACTIVE'),
('Mike Clampitt', 'HOUSE', 119, 'R', 'Jackson, Swain, Transylvania', 'ACTIVE'),
('Tracy Clark', 'HOUSE', 57, 'D', 'Guilford', 'ACTIVE'),
('Bryan Cohn', 'HOUSE', 32, 'D', 'Granville, Vance', 'ACTIVE'),
('Mike Colvin', 'HOUSE', 42, 'D', 'Cumberland', 'ACTIVE'),
('Amanda P. Cook', 'HOUSE', 60, 'D', 'Guilford', 'APPOINTED'),
('Tricia Ann Cotham', 'HOUSE', 105, 'R', 'Mecklenburg', 'ACTIVE'),
('Sarah Crawford', 'HOUSE', 66, 'D', 'Wake', 'ACTIVE'),
('Carla D. Cunningham', 'HOUSE', 106, 'D', 'Mecklenburg', 'ACTIVE'),
('Allison A. Dahle', 'HOUSE', 11, 'D', 'Wake', 'ACTIVE'),
('Ted Davis, Jr.', 'HOUSE', 20, 'R', 'New Hanover', 'ACTIVE'),
('Aisha O. Dew', 'HOUSE', 107, 'D', 'Mecklenburg', 'ACTIVE'),
('Jimmy Dixon', 'HOUSE', 4, 'R', 'Duplin, Wayne', 'ACTIVE'),
('Brian Echevarria', 'HOUSE', 82, 'R', 'Cabarrus', 'ACTIVE'),
('Blair Eddins', 'HOUSE', 94, 'R', 'Alexander, Wilkes', 'ACTIVE'),
('Wyatt Gable', 'HOUSE', 14, 'R', 'Onslow', 'ACTIVE'),
('Karl E. Gillespie', 'HOUSE', 120, 'R', 'Cherokee, Clay, Graham, Macon', 'ACTIVE'),
('Edward C. Goodwin', 'HOUSE', 1, 'R', 'Chowan, Currituck, Dare, Perquimans, Tyrrell, Washington', 'ACTIVE'),
('Dudley Greene', 'HOUSE', 85, 'R', 'Avery, McDowell, Mitchell, Yancey', 'ACTIVE'),
('Julia Greenfield', 'HOUSE', 100, 'D', 'Mecklenburg', 'ACTIVE'),
('Destin Hall', 'HOUSE', 87, 'R', 'Caldwell, Watauga', 'ACTIVE'),
('Kyle Hall', 'HOUSE', 91, 'R', 'Forsyth, Stokes', 'ACTIVE'),
('Pricey Harrison', 'HOUSE', 61, 'D', 'Guilford', 'ACTIVE'),
('Kelly E. Hastings', 'HOUSE', 110, 'R', 'Cleveland, Gaston', 'ACTIVE'),
('Zack Hawkins', 'HOUSE', 31, 'D', 'Durham', 'ACTIVE'),
('Beth Helfrich', 'HOUSE', 98, 'D', 'Mecklenburg', 'ACTIVE'),
('Julia C. Howard', 'HOUSE', 77, 'R', 'Davie, Rowan, Yadkin', 'ACTIVE'),
('Chris Humphrey', 'HOUSE', 12, 'R', 'Greene, Jones, Lenoir', 'ACTIVE'),
('Cody Huneycutt', 'HOUSE', 67, 'R', 'Montgomery, Stanly', 'ACTIVE'),
('Frank Iler', 'HOUSE', 17, 'R', 'Brunswick', 'ACTIVE'),
('Frances Jackson, PhD', 'HOUSE', 45, 'D', 'Cumberland', 'ACTIVE'),
('Neal Jackson', 'HOUSE', 78, 'R', 'Moore, Randolph', 'ACTIVE'),
('B. Ray Jeffers', 'HOUSE', 2, 'D', 'Durham, Person', 'ACTIVE'),
('Joe John', 'HOUSE', 40, 'D', 'Wake', 'DECEASED'),
('Jake Johnson', 'HOUSE', 113, 'R', 'Henderson, McDowell, Polk, Rutherford', 'ACTIVE'),
('Monika Johnson-Hostler', 'HOUSE', 33, 'D', 'Wake', 'ACTIVE'),
('Abe Jones', 'HOUSE', 38, 'D', 'Wake', 'ACTIVE'),
('Brenden H. Jones', 'HOUSE', 46, 'R', 'Columbus, Robeson', 'ACTIVE'),
('Keith Kidwell', 'HOUSE', 79, 'R', 'Beaufort, Dare, Hyde, Pamlico', 'ACTIVE'),
('Donny Lambeth', 'HOUSE', 75, 'R', 'Forsyth', 'ACTIVE'),
('Ya Liu', 'HOUSE', 21, 'D', 'Wake', 'ACTIVE'),
('Donnie Loftis', 'HOUSE', 109, 'R', 'Gaston', 'ACTIVE'),
('Brandon Lofton', 'HOUSE', 104, 'D', 'Mecklenburg', 'ACTIVE'),
('Carolyn G. Logan', 'HOUSE', 101, 'D', 'Mecklenburg', 'ACTIVE'),
('Tim Longest', 'HOUSE', 34, 'D', 'Wake', 'ACTIVE'),
('Jordan Lopez', 'HOUSE', 112, 'D', 'Mecklenburg', 'ACTIVE'),
('Jarrod Lowery', 'HOUSE', 47, 'R', 'Robeson', 'RESIGNED'),
('John L. Lowery', 'HOUSE', 47, 'R', 'Robeson', 'APPOINTED'),
('Nasif Majeed', 'HOUSE', 99, 'D', 'Mecklenburg', 'ACTIVE'),
('Jeffrey C. McNeely', 'HOUSE', 84, 'R', 'Iredell', 'ACTIVE'),
('Charles W. Miller', 'HOUSE', 19, 'R', 'Brunswick, New Hanover', 'ACTIVE'),
('Marcia Morey', 'HOUSE', 30, 'D', 'Durham', 'ACTIVE'),
('Ben T. Moss, Jr.', 'HOUSE', 52, 'R', 'Moore, Richmond', 'ACTIVE'),
('Erin Pare', 'HOUSE', 37, 'R', 'Wake', 'ACTIVE'),
('Howard Penny, Jr.', 'HOUSE', 53, 'R', 'Harnett, Johnston', 'ACTIVE'),
('Ray Pickett', 'HOUSE', 93, 'R', 'Alleghany, Ashe, Watauga', 'ACTIVE'),
('Garland E. Pierce', 'HOUSE', 48, 'D', 'Hoke, Scotland', 'ACTIVE'),
('Rodney D. Pierce', 'HOUSE', 27, 'D', 'Halifax, Northampton, Warren', 'ACTIVE'),
('Joseph Pike', 'HOUSE', 6, 'R', 'Harnett', 'ACTIVE'),
('Dante Pittman', 'HOUSE', 24, 'D', 'Nash, Wilson', 'ACTIVE'),
('Mark Pless', 'HOUSE', 118, 'R', 'Haywood, Madison', 'ACTIVE'),
('Larry W. Potts', 'HOUSE', 81, 'R', 'Davidson', 'ACTIVE'),
('Lindsey Prather', 'HOUSE', 115, 'D', 'Buncombe', 'ACTIVE'),
('Renee A. Price', 'HOUSE', 50, 'D', 'Caswell, Orange', 'ACTIVE'),
('A. Reece Pyrtle, Jr.', 'HOUSE', 65, 'R', 'Rockingham', 'ACTIVE'),
('Amos L. Quick, III', 'HOUSE', 58, 'D', 'Guilford', 'ACTIVE'),
('Timothy Reeder, MD', 'HOUSE', 9, 'R', 'Pitt', 'ACTIVE'),
('Robert T. Reives, II', 'HOUSE', 54, 'D', 'Chatham, Randolph', 'ACTIVE'),
('Heather H. Rhyne', 'HOUSE', 97, 'R', 'Lincoln', 'ACTIVE'),
('Dennis Riddell', 'HOUSE', 65, 'R', 'Alamance', 'ACTIVE'),
('James Roberson', 'HOUSE', 39, 'D', 'Wake', 'ACTIVE'),
('Stephen M. Ross', 'HOUSE', 63, 'R', 'Alamance', 'ACTIVE'),
('Phil Rubin', 'HOUSE', 40, 'D', 'Wake', 'APPOINTED'),
('John Sauls', 'HOUSE', 51, 'R', 'Lee, Moore', 'ACTIVE'),
('Mike Schietzelt', 'HOUSE', 35, 'R', 'Wake', 'ACTIVE'),
('Paul Scott', 'HOUSE', 111, 'R', 'Cleveland, Rutherford', 'ACTIVE'),
('Mitchell S. Setzer', 'HOUSE', 89, 'R', 'Catawba, Iredell', 'ACTIVE'),
('Phil Shepard', 'HOUSE', 15, 'R', 'Onslow', 'ACTIVE'),
('Carson Smith', 'HOUSE', 16, 'R', 'Onslow, Pender', 'ACTIVE'),
('Charles Smith', 'HOUSE', 44, 'D', 'Cumberland', 'ACTIVE'),
('Sarah Stevens', 'HOUSE', 90, 'R', 'Surry, Wilkes', 'ACTIVE'),
('Larry C. Strickland', 'HOUSE', 28, 'R', 'Johnston', 'ACTIVE'),
('John A. Torbett', 'HOUSE', 108, 'R', 'Gaston', 'ACTIVE'),
('Brian Turner', 'HOUSE', 116, 'D', 'Buncombe', 'ACTIVE'),
('Steve Tyson', 'HOUSE', 3, 'R', 'Craven', 'ACTIVE'),
('Julie von Haefen', 'HOUSE', 36, 'D', 'Wake', 'ACTIVE'),
('Bill Ward', 'HOUSE', 5, 'R', 'Camden, Gates, Hertford, Pasquotank', 'ACTIVE'),
('Harry Warren', 'HOUSE', 76, 'R', 'Rowan', 'ACTIVE'),
('Sam Watford', 'HOUSE', 80, 'R', 'Davidson', 'ACTIVE'),
('Diane Wheatley', 'HOUSE', 43, 'R', 'Cumberland', 'ACTIVE'),
('Donna McDowell White', 'HOUSE', 26, 'R', 'Johnston', 'ACTIVE'),
('Shelly Willingham', 'HOUSE', 23, 'D', 'Bertie, Edgecombe, Martin', 'ACTIVE'),
('David Willis', 'HOUSE', 68, 'R', 'Union', 'ACTIVE'),
('Matthew Winslow', 'HOUSE', 7, 'R', 'Franklin, Vance', 'ACTIVE'),
('Jeff Zenger', 'HOUSE', 74, 'R', 'Forsyth', 'ACTIVE'),
('Mark Brody', 'HOUSE', 55, 'R', 'Anson, Union', 'ACTIVE')
ON CONFLICT (full_name, chamber) DO NOTHING;

-- ============================================================================
-- SECTION 8: SEED DATA — COMMITTEES (19 Senate + 33 House = 52)
-- ============================================================================
INSERT INTO state_legislature.ncga_committees (committee_name, chamber, ncleg_code, policy_domain)
VALUES
-- SENATE COMMITTEES
('Agriculture, Energy, and Environment', 'SENATE', 1162, 'AGRICULTURE'),
('Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 145, 'AGRICULTURE'),
('Appropriations on Department of Transportation', 'SENATE', 140, 'TRANSPORTATION'),
('Appropriations on Education/Higher Education', 'SENATE', 141, 'EDUCATION'),
('Appropriations on General Government and Information Technology', 'SENATE', 142, 'GOVERNMENT'),
('Appropriations on Health and Human Services', 'SENATE', 143, 'HEALTH'),
('Appropriations on Justice and Public Safety', 'SENATE', 144, 'JUDICIARY'),
('Appropriations/Base Budget', 'SENATE', 136, 'FINANCE'),
('Commerce and Insurance', 'SENATE', 137, 'BUSINESS'),
('Education/Higher Education', 'SENATE', 134, 'EDUCATION'),
('Elections', 'SENATE', 154, 'ELECTIONS'),
('Finance', 'SENATE', 138, 'FINANCE'),
('Health Care', 'SENATE', 139, 'HEALTH'),
('Judiciary', 'SENATE', 147, 'JUDICIARY'),
('Pensions and Retirement and Aging', 'SENATE', 153, 'GOVERNMENT'),
('Regulatory Reform', 'SENATE', 1166, 'BUSINESS'),
('Rules and Operations of the Senate', 'SENATE', 148, 'LEADERSHIP'),
('State and Local Government', 'SENATE', 149, 'GOVERNMENT'),
('Transportation', 'SENATE', 150, 'TRANSPORTATION'),
-- HOUSE COMMITTEES
('Agriculture and Environment', 'HOUSE', 225, 'AGRICULTURE'),
('Alcoholic Beverage Control', 'HOUSE', 4, 'BUSINESS'),
('Appropriations', 'HOUSE', 6, 'FINANCE'),
('Appropriations, Agriculture and Natural and Economic Resources', 'HOUSE', 12, 'AGRICULTURE'),
('Appropriations, Capital and Information Technology', 'HOUSE', 227, 'GOVERNMENT'),
('Appropriations, Education', 'HOUSE', 7, 'EDUCATION'),
('Appropriations, General Government', 'HOUSE', 9, 'GOVERNMENT'),
('Appropriations, Health and Human Services', 'HOUSE', 10, 'HEALTH'),
('Appropriations, Justice and Public Safety', 'HOUSE', 11, 'JUDICIARY'),
('Appropriations, Transportation', 'HOUSE', 13, 'TRANSPORTATION'),
('Commerce and Economic Development', 'HOUSE', 16, 'BUSINESS'),
('Education - K-12', 'HOUSE', 166, 'EDUCATION'),
('Election Law', 'HOUSE', 21, 'ELECTIONS'),
('Emergency Management and Disaster Recovery', 'HOUSE', 212, 'EMERGENCY'),
('Energy and Public Utilities', 'HOUSE', 40, 'ENERGY'),
('Ethics', 'HOUSE', 23, 'LEADERSHIP'),
('Federal Relations and American Indian Affairs', 'HOUSE', 206, 'GOVERNMENT'),
('Finance', 'HOUSE', 24, 'FINANCE'),
('Health', 'HOUSE', 26, 'HEALTH'),
('Higher Education', 'HOUSE', 226, 'EDUCATION'),
('Homeland Security and Military and Veterans Affairs', 'HOUSE', 94, 'MILITARY'),
('Housing and Development', 'HOUSE', 207, 'DEVELOPMENT'),
('Insurance', 'HOUSE', 28, 'INSURANCE'),
('Judiciary 1', 'HOUSE', 35, 'JUDICIARY'),
('Judiciary 2', 'HOUSE', 202, 'JUDICIARY'),
('Judiciary 3', 'HOUSE', 194, 'JUDICIARY'),
('Oversight', 'HOUSE', 213, 'GOVERNMENT'),
('Pensions and Retirement', 'HOUSE', 169, 'GOVERNMENT'),
('Regulatory Reform', 'HOUSE', 133, 'BUSINESS'),
('Rules, Calendar, and Operations of the House', 'HOUSE', 2, 'LEADERSHIP'),
('State and Local Government', 'HOUSE', 228, 'GOVERNMENT'),
('Transportation', 'HOUSE', 45, 'TRANSPORTATION'),
('Wildlife Resources', 'HOUSE', 162, 'WILDLIFE')
ON CONFLICT (committee_name, chamber) DO NOTHING;

-- ============================================================================
-- SECTION 9: COMMITTEE-TO-FACTION WEIGHT MATRIX
-- This is the interpretive layer: each committee maps to faction weights.
-- Chair = full weight. Vice Chair = 80%. Member = 60%.
-- 
-- KEY INSIGHT: A legislator on Agriculture IS agriculture-priority.
-- A legislator on Insurance IS insurance special interest.
-- Committee assignments are PUBLIC RECORD — fully verifiable.
-- ============================================================================
INSERT INTO state_legislature.committee_faction_map (committee_id, maga, evan, trad, fisc, libt, busi, laws, popf, modg, vets, chna, rual)
SELECT c.committee_id,
    CASE c.policy_domain
        WHEN 'AGRICULTURE' THEN 10
        WHEN 'ELECTIONS' THEN 30
        ELSE 5
    END, -- maga
    CASE c.policy_domain
        WHEN 'EDUCATION' THEN 40
        WHEN 'HEALTH' THEN 20
        ELSE 5
    END, -- evan
    CASE c.policy_domain
        WHEN 'JUDICIARY' THEN 70
        WHEN 'LEADERSHIP' THEN 50
        WHEN 'ELECTIONS' THEN 40
        ELSE 15
    END, -- trad (traditional values / institutional power)
    CASE c.policy_domain
        WHEN 'FINANCE' THEN 80
        WHEN 'BUSINESS' THEN 60
        WHEN 'INSURANCE' THEN 60
        ELSE 15
    END, -- fisc (fiscal conservative)
    CASE c.policy_domain
        WHEN 'BUSINESS' THEN 30
        WHEN 'ENERGY' THEN 25
        ELSE 10
    END, -- libt (libertarian)
    CASE c.policy_domain
        WHEN 'BUSINESS' THEN 90
        WHEN 'FINANCE' THEN 75
        WHEN 'INSURANCE' THEN 85
        WHEN 'ENERGY' THEN 70
        WHEN 'TRANSPORTATION' THEN 60
        WHEN 'DEVELOPMENT' THEN 65
        ELSE 15
    END, -- busi (business special interest / pay to play)
    CASE c.policy_domain
        WHEN 'JUDICIARY' THEN 85
        WHEN 'ELECTIONS' THEN 50
        ELSE 10
    END, -- laws (law and order)
    CASE c.policy_domain
        WHEN 'ELECTIONS' THEN 40
        WHEN 'EMERGENCY' THEN 30
        ELSE 5
    END, -- popf (populist firebrand)
    CASE c.policy_domain
        WHEN 'TRANSPORTATION' THEN 50
        WHEN 'DEVELOPMENT' THEN 60
        WHEN 'GOVERNMENT' THEN 40
        WHEN 'HEALTH' THEN 35
        ELSE 10
    END, -- modg (moderate / big city infrastructure)
    CASE c.policy_domain
        WHEN 'MILITARY' THEN 95
        WHEN 'EMERGENCY' THEN 40
        ELSE 5
    END, -- vets (veterans / military)
    CASE c.policy_domain
        WHEN 'ENERGY' THEN 30
        WHEN 'BUSINESS' THEN 25
        ELSE 5
    END, -- chna (China hawk / trade)
    CASE c.policy_domain
        WHEN 'AGRICULTURE' THEN 95
        WHEN 'WILDLIFE' THEN 80
        WHEN 'EMERGENCY' THEN 40
        ELSE 10
    END  -- rual (rural interests)
FROM state_legislature.ncga_committees c
ON CONFLICT (committee_id) DO NOTHING;

-- ============================================================================
-- SECTION 10: COMMITTEE ASSIGNMENTS — NC SENATE
-- Source: ncleg.gov committee roster pages — scraped 2026-03-15
-- Role: CHAIR, VICE_CHAIR, ADVISORY, MEMBER
-- ============================================================================
-- Helper: INSERT assignment using name lookups (no hardcoded IDs)
-- Format: (member_name, committee_name, chamber, role)

INSERT INTO state_legislature.ncga_assignments (member_id, committee_id, role)
SELECT m.member_id, c.committee_id, v.role
FROM (VALUES
-- Senate: Agriculture, Energy, and Environment
('Lisa S. Barnes', 'Agriculture, Energy, and Environment', 'SENATE', 'CHAIR'),
('Brent Jackson', 'Agriculture, Energy, and Environment', 'SENATE', 'CHAIR'),
('Norman W. Sanderson', 'Agriculture, Energy, and Environment', 'SENATE', 'CHAIR'),
('Bob Brinson', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Jim Burgin', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Jay J. Chaudhuri', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('David W. Craven, Jr.', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Michael Garrett', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Lisa Grafstein', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Bobby Hanig', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Steve Jarvis', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Julie Mayfield', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Tom McInnis', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Chris Measmer', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Natalie S. Murdock', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Buck Newton', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Bill Rabon', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('DeAndrea Salvador', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Eddie D. Settle', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
('Kandie D. Smith', 'Agriculture, Energy, and Environment', 'SENATE', 'MEMBER'),
-- Senate: Appropriations on Ag, Natural, and Economic Resources
('Lisa S. Barnes', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'CHAIR'),
('Todd Johnson', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'CHAIR'),
('Norman W. Sanderson', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'CHAIR'),
('Bob Brinson', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'MEMBER'),
('Paul A. Lowe, Jr.', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'MEMBER'),
('Julie Mayfield', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'MEMBER'),
('Timothy D. Moffitt', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'MEMBER'),
('DeAndrea Salvador', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'MEMBER'),
('Eddie D. Settle', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'MEMBER'),
('Kandie D. Smith', 'Appropriations on Agriculture, Natural, and Economic Resources', 'SENATE', 'MEMBER'),
-- Senate: Appropriations on Dept of Transportation
('Michael A. Lazzara', 'Appropriations on Department of Transportation', 'SENATE', 'CHAIR'),
('Bill Rabon', 'Appropriations on Department of Transportation', 'SENATE', 'CHAIR'),
('Vickie Sawyer', 'Appropriations on Department of Transportation', 'SENATE', 'CHAIR'),
('Michael Garrett', 'Appropriations on Department of Transportation', 'SENATE', 'MEMBER'),
('Mark Hollo', 'Appropriations on Department of Transportation', 'SENATE', 'MEMBER'),
('Natalie S. Murdock', 'Appropriations on Department of Transportation', 'SENATE', 'MEMBER'),
('Caleb Theodros', 'Appropriations on Department of Transportation', 'SENATE', 'MEMBER'),
-- Senate: Appropriations on Education/Higher Education
('Kevin Corbin', 'Appropriations on Education/Higher Education', 'SENATE', 'CHAIR'),
('Brad Overcash', 'Appropriations on Education/Higher Education', 'SENATE', 'CHAIR'),
('Val Applewhite', 'Appropriations on Education/Higher Education', 'SENATE', 'MEMBER'),
('Jay J. Chaudhuri', 'Appropriations on Education/Higher Education', 'SENATE', 'MEMBER'),
('Sophia Chitlik', 'Appropriations on Education/Higher Education', 'SENATE', 'MEMBER'),
('David W. Craven, Jr.', 'Appropriations on Education/Higher Education', 'SENATE', 'MEMBER'),
('Dana Jones', 'Appropriations on Education/Higher Education', 'SENATE', 'MEMBER'),
('Joyce Waddell', 'Appropriations on Education/Higher Education', 'SENATE', 'MEMBER'),
-- Senate: Appropriations on General Government and IT
('W. Ted Alexander', 'Appropriations on General Government and Information Technology', 'SENATE', 'CHAIR'),
('Carl Ford', 'Appropriations on General Government and Information Technology', 'SENATE', 'CHAIR'),
('Bobby Hanig', 'Appropriations on General Government and Information Technology', 'SENATE', 'CHAIR'),
('Woodson Bradley', 'Appropriations on General Government and Information Technology', 'SENATE', 'MEMBER'),
('Terence Everitt', 'Appropriations on General Government and Information Technology', 'SENATE', 'MEMBER'),
('Steve Jarvis', 'Appropriations on General Government and Information Technology', 'SENATE', 'MEMBER'),
('Chris Measmer', 'Appropriations on General Government and Information Technology', 'SENATE', 'MEMBER'),
('Graig Meyer', 'Appropriations on General Government and Information Technology', 'SENATE', 'MEMBER'),
-- Senate: Appropriations on Health and Human Services
('Jim Burgin', 'Appropriations on Health and Human Services', 'SENATE', 'CHAIR'),
('Amy S. Galey', 'Appropriations on Health and Human Services', 'SENATE', 'CHAIR'),
('Benton G. Sawrey', 'Appropriations on Health and Human Services', 'SENATE', 'CHAIR'),
('Gale Adcock', 'Appropriations on Health and Human Services', 'SENATE', 'MEMBER'),
('Dan Blue', 'Appropriations on Health and Human Services', 'SENATE', 'MEMBER'),
('Kevin Corbin', 'Appropriations on Health and Human Services', 'SENATE', 'MEMBER'),
('Gladys A. Robinson', 'Appropriations on Health and Human Services', 'SENATE', 'MEMBER'),
-- Senate: Appropriations on Justice and Public Safety
('Danny Earl Britt, Jr.', 'Appropriations on Justice and Public Safety', 'SENATE', 'CHAIR'),
('Warren Daniel', 'Appropriations on Justice and Public Safety', 'SENATE', 'CHAIR'),
('Buck Newton', 'Appropriations on Justice and Public Safety', 'SENATE', 'CHAIR'),
('Sydney Batch', 'Appropriations on Justice and Public Safety', 'SENATE', 'MEMBER'),
('Lisa Grafstein', 'Appropriations on Justice and Public Safety', 'SENATE', 'MEMBER'),
('Mujtaba A. Mohammed', 'Appropriations on Justice and Public Safety', 'SENATE', 'MEMBER'),
('Norman W. Sanderson', 'Appropriations on Justice and Public Safety', 'SENATE', 'MEMBER'),
-- Senate: Appropriations/Base Budget
('Ralph Hise', 'Appropriations/Base Budget', 'SENATE', 'CHAIR'),
('Brent Jackson', 'Appropriations/Base Budget', 'SENATE', 'CHAIR'),
('Michael V. Lee', 'Appropriations/Base Budget', 'SENATE', 'CHAIR'),
('W. Ted Alexander', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Val Applewhite', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Lisa S. Barnes', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Sydney Batch', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Dan Blue', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Danny Earl Britt, Jr.', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Jim Burgin', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Kevin Corbin', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Warren Daniel', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Carl Ford', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Amy S. Galey', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Lisa Grafstein', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Steve Jarvis', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Paul A. Lowe, Jr.', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Graig Meyer', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Natalie S. Murdock', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Bill Rabon', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Gladys A. Robinson', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Norman W. Sanderson', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Benton G. Sawrey', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Vickie Sawyer', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
('Joyce Waddell', 'Appropriations/Base Budget', 'SENATE', 'MEMBER'),
-- Senate: Commerce and Insurance
('Danny Earl Britt, Jr.', 'Commerce and Insurance', 'SENATE', 'CHAIR'),
('Todd Johnson', 'Commerce and Insurance', 'SENATE', 'CHAIR'),
('Eddie D. Settle', 'Commerce and Insurance', 'SENATE', 'CHAIR'),
('Gale Adcock', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('W. Ted Alexander', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Sydney Batch', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Dan Blue', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Jay J. Chaudhuri', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Kevin Corbin', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('David W. Craven, Jr.', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Michael Garrett', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Mark Hollo', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Brent Jackson', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Steve Jarvis', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Michael V. Lee', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Paul A. Lowe, Jr.', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Tom McInnis', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Graig Meyer', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Timothy D. Moffitt', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Brad Overcash', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('DeAndrea Salvador', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
('Vickie Sawyer', 'Commerce and Insurance', 'SENATE', 'MEMBER'),
-- Senate: Education/Higher Education
('Kevin Corbin', 'Education/Higher Education', 'SENATE', 'CHAIR'),
('Michael V. Lee', 'Education/Higher Education', 'SENATE', 'CHAIR'),
('Brad Overcash', 'Education/Higher Education', 'SENATE', 'CHAIR'),
('Lisa S. Barnes', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Woodson Bradley', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Bob Brinson', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Jay J. Chaudhuri', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Sophia Chitlik', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Amy S. Galey', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Michael Garrett', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Bobby Hanig', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Mark Hollo', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Dana Jones', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Tom McInnis', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Buck Newton', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Gladys A. Robinson', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Norman W. Sanderson', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Kandie D. Smith', 'Education/Higher Education', 'SENATE', 'MEMBER'),
('Caleb Theodros', 'Education/Higher Education', 'SENATE', 'MEMBER'),
-- Senate: Elections
('Warren Daniel', 'Elections', 'SENATE', 'CHAIR'),
('Ralph Hise', 'Elections', 'SENATE', 'CHAIR'),
('Brad Overcash', 'Elections', 'SENATE', 'CHAIR'),
('W. Ted Alexander', 'Elections', 'SENATE', 'MEMBER'),
('Sydney Batch', 'Elections', 'SENATE', 'MEMBER'),
('Carl Ford', 'Elections', 'SENATE', 'MEMBER'),
('Amy S. Galey', 'Elections', 'SENATE', 'MEMBER'),
('Brent Jackson', 'Elections', 'SENATE', 'MEMBER'),
('Todd Johnson', 'Elections', 'SENATE', 'MEMBER'),
('Paul A. Lowe, Jr.', 'Elections', 'SENATE', 'MEMBER'),
('Julie Mayfield', 'Elections', 'SENATE', 'MEMBER'),
('Mujtaba A. Mohammed', 'Elections', 'SENATE', 'MEMBER'),
('Bill Rabon', 'Elections', 'SENATE', 'MEMBER'),
('Gladys A. Robinson', 'Elections', 'SENATE', 'MEMBER'),
('Benton G. Sawrey', 'Elections', 'SENATE', 'MEMBER'),
('Kandie D. Smith', 'Elections', 'SENATE', 'MEMBER'),
-- Senate: Finance
('David W. Craven, Jr.', 'Finance', 'SENATE', 'CHAIR'),
('Tom McInnis', 'Finance', 'SENATE', 'CHAIR'),
('Gale Adcock', 'Finance', 'SENATE', 'MEMBER'),
('W. Ted Alexander', 'Finance', 'SENATE', 'MEMBER'),
('Val Applewhite', 'Finance', 'SENATE', 'MEMBER'),
('Sydney Batch', 'Finance', 'SENATE', 'MEMBER'),
('Dan Blue', 'Finance', 'SENATE', 'MEMBER'),
('Jim Burgin', 'Finance', 'SENATE', 'MEMBER'),
('Warren Daniel', 'Finance', 'SENATE', 'MEMBER'),
('Carl Ford', 'Finance', 'SENATE', 'MEMBER'),
('Ralph Hise', 'Finance', 'SENATE', 'MEMBER'),
('Brent Jackson', 'Finance', 'SENATE', 'MEMBER'),
('Todd Johnson', 'Finance', 'SENATE', 'MEMBER'),
('Michael A. Lazzara', 'Finance', 'SENATE', 'MEMBER'),
('Paul A. Lowe, Jr.', 'Finance', 'SENATE', 'MEMBER'),
('Timothy D. Moffitt', 'Finance', 'SENATE', 'MEMBER'),
('Mujtaba A. Mohammed', 'Finance', 'SENATE', 'MEMBER'),
('Natalie S. Murdock', 'Finance', 'SENATE', 'MEMBER'),
('Buck Newton', 'Finance', 'SENATE', 'MEMBER'),
('Brad Overcash', 'Finance', 'SENATE', 'MEMBER'),
('Bill Rabon', 'Finance', 'SENATE', 'MEMBER'),
('DeAndrea Salvador', 'Finance', 'SENATE', 'MEMBER'),
('Vickie Sawyer', 'Finance', 'SENATE', 'MEMBER'),
('Joyce Waddell', 'Finance', 'SENATE', 'MEMBER'),
-- Senate: Health Care
('Jim Burgin', 'Health Care', 'SENATE', 'CHAIR'),
('Amy S. Galey', 'Health Care', 'SENATE', 'CHAIR'),
('Benton G. Sawrey', 'Health Care', 'SENATE', 'CHAIR'),
('Gladys A. Robinson', 'Health Care', 'SENATE', 'ADVISORY'),
('Gale Adcock', 'Health Care', 'SENATE', 'MEMBER'),
('Val Applewhite', 'Health Care', 'SENATE', 'MEMBER'),
('Lisa S. Barnes', 'Health Care', 'SENATE', 'MEMBER'),
('Danny Earl Britt, Jr.', 'Health Care', 'SENATE', 'MEMBER'),
('Kevin Corbin', 'Health Care', 'SENATE', 'MEMBER'),
('Michael Garrett', 'Health Care', 'SENATE', 'MEMBER'),
('Ralph Hise', 'Health Care', 'SENATE', 'MEMBER'),
('Mark Hollo', 'Health Care', 'SENATE', 'MEMBER'),
('Todd Johnson', 'Health Care', 'SENATE', 'MEMBER'),
('Michael V. Lee', 'Health Care', 'SENATE', 'MEMBER'),
('Julie Mayfield', 'Health Care', 'SENATE', 'MEMBER'),
('Timothy D. Moffitt', 'Health Care', 'SENATE', 'MEMBER'),
('Mujtaba A. Mohammed', 'Health Care', 'SENATE', 'MEMBER'),
('Natalie S. Murdock', 'Health Care', 'SENATE', 'MEMBER'),
('Eddie D. Settle', 'Health Care', 'SENATE', 'MEMBER'),
('Joyce Waddell', 'Health Care', 'SENATE', 'MEMBER'),
-- Senate: Judiciary
('Danny Earl Britt, Jr.', 'Judiciary', 'SENATE', 'CHAIR'),
('Warren Daniel', 'Judiciary', 'SENATE', 'CHAIR'),
('Buck Newton', 'Judiciary', 'SENATE', 'CHAIR'),
('Sydney Batch', 'Judiciary', 'SENATE', 'MEMBER'),
('Dan Blue', 'Judiciary', 'SENATE', 'MEMBER'),
('Sophia Chitlik', 'Judiciary', 'SENATE', 'MEMBER'),
('David W. Craven, Jr.', 'Judiciary', 'SENATE', 'MEMBER'),
('Terence Everitt', 'Judiciary', 'SENATE', 'MEMBER'),
('Amy S. Galey', 'Judiciary', 'SENATE', 'MEMBER'),
('Lisa Grafstein', 'Judiciary', 'SENATE', 'MEMBER'),
('Michael A. Lazzara', 'Judiciary', 'SENATE', 'MEMBER'),
('Michael V. Lee', 'Judiciary', 'SENATE', 'MEMBER'),
('Chris Measmer', 'Judiciary', 'SENATE', 'MEMBER'),
('Mujtaba A. Mohammed', 'Judiciary', 'SENATE', 'MEMBER'),
('Brad Overcash', 'Judiciary', 'SENATE', 'MEMBER'),
('Norman W. Sanderson', 'Judiciary', 'SENATE', 'MEMBER'),
('Benton G. Sawrey', 'Judiciary', 'SENATE', 'MEMBER'),
-- Senate: Pensions and Retirement and Aging
('W. Ted Alexander', 'Pensions and Retirement and Aging', 'SENATE', 'CHAIR'),
('Carl Ford', 'Pensions and Retirement and Aging', 'SENATE', 'CHAIR'),
('Val Applewhite', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Woodson Bradley', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Danny Earl Britt, Jr.', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Jim Burgin', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Kevin Corbin', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('David W. Craven, Jr.', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Warren Daniel', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Terence Everitt', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Ralph Hise', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Graig Meyer', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Gladys A. Robinson', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
('Joyce Waddell', 'Pensions and Retirement and Aging', 'SENATE', 'MEMBER'),
-- Senate: Regulatory Reform
('Steve Jarvis', 'Regulatory Reform', 'SENATE', 'CHAIR'),
('Tom McInnis', 'Regulatory Reform', 'SENATE', 'CHAIR'),
('Timothy D. Moffitt', 'Regulatory Reform', 'SENATE', 'CHAIR'),
('Lisa S. Barnes', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Woodson Bradley', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Sophia Chitlik', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('David W. Craven, Jr.', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Terence Everitt', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Lisa Grafstein', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Bobby Hanig', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Brent Jackson', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Dana Jones', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Michael A. Lazzara', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Chris Measmer', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Graig Meyer', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Norman W. Sanderson', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Vickie Sawyer', 'Regulatory Reform', 'SENATE', 'MEMBER'),
('Caleb Theodros', 'Regulatory Reform', 'SENATE', 'MEMBER'),
-- Senate: Rules and Operations of the Senate
('Bill Rabon', 'Rules and Operations of the Senate', 'SENATE', 'CHAIR'),
('Warren Daniel', 'Rules and Operations of the Senate', 'SENATE', 'VICE_CHAIR'),
('Gale Adcock', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Lisa S. Barnes', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Dan Blue', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Danny Earl Britt, Jr.', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Jay J. Chaudhuri', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Carl Ford', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Amy S. Galey', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Michael Garrett', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Ralph Hise', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Brent Jackson', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Todd Johnson', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Michael A. Lazzara', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Michael V. Lee', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Paul A. Lowe, Jr.', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Julie Mayfield', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Tom McInnis', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('DeAndrea Salvador', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Norman W. Sanderson', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Benton G. Sawrey', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Vickie Sawyer', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
('Joyce Waddell', 'Rules and Operations of the Senate', 'SENATE', 'MEMBER'),
-- Senate: State and Local Government
('W. Ted Alexander', 'State and Local Government', 'SENATE', 'CHAIR'),
('Carl Ford', 'State and Local Government', 'SENATE', 'CHAIR'),
('Bobby Hanig', 'State and Local Government', 'SENATE', 'CHAIR'),
('Gale Adcock', 'State and Local Government', 'SENATE', 'MEMBER'),
('Val Applewhite', 'State and Local Government', 'SENATE', 'MEMBER'),
('Bob Brinson', 'State and Local Government', 'SENATE', 'MEMBER'),
('Jim Burgin', 'State and Local Government', 'SENATE', 'MEMBER'),
('Kevin Corbin', 'State and Local Government', 'SENATE', 'MEMBER'),
('Lisa Grafstein', 'State and Local Government', 'SENATE', 'MEMBER'),
('Mark Hollo', 'State and Local Government', 'SENATE', 'MEMBER'),
('Steve Jarvis', 'State and Local Government', 'SENATE', 'MEMBER'),
('Dana Jones', 'State and Local Government', 'SENATE', 'MEMBER'),
('Michael A. Lazzara', 'State and Local Government', 'SENATE', 'MEMBER'),
('Chris Measmer', 'State and Local Government', 'SENATE', 'MEMBER'),
('Graig Meyer', 'State and Local Government', 'SENATE', 'MEMBER'),
('Gladys A. Robinson', 'State and Local Government', 'SENATE', 'MEMBER'),
('Eddie D. Settle', 'State and Local Government', 'SENATE', 'MEMBER'),
('Kandie D. Smith', 'State and Local Government', 'SENATE', 'MEMBER'),
-- Senate: Transportation
('Michael A. Lazzara', 'Transportation', 'SENATE', 'CHAIR'),
('Bill Rabon', 'Transportation', 'SENATE', 'CHAIR'),
('Vickie Sawyer', 'Transportation', 'SENATE', 'CHAIR'),
('Bob Brinson', 'Transportation', 'SENATE', 'MEMBER'),
('Jay J. Chaudhuri', 'Transportation', 'SENATE', 'MEMBER'),
('Bobby Hanig', 'Transportation', 'SENATE', 'MEMBER'),
('Steve Jarvis', 'Transportation', 'SENATE', 'MEMBER'),
('Todd Johnson', 'Transportation', 'SENATE', 'MEMBER'),
('Dana Jones', 'Transportation', 'SENATE', 'MEMBER'),
('Julie Mayfield', 'Transportation', 'SENATE', 'MEMBER'),
('Tom McInnis', 'Transportation', 'SENATE', 'MEMBER'),
('Timothy D. Moffitt', 'Transportation', 'SENATE', 'MEMBER'),
('Mujtaba A. Mohammed', 'Transportation', 'SENATE', 'MEMBER'),
('Natalie S. Murdock', 'Transportation', 'SENATE', 'MEMBER'),
('Buck Newton', 'Transportation', 'SENATE', 'MEMBER'),
('DeAndrea Salvador', 'Transportation', 'SENATE', 'MEMBER'),
('Eddie D. Settle', 'Transportation', 'SENATE', 'MEMBER'),
('Kandie D. Smith', 'Transportation', 'SENATE', 'MEMBER'),
('Caleb Theodros', 'Transportation', 'SENATE', 'MEMBER')
) AS v(member_name, committee_name, chamber, role)
JOIN state_legislature.ncga_members m ON m.full_name = v.member_name AND m.chamber = v.chamber
JOIN state_legislature.ncga_committees c ON c.committee_name = v.committee_name AND c.chamber = v.chamber
ON CONFLICT (member_id, committee_id) DO NOTHING;

-- ============================================================================
-- SECTION 11: COMMITTEE ASSIGNMENTS — NC HOUSE
-- Source: ncleg.gov committee roster pages — scraped 2026-03-15
-- NOTE: Due to 33 committees x ~25 members each, this is the largest section.
-- Only CHAIR/VICE_CHAIR/SENIOR_CHAIR roles are individually tagged;
-- all others default to MEMBER.
-- ============================================================================
INSERT INTO state_legislature.ncga_assignments (member_id, committee_id, role)
SELECT m.member_id, c.committee_id, v.role
FROM (VALUES
-- House: Agriculture and Environment
('Jeffrey C. McNeely', 'Agriculture and Environment', 'HOUSE', 'CHAIR'),
('Ben T. Moss, Jr.', 'Agriculture and Environment', 'HOUSE', 'VICE_CHAIR'),
('William D. Brisson', 'Agriculture and Environment', 'HOUSE', 'VICE_CHAIR'),
('Howard Penny, Jr.', 'Agriculture and Environment', 'HOUSE', 'CHAIR'),
('Jimmy Dixon', 'Agriculture and Environment', 'HOUSE', 'SENIOR_CHAIR'),
('Eric Ager', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Vernetta Alston', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Jennifer Balkcom', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Deb Butler', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Sarah Crawford', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Blair Eddins', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Neal Jackson', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('B. Ray Jeffers', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Keith Kidwell', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Brandon Lofton', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Nasif Majeed', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Ray Pickett', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Amos L. Quick, III', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Larry C. Strickland', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
('Sam Watford', 'Agriculture and Environment', 'HOUSE', 'MEMBER'),
-- House: Alcoholic Beverage Control
('Celeste C. Cairns', 'Alcoholic Beverage Control', 'HOUSE', 'CHAIR'),
('A. Reece Pyrtle, Jr.', 'Alcoholic Beverage Control', 'HOUSE', 'CHAIR'),
('Ray Pickett', 'Alcoholic Beverage Control', 'HOUSE', 'CHAIR'),
('Steve Tyson', 'Alcoholic Beverage Control', 'HOUSE', 'VICE_CHAIR'),
('David Willis', 'Alcoholic Beverage Control', 'HOUSE', 'VICE_CHAIR'),
('Kanika Brown', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
('Bryan Cohn', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
('Mike Colvin', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
('Allison A. Dahle', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
('Charles W. Miller', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
('Paul Scott', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
('Brian Turner', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
('Diane Wheatley', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
('Shelly Willingham', 'Alcoholic Beverage Control', 'HOUSE', 'MEMBER'),
-- House: Commerce and Economic Development
('Stephen M. Ross', 'Commerce and Economic Development', 'HOUSE', 'CHAIR'),
('John Sauls', 'Commerce and Economic Development', 'HOUSE', 'CHAIR'),
('Celeste C. Cairns', 'Commerce and Economic Development', 'HOUSE', 'VICE_CHAIR'),
('Jake Johnson', 'Commerce and Economic Development', 'HOUSE', 'VICE_CHAIR'),
('Jay Adams', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Vernetta Alston', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Jennifer Balkcom', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('John M. Blust', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Kanika Brown', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Carla D. Cunningham', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Brandon Lofton', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Nasif Majeed', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Garland E. Pierce', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Dante Pittman', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Timothy Reeder, MD', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Phil Shepard', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Larry C. Strickland', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Shelly Willingham', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
('Matthew Winslow', 'Commerce and Economic Development', 'HOUSE', 'MEMBER'),
-- House: Education - K-12
('Tricia Ann Cotham', 'Education - K-12', 'HOUSE', 'CHAIR'),
('Heather H. Rhyne', 'Education - K-12', 'HOUSE', 'VICE_CHAIR'),
('Hugh Blackwell', 'Education - K-12', 'HOUSE', 'VICE_CHAIR'),
('Jennifer Balkcom', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Brian Biggs', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Cynthia Ball', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Laura Budd', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Aisha O. Dew', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Tracy Clark', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Jake Johnson', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Larry W. Potts', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Dennis Riddell', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Timothy Reeder, MD', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Mike Schietzelt', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Phil Shepard', 'Education - K-12', 'HOUSE', 'MEMBER'),
('John A. Torbett', 'Education - K-12', 'HOUSE', 'MEMBER'),
('Donna McDowell White', 'Education - K-12', 'HOUSE', 'MEMBER'),
-- House: Election Law
('Hugh Blackwell', 'Election Law', 'HOUSE', 'CHAIR'),
('Sarah Stevens', 'Election Law', 'HOUSE', 'CHAIR'),
('Allison A. Dahle', 'Election Law', 'HOUSE', 'VICE_CHAIR'),
('Jonathan L. Almond', 'Election Law', 'HOUSE', 'MEMBER'),
('Cynthia Ball', 'Election Law', 'HOUSE', 'MEMBER'),
('Mary Belk', 'Election Law', 'HOUSE', 'MEMBER'),
('Ted Davis, Jr.', 'Election Law', 'HOUSE', 'MEMBER'),
('Jimmy Dixon', 'Election Law', 'HOUSE', 'MEMBER'),
('Tricia Ann Cotham', 'Election Law', 'HOUSE', 'MEMBER'),
('Dennis Riddell', 'Election Law', 'HOUSE', 'MEMBER'),
('Carson Smith', 'Election Law', 'HOUSE', 'MEMBER'),
('Charles Smith', 'Election Law', 'HOUSE', 'MEMBER'),
('Harry Warren', 'Election Law', 'HOUSE', 'MEMBER'),
('Shelly Willingham', 'Election Law', 'HOUSE', 'MEMBER'),
('Jeff Zenger', 'Election Law', 'HOUSE', 'MEMBER'),
('Phil Rubin', 'Election Law', 'HOUSE', 'MEMBER'),
('Bill Ward', 'Election Law', 'HOUSE', 'MEMBER'),
-- House: Energy and Public Utilities
('Dean Arp', 'Energy and Public Utilities', 'HOUSE', 'CHAIR'),
('Matthew Winslow', 'Energy and Public Utilities', 'HOUSE', 'CHAIR'),
('Neal Jackson', 'Energy and Public Utilities', 'HOUSE', 'VICE_CHAIR'),
('Charles W. Miller', 'Energy and Public Utilities', 'HOUSE', 'VICE_CHAIR'),
('William D. Brisson', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Kanika Brown', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Terry M. Brown Jr.', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Becky Carney', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Celeste C. Cairns', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Maria Cervania', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Sarah Crawford', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Carla D. Cunningham', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Jimmy Dixon', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Carolyn G. Logan', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('A. Reece Pyrtle, Jr.', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Dennis Riddell', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('John Sauls', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Mitchell S. Setzer', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Larry C. Strickland', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Steve Tyson', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Sam Watford', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
('Shelly Willingham', 'Energy and Public Utilities', 'HOUSE', 'MEMBER'),
-- House: Finance
('Stephen M. Ross', 'Finance', 'HOUSE', 'CHAIR'),
('Keith Kidwell', 'Finance', 'HOUSE', 'CHAIR'),
('Harry Warren', 'Finance', 'HOUSE', 'VICE_CHAIR'),
('Neal Jackson', 'Finance', 'HOUSE', 'SENIOR_CHAIR'),
('Mitchell S. Setzer', 'Finance', 'HOUSE', 'SENIOR_CHAIR'),
('Eric Ager', 'Finance', 'HOUSE', 'MEMBER'),
('Amber M. Baker', 'Finance', 'HOUSE', 'MEMBER'),
('John M. Blust', 'Finance', 'HOUSE', 'MEMBER'),
('Deb Butler', 'Finance', 'HOUSE', 'MEMBER'),
('Becky Carney', 'Finance', 'HOUSE', 'MEMBER'),
('Todd Carver', 'Finance', 'HOUSE', 'MEMBER'),
('Mike Colvin', 'Finance', 'HOUSE', 'MEMBER'),
('Aisha O. Dew', 'Finance', 'HOUSE', 'MEMBER'),
('Brian Echevarria', 'Finance', 'HOUSE', 'MEMBER'),
('Frances Jackson, PhD', 'Finance', 'HOUSE', 'MEMBER'),
('John L. Lowery', 'Finance', 'HOUSE', 'MEMBER'),
('Tim Longest', 'Finance', 'HOUSE', 'MEMBER'),
('Jordan Lopez', 'Finance', 'HOUSE', 'MEMBER'),
('Joseph Pike', 'Finance', 'HOUSE', 'MEMBER'),
('Paul Scott', 'Finance', 'HOUSE', 'MEMBER'),
('John Sauls', 'Finance', 'HOUSE', 'MEMBER'),
('Sam Watford', 'Finance', 'HOUSE', 'MEMBER'),
('Diane Wheatley', 'Finance', 'HOUSE', 'MEMBER'),
('Brandon Lofton', 'Finance', 'HOUSE', 'MEMBER'),
-- House: Health
('Donna McDowell White', 'Health', 'HOUSE', 'CHAIR'),
('Hugh Blackwell', 'Health', 'HOUSE', 'VICE_CHAIR'),
('Tricia Ann Cotham', 'Health', 'HOUSE', 'VICE_CHAIR'),
('Larry W. Potts', 'Health', 'HOUSE', 'SENIOR_CHAIR'),
('Cynthia Ball', 'Health', 'HOUSE', 'MEMBER'),
('Mary Belk', 'Health', 'HOUSE', 'MEMBER'),
('Brian Biggs', 'Health', 'HOUSE', 'MEMBER'),
('William D. Brisson', 'Health', 'HOUSE', 'MEMBER'),
('Allen Chesser', 'Health', 'HOUSE', 'MEMBER'),
('Tracy Clark', 'Health', 'HOUSE', 'MEMBER'),
('Sarah Crawford', 'Health', 'HOUSE', 'MEMBER'),
('Carla D. Cunningham', 'Health', 'HOUSE', 'MEMBER'),
('Becky Carney', 'Health', 'HOUSE', 'MEMBER'),
('Donnie Loftis', 'Health', 'HOUSE', 'MEMBER'),
('Ya Liu', 'Health', 'HOUSE', 'MEMBER'),
('Charles W. Miller', 'Health', 'HOUSE', 'MEMBER'),
('A. Reece Pyrtle, Jr.', 'Health', 'HOUSE', 'MEMBER'),
('Timothy Reeder, MD', 'Health', 'HOUSE', 'MEMBER'),
('Paul Scott', 'Health', 'HOUSE', 'MEMBER'),
('Phil Shepard', 'Health', 'HOUSE', 'MEMBER'),
('Julie von Haefen', 'Health', 'HOUSE', 'MEMBER'),
('Diane Wheatley', 'Health', 'HOUSE', 'MEMBER'),
-- House: Insurance
('Jennifer Balkcom', 'Insurance', 'HOUSE', 'CHAIR'),
('Mitchell S. Setzer', 'Insurance', 'HOUSE', 'VICE_CHAIR'),
('Jonathan L. Almond', 'Insurance', 'HOUSE', 'MEMBER'),
('Allen Buansi', 'Insurance', 'HOUSE', 'MEMBER'),
('Frances Jackson, PhD', 'Insurance', 'HOUSE', 'MEMBER'),
('Nasif Majeed', 'Insurance', 'HOUSE', 'MEMBER'),
('Marcia Morey', 'Insurance', 'HOUSE', 'MEMBER'),
('Garland E. Pierce', 'Insurance', 'HOUSE', 'MEMBER'),
('Rodney D. Pierce', 'Insurance', 'HOUSE', 'MEMBER'),
('Joseph Pike', 'Insurance', 'HOUSE', 'MEMBER'),
('Larry W. Potts', 'Insurance', 'HOUSE', 'MEMBER'),
('Timothy Reeder, MD', 'Insurance', 'HOUSE', 'MEMBER'),
('James Roberson', 'Insurance', 'HOUSE', 'MEMBER'),
('Harry Warren', 'Insurance', 'HOUSE', 'MEMBER'),
('Diane Wheatley', 'Insurance', 'HOUSE', 'MEMBER'),
('Shelly Willingham', 'Insurance', 'HOUSE', 'MEMBER'),
('Kanika Brown', 'Insurance', 'HOUSE', 'MEMBER'),
-- House: Judiciary 1
('Ted Davis, Jr.', 'Judiciary 1', 'HOUSE', 'CHAIR'),
('Hugh Blackwell', 'Judiciary 1', 'HOUSE', 'VICE_CHAIR'),
('Vernetta Alston', 'Judiciary 1', 'HOUSE', 'MEMBER'),
('Dean Arp', 'Judiciary 1', 'HOUSE', 'MEMBER'),
('Abe Jones', 'Judiciary 1', 'HOUSE', 'MEMBER'),
('Brandon Lofton', 'Judiciary 1', 'HOUSE', 'MEMBER'),
('Mike Schietzelt', 'Judiciary 1', 'HOUSE', 'MEMBER'),
('Matthew Winslow', 'Judiciary 1', 'HOUSE', 'MEMBER'),
-- House: Judiciary 2
('Sarah Stevens', 'Judiciary 2', 'HOUSE', 'CHAIR'),
('Carson Smith', 'Judiciary 2', 'HOUSE', 'VICE_CHAIR'),
('Laura Budd', 'Judiciary 2', 'HOUSE', 'MEMBER'),
('Todd Carver', 'Judiciary 2', 'HOUSE', 'MEMBER'),
('Terry M. Brown Jr.', 'Judiciary 2', 'HOUSE', 'MEMBER'),
('Ya Liu', 'Judiciary 2', 'HOUSE', 'MEMBER'),
('Charles W. Miller', 'Judiciary 2', 'HOUSE', 'MEMBER'),
('A. Reece Pyrtle, Jr.', 'Judiciary 2', 'HOUSE', 'MEMBER'),
-- House: Judiciary 3
('John M. Blust', 'Judiciary 3', 'HOUSE', 'CHAIR'),
('Jonathan L. Almond', 'Judiciary 3', 'HOUSE', 'MEMBER'),
('Todd Carver', 'Judiciary 3', 'HOUSE', 'MEMBER'),
('Keith Kidwell', 'Judiciary 3', 'HOUSE', 'MEMBER'),
('Tim Longest', 'Judiciary 3', 'HOUSE', 'MEMBER'),
('Marcia Morey', 'Judiciary 3', 'HOUSE', 'MEMBER'),
('Renee A. Price', 'Judiciary 3', 'HOUSE', 'MEMBER'),
('Bill Ward', 'Judiciary 3', 'HOUSE', 'MEMBER'),
-- House: Homeland Security and Military and Veterans Affairs
('Donnie Loftis', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'CHAIR'),
('Joseph Pike', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'CHAIR'),
('Allen Chesser', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'VICE_CHAIR'),
('Jay Adams', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Dean Arp', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Celeste C. Cairns', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Grant L. Campbell, MD', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Mike Clampitt', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Mike Colvin', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Allison A. Dahle', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Frances Jackson, PhD', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Carolyn G. Logan', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Nasif Majeed', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Garland E. Pierce', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Rodney D. Pierce', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Larry W. Potts', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Charles Smith', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('David Willis', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
('Diane Wheatley', 'Homeland Security and Military and Veterans Affairs', 'HOUSE', 'MEMBER'),
-- House: Housing and Development
('Mark Brody', 'Housing and Development', 'HOUSE', 'CHAIR'),
('Jeff Zenger', 'Housing and Development', 'HOUSE', 'CHAIR'),
('Tricia Ann Cotham', 'Housing and Development', 'HOUSE', 'MEMBER'),
('Carla D. Cunningham', 'Housing and Development', 'HOUSE', 'MEMBER'),
('Howard Penny, Jr.', 'Housing and Development', 'HOUSE', 'MEMBER'),
('Ya Liu', 'Housing and Development', 'HOUSE', 'MEMBER'),
('Jordan Lopez', 'Housing and Development', 'HOUSE', 'MEMBER'),
('Sam Watford', 'Housing and Development', 'HOUSE', 'MEMBER'),
('Matthew Winslow', 'Housing and Development', 'HOUSE', 'MEMBER'),
('David Willis', 'Housing and Development', 'HOUSE', 'MEMBER'),
-- House: Transportation
('Jay Adams', 'Transportation', 'HOUSE', 'CHAIR'),
('Jeffrey C. McNeely', 'Transportation', 'HOUSE', 'CHAIR'),
('Phil Shepard', 'Transportation', 'HOUSE', 'CHAIR'),
('Vernetta Alston', 'Transportation', 'HOUSE', 'MEMBER'),
('Mary Belk', 'Transportation', 'HOUSE', 'MEMBER'),
('John M. Blust', 'Transportation', 'HOUSE', 'MEMBER'),
('Laura Budd', 'Transportation', 'HOUSE', 'MEMBER'),
('Terry M. Brown Jr.', 'Transportation', 'HOUSE', 'MEMBER'),
('Tracy Clark', 'Transportation', 'HOUSE', 'MEMBER'),
('Brian Echevarria', 'Transportation', 'HOUSE', 'MEMBER'),
('Frances Jackson, PhD', 'Transportation', 'HOUSE', 'MEMBER'),
('Brandon Lofton', 'Transportation', 'HOUSE', 'MEMBER'),
('Jordan Lopez', 'Transportation', 'HOUSE', 'MEMBER'),
('Ben T. Moss, Jr.', 'Transportation', 'HOUSE', 'MEMBER'),
('Ray Pickett', 'Transportation', 'HOUSE', 'MEMBER'),
('James Roberson', 'Transportation', 'HOUSE', 'MEMBER'),
('Mike Schietzelt', 'Transportation', 'HOUSE', 'MEMBER'),
('Larry C. Strickland', 'Transportation', 'HOUSE', 'MEMBER'),
('Harry Warren', 'Transportation', 'HOUSE', 'MEMBER'),
('Jeff Zenger', 'Transportation', 'HOUSE', 'MEMBER'),
-- House: Wildlife Resources
('Ben T. Moss, Jr.', 'Wildlife Resources', 'HOUSE', 'CHAIR'),
('Jay Adams', 'Wildlife Resources', 'HOUSE', 'CHAIR'),
('William D. Brisson', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
('Deb Butler', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
('Mike Clampitt', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
('Carla D. Cunningham', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
('Blair Eddins', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
('Abe Jones', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
('Jake Johnson', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
('Mark Pless', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
('Brian Turner', 'Wildlife Resources', 'HOUSE', 'MEMBER'),
-- House: Emergency Management and Disaster Recovery
('John L. Lowery', 'Emergency Management and Disaster Recovery', 'HOUSE', 'VICE_CHAIR'),
('Mike Clampitt', 'Emergency Management and Disaster Recovery', 'HOUSE', 'VICE_CHAIR'),
('Mark Pless', 'Emergency Management and Disaster Recovery', 'HOUSE', 'VICE_CHAIR'),
('Eric Ager', 'Emergency Management and Disaster Recovery', 'HOUSE', 'MEMBER'),
('Allison A. Dahle', 'Emergency Management and Disaster Recovery', 'HOUSE', 'MEMBER'),
('Ted Davis, Jr.', 'Emergency Management and Disaster Recovery', 'HOUSE', 'MEMBER'),
('Monika Johnson-Hostler', 'Emergency Management and Disaster Recovery', 'HOUSE', 'MEMBER'),
('Dante Pittman', 'Emergency Management and Disaster Recovery', 'HOUSE', 'MEMBER'),
-- House: Federal Relations and American Indian Affairs
('Mike Clampitt', 'Federal Relations and American Indian Affairs', 'HOUSE', 'CHAIR'),
('Bill Ward', 'Federal Relations and American Indian Affairs', 'HOUSE', 'CHAIR'),
('John L. Lowery', 'Federal Relations and American Indian Affairs', 'HOUSE', 'VICE_CHAIR'),
('Mark Pless', 'Federal Relations and American Indian Affairs', 'HOUSE', 'VICE_CHAIR'),
('Amber M. Baker', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
('B. Ray Jeffers', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
('Dennis Riddell', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
('John Sauls', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
('Paul Scott', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
('Carson Smith', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
('Charles Smith', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
('Garland E. Pierce', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
('Shelly Willingham', 'Federal Relations and American Indian Affairs', 'HOUSE', 'MEMBER'),
-- House: Higher Education
('Ray Pickett', 'Higher Education', 'HOUSE', 'CHAIR'),
('Timothy Reeder, MD', 'Higher Education', 'HOUSE', 'VICE_CHAIR'),
('Jay Adams', 'Higher Education', 'HOUSE', 'MEMBER'),
('Mark Brody', 'Higher Education', 'HOUSE', 'MEMBER'),
('Gloristine Brown', 'Higher Education', 'HOUSE', 'MEMBER'),
('Terry M. Brown Jr.', 'Higher Education', 'HOUSE', 'MEMBER'),
('Todd Carver', 'Higher Education', 'HOUSE', 'MEMBER'),
('Becky Carney', 'Higher Education', 'HOUSE', 'MEMBER'),
('Neal Jackson', 'Higher Education', 'HOUSE', 'MEMBER'),
('Monika Johnson-Hostler', 'Higher Education', 'HOUSE', 'MEMBER'),
('Lindsey Prather', 'Higher Education', 'HOUSE', 'MEMBER'),
('Renee A. Price', 'Higher Education', 'HOUSE', 'MEMBER'),
('Julie von Haefen', 'Higher Education', 'HOUSE', 'MEMBER'),
('John Sauls', 'Higher Education', 'HOUSE', 'MEMBER'),
-- House: Oversight
('Jake Johnson', 'Oversight', 'HOUSE', 'CHAIR'),
('Brenden H. Jones', 'Oversight', 'HOUSE', 'CHAIR'),
('Harry Warren', 'Oversight', 'HOUSE', 'CHAIR'),
('Eric Ager', 'Oversight', 'HOUSE', 'MEMBER'),
('Dean Arp', 'Oversight', 'HOUSE', 'MEMBER'),
('Amber M. Baker', 'Oversight', 'HOUSE', 'MEMBER'),
('John M. Blust', 'Oversight', 'HOUSE', 'MEMBER'),
('Grant L. Campbell, MD', 'Oversight', 'HOUSE', 'MEMBER'),
('Maria Cervania', 'Oversight', 'HOUSE', 'MEMBER'),
('Carla D. Cunningham', 'Oversight', 'HOUSE', 'MEMBER'),
('Jimmy Dixon', 'Oversight', 'HOUSE', 'MEMBER'),
('Brian Echevarria', 'Oversight', 'HOUSE', 'MEMBER'),
('Jeffrey C. McNeely', 'Oversight', 'HOUSE', 'MEMBER'),
('Ben T. Moss, Jr.', 'Oversight', 'HOUSE', 'MEMBER'),
('Timothy Reeder, MD', 'Oversight', 'HOUSE', 'MEMBER'),
('Stephen M. Ross', 'Oversight', 'HOUSE', 'MEMBER'),
('Mike Schietzelt', 'Oversight', 'HOUSE', 'MEMBER'),
('Sarah Stevens', 'Oversight', 'HOUSE', 'MEMBER'),
('Amos L. Quick, III', 'Oversight', 'HOUSE', 'MEMBER'),
('Shelly Willingham', 'Oversight', 'HOUSE', 'MEMBER'),
-- House: Pensions and Retirement
('Charles Smith', 'Pensions and Retirement', 'HOUSE', 'CHAIR'),
('Carson Smith', 'Pensions and Retirement', 'HOUSE', 'CHAIR'),
('Diane Wheatley', 'Pensions and Retirement', 'HOUSE', 'CHAIR'),
('Mark Brody', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
('Aisha O. Dew', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
('John L. Lowery', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
('Lindsey Prather', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
('James Roberson', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
('Stephen M. Ross', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
('Phil Rubin', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
('Joseph Pike', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
('Amos L. Quick, III', 'Pensions and Retirement', 'HOUSE', 'MEMBER'),
-- House: Regulatory Reform
('Allen Chesser', 'Regulatory Reform', 'HOUSE', 'CHAIR'),
('Dennis Riddell', 'Regulatory Reform', 'HOUSE', 'CHAIR'),
('Jeff Zenger', 'Regulatory Reform', 'HOUSE', 'CHAIR'),
('Eric Ager', 'Regulatory Reform', 'HOUSE', 'MEMBER'),
('Amber M. Baker', 'Regulatory Reform', 'HOUSE', 'MEMBER'),
('Mary Belk', 'Regulatory Reform', 'HOUSE', 'MEMBER'),
('Hugh Blackwell', 'Regulatory Reform', 'HOUSE', 'MEMBER'),
('Terry M. Brown Jr.', 'Regulatory Reform', 'HOUSE', 'MEMBER'),
('Todd Carver', 'Regulatory Reform', 'HOUSE', 'MEMBER'),
('Sarah Stevens', 'Regulatory Reform', 'HOUSE', 'MEMBER'),
('Renee A. Price', 'Regulatory Reform', 'HOUSE', 'MEMBER'),
-- House: State and Local Government
('Keith Kidwell', 'State and Local Government', 'HOUSE', 'CHAIR'),
('John A. Torbett', 'State and Local Government', 'HOUSE', 'CHAIR'),
('Sam Watford', 'State and Local Government', 'HOUSE', 'CHAIR'),
('Vernetta Alston', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Tracy Clark', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Frances Jackson, PhD', 'State and Local Government', 'HOUSE', 'MEMBER'),
('B. Ray Jeffers', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Donnie Loftis', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Carolyn G. Logan', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Howard Penny, Jr.', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Ray Pickett', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Joseph Pike', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Lindsey Prather', 'State and Local Government', 'HOUSE', 'MEMBER'),
('James Roberson', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Stephen M. Ross', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Harry Warren', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Donna McDowell White', 'State and Local Government', 'HOUSE', 'MEMBER'),
('Bill Ward', 'State and Local Government', 'HOUSE', 'MEMBER'),
-- House: Rules, Calendar, and Operations of the House
('John R. Bell, IV', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'CHAIR'),
('Tricia Ann Cotham', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'VICE_CHAIR'),
('Brenden H. Jones', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'VICE_CHAIR'),
('Cynthia Ball', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Becky Carney', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('William D. Brisson', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Ted Davis, Jr.', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Jimmy Dixon', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Blair Eddins', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Allison A. Dahle', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Neal Jackson', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Tim Longest', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Charles W. Miller', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Ray Pickett', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Renee A. Price', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('A. Reece Pyrtle, Jr.', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Amos L. Quick, III', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Robert T. Reives, II', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Sarah Stevens', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Donna McDowell White', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Shelly Willingham', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('Steve Tyson', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER'),
('John A. Torbett', 'Rules, Calendar, and Operations of the House', 'HOUSE', 'MEMBER')
) AS v(member_name, committee_name, chamber, role)
JOIN state_legislature.ncga_members m ON m.full_name = v.member_name AND m.chamber = v.chamber
JOIN state_legislature.ncga_committees c ON c.committee_name = v.committee_name AND c.chamber = v.chamber
ON CONFLICT (member_id, committee_id) DO NOTHING;

-- ============================================================================
-- SECTION 12: SCORING ENGINE — Derive Legislator Faction Scores
-- 
-- LOGIC: For each legislator, sum their committee faction weights,
-- applying role multipliers:
--   CHAIR = 1.0, SENIOR_CHAIR = 0.9, VICE_CHAIR = 0.8, 
--   ADVISORY = 0.5, MEMBER = 0.6
-- Then normalize to 0-100 scale.
-- ============================================================================

-- Populate legislator_faction_scores from committee assignments
INSERT INTO state_legislature.legislator_faction_scores (
    member_id, maga_score, evan_score, trad_score, fisc_score,
    libt_score, busi_score, laws_score, popf_score, modg_score,
    vets_score, chna_score, rual_score,
    primary_faction, secondary_faction, tertiary_faction,
    committee_count, chair_count
)
SELECT 
    a.member_id,
    ROUND(SUM(f.maga * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS maga_score,
    ROUND(SUM(f.evan * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS evan_score,
    ROUND(SUM(f.trad * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS trad_score,
    ROUND(SUM(f.fisc * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS fisc_score,
    ROUND(SUM(f.libt * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS libt_score,
    ROUND(SUM(f.busi * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS busi_score,
    ROUND(SUM(f.laws * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS laws_score,
    ROUND(SUM(f.popf * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS popf_score,
    ROUND(SUM(f.modg * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS modg_score,
    ROUND(SUM(f.vets * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS vets_score,
    ROUND(SUM(f.chna * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS chna_score,
    ROUND(SUM(f.rual * CASE a.role 
        WHEN 'CHAIR' THEN 1.0 WHEN 'SENIOR_CHAIR' THEN 0.9
        WHEN 'VICE_CHAIR' THEN 0.8 WHEN 'ADVISORY' THEN 0.5
        ELSE 0.6 END) / GREATEST(COUNT(*),1), 2) AS rual_score,
    -- Primary/secondary/tertiary faction derived below
    NULL, NULL, NULL,
    COUNT(*) AS committee_count,
    COUNT(*) FILTER (WHERE a.role IN ('CHAIR','SENIOR_CHAIR')) AS chair_count
FROM state_legislature.ncga_assignments a
JOIN state_legislature.committee_faction_map f ON f.committee_id = a.committee_id
GROUP BY a.member_id
ON CONFLICT (member_id) DO UPDATE SET
    maga_score = EXCLUDED.maga_score,
    evan_score = EXCLUDED.evan_score,
    trad_score = EXCLUDED.trad_score,
    fisc_score = EXCLUDED.fisc_score,
    libt_score = EXCLUDED.libt_score,
    busi_score = EXCLUDED.busi_score,
    laws_score = EXCLUDED.laws_score,
    popf_score = EXCLUDED.popf_score,
    modg_score = EXCLUDED.modg_score,
    vets_score = EXCLUDED.vets_score,
    chna_score = EXCLUDED.chna_score,
    rual_score = EXCLUDED.rual_score,
    committee_count = EXCLUDED.committee_count,
    chair_count = EXCLUDED.chair_count,
    calculated_at = now();

-- Now update primary/secondary/tertiary faction labels
UPDATE state_legislature.legislator_faction_scores lfs
SET 
    primary_faction = ranked.faction_1,
    secondary_faction = ranked.faction_2,
    tertiary_faction = ranked.faction_3
FROM (
    SELECT member_id,
        (ARRAY_AGG(faction ORDER BY score DESC))[1] AS faction_1,
        (ARRAY_AGG(faction ORDER BY score DESC))[2] AS faction_2,
        (ARRAY_AGG(faction ORDER BY score DESC))[3] AS faction_3
    FROM (
        SELECT member_id, 'MAGA' AS faction, maga_score AS score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'EVAN', evan_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'TRAD', trad_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'FISC', fisc_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'LIBT', libt_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'BUSI', busi_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'LAWS', laws_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'POPF', popf_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'MODG', modg_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'VETS', vets_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'CHNA', chna_score FROM state_legislature.legislator_faction_scores
        UNION ALL SELECT member_id, 'RUAL', rual_score FROM state_legislature.legislator_faction_scores
    ) unpivoted
    GROUP BY member_id
) ranked
WHERE lfs.member_id = ranked.member_id;

-- ============================================================================
-- SECTION 13: ANALYTICAL VIEWS
-- ============================================================================

-- VIEW: Legislator profile card — name, party, district, top 3 factions, committees
CREATE OR REPLACE VIEW state_legislature.vw_legislator_profile AS
SELECT 
    m.full_name,
    m.chamber,
    m.district,
    m.party,
    m.county,
    lfs.primary_faction,
    lfs.secondary_faction,
    lfs.tertiary_faction,
    lfs.committee_count,
    lfs.chair_count,
    lfs.busi_score,
    lfs.fisc_score,
    lfs.rual_score,
    lfs.trad_score,
    lfs.laws_score,
    lfs.vets_score,
    lfs.maga_score,
    lfs.evan_score,
    lfs.modg_score
FROM state_legislature.ncga_members m
LEFT JOIN state_legislature.legislator_faction_scores lfs ON lfs.member_id = m.member_id
WHERE m.status IN ('ACTIVE','APPOINTED');

-- VIEW: Committee power map — who chairs what, with faction implications
CREATE OR REPLACE VIEW state_legislature.vw_committee_power_map AS
SELECT 
    c.committee_name,
    c.chamber,
    c.policy_domain,
    a.role,
    m.full_name,
    m.party,
    m.district,
    m.county,
    f.busi AS committee_busi_weight,
    f.rual AS committee_rual_weight,
    f.fisc AS committee_fisc_weight,
    f.laws AS committee_laws_weight,
    f.vets AS committee_vets_weight
FROM state_legislature.ncga_assignments a
JOIN state_legislature.ncga_members m ON m.member_id = a.member_id
JOIN state_legislature.ncga_committees c ON c.committee_id = a.committee_id
LEFT JOIN state_legislature.committee_faction_map f ON f.committee_id = c.committee_id
WHERE a.role IN ('CHAIR','SENIOR_CHAIR','VICE_CHAIR')
ORDER BY c.chamber, c.committee_name, 
    CASE a.role WHEN 'CHAIR' THEN 1 WHEN 'SENIOR_CHAIR' THEN 2 ELSE 3 END;

-- ============================================================================
-- SECTION 14: DONOR-LEGISLATOR CROSS-REFERENCE VIEW
-- This is Eddie's key insight: match NC BOE donors to legislators,
-- flag out-of-district donors, and infer industry alignment from
-- employer/occupation + committee chairmanships.
-- ============================================================================
CREATE OR REPLACE VIEW state_legislature.vw_donor_legislator_industry_signal AS
SELECT 
    d.donor_name,
    d.employer_name,
    d.profession_job_title,
    d.city AS donor_city,
    d.norm_zip5 AS donor_zip,
    d.committee_name AS recipient_committee_name,
    d.committee_sboe_id,
    SUM(d.amount_numeric) AS total_donated,
    COUNT(*) AS donation_count,
    m.full_name AS legislator_name,
    m.chamber,
    m.district,
    m.county AS legislator_county,
    m.party,
    lfs.primary_faction,
    lfs.secondary_faction,
    lfs.busi_score,
    lfs.rual_score,
    -- Out-of-district flag: donor city not in legislator county list
    CASE WHEN m.county IS NOT NULL 
         AND d.city IS NOT NULL
         AND NOT m.county ILIKE '%' || d.city || '%'
         THEN TRUE ELSE FALSE 
    END AS likely_out_of_district
FROM public.nc_boe_donations_raw d
JOIN state_legislature.ncga_members m 
    ON d.committee_name ILIKE '%' || 
       SPLIT_PART(m.full_name, ' ', 1) || '%' ||
       SPLIT_PART(m.full_name, ' ', 
           ARRAY_LENGTH(STRING_TO_ARRAY(m.full_name, ' '), 1)) || '%'
LEFT JOIN state_legislature.legislator_faction_scores lfs 
    ON lfs.member_id = m.member_id
WHERE d.amount_numeric > 0
GROUP BY d.donor_name, d.employer_name, d.profession_job_title,
    d.city, d.norm_zip5, d.committee_name, d.committee_sboe_id,
    m.full_name, m.chamber, m.district, m.county, m.party,
    lfs.primary_faction, lfs.secondary_faction, lfs.busi_score, lfs.rual_score;

-- ============================================================================
-- POST-DEPLOYMENT VERIFICATION QUERIES
-- ============================================================================
-- SELECT chamber, COUNT(*) FROM state_legislature.ncga_members GROUP BY chamber;
-- SELECT chamber, COUNT(*) FROM state_legislature.ncga_committees GROUP BY chamber;
-- SELECT COUNT(*) FROM state_legislature.ncga_assignments;
-- SELECT full_name, primary_faction, busi_score, rual_score, committee_count, chair_count
--   FROM state_legislature.vw_legislator_profile WHERE party = 'R' ORDER BY chair_count DESC LIMIT 20;
-- SELECT * FROM state_legislature.vw_committee_power_map WHERE chamber = 'SENATE' LIMIT 30;
