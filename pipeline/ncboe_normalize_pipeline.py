#!/usr/bin/env python3
"""
NCBOE GOLD CSV → raw.ncboe_donations (individual rows) + raw.ncboe_donations_sidelined (committee/org rows).

Reads CSV from /data/ncboe/gold/ (or --file), maps EXACT NCBOE headers (including typos),
populates norm_* columns. Default is --dry-run (no INSERT). Use --apply to write rows.

Environment: DATABASE_URL or HETZNER_DB_URL or SUPABASE_DB_URL (see pipeline.db).
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import re
import sys
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

from pipeline.address_number_extractor import extract_address_numbers
from pipeline.employer_normalizer import lookup_sic_naics, normalize_employer_text
from pipeline.ncboe_gold_csv_headers import HEADER_TO_DB_COLUMN, NCBOE_GOLD_HEADERS, normalize_header_key
from pipeline.ncboe_name_parser import parse_ncboe_gold_name

logger = logging.getLogger(__name__)

# ── Committee / sidelining detection ──────────────────────────────────────────
# Mirrors the same lists in ncboe_gold_audit.py — keep in sync.
_COMMITTEE_NAME_KEYWORDS = [
    "COMMITTEE", "FRIENDS OF", "CITIZENS FOR",
    "REPUBLICANS FOR", "CONSERVATIVES FOR", "VICTORY FUND",
    "PAC", "POLITICAL ACTION", "LEADERSHIP FUND",
    "REPUBLICAN PARTY", "DEMOCRATIC PARTY", "GOP", "NCGOP",
    "CAMPAIGN FUND", "CAMPAIGN COMMITTEE", "EXPLORATORY",
    "NORTH CAROLINA REPUBLICAN", "NC REPUBLICAN",
    "FOR CONGRESS", "FOR SENATE", "FOR GOVERNOR", "FOR PRESIDENT",
    "FOR COMMISSIONER", "FOR JUDGE", "FOR SHERIFF",
    "VICTORY COMMITTEE", "TRUST", "FOUNDATION", "ASSOCIATION",
    "CORPORATION", "CORP.", "INC.", " LLC", "LLC ",
    "HOLDINGS", "ENTERPRISES", "INDUSTRIES", "PROPERTIES",
]
_COMMITTEE_TRANSCTION_TYPES = {
    "Transfer In", "Transfer Out",
    "Contribution by Candidate",
    "Independent Expenditure",
    "Expenditure",
}


def _is_committee_row(dbrow: dict) -> tuple[bool, str]:
    """Return (True, reason) if row looks like a committee/org donor, not an individual."""
    name = (dbrow.get("name") or "").strip().upper()
    ttype = (dbrow.get("transction_type") or "").strip()
    if name:
        for kw in _COMMITTEE_NAME_KEYWORDS:
            if kw.upper() in name:
                return True, f"committee_keyword_in_name:{kw.strip()}"
    if ttype in _COMMITTEE_TRANSCTION_TYPES:
        return True, f"committee_transction_type:{ttype}"
    return False, ""

_INSERT_COLS = [
    "source_file",
    "name",
    "street_line_1",
    "street_line_2",
    "city",
    "state",
    "zip_code",
    "profession_job_title",
    "employer_name",
    "transction_type",
    "committee_name",
    "committee_sboe_id",
    "committee_street_1",
    "committee_street_2",
    "committee_city",
    "committee_state",
    "committee_zip_code",
    "report_name",
    "date_occured",
    "account_code",
    "amount",
    "form_of_payment",
    "purpose",
    "candidate_referendum_name",
    "declaration",
    "norm_last",
    "norm_first",
    "norm_middle",
    "norm_suffix",
    "norm_prefix",
    "norm_nickname",
    "norm_zip5",
    "norm_city",
    "norm_employer",
    "employer_sic_code",
    "employer_naics_code",
    "norm_amount",
    "norm_date",
    "address_numbers",
    "all_addresses",
    "year_donated",
    "is_unitemized",
]


_SIDELINED_COLS = _INSERT_COLS + ["sidelined_reason"]


def _insert_sidelined_batch(conn, batch: list[dict]) -> None:
    """Insert committee/org rows to raw.ncboe_donations_sidelined."""
    cols = _SIDELINED_COLS
    placeholders = ", ".join(["%s"] * len(cols))
    sql = f"INSERT INTO raw.ncboe_donations_sidelined ({', '.join(cols)}) VALUES ({placeholders})"
    tuples = []
    for b in batch:
        tuples.append(
            (
                b["source_file"],
                b.get("name"),
                b.get("street_line_1"),
                b.get("street_line_2"),
                b.get("city"),
                b.get("state"),
                b.get("zip_code"),
                b.get("profession_job_title"),
                b.get("employer_name"),
                b.get("transction_type"),
                b.get("committee_name"),
                b.get("committee_sboe_id"),
                b.get("committee_street_1"),
                b.get("committee_street_2"),
                b.get("committee_city"),
                b.get("committee_state"),
                b.get("committee_zip_code"),
                b.get("report_name"),
                b.get("date_occured"),
                b.get("account_code"),
                b.get("amount"),
                b.get("form_of_payment"),
                b.get("purpose"),
                b.get("candidate_referendum_name"),
                b.get("declaration"),
                b.get("norm_last"),
                b.get("norm_first"),
                b.get("norm_middle"),
                b.get("norm_suffix"),
                b.get("norm_prefix"),
                b.get("norm_nickname"),
                b.get("norm_zip5"),
                b.get("norm_city"),
                b.get("norm_employer"),
                b.get("employer_sic_code"),
                b.get("employer_naics_code"),
                b.get("norm_amount"),
                b.get("norm_date"),
                b.get("address_numbers") or None,
                b.get("all_addresses") or None,
                b.get("year_donated"),
                b.get("is_unitemized"),
                b.get("sidelined_reason"),
            )
        )
    with conn.cursor() as cur:
        cur.executemany(sql, tuples)
    conn.commit()


def _norm_zip5(z: str | None) -> str | None:
    if not z:
        return None
    digits = re.sub(r"\D", "", str(z))
    return digits[:5] if digits else None


def _norm_city(c: str | None) -> str | None:
    if not c or not str(c).strip():
        return None
    return str(c).strip().upper()


def _parse_amount(a: str | None) -> Decimal | None:
    if not a or not str(a).strip():
        return None
    s = str(a).strip().replace("$", "").replace(",", "")
    try:
        return Decimal(s)
    except InvalidOperation:
        return None


def _parse_date_from_ncboe(s: str | None) -> tuple[datetime.date | None, int | None]:
    """NCBOE dates vary; try common formats."""
    if not s or not str(s).strip():
        return None, None
    raw = str(s).strip()
    for fmt in ("%m/%d/%Y", "%m/%d/%y", "%Y-%m-%d", "%m-%d-%Y"):
        try:
            dt = datetime.strptime(raw, fmt)
            return dt.date(), dt.year
        except ValueError:
            continue
    return None, None


def _build_header_map(fieldnames: list[str] | None) -> dict[str, str]:
    """Map CSV header → DB column using exact NCBOE names; allow BOM/space drift."""
    if not fieldnames:
        return {}
    out: dict[str, str] = {}
    lower_map = {normalize_header_key(h): h for h in fieldnames}
    for canon in NCBOE_GOLD_HEADERS:
        key = normalize_header_key(canon)
        if key in lower_map:
            actual = lower_map[key]
            out[HEADER_TO_DB_COLUMN[canon]] = actual
    return out


def _row_to_db(
    row: dict[str, str],
    header_to_csvkey: dict[str, str],
    source_file: str,
    conn,
) -> dict:
    def get(db_col: str) -> str | None:
        csv_key = header_to_csvkey.get(db_col)
        if not csv_key:
            return None
        v = row.get(csv_key)
        return str(v).strip() if v is not None and str(v).strip() != "" else None

    base = {c: get(c) for c in HEADER_TO_DB_COLUMN.values()}
    base["source_file"] = source_file

    parsed = parse_ncboe_gold_name(base.get("name"))
    base["norm_prefix"] = parsed.prefix
    base["norm_first"] = parsed.first
    base["norm_middle"] = parsed.middle
    base["norm_nickname"] = parsed.nickname
    base["norm_last"] = parsed.last
    base["norm_suffix"] = parsed.suffix
    base["is_unitemized"] = parsed.is_unitemized

    base["norm_zip5"] = _norm_zip5(base.get("zip_code"))
    base["norm_city"] = _norm_city(base.get("city"))
    emp_norm = normalize_employer_text(base.get("employer_name"))
    base["norm_employer"] = emp_norm
    sic, naics = lookup_sic_naics(conn, emp_norm)
    base["employer_sic_code"] = sic
    base["employer_naics_code"] = naics

    base["norm_amount"] = _parse_amount(base.get("amount"))
    nd, yr = _parse_date_from_ncboe(base.get("date_occured"))
    base["norm_date"] = nd
    base["year_donated"] = yr

    a1, a2 = base.get("street_line_1"), base.get("street_line_2")
    base["address_numbers"] = extract_address_numbers(a1, a2)
    parts = [p for p in (a1, a2, base.get("city"), base.get("state"), base.get("zip_code")) if p]
    base["all_addresses"] = [" ".join(parts)] if parts else []

    return base


def process_csv(path: Path, conn, *, apply: bool, limit: int | None = None) -> dict:
    """Process one CSV. Returns dict with keys: individual, sidelined, total."""
    counts = {"individual": 0, "sidelined": 0, "total": 0}
    with path.open(newline="", encoding="utf-8-sig", errors="replace") as f:
        reader = csv.DictReader(f)
        header_map = _build_header_map(reader.fieldnames)
        if len(header_map) < 20:
            logger.warning(
                "Only mapped %s/%s headers — check typos. Fieldnames: %s",
                len(header_map),
                len(NCBOE_GOLD_HEADERS),
                reader.fieldnames,
            )
        ind_batch: list[dict] = []
        sl_batch: list[dict] = []
        for row in reader:
            if limit is not None and counts["total"] >= limit:
                break
            dbrow = _row_to_db(row, header_map, str(path.name), conn)
            counts["total"] += 1
            is_committee, reason = _is_committee_row(dbrow)
            if is_committee:
                dbrow["sidelined_reason"] = reason
                sl_batch.append(dbrow)
                counts["sidelined"] += 1
            else:
                ind_batch.append(dbrow)
                counts["individual"] += 1
            if apply and len(ind_batch) >= 500:
                _insert_batch(conn, ind_batch)
                ind_batch.clear()
            if apply and len(sl_batch) >= 500:
                _insert_sidelined_batch(conn, sl_batch)
                sl_batch.clear()
        if apply:
            if ind_batch:
                _insert_batch(conn, ind_batch)
            if sl_batch:
                _insert_sidelined_batch(conn, sl_batch)
        elif counts["total"]:
            logger.info(
                "Dry-run: %s rows from %s — %s individual, %s sidelined (committee/org)",
                counts["total"], path, counts["individual"], counts["sidelined"],
            )
    return counts


def _insert_batch(conn, batch: list[dict]) -> None:
    cols = _INSERT_COLS
    placeholders = ", ".join(["%s"] * len(cols))
    sql = f"INSERT INTO raw.ncboe_donations ({', '.join(cols)}) VALUES ({placeholders})"
    tuples = []
    for b in batch:
        tuples.append(
            (
                b["source_file"],
                b.get("name"),
                b.get("street_line_1"),
                b.get("street_line_2"),
                b.get("city"),
                b.get("state"),
                b.get("zip_code"),
                b.get("profession_job_title"),
                b.get("employer_name"),
                b.get("transction_type"),
                b.get("committee_name"),
                b.get("committee_sboe_id"),
                b.get("committee_street_1"),
                b.get("committee_street_2"),
                b.get("committee_city"),
                b.get("committee_state"),
                b.get("committee_zip_code"),
                b.get("report_name"),
                b.get("date_occured"),
                b.get("account_code"),
                b.get("amount"),
                b.get("form_of_payment"),
                b.get("purpose"),
                b.get("candidate_referendum_name"),
                b.get("declaration"),
                b.get("norm_last"),
                b.get("norm_first"),
                b.get("norm_middle"),
                b.get("norm_suffix"),
                b.get("norm_prefix"),
                b.get("norm_nickname"),
                b.get("norm_zip5"),
                b.get("norm_city"),
                b.get("norm_employer"),
                b.get("employer_sic_code"),
                b.get("employer_naics_code"),
                b.get("norm_amount"),
                b.get("norm_date"),
                b.get("address_numbers") or None,
                b.get("all_addresses") or None,
                b.get("year_donated"),
                b.get("is_unitemized"),
            )
        )
    with conn.cursor() as cur:
        cur.executemany(sql, tuples)
    conn.commit()


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    p = argparse.ArgumentParser(description="NCBOE GOLD normalize → raw.ncboe_donations")
    p.add_argument("--file", type=Path, help="Single CSV path")
    p.add_argument("--dir", type=Path, default=Path("/data/ncboe/gold"), help="Directory of CSVs")
    p.add_argument("--apply", action="store_true", help="Actually INSERT (default dry-run)")
    p.add_argument("--limit", type=int, default=None, help="Max rows per file (testing)")
    args = p.parse_args()

    from pipeline.db import get_connection, init_pool

    init_pool()
    total = 0
    with get_connection() as conn:
        files: list[Path] = []
        if args.file:
            files = [args.file]
        elif args.dir.exists():
            files = sorted(args.dir.glob("*.csv"))
        else:
            logger.error("No --file and directory %s does not exist", args.dir)
            return 1
        total_ind = 0
        total_sl = 0
        for fp in files:
            logger.info("Processing %s apply=%s", fp, args.apply)
            counts = process_csv(fp, conn, apply=args.apply, limit=args.limit)
            total_ind += counts["individual"]
            total_sl  += counts["sidelined"]
        logger.info(
            "Done. Individual rows: %s | Sidelined (committee/org): %s | Total: %s",
            total_ind, total_sl, total_ind + total_sl,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
