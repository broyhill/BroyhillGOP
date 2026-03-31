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
