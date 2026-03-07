-- ============================================================
-- BroyhillGOP PERSON MASTER SCHEMA
-- ============================================================
-- The central truth: a PERSON is a human being who can wear
-- multiple hats — donor, candidate, volunteer, delegate,
-- elected official, party officer, candidate family, friend.
--
-- Every person gets ONE master record. Roles are flags.
-- Prefixes (Governor, Senator, Judge, Honorable) are SACRED.
-- Preferred names (Ed, not James Edgar) are REQUIRED.
-- Address NUMBER (525) is the dedup key, not the full street.
--
-- Author: BroyhillGOP AI Platform
-- Date: February 11, 2026
-- ============================================================

-- ============================================================
-- 1. PERSONS_MASTER — THE one record per human being
-- ============================================================
CREATE TABLE IF NOT EXISTS persons_master (
    -- Primary identity
    person_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- === NAME FIELDS (all preserved, never stripped) ===
    prefix                  TEXT,           -- Mr., Mrs., Ms., Dr., Hon., Gov., Sen., Rep., Judge, Sheriff, Cong.
    first_name              TEXT NOT NULL,
    middle_name             TEXT,
    last_name               TEXT NOT NULL,
    suffix                  TEXT,           -- Jr, Sr, II, III, IV, Esq, MD, PhD
    preferred_name          TEXT,           -- "Ed" not "James Edgar", "Art" not "James Arthur"
    full_legal_name         TEXT,           -- "James Edgar Broyhill II" — computed or entered
    name_on_ballot          TEXT,           -- for candidates: how their name appears on ballot
    formal_salutation       TEXT,           -- "Dear Governor Bingham" / "Dear Ed"
    mail_salutation         TEXT,           -- "The Honorable Robert Bingham" / "Mr. Ed Broyhill"

    -- === ADDRESS (parsed components for matching) ===
    address_number          TEXT,           -- "525" — THE dedup key
    address_street          TEXT,           -- "N Hawthorne Rd" — street without number
    address_full            TEXT,           -- "525 N Hawthorne Rd" — full street line
    address_line_2          TEXT,           -- Suite, Apt, Unit
    city                    TEXT,
    state                   TEXT DEFAULT 'NC',
    zip5                    TEXT,           -- 5-digit zip
    zip4                    TEXT,           -- +4 extension
    county                  TEXT,           -- normalized county name

    -- === BUSINESS ADDRESS ===
    business_address        TEXT,
    business_city           TEXT,
    business_state          TEXT,
    business_zip            TEXT,

    -- === PHONES (with source attribution) ===
    cell_phone              TEXT,
    cell_phone_source       TEXT,           -- RNC, WinRed, NCGOP, Data Zapp, Acuity, iPhone
    home_phone              TEXT,
    home_phone_source       TEXT,
    business_phone          TEXT,
    business_phone_source   TEXT,
    other_phone             TEXT,
    other_phone_source      TEXT,

    -- === EMAIL ===
    email                   TEXT,
    email_source            TEXT,           -- NCGOP, WinRed, Data Zapp, Acuity, iPhone
    email_secondary         TEXT,

    -- === PROFESSIONAL ===
    employer                TEXT,
    occupation              TEXT,
    profession              TEXT,           -- from NCBOE "Profession/Job Title"
    linkedin_url            TEXT,

    -- === ROLE FLAGS (a person can be ALL of these simultaneously) ===
    is_donor                BOOLEAN DEFAULT FALSE,
    is_candidate            BOOLEAN DEFAULT FALSE,
    is_volunteer            BOOLEAN DEFAULT FALSE,
    is_delegate             BOOLEAN DEFAULT FALSE,
    is_elected_official     BOOLEAN DEFAULT FALSE,
    is_party_official       BOOLEAN DEFAULT FALSE,   -- precinct chair, county chair, state committee
    is_candidate_family     BOOLEAN DEFAULT FALSE,
    is_candidate_friend     BOOLEAN DEFAULT FALSE,
    is_trump_donor          BOOLEAN DEFAULT FALSE,
    is_ncboe_donor          BOOLEAN DEFAULT FALSE,
    is_fec_donor            BOOLEAN DEFAULT FALSE,

    -- === CUSTOM ROLE TAGS (flexible JSON array for any category) ===
    -- e.g., ["rally_attendee", "newsletter_subscriber", "event_host", "surrogate"]
    custom_tags             JSONB DEFAULT '[]'::jsonb,

    -- === DONOR DATA (aggregated) ===
    donations_total         NUMERIC(12,2) DEFAULT 0,
    donations_fec_total     NUMERIC(12,2) DEFAULT 0,
    donations_ncboe_total   NUMERIC(12,2) DEFAULT 0,
    donation_count          INTEGER DEFAULT 0,
    first_donation_date     DATE,
    last_donation_date      DATE,
    donation_rank           INTEGER,         -- rank among all donors
    donor_grade             TEXT,            -- A++, A+, A, A-, B+, B, B-, C+, C, C-, D, U
    top_committee_fec       TEXT,            -- committee they gave most to (federal)
    top_committee_ncboe     TEXT,            -- committee they gave most to (state)
    top_candidate_fec       TEXT,            -- candidate they supported most (federal)
    top_candidate_ncboe     TEXT,            -- candidate they supported most (state)

    -- === VOTER FILE LINK (sync to nc_voters + nc_datatrust) ===
    ncid                    TEXT,            -- NC voter registration ID (e.g., BY682764)
    rnc_regid               TEXT,            -- RNC DataHub registration GUID
    voter_status            TEXT,            -- Active, Inactive, Removed
    registered_party        TEXT,            -- REP, DEM, UNA, LIB
    registration_date       DATE,
    birth_year              INTEGER,
    age                     INTEGER,
    sex                     TEXT,

    -- === DATATRUST ENRICHMENT ===
    household_id            TEXT,            -- RNC HouseholdID for family grouping
    modeled_income          TEXT,            -- from DataTrust
    modeled_education       TEXT,
    modeled_ethnicity       TEXT,
    modeled_religion        TEXT,
    republican_ballot_score INTEGER,         -- 0-100 propensity
    turnout_score           INTEGER,         -- 0-100 propensity

    -- === DEDUP MATCHING FIELDS ===
    match_key               TEXT,            -- last_name|first3|zip5|addr_num
    name_variants           TEXT[],          -- all known name variations as array
    master_person_id_legacy UUID,            -- link to existing persons table ID
    group_id                INTEGER,         -- from delegate/volunteer files
    is_master_record        BOOLEAN DEFAULT TRUE,

    -- === SOURCE TRACKING ===
    source_files            TEXT,            -- comma-separated: "Masterfile,WinRed,Delegates"
    apollo_enriched         BOOLEAN DEFAULT FALSE,
    datatrust_enriched      BOOLEAN DEFAULT FALSE,
    voter_file_matched      BOOLEAN DEFAULT FALSE,

    -- === SCORING ===
    total_score             NUMERIC(6,2) DEFAULT 0,

    -- === METADATA ===
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW(),
    created_by              TEXT DEFAULT 'system',
    notes                   TEXT
);

