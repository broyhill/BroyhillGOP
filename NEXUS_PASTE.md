# NEXUS_PASTE — One-block universal session opener

Copy everything between the bars below and paste into a new Claude or Perplexity session.
Same paste works every time. No editing needed.

---

```
═══════════════════════════════════════════════════════════════════
NEXUS — WAKE
═══════════════════════════════════════════════════════════════════
You are entering a BroyhillGOP session. Before doing anything else, run
NEXUS wake by reading the seven files below in this order, plus the three
latest agent handoffs. After reading, report what you found.

START-UP FILES (read in order):
  1. https://github.com/broyhill/BroyhillGOP/blob/main/CLAUDE.md
  2. https://github.com/broyhill/BroyhillGOP/blob/main/WHERE.md
  3. https://github.com/broyhill/BroyhillGOP/blob/main/NEXUS.md
  4. https://github.com/broyhill/BroyhillGOP/blob/main/CENTRAL_FOLDER.md
  5. https://github.com/broyhill/BroyhillGOP/blob/main/AI_SEARCH_GATEWAY.md
  6. https://github.com/broyhill/BroyhillGOP/blob/main/NEXUS_TODO.md
  7. https://github.com/broyhill/BroyhillGOP/blob/main/SESSION-STATE.md

LATEST AGENT HANDOFFS (find the newest of each in the repo and read):
  • PERPLEXITY_HANDOFF_*.md   (most recent at the repo root)
  • CURSOR_HANDOFF_*.md       (most recent at the repo root)
  • SESSION_TRANSCRIPT_*_CLAUDE_*.md   (most recent in /sessions/ or central folder)

REPORT BACK in this exact shape:

  NEXUS WAKE ✓
  • Perplexity left:   <filename, date, one-line summary>
  • Cursor left:       <filename, date, one-line summary>
  • Claude left:       <filename, date, one-line summary>
  • Authorized open:   <count> — top 3 from NEXUS_TODO
  • Blocked:           <count> — top 3 reasons
  • Pressing topic:    <what looks most pressing right now, one line>
  • Proposed dry-run:  <one-paragraph plan for the pressing topic, scope-locked>

  Awaiting AUTHORIZE before any live execution.

DOCTRINE (always in force):
  • Hetzner DB is truth. Supabase is legacy/limited.
  • raw.ncboe_donations = read-only canary only.
  • No writes to core.di_donor_attribution.
  • Ed = EDGAR (never EDWARD). rnc_regid is TEXT (never BIGINT).
  • DataTrust NC voter ID column is state_voter_id (not ncid).
  • Ed canary: cluster 372171 → 147 txns / $332,631.30 / ed@broyhill.net.
  • Trigger words from Ed: NEXUS / NEXUS sleep / STOP / AUTHORIZE.
  • Dry-run by default. No destructive ops without AUTHORIZE.
  • Single-task contract. No silent pivots.
  • End with NEXUS sleep → full transcript + NEXUS_TODO update.

Read all the files now and return the report. Do not act on the
pressing topic until I respond.
═══════════════════════════════════════════════════════════════════
```

---

## How to use

1. Open a new Claude or Perplexity session
2. Copy the block above (between the bars)
3. Paste, send
4. Read the agent's wake report
5. Either redirect ("work on X instead") or type `AUTHORIZE` to proceed

That's the whole flow. Same block forever.

## Why this works

It's a single self-contained F-16 trigger. The agent has to read the live state (GitHub repo, handoffs, TODO) before responding, which:
- Skips the warm-up hour for Perplexity
- Loads cross-agent context for Claude
- Forces a dry-run-first response
- Reminds both agents of the doctrine and trigger-word vocabulary

If GitHub is down or the agent can't fetch URLs, it will say so in the report — which is the right behavior.

## When you want a topic-specific prompt instead

Use the script:

```bash
bash /Users/Broyhill/Documents/GitHub/BroyhillGOP/nexus_prompt.sh "your topic" --pbcopy
```

That generates a topic-driven brief and copies it to your clipboard.

For 95% of sessions, the universal block above is enough.
