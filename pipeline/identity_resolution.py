#!/usr/bin/env python3
"""
RFC-001 Identity Resolution — Populate core.person_spine

6-Pass blocking strategy (per RFC-001-ARCHITECTURE-REVIEW.md):
  Pass 1: voter_ncid exact match (confidence 0.99)
  Pass 2: email exact match (confidence 0.95)  [limited — email sparse]
  Pass 3: norm_last + norm_first + zip5 (confidence 0.95)
  Pass 4: norm_last + nickname_canonical + zip5 [already collapsed in norm_first]
  Pass 5: norm_last + first_initial + zip5 + employer (confidence 0.85)
  Pass 6: cross-zip with secondary signal (confidence 0.80)

Process:
  Phase A — Seed spine from NCBOE donors matched to voter file (voter_ncid anchor)
  Phase B — Add remaining NCBOE donors by name+zip clustering
  Phase C — Link norm.nc_boe_donations rows → person_id
  Phase D — Match FEC donors to spine (Passes 3 + 5)
  Phase E — Add unmatched FEC donors as new spine rows
  Phase F — Link norm.fec_individual rows → person_id
  Phase G — Enrich spine from nc_datatrust (voter data, scores, demographics)

Rules (from RFC-001 + Eddie's backstory):
  - Jr/Sr/III in suffix BLOCKS merging — they are different people
  - Address block = last_name + zip5 + street_number (household detection)
  - Preferred name by source-weighted preponderance; VIP overrides win
  - Do NOT seed spine from golden_records or person_master

Usage:
  cd /Users/Broyhill/Desktop/BroyhillGOP-CURSOR
  python3 -m pipeline.identity_resolution [--phase A|B|C|D|E|F|G|all] [--dry-run]
"""

from __future__ import annotations

import argparse
import logging
import sys
import time

import psycopg2.extras
from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Phase A: Seed spine from NCBOE donors WITH voter_ncid
# One row per voter_ncid; take most recent address, aggregate donations.
# Suffix is carried as a BLOCKING field — prevents Jr/Sr/III merges.
# ---------------------------------------------------------------------------
PHASE_A_SQL = """
INSERT INTO core.person_spine (
  last_name, first_name, suffix,
  norm_last, norm_first, nickname_canonical,
  street, city, state, zip5, addr_hash,
  employer, occupation,
  voter_ncid,
  total_contributed, contribution_count,
  first_contribution, last_contribution, max_single_gift, avg_gift,
  preferred_first, preferred_name_source, preferred_name_confidence
)
SELECT
  agg.norm_last                               AS last_name,
  agg.norm_first                              AS first_name,
  agg.norm_suffix                             AS suffix,
  agg.norm_last,
  agg.norm_first,
  agg.norm_first                              AS nickname_canonical,
  agg.norm_street                             AS street,
  agg.norm_city                               AS city,
  COALESCE(agg.norm_state, 'NC')              AS state,
  agg.norm_zip5                               AS zip5,
  address_hash(agg.norm_street, agg.norm_city, agg.norm_zip5) AS addr_hash,
  agg.norm_employer                           AS employer,
  agg.norm_occupation                         AS occupation,
  agg.voter_ncid,
  agg.total_contrib,
  agg.contrib_count,
  agg.first_date,
  agg.last_date,
  agg.max_gift,
  CASE WHEN agg.contrib_count > 0
       THEN ROUND(agg.total_contrib / agg.contrib_count, 2) END AS avg_gift,
  agg.norm_first                              AS preferred_first,
  'NCBOE'                                     AS preferred_name_source,
  0.95                                        AS preferred_name_confidence
FROM (
  -- Most recent address per voter_ncid; suffix blocks Jr/Sr/III separation
  SELECT DISTINCT ON (voter_ncid)
    voter_ncid,
    norm_last,
    norm_first,
    norm_suffix,
    norm_street,
    norm_city,
    norm_state,
    norm_zip5,
    norm_employer,
    norm_occupation,
    SUM(amount) OVER (PARTITION BY voter_ncid)          AS total_contrib,
    COUNT(*) OVER (PARTITION BY voter_ncid)             AS contrib_count,
    MIN(transaction_date) OVER (PARTITION BY voter_ncid) AS first_date,
    MAX(transaction_date) OVER (PARTITION BY voter_ncid) AS last_date,
    MAX(amount) OVER (PARTITION BY voter_ncid)          AS max_gift
  FROM norm.nc_boe_donations
  WHERE voter_ncid IS NOT NULL
    AND norm_last IS NOT NULL AND norm_last != ''
    AND norm_first IS NOT NULL AND norm_first != ''
  ORDER BY voter_ncid, transaction_date DESC NULLS LAST
) agg
ON CONFLICT DO NOTHING;
"""

