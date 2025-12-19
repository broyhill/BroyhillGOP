-- ============================================================================
-- CANDIDATE QUESTIONNAIRE AUTO-POPULATION SEARCH SCRIPT
-- Comprehensive Google Search Strategy for Local Candidate Intelligence
-- November 28, 2025
-- ============================================================================

/*
================================================================================
PURPOSE
================================================================================
This script defines a systematic Google search strategy to auto-populate
candidate questionnaire fields from public web sources. Each search query
is designed to fill specific questionnaire sections.

TARGET SOURCES:
• Ballotpedia.org (official candidate pages)
• State Board of Elections (NC SBoE - cf.ncsbe.gov)
• County Board of Elections PDFs
• Municipal/Village websites (.gov, .org)
• Local newspapers (Clemmons Courier, Journal Now, etc.)
• Campaign websites
• LinkedIn profiles
• FEC.gov (federal donation history)
• NC Campaign Finance (state donations)
• Social media (Facebook, Twitter/X, Truth Social)
• Business databases (Buzzfile, D&B, etc.)
• Property records
• Court records (civil/criminal)
• Professional licensing boards
================================================================================
*/

-- ============================================================================
-- SEARCH TEMPLATE TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS candidate_search_templates (
    id SERIAL PRIMARY KEY,
    search_category VARCHAR(100) NOT NULL,
    questionnaire_section VARCHAR(100) NOT NULL,
    fields_populated JSONB DEFAULT '[]'::jsonb,
    search_query_template TEXT NOT NULL,
    expected_sources JSONB DEFAULT '[]'::jsonb,
    search_priority INT DEFAULT 5,
    notes TEXT
);

-- ============================================================================
-- PHASE 1: IDENTITY & BASIC INFORMATION (Run First)
-- ============================================================================

INSERT INTO candidate_search_templates (search_category, questionnaire_section, fields_populated, search_query_template, expected_sources, search_priority, notes) VALUES

-- Search 1: Ballotpedia Official Page
('Identity', 'Basic Information', 
 '["full_name", "office_sought", "party", "election_year", "email"]'::jsonb,
 '{candidate_name} {municipality} {state} candidate Ballotpedia',
 '["ballotpedia.org"]'::jsonb,
 1,
 'ALWAYS RUN FIRST. Ballotpedia has standardized candidate info, email, office details.'),

-- Search 2: County Board of Elections Filing
('Identity', 'Basic Information',
 '["address", "filing_date", "party", "legal_name"]'::jsonb,
 '{candidate_name} {county} Board of Elections candidate filing',
 '["co.{county}.nc.us", "ncsbe.gov", "s3.amazonaws.com/dl.ncsbe.gov"]'::jsonb,
 1,
 'Official filing records show legal name, address, party, filing date.'),

-- Search 3: Municipal Website
('Identity', 'Government Profile',
 '["bio_short", "phone", "email", "committee_assignments", "photo_url"]'::jsonb,
 '{candidate_name} {municipality} NC official site',
 '["{municipality}.org", "{municipality}.gov"]'::jsonb,
 1,
 'If incumbent, municipal site has official bio, contact, photo.'),

-- Search 4: Campaign Website
('Identity', 'Campaign Information',
 '["campaign_website", "campaign_email", "campaign_phone", "bio_medium", "issues", "slogan"]'::jsonb,
 '{candidate_name} {office} campaign website {year}',
 '["www.*forcouncil.com", "www.*forsheriff.com", "www.elect*.com"]'::jsonb,
 2,
 'Campaign site has positions, bio, contact, donation link.');

-- ============================================================================
-- PHASE 2: BIOGRAPHY & BACKGROUND
-- ============================================================================

INSERT INTO candidate_search_templates (search_category, questionnaire_section, fields_populated, search_query_template, expected_sources, search_priority, notes) VALUES

-- Search 5: Education Background
('Biography', 'Education',
 '["undergrad_school", "undergrad_degree", "grad_school", "high_school"]'::jsonb,
 '"{candidate_name}" {municipality} NC education university college degree',
 '["linkedin.com", "local newspapers", "alumni databases"]'::jsonb,
 3,
 'Search for education mentions in bios, LinkedIn, alumni news.'),

-- Search 6: Professional/Occupation
('Biography', 'Professional',
 '["occupation", "employer", "industry", "years_experience", "business_owner"]'::jsonb,
 '"{candidate_name}" {municipality} NC occupation employer business',
 '["linkedin.com", "buzzfile.com", "dnb.com", "local news"]'::jsonb,
 3,
 'Business databases and LinkedIn have occupation/employer info.'),

