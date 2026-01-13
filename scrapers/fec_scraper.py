#!/usr/bin/env python3
"""
FEC Republican Donor Scraper
BroyhillGOP Platform - E00 DataHub Integration

Scrapes 10 years of quarterly FEC donation data for Republican candidates.
Integrates with existing Supabase donor records without overwriting enriched data.

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
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
import psycopg2
from psycopg2.extras import execute_values, RealDictCursor

# ============================================================================
# CONFIGURATION
# ============================================================================

# FEC API Configuration
FEC_API_KEY = os.getenv("FEC_API_KEY", "DEMO_KEY")  # Get real key from fec.gov
FEC_BASE_URL = "https://api.open.fec.gov/v1"

# Supabase Configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "postgresql://postgres.nqkoprtmgewchlynjxqz:poSkon-hurpok-6wuzwo@aws-0-us-east-1.pooler.supabase.com:6543/postgres")

# Scraper Configuration
PROGRESS_FILE = "/root/fec_progress.json"
OUTPUT_DIR = "/root/fec_data"
LOG_FILE = "/root/fec_scraper.log"
CHECKPOINT_INTERVAL = 1000  # Save every N records
RATE_LIMIT_DELAY = 0.5  # Seconds between API calls
MAX_RETRIES = 3

# Date Range: 10 years quarterly (2015-Q1 to 2024-Q4)
START_YEAR = 2015
END_YEAR = 2024

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

def save_progress(last_candidate_id: str, records_scraped: int, 
                  current_cycle: int, page: int):
    """Save scraping progress for resume capability"""
    progress = {
        'last_candidate_id': last_candidate_id,
        'records_scraped': records_scraped,
        'current_cycle': current_cycle,
        'current_page': page,
        'timestamp': datetime.now().isoformat()
    }
    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f, indent=2)
    logger.info(f"Progress saved: {records_scraped} records, cycle {current_cycle}")

def load_progress() -> Dict:
    """Load previous progress for resume"""
    if os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {
        'last_candidate_id': None,
        'records_scraped': 0,
        'current_cycle': START_YEAR * 2,  # FEC uses 2-year cycles
        'current_page': 1
    }

# ============================================================================
# FEC API FUNCTIONS
# ============================================================================

def get_republican_candidates(election_cycle: int, page: int = 1) -> Dict:
    """Fetch Republican candidates from FEC API"""
    url = f"{FEC_BASE_URL}/candidates/"
    params = {
        'api_key': FEC_API_KEY,
        'party': 'REP',  # REPUBLICANS ONLY
         'state': 'NC', # NC CANDIDATES ONLY
        'cycle': election_cycle,
        'per_page': 100,
        'page': page,
        'sort': 'name'
    }
    
    for attempt in range(MAX_RETRIES):
        try:
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.warning(f"API error (attempt {attempt + 1}): {e}")
            time.sleep(RATE_LIMIT_DELAY * (attempt + 1))
    
    return {'results': [], 'pagination': {'pages': 0}}

def get_candidate_contributions(candidate_id: str, election_cycle: int, 
                                 page: int = 1) -> Dict:
    """Fetch individual contributions to a candidate"""
    url = f"{FEC_BASE_URL}/schedules/schedule_a/"
    params = {
        'api_key': FEC_API_KEY,
        'candidate_id': candidate_id,
        'two_year_transaction_period': election_cycle,
        'per_page': 100,
        'page': page,
        'sort': '-contribution_receipt_date'
    }
    
    for attempt in range(MAX_RETRIES):
        try:
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.warning(f"Contribution API error (attempt {attempt + 1}): {e}")
            time.sleep(RATE_LIMIT_DELAY * (attempt + 1))
    
    return {'results': [], 'pagination': {'pages': 0}}

# ============================================================================
# DATA PROCESSING
# ============================================================================

def parse_contribution(contrib: Dict, candidate_info: Dict) -> Dict:
    """Parse FEC contribution record into standard format"""
    return {
        'transaction_id': contrib.get('transaction_id', ''),
        'donor_name': contrib.get('contributor_name', ''),
        'donor_first_name': contrib.get('contributor_first_name', ''),
        'donor_last_name': contrib.get('contributor_last_name', ''),
        'donor_address': contrib.get('contributor_street_1', ''),
        'donor_city': contrib.get('contributor_city', ''),
        'donor_state': contrib.get('contributor_state', ''),
        'donor_zip': contrib.get('contributor_zip', '')[:5] if contrib.get('contributor_zip') else '',
        'donor_employer': contrib.get('contributor_employer', ''),
        'donor_occupation': contrib.get('contributor_occupation', ''),
        'amount': float(contrib.get('contribution_receipt_amount', 0)),
        'donation_date': contrib.get('contribution_receipt_date', ''),
        'candidate_id': candidate_info.get('candidate_id', ''),
        'candidate_name': candidate_info.get('name', ''),
        'candidate_party': 'REP',  # Verified Republican
        'candidate_office': candidate_info.get('office', ''),
        'candidate_state': candidate_info.get('state', ''),
        'election_cycle': candidate_info.get('cycle', ''),
        'race_level': 'Federal',
        'source': 'FEC',
        'scraped_at': datetime.now().isoformat()
    }

def save_checkpoint(donations: List[Dict], checkpoint_num: int):
    """Save donations to CSV checkpoint file"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filename = f"{OUTPUT_DIR}/fec_donations_checkpoint_{checkpoint_num}.csv"
    
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
        donation['candidate_office'],
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
        'FEC'
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

