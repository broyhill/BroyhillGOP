# FEC Pull v2 — Approved Search Criteria
**Approved by Ed Broyhill | April 4, 2026 5:16 PM EDT**
**DO NOT MODIFY without Ed's explicit re-approval**

---

## 16 Parameters — All Approved

### 1. NC Residents Only — TWO LAYERS
- **Layer 1 (API):** `contributor_state=NC` on every Schedule A query
- **Layer 2 (Script):** Drop any row where `contributor_state != 'NC'` immediately after receipt
- Blocked: all 49 other states, DC, PR, GU, VI, AS, MP, foreign countries, blank/null
- A Virginia donor giving $500,000 to a NC Republican — NOT in the file. Ever.

### 2. Republican Committees Only — TWO LAYERS
- **Layer 1 (API):** `party=REP` in committee discovery query
- **Layer 2 (Script):** Drop any committee where `party != 'REP'`
- Explicitly blocked: DEM, IND, GRE, LIB, CON, NNE, UNK, OTH, blank/null

### 3. Principal Campaign Committee Only
- **API:** `designation=P`
- Excludes: leadership PACs, super PACs, joint fundraising committees, affiliated committees

### 4. Committee Type — H, S, P Only
- House pull: `committee_type=H` only
- Senate pull: `committee_type=S` only
- Presidential pull: `committee_type=P` only (fixed list)

### 5. Committee State = NC (House and Senate)
- Applied during committee discovery
- Presidential exempt — presidential committees register federally, not by state

### 6. Cycles = 2016, 2018, 2020, 2022, 2024, 2026
- Six two-year federal election cycles
- Covers full 2015–2026 window
- No data outside these cycles

### 7. Schedule A Only
- Individual contribution receipts only
- Excludes: Schedule B (disbursements), Schedule E (independent expenditures), committee-to-committee transfers

### 8. is_individual = true
- Individual human donors only
- Excludes: corporations, LLCs, unions, other committees

### 9. Date Range: 01/01/2015 — 12/31/2026
- Hard boundary on every query
- Nothing before 2015, nothing after 2026

### 10. per_page = 100 — Full Pagination
- Maximum allowed per API call
- Script paginates all pages until exhausted
- No records skipped

### 11. FEC_ContributorID Captured
- New field: `contributor_id` from Schedule A
- Blank for most individuals but captured when FEC populates it
- Added to flatten_record in commit 3dfc72466cf7

### 12. Sequential Runs Only
- Presidential first (~30 min)
- Senate second (~2 hours)
- House already complete (65,883 rows, April 4 2026)
- No parallel jobs sharing the key

### 13. OPENFEC_REQUEST_DELAY = 2.0 seconds
- Two-second pause between every API call
- Prevents 429 rate limit collisions

### 14. Presidential — Fixed Committee List
**34 confirmed IDs + 5 pending lookup by Cursor before pull starts**

#### Confirmed:
| Candidate | Cycle | Committee ID | Committee Name |
|-----------|-------|-------------|----------------|
| Trump, Donald | 2016 | C00580100 | MAKE AMERICA GREAT AGAIN PAC |
| Trump, Donald | 2016/2020 | C00618371 | TRUMP MAKE AMERICA GREAT AGAIN COMMITTEE |
| Trump, Donald | 2024 | C00828541 | NEVER SURRENDER, INC. |
| Cruz, Ted | 2016 | C00574624 | CRUZ FOR PRESIDENT |
| Rubio, Marco | 2016 | C00458844 | MARCO RUBIO FOR PRESIDENT |
| Bush, Jeb | 2016 | C00579458 | JEB 2016, INC. |
| Carson, Ben | 2016 | C00573519 | CARSON AMERICA |
| Kasich, John | 2016 | C00581876 | KASICH FOR AMERICA, INC. |
| Fiorina, Carly | 2016 | C00577312 | CARLY FOR PRESIDENT |
| Christie, Chris | 2016 | C00580399 | CHRIS CHRISTIE FOR PRESIDENT INC |
| Huckabee, Mike | 2016 | C00431809 | HUCKABEE FOR PRESIDENT, INC. |
| Huckabee, Mike | 2016 alt | C00577981 | HUCKABEE FOR PRESIDENT, INC. |
| Walker, Scott | 2016 | C00580480 | SCOTT WALKER INC |
| Jindal, Bobby | 2016 | C00580159 | JINDAL FOR PRESIDENT |
| Graham, Lindsey | 2016 | C00578757 | LINDSEY GRAHAM 2016 |
| Pataki, George | 2016 | C00578245 | PATAKI FOR PRESIDENT INC |
| Perry, Rick | 2016 | C00500587 | PERRY FOR PRESIDENT INC |
| Gilmore, Jim | 2016 | C00582668 | GILMORE FOR AMERICA LLC |
| Weld, Bill | 2020 | C00700906 | WELD 2020 PRESIDENTIAL CAMPAIGN COMMITTEE |
| Walsh, Joe | 2020 | C00717033 | WALSH FOR PRESIDENT |
| DeSantis, Ron | 2024 | C00841155 | TEAM DESANTIS 2024 |
| Ramaswamy, Vivek | 2024 | C00833913 | VIVEK 2024 |
| Christie, Chris | 2024 | C00842237 | CHRIS CHRISTIE FOR PRESIDENT, INC. |
| Pence, Mike | 2024 | C00842039 | MIKE PENCE FOR PRESIDENT |
| Hutchinson, Asa | 2024 | C00837104 | ASA FOR AMERICA, INC. |
| Burgum, Doug | 2024 | C00842302 | DOUG BURGUM FOR AMERICA, INC. |
| Elder, Larry | 2024 | C00839365 | ELDER FOR PRESIDENT 24 |
| Hurd, Will | 2024 | C00843540 | HURD FOR AMERICA, INC. |
| Suarez, Francis | 2024 | C00842971 | SUAREZ FOR PRESIDENT, INC. |
| Johnson, Perry | 2024 | C00833160 | PERRY JOHNSON FOR PRESIDENT INC. |

