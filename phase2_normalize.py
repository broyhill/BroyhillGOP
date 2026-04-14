#!/usr/bin/env python3
"""Phase 2: Normalize raw.ncboe_donations using ID-range batching."""

import sys
import re
import time
import logging
from decimal import Decimal, InvalidOperation
from datetime import datetime

sys.path.insert(0, "/opt/broyhillgop")
import psycopg2
from psycopg2.extras import execute_batch

from pipeline.ncboe_name_parser import parse_ncboe_gold_name
from pipeline.address_number_extractor import extract_address_numbers
from pipeline.employer_normalizer import normalize_employer_text

DB_URL = "postgresql://postgres:Anamaria%402026%40@localhost:5432/postgres"
BATCH_SIZE = 5000

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler("/tmp/phase2_normalize.log", mode='w'),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("phase2")


def norm_zip5(z):
    if not z: return None
    digits = re.sub(r"\D", "", str(z))
    return digits[:5] if digits else None

def norm_city(c):
    if not c or not str(c).strip(): return None
    return str(c).strip().upper()

def parse_amount(a):
    if not a or not str(a).strip(): return None
    s = str(a).strip().replace("$", "").replace(",", "")
    try: return Decimal(s)
    except: return None

def parse_date(s):
    if not s or not str(s).strip(): return None, None
    raw = str(s).strip()
    for fmt in ("%m/%d/%Y", "%m/%d/%y", "%Y-%m-%d", "%m-%d-%Y"):
        try:
            dt = datetime.strptime(raw, fmt)
            return dt.date(), dt.year
        except ValueError: continue
    return None, None


UPDATE_SQL = """
UPDATE raw.ncboe_donations SET
    norm_prefix=%(norm_prefix)s, norm_first=%(norm_first)s, norm_middle=%(norm_middle)s,
    norm_nickname=%(norm_nickname)s, norm_last=%(norm_last)s, norm_suffix=%(norm_suffix)s,
    is_unitemized=%(is_unitemized)s, norm_zip5=%(norm_zip5)s, norm_city=%(norm_city)s,
    norm_employer=%(norm_employer)s, norm_amount=%(norm_amount)s, norm_date=%(norm_date)s,
    year_donated=%(year_donated)s, address_numbers=%(address_numbers)s, all_addresses=%(all_addresses)s
WHERE id=%(id)s
"""


def process_row(row):
    rid, name, zip_code, city, employer_name, amount, date_occured, street1, street2, state = row
    parsed = parse_ncboe_gold_name(name)
    na = parse_amount(amount)
    nd, yr = parse_date(date_occured)
    addr_nums = extract_address_numbers(street1, street2)
    parts = [p for p in (street1, street2, city, state, zip_code) if p and str(p).strip()]
    all_addrs = [" ".join(parts)] if parts else []
    return {
        "id": rid,
        "norm_prefix": parsed.prefix, "norm_first": parsed.first, "norm_middle": parsed.middle,
        "norm_nickname": parsed.nickname, "norm_last": parsed.last, "norm_suffix": parsed.suffix,
        "is_unitemized": parsed.is_unitemized, "norm_zip5": norm_zip5(zip_code),
        "norm_city": norm_city(city), "norm_employer": normalize_employer_text(employer_name),
        "norm_amount": na, "norm_date": nd, "year_donated": yr,
        "address_numbers": addr_nums if addr_nums else None,
        "all_addresses": all_addrs if all_addrs else None,
    }


def main():
    log.info("=" * 60)
    log.info("Phase 2: NORMALIZATION")
    log.info("=" * 60)

    conn = psycopg2.connect(DB_URL)
    
    cur = conn.cursor()
    cur.execute("SELECT MIN(id), MAX(id), COUNT(*) FROM raw.ncboe_donations")
    min_id, max_id, total = cur.fetchone()
    log.info("ID range: %d to %d, total: %d", min_id, max_id, total)
    cur.close()

    processed = 0
    t0 = time.time()
    current_id = min_id

    while current_id <= max_id:
        end_id = current_id + BATCH_SIZE
        
        cur = conn.cursor()
        cur.execute("""
            SELECT id, name, zip_code, city, employer_name, amount, 
                   date_occured, street_line_1, street_line_2, state
            FROM raw.ncboe_donations
            WHERE id >= %s AND id < %s
        """, (current_id, end_id))
        rows = cur.fetchall()
        cur.close()

        if rows:
            updates = [process_row(r) for r in rows]
            cur = conn.cursor()
            execute_batch(cur, UPDATE_SQL, updates, page_size=1000)
            cur.close()
            conn.commit()
            processed += len(rows)

        current_id = end_id

        if processed % 50000 < BATCH_SIZE and processed > 0:
            elapsed = time.time() - t0
            rate = processed / elapsed if elapsed > 0 else 0
            pct = processed / total * 100
            eta = (total - processed) / rate if rate > 0 else 0
            log.info("  %d / %d (%.1f%%) — %.0f rows/sec — ETA %.0fs",
                     processed, total, pct, rate, eta)

    total_time = time.time() - t0
    log.info("=" * 60)
    log.info("DONE: %d rows in %.1fs (%.0f rows/sec)",
             processed, total_time, processed / total_time if total_time > 0 else 0)

    # Verify
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM raw.ncboe_donations WHERE norm_first IS NOT NULL OR is_unitemized = true")
    normed = cur.fetchone()[0]
    log.info("Normalized: %d / %d", normed, total)

    # ED check
    cur.execute("""
        SELECT name, norm_first, norm_last FROM raw.ncboe_donations 
        WHERE UPPER(name) LIKE '%%BROYHILL%%' LIMIT 5
    """)
    for r in cur.fetchall():
        log.info("  BROYHILL: %s", r)
    cur.close()

    conn.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())