# ---------------------------------------------------------------------------
# Phase B: Add NCBOE donors WITHOUT voter_ncid
# Group by (norm_last, norm_first, norm_zip5, COALESCE(norm_suffix,''))
# to preserve Jr/Sr/III distinctness.
# ---------------------------------------------------------------------------
PHASE_B_SQL = """
INSERT INTO core.person_spine (
  last_name, first_name, suffix,
  norm_last, norm_first, nickname_canonical,
  street, city, state, zip5, addr_hash,
  employer, occupation,
  total_contributed, contribution_count,
  first_contribution, last_contribution, max_single_gift, avg_gift,
  preferred_first, preferred_name_source, preferred_name_confidence
)
SELECT
  grp.norm_last                               AS last_name,
  grp.norm_first                              AS first_name,
  NULLIF(grp.norm_suffix, '')                 AS suffix,
  grp.norm_last,
  grp.norm_first,
  grp.norm_first                              AS nickname_canonical,
  grp.norm_street                             AS street,
  grp.norm_city                               AS city,
  COALESCE(grp.norm_state, 'NC')              AS state,
  grp.norm_zip5                               AS zip5,
  address_hash(grp.norm_street, grp.norm_city, grp.norm_zip5) AS addr_hash,
  grp.norm_employer                           AS employer,
  grp.norm_occupation                         AS occupation,
  grp.total_contrib,
  grp.contrib_count,
  grp.first_date,
  grp.last_date,
  grp.max_gift,
  CASE WHEN grp.contrib_count > 0
       THEN ROUND(grp.total_contrib / grp.contrib_count, 2) END AS avg_gift,
  grp.norm_first                              AS preferred_first,
  'NCBOE'                                     AS preferred_name_source,
  0.80                                        AS preferred_name_confidence
FROM (
  SELECT
    norm_last,
    norm_first,
    COALESCE(norm_suffix, '')                 AS norm_suffix,
    norm_zip5,
    -- Most recent address for this name+zip group
    (ARRAY_REMOVE(ARRAY_AGG(norm_street    ORDER BY transaction_date DESC NULLS LAST), NULL))[1] AS norm_street,
    (ARRAY_REMOVE(ARRAY_AGG(norm_city      ORDER BY transaction_date DESC NULLS LAST), NULL))[1] AS norm_city,
    (ARRAY_REMOVE(ARRAY_AGG(norm_state     ORDER BY transaction_date DESC NULLS LAST), NULL))[1] AS norm_state,
    (ARRAY_REMOVE(ARRAY_AGG(norm_employer  ORDER BY transaction_date DESC NULLS LAST), NULL))[1] AS norm_employer,
    (ARRAY_REMOVE(ARRAY_AGG(norm_occupation ORDER BY transaction_date DESC NULLS LAST), NULL))[1] AS norm_occupation,
    SUM(amount)        AS total_contrib,
    COUNT(*)           AS contrib_count,
    MIN(transaction_date) AS first_date,
    MAX(transaction_date) AS last_date,
    MAX(amount)        AS max_gift
  FROM norm.nc_boe_donations
  WHERE voter_ncid IS NULL
    AND norm_last IS NOT NULL AND norm_last != ''
    AND norm_first IS NOT NULL AND norm_first != '' AND norm_first != 'UNKNOWN'
    AND norm_zip5 IS NOT NULL AND length(norm_zip5) = 5
  GROUP BY norm_last, norm_first, COALESCE(norm_suffix, ''), norm_zip5
) grp
ON CONFLICT DO NOTHING;
"""

# ---------------------------------------------------------------------------
# Phase C: Link norm.nc_boe_donations → person_id
# Pass 1 (voter_ncid), then Pass 3 (name+zip) for remainder
# ---------------------------------------------------------------------------
PHASE_C_PASS1_SQL = """
UPDATE norm.nc_boe_donations n
SET person_id = s.person_id
FROM core.person_spine s
WHERE n.person_id IS NULL
  AND n.voter_ncid IS NOT NULL
  AND n.voter_ncid = s.voter_ncid;
"""

