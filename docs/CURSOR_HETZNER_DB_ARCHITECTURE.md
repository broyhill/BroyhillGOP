# BroyhillGOP Hetzner Platform — Database Architecture Reference

> **For Cursor AI**: This document is the authoritative schema reference for the BroyhillGOP Hetzner PostgreSQL database. Read this before writing any query, migration, or pipeline code. Pay close attention to the CRITICAL RULES section.

---

## Table of Contents

1. [Infrastructure](#infrastructure)
2. [Database Connection](#database-connection)
3. [Extensions](#extensions)
4. [Schema Inventory](#schema-inventory)
5. [Existing Tables (DO NOT ALTER)](#existing-tables-do-not-alter)
6. [New Data Layer Tables](#new-data-layer-tables)
7. [Brain / Event Bus Layer](#brain--event-bus-layer)
8. [Candidate Data Flow Layer](#candidate-data-flow-layer)
9. [Audit Layer](#audit-layer)
10. [Search / Profile Layer](#search--profile-layer)
11. [Key Relationships](#key-relationships)
12. [Critical Rules for Cursor](#critical-rules-for-cursor)
13. [Operational Procedures](#operational-procedures)
14. [GitHub / Migration Context](#github--migration-context)

---

## Infrastructure

| Property | Value |
|---|---|
| Server | Hetzner AX162 — IP `37.27.169.232` |
| CPUs | 96 × AMD EPYC |
| RAM | 251 GB |
| Storage | 2 × 1.7 TB NVMe — RAID 1 |
| OS | Ubuntu 24.04 LTS |
| PostgreSQL | 16 |
| PG tuning | Pending deployment — moving from stock `128MB` `shared_buffers` → `64GB` |

---

## Database Connection

```
postgresql://postgres:Anamaria%402026%40@localhost:5432/postgres
```

When connecting via CLI always use `-h 127.0.0.1` (not `localhost`) to force TCP:

```bash
psql -h 127.0.0.1 -U postgres -d postgres
```

---

## Extensions

| Extension | Purpose |
|---|---|
| `uuid-ossp` | UUID generation (`uuid_generate_v4()`) |
| `pgcrypto` | SHA-256 hashing, `gen_random_uuid()` |
| `pg_trgm` | Trigram similarity for fuzzy name search |
| `btree_gin` | Composite GIN indexes |

---

## Schema Inventory

The database contains **10 schemas**:

| Schema | Purpose |
|---|---|
| `raw` | Raw ingested source data — NCBOE, FEC |
| `core` | DataTrust voter file, Acxiom files, candidate registry, campaign lifecycle |
| `donor_intelligence` | Golden records, junction maps, materialized views |
| `pipeline` | ETL idempotency and job tracking; data source registry; real-time data ingest |
| `brain` | Autonomous decision engine — event bus, triggers, budgets; per-candidate trigger assignments and KPI metrics |
| `audit` | Immutable activity log (partitioned) |
| `staging` | Temporary landing zone for in-flight loads |
| `norm` | Normalization helpers and lookup data |
| `archive` | Retired / historical data |
| `volunteer` | Volunteer program data |

**Table count:** 27 logical base tables (3 are partitioned parents), 2 materialized views, 272 indexes. Partition children for `brain.event_queue`, `audit.activity_log`, and `pipeline.inbound_data_queue` add 12 additional rows in `pg_stat_user_tables`.

---

## Existing Tables (DO NOT ALTER)

These 7 tables are **finalized**. Never add, drop, or rename columns. Never modify indexes or constraints. Never re-run deduplication logic against them.

---

### `raw.ncboe_donations`

NC Board of Elections donation records.

| Property | Value |
|---|---|
| Rows | 2,431,198 |
| Columns | 59 |
| Unique clusters | 758,110 |
| RNC RegID coverage | 53.2% |

**Key columns:**

| Column | Type | Notes |
|---|---|---|
| `id` | BIGINT | PK — referenced by `contribution_map.source_row_id` |
| `cluster_id` | BIGINT | Deduplication cluster ID |
| `cluster_profile` | JSONB | Rich per-cluster aggregate profile |
| `rnc_regid` | TEXT | Voter file match key |
| `dt_match_method` | TEXT | Method used to match to DataTrust |

**Match method distribution:**

| Method | Count |
|---|---|
| `exact_unique` | 867,479 |
| `cluster_propagation` | 193,868 |
| `exact_multi_best` | 84,672 |
| `prefix_match` | 50,900 |
| `middle_name_match` | 45,490 |
| `exact_middle_confirm` | 31,639 |
| `initial_match` | 18,787 |
| `exact_middle_confirm_propagated` | 234 |

**Canary record — Ed Broyhill:**

| Field | Value |
|---|---|
| `cluster_id` | `372171` |
| `rnc_regid` | `c45eeea9-663f-40e1-b0e7-a473baee794e` |
| Rows in cluster | 627 |
| Cluster total | $1,318,672.04 |

> See [Critical Rule #1](#critical-rules-for-cursor): the name parser must map `ED` → `EDGAR` for Ed Broyhill.

---

### `core.datatrust_voter_nc`

DataTrust NC voter file.

| Property | Value |
|---|---|
| Rows | 7,720,136 |

**Key columns:**

| Column | Notes |
|---|---|
| `rnc_regid` | Join key to `person_master` and `ncboe_donations` |
| `registered_party` | Official registration |
| `voter_status` | Active / Inactive / Removed |
| `sex` | M / F / U |
| `birth_year` | Integer |
| `ethnicity_reported` | Self-reported ethnicity |
| `ethnic_group_modeled` | Acxiom/DataTrust modeled ethnicity |
| `calc_party` | Calculated effective party |
| `modeled_party` | Modeled party affiliation |

---

### `core.acxiom_ap_models`

Acxiom predictive model scores.

| Property | Value |
|---|---|
| Rows | 7,620,491 |

Join via `rnc_regid`. Contains modeled propensity scores used as **last resort** (see [Critical Rule #3](#critical-rules-for-cursor)).

---

### `core.acxiom_ibe`

Acxiom InfoBase Enhancement consumer data.

| Property | Value |
|---|---|
| Target rows | 7,620,491 |
| Status | Currently loading |

---

### `core.acxiom_consumer_nc`

Acxiom consumer demographics.

| Property | Value |
|---|---|
| Rows | 7,655,341 |

---

### `core.acxiom_market_indices`

Market-level indices.

| Property | Value |
|---|---|
| Rows | 0 (populates after `acxiom_ibe` load completes) |

---

### `donor_intelligence.employer_sic_master`

SIC code lookup table for employer classification.

| Property | Value |
|---|---|
| Rows | 0 (pending load) |

---

## New Data Layer Tables

These 5 tables are the core of the new data pipeline and must be used in all new code.

---

### `raw.fec_donations`

Federal Election Commission individual contribution records. Mirrors FEC bulk file structure.

**Key columns:**

| Column | Notes |
|---|---|
| `id` | BIGINT PK — referenced by `contribution_map.source_row_id` |
| `cmte_id` | FEC committee ID |
| `name` | Raw contributor name (full, as submitted) |
| `city`, `state`, `zip_code` | Contributor address |
| `employer`, `occupation` | As submitted |
| `contributor_last`, `contributor_first`, `contributor_middle` | Parsed name fields |
| `transaction_dt` | Donation date |
| `transaction_amt` | Donation amount |
| `cand_id`, `cand_name`, `cand_office` | Candidate info |
| `norm_*` | Normalized variants of address/name fields |
| `cluster_id` | FEC-side dedup cluster |
| `rnc_regid` | Matched voter file key |
| `match_method`, `match_confidence` | Matching metadata |
| `election_cycle` | 4-digit cycle year |
| `is_memo` | BOOLEAN — see [Critical Rule #5](#critical-rules-for-cursor) |

Indexes: 12 total.

> **CRITICAL**: Exclude `is_memo = TRUE` rows from all financial totals and contribution counts.

---

### `donor_intelligence.person_master`

**The golden record table. One row per human being.**

Primary key: `person_id UUID` (generated via `uuid_generate_v4()`).

Has an `updated_at` trigger that auto-updates on every row change.

**Name fields:**

| Column | Notes |
|---|---|
| `prefix` | Mr., Mrs., Dr., etc. |
| `first_name` | Given name |
| `middle_name` | Middle name or initial |
| `last_name` | Surname |
| `suffix` | Jr., Sr., III, etc. |
| `preferred_name` | Informal name (e.g., "Ed" for Edgar) |
| `formal_salutation` | Full formal salutation string |

**Address fields:** standard mailing address columns.

**Contact:**

| Column | Notes |
|---|---|
| `cell_phone` | Mobile phone |
| `email` | Email address |

**Professional:**

| Column | Notes |
|---|---|
| `employer` | Employer name |
| `occupation` | Occupation |
| `employer_sic_code` | FK to `employer_sic_master` |

**Role flags (partial indexes on each):**

| Column | Meaning |
|---|---|
| `is_donor` | Has any donation record |
| `is_candidate` | Has run for office |
| `is_volunteer` | Active volunteer |
| `is_delegate` | Party delegate |
| `is_elected_official` | Holds or held office |
| `is_party_official` | Party leadership role |
| `is_fec_donor` | Has FEC contribution record |
| `is_ncboe_donor` | Has NCBOE donation record |

**Voter linkage:**

| Column | Notes |
|---|---|
| `rnc_regid` | FK to `core.datatrust_voter_nc.rnc_regid` (LEFT JOIN) |
| `state_voter_id` | State voter registration ID |
| `voter_status` | Cached from DataTrust |
| `registered_party` | Cached from DataTrust |
| `birth_year` | Cached from DataTrust |
| `sex` | Cached from DataTrust |

**Household:**

| Column | Notes |
|---|---|
| `household_id` | Groups persons sharing a household |
| `household_position` | Primary / Secondary / etc. |

**Deduplication:**

| Column | Notes |
|---|---|
| `match_key` | Canonical dedup key |
| `name_variants[]` | Array of known name variants |
| `ncboe_cluster_id` | Link to `raw.ncboe_donations.cluster_id` |
| `fec_cluster_id` | Link to `raw.fec_donations.cluster_id` |

**Cached donation aggregates (denormalized for performance):**

| Column | Notes |
|---|---|
| `donations_total` | Lifetime total across all sources |
| `donations_ncboe` | NCBOE total |
| `donations_fec` | FEC total |
| `donation_count` | Total number of itemized contributions |
| `first_donation_date` | Earliest known donation date |
| `last_donation_date` | Most recent donation date |
| `donation_years[]` | Array of years with any activity |
| `household_total` | Combined household donation total |

**Scoring:**

| Column | Notes |
|---|---|
| `donor_grade` | Letter grade (A–F or similar) |
| `total_score` | Composite numeric score |

**Other:**

| Column | Notes |
|---|---|
| `custom_tags` | JSONB — arbitrary key/value tags |
| `source_systems[]` | Array of systems this record was sourced from |

Indexes: 17 total, including partial indexes on all role flag columns and full-text + trigram GIN indexes (see [Search / Profile Layer](#search--profile-layer)).

---

### `donor_intelligence.contribution_map`

**Junction table linking every donation row to exactly one `person_master` record.**

Every row in `raw.ncboe_donations` and `raw.fec_donations` that has been matched must have a corresponding row here. Unique constraint on `(source_system, source_row_id)` prevents duplicate linkage.

| Column | Type | Notes |
|---|---|---|
| `person_id` | UUID | FK → `person_master.person_id` |
| `source_system` | TEXT | `'ncboe'` or `'fec'` |
| `source_row_id` | BIGINT | `id` from the source table |
| `amount` | NUMERIC | Cached donation amount |
| `donation_date` | DATE | Cached donation date |
| `committee_id` | TEXT | Cached committee ID |
| `committee_name` | TEXT | Cached committee name |
| `candidate_name` | TEXT | Cached candidate name |
| `match_method` | TEXT | Method used to link this row |
| `match_confidence` | NUMERIC | Confidence score 0–1 |

---

### `donor_intelligence.committee_candidate_map`

Maps FEC/NCBOE committee IDs to their associated candidate `person_master` records.

| Column | Type | Notes |
|---|---|---|
| `committee_id` | TEXT | FEC or NCBOE committee ID |
| `committee_name` | TEXT | |
| `committee_type` | TEXT | |
| `committee_source` | TEXT | `'fec'` or `'ncboe'` |
| `candidate_person_id` | UUID | FK → `person_master.person_id` |
| `candidate_name` | TEXT | |
| `fec_candidate_id` | TEXT | FEC cand_id if applicable |
| `office_type` | TEXT | Federal / State / Local |
| `office_state` | TEXT | |
| `office_district` | TEXT | |
| `party` | TEXT | |
| `election_year` | INT | |

Unique index on `(committee_id, committee_source, COALESCE(election_year, 0))`.

---

### `pipeline.loaded_files`

**Idempotency guard.** Every file ingestion must check this table before processing.

| Column | Type | Notes |
|---|---|---|
| `file_name` | TEXT | Original filename |
| `file_hash` | TEXT | SHA-256 hex digest |
| `file_source` | TEXT | `'ncboe_gold'`, `'fec_individual'`, `'fec_committee'`, `'fec_candidate'`, `'datatrust'`, or `'acxiom'` |
| `row_count` | BIGINT | Raw rows in file |
| `net_row_count` | BIGINT | Rows inserted after dedup/filter |
| `status` | TEXT | `'complete'`, `'in_progress'`, `'failed'` |
| `loaded_by` | TEXT | Process / script identifier |

Unique constraint on `(file_hash, file_source)`.

**Idempotency pattern (required for all pipeline code):**

```sql
-- Before processing any file:
SELECT 1
FROM pipeline.loaded_files
WHERE file_hash = $1          -- SHA-256 of file bytes
  AND file_source = $2        -- e.g. 'fec_individual'
  AND status = 'complete';
-- If a row is returned, SKIP the file entirely.
```

---

## Brain / Event Bus Layer

Six tables forming the autonomous decision engine. The `brain` schema is universe-aware (see [Critical Rule #9](#critical-rules-for-cursor)).

---

### `brain.event_queue`

**Central event bus for all ecosystems. Partitioned by month.**

Partitioned `BY RANGE (created_at)`. Current partitions: `2026-04`, `2026-05`, `2026-06`, `2026-07`.

> New partitions must be created before month-end. Add `2026-08` before July 31.

| Column | Type | Notes |
|---|---|---|
| `event_id` | UUID | PK |
| `event_type` | TEXT | Type of event |
| `source_universe` | TEXT | Universe identifier (supports 60→5-7 consolidation) |
| `source_ecosystem` | TEXT | Ecosystem within universe |
| `entity_type` | TEXT | Type of entity this event is about |
| `entity_id` | TEXT | ID of the entity |
| `event_data` | JSONB | Arbitrary event payload |
| `priority` | INT | 1 (low) – 100 (high) |
| `status` | TEXT | `'pending'`, `'processing'`, `'completed'`, `'failed'`, `'expired'` |
| `attempts` | INT | Processing attempt count |
| `max_attempts` | INT | Maximum retries |
| `scheduled_for` | TIMESTAMPTZ | When to process |
| `processed_at` | TIMESTAMPTZ | When processing completed |

**Key index:** `idx_eq_pending ON brain.event_queue (scheduled_for, priority DESC) WHERE status = 'pending'`

Use this index by including `WHERE status = 'pending' AND scheduled_for <= NOW()` in all queue consumer queries, ordered by `priority DESC, scheduled_for ASC`.

---

### `brain.decisions`

GO/NO-GO decision records.

| Column | Notes |
|---|---|
| `decision_id` | UUID PK |
| `trigger_name` | Name of the brain trigger that fired |
| `event_id` | UUID FK to `event_queue` |
| `candidate_id` | UUID FK to `person_master` (the candidate) |
| `event_type` | Event type that prompted the decision |
| `decision` | `'go'`, `'no_go'`, `'review'`, or `'defer'` |
| `score` | Numeric decision score |
| `score_breakdown` | JSONB — per-factor scoring detail |
| `channels_selected[]` | Array of channels selected for execution |
| `targets_count` | Number of contact targets |
| `budget_allocated` | Dollar amount allocated |
| `execution_plan` | JSONB — full execution plan |
| `executed` | BOOLEAN |
| `result_metrics` | JSONB — post-execution outcomes |

---

### `brain.triggers`

Declarative trigger definitions. 905+ rows.

| Column | Notes |
|---|---|
| `trigger_id` | UUID PK |
| `name` | UNIQUE trigger name |
| `category` | Trigger category |
| `description` | Human-readable description |
| `universe` | Universe this trigger belongs to |
| `conditions` | JSONB — evaluation conditions |
| `actions` | JSONB — actions to execute on match |
| `priority` | INT — evaluation order |
| `is_active` | BOOLEAN |
| `cooldown_minutes` | INT — minimum minutes between fires |
| `fire_count` | INT — lifetime fire count |

---

### `brain.contact_fatigue`

Per-person, per-channel contact frequency tracking.

| Column | Notes |
|---|---|
| `contact_id` | UUID — person being contacted |
| `channel` | TEXT — communication channel (email, sms, mail, etc.) |
| `contacts_today` | INT |
| `contacts_this_week` | INT |
| `contacts_this_month` | INT |
| `fatigue_score` | NUMERIC — computed fatigue level |

Primary key: `(contact_id, channel)`.

---

### `brain.budgets`

Per-candidate, per-channel budget tracking.

| Column | Notes |
|---|---|
| `candidate_id` | UUID — candidate |
| `channel` | TEXT — communication channel |
| `daily_budget` | NUMERIC |
| `daily_spent` | NUMERIC |
| `weekly_budget` | NUMERIC |
| `weekly_spent` | NUMERIC |
| `monthly_budget` | NUMERIC |
| `monthly_spent` | NUMERIC |

---

### `brain.learning`

ML/RL feedback signal store. Stores aggregated performance metrics per segment.

| Column | Notes |
|---|---|
| `trigger_category` | TEXT — segment dimension |
| `channel` | TEXT — segment dimension |
| `donor_segment` | TEXT — segment dimension |
| `content_type` | TEXT — segment dimension |
| `sends` | BIGINT |
| `opens` | BIGINT |
| `clicks` | BIGINT |
| `conversions` | BIGINT |
| `revenue` | NUMERIC |
| `avg_roi` | NUMERIC |
| `confidence_score` | NUMERIC 0–1 |

---

## Candidate Data Flow Layer

Eight tables deployed in migration `HETZNER_CANDIDATE_DATA_FLOW.sql` (2026-04-13). Organized in four layers: candidate registry, data source registry, real-time data ingest, and per-candidate brain integration.

---

### Layer A — Candidate Registry (`core` schema)

---

#### `core.candidates`

**Central candidate registry. One row per candidate.**

Links to `donor_intelligence.person_master` via `person_id` (UNIQUE — a candidate IS a person). Contains the E03 273-field profile compressed into structured columns plus extensible JSONB sections. Has an `updated_at` trigger.

**Identity:**

| Column | Type | Notes |
|---|---|---|
| `candidate_id` | UUID | PK (`gen_random_uuid()`) |
| `person_id` | UUID | FK → `person_master.person_id`, UNIQUE, NOT NULL |
| `first_name` | TEXT | NOT NULL |
| `middle_name` | TEXT | |
| `last_name` | TEXT | NOT NULL |
| `suffix` | TEXT | |
| `preferred_name` | TEXT | e.g. "Ed" for Edgar |
| `legal_name` | TEXT | Full legal name |
| `formal_salutation` | TEXT | e.g. "Dear Senator Smith" |

**Office / Election:**

| Column | Type | Notes |
|---|---|---|
| `office_type` | TEXT | President / Senate / House / Governor / State Senate / State House / County Commissioner / Council / Mayor / etc. |
| `office_level` | TEXT | `'federal'`, `'state'`, `'local'` |
| `office_title` | TEXT | e.g. "NC House District 74" |
| `office_state` | TEXT | NOT NULL, DEFAULT `'NC'` |
| `office_district` | TEXT | |
| `county` | TEXT | |
| `is_incumbent` | BOOLEAN | NOT NULL, DEFAULT FALSE |
| `incumbent_since` | DATE | |
| `election_year` | INTEGER | |
| `primary_election_date` | DATE | |
| `general_election_date` | DATE | |
| `filing_date` | DATE | |
| `ballot_name` | TEXT | |
| `race_rating` | TEXT | `safe_r` / `likely_r` / `lean_r` / `toss_up` / `lean_d` / `likely_d` / `safe_d` |

**Party / Ideology:**

| Column | Type | Notes |
|---|---|---|
| `party` | TEXT | NOT NULL, DEFAULT `'REP'` |
| `faction` | TEXT | e.g. "Freedom Caucus", "Establishment", "MAGA" |
| `ideology_score` | INTEGER | 0–100 conservative scale |

**Status & Subscription:**

| Column | Type | Notes |
|---|---|---|
| `status` | TEXT | NOT NULL, CHECK: `prospect` / `recruited` / `onboarding` / `active` / `suspended` / `withdrawn` / `lost` / `won` / `termed` |
| `subscription_tier` | TEXT | NOT NULL, CHECK: `basic` / `standard` / `premium` / `enterprise` |
| `onboarding_stage` | TEXT | From E03 pipeline stages |

**Filing IDs:**

| Column | Type | Notes |
|---|---|---|
| `fec_candidate_id` | TEXT | P/H/S + digits |
| `fec_committee_id` | TEXT | C00... (principal campaign committee) |
| `state_committee_id` | TEXT | NCBOE committee ID |

**Campaign Staff:**

| Column | Notes |
|---|---|
| `campaign_manager` | Name |
| `campaign_manager_email` | Email |
| `campaign_manager_phone` | Phone |
| `finance_director` | Name |
| `communications_director` | Name |
| `field_director` | Name |
| `digital_director` | Name |
| `treasurer` | Name |

**Online Presence:**

| Column | Type | Notes |
|---|---|---|
| `campaign_website` | TEXT | |
| `donation_url` | TEXT | |
| `volunteer_url` | TEXT | |
| `social_media` | JSONB | `{ "facebook": {"url":"...", "handle":"..."}, "twitter": {...}, "instagram": {...}, "youtube": {...}, "tiktok": {...}, "linkedin": {...}, "truth_social": {...}, "rumble": {...} }` |

**Branding:**

| Column | Notes |
|---|---|
| `brand_primary_color` | Hex color |
| `brand_secondary_color` | Hex color |
| `brand_font` | Font name |
| `headshot_url` | Candidate photo |
| `logo_url` | Campaign logo |
| `banner_url` | Campaign banner |

**JSONB Sections:**

| Column | Structure |
|---|---|
| `ai_context` | `{ "voice_description", "messaging_tone", "topics_avoid", "key_phrases", "attack_lines", "defense_points", "accomplishments", "call_to_action", "donation_ask", "volunteer_ask", "vote_ask" }` |
| `district_demographics` | `{ "population", "registered_voters", "republican_pct", "democrat_pct", "median_income", "median_age", "urban_pct", "suburban_pct", "rural_pct", "trump_2020_pct", "pvi", "top_issues" }` |
| `biography` | `{ "bio_short", "bio_full", "tagline", "birth_city", "hometown", "years_in_district", "marital_status", "spouse_name", "children_count", "education", "career_history", "military", "religion", "community_involvement" }` |
| `issue_positions` | `{ "gun_rights": {"position":"strong_support","priority":1,"talking_points":[...]}, "immigration": {...}, ... }` (60 issues) |
| `priority_issues` | JSON array of top issue names |
| `attribute_scores` | `{ "professional_experience": 42, "legislative_knowledge": 68, "media_presence": 55, ... }` |
| `endorsements` | `{ "trump_endorsed": true, "trump_endorsed_date": "...", "nra_grade": "A+", "nra_endorsed": true, "right_to_life": true, "other": [...] }` |
| `custom_fields` | Arbitrary key/value JSONB |
| `custom_tags` | JSON array of tags |

**Finance (cached from FEC/NCBOE, refreshed by pipeline):**

| Column | Type | Notes |
|---|---|---|
| `raised_total` | NUMERIC(14,2) | |
| `raised_this_cycle` | NUMERIC(14,2) | |
| `cash_on_hand` | NUMERIC(14,2) | |
| `debt_total` | NUMERIC(14,2) | |
| `donor_count` | INTEGER | |
| `avg_donation` | NUMERIC(10,2) | |
| `small_dollar_pct` | NUMERIC(5,2) | |

**Scoring (1000-point E03 system):**

| Column | Type | Notes |
|---|---|---|
| `attribute_score_total` | INTEGER | NOT NULL, DEFAULT 0 — composite E03 score (max 1000) |
| `signature_issue` | TEXT | Primary defining issue |

**Indexes (13 total):**

| Index | Columns / Notes |
|---|---|
| `uidx_candidates_person` | UNIQUE on `person_id` |
| `idx_candidates_name` | `(last_name, first_name)` |
| `idx_candidates_status` | `(status)` |
| `idx_candidates_office` | `(office_type, office_state, office_district)` |
| `idx_candidates_party` | `(party)` |
| `idx_candidates_election_year` | `(election_year)` |
| `idx_candidates_fec_id` | `(fec_candidate_id)` WHERE NOT NULL |
| `idx_candidates_state_cmte` | `(state_committee_id)` WHERE NOT NULL |
| `idx_candidates_tier` | `(subscription_tier)` |
| `idx_candidates_county` | `(county)` |
| `idx_candidates_social_gin` | GIN on `social_media` |
| `idx_candidates_tags_gin` | GIN on `custom_tags` |
| `idx_candidates_issues_gin` | GIN on `issue_positions` |

---

#### `core.campaigns`

**Per-candidate campaign lifecycle. A candidate can have multiple campaigns** (primary, general, runoff, reelection). Has an `updated_at` trigger.

| Column | Type | Notes |
|---|---|---|
| `campaign_id` | UUID | PK |
| `candidate_id` | UUID | FK → `core.candidates.candidate_id`, CASCADE |
| `campaign_name` | TEXT | NOT NULL |
| `campaign_type` | TEXT | NOT NULL, CHECK: `primary` / `general` / `runoff` / `special` / `reelection` / `recall` / `referendum` |
| `election_cycle` | TEXT | e.g. `'2025-2026'` |
| `election_date` | DATE | |
| `status` | TEXT | NOT NULL, CHECK: `planning` / `active` / `paused` / `completed` / `won` / `lost` / `withdrawn` |
| `total_budget` | NUMERIC(14,2) | |
| `total_raised` | NUMERIC(14,2) | |
| `total_spent` | NUMERIC(14,2) | |
| `campaign_slogan` | TEXT | |
| `campaign_theme` | TEXT | |
| `campaign_priorities` | JSONB | JSON array of priority strings |
| `campaign_email` | TEXT | |
| `campaign_phone` | TEXT | |
| `campaign_address` | TEXT | |
| `metrics` | JSONB | `{ "emails_sent", "sms_sent", "calls_made", "doors_knocked", "yard_signs", "social_impressions", "website_visits", "volunteer_hours", "events_held" }` — refreshed nightly |

**Indexes (4):** `(candidate_id)`, `(status)`, `(election_cycle)`, `(campaign_type)`

---

### Layer B — Data Source Registry (`pipeline` schema)

---

#### `pipeline.data_sources`

**Master registry of ALL data sources.** Internal (Acxiom, DataTrust, FEC, NCBOE) and external third-party vendors. Plug-and-play: add a row here and the pipeline picks it up. Has an `updated_at` trigger.

| Column | Type | Notes |
|---|---|---|
| `source_id` | UUID | PK |
| `source_name` | TEXT | UNIQUE, NOT NULL |
| `source_type` | TEXT | CHECK: `voter_file` / `donation_file` / `consumer_data` / `model_scores` / `news_feed` / `social_media` / `polling` / `ad_platform` / `email_platform` / `sms_platform` / `payment_processor` / `crm` / `compliance` / `enrichment` / `field_ops` / `event_platform` / `analytics` / `custom` |
| `category` | TEXT | `'acxiom'`, `'datatrust'`, `'fec'`, `'ncboe'`, `'vendor'`, `'internal'` |
| `vendor_name` | TEXT | Third-party vendor name |
| `vendor_contact_name` | TEXT | |
| `vendor_contact_email` | TEXT | |
| `vendor_contract_id` | TEXT | |
| `vendor_contract_expires` | DATE | |
| `connection_type` | TEXT | NOT NULL, CHECK: `file_upload` / `api_pull` / `api_push` / `webhook` / `database_sync` / `sftp` / `stream` |
| `connection_config` | JSONB | `{ "api_url", "api_key_ref": "vault:...", "auth_type", "poll_interval_minutes", "sftp_host", "sftp_path", "webhook_secret": "vault:..." }` — API keys by vault reference, never plaintext |
| `data_format` | TEXT | `'csv'`, `'json'`, `'xml'`, `'parquet'`, `'api_json'` |
| `data_schema_version` | TEXT | Version tracking for schema changes |
| `expected_fields` | JSONB | Array of expected field names |
| `refresh_schedule` | TEXT | Cron expression, e.g. `'0 2 * * *'` |
| `last_refresh_at` | TIMESTAMPTZ | |
| `next_refresh_at` | TIMESTAMPTZ | |
| `expected_row_count` | BIGINT | For anomaly detection |
| `sla_freshness_hours` | INTEGER | Data must refresh within N hours |
| `reliability_score` | NUMERIC(5,2) | 0–100; degrades on failures, recovers on success |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT TRUE |
| `is_verified` | BOOLEAN | NOT NULL, DEFAULT FALSE — security audit passed |
| `compliance_status` | TEXT | CHECK: `pending` / `approved` / `restricted` / `revoked` |

**Seed data (9 rows inserted on deploy):**

| Source Name | Type | Category |
|---|---|---|
| DataTrust NC Voter File | `voter_file` | `datatrust` |
| NCBOE Donation Records | `donation_file` | `ncboe` |
| FEC Individual Contributions | `donation_file` | `fec` |
| FEC Committee Master | `donation_file` | `fec` |
| FEC Candidate Master | `donation_file` | `fec` |
| Acxiom InfoBase Enhancement | `consumer_data` | `acxiom` |
| Acxiom AP Models | `model_scores` | `acxiom` |
| Acxiom Consumer NC | `consumer_data` | `acxiom` |
| Acxiom Market Indices | `consumer_data` | `acxiom` |

**Indexes (6):** `(source_type)`, `(category)`, `(is_active)`, `(vendor_name)` WHERE NOT NULL, `(compliance_status)`, `(next_refresh_at)` WHERE `is_active = TRUE`

---

#### `pipeline.candidate_data_subscriptions`

**Per-candidate subscription to data sources.** Controls which data flows to which candidate. When a new vendor is added to `data_sources`, subscribe candidates here. Has an `updated_at` trigger.

| Column | Type | Notes |
|---|---|---|
| `subscription_id` | UUID | PK |
| `candidate_id` | UUID | NOT NULL, FK → `core.candidates.candidate_id`, CASCADE |
| `source_id` | UUID | NOT NULL, FK → `pipeline.data_sources.source_id`, RESTRICT |
| `campaign_id` | UUID | Nullable, FK → `core.campaigns.campaign_id`, SET NULL |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT TRUE |
| `priority` | INTEGER | 1–100, NOT NULL, DEFAULT 50 |
| `filter_config` | JSONB | `{ "state": "NC", "district": "05", "keywords": ["broyhill","watauga"], "committee_ids": ["C00123456"], "geo_radius_miles": 50 }` — narrows broad sources to candidate-relevant data |
| `custom_schedule` | TEXT | Cron override; NULL = use source default |
| `last_sync_at` | TIMESTAMPTZ | |
| `next_sync_at` | TIMESTAMPTZ | |
| `sync_status` | TEXT | CHECK: `idle` / `syncing` / `error` / `disabled` |
| `last_error` | TEXT | |
| `total_records_received` | BIGINT | NOT NULL, DEFAULT 0 |
| `total_records_processed` | BIGINT | NOT NULL, DEFAULT 0 |
| `total_records_failed` | BIGINT | NOT NULL, DEFAULT 0 |

**Unique constraint (functional index):**
```sql
CREATE UNIQUE INDEX uidx_cds_candidate_source_campaign
  ON pipeline.candidate_data_subscriptions (
      candidate_id, source_id,
      COALESCE(campaign_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );
```
> Uses the `COALESCE`-in-unique-index pattern (standard PostgreSQL) to enforce one subscription per candidate/source/campaign even when `campaign_id` is NULL. The sentinel UUID `00000000-0000-0000-0000-000000000000` stands in for NULL in the index. `brain.candidate_metrics` uses the same pattern.

**Indexes (5):** `(candidate_id)`, `(source_id)`, `(campaign_id)` WHERE NOT NULL, `(is_active)` WHERE TRUE, `(next_sync_at)` WHERE active and not disabled

---

### Layer C — Real-Time Data Ingest (`pipeline` schema)

---

#### `pipeline.inbound_data_queue`

**Universal intake table for ALL real-time data. Partitioned by month.**

Every data source lands here first: Acxiom batch files, DataTrust updates, FEC filings, news articles, social posts, webhook events, vendor pushes. Partitioned `BY RANGE (created_at)`.

Current partitions: `inbound_data_queue_2026_04`, `_2026_05`, `_2026_06`, `_2026_07`.

> **Add `2026_08` partition before July 31.**

| Column | Type | Notes |
|---|---|---|
| `record_id` | UUID | NOT NULL — part of composite PK |
| `source_id` | UUID | NOT NULL — FK intent to `pipeline.data_sources` (not enforced on partitioned table) |
| `source_name` | TEXT | Denormalized for fast reads |
| `source_record_id` | TEXT | External system's record ID (for dedup) |
| `candidate_id` | UUID | NULL = unrouted, needs router matching |
| `campaign_id` | UUID | |
| `subscription_id` | UUID | Which subscription matched this record |
| `data_type` | TEXT | NOT NULL — `voter_update` / `donation` / `news_article` / `social_post` / `poll_result` / `ad_metric` / `email_metric` / `sms_metric` / `enrichment_result` / `compliance_alert` / `field_report` / `event_rsvp` / `webhook_event` / `score_update` / `file_record` / `api_response` / `custom` |
| `payload` | JSONB | NOT NULL — actual data; structure varies by `data_type` |
| `status` | TEXT | NOT NULL, CHECK: `pending` → `routing` → `processing` → `enriching` → `completed` / `failed` / `skipped` / `duplicate` |
| `priority` | INTEGER | NOT NULL, DEFAULT 50 |
| `attempts` | INTEGER | NOT NULL, DEFAULT 0 |
| `max_attempts` | INTEGER | NOT NULL, DEFAULT 3 |
| `error_message` | TEXT | |
| `processed_at` | TIMESTAMPTZ | |
| `batch_id` | TEXT | Groups records from same file/API call |
| `parent_record_id` | UUID | Links chained records (e.g. enrichment spawned from donation) |
| `created_at` | TIMESTAMPTZ | NOT NULL — partition key |

Primary key: `(record_id, created_at)`.

**Processing flow:**
```
pending → routing → processing → enriching → completed
                                           ↘ failed / skipped / duplicate
```

**Indexes (6):**

| Index | Definition |
|---|---|
| `idx_idq_pending` | `(priority DESC, created_at)` WHERE `status = 'pending'` — primary work queue |
| `idx_idq_candidate` | `(candidate_id, created_at DESC)` WHERE `candidate_id IS NOT NULL` |
| `idx_idq_source` | `(source_id, created_at DESC)` |
| `idx_idq_type` | `(data_type)` |
| `idx_idq_batch` | `(batch_id)` WHERE `batch_id IS NOT NULL` |
| `idx_idq_source_record` | `(source_id, source_record_id)` WHERE `source_record_id IS NOT NULL` — dedup |

---

#### `pipeline.candidate_enrichment_log`

**Tracks every enrichment action applied to a candidate.** Acxiom scores, DataTrust updates, FEC filings, news matches, donations — all logged here. `is_significant = TRUE` rows fire `brain.event_queue` events.

| Column | Type | Notes |
|---|---|---|
| `enrichment_id` | UUID | PK |
| `candidate_id` | UUID | NOT NULL — FK intent to `core.candidates` |
| `person_id` | UUID | If enrichment applies to a specific person |
| `campaign_id` | UUID | |
| `source_id` | UUID | FK intent to `pipeline.data_sources` |
| `source_name` | TEXT | Denormalized |
| `inbound_record_id` | UUID | FK hint to `inbound_data_queue.record_id` |
| `enrichment_type` | TEXT | NOT NULL — `acxiom_score_update` / `datatrust_voter_update` / `fec_filing_update` / `donation_matched` / `news_article_matched` / `social_mention_detected` / `poll_result_added` / `ad_performance_updated` / `email_metrics_updated` / `wealth_score_updated` / `contact_appended` / `address_updated` / `phone_appended` / `email_appended` / `household_linked` / `voter_status_changed` / `party_registration_changed` / `compliance_flag_added` / `field_report_processed` / `custom` |
| `enrichment_data` | JSONB | NOT NULL — before/after values, scores, matched data |
| `fields_updated` | TEXT[] | Which fields were touched |
| `confidence_score` | NUMERIC(5,2) | 0–100 |
| `is_significant` | BOOLEAN | NOT NULL, DEFAULT FALSE — TRUE fires a `brain.event_queue` event |
| `status` | TEXT | CHECK: `applied` / `pending_review` / `rejected` / `rolled_back` |
| `triggered_event_id` | UUID | FK hint to `brain.event_queue.event_id` |
| `created_at` | TIMESTAMPTZ | NOT NULL |

**Indexes (6):** `(candidate_id, created_at DESC)`, `(person_id, created_at DESC)` WHERE NOT NULL, `(source_id)`, `(enrichment_type)`, `(candidate_id, created_at DESC)` WHERE `is_significant = TRUE`, `(created_at)`

---

### Layer D — Per-Candidate Brain Integration (`brain` schema)

---

#### `brain.candidate_triggers`

**Junction table linking `brain.triggers` to specific candidates** with optional per-candidate overrides. Allows candidate A to use trigger X with different settings than candidate B without modifying the global trigger. Has an `updated_at` trigger.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `candidate_id` | UUID | NOT NULL, FK → `core.candidates.candidate_id`, CASCADE |
| `trigger_id` | UUID | NOT NULL, FK → `brain.triggers.trigger_id`, CASCADE |
| `campaign_id` | UUID | Nullable, FK → `core.campaigns.campaign_id`, SET NULL |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT TRUE |
| `priority_override` | INTEGER | NULL = use global trigger priority |
| `cooldown_override` | INTEGER | NULL = use global `cooldown_minutes` |
| `custom_conditions` | JSONB | NULL = use global conditions |
| `custom_actions` | JSONB | NULL = use global actions |
| `allowed_channels` | TEXT[] | NULL = all channels allowed |
| `blocked_channels` | TEXT[] | e.g. `['sms']` if candidate opts out of SMS |
| `fire_count` | BIGINT | NOT NULL, DEFAULT 0 |
| `last_fired` | TIMESTAMPTZ | |

Unique constraint: `UNIQUE (candidate_id, trigger_id)`.

**Indexes (4):** `(candidate_id)`, `(trigger_id)`, `(campaign_id)` WHERE NOT NULL, `(candidate_id)` WHERE `is_active = TRUE`

---

#### `brain.candidate_metrics`

**Real-time KPI dashboard per candidate per time period.** Updated by the pipeline and Brain decisions. Powers E27 (real-time dashboard) and E29 (analytics dashboard).

| Column | Type | Notes |
|---|---|---|
| `metric_id` | UUID | PK |
| `candidate_id` | UUID | NOT NULL, FK → `core.candidates.candidate_id`, CASCADE |
| `campaign_id` | UUID | Nullable, FK → `core.campaigns.campaign_id`, SET NULL |
| `period_type` | TEXT | NOT NULL, CHECK: `hourly` / `daily` / `weekly` / `monthly` / `cycle` |
| `period_start` | TIMESTAMPTZ | NOT NULL |
| `period_end` | TIMESTAMPTZ | NOT NULL |

**Fundraising metrics:**

| Column | Type |
|---|---|
| `donations_received` | INTEGER |
| `donation_amount` | NUMERIC(14,2) |
| `avg_donation_size` | NUMERIC(10,2) |
| `new_donors` | INTEGER |
| `recurring_donors` | INTEGER |
| `lapsed_donors_reactivated` | INTEGER |

**Communication metrics:**

| Column | Notes |
|---|---|
| `emails_sent`, `emails_opened`, `emails_clicked` | Email funnel |
| `sms_sent`, `sms_responses` | SMS |
| `calls_made`, `calls_connected` | Phone |
| `mail_pieces_sent` | Direct mail |

**Digital metrics:**

| Column | Notes |
|---|---|
| `social_impressions` (BIGINT), `social_engagements` | Social |
| `website_visits` | Web |
| `ad_impressions` (BIGINT), `ad_clicks`, `ad_spend` (NUMERIC) | Paid ads |

**Field metrics:**

| Column | Notes |
|---|---|
| `doors_knocked`, `voter_contacts` | Field |
| `volunteer_hours` (NUMERIC) | Volunteer |
| `events_held`, `event_attendees`, `yard_signs_placed` | Events / visibility |

**News / PR metrics:**

| Column | Notes |
|---|---|
| `news_mentions` | Count of news articles |
| `news_sentiment_avg` | NUMERIC(5,2), –1.0 to 1.0 |
| `crisis_alerts` | Count of crisis-level mentions |
| `endorsements_received` | Count |

**Brain metrics:**

| Column | Notes |
|---|---|
| `brain_events_processed` | Events processed this period |
| `brain_decisions_go`, `brain_decisions_no_go` | Decision outcomes |
| `triggers_fired` | Trigger activations |

**Enrichment & compliance metrics:**

| Column | Notes |
|---|---|
| `records_ingested` (BIGINT), `records_enriched` (BIGINT) | Pipeline volume |
| `data_sources_active` | Active subscriptions |
| `compliance_flags`, `contribution_limit_warnings` | Compliance |

**Unique constraint (functional index):**
```sql
CREATE UNIQUE INDEX uidx_cm_candidate_period
  ON brain.candidate_metrics (
      candidate_id,
      COALESCE(campaign_id, '00000000-0000-0000-0000-000000000000'::uuid),
      period_type,
      period_start
  );
```
> Same `COALESCE`-in-unique-index pattern as `candidate_data_subscriptions`. One metrics row per candidate/campaign/period_type/period_start, even when `campaign_id` is NULL.

**Indexes (3):** `(candidate_id, period_type, period_start DESC)`, `(campaign_id, period_type, period_start DESC)` WHERE NOT NULL, `(period_type, period_start DESC)`

---

## Audit Layer

### `audit.activity_log`

**Immutable audit trail. Partitioned by month. NEVER UPDATE OR DELETE ROWS.**

Partitioned `BY RANGE (created_at)`. Current partitions: `2026-04`, `2026-05`, `2026-06`, `2026-07`.

> Add `2026-08` partition before July 31.

| Column | Notes |
|---|---|
| `action_type` | TEXT — what was done |
| `universe` | TEXT — which universe |
| `ecosystem` | TEXT — which ecosystem within universe |
| `actor_type` | TEXT — `'user'`, `'system'`, `'pipeline'`, etc. |
| `actor_id` | TEXT — ID of actor |
| `entity_type` | TEXT — type of entity acted upon |
| `entity_id` | TEXT — ID of entity acted upon |
| `person_id` | UUID — associated person if applicable |
| `details` | JSONB — full action detail |

```sql
-- Correct audit insert pattern:
INSERT INTO audit.activity_log
  (action_type, universe, ecosystem, actor_type, actor_id, entity_type, entity_id, person_id, details)
VALUES
  ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb);
-- NEVER: UPDATE audit.activity_log ...
-- NEVER: DELETE FROM audit.activity_log ...
```

---

## Search / Profile Layer

Two materialized views power the search UI (designed for 3,000 concurrent users). **Both are created `WITH NO DATA` and must be refreshed before first use.**

### Refresh Order

Always refresh in this order:

```sql
-- Step 1: donation rollup (no dependencies)
REFRESH MATERIALIZED VIEW CONCURRENTLY donor_intelligence.mv_donation_summary;

-- Step 2: donor profile (depends on mv_donation_summary)
REFRESH MATERIALIZED VIEW CONCURRENTLY donor_intelligence.mv_donor_profile;
```

---

### `donor_intelligence.mv_donor_profile`

Pre-computed donor profile for the search UI. Fuses:
- `person_master` base fields
- `ncboe_donations.cluster_profile` JSONB
- `datatrust_voter_nc` voter fields
- 90-day activity count from `audit.activity_log`

Used by all search endpoints. Never query the base tables directly in search contexts; use this view.

---

### `donor_intelligence.mv_donation_summary`

Per-person donation rollup across NCBOE and FEC, derived from `contribution_map`.

| Column | Notes |
|---|---|
| `person_id` | UUID |
| `total_donations` | Count of all contributions |
| `total_amount` | Total dollars across all sources |
| `ncboe_total` | NCBOE dollar total |
| `fec_total` | FEC dollar total |
| `ncboe_count` | NCBOE contribution count |
| `fec_count` | FEC contribution count |
| `first_donation` | Earliest donation date |
| `last_donation` | Most recent donation date |
| `unique_committees` | Count of distinct committees |
| `active_years` | Count of distinct donation years |
| `donation_years[]` | Array of years with activity |

---

### Full-Text and Fuzzy Search Indexes

All on `donor_intelligence.person_master`:

| Index Type | Columns | Use Case |
|---|---|---|
| GIN tsvector | `first_name`, `last_name`, `preferred_name`, `employer` | Full-text search (`@@` operator) |
| Trigram GIN | `last_name` | Fuzzy ILIKE: `WHERE last_name ILIKE '%broyh%'` |
| Trigram GIN | `first_name` | Fuzzy ILIKE: `WHERE first_name ILIKE '%ed%'` |

**Query pattern for search:**

```sql
-- Full-text search
SELECT *
FROM donor_intelligence.mv_donor_profile
WHERE to_tsvector('english', last_name || ' ' || first_name || ' ' || COALESCE(preferred_name, ''))
      @@ plainto_tsquery('english', $1)
LIMIT 50;

-- Fuzzy surname search
SELECT *
FROM donor_intelligence.mv_donor_profile
WHERE last_name ILIKE $1   -- e.g. '%broyhill%'
ORDER BY last_name, first_name
LIMIT 50;
```

---

## Key Relationships

```
person_master.rnc_regid
    → core.datatrust_voter_nc.rnc_regid            (LEFT JOIN — not all donors are registered voters)

person_master.ncboe_cluster_id
    → raw.ncboe_donations.cluster_id               (one person = one cluster)

person_master.fec_cluster_id
    → raw.fec_donations.cluster_id                 (one person = one FEC cluster)

donor_intelligence.contribution_map.person_id
    → donor_intelligence.person_master.person_id   (FK, NOT NULL)

donor_intelligence.contribution_map.source_row_id
    → raw.ncboe_donations.id                       (when source_system = 'ncboe')
    → raw.fec_donations.id                         (when source_system = 'fec')

donor_intelligence.committee_candidate_map.candidate_person_id
    → donor_intelligence.person_master.person_id   (FK, nullable — not all committees have matched candidates)

donor_intelligence.mv_donor_profile
    materializes: person_master
                + raw.ncboe_donations.cluster_profile (JSONB)
                + core.datatrust_voter_nc
                + audit.activity_log (90-day activity count)

donor_intelligence.mv_donation_summary
    materializes: donor_intelligence.contribution_map aggregates per person_id

-- Candidate Data Flow (deployed 2026-04-13)

core.candidates.person_id
    → donor_intelligence.person_master.person_id       (FK, UNIQUE — a candidate IS a person)

core.campaigns.candidate_id
    → core.candidates.candidate_id                     (FK, CASCADE)

pipeline.candidate_data_subscriptions.candidate_id
    → core.candidates.candidate_id                     (FK, CASCADE)

pipeline.candidate_data_subscriptions.source_id
    → pipeline.data_sources.source_id                  (FK, RESTRICT)

pipeline.inbound_data_queue.source_id
    → pipeline.data_sources.source_id                  (FK intent, not enforced on partitioned table)

pipeline.candidate_enrichment_log.candidate_id
    → core.candidates.candidate_id                     (FK intent)

brain.candidate_triggers.candidate_id
    → core.candidates.candidate_id                     (FK, CASCADE)

brain.candidate_triggers.trigger_id
    → brain.triggers.trigger_id                        (FK, CASCADE)

brain.candidate_metrics.candidate_id
    → core.candidates.candidate_id                     (FK, CASCADE)
```

---

## Critical Rules for Cursor

> These rules must be followed in **every** query, migration, and pipeline function written for this database. No exceptions.

---

### Rule 1 — ED = EDGAR, Never Edward

The name parser must always map the preferred name `"Ed"` to the formal first name `"EDGAR"` for Ed Broyhill. This is not a common nickname mapping — it is a specific business rule.

```python
# Correct
if preferred_name.upper() == "ED" and last_name.upper() == "BROYHILL":
    first_name = "EDGAR"

# WRONG — do not do this
if preferred_name.upper() == "ED":
    first_name = "EDWARD"
```

In the database: `preferred_name = 'Ed'`, `first_name = 'Edgar'`.

---

### Rule 2 — Individual Clusters, Household Linkage

- Each **person** gets their own `cluster_id` (NCBOE and/or FEC).
- **Household** totals are aggregated via `household_id`, not by merging clusters.
- Ed Broyhill wrote checks on behalf of others — those donations roll up into his cluster (`372171`), not the payee's cluster.
- **Melanie Broyhill** is a **separate person** with her own cluster (`372197`), but shares household `636697` with Ed.

```sql
-- Correct: household total uses household_id
SELECT SUM(p.donations_total)
FROM donor_intelligence.person_master p
WHERE p.household_id = 636697;

-- WRONG: do not merge clusters to get household total
```

---

### Rule 3 — Ed's 5-Tier Data Hierarchy

When building profiles or scores for Ed Broyhill (or any person), data sources must be used in strict priority order. Never use a lower-tier source if a higher-tier source is available.

| Priority | Source | Table(s) |
|---|---|---|
| 1 (highest) | Donation history | `contribution_map`, `ncboe_donations`, `fec_donations` |
| 2 | Voting history | `datatrust_voter_nc` |
| 3 | Party positions | `brain.triggers`, custom_tags |
| 4 | Volunteer activity | `volunteer.*` |
| 5 (last resort) | Acxiom modeled scores | `acxiom_ap_models`, `acxiom_consumer_nc` |

---

### Rule 4 — Every Donor Matters

Small donors are not noise — they are the volunteer pipeline. **Never filter out low-dollar donors** unless the user explicitly requests a minimum threshold. All contribution records must be preserved in `contribution_map` regardless of amount.

---

### Rule 5 — FEC Memo Rows Are Not Contributions

In `raw.fec_donations`, rows where `is_memo = TRUE` are **memo entries**, not itemized contributions. They represent earmarked pass-throughs or aggregate line items, not actual individual transactions.

```sql
-- ALL financial queries against fec_donations must include:
WHERE is_memo = FALSE

-- WRONG — never sum FEC totals without this filter:
SELECT SUM(transaction_amt) FROM raw.fec_donations WHERE cand_id = $1;

-- CORRECT:
SELECT SUM(transaction_amt) FROM raw.fec_donations
WHERE cand_id = $1 AND is_memo = FALSE;
```

---

### Rule 6 — NCBOE Dedup Is Finalized

The deduplication process on `raw.ncboe_donations` (cluster assignments, `cluster_profile` JSONB, `rnc_regid` matches, `dt_match_method`) is **complete and locked**. Do not:

- Re-run any dedup or clustering logic against this table
- Update `cluster_id`, `cluster_profile`, `rnc_regid`, or `dt_match_method`
- Add or drop indexes on this table
- Alter column types or constraints

This work is tracked in branch `session-mar17-2026-clean` (migrations 088–099).

---

### Rule 7 — Materialized Views Need Explicit Refresh

Both materialized views were created `WITH NO DATA`. They contain no rows until explicitly refreshed. Before any code reads from these views:

```sql
-- Required before first use, and after any significant data load:
REFRESH MATERIALIZED VIEW CONCURRENTLY donor_intelligence.mv_donation_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY donor_intelligence.mv_donor_profile;
```

Always refresh `mv_donation_summary` **before** `mv_donor_profile` (dependency order).

---

### Rule 8 — Partitioned Tables Need New Partitions Before Month-End

`brain.event_queue`, `audit.activity_log`, and `pipeline.inbound_data_queue` are all partitioned by month. A missing partition will cause inserts to fail with a "no partition found" error.

**Action required before July 31, 2026**: create `2026-08` partitions for all three tables:

```sql
CREATE TABLE brain.event_queue_2026_08 PARTITION OF brain.event_queue
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE audit.activity_log_2026_08 PARTITION OF audit.activity_log
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE pipeline.inbound_data_queue_2026_08 PARTITION OF pipeline.inbound_data_queue
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
```

Add a calendar reminder to create the next partition before the end of every month.

---

### Rule 9 — Universe-Aware Schema

The platform is in the process of consolidating from ~60 ecosystems into 5–7 universes. The `brain.event_queue.source_universe` column supports this consolidation. All new code must:

- Populate `source_universe` on every event insert
- Include `source_universe` in `audit.activity_log` inserts
- Never hard-code ecosystem names where a universe identifier should be used

---

### Rule 10 — Pipeline Idempotency

Every file load must check `pipeline.loaded_files` before processing. The pattern:

```python
import hashlib

def compute_sha256(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def should_skip_file(conn, file_hash: str, file_source: str) -> bool:
    row = conn.execute(
        "SELECT 1 FROM pipeline.loaded_files "
        "WHERE file_hash = %s AND file_source = %s AND status = 'complete'",
        (file_hash, file_source)
    ).fetchone()
    return row is not None
```

Valid `file_source` values: `'ncboe_gold'`, `'fec_individual'`, `'fec_committee'`, `'fec_candidate'`, `'datatrust'`, `'acxiom'`.

---

### Rule 11 — Candidate Data Flow Processing Order

Data entering the platform flows through these tables in sequence:

```
1. pipeline.inbound_data_queue       (status: pending → routing → processing → enriching → completed)
        ↓
2. pipeline.candidate_enrichment_log  (every enrichment action audited here)
        ↓  (if is_significant = TRUE)
3. brain.event_queue                  (significant enrichments fire brain events)
        ↓
4. brain.candidate_metrics            (aggregated KPIs updated per candidate per period)
```

Never write directly to `candidate_enrichment_log` or `candidate_metrics` without first recording the inbound data in `inbound_data_queue`. The queue is the authoritative intake point.

---

### Rule 12 — Plug-and-Play Vendor Integration

To add a new data vendor to the platform:

```sql
-- Step 1: Register the source
INSERT INTO pipeline.data_sources (source_name, source_type, category, connection_type, ...)
VALUES ('New Vendor Name', 'enrichment', 'vendor', 'api_pull', ...);

-- Step 2: Subscribe relevant candidates
INSERT INTO pipeline.candidate_data_subscriptions
  (candidate_id, source_id, filter_config, is_active)
VALUES ($candidate_id, $new_source_id, '{"state":"NC"}', TRUE);

-- Step 3: Data flows automatically
-- The pipeline reads candidate_data_subscriptions to route inbound_data_queue records.
-- No other code changes required.
```

The `filter_config` JSONB on `candidate_data_subscriptions` narrows broad sources (e.g., a national news feed) to candidate-relevant data using `state`, `district`, `keywords`, `committee_ids`, and `geo_radius_miles` filters.

---

## Operational Procedures

### Adding a New File Source

1. Add the new `file_source` value to the `pipeline.loaded_files` check constraint (if one exists) or document it here.
2. Write the loader to use `pipeline.loaded_files` idempotency pattern (Rule 10).
3. Insert a `pipeline.loaded_files` row with `status = 'in_progress'` at the start of the load.
4. Update to `status = 'complete'` only after successful commit.

### Adding a New Person Record

1. Compute `match_key` from normalized name + address.
2. Check `person_master` for existing `match_key` or `name_variants[]` match.
3. If match found: update the existing record, append to `name_variants[]` if needed.
4. If no match: `INSERT` with `uuid_generate_v4()` as `person_id`.
5. Insert corresponding rows into `contribution_map` for each linked donation.
6. Update `mv_donation_summary` and `mv_donor_profile` on next scheduled refresh.

### Checking Partition Health

```sql
SELECT
    parent.relname AS parent_table,
    child.relname  AS partition_name,
    pg_get_expr(child.relpartbound, child.oid) AS partition_range
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
WHERE parent.relname IN ('event_queue', 'activity_log', 'inbound_data_queue')
ORDER BY parent.relname, child.relname;
```

---

## GitHub / Migration Context

| Property | Value |
|---|---|
| Repository | `broyhill/BroyhillGOP` |
| Active branch | `session-mar17-2026-clean` |
| Migration range | `088` – `099` (Hetzner-native, dedup work) |
| Latest migration | `HETZNER_CANDIDATE_DATA_FLOW.sql` — deployed 2026-04-13 (8 new tables, 9 seed data source rows) |

All migration files should reference this document (`CURSOR_HETZNER_DB_ARCHITECTURE.md`) in their header comment for schema context. New migrations must:

- Be numbered sequentially from `100` onward
- Never alter tables listed in [Existing Tables (DO NOT ALTER)](#existing-tables-do-not-alter)
- Include a `-- Rollback:` comment section
- Check for partition existence before creating new ones (`IF NOT EXISTS` where PG version supports it)

---

*Last updated: 2026-04-13. Maintained in `broyhill/BroyhillGOP` — branch `session-mar17-2026-clean`.*
