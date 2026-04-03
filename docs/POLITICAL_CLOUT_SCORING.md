# Political Clout Scoring System
## BroyhillGOP — Quantifying Special Interest Power
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT
Every special interest needs:
1. A quantified CLOUT_SCORE based on 12 measurable dimensions
2. A roster of the actual humans who run it — officers, decision-makers, top donors
3. Bios on those humans — because relationships are built with people, not organizations

---

## THE 12 CLOUT DIMENSIONS

Each scored 1-10. Weighted composite = CLOUT_SCORE (0-100)

| # | Dimension | Weight | What it measures | Data source |
|---|-----------|--------|-----------------|-------------|
| D1 | **Total Political Donations** | 20% | Actual $ given to NC candidates (SBOE + FEC) | SBOE/FEC bulk data |
| D2 | **Lobbying Spend** | 15% | $ spent on NCGA lobbying per year | NC SOS lobbyist registry |
| D3 | **Membership / Constituency Size** | 10% | # of voters/members this group represents | Org reports, census |
| D4 | **Voter Turnout Rate** | 8% | How reliably members actually vote | SBOE voter history |
| D5 | **Media / Earned Media Influence** | 7% | Press coverage, social following, editorial relationships | E42 news tracking |
| D6 | **Organized Infrastructure** | 7% | Full-time staff, chapters, PAC apparatus, email list | Manual + 990s |
| D7 | **Issue Salience** | 5% | Single-issue intensity vs multi-issue diffusion | Primary voting patterns |
| D8 | **Geographic Concentration** | 3% | Concentrated in specific districts vs diffuse statewide | SBOE donor zip analysis |
| D9 | **Grants Received (Federal + State)** | 8% | Annual govt grants flowing to sector — dependency = intensity | USASpending.gov, NC budget |
| D10 | **Charitable / Nonprofit Donations Raised** | 5% | Annual fundraising — reflects public support + donor network | IRS Form 990 |
| D11 | **Economic Force / GDP Contribution** | 8% | Total economic output of industry in NC | BEA, NC Commerce |
| D12 | **Employment Base** | 4% | # of NC jobs in sector — job creators get legislators' ears | BLS, NC Labor stats |

**CLOUT_SCORE = D1(0.20) + D2(0.15) + D3(0.10) + D4(0.08) + D5(0.07) + D6(0.07) + D7(0.05) + D8(0.03) + D9(0.08) + D10(0.05) + D11(0.08) + D12(0.04)**
*Weights sum to 1.00. Each dimension scored 1-10. Multiply sum × 10 = CLOUT_SCORE 0-100.*

---

## DIMENSION SCORING SCALES

### D1 — Political Donations
| Score | NC SBOE + FEC giving |
|-------|---------------------|
| 10 | >$5M/cycle |
| 8 | $1M-$5M/cycle |
| 6 | $250K-$1M/cycle |
| 4 | $50K-$250K/cycle |
| 2 | $10K-$50K/cycle |
| 1 | <$10K/cycle |

### D9 — Grants Received
| Score | Annual federal + state grants to NC |
|-------|-------------------------------------|
| 10 | >$500M/year |
| 8 | $100M-$500M/year |
| 6 | $10M-$100M/year |
| 4 | $1M-$10M/year |
| 2 | $100K-$1M/year |
| 1 | <$100K or zero |

*Grant dependency amplifies political intensity — orgs fighting to protect grants are the most aggressive lobbyists*

### D10 — Charitable Fundraising (990 revenue)
| Score | Annual charitable/dues/donations raised |
|-------|----------------------------------------|
| 10 | >$50M/year |
| 8 | $10M-$50M/year |
| 6 | $1M-$10M/year |
| 4 | $100K-$1M/year |
| 2 | <$100K/year |

### D11 — Economic Force (NC GDP)
| Score | Annual NC GDP contribution |
|-------|--------------------------|
| 10 | >$20B/year |
| 8 | $5B-$20B/year |
| 6 | $1B-$5B/year |
| 4 | $100M-$1B/year |
| 2 | $10M-$100M/year |
| 1 | <$10M/year |

### D12 — Employment Base
| Score | NC workers employed |
|-------|-------------------|
| 10 | >200,000 |
| 8 | 100K-200K |
| 6 | 50K-100K |
| 4 | 10K-50K |
| 2 | 1K-10K |
| 1 | <1,000 |

---

## KNOWN NC ECONOMIC BENCHMARKS

