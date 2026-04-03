# District Microsegment Dominance Ranking System
## BroyhillGOP — Rank 1-100, Modulate Ecosystem Intensity
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT

Every office district gets a DOMINANCE RANK (1-100) for every microsegment.
Rank 1 = that segment is most dominant in that district relative to all other districts.
Rank 100 = that segment is least dominant.

These ranks directly control:
- Which newsfeeds appear on that district's dashboard (highest ranked segments get top billing)
- How intense the CTAs are (Rank 1-10 segments get urgent CTAs, 90-100 get passive monitoring)
- Which affinity groups get activated first
- Where volunteer deployment focuses
- Which fundraising appeals go out first

---

## THE RANKING FORMULA

For each district × segment combination, calculate a DOMINANCE SCORE:

```
DOMINANCE_SCORE = 
  (segment_voters_in_district / total_r_u_voters_in_district × 40)   -- % of electorate
  + (segment_donors_in_district / total_donors_in_district × 35)      -- % of donor base
  + (segment_volunteers / total_volunteers × 15)                       -- % of volunteer base  
  + (segment_turnout_rate × 10)                                        -- how reliably they vote
```

Then RANK districts 1-100 by DOMINANCE_SCORE within each segment.
And RANK segments 1-N by DOMINANCE_SCORE within each district.

---

## DATABASE IMPLEMENTATION

```sql
-- district_microsegment_rankings — the master ranking table
CREATE TABLE IF NOT EXISTS public.district_microsegment_rankings (
    id                  BIGSERIAL PRIMARY KEY,
    -- District identification
    district_type       text NOT NULL,  -- 'nc_house'|'nc_senate'|'us_house'|'county'
    district_id         text NOT NULL,  -- "35", "Wake", "13"
    district_name       text,
    -- Segment identification  
    segment_tag         text NOT NULL,  -- 'sportsmen'|'veterans'|'pro_life' etc
    segment_label       text,
    -- Raw counts
    segment_voters      integer DEFAULT 0,   -- R+U voters in this segment in this district
    segment_donors      integer DEFAULT 0,   -- known donors in segment in district
    segment_volunteers  integer DEFAULT 0,   -- active volunteers in segment in district
    total_r_u_voters    integer DEFAULT 0,   -- total R+U voters in district
    total_donors        integer DEFAULT 0,   -- total donors in district
    -- Percentages
    voter_pct           numeric DEFAULT 0,   -- segment as % of district R+U electorate
    donor_pct           numeric DEFAULT 0,   -- segment as % of district donors
    volunteer_pct       numeric DEFAULT 0,   -- segment as % of district volunteers
    -- Dominance score and rank
    dominance_score     numeric DEFAULT 0,   -- 0-100 weighted composite
    -- Rank of this segment WITHIN this district (1 = most dominant segment here)
    segment_rank_in_district    integer,
    -- Rank of this district WITHIN all districts for this segment (1 = strongest district for this segment)
    district_rank_for_segment   integer,
    -- Ecosystem modulation settings (derived from ranks)
    newsfeed_priority   integer,    -- 1-10, controls feed ordering on dashboard
    cta_intensity       text,       -- 'urgent'|'high'|'medium'|'low'|'passive'
    alert_threshold     text,       -- 'immediate'|'daily'|'weekly'|'monthly'
    auto_post           boolean DEFAULT false,  -- auto-post content for this segment/district?
    -- Metadata
    last_calculated     timestamptz DEFAULT NOW(),
    data_source         text DEFAULT 'datatrust_v1'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dmr_district ON public.district_microsegment_rankings (district_type, district_id);
CREATE INDEX IF NOT EXISTS idx_dmr_segment ON public.district_microsegment_rankings (segment_tag, district_rank_for_segment);
CREATE INDEX IF NOT EXISTS idx_dmr_rank ON public.district_microsegment_rankings (segment_rank_in_district);
```

---

## DOMINANCE SCORE CALCULATION SQL

