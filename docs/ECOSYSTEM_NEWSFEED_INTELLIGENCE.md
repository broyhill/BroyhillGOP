# Ecosystem Newsfeed Intelligence Architecture
## BroyhillGOP — Live Monitoring + Addictive Dashboard Feeds
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT
Every ecosystem dashboard has a specialized live intelligence feed.
E42 (News Intelligence) is the backbone — it monitors 13,000+ sources.
Each ecosystem subscribes to the slices it cares about.
Every feed item has a CALL TO ACTION button built in.

The goal: users open their ecosystem dashboard and can't leave.
New information constantly surfaces. Every item demands a response.

---

## MASTER FEED ARCHITECTURE

```
E42 News Intelligence (13,000+ sources)
    ↓ ingests + classifies by issue_tag + community_tag + partisan_lean
    ↓ scores by relevance to each ecosystem
    ↓ routes to ecosystem-specific feed queues
    ↓ triggers alerts, CTAs, auto-posts

FEEDS BY ECOSYSTEM:
E01 Donor Intelligence      → donor news, major gift announcements, death notices
E02 Donation Processing     → FEC filing deadlines, SBOE reports, compliance news
E03 Candidate Management    → candidate filings, poll results, endorsements, opposition research
E06 Analytics Engine        → election results, polling, demographic shifts
E08 Communications          → messaging trends, opposition attacks, viral content
E19 Social Media            → trending hashtags, influencer activity, viral posts
E20 Intelligence Brain      → all feeds aggregated, AI-prioritized
E30 Email Campaigns         → email deliverability news, CAN-SPAM updates
E31 SMS Marketing           → TCPA compliance, SMS news
E34 Events                  → venue news, weather, competing events
E38 Field Operations        → precinct results, canvassing intel, GOTV news
E42 News Intelligence       → master feed, all sources
E51 NEXUS Command           → everything, executive briefing format
```

---

## ECOSYSTEM-BY-ECOSYSTEM FEED SPECIFICATIONS

---

### E01 — DONOR INTELLIGENCE FEED
**Subject:** Money movement, major donors, death/estate notices, wealth events

**Sources monitored:**
- NC SBOE filing RSS → new campaign finance reports
- FEC RSS → federal filings
- Business Journal → executive moves, company sales, IPOs (wealth events)
- Obituary feeds (legacy.com, local newspapers) → estate/memorial giving opportunities
- Forbes/Bloomberg → net worth changes, major sales
- Real estate transaction records → large property sales = liquidity events
- Court records → estate settlements

**Feed items + CTAs:**
| Item | CTA |
|------|-----|
| New SBOE report filed for district | "View donor list" → opens donor table |
| Major donor gives to opposition | "Alert candidate" + "Counter-outreach" button |
| Executive sells company (wealth event) | "Schedule outreach" → adds to call list |
| Death notice for known major donor | "Flag for estate outreach" (sensitive, time-appropriate) |
| New large real estate sale in district | "Research owner" → pulls donor history |
| Donor gives to charity (990 filing) | "Note charitable interest" → updates profile |

---

### E03 — CANDIDATE MANAGEMENT FEED
**Subject:** Elections, candidates, polls, endorsements, opposition research

**Sources monitored:**
- NC SBOE candidate filing system → new filings, withdrawals
- FEC candidate registration → federal races
- Poll aggregators (RealClearPolitics, FiveThirtyEight, Ballotpedia)
- Local newspaper endorsement pages
- Opposition research feeds (opposition press releases, attack ads)
- Redistricting news
- Candidate social media accounts (all 100 NCGA R members)
- Opponent social media accounts

**Feed items + CTAs:**
| Item | CTA |
|------|-----|
| New candidate files in target district | "Research candidate" + "Add to watchlist" |
| Poll released showing race tightening | "Alert finance team" + "View district donors" |
| Endorsement announced | "Counter-endorse outreach" or "Celebrate + post" |
| Opposition attack ad detected | "Draft response" → opens E09 Content AI |
| Redistricting ruling | "Update district maps" → triggers person_district_map rebuild |
| Candidate files FEC report | "View top donors" → opens donor intelligence |

