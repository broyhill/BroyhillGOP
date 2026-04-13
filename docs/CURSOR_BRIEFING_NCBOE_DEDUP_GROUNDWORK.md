# CURSOR BRIEFING: NCBOE DEDUP GROUNDWORK COMPLETE
**Date: April 13, 2026 — 01:00 AM EDT**
**Author: Perplexity Computer on behalf of Ed Broyhill**
**Authority: Ed Broyhill — NC Republican National Committeeman**

---

## READ THIS FIRST

This document is the single source of truth for what has been done, what's on disk, and what comes next. The internal dedup of `raw.ncboe_donations` is **COMPLETE AND APPLIED**. The database is live. Every row has a `cluster_id` and a `cluster_profile` (JSONB). 193,868 previously-dark donors now have an `rnc_regid` via cluster propagation.

**DO NOT re-run the dedup.** Do not modify `ncboe_dedup_v2.py`. Do not reset `cluster_id` or `cluster_profile`. The dedup plan was painstakingly designed with Ed over many hours and iterated 10+ times. It is non-negotiable.

If you need to understand the dedup logic, read `/opt/broyhillgop/sessions/DONOR_DEDUP_PIPELINE_V2.md` (the canonical plan) and `/opt/broyhillgop/ncboe_dedup_v2.py` (the applied script — 946 lines of Python).

---

## TABLE OF CONTENTS

