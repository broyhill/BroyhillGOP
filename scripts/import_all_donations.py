#!/usr/bin/env python3
"""
MASTER DONATION IMPORT - REPUBLICANS ONLY
Excludes: Governor_*.csv, progress_*.csv (contain Democrat data)
"""
import csv, psycopg2, logging, os
from pathlib import Path
from datetime import datetime

os.makedirs('/opt/broyhillgop/logs', exist_ok=True)
logging.basicConfig(filename='/opt/broyhillgop/logs/donation_import.log', level=logging.INFO, format='%(asctime)s - %(message)s')
console = logging.StreamHandler()
logging.getLogger('').addHandler(console)

DB_URL = 'postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-1-us-east-1.pooler.supabase.com:6543/postgres'

SKIP_FILES = ['Governor_2016_2018.csv', 'Governor_2019_2021.csv', 'progress_25.csv', 'progress_50.csv', 'progress_75.csv', 'committees.csv']

def import_fec():
    logging.info('=== FEC IMPORT (Republicans Only) ===')
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute('SELECT COUNT(*) FROM staging_fec_contributions')
    start = cur.fetchone()[0]
    logging.info(f'FEC starting: {start:,}')
    if start > 200000:
        logging.info('FEC already complete')
        conn.close()
        return
    
    total = 0
    for race in ['PRESIDENT', 'NC_SENATE', 'NC_HOUSE']:
        race_dir = Path(f'/root/fec_downloads/{race}')
        if not race_dir.exists():
            continue
        for f in sorted(race_dir.glob('*.csv')):
            cand = f.stem.split('_')[0]
            batch = []
            for row in csv.DictReader(open(f, errors='ignore')):
                try:
                    amt = float(row.get('contribution_receipt_amount', 0) or 0)
                    batch.append((
                        row.get('committee_id'),
                        f'{cand} ({race})',
                        row.get('contributor_name'),
                        row.get('contributor_city'),
                        row.get('contributor_state'),
                        row.get('contributor_zip'),
                        row.get('contributor_employer'),
                        row.get('contributor_occupation'),
                        amt,
                        row.get('contribution_receipt_date') or None,
                        row.get('sub_id'),
                        f.name,
                        False
                    ))
                    if len(batch) >= 2000:
                        cur.executemany(
                            'INSERT INTO staging_fec_contributions (committee_id,committee_name,contributor_name,contributor_city,contributor_state,contributor_zip,contributor_employer,contributor_occupation,contribution_amount,contribution_date,transaction_id,file_source,processed) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                            batch
                        )
                        conn.commit()
                        total += len(batch)
                        batch = []
                except:
                    pass
            if batch:
                cur.executemany(
                    'INSERT INTO staging_fec_contributions (committee_id,committee_name,contributor_name,contributor_city,contributor_state,contributor_zip,contributor_employer,contributor_occupation,contribution_amount,contribution_date,transaction_id,file_source,processed) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                    batch
                )
                conn.commit()
                total += len(batch)
            logging.info(f'FEC {f.name}: {total:,}')
    logging.info(f'=== FEC COMPLETE: {total:,} ===')
    conn.close()

def import_ncsbe():
    logging.info('=== NCSBE IMPORT (Republicans Only) ===')
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute('SELECT COUNT(*) FROM staging_ncsbe_contributions')
    start = cur.fetchone()[0]
    logging.info(f'NCSBE starting: {start:,}')
    if start > 400000:
        logging.info('NCSBE already complete')
        conn.close()
        return
    
    total = 0
    NCSBE_DIR = Path('/root/nc_republican_donors/NCSBE')
    for f in sorted(NCSBE_DIR.glob('*.csv')):
        if f.name in SKIP_FILES:
            logging.info(f'SKIPPING {f.name} (Democrat data or metadata)')
            continue
        batch = []
        try:
            for row in csv.DictReader(open(f, errors='ignore')):
                try:
                    amt_str = str(row.get('Amount', '0')).replace(',', '')
                    amt = float(amt_str) if amt_str else 0
                    dt = row.get('Date Occured') or row.get('Date Occurred')
                    batch.append((
                        row.get('Committee SBoE ID'),
                        row.get('Committee Name'),
                        row.get('Name'),
                        row.get('Street Line 1'),
                        row.get('City'),
                        row.get('State'),
                        row.get('Zip Code'),
                        row.get("Employer's Name/Specific Field"),
                        row.get('Profession/Job Title'),
                        amt,
                        dt,
                        None,
                        f.name,
                        False
                    ))
                    if len(batch) >= 2000:
                        cur.executemany(
                            'INSERT INTO staging_ncsbe_contributions (committee_sboe_id,committee_name,contributor_name,contributor_street,contributor_city,contributor_state,contributor_zip,contributor_employer,contributor_occupation,contribution_amount,contribution_date,transaction_id,file_source,processed) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                            batch
                        )
                        conn.commit()
                        total += len(batch)
                        batch = []
                except:
                    pass
            if batch:
                cur.executemany(
                    'INSERT INTO staging_ncsbe_contributions (committee_sboe_id,committee_name,contributor_name,contributor_street,contributor_city,contributor_state,contributor_zip,contributor_employer,contributor_occupation,contribution_amount,contribution_date,transaction_id,file_source,processed) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                    batch
                )
                conn.commit()
                total += len(batch)
            logging.info(f'NCSBE {f.name}: {total:,}')
        except Exception as e:
            logging.error(f'Error {f.name}: {e}')
    logging.info(f'=== NCSBE COMPLETE: {total:,} ===')
    conn.close()

if __name__ == '__main__':
    logging.info('======== REPUBLICANS ONLY IMPORT ========')
    import_fec()
    import_ncsbe()
    logging.info('======== ALL COMPLETE ========')
