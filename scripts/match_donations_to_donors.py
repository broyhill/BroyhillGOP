#!/usr/bin/env python3
"""
BROYHILLGOP DONATION-TO-DONOR MATCHING
======================================
Created: January 19, 2026 (Autonomous Repair Session)
Protocol: METICULOUS EXECUTION MANDATE v2.0

This script matches donation records in donations_raw to donors using:
1. Exact name + zip match
2. First/Last name + city match
3. Email match (if available)

Updates matched_donor_id and match_method in donations_raw
"""

import os
import sys
import psycopg2
from psycopg2.extras import execute_batch, RealDictCursor
from datetime import datetime
import logging
import hashlib

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - MATCHING - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/broyhillgop/logs/match_donations_to_donors.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('matching')

# Load environment
from dotenv import load_dotenv
load_dotenv('/opt/broyhillgop/config/supabase.env')

DATABASE_URL = os.getenv('DATABASE_URL')


def normalize_name(name):
    """Normalize name for matching"""
    if not name:
        return ''
    return name.upper().strip().replace('.', '').replace(',', '')


def normalize_zip(zip_code):
    """Extract first 5 digits of zip"""
    if not zip_code:
        return ''
    digits = ''.join(c for c in str(zip_code) if c.isdigit())
    return digits[:5]


