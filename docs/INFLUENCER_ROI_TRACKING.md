# Influencer ROI Tracking System
## BroyhillGOP — Track Every Referral, Rate Every Influencer
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT
Every person who refers, hosts, introduces, or influences a donor
gets credited for that donor's activity — forever.
We rank influencers by their actual dollar impact, not their title or self-reported relationships.

An influencer is anyone who:
- Hosts an event that produces donors
- Personally introduces someone who then gives
- Shares content that drives donations
- Refers a prospect who converts
- Endorses publicly and drives donations
- Sits on a board that produces referrals

---

## THE INFLUENCER PERFORMANCE SCORE

### Dimensions (scored continuously, auto-updated)

| Metric | Weight | Measurement |
|--------|--------|-------------|
| **Total $ referred** | 35% | Sum of all donations from their referrals |
| **# of donors referred** | 20% | Count of unique donors attributed to them |
| **Conversion rate** | 15% | Referrals that became donors / total referrals made |
| **Avg donor value** | 10% | Avg donation amount of their referrals |
| **Retention rate** | 10% | % of their referrals who gave again next cycle |
| **Network depth** | 5% | Did their referrals also refer others? (2nd-degree) |
| **Speed to close** | 5% | Avg days from introduction to first donation |

**INFLUENCER_SCORE = weighted composite, recalculated monthly**
**TIER:** Platinum (85-100) | Gold (70-84) | Silver (50-69) | Bronze (25-49) | Developing (0-24)**

---

## DATABASE TABLES

```sql
-- influencer_registry — every person who refers donors
CREATE TABLE IF NOT EXISTS public.influencer_registry (
    id                  SERIAL PRIMARY KEY,
    person_id           bigint REFERENCES core.person_spine(person_id),
    voter_rncid         text,
    full_name           text,
    -- Classification
    influencer_type     text,   -- 'host' | 'endorser' | 'board_member' | 'social_media' |
                                --  'peer_referrer' | 'bundler' | 'finance_committee'
    primary_network     text,   -- 'healthcare' | 'legal' | 'farming' | 'hunting' etc
    issue_tags          text[],
    affinity_groups     text[],
    -- Performance scores (auto-updated monthly)
    total_dollars_referred      numeric DEFAULT 0,
    total_donors_referred       integer DEFAULT 0,
    total_referrals_made        integer DEFAULT 0,  -- including non-converted
    conversion_rate             numeric DEFAULT 0,  -- 0.0-1.0
    avg_donor_value             numeric DEFAULT 0,
    retention_rate              numeric DEFAULT 0,
    network_depth_score         numeric DEFAULT 0,
    avg_days_to_close           numeric DEFAULT 0,
    -- Composite score
    influencer_score            numeric DEFAULT 0,   -- 0-100
    influencer_tier             text DEFAULT 'Developing',  -- Platinum/Gold/Silver/Bronze/Developing
    -- Trend
    score_last_month            numeric DEFAULT 0,
    score_change                numeric DEFAULT 0,   -- positive = improving
    -- Relationship
    relationship_status         text DEFAULT 'cold', -- cold/warm/active/champion
    last_contact_date           date,
    assigned_relationship_mgr   text,
    -- Social media (if public influencer)
    twitter_handle              text,
    instagram_handle            text,
    facebook_url                text,
    follower_count_total        integer DEFAULT 0,
    nc_audience_pct             numeric DEFAULT 0,
    avg_engagement_rate         numeric DEFAULT 0,
    -- Contact
    email                       text,
    phone                       text,
    -- Notes
    notes                       text,
    created_at                  timestamptz DEFAULT NOW(),
    updated_at                  timestamptz DEFAULT NOW()
);

-- donor_referral_map — every referral tracked with full attribution
CREATE TABLE IF NOT EXISTS public.donor_referral_map (
    id                  BIGSERIAL PRIMARY KEY,
    -- The referral
    influencer_id       integer REFERENCES public.influencer_registry(id),
    referred_person_id  bigint REFERENCES core.person_spine(person_id),
    -- How the referral happened
    referral_type       text,   -- 'event_host' | 'personal_intro' | 'social_share' |
                                --  'endorsement' | 'peer_pressure' | 'content_click'
    referral_source     text,   -- specific event name, post URL, intro context
    referral_date       date,
    -- Conversion tracking
    first_donation_date date,
    first_donation_amt  numeric,
    converted           boolean DEFAULT false,
    days_to_convert     integer,
    -- Lifetime value tracking
    total_donated_lifetime  numeric DEFAULT 0,
    donation_count          integer DEFAULT 0,
    last_donation_date      date,
    last_donation_amt       numeric,
    is_recurring_donor      boolean DEFAULT false,
    -- 2nd degree — did this referral refer others?
    became_influencer       boolean DEFAULT false,
    sub_referrals_count     integer DEFAULT 0,
    sub_referrals_dollars   numeric DEFAULT 0,
    -- Attribution
    attribution_confidence  numeric DEFAULT 1.0,  -- 0-1, how certain is this attribution?
    attribution_method      text,   -- 'direct_intro' | 'event_attendance' | 'content_tracking'
    created_at              timestamptz DEFAULT NOW()
);

-- influencer_events — events hosted, content posted, endorsements made
CREATE TABLE IF NOT EXISTS public.influencer_events (
    id              SERIAL PRIMARY KEY,
    influencer_id   integer REFERENCES public.influencer_registry(id),
    event_type      text,   -- 'fundraiser_host' | 'social_post' | 'endorsement' |
                            --  'introduction' | 'board_meeting' | 'panel_appearance'
    event_date      date,
    description     text,
    -- Results
    attendees_count         integer,
    referrals_generated     integer,
    donors_converted        integer,
    dollars_raised          numeric,
    social_reach            integer,  -- impressions/views if social post
    -- Links
    event_id        integer,  -- FK to events table if applicable
    post_url        text,     -- if social media post
    created_at      timestamptz DEFAULT NOW()
);
```

