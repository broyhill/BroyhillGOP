# E58 Finance Committee — Integration Plan

## Overview

E58 is the candidate Finance Committee ecosystem. It identifies, recruits, deploys, and tracks fundraising leadership teams for every candidate on the platform — from US Senate to school board.

## Data Flow Architecture

```
INPUTS                          E58 CORE                        OUTPUTS
─────────────────────          ───────────────                  ──────────────────
                                                                
person_spine ──────┐            ┌──────────────┐                ──→ Candidate Command Center (E24)
contribution_map ──┤            │              │                ──→ Intelligence Brain (E20)
nc_datatrust ──────┤───────────→│  DISTRICT    │                ──→ ML Clustering (E21)
candidate_profiles ┤            │  AUDITOR     │                ──→ Agent Mesh (E59)
election_results ──┘            │              │                ──→ Analytics Dashboard (E29)
                                └──────┬───────┘                ──→ Automation Control (E40)
                                       │                        ──→ Email Campaigns (E30)
                                       ▼                        ──→ SMS Marketing (E31)
                                ┌──────────────┐
                                │  BUDGET      │
                                │  ENGINE      │
                                └──────┬───────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                   ▼
             ┌────────────┐    ┌────────────┐     ┌────────────┐
             │ COMMITTEE  │    │    AI       │     │QUESTIONNAIRE│
             │ MANAGER    │    │ RECOMMENDER │     │ PROCESSOR   │
             └─────┬──────┘    └─────┬──────┘     └──────┬──────┘
                   │                 │                    │
                   ▼                 ▼                    │
             ┌────────────┐    ┌────────────┐            │
             │ PROSPECT   │    │ EVENT      │◄───────────┘
             │ TRACKER    │    │COORDINATOR │
             └─────┬──────┘    └─────┬──────┘
                   │                 │
                   ▼                 ▼
             ┌────────────────────────────┐
             │    PERFORMANCE ENGINE      │
             │  (daily snapshots, weekly  │
             │   reports, scoring, pace)  │
             └────────────┬───────────────┘
                          │
                    ┌─────┴─────┐
                    ▼           ▼
             ┌──────────┐ ┌──────────┐
             │  BRAIN   │ │ CONTROL  │
             │CONNECTOR │ │  PANEL   │
             └──────────┘ └──────────┘
```

## Integration Points

### INBOUND (Data E58 Reads)

| Source | Table/View | What E58 Uses It For |
|--------|-----------|---------------------|
| Core Data | core.person_spine | Donor identification, lifetime giving, district mapping |
| Core Data | core.contribution_map | Giving history, source attribution, committee loyalty |
| Voter File | public.nc_datatrust | Voter registration, party affiliation, turnout history |
| Candidates | public.candidate_profiles | Candidate info, office type, district |
| Contacts | public.contacts | Contact details for committee member matching |
| E04 Activist | activist network data | PAC connections, activism intensity |
| E07 Issues | issue tracking data | District issue salience for targeting |
| E20 Brain | agent_brain_directives | AI directives for committee adjustments |
| E52 Contact Intel | enrichment data | Apollo.io, BetterContact enrichment for prospects |

### OUTBOUND (Data E58 Produces)

| Destination | What E58 Sends | Purpose |
|-------------|---------------|---------|
| E20 Intelligence Brain | Committee performance metrics, pace alerts | Brain decides when to intervene |
| E21 ML Clustering | Member performance data, donor response patterns | Pattern detection, predictive models |
| E24 Candidate Portal | Committee dashboard, member roster, pace gauge | Candidate's command center view |
| E29 Analytics Dashboard | Fundraising performance across all candidates | Platform-wide reporting |
| E30 Email | Event invitations, fundraising appeals | Automated outreach from committee |
| E31 SMS | Meeting reminders, milestone alerts | Real-time notifications to committee |
| E40 Automation | Trigger workflows (stale prospect → reminder, goal hit → celebration) | Automated actions |
| E59 Agent Mesh | Health metrics, error events, performance data | Monitoring and alerting |

## E20 Brain Integration Rules

### Triggers E58 Sends to Brain

| Trigger | Condition | Brain Action |
|---------|-----------|-------------|
| `fc_pace_critical` | Pace ratio < 0.7 for 7+ consecutive days | Recommend target adjustment or committee expansion |
| `fc_member_inactive` | Member has zero activity for 21+ days | Flag for removal or reassignment |
| `fc_chair_vacant` | Committee has no active Finance Chair | CRITICAL: escalate to candidate immediately |
| `fc_event_underperform` | Event revenue < 50% of goal | Suggest follow-up strategy or additional events |
| `fc_bundler_overperform` | Bundler exceeds pledge by 150%+ | Recommend promotion to Vice Chair |
| `fc_prospect_stale` | 50%+ prospects with no activity in 14 days | Recommend pipeline refresh or reassignment |
| `fc_budget_exceeded` | Raised > 100% of budget target | Recommend budget reallocation or race upgrade |
| `fc_election_30_day` | 30 days to election, < 80% of goal raised | CRITICAL: emergency fundraising push |

### Directives Brain Sends to E58

| Directive | Action | Approval Required |
|-----------|--------|-------------------|
| `adjust_target` | Change member weekly target up or down | No (auto-execute) |
| `recommend_recruit` | Suggest new committee member from AI pool | Yes (candidate approves) |
| `flag_underperformer` | Mark member as behind, trigger check-in | No (auto-flag) |
| `suggest_event` | Recommend new fundraising event | Yes (candidate approves) |
| `reallocate_goals` | Shift fundraising load between members | Yes (chair approves) |
| `escalate_to_candidate` | Direct message to candidate about critical issue | No (auto-send) |

