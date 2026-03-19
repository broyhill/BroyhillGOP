-- ============================================================================
-- NCGA COMMITTEE INDUSTRY JURISDICTION — NAICS/SIC MAPPING
-- BroyhillGOP Platform — Committee Oversight → Regulated Industry Codes
-- Generated: 2026-03-15
--
-- PURPOSE: Map each NC House and Senate committee (and its subcommittees)
-- to the specific industries under its regulatory jurisdiction, tagged
-- with NAICS (6-digit) and SIC (4-digit) codes. This creates a machine-
-- readable bridge:
--
--   DONOR EMPLOYER → NAICS/SIC → COMMITTEE JURISDICTION → LEGISLATOR
--
-- If a donor's employer operates in NAICS 524 (Insurance) and they donate
-- to the Chair of the Insurance Committee, that's a provable regulatory
-- relationship — not ideology, not party loyalty, but ACCESS.
--
-- NAICS: North American Industry Classification System (6-digit, modern)
-- SIC: Standard Industrial Classification (4-digit, legacy/SEC)
-- ============================================================================

-- TABLE: Committee-to-Industry jurisdiction mapping
CREATE TABLE IF NOT EXISTS state_legislature.committee_industry_jurisdiction (
    jurisdiction_id  SERIAL PRIMARY KEY,
    committee_id     INT REFERENCES state_legislature.ncga_committees(committee_id),
    committee_name   TEXT NOT NULL,
    chamber          TEXT NOT NULL CHECK (chamber IN ('HOUSE','SENATE')),
    subcommittee     TEXT,  -- NULL = full committee level
    industry_name    TEXT NOT NULL,
    industry_detail  TEXT,  -- specific subsector description
    naics_code       TEXT NOT NULL,  -- 2-6 digits (broader = shorter)
    naics_title      TEXT NOT NULL,
    sic_code         TEXT,  -- 4 digits, may be NULL for newer industries
    sic_title        TEXT,
    jurisdiction_type TEXT DEFAULT 'PRIMARY' 
        CHECK (jurisdiction_type IN ('PRIMARY','SECONDARY','OVERSIGHT')),
    -- PRIMARY = this committee writes the laws for this industry
    -- SECONDARY = this committee has partial/shared jurisdiction
    -- OVERSIGHT = appropriations/budget oversight only
    notes            TEXT,
    created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cij_naics ON state_legislature.committee_industry_jurisdiction(naics_code);
CREATE INDEX IF NOT EXISTS idx_cij_sic ON state_legislature.committee_industry_jurisdiction(sic_code);
CREATE INDEX IF NOT EXISTS idx_cij_committee ON state_legislature.committee_industry_jurisdiction(committee_id);

-- TABLE: Employer-to-NAICS classification (populated from donor data)
CREATE TABLE IF NOT EXISTS state_legislature.employer_naics_classification (
    classification_id SERIAL PRIMARY KEY,
    employer_name     TEXT NOT NULL,
    employer_normalized TEXT, -- cleaned/standardized name
    naics_code        TEXT,
    naics_title       TEXT,
    sic_code          TEXT,
    confidence        TEXT DEFAULT 'HIGH' CHECK (confidence IN ('HIGH','MEDIUM','LOW','INFERRED')),
    source            TEXT DEFAULT 'MANUAL', -- MANUAL, BLS, SEC, INFERRED
    created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_enc_employer ON state_legislature.employer_naics_classification(employer_normalized);
CREATE INDEX IF NOT EXISTS idx_enc_naics ON state_legislature.employer_naics_classification(naics_code);

-- ============================================================================
-- NC HOUSE COMMITTEES — INDUSTRY JURISDICTION WITH NAICS/SIC CODES
-- ============================================================================

-- Using subquery to get committee_id from name
INSERT INTO state_legislature.committee_industry_jurisdiction 
    (committee_id, committee_name, chamber, subcommittee, industry_name, industry_detail, 
     naics_code, naics_title, sic_code, sic_title, jurisdiction_type, notes)
VALUES
-- ========================================
-- AGRICULTURE AND ENVIRONMENT
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Crop Production', 'Row crops, tobacco, cotton, soybeans, corn, sweet potatoes',
 '111', 'Crop Production', '0100', 'Crops', 'PRIMARY', 'NC is #1 in tobacco, sweet potatoes, #2 in hogs'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Animal Production', 'Hog farming, poultry, cattle, dairy',
 '112', 'Animal Production and Aquaculture', '0200', 'Livestock', 'PRIMARY', 'NC #2 in hog production nationally. Smithfield, Prestage, Butterball'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Forestry and Logging', 'Timber, pulpwood, lumber production',
 '113', 'Forestry and Logging', '0800', 'Forestry', 'PRIMARY', NULL),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Fishing and Hunting', 'Commercial fishing, aquaculture, shellfish',
 '114', 'Fishing, Hunting and Trapping', '0900', 'Fishing, Hunting, Trapping', 'SECONDARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Farm Equipment', 'Tractors, combines, ag machinery manufacturing and sales',
 '333111', 'Farm Machinery and Equipment Manufacturing', '3523', 'Farm Machinery and Equipment', 'SECONDARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Fertilizer and Pesticide', 'Farm chemicals, fertilizer manufacturing and distribution',
 '325310', 'Fertilizer Manufacturing', '2870', 'Agricultural Chemicals', 'SECONDARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Food Processing', 'Meat packing, poultry processing, food manufacturing',
 '311', 'Food Manufacturing', '2000', 'Food and Kindred Products', 'PRIMARY', 'Smithfield Foods, Butterball, House of Raeford'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Environmental Services', 'Waste management, water treatment, remediation',
 '562', 'Waste Management and Remediation Services', '4950', 'Sanitary Services', 'PRIMARY', 'Hog lagoon regulation, water quality'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture and Environment' AND chamber='HOUSE'),
 'Agriculture and Environment', 'HOUSE', NULL,
 'Farm Supply and Distribution', 'Feed dealers, seed distributors, farm supply stores',
 '424510', 'Grain and Field Bean Merchant Wholesalers', '5150', 'Farm-Product Raw Materials', 'SECONDARY', NULL),

-- ========================================
-- ALCOHOLIC BEVERAGE CONTROL
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Alcoholic Beverage Control' AND chamber='HOUSE'),
 'Alcoholic Beverage Control', 'HOUSE', NULL,
 'Breweries', 'Beer brewing, craft breweries, microbreweries',
 '312120', 'Breweries', '2082', 'Malt Beverages', 'PRIMARY', 'NC craft beer boom - 400+ breweries'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Alcoholic Beverage Control' AND chamber='HOUSE'),
 'Alcoholic Beverage Control', 'HOUSE', NULL,
 'Wineries', 'Wine production, vineyards',
 '312130', 'Wineries', '2084', 'Wines, Brandy, and Brandy Spirits', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Alcoholic Beverage Control' AND chamber='HOUSE'),
 'Alcoholic Beverage Control', 'HOUSE', NULL,
 'Distilleries', 'Spirits production, craft distilleries',
 '312140', 'Distilleries', '2085', 'Distilled and Blended Liquors', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Alcoholic Beverage Control' AND chamber='HOUSE'),
 'Alcoholic Beverage Control', 'HOUSE', NULL,
 'Beer and Wine Wholesale', 'Distribution companies, wholesale alcohol',
 '424810', 'Beer and Ale Merchant Wholesalers', '5180', 'Beer, Wine, and Distilled Beverages', 'PRIMARY', 'NC Beer & Wine Wholesalers Assoc is major donor'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Alcoholic Beverage Control' AND chamber='HOUSE'),
 'Alcoholic Beverage Control', 'HOUSE', NULL,
 'Restaurants and Bars', 'On-premise alcohol sales, restaurants with bars',
 '722410', 'Drinking Places (Alcoholic Beverages)', '5813', 'Drinking Places', 'SECONDARY', 'ABC permit system'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Alcoholic Beverage Control' AND chamber='HOUSE'),
 'Alcoholic Beverage Control', 'HOUSE', NULL,
 'Hospitality', 'Hotels, resorts with alcohol service',
 '721110', 'Hotels and Motels', '7011', 'Hotels and Motels', 'SECONDARY', 'Tourism/hospitality alcohol permits'),

