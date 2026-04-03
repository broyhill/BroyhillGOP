# Campaign Control Panel — Toggle/Timer/AI Control System
## BroyhillGOP — Manual + AI Control for Every Segment, Issue, Person
## Date: March 31, 2026 | Authority: Ed Broyhill

---

## CONCEPT

Every element in the system has three control modes:
- **MANUAL** — candidate/campaign manager flips the switch themselves
- **AI AUTO** — system fires automatically based on rules and triggers
- **TIMER** — scheduled to fire at a specific date/time or after a delay

The control panel is the master dashboard where a candidate can see
every active segment, issue alert, and person touchpoint — and override,
pause, or accelerate any of it with one click.

---

## THE CONTROL PANEL — THREE PANELS

---

## PANEL 1: MICROSEGMENT CONTROLS

Every microsegment has its own row with full controls:

```
┌─────────────────────────────────────────────────────────────────────┐
│ MICROSEGMENT CONTROLS — NC Auditor Boliek / Watauga County          │
├──────────────────────┬───────┬───────┬──────────────┬──────────────┤
│ Segment              │ ON/OFF│ Mode  │ CTA Intensity│ Timer/Trigger│
├──────────────────────┼───────┼───────┼──────────────┼──────────────┤
│ CPAs / Accountants   │  ✅ ON│ AUTO  │ 🔴 Urgent    │ Always on    │
│ Fiscal Conservative  │  ✅ ON│ AUTO  │ 🔴 Urgent    │ Always on    │
│ Small Business       │  ✅ ON│ AUTO  │ 🟠 High      │ Always on    │
│ Lawyers              │  ✅ ON│ MANUAL│ 🟠 High      │ —            │
│ Bankers/Finance      │  ✅ ON│ AUTO  │ 🟠 High      │ Always on    │
│ Seniors              │  ✅ ON│ AUTO  │ 🟡 Medium    │ Always on    │
│ Veterans             │  ✅ ON│ AUTO  │ 🟡 Medium    │ Always on    │
│ Hunters              │  ❌ OFF│ —    │ ⚪ Passive   │ IRRELEVANT   │
│ Soccer Moms          │  ❌ OFF│ —    │ ⚪ Passive   │ IRRELEVANT   │
│ Mountain Resort      │  ❌ OFF│ —    │ ⚪ Passive   │ IRRELEVANT   │
└──────────────────────┴───────┴───────┴──────────────┴──────────────┘

OVERRIDE CONTROLS:
[🔴 Emergency Blast All Active Segments]  [⏸ Pause All]  [▶ Resume All]
[+ Add Custom Segment]  [⚙ Adjust Thresholds]  [📊 Segment Performance]
```

### Segment Toggle Fields in DB:

```sql
CREATE TABLE IF NOT EXISTS public.campaign_segment_controls (
    id                  SERIAL PRIMARY KEY,
    campaign_id         bigint,             -- which candidate/campaign
    office_type         text,               -- 'nc_auditor' etc
    district_type       text,
    district_id         text,
    segment_tag         text,
    -- ON/OFF
    is_active           boolean DEFAULT true,
    is_paused           boolean DEFAULT false,
    paused_at           timestamptz,
    paused_by           text,               -- 'candidate'|'manager'|'system'
    pause_reason        text,
    resume_at           timestamptz,        -- auto-resume timer
    -- Mode
    control_mode        text DEFAULT 'auto', -- 'auto'|'manual'|'timer'|'off'
    -- Intensity override
    cta_intensity_override text,            -- null = use default ranking, else 'urgent'|'high'|'medium'|'low'|'passive'
    -- Timer settings
    timer_start_at      timestamptz,        -- when to activate
    timer_end_at        timestamptz,        -- when to deactivate
    timer_recurrence    text,               -- 'none'|'daily'|'weekly'|'event_based'
    -- AI settings
    ai_auto_post        boolean DEFAULT true,
    ai_alert_threshold  text DEFAULT 'daily',
    ai_post_frequency   text DEFAULT 'as_needed', -- 'daily'|'weekly'|'as_needed'
    -- Performance
    posts_sent          integer DEFAULT 0,
    alerts_fired        integer DEFAULT 0,
    donors_activated    integer DEFAULT 0,
    last_activity_at    timestamptz,
    -- Audit
    created_at          timestamptz DEFAULT NOW(),
    updated_at          timestamptz DEFAULT NOW(),
    updated_by          text
);
```

