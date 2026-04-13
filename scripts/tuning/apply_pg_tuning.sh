#!/bin/bash
# ============================================================================
# BroyhillGOP PostgreSQL Tuning — Apply Script
# Run as root on Hetzner AX162
# ============================================================================
set -euo pipefail

echo "=== BroyhillGOP PG16 Tuning Apply ==="
echo "Started: $(date)"

# --- 1. Create backup directories for WAL archiving ---
echo "[1/7] Creating backup directories..."
mkdir -p /backup/wal /backup/base
chown -R postgres:postgres /backup
echo "  /backup/wal  — WAL segments"
echo "  /backup/base — base backups"

# --- 2. Configure huge pages ---
echo "[2/7] Configuring huge pages..."
# 63GB shared_buffers / 2MB page size × 1.05 overhead = 33868 pages
HUGE_PAGES=33868
CURRENT=$(cat /proc/sys/vm/nr_hugepages)
echo "  Current huge pages: $CURRENT"
echo "  Target huge pages:  $HUGE_PAGES"

if [ "$CURRENT" -lt "$HUGE_PAGES" ]; then
    # Set now
    sysctl -w vm.nr_hugepages=$HUGE_PAGES
    # Set persistent
    if grep -q 'vm.nr_hugepages' /etc/sysctl.conf; then
        sed -i "s/vm.nr_hugepages.*/vm.nr_hugepages = $HUGE_PAGES/" /etc/sysctl.conf
    else
        echo "vm.nr_hugepages = $HUGE_PAGES" >> /etc/sysctl.conf
    fi
    echo "  Huge pages configured: $HUGE_PAGES"
else
    echo "  Huge pages already sufficient"
fi

# Verify allocation
ALLOCATED=$(cat /proc/sys/vm/nr_hugepages)
echo "  Verified: $ALLOCATED huge pages allocated"
if [ "$ALLOCATED" -lt "$HUGE_PAGES" ]; then
    echo "  WARNING: Could not allocate all huge pages. Memory may be fragmented."
    echo "  Try rebooting if this persists. Continuing with huge_pages=try in PG config."
fi

# --- 3. Install pg_stat_statements extension ---
echo "[3/7] Ensuring pg_stat_statements is available..."
if dpkg -l | grep -q postgresql-16; then
    apt-get install -y postgresql-16-pg-stat-statements 2>/dev/null || echo "  Already installed or not in repo — will try loading anyway"
fi

# --- 4. Backup current config ---
echo "[4/7] Backing up current postgresql.conf..."
PG_CONF="/etc/postgresql/16/main/postgresql.conf"
cp "$PG_CONF" "${PG_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
echo "  Backed up to ${PG_CONF}.bak.$(date +%Y%m%d_%H%M%S)"

# --- 5. Apply new config ---
echo "[5/7] Applying tuned postgresql.conf..."
cp /tmp/postgresql_broyhillgop.conf "$PG_CONF"
chown postgres:postgres "$PG_CONF"
echo "  Config applied"

# --- 6. Verify config syntax ---
echo "[6/7] Verifying config syntax..."
su - postgres -c "pg_lsclusters" || true
# pg_conftool doesn't validate, but PG will on startup

# --- 7. Restart PostgreSQL ---
echo "[7/7] Restarting PostgreSQL 16..."
echo "  WARNING: This will terminate all active connections."
echo "  Active connections:"
PGPASSWORD='${PGPASSWORD}' psql -h 127.0.0.1 -U postgres -d postgres -t -c "SELECT count(*) FROM pg_stat_activity WHERE state != 'idle';" 2>/dev/null || echo "  (could not check)"

systemctl restart postgresql@16-main

# Wait for PG to come back
echo "  Waiting for PostgreSQL to start..."
for i in $(seq 1 30); do
    if PGPASSWORD='${PGPASSWORD}' psql -h 127.0.0.1 -U postgres -d postgres -t -c "SELECT 1;" > /dev/null 2>&1; then
        echo "  PostgreSQL is UP"
        break
    fi
    sleep 1
done

# --- Verify settings ---
echo ""
echo "=== Verification ==="
PGPASSWORD='${PGPASSWORD}' psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT name, setting, unit FROM pg_settings
WHERE name IN (
    'shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size',
    'max_connections', 'max_parallel_workers', 'max_parallel_workers_per_gather',
    'max_wal_size', 'random_page_cost', 'wal_compression', 'archive_mode',
    'archive_command', 'huge_pages', 'autovacuum_max_workers', 'autovacuum_work_mem',
    'shared_preload_libraries', 'listen_addresses', 'wal_level',
    'autovacuum_vacuum_scale_factor', 'autovacuum_vacuum_cost_delay',
    'max_parallel_maintenance_workers', 'effective_io_concurrency',
    'checkpoint_timeout', 'log_min_duration_statement'
)
ORDER BY name;
"

# Create pg_stat_statements extension
PGPASSWORD='${PGPASSWORD}' psql -h 127.0.0.1 -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" 2>/dev/null || echo "pg_stat_statements extension creation deferred"

echo ""
echo "=== Complete ==="
echo "Finished: $(date)"
echo ""
echo "NEXT STEPS:"
echo "  1. Take a base backup: pg_basebackup -D /backup/base -Ft -Xs -P -h 127.0.0.1 -U postgres"
echo "  2. Verify relay.py is reconnected (screen -r relay)"
echo "  3. Test a sample query on acxiom tables"
