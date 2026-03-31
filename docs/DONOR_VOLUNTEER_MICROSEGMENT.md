# Donor & Volunteer Base Microsegmentation by Office District
## BroyhillGOP — Every donor and volunteer tagged to every district they live in
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT

Every person in the donor spine AND volunteer base gets tagged to
EVERY elected office district they reside in simultaneously.

One person in Wake County lives in:
- US Congressional District 13
- NC Senate District 15
- NC House District 35
- Wake County Commissioner District 4
- Wake County School Board District 4
- Raleigh City Council District 2
- (possibly) Town of Cary jurisdiction

That person is a potential donor or volunteer for ALL of those races.
Tag them to all of them. Segment by any one or combination.

---

## DISTRICT TYPES TO TAG — ALL LEVELS

```
federal_congressional_district    -- US House (NC 1-14)
us_senate_class                   -- Class 2 (Tillis 2026) or Class 3 (Budd 2028)
nc_senate_district                -- 1-50
nc_house_district                 -- 1-120
nc_governor_statewide             -- everyone in NC
council_of_state_statewide        -- everyone in NC
nc_supreme_court_statewide        -- everyone in NC
nc_court_of_appeals_district      -- 1-8 appellate districts
nc_superior_court_district        -- county-based
nc_district_court_district        -- county-based
nc_da_district                    -- 1-44 prosecutorial districts
county_commissioner_district      -- varies by county
county_sheriff                    -- county-level
county_register_of_deeds          -- county-level
county_clerk_of_court             -- county-level
school_board_district             -- 115 districts, many sub-districts
municipal_district                -- city/town
municipal_ward                    -- ward within city
fire_district                     -- some are elected
soil_water_district               -- some are elected
```

---

## DATABASE IMPLEMENTATION

```sql
-- person_district_map — the core microsegmentation table
-- One row per person per district they live in
CREATE TABLE IF NOT EXISTS public.person_district_map (
    id              BIGSERIAL PRIMARY KEY,
    person_id       bigint REFERENCES core.person_spine(person_id),
    voter_ncid      text,
    voter_rncid     text,

    -- District type and number
    district_type   text NOT NULL,      -- 'nc_house' | 'nc_senate' | 'us_house' | 'county_commissioner' etc
    district_id     text NOT NULL,      -- "35" for NC House 35, "Wake" for county-level
    district_name   text,               -- "NC House District 35" | "Wake County District 4"

    -- The candidate(s) for this district
    incumbent_candidate_id  bigint,     -- current officeholder
    challenger_candidate_id bigint,     -- if contested

    -- Donor profile FOR THIS DISTRICT
    total_donated_to_district   numeric DEFAULT 0,  -- $ given to candidates in this district
    donation_count_district     integer DEFAULT 0,
    last_donated_district       date,
    is_district_donor           boolean DEFAULT false,

    -- Volunteer profile FOR THIS DISTRICT
    is_district_volunteer       boolean DEFAULT false,
    volunteer_hours_district    numeric DEFAULT 0,
    last_volunteered_district   date,
    volunteer_roles             text[],   -- 'canvasser' | 'phone_banker' | 'precinct_captain' | 'donor_host'

    -- Affinity groups active in this district
    affinity_group_ids          integer[],

    -- Flags
    is_target_donor             boolean DEFAULT false,  -- high propensity, not yet donor
    is_lapsed_donor             boolean DEFAULT false,  -- gave before, not recently
    is_active_donor             boolean DEFAULT false,  -- gave this cycle
    is_major_donor              boolean DEFAULT false,  -- >$1000 to district races
    is_precinct_captain         boolean DEFAULT false,
    is_volunteer_leader         boolean DEFAULT false,

    created_at      timestamptz DEFAULT NOW(),
    updated_at      timestamptz DEFAULT NOW()
);

-- Indexes for fast district-level queries
CREATE INDEX IF NOT EXISTS idx_pdm_district_type ON public.person_district_map (district_type, district_id);
CREATE INDEX IF NOT EXISTS idx_pdm_person ON public.person_district_map (person_id);
CREATE INDEX IF NOT EXISTS idx_pdm_ncid ON public.person_district_map (voter_ncid);
CREATE INDEX IF NOT EXISTS idx_pdm_rncid ON public.person_district_map (voter_rncid);
CREATE INDEX IF NOT EXISTS idx_pdm_donor_flags ON public.person_district_map (is_active_donor, is_major_donor, district_type);
CREATE INDEX IF NOT EXISTS idx_pdm_volunteer_flags ON public.person_district_map (is_district_volunteer, district_type);
```

