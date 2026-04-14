# raw.ncboe_donations — Column Schema & Mapping

**Created:** April 12, 2026 11:05 PM EDT  
**Author:** Perplexity Computer  
**Authority:** Ed Broyhill | NC National Committeeman  
**Table:** `raw.ncboe_donations` on Hetzner PostgreSQL (37.27.169.232)  
**Row count:** 2,431,198 (verified across all 18 GOLD files)

---

## Source Files

18 GOLD CSV files in `/data/ncboe/gold/`, all sharing identical 24-column headers:

| File | Rows |
|---|---|
| County-Municipal-100-counties-GOP-2015-2026.csv | 451,483 |
| NC-House-Gop++-2015-2026.csv | 407,499 |
| NC-Senate-Gop-2015-2026.csv | 321,585 |
| sheriff-only-gop-100-counties.csv | 272,481 |
| Judicial-gop-100-counties-2015-2026.csv | 170,002 |
| 2015-2026-supreme-court-appeals-.csv | 144,143 |
| 2015-2026-NC-Council-of-state.csv | 96,363 |
| 2ndary-counties-muni-cty-gop-2015-2026.csv | 96,273 |
| governor-2015-2026.csv | 96,093 |
| 2ndary-sheriff-gop-2015-2026.csv | 75,550 |
| District-ct-judge-gop-100-counties-2015-2026.csv | 64,708 |
| Council-commissioners-gop-2015-2026.csv | 55,965 |
| council-city-town-gop-2015-2026.csv | 51,425 |
| District-Att-gop-100 counties-2015-2026.csv | 46,069 |
| 2015-2025-lt-governor.csv | 31,793 |
| school-board-gop-2015-2026.csv | 25,834 |
| 2015-2026-Mayors.csv | 18,281 |
| clerk-court-gop-2015-2026.csv | 5,651 |

---

## 24 Original CSV Columns → Database Mapping

All 24 columns preserved with no renames and no drops. Column names converted from title case to snake_case. Non-null counts verified against raw CSV source using Python `csv` module.

| # | CSV Header | DB Column | Data Type | Non-Null Count | % Filled |
|---|---|---|---|---|---|
| 1 | Name | `name` | text | 2,431,195 | 100.0% |
| 2 | Street Line 1 | `street_line_1` | text | 1,779,287 | 73.2% |
| 3 | Street Line 2 | `street_line_2` | text | 60,979 | 2.5% |
| 4 | City | `city` | text | 1,769,272 | 72.8% |
| 5 | State | `state` | text | 2,431,198 | 100.0% |
| 6 | Zip Code | `zip_code` | text | 1,746,848 | 71.8% |
| 7 | Profession/Job Title | `profession_job_title` | text | 1,859,593 | 76.5% |
| 8 | Employer's Name/Specific Field | `employer_name` | text | 1,704,078 | 70.1% |
| 9 | Transction Type | `transction_type` | text | 2,431,198 | 100.0% |
| 10 | Committee Name | `committee_name` | text | 2,431,198 | 100.0% |
| 11 | Committee SBoE ID | `committee_sboe_id` | text | 2,431,198 | 100.0% |
| 12 | Committee Street 1 | `committee_street_1` | text | 2,431,198 | 100.0% |
| 13 | Committee Street 2 | `committee_street_2` | text | 84,364 | 3.5% |
| 14 | Committee City | `committee_city` | text | 2,431,198 | 100.0% |
| 15 | Committee State | `committee_state` | text | 2,431,198 | 100.0% |
| 16 | Committee Zip Code | `committee_zip_code` | text | 2,431,198 | 100.0% |
| 17 | Report Name | `report_name` | text | 2,431,198 | 100.0% |
| 18 | Date Occured | `date_occured` | text | 2,431,198 | 100.0% |
| 19 | Account Code | `account_code` | text | 2,431,198 | 100.0% |
| 20 | Amount | `amount` | text | 2,431,195 | 100.0% |
| 21 | Form of Payment | `form_of_payment` | text | 2,429,711 | 99.9% |
| 22 | Purpose | `purpose` | text | 28 | 0.0% |
| 23 | Candidate/Referendum Name | `candidate_referendum_name` | text | 0 | 0.0% |
| 24 | Declaration | `declaration` | text | 0 | 0.0% |

