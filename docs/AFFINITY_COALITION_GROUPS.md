# Candidate Affinity Coalition Groups
## BroyhillGOP — "___s for [Candidate]" System
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT
Every candidate gets named affinity groups built from:
1. The district's community identity tags (farmers, hunters, beach communities, etc.)
2. The donor/voter database — who actually lives and votes in that district
3. The issue tags — what issues dominate that geography
4. Occupation/employer/SIC data — what industries are present

Each group gets:
- A name: "Farmers for Broyhill", "Hunters for Smith", "Teachers for Jones"
- A member list (auto-built from spine + voter file)
- Social media presence (Facebook Group, X list, Instagram tag)
- Newsletter segment
- Auto-post content calendar
- Event capability (district-specific rallies, meetups)

---

## MASTER AFFINITY GROUP TEMPLATES

### OCCUPATIONAL / INDUSTRY GROUPS
| Group Name Template | Source data | SIC / employer match |
|--------------------|------------|---------------------|
| Farmers for [Candidate] | employer ILIKE '%farm%' OR SIC 01xx-09xx | Agriculture |
| Doctors for [Candidate] | employer ILIKE '%medical%hospital%clinic%MD%' OR SIC 80xx | Healthcare |
| Nurses for [Candidate] | occupation ILIKE '%nurse%RN%NP%' | Healthcare |
| Veterans for [Candidate] | military_service IS NOT NULL OR employer ILIKE '%veteran%army%navy%marines%air force%' | Military |
| Law Enforcement for [Candidate] | occupation ILIKE '%police%sheriff%officer%deputy%' | Public safety |
| Teachers for [Candidate] | occupation ILIKE '%teacher%educator%principal%' | Education |
| Small Business Owners for [Candidate] | is_self_employed = true OR SIC 52xx-59xx retail | Small business |
| Realtors for [Candidate] | occupation ILIKE '%realtor%real estate%broker%' | Real estate |
| Bankers for [Candidate] | SIC 60xx-62xx | Finance |
| Lawyers for [Candidate] | occupation ILIKE '%attorney%lawyer%counsel%' | Legal |
| Contractors for [Candidate] | SIC 15xx-17xx | Construction |
| Truck Drivers for [Candidate] | SIC 42xx OR occupation ILIKE '%driver%trucker%' | Transportation |
| Firefighters for [Candidate] | occupation ILIKE '%fire%EMS%paramedic%' | Public safety |
| Pastors for [Candidate] | occupation ILIKE '%pastor%minister%reverend%priest%' | Faith |
| Biochemists for [Candidate] | SIC 2836-2837 OR employer ILIKE '%biotech%pharma%research%lab%' | Life sciences |
| Engineers for [Candidate] | occupation ILIKE '%engineer%' | Tech/manufacturing |
| Manufacturing Workers for [Candidate] | SIC 20xx-39xx | Manufacturing |
| Hospitality Workers for [Candidate] | SIC 70xx-79xx | Hospitality |
| Auto Dealers for [Candidate] | SIC 5511-5599 | Auto |

### OUTDOOR / SPORTING GROUPS
| Group Name Template | Source data |
|--------------------|------------|
| Hunters for [Candidate] | donation history to DU/NRA/hunting orgs OR occupation ILIKE '%guide%outfitter%' |
| Fishermen for [Candidate] | donation history to CCA/fishing orgs OR zip code near coast/lake |
| Duck Hunters for [Candidate] | DU membership OR waterfowl committee donations |
| Deer Hunters for [Candidate] | QDMA/deer orgs OR rural county, hunting license proxy |
| Bear Hunters for [Candidate] | NC Bear Hunters Assoc OR western NC geography |
| Boaters for [Candidate] | lake community zip OR marina employer |
| Golfers for [Candidate] | Pinehurst/Moore County zip OR golf industry employer |
| Hikers for [Candidate] | mountain community zip OR outdoor retailer employer |
| Fox Hunters for [Candidate] | NC Fox Hunters Assoc OR rural Piedmont geography |

### FAITH / VALUES GROUPS
| Group Name Template | Source data |
|--------------------|------------|
| Christians for [Candidate] | NC Values Coalition donor OR faith-based employer |
| Catholics for [Candidate] | Diocese geography OR Catholic school employer |
| Baptists for [Candidate] | Baptist church employer OR Warren/Johnston geography |
| Pro-Life Advocates for [Candidate] | SBA Pro-Life donor OR NCVC donor |
| Parents for [Candidate] | has_children = true AND school_board_district match |
| Home School Families for [Candidate] | home_school_tag OR religious freedom donor |

### DEMOGRAPHIC / COMMUNITY GROUPS
| Group Name Template | Source data |
|--------------------|------------|
| Seniors for [Candidate] | age >= 65 |
| Young Republicans for [Candidate] | age 18-35 AND party = R |
| Women for [Candidate] | gender = F AND party = R |
| Veterans for [Candidate] | military_service flag |
| Hispanic Republicans for [Candidate] | ethnicity + party flag |
| Black Republicans for [Candidate] | race + party flag |
| Military Families for [Candidate] | military base community zip |

