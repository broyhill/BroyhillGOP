#!/usr/bin/env bash
# Wave 1: ingest all NCBOE GOP individual CSVs from NCBOE DONORS GOLD (Desktop).
# Does not touch FEC. Idempotent per file via pipeline.loaded_ncboe_files (see import_ncboe_raw.py).
# DB prep (voter flags / ref views): database/migrations/088_WAVE1_VOTER_DATATRUST_FOUNDATION.sql then 089_*.
#
# Usage:
#   export SUPABASE_DB_URL='postgresql://...'   # or rely on scripts/.env via db_conn
#   bash scripts/wave1_ingest_gold_ncboe.sh
#
# Override folder:
#   GOLD_DIR=/path/to/csvs bash scripts/wave1_ingest_gold_ncboe.sh

set -euo pipefail

GOLD_DIR="${GOLD_DIR:-$HOME/Desktop/NCBOE DONORS GOLD}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="${PYTHON:-python3}"

if [[ ! -d "$GOLD_DIR" ]]; then
  echo "ERROR: GOLD_DIR not found: $GOLD_DIR" >&2
  exit 1
fi

echo "Wave 1 NCBOE GOLD ingest from: $GOLD_DIR"
shopt -s nullglob
files=("$GOLD_DIR"/*.csv)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "ERROR: No .csv files in $GOLD_DIR" >&2
  exit 1
fi

for f in "${files[@]}"; do
  echo "---- $(basename "$f") ----"
  "$PY" "$ROOT/scripts/import_ncboe_raw.py" "$f"
done

echo "Done. Record snapshot in pipeline.wave1_source_snapshots if desired:"
echo "  INSERT INTO pipeline.wave1_source_snapshots (source_name, snapshot_label, notes)"
echo "  VALUES ('ncboe_gold_desktop', '$(date +%Y-%m-%d)', 'wave1_ingest_gold_ncboe.sh');"
