-- =====================================================
-- BROYHILLGOP PLATFORM - SPI OFFICE PATCH
-- NC Superintendent of Public Instruction
-- Patch to: broyhillgop_office_heatmap_extension.sql
-- Date: 2026-03-15
-- Status: DEPLOYED TO SUPABASE 2026-03-15
-- =====================================================
-- NOTE: 'SPI' row already exists in cos_office_registry via
-- the original INSERT in the extension file. This patch:
--   1. Adds SPI-specific issues to issue_taxonomy (14 new rows)
--   2. Inserts SPI intensity matrix rows (22 rows)
--   3. Inserts SPI archetype match rows (8 rows)
--   4. Inserts SPI geographic overlay rows (7 rows)
--   5. Inserts SPI go/no-go signals (10 rows)
-- =====================================================
-- What Made SPI Unique (and Missing Before):
--   14 new issue_taxonomy rows were required because SPI is the
--   only CoS office whose entire mandate is education — issues like
--   PHONICS_LITERACY, ANTI_NCAE, HELENE_SCHOOL_RECOVERY,
--   CHARTER_SCHOOL_EXPANSION, and HOMESCHOOL_NEUTRALITY don't
--   appear at meaningful intensity for any other CoS office.
--
--   CRITICAL STRUCTURAL VARIABLE: The NC State Board of Education
--   (13 Governor Stein appointees) holds superior policymaking
--   authority over the elected SPI. A Republican SPI in 2026 is
--   structurally in conflict with a Democrat-controlled Board from
--   Day 1 — encoded as signal #5 NOGO.
--
-- Patch Application Order:
--   1. Run original extension file first (creates schemas + cos_office_registry with SPI row)
--      \i broyhillgop_office_heatmap_extension.sql
--   2. Then apply the SPI patch
--      \i SPI_office_patch.sql
--
-- SPI Intensity Matrix at a Glance:
--   Tier ★★★★★ Defining (5 issues): Anti-DEI in DPI, School Choice, Anti-CRT, Accountability, Teacher Pay
--   Tier ★★★★ Very High  (8 issues): Parental Notification, Charter Expansion, Phonics/Literacy, Religious Liberty
--   Tier ★★★ Significant  (9 issues): CTE, ANTI_NCAE, Helene School Recovery, Rural School Funding
-- =====================================================


-- ─────────────────────────────────────────────────────────
-- STEP 1: Add SPI-specific issues to issue_taxonomy
-- ─────────────────────────────────────────────────────────

INSERT INTO state_offices.issue_taxonomy
    (issue_code, issue_name, issue_category, is_nc_specific, is_federal_only, is_state_only)
VALUES
    ('PARENTAL_NOTIFICATION',    'Parental Notification / Curriculum Transparency',     'EDUCATION', TRUE,  FALSE, TRUE),
    ('CHARTER_SCHOOL_EXPANSION', 'Charter School Expansion / Oversight',                 'EDUCATION', TRUE,  FALSE, TRUE),
    ('PHONICS_LITERACY',         'Phonics / Literacy Standards (Science of Reading)',    'EDUCATION', TRUE,  FALSE, TRUE),
    ('TEACHER_LICENSURE_REFORM', 'Teacher Licensure / Alternative Certification Reform','EDUCATION', TRUE,  FALSE, TRUE),
    ('SPECIAL_ED_IDEA',          'Special Education / IDEA Federal Compliance',          'EDUCATION', FALSE, FALSE, FALSE),
    ('ANTI_GENDER_SCHOOLS',      'Anti-Gender Ideology in Public Schools',               'SOCIAL',    TRUE,  FALSE, TRUE),
    ('SCHOOL_SAFETY_SROS',       'School Safety / School Resource Officers (SROs)',      'SECURITY',  TRUE,  FALSE, FALSE),
    ('FEDERAL_ED_FUNDING_ACCT',  'Federal Education Funding Accountability (Title I/IDEA)','ECONOMY', FALSE, FALSE, FALSE),
    ('HOMESCHOOL_NEUTRALITY',    'Homeschool / Private School Neutrality (Opp. Scholarships)','EDUCATION',TRUE,FALSE,TRUE),
    ('CAREER_TECH_EDUCATION',    'Career-Technical Education (CTE) Expansion',           'EDUCATION', TRUE,  FALSE, TRUE),
    ('AI_DIGITAL_CURRICULUM',    'AI / Digital Curriculum Standards',                    'EDUCATION', TRUE,  FALSE, TRUE),
    ('ANTI_NCAE',                'NCAE / Teachers Union Opposition',                     'EDUCATION', TRUE,  FALSE, TRUE),
    ('RURAL_SCHOOL_FUNDING',     'Rural School Funding Equity',                          'EDUCATION', TRUE,  FALSE, TRUE),
    ('HELENE_SCHOOL_RECOVERY',   'Hurricane Helene School Facility Recovery (WNC)',      'LOCAL_NC',  TRUE,  FALSE, TRUE)