-- ========================================
-- COMMERCE AND ECONOMIC DEVELOPMENT
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Economic Development' AND chamber='HOUSE'),
 'Commerce and Economic Development', 'HOUSE', NULL,
 'Banking and Finance', 'Commercial banks, credit unions, financial institutions',
 '522', 'Credit Intermediation and Related Activities', '6020', 'Commercial Banks', 'PRIMARY', 'Bank of America HQ Charlotte, First Citizens, etc.'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Economic Development' AND chamber='HOUSE'),
 'Commerce and Economic Development', 'HOUSE', NULL,
 'Securities and Investments', 'Investment firms, broker-dealers, financial advisors',
 '523', 'Securities, Commodity Contracts, and Other Financial Investments', '6200', 'Security and Commodity Brokers', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Economic Development' AND chamber='HOUSE'),
 'Commerce and Economic Development', 'HOUSE', NULL,
 'Real Estate', 'Real estate development, property management, REITs',
 '531', 'Real Estate', '6500', 'Real Estate', 'PRIMARY', 'NC Realtors PAC is massive donor'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Economic Development' AND chamber='HOUSE'),
 'Commerce and Economic Development', 'HOUSE', NULL,
 'Technology and Software', 'Software development, IT services, SaaS companies',
 '5112', 'Software Publishers', '7372', 'Prepackaged Software', 'SECONDARY', 'Research Triangle, Charlotte fintech'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Economic Development' AND chamber='HOUSE'),
 'Commerce and Economic Development', 'HOUSE', NULL,
 'Professional Services', 'Consulting, accounting, legal services, management',
 '541', 'Professional, Scientific, and Technical Services', '7389', 'Misc Business Services', 'SECONDARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Economic Development' AND chamber='HOUSE'),
 'Commerce and Economic Development', 'HOUSE', NULL,
 'Retail Trade', 'General merchandise, department stores, big box retail',
 '452', 'General Merchandise Stores', '5300', 'General Merchandise Stores', 'SECONDARY', 'Lowes HQ Mooresville'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Economic Development' AND chamber='HOUSE'),
 'Commerce and Economic Development', 'HOUSE', NULL,
 'Manufacturing General', 'Auto, aerospace, machinery, misc manufacturing',
 '31-33', 'Manufacturing', '2000-3999', 'Manufacturing', 'SECONDARY', 'Economic incentives, tax credits, site selection'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Economic Development' AND chamber='HOUSE'),
 'Commerce and Economic Development', 'HOUSE', NULL,
 'Auto Dealers', 'New and used car dealerships, auto industry',
 '441', 'Motor Vehicle and Parts Dealers', '5511', 'Motor Vehicle Dealers (New and Used)', 'SECONDARY', 'NC AutoPAC is a top-10 donor statewide'),

-- ========================================
-- EDUCATION - K-12
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Education - K-12' AND chamber='HOUSE'),
 'Education - K-12', 'HOUSE', NULL,
 'Elementary and Secondary Schools', 'Public school systems, charter schools',
 '611110', 'Elementary and Secondary Schools', '8211', 'Elementary and Secondary Schools', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Education - K-12' AND chamber='HOUSE'),
 'Education - K-12', 'HOUSE', NULL,
 'Educational Support Services', 'Tutoring, testing, curriculum, textbooks',
 '611710', 'Educational Support Services', '8299', 'Schools and Educational Services NEC', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Education - K-12' AND chamber='HOUSE'),
 'Education - K-12', 'HOUSE', NULL,
 'School Bus and Transportation', 'Student transportation services',
 '485410', 'School and Employee Bus Transportation', '4151', 'School Buses', 'SECONDARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Education - K-12' AND chamber='HOUSE'),
 'Education - K-12', 'HOUSE', NULL,
 'Teachers Unions and Associations', 'NCAE and teacher advocacy organizations',
 '813930', 'Labor Unions and Similar Labor Organizations', '8631', 'Labor Unions', 'SECONDARY', 'NCAE is major political force'),

-- ========================================
-- ELECTION LAW
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Election Law' AND chamber='HOUSE'),
 'Election Law', 'HOUSE', NULL,
 'Political Consulting', 'Campaign consultants, pollsters, political strategists',
 '541820', 'Public Relations Agencies', '7311', 'Advertising Services', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Election Law' AND chamber='HOUSE'),
 'Election Law', 'HOUSE', NULL,
 'Voting Technology', 'Voting machines, election equipment, ballot systems',
 '334118', 'Computer Terminal and Other Computer Peripheral Equipment Manufacturing', '3579', 'Office Machines NEC', 'PRIMARY', NULL),

-- ========================================
-- ENERGY AND PUBLIC UTILITIES
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Energy and Public Utilities' AND chamber='HOUSE'),
 'Energy and Public Utilities', 'HOUSE', NULL,
 'Electric Power Generation', 'Electric utilities, power plants, nuclear',
 '2211', 'Electric Power Generation, Transmission and Distribution', '4911', 'Electric Services', 'PRIMARY', 'Duke Energy dominates NC. $93K to Jackson alone'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Energy and Public Utilities' AND chamber='HOUSE'),
 'Energy and Public Utilities', 'HOUSE', NULL,
 'Natural Gas Distribution', 'Gas utilities, pipeline companies',
 '2212', 'Natural Gas Distribution', '4924', 'Natural Gas Distribution', 'PRIMARY', 'Piedmont Natural Gas (Duke subsidiary)'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Energy and Public Utilities' AND chamber='HOUSE'),
 'Energy and Public Utilities', 'HOUSE', NULL,
 'Solar Energy', 'Solar farms, solar panel installation, solar development',
 '221114', 'Solar Electric Power Generation', NULL, NULL, 'PRIMARY', 'NC is #2 in solar nationally. Strata Solar, Pine Gate Renewables'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Energy and Public Utilities' AND chamber='HOUSE'),
 'Energy and Public Utilities', 'HOUSE', NULL,
 'Water and Sewer', 'Water utilities, wastewater treatment',
 '2213', 'Water, Sewage and Other Systems', '4941', 'Water Supply', 'PRIMARY', NULL),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Energy and Public Utilities' AND chamber='HOUSE'),
 'Energy and Public Utilities', 'HOUSE', NULL,
 'Telecommunications', 'Phone, broadband, cable, fiber, wireless carriers',
 '517', 'Telecommunications', '4810', 'Telephone Communications', 'PRIMARY', 'AT&T NC PAC is major donor. Spectrum, Lumen, Windstream'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Energy and Public Utilities' AND chamber='HOUSE'),
 'Energy and Public Utilities', 'HOUSE', NULL,
 'Electric Cooperatives', 'Rural electric membership corporations (EMCs)',
 '221122', 'Electric Power Distribution', '4911', 'Electric Services', 'PRIMARY', 'Rural Electric Action Program gave $109K to Jackson'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Energy and Public Utilities' AND chamber='HOUSE'),
 'Energy and Public Utilities', 'HOUSE', NULL,
 'Oil and Gas', 'Petroleum refining, gas stations, fuel distribution',
 '324', 'Petroleum and Coal Products Manufacturing', '2911', 'Petroleum Refining', 'SECONDARY', NULL),

