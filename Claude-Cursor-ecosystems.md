# RFC-001: Architecture Review — BroyhillGOP Database Rebuild

**Status:** DRAFT — for review before any DDL is executed
**Author:** Claude 4.6 (Anthropic), acting as Supabase/Hetzner validator
**Date:** 2026-03-03
**Audience:** Eddie Broyhill, GPT-side architect (Cursor), any future AI session

---

## 0. Purpose

A GPT-based model in Cursor has proposed a schema-separated, multi-zone architecture
for rebuilding the BroyhillGOP donor database. This document:

1. **Critiques** that design against the live Supabase state (44 GB, 667 tables, 60M+ rows).
2. **Proposes concrete DDL** for every new table, with field lists.
3. **Identifies failure modes** the GPT model may not see.
4. **Provides validation queries** to prove correctness after each phase.

Nothing in this document is rubber-stamped. Every section contains explicit
objections or refinements.

---

## 1. Critique of the Proposed Architecture

### 1.1 The Blocking Key Will Fail on the Broyhill Family

**GPT proposal:** `soundex(last_name) + zip5 + first_initial` as the blocking key
for identity resolution.

**Problem — proved from live data:**

```
BROYHILL active records, blocking by first_initial + zip5:
  ED          zip=27103    1 record     ← block "E-27103"
  ED          zip=27104    1 record     ← block "E-27104"  (different block!)
  EDGAR       zip=27104    1 record     ← block "E-27104"  (same block as ED/27104, good)
  JEDGAR      zip=27104    1 record     ← block "J-27104"  (WRONG BLOCK — same person)
  JAMES       zip=27012    1 record     ← block "J-27012"
  JAMES       zip=27103    1 record     ← block "J-27103"
  JAMES       zip=27410    1 record     ← block "J-27410"
```

Ed Broyhill's legal name is **James Edgar Broyhill II**. His first_initial is
sometimes "E" (Ed, Edgar) and sometimes "J" (James, JEdgar). These will NEVER
land in the same block under the GPT proposal. Soundex doesn't help because the
last name is the same — the problem is the first name.

**This is not an edge case.** Any donor whose preferred name starts with a
different letter than their legal name breaks this blocking key. In political
donor data this is extremely common:

- BILL / WILLIAM (B vs W)
- BOB / ROBERT (B vs R)
- DICK / RICHARD (D vs R)
- JACK / JOHN (J vs J — happens to work, but only by luck)
- TED / EDWARD (T vs E)
- PEGGY / MARGARET (P vs M)
- CHUCK / CHARLES (C vs C — works by luck)
- JIM / JAMES (J vs J — works)
- ED / JAMES (E vs J — **breaks**)

**Fix: Multi-pass blocking, not single-key blocking.**

Run identity resolution in ordered passes, each with its own blocking strategy:

| Pass | Blocking Key | Confidence | What It Catches |
|------|-------------|------------|-----------------|
| 1 | voter_ncid (exact) | 0.99 | Same voter, any name/address variation |
| 2 | email (exact, lowered) | 0.95 | Same person regardless of name spelling |
| 3 | norm_last + norm_first + zip5 | 0.95 | Exact name at same zip |
| 4 | norm_last + nickname_canonical + zip5 | 0.90 | Bill=William at same zip |
| 5 | norm_last + first_initial + zip5 + employer | 0.85 | Same initial, same employer confirms |
| 6 | norm_last + norm_first, cross-zip, with secondary signal | 0.80 | Movers: need shared email/phone/employer/ncid |

Pass 1 and 2 are the GPT model's blind spot. Voter NCID is the single strongest
identity signal in NC political data — it's a unique ID assigned by the state to
each registered voter. If two golden records share a voter_ncid, they are the same
person with 99% confidence regardless of name or address. The GPT model doesn't
mention NCID at all.

### 1.2 Schema Separation — Good Idea, Supabase Constraints

**GPT proposal:** Separate schemas for `raw`, `normalized`, `golden`, `campaign`.

**Reality:** Supabase **does** support multiple schemas, but the PostgREST API
(which powers the Supabase client library and RLS) only exposes schemas that are
explicitly configured in the API settings. Currently only `public` is exposed.

**Current non-system schemas found:**
```
public
frontend
archive
nc_data_committee
brain_control
demo_ecosystem
intelligence_brain
social_intelligence
```

Most of these are abandoned scaffolding from previous AI sessions.

**Recommendation:** Use schemas, but with a pragmatic approach:

| Schema | Purpose | PostgREST Exposed? |
|--------|---------|-------------------|
| `raw` | Immutable source data (BOE, FEC, voter, DataTrust) | No |
| `norm` | Normalized/cleaned versions of raw data | No |
| `core` | person_spine, contribution_map, candidate_committee_map | Yes (add to API config) |
| `public` | Platform tables, views, RLS-protected endpoints | Yes (already exposed) |

The `raw` and `norm` schemas should NOT be exposed via PostgREST. They're
internal. Only Hetzner jobs and stored procedures should touch them. This is a
genuine security improvement over the current state where everything is in
`public`.

**Migration risk:** Moving 667 tables across schemas will break every existing
function, view, and index that references `public.table_name`. This must be done
in a specific order with a compatibility layer (views in `public` that point to
new locations) during transition.

### 1.3 The candidate_id Gap Is Worse Than the GPT Model Thinks

**Live proof from Supabase:**
```
donor_contribution_map:
  total rows:      3,102,546
  has candidate_id: 0          ← ZERO. Not "some". ZERO.
  has committee_id: 3,102,533  ← Nearly all have committee_id
```

The GPT model proposes a `candidate_committee_map` layer. Good. But the current
`boe_committee_candidate_map` has only **1,033 rows** mapping BOE committees to
candidates. There are far more committees than that in the data.

