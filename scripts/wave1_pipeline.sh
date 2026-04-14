#!/usr/bin/env bash
# Wave 1 — one entry point: GOLD NCBOE ingest then normalize (optional dry-run).
#
# Usage:
#   bash scripts/wave1_pipeline.sh                  # full ingest + normalize (needs DB)
#   bash scripts/wave1_pipeline.sh --dry-run        # validate CSVs + count norm backlog only
#   bash scripts/wave1_pipeline.sh --ingest-only
#   bash scripts/wave1_pipeline.sh --normalize-only
#
# Environment: GOLD_DIR (default ~/Desktop/NCBOE DONORS GOLD), PYTHON, .env with DB URL.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY=()
INGEST=1
NORM=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=(--dry-run); shift ;;
    --ingest-only) NORM=0; shift ;;
    --normalize-only) INGEST=0; shift ;;
    -h|--help)
      grep '^#' "$0" | head -11 | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$INGEST" -eq 1 ]]; then
  bash "$ROOT/scripts/wave1_ingest_gold_ncboe.sh" "${DRY[@]}"
fi

if [[ "$NORM" -eq 1 ]]; then
  bash "$ROOT/scripts/wave1_normalize_ncboe.sh" "${DRY[@]}"
fi

if [[ ${#DRY[@]} -gt 0 ]]; then dry_label="${DRY[*]}"; else dry_label="no"; fi
echo "wave1_pipeline: done (ingest=$INGEST norm=$NORM dry=$dry_label)."
