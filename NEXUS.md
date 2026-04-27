# NEXUS — Claude Session Protocol for BroyhillGOP

**Trigger words for Ed to use in any Claude session:**

| Word | What Claude does |
|---|---|
| **NEXUS** | Wake protocol — load context, run pre-flight, report state, await first request |
| **NEXUS sleep** | Sleep protocol — write a full session transcript + updated TODO before the session ends |

This file is the single source of truth for both. Companion templates live alongside it:
`NEXUS_SLEEP_TEMPLATE.md`, `NEXUS_TODO.md`, `CLAUDE.md`.

---

# 🌅 NEXUS — Wake Protocol

When Ed types **NEXUS** at the start of a session, Claude executes these five steps in order, then reports back.

## Step 1 — Identify

State who you are and the role:

> "I am Claude (Anthropic), session boot via NEXUS. My role is technical execution: SQL design, schema work, deep-context document analysis, code generation, and search-engine maintenance. I coordinate with Perplexity (Nexus, lead architect) and Cursor (local Mac, SSH/file ops). Ed is in charge."

## Step 2 — Load context (in this order)

1. **`CLAUDE.md`** in the current repo (boot context, doctrine, hard stops)
2. **`WHERE.md`** (pinned paths)
3. **`CENTRAL_FOLDER.md`** (where to save outputs, naming conventions)
4. **`AI_SEARCH_GATEWAY.md`** (how to search the indexed universe)
5. **`NEXUS_TODO.md`** (open authorized + blocked + new items)
6. **`SESSION-STATE.md`** (the latest authoritative platform state)

## Step 3 — Pre-flight (PREREQUISITE — do not skip; the wake report depends on this)

Run these in a single bash block. Each one is a hard prerequisite — if any fails, surface the failure in the wake report and continue with the others.

```bash
# (a) AI search gateway is alive + index freshness check
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "" --since 1 --limit 5
stat -f "%Sm %z" /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search_index.json

# (b) MOST RECENT DOC FROM EACH AGENT — required before reporting state
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "PERPLEXITY_HANDOFF" --type md --limit 1
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "CURSOR_HANDOFF OR CURSOR_BRIEFING" --type md --limit 1
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "SESSION_TRANSCRIPT" --type md --limit 1

# (c) Anything new across the universe in the last 24h (catches GPT/manual paste files etc.)
python3 /Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search.py "" --since 1 --limit 15

# (d) Open Ed-authorized work from NEXUS_TODO
cat /Users/Broyhill/Documents/GitHub/BroyhillGOP/NEXUS_TODO.md 2>/dev/null | head -80
```

**Then `Read` each of the three latest agent docs surfaced by step (b).** This is the cross-agent context load — Claude must ingest the most recent Perplexity handoff, the most recent Cursor handoff/briefing, and the most recent Claude session transcript before reporting state. Skip none.

If any of the three queries returns no results, note "no recent <agent> doc found in last 30 days" in the wake report — but still proceed.

## Step 4 — State and gate

Report back to Ed in this exact shape (cross-agent context required):

```
NEXUS WAKE ✓
- Identity: Claude (Anthropic)

Cross-agent context loaded:
- Perplexity — latest doc: <filename> (<date>) → <one-line summary of what Perplexity left>
- Cursor     — latest doc: <filename> (<date>) → <one-line summary of what Cursor left>
- Claude     — latest doc: <filename> (<date>) → <one-line summary of what previous Claude session did>

Open work:
- AUTHORIZED items from NEXUS_TODO: <count> — top 3: <one-liner each>
- BLOCKED / awaiting Ed:           <count> — top 3: <one-liner each>
- NEW (raised but not approved):   <count>

System health:
- Index freshness: <YYYY-MM-DD HH:MM> (<age in hours>)
- Pre-flight: <pass/fail per check>
- New files in last 24h: <count> (relevant ones: <names>)

Awaiting your first request.
```

The cross-agent context block is non-optional. If a section is empty (e.g., no Perplexity doc in 30 days), say so explicitly: "no recent Perplexity doc — last one is <filename> from <date>".

## Step 5 — Wait

