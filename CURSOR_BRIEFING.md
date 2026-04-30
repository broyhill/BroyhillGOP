# Cursor Briefing — Auto-Polling the BroyhillGOP Relay

**Eddie: append the boxed block below to your existing `.cursorrules` file** at the repo root. (Don't replace what's there — your existing rules about preflight validators, data rules, etc. all stay. This adds new behavior on top.)

The block teaches Cursor to:
1. Check the relay inbox at every session start (alongside the existing preflight)
2. Surface any messages from Perplexity or Claude before doing anything else
3. Reply via the relay when it finishes a task that came from another agent
4. Optionally poll periodically during long sessions

---

## Block to append to `.cursorrules`

```markdown
## RELAY INBOX — CHECK AT EVERY SESSION START

After running /tools/preflight_validator.py and BEFORE reading the next
cursor_tasks/ file, check the agent message bus.

Run this once at session start:

    curl -s "http://37.27.169.232:8080/inbox?agent=cursor&unread_only=true&limit=20" \
         -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"

Parse the JSON. For every message in `messages[]`:
- Print: `[from_agent] subject — body (first 200 chars)`
- If `to_agent` is `cursor` (not just `all`), it's directed at you specifically — handle it before any tasks.
- If `to_agent` is `all`, it's informational — log it and proceed.

If a message asks you to do something (apply migration, push code, run a deploy):
1. Confirm with Ed before executing if it touches production data
2. Execute the request
3. Reply via /reply with the result:

    curl -X POST http://37.27.169.232:8080/reply \
      -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
      -H "Content-Type: application/json" \
      -d '{
        "from_agent": "cursor",
        "parent_id":  <ID of the message you're replying to>,
        "body":       "Done. <one-line summary of what you did and the result>.",
        "payload":    {<any structured data — row counts, file paths, exit codes>}
      }'

## RELAY OUTBOUND — WHEN TO POST TO IT YOURSELF

After completing any task that another agent (Perplexity or Claude) handed
you via the relay, post a confirmation back to them so they know it's done.

After completing a task Ed handed you directly in chat, you do NOT need to
post — Ed sees the result in front of him.

## RELAY POLLING DURING LONG SESSIONS

If a session lasts more than 15 minutes, re-poll /inbox every ~5 minutes
during natural pause points (between tasks, while waiting for a build, etc.).
Do NOT interrupt a running migration or deploy to poll.

## RELAY ROSTER

| Agent name (`to_agent` value) | Who they are |
|---|---|
| `claude`     | Claude in Cowork mode or Claude Code |
| `perplexity` | Perplexity AI agent — does architecture and blueprint generation |
| `cursor`     | YOU |
| `all`        | Broadcast to all three agents (for status updates) |

Full protocol: docs/RELAY_MESSAGING_CONTRACT.md
```

---

## How to install this in Cursor

**Option A — append manually:**
1. Open `~/Documents/GitHub/BroyhillGOP/.cursorrules` in Cursor
2. Scroll to the bottom
3. Paste the boxed block above
4. Save

**Option B — let Cursor do it:**

Paste this single instruction into Cursor's chat:

> Cursor — open `.cursorrules` at the repo root and append the contents of `CURSOR_BRIEFING.md` (the section between the triple-backtick blocks). Save the file. Then test the relay by running:
>
>     curl -s "http://37.27.169.232:8080/inbox?agent=cursor&unread_only=true" -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"
>
> and report whatever you get.

That's it. Once `.cursorrules` has the block, every new Cursor session in this repo will check the relay inbox automatically.