def match_donations_batch(batch_size=50000):
    """Match donations to donors in batches"""
    
    logger.info('='*70)
    logger.info('BROYHILLGOP DONATION-TO-DONOR MATCHING')
    logger.info('='*70)
    logger.info(f'Started: {datetime.now()}')
    
    conn = psycopg2.connect(DATABASE_URL)
    
    # Count unmatched donations
    cur = conn.cursor()
    cur.execute("""
        SELECT COUNT(*) FROM donations_raw 
        WHERE matched_donor_id IS NULL
    """)
    total_unmatched = cur.fetchone()[0]
    
    cur.execute("SELECT COUNT(*) FROM donations_raw")
    total_donations = cur.fetchone()[0]
    
    cur.execute("SELECT COUNT(*) FROM donors")
    total_donors = cur.fetchone()[0]
    
    logger.info(f'Total donations: {total_donations:,}')
    logger.info(f'Unmatched donations: {total_unmatched:,}')
    logger.info(f'Total donors: {total_donors:,}')
    
    # Method 1: Exact name + zip match
    logger.info('')
    logger.info('METHOD 1: Exact First/Last Name + ZIP Match')
    logger.info('-'*50)
    
    cur.execute("""
        WITH matched AS (
            SELECT dr.id as donation_id, d.id as donor_id
            FROM donations_raw dr
            INNER JOIN donors d ON (
                UPPER(TRIM(dr.first_name)) = UPPER(TRIM(d.first_name))
                AND UPPER(TRIM(dr.last_name)) = UPPER(TRIM(d.last_name))
                AND LEFT(REGEXP_REPLACE(dr.zip_code, '[^0-9]', '', 'g'), 5) = 
                    LEFT(REGEXP_REPLACE(d.zip_code, '[^0-9]', '', 'g'), 5)
            )
            WHERE dr.matched_donor_id IS NULL
            AND dr.first_name IS NOT NULL
            AND dr.last_name IS NOT NULL
            AND dr.zip_code IS NOT NULL
            AND d.first_name IS NOT NULL
            AND d.last_name IS NOT NULL
            AND d.zip_code IS NOT NULL
        )
        UPDATE donations_raw dr
        SET matched_donor_id = m.donor_id,
            match_method = 'name_zip_exact'
        FROM matched m
        WHERE dr.id = m.donation_id
    """)
    method1_count = cur.rowcount
    conn.commit()
    logger.info(f'  Matched {method1_count:,} donations via name+zip')
    
    # Method 2: Name + City match
    logger.info('')
    logger.info('METHOD 2: First/Last Name + City Match')
    logger.info('-'*50)
    
    cur.execute("""
        WITH matched AS (
            SELECT dr.id as donation_id, d.id as donor_id
            FROM donations_raw dr
            INNER JOIN donors d ON (
                UPPER(TRIM(dr.first_name)) = UPPER(TRIM(d.first_name))
                AND UPPER(TRIM(dr.last_name)) = UPPER(TRIM(d.last_name))
                AND UPPER(TRIM(dr.city)) = UPPER(TRIM(d.city))
            )
            WHERE dr.matched_donor_id IS NULL
            AND dr.first_name IS NOT NULL
            AND dr.last_name IS NOT NULL
            AND dr.city IS NOT NULL
            AND d.first_name IS NOT NULL
            AND d.last_name IS NOT NULL
            AND d.city IS NOT NULL
        )
        UPDATE donations_raw dr
        SET matched_donor_id = m.donor_id,
            match_method = 'name_city'
        FROM matched m
        WHERE dr.id = m.donation_id
    """)
    method2_count = cur.rowcount
    conn.commit()
    logger.info(f'  Matched {method2_count:,} donations via name+city')
    
    # Method 3: Email match
    logger.info('')
    logger.info('METHOD 3: Email Match')
    logger.info('-'*50)
    
    cur.execute("""
        WITH matched AS (
            SELECT dr.id as donation_id, d.id as donor_id
            FROM donations_raw dr
            INNER JOIN donors d ON (
                LOWER(TRIM(dr.email)) = LOWER(TRIM(d.email))
            )
            WHERE dr.matched_donor_id IS NULL
            AND dr.email IS NOT NULL
            AND dr.email != ''
            AND d.email IS NOT NULL
            AND d.email != ''
        )
        UPDATE donations_raw dr
        SET matched_donor_id = m.donor_id,
            match_method = 'email_exact'
        FROM matched m
        WHERE dr.id = m.donation_id
    """)
    method3_count = cur.rowcount
    conn.commit()
    logger.info(f'  Matched {method3_count:,} donations via email')
    
    # Method 4: Last name + ZIP fuzzy match (for different first name spellings)
    logger.info('')
    logger.info('METHOD 4: Last Name + ZIP + Same First Initial')
    logger.info('-'*50)
    
    cur.execute("""
        WITH matched AS (
            SELECT DISTINCT ON (dr.id) dr.id as donation_id, d.id as donor_id
            FROM donations_raw dr
            INNER JOIN donors d ON (
                UPPER(TRIM(dr.last_name)) = UPPER(TRIM(d.last_name))
                AND LEFT(REGEXP_REPLACE(dr.zip_code, '[^0-9]', '', 'g'), 5) = 
                    LEFT(REGEXP_REPLACE(d.zip_code, '[^0-9]', '', 'g'), 5)
                AND LEFT(UPPER(TRIM(dr.first_name)), 1) = LEFT(UPPER(TRIM(d.first_name)), 1)
            )
            WHERE dr.matched_donor_id IS NULL
            AND dr.first_name IS NOT NULL
            AND dr.last_name IS NOT NULL
            AND dr.zip_code IS NOT NULL
            AND d.first_name IS NOT NULL
            AND d.last_name IS NOT NULL
            AND d.zip_code IS NOT NULL
            ORDER BY dr.id, d.donation_total DESC NULLS LAST
        )
        UPDATE donations_raw dr
        SET matched_donor_id = m.donor_id,
            match_method = 'lastname_zip_initial'
        FROM matched m
        WHERE dr.id = m.donation_id
    """)
    method4_count = cur.rowcount
    conn.commit()
    logger.info(f'  Matched {method4_count:,} donations via lastname+zip+initial')
    
    # Final count
    cur.execute("""
        SELECT COUNT(*) FROM donations_raw 
        WHERE matched_donor_id IS NOT NULL
    """)
    total_matched = cur.fetchone()[0]
    
    cur.execute("""
        SELECT match_method, COUNT(*) as count
        FROM donations_raw
        WHERE matched_donor_id IS NOT NULL
        GROUP BY match_method
        ORDER BY count DESC
    """)
    match_distribution = cur.fetchall()
    
    # Summary
    logger.info('')
    logger.info('='*70)
    logger.info('MATCHING COMPLETE')
    logger.info('='*70)
    logger.info(f'Total donations: {total_donations:,}')
    logger.info(f'Total matched: {total_matched:,}')
    logger.info(f'Match rate: {100.0 * total_matched / total_donations:.2f}%')
    logger.info('')
    logger.info('This session matched:')
    logger.info(f'  Method 1 (name+zip): {method1_count:,}')
    logger.info(f'  Method 2 (name+city): {method2_count:,}')
    logger.info(f'  Method 3 (email): {method3_count:,}')
    logger.info(f'  Method 4 (lastname+zip+initial): {method4_count:,}')
    logger.info(f'  TOTAL NEW MATCHES: {method1_count + method2_count + method3_count + method4_count:,}')
    logger.info('')
    logger.info('Match method distribution:')
    for method, count in match_distribution:
        logger.info(f'  {method}: {count:,}')
    
    conn.close()
    logger.info(f'Finished: {datetime.now()}')


if __name__ == '__main__':
    match_donations_batch()
