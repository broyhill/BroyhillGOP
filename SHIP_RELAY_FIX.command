#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  SHIP_RELAY_FIX.command
#  Double-click this from Finder to deploy the relay fix.
#  Does three things:
#    1. Commits & pushes the 4 changed files in BroyhillGOP repo to GitHub
#    2. SSHes to Hetzner (37.27.169.232) and runs deploy_relay.sh
#    3. Verifies http://37.27.169.232:8080/health returns 200
# ═══════════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")"
clear

echo "════════════════════════════════════════════════════════════════"
echo "   BROYHILLGOP RELAY FIX — automated ship"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Repo:      $(pwd)"
echo "Hetzner:   37.27.169.232"
echo ""

# ── Sanity check ───────────────────────────────────────────────────────────
if [[ ! -f relay.py || ! -f docker-compose.yml ]]; then
  echo "✗ This script must live at the BroyhillGOP repo root."
  echo "  Move SHIP_RELAY_FIX.command into ~/Documents/GitHub/BroyhillGOP/"
  read -p "Press return to close…"
  exit 1
fi

# ── 1. Commit + push ───────────────────────────────────────────────────────
echo "──── Step 1/3: commit + push to GitHub ────"
git add docker-compose.yml relay.py deploy_relay.sh docs/RELAY_MESSAGING_CONTRACT.md SHIP_RELAY_FIX.command
git status --short
echo ""

if git diff --cached --quiet; then
  echo "  (no changes to commit — already pushed)"
else
  git commit -m "Fix relay container entrypoint + add cursor to agent roster + 3-way contract

- docker-compose.yml: 'python app/relay.py' → 'python relay.py' (file is at repo root)
- docker-compose.yml: install curl in container so healthcheck works
- docker-compose.yml: bump start_period 20s → 60s for pip install
- relay.py: _validate_agent now accepts 'cursor' and 'all'
- docs/RELAY_MESSAGING_CONTRACT.md: canonical 3-way protocol reference
- deploy_relay.sh: one-shot ship script for Hetzner

Resolves: relay container had been crash-looping silently since last redeploy,
port 8080 had no listener, all messaging was dead despite SESSION-STATE
saying RUNNING."
  git push origin main
fi

echo ""
echo "✓ Pushed to GitHub."
echo ""

# ── 2. SSH to Hetzner and deploy ───────────────────────────────────────────
echo "──── Step 2/3: deploy on Hetzner ────"
echo "  (you may be prompted for SSH password if your key isn't loaded)"
echo ""

# Try common locations the repo might live on Hetzner
HETZNER_REPO_PATH="${HETZNER_REPO_PATH:-/root/BroyhillGOP}"

ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
    root@37.27.169.232 \
    "cd $HETZNER_REPO_PATH && bash deploy_relay.sh" \
  || {
    echo ""
    echo "✗ SSH failed. Two likely fixes:"
    echo "   a) The repo lives somewhere other than $HETZNER_REPO_PATH on Hetzner."
    echo "      Re-run with:  HETZNER_REPO_PATH=/your/path bash SHIP_RELAY_FIX.command"
    echo "   b) Your SSH key isn't authorized — log in once manually:"
    echo "      ssh root@37.27.169.232"
    read -p "Press return to close…"
    exit 1
  }

echo ""
echo "✓ Hetzner deploy returned successfully."
echo ""

# ── 3. External health check from your Mac ─────────────────────────────────
echo "──── Step 3/3: confirm /health from your Mac ────"
sleep 3
HTTP=$(curl -s -o /tmp/relay_health.json -m 8 -w "%{http_code}" http://37.27.169.232:8080/health || echo "000")
if [[ "$HTTP" == "200" ]]; then
  echo "✓ Relay LIVE → http://37.27.169.232:8080/health  (HTTP $HTTP)"
  echo ""
  cat /tmp/relay_health.json
  echo ""
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "   ALL GOOD. Perplexity ↔ Claude ↔ Cursor messaging is live."
  echo "   Contract: docs/RELAY_MESSAGING_CONTRACT.md"
  echo "════════════════════════════════════════════════════════════════"
else
  echo "⚠ Hetzner deploy succeeded but /health from your Mac returned HTTP $HTTP."
  echo "  Could be Hetzner firewall, port-forward, or in-progress restart."
  echo "  Try again in 30s or SSH to the box and:  docker compose logs -f relay"
fi

echo ""
read -p "Press return to close…"
