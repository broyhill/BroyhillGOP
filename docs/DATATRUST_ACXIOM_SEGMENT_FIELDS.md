# DataTrust + Acxiom Fields That Power Microsegment Sizing
## BroyhillGOP — Replace estimates with exact counts
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## WHAT WE HAVE IN nc_datatrust (7.65M NC voters — 251 columns confirmed)

---

## DIRECTLY USABLE FIELDS FOR EACH MICROSEGMENT

### SEGMENT: HUNTERS / SPORTSMEN
**DataTrust field:** `coalitionid_sportsmen`
- This IS the field. DataTrust has already identified sportsmen.
- Query: `WHERE coalitionid_sportsmen IS NOT NULL AND coalitionid_sportsmen != ''`
- Also: `coalitionid_2ndamendment` — gun owners overlap heavily

```sql
SELECT COUNT(*) as sportsmen_voters,
    COUNT(CASE WHEN registeredparty = 'REP' THEN 1 END) as r_sportsmen,
    COUNT(CASE WHEN registeredparty IN ('UNA','UNR','NPA') THEN 1 END) as una_sportsmen
FROM public.nc_datatrust
WHERE coalitionid_sportsmen IS NOT NULL AND coalitionid_sportsmen != '';
```

### SEGMENT: VETERANS
**DataTrust field:** `coalitionid_veteran`
- Direct veteran flag from DataTrust
- Query: `WHERE coalitionid_veteran IS NOT NULL AND coalitionid_veteran != ''`

```sql
SELECT COUNT(*) as veteran_voters
FROM public.nc_datatrust
WHERE coalitionid_veteran IS NOT NULL AND coalitionid_veteran != '';
```

### SEGMENT: SECOND AMENDMENT / GUN OWNERS
**DataTrust field:** `coalitionid_2ndamendment`
- Direct 2A flag
- Query: `WHERE coalitionid_2ndamendment IS NOT NULL`

### SEGMENT: PRO-LIFE
**DataTrust field:** `coalitionid_prolife`
- Direct pro-life flag
- Also: `coalitionid_prochoice` (opposition — know your enemy)

### SEGMENT: SOCIAL CONSERVATIVES
**DataTrust field:** `coalitionid_socialconservative`
- Covers: religious right, family values, traditional marriage voters

### SEGMENT: FISCAL CONSERVATIVES
**DataTrust field:** `coalitionid_fiscalconservative`
- Small government, low tax, anti-spending voters

### SEGMENT: SENIORS
**DataTrust fields:** `age`, `agerange`, `birthyear`
```sql
SELECT COUNT(*) as seniors_65plus
FROM public.nc_datatrust
WHERE age >= 65 AND registeredparty IN ('REP','UNA','UNR','NPA');
```

### SEGMENT: WOMEN (for Soccer Moms, Women for Broyhill)
**DataTrust field:** `sex` — 'F' / 'M'
```sql
SELECT COUNT(*) as republican_women_30_55
FROM public.nc_datatrust
WHERE sex = 'F'
AND age BETWEEN 30 AND 55
AND registeredparty IN ('REP','UNA','UNR','NPA');
```

### SEGMENT: RELIGION / FAITH
**DataTrust field:** `religionmodeled`
- Acxiom-modeled religion — Catholic, Baptist, Protestant, Evangelical, etc.
- Query: `WHERE religionmodeled IN ('Baptist','Evangelical','Pentecostal','Protestant')`

### SEGMENT: INCOME / DONORS
**DataTrust field:** `householdincomemodeled`
- Acxiom-modeled household income
- High-income = higher donor propensity
```sql
-- Identify high-income R+UNA voters not yet in donor spine
SELECT COUNT(*) as high_income_untapped
FROM public.nc_datatrust dt
LEFT JOIN core.person_spine ps ON ps.voter_rncid = dt.rnc_regid::text
WHERE dt.householdincomemodeled IN ('$150,000-$200,000','$200,000+','$100,000-$150,000')
AND dt.registeredparty IN ('REP','UNA')
AND ps.person_id IS NULL  -- not yet in our donor spine
AND dt.donorflag = '1';   -- DataTrust knows they donate to SOMETHING
```

### SEGMENT: DONOR FLAG
**DataTrust field:** `donorflag`
- DataTrust marks known donors (charitable OR political)
- Direct indicator of giving capacity

