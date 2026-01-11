#!/usr/bin/env python3
"""
FEC/NCBOE Scraper Verification Script
BroyhillGOP Platform

Verifies scraped data and generates required statistics report.
Run this after scraping is complete.

Author: BroyhillGOP Platform
Created: January 11, 2026
"""

import os
import json
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

# Supabase Configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-0-us-east-1.pooler.supabase.com:6543/postgres")

def get_db_connection():
    return psycopg2.connect(SUPABASE_URL)

def run_verification():
    """Run all verification queries and generate report"""
    
    print("=" * 60)
    print("FEC/NCBOE SCRAPER VERIFICATION REPORT")
    print(f"Generated: {datetime.now().isoformat()}")
    print("=" * 60)
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    # 1. Total unique donors
    print("\n[1] TOTAL UNIQUE DONORS")
    cur.execute("SELECT COUNT(DISTINCT donor_id) as unique_donors FROM donors")
    result = cur.fetchone()
    print(f"    Unique Donors: {result['unique_donors']:,}")
    
    # 2. Total donation transactions
    print("\n[2] TOTAL DONATION TRANSACTIONS (10 years)")
    cur.execute("SELECT COUNT(*) as total_transactions FROM donations")
    result = cur.fetchone()
    print(f"    Total Transactions: {result['total_transactions']:,}")
    
    # 3. Federal candidates covered
    print("\n[3] FEDERAL CANDIDATES COVERED")
    cur.execute("""
        SELECT COUNT(DISTINCT candidate_id) as federal_candidates 
        FROM donations WHERE race_level = 'Federal'
    """)
    result = cur.fetchone()
    print(f"    Federal Candidates: {result['federal_candidates']:,}")
    
    # 4. State candidates covered
    print("\n[4] STATE CANDIDATES COVERED")
    cur.execute("""
        SELECT COUNT(DISTINCT candidate_id) as state_candidates 
        FROM donations WHERE race_level = 'State'
    """)
    result = cur.fetchone()
    print(f"    State Candidates: {result['state_candidates']:,}")
    
    # 5. Local candidates covered
    print("\n[5] LOCAL CANDIDATES COVERED")
    cur.execute("""
        SELECT COUNT(DISTINCT candidate_id) as local_candidates 
        FROM donations WHERE race_level = 'Local'
    """)
    result = cur.fetchone()
    print(f"    Local Candidates: {result['local_candidates']:,}")
    
    # 6. Date range verification
    print("\n[6] DATE RANGE VERIFICATION")
    cur.execute("""
        SELECT MIN(donation_date) as oldest, MAX(donation_date) as newest 
        FROM donations
    """)
    result = cur.fetchone()
    print(f"    Oldest: {result['oldest']}")
    print(f"    Newest: {result['newest']}")
    
    # 7. Party breakdown - CRITICAL CHECK
    print("\n[7] PARTY BREAKDOWN (MUST BE 100% REPUBLICAN)")
    cur.execute("""
        SELECT candidate_party, COUNT(*) as count
        FROM donations 
        GROUP BY candidate_party
        ORDER BY count DESC
    """)
    results = cur.fetchall()
    
    total = sum(r['count'] for r in results)
    rep_count = sum(r['count'] for r in results if r['candidate_party'] == 'REP')
    
    for r in results:
        pct = (r['count'] / total * 100) if total > 0 else 0
        status = "✅" if r['candidate_party'] == 'REP' else "❌ ERROR!"
        print(f"    {status} {r['candidate_party']}: {r['count']:,} ({pct:.1f}%)")
    
    if rep_count != total:
        print(f"\n    ⚠️  WARNING: Found non-Republican donations!")
        print(f"    Run: DELETE FROM donations WHERE candidate_party != 'REP'")
    else:
        print(f"\n    ✅ VERIFIED: 100% Republican donations")
    
    # 8. Top 20 federal candidates
    print("\n[8] TOP 20 FEDERAL CANDIDATES BY DONATION COUNT")
    cur.execute("""
        SELECT candidate_name, COUNT(*) as donation_count, SUM(amount) as total_raised
        FROM donations 
        WHERE race_level = 'Federal'
        GROUP BY candidate_name 
        ORDER BY donation_count DESC 
        LIMIT 20
    """)
    results = cur.fetchall()
    
    print(f"    {'#':<4} {'Candidate':<40} {'Donations':>12} {'Total Raised':>15}")
    print("    " + "-" * 75)
    for i, r in enumerate(results, 1):
        total_raised = r['total_raised'] or 0
        print(f"    {i:<4} {r['candidate_name'][:38]:<40} {r['donation_count']:>12,} ${total_raised:>14,.2f}")
    
    # 9. By source
    print("\n[9] DONATIONS BY SOURCE")
    cur.execute("""
        SELECT source, COUNT(*) as count, SUM(amount) as total
        FROM donations 
        GROUP BY source
        ORDER BY count DESC
    """)
    results = cur.fetchall()
    for r in results:
        total = r['total'] or 0
        print(f"    {r['source']}: {r['count']:,} donations, ${total:,.2f} total")
    
    # 10. By election cycle
    print("\n[10] DONATIONS BY ELECTION CYCLE")
    cur.execute("""
        SELECT election_cycle, COUNT(*) as count, SUM(amount) as total
        FROM donations 
        GROUP BY election_cycle
        ORDER BY election_cycle
    """)
    results = cur.fetchall()
    for r in results:
        total = r['total'] or 0
        print(f"    {r['election_cycle']}: {r['count']:,} donations, ${total:,.2f}")
    
    # 11. Enrichment status
    print("\n[11] DONOR ENRICHMENT STATUS")
    cur.execute("""
        SELECT 
            COUNT(*) as total_donors,
            COUNT(email) as has_email,
            COUNT(phone) as has_phone,
            COUNT(CASE WHEN apollo_data IS NOT NULL THEN 1 END) as has_apollo
        FROM donors
    """)
    result = cur.fetchone()
    print(f"    Total Donors: {result['total_donors']:,}")
    print(f"    With Email: {result['has_email']:,} ({result['has_email']/result['total_donors']*100:.1f}%)")
    print(f"    With Phone: {result['has_phone']:,} ({result['has_phone']/result['total_donors']*100:.1f}%)")
    print(f"    With Apollo Data: {result['has_apollo']:,}")
    
    # 12. Progress files status
    print("\n[12] SCRAPER PROGRESS STATUS")
    
    for name, path in [('FEC', '/root/fec_progress.json'), ('NCBOE', '/root/ncboe_progress.json')]:
        if os.path.exists(path):
            with open(path) as f:
                progress = json.load(f)
            print(f"    {name}:")
            print(f"      Records: {progress.get('records_scraped', 'N/A'):,}")
            print(f"      Last Update: {progress.get('timestamp', 'N/A')}")
            print(f"      Status: {progress.get('last_candidate_id', 'N/A')}")
        else:
            print(f"    {name}: Progress file not found")
    
    conn.close()
    
    print("\n" + "=" * 60)
    print("VERIFICATION COMPLETE")
    print("=" * 60)

if __name__ == "__main__":
    run_verification()
