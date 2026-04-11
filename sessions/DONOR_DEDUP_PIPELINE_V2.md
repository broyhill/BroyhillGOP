# DONOR DEDUP PIPELINE V2 — BroyhillGOP
**Created: April 10, 2026 10:23 PM EDT**
**Authority: Ed Broyhill | NC National Committeeman**
**Author: Perplexity (CEO) — based on direct instruction from Ed Broyhill**

---

## PHILOSOPHY

Every donor matters equally — the $100 donor today is the $25,000 donor in 10 years. No shortcuts on small donors. No tiers of effort. The matching quality is the same for everyone.

Major donors (high frequency, high dollar) are the HARDEST to match because they have the most name variations, file from business addresses, and change employers over 11 years. The pipeline must solve the hardest cases, not just the easy ones.

---

## PRE-PROCESSING: REVERSE CHRONOLOGICAL SORT

**Process 2026 → 2015, not 2015 → 2026.**

Rationale: The 2026 donor record has the best chance of matching the current voter file. The donor is most likely alive, at the same address, still registered. Older records match against a future voter file where the person may be dead, moved, divorced, or re-registered.

Once a donor is matched from a 2026 transaction, their 2018 transaction under a different name/address inherits that match. The newer anchors the older.

---

## STAGE 1: INTERNAL DEDUP (donor file against itself)

Before matching donors to the voter file, cluster the donor file against itself across all 11 years. Goal: collapse multiple transaction rows into unique donor persons.

### Stage 1A — Exact match clustering
Group transactions that share:
- **Exact last name + exact first name + exact zip5**
These are the same person filing consistently. Merge into one cluster.

### Stage 1B — Employer cluster
Group transactions by:
- **Last name + normalized employer + city**
Use `employer_sic_master` (62,100 mappings) for normalization. This catches:
- ED BROYHILL / ANVIL VENTURE GROUP / WINSTON-SALEM
- JAMES EDGAR BROYHILL / ANVIL VENTURES / WINSTON SALEM
- ED BROYHILL / ANVIL MANAGEMENT LLC / WINSTON-SALEM
All cluster together because ANVIL* normalizes to one employer in the same city.

### Stage 1C — Committee loyalty fingerprint
Group transactions by:
- **Last name + zip5 + committee_id pattern**
If BILL SMITH at 27104 gives to the same 3+ committees across multiple years, that's one person. No one else with that name in that zip has the same committee fingerprint.

### Stage 1D — Address number collection
For each cluster, collect ALL address numbers from BOTH Street Line 1 AND Street Line 2 across all transactions. These are not just house numbers — they include:
- House numbers (525)
- PO Box numbers (1247)
- Highway numbers (421)
- Suite numbers (300)
- Floor numbers (12)
- Rural route numbers (3)
Any numeric value from any address field.

### Stage 1E — Name variant collection
For each cluster, collect ALL first name variants used across all transactions.
**Do NOT use nickname lookup tables.** The actual filing names ARE the name variants.
Example: POPE + VARIETY WHOLESALERS + RALEIGH → {ART, ARTHUR, JAMES, JAMES A., JAMES ARTHUR, JAMES ART}

### Stage 1F — Employer history collection
For each cluster, collect ALL employers across all 11 years. This solves the RETIRED problem:
- 2016: CEO / ANVIL VENTURES (active career)
- 2024: RETIRED / RETIRED (now retired)
Both map to the same cluster. The career-era employer is preserved for SIC/NAICS segmentation even after retirement.

### Stage 1G — Multi-address / Second home collection
For each cluster, collect ALL complete addresses (not just numbers) across all transactions.
Donors may file from:
- **Primary home** (voter registration address)
- **Business/office** (75% of major donors)
- **Second home** — beach (Wrightsville, Figure Eight, Bald Head), mountains (Blowing Rock, Banner Elk, Highlands), lake houses
- **Florida second home** — common for wealthy NC donors wintering in FL
- **PO Boxes**
- **Vacation properties**

Store ALL addresses as a multi-value field. Never discard a non-primary address.
These are politically valuable:
- Mountain home in Avery County = donor can be activated for Avery district candidates
- Beach home in New Hanover = donor can be activated for coastal candidates
- Florida address = may indicate permanent move (check voter status) or seasonal residence

