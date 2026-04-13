#!/bin/bash
# =============================================================================
# BroyhillGOP — Snapshot System Setup
# =============================================================================
# Installs: rclone (for Dropbox), snapshot scripts, candidate scripts, cron
#
# Run once on the Hetzner server as root.
# After running, configure rclone for Dropbox:
#   rclone config  →  choose Dropbox  →  name it "dropbox"  →  authorize
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/opt/pgbackup"
SCRIPTS_DIR="${BACKUP_ROOT}/scripts"
CAND_DIR="${BACKUP_ROOT}/candidates"
SNAPSHOT_DIR="${BACKUP_ROOT}/snapshots"
LOG_DIR="${BACKUP_ROOT}/logs"

echo "============================================="
echo "BroyhillGOP Snapshot System Setup"
echo "============================================="

# ── Step 1: Directories ──────────────────────────────────────────────────────
echo "[1/5] Creating directories..."
mkdir -p "${SCRIPTS_DIR}" "${CAND_DIR}" "${SNAPSHOT_DIR}" "${LOG_DIR}"
chown -R postgres:postgres "${BACKUP_ROOT}"
chmod 700 "${CAND_DIR}" "${SNAPSHOT_DIR}"
echo "  → Directories ready"

# ── Step 2: Install rclone ────────────────────────────────────────────────────
echo "[2/5] Installing rclone for Dropbox uploads..."
if command -v rclone &>/dev/null; then
    RCLONE_VER=$(rclone version | head -1)
    echo "  → rclone already installed: ${RCLONE_VER}"
else
    curl -s https://rclone.org/install.sh | bash
    echo "  → rclone installed: $(rclone version | head -1)"
fi

# Check if Dropbox remote is configured
if rclone listremotes 2>/dev/null | grep -q "^dropbox:"; then
    echo "  → Dropbox remote already configured"
else
    echo ""
    echo "  ⚠  Dropbox remote not yet configured."
    echo "  Run this after setup completes:"
    echo "    rclone config"
    echo "    → New remote → Name: dropbox → Storage: dropbox → Follow auth prompts"
    echo ""
fi

# ── Step 3: Install scripts ──────────────────────────────────────────────────
echo "[3/5] Installing scripts..."

# Copy scripts from /tmp staging area to permanent location
for SCRIPT in daily_snapshot_dropbox.sh snapshot_restore.sh candidate_snapshot.sh candidate_restore.sh; do
    if [ -f "/tmp/bgop_scripts/${SCRIPT}" ]; then
        cp "/tmp/bgop_scripts/${SCRIPT}" "${SCRIPTS_DIR}/${SCRIPT}"
        chmod +x "${SCRIPTS_DIR}/${SCRIPT}"
        chown postgres:postgres "${SCRIPTS_DIR}/${SCRIPT}"
        echo "  → ${SCRIPT} installed"
    else
        echo "  ⚠  ${SCRIPT} not found in /tmp/bgop_scripts/"
    fi
done

echo ""
echo "  Scripts installed at ${SCRIPTS_DIR}/:"
echo "  ├── daily_snapshot_dropbox.sh   Daily pg_dump → local + Dropbox"
echo "  ├── snapshot_restore.sh         Full DB restore from snapshot"
echo "  ├── candidate_snapshot.sh       Per-candidate export"
echo "  └── candidate_restore.sh        Per-candidate surgical restore"

# ── Step 4: Create backup schema if not exists ────────────────────────────────
echo ""
echo "[4/5] Ensuring backup schema exists..."

PGPASSWORD='Anamaria@2026@' psql -h 127.0.0.1 -U postgres -d postgres << 'SQLBLOCK'
CREATE SCHEMA IF NOT EXISTS backup;