---

## PANEL 2: ISSUE ALERT CONTROLS

Every issue tag has its own monitoring toggle:

```
┌──────────────────────────────────────────────────────────────────────┐
│ ISSUE ALERT CONTROLS — NC Auditor Boliek                             │
├────────────────────────┬───────┬───────┬──────────┬─────────────────┤
│ Issue                  │ ON/OFF│ Mode  │ Alert    │ Timer           │
├────────────────────────┼───────┼───────┼──────────┼─────────────────┤
│ Government Waste/Fraud │  ✅ ON│ AUTO  │ Immediate│ Always          │
│ Fiscal Conservatism    │  ✅ ON│ AUTO  │ Daily    │ Always          │
│ Helene Disaster $ Track│  ✅ ON│ AUTO  │ Immediate│ Until 12/31/26  │
│ Audit Findings (NCGA)  │  ✅ ON│ AUTO  │ Immediate│ Always          │
│ CPA/Accounting News    │  ✅ ON│ AUTO  │ Weekly   │ Always          │
│ Property Tax Reform    │  ✅ ON│ AUTO  │ Weekly   │ Always          │
│ School Board Issues    │  ❌ OFF│  —   │ Off      │ — (irrelevant)  │
│ Hunting Regulations    │  ❌ OFF│  —   │ Off      │ — (irrelevant)  │
│ Hog Farm Regulations   │  ❌ OFF│  —   │ Off      │ — (irrelevant)  │
│ [ELECTION MODE] All R+ │  ⏱ TIMER│ Timer│ Immediate│ Oct 1-Nov 3    │
└────────────────────────┴───────┴───────┴──────────┴─────────────────┘

[⚡ Emergency: Blast issue alert NOW]  [+ Add Custom Issue Monitor]
[📅 Schedule Issue Campaign]  [🔇 Mute issue for X days]
```

### Issue Control DB Table:

```sql
CREATE TABLE IF NOT EXISTS public.campaign_issue_controls (
    id                  SERIAL PRIMARY KEY,
    campaign_id         bigint,
    issue_tag           text,
    is_active           boolean DEFAULT true,
    control_mode        text DEFAULT 'auto',
    alert_threshold     text DEFAULT 'daily',  -- 'immediate'|'daily'|'weekly'|'off'
    -- Timer
    active_from         timestamptz,
    active_until        timestamptz,
    -- Response template
    auto_response_template text,               -- AI uses this to draft response when issue fires
    escalate_to_candidate  boolean DEFAULT false, -- ping candidate directly on this issue
    -- Blackout periods
    blackout_start      timestamptz,           -- suppress alerts during this window
    blackout_end        timestamptz,
    blackout_reason     text,
    -- Performance
    alerts_sent         integer DEFAULT 0,
    responses_drafted   integer DEFAULT 0,
    posts_generated     integer DEFAULT 0
);
```

---

## PANEL 3: PERSON CONTROLS

Every donor, influencer, and volunteer has individual controls:

```
┌──────────────────────────────────────────────────────────────────────┐
│ PERSON CONTROLS — High-Value Targets                                  │
├────────────────────────┬──────┬──────┬────────────┬─────────────────┤
│ Person                 │ Mode │ Stage│ Next Action│ Timer           │
├────────────────────────┼──────┼──────┼────────────┼─────────────────┤
│ [CPA Partner, Boone]   │ AUTO │ Warm │ Email invite│ 3 days         │
│ [Bank VP, Blowing Rock]│MANUAL│ Cold │ Research   │ —               │
│ [Retired CFO, Boone]   │ AUTO │ Hot  │ Ask call   │ Tomorrow 10am   │
│ [Atty, Banner Elk]     │ TIMER│ Warm │ Event invite│ Oct 15 (event) │
│ [Known donor - gave $5K│ AUTO │ VIP  │ Thank you  │ Fired ✅        │
│ [Influencer - top CPA] │ AUTO │ Host │ Host ask   │ This week       │
└────────────────────────┴──────┴──────┴────────────┴─────────────────┘

[+ Add Person]  [📞 Generate Call List]  [✉️ Draft All Pending Emails]
[🎯 Run AI Outreach Now]  [⏸ Pause All Outreach]
```

