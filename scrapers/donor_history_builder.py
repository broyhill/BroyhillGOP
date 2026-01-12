#!/usr/bin/env python3
"""
REPUBLICAN DONOR HISTORY BUILDER v2
BroyhillGOP Platform - January 2026

LOGIC:
1. Download FEC bulk CSVs (not API) - millions of records instantly
2. For each donation:
   - Try match existing donor (name+zip first, fallback name+city)
   - If match → insert donation with donor_id link
   - If no match → create new donor, then link donation
3. Batch insert 1000+ donations at once
4. Parallel processing - 20 workers, one per year
5. Preserve existing 137K donors - never modify them
6. Republican filter at committee level
"""

import csv
import psycopg2
from psycopg2.extras import execute_values, RealDictCursor
from psycopg2.pool import ThreadedConnectionPool
import os
import requests
import zipfile
import io
from datetime import datetime
from collections import defaultdict
import json
import concurrent.futures
import threading

# Database
DB_URL = 'postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-1-us-east-1.pooler.supabase.com:6543/postgres'

# FEC Bulk Downloads (each cycle covers 2 years)
FEC_INDIV_URLS = {
    2016: 'https://www.fec.gov/files/bulk-downloads/2016/indiv16.zip',  # 2015-2016
    2018: 'https://www.fec.gov/files/bulk-downloads/2018/indiv18.zip',  # 2017-2018
    2020: 'https://www.fec.gov/files/bulk-downloads/2020/indiv20.zip',  # 2019-2020
    2022: 'https://www.fec.gov/files/bulk-downloads/2022/indiv22.zip',  # 2021-2022
    2024: 'https://www.fec.gov/files/bulk-downloads/2024/indiv24.zip',  # 2023-2024
}

FEC_COMMITTEE_URLS = {
    2016: 'https://www.fec.gov/files/bulk-downloads/2016/cm16.zip',
    2018: 'https://www.fec.gov/files/bulk-downloads/2018/cm18.zip',
    2020: 'https://www.fec.gov/files/bulk-downloads/2020/cm20.zip',
    2022: 'https://www.fec.gov/files/bulk-downloads/2022/cm22.zip',
    2024: 'https://www.fec.gov/files/bulk-downloads/2024/cm24.zip',
}

DATA_DIR = '/root/bulk_data'
LOG_FILE = '/root/donor_history.log'
PROGRESS_FILE = '/root/donor_history_progress.json'
BATCH_SIZE = 1000

# Thread-safe logging
log_lock = threading.Lock()

def log(msg):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{timestamp}] {msg}'
    with log_lock:
        print(line, flush=True)
        with open(LOG_FILE, 'a') as f:
            f.write(line + '\n')

def save_progress(data):
    with open(PROGRESS_FILE, 'w') as f:
        json.dump(data, f, indent=2, default=str)

# ============================================================
# DATABASE SETUP
# ============================================================

