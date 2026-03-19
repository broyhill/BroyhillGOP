#!/usr/bin/env python3
"""
Audit: Top 100 donors — home vs business address usage.

For each of the top 100 donors by total donation amount, classify each donation
as HOME (address matches voter registration) or BUSINESS (does not match).

Logic:
- Donor = grouped by (norm_last, canonical_first, COALESCE(name_suffix,''))
- Home = donation address matches nc_voters.res_street_address (when voter_ncid present)
- Business = donation address does NOT match voter registration
- Unknown = no voter_ncid (cannot compare)

Address match: normalized street (strip apt/suite) + zip5. Uses street_number when
available for stronger signal.

Usage:
  cd /Users/Broyhill/Desktop/BroyhillGOP-CURSOR
  python3 scripts/audit_top100_home_vs_business_address.py
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

# Add project root for pipeline imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pipeline.db import get_connection, init_pool


def normalize_addr(addr: str | None) -> str:
    """Normalize address for comparison: strip apt/suite, uppercase, collapse whitespace."""
    if not addr or not str(addr).strip():
        return ""
    s = str(addr).upper().strip()
    s = re.sub(r"\s*(APT|SUITE|#|UNIT|STE|FL)\s*.*$", "", s, flags=re.I)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def extract_street_number(addr: str | None) -> str | None:
    """Extract leading street number or PO Box number."""
    if not addr or not str(addr).strip():
        return None
    s = str(addr).strip().upper()
    # PO Box
    m = re.search(r"P\.?O\.?\s*BOX\s*(\d+)", s, re.I)
    if m:
        return m.group(1)
    # Leading digits
    m = re.match(r"^(\d+[A-Z]?)\s", s)
    if m:
        return m.group(1)
    return None


def run_audit() -> None:
    init_pool()

    with get_connection() as conn:
        with conn.cursor() as cur:
            # 1. Top 100 donors by total amount (Individual + General only)
            cur.execute("""
                SELECT
                    norm_last,
                    canonical_first,
                    COALESCE(name_suffix, '') AS name_suffix,
                    SUM(amount_numeric) AS total_amount,
                    COUNT(*) AS donation_count
                FROM public.nc_boe_donations_raw
                WHERE transaction_type IN ('Individual', 'General')
                  AND amount_numeric IS NOT NULL
                  AND amount_numeric > 0
                  AND norm_last IS NOT NULL
                  AND canonical_first IS NOT NULL
                GROUP BY norm_last, canonical_first, COALESCE(name_suffix, '')
                ORDER BY SUM(amount_numeric) DESC
                LIMIT 100
            """)
            top100 = cur.fetchall()

        if not top100:
            print("No donors found. Check nc_boe_donations_raw has data.")
            return

        print("=" * 80)
        print("TOP 100 DONORS — HOME vs BUSINESS ADDRESS AUDIT")
        print("=" * 80)
        print()

        total_home_amount = 0
        total_business_amount = 0
        total_unknown_amount = 0
        total_home_count = 0
        total_business_count = 0
        total_unknown_count = 0

        results = []

        for row in top100:
            norm_last, canonical_first, name_suffix, donor_total, donor_count = row
            donor_key = f"{norm_last}|{canonical_first}|{name_suffix}"

            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        d.id,
                        d.amount_numeric,
                        d.street_line_1,
                        d.norm_addr,
                        d.norm_zip5,
                        d.voter_ncid,
                        v.res_street_address AS voter_addr,
                        v.zip_code AS voter_zip
                    FROM public.nc_boe_donations_raw d
                    LEFT JOIN public.nc_voters v ON v.ncid = d.voter_ncid
                    WHERE d.norm_last = %s
                      AND d.canonical_first = %s
                      AND COALESCE(d.name_suffix, '') = %s
                      AND d.transaction_type IN ('Individual', 'General')
                      AND d.amount_numeric IS NOT NULL
                      AND d.amount_numeric > 0
                """, (norm_last, canonical_first, name_suffix))
                donations = cur.fetchall()

            home_amt = 0
            business_amt = 0
            unknown_amt = 0
            home_cnt = 0
            business_cnt = 0
            unknown_cnt = 0

            for d in donations:
                (_, amt, street1, norm_addr, norm_zip5, voter_ncid, voter_addr, voter_zip) = d
                amt = float(amt or 0)

                if not voter_ncid:
                    unknown_amt += amt
                    unknown_cnt += 1
                    continue

                # Compare donation address to voter registration (home)
                donor_norm = normalize_addr(street1 or norm_addr)
                voter_norm = normalize_addr(voter_addr)

                donor_num = extract_street_number(street1 or norm_addr)
                voter_num = extract_street_number(voter_addr)

                donor_zip5 = (norm_zip5 or "")[:5].strip() if norm_zip5 else ""
                voter_zip5 = (voter_zip or "")[:5].strip() if voter_zip else ""

                # Home = donation address matches voter registration address
                is_home = False
                if donor_norm and voter_norm:
                    if donor_norm == voter_norm:
                        is_home = True
                    elif donor_num and voter_num and donor_num == voter_num and donor_zip5 == voter_zip5:
                        is_home = True  # same street number + zip
                    elif donor_num and voter_num and donor_num == voter_num:
                        is_home = True  # same street number (strong signal)
                    elif len(donor_norm) >= 15 and len(voter_norm) >= 15:
                        if donor_norm[:25] == voter_norm[:25]:
                            is_home = True  # leading chars match (handles RD vs ROAD)
                        elif voter_norm in donor_norm or donor_norm in voter_norm:
                            is_home = True

                if is_home:
                    home_amt += amt
                    home_cnt += 1
                else:
                    business_amt += amt
                    business_cnt += 1

            total_home_amount += home_amt
            total_business_amount += business_amt
            total_unknown_amount += unknown_amt
            total_home_count += home_cnt
            total_business_count += business_cnt
            total_unknown_count += unknown_cnt

            display_name = f"{canonical_first} {norm_last}"
            if name_suffix:
                display_name += f" {name_suffix}"
            results.append({
                "name": display_name,
                "total": donor_total,
                "home_amt": home_amt,
                "business_amt": business_amt,
                "unknown_amt": unknown_amt,
                "home_cnt": home_cnt,
                "business_cnt": business_cnt,
                "unknown_cnt": unknown_cnt,
            })

        # Summary
        grand_total = total_home_amount + total_business_amount + total_unknown_amount
        print("SUMMARY (Top 100 donors)")
        print("-" * 60)
        print(f"  Home address donations:     ${total_home_amount:>15,.0f}  ({total_home_count:,} donations)")
        print(f"  Business address donations: ${total_business_amount:>15,.0f}  ({total_business_count:,} donations)")
        print(f"  Unknown (no voter match):   ${total_unknown_amount:>15,.0f}  ({total_unknown_count:,} donations)")
        print(f"  Grand total:                ${grand_total:>15,.0f}")
        print()
        if grand_total > 0:
            pct_home = 100 * total_home_amount / grand_total
            pct_business = 100 * total_business_amount / grand_total
            pct_unknown = 100 * total_unknown_amount / grand_total
            print(f"  Home:     {pct_home:>5.1f}% of amount")
            print(f"  Business: {pct_business:>5.1f}% of amount")
            print(f"  Unknown:  {pct_unknown:>5.1f}% of amount")
        print()

        # Top 20 detail
        print("TOP 20 DONORS — BREAKDOWN")
        print("-" * 80)
        for r in sorted(results, key=lambda x: -float(x["total"]))[:20]:
            t = float(r["total"])
            h = float(r["home_amt"])
            b = float(r["business_amt"])
            u = float(r["unknown_amt"])
            hp = 100 * h / t if t else 0
            bp = 100 * b / t if t else 0
            up = 100 * u / t if t else 0
            print(f"  {r['name'][:35]:<35} ${t:>12,.0f}  home:{hp:>5.1f}%  biz:{bp:>5.1f}%  unk:{up:>5.1f}%")

        # Write full results to CSV
        out_path = Path(__file__).parent.parent / "analysis" / "top100_home_vs_business_audit.csv"
        out_path.parent.mkdir(exist_ok=True)
        with open(out_path, "w") as f:
            f.write("donor_name,total_amount,home_amount,home_pct,business_amount,business_pct,unknown_amount,unknown_pct,home_count,business_count,unknown_count\n")
            for r in results:
                t = float(r["total"])
                hp = 100 * float(r["home_amt"]) / t if t else 0
                bp = 100 * float(r["business_amt"]) / t if t else 0
                up = 100 * float(r["unknown_amt"]) / t if t else 0
                f.write(f'"{r["name"]}",{t:.2f},{r["home_amt"]:.2f},{hp:.1f},{r["business_amt"]:.2f},{bp:.1f},{r["unknown_amt"]:.2f},{up:.1f},{r["home_cnt"]},{r["business_cnt"]},{r["unknown_cnt"]}\n')
        print()
        print(f"Full results written to {out_path}")


def main() -> int:
    run_audit()
    return 0


if __name__ == "__main__":
    sys.exit(main())
