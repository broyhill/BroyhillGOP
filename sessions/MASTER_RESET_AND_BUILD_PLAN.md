# MASTER RESET AND BUILD PLAN — BroyhillGOP
**Created: April 10, 2026 2:05 PM EDT**
**Authority: Ed Broyhill | NC National Committeeman**
**Author: Perplexity (CEO)**
**Audience: Cursor, Claude, and any AI agent touching this project**

---

## READ THIS ENTIRE DOCUMENT BEFORE DOING ANYTHING. NO EXCEPTIONS.

This is the FINAL build. We have had 13 contamination incidents because agents did not read instructions before acting. If you skip any section of this document, you will be removed from the project.

---

## PHASE 0 — SUPABASE DATABASE RESET

### What We Are Doing
Restoring the Supabase BroyhillGOP-Claude database (project `isbgjpnbocdkeslofota`) to the **April 8, 2026 at 7:00 AM EDT** snapshot via Point-in-Time Recovery. This erases all contaminated NCBOE and FEC data loaded after that point.

### Who Executes This
**Ed Broyhill ONLY.** No agent can perform PITR. Ed does this in the Supabase Dashboard:
1. Go to: https://supabase.com/dashboard/project/isbgjpnbocdkeslofota
2. Settings → Database → Backups → Point in Time Recovery
3. Set restore point: **April 8, 2026 — 07:00 AM EDT (11:00 UTC)**
4. Confirm restore

### After Reset — Verify These Counts (Cursor or Claude may SELECT only)
```sql
SET statement_timeout = '300s';

-- SACRED TABLES (must survive reset intact)
SELECT 'nc_datatrust' as tbl, COUNT(*) as rows FROM public.nc_datatrust;        -- Expected: ~7,661,978
SELECT 'nc_voters' as tbl, COUNT(*) as rows FROM public.nc_voters;              -- Expected: ~9,079,672
SELECT 'rnc_voter_staging' as tbl, COUNT(*) as rows FROM public.rnc_voter_staging; -- Expected: ~7,708,268
SELECT 'nc_voters_fresh' as tbl, COUNT(*) as rows FROM staging.nc_voters_fresh;   -- Expected: ~7,707,910

-- THE PEARL
SELECT 'person_spine_active' as tbl, COUNT(*) as rows FROM core.person_spine WHERE is_active = true;   -- Expected: ~74,407
SELECT 'person_spine_inactive' as tbl, COUNT(*) as rows FROM core.person_spine WHERE is_active = false; -- Expected: ~125,976

-- CONTRIBUTION DATA (may be partially contaminated — assess after reset)
SELECT 'contribution_map' as tbl, COUNT(*) as rows FROM core.contribution_map;   -- Expected: ~2,960,201
SELECT 'fec_donations' as tbl, COUNT(*) as rows FROM public.fec_donations;       -- Expected: ~779,182 (14 locked files)

-- CONTAMINATED TABLE (assess state after reset)
SELECT 'nc_boe_donations_raw' as tbl, COUNT(*) as rows FROM public.nc_boe_donations_raw; -- Should be 338,223 if reset worked, or ~221,437 if partial GOLD load was in progress

-- CANDIDATE/COMMITTEE PIPELINE (PRESERVE THESE)
SELECT 'committee_party_map' as tbl, COUNT(*) as rows FROM core.committee_party_map;
SELECT 'candidate_profiles' as tbl, COUNT(*) as rows FROM core.candidate_profiles;
SELECT 'committee_candidate_bridge' as tbl, COUNT(*) as rows FROM staging.committee_candidate_bridge;
SELECT 'boe_donation_candidate_map' as tbl, COUNT(*) as rows FROM staging.boe_donation_candidate_map;
SELECT 'csv_candidate_committee_master' as tbl, COUNT(*) as rows FROM staging.csv_candidate_committee_master;
SELECT 'sboe_committee_master' as tbl, COUNT(*) as rows FROM staging.sboe_committee_master;
```