| Sector | NC GDP | NC Jobs | Grants/year | D11 | D12 |
|--------|--------|---------|------------|-----|-----|
| Healthcare / hospitals | $60B | 550K | $4B (Medicaid match) | 10 | 10 |
| Financial services | $45B | 150K | minimal | 10 | 8 |
| Defense / military | $20B | 100K | $6B (Fort Liberty alone) | 10 | 8 |
| Agriculture / food | $18B | 250K | $800M (USDA) | 10 | 10 |
| Manufacturing | $100B | 460K | moderate | 10 | 10 |
| Tourism / hospitality | $28B | 400K | moderate | 10 | 10 |
| Technology / RTP | $30B | 180K | $1B+ (NIH/NSF/DOE) | 10 | 8 |
| Construction | $15B | 210K | moderate | 8 | 10 |
| Hog farming / pork | $4B | 35K | $200M (USDA) | 7 | 4 |
| Cherokee Casino (EBCI) | $1.5B | 8K | zero (tribal) | 7 | 2 |
| NASCAR / motorsports | $5B Carolinas | 40K | minimal | 7 | 4 |
| Tobacco farming | $900M declining | 15K | $100M (USDA) | 5 | 4 |
| Commercial fishing | $600M | 12K | $10M (NOAA) | 5 | 4 |
| Recreational hunting/fishing | $2.5B | 25K | $50M (P-R/D-J) | 6 | 4 |
| Film industry (Wilmington) | $500M | 5K | $30M (incentives) | 4 | 2 |
| Arts / creative economy | $3B | 60K | $50M (arts council) | 6 | 6 |

---

## PART 2: THE HUMAN LAYER
## Officers, Decision-Makers & Top Donors — Profile Fields

*The clout score tells you the organization's power.*
*The human layer tells you WHO to cultivate a relationship with.*

---

### interest_group_people table — fields for each person

```sql
CREATE TABLE IF NOT EXISTS public.interest_group_people (
    id                  SERIAL PRIMARY KEY,
    -- Identity
    first_name          text NOT NULL,
    last_name           text NOT NULL,
    middle_name         text,
    suffix              text,
    preferred_name      text,           -- "goes by Jim"
    norm_first          text,           -- normalized for matching
    norm_last           text,

    -- Role at organization
    org_name            text,           -- which special interest / PAC / org
    org_id              integer,        -- FK to committee_registry or community_profiles
    role_title          text,           -- "President", "Executive Director", "Treasurer", "Board Chair"
    role_type           text,           -- 'officer' | 'board' | 'major_donor' | 'lobbyist' | 'staff'
    role_start_date     date,
    role_end_date       date,
    is_current          boolean DEFAULT true,

    -- Bio
    date_of_birth       date,
    age                 integer,        -- computed
    hometown            text,
    current_city        text,
    current_county      text,
    education           jsonb,          -- [{school, degree, year}]
    occupation          text,           -- day job if volunteer officer
    employer            text,
    employer_industry   text,
    military_service    text,
    religion            text,
    family_status       text,           -- married, children etc
    bio_summary         text,           -- 2-3 sentence AI-generated bio

    -- Political profile
    party_registration  text,           -- R / D / U
    voter_ncid          text,           -- link to nc_voters
    voter_rncid         text,           -- link to nc_datatrust
    known_political_views text,         -- brief characterization
    elected_offices_held text[],        -- prior or current offices

    -- Donation history
    total_donated_sboe  numeric,        -- total to NC candidates (from SBOE data)
    total_donated_fec   numeric,        -- total to federal candidates (from FEC data)
    total_donated_all   numeric,        -- combined
    top_recipient_1     text,           -- candidate name
    top_recipient_2     text,
    top_recipient_3     text,
    donor_since_year    integer,        -- first donation year
    last_donation_year  integer,

    -- Charitable giving
    total_charitable    numeric,        -- known charitable donations
    top_charity_1       text,
    top_charity_2       text,
    top_charity_3       text,

    -- Contact & social
    email               text,
    phone               text,
    linkedin_url        text,
    twitter_url         text,
    facebook_url        text,
    website_url         text,
    address_line1       text,
    city                text,
    zip5                text,

    -- Intelligence
    known_relationships text[],         -- other key people they know
    known_issues        text[],         -- issue_tags they personally care about
    influence_network   text,           -- brief description of their network
    talking_points      text,           -- what motivates this person
    approach_notes      text,           -- how to cultivate this relationship
    last_contact_date   date,
    contact_rating      text,           -- 'A' 'B' 'C' 'D' — quality of relationship

    -- Spine linkage
    person_spine_id     bigint,         -- FK to core.person_spine if donor
    contact_id          bigint,         -- FK to contacts table

    created_at          timestamptz DEFAULT NOW(),
    updated_at          timestamptz DEFAULT NOW()
);
```

