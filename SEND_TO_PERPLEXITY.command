#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  SEND_TO_PERPLEXITY.command
#  Quick fire-and-forget send. No back-and-forth. For one-shot questions.
#  Use TALK_TO_PERPLEXITY.command for an interactive chat session.
# ═══════════════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"

RELAY="${RELAY:-http://37.27.169.232:8080}"
KEY="${KEY:-bgop-relay-k9x2mP8vQnJwT4rL}"
ME="${ME:-claude}"
TO="${TO:-perplexity}"

clear
echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  SEND TO PERPLEXITY  (single message)                        │"
echo "  │  From: $ME  →  To: $TO                                       │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""

read -r -p "  Subject: " SUBJECT
echo "  Body (end with a single line containing only '.', then return):"
BODY=""
while IFS= read -r line; do
  if [[ "$line" == "." ]]; then break; fi
  BODY="${BODY}${BODY:+$'\n'}${line}"
done

if [[ -z "$BODY" ]]; then
  echo "  (empty body — aborted)"
  read -p "  Press return to close…"
  exit 0
fi

PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'from_agent': '${ME}',
    'to_agent':   '${TO}',
    'subject':    ${SUBJECT@Q} or None,
    'body':       ${BODY@Q},
}))")

echo ""
echo "  Sending…"
RESP=$(curl -s -m 10 -X POST "${RELAY}/message" \
            -H "X-API-Key: ${KEY}" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD")

if echo "$RESP" | grep -q '"sent":true'; then
  ID=$(echo "$RESP" | python3 -c "import json,sys;print(json.load(sys.stdin).get('id',''))")
  TID=$(echo "$RESP" | python3 -c "import json,sys;print(json.load(sys.stdin).get('thread_id',''))")
  echo "  ✓ Sent. id=$ID  thread=$TID"
  echo ""
  echo "  Use READ_PERPLEXITY_INBOX.command in a few minutes to see the reply,"
  echo "  or TALK_TO_PERPLEXITY.command for a live conversation."
else
  echo "  ✗ Send failed:"
  echo "    $RESP"
fi
echo ""
read -p "  Press return to close…"
