# NEXUS_TODO — 2026-04-27 18:30

> Single-source open-items list for Claude sessions. Overwritten each `NEXUS sleep`.
> Order matters: AUTHORIZED first, then BLOCKED, then NEW, then RETIRED.
> See `NEXUS.md` for the trigger-word protocol.

---

## ✅ AUTHORIZED (Ed has approved; safe to execute next session)

_None yet — waiting for first NEXUS sleep to populate this list._

---

## ⏸ BLOCKED (waiting on Ed, Perplexity, Cursor, or external)

1. **Bridge service for V8 OPEN buttons** — needs a small Python server at localhost:8181 to handle `open -a <app> <path>`, `open -R <path>`, `pbcopy`. Without it, V8 OPEN/REVEAL buttons fall back to browser default. Blocked by: Ed has not asked for this yet. (Companion: see `god_file_server.py` which is the bridge skeleton.)

2. **launchd plist for morning_scrape.sh** — template is in `CENTRAL_FOLDER.md`. Blocked by: Ed needs to run `launchctl load ~/Library/LaunchAgents/com.broyhillgop.morning-scrape.plist` once on his Mac to activate the 7 AM auto-rebuild.

3. **Git push of new gateway files** — `CLAUDE.md`, `NEXUS.md`, `NEXUS_SLEEP_TEMPLATE.md`, `NEXUS_TODO.md`, `ai_search.py`, `ai_search_index.json`, `AI_SEARCH_GATEWAY.md`, `CENTRAL_FOLDER.md`, modified `GOD_FILE_INDEX_V8.html`, V7 redirect. Blocked by: needs Ed to authorize the commit + push.

---

## 🆕 NEW (raised this session, awaiting Ed's read)

1. **Move 28 loose code files from central-folder ROOT into `scripts/`** — files like `bulletproof_load.py`, `datatrust_enrich.py`, `pipeline_ddl 2.sql`, `PERSON_MASTER_SCHEMA 2.sql` look like they belong in `scripts/`. Some root files (`build_v8.py`, `god_file_server.py`, `rebuild_god_file.sh`) are intentional top-level tooling. Need Ed to confirm which go where.

2. **Deep-index the 34 unreachable files** that were in earlier scans but live outside the four currently-mounted folders. Now that `~/Downloads` is mounted, re-run the deep-index pass to close the remaining ~6% gap on last-2-weeks coverage.

3. **Push `morning_scrape.sh` Step 5** — the AI-snapshot export step was added but the script lives only on Ed's Mac (in the central folder, not the GitHub repo). Decide: should it live in `/Users/Broyhill/Documents/GitHub/BroyhillGOP/scripts/morning_scrape.sh` and be symlinked to the central folder, or stay where it is?

4. **Apply CENTRAL flag refresh nightly** — currently the `central=1` flag is set during the merge run. The morning scrape rebuilds V8 from V7, which doesn't carry the `central` field. Either: (a) build_v8.py needs to re-mark central files based on path prefix, or (b) the AI-snapshot step (Step 5 of morning_scrape.sh) needs to re-apply the flag.

---

## 🚫 RETIRED THIS SESSION

1. **V7 as canonical search engine** — retired and replaced with redirect page; original archived at `GOD_FILE_INDEX_V7.html.archived_20260427`. V8 is now canonical.
2. **Manual-only morning scrape** — script `morning_scrape.sh` now exists; just needs scheduling.
3. **AI-search non-existence** — `ai_search.py` + `ai_search_index.json` + `AI_SEARCH_GATEWAY.md` now in place.
4. **No NEXUS protocol for Claude** — `NEXUS.md` + `NEXUS_SLEEP_TEMPLATE.md` now in place.

---

_Last updated by Claude (Cowork session) — 2026-04-27 18:30_
_Next update: at next `NEXUS sleep`._
