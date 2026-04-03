# District & Geography Issue Profiles
## BroyhillGOP — Permanent Geographic Issue Tags
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT: TWO SEPARATE ISSUE DIMENSIONS

### Dimension 1: CANDIDATE ISSUES (politician-specific)
- What THIS person champions, votes for, scores on
- Changes when the politician changes
- Source: voting record, endorsements, scorecards
- Table: candidate_issues

### Dimension 2: DISTRICT GEOGRAPHY ISSUES (place-specific)
- What THIS geography permanently generates as political conflict
- Exists regardless of who holds the office
- Special interests engage HERE because of geography, not because of the person
- Source: economic data, demographic data, industry presence, land use
- Table: district_geography_issues (NEW)

---

## NC GEOGRAPHY-DRIVEN ISSUE MAP

### MOUNTAIN REGION (Western NC — roughly Districts 45-50 Senate, 85-120 House)

| Geography | Permanent Issue | Special Interest Engaged | issue_tag |
|-----------|----------------|------------------------|-----------|
| Cherokee County / Eastern Band of Cherokee Indians (EBCI) | Tribal gaming / Cherokee Casino (Harrah's) | EBCI tribal government, Harrah's Cherokee, anti-gambling groups | tribal_gaming |
| Cherokee County | Tribal sovereignty, federal Indian law | EBCI, BIA, tribal rights groups | tribal_sovereignty |
| Western NC mountains | Tourism / short-term rental regulation | VRBO/Airbnb hosts, hotel industry, mountain town residents | str_regulation |
| Appalachian forests | Logging / timber rights | NC Forestry Association, Sierra Club, timber industry | timber_forestry |
| Mountain rivers | Trout fishing / clean water | Trout Unlimited, DU, white water tourism | freshwater_fishing |
| Avery/Watauga | Ski industry / mountain development | Ski resort operators, environmental groups | mountain_development |
| Western NC | Broadband/rural internet access | Spectrum, AT&T, rural electric co-ops | rural_broadband |
| Helene disaster zone (2024) | Disaster recovery / FEMA funding | Construction industry, FEMA, insurance | disaster_recovery |
| Small mountain towns | Hospital closures / rural healthcare | Rural hospital systems, Medicaid | rural_healthcare |

### PIEDMONT TRIAD (Guilford, Forsyth, Rockingham, Alamance, Davidson, Randolph)

| Geography | Permanent Issue | Special Interest | issue_tag |
|-----------|----------------|-----------------|-----------|
| Guilford/Forsyth | Manufacturing base — furniture, textiles, biotech | NC Chamber, manufacturers assoc | manufacturing |
| Greensboro/Winston-Salem | Airport expansion / aviation | Piedmont Triad Airport authority, airlines | aviation_transport |
| Alamance County | Immigration enforcement (287g leader) | ICE, immigration reform groups, Latino orgs | immigration_enforcement |
| Randolph County | Gun manufacturing (Remington relocated here) | NSSF, gun rights groups | second_amendment |
| Davidson County | Furniture / logistics hub | Furniture industry PAC, trucking | furniture_industry |

### CHARLOTTE METRO (Mecklenburg, Cabarrus, Union, Gaston, Iredell, Lincoln, Rowan)

| Geography | Permanent Issue | Special Interest | issue_tag |
|-----------|----------------|-----------------|-----------|
| Mecklenburg | Banking/finance hub (Bank of America, Wells Fargo HQ) | NC Bankers, financial industry PACs | banking_finance |
| Charlotte | Light rail / transit expansion | CATS, real estate developers, anti-transit groups | urban_transit |
| Charlotte | Growth/zoning pressure | Home builders, developers, neighborhood groups | zoning_development |
| Mecklenburg | Immigration / sanctuary city pressure | Immigration groups, law enforcement | immigration_enforcement |
| Union/Cabarrus | Rapid suburban growth | Home builders, school bond issues, road funding | suburban_growth |
| Gaston County | Textile mill legacy / economic redevelopment | Economic development corps | economic_redevelopment |
| Lake Norman (Iredell/Lincoln) | Lake development, water quality, boat access | Lake homeowners assoc, marina industry | lake_development |

### RESEARCH TRIANGLE (Wake, Durham, Orange, Chatham)

| Geography | Permanent Issue | Special Interest | issue_tag |
|-----------|----------------|-----------------|-----------|
| Wake/Durham/Orange | Research Triangle Park — biotech, pharma, tech | PhRMA, tech industry, university research | biotech_pharma |
| Wake County | Rapid growth — roads, schools, water | Home builders, Realtors, school bond advocacy | suburban_growth |
| Wake | State government seat — all issues | Lobbyists, all state-level PACs | state_government |
| Durham/Orange | University towns — UNC, Duke, NCCU, NCState | University systems, academic freedom groups | higher_education |
| Orange County | Anti-development / environmental | Sierra Club, environmental groups | environmental |
| Chatham County | Solar farm proliferation | Solar industry, rural landowners, anti-solar groups | energy_solar |
| Jordan Lake / Falls Lake | Water supply / nutrient rules | Agriculture (upstream), municipal water utilities | water_quality |

### COASTAL PLAIN (Eastern NC — roughly Districts 1-12 Senate, 1-25 House)

| Geography | Permanent Issue | Special Interest | issue_tag |
|-----------|----------------|-----------------|-----------|
| Eastern NC coast | Commercial vs recreational fishing | CCA, Recreational Fishing Alliance vs NC Fisheries Assoc | commercial_rec_conflict |
| Outer Banks | Beach nourishment / coastal development | Dare County, NCDOT, Army Corps of Engineers | coastal_development |
| Pamlico/Albemarle sounds | Shrimp trawl / gill net ban | CCA, commercial fishermen, recreational anglers | saltwater_fishing |
| Bertie/Halifax/Northampton | Economically distressed — rural poverty | Economic development, Opportunity Zones, HUD | rural_economic_development |
| Robeson County | Lumber River flooding — Lumbee Tribe | Lumbee Tribe (federal recognition battle), FEMA | tribal_sovereignty |
| Robeson County | Lumbee Tribe federal recognition | Lumbee Tribal Council, Cherokee (opposes), BIA | lumbee_recognition |
| Sampson/Duplin/Wayne | Hog farms / environmental complaints | NC Pork Council, CAFO opponents, environmental groups | hog_farming |
| Lenoir/Greene/Pitt | Tobacco legacy economy | NC Tobacco Growers, farm bureau | tobacco_farming |
| Pitt County | ECU medical school / healthcare | ECU Health, rural healthcare access | rural_healthcare |
| Fort Bragg / Cumberland | Military base — Bragg/Liberty largest US base | Defense contractors, military housing, BRAC | military_base |
| Camp Lejeune / Onslow | Marine base — PFAS contamination | Veterans groups, environmental, DOD | military_base |
| Camp Lejeune | PFAS water contamination litigation | Veterans, plaintiff lawyers, DOD, EPA | pfas_contamination |

### SANDHILLS (Moore, Hoke, Scotland, Richmond, Montgomery)

| Geography | Permanent Issue | Special Interest | issue_tag |
|-----------|----------------|-----------------|-----------|
| Moore County | Golf industry (Pinehurst) | Golf industry, tourism, resort development | golf_tourism |
| Moore/Hoke | Fort Liberty (Bragg) economy | Defense contractors, military families | military_base |
| Hoke/Scotland/Robeson | Lumbee Tribe territory | Lumbee recognition, tribal gaming aspirations | lumbee_recognition |
| Richmond County | Correctional facility employment | Prison guard union (NCDPS), rural jobs | corrections |

### CAPE FEAR / COASTAL SOUTHEAST (Brunswick, New Hanover, Pender, Columbus, Bladen)

| Geography | Permanent Issue | Special Interest | issue_tag |
|-----------|----------------|-----------------|-----------|
| New Hanover / Wilmington | Film industry (Wilmington studio — Screen Gems) | NC Film incentives, entertainment industry | film_industry |
| Brunswick County | Fastest-growing county in NC — development pressure | Home builders, developers, environmental groups | coastal_development |
| Cape Fear River | GenX/PFAS contamination (Chemours/Fayetteville Works) | Environmental groups, plaintiffs, Chemours, EPA | pfas_contamination |
| Southeastern coast | Nuclear power (Shearon Harris, Brunswick Plant) | Duke Energy, nuclear industry, anti-nuclear | nuclear_energy |
| Wilmington port | Port of Wilmington expansion | Shipping industry, NCDOT, logistics | port_commerce |

### NORTHEAST CORRIDOR (Halifax, Warren, Vance, Granville, Person, Caswell)

| Geography | Permanent Issue | Special Interest | issue_tag |
|-----------|----------------|-----------------|-----------|
| I-85 corridor | Broadband, economic development | Rural electric co-ops, economic development | rural_broadband |
| Halifax/Northampton | Poorest counties in NC | Opportunity zones, HUD, workforce development | rural_economic_development |
| Vance/Warren | Prison economy (Kerr Lake area) | NCDPS, corrections officers | corrections |

---

## TRIBAL SOVEREIGNTY — SPECIAL FOCUS

NC has two federally recognized tribes and one seeking recognition:

| Tribe | Location | Key Issues | Status |
|-------|----------|-----------|--------|
| **Eastern Band of Cherokee Indians (EBCI)** | Cherokee, NC (Jackson/Swain/Graham counties) | Harrah's Cherokee Casino (2 locations, $1B+ revenue), tribal sovereignty, gaming compact with state, tax exemptions | Federally recognized — very politically active |
| **Lumbee Tribe of NC** | Robeson/Hoke/Scotland/Cumberland counties | Federal recognition (blocked for decades by EBCI to protect casino monopoly), potential gaming rights, federal funding | State recognized, NOT federally recognized — active lobbying campaign |
| **Coharie Tribe** | Sampson/Harnett counties | State recognized only, limited resources | Lower profile |

**The EBCI opposes Lumbee federal recognition specifically because it would allow Lumbee to open competing casinos under IGRA (Indian Gaming Regulatory Act).**

This is a permanent geographic conflict:
- EBCI → massive political donor → opposes Lumbee recognition
- Lumbee → growing political force → push for federal recognition + gaming
- NC Governor and congressional delegation → key votes on Lumbee recognition bill

---

## DATABASE IMPLEMENTATION

```sql
-- New table: district_geography_issues
CREATE TABLE IF NOT EXISTS public.district_geography_issues (
    id              SERIAL PRIMARY KEY,
    geography_name  text NOT NULL,         -- "Cherokee County", "Outer Banks", "Research Triangle"
    region          text,                  -- mountain/piedmont/triad/charlotte/triangle/coastal_plain/sandhills/cape_fear/northeast
    county          text[],                -- array of counties in geography
    issue_tag       text REFERENCES public.issue_tags(tag),
    special_interests text,               -- key groups engaged on this issue here
    notes           text,
    is_permanent    boolean DEFAULT true,  -- true = geography-driven, false = temporary
    created_at      timestamptz DEFAULT NOW()
);

-- Junction: district_to_candidate
-- Links a legislative district to its geography issues
CREATE TABLE IF NOT EXISTS public.district_candidate_geography (
    candidate_id    bigint REFERENCES public.candidates(id),
    district_number text,
    chamber         text,   -- house/senate/federal
    geography_issues text[] -- array of issue_tags from district_geography_issues
);
```

### Query: "Which candidates represent districts with tribal gaming issues?"
```sql
SELECT c.norm_first, c.norm_last, c.current_office, dgi.geography_name, dgi.issue_tag
FROM public.candidates c
JOIN public.district_candidate_geography dcg ON dcg.candidate_id = c.id
JOIN public.district_geography_issues dgi ON dgi.issue_tag = ANY(dcg.geography_issues)
WHERE dgi.issue_tag = 'tribal_gaming'
ORDER BY c.norm_last;
```

---

*Prepared by Perplexity AI — March 31, 2026*
*Geography issues are permanent — they exist independent of officeholder*
*To be combined with candidate_issues for full political profile*
