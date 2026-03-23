# BroyhillGOP Full Database Audit
**Date:** March 23, 2026  
**Total Tables:** 874 | **Total Size:** ~55 GB | **Platform:** Supabase PostgreSQL

---

## PART 1: IDENTITY & VOTER FOUNDATION

### `nc_datatrust` — 7,655,593 rows | 251 cols | 12 GB
The crown jewel. This is the full RNC/DataTrust NC voter file — every registered NC voter enriched with 251 data points. It comes from DataTrust (the RNC's data cooperative), which aggregates the state voter file and overlays consumer data, model scores, and behavioral signals.

**What it contains:**
- `rnc_regid` — RNC's internal voter ID (the universal key across all RNC systems)
- `statevoterid` — NC State Board of Elections NCID (matches `nc_voters.ncid` exactly)
- Full name, address, phone, email
- Party registration, voter status, registration date
- 50+ RNC model scores: Republican Party Score, Turnout Score, Donor Propensity, Issue positions
- Ethnicity, gender, age, education estimates
- Voting history flags
- Employer, occupation
- Congressional, state senate, state house districts, precinct

**How it links to nc_voters:** `nc_datatrust.statevoterid = nc_voters.ncid` — direct exact match. Both originate from the NC State Board of Elections voter file. 7,655,593 of the 9,082,810 nc_voters records appear in DataTrust. The ~1.4M gap = voters registered after the DataTrust data pull, or records DataTrust filtered out.

---

### `nc_voters` — 9,082,810 rows | 71 cols | 8.6 GB
The official NC State Board of Elections voter registration file. Every registered voter in NC.

**Breakdown by party:**
- Republican: 2,718,162
- Democrat: 2,857,354
- Unaffiliated: 3,448,644
- Libertarian: 54,102

**Key fields:** ncid (primary key), name, address, zip, mail address, phone, party_cd, status_cd, registr_dt, race_code, ethnic_code, gender_code, county, congressional/senate/house districts

**How it links to DataTrust:** `nc_voters.ncid = nc_datatrust.statevoterid`  
**How it links to person_master:** `nc_voters.ncid = person_master.ncvoter_ncid`

---

### `person_master` — 7,660,662 rows | 43 cols | 6.2 GB
The identity spine of the platform. Built from DataTrust as the canonical person record — one row per unique individual. Every ecosystem feeds off this table.

**Linkage status (CRITICAL):**

| Link Column | Populated | % | Status |
|-------------|-----------|---|--------|
| `datatrust_rncid` | 7,655,593 | 100% | ✅ Done |
| `ncvoter_ncid` | 7,660,662 | 100% | ✅ Done |
| `rnc_rncid` | 0 | 0% | ❌ EMPTY |
| `boe_donor_id` | 0 | 0% | ❌ EMPTY |
| `fec_contributor_id` | 0 | 0% | ❌ EMPTY |
| `is_voter` | 7,660,662 | 100% | ✅ |
| `is_donor` | 82,269 | 1.1% | ⚠️ WAY TOO LOW |

**The problem:** person_master knows about voters but NOT donors. The rnc_rncid, boe_donor_id, and fec_contributor_id columns are all zero. Only 82,269 people are flagged as donors when we have 625,897 BOE records and 2.6M FEC records. The linkage from donor tables back to person_master has not been completed.

---

### `acxiom_consumer_data` — 7,655,593 rows | 152 cols | 4.1 GB
Consumer lifestyle enrichment data from Acxiom, row-matched to DataTrust exactly (same 7.6M count). Appended to every DataTrust voter record.

**Contains:** Household income estimate, education level, credit indicators, homeowner/renter status, vehicle ownership, retail purchase behaviors, lifestyle segments, financial product ownership, health indicators, magazine/media consumption.

**How it links:** Matched to nc_datatrust row-for-row by RNCID during the DataTrust load pipeline.

---

### `rnc_voter_staging` — 7,708,542 rows | 6 cols | 1.1 GB
The full RNC DataHub NC voter file downloaded specifically for RNCID resolution. Downloaded March 22, 2026.

**Columns:** rncid, statevoterid, norm_last, norm_first, zip5  
**Purpose:** Join to nc_boe_donations_raw on name+zip to backfill rncid and voter_ncid onto donation records.  
**Status:** Used in the 54.1% exact match pass. Still needed for the fuzzy pass on remaining 287K rows.

---

### `rnc_voter_core` — 1,106,000 rows | 62 cols | 638 MB
A partial load of the RNC DataHub full voter record (only 14.4% of the 7.7M file). Has all 62 RNC data columns for the loaded records. The 7 supplemental `rnc_*` tables below all have exactly 1,105,000 rows — they correspond to this same 1.1M cohort.

**The 7 supplemental RNC tables (each ~1.1M rows):**
- `rnc_proprietary_scores` (371 MB, 7 cols) — RNC's private model scores
- `rnc_scores` (211 MB, 16 cols) — General RNC composite scores
- `rnc_addresses` (311 MB, 49 cols) — Address history and validation
- `rnc_phones` (278 MB, 41 cols) — Phone numbers with type and quality flags
- `rnc_vote_history` (134 MB, 52 cols) — Election-by-election voting history
- `rnc_demographics_acs` (197 MB, 11 cols) — ACS census demographics overlay
- `rnc_political_geography` (307 MB, 31 cols) — Districts, precincts, jurisdictions

---

## PART 2: THE DATATRUST LOOKUP SYSTEM

### `_lookup_datatrust_*` — 27 tables | ~6.6M rows total
These are alphabetically-sharded lookup indexes built FOR FAST DataTrust name matching. When a donor name needs to be matched to a DataTrust/person_master record, instead of scanning all 7.6M rows, the system queries the appropriate letter bucket.

| Table | Rows | Purpose |
|-------|------|---------|
| `_lookup_datatrust_all` | 6,590,951 | Full index, all letters |
| `_lookup_datatrust_b` | 635,443 | Last names starting with B |
| `_lookup_datatrust_m` | 627,823 | Last names starting with M |
| `_lookup_datatrust_s` | 627,405 | Last names starting with S |
| `_lookup_datatrust_h` | 522,527 | H surnames |
| `_lookup_datatrust_c` | 502,587 | C surnames |
| `_lookup_datatrust_w` | 441,059 | W surnames |
| ...etc | | |

**Schema (each table):** norm_last, norm_first (or first initial), zip5, rnc_regid — the minimum data needed to execute a match and return the RNCID for joining back to the full DataTrust record.

---

## PART 3: DONATION DATA

### `nc_boe_donations_raw` — 625,897 rows | 62 cols | 1.3 GB
NC Board of Elections campaign finance records. Every donation to every NC political committee that was required to file with NCSBE.

**Linkage status:**

| Column | Populated | % |
|--------|-----------|---|
| `member_id` (internal UUID) | 625,897 | 100% |
| `rncid` | 338,720 | 54.1% |
| `voter_ncid` | 338,720 | 54.1% |
| `golden_record_id` | 290,931 | 46.5% |

**Key fields:** donor_name, address, zip, profession, employer, committee_name, committee_sboe_id (NC committee ID), amount, date, transaction_type, form_of_payment, norm_last, norm_first, norm_zip5, rncid, voter_ncid, golden_record_id

**Why 287K have no rncid:** The exact name+zip5 match pass ran March 22, 2026. The 287,177 unmatched rows either have name format differences (nickname vs. legal name, hyphenated names), different zip codes on the donation vs. voter registration, or are legitimately out-of-state donors to NC committees. A fuzzy trigram pass will recover an estimated 80-120K more.

---

### `fec_donations` — 2,597,935 rows | 32 cols | 2.8 GB
FEC Schedule A individual contribution records for NC Republican committees. Every federal campaign donation made to an NC-connected Republican committee.

**Linkage status:**
- person_id populated: 2,330,166 (89.7%) ✅
- Distinct committees: 3,734
- Republican donors: 423,240

**Key fields:** committee_id, committee_name, contributor name/address/zip, employer, occupation, contribution_date, contribution_amount, candidate_name, candidate_office, two_year_period, fec_category, party, person_id (links to person_master), norm_first, norm_last, norm_zip5

---

### `fec_party_committee_donations` — 1,734,568 rows | 32 cols | 2.6 GB
FEC committee-to-committee transfers, party coordinated expenditures, and PAC-to-candidate contributions. These are NOT individual donors — they are organizational money flows between political committees.

**Important:** Do NOT try to identity-match these. They are institutional transactions. Use for: understanding which PACs fund which candidates, party money flow analysis, coordinated spending patterns.

---

### `fec_god_contributions` — 224,887 rows | 127 cols | 1.5 GB
The "God file" — FEC contributions with maximum enrichment (127 columns). Combines raw FEC data with matched voter/person/DataTrust fields. The most complete individual FEC record available.

---

### `winred_donors` — 194,279 rows | 26 cols | 87 MB
Online donors via WinRed (the Republican small-dollar online fundraising platform). These are people who gave online to NC Republicans through the WinRed payment processor.

**Contains:** Total given, donation count, first gift date, last gift date, donor party, segment classification. Person_master has `winred_total_given`, `winred_donation_count`, `winred_first_gift`, `winred_last_gift` columns populated from this table.

---

### `nc_boe_pac_committee_raw` — 57,617 rows
NC BOE PAC and committee financial transactions (non-individual). Includes committee-to-committee contributions, in-kind donations, party transfers at the state level.

---

### `ncgop_god_contributions` — 23,026 rows
NCGOP state party-specific contributions with full enrichment. These are donations to the NC Republican Party itself.

---

### `ncgop_masterfile_donors` — 6,588 rows
NCGOP's internal masterfile of known high-value party donors. Pre-enriched, curated list.

---

## PART 4: THE CANDIDATE/COMMITTEE MATCHING MACHINE

This is the system that connects money to candidates. It has multiple layers:

### Layer 1: Committee Registries
- **`committee_registry`** — 10,975 rows — Master registry of ALL political committees active in NC (both NC BOE and FEC committees merged into one reference table). Central hub.
- **`fec_committee_master_staging`** — 35,521 rows — Full FEC national committee master file (staging). Contains committee_id, name, type (PAC/party/candidate), party, filing_frequency, treasurer, address. This is the raw FEC data not yet promoted to the master tables.
- **`committee_party_map`** — 4,553 rows — Maps each committee to its party affiliation.
- **`fec_committees`** — 60 rows ⚠️ — Only 60 rows! The FEC committee master table is nearly empty. The real data is in `fec_committee_master_staging` (35K rows). The staging table needs to be promoted.

### Layer 2: Candidate Files
- **`ncsbe_candidates`** — 55,985 rows — All NC candidates who have ever filed with NCSBE. Goes back decades. Every office from Governor to Soil & Water.
- **`candidate_profiles`** — 2,303 rows — Active NC Republican candidates with enriched profiles, linked to ecosystems.
- **`fec_candidates`** — 161 rows ⚠️ — Very sparse. Only 161 federal candidates. Needs to be built from fec_committee_master_staging.
- **`political_entity_master`** — 1,947 rows — Merged master list of candidates and committees as unified political entities.

### Layer 3: Committee-to-Candidate Links
- **`boe_committee_candidate_map`** — 1,033 rows — Maps NC BOE committee IDs to NC candidate IDs. Used to trace state-level donations to specific candidates.
- **`fec_committee_candidate_lookup`** — 770 rows — FEC committee-to-candidate lookup. Links committee IDs to the federal candidates they support.

### Layer 4: Donor-to-Candidate Matching (THE ENGINE)
- **`fec_donor_candidate_match`** — 1,631,495 rows — This is the biggest output of the matching machine. Every FEC donor linked to the candidate(s) they donated to. 1.6M matches.
- **`donor_candidate_scores`** — 142,288 rows — Affinity scores between donors and candidates (who is likely to give to whom).
- **`fec_committee_transfers`** — 107,485 rows — Traces money through the committee transfer network.
- **`nc_donor_summary`** — 195,317 rows — Aggregated per-donor giving summary across all sources.

---

## PART 5: IDENTITY RESOLUTION TABLES

### `donor_contribution_map` — 795,345 rows | 12 cols
Maps donors to their contribution records across all sources (BOE, FEC, WinRed). The cross-source bridge.

### `donor_voter_links` — 309,112 rows | 7 cols | 74 MB
Explicit links between donor records and nc_voters records. 309K donors successfully matched to voter registrations.

### `person_source_links` — 1,846,282 rows | 6 cols | 899 MB
Maps each person_master record to their originating source records. One person can have entries pointing to DataTrust, BOE donations, FEC records, WinRed, etc. This is the audit trail of how each person was assembled.

### `rncid_resolution_queue` — 150,755 rows | 33 MB
Queue of donor records that need RNCID resolution. These are donors who couldn't be matched in the standard pipeline and are awaiting fuzzy matching or manual review.

### `golden_record_clusters` — 3 rows ⚠️
Nearly empty. The full clustering pipeline has not been run. This should have ~130-144K clusters once identity resolution is complete.

### `contact_enrichment` — 341,433 rows | 30 cols
Enriched contact information (phone, email, address validation) for ~341K people.

### `donor_acxiom_enrichment` — 12,099 rows
Acxiom consumer data matched specifically to donor records (separate from the bulk DataTrust-linked acxiom table).

---

## PART 6: SCORING & INTELLIGENCE

### `donor_candidate_scores` — 142,288 rows
Affinity scores: how likely is each donor to give to each candidate. Used by the E20 Brain for targeting.

### `rnc_proprietary_scores` — 1,106,000 rows
RNC's private model scores for 1.1M NC voters: Republican Party Score, turnout probability, issue position scores.

### `contact_enrichment` — 341,433 rows
Phone/email/address enrichment with quality flags.

### `brain_decisions`, `brain_events`, `brain_rules`, `brain_triggers`, `brain_event_queue`
E20 Brain Hub tables — all created, seeded with initial brain_rules, ready for the Docker brain service to write to.

---

## PART 7: ECOSYSTEM TABLES (874 TOTAL)

The database has 874 tables — the vast majority are ecosystem operational tables already built:
- **E17 (Ringless Voicemail):** 25 tables (e17_*)
- **E35 RVM:** 2 tables
- **E45 (Video Studio):** 8 tables
- **E55 (Contact Intelligence):** 11 tables
- **Campaigns, SMS, Email, Social, Events, Volunteers, Compliance, Analytics, etc.** — all built

---

## PART 8: GAPS — WHAT'S BROKEN OR MISSING

### 🔴 CRITICAL BLOCKERS

| # | Issue | Impact |
|---|-------|--------|
| 1 | `person_master.rnc_rncid` = 0 rows | Cannot link DataTrust voters to RNC DataHub supplemental data |
| 2 | `person_master.boe_donor_id` = 0 rows | BOE donations not linked to identity spine |
| 3 | `person_master.fec_contributor_id` = 0 rows | FEC donations not linked to identity spine |
| 4 | `person_master.is_donor` = 82,269 (should be 600K+) | Ecosystem donor targeting is working on 1% of actual donors |
| 5 | `golden_record_clusters` = 3 rows | Full identity clustering not run |
| 6 | `fec_committees` = 60 rows | FEC committee master data not promoted from staging (35K rows ready) |
| 7 | `fec_candidates` = 161 rows | Federal candidate table nearly empty |
| 8 | BOE rncid 54.1% complete | 287,177 donations have no voter match |

### 🟡 INCOMPLETE

| # | Issue | Status |
|---|-------|--------|
| 9 | `voter_ncid` column type = bigint | Should be VARCHAR (StateVoterID = alphanumeric like AR10451) |
| 10 | `rnc_voter_core` = 1.1M rows | Only 14.4% of 7.7M RNC file loaded |
| 11 | `fec_committee_master_staging` → `fec_committees` | Staging has 35K rows, production has 60 |
| 12 | `boe_committee_candidate_map` = 1,033 rows | Should map all 10,975 committees |
| 13 | `donor_acxiom_enrichment` = 12,099 rows | Acxiom enrichment only done for 12K donors |

---

## PART 9: COMPLETE TODO LIST TO FINISH THE DATABASE

### Phase 1 — Identity Spine (Do First — Everything Else Depends On This)

1. **Fix voter_ncid column type** on `nc_boe_donations_raw`: ALTER COLUMN voter_ncid from bigint → text/VARCHAR
2. **Run BOE fuzzy match pass** — recover 80-120K of the 287K unmatched BOE donations using trigram similarity on norm_last + norm_first + zip5
3. **Populate person_master.boe_donor_id** — join nc_boe_donations_raw.member_id → person_master on RNCID/NCID
4. **Populate person_master.fec_contributor_id** — join fec_donations.person_id → person_master
5. **Populate person_master.rnc_rncid** — join rnc_voter_staging.rncid → person_master on ncvoter_ncid = statevoterid
6. **Update person_master.is_donor = true** for all persons with BOE or FEC contribution records (~600K rows)
7. **Run identity clustering** — build golden_record_clusters from donor_contribution_map using union-find on name+address+zip variants

### Phase 2 — Committee & Candidate Master

8. **Promote fec_committee_master_staging → fec_committees** — INSERT 35,521 rows into fec_committees
9. **Build fec_candidates** from fec_committee_candidate_lookup + fec_donations distinct candidates
10. **Complete boe_committee_candidate_map** — map all NC BOE committees to candidates using ncsbe_candidates
11. **Reconcile political_entity_master** — merge ncsbe_candidates + fec_candidates into unified entity list

### Phase 3 — RNC Data Completion

12. **Resume rnc_voter_core load** — currently at 1.1M (14.4%), load remaining 6.6M records from RNC DataHub
13. **Link rnc_* supplemental tables** (scores, addresses, phones) to person_master via rnc_rncid

### Phase 4 — Scoring & Affinity

14. **Recalculate donor_candidate_scores** — after person_master linkage is complete, rerun affinity scoring on full donor universe (currently 142K, should be 600K+)
15. **Populate brain_decisions table** — create the schema (table exists but needs column definition check)
16. **Seed brain_rules** with E20 decision logic from the architecture document

### Phase 5 — Final Validation

17. **Verify donor_contribution_map completeness** — should map all 625K BOE + 2.6M FEC donations
18. **Validate person_source_links** — should have entries for all source tables
19. **Run full SELECT COUNT(*) audit** — verify all counts match expectations
20. **Update SESSION-STATE.md** with final verified counts
21. **Declare platform database READY** — clear ecosystems to begin using donor/voter data

---

## SUMMARY: WHAT YOU HAVE vs. WHAT YOU NEED

| Category | Have | Need |
|----------|------|------|
| NC Voter records | 9.08M ✅ | Done |
| DataTrust enriched voters | 7.66M ✅ | Done |
| Acxiom consumer data | 7.66M ✅ | Done |
| BOE donation records | 625,897 ✅ | Done (raw load) |
| FEC individual donations | 2.6M ✅ | Done (raw load) |
| BOE rncid matched | 338,720 (54%) | 287K fuzzy match pending |
| person_master voter links | 7.66M ✅ | Done |
| person_master donor links | 0 ❌ | Phases 1-2 above |
| Committee master | 60 rows ❌ | Promote 35K from staging |
| Golden record clusters | 3 rows ❌ | Full clustering run needed |
| Ecosystem tables | 874 built ✅ | Blocked on donor identity |