---

## WHAT A COMPLETE INTEREST GROUP PROFILE LOOKS LIKE

### Example: NC Farm Bureau — Full Intelligence Profile

**ORGANIZATION PROFILE**
- Name: NC Farm Bureau Federation
- Type: Agriculture membership association + PAC
- Partisan lean: R
- Members: 525,000 member families (largest org in NC)
- Annual PAC giving: ~$800K/cycle to NC candidates
- Lobbying spend: ~$1.2M/year at NCGA
- Annual budget: ~$500M (insurance arm dominant)
- NC GDP contribution: $18B agriculture sector
- NC jobs: 250,000+
- Federal grants: $800M+ USDA commodity programs
- 990 revenue: $450M+
- **CLOUT_SCORE: 88**

**OFFICERS & DECISION-MAKERS**
| Name | Title | County | Donor? | Notes |
|------|-------|--------|--------|-------|
| Shawn Harding | President/CEO | Statewide | Yes | Day-to-day leader |
| Lacy Upchurch (past pres) | Past President | Johnston | Yes | Major donor network |
| County Farm Bureau Presidents (100) | County chairs | Each county | Yes | Local mobilizers |
| PAC Treasurer | PAC Treasurer | Raleigh | Yes | Controls donation decisions |

**TOP INDIVIDUAL DONORS TO CANDIDATES** (from SBOE data)
- Pull from nc_boe_donations_raw WHERE employer ILIKE '%farm bureau%'
- Cross-reference with interest_group_people

**ISSUE TAGS**
- crop_agriculture (primary)
- rural_economy
- property_rights
- rural_broadband
- water_quality
- hog_farming_cafo (overlaps)
- tobacco_farming (overlaps)

**GEOGRAPHIC CONCENTRATION**
- D8 score: 8 — concentrated in 60+ rural counties
- Highest clout: Johnston, Sampson, Duplin, Wayne, Harnett, Wilson, Nash, Pitt

---

## PROFILE PAGE LAYOUT FOR INTEREST GROUP OFFICER

```
[PHOTO]  [NAME + TITLE + ORG BADGE]
         [Party: R] [County: Johnston] [Voter: ACTIVE]

TABS:
├── BIO          — age, education, occupation, family, background
├── DONATIONS    — total given, top recipients, timeline chart, R/D split
├── CHARITABLE   — known charitable giving, which causes
├── ROLES        — all orgs this person leads/serves on boards
├── ISSUES       — personal issue tags, what they care about
├── NETWORK      — known connections to other key people
├── CONTACT      — email, phone, social, address
└── INTELLIGENCE — talking points, approach notes, relationship rating
```

---

## DATA POPULATION STRATEGY

### Automated (from existing DB)
- Donation history → from nc_boe_donations_raw + fec_donations
  - Match on name + employer + zip
- Voter registration → from nc_voters via voter_ncid
- DataTrust enrichment → from nc_datatrust via voter_rncid
  - Gets: phone, address, party, demographics, modeled scores

### Semi-automated (from public sources)
- 990 data → ProPublica Nonprofit Explorer API
- Lobbying registrations → NC SOS lobbyist registry (public)
- NCGA committee assignments → ncleg.gov
- FEC officer filings → FEC bulk data (treasurer names)
- LinkedIn → public profile scraping
- News mentions → E42 News Intelligence engine

### Manual (relationship intelligence)
- Talking points, approach notes, relationship rating
- Known relationships between people
- Charitable giving not in public records
- Personal issue priorities

---

## PRIORITY PEOPLE TO PROFILE FIRST

### Tier 1 — Profile immediately (highest clout orgs, known major donors)
1. NC Farm Bureau President + top county chairs
2. NC Chamber President/CEO + board chairs
3. NC Home Builders President + top regional directors
4. NC Realtors President + PAC committee
5. NRA NC state director + liaison to NC legislators
6. EBCI Tribal Council members + Principal Chief
7. Lumbee Tribe Chairman + federal recognition lobbyists
8. NC Hospital Association President + board
9. NC Medical Society President + PAC committee
10. NC Values Coalition President + board

### Tier 2 — Profile within 30 days
- All 30 NC Senate Republican chiefs of staff
- All major PAC treasurers (their name is on the SBOE filings)
- Top 50 individual donors by total SBOE giving (pull from our data)
- All registered NCGA lobbyists for R-aligned orgs