---

### E19 — SOCIAL MEDIA INTELLIGENCE FEED
**Subject:** Trending content, influencers, viral moments, opposition social activity

**Influencer monitoring by interest group:**
```
Hunters/Outdoors:
  - @NCHunters (Twitter/X)
  - Ducks Unlimited NC Instagram
  - NC Wildlife Resources Commission @NCWildlife
  - Major hunting YouTubers with NC audience

Farmers:
  - @NCFarmBureau
  - @NCDeptAg
  - Farm bureau county chapter accounts
  - AgWeb, Farm Journal social

Law Enforcement:
  - NC Sheriffs' Association social
  - @NCSHP (State Highway Patrol)
  - Police1.com RSS

Pro-Life:
  - @NCValuesCoalition
  - @SBAProLife
  - @marchforlife

School Choice / Parental Rights:
  - @MomsForLiberty
  - @ParentsDefendEd
  - @NCSchoolChoice
  - Local school board meeting livestreams

Second Amendment:
  - @NRA @NRAILA
  - @GunOwnersofAmerica
  - @NCFirearmsCoalition

Soccer Moms:
  - Local NextDoor groups (public posts)
  - Town Facebook groups
  - Local youth sports association pages

Healthcare:
  - @NCMedicalSociety
  - @AMADocAdvocacy
  - @NCNurses
```

**Feed items + CTAs:**
| Item | CTA |
|------|-----|
| Influencer posts about key issue | "Engage" + "Share to our feed" + "Reply suggestion" |
| Post going viral (R-friendly) | "Boost" → queues for E19 auto-repost |
| Opposition post gaining traction | "Counter-narrative" → E09 drafts response |
| Hashtag trending in NC | "Join conversation" → E19 posts with hashtag |
| Affinity group member posts | "Engage" → like/comment/share |
| Negative coverage of candidate | "Alert + Response draft" |

---

### E42 — NEWS INTELLIGENCE MASTER FEED
**Subject:** Everything — the master intelligence engine

**13,000+ sources organized by:**

```
TIER 1 — NC-SPECIFIC (highest priority)
  NC newspapers: News & Observer, Charlotte Observer, Winston-Salem Journal,
    Greensboro News & Record, Fayetteville Observer, Wilmington StarNews,
    Asheville Citizen-Times, Durham Herald-Sun, Rocky Mount Telegram,
    High Point Enterprise, + 80 local papers
  NC TV stations: WRAL, WSOC, WBTV, WXII, WTVD, WECT, WWAY
  NC radio: WBT, WPTF, + network
  NC political: ncpolicywatch.com, NC Capitol Connection, NCGA press

TIER 2 — SOUTHEAST / REGIONAL
  Charlotte Business Journal, Triangle Business Journal
  Wilmington Business Journal
  AP Southeast bureau

TIER 3 — NATIONAL / POLITICAL
  Fox News, Breitbart, Daily Wire, Washington Examiner, NY Post (R-friendly)
  Politico, The Hill, Roll Call (neutral political)
  AP, Reuters (wire)

TIER 4 — INTEREST GROUP SPECIFIC (by issue_tag)
  Agriculture: Farm Journal, AgWeb, Southeast Farm Press
  Healthcare: Modern Healthcare, Becker's Hospital Review
  Legal: Law360, NC Lawyers Weekly
  Military: Military Times, Stars & Stripes
  Hunting: Outdoor Life, Field & Stream, DU Magazine
  Education: Education Week, NC School Boards Journal
  Finance: American Banker, NC Bankers Journal
  Real Estate: CoStar, NC Realtors news
  Energy: E&E News, NC Energy News
  Sports/NASCAR: NASCAR.com, Motorsport.com
```

**Feed items + CTAs:**
| Item Type | CTA Options |
|-----------|------------|
| R candidate win/announcement | "Celebrate + auto-post" |
| D opponent gaffe | "Share + opposition research tag" |
| Issue bill introduced in NCGA | "Alert affected affinity groups" |
| Federal funding cut to NC program | "Alert affected community" + "Draft response" |
| Major donor mentioned in news | "Update donor profile" |
| Interest group endorsement | "Add to candidate profile" |
| Poll released | "Add to race dashboard" |
| Ethics investigation | "Flag + monitor" |
| Natural disaster in district | "Candidate response protocol" → E08 messaging |