FEC data has `committee_id` on every row but `candidate_id` on zero rows in the
contribution map (even though the raw `fec_god_contributions` table has a
`candidate_id` column — it was never carried through to the map).

**Fix:** The `candidate_committee_map` must be comprehensive:

1. **FEC committees → candidates:** Use the FEC API or bulk data to map
   `committee_id` → `candidate_id` for all federal committees in the data.
2. **BOE committees → candidates:** Expand the existing 1,033-row map. The BOE
   raw data has `candidate_referendum_name` and `committee_sboe_id` — these can
   be parsed to build the mapping.
3. **Party committees → multiple candidates:** PACs and party committees (RNC,
   NCGOP, county parties) don't map to a single candidate. These need a
   `committee_type` flag: `candidate_committee`, `party_committee`, `pac`,
   `super_pac`. Only `candidate_committee` rows get a direct `candidate_id`.

### 1.4 Preferred Name Inference — Mostly Right, One Fatal Flaw

**GPT proposal:** Within a blocking group, map raw first names into nick groups
via a nickname table, then pick the most frequent raw spelling as the preferred
name.

**The fatal flaw: bulk data skews frequency counts.**

Ed Broyhill has ~264 BOE transactions under "ED BROYHILL" and ~10 FEC transactions
under "EDGAR BROYHILL" and ~51 transactions under "JAMES BROYHILL". By
frequency, "ED" wins. That happens to be correct for Ed. But consider:

- A donor who gave once via personal check ("Bobby Smith") and 200 times via
  WinRed auto-recurring ("Robert Smith"). Frequency says "Robert" — but the
  donor goes by Bobby.
- FEC filings use legal names. Personal checks use preferred names. WinRed uses
  whatever the donor typed once. BOE filings use whatever the committee reported.

**Fix: Weight by source, not just frequency.**

```
Source weights for preferred name inference:
  NCGOP_FINANCIAL contact list:  10x  (these are people who told NCGOP their name)
  Personal check / direct mail:   5x  (self-identified)
  BOE individual filing:          3x  (reported by campaign, often informal)
  FEC individual filing:          2x  (tends toward legal name)
  WinRed / ActBlue recurring:     1x  (auto-filled, often legal)
  DataTrust / voter file:         1x  (government legal name)
```

If the weighted vote still picks the wrong name, the VIP override table
catches it.

### 1.5 Title/Salutation — The GPT Model Undersells This

**GPT proposal:** A `title_map` table turning Senator, Governor, etc. into
salutation templates.

**Reality check from Eddie's non-negotiables:** "Hey You" or the wrong name is
unacceptable. And many donors are also officeholders.

The current golden records have `formal_salutation` on only **49,941 of 253,780**
active records (19.7%). The `roles` array column exists but is sparsely populated.
`prefix` exists but is mostly NULL.

**What's needed:**

1. The `person_spine` must track **current office held** (if any) as a
   first-class field, not buried in a roles array.
2. Salutation generation must be **context-aware**:
   - In a formal fundraising letter: "The Honorable James E. Broyhill II"
   - In a personal email from the candidate: "Ed"
   - In a call script: "Mr. Broyhill" or "Ed" depending on relationship level
3. The salutation cache must be **per-tenant**, because a donor's relationship
   with one candidate (formal) differs from another (personal friend).

### 1.6 Scale Concerns at 60M+ Rows

The GPT model doesn't address Supabase-specific performance constraints:

1. **Statement timeout:** Supabase has a default 2-minute statement timeout on
   direct connections and 10-second on pooled connections. Any identity resolution
   query joining nc_voters (9M) to golden_records (253K) must be chunked or run
   via Hetzner with a direct connection (port 5432, not 6543 pooler).

2. **Connection limits:** Supabase free/pro tiers have connection limits.
   Hetzner batch jobs must use a single persistent connection, not connection-per-query.

3. **Index bloat:** The golden_records table already has **24 indexes**. Every
   INSERT/UPDATE pays the cost of maintaining all 24. During the rebuild, drop
   non-essential indexes, bulk load, then recreate.

4. **VACUUM:** After bulk deletes (soft-deleting ~100K duplicate golden records),
   the table bloat will be severe. Schedule a `VACUUM ANALYZE` after each major
   phase.

5. **The `raw` schema tables should be append-only.** Never UPDATE raw data.
   If a correction is needed, add a new row with a correction flag. This
   preserves auditability and avoids VACUUM thrash on multi-GB tables.

---

## 2. Proposed Schema — Concrete DDL

### 2.1 Schema Creation

```sql
-- Create new schemas (run once, as superuser)
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS norm;
CREATE SCHEMA IF NOT EXISTS core;

-- Grant access to postgres role
GRANT USAGE ON SCHEMA raw TO postgres;
GRANT USAGE ON SCHEMA norm TO postgres;
GRANT USAGE ON SCHEMA core TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA raw TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA norm TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA core TO postgres;

-- Expose core schema via PostgREST (requires Supabase dashboard config change)
-- In Supabase Dashboard → Settings → API → Schema, add "core"
```

### 2.2 Raw Zone Tables

These are immutable landing zones. One per source. Original column names preserved.
Load metadata added.

```sql
-- raw.nc_voters: Move existing public.nc_voters here
-- (or create view: CREATE VIEW raw.nc_voters AS SELECT * FROM public.nc_voters)
-- ~9.1M rows, 71 columns. DO NOT MODIFY.

-- raw.nc_datatrust: Move existing public.nc_datatrust here
-- ~7.6M rows, 251 columns. DO NOT MODIFY.

-- raw.nc_boe_donations: Move existing public.nc_boe_donations_raw here
-- ~684K rows. DO NOT MODIFY.

-- raw.fec_individual: Move existing public.fec_god_contributions here
-- ~275K rows. DO NOT MODIFY.

-- raw.fec_party: Move existing public.fec_party_committee_donations here
-- ~2.2M rows. DO NOT MODIFY.

-- New: load tracking
CREATE TABLE raw.load_log (
    load_id         BIGSERIAL PRIMARY KEY,
    source_system   TEXT NOT NULL,        -- 'nc_voters','nc_datatrust','nc_boe','fec_individual','fec_party'
    file_name       TEXT,
    file_hash       TEXT,                 -- SHA-256 of source file
    rows_loaded     INTEGER,
    rows_rejected   INTEGER DEFAULT 0,
    load_started    TIMESTAMPTZ DEFAULT now(),
    load_completed  TIMESTAMPTZ,
    load_status     TEXT DEFAULT 'running', -- 'running','completed','failed'
    error_message   TEXT,
    loaded_by       TEXT DEFAULT 'hetzner_pipeline'
);
```