CREATE TABLE IF NOT EXISTS backup.backup_history (
    backup_id           UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    backup_type         TEXT            NOT NULL CHECK (backup_type IN ('base','manual','wal','snapshot','candidate')),
    backup_path         TEXT,
    backup_size_bytes   BIGINT,
    duration_seconds    INTEGER,
    status              TEXT            NOT NULL DEFAULT 'completed'
                            CHECK (status IN ('started','completed','failed','expired')),
    details             JSONB           NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Add 'snapshot' and 'candidate' to check constraint if table already exists
-- (safe: if constraint already allows these values, this is a no-op)
DO $$
BEGIN
    ALTER TABLE backup.backup_history DROP CONSTRAINT IF EXISTS backup_history_backup_type_check;
    ALTER TABLE backup.backup_history ADD CONSTRAINT backup_history_backup_type_check
        CHECK (backup_type IN ('base','manual','wal','snapshot','candidate'));
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_bh_type ON backup.backup_history (backup_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bh_status ON backup.backup_history (status);

CREATE TABLE IF NOT EXISTS backup.restore_log (
    restore_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    restore_type        TEXT            NOT NULL CHECK (restore_type IN ('pitr','full','manual','candidate')),
    source_backup       TEXT,
    target_time         TIMESTAMPTZ,
    status              TEXT            NOT NULL DEFAULT 'completed'
                            CHECK (status IN ('started','completed','failed','rolled_back')),
    details             JSONB           NOT NULL DEFAULT '{}',
    restored_by         TEXT            NOT NULL DEFAULT current_user,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Add 'candidate' to restore_log check constraint
DO $$
BEGIN
    ALTER TABLE backup.restore_log DROP CONSTRAINT IF EXISTS restore_log_restore_type_check;
    ALTER TABLE backup.restore_log ADD CONSTRAINT restore_log_restore_type_check
        CHECK (restore_type IN ('pitr','full','manual','candidate'));
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_rl_type ON backup.restore_log (restore_type, created_at DESC);

CREATE OR REPLACE VIEW backup.v_backup_status AS
SELECT
    'Last base backup' AS metric,
    TO_CHAR(MAX(created_at), 'YYYY-MM-DD HH24:MI:SS') AS value
FROM backup.backup_history
WHERE backup_type = 'base' AND status = 'completed'
UNION ALL
SELECT
    'Last snapshot',
    TO_CHAR(MAX(created_at), 'YYYY-MM-DD HH24:MI:SS')
FROM backup.backup_history
WHERE backup_type = 'snapshot' AND status = 'completed'
UNION ALL
SELECT
    'Last candidate snapshot',
    TO_CHAR(MAX(created_at), 'YYYY-MM-DD HH24:MI:SS')
FROM backup.backup_history
WHERE backup_type = 'candidate' AND status = 'completed'
UNION ALL
SELECT
    'Total snapshots',
    COUNT(*)::TEXT
FROM backup.backup_history
WHERE backup_type IN ('snapshot','candidate') AND status = 'completed'
UNION ALL
SELECT
    'Total restores',
    COUNT(*)::TEXT
FROM backup.restore_log
UNION ALL
SELECT
    'Candidate restores',
    COUNT(*)::TEXT
FROM backup.restore_log
WHERE restore_type = 'candidate'
UNION ALL
SELECT
    'DB size',
    pg_size_pretty(pg_database_size('postgres'));

COMMENT ON VIEW backup.v_backup_status IS
  'Quick overview: SELECT * FROM backup.v_backup_status;';

SQLBLOCK

echo "  → backup schema ready (backup_history, restore_log, v_backup_status)"

# ── Step 5: Install cron ─────────────────────────────────────────────────────
echo "[5/5] Installing cron jobs..."

CRON_TEMP=$(mktemp)
crontab -u postgres -l 2>/dev/null > "${CRON_TEMP}" || true

# Daily snapshot at 3:00 AM (after PITR base backup at 2:00 AM)
if ! grep -q "daily_snapshot_dropbox" "${CRON_TEMP}"; then
    echo "# BroyhillGOP daily pg_dump snapshot at 3:00 AM → Dropbox" >> "${CRON_TEMP}"
    echo "0 3 * * * ${SCRIPTS_DIR}/daily_snapshot_dropbox.sh >> ${LOG_DIR}/cron_snapshot.log 2>&1" >> "${CRON_TEMP}"
    crontab -u postgres "${CRON_TEMP}"
    echo "  → Daily snapshot cron installed (3:00 AM)"
else
    echo "  → Daily snapshot cron already exists"
fi

rm -f "${CRON_TEMP}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================="
echo "Setup Complete!"
echo "============================================="
echo ""
echo "BACKUP SCHEDULE (cron, postgres user):"
echo "  2:00 AM — PITR base backup (pg_basebackup, binary)"
echo "  3:00 AM — pg_dump snapshot → Dropbox (logical, per-table)"
echo ""
echo "COMMANDS:"
echo ""
echo "  Full DB snapshot (on-demand):"
echo "    sudo -u postgres ${SCRIPTS_DIR}/daily_snapshot_dropbox.sh"
echo ""
echo "  Full DB restore:"
echo "    ${SCRIPTS_DIR}/snapshot_restore.sh latest"
echo "    ${SCRIPTS_DIR}/snapshot_restore.sh list"
echo "    ${SCRIPTS_DIR}/snapshot_restore.sh dropbox"
echo ""
echo "  Per-candidate snapshot (BEFORE risky changes):"
echo "    sudo -u postgres ${SCRIPTS_DIR}/candidate_snapshot.sh <candidate_id>"
echo "    sudo -u postgres ${SCRIPTS_DIR}/candidate_snapshot.sh list"
echo ""
echo "  Per-candidate restore (surgical rollback):"
echo "    ${SCRIPTS_DIR}/candidate_restore.sh <candidate_id> latest"
echo "    ${SCRIPTS_DIR}/candidate_restore.sh <candidate_id> list"
echo ""
echo "  Check backup status:"
echo "    PGPASSWORD='Anamaria@2026@' psql -h 127.0.0.1 -U postgres -d postgres \\"
echo "      -c \"SELECT * FROM backup.v_backup_status;\""
echo ""
if ! rclone listremotes 2>/dev/null | grep -q "^dropbox:"; then
    echo "⚠  NEXT STEP: Configure Dropbox for rclone:"
    echo "    rclone config → New remote → dropbox → Follow auth"
    echo ""
fi
echo "============================================="