```sql
-- Step 1: Calculate raw scores for NC House districts
-- (Run after microseg_nc_house.csv is loaded into district_microsegment_raw)

INSERT INTO public.district_microsegment_rankings (
    district_type, district_id, district_name, segment_tag, segment_label,
    segment_voters, total_r_u_voters, voter_pct, dominance_score
)
SELECT
    'nc_house' as district_type,
    d.district_id,
    'NC House District ' || d.district_id as district_name,
    s.segment_tag,
    s.segment_label,
    s.segment_count as segment_voters,
    d.total_r_u as total_r_u_voters,
    ROUND(s.segment_count::numeric / NULLIF(d.total_r_u, 0) * 100, 2) as voter_pct,
    -- Dominance score: raw % × statewide rarity factor
    -- Segments that are locally concentrated AND statewide rare = higher dominance
    ROUND(
        (s.segment_count::numeric / NULLIF(d.total_r_u, 0) * 100) *
        (1 + (1 - s.statewide_pct / 100))  -- rarity multiplier
    , 2) as dominance_score
FROM district_totals d
CROSS JOIN segment_definitions s
JOIN district_segment_counts sc ON sc.district_id = d.district_id AND sc.segment = s.segment_tag;

-- Step 2: Rank segments within each district
UPDATE public.district_microsegment_rankings dmr
SET segment_rank_in_district = ranked.rnk
FROM (
    SELECT id,
        RANK() OVER (
            PARTITION BY district_type, district_id
            ORDER BY dominance_score DESC
        ) as rnk
    FROM public.district_microsegment_rankings
) ranked
WHERE dmr.id = ranked.id;

-- Step 3: Rank districts within each segment  
UPDATE public.district_microsegment_rankings dmr
SET district_rank_for_segment = ranked.rnk
FROM (
    SELECT id,
        RANK() OVER (
            PARTITION BY district_type, segment_tag
            ORDER BY dominance_score DESC
        ) as rnk
    FROM public.district_microsegment_rankings
) ranked
WHERE dmr.id = ranked.id;

-- Step 4: Set ecosystem modulation settings based on ranks
UPDATE public.district_microsegment_rankings SET
    newsfeed_priority = CASE
        WHEN segment_rank_in_district <= 3  THEN 1   -- top 3 segments in district: highest priority
        WHEN segment_rank_in_district <= 5  THEN 2
        WHEN segment_rank_in_district <= 8  THEN 3
        WHEN segment_rank_in_district <= 12 THEN 4
        WHEN segment_rank_in_district <= 20 THEN 5
        ELSE 6
    END,
    cta_intensity = CASE
        WHEN segment_rank_in_district <= 3  THEN 'urgent'
        WHEN segment_rank_in_district <= 8  THEN 'high'
        WHEN segment_rank_in_district <= 15 THEN 'medium'
        WHEN segment_rank_in_district <= 25 THEN 'low'
        ELSE 'passive'
    END,
    alert_threshold = CASE
        WHEN segment_rank_in_district <= 3  THEN 'immediate'
        WHEN segment_rank_in_district <= 8  THEN 'daily'
        WHEN segment_rank_in_district <= 20 THEN 'weekly'
        ELSE 'monthly'
    END,
    auto_post = CASE
        WHEN segment_rank_in_district <= 5 THEN true
        ELSE false
    END;
```

---

## ECOSYSTEM MODULATION RULES

### How dashboard content intensity is controlled:

```
segment_rank_in_district 1-3  → cta_intensity = 'urgent'
  - Newsfeed: Top of page, always visible, red badge
  - CTAs: Bold red buttons, auto-notification on new content
  - Auto-post: YES — content for this segment auto-queued for social
  - Alert: Immediate push notification on any relevant news
  - Example: NC House District 9 (Brent Jackson — Sampson/Duplin/Bladen)
    Rank 1 = hog_farming (91% of economy), Rank 2 = crop_agriculture, Rank 3 = veterans
    → Any hog farm regulation news fires IMMEDIATE alert to District 9 dashboard

segment_rank_in_district 4-8  → cta_intensity = 'high'
  - Newsfeed: Above the fold, orange badge
  - CTAs: Orange buttons, daily digest
  - Auto-post: YES for segments 4-5
  - Alert: Daily digest

segment_rank_in_district 9-15 → cta_intensity = 'medium'
  - Newsfeed: Mid-page, yellow indicator
  - CTAs: Standard buttons, weekly digest
  - Auto-post: NO
  - Alert: Weekly digest

segment_rank_in_district 16-25 → cta_intensity = 'low'
  - Newsfeed: Lower page, no badge
  - CTAs: Subtle, informational
  - Auto-post: NO
  - Alert: Monthly digest

segment_rank_in_district 26+  → cta_intensity = 'passive'
  - Newsfeed: Available but not promoted
  - CTAs: Only if user navigates to segment
  - Auto-post: NO
  - Alert: Manual only
```

