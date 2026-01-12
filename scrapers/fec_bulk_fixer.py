#!/usr/bin/env python3
"""
FEC BULK DOWNLOAD FIXER
Retry logic + size validation + zip verification
Run AFTER NCSBE completes
"""

import os
import requests
import zipfile
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime
from collections import defaultdict
import time

DB_URL = 'postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-1-us-east-1.pooler.supabase.com:6543/postgres'
DATA_DIR = '/root/bulk_data'
LOG_FILE = '/root/fec_bulk.log'
BATCH_SIZE = 1000

# Expected minimum sizes (MB) - files smaller are likely corrupted
MIN_SIZES = {
    2016: 500,
    2018: 600, 
    2020: 700,
    2022: 800,
    2024: 900
}

FEC_URLS = {
    2016: 'https://www.fec.gov/files/bulk-downloads/2016/indiv16.zip',
    2018: 'https://www.fec.gov/files/bulk-downloads/2018/indiv18.zip',
    2020: 'https://www.fec.gov/files/bulk-downloads/2020/indiv20.zip',
    2022: 'https://www.fec.gov/files/bulk-downloads/2022/indiv22.zip',
    2024: 'https://www.fec.gov/files/bulk-downloads/2024/indiv24.zip',
}

CM_URLS = {
    2016: 'https://www.fec.gov/files/bulk-downloads/2016/cm16.zip',
    2018: 'https://www.fec.gov/files/bulk-downloads/2018/cm18.zip',
    2020: 'https://www.fec.gov/files/bulk-downloads/2020/cm20.zip',
    2022: 'https://www.fec.gov/files/bulk-downloads/2022/cm22.zip',
    2024: 'https://www.fec.gov/files/bulk-downloads/2024/cm24.zip',
}

def log(msg):
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] {msg}'
    print(line, flush=True)
    with open(LOG_FILE, 'a') as f:
        f.write(line + '\n')

def validate_zip(path):
    """Check if file is valid zip"""
    try:
        with zipfile.ZipFile(path, 'r') as z:
            return len(z.namelist()) > 0
    except:
        return False

def download_with_retry(url, path, min_size_mb, max_retries=3):
    """Download with retry, size check, and zip validation"""
    
    for attempt in range(max_retries):
        # Delete corrupted file if exists
        if os.path.exists(path):
            if validate_zip(path):
                size_mb = os.path.getsize(path) / (1024*1024)
                if size_mb >= min_size_mb:
                    log(f"  Valid file exists: {size_mb:.0f}MB")
                    return True
            log(f"  Removing corrupted file (attempt {attempt+1})")
            os.remove(path)
        
        log(f"  Downloading (attempt {attempt+1}/{max_retries})...")
        try:
            r = requests.get(url, stream=True, timeout=1800)  # 30 min timeout
            r.raise_for_status()
            
            total = int(r.headers.get('content-length', 0))
            downloaded = 0
            
            # Write to temp file first
            temp_path = path + '.tmp'
            with open(temp_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=1024*1024):
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total > 0 and downloaded % (200*1024*1024) == 0:
                        log(f"    {downloaded//(1024*1024)}MB / {total//(1024*1024)}MB")
            
            # Validate before renaming
            if not validate_zip(temp_path):
                log(f"  Downloaded file is not valid zip!")
                os.remove(temp_path)
                continue
            
            size_mb = os.path.getsize(temp_path) / (1024*1024)
            if size_mb < min_size_mb:
                log(f"  File too small: {size_mb:.0f}MB < {min_size_mb}MB expected")
                os.remove(temp_path)
                continue
            
            # Success - rename
            os.rename(temp_path, path)
            log(f"  Downloaded and validated: {size_mb:.0f}MB")
            return True
            
        except Exception as e:
            log(f"  Download error: {e}")
            time.sleep(10)  # Wait before retry
    
    return False

def get_republican_committees(cycle):
    """Get Republican committee IDs"""
    cache = os.path.join(DATA_DIR, f'rep_cm_{cycle}.txt')
    
    if os.path.exists(cache):
        with open(cache) as f:
            return set(line.strip() for line in f if line.strip())
    
    log(f"Fetching Republican committees for {cycle}...")
    rep = set()
    
    try:
        r = requests.get(CM_URLS[cycle], timeout=120)
        with zipfile.ZipFile(__import__('io').BytesIO(r.content)) as z:
            for name in z.namelist():
                if name.endswith('.txt'):
                    with z.open(name) as f:
                        for line in f:
                            parts = line.decode('utf-8', errors='ignore').split('|')
                            if len(parts) > 10 and parts[10].strip().upper() in ('REP', 'R'):
                                rep.add(parts[0].strip())
        
        with open(cache, 'w') as f:
            f.write('\n'.join(rep))
        log(f"  Found {len(rep):,} Republican committees")
        return rep
    except Exception as e:
        log(f"  Error: {e}")
        return set()

def load_donor_indexes(conn):
    """Load existing donors for matching"""
    log("Loading donor indexes...")
    cur = conn.cursor()
    cur.execute("""
        SELECT id, first_name, last_name, city, zip_code
        FROM donors WHERE first_name IS NOT NULL AND last_name IS NOT NULL
    """)
    
    by_name_zip = defaultdict(list)
    by_name_city = defaultdict(list)
    
    for row in cur.fetchall():
        did, fn, ln, city, zip5 = row
        fn = (fn or '').upper().strip()[:10]
        ln = (ln or '').upper().strip()
        city = (city or '').upper().strip()
        zip5 = (zip5 or '')[:5]
        
        if fn and ln and zip5:
            by_name_zip[f"{ln}|{fn}|{zip5}"].append(did)
        if fn and ln and city:
            by_name_city[f"{ln}|{fn}|{city}"].append(did)
    
    log(f"  Loaded {len(by_name_zip):,} name+zip, {len(by_name_city):,} name+city")
    return by_name_zip, by_name_city