### 2.3 Normalized Zone Tables

Cleaned, typed, standardized. One per source. These are the tables that identity
resolution reads from.

```sql
CREATE TABLE norm.nc_boe_donations (
    id                  BIGINT PRIMARY KEY,   -- from raw
    load_id             BIGINT REFERENCES raw.load_log(load_id),
    -- Donor identity (normalized)
    norm_last           TEXT NOT NULL,
    norm_first          TEXT NOT NULL,
    norm_middle         TEXT,
    norm_suffix         TEXT,
    raw_donor_name      TEXT,                 -- original, for audit
    -- Address (normalized)
    norm_street         TEXT,
    norm_city           TEXT,
    norm_state          TEXT DEFAULT 'NC',
    norm_zip5           TEXT,
    raw_street_1        TEXT,
    raw_street_2        TEXT,
    -- Employment
    norm_employer       TEXT,
    norm_occupation     TEXT,
    -- Transaction
    amount              NUMERIC(12,2) NOT NULL,
    transaction_date    DATE,
    transaction_type    TEXT,
    form_of_payment     TEXT,
    purpose             TEXT,
    -- Committee / candidate
    committee_sboe_id   TEXT,
    committee_name      TEXT,
    candidate_referendum_name TEXT,
    report_name         TEXT,
    -- Identity resolution output (filled by pipeline)
    person_id           BIGINT,               -- FK to core.person_spine, NULL until resolved
    -- Metadata
    source_file         TEXT,
    normalized_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_norm_boe_last_first_zip ON norm.nc_boe_donations(norm_last, norm_first, norm_zip5);
CREATE INDEX idx_norm_boe_person_id ON norm.nc_boe_donations(person_id);
CREATE INDEX idx_norm_boe_committee ON norm.nc_boe_donations(committee_sboe_id);

CREATE TABLE norm.fec_individual (
    id                  BIGINT PRIMARY KEY,
    load_id             BIGINT REFERENCES raw.load_log(load_id),
    -- Donor identity
    norm_last           TEXT NOT NULL,
    norm_first          TEXT NOT NULL,
    norm_middle         TEXT,
    norm_suffix         TEXT,
    norm_prefix         TEXT,
    raw_contributor_name TEXT,
    contributor_id      TEXT,                 -- FEC contributor ID if available
    -- Address
    norm_street         TEXT,
    norm_city           TEXT,
    norm_state          TEXT,
    norm_zip5           TEXT,
    -- Employment
    norm_employer       TEXT,
    norm_occupation     TEXT,
    -- Transaction
    amount              NUMERIC(12,2) NOT NULL,
    transaction_date    DATE,
    receipt_type        TEXT,
    receipt_type_desc   TEXT,
    memo_text           TEXT,
    aggregate_ytd       NUMERIC(12,2),
    -- Committee / candidate
    committee_id        TEXT,
    candidate_id        TEXT,                 -- from FEC raw data
    candidate_name      TEXT,
    -- Identity resolution
    person_id           BIGINT,
    -- Metadata
    sub_id              BIGINT,
    file_number         BIGINT,
    fec_cycle           INTEGER,
    normalized_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_norm_fec_ind_last_first_zip ON norm.fec_individual(norm_last, norm_first, norm_zip5);
CREATE INDEX idx_norm_fec_ind_person ON norm.fec_individual(person_id);

CREATE TABLE norm.fec_party (
    id                  BIGINT PRIMARY KEY,
    load_id             BIGINT REFERENCES raw.load_log(load_id),
    -- Donor identity
    norm_last           TEXT NOT NULL,
    norm_first          TEXT NOT NULL,
    norm_middle         TEXT,
    norm_suffix         TEXT,
    raw_contributor_name TEXT,
    -- Address
    norm_city           TEXT,
    norm_state          TEXT,
    norm_zip5           TEXT,
    -- Employment
    norm_employer       TEXT,
    norm_occupation     TEXT,
    -- Transaction
    amount              NUMERIC(12,2) NOT NULL,
    transaction_date    DATE,               -- parsed from MMDDYYYY text
    transaction_type    TEXT,
    entity_type         TEXT,
    memo_text           TEXT,
    -- Committee
    committee_id        TEXT,
    committee_name      TEXT,
    committee_type      TEXT,
    -- Identity resolution
    person_id           BIGINT,
    -- Metadata
    sub_id              TEXT,
    fec_cycle           INTEGER,
    normalized_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_norm_fec_party_last_first_zip ON norm.fec_party(norm_last, norm_first, norm_zip5);
CREATE INDEX idx_norm_fec_party_person ON norm.fec_party(person_id);
```

### 2.4 Core Zone — The Spine

