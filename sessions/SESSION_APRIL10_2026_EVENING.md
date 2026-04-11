# SESSION TRANSCRIPT — April 10, 2026 Evening
## BroyhillGOP Platform — Perplexity (CEO) + Ed Broyhill
### Duration: 1:15 PM – 10:45 PM EDT (9.5 hours)

---

## WHO IS ED BROYHILL

Ed Broyhill is the North Carolina Republican National Committeeman — the top GOP position in the state. He is the grandson of James Edgar "J.E." Broyhill, founder of Broyhill Furniture Industries (the largest furniture manufacturer in America). His father was U.S. Senator James Thomas Broyhill. His son Penn Broyhill is an NC Superior Court Judge. His son James Thomas Broyhill II runs JB by James Broyhill furniture. His company is Anvil Venture Group, named after his grandfather's biography "Anvil of Adversity."

Ed's full legal name is James Edgar Broyhill II. "Ed" is short for EDGAR (his middle name), NOT EDWARD. Every AI agent has gotten this wrong. Do not map ED to EDWARD. Ever.

Ed is also an A++ donor, volunteer, fundraiser host, RNC Convention Delegate, NCGOP Hall of Fame inductee, and recipient of the J.E. Broyhill GOP Award (the state party's highest achievement, named for his grandfather).

---

## WHAT IS THIS PROJECT

BroyhillGOP is a political data platform that combines:
1. NC voter file (9M+ voters)
2. DataTrust/RNC enriched voter file (252 columns per voter — demographics, voting history, parsed addresses, modeled scores, household data)
3. Acxiom consumer behavioral data (1,925 columns per voter — income, lifestyle, political propensity, purchasing behavior)
4. NCBOE state/local donor files (18 GOLD files covering Republican candidates 2015-2026)
5. FEC federal donor files (14 locked files — House, Senate, Presidential)
6. Volunteer tracking, party officer records, committee classifications
7. RNC fact tables (absentee ballot tracking, voter contact history from canvassing/phone banks)

The goal: build the most personalized campaign deployment platform in Republican politics. Match donors to candidates by district. Match volunteers to campaigns by skills and geography. Microsegment by industry, employer, and behavioral scores. Enable events like "25 bankers in Mecklenburg County meet the Banking Committee chairman."

---

## THE JOIN CHAIN (memorize this — it connects everything)

```
nc_voters.ncid = DataTrust.StateVoterID → DataTrust.RNC_RegID = Acxiom.RNC_RegID
```

- ncid = NC State Board of Elections voter ID
- StateVoterID = RNC's copy of ncid (same number)
- RNC_RegID = RNC's universal person ID (UUID) — the key to Acxiom and all RNC systems
- This is a deterministic one-to-one key join. No fuzzy matching needed for voter-level data.

---

## INFRASTRUCTURE (as of end of session)

| Resource | Details |
|----------|---------|
| Supabase (main DB) | Project: isbgjpnbocdkeslofota, us-east-1 |
| Supabase direct | db.isbgjpnbocdkeslofota.supabase.co port 5432 |
| Supabase pooler | port 6543 |
| Supabase password | Anamaria@2026@ |
| New Hetzner (PRIMARY) | 37.27.169.232 (AX162-R, Finland, 96 cores, 252GB RAM, 1.8TB RAID) |
| New Hetzner root pw | c7pgN4_fD63DnG |
| Old Hetzner (COMPROMISED) | 5.9.99.109 — DDoS abuse report, relay lives here, deadline April 11 11:50 PM UTC |
| Old Hetzner 2 (GPU) | 144.76.219.24 (GEX44, RTX 4000) root: NvHvF3mrZGvP7W |
| RNC API auth | POST https://rncdhapi.azurewebsites.net/api/Authenticate (NEW endpoint for auth) |
| RNC API data | GET https://rncdatahubapi.gop/api/{endpoint} (OLD endpoint for data) |
| RNC API trick | Auth at NEW endpoint, call OLD endpoint. Both return 200. |
| RNC Client ID | 07264d72-5f06-4de1-81c0-26909ac136f2 |
| RNC Client Secret | XK38Q~l6CI2XsaZljCZ3bW3csZwo~-3dBV1fZdlb |
| RNC MSSQL | rncazdwsql.cloudapp.net:52954 (myodd_nc_statecomm) — same client ID but MSSQL login credentials unknown (one-time link expired) |
| GitHub | broyhill/BroyhillGOP |
| Relay | 5.9.99.109:8080 (key: bgop-relay-k9x2mP8vQnJwT4rL) — at risk due to DDoS compromise |
| Zack Imel | RNC Data Director, ZImel@gop.com, 270-799-0923 |
| Danny Peletski | RNC Data, DPeletski@gop.com |

---

## RNC API ENDPOINTS (all working from 37.27.169.232)

| Endpoint | Purpose |
|----------|---------|
| /api/VoterFile | Full 252-column DataTrust voter file — THE FOUNDATION |
| /api/VoterFile/Count | Row count |
| /api/AcxiomConsumerData | 1,925-column consumer behavioral data |
| /api/Absentee | Absentee ballot tracking (requested, mailed, returned, rejected) |
| /api/FactInitiativeContacts | Voter contact history (door knocks, phone calls, canvassing) |
| /api/FactInitiativeContactDetails | Contact Q&A details |
| /api/DimElection | Election reference data |
| /api/DimOrganization | Contact organizations |
| /api/DimTag | Initiative tags |
| /api/Volunteers | Volunteer data |
| /api/VoterContacts | Voter contact records |
| /api/VoterTags | Voter tags |
| /api/Organizations | Organization records |

Pagination: use `top` and `skip` (plain params, NOT OData `$top`). Token valid ~1 hour. Refresh every 100 pages.

---

## WHAT WAS ACCOMPLISHED THIS SESSION

### 1. Read all reference materials
- SESSION_START_READ_ME_FIRST.md
- Deep Research transcript (ChatGPT agent analysis of dedup strategy)
- Cursor transcript (nightmare summary + implementation plan)
- All 4 RNC PDFs (Absentee, Contacts, API instructions, myODD login)
- 5 Excel workbooks (DataTrust 252-col schema, Acxiom API 148-col, Market Indices 1132-col, IBE 8685-col, AP Models)
- Credentials files

### 2. New Hetzner server fully set up (by Cursor)
- Ubuntu 24.04, PostgreSQL 16, Python 3.12
- 96 cores, 252GB RAM, 1.8TB disk
- Acxiom parquet downloaded: 7.8GB, 7,655,593 rows, 1,925 columns
- All schemas created (core, staging, norm, archive, audit, volunteer, donor_intelligence, raw)
- BroyhillGOP repo cloned
- Whitelisted for RNC API and MSSQL

### 3. VoterFile download started
- Using RNC API /api/VoterFile endpoint
- Downloading full 252-column NC voter file to /data/datatrust/nc_voterfile_full.jsonl
- Running in screen session on new server
- Hourly monitor cron watching progress
- Expected: 7.6M+ rows, finishing overnight

### 4. Supabase PITR reset executed
- Restored to April 8, 2026 7:00 AM EDT
- nc_boe_donations_raw still contaminated (incident #13 was before April 8)
- Will be TRUNCATED and reloaded from Ed's 18 GOLD files

### 5. Master Reset and Build Plan committed to GitHub
- sessions/MASTER_RESET_AND_BUILD_PLAN.md — 8-phase build sequence
- sessions/CURSOR_WORK_ORDERS_APR10.md — Cursor task list
- sessions/CURSOR_URGENT_SERVER_SETUP.md — Server setup checklist (completed)

### 6. Donor Dedup Pipeline V2 written and committed
- sessions/DONOR_DEDUP_PIPELINE_V2.md — the complete matching strategy
- Every rule comes from Ed's direct instruction
- THIS IS THE DOCUMENT YOU MUST READ BEFORE TOUCHING DONOR DATA

### 7. Hetzner abuse incident identified
- Old server 5.9.99.109 is sending DDoS traffic (UDP floods to 192.170.231.151)
- Docker container likely compromised
- Abuse report deadline: April 11, 2026 11:50 PM UTC
- Statement must be submitted at: https://abuse-network.hetzner.com/statement/0084eead-788b-41c6-9d71-2542842a218c
- Relay lives on this server — may need to migrate to new server

---

## THE DEDUP PIPELINE — READ THIS CAREFULLY

Full details in sessions/DONOR_DEDUP_PIPELINE_V2.md. Here is the summary:

### Why dedup is hard on this data

1. **Name chaos**: Ed Broyhill appears as ED BROYHILL, Ed Broyhill, JAMES EDGAR BROYHILL, JAMES EDGAR 'ED' BROYHILL, J BROYHILL — and ED means EDGAR not EDWARD
2. **Address chaos**: Same person files from home (525 N Hawthorne), office (202 North Hawthorne), PO Box, second home, beach house, mountain house
3. **Employer chaos**: ANVIL VENTURE GROUP, ANVIL VENTURES, ANVIL MANAGEMENT LLC, ANVILE VENTURE (typo), BROYHILL GROUP, BROYHILL INVESTMENTS — 12 variants for one person
4. **Time chaos**: 11-year file (2015-2026). Donors age, retire, die, divorce, remarry, move. A 2016 filing as CEO of XYZ Corp becomes a 2024 filing as RETIRED from same person.
5. **Major donors are hardest**: 75% of wealthy donors file from their BUSINESS address, not home. Voter file only knows home address. The most valuable people in the database are the hardest to match.
6. **NCBOE files have NO voter ID**: No ncid, no RNC_RegID. Only name, address, employer, committee. Must be matched using physical attributes.
7. **FEC files start with first name, NCBOE files start with last name**: Different name field order between sources.

### The matching strategy (NOT fuzzy matching — deterministic anchors)

**Process 2026 → 2015 (reverse chronological)**. The newest donation has the best chance of matching the current voter file.

**Stage 1: Internal dedup** — cluster the donor file against ITSELF first:
- Exact name + zip clusters
- Employer + last name + city clusters (catches business-address filers)
- Committee loyalty fingerprint (same person giving to same committee for 10 years)
- Collect ALL address numbers from both address lines (house, PO box, highway, suite, floor, rural route)
- Collect ALL name variants from actual filings (no nickname lookup tables)
- Collect ALL employers across 11 years (solves RETIRED problem)
- Collect ALL complete addresses (primary, office, second homes — never discard)

**Stage 2: Match clusters to DataTrust voter file** — 8 passes:

| Pass | Method | Confidence |
|------|--------|------------|
| 1 | DOB + Sex + Last Name + Zip (TOP SELECT — run first) | ~100% |
| 2 | Any address number + Last Name + Zip | 97% |
| 3 | Normalized employer + Last Name + City (key for major donors) | 94% |
| 4 | FEC + NCBOE cross-reference (same person in 2 govt sources) | 98% |
| 5 | Committee loyalty fingerprint (3+ same committees over years) | 96% |
| 6 | All name variants from cluster + Last Name + City | 90% |
| 7 | Geocode proximity (lat/long within 100m + last name) | 95% |
| 8 | Household matching (DataTrust HouseholdID — catches spouses) | 90% |

**Stage 3: Unmatched donors** — 28-41% won't match (dead, moved, divorced). NEVER DROP THEM. Score on donation history. Flag for manual review if > $1,000. Link deceased donors to surviving spouse.

### Critical rules (non-negotiable)
- ED maps to EDGAR, never EDWARD
- No nickname lookup tables — use actual name variants from donation history
- DOB + Sex is the top filter, not name or address
- Address numbers include PO Box, Highway, Suite, Floor — not just house numbers
- Employer is the bridge for major donors (75% file from business address)
- Collect all employers across 11 years (solves RETIRED problem)
- Committee loyalty fingerprint = identity proof
- Every donor matters equally — $100 today is $25,000 in 10 years
- Low-dollar donors are volunteer prospects
- Never drop unmatched donors
- Store ALL addresses including second homes (beach, mountain, Florida)
- Suffix (Jr., Sr., III) distinguishes family members in same household
- Multiple SIC/NAICS codes per donor — one person, many microsegments

---

## HONORIFIC SYSTEM

Every person in the database gets a correct title. Never address a titled person as Mr./Mrs. Priority:

1. President / Vice President
2. Governor / U.S. Senator / U.S. Representative
3. General officer (all stars addressed as "General")
4. Colonel and below (lifetime)
5. Judge (lifetime)
6. Tribal Chief / Principal Chief / Tribal Chairman
7. State Senator / State Representative
8. Mayor / Sheriff / DA / Commissioner
9. Party officer (Chairman, Committeeman)
10. Reverend / Pastor / Bishop / Chaplain / Deacon / Rabbi
11. Dr.
12. Military: Lt. General, Major General, Brigadier General → all "General"
13. Mrs. (married confirmed) / Ms. (default if unknown) / Miss (only if preferred)
14. Mr. — ONLY if nothing else applies

Titles are for LIFE. Former Senator = always Senator. Former Judge = always Judge. Retired Colonel = always Colonel. Military title outranks civilian.

Never address Governor James Green as "Dear Jimmy." Never.

---

## MICROSEGMENTATION VISION

The legally required employer disclosure on donations > $200 is the most powerful segmentation tool. Every donor gets tagged by ALL employers across 11 years → multiple SIC/NAICS codes → multiple microsegments.

Use cases:
- All bankers in Mecklenburg County → Banking Committee chairman fundraiser
- All teachers statewide → Superintendent of Education campaign
- All lawyers by county → Supreme Court candidate outreach
- All builders → Building Codes Committee chairman event
- All veterans → Armed Services congressman meet-and-greet
- All employees of same company → company networking event
- All donors in a specific precinct → candidate door-to-door volunteer deployment

Low-dollar donors are volunteer prospects. A $100 donor who volunteers 200 hours is worth more to a State House candidate than a $5,000 donor in another district who never shows up.

---

## DATABASE STATE (end of session)

| Item | Status |
|------|--------|
| Supabase person_spine active | 74,407 (correct — D-flag cleanup was intentional) |
| Supabase person_spine inactive | 125,976 |
| Supabase contribution_map | 2,960,201 rows |
| Supabase nc_boe_donations_raw | 538,368 (CONTAMINATED — needs TRUNCATE + reload) |
| Supabase fec_donations | 779,182 (zero person_id — needs 7-pass dedup) |
| Broyhill canary | $352,416 (missing NCBOE state donations — will recover with GOLD file reload) |
| New server Acxiom | 7,655,593 rows, 1,925 columns — DOWNLOADED |
| New server VoterFile | DOWNLOADING — 7.6M rows expected overnight |
| New server PostgreSQL | Running, schemas created, no tables yet |
| Old server 5.9.99.109 | COMPROMISED — DDoS, abuse deadline tomorrow |

---

## CANARY SYSTEM

The "canary" is Ed Broyhill's own donor record (person_id 26451). It is checked every hour. If his total_contributed on the spine doesn't match the sum in contribution_map, something went wrong. This caught every database corruption incident.

Current canary: $352,416 (missing NCBOE data). Target when fully loaded: $857K-$1M+.

---

## 13 CONTAMINATION INCIDENTS

This database has been corrupted 13 times by AI agents who did not read the session docs before acting. The causes:
- Loading files without TRUNCATE-first protocol
- Loading Democrat candidate donations into a Republican-only database
- Running bulk UPDATE/DELETE without audit trails
- Improvising architecture from memory instead of reading docs
- Not following the two-phase protocol (DRY RUN → Ed authorizes → EXECUTE)

DO NOT BECOME INCIDENT #14.

---

## TWO-PHASE PROTOCOL (mandatory)

1. **DRY RUN**: Present the exact SQL, expected row counts, and canary impact
2. **EXECUTION**: Only after Ed says "I authorize this action"

Exception: Ed authorized blanket execution for infrastructure setup and file downloads on April 10. This does NOT extend to loading data into production tables or modifying the spine.

---

## WHAT HAPPENS NEXT (Monday priority)

1. VoterFile download completes overnight → verify row count (~7.6M)
2. Submit Hetzner abuse statement for 5.9.99.109 (deadline tomorrow evening)
3. Design the DataTrust voter table schema on new server (252 columns from 2025_Voterfile_Schema_Update.xlsx)
4. Load VoterFile JSONL into PostgreSQL on new server
5. Join Acxiom data by RNC_RegID
6. TRUNCATE nc_boe_donations_raw on Supabase, reload from Ed's 18 GOLD files
7. Run the 7-pass dedup pipeline on donor data
8. Migrate critical tables from Supabase to new server
9. Rebuild the spine on new architecture (RNC_RegID as primary key)

---

## FILES TO READ BEFORE ANY WORK

1. sessions/SESSION_START_READ_ME_FIRST.md
2. sessions/MASTER_RESET_AND_BUILD_PLAN.md
3. sessions/DONOR_DEDUP_PIPELINE_V2.md
4. sessions/SESSION_APRIL10_2026_EVENING.md (this document)

---

*Written by Perplexity (CEO) at Ed Broyhill's request, April 10, 2026 10:45 PM EDT*
*Every rule in this document comes from Ed's direct instruction over 9.5 hours.*
*Do not modify without Ed's authorization.*