1. [Server Environment](#1-server-environment)
2. [Database Schema & Tables](#2-database-schema--tables)
3. [NCBOE Donations Table — Complete Column Reference](#3-ncboe-donations-table--complete-column-reference)
4. [Dedup: What Was Done (Stage-by-Stage)](#4-dedup-what-was-done-stage-by-stage)
5. [Dedup Results Summary](#5-dedup-results-summary)
6. [Cluster Profile Schema (JSONB)](#6-cluster-profile-schema-jsonb)
7. [Household Linkage](#7-household-linkage)
8. [RNC RegID Propagation (Dark Donor Rescue)](#8-rnc-regid-propagation-dark-donor-rescue)
9. [Ed Broyhill Family — Proof-of-Correctness Canary](#9-ed-broyhill-family--proof-of-correctness-canary)
10. [DataTrust Voter File Reference](#10-datatrust-voter-file-reference)
11. [Acxiom Tables Reference](#11-acxiom-tables-reference)
12. [Known Data Issues & Landmines](#12-known-data-issues--landmines)
13. [What Comes Next (Ordered)](#13-what-comes-next-ordered)
14. [Files on Server](#14-files-on-server)
15. [Critical Rules (Non-Negotiable)](#15-critical-rules-non-negotiable)

---

## 1. Server Environment

| Item | Value |
|------|-------|
| **Host** | Hetzner — 37.27.169.232 |
| **OS** | Ubuntu 24.04.4 LTS |
| **CPU** | 2 vCPU |
| **Disk** | 1.8 TB total, 222 GB used (14%) |
| **RAM usage** | 4% |
| **PostgreSQL** | Local, port 5432 |
| **DB connstring** | `postgresql://postgres:Anamaria%402026%40@127.0.0.1:5432/postgres` |
| **Supabase project** | `isbgjpnbocdkeslofota` |
| **GitHub repo** | `broyhill/BroyhillGOP`, branch `main` |
| **Last git commit** | `8412b6a` — NCBOE GOLD file audit script |

### Active Screen Sessions

| Screen | Status | Purpose |
|--------|--------|---------|
| `relay` | Running (since Apr 11) | Relay service |
| `acxrestructure` | Running (since Apr 12) | Acxiom IBE load — still in progress |

---

## 2. Database Schema & Tables

### Schemas
`archive`, `audit`, `core`, `donor_intelligence`, `norm`, `public`, `raw`, `staging`, `volunteer`

### Tables (by size)

| Table | Rows | Size | Status |
|-------|------|------|--------|
| `core.acxiom_consumer_nc` | 7,655,593 | 89 GB | Loaded — 22 columns, key Acxiom consumer fields |
| `core.acxiom_ibe` | 4,450,000 | 18 GB | **STILL LOADING** in screen `acxrestructure` — 911 columns |
| `core.acxiom_ap_models` | 7,655,593 | 16 GB | Loaded — ~420 columns of AP model scores |
| `core.datatrust_voter_nc` | 7,727,637 | 12 GB | Loaded — 252 columns, NC voter file |
| `raw.ncboe_donations` | 2,431,198 | 5.3 GB | **DEDUP APPLIED** — 58 columns |
| `core.acxiom_market_indices` | 0 | 16 KB | Empty — schema only |
| `donor_intelligence.employer_sic_master` | 0 | 32 KB | **EMPTY** — schema exists (6 cols), no data loaded |

### donor_intelligence.employer_sic_master — IMPORTANT

The schema exists with columns: `employer_raw`, `employer_normalized`, `sic_code`, `naics_code`, `industry_sector`, `match_confidence`. But the table has **ZERO rows**. The dedup plan (Stage 1B) references "62,100 mappings" but those were never loaded. The dedup script works without it — it uses raw `norm_employer` as-is. SIC-based employer normalization is a **future enhancement**, not a current dependency.

---

## 3. NCBOE Donations Table — Complete Column Reference

**Table:** `raw.ncboe_donations` — 2,431,198 rows, 58 columns

### Original NCBOE columns (raw from state filings)

| Column | Type | Description |
|--------|------|-------------|
| `id` | bigint (PK) | Auto-increment primary key |
| `source_file` | text NOT NULL | Which NCBOE file this row came from |
| `name` | text | Raw donor name as filed |
| `street_line_1` | text | Raw address line 1 |
| `street_line_2` | text | Raw address line 2 |
| `city` | text | Raw city |
| `state` | text | Raw state |
| `zip_code` | text | Raw zip code |
| `profession_job_title` | text | Raw profession/job title |
| `employer_name` | text | Raw employer name |
| `transction_type` | text | Transaction type (note: typo in original NCBOE data — "transction" not "transaction") |
| `committee_name` | text | Committee receiving donation |
| `committee_sboe_id` | text | Committee SBOE identifier |
| `committee_street_1` | text | Committee address |
| `committee_street_2` | text | Committee address line 2 |
| `committee_city` | text | Committee city |
| `committee_state` | text | Committee state |
| `committee_zip_code` | text | Committee zip |
| `report_name` | text | NCBOE report name |
| `date_occured` | text | Raw date — NOTE: column name has typo "occured" not "occurred" |
| `account_code` | text | Account code |
| `amount` | text | Raw amount **AS TEXT** — do not use for math, use `norm_amount` instead |
| `form_of_payment` | text | Payment method |
| `purpose` | text | Purpose of donation |
| `candidate_referendum_name` | text | Candidate or referendum name |
| `declaration` | text | Declaration text |

### Normalized columns (added by pipeline)

| Column | Type | Description |
|--------|------|-------------|
| `norm_last` | text | Normalized last name (uppercase, cleaned) |
| `norm_first` | text | Normalized first name (uppercase, cleaned) |
| `norm_middle` | text | Normalized middle name/initial |
| `norm_suffix` | text | Suffix (JR, SR, II, III, IV) |
| `norm_prefix` | text | Name prefix |
| `norm_nickname` | text | Nickname extracted from name |
| `norm_zip5` | text | 5-digit zip |
| `norm_city` | text | Normalized city name |
| `norm_employer` | text | Normalized employer (uppercase, basic cleaning — NOT SIC-based) |
| `employer_sic_code` | text | SIC code — mostly NULL (employer_sic_master is empty) |
| `employer_naics_code` | text | NAICS code — mostly NULL |
| `norm_amount` | numeric | Parsed numeric amount — **USE THIS FOR ALL MATH** |
| `norm_date` | date | Parsed date |
| `address_numbers` | text[] | Array of all numbers extracted from address fields |
| `all_addresses` | text[] | Array of all full addresses (concatenated street+city+state+zip) |
| `year_donated` | integer | Year extracted from donation date |
| `is_unitemized` | boolean | Whether this is an unitemized donation |

### DataTrust enrichment columns

| Column | Type | Description |
|--------|------|-------------|
| `rnc_regid` | text | RNC voter ID — the master identifier linking to voter file. **53.2% coverage** (1,293,069 / 2,431,198) |
| `match_pass` | integer | Which DataTrust matching pass assigned this rnc_regid |
| `match_confidence` | numeric | Confidence score of the DataTrust match |
| `is_matched` | boolean | Whether DataTrust matched this row |
| `state_voter_id` | text | NC state voter ID (e.g., BN94856) |
| `dt_first` | text | DataTrust canonical first name |
| `dt_middle` | text | DataTrust canonical middle name |
| `dt_last` | text | DataTrust canonical last name |
| `dt_suffix` | text | DataTrust suffix |
| `dt_prefix` | text | DataTrust prefix |
| `dt_zip4` | text | DataTrust zip+4 |
| `dt_house_hold_id` | integer | DataTrust household ID — used for household linkage |
| `dt_match_method` | text | How the rnc_regid was assigned (see section 8) |

### Dedup columns (written by ncboe_dedup_v2.py)

| Column | Type | Description |
|--------|------|-------------|
| `cluster_id` | bigint | Dedup cluster identifier — all rows with same cluster_id are the same person |
| `cluster_profile` | jsonb | Rich JSONB profile with all aggregated data for the cluster (see section 6) |
| `created_at` | timestamptz | Row creation timestamp |

### Indexes on raw.ncboe_donations

| Index | Columns | Purpose |
|-------|---------|---------|
| `ncboe_donations_pkey` | id | Primary key |
| `idx_ncboe_cluster` | cluster_id | Cluster lookups |
| `idx_ncboe_rnc` | rnc_regid | Voter file joins |
| `idx_ncboe_name` | norm_last, norm_first | Name search |
| `idx_ncboe_last_zip` | norm_last, norm_zip5 | Name+zip lookup (dedup key) |
| `idx_ncboe_zip` | norm_zip5 | Zip code filtering |
| `idx_ncboe_employer` | norm_employer | Employer search |
| `idx_ncboe_date` | norm_date | Date range queries |
| `idx_ncboe_committee` | committee_sboe_id | Committee filtering |
| `idx_ncboe_candidate` | candidate_referendum_name | Candidate filtering |
| `idx_ncboe_sic` | employer_sic_code | SIC lookup (mostly null) |
| `idx_ncboe_source` | source_file | Source file filtering |

---

## 4. Dedup: What Was Done (Stage-by-Stage)

The dedup uses a **Union-Find** data structure with path compression and union-by-min-id. All stages run sequentially in one pass over 2.4M rows. The script loads everything into memory (~4GB peak), runs stages 1A–1G, builds cluster profiles, computes household linkage, then writes back to the database.

### Stage 1A: Exact Match (last + first + zip5)
- **Key:** `(norm_last, norm_first, norm_zip5)`
- **Logic:** If two rows share all three, they are the same person filing consistently.
- **Result:** 1,642,977 merges
- **This is the workhorse** — catches 98% of easy cases.

### Stage 1B: Employer Cluster (last + employer + city)
- **Key:** `(norm_last, norm_employer, norm_city)`
- **Guard:** Skips generic employers: RETIRED, SELF-EMPLOYED, SELF EMPLOYED, NOT EMPLOYED, NONE, N/A, NA, HOMEMAKER, STUDENT, UNEMPLOYED, NO EMPLOYER, INFORMATION REQUESTED, INFORMATION REQUESTED PER BEST EFFORTS
- **Why the guard:** Without it, all retired BROYHILLs in WINSTON-SALEM merge into one cluster. This was the original spouse-merge bug.
- **Result:** 19,458 merges (407,000+ generic skipped)
- **Generic employer counts in the database:**
  - SELF-EMPLOYED: 154,086
  - NOT EMPLOYED: 128,829
  - RETIRED: 114,918
  - HOMEMAKER: 13,591
  - UNEMPLOYED: 12,025
  - STUDENT: 714
  - VOLUNTEER: 61

### Stage 1C: Committee Fingerprint (last + zip5 + 3+ shared committees)
- **Key:** `(norm_last, norm_zip5)` with min 3 shared `committee_sboe_id` values
- **Guard:** Before merging, checks that the two clusters don't have conflicting `rnc_regid` sets. If cluster A has regid X and cluster B has regid Y (and X ≠ Y), the merge is blocked — they're confirmed different people at the same address.
- **Result:** 67 merges, 224 blocked
- **Note:** This stage rarely fires because 1A already captures most same-name-same-zip donors. But it's the safety net for when first names differ across committees.

### Stage 1D: Address Number Cross-Name (last + zip + addr_num + first-name guard)
- **Key:** `(norm_last, norm_zip5, address_number)` from the `address_numbers` array
- **Guard 1 — RNC RegID conflict:** If both rows have different rnc_regids → block
- **Guard 2 — First-name compatibility:** Uses `_first_names_compatible()`:
  - Same name → compatible
  - One is single letter matching other's initial → compatible (J ↔ JAMES)
  - One is prefix of other, both ≥ 2 chars → compatible (ED ↔ EDGAR)
  - Otherwise → incompatible (blocks ED ↔ MELANIE, JAMES ↔ LOUISE)
- **Why this exists:** At the same address, "JAMES BROYHILL" and "EDGAR BROYHILL" should merge (same person — ED's legal first name is JAMES EDGAR). But "ED BROYHILL" and "MELANIE BROYHILL" must NOT merge (spouse).
- **Result:** 1,176 merges, ~150,000 blocked (spouse/family guard)

### Stage 1E: Name Variant Cross-Cluster Merge (last + zip, overlapping first-name sets)
- **Logic:** After 1A-1D, collect all first-name variants per cluster. If two clusters share (last, zip) and their first-name sets overlap OR one name is a prefix of another (≥ 2 chars), merge.
- **Example:** Cluster A has {ED}, cluster B has {EDGAR}. ED is prefix of EDGAR → merge.
- **Result:** 357 merges
- **This is the iterative pass** that catches name variants after initial clustering.

### Stage 1F: Employer History Bridge (RETIRED problem)
- **Logic:** If cluster A was at employer "ANVIL VENTURES" and cluster B says "RETIRED" but they share the same last+zip, and cluster A's first names are compatible with cluster B's, merge them.
- **The actual logic:** Builds (last, zip, employer) → cluster mapping for non-generic employers, then for generic-employer clusters, checks if any other cluster at same (last, zip) has a compatible first name.
- **Result:** 43 merges
- **Why so few:** Most of these cases were already caught by 1D or 1E. This is the catch-all for the remaining RETIRED→career-employer links.

### Stage 1G: Cross-Zip Merge (multi-address / second homes)

Two approaches:

**Approach 1 — Employer across zips:**
- Key: `(norm_last, norm_first, norm_employer)` where employer is NOT generic
- Requires: entries from at least 2 different zip codes
- Guard: rnc_regid conflict check
- Catches: ED BROYHILL / ANVIL in 27104 and ED BROYHILL / ANVIL in 27012 → same person
- Result: 1,029 merges

**Approach 2 — Address number across zips:**
- Key: `(norm_last, norm_first, address_number)` across different zips
- Catches: JAMES BROYHILL at house 1930 in 27104 and JAMES BROYHILL at house 1930 in 27012 → same person who moved
- Guard: rnc_regid conflict check
- Result: 7,981 merges

**Total 1G:** 9,010 merges (1,029 employer + 7,981 address)

---

## 5. Dedup Results Summary

| Metric | Value |
|--------|-------|
| **Total rows** | 2,431,198 |
| **Total clusters** | 758,110 |
| **Singleton clusters** | 677,335 (89.3% — one-time donors) |
| **Multi-row clusters** | 80,775 |
| **Largest cluster** | 7,803 rows |
| **Top 10 clusters** | 7803, 5729, 4790, 3770, 3427, 2957, 2734, 2589, 2475, 2414 |
| **Total donation amount** | $1,199,211,944.32 |
| **Date range** | 2015–2026 (plus a few bad-year rows: 2029, 2906, 3201, 5200) |
| **Median donation** | $100 |

### Cluster Size Distribution

| Bucket | Clusters | Rows |
|--------|----------|------|
| 1 (singleton) | 677,335 | 677,335 |
| 2–5 | 29,956 | 93,890 |
| 6–20 | 33,417 | 369,270 |
| 21–100 | 14,806 | 607,032 |
| 101–500 | 2,346 | 440,679 |
| 500+ | 250 | 242,992 |

### Stage Merge Counts

| Stage | Merges | Notes |
|-------|--------|-------|
| 1A | 1,642,977 | Exact last+first+zip |
| 1B | 19,458 | Employer (407K generic skipped) |
| 1C | 67 | Committee fingerprint (224 blocked) |
| 1D | 1,176 | Address number (~150K blocked by spouse guard) |
| 1E | 357 | Name variant cross-cluster |
| 1F | 43 | Employer history bridge |
| 1G | 9,010 | Cross-zip (1,029 emp + 7,981 addr) |
| **Total** | **1,673,088** | |

### Top 20 Clusters by Total Donations

| Cluster | Last | First Names | Rows | Total |
|---------|------|-------------|------|-------|
| 355385 | LUDDY | BOB, MARIA, ROBERT | 4,790 | $20,869,500 |
| 365345 | POPE | ART, ARTHRU, JAMES, KATHERINE | 2,957 | $15,249,685 |
| 362950 | KANE | JIM, JOHN | 3,427 | $8,179,386 |
| 366525 | EVERETTE | ALBERT, BLANTON, BONNIE, R, ROYCE, SPENCER | 5,729 | $7,113,648 |
| 379352 | SLOAN | C, CYRUS, HAMILTON, O, ORRIS, TEMPLE | 1,402 | $4,764,600 |
| 372332 | CRAIG | MARK | 2,359 | $4,741,368 |
| 382620 | HENSON | ALEXANDER, ALEXANDRA, SANDRA | 1,087 | $4,609,076 |
| 474838 | WETHERILL | DEBORA, EDDIE, EDWARD | 1,825 | $4,585,091 |
| 373322 | RAWL | JJLIAN, JULIA, JULIAN | 2,344 | $4,575,309 |
| 414261 | MILLS | FRED, FRED` | 2,589 | $4,334,910 |
| 354061 | VANDERWOUDE | J, JOHN, PHILIP, STEPHEN, STEVE | 1,170 | $4,330,888 |
| 379833 | WORDSWORTH | BRICE, ELAINE, JERRY, JOSH, RACHEL, STEVE, STEVEN | 1,235 | $3,917,500 |
| 358500 | CLARK | JIMMY, LYNN | 1,218 | $3,854,835 |
| 438019 | LONG | DAVID, RODNEY, WILLIAM | 2,154 | $3,818,216 |
| 459217 | JACOBS | SENACA, SENECA, SENECIA | 2,308 | $3,620,307 |
| 356526 | CARROLL | BRITTANY, HAYLEIGH, MADISON, ROY, VANESSA | 1,049 | $3,450,419 |
| 429221 | ZELNAK | JUDY, STEPHAN, STEPHEN, STEVE | 990 | $3,420,900 |
| 373505 | SMITH | C, CHRISTOPHER, E, EC, EDDIE, EDDY, EDWARD | 1,329 | $3,419,100 |
| 380413 | FAISON | JAY, OLGA | 991 | $3,409,358 |
| 379288 | PRESTAGE | BILL, JOHN, JOY, MARSHA, SCOTT, W, W.H, WILLIAM | 1,330 | $3,316,448 |

**ALERT:** Some of these top clusters may contain family merges (multiple distinct people). For example, POPE has both ART/JAMES and KATHERINE, which looks like family members clustered together via employer. CARROLL has BRITTANY, HAYLEIGH, MADISON, ROY, VANESSA — likely a family. WORDSWORTH has 7 distinct first names. These should be spot-checked during QA but are a consequence of shared employers and addresses — they may be intentional (shared business) or may need manual review.

### Year Distribution

| Year | Rows | Total Amount |
|------|------|-------------|
| 2015 | 62,043 | $41,229,740 |
| 2016 | 132,407 | $68,287,779 |
| 2017 | 234,929 | $63,751,385 |
| 2018 | 445,212 | $139,353,998 |
| 2019 | 128,050 | $66,211,210 |
| 2020 | 192,057 | $110,298,194 |
| 2021 | 222,716 | $87,055,289 |
| 2022 | 418,186 | $199,795,482 |
| 2023 | 153,109 | $114,087,538 |
| 2024 | 257,380 | $179,016,803 |
| 2025 | 156,216 | $108,600,987 |
| 2026 | 28,851 | $21,521,115 |
| 2029 | 13 | $1,300 |
| 2906 | 12 | $600 |
| 3201 | 13 | $325 |
| 5200 | 4 | $200 |

**Bad years:** 2029, 2906, 3201, 5200 are clearly corrupt `date_occured` values (42 rows total, $2,425). These are harmless — they'll just cluster with any same-name rows from real years.

---

## 6. Cluster Profile Schema (JSONB)

Every row's `cluster_profile` contains this structure (example from Ed Broyhill cluster 372171):

```json
{
  "cluster_id": 372171,
  "n_rows": 627,
  "name_variants_first": ["ED", "EDGAR", "J", "JAMES"],
  "last_names": ["BROYHILL"],
  "address_numbers": ["1930", "202", "325", "525"],
  "addresses": [
    "1930 VIRGINIA RD WINSTON SALEM NC 27104",
    "525 N HAWTHORNE RD WINSTON SALEM NC 27104",
    "... (all unique address strings)"
  ],
  "employers": ["ANVIL", "ANVIL MANAGEMENT", "ANVIL MGT", "ANVIL VENTURE GROUP", ...],
  "cities": ["WINSTON SALEM", "WINSTON-SALEM"],
  "zip5s": ["2030", "27012", "27104", "27105"],
  "committees": ["STA-036R3D-C-001", "STA-08H8K5-C-001", ...],
  "total_amount": 1318672.04,
  "year_min": 2015,
  "year_max": 2026,
  "year_range": [2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026],
  "rnc_regids": ["c45eeea9-663f-40e1-b0e7-a473baee794e"],
  "state_voter_ids": ["BN94856"],
  "dt_canonical_firsts": ["JAMES"],
  "dt_canonical_middles": ["EDGAR"],
  "household_id": "636697",
  "household_cluster_ids": [372197],
  "household_total": 1385696.27,
  "household_n_clusters": 2
}
```

### Querying cluster_profile

```sql
-- Get all employers for a cluster
SELECT cluster_profile->'employers' FROM raw.ncboe_donations WHERE cluster_id = 372171 LIMIT 1;

-- Get household total
SELECT (cluster_profile->>'household_total')::numeric FROM raw.ncboe_donations WHERE cluster_id = 372171 LIMIT 1;

-- Find clusters with household linkage
SELECT DISTINCT cluster_id, 
  cluster_profile->>'household_id' as hh_id,
  cluster_profile->>'household_total' as hh_total,
  cluster_profile->>'household_n_clusters' as hh_members
FROM raw.ncboe_donations 
WHERE (cluster_profile->>'household_n_clusters')::int > 1
LIMIT 100;
```

---

## 7. Household Linkage

Household linkage uses `dt_house_hold_id` from the DataTrust enrichment. It does NOT merge clusters — each person keeps their own `cluster_id` and individual total. The household data is stored in `cluster_profile` JSONB.

### How It Works

1. For each cluster, collect all `dt_house_hold_id` values from its member rows
2. Build a map: `dt_house_hold_id → set of cluster_ids`
3. For each cluster, find all other clusters sharing the same household_id
4. Compute `household_total` = sum of all linked clusters' `total_amount`
5. Store `household_id`, `household_cluster_ids`, `household_total`, `household_n_clusters` in the profile

### Stats

| Metric | Value |
|--------|-------|
| Total households with donors | 58,442 |
| Households with 2+ donor clusters | 4,459 |
| Total clusters linked by household | 9,089 |
| Avg clusters per multi-donor household | 2.0 |
| Max clusters in one household | 5 |
| Combined household donation total | $187,373,498.01 |

### Ed Broyhill Household Example

Ed (cluster 372171) and Melanie (cluster 372197) share `dt_house_hold_id = 636697`.

- Ed's individual total: $1,318,672.04 (627 rows)
- Melanie's individual total: $67,024.23 (18 rows)
- Household total: $1,385,696.27 (both clusters combined)
- Each person's profile shows the household total AND links to the other cluster

**Ed's profile page would show:**
- Individual: $1,318,672.04
- Household: $1,385,696.27 (includes Melanie Broyhill — $67,024.23)

---

## 8. RNC RegID Propagation (Dark Donor Rescue)

### Before Propagation
- 1,099,201 rows had `rnc_regid` from DataTrust matching (45.2%)
- 1,331,997 rows had no `rnc_regid` — "dark donors"

### After Propagation
- 1,293,069 rows have `rnc_regid` (53.2%)
- **193,868 dark donors rescued** via cluster propagation

### How It Works

When a cluster contains some rows matched to the voter file and some unmatched, the matched `rnc_regid` is propagated to the unmatched rows. This is safe because the dedup already confirmed they're the same person.

The propagation also copies: `state_voter_id`, `dt_first`, `dt_middle`, `dt_last`, `dt_suffix`, `dt_prefix`, `dt_zip4`, `dt_house_hold_id`. These rows get `dt_match_method = 'cluster_propagation'`.

### Match Method Distribution (after propagation)

| Match Method | Rows | Clusters |
|-------------|------|----------|
| exact_unique | 867,479 | 51,120 |
| cluster_propagation | 193,868 | 4,139 |
| exact_multi_best | 84,672 | 4,482 |
| prefix_match | 50,900 | 3,674 |
| middle_name_match | 45,490 | 2,955 |
| exact_middle_confirm | 31,639 | 1,597 |
| initial_match | 18,787 | 847 |
| exact_middle_confirm_propagated | 234 | 15 |

### Remaining Dark Donors

1,138,129 rows still have no `rnc_regid` (46.8%). These are:
- One-time donors who never matched any voter record
- Donors who moved out of state
- Deceased donors not in current voter file
- Donors with insufficient identifying information
- Business entities / PACs filing as individual donations

**DO NOT drop these.** They retain their cluster_id and cluster_profile. Stage 2 matching will attempt to resolve more.

---

## 9. Ed Broyhill Family — Proof-of-Correctness Canary

This family is the test case for every dedup decision. If the Ed cluster is wrong, the whole pipeline is wrong.

### Ed Broyhill — cluster 372171

| Field | Value |
|-------|-------|
| **Full name** | JAMES EDGAR BROYHILL II |
| **Known as** | Ed Broyhill |
| **rnc_regid** | `c45eeea9-663f-40e1-b0e7-a473baee794e` |
| **state_voter_id** | BN94856 |
| **Born** | 1954 |
| **Address** | 525 N Hawthorne Rd, Winston-Salem, NC 27104 |
| **dt_house_hold_id** | 636697 |
| **Cluster rows** | 627 |
| **Individual total** | $1,318,672.04 |
| **Household total** | $1,385,696.27 |
| **Name variants** | ED, EDGAR, J, JAMES |
| **Employers** | ANVIL, ANVIL MANAGEMENT, ANVIL MGT, ANVIL VENTURE GROUP, BROYHILL, BROYHILL FAMILY GROUP, BROYHILL GROUP, RNC, SELF-EMPLOYED, RETIRED, SENATOR, U.S. CONGRESSMAN |
| **Zips** | 2030 (bad data), 27012, 27104, 27105 |
| **Address numbers** | 1930 (father's address), 202, 325, 525 (home) |
| **Years** | 2015–2026 (all 12 years) |

**CRITICAL NAME RULE:** ED = EDGAR, never EDWARD. The name parser must enforce this. Ed's legal name is JAMES EDGAR BROYHILL II. "ED" is short for EDGAR.

**Why this cluster has Senator's donations:** Ed wrote the checks for his father (Senator James Thomas Broyhill, 1927-2023, deceased) and mother (Louise Robbins Broyhill, born 1929). The Senator's donations filed under "JAMES BROYHILL" merged into Ed's cluster because they share first name JAMES + last name BROYHILL and some had the same rnc_regid (mis-enrichment — some of the Senator's rows were incorrectly matched to Ed's voter record). Ed instructed: "add my mother and father donations in with my total as i wrote the checks."

### Melanie Pennell Broyhill (wife) — cluster 372197

| Field | Value |
|-------|-------|
| **rnc_regid** | `8d88ee52-0035-466c-9b6a-6b5d94844c4c` |
| **state_voter_id** | BN9956 |
| **Born** | 1954 |
| **Address** | 525 N Hawthorne Rd, Winston-Salem, NC 27104 |
| **dt_house_hold_id** | 636697 |
| **Cluster rows** | 18 |
| **Individual total** | $67,024.23 |
| **Name variants** | MELANIE only |

**Melanie is SEPARATE.** She is linked to Ed's household (same dt_house_hold_id = 636697) but never merged into his cluster. The 1D first-name guard blocks ED/MELANIE merges, and the rnc_regid conflict guard (different regids) blocks it at every stage.

### Louise Robbins Broyhill (mother)

| Field | Value |
|-------|-------|
| **rnc_regid** | `611ee508-04de-4be0-b8eb-a3b108282a9f` |
| **state_voter_id** | BN180289 |
| **Born** | 1929 |
| **Voter file address** | 1244 (voter file) / 1930 Virginia Rd (donation) |
| **dt_house_hold_id** | 636696 |

Louise has her own cluster, separate from Ed. She's at a different dt_house_hold_id (636696 vs 636697) because she lived at 1930 Virginia Rd (the Senator's address), not 525 Hawthorne.

### Senator James Thomas "Jim" Broyhill (father, deceased 2023)

Former US Congressman and Senator. Some of his donation rows were incorrectly enriched with Ed's rnc_regid by the DataTrust matching pipeline (because they share the first name JAMES and last name BROYHILL). Those rows merged into Ed's cluster, which Ed explicitly approved — he wrote the checks. The Senator's separate voter record no longer appears in the active voter file (he's deceased).

---

## 10. DataTrust Voter File Reference

**Table:** `core.datatrust_voter_nc` — 7,727,637 rows, 252 columns, 12 GB

### Key Column Categories

**Identity:** `rnc_regid`, `state_voter_id`, `first_name`, `last_name`, `middle_name`, `name_suffix`, `sex`, `birth_year`, `birth_month`, `birth_day`, `age`, `age_range`

**Registration:** `registered_party`, `registration_date`, `voter_status`, `first_observed_date`, `first_observed_state`

**Address (parsed):** `reg_house_num`, `reg_house_sfx`, `reg_st_prefix`, `reg_st_name`, `reg_st_type`, `reg_unit_type`, `reg_unit_number`, `registration_addr1`, `registration_addr2`, `city_council`, `reg_zip5`, `reg_zip4`, `reg_sta`, `reg_latitude`, `reg_longitude`

**Districts:** `congressional_district`, `state_leg_upper_district`, `state_leg_lower_district`, `county_name`, `county_fips`, `school_district`, `school_board`, `ward`, `juriscode`, `jurisname`

**Household:** `house_hold_id`, `house_hold_member_id`, `house_hold_party`, `household_income_modeled`

**Phone:** `cell`, `cell_abev`, `cell_neustar`, `cell_data_axle` (with append dates, match levels, DNC flags)

**Voting History:** `vh06_g` through `vh26_p` (general and primary for every election 2006-2026), `voter_frequency_general`, `voter_frequency_primary`, `voter_regularity_general`, `voter_regularity_primary`

**Scores:** `republican_party_score`, `democratic_party_score`, `republican_ballot_score`, `democratic_ballot_score`, `turnout_general_score`, `calc_party`, `is_party_reg`

**Modeled:** `education_modeled`, `ethnic_group_modeled`, `ethnic_group_name_modeled`, `ethnicity_modeled`, `ethnicity_reported`, `religion_modeled`

**Coalition IDs:** `coalition_id_2nd_amendment`, `coalition_id_fiscal_conservative`, `coalition_id_pro_choice`, `coalition_id_pro_life`, `coalition_id_social_conservative`, `coalition_id_sportsmen`, `coalition_id_veteran`

**Census:** `census_block2020`, ACS education/ethnicity proportions

**Change tracking:** `change_of_address_date`, `change_of_address_source`, `change_of_address_type`

---

## 11. Acxiom Tables Reference

### core.acxiom_ap_models — 7,655,593 rows, ~420 columns, 16 GB
**Key:** `rnc_regid` (joins to voter file and donations)

These are Acxiom's PersonicX and audience propensity models. Column names are coded (ap000313, ap001517, etc.). Each code maps to a specific behavioral/demographic model score. You'll need the Acxiom data dictionary to decode them.

**Ed's data hierarchy places Acxiom modeled scores LAST (tier 5).** Never use these as a primary data source. They are modeled — not factual. Use them only when donation history, voting history, party positions, and volunteer activity are insufficient.

### core.acxiom_ibe — 4,450,000 rows (STILL LOADING), 911 columns, 18 GB
**Key:** `rnc_regid`

Individual Behavioral Elements. Screen `acxrestructure` is still running. Check progress with:
```bash
screen -r acxrestructure
```
or:
```sql
SELECT count(*) FROM core.acxiom_ibe;
```

IBE columns are coded (ibe1273_01, ibe2022, etc.) — need Acxiom data dictionary.

### core.acxiom_consumer_nc — 7,655,593 rows, 22 columns, 89 GB
**Key:** `rnc_regid`

Lightweight consumer data: `state`, `first_name`, `last_name`, `reg_city`, `reg_zip5`, plus ~16 selected AP model scores. This appears to be a denormalized subset for quick lookups.

### core.acxiom_market_indices — 0 rows
Empty table — schema only.

---

## 12. Known Data Issues & Landmines

### 1. `amount` column is TEXT, not numeric
The raw `amount` column from NCBOE is stored as `text`. **Always use `norm_amount` (numeric) for calculations.** If you write SQL with `sum(amount)`, PostgreSQL will throw: `function sum(text) does not exist`.

### 2. Column typo: `date_occured` (not `date_occurred`)
The raw date column is misspelled. Use `norm_date` (date type) or `year_donated` (integer) instead.

### 3. Column typo: `transction_type` (not `transaction_type`)
Another NCBOE original typo.

### 4. `norm_amount` has 3 NULLs, 72 zeros, 12 negatives
- 3 rows with NULL norm_amount — donation amount couldn't be parsed
- 72 rows with $0.00 — in-kind or zero-value transactions
- 12 rows with negative amounts — refunds/returns
- Min: -$75.00, Max: $100,000.00

### 5. Bad year_donated values
42 rows have impossible years: 2029 (13 rows), 2906 (12), 3201 (13), 5200 (4). These are corrupt `date_occured` values. They cluster normally by name/zip and are harmless.

### 6. employer_sic_master is EMPTY
The plan references 62,100 SIC mappings but the table has 0 rows. SIC-based employer normalization has never been loaded. The dedup works without it — `norm_employer` is just string-cleaned, not SIC-normalized.

### 7. acxiom_ibe is still loading
Screen `acxrestructure` is actively loading. Don't query acxiom_ibe for full analysis yet — you'll get partial results. Check `SELECT count(*)` to monitor progress.

### 8. Senator Broyhill mis-enrichment
Some of the Senator's donation rows were incorrectly matched to Ed's rnc_regid during DataTrust matching. This is a known issue caused by shared name (JAMES BROYHILL) + similar address. The dedup intentionally merges these into Ed's cluster per Ed's instruction. But if you're doing voter-file-level analysis, be aware that rnc_regid `c45eeea9...` is Ed (born 1954), not the Senator (born 1927, deceased 2023).

### 9. Top clusters may contain family members
Clusters like POPE (ART + KATHERINE), FAISON (JAY + OLGA), HENSON (ALEXANDER + ALEXANDRA + SANDRA) may include spouses or family merged via shared employer + city. The dedup only blocks spouse merges when it has rnc_regid evidence or the first names are clearly incompatible. If two people share last name + employer + city, they merge. This is correct for business partnerships but may over-merge some family-run businesses.

### 10. `norm_employer` uses string cleaning, not SIC normalization
`norm_employer` is uppercased and trimmed. It does NOT map employer variants to a canonical form (e.g., "ANVIL VENTURE GROUP", "ANVIL MANAGEMENT", "ANVIL MGT" are all separate values). SIC-based normalization would collapse these. This is a future enhancement dependent on loading `employer_sic_master`.

---

## 13. What Comes Next (Ordered)

### Phase 1: Immediate (before any new work)

1. **Verify Acxiom IBE load completes** — check screen `acxrestructure`, confirm row count matches AP models (should be ~7.6M when done)
2. **Load `employer_sic_master`** — the table schema exists, need the 62,100-row mapping file. Ask Ed where the source file is.
3. **Push `ncboe_dedup_v2.py` to GitHub** — it's on the server but not yet committed

### Phase 2: Normalization Enhancement

4. **SIC-based employer normalization** — once `employer_sic_master` is loaded, build a `phase2_normalize.py` that updates `norm_employer` with SIC-normalized values AND populates `employer_sic_code` / `employer_naics_code`
5. **Re-run cluster profiles** (NOT dedup) — after employer normalization, update `cluster_profile` JSONB with normalized employer names. The cluster_ids and merge boundaries do NOT change — only the profile metadata improves.

### Phase 3: Stage 2 — Voter File Matching

6. **Build Stage 2 matching script** — match dedup clusters to `core.datatrust_voter_nc` using the pass order from `DONOR_DEDUP_PIPELINE_V2.md`:
   - Pass 1: DOB + Sex + Last + Zip
   - Pass 2: Address number + Last + Zip
   - Pass 3: Employer + Last + City
   - Pass 4: FEC cross-reference
   - Pass 5: Committee loyalty
   - Pass 6: Name variants + Last + City
   - Pass 7: Geocode proximity
   - Pass 8: Household matching
7. **This is the highest-value work remaining** — it will resolve the remaining 46.8% dark donors that cluster propagation couldn't reach

### Phase 4: Enrichment

8. **Build donor enrichment view/materialized view** joining `raw.ncboe_donations` → `core.datatrust_voter_nc` → `core.acxiom_ap_models` → `core.acxiom_ibe` via `rnc_regid`
9. **Microsegmentation tagging** based on SIC codes
10. **Honorific assignment** per the pipeline spec

### Phase 5: Frontend Integration

11. **Donor profile pages** — individual donor view with cluster_profile data
12. **Household view** — combined family giving
13. **Search/filter by employer, committee, district, amount, date range**

---

## 14. Files on Server

### Root: /opt/broyhillgop/

**Production scripts (active):**
| File | Purpose |
|------|---------|
| `ncboe_dedup_v2.py` (34KB) | **THE dedup script — APPLIED** — do not modify |
| `datatrust_enrich.py` (17KB) | DataTrust enrichment script |
| `bulletproof_load.py` (8KB) | Data loading utility |
| `load_all_gold.py` (6KB) | Gold file loader |
| `phase2_normalize.py` (5KB) | Phase 2 normalization (may be incomplete) |
| `relay.py` (34KB) | Running in screen `relay` |

**Key documentation:**
| File | Purpose |
|------|---------|
| `sessions/DONOR_DEDUP_PIPELINE_V2.md` | **CANONICAL** dedup plan — the Bible |
| `sessions/SESSION_APRIL12_2026_FINAL.md` | Session log |
| `docs/NCBOE_DONATIONS_SCHEMA.md` | Schema reference (pushed to GitHub) |
| `.cursorrules` | Cursor AI rules for frontend |
| `CURSOR_WAKE_UP.md` | Previous Cursor briefing |

**Session logs:** `/opt/broyhillgop/sessions/` — 50+ files spanning March–April 2026

**Scripts directory:** `/opt/broyhillgop/scripts/` — 40+ utility scripts

### GitHub: broyhill/BroyhillGOP

Last commit: `8412b6a` — "Add NCBOE GOLD file audit script"

**Not yet pushed:**
- `ncboe_dedup_v2.py` (the production dedup script)
- This briefing document

---

## 15. Critical Rules (Non-Negotiable)

These come directly from Ed Broyhill. Violating any of them will result in bad data and angry phone calls.

1. **DO NOT re-run or modify the dedup script.** It's been applied. The cluster_ids are in the database. Changing the algorithm means re-running on 2.4M rows and risking different results.

2. **ED = EDGAR, never EDWARD.** Ed's legal name is JAMES EDGAR BROYHILL II. Any name parser that maps ED → EDWARD is wrong.

3. **Every donor matters equally.** The $100 donor is the $25,000 donor in 10 years. Small donors are the volunteer pipeline. No shortcuts.

4. **Process 2026 → 2015** (reverse chronological). The newest record is most likely to match the current voter file.

5. **No nickname lookup tables.** Use actual name variants from donation history only.

6. **Never drop unmatched donors.** Score them on donation history alone. Flag for manual review if > $1,000.

7. **Household linkage, not merging.** Each person gets their own cluster/profile. Households are linked for combined totals but individuals stay separate.

8. **5-tier data hierarchy:**
   1. Donation history (GOLD — actual money)
   2. Voting history (verified behavior)
   3. Party positions (registered affiliation)
   4. Volunteer activity (engagement)
   5. Acxiom modeled scores (LAST RESORT — these are predictions, not facts)

9. **Verify before trusting.** Cursor has previously loaded contaminated files. Always check the data before building on it.

10. **Accuracy over speed.** "do what is most accurate not to lose any donations"

---

*This briefing was generated by Perplexity Computer from live database queries and the applied dedup script. All numbers are from the production database as of April 13, 2026 01:00 AM EDT.*