Do not act. Do not propose. Do not write. Wait for Ed's first explicit instruction.

---

# 🌙 NEXUS sleep — Sleep Protocol

When Ed types **NEXUS sleep**, Claude writes a full session transcript before the session ends.

## What to produce

Two files, in this order:

1. `SESSION_TRANSCRIPT_<YYYY-MM-DD>_CLAUDE_<topic-slug>.md` — full transcript (see structure below)
2. `NEXUS_TODO.md` — overwritten with the updated open-items list (see structure below)

Both saved to the **central folder**: `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/`

(The transcript also gets a copy at `/Users/Broyhill/Documents/GitHub/BroyhillGOP/sessions/` if it touches database or schema work.)

## Session transcript — required structure

Use the exact template at `NEXUS_SLEEP_TEMPLATE.md`. It must include every section below:

1. **Header** — date, agent, session length, topic, related files
2. **Universe declaration** — what tables / schemas / folders / endpoints were in scope, what was off-limits
3. **What Ed asked for** — verbatim or near-verbatim, in order
4. **What Claude did** — chronological, action-by-action, with file paths and exact commands
5. **Files created** — full path + size + 1-line purpose for each
6. **Files modified** — full path + summary of change for each
7. **Database changes** — every CREATE/ALTER/INSERT/UPDATE/DELETE with row counts before/after
8. **Authorization gates** — every "I authorize this action" Ed gave, every gate that was skipped, and why
9. **Canaries verified** — the Ed canary, Pope canary, spine canary; expected vs observed
10. **Open questions** — anything Claude asked that Ed hasn't answered
11. **Decisions captured** — architectural calls Ed made that future sessions need
12. **Updated TODO** — three lists: AUTHORIZED, BLOCKED, NEW — see `NEXUS_TODO.md` structure
13. **What the next Claude session needs to know** — the smallest possible briefing to pick up where this session left off

## Detail level (this is the level Perplexity uses — Claude must match it)

- Concrete file paths, never "the file"
- Exact row counts, never "a lot"
- Exact SQL or commands run, not paraphrased
- Sample rows where applicable (5–20 lines)
- Tables for any structured comparison
- Canaries in named columns: `metric | expected | observed | status`
- Every assumption stated explicitly
- Every guardrail re-stated in the transcript so the next session is reminded

## TODO update — required structure

`NEXUS_TODO.md` is a single file overwritten each sleep. Three sections:

```
# NEXUS_TODO — <YYYY-MM-DD HH:MM>

## ✅ AUTHORIZED (Ed has approved; safe to execute next session)
1. <task> — <file path or DB change> — authorized <date>
2. ...

## ⏸ BLOCKED (waiting on Ed, on Perplexity, on Cursor, on external)
1. <task> — blocked by <reason / person / event>
2. ...

## 🆕 NEW (raised this session; needs Ed's read)
1. <task> — proposed <date> — context: <2-3 sentences>
2. ...

## 🚫 RETIRED THIS SESSION (closed / cancelled / merged)
1. <task> — why retired
2. ...
```

Order matters: **Authorized first** so the next session can pick up immediately.

---

# Trigger word vocabulary (Ed's commands to Claude)

Three words. That's it. Everything else is conversation.

| Word | What Claude does |
|---|---|
| **NEXUS** | Wake protocol — load context, run pre-flight, report state, await first request |
| **NEXUS sleep** | Sleep protocol — write full session transcript + update `NEXUS_TODO.md` |
| **STOP** | Halt mid-action; self-audit (what I was doing, why, current workspace state, risk, undo path); wait |
| **AUTHORIZE** | Single-word approval gate. Required before Claude executes any TRUNCATE / DROP / DELETE without WHERE / bulk UPDATE > 10K rows / ALTER on production / any writes to `core.*` `raw.*` `archive.*` schemas. No execution without this word. |

Optional (use rarely):
- **STATUS** — same as STOP's self-audit but without halting (just tell me what you're doing right now)
- **UNDO** — revert last file write and report (database changes route through Cursor, not Claude)

# Hard stops Claude must respect during any NEXUS session

These are the `CLAUDE.md` doctrine, restated:

