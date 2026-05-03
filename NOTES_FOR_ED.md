# V8 Search Engine — Bug Fixes 2026-05-03

## What was authorized → what I changed

| # | Bug | Status | Marker |
|---|---|---|---|
| 1 | E59/60/61 missing from classifier | Fixed | `# === BUG FIX (2026-05-03): add E59/E60/E61 to classifier ===` |
| 2 | .docx files topic-indexed only by filename | Fixed | `# === BUG FIX (2026-05-03): .docx topic-extraction (parallel to existing) ===` + helper block |
| 3 | REVEAL → folder of thousands | Fixed | `// === BUG FIX (2026-05-03): REVEAL no longer dumps into folder of thousands ===` |
| 4 | COPY broken on file:// pages | Fixed | `// === BUG FIX (2026-05-03): COPY now actually works on file:// URLs ===` |
| 5 | Confusing titles | Fixed | `// === BUG FIX (2026-05-03): show extracted title in filename slot when available ===` + helper + loop |
| Enh | Rollup counts on filter pills + eco chips | Added | `// === ADDITION (2026-05-03): rollup counts ===` (×2) |

All 11 marker blocks (open/close pairs) verified balanced.

## E59/E60/E61 keyword arrays (the ones you approved)

```python
"E59": ["nervous net","cost ledger","ifttt","iftt","rule fire","cost event",
        "ml optimizer","bandit","brain orchestrator"],
"E60": ["poll","survey","county intensity","catawba","meredith","high point university",
        "cygnal","civitas","yougov","voter archetype","onsp","issue intensity",
        "poll source","nc county","calibration"],
"E61": ["source ingestion","identity resolution","master data","mdm",
        "source registry","entity resolution","raw_sources"],
```

## Things I noticed but did NOT touch (per do-not-touch rules)

- **Existing E00–E58 keyword lists.** Some have weak recall (e.g. E07 "issue tracking" is
  generic enough to match unrelated docs). Did not modify per rule.
- **File-type inclusion list.** .txt, .csv, .json, .html files still get filename-only
  indexing. The amendment only authorized adding .docx topic extraction. Flagging in case
  you want a future amendment for these.
- **The V7 → V8 inheritance pattern.** build_v8.py reads V7's HTML data line and re-uses
  it; it does not re-walk the filesystem. This means files you've created since V7 was
  generated won't appear until V7 is also regenerated. Not in scope today.
- **god_file_search_index.json** at repo root — newer manifest format (7,046 records, ISO
  dates, richer schema). build_v8.py doesn't use it; V7 HTML is the source of truth.
  Worth a future ticket to swap V7 inheritance for direct manifest read.
- **The bridge endpoint** (`http://localhost:8181`) — script assumes this is running on
  your Mac. If it's not, REVEAL/COPY/OPEN all degrade to the modal fallback (which now
  works correctly thanks to fix #3 and #4). If you want me to investigate why the bridge
  has been flaky, that's a separate ticket.

## How to regenerate the HTML

On your Mac (where the V7 file actually exists):

```
cd /Users/Broyhill/Documents/GitHub/BroyhillGOP
git fetch origin
git checkout claude/v8-bug-fixes-2026-05-03
python3 build_v8.py
open GOD_FILE_INDEX_V8.html
```

Test plan once it's open:
1. Click E59, E60, E61 — should all return results (were empty before)
2. Click any .docx blueprint card → REVEAL should open Finder modal with copy-able path
3. Click COPY on any card → should copy without surfacing "prompt:" dialog
4. Open a session-transcript card → title should show H1, not the long filename
5. Filter pills should show live counts: "Python (1,516)" "SESSION (147)" etc.

## Smoke test results (sandbox-side)

- Python ast.parse: ✅ clean
- 7,046-file synthetic index processes end-to-end without error
- HTML output: 2.1MB, 11 marker blocks confirmed in source + 5 in rendered HTML
- Did NOT run on real Mac filesystem — Mac paths not accessible from sandbox
