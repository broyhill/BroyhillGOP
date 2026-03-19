#!/bin/bash
# NCBOE Pipeline Audit — run via psql (no Python pipeline dependency)
# Usage: ./scripts/audit_ncboe.sh
# Requires: SUPABASE_DB_URL or DATABASE_URL in env, or pass URL as $1

set -e
# Load .env from project root if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
[[ -f "$PROJECT_ROOT/.env" ]] && set -a && source "$PROJECT_ROOT/.env" && set +a

URL="${1:-${SUPABASE_DB_URL:-${DATABASE_URL}}}"
if [[ -z "$URL" ]]; then
  echo "Error: Set SUPABASE_DB_URL or DATABASE_URL, or pass URL as first arg"
  exit 1
fi

echo "============================================================"
echo "NCBOE PIPELINE AUDIT"
echo "============================================================"

echo ""
echo "--- nc_boe_donations_raw ---"
psql "$URL" -t -A -c "SELECT 'total: ' || count(*) FROM public.nc_boe_donations_raw"
psql "$URL" -t -A -c "SELECT 'individual: ' || count(*) FROM public.nc_boe_donations_raw WHERE transaction_type = 'Individual'"
psql "$URL" -t -A -c "SELECT 'with_voter_ncid: ' || count(*) FROM public.nc_boe_donations_raw WHERE voter_ncid IS NOT NULL"
psql "$URL" -t -A -c "SELECT 'with_dedup_key: ' || count(*) FROM public.nc_boe_donations_raw WHERE dedup_key IS NOT NULL"

echo ""
echo "--- identity_clusters (nc_boe) ---"
psql "$URL" -t -A -c "SELECT 'clusters: ' || count(*) FROM pipeline.identity_clusters WHERE source_system = 'nc_boe'"
psql "$URL" -t -A -c "SELECT 'total_members: ' || coalesce(sum(member_count), 0) FROM pipeline.identity_clusters WHERE source_system = 'nc_boe'"

echo ""
echo "--- identity_pass_log ---"
psql "$URL" -c "SELECT pass_name, status, rows_matched, rows_remaining, last_run_at FROM pipeline.identity_pass_log WHERE pass_name LIKE '%nc_boe%' OR pass_name LIKE '%dedup%' ORDER BY last_run_at DESC LIMIT 5"

echo ""
echo "--- staging.ncboe_archive ---"
psql "$URL" -t -A -c "SELECT 'archived: ' || count(*) FROM staging.ncboe_archive"

echo ""
echo "--- core.ncboe_committee_registry ---"
psql "$URL" -t -A -c "SELECT 'committees: ' || count(*) FROM core.ncboe_committee_registry"

echo ""
echo "============================================================"
