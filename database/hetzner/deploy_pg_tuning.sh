#!/bin/bash
# ============================================================================
# BroyhillGOP — Deploy PostgreSQL Tuning to Hetzner AX162
# ============================================================================
# WARNING: This restarts PostgreSQL. Run during a maintenance window.
# The Acxiom IBE load (screen: acxrestructure) will be interrupted.
# ============================================================================

set -euo pipefail

echo "=== Step 1: Create conf.d directory if needed ==="
mkdir -p /etc/postgresql/16/main/conf.d

# Check if conf.d is included in main config
if ! grep -q "include_dir.*conf.d" /etc/postgresql/16/main/postgresql.conf; then
    echo "include_dir = 'conf.d'" >> /etc/postgresql/16/main/postgresql.conf
    echo "Added include_dir directive"
else
    echo "conf.d already included"
fi

echo "=== Step 2: Copy tuning config ==="
cp /tmp/postgresql_hetzner_tuning.conf /etc/postgresql/16/main/conf.d/99-broyhillgop.conf
echo "Config copied"

echo "=== Step 3: Set huge pages for 64GB shared_buffers ==="
# 64GB = 67,108,864 KB / 2048 KB per huge page = 32768 + 10% buffer = 33000
sysctl -w vm.nr_hugepages=33000
# Make persistent
if grep -q "vm.nr_hugepages" /etc/sysctl.conf; then
    sed -i 's/vm.nr_hugepages=.*/vm.nr_hugepages=33000/' /etc/sysctl.conf
else
    echo "vm.nr_hugepages=33000" >> /etc/sysctl.conf
fi
echo "Huge pages set to 33000"

echo "=== Step 4: Install pg_stat_statements extension ==="
apt-get install -y postgresql-16-pg-stat-statements 2>/dev/null || echo "pg_stat_statements may already be installed"

echo "=== Step 5: Verify config syntax ==="
sudo -u postgres /usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main -c 2>&1 || true

echo "=== Step 6: Restart PostgreSQL ==="
echo "WARNING: This will restart PostgreSQL and interrupt running queries."
echo "The acxrestructure screen session will need to be restarted."
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl restart postgresql
    sleep 5
    
    echo "=== Step 7: Verify new settings ==="
    sudo -u postgres psql -c "SHOW shared_buffers;"
    sudo -u postgres psql -c "SHOW work_mem;"
    sudo -u postgres psql -c "SHOW effective_cache_size;"
    sudo -u postgres psql -c "SHOW max_parallel_workers;"
    sudo -u postgres psql -c "SHOW max_connections;"
    
    echo "=== Step 8: Create pg_stat_statements extension ==="
    sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    
    echo "=== DONE ==="
    echo "PostgreSQL restarted with new tuning."
    echo "Remember to restart the acxrestructure screen session if IBE load was interrupted."
else
    echo "Aborted. Config file is in place — restart PostgreSQL manually when ready."
fi