### GEOGRAPHY / COMMUNITY IDENTITY GROUPS
| Group Name Template | Source data |
|--------------------|------------|
| Coastal Families for [Candidate] | beach community zip |
| Mountain Families for [Candidate] | mountain county zip |
| Farm Families for [Candidate] | rural county + agricultural SIC |
| Lake Norman Residents for [Candidate] | Lake Norman zip codes |
| Pinehurst Residents for [Candidate] | Moore County + golf community |
| Outer Banks Families for [Candidate] | Dare/Currituck coastal zip |
| Research Triangle Professionals for [Candidate] | RTP employer OR Wake/Durham/Orange |

### ISSUE-BASED GROUPS
| Group Name Template | Source data |
|--------------------|------------|
| Second Amendment Supporters for [Candidate] | NRA donor OR gun shop employer OR gun SIC |
| School Choice Advocates for [Candidate] | Parents Defending Ed donor OR private school employee |
| Tax Cutters for [Candidate] | Club for Growth donor OR AFP donor |
| Property Rights Advocates for [Candidate] | Farm Bureau donor OR rural landowner |
| Energy Freedom Advocates for [Candidate] | Oil/gas SIC OR anti-renewable donor |
| Election Integrity Advocates for [Candidate] | True the Vote donor OR election integrity org |

---

## DATABASE IMPLEMENTATION

```sql
-- affinity_group_templates — master list of all group types
CREATE TABLE IF NOT EXISTS public.affinity_group_templates (
    id              SERIAL PRIMARY KEY,
    template_name   text NOT NULL,      -- "Farmers for {candidate}"
    group_category  text,               -- occupational/outdoor/faith/demographic/geography/issue
    issue_tags      text[],             -- which issue_tags this group cares about
    community_tags  text[],             -- which community_identity_tags apply
    -- Membership query rules
    sic_codes       text[],             -- SIC codes that qualify
    employer_keywords text[],           -- ILIKE patterns for employer field
    occupation_keywords text[],         -- ILIKE patterns for occupation
    zip_codes       text[],             -- geographic qualifier
    age_min         integer,
    age_max         integer,
    gender          char(1),
    party           char(1) DEFAULT 'R',
    min_donation_amount numeric DEFAULT 0,
    donation_committee_tags text[],     -- donated to committees with these tags
    -- Social media setup
    facebook_group_name_template text,
    facebook_group_privacy text DEFAULT 'Public',
    hashtag_template text,              -- #FarmersForBroyhill
    -- Content strategy
    content_themes  text[],             -- what to post about for this group
    email_subject_template text,
    sms_template    text,
    created_at      timestamptz DEFAULT NOW()
);

-- affinity_groups — instances per candidate
CREATE TABLE IF NOT EXISTS public.affinity_groups (
    id              SERIAL PRIMARY KEY,
    template_id     integer REFERENCES public.affinity_group_templates(id),
    candidate_id    bigint REFERENCES public.candidates(id),
    group_name      text NOT NULL,      -- "Farmers for Broyhill"
    candidate_name  text,               -- "Ed Broyhill"
    district        text,
    -- Social media
    facebook_group_url  text,
    facebook_group_id   text,
    twitter_list_url    text,
    instagram_hashtag   text,
    -- Email/SMS list
    email_segment_id    text,
    sms_segment_id      text,
    -- Membership
    member_count        integer DEFAULT 0,
    last_refreshed      timestamptz,
    -- Status
    is_active           boolean DEFAULT true,
    launch_date         date,
    created_at          timestamptz DEFAULT NOW()
);

-- affinity_group_members — who belongs to each group
CREATE TABLE IF NOT EXISTS public.affinity_group_members (
    group_id        integer REFERENCES public.affinity_groups(id),
    person_id       bigint REFERENCES core.person_spine(person_id),
    voter_rncid     text,
    join_reason     text,   -- which rule matched: 'sic_code' | 'employer' | 'donation_history' | 'geography' | 'occupation'
    join_score      numeric, -- confidence 0-1
    is_leader       boolean DEFAULT false,  -- district captain / group leader
    leader_title    text,                   -- "District Captain" "County Chair"
    joined_at       timestamptz DEFAULT NOW()
);
```

---

## AUTO-BUILD QUERY — "Farmers for Broyhill" in Senate District 26