-- ========================================
-- FINANCE
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='HOUSE'),
 'Finance', 'HOUSE', NULL,
 'Tax Preparation and Accounting', 'CPAs, tax preparers, accounting firms',
 '541211', 'Offices of Certified Public Accountants', '7291', 'Tax Return Preparation Services', 'PRIMARY', 'Controls NC tax code'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='HOUSE'),
 'Finance', 'HOUSE', NULL,
 'Banking', 'All banking entities subject to state tax policy',
 '522110', 'Commercial Banking', '6022', 'State commercial banks-Federal Reserve members', 'PRIMARY', 'Tax policy on financial institutions'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='HOUSE'),
 'Finance', 'HOUSE', NULL,
 'Tobacco Industry', 'Cigarette tax, tobacco settlement, vaping regulation',
 '312230', 'Tobacco Manufacturing', '2111', 'Cigarettes', 'PRIMARY', 'NC tobacco tax policy. Reynolds, Liggett'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='HOUSE'),
 'Finance', 'HOUSE', NULL,
 'Alcohol and Beverage Tax', 'Beer, wine, spirits tax policy',
 '312120', 'Breweries', '2082', 'Malt Beverages', 'SECONDARY', 'Excise tax rates on alcohol'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='HOUSE'),
 'Finance', 'HOUSE', NULL,
 'Real Estate Tax', 'Property tax, transfer tax, real estate taxation',
 '531', 'Real Estate', '6500', 'Real Estate', 'PRIMARY', 'Property tax policy'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='HOUSE'),
 'Finance', 'HOUSE', NULL,
 'Motor Vehicles Tax', 'Vehicle property tax, highway use tax, registration fees',
 '441', 'Motor Vehicle and Parts Dealers', '5511', 'Motor Vehicle Dealers', 'PRIMARY', 'Highway use tax replaces sales tax on vehicles'),

-- ========================================
-- HEALTH
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health' AND chamber='HOUSE'),
 'Health', 'HOUSE', NULL,
 'Hospitals', 'Hospital systems, medical centers, trauma centers',
 '622', 'Hospitals', '8060', 'Hospitals', 'PRIMARY', 'NC Hospital Assoc is top-20 donor. Atrium, Novant, UNC Health, Duke Health'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health' AND chamber='HOUSE'),
 'Health', 'HOUSE', NULL,
 'Physicians and Medical Groups', 'Physician practices, specialty groups, radiology',
 '621111', 'Offices of Physicians', '8011', 'Offices of Doctors of Medicine', 'PRIMARY', 'NC Medical Society PAC. Metrolina Radiologists gave $50K to Jackson'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health' AND chamber='HOUSE'),
 'Health', 'HOUSE', NULL,
 'Dental', 'Dental practices, dental groups, orthodontics',
 '621210', 'Offices of Dentists', '8021', 'Offices of Dentists', 'PRIMARY', 'NC Dental PAC is major donor'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health' AND chamber='HOUSE'),
 'Health', 'HOUSE', NULL,
 'Nursing and Residential Care', 'Nursing homes, assisted living, long-term care',
 '623', 'Nursing and Residential Care Facilities', '8051', 'Skilled Nursing Care Facilities', 'PRIMARY', 'NC Health Care Facilities Assoc gave $105K to Jackson'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health' AND chamber='HOUSE'),
 'Health', 'HOUSE', NULL,
 'Pharmaceuticals', 'Drug manufacturers, pharmacy chains, PBMs',
 '325410', 'Pharmaceutical and Medicine Manufacturing', '2834', 'Pharmaceutical Preparations', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health' AND chamber='HOUSE'),
 'Health', 'HOUSE', NULL,
 'Home Health and Ambulance', 'Home health agencies, EMS, ambulance services',
 '621610', 'Home Health Care Services', '8082', 'Home Health Care Services', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health' AND chamber='HOUSE'),
 'Health', 'HOUSE', NULL,
 'Mental Health and Substance Abuse', 'Behavioral health, addiction treatment, counseling',
 '621420', 'Outpatient Mental Health and Substance Abuse Centers', '8093', 'Specialty Outpatient Facilities', 'PRIMARY', 'Medicaid expansion impact'),

-- ========================================
-- HIGHER EDUCATION
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Higher Education' AND chamber='HOUSE'),
 'Higher Education', 'HOUSE', NULL,
 'Colleges and Universities', 'UNC System, community colleges, private universities',
 '611310', 'Colleges, Universities, and Professional Schools', '8221', 'Colleges and Universities', 'PRIMARY', 'UNC System 16 campuses. 58 community colleges'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Higher Education' AND chamber='HOUSE'),
 'Higher Education', 'HOUSE', NULL,
 'For-Profit Education', 'Trade schools, online universities, vocational',
 '611510', 'Technical and Trade Schools', '8249', 'Vocational Schools NEC', 'SECONDARY', NULL),

-- ========================================
-- HOMELAND SECURITY AND MILITARY AND VETERANS AFFAIRS
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Homeland Security and Military and Veterans Affairs' AND chamber='HOUSE'),
 'Homeland Security and Military and Veterans Affairs', 'HOUSE', NULL,
 'Defense Contractors', 'Military equipment, weapons systems, defense tech',
 '336411', 'Aircraft Manufacturing', '3721', 'Aircraft', 'PRIMARY', 'Fort Liberty (Bragg), Camp Lejeune, Seymour Johnson AFB'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Homeland Security and Military and Veterans Affairs' AND chamber='HOUSE'),
 'Homeland Security and Military and Veterans Affairs', 'HOUSE', NULL,
 'Security Services', 'Private security, cybersecurity, surveillance',
 '561612', 'Security Guards and Patrol Services', '7382', 'Security Services', 'SECONDARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Homeland Security and Military and Veterans Affairs' AND chamber='HOUSE'),
 'Homeland Security and Military and Veterans Affairs', 'HOUSE', NULL,
 'Veterans Services', 'VA contractors, veterans health, military transition',
 '624', 'Social Assistance', '8399', 'Membership Organizations NEC', 'PRIMARY', '775K+ NC veterans'),

