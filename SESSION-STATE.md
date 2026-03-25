# BroyhillGOP SESSION STATE
## Updated: 2026-03-24 22:35 EDT by Claude

---

## INFRASTRUCTURE STATUS
- Relay: v1.5.0 running on :8080 (healthy ✓, Redis OK, Docker healthcheck fixed)
- Containers: bgop_relay (healthy), bgop_brain (up), bgop_redis (up)
- Database: Supabase PostgreSQL (58GB, 1187 tables, 18 schemas)
- Terminal: ttyd on :7681 with startup briefing hook
- Agent messaging: agent_messages table + Redis pub/sub live
- **Hetzner UPGRADED: 20 cores / Intel i5-13500 / 62GB RAM (128GB add-on ordered) / 1.7TB disk**

## GOD FILE V7 — AI SEARCH ENGINE (NEW THIS SESSION)
**Eddie's master file index. Every AI reads manifest at session start.**

### Endpoints (no auth required):
- `GET http://5.9.99.109:8080/docs/v7`          → HTML browser (open in Safari/ttyd)
- `GET http://5.9.99.109:8080/docs/manifest`     → AI startup briefing (read every session)
- `GET http://5.9.99.109:8080/docs/search?q=X`   → keyword search (name+topics+ecosystems)
- `GET http://5.9.99.109:8080/docs/search?type=sql`  → by file type
- `GET http://5.9.99.109:8080/docs/search?eco=E01`   → by ecosystem ID
- `GET http://5.9.99.109:8080/docs/search?session=1` → 171 session transcripts
- `GET http://5.9.99.109:8080/docs/search?category=BroyhillGOP` → by folder
- Combine: `?q=donor&type=sql&eco=E01&date_from=2026-01-01`

### Stats:
- 6,388 files indexed (filtered from 32,632 raw)
- 171 session transcripts (full work history)
- 670 SQL files | 1,457 Python files | 1,358 markdown | 756 Word docs
- Every file: date modified, topic tags, ecosystem refs (E01-E58)
- Action buttons: OPEN in app | REVEAL in Finder | COPY path | DRIVE link

### Nightly rebuild: Auto at midnight via Cowork scheduled task.
### Mac rebuild script: /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/rebuild_god_file.sh

## SESSION START PROTOCOL (BOTH AGENTS)
```
curl http://5.9.99.109:8080/docs/manifest       # full project orient
curl http://5.9.99.109:8080/briefing             # SESSION-STATE.md
curl 'http://5.9.99.109:8080/docs/search?session=1&limit=5'  # recent sessions
curl http://5.9.99.109:8080/inbox               # unread messages
```

## LIVE NUMBERS (as of 2026-03-24)
### rncid_resolution_queue
- resolved: 79,702
- review: 42,529
- unresolved: 28,524
- TOTAL: 150,755

### donor_voter_links (pre-existing dataset)
- total matches: 309,112
- unique donors: 291,452
- unique NCIDs: 205,747
- unique RNCIDs: 209,871
- avg confidence: 0.894
- high confidence (>=0.9): 185,068 (59.8%)

## PRIORITY TIERS

### TIER 1 - BLOCKED (needs Eddie approval)
- [ ] BLOCK G WRITE-BACK: stamp resolved RNCIDs back to nc_boe_donations_raw
- [ ] Restore 132,623 missing rows in nc_boe_donations_raw from archive backup

### TIER 2 - READY TO EXECUTE (no blockers)
- [ ] Review queue decision: 42,529 rows in review — auto-promote >=0.90? Or spot-check?
- [ ] Evaluate donor_voter_links overlap: 309K pre-existing matches — skip re-resolving?
- [ ] Fix person_spine mislink: person_id 235240 → correct Robert B. Jordan IV NCID
- [ ] Fix briefing queue count: shows 1000 due to RPC row limit — use COUNT(*)

### TIER 3 - MAINTENANCE
- [ ] Resume rnc_voter_core load: currently at 14.4%
- [ ] Fix 5 broken pg_cron jobs: identify and either repair or drop
- [ ] Rebuild person_spine: current links have errors (Jordan father/son confusion)

### TIER 4 - FUTURE
- [ ] Golden record rebuild: Ed Broyhill 7+ records, Art Pope 0
- [ ] E20 outbound queue consumer: brain.py pushes to bgop:outbound but nothing consumes

## KEY MAC FILES (Claude's tools)
- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/ecosystem_search_engine.py` — file indexer (updated: now captures mtime, ecosystems, category, is_session)
- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/enrich_json_v7.py` — enriches JSON with dates+eco refs (NEW)
- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/build_god_file_v7.py` — builds V7 HTML (NEW)
- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/write_god_file_manifest.py` — builds AI manifest (NEW)
- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/rebuild_god_file.sh` — full nightly rebuild (UPDATED for V7)
- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/ecosystem_search_results_v7.json` — enriched index (9MB)
- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/god_file_search_index.json` — slim search index for relay
- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/GOD_FILE_MANIFEST.json` — AI startup manifest

## DISCOVERY ASSETS (from prior sessions)
- donor_voter_links: 309K pre-matched donor-to-voter records at 0.894 avg confidence
- Employer matching strategy: 3 digits address + first 3 letters last name + first 3 employer zip
- Government files have NO misspelled names — exact matching valid
- fuzzy_run_v4.py moved 19K rows from unresolved to review (3-pass SQL matching)

## COORDINATION PROTOCOL
- Perplexity: reads manifest + /briefing at every ttyd session start (.bashrc hook)
- Claude: reads manifest + /briefing/announce at every session start (CLAUDE_RULES)
- Both agents update this file at session end
- Inter-agent messages via POST /message, GET /inbox on relay :8080
- Relay API key: bgop-relay-k9x2mP8vQnJwT4rL

## AGENT ROLES
- Perplexity: browser automation, Supabase SQL, data exploration, audit queries, web research
- Claude: server-side scripts, Python pipelines, file operations, Docker management, fuzzy matching
- Eddie: approval authority for write-backs, deletes, and schema changes

## THIS SESSION — WHAT CLAUDE DID (2026-03-24)
1. Built GOD FILE V7 with dates, topics, ecosystem tags, advanced filters, action buttons
2. Created AI search API (/docs/search) — JSON endpoint, no auth, combinable params
3. Created AI manifest (/docs/manifest) — startup briefing for every agent session
4. Updated ecosystem_search_engine.py to capture mtime, ecosystems, category, is_session natively
5. Deployed V7 HTML + search index + manifest to Hetzner
6. Fixed Docker healthcheck (curl → python3), relay now shows (healthy)
7. Scheduled nightly rebuild at midnight via Cowork
8. Briefed Perplexity on all new endpoints (agent_messages id 19)
9. Noted Hetzner upgrade: 20 cores, 62GB RAM, 128GB add-on ordered
