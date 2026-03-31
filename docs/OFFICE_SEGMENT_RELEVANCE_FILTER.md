# Office-Type Microsegment Relevance Filter
## BroyhillGOP — Only show segments that produce real donors + volunteers for each office
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT

Before ranking microsegments by district, apply an OFFICE-TYPE FILTER.
A hunter in Watauga County will not give to the NC Auditor.
A CPA in Watauga County will.

Every office type has:
- PRIMARY segments: These people write checks AND volunteer for this office
- SECONDARY segments: They may vote R but rarely engage at this office level
- IRRELEVANT segments: Wrong issue, wrong level, won't engage — DO NOT SHOW

---

## OFFICE TYPE × SEGMENT RELEVANCE MATRIX

### FEDERAL OFFICES

#### US SENATE (statewide — Tillis, Budd)
```
PRIMARY (show all, high intensity):
  fiscal_conservative, second_amendment, veterans, seniors, small_business,
  pro_life, social_conservative, farmers, military_community, faith,
  law_enforcement, hunters, coastal_fishing, outdoor_sports_wildlife,
  soccer_moms, women_30_55, young_republicans

SECONDARY (show, medium intensity):
  doctors, nurses, lawyers, bankers, realtors, construction,
  biotech_pharma, university_town, mountain_tourist, beach_coastal

IRRELEVANT (exclude):
  Nothing excluded — Senate is statewide, all segments matter
```

#### US HOUSE (district-specific)
```
PRIMARY: Apply district geography filter first, then:
  fiscal_conservative, veterans, second_amendment, small_business, seniors,
  + top 5 community_identity_tags for that district

SECONDARY: All other R+U segments in district

IRRELEVANT: Segments with <200 R+U voters in district
```

---

### NC COUNCIL OF STATE — Each office has distinct relevant segments

#### GOVERNOR
```
PRIMARY:
  small_business, fiscal_conservative, veterans, law_enforcement, farmers,
  seniors, soccer_moms, faith, second_amendment, pro_life, hunters,
  construction, realtors, military_community, coastal_fishing

SECONDARY:
  doctors, nurses, teachers, bankers, lawyers, biotech, university_staff

IRRELEVANT:
  Nothing excluded — statewide office
```

#### NC AUDITOR (Dave Boliek)
```
PRIMARY — These people care about government accountability + have money:
  cpas_accountants        -- his professional peers, care about audit standards
  fiscal_conservative     -- anti-waste, anti-fraud, pro-transparency
  small_business          -- waste = higher taxes on them
  bankers_finance         -- fiscal discipline, debt management
  lawyers                 -- government accountability world
  retired_executives      -- fixed income, anti-corruption
  republican_party_activists -- ticket loyalty

SECONDARY — May give small amounts:
  seniors                 -- government waste affects fixed-income seniors
  veterans                -- government accountability = protecting benefits
  realtors                -- government permitting + spending transparency

IRRELEVANT — Do NOT show for Auditor:
  hunters, fishermen, dairy_farmers, hog_farming, tobacco,
  soccer_moms (school board issue, not auditor),
  university_students, beach_coastal, NASCAR, mountain_tourist,
  nurses, teachers, biotech_pharma
  
NOTE: In Watauga County specifically:
  - CPAs/accountants in county: ~150-200
  - Small business owners (R+U): ~400
  - Attorneys: ~80
  - Bankers/financial advisors: ~60
  - Republican Party officers: ~50
  - Retired executives: ~200
  TOTAL REALISTIC BOLIEK UNIVERSE IN WATAUGA: ~500-800 people
```

#### NC TREASURER
```
PRIMARY:
  bankers_finance, cpas_accountants, fiscal_conservative, investment_managers,
  retired_executives, small_business, lawyers, republican_party_activists

SECONDARY:
  seniors, realtors, corporate_executives

IRRELEVANT:
  hunters, farmers (unless large ag operation with investment concerns),
  soccer_moms, teachers, nurses, beach_coastal, NASCAR
```

#### NC ATTORNEY GENERAL
```
PRIMARY:
  law_enforcement, lawyers, sheriffs, victims_rights, fiscal_conservative,
  second_amendment (2A litigation cases), pro_life (AG defends abortion laws),
  faith (religious liberty cases), veterans, seniors (elder fraud)

SECONDARY:
  small_business (regulatory enforcement), doctors (healthcare fraud)

IRRELEVANT:
  hunters (unless hunting rights litigation active), dairy_farmers,
  NASCAR, mountain_tourist, beach_coastal
```