ON CONFLICT (issue_code) DO NOTHING;


-- ─────────────────────────────────────────────────────────
-- STEP 2: SPI Issue Intensity Matrix (22 rows)
-- ─────────────────────────────────────────────────────────

INSERT INTO state_offices.cos_office_issue_intensity
    (office_id, issue_id, intensity_score, tier, is_primary, is_unique_to_office, rationale)
SELECT
    o.office_id, i.issue_id,
    v.intensity_score, v.tier, v.is_primary, v.is_unique_to_office, v.rationale
FROM state_offices.cos_office_registry o
CROSS JOIN (VALUES
    ('SCHOOL_CHOICE',           5, 1, TRUE,  FALSE, 'SPI administers Opportunity Scholarship program; parental rights is the primary activation issue'),
    ('CRT_CURRICULUM',          5, 1, TRUE,  FALSE, 'SPI sets curriculum frameworks statewide — directly executes or blocks CRT content'),
    ('TEACHER_PAY_SPI',         5, 1, TRUE,  TRUE,  'NC teacher pay is the SPI-defining contrast issue; activates both education professionals and fiscal hawks'),
    ('SCHOOL_ACCOUNTABILITY',   5, 1, TRUE,  FALSE, 'SPI administers NC school performance grades; accountability is the defining conservative contrast'),
    ('ANTI_DEI_GOVT',           5, 1, TRUE,  FALSE, 'SPI can directly defund DEI programs inside DPI and district curriculum on Day 1'),
    ('PARENTAL_NOTIFICATION',   4, 2, FALSE, TRUE,  'SPI can mandate statewide parental notification policies; connects to anti-gender curriculum'),
    ('CHARTER_SCHOOL_EXPANSION',4, 2, FALSE, TRUE,  'SPI has charter school compliance oversight role; major conservative education battleground'),
    ('FENTANYL_TRAFFICKING',    4, 2, FALSE, FALSE, 'SPI controls substance abuse/drug education curriculum in NC schools'),
    ('SCHOOL_SAFETY_SROS',      4, 2, FALSE, TRUE,  'SPI has school safety policy role; connects LEO/defense donor base to education office'),
    ('FEDERAL_ED_FUNDING_ACCT', 4, 2, FALSE, TRUE,  'Title I and IDEA funds flow through SPI; fiscal hawks activated by federal accountability angle'),
    ('PHONICS_LITERACY',        4, 2, FALSE, TRUE,  'NC adopted Science of Reading — SPI enforces implementation; suburban parent activation'),
    ('RELIGIOUS_LIBERTY',       4, 2, FALSE, FALSE, 'SPI can set policy on religious expression in schools; evangelical donor primary trigger'),
    ('ANTI_GENDER_SCHOOLS',     4, 2, FALSE, TRUE,  'SPI can issue statewide guidance on gender ideology; connects to parental notification'),
    ('TEACHER_LICENSURE_REFORM',3, 3, FALSE, TRUE,  'SPI controls alternative licensure pathways; workforce/business donor activation'),
    ('SPECIAL_ED_IDEA',         3, 3, FALSE, FALSE, 'IDEA federal compliance is SPI responsibility; parent-community activation'),
    ('RURAL_SCHOOL_FUNDING',    3, 3, FALSE, TRUE,  'Appalachian and eastern NC rural donors; Helene-adjacent for WNC schools'),
    ('LOTTERY_FUNDING',         3, 3, FALSE, TRUE,  'SPI responsible for education fund accounting transparency — not lottery operator'),
    ('HOMESCHOOL_NEUTRALITY',   3, 3, FALSE, TRUE,  'SPI must administer Opportunity Scholarships without penalizing private/homeschool'),
    ('AI_DIGITAL_CURRICULUM',   3, 3, FALSE, TRUE,  'SPI sets AI curriculum standards; tech-sector suburban donor activation'),
    ('CAREER_TECH_EDUCATION',   3, 3, FALSE, TRUE,  'CTE expansion is the establishment business-class unlock for SPI'),
    ('ANTI_NCAE',               3, 3, FALSE, TRUE,  'NCAE opposition is a go-signal in Republican primary; signals reform intent'),
    ('HELENE_SCHOOL_RECOVERY',  3, 3, FALSE, TRUE,  '25+ WNC school facilities damaged by Helene; named recovery platform activates mountain donors')
) AS v(issue_code, intensity_score, tier, is_primary, is_unique_to_office, rationale)
JOIN state_offices.issue_taxonomy i ON i.issue_code = v.issue_code
WHERE o.office_code = 'SPI'
ON CONFLICT (office_id, issue_id) DO UPDATE SET
    intensity_score     = EXCLUDED.intensity_score,
    tier                = EXCLUDED.tier,
    is_primary          = EXCLUDED.is_primary,
    is_unique_to_office = EXCLUDED.is_unique_to_office,
    rationale           = EXCLUDED.rationale,
    updated_at          = NOW();


