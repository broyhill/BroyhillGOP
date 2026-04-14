#!/usr/bin/env python3
"""
Bulletproof NCBOE GOLD CSV loader — COPY FROM STDIN, no ORM, no batch bugs.
"""

import csv
import io
import os
import re
import sys
import time
import logging
from pathlib import Path
import psycopg2

DB_URL = "postgresql://postgres:Anamaria%402026%40@localhost:5432/postgres"
GOLD_DIR = Path("/data/ncboe/gold")
LOG_FILE = "/tmp/bulletproof_load.log"

EXPECTED = {
    "County-Municipal-100-counties-GOP-2015-2026.csv": 451483,
    "NC-House-Gop++-2015-2026.csv": 407499,
    "NC-Senate-Gop-2015-2026.csv": 321585,
    "sheriff-only-gop-100-counties.csv": 272481,
    "Judicial-gop-100-counties-2015-2026.csv": 170002,
    "2015-2026-supreme-court-appeals-.csv": 144143,
    "2015-2026-NC-Council-of-state.csv": 96363,
    "2ndary-counties-muni-cty-gop-2015-2026.csv": 96273,
    "governor-2015-2026.csv": 96093,
    "2ndary-sheriff-gop-2015-2026.csv": 75550,
    "District-ct-judge-gop-100-counties-2015-2026.csv": 64708,
    "Council-commissioners-gop-2015-2026.csv": 55965,
    "council-city-town-gop-2015-2026.csv": 51425,
    "District-Att-gop-100 counties-2015-2026.csv": 46069,
    "2015-2025-lt-governor.csv": 31793,
    "school-board-gop-2015-2026.csv": 25834,
    "2015-2026-Mayors.csv": 18281,
    "clerk-court-gop-2015-2026.csv": 5651,
}
TOTAL_EXPECTED = 2431198

CSV_TO_DB = [
    ("Name", "name"),
    ("Street Line 1", "street_line_1"),
    ("Street Line 2", "street_line_2"),
    ("City", "city"),
    ("State", "state"),
    ("Zip Code", "zip_code"),
    ("Profession/Job Title", "profession_job_title"),
    ("Employer's Name/Specific Field", "employer_name"),
    ("Transction Type", "transction_type"),
    ("Committee Name", "committee_name"),
    ("Committee SBoE ID", "committee_sboe_id"),
    ("Committee Street 1", "committee_street_1"),
    ("Committee Street 2", "committee_street_2"),
    ("Committee City", "committee_city"),
    ("Committee State", "committee_state"),
    ("Committee Zip Code", "committee_zip_code"),
    ("Report Name", "report_name"),
    ("Date Occured", "date_occured"),
    ("Account Code", "account_code"),
    ("Amount", "amount"),
    ("Form of Payment", "form_of_payment"),
    ("Purpose", "purpose"),
    ("Candidate/Referendum Name", "candidate_referendum_name"),
    ("Declaration", "declaration"),
]

DB_COLS = ["source_file"] + [db for _, db in CSV_TO_DB]
COLS_STR = ", ".join(DB_COLS)
COPY_SQL = f"COPY raw.ncboe_donations ({COLS_STR}) FROM STDIN WITH (FORMAT csv, DELIMITER ',', NULL '')"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, mode='w'),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("bulletproof")


def normalize_header(h):
    h = (h or "").replace("\ufeff", "").strip()
    h = h.replace("\u2018", "'").replace("\u2019", "'").replace("\u0060", "'")
    return h


def build_header_map(fieldnames):
    norm_to_idx = {}
    for i, fn in enumerate(fieldnames):
        norm_to_idx[normalize_header(fn)] = i
    result = {}
    for csv_name, db_name in CSV_TO_DB:
        norm = normalize_header(csv_name)
        if norm in norm_to_idx:
            result[db_name] = norm_to_idx[norm]
        else:
            log.warning("Header not found: %r", csv_name)
            result[db_name] = None
    return result


def csv_escape(v):
    """Escape a value for CSV format COPY."""
    if v is None or v == "":
        return ""
    # If it contains comma, quote, or newline — wrap in quotes and double any quotes
    if "," in v or '"' in v or "\n" in v or "\r" in v:
        return '"' + v.replace('"', '""') + '"'
    return v