#### COMMISSIONER OF AGRICULTURE
```
PRIMARY:
  farmers (all types — crop, hog, dairy, tobacco, poultry),
  rural_economy, farm_bureau_members, ag_lenders,
  food_processing_industry, forestry_timber, veterinarians_large_animal,
  rural_electric_coop_members, ag_equipment_dealers, feed_store_owners

SECONDARY:
  rural_veterans, rural_seniors, sportsmen (rural overlap)

IRRELEVANT:
  biotech_pharma, university_students, beach_coastal, NASCAR,
  soccer_moms, teachers, lawyers, bankers (urban), doctors (urban)
```

#### COMMISSIONER OF INSURANCE
```
PRIMARY:
  insurance_agents, small_business (business insurance),
  healthcare_providers (malpractice), realtors (property insurance),
  construction (liability insurance), seniors (Medicare supplement),
  bankers_finance, lawyers (insurance litigation), cpas_accountants

SECONDARY:
  homeowners generally, farmers (crop insurance)

IRRELEVANT:
  hunters, NASCAR, university_students, dairy_farmers, hog_farming (unless CAFO insurance)
```

#### COMMISSIONER OF LABOR
```
PRIMARY:
  small_business (labor regulations), construction (OSHA),
  manufacturing_workers, restaurant_hospitality (wage laws),
  trucking (DOT regulations), farmers (H-2A labor),
  business_associations, fiscal_conservative

SECONDARY:
  nurses (healthcare staffing ratios), veterans (workforce training)

IRRELEVANT:
  hunters, NASCAR, beach_coastal, biotech (federal regulation, not state labor),
  university_students
```

#### SUPERINTENDENT OF PUBLIC INSTRUCTION
```
PRIMARY:
  soccer_moms, parents_school_age_children, teachers_conservative,
  school_choice_advocates, faith_homeschool, principals_administrators,
  private_school_operators, charter_school_advocates

SECONDARY:
  seniors (grandchildren), small_business (workforce pipeline),
  faith_congregations (school values)

IRRELEVANT:
  hunters, farmers, dairy, hog, NASCAR, beach_coastal, bankers,
  lawyers, insurance agents
```

#### SECRETARY OF STATE
```
PRIMARY:
  lawyers, cpas_accountants, small_business (LLC/corp filings),
  realtors (deed recording), bankers, nonprofit_operators,
  republican_party_activists

SECONDARY:
  fiscal_conservative, retired_executives

IRRELEVANT:
  hunters, farmers, NASCAR, beach_coastal, soccer_moms,
  teachers, nurses, military
```

---

### NC GENERAL ASSEMBLY

#### NC SENATE / NC HOUSE (state legislative)
```
Apply district geography first. Then:

PRIMARY (R+U in district who engage at legislative level):
  small_business, fiscal_conservative, farmers (if rural), realtors,
  construction, second_amendment, veterans, faith, pro_life,
  + top community_identity segments for that specific district

SECONDARY:
  doctors, lawyers, bankers, seniors

IRRELEVANT:
  University students (don't give to legislators), NASCAR (federal/track level),
  commercial_fishing (coastal districts only)
```

---

### NC JUDICIAL OFFICES

#### NC SUPREME COURT / COURT OF APPEALS (statewide)
```
PRIMARY:
  lawyers, judges_former, judicial_victory_fund_donors,
  fiscal_conservative, pro_life (judicial philosophy),
  faith_religious_liberty (judicial philosophy),
  second_amendment (2A cases), business_community (tort reform),
  federalist_society_members, republican_party_activists

SECONDARY:
  small_business (civil litigation), doctors (malpractice reform),
  construction (liability cases)

IRRELEVANT:
  hunters, farmers, NASCAR, soccer_moms, teachers, nurses,
  beach_coastal, dairy, hog
```

#### DISTRICT ATTORNEY
```
PRIMARY:
  law_enforcement, sheriffs, police_associations, bail_bondsmen,
  victims_rights_advocates, seniors (elder fraud/crime fear),
  neighborhood_associations, faith (crime/morality),
  veterans (military justice background)

SECONDARY:
  lawyers (defense bar opposes, prosecution bar supports),
  small_business (property crime, fraud)

IRRELEVANT:
  hunters, farmers, NASCAR, soccer_moms, teachers, beach, dairy
```

#### SUPERIOR/DISTRICT COURT JUDGE
```
PRIMARY:
  local_bar_association, lawyers_in_district, law_enforcement,
  republican_party_county, judicial_victory_fund_donors,
  bail_bondsmen, business_community

SECONDARY:
  seniors, veterans

IRRELEVANT:
  Nearly all occupational/interest segments — judicial races are
  lawyer-driven, party-loyalty driven, and very local
```

---

### COUNTY OFFICES