---

*Prepared by Perplexity AI — March 31, 2026*
*12 clout dimensions + full human intelligence layer*
*This is the foundation for the donor 360 profile system*

---

## PART 3: DIGITAL PRESENCE & SOCIAL MEDIA INTEGRATION

### Every interest group person and org gets a full digital profile
### These fields feed directly into E42 (News Intelligence), E30 (Email), E31 (SMS), E19 (Social Media), E41 (Campaign Builder)

---

### ORGANIZATION DIGITAL FIELDS

```sql
ALTER TABLE public.committee_registry ADD COLUMN IF NOT EXISTS
    website_url         text,           -- official website
    facebook_url        text,           -- Facebook page URL
    facebook_handle     text,           -- @handle
    twitter_url         text,           -- X/Twitter URL
    twitter_handle      text,           -- @handle
    instagram_url       text,
    instagram_handle    text,
    youtube_url         text,           -- YouTube channel
    linkedin_url        text,           -- LinkedIn company page
    tiktok_url          text,
    newsletter_signup   text,           -- URL to subscribe to their newsletter
    newsletter_name     text,           -- name of their publication
    rss_feed_url        text,           -- RSS for E42 auto-monitoring
    press_contact_email text,           -- who to contact for media
    press_contact_name  text,
    event_calendar_url  text,           -- their public events calendar
    donation_page_url   text,           -- their donate button URL
    volunteer_signup_url text,
    membership_url      text,
    podcast_url         text,
    podcast_name        text,
    substack_url        text,
    facebook_group_url  text,           -- private member group if public
    -- Social metrics (auto-updated by E42)
    facebook_followers  integer,
    twitter_followers   integer,
    instagram_followers integer,
    youtube_subscribers integer,
    -- E42 monitoring flags
    monitor_news        boolean DEFAULT false,  -- E42 tracks press mentions
    monitor_social      boolean DEFAULT false,  -- E42 tracks social posts
    auto_post_relevant  boolean DEFAULT false,  -- E30/E31/E19 auto-shares their content
    last_monitored_at   timestamptz;
```

### PERSON DIGITAL FIELDS (add to interest_group_people)

```sql
ALTER TABLE public.interest_group_people ADD COLUMN IF NOT EXISTS
    personal_website    text,
    linkedin_url        text,
    twitter_url         text,
    twitter_handle      text,
    facebook_url        text,
    instagram_url       text,
    tiktok_url          text,
    substack_url        text,
    podcast_url         text,
    email_personal      text,
    email_work          text,
    email_campaign      text,
    preferred_contact   text,           -- 'email' | 'text' | 'phone' | 'linkedin'
    -- Consent / list membership
    on_email_list       boolean DEFAULT false,
    on_sms_list         boolean DEFAULT false,
    email_unsubscribed  boolean DEFAULT false,
    sms_opted_out       boolean DEFAULT false,
    -- Engagement tracking
    last_email_sent     timestamptz,
    last_email_opened   timestamptz,
    last_sms_sent       timestamptz,
    last_clicked_at     timestamptz,
    total_emails_sent   integer DEFAULT 0,
    total_opens         integer DEFAULT 0,
    email_open_rate     numeric,
    -- Social engagement
    follows_our_page    boolean DEFAULT false,  -- follows BroyhillGOP social
    shared_our_content  boolean DEFAULT false,
    tagged_us           boolean DEFAULT false;
```

---

## E42 NEWS INTELLIGENCE INTEGRATION

### Auto-monitoring pipeline for interest groups:
```
E42 monitors RSS + Google News for every org where monitor_news = true
  → New article detected about org
  → Article tagged with org's issue_tags + partisan_lean
  → If relevant to BroyhillGOP candidates → alert sent to relevant candidate profiles
  → If shareable (R-friendly content) → queued for E30/E31/E19 auto-distribution
```

### RSS feeds to monitor — examples:
- NC Farm Bureau: `https://www.ncfb.org/news/feed/`
- NC Chamber: `https://www.ncchamber.com/feed/`
- NRA-ILA: `https://www.nraila.org/rss/`
- NC Values Coalition: `https://ncvalues.org/feed/`
- Club for Growth: `https://www.clubforgrowth.org/feed/`
- Ducks Unlimited: `https://www.ducks.org/conservation/news/feed`
- Sportsmen's Alliance: `https://sportsmensalliance.org/feed/`
- NCGA (official): `https://www.ncleg.gov/rss/`
- NC Governor's office: `https://governor.nc.gov/feed/`

---