```sql
-- Step 1: Build member list
INSERT INTO public.affinity_group_members (group_id, person_id, voter_rncid, join_reason, join_score)
SELECT
    [group_id_for_farmers_broyhill],
    ps.person_id,
    ps.voter_rncid,
    CASE
        WHEN ps.employer_sic BETWEEN '0100' AND '0999' THEN 'sic_code'
        WHEN ps.employer_norm ILIKE ANY(ARRAY['%farm%','%agriculture%','%grower%','%crop%','%livestock%','%poultry%','%tobacco%']) THEN 'employer'
        WHEN EXISTS (
            SELECT 1 FROM core.contribution_map cm
            JOIN public.committee_issues ci ON ci.committee_id = cm.committee_id
            WHERE cm.person_id = ps.person_id
            AND ci.issue_tag IN ('crop_agriculture','hog_farming_cafo','tobacco_farming','rural_economy')
        ) THEN 'donation_history'
        ELSE 'geography'
    END as join_reason,
    0.85 as join_score
FROM core.person_spine ps
JOIN public.nc_voters nv ON nv.ncid = ps.voter_ncid
WHERE
    -- In District 26 (Guilford + Rockingham counties)
    nv.county_id IN (SELECT county_id FROM counties WHERE county_name IN ('GUILFORD','ROCKINGHAM'))
    AND ps.voter_rncid IS NOT NULL
    AND (
        ps.employer_sic BETWEEN '0100' AND '0999'
        OR ps.employer_norm ILIKE '%farm%'
        OR ps.employer_norm ILIKE '%agriculture%'
        OR EXISTS (
            SELECT 1 FROM core.contribution_map cm
            JOIN public.committee_issues ci ON ci.committee_id = cm.committee_id
            WHERE cm.person_id = ps.person_id
            AND ci.issue_tag = 'crop_agriculture'
        )
    );

-- Step 2: Update member count
UPDATE public.affinity_groups SET member_count = (
    SELECT COUNT(*) FROM public.affinity_group_members WHERE group_id = [id]
) WHERE id = [id];
```

---

## SOCIAL MEDIA SETUP PER GROUP

### Facebook Group: "Farmers for Broyhill"
- Type: Public group (visible, joinable by anyone)
- Cover photo: candidate photo + farm imagery
- Description: "NC farmers and agricultural families supporting [Candidate] for [Office]. Join us to stay updated on agricultural policy, events, and how to get involved."
- Auto-posts from E42: Farm Bureau news, USDA news, agricultural legislation
- Pinned post: candidate's agricultural policy positions
- Admin: candidate campaign + BroyhillGOP system

### X/Twitter List: "Hunters for Broyhill"
- List of accounts: NRA, DU, Sportsmen's Alliance, NCWRC, candidate account
- Hashtag: #HuntersForBroyhill
- Auto-posts: NRA alerts, hunting season updates, anti-hunting legislation alerts

### Instagram: #HuntersForBroyhill
- Visual content: hunting photos, conservation images, candidate at outdoor events
- Stories: hunting season countdowns, event invites

---

## CONTENT CALENDAR BY GROUP TYPE

### Farmers for [Candidate] — monthly content themes
| Month | Theme | Auto-source |
|-------|-------|------------|
| Jan | Farm bill updates | USDA, Farm Bureau RSS |
| Feb | Planting season prep / input costs | Farm Bureau, NCDA |
| Mar | Property tax filing season | NC DOR, county assessors |
| Apr | H-2A visa updates | USCIS, growers assoc |
| May | Crop insurance deadlines | USDA FSA |
| Jun | Summer drought / water issues | NCDA, NOAA |
| Jul | County fair season | Local fair calendars |
| Aug | Harvest begins | Farm Bureau |
| Sep | Hurricane season / crop protection | NCDA, NOAA |
| Oct | Harvest wrap / yields | USDA NASS |
| Nov | Election season / farm policy stakes | Campaign content |
| Dec | Year-end farm income / tax planning | Farm Bureau, USDA |

### Hunters for [Candidate] — seasonal content
| Month | Theme |
|-------|-------|
| Aug-Sep | Dove season opens — celebrate |
| Oct | Deer season opens — safety tips, DU events |
| Nov | Duck/waterfowl season — share DU content |
| Jan | Bear season recap, season review |
| Mar | Turkey season opens |
| May | Turkey season closes, conservation projects |
| Year-round | NRA alerts, NCWRC regulation changes, anti-hunting legislation alerts |

---

## PRIORITY GROUPS TO BUILD FIRST — FOR ED BROYHILL

Ed Broyhill is NC Republican National Committeeman — statewide role.
His affinity groups should be statewide, not district-specific:

| Group | Est. Members in NC Spine | Priority |
|-------|------------------------|---------|
| Farmers for Broyhill | ~8,000-12,000 | HIGH |
| Hunters for Broyhill | ~15,000-20,000 | HIGH |
| Veterans for Broyhill | ~12,000-18,000 | HIGH |
| Small Business Owners for Broyhill | ~10,000-15,000 | HIGH |
| Law Enforcement for Broyhill | ~5,000-8,000 | HIGH |
| Second Amendment Supporters for Broyhill | ~25,000+ | HIGH |
| Property Rights Advocates for Broyhill | ~10,000 | MEDIUM |
| School Choice Advocates for Broyhill | ~8,000 | MEDIUM |
| Christians for Broyhill | ~20,000+ | MEDIUM |
| Seniors for Broyhill (65+) | ~30,000+ | MEDIUM |
| Coastal Families for Broyhill | ~8,000 | MEDIUM |
| Biochemists / Life Sciences for Broyhill | ~3,000 | LOW-MEDIUM |
| Young Republicans for Broyhill | ~5,000 | MEDIUM |
| Women for Broyhill | ~40,000+ | HIGH |

