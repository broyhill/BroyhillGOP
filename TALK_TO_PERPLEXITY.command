#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  TALK_TO_PERPLEXITY.command
#  Double-click from Finder. Interactive chat with Perplexity through the relay.
#
#  Loops: shows new inbox messages → prompts you for a reply → sends → repeats.
#  Press Ctrl-C to exit.
# ═══════════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")"

RELAY="${RELAY:-http://37.27.169.232:8080}"
KEY="${KEY:-bgop-relay-k9x2mP8vQnJwT4rL}"
ME="${ME:-claude}"        # who I am — change to 'cursor' or 'system' if you want
TO="${TO:-perplexity}"    # default recipient

# Colors
B=$'\e[1m';     R=$'\e[0m'
ORG=$'\e[38;5;208m'   # perplexity orange
BLU=$'\e[38;5;75m'    # cursor blue
GRN=$'\e[38;5;46m'    # success green
RED=$'\e[38;5;196m'   # error red
GRY=$'\e[38;5;245m'   # meta grey

clear
echo "${B}═══════════════════════════════════════════════════════════════${R}"
echo "${B}  TALK TO PERPLEXITY  —  BroyhillGOP Relay${R}"
echo "${B}═══════════════════════════════════════════════════════════════${R}"
echo ""
echo "  Relay : ${RELAY}"
echo "  You   : ${ME}"
echo "  →     : ${TO}"
echo ""

# ── Sanity: relay reachable? ───────────────────────────────────────────────
echo -n "  ${GRY}Pinging relay…${R} "
HTTP=$(curl -s -o /tmp/relay_ping.json -m 5 -w "%{http_code}" "${RELAY}/health" || echo "000")
if [[ "$HTTP" == "200" ]]; then
  V=$(grep -o '"relay_version":"[^"]*"' /tmp/relay_ping.json | cut -d'"' -f4 || echo "?")
  echo "${GRN}OK${R} (v${V})"
else
  echo "${RED}HTTP $HTTP${R}"
  echo ""
  echo "  ${RED}✗ Relay not reachable.${R}"
  echo "    Run SHIP_RELAY_FIX.command first to deploy the relay."
  echo ""
  read -p "  Press return to close…"
  exit 1
fi
echo ""
echo "  ${GRY}Type your message and press Enter (empty line to send).${R}"
echo "  ${GRY}Press Ctrl-C to exit.${R}"
echo ""

# ── Helper: pretty-print one message ───────────────────────────────────────
print_message() {
  local from="$1" subj="$2" body="$3" ts="$4" tid="$5"
  local color="${BLU}"
  case "$from" in
    perplexity) color="${ORG}" ;;
    claude|cursor) color="${BLU}" ;;
    system) color="${GRY}" ;;
  esac
  echo ""
  echo "  ${color}┌─ ${B}${from}${R}${color} ──── ${GRY}${ts} ── thread ${tid}${R}"
  if [[ -n "$subj" && "$subj" != "null" ]]; then
    echo "  ${color}│ ${B}${subj}${R}"
    echo "  ${color}│${R}"
  fi
  echo "$body" | while IFS= read -r line; do
    echo "  ${color}│${R} $line"
  done
  echo "  ${color}└────────────────────────────────────────────${R}"
}

# ── Helper: fetch inbox, print only new (unread) messages ──────────────────
SEEN_IDS_FILE="/tmp/talk_perplexity_seen_${ME}.txt"
touch "$SEEN_IDS_FILE"

fetch_new_messages() {
  local data
  data=$(curl -s -m 8 "${RELAY}/inbox?agent=${ME}&unread_only=false&limit=20" \
              -H "X-API-Key: ${KEY}")
  if [[ -z "$data" ]] || ! echo "$data" | python3 -c 'import json,sys;json.load(sys.stdin)' 2>/dev/null; then
    return
  fi
  echo "$data" | python3 - "$SEEN_IDS_FILE" <<'PY'
import json, sys
seen_file = sys.argv[1]
data = json.load(sys.stdin)
seen = set()
try:
    seen = set(open(seen_file).read().split())
except: pass
new = []
for m in data.get("messages", []):
    if str(m["id"]) not in seen:
        new.append(m)
        seen.add(str(m["id"]))
# keep only the unseen-by-us, ordered oldest first
new.sort(key=lambda m: m.get("created_at",""))
for m in new:
    # tab-delimited for shell parsing
    print("\t".join([
        str(m.get("id","")),
        m.get("from_agent","?"),
        (m.get("subject") or "").replace("\t"," "),
        (m.get("body") or "").replace("\n"," ⏎ ").replace("\t"," "),
        m.get("created_at",""),
        m.get("thread_id","")
    ]))
with open(seen_file, "w") as f:
    f.write(" ".join(seen))
PY
}

