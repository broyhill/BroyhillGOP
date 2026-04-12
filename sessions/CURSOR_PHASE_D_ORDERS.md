# CURSOR WORK ORDERS — Phase D Preparation
# April 12, 2026 3:04 PM EDT
# Ed has authorized all work. Do not ask for approvals.

## CONTEXT
DataTrust voter file: LOADED (7,727,637 rows, core.datatrust_voter_nc)
Acxiom consumer data: LOADED (7,655,593 rows, core.acxiom_consumer_nc)
RNC fact tables: DOWNLOADING NOW (absentee at 5.8M rows, 6 more endpoints queued)
Relay: Running at 37.27.169.232:8080
Server: 37.27.169.232 (PostgreSQL 16, 96 cores, 252GB RAM, 1.7TB free)

## NEXT: Prepare for Phase D — NCBOE GOLD File Ingestion

Ed has 18 GOLD NCBOE donor files on his laptop. Before he transfers them, we need the receiving infrastructure ready on the new server.

### TASK 1 — Build the NCBOE raw staging table

The 18 GOLD NCBOE files have these columns:
```
Name, Street Line 1, Street Line 2, City, State, Zip Code,
Profession/Job Title, Employer's Name/Specific Field,
Transaction Type, Committee Name, Committee SBoE ID,
Committee Street 1, Committee Street 2, Committee City,
Committee State, Committee Zip Code, Report Name,
Date Occurred, Account Code, Amount, Form of Payment,
Purpose, Candidate/Referendum Name, Declaration
```

Create this table on the new server:
```sql
CREATE TABLE raw.ncboe_donations (
    id SERIAL PRIMARY KEY,
    source_file TEXT NOT NULL,
    -- Original NCBOE columns
    name TEXT,
    street_line_1 TEXT,
    street_line_2 TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    profession_job_title TEXT,
    employer_name TEXT,
    transaction_type TEXT,
    committee_name TEXT,
    committee_sboe_id TEXT,
    committee_street_1 TEXT,
    committee_street_2 TEXT,
    committee_city TEXT,
    committee_state TEXT,
    committee_zip_code TEXT,
    report_name TEXT,
    date_occurred TEXT,
    account_code TEXT,
    amount TEXT,
    form_of_payment TEXT,
    purpose TEXT,
    candidate_referendum_name TEXT,
    declaration TEXT,
    -- Enrichment columns (populated during normalization)
    norm_last TEXT,
    norm_first TEXT,
    norm_middle TEXT,
    norm_suffix TEXT,
    norm_prefix TEXT,
    norm_nickname TEXT,
    norm_zip5 TEXT,
    norm_city TEXT,
    norm_employer TEXT,
    norm_amount NUMERIC(12,2),
    norm_date DATE,
    address_numbers TEXT[],  -- all numbers extracted from both address lines
    all_addresses TEXT[],    -- complete addresses preserved (home, office, 2nd homes)
    year_donated INTEGER,
    -- Matching columns (populated during dedup)
    cluster_id INTEGER,
    rnc_regid TEXT,          -- FK to datatrust_voter_nc after matching
    match_pass INTEGER,      -- which dedup pass matched this record
    match_confidence NUMERIC(5,2),
    is_matched BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ncboe_name ON raw.ncboe_donations (norm_last, norm_first);
CREATE INDEX idx_ncboe_zip ON raw.ncboe_donations (norm_zip5);
CREATE INDEX idx_ncboe_employer ON raw.ncboe_donations (norm_employer);
CREATE INDEX idx_ncboe_committee ON raw.ncboe_donations (committee_sboe_id);
CREATE INDEX idx_ncboe_date ON raw.ncboe_donations (norm_date);
CREATE INDEX idx_ncboe_cluster ON raw.ncboe_donations (cluster_id);
CREATE INDEX idx_ncboe_rnc ON raw.ncboe_donations (rnc_regid);
CREATE INDEX idx_ncboe_source ON raw.ncboe_donations (source_file);
CREATE INDEX idx_ncboe_candidate ON raw.ncboe_donations (candidate_referendum_name);
```

### TASK 2 — Build the NCBOE name parser