```sql
-- ============================================================
-- core.person_spine — ONE ROW PER REAL HUMAN BEING
-- ============================================================
CREATE TABLE core.person_spine (
    person_id           BIGSERIAL PRIMARY KEY,

    -- === Canonical identity ===
    last_name           TEXT NOT NULL,
    first_name          TEXT NOT NULL,        -- legal first name
    middle_name         TEXT,
    suffix              TEXT,                 -- Jr, Sr, II, III, IV
    prefix              TEXT,                 -- Mr, Mrs, Dr, Hon, etc.

    -- === Preferred name (what they want to be called) ===
    preferred_first     TEXT,                 -- "Ed" not "James"
    preferred_name_source TEXT,               -- 'vip_override','inferred','donor_contact_staging'
    preferred_name_confidence NUMERIC(3,2),   -- 0.00-1.00

    -- === Normalized keys for matching ===
    norm_last           TEXT NOT NULL,        -- UPPER, alpha only
    norm_first          TEXT NOT NULL,        -- UPPER, alpha only
    nickname_canonical  TEXT,                 -- from nick_group: ED→EDWARD, BOB→ROBERT
    match_hash          TEXT,                 -- hash of norm_last+norm_first+zip5 for fast lookup

    -- === Primary address ===
    street              TEXT,
    city                TEXT,
    state               TEXT DEFAULT 'NC',
    zip5                TEXT,
    county              TEXT,
    addr_hash           TEXT,                 -- hash of normalized street+zip5

    -- === Contact ===
    email               TEXT,
    email_source        TEXT,
    email_verified      BOOLEAN DEFAULT false,
    cell_phone          TEXT,
    cell_source         TEXT,
    landline            TEXT,
    landline_source     TEXT,
    business_phone      TEXT,
    business_phone_source TEXT,

    -- === Employment ===
    employer            TEXT,
    occupation          TEXT,

    -- === Voter registration ===
    voter_ncid          TEXT UNIQUE,          -- NC voter ID (strongest identity signal)
    voter_rncid         TEXT,                 -- RNC voter ID
    voter_party         TEXT,                 -- REP, DEM, UNA, LIB, etc.
    voter_status        TEXT,                 -- ACTIVE, INACTIVE, REMOVED
    voter_county        TEXT,
    is_registered_voter BOOLEAN DEFAULT false,

    -- === Political geography ===
    congressional_district  TEXT,
    state_senate_district   TEXT,
    state_house_district    TEXT,
    precinct                TEXT,

    -- === Demographics ===
    birth_year          INTEGER,
    age                 INTEGER,              -- computed from birth_year
    sex                 TEXT,                 -- M, F
    race                TEXT,
    ethnicity           TEXT,

    -- === Scores (from DataTrust / models) ===
    republican_score    NUMERIC(5,2),
    turnout_score       NUMERIC(5,2),
    donor_score         NUMERIC(5,2),         -- custom: propensity to donate

    -- === Giving summary (denormalized for query speed) ===
    total_contributed   NUMERIC(14,2) DEFAULT 0,
    contribution_count  INTEGER DEFAULT 0,
    first_contribution  DATE,
    last_contribution   DATE,
    max_single_gift     NUMERIC(12,2),
    avg_gift            NUMERIC(12,2),
    giving_frequency    TEXT,                 -- 'one_time','occasional','regular','recurring'

    -- === Role flags ===
    is_candidate        BOOLEAN DEFAULT false,
    is_officeholder     BOOLEAN DEFAULT false,
    current_office      TEXT,                 -- 'NC SENATE 26', 'SHERIFF - MECKLENBURG', etc.
    is_delegate         BOOLEAN DEFAULT false,
    is_volunteer        BOOLEAN DEFAULT false,
    is_party_officer    BOOLEAN DEFAULT false,
    is_military         BOOLEAN DEFAULT false,

    -- === Household ===
    household_id        BIGINT,               -- FK to household grouping (future)

    -- === Metadata ===
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),
    merged_from         BIGINT[],             -- array of old golden_record_ids for audit trail
    is_active           BOOLEAN DEFAULT true,
    data_quality_score  NUMERIC(3,2),         -- 0.00-1.00, computed from field completeness
    version             INTEGER DEFAULT 1     -- incremented on each update
);

-- === Indexes (create AFTER bulk load, not before) ===
-- Primary lookup patterns
CREATE UNIQUE INDEX idx_spine_ncid ON core.person_spine(voter_ncid) WHERE voter_ncid IS NOT NULL;
CREATE INDEX idx_spine_last_first_zip ON core.person_spine(norm_last, norm_first, zip5);
CREATE INDEX idx_spine_last_canonical_zip ON core.person_spine(norm_last, nickname_canonical, zip5);
CREATE INDEX idx_spine_email ON core.person_spine(lower(email)) WHERE email IS NOT NULL;
CREATE INDEX idx_spine_cell ON core.person_spine(cell_phone) WHERE cell_phone IS NOT NULL;
CREATE INDEX idx_spine_match_hash ON core.person_spine(match_hash);
CREATE INDEX idx_spine_zip5 ON core.person_spine(zip5);
CREATE INDEX idx_spine_county ON core.person_spine(county);
-- Geography for candidate portal filtering
CREATE INDEX idx_spine_cong ON core.person_spine(congressional_district);
CREATE INDEX idx_spine_senate ON core.person_spine(state_senate_district);
CREATE INDEX idx_spine_house ON core.person_spine(state_house_district);
-- Giving for donor queries
CREATE INDEX idx_spine_total ON core.person_spine(total_contributed DESC NULLS LAST);
CREATE INDEX idx_spine_last_gift ON core.person_spine(last_contribution DESC NULLS LAST);
CREATE INDEX idx_spine_active ON core.person_spine(is_active) WHERE is_active = true;


-- ============================================================
-- core.person_names — ALL known name variations per person
-- ============================================================
CREATE TABLE core.person_names (
    id                  BIGSERIAL PRIMARY KEY,
    person_id           BIGINT NOT NULL REFERENCES core.person_spine(person_id),
    raw_full_name       TEXT,                 -- original as-filed
    first_name          TEXT,
    middle_name         TEXT,
    last_name           TEXT,
    suffix              TEXT,
    prefix              TEXT,
    source_system       TEXT NOT NULL,        -- 'nc_boe','fec_individual','fec_party','nc_voters','nc_datatrust'
    source_id           BIGINT,              -- row ID in the source table
    occurrence_count    INTEGER DEFAULT 1,    -- how many times this exact spelling appears
    first_seen          DATE,
    last_seen           DATE,
    is_legal_name       BOOLEAN DEFAULT false, -- from voter file = legal
    is_preferred        BOOLEAN DEFAULT false, -- inferred or VIP-overridden
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_pnames_person ON core.person_names(person_id);
CREATE INDEX idx_pnames_last_first ON core.person_names(last_name, first_name);


-- ============================================================
-- core.person_addresses — address history per person
-- ============================================================
CREATE TABLE core.person_addresses (
    id                  BIGSERIAL PRIMARY KEY,
    person_id           BIGINT NOT NULL REFERENCES core.person_spine(person_id),
    street              TEXT,
    city                TEXT,
    state               TEXT,
    zip5                TEXT,
    addr_hash           TEXT,
    source_system       TEXT NOT NULL,
    first_seen          DATE,
    last_seen           DATE,
    is_current          BOOLEAN DEFAULT false,
    address_type        TEXT DEFAULT 'home',  -- 'home','business','mailing','po_box'
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_paddrs_person ON core.person_addresses(person_id);
CREATE INDEX idx_paddrs_zip ON core.person_addresses(zip5);


-- ============================================================
-- core.nick_group — nickname → canonical mapping
-- ============================================================
-- Migrate from existing public.name_nickname_map (246 rows)
CREATE TABLE core.nick_group (
    id                  SERIAL PRIMARY KEY,
    nickname            TEXT NOT NULL,        -- ED, EDDIE, EDGAR, TED
    canonical           TEXT NOT NULL,        -- EDWARD
    gender              TEXT,                 -- M, F, NULL
    confidence          NUMERIC(3,2),
    UNIQUE(nickname)
);

CREATE INDEX idx_nick_canonical ON core.nick_group(canonical);


-- ============================================================
-- core.vip_overrides — manual name/title overrides for top donors
-- ============================================================
CREATE TABLE core.vip_overrides (
    id                  SERIAL PRIMARY KEY,
    person_id           BIGINT NOT NULL REFERENCES core.person_spine(person_id),
    override_type       TEXT NOT NULL,        -- 'preferred_name','title','salutation','never_call'
    override_value      TEXT NOT NULL,        -- 'Ed', 'The Honorable', etc.
    context             TEXT,                 -- 'formal','informal','call_script','email'
    notes               TEXT,                 -- "Hates being called James"
    created_by          TEXT DEFAULT 'eddie',
    created_at          TIMESTAMPTZ DEFAULT now(),
    UNIQUE(person_id, override_type, context)
);


-- ============================================================
-- core.preferred_name_cache — inferred preferred first name per person
-- ============================================================
CREATE TABLE core.preferred_name_cache (
    person_id           BIGINT PRIMARY KEY REFERENCES core.person_spine(person_id),
    preferred_first     TEXT NOT NULL,
    nick_group          TEXT,                 -- canonical group used
    winning_raw_spelling TEXT,                -- actual spelling that won
    weighted_score      NUMERIC(8,2),         -- sum of weighted occurrences
    runner_up           TEXT,                 -- second-place name
    runner_up_score     NUMERIC(8,2),
    confidence          NUMERIC(3,2),         -- score_gap / total_score
    computed_at         TIMESTAMPTZ DEFAULT now()
);


-- ============================================================
-- core.salutation_parts — title/prefix lookup
-- ============================================================
CREATE TABLE core.salutation_parts (
    id                  SERIAL PRIMARY KEY,
    title               TEXT NOT NULL,        -- 'Senator','Governor','Representative','Judge',...
    abbreviation        TEXT,                 -- 'Sen.','Gov.','Rep.','Hon.'
    formal_prefix       TEXT NOT NULL,        -- 'The Honorable','Senator','Governor'
    envelope_line       TEXT,                 -- 'The Honorable {first} {last}'
    salutation_formal   TEXT,                 -- 'Dear Senator {last}:'
    salutation_informal TEXT,                 -- 'Dear {preferred_first},'
    gender_specific     BOOLEAN DEFAULT false,
    priority            INTEGER DEFAULT 50,   -- higher = more important title
    UNIQUE(title)
);

-- Seed data
INSERT INTO core.salutation_parts (title, abbreviation, formal_prefix, envelope_line, salutation_formal, salutation_informal, priority) VALUES
('Senator', 'Sen.', 'The Honorable', 'The Honorable {first} {last}', 'Dear Senator {last}:', 'Dear {preferred_first},', 90),
('Governor', 'Gov.', 'The Honorable', 'The Honorable {first} {last}', 'Dear Governor {last}:', 'Dear {preferred_first},', 95),
('Representative', 'Rep.', 'The Honorable', 'The Honorable {first} {last}', 'Dear Representative {last}:', 'Dear {preferred_first},', 85),
('Judge', 'Judge', 'The Honorable', 'The Honorable {first} {last}', 'Dear Judge {last}:', 'Dear {preferred_first},', 80),
('Commissioner', 'Comm.', 'Commissioner', 'Commissioner {first} {last}', 'Dear Commissioner {last}:', 'Dear {preferred_first},', 70),
('Sheriff', 'Sheriff', 'Sheriff', 'Sheriff {first} {last}', 'Dear Sheriff {last}:', 'Dear {preferred_first},', 75),
('Mayor', 'Mayor', 'The Honorable', 'The Honorable {first} {last}, Mayor of {city}', 'Dear Mayor {last}:', 'Dear {preferred_first},', 85),
('Councilman', 'Coun.', 'Councilman', 'Councilman {first} {last}', 'Dear Councilman {last}:', 'Dear {preferred_first},', 60),
('Councilwoman', 'Coun.', 'Councilwoman', 'Councilwoman {first} {last}', 'Dear Councilwoman {last}:', 'Dear {preferred_first},', 60),
('Superintendent', 'Supt.', 'Superintendent', 'Superintendent {first} {last}', 'Dear Superintendent {last}:', 'Dear {preferred_first},', 65),
('Mr', 'Mr.', 'Mr.', 'Mr. {first} {last}', 'Dear Mr. {last}:', 'Dear {preferred_first},', 10),
('Mrs', 'Mrs.', 'Mrs.', 'Mrs. {first} {last}', 'Dear Mrs. {last}:', 'Dear {preferred_first},', 10),
('Ms', 'Ms.', 'Ms.', 'Ms. {first} {last}', 'Dear Ms. {last}:', 'Dear {preferred_first},', 10),
('Dr', 'Dr.', 'Dr.', 'Dr. {first} {last}', 'Dear Dr. {last}:', 'Dear {preferred_first},', 50),
('Rev', 'Rev.', 'The Reverend', 'The Reverend {first} {last}', 'Dear Reverend {last}:', 'Dear {preferred_first},', 50);


-- ============================================================
-- core.candidate_committee_map — links committees to candidates and tenants
-- ============================================================
CREATE TABLE core.candidate_committee_map (
    id                  SERIAL PRIMARY KEY,
    committee_id        TEXT NOT NULL,         -- FEC committee_id or BOE committee_sboe_id
    committee_name      TEXT,
    committee_source    TEXT NOT NULL,         -- 'fec','nc_boe'
    committee_type      TEXT NOT NULL,         -- 'candidate','party','pac','super_pac','ie'
    -- Candidate link (NULL for party/pac committees)
    candidate_id        UUID,                 -- FK to candidate_profiles.candidate_id
    candidate_name      TEXT,
    -- Tenant link (always populated)
    tenant_id           UUID,                 -- which portal/campaign this belongs to
    -- Metadata
    election_cycle      TEXT,                 -- '2024','2026'
    office              TEXT,
    state               TEXT DEFAULT 'NC',
    district            TEXT,
    match_confidence    NUMERIC(3,2),
    created_at          TIMESTAMPTZ DEFAULT now(),
    UNIQUE(committee_id, committee_source)
);

CREATE INDEX idx_ccm_candidate ON core.candidate_committee_map(candidate_id);
CREATE INDEX idx_ccm_tenant ON core.candidate_committee_map(tenant_id);
CREATE INDEX idx_ccm_committee ON core.candidate_committee_map(committee_id);


-- ============================================================
-- core.contribution_map — replaces public.donor_contribution_map
-- ============================================================
CREATE TABLE core.contribution_map (
    id                  BIGSERIAL PRIMARY KEY,
    person_id           BIGINT NOT NULL REFERENCES core.person_spine(person_id),
    source_system       TEXT NOT NULL,         -- 'nc_boe','fec_individual','fec_party'
    source_id           BIGINT NOT NULL,       -- row ID in norm.* table
    amount              NUMERIC(12,2) NOT NULL,
    transaction_date    DATE,
    committee_id        TEXT,
    candidate_id        UUID,                  -- resolved via candidate_committee_map
    tenant_id           UUID,                  -- resolved via candidate_committee_map
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_cmap_person ON core.contribution_map(person_id);
CREATE INDEX idx_cmap_candidate ON core.contribution_map(candidate_id);
CREATE INDEX idx_cmap_tenant ON core.contribution_map(tenant_id);
CREATE INDEX idx_cmap_date ON core.contribution_map(transaction_date);
CREATE INDEX idx_cmap_source ON core.contribution_map(source_system, source_id);


-- ============================================================
-- core.identity_clusters — tracks which records merged into which person
-- ============================================================
CREATE TABLE core.identity_clusters (
    id                  BIGSERIAL PRIMARY KEY,
    person_id           BIGINT NOT NULL REFERENCES core.person_spine(person_id),
    source_system       TEXT NOT NULL,
    source_id           BIGINT NOT NULL,
    cluster_method      TEXT NOT NULL,         -- 'ncid','email','exact_name_zip','nickname_zip','cross_zip_confirmed'
    confidence          NUMERIC(3,2) NOT NULL,
    created_at          TIMESTAMPTZ DEFAULT now(),
    UNIQUE(source_system, source_id)
);

CREATE INDEX idx_icluster_person ON core.identity_clusters(person_id);
```