-- Search 7: Military Service
('Biography', 'Military',
 '["military_veteran", "military_branch", "military_rank", "military_years"]'::jsonb,
 '"{candidate_name}" {municipality} NC veteran military army navy marine air force',
 '["local newspapers", "vfw.org", "legion.org", "campaign sites"]'::jsonb,
 4,
 'Military service often highlighted in campaign materials.'),

-- Search 8: Family Information
('Biography', 'Family',
 '["spouse_name", "children_count", "years_in_community"]'::jsonb,
 '"{candidate_name}" {municipality} NC family wife husband married children',
 '["local newspapers", "campaign sites", "municipal sites"]'::jsonb,
 4,
 'Family details often in campaign bios and newspaper profiles.');

-- ============================================================================
-- PHASE 3: CIVIC & COMMUNITY ENGAGEMENT
-- ============================================================================

INSERT INTO candidate_search_templates (search_category, questionnaire_section, fields_populated, search_query_template, expected_sources, search_priority, notes) VALUES

-- Search 9: Community Organizations
('Community', 'Civic Engagement',
 '["rotary_member", "lions_member", "chamber_member", "civic_orgs"]'::jsonb,
 '"{candidate_name}" {municipality} NC Rotary Lions Kiwanis Chamber civic club',
 '["local newspapers", "rotary.org", "lionsclubs.org"]'::jsonb,
 3,
 'Civic club memberships often in newspaper mentions.'),

-- Search 10: Church/Faith
('Community', 'Faith',
 '["church_name", "denomination", "church_leadership"]'::jsonb,
 '"{candidate_name}" {municipality} NC church faith Christian Baptist Methodist',
 '["local newspapers", "church websites", "campaign materials"]'::jsonb,
 4,
 'Church affiliation often mentioned in conservative campaigns.'),

-- Search 11: Charitable/Volunteer
('Community', 'Charitable',
 '["volunteer_orgs", "charitable_involvement", "board_positions"]'::jsonb,
 '"{candidate_name}" {municipality} NC volunteer nonprofit board foundation charity',
 '["local newspapers", "nonprofit databases", "campaign sites"]'::jsonb,
 4,
 'Charitable involvement shows community engagement.');

-- ============================================================================
-- PHASE 4: POLITICAL ENGAGEMENT & HISTORY
-- ============================================================================

INSERT INTO candidate_search_templates (search_category, questionnaire_section, fields_populated, search_query_template, expected_sources, search_priority, notes) VALUES

-- Search 12: Party Involvement
('Political', 'Party Engagement',
 '["county_gop_member", "precinct_chair", "convention_delegate"]'::jsonb,
 '"{candidate_name}" {county} NC Republican Party GOP precinct delegate convention',
 '["forsythgop.org", "ncgop.org", "local newspapers"]'::jsonb,
 3,
 'County GOP sites and local papers report party involvement.'),

-- Search 13: Past Elections
('Political', 'Election History',
 '["previous_races", "wins", "losses", "vote_totals"]'::jsonb,
 '"{candidate_name}" {municipality} NC election results {year-4} {year-2}',
 '["ballotpedia.org", "local newspapers", "ncsbe.gov"]'::jsonb,
 2,
 'Historical election results show track record.'),

-- Search 14: Endorsements
('Political', 'Endorsements',
 '["trump_endorsement", "nra_grade", "endorsements_received"]'::jsonb,
 '"{candidate_name}" {municipality} NC endorsement Trump NRA pro-life',
 '["campaign sites", "nrapvf.org", "local newspapers"]'::jsonb,
 3,
 'Endorsements are key for donor matching.'),

-- Search 15: Campaign Finance
('Political', 'Fundraising',
 '["amount_raised", "donor_count", "major_donors"]'::jsonb,
 '"{candidate_name}" campaign contributions donations {municipality} NC',
 '["cf.ncsbe.gov", "fec.gov", "opensecrets.org"]'::jsonb,
 2,
 'NC SBoE has detailed campaign finance reports.');

-- ============================================================================
-- PHASE 5: ISSUE POSITIONS
-- ============================================================================

INSERT INTO candidate_search_templates (search_category, questionnaire_section, fields_populated, search_query_template, expected_sources, search_priority, notes) VALUES

