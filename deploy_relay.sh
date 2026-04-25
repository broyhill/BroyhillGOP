#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy_relay.sh — restore the BroyhillGOP relay on Hetzner (37.27.169.232)
#
# What this fixes:
#   docker-compose.yml had `python app/relay.py` but relay.py is at repo root.
#   Container exits immediately, port 8080 has no listener.
#   This script pulls the fix, rebuilds the relay container, and validates.
#
# How to use:
#   ssh root@37.27.169.232
#   cd /path/to/BroyhillGOP   # wherever the repo lives on Hetzner
#   bash deploy_relay.sh
#
# Or paste this whole file inline if you don't want to scp it.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(pwd)}"
RELAY_HOST="${RELAY_HOST:-37.27.169.232}"
RELAY_PORT="${RELAY_PORT:-8080}"

cd "$REPO_DIR"

echo "==> Repo: $(pwd)"
echo "==> Pulling latest main…"
git fetch --all --prune
git reset --hard origin/main

# Verify the fix landed in compose
if grep -q "python app/relay.py" docker-compose.yml; then
  echo "FATAL: docker-compose.yml still references 'app/relay.py'."
  echo "       Pull or merge again — the fix commit is missing."
  exit 1
fi

# Make sure relay.py and .env exist
[[ -f relay.py ]] || { echo "FATAL: relay.py missing at repo root"; exit 1; }
[[ -f .env     ]] || { echo "FATAL: .env missing at repo root"; exit 1; }

echo ""
echo "==> Stopping old relay container (if running)…"
docker compose stop relay || true
docker compose rm -f relay || true

echo ""
echo "==> Bringing relay back up (with redis dependency)…"
docker compose up -d redis relay

echo ""
echo "==> Waiting for /health to respond (up to 90s)…"
for i in $(seq 1 30); do
  sleep 3
  code=$(curl -s -o /tmp/relay_health.json -w "%{http_code}" "http://localhost:${RELAY_PORT}/health" || echo "000")
  if [[ "$code" == "200" ]]; then
    echo ""
    echo "✓ Relay is LIVE on localhost:${RELAY_PORT}"
    cat /tmp/relay_health.json
    echo ""
    break
  fi
  echo "  attempt $i: HTTP $code — still booting…"
done

if [[ "${code:-000}" != "200" ]]; then
  echo ""
  echo "✗ Relay did not come up healthy. Showing last 50 lines of logs:"
  docker compose logs --tail 50 relay
  exit 1
fi

echo ""
echo "==> External reachability test (from outside the VM):"
echo "    curl -s http://${RELAY_HOST}:${RELAY_PORT}/health"
echo ""
echo "==> Container status:"
docker compose ps relay redis

echo ""
echo "==> Done. To tail live logs:"
echo "    docker compose logs -f relay"