### Person Control DB Table:

```sql
CREATE TABLE IF NOT EXISTS public.campaign_person_controls (
    id                  SERIAL PRIMARY KEY,
    campaign_id         bigint,
    person_id           bigint REFERENCES core.person_spine(person_id),
    -- Mode
    control_mode        text DEFAULT 'auto',  -- 'auto'|'manual'|'timer'|'paused'|'do_not_contact'
    -- Outreach stage
    outreach_stage      text DEFAULT 'cold',  -- 'cold'|'warm'|'hot'|'vip'|'host'|'committed'|'declined'
    -- Next action
    next_action_type    text,   -- 'email'|'call'|'event_invite'|'thank_you'|'ask'|'host_ask'
    next_action_due     timestamptz,
    next_action_notes   text,
    -- Timer
    outreach_delay_days integer DEFAULT 0,    -- wait X days before contacting
    contact_frequency   text DEFAULT 'weekly',-- how often AI can contact
    last_contacted_at   timestamptz,
    -- Ask settings
    ask_amount          numeric,              -- target ask amount
    ask_ready           boolean DEFAULT false,
    ask_approved_by     text,                 -- candidate or manager must approve ask
    -- Do not contact
    dnc_reason          text,
    dnc_until           timestamptz,          -- temporary DNC with auto-lift
    -- AI settings
    ai_can_email        boolean DEFAULT true,
    ai_can_sms          boolean DEFAULT false,-- higher bar for SMS
    ai_can_generate_ask boolean DEFAULT false,-- candidate must approve ask letter
    -- Escalation
    escalate_to_candidate boolean DEFAULT false, -- candidate personally handles this one
    candidate_notes     text,                 -- candidate's personal notes
    -- Performance
    emails_sent         integer DEFAULT 0,
    calls_logged        integer DEFAULT 0,
    events_attended     integer DEFAULT 0,
    total_given         numeric DEFAULT 0
);
```

---

## THE TIMER SYSTEM — KEY USE CASES

```sql
CREATE TABLE IF NOT EXISTS public.campaign_timers (
    id              SERIAL PRIMARY KEY,
    campaign_id     bigint,
    timer_name      text,
    timer_type      text,   -- 'segment_activate'|'issue_boost'|'person_outreach'|
                            --  'event_countdown'|'election_mode'|'blackout'|'follow_up'
    -- What it controls
    target_type     text,   -- 'segment'|'issue'|'person'|'all'
    target_id       text,   -- segment_tag, issue_tag, person_id, or 'ALL'
    -- Timing
    fires_at        timestamptz,        -- exact datetime
    fires_after_days integer,           -- relative delay from trigger
    trigger_event   text,               -- 'event_attended'|'donation_received'|'email_opened'|'date'
    recurs          boolean DEFAULT false,
    recurrence_rule text,               -- cron expression
    -- Action
    action          text,               -- what happens when timer fires
    action_params   jsonb,              -- parameters for the action
    -- Status
    status          text DEFAULT 'pending', -- 'pending'|'fired'|'cancelled'|'paused'
    fired_at        timestamptz,
    -- Audit
    created_by      text,
    created_at      timestamptz DEFAULT NOW()
);
```

### Timer Examples:

```sql
-- Timer 1: Activate "Election Mode" Oct 1 — turn everything to urgent
INSERT INTO campaign_timers (timer_name, timer_type, target_type, fires_at, action) VALUES
('Election Mode Activate', 'segment_activate', 'all', '2026-10-01 00:00:00', 
 'SET all segment cta_intensity = urgent, ai_post_frequency = daily');

-- Timer 2: Follow up with event attendees 3 days after event
INSERT INTO campaign_timers (timer_name, timer_type, target_type, fires_after_days, trigger_event, action) VALUES
('Post-Event Follow Up', 'person_outreach', 'person', 3, 'event_attended',
 'SEND thank_you_email + SET next_action = ask, next_action_due = NOW() + 7 days');

-- Timer 3: Thank you within 24hrs of donation
INSERT INTO campaign_timers (timer_name, timer_type, target_type, fires_after_days, trigger_event, action) VALUES
('Donation Thank You', 'person_outreach', 'person', 0, 'donation_received',
 'SEND thank_you_email IMMEDIATELY, SET stage = vip if amount > 1000');

-- Timer 4: Helene recovery monitoring ends Dec 31 2026
INSERT INTO campaign_timers (timer_name, timer_type, target_type, fires_at, action) VALUES
('End Helene Monitoring', 'issue_boost', 'issue', '2026-12-31 23:59:59',
 'SET issue disaster_recovery active = false');

-- Timer 5: Mute all outreach 2 weeks before election (let field ops run)
INSERT INTO campaign_timers (timer_name, timer_type, target_type, fires_at, action) VALUES
('Pre-Election Blackout Start', 'blackout', 'all', '2026-10-20 00:00:00',
 'SET all ai_can_email = false, ai_can_sms = false');
INSERT INTO campaign_timers (timer_name, timer_type, target_type, fires_at, action) VALUES
('Election Day - Resume', 'blackout', 'all', '2026-11-03 06:00:00',
 'SET all ai_can_email = true');
```

---

## CANDIDATE vs MANAGER vs AI PERMISSIONS

```sql
CREATE TABLE IF NOT EXISTS public.campaign_permissions (
    campaign_id     bigint,
    user_type       text,   -- 'candidate'|'campaign_manager'|'finance_director'|'ai'
    -- What they can do
    can_toggle_segments     boolean DEFAULT false,
    can_override_intensity  boolean DEFAULT false,
    can_approve_asks        boolean DEFAULT false,
    can_send_email          boolean DEFAULT false,
    can_send_sms            boolean DEFAULT false,
    can_auto_post_social    boolean DEFAULT false,
    can_add_people          boolean DEFAULT false,
    can_set_timers          boolean DEFAULT false,
    can_pause_all           boolean DEFAULT false,
    can_view_all_contacts   boolean DEFAULT false,
    -- Ask approval thresholds
    ask_auto_approve_under  numeric DEFAULT 0,    -- AI can send asks under this amount without approval
    ask_requires_review_over numeric DEFAULT 500  -- Manual review required over this amount
);

-- Candidate: full control + ask approval
-- Manager: operational control, no major ask approval
-- Finance Director: donor controls + ask letters
-- AI: execute approved rules only, flag for review when uncertain
```

---

## CONTROL PANEL UI SUMMARY

```
CAMPAIGN COMMAND CENTER — Dave Boliek / NC Auditor
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STATUS: 🟢 ACTIVE | Mode: AI AUTO | Next election: 218 days

PANELS:
[📊 Microsegments] [🎯 Issues] [👤 People] [⏱ Timers] [📈 Performance]

QUICK CONTROLS:
[🔴 EMERGENCY BLAST]  [⏸ PAUSE ALL]  [🔇 BLACKOUT MODE]
[⚡ BOOST: Election Mode]  [📅 Schedule Campaign]

ACTIVE RIGHT NOW:
  ✅ 7 segments monitoring
  ✅ 5 issue alerts active
  ✅ 23 people in outreach queue
  ⏱ 4 timers pending
  🤖 AI: 3 emails drafted, awaiting approval
  🚨 2 alerts need your review

TODAY'S ACTIONS NEEDED:
  → [Approve thank-you to $2,500 donor in Boone]
  → [Review: CPA firm partner added to list — confirm relevance]
  → [Timer: Post-event follow-up fires in 6 hours — preview?]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## E40 AUTOMATION CONTROL PANEL — THE ECOSYSTEM HOME

This spec is the core of E40 (Automation Control Panel ecosystem).
Every other ecosystem plugs into these controls:

```
E40 Control Panel
  ↓ controls
  E42 News Intelligence  → issue_controls (on/off/intensity/timer)
  E30 Email Campaigns    → person_controls (ai_can_email, frequency)
  E31 SMS Marketing      → person_controls (ai_can_sms — higher bar)
  E19 Social Media       → segment_controls (ai_auto_post, frequency)
  E38 Field Operations   → segment_controls (volunteer deployment)
  E34 Events             → timers (event countdown, follow-up)
  E01 Donor Intelligence → person_controls (ask_amount, stage)
  E20 Intelligence Brain → all controls (reads state, suggests actions)