---

## POPULATION QUERY — build person_district_map from nc_voters

```sql
-- Step 1: Tag every donor/volunteer to their NC House district
INSERT INTO public.person_district_map (person_id, voter_ncid, voter_rncid, district_type, district_id, district_name)
SELECT
    ps.person_id,
    ps.voter_ncid,
    ps.voter_rncid,
    'nc_house' as district_type,
    nv.house_district as district_id,
    'NC House District ' || nv.house_district as district_name
FROM core.person_spine ps
JOIN public.nc_voters nv ON nv.ncid = ps.voter_ncid
WHERE nv.house_district IS NOT NULL
ON CONFLICT DO NOTHING;

-- Step 2: NC Senate
INSERT INTO public.person_district_map (person_id, voter_ncid, voter_rncid, district_type, district_id, district_name)
SELECT ps.person_id, ps.voter_ncid, ps.voter_rncid,
    'nc_senate', nv.senate_district, 'NC Senate District ' || nv.senate_district
FROM core.person_spine ps
JOIN public.nc_voters nv ON nv.ncid = ps.voter_ncid
WHERE nv.senate_district IS NOT NULL
ON CONFLICT DO NOTHING;

-- Step 3: US Congressional
INSERT INTO public.person_district_map (person_id, voter_ncid, voter_rncid, district_type, district_id, district_name)
SELECT ps.person_id, ps.voter_ncid, ps.voter_rncid,
    'us_house', nv.congressional_district, 'US House District ' || nv.congressional_district
FROM core.person_spine ps
JOIN public.nc_voters nv ON nv.ncid = ps.voter_ncid
WHERE nv.congressional_district IS NOT NULL
ON CONFLICT DO NOTHING;

-- Step 4: County (sheriff, commissioner, clerk, register)
INSERT INTO public.person_district_map (person_id, voter_ncid, voter_rncid, district_type, district_id, district_name)
SELECT ps.person_id, ps.voter_ncid, ps.voter_rncid,
    'county', nv.county_desc, nv.county_desc || ' County'
FROM core.person_spine ps
JOIN public.nc_voters nv ON nv.ncid = ps.voter_ncid
WHERE nv.county_desc IS NOT NULL
ON CONFLICT DO NOTHING;
```

---

## DONOR + VOLUNTEER MIRROR — they should look alike

**The principle:** A good volunteer prospect looks exactly like a donor prospect.
Same demographics, same geography, same issues, same community identity.
The difference is capacity — donors have money, volunteers have time.
Many people are both.

```sql
-- Volunteer profile table — mirrors donor profile exactly
CREATE TABLE IF NOT EXISTS public.volunteer_profiles (
    person_id       bigint PRIMARY KEY REFERENCES core.person_spine(person_id),
    voter_ncid      text,
    voter_rncid     text,

    -- Availability
    available_weekdays  boolean DEFAULT false,
    available_evenings  boolean DEFAULT true,
    available_weekends  boolean DEFAULT true,
    hours_per_week      integer,

    -- Skills
    can_canvass         boolean DEFAULT false,
    can_phone_bank      boolean DEFAULT false,
    can_host_event      boolean DEFAULT false,
    can_donate_space    boolean DEFAULT false,   -- has home/venue for fundraiser
    can_drive_voters    boolean DEFAULT false,
    can_data_entry      boolean DEFAULT false,
    can_social_media    boolean DEFAULT false,
    can_write           boolean DEFAULT false,
    has_truck_trailer   boolean DEFAULT false,   -- yard sign delivery
    speaks_spanish      boolean DEFAULT false,
    speaks_other        text,
    professional_skill  text,                    -- doctor/lawyer/accountant — can advise campaign

    -- Geographic scope
    willing_county      text[],                  -- counties willing to work in
    willing_statewide   boolean DEFAULT false,
    home_precinct       text,
    precinct_captain    boolean DEFAULT false,

    -- Activity
    total_events_attended   integer DEFAULT 0,
    total_doors_knocked     integer DEFAULT 0,
    total_calls_made        integer DEFAULT 0,
    total_hours             numeric DEFAULT 0,
    last_activity_date      date,
    first_activity_date     date,

    -- Reliability score (0-100)
    reliability_score   integer,                 -- showed up when committed
    enthusiasm_score    integer,                 -- energy level, recruits others
    skill_score         integer,                 -- effectiveness at their role

    -- Affinity groups
    affinity_group_ids  integer[],

    -- Matching to donor profile
    is_also_donor       boolean DEFAULT false,
    total_donated       numeric DEFAULT 0,

    created_at  timestamptz DEFAULT NOW(),
    updated_at  timestamptz DEFAULT NOW()
);
```