#### Cursor Must Look Up Before Pull Starts:
| Candidate | Cycle | Status |
|-----------|-------|--------|
| Paul, Rand | 2016 | LOOKUP NEEDED |
| Santorum, Rick | 2016 | LOOKUP NEEDED |
| Sanford, Mark | 2020 | LOOKUP NEEDED |
| Haley, Nikki | 2024 | LOOKUP NEEDED |
| Scott, Tim | 2024 | LOOKUP NEEDED |

### 15. Explicit Party Committee Exclusion — TWO LAYERS
- **Layer 1 (API):** `committee_type=H/S/P` only
- **Layer 2 (Script):** Drop any committee where type is X, Y, Z, Q, N, O, U, V, W
- Drop any committee name containing: REPUBLICAN PARTY, GOP, NRCC, NRSC, RNC, NCGOP, VICTORY

### 16. Explicit Non-Republican Candidate Exclusion — TWO LAYERS
- **Layer 1 (API):** `party=REP` in discovery
- **Layer 2 (Script):** Verify party=REP on every committee before querying Schedule A
- Explicitly blocked parties: DEM, IND, GRE, LIB, CON, NNE, UNK, OTH, blank, null

---

## Output Fields (every row)
| Field | FEC Source |
|-------|-----------|
| FEC_TransactionID | sub_id |
| FEC_ContributorID | contributor_id ← NEW |
| CandidateName | candidate_name |
| CommitteeName | committee_name |
| FEC_CommitteeID | committee_id |
| FEC_CandidateID | candidate_id |
| Party | party |
| Cycle | two_year_transaction_period |
| DonationAmount | contribution_receipt_amount |
| FullName | contributor_name |
| norm_first | normalized first name |
| norm_last | normalized last name |
| contributor_zip5 | zip truncated to 5 digits |
| City | contributor_city |
| State | contributor_state |
| Occupation | contributor_occupation |
| Employer | contributor_employer |
| receipt_date | contribution_receipt_date |
| primary_or_general | election_type |
| CandidateOffice | office |
| CandidateState | candidate_office_state |
| CandidateDistrict | candidate_office_district |

---

## Dry Run Protocol (MANDATORY before full pull)
1. Cursor updates script with all 16 parameters
2. Run single committee test: `--test-committee C00574624 --limit 10`
3. Ed and Perplexity inspect 10 rows together:
   - All State = NC? ✓
   - All Party = REP? ✓
   - FEC_ContributorID column present? ✓
   - No party committees? ✓
4. Ed approves dry run
5. Full pull begins — Presidential first, then Senate

---

## Run Sequence
1. Cursor looks up 5 missing presidential committee IDs
2. Cursor updates script — all 16 parameters enforced
3. Dry run — 10 rows, Ed approves
4. Presidential alone: `--presidential-nc-export-only` | est. ~30 min
5. Senate alone: `--office S` | est. ~2 hours
6. House: already complete — 65,883 rows in hand, load with NC filter

---
*Approved by Ed Broyhill | April 4, 2026 | BroyhillGOP-Claude*
