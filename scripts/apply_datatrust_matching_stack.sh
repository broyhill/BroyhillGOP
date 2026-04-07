#!/usr/bin/env bash
# Apply DataTrust matching stack in order: 097 → 098 → procedures.
# Requires: SUPABASE_DB_URL or first argument = postgres connection string.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="${1:-${SUPABASE_DB_URL:-}}"
if [[ -z "$URL" ]]; then
  echo "Usage: SUPABASE_DB_URL=... $0   OR   $0 'postgresql://...'" >&2
  exit 1
fi
psql "$URL" -v ON_ERROR_STOP=1 -f "$ROOT/database/migrations/097_INTEGRATION_DATATRUST_CONTACT_LINK.sql"
psql "$URL" -v ON_ERROR_STOP=1 -f "$ROOT/database/migrations/098_UNIFIED_CONTACTS_STUB_AND_DATATRUST_BACKFILL.sql"
psql "$URL" -v ON_ERROR_STOP=1 -f "$ROOT/database/schemas/datatrust_matching_procedures.sql"
echo "OK — DataTrust matching stack applied."
