# E55 Autonomous Intelligence Agent — Jeeva Clone for Political Campaigns

## What This Is

E55 is a political campaign intelligence agent modeled after [Jeeva.ai](https://jeeva.ai), the AI sales automation platform that scaled from $0 to $5M ARR in 9 months with 11 people.

Where Jeeva automates B2B sales (prospecting, outreach, follow-up, scheduling), E55 automates **campaign field operations** — prospect discovery, waterfall enrichment, community group monitoring, news cycle reaction, pre-call briefings, and multi-channel outreach sequences.

## Architecture

```
┌─────────────────────────────────────────────────┐
│               Supabase (PostgreSQL)              │
│  15 tables · 9 functions · 5 views · 4 triggers │
│  80 enrichment sources · RLS policies            │
├─────────────────────────────────────────────────┤
│            E55 Python Agent (Hetzner)            │
│  ICP Engine · Waterfall Enrichment · Social      │
│  Monitor · News Reactor · Briefing Generator     │
│  Outreach Engine · Inbox Classifier              │
├─────────────────────────────────────────────────┤
│          Edge Functions (Supabase)                │
│  17 REST API endpoints                           │
├─────────────────────────────────────────────────┤
│              Web Interfaces                       │
│  Command Center · AI Advisor Funnel Builder       │
│  Solutions Briefing Templates                     │
└─────────────────────────────────────────────────┘
```

## Files

| File | Size | Description |
|------|------|-------------|
| `sql/e55_deploy.py` | 66KB | Full schema deployment (tables, indexes, RLS, functions, views, triggers, seed data) |
| `agent/e55_enrichment_agent.py` | 50KB | Python enrichment engine with 9 agent classes |
| `agent/e55_agent.service` | 0.5KB | systemd service file for Hetzner |
| `edge_functions/e55_edge_functions.js` | 19KB | 17 Supabase Edge Function endpoints |
| `webhooks/e55_n8n_webhooks.json` | 8KB | 8 webhook configs + 3 n8n workflow templates |
| `web/E55_Command_Center.html` | 43KB | Interactive dashboard (12 pages) |
| `web/NEXUS_AI_Advisor_Funnel_Builder.html` | 31KB | Campaign funnel builder with issue clusters |
| `deploy_e55.sh` | 2KB | One-click deployment script |

## Deployment

```bash
cd e55_jeeva_clone
chmod +x deploy_e55.sh
./deploy_e55.sh
```

## Supabase Tables (15)

- `e55_agent_profiles` — One agent per candidate
- `e55_social_group_directory` — Monitored community groups
- `e55_group_memberships` — Group-to-golden-record links
- `e55_enrichment_queue` — Waterfall enrichment pipeline
- `e55_prospect_origins` — Full origin attribution (CORE)
- `e55_capacity_signals` — Wealth/giving capacity indicators
- `e55_outreach_sequences` — Multi-step outreach campaigns
- `e55_connector_scores` — Community super-connector rankings
- `e55_unified_inbox` — Centralized message inbox
- `e55_newsletter_tracking` — Subscriber engagement tracking
- `e55_precall_briefings` — Auto-generated pre-call briefs
- `e55_news_cycle_events` — Breaking news event registry
- `e55_agent_activity_log` — Full agent action audit trail
- `e55_icp_profiles` — Natural language ICP search
- `e55_enrichment_sources` — 80 sources across 7 tiers