-- ========================================
-- HOUSING AND DEVELOPMENT
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Housing and Development' AND chamber='HOUSE'),
 'Housing and Development', 'HOUSE', NULL,
 'Residential Construction', 'Homebuilders, general contractors, subdivisions',
 '236110', 'Residential Building Construction', '1521', 'General Contractors-Residential', 'PRIMARY', 'NC Build PAC (Home Builders) gave $66K to Jackson'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Housing and Development' AND chamber='HOUSE'),
 'Housing and Development', 'HOUSE', NULL,
 'Commercial Construction', 'Office buildings, retail, mixed-use development',
 '236220', 'Commercial and Institutional Building Construction', '1542', 'General Contractors-Nonresidential', 'PRIMARY', 'Carolina Asphalt Pavement Assoc PAC'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Housing and Development' AND chamber='HOUSE'),
 'Housing and Development', 'HOUSE', NULL,
 'Specialty Contractors', 'Plumbing, electrical, HVAC, concrete, roofing',
 '238', 'Specialty Trade Contractors', '1700', 'Construction-Special Trade', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Housing and Development' AND chamber='HOUSE'),
 'Housing and Development', 'HOUSE', NULL,
 'Real Estate Development', 'Land developers, property development, subdivisions',
 '531390', 'Other Activities Related to Real Estate', '6552', 'Land Subdividers and Developers', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Housing and Development' AND chamber='HOUSE'),
 'Housing and Development', 'HOUSE', NULL,
 'Building Materials', 'Lumber yards, hardware, building supply wholesale',
 '444', 'Building Material and Garden Equipment Dealers', '5211', 'Lumber and Building Materials Dealers', 'SECONDARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Housing and Development' AND chamber='HOUSE'),
 'Housing and Development', 'HOUSE', NULL,
 'Property Management', 'Apartment management, HOA management, rental properties',
 '531311', 'Residential Property Managers', '6512', 'Operators of Apartment Buildings', 'PRIMARY', NULL),

-- ========================================
-- INSURANCE
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Insurance' AND chamber='HOUSE'),
 'Insurance', 'HOUSE', NULL,
 'Health Insurance', 'Health plans, HMOs, Blue Cross, managed care',
 '524114', 'Direct Health and Medical Insurance Carriers', '6321', 'Accident and Health Insurance', 'PRIMARY', 'Blue Cross Blue Shield NC PAC gave $89K to Jackson'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Insurance' AND chamber='HOUSE'),
 'Insurance', 'HOUSE', NULL,
 'Property and Casualty Insurance', 'Auto, homeowners, commercial property, liability',
 '524126', 'Direct Property and Casualty Insurance Carriers', '6331', 'Fire, Marine, and Casualty Insurance', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Insurance' AND chamber='HOUSE'),
 'Insurance', 'HOUSE', NULL,
 'Life Insurance', 'Life insurance carriers, annuities',
 '524113', 'Direct Life Insurance Carriers', '6311', 'Life Insurance', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Insurance' AND chamber='HOUSE'),
 'Insurance', 'HOUSE', NULL,
 'Insurance Agents and Brokers', 'Independent agents, brokerages, adjusters',
 '524210', 'Insurance Agencies and Brokerages', '6411', 'Insurance Agents, Brokers, and Service', 'PRIMARY', NULL),

-- ========================================
-- JUDICIARY 1, 2, 3 (combined — same industry jurisdiction)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Judiciary 1' AND chamber='HOUSE'),
 'Judiciary 1', 'HOUSE', NULL,
 'Law Firms and Legal Services', 'Attorneys, law firms, legal aid',
 '541110', 'Offices of Lawyers', '8111', 'Legal Services', 'PRIMARY', 'NC Bar Association, NC Advocates for Justice (trial lawyers)'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Judiciary 1' AND chamber='HOUSE'),
 'Judiciary 1', 'HOUSE', NULL,
 'Bail Bonds and Corrections', 'Bail bondsmen, private prisons, probation services',
 '561990', 'All Other Support Services', '7389', 'Misc Business Services', 'SECONDARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Judiciary 2' AND chamber='HOUSE'),
 'Judiciary 2', 'HOUSE', NULL,
 'Law Firms and Legal Services', 'Attorneys, law firms, corporate law',
 '541110', 'Offices of Lawyers', '8111', 'Legal Services', 'PRIMARY', NULL),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Judiciary 2' AND chamber='HOUSE'),
 'Judiciary 2', 'HOUSE', NULL,
 'Firearms and Weapons', 'Gun manufacturers, firearms dealers, ammunition',
 '332994', 'Small Arms, Ordnance, and Ordnance Accessories Manufacturing', '3489', 'Ordnance and Accessories NEC', 'SECONDARY', 'Gun rights legislation, concealed carry'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Judiciary 3' AND chamber='HOUSE'),
 'Judiciary 3', 'HOUSE', NULL,
 'Law Firms and Legal Services', 'Attorneys, family law, civil litigation',
 '541110', 'Offices of Lawyers', '8111', 'Legal Services', 'PRIMARY', NULL),

-- ========================================
-- REGULATORY REFORM
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Regulatory Reform' AND chamber='HOUSE'),
 'Regulatory Reform', 'HOUSE', NULL,
 'Manufacturing (all)', 'Any manufacturer subject to state environmental/safety regulation',
 '31-33', 'Manufacturing', '2000-3999', 'Manufacturing', 'PRIMARY', 'Deregulation bills, permit streamlining'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Regulatory Reform' AND chamber='HOUSE'),
 'Regulatory Reform', 'HOUSE', NULL,
 'Construction', 'Building code reform, permitting, zoning',
 '236', 'Construction of Buildings', '1500', 'General Building Contractors', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Regulatory Reform' AND chamber='HOUSE'),
 'Regulatory Reform', 'HOUSE', NULL,
 'Environmental Consulting', 'Environmental impact, remediation, compliance',
 '541620', 'Environmental Consulting Services', '8999', 'Services NEC', 'SECONDARY', NULL),

-- ========================================
-- TRANSPORTATION
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='HOUSE'),
 'Transportation', 'HOUSE', NULL,
 'Highway and Road Construction', 'Road paving, bridge building, highway contractors',
 '237310', 'Highway, Street, and Bridge Construction', '1611', 'Highway and Street Construction', 'PRIMARY', 'Carolina Asphalt PAC. NCDOT contracts are massive'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='HOUSE'),
 'Transportation', 'HOUSE', NULL,
 'Trucking', 'Freight hauling, logistics, trucking companies',
 '484', 'Truck Transportation', '4210', 'Trucking and Courier Services', 'PRIMARY', 'Ezzell Trucking CEO gave $59K to Jackson'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='HOUSE'),
 'Transportation', 'HOUSE', NULL,
 'Auto Dealers', 'Motor vehicle dealers, used car lots, fleet sales',
 '441110', 'New Car Dealers', '5511', 'New and Used Car Dealers', 'PRIMARY', 'NC AutoPAC gave $106K to Jackson'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='HOUSE'),
 'Transportation', 'HOUSE', NULL,
 'Rail Transportation', 'Freight rail, passenger rail, Amtrak, commuter rail',
 '482', 'Rail Transportation', '4011', 'Railroads, Line-Haul Operating', 'SECONDARY', 'Norfolk Southern, CSX'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='HOUSE'),
 'Transportation', 'HOUSE', NULL,
 'Air Transportation', 'Airlines, airports, aviation services',
 '481', 'Air Transportation', '4512', 'Air Transportation, Scheduled', 'SECONDARY', 'CLT is American Airlines hub'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='HOUSE'),
 'Transportation', 'HOUSE', NULL,
 'Transit and Ground Passenger', 'Bus systems, ride-share, taxi, public transit',
 '485', 'Transit and Ground Passenger Transportation', '4111', 'Local and Suburban Transit', 'PRIMARY', 'CATS Charlotte, GoTriangle, GoRaleigh'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='HOUSE'),
 'Transportation', 'HOUSE', NULL,
 'Engineering Services', 'Civil engineering, transportation design, DOT consultants',
 '541330', 'Engineering Services', '8711', 'Engineering Services', 'SECONDARY', 'HNTB, WSP, Kimley-Horn — major DOT contract firms'),

