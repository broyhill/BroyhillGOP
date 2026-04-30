# Claude Briefing — Relay Inbox Protocol

**Eddie: this is the briefing for me (Claude in Cowork mode and Claude Code).** It tells me when and how to check the relay so when Perplexity or Cursor sends me a message, I see it without you having to remind me.

I'll honor this protocol whenever I'm working in the BroyhillGOP context (the repo at `~/Documents/GitHub/BroyhillGOP/` is mounted, or you mention the relay, or you mention Perplexity/Cursor by name).

---

## When I should check `/inbox`

| Trigger | Action |
|---|---|
| You start a session that mentions BroyhillGOP, the relay, Perplexity, or Cursor | Fetch `/inbox?agent=claude&unread_only=true` immediately and report any unread |
| You say "check relay", "check inbox", or "any messages?" | Same — fetch and report |
| You hand me a task that another agent might be waiting on | Fetch first, see if there's already a related thread |
| You say "tell Perplexity..." or "tell Cursor..." | Send via `/message` to that agent |
| You say "broadcast to everyone" or "tell all agents" | Send to `to_agent: "all"` |
| In the middle of a long session if 30+ min passed | Quietly re-fetch at a natural pause |

## How I'll fetch

```bash
curl -s "http://37.27.169.232:8080/inbox?agent=claude&unread_only=true&limit=50" \
     -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL"
```

## How I'll report what's there

For every unread message I find, I'll surface a short summary:
- Who it's from (`from_agent`)
- The subject line
- A 1–2 sentence summary of the body
- Anything in `payload` that looks actionable
- The thread_id, so you can reference it

Then I'll ask whether to act on it, reply, or just acknowledge.

## How I'll send

To message Perplexity (architecture / blueprint questions):

```bash
curl -X POST http://37.27.169.232:8080/message \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
  -H "Content-Type: application/json" \
  -d '{"from_agent":"claude","to_agent":"perplexity","subject":"...","body":"..."}'
```

To message Cursor (file edits, deploys, SQL execution):

```bash
curl -X POST http://37.27.169.232:8080/message \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
  -H "Content-Type: application/json" \
  -d '{"from_agent":"claude","to_agent":"cursor","subject":"...","body":"..."}'
```

To broadcast a status update everyone should see:

```bash
curl -X POST http://37.27.169.232:8080/message \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
  -H "Content-Type: application/json" \
  -d '{"from_agent":"claude","to_agent":"all","subject":"...","body":"..."}'
```

## How I'll reply to a message

When I act on a message from Perplexity or Cursor, I'll close the loop by posting to `/reply` with `parent_id` so the sender knows I handled it and the original thread stays linked.

## Reference

Full endpoint contract: [`docs/RELAY_MESSAGING_CONTRACT.md`](./docs/RELAY_MESSAGING_CONTRACT.md)

---

## What you (Eddie) should know

- **You don't need to paste this anywhere.** This file exists in the repo so I see it when the repo is mounted into a Cowork session — that's enough for me to honor the protocol.
- **If I'm in a fresh Cowork session that isn't BroyhillGOP-context yet**, just say "check the relay" or mount this folder, and I'll start polling.
- **For brand-new Cowork sessions where the repo isn't mounted**, you can prepend this paragraph to your first message:
  > *"I'm in BroyhillGOP context. Check `~/Documents/GitHub/BroyhillGOP/CLAUDE_BRIEFING.md` and follow that protocol. Start by polling the relay inbox."*
