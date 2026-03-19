#!/usr/bin/env python3
"""
Load General Fund CSVs into staging.staging_general_fund.
Handles quoted commas and variable-length rows that psql COPY cannot parse.
Run from project root. Requires staging.staging_general_fund to exist.
"""
from __future__ import annotations

import csv
import io
import os
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

Path(__file__).resolve().parent
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

# CSV column order (matches NC BOE TransInq format)
COLS = [
    "donor_name", "street_line_1", "street_line_2", "city", "state", "zip_code",
    "profession_job_title", "employer_name", "transaction_type", "committee_name",
    "committee_sboe_id", "committee_street_1", "committee_street_2",
    "committee_city", "committee_state", "committee_zip_code", "report_name",
    "date_occured_raw", "account_code", "amount_raw", "form_of_payment", "purpose",
    "candidate_referendum_name", "declaration",
]

# CSV header -> our column name (exact match from CSV)
CSV_TO_COL = {
    "Name": "donor_name",
    "Street Line 1": "street_line_1",
    "Street Line 2": "street_line_2",
    "City": "city",
    "State": "state",
    "Zip Code": "zip_code",
    "Profession/Job Title": "profession_job_title",
    "Employer's Name/Specific Field": "employer_name",
    "Transction Type": "transaction_type",
    "Committee Name": "committee_name",
    "Committee SBoE ID": "committee_sboe_id",
    "Committee Street 1": "committee_street_1",
    "Committee Street 2": "committee_street_2",
    "Committee City": "committee_city",
    "Committee State": "committee_state",
    "Committee Zip Code": "committee_zip_code",
    "Report Name": "report_name",
    "Date Occured": "date_occured_raw",
    "Account Code": "account_code",
    "Amount": "amount_raw",
    "Form of Payment": "form_of_payment",
    "Purpose": "purpose",
    "Candidate/Referendum Name": "candidate_referendum_name",
    "Declaration": "declaration",
}


def load_file(conn, path: Path, source_file: str, skip_2020: bool = False) -> int:
    """Load CSV using COPY for speed. Filters rows in Python, streams to DB."""
    buf = io.StringIO()
    writer = csv.writer(buf)
    count = 0
    with open(path, newline="", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []
        h_to_col = {}
        for h in headers:
            h_clean = h.strip()
            if h_clean in CSV_TO_COL:
                h_to_col[h_clean] = CSV_TO_COL[h_clean]
            else:
                for k, v in CSV_TO_COL.items():
                    if k.lower() == h_clean.lower():
                        h_to_col[h_clean] = v
                        break

        for row in reader:
            vals = []
            for c in COLS:
                h = next((k for k, v in h_to_col.items() if v == c), None)
                v = (row.get(h) or "").strip() if h else None
                vals.append(v if v else "")
            date_raw = vals[COLS.index("date_occured_raw")]
            if skip_2020 and date_raw and len(date_raw) >= 4 and date_raw[-4:] == "2020":
                continue
            if not date_raw or not vals[COLS.index("amount_raw")]:
                continue
            vals.append(source_file)
            writer.writerow(vals)
            count += 1

    buf.seek(0)
    with conn.cursor() as cur:
        cur.copy_expert(
            """
            COPY staging.staging_general_fund (
                donor_name, street_line_1, street_line_2, city, state, zip_code,
                profession_job_title, employer_name, transaction_type, committee_name,
                committee_sboe_id, committee_street_1, committee_street_2,
                committee_city, committee_state, committee_zip_code, report_name,
                date_occured_raw, account_code, amount_raw, form_of_payment, purpose,
                candidate_referendum_name, declaration, source_file
            ) FROM STDIN WITH (FORMAT csv, NULL '')
            """,
            buf,
        )
    return count


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    url = os.getenv("DATABASE_URL") or os.getenv("SUPABASE_DB_URL")
    if not url:
        print("Set DATABASE_URL or SUPABASE_DB_URL", file=sys.stderr)
        return 1

    f1 = root / "2015-2020-ncboe-general-funds.csv"
    f2 = root / "2020-2026-ncboe-donors-general-fund.csv"
    if not f1.exists() or not f2.exists():
        print(f"CSVs not found: {f1} {f2}", file=sys.stderr)
        return 1

    conn = psycopg2.connect(url)
    conn.autocommit = False
    try:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE staging.staging_general_fund")
        conn.commit()

        print("Loading 2015-2020 (excluding 2020)...")
        n1 = load_file(conn, f1, "general-fund-2015-2019", skip_2020=True)
        conn.commit()
        print(f"  Loaded {n1} rows")

        print("Loading 2020-2026...")
        n2 = load_file(conn, f2, "general-fund-2020-2026", skip_2020=False)
        conn.commit()
        print(f"  Loaded {n2} rows")

        print(f"Total: {n1 + n2} rows in staging.staging_general_fund")
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