-- ========================================
-- WILDLIFE RESOURCES
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Wildlife Resources' AND chamber='HOUSE'),
 'Wildlife Resources', 'HOUSE', NULL,
 'Hunting and Fishing Equipment', 'Firearms for hunting, fishing tackle, outdoor gear',
 '451110', 'Sporting Goods Stores', '5941', 'Sporting Goods Stores', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Wildlife Resources' AND chamber='HOUSE'),
 'Wildlife Resources', 'HOUSE', NULL,
 'Fishing Industry', 'Commercial and recreational fishing, aquaculture, marinas',
 '114', 'Fishing, Hunting and Trapping', '0900', 'Fishing Hunting Trapping', 'PRIMARY', 'NC coast fishing industry'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Wildlife Resources' AND chamber='HOUSE'),
 'Wildlife Resources', 'HOUSE', NULL,
 'Timber and Forestry', 'Logging operations, timber management, forest products',
 '113', 'Forestry and Logging', '0800', 'Forestry', 'SECONDARY', NULL),

-- ========================================
-- PENSIONS AND RETIREMENT
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Pensions and Retirement' AND chamber='HOUSE'),
 'Pensions and Retirement', 'HOUSE', NULL,
 'Investment Management', 'Asset managers, pension fund managers, fiduciary advisors',
 '523920', 'Portfolio Management', '6282', 'Investment Advice', 'PRIMARY', 'NC State Employees retirement system $100B+ AUM'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Pensions and Retirement' AND chamber='HOUSE'),
 'Pensions and Retirement', 'HOUSE', NULL,
 'Public Employee Unions', 'State employee associations, teacher retirement',
 '813930', 'Labor Unions and Similar Labor Organizations', '8631', 'Labor Unions', 'SECONDARY', 'SEANC - State Employees Assoc of NC'),

-- ========================================
-- EMERGENCY MANAGEMENT AND DISASTER RECOVERY
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Emergency Management and Disaster Recovery' AND chamber='HOUSE'),
 'Emergency Management and Disaster Recovery', 'HOUSE', NULL,
 'Insurance - Catastrophe', 'Flood insurance, wind/hail, coastal property insurance',
 '524126', 'Direct Property and Casualty Insurance Carriers', '6331', 'Fire, Marine, and Casualty Insurance', 'SECONDARY', 'Hurricane/flood zone policy'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Emergency Management and Disaster Recovery' AND chamber='HOUSE'),
 'Emergency Management and Disaster Recovery', 'HOUSE', NULL,
 'Disaster Restoration', 'Mold remediation, fire/water damage, debris removal',
 '562910', 'Remediation Services', '1794', 'Excavation Work', 'PRIMARY', 'Post-hurricane cleanup industry'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Emergency Management and Disaster Recovery' AND chamber='HOUSE'),
 'Emergency Management and Disaster Recovery', 'HOUSE', NULL,
 'Emergency Equipment', 'Fire apparatus, rescue equipment, emergency vehicles',
 '336120', 'Heavy Duty Truck Manufacturing', '3711', 'Motor Vehicles and Car Bodies', 'SECONDARY', NULL),

-- ========================================
-- ETHICS (minimal industry jurisdiction — oversight of legislators)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Ethics' AND chamber='HOUSE'),
 'Ethics', 'HOUSE', NULL,
 'Lobbying Firms', 'Registered lobbyists, government relations firms',
 '541820', 'Public Relations Agencies', '7311', 'Advertising Services', 'PRIMARY', 'Lobbyist registration and ethics compliance'),

-- ========================================
-- FEDERAL RELATIONS AND AMERICAN INDIAN AFFAIRS
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Federal Relations and American Indian Affairs' AND chamber='HOUSE'),
 'Federal Relations and American Indian Affairs', 'HOUSE', NULL,
 'Tribal Gaming', 'Casinos, gaming operations on tribal land',
 '713210', 'Casinos (except Casino Hotels)', '7993', 'Coin-Operated Amusement Devices', 'PRIMARY', 'Eastern Band of Cherokee Indians - Harrahs Cherokee'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Federal Relations and American Indian Affairs' AND chamber='HOUSE'),
 'Federal Relations and American Indian Affairs', 'HOUSE', NULL,
 'Federal Contracting', 'Entities with both federal and state regulatory exposure',
 '541990', 'All Other Professional, Scientific, and Technical Services', '8999', 'Services NEC', 'SECONDARY', 'Federal funding pass-through, Medicaid, highway funds'),

-- ========================================
-- STATE AND LOCAL GOVERNMENT
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='State and Local Government' AND chamber='HOUSE'),
 'State and Local Government', 'HOUSE', NULL,
 'Municipal Government Services', 'City/county government operations, annexation',
 '921', 'Executive, Legislative, and General Government', '9111', 'Executive Offices', 'PRIMARY', 'Municipal incorporation, annexation, zoning authority'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='State and Local Government' AND chamber='HOUSE'),
 'State and Local Government', 'HOUSE', NULL,
 'Public Works and Utilities', 'Municipal water/sewer, solid waste, public infrastructure',
 '562111', 'Solid Waste Collection', '4953', 'Refuse Systems', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='State and Local Government' AND chamber='HOUSE'),
 'State and Local Government', 'HOUSE', NULL,
 'Architecture and Planning', 'Urban planning, zoning consultants, architects',
 '541310', 'Architectural Services', '8712', 'Architectural Services', 'SECONDARY', NULL),

-- ========================================
-- OVERSIGHT (cross-cutting — watches all state agencies)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Oversight' AND chamber='HOUSE'),
 'Oversight', 'HOUSE', NULL,
 'Government IT and Consulting', 'State IT contracts, management consulting to state agencies',
 '541512', 'Computer Systems Design Services', '7371', 'Computer Services', 'SECONDARY', 'Major state IT vendors: Accenture, Deloitte, IBM'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Oversight' AND chamber='HOUSE'),
 'Oversight', 'HOUSE', NULL,
 'Audit and Accounting', 'State audit firms, financial compliance, internal controls',
 '541211', 'Offices of Certified Public Accountants', '7291', 'Tax Return Preparation', 'SECONDARY', NULL)
;

-- ============================================================================
-- NC SENATE COMMITTEES — INDUSTRY JURISDICTION WITH NAICS/SIC CODES
-- Senate has fewer committees but broader jurisdiction per committee.
-- ============================================================================
INSERT INTO state_legislature.committee_industry_jurisdiction 
    (committee_id, committee_name, chamber, subcommittee, industry_name, industry_detail, 
     naics_code, naics_title, sic_code, sic_title, jurisdiction_type, notes)
