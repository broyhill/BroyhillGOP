# NEXUS Sleep Template — Session Transcript

> Claude: when Ed types `NEXUS sleep`, copy this template into a new file at the path
> `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/SESSION_TRANSCRIPT_<YYYY-MM-DD>_CLAUDE_<topic-slug>.md`
> and fill in every section. Do NOT abbreviate. Match the level of detail Perplexity uses
> in `PERPLEXITY_HANDOFF_*.md` files.

---

# Session Transcript — <topic in plain English>

**Agent:** Claude (Anthropic)
**Date:** <YYYY-MM-DD>
**Started:** <HH:MM Eastern>
**Ended:** <HH:MM Eastern>
**Duration:** <e.g. 2h 14m>
**Trigger:** NEXUS wake → NEXUS sleep
**Mode:** <Cowork desktop / claude.ai web / Cursor inline>
**Repo:** <git branch + last commit if applicable>
**Related session(s):** <previous transcript filename if continuation>

---

## 1. Universe declaration

**In scope:**
- Schemas: <e.g. `staging.*`, `core.contribution_map` read-only, …>
- Folders: <e.g. `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/runbooks/`>
- Endpoints: <e.g. Hetzner Postgres on 37.27.169.232:5432 via bore tunnel>
- Files: <list of files touched or referenced>

**Off-limits this session:**
- <e.g. `raw.ncboe_donations` (read-only canary only)>
- <e.g. `core.di_donor_attribution` (no writes)>
- <e.g. Stage 4 propagation, _v2 swap, FEC ingestion>

---

## 2. What Ed asked for (verbatim, in order)

> 1. <Ed's first ask, near-verbatim>
> 2. <Ed's second ask>
> 3. …

If Ed re-scoped mid-session, capture both the original and the revised ask with the timestamp of the change.

---

## 3. What Claude did (chronological)

For each action, in order:

| # | Time | Action | Target / file / table | Result |
|---|------|--------|-----------------------|--------|
| 1 | HH:MM | <verb + object> | <path or table> | <row count / size / pass-fail> |
| 2 | HH:MM | … | … | … |

Below the table, expand each step that involved code or SQL with the exact command run:

```bash
# Step 1
<the actual command>
```

```sql
-- Step 2
<the actual SQL>
```

---

## 4. Files created

| Path | Size | Purpose |
|------|------|---------|
| `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/<file>.md` | <bytes> | <one-line role> |

---

## 5. Files modified

| Path | Change summary |
|------|----------------|
| `/Users/Broyhill/Documents/GitHub/BroyhillGOP/<file>` | <what changed and why> |

---

## 6. Database changes

For each schema or data change:

```sql
-- Statement run (or proposed if dry-run only):
<the SQL>
```

| Object | Operation | Rows before | Rows after | Δ | Tier |
|--------|-----------|-------------|------------|---|------|
| `staging.foo` | INSERT | 0 | 12,341 | +12,341 | dry-run / authorized / executed |

Mark every row with one of:
- `dry-run` — proposed, not executed
- `authorized` — Ed gave the exact phrase, executed
- `executed-safe` — read-only or temp-only, no auth needed

---

## 7. Authorization gates

| Gate | Asked at | Phrase received | Action |
|------|----------|-----------------|--------|
| <e.g. UPDATE 24K rows on staging> | HH:MM | `I AUTHORIZE THIS ACTION` | executed at HH:MM |
| <e.g. proposed DROP TABLE> | HH:MM | (declined / not given) | aborted |

If Claude proceeded without the exact phrase on something requiring it, that is a doctrine
violation — record it explicitly with `⚠ DOCTRINE VIOLATION` and what Ed should know.

---

## 8. Canaries verified

| Canary | Expected | Observed | Status |
|--------|----------|----------|--------|
| Ed Broyhill (cluster 372171, `raw.ncboe_donations`) | 147 txns / $332,631.30 / ed@broyhill.net | <observed> | ✓ / ✗ |
| Pope canary | <expected> | <observed> | ✓ / ✗ |
| Spine canary | <expected> | <observed> | ✓ / ✗ |
| Index freshness | <expected age> | <observed age> | ✓ / ✗ |

If any canary failed, halt that workstream and capture the exact failure here. Do not
proceed on top of a failed canary.

---

## 9. Open questions for Ed

Numbered list. Each item:

> **Q1.** <The exact question — single, specific, answerable in 1-2 sentences>
> Context: <2-3 lines on why this matters and what Claude needs to act>
> Blocking: <yes/no, and which TODO item is blocked>

---

## 10. Decisions captured (architectural / doctrine / naming)

These are calls Ed made this session that future sessions must respect. Examples:

- "James Sr Broyhill rolls up to ED_BROYHILL_FAMILY_OFFICE in `credited_to`"
- "Stage 4 strict mode is now the default — non-strict is deprecated"
- "Apollo data with jsneeden@msn.com is bad — clear it on sight"
- "Cursor's `BroyhillGOP-CURSOR/` repo is the canonical work folder, not GitHub"

For each decision, capture: **what was decided**, **what was rejected**, **why**, **who else needs to know** (Perplexity, Cursor, future Claude).

---

## 11. Updated TODO (also written to `NEXUS_TODO.md`)

### ✅ AUTHORIZED (safe to execute next session)
1. …

### ⏸ BLOCKED
1. … — blocked by <reason>

### 🆕 NEW (raised this session, awaiting Ed)
1. …

### 🚫 RETIRED THIS SESSION
1. …

---

## 12. Brief for the next Claude session

The smallest possible context dump so a fresh Claude session can pick up. Three short paragraphs max:

**State now:**
<2-3 sentences on what's true today that wasn't before this session>

**Next action:**
<1 sentence — exactly what should happen first>

**Watch out for:**
<1-2 sentences on doctrine items, canaries, or pitfalls relevant to the next move>

---

_End of session transcript — Claude (Anthropic) — NEXUS sleep — <YYYY-MM-DD HH:MM>_
