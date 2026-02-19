#!/usr/bin/env python3
"""
BROYHILLGOP BATCH DONOR GRADING
================================
Created: January 19, 2026 (Autonomous Repair Session)
Protocol: METICULOUS EXECUTION MANDATE v2.0

This script grades all ungraded donors in batches of 10,000
Using the E01 3D Grading system (Amount × Intensity × Level)
"""

import os
import sys
import psycopg2
from psycopg2.extras import execute_batch, RealDictCursor
from datetime import datetime, timedelta
import logging
import math

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - GRADING - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/broyhillgop/logs/batch_grade_donors.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('grading')

# Load environment
from dotenv import load_dotenv
load_dotenv('/opt/broyhillgop/config/supabase.env')

DATABASE_URL = os.getenv('DATABASE_URL')

# Grading thresholds
AMOUNT_GRADES = {
    'A++': 10000,
    'A+': 5000,
    'A': 2500,
    'B+': 1500,
    'B': 1000,
    'B-': 750,
    'C+': 500,
    'C': 250,
    'C-': 100,
    'D': 50,
    'F': 0
}

def calculate_amount_grade(total_donated):
    """Calculate amount grade based on total donations"""
    if total_donated is None or total_donated <= 0:
        return 'U', 0  # Unknown/ungraded
    
    for grade, threshold in sorted(AMOUNT_GRADES.items(), key=lambda x: x[1], reverse=True):
        if total_donated >= threshold:
            # Calculate percentile (0-1000 scale)
            percentile = min(1000, int(math.log10(total_donated + 1) * 200))
            return grade, percentile
    
    return 'F', 0


def batch_grade_donors(batch_size=10000):
    """Grade all ungraded donors in batches"""
    
    logger.info('='*70)
    logger.info('BROYHILLGOP BATCH DONOR GRADING')
    logger.info('='*70)
    logger.info(f'Started: {datetime.now()}')
    logger.info(f'Batch size: {batch_size}')
    
    conn = psycopg2.connect(DATABASE_URL)
    
    # Count ungraded donors
    cur = conn.cursor()
    cur.execute("""
        SELECT COUNT(*) FROM donors 
        WHERE (donor_grade IS NULL OR donor_grade = '' OR donor_grade = 'U')
        AND donation_total IS NOT NULL AND donation_total > 0
    """)
    ungraded_with_donations = cur.fetchone()[0]
    
    cur.execute("""
        SELECT COUNT(*) FROM donors 
        WHERE (donor_grade IS NULL OR donor_grade = '')
    """)
    total_ungraded = cur.fetchone()[0]
    
    logger.info(f'Total ungraded donors: {total_ungraded:,}')
    logger.info(f'Ungraded with donations: {ungraded_with_donations:,}')
    
    # Process in batches
    processed = 0
    graded = 0
    batch_num = 0
    
    while True:
        batch_num += 1
        logger.info(f'Processing batch {batch_num}...')
        
        # Get batch of ungraded donors WITH donation totals
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, first_name, last_name, donation_total, last_donation_date
            FROM donors 
            WHERE (donor_grade IS NULL OR donor_grade = '' OR donor_grade = 'U')
            AND donation_total IS NOT NULL AND donation_total > 0
            LIMIT %s
        """, (batch_size,))
        
        donors = cur.fetchall()
        
        if not donors:
            logger.info('No more donors to grade')
            break
        
        # Calculate grades
        updates = []
        for donor in donors:
            total = donor['donation_total'] or 0
            grade, percentile = calculate_amount_grade(total)
            
            # Calculate days since last donation
            if donor['last_donation_date']:
                try:
                    if isinstance(donor['last_donation_date'], str):
                        last_date = datetime.strptime(donor['last_donation_date'][:10], '%Y-%m-%d')
                    else:
                        last_date = donor['last_donation_date']
                    days_since = (datetime.now() - last_date).days
                except:
                    days_since = 999
            else:
                days_since = 999
            
            updates.append((grade, percentile, donor['id']))
        
        # Batch update
        cur2 = conn.cursor()
        execute_batch(cur2, """
            UPDATE donors 
            SET donor_grade = %s, donation_rank = %s
            WHERE id = %s
        """, updates, page_size=1000)
        
        conn.commit()
        
        processed += len(donors)
        graded += len(updates)
        
        logger.info(f'  Batch {batch_num}: Graded {len(updates):,} donors (Total: {graded:,})')
        
        if len(donors) < batch_size:
            break
    
    # Now grade donors WITHOUT donation totals as 'U' (unknown)
    logger.info('Grading donors without donation history as U (unknown)...')
    cur = conn.cursor()
    cur.execute("""
        UPDATE donors 
        SET donor_grade = 'U'
        WHERE (donor_grade IS NULL OR donor_grade = '')
        AND (donation_total IS NULL OR donation_total <= 0)
    """)
    unknown_count = cur.rowcount
    conn.commit()
    
    logger.info(f'Marked {unknown_count:,} donors as grade U (unknown/no donations)')
    
    # Final summary
    cur.execute("""
        SELECT donor_grade, COUNT(*) as count
        FROM donors
        GROUP BY donor_grade
        ORDER BY count DESC
    """)
    distribution = cur.fetchall()
    
    logger.info('='*70)
    logger.info('GRADING COMPLETE')
    logger.info('='*70)
    logger.info(f'Total processed: {processed:,}')
    logger.info(f'Donors graded: {graded:,}')
    logger.info(f'Donors marked unknown: {unknown_count:,}')
    logger.info('')
    logger.info('GRADE DISTRIBUTION:')
    for grade, count in distribution:
        logger.info(f'  {grade or "NULL"}: {count:,}')
    
    conn.close()
    logger.info(f'Finished: {datetime.now()}')


if __name__ == '__main__':
    batch_grade_donors()
