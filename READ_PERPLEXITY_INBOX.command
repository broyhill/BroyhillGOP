#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  READ_PERPLEXITY_INBOX.command
#  Double-click to see the latest 30 messages in your inbox.
#  Quick read-only view. Doesn't mark anything as read.
# ═══════════════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"

RELAY="${RELAY:-http://37.27.169.232:8080}"
KEY="${KEY:-bgop-relay-k9x2mP8vQnJwT4rL}"
ME="${ME:-claude}"

clear
echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  INBOX FOR: $ME                                              │"
echo "  │  Relay:     $RELAY                                            │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""

curl -s -m 8 "${RELAY}/inbox?agent=${ME}&unread_only=false&limit=30" \
     -H "X-API-Key: ${KEY}" \
| python3 - <<'PY'
import json, sys
from datetime import datetime
try:
    data = json.load(sys.stdin)
except Exception as e:
    print(f"  ✗ Could not parse relay response: {e}")
    sys.exit(1)
msgs = data.get("messages", [])
if not msgs:
    print("  (inbox is empty)")
    sys.exit(0)

C = {
    "perplexity": "\033[38;5;208m",
    "claude":     "\033[38;5;75m",
    "cursor":     "\033[38;5;46m",
    "system":     "\033[38;5;245m",
    "you":        "\033[38;5;39m",
}
RESET = "\033[0m"; BOLD = "\033[1m"; GREY = "\033[38;5;245m"

# Group by thread
threads = {}
for m in msgs:
    tid = m.get("thread_id") or f"orphan-{m['id']}"
    threads.setdefault(tid, []).append(m)

# Sort threads by most recent message
for tid, ms in threads.items():
    ms.sort(key=lambda m: m.get("created_at",""))
threads_sorted = sorted(threads.items(), key=lambda kv: kv[1][-1].get("created_at",""), reverse=True)

print(f"  {BOLD}{len(msgs)} message(s) across {len(threads)} thread(s){RESET}\n")

for tid, ms in threads_sorted:
    last = ms[-1]
    subj = last.get("subject") or "(no subject)"
    print(f"  {BOLD}━━━ Thread {tid}{RESET}  {GREY}— {subj}{RESET}")
    for m in ms:
        f = m.get("from_agent","?")
        color = C.get(f, "")
        ts = m.get("created_at","")[:19].replace("T"," ")
        unread = "" if m.get("read_at") else f" {color}●{RESET}"
        body = (m.get("body") or "").strip()
        # truncate body to 200 chars for the list view
        if len(body) > 240:
            body = body[:240] + "…"
        body = body.replace("\n","\n         ")
        print(f"    {color}{BOLD}{f:<10}{RESET} {GREY}{ts}{RESET}{unread}")
        print(f"         {body}")
    print()

print(f"  {GREY}● = unread.  Use TALK_TO_PERPLEXITY.command to reply.{RESET}\n")
PY

echo ""
read -p "  Press return to close…"
