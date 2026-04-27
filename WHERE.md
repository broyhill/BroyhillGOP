# WHERE — Pinned paths for BroyhillGOP

> One screen. The most-used paths in the project. Open this file when you need to find something fast.
> Refreshed by hand. Live agents see the same list via `python3 ai_search.py --pinned`.

---

## 🤖 Agent folders (per-AI working space)

| Agent | Long-form docs folder | Boot file | Protocol file | Open TODO |
|---|---|---|---|---|
| **Claude (Anthropic)** | `Claude Docs/` | `CLAUDE.md` | `NEXUS.md` | `NEXUS_TODO.md` |
| **Perplexity (Nexus)** | `Perplexity Docs/` | `PERPLEXITY_ONBOARDING.md` | `PERPLEXITY_SESSION_STARTER.md` (in `sessions/`) | `PERPLEXITY_BRIEFING.md` |
| **Cursor (local Mac)** | (uses central folder) | `CURSOR_WAKE_UP.md` | `CURSOR_BRIEFING.md` | (in handoffs) |

All three agents share: `sessions/`, `ai_search.py`, `ai_search_index.json`, `CENTRAL_FOLDER.md`, `GOD_FILE_INDEX_V8.html`.

---

## 📁 Top-of-mind locations

| Need | Path |
|---|---|
| **Search anything** | `python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "<query>"` |
| **Search engine UI** | `/Users/Broyhill/Documents/GitHub/BroyhillGOP/GOD_FILE_INDEX_V8.html` |
| **Central work folder** (where outputs go) | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/` |
| **GitHub repo root** | `/Users/Broyhill/Documents/GitHub/BroyhillGOP/` |
| **Session transcripts** | `/Users/Broyhill/Documents/GitHub/BroyhillGOP/sessions/` |
| **Runbooks / specs / dryruns** | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/runbooks/` |
| **Generated SQL/Python/shell** | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/scripts/` |
| **Database migrations** | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/database/migrations/` |
| **Long-form architecture (free-form)** | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/MD FILES/` |

---

## 🛠 Operational scripts

| Script | Path | Purpose |
|---|---|---|
| Morning scrape (rebuild index) | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.sh` | Daily 7AM rebuild of V8 + AI snapshot |
| Build V8 (deep-indexed) | `/Users/Broyhill/Documents/GitHub/BroyhillGOP/build_v8.py` | Rebuild from V7 + deep content |
| Build V7 (intermediate) | `/Users/Broyhill/Documents/GitHub/BroyhillGOP/build_god_file_v7.py` | Build V7 from enriched JSON |
| Enrich JSON | `/Users/Broyhill/Documents/GitHub/BroyhillGOP/enrich_json_v7.py` | Add timestamps + ecosystems |
| Scanner | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/ecosystem_search_engine.py` | Walk filesystem, extract topics |
| Bridge server (OPEN/REVEAL/COPY) | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/god_file_server.py` | localhost:8181 |

---

## 🔑 Reference / doctrine files (read before acting)

| File | Path |
|---|---|
| Donor table naming doctrine | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/DONOR_TABLE_NAMING_DOCTRINE.md` |
| Committee ingestion runbook v4 | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/runbooks/COMMITTEE_INGESTION_RUNBOOK_V4.md` |
| Master context | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/MASTER_CONTEXT.md` |
| Latest session state | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/SESSION-STATE.md` |
| Session start read-me | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/sessions/SESSION_START_READ_ME_FIRST.md` |
| Constitution v4.1 | `/Users/Broyhill/Documents/GitHub/BroyhillGOP/docs/BROYHILLGOP_CONSTITUTION_v4.md` |

---

## 🌐 Infrastructure quick-reference

| Resource | Value |
|---|---|
| Hetzner DB (truth source) | `37.27.169.232:5432` |
| Hetzner Server 1 | `5.9.99.109` |
| GitHub repo | `git@github.com:broyhill/BroyhillGOP.git` |
| Relay endpoint | `http://5.9.99.109:8080` |
| Relay API key | `bgop-relay-k9x2mP8vQnJwT4rL` |
| Bridge service (local) | `http://localhost:8181` (OPEN/REVEAL/COPY) |

---

_Last updated: 2026-04-27 — Edit this file by hand whenever a new pinned location is added._
