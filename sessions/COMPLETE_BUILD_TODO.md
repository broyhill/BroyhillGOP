# COMPLETE DATABASE BUILD — MASTER TODO LIST
## BroyhillGOP Platform
**Created: April 10, 2026 10:50 PM EDT**
**Authority: Ed Broyhill | NC National Committeeman**
**Author: Perplexity (CEO)**

---

## READ BEFORE STARTING

This is the complete task list for building the BroyhillGOP political data platform from the ground up. Tasks are in STRICT ORDER. Do not skip ahead. Do not improvise. Do not guess column names. Read the data first.

**Required reading before touching any code:**
1. sessions/SESSION_START_READ_ME_FIRST.md
2. sessions/MASTER_RESET_AND_BUILD_PLAN.md
3. sessions/DONOR_DEDUP_PIPELINE_V2.md
4. sessions/SESSION_APRIL10_2026_EVENING.md

---

# PHASE A — FOUNDATION: DataTrust Voter File

The DataTrust 252-column voter file is the FOUNDATION of everything. It is a SUPERSET of the NC SBOE voter file. Do NOT download a separate SBOE voter file — DataTrust already contains everything SBOE has plus 185 additional columns. Loading SBOE separately and trying to bridge to DataTrust was tried before and caused confusion. Don't repeat that mistake.

## A1. Complete the VoterFile API download
- [ ] Verify VoterFile download completed on new server 37.27.169.232
- [ ] Check: `wc -l /data/datatrust/nc_voterfile_full.jsonl` — expect ~7.6M lines
- [ ] Check: `cat /data/datatrust/resume_offset.txt` — should show final offset
- [ ] If stalled or incomplete, restart from resume_offset using the pull script at `/data/datatrust/pull_voterfile.py`
- [ ] API auth trick: authenticate at `https://rncdhapi.azurewebsites.net/api/Authenticate`, then call data at `https://rncdatahubapi.gop/api/VoterFile`
- [ ] Token refreshes every 100 pages. Page size = 1000 rows.

## A2. Inspect the downloaded data
- [ ] Read the first 5 records: `head -5 /data/datatrust/nc_voterfile_full.jsonl | python3 -m json.tool`
- [ ] Count total columns: `head -1 /data/datatrust/nc_voterfile_full.jsonl | python3 -c "import json,sys; print(len(json.loads(sys.stdin.readline()).keys()))"`
- [ ] List ALL column names and save to file: `/data/datatrust/voterfile_columns.txt`
- [ ] Verify key columns exist: `RNCID`, `RNC_Regid`, `StateVoterID`, `LastName`, `FirstName`, `DOB_Year`, `DOB_Month`, `DOB_Day`, `Sex`, `RegisteredParty`, `RegHouseNum`, `RegStName`, `RegCity`, `RegZip5`, `RegLatitude`, `RegLongitude`, `CountyFIPS`, `CountyName`, `CongressionalDistrict`, `HouseholdID`, `CellPhone`, `LandLine`, `Email`
- [ ] Verify `StateVoterID` values look like NC ncid format
- [ ] Spot-check Ed Broyhill: search for LastName=BROYHILL, RegZip5=27104. Confirm his record exists with RNC_Regid populated.

## A3. Design the PostgreSQL table
- [ ] Map every JSON field to a PostgreSQL column with correct data type
- [ ] Use snake_case column names (e.g., `rnc_regid`, `state_voter_id`, `last_name`)
- [ ] Primary key: `rnc_regid` (UUID)
- [ ] Create indexes on: `state_voter_id`, `rncid`, `last_name + reg_zip5`, `reg_house_num + reg_zip5 + last_name`, `county_fips`, `congressional_district`, `state_leg_upper_district`, `state_leg_lower_district`, `household_id`
- [ ] Present CREATE TABLE DDL for review before executing
- [ ] Table name: `core.datatrust_voter_nc`