def load_file(conn, filepath):
    fname = filepath.name
    log.info("Loading %s ...", fname)

    with filepath.open(newline="", encoding="utf-8-sig", errors="replace") as f:
        reader = csv.reader(f)
        header_row = next(reader)
        header_map = build_header_map(header_row)

        mapped = sum(1 for v in header_map.values() if v is not None)
        log.info("  Mapped %d/24 CSV columns", mapped)
        if mapped < 20:
            log.error("Too few columns mapped for %s — SKIPPING", fname)
            return 0

        row_count = 0
        chunk_size = 100000
        buf = io.StringIO()

        for row in reader:
            # Build CSV line: source_file, then each mapped column
            vals = [csv_escape(fname)]
            for _, db_col in CSV_TO_DB:
                idx = header_map.get(db_col)
                if idx is not None and idx < len(row):
                    val = row[idx].strip() if row[idx] else ""
                    vals.append(csv_escape(val))
                else:
                    vals.append("")
            buf.write(",".join(vals) + "\n")
            row_count += 1

            if row_count % chunk_size == 0:
                buf.seek(0)
                with conn.cursor() as cur:
                    cur.copy_expert(COPY_SQL, buf)
                conn.commit()
                buf = io.StringIO()
                log.info("  %s: %d rows committed...", fname, row_count)

        # Flush remaining
        if buf.tell() > 0:
            buf.seek(0)
            with conn.cursor() as cur:
                cur.copy_expert(COPY_SQL, buf)
            conn.commit()

    log.info("  %s: DONE — %d rows", fname, row_count)
    return row_count


def verify_counts(conn):
    log.info("=" * 60)
    log.info("VERIFICATION")
    log.info("=" * 60)
    
    with conn.cursor() as cur:
        cur.execute("""
            SELECT source_file, COUNT(*) as cnt
            FROM raw.ncboe_donations
            GROUP BY source_file
            ORDER BY cnt DESC
        """)
        rows = cur.fetchall()

    all_ok = True
    total = 0
    for source_file, cnt in rows:
        expected = EXPECTED.get(source_file, "???")
        match = "OK" if cnt == expected else f"MISMATCH (expected {expected})"
        if cnt != expected:
            all_ok = False
        log.info("  %-55s %8d  %s", source_file, cnt, match)
        total += cnt

    log.info("-" * 60)
    total_match = "OK" if total == TOTAL_EXPECTED else f"MISMATCH (expected {TOTAL_EXPECTED})"
    if total != TOTAL_EXPECTED:
        all_ok = False
    log.info("  TOTAL: %d  %s", total, total_match)
    return all_ok


def main():
    log.info("=" * 60)
    log.info("BULLETPROOF NCBOE GOLD LOADER — Attempt 3")
    log.info("=" * 60)

    conn = psycopg2.connect(DB_URL)
    conn.autocommit = False

    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM raw.ncboe_donations")
        existing = cur.fetchone()[0]
    
    if existing > 0:
        log.info("Table has %d rows — truncating...", existing)
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE raw.ncboe_donations")
        conn.commit()

    files = sorted(GOLD_DIR.glob("*.csv"))
    log.info("Found %d CSV files", len(files))

    grand_total = 0
    t0 = time.time()
    errors = []

    for fp in files:
        t1 = time.time()
        count = load_file(conn, fp)
        elapsed = time.time() - t1
        grand_total += count
        expected = EXPECTED.get(fp.name, "???")
        
        if count == expected:
            log.info("  => %s: %d rows in %.1fs  OK", fp.name, count, elapsed)
        else:
            log.error("  => %s: %d rows in %.1fs  MISMATCH (expected %s)", fp.name, count, elapsed, expected)
            errors.append(fp.name)

    total_elapsed = time.time() - t0
    log.info("=" * 60)
    log.info("LOAD COMPLETE: %d rows in %.1fs (%.0f rows/sec)", 
             grand_total, total_elapsed, grand_total / total_elapsed if total_elapsed > 0 else 0)

    ok = verify_counts(conn)
    
    if ok:
        log.info("ALL COUNTS VERIFIED — Phase 1 SUCCESSFUL")
    else:
        log.error("VERIFICATION FAILED — check mismatches above")
        if errors:
            log.error("Problem files: %s", errors)

    conn.close()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
