# CANDIDATE ECOSYSTEM → SUPABASE GAP ANALYSIS
## Complete Investigation Transcript — February 2, 2026

---

## EXECUTIVE SUMMARY

**The comprehensive E03 Candidate Profiles system (273-field schema, 8 tables, 4 views, 3 reference tables with seed data) was NEVER deployed to Supabase.** The E24 Candidate Portal (7 additional tables) was also never deployed. What exists in Supabase are only raw data imports from NC State Board of Elections and FEC — basic election filing records, not the designed campaign management system.

**Combined undeployed development value: $220,000+** (E03: $80,000 + E24: $140,000)

---

## SECTION 1: WHAT WAS DESIGNED (E03 + E24)

### E03: Candidate Profiles System — `ecosystem_03_candidate_profiles.py`
**File:** `/mnt/project/ecosystem_03_candidate_profiles.py` (1,258 lines)
**Development Value:** $80,000+
**Capacity:** 5,000+ candidates across all levels

#### Main `candidates` Table — 273 Fields

**BASIC INFO (20 fields)**
- `candidate_id` (UUID, PK), `first_name`, `middle_name`, `last_name`, `suffix`, `preferred_name`, `legal_name`
- `date_of_birth`, `age`, `gender`, `pronouns`
- `email`, `phone`, `mobile`
- `address_line1`, `address_line2`, `city`, `state`, `zip`, `county`

**OFFICE INFO (25 fields)**
- `office_type`, `office_title`, `office_level` (federal/state/local)
- Geographic: `district_id`, `district_name`, `district_type`, `precinct`, `ward`
- Position: `is_incumbent`, `incumbent_since`, `term_start_date`, `term_end_date`, `terms_served`
- Election: `election_year`, `election_date`, `election_type`, `filing_date`, `ballot_name`, `ballot_order`
- Opponent: `opponent_name`, `opponent_party`, `opponent_incumbent`, `race_rating` (safe_r → toss_up → safe_d)

**POLITICAL INFO (30 fields)**
- `party`, `faction`, `faction_secondary`, `ideology_score` (0-100)
- Endorsements: `trump_endorsed` + date, `governor_endorsed`, `nra_grade`, `nra_endorsed`, `right_to_life_endorsed`, `chamber_endorsed`, `other_endorsements` (JSONB)
- Committees: `committees`, `committee_leadership`, `caucus_memberships` (all JSONB)
- Voting Record: `lifetime_conservative_score`, `current_session_score`, `key_votes` (JSONB)
- Legislative: `bills_sponsored`, `bills_cosponsored`, `bills_passed`, `amendments_sponsored`
- Ratings: `heritage_score`, `aclu_score`, `ntu_grade`

**CAMPAIGN INFO (35 fields)**
- `campaign_name`, `campaign_slogan`, `campaign_theme`, `campaign_priorities` (JSONB)
- Contact: `campaign_email`, `campaign_phone`, `campaign_address`, `campaign_city`, `campaign_state`, `campaign_zip`
- Online: `campaign_website`, `donation_url`, `volunteer_url`, `merchandise_url`
- Social Media (16 fields): Facebook (url + handle), Twitter, Instagram, YouTube, TikTok, LinkedIn, Truth Social, Rumble, Gettr, Parler, Gab
- Staff: `campaign_manager` + email + phone, `finance_director`, `communications_director`, `field_director`, `digital_director`, `treasurer`

**FINANCE INFO (25 fields)**
- IDs: `fec_candidate_id`, `fec_committee_id`, `state_committee_id`
- Fundraising: `raised_total`, `raised_this_cycle`, `raised_this_quarter`, `raised_this_month`
- `cash_on_hand`, `debt_total`
- Spending: `spent_total`, `spent_this_cycle`, `spent_this_quarter`
- Donors: `donor_count`, `avg_donation`, `small_dollar_pct`
- PAC: `pac_support_total`, `pac_opposition_total`, `super_pac_support` (JSONB)
- Self-funding: `self_funded_amount`, `personal_loan_amount`