---

## 3. Stored Procedure Outlines

### 3.1 resolve_identity_batch

```sql
CREATE OR REPLACE FUNCTION core.resolve_identity_batch(
    p_source_system TEXT,         -- 'nc_boe','fec_individual','fec_party'
    p_batch_size INTEGER DEFAULT 10000,
    p_pass INTEGER DEFAULT NULL   -- NULL = run all passes, or 1-6 for specific pass
) RETURNS TABLE(pass_number INTEGER, records_matched BIGINT, records_created BIGINT) AS $$
DECLARE
    v_matched BIGINT;
    v_created BIGINT;
BEGIN
    -- PASS 1: voter_ncid exact match
    -- For donors already matched to voter file, ncid is definitive.
    -- JOIN norm.{source} to core.person_spine ON voter_ncid.
    -- Any match = same person, confidence 0.99.

    -- PASS 2: email exact match
    -- JOIN on lower(email). Confidence 0.95.
    -- Skip generic emails: noreply@, info@, etc.

    -- PASS 3: exact norm_last + norm_first + zip5
    -- The most common match. Confidence 0.95.
    -- Only match active spine records.

    -- PASS 4: norm_last + nickname_canonical + zip5
    -- Use core.nick_group to resolve BILL=WILLIAM, etc.
    -- Confidence 0.90.

    -- PASS 5: norm_last + first_initial + zip5 + employer
    -- Looser name match, but employer confirms identity.
    -- Exclude generic employers: RETIRED, SELF-EMPLOYED, NONE.
    -- Confidence 0.85.

    -- PASS 6: norm_last + norm_first, cross-zip, with secondary signal
    -- Same name at different zips: require shared email OR phone OR employer.
    -- Confidence 0.80.

    -- For each unmatched record after all passes: CREATE new person_spine row.
    -- Log all matches to core.identity_clusters with method and confidence.

    -- TRANSITIVE RESOLUTION: After all passes, chase chains where
    -- person A merged to person B, and person B later merged to person C.
    -- Collapse to single canonical person_id.

    RETURN;
END;
$$ LANGUAGE plpgsql;
```

