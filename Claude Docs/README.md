# Claude Docs — BroyhillGOP

This folder mirrors `Perplexity Docs/` for Claude (Anthropic) work on BroyhillGOP.

Both folders live in the same repo (`broyhill/BroyhillGOP`). There is no separate Claude repo —
the search engine, the central folder pointer, and the session-transcript convention are shared.

---

## What goes in here

- **Long-form Claude-authored architecture docs** (mirrors Perplexity's `perplexity-database-finalized-platform-architecture.docx`)
- **Claude-specific runbooks** that don't belong in `docs/runbooks/`
- **Cross-session knowledge files** Claude has produced (research summaries, audit reports, multi-step design docs)
- **Anything Claude generates that's reference material rather than ephemeral session output**

## What does NOT go in here

- Session transcripts → `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/SESSION_TRANSCRIPT_*.md` (central folder), with a copy in `sessions/` if it's database/schema work
- Generated SQL / Python / shell code → `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/scripts/` and `database/migrations/`
- Plans / specs / QA / dryrun outputs → `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/runbooks/`
- The NEXUS protocol files → repo root (parallel to Perplexity's onboarding/briefing files)

---

## Companion files at the repo root

| File | Mirror of (Perplexity side) | Purpose |
|---|---|---|
| `CLAUDE.md` | `(no Perplexity mirror — Claude-only boot file)` | Claude session boot context |
| `NEXUS.md` | `PERPLEXITY_ONBOARDING.md` | Wake/sleep protocol — Ed types `NEXUS` to start, `NEXUS sleep` to end |
| `NEXUS_SLEEP_TEMPLATE.md` | `PERPLEXITY_HANDOFF_*.md` (a worked example) | Format for session transcripts |
| `NEXUS_TODO.md` | `(rolling open-items, refreshed each `NEXUS sleep`)` | Single source of truth for Claude's open work |
| `ai_search.py` | (shared) | Search CLI — both agents use it |
| `ai_search_index.json` | (shared) | Search index — both agents use it |
| `AI_SEARCH_GATEWAY.md` | (shared) | Search usage doc |
| `CENTRAL_FOLDER.md` | (shared) | Where any agent saves outputs |

---

## Side-by-side: how the two agents are organized in this repo

```
broyhill/BroyhillGOP/
├── PERPLEXITY_ONBOARDING.md          ← Perplexity boot (April 2026)
├── PERPLEXITY_BRIEFING.md            ← Perplexity short brief
├── PERPLEXITY_HANDOFF_*.md           ← Perplexity session handoffs
├── PERPLEXITY_SESSION_ALL_CODE_BLOCKS.py
├── Perplexity Docs/                  ← Perplexity long-form docs
│   ├── main_perplexity-Session-GOD.txt
│   └── perplexity-database-finalized-platform-architecture.docx
│
├── CLAUDE.md                         ← Claude boot
├── NEXUS.md                          ← Claude wake/sleep protocol (mirrors PERPLEXITY_ONBOARDING)
├── NEXUS_SLEEP_TEMPLATE.md           ← Claude transcript format
├── NEXUS_TODO.md                     ← Claude open items
├── Claude Docs/                      ← Claude long-form docs (THIS FOLDER)
│   └── README.md
│
└── sessions/                         ← BOTH agents' session transcripts go here
    ├── 2026-03-23_FULL-DATABASE-AUDIT.md             (Perplexity)
    ├── 2026-04-26_PERPLEXITY_*.md                    (Perplexity)
    └── 2026-04-27_CLAUDE_*.md                        (Claude)
```

---

## Search engine — shared across both agents

Both Claude and Perplexity use the same search gateway. There is no separate Claude index.

```bash
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "<query>"
```

The index covers everything in the universe (Desktop, Downloads, Documents, NCBOE-FEC folder)
and is refreshed every morning at 7 AM by `morning_scrape.sh`. Either agent can search the other's
output, which is the point — they should see each other's work.

---

_Last updated: 2026-04-27 — Maintained alongside `NEXUS.md`, `CLAUDE.md`, `CENTRAL_FOLDER.md`_
