# AI Protocols — BroyhillGOP

This folder contains startup and shutdown protocols for every AI agent working on the BroyhillGOP platform.

## Trigger Words (Universal Across All Agents)

| Trigger | Action |
|---|---|
| `nexus` | Boot — read MASTER_PLAN.md + latest session, present status |
| `nexus sleep` | Shutdown — write session log, update MASTER_PLAN.md |

## Files

| File | Agent | Purpose |
|---|---|---|
| `PERPLEXITY_STARTUP.md` | Perplexity AI | Startup protocol, boot sequence, nexus sleep instructions |
| `CURSOR_STARTUP.md` | Cursor IDE | Startup protocol, pre-code checklist, nexus sleep instructions |
| `CLAUDE_STARTUP.md` | Claude (Anthropic) | Startup protocol, mandatory architecture review, nexus sleep |
| `MASTER_PLAN.md` | All Agents | Shared governing document — session log, phase status, next tasks |

## How It Works

1. Ed types `nexus` → Agent reads MASTER_PLAN.md + latest session file → Boots with full context
2. Work session proceeds
3. Ed types `nexus sleep` → Agent writes dated session log → Updates MASTER_PLAN.md → Commits to GitHub
4. Next agent reads MASTER_PLAN.md on its own `nexus` boot → picks up exactly where the last agent left off

## Agent Roles

- **Perplexity** — Primary architect, session coordinator, research & planning
- **Cursor** — Primary code builder, migration executor, frontend builder  
- **Claude** — Primary SQL architect, intelligence designer, complex reasoning

---
*BroyhillGOP Platform | 55 Ecosystems | 905 Triggers | $3,520,000+ Development Value*