**BIOGRAPHY (30 fields)**
- `biography`, `biography_short`, `tagline`
- Origin: `birth_city`, `birth_state`, `birth_country`, `hometown`, `years_in_district`
- Family: `marital_status`, `spouse_name`, `spouse_occupation`, `children_count`, `children_names` (JSONB), `grandchildren_count`
- Education: `education` (JSONB), `highest_degree`, `alma_mater`
- Career: `occupation`, `employer`, `business_owner`, `business_name`, `business_type`, `career_history` (JSONB)
- Military: `military_service`, `military_branch`, `military_rank`, `military_years`, `military_awards` (JSONB), `veteran`
- Faith: `religion`, `church_name`, `church_city`

**ISSUE POSITIONS (stored as JSONB — covers 60 issues)**
- `issue_positions` (JSONB), `priority_issues` (JSONB), `signature_issue`

**MEDIA (20 fields)**
- Photos: `headshot_url`, `headshot_formal_url`, `headshot_casual_url`, `family_photo_url`, `action_photo_url`
- Logos: `logo_url`, `logo_dark_url`, `banner_url`
- Video: `intro_video_url`, `campaign_video_url`
- Voice: `voice_sample_url`, `voice_profile_id`
- Press: `press_kit_url`, `press_release_latest`, `media_appearances` (JSONB)
- Branding: `brand_primary_color`, `brand_secondary_color`, `brand_font`

**AI CONTEXT (15 fields)**
- `ai_context`, `ai_voice_description`, `ai_messaging_tone`
- `ai_topics_avoid` (JSONB), `ai_key_phrases` (JSONB)
- `ai_opponents_attack_lines` (JSONB), `ai_defense_points` (JSONB), `ai_accomplishments` (JSONB)
- `ai_future_vision`, `ai_call_to_action`, `ai_donation_ask`, `ai_volunteer_ask`, `ai_vote_ask`
- `ai_last_updated`, `ai_generated_bio`

**DISTRICT INFO (20 fields)**
- `district_population`, `district_registered_voters`
- Party: `district_republican_pct`, `district_democrat_pct`, `district_independent_pct`
- Demographics: `district_median_income`, `district_median_age`, `district_urban_pct`, `district_suburban_pct`, `district_rural_pct`
- Race: `district_white_pct`, `district_black_pct`, `district_hispanic_pct`, `district_asian_pct`
- Education: `district_college_pct`
- Performance: `district_trump_2020_pct`, `district_trump_2016_pct`, `district_pvi`
- `district_top_issues` (JSONB), `district_counties` (JSONB)

**LOCAL CANDIDATE FIELDS (15 fields)**
- `local_churches`, `local_schools`, `local_civic_groups`, `local_sports_leagues` (all JSONB)
- `local_businesses_owned`, `local_boards_served`, `local_volunteer_history` (all JSONB)
- `neighborhood`, `hoa_name`, `years_homeowner`
- `community_involvement`, `local_newspaper`, `local_radio_station`, `local_tv_station`
- `local_issues` (JSONB)

**METADATA (13 fields)**
- `status` (active/withdrawn/suspended/lost/won), `profile_completeness` (0-100)
- `last_activity_date`, `data_source`, `data_quality_score`
- `verified`, `verified_by`, `verified_at`
- `notes`, `internal_notes`, `tags` (JSONB)
- `created_at`, `updated_at`

#### 11 Performance Indexes
- `idx_candidates_name` (last_name, first_name)
- `idx_candidates_office` (office_type, office_level)
- `idx_candidates_state` (state)
- `idx_candidates_county` (county)
- `idx_candidates_district` (district_id)
- `idx_candidates_party` (party)
- `idx_candidates_faction` (faction)
- `idx_candidates_status` (status)
- `idx_candidates_election` (election_year, election_type)
- `idx_candidates_incumbent` (is_incumbent)
- `idx_candidates_trump` (trump_endorsed)

