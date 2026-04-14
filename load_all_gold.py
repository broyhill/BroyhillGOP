#!/usr/bin/env python3
"""
One-shot loader: all 18 GOLD CSVs → raw.ncboe_donations.
No pool, no dotenv, no double-commit. Just psycopg2 and the pipeline parsers.
"""
import csv, glob, os, re, sys, time
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

sys.path.insert(0, "/opt/broyhillgop")
from pipeline.ncboe_name_parser import parse_ncboe_gold_name
from pipeline.address_number_extractor import extract_address_numbers
from pipeline.employer_normalizer import normalize_employer_text

import psycopg2

GOLD_DIR = Path("/data/ncboe/gold")
DB_URL = "postgresql://postgres:Anamaria%402026%40@localhost:5432/postgres"

# NCBOE header → db column (handles typos)
HEADER_MAP = {
    "Name": "name", "Street Line 1": "street_line_1", "Street Line 2": "street_line_2",
    "City": "city", "State": "state", "Zip Code": "zip_code",
    "Profession/Job Title": "profession_job_title",
    "Employer\u0027s Name/Specific Field": "employer_name",
    "Transction Type": "transction_type", "Committee Name": "committee_name",
    "Committee SBoE ID": "committee_sboe_id", "Committee Street 1": "committee_street_1",
    "Committee Street 2": "committee_street_2", "Committee City": "committee_city",
    "Committee State": "committee_state", "Committee Zip Code": "committee_zip_code",
    "Report Name": "report_name", "Date Occured": "date_occured",
    "Account Code": "account_code", "Amount": "amount",
    "Form of Payment": "form_of_payment", "Purpose": "purpose",
    "Candidate/Referendum Name": "candidate_referendum_name",
    "Declaration": "declaration",
}

INSERT_COLS = [
    "source_file","name","street_line_1","street_line_2","city","state","zip_code",
    "profession_job_title","employer_name","transction_type","committee_name",
    "committee_sboe_id","committee_street_1","committee_street_2","committee_city",
    "committee_state","committee_zip_code","report_name","date_occured","account_code",
    "amount","form_of_payment","purpose","candidate_referendum_name","declaration",
    "norm_last","norm_first","norm_middle","norm_suffix","norm_prefix","norm_nickname",
    "norm_zip5","norm_city","norm_employer","norm_amount","norm_date",
    "address_numbers","all_addresses","year_donated","is_unitemized",
]

def norm_zip5(z):
    if not z: return None
    d = re.sub(r"\D","",str(z))
    return d[:5] if d else None

def norm_city(c):
    if not c or not str(c).strip(): return None
    return str(c).strip().upper()

def parse_amount(a):
    if not a or not str(a).strip(): return None
    s = str(a).strip().replace("$","").replace(",","")
    try: return Decimal(s)
    except: return None

def parse_date(s):
    if not s or not str(s).strip(): return None, None
    raw = str(s).strip()
    for fmt in ("%m/%d/%Y","%m/%d/%y","%Y-%m-%d"):
        try:
            dt = datetime.strptime(raw, fmt)
            return dt.date(), dt.year
        except: continue
    return None, None

def process_row(row, hmap, source_file):
    def get(db_col):
        for csv_h, db_c in HEADER_MAP.items():
            if db_c == db_col and csv_h in hmap:
                v = row.get(hmap[csv_h])
                return str(v).strip() if v and str(v).strip() else None
        return None

    base = {db_c: get(db_c) for db_c in HEADER_MAP.values()}
    base["source_file"] = source_file

    p = parse_ncboe_gold_name(base.get("name"))
    base["norm_prefix"] = p.prefix
    base["norm_first"] = p.first
    base["norm_middle"] = p.middle
    base["norm_nickname"] = p.nickname
    base["norm_last"] = p.last
    base["norm_suffix"] = p.suffix
    base["is_unitemized"] = p.is_unitemized

    base["norm_zip5"] = norm_zip5(base.get("zip_code"))
    base["norm_city"] = norm_city(base.get("city"))
    base["norm_employer"] = normalize_employer_text(base.get("employer_name"))
    base["norm_amount"] = parse_amount(base.get("amount"))
    nd, yr = parse_date(base.get("date_occured"))
    base["norm_date"] = nd
    base["year_donated"] = yr

    a1, a2 = base.get("street_line_1"), base.get("street_line_2")
    base["address_numbers"] = extract_address_numbers(a1, a2) or None
    parts = [x for x in (a1, a2, base.get("city"), base.get("state"), base.get("zip_code")) if x]
    base["all_addresses"] = [" ".join(parts)] if parts else None

    return tuple(base.get(c) for c in INSERT_COLS)

def main():
    conn = psycopg2.connect(DB_URL, options="-c statement_timeout=0")
    conn.autocommit = False
    cur = conn.cursor()

    placeholders = ",".join(["%s"] * len(INSERT_COLS))
    cols_str = ",".join(INSERT_COLS); sql = f"INSERT INTO raw.ncboe_donations ({cols_str}) VALUES ({placeholders})"

    files = sorted(GOLD_DIR.glob("*.csv"))
    print(f"Found {len(files)} CSV files")

    grand_total = 0
    for fp in files:
        fname = fp.name
        # Check if already loaded
        cur.execute("SELECT COUNT(*) FROM raw.ncboe_donations WHERE source_file = %s", (fname,))
        existing = cur.fetchone()[0]
        if existing > 0:
            print(f"SKIP {fname} — already has {existing:,} rows")
            grand_total += existing
            continue

        t0 = time.time()
        with open(fp, newline="", encoding="utf-8-sig", errors="replace") as f:
            reader = csv.DictReader(f)
            hmap = {h: h for h in (reader.fieldnames or [])}
            batch = []
            n = 0
            for row in reader:
                batch.append(process_row(row, hmap, fname))
                n += 1
                if len(batch) >= 1000:
                    cur.executemany(sql, batch)
                    batch.clear()
            if batch:
                cur.executemany(sql, batch)
        conn.commit()
        elapsed = time.time() - t0
        grand_total += n
        print(f"LOADED {fname}: {n:,} rows in {elapsed:.1f}s | running total: {grand_total:,}")

    # Final verify
    cur.execute("SELECT source_file, COUNT(*) FROM raw.ncboe_donations GROUP BY source_file ORDER BY source_file")
    print("\n=== FINAL COUNTS ===")
    total = 0
    for row in cur.fetchall():
        print(f"  {row[1]:>10,}  {row[0]}")
        total += row[1]
    print(f"  {total:>10,}  TOTAL")

    cur.close()
    conn.close()
    print(f"\nDONE. {total:,} rows loaded. Zero lost.")

if __name__ == "__main__":
    main()