---

### E20 — INTELLIGENCE BRAIN EXECUTIVE FEED
**Subject:** AI-curated daily briefing — most important items across all feeds

**Format:** Eddie's morning briefing — top 10 items that need attention today

```
DAILY BRIEFING FORMAT:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 URGENT (needs response today)
  1. [Item] → [CTA]
  2. [Item] → [CTA]

🟡 IMPORTANT (this week)
  3. [Item] → [CTA]
  4. [Item] → [CTA]
  5. [Item] → [CTA]

🟢 MONITOR (FYI)
  6-10. [Items]

💰 DONOR OPPORTUNITIES
  - [Wealth event] → [Outreach CTA]

📊 RACE UPDATES
  - [Poll/filing news] → [View district]

🎯 AFFINITY GROUP ALERTS
  - [Hunter/farmer/sheriff news] → [Group CTA]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## CALL TO ACTION LIBRARY

Every feed item has one or more CTAs from this library:

```sql
CREATE TABLE IF NOT EXISTS public.feed_cta_types (
    id          SERIAL PRIMARY KEY,
    cta_code    text UNIQUE,
    label       text,           -- button text
    icon        text,           -- emoji or icon name
    action      text,           -- what happens when clicked
    target_ecosystem text       -- which ecosystem handles it
);