#### Supporting Tables

**`candidate_endorsements`** — Endorsement tracking
- `endorsement_id` (UUID PK), `candidate_id` (FK → candidates)
- `endorser_type` (person/organization/official), `endorser_name`, `endorser_title`, `endorser_organization`
- `endorsement_date`, `endorsement_quote`, `endorsement_url`
- `is_notable`, `display_order`, `created_at`

**`candidate_events`** — Campaign event tracking
- `event_id` (UUID PK), `candidate_id` (FK → candidates)
- `event_type`, `event_name`, `event_date`, `event_time`
- `venue_name`, `venue_address`, `venue_city`
- `is_public`, `rsvp_required`, `rsvp_url`
- `expected_attendance`, `actual_attendance`, `notes`, `created_at`

**`candidate_news`** — Media mention tracking with sentiment
- `news_id` (UUID PK), `candidate_id` (FK → candidates)
- `headline`, `source`, `source_type` (newspaper/tv/radio/online)
- `url`, `published_at`, `sentiment` (positive/negative/neutral)
- `is_opinion`, `summary`, `created_at`

**`candidate_polling`** — Poll result tracking
- `poll_id` (UUID PK), `candidate_id` (FK → candidates)
- `pollster`, `poll_date`, `sample_size`, `margin_of_error`
- `candidate_pct`, `opponent_pct`, `undecided_pct`, `lead`
- `methodology`, `url`, `created_at`

#### Reference Tables (with seed data in deploy function)

**`office_types`** — 50+ office type reference
- `office_type_code` (PK), `office_title`, `office_level`, `term_years`
- `description`, `requirements`, `salary_range`, `is_partisan`, `is_elected`

Seeded with 50+ types across 7 categories:
- **Federal (4):** President, VP, Senator, Representative
- **State Executive (10):** Governor, Lt Governor, AG, Secretary of State, Treasurer, Auditor, Superintendent, Agriculture/Insurance/Labor Commissioners
- **State Legislature (4):** State Senator, Representative, House, Assembly
- **State Judicial (6):** Supreme Court, Appeals Court, Superior Court, District Court, DA, Public Defender
- **County (12):** Commissioner, Manager, Sheriff, Clerk of Court, Register of Deeds, Tax Collector, Treasurer, Auditor, Coroner, Surveyor, Soil & Water, Board Chair
- **Municipal (10):** Mayor, City Council, Town Council, Alderman, City Manager, City Clerk, City Treasurer, City Attorney, Municipal Judge, Police Chief
- **School Board (4):** School Board Member, Board Chair, Superintendent of Schools, Community College Board
- **Special Districts (6):** Hospital Board, Water District, Fire District, Sanitation District, Transit Board, Airport Authority

**`factions`** — 13 faction alignments reference
- `faction_code` (PK), `faction_name`, `description`, `priority_issues` (JSONB), `key_figures` (JSONB)

Seeded with 13 factions:
1. **MAGA / America First** — Trump-aligned, populist conservative (immigration, trade, america_first, election_integrity)
2. **Establishment Republican** — Traditional GOP, business-friendly (tax_cuts, free_trade, defense, fiscal_responsibility)
3. **Liberty / Libertarian** — Small government, individual freedom (limited_government, civil_liberties, spending_cuts, term_limits)
4. **Social Conservative** — Faith-based, traditional values (pro_life, religious_liberty, traditional_marriage, parental_rights)
5. **Fiscal Conservative** — Budget hawks, debt reduction (balanced_budget, spending_cuts, debt_reduction, tax_reform)
6. **Moderate Republican** — Centrist, pragmatic (bipartisanship, pragmatic_solutions, healthcare, infrastructure)
7. **Tea Party** — Constitutional conservative, anti-establishment (constitution, limited_government, term_limits, spending_cuts)
8. **Chamber of Commerce** — Pro-business, economic growth (business_friendly, workforce, regulations, economic_growth)
9. **Defense / National Security** — Strong military focus (military_strength, veterans, border_security, foreign_policy)
10. **Rural Conservative** — Agriculture, rural issues (agriculture, rural_broadband, gun_rights, property_rights)
11. **Suburban Republican** — Quality of life focus (schools, public_safety, property_values, quality_of_life)
12. **Young Republican** — Next generation conservative (technology, environment, opportunity, innovation)
13. **Independent Conservative** — Non-partisan conservative (common_sense, accountability, transparency, reform)

