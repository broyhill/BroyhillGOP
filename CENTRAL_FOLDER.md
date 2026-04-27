# CENTRAL FOLDER — BroyhillGOP

**Status:** AUTHORITATIVE • Set 2026-04-27
**Path:** `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/`

---

## What this is

This file pins the location of the **central work folder** for the BroyhillGOP project.

All AI agents (Claude, Cursor, Perplexity, future sessions) **MUST** save the following artifacts in the central folder, not elsewhere:

- Session plans (`SESSION_*.md`, `*_HANDOFF_*.md`, `*_BRIEFING.md`)
- Generated code (`.py`, `.sql`, `.sh`, `.ts`, `.tsx`, `.jsx`)
- Runbooks and specs (`docs/runbooks/*.md`)
- QA reports and dryrun outputs (`*_qa_*.md`, `*_dryrun_*.md`)
- Phase / stage proposals and CSVs (`*_phase_*`, `*_stage*_*`, `*_propagation_*`)
- Architecture docs and plans (`PLAN_*.md`, `*_PLAN_*.md`, `*_SPEC.md`)
- Cluster / rollup work (`*_cluster_rollup_*`, `*_rollup_v*`)

## Search and discovery

The central folder is indexed by **`GOD_FILE_INDEX_V8.html`** (the canonical search engine for the project, in this repo's root). Files saved here automatically:

- Get the **★ CENTRAL** badge in V8
- Float to the top of search results within their date
- Are deep-indexed (HEADINGS, TECH refs, table names, dollar amounts, names) on next index rebuild
- Are tagged with topic keywords for subject-search

To filter to only central files in V8: click **★ CENTRAL Only** in the QUICK FILTERS sidebar.

## Where things go inside the central folder

```
/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/
├── docs/runbooks/         ← runbooks, plans, specs, QA reports
├── scripts/               ← generated SQL, Python, shell, TS code
├── database/migrations/   ← schema migrations (numbered)
├── MD FILES/              ← long-form session transcripts and architecture docs
├── AAA DONOR CONTACT INFO/← donor data files
├── AAA Datatrust/         ← DataTrust integration files
└── (root)                 ← cross-cutting handoffs, briefings, top-level plans
```

## File naming conventions

- Session transcripts: `SESSION_TRANSCRIPT_YYYY-MM-DD_<AGENT>.md`
- Handoff files: `<AGENT>_HANDOFF_YYYY-MM-DD_<TOPIC>.md` (e.g., `PERPLEXITY_HANDOFF_2026-04-26_PHASE_BCD.md`)
- Briefings: `<AGENT>_BRIEFING.md` or `<AGENT>_BRIEFING_<TOPIC>.md`
- Plans: `<TOPIC>_PLAN.md` or `<TOPIC>_PLAN_V<n>.md`
- Specs: `<TOPIC>_SPEC.md` or `<TOPIC>_V<n>_SPEC.md`
- QA: `<topic>_qa_YYYYMMDD.md`
- Dryruns: `<topic>_dryrun_YYYYMMDD.md`
- Code: `<topic>_<verb>.py|.sql|.sh` (e.g., `committee_donor_rollup_v1_build.sql`)

Use `YYYYMMDD` (no dashes) inside file names for sortable date stamps; use `YYYY-MM-DD` (with dashes) only at the start of the filename if needed.

## Cross-environment notes

- **Cursor's working repo** = the central folder above (`/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/`)
- **GitHub repo** = `/Users/Broyhill/Documents/GitHub/BroyhillGOP/` (this file lives here for discoverability; production indexes also live here)
- **Hetzner Postgres** is the database; canonical state checkpoint = `public.session_state.id = 25`, expected `updated_by = 'Nexus-2026-04-26-sleep-checkpoint'` (or the latest equivalent)
- **Perplexity Computer sandbox** has its own ephemeral workspace — files there are NOT central; copy anything important into the path above

## For Claude / agents reading this

When the user asks you to "save this", "write this plan", "generate this code", or "create a session transcript":

1. Default save location is `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/`
2. Use the appropriate subdirectory above
3. Use the naming convention above
4. After saving, mention the path so the user can confirm

If the central folder path ever changes, update this file and the path above stays the source of truth.

---

## Morning scrape

The search engine is refreshed daily by `morning_scrape.sh` at the central folder root:

```
/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.sh
```

It runs the full 4-step chain:

1. `ecosystem_search_engine.py` — scans `Desktop/BroyhillGOP-CURSOR`, **`Downloads`**, `Documents`, and `Desktop/NCBOE-FEC- DONORS 2015-2026`
2. `enrich_json_v7.py` — adds mtime / ctime / ecosystem references
3. `build_god_file_v7.py` — writes the intermediate V7 dataset
4. `build_v8.py` — deep-indexes (HEADINGS, TABLES, NAMES, AMOUNTS, TECH, COUNTS, ECOSYSTEMS) and writes the canonical `GOD_FILE_INDEX_V8.html`

### Schedule via launchd (recommended on macOS)

Save to `~/Library/LaunchAgents/com.broyhillgop.morning-scrape.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.broyhillgop.morning-scrape</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>7</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.log</string>
  <key>StandardErrorPath</key><string>/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.log</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
```

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.broyhillgop.morning-scrape.plist
```

### Ad-hoc run

```bash
bash /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.sh
```

### Scope

The scrape covers all four `SEARCH_DIRS` configured in `ecosystem_search_engine.py`:

- `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR` (this central folder)
- `/Users/Broyhill/Desktop/NCBOE-FEC- DONORS 2015-2026`
- **`/Users/Broyhill/Downloads`** (so anything dropped there gets picked up)
- `/Users/Broyhill/Documents`

To add a new scan directory, edit `SEARCH_DIRS` at the top of `ecosystem_search_engine.py`.

---

_Last updated: 2026-04-27_
_Maintained alongside `GOD_FILE_INDEX_V8.html` in this repo_
