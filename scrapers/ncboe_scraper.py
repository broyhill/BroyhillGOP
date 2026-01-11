#!/usr/bin/env python3
"""
NCBOE Republican Donor Scraper
BroyhillGOP Platform - E00 DataHub Integration

Scrapes 10 years of NC State Board of Elections donation data 
for Republican candidates at State and Local levels.

Author: BroyhillGOP Platform
Created: January 11, 2026
"""

import os
import sys
import json
import csv
import time
import logging
import requests
from datetime import datetime
from typing import Optional, Dict, List
import psycopg2
from bs4 import BeautifulSoup
import pandas as pd
from io import StringIO

# ============================================================================
# CONFIGURATION
# ============================================================================

# NCBOE Configuration
NCBOE_BASE_URL = "https://cf.ncsbe.gov"
NCBOE_SEARCH_URL = f"{NCBOE_BASE_URL}/CFTxnLkup"
NCBOE_DOWNLOAD_URL = f"{NCBOE_BASE_URL}/CFOrgLkup/ExportDetailResults"

# Supabase Configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-0-us-east-1.pooler.supabase.com:6543/postgres")

# Scraper Configuration
PROGRESS_FILE = "/root/ncboe_progress.json"
OUTPUT_DIR = "/root/ncboe_data"
LOG_FILE = "/root/ncboe_scraper.log"
CHECKPOINT_INTERVAL = 1000
RATE_LIMIT_DELAY = 1.0  # NCBOE is slower, be respectful
MAX_RETRIES = 3

# Date Range: 10 years (2015-2024)
START_YEAR = 2015
END_YEAR = 2024

# Republican Party Codes in NCBOE
REPUBLICAN_PARTY_CODES = ['REP', 'Republican', 'R']

# ============================================================================
# LOGGING SETUP
# ============================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# ============================================================================
# PROGRESS TRACKING
# ============================================================================

def save_progress(last_committee: str, records_scraped: int, 
                  current_year: int):
    """Save scraping progress for resume capability"""
    progress = {
        'last_committee': last_committee,
        'records_scraped': records_scraped,
        'current_year': current_year,
        'timestamp': datetime.now().isoformat()
    }
    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f, indent=2)
    logger.info(f"Progress saved: {records_scraped} records, year {current_year}")

def load_progress() -> Dict:
    """Load previous progress for resume"""
    if os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {
        'last_committee': None,
        'records_scraped': 0,
        'current_year': START_YEAR
    }

# ============================================================================
# NCBOE SCRAPING FUNCTIONS
# ============================================================================

def get_session():
    """Create requests session with headers"""
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
    })
    return session

def get_republican_committees(session, year: int) -> List[Dict]:
    """Fetch Republican campaign committees from NCBOE"""
    committees = []
    
    # NCBOE committee search
    search_url = f"{NCBOE_BASE_URL}/CFOrgLkup/SearchCF"
    
    params = {
        'searchBy': 'committee',
        'party': 'REP',  # REPUBLICANS ONLY
        'year': year,
        'electionType': 'ALL'
    }
    
    for attempt in range(MAX_RETRIES):
        try:
            response = session.get(search_url, params=params, timeout=60)
            response.raise_for_status()
            
            # Parse HTML response
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Find committee table
            table = soup.find('table', {'id': 'searchResults'})
            if not table:
                # Try alternate table structure
                table = soup.find('table', class_='table')
            
            if table:
                rows = table.find_all('tr')[1:]  # Skip header
                for row in rows:
                    cols = row.find_all('td')
                    if len(cols) >= 4:
                        committee = {
                            'committee_id': cols[0].get_text(strip=True),
                            'committee_name': cols[1].get_text(strip=True),
                            'candidate_name': cols[2].get_text(strip=True),
                            'party': cols[3].get_text(strip=True),
                            'year': year
                        }
                        
                        # VERIFY REPUBLICAN
                        if committee['party'] in REPUBLICAN_PARTY_CODES:
                            committees.append(committee)
            
            break
            
        except requests.exceptions.RequestException as e:
            logger.warning(f"NCBOE search error (attempt {attempt + 1}): {e}")
            time.sleep(RATE_LIMIT_DELAY * (attempt + 1))
    
    logger.info(f"Found {len(committees)} Republican committees for {year}")
    return committees