### Report ALL counts to Ed before proceeding. Do not proceed without Ed's approval.

---

## PHASE 0.5 — ASSESS, PRESERVE, AND BACK UP

### Tables to BACK UP before any further work (dump to new Hetzner server)

**SACRED — Never delete, always preserve:**
| Table | Why |
|-------|-----|
| `public.nc_datatrust` | 7.66M rows, 16GB — RNC DataTrust enrichment, primary identity anchor |
| `public.nc_voters` | 9.08M rows — NC SBOE voter file |
| `public.rnc_voter_staging` | 7.71M rows — RNC voter staging |
| `staging.nc_voters_fresh` | 7.71M rows — DataTrust-enriched voter file |

**THE PEARL — Back up separately:**
| Table | Why |
|-------|-----|
| `core.person_spine` | 74,407 active + 125,976 inactive — the master identity table |
| `core.contribution_map` | 2.96M rows — all contribution linkages |

**CANDIDATE/COMMITTEE PIPELINE — Critical reference data:**
| Table | Why |
|-------|-----|
| `core.committee_party_map` | Republican/Democrat/Unknown committee classifications |
| `core.candidate_profiles` | 9,759 Republican candidate profiles |
| `staging.committee_candidate_bridge` | Fuzzy-matched committee-to-candidate linkages |
| `staging.boe_donation_candidate_map` | BOE donation-to-candidate mapping |
| `staging.csv_candidate_committee_master` | CSV-loaded candidate/committee master |
| `staging.sboe_committee_master` | SBOE committee reference |
| `public.nc_republican_federal_candidates_2015_2026` | 138 federal R candidates (if loaded) |
| `public.gop_presidential_committees_2016_2024` | 26 presidential committees (if loaded) |

**VOLUNTEER ECOSYSTEM (if created before April 8 7AM):**
| Table | Why |
|-------|-----|
| `volunteer.person_volunteer_profile` | 54,495 profiles |
| `volunteer.party_organization` | 109 orgs |
| `volunteer.party_officer` | Officer records |
| `volunteer.volunteer_activity` | Activity tracking |
| `volunteer.candidate_volunteer_match` | Matching engine |

**DONOR INTELLIGENCE (if created before April 8 7AM):**
| Table | Why |
|-------|-----|
| `donor_intelligence.employer_sic_master` | 62,100 employer→SIC mappings |
| `donor_intelligence.donor_alias_clusters` | 29,205 name-variant clusters |

**INDEXES — Document all custom indexes before reset:**
```sql
SELECT schemaname, tablename, indexname, indexdef 
FROM pg_indexes 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;
```
Save this output to a file. We may need to recreate indexes after migration.

**FUNCTIONS — Document all custom functions:**
```sql
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema NOT IN ('pg_catalog', 'information_schema', 'extensions')
ORDER BY routine_schema, routine_name;
```

### Back Up Method
From the new Hetzner server (37.27.169.232), use `pg_dump` against Supabase direct connection (port 5432, NOT pooler 6543):
```bash
pg_dump -h db.isbgjpnbocdkeslofota.supabase.co -p 5432 -U postgres \
  -t 'core.person_spine' -t 'core.contribution_map' \
  -t 'core.committee_party_map' -t 'core.candidate_profiles' \
  -t 'staging.committee_candidate_bridge' -t 'staging.boe_donation_candidate_map' \
  -t 'staging.csv_candidate_committee_master' -t 'staging.sboe_committee_master' \
  -F c -f /data/backups/supabase_critical_tables_$(date +%Y%m%d).dump
```
Password: (ask Ed — do NOT hardcode in scripts)

---

## PHASE 1 — NEW SERVER SETUP (Hetzner 37.27.169.232)

### Server Specs
- **AX162-R #2973063** — Finland (HEL1)
- **IP**: 37.27.169.232
- **OS**: (Claude to confirm what was installed)
- **PostgreSQL**: Must be version 16+