def create_donations_table(conn):
    """Create donations table with proper foreign key"""
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS donations (
            id SERIAL PRIMARY KEY,
            donor_id INTEGER REFERENCES donors(id),
            amount DECIMAL(12,2),
            donation_date DATE,
            candidate_name VARCHAR(200),
            candidate_party VARCHAR(10) DEFAULT 'REP',
            committee_id VARCHAR(20),
            transaction_id VARCHAR(100) UNIQUE,
            source VARCHAR(20),
            race_type VARCHAR(20),
            election_cycle INTEGER,
            employer VARCHAR(200),
            occupation VARCHAR(100),
            created_at TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_don_donor ON donations(donor_id);
        CREATE INDEX IF NOT EXISTS idx_don_date ON donations(donation_date);
        CREATE INDEX IF NOT EXISTS idx_don_cycle ON donations(election_cycle);
    """)
    conn.commit()
    log("Donations table ready")

# ============================================================
# DONOR MATCHING
# ============================================================

class DonorMatcher:
    """Thread-safe donor matching with caching"""
    
    def __init__(self, conn):
        self.lock = threading.Lock()
        self.by_name_zip = defaultdict(list)
        self.by_name_city = defaultdict(list)
        self.by_email = {}
        self.new_donors = {}  # Cache for newly created donors
        self._load_donors(conn)
    
    def _load_donors(self, conn):
        log("Loading existing donors for matching...")
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, first_name, last_name, email, city, state, zip_code
            FROM donors 
            WHERE first_name IS NOT NULL AND last_name IS NOT NULL
        """)
        donors = cur.fetchall()
        
        for d in donors:
            fn = self._normalize(d['first_name'])[:10]
            ln = self._normalize(d['last_name'])
            city = self._normalize(d['city'])
            zip5 = (d['zip_code'] or '')[:5]
            email = (d['email'] or '').lower().strip()
            
            if fn and ln:
                if zip5:
                    self.by_name_zip[f"{ln}|{fn}|{zip5}"].append(d['id'])
                if city:
                    self.by_name_city[f"{ln}|{fn}|{city}"].append(d['id'])
            if email:
                self.by_email[email] = d['id']
        
        log(f"Loaded {len(donors):,} donors")
        log(f"Indexes: {len(self.by_name_zip):,} name+zip, {len(self.by_name_city):,} name+city, {len(self.by_email):,} email")
    
    def _normalize(self, s):
        return (s or '').upper().strip()
    
    def match(self, first_name, last_name, city, zip_code, email=None):
        """Find existing donor. Returns donor_id or None"""
        fn = self._normalize(first_name)[:10]
        ln = self._normalize(last_name)
        city = self._normalize(city)
        zip5 = (zip_code or '')[:5]
        email = (email or '').lower().strip()
        
        # Priority 1: Email
        if email and email in self.by_email:
            return self.by_email[email]
        
        # Priority 2: Name + Zip (most accurate)
        if fn and ln and zip5:
            key = f"{ln}|{fn}|{zip5}"
            if key in self.by_name_zip:
                return self.by_name_zip[key][0]
        
        # Priority 3: Name + City (fallback)
        if fn and ln and city:
            key = f"{ln}|{fn}|{city}"
            if key in self.by_name_city:
                return self.by_name_city[key][0]
        
        # Check new donors cache
        if fn and ln and zip5:
            cache_key = f"{ln}|{fn}|{zip5}"
            with self.lock:
                if cache_key in self.new_donors:
                    return self.new_donors[cache_key]
        
        return None
    
    def create_donor(self, conn, first_name, last_name, city, state, zip_code, 
                     address=None, employer=None, occupation=None):
        """Create new donor and return id. Thread-safe."""
        fn = self._normalize(first_name)[:10]
        ln = self._normalize(last_name)
        zip5 = (zip_code or '')[:5]
        cache_key = f"{ln}|{fn}|{zip5}" if zip5 else f"{ln}|{fn}|{city}"
        
        with self.lock:
            # Double-check cache
            if cache_key in self.new_donors:
                return self.new_donors[cache_key]
            
            try:
                cur = conn.cursor()
                cur.execute("""
                    INSERT INTO donors (first_name, last_name, city, state, zip_code, 
                                        address, employer, occupation, data_source)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'FEC_BULK')
                    RETURNING id
                """, (first_name[:50], last_name[:50], city[:50] if city else None, 
                      state[:2] if state else None, zip5, 
                      address[:200] if address else None,
                      employer[:200] if employer else None, 
                      occupation[:100] if occupation else None))
                donor_id = cur.fetchone()[0]
                conn.commit()
                
                # Add to caches
                self.new_donors[cache_key] = donor_id
                if fn and ln and zip5:
                    self.by_name_zip[f"{ln}|{fn}|{zip5}"].append(donor_id)
                if fn and ln and city:
                    self.by_name_city[f"{ln}|{fn}|{self._normalize(city)}"].append(donor_id)
                
                return donor_id
            except Exception as e:
                conn.rollback()
                return None

# ============================================================
# FEC PROCESSING
# ============================================================

