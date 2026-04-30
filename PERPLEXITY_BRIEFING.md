# Perplexity Briefing — How to Message Claude and Cursor via the BroyhillGOP Relay

**Eddie: paste this entire document into Perplexity once.** It teaches Perplexity the relay protocol so Perplexity can autonomously message Claude and Cursor whenever it has something to hand off, ask, or report.

---

> **Perplexity — read and internalize.**
>
> You are now connected to the BroyhillGOP **relay**, a small HTTP service that lets you exchange messages with two other agents I work with: **Claude** (running in Cowork mode and Claude Code) and **Cursor** (the Cursor IDE on my Mac). All three of you can now coordinate without me being in the loop on every handoff.
>
> ### Your relay endpoint
>
> ```
> Base URL : http://37.27.169.232:8080
> Auth     : header  X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL
> Content  : application/json
> ```
>
> ### Who's on the bus
>
> | `to_agent` value | Recipient |
> |---|---|
> | `"claude"`     | Claude — running in my Cowork or Claude Code session |
> | `"cursor"`     | Cursor IDE on my Mac |
> | `"all"`        | Broadcast to both Claude and Cursor (recommended for status updates) |
> | `"both"`       | Legacy alias for Claude + Perplexity (use `"all"` instead) |
>
> Your own identity is `"perplexity"` — always set that as `from_agent`.
>
> ### How to send a message
>
> Make this exact HTTP call whenever you need to hand off architecture, ask a clarifying question, or post a status update:
>
> ```bash
> curl -X POST http://37.27.169.232:8080/message \
>   -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
>   -H "Content-Type: application/json" \
>   -d '{
>     "from_agent": "perplexity",
>     "to_agent":   "claude",
>     "subject":    "Phase D ready — column migration",
>     "body":       "I generated DDL for the 12 column mods. Apply migration 056_column_migration.sql on Hetzner and confirm row counts. Rollback file is rollback_056.sql.",
>     "payload":    {"migration": "056", "files": ["056_column_migration.sql","rollback_056.sql"]}
>   }'
> ```
>
> The relay returns:
> ```json
> { "sent": true, "id": 228, "thread_id": "9f3a1c2b", "timestamp": "2026-04-25T20:30:15Z" }
> ```
>
> Save the `thread_id`. To **reply** to a message Claude or Cursor sent you, post to `/reply` with `parent_id` set to their message's `id` — that auto-routes the reply back to whoever wrote you and marks their message read.
>
> ### How to read your own inbox
>
> When I (Eddie) tell you "check the relay" or you want to see if Claude or Cursor wrote you:
>
> ```bash
> curl "http://37.27.169.232:8080/inbox?agent=perplexity&unread_only=true&limit=50" \
>      -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"
> ```
>
> You'll get back a JSON list of messages. Process them in order, reply to each via `/reply`, and report a one-line summary to me.
>
> ### When to use the relay (vs. just answering me)
>
> | Situation | What to do |
> |---|---|
> | Eddie asks you a question and you can answer in this chat | Just answer — no relay needed |
> | You generate a SQL migration / DDL Cursor needs to apply | Send to `cursor` |
> | You generate documentation Claude should keep in context | Send to `claude` |
> | You make an architectural decision the others should know | Send to `all` (broadcast) |
> | You need Claude to fetch something or do file I/O | Send to `claude` |
> | You need Cursor to push code to GitHub or SSH-deploy | Send to `cursor` |
> | Eddie tells you "tell Claude to..." or "have Cursor..." | Send via relay immediately |
>
> ### Required fields
>
> Every `/message` POST must include:
> - `from_agent` — always `"perplexity"`
> - `to_agent` — `"claude"`, `"cursor"`, or `"all"`
> - `body` — the actual message text
>
> Strongly recommended:
> - `subject` — one short line; this is what shows up in inbox listings
> - `payload` — any structured data (file paths, SQL, table names, JSON the recipient should parse)
> - `thread_id` — only when continuing an existing thread (omit for first message; relay assigns one)
>
> ### Practical patterns
>
> **Architecture handoff to Cursor:**
> ```json
> { "from_agent": "perplexity", "to_agent": "cursor",
>   "subject": "Apply migration 057",
>   "body": "Run docs/migrations/057_xxx.sql on Hetzner-bgop. If row count > 1M, do it in transactions of 100k. Rollback in rollback_057.sql.",
>   "payload": {"migration": "057", "rollback": "rollback_057.sql", "batch_size": 100000} }
> ```
>
> **Question for Claude:**
> ```json
> { "from_agent": "perplexity", "to_agent": "claude",
>   "subject": "E40 vs E41 boundary",
>   "body": "Should the cron-triggered automation rules live in E40 (Automation Control) or E41 (Campaign Builder)? One-line answer please." }
> ```
>
> **Status broadcast:**
> ```json
> { "from_agent": "perplexity", "to_agent": "all",
>   "subject": "Blueprint E62 ready",
>   "body": "Just dropped E62_FUNDRAISER_OPS.docx in ECOSYSTEM_REPORTS. 7-layer schema, 14 tables, 45 indexes." }
> ```
>
> ### Acknowledgment protocol
>
> Once you've absorbed this, please send a confirmation message:
>
> ```json
> { "from_agent": "perplexity", "to_agent": "all",
>   "subject": "Perplexity online",
>   "body": "Relay protocol absorbed. I will message Claude/Cursor directly when handing off work, and check /inbox at the start of each session." }
> ```
>
> Eddie will see that confirmation come through and know the bus is live for all three of us.

---

## Notes for Eddie

- **You only need to paste the boxed prompt above into Perplexity once per major Perplexity context** (a project / spaces conversation). After that, Perplexity remembers and will use the relay autonomously when the situation calls for it.
- **The full protocol reference** with every endpoint is at `docs/RELAY_MESSAGING_CONTRACT.md`.
- **Claude (me, in Cowork)** has its own briefing at `CLAUDE_BRIEFING.md` — I check the relay inbox whenever you mention messaging, the relay, or another agent.
- **Cursor** has its own briefing at `CURSOR_BRIEFING.md` — drop it into your `.cursorrules` so Cursor polls the inbox at session start.
- **Background notifications**: run `RELAY_WATCHER.command` once and leave it open — you'll get a macOS notification anytime Perplexity, Claude, or Cursor posts a new message, so you can see the agents talking to each other in real time.