A donor with homes in 3 NC counties is a resource for candidates in ALL 3 districts.

### OUTPUT of Stage 1:
Each unique donor cluster has:
- All name variants (first names used)
- All address numbers (from any address field)
- **All complete addresses** (primary, business, second homes, PO boxes — never discard any)
- All employers (across 11 years)
- All cities
- All zip codes
- Committee fingerprint
- Total transactions and total dollars
- First and last donation dates
- Donation year range

---

## STAGE 2: MATCH CLUSTERS TO VOTER FILE (DataTrust 252-column)

Process in this pass order. Each pass uses the DataTrust voter file as the target. Once a cluster matches, it is removed from subsequent passes.

### Pass 1 — DOB + Sex + Last Name + Zip
**Top select. Run this first.**
- Donor cluster last name + zip5 → filter DataTrust voters
- Match DOB year (if available from Acxiom enrichment or implied by donation timeline)
- Match Sex (inferred from first name or DataTrust)
- If exactly ONE voter matches: **auto-link** (100% confidence)
- If multiple match: carry to next pass with candidates narrowed

### Pass 2 — Any Address Number + Last Name + Zip
- Try EVERY address number collected in Stage 1D against DataTrust `RegHouseNum`
- Match: last name + any donor address number = DataTrust RegHouseNum + same zip
- ANY address number matching (home, office, PO box) counts
- Single match: **auto-link** (97% confidence)

### Pass 3 — Normalized Employer + Last Name + City
- Use employer_sic_master to normalize donor employer
- Match: last name + normalized employer + city against DataTrust last name + city
- This catches major donors who file from business addresses (75% of wealthy donors)
- Use SIC/NAICS code as additional confirmation
- Single match: **auto-link** (94% confidence)

### Pass 4 — FEC + NCBOE Cross-Reference
- If the same person appears in BOTH FEC and NCBOE filings (two government sources)
- Cross-reference name + city across both sources
- Two independent government records agreeing = **auto-link** (98% confidence)

### Pass 5 — Committee Loyalty Fingerprint
- Donor who gives to same candidate/committee 3+ times across years
- Last name + zip + committee pattern → unique identity
- Match against DataTrust by last name + zip
- **Auto-link** (96% confidence)

### Pass 6 — Name Variants from Cluster + Last Name + City
- Use ALL first name variants collected in Stage 1E
- Try EACH variant against DataTrust first name + last name + city
- No nickname lookup table — only actual names from donation history
- Single match: **auto-link** (90% confidence)

### Pass 7 — Geocode Proximity
- If donor address geocodes to lat/long within 100 meters of a DataTrust voter
- Last name match + geocode proximity = same household
- DataTrust provides `RegLatitude` + `RegLongitude`
- **Auto-link** (95% confidence)

### Pass 8 — Household Matching
- DataTrust `HouseholdID` groups people at the same address
- If one household member is already matched, check other household members for the remaining donor clusters
- Catches spouses, adult children at same address
- Use suffix (Jr., Sr., III) to distinguish family members within household

---

## STAGE 3: UNMATCHED DONORS (Track 2)

28-41% of donors across 11 years will NOT match the current voter file. Reasons:
- **Deceased** — donated in 2016, died in 2022
- **Moved out of state** — donated from NC, now lives in Florida
- **Divorced + name change** — was JANE SMITH, now JANE JOHNSON
- **Address expired** — moved within NC, re-registered at new address
- **Young donor** — donated at 17-18, not yet in voter file at time of donation

### NEVER DROP UNMATCHED DONORS.

### Track 2 Processing:
1. Flag as UNMATCHED with reason code (DECEASED_LIKELY, MOVED_LIKELY, NAME_CHANGE_LIKELY, UNKNOWN)
2. Score on donation history alone (total dollars, frequency, recency, committee breadth)
3. Assign SIC/NAICS from employer history
4. Store ALL collected attributes (name variants, addresses, employers)
5. Flag for manual review if total_contributed > $1,000
6. Check DataTrust `ChangeOfAddress` and `PreviousState` for moved donors
7. Check DataTrust `VoterStatus` = 'Removed' or 'Inactive' for potentially deceased

### Deceased Donor Handling:
A deceased major donor's **spouse** is still alive, still at the same address, still capable of giving. The deceased record should link to the household. The spouse inherits the cultivation relationship.