**Notes on sparse columns:**
- `purpose` (28 rows), `candidate_referendum_name` (0 rows), `declaration` (0 rows) — verified empty in source CSVs, not a load error
- `name` and `amount` show 2,431,195 = 3 unitemized donation rows with no donor name/amount
- `street_line_2` at 2.5% is expected — most donors have single-line addresses

---

## 26 Added Columns (not from CSV)

### Infrastructure (2 columns)

| DB Column | Data Type | Purpose | Added By |
|---|---|---|---|
| `id` | bigint (PK) | Auto-generated row identifier | Table DDL |
| `source_file` | text | Tracks which of the 18 GOLD files each row came from | bulletproof_load.py |

### Phase 2 Normalization (17 columns)

Added by `phase2_normalize.py` — all 2,431,198 rows populated.

| DB Column | Data Type | Purpose | Source Column(s) |
|---|---|---|---|
| `norm_last` | text | Normalized last name (uppercase, stripped) | Parsed from `name` |
| `norm_first` | text | Normalized first name | Parsed from `name` |
| `norm_middle` | text | Middle name/initial if present | Parsed from `name` |
| `norm_suffix` | text | Suffix (Jr., Sr., III, etc.) | Parsed from `name` |
| `norm_prefix` | text | Prefix/title (Dr., Rev., etc.) | Parsed from `name` |
| `norm_nickname` | text | Nickname if detected in name | Parsed from `name` |
| `norm_zip5` | text | First 5 digits of zip code | Derived from `zip_code` |
| `norm_city` | text | Normalized city name (uppercase, standardized) | Derived from `city` |
| `norm_employer` | text | Normalized employer name | Derived from `employer_name` |
| `employer_sic_code` | text | SIC industry code from employer_sic_master | Looked up from `norm_employer` |
| `employer_naics_code` | text | NAICS industry code | Looked up from `norm_employer` |
| `norm_amount` | numeric | Parsed numeric amount | Derived from `amount` |
| `norm_date` | date | Parsed date | Derived from `date_occured` |
| `address_numbers` | text[] (ARRAY) | All numeric values from address fields (house#, PO box#, suite#, etc.) | Extracted from `street_line_1`, `street_line_2` |
| `all_addresses` | text[] (ARRAY) | All complete addresses as array | Assembled from `street_line_1`, `street_line_2`, `city`, `state`, `zip_code` |
| `year_donated` | integer | Year extracted from donation date | Derived from `date_occured` |
| `is_unitemized` | boolean | True if donation is unitemized (no named donor) | Derived from `name` |

### Dedup / Voter Match (6 columns)

Columns exist but are NULL — dedup has NOT been run yet.

| DB Column | Data Type | Purpose | Populated By |
|---|---|---|---|
| `cluster_id` | bigint | Internal dedup cluster identifier (Stage 1) | ncboe_internal_dedup.py (pending) |
| `cluster_profile` | jsonb | JSON profile with name variants, addresses, employers, committees, totals | ncboe_internal_dedup.py (pending) |
| `rnc_regid` | text | RNC/DataTrust voter registration ID (Stage 2 match) | Voter file matching (pending) |
| `match_pass` | integer | Which match pass linked this donor (1-8) | Voter file matching (pending) |
| `match_confidence` | numeric | Confidence score of the voter match (0.0–1.0) | Voter file matching (pending) |
| `is_matched` | boolean | Whether donor has been matched to voter file | Voter file matching (pending) |

### Timestamp (1 column)

| DB Column | Data Type | Purpose |
|---|---|---|
| `created_at` | timestamptz | Row creation timestamp |

---

## Column Count Summary

| Category | Count |
|---|---|
| Original CSV columns (preserved) | 24 |
| Infrastructure (id, source_file) | 2 |
| Phase 2 normalization | 17 |
| Dedup / voter match (pending) | 6 |
| Timestamp | 1 |
| **Total** | **50** |

---

## Critical Rules

1. **ED maps to EDGAR, never EDWARD** — enforced in name parser
2. **All 24 raw columns are immutable** — never modify source data, only add norm_* columns
3. **3 unitemized rows** have NULL name/amount — this is correct, do not delete them
4. **Dedup columns are NULL** — `ncboe_internal_dedup.py` has NOT been run (and should NOT be run in current form — see DEDUP_AUDIT_REPORT.md)

---

*This schema was verified on April 12, 2026 by cross-checking every column's non-null count between the raw CSV files (via Python csv module) and the PostgreSQL table.*