def get_republican_committees(cycle, data_dir):
    """Get set of Republican committee IDs"""
    cache_file = os.path.join(data_dir, f'rep_committees_{cycle}.txt')
    
    if os.path.exists(cache_file):
        with open(cache_file) as f:
            return set(line.strip() for line in f if line.strip())
    
    url = FEC_COMMITTEE_URLS.get(cycle)
    if not url:
        return set()
    
    log(f"Fetching Republican committees for {cycle}...")
    rep = set()
    
    try:
        r = requests.get(url, timeout=120)
        r.raise_for_status()
        
        with zipfile.ZipFile(io.BytesIO(r.content)) as z:
            for name in z.namelist():
                if name.endswith('.txt'):
                    with z.open(name) as f:
                        for line in f:
                            try:
                                parts = line.decode('utf-8', errors='ignore').split('|')
                                if len(parts) > 10:
                                    cm_id = parts[0].strip()
                                    party = parts[10].strip().upper()
                                    if party in ('REP', 'R', 'REPUBLICAN'):
                                        rep.add(cm_id)
                            except:
                                continue
        
        with open(cache_file, 'w') as f:
            f.write('\n'.join(rep))
        
        log(f"Found {len(rep):,} Republican committees for {cycle}")
        return rep
        
    except Exception as e:
        log(f"Error fetching committees: {e}")
        return set()

def parse_fec_name(name):
    """Parse FEC name format: LAST, FIRST MIDDLE"""
    name = (name or '').strip().upper()
    if ',' in name:
        parts = name.split(',', 1)
        last_name = parts[0].strip()
        first_parts = parts[1].strip().split()
        first_name = first_parts[0] if first_parts else ''
    else:
        parts = name.split()
        last_name = parts[-1] if parts else ''
        first_name = parts[0] if len(parts) > 1 else ''
    return first_name[:50], last_name[:50]

def download_fec_bulk(cycle, data_dir):
    """Download FEC bulk file"""
    url = FEC_INDIV_URLS.get(cycle)
    if not url:
        return None
    
    zip_path = os.path.join(data_dir, f'indiv{str(cycle)[2:]}.zip')
    
    if os.path.exists(zip_path):
        log(f"FEC {cycle} already downloaded")
        return zip_path
    
    log(f"Downloading FEC {cycle} bulk data...")
    try:
        r = requests.get(url, stream=True, timeout=600)
        r.raise_for_status()
        
        total = int(r.headers.get('content-length', 0))
        downloaded = 0
        
        with open(zip_path, 'wb') as f:
            for chunk in r.iter_content(chunk_size=1024*1024):
                f.write(chunk)
                downloaded += len(chunk)
                if total > 0 and downloaded % (100*1024*1024) == 0:
                    log(f"  {cycle}: {downloaded//(1024*1024)}MB / {total//(1024*1024)}MB")
        
        log(f"Downloaded FEC {cycle}: {os.path.getsize(zip_path)//(1024*1024)}MB")
        return zip_path
        
    except Exception as e:
        log(f"Download failed for {cycle}: {e}")
        return None

