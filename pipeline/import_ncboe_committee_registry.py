#!/usr/bin/env python3
"""
Import NCBOE committee registry into core.ncboe_committee_type_lookup.

REQUIRED before ETL Step 6. Do NOT use split_part on SBOE IDs — they are opaque.
Populate lookup from NCBOE official committee registry.

Source options:
  - NCSBE Campaign Finance: https://cf.ncsbe.gov/CFOrgLkup/ (search/export)
  - NCSBE public data: https://dl.ncsbe.gov/ → Campaign_Finance/
  - Contact NCSBE for bulk committee list if no direct CSV exists

Expected CSV columns (flexible mapping):
  - committee_sboe_id: Committee ID, SBoE ID, committee_sboe_id, STA_ID
  - committee_type: Committee Type, Type, committee_type (values: candidate, pac, party, independent)
  - committee_name (optional): Committee Name, Name

Usage:
  python3 -m pipeline.import_ncboe_committee_registry path/to/committees.csv
  python3 -m pipeline.import_ncboe_committee_registry --help
"""

from __future__ import annotations

import argparse
import csv
import logging
import sys
from pathlib import Path

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)

# Column name aliases (case-insensitive match)
SBOE_ID_ALIASES = ("committee_sboe_id", "committee id", "sboe id", "sta_id", "committee_sboe")
TYPE_ALIASES = ("committee_type", "committee type", "type", "committee type code")
NAME_ALIASES = ("committee_name", "committee name", "name")


def _find_column(row: dict[str, str], aliases: tuple[str, ...]) -> str | None:
    """Return first matching column key (case-insensitive)."""
    keys_lower = {k.lower(): k for k in row.keys()}
    for alias in aliases:
        if alias.lower() in keys_lower:
            return keys_lower[alias.lower()]
    return None


def run_import(csv_path: Path) -> dict:
    """
    Import committee registry CSV into core.ncboe_committee_type_lookup.

    Returns:
        Dict with rows_inserted, rows_updated, errors.
    """
    if not csv_path.exists():
        raise FileNotFoundError(
            f"Committee registry file not found: {csv_path}\n"
            "Obtain from NCBOE: https://cf.ncsbe.gov/CFOrgLkup/ or https://dl.ncsbe.gov/"
        )

    init_pool()
    result = {"rows_inserted": 0, "rows_updated": 0, "errors": []}

    with get_connection() as conn:
        with conn.cursor() as cur:
            with open(csv_path, newline="", encoding="utf-8", errors="replace") as f:
                reader = csv.DictReader(f)
                if not reader.fieldnames:
                    raise ValueError("CSV has no header row")

                sboe_col = _find_column({fn: "" for fn in reader.fieldnames}, SBOE_ID_ALIASES)
                type_col = _find_column({fn: "" for fn in reader.fieldnames}, TYPE_ALIASES)
                name_col = _find_column({fn: "" for fn in reader.fieldnames}, NAME_ALIASES)

                if not sboe_col or not type_col:
                    raise ValueError(
                        f"CSV must have committee_sboe_id and committee_type columns. "
                        f"Found: {reader.fieldnames}. "
                        f"Tried aliases: sboe={SBOE_ID_ALIASES}, type={TYPE_ALIASES}"
                    )

                for i, row in enumerate(reader, start=2):
                    sboe_id = (row.get(sboe_col) or "").strip()
                    ctype = (row.get(type_col) or "").strip()
                    cname = (row.get(name_col) or "").strip() if name_col else None

                    if not sboe_id or not ctype:
                        result["errors"].append(f"Row {i}: missing sboe_id or type, skipped")
                        continue

                    try:
                        cur.execute(
                            """
                            INSERT INTO core.ncboe_committee_type_lookup
                                (committee_sboe_id, committee_type, notes)
                            VALUES (%s, %s, %s)
                            ON CONFLICT (committee_sboe_id) DO UPDATE SET
                                committee_type = EXCLUDED.committee_type,
                                notes = COALESCE(EXCLUDED.notes, core.ncboe_committee_type_lookup.notes)
                            """,
                            (sboe_id, ctype, cname or None),
                        )
                        if cur.rowcount == 1:
                            result["rows_inserted"] += 1
                        else:
                            result["rows_updated"] += 1
                    except Exception as e:
                        result["errors"].append(f"Row {i} ({sboe_id}): {e}")

    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Import NCBOE committee registry into core.ncboe_committee_type_lookup"
    )
    parser.add_argument(
        "csv_path",
        type=Path,
        help="Path to committee registry CSV (committee_sboe_id, committee_type required)",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    try:
        r = run_import(args.csv_path)
        print(f"Inserted: {r['rows_inserted']}, Updated: {r['rows_updated']}")
        if r["errors"]:
            for e in r["errors"][:20]:
                print(f"  Error: {e}")
            if len(r["errors"]) > 20:
                print(f"  ... and {len(r['errors']) - 20} more")
            return 1
        return 0
    except (FileNotFoundError, ValueError) as e:
        print(str(e), file=sys.stderr)
        return 1
    except Exception as e:
        logger.exception("Import failed: %s", e)
        return 1


if __name__ == "__main__":
    sys.exit(main())
