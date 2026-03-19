#!/usr/bin/env python3
"""
BROYHILLGOP DONOR PERCENTILE ANALYSIS
======================================
Computes actual donation ranges from the database to derive donor tiers.
DO NOT use hardcoded tiers (A++=$10K, A+=$5K) — run this script first.

Output: Percentile boundaries and suggested grade tiers for campaign funnel logic.
Use: Different tiers drive different treatment (personal call vs mass email).
     $10K donor ≠ $4M donor — they must not get the same funnel.

Run: python3 scripts/analyze_donor_percentiles.py
     (Requires DATABASE_URL in env, e.g. from .env or supabase.env)
"""

import os
import sys
from decimal import Decimal

# Load env from common locations
for path in ['/opt/broyhillgop/config/supabase.env', '.env', '../.env']:
    if os.path.exists(path):
        try:
            from dotenv import load_dotenv
            load_dotenv(path)
            break
        except ImportError:
            pass

DATABASE_URL = os.getenv('DATABASE_URL') or os.getenv('SUPABASE_DB_URL')
if not DATABASE_URL:
    print("ERROR: Set DATABASE_URL or SUPABASE_DB_URL")
    sys.exit(1)

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("ERROR: pip install psycopg2-binary")
    sys.exit(1)


def run_query(conn, sql, params=None):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params or ())
        return cur.fetchall()


def run_scalar(conn, sql, params=None):
    with conn.cursor() as cur:
        cur.execute(sql, params or ())
        return cur.fetchone()[0]


def analyze_ncboe(conn):
    """Percentiles from nc_boe_donations_raw (NC state donations)."""
    # Check if view exists; fallback to raw aggregation
    has_view = run_scalar(conn, """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.views
            WHERE table_schema = 'public' AND table_name = 'vw_donor_analysis_consolidated'
        )
    """)
    if has_view:
        base_sql = """
            SELECT total_amount FROM vw_donor_analysis_consolidated
            WHERE total_amount IS NOT NULL AND total_amount > 0
        """
    else:
        base_sql = """
            SELECT SUM(amount_numeric) AS total_amount
            FROM public.nc_boe_donations_raw
            WHERE transaction_type = 'Individual'
              AND amount_numeric IS NOT NULL AND amount_numeric > 0
              AND date_occurred IS NOT NULL
            GROUP BY COALESCE(voter_ncid, md5(COALESCE(norm_last,'') || '|' || COALESCE(canonical_first,'') || '|' || COALESCE(norm_zip5,'')))
        """
    # Wrap for percentile
    sql = f"""
        WITH donor_totals AS ({base_sql})
        SELECT
            COUNT(*) AS donor_count,
            SUM(total_amount) AS total_dollars,
            percentile_cont(0.50) WITHIN GROUP (ORDER BY total_amount) AS p50,
            percentile_cont(0.75) WITHIN GROUP (ORDER BY total_amount) AS p75,
            percentile_cont(0.90) WITHIN GROUP (ORDER BY total_amount) AS p90,
            percentile_cont(0.95) WITHIN GROUP (ORDER BY total_amount) AS p95,
            percentile_cont(0.99) WITHIN GROUP (ORDER BY total_amount) AS p99,
            percentile_cont(0.995) WITHIN GROUP (ORDER BY total_amount) AS p99_5,
            percentile_cont(0.999) WITHIN GROUP (ORDER BY total_amount) AS p99_9,
            MIN(total_amount) AS min_amt,
            MAX(total_amount) AS max_amt
        FROM donor_totals
    """
    try:
        return run_query(conn, sql)[0], "NCBOE (NC state donations)"
    except Exception as e:
        return None, f"NCBOE failed: {e}"


def analyze_contribution_map(conn):
    """Percentiles from donor_contribution_map (FEC + NCBOE combined)."""
    # Discover amount column
    cols = run_query(conn, """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'donor_contribution_map'
    """)
    col_names = [r['column_name'] for r in cols]
    amt_col = None
    for c in ['amount', 'contribution_amount', 'total_amount']:
        if c in col_names:
            amt_col = c
            break
    if not amt_col:
        return None, "donor_contribution_map: no amount column found"
    sql = f"""
        WITH donor_totals AS (
            SELECT golden_record_id, SUM({amt_col}) AS total_amount
            FROM public.donor_contribution_map
            WHERE golden_record_id IS NOT NULL AND {amt_col} IS NOT NULL AND {amt_col} > 0
            GROUP BY golden_record_id
        )
        SELECT
            COUNT(*) AS donor_count,
            SUM(total_amount) AS total_dollars,
            percentile_cont(0.50) WITHIN GROUP (ORDER BY total_amount) AS p50,
            percentile_cont(0.75) WITHIN GROUP (ORDER BY total_amount) AS p75,
            percentile_cont(0.90) WITHIN GROUP (ORDER BY total_amount) AS p90,
            percentile_cont(0.95) WITHIN GROUP (ORDER BY total_amount) AS p95,
            percentile_cont(0.99) WITHIN GROUP (ORDER BY total_amount) AS p99,
            percentile_cont(0.995) WITHIN GROUP (ORDER BY total_amount) AS p99_5,
            percentile_cont(0.999) WITHIN GROUP (ORDER BY total_amount) AS p99_9,
            MIN(total_amount) AS min_amt,
            MAX(total_amount) AS max_amt
        FROM donor_totals
    """
    try:
        return run_query(conn, sql)[0], "donor_contribution_map (FEC+NCBOE)"
    except Exception as e:
        return None, f"donor_contribution_map failed: {e}"


def fmt(n):
    if n is None:
        return "N/A"
    if isinstance(n, Decimal):
        n = float(n)
    return f"${n:,.0f}" if n >= 100 else f"${n:,.2f}"


