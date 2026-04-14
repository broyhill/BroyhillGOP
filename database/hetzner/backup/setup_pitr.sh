#!/bin/bash
# =============================================================================
# BroyhillGOP Hetzner — Point-in-Time Recovery (PITR) Backup System
# =============================================================================
# Server:  Hetzner AX162 — 37.27.169.232
# DB:      PostgreSQL 16, 145 GB
# Storage: 1.8 TB RAID1 NVMe, 1.5 TB free
#
# What this does:
#   1. Creates backup directory structure
#   2. Enables WAL archiving (continuous transaction log shipping)
#   3. Installs daily base backup script (pg_basebackup at 2 AM)
#   4. Installs WAL cleanup script (keeps 7 days of WAL files)
#   5. Installs PITR restore script (the "reset button")
#   6. Sets up cron jobs
#   7. Creates backup tracking schema in PostgreSQL
#
# Space budget:
#   - Each base backup: ~145 GB compressed → ~40-50 GB with gzip
#   - Keep 7 daily backups: ~350 GB
#   - WAL files: ~5-20 GB/day depending on activity
#   - Total: ~500 GB max → well within 1.5 TB free
#
# REQUIRES: PostgreSQL restart to enable archive_mode
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/opt/pgbackup"
WAL_ARCHIVE="${BACKUP_ROOT}/wal_archive"
BASE_BACKUP_DIR="${BACKUP_ROOT}/base"
SCRIPTS_DIR="${BACKUP_ROOT}/scripts"
LOG_DIR="${BACKUP_ROOT}/logs"
PG_DATA="/var/lib/postgresql/16/main"
PG_CONF="/etc/postgresql/16/main/postgresql.conf"
PG_USER="postgres"
DB_NAME="postgres"
DB_PASS="Anamaria@2026@"
RETENTION_DAYS=7

echo "============================================="
echo "BroyhillGOP PITR Backup System Setup"
echo "============================================="

# -----------------------------------------------
# Step 1: Create directory structure
# -----------------------------------------------
echo "[1/7] Creating directory structure..."
mkdir -p "${WAL_ARCHIVE}"
mkdir -p "${BASE_BACKUP_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOG_DIR}"
chown -R postgres:postgres "${BACKUP_ROOT}"
chmod 700 "${WAL_ARCHIVE}" "${BASE_BACKUP_DIR}"

echo "  → ${BACKUP_ROOT}/ created"

# -----------------------------------------------
# Step 2: Enable WAL archiving in postgresql.conf
# -----------------------------------------------
echo "[2/7] Configuring WAL archiving..."

# Backup current config
cp "${PG_CONF}" "${PG_CONF}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if archive settings already exist
if grep -q "^archive_mode = on" "${PG_CONF}"; then
    echo "  → WAL archiving already enabled, skipping config changes"
else
    # Add PITR config block
    cat >> "${PG_CONF}" << 'PGCONF'

# =============================================================================
# PITR BACKUP CONFIGURATION — Added by setup_backup.sh
# =============================================================================
archive_mode = on
archive_command = 'test ! -f /opt/pgbackup/wal_archive/%f && cp %p /opt/pgbackup/wal_archive/%f'
archive_timeout = 300
# Archive WAL segment every 5 minutes even if not full (ensures max 5 min data loss)
# =============================================================================
PGCONF
    echo "  → Archive settings appended to postgresql.conf"
    echo "  ⚠  PostgreSQL restart required to activate archive_mode"
fi

# -----------------------------------------------
# Step 3: Create daily base backup script
# -----------------------------------------------
echo "[3/7] Installing daily base backup script..."

cat > "${SCRIPTS_DIR}/daily_base_backup.sh" << 'BACKUP_SCRIPT'
#!/bin/bash
# Daily base backup using pg_basebackup
# Runs as postgres user via cron at 2:00 AM

set -euo pipefail

BACKUP_ROOT="/opt/pgbackup"
BASE_DIR="${BACKUP_ROOT}/base"
LOG_DIR="${BACKUP_ROOT}/logs"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="base_${TIMESTAMP}"
BACKUP_PATH="${BASE_DIR}/${BACKUP_NAME}"
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"
DB_PASS="Anamaria@2026@"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=========================================="
echo "Base Backup Starting: $(date)"
echo "Target: ${BACKUP_PATH}"
echo "=========================================="

START_TIME=$(date +%s)

