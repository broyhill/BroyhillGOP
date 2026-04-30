#!/bin/bash
# =============================================================================
# BroyhillGOP — Full DB Restore from pg_dump Snapshot
# =============================================================================
# One-command restore from a daily pg_dump snapshot (local or from Dropbox).
#
# Usage:
#   ./snapshot_restore.sh <snapshot_file>         Restore from local .dump
#   ./snapshot_restore.sh latest                  Restore from latest local snapshot
#   ./snapshot_restore.sh dropbox                 List available Dropbox snapshots
#   ./snapshot_restore.sh dropbox <filename>      Download + restore from Dropbox
#   ./snapshot_restore.sh list                    List local snapshots
#
# What happens:
#   1. Stops all active connections (except this one)
#   2. Creates a safety pg_dump of current state
#   3. Drops and recreates the database
#   4. Restores from the snapshot
#   5. Verifies row counts
#   6. Records in backup.restore_log (after restore)
#
# WARNING: This replaces the ENTIRE database. For single-candidate fix, use
#          candidate_restore.sh instead.
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/opt/pgbackup"
SNAPSHOT_DIR="${BACKUP_ROOT}/snapshots"
LOG_DIR="${BACKUP_ROOT}/logs"
SCRIPTS_DIR="${BACKUP_ROOT}/scripts"
DB_HOST="127.0.0.1"
DB_USER="postgres"
DB_NAME="postgres"
DB_PASS="${PG_PASSWORD}"
RCLONE_REMOTE="dropbox"
DROPBOX_PATH="BroyhillGOP/backups/daily"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SOURCE="${1:-}"
REMOTE_FILE="${2:-}"

