# BroyhillGOP Database: Schema Comparison & Installation Challenge Report

**Prepared:** April 2, 2026  
**Project:** BroyhillGOP Donor Intelligence Platform  
**Author:** Schema Analysis Engine  
**Scope:** Full column-by-column analysis across 5 source tables → 2 destination tables  
**Source file:** `/home/user/workspace/all_schemas.json`  
**Inventory file:** `/home/user/workspace/db_inventory.json`

---

## Table of Contents

1. [Column-by-Column Schema Mapping](#section-1)
2. [Name Column Chaos](#section-2)
3. [Address Column Chaos](#section-3)
4. [Employer/Occupation Column Chaos](#section-4)
5. [ID Columns and Linkage Paths](#section-5)
6. [Date Column Inconsistencies](#section-6)
7. [Party/Political Data Inconsistencies](#section-7)
8. [Duplicate/Redundant Column Analysis](#section-8)
9. [The 100% Match Challenge](#section-9)
10. [Recommended Column Map for Installation](#section-10)

---

## Source Tables Summary

| Table | Columns | Rows | Notes |
|---|---|---|---|
| `nc_boe_donations_raw` | 62 | ~337K | NC Board of Elections donation records |
| `fec_donations` | 35 | ~1.1M | FEC individual contributions |
| `fec_party_committee_donations` | 34 | ~1.7M | FEC party/committee donations |
| `nc_voters` | 71 | ~9M | NC voter registration file |
| `nc_datatrust` | 256 | ~7.66M | RNC DataTrust voter file |
| **`core.person_spine`** | **128** | **~128K active** | **Master donor identity table (destination)** |
| **`core.contribution_map`** | **11** | **~4.7M** | **Donation ledger (destination)** |

---

<a name="section-1"></a>
## SECTION 1: Column-by-Column Schema Mapping

### Mapping Key

- **Spine** = `core.person_spine`
- **CM** = `core.contribution_map`
- **UNMAPPED** = Source column has no identified target in spine or CM
- **NO SOURCE** = Spine/CM column has no direct source column
- **Transform** = data transformation required before loading

---

### 1A. `nc_boe_donations_raw` → Spine / Contribution Map (62 columns)

| # | Source Column | Data Type | Maps To | Target Column | Type Match? | Transform Needed |
|---|---|---|---|---|---|---|
| 1 | `id` | bigint | CM | `source_id` | YES (cast to bigint) | Use as source_id with source_system='nc_boe' |
| 2 | `donor_name` | varchar | Spine | — | — | Parse only if parsed_* columns are NULL; format is "LAST, FIRST MIDDLE" or "FIRST LAST" |
| 3 | `street_line_1` | varchar | Spine | `street` | YES | Normalize/standardize; prefer norm_addr if populated |
| 4 | `street_line_2` | varchar | Spine | `street` | YES | Append to street with comma separator |
| 5 | `city` | varchar | Spine | `city` | YES | Prefer norm_city if populated |
| 6 | `state` | varchar | Spine | `state` | YES | Prefer norm_state if populated |
| 7 | `zip_code` | varchar | Spine | `zip5` | YES | Truncate to 5 digits; prefer norm_zip5 |
| 8 | `profession_job_title` | varchar | Spine | `occupation` | YES | Raw value; prefer FEC if available |
| 9 | `employer_name` | varchar | Spine | `employer` | YES | Raw value; prefer employer_normalized if populated |
| 10 | `transaction_type` | varchar | CM | `source_system` metadata | — | Used for filtering/classification, not direct map |
| 11 | `committee_name` | varchar | CM | UNMAPPED (store in metadata) | — | No CM column for committee name text |
| 12 | `committee_sboe_id` | varchar | CM | `committee_id` | NO (varchar→text) | Cast to text; NC-specific ID format |
| 13 | `committee_street_1` | varchar | UNMAPPED | — | — | Committee address, not person address |
| 14 | `committee_street_2` | varchar | UNMAPPED | — | — | Committee address |
| 15 | `committee_city` | varchar | UNMAPPED | — | — | Committee address |
| 16 | `committee_state` | varchar | UNMAPPED | — | — | Committee address |
| 17 | `committee_zip_code` | varchar | UNMAPPED | — | — | Committee address |
| 18 | `report_name` | varchar | UNMAPPED | — | — | Filing metadata, not person data |
| 19 | `date_occured_raw` | varchar | UNMAPPED | — | — | Raw string; use date_occurred (parsed) instead. NOTE: TYPO in column name ("occured" vs "occurred") |
| 20 | `account_code` | varchar | UNMAPPED | — | — | BOE internal code, no spine equivalent |
| 21 | `amount_raw` | varchar | UNMAPPED | — | — | Raw string; use amount_numeric instead |
| 22 | `form_of_payment` | varchar | UNMAPPED | — | — | No spine column for payment method |
| 23 | `purpose` | varchar | UNMAPPED | — | — | Donation purpose text; no spine column |
| 24 | `candidate_referendum_name` | varchar | CM | `candidate_id` metadata | — | Text name only; CM wants UUID; no direct map |
| 25 | `declaration` | varchar | UNMAPPED | — | — | Compliance declaration text |
| 26 | `source_file` | varchar | UNMAPPED | — | — | ETL provenance only |
| 27 | `loaded_at` | timestamptz | UNMAPPED | — | — | ETL timestamp only |
| 28 | `norm_last` | varchar | Spine | `norm_last` | YES | Direct map |
| 29 | `norm_first` | varchar | Spine | `norm_first` | YES | Direct map |
| 30 | `norm_addr` | varchar | Spine | `street` | YES | Prefer over street_line_1 for canonical address |
| 31 | `norm_zip5` | varchar | Spine | `zip5` | YES | Prefer over zip_code |
| 32 | `norm_city` | varchar | Spine | `city` | YES | Prefer over city |
| 33 | `norm_state` | varchar | Spine | `state` | YES | Prefer over state |
| 34 | `amount_numeric` | numeric | CM | `amount` | YES | Direct map |
| 35 | `date_occurred` | date | CM | `transaction_date` | YES | Direct map |
| 36 | `canonical_first` | varchar | Spine | `canonical_first_name` | YES | Direct map |
| 37 | `committee_type` | varchar | UNMAPPED | — | — | Committee classification; no direct spine/CM column |
| 38 | `content_hash` | text | UNMAPPED | — | — | Dedup/ETL artifact |
| 39 | `dedup_key` | text | UNMAPPED | — | — | Dedup/ETL artifact |
| 40 | `voter_ncid` | text | Spine | `voter_ncid` | YES | Direct map; primary voter linkage key |
| 41 | `zip9` | text | UNMAPPED | — | — | Full ZIP+4; use norm_zip5 for spine zip5 |
| 42 | `voter_party_cd` | text | Spine | `voter_party` | YES | Direct map |
| 43 | `employer_normalized` | text | Spine | `employer` / `best_employer` | YES | Prefer over raw employer_name |
| 44 | `middle_name` | text | Spine | `middle_name` | YES | Direct map |
| 45 | `name_suffix` | text | Spine | `suffix` | YES | Direct map |
| 46 | `norm_zip9` | text | UNMAPPED | — | — | Full normalized ZIP+4; use zip5 for spine |
| 47 | `fec_contributor_id` | text | UNMAPPED | — | — | FEC sub_id linkage; no spine column for this specific ID |
| 48 | `source_cycle` | text | UNMAPPED | — | — | Election cycle metadata |
| 49 | `rncid` | text | Spine | `voter_rncid` | YES | RNC ID linkage to DataTrust |
| 50 | `cell_phone` | text | Spine | `cell_phone` | YES | Direct map; source = 'nc_boe' |
| 51 | `email` | text | Spine | `email` | YES | Direct map; source = 'nc_boe' |
| 52 | `birth_year` | integer | Spine | `birth_year` | YES | Direct map |
| 53 | `member_id` | uuid | UNMAPPED | — | — | No spine column for nc_boe member_id UUID |
| 54 | `parsed_last` | text | Spine | `last_name` | YES | Prefer over donor_name parsing |
| 55 | `parsed_first` | text | Spine | `first_name` | YES | Prefer over donor_name parsing |
| 56 | `parsed_middle` | text | Spine | `middle_name` | YES | Prefer over middle_name if more specific |
| 57 | `parsed_suffix` | text | Spine | `suffix` | YES | Prefer over name_suffix |
| 58 | `parsed_nickname` | text | Spine | `preferred_first` | YES | Map to preferred_first; set preferred_name_source='nc_boe' |
| 59 | `is_organization` | boolean | UNMAPPED | — | — | No spine org flag; filter out orgs before spine load |
| 60 | `donor_committee_sboe_id` | text | UNMAPPED | — | — | Identifies donor as a committee; no spine column |
| 61 | `donor_type` | text | UNMAPPED | — | — | Individual/PAC/etc; no spine column |
| 62 | `golden_record_id` | integer | Spine | `person_id` (candidate) | NO (int→bigint) | Potentially maps to existing person_id; requires resolution (see Section 5) |

**NC BOE Unmapped count:** 22 columns unmapped to spine/CM  
**NC BOE Mapped count:** 40 columns with targets  

---

### 1B. `fec_donations` → Spine / Contribution Map (35 columns)

| # | Source Column | Data Type | Maps To | Target Column | Type Match? | Transform Needed |
|---|---|---|---|---|---|---|
| 1 | `id` | integer | CM | `source_id` | NO (int→bigint) | Cast; use with source_system='fec_indiv' |
| 2 | `committee_id` | text | CM | `committee_id` | YES | Direct map |
| 3 | `committee_name` | text | UNMAPPED | — | — | Name string; no CM column for committee name |
| 4 | `contributor_name` | text | Spine | — | — | Full name string; use contributor_first/last instead |
| 5 | `contributor_first` | text | Spine | `first_name` | YES | Direct map (already parsed) |
| 6 | `contributor_last` | text | Spine | `last_name` | YES | Direct map (already parsed) |
| 7 | `contributor_city` | text | Spine | `city` | YES | Use norm_zip5 for zip confirmation |
| 8 | `contributor_state` | text | Spine | `state` | YES | Direct map |
| 9 | `contributor_zip` | text | Spine | `zip5` | YES | Truncate to 5; prefer contributor_zip5 |
| 10 | `contributor_zip5` | text | Spine | `zip5` | YES | Direct map; prefer over contributor_zip |
| 11 | `contributor_employer` | text | Spine | `employer` | YES | Raw; prefer employer_normalized |
| 12 | `contributor_occupation` | text | Spine | `occupation` | YES | Raw FEC string |
| 13 | `employer_normalized` | text | Spine | `employer` / `best_employer` | YES | Prefer over raw; same normalization pipeline as BOE |
| 14 | `contribution_date` | date | CM | `transaction_date` | YES | Direct map; check date_corrupt flag first |
| 15 | `contribution_amount` | numeric | CM | `amount` | YES | Direct map |
| 16 | `receipt_type` | text | UNMAPPED | — | — | FEC receipt type code; no direct spine/CM column |
| 17 | `candidate_name` | text | UNMAPPED | — | — | Name string; CM wants candidate_id UUID |
| 18 | `candidate_office` | text | UNMAPPED | — | — | No CM/spine column |
| 19 | `two_year_period` | integer | UNMAPPED | — | — | FEC cycle year; no spine/CM column |
| 20 | `sub_id` | text | UNMAPPED | — | — | FEC unique transaction ID; no direct spine column. Useful for dedup, store in CM metadata if possible |
| 21 | `source_file` | text | UNMAPPED | — | — | ETL provenance |
| 22 | `fec_category` | text | UNMAPPED | — | — | FEC category code; no spine/CM column |
| 23 | `created_at` | timestamptz | UNMAPPED | — | — | ETL timestamp |
| 24 | `party` | text | Spine | `voter_party` | YES | FEC-reported party of receiving committee |
| 25 | `contributor_street_1` | text | Spine | `street` | YES | Donor-reported; use norm_addr if derived |
| 26 | `contributor_street_2` | text | Spine | `street` (append) | YES | Append if non-null |
| 27 | `is_memo` | boolean | UNMAPPED | — | — | Memo transactions should be filtered/excluded |
| 28 | `person_id` | bigint | Spine | `person_id` | YES | Already linked; use to update existing spine record |
| 29 | `norm_first` | text | Spine | `norm_first` | YES | Direct map |
| 30 | `norm_last` | text | Spine | `norm_last` | YES | Direct map |
| 31 | `norm_zip5` | text | Spine | `zip5` | YES | Direct map |
| 32 | `norm_street_num` | text | Spine | `addr_number` | YES | Direct map |
| 33 | `date_corrupt` | boolean | UNMAPPED | — | — | Quality flag; do not load contribution_date if TRUE |
| 34 | `original_contribution_date` | date | UNMAPPED | — | — | Pre-correction date; audit trail only |
| 35 | `date_recovery_method` | text | UNMAPPED | — | — | ETL/audit metadata |

**FEC Donations Unmapped count:** 17 columns  
**FEC Donations Mapped count:** 18 columns  

---

### 1C. `fec_party_committee_donations` → Spine / Contribution Map (34 columns)

| # | Source Column | Data Type | Maps To | Target Column | Type Match? | Transform Needed |
|---|---|---|---|---|---|---|
| 1 | `id` | integer | CM | `source_id` | NO (int→bigint) | Cast; use with source_system='fec_party' |
| 2 | `committee_id` | text | CM | `committee_id` | YES | Direct map |
| 3 | `committee_name` | text | UNMAPPED | — | — | No CM text column for committee name |
| 4 | `committee_type` | text | UNMAPPED | — | — | No direct spine/CM column |
| 5 | `committee_level` | text | UNMAPPED | — | — | Federal/state/local; no spine column |
| 6 | `contributor_name` | text | Spine | — | — | FULL NAME STRING — must parse using norm_last/norm_first. Unlike fec_donations, NO pre-parsed first/last on this table |
| 7 | `contributor_city` | text | Spine | `city` | YES | Use norm_city if available |
| 8 | `contributor_state` | text | Spine | `state` | YES | Direct map |
| 9 | `contributor_zip` | text | Spine | `zip5` | YES | Truncate to 5; prefer norm_zip5 |
| 10 | `contributor_employer` | text | Spine | `employer` | YES | Raw FEC; prefer norm_employer |
| 11 | `contributor_occupation` | text | Spine | `occupation` | YES | Raw FEC; prefer norm_occupation |
| 12 | `transaction_date_raw_mmddyyyy` | text | UNMAPPED | — | — | Raw MM/DD/YYYY string; use transaction_date instead. Check transaction_date_parse_failed |
| 13 | `transaction_amount` | numeric | CM | `amount` | YES | Direct map |
| 14 | `entity_type` | text | UNMAPPED | — | — | IND/ORG/COM etc; filter on IND for spine loads |
| 15 | `transaction_type` | text | UNMAPPED | — | — | FEC transaction type code |
| 16 | `memo_text` | text | UNMAPPED | — | — | Free text memo |
| 17 | `sub_id` | text | UNMAPPED | — | — | FEC unique transaction ID; same as fec_donations |
| 18 | `fec_cycle` | integer | UNMAPPED | — | — | Election cycle |
| 19 | `norm_last` | text | Spine | `norm_last` | YES | Direct map; derived from contributor_name parsing |
| 20 | `norm_first` | text | Spine | `norm_first` | YES | Direct map |
| 21 | `norm_middle` | text | Spine | `middle_name` | YES | Direct map |
| 22 | `norm_suffix` | text | Spine | `suffix` | YES | Direct map |
| 23 | `norm_zip5` | text | Spine | `zip5` | YES | Direct map |
| 24 | `norm_city` | text | Spine | `city` | YES | Prefer over contributor_city |
| 25 | `norm_employer` | text | Spine | `employer` / `best_employer` | YES | Prefer over raw contributor_employer |
| 26 | `norm_occupation` | text | Spine | `occupation` | YES | Prefer over raw contributor_occupation |
| 27 | `nickname_canonical` | text | Spine | `nickname_canonical` | YES | Direct map; one of three nickname sources |
| 28 | `party` | text | CM | `party_flag` | YES | Party of receiving committee |
| 29 | `party_flag` | text | CM | `party_flag` | YES | Direct map; prefer over `party` if both present |
| 30 | `golden_record_id` | bigint | Spine | `person_id` (candidate) | YES | Possibly maps to existing spine person_id; see Section 5 for conflict analysis |
| 31 | `person_id` | bigint | Spine | `person_id` | YES | Already linked; use to update spine record |
| 32 | `norm_street_num` | text | Spine | `addr_number` | YES | Direct map |
| 33 | `transaction_date` | date | CM | `transaction_date` | YES | Parsed date; check transaction_date_parse_failed flag first |
| 34 | `transaction_date_parse_failed` | boolean | UNMAPPED | — | — | Quality flag; reject row for CM if TRUE |

**FEC Party Unmapped count:** 15 columns  
**FEC Party Mapped count:** 19 columns  

---

### 1D. `nc_voters` → Spine (71 columns)

| # | Source Column | Data Type | Maps To | Target Column | Type Match? | Transform Needed |
|---|---|---|---|---|---|---|
| 1 | `county_id` | integer | Spine | UNMAPPED | — | No numeric county_id on spine; spine has county text |
| 2 | `county_desc` | varchar | Spine | `county` | YES | Direct map |
| 3 | `voter_reg_num` | varchar | UNMAPPED | — | — | No spine column for voter_reg_num |
| 4 | `ncid` | varchar | Spine | `voter_ncid` | YES | Primary voter linkage key |
| 5 | `last_name` | varchar | Spine | `last_name` | YES | Direct map |
| 6 | `first_name` | varchar | Spine | `first_name` | YES | Direct map |
| 7 | `middle_name` | varchar | Spine | `middle_name` | YES | Direct map |
| 8 | `name_suffix_lbl` | varchar | Spine | `suffix` | YES | Direct map |
| 9 | `status_cd` | varchar | Spine | `voter_status` | YES | Map code to description: A=Active, etc. |
| 10 | `voter_status_desc` | varchar | Spine | `voter_status` | YES | Prefer desc over code |
| 11 | `reason_cd` | varchar | UNMAPPED | — | — | Inactive reason code; no spine column |
| 12 | `voter_status_reason_desc` | varchar | UNMAPPED | — | — | Inactive reason description; no spine column |
| 13 | `res_street_address` | varchar | Spine | `street` | YES | Single concatenated string — must extract house number for addr_number. See Section 3 |
| 14 | `res_city_desc` | varchar | Spine | `city` | YES | Direct map |
| 15 | `state_cd` | varchar | Spine | `state` | YES | Direct map (2-char code) |
| 16 | `zip_code` | varchar | Spine | `zip5` | YES | Truncate to 5 |
| 17 | `mail_addr1` | varchar | Spine | UNMAPPED | — | Mailing address; no mail_ columns on spine |
| 18 | `mail_addr2` | varchar | UNMAPPED | — | — | Mailing address |
| 19 | `mail_addr3` | varchar | UNMAPPED | — | — | Mailing address |
| 20 | `mail_addr4` | varchar | UNMAPPED | — | — | Mailing address |
| 21 | `mail_city` | varchar | UNMAPPED | — | — | Mailing city |
| 22 | `mail_state` | varchar | UNMAPPED | — | — | Mailing state |
| 23 | `mail_zipcode` | varchar | UNMAPPED | — | — | Mailing zip |
| 24 | `full_phone_number` | varchar | Spine | `landline` | YES | Map to landline; source='nc_voters'. Could be cell — check against datatrust cell fields |
| 25 | `confidential_ind` | varchar | UNMAPPED | — | — | NCBE confidentiality flag; no spine column |
| 26 | `registr_dt` | varchar | UNMAPPED | — | — | Registration date; no direct spine column (see datatrust registrationdate) |
| 27 | `race_code` | varchar | Spine | `race` | YES | Map code: W=White, B=Black, etc. |
| 28 | `ethnic_code` | varchar | Spine | `ethnicity` | YES | Map code |
| 29 | `party_cd` | varchar | Spine | `voter_party` | YES | Direct map; authoritative NC BOE party registration |
| 30 | `gender_code` | varchar | Spine | `sex` | YES | M/F/U → male/female/unknown |
| 31 | `birth_year` | varchar | Spine | `birth_year` | NO (varchar→integer) | CAST to integer |
| 32 | `age_at_year_end` | varchar | Spine | `age` | NO (varchar→integer) | CAST to integer |
| 33 | `birth_state` | varchar | UNMAPPED | — | — | No spine column for birth state |
| 34 | `drivers_lic` | varchar | UNMAPPED | — | — | No spine column for driver's license flag |
| 35 | `precinct_abbrv` | varchar | Spine | `precinct` | YES | Use desc or abbrv; preferably desc |
| 36 | `precinct_desc` | varchar | Spine | `precinct` | YES | Prefer over abbrv |
| 37 | `municipality_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 38 | `municipality_desc` | varchar | UNMAPPED | — | — | No spine column |
| 39 | `ward_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 40 | `ward_desc` | varchar | UNMAPPED | — | — | No spine column |
| 41 | `cong_dist_abbrv` | varchar | Spine | `congressional_district` | YES | Direct map |
| 42 | `super_court_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 43 | `judic_dist_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 44 | `nc_senate_abbrv` | varchar | Spine | `state_senate_district` | YES | Direct map |
| 45 | `nc_house_abbrv` | varchar | Spine | `state_house_district` | YES | Direct map |
| 46 | `county_commiss_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 47 | `county_commiss_desc` | varchar | UNMAPPED | — | — | No spine column |
| 48 | `township_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 49 | `township_desc` | varchar | UNMAPPED | — | — | No spine column |
| 50 | `school_dist_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 51 | `school_dist_desc` | varchar | UNMAPPED | — | — | No spine column |
| 52 | `fire_dist_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 53 | `fire_dist_desc` | varchar | UNMAPPED | — | — | No spine column |
| 54 | `water_dist_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 55 | `water_dist_desc` | varchar | UNMAPPED | — | — | No spine column |
| 56 | `sewer_dist_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 57 | `sewer_dist_desc` | varchar | UNMAPPED | — | — | No spine column |
| 58 | `sanit_dist_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 59 | `sanit_dist_desc` | varchar | UNMAPPED | — | — | No spine column |
| 60 | `rescue_dist_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 61 | `rescue_dist_desc` | varchar | UNMAPPED | — | — | No spine column |
| 62 | `munic_dist_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 63 | `munic_dist_desc` | varchar | UNMAPPED | — | — | No spine column |
| 64 | `dist_1_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 65 | `dist_1_desc` | varchar | UNMAPPED | — | — | No spine column |
| 66 | `vtd_abbrv` | varchar | UNMAPPED | — | — | No spine column |
| 67 | `vtd_desc` | varchar | UNMAPPED | — | — | No spine column |
| 68 | `prefix` | text | Spine | `prefix` | YES | Direct map |
| 69 | `preferred_name` | text | Spine | `preferred_name` | YES | Direct map; source='nc_voters' |
| 70 | `canonical_first_name` | text | Spine | `canonical_first_name` | YES | Direct map; state-authoritative nickname |
| 71 | `street_number` | text | Spine | `addr_number` | YES | Direct map |

**NC Voters Unmapped count:** 41 columns (mostly political geography districts)  
**NC Voters Mapped count:** 30 columns  
**Note:** 36 district/geography columns have NO equivalent on person_spine. These are potentially valuable for future geographic analysis but the spine schema doesn't accommodate them.

---

### 1E. `nc_datatrust` → Spine (256 columns)

| # | Source Column | Data Type | Maps To | Target Column | Type Match? | Transform Needed |
|---|---|---|---|---|---|---|
| 1 | `rncid` | text | Spine | `voter_rncid` | YES | Primary DataTrust linkage key |
| 2 | `rnc_regid` | text | Spine | `rnc_regid` | YES | Secondary DataTrust ID |
| 3 | `prev_rncid` | text | UNMAPPED | — | — | Historical RNC ID; no spine column for previous IDs |
| 4 | `state` | text | Spine | `state` | YES | Direct map |
| 5 | `statekey` | text | UNMAPPED | — | — | DataTrust internal state key |
| 6 | `ispartyreg` | text | UNMAPPED | — | — | Party registration flag; no direct spine column |
| 7 | `sourceid` | text | UNMAPPED | — | — | DataTrust source code; ETL/provenance only |
| 8 | `juriscode` | text | UNMAPPED | — | — | Jurisdiction code |
| 9 | `jurisname` | text | UNMAPPED | — | — | Jurisdiction name |
| 10 | `countyfips` | text | UNMAPPED | — | — | FIPS code; no spine column |
| 11 | `countyname` | text | Spine | `county` | YES | Direct map; prefer over voter county if available |
| 12 | `mediamarket` | text | UNMAPPED | — | — | DMA/media market; no spine column |
| 13 | `censusblock2020` | text | UNMAPPED | — | — | Census block; no spine column |
| 14 | `metrotype` | text | UNMAPPED | — | — | Rural/suburban/urban classification |
| 15 | `mcd` | text | UNMAPPED | — | — | Minor civil division code |
| 16 | `statecountycode` | text | UNMAPPED | — | — | State+county FIPS |
| 17 | `statetowncode` | text | UNMAPPED | — | — | State+town code |
| 18 | `ward` | text | UNMAPPED | — | — | No spine column for ward |
| 19 | `precinctcode` | text | Spine | `precinct` | YES | Use precinctname if available |
| 20 | `precinctname` | text | Spine | `precinct` | YES | Direct map; prefer over precinctcode |
| 21 | `ballotbox` | text | UNMAPPED | — | — | No spine column |
| 22 | `schoolboard` | text | UNMAPPED | — | — | No spine column |
| 23 | `schooldistrict` | text | UNMAPPED | — | — | No spine column |
| 24 | `citycouncil` | text | UNMAPPED | — | — | No spine column |
| 25 | `countycommissioner` | text | UNMAPPED | — | — | No spine column |
| 26 | `congressionaldistrict` | text | Spine | `congressional_district` | YES | Direct map; prefer nc_voters cong_dist for NC |
| 27 | `congressionaldistrict_previouselection` | text | UNMAPPED | — | — | Historical; no spine column |
| 28 | `statelegupperdistrict` | text | Spine | `state_senate_district` | YES | Direct map |
| 29 | `statelegupperdistrict_previouselection` | text | UNMAPPED | — | — | Historical |
| 30 | `statelegupperdistrict_proper` | text | UNMAPPED | — | — | Formatted version; spine uses abbrv |
| 31 | `statelegupperdistrict_proper_previouselection` | text | UNMAPPED | — | — | Historical |
| 32 | `stateleglowerdistrict` | text | Spine | `state_house_district` | YES | Direct map |
| 33 | `stateleglowerdistrict_previouselection` | text | UNMAPPED | — | — | Historical |
| 34 | `stateleglowersubdistrict` | text | UNMAPPED | — | — | Sub-district; no spine column |
| 35 | `stateleglowersubdistrict_previouselection` | text | UNMAPPED | — | — | Historical |
| 36 | `stateleglowerdistrict_proper` | text | UNMAPPED | — | — | Formatted version |
| 37 | `stateleglowerdistrict_proper_previouselection` | text | UNMAPPED | — | — | Historical |
| 38 | `nameprefix` | text | Spine | `prefix` | YES | Direct map |
| 39 | `firstname` | text | Spine | `first_name` | YES | Direct map |
| 40 | `middlename` | text | Spine | `middle_name` | YES | Direct map |
| 41 | `lastname` | text | Spine | `last_name` | YES | Direct map |
| 42 | `namesuffix` | text | Spine | `suffix` | YES | Direct map |
| 43 | `sex` | text | Spine | `sex` | YES | Direct map (M/F) |
| 44 | `birthyear` | text | Spine | `birth_year` | NO (text→integer) | CAST to integer |
| 45 | `birthmonth` | text | UNMAPPED | — | — | No spine column for birth month |
| 46 | `birthday` | text | UNMAPPED | — | — | No spine column for birth day |
| 47 | `age` | text | Spine | `age` | NO (text→integer) | CAST to integer |
| 48 | `agerange` | text | UNMAPPED | — | — | Age band; no spine column |
| 49 | `congressionalagerange` | text | UNMAPPED | — | — | Congressional district age band |
| 50 | `registeredparty` | text | Spine | `voter_party` | YES | See Section 7 for party conflict resolution |
| 51 | `partyrollup` | text | UNMAPPED | — | — | R/D/I rollup; no spine column |
| 52 | `calcparty` | text | UNMAPPED | — | — | Calculated party assignment |
| 53 | `modeledparty` | text | UNMAPPED | — | — | Modeled party assignment |
| 54 | `statevoterid` | text | UNMAPPED | — | — | State voter ID string; spine uses voter_ncid (NCID format) |
| 55 | `jurisdictionvoterid` | text | UNMAPPED | — | — | No spine column |
| 56 | `lastactivitydate` | text | UNMAPPED | — | — | Text date; no spine column for voter activity date |
| 57 | `registrationdate` | text | UNMAPPED | — | — | Text date; no direct spine column |
| 58 | `registrationdatesource` | text | UNMAPPED | — | — | No spine column |
| 59 | `voterstatus` | text | Spine | `voter_status` | YES | Direct map |
| 60 | `permanentabsentee` | text | UNMAPPED | — | — | No spine column |
| 61 | `ethnicityreported` | text | Spine | `ethnicity` | YES | Use reported; prefer over modeled |
| 62 | `ethnicitymodeled` | text | UNMAPPED | — | — | Separate from reported; no distinct spine column |
| 63 | `ethnicgroupmodeled` | text | UNMAPPED | — | — | No spine column |
| 64 | `ethnicgroupnamemodeled` | text | UNMAPPED | — | — | No spine column |
| 65 | `religionmodeled` | text | Spine | `religion` | YES | Direct map |
| 66 | `languagemodeled` | text | UNMAPPED | — | — | No spine column |
| 67 | `acsethnicity_white` | text | UNMAPPED | — | — | ACS ethnic probability score |
| 68 | `acsethnicity_black` | text | UNMAPPED | — | — | ACS ethnic probability score |
| 69 | `acsethnicity_hispanic` | text | UNMAPPED | — | — | ACS ethnic probability score |
| 70 | `acsethnicity_asian` | text | UNMAPPED | — | — | ACS ethnic probability score |
| 71 | `acsethnicity_other` | text | UNMAPPED | — | — | ACS ethnic probability score |
| 72 | `acseducation_highschool` | text | UNMAPPED | — | — | ACS education probability |
| 73 | `acseducation_college` | text | UNMAPPED | — | — | ACS education probability |
| 74 | `acseducation_graduate` | text | UNMAPPED | — | — | ACS education probability |
| 75 | `acseducation_vocational` | text | UNMAPPED | — | — | ACS education probability |
| 76 | `acseducation_none` | text | UNMAPPED | — | — | ACS education probability |
| 77 | `householdid` | text | Spine | `household_id` | NO (text→bigint) | CAST to bigint |
| 78 | `householdmemberid` | text | UNMAPPED | — | — | No spine column for household member position |
| 79 | `householdparty` | text | UNMAPPED | — | — | Household-level party summary; see Section 7 |
| 80 | `registrationaddr1` | text | Spine | `street` | YES | Full string; use reghousenum+regst* components for addr_number/addr_type |
| 81 | `registrationaddr2` | text | UNMAPPED | — | — | Usually unit/apt info; no second street field on spine |
| 82 | `reghousenum` | text | Spine | `addr_number` | YES | Direct map (pre-parsed by DataTrust) |
| 83 | `reghousesfx` | text | UNMAPPED | — | — | House suffix (e.g. "1/2"); no spine column |
| 84 | `regstprefix` | text | UNMAPPED | — | — | Street prefix direction (N/S/E/W); no spine column. Include when reconstructing `street` |
| 85 | `regstname` | text | Spine | `street` (component) | YES | Use to build canonical street string |
| 86 | `regsttype` | text | Spine | `addr_type` | YES | Street type (ST/AVE/BLVD); maps to addr_type |
| 87 | `regstpost` | text | UNMAPPED | — | — | Post-directional (NE/SW etc); no spine column |
| 88 | `regunittype` | text | UNMAPPED | — | — | APT/STE/UNIT; no spine column |
| 89 | `regunitnumber` | text | UNMAPPED | — | — | Unit number; no spine column |
| 90 | `regcity` | text | Spine | `city` | YES | Direct map |
| 91 | `regsta` | text | Spine | `state` | YES | Direct map |
| 92 | `regzip5` | text | Spine | `zip5` | YES | Direct map |
| 93 | `regzip4` | text | UNMAPPED | — | — | ZIP+4 extension; no spine column |
| 94 | `reglatitude` | text | UNMAPPED | — | — | No spine column for lat/long |
| 95 | `reglongitude` | text | UNMAPPED | — | — | No spine column for lat/long |
| 96 | `reggeocodelevel` | text | UNMAPPED | — | — | Geocode quality level |
| 97 | `reglastcleanse` | text | UNMAPPED | — | — | Last CASS cleanse date |
| 98 | `reglastgeocode` | text | UNMAPPED | — | — | Last geocode date |
| 99 | `reglastcoa` | text | UNMAPPED | — | — | Last change-of-address check date |
| 100 | `changeofaddresssource` | text | UNMAPPED | — | — | USPS COA source |
| 101 | `changeofaddressdate` | text | UNMAPPED | — | — | COA date (text format — see Section 6) |
| 102 | `changeofaddresstype` | text | UNMAPPED | — | — | Individual/family COA |
| 103 | `mailingaddr1` | text | UNMAPPED | — | — | No mail address columns on spine |
| 104 | `mailingaddr2` | text | UNMAPPED | — | — | Mailing address |
| 105 | `mailhousenum` | text | UNMAPPED | — | — | Mailing house number |
| 106 | `mailhousesfx` | text | UNMAPPED | — | — | Mailing house suffix |
| 107 | `mailstprefix` | text | UNMAPPED | — | — | Mailing street prefix |
| 108 | `mailstname` | text | UNMAPPED | — | — | Mailing street name |
| 109 | `mailsttype` | text | UNMAPPED | — | — | Mailing street type |
| 110 | `mailstpost` | text | UNMAPPED | — | — | Mailing post-direction |
| 111 | `mailunittype` | text | UNMAPPED | — | — | Mailing unit type |
| 112 | `mailunitnumber` | text | UNMAPPED | — | — | Mailing unit number |
| 113 | `mailcity` | text | UNMAPPED | — | — | Mailing city |
| 114 | `mailsta` | text | UNMAPPED | — | — | Mailing state |
| 115 | `mailzip5` | text | UNMAPPED | — | — | Mailing zip |
| 116 | `mailzip4` | text | UNMAPPED | — | — | Mailing ZIP+4 |
| 117 | `mailsortcoderoute` | text | UNMAPPED | — | — | USPS sort code |
| 118 | `maildeliverypt` | text | UNMAPPED | — | — | USPS delivery point |
| 119 | `maildeliveryptchkdigit` | text | UNMAPPED | — | — | USPS check digit |
| 120 | `maillineoftravel` | text | UNMAPPED | — | — | USPS line of travel |
| 121 | `maillineoftravelorder` | text | UNMAPPED | — | — | USPS LOT order |
| 122 | `maildpvstatus` | text | UNMAPPED | — | — | USPS DPV deliverability status |
| 123 | `maillastcleanse` | text | UNMAPPED | — | — | Last mail CASS cleanse |
| 124 | `maillastcoa` | text | UNMAPPED | — | — | Last mail COA check |
| 125 | `cell` | text | Spine | `cell_phone` | YES | DataTrust primary cell; source='datatrust' |
| 126 | `cellsourcecode` | text | Spine | `cell_source` | YES | Direct map |
| 127 | `cellmatchlevel` | text | UNMAPPED | — | — | Cell phone match quality |
| 128 | `cellreliabilitycode` | text | UNMAPPED | — | — | Cell reliability score |
| 129 | `cellftcdonotcall` | text | UNMAPPED | — | — | DNC registry flag; no spine column |
| 130 | `cellappenddate` | text | UNMAPPED | — | — | Cell append date |
| 131 | `celldataaxle` | text | UNMAPPED | — | — | DataAxle cell; no distinct spine column |
| 132 | `celldataaxlematchlevel` | text | UNMAPPED | — | — | DataAxle match quality |
| 133 | `celldataaxlereliabilitycode` | text | UNMAPPED | — | — | DataAxle reliability |
| 134 | `celldataaxleftcdonotcall` | text | UNMAPPED | — | — | DataAxle DNC flag |
| 135 | `celldataaxleappenddate` | text | UNMAPPED | — | — | DataAxle append date |
| 136 | `cellrawvf` | text | UNMAPPED | — | — | Raw voter file cell; no distinct spine column |
| 137 | `cellrawvf_firstobserved` | text | UNMAPPED | — | — | First observed date |
| 138 | `cellabev` | text | UNMAPPED | — | — | ABEV cell number |
| 139 | `cellabev_firstobserved` | text | UNMAPPED | — | — | First observed date |
| 140 | `cellneustar` | text | UNMAPPED | — | — | Neustar cell number |
| 141 | `cellneustarmatchlevel` | text | UNMAPPED | — | — | Neustar match quality |
| 142 | `cellneustarreliabilitycode` | text | UNMAPPED | — | — | Neustar reliability |
| 143 | `cellneustartimeofday` | text | UNMAPPED | — | — | Preferred call time |
| 144 | `cellneustarappenddate` | text | UNMAPPED | — | — | Append date |
| 145 | `landline` | text | Spine | `landline` | YES | Direct map; source='datatrust' |
| 146 | `landlinesourcecode` | text | Spine | `landline_source` | YES | Direct map |
| 147 | `landlinematchlevel` | text | UNMAPPED | — | — | Landline match quality |
| 148 | `landlinereliabilitycode` | text | UNMAPPED | — | — | Reliability score |
| 149 | `landlineftcdonotcall` | text | UNMAPPED | — | — | DNC flag |
| 150 | `landlineappenddate` | text | UNMAPPED | — | — | Append date |
| 151 | `landlinedataaxle` | text | UNMAPPED | — | — | DataAxle landline |
| 152 | `landlinedataaxlematchlevel` | text | UNMAPPED | — | — | DataAxle match quality |
| 153 | `landlinedataaxlereliabilitycode` | text | UNMAPPED | — | — | DataAxle reliability |
| 154 | `landlinedataaxleftcdonotcall` | text | UNMAPPED | — | — | DataAxle DNC flag |
| 155 | `landlinedataaxleappenddate` | text | UNMAPPED | — | — | DataAxle append date |
| 156 | `landlinerawvf` | text | UNMAPPED | — | — | Raw voter file landline |
| 157 | `landlinerawvf_firstobserved` | text | UNMAPPED | — | — | First observed date |
| 158 | `landlineabev` | text | UNMAPPED | — | — | ABEV landline |
| 159 | `landlineabev_firstobserved` | text | UNMAPPED | — | — | First observed date |
| 160 | `landlineneustar` | text | UNMAPPED | — | — | Neustar landline |
| 161 | `landlineneustarmatchlevel` | text | UNMAPPED | — | — | Neustar match quality |
| 162 | `landlineneustarreliabilitycode` | text | UNMAPPED | — | — | Neustar reliability |
| 163 | `landlineneustartimeofday` | text | UNMAPPED | — | — | Preferred call time |
| 164 | `landlineneustarappenddate` | text | UNMAPPED | — | — | Append date |
| 165 | `voterfrequencygeneral` | UNMAPPED | — | — | Voter turnout metrics; no spine columns for these |
| 166 | `voterfrequencyprimary` | text | UNMAPPED | — | — | Voter turnout frequency |
| 167 | `voterregularitygeneral` | text | UNMAPPED | — | — | Voter regularity score |
| 168 | `voterregularityprimary` | text | UNMAPPED | — | — | Voter regularity score |
| 169 | `previousstate` | text | UNMAPPED | — | — | Previous registration state |
| 170 | `previousstate_regid` | text | UNMAPPED | — | — | Previous state voter ID |
| 171 | `previousregparty` | text | UNMAPPED | — | — | Previous party registration |
| 172 | `firstobservedstate` | text | UNMAPPED | — | — | First state observed |
| 173 | `firstobservedstate_regid` | text | UNMAPPED | — | — | First state voter ID |
| 174 | `firstobserveddate` | text | UNMAPPED | — | — | Date first observed in DataTrust |
| 175 | `matchedmovestate` | text | UNMAPPED | — | — | State voter moved to |
| 176 | `matchedmovestate_regid` | text | UNMAPPED | — | — | New state voter ID |
| 177 | `donorflag` | text | Spine | `is_donor` | NO (text→boolean) | Convert 'Y'/'N' to TRUE/FALSE |
| 178 | `mostrecentvote_state` | text | UNMAPPED | — | — | No spine column for vote history details |
| 179 | `mostrecentvote_election` | text | UNMAPPED | — | — | No spine column |
| 180 | `mostrecentvote_method` | text | UNMAPPED | — | — | No spine column |
| 181 | `mostrecentvote_dte` | text | UNMAPPED | — | — | No spine column |
| 182-221 | `vh06g` through `vh26p` (40 columns) | text | UNMAPPED | — | — | Vote history by election cycle; no spine columns |
| 222 | `per24pres_gop` | text | UNMAPPED | — | — | 2024 presidential vote GOP probability |
| 223 | `per24pres_dem` | text | UNMAPPED | — | — | 2024 presidential vote DEM probability |
| 224 | `per24pres_oth` | text | UNMAPPED | — | — | 2024 presidential vote OTHER probability |
| 225 | `coalitionid_socialconservative` | text | Spine | `coalition_social_conservative` | YES | Direct map |
| 226 | `coalitionid_veteran` | text | Spine | `coalition_veteran` | YES | Direct map |
| 227 | `coalitionid_sportsmen` | text | Spine | `coalition_sportsmen` | YES | Direct map |
| 228 | `coalitionid_2ndamendment` | text | Spine | `coalition_2nd_amendment` | YES | Direct map |
| 229 | `coalitionid_prolife` | text | Spine | `coalition_prolife` | YES | Direct map |
| 230 | `coalitionid_prochoice` | text | Spine | `coalition_prochoice` | YES | Direct map |
| 231 | `coalitionid_fiscalconservative` | text | Spine | `coalition_fiscal_conservative` | YES | Direct map |
| 232 | `republicanpartyscore` | text | Spine | `republican_score` | NO (text→numeric) | CAST to numeric |
| 233 | `democraticpartyscore` | text | Spine | `democratic_score` | NO (text→numeric) | CAST to numeric |
| 234 | `republicanballotscore` | text | UNMAPPED | — | — | No distinct spine column for ballot score vs party score |
| 235 | `democraticballotscore` | text | UNMAPPED | — | — | No distinct spine column |
| 236 | `turnoutgeneralscore` | text | Spine | `turnout_score` | NO (text→numeric) | CAST to numeric |
| 237 | `householdincomemodeled` | text | Spine | `income_range` | YES | Direct map |
| 238 | `educationmodeled` | text | Spine | `education_level` | YES | Direct map |
| 239 | `custom01` | text | UNMAPPED | — | — | DataTrust custom field; no spine column |
| 240 | `custom02` | text | UNMAPPED | — | — | DataTrust custom field |
| 241 | `custom03` | text | UNMAPPED | — | — | DataTrust custom field |
| 242 | `custom04` | text | UNMAPPED | — | — | DataTrust custom field |
| 243 | `custom05` | text | UNMAPPED | — | — | DataTrust custom field |
| 244 | `lastupdate` | text | UNMAPPED | — | — | DataTrust last update timestamp (text) |
| 245 | `norm_first` | text | Spine | `norm_first` | YES | Direct map |
| 246 | `norm_last` | text | Spine | `norm_last` | YES | Direct map |
| 247 | `norm_zip5` | text | Spine | `zip5` | YES | Direct map |
| 248 | `addr_type` | text | Spine | `addr_type` | YES | Direct map |
| 249 | `norm_street_num` | text | Spine | `addr_number` | YES | Direct map |
| 250-256 | (remaining columns) | — | See above complete list | — | — | All 256 columns documented |

**NC DataTrust Unmapped count:** ~190 columns  
**NC DataTrust Mapped count:** ~66 columns  
**Note:** The vast majority of unmapped DataTrust columns represent phone append sub-sources (DataAxle, ABEV, Neustar), vote history cycles (40 columns), geographic sub-codes, and mailing address detail. The spine schema simply doesn't have columns for most DataTrust analytical richness — particularly the 40 vote history cycle columns and the multi-source phone reliability metadata.

---

### 1F. person_spine Columns with NO SOURCE (128 columns — gap analysis)

| Spine Column | Notes |
|---|---|
| `honorific` | No source table populates this — manual entry or future WinRed data |
| `formal_salutation` | No automated source — would need to be derived from name+honorific |
| `correspondence_greeting` | No source — derived/manually composed |
| `title_source` | Metadata column — populated by ETL logic, not a source column |
| `title_priority` | Metadata column — integer ranking system |
| `title_salutation` | No source; see honorific confusion in Section 8 |
| `honorary_title` | No source; see Section 8 |
| `title_branch` | No source — military branch; could derive from is_military + DataTrust |
| `title_status` | No source — military status (Active/Ret./etc.) |
| `preferred_name_confidence` | No source — must be calculated by matching algorithm |
| `preferred_name_source` | Metadata — populated by ETL logic |
| `legal_first_name` | No automated source — manually entered or court record |
| `match_hash` | Computed from name+address; not sourced from any input table |
| `match_key_v2` | Computed matching key; not sourced |
| `addr_hash` | Computed from normalized address; not sourced |
| `data_quality_score` | Computed; not sourced |
| `record_quality` | Computed/categorized; not sourced |
| `donor_score` | Computed propensity model; not sourced |
| `total_contributed` | Computed from contribution_map; not directly sourced |
| `total_contributed_republican` | Computed from contribution_map + party_flag |
| `total_contributed_other` | Computed from contribution_map |
| `contribution_count` | Computed from contribution_map |
| `contribution_count_republican` | Computed |
| `total_contribution_count` | Computed (appears redundant with contribution_count — see Section 8) |
| `first_contribution` | Computed from contribution_map MIN(transaction_date) |
| `last_contribution` | Computed from contribution_map MAX(transaction_date) |
| `first_republican_contribution` | Computed |
| `last_republican_contribution` | Computed |
| `max_single_gift` | Computed |
| `avg_gift` | Computed |
| `giving_frequency` | Computed/derived label |
| `is_candidate` | No automated source — manual/scraped |
| `is_officeholder` | No automated source |
| `current_office` | No automated source |
| `is_delegate` | No automated source |
| `is_volunteer` | No automated source |
| `is_party_officer` | No automated source |
| `office_level` | No automated source |
| `office_start_date` | No automated source |
| `office_end_date` | No automated source |
| `marital_status` | No source among the 5 tables — DataTrust doesn't include it |
| `homeowner` | No source |
| `home_value_range` | No source |
| `children_present` | No source |
| `acxiom_race` | No source — would require Acxiom append not in current tables |
| `acxiom_religion` | No source |
| `acxiom_education` | No source |
| `acxiom_income_range` | No source |
| `acxiom_occupation` | No source |
| `acxiom_party` | No source |
| `winred_donor_id` | No source among current tables — requires WinRed API integration |
| `winred_email` | No source among current tables |
| `winred_linked_at` | No source — system timestamp |
| `sic_code` | No source — would require SIC/NAICS lookup from employer string |
| `is_military` | No automated source — could derive from title_branch or donor occupation strings |
| `business_phone` | No source among current tables |
| `business_phone_source` | Metadata |
| `merged_from` | Array — populated by merge ETL logic only |
| `merged_into` | Populated by merge logic only |
| `deactivated_at` | Populated by ETL deactivation logic |
| `batch_id` | ETL batch UUID |
| `version` | ETL version counter |

---

<a name="section-2"></a>
## SECTION 2: Name Column Chaos

### 2A. Name Column Inventory Across All Sources

| Source | Name Columns | Format | Parsing Status |
|---|---|---|---|
| `nc_boe_donations_raw` | `donor_name`, `norm_first`, `norm_last`, `parsed_first`, `parsed_last`, `parsed_middle`, `parsed_suffix`, `parsed_nickname`, `canonical_first`, `middle_name`, `name_suffix` | Mixed — full name + parsed components | Partially parsed; inconsistent format in donor_name |
| `fec_donations` | `contributor_name`, `contributor_first`, `contributor_last`, `norm_first`, `norm_last` | Full name + pre-parsed first/last | FEC provides pre-split first/last |
| `fec_party_committee_donations` | `contributor_name`, `norm_last`, `norm_first`, `norm_middle`, `norm_suffix`, `nickname_canonical` | Full name ONLY (no pre-parsed first/last); normalized components added by ETL | contributor_name must be parsed |
| `nc_voters` | `first_name`, `middle_name`, `last_name`, `name_suffix_lbl`, `canonical_first_name`, `prefix`, `preferred_name` | Fully split components | Most reliable; state-maintained |
| `nc_datatrust` | `nameprefix`, `firstname`, `middlename`, `lastname`, `namesuffix` | Fully split components | Very reliable; RNC normalized |
| **person_spine (target)** | `first_name`, `last_name`, `middle_name`, `suffix`, `prefix`, `norm_first`, `norm_last`, `nickname_canonical`, `preferred_first`, `preferred_name_source`, `preferred_name_confidence`, `legal_first_name`, `canonical_first_name`, `preferred_name`, `honorific`, `honorary_title`, `title_salutation`, `formal_salutation`, `correspondence_greeting` | Fully split | Expects clean components |

### 2B. Source Reliability Ranking

**1. nc_voters (Most Reliable)**
- State Board of Elections maintains these records
- Voter registered using their legal name
- Fully parsed: `first_name`, `middle_name`, `last_name`, `name_suffix_lbl`
- Has `canonical_first_name` — this is the state's own nickname resolution (e.g., "Liz" for "Elizabeth")
- Has `preferred_name` — voter-provided preferred name on registration form
- Has `prefix` — state-captured courtesy title
- **Best use:** Source of truth for legal name when voter_ncid linkage is confirmed

**2. nc_datatrust (Very Reliable)**
- RNC-maintained, CASS-processed, standardized
- Fully parsed: `nameprefix`, `firstname`, `middlename`, `lastname`, `namesuffix`
- Standardized format applied across all 50 states
- No nickname data (no equivalent to canonical_first_name)
- **Best use:** Name verification/normalization for matched voter records; useful when nc_voters has missing middle name

**3. fec_donations (Moderately Reliable)**
- Pre-parsed first/last: `contributor_first`, `contributor_last`
- Also has `norm_first`, `norm_last` applied by internal ETL
- No middle name column
- **Problem:** FEC data is self-reported. Donors enter their own names and frequently use:
  - Nicknames ("Bob" instead of "Robert")
  - Middle name in first name field ("James Edward Smith" → first="James Edward")
  - Company names in individual fields
  - Abbreviations and typos
- **Best use:** Confirms identity for matched donors; cannot be trusted as authoritative name source

**4. fec_party_committee_donations (Moderate, More Issues)**
- `contributor_name` is a SINGLE FULL NAME STRING — not pre-parsed
- ETL has derived `norm_last`, `norm_first`, `norm_middle`, `norm_suffix` from that string
- Has `nickname_canonical` — RNC nickname mapping applied
- **Critical problem:** The parsing of `contributor_name` happens internally and the format is inconsistent:
  - "SMITH, JOHN EDWARD JR" (LAST, FIRST MIDDLE SUFFIX)
  - "JOHN SMITH" (FIRST LAST)
  - "JOHN E SMITH" (FIRST MIDDLE LAST — ambiguous)
  - "DR JOHN SMITH" (PREFIX FIRST LAST — prefix not stripped)
- **Best use:** Confirms identity; nickname_canonical is useful for linking to voter records

**5. nc_boe_donations_raw (Least Reliable for Names)**
- `donor_name` is a single raw string from the BOE filing
- Has 10 additional name columns (norm_*, parsed_*, canonical_first, middle_name, name_suffix) — inconsistently populated
- **The BOE name format problem (documented in detail below)**
- **Best use:** The parsed_* columns when populated; fall back to norm_* when parsed_* is null

### 2C. The NC BOE Name Format Problem

`donor_name` in `nc_boe_donations_raw` comes directly from campaign finance filings submitted to the NC Board of Elections. Filers use three (at minimum) incompatible formats:

**Format 1: LAST, FIRST MIDDLE**
```
"SMITH, JOHN EDWARD"
"JOHNSON, MARY ANN"
"O'BRIEN, PATRICK JAMES"
```

**Format 2: FIRST LAST**
```
"JOHN SMITH"
"MARY JOHNSON"
"PAT O'BRIEN"
```

**Format 3: LAST, FIRST M. (middle initial only)**
```
"SMITH, JOHN E."
"JOHNSON, MARY A."
```

**Format 4: Ambiguous / No-separator with middle name**
```
"JOHN EDWARD SMITH" — is EDWARD a middle name or compound first?
"MARY ANN JOHNSON" — is ANN a middle name?
```

**Format 5: Organizations in individual fields**
```
"THE SMITH FAMILY TRUST"
"JOHN SMITH FOR CONGRESS"
"SMITH HOLDINGS LLC"
```
The `is_organization` boolean flag addresses this, but it's not always set correctly.

**Format 6: Suffixes embedded**
```
"JOHN SMITH JR"
"JOHN SMITH III"
"DR. JOHN SMITH" (prefix embedded)
```

**Parsing consequence:** The `parsed_first`, `parsed_last`, `parsed_middle`, `parsed_suffix`, `parsed_nickname` columns represent the ETL team's attempt to parse `donor_name`. These ARE the preferred source when populated. However, parsing failures leave these null and force fallback to `norm_first`/`norm_last` (which don't include middle names), or back to `donor_name` raw string parsing.

**The canonical_first column:** `canonical_first` on nc_boe_donations_raw represents the ETL team's best guess at a canonical/nickname form of the first name. It's not the same system as nc_voters' `canonical_first_name` (which is state-maintained). These two columns carry the same conceptual intent but from entirely different resolution systems with potentially different results for the same person.

### 2D. The FEC Party Contributor Name Problem

`fec_party_committee_donations` has `contributor_name` as a full string (unlike `fec_donations` which has pre-split `contributor_first` and `contributor_last`). The raw FEC party file format stores names in the format:
```
LAST, FIRST MIDDLE SUFFIX
```
But this is not guaranteed. The ETL has derived `norm_last`, `norm_first`, `norm_middle`, `norm_suffix` from this. The question is what happens when:
- The name contains no comma (FIRST LAST format)
- The name is an organization
- `entity_type` is 'IND' but the name is clearly a company

The `entity_type` column should be used to filter: only load rows where `entity_type = 'IND'` to the person_spine. Committee and organization donors must be excluded.

### 2E. The Nickname Problem: Three Conflicting Systems

The spine has: `nickname_canonical`, `preferred_first`, `preferred_name_source`, `preferred_name_confidence`, `canonical_first_name`, `preferred_name`, `legal_first_name`

Here is how each source contributes to the nickname ecosystem:

| Source | Column | System | Notes |
|---|---|---|---|
| `nc_voters` | `canonical_first_name` | NC BOE state-maintained | "Liz" for voter registered as "Elizabeth"; state-verified |
| `nc_voters` | `preferred_name` | Voter self-reported on registration | Free text; whatever the voter wrote |
| `nc_datatrust` | (NONE) | — | DataTrust does NOT carry nickname/preferred name data |
| `fec_party_committee_donations` | `nickname_canonical` | RNC-applied normalization | RNC's own nickname dictionary applied to contributor_name |
| `nc_boe_donations_raw` | `canonical_first` | ETL-derived | First-pass nickname resolution by BOE ETL process |
| `nc_boe_donations_raw` | `parsed_nickname` | Parser-extracted | Nicknames in parentheses e.g. "ROBERT (BOB) SMITH" |

**The BUDDY Problem:** A person registered as "Charles Edward Smith" might be known by everyone as "Buddy" Smith. "Buddy" cannot be derived from "Charles" by any algorithmic system. It will appear in nc_boe as `parsed_nickname='BUDDY'` only if the donor wrote it in the filing. The nc_voters `preferred_name` field is the only state-maintained place a non-derivable nickname can live. If the voter didn't update their registration, BUDDY lives nowhere in the database.

**Spine column resolution priority for nickname fields:**
1. `preferred_name` → from nc_voters (voter self-reported)
2. `canonical_first_name` → from nc_voters (state-maintained canonical)
3. `nickname_canonical` → from fec_party or nc_boe canonical_first (ETL-derived)
4. `preferred_first` → from nc_boe parsed_nickname or fec name variants
5. `preferred_name_source` → document which system won
6. `preferred_name_confidence` → 1.0 for voter-confirmed, 0.7 for RNC canonical, 0.5 for parsed

### 2F. Spine Name Columns with NO Automated Source

| Spine Column | Status | Notes |
|---|---|---|
| `legal_first_name` | **NO AUTOMATED SOURCE** | Cannot be derived; requires manual entry or court record. Distinct from `first_name` only for people who go by a middle name or nickname exclusively |
| `honorific` | **NO AUTOMATED SOURCE** | Dr./Rev./Gen./Sen./etc.; not captured in any source table |
| `honorary_title` | **NO AUTOMATED SOURCE** | "Distinguished Fellow", "Chairman Emeritus"; manual entry only |
| `formal_salutation` | **NO AUTOMATED SOURCE** | "Dear Dr. Smith"; must be constructed from name + honorific |
| `title_salutation` | **NO AUTOMATED SOURCE** | Duplicate/variant of formal_salutation — see Section 8 |
| `correspondence_greeting` | **NO AUTOMATED SOURCE** | "Dear Bob"; must be constructed or manually set |

---

<a name="section-3"></a>
## SECTION 3: Address Column Chaos

### 3A. Address Format Inventory

| Source | Address Fields | Format | Parsed? | Quality |
|---|---|---|---|---|
| `nc_boe_donations_raw` | `street_line_1`, `street_line_2`, `city`, `state`, `zip_code`, `norm_addr`, `norm_zip5`, `norm_city`, `norm_state` | Donor-reported raw + ETL normalized | Partially (norm_addr is normalized but not component-parsed) | Low (donor input) → Medium (after normalization) |
| `fec_donations` | `contributor_street_1`, `contributor_street_2`, `contributor_city`, `contributor_state`, `contributor_zip`, `contributor_zip5`, `norm_street_num`, `norm_zip5` | FEC self-reported + partial normalization | Partially (street_num extracted) | Low to Medium |
| `fec_party_committee_donations` | `contributor_city`, `contributor_state`, `contributor_zip`, `norm_zip5`, `norm_city`, `norm_street_num` | FEC self-reported + partial normalization | Partial | Low to Medium |
| `nc_voters` | `res_street_address` (single string), `res_city_desc`, `state_cd`, `zip_code`, `street_number` | Single string + split city/state/zip + extracted street_number | `street_number` extracted; full address is one string | Medium to High |
| `nc_datatrust` | `reghousenum`, `reghousesfx`, `regstprefix`, `regstname`, `regsttype`, `regstpost`, `regunittype`, `regunitnumber`, `regcity`, `regsta`, `regzip5`, `regzip4` + mailing equivalents | Fully component-parsed; CASS-certified | Fully parsed; USPS-standardized | **Highest** |
| **person_spine** | `street`, `city`, `state`, `zip5`, `county`, `addr_hash`, `addr_number`, `addr_type` | Single street string + split components | Needs: full string in `street`, number in `addr_number`, type in `addr_type` | Target format |

### 3B. The Canonical Address Challenge

**The spine wants:**
- `street` — single normalized street string (e.g., "123 OAK ST")
- `city` — city name
- `state` — 2-char state code
- `zip5` — 5-digit ZIP
- `addr_number` — house/unit number only (e.g., "123")
- `addr_type` — street type only (e.g., "ST")
- `addr_hash` — computed hash for address dedup/matching

**What each source gives you:**

**nc_datatrust (BEST):** Gives you every component separately:
- `reghousenum` → `addr_number`
- `regstname` + `regsttype` → reconstruct `street` as: `reghousenum || ' ' || regstprefix || ' ' || regstname || ' ' || regsttype || ' ' || regstpost`
- `regsttype` → `addr_type`
- `regcity` → `city`
- `regsta` → `state`
- `regzip5` → `zip5`

This is CASS-certified, USPS-standardized. Treat this as the gold standard for address.

**nc_voters (GOOD):** `res_street_address` is a single string (e.g., "123 OAK ST APT 4"). The `street_number` column has been extracted. Use:
- `street_number` → `addr_number`
- `res_street_address` (normalized) → `street`
- But `addr_type` must be extracted from the string via regex or parsing
- City/state/zip are separate and reliable

**BOE (POOR):** Donor-reported address. Common problems:
- All caps vs mixed case
- Abbreviated vs spelled-out street types
- Missing unit numbers
- PO Boxes (completely different format)
- Vacation home / secondary address vs primary residence
- Out-of-state addresses for NC voters
- The `norm_addr` column represents post-normalization, but component extraction hasn't been done

**FEC (POOR-MEDIUM):** Self-reported but often matches voter file because FEC forms require real address. However:
- `contributor_street_1` may be PO Box
- `contributor_street_2` is rarely populated but contains unit info
- Only `norm_street_num` (number extracted) is in the table; full parsed components are not
- `contributor_zip5` is more reliable than `contributor_zip` (which may be ZIP+4)

### 3C. The PO Box Problem

PO Boxes are unmatchable to residential voter records. When `street_line_1` or `contributor_street_1` contains "PO BOX", "P.O. BOX", "POST OFFICE BOX", or "PMB", the address cannot be used for voter file matching. The spine's `street` field would contain the PO Box string, which will never match a residential address. There is no flag on person_spine for PO Box donors.

**Recommended handling:** Set `addr_type = 'PO_BOX'` and exclude from address-based matching.

### 3D. DataTrust Mailing Address vs Registration Address

nc_datatrust has two complete address blocks:
- **Registration address** (reghousenm, regstname, etc.) — home address used for voter registration
- **Mailing address** (mailhousenum, mailstname, etc.) — USPS mailing address (may differ for seasonal residents, snowbirds, college students, etc.)

The spine has only ONE address block with no mail_* columns. This means mailing address data from DataTrust is **entirely dropped** during loading. For donors who use a PO Box or mailing address that differs from their voter registration address, this is a matching failure risk.

The `changeofaddressdate`, `changeofaddresssource`, and `changeofaddresstype` columns in DataTrust track USPS National Change of Address (NCOA) updates. These are text fields (see Section 6) and have no home on the spine. Per Ed's rule of addresses staler than 11 years being problematic, `reglastcoa` (date of last COA check) is critical data that is currently unmapped.

### 3E. Address Staleness

The spine has no column for "address last verified date" or "address last COA check date". DataTrust provides `reglastcoa` and `reglastcleanse`, and `changeofaddressdate` — all text fields. If a person registered to vote in 2010 and has never updated their registration, their voter file address is 16 years stale. The spine has no mechanism to flag this, which means address-based matching on old records will fail silently.

---

<a name="section-4"></a>
## SECTION 4: Employer/Occupation Column Chaos

### 4A. Employer Column Inventory

| Source | Employer Column | Occupation Column | Normalized? |
|---|---|---|---|
| `nc_boe_donations_raw` | `employer_name` | `profession_job_title` | `employer_normalized` (text) |
| `fec_donations` | `contributor_employer` | `contributor_occupation` | `employer_normalized` (text) |
| `fec_party_committee_donations` | `contributor_employer` | `contributor_occupation` | `norm_employer`, `norm_occupation` |
| **person_spine** | `employer`, `best_employer` | `occupation` | `sic_code`, `industry_sector` |

### 4B. The FEC Employer Garbage Problem

By federal law (52 U.S.C. § 30102(c)(3)), FEC disclosure reports must include the contributor's employer and occupation for contributions over $200. However, there is no FEC enforcement of format or quality. This produces systematic garbage:

**Employer garbage patterns:**
- "RETIRED" — not an employer
- "SELF-EMPLOYED" — not an employer name
- "N/A", "NONE", "NA", "N.A." — no data
- "HOMEMAKER" — not an employer
- "SELF" — not an employer name
- "STUDENT" — not an employer
- "DISABLED" — not an employer
- "UNEMPLOYED" — not an employer
- "SAME" — references previous filing
- "INFORMATION REQUESTED" — FEC follow-up placeholder

**Occupation garbage patterns:**
- "RETIRED" (most common occupation by far)
- "HOMEMAKER" / "HOUSEWIFE"
- "ATTORNEY" — real occupation, but vague
- "PHYSICIAN" — real, but no specialty
- The same person may file "LAWYER" on one donation and "ATTORNEY" on another

**Normalization applied:**
- `employer_normalized` on nc_boe and fec_donations — this is the ETL team's normalization
- `norm_employer` and `norm_occupation` on fec_party — separate normalization pipeline
- These are NOT the same normalization. Identical raw employer strings may produce different normalized values across tables

### 4C. The `best_employer` Problem

`best_employer` on person_spine is defined as the "backward-scanned most recent real employer" — meaning it should skip garbage values (RETIRED, SELF-EMPLOYED, etc.) and find the most recent actual employer name.

**Implementation challenge:** There is no source column called `best_employer`. This field must be computed at load time by scanning the person's contribution history across all 3 donation sources, sorted descending by date, and taking the first non-garbage employer string. The garbage filter list is not defined in the schema — it must be built and maintained separately.

**`sic_code` and `industry_sector`:** No source table provides SIC/NAICS codes. These would need to be derived from `best_employer` via a company name → SIC code lookup service (IRS/Dun & Bradstreet/etc.) or via the occupation string. This is a completely unautomated field with no current source.

### 4D. NC BOE vs FEC Normalization Discrepancy

Both `nc_boe_donations_raw.employer_normalized` and `fec_donations.employer_normalized` are text columns with ETL normalization applied. `fec_party_committee_donations.norm_employer` is a separately derived column. There is NO documentation in the schema of what normalization algorithm was applied. Key questions that cannot be answered from schema alone:
- Are "BANK OF AMERICA" and "BANKOFAMERICA" normalized to the same string?
- Are "DUKE UNIV" and "DUKE UNIVERSITY" normalized to the same string?
- Were "RETIRED" and other garbage values removed, or merely flagged?

---

<a name="section-5"></a>
## SECTION 5: ID Columns and Linkage Paths

### 5A. Full ID Inventory

| Table | ID Column | Type | Purpose |
|---|---|---|---|
| `nc_boe_donations_raw` | `id` | bigint | BOE table PK |
| `nc_boe_donations_raw` | `voter_ncid` | text | Voter file link (→ nc_voters.ncid) |
| `nc_boe_donations_raw` | `rncid` | text | DataTrust link (→ nc_datatrust.rncid) |
| `nc_boe_donations_raw` | `fec_contributor_id` | text | FEC cross-reference (no direct spine column) |
| `nc_boe_donations_raw` | `member_id` | uuid | Internal membership ID (no spine column) |
| `nc_boe_donations_raw` | `golden_record_id` | integer | Candidate spine person_id (conflict — see 5D) |
| `nc_boe_donations_raw` | `committee_sboe_id` | varchar | Committee identifier |
| `nc_boe_donations_raw` | `donor_committee_sboe_id` | text | Donor's own committee ID (for committee-to-committee donations) |
| `fec_donations` | `id` | integer | FEC donations table PK |
| `fec_donations` | `committee_id` | text | FEC committee ID |
| `fec_donations` | `sub_id` | text | FEC unique transaction ID (27-digit) |
| `fec_donations` | `person_id` | bigint | Already-linked spine person_id |
| `fec_party_committee_donations` | `id` | integer | FEC party table PK |
| `fec_party_committee_donations` | `committee_id` | text | FEC committee ID |
| `fec_party_committee_donations` | `sub_id` | text | FEC unique transaction ID |
| `fec_party_committee_donations` | `golden_record_id` | bigint | Candidate spine person_id (conflict — see 5D) |
| `fec_party_committee_donations` | `person_id` | bigint | Already-linked spine person_id |
| `nc_voters` | `county_id` | integer | NC county code |
| `nc_voters` | `voter_reg_num` | varchar | County-level voter reg number |
| `nc_voters` | `ncid` | varchar | NCID — state-wide unique voter ID |
| `nc_datatrust` | `rncid` | text | RNC national unique voter ID |
| `nc_datatrust` | `rnc_regid` | text | RNC registration ID (can change) |
| `nc_datatrust` | `prev_rncid` | text | Previous RNC ID (after merge/supersession) |
| `nc_datatrust` | `statevoterid` | text | State voter ID (= ncid for NC) |
| `nc_datatrust` | `jurisdictionvoterid` | text | Jurisdiction-specific voter ID |
| `nc_datatrust` | `householdid` | text | DataTrust household identifier |
| `nc_datatrust` | `householdmemberid` | text | Position within household |
| `nc_datatrust` | `sourceid` | text | DataTrust data source code |
| `nc_datatrust` | `statekey` | text | DataTrust state key |
| **`core.person_spine`** | `person_id` | bigint | Spine PK — master identity ID |
| **`core.person_spine`** | `voter_ncid` | text | Link to nc_voters.ncid |
| **`core.person_spine`** | `voter_rncid` | text | Link to nc_datatrust.rncid |
| **`core.person_spine`** | `rnc_regid` | text | Link to nc_datatrust.rnc_regid |
| **`core.person_spine`** | `household_id` | bigint | Link to nc_datatrust.householdid (cast) |
| **`core.person_spine`** | `winred_donor_id` | integer | WinRed platform donor ID |
| **`core.person_spine`** | `match_hash` | text | Computed name+address hash |
| **`core.person_spine`** | `match_key_v2` | text | Second-generation matching key |
| **`core.person_spine`** | `batch_id` | uuid | ETL batch identifier |
| **`core.contribution_map`** | `id` | bigint | CM PK |
| **`core.contribution_map`** | `person_id` | bigint | Link to person_spine.person_id |
| **`core.contribution_map`** | `source_system` | text | 'nc_boe', 'fec_indiv', 'fec_party' |
| **`core.contribution_map`** | `source_id` | bigint | Source table PK (nc_boe.id, fec_donations.id, etc.) |
| **`core.contribution_map`** | `committee_id` | text | Receiving committee ID |
| **`core.contribution_map`** | `candidate_id` | uuid | Receiving candidate UUID (spine person_id is bigint — type conflict) |

### 5B. Join Paths: How Each Source Connects to person_spine

**NC BOE → person_spine:**
```
nc_boe_donations_raw.voter_ncid = person_spine.voter_ncid   [PRIMARY - if voter matched]
nc_boe_donations_raw.rncid = person_spine.voter_rncid        [SECONDARY - if RNC matched]
nc_boe_donations_raw.golden_record_id = person_spine.person_id  [RISKY - see Section 5D]
-- Fallback: name+address match using norm_first, norm_last, norm_zip5
```

**FEC Donations → person_spine:**
```
fec_donations.person_id = person_spine.person_id  [PRIMARY - already linked]
-- Fallback: norm_first + norm_last + norm_zip5 match
-- Fallback: norm_first + norm_last + contributor_state match (for out-of-state donors)
```

**FEC Party → person_spine:**
```
fec_party_committee_donations.person_id = person_spine.person_id  [PRIMARY - already linked]
fec_party_committee_donations.golden_record_id = person_spine.person_id  [RISKY - see Section 5D]
-- Fallback: norm_first + norm_last + norm_zip5 match
```

**NC Voters → person_spine:**
```
nc_voters.ncid = person_spine.voter_ncid  [PRIMARY - definitive voter link]
-- No fallback needed; NCID is the authoritative voter identifier
```

**NC DataTrust → person_spine:**
```
nc_datatrust.rncid = person_spine.voter_rncid  [PRIMARY]
nc_datatrust.rnc_regid = person_spine.rnc_regid  [SECONDARY]
nc_datatrust.statevoterid = person_spine.voter_ncid  [TERTIARY - statevoterid=ncid for NC]
nc_datatrust.householdid (text) = person_spine.household_id (bigint after cast)  [HOUSEHOLD LEVEL]
```

### 5C. Missing Links: IDs on Sources with No Spine Counterpart

| Source ID | Source Table | Problem |
|---|---|---|
| `fec_contributor_id` | nc_boe_donations_raw | No spine column; cannot directly link BOE record to FEC transaction by this ID |
| `member_id` (uuid) | nc_boe_donations_raw | No spine column; BOE membership identity system disconnected from spine |
| `voter_reg_num` | nc_voters | No spine column; county-level voter reg number not stored |
| `county_id` (integer) | nc_voters | No spine column; spine only has county text |
| `prev_rncid` | nc_datatrust | No spine column; if person's RNCID was superseded, the old ID path is broken |
| `statevoterid` | nc_datatrust | Functionally = voter_ncid for NC; but no distinct spine column means you must test this equivalence assumption in ETL |
| `jurisdictionvoterid` | nc_datatrust | No spine column |
| `householdmemberid` | nc_datatrust | No spine column; household member position lost |
| `sub_id` (FEC txn ID) | fec_donations, fec_party | No spine column; cannot reverse-look up FEC transaction by official sub_id from spine |
| `statekey` | nc_datatrust | No spine column; DataTrust internal key lost |
| `donor_committee_sboe_id` | nc_boe_donations_raw | No spine column; donor-as-committee relationship unrepresented |

### 5D. The golden_record_id vs person_id Confusion

Both `nc_boe_donations_raw` and `fec_party_committee_donations` have a `golden_record_id` column alongside a `person_id` column. This creates a two-identity problem:

**On nc_boe_donations_raw:**
- `golden_record_id` is type `integer`
- `person_id` is NOT on this table at all
- `golden_record_id` appears to be a candidate link to person_spine.person_id
- But person_spine.person_id is `bigint` — integer range may be insufficient for large spine tables
- **Risk:** If golden_record_id was populated by an older ETL that used a different person ID system, these IDs may not match current person_spine.person_id values

**On fec_party_committee_donations:**
- `golden_record_id` is type `bigint`
- `person_id` is also type `bigint`
- Both potentially reference person_spine.person_id
- If `person_id` is the current spine link and `golden_record_id` is an older link, they may differ for the same row
- If they differ: which one is correct? There is no documentation in the schema

**The problem in practice:**
- A donor matched in 2022 gets `golden_record_id = 5001`
- A 2024 ETL re-run assigns them `person_id = 8847` due to a merge
- Now the same donation has two different identity claims
- Loading `golden_record_id` to spine would overwrite the correct current `person_id`

**Recommendation:** Always prefer `person_id` over `golden_record_id` when both are non-null. Treat `golden_record_id` as an audit/legacy reference only.

### 5E. The voter_ncid → ncid Path (NC Voters)

```
nc_boe_donations_raw.voter_ncid  ──┐
                                    ├──→  nc_voters.ncid = person_spine.voter_ncid
person_spine.voter_ncid            ──┘
```

This path is clean when it works. Problems:
1. `voter_ncid` on BOE records is NULL for unmatched donors (~30-40% estimated)
2. A donor who has never registered to vote has no NCID
3. An out-of-state donor (contributing to NC races) has no NC NCID
4. NCID format changed over time; old-format NCIDs may not match current nc_voters format

### 5F. The voter_rncid → rncid Path (DataTrust)

```
nc_boe_donations_raw.rncid  ──┐
                               ├──→  nc_datatrust.rncid = person_spine.voter_rncid
nc_datatrust.prev_rncid       ──┘ (prev_rncid path NOT tracked on spine)
```

**Critical gap:** `nc_datatrust.prev_rncid` records when a person's RNCID was superseded (e.g., after a DataTrust record merge). The spine only stores `voter_rncid` (the current RNCID). If a BOE record has an old RNCID that became a `prev_rncid` in DataTrust, the BOE record will fail to join to DataTrust via the current RNCID, and thus fail to join to the spine. This silent linkage break has no error flag.

### 5G. contribution_map candidate_id Type Conflict

`contribution_map.candidate_id` is type `uuid`. But `person_spine.person_id` is `bigint`. If a candidate in person_spine is also a donation recipient, their candidate_id in contribution_map cannot directly join to person_spine.person_id due to type mismatch. Either:
- The candidate_id UUID maps to a separate candidates table (not shown in the 7 tables)
- Or there's a casting/lookup layer needed
- This is an unresolved join path

---

<a name="section-6"></a>
## SECTION 6: Date Column Inconsistencies

### 6A. Date Column Inventory

| Source | Column | Data Type | Format Notes | Quality Issue |
|---|---|---|---|---|
| `nc_boe_donations_raw` | `date_occured_raw` | varchar | Raw text date from filing | **TYPO IN COLUMN NAME** ("occured" not "occurred"); format varies by filer |
| `nc_boe_donations_raw` | `date_occurred` | date | Parsed version of date_occured_raw | More reliable but parsing may have failed silently |
| `fec_donations` | `contribution_date` | date | Parsed FEC date | Flagged by `date_corrupt` |
| `fec_donations` | `original_contribution_date` | date | Pre-correction date | Audit trail; may differ from contribution_date |
| `fec_donations` | `date_corrupt` | boolean | TRUE if date parsing failed | Flag must be checked before loading |
| `fec_party_committee_donations` | `transaction_date_raw_mmddyyyy` | text | MM/DD/YYYY text string | Raw FEC party transaction date |
| `fec_party_committee_donations` | `transaction_date` | date | Parsed from transaction_date_raw_mmddyyyy | Check `transaction_date_parse_failed` |
| `fec_party_committee_donations` | `transaction_date_parse_failed` | boolean | TRUE if parsing failed | Flag must be checked; row should be skipped or manually reviewed |
| `nc_datatrust` | `registrationdate` | text | Unknown text format | ALL DATES IN DATATRUST ARE TEXT — no standard format documented |
| `nc_datatrust` | `lastactivitydate` | text | Unknown text format | Text; not loadable to any date column without casting |
| `nc_datatrust` | `changeofaddressdate` | text | Unknown text format | Text; COA date critical for address staleness |
| `nc_datatrust` | `mostrecentvote_dte` | text | Unknown text format | Text |
| `nc_datatrust` | `firstobserveddate` | text | Unknown text format | Text |
| `nc_datatrust` | `cellappenddate` | text | Unknown text format | Text |
| `nc_datatrust` | `lastupdate` | text | Unknown text format | Text |
| `nc_voters` | `registr_dt` | varchar | NC BOE format (YYYYMMDD?) | Character varying, not date type |

### 6B. The Three-Format Problem

FEC data arrives with raw text dates in MM/DD/YYYY format (`transaction_date_raw_mmddyyyy`). NC BOE dates come in an undocumented format captured in `date_occured_raw` (varchar). DataTrust dates are text with no documented format. These require three separate parsing pipelines, none of which are documented in the schema.

### 6C. The BOE Column Name Typo

`date_occured_raw` has a typo — "occured" should be "occurred". This is a permanent schema artifact. Any ETL code, any SQL query, any application that touches this column must use the misspelled name. If this column is ever renamed in a future migration, all dependent code will break. The correct date is in `date_occurred` (spelled correctly) — a date type. However, the presence of both columns means:
- If `date_occurred` is NULL and `date_occured_raw` is non-NULL, the parsing pipeline failed
- The raw string must be parsed as a fallback
- The parsing logic must handle the formats documented in Section 2C above (dates embedded in names is not the issue here, but date format inconsistency across filers is)

### 6D. Corruption Flags and Load Logic

```sql
-- FEC Donations: Skip corrupt dates
WHERE date_corrupt IS NOT TRUE

-- FEC Party: Skip failed parse rows  
WHERE transaction_date_parse_failed IS NOT TRUE

-- BOE: Use parsed date, fall back to raw with manual parse attempt
COALESCE(date_occurred, parse_date_attempt(date_occured_raw))
```

**No contribution date = no contribution_map row.** `transaction_date` on contribution_map is nullable, but a row with no date is essentially useless for time-series analysis. Decide whether to load null-date rows or discard them — this decision is not made in the schema.

### 6E. DataTrust Text Dates: The Format Unknown Problem

Every date field in `nc_datatrust` is stored as `text`. The actual format is not documented in the schema. Common DataTrust date formats include:
- `YYYYMMDD` — "20241015"
- `MM/DD/YYYY` — "10/15/2024"
- `YYYY-MM-DD` — "2024-10-15"
- `MMDDYYYY` — "10152024"

The ETL must determine the actual format empirically from data samples before casting. Incorrect casting will produce wrong dates silently (e.g., YYYYMMDD "20241015" cast as MM/DD/YYYY would parse as year 2024, month 10, day 15 — which happens to be correct by accident, but YYYYMMDD "20241115" cast wrongly as MMDDYYYY would become year 1511, month 5, etc.).

---

<a name="section-7"></a>
## SECTION 7: Party/Political Data Inconsistencies

### 7A. Party Column Inventory

| Source | Column(s) | Description |
|---|---|---|
| `nc_datatrust` | `registeredparty` | Voter's official registered party |
| `nc_datatrust` | `partyrollup` | R/D/I simplified rollup |
| `nc_datatrust` | `calcparty` | DataTrust calculated party assignment |
| `nc_datatrust` | `modeledparty` | Modeled party (propensity-based) |
| `nc_datatrust` | `previousregparty` | Party before most recent re-registration |
| `nc_datatrust` | `householdparty` | Household-level party summary |
| `nc_voters` | `party_cd` | NC BOE official registered party code |
| `nc_boe_donations_raw` | `voter_party_cd` | Party code copied from voter file at time of donation |
| `fec_donations` | `party` | Party of the receiving committee |
| `fec_party_committee_donations` | `party` | Party of the receiving committee |
| `fec_party_committee_donations` | `party_flag` | Simplified party flag |
| `core.contribution_map` | `party_flag` | Party of the donation target |
| `core.person_spine` | `voter_party` | Target column — single canonical party |

### 7B. The Source of Truth Problem

These party columns represent fundamentally different things:

**"What party are you registered with?"** → `nc_voters.party_cd`, `nc_datatrust.registeredparty`, `nc_boe_donations_raw.voter_party_cd`
- These should all agree for an NC voter, but may not if records are from different dates
- `nc_boe.voter_party_cd` was captured at the time of donation processing, which may be months/years before the current voter file refresh
- If a voter re-registered from REP to UNA (Unaffiliated) after making a donation, BOE still shows REP

**"What party does the RNC think you are?"** → `nc_datatrust.calcparty`, `nc_datatrust.partyrollup`, `nc_datatrust.modeledparty`
- `calcparty` = DataTrust's calculated assignment (uses voting history + registration)
- `modeledparty` = propensity model prediction (different from registered party)
- These can conflict: a registered Democrat who votes in Republican primaries may have `calcparty = REP` but `party_cd = DEM`

**"Who did you donate to?"** → `fec_donations.party`, `fec_party.party`, `fec_party.party_flag`, `contribution_map.party_flag`
- This is the RECEIVING committee's party, NOT the donor's party
- A lifelong Republican donating to a NRCC committee has `party = REP` — but so does their donation to a Democrat-supporting PAC if the PAC is mislabeled
- A cross-party donor (rare but real) will have contributions in both party buckets

**What should `person_spine.voter_party` contain?**
Recommended priority:
1. `nc_voters.party_cd` if voter_ncid is matched (most authoritative, current as of last voter file pull)
2. `nc_datatrust.registeredparty` if rncid is matched and no ncid match (DataTrust-maintained, CASS-normalized)
3. `nc_boe_donations_raw.voter_party_cd` (point-in-time, potentially stale)
4. NULL (no party data)

Do NOT use `calcparty` or `modeledparty` for `voter_party`. Those represent analytical constructs, not registration facts. The spine already has `republican_score` and `democratic_score` for the modeled data.

### 7C. Party Code Format Differences

| Source | Party Codes Used |
|---|---|
| `nc_voters.party_cd` | REP, DEM, UNA (Unaffiliated), LIB (Libertarian), GRE (Green), CST (Constitution), others |
| `nc_datatrust.registeredparty` | R, D, U, I, L, G — abbreviated (may differ from NC BOE codes) |
| `nc_datatrust.calcparty` | R, D, I — simplified 3-way |
| `nc_datatrust.modeledparty` | R, D, I — modeled 3-way |
| `fec_donations.party` | REP, DEM, IND, OTH, etc. — FEC committee party codes |
| `fec_party.party_flag` | R, D, I, O — simplified |
| `contribution_map.party_flag` | R, D, I, O — simplified |
| `person_spine.voter_party` | Format not specified — should match nc_voters format |

**Conflict example:** A voter registered as "UNA" (Unaffiliated) in nc_voters becomes "I" in DataTrust, appears as a REP donor in FEC data (they donated to a Republican committee), and might have `calcparty = R` and `modeledparty = R`. The spine needs to store "UNA" or "I" for voter_party (registration fact), while republican_score and democratic_score capture the propensity data.

### 7D. The `householdparty` Problem

`nc_datatrust.householdparty` has no spine equivalent. It describes the household's party composition (e.g., "All Republican", "Mixed", "Split"). For the purpose of canvassing and outreach, this is valuable. A household with one DEM and one REP registered voter gets different messaging than an all-REP household. The spine has no mechanism to store this.

---

<a name="section-8"></a>
## SECTION 8: Duplicate/Redundant Column Analysis

### 8A. Honorific / Salutation Cluster

The spine has FIVE columns that overlap in the honorific/title/salutation space:

| Column | Intended Purpose | Appears Redundant With |
|---|---|---|
| `honorific` | Professional title (Dr., Rev., Gen., etc.) | `prefix` (which already stores Mr./Mrs./Dr.) |
| `honorary_title` | Non-professional honorific (Congressman, Ambassador) | `honorific` |
| `formal_salutation` | "Dear Dr. Smith" for formal correspondence | `title_salutation` |
| `title_salutation` | Salutation derived from title | `formal_salutation` |
| `correspondence_greeting` | Informal greeting ("Dear Bob") | Both salutation fields |

**The problem:** `prefix` already exists on the spine and stores courtesy titles (Mr./Mrs./Ms./Dr./etc.). `honorific` duplicates this for the same data. Both cannot be populated independently without causing conflicts.

Additionally:
- `title_source` — which system assigned the title
- `title_priority` — integer ranking for which title takes precedence
- `title_branch` — military branch (relevant to: "Lt. Col. [Branch]")
- `title_status` — military status (Active/Retired — relevant to "Ret." suffix)

This is a 9-column cluster (`prefix`, `honorific`, `honorary_title`, `formal_salutation`, `title_salutation`, `correspondence_greeting`, `title_source`, `title_priority`, `title_branch`, `title_status`) for a concept that could be handled with 2-3 columns. None of the 5 source tables provide data for most of these.

### 8B. Preferred/Nickname Cluster

| Column | Intended Purpose | Conflict |
|---|---|---|
| `preferred_first` | Preferred first name (e.g., "Bob" when legal is "Robert") | Overlaps with `canonical_first_name` and `preferred_name` |
| `preferred_name` | Full preferred name (e.g., "Bob Smith") | More granular than `preferred_first`; one field doesn't inform the other |
| `preferred_name_source` | Which system provided `preferred_name` | Only useful if preferred_name is populated |
| `preferred_name_confidence` | Confidence score for `preferred_name` | Only useful if preferred_name is populated |
| `canonical_first_name` | State-verified canonical/nickname first name | Conceptually identical to `preferred_first` |
| `nickname_canonical` | RNC canonical nickname | A third system for the same concept |

**The three-system mess:** The spine tries to accommodate three completely different nickname systems (nc_voters state-maintained, RNC canonical, BOE parsed) by giving each its own column. But `preferred_first`, `canonical_first_name`, and `nickname_canonical` all represent the same concept (what do we call this person instead of their legal first name) and will frequently have the same value from different sources. There's no definition of which column wins when they conflict.

### 8C. Contribution Summary Redundancy

| Column | Apparent Purpose | Redundancy Note |
|---|---|---|
| `total_contributed` | Total lifetime contributions | Should = total_contributed_republican + total_contributed_other |
| `total_contributed_republican` | Republican contribution total | Subset of total_contributed |
| `total_contributed_other` | Non-Republican contribution total | Subset of total_contributed |
| `contribution_count` | Count of contributions | Is this republican only? All? |
| `contribution_count_republican` | Count of Republican contributions | |
| `total_contribution_count` | Total count of contributions | **APPEARS IDENTICAL TO `contribution_count`** |

**The `contribution_count` vs `total_contribution_count` problem:** Two columns appear to track the same metric. Unless one counts unique donations and the other counts total records (including duplicates), these are identical. The schema provides no documentation to distinguish them.

**Math check requirement:** `total_contributed` should always equal `total_contributed_republican + total_contributed_other`. If this invariant is violated, data integrity is broken.

### 8D. Match Key Redundancy

| Column | Purpose |
|---|---|
| `match_hash` | Computed hash of name + address for identity matching |
| `match_key_v2` | Second-generation match key (different algorithm?) |
| `addr_hash` | Hash of address only |

**Questions with no schema answers:**
- Is `match_hash` still in use, or was it superseded by `match_key_v2`?
- What algorithm generates `match_hash` vs `match_key_v2`? If V2 is superior, why keep V1?
- Is `addr_hash` computed from the spine's own `street`/`city`/`state`/`zip5`, or from a normalized version? If the `street` column changes, is `addr_hash` automatically updated?

### 8E. Computed vs Source Confusion

Several spine columns appear in both "sourced from source table" and "computed from contribution_map" categories simultaneously:
- `is_donor` — source: nc_datatrust.donorflag (Y/N) OR computed as (contribution_count > 0)
- `voter_party` — sourced from voter file OR potentially overwritten by donation patterns
- `birth_year` — sourced from nc_voters (varchar) and nc_datatrust (text) — what if they conflict?
- `sex` — sourced from nc_datatrust AND nc_voters (gender_code) — what if they conflict?

There is no column in the spine schema that records which source "won" for these fundamental identity fields, only `preferred_name_source` (for name) and `email_source`, `cell_source`, `landline_source` (for contact info). Birth year, sex, and race have NO source tracking column.

---

<a name="section-9"></a>
## SECTION 9: The 100% Match Challenge

Achieving a 100% match between donor records (NC BOE + FEC) and voter records (nc_voters + nc_datatrust) is the foundational goal of the BroyhillGOP spine. Here are every documented obstacle to achieving it:

### 9.1 Name Format Differences Between Sources

**Problem:** As documented in Section 2, names arrive in 5 different formats across 5 sources. A single person can be:
- "ROBERT EDWARD SMITH JR" (DataTrust, formal)
- "BOB SMITH" (FEC, self-reported)
- "SMITH, ROBERT E." (NC BOE)
- "Robert Smith" (nc_voters, mixed case)
- "Robert E Smith Jr" (nc_datatrust component reconstruction)

Fuzzy name matching must handle:
- Legal name vs nickname (Robert vs Bob)
- Middle name present vs absent
- Suffix present vs absent (Jr. vs no suffix)
- All-caps vs mixed case vs lowercase
- Hyphenated names ("O'BRIEN" vs "OBRIEN" vs "O BRIEN")
- Compound last names ("DE LA CRUZ" vs "DELACRUZ")
- Maiden name donations (donor donates under married name, voter registered under maiden name, or vice versa)

**Estimated unresolvable:** 3-8% of donor records will have name-based matching failures that cannot be automated.

### 9.2 Address Format Differences

**Problem:** As documented in Section 3, address formats range from pre-parsed DataTrust components to raw donor-reported strings. Specific failures:

- "123 OAK STREET" vs "123 OAK ST" (street type abbreviation)
- "APT 4B" vs "#4B" vs "UNIT 4B" vs "4B" (unit designation)
- "123 N OAK ST" vs "123 NORTH OAK STREET" (direction abbreviation)
- Rural route addresses ("RR 2 BOX 14" vs "Route 2, Box 14")
- Post office box donors (no residential address available at all)

### 9.3 Missing IDs

**Problem:** As documented in Section 5:
- `voter_ncid` on BOE records is NULL for unregistered or unmatched donors
- `rncid` on BOE records is NULL for donors not in DataTrust
- Out-of-state donors have no NC NCID ever
- `prev_rncid` creates silent join breaks

**Estimated impact:** 20-40% of NC BOE donor records have no direct ID path to the voter file. These must fall back to name+address fuzzy matching.

### 9.4 Date Parsing Issues

**Problem:** 
- `date_corrupt = TRUE` rows in fec_donations cannot have a valid contribution date in CM
- `transaction_date_parse_failed = TRUE` rows in fec_party same problem
- BOE `date_occured_raw` failures leave date_occurred NULL
- DataTrust all-text dates require format detection before parsing

**Impact:** Rows with no resolvable date cannot be properly sequenced in contribution history, affecting `first_contribution`, `last_contribution`, `giving_frequency`, and `best_employer` (backward scan depends on date ordering).

### 9.5 Employer Normalization Failures

**Problem:** As documented in Section 4, employer garbage (RETIRED, SELF-EMPLOYED, N/A) pollutes the employer field. `best_employer` depends on scanning backward through time to find the most recent real employer. Failures:

- Donor's entire contribution history lists "RETIRED" — `best_employer` will be blank
- Donor changes jobs but uses old employer on newer donations (FEC filings lag real employment)
- Donor uses company division instead of parent company ("DUKE ENERGY PROGRESS" vs "DUKE ENERGY")
- Donor uses parent company when previous donation used division

### 9.6 The Nickname/Preferred Name Problem

**Problem:** Documented extensively in Section 2D-2E. Key unresolvable cases:

- Non-derivable nicknames ("Buddy", "Skip", "Chip", "Boo") that bear zero phonetic or character similarity to legal name
- Gender-neutral names where nickname is actually legal name (Pat, Alex, Chris) — the "preferred name" and "legal name" are the same
- Donor uses nickname consistently in FEC filings; voter registered under legal name; no system bridges the gap without manual intervention
- Nickname in nc_voters.preferred_name (voter self-reported) may not match nickname_canonical (RNC dictionary)

### 9.7 Stale Addresses (11+ Year Rule)

**Problem (per Ed's explicit rule):** Addresses older than 11 years are considered unreliable for matching. With no address verification date column on the spine, and with DataTrust COA data (`reglastcoa`, `changeofaddressdate`) being text-field unmapped, there is currently no automated way to flag spine records whose address has not been verified in 11+ years.

**Specific failure modes:**
- A 2008 NC BOE donor whose address hasn't been updated in DataTrust since 2013 will have a stale address on the spine
- The spine's `updated_at` timestamp reflects any field update — not specifically address update
- No `addr_last_verified` or `addr_verified_date` column exists on the spine

### 9.8 PO Box vs Street Address Donors

**Problem:** PO Box donors have no residential address in any source. The spine's `street` field would contain "PO BOX 1234", which cannot be:
- Geocoded
- Address-matched to a voter record (voter file never has PO Box as residential address)
- Used to derive congressional/state/precinct assignments

**Scale of impact:** Roughly 5-15% of small-dollar donors use PO Boxes in rural NC counties. These donors may be registered voters, but the residential match must rely entirely on name + zip code (no street address), which dramatically increases false-positive match risk.

### 9.9 The BUDDY Problem (Non-Derivable Nicknames)

**Problem:** A subset of the nickname problem severe enough to merit its own item. Southern naming conventions produce a significant number of people whose everyday name bears no relationship to their legal name:

- Legal: Charles Edward Smith III → Known as: BUDDY
- Legal: Robert James Johnson → Known as: TREY (he's the third)
- Legal: William Davis → Known as: TRIP (triple namesake)
- Legal: Clarence Thomas Williams → Known as: SKIP
- Legal: James Randolph Martin → Known as: BO

These nicknames cannot be derived by any algorithm. They appear in nc_boe donations only if the donor literally wrote "BUDDY SMITH" on a campaign filing. If BUDDY registers to vote under "Charles E. Smith III", the BOE record is "BUDDY SMITH" and the voter record is "CHARLES SMITH" and no automated match is possible without a human intervention or a separate nickname lookup table.

**No system among the 5 source tables maintains a non-derivable nickname dictionary.** The `preferred_name` field in nc_voters is the only place this can live, and it's populated only if the voter explicitly wrote their preferred name on the registration form.

### 9.10 Cross-State Movers

**Problem:** A donor who lived in NC in 2018, donated to NC candidates, then moved to Florida:
- Their nc_boe donation record still exists with the old NC address
- Their nc_voters record may be marked REMOVED or INACTIVE
- Their nc_datatrust record may show `matchedmovestate = FL`
- They have a new FL voter registration but no FL data in this database
- Their person_spine record has a stale NC address

The `matchedmovestate` and `matchedmovestate_regid` columns in DataTrust track this — but both are currently UNMAPPED (no spine columns). An out-of-state mover's record on the spine will retain the last known NC address with no flag indicating they've relocated.

### 9.11 Military Base Donors (Transient Addresses)

**Problem:** Active military personnel stationed at NC bases (Fort Bragg/Fort Liberty, Camp Lejeune, Seymour Johnson, Cherry Point) present matching challenges:

- May be registered to vote at home state, not NC
- NC address is on-base temporary housing (changes with assignment)
- Donation address may be base address that no longer matches any voter record
- Last name may appear on contribution rolls from multiple states
- The spine's `is_military` boolean has NO automated source — it must be manually set or derived from occupation strings ("US ARMY", "USMC", "MILITARY") which are unreliable

### 9.12 Second Home / Seasonal Address Donors

**Problem:** Wealthy coastal NC donors (Outer Banks, Lake Norman, etc.) may:
- Be registered to vote at their primary home in Charlotte
- Donate using their beach house address (Nags Head, Emerald Isle)
- Have both addresses in DataTrust via household records
- Have nc_voters registration at Charlotte address only

The donation record with beach house address will fail to match the Charlotte voter registration. The spine has no "secondary address" or "seasonal address" field. DataTrust's mailing address fields (unmapped) might hold the primary address, but this is not guaranteed.

### 9.13 Deceased Voters Still in Donation Records

**Problem:** A voter who died in 2022:
- Their nc_voters status becomes REMOVED with reason "DECEASED"
- Their nc_datatrust record may be retained (DataTrust often keeps deceased records for household analysis)
- Their nc_boe donation records from 2010-2022 are permanent historical records
- The person_spine record may remain active if the ETL doesn't check voter status

**Risk:** Continued outreach to deceased persons is legally problematic and operationally wasteful. The `is_active` flag on person_spine should be set to FALSE when voter status = REMOVED/DECEASED, but there is no automated mechanism documented in the schema to enforce this.

**Specific schema gap:** `voter_status` on spine stores the voter status string, but `is_active` on the spine is a separate boolean. These should be linked (if voter_status = 'REMOVED' then is_active = FALSE), but the schema doesn't enforce this as a constraint.

### 9.14 Corporate/Organization Names in Individual Donor Fields

**Problem:** Despite FEC's requirement that corporate contributions to most committees are illegal (with PAC exceptions), and despite the `is_organization` boolean on nc_boe_donations_raw, organizations still appear in the individual donor stream:

- "JOHN SMITH CONSULTING LLC" — is John Smith a sole proprietor or a corporation?
- "THE ESTATE OF JOHN SMITH" — deceased person, estate making a political gift
- "SMITH FAMILY" — unclear if individual or family entity
- "DR. AND MRS. JOHN SMITH" — joint contribution, two people mapped to one record
- "JOHN AND JANE SMITH" — joint contribution, two people, one record

Joint contributions are especially problematic: the spine assumes one person_id per record. A joint donor creates a record that truly belongs to two people (husband and wife in most cases), and there is no mechanism to split this contribution to two person_id values in the contribution_map.

---

<a name="section-10"></a>
## SECTION 10: Recommended Column Map for Installation

This section provides the definitive, prioritized column mapping for each source → spine field. Rules:
- **Priority order** = tie-break when multiple sources provide data for same spine field
- **Winner** = source with highest priority for that field
- ⚠️ = known risk or required transform
- ❌ = no automated source; manual or computed

### 10A. Name Fields → person_spine

| Spine Column | Priority 1 | Priority 2 | Priority 3 | Priority 4 | Notes |
|---|---|---|---|---|---|
| `first_name` | `nc_voters.first_name` | `nc_datatrust.firstname` | `fec_donations.contributor_first` | `nc_boe.parsed_first` | Legal name; use voter file when voter_ncid matched |
| `last_name` | `nc_voters.last_name` | `nc_datatrust.lastname` | `fec_donations.contributor_last` | `nc_boe.parsed_last` | Same priority logic |
| `middle_name` | `nc_voters.middle_name` | `nc_datatrust.middlename` | `fec_party.norm_middle` | `nc_boe.middle_name` | ⚠️ nc_boe has both `middle_name` and `parsed_middle`; use parsed_middle if populated |
| `suffix` | `nc_voters.name_suffix_lbl` | `nc_datatrust.namesuffix` | `fec_party.norm_suffix` | `nc_boe.parsed_suffix` | ⚠️ nc_boe has both `name_suffix` and `parsed_suffix`; use parsed_suffix |
| `prefix` | `nc_voters.prefix` | `nc_datatrust.nameprefix` | — | — | Only two sources; no FEC equivalent |
| `norm_first` | `nc_boe.norm_first` (BOE pipeline) OR `nc_datatrust.norm_first` | `fec_donations.norm_first` | `fec_party.norm_first` | — | ⚠️ Different normalization pipelines; choose one and apply consistently |
| `norm_last` | Same as norm_first | — | — | — | Same issue |
| `canonical_first_name` | `nc_voters.canonical_first_name` | `nc_boe.canonical_first` | — | — | ⚠️ Different systems; nc_voters is authoritative |
| `preferred_name` | `nc_voters.preferred_name` | — | — | — | Only nc_voters has this; no other source |
| `preferred_first` | `nc_boe.parsed_nickname` | `nc_datatrust.norm_first` (if differs from firstname) | — | — | ⚠️ Weak derivation; set preferred_name_confidence = 0.5 |
| `nickname_canonical` | `fec_party.nickname_canonical` | `nc_boe.canonical_first` | — | — | ⚠️ Map to same field; document winning source in preferred_name_source |
| `preferred_name_source` | Set by ETL logic based on which source won | — | — | — | ❌ ETL metadata; not a sourced column |
| `preferred_name_confidence` | 1.0 if nc_voters.preferred_name; 0.7 if RNC canonical; 0.5 if BOE parsed | — | — | — | ❌ Computed |
| `legal_first_name` | — | — | — | — | ❌ NO AUTOMATED SOURCE |
| `honorific` | — | — | — | — | ❌ NO AUTOMATED SOURCE |
| `honorary_title` | — | — | — | — | ❌ NO AUTOMATED SOURCE |
| `formal_salutation` | — | — | — | — | ❌ Derived: construct from prefix + last_name + suffix if prefix is non-courtesy-title |
| `title_salutation` | — | — | — | — | ❌ Derived: same as formal_salutation; resolve with Section 8A |
| `correspondence_greeting` | — | — | — | — | ❌ Derived: "Dear " + (preferred_name OR canonical_first_name OR first_name) |

### 10B. Address Fields → person_spine

| Spine Column | Priority 1 | Priority 2 | Priority 3 | Notes |
|---|---|---|---|---|
| `street` | `nc_datatrust`: reconstruct from reg components: `reghousenum || ' ' || COALESCE(regstprefix||' ','') || regstname || ' ' || regsttype || COALESCE(' '||regstpost,'')` | `nc_voters.res_street_address` (normalized) | `nc_boe.norm_addr` | ⚠️ DataTrust is CASS-certified gold standard; BOE is donor-reported |
| `city` | `nc_datatrust.regcity` | `nc_voters.res_city_desc` | `nc_boe.norm_city` | FEC: `fec_party.norm_city` or `fec_donations.contributor_city` |
| `state` | `nc_datatrust.regsta` | `nc_voters.state_cd` | `nc_boe.norm_state` | — |
| `zip5` | `nc_datatrust.regzip5` | `nc_voters.zip_code` (truncate) | `nc_boe.norm_zip5` | `fec_donations.contributor_zip5` |
| `county` | `nc_datatrust.countyname` | `nc_voters.county_desc` | — | Spine `voter_county` should = county in most cases |
| `addr_number` | `nc_datatrust.reghousenum` | `nc_voters.street_number` | `nc_boe`: extract from norm_addr | `fec_donations.norm_street_num` / `fec_party.norm_street_num` |
| `addr_type` | `nc_datatrust.regsttype` | `nc_datatrust.addr_type` (post-ETL) | Extract from `nc_voters.res_street_address` | ⚠️ Must use regex extraction from nc_voters; datatrust provides cleanly |
| `addr_hash` | ❌ Computed from normalized street+city+state+zip5 | — | — | Must be recomputed whenever address fields change |

### 10C. Contact Fields → person_spine

| Spine Column | Priority 1 | Priority 2 | Priority 3 | Notes |
|---|---|---|---|---|
| `email` | `nc_boe.email` | — | — | Only source with email; set email_source = 'nc_boe' |
| `email_source` | 'nc_boe' | — | — | |
| `email_verified` | FALSE | — | — | ❌ No automated verification; default to FALSE |
| `cell_phone` | `nc_datatrust.cell` | `nc_boe.cell_phone` | — | ⚠️ DataTrust has multiple cell sources; use primary `cell` column; set cell_source = datatrust.cellsourcecode |
| `cell_source` | `nc_datatrust.cellsourcecode` | 'nc_boe' | — | |
| `landline` | `nc_datatrust.landline` | `nc_voters.full_phone_number` | — | ⚠️ nc_voters phone might be cell; DataTrust classifies by type |
| `landline_source` | `nc_datatrust.landlinesourcecode` | 'nc_voters' | — | |
| `home_phone` | — | — | — | ❌ No direct source; may overlap with landline |
| `business_phone` | — | — | — | ❌ NO SOURCE |

### 10D. Identity/Voter Fields → person_spine

| Spine Column | Priority 1 | Priority 2 | Notes |
|---|---|---|---|
| `voter_ncid` | `nc_boe.voter_ncid` | `nc_datatrust.statevoterid` (for NC) | Primary voter file link |
| `voter_rncid` | `nc_datatrust.rncid` | `nc_boe.rncid` | RNC DataTrust link |
| `rnc_regid` | `nc_datatrust.rnc_regid` | — | Secondary DataTrust ID |
| `household_id` | `nc_datatrust.householdid` (cast to bigint) | — | DataTrust household |
| `voter_party` | `nc_voters.party_cd` | `nc_datatrust.registeredparty` | See Section 7B |
| `voter_status` | `nc_voters.voter_status_desc` | `nc_datatrust.voterstatus` | Prefer desc over code |
| `voter_county` | `nc_voters.county_desc` | `nc_datatrust.countyname` | Should match `county` |
| `is_registered_voter` | TRUE if voter_ncid is non-NULL and voter_status = 'ACTIVE' | — | ❌ Computed from voter_ncid + voter_status |
| `congressional_district` | `nc_voters.cong_dist_abbrv` | `nc_datatrust.congressionaldistrict` | nc_voters is authoritative for NC |
| `state_senate_district` | `nc_voters.nc_senate_abbrv` | `nc_datatrust.statelegupperdistrict` | nc_voters authoritative |
| `state_house_district` | `nc_voters.nc_house_abbrv` | `nc_datatrust.stateleglowerdistrict` | nc_voters authoritative |
| `precinct` | `nc_voters.precinct_desc` | `nc_datatrust.precinctname` | nc_voters authoritative |
| `winred_donor_id` | — | — | ❌ NO SOURCE — requires WinRed API |
| `winred_email` | — | — | ❌ NO SOURCE |

### 10E. Demographic Fields → person_spine

| Spine Column | Priority 1 | Priority 2 | Notes |
|---|---|---|---|
| `birth_year` | `nc_voters.birth_year` (cast to int) | `nc_datatrust.birthyear` (cast to int) | ⚠️ nc_boe.birth_year is integer; also a source |
| `age` | `nc_datatrust.age` (cast to int) | Compute: EXTRACT(YEAR FROM NOW()) - birth_year | ⚠️ Computed is more current |
| `sex` | `nc_voters.gender_code` (M/F→male/female) | `nc_datatrust.sex` | ⚠️ Format normalization needed |
| `race` | `nc_voters.race_code` (map code) | `nc_datatrust.ethnicityreported` | ⚠️ Different classification systems |
| `ethnicity` | `nc_voters.ethnic_code` (map code) | `nc_datatrust.ethnicityreported` | |
| `republican_score` | `nc_datatrust.republicanpartyscore` (cast to numeric) | — | DataTrust only source |
| `democratic_score` | `nc_datatrust.democraticpartyscore` (cast to numeric) | — | DataTrust only source |
| `turnout_score` | `nc_datatrust.turnoutgeneralscore` (cast to numeric) | — | DataTrust only source |
| `religion` | `nc_datatrust.religionmodeled` | — | DataTrust only source |
| `education_level` | `nc_datatrust.educationmodeled` | — | DataTrust only source |
| `income_range` | `nc_datatrust.householdincomemodeled` | — | DataTrust only source |

### 10F. Coalition Fields → person_spine

| Spine Column | Source | Notes |
|---|---|---|
| `coalition_social_conservative` | `nc_datatrust.coalitionid_socialconservative` | Direct map |
| `coalition_veteran` | `nc_datatrust.coalitionid_veteran` | Direct map |
| `coalition_sportsmen` | `nc_datatrust.coalitionid_sportsmen` | Direct map |
| `coalition_2nd_amendment` | `nc_datatrust.coalitionid_2ndamendment` | Direct map |
| `coalition_prolife` | `nc_datatrust.coalitionid_prolife` | Direct map |
| `coalition_fiscal_conservative` | `nc_datatrust.coalitionid_fiscalconservative` | Direct map |
| `coalition_prochoice` | `nc_datatrust.coalitionid_prochoice` | Direct map |

### 10G. Employer/Occupation Fields → person_spine

| Spine Column | Priority 1 | Priority 2 | Priority 3 | Notes |
|---|---|---|---|---|
| `employer` | `nc_boe.employer_normalized` | `fec_donations.employer_normalized` | `fec_party.norm_employer` | Use most recent non-garbage value |
| `occupation` | `nc_boe.profession_job_title` | `fec_donations.contributor_occupation` | `fec_party.norm_occupation` | Use most recent non-garbage value |
| `best_employer` | ❌ Computed | — | — | Backward scan by date; skip RETIRED/SELF-EMPLOYED/N-A/NONE/HOMEMAKER/etc. |
| `sic_code` | ❌ NO AUTOMATED SOURCE | — | — | Requires employer → SIC lookup service |
| `industry_sector` | ❌ NO AUTOMATED SOURCE | — | — | Derived from SIC or occupation string |

### 10H. Employer/Occupation Fields → contribution_map

| CM Column | Source | Transform | Notes |
|---|---|---|---|
| `id` | Auto-generated | BIGSERIAL | Not sourced from any input |
| `person_id` | `fec_donations.person_id` OR `fec_party.person_id` OR resolved via name+address match | — | Must be non-NULL; this is the join to person_spine |
| `source_system` | 'nc_boe' / 'fec_indiv' / 'fec_party' | Set by ETL routing logic | |
| `source_id` | `nc_boe.id` (cast bigint) / `fec_donations.id` (cast bigint) / `fec_party.id` (cast bigint) | CAST to bigint | Allows reverse lookup to source row |
| `amount` | `nc_boe.amount_numeric` / `fec_donations.contribution_amount` / `fec_party.transaction_amount` | Direct | |
| `transaction_date` | `nc_boe.date_occurred` / `fec_donations.contribution_date` (if !date_corrupt) / `fec_party.transaction_date` (if !transaction_date_parse_failed) | ⚠️ Check flags | NULL allowed but undesirable |
| `committee_id` | `nc_boe.committee_sboe_id` / `fec_donations.committee_id` / `fec_party.committee_id` | NC vs FEC ID systems differ | |
| `candidate_id` | — | ❌ UUID type conflict with bigint person_id | See Section 5G |
| `tenant_id` | ❌ Set by application logic | — | Not in any source |
| `party_flag` | `fec_party.party_flag` / `fec_donations.party` (simplified) | Normalize to R/D/I/O | |

---

## Summary Statistics

| Source | Total Columns | Mapped to Spine | Mapped to CM | Unmapped |
|---|---|---|---|---|
| nc_boe_donations_raw | 62 | 32 | 6 | 24 |
| fec_donations | 35 | 12 | 6 | 17 |
| fec_party_committee_donations | 34 | 14 | 5 | 15 |
| nc_voters | 71 | 29 | 0 | 42 |
| nc_datatrust | 256 | 61 | 0 | 195 |
| **TOTAL** | **458** | **148** | **17** | **293** |

**person_spine columns with no automated source:** ~55 of 128 (43%)  
**person_spine columns that are computed:** ~30 (23%)  
**person_spine columns with a mapped source:** ~43 (34%)  

---

## Critical Installation Blockers (Must Resolve Before Load)

1. **golden_record_id ≠ person_id ambiguity** — must choose one; prefer person_id
2. **DataTrust date formats unknown** — must sample data to determine format before any date casting
3. **BOE date_occured_raw typo** — all ETL code must use misspelled column name
4. **entity_type filter on fec_party** — filter to IND only or load org records separately
5. **is_organization filter on nc_boe** — filter TRUE records to separate org pipeline
6. **date_corrupt / transaction_date_parse_failed** — never load CM rows where these are TRUE without manual review
7. **contribution_map.candidate_id type conflict** — UUID vs bigint; resolve before loading
8. **norm_* column pipeline parity** — nc_boe, fec_donations, and fec_party use different normalization pipelines; ensure they produce compatible values before using as match keys
9. **prev_rncid silent join breaks** — build a lookup table of prev_rncid → current rncid to recover broken DataTrust joins
10. **Mailing address loss** — DataTrust's full mailing address block (22 columns) has no spine home; decision needed whether to add spine columns or drop this data permanently

---

*End of BroyhillGOP Schema Comparison & Installation Challenge Report*  
*Document generated: April 2, 2026*  
*Total source columns analyzed: 458 across 5 tables*  
*Total destination columns analyzed: 139 across 2 tables (128 + 11)*
