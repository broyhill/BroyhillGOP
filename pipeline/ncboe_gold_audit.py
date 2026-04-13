#!/usr/bin/env python3
"""
NCBOE GOLD FILE AUDIT — BroyhillGOP
====================================
Audits every CSV in /data/ncboe/gold/ BEFORE any --apply runs.
No DB writes. No Supabase. Read-only analysis only.

Authority: Ed Broyhill | NC National Committeeman
Written by: Perplexity (CEO) | April 12, 2026

Run:
    python3 ncboe_gold_audit.py --dir /data/ncboe/gold/
    python3 ncboe_gold_audit.py --file /data/ncboe/gold/somefile.csv

Output:
    - Console report per file
    - Summary table across all files
    - audit_report_YYYYMMDD_HHMMSS.txt saved to same directory
    - EXIT CODE 0 = all files passed
    - EXIT CODE 1 = one or more files FAILED — do NOT load until fixed
"""

from __future__ import annotations
import argparse
import csv
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

# ─────────────────────────────────────────────────────────────
# EXACT NCBOE GOLD COLUMN SPEC (typos intentional — do not fix)
# ─────────────────────────────────────────────────────────────
REQUIRED_COLUMNS = [
    "Name",
    "Street Line 1",
    "Street Line 2",
    "City",
    "State",
    "Zip Code",
    "Profession/Job Title",
    "Employer's Name/Specific Field",
    "Transction Type",           # ← TYPO: missing 'a' in Transaction
    "Committee Name",
    "Committee SBoE ID",
    "Committee Street 1",
    "Committee Street 2",
    "Committee City",
    "Committee State",
    "Committee Zip Code",
    "Report Name",
    "Date Occured",              # ← TYPO: missing 'r' in Occurred
    "Account Code",
    "Amount",
    "Form of Payment",
    "Purpose",
    "Candidate/Referendum Name",
    "Declaration",
]
EXPECTED_COL_COUNT = len(REQUIRED_COLUMNS)  # 24

# Republican / non-partisan candidate name keywords to BLOCK (Democratic candidates)
DEM_KEYWORDS = [
    " DEM ", " (D)", " (D) ", " DEMOCRAT", "DEMOCRATIC",
]

# Committee-to-committee transfer / org donor detection
# Mirrors _COMMITTEE_NAME_KEYWORDS in ncboe_normalize_pipeline.py — keep in sync.
COMMITTEE_NAME_KEYWORDS = [
    "COMMITTEE", "FRIENDS OF", "CITIZENS FOR",
    "REPUBLICANS FOR", "CONSERVATIVES FOR", "VICTORY FUND",
    " PAC", "POLITICAL ACTION", "LEADERSHIP FUND",
    "REPUBLICAN PARTY", "DEMOCRATIC PARTY", "GOP", "NCGOP",
    "CAMPAIGN FUND", "CAMPAIGN COMMITTEE", "EXPLORATORY",
    "NORTH CAROLINA REPUBLICAN", "NC REPUBLICAN",
    "FOR CONGRESS", "FOR SENATE", "FOR GOVERNOR", "FOR PRESIDENT",
    "FOR COMMISSIONER", "FOR JUDGE", "FOR SHERIFF",
    "VICTORY COMMITTEE", "TRUST", "FOUNDATION", "ASSOCIATION",
    "CORPORATION", "CORP.", "INC.", " LLC", "LLC ",
    "HOLDINGS", "ENTERPRISES", "INDUSTRIES", "PROPERTIES",
]
# Committee Transction Types that flag a row as non-individual
COMMITTEE_TRANSCTION_TYPES = {
    "Transfer In", "Transfer Out",
    "Contribution by Candidate",
    "Independent Expenditure",
    "Expenditure",
}

# NC zip range (roughly — catches obvious out-of-state)
NC_ZIP_PREFIXES = tuple(str(z) for z in range(270, 290))

# Known NCBOE transaction types (expand as needed)
KNOWN_TRANSCTION_TYPES = {
    "Individual Contribution", "Contribution by Candidate",
    "In-Kind Contribution", "Loan from Candidate",
    "Loan Received", "Returned Contribution",
    "Expenditure", "Independent Expenditure",
    "Contribution Received", "Transfer In",
    "Individual",
    "Transfer Out", "Refund of Contribution",
    "",  # blank is ok — unitemized
}

