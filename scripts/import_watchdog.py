#!/usr/bin/env python3
"""
IMPORT WATCHDOG - Detects stalls and restarts import
Runs every 60 seconds, checks if import is running and progressing
"""
import subprocess
import time
import psycopg2
import logging
import os

logging.basicConfig(
    filename='/opt/broyhillgop/logs/watchdog.log',
    level=logging.INFO,
    format='%(asctime)s - %(message)s'
)

DB_URL = 'postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-1-us-east-1.pooler.supabase.com:6543/postgres'
IMPORT_SCRIPT = '/opt/broyhillgop/scripts/import_all_donations.py'
CHECK_INTERVAL = 60  # seconds
STALL_THRESHOLD = 120  # seconds without progress = stall

last_count = 0
last_change_time = time.time()

def get_total_count():
    try:
        conn = psycopg2.connect(DB_URL)
        cur = conn.cursor()
        cur.execute('SELECT COUNT(*) FROM staging_fec_contributions')
        fec = cur.fetchone()[0]
        cur.execute('SELECT COUNT(*) FROM staging_ncsbe_contributions')
        ncsbe = cur.fetchone()[0]
        conn.close()
        return fec + ncsbe
    except Exception as e:
        logging.error(f'DB error: {e}')
        return -1

def is_import_running():
    result = subprocess.run(['pgrep', '-f', 'import_all_donations'], capture_output=True)
    return result.returncode == 0

def start_import():
    logging.info('Starting import process...')
    subprocess.Popen(
        ['nohup', 'python3', IMPORT_SCRIPT],
        stdout=open('/opt/broyhillgop/logs/donation_import.log', 'a'),
        stderr=subprocess.STDOUT,
        cwd='/opt/broyhillgop',
        start_new_session=True
    )
    logging.info('Import started')

def is_complete():
    try:
        conn = psycopg2.connect(DB_URL)
        cur = conn.cursor()
        cur.execute('SELECT COUNT(*) FROM staging_fec_contributions')
        fec = cur.fetchone()[0]
        cur.execute('SELECT COUNT(*) FROM staging_ncsbe_contributions')
        ncsbe = cur.fetchone()[0]
        conn.close()
        # FEC ~264K, NCSBE ~534K
        return fec > 240000 and ncsbe > 500000
    except:
        return False

logging.info('========== WATCHDOG STARTED ==========')

while True:
    if is_complete():
        logging.info('IMPORT COMPLETE! FEC + NCSBE targets reached.')
        logging.info('========== WATCHDOG EXITING ==========')
        break
    
    current_count = get_total_count()
    running = is_import_running()
    
    if current_count > last_count:
        last_count = current_count
        last_change_time = time.time()
        logging.info(f'Progress: {current_count:,} records, running={running}')
    
    stall_time = time.time() - last_change_time
    
    if not running:
        logging.warning(f'Import not running! Count={current_count:,}. Restarting...')
        start_import()
        last_change_time = time.time()
    elif stall_time > STALL_THRESHOLD:
        logging.warning(f'STALL DETECTED! No progress for {stall_time:.0f}s. Killing and restarting...')
        subprocess.run(['pkill', '-f', 'import_all_donations'])
        time.sleep(2)
        start_import()
        last_change_time = time.time()
    
    time.sleep(CHECK_INTERVAL)