def scrape_fec_republican_donations():
    """Main scraper function with auto-resume capability"""
    logger.info("=" * 60)
    logger.info("FEC REPUBLICAN DONOR SCRAPER STARTED")
    logger.info("=" * 60)
    
    # Load progress
    progress = load_progress()
    total_records = progress['records_scraped']
    start_cycle = progress['current_cycle']
    
    logger.info(f"Resuming from cycle {start_cycle}, {total_records} records already scraped")
    
    # Create output directory
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Buffer for checkpoint
    donation_buffer = []
    checkpoint_num = total_records // CHECKPOINT_INTERVAL
    
    # Iterate through election cycles (2-year periods)
    for cycle in range(start_cycle, (END_YEAR + 1) * 2, 2):
        if cycle > END_YEAR * 2:
            break
            
        logger.info(f"\n{'='*40}")
        logger.info(f"Processing Election Cycle: {cycle}")
        logger.info(f"{'='*40}")
        
        # Get Republican candidates for this cycle
        page = 1
        while True:
            candidates_response = get_republican_candidates(cycle, page)
            candidates = candidates_response.get('results', [])
            
            if not candidates:
                break
            
            for candidate in candidates:
                candidate_id = candidate.get('candidate_id')
                candidate_name = candidate.get('name')
                candidate_party = candidate.get('party')
                
                # VERIFY REPUBLICAN
                if candidate_party != 'REP':
                    logger.warning(f"Skipping non-Republican: {candidate_name} ({candidate_party})")
                    continue
                
                logger.info(f"Scraping: {candidate_name} ({candidate_id})")
                
                # Get contributions for this candidate
                contrib_page = 1
                while True:
                    contrib_response = get_candidate_contributions(
                        candidate_id, cycle, contrib_page
                    )
                    contributions = contrib_response.get('results', [])
                    
                    if not contributions:
                        break
                    
                    for contrib in contributions:
                        donation = parse_contribution(contrib, {
                            'candidate_id': candidate_id,
                            'name': candidate_name,
                            'office': candidate.get('office'),
                            'state': candidate.get('state'),
                            'cycle': cycle
                        })
                        
                        donation_buffer.append(donation)
                        total_records += 1
                        
                        # Checkpoint every N records
                        if len(donation_buffer) >= CHECKPOINT_INTERVAL:
                            checkpoint_num += 1
                            save_checkpoint(donation_buffer, checkpoint_num)
                            save_progress(candidate_id, total_records, cycle, page)
                            
                            # Upload to Supabase
                            try:
                                upload_to_supabase(donation_buffer)
                            except Exception as e:
                                logger.error(f"Supabase upload failed: {e}")
                            
                            donation_buffer = []
                    
                    # Check for more pages
                    total_pages = contrib_response.get('pagination', {}).get('pages', 1)
                    if contrib_page >= total_pages:
                        break
                    contrib_page += 1
                    time.sleep(RATE_LIMIT_DELAY)
                
                time.sleep(RATE_LIMIT_DELAY)
            
            # Check for more candidate pages
            total_pages = candidates_response.get('pagination', {}).get('pages', 1)
            if page >= total_pages:
                break
            page += 1
    
    # Final checkpoint
    if donation_buffer:
        checkpoint_num += 1
        save_checkpoint(donation_buffer, checkpoint_num)
        upload_to_supabase(donation_buffer)
    
    save_progress("COMPLETE", total_records, END_YEAR * 2, 0)
    
    logger.info("=" * 60)
    logger.info(f"SCRAPING COMPLETE: {total_records} total records")
    logger.info("=" * 60)

# ============================================================================
# ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    try:
        scrape_fec_republican_donations()
    except KeyboardInterrupt:
        logger.info("Scraper interrupted by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        raise