```

---

*Prepared by Perplexity AI — March 31, 2026*
*Three panels: Segment controls, Issue controls, Person controls*
*Three modes: Manual, AI Auto, Timer*
*Candidate controls the levers. AI executes within approved boundaries.*
*E40 Automation Control Panel is the home ecosystem for all of this.*

---

## PANEL 4: CANDIDATE STANCE CONTROLS

Every issue has a STANCE — not just on/off. And every person can be flagged.

---

### ISSUE STANCE SETTINGS

```sql
ALTER TABLE public.campaign_issue_controls ADD COLUMN IF NOT EXISTS
    candidate_stance    text DEFAULT 'neutral',
    -- Values:
    --   'champion'    -- candidate actively promotes this issue
    --   'supportive'  -- supports but not a lead issue
    --   'neutral'     -- no public position, dodge if asked
    --   'avoiding'    -- actively dodging, do not surface in content
    --   'opposed'     -- candidate opposes this (rare for R issues)
    --   'conflicted'  -- internal conflict, needs careful handling
    --   'developing'  -- position not yet set, research in progress

    stance_public_statement text,  -- approved talking points IF asked
    stance_internal_notes   text,  -- why they're taking this stance (not public)
    dodge_language          text,  -- exact language to use when dodging
    no_go_topics            text[], -- specific sub-topics to NEVER touch
    escalate_if_asked       boolean DEFAULT false; -- flag candidate immediately if media asks
```

### Dashboard View with Stances:

```
┌──────────────────────────────────────────────────────────────────────┐
│ ISSUE STANCE CONTROLS — NC Auditor Boliek                            │
├─────────────────────────┬────────────┬──────────┬───────────────────┤
│ Issue                   │ Stance     │ Promote? │ If Asked...       │
├─────────────────────────┼────────────┼──────────┼───────────────────┤
│ Government Waste/Fraud  │ 🟢 CHAMPION│ YES - max│ Full statement    │
│ Fiscal Conservatism     │ 🟢 CHAMPION│ YES - max│ Full statement    │
│ Helene Recovery Audit   │ 🟢 CHAMPION│ YES - max│ Full statement    │
│ Abortion (state)        │ 🟡 NEUTRAL │ NO       │ "Not my office"   │
│ Gun Control             │ 🟡 NEUTRAL │ NO       │ "Not my office"   │
│ NCAE / Teacher unions   │ 🟡 AVOIDING│ NO       │ Dodge - redirect  │
│ App State budget cuts   │ 🔴 AVOIDING│ NEVER    │ "I audit all orgs"│
│ [Specific developer]    │ 🚫 CONFLICT│ BLOCKED  │ Escalate to mgr   │
│ Certificate of Need     │ 🟡 NEUTRAL │ NO       │ "I'd audit CON"   │
└─────────────────────────┴────────────┴──────────┴───────────────────┘
```

---

### PERSON CONFLICT FLAGS

Every person in the system can be flagged with a relationship status
that controls how the AI and campaign handle them:

```sql
ALTER TABLE public.campaign_person_controls ADD COLUMN IF NOT EXISTS
    relationship_flag   text DEFAULT 'normal',
    -- Values:
    --   'normal'        -- standard outreach
    --   'vip'           -- white glove treatment, candidate handles personally
    --   'friendly'      -- supportive, warm relationship
    --   'neutral'       -- no strong relationship either way
    --   'cautious'      -- handle carefully, don't assume support
    --   'do_not_contact'-- never contact, for any reason
    --   'adversarial'   -- known opponent, active conflict
    --   'conflict_of_interest' -- legal/ethical issue, flag counsel
    --   'media_hostile' -- known hostile journalist/blogger
    --   'former_ally_turned'  -- was friendly, now opposed
    --   'competitor_donor'    -- donates to opponent
    --   'pending_litigation'  -- in a lawsuit with campaign/candidate
    --   'sensitive'     -- handle with extreme care, reason in notes

    flag_reason         text,    -- WHY this flag (internal only, never shown)
    flag_set_by         text,    -- 'candidate'|'manager'|'counsel'
    flag_date           date,
    ai_can_contact      boolean GENERATED ALWAYS AS (
                            relationship_flag NOT IN (
                                'do_not_contact','adversarial',
                                'conflict_of_interest','pending_litigation'
                            )
                        ) STORED,
    requires_candidate_approval boolean GENERATED ALWAYS AS (
                            relationship_flag IN ('vip','sensitive','cautious')
                        ) STORED,
    legal_hold          boolean DEFAULT false,  -- counsel flagged — no contact
    legal_notes         text;   -- counsel notes (privileged, restricted access)