### Required Software
```
PostgreSQL 16+
Python 3.11+
pyarrow (for parquet files)
pandas
psycopg2-binary
pymssql (for MSSQL VoterSnapshot pull)
git
screen (for long-running jobs)
```

### Required Access (Ed must request from Zack Imel / Danny Peletski)
1. **RNC API whitelist**: Add 37.27.169.232 to `rncdatahubapi.gop` allowed IPs
2. **MSSQL whitelist**: Add 37.27.169.232 to `rncazdwsql.cloudapp.net:52954` allowed IPs
3. **DataTrust token renewal** (was expiring April 10, 2026)
4. **Contacts**: Zack Imel (ZImel@gop.com, 270-799-0923), Danny Peletski (DPeletski@gop.com)

### Database Schema Setup on New Server
Create these schemas ONLY (no tables yet — tables come in later phases):
```sql
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS public;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS norm;
CREATE SCHEMA IF NOT EXISTS archive;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS volunteer;
CREATE SCHEMA IF NOT EXISTS donor_intelligence;
CREATE SCHEMA IF NOT EXISTS raw;
```

---

## PHASE 2 — LOAD FOUNDATION: DataTrust Full Voter File

### Why DataTrust First (NOT SBOE)
The DataTrust 252-column voter file is a SUPERSET of the NC SBOE voter file. It contains:
- `StateVoterID` (= NC SBOE `ncid`) — the state-assigned voter ID
- `RNC_RegID` — the universal key to Acxiom and all RNC systems
- All 67 SBOE columns PLUS 185 additional columns (modeled scores, parsed addresses, geocodes, household, ACS census data, change of address tracking, voting history)

Loading the SBOE file separately and then trying to bridge to DataTrust is WRONG. It was tried before and caused confusion. The DataTrust file IS the voter file — enriched.

### Source Options (in priority order)
1. **Full 2,200-variable DataTrust dump** — Zack Imel agreed to provide. Check if delivered.
2. **DataTrust API** via old Hetzner (5.9.99.109) which is already whitelisted — pull the 252-column voter file for NC
3. **VoterSnapshot view** from MSSQL (`rncazdwsql.cloudapp.net:52954`, database `myodd_nc_statecomm`) — at minimum gives us the `StateVoterID → RNC_RegID` bridge

### Target Table
```sql
-- DO NOT CREATE THIS TABLE YET
-- Present the CREATE TABLE DDL to Ed for approval first
-- Schema must match the 252 columns from 2025_Voterfile_Schema_Update.xlsx exactly
-- Column names must match DataTrust field names exactly (case-sensitive)
-- Primary key: RNC_RegID
-- Index on: StateVoterID, RNCID, LastName+RegZip5, RegHouseNum+RegZip5+LastName, CountyFIPS, CongressionalDistrict, StateLegUpperDistrict, StateLegLowerDistrict
```

### Verification Gate (must pass before Phase 3)
1. `SELECT COUNT(*) FROM datatrust_voter_file` ≈ 7.6M–7.7M for NC
2. `SELECT COUNT(DISTINCT StateVoterID) WHERE StateVoterID IS NOT NULL` — must equal row count (1:1)
3. `SELECT COUNT(DISTINCT RNC_RegID) WHERE RNC_RegID IS NOT NULL` — must equal row count (1:1)
4. `SELECT COUNT(DISTINCT CountyName)` = 100 NC counties
5. Broyhill canary: `SELECT * WHERE LastName = 'BROYHILL' AND RegZip5 = '27104'` — Ed must see his record
6. Report all counts to Ed. **Do not proceed without "I authorize this action."**

---

## PHASE 3 — LOAD ACXIOM CONSUMER DATA

### Source
Parquet file from Danny Peletski (Azure blob storage, expires April 30, 2026):
```
https://dlsrncprod.blob.core.windows.net/sandbox/DPeletski/Acxiom_National_Full_NC/part-00000-e23f0758-5b5c-4e9d-9972-b2e1d6abfcb8-c000.snappy.parquet?sv=2023-11-03&spr=https&st=2026-04-09T11%3A48%3A23Z&se=2026-04-30T11%3A48%3A00Z&sr=b&sp=r&sig=4lclFiseWjG6gmYlvxnD35CjI6udlWlhFY1er5iA4Ck%3D
```