VALUES
-- ========================================
-- AGRICULTURE, ENERGY, AND ENVIRONMENT (Senate combines what House splits into 3)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture, Energy, and Environment' AND chamber='SENATE'),
 'Agriculture, Energy, and Environment', 'SENATE', NULL,
 'Crop Production', 'All row crops, tobacco, cotton, soybeans, sweet potatoes',
 '111', 'Crop Production', '0100', 'Crops', 'PRIMARY', 'Brent Jackson co-chairs. NC Farm Bureau $120K to him'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture, Energy, and Environment' AND chamber='SENATE'),
 'Agriculture, Energy, and Environment', 'SENATE', NULL,
 'Animal Production', 'Hog farming, poultry, cattle, aquaculture',
 '112', 'Animal Production and Aquaculture', '0200', 'Livestock', 'PRIMARY', 'Prestage Farms $117K to Jackson (3 family members)'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture, Energy, and Environment' AND chamber='SENATE'),
 'Agriculture, Energy, and Environment', 'SENATE', NULL,
 'Food Manufacturing', 'Meat packing, poultry processing, food products',
 '311', 'Food Manufacturing', '2000', 'Food and Kindred Products', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture, Energy, and Environment' AND chamber='SENATE'),
 'Agriculture, Energy, and Environment', 'SENATE', NULL,
 'Electric Utilities', 'Duke Energy, cooperatives, power generation',
 '2211', 'Electric Power Generation, Transmission and Distribution', '4911', 'Electric Services', 'PRIMARY', 'Duke Energy PAC $93K to Jackson'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture, Energy, and Environment' AND chamber='SENATE'),
 'Agriculture, Energy, and Environment', 'SENATE', NULL,
 'Solar Energy', 'Solar farms, solar development, renewable energy',
 '221114', 'Solar Electric Power Generation', NULL, NULL, 'PRIMARY', 'NC #2 nationally in solar'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture, Energy, and Environment' AND chamber='SENATE'),
 'Agriculture, Energy, and Environment', 'SENATE', NULL,
 'Natural Gas', 'Gas utilities, pipeline companies',
 '2212', 'Natural Gas Distribution', '4924', 'Natural Gas Distribution', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture, Energy, and Environment' AND chamber='SENATE'),
 'Agriculture, Energy, and Environment', 'SENATE', NULL,
 'Environmental Services', 'Waste management, water treatment, hog lagoon compliance',
 '562', 'Waste Management and Remediation Services', '4950', 'Sanitary Services', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Agriculture, Energy, and Environment' AND chamber='SENATE'),
 'Agriculture, Energy, and Environment', 'SENATE', NULL,
 'Telecommunications', 'Broadband, cable, wireless, fiber-to-home',
 '517', 'Telecommunications', '4810', 'Telephone Communications', 'PRIMARY', 'AT&T NC PAC $49K to Jackson'),

-- ========================================
-- COMMERCE AND INSURANCE
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Insurance' AND chamber='SENATE'),
 'Commerce and Insurance', 'SENATE', NULL,
 'Banking', 'Commercial banking, credit unions, state-chartered banks',
 '522', 'Credit Intermediation and Related Activities', '6020', 'Commercial Banks', 'PRIMARY', 'Bank of America, First Citizens, Truist HQd in NC'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Insurance' AND chamber='SENATE'),
 'Commerce and Insurance', 'SENATE', NULL,
 'Health Insurance', 'BCBSNC, managed care, health plans',
 '524114', 'Direct Health and Medical Insurance Carriers', '6321', 'Accident and Health Insurance', 'PRIMARY', NULL),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Insurance' AND chamber='SENATE'),
 'Commerce and Insurance', 'SENATE', NULL,
 'Property and Casualty Insurance', 'Auto, homeowners, commercial property, liability',
 '524126', 'Direct Property and Casualty Insurance Carriers', '6331', 'Fire, Marine, Casualty Insurance', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Insurance' AND chamber='SENATE'),
 'Commerce and Insurance', 'SENATE', NULL,
 'Real Estate', 'Development, brokerage, property management',
 '531', 'Real Estate', '6500', 'Real Estate', 'PRIMARY', 'NC Realtors PAC'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Insurance' AND chamber='SENATE'),
 'Commerce and Insurance', 'SENATE', NULL,
 'Auto Dealers', 'New/used car dealers, franchised dealers',
 '441110', 'New Car Dealers', '5511', 'Motor Vehicle Dealers', 'SECONDARY', 'NC AutoPAC'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Commerce and Insurance' AND chamber='SENATE'),
 'Commerce and Insurance', 'SENATE', NULL,
 'Securities and Investment', 'Broker-dealers, financial advisors, investment banks',
 '523', 'Securities and Other Financial Investments', '6200', 'Security and Commodity Brokers', 'PRIMARY', NULL),

-- ========================================
-- EDUCATION/HIGHER EDUCATION
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Education/Higher Education' AND chamber='SENATE'),
 'Education/Higher Education', 'SENATE', NULL,
 'K-12 Public Schools', 'Public school systems, charter schools',
 '611110', 'Elementary and Secondary Schools', '8211', 'Elementary and Secondary Schools', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Education/Higher Education' AND chamber='SENATE'),
 'Education/Higher Education', 'SENATE', NULL,
 'Universities', 'UNC System, private colleges, community colleges',
 '611310', 'Colleges, Universities, and Professional Schools', '8221', 'Colleges and Universities', 'PRIMARY', NULL),

-- ========================================
-- FINANCE (Senate)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='SENATE'),
 'Finance', 'SENATE', NULL,
 'Banking and Financial Services', 'All entities subject to state tax policy',
 '522', 'Credit Intermediation and Related Activities', '6020', 'Commercial Banks', 'PRIMARY', 'NC tax code — corporate, personal income, franchise tax'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='SENATE'),
 'Finance', 'SENATE', NULL,
 'Tobacco', 'Cigarette/tobacco tax, vaping regulation',
 '312230', 'Tobacco Manufacturing', '2111', 'Cigarettes', 'PRIMARY', 'Excise tax rates, tobacco settlement'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='SENATE'),
 'Finance', 'SENATE', NULL,
 'Real Estate', 'Property tax, transfer tax, recording fees',
 '531', 'Real Estate', '6500', 'Real Estate', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Finance' AND chamber='SENATE'),
 'Finance', 'SENATE', NULL,
 'Accounting and Tax Prep', 'CPAs, tax advisors, enrolled agents',
 '541211', 'Offices of Certified Public Accountants', '7291', 'Tax Return Preparation', 'PRIMARY', NULL),

-- ========================================
-- HEALTH CARE (Senate)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health Care' AND chamber='SENATE'),
 'Health Care', 'SENATE', NULL,
 'Hospitals', 'Hospital systems, medical centers',
 '622', 'Hospitals', '8060', 'Hospitals', 'PRIMARY', 'NC Hospital Assoc'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health Care' AND chamber='SENATE'),
 'Health Care', 'SENATE', NULL,
 'Physicians', 'Medical practices, specialty groups',
 '621111', 'Offices of Physicians', '8011', 'Offices of Doctors of Medicine', 'PRIMARY', 'NC Medical Society'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health Care' AND chamber='SENATE'),
 'Health Care', 'SENATE', NULL,
 'Dentists', 'Dental practices',
 '621210', 'Offices of Dentists', '8021', 'Offices of Dentists', 'PRIMARY', 'NC Dental PAC'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health Care' AND chamber='SENATE'),
 'Health Care', 'SENATE', NULL,
 'Nursing Facilities', 'Nursing homes, assisted living, long-term care',
 '623', 'Nursing and Residential Care Facilities', '8051', 'Skilled Nursing Care', 'PRIMARY', 'NC Health Care Facilities Assoc'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Health Care' AND chamber='SENATE'),
 'Health Care', 'SENATE', NULL,
 'Pharmaceuticals', 'Drug manufacturers, pharmacy chains, PBMs',
 '325410', 'Pharmaceutical and Medicine Manufacturing', '2834', 'Pharmaceutical Preparations', 'PRIMARY', 'Medicaid drug formulary, pharmacy regulation'),