def suggest_tiers(row):
    """Suggest grade boundaries from percentiles. More tiers at top to separate $10K from $4M."""
    if not row or row.get('donor_count', 0) == 0:
        return []
    p50 = float(row.get('p50') or 0)
    p75 = float(row.get('p75') or 0)
    p90 = float(row.get('p90') or 0)
    p95 = float(row.get('p95') or 0)
    p99 = float(row.get('p99') or 0)
    p99_5 = float(row.get('p99_5') or 0)
    p99_9 = float(row.get('p99_9') or 0)
    max_amt = float(row.get('max_amt') or 0)
    # Data-driven tiers from percentiles. Top 0.1% (above p99_9) needs sub-tiers
    # to separate $10K from $4M — run top_donors query for finer breakdown
    tiers = [
        ('F', 0, p50, "Bottom half"),
        ('D', p50, p75, "50th–75th"),
        ('C-', p75, p90, "75th–90th"),
        ('C', p90, p95, "90th–95th"),
        ('C+', p95, p99, "95th–99th"),
        ('B-', p99, p99_5, "99th–99.5th"),
        ('B', p99_5, p99_9, "99.5th–99.9th"),
        ('B+', p99_9, max_amt, "Top 0.1% — SUBDIVIDE: $10K≠$4M"),
    ]
    return tiers


def main():
    print("=" * 70)
    print("BROYHILLGOP DONOR PERCENTILE ANALYSIS")
    print("=" * 70)
    print("Purpose: Derive donor tiers from actual data. $10K ≠ $4M — different funnel treatment.")
    print()

    conn = psycopg2.connect(DATABASE_URL)

    results = []
    # 1. NCBOE
    row, label = analyze_ncboe(conn)
    if row:
        results.append((label, row))
    else:
        print(f"Skip: {label}")

    # 2. donor_contribution_map (if exists)
    has_dcm = run_scalar(conn, """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = 'donor_contribution_map'
        )
    """)
    if has_dcm:
        row, label = analyze_contribution_map(conn)
        if row:
            results.append((label, row))
        else:
            print(f"Skip: {label}")

    if not results:
        print("No data sources available. Check nc_boe_donations_raw or donor_contribution_map.")
        sys.exit(1)

    for label, row in results:
        print("-" * 70)
        print(f"SOURCE: {label}")
        print("-" * 70)
        print(f"  Donors:      {row.get('donor_count', 0):,}")
        print(f"  Total $:     {fmt(row.get('total_dollars'))}")
        print(f"  Min:         {fmt(row.get('min_amt'))}")
        print(f"  Max:         {fmt(row.get('max_amt'))}")
        print()
        print("  PERCENTILES (total $ per donor over all time):")
        print(f"    50th: {fmt(row.get('p50'))}  75th: {fmt(row.get('p75'))}  90th: {fmt(row.get('p90'))}")
        print(f"    95th: {fmt(row.get('p95'))}  99th: {fmt(row.get('p99'))}  99.5th: {fmt(row.get('p99_5'))}  99.9th: {fmt(row.get('p99_9'))}")
        print()
        tiers = suggest_tiers(row)
        if tiers:
            print("  SUGGESTED TIER BOUNDARIES (use for campaign funnel logic):")
            for grade, lo, hi, desc in tiers:
                print(f"    {grade:3}: {fmt(lo):>12} – {fmt(hi):>12}  ({desc})")
        # Top 25 donors — shows spread ($10K vs $4M) for defining A/A+/A++ sub-tiers
        try:
            has_view = run_scalar(conn, """
                SELECT EXISTS (SELECT 1 FROM information_schema.views
                WHERE table_schema = 'public' AND table_name = 'vw_donor_analysis_consolidated')
            """)
            if has_view:
                top = run_query(conn, """
                    SELECT last_name, first_name, total_amount, donation_count
                    FROM vw_donor_analysis_consolidated
                    WHERE total_amount > 0
                    ORDER BY total_amount DESC
                    LIMIT 25
                """)
            else:
                top = run_query(conn, """
                    WITH t AS (
                        SELECT COALESCE(voter_ncid, md5(COALESCE(norm_last,'')||'|'||COALESCE(canonical_first,'')||'|'||COALESCE(norm_zip5,''))) AS k,
                               norm_last, canonical_first,
                               SUM(amount_numeric) AS total_amount, COUNT(*) AS donation_count
                        FROM public.nc_boe_donations_raw
                        WHERE transaction_type = 'Individual' AND amount_numeric > 0 AND date_occurred IS NOT NULL
                        GROUP BY 1,2,3
                    )
                    SELECT norm_last AS last_name, canonical_first AS first_name, total_amount, donation_count
                    FROM t ORDER BY total_amount DESC LIMIT 25
                """)
            if top:
                print()
                print("  TOP 25 DONORS (define A/A+/A++ sub-tiers from this spread):")
                for i, r in enumerate(top, 1):
                    name = f"{r.get('last_name') or ''}, {r.get('first_name') or ''}".strip(', ')
                    print(f"    {i:2}. {fmt(r.get('total_amount')):>12}  {name[:40]}")
        except Exception as e:
            print(f"  (Top donors query skipped: {e})")
        print()

    print("=" * 70)
    print("NEXT: Update batch_grade_donors.py AMOUNT_GRADES from these percentiles.")
    print("      Consider office-specific tiers (federal vs state vs judicial) when schema supports.")
    print("See: docs/DONOR_RANGES_AND_LIMITS_RULES.md")
    print("=" * 70)

    conn.close()


if __name__ == '__main__':
    main()