---

## INFLUENCER LEADERBOARD — Live Dashboard

### Top Influencers This Cycle

```sql
SELECT
    ir.full_name,
    ir.influencer_tier,
    ir.influencer_score,
    ir.total_dollars_referred,
    ir.total_donors_referred,
    ROUND(ir.conversion_rate * 100, 1) as conversion_pct,
    ir.avg_donor_value,
    ROUND(ir.retention_rate * 100, 1) as retention_pct,
    ir.score_change as trend,  -- positive = rising star
    ir.primary_network,
    ir.relationship_status
FROM public.influencer_registry ir
WHERE ir.total_referrals_made > 0
ORDER BY ir.influencer_score DESC
LIMIT 50;
```

### Live Leaderboard Display:
```
╔══════════════════════════════════════════════════════════╗
║  🏆 TOP INFLUENCERS — 2025-2026 CYCLE                   ║
╠══════════════════════════════════════════════════════════╣
║  PLATINUM                                                ║
║  1. [Name] — Healthcare  $485,000  47 donors  ↑+12pts   ║
║  2. [Name] — Legal       $312,000  28 donors  ↑+8pts    ║
║  3. [Name] — Real Estate $287,000  52 donors  →0pts     ║
╠══════════════════════════════════════════════════════════╣
║  GOLD                                                    ║
║  4. [Name] — Farming     $185,000  31 donors  ↑+5pts    ║
║  5. [Name] — Banking     $162,000  19 donors  ↓-3pts    ║
╠══════════════════════════════════════════════════════════╣
║  🌟 RISING STARS (biggest score gains this month)       ║
║  • [Name] — +24pts — 3 referrals → $45,000 this month  ║
║  • [Name] — +18pts — hosted first event, 8 donors      ║
╚══════════════════════════════════════════════════════════╝
```

---

## SCORE AUTO-CALCULATION

```sql
-- Run monthly to recalculate all influencer scores
UPDATE public.influencer_registry ir SET
    total_dollars_referred = stats.total_dollars,
    total_donors_referred = stats.total_donors,
    total_referrals_made = stats.total_referrals,
    conversion_rate = CASE WHEN stats.total_referrals > 0
        THEN stats.converted_count::numeric / stats.total_referrals ELSE 0 END,
    avg_donor_value = CASE WHEN stats.converted_count > 0
        THEN stats.total_dollars / stats.converted_count ELSE 0 END,
    retention_rate = stats.retention_rate,
    avg_days_to_close = stats.avg_days,
    -- Composite score
    influencer_score = ROUND(
        (LEAST(stats.total_dollars / 10000, 10) * 0.35) +  -- D1: $ referred (cap at $100K=10)
        (LEAST(stats.converted_count, 10) * 0.20) +          -- D2: # donors (cap at 10=10)
        (stats.conversion_rate * 10 * 0.15) +                -- D3: conversion rate
        (LEAST(stats.total_dollars / NULLIF(stats.converted_count,0) / 1000, 10) * 0.10) + -- D4: avg value
        (stats.retention_rate * 10 * 0.10) +                  -- D5: retention
        (LEAST(stats.sub_referrals, 10) * 0.05) +             -- D6: network depth
        (GREATEST(10 - stats.avg_days/10, 0) * 0.05)          -- D7: speed (faster=higher)
    * 10, 1),
    -- Tier
    influencer_tier = CASE
        WHEN influencer_score >= 85 THEN 'Platinum'
        WHEN influencer_score >= 70 THEN 'Gold'
        WHEN influencer_score >= 50 THEN 'Silver'
        WHEN influencer_score >= 25 THEN 'Bronze'
        ELSE 'Developing'
    END,
    score_change = ROUND(influencer_score - ir.score_last_month, 1),
    score_last_month = ir.influencer_score,
    updated_at = NOW()
FROM (
    SELECT
        drm.influencer_id,
        COALESCE(SUM(drm.total_donated_lifetime), 0) as total_dollars,
        COUNT(DISTINCT CASE WHEN drm.converted THEN drm.referred_person_id END) as converted_count,
        COUNT(DISTINCT drm.referred_person_id) as total_referrals,
        COALESCE(AVG(drm.days_to_convert), 999) as avg_days,
        COALESCE(AVG(CASE WHEN drm.is_recurring_donor THEN 1.0 ELSE 0.0 END), 0) as retention_rate,
        COALESCE(SUM(drm.sub_referrals_count), 0) as sub_referrals
    FROM public.donor_referral_map drm
    GROUP BY drm.influencer_id
) stats
WHERE ir.id = stats.influencer_id;
```

