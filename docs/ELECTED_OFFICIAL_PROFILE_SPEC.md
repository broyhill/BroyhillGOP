# Elected Official & PAC Profile Page Spec
## BroyhillGOP — E03 Candidate Management + E01 Donor Intelligence
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## SCOPE
One profile page per entity:
- Every NC Republican elected official (federal → municipal)
- Every PAC / committee / activist org in the registry

---

## PART 1: ELECTED OFFICIAL PROFILE PAGE

### Header Card
- Full name + photo
- Office title + district/county
- Party (R)
- Term dates (start → end / next election date)
- Office level badge: FEDERAL | STATE | JUDICIAL | COUNTY | MUNICIPAL | SCHOOL BOARD
- Status badge: INCUMBENT | CHALLENGER | OPEN SEAT

### Contact & Links Bar
- Official website
- Campaign website
- NCGA profile link (for state legislators): `ncleg.gov/Members/MemberInfo/H|S/{id}`
- FEC profile link (federal): `fec.gov/data/candidate/{fec_id}/`
- NC SBOE candidate filing: `ncsbe.gov`
- Facebook | Twitter/X | Instagram | LinkedIn
- Campaign finance dashboard (SBOE or FEC)
- Email (official + campaign)
- Phone (office + campaign)
- Mailing address

### Bio Card
- Age / date of birth
- Hometown / city of residence
- Education (schools, degrees)
- Occupation / employer
- Military service (if any)
- Religion (if public)
- Family (spouse, children)
- Years in office / prior offices held
- Committee assignments (for legislators)
- Leadership roles (Speaker, Majority Leader, Caucus chair, etc.)

### Issue Tags Card
- All `issue_tags` assigned to this candidate
- Displayed as colored chips: school_choice | second_amendment | pro_life | etc.
- Primary issues highlighted larger

### Voting Record Card (legislators only)
- Link to voting record on NCGA or VoteSmart
- Key votes on top 25 conservative issues
- Conservative scorecard ratings:
  - NC Chamber score
  - American Conservative Union (ACU) rating
  - Heritage Action scorecard
  - Club for Growth rating (federal)
  - NRA grade (A+ through F)
  - NC Values Coalition scorecard
  - Right to Life score

### Donor Intelligence Card
- Total raised this cycle
- Total raised all-time (from SBOE/FEC)
- Top 10 individual donors (name, amount, employer)
- Top 10 PAC donors (committee name, amount, partisan_lean)
- Donor geography map (county-level heatmap of donors)
- Donor industry breakdown (pie chart — real estate, healthcare, finance, etc.)
- Avg donation size
- # of unique donors
- In-state vs out-of-state %
- Small dollar (<$200) vs large dollar (>$1000) split

### PAC Affinity Card
- All PACs that have donated to this candidate (from contribution_map)
- Each PAC shown with: name | amount | partisan_lean | issue_tags
- "Donor coalition" — which issue categories fund this candidate most

### Opponent / Race Card
- Current race: opponent name(s), party
- Poll averages (if available)
- Cook/Sabato race rating
- Prior election results (% won by)
- District partisan lean (R+/D+ score)

### Canvassing / Field Card (internal use)
- Volunteer assignments in this district
- GOTV targets in district (from voter file)
- Key precincts
- Phone bank lists

---

## PART 2: PAC / COMMITTEE PROFILE PAGE

### Header Card
- Committee name
- Committee type (PAC | SuperPAC | 501c4 | Party Committee | Candidate Committee | etc.)
- Tier (1-8 per taxonomy)
- Partisan lean badge: **R** | **D** | **N** | **U**
- Status: ACTIVE | INACTIVE | DISSOLVED

### Registration & Links Bar
- NC SBOE Committee ID + link: `ncsbe.gov/Campaign-Finance`
- FEC Committee ID + link: `fec.gov/data/committee/{id}/`
- Official website
- Social media links
- Treasurer name + contact
- Filing frequency (monthly | quarterly | semi-annual)

### Financial Summary Card
- Total raised (all-time)
- Total raised (current cycle)
- Total spent (all-time / current cycle)
- Cash on hand
- Top donors to this PAC (individuals + orgs that fund it)
- Filing history links

