-- ============================================================================
-- DONOR SIC CLASSIFICATION ENGINE
-- BroyhillGOP Database Migration
-- Created: 2026-03-15
-- Schema: donor_intelligence
-- ============================================================================
-- This migration creates the full SIC/NAICS industry classification system:
--   1. sic_divisions (80 rows) - SIC major group reference table
--   2. sic_keyword_patterns (272 rows) - Employer name → SIC mapping
--   3. profession_sic_patterns (74 rows) - Profession/job title → SIC fallback
--   4. employer_sic_master (62,100 rows) - Classified donor profiles
--   5. ecosystem_definitions (7 rows) - Charlotte micro-ecosystem geography
--   6. Views: vw_donor_sic_donations, vw_district_donor_prospects,
--      vw_industry_to_committee, vw_industry_by_zip, vw_ecosystem_industry_profile
--   7. 28 indexes across all tables
-- ============================================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS donor_intelligence;

-- ============================================================================
-- SECTION 1: SIC DIVISIONS REFERENCE TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_intelligence.sic_divisions (
    sic_division VARCHAR(2) PRIMARY KEY,
    division_name TEXT NOT NULL,
    division_range VARCHAR(10),
    naics_sector VARCHAR(2)
);

INSERT INTO donor_intelligence.sic_divisions (sic_division, division_name, division_range, naics_sector) VALUES
('01', 'Agriculture - Crops', '01-07', '11'),
('02', 'Agriculture - Livestock', '01-07', '11'),
('07', 'Agriculture Services', '07-09', '11'),
('08', 'Forestry', '07-09', '11'),
('09', 'Fishing/Hunting/Trapping', '07-09', '11'),
('10', 'Metal Mining', '10-14', '21'),
('12', 'Coal Mining', '10-14', '21'),
('13', 'Oil and Gas Extraction', '10-14', '21'),
('14', 'Mining - Nonmetallic', '10-14', '21'),
('15', 'Construction - General', '15-17', '23'),
('16', 'Construction - Heavy', '15-17', '23'),
('17', 'Construction - Special Trade', '15-17', '23'),
('20', 'Food and Kindred Products', '20-39', '31'),
('22', 'Textile Mill Products', '20-39', '31'),
('23', 'Apparel', '20-39', '31'),
('24', 'Lumber and Wood', '20-39', '32'),
('25', 'Furniture and Fixtures', '20-39', '33'),
('26', 'Paper', '20-39', '32'),
('27', 'Printing and Publishing', '20-39', '51'),
('28', 'Chemicals', '20-39', '32'),
('29', 'Petroleum Refining', '20-39', '32'),
('30', 'Rubber and Plastics', '20-39', '32'),
('31', 'Leather', '20-39', '31'),
('32', 'Stone/Clay/Glass', '20-39', '32'),
('33', 'Primary Metals', '20-39', '33'),
('34', 'Fabricated Metals', '20-39', '33'),
('35', 'Industrial Machinery', '20-39', '33'),
('36', 'Electronic Equipment', '20-39', '33'),
('37', 'Transportation Equipment', '20-39', '33'),
('38', 'Instruments', '20-39', '33'),
('39', 'Misc Manufacturing', '20-39', '33'),
('40', 'Railroad Transportation', '40-49', '48'),
('41', 'Local Passenger Transit', '40-49', '48'),
('42', 'Motor Freight/Warehousing', '40-49', '48'),
('44', 'Water Transportation', '40-49', '48'),
('45', 'Air Transportation', '40-49', '48'),
('46', 'Pipelines', '40-49', '48'),
('47', 'Transportation Services', '40-49', '48'),
('48', 'Communications', '40-49', '51'),
('49', 'Electric/Gas/Sanitary', '40-49', '22'),
('50', 'Wholesale - Durable', '50-51', '42'),
('51', 'Wholesale - Nondurable', '50-51', '42'),
('52', 'Retail - Building Materials', '52-59', '44'),
('53', 'Retail - General Merchandise', '52-59', '45'),
('54', 'Retail - Food', '52-59', '44'),
('55', 'Retail - Auto Dealers', '52-59', '44'),
('56', 'Retail - Apparel', '52-59', '44'),
('57', 'Retail - Furniture', '52-59', '44'),
('58', 'Retail - Eating/Drinking', '52-59', '72'),
('59', 'Retail - Misc', '52-59', '44'),
('60', 'Depository Institutions', '60-67', '52'),
('61', 'Nondepository Credit', '60-67', '52'),
('62', 'Security/Commodity Brokers', '60-67', '52'),
('63', 'Insurance Carriers', '60-67', '52'),
('64', 'Insurance Agents', '60-67', '52'),
('65', 'Real Estate', '60-67', '53'),
('67', 'Holding/Investment Offices', '60-67', '55'),
('70', 'Hotels/Lodging', '70-89', '72'),
('72', 'Personal Services', '70-89', '81'),
('73', 'Business Services', '70-89', '54'),
('75', 'Auto Repair/Services', '70-89', '81'),
('76', 'Misc Repair Services', '70-89', '81'),
('78', 'Motion Pictures', '70-89', '51'),
('79', 'Amusement/Recreation', '70-89', '71'),
('80', 'Health Services', '70-89', '62'),
('81', 'Legal Services', '70-89', '54'),
('82', 'Educational Services', '70-89', '61'),
('83', 'Social Services', '70-89', '62'),
('84', 'Museums/Gardens', '70-89', '71'),
('86', 'Membership Organizations', '70-89', '81'),
('87', 'Engineering/Management', '70-89', '54'),
('89', 'Misc Services', '70-89', '81'),
('91', 'Executive/Legislative', '91-99', '92'),
('92', 'Justice/Public Order', '91-99', '92'),
('93', 'Public Finance', '91-99', '92'),
('94', 'Administration - Human Resources', '91-99', '92'),
('95', 'Administration - Environmental', '91-99', '92'),
('96', 'Administration - Economic', '91-99', '92'),
('97', 'National Security', '91-99', '92'),
('99', 'Nonclassifiable', '91-99', '99')
ON CONFLICT (sic_division) DO NOTHING;

-- ============================================================================
-- SECTION 2: SIC KEYWORD PATTERNS (272 employer name → SIC mappings)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_intelligence.sic_keyword_patterns (
    pattern_id SERIAL PRIMARY KEY,
    keyword_pattern TEXT NOT NULL UNIQUE,
    sic_code VARCHAR(4) NOT NULL,
    sic_division VARCHAR(2) NOT NULL,
    sic_description TEXT,
    naics_code VARCHAR(6),
    match_priority INTEGER DEFAULT 50,
    match_type VARCHAR(20) DEFAULT 'CONTAINS'
);