# Run pg_basebackup with gzip compression
PGPASSWORD="${DB_PASS}" pg_basebackup \
    -h 127.0.0.1 \
    -U postgres \
    -D "${BACKUP_PATH}" \
    -Ft \
    -z \
    -Xs \
    -P \
    --checkpoint=fast \
    --label="daily_${TIMESTAMP}"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)

echo "=========================================="
echo "Backup Complete: $(date)"
echo "Duration: ${ELAPSED} seconds"
echo "Size: ${BACKUP_SIZE}"
echo "=========================================="

# Record in database
PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -U postgres -d postgres -c "
INSERT INTO backup.backup_history 
    (backup_type, backup_path, backup_size_bytes, duration_seconds, status, details)
VALUES 
    ('base', '${BACKUP_PATH}', $(du -sb "${BACKUP_PATH}" | cut -f1), ${ELAPSED}, 'completed',
     jsonb_build_object('label', 'daily_${TIMESTAMP}', 'method', 'pg_basebackup', 'compression', 'gzip'));
" 2>/dev/null || echo "Warning: Could not record backup in tracking table"

# Cleanup old backups (keep last N days)
echo "Cleaning up backups older than ${RETENTION_DAYS} days..."
find "${BASE_DIR}" -maxdepth 1 -name "base_*" -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \; -print
echo "Cleanup complete."

# Cleanup old WAL files (keep WAL files newer than oldest base backup)
OLDEST_BASE=$(ls -1t "${BASE_DIR}" | tail -1)
if [ -n "${OLDEST_BASE}" ] && [ -d "${BASE_DIR}/${OLDEST_BASE}" ]; then
    OLDEST_BACKUP_TIME=$(stat -c %Y "${BASE_DIR}/${OLDEST_BASE}")
    echo "Cleaning WAL files older than oldest base backup (${OLDEST_BASE})..."
    find "${BACKUP_ROOT}/wal_archive" -name "0*" -type f ! -newer "${BASE_DIR}/${OLDEST_BASE}" -delete 2>/dev/null
    echo "WAL cleanup complete."
fi

echo "=========================================="
echo "All done: $(date)"
echo "=========================================="
BACKUP_SCRIPT

chmod +x "${SCRIPTS_DIR}/daily_base_backup.sh"
chown postgres:postgres "${SCRIPTS_DIR}/daily_base_backup.sh"
echo "  → daily_base_backup.sh installed"

# -----------------------------------------------
# Step 4: Create PITR restore script (THE RESET BUTTON)
# -----------------------------------------------
echo "[4/7] Installing PITR restore script..."

cat > "${SCRIPTS_DIR}/pitr_restore.sh" << 'RESTORE_SCRIPT'
#!/bin/bash
# =============================================================================
# PITR RESTORE — THE RESET BUTTON
# =============================================================================
# Usage:
#   ./pitr_restore.sh "2026-04-13 08:00:00"
#     → Restores database to the state it was in at 8:00 AM on April 13
#
#   ./pitr_restore.sh latest
#     → Restores from the most recent base backup (no time target)
#
#   ./pitr_restore.sh list
#     → Lists available base backups and the time range you can restore to
#
# THIS SCRIPT:
#   1. Stops PostgreSQL
#   2. Moves current data directory aside (safety net)
#   3. Restores the base backup taken before your target time
#   4. Configures recovery to replay WAL up to your target time
#   5. Starts PostgreSQL in recovery mode
#   6. Waits for recovery to complete
#   7. Resumes normal operations
#
# REQUIRES: root or sudo access
# WARNING: This replaces the current database. The old data is preserved
#          in /var/lib/postgresql/16/main.pre_restore_TIMESTAMP
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/opt/pgbackup"
BASE_DIR="${BACKUP_ROOT}/base"
WAL_DIR="${BACKUP_ROOT}/wal_archive"
PG_DATA="/var/lib/postgresql/16/main"
DB_PASS="Anamaria@2026@"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# -----------------------------------------------
# LIST MODE
# -----------------------------------------------
if [ "${1:-}" = "list" ]; then
    echo "=========================================="
    echo "Available Base Backups"
    echo "=========================================="
    
    if [ ! -d "${BASE_DIR}" ] || [ -z "$(ls -A ${BASE_DIR} 2>/dev/null)" ]; then
        echo -e "${RED}No base backups found.${NC}"
        echo "Run a base backup first: /opt/pgbackup/scripts/daily_base_backup.sh"
        exit 1
    fi
    
    for backup in $(ls -1t "${BASE_DIR}"); do
        BTIME=$(stat -c %Y "${BASE_DIR}/${backup}")
        BDATE=$(date -d "@${BTIME}" "+%Y-%m-%d %H:%M:%S")
        BSIZE=$(du -sh "${BASE_DIR}/${backup}" | cut -f1)
        echo "  ${backup}  |  ${BDATE}  |  ${BSIZE}"
    done
    
    echo ""
    echo "WAL Archive:"
    WAL_COUNT=$(find "${WAL_DIR}" -name "0*" -type f 2>/dev/null | wc -l)
    if [ "${WAL_COUNT}" -gt 0 ]; then
        OLDEST_WAL=$(ls -1t "${WAL_DIR}"/0* 2>/dev/null | tail -1)
        NEWEST_WAL=$(ls -1t "${WAL_DIR}"/0* 2>/dev/null | head -1)
        echo "  ${WAL_COUNT} WAL segments archived"
        echo "  Oldest: $(stat -c %Y "${OLDEST_WAL}" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S")"
        echo "  Newest: $(stat -c %Y "${NEWEST_WAL}" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S")"
    else
        echo "  No WAL segments archived yet"
    fi
    
    echo ""
    echo -e "${GREEN}You can restore to any point between the oldest backup and the newest WAL segment.${NC}"
    exit 0