```

### Person Flag Dashboard:

```
┌──────────────────────────────────────────────────────────────────────┐
│ FLAGGED PERSONS — Boliek / Watauga                                    │
├──────────────────────────┬────────────────────┬──────────┬──────────┤
│ Person                   │ Flag               │ AI can?  │ Who acts │
├──────────────────────────┼────────────────────┼──────────┼──────────┤
│ [Large CPA firm partner] │ 🟢 VIP             │ No       │ Candidate│
│ [Bank VP - Blowing Rock] │ 🟡 CAUTIOUS        │ Limited  │ Manager  │
│ [Developer - known D]    │ 🔴 COMPETITOR DONOR│ No       │ Nobody   │
│ [Journalist - NC Policy] │ 🔴 MEDIA HOSTILE   │ No       │ Campaign │
│ [Former ally turned oppo]│ 🔴 ADVERSARIAL     │ No       │ Nobody   │
│ [Pending lawsuit party]  │ ⚖️ LITIGATION      │ BLOCKED  │ Counsel  │
│ [Sensitive - see notes]  │ 🔒 SENSITIVE       │ No       │ Candidate│
└──────────────────────────┴────────────────────┴──────────┴──────────┘

[+ Flag Person]  [🔒 View Restricted Flags]  [⚖️ Legal Hold List]
```

---

## AI BEHAVIOR RULES — STANCE + FLAG AWARE

```
IF issue.candidate_stance = 'neutral' OR 'avoiding':
  → DO NOT include in auto-posts
  → DO NOT generate content on this issue
  → IF media query detected on this issue → ESCALATE to candidate immediately
  → Use dodge_language if direct question

IF issue.candidate_stance = 'conflicted':
  → PAUSE all automated content on this issue
  → Flag for candidate review before any action
  → Do not respond to social media questions on this topic

IF person.relationship_flag = 'do_not_contact':
  → BLOCK all outreach, email, SMS, event invites
  → Remove from all lists silently
  → Do not show in any campaign reports
  → Log attempt if somehow triggered

IF person.relationship_flag = 'adversarial':
  → Monitor their social media (E42) — know what they're saying
  → Do NOT engage or respond directly
  → Flag any attacks for rapid response team
  → Never include in any outreach

IF person.relationship_flag = 'conflict_of_interest':
  → Legal hold — zero contact
  → Alert campaign counsel immediately
  → Log everything

IF person.relationship_flag = 'vip' AND action = 'ask':
  → STOP — do not auto-generate ask
  → Draft ask for candidate personal review
  → Candidate must approve AND make the call personally
  → No email asks for VIPs — phone only

