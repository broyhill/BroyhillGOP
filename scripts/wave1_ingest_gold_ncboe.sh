#!/usr/bin/env bash
# Wave 1: ingest all NCBOE GOP individual CSVs from NCBOE DONORS GOLD (Desktop).
# Does not touch FEC. Idempotent per file via pipeline.loaded_ncboe_files (see import_ncboe_raw.py).
# DB prep (voter flags / ref views): database/migrations/088_WAVE1_VOTER_DATATRUST_FOUNDATION.sql then 089_*.
#
# Usage:
#   export SUPABASE_DB_URL='postgresql://...'   # or rely on scripts/.env via db_conn
#   bash scripts/wave1_ingest_gold_ncboe.sh
#   bash scripts/wave1_ingest_gold_ncboe.sh --dry-run   # validate headers + row counts only (no DB)
#
# Override folder:
#   GOLD_DIR=/path/to/csvs bash scripts/wave1_ingest_gold_ncboe.sh

set -euo pipefail

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

GOLD_DIR="${GOLD_DIR:-$HOME/Desktop/NCBOE DONORS GOLD}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="${PYTHON:-python3}"
EXTRA=()
if [[ "$DRY_RUN" -eq 1 ]]; then
  EXTRA=(--dry-run)
  echo "DRY RUN: no database writes; validating NCBOE CSVs only."
fi

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
  "$PY" "$ROOT/scripts/import_ncboe_raw.py" "${EXTRA[@]}" "$f"
done

echo "Done. Optional next steps:"
echo "  1) Record load: INSERT INTO pipeline.wave1_source_snapshots (source_name, snapshot_label, notes)"
echo "     VALUES ('ncboe_gold_desktop', '$(date +%Y-%m-%d)', 'wave1_ingest_gold_ncboe.sh');"
echo "  2) Normalize raw → norm:  bash $ROOT/scripts/wave1_normalize_ncboe.sh"
echo "     (or: $PY $ROOT/scripts/normalize_ncboe.py — same; uses .env / SUPABASE_DB_URL)"
