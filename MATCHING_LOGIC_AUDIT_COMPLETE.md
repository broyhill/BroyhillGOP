# MATCHING LOGIC AUDIT - COMPLETE DATA MAP

## WHAT THIS DOCUMENT IS

A complete audit of every donor field, every candidate field, and whether matching logic exists to connect them.

**Sources Audited:**
- 02_donors.sql (200+ fields)
- 01_candidates.sql (200+ fields)
- 06_donor_match_functions.sql (current matching logic)

---

## SUMMARY

| Category | Total Fields | Used in Matching | NOT Used | Gap % |
|----------|-------------|------------------|----------|-------|
| Donor Demographics | 25 | 0 | 25 | **100%** |
| Donor Voter Data | 20 | 0 | 20 | **100%** |
| Donor Giving - Candidates | 30 | 8 | 22 | 73% |
| Donor Giving - Orgs | 25 | 6 | 19 | 76% |
| Donor Issues | 45 | 15 | 30 | 67% |
| Donor Factions | 10 | 1 | 9 | 90% |
| Donor Engagement | 20 | 0 | 20 | **100%** |
| Candidate Appeal Scores | 25 | 0 | 25 | **100%** |
| Candidate Demographics | 20 | 1 | 19 | 95% |

**MASSIVE GAPS: Demographics, Voter Data, Engagement, and Candidate Appeal Scores are 100% unused.**

---

## DONOR FIELDS - USED IN MATCHING ✅

These fields ARE currently connected to matching logic:

### Geographic (4 fields)
```
donor.county                    → calculate_donor_geographic_match()
donor.congressional_district    → calculate_donor_geographic_match()
donor.nc_senate_district        → calculate_donor_geographic_match()
donor.nc_house_district         → calculate_donor_geographic_match()
```

### Issue Intensities (15 fields)
```
donor.issue_2a_intensity        → calculate_donor_issue_match()
donor.issue_abortion_intensity  → calculate_donor_issue_match()
donor.issue_crt_intensity       → calculate_donor_issue_match()
donor.issue_election_intensity  → calculate_donor_issue_match()
donor.issue_border_intensity    → calculate_donor_issue_match()
donor.issue_taxes_intensity     → calculate_donor_issue_match()
donor.issue_spending_intensity  → calculate_donor_issue_match()
donor.issue_crime_intensity     → calculate_donor_issue_match()
donor.issue_religion_intensity  → calculate_donor_issue_match()
donor.issue_parental_intensity  → calculate_donor_issue_match()
donor.issue_school_choice_intensity → calculate_donor_issue_match()
donor.issue_energy_intensity    → calculate_donor_issue_match()
donor.issue_healthcare_intensity → calculate_donor_issue_match()
donor.issue_veterans_intensity  → calculate_donor_issue_match()
donor.issue_agriculture_intensity → calculate_donor_issue_match()
```

### Org Giving (6 fields)
```
donor.giving_nra_lifetime       → calculate_donor_endorsement_match()
donor.giving_nrlc_lifetime      → calculate_donor_endorsement_match()
donor.giving_sba_list_lifetime  → calculate_donor_endorsement_match()
donor.giving_club_growth_lifetime → calculate_donor_endorsement_match()
donor.giving_afp_lifetime       → calculate_donor_endorsement_match()
donor.giving_heritage_lifetime  → calculate_donor_endorsement_match()
```

### Giving History (8 fields)
```
donor.giving_candidate_lifetime → calculate_amount_grade()
donor.giving_org_lifetime       → calculate_capacity_flag()
donor.giving_federal_count      → calculate_history_score()
donor.giving_state_count        → calculate_history_score()
donor.giving_local_count        → calculate_history_score()
donor.giving_multi_level        → calculate_history_score()
donor.giving_multi_cycle        → calculate_history_score()
donor.giving_last_date          → calculate_recency_score()
```

### Faction (1 field)
```
donor.faction_trump_maga        → calculate_donor_faction_match()
```

---

## DONOR FIELDS - NOT USED IN MATCHING ❌

### Demographics (25 fields) - 100% UNUSED