## A4. Load into PostgreSQL on new server
- [ ] Parse JSONL file and bulk insert using COPY or batch INSERT
- [ ] Verify row count matches JSONL line count
- [ ] Verify zero NULL `rnc_regid` values
- [ ] Verify zero NULL `state_voter_id` values
- [ ] Verify 100 distinct `county_name` values
- [ ] Spot-check Ed Broyhill record: all fields populated
- [ ] Run: `SELECT COUNT(*), COUNT(DISTINCT rnc_regid), COUNT(DISTINCT state_voter_id) FROM core.datatrust_voter_nc` — all three numbers should be equal

## A5. Verify the join chain works
- [ ] Confirm `state_voter_id` in DataTrust = `ncid` in NC voter rolls
- [ ] Confirm `rnc_regid` in DataTrust = `RNC_RegID` in Acxiom parquet
- [ ] Run test join: `SELECT COUNT(*) FROM core.datatrust_voter_nc dt JOIN acxiom a ON dt.rnc_regid = a.rnc_regid` — should match ~7.6M

---

# PHASE B — ACXIOM CONSUMER DATA

## B1. Inspect the Acxiom parquet file
- [ ] File is at `/data/acxiom/acxiom_nc_full.parquet` (7.8GB, 7,655,593 rows, 1,925 columns)
- [ ] Read column names: `python3 -c "import pyarrow.parquet as pq; f=pq.ParquetFile('/data/acxiom/acxiom_nc_full.parquet'); print(f.schema)"`
- [ ] Identify the join key column (should be `RNC_RegID` or `DT_RegID`)
- [ ] Sample 5 rows and inspect key behavioral columns: AP000595 (political writing), AP000649 (rally attendance), AP000655 (party work), AP001722 (fundraising), AP004359 (conservative views), AP006784 (Republican score 1-100)

## B2. Design the Acxiom table
- [ ] With 1,925 columns, consider JSONB approach: one row per person, JSONB columns for each data layer
- [ ] Option A: `rnc_regid UUID PK, state TEXT, market_indices JSONB, ibe JSONB, ap_models JSONB`
- [ ] Option B: Wide table with all 1,925 columns as individual fields
- [ ] Option C: Separate tables per layer (market, ibe, models) joined by rnc_regid
- [ ] Present decision to Ed for approval
- [ ] Key behavioral columns that will be queried frequently should be individual indexed columns regardless of approach

## B3. Load Acxiom into PostgreSQL
- [ ] Load parquet into the chosen schema
- [ ] Verify row count = 7,655,593
- [ ] Verify join to DataTrust: `SELECT COUNT(*) FROM acxiom a JOIN core.datatrust_voter_nc dt ON a.rnc_regid = dt.rnc_regid`
- [ ] Spot-check Ed Broyhill: find his RNC_RegID from DataTrust, pull his Acxiom record, verify behavioral scores populated

---

# PHASE C — RNC FACT TABLES

## C1. Pull FactInitiativeContacts (voter contact history)
- [ ] API: `GET https://rncdatahubapi.gop/api/FactInitiativeContacts?state=NC&top=1000&skip=0`
- [ ] This is every door knock, phone call, canvassing contact the RNC has made
- [ ] Includes VolunteerKey, OrganizationKey, ContactType, Disposition
- [ ] Save to `/data/rnc/initiative_contacts.jsonl`
- [ ] Load into `staging.rnc_initiative_contacts`

## C2. Pull FactInitiativeContactDetails
- [ ] API: `GET https://rncdatahubapi.gop/api/FactInitiativeContactDetails?state=NC&top=1000&skip=0`
- [ ] Question/answer details from each contact
- [ ] Save to `/data/rnc/initiative_contact_details.jsonl`
- [ ] Load into `staging.rnc_initiative_contact_details`

## C3. Pull Absentee ballot data
- [ ] API: `GET https://rncdatahubapi.gop/api/Absentee?state=NC&top=1000&skip=0`
- [ ] Ballot requested, mailed, returned, early voted, rejected, challenged
- [ ] Save to `/data/rnc/absentee.jsonl`
- [ ] Load into `staging.rnc_absentee`

## C4. Pull dimensional lookup tables
- [ ] DimElection: `GET https://rncdatahubapi.gop/api/DimElection`
- [ ] DimOrganization: `GET https://rncdatahubapi.gop/api/DimOrganization`
- [ ] DimTag: `GET https://rncdatahubapi.gop/api/DimTag`
- [ ] These are small reference tables — pull all at once