-- ============================================================
-- 2. INDEXES for persons_master
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_pm_last_name ON persons_master(last_name);
CREATE INDEX IF NOT EXISTS idx_pm_name ON persons_master(last_name, first_name);
CREATE INDEX IF NOT EXISTS idx_pm_match_key ON persons_master(match_key);
CREATE INDEX IF NOT EXISTS idx_pm_zip ON persons_master(zip5);
CREATE INDEX IF NOT EXISTS idx_pm_addr_num ON persons_master(address_number, zip5);
CREATE INDEX IF NOT EXISTS idx_pm_ncid ON persons_master(ncid);
CREATE INDEX IF NOT EXISTS idx_pm_rnc_regid ON persons_master(rnc_regid);
CREATE INDEX IF NOT EXISTS idx_pm_county ON persons_master(county);
CREATE INDEX IF NOT EXISTS idx_pm_cell ON persons_master(cell_phone);
CREATE INDEX IF NOT EXISTS idx_pm_email ON persons_master(email);
CREATE INDEX IF NOT EXISTS idx_pm_donor ON persons_master(is_donor) WHERE is_donor = TRUE;
CREATE INDEX IF NOT EXISTS idx_pm_candidate ON persons_master(is_candidate) WHERE is_candidate = TRUE;
CREATE INDEX IF NOT EXISTS idx_pm_volunteer ON persons_master(is_volunteer) WHERE is_volunteer = TRUE;
CREATE INDEX IF NOT EXISTS idx_pm_delegate ON persons_master(is_delegate) WHERE is_delegate = TRUE;
CREATE INDEX IF NOT EXISTS idx_pm_official ON persons_master(is_elected_official) WHERE is_elected_official = TRUE;
CREATE INDEX IF NOT EXISTS idx_pm_grade ON persons_master(donor_grade);
CREATE INDEX IF NOT EXISTS idx_pm_household ON persons_master(household_id);
CREATE INDEX IF NOT EXISTS idx_pm_group ON persons_master(group_id);