-- ─────────────────────────────────────────────────────────
-- STEP 3: SPI Archetype Match (8 rows)
-- ─────────────────────────────────────────────────────────

INSERT INTO state_offices.cos_archetype_match
    (office_id, archetype_code, archetype_name, activation_level, primary_triggers, concentration_notes, go_signal)
SELECT
    o.office_id, v.archetype_code, v.archetype_name, v.activation_level,
    v.primary_triggers, v.concentration_notes, v.go_signal
FROM state_offices.cos_office_registry o
CROSS JOIN (VALUES
    ('EVAN',    'Evangelical / Faith-Based',        5,
     ARRAY['ANTI_GENDER_SCHOOLS','RELIGIOUS_LIBERTY','CRT_CURRICULUM','PARENTAL_NOTIFICATION'],
     'SPI is the #1 faith-based education activation office in the entire CoS taxonomy; statewide reach',
     'Lead with anti-gender curriculum guidance + religious liberty in schools; evangelical donors give on Day 1 commitment'),
    ('ANTIWOKE','Anti-Woke',                        5,
     ARRAY['ANTI_DEI_GOVT','CRT_CURRICULUM','ANTI_GENDER_SCHOOLS','ANTI_NCAE'],
     'SPI is THE anti-woke education battleground — highest activation for this archetype in the entire CoS',
     '"I will defund DEI inside DPI on Day 1" is the single highest-ROI sentence in the SPI primary donor appeal'),
    ('RURL',    'Suburban Parent / Parental Rights', 5,
     ARRAY['SCHOOL_CHOICE','PARENTAL_NOTIFICATION','PHONICS_LITERACY','SCHOOL_ACCOUNTABILITY'],
     'Piedmont suburban collar counties (Wake, Mecklenburg, Union, Cabarrus outer ring); primary SPI donor community',
     'School choice expansion + parental notification = the two-issue package that activates suburban parent donors universally'),
    ('FISC',    'Fiscal Hawk',                      4,
     ARRAY['FEDERAL_ED_FUNDING_ACCT','SCHOOL_ACCOUNTABILITY','TEACHER_PAY_SPI','LOTTERY_FUNDING'],
     'Statewide distribution; strongest in business-community donor circles',
     'Named DPI budget accountability platform + federal funding strings critique = fiscal hawk activation'),
    ('MAGA',    'MAGA Hardliner',                   4,
     ARRAY['CRT_CURRICULUM','ANTI_DEI_GOVT','ANTI_GENDER_SCHOOLS','ANTI_NCAE'],
     'Strong in exurban and rural areas; secondary to evangelical and parental rights archetypes for SPI',
     'MAGA activation follows evangelical — same issues, slightly different frame (national vs community)'),
    ('BUSI',    'Establishment / Business Class',   4,
     ARRAY['CAREER_TECH_EDUCATION','PHONICS_LITERACY','SCHOOL_ACCOUNTABILITY','TEACHER_LICENSURE_REFORM'],
     'Charlotte, Raleigh, Greensboro business communities; workforce-readiness is the activation angle',
     'CTE expansion + literacy standards = "NC students ready to work" is the business-class SPI pitch'),
    ('HLTH',    'Healthcare / Professional',        3,
     ARRAY['SPECIAL_ED_IDEA','SCHOOL_SAFETY_SROS','PARENTAL_NOTIFICATION'],
     'Educator and healthcare professional crossover community; concentrated in metro areas',
     'Special education and school mental health policy are the professional-community activation levers'),
    ('DEF',     'Defense / LEO / Veterans',         3,
     ARRAY['SCHOOL_SAFETY_SROS','FEDERAL_ED_FUNDING_ACCT','PARENTAL_NOTIFICATION'],
     'Military family education quality; concentrated near Fort Liberty, Camp Lejeune, Seymour Johnson corridors',
     'School safety + SRO policy + JROTC programs = military family donor activation for SPI')
) AS v(archetype_code, archetype_name, activation_level, primary_triggers, concentration_notes, go_signal)
WHERE o.office_code = 'SPI'
ON CONFLICT (office_id, archetype_code) DO UPDATE SET
    activation_level    = EXCLUDED.activation_level,
    primary_triggers    = EXCLUDED.primary_triggers,
    concentration_notes = EXCLUDED.concentration_notes,
    go_signal           = EXCLUDED.go_signal;


