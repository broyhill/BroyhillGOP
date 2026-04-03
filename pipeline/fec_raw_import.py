#!/usr/bin/env python3
"""
DEPRECATED / POLICY-BLOCKED — FEC bulk Schedule A import

**Project rule (Ed): Do not select or ingest FEC bulk download files.**
Bulk Schedule A extracts are not an approved source for BroyhillGOP ingestion
(physical-address and data-quality requirements are not met by this path).

This module is retained only as historical reference. By default it **refuses to run**.
To override in an extreme recovery scenario only, set:
  export BROYHILL_ALLOW_FEC_BULK_IMPORT=1

Original behavior when allowed: import March 2026 FEC schedule_a CSVs from
~/Downloads into raw.fec_donations, dedupe on sub_id.
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import psycopg2
import psycopg2.extras
from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)

DOWNLOADS = Path.home() / "Downloads"

# Ed's "6 + 6 + 6" layout (March 2026 pull) — REFERENCE ONLY; module is policy-blocked.
# - 6 Presidential + 6 US House + 6 US Senate = 18 files, one per ~two-year election slice.
# - Downloaded sequentially: suspected FEC site row caps / truncated output on huge exports;
#   Trump-cycle volume made splitting by office (pres / house / senate) and period safer.
# - Plus 5 party-committee files (RNC×2, NRCC×1, NRSC×2) → 23 paths below.

FEC_FILES: list[tuple[str, str]] = [
    # Presidential (6)
    ("pres-2015-16-schedule_a-2026-03-11T22_18_56.csv",           "PRESIDENTIAL"),
    ("pres-2017-2018-schedule_a-2026-03-11T22_21_57.csv",          "PRESIDENTIAL"),
    ("pres-2019-2020schedule_a-2026-03-11T22_29_00.csv",           "PRESIDENTIAL"),
    ("pres-2021-2022-schedule_a-2026-03-11T22_32_16.csv",          "PRESIDENTIAL"),
    ("pres-2023-2024-schedule_a-2026-03-11T22_34_32.csv",          "PRESIDENTIAL"),
    ("pres-2025-2026-schedule_a-2026-03-11T22_36_12.csv",          "PRESIDENTIAL"),
    # US House (6)
    ("House-2015-2016-schedule_a-2026-03-11T22_38_59.csv",         "US_HOUSE"),
    ("house-2017-2018-schedule_a-2026-03-11T22_40_13.csv",         "US_HOUSE"),
    ("house-2019-2020-schedule_a-2026-03-11T22_42_56.csv",         "US_HOUSE"),
    ("house 2021-2022-schedule_a-2026-03-11T22_46_12.csv",         "US_HOUSE"),
    ("house-2023-2024-schedule_a-2026-03-11T22_48_39.csv",         "US_HOUSE"),
    ("house-2025-2026-schedule_a-2026-03-11T22_50_12.csv",         "US_HOUSE"),
    # US Senate (6)
    ("senate-2015-2016-schedule_a-2026-03-11T22_52_17.csv",        "US_SENATE"),
    ("senate-2017-2018-schedule_a-2026-03-11T22_53_51.csv",        "US_SENATE"),
    ("senate-2019-2020-schedule_a-2026-03-11T23_00_50.csv",        "US_SENATE"),
    ("senate-2021-2022-schedule_a-2026-03-11T23_12_37.csv",        "US_SENATE"),
    ("senate-2023-2024-schedule_a-2026-03-11T23_14_42.csv",        "US_SENATE"),
    ("senate-2025-2026-schedule_a-2026-03-11T23_16_23.csv",        "US_SENATE"),
    # RNC / NRCC / NRSC (5)
    ("RNC-2015-2023-schedule_a-2026-03-11T23_24_16.csv",           "RNC"),
    ("RNC-2024-2026-schedule_a-2026-03-11T23_26_28.csv",           "RNC"),
    ("NRCC-2015-2026-schedule_a-2026-03-11T23_29_07.csv",          "NRCC"),
    ("NRSC-2015-2020-schedule_a-2026-03-11T23_34_04.csv",          "NRSC"),
    ("NRSC-2021-2026-schedule_a-2026-03-11T23_36_31.csv",          "NRSC"),
]

# All 78 source column names (from FEC API export format)
FEC_SOURCE_COLS = [
    "committee_id", "committee_name", "report_year", "report_type",
    "image_number", "filing_form", "link_id", "line_number",
    "transaction_id", "file_number", "entity_type", "entity_type_desc",
    "unused_contbr_id", "contributor_prefix", "contributor_name",
    "recipient_committee_type", "recipient_committee_org_type",
    "recipient_committee_designation", "contributor_first_name",
    "contributor_middle_name", "contributor_last_name", "contributor_suffix",
    "contributor_street_1", "contributor_street_2", "contributor_city",
    "contributor_state", "contributor_zip", "contributor_employer",
    "contributor_occupation", "contributor_id", "is_individual",
    "receipt_type", "receipt_type_desc", "receipt_type_full",
    "memo_code", "memo_code_full", "memo_text",
    "contribution_receipt_date", "contribution_receipt_amount",
    "contributor_aggregate_ytd", "candidate_id", "candidate_name",
    "candidate_first_name", "candidate_last_name", "candidate_middle_name",
    "candidate_prefix", "candidate_suffix", "candidate_office",
    "candidate_office_full", "candidate_office_state",
    "candidate_office_state_full", "candidate_office_district",
    "conduit_committee_id", "conduit_committee_name",
    "conduit_committee_street1", "conduit_committee_street2",
    "conduit_committee_city", "conduit_committee_state",
    "conduit_committee_zip", "donor_committee_name",
    "national_committee_nonfederal_account", "election_type",
    "election_type_full", "fec_election_type_desc", "fec_election_year",
    "two_year_transaction_period", "amendment_indicator",
    "amendment_indicator_desc", "schedule_type", "schedule_type_full",
    "increased_limit", "load_date", "sub_id", "original_sub_id",
    "back_reference_transaction_id", "back_reference_schedule_name",
    "pdf_url", "line_number_label",
]

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS raw.fec_donations (
    id                              BIGSERIAL PRIMARY KEY,
    -- All 78 FEC source columns (text; parse at norm layer)
    committee_id                    TEXT,
    committee_name                  TEXT,
    report_year                     TEXT,
    report_type                     TEXT,
    image_number                    TEXT,
    filing_form                     TEXT,
    link_id                         TEXT,
    line_number                     TEXT,
    transaction_id                  TEXT,
    file_number                     TEXT,
    entity_type                     TEXT,
    entity_type_desc                TEXT,
    unused_contbr_id                TEXT,
    contributor_prefix              TEXT,
    contributor_name                TEXT,
    recipient_committee_type        TEXT,
    recipient_committee_org_type    TEXT,
    recipient_committee_designation TEXT,
    contributor_first_name          TEXT,
    contributor_middle_name         TEXT,
    contributor_last_name           TEXT,
    contributor_suffix              TEXT,
    contributor_street_1            TEXT,
    contributor_street_2            TEXT,
    contributor_city                TEXT,
    contributor_state               TEXT,
    contributor_zip                 TEXT,
    contributor_employer            TEXT,
    contributor_occupation          TEXT,
    contributor_id                  TEXT,
    is_individual                   TEXT,
    receipt_type                    TEXT,
    receipt_type_desc               TEXT,
    receipt_type_full               TEXT,
    memo_code                       TEXT,
    memo_code_full                  TEXT,
    memo_text                       TEXT,
    contribution_receipt_date       TEXT,
    contribution_receipt_amount     TEXT,
    contributor_aggregate_ytd       TEXT,
    candidate_id                    TEXT,
    candidate_name                  TEXT,
    candidate_first_name            TEXT,
    candidate_last_name             TEXT,
    candidate_middle_name           TEXT,
    candidate_prefix                TEXT,
    candidate_suffix                TEXT,
    candidate_office                TEXT,
    candidate_office_full           TEXT,
    candidate_office_state          TEXT,
    candidate_office_state_full     TEXT,
    candidate_office_district       TEXT,
    conduit_committee_id            TEXT,
    conduit_committee_name          TEXT,
    conduit_committee_street1       TEXT,
    conduit_committee_street2       TEXT,
    conduit_committee_city          TEXT,
    conduit_committee_state         TEXT,
    conduit_committee_zip           TEXT,
    donor_committee_name            TEXT,
    national_committee_nonfederal_account TEXT,
    election_type                   TEXT,
    election_type_full              TEXT,
    fec_election_type_desc          TEXT,
    fec_election_year               TEXT,
    two_year_transaction_period     TEXT,
    amendment_indicator             TEXT,
    amendment_indicator_desc        TEXT,
    schedule_type                   TEXT,
    schedule_type_full              TEXT,
    increased_limit                 TEXT,
    load_date                       TEXT,
    sub_id                          TEXT UNIQUE,   -- FEC unique transaction ID; dedup key
    original_sub_id                 TEXT,
    back_reference_transaction_id   TEXT,
    back_reference_schedule_name    TEXT,
    pdf_url                         TEXT,
    line_number_label               TEXT,
    -- Pipeline-added columns
    contributor_zip5                TEXT,          -- left(contributor_zip, 5)
    contributor_last_norm           TEXT,          -- upper(trim(contributor_last_name))
    contributor_first_norm          TEXT,          -- upper(trim(contributor_first_name))
    employer_normalized             TEXT,          -- stripped LLC/Inc/etc
    fec_category                    TEXT NOT NULL, -- PRESIDENTIAL / US_HOUSE / US_SENATE / RNC / NRCC / NRSC
    source_file                     TEXT NOT NULL,
    loaded_at                       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_raw_fec_name ON raw.fec_donations (contributor_last_norm, contributor_first_norm);
CREATE INDEX IF NOT EXISTS idx_raw_fec_zip  ON raw.fec_donations (contributor_zip5);
CREATE INDEX IF NOT EXISTS idx_raw_fec_zip_name ON raw.fec_donations (contributor_last_norm, contributor_first_norm, contributor_zip5);
CREATE INDEX IF NOT EXISTS idx_raw_fec_committee ON raw.fec_donations (committee_id);
CREATE INDEX IF NOT EXISTS idx_raw_fec_category  ON raw.fec_donations (fec_category);
CREATE INDEX IF NOT EXISTS idx_raw_fec_date ON raw.fec_donations (contribution_receipt_date);
"""