---

*Prepared by Perplexity AI — March 31, 2026*
*Auto-built from donor spine + voter file + SIC codes + donation history*
*Feeds directly into E30 (email), E31 (SMS), E19 (social), E34 (events), E41 (campaign builder)*

---

## ADDED GROUPS: TEACHERS, SHERIFFS, DAIRY FARMERS

---

### 👩‍🏫 TEACHERS FOR BROYHILL

**Why this group matters:**
NCAE (NC Association of Educators) is the teachers union — strongly D, gives millions to D candidates.
BUT: 40-45% of NC teachers are registered Republicans or Unaffiliated who vote R.
They are underserved, often feel silenced, and respond powerfully when a candidate
reaches out to them specifically — breaking the NCAE monopoly on teacher identity.

**Key message:** "Not all teachers agree with NCAE. We support school choice AND great public school teachers. 
Teachers who believe in parental rights, safe classrooms, and academic excellence — 
we see you. You are not your union."

**Member qualification rules:**
```sql
-- Teachers for Broyhill
WHERE (
    ps.occupation ILIKE '%teacher%'
    OR ps.occupation ILIKE '%educator%'
    OR ps.occupation ILIKE '%principal%'
    OR ps.occupation ILIKE '%instructor%'
    OR ps.employer ILIKE '%public school%'
    OR ps.employer ILIKE '%elementary%'
    OR ps.employer ILIKE '%middle school%'
    OR ps.employer ILIKE '%high school%'
    OR ps.employer_sic = '8211'  -- elementary/secondary schools
    OR ps.employer_sic = '8221'  -- colleges/universities
)
AND nv.party_cd IN ('REP','UNA')  -- R or Unaffiliated only
```

**Est. statewide members in spine:** 4,000-8,000 Republican/Unaffiliated teachers

**Content themes:**
- Classroom safety / discipline reform
- Teacher pay raises (R-backed NCGA raises, not NCAE narrative)
- Parental rights — teachers who support parents
- Anti-DEI curriculum — "let teachers teach, not preach"
- School choice — "good teachers thrive in any school system"
- NCAE dues — "your union doesn't speak for all teachers"
- Reading/math scores — celebrating NC academic improvements under R NCGA

**Facebook Group:** "Teachers for Broyhill"
- Cover: classroom + candidate image
- Tone: welcoming, NOT anti-teacher — pro-teacher, anti-union-politics
- Key distinction: position against NCAE political agenda, NOT against teachers

**Hashtag:** #TeachersForBroyhill

---

### 🏠 SHERIFFS FOR BROYHILL

**Why this group matters:**
NC has 100 elected sheriffs — one per county. They are:
- Most trusted elected officials in rural NC
- NRA's most important local allies (can declare "2A sanctuary counties")
- Control 287g immigration enforcement
- Key validators for law-and-order candidates
- Personally know EVERY major donor and civic leader in their county
- Their endorsement unlocks that county's entire donor/voter network

A "Sheriffs for Broyhill" coalition with even 40-50 sheriff endorsements is
a massive statewide signal — each endorsement reaches that sheriff's entire
personal network in their county.

**Member qualification rules:**
```sql
-- Active and former NC sheriffs
WHERE (
    ps.current_office ILIKE '%sheriff%'
    OR ps.elected_offices_held @> ARRAY['sheriff']
    OR ps.occupation ILIKE '%sheriff%'
    OR (ps.employer ILIKE '%sheriff%' AND ps.occupation ILIKE '%chief%director%')
)
-- Also include: undersheriffs, chief deputies (future sheriffs)
OR (
    ps.occupation ILIKE '%undersheriff%'
    OR ps.occupation ILIKE '%chief deputy%'
    OR (ps.employer ILIKE '%sheriff%' AND ps.occupation ILIKE '%captain%major%colonel%')
)
```

**Est. statewide members in spine:** 100 sheriffs + ~500 senior command staff

**This is NOT a mass group — it's an elite endorsement roster.**
Strategy: personal outreach to each sheriff, ask for endorsement,
then build "Sheriffs for Broyhill" as a prestige coalition.

**Content themes:**
- Law enforcement appreciation
- Anti-bail reform (cash bail protection)
- 287g / immigration enforcement support
- Second Amendment sanctuary counties
- Mental health + drug treatment (rural crime drivers)
- Fentanyl / drug trafficking at the border
- Anti-defund the police
- Veterans in law enforcement

