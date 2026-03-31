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