### IMPORTANT: Download this file IMMEDIATELY to the new server. Do not wait. Link expires April 30.
```bash
wget -O /data/acxiom/acxiom_nc_full.parquet "https://dlsrncprod.blob.core.windows.net/sandbox/DPeletski/Acxiom_National_Full_NC/part-00000-e23f0758-5b5c-4e9d-9972-b2e1d6abfcb8-c000.snappy.parquet?sv=2023-11-03&spr=https&st=2026-04-09T11%3A48%3A23Z&se=2026-04-30T11%3A48%3A00Z&sr=b&sp=r&sig=4lclFiseWjG6gmYlvxnD35CjI6udlWlhFY1er5iA4Ck%3D"
```

### Join Key
`acxiom.RNC_RegID = datatrust.RNC_RegID`

### Acxiom has three data layers (from the workbooks Eddie provided):
1. **Market Indices** (dt_vf_marketindices) — 1,132 cols — geo/census/ACS data
2. **IBE Individual Behavioral** (dt_vf_ibe) — 8,685 cols — consumer behavior, household, economic
3. **AP Models** (dt_vf_apmodels) — predictive scores, propensity models

### Schema Design Decision
DO NOT create 10,000 scalar columns. Use one of:
- **Option A**: JSONB column per Acxiom layer (market_indices JSONB, ibe JSONB, ap_models JSONB) — flexible, queryable
- **Option B**: Separate tables per layer, joined by RNC_RegID — traditional star schema
- **Present both options to Ed for decision before creating anything.**

### Verification Gate
1. Row count matches DataTrust voter count for NC
2. `SELECT COUNT(*) WHERE RNC_RegID IS NOT NULL` = total rows
3. Spot-check: Ed Broyhill's record has Acxiom data populated
4. Report to Ed. **Do not proceed without approval.**

---

## PHASE 4 — LOAD RNC FACT TABLES

### Tables Available via API or MSSQL
| Table | Source | Key | Purpose |
|-------|--------|-----|---------|
| FactAbsenteeHarvest | API: `GET /api/Absentee` | RNC_RegID + StateVoterID | Absentee ballot tracking |
| FactInitiativeContacts | API: `GET /api/Contacts` (TBD) | RNC_RegID + StateVoterID | Voter contact history (canvassing, phone banks) |
| FactInitiativeContactDetails | Joined to Contacts via ContactKey | ContactKey | Question/answer details from contacts |
| DimElection | API: `GET /api/Elections` (TBD) | ElectionKey | Election reference data |
| DimOrganization | API: `GET /api/Organizations` (TBD) | OrganizationKey | Contact organizations |
| DimTag | API: `GET /api/Tags` (TBD) | TagKey | Initiative tags |

### API Authentication
- OAuth2 via Azure AD
- Token URL: `https://rncdatahubapi.gop/dev/api/Authenticate`
- ClientID: [REDACTED — see CREDENTIALS_MASTER.md]
- ClientSecret: [REDACTED — see CREDENTIALS_MASTER.md]
- Token valid ~1 hour
- Use `top` and `skip` for pagination (plain params, NOT OData `$top`)
- Swagger: https://rncdhapi.azurewebsites.net/swagger/index.html
- Support: Danny Peletski (dpeletski@gop.com)

### REQUIRES WHITELIST on new server IP (37.27.169.232). Use old server (5.9.99.109) as fallback.

---

## PHASE 5 — REBUILD THE PEARL (person_spine)

### Approach
The person_spine must be rebuilt from the DataTrust voter file as foundation, NOT from donor files.

1. Every NC voter with `VoterStatus = 'A'` (Active) gets a row in person_spine
2. Primary key: `RNC_RegID`
3. `StateVoterID` (= ncid) stored as a column for SBOE cross-reference
4. All DataTrust demographic, geographic, and modeled columns flow onto the spine
5. Acxiom behavioral data accessible via `RNC_RegID` join