INSERT INTO feed_cta_types VALUES
-- Content actions
(1, 'AUTO_POST', 'Post to Social', '📢', 'Queue for E19 auto-post', 'E19'),
(2, 'DRAFT_EMAIL', 'Draft Email', '✉️', 'Open E09 with context pre-loaded', 'E09'),
(3, 'DRAFT_SMS', 'Draft SMS', '📱', 'Open E31 composer with context', 'E31'),
(4, 'DRAFT_RESPONSE', 'Draft Response', '✍️', 'E09 AI drafts opposition response', 'E09'),
-- Donor actions
(5, 'VIEW_DONORS', 'View District Donors', '💰', 'Open E01 filtered to district', 'E01'),
(6, 'RESEARCH_DONOR', 'Research Donor', '🔍', 'Pull full donor intelligence profile', 'E01'),
(7, 'SCHEDULE_CALL', 'Schedule Outreach', '📞', 'Add to call list in E15', 'E15'),
(8, 'FLAG_ESTATE', 'Flag Estate Opportunity', '🏛️', 'Tag for planned giving outreach', 'E01'),
-- Candidate actions
(9, 'ALERT_CANDIDATE', 'Alert Candidate', '🚨', 'Push notification to candidate', 'E03'),
(10, 'UPDATE_PROFILE', 'Update Profile', '👤', 'Open candidate profile edit', 'E03'),
(11, 'VIEW_RACE', 'View Race Dashboard', '🗳️', 'Open race dashboard', 'E03'),
-- Field actions
(12, 'BUILD_LIST', 'Build Contact List', '📋', 'Generate filtered list for district', 'E38'),
(13, 'DEPLOY_CANVASSERS', 'Deploy Canvassers', '🚪', 'Open field ops for district', 'E38'),
-- Intelligence actions
(14, 'MONITOR', 'Add to Watchlist', '👁️', 'Add source/entity to E42 monitoring', 'E42'),
(15, 'RESEARCH', 'Deep Research', '🔬', 'Trigger full research on entity', 'E20'),
(16, 'SHARE_INTEL', 'Share with Team', '🤝', 'Send to relevant team member', 'E08'),
-- Affinity group actions
(17, 'ALERT_GROUP', 'Alert Affinity Group', '🎯', 'Push alert to affinity group members', 'E30/E31'),
(18, 'ENGAGE_INFLUENCER', 'Engage Influencer', '⭐', 'Open relationship management for influencer', 'E19');
```

---

## INFLUENCER REGISTRY TABLE

```sql
CREATE TABLE IF NOT EXISTS public.influencer_registry (
    id              SERIAL PRIMARY KEY,
    name            text NOT NULL,
    handle_twitter  text,
    handle_instagram text,
    handle_tiktok   text,
    handle_youtube  text,
    handle_facebook text,
    platform_primary text,      -- where they have most reach
    follower_count  integer,
    nc_audience_pct numeric,    -- % of followers in NC
    nc_followers_est integer,   -- estimated NC followers
    partisan_lean   char(1),    -- R/D/N
    issue_tags      text[],     -- which issues they cover
    affinity_groups text[],     -- which affinity groups they speak to
    influence_score integer,    -- 1-100
    is_monitored    boolean DEFAULT true,
    last_post_at    timestamptz,
    avg_engagement_rate numeric,
    known_to_candidate boolean DEFAULT false,
    relationship_status text,   -- 'cold' | 'aware' | 'friendly' | 'allied' | 'endorsed'
    contact_email   text,
    contact_phone   text,
    notes           text,
    created_at      timestamptz DEFAULT NOW()
);
```

---

## DASHBOARD ADDICTION DESIGN PRINCIPLES

1. **Always something new** — feeds refresh every 15 minutes
2. **Urgency indicators** — 🔴 needs response, 🟡 today, 🟢 monitor
3. **One-click action** — every item has a CTA, never more than one click to act
4. **Personalized** — each user sees their districts, their affinity groups, their races
5. **Competitive** — show "opposition raised $X today" to trigger urgency
6. **Rewards** — "You responded to 8 of 10 alerts today" progress bar
7. **FOMO** — "3 donors in your district gave to opposition yesterday"
8. **Streaks** — daily engagement streaks, volunteer hour streaks
9. **Leaderboards** — which county raised most this week, which volunteer knocked most doors
10. **Real-time** — live donation ticker, live canvassing results

---

*Prepared by Perplexity AI — March 31, 2026*
*E42 is the engine — every other ecosystem subscribes to its classified feed*
*CTA library makes every feed item immediately actionable*
*Dashboard addiction design keeps users engaged continuously*

---

## ADVANCED CTA: CONVERT TOP DONOR TO HOST

### Trigger: Top donor gives $1M+ to medical center
### Advanced play: Ask THEM to host — not donate more

---

### WHY HOSTING IS MORE VALUABLE THAN DONATING

| Hosting | Donating |
|---------|---------|
| They bring their entire network | They bring only their check |
| 50-100 doctors/executives in one room | One person's contribution |
| Their credibility vouches for the candidate | Candidate stands alone |
| Deepens THEIR relationship with candidate | Transactional exchange |
| Creates new donors from their network | No multiplication effect |
| They feel ownership of the campaign | They feel like an ATM |
| Costs them time, not just money | Pure financial transaction |

**The $1M hospital donor knows every doctor, every hospital board member,
every healthcare executive in their region. Their guest list IS the fundraiser.**

---

### THE ASK — HOW TO FRAME IT

**Wrong way:**
"Would you host a fundraiser for us?"
→ Sounds like you want their address and their rolodex

**Right way:**
"[Name], what you did for [Hospital] shows you understand
what good healthcare leadership looks like. We're putting together
a small dinner — 20-25 physicians and healthcare executives —
to talk about Certificate of Need reform, malpractice liability,
and getting government out of the exam room.

We'd love for you to be the person who brings that group together.
Your name on the invitation means they'll come.
Would you be willing to host that conversation at your home?"

**Key elements:**
1. It's a POLICY conversation first, fundraiser second
2. Their NAME is the draw — you're honoring their status
3. Small and exclusive — 20-25 people, not a cattle call
4. Specific issue agenda — they know exactly what they're hosting
5. "Bring that group together" — they're the convener, not the donor

---

### THE EVENT DESIGN

**Format:** Private home dinner or exclusive venue
**Size:** 20-30 guests maximum (intimacy = higher asks)
**Guest list:** Built jointly — host suggests their contacts, we add ours

**Suggested invite targets from host's network:**
```sql
-- Find doctors/healthcare executives in same county as host
-- who have given to R candidates or have R registration
SELECT ps.norm_first, ps.norm_last, ps.employer, ps.occupation,
    ps.total_donated, nv.county_desc