### 3.2 infer_preferred_names

```sql
CREATE OR REPLACE FUNCTION core.infer_preferred_names(
    p_person_id BIGINT DEFAULT NULL  -- NULL = all, or specific person
) RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    -- For each person (or specific person_id):
    --
    -- 1. Gather all name variants from core.person_names.
    -- 2. Map each first_name to its nick_group canonical via core.nick_group.
    -- 3. Weight each occurrence:
    --      source_system weights:
    --        'ncgop_financial' → 10
    --        'donor_contact_staging' → 5
    --        'nc_boe' → 3
    --        'fec_individual' → 2
    --        'fec_party' → 1
    --        'nc_voters' → 1
    --        'nc_datatrust' → 1
    -- 4. Sum weighted scores per nick_group.
    -- 5. Winning group = highest weighted score.
    -- 6. Within winning group, most frequent raw spelling = preferred_first.
    -- 7. Check core.vip_overrides — if VIP override exists, it wins unconditionally.
    -- 8. Upsert into core.preferred_name_cache.
    -- 9. Update core.person_spine.preferred_first and preferred_name_source.

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;
```

### 3.3 rebuild_salutation_cache

```sql
CREATE OR REPLACE FUNCTION core.rebuild_salutation_cache(
    p_person_id BIGINT DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    -- For each person:
    --
    -- 1. Determine title:
    --    a. Check core.vip_overrides for override_type='title'.
    --    b. Check person_spine.current_office → look up in salutation_parts.
    --    c. Check person_spine.prefix → look up in salutation_parts.
    --    d. Default: 'Mr' or 'Ms' based on sex field.
    --
    -- 2. Determine preferred first name:
    --    a. Check core.vip_overrides for override_type='preferred_name'.
    --    b. Check core.preferred_name_cache.
    --    c. Fall back to person_spine.first_name.
    --
    -- 3. Generate salutation strings:
    --    formal_salutation = template from salutation_parts with {last} substituted
    --    informal_greeting = 'Dear {preferred_first},'
    --    envelope_line = template from salutation_parts with {first} {last}
    --    full_formal_name = '{prefix} {first} {middle_initial}. {last} {suffix}'
    --
    -- 4. Update person_spine.prefix, person_spine.preferred_first.

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;
```