| Field | Data Source | Potential Match To |
|-------|-------------|-------------------|
| `gender` | Datatrust/NCSBE | candidate.appeal_women, appeal_men |
| `birth_year` | Datatrust | candidate.appeal_seniors, appeal_youth |
| `age` | Calculated | candidate.appeal_* by age |
| `age_range` | Datatrust | candidate.appeal_* by age |
| `marital_status` | Datatrust | candidate.marital_status |
| `household_size` | Datatrust | candidate.appeal_parents |
| `children_present` | Datatrust | candidate.appeal_parents |
| `homeowner` | Datatrust | candidate.appeal_* wealth |
| `home_value_range` | Datatrust | capacity indicators |
| `education_level` | Apollo/BetterContact | candidate.education_level |
| **`occupation`** | **Apollo/LinkedIn** | **candidate.office_type (ATTORNEYS→JUDGES)** |
| **`employer`** | **Apollo/LinkedIn** | **industry matching** |
| **`industry`** | **Apollo/LinkedIn** | **candidate.industry** |
| **`job_title`** | **Apollo/LinkedIn** | **professional affinity** |
| `employment_status` | Apollo | candidate.appeal_retirees |
| `income_range` | Datatrust | capacity/ask amount |
| `net_worth_range` | Datatrust | capacity/ask amount |
| `wealth_tier` | Calculated | priority tier |
| **`religion`** | **Datatrust** | **candidate.church_affiliation (GREEK ORTHODOX→GREEK)** |
| `church_attendance` | Datatrust | candidate.appeal_evangelicals |
| **`veteran`** | **Datatrust/Apollo** | **candidate.military_service (GREEN BERET→GREEN BERET)** |
| **`military_branch`** | **Datatrust/Apollo** | **candidate.military_branch** |
| `gun_owner` | Datatrust | candidate.issue_2a_intensity |
| `hunter` | Datatrust | candidate.appeal_hunters |

### Voter Data (20 fields) - 100% UNUSED

| Field | Data Source | Potential Match To |
|-------|-------------|-------------------|
| `voter_status` | NCSBE | targeting priority |
| `party_registration` | NCSBE | R primary voters = higher priority |
| `vote_2024_general` | NCSBE | engagement level |
| `vote_2024_primary` | NCSBE | **R primary voter = activist** |
| `vote_2022_general` | NCSBE | consistency |
| `vote_2020_general` | NCSBE | consistency |
| `r_primary_voter` | Calculated | **activist indicator** |
| `voter_score` | Calculated | targeting priority |
| `general_vote_frequency` | Calculated | engagement |
| `primary_vote_frequency` | Calculated | engagement |

### Giving History - Not Used (22 fields)

| Field | Data Source | Potential Match To |
|-------|-------------|-------------------|
| `giving_candidate_ytd` | FEC/NCSBE | current cycle priority |
| `giving_federal_lifetime` | FEC | candidate.office_type = Federal |
| `giving_state_lifetime` | NCSBE | candidate.office_type = State |
| `giving_local_lifetime` | NCSBE | candidate.office_type = Local |
| `giving_avg_donation` | Calculated | optimal ask amount |
| `giving_max_donation` | Calculated | capacity indicator |
| `giving_first_date` | FEC/NCSBE | donor lifecycle |
| `giving_frequency` | Calculated | intensity score |
| `giving_ncgop_lifetime` | FEC | party loyalty |
| `giving_rnc_lifetime` | FEC | party loyalty |
| `giving_pac_total` | FEC | capacity indicator |
| `giving_pac_list` | FEC | **PAC affinity matching** |

### Engagement (20 fields) - 100% UNUSED

| Field | Data Source | Potential Match To |
|-------|-------------|-------------------|
| `engagement_email_opens` | Internal | response probability |
| `engagement_email_open_rate` | Calculated | channel preference |
| `engagement_events_attended` | Internal | activist level |
| `engagement_volunteered` | Internal | activist flag |
| `engagement_volunteer_hours` | Internal | activist level |
| `engagement_score` | Calculated | **priority tier** |
| `engagement_level` | Calculated | targeting |
| `engagement_petition_signer` | Internal | activist indicator |
| `engagement_survey_responder` | Internal | responsive donor |

### Factions - Underused (9 of 10 unused)

| Field | Data Source | Potential Match To |
|-------|-------------|-------------------|
| `faction_tea_party` | Inferred | candidate.faction_tea_party |
| `faction_establishment` | Inferred | candidate.faction_establishment |
| `faction_libertarian` | Inferred | candidate.faction_libertarian |
| `faction_moderate` | Inferred | candidate.faction_moderate |
| `faction_religious_right` | Inferred | candidate.faction_religious_right |
| `faction_primary` | Calculated | candidate.faction_primary |
| `faction_secondary` | Calculated | candidate.faction_secondary |