PHASE_C_PASS3_SQL = """
UPDATE norm.nc_boe_donations n
SET person_id = s.person_id
FROM core.person_spine s
WHERE n.person_id IS NULL
  AND n.norm_last = s.norm_last
  AND n.norm_first = s.norm_first
  AND n.norm_zip5 = s.zip5
  AND COALESCE(n.norm_suffix, '') = COALESCE(s.suffix, '');
"""

# ---------------------------------------------------------------------------
# Phase D: Match FEC donors to existing spine rows
# Pass 3: exact name+zip
# Pass 5: first_initial + zip + employer (for nickname mismatches)
# ---------------------------------------------------------------------------
PHASE_D_PASS3_SQL = """
UPDATE norm.fec_individual f
SET person_id = s.person_id
FROM core.person_spine s
WHERE f.person_id IS NULL
  AND f.norm_last = s.norm_last
  AND f.norm_first = s.norm_first
  AND f.norm_zip5 = s.zip5
  AND COALESCE(f.norm_suffix, '') = COALESCE(s.suffix, '');
"""

PHASE_D_PASS5_SQL = """
UPDATE norm.fec_individual f
SET person_id = s.person_id
FROM core.person_spine s
WHERE f.person_id IS NULL
  AND f.norm_last = s.norm_last
  AND LEFT(f.norm_first, 1) = LEFT(s.norm_first, 1)
  AND f.norm_zip5 = s.zip5
  AND f.norm_employer IS NOT NULL AND s.employer IS NOT NULL
  AND f.norm_employer = s.employer
  AND COALESCE(f.norm_suffix, '') = COALESCE(s.suffix, '');
"""

# ---------------------------------------------------------------------------
# Phase E: Create new spine rows for FEC donors not matched to any NCBOE donor
# ---------------------------------------------------------------------------
PHASE_E_SQL = """
INSERT INTO core.person_spine (
  last_name, first_name, suffix,
  norm_last, norm_first, nickname_canonical,
  street, city, state, zip5, addr_hash,
  employer, occupation,
  total_contributed, contribution_count,
  first_contribution, last_contribution, max_single_gift, avg_gift,
  preferred_first, preferred_name_source, preferred_name_confidence
)
SELECT
  grp.norm_last,
  grp.norm_first,
  NULLIF(grp.norm_suffix, ''),
  grp.norm_last,
  grp.norm_first,
  grp.norm_first,
  grp.norm_street,
  grp.norm_city,
  grp.norm_state,
  grp.norm_zip5,
  address_hash(grp.norm_street, grp.norm_city, grp.norm_zip5),
  grp.norm_employer,
  grp.norm_occupation,
  grp.total_contrib,
  grp.contrib_count,
  grp.first_date,
  grp.last_date,
  grp.max_gift,
  CASE WHEN grp.contrib_count > 0
       THEN ROUND(grp.total_contrib / grp.contrib_count, 2) END,
  grp.norm_first,
  'FEC',
  0.75
FROM (
  SELECT
    f.norm_last,
    f.norm_first,
    COALESCE(f.norm_suffix, '')                           AS norm_suffix,
    f.norm_zip5,
    (ARRAY_REMOVE(ARRAY_AGG(f.norm_street     ORDER BY f.transaction_date DESC NULLS LAST), NULL))[1] AS norm_street,
    (ARRAY_REMOVE(ARRAY_AGG(f.norm_city       ORDER BY f.transaction_date DESC NULLS LAST), NULL))[1] AS norm_city,
    (ARRAY_REMOVE(ARRAY_AGG(f.norm_state      ORDER BY f.transaction_date DESC NULLS LAST), NULL))[1] AS norm_state,
    (ARRAY_REMOVE(ARRAY_AGG(f.norm_employer   ORDER BY f.transaction_date DESC NULLS LAST), NULL))[1] AS norm_employer,
    (ARRAY_REMOVE(ARRAY_AGG(f.norm_occupation ORDER BY f.transaction_date DESC NULLS LAST), NULL))[1] AS norm_occupation,
    SUM(f.amount)           AS total_contrib,
    COUNT(*)                AS contrib_count,
    MIN(f.transaction_date) AS first_date,
    MAX(f.transaction_date) AS last_date,
    MAX(f.amount)           AS max_gift
  FROM norm.fec_individual f
  WHERE f.person_id IS NULL
    AND f.norm_last IS NOT NULL AND f.norm_last != ''
    AND f.norm_first IS NOT NULL AND f.norm_first != '' AND f.norm_first != 'UNKNOWN'
    AND f.norm_zip5 IS NOT NULL AND length(f.norm_zip5) = 5
  GROUP BY f.norm_last, f.norm_first, COALESCE(f.norm_suffix, ''), f.norm_zip5
) grp
ON CONFLICT DO NOTHING;
"""