## C5. Pull Volunteers and VoterContacts
- [ ] API: `GET https://rncdatahubapi.gop/api/Volunteers?state=NC`
- [ ] API: `GET https://rncdatahubapi.gop/api/VoterContacts?state=NC`
- [ ] Save and load into staging tables

---

# PHASE D — CLEAN NCBOE DONOR DATA LOAD

**WARNING: THIS IS WHERE 13 CONTAMINATION INCIDENTS OCCURRED. READ EVERY WORD.**

## D0. Understand what you're dealing with

### NCBOE file format
- **Name field is LAST NAME FIRST**: "ED BROYHILL" not "BROYHILL, ED"
- But it's a SINGLE field called `Name` — not split into first/last
- The name field contains the FULL name as one string: "ED BROYHILL", "JAMES EDGAR BROYHILL", "JAMES EDGAR 'ED' BROYHILL"
- Sometimes mixed case: "Ed Broyhill" vs "ED BROYHILL"
- You must PARSE this field to extract first name and last name
- The LAST word is almost always the last name, BUT watch for suffixes: "JAMES T BROYHILL JR" — last name is BROYHILL, not JR

### NCBOE columns (from the GOLD files)
```
Name, Street Line 1, Street Line 2, City, State, Zip Code, 
Profession/Job Title, Employer's Name/Specific Field, 
Transaction Type, Committee Name, Committee SBoE ID, 
Committee Street 1, Committee Street 2, Committee City, 
Committee State, Committee Zip Code, Report Name, 
Date Occurred, Account Code, Amount, Form of Payment, 
Purpose, Candidate/Referendum Name, Declaration
```

### The 11-year data challenge (2015-2026)
You are looking at 11 years of donation records filed by hand by campaign treasurers across 100 counties. The data is DIRTY:

**Name variations for ONE person (Ed Broyhill):**
- ED BROYHILL
- Ed Broyhill
- JAMES EDGAR BROYHILL
- JAMES EDGAR 'ED' BROYHILL
- J BROYHILL