-- ========================================
-- JUDICIARY (Senate)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Judiciary' AND chamber='SENATE'),
 'Judiciary', 'SENATE', NULL,
 'Law Firms', 'Attorneys, law firms, legal services',
 '541110', 'Offices of Lawyers', '8111', 'Legal Services', 'PRIMARY', 'Trial lawyers vs defense bar — both donate heavily'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Judiciary' AND chamber='SENATE'),
 'Judiciary', 'SENATE', NULL,
 'Firearms', 'Gun manufacturers, dealers, ammunition, concealed carry',
 '332994', 'Small Arms Manufacturing', '3489', 'Ordnance and Accessories NEC', 'SECONDARY', 'Gun rights legislation'),

-- ========================================
-- REGULATORY REFORM (Senate)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Regulatory Reform' AND chamber='SENATE'),
 'Regulatory Reform', 'SENATE', NULL,
 'Manufacturing', 'All manufacturing subject to state regulation',
 '31-33', 'Manufacturing', '2000-3999', 'Manufacturing', 'PRIMARY', 'Permit streamlining, environmental deregulation'),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Regulatory Reform' AND chamber='SENATE'),
 'Regulatory Reform', 'SENATE', NULL,
 'Construction', 'Building codes, permitting, occupational licensing',
 '236', 'Construction of Buildings', '1500', 'General Building Contractors', 'PRIMARY', NULL),

-- ========================================
-- TRANSPORTATION (Senate)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='SENATE'),
 'Transportation', 'SENATE', NULL,
 'Highway Construction', 'Road paving, bridge, DOT contractors',
 '237310', 'Highway, Street, and Bridge Construction', '1611', 'Highway and Street Construction', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='SENATE'),
 'Transportation', 'SENATE', NULL,
 'Trucking', 'Freight hauling, logistics',
 '484', 'Truck Transportation', '4210', 'Trucking and Courier Services', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='SENATE'),
 'Transportation', 'SENATE', NULL,
 'Auto Dealers', 'Vehicle sales, dealer licensing, franchise law',
 '441110', 'New Car Dealers', '5511', 'Motor Vehicle Dealers', 'PRIMARY', NULL),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Transportation' AND chamber='SENATE'),
 'Transportation', 'SENATE', NULL,
 'Engineering', 'Civil engineering, DOT design consultants',
 '541330', 'Engineering Services', '8711', 'Engineering Services', 'SECONDARY', NULL),

-- ========================================
-- STATE AND LOCAL GOVERNMENT (Senate)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='State and Local Government' AND chamber='SENATE'),
 'State and Local Government', 'SENATE', NULL,
 'Municipal Operations', 'City/county government, annexation, zoning',
 '921', 'Executive, Legislative, and General Government', '9111', 'Executive Offices', 'PRIMARY', NULL),
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='State and Local Government' AND chamber='SENATE'),
 'State and Local Government', 'SENATE', NULL,
 'Public Works', 'Municipal water, sewer, solid waste',
 '562111', 'Solid Waste Collection', '4953', 'Refuse Systems', 'PRIMARY', NULL),

-- ========================================
-- ELECTIONS (Senate)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Elections' AND chamber='SENATE'),
 'Elections', 'SENATE', NULL,
 'Political Consulting', 'Campaign consultants, pollsters, mailers',
 '541820', 'Public Relations Agencies', '7311', 'Advertising Services', 'PRIMARY', NULL),