INSERT INTO donor_intelligence.sic_keyword_patterns (keyword_pattern, sic_code, sic_division, sic_description, naics_code, match_priority, match_type) VALUES
-- Division 01: Agriculture - Crops
('%TOBACCO%', '0132', '01', 'Tobacco', '111910', 60, 'CONTAINS'),
('%NURSERY%', '0181', '01', 'Ornamental Nursery Products', '111421', 50, 'CONTAINS'),
('%FARM%', '0100', '01', 'Farms - General', '111000', 30, 'CONTAINS'),
-- Division 02: Agriculture - Livestock
('%MURPHY FAMILY%', '0213', '02', 'Hog and Pig Farming', '112210', 95, 'CONTAINS'),
('%PRESTAGE%', '0213', '02', 'Hog and Pig Farming', '112210', 95, 'CONTAINS'),
('%BRASWELL%FARM%', '0250', '02', 'Poultry and Eggs', '112300', 95, 'CONTAINS'),
('%DAIRY%', '0240', '02', 'Dairy Farms', '112120', 60, 'CONTAINS'),
('%HOG%', '0213', '02', 'Hog and Pig Farming', '112210', 60, 'CONTAINS'),
('%POULTRY%', '0250', '02', 'Poultry and Eggs', '112300', 60, 'CONTAINS'),
('%CATTLE%', '0212', '02', 'Beef Cattle', '112111', 60, 'CONTAINS'),
-- Division 07: Agriculture Services
('%VETERINAR%', '0742', '07', 'Veterinary Services', '541940', 60, 'CONTAINS'),
('%LANDSCAP%', '0782', '07', 'Lawn and Garden Services', '561730', 50, 'CONTAINS'),
('%LAWN%', '0782', '07', 'Lawn and Garden Services', '561730', 40, 'CONTAINS'),
-- Division 08: Forestry
('%TIMBER%', '0811', '08', 'Timber Tracts', '113110', 50, 'CONTAINS'),
('%FORESTRY%', '0811', '08', 'Forestry', '113110', 50, 'CONTAINS'),
-- Division 10-14: Mining
('%MINING%', '1000', '10', 'Mining', '212000', 50, 'CONTAINS'),
('%MARTIN MARIETTA%', '1400', '14', 'Mining - Crushed Stone', '212312', 95, 'CONTAINS'),
('%QUARRY%', '1400', '14', 'Mining - Nonmetallic Minerals', '212310', 60, 'CONTAINS'),
('%GRAVEL%', '1440', '14', 'Sand and Gravel', '212321', 50, 'CONTAINS'),
('%AGGREGATE%', '1400', '14', 'Mining - Nonmetallic Minerals', '212310', 50, 'CONTAINS'),
('%SAND %', '1440', '14', 'Sand and Gravel', '212321', 40, 'CONTAINS'),
-- Division 15: Construction - General
('%MILLS CONSTRUCTION%', '1500', '15', 'General Construction', '236220', 95, 'CONTAINS'),
('%VANNOY CONSTRUCTION%', '1500', '15', 'General Construction', '236220', 95, 'CONTAINS'),
('%LOGAN HOMES%', '1522', '15', 'Residential Construction', '236115', 95, 'CONTAINS'),
('%HOMEBUILDER%', '1522', '15', 'Residential Construction', '236115', 70, 'CONTAINS'),
('%GENERAL CONTRACTOR%', '1520', '15', 'General Building Contractors', '236220', 70, 'CONTAINS'),
('%HOME BUILD%', '1522', '15', 'Residential Construction', '236115', 60, 'CONTAINS'),
('%CONSTRUCTION%', '1500', '15', 'General Construction', '236000', 40, 'CONTAINS'),
('%BUILDER%', '1522', '15', 'General Building Contractors', '236220', 30, 'CONTAINS'),
-- Division 16: Construction - Heavy
('%BARNHILL CONTRACTING%', '1611', '16', 'Highway Construction', '237310', 95, 'CONTAINS'),
('%FRED SMITH COMPANY%', '1611', '16', 'Highway Construction', '237310', 95, 'CONTAINS'),
('%HIGHLAND PAVING%', '1611', '16', 'Highway Construction', '237310', 95, 'CONTAINS'),
('%PAVING%', '1611', '16', 'Highway and Street Construction', '237310', 60, 'CONTAINS'),
-- Division 17: Construction - Special Trade
('%HVAC%', '1711', '17', 'Plumbing, Heating, AC', '238220', 70, 'CONTAINS'),
('%ELECTRIC%CONTRACT%', '1731', '17', 'Electrical Work', '238210', 70, 'CONTAINS'),
('%DRYWALL%', '1742', '17', 'Plastering and Drywall', '238310', 60, 'CONTAINS'),
('%HEATING%COOLING%', '1711', '17', 'Plumbing, Heating, AC', '238220', 60, 'CONTAINS'),
('%STEEL%FAB%', '1791', '17', 'Structural Steel Erection', '238120', 60, 'CONTAINS'),
('%ROOFING%', '1761', '17', 'Roofing and Sheet Metal', '238160', 60, 'CONTAINS'),
('%EXCAVAT%', '1794', '17', 'Excavation Work', '238910', 60, 'CONTAINS'),
('%PAINTING%CONTRACT%', '1721', '17', 'Painting and Paper Hanging', '238320', 60, 'CONTAINS'),
('%MASONRY%', '1741', '17', 'Masonry and Stonework', '238140', 60, 'CONTAINS'),
('%PLUMBING%', '1711', '17', 'Plumbing, Heating, AC', '238220', 60, 'CONTAINS'),
('%GRADING%', '1794', '17', 'Excavation Work', '238910', 50, 'CONTAINS'),
('%CONCRETE%', '1771', '17', 'Concrete Work', '238110', 50, 'CONTAINS'),
('%SITE WORK%', '1794', '17', 'Excavation Work', '238910', 50, 'CONTAINS'),
('%FRAMING%', '1751', '17', 'Carpentry Work', '238130', 40, 'CONTAINS'),
('%INSULATION%', '1742', '17', 'Insulation Work', '238310', 40, 'CONTAINS'),
('%ELECTRICAL%', '1731', '17', 'Electrical Work', '238210', 30, 'CONTAINS'),
-- Division 20: Food and Kindred Products
('%BREWERY%', '2082', '20', 'Malt Beverages', '312120', 70, 'CONTAINS'),
('%BREWING%', '2082', '20', 'Malt Beverages', '312120', 60, 'CONTAINS'),
('%DISTILLER%', '2085', '20', 'Distilled Spirits', '312140', 60, 'CONTAINS'),
('%BOTTLING%', '2086', '20', 'Bottled Beverages', '312111', 60, 'CONTAINS'),
('%MEAT%PACK%', '2011', '20', 'Meat Packing Plants', '311611', 60, 'CONTAINS'),
('%BAKERY%', '2050', '20', 'Bakery Products', '311810', 50, 'CONTAINS'),
('%FOOD PROCESS%', '2000', '20', 'Food and Kindred Products', '311000', 50, 'CONTAINS'),
('%BEVERAGE%', '2080', '20', 'Beverages', '312100', 40, 'CONTAINS'),
-- Division 22-39: Manufacturing
('%TEXTILE%', '2200', '22', 'Textile Mill Products', '313000', 40, 'CONTAINS'),
('%FABRIC%', '2281', '22', 'Yarn Throwing and Winding', '313110', 40, 'CONTAINS'),
('%LUMBER%', '2421', '24', 'Sawmills and Planing Mills', '321113', 50, 'CONTAINS'),
('%FURNITURE%MANUFACT%', '2510', '25', 'Household Furniture', '337000', 60, 'CONTAINS'),
('%PAPER%MILL%', '2621', '26', 'Paper Mills', '322121', 60, 'CONTAINS'),
('%PRINTING%', '2750', '27', 'Commercial Printing', '323111', 40, 'CONTAINS'),
('%PHARMACEUTICAL%', '2834', '28', 'Pharmaceutical Preparations', '325412', 60, 'CONTAINS'),
('%PHARMA%', '2834', '28', 'Pharmaceutical Preparations', '325412', 50, 'CONTAINS'),
('%CHEMICAL%', '2800', '28', 'Chemicals', '325000', 40, 'CONTAINS'),
('%PLASTICS%', '3080', '30', 'Plastics Products', '326000', 40, 'CONTAINS'),
('%RUBBER%', '3000', '30', 'Rubber Products', '326200', 40, 'CONTAINS'),
('%CHARLOTTE PIPE%', '3321', '33', 'Gray Iron Foundries - Pipe', '331511', 95, 'CONTAINS'),
('%PIPE%FOUNDRY%', '3321', '33', 'Gray Iron Foundries', '331511', 80, 'CONTAINS'),
('%FOUNDRY%', '3320', '33', 'Iron and Steel Foundries', '331500', 50, 'CONTAINS'),
('%CAPTIVEAIRE%', '3585', '35', 'Refrigeration and Heating Equipment', '333415', 95, 'CONTAINS'),
('%CAPTIVE AIRE%', '3585', '35', 'Refrigeration and Heating Equipment', '333415', 95, 'CONTAINS'),
('%MACHINE SHOP%', '3599', '35', 'Machine Shops', '332710', 60, 'CONTAINS'),
('%MACHINING%', '3599', '35', 'Machine Shops', '332710', 50, 'CONTAINS'),
('%JARRETT BAY%', '3732', '37', 'Boat Building', '336612', 95, 'CONTAINS'),
('%MOTORSPORT%', '3711', '37', 'Motor Vehicles', '336111', 60, 'CONTAINS'),
('%BOAT%', '3732', '37', 'Boat Building and Repairing', '336612', 50, 'CONTAINS'),
('%AEROSPACE%', '3720', '37', 'Aircraft and Parts', '336400', 50, 'CONTAINS'),
-- Division 40-49: Transportation/Communications/Utilities
('%RAILROAD%', '4011', '40', 'Railroads', '482111', 60, 'CONTAINS'),
('%TRUCKING%', '4213', '42', 'Trucking', '484121', 60, 'CONTAINS'),
('%FREIGHT%', '4210', '42', 'Freight Transportation', '484000', 50, 'CONTAINS'),
('%TRANSPORT%', '4200', '42', 'Transportation', '484000', 30, 'CONTAINS'),
('%AIRLINE%', '4512', '45', 'Air Transportation', '481111', 60, 'CONTAINS'),
('%PIPELINE%', '4612', '46', 'Crude Petroleum Pipelines', '486110', 50, 'CONTAINS'),
('%KALOS TOURS%', '4720', '47', 'Travel Services', '561510', 95, 'CONTAINS'),
('%TELECOM%', '4813', '48', 'Telecommunications', '517000', 50, 'CONTAINS'),
('%CABLE%TV%', '4841', '48', 'Cable and Pay TV', '517110', 50, 'CONTAINS'),
('%TELEPHONE%', '4813', '48', 'Telephone Communications', '517311', 40, 'CONTAINS'),
-- Division 49: Electric/Gas/Sanitary
('%STRATA CLEAN%', '4911', '49', 'Solar/Clean Energy', '221114', 95, 'CONTAINS'),
('%STRATA SOLAR%', '4911', '49', 'Solar Electric Generation', '221114', 95, 'CONTAINS'),
('%DUKE ENERGY%', '4911', '49', 'Electric Services', '221112', 90, 'CONTAINS'),
('%PIEDMONT NATURAL%', '4924', '49', 'Natural Gas Distribution', '221210', 90, 'CONTAINS'),
('%NATURAL GAS%', '4924', '49', 'Natural Gas Distribution', '221210', 60, 'CONTAINS'),
('%POWER COMPANY%', '4911', '49', 'Electric Services', '221112', 60, 'CONTAINS'),
('%ELECTRIC%POWER%', '4911', '49', 'Electric Services', '221112', 60, 'CONTAINS'),
('%WATER%SEWER%', '4952', '49', 'Sewerage Systems', '221320', 50, 'CONTAINS'),
('%SOLAR%', '4911', '49', 'Electric Services - Solar', '221114', 50, 'CONTAINS'),
('%UTILITY%', '4900', '49', 'Electric, Gas, and Sanitary Services', '221000', 40, 'CONTAINS'),
-- Division 50-51: Wholesale Trade
('%STORR OFFICE%', '5021', '50', 'Office Furniture Wholesale', '423210', 95, 'CONTAINS'),
('%ELECTRIC SUPPLY%', '5063', '50', 'Electrical Supplies Wholesale', '423610', 70, 'CONTAINS'),
('%WHOLESALE%', '5000', '50', 'Wholesale Trade - Durable', '423000', 30, 'CONTAINS'),
('%DISTRIBUT%', '5000', '50', 'Wholesale Distribution', '424000', 30, 'CONTAINS'),
('%LONG BEVERAGE%', '5181', '51', 'Beer/Wine Wholesale', '424810', 95, 'CONTAINS'),
('%UNITED BEVERAGES%', '5181', '51', 'Beer/Wine Wholesale', '424810', 95, 'CONTAINS'),
('%RH BARRINGER%', '5181', '51', 'Beer/Wine Wholesale', '424810', 95, 'CONTAINS'),
('%HEALY WHOLESALE%', '5181', '51', 'Beer/Wine Wholesale', '424810', 95, 'CONTAINS'),
-- Division 52-59: Retail Trade
('%LOWE''S%', '5211', '52', 'Lumber and Building Materials', '444110', 80, 'CONTAINS'),
('%HARDWARE%', '5251', '52', 'Hardware Stores', '444130', 50, 'CONTAINS'),
('%VARIETY WHOLESALERS%', '5331', '53', 'Variety Stores', '452990', 95, 'CONTAINS'),
('%SUPERMARKET%', '5411', '54', 'Grocery Stores', '445110', 60, 'CONTAINS'),
('%GROCERY%', '5411', '54', 'Grocery Stores', '445110', 50, 'CONTAINS'),
('%CONVENIENCE%', '5411', '54', 'Convenience Stores', '445120', 40, 'CONTAINS'),
('%FORD DEALER%', '5511', '55', 'Motor Vehicle Dealers - New', '441110', 80, 'CONTAINS'),
('%HENDRICK%', '5511', '55', 'Motor Vehicle Dealers', '441110', 70, 'CONTAINS'),
('%AUTO DEALER%', '5511', '55', 'Motor Vehicle Dealers - New', '441110', 70, 'CONTAINS'),
('%CHEVROLET%', '5511', '55', 'Motor Vehicle Dealers - New', '441110', 70, 'CONTAINS'),
('%PONTIAC%', '5511', '55', 'Motor Vehicle Dealers - New', '441110', 70, 'CONTAINS'),
('%GAS STATION%', '5541', '55', 'Gasoline Service Stations', '447110', 60, 'CONTAINS'),
('%AUTOMOTIVE%', '5511', '55', 'Motor Vehicle Dealers', '441110', 40, 'CONTAINS'),
('%MOTORS%', '5511', '55', 'Motor Vehicle Dealers', '441110', 30, 'CONTAINS'),
('%FURNITURE%STORE%', '5712', '57', 'Furniture Stores', '442110', 60, 'CONTAINS'),
('%RESTAURANT%', '5812', '58', 'Eating Places', '722511', 50, 'CONTAINS'),
('%GRILL%', '5812', '58', 'Eating Places', '722511', 30, 'CONTAINS'),
('%PHARMACY%', '5912', '59', 'Drug Stores', '446110', 60, 'CONTAINS'),
('%DRUG STORE%', '5912', '59', 'Drug Stores', '446110', 60, 'CONTAINS'),
('%JEWELRY%', '5944', '59', 'Jewelry Stores', '448310', 50, 'CONTAINS'),
-- Division 60: Depository Institutions (Banking)
('%WACHOVIA%', '6020', '60', 'Commercial Banking', '522110', 90, 'CONTAINS'),
('%BANK OF AMERICA%', '6020', '60', 'Commercial Banking', '522110', 90, 'CONTAINS'),
('%WELLS FARGO%', '6020', '60', 'Commercial Banking', '522110', 90, 'CONTAINS'),
('%TRUIST%', '6020', '60', 'Commercial Banking', '522110', 90, 'CONTAINS'),
('%FIRST CITIZENS%', '6020', '60', 'Commercial Banking', '522110', 90, 'CONTAINS'),
('%BB&T%', '6020', '60', 'Commercial Banking', '522110', 90, 'CONTAINS'),
('%CREDIT UNION%', '6061', '60', 'Credit Unions', '522130', 70, 'CONTAINS'),
('%BANK %', '6020', '60', 'Commercial Banking', '522110', 40, 'CONTAINS'),
-- Division 61: Nondepository Credit
('%LENDING TREE%', '6159', '61', 'Mortgage/Lending Technology', '522310', 95, 'CONTAINS'),
('%LENDINGTREE%', '6159', '61', 'Mortgage/Lending Technology', '522310', 95, 'CONTAINS'),
('%MORTGAGE%', '6159', '61', 'Mortgage Bankers', '522310', 50, 'CONTAINS'),
('%LENDING%', '6159', '61', 'Mortgage/Lending', '522310', 40, 'CONTAINS'),
-- Division 62: Security/Commodity Brokers
('%FINANCIAL%PLAN%', '6282', '62', 'Investment Advice', '523930', 60, 'CONTAINS'),
('%WEALTH%MANAGE%', '6282', '62', 'Investment Advice', '523930', 60, 'CONTAINS'),
('%FINANCIAL%ADVISOR%', '6282', '62', 'Investment Advice', '523930', 60, 'CONTAINS'),
('%INVESTMENT%', '6211', '62', 'Security Brokers and Dealers', '523110', 40, 'CONTAINS'),
('%CAPITAL%', '6211', '62', 'Securities/Investment', '523110', 25, 'CONTAINS'),
-- Division 63: Insurance Carriers
('%HEALTHGRAM%', '6324', '63', 'Health Insurance Services', '524114', 95, 'CONTAINS'),
('%ELI GLOBAL%', '6311', '63', 'Insurance Holding Company', '524113', 95, 'CONTAINS'),
('%BLUE CROSS%', '6324', '63', 'Hospital and Medical Service Plans', '524114', 90, 'CONTAINS'),
('%BCBS%', '6324', '63', 'Hospital and Medical Service Plans', '524114', 90, 'CONTAINS'),
('%STATE FARM%', '6311', '63', 'Insurance - Fire, Marine, Casualty', '524126', 90, 'CONTAINS'),
('%ALLSTATE%', '6311', '63', 'Insurance - Fire, Marine, Casualty', '524126', 90, 'CONTAINS'),
('%INSURANCE%', '6311', '63', 'Insurance', '524114', 40, 'CONTAINS'),
-- Division 64: Insurance Agents
('%DIAL INSURANCE%', '6411', '64', 'Insurance Agents/Brokers', '524210', 95, 'CONTAINS'),
-- Division 65: Real Estate
('%CAMERON MANAGEMENT%', '6512', '65', 'Property Management', '531311', 95, 'CONTAINS'),
('%KANE REALTY%', '6552', '65', 'Real Estate Development', '531390', 95, 'CONTAINS'),
('%CHILDRESS KLEIN%', '6552', '65', 'Real Estate Development', '531390', 95, 'CONTAINS'),
('%KOTIS%', '6512', '65', 'Real Estate Operators', '531120', 95, 'CONTAINS'),
('%PRESTON DEVELOPMENT%', '6552', '65', 'Real Estate Development', '531390', 95, 'CONTAINS'),
('%PROFFITT DIXON%', '6552', '65', 'Real Estate Development', '531390', 95, 'CONTAINS'),
('%CARROLL COMPAN%', '6552', '65', 'Real Estate Development', '531390', 95, 'CONTAINS'),
('%BLUE RIDGE COMPANIES%', '6552', '65', 'Real Estate Development', '531390', 95, 'CONTAINS'),
('%TIME INVESTMENT%', '6552', '65', 'Real Estate Investment', '531390', 95, 'CONTAINS'),
('%CAPE FEAR COMMERCIAL%', '6531', '65', 'Commercial Real Estate', '531210', 95, 'CONTAINS'),
('%CPFRM%', '6552', '65', 'Real Estate Management', '531390', 85, 'CONTAINS'),
('%COLDWELL%', '6531', '65', 'Real Estate Agents', '531210', 80, 'CONTAINS'),
('%RE/MAX%', '6531', '65', 'Real Estate Agents', '531210', 80, 'CONTAINS'),
('%KELLER WILLIAMS%', '6531', '65', 'Real Estate Agents', '531210', 80, 'CONTAINS'),
('%PROPERTY%MANAGE%', '6512', '65', 'Property Management', '531311', 60, 'CONTAINS'),
('%DEVELOPER%', '6552', '65', 'Land Developers', '236117', 50, 'CONTAINS'),
('%REALT%', '6531', '65', 'Real Estate Agents and Managers', '531210', 50, 'CONTAINS'),
('%REAL ESTATE%', '6500', '65', 'Real Estate', '531000', 40, 'CONTAINS'),
('%PROPERTIES%', '6512', '65', 'Real Estate Operators', '531120', 35, 'CONTAINS'),
('%DEVELOPMENT%', '6552', '65', 'Real Estate Development', '236117', 25, 'CONTAINS'),
-- Division 67: Holding/Investment Offices
('%TRAIL CREEK%', '6726', '67', 'Investment Offices', '523910', 95, 'CONTAINS'),
('%ANVIL VENTURE%', '6726', '67', 'Investment Offices', '523910', 95, 'CONTAINS'),
('%BROYHILL GROUP%', '6726', '67', 'Investment Offices', '523910', 95, 'CONTAINS'),
('%SPANGLER%', '6726', '67', 'Investment Offices', '523910', 85, 'CONTAINS'),
('%PRIVATE EQUITY%', '6726', '67', 'Investment Offices', '523910', 70, 'CONTAINS'),
('%HEDGE FUND%', '6726', '67', 'Investment Offices', '523910', 70, 'CONTAINS'),
('%VENTURE%', '6726', '67', 'Investment Offices', '523910', 30, 'CONTAINS'),
-- Division 70: Hotels/Lodging
('%SREE HOTELS%', '7011', '70', 'Hotels and Motels', '721110', 95, 'CONTAINS'),
('%HILTON%', '7011', '70', 'Hotels and Motels', '721110', 90, 'CONTAINS'),
('%MARRIOTT%', '7011', '70', 'Hotels and Motels', '721110', 90, 'CONTAINS'),
('%HAMPTON INN%', '7011', '70', 'Hotels and Motels', '721110', 90, 'CONTAINS'),
('%HOTEL%', '7011', '70', 'Hotels and Motels', '721110', 60, 'CONTAINS'),
('%MOTEL%', '7011', '70', 'Hotels and Motels', '721110', 60, 'CONTAINS'),
('%HOSPITALITY%', '7011', '70', 'Hotels and Motels', '721110', 40, 'CONTAINS'),
-- Division 72: Personal Services
('%H&R BLOCK%', '7291', '72', 'Tax Return Preparation', '541213', 95, 'CONTAINS'),
('%MORTUARY%', '7261', '72', 'Funeral Service', '812210', 60, 'CONTAINS'),
('%DRY CLEAN%', '7212', '72', 'Garment Cleaning', '812320', 60, 'CONTAINS'),
('%FUNERAL%', '7261', '72', 'Funeral Service', '812210', 60, 'CONTAINS'),
('%BARBER%', '7241', '72', 'Barber Shops', '812111', 50, 'CONTAINS'),
('%SALON%', '7231', '72', 'Beauty Shops', '812111', 40, 'CONTAINS'),
-- Division 73: Business Services
('%CPI SECURITY%', '7382', '73', 'Security Systems Services', '561621', 95, 'CONTAINS'),
('%SAS INSTITUTE%', '7372', '73', 'Prepackaged Software', '511210', 95, 'CONTAINS'),
('%DRAKE ENTERPRISE%', '7372', '73', 'Tax Software (Drake)', '511210', 95, 'CONTAINS'),
('%DRAKE SOFTWARE%', '7372', '73', 'Tax Software', '511210', 95, 'CONTAINS'),
('%STAFFING%', '7363', '73', 'Help Supply Services', '561320', 60, 'CONTAINS'),
('%TEMP%AGENCY%', '7363', '73', 'Help Supply Services', '561320', 60, 'CONTAINS'),
('%ADVERTISING%', '7311', '73', 'Advertising Services', '541810', 60, 'CONTAINS'),
('%PUBLIC RELATION%', '7311', '73', 'Advertising/PR Services', '541820', 60, 'CONTAINS'),
('%IT %SERVICE%', '7371', '73', 'Computer Services', '541512', 50, 'CONTAINS'),
('%ACCOUNTING%', '7389', '73', 'Accounting Services', '541211', 50, 'CONTAINS'),
('%MARKETING%', '7311', '73', 'Advertising Services', '541810', 50, 'CONTAINS'),
('%SOFTWARE%', '7372', '73', 'Prepackaged Software', '511210', 50, 'CONTAINS'),
('%CPA%', '7389', '73', 'Accounting Services', '541211', 40, 'CONTAINS'),
('%CONSULTING%', '7389', '73', 'Management Consulting', '541611', 40, 'CONTAINS'),
('%SECURITY%', '7382', '73', 'Security Services', '561612', 35, 'CONTAINS'),
('%TECHNOLOGY%', '7372', '73', 'Computer Services', '541512', 35, 'CONTAINS'),
('%SAS%', '7372', '73', 'Prepackaged Software (SAS)', '511210', 20, 'CONTAINS'),
-- Division 79: Amusement/Recreation
('%HENDRICK MOTORSPORT%', '7941', '79', 'Auto Racing Teams', '711219', 95, 'CONTAINS'),
('%SPEEDWAY MOTORSPORT%', '7941', '79', 'Professional Sports Venues', '711212', 95, 'CONTAINS'),
-- Division 80: Health Services
('%ALG SENIOR%', '8051', '80', 'Assisted Living Facilities', '623312', 95, 'CONTAINS'),
('%AFFINITY LIVING%', '8051', '80', 'Assisted Living Facilities', '623312', 95, 'CONTAINS'),
('%NOVANT%', '8062', '80', 'General Medical Hospitals', '622110', 90, 'CONTAINS'),
('%DUKE%HEALTH%', '8062', '80', 'General Medical Hospitals', '622110', 90, 'CONTAINS'),
('%WAKE%MED%', '8062', '80', 'General Medical Hospitals', '622110', 90, 'CONTAINS'),
('%ATRIUM%HEALTH%', '8062', '80', 'General Medical Hospitals', '622110', 90, 'CONTAINS'),
('%ASSISTED LIVING%', '8051', '80', 'Assisted Living', '623312', 70, 'CONTAINS'),
('%ORTHODONT%', '8021', '80', 'Offices of Dentists', '621210', 70, 'CONTAINS'),
('%CHIROPRACT%', '8041', '80', 'Offices of Chiropractors', '621310', 70, 'CONTAINS'),
('%OPTOMETR%', '8042', '80', 'Offices of Optometrists', '621320', 70, 'CONTAINS'),
('%DENTIST%', '8021', '80', 'Offices of Dentists', '621210', 60, 'CONTAINS'),
('%NURSING HOME%', '8051', '80', 'Skilled Nursing Facilities', '623110', 60, 'CONTAINS'),
('%SENIOR%LIVING%', '8051', '80', 'Skilled Nursing/Assisted Living', '623110', 60, 'CONTAINS'),
('%SENIOR CARE%', '8051', '80', 'Nursing/Senior Care', '623110', 60, 'CONTAINS'),
('%MEDICAL CENTER%', '8062', '80', 'General Medical Hospitals', '622110', 60, 'CONTAINS'),
('%DENTAL%', '8021', '80', 'Offices of Dentists', '621210', 60, 'CONTAINS'),
('%PHYSICIAN%', '8011', '80', 'Offices of Physicians', '621111', 50, 'CONTAINS'),
('%HOSPITAL%', '8062', '80', 'General Medical Hospitals', '622110', 50, 'CONTAINS'),
('%DOCTOR%', '8011', '80', 'Offices of Physicians', '621111', 30, 'CONTAINS'),
('%HEALTHCARE%', '8000', '80', 'Health Services', '621000', 30, 'CONTAINS'),
('%HEALTH CARE%', '8000', '80', 'Health Services', '621000', 30, 'CONTAINS'),
('%MEDICAL%', '8011', '80', 'Health Services', '621000', 30, 'CONTAINS'),
-- Division 81: Legal Services
('%MCGUIRE WOODS%', '8111', '81', 'Legal Services', '541110', 90, 'CONTAINS'),
('%SHANAHAN LAW%', '8111', '81', 'Legal Services', '541110', 90, 'CONTAINS'),
('%WALLACE & GRAHAM%', '8111', '81', 'Legal Services', '541110', 90, 'CONTAINS'),
('%WHITLEY LAW%', '8111', '81', 'Legal Services', '541110', 90, 'CONTAINS'),
('%ROBINSON BRADSHAW%', '8111', '81', 'Legal Services', '541110', 90, 'CONTAINS'),
('%LAW OFFICE%', '8111', '81', 'Legal Services', '541110', 70, 'CONTAINS'),
('%LAW FIRM%', '8111', '81', 'Legal Services', '541110', 70, 'CONTAINS'),
('%LAW GROUP%', '8111', '81', 'Legal Services', '541110', 70, 'CONTAINS'),
('%ATTORNEY%', '8111', '81', 'Legal Services', '541110', 50, 'CONTAINS'),
('% PLLC%', '8111', '81', 'Legal Services', '541110', 40, 'CONTAINS'),
('%LEGAL%', '8111', '81', 'Legal Services', '541110', 30, 'CONTAINS'),
('% PA%', '8111', '81', 'Legal Services', '541110', 20, 'CONTAINS'),
-- Division 82: Educational Services
('%UNIVERSITY%', '8221', '82', 'Colleges and Universities', '611310', 50, 'CONTAINS'),
('%COLLEGE%', '8221', '82', 'Colleges and Universities', '611310', 40, 'CONTAINS'),
('%TEACHER%', '8211', '82', 'Elementary and Secondary Schools', '611110', 40, 'CONTAINS'),
('%SCHOOL%', '8211', '82', 'Elementary and Secondary Schools', '611110', 30, 'CONTAINS'),
-- Division 86: Membership Organizations
('%BAPTIST%', '8661', '86', 'Religious Organizations', '813110', 60, 'CONTAINS'),
('%METHODIST%', '8661', '86', 'Religious Organizations', '813110', 60, 'CONTAINS'),
('%CHURCH%', '8661', '86', 'Religious Organizations', '813110', 50, 'CONTAINS'),
('%MINISTRY%', '8661', '86', 'Religious Organizations', '813110', 40, 'CONTAINS'),
-- Division 87: Engineering/Management
('%ARCHITECT%', '8712', '87', 'Architectural Services', '541310', 60, 'CONTAINS'),
('%SURVEYOR%', '8713', '87', 'Surveying Services', '541370', 60, 'CONTAINS'),
('%ENGINEER%', '8711', '87', 'Engineering Services', '541330', 50, 'CONTAINS'),
('%SURVEY%', '8713', '87', 'Surveying Services', '541370', 30, 'CONTAINS'),
-- Division 91: Executive/Legislative
('%NC GENERAL ASSEMBLY%', '9121', '91', 'Legislative Bodies', '921120', 90, 'CONTAINS'),
('%STATE OF NORTH CAROLINA%', '9199', '91', 'State Government', '921190', 80, 'CONTAINS'),
('%STATE OF NC%', '9199', '91', 'State Government', '921190', 70, 'CONTAINS'),
('%CITY OF %', '9199', '91', 'Local Government', '921190', 50, 'CONTAINS'),
('%COUNTY OF%', '9199', '91', 'Local Government', '921190', 50, 'CONTAINS'),
('% COUNTY%', '9199', '91', 'Local Government', '921190', 15, 'CONTAINS'),
-- Division 92: Justice/Public Order
('%FIRE DEPT%', '9224', '92', 'Fire Protection', '922160', 60, 'CONTAINS'),
('%POLICE%', '9221', '92', 'Police Protection', '922120', 50, 'CONTAINS'),
('%SHERIFF%', '9221', '92', 'Police Protection', '922120', 50, 'CONTAINS'),
-- Division 97: National Security
('%US ARMY%', '9711', '97', 'National Security', '928110', 80, 'CONTAINS'),
('%US NAVY%', '9711', '97', 'National Security', '928110', 80, 'CONTAINS'),
('%US AIR FORCE%', '9711', '97', 'National Security', '928110', 80, 'CONTAINS'),
('%US MARINE%', '9711', '97', 'National Security', '928110', 80, 'CONTAINS'),
('%MILITARY%', '9711', '97', 'National Security', '928110', 40, 'CONTAINS')
ON CONFLICT (keyword_pattern) DO NOTHING;