# ── List mode ─────────────────────────────────────────────────────────────────
if [ "${SOURCE}" = "list" ]; then
    echo "============================================="
    echo "Local Snapshots"
    echo "============================================="
    for f in $(ls -1t "${SNAPSHOT_DIR}"/bgop_*.dump 2>/dev/null); do
        FDATE=$(stat -c %Y "${f}" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S")
        FSIZE=$(du -sh "${f}" | cut -f1)
        echo "  ${f}  |  ${FDATE}  |  ${FSIZE}"
    done
    echo ""
    echo "DB snapshots in Dropbox:"
    if command -v rclone &>/dev/null; then
        rclone ls "${RCLONE_REMOTE}:${DROPBOX_PATH}/" 2>/dev/null | while read SIZE NAME; do
            echo "  ${NAME}  |  $(numfmt --to=iec ${SIZE})"
        done
    else
        echo "  (rclone not installed — cannot list Dropbox)"
    fi
    exit 0
fi

# ── Dropbox download mode ────────────────────────────────────────────────────
if [ "${SOURCE}" = "dropbox" ]; then
    if ! command -v rclone &>/dev/null; then
        echo -e "${RED}rclone not installed. Install: curl https://rclone.org/install.sh | bash${NC}"
        exit 1
    fi
    if [ -z "${REMOTE_FILE}" ]; then
        echo "Available Dropbox snapshots:"
        rclone ls "${RCLONE_REMOTE}:${DROPBOX_PATH}/" 2>/dev/null
        echo ""
        echo "Usage: $0 dropbox <filename>"
        exit 0
    fi
    echo "Downloading ${REMOTE_FILE} from Dropbox..."
    rclone copy "${RCLONE_REMOTE}:${DROPBOX_PATH}/${REMOTE_FILE}" "${SNAPSHOT_DIR}/" --progress
    SOURCE="${SNAPSHOT_DIR}/${REMOTE_FILE}"
    echo "  → Downloaded to ${SOURCE}"
fi

# ── Resolve snapshot ──────────────────────────────────────────────────────────
if [ "${SOURCE}" = "latest" ]; then
    SOURCE=$(ls -1t "${SNAPSHOT_DIR}"/bgop_*.dump 2>/dev/null | head -1)
    if [ -z "${SOURCE}" ]; then
        echo -e "${RED}No local snapshots found in ${SNAPSHOT_DIR}${NC}"
        exit 1
    fi
fi

if [ -z "${SOURCE}" ]; then
    echo "Usage:"
    echo "  $0 <snapshot.dump>     Restore from file"
    echo "  $0 latest              Most recent local snapshot"
    echo "  $0 list                List all snapshots"
    echo "  $0 dropbox             List/download Dropbox snapshots"
    exit 1
fi

if [ ! -f "${SOURCE}" ]; then
    echo -e "${RED}File not found: ${SOURCE}${NC}"
    exit 1
fi

SNAP_DATE=$(stat -c %Y "${SOURCE}" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S")
SNAP_SIZE=$(du -sh "${SOURCE}" | cut -f1)

# ── Confirmation ──────────────────────────────────────────────────────────────
echo -e "${RED}============================================="
echo "   FULL DATABASE RESTORE"
echo "=============================================${NC}"
echo ""
echo "  Snapshot: $(basename ${SOURCE})"
echo "  Taken:    ${SNAP_DATE}"
echo "  Size:     ${SNAP_SIZE}"
echo ""
echo -e "${YELLOW}WARNING: This will REPLACE the entire database!${NC}"
echo "  - All current data will be overwritten"
echo "  - A safety dump of current state will be saved first"
echo "  - All active connections will be terminated"
echo ""
echo "For single-candidate fix, use candidate_restore.sh instead."
echo ""
read -p "Type RESTORE to proceed: " CONFIRM
if [ "${CONFIRM}" != "RESTORE" ]; then
    echo "Aborted."
    exit 1
fi

RESTORE_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/restore_${RESTORE_TIMESTAMP}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo ""
START_TIME=$(date +%s)

# ── Step 1: Safety dump ───────────────────────────────────────────────────────
echo "[1/4] Creating safety dump of current state..."
SAFETY_FILE="${SNAPSHOT_DIR}/safety_prerestore_${RESTORE_TIMESTAMP}.dump"

PGPASSWORD="${DB_PASS}" pg_dump \
    -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" \
    --format=custom --compress=6 \
    --file="${SAFETY_FILE}" 2>&1 | tail -3

SAFETY_SIZE=$(du -sh "${SAFETY_FILE}" | cut -f1)
echo "  → Safety dump: ${SAFETY_FILE} (${SAFETY_SIZE})"

# ── Step 2: Terminate connections ─────────────────────────────────────────────
echo "[2/4] Terminating active connections..."

PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${DB_NAME}'
  AND pid != pg_backend_pid()
  AND state != 'idle';
" 2>/dev/null || true

sleep 2
echo "  → Connections terminated"

# ── Step 3: Restore ──────────────────────────────────────────────────────────
echo "[3/4] Restoring from snapshot (this may take 15-30 minutes)..."

# pg_restore with --clean drops objects before recreating
PGPASSWORD="${DB_PASS}" pg_restore \
    -h "${DB_HOST}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --clean \
    --if-exists \
    --jobs=8 \
    --verbose \
    "${SOURCE}" 2>&1 | tail -20

echo "  → Restore complete"

# ── Step 4: Verify ───────────────────────────────────────────────────────────
echo "[4/4] Verifying restore..."

PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
SELECT schemaname || '.' || relname AS table_name, n_live_tup AS rows
FROM pg_stat_user_tables
WHERE n_live_tup > 0
ORDER BY n_live_tup DESC
LIMIT 20;
"

DB_SIZE=$(PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c \
    "SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));")

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# Record restore
PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
INSERT INTO backup.restore_log
    (restore_type, source_backup, status, details)
VALUES
    ('full', '$(basename ${SOURCE})', 'completed',
     jsonb_build_object(
         'source_file', '${SOURCE}',
         'snapshot_date', '${SNAP_DATE}',
         'safety_backup', '${SAFETY_FILE}',
         'restore_seconds', ${ELAPSED},
         'db_size_after', '${DB_SIZE}'
     ));
" 2>/dev/null || echo "Warning: Could not record restore in tracking table"

echo ""
echo -e "${GREEN}============================================="
echo "   RESTORE COMPLETE"
echo "=============================================${NC}"
echo ""
echo "  Source:    $(basename ${SOURCE}) (${SNAP_DATE})"
echo "  DB size:   ${DB_SIZE}"
echo "  Duration:  ${ELAPSED}s"
echo ""
echo "  Safety backup: ${SAFETY_FILE}"
echo "  To undo: $0 ${SAFETY_FILE}"
echo "============================================="