IF person.relationship_flag = 'cautious':
  → Require manager approval before any outreach
  → Lower ask amount by 50%
  → No SMS — email only
  → Flag if they open email (signals interest)
```

---

## THE CONFLICT DETECTION SYSTEM

AI automatically flags potential conflicts before they become problems:

```sql
CREATE TABLE IF NOT EXISTS public.conflict_alerts (
    id              SERIAL PRIMARY KEY,
    campaign_id     bigint,
    alert_type      text,
    -- 'donor_opponent'     — person just gave to opponent
    -- 'issue_contradiction' — candidate has two conflicting stances
    -- 'media_inquiry'      — hostile media asking about this issue
    -- 'litigation_risk'    — person is in legal dispute with related party
    -- 'regulatory_flag'    — FEC/SBOE compliance issue detected
    -- 'relationship_change' — former ally now posting against candidate
    person_id       bigint,
    issue_tag       text,
    description     text,
    severity        text,   -- 'low'|'medium'|'high'|'critical'
    detected_at     timestamptz DEFAULT NOW(),
    reviewed        boolean DEFAULT false,
    reviewed_by     text,
    resolution      text,
    resolved_at     timestamptz
);
```

### Conflict Alert Examples:

```
🚨 CONFLICT ALERTS — Boliek Campaign
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 CRITICAL: [Bank VP, Blowing Rock] just maxed out to your opponent ($5,400)
   → Auto-flagged as COMPETITOR DONOR. Removed from outreach.
   → [Confirm] [Review] [Escalate]

🟠 HIGH: Hostile journalist (@NCPolicyWatch) tweeted about your audit position
   → Issue: government_waste | Stance: champion — OK to respond
   → AI draft response ready | [Review Response] [Ignore] [Escalate]

🟡 MEDIUM: [Former ally] changed social media bio — removed your endorsement
   → Relationship status changed: friendly → cautious
   → [Confirm Change] [Reach Out Personally] [Flag Adversarial]

🟡 MEDIUM: You have conflicting stances detected:
   → Issue: App_State_budget = avoiding
   → Issue: university_grants = champion
   → These may conflict if pressed. Recommend unified talking point.
   → [Review Stances] [Draft Unified Position] [Ask Candidate]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

*Updated March 31, 2026 — Stance controls and person conflict flags added*
*AI is stance-aware and flag-aware — never promotes neutral/avoiding issues*
*Legal hold and adversarial flags completely block AI contact*
*Conflict detection system surfaces problems before they become crises*

---

## MANUAL PRIORITY OVERRIDE

The AI calculates dominance scores from DataTrust data.
The candidate can override any segment's rank manually — permanently or temporarily.

### Why a candidate overrides:

| Scenario | What they do |
|----------|-------------|
| "I just met a CPA who runs the county association — they're my #1 target now" | Promote CPAs to rank 1 manually |
| "There's a big veterans event next month — boost veterans until then" | Temporary boost with timer |
| "I had a bad experience with a local lawyer group — dial them back" | Demote lawyers manually |
| "The Helene disaster is my signature issue right now" | Promote fiscal_conservative + disaster_recovery to top |
| "We're in the homestretch — everything goes to fiscal conservative messaging only" | Demote all others, lock fiscal conservative at #1 |

---

### DB FIELDS — Add to campaign_segment_controls:

```sql
ALTER TABLE public.campaign_segment_controls ADD COLUMN IF NOT EXISTS
    -- Manual rank override
    manual_rank_override    integer,        -- null = use AI rank, 1-99 = candidate override
    override_set_by         text,           -- 'candidate'|'manager'
    override_set_at         timestamptz,
    override_reason         text,           -- why they overrode (internal note)
    override_expires_at     timestamptz,    -- null = permanent, else auto-reverts to AI rank
    override_is_temporary   boolean DEFAULT false,

    -- Boost/suppress controls
    boost_multiplier        numeric DEFAULT 1.0,  -- 1.5 = 50% intensity boost, 0.5 = half intensity
    is_pinned_top           boolean DEFAULT false, -- always appears first regardless of score
    is_suppressed           boolean DEFAULT false; -- pushed to bottom regardless of score
```

