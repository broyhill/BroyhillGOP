# E58 — Finance Committee Ecosystem

## What This Does

Every candidate needs a Finance Committee — a structured volunteer leadership team that drives fundraising. E58 automates the entire lifecycle: analyzing the district, estimating the budget needed to win, sizing the committee, recommending recruits from donor data, tracking every member's weekly performance, and keeping the candidate on pace day by day until election day.

## How It Works

1. **District Audit** — The system analyzes the district using voter file, donor history, and election data. It scores difficulty (D1-D10) and Republican baseline (R1-R10), estimates the budget required to win, and identifies the top microsegments and donor pools.

2. **Budget Plan** — From the district audit, E58 calculates a total fundraising budget, breaks it into daily and weekly targets with early-weighting, and determines how many bundlers, hosts, and Vice Chairs the candidate needs.

3. **Candidate Questionnaire** — During onboarding, the candidate nominates their Finance Chair, proposes committee members, and identifies event hosts and key relationships. The platform merges these with AI-recommended recruits from the donor database.

4. **Committee Formation** — The Finance Committee is assembled with roles assigned: Chair, Vice Chairs (by geography/industry), Bundlers (with individual pledge goals), Event Hosts, and general Members. Each person gets a weekly target.

5. **Weekly Tracking** — Every week, the system generates performance reports for each member: asks made, dollars committed, dollars received, events attended, meetings attended. Members are graded A+ through F. The candidate sees a scoreboard.

6. **AI & Brain Integration** — E20 Intelligence Brain monitors committee health and intervenes: adjusting targets when pace falls behind, recommending new recruits, flagging inactive members, suggesting events, and escalating critical issues to the candidate.

## Office Tiers

| Tier | Offices | Committee Size |
|------|---------|---------------|
| Federal | US Senate, US House | 25-75 |
| Statewide | Governor, Council of State | 15-40 |
| State Legislature | NC Senate, NC House | 8-20 |
| County | Commissioner, Sheriff, DA, Clerk | 5-12 |
| Municipal (Large) | Mayor, City Council (Charlotte, Raleigh) | 5-15 |
| Municipal (Small) | Mayor, Town Council, Village Board | 3-10 |
| Judicial | Supreme Court, Court of Appeals, Superior, District | 5-15 |
| Special District | School Board, Soil & Water, Hospital Board | 2-5 |

## Files

```
e58_finance_committee/
├── sql/
│   └── 001_e58_finance_committee_schema.sql    # 13 tables, 40+ indexes, triggers, functions
├── agents/
│   └── ecosystem_58_finance_committee_complete.py  # 10 classes, 26+ API endpoints
├── panel/
│   └── e58_control_panel.html                  # Single-file SPA, 6 tabs, dark theme
├── INTEGRATION_PLAN.md                         # Architecture, algorithms, deployment
├── requirements.txt                            # Python dependencies
└── README.md                                   # This file
```

## Quick Start

```bash
# 1. Apply schema
psql $DATABASE_URL < sql/001_e58_finance_committee_schema.sql

# 2. Install dependencies
pip install -r requirements.txt

# 3. Set environment
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_KEY=your-service-role-key

# 4. Start API
uvicorn agents.ecosystem_58_finance_committee_complete:app --host 0.0.0.0 --port 8058

# 5. Open control panel
open panel/e58_control_panel.html
```

## Database Tables

| Table | Purpose |
|-------|---------|
| fc_office_tiers | 8 office level configurations with bundler tier definitions |
| fc_district_audit | Pre-computed district analysis (D1-D10, R1-R10, budget estimates) |
| fc_budget_plan | Daily/weekly fundraising targets per candidate |
| fc_committees | One Finance Committee per candidate per cycle |
| fc_roles | 5 role definitions with task checklists |
| fc_members | Every person assigned with targets and performance tracking |
| fc_ai_recommendations | AI-suggested committee recruits from donor data |
| fc_weekly_reports | Auto-generated weekly performance per member |
| fc_events | Fundraising events with revenue tracking |
| fc_prospect_pipeline | Every prospect being worked by committee members |
| fc_candidate_questionnaire | Candidate onboarding answers |
| fc_performance_snapshots | Daily committee-level pace snapshots |
| fc_brain_directives | E20 Intelligence Brain actions |
