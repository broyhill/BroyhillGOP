# URGENT CURSOR ORDERS — April 10, 2026 9:17 PM EDT
# DO THIS NOW. The new server has NO OS. It is in Hetzner Rescue mode.

## SERVER: 37.27.169.232 (AX162-R #2973063, Finland)
- Root password (rescue mode): ${PG_PASSWORD_RETIRED_20260417}
- This server is BLANK. No OS installed. Claude never did it.

## STEP 1 — SSH in and install Ubuntu 24.04
```bash
ssh root@37.27.169.232
# Password: ${PG_PASSWORD_RETIRED_20260417}
# You are now in Hetzner Rescue System

# Run the Hetzner installimage tool:
installimage
```
In the installimage menu:
- Select **Ubuntu 24.04**
- Use default partitioning (or set up LVM if you prefer)
- Hostname: broyhillgop-db
- Confirm and let it install
- When done: `reboot`

After reboot, SSH back in with the NEW root password that installimage sets.

## STEP 2 — Install PostgreSQL 16
```bash
apt update && apt upgrade -y
apt install -y postgresql-16 postgresql-client-16 postgresql-contrib
systemctl enable postgresql
systemctl start postgresql
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '${PG_PASSWORD}';"
```

## STEP 3 — Install Python and dependencies
```bash
apt install -y python3 python3-pip python3-venv git screen curl wget
pip3 install pyarrow pandas psycopg2-binary pymssql openpyxl
```

## STEP 4 — Create data directories
```bash
mkdir -p /data/acxiom /data/backups /data/fec /data/ncboe /data/datatrust /data/rnc
mkdir -p /opt/broyhillgop
```

## STEP 5 — Download Acxiom parquet file (EXPIRES APRIL 30)
```bash
cd /data/acxiom
wget -O acxiom_nc_full.parquet "https://dlsrncprod.blob.core.windows.net/sandbox/DPeletski/Acxiom_National_Full_NC/part-00000-e23f0758-5b5c-4e9d-9972-b2e1d6abfcb8-c000.snappy.parquet?sv=2023-11-03&spr=https&st=2026-04-09T11%3A48%3A23Z&se=2026-04-30T11%3A48%3A00Z&sr=b&sp=r&sig=4lclFiseWjG6gmYlvxnD35CjI6udlWlhFY1er5iA4Ck%3D"
ls -lh acxiom_nc_full.parquet
python3 -c "import pyarrow.parquet as pq; f=pq.read_metadata('acxiom_nc_full.parquet'); print(f'Rows: {f.num_rows}, Cols: {f.num_columns}')"
```

## STEP 6 — Create PostgreSQL schemas
```bash
sudo -u postgres psql -c "
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS norm;
CREATE SCHEMA IF NOT EXISTS archive;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS volunteer;
CREATE SCHEMA IF NOT EXISTS donor_intelligence;
CREATE SCHEMA IF NOT EXISTS raw;
"
```

## STEP 7 — Clone the BroyhillGOP repo
```bash
cd /opt/broyhillgop
git clone https://github.com/broyhill/BroyhillGOP.git .
```

## STEP 8 — Configure PostgreSQL for remote access
Edit /etc/postgresql/16/main/postgresql.conf:
- Set: listen_addresses = '*'

Edit /etc/postgresql/16/main/pg_hba.conf:
- Add: host all all 0.0.0.0/0 md5

```bash
systemctl restart postgresql
```

## STEP 9 — Set up firewall
```bash
apt install -y ufw
ufw allow ssh
ufw allow 5432/tcp  # PostgreSQL
ufw allow 8080/tcp  # Future relay
ufw enable
```

## STEP 10 — Report back
After all steps complete, report:
- OS version (cat /etc/os-release)
- PostgreSQL version (psql --version)
- Python version (python3 --version)
- Disk space (df -h /)
- RAM (free -h)
- Acxiom file size and row/column count
- Confirm all schemas created

## GUARDRAILS
- This is infrastructure setup ONLY
- Do NOT load any data into PostgreSQL tables yet
- Do NOT create any tables — only schemas
- Do NOT touch Supabase (it is being restored right now)
- Read sessions/MASTER_RESET_AND_BUILD_PLAN.md after cloning the repo