---

## MICROSEGMENT QUERY EXAMPLES

### "Who are our active donors in NC Senate District 26 (Phil Berger's district)?"
```sql
SELECT ps.norm_first, ps.norm_last, ps.voter_rncid,
    pdm.total_donated_to_district, pdm.last_donated_district
FROM public.person_district_map pdm
JOIN core.person_spine ps ON ps.person_id = pdm.person_id
WHERE pdm.district_type = 'nc_senate'
AND pdm.district_id = '26'
AND pdm.is_active_donor = true
ORDER BY pdm.total_donated_to_district DESC;
```

### "Who are high-propensity volunteer prospects in Wake County for US House District 13?"
```sql
SELECT ps.norm_first, ps.norm_last, vp.can_canvass, vp.can_phone_bank,
    vp.available_weekends, vp.reliability_score
FROM public.person_district_map pdm
JOIN core.person_spine ps ON ps.person_id = pdm.person_id
JOIN public.volunteer_profiles vp ON vp.person_id = pdm.person_id
WHERE pdm.district_type = 'us_house'
AND pdm.district_id = '13'
AND pdm.is_target_donor = false      -- not already a donor
AND vp.available_weekends = true
AND vp.reliability_score >= 70
ORDER BY vp.total_hours DESC;
```

### "For Sheriffs for Broyhill campaign — who in each county are our top donors AND top volunteers?"
```sql
SELECT
    pdm.district_id as county,
    COUNT(DISTINCT CASE WHEN pdm.is_active_donor THEN ps.person_id END) as active_donors,
    COUNT(DISTINCT CASE WHEN pdm.is_district_volunteer THEN ps.person_id END) as volunteers,
    COUNT(DISTINCT CASE WHEN pdm.is_active_donor AND pdm.is_district_volunteer THEN ps.person_id END) as donor_volunteers,
    ROUND(SUM(CASE WHEN pdm.is_active_donor THEN pdm.total_donated_to_district ELSE 0 END)) as total_raised
FROM public.person_district_map pdm
JOIN core.person_spine ps ON ps.person_id = pdm.person_id
WHERE pdm.district_type = 'county'
GROUP BY pdm.district_id
ORDER BY total_raised DESC;
```

### "Build a call list for Soccer Moms in suburban Wake County districts"
```sql
SELECT ps.norm_first, ps.norm_last, dc.contact_value as phone,
    pdm.district_type, pdm.district_name
FROM public.person_district_map pdm
JOIN core.person_spine ps ON ps.person_id = pdm.person_id
JOIN public.affinity_group_members agm ON agm.person_id = ps.person_id
JOIN public.affinity_groups ag ON ag.id = agm.group_id
    AND ag.group_name ILIKE '%Soccer Moms%'
JOIN public.donor_contacts dc ON dc.voter_ncid = ps.voter_ncid
    AND dc.contact_type IN ('cell','mobile_phone')
WHERE pdm.district_type = 'nc_house'
AND pdm.district_id IN ('35','36','37','40','41')  -- suburban Wake districts
ORDER BY ps.norm_last;
```

---

## BUILD ORDER

1. **person_district_map** — populate from nc_voters (all 4 district types: us_house, nc_senate, nc_house, county)
2. **Stamp is_active_donor** — cross-reference contribution_map for donations to candidates in each district
3. **Stamp is_district_volunteer** — cross-reference volunteer_profiles
4. **Stamp is_target_donor** — high RNC scores + no donation history = target
5. **affinity_group_members** — auto-build from spine + SIC + employer + geography
6. **volunteer_profiles** — build from existing volunteer data + nc_voters demographics

---

*Prepared by Perplexity AI — March 31, 2026*
*Every donor and volunteer tagged to every district simultaneously*
*Donor base and volunteer base mirror each other — same schema, same segmentation*
*Foundation for every affinity group, every campaign, every outreach list*
