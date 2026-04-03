# BroyhillGOP — Complete Committee & Organization Taxonomy
## For: committee_registry.committee_category classification
## Date: March 31, 2026
## Authority: Ed Broyhill

---

## TIER 1 — OFFICIAL NCGOP PARTY COMMITTEES
*Regulated by NCSBOE. Coordinated activity with candidates allowed.*

- NCGOP (state central committee)
- NCGOP Federal Account (separate FEC account — C00038505)
- 100 NC County Republican Parties (each files separately)

**committee_category = 'OFFICIAL_STATE_PARTY'**

---

## TIER 2 — NCGOP AUXILIARY FUNDS
*Controlled by or formally affiliated with NCGOP. Separate treasuries but party-directed.*

- NC GOP House Caucus
- NC GOP Senate Caucus
- NC Judicial Victory Fund (est. 2019 — elects conservative judges statewide)
- NC GOP Council of State Fund (Treasurer, AG, Auditor, Lt. Gov, etc.)
- NC GOP Executive Committee Fund
- NC Republican Congressional Delegation Fund

**committee_category = 'NCGOP_AUXILIARY'**

---

## TIER 3 — NCGOP AFFILIATE ORGANIZATIONS
*Independent treasury, not controlled by NCGOP, but officially GOP-aligned.*

- NC Federation of Republican Women (NCFRW)
- NC Young Republicans (NCYR)
- Teen Age Republicans (TARS)
- College Republicans of NC
- NC Republican Men's Clubs (county chapters)
- NC Hispanic Republicans
- NC Black Republican Council
- NC Asian American Republicans

**committee_category = 'GOP_AFFILIATE_ORG'**

---

## TIER 4 — CANDIDATE COMMITTEES
*"Smith for NC Senate", "Jones for Congress" — direct candidate campaign accounts.*
*Links to candidates table via candidate_id.*

- State legislative candidates (NC House, NC Senate)
- Statewide candidates (Governor, AG, Treasurer, Auditor, Lt. Gov, SOS, Supt, Comm of Agriculture, Comm of Insurance, Comm of Labor)
- Federal candidates (US House, US Senate, President)
- Judicial candidates (Supreme Court, Court of Appeals, Superior Court, District Court)
- Local candidates (County Commissioner, Sheriff, School Board, etc.)

**committee_category = 'CANDIDATE_COMMITTEE'**
**+ office_level = 'federal' | 'state' | 'judicial' | 'local'**

---

## TIER 5 — NATIONAL CONSERVATIVE ORGS (501c3 / 501c4 / PAC)
*National groups active in NC. Mix of 501c3, 501c4, and PAC structures.*

### 501(c)(4) Issue Advocacy / Dark Money
- Club for Growth (federal SuperPAC + c4) — fiscal conservatism, primary challengers
- Turning Point Action (c4) — Charlie Kirk, GOTV, campus organizing
- Americans for Prosperity (c4) — Koch network, free market
- Heritage Action for America (c4) — Heritage Foundation arm
- Freedom Works (c4) — grassroots conservative
- Susan B. Anthony Pro-Life America (c4) — pro-life
- National Rifle Association Institute for Legislative Action (NRA-ILA, c4)
- American Legislative Exchange Council (ALEC) — state legislature focus
- Faith & Freedom Coalition (c4) — Ralph Reed, evangelical voters

### 501(c)(3) Education / Research (cannot endorse candidates)
- Turning Point USA (c3) — campus organizing
- Heritage Foundation (c3) — policy research
- NC State Policy Network affiliates — Civitas Institute / John Locke Foundation (NC-specific)
- Federalist Society — judicial conservatism

### Super PACs (Independent Expenditure Only)
- Club for Growth PAC
- Senate Leadership Fund (McConnell-aligned)
- Congressional Leadership Fund (House R)
- American Crossroads (Karl Rove)

**committee_category = 'NATIONAL_CONSERVATIVE_ORG'**
**+ nonprofit_type = '501c3' | '501c4' | 'super_pac' | 'pac'**

---

## TIER 6 — NC STATE CONSERVATIVE ORGS
*NC-specific issue orgs, think tanks, and advocacy groups.*

- John Locke Foundation / Civitas Institute (c3/c4) — NC free market think tank
- NC Values Coalition (c4) — social conservative, religious freedom
- NC Chamber of Commerce PAC — business/economic
- NC Homebuilders PAC
- NC Farm Bureau PAC
- NC Medical Society PAC
- NC Realtors PAC
- NC Bankers PAC
- NC Restaurant & Lodging PAC
- NC Truckers PAC
- NC Sheriff's Association PAC

**committee_category = 'NC_CONSERVATIVE_ORG'**

---

## TIER 7 — CORPORATE / TRADE / INDUSTRY PACs
*Non-party political committees — business PACs donating to R candidates.*

- Non-Party Comm (NCSBOE designation)
- Corporate PACs (WellCare, BB&T, Progress Energy, etc.)
- Trade association PACs
- Professional association PACs

**committee_category = 'CORPORATE_PAC'**

---

## TIER 8 — PASS-THROUGHS (NOT DONORS)
*Committee-to-committee money transfers. Not donors — just money moving between treasuries.*

- Cont to Other Comm (NCSBOE designation)
- Coordinated Party Expenditures

**committee_category = 'COMMITTEE_TRANSFER'**
*Do NOT include in donor totals or donor spine*

