
# SESSION TRANSCRIPT — April 12, 2026
## BroyhillGOP Platform — Perplexity (CEO) + Ed Broyhill
### Duration: 1:18 PM – 4:00 PM EDT

---

## READ FIRST
Before doing any work, read these files in order:
1. sessions/SESSION_START_READ_ME_FIRST.md
2. sessions/COMPLETE_BUILD_TODO.md
3. sessions/DONOR_DEDUP_PIPELINE_V2.md
4. sessions/SESSION_APRIL10_2026_EVENING.md
5. This file (SESSION_APRIL12_2026.md)

---

## WHAT WAS ACCOMPLISHED TODAY

### Phase A — DataTrust Voter File: COMPLETE
- 7,727,637 rows loaded into `core.datatrust_voter_nc` on new server 37.27.169.232
- 252 columns, primary key on `rnc_regid`, 15 indexes
- Broyhill canary verified: JAMES EDGAR BROYHILL, rnc_regid c45eeea9-663f-40e1-b0e7-a473baee794e, ncid BN94856, 525 N Hawthorne Rd, Winston Salem 27104, Republican, born June 23 1954 (NOTE: DataTrust has June 21 — this is WRONG, Ed confirmed June 23)
- Join chain verified: state_voter_id = ncid, rnc_regid joins to Acxiom

### Phase B — Acxiom Consumer Data: RESTRUCTURING IN PROGRESS
- Original JSONB load completed overnight: 7,655,593 rows
- Ed requested Option C restructure (separate tables per layer) for production performance with 3,000 concurrent users
- Restructure script running in screen session `acxrestructure` on new server
- Three new tables being created:
  - `core.acxiom_ap_models` — AP predictive scores + TP + PX codes (~200 columns). 675,000 rows loaded as of 3:39 PM, still loading.
  - `core.acxiom_ibe` — IBE individual behavioral (~900 columns)
  - `core.acxiom_market_indices` — miACS census/geographic data (~800 columns)
- All joined by rnc_regid. Key political scores have individual indexes for fast campaign queries.
- Old JSONB table (`core.acxiom_consumer_nc`) will be dropped after restructure completes.

### Phase C — RNC Fact Tables: IN PROGRESS
- Absentee ballot data: 10,509,999 rows (8.2GB) and still downloading in screen session `factpull`
- After absentee completes, script auto-pulls: VoterContacts, Volunteers, Organizations, DimElection, DimOrganization, DimTag
- All saved to /data/rnc/ as JSONL files

### Ed Broyhill Canonical Profile: CREATED
- 9-page DOCX with all 2,177 variables
- Exported to Google Drive
- Ed reviewed and found errors in Acxiom data (see KEY FINDINGS below)

### Acxiom Variable Report: CREATED
- V3 report: 1,170 non-null variables, 928 defined, 242 still undefined
- 242 undefined are IBE codes not documented in any of Danny Peletski's files
- Danny's three workbooks (apmodels, ibe, marketindices) are ALL the documentation Acxiom provides
- Need to ask Danny for full IBE data dictionary for the remaining 242

---

## KEY FINDINGS FROM ED'S PROFILE REVIEW

Ed reviewed his own Acxiom profile and found significant errors. This has design implications for the platform:

### Acxiom Errors on Ed Broyhill's Record
| Field | Acxiom Says | Reality |
|-------|-------------|---------|
| Birthday | June 21, 1954 | June 23, 1954 |
| Republican view (AP006784) | 74/100 | Should be 99-100 — he IS the NC National Committeeman |
| Fundraising propensity (AP001722) | 6/20 | Has hosted 248 fundraisers in his life |
| Coalition IDs | Sportsmen=1, all others=0 | Should be Fiscal Conservative, Pro-Life, 2nd Amendment |
| Political contributor (AP005098) | 3/20 | Top 20 donor in the state |
| Home value (AP000444) | $348,000 | $1,800,000 (real property data IBE8702 shows $2,550,000 purchase price) |
| Vehicles | 2016 Chrysler Town & Country | That's his father's van, not his |
| Net worth | $199,000 | Not even close |

