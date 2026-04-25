# BroyhillGOP Relay — 3-Way Messaging Contract

**Effective:** April 25, 2026
**Supersedes:** any prior 2-agent (Perplexity ↔ Claude) message protocol

This document is the canonical reference for **Perplexity ↔ Claude ↔ Cursor** message exchange via the BroyhillGOP relay.

---

## 1. Endpoint

```
Base URL:   http://37.27.169.232:8080
Auth:       header  X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL
Content:    application/json
```

The relay is a FastAPI app at `relay.py` in the repo root. Messages are persisted in Supabase table `brain.agent_messages` and announced on Redis channel `bgop:agent_channel` for live listeners.

---

## 2. The Roster

| Agent name (string) | Who they are | When you'd talk to them |
|---|---|---|
| `perplexity` | Perplexity Pro AI agent | Architecture, blueprint generation, schema design |
| `claude`     | Claude (in any client — Cowork, Claude.ai, Claude Code) | Code edits, file operations, briefings |
| `cursor`     | Cursor IDE agent on Eddie's machine | Local code execution, repo edits, deploys |
| `system`     | Cron / scheduled scripts | Automated alerts |
| `both`       | (legacy) broadcast to perplexity + claude | Backward compatibility only |
| `all`        | broadcast to all three human agents | Use this for new 3-way fan-out |

---

## 3. Send a Message — `POST /message`

```bash
curl -X POST http://37.27.169.232:8080/message \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
  -H "Content-Type: application/json" \
  -d '{
    "from_agent": "perplexity",
    "to_agent":   "cursor",
    "subject":    "Phase D — column migration ready",
    "body":       "Run the DDL in docs/BGOP_ARCHITECTURE_BRIEF.docx §3. Confirm row counts when done.",
    "payload":    {"file": "docs/BGOP_ARCHITECTURE_BRIEF.docx", "section": "3"},
    "thread_id":  null
  }'
```

**Response:**
```json
{ "sent": true, "id": 227, "thread_id": "9f3a1c2b", "timestamp": "2026-04-25T20:14:31Z" }
```

`thread_id` is auto-assigned if you pass `null`. Capture it so replies stay threaded.

---

## 4. Read Your Inbox — `GET /inbox`

Each agent should poll this at the **start of every session**.

```bash
# Claude checking own inbox + broadcast messages
curl "http://37.27.169.232:8080/inbox?agent=claude&unread_only=true&limit=50" \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"

# Cursor checking own inbox
curl "http://37.27.169.232:8080/inbox?agent=cursor&unread_only=true" \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"

# Perplexity checking own inbox
curl "http://37.27.169.232:8080/inbox?agent=perplexity&unread_only=true" \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"
```

`include_both=true` (default) auto-includes anything addressed to `both` or `all`.

---

## 5. Reply — `POST /reply`

A reply auto-marks the parent as read and routes to the parent's sender.

```bash
curl -X POST http://37.27.169.232:8080/reply \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
  -H "Content-Type: application/json" \
  -d '{
    "from_agent": "cursor",
    "parent_id":  227,
    "body":       "DDL applied. core.person_master rowcount = 333,142.",
    "payload":    {"row_counts": {"core.person_master": 333142}}
  }'
```

You can also reply without a parent by supplying `thread_id` directly.

---

## 6. Read a Whole Thread — `GET /thread/{thread_id}`

```bash
curl http://37.27.169.232:8080/thread/9f3a1c2b \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"
```

Returns chronological list of all messages sharing that `thread_id`.

---

## 7. Mark Read — `PATCH /message/{id}/read`

Mostly handled automatically by `/reply`, but available manually:

```bash
curl -X PATCH http://37.27.169.232:8080/message/227/read \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"
```

---

## 8. Liveness — `GET /health`

No auth required. Use this for monitoring.

```bash
curl http://37.27.169.232:8080/health
# → {"ok": true, "redis": "ok", "supabase": "ok", "version": "1.3"}
```

---

## 9. Operating Cadence (recommended)

| Agent | Cadence |
|---|---|
| Claude (Cowork) | Check `/inbox` at session start. Reply within the same session. Use `to_agent: "all"` for status broadcasts. |
| Perplexity | Check `/inbox` at session start. Use `subject` field — it's how Eddie scans threads. |
| Cursor | Pull `/inbox` whenever the user opens the repo. Post `/reply` after every applied change. |

---

## 10. Common Patterns

**Architecture handoff (Perplexity → Cursor):**
```json
{ "from_agent": "perplexity", "to_agent": "cursor",
  "subject": "Apply migration 056",
  "body": "Run docs/migrations/056_xxx.sql on hetzner-bgop. Roll back via rollback_056.sql.",
  "payload": {"migration": "056", "rollback": "rollback_056.sql"} }
```

**Status update (Cursor → all):**
```json
{ "from_agent": "cursor", "to_agent": "all",
  "subject": "Migration 056 applied",
  "body": "Schema change live. 1.2M rows updated, 0 errors." }
```

**Question (Claude → Perplexity):**
```json
{ "from_agent": "claude", "to_agent": "perplexity",
  "subject": "E40 vs E41 boundary",
  "body": "Should automation triggers (cron-style) live in E40 or E41? Need a one-line answer." }
```

---

## 11. What Was Broken Until April 25, 2026

- `docker-compose.yml` ran `python app/relay.py` but `relay.py` is at repo root → relay container exited on startup since the last redeploy → port 8080 had no listener → no messaging was actually flowing despite SESSION-STATE saying "RUNNING."
- `_validate_agent()` didn't recognize `"cursor"` as a valid agent name.

Both fixed in this commit. Run `deploy_relay.sh` on Hetzner to ship.