---

## INFLUENCER MANAGEMENT WORKFLOWS

### Platinum Tier — White Glove Treatment
- Personal call from candidate quarterly
- Invited to every VIP event
- Named in campaign materials (with permission)
- First to know about major announcements
- Asked to host 2+ events per cycle
- Finance committee membership offered
- Regular intel briefings on issues they care about

### Gold Tier — Active Cultivation
- Personal call from campaign manager monthly
- Invited to VIP events
- Asked to host 1 event per cycle
- Recognized at events publicly
- Regular email with exclusive content

### Silver Tier — Warm Engagement
- Monthly email with exclusive updates
- Invited to select events
- Encouraged to refer more prospects
- Given tools: sample language for referrals, shareable content

### Bronze Tier — Activation Campaign
- "You're close to Gold" messaging
- One specific ask: "Who is one person you could introduce us to?"
- Event invitation with bring-a-friend ask
- Recognition for any new referral

### Developing — Identification & Onboarding
- Who are they? Pull from spine + voter file
- What network do they have? (E20 maps their connections)
- What's their motivation? (issue tags, community identity)
- First ask: "Would you share this with [specific person you know]?"

---

## SOCIAL MEDIA INFLUENCER TRACKING

For public influencers (not just personal networks):

```sql
-- Track every post that drives donations
INSERT INTO public.influencer_events (
    influencer_id, event_type, event_date,
    description, social_reach, referrals_generated, dollars_raised
)
-- Populated by E42 monitoring + UTM link tracking
-- When someone clicks a tracked link from an influencer's post
-- and then donates, the referral is auto-attributed

-- UTM parameter structure:
-- utm_source = influencer_[id]
-- utm_medium = social_[platform]
-- utm_campaign = [campaign_name]
-- utm_content = [post_date]
```

### Influencer Content Performance:
```
[Influencer Name] — @NCHunters — Instagram
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Post: "Why I'm supporting Broyhill for RNC" — March 15
  👁️ Reach: 48,200
  ❤️ Engagement: 3,847 (8.0%)
  🖱️ Link clicks: 412
  💰 Donations from this post: 23 donors, $8,450
  📈 ROI: $8,450 from one post
  ⭐ Best performing post this cycle
```

---

## RISING STAR ALERTS

```
🌟 RISING STAR ALERT
[Name] just converted their 3rd referral this month.
Total attributed: $18,500 this cycle — up from $0 last cycle.
They hosted their first event last week (8 donors, $12,000).
Score: 34 → 58 (+24pts) — now Silver Tier, approaching Gold.

RECOMMENDED ACTION:
→ Personal thank-you call from candidate THIS WEEK
→ Invite to Gold Tier VIP event next month
→ Ask about hosting a second event in their network
→ "You have a gift for this — we'd love to have you on our finance committee"

[Call Now] [Schedule Follow-up] [View Their Network]
```

---

## REFERRAL CHAIN VISUALIZATION

For each major donor — show the full chain of who brought them in:

```
ART POPE ($50,000)
├── Referred by: [Influencer A] — hosted dinner March 2025
│   ├── [Influencer A] referred 12 other donors ($185,000 total)
│   └── [Influencer A] was referred by: [Influencer B]
│
JOHN SMITH, MD ($5,000)
├── Referred by: [Hospital Donor Host] — healthcare dinner April 2025
│   ├── 23 other doctors from same dinner
│   └── 3 of those doctors later hosted their OWN events
│       ├── Dr. Jones dinner → 8 donors, $28,000
│       └── Dr. Williams roundtable → 5 donors, $15,000
│
Total network value of [Hospital Donor Host] hosting ONE dinner:
$185,000+ across 3 generations of referrals
```

---

*Prepared by Perplexity AI — March 31, 2026*
*Every referral tracked, every influencer scored, every chain visualized*
*Leaderboard drives competition and recognition*
*Rising star alerts prevent losing emerging influencers*