### Giving History Card
- Total given to candidates (all-time)
- Total given to R candidates vs D candidates vs N candidates
- Partisan lean % calculated from actual giving
- Top 20 candidates received (name | office | amount | year)
- Giving by office level (federal | state | judicial | county | municipal)
- Giving by issue area (school choice | 2A | pro-life | etc.)
- Year-by-year giving chart

### Issue Tags Card
- All issue_tags for this committee
- Primary issue highlighted

### Connected Entities Card
- Parent organization (if chapter/affiliate)
- Sister PACs / related committees
- Known allied candidates
- Opposing PACs (who fights them)

---

## DATA SOURCES FOR PROFILE POPULATION

| Data Type | Source | Table |
|-----------|--------|-------|
| Candidate bio | NCGA website, FEC, VoteSmart | candidates |
| Voting record | NCGA, Congress.gov, VoteSmart | (external link) |
| SBOE donations received | NC SBOE campaign finance | nc_boe_donations_raw |
| FEC donations received | FEC bulk data | fec_donations |
| PAC donors to candidate | SBOE/FEC filings | contribution_map |
| Committee financial summary | SBOE/FEC | committee_registry |
| Issue tags | Manual + AI classification | candidate_issues |
| Voter file linkage | NCWRC/SBOE | nc_voters + nc_datatrust |
| Social media | Manual + scraping | candidates table |
| Scorecards | ACU, Heritage, NRA, NCVC websites | (external links) |
| Photos | Official NCGA/FEC photos | storage bucket |

---

## PRIORITY BUILD ORDER

### Phase 1 — State Legislators (already have roster)
- 30 NC Senate Republicans
- 70 NC House Republicans
- Source: NCGA website (already pulled)

### Phase 2 — Council of State
- 8 statewide officers
- Source: NC.gov

### Phase 3 — Federal Delegation
- 10 NC House Republicans + 2 US Senators
- Source: Congress.gov, FEC

### Phase 4 — Local (County/Municipal)
- 100 County Sheriffs
- 100 County Commissioner Boards
- 500+ Mayors
- Source: County websites, NCACC

### Phase 5 — PAC Registry
- All committees in committee_registry (10,975 rows)
- Source: SBOE + FEC bulk data

---

## ECOSYSTEM MAPPING
- **E03 Candidate Management** — candidate profile pages, bio, race info, voting record
- **E01 Donor Intelligence** — donor history, PAC donors, fundraising totals
- **E06 Analytics Engine** — scorecard ratings, partisan lean auto-calc
- **E20 Intelligence Brain** — AI-generated candidate briefings
- **E15 Contact Directory** — contact info, social links
- **E38 Field Operations** — canvassing/GOTV data overlay

---

*Prepared by Perplexity AI — March 31, 2026*
*Covers all NC elective offices — every profile, every PAC*
*Pending Claude implementation after Eddie approval*

---

## COMPLETE NC ELECTED OFFICE INVENTORY — CORRECTED & EXPANDED

### FEDERAL (NC delegation)
| Office | Current R Holder | Next Election | Profile Priority |
|--------|-----------------|---------------|-----------------|
| US Senate — Class 3 | **Ted Budd** | 2028 | HIGH |
| US Senate — Class 2 | **Thom Tillis** | 2026 ← UP NOW | URGENT |
| US House District 3 | **Greg Murphy** | Nov 2026 | HIGH |
| US House District 5 | **Virginia Foxx** | Nov 2026 | HIGH |
| US House District 6 | **Addison McDowell** | Nov 2026 | HIGH |
| US House District 7 | **David Rouzer** | Nov 2026 | HIGH |
| US House District 8 | **Mark Harris** | Nov 2026 | HIGH |
| US House District 9 | **Richard Hudson** (NRCC Chair) | Nov 2026 | HIGH |
| US House District 10 | **Pat Harrigan** | Nov 2026 | HIGH |
| US House District 11 | **Chuck Edwards** | Nov 2026 | HIGH |
| US House District 13 | **Brad Knott** | Nov 2026 | HIGH |
| US House District 14 | **Tim Moore** (former NC Speaker) | Nov 2026 | HIGH |
| *US House District 1* | Don Davis (D — R+5, target) | Nov 2026 | WATCH |
| *US House District 12* | Alma Adams (D) | Nov 2026 | low |

