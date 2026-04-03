#!/usr/bin/env python3
"""
Phase 5c — Populate norm.fec_individual from raw.fec_donations

**Policy:** FEC data in raw.fec_donations must not be loaded from FEC bulk Schedule A
downloads (see SESSION-STATE / fec_raw_import.py). Do not mix party-committee-only
exports (RNC, NRCC, NRSC) or non-individual-to-candidate-committee sources into this path.
Only categories processed: PRESIDENTIAL, US_HOUSE, US_SENATE.

Applies:
  - get_canonical_first_name() from DB nickname map (ED→EDWARD, ART→ARTHUR, etc.)
  - normalize_address() for street normalization
  - Derived identity-resolution fields:
      first_initial, nickname_canonical, street_number, address_block_key
  - Sub_id for dedup on re-run

Usage:
  cd /Users/Broyhill/Desktop/BroyhillGOP-CURSOR
  python3 -m pipeline.fec_norm_populate
"""

from __future__ import annotations

import logging
import sys
import time

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)

# Process in batches by fec_category to keep statements manageable
CATEGORIES = ['PRESIDENTIAL', 'US_HOUSE', 'US_SENATE']

INSERT_SQL = """
INSERT INTO norm.fec_individual (
  load_id,
  norm_last, norm_first, norm_middle, norm_suffix, norm_prefix,
  raw_contributor_name,
  contributor_id,
  norm_street, norm_city, norm_state, norm_zip5,
  norm_employer, norm_occupation,
  amount, transaction_date,
  receipt_type, receipt_type_desc, memo_text,
  aggregate_ytd,
  committee_id, candidate_id, candidate_name,
  sub_id, fec_cycle,
  voter_ncid,
  normalized_at
)
SELECT
  2                                                    AS load_id,
  r.contributor_last_norm                              AS norm_last,
  get_canonical_first_name(r.contributor_first_norm)  AS norm_first,
  UPPER(TRIM(r.contributor_middle_name))               AS norm_middle,
  UPPER(TRIM(r.contributor_suffix))                    AS norm_suffix,
  UPPER(TRIM(r.contributor_prefix))                    AS norm_prefix,
  r.contributor_name                                   AS raw_contributor_name,
  r.contributor_id,
  normalize_address(r.contributor_street_1)            AS norm_street,
  UPPER(TRIM(r.contributor_city))                      AS norm_city,
  r.contributor_state                                  AS norm_state,
  r.contributor_zip5                                   AS norm_zip5,
  r.employer_normalized                                AS norm_employer,
  UPPER(TRIM(r.contributor_occupation))                AS norm_occupation,
  CASE
    WHEN r.contribution_receipt_amount ~ '^-?[0-9]+(\\.[0-9]+)?$'
    THEN r.contribution_receipt_amount::NUMERIC
    ELSE 0
  END                                                  AS amount,
  CASE
    WHEN r.contribution_receipt_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
    THEN r.contribution_receipt_date::DATE
    ELSE NULL
  END                                                  AS transaction_date,
  r.receipt_type,
  r.receipt_type_desc,
  r.memo_text,
  CASE
    WHEN r.contributor_aggregate_ytd ~ '^-?[0-9]+(\\.[0-9]+)?$'
    THEN r.contributor_aggregate_ytd::NUMERIC
    ELSE NULL
  END                                                  AS aggregate_ytd,
  r.committee_id,
  r.candidate_id,
  r.candidate_name,
  CASE WHEN r.sub_id ~ '^[0-9]+$' THEN r.sub_id::BIGINT ELSE NULL END AS sub_id,
  CASE WHEN r.two_year_transaction_period ~ '^[0-9]{4}$'
       THEN r.two_year_transaction_period::INTEGER ELSE NULL END        AS fec_cycle,
  NULL                                                 AS voter_ncid,
  NOW()                                                AS normalized_at
FROM raw.fec_donations r
WHERE r.fec_category = %s
  AND r.contributor_last_norm IS NOT NULL AND r.contributor_last_norm != ''
  AND r.contributor_zip5 IS NOT NULL AND length(r.contributor_zip5) = 5
  -- Exclude committees/PACs/ORGs — only individuals (run 059 to move existing)
  AND (
    r.entity_type = 'IND'
    OR UPPER(COALESCE(r.is_individual, '')) = 'Y'
    OR UPPER(COALESCE(r.entity_type_desc, '')) LIKE '%%INDIVIDUAL%%'
    OR (r.entity_type IS NULL AND r.is_individual IS NULL)
  )
  AND r.entity_type NOT IN ('PAC', 'ORG', 'COM')
ON CONFLICT DO NOTHING
"""


def run() -> None:
    init_pool()
    grand_total = 0

    for category in CATEGORIES:
        print(f"\n→ Normalizing {category}...")
        start = time.time()
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(INSERT_SQL, (category,))
                inserted = cur.rowcount
        grand_total += inserted
        elapsed = time.time() - start
        print(f"  Inserted {inserted:,} rows in {elapsed:.0f}s")

    print(f"\nTOTAL: {grand_total:,} rows in norm.fec_individual")

    # Verify
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM norm.fec_individual")
            total = cur.fetchone()[0]
            cur.execute(
                "SELECT fec_category, COUNT(*) FROM raw.fec_donations r "
                "JOIN norm.fec_individual n ON n.sub_id = r.sub_id::BIGINT "
                "GROUP BY fec_category ORDER BY 2 DESC"
            )
    print(f"  Final norm.fec_individual count: {total:,}")


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