FROM core.person_spine ps
JOIN public.nc_voters nv ON nv.ncid = ps.voter_ncid
WHERE nv.county_desc = '[HOST_COUNTY]'
AND nv.party_cd IN ('REP','UNA')
AND (
    ps.employer_sic IN ('8011','8049','8062','8099')
    OR ps.occupation ILIKE ANY(ARRAY['%physician%','%doctor%','%surgeon%','%MD%','%hospital%CEO%','%health system%'])
)
AND ps.total_donated > 0
ORDER BY ps.total_donated DESC
LIMIT 30;
-- Result: personalized guest list recommendation for host
```

**Event flow:**
```
6:30 PM  Arrival, cocktails — host personally greets every guest
7:00 PM  Dinner — candidate sits at table with 6-8 guests
8:00 PM  Candidate speaks 10 minutes — specific healthcare policy
8:15 PM  Open discussion — "What's your biggest challenge right now?"
8:45 PM  Finance director makes the ask — host stays silent
          (never the host's job to ask — protect the relationship)
9:00 PM  Reception continues — candidate works the room
9:30 PM  Close
```

**Ask amounts by guest profile:**
| Guest Type | Suggested Ask |
|-----------|--------------|
| Hospital CEO / CMO | $5,000-$10,000 |
| Physician practice owner | $2,500-$5,000 |
| Hospital department chief | $1,000-$2,500 |
| Staff physician | $500-$1,000 |
| Healthcare executive | $1,000-$5,000 |
| Host (if they want to give on top of hosting) | $10,000-$25,000 |

**Revenue target:** 25 guests × avg $2,500 = **$62,500 net**
**Host cost:** Their home, catering (~$3,000-$5,000) — campaign reimburses or covers

---

### DATABASE + AUTOMATION SUPPORT

```sql
-- E34 Events table entry
INSERT INTO public.events (
    event_type, event_name, host_person_id,
    candidate_id, target_audience_tag,
    target_revenue, guest_list_query,
    event_date, venue_type, max_guests,
    status
) VALUES (
    'major_donor_host_fundraiser',
    'Healthcare Policy Dinner — hosted by [Name]',
    [host_person_id],
    [candidate_id],
    'Doctors for Broyhill',
    62500.00,
    'county=[HOST_COUNTY] AND sic=80xx AND party=R',
    '[event_date]',
    'private_home',
    25,
    'planning'
);

-- E30 generates personalized invitation
-- Subject: "An Invitation from [Host Name]"
-- Signed by HOST, not candidate campaign
-- That's the magic — the credibility transfer
```

---

### THE MULTIPLICATION EFFECT

```
$1M hospital donor
    → hosts dinner for 25 healthcare executives
    → raises $62,500 at the event
    → 5 attendees become recurring donors ($10K+ per cycle each)
    → 2 attendees host their OWN follow-up events
    → 1 attendee joins finance committee
    → host deepens relationship → eventual $25K personal gift
    → total value generated: $250,000-$500,000 over 2 cycles

vs.

Asking the $1M donor for $25K directly
    → $25K one-time
    → no network multiplication
    → donor feels used
    → may not give again
```

**The host model multiplies. The ask model is linear.**

---

### E34 EVENTS AUTOMATION — HOST RECRUITMENT PIPELINE

```
When E42 detects major charitable gift →
  → CTA: "Recruit as host"
  → E20 Intelligence Brain maps their network
  → E34 Events creates event skeleton
  → E30 drafts personalized ask letter (for candidate signature)
  → E01 Donor Intelligence suggests guest list from spine
  → E15 Contact Directory pulls host's phone/email
  → Candidate gets briefing: who they are, what they gave, how to ask
```

---

*Updated March 31, 2026 — Host recruitment strategy added*
*Top donor as HOST is more valuable than top donor as donor*
*E34 + E01 + E20 + E30 work together to execute the full host model*