-- ============================================================
-- 3. CANDIDATE PROFILES — extended data for is_candidate=TRUE
-- ============================================================
CREATE TABLE IF NOT EXISTS candidate_profiles_master (
    candidate_profile_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id               UUID NOT NULL REFERENCES persons_master(person_id),

    -- === ELECTION HISTORY ===
    -- Each row = one candidacy. A person can run multiple times.
    election_year           INTEGER,
    election_date           DATE,
    election_type           TEXT,            -- General, Primary, Municipal, Special
    contest_name            TEXT,            -- "NC SENATE DISTRICT 31", "US HOUSE OF REPRESENTATIVES DISTRICT 05"
    office_type             TEXT,            -- US Senate, US House, Governor, NC Senate, NC House, Sheriff, etc.
    office_level            TEXT,            -- Federal, State, County, Municipal, Judicial
    district                TEXT,            -- district number or name
    county                  TEXT,            -- for county-level races

    -- === PARTY & CANDIDACY ===
    party                   TEXT DEFAULT 'REP',
    candidacy_date          DATE,
    is_incumbent            BOOLEAN DEFAULT FALSE,
    is_challenger           BOOLEAN DEFAULT FALSE,
    is_open_seat            BOOLEAN DEFAULT FALSE,

    -- === RACE DETAILS ===
    is_partisan             BOOLEAN DEFAULT TRUE,
    has_primary             BOOLEAN DEFAULT FALSE,
    is_unexpired_term       BOOLEAN DEFAULT FALSE,
    vote_for                INTEGER DEFAULT 1,
    term_length_years       INTEGER,

    -- === RESULTS ===
    won                     BOOLEAN,
    vote_total              INTEGER,
    vote_percentage         NUMERIC(5,2),
    margin_of_victory       NUMERIC(5,2),

    -- === COMMITTEE LINKS ===
    principal_committee_id  TEXT,            -- FEC committee_id (C00xxxxxx)
    principal_committee_name TEXT,
    ncsbe_committee_id      TEXT,            -- SBoE ID (STA-xxxxxx-C-001)
    ncsbe_committee_name    TEXT,

    -- === IDENTIFIERS ===
    fec_candidate_id        TEXT,            -- FEC ID (S6NC00324, H8NC05123)
    ncsbe_source_file       TEXT,            -- which Candidate_Listing file

    -- === METADATA ===
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cpm_person ON candidate_profiles_master(person_id);
CREATE INDEX IF NOT EXISTS idx_cpm_year ON candidate_profiles_master(election_year);
CREATE INDEX IF NOT EXISTS idx_cpm_office ON candidate_profiles_master(office_type);
CREATE INDEX IF NOT EXISTS idx_cpm_fec ON candidate_profiles_master(fec_candidate_id);
CREATE INDEX IF NOT EXISTS idx_cpm_ncsbe ON candidate_profiles_master(ncsbe_committee_id);
CREATE INDEX IF NOT EXISTS idx_cpm_contest ON candidate_profiles_master(contest_name);

-- ============================================================
-- 4. COMMITTEE-TO-CANDIDATE LOOKUP
-- ============================================================
CREATE TABLE IF NOT EXISTS committee_candidate_lookup (
    lookup_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Committee identity
    committee_id            TEXT NOT NULL,       -- FEC C00xxxxxx or NCSBE STA-xxxxx-C-001
    committee_name          TEXT NOT NULL,
    committee_type          TEXT,                -- Principal, PAC, Party, JFC
    committee_source        TEXT NOT NULL,       -- 'FEC' or 'NCSBE'

    -- Linked candidate
    candidate_person_id     UUID REFERENCES persons_master(person_id),
    candidate_name          TEXT,
    fec_candidate_id        TEXT,

    -- Office info
    office_type             TEXT,
    office_state            TEXT,
    office_district         TEXT,
    party                   TEXT,

    -- Metadata
    election_year           INTEGER,
    created_at              TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(committee_id, committee_source, election_year)
);

CREATE INDEX IF NOT EXISTS idx_ccl_committee ON committee_candidate_lookup(committee_id);
CREATE INDEX IF NOT EXISTS idx_ccl_name ON committee_candidate_lookup(committee_name);
CREATE INDEX IF NOT EXISTS idx_ccl_candidate ON committee_candidate_lookup(candidate_person_id);
CREATE INDEX IF NOT EXISTS idx_ccl_fec ON committee_candidate_lookup(fec_candidate_id);

-- ============================================================
-- 5. CANDIDATE PRIVATE CONTACT LISTS
-- Each candidate gets their own contact book. They can upload
-- from iPhone, add people manually, and tag with categories
-- for events, rallies, newsletters, press, etc.
-- ============================================================
CREATE TABLE IF NOT EXISTS candidate_contact_lists (
    contact_entry_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Which candidate owns this contact list
    candidate_person_id     UUID NOT NULL REFERENCES persons_master(person_id),

    -- The contact being added (may or may not be in persons_master)
    contact_person_id       UUID REFERENCES persons_master(person_id),

    -- If not in persons_master yet, store raw data here
    raw_first_name          TEXT,
    raw_last_name           TEXT,
    raw_phone               TEXT,
    raw_email               TEXT,
    raw_company             TEXT,
    raw_notes               TEXT,
    source                  TEXT,                -- 'iphone_upload', 'manual', 'csv_import', 'scan'

    -- === CATEGORY TAGS (flexible, candidate-defined) ===
    -- Examples: ["rally", "fundraiser_dinner", "newsletter", "press_contact",
    --           "family", "friend", "golf_buddy", "church", "rotary_club"]
    categories              JSONB DEFAULT '[]'::jsonb,

    -- === RELATIONSHIP ===
    relationship_type       TEXT,                -- family, friend, donor, advisor, volunteer, staff, media
    relationship_notes      TEXT,

    -- === COMMUNICATION PREFERENCES ===
    include_in_newsletter   BOOLEAN DEFAULT FALSE,
    include_in_events       BOOLEAN DEFAULT TRUE,
    include_in_fundraising  BOOLEAN DEFAULT FALSE,
    preferred_channel       TEXT DEFAULT 'email', -- email, sms, phone, mail
    do_not_contact          BOOLEAN DEFAULT FALSE,

    -- === METADATA ===
    added_by                TEXT,                -- candidate name or staff name
    added_at                TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW(),
    is_active               BOOLEAN DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_ccl_candidate_owner ON candidate_contact_lists(candidate_person_id);
CREATE INDEX IF NOT EXISTS idx_ccl_contact ON candidate_contact_lists(contact_person_id);
CREATE INDEX IF NOT EXISTS idx_ccl_categories ON candidate_contact_lists USING GIN(categories);

-- ============================================================
-- 6. FEC DONATION TRANSACTIONS (rebuilt with candidate fields)
-- ============================================================
CREATE TABLE IF NOT EXISTS fec_donations_master (
    donation_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Link to person master
    donor_person_id         UUID REFERENCES persons_master(person_id),

    -- === CONTRIBUTOR (donor) ===
    contributor_name        TEXT,            -- raw name from FEC
    contributor_prefix      TEXT,            -- col 13: Mr, Mrs, Dr, etc.
    contributor_first_name  TEXT,            -- col 18
    contributor_middle_name TEXT,            -- col 19
    contributor_last_name   TEXT,            -- col 20
    contributor_suffix      TEXT,            -- col 21: Jr, Sr, II, III
    contributor_street_1    TEXT,            -- col 22
    contributor_street_2    TEXT,            -- col 23
    contributor_city        TEXT,            -- col 24
    contributor_state       TEXT,            -- col 25
    contributor_zip         TEXT,            -- col 26
    contributor_employer    TEXT,            -- col 27
    contributor_occupation  TEXT,            -- col 28

    -- === COMMITTEE (who received the money) ===
    committee_id            TEXT,            -- col 0: C00xxxxxx
    committee_name          TEXT,            -- col 1

    -- === CANDIDATE (who the committee supports) ===
    candidate_id            TEXT,            -- col 40: S6NC00324, H8NC05123
    candidate_name          TEXT,            -- col 41
    candidate_first_name    TEXT,            -- col 42
    candidate_last_name     TEXT,            -- col 43
    candidate_office        TEXT,            -- col 47: S (Senate), H (House), P (President)
    candidate_office_full   TEXT,            -- col 48: "Senate", "House"
    candidate_office_state  TEXT,            -- col 49
    candidate_office_district TEXT,          -- col 51
    candidate_person_id     UUID REFERENCES persons_master(person_id),

    -- === TRANSACTION ===
    contribution_receipt_amount  NUMERIC(12,2) NOT NULL,
    contribution_receipt_date    DATE,
    contributor_aggregate_ytd    NUMERIC(12,2),
    election_type               TEXT,        -- col 61
    two_year_transaction_period  INTEGER,     -- col 65

    -- === FEC METADATA ===
    report_year             INTEGER,
    receipt_type            TEXT,
    memo_text               TEXT,
    filing_form             TEXT,
    sub_id                  TEXT,
    pdf_url                 TEXT,

    -- === DEDUP ===
    normalized_name         TEXT,
    resolved_name           TEXT,
    match_key               TEXT,
    address_number          TEXT,            -- extracted house number

    -- === INGESTION ===
    source_file             TEXT,
    election_cycle          TEXT,            -- "2023-2024", "2019-2020"
    ingested_at             TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fdm_donor ON fec_donations_master(donor_person_id);
CREATE INDEX IF NOT EXISTS idx_fdm_candidate ON fec_donations_master(candidate_person_id);
CREATE INDEX IF NOT EXISTS idx_fdm_committee ON fec_donations_master(committee_id);
CREATE INDEX IF NOT EXISTS idx_fdm_candidate_id ON fec_donations_master(candidate_id);
CREATE INDEX IF NOT EXISTS idx_fdm_date ON fec_donations_master(contribution_receipt_date);
CREATE INDEX IF NOT EXISTS idx_fdm_amount ON fec_donations_master(contribution_receipt_amount);
CREATE INDEX IF NOT EXISTS idx_fdm_match ON fec_donations_master(match_key);
CREATE INDEX IF NOT EXISTS idx_fdm_zip ON fec_donations_master(contributor_zip);

-- ============================================================
-- 7. NCBOE DONATION TRANSACTIONS (with candidate linkage)
-- ============================================================
CREATE TABLE IF NOT EXISTS ncboe_donations_master (
    donation_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Link to person master
    donor_person_id         UUID REFERENCES persons_master(person_id),

    -- === DONOR ===
    donor_name              TEXT,            -- raw "Name" from NCBOE
    street_line_1           TEXT,
    street_line_2           TEXT,
    city                    TEXT,
    state                   TEXT,
    zip_code                TEXT,
    profession              TEXT,            -- "Profession/Job Title"
    employer_name           TEXT,            -- "Employer's Name/Specific Field"

    -- === COMMITTEE (who received the money) ===
    committee_name          TEXT,            -- "Committee Name"
    committee_sboe_id       TEXT,            -- "Committee SBoE ID" (STA-xxxxx-C-001)
    committee_street_1      TEXT,
    committee_city          TEXT,
    committee_state         TEXT,
    committee_zip           TEXT,

    -- === CANDIDATE (resolved from committee) ===
    candidate_referendum_name TEXT,          -- col 22 "Candidate/Referendum Name"
    candidate_person_id     UUID REFERENCES persons_master(person_id),

    -- === TRANSACTION ===
    transaction_type        TEXT,            -- "Individual", "Funds from Other Committees"
    amount                  NUMERIC(12,2) NOT NULL,
    date_occurred           DATE,
    account_code            TEXT,
    form_of_payment         TEXT,
    purpose                 TEXT,
    declaration             TEXT,
    report_name             TEXT,

    -- === DEDUP ===
    normalized_name         TEXT,
    resolved_name           TEXT,
    match_key               TEXT,
    address_number          TEXT,
    master_person_id_legacy UUID,            -- from existing nc_boe_donations_raw
    household_id_legacy     UUID,

    -- === INGESTION ===
    source_file             TEXT,
    ingested_at             TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ndm_donor ON ncboe_donations_master(donor_person_id);
CREATE INDEX IF NOT EXISTS idx_ndm_candidate ON ncboe_donations_master(candidate_person_id);
CREATE INDEX IF NOT EXISTS idx_ndm_committee ON ncboe_donations_master(committee_sboe_id);
CREATE INDEX IF NOT EXISTS idx_ndm_date ON ncboe_donations_master(date_occurred);
CREATE INDEX IF NOT EXISTS idx_ndm_amount ON ncboe_donations_master(amount);
CREATE INDEX IF NOT EXISTS idx_ndm_match ON ncboe_donations_master(match_key);

-- ============================================================
-- 8. UPDATED_AT TRIGGERS
-- ============================================================
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pm_updated ON persons_master;
CREATE TRIGGER trg_pm_updated
    BEFORE UPDATE ON persons_master
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_cpm_updated ON candidate_profiles_master;
CREATE TRIGGER trg_cpm_updated
    BEFORE UPDATE ON candidate_profiles_master
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_ccl_updated ON candidate_contact_lists;
CREATE TRIGGER trg_ccl_updated
    BEFORE UPDATE ON candidate_contact_lists
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================
-- 9. USEFUL VIEWS
-- ============================================================

-- All donors with their top contributions
CREATE OR REPLACE VIEW v_donors AS
SELECT
    pm.*,
    fec.fec_total,
    fec.fec_count,
    ncboe.ncboe_total,
    ncboe.ncboe_count
FROM persons_master pm
LEFT JOIN (
    SELECT donor_person_id,
           SUM(contribution_receipt_amount) as fec_total,
           COUNT(*) as fec_count
    FROM fec_donations_master
    GROUP BY donor_person_id
) fec ON fec.donor_person_id = pm.person_id
LEFT JOIN (
    SELECT donor_person_id,
           SUM(amount) as ncboe_total,
           COUNT(*) as ncboe_count
    FROM ncboe_donations_master
    GROUP BY donor_person_id
) ncboe ON ncboe.donor_person_id = pm.person_id
WHERE pm.is_donor = TRUE;

-- All candidates with election count
CREATE OR REPLACE VIEW v_candidates AS
SELECT
    pm.person_id, pm.prefix, pm.preferred_name, pm.first_name, pm.last_name, pm.suffix,
    pm.formal_salutation, pm.cell_phone, pm.email, pm.county,
    COUNT(cpm.candidate_profile_id) as elections_run,
    MAX(cpm.election_year) as latest_election,
    BOOL_OR(cpm.won) as ever_won,
    array_agg(DISTINCT cpm.office_type) as offices_sought
FROM persons_master pm
JOIN candidate_profiles_master cpm ON cpm.person_id = pm.person_id
WHERE pm.is_candidate = TRUE
GROUP BY pm.person_id, pm.prefix, pm.preferred_name, pm.first_name, pm.last_name,
         pm.suffix, pm.formal_salutation, pm.cell_phone, pm.email, pm.county;

-- All delegates who are also donors
CREATE OR REPLACE VIEW v_delegate_donors AS
SELECT * FROM persons_master
WHERE is_delegate = TRUE AND is_donor = TRUE
ORDER BY donations_total DESC;

-- People with multiple roles
CREATE OR REPLACE VIEW v_multi_role AS
SELECT *,
    (CASE WHEN is_donor THEN 1 ELSE 0 END +
     CASE WHEN is_candidate THEN 1 ELSE 0 END +
     CASE WHEN is_volunteer THEN 1 ELSE 0 END +
     CASE WHEN is_delegate THEN 1 ELSE 0 END +
     CASE WHEN is_elected_official THEN 1 ELSE 0 END +
     CASE WHEN is_party_official THEN 1 ELSE 0 END) as role_count
FROM persons_master
WHERE (CASE WHEN is_donor THEN 1 ELSE 0 END +
       CASE WHEN is_candidate THEN 1 ELSE 0 END +
       CASE WHEN is_volunteer THEN 1 ELSE 0 END +
       CASE WHEN is_delegate THEN 1 ELSE 0 END +
       CASE WHEN is_elected_official THEN 1 ELSE 0 END +
       CASE WHEN is_party_official THEN 1 ELSE 0 END) >= 2
ORDER BY role_count DESC, donations_total DESC;

-- ============================================================
-- 10. VERIFICATION QUERIES
-- ============================================================
-- After loading, run these:
-- SELECT 'persons_master' as tbl, COUNT(*) FROM persons_master
-- UNION ALL SELECT 'candidates', COUNT(*) FROM candidate_profiles_master
-- UNION ALL SELECT 'committee_lookup', COUNT(*) FROM committee_candidate_lookup
-- UNION ALL SELECT 'fec_donations', COUNT(*) FROM fec_donations_master
-- UNION ALL SELECT 'ncboe_donations', COUNT(*) FROM ncboe_donations_master
-- UNION ALL SELECT 'contact_lists', COUNT(*) FROM candidate_contact_lists;
--
-- SELECT is_donor::text, is_candidate::text, is_volunteer::text,
--        is_delegate::text, COUNT(*)
-- FROM persons_master
-- GROUP BY is_donor, is_candidate, is_volunteer, is_delegate
-- ORDER BY COUNT(*) DESC;
