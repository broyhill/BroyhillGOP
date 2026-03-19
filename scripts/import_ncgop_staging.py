#!/usr/bin/env python3
"""
Load NCGOP WinRed CSV into staging table. Isolated from NCBOE.

Schema: staging_ncgop_winred (public schema)
SHA-256 idempotency: reject if file_hash already loaded.

Usage:
  python scripts/import_ncgop_staging.py path/to/NCGOP_file.csv
  python scripts/import_ncgop_staging.py --dry-run path/to/file.csv
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import logging
import re
import sys
from datetime import datetime
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

_script_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(_script_dir))
load_dotenv(_script_dir.parent / ".env")

from db_conn import get_connection_url

STAGING_TABLE = "staging.ncgop_winred"

# NCGOP column mapping (header -> db column)
NCGOP_MAP = {
    "First Name": "first_name",
    "Last Name": "last_name",
    "Email": "email",
    "Phone": "phone",
    "Address": "address",
    "City": "city",
    "State": "state",
    "Zip": "zip5",
    "Employer": "employer",
    "Occupation": "occupation",
    "Amount": "amount",
    "Date": "contribution_date",
}

# Default column order when --no-header (WinRed export: First, Last, Email, Phone, Address, City, State, Zip, Amount, Date)
NO_HEADER_COLUMNS = [
    "first_name", "last_name", "email", "phone", "address",
    "city", "state", "zip5", "amount", "contribution_date",
]


def _create_table(conn) -> None:
    with conn.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS staging")
        cur.execute(f"""
            CREATE TABLE IF NOT EXISTS {STAGING_TABLE} (
                id SERIAL PRIMARY KEY,
                first_name VARCHAR(255),
                last_name VARCHAR(255),
                email VARCHAR(255),
                phone VARCHAR(50),
                address TEXT,
                city VARCHAR(100),
                state VARCHAR(10),
                zip5 VARCHAR(10),
                zip9 VARCHAR(15),
                employer VARCHAR(255),
                occupation VARCHAR(255),
                amount NUMERIC(12,2),
                contribution_date DATE,
                statevoterid VARCHAR(50),
                source_file VARCHAR(255),
                loaded_at TIMESTAMPTZ DEFAULT now(),
                file_hash VARCHAR(64) UNIQUE
            )
        """)


def _file_hash(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _parse_amount(val: str) -> float | None:
    if not val or not str(val).strip():
        return None
    s = str(val).strip().replace(",", "").replace("$", "")
    try:
        return float(s)
    except ValueError:
        return None


def _parse_date(val: str) -> datetime | None:
    if not val or not str(val).strip():
        return None
    s = str(val).strip()
    for fmt in ("%m/%d/%Y", "%Y-%m-%d", "%m/%d/%y"):
        try:
            return datetime.strptime(s[:10] if len(s) > 10 else s, fmt)
        except ValueError:
            continue
    m = re.match(r"(\d{1,2})/(\d{1,2})/(\d{2,4})", s)
    if m:
        mm, dd, yy = m.groups()
        y = int(yy) if len(yy) == 4 else (2000 + int(yy) if int(yy) < 100 else 1900 + int(yy))
        return datetime(y, int(mm), int(dd))
    return None


def _zip5(val: str) -> str:
    if not val:
        return ""
    digits = re.sub(r"\D", "", str(val))
    return digits[:5] if digits else ""


def _zip9(val: str) -> str:
    if not val:
        return ""
    digits = re.sub(r"\D", "", str(val))
    return digits[:9] if len(digits) >= 9 else digits[:5] if digits else ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Import NCGOP WinRed CSV to staging")
    parser.add_argument("file", type=Path, help="NCGOP CSV path")
    parser.add_argument("--dry-run", action="store_true", help="Print what would run, no writes")
    parser.add_argument("--no-header", action="store_true", help="File has no header row; use default column order")
    parser.add_argument("--encoding", default="utf-8", help="File encoding (default: utf-8, use latin-1 for WinRed)")
    parser.add_argument("--log-file", default="import_ncgop_staging.log", help="Log file")
    args = parser.parse_args()

    log_path = Path(args.log_file)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(log_path), logging.StreamHandler(sys.stdout)],
    )
    logger = logging.getLogger(__name__)

    if not args.file.exists():
        logger.error("File not found: %s", args.file)
        return 1

    fhash = _file_hash(args.file)
    logger.info("File hash: %s", fhash)

    conn = psycopg2.connect(get_connection_url())
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM information_schema.tables WHERE table_schema='staging' AND table_name='ncgop_winred'"
            )
            if not cur.fetchone():
                _create_table(conn)
                conn.commit()
            cur.execute("SELECT 1 FROM staging.ncgop_winred WHERE file_hash = %s", (fhash,))
            if cur.fetchone():
                logger.warning("File already loaded (hash %s). Skipping.", fhash[:16])
                conn.close()
                return 0
    except psycopg2.ProgrammingError as e:
        conn.rollback()
        if "does not exist" in str(e):
            _create_table(conn)
            conn.commit()
        else:
            raise

    if args.dry_run:
        logger.info("DRY RUN: Would load %s into %s", args.file, STAGING_TABLE)
        rows = 0
        with open(args.file, newline="", encoding=args.encoding, errors="replace") as f:
            if args.no_header:
                for _ in csv.reader(f):
                    rows += 1
            else:
                for _ in csv.DictReader(f):
                    rows += 1
        logger.info("DRY RUN: Would insert %s rows", rows)
        conn.close()
        return 0

    BATCH_SIZE = 2000
    rows_inserted = 0

    def _row_to_values(row: dict) -> tuple:
        first = (row.get("First Name") or row.get("first_name") or "").strip()
        last = (row.get("Last Name") or row.get("last_name") or "").strip()
        email = (row.get("Email") or row.get("email") or "").strip()
        phone = (row.get("Phone") or row.get("phone") or "").strip()
        addr = (row.get("Address") or row.get("address") or "").strip()
        city = (row.get("City") or row.get("city") or "").strip()
        state = (row.get("State") or row.get("state") or "").strip()
        zipval = (row.get("Zip") or row.get("zip") or row.get("zip5") or "").strip()
        employer = (row.get("Employer") or row.get("employer") or "").strip()
        occ = (row.get("Occupation") or row.get("occupation") or "").strip()
        amt_raw = row.get("Amount") or row.get("amount") or row.get("contribution_amount") or ""
        date_raw = row.get("Date") or row.get("date") or row.get("contribution_date") or ""
        amount = _parse_amount(amt_raw)
        cdate = _parse_date(date_raw)
        zip5 = _zip5(zipval)
        zip9 = _zip9(zipval)
        return (first or None, last or None, email or None, phone or None, addr or None,
                city or None, state or None, zip5 or None, zip9 or None, employer or None,
                occ or None, amount, cdate.date() if cdate else None)

    with open(args.file, newline="", encoding=args.encoding, errors="replace") as f:
        if args.no_header:
            reader = csv.reader(f)
            rows_iter = (dict(zip(NO_HEADER_COLUMNS, row)) if len(row) >= len(NO_HEADER_COLUMNS) else dict(zip(NO_HEADER_COLUMNS[: len(row)], row)) for row in reader)
        else:
            rows_iter = csv.DictReader(f)

        with conn.cursor() as cur:
            for row in rows_iter:
                first, last, email, phone, addr, city, state, zip5, zip9, employer, occ, amount, cdate = _row_to_values(row)
                cur.execute(
                    """
                    INSERT INTO staging.ncgop_winred
                    (first_name, last_name, email, phone, address, city, state, zip5, zip9,
                     employer, occupation, amount, contribution_date, source_file, file_hash)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (first, last, email, phone, addr, city, state, zip5, zip9, employer, occ, amount, cdate, args.file.name, fhash),
                )
                rows_inserted += 1
                if rows_inserted % BATCH_SIZE == 0:
                    conn.commit()
                    logger.info("Committed batch: %s rows", rows_inserted)

    conn.commit()
    logger.info("Inserted %s rows from %s", rows_inserted, args.file.name)
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