### NC COUNCIL OF STATE — Current Holders
| Office | Current Holder | Party | Next Election |
|--------|---------------|-------|--------------|
| Governor | Josh Stein | D | 2028 |
| Lt. Governor | Rachel Hunt | D | 2028 |
| Attorney General | Jeff Jackson | D | 2028 |
| Secretary of State | Elaine Marshall | D | 2028 |
| State Auditor | Dave Boliek | **R** | 2028 |
| State Treasurer | Brad Briner | **R** | 2028 |
| Superintendent of Public Instruction | Mo Green | D | 2028 |
| Commissioner of Agriculture | Steve Troxler | **R** | 2028 |
| Commissioner of Insurance | Mike Causey | **R** | 2028 |
| Commissioner of Labor | Luke Farley | **R** | 2028 |

*Note: R holds 5 of 10 Council of State seats. Governor, AG, Lt. Gov, SOS, Supt all D.*

### NC GENERAL ASSEMBLY LEADERSHIP — Profile Priority

#### NC House Leadership (R)
| Role | Member | District |
|------|--------|---------|
| Speaker | Destin Hall | 87 — Caldwell, Watauga |
| Speaker Pro Tempore | Mitchell S. Setzer | 89 — Catawba, Iredell |
| Majority Leader | Brenden H. Jones | 46 — Columbus, Robeson |
| Deputy Majority Leader | Steve Tyson | 3 — Craven |
| Majority Whip | Karl E. Gillespie | 120 — Cherokee, Clay, Graham, Macon |
| Majority Conference Co-Chair | Matthew Winslow | 7 — Franklin, Vance |
| Majority Conference Co-Chair | Jeff Zenger | 74 — Forsyth |
| Majority Caucus Joint Liaison | Harry Warren | 76 — Rowan |
| Majority Freshman Leader | Heather H. Rhyne | 97 — Lincoln |
| Deputy Majority Whips (5) | Biggs, Cairns, Jake Johnson, Penny, Reeder | various |

#### NC Senate Leadership (R) — need to pull separately
- President Pro Tempore: Phil Berger (District 26 — Guilford, Rockingham)
- Majority Leader: (pull from NCGA)
- Majority Whip: (pull from NCGA)

### NC GENERAL ASSEMBLY COMMITTEES — 44 House + 18 Senate standing committees
Key committees for PAC donor mapping:
- Agriculture and Environment — Farm Bureau, agribusiness PACs
- Appropriations (all subcommittees) — broad PAC interest
- Commerce and Economic Development — Chamber, business PACs
- Education — NCAE fights these seats, school choice PACs support
- Finance — banking, insurance, real estate PACs
- Health and Human Services — hospital, pharma, medical PACs
- Judiciary — NC Judicial Victory Fund, law enforcement
- Rules — leadership control — top PAC target
- Transportation — trucking, highway contractors

### NC JUDICIAL — STATEWIDE
| Office | # Seats | Currently R? | Next Election |
|--------|---------|-------------|--------------|
| NC Supreme Court | 7 justices | 5R, 2D | staggered terms |
| NC Court of Appeals | 15 judges | majority R | staggered terms |
| NC Business Court | 4 judges | appointed | N/A |

### NC JUDICIAL — LOCAL (100 counties)
| Office | # Offices | Notes |
|--------|----------|-------|
| Superior Court (resident) | ~100 judges | 8 divisions, multi-county |
| District Court | ~270 judges | Family, criminal, civil |
| District Attorney | 44 districts | Multi-county districts |

### NCGA MEMBERS MISSING FROM INITIAL PULL
The following were not captured in the initial browser pull — need to add:
- Jerry Carter (District 59, Guilford) — last name was cut off
- Any members appointed mid-session (check for vacancies filled since Nov 2024)

---

*Updated by Perplexity AI — March 31, 2026*
*Full federal delegation, Council of State current holders, NCGA leadership roles all documented*