# NC state abbreviations (donors must be NC)
VALID_DONOR_STATES = {"NC"}
# Allow blank state (some unitemized rows have no address)
VALID_DONOR_STATES_ALLOW_BLANK = {"NC", "", None}

# Amount patterns
AMOUNT_WITH_CURRENCY = re.compile(r'^\$[\d,]+(\.\d{2})?$')
AMOUNT_CLEAN = re.compile(r'^-?[\d,]+(\.\d{2})?$')
AMOUNT_NEGATIVE = re.compile(r'^-')

# Date patterns we accept
DATE_PATTERNS = [
    re.compile(r'^\d{1,2}/\d{1,2}/\d{4}$'),       # M/D/YYYY
    re.compile(r'^\d{4}-\d{2}-\d{2}$'),            # YYYY-MM-DD
    re.compile(r'^\d{1,2}-\d{1,2}-\d{4}$'),        # M-D-YYYY
]

# Voter/donor ID patterns
NC_VOTER_ID_PATTERN = re.compile(r'^[A-Z]{2}\d{5,8}$')   # e.g. BN94856
RNC_ID_PATTERN = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.IGNORECASE)

# ─────────────────────────────────────────────────────────────
# AUDIT ENGINE
# ─────────────────────────────────────────────────────────────

class FileAudit:
    def __init__(self, filepath: Path):
        self.filepath = filepath
        self.filename = filepath.name
        self.errors: list[dict] = []
        self.warnings: list[dict] = []
        self.info: list[dict] = []
        self.stats: dict = {}
        self.passed = True

    def error(self, check: str, msg: str, row: int = None, value: str = None):
        self.errors.append({"check": check, "msg": msg, "row": row, "value": value})
        self.passed = False

    def warn(self, check: str, msg: str, row: int = None, value: str = None):
        self.warnings.append({"check": check, "msg": msg, "row": row, "value": value})

    def note(self, check: str, msg: str):
        self.info.append({"check": check, "msg": msg})


def _parse_amount(raw: str) -> float | None:
    if not raw or not raw.strip():
        return None
    s = raw.strip().lstrip('$').replace(',', '')
    try:
        return float(s)
    except ValueError:
        return None


def _is_valid_date(raw: str) -> bool:
    if not raw or not raw.strip():
        return False
    for pat in DATE_PATTERNS:
        if pat.match(raw.strip()):
            return True
    return False


