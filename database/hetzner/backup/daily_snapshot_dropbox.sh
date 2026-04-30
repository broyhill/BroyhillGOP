#!/bin/bash
# =============================================================================
# BroyhillGOP — Daily pg_dump Snapshot → Dropbox
# =============================================================================
# Server:  Hetzner AX162 — 37.27.169.232
# DB:      PostgreSQL 16, ~145 GB (compressed ~30-40 GB)
# Runs:    Daily at 3:00 AM via cron  (after PITR base backup at 2:00 AM)
#
# What this does:
#   1. pg_dump --format=custom (compressed, parallel, supports per-table restore)
#   2. Upload to Dropbox via rclone
#   3. Prune local copies older than 3 days (Dropbox keeps 14 days)
#   4. Log everything to backup.backup_history
#
# Dropbox path: /BroyhillGOP/backups/daily/bgop_YYYYMMDD_HHMMSS.dump
#
# Why BOTH pg_dump AND the PITR system?
#   - PITR = binary-level, fastest full restore, continuous WAL replay
#   - pg_dump = logical, portable, supports per-table/per-candidate restore
#   - pg_dump on Dropbox = off-site disaster recovery (server dies = still have data)
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BACKUP_ROOT="/opt/pgbackup"
SNAPSHOT_DIR="${BACKUP_ROOT}/snapshots"
LOG_DIR="${BACKUP_ROOT}/logs"
SCRIPTS_DIR="${BACKUP_ROOT}/scripts"

DB_HOST="127.0.0.1"
DB_USER="postgres"
DB_NAME="postgres"
DB_PASS="${PG_PASSWORD}"

RCLONE_REMOTE="dropbox"               # rclone remote name (configured during setup)
DROPBOX_PATH="BroyhillGOP/backups/daily"
LOCAL_RETENTION_DAYS=3                 # Keep local snapshots 3 days
DROPBOX_RETENTION_DAYS=14              # Keep Dropbox snapshots 14 days
PARALLEL_JOBS=8                        # pg_dump parallel workers (96 CPU box)

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="bgop_${TIMESTAMP}.dump"
DUMP_PATH="${SNAPSHOT_DIR}/${DUMP_FILE}"
LOG_FILE="${LOG_DIR}/snapshot_${TIMESTAMP}.log"

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "${SNAPSHOT_DIR}" "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================="
echo "BroyhillGOP Daily Snapshot"
echo "Started: $(date)"
echo "============================================="

# ── Step 1: pg_dump ───────────────────────────────────────────────────────────
echo "[1/4] Running pg_dump (custom format, ${PARALLEL_JOBS} workers)..."
START_TIME=$(date +%s)

PGPASSWORD="${DB_PASS}" pg_dump \
    -h "${DB_HOST}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --format=custom \
    --compress=6 \
    --jobs="${PARALLEL_JOBS}" \
    --verbose \
    --file="${DUMP_PATH}" \
    2>&1 | tail -5

END_TIME=$(date +%s)
DUMP_ELAPSED=$((END_TIME - START_TIME))
DUMP_SIZE=$(du -sh "${DUMP_PATH}" | cut -f1)
DUMP_SIZE_BYTES=$(stat -c %s "${DUMP_PATH}")

echo "  → Dump complete: ${DUMP_SIZE} in ${DUMP_ELAPSED}s"

# ── Step 2: Upload to Dropbox ─────────────────────────────────────────────────
echo "[2/4] Uploading to Dropbox (${DROPBOX_PATH}/${DUMP_FILE})..."
UPLOAD_START=$(date +%s)