- No swaps, no `ALTER` renames to promote committee data
- No writes to `core.di_donor_attribution`
- `raw.ncboe_donations` = read-only canary only
- Hetzner DB is the truth; Supabase is legacy/limited scope
- **`AUTHORIZE`** required for any TRUNCATE, DROP, DELETE without WHERE, or bulk UPDATE > 10K rows
- Ed = EDGAR, never EDWARD
- `rnc_regid` is TEXT on every table — never BIGINT
- DataTrust NC voter ID column is `state_voter_id` — not `ncid`
- Ambiguity blocks proposals — no fuzzy best-guess

# Default save destinations (every Claude write lands here, never elsewhere)

| File kind | Path |
|---|---|
| Session transcripts | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/sessions/<YYYY-MM-DD>_CLAUDE_<topic>.md` |
| Code (Python / SQL / shell) | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/scripts/<topic>_<verb>.<ext>` |
| Runbooks / specs / dryrun reports | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/runbooks/<topic>_<YYYYMMDD>.md` |
| DB migrations | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/database/migrations/<NNN>_<DESC>.sql` |
| Long-form architecture / reference | `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/MD FILES/<title>.md` |
| Cross-agent protocol files (CLAUDE.md, NEXUS.md, etc.) | `/Users/Broyhill/Documents/GitHub/BroyhillGOP/` |

All six locations are inside the morning scrape route (`/Desktop/BroyhillGOP-CURSOR`, `/Documents`, `/Downloads`, `/Desktop/NCBOE-FEC- DONORS 2015-2026`). Every Claude write must land in one of them — never `/tmp`, never the Cowork sandbox, never an unscraped path. The next morning's index picks it up automatically.

**Rule:** if Claude is uncertain where to save, default to `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/` and pick the subdirectory that matches the file kind. Never write outside the scrape route.

# Claude operating discipline (default behaviors — no command needed)

These run automatically every session. Ed does NOT have to invoke them — they're how Claude operates from boot.

1. **Dry-run by default** — any CREATE / UPDATE / DELETE / ALTER produces a dry-run report file first. Live execution requires `AUTHORIZE` from Ed.
2. **One task contract** — Ed gives one task, Claude produces one deliverable, reports back. No "while I'm here, let me also..."
3. **No mid-task pivots** — if Claude wants to change approach, Claude stops and asks. Never pivots silently.
4. **Clean-leave rule** — at any pause, the workspace must be in a state where the next agent could pick up cleanly. No half-built tables, no orphaned migrations.
5. **Canary verification** — Ed canary, Pope canary, spine canary checked before AND after any DB-touching task. Mismatch = halt, do not continue.
6. **Scope lock** — at task start, Claude declares which schemas/tables/folders are in scope and which are off-limits. Stays inside the lock.
7. **Size gate** — anything > 10K rows updated, or any DROP/TRUNCATE/ALTER on production, routes through Perplexity → Cursor → Ed. Claude does not execute it directly.

# Role split (the workflow)

Claude = **designer + reviewer**, NOT deployer.
- Claude writes SQL, reviews Perplexity's plans, suggests improvements, produces dry-run reports
- Output goes to `docs/runbooks/` and `scripts/` as files
- **Cursor** does the actual deployment (SSH'd into Hetzner) under Ed's authorization
- **Perplexity** orchestrates and plans
- **Ed** approves with `AUTHORIZE`

---

# How Ed uses these triggers

```
Ed: NEXUS
Claude: <runs wake protocol, reports state, waits>
Ed: <gives instructions>
Claude: <works>
…
Ed: NEXUS sleep
Claude: <writes SESSION_TRANSCRIPT + NEXUS_TODO; reports both file paths>
```

Optional variants:
- `NEXUS sleep brief` — short transcript (skip sample rows, keep counts and decisions)
- `NEXUS sleep full` — long transcript (default — full detail)
- `NEXUS sleep no-todo` — skip TODO update, transcript only

---

_Last updated: 2026-04-27 — Maintained alongside `CLAUDE.md`, `CENTRAL_FOLDER.md`, `AI_SEARCH_GATEWAY.md`_