---

## CANDIDATE FIELDS - NOT USED IN MATCHING ❌

### Appeal Scores (25 fields) - 100% UNUSED

These are DESIGNED to match donors but NO LOGIC EXISTS:

| Candidate Field | Should Match Donor Field |
|-----------------|-------------------------|
| `appeal_rural` | donor in rural county |
| `appeal_suburban` | donor in suburban county |
| `appeal_urban` | donor in urban county |
| `appeal_seniors` | donor.age_range = '65+' |
| `appeal_middle_age` | donor.age_range = '45-64' |
| `appeal_young_adults` | donor.age_range = '25-44' |
| `appeal_youth` | donor.age_range = '18-24' |
| `appeal_veterans` | donor.veteran = true |
| `appeal_military_families` | donor.military_branch IS NOT NULL |
| `appeal_small_business` | donor.occupation LIKE '%owner%' |
| `appeal_farmers` | donor.industry = 'Agriculture' |
| `appeal_evangelicals` | donor.church_attendance = 'Weekly' |
| `appeal_catholics` | donor.religion = 'Catholic' |
| `appeal_women` | donor.gender = 'Female' |
| `appeal_men` | donor.gender = 'Male' |
| `appeal_parents` | donor.children_present = true |
| `appeal_retirees` | donor.employment_status = 'Retired' |
| `appeal_gun_owners` | donor.gun_owner = true |
| `appeal_hunters` | donor.hunter = true |
| `appeal_first_responders` | donor.occupation LIKE '%police%' etc |
| `appeal_blue_collar` | donor.occupation classification |
| `appeal_white_collar` | donor.occupation classification |
| `appeal_professionals` | donor.job_title classification |
| `appeal_entrepreneurs` | donor.business_owner = true |

### Candidate Demographics (19 unused)

| Candidate Field | Should Match Donor Field |
|-----------------|-------------------------|
| `occupation` | donor.occupation |
| `industry` | donor.industry |
| `military_service` | donor.veteran |
| `military_branch` | donor.military_branch |
| `church_affiliation` | donor.religion |
| `education_school` | donor.education (alumni match) |
| `years_in_district` | donor.length_of_residence |

---

## KNOWN HIGH-VALUE PATTERNS NOT IMPLEMENTED

### Pattern 1: Occupation → Office Type
```
IF donor.occupation LIKE '%attorney%' OR '%lawyer%'
   AND candidate.office_type IN ('Judge', 'District Attorney', 'Superior Court')
THEN match_score += 30
```
**Source:** Your experience - trial attorneys donate to justice races

### Pattern 2: Same Occupation Match
```
IF donor.occupation = candidate.occupation
THEN match_score += 20
```
**Example:** CPA running for office matches CPA donors

### Pattern 3: Veteran → Veteran
```
IF donor.veteran = true AND donor.military_branch = candidate.military_branch
THEN match_score += 40
```
**Example:** Green Beret donor matches Green Beret candidate

### Pattern 4: Religion/Ethnicity Match
```
IF donor.religion = 'Greek Orthodox' AND candidate.religion = 'Greek Orthodox'
THEN match_score += 40
```
**Source:** Your experience - Greek donors support Greek candidates

### Pattern 5: Alumni Match
```
IF donor.education_school = candidate.education_school
THEN match_score += 15
```
**Example:** Duke alumni support Duke alumni candidates

### Pattern 6: Historical Office Type Affinity
```
IF donor gave to ANY judge in past 5 years
   AND candidate.office_type = 'Judge'
THEN match_score += 25
```
**Pattern:** Past behavior predicts future behavior

### Pattern 7: Business Owner → Business-Friendly
```
IF donor.business_owner = true
   AND candidate.appeal_entrepreneurs >= 70
THEN match_score += 20
```

### Pattern 8: Parent → Education Issues
```
IF donor.children_present = true
   AND (candidate.issue_school_choice_intensity >= 4 
        OR candidate.issue_parental_intensity >= 4)
THEN match_score += 15
```

---

## DATA SOURCES FEEDING THESE FIELDS