-- ─────────────────────────────────────────────────────────
-- STEP 4: SPI Geographic Overlays (7 rows)
-- ─────────────────────────────────────────────────────────

INSERT INTO state_offices.cos_geographic_overlay
    (office_id, geographic_zone, issue_id, override_score, override_reason, county_list)
SELECT
    o.office_id, v.geographic_zone, i.issue_id,
    v.override_score, v.override_reason, v.county_list
FROM state_offices.cos_office_registry o
CROSS JOIN (VALUES
    ('APPALACHIAN',        'HELENE_SCHOOL_RECOVERY', 5,
     'Helene damaged 25+ WNC school facilities; named recovery platform is the #1 SPI issue in this zone',
     ARRAY['Buncombe','Haywood','Madison','McDowell','Mitchell','Yancey','Avery','Watauga','Ashe','Alleghany']),
    ('APPALACHIAN',        'RURAL_SCHOOL_FUNDING',   5,
     'Most underfunded rural school districts in NC are in WNC; resource equity is SPI-specific activation',
     ARRAY['Cherokee','Clay','Graham','Swain','Jackson','Macon','Transylvania']),
    ('PIEDMONT_SUBURBAN',  'SCHOOL_CHOICE',           5,
     'Highest-density suburban parent donor community; Opportunity Scholarship expansion is top issue',
     ARRAY['Wake','Mecklenburg','Union','Cabarrus','Iredell','Johnston','Forsyth']),
    ('PIEDMONT_SUBURBAN',  'PARENTAL_NOTIFICATION',   5,
     'Suburban parents most activated by curriculum transparency requirements',
     ARRAY['Wake','Mecklenburg','Union','Cabarrus','Durham outer']),
    ('COASTAL',            'SCHOOL_SAFETY_SROS',      5,
     'Military family communities are most activated by school safety policy',
     ARRAY['Onslow','Craven','Cumberland','Wayne']),
    ('PIEDMONT_URBAN',     'ANTI_DEI_GOVT',           5,
     'Anti-DEI inside DPI is the urban conservative activation point; most visible contrast with Democrat SPI',
     ARRAY['Wake','Mecklenburg','Guilford','Forsyth','Durham']),
    ('RURAL_EASTERN',      'RURAL_SCHOOL_FUNDING',    5,
     'Most underfunded public school districts in NC are in eastern NC; Title I dependency is highest here',
     ARRAY['Robeson','Scotland','Hoke','Richmond','Anson','Hertford','Northampton','Bertie'])
) AS v(geographic_zone, issue_code, override_score, override_reason, county_list)
JOIN state_offices.issue_taxonomy i ON i.issue_code = v.issue_code
WHERE o.office_code = 'SPI';


