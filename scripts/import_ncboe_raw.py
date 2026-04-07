#!/usr/bin/env python3
"""
Import NCBOE CSV files into nc_boe_donations_raw. Replaces import_all_donations.py and unified_loader_v2.py.

Accepts individual file paths (NOT glob). Validates NCBOE schema before loading.
Correct name parsing: "LAST, FIRST" -> last=left of comma, first=right.
Handles both "Date Occured" and "Date Occurred". Handles $1,234.56 and 1234.56 amounts.
SHA-256 idempotency per file.

Usage:
  python scripts/import_ncboe_raw.py NCBOE-2015-2019.csv
  python scripts/import_ncboe_raw.py --dry-run NCBOE-2020-2026-part1.csv

Env:
  NCBOE_BATCH_SIZE — rows per commit during insert (default 2000, min 500).
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import logging
import os
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

_script_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(_script_dir))
load_dotenv(_script_dir.parent / ".env")

from db_conn import get_connection_url
from utils import parse_name_last_first, parse_amount, parse_date

# NCBOE schema signatures
NCBOE_SIGNATURE = {"Committee SBoE ID", "Date Occured"}
NCBOE_ALT = {"Committee SBoE ID", "Date Occurred"}


def _file_hash(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _detect_ncboe(headers: list[str]) -> bool:
    hset = {h.strip() for h in headers if h}
    return bool(NCBOE_SIGNATURE.issubset(hset) or NCBOE_ALT.issubset(hset))


def _get_col(row: dict, *keys: str) -> str:
    for k in keys:
        if k in row and row[k] is not None:
            v = str(row[k]).strip()
            return v
    # Case-insensitive fallback
    for rk, rv in row.items():
        if rk and rv is not None:
            for k in keys:
                if k.lower() in rk.lower():
                    return str(rv).strip()
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Import NCBOE CSV to nc_boe_donations_raw")
    parser.add_argument("file", type=Path, help="NCBOE CSV path (single file)")
    parser.add_argument("--dry-run", action="store_true", help="Validate only, no insert")
    parser.add_argument("--log-file", default="import_ncboe_raw.log", help="Log file")
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

    # utf-8-sig strips BOM from Excel-exported CSVs
    with open(args.file, newline="", encoding="utf-8-sig", errors="replace") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []
        if not _detect_ncboe(headers):
            logger.error("File is not NCBOE schema. Expected 'Committee SBoE ID' and 'Date Occured' or 'Date Occurred'.")
            return 1

    fhash = _file_hash(args.file)
    logger.info("File hash: %s", fhash[:16] + "...")

    if args.dry_run:
        rows = 0
        with open(args.file, newline="", encoding="utf-8-sig", errors="replace") as f:
            for _ in csv.DictReader(f):
                rows += 1
        logger.info("DRY RUN: %s rows, NCBOE schema OK, file=%s", rows, args.file.name)
        return 0

    conn = psycopg2.connect(get_connection_url())

    # Idempotency: SHA-256 file hash - reject if already loaded
    with conn.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS pipeline")
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS pipeline.loaded_ncboe_files (
                file_hash VARCHAR(64) PRIMARY KEY,
                source_file VARCHAR(255),
                loaded_at TIMESTAMPTZ DEFAULT now(),
                row_count INT
            )
            """
        )
        conn.commit()
        cur.execute("SELECT 1 FROM pipeline.loaded_ncboe_files WHERE file_hash = %s", (fhash,))
        if cur.fetchone():
            logger.warning("File already loaded (hash %s). Skipping.", fhash[:16] + "...")
            conn.close()
            return 0

    # Column name variants (NCBOE files may differ)
    with open(args.file, newline="", encoding="utf-8-sig", errors="replace") as f:
        reader = csv.DictReader(f)
        headers = list(reader.fieldnames or [])
    date_col = next((h for h in headers if "date occured" in h.lower() or "date occurred" in h.lower()), "Date Occured")
    amt_col = next((h for h in headers if "amount" in h.lower()), "Amount")
    contrib_col = next((h for h in headers if "contributor" in h.lower() or h.strip() == "Name"), "Contributor Name")
    txn_type_col = next((h for h in headers if "transction" in h.lower() or "transaction" in h.lower()), "Transction Type")

    try:
        BATCH_SIZE = max(500, int(os.environ.get("NCBOE_BATCH_SIZE", "2000")))
    except ValueError:
        BATCH_SIZE = 2000
    inserted = 0
    with open(args.file, newline="", encoding="utf-8-sig", errors="replace") as f:
        reader = csv.DictReader(f)
        with conn.cursor() as cur:
            for row in reader:
                donor_name_raw = _get_col(row, "Name", contrib_col, "Contributor Name", "contributor_name")
                last, first = parse_name_last_first(donor_name_raw)
                donor_name = donor_name_raw  # Store raw for audit

                transaction_type = _get_col(row, txn_type_col, "Transction Type", "Transaction Type") or "Individual"

                street1 = _get_col(row, "Street Line 1", "street_line_1", "Street 1")
                street2 = _get_col(row, "Street Line 2", "street_line_2", "Street 2")
                city = _get_col(row, "City", "city")
                state = _get_col(row, "State", "state")
                zip_code = _get_col(row, "Zip", "zip", "zip_code")
                committee_sboe = _get_col(row, "Committee SBoE ID", "committee_sboe_id")
                committee_name = _get_col(row, "Committee Name", "committee_name")
                date_raw = _get_col(row, date_col, "Date Occured", "Date Occurred")
                amount_raw = _get_col(row, amt_col, "Amount", "amount")
                purpose = _get_col(row, "Purpose", "purpose")
                form_payment = _get_col(row, "Form of Payment", "form_of_payment")
                profession = _get_col(row, "Profession/Job Title", "profession_job_title")
                employer = _get_col(row, "Employer Name", "employer_name", "Employer")

                amount_numeric = parse_amount(amount_raw)
                date_occurred = parse_date(date_raw)

                cur.execute(
                    """
                    INSERT INTO public.nc_boe_donations_raw
                    (donor_name, street_line_1, street_line_2, city, state, zip_code,
                     profession_job_title, employer_name, transaction_type, committee_name, committee_sboe_id,
                     date_occured_raw, amount_raw, amount_numeric, date_occurred, form_of_payment, purpose,
                     source_file, loaded_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now())
                    """,
                    (
                        donor_name or None,
                        street1 or None,
                        street2 or None,
                        city or None,
                        state or None,
                        zip_code or None,
                        profession or None,
                        employer or None,
                        transaction_type or "Individual",
                        committee_name or None,
                        committee_sboe or None,
                        date_raw or None,
                        amount_raw or None,
                        amount_numeric,
                        date_occurred.date() if date_occurred else None,
                        form_payment or None,
                        purpose or None,
                        args.file.name,
                    ),
                )
                inserted += 1
                if inserted % BATCH_SIZE == 0:
                    conn.commit()
                    logger.info("Committed batch: %s rows", inserted)

    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO pipeline.loaded_ncboe_files (file_hash, source_file, row_count) VALUES (%s, %s, %s)",
            (fhash, args.file.name, inserted),
        )
    conn.commit()
    logger.info("Inserted %s rows from %s", inserted, args.file.name)
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