def get_committee_contributions(session, committee_id: str, year: int) -> List[Dict]:
    """Fetch contributions for a specific committee"""
    contributions = []
    
    # NCBOE transaction lookup
    txn_url = f"{NCBOE_BASE_URL}/CFTxnLkup/SearchResults"
    
    params = {
        'SID': committee_id,
        'TranType': 'ALL',
        'FromDate': f'01/01/{year}',
        'ToDate': f'12/31/{year}'
    }
    
    for attempt in range(MAX_RETRIES):
        try:
            response = session.get(txn_url, params=params, timeout=120)
            response.raise_for_status()
            
            # Try to parse as CSV if available
            if 'text/csv' in response.headers.get('Content-Type', ''):
                df = pd.read_csv(StringIO(response.text))
                contributions = df.to_dict('records')
            else:
                # Parse HTML table
                soup = BeautifulSoup(response.text, 'html.parser')
                table = soup.find('table', {'id': 'transactionResults'})
                
                if table:
                    rows = table.find_all('tr')[1:]  # Skip header
                    for row in rows:
                        cols = row.find_all('td')
                        if len(cols) >= 6:
                            contrib = {
                                'transaction_id': cols[0].get_text(strip=True),
                                'date': cols[1].get_text(strip=True),
                                'contributor_name': cols[2].get_text(strip=True),
                                'contributor_address': cols[3].get_text(strip=True),
                                'amount': cols[4].get_text(strip=True),
                                'transaction_type': cols[5].get_text(strip=True)
                            }
                            contributions.append(contrib)
            
            break
            
        except requests.exceptions.RequestException as e:
            logger.warning(f"NCBOE transaction error (attempt {attempt + 1}): {e}")
            time.sleep(RATE_LIMIT_DELAY * (attempt + 1))
    
    return contributions

def download_bulk_contributions(session, year: int) -> pd.DataFrame:
    """Download bulk contribution data from NCBOE"""
    
    # NCBOE provides bulk downloads
    bulk_url = f"https://s3.amazonaws.com/dl.ncsbe.gov/cf/{year}/receipts_{year}.csv"
    
    for attempt in range(MAX_RETRIES):
        try:
            logger.info(f"Downloading bulk data for {year}...")
            response = session.get(bulk_url, timeout=300)
            response.raise_for_status()
            
            df = pd.read_csv(StringIO(response.text), low_memory=False)
            logger.info(f"Downloaded {len(df)} records for {year}")
            return df
            
        except requests.exceptions.RequestException as e:
            logger.warning(f"Bulk download error (attempt {attempt + 1}): {e}")
            time.sleep(RATE_LIMIT_DELAY * (attempt + 1))
    
    return pd.DataFrame()

# ============================================================================
# DATA PROCESSING
# ============================================================================

def parse_ncboe_contribution(contrib: Dict, committee: Dict) -> Dict:
    """Parse NCBOE contribution record into standard format"""
    
    # Parse contributor name
    name = contrib.get('contributor_name', '') or contrib.get('Name', '')
    name_parts = name.split(',') if ',' in name else name.split()
    
    # Parse address
    address = contrib.get('contributor_address', '') or contrib.get('Address', '')
    city, state, zip_code = '', 'NC', ''
    
    if address:
        # Try to parse city, state, zip from address
        parts = address.split(',')
        if len(parts) >= 2:
            city = parts[-2].strip() if len(parts) > 2 else ''
            state_zip = parts[-1].strip().split()
            if len(state_zip) >= 1:
                state = state_zip[0]
            if len(state_zip) >= 2:
                zip_code = state_zip[1][:5]
    
    # Parse amount
    amount_str = str(contrib.get('amount', '') or contrib.get('Amount', '0'))
    amount = float(amount_str.replace('$', '').replace(',', '').strip() or 0)
    
    # Determine race level
    office = committee.get('candidate_name', '').lower()
    if any(x in office for x in ['senate', 'house', 'congress', 'representative']):
        race_level = 'Federal'
    elif any(x in office for x in ['governor', 'lt. gov', 'attorney general', 'state']):
        race_level = 'State'
    else:
        race_level = 'Local'
    
    return {
        'transaction_id': f"NCBOE-{contrib.get('transaction_id', '')}-{committee.get('year', '')}",
        'donor_name': name,
        'donor_first_name': name_parts[-1] if len(name_parts) > 1 else '',
        'donor_last_name': name_parts[0] if name_parts else '',
        'donor_address': address,
        'donor_city': city,
        'donor_state': state,
        'donor_zip': zip_code,
        'donor_employer': contrib.get('employer', ''),
        'donor_occupation': contrib.get('profession', ''),
        'amount': amount,
        'donation_date': contrib.get('date', '') or contrib.get('Date Trans', ''),
        'candidate_id': committee.get('committee_id', ''),
        'candidate_name': committee.get('candidate_name', ''),
        'candidate_party': 'REP',  # Verified Republican
        'candidate_office': committee.get('office', ''),
        'election_cycle': committee.get('year', ''),
        'race_level': race_level,
        'source': 'NCBOE',
        'scraped_at': datetime.now().isoformat()
    }

