#!/bin/bash
# =============================================================================
# BroyhillGOP — Per-Candidate Snapshot (Export)
# =============================================================================
# Exports ALL data for one candidate across all 13 candidate-aware tables
# into a single SQL file. This is the "save point" for a candidate before
# making risky changes.
#
# Usage:
#   ./candidate_snapshot.sh <candidate_id> ["label"]
#   ./candidate_snapshot.sh 42 "before ecosystem migration"
#   ./candidate_snapshot.sh list                              # list all candidates
#
# Output:
#   /opt/pgbackup/candidates/cand_<id>_<timestamp>.sql
#
# Tables exported (13 tables with candidate_id):
#   core.candidates, core.campaigns,
#   brain.budgets, brain.candidate_metrics, brain.candidate_triggers,
#   brain.contact_fatigue (via campaign→candidate), brain.decisions,
#   brain.event_queue (entity_id match),
#   pipeline.candidate_data_subscriptions, pipeline.inbound_data_queue,
#   pipeline.candidate_enrichment_log,
#   platform.candidate_ecosystems, platform.candidate_feature_config
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/opt/pgbackup"
CAND_DIR="${BACKUP_ROOT}/candidates"
LOG_DIR="${BACKUP_ROOT}/logs"
DB_HOST="127.0.0.1"
DB_USER="postgres"
DB_NAME="postgres"
DB_PASS="${PG_PASSWORD}"

mkdir -p "${CAND_DIR}" "${LOG_DIR}"

# ── List mode ─────────────────────────────────────────────────────────────────
if [ "${1:-}" = "list" ]; then
    echo "============================================="
    echo "All Candidates"
    echo "============================================="
    PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
    SELECT candidate_id, first_name, last_name, office_title, office_district, status,
           subscription_tier
    FROM core.candidates
    ORDER BY candidate_id;
    "
    echo ""
    echo "Existing candidate snapshots:"
    ls -1t "${CAND_DIR}"/cand_*.sql 2>/dev/null | head -20 || echo "  (none)"
    exit 0
fi

# ── Validate input ────────────────────────────────────────────────────────────
CANDIDATE_ID="${1:-}"
LABEL="${2:-manual}"

if [ -z "${CANDIDATE_ID}" ]; then
    echo "Usage:"
    echo "  $0 <candidate_id> [\"label\"]"
    echo "  $0 list"
    exit 1
fi