**Address variations for ONE person:**
- 525 N HAWTHORNE ROAD
- 525 N Hawthorne Rd
- 525 N. HAWTHORNE ROAD
- 525 HAWTHORNE ROAD (missing N)
- 202 NORTH HAWTHORNE RD (office address)
- PO BOX 500
- 42 PARK BLVD.
- 800 Hickory Blvd SW
- 1930 VIRGINIA ROAD (parents' home)

**Employer variations for ONE person:**
- ANVIL VENTURE GROUP
- ANVIL VENTURES
- ANVIL VENTURE
- ANVIL MANAGEMENT LLC
- ANVILE VENTURE (typo)
- Anvil Venture (case)
- BROYHILL GROUP
- BROYHILL GROUP/ANVILL VENTURE GROUP (typo + combined)
- BROYHILL INVESTMENTS
- Broyhill Asset Management
- SENATOR
- No Employer

**Zip code variations:** 27104, 27104-3224, blank

**The RETIRED problem:** A CEO in 2016 who is retired in 2024. Both filings are the same person but employer field changes from company name to "RETIRED".

**The second home problem:** Major donors file from home, office, beach house, mountain house, Florida condo. 5 different addresses, 5 different address numbers.

**The deceased problem:** 28-41% of donors over 11 years are now dead, moved, divorced, or remarried. They won't match the current voter file.

**The major donor irony:** The most valuable donors have the MOST variations because they donate the MOST frequently. High variation count = high-value donor, not bad data.

**Duplicate rows:** Some records appear duplicated 4-6 times. Check the file before loading.

**Blank names:** Some records have amounts and committees but NO contributor name. These are unitemized aggregate donations below the reporting threshold. Skip for identity matching but keep for committee totals.

## D1. Transfer files from Ed's laptop to new server
- [ ] Ed provides 18 GOLD NCBOE files (see MASTER_FILE_MANIFEST.md for exact filenames)
- [ ] Transfer via SCP or SFTP to `/data/ncboe/gold/` on 37.27.169.232
- [ ] Verify each file: filename, row count, sample first 5 rows
- [ ] Ed must confirm each file: **"I authorize this action"**

## D2. TRUNCATE contaminated data
- [ ] On Supabase: `TRUNCATE TABLE public.nc_boe_donations_raw;`
- [ ] Ed must authorize this specific action
- [ ] Verify: `SELECT COUNT(*) FROM public.nc_boe_donations_raw` = 0

## D3. Load GOLD files into raw staging table
- [ ] Create `/data/ncboe/gold_combined.csv` by concatenating all 18 files (preserving headers from first file only)
- [ ] Verify combined row count
- [ ] Load into `raw.ncboe_donations` on new server PostgreSQL (NOT Supabase yet)
- [ ] Verify row count matches

## D4. Normalize and parse the NCBOE data
- [ ] **Parse Name field**: Split "ED BROYHILL" into first_name="ED", last_name="BROYHILL"
  - Handle suffixes: JR, SR, II, III, IV → store in suffix field, don't include in last_name
  - Handle middle names: "JAMES EDGAR BROYHILL" → first="JAMES", middle="EDGAR", last="BROYHILL"
  - Handle nicknames in quotes: "JAMES EDGAR 'ED' BROYHILL" → first="JAMES", middle="EDGAR", nickname="ED", last="BROYHILL"
  - Handle initials: "J BROYHILL" → first="J", last="BROYHILL"
  - Handle prefixes: DR, REV, MR, MRS, MS → store in prefix field
  - **BLANK names → flag as UNITEMIZED, skip identity matching**
- [ ] **Normalize addresses**: Uppercase all, strip extra spaces, standardize ST/STREET, RD/ROAD, DR/DRIVE, BLVD/BOULEVARD, AVE/AVENUE, N/NORTH, S/SOUTH, E/EAST, W/WEST
- [ ] **Extract ALL address numbers** from Street Line 1 AND Street Line 2 — house numbers, PO Box numbers, highway numbers, suite numbers, floor numbers, rural route numbers
- [ ] **Normalize zip**: Take first 5 digits only (27104-3224 → 27104), handle blanks
- [ ] **Normalize employer**: Uppercase, strip INC/LLC/CORP/CO, use employer_sic_master for canonical mapping where available
- [ ] **Normalize city**: Uppercase, handle "WINSTON-SALEM" vs "WINSTON SALEM"
- [ ] **Parse date**: "06/28/2016" → proper DATE type
- [ ] **Normalize amount**: Ensure numeric, handle "1000.0000" → 1000.00
- [ ] **Add computed columns**: norm_last, norm_first, norm_zip5, norm_city, norm_employer, address_numbers (array), year_donated
- [ ] Output to: `norm.ncboe_donations` on new server

## D5. Internal dedup (Stage 1 of DONOR_DEDUP_PIPELINE_V2.md)
- [ ] **Process 2026 → 2015** (sort by Date Occurred descending)
- [ ] Run Stage 1A: Exact last name + first name + zip5 clustering
- [ ] Run Stage 1B: Employer + last name + city clustering
- [ ] Run Stage 1C: Committee loyalty fingerprint (same committee pattern over years)
- [ ] Run Stage 1D: Collect ALL address numbers per cluster
- [ ] Run Stage 1E: Collect ALL name variants per cluster (from actual filings, NOT nickname tables)
- [ ] Run Stage 1F: Collect ALL employers per cluster (across all years)
- [ ] Run Stage 1G: Collect ALL complete addresses per cluster (including second homes)
- [ ] Output: `staging.ncboe_donor_clusters` — one row per unique person with arrays of variants
- [ ] Report: total input rows → total unique clusters. Expect significant reduction.

## D6. Match NCBOE clusters to DataTrust voter file (Stage 2)
- [ ] **Pass 1: DOB + Sex + Last Name + Zip** (if DOB available from Acxiom/DataTrust enrichment)
- [ ] **Pass 2: Any address number + Last Name + Zip** against DataTrust `reg_house_num`
- [ ] **Pass 3: Normalized employer + Last Name + City** — critical for major donors
- [ ] **Pass 4: Committee loyalty fingerprint + Last Name + Zip**
- [ ] **Pass 5: All name variants + Last Name + City** (no nickname tables — use actual filing names)
- [ ] **Pass 6: Geocode proximity** (DataTrust lat/long within 100m + last name match)
- [ ] **Pass 7: Household matching** (DataTrust HouseholdID — catches spouses at same address)
- [ ] After each pass, remove matched clusters from subsequent passes
- [ ] Output: `staging.ncboe_donor_matched` with rnc_regid linkage
- [ ] Output: `staging.ncboe_donor_unmatched` — Track 2, scored on donation history
- [ ] Report: match rate per pass, total matched, total unmatched

## D7. Verify NCBOE matching results
- [ ] Spot-check Ed Broyhill: ALL name variants should resolve to ONE rnc_regid
- [ ] Spot-check Art Pope: ARTHUR/ART/JAMES/JAMES A./JAMES ARTHUR → ONE rnc_regid
- [ ] Spot-check Jay Faison: JAY/JAMES → ONE rnc_regid
- [ ] Spot-check Fred Eshelman: FRED/FREDERICK/FREDRIC/FREDERIC → ONE rnc_regid
- [ ] Check for false merges: two different people collapsed into one cluster
- [ ] Report top 20 clusters by total dollars with their name variant arrays

---

# PHASE E — FEC FEDERAL DONOR DATA LOAD

## E0. Understand FEC file format

### FEC name field is DIFFERENT from NCBOE
- **FEC format: LAST, FIRST MIDDLE** — e.g., "BROYHILL, JAMES EDGAR"
- **NCBOE format: FIRST LAST** — e.g., "ED BROYHILL"
- These are OPPOSITE formats. The parser must handle both.
- FEC uses a COMMA to separate last name from first name
- Some FEC records have no comma: "ED BROYHILL" (filed incorrectly)
- Some have suffixes after the first name: "BROYHILL, JAMES EDGAR JR"

### FEC columns (standard FEC individual contributions format)
```
committee_id, committee_name, report_year, report_type, image_num,
transaction_type, entity_type, contributor_name, contributor_city,
contributor_state, contributor_zip, contributor_employer,
contributor_occupation, contribution_receipt_date,
contribution_receipt_amount, receipt_type, memo_text, etc.
```

### FEC-specific challenges
- **National scope**: FEC files contain donors from ALL states, not just NC. Filter to NC donors only (contributor_state = 'NC') but ALSO keep out-of-state donors who give to NC Republican candidates (they go to a separate holding table per Ed's instruction).
- **Committee IDs**: FEC uses federal committee IDs (C00XXXXXX format) — different from NCBOE SBoE IDs
- **Amount field**: Can be negative (refunds/redesignations). Keep negatives — they affect totals.
- **Memo transactions**: Some rows are memo/earmark pass-throughs. Be careful not to double-count.

## E1. Transfer FEC files from Ed's laptop
- [ ] Ed provides 14 locked FEC files from `/Users/Broyhill/Desktop/AAA FEC Federal Pres Senate House/`
- [ ] Transfer to `/data/fec/` on new server
- [ ] Verify each file: filename, row count, sample first 5 rows
- [ ] Ed must authorize each file

## E2. Load FEC into raw staging
- [ ] Load into `raw.fec_donations` on new server
- [ ] Verify row count — expect ~779K for current locked set
- [ ] Check: no Democrat candidate committees mixed in (reference nc_republican_federal_candidates_2015_2026.csv and gop_presidential_committees_2016_2024.csv)

## E3. Normalize and parse FEC data
- [ ] **Parse Name field** (DIFFERENT from NCBOE):
  - Standard format: "BROYHILL, JAMES EDGAR" → last="BROYHILL", first="JAMES", middle="EDGAR"
  - Handle comma-separated: split on first comma
  - Handle no-comma format: "ED BROYHILL" → last word = last name (same as NCBOE logic)
  - Handle suffixes: "BROYHILL, JAMES EDGAR JR" → suffix="JR"
  - Handle titles: "DR", "REV", "MR", "MRS" → prefix field
  - **BLANK names → flag as UNITEMIZED**
- [ ] **Normalize addresses, employers, zips** — same rules as NCBOE (D4)
- [ ] **Extract address numbers** from contributor address fields
- [ ] **Filter NC donors**: contributor_state = 'NC' → main pipeline
- [ ] **Out-of-state donors to NC Republican candidates**: → `staging.fec_outofstate_donors` (store safely, don't delete)
- [ ] **Add computed columns**: norm_last, norm_first, norm_zip5, norm_city, norm_employer, address_numbers array, year_donated
- [ ] Output to: `norm.fec_donations`

## E4. Internal dedup (same Stage 1 process as NCBOE)
- [ ] Process 2026 → 2015
- [ ] All 7 clustering stages (1A through 1G)
- [ ] Output: `staging.fec_donor_clusters`

## E5. Cross-reference FEC clusters with NCBOE clusters
- [ ] **This is Pass 4 of the matching pipeline** — if the same person appears in BOTH FEC and NCBOE, that's 98% confidence
- [ ] Match on: last_name + city + any overlapping employer or address number
- [ ] Merge FEC and NCBOE clusters for the same person into unified donor clusters
- [ ] Output: `staging.unified_donor_clusters`

## E6. Match unified clusters to DataTrust voter file
- [ ] Same 8-pass process as D6 but now with richer data (FEC + NCBOE combined)
- [ ] More address numbers, more employer variants, more name variants per cluster
- [ ] Higher match rate expected because of cross-source confirmation
- [ ] Output: `staging.fec_donor_matched`, `staging.fec_donor_unmatched`

## E7. Verify FEC matching results
- [ ] Same spot-checks as D7
- [ ] Verify no Democrat candidates slipped through
- [ ] Check total dollars — should make sense relative to known NC Republican federal fundraising

---

# PHASE F — BUILD THE UNIFIED PERSON SPINE

## F1. Create the new spine table
- [ ] Primary key: `rnc_regid` (UUID) — from DataTrust
- [ ] Every active NC voter from DataTrust gets a row (not just donors)
- [ ] Include ALL DataTrust columns (demographics, districts, addresses, voting history, modeled scores)
- [ ] Add donor aggregate columns: total_contributed, contribution_count, first_contribution, last_contribution, max_single_gift, avg_gift, donation_years_active
- [ ] Add volunteer columns: volunteer_level, activism_score, is_volunteer, volunteer_hours, skills array
- [ ] Add party officer columns: is_party_officer, is_convention_delegate, is_hall_of_fame, party_positions array
- [ ] Add officeholder columns: is_officeholder, is_candidate, current_office, office_level, office_start_date, office_end_date
- [ ] Add honorific columns: honorific, formal_salutation, correspondence_greeting, title_source, title_priority
- [ ] Add contact columns: cell_phone, landline, email, tcpa_compliant
- [ ] Add SIC/NAICS columns: sic_codes array, naics_codes array, industry_sectors array, all_employers array
- [ ] Add address columns: primary_address, all_addresses array (includes second homes, office, PO boxes)
- [ ] Add household columns: household_id, household_total_contributed, spouse_rnc_regid, household_members array
- [ ] Add matching metadata: match_source (which pass matched them), match_confidence, name_variants array
- [ ] Table name: `core.person_spine_v2`

## F2. Populate from DataTrust voter data
- [ ] INSERT INTO core.person_spine_v2 SELECT all voter columns FROM core.datatrust_voter_nc
- [ ] All 7.6M+ NC voters get a row — donors and non-donors alike
- [ ] Verify row count matches DataTrust source

## F3. Link Acxiom behavioral data
- [ ] Join by rnc_regid to populate Acxiom behavioral scores
- [ ] Key scores to populate: political activism propensity, fundraising likelihood, conservative ideology, Republican affiliation, influencer score

## F4. Link matched NCBOE donors
- [ ] For each matched NCBOE donor cluster → UPDATE the corresponding spine row with donation aggregates
- [ ] Compute: total_contributed, contribution_count, first/last/max/avg gift from NCBOE data
- [ ] Store all name variants and addresses from NCBOE in the variant arrays
- [ ] Store all employers and SIC codes

## F5. Link matched FEC donors
- [ ] Same as F4 but for FEC data
- [ ] ADD to existing totals (don't overwrite — a person may be in both NCBOE and FEC)
- [ ] total_contributed = NCBOE total + FEC total
- [ ] Merge name/address/employer variants from FEC into existing arrays

## F6. Build contribution map
- [ ] `core.contribution_map_v2` — one row per donation transaction
- [ ] Columns: rnc_regid (FK to spine), source_system (NCBOE/FEC/WINRED/NCGOP), amount, date, committee_id, committee_name, candidate_name, source_file, original_name, original_address
- [ ] Every donation links to the spine via rnc_regid
- [ ] Verify: SUM(amount) per person matches spine total_contributed

## F7. Apply donation level separation
- [ ] Federal: FEC donations to House, Senate, Presidential committees
- [ ] State: NCBOE donations to Governor, Lt Gov, Council of State, NC Senate, NC House
- [ ] Judicial: Supreme Court, Court of Appeals, Superior Court, District Court
- [ ] County/Local: Sheriff, Commissioner, Mayor, City Council, School Board, DA, Clerk
- [ ] Party: NCGOP, RNC, county parties, Republican Women, Young Republicans, affiliates
- [ ] Add columns: federal_total, state_total, judicial_total, county_total, party_total

## F8. Verify the canary
- [ ] Ed Broyhill (find by last_name=BROYHILL, reg_zip5=27104, first name variant containing ED or EDGAR)
- [ ] Total should approach $857K-$1M when all sources are loaded
- [ ] All name variants resolved to ONE rnc_regid
- [ ] All addresses captured (home, office, PO Box, etc.)
- [ ] All employers captured across 11 years
- [ ] Honorific = "Committeeman"
- [ ] is_party_officer = true
- [ ] is_convention_delegate = true
- [ ] is_hall_of_fame = true

---

# PHASE G — COMMITTEE AND CANDIDATE REGISTRY

## G1. Load committee reference data
- [ ] Restore committee_party_map from Supabase backup (as CSV)
- [ ] Load nc_republican_federal_candidates_2015_2026.csv (138 federal R candidates)
- [ ] Load gop_presidential_committees_2016_2024.csv (26 presidential committees)
- [ ] Load SBOE committee master from Supabase backup

## G2. Classify remaining UNKNOWN committees
- [ ] Any committee receiving donations from Republican donors should be investigated
- [ ] PAC money goes to HOLD — not automatically Republican
- [ ] Cross-reference with NCBOE candidate listings
- [ ] Report remaining unknowns for Ed's manual classification

## G3. Link committees to candidates
- [ ] Every committee should map to a candidate or party organization
- [ ] Populate committee_type: candidate, party, PAC, leadership, inaugural, other

---

# PHASE H — VOLUNTEER ECOSYSTEM

## H1. Create volunteer schema tables
- [ ] person_volunteer_profile (FK to spine via rnc_regid)
- [ ] party_organization (NCGOP + 100 counties + 8 affiliates)
- [ ] party_officer (who holds what position)
- [ ] volunteer_activity (individual events, hours, candidate benefited)
- [ ] candidate_volunteer_match (scoring engine)

## H2. Seed party organizations
- [ ] NCGOP state party
- [ ] All 100 county Republican parties
- [ ] NC Federation of Republican Women (state + county chapters)
- [ ] NC Federation of Young Republicans
- [ ] NC Teenage Republicans
- [ ] NC Federation of College Republicans
- [ ] NC Federation of Republican Men
- [ ] Republican National Hispanic Assembly-NC
- [ ] Frederick Douglass Foundation of NC
- [ ] District and County Officers Association (NCDCOA)

## H3. Import RNC volunteer contact history
- [ ] Load FactInitiativeContacts from Phase C into volunteer activity records
- [ ] Link to spine by rnc_regid

## H4. Flag volunteer prospects
- [ ] Donors with total < $500 = volunteer prospects
- [ ] Donors to party-affiliated committees (Republican Women, Young Republicans, county parties) = volunteer + donor
- [ ] Acxiom scores: AP000649 (rally), AP000655 (party work), AP001722 (fundraising), AP004330 (worked for candidate) — high scores = volunteer prospects regardless of donation amount

## H5. Tag officeholders
- [ ] Match spine records to candidate_profiles for current/former officeholders
- [ ] Set is_officeholder, current_office, office_level
- [ ] These are lifetime tags — former officials keep the flag

---

# PHASE I — HONORIFIC SYSTEM

## I1. Apply titles from officeholder data
- [ ] Senators, Representatives, Governors, Judges, Sheriffs, Mayors, Commissioners, DAs
- [ ] Military ranks from DataTrust or Acxiom veteran indicators
- [ ] Clergy from employer/occupation fields (PASTOR, REVEREND, BISHOP, CHAPLAIN)
- [ ] Tribal leaders from organizational affiliations
- [ ] Party officers (Chairman, Committeeman, Vice Chair)
- [ ] Dr. from occupation/profession fields

## I2. Set correspondence fields
- [ ] formal_salutation: "The Honorable Penn Broyhill" / "General John Smith, USA (Ret.)"
- [ ] correspondence_greeting: "Dear Judge Broyhill" / "Dear Senator Tillis" / "Dear Committeeman Broyhill"
- [ ] NEVER use Mr./Mrs. for a titled person
- [ ] Mrs. only if married status confirmed, Ms. if unknown
- [ ] Titles are for LIFE — former Senator = always Senator

---

# PHASE J — MICROSEGMENTATION

## J1. Apply SIC/NAICS codes from employer history
- [ ] Every employer variant across 11 years → SIC/NAICS lookup
- [ ] Use employer_sic_master (62,100 mappings) + extend as new employers appear
- [ ] One person can have MULTIPLE SIC codes (real estate + venture capital + asset management)
- [ ] Store as arrays on the spine: sic_codes[], naics_codes[], industry_sectors[]

## J2. Build microsegment query capability
- [ ] Enable queries like: "All donors in SIC 8211 (education) in Wake County with activism_score > 70"
- [ ] Enable: "All donors who gave to judicial candidates in the last 2 years who are lawyers"
- [ ] Enable: "All veterans in District 5 with turnout_score > 80"
- [ ] Enable: "All employees of Bank of America who donate to Republican candidates"

## J3. Household aggregation
- [ ] Group by DataTrust HouseholdID
- [ ] Compute household_total_contributed
- [ ] Tag spouse relationships using household membership + suffix
- [ ] Build household profile alongside individual profiles

---

# PHASE K — MIGRATE TO PRODUCTION

## K1. Final verification
- [ ] Canary check: Ed Broyhill record correct across all dimensions
- [ ] Top 50 donors spot-checked
- [ ] Committee classifications complete
- [ ] Honorifics applied to all titled persons
- [ ] Volunteer profiles populated
- [ ] Microsegments queryable
- [ ] Household totals computed

## K2. Back up everything
- [ ] Full pg_dump of new server database
- [ ] Store backup on separate disk/volume
- [ ] Document restore procedure

## K3. Decommission old infrastructure
- [ ] Migrate relay from 5.9.99.109 to new server (if needed)
- [ ] Respond to Hetzner abuse report
- [ ] Consider decommissioning old Hetzner servers after migration complete

---

# CRITICAL REMINDERS (post on your wall)

1. **ED = EDGAR, not EDWARD**
2. **DataTrust IS the voter file** — don't load SBOE separately
3. **NCBOE name field = FIRST LAST** ("ED BROYHILL")
4. **FEC name field = LAST, FIRST** ("BROYHILL, JAMES EDGAR")
5. **Process 2026 → 2015** (reverse chronological)
6. **DOB + Sex is the top match filter**
7. **No nickname lookup tables** — use actual name variants from filing history
8. **75% of major donors file from business address** — employer is the bridge, not address
9. **Address numbers = house, PO box, highway, suite, floor, rural route** — not just house numbers
10. **Every donor matters equally** — $100 today = $25,000 in 10 years
11. **Low-dollar donors = volunteer prospects**
12. **Never drop unmatched donors**
13. **Store ALL addresses including second homes**
14. **Titles are for life** — never Mr./Mrs. a titled person
15. **Two-phase protocol**: DRY RUN → Ed authorizes → EXECUTE
16. **This database has been corrupted 13 times.** Do not become #14.

---

*Created by Perplexity (CEO) at Ed Broyhill's direction, April 10, 2026*
*Do not modify without Ed's authorization.*
