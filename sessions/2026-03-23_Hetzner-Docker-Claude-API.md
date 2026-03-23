# Session: Hetzner Docker + Claude API + E20 Brain Setup
**Date:** March 23, 2026  
**Status:** ✅ COMPLETE

---

## What Was Accomplished

### 1. Hetzner Server Recovery
- Changed root password via `passwd` using SSH key auth: `ssh -i ~/.ssh/id_ed25519_hetzner root@5.9.99.109`
- Server is Ubuntu 22.04 (NOT 24.04 as previously noted)

### 2. Docker Installation
- Docker 29.3.0 installed via `curl -fsSL https://get.docker.com | sh`
- Docker Compose v5.1.1 installed
- Docker daemon enabled and started on boot

### 3. Claude API Verified Live
- Tested Claude API from Hetzner via Docker
- Full stack confirmed: Hetzner → Docker → Python → Anthropic API → Claude
- Model used: `claude-sonnet-4-20250514`
- API key stored in `/opt/broyhillgop/.env`

### 4. E20 Brain Hub Docker Stack Deployed
Files deployed to `/opt/broyhillgop/`:
- `docker-compose.yml` — Brain service + Redis event bus
- `brain.py` — E20 decision engine (144 lines)
- `.env` — credentials (Claude API key, Supabase URL + service key, Redis config)

### Stack Architecture
```
Redis (bgop_redis) ← event bus on port 6379
Brain (bgop_brain) ← Python service, listens on bgop:events + bgop:triggers
Supabase ← remote, logs decisions to brain_decisions table
```

### Brain Service Logic
- Listens for JSON events via Redis pub/sub
- Sends each event to Claude with E20 system prompt
- Claude returns structured JSON decision: action, channel, message, ask_amount, expected_value
- Decisions logged to Supabase `brain_decisions` table
- SEND_MESSAGE decisions pushed to `bgop:outbound` Redis queue

### 5. GitHub + GitHub Pages
- GitHub Pages enabled: `https://broyhill.github.io/BroyhillGOP/`
- Document directory pushed: `https://broyhill.github.io/BroyhillGOP/docs/document-directory.html`
- Session transcripts folder created: `sessions/`

---

## Credentials (Current)
- Supabase DB password: `BroyhillGOP2026` (NO dollar sign)
- Hetzner SSH: `ssh -i ~/.ssh/id_ed25519_hetzner root@5.9.99.109`
- Claude API key: in `/opt/broyhillgop/.env`
- Supabase service key: in `/opt/broyhillgop/.env`

## Next Steps
1. Resume BOE fuzzy match (287K unmatched rows)
2. Populate `brain_decisions` table in Supabase (schema needed)
3. FEC ingestion (fec_schedule_a_raw = 0 rows)
4. nc_voters population (currently 0 — see note below)

## ⚠️ VOTER FILE NOTE
`nc_voters` currently shows 0 rows in the plugin skill file — BUT per the E20 Brain Audit Report (March 2026), `nc_voters` has **9,161,218 rows** already loaded. Perplexity and any new session should NOT re-download or re-ingest the voter file. Verify with `SELECT COUNT(*) FROM nc_voters` before any voter file work.
