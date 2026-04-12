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

**Authoritative DDL:** `database/migrations/071_raw_ncboe_donations_gold_hetzner.sql` (replaces the inline SQL below).

NCBOE GOLD CSV headers include **intentional typos** — do not “fix” them in the file. Database columns preserve typos as `transction_type` and `date_occured`. See `sessions/SESSION_APRIL12_2026.md` and `pipeline/ncboe_gold_csv_headers.py`.

The 18 GOLD files use these **display** headers (typos shown):
```
Name, Street Line 1, Street Line 2, City, State, Zip Code,
Profession/Job Title, Employer's Name/Specific Field,
Transction Type, Committee Name, Committee SBoE ID,
Committee Street 1, Committee Street 2, Committee City,
Committee State, Committee Zip Code, Report Name,
Date Occured, Account Code, Amount, Form of Payment,
Purpose, Candidate/Referendum Name, Declaration
```

Apply on Hetzner:
```bash
psql "$HETZNER_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/071_raw_ncboe_donations_gold_hetzner.sql
```

Creates `raw.ncboe_donations` (BIGSERIAL, typo columns, `employer_sic_code` / `employer_naics_code`, `cluster_profile` JSONB, `is_unitemized`, indexes) and an empty `donor_intelligence.employer_sic_master` shell for local SIC loads (pg_dump from Supabase when authorized).

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

Save to: `pipeline/ncboe_name_parser.py` in Git; on server run `git pull` under `/opt/broyhillgop` (same relative path).
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

Save to: `pipeline/address_number_extractor.py` (sync via git pull on server).
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

Save to: `pipeline/employer_normalizer.py`. SIC lookup uses `donor_intelligence.employer_sic_master` on the same DB (empty until loaded from Supabase dump when authorized).

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

Save to: `pipeline/ncboe_normalize_pipeline.py`. Default is dry-run; use `--apply` to INSERT. Set `HETZNER_DB_URL` on the server.

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

Save to: `pipeline/ncboe_internal_dedup.py`.

## GUARDRAILS
- All code goes in /opt/broyhillgop/pipeline/ on the new server
- DO NOT load any data — just build the infrastructure
- DO NOT touch Supabase
- Commit all code to GitHub
- Read sessions/DONOR_DEDUP_PIPELINE_V2.md before writing dedup code
- ED = EDGAR, never EDWARD

## THE JOIN CHAIN
nc_voters.ncid = DataTrust.StateVoterID → DataTrust.RNC_RegID = Acxiom.RNC_RegID