# ---------------------------------------------------------------------------
# Phase F: Link remaining norm.fec_individual rows → person_id (after Phase E)
# ---------------------------------------------------------------------------
PHASE_F_SQL = """
UPDATE norm.fec_individual f
SET person_id = s.person_id
FROM core.person_spine s
WHERE f.person_id IS NULL
  AND f.norm_last = s.norm_last
  AND f.norm_first = s.norm_first
  AND f.norm_zip5 = s.zip5
  AND COALESCE(f.norm_suffix, '') = COALESCE(s.suffix, '');
"""

# ---------------------------------------------------------------------------
# Phase G: Enrich spine from nc_datatrust
# Pull voter_ncid (via statevoterid), party, birth_year, sex, race, cell, landline, scores
# ---------------------------------------------------------------------------
PHASE_G_SQL = """
UPDATE core.person_spine s
SET
  voter_ncid       = COALESCE(s.voter_ncid, dt.statevoterid),
  voter_party      = COALESCE(s.voter_party, dt.registeredparty),
  birth_year       = COALESCE(s.birth_year, CASE WHEN dt.birthyear ~ '^[0-9]{4}$'
                              THEN dt.birthyear::INTEGER ELSE NULL END),
  sex              = COALESCE(s.sex, dt.sex),
  cell_phone       = COALESCE(s.cell_phone, NULLIF(dt.cell, '')),
  cell_source      = CASE WHEN s.cell_phone IS NULL AND NULLIF(dt.cell,'') IS NOT NULL
                          THEN 'DATATRUST' ELSE s.cell_source END,
  landline         = COALESCE(s.landline, NULLIF(dt.landline, '')),
  voter_rncid      = COALESCE(s.voter_rncid, dt.rncid),
  is_registered_voter = true,
  updated_at       = NOW()
FROM public.nc_datatrust dt
WHERE s.voter_ncid IS NOT NULL
  AND s.voter_ncid = dt.statevoterid
  AND (s.voter_party IS NULL OR s.birth_year IS NULL OR s.sex IS NULL
       OR s.cell_phone IS NULL);
"""

# ---------------------------------------------------------------------------
# Phase G2: Match spine rows without voter_ncid to DataTrust by name+zip
# (unique matches only — exactly 1 DataTrust record for that name+zip)
# ---------------------------------------------------------------------------
PHASE_G2_SQL = """
UPDATE core.person_spine s
SET
  voter_ncid       = dt_match.statevoterid,
  voter_party      = dt_match.registeredparty,
  birth_year       = CASE WHEN dt_match.birthyear ~ '^[0-9]{4}$'
                          THEN dt_match.birthyear::INTEGER ELSE NULL END,
  sex              = dt_match.sex,
  cell_phone       = COALESCE(s.cell_phone, NULLIF(dt_match.cell, '')),
  cell_source      = CASE WHEN s.cell_phone IS NULL AND NULLIF(dt_match.cell,'') IS NOT NULL
                          THEN 'DATATRUST' ELSE s.cell_source END,
  landline         = COALESCE(s.landline, NULLIF(dt_match.landline, '')),
  voter_rncid      = dt_match.rncid,
  is_registered_voter = true,
  updated_at       = NOW()
FROM (
  SELECT dt.statevoterid, dt.registeredparty, dt.birthyear,
         dt.sex, dt.cell, dt.landline, dt.rncid,
         dt.lastname, dt.firstname, dt.regzip5
  FROM public.nc_datatrust dt
  WHERE EXISTS (
    SELECT 1 FROM core.person_spine s2
    WHERE s2.voter_ncid IS NULL
      AND s2.norm_last = dt.lastname
      AND s2.norm_first = dt.firstname
      AND s2.zip5 = dt.regzip5
  )
) dt_match
WHERE s.voter_ncid IS NULL
  AND s.norm_last = dt_match.lastname
  AND s.norm_first = dt_match.firstname
  AND s.zip5 = dt_match.regzip5
  -- Only unique DataTrust matches
  AND (
    SELECT COUNT(*) FROM public.nc_datatrust dt2
    WHERE dt2.lastname = s.norm_last
      AND dt2.firstname = s.norm_first
      AND dt2.regzip5 = s.zip5
  ) = 1
  -- Prevent assigning a voter_ncid already used by another spine row
  AND NOT EXISTS (
    SELECT 1 FROM core.person_spine s2
    WHERE s2.voter_ncid = dt_match.statevoterid
  );
"""