**`issues`** — 60 hot button issues reference
- `issue_code` (PK), `issue_name`, `category`, `description`, `republican_position`, `democrat_position`, `talking_points` (JSONB)

Seeded with 60 issues across 9 categories:
- **Economy (10):** Tax Cuts, Tax Reform, Balanced Budget, Debt Reduction, Spending Cuts, Free Trade, Tariffs/Protectionism, Minimum Wage, Right to Work, Economic Growth
- **Social Issues (12):** Pro-Life, Pro-Choice, Traditional Marriage, LGBT Rights, Religious Liberty, Parental Rights, School Choice, Ban CRT, Oppose Gender Ideology, Death Penalty, Marijuana Legalization, Gambling Expansion
- **Immigration (6):** Border Wall, Mass Deportation, End Sanctuary Cities, DACA/Dreamers, Immigration Reform, E-Verify Mandate
- **Second Amendment (4):** Gun Rights, Gun Control, Constitutional Carry, Red Flag Laws
- **Government (8):** Limited Government, Term Limits, Voter ID, Election Integrity, States' Rights, Regulatory Reform, Government Transparency, Convention of States
- **National Security (6):** Strong Military, Veterans Support, Border Security, America First Foreign Policy, Support for Israel, Tough on China
- **Healthcare (6):** Repeal Obamacare, Healthcare Choice, Medicare Eligibility Age, Lower Drug Prices, Mental Health Funding, No Vaccine Mandates
- **Environment/Energy (6):** Energy Independence, Support Fossil Fuels, Oppose Green New Deal, Nuclear Energy, No EV Mandates, Climate Change Policy
- **Crime/Justice (4):** Support Law Enforcement, Criminal Justice Reform, End Cashless Bail, Tough on Crime

#### 4 Database Views
- `v_candidate_summary` — Active candidates with key fields (name, office, district, party, faction, endorsements, cash, profile completeness)
- `v_federal_candidates` — Active federal candidates ordered by office/state/district
- `v_state_candidates` — Active state candidates ordered by state/office/district
- `v_local_candidates` — Active local candidates ordered by state/county/office

#### Python Manager Class — `CandidateProfileManager`
Full CRUD operations:
- `create_candidate()` — Insert with office type lookup
- `update_candidate()` — Dynamic field updates
- `get_candidate()` — Single profile retrieval
- `search_candidates()` — Filtered search (office_type, level, state, county, faction, trump_endorsed, is_incumbent)
- `set_issue_position()` — Update JSONB issue positions
- `add_endorsement()` — Insert endorsement records
- `generate_ai_context()` — Build AI-ready candidate context from profile data
- `calculate_profile_completeness()` — Score 0-100 based on filled fields
- `get_candidates_by_faction()` — Faction-filtered search
- `get_candidates_by_office()` — Office-filtered search
- `get_stats()` — Aggregate statistics with faction breakdown

#### Deployment Function — `deploy_candidate_system()`
- Creates all tables via `CANDIDATE_SCHEMA` SQL
- Seeds `office_types` (50+ types)
- Seeds `factions` (13 alignments)
- Seeds `issues` (60 hot button issues)
- **THIS FUNCTION WAS NEVER EXECUTED**