---

## STAGE 4: ENRICHMENT

After matching, every matched donor gets:
- DataTrust 252 columns (demographics, districts, parsed address, modeled scores, voting history)
- Acxiom behavioral scores (activism propensity, fundraising likelihood, ideology, consumer behavior)
- SIC/NAICS codes from ALL employers across 11 years (multiple microsegments per person)
- Household composition and household total donations
- Volunteer propensity scores

---

## STAGE 5: HONORIFIC ASSIGNMENT

After enrichment, assign correct title for every donor. Priority order:
1. President / Vice President
2. Governor / U.S. Senator / U.S. Representative
3. General officer (all stars addressed as "General")
4. Colonel and below (lifetime)
5. Judge (lifetime — including retired)
6. Tribal Chief / Principal Chief / Tribal Chairman
7. State Senator / State Representative
8. Mayor / Sheriff / DA / Commissioner
9. Party officer (Chairman, Committeeman, Vice Chair)
10. Reverend / Pastor / Bishop / Chaplain / Deacon / Rabbi
11. Dr. (MD, PhD, JD — use if no political/military/clergy title)
12. Military ranks: Lt. General, Major General, Brigadier General → all "General"; Colonel, Major, Captain, etc.
13. Mrs. / Ms. / Miss — Mrs. if married status confirmed, Ms. if unknown, Miss only if explicitly preferred
14. Mr. — ONLY if no other title applies

**RULES:**
- Titles are for LIFE — former Senator is always Senator, former Judge is always Judge
- Never address titled person as Mr./Mrs./Ms.
- Never use first name or nickname in formal correspondence (not "Dear Jimmy" for Governor James Green)
- Military title outranks civilian title (retired Colonel who is a Commissioner = Colonel)
- Clergy title used in community correspondence, political title in political correspondence

---

## STAGE 6: MICROSEGMENTATION TAGGING

Every donor gets tagged into ALL applicable microsegments based on employer history:
- SIC codes from every employer across 11 years
- NAICS subdivisions for deeper targeting
- One donor can appear in multiple segments (real estate + venture capital + asset management)

Use cases:
- All bankers in Mecklenburg County → Banking Committee fundraiser
- All teachers statewide → Superintendent of Education campaign
- All lawyers by county → Supreme Court candidate outreach
- All builders → Building Codes Committee chairman event
- All veterans / active military → Armed Services congressman meet-and-greet
- All physicians → health policy roundtable
- All farmers → Agriculture Commissioner event
- Employees of same company → company-specific networking event

---

## STAGE 7: HOUSEHOLD AGGREGATION

After individual matching:
- Group matched donors by DataTrust `HouseholdID`
- Tag spouse relationships using suffix (Jr./Sr.) and household membership
- Compute household total donations (sum of all household members)
- Create household profile alongside individual profiles
- Each donor gets their own profile page (like a Facebook page for the candidate to see)
- Household profile shows combined giving and all family members

---

## CRITICAL RULES (NON-NEGOTIABLE)

1. **Process 2026 → 2015** (reverse chronological)
2. **Internal dedup first** (cluster donor file against itself before matching to voter file)
3. **DOB + Sex is top filter** before name/address matching
4. **No nickname lookup tables** — use actual name variants from donation history
5. **Address numbers from BOTH address lines** — house, PO box, highway, suite, floor, rural route
6. **Employer is the bridge for major donors** — 75% file from business address, not home
7. **Collect all employers across 11 years** — solves RETIRED problem
8. **Committee loyalty fingerprint** — repeat giving to same committee = identity proof
9. **Never drop unmatched donors** — score on history, flag for manual review
10. **Every donor matters equally** — $100 today is $25,000 in 10 years
11. **Low-dollar donors are volunteer prospects** — match effort is the same
12. **ED maps to EDGAR, never EDWARD**
13. **Deceased donor → link to surviving spouse**
14. **Suffix (Jr., Sr., III) distinguishes family members** in same household
15. **Title/honorific is mandatory** on every outbound communication
16. **Multiple SIC codes per donor** — one person, many microsegments

---

*This pipeline was designed through direct conversation with Ed Broyhill on April 10, 2026.*
*Every rule in this document comes from his lived experience as NC National Committeeman.*
*Do not modify without Ed's authorization.*