## District Audit Algorithm

### Difficulty Score (D1-D10)

```
D = weighted_average(
    partisan_lean_penalty     * 0.30,   -- D+5 = D8, R+10 = D2
    opponent_strength         * 0.25,   -- incumbent + war chest = harder
    historical_volatility     * 0.15,   -- swing districts = harder
    turnout_unpredictability  * 0.10,   -- low/variable turnout = harder
    media_market_cost         * 0.10,   -- expensive media = harder
    candidate_name_recognition * 0.10   -- unknown candidate = harder
)
```

### Republican Baseline (R1-R10)

```
R = weighted_average(
    r_voter_registration_pct  * 0.25,   -- raw R registration advantage
    avg_r_performance_3_cycles * 0.30,  -- how R candidates performed
    trump_margin              * 0.20,   -- presidential R performance
    r_donor_density           * 0.15,   -- R donors per 1000 voters
    r_volunteer_density       * 0.10    -- R volunteers per 1000 voters
)
```

### Budget Estimation

```
budget_mid = base_cost[office_tier] * difficulty_multiplier * media_market_multiplier
budget_low = budget_mid * 0.7
budget_high = budget_mid * 1.4

difficulty_multiplier:
  D1-D2: 0.6   (safe seat, minimal spend)
  D3-D4: 0.8   (lean R, moderate spend)
  D5-D6: 1.0   (toss-up, full spend)
  D7-D8: 1.2   (lean D, extra effort)
  D9-D10: 1.5  (deep D, maximum effort or strategic write-off)

base_cost[tier]:
  federal:      $2,000,000 (House), $15,000,000 (Senate)
  statewide:    $5,000,000 (Governor), $1,000,000 (Council of State)
  state_leg:    $150,000 (House), $300,000 (Senate)
  county:       $50,000
  municipal_lg: $100,000
  municipal_sm: $10,000
  judicial:     $200,000 (Supreme Court), $50,000 (lower courts)
  special:      $5,000
```

## Committee Sizing Algorithm

```
Given: total_budget, tier_code

bundler_count = ceil((budget * 0.60) / avg_bundler_goal[tier])
host_count    = ceil((budget * 0.30) / avg_event_revenue[tier])
vice_chairs   = ceil(bundler_count / 4.5)
members       = ceil((bundlers + hosts + vice_chairs) * 0.25)
total         = 1 (chair) + vice_chairs + bundlers + hosts + members
total         = clamp(total, tier.min_committee_size, tier.max_committee_size)
```

## Weekly Goal Distribution

```
For each bundler:
  weekly_goal = fundraising_pledge / weeks_remaining
  adjusted_weekly = weekly_goal * early_weight_factor

early_weight_factor:
  weeks 1-8:   1.15  (front-load)
  weeks 9-16:  1.00  (steady state)
  weeks 17-24: 0.90  (winding down, events taper)
  weeks 25+:   0.85  (final stretch, direct asks only)
```

## Performance Scoring (0-100)

| Component | Points | Criteria |
|-----------|--------|----------|
| Personal gift | 20 | received=20, pledged=10, pending=0 |
| Fundraising progress | 40 | (raised / pledge) * 40, capped at 40 |
| Activity | 20 | events attended (2.5 ea), hosted (5 ea), asks (0.5 ea), intros (1 ea) |
| Meeting attendance | 10 | (attended / total) * 10 |
| Consistency | 10 | weeks with $>0 received * 2, capped at 10 |

### Grade Scale

| Grade | Score | Status Color |
|-------|-------|-------------|
| A+ | 95-100 | Green (star) |
| A | 85-94 | Green (on_track) |
| B | 75-84 | Green (on_track) |
| C | 60-74 | Yellow (behind) |
| D | 40-59 | Yellow (behind) |
| F | <40 | Red (inactive) |

## Deployment Sequence

1. **Run SQL schema** against Supabase (001_e58_finance_committee_schema.sql)
2. **Verify tables created** (13 tables, 40+ indexes, 6 triggers, 3 functions, 2 views)
3. **Install Python dependencies** on Hetzner (see requirements.txt)
4. **Set environment variables** (SUPABASE_URL, SUPABASE_KEY, etc.)
5. **Start E58 API** (`uvicorn ecosystem_58_finance_committee_complete:app --host 0.0.0.0 --port 8058`)
6. **Deploy control panel** (serve e58_control_panel.html or deploy to Vercel)
7. **Register with E59 Agent Mesh** (add E58 to agent_registry)
8. **Configure E20 Brain rules** (add trigger definitions)
9. **Run first district audits** (populate fc_district_audit for all active districts)
10. **Enable AI recommendations** (populate fc_ai_recommendations from donor data)

## File Manifest

| File | Lines | Purpose |
|------|-------|---------|
| sql/001_e58_finance_committee_schema.sql | ~650 | 13 tables, indexes, triggers, functions, views, RLS |
| agents/ecosystem_58_finance_committee_complete.py | ~1800 | Complete Python module with 10 classes, 26+ API endpoints |
| panel/e58_control_panel.html | ~1850 | Single-file SPA control panel with 6 tabs |
| INTEGRATION_PLAN.md | this file | Architecture, data flow, algorithms, deployment |
| requirements.txt | ~15 | Python dependencies |
| README.md | ~200 | Overview and quick start |