### The Canary
Ed Broyhill must appear as ONE record with:
- All 8 name variants resolved (ED, EDGAR, JAMES, JAMES EDGAR, J, EDWARD — note: ED maps to EDGAR, NOT EDWARD)
- Address: 525 N Hawthorne, Winston-Salem 27104
- Correct honorific: Committeeman
- All donation totals summed correctly

---

## PHASE 6 — LOAD CLEAN DONOR FILES

### Source: Ed's laptop. 18 GOLD NCBOE files + pure FEC files.

### NCBOE GOLD Files (from MASTER_FILE_MANIFEST.md):
| File | Status |
|------|--------|
| 2ndary-counties-muni-cty-gop-2015-2026.csv | APPROVED |
| 2ndary-sheriff-gop-2015-2026.csv | APPROVED |
| 2015-2025-lt-governor.csv | APPROVED |
| 2015-2026-Mayors.csv | APPROVED |
| 2015-2026-NC-Council-of-state.csv | APPROVED |
| 2015-2026-supreme-court-appeals-.csv | APPROVED |
| clerk-court-gop-2015-2026.csv | APPROVED |
| council-city-town-gop-2015-2026.csv | APPROVED |
| Council-commissioners-gop-2015-2026.csv | APPROVED |
| County-Municipal-100-counties-GOP-2015-2026.csv | APPROVED |
| District-Att-gop-100 counties-2015-2026.csv | APPROVED |
| District-ct-judge-gop-100-counties-2015-2026.csv | APPROVED |
| governor-2015-2026.csv | APPROVED |
| Judicial-gop-100-counties-2015-2026.csv | APPROVED |
| NC-House-Gop++-2015-2026.csv | APPROVED |
| NC-Senate-Gop-2015-2026.csv | APPROVED |
| school-board-gop-2015-2026.csv | APPROVED |
| sheriff-only-gop-100-counties.csv | APPROVED |

### FEC Files (14 locked files from MASTER_FILE_MANIFEST.md):
Desktop folder: `/Users/Broyhill/Desktop/AAA FEC Federal Pres Senate House/`
Load AFTER NCBOE spine is stable. Individual donors to Republican candidates only.

### Load Protocol (NON-NEGOTIABLE)
1. Ed transfers file to server
2. Agent presents: filename, row count, sample rows to Ed
3. Ed says **"I authorize this action"**
4. TRUNCATE target raw table first
5. Load file
6. Verify count matches
7. Run enrichment pipeline (voter_ncid linkage, normalization, DataTrust sync)
8. Verify enrichment before loading next file

### Matching Donor Records to Voter File
The 7-pass rollup from `2026-03-31_DONOR_ROLLUP_IDENTITY_SPEC.md`:

| Pass | Anchor | Confidence |
|------|--------|------------|
| Pass 1 | `voter_ncid` exact bridge → DataTrust `StateVoterID` | 100% — auto-merge |
| Pass 2 | `RegHouseNum` + `RegZip5` + last name prefix | 97% — single match auto |
| Pass 3 | Employer + SIC + last prefix | 94% |
| Pass 4 | FEC + NCBOE cross-reference (two govt sources) | 98% |
| Pass 5 | Committee loyalty fingerprint (3+ same committees) | 96% |
| Pass 6 | Canonical first name + last + zip (nickname normalization) | 90% |
| Pass 7 | Last + first + zip (standard) | 85% |

**CRITICAL RULES:**
- Never merge on name alone — always require a second anchor
- Multi-matches go to review queue — never auto-merge ambiguous cases
- Birth year guard: `ABS(birth_year_a - birth_year_b) <= 5` when both known
- ED maps to EDGAR, not EDWARD — ever
- High name variation count (10+) = positive signal (repeat major donor), not noise
- 28-41% of FEC donors may not match voter file (dead, moved, divorced over 11 years) — these get Track 2 scoring on donation history alone, NEVER dropped

