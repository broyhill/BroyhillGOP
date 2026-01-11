#!/bin/bash
# ============================================================================
# DEPLOY FEC/NCBOE SCRAPERS TO HETZNER
# BroyhillGOP Platform
# Created: January 11, 2026
# ============================================================================
#
# This script deploys and starts the FEC/NCBOE Republican donor scrapers
# on the Hetzner server (5.9.99.109)
#
# Run this on Hetzner after SSH login
# ============================================================================

echo "=========================================="
echo "BroyhillGOP FEC/NCBOE Scraper Deployment"
echo "=========================================="

# Configuration
SCRAPER_DIR="/root"
DATA_DIR="/root/fec_data"
NCBOE_DATA_DIR="/root/ncboe_data"

# Supabase credentials (from memory)
export SUPABASE_URL="postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-0-us-east-1.pooler.supabase.com:6543/postgres"

# FEC API Key (get from fec.gov if needed)
export FEC_API_KEY="${FEC_API_KEY:-DEMO_KEY}"

echo "[1/6] Installing dependencies..."
apt-get update -qq
apt-get install -y python3 python3-pip python3-venv -qq

pip3 install --quiet \
    requests \
    psycopg2-binary \
    pandas \
    beautifulsoup4 \
    lxml

echo "[2/6] Creating data directories..."
mkdir -p $DATA_DIR
mkdir -p $NCBOE_DATA_DIR

echo "[3/6] Verifying scraper files..."
if [ ! -f "$SCRAPER_DIR/fec_scraper.py" ]; then
    echo "ERROR: fec_scraper.py not found in $SCRAPER_DIR"
    echo "Please copy the scraper files first"
    exit 1
fi

if [ ! -f "$SCRAPER_DIR/ncboe_scraper.py" ]; then
    echo "ERROR: ncboe_scraper.py not found in $SCRAPER_DIR"
    echo "Please copy the scraper files first"
    exit 1
fi

if [ ! -f "$SCRAPER_DIR/scraper_monitor.sh" ]; then
    echo "ERROR: scraper_monitor.sh not found in $SCRAPER_DIR"
    echo "Please copy the monitor script first"
    exit 1
fi

echo "[4/6] Setting permissions..."
chmod +x $SCRAPER_DIR/scraper_monitor.sh
chmod +x $SCRAPER_DIR/fec_scraper.py
chmod +x $SCRAPER_DIR/ncboe_scraper.py

echo "[5/6] Testing database connection..."
python3 << 'EOF'
import psycopg2
import os

try:
    conn = psycopg2.connect(os.environ['SUPABASE_URL'])
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM donors")
    count = cur.fetchone()[0]
    print(f"✅ Database connected! Found {count} existing donors")
    conn.close()
except Exception as e:
    print(f"❌ Database connection failed: {e}")
    exit(1)
EOF

if [ $? -ne 0 ]; then
    echo "Database connection failed. Check SUPABASE_URL"
    exit 1
fi

echo "[6/6] Starting scrapers with monitor..."

# Kill any existing scrapers/monitors
pkill -f "scraper_monitor.sh" 2>/dev/null
pkill -f "fec_scraper.py" 2>/dev/null
pkill -f "ncboe_scraper.py" 2>/dev/null
sleep 2

# Remove old PID files
rm -f /root/fec_scraper.pid /root/ncboe_scraper.pid

# Start monitor (which will start scrapers)
nohup $SCRAPER_DIR/scraper_monitor.sh > /root/monitor.log 2>&1 &
MONITOR_PID=$!

echo "Monitor started with PID: $MONITOR_PID"

# Wait for scrapers to start
sleep 5

echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "Status:"
ps aux | grep -E "(fec_scraper|ncboe_scraper|scraper_monitor)" | grep -v grep
echo ""
echo "Logs:"
echo "  - Monitor: tail -f /root/scraper_monitor.log"
echo "  - FEC:     tail -f /root/fec_scraper.log"
echo "  - NCBOE:   tail -f /root/ncboe_scraper.log"
echo ""
echo "Progress:"
echo "  - FEC:     cat /root/fec_progress.json"
echo "  - NCBOE:   cat /root/ncboe_progress.json"
echo ""
echo "Data:"
echo "  - FEC:     ls -la $DATA_DIR/"
echo "  - NCBOE:   ls -la $NCBOE_DATA_DIR/"
echo ""