-- ============================================================================
-- SECTION 3: PROFESSION SIC PATTERNS (74 job title → SIC fallback mappings)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_intelligence.profession_sic_patterns (
    pattern_id SERIAL PRIMARY KEY,
    profession_pattern TEXT NOT NULL UNIQUE,
    sic_code VARCHAR(4) NOT NULL,
    sic_description TEXT,
    industry_sector TEXT,
    naics_code VARCHAR(6),
    match_priority INTEGER DEFAULT 50
);

INSERT INTO donor_intelligence.profession_sic_patterns (profession_pattern, sic_code, sic_description, industry_sector, naics_code, match_priority) VALUES
-- Priority 80: Highly specific professions
('REAL ESTATE BROKER', '6531', 'Real Estate Agents', 'Real Estate', '531210', 80),
('SURGEON', '8011', 'Offices of Physicians', 'Healthcare', '621111', 80),
('REAL ESTATE DEVELOPER', '6552', 'Land Developers', 'Real Estate', '236117', 80),
('ELECTRICIAN', '1731', 'Electrical Work', 'Construction', '238210', 80),
('JUDGE', '9211', 'Courts', 'Government', '922110', 80),
('PLUMBER', '1711', 'Plumbing, Heating, AC', 'Construction', '238220', 80),
('FARMER', '0100', 'Farms - General', 'Agriculture', '111000', 80),
('DENTIST', '8021', 'Offices of Dentists', 'Healthcare', '621210', 80),
('ORTHODONTIST', '8021', 'Offices of Dentists', 'Healthcare', '621210', 80),
('GENERAL CONTRACTOR', '1520', 'General Building Contractors', 'Construction', '236220', 80),
('CHIROPRACTOR', '8041', 'Offices of Chiropractors', 'Healthcare', '621310', 80),
('OPTOMETRIST', '8042', 'Offices of Optometrists', 'Healthcare', '621320', 80),
('PHARMACIST', '5912', 'Drug Stores and Pharmacies', 'Retail Trade', '446110', 80),
('VETERINARIAN', '0742', 'Veterinary Services', 'Agriculture Services', '541940', 80),
('ATTORNEY', '8111', 'Legal Services', 'Legal Services', '541110', 80),
('PASTOR', '8661', 'Religious Organizations', 'Religious Organizations', '813110', 80),
('PHYSICIAN', '8011', 'Offices of Physicians', 'Healthcare', '621111', 80),
('CPA', '8721', 'Accounting/Auditing', 'Business Services/Technology', '541211', 80),
('ACCOUNTANT', '8721', 'Accounting/Auditing', 'Business Services/Technology', '541211', 80),
('FINANCIAL ADVISOR', '6282', 'Investment Advice', 'Securities/Investments', '523930', 80),
('FINANCIAL PLANNER', '6282', 'Investment Advice', 'Securities/Investments', '523930', 80),
('LAWYER', '8111', 'Legal Services', 'Legal Services', '541110', 80),
('LEGISLATOR', '9121', 'Legislative Bodies', 'Government', '921120', 80),
('INSURANCE AGENT', '6411', 'Insurance Agents/Brokers', 'Insurance', '524210', 80),
('SURVEYOR', '8713', 'Surveying Services', 'Engineering/Architecture', '541370', 80),
('VENTURE CAPITAL', '6726', 'Investment Offices', 'Holding/Investment Companies', '523910', 80),
('ARCHITECT', '8712', 'Architectural Services', 'Engineering/Architecture', '541310', 80),
('PROFESSOR', '8221', 'Colleges and Universities', 'Education', '611310', 80),
('REALTOR', '6531', 'Real Estate Agents', 'Real Estate', '531210', 80),
-- Priority 75
('REAL ESTATE DEVELOPMENT', '6552', 'Land Developers', 'Real Estate', '236117', 75),
-- Priority 70: Clear professions
('CLERGY', '8661', 'Religious Organizations', 'Religious Organizations', '813110', 70),
('PARALEGAL', '8111', 'Legal Services', 'Legal Services', '541110', 70),
('DOCTOR', '8011', 'Offices of Physicians', 'Healthcare', '621111', 70),
('NURSE', '8049', 'Health Practitioners', 'Healthcare', '621399', 70),
('PSYCHOLOGIST', '8049', 'Health Practitioners', 'Healthcare', '621399', 70),
('BANKER', '6020', 'Commercial Banking', 'Banking', '522110', 70),
('REAL ESTATE INVESTOR', '6512', 'Real Estate Operators', 'Real Estate', '531120', 70),
('PROPERTY MANAGER', '6512', 'Property Management', 'Real Estate', '531311', 70),
('FARMING', '0100', 'Farms - General', 'Agriculture', '111000', 70),
('RANCHER', '0212', 'Beef Cattle', 'Agriculture', '112111', 70),
('CONTRACTOR', '1520', 'General Building Contractors', 'Construction', '236220', 70),
('ROOFER', '1761', 'Roofing', 'Construction', '238160', 70),
('TEACHER', '8211', 'Elementary/Secondary Schools', 'Education', '611110', 70),
('PRINCIPAL', '8211', 'Elementary/Secondary Schools', 'Education', '611110', 70),
('BARBER', '7241', 'Barber Shops', 'Personal Services', '812111', 70),
('BEAUTICIAN', '7231', 'Beauty Shops', 'Personal Services', '812111', 70),
('POLICE', '9221', 'Police Protection', 'Government', '922120', 70),
('FIREFIGHTER', '9224', 'Fire Protection', 'Government', '922160', 70),
('MINISTER', '8661', 'Religious Organizations', 'Religious Organizations', '813110', 70),
-- Priority 60: Moderate specificity
('THERAPIST', '8049', 'Health Practitioners', 'Healthcare', '621399', 60),
('ENGINEER', '8711', 'Engineering Services', 'Engineering/Architecture', '541330', 60),
('BROKER', '6211', 'Security Brokers', 'Securities/Investments', '523120', 60),
('INVESTOR', '6726', 'Investment Offices', 'Holding/Investment Companies', '523910', 60),
('MECHANIC', '7538', 'Auto Repair', 'Personal Services', '811111', 60),
('CONSTRUCTION', '1500', 'General Construction', 'Construction', '236000', 60),
('MILITARY', '9711', 'National Security', 'Military', '928110', 60),
('AGRICULTURAL', '0100', 'Agriculture', 'Agriculture', '111000', 60),
('BUILDER', '1522', 'Residential Construction', 'Construction', '236115', 60),
('INSURANCE', '6311', 'Insurance', 'Insurance', '524114', 60),
('POLITICIAN', '9121', 'Legislative Bodies', 'Government', '921120', 60),
('REAL ESTATE', '6531', 'Real Estate', 'Real Estate', '531210', 60),
('EDUCATOR', '8211', 'Schools', 'Education', '611110', 60),
-- Priority 50: Broader categories
('DEVELOPER', '6552', 'Real Estate Development', 'Real Estate', '236117', 50),
('MANUFACTURING', '2000', 'Manufacturing', 'Manufacturing', '310000', 50),
('HEALTHCARE', '8000', 'Health Services', 'Healthcare', '621000', 50),
('CONSULTANT', '7389', 'Management Consulting', 'Business Services/Technology', '541611', 50),
('CONSULTING', '7389', 'Management Consulting', 'Business Services/Technology', '541611', 50),
-- Priority 40-20: Generic titles
('BUSINESS OWNER', '6726', 'Business Owner', 'Holding/Investment Companies', '523910', 40),
('BUSINESSMAN', '6726', 'Business Owner', 'Holding/Investment Companies', '523910', 40),
('ENTREPRENEUR', '6726', 'Entrepreneur', 'Holding/Investment Companies', '523910', 40),
('EXECUTIVE', '6726', 'Executive', 'Holding/Investment Companies', '523910', 30),
('CEO', '6726', 'Executive', 'Holding/Investment Companies', '523910', 30),
('SALES', '5000', 'Wholesale/Retail Sales', 'Wholesale Trade', '423000', 30),
('PRESIDENT', '6726', 'Executive', 'Holding/Investment Companies', '523910', 20)
ON CONFLICT (profession_pattern) DO NOTHING;