**Rollout strategy:**
1. Pull all 100 NC sheriffs from candidates/voter file
2. Cross-reference — how many are R, how many are N (officially nonpartisan)
3. Personal call/letter from Ed Broyhill to each R sheriff
4. Build endorsement list publicly as sheriffs commit
5. Use each endorsement as social media moment: "Sheriff [Name] of [County] endorses Broyhill"
6. Final coalition announcement: press release with all endorsing sheriffs

**Facebook:** "NC Sheriffs Supporting Ed Broyhill" (official endorsement page, not open group)
**Hashtag:** #SheriffsForBroyhill

---

### 🐄 DAIRY FARMERS FOR BROYHILL

**Why this group matters:**
Dairy farming is distinct from general crop agriculture — it's:
- Year-round, 365-day operation (no off-season)
- Subject to federal milk pricing (USDA Federal Milk Marketing Orders)
- Dependent on immigration (H-2A labor for milking operations)
- Brutally competitive — NC dairy farms have been closing for decades
- Concentrated geographically — mostly Piedmont and western NC
- Strong family farm identity — multi-generational, deeply conservative
- Active in Farm Bureau but feel underrepresented vs row crop farmers

**NC dairy facts:**
- ~250 dairy farms remaining in NC (down from 1,000+ in 1990s)
- Concentrated in: Guilford, Alamance, Davidson, Cabarrus, Rowan, 
  Iredell, Catawba, Burke, Caldwell, Lincoln, Gaston counties
- Average NC dairy farm: 200-400 cows
- Total NC milk production: ~1.3 billion lbs/year
- Economic value: ~$350M/year farm gate

**Key issues specific to dairy:**
- Federal Milk Marketing Order reform (price they receive for milk)
- Dairy margin protection programs (USDA safety net)
- Animal agriculture nuisance suit protection (same as hog farms)
- Immigration / H-2A for dairy labor (milking 2x/day needs workers)
- Raw milk laws (sale of unpasteurized milk — active fight in NCGA)
- Ag-gag laws (protect farms from activist infiltration)
- Property tax on dairy facilities and equipment
- Manure management regulations (similar to hog lagoon fight)
- Chinese/foreign ownership of food processing facilities
- Dairy checkoff program — mandatory USDA fee, contentious

**Member qualification rules:**
```sql
-- Dairy Farmers for Broyhill
WHERE (
    ps.employer_sic = '0241'  -- dairy farms
    OR ps.employer ILIKE '%dairy%'
    OR ps.employer ILIKE '%creamery%'
    OR ps.employer ILIKE '%milk%farm%'
    OR ps.occupation ILIKE '%dairy%'
    OR ps.occupation ILIKE '%dairyman%'
)
-- Also include: dairy processors, milk co-ops, feed/equipment suppliers
OR ps.employer ILIKE ANY(ARRAY[
    '%Dairy Farmers of America%',
    '%Southeast Milk%',
    '%Milkco%',
    '%Homeland Creamery%',
    '%Maple View Farm%',
    '%Homeland%'
])
```

**Est. statewide members in spine:** 500-1,500 (small, tight-knit community)

**This is a HIGH-VALUE SMALL GROUP — every dairy farmer knows every other dairy farmer in their county.**
One dairy farmer in Guilford County personally knows 20 other dairy families.

**Content themes:**
- Raw milk legalization in NC (currently illegal to sell retail — hot issue)
- Dairy margin protection / milk price policy
- Immigration / H-2A reform for dairy labor
- Farm succession / estate tax
- Celebrating NC dairy heritage
- Anti-foreign ownership of food supply
- USDA dairy policy reform
- Supporting dairy science programs at NC State / NC A&T

**Partner orgs to engage:**
- NC Dairy Producers Association
- NC Farm Bureau Dairy Committee  
- Southeast United Dairy Industry Association (SUDIA)
- Dairy Farmers of America (DFA) Southeast region
- NC State Animal Science Dept (training next gen)

**Facebook Group:** "Dairy Farmers for Broyhill"
- Cover: dairy farm + cows + candidate
- Small, personal, community feel
- Monthly "farm spotlight" — feature a NC dairy farm family
**Hashtag:** #DairyFarmersForBroyhill

---

## UPDATED PRIORITY LIST — ALL GROUPS FOR ED BROYHILL

