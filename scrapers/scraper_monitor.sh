#!/bin/bash
# ============================================================================
# SCRAPER MONITOR - Auto-restart for FEC/NCBOE Scrapers
# BroyhillGOP Platform
# Created: January 11, 2026
# ============================================================================
#
# This script monitors FEC and NCBOE scrapers and auto-restarts them if they
# stop running. Checks every 60 seconds as required.
#
# Usage: nohup /root/scraper_monitor.sh &
# ============================================================================

LOG_FILE="/root/scraper_monitor.log"
FEC_PID_FILE="/root/fec_scraper.pid"
NCBOE_PID_FILE="/root/ncboe_scraper.pid"

# Ensure log file exists
touch $LOG_FILE

echo "$(date): ========================================" >> $LOG_FILE
echo "$(date): SCRAPER MONITOR STARTED" >> $LOG_FILE
echo "$(date): ========================================" >> $LOG_FILE

# Function to check if process is really running
is_running() {
    local pid=$1
    if [ -z "$pid" ]; then
        return 1
    fi
    if ps -p $pid > /dev/null 2>&1; then
        # Also check if it's actually Python scraper
        if ps -p $pid -o comm= | grep -q "python"; then
            return 0
        fi
    fi
    return 1
}

# Function to start FEC scraper
start_fec_scraper() {
    echo "$(date): Starting FEC scraper..." >> $LOG_FILE
    cd /root
    python3 /root/fec_scraper.py >> /root/fec_scraper.log 2>&1 &
    echo $! > $FEC_PID_FILE
    echo "$(date): FEC scraper started with PID $(cat $FEC_PID_FILE)" >> $LOG_FILE
}

# Function to start NCBOE scraper
start_ncboe_scraper() {
    echo "$(date): Starting NCBOE scraper..." >> $LOG_FILE
    cd /root
    python3 /root/ncboe_scraper.py >> /root/ncboe_scraper.log 2>&1 &
    echo $! > $NCBOE_PID_FILE
    echo "$(date): NCBOE scraper started with PID $(cat $NCBOE_PID_FILE)" >> $LOG_FILE
}

# Main monitoring loop
while true; do
    # Check FEC scraper
    if [ -f "$FEC_PID_FILE" ]; then
        FEC_PID=$(cat $FEC_PID_FILE 2>/dev/null)
        if ! is_running "$FEC_PID"; then
            echo "$(date): FEC scraper died (was PID $FEC_PID). Restarting..." >> $LOG_FILE
            start_fec_scraper
        fi
    else
        echo "$(date): FEC scraper not initialized. Starting..." >> $LOG_FILE
        start_fec_scraper
    fi
    
    # Check NCBOE scraper
    if [ -f "$NCBOE_PID_FILE" ]; then
        NCBOE_PID=$(cat $NCBOE_PID_FILE 2>/dev/null)
        if ! is_running "$NCBOE_PID"; then
            echo "$(date): NCBOE scraper died (was PID $NCBOE_PID). Restarting..." >> $LOG_FILE
            start_ncboe_scraper
        fi
    else
        echo "$(date): NCBOE scraper not initialized. Starting..." >> $LOG_FILE
        start_ncboe_scraper
    fi
    
    # Log status every hour (60 iterations)
    ITERATION=$((${ITERATION:-0} + 1))
    if [ $((ITERATION % 60)) -eq 0 ]; then
        FEC_PROGRESS=$(cat /root/fec_progress.json 2>/dev/null | grep records_scraped || echo "N/A")
        NCBOE_PROGRESS=$(cat /root/ncboe_progress.json 2>/dev/null | grep records_scraped || echo "N/A")
        echo "$(date): Hourly status - FEC: $FEC_PROGRESS, NCBOE: $NCBOE_PROGRESS" >> $LOG_FILE
    fi
    
    # Wait 60 seconds before next check
    sleep 60
done