def audit_file(filepath: Path, all_seen_rows: set) -> FileAudit:
    audit = FileAudit(filepath)

    # ── 1. File-level checks ─────────────────────────────────
    if filepath.stat().st_size == 0:
        audit.error("FILE_EMPTY", "File is empty — zero bytes")
        return audit

    # ── 2. Read CSV ──────────────────────────────────────────
    rows = []
    try:
        with open(filepath, newline='', encoding='utf-8-sig') as fh:
            reader = csv.DictReader(fh)
            headers = reader.fieldnames or []
            for i, row in enumerate(reader, start=2):  # row 1 = header
                rows.append((i, row))
    except UnicodeDecodeError:
        # Try latin-1 fallback (Windows NCBOE files)
        try:
            with open(filepath, newline='', encoding='latin-1') as fh:
                reader = csv.DictReader(fh)
                headers = reader.fieldnames or []
                for i, row in enumerate(reader, start=2):
                    rows.append((i, row))
            audit.warn("ENCODING", "File is latin-1 encoded (not UTF-8) — normalize encoding before production load")
        except Exception as e:
            audit.error("ENCODING", f"Cannot read file: {e}")
            return audit
    except Exception as e:
        audit.error("FILE_READ", f"Cannot read file: {e}")
        return audit

    total_rows = len(rows)
    audit.stats["total_rows"] = total_rows
    audit.stats["filename"] = filepath.name
    audit.stats["filesize_mb"] = round(filepath.stat().st_size / 1024 / 1024, 2)

    # ── 3. Schema / Header checks ────────────────────────────
    if not headers:
        audit.error("SCHEMA_NO_HEADERS", "No headers found — file may be corrupt or empty")
        return audit

    # Strip BOM and whitespace from headers
    headers_clean = [h.strip().lstrip('\ufeff') for h in headers]
    audit.stats["header_count"] = len(headers_clean)

    # Exact column count
    if len(headers_clean) != EXPECTED_COL_COUNT:
        audit.error("SCHEMA_COL_COUNT",
            f"Expected {EXPECTED_COL_COUNT} columns, found {len(headers_clean)}")

    # Exact column names (including typos)
    missing_cols = [c for c in REQUIRED_COLUMNS if c not in headers_clean]
    extra_cols   = [c for c in headers_clean if c not in REQUIRED_COLUMNS]
    if missing_cols:
        audit.error("SCHEMA_MISSING_COLS", f"Missing columns: {missing_cols}")
    if extra_cols:
        audit.warn("SCHEMA_EXTRA_COLS", f"Unexpected extra columns: {extra_cols}")

    # Column order (must match spec exactly)
    if headers_clean[:EXPECTED_COL_COUNT] != REQUIRED_COLUMNS:
        if not missing_cols:  # only warn if not already an error
            audit.warn("SCHEMA_COL_ORDER", "Column order differs from spec — check for positional mismatches")

    if not rows:
        audit.warn("NO_DATA_ROWS", "File has headers but zero data rows")
        return audit

    # ── 4. Per-column null / blank tracking ─────────────────
    null_counts: dict[str, int] = defaultdict(int)
    blank_counts: dict[str, int] = defaultdict(int)

    # ── 5. Per-column profiling state ────────────────────────
    amount_errors = 0
    amount_negatives = 0
    amount_with_dollar_sign = 0
    amounts_parsed: list[float] = []

    date_errors = 0
    date_future = 0
    date_values: list[str] = []

    state_values: Counter = Counter()
    zip_formats: Counter = Counter()
    bad_zip_rows: list[int] = []

    transction_type_values: Counter = Counter()
    unknown_transction_types: list[tuple] = []

    name_blanks = 0  # unitemized
    name_samples: list[str] = []
    name_edward_bleeds: list[str] = []

    candidate_names: Counter = Counter()
    dem_candidate_rows: list[tuple] = []

    committee_sboe_ids: set = set()
    committee_row_count: int = 0
    committee_row_samples: list = []
    committee_ttype_count: int = 0
    duplicate_rows: list[int] = []
    row_fingerprints: list[str] = []

    # NC voter ID / RNC ID columns (if present — enriched files only)
    voter_ncid_values: list[str] = []
    rnc_id_values: list[str] = []
    voter_ncid_col = next((c for c in headers_clean if 'voter_ncid' in c.lower() or 'ncid' in c.lower()), None)
    rnc_id_col     = next((c for c in headers_clean if 'rncid' in c.lower() or 'rnc_id' in c.lower()), None)

    today = datetime.today()

    for row_num, row in rows:
        # null / blank per column
        for col in REQUIRED_COLUMNS:
            val = row.get(col)
            if val is None:
                null_counts[col] += 1
            elif val.strip() == "":
                blank_counts[col] += 1

        # ── Name ──────────────────────────────────────────────
        name = (row.get("Name") or "").strip()
        if not name:
            name_blanks += 1
        else:
            if len(name_samples) < 50:
                name_samples.append(name)
            # ED → EDWARD bleed check
            upper = name.upper()
            if "EDWARD" in upper and upper.startswith("ED "):
                name_edward_bleeds.append(name)

        # ── Committee / Org donor detection ──────────────────
        ttype_for_check = (row.get("Transction Type") or "").strip()
        is_committee_row = False
        if name:
            upper_name = name.upper()
            for kw in COMMITTEE_NAME_KEYWORDS:
                if kw.upper() in upper_name:
                    is_committee_row = True
                    break
        if not is_committee_row and ttype_for_check in COMMITTEE_TRANSCTION_TYPES:
            is_committee_row = True
            committee_ttype_count += 1
        if is_committee_row:
            committee_row_count += 1
            if len(committee_row_samples) < 10:
                committee_row_samples.append((row_num, name, ttype_for_check))

        # ── State ─────────────────────────────────────────────
        state = (row.get("State") or "").strip().upper()
        state_values[state] += 1

        # ── Zip Code ──────────────────────────────────────────
        zipraw = (row.get("Zip Code") or "").strip()
        if zipraw:
            if re.match(r'^\d{5}(-\d{4})?$', zipraw):
                zip5 = zipraw[:5]
                if not zip5.startswith(NC_ZIP_PREFIXES):
                    bad_zip_rows.append((row_num, zipraw))
                zip_formats["valid"] += 1
            else:
                zip_formats["invalid"] += 1
                bad_zip_rows.append((row_num, zipraw))
        else:
            zip_formats["blank"] += 1

        # ── Transction Type ───────────────────────────────────
        ttype = (row.get("Transction Type") or "").strip()
        transction_type_values[ttype] += 1
        if ttype and ttype not in KNOWN_TRANSCTION_TYPES:
            unknown_transction_types.append((row_num, ttype))

        # ── Date Occured ──────────────────────────────────────
        dateraw = (row.get("Date Occured") or "").strip()
        if dateraw:
            date_values.append(dateraw)
            if not _is_valid_date(dateraw):
                date_errors += 1
                if date_errors <= 5:
                    audit.error("DATE_FORMAT",
                        f"Unparseable date value: '{dateraw}'", row=row_num, value=dateraw)
            else:
                # Check for future dates
                for fmt in ["%m/%d/%Y", "%Y-%m-%d", "%m-%d-%Y"]:
                    try:
                        dt = datetime.strptime(dateraw.strip(), fmt)
                        if dt > today:
                            date_future += 1
                        break
                    except ValueError:
                        continue

        # ── Amount ────────────────────────────────────────────
        amtraw = (row.get("Amount") or "").strip()
        if amtraw:
            if AMOUNT_WITH_CURRENCY.match(amtraw):
                amount_with_dollar_sign += 1
            parsed = _parse_amount(amtraw)
            if parsed is None:
                amount_errors += 1
                if amount_errors <= 5:
                    audit.error("AMOUNT_FORMAT",
                        f"Cannot parse amount: '{amtraw}'", row=row_num, value=amtraw)
            else:
                amounts_parsed.append(parsed)
                if parsed < 0:
                    amount_negatives += 1

        # ── Candidate/Referendum Name ─────────────────────────
        cand = (row.get("Candidate/Referendum Name") or "").strip().upper()
        if cand:
            candidate_names[cand] += 1
            for kw in DEM_KEYWORDS:
                if kw in f" {cand} ":
                    dem_candidate_rows.append((row_num, cand))
                    break

        # ── Committee SBoE ID ─────────────────────────────────
        sboe = (row.get("Committee SBoE ID") or "").strip()
        if sboe:
            committee_sboe_ids.add(sboe)

        # ── Cross-file duplicate fingerprint ─────────────────
        fingerprint = "|".join([
            name,
            (row.get("Date Occured") or "").strip(),
            (row.get("Amount") or "").strip(),
            (row.get("Committee SBoE ID") or "").strip(),
        ])
        if fingerprint in all_seen_rows:
            duplicate_rows.append(row_num)
        else:
            all_seen_rows.add(fingerprint)
        row_fingerprints.append(fingerprint)

        # ── Voter NCID (if enriched) ──────────────────────────
        if voter_ncid_col:
            v = (row.get(voter_ncid_col) or "").strip()
            if v:
                voter_ncid_values.append(v)

        # ── RNC ID (if enriched) ─────────────────────────────
        if rnc_id_col:
            r = (row.get(rnc_id_col) or "").strip()
            if r:
                rnc_id_values.append(r)

    # ── 6. Post-loop aggregate checks ───────────────────────

    # Null rates for required columns
    # These columns are structurally sparse — high nulls are expected and not errors
    STRUCTURALLY_SPARSE_COLS = {
        "Street Line 2",            # second address line — most donors don't have one
        "Purpose",                  # only required for expenditures
        "Declaration",              # only required for certain transaction types
        "Account Code",             # internal NCBOE code, often blank
        "Form of Payment",          # not always captured
        "Profession/Job Title",     # optional
        "Employer's Name/Specific Field",  # optional for small donors
    }
    HIGH_NULL_THRESHOLD = 0.05   # 5% — warn
    HIGH_NULL_ERROR_THRESHOLD = 0.50  # 50% — error (only for required fields)
    for col in REQUIRED_COLUMNS:
        null_rate = (null_counts[col] + blank_counts[col]) / total_rows if total_rows else 0
        if col in STRUCTURALLY_SPARSE_COLS:
            # Never error on sparse columns — just note if >95% blank
            if null_rate > 0.95:
                audit.warn("NULL_RATE_SPARSE_COL",
                    f"Column '{col}' is {null_rate:.1%} null/blank — structurally sparse, expected")
        elif null_rate > HIGH_NULL_THRESHOLD:
            severity = "error" if null_rate > HIGH_NULL_ERROR_THRESHOLD else "warn"
            msg = f"Column '{col}' is {null_rate:.1%} null/blank ({null_counts[col]+blank_counts[col]:,} of {total_rows:,} rows)"
            if severity == "error":
                audit.error("NULL_RATE_HIGH", msg)
            else:
                audit.warn("NULL_RATE_ELEVATED", msg)

    # State check — must be NC only (blanks allowed for unitemized)
    non_nc_states = {s: c for s, c in state_values.items() if s not in VALID_DONOR_STATES_ALLOW_BLANK}
    if non_nc_states:
        audit.error("STATE_NON_NC",
            f"Non-NC donor states found: {dict(non_nc_states)} — "
            f"file may contain out-of-state donors (violates platform rules)")

    # Amount dollar sign format
    if amount_with_dollar_sign > 0:
        audit.warn("AMOUNT_DOLLAR_SIGN",
            f"{amount_with_dollar_sign:,} amount values contain '$' — "
            f"pipeline strips this but verify it parses correctly")

    # Amount negatives
    if amount_negatives > 0:
        audit.warn("AMOUNT_NEGATIVE",
            f"{amount_negatives:,} negative amounts — these are refunds or reversals, verify intent")

    # Amount stats
    if amounts_parsed:
        audit.stats["amount_min"]    = round(min(amounts_parsed), 2)
        audit.stats["amount_max"]    = round(max(amounts_parsed), 2)
        audit.stats["amount_mean"]   = round(sum(amounts_parsed) / len(amounts_parsed), 2)
        audit.stats["amount_total"]  = round(sum(amounts_parsed), 2)
        audit.stats["amount_zero_count"] = sum(1 for a in amounts_parsed if a == 0)
        if audit.stats["amount_zero_count"] > 0:
            audit.warn("AMOUNT_ZERO",
                f"{audit.stats['amount_zero_count']:,} rows with $0.00 amount — verify these are valid")

    # Date range
    if date_values:
        audit.stats["date_min"] = min(date_values)
        audit.stats["date_max"] = max(date_values)
    if date_future > 0:
        audit.error("DATE_FUTURE", f"{date_future:,} rows have future dates — data integrity issue")
    if date_errors > 5:
        audit.error("DATE_FORMAT_BULK", f"{date_errors:,} total rows with unparseable dates")

    # Unitemized rows
    audit.stats["unitemized_rows"] = name_blanks
    audit.stats["unitemized_pct"]  = round(name_blanks / total_rows * 100, 1) if total_rows else 0

    # Transction Type unknown values
    if unknown_transction_types:
        audit.warn("TRANSCTION_TYPE_UNKNOWN",
            f"{len(unknown_transction_types)} rows with unrecognized Transction Type: "
            f"{list(set(v for _, v in unknown_transction_types[:5]))}")

    # Bad zips
    if bad_zip_rows:
        audit.warn("ZIP_NON_NC_OR_INVALID",
            f"{len(bad_zip_rows)} rows with non-NC or invalid zip codes (first 3: {bad_zip_rows[:3]})")

    # Democratic candidates
    if dem_candidate_rows:
        audit.error("DEM_CANDIDATE",
            f"🚨 {len(dem_candidate_rows)} rows contain Democratic candidate names — "
            f"ENTIRE FILE MUST GO BACK. Samples: {[c for _, c in dem_candidate_rows[:3]]}")

    # Cross-file duplicates — same name+date+amount+committee_sboe_id across files
    # Expected: NCBOE search-by-office strategy means some rows overlap between
    # primary and secondary files (e.g. sheriff-only vs 2ndary-sheriff).
    # A handful of overlaps is noise. A large number is a double-export problem.
    if duplicate_rows:
        dup_count = len(duplicate_rows)
        dup_pct = round(dup_count / total_rows * 100, 2) if total_rows else 0
        audit.stats["cross_file_duplicates"] = dup_count
        audit.stats["cross_file_dup_pct"] = dup_pct
        if dup_pct > 5.0:
            audit.error("CROSS_FILE_DUPLICATE_HIGH",
                f"{dup_count:,} rows ({dup_pct}%) are exact duplicates of rows in a previously "
                f"audited file (name+date+amount+committee). >5% threshold — investigate before load.")
        else:
            audit.warn("CROSS_FILE_DUPLICATE",
                f"{dup_count:,} rows ({dup_pct}%) match rows in a previously audited file "
                f"(name+date+amount+committee). Within acceptable range — pipeline will deduplicate on load.")
    else:
        audit.stats["cross_file_duplicates"] = 0
        audit.stats["cross_file_dup_pct"] = 0.0
        audit.note("CROSS_FILE_DUPLICATE", "No cross-file duplicates detected")

    # Committee / org donor rows — sidelined on --apply, not rejected
    audit.stats["committee_rows"]        = committee_row_count
    audit.stats["committee_rows_pct"]    = round(committee_row_count / total_rows * 100, 2) if total_rows else 0
    audit.stats["committee_ttype_rows"]  = committee_ttype_count
    if committee_row_count > 0:
        pct = audit.stats["committee_rows_pct"]
        sample_str = [(r, n, t) for r, n, t in committee_row_samples[:5]]
        if pct > 10.0:
            audit.error("COMMITTEE_CONTAMINATION",
                f"\U0001f6a8 {committee_row_count:,} rows ({pct}%) appear to be committee/org donors — "
                f"exceeds 10% threshold. Verify file is individual contributions only. "
                f"These will be SIDELINED on --apply. Samples: {sample_str}")
        else:
            audit.warn("COMMITTEE_ROWS_PRESENT",
                f"{committee_row_count:,} rows ({pct}%) look like committee/org donors — "
                f"will be routed to raw.ncboe_donations_sidelined on --apply. "
                f"Samples: {sample_str}")
    else:
        audit.note("COMMITTEE_CHECK", "No committee/org donor rows detected")

    # ED → EDWARD bleed
    if name_edward_bleeds:
        audit.error("NAME_ED_EDWARD_BLEED",
            f"🚨 ED mapped to EDWARD in {len(name_edward_bleeds)} rows: {name_edward_bleeds[:5]}")

    # Voter NCID validation
    if voter_ncid_values:
        bad_ncids = [v for v in voter_ncid_values if not NC_VOTER_ID_PATTERN.match(v)]
        audit.stats["voter_ncid_count"] = len(voter_ncid_values)
        if bad_ncids:
            audit.warn("VOTER_NCID_FORMAT",
                f"{len(bad_ncids)} voter_ncid values don't match NC format (e.g. BN94856): {bad_ncids[:5]}")
    else:
        audit.note("VOTER_NCID", "No voter_ncid column found — expected for raw (unenriched) files")

    # RNC ID validation
    if rnc_id_values:
        bad_rnc = [v for v in rnc_id_values if not RNC_ID_PATTERN.match(v)]
        audit.stats["rnc_id_count"] = len(rnc_id_values)
        if bad_rnc:
            audit.warn("RNC_ID_FORMAT",
                f"{len(bad_rnc)} rnc_id values don't match UUID format: {bad_rnc[:5]}")
    else:
        audit.note("RNC_ID", "No rnc_id column found — expected for raw (unenriched) files")

    # Name parser spot-check (30 samples)
    try:
        sys.path.insert(0, '/opt/broyhillgop')
        from pipeline.ncboe_name_parser import parse_ncboe_name
        parser_available = True
    except ImportError:
        parser_available = False

    if parser_available and name_samples:
        parse_errors = []
        for raw_name in name_samples[:30]:
            try:
                result = parse_ncboe_name(raw_name)
                if result.first == "EDWARD" and raw_name.upper().startswith("ED "):
                    parse_errors.append(f"ED→EDWARD: '{raw_name}'")
                if result.last is None and not result.is_unitemized:
                    parse_errors.append(f"No last name parsed: '{raw_name}'")
                if result.suffix and result.suffix in (result.middle or ""):
                    parse_errors.append(f"Suffix bleed into middle: '{raw_name}' → middle={result.middle} suffix={result.suffix}")
            except Exception as e:
                parse_errors.append(f"Parser exception on '{raw_name}': {e}")
        if parse_errors:
            audit.error("PARSER_SPOT_CHECK",
                f"{len(parse_errors)} name parse issues in sample of {len(name_samples)}: {parse_errors[:5]}")
        else:
            audit.note("PARSER_SPOT_CHECK",
                f"Parser spot-check passed on {len(name_samples)} sample names")
    elif not parser_available:
        audit.warn("PARSER_UNAVAILABLE",
            "ncboe_name_parser not importable from /opt/broyhillgop — run on server to enable parser checks")

    # Summary stats
    audit.stats["committees"]        = len(committee_sboe_ids)
    audit.stats["transction_types"]  = dict(transction_type_values.most_common(10))
    audit.stats["state_distribution"] = dict(state_values.most_common(10))
    audit.stats["top_candidates"]    = dict(candidate_names.most_common(10))
    audit.stats["error_count"]       = len(audit.errors)
    audit.stats["warning_count"]     = len(audit.warnings)

    return audit