## E30/E31/E19 SOCIAL MEDIA AUTO-POSTING INTEGRATION

### Trigger rules for auto-content distribution:

| Trigger | Action | Channel |
|---------|--------|---------|
| NRA gives A+ rating to NC candidate | Auto-post endorsement graphic | Facebook, X, Instagram |
| Farm Bureau endorses candidate | Auto-newsletter to agricultural district donors | E30 email |
| EBCI makes major donation to R candidate | Alert to relevant district candidate | Internal only |
| Club for Growth endorses primary challenger | Flag for candidate monitoring | Internal alert |
| NC Values Coalition scorecard released | Auto-post to pro-life donor segment | E30 + E31 SMS |
| Interest group holds major fundraiser | Calendar event created | E34 Events |
| Ducks Unlimited chapter dinner in district | Alert to hunting/fishing donor segment | E30 email |
| Legislative vote on hog farm regulation | Alert to Duplin/Sampson donor list | E31 SMS |
| Beach nourishment bill passes | Alert to coastal district donors | E30 email |

### Segment builder — auto-audience from interest group tags:
```sql
-- Build email segment: "Everyone who donated to hunting/fishing orgs"
SELECT DISTINCT ps.person_id, ps.voter_rncid, dc.email
FROM core.person_spine ps
JOIN core.contribution_map cm ON cm.person_id = ps.person_id
JOIN public.committee_issues ci ON ci.committee_id = cm.committee_id
JOIN public.issue_tags it ON it.tag = ci.issue_tag
  AND it.tag IN ('waterfowl_hunting','deer_hunting','saltwater_fishing',
                 'freshwater_fishing','second_amendment','outdoor_sports_wildlife')
JOIN public.donor_contacts dc ON dc.voter_ncid = ps.voter_ncid
  AND dc.contact_type = 'email'
WHERE cm.amount > 0
GROUP BY ps.person_id, ps.voter_rncid, dc.email
HAVING SUM(cm.amount) >= 50;
-- Result: targeted list for Ducks Unlimited dinner invite, hunting season alert, etc.
```

---

## NEWSLETTER / PUBLICATION TRACKING

Every major interest group publishes content we should monitor and sometimes repost:

| Publication | Org | Format | Frequency | Auto-monitor? |
|------------|-----|--------|-----------|--------------|
| NC Farm Bureau News | Farm Bureau | Print + digital | Monthly | YES |
| The Tar Heel | NC Chamber | Newsletter | Weekly | YES |
| NRA America's 1st Freedom | NRA | Magazine | Monthly | YES |
| Wildlife in NC | NCWRC | Magazine | Bimonthly | YES |
| NC Wildlife Federation News | NCWF | Newsletter | Quarterly | YES |
| Ducks Unlimited Magazine | DU | Magazine | Bimonthly | YES |
| NC Values Voter Guide | NCVC | Annual | Election cycle | YES |
| Club for Growth Newsletter | CFG | Email | Weekly | YES |
| Heritage Foundation Daily Signal | Heritage | Daily | Daily | YES |
| John Locke Foundation newsletters | JLF/Civitas | Daily | Daily | YES |
| NCGA News | NCGA | Press releases | As issued | YES |
| Sportsmen's Alliance Alert | SA | Email alert | As needed | YES |

---

## DATABASE TABLES SUMMARY — FULL DIGITAL LAYER

```sql
-- All tied together:
interest_group_people       -- the humans (officers, donors, decision-makers)
  → committee_registry      -- their organization (with all digital links)
  → core.person_spine       -- their donor record (if they donate)
  → contacts                -- their contact info (email, phone)
  → candidate_issues        -- if they are also a candidate/officeholder
  → issue_tags              -- what issues they care about personally
  → community_profiles      -- what community they represent geographically

-- E42 monitors:
committee_registry.rss_feed_url    → news articles tagged to org + issues
interest_group_people.twitter_url  → tweets from key decision-makers

-- E30/E31/E19 uses:
contacts.contact_value (email/phone)  → outreach
committee_registry.newsletter_signup  → subscribe to their content
-- Segment builder queries above → targeted audience lists

-- Clout scoring auto-updates:
committee_registry.clout_score        → recalculated each filing period
  using D1 (SBOE data) + D2 (SOS lobbyist data) + D3-D12 (various sources)
```

---

*Updated by Perplexity AI — March 31, 2026*
*Full digital presence layer — website, social, RSS, newsletter, auto-post triggers*
*Integrates with E42 (News), E30 (Email), E31 (SMS), E19 (Social Media), E41 (Campaign Builder)*