def filter_republicans(df: pd.DataFrame) -> pd.DataFrame:
    """Filter dataframe to Republican candidates only"""
    
    # Common party column names in NCBOE data
    party_cols = ['Party', 'party', 'Candidate Party', 'Committee Party']
    
    for col in party_cols:
        if col in df.columns:
            df = df[df[col].isin(REPUBLICAN_PARTY_CODES)]
            break
    
    logger.info(f"After Republican filter: {len(df)} records")
    return df

def save_checkpoint(donations: List[Dict], checkpoint_num: int):
    """Save donations to CSV checkpoint file"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filename = f"{OUTPUT_DIR}/ncboe_donations_checkpoint_{checkpoint_num}.csv"
    
    if not donations:
        return
    
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=donations[0].keys())
        writer.writeheader()
        writer.writerows(donations)
    
    logger.info(f"Checkpoint saved: {filename} ({len(donations)} records)")

# ============================================================================
# SUPABASE INTEGRATION
# ============================================================================

def get_db_connection():
    """Get Supabase database connection"""
    return psycopg2.connect(SUPABASE_URL)

def find_existing_donor(conn, name: str, zip_code: str, 
                        email: str = None, phone: str = None) -> Optional[str]:
    """Find matching donor in Supabase - preserves existing enriched data"""
    cur = conn.cursor()
    
    # Try exact email match first
    if email:
        cur.execute(
            "SELECT donor_id FROM donors WHERE LOWER(email) = LOWER(%s)", 
            (email,)
        )
        result = cur.fetchone()
        if result:
            return result[0]
    
    # Try phone match
    if phone:
        clean_phone = ''.join(filter(str.isdigit, str(phone)))[-10:]
        if len(clean_phone) == 10:
            cur.execute(
                "SELECT donor_id FROM donors WHERE phone LIKE %s", 
                (f"%{clean_phone}",)
            )
            result = cur.fetchone()
            if result:
                return result[0]
    
    # Try name + zip match
    if name and zip_code:
        cur.execute("""
            SELECT donor_id FROM donors 
            WHERE LOWER(full_name) = LOWER(%s) AND zip_code = %s
        """, (name, zip_code[:5]))
        result = cur.fetchone()
        if result:
            return result[0]
    
    return None

def insert_donation(conn, donor_id: str, donation: Dict):
    """Insert donation record linked to donor"""
    cur = conn.cursor()
    
    # Check if donation already exists (by transaction_id)
    cur.execute(
        "SELECT donation_id FROM donations WHERE transaction_id = %s",
        (donation['transaction_id'],)
    )
    if cur.fetchone():
        return  # Already exists
    
    cur.execute("""
        INSERT INTO donations (
            donor_id, amount, donation_date, candidate_id, candidate_name,
            candidate_party, candidate_office, election_cycle, race_level,
            transaction_id, source, created_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
        ON CONFLICT (transaction_id) DO NOTHING
    """, (
        donor_id,
        donation['amount'],
        donation['donation_date'],
        donation['candidate_id'],
        donation['candidate_name'],
        donation['candidate_party'],
        donation.get('candidate_office', ''),
        donation['election_cycle'],
        donation['race_level'],
        donation['transaction_id'],
        donation['source']
    ))

def create_donor(conn, donation: Dict) -> str:
    """Create new donor record from donation data"""
    cur = conn.cursor()
    
    cur.execute("""
        INSERT INTO donors (
            full_name, first_name, last_name, address, city, state, zip_code,
            employer, occupation, source, created_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
        RETURNING donor_id
    """, (
        donation['donor_name'],
        donation['donor_first_name'],
        donation['donor_last_name'],
        donation['donor_address'],
        donation['donor_city'],
        donation['donor_state'],
        donation['donor_zip'],
        donation['donor_employer'],
        donation['donor_occupation'],
        'NCBOE'
    ))
    
    return cur.fetchone()[0]

def upload_to_supabase(donations: List[Dict]):
    """Upload donations to Supabase with deduplication"""
    conn = get_db_connection()
    
    new_donors = 0
    matched_donors = 0
    donations_inserted = 0
    
    try:
        for donation in donations:
            # Find existing donor or create new
            donor_id = find_existing_donor(
                conn,
                donation['donor_name'],
                donation['donor_zip']
            )
            
            if donor_id:
                matched_donors += 1
            else:
                donor_id = create_donor(conn, donation)
                new_donors += 1
            
            # Insert donation record
            insert_donation(conn, donor_id, donation)
            donations_inserted += 1
        
        conn.commit()
        logger.info(f"Uploaded: {donations_inserted} donations, "
                   f"{new_donors} new donors, {matched_donors} matched")
        
    except Exception as e:
        conn.rollback()
        logger.error(f"Upload error: {e}")
        raise
    finally:
        conn.close()

# ============================================================================
# MAIN SCRAPER
# ============================================================================

def scrape_ncboe_republican_donations():
    """Main scraper function with auto-resume capability"""
    logger.info("=" * 60)
    logger.info("NCBOE REPUBLICAN DONOR SCRAPER STARTED")
    logger.info("=" * 60)
    
    # Load progress
    progress = load_progress()
    total_records = progress['records_scraped']
    start_year = progress['current_year']
    
    logger.info(f"Resuming from year {start_year}, {total_records} records already scraped")
    
    # Create output directory
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Create session
    session = get_session()
    
    # Buffer for checkpoint
    donation_buffer = []
    checkpoint_num = total_records // CHECKPOINT_INTERVAL
    
    # Iterate through years
    for year in range(start_year, END_YEAR + 1):
        logger.info(f"\n{'='*40}")
        logger.info(f"Processing Year: {year}")
        logger.info(f"{'='*40}")
        
        # Try bulk download first (faster)
        bulk_df = download_bulk_contributions(session, year)
        
        if not bulk_df.empty:
            # Filter to Republicans
            bulk_df = filter_republicans(bulk_df)
            
            # Process bulk data
            for _, row in bulk_df.iterrows():
                committee = {
                    'committee_id': row.get('Committee SBoE ID', ''),
                    'candidate_name': row.get('Candidate Name', ''),
                    'year': year
                }
                
                donation = parse_ncboe_contribution(row.to_dict(), committee)
                donation_buffer.append(donation)
                total_records += 1
                
                # Checkpoint
                if len(donation_buffer) >= CHECKPOINT_INTERVAL:
                    checkpoint_num += 1
                    save_checkpoint(donation_buffer, checkpoint_num)
                    save_progress(committee.get('committee_id', ''), total_records, year)
                    
                    try:
                        upload_to_supabase(donation_buffer)
                    except Exception as e:
                        logger.error(f"Supabase upload failed: {e}")
                    
                    donation_buffer = []
        
        else:
            # Fall back to committee-by-committee scraping
            committees = get_republican_committees(session, year)
            
            for committee in committees:
                committee_id = committee['committee_id']
                logger.info(f"Scraping: {committee['candidate_name']} ({committee_id})")
                
                contributions = get_committee_contributions(session, committee_id, year)
                
                for contrib in contributions:
                    donation = parse_ncboe_contribution(contrib, committee)
                    donation_buffer.append(donation)
                    total_records += 1
                    
                    # Checkpoint
                    if len(donation_buffer) >= CHECKPOINT_INTERVAL:
                        checkpoint_num += 1
                        save_checkpoint(donation_buffer, checkpoint_num)
                        save_progress(committee_id, total_records, year)
                        
                        try:
                            upload_to_supabase(donation_buffer)
                        except Exception as e:
                            logger.error(f"Supabase upload failed: {e}")
                        
                        donation_buffer = []
                
                time.sleep(RATE_LIMIT_DELAY)
        
        logger.info(f"Year {year} complete. Total records: {total_records}")
    
    # Final checkpoint
    if donation_buffer:
        checkpoint_num += 1
        save_checkpoint(donation_buffer, checkpoint_num)
        upload_to_supabase(donation_buffer)
    
    save_progress("COMPLETE", total_records, END_YEAR)
    
    logger.info("=" * 60)
    logger.info(f"SCRAPING COMPLETE: {total_records} total records")
    logger.info("=" * 60)

# ============================================================================
# ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    try:
        scrape_ncboe_republican_donations()
    except KeyboardInterrupt:
        logger.info("Scraper interrupted by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        raise