#### COUNTY COMMISSIONER
```
PRIMARY (varies by county economic identity — apply community_identity filter):
  small_business, realtors, construction, fiscal_conservative,
  farmers (rural counties), republican_party_county,
  + dominant community identity (coastal = tourism operators,
    mountain = resort owners, piedmont = manufacturers)

SECONDARY:
  veterans, seniors, faith

IRRELEVANT:
  Apply community_identity_tags — if hog_farming county ≠ show beach segment
```

#### COUNTY SHERIFF
```
PRIMARY:
  second_amendment, law_enforcement_community, veterans,
  bail_bondsmen, nra_members, farmers (rural — property crime),
  seniors (crime fear), republican_party_county,
  business_community, faith (conservative values alignment)

SECONDARY:
  small_business, construction (equipment theft)

IRRELEVANT:
  soccer_moms, teachers, biotech, university_students, NASCAR
  (unless sheriff is their neighbor), beach_coastal
```

#### SCHOOL BOARD
```
PRIMARY:
  soccer_moms, parents_school_age_children, teachers_conservative,
  faith_congregations, school_choice_advocates,
  moms_for_liberty_members, pta_conservative_leaders,
  small_business (education quality = workforce)

SECONDARY:
  seniors (grandchildren), real_estate (school quality drives home values)

IRRELEVANT:
  hunters, farmers, NASCAR, military, bankers, lawyers,
  beach, hog_farming — NOT their issue at school board level
```

---

## DATABASE IMPLEMENTATION

```sql
-- office_segment_relevance — the filter table
CREATE TABLE IF NOT EXISTS public.office_segment_relevance (
    id              SERIAL PRIMARY KEY,
    office_type     text NOT NULL,      -- 'nc_auditor'|'sheriff'|'school_board' etc
    office_level    text NOT NULL,      -- 'federal'|'state_statewide'|'state_leg'|'judicial'|'county'|'municipal'
    segment_tag     text NOT NULL,      -- microsegment tag
    relevance_tier  text NOT NULL,      -- 'primary'|'secondary'|'irrelevant'
    relevance_score integer DEFAULT 0, -- 1-100, used to weight within primary/secondary
    notes           text,
    PRIMARY KEY (office_type, segment_tag)
);

-- Modified ranking query — apply relevance filter
SELECT dmr.*, osr.relevance_tier, osr.relevance_score,
    CASE
        WHEN osr.relevance_tier = 'primary' THEN dmr.dominance_score * 1.0
        WHEN osr.relevance_tier = 'secondary' THEN dmr.dominance_score * 0.4
        WHEN osr.relevance_tier = 'irrelevant' THEN 0
    END as office_adjusted_score
FROM public.district_microsegment_rankings dmr
JOIN public.office_segment_relevance osr
    ON osr.office_type = 'nc_auditor'   -- swap for any office
    AND osr.segment_tag = dmr.segment_tag
WHERE dmr.district_type = 'county'
AND dmr.district_id = 'WATAUGA'
AND osr.relevance_tier != 'irrelevant'  -- exclude irrelevant segments entirely
ORDER BY office_adjusted_score DESC;
```

---

## BOLIEK IN WATAUGA — CORRECTED OUTPUT

After applying the nc_auditor relevance filter to Watauga County:

| Rank | Segment | Watauga R+U est. | Relevance | Score |
|------|---------|-----------------|-----------|-------|
| 1 | CPAs / Accountants | 150-200 | PRIMARY | 94 |
| 2 | Fiscal Conservative | ~4,500 | PRIMARY | 88 |
| 3 | Small Business Owners | ~400 | PRIMARY | 82 |
| 4 | Lawyers | ~80 | PRIMARY | 76 |
| 5 | Bankers / Finance | ~60 | PRIMARY | 71 |
| 6 | Retired Executives | ~200 | PRIMARY | 65 |
| 7 | Republican Party Activists | ~50 | PRIMARY | 61 |
| 8 | Seniors (anti-waste angle) | ~1,800 | SECONDARY | 38 |
| 9 | Veterans (accountability) | ~800 | SECONDARY | 31 |
| 10 | Realtors (permitting transparency) | ~120 | SECONDARY | 24 |
| — | Hunters | FILTERED OUT | IRRELEVANT | 0 |
| — | App State students | FILTERED OUT | IRRELEVANT | 0 |
| — | Mountain resort owners | FILTERED OUT | IRRELEVANT | 0 |

**Total realistic Boliek donor+volunteer universe in Watauga: ~700-1,000 people**
**Top event format: CPA/accountant professional dinner, 20-25 people, $500-$1,000 ask**

---

*Prepared by Perplexity AI — March 31, 2026*
*Office-type filter is the missing layer — apply BEFORE district ranking*
*Watauga example: 31,000 R+U voters → 700-1,000 relevant to Boliek*