fi

# -----------------------------------------------
# RESTORE MODE
# -----------------------------------------------
TARGET_TIME="${1:-}"

if [ -z "${TARGET_TIME}" ]; then
    echo "Usage:"
    echo "  $0 \"2026-04-13 08:00:00\"   Restore to specific time"
    echo "  $0 latest                    Restore from latest backup"
    echo "  $0 list                      List available backups"
    exit 1
fi

echo -e "${RED}=========================================="
echo "   DATABASE POINT-IN-TIME RESTORE"
echo "==========================================${NC}"
echo ""

if [ "${TARGET_TIME}" = "latest" ]; then
    echo "Mode: Restore from latest base backup (no time target)"
    LATEST_BACKUP=$(ls -1t "${BASE_DIR}" | head -1)
    if [ -z "${LATEST_BACKUP}" ]; then
        echo -e "${RED}No base backups found!${NC}"
        exit 1
    fi
    SELECTED_BACKUP="${LATEST_BACKUP}"
    echo "Selected backup: ${SELECTED_BACKUP}"
else
    echo "Target time: ${TARGET_TIME}"
    
    # Find the most recent backup BEFORE the target time
    TARGET_EPOCH=$(date -d "${TARGET_TIME}" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Invalid date format. Use: YYYY-MM-DD HH:MM:SS${NC}"
        exit 1
    fi
    
    SELECTED_BACKUP=""
    for backup in $(ls -1t "${BASE_DIR}"); do
        BTIME=$(stat -c %Y "${BASE_DIR}/${backup}")
        if [ "${BTIME}" -le "${TARGET_EPOCH}" ]; then
            SELECTED_BACKUP="${backup}"
            break
        fi
    done
    
    if [ -z "${SELECTED_BACKUP}" ]; then
        echo -e "${RED}No base backup found before ${TARGET_TIME}${NC}"
        echo "Available backups:"
        ls -1t "${BASE_DIR}"
        exit 1
    fi
    
    BACKUP_DATE=$(stat -c %Y "${BASE_DIR}/${SELECTED_BACKUP}" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S")
    echo "Selected backup: ${SELECTED_BACKUP} (taken at ${BACKUP_DATE})"
fi

echo ""
echo -e "${YELLOW}WARNING: This will replace the current database!${NC}"
echo "The current data will be preserved at:"
echo "  ${PG_DATA}.pre_restore_$(date +%Y%m%d_%H%M%S)"
echo ""
read -p "Type YES to proceed: " CONFIRM
if [ "${CONFIRM}" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

RESTORE_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SAFETY_DIR="${PG_DATA}.pre_restore_${RESTORE_TIMESTAMP}"

echo ""
echo "[1/6] Stopping PostgreSQL..."
systemctl stop postgresql
sleep 3

# Verify it stopped
if pg_isready -h 127.0.0.1 2>/dev/null; then
    echo -e "${RED}PostgreSQL did not stop cleanly!${NC}"
    exit 1
fi
echo "  → PostgreSQL stopped"

echo "[2/6] Preserving current data directory..."
mv "${PG_DATA}" "${SAFETY_DIR}"
echo "  → Moved to ${SAFETY_DIR}"

echo "[3/6] Restoring base backup..."
mkdir -p "${PG_DATA}"
cd "${PG_DATA}"

# Extract the tar backup
tar xzf "${BASE_DIR}/${SELECTED_BACKUP}/base.tar.gz" -C "${PG_DATA}/"

# Extract WAL if present
if [ -f "${BASE_DIR}/${SELECTED_BACKUP}/pg_wal.tar.gz" ]; then
    mkdir -p "${PG_DATA}/pg_wal"
    tar xzf "${BASE_DIR}/${SELECTED_BACKUP}/pg_wal.tar.gz" -C "${PG_DATA}/pg_wal/"
fi

chown -R postgres:postgres "${PG_DATA}"
chmod 700 "${PG_DATA}"
echo "  → Base backup restored"

echo "[4/6] Configuring recovery..."

# Create recovery signal file
touch "${PG_DATA}/recovery.signal"
chown postgres:postgres "${PG_DATA}/recovery.signal"

# Create recovery configuration
cat > "${PG_DATA}/postgresql.auto.conf.restore" << RECOVERY_CONF
# PITR Recovery Configuration — ${RESTORE_TIMESTAMP}
restore_command = 'cp ${WAL_DIR}/%f %p'
RECOVERY_CONF

if [ "${TARGET_TIME}" != "latest" ]; then
    echo "recovery_target_time = '${TARGET_TIME}'" >> "${PG_DATA}/postgresql.auto.conf.restore"
    echo "recovery_target_action = 'promote'" >> "${PG_DATA}/postgresql.auto.conf.restore"
fi

# Merge with existing auto.conf
if [ -f "${PG_DATA}/postgresql.auto.conf" ]; then
    cat "${PG_DATA}/postgresql.auto.conf.restore" >> "${PG_DATA}/postgresql.auto.conf"
else
    mv "${PG_DATA}/postgresql.auto.conf.restore" "${PG_DATA}/postgresql.auto.conf"
fi
chown postgres:postgres "${PG_DATA}/postgresql.auto.conf"

echo "  → Recovery configured"
if [ "${TARGET_TIME}" != "latest" ]; then
    echo "  → Target time: ${TARGET_TIME}"
fi

echo "[5/6] Starting PostgreSQL in recovery mode..."
systemctl start postgresql

echo "  → Waiting for recovery to complete..."
WAIT_COUNT=0
MAX_WAIT=300  # 5 minutes max
while [ ${WAIT_COUNT} -lt ${MAX_WAIT} ]; do
    # Check if recovery is complete (recovery.signal will be removed)
    if ! [ -f "${PG_DATA}/recovery.signal" ]; then
        break
    fi
    
    # Also check if PG is accepting connections
    if PGPASSWORD="${DB_PASS}" pg_isready -h 127.0.0.1 -U postgres 2>/dev/null; then
        # Check if still in recovery
        IN_RECOVERY=$(PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -U postgres -d postgres -t -A -c "SELECT pg_is_in_recovery();" 2>/dev/null || echo "true")
        if [ "${IN_RECOVERY}" = "f" ]; then
            break
        fi
    fi
    
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
        echo "  → Still recovering... (${WAIT_COUNT}s)"
    fi
done

echo "[6/6] Verifying restore..."
sleep 3

if PGPASSWORD="${DB_PASS}" pg_isready -h 127.0.0.1 -U postgres 2>/dev/null; then
    echo -e "${GREEN}=========================================="
    echo "   RESTORE COMPLETE"
    echo "==========================================${NC}"
    
    # Show DB stats
    PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -U postgres -d postgres -c "
    SELECT schemaname || '.' || relname AS table_name, n_live_tup AS rows
    FROM pg_stat_user_tables
    WHERE n_live_tup > 0
    ORDER BY n_live_tup DESC
    LIMIT 15;"
    
    echo ""
    echo "Database size: $(PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -U postgres -d postgres -t -A -c "SELECT pg_size_pretty(pg_database_size('postgres'));")"
    echo ""
    echo "Previous data preserved at: ${SAFETY_DIR}"
    echo "  To remove: rm -rf ${SAFETY_DIR}"
    echo ""
    
    # Record restore in tracking table
    PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -U postgres -d postgres -c "
    INSERT INTO backup.restore_log 
        (restore_type, source_backup, target_time, status, details)
    VALUES 
        ('pitr', '${SELECTED_BACKUP}', 
         $([ "${TARGET_TIME}" = "latest" ] && echo "NULL" || echo "'${TARGET_TIME}'"),
         'completed',
         jsonb_build_object('safety_backup', '${SAFETY_DIR}', 'restore_timestamp', '${RESTORE_TIMESTAMP}'));
    " 2>/dev/null || echo "Note: Could not record restore in tracking table"
    
    # Clean up recovery settings from auto.conf
    sed -i '/restore_command/d' "${PG_DATA}/postgresql.auto.conf" 2>/dev/null || true
    sed -i '/recovery_target/d' "${PG_DATA}/postgresql.auto.conf" 2>/dev/null || true
    
else
    echo -e "${RED}=========================================="
    echo "   RESTORE FAILED — PostgreSQL not responding"
    echo "==========================================${NC}"
    echo ""
    echo "Check logs: journalctl -u postgresql -n 50"
    echo "To rollback: systemctl stop postgresql && rm -rf ${PG_DATA} && mv ${SAFETY_DIR} ${PG_DATA} && systemctl start postgresql"
    exit 1
fi
RESTORE_SCRIPT

chmod +x "${SCRIPTS_DIR}/pitr_restore.sh"
chown postgres:postgres "${SCRIPTS_DIR}/pitr_restore.sh"
echo "  → pitr_restore.sh installed"

# -----------------------------------------------
# Step 5: Create manual backup script (on-demand)
# -----------------------------------------------
echo "[5/7] Installing on-demand backup script..."

cat > "${SCRIPTS_DIR}/backup_now.sh" << 'NOW_SCRIPT'
#!/bin/bash
# Quick on-demand backup — run before making risky changes
# Usage: ./backup_now.sh "before schema migration 103"

set -euo pipefail

LABEL="${1:-manual_$(date +%Y%m%d_%H%M%S)}"
BACKUP_ROOT="/opt/pgbackup"
BASE_DIR="${BACKUP_ROOT}/base"
LOG_DIR="${BACKUP_ROOT}/logs"
DB_PASS="Anamaria@2026@"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="manual_${TIMESTAMP}"
BACKUP_PATH="${BASE_DIR}/${BACKUP_NAME}"

echo "Starting on-demand backup: ${LABEL}"
echo "Target: ${BACKUP_PATH}"

PGPASSWORD="${DB_PASS}" pg_basebackup \
    -h 127.0.0.1 \
    -U postgres \
    -D "${BACKUP_PATH}" \
    -Ft \
    -z \
    -Xs \
    -P \
    --checkpoint=fast \
    --label="${LABEL}"

BSIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
echo "Backup complete: ${BSIZE}"

PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -U postgres -d postgres -c "
INSERT INTO backup.backup_history 
    (backup_type, backup_path, backup_size_bytes, status, details)
VALUES 
    ('manual', '${BACKUP_PATH}', $(du -sb "${BACKUP_PATH}" | cut -f1), 'completed',
     jsonb_build_object('label', '${LABEL}'));
" 2>/dev/null || echo "Note: Could not record in tracking table"

echo "Done. To restore: /opt/pgbackup/scripts/pitr_restore.sh latest"
NOW_SCRIPT

chmod +x "${SCRIPTS_DIR}/backup_now.sh"
chown postgres:postgres "${SCRIPTS_DIR}/backup_now.sh"
echo "  → backup_now.sh installed"

# -----------------------------------------------
# Step 6: Create backup tracking schema
# -----------------------------------------------
echo "[6/7] Creating backup tracking schema..."

PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -U postgres -d postgres << 'SQLBLOCK'

CREATE SCHEMA IF NOT EXISTS backup;

-- Backup history
CREATE TABLE IF NOT EXISTS backup.backup_history (
    backup_id           UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    backup_type         TEXT            NOT NULL CHECK (backup_type IN ('base','manual','wal')),
    backup_path         TEXT,
    backup_size_bytes   BIGINT,
    duration_seconds    INTEGER,
    status              TEXT            NOT NULL DEFAULT 'completed'
                            CHECK (status IN ('started','completed','failed','expired')),
    details             JSONB           NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bh_type ON backup.backup_history (backup_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bh_status ON backup.backup_history (status);

COMMENT ON TABLE backup.backup_history IS
  'Tracks all base backups (daily and manual). Used to find the right backup for PITR restore. '
  'Rows are inserted by daily_base_backup.sh and backup_now.sh.';

-- Restore log
CREATE TABLE IF NOT EXISTS backup.restore_log (
    restore_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    restore_type        TEXT            NOT NULL CHECK (restore_type IN ('pitr','full','manual')),
    source_backup       TEXT,
    target_time         TIMESTAMPTZ,
    status              TEXT            NOT NULL DEFAULT 'completed'
                            CHECK (status IN ('started','completed','failed','rolled_back')),
    details             JSONB           NOT NULL DEFAULT '{}',
    restored_by         TEXT            NOT NULL DEFAULT current_user,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rl_type ON backup.restore_log (restore_type, created_at DESC);

COMMENT ON TABLE backup.restore_log IS
  'Immutable log of every database restore operation. Audit trail for who restored what and when.';

-- Convenience view: current backup status
CREATE OR REPLACE VIEW backup.v_backup_status AS
SELECT 
    'Last base backup' AS metric,
    TO_CHAR(MAX(created_at), 'YYYY-MM-DD HH24:MI:SS') AS value
FROM backup.backup_history 
WHERE backup_type = 'base' AND status = 'completed'
UNION ALL
SELECT 
    'Total backups',
    COUNT(*)::TEXT
FROM backup.backup_history 
WHERE status = 'completed'
UNION ALL
SELECT 
    'Total restores',
    COUNT(*)::TEXT
FROM backup.restore_log
UNION ALL
SELECT
    'DB size',
    pg_size_pretty(pg_database_size('postgres'));

COMMENT ON VIEW backup.v_backup_status IS
  'Quick overview of backup system status. Run: SELECT * FROM backup.v_backup_status;';

SQLBLOCK

echo "  → backup schema created (backup_history, restore_log, v_backup_status)"

# -----------------------------------------------
# Step 7: Install cron jobs
# -----------------------------------------------
echo "[7/7] Installing cron jobs..."

# Write crontab for postgres user
CRON_TEMP=$(mktemp)
crontab -u postgres -l 2>/dev/null > "${CRON_TEMP}" || true

# Check if daily backup cron already exists
if ! grep -q "daily_base_backup" "${CRON_TEMP}"; then
    echo "# BroyhillGOP daily base backup at 2:00 AM" >> "${CRON_TEMP}"
    echo "0 2 * * * ${SCRIPTS_DIR}/daily_base_backup.sh >> ${LOG_DIR}/cron_backup.log 2>&1" >> "${CRON_TEMP}"
    crontab -u postgres "${CRON_TEMP}"
    echo "  → Daily backup cron installed (2:00 AM)"
else
    echo "  → Daily backup cron already exists"
fi
rm -f "${CRON_TEMP}"

echo ""
echo "============================================="
echo "Setup Complete!"
echo "============================================="
echo ""
echo "Directory structure:"
echo "  ${BACKUP_ROOT}/"
echo "  ├── wal_archive/     WAL segments (continuous)"
echo "  ├── base/            Base backups (daily at 2 AM)"
echo "  ├── scripts/"
echo "  │   ├── daily_base_backup.sh"
echo "  │   ├── backup_now.sh        ← Run before risky changes"
echo "  │   └── pitr_restore.sh      ← THE RESET BUTTON"
echo "  └── logs/"
echo ""
echo "⚠  IMPORTANT: PostgreSQL restart required to enable WAL archiving."
echo "   Wait for IBE load to finish, then run:"
echo "     systemctl restart postgresql"
echo ""
echo "After restart, take the first base backup:"
echo "  sudo -u postgres ${SCRIPTS_DIR}/daily_base_backup.sh"
echo ""
echo "THE RESET BUTTON — Usage:"
echo "  ${SCRIPTS_DIR}/pitr_restore.sh list"
echo "  ${SCRIPTS_DIR}/pitr_restore.sh \"2026-04-14 08:00:00\""
echo "  ${SCRIPTS_DIR}/pitr_restore.sh latest"
echo ""
echo "On-demand backup before risky changes:"
echo "  sudo -u postgres ${SCRIPTS_DIR}/backup_now.sh \"before migration 103\""
echo ""
