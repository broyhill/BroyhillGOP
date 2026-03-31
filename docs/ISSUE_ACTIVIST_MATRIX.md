# BroyhillGOP — Conservative Issue × Activist Group × Office Type Matrix
## For: issue_tag system on committee_registry and candidates tables
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## DESIGN INTENT
Tag activist organizations AND candidates/officeholders to issues.
Enables: "Which donors care about school choice?" → find all committees + candidates tagged school_choice → find their donors.

---

## TOP 25 CONSERVATIVE ISSUES — RANKED BY OFFICE LEVEL RELEVANCE

| # | Issue | issue_tag | Federal | State | Judicial | County | School Board | Municipal |
|---|-------|-----------|---------|-------|----------|--------|--------------|-----------|
| 1 | School Choice / Vouchers | school_choice | ✅ Dept of Ed | ✅ PRIMARY | — | ✅ funding | ✅ PRIMARY | — |
| 2 | Border Security / Immigration | border_security | ✅ PRIMARY | ✅ enforcement | — | ✅ sanctuary | — | ✅ sanctuary |
| 3 | Second Amendment / Gun Rights | second_amendment | ✅ PRIMARY | ✅ concealed carry | ✅ cases | ✅ sheriff | — | — |
| 4 | Pro-Life / Abortion | pro_life | ✅ SCOTUS | ✅ PRIMARY | ✅ cases | — | — | — |
| 5 | Election Integrity / Voter ID | election_integrity | ✅ PRIMARY | ✅ PRIMARY | ✅ cases | ✅ BOE | — | ✅ BOE |
| 6 | Anti-DEI / Parental Rights | anti_dei | ✅ Dept of Ed | ✅ PRIMARY | — | — | ✅ PRIMARY | — |
| 7 | Tax Cuts / Fiscal Conservatism | fiscal_conservatism | ✅ PRIMARY | ✅ PRIMARY | — | ✅ property tax | ✅ budget | ✅ budget |
| 8 | Religious Liberty | religious_liberty | ✅ PRIMARY | ✅ PRIMARY | ✅ PRIMARY | — | ✅ prayer | — |
| 9 | Energy / Oppose Green New Deal | energy_freedom | ✅ PRIMARY | ✅ utilities | — | ✅ zoning | — | ✅ zoning |
| 10 | Crime / Public Safety / Bail Reform | public_safety | ✅ DOJ | ✅ PRIMARY | ✅ bail/DA | ✅ sheriff | — | ✅ police |
| 11 | Free Speech / Anti-Censorship | free_speech | ✅ PRIMARY | ✅ campus | ✅ cases | — | ✅ curriculum | — |
| 12 | Healthcare / Anti-Mandate | healthcare_freedom | ✅ ACA repeal | ✅ Medicaid | — | ✅ health dept | — | — |
| 13 | Property Rights / Anti-Zoning | property_rights | — | ✅ PRIMARY | ✅ cases | ✅ PRIMARY | — | ✅ PRIMARY |
| 14 | Parental Rights in Education | parental_rights | ✅ Dept of Ed | ✅ PRIMARY | — | — | ✅ PRIMARY | — |
| 15 | Anti-Transgender / Gender Ideology | gender_ideology | ✅ Title IX | ✅ PRIMARY | ✅ cases | — | ✅ bathrooms | — |
| 16 | Military / Veterans | military_veterans | ✅ PRIMARY | ✅ Guard/benefits | — | ✅ veterans svc | — | — |
| 17 | Judicial Originalism | judicial_originalism | ✅ SCOTUS/fed | ✅ PRIMARY | ✅ PRIMARY | — | — | — |
| 18 | Farming / Rural Economy | rural_economy | ✅ farm bill | ✅ ag policy | — | ✅ PRIMARY | — | — |
| 19 | Small Business / Anti-Regulation | small_business | ✅ PRIMARY | ✅ PRIMARY | — | ✅ licensing | — | ✅ licensing |
| 20 | Anti-CRT / Curriculum Reform | curriculum_reform | ✅ Dept of Ed | ✅ PRIMARY | — | — | ✅ PRIMARY | — |
| 21 | Infrastructure / Transportation | infrastructure | ✅ PRIMARY | ✅ PRIMARY | — | ✅ roads | — | ✅ roads |
| 22 | Housing Affordability (R version) | housing | — | ✅ zoning reform | — | ✅ PRIMARY | — | ✅ PRIMARY |
| 23 | Law Enforcement Support (Back the Blue) | back_the_blue | ✅ DOJ | ✅ PRIMARY | ✅ DA | ✅ sheriff | — | ✅ police chief |
| 24 | Anti-Socialism / Free Markets | free_markets | ✅ PRIMARY | ✅ PRIMARY | — | — | — | — |
| 25 | AI / Tech Freedom / Anti-Censorship | tech_freedom | ✅ PRIMARY | ✅ emerging | ✅ cases | — | — | — |

---

## ACTIVIST GROUPS MAPPED TO ISSUES