| Group | Est. Members | Type | Priority |
|-------|-------------|------|---------|
| Second Amendment Supporters for Broyhill | 25,000+ | Issue | 🔴 TOP |
| Women for Broyhill | 40,000+ | Demographic | 🔴 TOP |
| Seniors for Broyhill | 30,000+ | Demographic | 🔴 TOP |
| Veterans for Broyhill | 18,000+ | Identity | 🔴 TOP |
| Hunters for Broyhill | 20,000+ | Outdoor | 🔴 TOP |
| Christians for Broyhill | 20,000+ | Faith | 🔴 TOP |
| Small Business Owners for Broyhill | 15,000+ | Occupational | 🔴 TOP |
| Law Enforcement for Broyhill | 8,000+ | Occupational | 🔴 TOP |
| Farmers for Broyhill | 12,000+ | Industry | 🔴 TOP |
| Sheriffs for Broyhill | 100 sheriffs | Elite endorsement | 🔴 TOP |
| School Choice Advocates for Broyhill | 8,000+ | Issue | 🟡 HIGH |
| Property Rights Advocates for Broyhill | 10,000+ | Issue | 🟡 HIGH |
| Young Republicans for Broyhill | 5,000+ | Demographic | 🟡 HIGH |
| Fishermen for Broyhill | 8,000+ | Outdoor | 🟡 HIGH |
| Teachers for Broyhill | 6,000+ | Occupational | 🟡 HIGH |
| Coastal Families for Broyhill | 8,000+ | Geography | 🟡 HIGH |
| Dairy Farmers for Broyhill | 1,000 | Industry niche | 🟡 HIGH |
| Mountain Families for Broyhill | 5,000+ | Geography | 🟢 MEDIUM |
| Biochemists / Life Sciences for Broyhill | 3,000 | Occupational | 🟢 MEDIUM |
| Duck Hunters for Broyhill | 3,000 | Outdoor niche | 🟢 MEDIUM |
| Bear Hunters for Broyhill | 1,500 | Outdoor niche | 🟢 MEDIUM |
| Pro-Life Advocates for Broyhill | 8,000+ | Issue | 🟢 MEDIUM |
| Military Families for Broyhill | 6,000+ | Identity | 🟢 MEDIUM |
| Fox Hunters for Broyhill | 500 | Outdoor niche | 🔵 LATER |
| Pastors for Broyhill | 2,000+ | Faith | 🔵 LATER |

---

*Updated March 31, 2026 — Teachers, Sheriffs, Dairy Farmers added*
*Sheriffs is elite endorsement strategy, not mass group*
*Teachers breaks NCAE monopoly — strategic positioning*
*Dairy Farmers is small but extremely high-value tight-knit community*

---

## ADDED GROUPS: DOCTORS, NURSES, SENIORS, SOCCER MOMS

---

### 👨‍⚕️ DOCTORS FOR BROYHILL

**Why this group matters:**
NC has ~30,000 licensed physicians. They are:
- High-income donors — avg physician gives $2,500-$10,000/cycle
- Conservative on regulation, liability, government interference in medicine
- Fighting ACA mandates, vaccine mandates, prior authorization requirements
- Deeply opposed to trial lawyers (malpractice suits)
- Frustrated with hospital corporate consolidation eating their independence
- Republican-leaning but feel taken for granted
- Each physician knows 50-100 other high-net-worth professionals

**Key message:** "Government bureaucrats and insurance companies should not practice medicine. 
Doctors deserve the freedom to treat patients, not fill out forms. 
We stand with NC physicians for a free practice of medicine."

**Member qualification rules:**
```sql
WHERE (
    ps.occupation ILIKE ANY(ARRAY['%physician%','%doctor%','% MD%','% DO%','%surgeon%','%radiologist%','%cardiologist%','%oncologist%','%pediatrician%','%psychiatrist%','%anesthesiologist%'])
    OR ps.employer_sic IN ('8011','8049')  -- offices of physicians
    OR ps.employer ILIKE '%medical center%'
    AND (ps.occupation ILIKE '%M.D%' OR ps.occupation ILIKE '%physician%')
)
AND nv.party_cd IN ('REP','UNA')
```

**Est. statewide members in spine:** 3,000-6,000

**Key issues:**
- Certificate of Need (CON) reform — doctors can't open competing facilities
- Prior authorization reform — insurance blocking treatment decisions
- Malpractice / tort reform — trial lawyer liability
- Medicaid reimbursement rates
- ACA / government mandate repeal
- Physician independence vs hospital employment
- DEA licensing for controlled substances
- Vaccine mandate opposition
- Mental health parity

**Partner orgs:** NC Medical Society, NC Physicians Alliance, NC Specialty societies (cardiology, oncology, orthopedics, surgery)

**Facebook:** "Doctors for Broyhill" — professional tone, policy focused
**Hashtag:** #DoctorsForBroyhill

---

### 👩‍⚕️ NURSES FOR BROYHILL

**Why this group matters:**
NC has ~120,000 registered nurses — the largest healthcare workforce segment.
They are:
- More politically diverse than doctors — split R/D
- INCREASINGLY Republican due to: vaccine mandates, woke hospital policies, DEI requirements, being fired for religious exemptions, staff-to-patient ratio fights
- 2020-2023 created a massive wave of politically activated conservative nurses
- Strong on: religious freedom, medical freedom, anti-mandate, pro-patient-not-bureaucracy
- High community trust — neighbors listen to nurses

