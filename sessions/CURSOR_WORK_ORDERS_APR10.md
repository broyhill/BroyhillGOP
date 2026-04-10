# CURSOR WORK ORDERS — April 10, 2026 2:40 PM EDT
# READ THIS IMMEDIATELY. Ed has authorized all work. Do not ask for approvals.

## CONTEXT
Ed Broyhill has authorized full execution of the Master Reset and Build Plan.
Read: sessions/MASTER_RESET_AND_BUILD_PLAN.md FIRST.
New Hetzner server: 37.27.169.232 (AX162-R, Finland) — whitelisted for RNC API and MSSQL.
Ed is away from desk. Work continuously.

## YOUR TASKS (in priority order)

### TASK 1 — Prepare the 252-column DataTrust voter file schema
Using the schema from the 2025_Voterfile_Schema_Update.xlsx (252 columns, documented in sessions/MASTER_RESET_AND_BUILD_PLAN.md Phase 2), write the CREATE TABLE DDL for the new server PostgreSQL. 
- Table name: public.datatrust_voter_nc
- Primary key: rnc_regid (UUID)
- Index on: state_voter_id, rncid, last_name + reg_zip5, reg_house_num + reg_zip5 + last_name, county_fips, congressional_district, state_leg_upper_district, state_leg_lower_district
- Column names: use snake_case versions of the DataTrust field names
- Save DDL to: sessions/DDL_DATATRUST_VOTER_NC.sql and commit to GitHub

### TASK 2 — Prepare the Acxiom schema
The Acxiom consumer data has ~10,000+ columns across three layers (Market Indices, IBE, AP Models).
Design the schema using JSONB approach:
- Table: public.acxiom_consumer_nc
- Columns: rnc_regid (UUID PK), state TEXT, market_indices JSONB, ibe JSONB, ap_models JSONB, last_update TIMESTAMPTZ
- Index: rnc_regid, GIN indexes on each JSONB column
- Save DDL to: sessions/DDL_ACXIOM_CONSUMER_NC.sql and commit to GitHub

### TASK 3 — Prepare the nc_boe_donations_raw schema for clean GOLD load
Write the CREATE TABLE DDL for a clean nc_boe_donations_raw table on the new server.
Must include all columns from the 18 GOLD NCBOE files plus enrichment columns:
- voter_ncid, rncid, norm_last, norm_first, norm_zip5, norm_addr
- Save DDL to: sessions/DDL_NCBOE_DONATIONS_RAW.sql

### TASK 4 — Prepare the person_spine rebuild DDL
Design the new person_spine that starts from the DataTrust voter file as foundation (not donor files).
- Primary key: rnc_regid (matches DataTrust)
- state_voter_id (= ncid) as indexed column
- All demographic, geographic, and contact columns from DataTrust
- Donor aggregate columns (total_contributed, contribution_count, etc.)
- Volunteer columns (volunteer_level, activism_score, is_party_officer, etc.)
- Honorific columns (honorific, formal_salutation, correspondence_greeting)
- Save DDL to: sessions/DDL_PERSON_SPINE_V2.sql

### TASK 5 — Build the ncboe_voter_statewide_ingest.py pipeline
The 70→67 column mapping pipeline for NC SBOE voter file. This was started earlier.
Verify it handles: Latin-1 encoding, 70→67 mapping (drop ssn, no_dl_ssn_chkbx, hava_id_req), validation report, dedup.
Save to: pipeline/ncboe_voter_statewide_ingest.py

## GUARDRAILS
- DO NOT execute any DDL on Supabase — Ed is about to PITR reset it
- DO NOT load any files — just prepare the schemas and pipelines
- DO NOT touch SACRED tables
- ED maps to EDGAR, never EDWARD
- All DDL is DESIGN ONLY — will be executed on the new server after review
- Commit all work to GitHub so other agents can see it

## THE JOIN CHAIN (memorize)
nc_voters.ncid = DataTrust.StateVoterID → DataTrust.RNC_RegID = Acxiom.RNC_RegID

Work continuously. Commit often.
