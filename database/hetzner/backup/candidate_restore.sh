#!/bin/bash
# =============================================================================
# BroyhillGOP — Per-Candidate Restore (Surgical Rollback)
# =============================================================================
# Restores ONE candidate's data from a snapshot without touching any other
# candidate's data. This is the scalpel vs the PITR sledgehammer.
#
# Usage:
#   ./candidate_restore.sh <candidate_id> <snapshot_file>
#   ./candidate_restore.sh <candidate_id> latest
#   ./candidate_restore.sh <candidate_id> list
#
# What happens:
#   1. Verifies the snapshot belongs to this candidate
#   2. Creates a safety export of current state BEFORE restoring
#   3. Deletes all current data for this candidate across 11 tables
#   4. Loads data from the snapshot file
#   5. Records the restore in backup.restore_log
#
# What it does NOT touch:
#   - Any other candidate's data
#   - Shared reference data (voters, donations, Acxiom)
#   - audit.activity_log (append-only, never deleted)
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/opt/pgbackup"
CAND_DIR="${BACKUP_ROOT}/candidates"
SCRIPTS_DIR="${BACKUP_ROOT}/scripts"
DB_HOST="127.0.0.1"
DB_USER="postgres"
DB_NAME="postgres"
DB_PASS="${PG_PASSWORD}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CANDIDATE_ID="${1:-}"
SOURCE="${2:-}"

# ── Validation ────────────────────────────────────────────────────────────────
if [ -z "${CANDIDATE_ID}" ] || [ -z "${SOURCE}" ]; then
    echo "Usage:"
    echo "  $0 <candidate_id> <snapshot_file>    Restore from specific snapshot"
    echo "  $0 <candidate_id> latest             Restore from most recent snapshot"
    echo "  $0 <candidate_id> list               List available snapshots"
    exit 1
fi

