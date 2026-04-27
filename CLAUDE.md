# Claude (Anthropic) — BroyhillGOP boot

## 📍 Pinned paths — open `WHERE.md` first

```
/Users/Broyhill/Documents/GitHub/BroyhillGOP/WHERE.md
```

One screen with every agent folder, work folder, and key path. Or fast lookup:

```bash
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py --pinned
```

**Per-agent folders:** `Claude Docs/` (Claude long-form), `Perplexity Docs/` (Perplexity long-form), `sessions/` (shared transcripts).

**Per-agent boot files at repo root:** `CLAUDE.md` (this file) + `NEXUS.md` for Claude; `PERPLEXITY_ONBOARDING.md` + `PERPLEXITY_BRIEFING.md` for Perplexity; `CURSOR_WAKE_UP.md` for Cursor.

---

## AI search engine — START HERE for ANY query about existing files

Before searching the filesystem yourself, use the AI search gateway:

```bash
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "<query>"
```

It searches **everything** in the indexed universe (~7,100 files): all of `Desktop/BroyhillGOP-CURSOR/`, `Downloads/`, `Documents/`, `Desktop/NCBOE-FEC- DONORS 2015-2026/`. Results are sorted newest-first with topic tags, ecosystem refs, and deep-content extractions (HEADINGS, TABLES, NAMES, AMOUNTS, TECH terms).

Common patterns:

```bash
python3 …/ai_search.py "rollup phase b"               # term match
python3 …/ai_search.py --ecosystem E32 --topics       # E00..E58 filter
python3 …/ai_search.py "" --central --since 1         # central files modified today
python3 …/ai_search.py "session" --type md --since 7  # last week's transcripts
python3 …/ai_search.py "donor cluster" --json         # JSON for downstream parsing
```

Full usage doc: `AI_SEARCH_GATEWAY.md` (this directory)

The search index `ai_search_index.json` is refreshed every morning at 7 AM by `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.sh`. To force-refresh ad-hoc, run that script. Human UI: open `GOD_FILE_INDEX_V8.html` (this directory).

## Where to save outputs

Default save location for session plans, generated code, runbooks, QA reports, dryruns, specs:

```
/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/
```

Subdirectory conventions and naming rules: see `CENTRAL_FOLDER.md` (this directory).

Files saved under that path get the **★ CENTRAL** flag in search results.

---

## Committee / party-committee donor work on Hetzner

Before any such work:

1. `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/DONOR_TABLE_NAMING_DOCTRINE.md` — candidate spine vs committee prep vs core.
2. `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/runbooks/COMMITTEE_INGESTION_RUNBOOK_V4.md` — V4 cascade, status, canaries (**candidate canary uses `SUM(norm_amount)`**).
3. Read-only: latest `public.session_state` on Hetzner (`state_md`).

**Hard stops (unless Ed authorizes explicitly):** no swaps; no `ALTER` renames to promote committee data; no writes to `core.di_donor_attribution`; **`raw.ncboe_donations`** = read-only canary only (candidate spine, not the committee file).

Platform-wide context: `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/MASTER_CONTEXT.md`, `SESSION-STATE.md`, `sessions/SESSION_START_READ_ME_FIRST.md`.