if command -v rclone &>/dev/null; then
    rclone copy "${DUMP_PATH}" "${RCLONE_REMOTE}:${DROPBOX_PATH}/" \
        --progress \
        --transfers=4 \
        --checkers=4 \
        --dropbox-chunk-size=150M \
        2>&1 | tail -3

    UPLOAD_END=$(date +%s)
    UPLOAD_ELAPSED=$((UPLOAD_END - UPLOAD_START))
    UPLOAD_OK=true

    # Verify upload
    REMOTE_SIZE=$(rclone size "${RCLONE_REMOTE}:${DROPBOX_PATH}/${DUMP_FILE}" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('bytes',0))" 2>/dev/null || echo "0")
    if [ "${REMOTE_SIZE}" -gt 0 ]; then
        echo "  → Upload verified: $(numfmt --to=iec ${REMOTE_SIZE}) on Dropbox in ${UPLOAD_ELAPSED}s"
    else
        echo "  ⚠  Upload completed but could not verify remote size"
    fi
else
    echo "  ⚠  rclone not installed — snapshot saved locally only"
    echo "  Run: curl https://rclone.org/install.sh | bash && rclone config"
    UPLOAD_OK=false
    UPLOAD_ELAPSED=0
fi

# ── Step 3: Prune old snapshots ───────────────────────────────────────────────
echo "[3/4] Pruning old snapshots..."

# Local: keep 3 days
LOCAL_DELETED=$(find "${SNAPSHOT_DIR}" -name "bgop_*.dump" -mtime +${LOCAL_RETENTION_DAYS} -print -delete 2>/dev/null | wc -l)
echo "  → Deleted ${LOCAL_DELETED} local snapshots older than ${LOCAL_RETENTION_DAYS} days"

# Dropbox: keep 14 days
if [ "${UPLOAD_OK:-false}" = true ] && command -v rclone &>/dev/null; then
    REMOTE_DELETED=$(rclone delete "${RCLONE_REMOTE}:${DROPBOX_PATH}/" \
        --min-age "${DROPBOX_RETENTION_DAYS}d" \
        --dry-run 2>&1 | grep -c "NOTICE:" || echo "0")
    rclone delete "${RCLONE_REMOTE}:${DROPBOX_PATH}/" \
        --min-age "${DROPBOX_RETENTION_DAYS}d" 2>/dev/null || true
    echo "  → Cleaned ~${REMOTE_DELETED} Dropbox snapshots older than ${DROPBOX_RETENTION_DAYS} days"
fi

# ── Step 4: Record in tracking table ──────────────────────────────────────────
echo "[4/4] Recording in backup.backup_history..."

PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
INSERT INTO backup.backup_history
    (backup_type, backup_path, backup_size_bytes, duration_seconds, status, details)
VALUES
    ('snapshot', '${DUMP_PATH}', ${DUMP_SIZE_BYTES}, ${DUMP_ELAPSED}, 'completed',
     jsonb_build_object(
         'format', 'custom',
         'compression', 6,
         'parallel_jobs', ${PARALLEL_JOBS},
         'dropbox_path', '${DROPBOX_PATH}/${DUMP_FILE}',
         'dropbox_uploaded', ${UPLOAD_OK:-false},
         'upload_seconds', ${UPLOAD_ELAPSED},
         'local_file', '${DUMP_PATH}'
     ));
" 2>/dev/null || echo "Warning: Could not record snapshot in tracking table"

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL_END=$(date +%s)
TOTAL_ELAPSED=$((TOTAL_END - START_TIME))

echo ""
echo "============================================="
echo "Snapshot Complete: $(date)"
echo "============================================="
echo "  File:     ${DUMP_PATH}"
echo "  Size:     ${DUMP_SIZE}"
echo "  Dump:     ${DUMP_ELAPSED}s"
echo "  Upload:   ${UPLOAD_ELAPSED}s"
echo "  Total:    ${TOTAL_ELAPSED}s"
echo "  Dropbox:  ${DROPBOX_PATH}/${DUMP_FILE}"
echo ""
echo "To restore full DB:  ${SCRIPTS_DIR}/snapshot_restore.sh ${DUMP_PATH}"
echo "To restore 1 candidate: ${SCRIPTS_DIR}/candidate_restore.sh <candidate_id> ${DUMP_PATH}"
echo "============================================="