-- Search 16: Tax Positions
('Issues', 'Fiscal Positions',
 '["position_taxes", "position_spending"]'::jsonb,
 '"{candidate_name}" {municipality} NC taxes budget spending fiscal conservative',
 '["local newspapers", "campaign sites", "voter guides"]'::jsonb,
 3,
 'Tax positions critical for fiscal conservative matching.'),

-- Search 17: Public Safety Positions
('Issues', 'Safety Positions',
 '["position_crime", "position_guns", "position_immigration"]'::jsonb,
 '"{candidate_name}" {municipality} NC crime police sheriff guns 2nd amendment',
 '["local newspapers", "campaign sites", "nrapvf.org"]'::jsonb,
 3,
 'Public safety positions for LAWS faction matching.'),

-- Search 18: Education Positions
('Issues', 'Education Positions',
 '["position_education", "position_parental_rights"]'::jsonb,
 '"{candidate_name}" {municipality} NC schools education curriculum parental rights',
 '["local newspapers", "campaign sites", "momsforliberty.org"]'::jsonb,
 3,
 'Education positions critical for EVAN/CHNA matching.'),

-- Search 19: Growth/Development Positions
('Issues', 'Development Positions',
 '["position_growth", "position_zoning"]'::jsonb,
 '"{candidate_name}" {municipality} NC development zoning growth planning',
 '["local newspapers", "planning meeting minutes"]'::jsonb,
 4,
 'Local candidates often defined by development stances.');

-- ============================================================================
-- PHASE 6: SOCIAL MEDIA & DIGITAL PRESENCE
-- ============================================================================

INSERT INTO candidate_search_templates (search_category, questionnaire_section, fields_populated, search_query_template, expected_sources, search_priority, notes) VALUES

-- Search 20: Facebook
('Social Media', 'Facebook',
 '["facebook_personal", "facebook_campaign", "facebook_followers"]'::jsonb,
 '"{candidate_name}" {municipality} NC site:facebook.com',
 '["facebook.com"]'::jsonb,
 3,
 'Facebook is primary social platform for local candidates.'),

-- Search 21: Twitter/X
('Social Media', 'Twitter',
 '["twitter_handle", "twitter_followers"]'::jsonb,
 '"{candidate_name}" {municipality} NC site:twitter.com OR site:x.com',
 '["twitter.com", "x.com"]'::jsonb,
 4,
 'Twitter less common for local but check.'),

-- Search 22: LinkedIn
('Social Media', 'LinkedIn',
 '["linkedin_url", "occupation", "education", "employer"]'::jsonb,
 '"{candidate_name}" {municipality} NC site:linkedin.com',
 '["linkedin.com"]'::jsonb,
 3,
 'LinkedIn has detailed professional background.'),

-- Search 23: Truth Social / Parler
('Social Media', 'Alt-Social',
 '["truth_social_handle", "parler_handle"]'::jsonb,
 '"{candidate_name}" {municipality} NC site:truthsocial.com OR site:parler.com',
 '["truthsocial.com", "parler.com"]'::jsonb,
 5,
 'Check for conservative platform presence.');

-- ============================================================================
-- PHASE 7: PRESS & PUBLIC RECORD
-- ============================================================================

INSERT INTO candidate_search_templates (search_category, questionnaire_section, fields_populated, search_query_template, expected_sources, search_priority, notes) VALUES

-- Search 24: Positive Press
('Press', 'Positive Coverage',
 '["positive_press_articles", "awards_received"]'::jsonb,
 '"{candidate_name}" {municipality} NC award honor recognition',
 '["local newspapers"]'::jsonb,
 4,
 'Awards and recognition boost candidate profile.'),

-- Search 25: Local News Coverage
('Press', 'News Coverage',
 '["press_mentions", "news_sentiment"]'::jsonb,
 '"{candidate_name}" {municipality} site:clemmonscourier.com OR site:journalnow.com',
 '["clemmonscourier.com", "journalnow.com"]'::jsonb,
 2,
 'Local papers are primary news source for municipal candidates.'),

-- Search 26: Negative Press / Opposition Research
('Press', 'Vulnerabilities',
 '["negative_press_articles", "controversies"]'::jsonb,
 '"{candidate_name}" {municipality} NC controversy lawsuit complaint',
 '["local newspapers", "court records"]'::jsonb,
 3,
 'Check for negative coverage, legal issues.'),

-- Search 27: Court Records
('Public Record', 'Legal',
 '["lawsuits", "criminal_record", "civil_judgments"]'::jsonb,
 '"{candidate_name}" {county} NC court case lawsuit',
 '["nccourts.gov", "local newspapers"]'::jsonb,
 4,
 'Court records reveal legal history.');