| Organization | Type | issue_tags | Office levels |
|-------------|------|-----------|---------------|
| **Club for Growth** | 501c4 + SuperPAC | fiscal_conservatism, free_markets, small_business | Federal, State |
| **Turning Point USA** | 501c3 | anti_dei, curriculum_reform, free_speech, parental_rights | State, School Board, College |
| **Turning Point Action** | 501c4 | election_integrity, anti_dei, border_security | Federal, State |
| **Americans for Prosperity** | 501c4 | fiscal_conservatism, energy_freedom, small_business, healthcare_freedom | Federal, State, County |
| **Heritage Action** | 501c4 | fiscal_conservatism, religious_liberty, judicial_originalism | Federal, State |
| **NRA / NRA-ILA** | 501c4 | second_amendment | Federal, State, County (sheriff) |
| **Susan B. Anthony Pro-Life America** | 501c4 | pro_life | Federal, State |
| **NC Values Coalition** | 501c4 | pro_life, religious_liberty, gender_ideology, parental_rights | State, School Board |
| **John Locke Foundation / Civitas** | 501c3/c4 | fiscal_conservatism, school_choice, property_rights, small_business | State, County, School Board |
| **Faith & Freedom Coalition** | 501c4 | religious_liberty, pro_life, election_integrity | Federal, State |
| **ALEC** | 501c4 | fiscal_conservatism, small_business, energy_freedom, school_choice | State |
| **Federalist Society** | 501c3 | judicial_originalism, religious_liberty, free_speech | Federal, State (judicial) |
| **NC Judicial Victory Fund** | NCGOP Auxiliary | judicial_originalism, pro_life, religious_liberty, second_amendment | State (judicial) |
| **NC GOP House Caucus** | NCGOP Auxiliary | ALL (legislative agenda) | State (House) |
| **NC GOP Senate Caucus** | NCGOP Auxiliary | ALL (legislative agenda) | State (Senate) |
| **Parents Defending Education** | 501c4 | parental_rights, anti_dei, curriculum_reform | School Board |
| **Moms for Liberty** | 501c4 | parental_rights, curriculum_reform, anti_dei | School Board, County |
| **Gun Owners of America** | 501c4 | second_amendment | Federal, State |
| **Tea Party Patriots** | 501c4 | fiscal_conservatism, healthcare_freedom, small_business | Federal, State, Local |
| **Senate Leadership Fund** | SuperPAC | ALL | Federal (Senate) |
| **Congressional Leadership Fund** | SuperPAC | ALL | Federal (House) |
| **NC Chamber PAC** | PAC | small_business, fiscal_conservatism, infrastructure | State, County |
| **NC Farm Bureau PAC** | PAC | rural_economy, property_rights, energy_freedom | State, County |
| **American Crossroads** | 501c4 + SuperPAC | ALL | Federal, State |

---

## DATABASE IMPLEMENTATION

### New table: issue_tags
```sql
CREATE TABLE IF NOT EXISTS public.issue_tags (
    id              SERIAL PRIMARY KEY,
    tag             text NOT NULL UNIQUE,   -- machine key e.g. 'school_choice'
    label           text NOT NULL,          -- display name e.g. 'School Choice / Vouchers'
    description     text,
    federal_relevant boolean DEFAULT false,
    state_relevant   boolean DEFAULT false,
    judicial_relevant boolean DEFAULT false,
    county_relevant  boolean DEFAULT false,
    school_board_relevant boolean DEFAULT false,
    municipal_relevant boolean DEFAULT false,
    created_at      timestamptz DEFAULT NOW()
);
```

### Junction table: committee_issues (committee → issue tags)
```sql
CREATE TABLE IF NOT EXISTS public.committee_issues (
    committee_id    text REFERENCES public.committee_registry(committee_id),
    issue_tag       text REFERENCES public.issue_tags(tag),
    relevance       text CHECK (relevance IN ('primary','secondary','opposed')),
    PRIMARY KEY (committee_id, issue_tag)
);
```

### Junction table: candidate_issues (candidate → issue tags)
```sql
CREATE TABLE IF NOT EXISTS public.candidate_issues (
    candidate_id    bigint REFERENCES public.candidates(id),
    issue_tag       text REFERENCES public.issue_tags(tag),
    relevance       text CHECK (relevance IN ('primary','secondary','opposed')),
    PRIMARY KEY (candidate_id, issue_tag)
);
```

### Query: "Find all donors who gave to school choice committees"
```sql
SELECT DISTINCT ps.person_id, ps.norm_first, ps.norm_last, ps.voter_rncid,
    SUM(cm.amount) as school_choice_total
FROM core.contribution_map cm
JOIN public.committee_issues ci ON ci.committee_id = cm.committee_id
JOIN public.issue_tags it ON it.tag = ci.issue_tag AND it.tag = 'school_choice'
JOIN core.person_spine ps ON ps.person_id = cm.person_id
GROUP BY ps.person_id, ps.norm_first, ps.norm_last, ps.voter_rncid
ORDER BY school_choice_total DESC;
```

---

*Prepared by Perplexity AI — March 31, 2026*
*Pending Eddie approval before Claude implements*