| Source | Fields Populated | Used in Matching? |
|--------|-----------------|-------------------|
| **FEC API** | giving_*, candidate history | Partial |
| **NC SBOE** | voter_*, party_registration, vote history | **NO** |
| **Datatrust/L2** | demographics, household, wealth | **NO** |
| **Apollo** | occupation, employer, job_title, linkedin | **NO** |
| **BetterContact** | email/phone verification | N/A |
| **LinkedIn Scrape** | occupation, company, education | **NO** |
| **Facebook Scrape** | interests, groups, location | **NO** |
| **AI Search Agents** | enrichment, news, updates | **NO** |
| **Internal CRM** | engagement_*, events, volunteer | **NO** |
| **Questionnaires** | issue intensity, preferences | Partial |

---

## WHAT NEEDS TO BE BUILT

### Priority 1: Occupation/Office Affinity Match
```sql
CREATE FUNCTION calculate_donor_occupation_match(candidate_id, donor_id)
```
- Attorney → Judge/DA
- CPA/Accountant → Treasurer
- Teacher → School Board
- Farmer → Agriculture Commissioner
- Business Owner → Business-friendly candidates

### Priority 2: Demographic Appeal Match
```sql
CREATE FUNCTION calculate_donor_demographic_match(candidate_id, donor_id)
```
Uses candidate.appeal_* scores against donor demographics

### Priority 3: Veteran/Military Match
```sql
CREATE FUNCTION calculate_donor_military_match(candidate_id, donor_id)
```
- Same branch = high match
- Any veteran to veteran = moderate match

### Priority 4: Religion/Community Match
```sql
CREATE FUNCTION calculate_donor_community_match(candidate_id, donor_id)
```
- Same religion
- Same church
- Same civic groups

### Priority 5: Historical Office Type Affinity
```sql
CREATE FUNCTION calculate_donor_office_history_match(candidate_id, donor_id)
```
Analyze donor's past giving to similar office types

### Priority 6: Engagement Score Integration
```sql
-- Modify priority tier calculation
IF donor.engagement_score >= 80 THEN tier_boost := 1
```

---

## ML OPPORTUNITY

With 200+ donor fields and 200+ candidate fields, machine learning can:

1. **Discover Hidden Patterns** - What combinations predict donations?
2. **Weight Optimization** - Which of the 400+ attributes actually matter?
3. **Clustering** - Group similar donors and similar candidates
4. **Collaborative Filtering** - "Donors who gave to X also gave to Y"

**Training Data Available:**
- 136,000+ donors
- Historical donation records (who gave to whom)
- Candidate attributes from questionnaires
- Outcome data (donation amounts, response rates)

---

## WHEN NEW DATA UPLOADS

### Current Process (what happens):
1. CSV uploaded to Supabase
2. import_datahub_complete.py runs
3. donor record created/updated
4. **NOTHING ELSE** - no re-matching, no re-scoring

### What SHOULD Happen:
1. CSV uploaded
2. Import runs
3. **Trigger:** `donor.created` or `donor.updated` event
4. **For each candidate:** Recalculate match score for this donor
5. **If match >= threshold:** Add/update in candidate_donor_universe
6. **Calculate:** Grade, composite score, priority tier
7. **Flag:** New prospect, cultivation opportunity, etc.

### Event-Driven Architecture Needed:
```
NEW_DONOR_EVENT
    → FOR EACH active_candidate
        → calculate_all_match_scores()
        → IF match >= 50
            → INSERT/UPDATE candidate_donor_universe
            → publish('donor.matched', {candidate_id, donor_id, score})
```

---

## CONCLUSION

**The matching logic uses less than 20% of available data.**

200+ donor fields exist. 200+ candidate fields exist. But only ~35 fields are connected in matching logic.

The biggest gaps:
1. **Demographics** (100% unused)
2. **Occupation/Employer** (100% unused) 
3. **Voter Data** (100% unused)
4. **Engagement** (100% unused)
5. **Candidate Appeal Scores** (100% unused)

These gaps mean:
- Attorney donors don't auto-match to judicial candidates
- Veteran donors don't auto-match to veteran candidates
- Greek Orthodox donors don't auto-match to Greek candidates
- High-engagement donors don't get priority
- Past giving patterns don't predict future matches

**This is why ML is needed** - to find the correlations humans can't see across 400+ attributes.