def process_fec_cycle(cycle, data_dir, matcher, pool):
    """Process one FEC cycle - runs in parallel"""
    
    zip_path = download_fec_bulk(cycle, data_dir)
    if not zip_path:
        return {'cycle': cycle, 'matched': 0, 'created': 0, 'skipped': 0}
    
    rep_committees = get_republican_committees(cycle, data_dir)
    if not rep_committees:
        log(f"No Republican committees for {cycle}")
        return {'cycle': cycle, 'matched': 0, 'created': 0, 'skipped': 0}
    
    log(f"Processing FEC {cycle} ({len(rep_committees):,} Republican committees)...")
    
    conn = pool.getconn()
    cur = conn.cursor()
    
    batch = []
    matched = 0
    created = 0
    skipped = 0
    total = 0
    
    try:
        with zipfile.ZipFile(zip_path) as z:
            for name in z.namelist():
                if 'itcont' in name.lower() or (name.endswith('.txt') and 'cm' not in name.lower()):
                    log(f"  Reading {name}...")
                    with z.open(name) as f:
                        for line_bytes in f:
                            total += 1
                            
                            if total % 1000000 == 0:
                                log(f"  {cycle}: {total:,} rows, {matched:,} matched, {created:,} created, {skipped:,} skipped")
                                # Flush batch
                                if batch:
                                    _insert_donations(cur, conn, batch)
                                    batch = []
                            
                            try:
                                line = line_bytes.decode('utf-8', errors='ignore')
                                parts = line.strip().split('|')
                                if len(parts) < 15:
                                    continue
                                
                                committee_id = parts[0].strip()
                                
                                # REPUBLICAN FILTER
                                if committee_id not in rep_committees:
                                    skipped += 1
                                    continue
                                
                                # Parse fields
                                name = parts[7].strip()
                                city = parts[8].strip()
                                state = parts[9].strip()
                                zip_code = parts[10].strip()[:5]
                                employer = parts[11].strip()[:200]
                                occupation = parts[12].strip()[:100]
                                date_str = parts[13].strip()
                                amount_str = parts[14].strip()
                                
                                first_name, last_name = parse_fec_name(name)
                                if not first_name or not last_name:
                                    skipped += 1
                                    continue
                                
                                # Parse date (MMDDYYYY)
                                donation_date = None
                                if len(date_str) == 8:
                                    try:
                                        donation_date = f"{date_str[4:8]}-{date_str[0:2]}-{date_str[2:4]}"
                                    except:
                                        pass
                                
                                # Parse amount
                                try:
                                    amount = float(amount_str.replace(',', ''))
                                except:
                                    amount = 0
                                
                                # MATCH OR CREATE DONOR
                                donor_id = matcher.match(first_name, last_name, city, zip_code)
                                
                                if donor_id:
                                    matched += 1
                                else:
                                    # Create new donor
                                    donor_id = matcher.create_donor(
                                        conn, first_name, last_name, city, state, zip_code,
                                        None, employer, occupation
                                    )
                                    if donor_id:
                                        created += 1
                                    else:
                                        skipped += 1
                                        continue
                                
                                # Transaction ID
                                trans_id = f"FEC{cycle}_{committee_id}_{total}"
                                
                                batch.append((
                                    donor_id, amount, donation_date, None, 'REP',
                                    committee_id, trans_id, 'FEC', 'FEDERAL', cycle,
                                    employer, occupation
                                ))
                                
                                if len(batch) >= BATCH_SIZE:
                                    _insert_donations(cur, conn, batch)
                                    batch = []
                                
                            except Exception as e:
                                continue
                    break  # Only first matching file
        
        # Final batch
        if batch:
            _insert_donations(cur, conn, batch)
        
    except Exception as e:
        log(f"Error processing {cycle}: {e}")
    finally:
        pool.putconn(conn)
    
    log(f"FEC {cycle} DONE: {matched:,} matched, {created:,} created, {skipped:,} skipped")
    return {'cycle': cycle, 'matched': matched, 'created': created, 'skipped': skipped}

def _insert_donations(cur, conn, batch):
    """Batch insert donations"""
    try:
        execute_values(cur, """
            INSERT INTO donations 
            (donor_id, amount, donation_date, candidate_name, candidate_party,
             committee_id, transaction_id, source, race_type, election_cycle,
             employer, occupation)
            VALUES %s
            ON CONFLICT (transaction_id) DO NOTHING
        """, batch)
        conn.commit()
    except Exception as e:
        conn.rollback()

# ============================================================
# NCSBE PROCESSING
# ============================================================

def process_ncsbe(data_dir, matcher, pool):
    """Process NCSBE state/local donations"""
    ncsbe_dir = '/root/nc_republican_donors/NCSBE'
    
    if not os.path.exists(ncsbe_dir):
        log("NCSBE directory not found, skipping")
        return {'matched': 0, 'created': 0}
    
    log("Processing NCSBE state/local donations...")
    
    conn = pool.getconn()
    cur = conn.cursor()
    
    matched = 0
    created = 0
    
    try:
        for filename in sorted(os.listdir(ncsbe_dir)):
            if not filename.endswith('.csv'):
                continue
            
            filepath = os.path.join(ncsbe_dir, filename)
            office = filename.replace('.csv', '')
            batch = []
            file_count = 0
            
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    reader = csv.DictReader(f)
                    
                    for i, row in enumerate(reader):
                        name = row.get('Name', '').strip()
                        if not name or 'Aggregated' in name:
                            continue
                        
                        city = row.get('City', '').strip()
                        state = row.get('State', 'NC').strip()
                        zip_code = (row.get('Zip Code', '') or '')[:5]
                        amount_str = row.get('Amount', '0')
                        date_str = row.get('Date', '')
                        candidate = row.get('Candidate', row.get('Committee Name', ''))[:200]
                        
                        # Parse name
                        parts = name.split()
                        if len(parts) >= 2:
                            first_name = parts[0][:50]
                            last_name = ' '.join(parts[1:])[:50]
                        else:
                            continue
                        
                        # Match or create
                        donor_id = matcher.match(first_name, last_name, city, zip_code)
                        if donor_id:
                            matched += 1
                        else:
                            donor_id = matcher.create_donor(conn, first_name, last_name, city, state, zip_code)
                            if donor_id:
                                created += 1
                            else:
                                continue
                        
                        file_count += 1
                        
                        # Parse amount
                        try:
                            amount = float(amount_str.replace(',', '').replace('$', ''))
                        except:
                            amount = 0
                        
                        # Parse date
                        donation_date = None
                        if '/' in date_str:
                            try:
                                p = date_str.split('/')
                                donation_date = f"{p[2]}-{p[0].zfill(2)}-{p[1].zfill(2)}"
                            except:
                                pass
                        
                        trans_id = f"NCSBE_{office}_{i}"
                        
                        batch.append((
                            donor_id, amount, donation_date, candidate, 'REP',
                            None, trans_id, 'NCSBE', 'STATE', 2024, None, None
                        ))
                        
                        if len(batch) >= BATCH_SIZE:
                            _insert_donations(cur, conn, batch)
                            batch = []
                
                if batch:
                    _insert_donations(cur, conn, batch)
                
                if file_count > 0:
                    log(f"  {filename}: {file_count:,}")
                    
            except Exception as e:
                log(f"Error {filename}: {e}")
    
    finally:
        pool.putconn(conn)
    
    log(f"NCSBE DONE: {matched:,} matched, {created:,} created")
    return {'matched': matched, 'created': created}