-- ─────────────────────────────────────────────────────────
-- STEP 5: SPI Go / No-Go Signals (10 rows)
-- ─────────────────────────────────────────────────────────

INSERT INTO state_offices.cos_signals
    (office_id, signal_type, signal_text, applies_to, priority_rank)
SELECT
    o.office_id, v.signal_type, v.signal_text, v.applies_to, v.priority_rank
FROM state_offices.cos_office_registry o
CROSS JOIN (VALUES
    ('GO',   'Any candidate who opens with "I will defund DEI inside DPI on Day 1" immediately consolidates the MAGA + Evangelical + Anti-Woke donor stack. Highest-ROI single sentence in the SPI primary.',
     'PRIMARY', 1),
    ('GO',   'Opportunity Scholarship expansion commitment crosses all archetypes simultaneously — MAGA, evangelical, fiscal hawk, and suburban parent all activate. This is the one issue that generates multi-archetype consolidation.',
     'ALL', 2),
    ('GO',   'Any SPI candidate who develops a named "WNC School Recovery" platform specifically addressing Helene-damaged school facilities will capture the Appalachian donor community otherwise less engaged with SPI.',
     'GENERAL', 3),
    ('GO',   'CTE expansion + literacy standards = "NC students ready to work" is the establishment business-class and fiscal hawk dual-activation message. Second-highest ROI message after the anti-DEI opener.',
     'GENERAL', 4),
    ('GO',   'NCAE (NC Association of Educators) opposition is a go-signal, not a liability, in the Republican primary. Candidates who name NCAE as an obstacle to reform consolidate the reform-conservative donor base.',
     'PRIMARY', 5),
    ('NOGO', 'Do NOT run a "protect public schools" defense campaign. That is the Democrat frame. Republican SPI must be offensively positioned on choice, accountability, and anti-DEI — not defending the DPI bureaucracy.',
     'ALL', 1),
    ('NOGO', 'Any softening on NCAE (NC teachers union) will lose the evangelical and MAGA donor stacks immediately. NCAE opposition is expected as a baseline in the Republican primary.',
     'PRIMARY', 2),
    ('NOGO', 'Do NOT accept expanded federal education funding without publicly articulating accountability conditions. Pairing any federal funding reference with accountability language is non-negotiable for the fiscal hawk community.',
     'ALL', 3),
    ('NOGO', 'Do NOT run a testing-abolition platform. Libertarian-leaning education donors want this but it loses the accountability and business-class communities. School performance grades are a feature, not a bug, for Republican donors.',
     'ALL', 4),
    ('NOGO', 'CRITICAL STRUCTURAL CONTEXT: The NC State Board of Education (13 members, appointed by Gov. Josh Stein, Democrat) holds superior education policymaking authority over the elected SPI. A Republican SPI will be in structural conflict with a Democrat-controlled Board. The platform must address this tension directly — donors expect the candidate to articulate how they will operate within or push against the Board. Candidates who ignore this structure will be flanked in debates.',
     'ALL', 5)
) AS v(signal_type, signal_text, applies_to, priority_rank)
WHERE o.office_code = 'SPI';


-- ─────────────────────────────────────────────────────────
-- VERIFICATION QUERY
-- ─────────────────────────────────────────────────────────
-- Expected: 22 issues | 8 archetypes | 10 signals | 7 geo overlays
/*
SELECT
    r.office_code, r.office_name,
    COUNT(DISTINCT i.intensity_id) AS issue_count,
    COUNT(DISTINCT a.match_id)     AS archetype_count,
    COUNT(DISTINCT s.signal_id)    AS signal_count,
    COUNT(DISTINCT g.overlay_id)   AS geo_overlay_count
FROM state_offices.cos_office_registry r
LEFT JOIN state_offices.cos_office_issue_intensity i ON i.office_id = r.office_id
LEFT JOIN state_offices.cos_archetype_match a         ON a.office_id = r.office_id
LEFT JOIN state_offices.cos_signals s                 ON s.office_id = r.office_id
LEFT JOIN state_offices.cos_geographic_overlay g      ON g.office_id = r.office_id
WHERE r.office_code = 'SPI'
GROUP BY r.office_code, r.office_name;
*/