---

## EXAMPLE: NC HOUSE DISTRICT 9 (Brent Jackson)
**Counties:** Bladen, Duplin, Jones, Pender, Sampson

| Rank | Segment | Voters | Dominance Score | CTA Intensity |
|------|---------|--------|----------------|--------------|
| 1 | Hog Farming | ~18,000 | 94.2 | 🔴 URGENT |
| 2 | Crop Agriculture | ~22,000 | 87.6 | 🔴 URGENT |
| 3 | Veterans | ~8,500 | 71.3 | 🔴 URGENT |
| 4 | Fiscal Conservative | ~31,000 | 68.4 | 🟠 HIGH |
| 5 | 2nd Amendment | ~29,000 | 65.1 | 🟠 HIGH |
| 6 | Pro-Life | ~18,000 | 58.2 | 🟠 HIGH |
| 7 | Social Conservative | ~22,000 | 54.7 | 🟠 HIGH |
| 8 | Sportsmen | ~12,000 | 49.3 | 🟠 HIGH |
| 9 | Faith / Religious | ~15,000 | 38.1 | 🟡 MEDIUM |
| 10 | Seniors 65+ | ~19,000 | 35.4 | 🟡 MEDIUM |
| ... | ... | ... | ... | ... |
| 25+ | Beach/Coastal | ~1,200 | 4.1 | ⚪ PASSIVE |

**District 9 Dashboard shows:**
- Feed 1: Hog farm news (any mention of Smithfield, CAFO regulations, Murphy-Brown)
- Feed 2: Agricultural news (USDA, Farm Bureau, crop prices)
- Feed 3: Veterans news (VA, military policy, base news)
- Auto-posts: Hog farm + crop agriculture content queued automatically
- Alerts: ANY hog farm bill in NCGA → immediate red alert to District 9

---

## EXAMPLE: NC HOUSE DISTRICT 35 (Mike Schietzelt — suburban Wake)
**County:** Wake (suburban)

| Rank | Segment | Voters | Dominance Score | CTA Intensity |
|------|---------|--------|----------------|--------------|
| 1 | Soccer Moms | ~28,000 | 89.4 | 🔴 URGENT |
| 2 | Small Business | ~35,000 | 84.2 | 🔴 URGENT |
| 3 | Fiscal Conservative | ~42,000 | 79.6 | 🔴 URGENT |
| 4 | Biotech/Pharma | ~18,000 | 71.2 | 🟠 HIGH |
| 5 | School Choice | ~22,000 | 68.8 | 🟠 HIGH |
| 6 | High Income | ~31,000 | 65.3 | 🟠 HIGH |
| 7 | Women 30-55 | ~38,000 | 61.4 | 🟠 HIGH |
| 8 | Doctors | ~4,200 | 58.7 | 🟠 HIGH |
| 9 | Real Estate | ~8,500 | 42.1 | 🟡 MEDIUM |
| 10 | Seniors | ~18,000 | 38.4 | 🟡 MEDIUM |
| ... | ... | ... | ... | ... |
| 25+ | Hog Farming | ~120 | 0.8 | ⚪ PASSIVE |

**District 35 Dashboard shows:**
- Feed 1: School board / curriculum news (Soccer Moms)
- Feed 2: Small business / tax news
- Feed 3: Fiscal policy / spending news
- Auto-posts: School choice + parental rights content
- Hog farm news: NOT shown (rank 25+ → passive, not relevant here)

---

## QUERY: "What are the top 5 segments in every district?"

```sql
SELECT district_type, district_id, district_name,
    ARRAY_AGG(segment_tag ORDER BY segment_rank_in_district) FILTER (WHERE segment_rank_in_district <= 5) as top_5_segments,
    ARRAY_AGG(cta_intensity ORDER BY segment_rank_in_district) FILTER (WHERE segment_rank_in_district <= 5) as intensities
FROM public.district_microsegment_rankings
WHERE district_type = 'nc_house'
GROUP BY district_type, district_id, district_name
ORDER BY district_id::integer;
```

