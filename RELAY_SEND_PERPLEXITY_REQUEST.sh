#!/usr/bin/env bash
# =============================================================================
# Send the V4 full-disclosure request to Perplexity via the relay.
# Created: 2026-04-26 by Claude at Ed's direction.
# Run from: ~/Documents/GitHub/BroyhillGOP
# =============================================================================
set -euo pipefail

# Relay endpoint — try the GEX44 first (per CLAUDE_BRIEFING.md), then fall back
# to the AX41-NVMe address (per CURSOR_BRIEFING.md) if the first is unreachable.
PRIMARY_RELAY="http://5.9.99.109:8080"
FALLBACK_RELAY="http://37.27.169.232:8080"
API_KEY="bgop-relay-k9x2mP8vQnJwT4rL"

MESSAGE_FILE="$(dirname "$0")/RELAY_MESSAGE_TO_PERPLEXITY_2026-04-26.json"

if [[ ! -f "$MESSAGE_FILE" ]]; then
  echo "ERROR: $MESSAGE_FILE not found" >&2
  exit 1
fi

send() {
  local relay="$1"
  curl -sS -X POST "$relay/message" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    --max-time 15 \
    -d @"$MESSAGE_FILE"
}

echo "→ Posting to primary relay: $PRIMARY_RELAY"
if RESPONSE=$(send "$PRIMARY_RELAY" 2>&1); then
  echo "$RESPONSE"
  echo
  echo "✓ Sent. Watch Perplexity's reply with:"
  echo "  curl -s -H 'X-API-Key: $API_KEY' '$PRIMARY_RELAY/inbox?agent=claude&unread_only=true&limit=20'"
  exit 0
fi

echo "Primary relay failed. Trying fallback: $FALLBACK_RELAY"
if RESPONSE=$(send "$FALLBACK_RELAY" 2>&1); then
  echo "$RESPONSE"
  echo
  echo "✓ Sent via fallback. Watch with:"
  echo "  curl -s -H 'X-API-Key: $API_KEY' '$FALLBACK_RELAY/inbox?agent=claude&unread_only=true&limit=20'"
  exit 0
fi

echo "ERROR: both relays unreachable. Check that the relay container is up:" >&2
echo "  ssh root@hetzner-1 'docker ps | grep relay'" >&2
exit 2