---

## PHASE 7 — REBUILD CONTRIBUTION MAP AND AGGREGATES

After donor files are loaded and matched:
1. Rebuild `core.contribution_map` from clean source tables
2. Compute spine aggregates (total_contributed, contribution_count, first/last gift, max gift, avg gift)
3. Apply donation level separation: federal, state, legislative, judicial, county/local
4. Canary check: Ed Broyhill total must match sum of contribution_map

---

## PHASE 8 — VOLUNTEER ECOSYSTEM AND HONORIFICS

1. Rebuild volunteer schema tables
2. Re-seed party organizations (NCGOP + 100 counties + 8 affiliates)
3. Tag officeholders from candidate data
4. Apply honorific system (Senator, Judge, Sheriff, Committeeman — never "Mr." for titled persons)
5. Low-dollar donors → volunteer prospects
6. Import FactInitiativeContacts for existing RNC volunteer contact history

---

## GUARDRAILS — MANDATORY FOR ALL AGENTS

### What You MAY Do Without Asking
- SELECT on any table
- CREATE TEMP TABLE
- Download files to the new Hetzner server (37.27.169.232)
- Write to staging schema on the new server
- Report findings via relay or to Ed

### What You MUST Present as DRY RUN First
- Any CREATE TABLE in core, public, or production schemas
- Any INSERT, UPDATE, DELETE on any non-temp table
- Any schema changes (ALTER TABLE, DROP COLUMN, etc.)
- Any index creation or deletion
- Any function creation

### What You MUST NEVER Do
- Touch SACRED tables (nc_datatrust, nc_voters, rnc_voter_staging, nc_voters_fresh)
- INSERT into nc_boe_donations_raw without TRUNCATE-first protocol and Ed's authorization
- Load any file not on the approved manifest without Ed's explicit authorization stating filename
- Map ED to EDWARD in any system
- Drop schema columns without knowing why they exist
- Improvise architecture from memory — read the session docs first
- Hardcode credentials in scripts or commit them to git

### The Two-Phase Protocol
1. **DRY RUN**: Present the exact SQL, the expected row counts, and the canary impact to Ed
2. **EXECUTION**: Only after Ed says **"I authorize this action"** (exact phrase)

---

## KEY CONTACTS

| Role | Person | Contact |
|------|--------|---------|
| Authority / NC National Committeeman | Ed Broyhill | ed@broyhill.net, 336-972-1000 |
| RNC Data Director | Zack Imel | ZImel@gop.com, 270-799-0923 |
| RNC Data (Acxiom/API) | Danny Peletski | DPeletski@gop.com |

---

## INFRASTRUCTURE

| Resource | Value |
|----------|-------|
| Supabase project | isbgjpnbocdkeslofota (us-east-1) |
| Supabase pooler | db.isbgjpnbocdkeslofota.supabase.co port 6543 |
| Supabase direct | db.isbgjpnbocdkeslofota.supabase.co port 5432 |
| New Hetzner | 37.27.169.232 (AX162-R, Finland) |
| Old Hetzner | 5.9.99.109 (relay, whitelisted for RNC API) |
| Old Hetzner 2 | 144.76.219.24 |
| RNC API | rncdatahubapi.gop (OAuth2, JWT) |
| RNC MSSQL | rncazdwsql.cloudapp.net:52954 (myodd_nc_statecomm) |
| GitHub | broyhill/BroyhillGOP |
| Relay | 5.9.99.109:8080 (API key: [REDACTED]) |

---

## THE JOIN CHAIN (memorize this)

```
nc_voters.ncid = DataTrust.StateVoterID → DataTrust.RNC_RegID = Acxiom.RNC_RegID
```

This is the universal key path. Everything connects through it. No fuzzy matching needed for voter-level joins.

---

*Created by Perplexity | April 10, 2026 2:05 PM EDT*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
*This is the final build. Do not deviate.*