### Ed's mother Louise Broyhill scores 100 on Republican scale — but voted for Biden and Obama.

### PLATFORM DESIGN RULE (from Ed):
Acxiom modeled scores are LAST RESORT. The hierarchy:
1. Donation history (what they gave, to whom, how much) — REAL
2. Voting history (which primaries, turnout) — REAL  
3. Party positions (officer, delegate, committee member) — REAL
4. Volunteer activity (events hosted, contacts made) — REAL
5. Acxiom modeled scores — only when 1-4 are empty

Every variable needs SOURCE ATTRIBUTION. The spine must store multi-source scores:
- republican_score_acxiom (modeled)
- republican_score_datatrust (CalcParty)
- republican_score_donation (computed from giving)
- republican_score_voting (computed from primary ballots)
- republican_score_party (computed from officer/delegate roles)
- republican_score_composite (weighted blend — THIS is what candidates see)

Ed's quote: "We are the Gold Standard with bad info." Nobody else has this data at all. Acxiom is the wrapping paper. Donation history is the truth.

---

## NCBOE FILE SCHEMA — CRITICAL CORRECTIONS

### EXACT Column Headers (with NCBOE typos — DO NOT CORRECT):
```
1.  Name
2.  Street Line 1
3.  Street Line 2
4.  City
5.  State
6.  Zip Code
7.  Profession/Job Title
8.  Employer's Name/Specific Field
9.  Transction Type          ← TYPO: missing 'a' in Transaction
10. Committee Name
11. Committee SBoE ID
12. Committee Street 1
13. Committee Street 2
14. Committee City
15. Committee State
16. Committee Zip Code
17. Report Name
18. Date Occured             ← TYPO: missing 'r' in Occurred
19. Account Code
20. Amount
21. Form of Payment
22. Purpose
23. Candidate/Referendum Name
24. Declaration
```

### CSV Parser MUST:
- Match these EXACT misspelled column names, or use column position (1-24)
- Handle the apostrophe in "Employer's Name/Specific Field"
- Handle Windows line endings (\r\n)

### Name Field Format: FIRST MIDDLE LAST
- ED BROYHILL → first=ED, last=BROYHILL
- THOMAS L 'TOM' ADAMS → first=THOMAS, middle=L, nickname=TOM, last=ADAMS
- T.JONATHAN ADAMS → first=T.JONATHAN, last=ADAMS (period, no space)
- JAMES EDGAR 'ED' BROYHILL → first=JAMES, middle=EDGAR, nickname=ED, last=BROYHILL
- JAMES T BROYHILL JR → first=JAMES, middle=T, last=BROYHILL, suffix=JR
- Blank name = unitemized donation, skip for matching, keep for committee totals

### FEC Name Format (different!): LAST, FIRST MIDDLE
- BROYHILL, JAMES EDGAR → last=BROYHILL, first=JAMES, middle=EDGAR
- Split on first comma

### ED = EDGAR, never EDWARD. Ever.

---

## EMPLOYER / SIC CODE AS MATCHING ANCHOR

Ed emphasized: the employer name is a critical dedup anchor because 75% of major donors file from their business address, not home. The voter file only knows home address.

The SIC/NAICS code is MORE stable than the employer text string because:
- ANVIL VENTURE GROUP, ANVIL VENTURES, ANVILE VENTURE (typo) all map to one SIC code
- SIC 6726 (Investment Offices) doesn't have typos
- The `employer_sic_master` table (62,100 mappings) normalizes text → code

Matching with SIC: last_name + SIC_code + city → unique match even for common names.

The employer normalizer in the pipeline MUST include SIC/NAICS lookup, not just text cleanup.

---

## LATITUDE/LONGITUDE — CONFIRMATION ONLY, NOT PRIMARY MATCH

Lat/long fails as a primary anchor because:
- Donor files from office address (different lat/long than voter registration)
- Second homes in different counties (beach, mountain, Florida)
- 75% of major donors = business address ≠ home address