# ── Helper: send a message ─────────────────────────────────────────────────
send_message() {
  local subj="$1" body="$2" tid="$3"
  local payload
  payload=$(python3 -c "
import json,sys
print(json.dumps({
    'from_agent': '${ME}',
    'to_agent':   '${TO}',
    'subject':    ${subj@Q} or None,
    'body':       ${body@Q},
    'thread_id':  ${tid@Q} or None,
}))" 2>/dev/null)

  local resp
  resp=$(curl -s -m 10 -X POST "${RELAY}/message" \
              -H "X-API-Key: ${KEY}" \
              -H "Content-Type: application/json" \
              -d "$payload")
  if echo "$resp" | grep -q '"sent":true'; then
    local sent_id sent_tid
    sent_id=$(echo "$resp" | python3 -c "import json,sys;print(json.load(sys.stdin).get('id',''))")
    sent_tid=$(echo "$resp" | python3 -c "import json,sys;print(json.load(sys.stdin).get('thread_id',''))")
    echo "  ${GRN}✓ Sent${R} ${GRY}(id=$sent_id  thread=$sent_tid)${R}"
    CUR_THREAD="$sent_tid"
  else
    echo "  ${RED}✗ Send failed:${R} $resp"
  fi
}

# ── Main loop ──────────────────────────────────────────────────────────────
CUR_THREAD=""

while true; do
  # 1. show any new messages from the other agent(s)
  while IFS=$'\t' read -r mid from subj body ts tid; do
    [[ -z "$mid" ]] && continue
    print_message "$from" "$subj" "${body//⏎/$'\n'}" "$ts" "$tid"
    CUR_THREAD="$tid"
  done < <(fetch_new_messages)

  # 2. prompt for next message
  echo ""
  if [[ -n "$CUR_THREAD" ]]; then
    echo "  ${GRY}↓ Reply in thread $CUR_THREAD (or type /new for fresh thread, /quit to exit)${R}"
  else
    echo "  ${GRY}↓ New message to $TO (or /quit to exit)${R}"
  fi

  # subject (only required for new threads)
  if [[ -z "$CUR_THREAD" ]]; then
    read -r -p "  Subject: " SUBJ
  else
    SUBJ=""
  fi

  # body — multi-line until empty line
  echo "  Body (empty line to send):"
  BODY=""
  while IFS= read -r line; do
    if [[ -z "$line" && -n "$BODY" ]]; then break; fi
    if [[ "$line" == "/quit" ]]; then exit 0; fi
    if [[ "$line" == "/new" ]]; then CUR_THREAD=""; SUBJ=""; BODY=""; echo "  ${GRY}(new thread)${R}"; continue 2; fi
    BODY="${BODY}${BODY:+$'\n'}${line}"
  done

  if [[ -z "$BODY" ]]; then
    echo "  ${GRY}(empty — skipped)${R}"
    sleep 2
    continue
  fi

  send_message "$SUBJ" "$BODY" "$CUR_THREAD"

  # 3. brief pause then poll again for reply
  echo ""
  echo "  ${GRY}Polling for reply… (Ctrl-C to stop)${R}"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 3
    NEW_OUTPUT=$(fetch_new_messages)
    if [[ -n "$NEW_OUTPUT" ]]; then
      while IFS=$'\t' read -r mid from subj body ts tid; do
        [[ -z "$mid" ]] && continue
        print_message "$from" "$subj" "${body//⏎/$'\n'}" "$ts" "$tid"
        CUR_THREAD="$tid"
      done <<< "$NEW_OUTPUT"
      break
    fi
    echo -n "  ${GRY}.${R}"
  done
  echo ""
done