---

### E24: Candidate Portal — `ecosystem_24_candidate_portal.py`
**File:** `/mnt/project/ecosystem_24_candidate_portal.py` (1,284 lines)
**Development Value:** $140,000+
**Monthly Savings:** $900+/month (replaces NationBuilder $500/mo + NGP VAN $400/mo)

#### Portal Schema — 7 Tables

**`portal_users`** — Candidate and staff authentication
- `user_id` (UUID PK), `candidate_id`, `email` (unique), `first_name`, `last_name`, `phone`
- Auth: `password_hash`, `mfa_enabled`, `mfa_secret`
- Role: `role` (candidate/manager/staff/viewer), `permissions` (JSONB)
- Preferences: `notification_preferences`, `dashboard_layout`, `timezone`
- Status: `is_active`, `last_login_at`, `login_count`

**`portal_sessions`** — Session management
- `session_id`, `user_id` (FK), `token_hash`, `ip_address`, `user_agent`
- `created_at`, `expires_at`, `last_activity_at`

**`portal_dashboards`** — Dashboard configurations
- `dashboard_id`, `candidate_id`, `user_id` (FK)
- `name`, `description`, `is_default`
- `layout_config` (JSONB), `widgets` (JSONB)
- Sharing: `is_shared`, `shared_with` (JSONB)

**`portal_widgets`** — Dashboard widget configs
- 14 widget types: Fundraising Gauge, Donor Feed, Event Calendar, Volunteer Leaderboard, News Feed, Approval Queue, Social Metrics, Campaign Health, Action Items, Competitor Tracker, Poll Tracker, Map Visualization, Countdown Timer, Quick Stats
- Position grid: `position_x`, `position_y`, `width`, `height`
- Data: `data_source`, `data_config`, `refresh_interval_seconds`

**`portal_alerts`** — Alert system
- 5 priority levels: critical, high, medium, low, info
- Source tracking: `source_ecosystem`, `source_entity_type`, `source_entity_id`
- Actions: `action_url`, `action_label`, `requires_action`
- Status: `is_read`, `is_dismissed` with timestamps

**`portal_approvals`** — Content approval workflow
- Item types: content, expense, email, ad, etc.
- Status: pending, approved, rejected, expired
- Review tracking: `reviewed_by`, `reviewed_at`, `review_notes`

**`portal_activity_log`** — Activity audit trail
- Tracks all portal actions with `activity_type`, `description`, `metadata` (JSONB)

---

## SECTION 2: WHAT EXISTS IN SUPABASE (ACTUAL STATE)

### Query Results — 17 Candidate-Related Tables Found

| # | Table Name | Row Count | Status |
|---|-----------|-----------|--------|
| 1 | `candidate_avatars` | 0 | Empty |
| 2 | `candidate_media_library` | 9 | Minimal |
| 3 | `candidate_profiles` | 1 | Single test record |
| 4 | `candidate_scripts` | 5 | Minimal |
| 5 | `donor_candidate_scores` | 0 | Empty |
| 6 | `fec_candidate_party` | 0 | Empty |
| 7 | `fec_candidates` | 161 | FEC import |
| 8 | `fec_candidates_staging` | 0 | Empty |
| 9 | `fec_committee_candidate_lookup` | 8,203 | FEC import |
| 10 | `ncboe_candidates` | 777 | NC BOE import |
| 11 | **`ncsbe_candidates`** | **31,052** | **Primary data** |
| 12 | `ncsbe_candidates_raw` | 0 | Empty |
| 13 | `republican_candidate_contacts` | 0 | Empty |
| 14-17 | (other candidate-related) | 0 | Empty |

### Primary Data Source: `ncsbe_candidates` — 31,052 Rows, 22 Columns