**Key message:** "NC nurses were called heroes — then fired for their beliefs.
We stand with nurses who believe in medical freedom, religious liberty,
patient-centered care, and the right to practice without government dictating
what goes in your body or your patients' bodies."

**Member qualification rules:**
```sql
WHERE (
    ps.occupation ILIKE ANY(ARRAY['%nurse%','% RN%','% LPN%','% NP%','%nurse practitioner%','%nursing%','%CNA%'])
    OR ps.employer_sic IN ('8011','8049','8051','8062','8063','8069')
    AND ps.occupation ILIKE '%nurs%'
)
AND nv.party_cd IN ('REP','UNA')
```

**Est. statewide members in spine:** 8,000-15,000

**Key issues:**
- Vaccine mandate / religious exemption protection
- Nurse-to-patient ratio legislation
- Scope of practice expansion (NPs practicing independently)
- Travel nurse regulation
- DEI requirements in hospitals
- Religious freedom in healthcare employment
- Opioid prescribing liability protection
- Nursing home staffing mandates

**Subgroups possible:**
- Travel Nurses for Broyhill (highly mobile, politically activated)
- Veteran Nurses for Broyhill
- Christian Nurses for Broyhill

**Facebook:** "Nurses for Broyhill"
**Hashtag:** #NursesForBroyhill

---

### 👴 SENIORS FOR BROYHILL

**Why this group matters:**
NC has 2.1M residents age 65+ — the highest-turnout voting bloc.
They are:
- Most reliable voters — 75%+ turnout every election
- Historically Republican-leaning in NC
- BUT increasingly contested — Dems target with Social Security / Medicare fear messaging
- Respond strongly to: crime safety, Medicare protection, anti-socialism, grandchildren's future
- Fixed income → deeply opposed to inflation, taxes, government spending
- Many are veterans — dual identity
- Heavy concentration: Brunswick County coast, western NC mountains, Pinehurst, Lake Norman

**Key message:** "You worked your whole life for this. You earned your Social Security, 
your Medicare, your savings, your home. We will protect what you've built — 
from inflation, from crime, from a government that wants to take it away 
and give it to people who didn't earn it."

**Member qualification rules:**
```sql
WHERE
    EXTRACT(YEAR FROM NOW()) - EXTRACT(YEAR FROM nv.birth_year) >= 65
    AND nv.party_cd IN ('REP','UNA')
    AND nv.voter_status_cd = 'A'  -- active voters only
```

**Est. statewide members in spine:** 30,000-50,000 (massive group)

**Segment further by:**
- 65-74 (Active Seniors) — different messaging than 75+
- Military veterans 65+ — "Veterans & Seniors for Broyhill"
- Rural seniors vs suburban seniors — different issues
- Fixed-income seniors vs affluent retired — different donor capacity

**Key issues:**
- Social Security protection (no cuts)
- Medicare preservation and drug pricing
- Inflation / cost of living
- Crime safety — seniors disproportionately fear crime
- Grandchildren's future — debt, education, values
- Property tax relief for seniors (homestead exemption)
- Long-term care / Medicaid for nursing homes
- Anti-socialism / protecting retirement savings
- Voter ID — seniors have IDs, support it strongly
- Veterans benefits (overlap)

**Content calendar:**
- Monthly: Medicare/Social Security policy updates
- Seasonal: Property tax deadlines, senior discount programs
- Ongoing: Crime statistics, anti-inflation messaging
- Events: Senior center visits, "Coffee with Broyhill" events

**Facebook Group:** "Seniors for Broyhill" — warm, family-values tone
**Newsletter:** Monthly "Senior Voice" newsletter
**Hashtag:** #SeniorsForBroyhill

---

### ⚽ SOCCER MOMS FOR BROYHILL

**Why this group matters:**
"Soccer Mom" is the most famous swing voter demographic in American politics.
In 2025-2026 context they are:
- Suburban women, 30-50, children in school
- Moved LEFT in 2018-2020 on Trump/tone issues
- Moving RIGHT in 2022-2026 on: school curriculum, crime, inflation, fentanyl
- The Loudoun County effect — CRT/gender ideology in schools created conservative moms
- Moms for Liberty, Parents Defending Education built from this energy
- High community influence — PTA, youth sports, neighborhood networks
- They talk to each other constantly — viral word of mouth
- In NC: concentrated in suburban Wake, Mecklenburg, Guilford, Cabarrus, Union counties

**Key message:** "You coach the team, you run the carpool, you know every kid 
on the field by name. You just want safe schools, honest education, 
and a community where your kids can grow up free. 
We're with you — not the bureaucrats, not the union, not the activists. You."

**Member qualification rules:**
```sql
WHERE
    nv.gender_code = 'F'
    AND EXTRACT(YEAR FROM NOW()) - EXTRACT(YEAR FROM nv.birth_year) BETWEEN 28 AND 55
    AND nv.party_cd IN ('REP','UNA')
    -- Suburban zip codes (pre-tagged by community_identity)
    AND nv.zip_code IN (SELECT zip5 FROM community_profiles 
                        WHERE 'suburban_growth' = ANY(identity_tags))
    -- Bonus: has children in school age range (proxy: voter age 30-50, suburban)
```