# ============================================================
# MAIN
# ============================================================

def main():
    log("=" * 70)
    log("REPUBLICAN DONOR HISTORY BUILDER v2")
    log("Bulk downloads + Parallel processing + Proper matching")
    log("=" * 70)
    
    os.makedirs(DATA_DIR, exist_ok=True)
    
    # Connection pool for parallel workers
    log("Creating connection pool...")
    pool = ThreadedConnectionPool(1, 10, DB_URL)
    conn = pool.getconn()
    
    # Setup
    create_donations_table(conn)
    
    # Get before counts
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM donors")
    donors_before = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM donations")
    donations_before = cur.fetchone()[0]
    
    log(f"Before: {donors_before:,} donors, {donations_before:,} donations")
    
    # Load donors for matching
    matcher = DonorMatcher(conn)
    pool.putconn(conn)
    
    # Process FEC cycles in parallel (20 workers = 4 cycles * 5 threads each conceptually)
    log("Processing FEC bulk data (parallel)...")
    
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = {
            executor.submit(process_fec_cycle, cycle, DATA_DIR, matcher, pool): cycle
            for cycle in [2016, 2018, 2020, 2022, 2024]
        }
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            log(f"Completed cycle {result['cycle']}")
    
    # Process NCSBE
    ncsbe_result = process_ncsbe(DATA_DIR, matcher, pool)
    
    # Final counts
    conn = pool.getconn()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM donors")
    donors_after = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM donations")
    donations_after = cur.fetchone()[0]
    cur.execute("SELECT COUNT(DISTINCT donor_id) FROM donations WHERE donor_id IS NOT NULL")
    donors_with_history = cur.fetchone()[0]
    pool.putconn(conn)
    
    # Summary
    total_matched = sum(r['matched'] for r in results) + ncsbe_result['matched']
    total_created = sum(r['created'] for r in results) + ncsbe_result['created']
    
    log("=" * 70)
    log("COMPLETE")
    log(f"  Donors: {donors_before:,} -> {donors_after:,} (+{donors_after-donors_before:,} new)")
    log(f"  Donations: {donations_before:,} -> {donations_after:,} (+{donations_after-donations_before:,})")
    log(f"  Matched to existing: {total_matched:,}")
    log(f"  New donors created: {total_created:,}")
    log(f"  Donors with history: {donors_with_history:,}")
    log("=" * 70)
    
    save_progress({
        'status': 'COMPLETE',
        'donors_before': donors_before,
        'donors_after': donors_after,
        'donations_before': donations_before,
        'donations_after': donations_after,
        'total_matched': total_matched,
        'total_created': total_created,
        'donors_with_history': donors_with_history,
        'completed_at': datetime.now().isoformat()
    })
    
    pool.closeall()

if __name__ == '__main__':
    main()