**Schema:**
```
id (bigint, PK)
election_dt (varchar)
county_name (varchar)
contest_name (varchar)
name_on_ballot (varchar)
first_name (varchar)
middle_name (varchar)
last_name (varchar)
name_suffix_lbl (varchar)
nickname (varchar)
street_address (varchar)
city (varchar)
state (varchar)
zip_code (varchar)
phone (varchar)
email (varchar)
full_name_mail (varchar)
full_name_rep (varchar)
candidacy_dt (varchar)
election_type (varchar)
party (varchar)
created_at (timestamp)
```

**Sample Data:**
| name_on_ballot | contest_name | county_name | party |
|---------------|--------------|-------------|-------|
| Jim O'Neill | NC GOVERNOR | FORSYTH | REP |
| Hal Weatherman | NC LT. GOVERNOR | MECKLENBURG | REP |
| Donald J. Trump | US PRESIDENT | STATEWIDE | REP |

**What this table IS:** Raw NC State Board of Elections candidate filing data — names, addresses, party, contest, election dates.

**What this table IS NOT:** A campaign management system. No finance data, no endorsements, no issue positions, no AI context, no media, no district demographics, no campaign staff, no social media, no voting records.

---

## SECTION 3: THE GAP

### Tables That SHOULD Exist But DON'T

From E03 (never deployed):
| Table | Purpose | Status |
|-------|---------|--------|
| `candidates` | Main 273-field campaign profiles | **DOES NOT EXIST** |
| `candidate_endorsements` | Endorsement tracking | **DOES NOT EXIST** |
| `candidate_events` | Campaign event tracking | **DOES NOT EXIST** |
| `candidate_news` | Media mentions + sentiment | **DOES NOT EXIST** |
| `candidate_polling` | Poll results tracking | **DOES NOT EXIST** |
| `office_types` | 50+ office type reference | **DOES NOT EXIST** |
| `factions` | 13 faction reference | **DOES NOT EXIST** |
| `issues` | 60 issue position reference | **DOES NOT EXIST** |
| `v_candidate_summary` | Active candidate summary view | **DOES NOT EXIST** |
| `v_federal_candidates` | Federal candidates view | **DOES NOT EXIST** |
| `v_state_candidates` | State candidates view | **DOES NOT EXIST** |
| `v_local_candidates` | Local candidates view | **DOES NOT EXIST** |

From E24 (never deployed):
| Table | Purpose | Status |
|-------|---------|--------|
| `portal_users` | Candidate/staff authentication | **DOES NOT EXIST** |
| `portal_sessions` | Session management | **DOES NOT EXIST** |
| `portal_dashboards` | Dashboard configurations | **DOES NOT EXIST** |
| `portal_widgets` | Widget configurations | **DOES NOT EXIST** |
| `portal_alerts` | Alert system | **DOES NOT EXIST** |
| `portal_approvals` | Approval workflows | **DOES NOT EXIST** |
| `portal_activity_log` | Activity audit trail | **DOES NOT EXIST** |

**Total: 19 tables + 4 views designed but never deployed**

### What Deploying Would Enable

**Immediate:**
- Transform 31,052 raw ncsbe_candidates records into rich 273-field campaign profiles
- Cross-reference with 8,203 FEC committee/candidate records and 161 FEC candidate records
- Create unified candidate identity linking NCSBE + FEC + NCBOE data sources
- Seed 50+ office types, 13 factions, and 60 issue positions as reference data

**Platform Integration:**
- E20 Intelligence Brain could score and analyze candidates
- E22 A/B Testing could optimize candidate messaging
- E01 Donor Intelligence could link donors to candidates
- E30 Email could generate candidate-specific communications
- E32 Phone Banking could use AI context for call scripts
- E45 Video Studio could use voice/media profiles
- E56 Visitor Deanonymization could attribute website visits to candidate interest

### Data Flow Architecture (Designed But Not Connected)