_EMPLOYER_STRIP = re.compile(
    r'\b(LLC|L\.L\.C\.?|INC\.?|INCORPORATED|CORP\.?|CORPORATION|LTD\.?|'
    r'LP|L\.P\.?|PLLC|PC|P\.C\.?|CO\.?)\s*$',
    re.IGNORECASE,
)

def normalize_employer(val: str | None) -> str | None:
    if not val:
        return None
    v = val.strip().upper()
    if v in ('', 'N/A', 'NA', 'NONE', 'NOT EMPLOYED', 'RETIRED', 'SELF'):
        return v or None
    v = re.sub(r'\s+', ' ', v)
    v = _EMPLOYER_STRIP.sub('', v).strip().rstrip(',').strip()
    return v or None


def zip5(val: str | None) -> str | None:
    if not val:
        return None
    digits = re.sub(r'\D', '', val)
    return digits[:5] if len(digits) >= 5 else None


def clean(val: str | None) -> str | None:
    if val is None:
        return None
    v = val.strip()
    return v if v else None


def load_file(conn, filepath: Path, category: str, dry_run: bool) -> dict:
    inserted = skipped = errors = 0
    start = time.time()

    with open(filepath, newline='', encoding='utf-8-sig', errors='replace') as fh:
        reader = csv.DictReader(fh)
        batch: list[tuple] = []

        for row in reader:
            try:
                last_norm = clean(row.get('contributor_last_name', '') or '')
                first_norm = clean(row.get('contributor_first_name', '') or '')

                values = tuple(
                    clean(row.get(col)) for col in FEC_SOURCE_COLS
                ) + (
                    zip5(row.get('contributor_zip')),                  # contributor_zip5
                    last_norm.upper() if last_norm else None,           # contributor_last_norm
                    first_norm.upper() if first_norm else None,         # contributor_first_norm
                    normalize_employer(row.get('contributor_employer')),# employer_normalized
                    category,                                           # fec_category
                    filepath.name,                                      # source_file
                )
                batch.append(values)
            except Exception as exc:
                errors += 1
                logger.debug("Row error: %s", exc)
                continue

            if len(batch) >= 2000:
                if not dry_run:
                    ins, sk = _insert_batch(conn, batch)
                    inserted += ins
                    skipped += sk
                else:
                    inserted += len(batch)
                batch = []

        if batch and not dry_run:
            ins, sk = _insert_batch(conn, batch)
            inserted += ins
            skipped += sk
        elif batch and dry_run:
            inserted += len(batch)

    elapsed = time.time() - start
    return {"inserted": inserted, "skipped": skipped, "errors": errors, "elapsed": elapsed}