-- ============================================================================
-- PHASE 8: LOCAL CONSERVATIVE GROUPS
-- ============================================================================

INSERT INTO candidate_search_templates (search_category, questionnaire_section, fields_populated, search_query_template, expected_sources, search_priority, notes) VALUES

-- Search 28: Conservative Group Membership
('Groups', 'Conservative Orgs',
 '["tea_party_member", "moms_liberty", "conservative_club"]'::jsonb,
 '"{candidate_name}" {county} NC tea party "moms for liberty" conservative club',
 '["facebook groups", "local newspapers"]'::jsonb,
 4,
 'Conservative group affiliations for faction matching.'),

-- Search 29: Second Amendment Groups
('Groups', '2A Organizations',
 '["nra_member", "goa_member", "2a_groups"]'::jsonb,
 '"{candidate_name}" {county} NC NRA "gun owners" "second amendment"',
 '["nrapvf.org", "gunowners.org", "local papers"]'::jsonb,
 4,
 '2A group memberships for LAWS faction.'),

-- Search 30: Pro-Life Organizations
('Groups', 'Pro-Life Orgs',
 '["pro_life_orgs", "crisis_pregnancy_volunteer"]'::jsonb,
 '"{candidate_name}" {county} NC pro-life "right to life" "crisis pregnancy"',
 '["nrlc.org", "local crisis pregnancy centers"]'::jsonb,
 4,
 'Pro-life affiliations for EVAN/CHNA factions.');

-- ============================================================================
-- SEARCH EXECUTION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_candidate_searches(
    p_candidate_name VARCHAR,
    p_municipality VARCHAR,
    p_county VARCHAR,
    p_state VARCHAR DEFAULT 'NC',
    p_office VARCHAR DEFAULT NULL,
    p_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT
) RETURNS TABLE (
    search_priority INT,
    search_category VARCHAR,
    questionnaire_section VARCHAR,
    search_query TEXT,
    fields_to_populate JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cst.search_priority,
        cst.search_category,
        cst.questionnaire_section,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(cst.search_query_template, 
                                '{candidate_name}', p_candidate_name),
                            '{municipality}', p_municipality),
                        '{county}', p_county),
                    '{state}', p_state),
                '{office}', COALESCE(p_office, '')),
            '{year}', p_year::VARCHAR) AS search_query,
        cst.fields_populated
    FROM candidate_search_templates cst
    ORDER BY cst.search_priority, cst.id;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- EXAMPLE: Generate Searches for Mary Cameron
-- ============================================================================

/*
SELECT * FROM generate_candidate_searches(
    'Mary Cameron',
    'Clemmons',
    'Forsyth',
    'NC',
    'Village Council',
    2025
);

Results would include:
1. Mary Cameron Clemmons NC candidate Ballotpedia
2. Mary Cameron Forsyth Board of Elections candidate filing
3. Mary Cameron Clemmons NC official site
4. Mary Cameron Village Council campaign website 2025
5. "Mary Cameron" Clemmons NC education university college degree
... etc.
*/

-- ============================================================================
-- DATA EXTRACTION PATTERNS
-- ============================================================================

/*
After running searches, extract data using these patterns:

BALLOTPEDIA PATTERNS:
- Email: Look for "You can ask {name} to fill out this survey by using the button below or emailing {EMAIL}"
- Party: "({Party} Party) ran for election to the {Office}"
- Election Year: "general election on {Date}"

MUNICIPAL WEBSITE PATTERNS:
- Bio: Usually in paragraphs under name/photo
- Phone: Look for "Phone:" or tel: links
- Email: Look for "@{municipality}.org" addresses

CAMPAIGN WEBSITE PATTERNS:
- Issues: Usually in navigation or section headers
- Bio: "About" or "Meet {Name}" pages
- Donate links reveal ActBlue/WinRed use

LOCAL NEWSPAPER PATTERNS:
- Vote totals: "{Name} - {number} votes ({percent}%)"
- History: "first elected in {year}"
- Endorsements: "{Name} is endorsed by..."

SOCIAL MEDIA PATTERNS:
- Facebook: Page likes/followers in About section
- LinkedIn: Education and Experience sections structured
*/

COMMENT ON FUNCTION generate_candidate_searches IS 
'Generates prioritized Google search queries to auto-populate candidate questionnaire fields';
