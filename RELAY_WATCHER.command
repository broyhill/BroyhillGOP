#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  RELAY_WATCHER.command
#  Double-click and leave running. Polls the relay inbox every 30s and pops a
#  macOS notification anytime Perplexity, Claude, or Cursor sends a message
#  that you (Eddie) haven't seen yet — for ANY of the three agents.
#
#  Press Ctrl-C in the terminal window to stop watching.
# ═══════════════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"

RELAY="${RELAY:-http://37.27.169.232:8080}"
KEY="${KEY:-bgop-relay-k9x2mP8vQnJwT4rL}"
POLL_SEC="${POLL_SEC:-30}"
SEEN_FILE="$HOME/.bgop_relay_seen.txt"
touch "$SEEN_FILE"

clear
echo "═══════════════════════════════════════════════════════════════════════"
echo "  RELAY WATCHER  —  BroyhillGOP message bus"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "  Watching all three inboxes (perplexity, claude, cursor) every ${POLL_SEC}s."
echo "  macOS notifications will pop on every new message."
echo "  Ctrl-C to stop."
echo ""
echo "  Relay : ${RELAY}"
echo ""

# ── Confirm the relay responds ─────────────────────────────────────────────
HTTP=$(curl -s -o /dev/null -m 5 -w "%{http_code}" "${RELAY}/health" || echo "000")
if [[ "$HTTP" != "200" ]]; then
  echo "  ✗ Relay /health returned HTTP $HTTP — make sure SHIP_RELAY_FIX.command has been run."
  echo ""
  read -p "  Press return to close…"
  exit 1
fi
echo "  ✓ Relay is up."
echo ""

# ── macOS notification helper ──────────────────────────────────────────────
notify() {
  local title="$1" body="$2"
  # escape backslashes and double-quotes for AppleScript
  body=$(echo "$body" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  title=$(echo "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')
  osascript -e "display notification \"${body:0:200}\" with title \"${title}\" sound name \"Glass\"" 2>/dev/null || true
}

echo "── Polling started ──"
echo ""

while true; do
  TS=$(date +'%H:%M:%S')

  # Pull every agent's inbox (relay returns oldest-first, so order is consistent)
  for AGENT in perplexity claude cursor; do
    DATA=$(curl -s -m 8 "${RELAY}/inbox?agent=${AGENT}&unread_only=false&limit=50" \
                -H "X-API-Key: ${KEY}" 2>/dev/null)
    if [[ -z "$DATA" ]]; then continue; fi

    # Use python to walk the JSON, find unseen IDs, output one notification line per new msg
    NEW=$(echo "$DATA" | python3 - "$SEEN_FILE" "$AGENT" <<'PY' 2>/dev/null
import json, sys, os
seen_path, agent = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
seen = set()
if os.path.exists(seen_path):
    seen = set(open(seen_path).read().split())
new = []
for m in data.get("messages", []):
    mid = str(m["id"])
    if mid in seen: continue
    seen.add(mid)
    fr  = m.get("from_agent","?")
    sub = (m.get("subject") or "(no subject)")[:80]
    body= (m.get("body") or "")[:140]
    # tab-delimited: agent_inbox \t from \t subject \t body
    new.append(f"{agent}\t{fr}\t{sub}\t{body}")
with open(seen_path, "w") as f:
    f.write(" ".join(seen))
print("\n".join(new))
PY
)
    if [[ -n "$NEW" ]]; then
      while IFS=$'\t' read -r in_box frm subj body; do
        [[ -z "$in_box" ]] && continue
        echo "  [${TS}] ${frm} → ${in_box}'s inbox: ${subj}"
        echo "          ${body}"
        echo ""
        notify "${frm} → ${in_box}" "${subj} — ${body}"
      done <<< "$NEW"
    fi
  done

  sleep "$POLL_SEC"
done
