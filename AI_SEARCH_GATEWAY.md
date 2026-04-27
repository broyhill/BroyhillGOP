# AI SEARCH GATEWAY — BroyhillGOP

**For: every AI agent (Claude, Cursor, Perplexity, future sessions) working on BroyhillGOP.**

This is the single entry point for searching across the entire BroyhillGOP universe of files — sessions, code, runbooks, documents, ecosystem reports, donor data — all of it.

---

## Quick start (one line)

```bash
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "ecosystem 32"
```

That returns every file matching "ecosystem 32" sorted newest-first, with topics, paths, ecosystems, and badges (★ CENTRAL, ⊕ deep-indexed, § session transcript).

---

## What it covers

The gateway searches the canonical index built each morning by `morning_scrape.sh`:

- **All four scan dirs**: `Desktop/BroyhillGOP-CURSOR/`, `Downloads/`, `Documents/`, `Desktop/NCBOE-FEC- DONORS 2015-2026/`
- **Every file type**: `.md`, `.sql`, `.py`, `.docx`, `.xlsx`, `.csv`, `.txt`, `.sh`, `.json`, `.html`, `.ts`, `.jsx`
- **Every indexed field**: filename, path, topic tags, ecosystem refs (E00–E58), category, deep-content extractions (HEADINGS, TABLES, NAMES, AMOUNTS, TECH terms)
- **Date range**: full project history; sort defaults to newest first

Total searchable: ~7,100 files (as of 2026-04-27), refreshed daily.

---

## How the freshness chain works

1. `morning_scrape.sh` runs each morning at 7:00 AM (via launchd)
2. It rebuilds `GOD_FILE_INDEX_V8.html` (the human UI) **and** writes `ai_search_index.json` (the AI snapshot)
3. `ai_search.py` reads `ai_search_index.json` first (fast), with `GOD_FILE_INDEX_V8.html` as fallback
4. Result: when an AI session searches in the morning, it gets results that include yesterday's work

To force-refresh manually before the next morning run:

```bash
bash /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.sh
```

---

## Usage

### Basic queries

```bash
python3 ai_search.py "donor cluster"          # any file mentioning both terms
python3 ai_search.py "rollup phase b"         # all three terms required
python3 ai_search.py ""                       # everything (filter with flags)
```

### Filter by ecosystem

```bash
python3 ai_search.py --ecosystem E32                  # all E32 files
python3 ai_search.py "intelligence" --ecosystem E20   # E20 + term match
```

Ecosystems are E00..E58. Names are in `build_god_file_v7.py` under `ECOSYSTEM_NAMES`.

### Filter by file type

```bash
python3 ai_search.py "session" --type md
python3 ai_search.py "" --type sql --since 7
python3 ai_search.py "" --type py --central
```

### Filter by date

```bash
python3 ai_search.py "" --since 1            # last 24 hours
python3 ai_search.py "" --since 7            # last week
python3 ai_search.py "" --since 30           # last month
python3 ai_search.py "" --from 2026-04-01    # since Apr 1
python3 ai_search.py "" --from 2026-03-01 --to 2026-03-31
```

### Filter by category / scope

```bash
python3 ai_search.py "" --central                       # ★ central folder only
python3 ai_search.py "" --session                       # transcripts/handoffs/briefings
python3 ai_search.py "" --deep                          # only files with HEADINGS extracted
python3 ai_search.py "donor" --category BroyhillGOP     # repo files only
```

### Output formats

```bash
python3 ai_search.py "phase b" --json              # full JSON records
python3 ai_search.py "phase b" --count             # just the number of matches
python3 ai_search.py "phase b" --topics            # text + topic chips per result
python3 ai_search.py "phase b" --limit 100         # raise default 30-result cap
```

### Combine flags freely

```bash
python3 ai_search.py "rollup" --central --type sql --since 14 --limit 20 --json
```

---

## Output legend

Text mode shows one row per file:

```
2026-04-27 [★⊕§] .md     8KB  committee_donor_cluster_rollup_match_apply_dryrun_20260426.md  E:E02,E07
              /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/runbooks/committee_donor_cluster_rollup_match_apply_dryrun_20260426.md
```

| Symbol | Meaning |
|---|---|
| `★` | CENTRAL — lives in the central work folder |
| `⊕` | Deep-indexed — has HEADINGS / TABLES / TECH / NAMES / AMOUNTS extracted |
| `§` | Session transcript / handoff / briefing |
| `E:E02,E07` | Ecosystems referenced in this file |

JSON mode returns the raw records with these fields:

```
n        file name
p        full path on disk
t        type (extension without dot)
c        category (BroyhillGOP, Downloads, Documents, Donors/FEC, Other)
s        size in bytes
q        topics, then " || " then deep-content extraction
d        date (YYYY-MM-DD, last modified)
e        ecosystem CSV (e.g. "E20,E32")
x        1 if session/transcript
dc       1 if deep-indexed
central  1 if in central folder
```

---

## Real-world examples

**Front-end work — what we have on Ecosystem 32 (Phone Banking)**

```bash
python3 ai_search.py --ecosystem E32 --topics --limit 20
```

**Yesterday's session pickup — what was generated?**

```bash
python3 ai_search.py "" --central --since 1 --topics
```

**All committee donor rollup work, newest first**

```bash
python3 ai_search.py "committee donor rollup"
```

**Find the latest schema spec that touches person_spine**

```bash
python3 ai_search.py "person_spine" --type md --limit 5
```

**Programmatic — load matching records into a session**

```bash
python3 ai_search.py "compliance" --json --limit 10 > /tmp/results.json
```

---

## When to use this gateway

- **At session start**, to load context without scanning the filesystem yourself
- **Mid-task**, to confirm whether existing work covers a topic (avoid re-creating)
- **Before generating code**, to find prior implementations to extend
- **Cross-references**, to find every doc referencing a specific table or ecosystem
- **Date-bounded recall**, to see only what's changed in the last N days

---

## When NOT to use it

- Reading a specific known file → just `cat` or `Read` it
- Looking for content inside a file you already know about → `grep` directly
- Live database queries → use Hetzner Postgres tools, not this index
- Searching freshly-created files (within seconds) → wait for next morning rebuild, or run `morning_scrape.sh` manually

---

## Files involved

| File | Purpose |
|---|---|
| `/Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py` | The CLI |
| `/Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search_index.json` | Daily snapshot the CLI reads (refreshed by morning_scrape.sh) |
| `/Users/Broyhill/Documents/GitHub/BroyhillGOP/GOD_FILE_INDEX_V8.html` | Human-facing search UI (same data) |
| `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/morning_scrape.sh` | Daily rebuild orchestrator |
| `/Users/Broyhill/Documents/GitHub/BroyhillGOP/CENTRAL_FOLDER.md` | Companion: where to save outputs |

---

_Last updated: 2026-04-27_