---

## DATABASE IMPLEMENTATION

### Add to committee_registry:
```sql
ALTER TABLE public.committee_registry
  ADD COLUMN IF NOT EXISTS committee_category text,
  ADD COLUMN IF NOT EXISTS office_level text,        -- federal/state/judicial/local (Tier 4 only)
  ADD COLUMN IF NOT EXISTS nonprofit_type text,      -- 501c3/501c4/super_pac/pac (Tier 5 only)
  ADD COLUMN IF NOT EXISTS is_gop_aligned boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_official_party boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS tier integer,             -- 1-8 per above
  ADD COLUMN IF NOT EXISTS national_org_name text,   -- parent org name if branch/chapter
  ADD COLUMN IF NOT EXISTS fec_committee_id text,    -- link to fec_committees
  ADD COLUMN IF NOT EXISTS sboe_committee_id text;   -- link to NC SBOE

CREATE INDEX IF NOT EXISTS idx_committee_registry_category
  ON public.committee_registry (committee_category);
CREATE INDEX IF NOT EXISTS idx_committee_registry_tier
  ON public.committee_registry (tier);
```

### Classification priority order:
1. Match on known NCGOP auxiliary fund names → Tier 2
2. Match on known affiliate org names → Tier 3
3. Match on "FOR [OFFICE]" pattern → Tier 4 (candidate committee)
4. Match on known national org names → Tier 5
5. Match on known NC org names → Tier 6
6. Non-Party Comm with corporate name → Tier 7
7. Cont to Other Comm → Tier 8
8. Unclassified → NULL (review queue)

---

*Prepared by Perplexity AI — March 31, 2026*
*For implementation by Claude on committee_registry table*

---

## PARTISAN LEAN FLAG — partisan_lean column

Every committee in committee_registry gets tagged:

| Value | Meaning |
|-------|---------|
| `R` | Gives predominantly to Republicans (>70% of donations) |
| `D` | Gives predominantly to Democrats (>70% of donations) |
| `N` | Neutral — gives to both parties (trade assocs, some industry PACs) |
| `U` | Unknown — insufficient data to classify yet |

### Add to committee_registry:
```sql
ALTER TABLE public.committee_registry
  ADD COLUMN IF NOT EXISTS partisan_lean char(1)
    CHECK (partisan_lean IN ('R','D','N','U'))
    DEFAULT 'U';

CREATE INDEX IF NOT EXISTS idx_committee_registry_partisan
  ON public.committee_registry (partisan_lean);
```

### Known partisan leans for major NC PACs:

#### Reliably R
- NC Chamber of Commerce PAC → R
- NC Home Builders PAC → R
- NC Farm Bureau PAC → R (historically R lean)
- NC Restaurant & Lodging PAC → R
- NC Truckers PAC → R
- NC Bankers PAC → N (gives both but leans R)
- NC Association of Realtors PAC → N (gives both)
- NC Medical Society PAC → N (gives both)
- NC Dental Society PAC → N (gives both)
- Club for Growth PAC → R
- NCGOP House Caucus → R
- NCGOP Senate Caucus → R
- NC Judicial Victory Fund → R
- All NCGOP auxiliary funds → R
- All county Republican parties → R
- NRA-PVF → R
- NC Values Coalition → R
- Ducks Unlimited PAC → R lean
- Sportsmen's Alliance → R lean

#### Reliably D
- NC Association of Educators PAC (NCAE) → D
- NC AFL-CIO → D
- NC Justice Center → D
- Planned Parenthood NC PAC → D
- Sierra Club NC PAC → D
- Trial Lawyers PAC → D
- SEIU NC → D
- NC Nurses Association → D lean

#### Neutral (N) — gives to both, follow the majority
- NC Association of Realtors PAC → N (tracks majority party in power)
- NC Medical Society PAC → N
- NC Dental Society PAC → N
- NC Hospital Association PAC → N
- NC Bankers Association PAC → N
- NC Bar Association → N
- Duke Energy PAC → N
- Dominion Energy PAC → N
- AT&T PAC → N
- Spectrum/Charter PAC → N
- Retail Merchants Association → N

### Calculation method (automated):
```sql
-- Auto-classify based on actual SBOE giving patterns
-- Run after committee_issues and contribution_map are fully populated
UPDATE public.committee_registry cr
SET partisan_lean = CASE
  WHEN r_pct >= 0.70 THEN 'R'
  WHEN d_pct >= 0.70 THEN 'D'
  WHEN r_pct BETWEEN 0.30 AND 0.70 THEN 'N'
  ELSE 'U'
END
FROM (
  SELECT
    cm.committee_id,
    ROUND(SUM(CASE WHEN c.party = 'R' THEN cm.amount ELSE 0 END) /
      NULLIF(SUM(cm.amount),0), 2) AS r_pct,
    ROUND(SUM(CASE WHEN c.party = 'D' THEN cm.amount ELSE 0 END) /
      NULLIF(SUM(cm.amount),0), 2) AS d_pct
  FROM core.contribution_map cm
  JOIN public.candidates c ON c.id = cm.candidate_id
  WHERE cm.committee_id IS NOT NULL
  GROUP BY cm.committee_id
  HAVING SUM(cm.amount) > 5000  -- min threshold for classification
) stats
WHERE cr.committee_id = stats.committee_id;
```

