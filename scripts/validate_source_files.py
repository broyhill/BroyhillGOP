#!/usr/bin/env python3
"""
Validate NCBOE and NCGOP source CSV files before ingestion.

Detects schema type by headers. Exits non-zero if any file is UNKNOWN.
Outputs JSON report. Use --dry-run to validate without failing on UNKNOWN.

Usage:
  python scripts/validate_source_files.py file1.csv file2.csv ...
  python scripts/validate_source_files.py --dry-run *.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import re
import sys
from pathlib import Path

from dotenv import load_dotenv

_script_dir = Path(__file__).resolve().parent
load_dotenv(_script_dir.parent / ".env")

# Schema signatures
NCBOE_SIGNATURE = {"Committee SBoE ID", "Date Occured"}
NCBOE_ALT_DATE = "Date Occurred"
NCGOP_SIGNATURE = {"Email", "Phone"}


def _detect_schema(headers: list[str]) -> str:
    """Return NCBOE, NCGOP, or UNKNOWN."""
    hset = {h.strip() for h in headers if h}
    if NCBOE_SIGNATURE.issubset(hset) or (NCBOE_ALT_DATE in hset and "Committee SBoE ID" in hset):
        return "NCBOE"
    if NCGOP_SIGNATURE.issubset(hset):
        return "NCGOP"
    return "UNKNOWN"


def _find_amount_col(headers: list[str], schema: str) -> str | None:
    """Find amount/contribution column name."""
    if schema == "NCBOE":
        for h in headers:
            hc = h.strip().lower()
            if "amount" in hc or "contribution" in hc:
                return h.strip()
    if schema == "NCGOP":
        for h in headers:
            hc = h.strip().lower()
            if "amount" in hc or "contribution" in hc:
                return h.strip()
    return None


def _find_date_col(headers: list[str], schema: str) -> str | None:
    """Find date column name."""
    if schema == "NCBOE":
        for h in headers:
            hc = h.strip()
            if hc in ("Date Occured", "Date Occurred"):
                return hc
    if schema == "NCGOP":
        for h in headers:
            hc = h.strip().lower()
            if "date" in hc:
                return h.strip()
    return None


def _parse_amount(val: str) -> float | None:
    """Parse dollar amount. Returns None if unparseable."""
    if not val or not str(val).strip():
        return None
    s = str(val).strip().replace(",", "").replace("$", "")
    try:
        return float(s)
    except ValueError:
        return None


def _parse_date(val: str) -> str | None:
    """Parse date to ISO-ish. Returns None if unparseable."""
    if not val or not str(val).strip():
        return None
    s = str(val).strip()
    # Common formats: MM/DD/YYYY, YYYY-MM-DD, M/D/YY
    m = re.match(r"(\d{1,2})/(\d{1,2})/(\d{2,4})", s)
    if m:
        mm, dd, yy = m.groups()
        y = int(yy) if len(yy) == 4 else 2000 + int(yy) if int(yy) < 100 else 1900 + int(yy)
        return f"{y:04d}-{int(mm):02d}-{int(dd):02d}"
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", s)
    if m:
        return s[:10]
    return None


def validate_file(path: Path) -> dict:
    """Validate one CSV file. Returns report dict."""
    report = {
        "file": str(path),
        "schema_type": "UNKNOWN",
        "row_count": 0,
        "issues": [],
        "amount_parseable": 0,
        "amount_unparseable": 0,
        "date_parseable": 0,
        "date_unparseable": 0,
    }
    if not path.exists():
        report["issues"].append("File not found")
        return report

    try:
        with open(path, newline="", encoding="utf-8", errors="replace") as f:
            reader = csv.reader(f)
            headers = next(reader, [])
            if not headers:
                report["issues"].append("Empty file or no headers")
                return report

            report["schema_type"] = _detect_schema(headers)
            amount_col = _find_amount_col(headers, report["schema_type"])
            date_col = _find_date_col(headers, report["schema_type"])

            if not amount_col:
                report["issues"].append("No amount/contribution column found")
            if not date_col:
                report["issues"].append("No date column found")

            try:
                amt_idx = headers.index(amount_col) if amount_col else -1
            except ValueError:
                amt_idx = -1
            try:
                date_idx = headers.index(date_col) if date_col else -1
            except ValueError:
                date_idx = -1

            for row in reader:
                report["row_count"] += 1
                if amt_idx >= 0 and amt_idx < len(row):
                    v = _parse_amount(row[amt_idx])
                    if v is not None:
                        report["amount_parseable"] += 1
                    else:
                        report["amount_unparseable"] += 1
                if date_idx >= 0 and date_idx < len(row):
                    v = _parse_date(row[date_idx])
                    if v is not None:
                        report["date_parseable"] += 1
                    else:
                        report["date_unparseable"] += 1

    except Exception as e:
        report["issues"].append(str(e))

    return report


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate NCBOE/NCGOP CSV files")
    parser.add_argument("files", nargs="+", type=Path, help="CSV file paths")
    parser.add_argument("--dry-run", action="store_true", help="Do not exit non-zero on UNKNOWN")
    parser.add_argument("--log-file", default="validate_source_files.log", help="Log file path")
    args = parser.parse_args()

    log_path = Path(args.log_file)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.FileHandler(log_path),
            logging.StreamHandler(sys.stdout),
        ],
    )
    logger = logging.getLogger(__name__)

    reports = []
    has_unknown = False
    for p in args.files:
        r = validate_file(p)
        reports.append(r)
        if r["schema_type"] == "UNKNOWN":
            has_unknown = True
        logger.info("%s: %s, %s rows, %s issues", p.name, r["schema_type"], r["row_count"], len(r["issues"]))

    print(json.dumps(reports, indent=2))

    if has_unknown and not args.dry_run:
        logger.error("One or more files have UNKNOWN schema type. Exiting non-zero.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
