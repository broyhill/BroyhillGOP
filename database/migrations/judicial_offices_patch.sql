-- =====================================================
-- BROYHILLGOP PLATFORM — JUDICIAL OFFICES PATCH
-- NC Supreme Court + NC Court of Appeals
-- New Schema: judicial_offices
-- Date: 2026-03-15
-- =====================================================
-- ARCHITECTURAL NOTE:
--   Judicial offices require a SEPARATE schema from state_offices
--   because donor activation is philosophy-based, not issue-based.
--   NC Canon of Judicial Conduct prohibits policy pledge fundraising.
--   judicial_philosophy_intensity replaces cos_office_issue_intensity.
-- =====================================================


-- ─────────────────────────────────────────────────────────
-- CREATE SCHEMA
-- ─────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS judicial_offices;
COMMENT ON SCHEMA judicial_offices IS
  'NC Supreme Court + NC Court of Appeals — philosophy-based donor scoring. '
  'Separate from state_offices because NC Canon of Judicial Conduct prohibits '
  'policy-pledge-based fundraising. All donor activation uses judicial philosophy '
  'frames, not policy issue intensity.';


-- ─────────────────────────────────────────────────────────
-- TABLE 1: judicial_office_registry
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS judicial_offices.judicial_office_registry (
    office_id               SERIAL          PRIMARY KEY,
    office_code             VARCHAR(30)     NOT NULL UNIQUE,
    court_level             VARCHAR(20)     NOT NULL,   -- SUPREME, APPEALS
    office_name             VARCHAR(200)    NOT NULL,
    seat_number             INTEGER,                    -- NULL = TBD; specific seat when known
    term_years              INTEGER         NOT NULL DEFAULT 8,
    is_partisan             BOOLEAN         NOT NULL DEFAULT TRUE,
    is_2026_cycle           BOOLEAN         NOT NULL DEFAULT TRUE,
    current_occupant        VARCHAR(200),
    current_party           VARCHAR(10),
    is_open_seat            BOOLEAN         DEFAULT FALSE,
    is_vacancy_appointment  BOOLEAN         DEFAULT FALSE,
    competitive_class       VARCHAR(20),    -- SAFE_R, LEAN_R, COMPETITIVE, etc.
    fec_applies             BOOLEAN         NOT NULL DEFAULT FALSE,
    contribution_limit      NUMERIC(10,2),  -- NULL = no NC limit for judicial
    jurisdiction_body       VARCHAR(50)     NOT NULL DEFAULT 'NCSBE',
    canon5_restricted       BOOLEAN         NOT NULL DEFAULT TRUE, -- Always TRUE for NC judges
    geographic_scope        VARCHAR(20)     NOT NULL DEFAULT 'STATEWIDE',
    court_size              INTEGER,        -- Total judges on court
    current_composition_r   INTEGER,        -- Current Republican seat count
    current_composition_d   INTEGER,        -- Current Democrat seat count
    notes                   TEXT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE judicial_offices.judicial_office_registry IS
  'Registry of individual NC Supreme Court and Court of Appeals seats up for election. '
  'canon5_restricted=TRUE enforces that donor scoring uses philosophy frames, not policy pledges.';

COMMENT ON COLUMN judicial_offices.judicial_office_registry.canon5_restricted IS
  'ALWAYS TRUE. Enforces API-layer routing to judicial_philosophy_intensity table '
  'instead of cos_office_issue_intensity. Do not set to FALSE without legal review.';


-- ─────────────────────────────────────────────────────────
-- TABLE 2: judicial_philosophy_taxonomy
-- (Replaces issue_taxonomy for judicial offices)
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS judicial_offices.judicial_philosophy_taxonomy (
    philosophy_id       SERIAL          PRIMARY KEY,
    philosophy_code     VARCHAR(50)     NOT NULL UNIQUE,
    philosophy_name     VARCHAR(200)    NOT NULL,
    philosophy_category VARCHAR(50)     NOT NULL, -- CONSTITUTIONAL, CRIMINAL, ADMINISTRATIVE, CIVIL, FAMILY, BUSINESS
    applies_to_supreme  BOOLEAN         NOT NULL DEFAULT TRUE,
    applies_to_appeals  BOOLEAN         NOT NULL DEFAULT TRUE,
    coded_donor_language TEXT           NOT NULL,    -- Canon 5-compliant donor activation language
    is_canon5_compliant BOOLEAN         NOT NULL DEFAULT TRUE,
    description         TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE judicial_offices.judicial_philosophy_taxonomy IS
  'Canonical list of judicial philosophy frames used for donor activation scoring. '
  'All coded_donor_language entries have been reviewed for NC Canon 5 compliance — '
  'they express philosophy, not policy pledges or outcome commitments.';


-- ─────────────────────────────────────────────────────────
-- TABLE 3: judicial_philosophy_intensity
-- (Replaces cos_office_issue_intensity for judicial offices)
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS judicial_offices.judicial_philosophy_intensity (
    intensity_id        SERIAL          PRIMARY KEY,
    office_id           INTEGER         NOT NULL REFERENCES judicial_offices.judicial_office_registry(office_id) ON DELETE CASCADE,
    philosophy_id       INTEGER         NOT NULL REFERENCES judicial_offices.judicial_philosophy_taxonomy(philosophy_id) ON DELETE CASCADE,
    intensity_score     SMALLINT        NOT NULL CHECK (intensity_score BETWEEN 1 AND 5),
    tier                SMALLINT        NOT NULL CHECK (tier BETWEEN 1 AND 3),
    is_primary          BOOLEAN         NOT NULL DEFAULT FALSE,
    court_specific_note TEXT,
    rationale           TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (office_id, philosophy_id)
);

CREATE INDEX IF NOT EXISTS idx_judicial_intensity_office
    ON judicial_offices.judicial_philosophy_intensity(office_id);
CREATE INDEX IF NOT EXISTS idx_judicial_intensity_score
    ON judicial_offices.judicial_philosophy_intensity(intensity_score DESC);


-- ─────────────────────────────────────────────────────────
-- TABLE 4: judicial_archetype_match
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS judicial_offices.judicial_archetype_match (
    match_id                SERIAL          PRIMARY KEY,
    office_id               INTEGER         NOT NULL REFERENCES judicial_offices.judicial_office_registry(office_id) ON DELETE CASCADE,
    archetype_code          VARCHAR(20)     NOT NULL,
    archetype_name          VARCHAR(100)    NOT NULL,
    activation_level        SMALLINT        NOT NULL CHECK (activation_level BETWEEN 1 AND 5),
    primary_philosophy_triggers TEXT[],
    concentration_notes     TEXT,
    canon5_compliant_ask    TEXT,           -- The actual donor ask language — reviewed for Canon 5
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (office_id, archetype_code)
);


-- ─────────────────────────────────────────────────────────
-- TABLE 5: judicial_signals
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS judicial_offices.judicial_signals (
    signal_id       SERIAL          PRIMARY KEY,
    office_id       INTEGER         REFERENCES judicial_offices.judicial_office_registry(office_id) ON DELETE CASCADE,
    court_level     VARCHAR(20),    -- SUPREME, APPEALS, BOTH — NULL means all judicial offices
    signal_type     VARCHAR(10)     NOT NULL CHECK (signal_type IN ('GO','NOGO')),
    signal_text     TEXT            NOT NULL,
    applies_to      VARCHAR(30)     NOT NULL DEFAULT 'ALL', -- PRIMARY, GENERAL, ALL
    is_canon5_note  BOOLEAN         NOT NULL DEFAULT FALSE, -- TRUE = this signal is specifically about Canon 5 compliance
    priority_rank   SMALLINT        NOT NULL DEFAULT 1,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- ─────────────────────────────────────────────────────────
-- TABLE 6: judicial_seat_tracker
-- (NEW — tracks real-time seat status, vacancy, composition)
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS judicial_offices.judicial_seat_tracker (
    tracker_id              SERIAL          PRIMARY KEY,
    office_id               INTEGER         NOT NULL REFERENCES judicial_offices.judicial_office_registry(office_id) ON DELETE CASCADE,
    seat_label              VARCHAR(100)    NOT NULL,   -- e.g. "NC Supreme Court - Seat 3"
    incumbent_name          VARCHAR(200),
    incumbent_party         VARCHAR(10),
    term_expiration_year    INTEGER,
    is_vacancy              BOOLEAN         NOT NULL DEFAULT FALSE,
    vacancy_reason          VARCHAR(50),    -- RETIREMENT, DEATH, ELEVATION, APPOINTMENT
    appointed_occupant      VARCHAR(200),   -- If vacancy was filled by Gov appointment
    appointed_by_party      VARCHAR(10),
    primary_date            DATE,
    general_date            DATE,
    r_candidate             VARCHAR(200),
    d_candidate             VARCHAR(200),
    competitive_rating      VARCHAR(20),
    last_updated            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    notes                   TEXT
);

COMMENT ON TABLE judicial_offices.judicial_seat_tracker IS
  'Real-time seat status for Supreme Court and Court of Appeals races. '
  'Updated as candidates file and vacancy status changes. '
  'Drives the donor heat map competitive-priority weighting.';


-- ─────────────────────────────────────────────────────────
-- SEED: judicial_office_registry
-- ─────────────────────────────────────────────────────────

INSERT INTO judicial_offices.judicial_office_registry
    (office_code, court_level, office_name, seat_number, term_years, is_partisan,
     is_2026_cycle, competitive_class, fec_applies, canon5_restricted,
     court_size, current_composition_r, current_composition_d, notes)
VALUES
    -- NC Supreme Court (7 justices — multiple seats may be on 2026 ballot)
    ('NCSUPCT_S1', 'SUPREME', 'NC Supreme Court Justice — Seat 1 (2026 Cycle)', 1, 8, TRUE,
     TRUE, 'LEAN_R', FALSE, TRUE, 7, 5, 2,
     'Republicans hold 5-2 majority. Defending majority is the primary strategic objective.'),

    ('NCSUPCT_S2', 'SUPREME', 'NC Supreme Court Justice — Seat 2 (2026 Cycle)', 2, 8, TRUE,
     TRUE, 'LEAN_R', FALSE, TRUE, 7, 5, 2,
     'Second seat if applicable. Update seat_number and current_occupant when 2026 filings confirmed.'),

    -- NC Court of Appeals (15 judges — multiple seats in 2026)
    ('NCCOA_S1',  'APPEALS', 'NC Court of Appeals Judge — Seat 1 (2026 Cycle)',  1, 8, TRUE,
     TRUE, 'LEAN_R', FALSE, TRUE, 15, NULL, NULL,
     'Update competitive_class and current_occupant when 2026 candidates file.'),

    ('NCCOA_S2',  'APPEALS', 'NC Court of Appeals Judge — Seat 2 (2026 Cycle)',  2, 8, TRUE,
     TRUE, 'LEAN_R', FALSE, TRUE, 15, NULL, NULL, NULL),

    ('NCCOA_S3',  'APPEALS', 'NC Court of Appeals Judge — Seat 3 (2026 Cycle)',  3, 8, TRUE,
     TRUE, 'COMPETITIVE', FALSE, TRUE, 15, NULL, NULL, NULL),

    ('NCCOA_S4',  'APPEALS', 'NC Court of Appeals Judge — Seat 4 (2026 Cycle)',  4, 8, TRUE,
     TRUE, 'LEAN_R', FALSE, TRUE, 15, NULL, NULL, NULL),

    ('NCCOA_S5',  'APPEALS', 'NC Court of Appeals Judge — Seat 5 (2026 Cycle)',  5, 8, TRUE,
     TRUE, 'LEAN_R', FALSE, TRUE, 15, NULL, NULL, NULL)

ON CONFLICT (office_code) DO NOTHING;


-- ─────────────────────────────────────────────────────────
-- SEED: judicial_philosophy_taxonomy
-- ─────────────────────────────────────────────────────────

INSERT INTO judicial_offices.judicial_philosophy_taxonomy
    (philosophy_code, philosophy_name, philosophy_category,
     applies_to_supreme, applies_to_appeals, coded_donor_language, description)
VALUES

    -- CONSTITUTIONAL
    ('ORIGINALISM',          'Originalism / Textualism',                         'CONSTITUTIONAL', TRUE,  TRUE,
     'I will interpret the NC Constitution as written, not as I wish it said.',
     'Core conservative judicial philosophy — donor activation across all archetypes'),

    ('ANTI_ACTIVISM',        'Anti-Judicial Activism',                           'CONSTITUTIONAL', TRUE,  TRUE,
     'Courts make law, not policy — that role belongs exclusively to the legislature.',
     'Universal Republican donor activation frame for all judicial offices'),

    ('ELECTION_LAW_FIDELITY','Election Law / Voter ID Fidelity',                 'CONSTITUTIONAL', TRUE,  TRUE,
     'I will uphold the will of the voters expressed through validly enacted election law.',
     'Highest activation for MAGA and establishment donors post-2022 court flip narrative'),

    ('REDISTRICTING_DEFENSE','Redistricting / Legislative Map Defense',          'CONSTITUTIONAL', TRUE,  FALSE,
     'Redistricting is a legislative, not judicial, function.',
     'Supreme Court-specific — the 2023 Harper v. Hall reversal is the donor proof point'),

    ('PROPERTY_RIGHTS',      'Property Rights / Regulatory Takings',             'CONSTITUTIONAL', TRUE,  TRUE,
     'Government must compensate when it takes or substantially burdens private property.',
     'Rural, agricultural, and business donor activation'),

    -- CRIMINAL
    ('CRIMINAL_VICTIMS_RIGHTS','Criminal Law / Victims Rights',                  'CRIMINAL',       TRUE,  TRUE,
     'I will not substitute my personal sympathies for the criminal penalties the legislature enacted.',
     'LEO and defense donor primary trigger; Court of Appeals decides most criminal appeals'),

    ('SECOND_AMENDMENT',     'Second Amendment / Constitutional Carry',           'CRIMINAL',       TRUE,  TRUE,
     'The Second Amendment is not a second-class constitutional right.',
     'MAGA and rural/defense donor activation'),

    -- ADMINISTRATIVE
    ('ANTI_ADMIN_STATE',     'Anti-Administrative State / Agency Deference',     'ADMINISTRATIVE', TRUE,  TRUE,
     'State agencies interpret their own authority broadly — courts interpret law, not agencies.',
     'NC equivalent of anti-Chevron deference; fiscal hawk and business donor activation'),

    ('ANTI_DEI_GOV_CONTRACTS','Anti-DEI in Government Employment / Contracting', 'ADMINISTRATIVE', FALSE, TRUE,
     'Government employment and contracting decisions must be based on merit, as the law requires.',
     'Court of Appeals-specific — reviews agency and government DEI program challenges'),

    -- CIVIL / FAMILY
    ('RELIGIOUS_LIBERTY_JUD','Religious Liberty Jurisprudence',                  'CIVIL',          TRUE,  TRUE,
     'Faith institutions and individuals operate free from government compulsion in matters of faith.',
     'Evangelical donor primary trigger for all judicial races'),

    ('PARENTAL_RIGHTS_JUD',  'Parental Rights / Education Law',                  'FAMILY',         TRUE,  TRUE,
     'Parents, not government bureaucracies, are the primary decision-makers for their children.',
     'Suburban parent and evangelical donor activation'),

    ('ANTI_TORT_EXPANSION',  'Anti-Tort Expansion',                              'CIVIL',          TRUE,  TRUE,
     'Courts should not expand tort liability beyond what the legislature explicitly authorized.',
     'Business and fiscal hawk donor activation — limits trial lawyer plaintiffs bar'),

    ('LIFE_SANCTITY',        'Life / Sanctity of Life',                          'CIVIL',          TRUE,  FALSE,
     'I will apply NC statutes as enacted by the General Assembly — I will not create rights the legislature did not create.',
     'Evangelical activation — Canon 5 compliant framing (apply statute, not pledge outcome)'),

    -- BUSINESS
    ('CONTRACT_ENFORCEMENT', 'Business / Contract Enforcement',                  'BUSINESS',       TRUE,  TRUE,
     'NC must be a state where contracts mean what they say and courts enforce them without judicial rewrite.',
     'Establishment and business class donor activation'),

    ('ENV_REGULATORY_BALANCE','Environmental / Regulatory Balance',              'BUSINESS',       FALSE, TRUE,
     'NC landowners and businesses have constitutional protections against regulatory overreach.',
     'Rural and business donor activation for Court of Appeals regulatory review cases')

ON CONFLICT (philosophy_code) DO NOTHING;


-- ─────────────────────────────────────────────────────────
-- SEED: judicial_philosophy_intensity
-- (Separate inserts for Supreme Court and Court of Appeals)
-- ─────────────────────────────────────────────────────────

-- NC SUPREME COURT — intensity for all Supreme Court seats
INSERT INTO judicial_offices.judicial_philosophy_intensity
    (office_id, philosophy_id, intensity_score, tier, is_primary, court_specific_note)
SELECT
    o.office_id,
    p.philosophy_id,
    v.intensity_score,
    v.tier,
    v.is_primary,
    v.court_specific_note
FROM judicial_offices.judicial_office_registry o
CROSS JOIN (VALUES
    ('ORIGINALISM',           5, 1, TRUE,  'Universal conservative judicial donor activation entry point'),
    ('ANTI_ACTIVISM',         5, 1, TRUE,  'Supreme Court is where activist rulings do the most damage — highest activation'),
    ('ELECTION_LAW_FIDELITY', 5, 1, TRUE,  '2022 court flip + 2023 reversal of voter ID/redistricting is the live proof point'),
    ('REDISTRICTING_DEFENSE', 5, 1, TRUE,  'Supreme Court-specific; Harper v. Hall reversal is the donor narrative'),
    ('PROPERTY_RIGHTS',       5, 1, FALSE, 'Final court on NC constitutional property protections'),
    ('SECOND_AMENDMENT',      4, 2, FALSE, 'Supreme Court is final arbiter of 2A under NC Constitution'),
    ('RELIGIOUS_LIBERTY_JUD', 4, 2, FALSE, 'Evangelical activation; Supreme Court sets binding statewide religious liberty precedent'),
    ('PARENTAL_RIGHTS_JUD',   4, 2, FALSE, 'School choice constitutionality (Opportunity Scholarships) was a Supreme Court question'),
    ('ANTI_ADMIN_STATE',      4, 2, FALSE, 'Supreme Court reviews state agency rulemaking authority — anti-Chevron equivalent'),
    ('CRIMINAL_VICTIMS_RIGHTS',4,2, FALSE, 'Supreme Court sets criminal law standards for entire NC judiciary'),
    ('CONTRACT_ENFORCEMENT',  4, 2, FALSE, 'Business community activated by Supreme Court commercial law stability'),
    ('ANTI_TORT_EXPANSION',   3, 3, FALSE, 'Supreme Court sets limits on tort expansion across NC'),
    ('LIFE_SANCTITY',         3, 3, FALSE, 'Canon 5 compliant: apply NC statute as enacted — evangelical activation'),
    ('ENV_REGULATORY_BALANCE',3, 3, FALSE, 'Supreme Court reviews DENR and local government regulatory challenges')
) AS v(philosophy_code, intensity_score, tier, is_primary, court_specific_note)
JOIN judicial_offices.judicial_philosophy_taxonomy p ON p.philosophy_code = v.philosophy_code
WHERE o.court_level = 'SUPREME'
ON CONFLICT (office_id, philosophy_id) DO UPDATE SET
    intensity_score      = EXCLUDED.intensity_score,
    tier                 = EXCLUDED.tier,
    is_primary           = EXCLUDED.is_primary,
    court_specific_note  = EXCLUDED.court_specific_note,
    updated_at           = NOW();


-- NC COURT OF APPEALS — intensity for all CoA seats
INSERT INTO judicial_offices.judicial_philosophy_intensity
    (office_id, philosophy_id, intensity_score, tier, is_primary, court_specific_note)
SELECT
    o.office_id,
    p.philosophy_id,
    v.intensity_score,
    v.tier,
    v.is_primary,
    v.court_specific_note
FROM judicial_offices.judicial_office_registry o
CROSS JOIN (VALUES
    ('ORIGINALISM',             5, 1, TRUE,  'Entry-level philosophy signal; same activation as Supreme Court'),
    ('ANTI_ACTIVISM',           5, 1, TRUE,  'Panels of 3 judges — anti-activism framing resonates strongly at intermediate level'),
    ('CRIMINAL_VICTIMS_RIGHTS', 5, 1, TRUE,  'Court of Appeals decides ~4,000 cases/year; most are criminal appeals — #1 LEO activation'),
    ('ANTI_ADMIN_STATE',        5, 1, TRUE,  'Court reviews all NC state agency decisions — anti-Chevron deference primary activation'),
    ('ELECTION_LAW_FIDELITY',   4, 2, FALSE, 'Court of Appeals reviews election law challenges before Supreme Court'),
    ('PARENTAL_RIGHTS_JUD',     4, 2, FALSE, 'Most family law appeals resolved at CoA; parental rights frame activates suburban parents'),
    ('PROPERTY_RIGHTS',         4, 2, FALSE, 'Court reviews local government regulatory decisions affecting property'),
    ('RELIGIOUS_LIBERTY_JUD',   4, 2, FALSE, 'Faith community gives to CoA candidates who signal religious liberty philosophy'),
    ('SECOND_AMENDMENT',        4, 2, FALSE, 'Court reviews firearm-related criminal and civil law at intermediate level'),
    ('CONTRACT_ENFORCEMENT',    4, 2, FALSE, 'Primary venue for commercial law appeals in NC — business community activation'),
    ('ANTI_TORT_EXPANSION',     3, 3, FALSE, 'Court sets intermediate tort precedent that all trial courts must follow'),
    ('ANTI_DEI_GOV_CONTRACTS',  3, 3, FALSE, 'Court reviews DEI mandates in government employment and contracting — anti-woke activation'),
    ('ENV_REGULATORY_BALANCE',  3, 3, FALSE, 'Court reviews DENR and local land use decisions'),
    ('LIFE_SANCTITY',           3, 3, FALSE, 'Canon 5 compliant framing; evangelical activation at intermediate level')
) AS v(philosophy_code, intensity_score, tier, is_primary, court_specific_note)
JOIN judicial_offices.judicial_philosophy_taxonomy p ON p.philosophy_code = v.philosophy_code
WHERE o.court_level = 'APPEALS'
ON CONFLICT (office_id, philosophy_id) DO UPDATE SET
    intensity_score      = EXCLUDED.intensity_score,
    tier                 = EXCLUDED.tier,
    is_primary           = EXCLUDED.is_primary,
    court_specific_note  = EXCLUDED.court_specific_note,
    updated_at           = NOW();


-- ─────────────────────────────────────────────────────────
-- SEED: judicial_archetype_match
-- ─────────────────────────────────────────────────────────

-- NC SUPREME COURT archetypes
INSERT INTO judicial_offices.judicial_archetype_match
    (office_id, archetype_code, archetype_name, activation_level,
     primary_philosophy_triggers, concentration_notes, canon5_compliant_ask)
SELECT o.office_id, v.archetype_code, v.archetype_name, v.activation_level,
       v.primary_philosophy_triggers, v.concentration_notes, v.canon5_compliant_ask
FROM judicial_offices.judicial_office_registry o
CROSS JOIN (VALUES
    ('MAGA',    'MAGA Hardliner',              5,
     ARRAY['ELECTION_LAW_FIDELITY','ANTI_ACTIVISM','REDISTRICTING_DEFENSE'],
     '2022 court flip + 2023 ruling reversals is the highest-ROI narrative; donors give when they understand stakes',
     '"One seat = one majority = one reversal. We need your help to defend what we won in 2022."'),
    ('EVAN',    'Evangelical / Faith-Based',   5,
     ARRAY['RELIGIOUS_LIBERTY_JUD','LIFE_SANCTITY','PARENTAL_RIGHTS_JUD','ANTI_ACTIVISM'],
     'Faith donors are the single largest judicial donor community in NC; Supreme Court has greatest activation pull',
     '"Judge [X] will faithfully apply the law as written — not invent rights the legislature never created."'),
    ('FISC',    'Fiscal Hawk',                 4,
     ARRAY['PROPERTY_RIGHTS','ANTI_ADMIN_STATE','CONTRACT_ENFORCEMENT','ANTI_TORT_EXPANSION'],
     'Business and property donor community; motivated by regulatory predictability and contract stability',
     '"NC''s business climate depends on courts that enforce contracts and protect property — not rewrite them."'),
    ('BUSI',    'Establishment / Business',    4,
     ARRAY['CONTRACT_ENFORCEMENT','ANTI_ADMIN_STATE','PROPERTY_RIGHTS','ANTI_TORT_EXPANSION'],
     'Charlotte, Raleigh, Greensboro chamber/business community; rule-of-law framing is the unlock',
     '"Regulatory predictability and contract enforcement are the foundation of NC''s economic competitiveness."'),
    ('ANTIWOKE','Anti-Woke',                   4,
     ARRAY['ANTI_ACTIVISM','ELECTION_LAW_FIDELITY','ANTI_ADMIN_STATE'],
     'Statewide distribution; motivated by stopping courts from legislating progressive outcomes from the bench',
     '"Courts that make law instead of applying it are the greatest threat to self-governance."'),
    ('DEF',     'Defense / LEO / Veterans',    3,
     ARRAY['CRIMINAL_VICTIMS_RIGHTS','SECOND_AMENDMENT','ELECTION_LAW_FIDELITY'],
     'LEO community respects Supreme Court''s criminal law standard-setting role',
     '"Judge [X] will not let sympathy for defendants override what the legislature determined was just."'),
    ('AGRI',    'Rural / Agricultural',        3,
     ARRAY['PROPERTY_RIGHTS','ENV_REGULATORY_BALANCE','ANTI_ADMIN_STATE'],
     'Rural landowner donor community; property rights and regulatory takings frame',
     '"NC landowners deserve a Supreme Court that takes constitutional property protections seriously."')
) AS v(archetype_code, archetype_name, activation_level, primary_philosophy_triggers, concentration_notes, canon5_compliant_ask)
WHERE o.court_level = 'SUPREME'
ON CONFLICT (office_id, archetype_code) DO UPDATE SET
    activation_level             = EXCLUDED.activation_level,
    primary_philosophy_triggers  = EXCLUDED.primary_philosophy_triggers,
    canon5_compliant_ask         = EXCLUDED.canon5_compliant_ask;


-- NC COURT OF APPEALS archetypes
INSERT INTO judicial_offices.judicial_archetype_match
    (office_id, archetype_code, archetype_name, activation_level,
     primary_philosophy_triggers, concentration_notes, canon5_compliant_ask)
SELECT o.office_id, v.archetype_code, v.archetype_name, v.activation_level,
       v.primary_philosophy_triggers, v.concentration_notes, v.canon5_compliant_ask
FROM judicial_offices.judicial_office_registry o
CROSS JOIN (VALUES
    ('DEF',     'Defense / LEO / Veterans',    5,
     ARRAY['CRIMINAL_VICTIMS_RIGHTS','SECOND_AMENDMENT','ANTI_ACTIVISM'],
     'LEO community MORE activated by CoA than Supreme Court when briefed on case volume — 4,000+ cases/year',
     '"The Court of Appeals decides more criminal cases in a year than the Supreme Court does in a decade. Every ruling matters."'),
    ('MAGA',    'MAGA Hardliner',              4,
     ARRAY['ELECTION_LAW_FIDELITY','ANTI_ACTIVISM','CRIMINAL_VICTIMS_RIGHTS'],
     'Election law challenges often resolved at CoA; tough-on-crime frame activates MAGA donors',
     '"Today''s Court of Appeals is tomorrow''s Supreme Court — and it decides 95% of NC appellate law today."'),
    ('EVAN',    'Evangelical / Faith-Based',   4,
     ARRAY['RELIGIOUS_LIBERTY_JUD','PARENTAL_RIGHTS_JUD','LIFE_SANCTITY'],
     'Family law + religious liberty frame; most family appeals never reach Supreme Court',
     '"Most family law decisions in NC are finalized at the Court of Appeals. This is where parental rights are won or lost."'),
    ('BUSI',    'Establishment / Business',    4,
     ARRAY['CONTRACT_ENFORCEMENT','ANTI_TORT_EXPANSION','ANTI_ADMIN_STATE'],
     'Primary venue for commercial law appeals; business community understands CoA is where day-to-day law is made',
     '"The Court of Appeals is where NC business law is actually made — every commercial dispute ends here."'),
    ('FISC',    'Fiscal Hawk',                 3,
     ARRAY['ANTI_ADMIN_STATE','PROPERTY_RIGHTS','ENV_REGULATORY_BALANCE'],
     'Anti-regulatory-state framing; CoA reviews all state agency decisions',
     '"Every state agency overreach case in NC is reviewed by the Court of Appeals. We need judges who understand limits."'),
    ('ANTIWOKE','Anti-Woke',                   3,
     ARRAY['ANTI_DEI_GOV_CONTRACTS','ANTI_ADMIN_STATE','ANTI_ACTIVISM'],
     'Government DEI program challenges land at CoA; anti-woke donors motivated by this pipeline',
     '"Government DEI mandates in employment and contracting are reviewed by the Court of Appeals. Philosophy matters."')
) AS v(archetype_code, archetype_name, activation_level, primary_philosophy_triggers, concentration_notes, canon5_compliant_ask)
WHERE o.court_level = 'APPEALS'
ON CONFLICT (office_id, archetype_code) DO UPDATE SET
    activation_level             = EXCLUDED.activation_level,
    primary_philosophy_triggers  = EXCLUDED.primary_philosophy_triggers,
    canon5_compliant_ask         = EXCLUDED.canon5_compliant_ask;


-- ─────────────────────────────────────────────────────────
-- SEED: judicial_signals
-- ─────────────────────────────────────────────────────────

INSERT INTO judicial_offices.judicial_signals
    (court_level, signal_type, signal_text, applies_to, is_canon5_note, priority_rank)
VALUES
    -- GO signals
    ('SUPREME', 'GO',
     '"One seat = one majority = one reversal." Every archetype gives when they understand that flipping a single Supreme Court seat can reverse redistricting, voter ID, school choice, and religious liberty rulings at once. The 2022-2023 actual flip and reversal narrative is the proof point — always use it.',
     'ALL', FALSE, 1),

    ('SUPREME', 'GO',
     'Evangelical activation: Judicial candidates CAN say they will "faithfully apply NC statutes as enacted" without pledging a specific outcome on life-related issues. This is the Canon 5-compliant coded signal the faith donor community recognizes. Do not go beyond this language.',
     'ALL', TRUE, 2),

    ('SUPREME', 'GO',
     '"Regulatory predictability and contract enforcement are the foundation of NC''s business climate" is the establishment donor unlock for Supreme Court races. Activates chamber/business donors without impermissible pledges.',
     'ALL', FALSE, 3),

    ('APPEALS', 'GO',
     'LEO/Defense primary activation: "The Court of Appeals decides more criminal cases in a year than the Supreme Court does in a decade." The LEO/defense/veterans community is MORE activated by a Court of Appeals race than a Supreme Court race when properly briefed on case volume.',
     'ALL', FALSE, 1),

    ('APPEALS', 'GO',
     '"Today''s Court of Appeals judge is tomorrow''s Supreme Court justice." The pipeline frame activates long-view donors — establishment, business, and evangelical communities who think generationally about the courts.',
     'ALL', FALSE, 2),

    ('APPEALS', 'GO',
     '"The Court of Appeals is where 95% of NC appellate law is actually made — most cases never reach the Supreme Court." Activates sophisticated donors who want maximum jurisprudential impact per dollar given.',
     'ALL', FALSE, 3),

    -- NO-GO signals (shared across both courts where relevant)
    ('SUPREME', 'NOGO',
     'CANON 5 HARD RULE: Candidates who pledge specific rulings on identified cases or issues are subject to judicial conduct disciplinary complaint. ALL activation language must be PHILOSOPHY-based (e.g., "apply law as written") NOT OUTCOME-based (e.g., "I will rule against X"). Legal review required before any new donor ask language is deployed.',
     'ALL', TRUE, 1),

    ('APPEALS', 'NOGO',
     'CANON 5 HARD RULE: Identical Canon 5 restrictions apply to Court of Appeals candidates. No policy pledges, no personal solicitation, no misrepresentation of opponent record. All fundraising through committee only.',
     'ALL', TRUE, 1),

    ('SUPREME', 'NOGO',
     '"I am a fair and impartial judge" is NOT an activation message. Vague fairness framing activates nobody. Donors give to candidates who signal conservative judicial philosophy clearly — originalism, anti-activism, property rights, rule of law. Generic fairness is the non-partisan voter message, not the donor message.',
     'ALL', FALSE, 2),

    ('APPEALS', 'NOGO',
     'Never allow a Court of Appeals race to be framed as "less important" than the Supreme Court. The donor community systematically undervalues intermediate appellate courts. Combat this directly with the case volume argument and pipeline argument on every ask.',
     'ALL', FALSE, 2),

    ('APPEALS', 'NOGO',
     'Do NOT suggest candidates will influence panel composition (which judges sit together on cases). That is the Chief Judge''s administrative function. Any suggestion of panel manipulation is a judicial conduct violation and donor-credibility liability.',
     'ALL', TRUE, 3);


-- ─────────────────────────────────────────────────────────
-- VIEW: judicial_office_readiness
-- (Combines registry + tracker + seat count for heat map targeting)
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW judicial_offices.vw_judicial_office_readiness AS
SELECT
    r.office_code,
    r.court_level,
    r.office_name,
    r.seat_number,
    r.competitive_class,
    r.current_composition_r,
    r.current_composition_d,
    r.is_open_seat,
    t.incumbent_name,
    t.incumbent_party,
    t.is_vacancy,
    t.r_candidate,
    t.d_candidate,
    t.primary_date,
    t.general_date,
    COUNT(DISTINCT pi.intensity_id)  AS philosophy_scores_loaded,
    COUNT(DISTINCT am.match_id)      AS archetype_profiles_loaded,
    COUNT(DISTINCT sig.signal_id)    AS signals_loaded,
    CASE
        WHEN COUNT(DISTINCT pi.intensity_id) > 0
         AND COUNT(DISTINCT am.match_id) > 0
         AND COUNT(DISTINCT sig.signal_id) > 0
        THEN TRUE ELSE FALSE
    END AS heat_map_ready
FROM judicial_offices.judicial_office_registry r
LEFT JOIN judicial_offices.judicial_seat_tracker t ON t.office_id = r.office_id
LEFT JOIN judicial_offices.judicial_philosophy_intensity pi ON pi.office_id = r.office_id
LEFT JOIN judicial_offices.judicial_archetype_match am ON am.office_id = r.office_id
LEFT JOIN judicial_offices.judicial_signals sig ON sig.court_level = r.court_level OR sig.office_id = r.office_id
GROUP BY r.office_code, r.court_level, r.office_name, r.seat_number,
         r.competitive_class, r.current_composition_r, r.current_composition_d,
         r.is_open_seat, t.incumbent_name, t.incumbent_party, t.is_vacancy,
         t.r_candidate, t.d_candidate, t.primary_date, t.general_date;


-- ─────────────────────────────────────────────────────────
-- GRANT (adjust role names to match your environment)
-- ─────────────────────────────────────────────────────────
-- GRANT USAGE ON SCHEMA judicial_offices TO broyhillgop_app;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA judicial_offices TO broyhillgop_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA judicial_offices TO broyhillgop_app;