-- ============================================================================
-- SECTION 4: EMPLOYER SIC MASTER TABLE + POPULATION QUERIES
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_intelligence.employer_sic_master (
    employer_id SERIAL PRIMARY KEY,
    employer_raw TEXT NOT NULL UNIQUE,
    employer_normalized TEXT,
    sic_code VARCHAR(4),
    sic_description TEXT,
    sic_division VARCHAR(2),
    naics_code VARCHAR(6),
    industry_sector TEXT,
    match_method VARCHAR(20),      -- 'EMPLOYER_KEYWORD' or 'PROFESSION'
    match_confidence INTEGER,       -- match_priority from pattern table
    total_donation_dollars NUMERIC(12,2),
    total_donations INTEGER,
    unique_donors INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- STEP 1: Create temp table of individual donors with their primary employer
-- Filters out PACs/committees, keeps only individual human donors
CREATE TEMP TABLE IF NOT EXISTS temp_individual_donors AS
SELECT donor_name, employer_clean, total_given, total_donations, city, zip5
FROM (
    SELECT
        donor_name,
        UPPER(TRIM(employer_name)) AS employer_clean,
        city,
        norm_zip5 AS zip5,
        ROW_NUMBER() OVER (
            PARTITION BY donor_name
            ORDER BY COUNT(*) DESC, SUM(amount_numeric) DESC
        ) AS rn,
        SUM(SUM(amount_numeric)) OVER (PARTITION BY donor_name) AS total_given,
        SUM(COUNT(*)) OVER (PARTITION BY donor_name) AS total_donations
    FROM public.nc_boe_donations_raw
    WHERE employer_name IS NOT NULL
      AND TRIM(employer_name) != ''
      AND UPPER(TRIM(employer_name)) NOT IN (
          'SELF', 'SELF EMPLOYED', 'SELF-EMPLOYED', 'RETIRED', 'NONE',
          'NOT EMPLOYED', 'HOMEMAKER', 'STUDENT', 'N/A', 'NA', 'UNEMPLOYED'
      )
      -- Exclude PAC/committee transfers
      AND donor_name NOT ILIKE '%committee%'
      AND donor_name NOT ILIKE '%for nc%'
      AND donor_name NOT ILIKE '%republican%'
      AND donor_name NOT ILIKE '%democrat%'
      AND donor_name NOT ILIKE '%party%'
      AND donor_name NOT ILIKE '%PAC%'
      AND donor_name NOT ILIKE '%political%'
      AND donor_name NOT ILIKE '%campaign%'
      AND donor_name NOT ILIKE '%caucus%'
    GROUP BY donor_name, UPPER(TRIM(employer_name)), city, norm_zip5
) sub WHERE rn = 1;

-- STEP 2: Layer 1 — Employer keyword match (highest priority pattern wins)
INSERT INTO donor_intelligence.employer_sic_master
    (employer_raw, employer_normalized, sic_code, sic_description, sic_division,
     naics_code, industry_sector, match_method, match_confidence,
     total_donation_dollars, total_donations, unique_donors)
SELECT DISTINCT ON (d.donor_name)
    d.donor_name,
    d.employer_clean,
    p.sic_code,
    p.sic_description,
    p.sic_division,
    p.naics_code,
    div.division_name AS industry_sector,
    'EMPLOYER_KEYWORD',
    p.match_priority,
    d.total_given,
    d.total_donations,
    1
FROM temp_individual_donors d
JOIN donor_intelligence.sic_keyword_patterns p
    ON d.employer_clean ILIKE p.keyword_pattern
LEFT JOIN donor_intelligence.sic_divisions div
    ON p.sic_division = div.sic_division
ORDER BY d.donor_name, p.match_priority DESC
ON CONFLICT (employer_raw) DO NOTHING;

-- STEP 3: Layer 2 — Profession/job title fallback for self-employed donors
-- Only classifies donors NOT already in employer_sic_master
WITH primary_prof AS (
    SELECT donor_name, profession_clean, total_given, total_donations
    FROM (
        SELECT
            donor_name,
            UPPER(TRIM(profession_job_title)) AS profession_clean,
            SUM(amount_numeric) AS total_given,
            COUNT(*) AS total_donations,
            ROW_NUMBER() OVER (
                PARTITION BY donor_name
                ORDER BY COUNT(*) DESC
            ) AS rn
        FROM public.nc_boe_donations_raw
        WHERE profession_job_title IS NOT NULL
          AND TRIM(profession_job_title) != ''
          AND UPPER(TRIM(employer_name)) IN (
              'SELF', 'SELF EMPLOYED', 'SELF-EMPLOYED', 'RETIRED', 'NONE',
              'NOT EMPLOYED', 'HOMEMAKER'
          )
        GROUP BY donor_name, UPPER(TRIM(profession_job_title))
    ) sub WHERE rn = 1
)
INSERT INTO donor_intelligence.employer_sic_master
    (employer_raw, employer_normalized, sic_code, sic_description, sic_division,
     naics_code, industry_sector, match_method, match_confidence,
     total_donation_dollars, total_donations, unique_donors)
SELECT DISTINCT ON (pp.donor_name)
    pp.donor_name,
    pp.profession_clean,
    p.sic_code,
    p.sic_description,
    LEFT(p.sic_code, 2),
    p.naics_code,
    p.industry_sector,
    'PROFESSION',
    p.match_priority,
    pp.total_given,
    pp.total_donations,
    1
FROM primary_prof pp
JOIN donor_intelligence.profession_sic_patterns p
    ON pp.profession_clean = p.profession_pattern
WHERE pp.donor_name NOT IN (
    SELECT employer_raw FROM donor_intelligence.employer_sic_master
)
ORDER BY pp.donor_name, p.match_priority DESC
ON CONFLICT (employer_raw) DO NOTHING;

-- Cleanup
DROP TABLE IF EXISTS temp_individual_donors;

-- ============================================================================
-- SECTION 5: VIEWS
-- ============================================================================

-- View 1: Donor SIC Donations — joins classified donors to donation records
CREATE OR REPLACE VIEW donor_intelligence.vw_donor_sic_donations AS
SELECT
    d.donor_name,
    d.committee_name,
    d.amount_numeric,
    d.date_occurred,
    d.city,
    d.norm_zip5 AS zip5,
    d.employer_name,
    d.profession_job_title,
    s.sic_code,
    s.sic_description,
    s.sic_division,
    s.naics_code,
    s.industry_sector,
    s.match_method,
    s.match_confidence,
    div.division_name AS sic_division_name
FROM nc_boe_donations_raw d
JOIN donor_intelligence.employer_sic_master s
    ON d.donor_name = s.employer_raw
LEFT JOIN donor_intelligence.sic_divisions div
    ON s.sic_division = div.sic_division;

-- View 2: District Donor Prospects — donor profiles with tier/status for prospecting
CREATE OR REPLACE VIEW donor_intelligence.vw_district_donor_prospects AS
WITH donor_geo AS (
    SELECT
        d.donor_name, d.city, d.norm_zip5 AS zip5, d.employer_name,
        SUM(d.amount_numeric) AS total_given,
        COUNT(*) AS num_donations,
        COUNT(DISTINCT d.committee_name) AS unique_committees,
        MAX(d.date_occurred) AS last_donation,
        MIN(d.date_occurred) AS first_donation
    FROM nc_boe_donations_raw d
    WHERE d.donor_name IN (SELECT employer_raw FROM donor_intelligence.employer_sic_master)
    GROUP BY d.donor_name, d.city, d.norm_zip5, d.employer_name
), donor_primary AS (
    SELECT DISTINCT ON (donor_name)
        donor_name, city, zip5, employer_name, total_given,
        num_donations, unique_committees, last_donation, first_donation
    FROM donor_geo
    ORDER BY donor_name, num_donations DESC, total_given DESC
)
SELECT
    dp.donor_name, dp.city, dp.zip5, dp.employer_name,
    s.employer_normalized AS employer_classified,
    s.sic_code, s.sic_description, s.industry_sector, s.naics_code,
    s.match_confidence,
    dp.total_given, dp.num_donations, dp.unique_committees,
    dp.first_donation, dp.last_donation,
    CASE
        WHEN dp.last_donation >= '2025-01-01' THEN 'ACTIVE_2025'
        WHEN dp.last_donation >= '2024-01-01' THEN 'ACTIVE_2024'
        WHEN dp.last_donation >= '2022-01-01' THEN 'RECENT'
        ELSE 'DORMANT'
    END AS donor_status,
    CASE
        WHEN dp.num_donations >= 20 AND dp.unique_committees >= 5 THEN 'MEGA_DONOR'
        WHEN dp.num_donations >= 10 OR dp.total_given >= 10000 THEN 'MAJOR_DONOR'
        WHEN dp.num_donations >= 5 OR dp.total_given >= 2500 THEN 'MID_DONOR'
        ELSE 'SMALL_DONOR'
    END AS donor_tier
FROM donor_primary dp
JOIN donor_intelligence.employer_sic_master s ON dp.donor_name = s.employer_raw;

-- View 3: Industry to Committee — industry dollars per committee (regulatory access)
CREATE OR REPLACE VIEW donor_intelligence.vw_industry_to_committee AS
SELECT
    s.industry_sector, s.sic_code, s.sic_description, d.committee_name,
    COUNT(DISTINCT d.donor_name) AS unique_donors,
    COUNT(*) AS num_donations,
    ROUND(SUM(d.amount_numeric), 0) AS total_dollars,
    MIN(d.date_occurred) AS first_donation,
    MAX(d.date_occurred) AS last_donation
FROM nc_boe_donations_raw d
JOIN donor_intelligence.employer_sic_master s ON d.donor_name = s.employer_raw
GROUP BY s.industry_sector, s.sic_code, s.sic_description, d.committee_name;

-- View 4: Industry by ZIP — industry concentration by geography
CREATE OR REPLACE VIEW donor_intelligence.vw_industry_by_zip AS
SELECT
    d.norm_zip5 AS zip5,
    MAX(d.city) AS city,
    s.industry_sector, s.sic_division,
    COUNT(DISTINCT d.donor_name) AS unique_donors,
    ROUND(SUM(d.amount_numeric), 0) AS total_dollars,
    ROUND(AVG(d.amount_numeric), 0) AS avg_donation,
    COUNT(*) AS num_donations
FROM nc_boe_donations_raw d
JOIN donor_intelligence.employer_sic_master s ON d.donor_name = s.employer_raw
WHERE d.norm_zip5 IS NOT NULL
GROUP BY d.norm_zip5, s.industry_sector, s.sic_division;

-- View 5: Ecosystem Industry Profile — Charlotte micro-ecosystem breakdown
CREATE OR REPLACE VIEW donor_intelligence.vw_ecosystem_industry_profile AS
SELECT
    CASE
        WHEN d.city ILIKE '%mooresville%' OR d.city ILIKE '%cornelius%'
             OR d.city ILIKE '%davidson%' OR d.city ILIKE '%huntersville%'
            THEN 'LAKE_NORMAN'
        WHEN d.city ILIKE '%charlotte%' AND d.norm_zip5 IN
            ('28202','28203','28204','28206','28208','28244','28280','28281','28282')
            THEN 'DOWNTOWN_CLT'
        WHEN d.city ILIKE '%charlotte%' AND d.norm_zip5 IN
            ('28207','28209','28210','28211','28226')
            THEN 'SOUTHPARK'
        WHEN (d.city ILIKE '%charlotte%' AND d.norm_zip5 IN ('28277','28134'))
             OR d.city ILIKE '%pineville%'
            THEN 'BALLANTYNE_PINEVILLE'
        WHEN d.city ILIKE '%matthews%' OR d.city ILIKE '%mint hill%'
             OR d.city ILIKE '%stallings%'
            THEN 'MATTHEWS'
        WHEN d.city ILIKE '%waxhaw%' OR d.city ILIKE '%indian trail%'
             OR d.city ILIKE '%marvin%' OR d.city ILIKE '%weddington%'
             OR d.city ILIKE '%wesley chapel%' OR d.city ILIKE '%mineral springs%'
            THEN 'WAXHAW_INDIAN_TRAIL'
        WHEN d.city ILIKE '%harrisburg%'
             OR (d.city ILIKE '%charlotte%' AND d.norm_zip5 IN ('28213','28262','28269','28215'))
            THEN 'UNCC_AREA'
        WHEN d.city ILIKE '%charlotte%'
            THEN 'CLT_OTHER'
        ELSE NULL
    END AS ecosystem,
    s.industry_sector, s.sic_code,
    COUNT(DISTINCT d.donor_name) AS unique_donors,
    ROUND(SUM(d.amount_numeric), 0) AS total_dollars,
    ROUND(AVG(d.amount_numeric), 0) AS avg_donation
FROM nc_boe_donations_raw d
JOIN donor_intelligence.employer_sic_master s ON d.donor_name = s.employer_raw
WHERE d.city ILIKE '%charlotte%' OR d.city ILIKE '%mooresville%'
   OR d.city ILIKE '%cornelius%' OR d.city ILIKE '%davidson%'
   OR d.city ILIKE '%huntersville%' OR d.city ILIKE '%matthews%'
   OR d.city ILIKE '%mint hill%' OR d.city ILIKE '%waxhaw%'
   OR d.city ILIKE '%indian trail%' OR d.city ILIKE '%stallings%'
   OR d.city ILIKE '%pineville%' OR d.city ILIKE '%marvin%'
   OR d.city ILIKE '%weddington%' OR d.city ILIKE '%wesley chapel%'
   OR d.city ILIKE '%mineral springs%' OR d.city ILIKE '%harrisburg%'
GROUP BY
    CASE
        WHEN d.city ILIKE '%mooresville%' OR d.city ILIKE '%cornelius%'
             OR d.city ILIKE '%davidson%' OR d.city ILIKE '%huntersville%'
            THEN 'LAKE_NORMAN'
        WHEN d.city ILIKE '%charlotte%' AND d.norm_zip5 IN
            ('28202','28203','28204','28206','28208','28244','28280','28281','28282')
            THEN 'DOWNTOWN_CLT'
        WHEN d.city ILIKE '%charlotte%' AND d.norm_zip5 IN
            ('28207','28209','28210','28211','28226')
            THEN 'SOUTHPARK'
        WHEN (d.city ILIKE '%charlotte%' AND d.norm_zip5 IN ('28277','28134'))
             OR d.city ILIKE '%pineville%'
            THEN 'BALLANTYNE_PINEVILLE'
        WHEN d.city ILIKE '%matthews%' OR d.city ILIKE '%mint hill%'
             OR d.city ILIKE '%stallings%'
            THEN 'MATTHEWS'
        WHEN d.city ILIKE '%waxhaw%' OR d.city ILIKE '%indian trail%'
             OR d.city ILIKE '%marvin%' OR d.city ILIKE '%weddington%'
             OR d.city ILIKE '%wesley chapel%' OR d.city ILIKE '%mineral springs%'
            THEN 'WAXHAW_INDIAN_TRAIL'
        WHEN d.city ILIKE '%harrisburg%'
             OR (d.city ILIKE '%charlotte%' AND d.norm_zip5 IN ('28213','28262','28269','28215'))
            THEN 'UNCC_AREA'
        WHEN d.city ILIKE '%charlotte%'
            THEN 'CLT_OTHER'
        ELSE NULL
    END,
    s.industry_sector, s.sic_code;

-- ============================================================================
-- SECTION 6: INDEXES (28 total across all tables)
-- ============================================================================

-- employer_sic_master indexes
CREATE INDEX IF NOT EXISTS idx_employer_sic_code ON donor_intelligence.employer_sic_master (sic_code);
CREATE INDEX IF NOT EXISTS idx_employer_sic_raw ON donor_intelligence.employer_sic_master (employer_raw);
CREATE INDEX IF NOT EXISTS idx_employer_sic_sector ON donor_intelligence.employer_sic_master (industry_sector);
CREATE INDEX IF NOT EXISTS idx_esm_confidence ON donor_intelligence.employer_sic_master (match_confidence);
CREATE INDEX IF NOT EXISTS idx_esm_division ON donor_intelligence.employer_sic_master (sic_division);
CREATE INDEX IF NOT EXISTS idx_esm_dollars_desc ON donor_intelligence.employer_sic_master (total_donation_dollars DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_esm_employer_norm ON donor_intelligence.employer_sic_master (employer_normalized);
CREATE INDEX IF NOT EXISTS idx_esm_match_method ON donor_intelligence.employer_sic_master (match_method);
CREATE INDEX IF NOT EXISTS idx_esm_naics ON donor_intelligence.employer_sic_master (naics_code);

-- Trigram index for fuzzy employer name search (requires pg_trgm extension)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_esm_employer_raw_trgm
    ON donor_intelligence.employer_sic_master USING gin (employer_raw gin_trgm_ops);

-- sic_keyword_patterns indexes
CREATE INDEX IF NOT EXISTS idx_skp_division ON donor_intelligence.sic_keyword_patterns (sic_division);
CREATE INDEX IF NOT EXISTS idx_skp_priority ON donor_intelligence.sic_keyword_patterns (match_priority DESC);
CREATE INDEX IF NOT EXISTS idx_skp_sic_code ON donor_intelligence.sic_keyword_patterns (sic_code);

-- profession_sic_patterns indexes
CREATE INDEX IF NOT EXISTS idx_psp_priority ON donor_intelligence.profession_sic_patterns (match_priority DESC);
CREATE INDEX IF NOT EXISTS idx_psp_sector ON donor_intelligence.profession_sic_patterns (industry_sector);
CREATE INDEX IF NOT EXISTS idx_psp_sic_code ON donor_intelligence.profession_sic_patterns (sic_code);

-- ============================================================================
-- SECTION 7: ECOSYSTEM DEFINITIONS (7 Charlotte micro-ecosystems)
-- ============================================================================

CREATE TABLE IF NOT EXISTS donor_intelligence.ecosystem_definitions (
    ecosystem_id SERIAL PRIMARY KEY,
    ecosystem_code VARCHAR(30) UNIQUE NOT NULL,
    ecosystem_name TEXT NOT NULL,
    description TEXT,
    zip_codes TEXT[] NOT NULL,
    city_patterns TEXT[] NOT NULL,
    county VARCHAR(50),
    region VARCHAR(50)
);

INSERT INTO donor_intelligence.ecosystem_definitions
    (ecosystem_code, ecosystem_name, description, zip_codes, city_patterns, county, region)
VALUES
('LAKE_NORMAN', 'Lake Norman',
 'NASCAR money, financial advisors, lake-lifestyle wealth',
 ARRAY['28031','28036','28035','28078','28115','28117','28166'],
 ARRAY['%mooresville%','%cornelius%','%davidson%','%huntersville%'],
 'Mecklenburg/Iredell', 'Charlotte Metro'),
('DOWNTOWN_CLT', 'Downtown Charlotte',
 'Corporate PACs, banking HQs, Duke Energy, law firms',
 ARRAY['28202','28203','28204','28206','28208','28244','28280','28281','28282'],
 ARRAY['%charlotte%'],
 'Mecklenburg', 'Charlotte Metro'),
('SOUTHPARK', 'SouthPark',
 'Old Charlotte money, real estate developers, country club set',
 ARRAY['28207','28209','28210','28211','28226'],
 ARRAY['%charlotte%'],
 'Mecklenburg', 'Charlotte Metro'),
('BALLANTYNE_PINEVILLE', 'Ballantyne-Pineville',
 'Tech transplants, Indian hospitality, LendingTree',
 ARRAY['28277','28134'],
 ARRAY['%charlotte%','%pineville%'],
 'Mecklenburg', 'Charlotte Metro'),
('MATTHEWS', 'Matthews',
 'Bedroom community, small business, Brawley/Cotham territory',
 ARRAY['28105','28227'],
 ARRAY['%matthews%','%mint hill%','%stallings%'],
 'Mecklenburg', 'Charlotte Metro'),
('WAXHAW_INDIAN_TRAIL', 'Waxhaw-Indian Trail',
 'Rich enclave, Dan Bishop base, construction/MAGA money',
 ARRAY['28173','28079'],
 ARRAY['%waxhaw%','%indian trail%','%marvin%','%weddington%','%wesley chapel%','%mineral springs%'],
 'Union', 'Charlotte Metro'),
('UNCC_AREA', 'UNCC Area',
 'University corridor, Adams Beverages, RE/MAX territory',
 ARRAY['28213','28262','28269','28215'],
 ARRAY['%harrisburg%'],
 'Mecklenburg/Cabarrus', 'Charlotte Metro')
ON CONFLICT (ecosystem_code) DO NOTHING;

-- ============================================================================
-- SECTION 8: FOREIGN KEY CONSTRAINTS AND TABLE COMMENTS
-- ============================================================================

-- FK: employer_sic_master.sic_division → sic_divisions.sic_division
ALTER TABLE donor_intelligence.employer_sic_master
    DROP CONSTRAINT IF EXISTS fk_esm_sic_division;
ALTER TABLE donor_intelligence.employer_sic_master
    ADD CONSTRAINT fk_esm_sic_division
    FOREIGN KEY (sic_division) REFERENCES donor_intelligence.sic_divisions(sic_division);

-- FK: sic_keyword_patterns.sic_division → sic_divisions.sic_division
ALTER TABLE donor_intelligence.sic_keyword_patterns
    DROP CONSTRAINT IF EXISTS fk_skp_sic_division;
ALTER TABLE donor_intelligence.sic_keyword_patterns
    ADD CONSTRAINT fk_skp_sic_division
    FOREIGN KEY (sic_division) REFERENCES donor_intelligence.sic_divisions(sic_division);

-- Table comments
COMMENT ON TABLE donor_intelligence.sic_divisions IS
    'SIC major group reference: 80 two-digit divisions mapping to NAICS sectors';
COMMENT ON TABLE donor_intelligence.sic_keyword_patterns IS
    '272 ILIKE patterns matching employer names to SIC codes, priority-scored';
COMMENT ON TABLE donor_intelligence.profession_sic_patterns IS
    '74 profession/job title patterns for self-employed donor SIC fallback';
COMMENT ON TABLE donor_intelligence.employer_sic_master IS
    '62,100 classified donors: employer_raw=donor_name, two-layer match (employer keyword + profession fallback)';
COMMENT ON TABLE donor_intelligence.ecosystem_definitions IS
    '7 Charlotte micro-ecosystems with ZIP codes and city patterns for geographic donor segmentation';

-- View comments
COMMENT ON VIEW donor_intelligence.vw_donor_sic_donations IS
    'Joins classified donors to nc_boe_donations_raw with full SIC/NAICS detail';
COMMENT ON VIEW donor_intelligence.vw_district_donor_prospects IS
    'Donor prospecting view with tier (MEGA/MAJOR/MID/SMALL) and status (ACTIVE/RECENT/DORMANT)';
COMMENT ON VIEW donor_intelligence.vw_industry_to_committee IS
    'Industry dollars per committee — detects regulatory access donation patterns';
COMMENT ON VIEW donor_intelligence.vw_industry_by_zip IS
    'Industry concentration by ZIP code for geographic targeting';
COMMENT ON VIEW donor_intelligence.vw_ecosystem_industry_profile IS
    'Charlotte micro-ecosystem industry breakdown for local strategy';

-- ============================================================================
-- MIGRATION COMPLETE
-- Tables: sic_divisions, sic_keyword_patterns, profession_sic_patterns,
--         employer_sic_master, ecosystem_definitions
-- Views:  vw_donor_sic_donations, vw_district_donor_prospects,
--         vw_industry_to_committee, vw_industry_by_zip,
--         vw_ecosystem_industry_profile
-- Indexes: 28 across all tables
-- ============================================================================


-- ============================================================================
-- SECTION 9: LEGISLATIVE INTELLIGENCE + NEWS MEDIA + NEWSLETTER ENGINE
-- Added: 2026-03-15
-- Tables: bill_subject_sic_mapping, bill_sponsors, news_intelligence,
--         newsletter_campaigns, newsletter_recipients
-- Views:  vw_regulatory_access_triggers, vw_news_donor_impact,
--         vw_ecosystem_newsletter_queue, vw_district_newsletter_composer
-- ============================================================================

-- 9A: Bill Subject → SIC Mapping (103 legislative subject → industry mappings)
CREATE TABLE IF NOT EXISTS donor_intelligence.bill_subject_sic_mapping (
    mapping_id SERIAL PRIMARY KEY,
    subject_keyword TEXT NOT NULL UNIQUE,
    sic_code VARCHAR(4) NOT NULL,
    sic_division VARCHAR(2) NOT NULL,
    subject_description TEXT,
    affected_industry TEXT,
    naics_code VARCHAR(6),
    match_priority INTEGER DEFAULT 50,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO donor_intelligence.bill_subject_sic_mapping
    (subject_keyword, sic_code, sic_division, subject_description, affected_industry, naics_code, match_priority) VALUES
-- Agriculture
('AGRICULTURE', '0100', '01', 'General agriculture policy', 'Agriculture - Crops', '111000', 60),
('FARM', '0100', '01', 'Farm policy/subsidies', 'Agriculture - Crops', '111000', 70),
('TOBACCO', '0132', '01', 'Tobacco regulation/settlement', 'Agriculture - Crops', '111910', 80),
('LIVESTOCK', '0200', '02', 'Livestock regulation', 'Agriculture - Livestock', '112000', 70),
('HOG FARM', '0213', '02', 'Hog farming regulation', 'Agriculture - Livestock', '112210', 90),
('POULTRY', '0250', '02', 'Poultry regulation', 'Agriculture - Livestock', '112300', 80),
('PESTICIDE', '0700', '07', 'Pesticide regulation', 'Agriculture Services', '115000', 80),
('FORESTRY', '0811', '08', 'Forestry/timber policy', 'Forestry', '113110', 70),
('HUNTING', '0900', '09', 'Hunting/fishing regulation', 'Fishing/Hunting', '114000', 60),
('FISHING', '0900', '09', 'Fishing regulation', 'Fishing/Hunting', '114000', 60),
-- Mining / Energy Extraction
('MINING', '1000', '10', 'Mining regulation', 'Metal Mining', '212000', 70),
('COAL', '1200', '12', 'Coal regulation', 'Coal Mining', '212100', 80),
('OIL AND GAS', '1300', '13', 'Oil/gas extraction policy', 'Oil and Gas', '211000', 80),
('FRACKING', '1300', '13', 'Hydraulic fracturing policy', 'Oil and Gas', '211000', 90),
('NATURAL GAS', '1300', '13', 'Natural gas regulation', 'Oil and Gas', '211000', 80),
-- Construction
('HIGHWAY', '1611', '16', 'Highway construction/funding', 'Construction - Heavy', '237310', 80),
('ROAD CONSTRUCTION', '1611', '16', 'Road building/maintenance', 'Construction - Heavy', '237310', 90),
('BUILDING CODE', '1500', '15', 'Building codes/standards', 'Construction - General', '236000', 80),
('CONTRACTOR LICENSE', '1500', '15', 'Contractor licensing', 'Construction - General', '236000', 85),
('HOUSING', '1522', '15', 'Housing policy', 'Construction - General', '236115', 60),
('AFFORDABLE HOUSING', '1522', '15', 'Affordable housing mandates', 'Construction - General', '236115', 70),
('ELECTRICAL CODE', '1731', '17', 'Electrical codes', 'Construction - Special Trade', '238210', 80),
('PLUMBING CODE', '1711', '17', 'Plumbing codes', 'Construction - Special Trade', '238220', 80),
-- Manufacturing / Food
('PHARMACEUTICAL', '2834', '28', 'Pharma regulation/pricing', 'Chemicals', '325412', 80),
('DRUG PRICING', '2834', '28', 'Prescription drug pricing', 'Chemicals', '325412', 85),
('BREWERY', '2082', '20', 'Brewery/alcohol regulation', 'Food and Kindred Products', '312120', 80),
('DISTILLERY', '2085', '20', 'Distillery regulation', 'Food and Kindred Products', '312140', 80),
('ABC', '2085', '20', 'Alcohol Beverage Control', 'Food and Kindred Products', '312140', 70),
('FOOD SAFETY', '2000', '20', 'Food safety regulation', 'Food and Kindred Products', '311000', 70),
-- Transportation / Utilities
('TRANSPORTATION', '4200', '42', 'Transportation policy', 'Motor Freight/Warehousing', '484000', 50),
('TRUCKING', '4213', '42', 'Trucking regulation', 'Motor Freight/Warehousing', '484121', 80),
('RAILROAD', '4011', '40', 'Railroad policy', 'Railroad Transportation', '482111', 80),
('AIRLINE', '4512', '45', 'Aviation regulation', 'Air Transportation', '481111', 70),
('PIPELINE', '4612', '46', 'Pipeline regulation', 'Pipelines', '486110', 80),
('TELECOM', '4813', '48', 'Telecommunications regulation', 'Communications', '517000', 70),
('BROADBAND', '4813', '48', 'Broadband expansion/regulation', 'Communications', '517311', 80),
('INTERNET', '4813', '48', 'Internet regulation', 'Communications', '517000', 60),
('SOLAR ENERGY', '4911', '49', 'Solar energy policy', 'Electric/Gas/Sanitary', '221114', 90),
('RENEWABLE ENERGY', '4911', '49', 'Renewable energy mandates', 'Electric/Gas/Sanitary', '221100', 80),
('ELECTRIC UTILITY', '4911', '49', 'Electric utility regulation', 'Electric/Gas/Sanitary', '221112', 80),
('UTILITY RATE', '4900', '49', 'Utility rate setting', 'Electric/Gas/Sanitary', '221000', 85),
('ENERGY POLICY', '4911', '49', 'Energy policy general', 'Electric/Gas/Sanitary', '221000', 60),
('WATER QUALITY', '4952', '49', 'Water quality standards', 'Electric/Gas/Sanitary', '221320', 70),
('SEWER', '4952', '49', 'Sewer/wastewater regulation', 'Electric/Gas/Sanitary', '221320', 70),
-- Banking / Finance / Insurance
('BANKING', '6020', '60', 'Banking regulation', 'Depository Institutions', '522110', 70),
('CREDIT UNION', '6061', '60', 'Credit union regulation', 'Depository Institutions', '522130', 80),
('MORTGAGE', '6159', '61', 'Mortgage regulation', 'Nondepository Credit', '522310', 70),
('PREDATORY LENDING', '6159', '61', 'Lending regulation', 'Nondepository Credit', '522310', 85),
('PAYDAY LENDING', '6159', '61', 'Payday loan regulation', 'Nondepository Credit', '522390', 90),
('SECURITIES', '6211', '62', 'Securities regulation', 'Security/Commodity Brokers', '523110', 70),
('INSURANCE REFORM', '6311', '63', 'Insurance reform', 'Insurance Carriers', '524114', 80),
('HEALTH INSURANCE', '6324', '63', 'Health insurance mandates', 'Insurance Carriers', '524114', 85),
('AUTO INSURANCE', '6311', '63', 'Auto insurance regulation', 'Insurance Carriers', '524126', 80),
('WORKERS COMP', '6311', '63', 'Workers compensation', 'Insurance Carriers', '524126', 80),
('INSURANCE RATE', '6311', '63', 'Insurance rate regulation', 'Insurance Carriers', '524114', 85),
-- Real Estate
('REAL ESTATE', '6500', '65', 'Real estate regulation', 'Real Estate', '531000', 60),
('ZONING', '6552', '65', 'Zoning/land use', 'Real Estate', '531390', 80),
('EMINENT DOMAIN', '6552', '65', 'Eminent domain/property rights', 'Real Estate', '531390', 90),
('PROPERTY TAX', '6500', '65', 'Property tax policy', 'Real Estate', '531000', 80),
('ANNEXATION', '6552', '65', 'Municipal annexation', 'Real Estate', '531390', 85),
('DEVELOPMENT APPROVAL', '6552', '65', 'Development permitting', 'Real Estate', '531390', 85),
('LANDLORD TENANT', '6512', '65', 'Landlord-tenant law', 'Real Estate', '531120', 80),
('RENT CONTROL', '6512', '65', 'Rent regulation', 'Real Estate', '531120', 90),
-- Healthcare
('MEDICAID', '8062', '80', 'Medicaid expansion/policy', 'Health Services', '622110', 85),
('HOSPITAL', '8062', '80', 'Hospital regulation', 'Health Services', '622110', 70),
('NURSING HOME', '8051', '80', 'Nursing home regulation', 'Health Services', '623110', 80),
('ASSISTED LIVING', '8051', '80', 'Assisted living regulation', 'Health Services', '623312', 80),
('CERTIFICATE OF NEED', '8062', '80', 'CON regulation', 'Health Services', '622110', 95),
('SCOPE OF PRACTICE', '8011', '80', 'Provider scope of practice', 'Health Services', '621111', 85),
('DENTAL', '8021', '80', 'Dental regulation', 'Health Services', '621210', 70),
('PHARMACY BENEFIT', '5912', '59', 'PBM regulation', 'Retail - Misc', '446110', 85),
('OPIOID', '8011', '80', 'Opioid regulation', 'Health Services', '621111', 80),
('MENTAL HEALTH', '8011', '80', 'Mental health policy', 'Health Services', '621000', 60),
-- Legal / Courts
('TORT REFORM', '8111', '81', 'Tort reform/liability', 'Legal Services', '541110', 90),
('MEDICAL MALPRACTICE', '8111', '81', 'Med mal liability limits', 'Legal Services', '541110', 90),
('JUDICIAL', '9211', '92', 'Judicial reform', 'Justice/Public Order', '922110', 60),
('CRIMINAL JUSTICE', '9221', '92', 'Criminal justice reform', 'Justice/Public Order', '922120', 60),
-- Education
('K-12', '8211', '82', 'K-12 education policy', 'Educational Services', '611110', 60),
('CHARTER SCHOOL', '8211', '82', 'Charter school policy', 'Educational Services', '611110', 80),
('SCHOOL VOUCHER', '8211', '82', 'School voucher/choice', 'Educational Services', '611110', 85),
('UNIVERSITY', '8221', '82', 'Higher education policy', 'Educational Services', '611310', 60),
('COMMUNITY COLLEGE', '8222', '82', 'Community college funding', 'Educational Services', '611210', 70),
('TEACHER PAY', '8211', '82', 'Teacher compensation', 'Educational Services', '611110', 70),
-- Environment
('COAL ASH', '4953', '49', 'Coal ash disposal regulation', 'Electric/Gas/Sanitary', '562000', 95),
('WETLANDS', '9511', '95', 'Wetlands protection', 'Administration - Environmental', '924110', 80),
('AIR QUALITY', '9511', '95', 'Air quality standards', 'Administration - Environmental', '924110', 80),
('POLLUTION', '9511', '95', 'Pollution regulation', 'Administration - Environmental', '924110', 70),
('ENVIRONMENTAL REVIEW', '9511', '95', 'Environmental permitting', 'Administration - Environmental', '924110', 80),
-- Government / Tax
('CORPORATE TAX', '9311', '93', 'Corporate tax policy', 'Public Finance', '921130', 80),
('INCOME TAX', '9311', '93', 'Income tax policy', 'Public Finance', '921130', 80),
('SALES TAX', '9311', '93', 'Sales tax policy', 'Public Finance', '921130', 80),
('TAX INCENTIVE', '9611', '96', 'Economic development incentives', 'Administration - Economic', '926110', 85),
('ECONOMIC DEVELOPMENT', '9611', '96', 'Econ dev programs', 'Administration - Economic', '926110', 70),
-- Law Enforcement / Guns
('GUN', '5941', '59', 'Firearms regulation', 'Retail - Misc', '451110', 70),
('FIREARM', '5941', '59', 'Firearms regulation', 'Retail - Misc', '451110', 80),
('LAW ENFORCEMENT', '9221', '92', 'Police/sheriff regulation', 'Justice/Public Order', '922120', 60),
('CONCEALED CARRY', '5941', '59', 'Concealed carry policy', 'Retail - Misc', '451110', 85),
-- Technology / Business
('DATA PRIVACY', '7372', '73', 'Data privacy regulation', 'Business Services', '511210', 80),
('CYBERSECURITY', '7372', '73', 'Cybersecurity regulation', 'Business Services', '511210', 80),
('OCCUPATIONAL LICENSE', '7389', '73', 'Occupational licensing reform', 'Business Services', '541600', 85),
('MINIMUM WAGE', '7389', '73', 'Minimum wage policy', 'Business Services', '541600', 70),
('RIGHT TO WORK', '7389', '73', 'Labor/right to work', 'Business Services', '541600', 85),
('NON COMPETE', '7389', '73', 'Non-compete regulation', 'Business Services', '541600', 80)
ON CONFLICT (subject_keyword) DO NOTHING;

-- 9B: Bill Sponsors
CREATE TABLE IF NOT EXISTS donor_intelligence.bill_sponsors (
    sponsor_id SERIAL PRIMARY KEY,
    bill_number VARCHAR(20) NOT NULL,
    bill_session VARCHAR(10) NOT NULL,
    bill_title TEXT,
    bill_subjects TEXT[],
    sponsor_name TEXT NOT NULL,
    sponsor_type VARCHAR(20) DEFAULT 'PRIMARY',
    sponsor_party VARCHAR(5),
    sponsor_chamber VARCHAR(10),
    sponsor_district VARCHAR(10),
    filed_date DATE,
    last_action TEXT,
    last_action_date DATE,
    bill_status VARCHAR(30),
    source_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (bill_number, bill_session, sponsor_name)
);

-- 9C: News Intelligence
CREATE TABLE IF NOT EXISTS donor_intelligence.news_intelligence (
    news_id SERIAL PRIMARY KEY,
    headline TEXT NOT NULL,
    source_name TEXT,
    source_url TEXT,
    published_date DATE,
    summary TEXT,
    subjects TEXT[],
    sic_codes VARCHAR(4)[],
    sic_divisions VARCHAR(2)[],
    affected_industries TEXT[],
    geographic_scope VARCHAR(20),
    affected_zips TEXT[],
    affected_ecosystems TEXT[],
    relevance_score INTEGER DEFAULT 50,
    story_type VARCHAR(30),
    processed BOOLEAN DEFAULT FALSE,
    newsletter_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9D: Newsletter Campaigns
CREATE TABLE IF NOT EXISTS donor_intelligence.newsletter_campaigns (
    campaign_id SERIAL PRIMARY KEY,
    campaign_name TEXT NOT NULL,
    campaign_type VARCHAR(20) NOT NULL,
    target_ecosystem VARCHAR(30),
    target_sic_divisions VARCHAR(2)[],
    target_donor_tiers TEXT[],
    target_donor_statuses TEXT[],
    subject_line TEXT,
    header_text TEXT,
    body_content TEXT,
    news_ids INTEGER[],
    bill_numbers TEXT[],
    call_to_action TEXT,
    estimated_recipients INTEGER,
    status VARCHAR(20) DEFAULT 'DRAFT',
    scheduled_date DATE,
    sent_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9E: Newsletter Recipients
CREATE TABLE IF NOT EXISTS donor_intelligence.newsletter_recipients (
    recipient_id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES donor_intelligence.newsletter_campaigns(campaign_id),
    donor_name TEXT NOT NULL,
    email TEXT,
    mailing_address TEXT,
    city TEXT,
    zip5 VARCHAR(5),
    ecosystem_code VARCHAR(30),
    industry_sector TEXT,
    sic_code VARCHAR(4),
    donor_tier VARCHAR(20),
    donor_status VARCHAR(20),
    total_given NUMERIC(12,2),
    delivery_method VARCHAR(10),
    personalization_tags JSONB,
    sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9F: Donor Alerts / Newsfeed
CREATE TABLE IF NOT EXISTS donor_intelligence.donor_alerts (
    alert_id SERIAL PRIMARY KEY,
    alert_type VARCHAR(30) NOT NULL,
    severity VARCHAR(10) DEFAULT 'MEDIUM',
    headline TEXT NOT NULL,
    detail TEXT,
    donor_name TEXT,
    donor_tier VARCHAR(20),
    donor_total_given NUMERIC(12,2),
    industry_sector TEXT,
    sic_code VARCHAR(4),
    ecosystem_code VARCHAR(30),
    bill_number VARCHAR(20),
    news_id INTEGER,
    source_url TEXT,
    read BOOLEAN DEFAULT FALSE,
    dismissed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9G: Section 9 Indexes
CREATE INDEX IF NOT EXISTS idx_bssm_sic_code ON donor_intelligence.bill_subject_sic_mapping (sic_code);
CREATE INDEX IF NOT EXISTS idx_bssm_division ON donor_intelligence.bill_subject_sic_mapping (sic_division);
CREATE INDEX IF NOT EXISTS idx_bssm_priority ON donor_intelligence.bill_subject_sic_mapping (match_priority DESC);
CREATE INDEX IF NOT EXISTS idx_bs_bill ON donor_intelligence.bill_sponsors (bill_number, bill_session);
CREATE INDEX IF NOT EXISTS idx_bs_sponsor ON donor_intelligence.bill_sponsors (sponsor_name);
CREATE INDEX IF NOT EXISTS idx_bs_party ON donor_intelligence.bill_sponsors (sponsor_party);
CREATE INDEX IF NOT EXISTS idx_bs_chamber ON donor_intelligence.bill_sponsors (sponsor_chamber);
CREATE INDEX IF NOT EXISTS idx_bs_district ON donor_intelligence.bill_sponsors (sponsor_district);
CREATE INDEX IF NOT EXISTS idx_bs_status ON donor_intelligence.bill_sponsors (bill_status);
CREATE INDEX IF NOT EXISTS idx_bs_filed ON donor_intelligence.bill_sponsors (filed_date DESC);
CREATE INDEX IF NOT EXISTS idx_bs_subjects ON donor_intelligence.bill_sponsors USING gin (bill_subjects);
CREATE INDEX IF NOT EXISTS idx_ni_published ON donor_intelligence.news_intelligence (published_date DESC);
CREATE INDEX IF NOT EXISTS idx_ni_sic_codes ON donor_intelligence.news_intelligence USING gin (sic_codes);
CREATE INDEX IF NOT EXISTS idx_ni_divisions ON donor_intelligence.news_intelligence USING gin (sic_divisions);
CREATE INDEX IF NOT EXISTS idx_ni_ecosystems ON donor_intelligence.news_intelligence USING gin (affected_ecosystems);
CREATE INDEX IF NOT EXISTS idx_ni_story_type ON donor_intelligence.news_intelligence (story_type);
CREATE INDEX IF NOT EXISTS idx_ni_processed ON donor_intelligence.news_intelligence (processed) WHERE processed = FALSE;
CREATE INDEX IF NOT EXISTS idx_ni_newsletter ON donor_intelligence.news_intelligence (newsletter_used) WHERE newsletter_used = FALSE;
CREATE INDEX IF NOT EXISTS idx_ni_relevance ON donor_intelligence.news_intelligence (relevance_score DESC);
CREATE INDEX IF NOT EXISTS idx_nc_ecosystem ON donor_intelligence.newsletter_campaigns (target_ecosystem);
CREATE INDEX IF NOT EXISTS idx_nc_status ON donor_intelligence.newsletter_campaigns (status);
CREATE INDEX IF NOT EXISTS idx_nc_scheduled ON donor_intelligence.newsletter_campaigns (scheduled_date);
CREATE INDEX IF NOT EXISTS idx_nc_type ON donor_intelligence.newsletter_campaigns (campaign_type);
CREATE INDEX IF NOT EXISTS idx_nr_campaign ON donor_intelligence.newsletter_recipients (campaign_id);
CREATE INDEX IF NOT EXISTS idx_nr_donor ON donor_intelligence.newsletter_recipients (donor_name);
CREATE INDEX IF NOT EXISTS idx_nr_ecosystem ON donor_intelligence.newsletter_recipients (ecosystem_code);
CREATE INDEX IF NOT EXISTS idx_nr_tier ON donor_intelligence.newsletter_recipients (donor_tier);
CREATE INDEX IF NOT EXISTS idx_da_unread ON donor_intelligence.donor_alerts (read) WHERE read = FALSE;
CREATE INDEX IF NOT EXISTS idx_da_severity ON donor_intelligence.donor_alerts (severity, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_da_type ON donor_intelligence.donor_alerts (alert_type);
CREATE INDEX IF NOT EXISTS idx_da_donor ON donor_intelligence.donor_alerts (donor_name);
CREATE INDEX IF NOT EXISTS idx_da_ecosystem ON donor_intelligence.donor_alerts (ecosystem_code);
CREATE INDEX IF NOT EXISTS idx_da_created ON donor_intelligence.donor_alerts (created_at DESC);

-- 9H: Section 9 Views (see live database for full CREATE OR REPLACE statements)
-- vw_regulatory_access_triggers: bill sponsors × bill SIC × donor SIC = regulatory access
-- vw_news_donor_impact: news SIC × donor SIC × ecosystem = newsletter targeting
-- vw_ecosystem_newsletter_queue: per-ecosystem pending stories + donor counts
-- vw_district_newsletter_composer: per-ZIP industry/donor breakdown for legislators
-- vw_alert_generator: auto-generates CRITICAL/HIGH/MEDIUM alerts for mega/major donors

-- 9I: Section 9 Comments
COMMENT ON TABLE donor_intelligence.bill_subject_sic_mapping IS
    '103 legislative subject-to-SIC mappings for regulatory access detection';
COMMENT ON TABLE donor_intelligence.bill_sponsors IS
    'Legislator bill sponsorship tracking for SIC cross-referencing';
COMMENT ON TABLE donor_intelligence.news_intelligence IS
    'News stories tagged with SIC codes/ecosystems for donor-targeted newsletters';
COMMENT ON TABLE donor_intelligence.newsletter_campaigns IS
    'Newsletter editions per ecosystem micro-segment with content and recipient targeting';
COMMENT ON TABLE donor_intelligence.newsletter_recipients IS
    'Pre-computed recipient lists per campaign with personalization tags';
COMMENT ON TABLE donor_intelligence.donor_alerts IS
    'Real-time newsfeed alerts when legislation or news impacts mega/major donors';

-- ============================================================================
-- MIGRATION COMPLETE — FULL SYSTEM
-- Sections 1-8: SIC Classification Engine (62,100 classified donors)
-- Section 9: Legislative Intelligence + News Media + Newsletter + Alerts
-- Total tables: 11 | Total views: 10 | Total indexes: 58+
-- ============================================================================