---

## 4. Validation Queries

### 4.1 Identity Quality — Broyhill Family Test

```sql
-- ACCEPTANCE TEST 1: Ed Broyhill must be exactly ONE active spine record.
-- His preferred_first must be 'Ed', not 'James' or 'Edgar'.
-- His total_contributed must be >= $1.8M (sum of all current fragments).
SELECT person_id, last_name, first_name, preferred_first,
       total_contributed, contribution_count, email, zip5, voter_ncid
FROM core.person_spine
WHERE norm_last = 'BROYHILL' AND norm_first IN ('ED','EDGAR','EDWARD','JAMES','JEDGAR')
AND is_active = true;
-- EXPECTED: 1 row. preferred_first='Ed'. total_contributed > 1800000.

-- ACCEPTANCE TEST 2: All Broyhill family members should be separate people.
SELECT person_id, last_name, preferred_first, first_name, zip5,
       total_contributed, contribution_count
FROM core.person_spine
WHERE norm_last = 'BROYHILL' AND is_active = true
ORDER BY total_contributed DESC NULLS LAST;
-- EXPECTED: ~8-10 distinct Broyhills (Ed, James Sr, Hunt, Karen, Peg, Louise, etc.)
-- Not 25+, not 2.

-- ACCEPTANCE TEST 3: No Broyhill name variants lost.
SELECT person_id, raw_full_name, source_system, occurrence_count
FROM core.person_names
WHERE last_name = 'BROYHILL'
ORDER BY person_id, source_system;
-- Every raw name spelling must be preserved and linked to the correct person_id.
```

### 4.2 Identity Quality — Art Pope Test

```sql
-- Art Pope's legal name is JAMES ARTHUR POPE.
-- He must be ONE person, not scattered across JAMES POPE and ART POPE records.
-- His records at zip 27609 (Raleigh) must all resolve together.
-- Records for OTHER James Popes (different zips, different emails) must remain separate.
SELECT person_id, last_name, preferred_first, first_name, zip5, email,
       total_contributed, contribution_count
FROM core.person_spine
WHERE norm_last = 'POPE' AND (norm_first IN ('ART','JAMES','ARTHUR') OR nickname_canonical = 'JAMES')
AND is_active = true
ORDER BY total_contributed DESC NULLS LAST;
-- EXPECTED: Art Pope = 1 row, total > $2.9M, preferred_first='Art'.
-- Other James Popes at different zips = separate rows.
```

### 4.3 Referential Integrity After Reload