-- ========================================
-- PENSIONS AND RETIREMENT AND AGING (Senate)
-- ========================================
((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Pensions and Retirement and Aging' AND chamber='SENATE'),
 'Pensions and Retirement and Aging', 'SENATE', NULL,
 'Investment Management', 'Pension fund managers, asset managers',
 '523920', 'Portfolio Management', '6282', 'Investment Advice', 'PRIMARY', 'NC Retirement Systems $100B+ AUM'),

((SELECT committee_id FROM state_legislature.ncga_committees WHERE committee_name='Pensions and Retirement and Aging' AND chamber='SENATE'),
 'Pensions and Retirement and Aging', 'SENATE', NULL,
 'Senior Care', 'Assisted living, home health, elder services',
 '623', 'Nursing and Residential Care Facilities', '8051', 'Skilled Nursing Care', 'SECONDARY', 'Aging population policy')
;

-- ============================================================================
-- SECTION: SEED EMPLOYER NAICS CLASSIFICATIONS
-- Top NC political donor employers, manually classified
-- These are verified from the Jackson donor analysis and known NC entities
-- ============================================================================
INSERT INTO state_legislature.employer_naics_classification 
    (employer_name, employer_normalized, naics_code, naics_title, sic_code, confidence, source)
VALUES
('HOG SLATS', 'HOG SLATS', '332999', 'Miscellaneous Fabricated Metal Product Mfg', '3499', 'HIGH', 'MANUAL'),
('PRESTAGE FARMS', 'PRESTAGE FARMS', '112210', 'Hog and Pig Farming', '0213', 'HIGH', 'MANUAL'),
('EZZELL TRUCKING, INC.', 'EZZELL TRUCKING', '484121', 'General Freight Trucking, Long-Distance', '4213', 'HIGH', 'MANUAL'),
('STRATA SOLAR', 'STRATA SOLAR', '221114', 'Solar Electric Power Generation', NULL, 'HIGH', 'MANUAL'),
('NC HORSE COUNCIL', 'NC HORSE COUNCIL', '813910', 'Business Associations', '8611', 'HIGH', 'MANUAL'),
('WAKE FOREST SCHOOL OF MEDICINE', 'WAKE FOREST SCHOOL OF MEDICINE', '611310', 'Colleges and Universities', '8221', 'HIGH', 'MANUAL'),
('HOUSE OF REAFORD HOMES', 'HOUSE OF RAEFORD', '311615', 'Poultry Processing', '2015', 'HIGH', 'MANUAL'),
('FOOD LION', 'FOOD LION', '445110', 'Supermarkets and Grocery Stores', '5411', 'HIGH', 'MANUAL'),
('SAS', 'SAS INSTITUTE', '511210', 'Software Publishers', '7372', 'HIGH', 'MANUAL'),
('DUKE ENERGY', 'DUKE ENERGY', '221112', 'Fossil Fuel Electric Power Generation', '4911', 'HIGH', 'MANUAL'),
('BLUE CROSS AND BLUE SHIELD', 'BCBSNC', '524114', 'Direct Health and Medical Insurance', '6321', 'HIGH', 'MANUAL'),
('BANK OF AMERICA', 'BANK OF AMERICA', '522110', 'Commercial Banking', '6021', 'HIGH', 'MANUAL'),
('WELLS FARGO', 'WELLS FARGO', '522110', 'Commercial Banking', '6021', 'HIGH', 'MANUAL'),
('LOWES', 'LOWES', '444110', 'Home Centers', '5211', 'HIGH', 'MANUAL'),
('SMITHFIELD FOODS', 'SMITHFIELD FOODS', '311611', 'Animal Slaughtering', '2011', 'HIGH', 'MANUAL'),
('BUTTERBALL', 'BUTTERBALL', '311615', 'Poultry Processing', '2015', 'HIGH', 'MANUAL'),
('AT&T', 'AT&T', '517311', 'Wired Telecommunications Carriers', '4813', 'HIGH', 'MANUAL'),
('SPECTRUM', 'CHARTER COMMUNICATIONS', '517311', 'Wired Telecommunications Carriers', '4841', 'HIGH', 'MANUAL'),
('CRUMPLER PLASTIC PIPE', 'CRUMPLER PLASTIC PIPE', '326122', 'Plastics Pipe and Pipe Fitting Mfg', '3084', 'HIGH', 'MANUAL'),
('FAIRCLOTH FARMS', 'FAIRCLOTH FARMS', '111998', 'All Other Miscellaneous Crop Farming', '0191', 'HIGH', 'MANUAL'),
('RESTORATION SYSTEMS', 'RESTORATION SYSTEMS', '541620', 'Environmental Consulting Services', '8999', 'HIGH', 'MANUAL'),
('PRESTON DEVELOPMENT', 'PRESTON DEVELOPMENT', '531390', 'Other Real Estate Activities', '6552', 'HIGH', 'MANUAL'),
('R. A. JEFFREYS DISTRIBUTING', 'RA JEFFREYS DISTRIBUTING', '424810', 'Beer and Ale Merchant Wholesalers', '5181', 'HIGH', 'MANUAL'),
('KIMLEY-HORN', 'KIMLEY-HORN', '541330', 'Engineering Services', '8711', 'HIGH', 'MANUAL'),
('DELOITTE', 'DELOITTE', '541211', 'Offices of Certified Public Accountants', '7291', 'HIGH', 'MANUAL'),
('MCGUIREWOODS', 'MCGUIREWOODS', '541110', 'Offices of Lawyers', '8111', 'HIGH', 'MANUAL'),
('BROOKS PIERCE', 'BROOKS PIERCE', '541110', 'Offices of Lawyers', '8111', 'HIGH', 'MANUAL'),
('MOORE AND VAN ALLEN', 'MOORE AND VAN ALLEN', '541110', 'Offices of Lawyers', '8111', 'HIGH', 'MANUAL'),
('WOMBLE BOND DICKINSON', 'WOMBLE BOND DICKINSON', '541110', 'Offices of Lawyers', '8111', 'HIGH', 'MANUAL'),
('KILPATRICK TOWNSEND', 'KILPATRICK TOWNSEND', '541110', 'Offices of Lawyers', '8111', 'HIGH', 'MANUAL'),
('PARKER POE', 'PARKER POE', '541110', 'Offices of Lawyers', '8111', 'HIGH', 'MANUAL'),
('SMITH ANDERSON', 'SMITH ANDERSON', '541110', 'Offices of Lawyers', '8111', 'HIGH', 'MANUAL')
ON CONFLICT (employer_normalized) DO NOTHING;

-- ============================================================================
-- ANALYTICAL VIEW: Donor-to-Committee Industry Match
-- This is the money shot. For each donation, check if the donor's employer
-- industry (via NAICS) matches the committee jurisdiction of the legislator
-- they're donating to. A match = regulatory access donation.
-- ============================================================================
CREATE OR REPLACE VIEW state_legislature.vw_donor_regulatory_access AS
WITH donor_employers AS (
    SELECT 
        d.donor_name,
        d.employer_name,
        d.profession_job_title,
        d.city AS donor_city,
        d.norm_zip5 AS donor_zip,
        d.committee_name AS recipient_committee,
        d.committee_sboe_id,
        SUM(d.amount_numeric) AS total_donated,
        COUNT(*) AS donation_count,
        -- Try to match employer to NAICS classification
        enc.naics_code AS employer_naics,
        enc.naics_title AS employer_industry
    FROM public.nc_boe_donations_raw d
    LEFT JOIN state_legislature.employer_naics_classification enc
        ON d.employer_name ILIKE '%' || enc.employer_normalized || '%'
    WHERE d.amount_numeric > 0
      AND d.employer_name IS NOT NULL
      AND d.employer_name != ''
    GROUP BY d.donor_name, d.employer_name, d.profession_job_title,
        d.city, d.norm_zip5, d.committee_name, d.committee_sboe_id,
        enc.naics_code, enc.naics_title
)
SELECT 
    de.*,
    m.full_name AS legislator_name,
    m.chamber,
    m.district,
    m.county AS legislator_county,
    m.party,
    -- Check if employer NAICS matches ANY committee the legislator sits on
    EXISTS (
        SELECT 1 
        FROM state_legislature.ncga_assignments a
        JOIN state_legislature.committee_industry_jurisdiction cij 
            ON cij.committee_id = a.committee_id
        WHERE a.member_id = m.member_id
          AND de.employer_naics IS NOT NULL
          AND LEFT(cij.naics_code, 3) = LEFT(de.employer_naics, 3)
    ) AS regulatory_access_match,
    -- What committee jurisdiction does this employer fall under?
    (SELECT STRING_AGG(DISTINCT cij.committee_name, ', ')
     FROM state_legislature.ncga_assignments a
     JOIN state_legislature.committee_industry_jurisdiction cij 
         ON cij.committee_id = a.committee_id
     WHERE a.member_id = m.member_id
       AND de.employer_naics IS NOT NULL
       AND LEFT(cij.naics_code, 3) = LEFT(de.employer_naics, 3)
    ) AS matched_committees
FROM donor_employers de
JOIN state_legislature.ncga_members m 
    ON de.recipient_committee ILIKE '%' || SPLIT_PART(m.full_name, ' ', 
        ARRAY_LENGTH(STRING_TO_ARRAY(m.full_name, ' '), 1)) || '%'
    AND de.recipient_committee ILIKE '%' || SPLIT_PART(m.full_name, ' ', 1) || '%'
WHERE de.total_donated >= 1000;

-- ============================================================================
-- SUMMARY VIEW: Top Regulatory Access Donors by Legislator
-- Aggregates the regulatory access matches into a ranked donor list
-- ============================================================================
CREATE OR REPLACE VIEW state_legislature.vw_top_regulatory_access_donors AS
SELECT 
    legislator_name,
    chamber,
    party,
    donor_name,
    employer_name,
    employer_industry,
    total_donated,
    donation_count,
    donor_city,
    donor_zip,
    matched_committees,
    regulatory_access_match
FROM state_legislature.vw_donor_regulatory_access
WHERE regulatory_access_match = TRUE
ORDER BY total_donated DESC;

-- ============================================================================
-- POST-DEPLOYMENT VERIFICATION
-- ============================================================================
-- SELECT committee_name, chamber, COUNT(*) AS industry_count 
--   FROM state_legislature.committee_industry_jurisdiction 
--   GROUP BY committee_name, chamber ORDER BY chamber, committee_name;
--
-- SELECT * FROM state_legislature.employer_naics_classification ORDER BY employer_normalized;
--
-- SELECT * FROM state_legislature.vw_top_regulatory_access_donors LIMIT 20;
--
-- TEST: Brent Jackson regulatory access donors
-- SELECT donor_name, employer_name, employer_industry, total_donated, matched_committees
--   FROM state_legislature.vw_donor_regulatory_access
--   WHERE legislator_name = 'Brent Jackson' AND regulatory_access_match = TRUE
--   ORDER BY total_donated DESC LIMIT 20;