**Est. statewide members in spine:** 15,000-25,000

**Key issues — what ACTUALLY moved them right:**
- School curriculum — no gender ideology, no CRT, no age-inappropriate content
- Parental rights — right to know what's taught, right to opt out
- School safety — real security, not metal detectors but culture
- Fentanyl / drug crisis — their kids' friends are dying
- Inflation — grocery prices, youth sports costs
- Crime in their neighborhoods — carjackings, porch pirates
- Social media harm to children — algorithmic regulation
- College admissions / DEI — merit-based for their kids
- Library book content — age-appropriate materials

**Key differentiator from Moms for Liberty:**
Soccer Moms for Broyhill is BROADER and SOFTER than Moms for Liberty.
MFL has become politically polarizing. Soccer Moms is welcoming to:
- UNA women who aren't ready to call themselves Republicans yet
- Women who care about schools but aren't single-issue activists
- Moms who want a community, not a political organization

**Content strategy:**
- Warm, visual, community-focused
- Real NC moms featured (user-generated content)
- School calendar aligned — back to school, testing season, prom, graduation
- Youth sports imagery — fields, teams, scoreboard
- NOT angry, NOT political war language — hopeful, protective, forward-looking

**Events:** 
- "Coffee with Moms" — candidate home visits in suburban neighborhoods
- Youth sports sponsorships — "Broyhill for NC" sponsors local soccer league
- School board meeting watch parties

**Facebook Group:** "Soccer Moms for Broyhill" — warm, visual, community board
**Instagram:** Primary platform for this group — visual storytelling
**Hashtag:** #SoccerMomsForBroyhill
**Pinterest:** Yes — this group uses Pinterest for family content

---

## UPDATED MASTER PRIORITY LIST

| Group | Est. Members | Type | Priority |
|-------|-------------|------|---------|
| Second Amendment Supporters for Broyhill | 25,000+ | Issue | 🔴 TOP |
| Women for Broyhill | 40,000+ | Demographic | 🔴 TOP |
| **Seniors for Broyhill** | **35,000+** | **Demographic** | 🔴 **TOP** |
| Veterans for Broyhill | 18,000+ | Identity | 🔴 TOP |
| **Soccer Moms for Broyhill** | **20,000+** | **Swing voter** | 🔴 **TOP** |
| Hunters for Broyhill | 20,000+ | Outdoor | 🔴 TOP |
| Christians for Broyhill | 20,000+ | Faith | 🔴 TOP |
| Small Business Owners for Broyhill | 15,000+ | Occupational | 🔴 TOP |
| Law Enforcement for Broyhill | 8,000+ | Occupational | 🔴 TOP |
| Farmers for Broyhill | 12,000+ | Industry | 🔴 TOP |
| Sheriffs for Broyhill | 100 sheriffs | Elite endorsement | 🔴 TOP |
| **Nurses for Broyhill** | **12,000+** | **Occupational** | 🟡 **HIGH** |
| **Doctors for Broyhill** | **5,000+** | **Occupational** | 🟡 **HIGH** |
| Teachers for Broyhill | 6,000+ | Occupational | 🟡 HIGH |
| School Choice Advocates for Broyhill | 8,000+ | Issue | 🟡 HIGH |
| Fishermen for Broyhill | 8,000+ | Outdoor | 🟡 HIGH |
| Dairy Farmers for Broyhill | 1,000 | Industry niche | 🟡 HIGH |
| Coastal Families for Broyhill | 8,000+ | Geography | 🟡 HIGH |
| Young Republicans for Broyhill | 5,000+ | Demographic | 🟡 HIGH |
| Military Families for Broyhill | 6,000+ | Identity | 🟢 MEDIUM |
| Pro-Life Advocates for Broyhill | 8,000+ | Issue | 🟢 MEDIUM |
| Mountain Families for Broyhill | 5,000+ | Geography | 🟢 MEDIUM |
| Duck Hunters for Broyhill | 3,000 | Outdoor niche | 🟢 MEDIUM |
| Bear Hunters for Broyhill | 1,500 | Outdoor niche | 🟢 MEDIUM |
| Fox Hunters for Broyhill | 500 | Outdoor niche | 🔵 LATER |
| Pastors for Broyhill | 2,000+ | Faith | 🔵 LATER |
| Biochemists / Life Sciences for Broyhill | 3,000 | Occupational | 🔵 LATER |

---

*Updated March 31, 2026 — Doctors, Nurses, Seniors, Soccer Moms added*
*Soccer Moms is the #1 swing voter group — softer positioning than Moms for Liberty*
*Seniors is the largest high-turnout group — 35,000+ active voters*
*Nurses group activated by mandate/religious freedom issues post-2020*