def match_donor(fn, ln, city, zip5, by_name_zip, by_name_city):
    fn = (fn or '').upper().strip()[:10]
    ln = (ln or '').upper().strip()
    city = (city or '').upper().strip()
    zip5 = (zip5 or '')[:5]
    
    if fn and ln and zip5:
        key = f"{ln}|{fn}|{zip5}"
        if key in by_name_zip:
            return by_name_zip[key][0]
    
    if fn and ln and city:
        key = f"{ln}|{fn}|{city}"
        if key in by_name_city:
            return by_name_city[key][0]
    
    return None

def process_cycle(cycle, conn, by_name_zip, by_name_city, rep_committees):
    """Process one FEC cycle"""
    zip_path = os.path.join(DATA_DIR, f'indiv{str(cycle)[2:]}.zip')
    
    if not os.path.exists(zip_path):
        log(f"  File not found: {zip_path}")
        return 0, 0
    
    log(f"Processing {cycle}...")
    cur = conn.cursor()
    batch = []
    matched = 0
    skipped = 0
    total = 0
    
    with zipfile.ZipFile(zip_path) as z:
        for name in z.namelist():
            if 'itcont' in name.lower() or name.endswith('.txt'):
                log(f"  Reading {name}...")
                with z.open(name) as f:
                    for line_bytes in f:
                        total += 1
                        if total % 500000 == 0:
                            log(f"    {total:,} rows, {matched:,} matched")
                            if batch:
                                _insert(cur, conn, batch)
                                batch = []
                        
                        try:
                            parts = line_bytes.decode('utf-8', errors='ignore').split('|')
                            if len(parts) < 15:
                                continue
                            
                            cm_id = parts[0].strip()
                            if cm_id not in rep_committees:
                                skipped += 1
                                continue
                            
                            name_str = parts[7].strip()
                            city = parts[8].strip()
                            state = parts[9].strip()
                            zip5 = parts[10].strip()[:5]
                            employer = parts[11].strip()[:200]
                            occupation = parts[12].strip()[:100]
                            date_str = parts[13].strip()
                            amt_str = parts[14].strip()
                            
                            # Parse name
                            if ',' in name_str:
                                ln, fn = name_str.split(',', 1)
                                fn = fn.split()[0] if fn.split() else ''
                            else:
                                parts2 = name_str.split()
                                ln = parts2[-1] if parts2 else ''
                                fn = parts2[0] if len(parts2) > 1 else ''
                            
                            if not fn or not ln:
                                continue
                            
                            donor_id = match_donor(fn, ln, city, zip5, by_name_zip, by_name_city)
                            if not donor_id:
                                skipped += 1
                                continue
                            
                            matched += 1
                            
                            # Parse date
                            don_date = None
                            if len(date_str) == 8:
                                don_date = f"{date_str[4:8]}-{date_str[0:2]}-{date_str[2:4]}"
                            
                            try:
                                amt = float(amt_str.replace(',', ''))
                            except:
                                amt = 0
                            
                            trans_id = f"FEC{cycle}_{cm_id}_{total}"
                            
                            batch.append((
                                donor_id, amt, don_date, None, 'REP', cm_id,
                                trans_id, 'FEC', 'FEDERAL', cycle, employer, occupation
                            ))
                            
                            if len(batch) >= BATCH_SIZE:
                                _insert(cur, conn, batch)
                                batch = []
                        except:
                            continue
                break  # Only first file
    
    if batch:
        _insert(cur, conn, batch)
    
    log(f"  {cycle}: {matched:,} matched, {skipped:,} skipped")
    return matched, skipped

def _insert(cur, conn, batch):
    try:
        execute_values(cur, """
            INSERT INTO donation_history 
            (donor_id, amount, donation_date, candidate_name, candidate_party,
             committee_id, transaction_id, source, race_type, election_cycle, employer, occupation)
            VALUES %s ON CONFLICT (transaction_id) DO NOTHING
        """, batch)
        conn.commit()
    except Exception as e:
        conn.rollback()

def main():
    log("=" * 60)
    log("FEC BULK FIXER - Retry + Validate + Process")
    log("=" * 60)
    
    os.makedirs(DATA_DIR, exist_ok=True)
    
    conn = psycopg2.connect(DB_URL)
    by_name_zip, by_name_city = load_donor_indexes(conn)
    
    total_matched = 0
    
    for cycle in [2024, 2022, 2020, 2018, 2016]:
        log(f"\n=== CYCLE {cycle} ===")
        
        # Download with retry
        url = FEC_URLS[cycle]
        path = os.path.join(DATA_DIR, f'indiv{str(cycle)[2:]}.zip')
        
        if not download_with_retry(url, path, MIN_SIZES[cycle]):
            log(f"  FAILED to download {cycle} after retries")
            continue
        
        # Get Republican committees
        rep = get_republican_committees(cycle)
        if not rep:
            continue
        
        # Process
        matched, skipped = process_cycle(cycle, conn, by_name_zip, by_name_city, rep)
        total_matched += matched
    
    # Final stats
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*), COUNT(DISTINCT donor_id) FROM donation_history")
    total, unique = cur.fetchone()
    
    log("\n" + "=" * 60)
    log("COMPLETE")
    log(f"  Total donations: {total:,}")
    log(f"  Unique donors with history: {unique:,}")
    log(f"  FEC matched this run: {total_matched:,}")
    log("=" * 60)
    
    conn.close()

if __name__ == '__main__':
    main()
