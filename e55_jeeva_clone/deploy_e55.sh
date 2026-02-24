#!/bin/bash
# E55 Jeeva Clone - Full Deployment Script
# Deploys to Hetzner server at 5.9.99.109
# Usage: ./deploy_e55.sh

set -e

HETZNER_HOST="5.9.99.109"
HETZNER_USER="root"
DEPLOY_DIR="/opt/broyhillgop/e55_jeeva_clone"
WEB_DIR="/var/www/html/e55"

echo "========================================"
echo "  E55 JEEVA CLONE - FULL DEPLOYMENT"
echo "  Target: ${HETZNER_HOST}"
echo "========================================"

# Step 1: Create directory structure on Hetzner
echo ""
echo "[1/6] Creating directory structure..."
ssh ${HETZNER_USER}@${HETZNER_HOST} "mkdir -p ${DEPLOY_DIR}/{agent,edge_functions,webhooks,web,sql,logs} ${WEB_DIR}"

# Step 2: Copy files
echo "[2/6] Copying E55 files to Hetzner..."
scp -r agent/ ${HETZNER_USER}@${HETZNER_HOST}:${DEPLOY_DIR}/
scp -r edge_functions/ ${HETZNER_USER}@${HETZNER_HOST}:${DEPLOY_DIR}/
scp -r webhooks/ ${HETZNER_USER}@${HETZNER_HOST}:${DEPLOY_DIR}/
scp -r web/ ${HETZNER_USER}@${HETZNER_HOST}:${DEPLOY_DIR}/
scp -r sql/ ${HETZNER_USER}@${HETZNER_HOST}:${DEPLOY_DIR}/

# Step 3: Copy web files to nginx directory
echo "[3/6] Publishing web interfaces..."
ssh ${HETZNER_USER}@${HETZNER_HOST} "cp ${DEPLOY_DIR}/web/*.html ${WEB_DIR}/ 2>/dev/null; cp ${DEPLOY_DIR}/web/*.docx ${WEB_DIR}/ 2>/dev/null"

# Step 4: Install Python dependencies
echo "[4/6] Installing Python dependencies..."
ssh ${HETZNER_USER}@${HETZNER_HOST} "pip3 install httpx psycopg2-binary python-dateutil 2>/dev/null || pip install httpx psycopg2-binary python-dateutil 2>/dev/null"

# Step 5: Install and start systemd service
echo "[5/6] Installing E55 agent service..."
ssh ${HETZNER_USER}@${HETZNER_HOST} "cp ${DEPLOY_DIR}/agent/e55_agent.service /etc/systemd/system/ && systemctl daemon-reload && systemctl enable e55-agent && systemctl restart e55-agent"

# Step 6: Configure nginx for E55 web
echo "[6/6] Configuring nginx..."
ssh ${HETZNER_USER}@${HETZNER_HOST} "cat > /etc/nginx/conf.d/e55.conf << 'NGINX'
server {
    listen 8055;
    server_name _;
    root ${WEB_DIR};
    index E55_Command_Center.html;

    location / {
        try_files \$uri \$uri/ =404;
        add_header Access-Control-Allow-Origin *;
    }

    location ~ \.docx$ {
        add_header Content-Disposition 'attachment';
    }
}
NGINX
nginx -t && systemctl reload nginx 2>/dev/null || echo 'nginx reload skipped'"

echo ""
echo "========================================"
echo "  E55 DEPLOYMENT COMPLETE"
echo "========================================"
echo ""
echo "  Command Center:  http://${HETZNER_HOST}:8055/"
echo "  Funnel Builder:  http://${HETZNER_HOST}:8055/NEXUS_AI_Advisor_Funnel_Builder.html"
echo "  Agent Status:    systemctl status e55-agent"
echo "  Agent Logs:      journalctl -u e55-agent -f"
echo ""
