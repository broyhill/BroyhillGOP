#!/usr/bin/env bash
# Apply Phase D DDL on Hetzner Postgres (37.27.169.232). Does not touch Supabase.
# Usage on server after git pull:
#   export HETZNER_DB_URL='postgresql://postgres:PASSWORD@127.0.0.1:5432/postgres?sslmode=disable'
#   bash scripts/hetzner_apply_099_ncboe.sh

set -euo pipefail
: "${HETZNER_DB_URL:?Set HETZNER_DB_URL to local postgres on the AX162}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
psql "$HETZNER_DB_URL" -v ON_ERROR_STOP=1 -f "$ROOT/database/migrations/099_raw_ncboe_donations_gold_hetzner.sql"
mkdir -p /data/ncboe/gold
echo "OK: raw.ncboe_donations + employer_sic_master shell. GOLD CSVs → /data/ncboe/gold"
echo "Dry-run parse: cd $ROOT && HETZNER_DB_URL=... python3 -m pipeline.ncboe_normalize_pipeline --file /path/to/sample.csv"
echo "Dedup Stage1:  HETZNER_DB_URL=... python3 -m pipeline.ncboe_internal_dedup"