```sql
-- Every contribution must point to an active person.
SELECT count(*) as orphaned_contributions
FROM core.contribution_map cm
LEFT JOIN core.person_spine ps ON ps.person_id = cm.person_id AND ps.is_active = true
WHERE ps.person_id IS NULL;
-- MUST BE 0.

-- Every norm record must have a person_id after resolution.
SELECT source_system, count(*) as unresolved
FROM (
    SELECT 'nc_boe' as source_system, id FROM norm.nc_boe_donations WHERE person_id IS NULL
    UNION ALL
    SELECT 'fec_individual', id FROM norm.fec_individual WHERE person_id IS NULL
    UNION ALL
    SELECT 'fec_party', id FROM norm.fec_party WHERE person_id IS NULL
) unmatched
GROUP BY source_system;
-- EXPECTED: 0 for all sources. Every donation must resolve to a person.

-- Dollar totals must match between raw and core.
SELECT
    (SELECT sum(amount) FROM norm.nc_boe_donations) as boe_norm,
    (SELECT sum(amount) FROM core.contribution_map WHERE source_system = 'nc_boe') as boe_core,
    (SELECT sum(amount) FROM norm.fec_individual) as fec_ind_norm,
    (SELECT sum(amount) FROM core.contribution_map WHERE source_system = 'fec_individual') as fec_ind_core;
-- Each pair MUST match exactly. If they don't, contributions were lost or duplicated.
```

### 4.4 Coverage Regression Test

```sql
-- Run BEFORE and AFTER voter/DataTrust append. Store the "before" snapshot.
-- Coverage must only go UP, never down.
WITH coverage AS (
    SELECT
        count(*) as total,
        count(email) as email,
        count(cell_phone) as cell,
        count(landline) as landline,
        count(voter_party) as party,
        count(voter_ncid) as ncid,
        count(republican_score) as rep_score,
        count(CASE WHEN preferred_first IS NOT NULL THEN 1 END) as preferred_name
    FROM core.person_spine
    WHERE is_active = true
)
SELECT
    total,
    email, round(100.0*email/total, 1) as email_pct,
    cell, round(100.0*cell/total, 1) as cell_pct,
    party, round(100.0*party/total, 1) as party_pct,
    ncid, round(100.0*ncid/total, 1) as ncid_pct,
    rep_score, round(100.0*rep_score/total, 1) as rep_pct,
    preferred_name, round(100.0*preferred_name/total, 1) as pref_pct
FROM coverage;
-- Compare to previous run. ALL percentages must be >= previous values.
-- If any dropped, the append introduced a regression.
```

### 4.5 Candidate Committee Coverage

```sql
-- What percentage of contributions can be attributed to a specific candidate?
SELECT
    source_system,
    count(*) as total,
    count(candidate_id) as has_candidate,
    round(100.0 * count(candidate_id) / count(*), 1) as candidate_pct,
    count(tenant_id) as has_tenant,
    round(100.0 * count(tenant_id) / count(*), 1) as tenant_pct
FROM core.contribution_map
GROUP BY source_system;
-- TARGET: nc_boe > 80% candidate attribution.
-- fec_individual > 90% (these have candidate_id in raw data).
-- fec_party: will be low — party/PAC donations don't map to one candidate.
```

---

## 5. Migration Sequence

**Do NOT attempt all of this in one session.**

| Phase | What | Where | Duration Est. | Rollback |
|-------|------|-------|---------------|----------|
| 0 | Create schemas, grant permissions | Supabase SQL | 5 min | DROP SCHEMA |
| 1 | Create raw.load_log | Supabase SQL | 1 min | DROP TABLE |
| 2 | Create norm.* tables (empty) | Supabase SQL | 5 min | DROP TABLE |
| 3 | Create core.* tables (empty) | Supabase SQL | 10 min | DROP TABLE |
| 4 | Seed core.nick_group from existing name_nickname_map | Supabase SQL | 1 min | TRUNCATE |
| 5 | Seed core.salutation_parts | Supabase SQL | 1 min | TRUNCATE |
| 6 | Populate norm.nc_boe_donations from raw BOE data | **Hetzner** | 30 min | TRUNCATE norm table |
| 7 | Populate norm.fec_individual from raw FEC data | **Hetzner** | 15 min | TRUNCATE |
| 8 | Populate norm.fec_party from raw FEC party data | **Hetzner** | 2-3 hrs | TRUNCATE |
| 9 | Run identity resolution passes 1-6 | **Hetzner** | 2-4 hrs | Soft-delete, re-run |
| 10 | Populate core.person_spine from resolved identities | **Hetzner** | 1 hr | TRUNCATE + re-run |
| 11 | Populate core.contribution_map | **Hetzner** | 1-2 hrs | TRUNCATE + re-run |
| 12 | Build candidate_committee_map | Supabase SQL | 30 min | TRUNCATE |
| 13 | Run preferred name inference | Supabase SQL | 30 min | Re-run |
| 14 | Append voter/DataTrust enrichment | **Hetzner** | 1-2 hrs | Re-run |
| 15 | Run validation queries (Section 4) | Supabase SQL | 15 min | — |
| 16 | Create compatibility views in public schema | Supabase SQL | 15 min | DROP VIEW |
| 17 | Update PostgREST config to expose core schema | Supabase Dashboard | 5 min | Revert config |

**Total estimated: 8-12 hours of compute time, spread across 2-3 sessions.**

Phases 6-11 and 14 MUST run on Hetzner (direct connection, no statement timeout,
no connection pool limits). Everything else can run via Supabase SQL editor.

---

## 6. Open Questions for Eddie

1. **VIP list scope:** You said 500-1,000 people for VIP overrides. Do you have
   this list, or should the system auto-identify the top 1,000 donors by total
   giving and flag them for manual review?

2. **Tenant model:** Are tenants = individual candidates, or are some tenants
   party organizations (county GOP, NCGOP)? This affects how party committee
   donations get attributed.

3. **Historical offices:** Should the salutation system track past offices?
   (e.g., "Former Governor Pat McCrory" — still uses "Governor" in salutation.)

4. **DataTrust email:** DataTrust has NO email column in the current load. Is
   there a separate DataTrust email file, or is email only coming from
   donor_contacts_staging (41,878 rows) and FEC filings?

5. **The old golden_records:** After the new core.person_spine is validated,
   should the 667-table `public` schema be archived or dropped?

---

*End of RFC-001.*
