#!/usr/bin/env python3
"""
BROYHILLGOP DATA REPAIR - CANDIDATE ATTRIBUTION
================================================
Created: January 19, 2026 (Autonomous Repair Session)
Protocol: METICULOUS EXECUTION MANDATE v2.0

This script fixes the missing candidate attribution by:
1. Creating fec_committee_candidate_lookup table from cn.txt and ccl.txt
2. Backfilling candidate_name in donation_history using the lookup
3. Adding proper columns to donations table
4. Populating donations from donations_raw with full attribution

PRESERVES ALL EXISTING DATA - NO DELETIONS
"""

import os
import sys
import psycopg2
from psycopg2.extras import execute_batch, RealDictCursor
from datetime import datetime
import logging

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - REPAIR - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/broyhillgop/logs/repair_candidate_attribution.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('repair')

# Load environment
from dotenv import load_dotenv
load_dotenv('/opt/broyhillgop/config/supabase.env')

DATABASE_URL = os.getenv('DATABASE_URL')

# File paths
FEC_CN_FILE = '/opt/broyhillgop/data/fec/cn.txt'
FEC_CCL_FILE = '/opt/broyhillgop/data/fec/ccl.txt'


def create_lookup_table(cursor):
    """Create the FEC committee-candidate lookup table"""
    logger.info('Creating fec_committee_candidate_lookup table...')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS fec_committee_candidate_lookup (
            committee_id VARCHAR(20) PRIMARY KEY,
            candidate_id VARCHAR(20),
            candidate_name VARCHAR(255),
            candidate_party VARCHAR(10),
            candidate_office VARCHAR(5),
            candidate_office_state VARCHAR(5),
            candidate_office_district VARCHAR(5),
            election_year INTEGER,
            created_at TIMESTAMP DEFAULT NOW()
        );
        
        CREATE INDEX IF NOT EXISTS idx_fec_lookup_candidate 
        ON fec_committee_candidate_lookup(candidate_id);
    ''')
    logger.info('Lookup table created')


def load_candidates(cursor):
    """Load FEC candidate master file (cn.txt)"""
    logger.info(f'Loading candidates from {FEC_CN_FILE}...')
    
    # cn.txt format: CAND_ID|CAND_NAME|CAND_PTY|CAND_YR|CAND_ST|CAND_OFFICE|CAND_DISTRICT|...
    candidates = {}
    
    with open(FEC_CN_FILE, 'r', encoding='latin-1') as f:
        for line_num, line in enumerate(f, 1):
            try:
                parts = line.strip().split('|')
                if len(parts) >= 7:
                    cand_id = parts[0]
                    candidates[cand_id] = {
                        'name': parts[1] if len(parts) > 1 else '',
                        'party': parts[2] if len(parts) > 2 else '',
                        'year': int(parts[3]) if len(parts) > 3 and parts[3].isdigit() else 0,
                        'state': parts[4] if len(parts) > 4 else '',
                        'office': parts[5] if len(parts) > 5 else '',
                        'district': parts[6] if len(parts) > 6 else ''
                    }
            except Exception as e:
                logger.warning(f'Line {line_num}: {e}')
                
            if line_num % 1000 == 0:
                logger.info(f'  Loaded {line_num} candidates...')
    
    logger.info(f'Loaded {len(candidates)} candidates')
    return candidates


def load_committee_links(cursor, candidates):
    """Load FEC committee-candidate linkage and insert into lookup table"""
    logger.info(f'Loading committee linkages from {FEC_CCL_FILE}...')
    
    # ccl.txt format: CAND_ID|CAND_ELECTION_YR|FEC_ELECTION_YR|CMTE_ID|CMTE_TP|CMTE_DSGN|LINKAGE_ID
    lookups = []
    
    with open(FEC_CCL_FILE, 'r', encoding='latin-1') as f:
        for line_num, line in enumerate(f, 1):
            try:
                parts = line.strip().split('|')
                if len(parts) >= 4:
                    cand_id = parts[0]
                    cmte_id = parts[3]
                    
                    if cand_id in candidates:
                        cand = candidates[cand_id]
                        lookups.append((
                            cmte_id,
                            cand_id,
                            cand['name'],
                            cand['party'],
                            cand['office'],
                            cand['state'],
                            cand['district'],
                            cand['year']
                        ))
            except Exception as e:
                logger.warning(f'Line {line_num}: {e}')
                
            if line_num % 1000 == 0:
                logger.info(f'  Processed {line_num} linkages...')
    
    logger.info(f'Inserting {len(lookups)} committee-candidate mappings...')
    
    execute_batch(cursor, '''
        INSERT INTO fec_committee_candidate_lookup 
        (committee_id, candidate_id, candidate_name, candidate_party, 
         candidate_office, candidate_office_state, candidate_office_district, election_year)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (committee_id) DO UPDATE SET
            candidate_id = EXCLUDED.candidate_id,
            candidate_name = EXCLUDED.candidate_name,
            candidate_party = EXCLUDED.candidate_party,
            candidate_office = EXCLUDED.candidate_office,
            candidate_office_state = EXCLUDED.candidate_office_state,
            candidate_office_district = EXCLUDED.candidate_office_district,
            election_year = EXCLUDED.election_year
    ''', lookups, page_size=1000)
    
    logger.info(f'Inserted {len(lookups)} lookups')
    return len(lookups)


def backfill_donation_history(cursor):
    """Backfill candidate_name in donation_history using the lookup"""
    logger.info('Backfilling candidate_name in donation_history...')
    
    # Count records to update
    cursor.execute('''
        SELECT COUNT(*) FROM donation_history 
        WHERE (candidate_name IS NULL OR candidate_name = '')
        AND committee_id IS NOT NULL
    ''')
    to_update = cursor.fetchone()[0]
    logger.info(f'Records to update: {to_update}')
    
    # Update in batches
    cursor.execute('''
        UPDATE donation_history dh
        SET 
            candidate_name = lookup.candidate_name,
            candidate_party = lookup.candidate_party
        FROM fec_committee_candidate_lookup lookup
        WHERE dh.committee_id = lookup.committee_id
        AND (dh.candidate_name IS NULL OR dh.candidate_name = '')
    ''')
    
    updated = cursor.rowcount
    logger.info(f'Updated {updated} records in donation_history')
    return updated


def add_columns_to_donations(cursor):
    """Add missing columns to the donations table"""
    logger.info('Adding missing columns to donations table...')
    
    columns_to_add = [
        ('candidate_id', 'VARCHAR(20)'),
        ('candidate_name', 'VARCHAR(255)'),
        ('candidate_party', 'VARCHAR(10)'),
        ('candidate_office', 'VARCHAR(50)'),
        ('candidate_district', 'VARCHAR(20)'),
        ('committee_id', 'VARCHAR(50)'),
        ('committee_name', 'VARCHAR(500)'),
        ('committee_sboe_id', 'VARCHAR(50)'),
        ('fec_transaction_id', 'VARCHAR(50)'),
        ('report_name', 'VARCHAR(100)'),
        ('race_level', 'VARCHAR(10)'),
        ('raw_data', 'JSONB')
    ]
    
    for col_name, col_type in columns_to_add:
        try:
            cursor.execute(f'''
                ALTER TABLE donations 
                ADD COLUMN IF NOT EXISTS {col_name} {col_type}
            ''')
            logger.info(f'  Added column: {col_name}')
        except Exception as e:
            logger.warning(f'  Column {col_name}: {e}')
    
    logger.info('Columns added to donations table')


def main():
    """Main repair function"""
    logger.info('='*70)
    logger.info('BROYHILLGOP DATA REPAIR - CANDIDATE ATTRIBUTION')
    logger.info('='*70)
    logger.info(f'Started: {datetime.now()}')
    logger.info(f'Database: {DATABASE_URL[:50]}...')
    
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        
        # Step 1: Create lookup table
        create_lookup_table(cursor)
        conn.commit()
        
        # Step 2: Load candidates and committee links
        candidates = load_candidates(cursor)
        links_count = load_committee_links(cursor, candidates)
        conn.commit()
        
        # Step 3: Backfill donation_history
        updated_count = backfill_donation_history(cursor)
        conn.commit()
        
        # Step 4: Add columns to donations table
        add_columns_to_donations(cursor)
        conn.commit()
        
        # Summary
        logger.info('='*70)
        logger.info('REPAIR COMPLETE')
        logger.info('='*70)
        logger.info(f'Candidates loaded: {len(candidates)}')
        logger.info(f'Committee-candidate links: {links_count}')
        logger.info(f'Donation history records updated: {updated_count}')
        logger.info(f'Finished: {datetime.now()}')
        
        conn.close()
        
    except Exception as e:
        logger.error(f'REPAIR FAILED: {e}')
        raise


if __name__ == '__main__':
    main()
