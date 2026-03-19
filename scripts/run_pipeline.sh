#!/bin/bash
# NCBOE + NCGOP Pipeline — Run in order from project root
# Usage: ./scripts/run_pipeline.sh [path/to/NCGOP_file.csv]

set -e
cd "$(dirname "$0")/.."

NCGOP_FILE="${1:-GOD-North_Carolina_Republican_PartyNCGOP_FinancialSearch_07122024_1156.csv}"

if [ ! -f "$NCGOP_FILE" ]; then
  echo "ERROR: NCGOP file not found: $NCGOP_FILE"
  echo "Usage: $0 [path/to/NCGOP_file.csv]"
  exit 1
fi

echo "=== Step 1: Validate NCGOP file schema ==="
python3 scripts/validate_source_files.py "$NCGOP_FILE"

echo ""
echo "=== Step 2: Stage NCGOP (isolated) ==="
python3 scripts/import_ncgop_staging.py "$NCGOP_FILE"

echo ""
echo "=== Step 3: Match NCGOP → voter file ==="
python3 scripts/match_ncgop_to_voters.py

echo ""
echo "=== Step 4: Normalize NCBOE raw → norm table ==="
python3 scripts/normalize_ncboe.py

echo ""
echo "=== Step 5: Dry run golden records ==="
python3 scripts/build_donor_golden_records.py --dry-run

echo ""
echo "=== Step 6: Dry run contributions ==="
python3 scripts/build_contributions.py --dry-run

echo ""
echo "=== Pipeline complete. Review Steps 5–6 dry-run output before running live. ==="
