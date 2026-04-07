#!/usr/bin/env bash
# Wave 1: raw → norm after GOLD ingest (see wave1_ingest_gold_ncboe.sh).
#
# Usage:
#   bash scripts/wave1_normalize_ncboe.sh
#   bash scripts/wave1_normalize_ncboe.sh --dry-run

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="${PYTHON:-python3}"
args=()
if [[ "${1:-}" == "--dry-run" ]]; then
  args=(--dry-run)
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--dry-run]" >&2
  exit 1
fi

exec "$PY" "$ROOT/scripts/normalize_ncboe.py" "${args[@]}"