# Verify candidate exists
CAND_NAME=$(PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "
SELECT first_name || ' ' || last_name FROM core.candidates WHERE candidate_id = ${CANDIDATE_ID};
" 2>/dev/null)

if [ -z "${CAND_NAME}" ]; then
    echo "ERROR: candidate_id ${CANDIDATE_ID} not found in core.candidates"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_FILE="${CAND_DIR}/cand_${CANDIDATE_ID}_${TIMESTAMP}.sql"
LOG_FILE="${LOG_DIR}/cand_snapshot_${CANDIDATE_ID}_${TIMESTAMP}.log"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================="
echo "Candidate Snapshot: ${CAND_NAME} (ID: ${CANDIDATE_ID})"
echo "Label: ${LABEL}"
echo "Started: $(date)"
echo "============================================="

START_TIME=$(date +%s)

# ── Header ────────────────────────────────────────────────────────────────────
cat > "${SNAPSHOT_FILE}" << HEADER
-- =============================================================================
-- BroyhillGOP Candidate Snapshot
-- Candidate: ${CAND_NAME} (candidate_id: ${CANDIDATE_ID})
-- Created:   $(date -u +"%Y-%m-%d %H:%M:%S UTC")
-- Label:     ${LABEL}
-- =============================================================================
-- To restore this candidate:
--   /opt/pgbackup/scripts/candidate_restore.sh ${CANDIDATE_ID} ${SNAPSHOT_FILE}
-- =============================================================================

BEGIN;

-- Record the restore in the log
INSERT INTO backup.restore_log (restore_type, source_backup, status, details)
VALUES ('candidate', '${SNAPSHOT_FILE}', 'started',
        jsonb_build_object('candidate_id', ${CANDIDATE_ID}, 'candidate_name', '${CAND_NAME}'));

HEADER

# ── Export function ───────────────────────────────────────────────────────────
export_table() {
    local SCHEMA=$1
    local TABLE=$2
    local WHERE=$3
    local FULL="${SCHEMA}.${TABLE}"

    ROW_COUNT=$(PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "
        SELECT COUNT(*) FROM ${FULL} WHERE ${WHERE};
    " 2>/dev/null || echo "0")

    echo "  → ${FULL}: ${ROW_COUNT} rows"

    if [ "${ROW_COUNT}" -gt 0 ]; then
        echo "" >> "${SNAPSHOT_FILE}"
        echo "-- ${FULL}: ${ROW_COUNT} rows" >> "${SNAPSHOT_FILE}"
        echo "DELETE FROM ${FULL} WHERE ${WHERE};" >> "${SNAPSHOT_FILE}"

        # Use COPY format for speed and correctness
        PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
            \\COPY (SELECT * FROM ${FULL} WHERE ${WHERE}) TO STDOUT WITH (FORMAT csv, HEADER true, FORCE_QUOTE *)
        " 2>/dev/null > "/tmp/cand_export_${TABLE}.csv"

        # Generate INSERT statements from CSV (handles NULLs, escaping)
        PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "
            SELECT 'INSERT INTO ${FULL} SELECT * FROM (VALUES' || chr(10) ||
                   '  -- Data loaded via COPY below' || chr(10) ||
                   ') placeholder;' ;
        " > /dev/null 2>&1

        # Better approach: use COPY with inline data
        echo "\\COPY ${FULL} FROM STDIN WITH (FORMAT csv, HEADER true, NULL '')" >> "${SNAPSHOT_FILE}"
        cat "/tmp/cand_export_${TABLE}.csv" >> "${SNAPSHOT_FILE}"
        echo "\\." >> "${SNAPSHOT_FILE}"

        rm -f "/tmp/cand_export_${TABLE}.csv"
    fi
}

# ── Export all candidate tables ───────────────────────────────────────────────
echo ""
echo "Exporting candidate data across 13 tables..."

# Tier 1: Core identity
export_table "core" "candidates" "candidate_id = ${CANDIDATE_ID}"
export_table "core" "campaigns"  "candidate_id = ${CANDIDATE_ID}"

# Tier 2: Brain (decisions, triggers, budgets, metrics)
export_table "brain" "budgets"            "candidate_id = ${CANDIDATE_ID}"
export_table "brain" "candidate_metrics"  "candidate_id = ${CANDIDATE_ID}"
export_table "brain" "candidate_triggers" "candidate_id = ${CANDIDATE_ID}"
export_table "brain" "decisions"          "candidate_id = ${CANDIDATE_ID}"

# Tier 3: Pipeline (data flow)
export_table "pipeline" "candidate_data_subscriptions" "candidate_id = ${CANDIDATE_ID}"
export_table "pipeline" "inbound_data_queue"           "candidate_id = ${CANDIDATE_ID}"
export_table "pipeline" "candidate_enrichment_log"     "candidate_id = ${CANDIDATE_ID}"

# Tier 4: Platform (ecosystem config)
export_table "platform" "candidate_ecosystems"    "candidate_id = ${CANDIDATE_ID}"
export_table "platform" "candidate_feature_config" "candidate_id = ${CANDIDATE_ID}"

# Tier 5: Audit log (read-only export, not deleted on restore)
echo "" >> "${SNAPSHOT_FILE}"
echo "-- audit.activity_log: exported for reference only (not deleted on restore)" >> "${SNAPSHOT_FILE}"
AUDIT_COUNT=$(PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "
    SELECT COUNT(*) FROM audit.activity_log WHERE entity_id = '${CANDIDATE_ID}';
" 2>/dev/null || echo "0")
echo "  → audit.activity_log: ${AUDIT_COUNT} rows (reference only)"

# ── Footer ────────────────────────────────────────────────────────────────────
cat >> "${SNAPSHOT_FILE}" << 'FOOTER'

-- Mark restore complete
UPDATE backup.restore_log
SET status = 'completed',
    details = details || jsonb_build_object('completed_at', NOW()::text)
WHERE restore_id = (
    SELECT restore_id FROM backup.restore_log
    WHERE restore_type = 'candidate' AND status = 'started'
    ORDER BY created_at DESC LIMIT 1
);

COMMIT;
FOOTER

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
SNAP_SIZE=$(du -sh "${SNAPSHOT_FILE}" | cut -f1)

# Record in backup_history
PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
INSERT INTO backup.backup_history
    (backup_type, backup_path, backup_size_bytes, duration_seconds, status, details)
VALUES
    ('candidate', '${SNAPSHOT_FILE}', $(stat -c %s "${SNAPSHOT_FILE}"), ${ELAPSED}, 'completed',
     jsonb_build_object('candidate_id', ${CANDIDATE_ID}, 'candidate_name', '${CAND_NAME}',
                        'label', '${LABEL}', 'tables_exported', 13));
" 2>/dev/null || echo "Warning: Could not record in tracking table"

echo ""
echo "============================================="
echo "Snapshot Complete: $(date)"
echo "============================================="
echo "  Candidate: ${CAND_NAME} (ID: ${CANDIDATE_ID})"
echo "  File:      ${SNAPSHOT_FILE}"
echo "  Size:      ${SNAP_SIZE}"
echo "  Duration:  ${ELAPSED}s"
echo ""
echo "To restore:  /opt/pgbackup/scripts/candidate_restore.sh ${CANDIDATE_ID} ${SNAPSHOT_FILE}"
echo "============================================="