def _run_phase(conn, name: str, sql: str, dry_run: bool) -> int:
    if dry_run:
        logger.info("  [DRY RUN] would execute: %s", name)
        return 0
    start = time.time()
    with conn.cursor() as cur:
        cur.execute(sql)
        rows = cur.rowcount
    elapsed = time.time() - start
    logger.info("  %s: %s rows affected in %.0fs", name, f"{rows:,}", elapsed)
    return rows


def _count(conn, table: str, where: str = '') -> int:
    with conn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) FROM {table} {where}")
        return cur.fetchone()[0] or 0


def run(phases: list[str], dry_run: bool) -> None:
    init_pool()

    phase_map = {
        'A': ('Seed spine from NCBOE voter_ncid-matched donors', PHASE_A_SQL),
        'B': ('Add remaining NCBOE donors (no voter_ncid) by name+zip', PHASE_B_SQL),
        'C1': ('Link NCBOE→spine: Pass 1 voter_ncid', PHASE_C_PASS1_SQL),
        'C3': ('Link NCBOE→spine: Pass 3 name+zip', PHASE_C_PASS3_SQL),
        'D3': ('Match FEC→spine: Pass 3 exact name+zip', PHASE_D_PASS3_SQL),
        'D5': ('Match FEC→spine: Pass 5 initial+zip+employer', PHASE_D_PASS5_SQL),
        'E': ('Create new spine rows for unmatched FEC donors', PHASE_E_SQL),
        'F': ('Link remaining FEC→spine after Phase E', PHASE_F_SQL),
        'G': ('Enrich spine from DataTrust (voter_ncid matched)', PHASE_G_SQL),
        'G2': ('Enrich spine from DataTrust (name+zip match, unique only)', PHASE_G2_SQL),
    }

    run_all = 'all' in phases
    ordered = ['A', 'B', 'C1', 'C3', 'D3', 'D5', 'E', 'F', 'G', 'G2']
    to_run = ordered if run_all else [p for p in ordered if p in phases]

    for phase_key in to_run:
        if phase_key not in phase_map:
            logger.warning("Unknown phase: %s", phase_key)
            continue
        label, sql = phase_map[phase_key]
        print(f"\n{'[DRY RUN] ' if dry_run else ''}Phase {phase_key}: {label}")
        with get_connection() as conn:
            _run_phase(conn, phase_key, sql, dry_run)

    # Summary
    print("\n--- Final counts ---")
    with get_connection() as conn:
        spine = _count(conn, 'core.person_spine')
        spine_ncid = _count(conn, 'core.person_spine', 'WHERE voter_ncid IS NOT NULL')
        spine_cell = _count(conn, 'core.person_spine', 'WHERE cell_phone IS NOT NULL')
        boe_linked = _count(conn, 'norm.nc_boe_donations', 'WHERE person_id IS NOT NULL')
        boe_total = _count(conn, 'norm.nc_boe_donations')
        fec_linked = _count(conn, 'norm.fec_individual', 'WHERE person_id IS NOT NULL')
        fec_total = _count(conn, 'norm.fec_individual')

    print(f"  core.person_spine:        {spine:>10,} rows")
    print(f"    with voter_ncid:        {spine_ncid:>10,} ({spine_ncid*100//spine if spine else 0}%)")
    print(f"    with cell_phone:        {spine_cell:>10,} ({spine_cell*100//spine if spine else 0}%)")
    print(f"  norm.nc_boe_donations:    {boe_linked:>10,} / {boe_total:,} linked ({boe_linked*100//boe_total if boe_total else 0}%)")
    print(f"  norm.fec_individual:      {fec_linked:>10,} / {fec_total:,} linked ({fec_linked*100//fec_total if fec_total else 0}%)")


def main() -> int:
    parser = argparse.ArgumentParser(description="RFC-001 identity resolution")
    parser.add_argument(
        '--phase',
        nargs='+',
        default=['all'],
        help='Phases to run: A B C1 C3 D3 D5 E F G G2 (or "all")',
    )
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format='%(message)s',
    )

    run(phases=args.phase, dry_run=args.dry_run)
    return 0


if __name__ == '__main__':
    sys.exit(main())