# ─────────────────────────────────────────────────────────────
# REPORT FORMATTER
# ─────────────────────────────────────────────────────────────

def format_report(audits: list[FileAudit]) -> str:
    lines = []
    lines.append("=" * 80)
    lines.append("NCBOE GOLD FILE AUDIT REPORT")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"Files audited: {len(audits)}")
    lines.append("=" * 80)

    passed = [a for a in audits if a.passed]
    failed = [a for a in audits if not a.passed]
    lines.append(f"\nSUMMARY: {len(passed)} PASSED / {len(failed)} FAILED\n")

    if failed:
        lines.append("🚨 FAILED FILES — DO NOT LOAD UNTIL FIXED:")
        for a in failed:
            lines.append(f"  ✗ {a.filename} — {len(a.errors)} error(s)")
        lines.append("")

    if passed:
        lines.append("✅ PASSED FILES:")
        for a in passed:
            lines.append(f"  ✓ {a.filename} — {a.stats.get('total_rows',0):,} rows, "
                         f"{a.stats.get('warning_count',0)} warning(s)")
        lines.append("")

    lines.append("─" * 80)
    lines.append("DETAIL BY FILE")
    lines.append("─" * 80)

    for audit in audits:
        s = audit.stats
        status = "✅ PASS" if audit.passed else "🚨 FAIL"
        lines.append(f"\n{status} — {audit.filename}")
        lines.append(f"  Size:         {s.get('filesize_mb', '?')} MB")
        lines.append(f"  Rows:         {s.get('total_rows', 0):,}")
        lines.append(f"  Columns:      {s.get('header_count', '?')}")
        lines.append(f"  Unitemized:   {s.get('unitemized_rows', 0):,} ({s.get('unitemized_pct', 0)}%)")
        lines.append(f"  Committee/org rows: {s.get('committee_rows', 0):,} ({s.get('committee_rows_pct', 0)}%) — will be sidelined")
        lines.append(f"  Cross-file dups:  {s.get('cross_file_duplicates', 0):,} ({s.get('cross_file_dup_pct', 0)}%) — expected overlap from office-type search strategy")
        lines.append(f"  Committees:   {s.get('committees', 0):,} unique SBoE IDs")
        if 'amount_total' in s:
            lines.append(f"  Amount:       ${s['amount_total']:,.2f} total | "
                         f"${s.get('amount_min',0):,.2f} min | ${s.get('amount_max',0):,.2f} max | "
                         f"${s.get('amount_mean',0):,.2f} avg")
        if 'date_min' in s:
            lines.append(f"  Date range:   {s['date_min']} → {s['date_max']}")
        if s.get('voter_ncid_count'):
            lines.append(f"  Voter NCIDs:  {s['voter_ncid_count']:,} present")
        if s.get('rnc_id_count'):
            lines.append(f"  RNC IDs:      {s['rnc_id_count']:,} present")

        lines.append(f"  State dist:   {s.get('state_distribution', {})}")
        lines.append(f"  Trans types:  {s.get('transction_types', {})}")

        if s.get('top_candidates'):
            lines.append("  Top candidates:")
            for cand, cnt in list(s['top_candidates'].items())[:5]:
                lines.append(f"    {cnt:>6,}  {cand}")

        if audit.errors:
            lines.append(f"\n  ERRORS ({len(audit.errors)}):")
            for e in audit.errors:
                row_str = f" [row {e['row']}]" if e.get('row') else ""
                lines.append(f"    ❌ [{e['check']}]{row_str} {e['msg']}")

        if audit.warnings:
            lines.append(f"\n  WARNINGS ({len(audit.warnings)}):")
            for w in audit.warnings:
                row_str = f" [row {w['row']}]" if w.get('row') else ""
                lines.append(f"    ⚠️  [{w['check']}]{row_str} {w['msg']}")

        if audit.info:
            lines.append(f"\n  NOTES:")
            for n in audit.info:
                lines.append(f"    ℹ️  [{n['check']}] {n['msg']}")

    lines.append("\n" + "=" * 80)
    lines.append("END OF AUDIT REPORT")
    lines.append("=" * 80)

    # Final verdict
    if failed:
        lines.append(f"\n🚨 VERDICT: {len(failed)} file(s) FAILED. DO NOT RUN --apply UNTIL ALL ERRORS ARE RESOLVED.")
    else:
        lines.append(f"\n✅ VERDICT: All {len(passed)} files passed audit. "
                     f"Ed may authorize load with 'I authorize this action'.")

    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Audit NCBOE GOLD CSV files before loading")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--dir",  help="Directory containing CSV files")
    group.add_argument("--file", help="Single CSV file to audit")
    args = parser.parse_args()

    if args.dir:
        gold_dir = Path(args.dir)
        if not gold_dir.is_dir():
            print(f"ERROR: {gold_dir} is not a directory", file=sys.stderr)
            sys.exit(1)
        csv_files = sorted(gold_dir.glob("*.csv"))
        if not csv_files:
            print(f"ERROR: No .csv files found in {gold_dir}", file=sys.stderr)
            sys.exit(1)
    else:
        csv_files = [Path(args.file)]
        if not csv_files[0].exists():
            print(f"ERROR: File not found: {csv_files[0]}", file=sys.stderr)
            sys.exit(1)

    print(f"Auditing {len(csv_files)} file(s)...\n")

    all_seen_rows: set = set()  # cross-file duplicate detection
    audits: list[FileAudit] = []

    for i, fp in enumerate(csv_files, 1):
        print(f"[{i}/{len(csv_files)}] {fp.name}...", end=" ", flush=True)
        a = audit_file(fp, all_seen_rows)
        audits.append(a)
        status = "PASS" if a.passed else f"FAIL ({len(a.errors)} errors)"
        print(f"{a.stats.get('total_rows', 0):,} rows — {status}")

    report = format_report(audits)
    print("\n" + report)

    # Save report
    output_dir = Path(args.dir) if args.dir else Path(args.file).parent
    report_path = output_dir / f"audit_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    report_path.write_text(report, encoding='utf-8')
    print(f"\nReport saved to: {report_path}")

    # Exit code
    failed = [a for a in audits if not a.passed]
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