# Verify candidate exists
CAND_NAME=$(PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "
SELECT first_name || ' ' || last_name FROM core.candidates WHERE candidate_id = ${CANDIDATE_ID};
" 2>/dev/null)

if [ -z "${CAND_NAME}" ]; then
    echo -e "${RED}ERROR: candidate_id ${CANDIDATE_ID} not found${NC}"
    exit 1
fi

# ── List mode ─────────────────────────────────────────────────────────────────
if [ "${SOURCE}" = "list" ]; then
    echo "============================================="
    echo "Snapshots for ${CAND_NAME} (ID: ${CANDIDATE_ID})"
    echo "============================================="
    FOUND=0
    for f in $(ls -1t "${CAND_DIR}"/cand_${CANDIDATE_ID}_*.sql 2>/dev/null); do
        FDATE=$(stat -c %Y "${f}" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S")
        FSIZE=$(du -sh "${f}" | cut -f1)
        echo "  ${f}  |  ${FDATE}  |  ${FSIZE}"
        FOUND=$((FOUND + 1))
    done
    if [ ${FOUND} -eq 0 ]; then
        echo "  (no snapshots found)"
        echo ""
        echo "Create one: ${SCRIPTS_DIR}/candidate_snapshot.sh ${CANDIDATE_ID}"
    fi
    exit 0
fi

# ── Resolve snapshot file ─────────────────────────────────────────────────────
if [ "${SOURCE}" = "latest" ]; then
    SNAPSHOT_FILE=$(ls -1t "${CAND_DIR}"/cand_${CANDIDATE_ID}_*.sql 2>/dev/null | head -1)
    if [ -z "${SNAPSHOT_FILE}" ]; then
        echo -e "${RED}No snapshots found for candidate ${CANDIDATE_ID}${NC}"
        echo "Create one: ${SCRIPTS_DIR}/candidate_snapshot.sh ${CANDIDATE_ID}"
        exit 1
    fi
else
    SNAPSHOT_FILE="${SOURCE}"
fi

if [ ! -f "${SNAPSHOT_FILE}" ]; then
    echo -e "${RED}Snapshot file not found: ${SNAPSHOT_FILE}${NC}"
    exit 1
fi

# Verify snapshot belongs to this candidate
if ! head -5 "${SNAPSHOT_FILE}" | grep -q "candidate_id: ${CANDIDATE_ID}"; then
    echo -e "${RED}ERROR: Snapshot does not belong to candidate ${CANDIDATE_ID}${NC}"
    echo "Snapshot header:"
    head -10 "${SNAPSHOT_FILE}"
    exit 1
fi

SNAP_DATE=$(stat -c %Y "${SNAPSHOT_FILE}" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S")
SNAP_SIZE=$(du -sh "${SNAPSHOT_FILE}" | cut -f1)

# ── Confirmation ──────────────────────────────────────────────────────────────
echo -e "${RED}============================================="
echo "   CANDIDATE RESTORE"
echo "=============================================${NC}"
echo ""
echo "  Candidate:  ${CAND_NAME} (ID: ${CANDIDATE_ID})"
echo "  Snapshot:   $(basename ${SNAPSHOT_FILE})"
echo "  Taken:      ${SNAP_DATE}"
echo "  Size:       ${SNAP_SIZE}"
echo ""
echo -e "${YELLOW}This will DELETE all current data for candidate ${CANDIDATE_ID}"
echo -e "and replace it with the snapshot from ${SNAP_DATE}.${NC}"
echo ""
echo "Tables affected:"
echo "  core.candidates, core.campaigns"
echo "  brain.budgets, candidate_metrics, candidate_triggers, decisions"
echo "  pipeline.candidate_data_subscriptions, inbound_data_queue, candidate_enrichment_log"
echo "  platform.candidate_ecosystems, candidate_feature_config"
echo ""
echo -e "${GREEN}No other candidate's data will be touched.${NC}"
echo ""
read -p "Type YES to proceed: " CONFIRM
if [ "${CONFIRM}" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

RESTORE_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ── Step 1: Safety export of current state ────────────────────────────────────
echo ""
echo "[1/3] Creating safety snapshot of current state..."
SAFETY_FILE="${CAND_DIR}/cand_${CANDIDATE_ID}_prerestore_${RESTORE_TIMESTAMP}.sql"
"${SCRIPTS_DIR}/candidate_snapshot.sh" "${CANDIDATE_ID}" "pre-restore safety" 2>/dev/null
# Rename the snapshot to the safety filename
LATEST_SAFETY=$(ls -1t "${CAND_DIR}"/cand_${CANDIDATE_ID}_*.sql | head -1)
if [ "${LATEST_SAFETY}" != "${SNAPSHOT_FILE}" ]; then
    mv "${LATEST_SAFETY}" "${SAFETY_FILE}" 2>/dev/null || true
fi
echo "  → Safety export: ${SAFETY_FILE}"

# ── Step 2: Delete current candidate data ─────────────────────────────────────
echo "[2/3] Removing current candidate data..."

PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" << DELSQL
BEGIN;

-- Brain schema (FKs reference candidates/campaigns, delete children first)
DELETE FROM brain.decisions          WHERE candidate_id = ${CANDIDATE_ID};
DELETE FROM brain.candidate_triggers WHERE candidate_id = ${CANDIDATE_ID};
DELETE FROM brain.candidate_metrics  WHERE candidate_id = ${CANDIDATE_ID};
DELETE FROM brain.budgets            WHERE candidate_id = ${CANDIDATE_ID};

-- Pipeline schema
DELETE FROM pipeline.candidate_enrichment_log     WHERE candidate_id = ${CANDIDATE_ID};
DELETE FROM pipeline.inbound_data_queue           WHERE candidate_id = ${CANDIDATE_ID};
DELETE FROM pipeline.candidate_data_subscriptions WHERE candidate_id = ${CANDIDATE_ID};

-- Platform schema
DELETE FROM platform.candidate_feature_config WHERE candidate_id = ${CANDIDATE_ID};
DELETE FROM platform.candidate_ecosystems     WHERE candidate_id = ${CANDIDATE_ID};

-- Core (campaigns before candidates due to FK)
DELETE FROM core.campaigns  WHERE candidate_id = ${CANDIDATE_ID};
DELETE FROM core.candidates WHERE candidate_id = ${CANDIDATE_ID};

COMMIT;
DELSQL

echo "  → Current data deleted for candidate ${CANDIDATE_ID}"

# ── Step 3: Load snapshot ─────────────────────────────────────────────────────
echo "[3/3] Loading snapshot data..."

PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" \
    -f "${SNAPSHOT_FILE}" 2>&1 | tail -5

echo "  → Snapshot loaded"

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "Verifying restore..."
PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
SELECT 'core.candidates' AS table_name, COUNT(*) AS rows
FROM core.candidates WHERE candidate_id = ${CANDIDATE_ID}
UNION ALL
SELECT 'core.campaigns', COUNT(*) FROM core.campaigns WHERE candidate_id = ${CANDIDATE_ID}
UNION ALL
SELECT 'brain.budgets', COUNT(*) FROM brain.budgets WHERE candidate_id = ${CANDIDATE_ID}
UNION ALL
SELECT 'brain.decisions', COUNT(*) FROM brain.decisions WHERE candidate_id = ${CANDIDATE_ID}
UNION ALL
SELECT 'brain.candidate_triggers', COUNT(*) FROM brain.candidate_triggers WHERE candidate_id = ${CANDIDATE_ID}
UNION ALL
SELECT 'brain.candidate_metrics', COUNT(*) FROM brain.candidate_metrics WHERE candidate_id = ${CANDIDATE_ID}
UNION ALL
SELECT 'platform.candidate_ecosystems', COUNT(*) FROM platform.candidate_ecosystems WHERE candidate_id = ${CANDIDATE_ID}
UNION ALL
SELECT 'platform.candidate_feature_config', COUNT(*) FROM platform.candidate_feature_config WHERE candidate_id = ${CANDIDATE_ID}
ORDER BY 1;
"

# Record restore
PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
INSERT INTO backup.restore_log
    (restore_type, source_backup, status, details)
VALUES
    ('candidate', '${SNAPSHOT_FILE}', 'completed',
     jsonb_build_object(
         'candidate_id', ${CANDIDATE_ID},
         'candidate_name', '${CAND_NAME}',
         'safety_backup', '${SAFETY_FILE}',
         'snapshot_date', '${SNAP_DATE}',
         'restore_timestamp', '${RESTORE_TIMESTAMP}'
     ));
" 2>/dev/null || echo "Warning: Could not record restore"

echo ""
echo -e "${GREEN}============================================="
echo "   RESTORE COMPLETE"
echo "=============================================${NC}"
echo ""
echo "  Candidate: ${CAND_NAME} (ID: ${CANDIDATE_ID})"
echo "  Restored to: ${SNAP_DATE}"
echo "  Safety backup: ${SAFETY_FILE}"
echo ""
echo "  To undo this restore:"
echo "    ${SCRIPTS_DIR}/candidate_restore.sh ${CANDIDATE_ID} ${SAFETY_FILE}"
echo "============================================="