Write a Python function that parses the NCBOE `Name` field. CRITICAL RULES:
- NCBOE format is FIRST LAST (not LAST, FIRST like FEC)
- Handle suffixes: JR, SR, II, III, IV — store in suffix, NOT in last_name
- Handle middle names: "JAMES EDGAR BROYHILL" → first=JAMES, middle=EDGAR, last=BROYHILL
- Handle nicknames in quotes: "JAMES EDGAR 'ED' BROYHILL" → first=JAMES, middle=EDGAR, nickname=ED, last=BROYHILL
- Handle initials: "J BROYHILL" → first=J, last=BROYHILL
- Handle prefixes: DR, REV, MR, MRS, MS → store in prefix field
- BLANK names → flag as UNITEMIZED, skip identity matching
- ED maps to EDGAR, not EDWARD — EVER
- The LAST word is almost always the last name, BUT watch for suffixes

Save to: /opt/broyhillgop/pipeline/ncboe_name_parser.py
Include unit tests for: ED BROYHILL, JAMES EDGAR BROYHILL, JAMES EDGAR 'ED' BROYHILL, J BROYHILL, JAMES T BROYHILL JR, DR JANE SMITH, REV JOHN DOE III

### TASK 3 — Build the address number extractor

Write a Python function that extracts ALL numeric values from address fields. CRITICAL:
- Not just house numbers — PO Box, Highway, Suite, Floor, Rural Route, Apt numbers
- Extract from BOTH Street Line 1 AND Street Line 2
- Return as array: ["525", "3224"] for "525 N HAWTHORNE RD" + "APT 3224"
- Handle: "PO BOX 1247" → ["1247"]
- Handle: "4721 HWY 421 S" → ["4721", "421"]
- Handle: "STE 300 100 MAIN ST" → ["300", "100"]
- Handle: "RR 3 BOX 45" → ["3", "45"]

Save to: /opt/broyhillgop/pipeline/address_number_extractor.py
Include unit tests.

### TASK 4 — Build the employer normalizer

Write a Python function that normalizes employer names:
- Uppercase
- Strip: INC, LLC, CORP, CO, LTD, LP, LLP, PC, PA, PLLC, DBA
- Strip trailing periods and commas
- Map known variants: ANVIL VENTURE* → ANVIL VENTURE GROUP, VARIETY WHOLESALE* → VARIETY WHOLESALERS
- "RETIRED" → "RETIRED"
- "SELF" or "SELF-EMPLOYED" or "SELF EMPLOYED" → "SELF-EMPLOYED"
- "NONE" or "N/A" or blank → NULL

Save to: /opt/broyhillgop/pipeline/employer_normalizer.py

### TASK 5 — Build the NCBOE normalization pipeline

Write a Python script that:
1. Reads a CSV file from /data/ncboe/gold/
2. Parses names using Task 2
3. Extracts address numbers using Task 3
4. Normalizes employers using Task 4
5. Normalizes zip (first 5 digits), city (uppercase), dates
6. Computes norm_amount as numeric
7. Computes year_donated
8. INSERTs into raw.ncboe_donations with source_file tag

Save to: /opt/broyhillgop/pipeline/ncboe_normalize_pipeline.py

### TASK 6 — Build the internal dedup clustering engine

Write a Python script that implements Stage 1 of DONOR_DEDUP_PIPELINE_V2.md:
- Stage 1A: Exact last + first + zip clustering
- Stage 1B: Employer + last + city clustering
- Stage 1C: Committee loyalty fingerprint
- Stage 1D: Address number collection per cluster
- Stage 1E: Name variant collection per cluster
- Stage 1F: Employer history collection per cluster
- Stage 1G: Multi-address / second home collection
- Process 2026 → 2015 (reverse chronological)
- Output: UPDATE raw.ncboe_donations SET cluster_id = X

Save to: /opt/broyhillgop/pipeline/ncboe_internal_dedup.py

## GUARDRAILS
- All code goes in /opt/broyhillgop/pipeline/ on the new server
- DO NOT load any data — just build the infrastructure
- DO NOT touch Supabase
- Commit all code to GitHub
- Read sessions/DONOR_DEDUP_PIPELINE_V2.md before writing dedup code
- ED = EDGAR, never EDWARD

## THE JOIN CHAIN
nc_voters.ncid = DataTrust.StateVoterID → DataTrust.RNC_RegID = Acxiom.RNC_RegID