### Control Panel Override UI:

```
┌──────────────────────────────────────────────────────────────────────┐
│ SEGMENT PRIORITY — Boliek / Watauga County          [AI] [MANUAL]   │
├──────────────────────┬──────┬──────────┬───────────┬────────────────┤
│ Segment              │ AI # │ Manual # │ Final #   │ Override       │
├──────────────────────┼──────┼──────────┼───────────┼────────────────┤
│ 📌 Fiscal Conserv.  │  2   │  1 (PIN) │  🥇 1     │ Pinned by cand │
│ 📌 Helene Disaster  │  8   │  2 (TEMP)│  🥈 2     │ Boosted - 30d  │
│    CPAs/Accountants  │  1   │  —       │  🥉 3     │ AI rank        │
│    Small Business    │  3   │  —       │     4     │ AI rank        │
│    Bankers/Finance   │  4   │  —       │     5     │ AI rank        │
│ ⬇️  Lawyers         │  5   │  9 (↓)   │     9     │ Demoted by mgr │
│    Seniors           │  6   │  —       │     6     │ AI rank        │
│    Veterans          │  7   │  —       │     7     │ AI rank        │
└──────────────────────┴──────┴──────────┴───────────┴────────────────┘

[↑ Promote]  [↓ Demote]  [📌 Pin Top]  [⬇️ Suppress]
[⏱ Temp Boost: +X days]  [↩ Reset to AI]  [↩ Reset All]
```

---

### Override Logic in Query:

```sql
-- Final rank = manual override if set, else AI-calculated rank
SELECT
    segment_tag,
    COALESCE(manual_rank_override, segment_rank_in_district) as final_rank,
    CASE
        WHEN is_pinned_top THEN 'PINNED'
        WHEN manual_rank_override IS NOT NULL
             AND (override_expires_at IS NULL OR override_expires_at > NOW())
            THEN 'MANUAL (' || override_set_by || ')'
        ELSE 'AI'
    END as rank_source,
    dominance_score * boost_multiplier as adjusted_score,
    cta_intensity
FROM public.campaign_segment_controls csc
JOIN public.district_microsegment_rankings dmr
    ON dmr.segment_tag = csc.segment_tag
    AND dmr.district_id = 'WATAUGA'
WHERE csc.campaign_id = [boliek_campaign_id]
AND csc.is_active = true
AND NOT csc.is_suppressed
ORDER BY
    is_pinned_top DESC,              -- pinned always first
    COALESCE(manual_rank_override,
             segment_rank_in_district) ASC;  -- then manual, then AI
```

---

### Timer-Based Temporary Boosts:

```sql
-- "Boost veterans segment for 30 days around Veterans Day"
INSERT INTO campaign_timers (timer_name, timer_type, target_id, fires_at, action, action_params) VALUES
('Veterans Day Boost Start', 'segment_activate', 'veterans',
 '2026-11-01 00:00:00', 'BOOST_SEGMENT',
 '{"boost_multiplier": 2.0, "manual_rank_override": 1, "override_expires_at": "2026-11-15"}'),

('Veterans Day Boost End', 'segment_activate', 'veterans',
 '2026-11-15 00:00:00', 'RESET_SEGMENT_TO_AI', '{}');

-- "Pin Helene disaster recovery to top for next 60 days"
UPDATE campaign_segment_controls SET
    is_pinned_top = true,
    manual_rank_override = 1,
    override_set_by = 'candidate',
    override_reason = 'Helene recovery is my signature issue this quarter',
    override_expires_at = NOW() + interval '60 days',
    override_is_temporary = true
WHERE campaign_id = [boliek_id] AND segment_tag = 'disaster_recovery';
```

---

*Updated March 31, 2026 — Manual priority override added*
*Candidate or manager can pin, boost, demote, or suppress any segment*
*Temporary overrides auto-expire back to AI rank on schedule*
*Final rank = PIN first, then manual override, then AI calculated*