## QUERY: "Which districts should we target for veteran outreach?"

```sql
SELECT district_id, district_name, segment_voters as veterans,
    district_rank_for_segment as rank_among_all_districts,
    cta_intensity
FROM public.district_microsegment_rankings
WHERE segment_tag = 'veterans'
AND district_type = 'nc_house'
AND district_rank_for_segment <= 20  -- top 20 districts for veterans
ORDER BY district_rank_for_segment;
```

## QUERY: "For candidate in District X — what's their full segment dashboard?"

```sql
SELECT segment_tag, segment_label, segment_voters,
    voter_pct, dominance_score,
    segment_rank_in_district as rank,
    cta_intensity, auto_post, alert_threshold
FROM public.district_microsegment_rankings
WHERE district_type = 'nc_house' AND district_id = '35'
ORDER BY segment_rank_in_district;
```

---

## CANDIDATE BRIEFING FORMAT (auto-generated)

```
DISTRICT 9 MICROSEGMENT BRIEFING — Rep. Brent Jackson
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
YOUR DISTRICT'S POLITICAL DNA:

🔴 URGENT — Your top 3 segments (auto-monitored, auto-posted):
  1. HOG FARMING     18,000 voters  94.2 score  → Any CAFO bill = immediate alert
  2. CROP AGRICULTURE 22,000 voters  87.6 score  → Farm Bureau news auto-posted
  3. VETERANS        8,500 voters   71.3 score  → VA/military news in daily digest

🟠 HIGH — Your next 5 segments (daily monitoring):
  4. Fiscal Conservative  5. 2nd Amendment  6. Pro-Life  7. Social Conservative  8. Sportsmen

🟡 MEDIUM — Monitor weekly:
  9. Faith/Religious  10. Seniors  11. Dairy Farmers  12. Tobacco Farmers

⚪ PASSIVE — Available on request:
  Beach/Coastal, Biotech/Pharma, Soccer Moms, Nurses, Doctors...
  (Low relevance — these segments are small in your district)

YOUR DONOR TARGETS THIS MONTH:
  💰 18 high-income hog farm operators not yet in donor file → outreach list ready
  💰 34 Farm Bureau members who have given to D candidates → persuasion targets
  💰 12 large landowners with no donation history → first-time ask candidates

YOUR VOLUNTEER ARMY:
  🚪 Canvassers available: 847 (veterans + farmers top availability)
  📞 Phone bankers: 312
  🏠 Event hosts: 23 (large farm operations with space)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## ECOSYSTEM INTEGRATION — HOW RANKINGS FEED EVERY SYSTEM

```
district_microsegment_rankings
    ↓
E42 News Intelligence
    → Uses segment_rank_in_district to prioritize which news appears on dashboard
    → Uses alert_threshold to determine when to push notifications
    → Uses auto_post flag to auto-queue content for E19

E19 Social Media
    → Auto-posts content for top-ranked segments (auto_post = true)
    → Hashtags match segment affinity groups for that district

E30 Email / E31 SMS
    → Segment rank determines which appeal goes in next email
    → Rank 1-3 segments get dedicated emails
    → Rank 4-8 get featured sections within broader emails
    → Rank 9+ get brief mentions or are excluded

E38 Field Operations
    → Volunteer deployment prioritized by segment rank × volunteer count
    → Canvassing scripts customized to top 3 ranked segments in precinct

E34 Events
    → Event type matches top 3 segments (Farm tour vs soccer mom coffee vs vet breakfast)
    → Venue selection based on where segment voters are concentrated

E01 Donor Intelligence
    → Donor outreach prioritized by segment rank × wealth indicators
    → Highest-ranked segments get personal outreach
    → Lower-ranked segments get mass email only

E20 Intelligence Brain
    → Morning briefing leads with Rank 1-3 segment news
    → Alert severity tied to segment rank in affected district
```

---

*Prepared by Perplexity AI — March 31, 2026*
*Rankings auto-update monthly after DataTrust refresh*
*Everything modulates from the ranking — news priority, CTA intensity, alert threshold, auto-post, volunteer deployment, donor outreach*