Use lat/long to CONFIRM a match already identified by other means, not to discover matches.

---

## DONORS WITH NO ADDRESS

Some donors have 25+ transactions with no address at all. Handle via:
- Pass 3: employer + last name + committee city
- Pass 5: committee loyalty fingerprint (25 donations to same committees = identity)
- Pass 6: name variants from cluster
- If no match: Track 2, scored on donation history, flagged for manual review
- Never drop — 25 transactions = high-value donor

---

## INFRASTRUCTURE STATE (end of session)

### New Server: 37.27.169.232
| Item | Status |
|------|--------|
| OS | Ubuntu 24.04, 96 cores, 252GB RAM, 1.7TB free |
| PostgreSQL 16 | Running |
| core.datatrust_voter_nc | 7,727,637 rows — COMPLETE |
| core.acxiom_ap_models | Loading (~675K of 7.65M) — screen `acxrestructure` |
| core.acxiom_ibe | Queued (after ap_models) |
| core.acxiom_market_indices | Queued (after ibe) |
| core.acxiom_consumer_nc | OLD JSONB table — to be dropped after restructure |
| /data/rnc/absentee.jsonl | 10.5M rows (8.2GB) — still downloading in screen `factpull` |
| /data/rnc/ (other fact tables) | Queued after absentee |
| Relay | Running on port 8080 — screen `relay` |
| raw.ncboe_donations | Table NOT YET CREATED — Cursor needs to build this |

### Supabase (isbgjpnbocdkeslofota)
| Item | Status |
|------|--------|
| person_spine active | 74,407 (canary passing) |
| Broyhill canary | $352,416 (matches contribution_map) |
| nc_boe_donations_raw | Still contaminated — needs TRUNCATE + reload |
| Status | Stable, hourly canary check running |

### Screen Sessions on New Server
- `relay` — BroyhillGOP relay on port 8080
- `factpull` — RNC fact table downloads (absentee + 6 more)
- `acxrestructure` — Acxiom Option C table restructure

---

## WHAT CURSOR NEEDS TO DO NEXT

### Read these files first:
1. sessions/CURSOR_PHASE_D_ORDERS.md — the 6 tasks
2. sessions/DONOR_DEDUP_PIPELINE_V2.md — the dedup logic
3. This file (SESSION_APRIL12_2026.md) — the schema corrections and SIC requirement

### Build on the new server (37.27.169.232):
1. `raw.ncboe_donations` table with EXACT column names from the file (typos and all)
2. Name parser handling all edge cases (periods, quotes, initials, suffixes)
3. Address number extractor (house, PO Box, highway, suite, floor, rural route)
4. Employer normalizer WITH SIC/NAICS lookup
5. Normalization pipeline (CSV → parsed → staged)
6. Internal dedup clustering engine (Stage 1A-1G, reverse chronological)

### DO NOT:
- Touch Supabase
- Load any donor data — just build the infrastructure
- Correct the column name typos — match what the file says
- Map ED to EDWARD

---

## FILES ED PROVIDED TODAY
- District-ct-judge-gop-100-counties-2015-2026.csv — sample NCBOE GOLD file (used to verify schema)
- 2015-2026-NC-Council-of-state.csv — another GOLD file (from previous session)
- All RNC documentation files (re-uploaded for reference)
- Screenshot of Danny Peletski's email confirming the 3 Acxiom workbooks are ALL the documentation

---

## 12 FAILED ATTEMPTS AT STAGING

Ed noted this is the 12th time we've attempted to stage the ingestion pipeline. Every previous attempt failed due to:
- Not reading the actual data before writing parsers
- Column name mismatches (typos in headers)
- Wrong name field order assumptions
- Not including SIC/NAICS in the employer normalizer
- Redesigning instead of executing
- Agents not reading session docs

This time: read the data first, match the actual schema, include SIC codes, stick to the plan.

---

*Written by Perplexity (CEO) at Ed Broyhill's direction, April 12, 2026 4:00 PM EDT*
*Do not modify without Ed's authorization.*