### SEGMENT: EDUCATION (for Biotech/Professional segments)
**DataTrust fields:** `educationmodeled`, `acseducation_college`, `acseducation_graduate`
```sql
SELECT COUNT(*) as college_educated_r
FROM public.nc_datatrust
WHERE (educationmodeled ILIKE '%college%' OR educationmodeled ILIKE '%graduate%'
       OR acseducation_college > 0.5 OR acseducation_graduate > 0.5)
AND registeredparty IN ('REP','UNA');
```

### SEGMENT: ETHNICITY (for Hispanic R, Black R groups)
**DataTrust fields:** `ethnicitymodeled`, `ethnicityreported`, `ethnicgroupmodeled`,
`acsethnicity_hispanic`, `acsethnicity_black`, `acsethnicity_white`, `acsethnicity_asian`

### SEGMENT: MILITARY COMMUNITY
**DataTrust fields:** `coalitionid_veteran` + `mediamarket` (Fayetteville, Jacksonville)
```sql
SELECT COUNT(*) from nc_datatrust
WHERE (coalitionid_veteran IS NOT NULL
   OR mediamarket IN ('FAYETTEVILLE','JACKSONVILLE','GOLDSBORO'))
AND registeredparty IN ('REP','UNA');
```

### SEGMENT: VOTER TURNOUT / RELIABILITY
**DataTrust fields:** `voterfrequencygeneral`, `voterfrequencyprimary`,
`voterregularitygeneral`, `voterregularityprimary`, `turnoutgeneralscore`
`vh06g` through `vh26g` — vote history every election 2006-2026

```sql
-- Super-voters: voted in 5+ of last 5 generals (2016-2024)
SELECT COUNT(*) as super_voters_r
FROM public.nc_datatrust
WHERE registeredparty IN ('REP','UNA')
AND vh16g = '1' AND vh18g = '1' AND vh20g = '1' AND vh22g = '1' AND vh24g = '1';
```

### SEGMENT: REPUBLICAN SCORES
**DataTrust fields:** `republicanpartyscore`, `republicanballotscore`,
`per24pres_gop`, `modeledparty`, `calcparty`

```sql
-- High-propensity R voters not yet registered R (persuasion targets)
SELECT COUNT(*) as r_leaning_una
FROM public.nc_datatrust
WHERE registeredparty IN ('UNA','UNR','NPA')
AND republicanpartyscore >= 70  -- modeled to be 70%+ Republican
AND republicanballotscore >= 65;
```

### SEGMENT: GEOGRAPHY (district-level)
**DataTrust fields:**
- `stateleglowerdistrict` — NC House district
- `statelegupperdistrict` — NC Senate district
- `congressionaldistrict` — US House district
- `countyname` — county
- `schoolboard` — school board district
- `schooldistrict` — school district
- `citycouncil` — city council district
- `countycommissioner` — county commissioner district
- `ward` — municipal ward
- `precinctcode` / `precinctname` — precinct level
- `reglatitude` / `reglongitude` — exact geocoded address

**This means person_district_map can be built DIRECTLY from DataTrust
without any additional geographic join — all districts are already on the record.**

### SEGMENT: CONTACT INFORMATION
**DataTrust fields (Acxiom + Neustar appended):**
- `cell` — cell phone (primary contact)
- `cellneustar`, `celldataaxle` — vendor-sourced cell
- `landline` — home phone
- `landlineneustar`, `landlinedataaxle` — vendor-sourced landline
- `cellftcdonotcall` — do not call flag
- `landlineftcdonotcall` — do not call flag

---

## ACXIOM-SPECIFIC DATA IN DATATRUST

DataTrust overlays Acxiom consumer data on every voter. Key fields:

| Field | What Acxiom tells us | Microsegment use |
|-------|---------------------|-----------------|
| `householdincomemodeled` | Income bracket | Donor capacity scoring |
| `educationmodeled` | Education level | Professional segment identification |
| `religionmodeled` | Modeled religion | Faith segment, GOTV targeting |
| `ethnicitymodeled` | Modeled ethnicity | Demographic coalition building |
| `languagemodeled` | Primary language | Spanish outreach |
| `acseducation_*` | Census education tract data | Professional density by area |
| `acsethnicity_*` | Census ethnicity tract data | Demographic density by area |
| `donorflag` | Known donor (any cause) | High-propensity donor identification |
| `householdid` | Household grouping | Household-level targeting |
| `householdparty` | Household political lean | Household-level R identification |

---

## EXACT COUNTS — RUN THESE QUERIES

Replace all estimates with exact numbers from DataTrust:

```sql
-- Master segment count query — run once, update MICROSEGMENT_SIZE_ESTIMATES
SELECT
    'Total R+UNA voters' as segment,
    COUNT(*) as total
FROM public.nc_datatrust
WHERE registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Sportsmen (coalitionid)',
    COUNT(*) FROM public.nc_datatrust
    WHERE coalitionid_sportsmen IS NOT NULL AND coalitionid_sportsmen != ''
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Veterans (coalitionid)',
    COUNT(*) FROM public.nc_datatrust
    WHERE coalitionid_veteran IS NOT NULL AND coalitionid_veteran != ''
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT '2nd Amendment (coalitionid)',
    COUNT(*) FROM public.nc_datatrust
    WHERE coalitionid_2ndamendment IS NOT NULL AND coalitionid_2ndamendment != ''
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Pro-Life (coalitionid)',
    COUNT(*) FROM public.nc_datatrust
    WHERE coalitionid_prolife IS NOT NULL AND coalitionid_prolife != ''
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Social Conservative (coalitionid)',
    COUNT(*) FROM public.nc_datatrust
    WHERE coalitionid_socialconservative IS NOT NULL AND coalitionid_socialconservative != ''
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Fiscal Conservative (coalitionid)',
    COUNT(*) FROM public.nc_datatrust
    WHERE coalitionid_fiscalconservative IS NOT NULL AND coalitionid_fiscalconservative != ''
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Seniors 65+ R+UNA',
    COUNT(*) FROM public.nc_datatrust
    WHERE age >= 65
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Women 30-55 R+UNA',
    COUNT(*) FROM public.nc_datatrust
    WHERE sex = 'F' AND age BETWEEN 30 AND 55
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'High income R+UNA (Acxiom modeled)',
    COUNT(*) FROM public.nc_datatrust
    WHERE householdincomemodeled ILIKE '%100,000%'
       OR householdincomemodeled ILIKE '%150,000%'
       OR householdincomemodeled ILIKE '%200,000%'
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Known donors (donorflag)',
    COUNT(*) FROM public.nc_datatrust
    WHERE donorflag = '1'
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'Super voters (5/5 generals 2016-2024)',
    COUNT(*) FROM public.nc_datatrust
    WHERE vh16g = '1' AND vh18g = '1' AND vh20g = '1' AND vh22g = '1' AND vh24g = '1'
    AND registeredparty IN ('REP','UNA','UNR','NPA')

UNION ALL SELECT 'High R-score UNA voters (persuasion)',
    COUNT(*) FROM public.nc_datatrust
    WHERE registeredparty IN ('UNA','UNR','NPA')
    AND republicanpartyscore >= 70

ORDER BY total DESC;
```

---

## THE ACXIOM CONSUMER INTEREST LAYER

Beyond DataTrust's political overlays, Acxiom's consumer data adds:
- **Outdoor/sporting goods purchases** → proxy for hunters/fishermen
- **Farm supply purchases** → proxy for farmers
- **Medical journal subscriptions** → proxy for physicians
- **Religious publication subscriptions** → proxy for faith segment
- **Home ownership + acreage** → property rights interest
- **Vehicle type** (truck vs sedan) → rural/urban proxy
- **Magazine subscriptions** → hunting, fishing, farming, business magazines

These are in the Acxiom consumer database which DataTrust overlays.
The `custom01-custom05` fields in nc_datatrust may hold additional Acxiom flags
that need to be inventoried with Claude.

---

## WHAT THIS MEANS

**We don't need to estimate. We have exact counts.**

- Sportsmen: exact from `coalitionid_sportsmen`
- Veterans: exact from `coalitionid_veteran`
- 2A supporters: exact from `coalitionid_2ndamendment`
- Pro-life: exact from `coalitionid_prolife`
- Seniors: exact from `age >= 65`
- Women 30-55: exact from `sex = 'F' AND age BETWEEN 30 AND 55`
- High income: exact from `householdincomemodeled`
- Known donors: exact from `donorflag = '1'`
- Super voters: exact from `vh16g` through `vh24g` vote history
- District assignments: exact from `stateleglowerdistrict`, `statelegupperdistrict`, `congressionaldistrict`
- Contact info: cell + landline from Neustar + Data Axle append

**Every microsegment estimate in MICROSEGMENT_SIZE_ESTIMATES.md
should be replaced with live DataTrust COUNT(*) queries.**

---

*Prepared by Perplexity AI — March 31, 2026*
*nc_datatrust has 7.65M rows, 251 columns, Acxiom + DataTrust overlaid*
*coalitionid fields are pre-built RNC segment flags — use them directly*
*All estimates become exact counts once queries run against live DB*