def _insert_batch(conn, batch: list[tuple]) -> tuple[int, int]:
    all_cols = FEC_SOURCE_COLS + [
        'contributor_zip5', 'contributor_last_norm', 'contributor_first_norm',
        'employer_normalized', 'fec_category', 'source_file',
    ]
    placeholders = ','.join(['%s'] * len(all_cols))
    col_list = ','.join(all_cols)
    sql = f"""
        INSERT INTO raw.fec_donations ({col_list})
        VALUES ({placeholders})
        ON CONFLICT (sub_id) DO NOTHING
    """
    with conn.cursor() as cur:
        psycopg2.extras.execute_batch(cur, sql, batch, page_size=500)
        inserted = cur.rowcount if cur.rowcount >= 0 else len(batch)
    conn.commit()
    # rowcount from execute_batch is total affected; skipped = len(batch) - inserted
    skipped = max(0, len(batch) - inserted)
    return inserted, skipped


def ensure_schema(conn) -> None:
    with conn.cursor() as cur:
        cur.execute(CREATE_TABLE_SQL)
    conn.commit()
    logger.info("raw.fec_donations table and indexes ready")


def run(dry_run: bool = False, single_file: str | None = None) -> None:
    if os.environ.get("BROYHILL_ALLOW_FEC_BULK_IMPORT", "").strip() != "1":
        print(
            "ABORT: FEC bulk download ingestion is disabled by project policy.\n"
            "Do not select or ingest FEC bulk Schedule A files (no approved physical-address path).\n"
            "Override only if Ed explicitly authorizes: BROYHILL_ALLOW_FEC_BULK_IMPORT=1",
            file=sys.stderr,
        )
        sys.exit(2)

    init_pool()

    files = FEC_FILES
    if single_file:
        files = [(f, c) for f, c in FEC_FILES if single_file.lower() in f.lower()]
        if not files:
            logger.error("No matching file found for: %s", single_file)
            sys.exit(1)

    # Verify all files exist before starting
    missing = [f for f, _ in files if not (DOWNLOADS / f).exists()]
    if missing:
        logger.error("Missing source files:\n  %s", '\n  '.join(missing))
        sys.exit(1)

    with get_connection() as conn:
        if not dry_run:
            ensure_schema(conn)

    grand_total = 0
    grand_skipped = 0

    for filename, category in files:
        filepath = DOWNLOADS / filename
        size_mb = filepath.stat().st_size / 1_048_576
        print(f"\n→ {filename} [{category}] ({size_mb:.0f} MB)")

        with get_connection() as conn:
            result = load_file(conn, filepath, category, dry_run)

        grand_total += result['inserted']
        grand_skipped += result['skipped']
        print(
            f"  {'DRY RUN: would insert' if dry_run else 'Inserted'} "
            f"{result['inserted']:,} rows  |  skipped {result['skipped']:,}  |  "
            f"errors {result['errors']}  |  {result['elapsed']:.0f}s"
        )

    print(f"\n{'DRY RUN ' if dry_run else ''}TOTAL: {grand_total:,} inserted, {grand_skipped:,} skipped (sub_id conflicts)")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="POLICY-BLOCKED: FEC bulk import (see module docstring). Requires BROYHILL_ALLOW_FEC_BULK_IMPORT=1."
    )
    parser.add_argument("--dry-run", action="store_true", help="Count rows without writing")
    parser.add_argument("--file", help="Load only the file matching this substring")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(message)s",
    )

    run(dry_run=args.dry_run, single_file=args.file)
    return 0


if __name__ == "__main__":
    sys.exit(main())