```
RAW DATA SOURCES                    DESIGNED SYSTEM (NOT DEPLOYED)
┌─────────────────┐                ┌──────────────────────────────┐
│ ncsbe_candidates │───────────────│                              │
│ (31,052 rows)    │  ETL needed   │   candidates (273 fields)    │
├─────────────────┤                │                              │
│ fec_candidates   │───────────────│   office_types (50+ types)   │
│ (161 rows)       │  ETL needed   │   factions (13 alignments)   │
├─────────────────┤                │   issues (60 positions)      │
│ fec_committee_   │───────────────│                              │
│ candidate_lookup │  ETL needed   │   candidate_endorsements     │
│ (8,203 rows)     │               │   candidate_events           │
├─────────────────┤                │   candidate_news             │
│ ncboe_candidates │───────────────│   candidate_polling          │
│ (777 rows)       │  ETL needed   │                              │
└─────────────────┘                └──────────────┬───────────────┘
                                                  │
                                                  ▼
                                   ┌──────────────────────────────┐
                                   │  E24: Candidate Portal       │
                                   │  (portal_users, dashboards,  │
                                   │   widgets, alerts, approvals)│
                                   └──────────────────────────────┘
```

---

## SECTION 4: DEPLOYMENT REQUIREMENTS

### To Deploy E03 Schema
1. Execute `CANDIDATE_SCHEMA` SQL against Supabase (creates tables + indexes)
2. Run seed functions for `office_types` (50+ records), `factions` (13 records), `issues` (60 records)
3. Build ETL pipeline: `ncsbe_candidates` → `candidates` field mapping
4. Build ETL pipeline: `fec_candidates` → `candidates` enrichment
5. Build ETL pipeline: `fec_committee_candidate_lookup` → `candidates.fec_committee_id` linking

### To Deploy E24 Schema
1. Execute `CANDIDATE_PORTAL_SCHEMA` SQL against Supabase
2. Depends on E03 `candidates` table existing first (FK references)

### DEPLOY BLOCK Considerations
Per established protocol, deployment requires:
1. ✅ Read affected ecosystems (E03, E24 — done in this analysis)
2. ⬜ Check E20 Brain Hub integration (E20 references candidate data)
3. ⬜ Verify no breaks to existing 95 tables
4. ⬜ Eddie's explicit approval

---

## SECTION 5: EXISTING DATA QUALITY NOTES

### `ncsbe_candidates` (31,052 rows)
- Date fields stored as VARCHAR not DATE (e.g., `election_dt`, `candidacy_dt`)
- No deduplication — same candidate appears multiple times across elections
- No party normalization (REP, DEM, LIB, GRE, etc.)
- Basic contact info only: street address, phone, email
- No unique candidate identifier across elections
- No linking to FEC records

### `fec_committee_candidate_lookup` (8,203 rows)
- Federal candidates only
- Links FEC committee IDs to candidate IDs
- Would populate `candidates.fec_candidate_id` and `candidates.fec_committee_id`

### `fec_candidates` (161 rows)
- Small subset of federal candidates
- Has FEC-specific identifiers

### `ncboe_candidates` (777 rows)
- NC Board of Elections specific data
- Smaller than NCSBE dataset

---

## APPENDIX: DEPLOYMENT SQL (From E03 deploy_candidate_system())

The deploy function at line 1154 of `ecosystem_03_candidate_profiles.py` executes:
1. `CANDIDATE_SCHEMA` — All CREATE TABLE, CREATE INDEX, CREATE VIEW statements
2. Office types seed — 50+ INSERT INTO office_types
3. Factions seed — 13 INSERT INTO factions
4. Issues seed — 60 INSERT INTO issues

All use ON CONFLICT DO NOTHING for idempotent re-runs.

---

*Investigation conducted February 2, 2026 via Supabase SQL Editor against project `isbgjpnbocdkeslofota`*
*Ecosystem files reviewed from `/mnt/project/` (Claude project knowledge)*
