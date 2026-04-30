#!/usr/bin/env python3
"""Load non-public tables from Supabase to Hetzner via RPC functions."""

import json
import subprocess
import requests
import sys

SUPABASE_URL = "https://isbgjpnbocdkeslofota.supabase.co"
ANON_KEY = "${SUPABASE_ANON_KEY}"
HETZNER_HOST = "37.27.169.232"
HETZNER_PASS = "${PG_PASSWORD_RETIRED_20260417}"
PG_PASS = "${PG_PASSWORD}"

def ssh_cmd(cmd):
    full = f"sshpass -p '{HETZNER_PASS}' ssh -o StrictHostKeyChecking=no root@{HETZNER_HOST} \"{cmd}\""
    return subprocess.run(full, shell=True, capture_output=True, text=True, timeout=120)

def psql_file(filepath):
    cmd = f"PGPASSWORD='{PG_PASS}' psql -h localhost -U postgres -d postgres -f {filepath}"
    return ssh_cmd(cmd)

def escape_sql_value(val):
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "TRUE" if val else "FALSE"
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, dict) or isinstance(val, list):
        s = json.dumps(val).replace("'", "''")
        return f"'{s}'::jsonb"
    s = str(val).replace("'", "''")
    return f"'{s}'"

def fetch_rpc(func_name, limit=1000, offset=0):
    url = f"{SUPABASE_URL}/rest/v1/rpc/{func_name}"
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
        "Content-Type": "application/json"
    }
    resp = requests.post(url, headers=headers, json={"p_limit": limit, "p_offset": offset})
    if resp.status_code != 200:
        print(f"  ERROR: HTTP {resp.status_code} - {resp.text[:200]}")
        return []
    return resp.json()

def fetch_all_rpc(func_name, page_size=1000):
    all_rows = []
    offset = 0
    while True:
        rows = fetch_rpc(func_name, limit=page_size, offset=offset)
        if not rows:
            break
        all_rows.extend(rows)
        print(f"  Fetched {len(all_rows)} rows...")
        offset += page_size
        if len(rows) < page_size:
            break
    return all_rows

def generate_insert_sql(schema, table, rows, columns):
    if not rows:
        return ""
    col_list = ", ".join(f'"{c}"' for c in columns)
    statements = []
    batch_size = 100
    for i in range(0, len(rows), batch_size):
        batch = rows[i:i+batch_size]
        values = []
        for row in batch:
            vals = ", ".join(escape_sql_value(row.get(c)) for c in columns)
            values.append(f"({vals})")
        stmt = f'INSERT INTO {schema}."{table}" ({col_list}) VALUES\n' + ",\n".join(values) + ";"
        statements.append(stmt)
    return "\n\n".join(statements)

TABLES = [
    {
        "rpc_func": "export_ncboe_committee_registry",
        "target_schema": "core",
        "target_table": "ncboe_committee_registry",
        "expected_rows": 2032,
        "columns": ["committee_sboe_id", "committee_name", "committee_type",
                     "first_seen_year", "last_seen_year", "updated_at"],
    },
    {
        "rpc_func": "export_ncboe_committee_type_lookup",
        "target_schema": "core",
        "target_table": "ncboe_committee_type_lookup",
        "expected_rows": 2039,
        "columns": ["committee_sboe_id", "committee_type", "notes"],
    },
    {
        "rpc_func": "export_candidate_committee_map",
        "target_schema": "core",
        "target_table": "candidate_committee_map",
        "expected_rows": 5761,
        "columns": ["id", "committee_id", "committee_name", "committee_source",
                     "committee_type", "candidate_id", "candidate_name", "tenant_id",
                     "election_cycle", "office", "state", "district",
                     "match_confidence", "created_at", "fec_cand_id"],
    },
    {
        "rpc_func": "export_sboe_committee_master",
        "target_schema": "staging",
        "target_table": "sboe_committee_master",
        "expected_rows": 13237,
        "columns": ["sboe_id", "old_id", "committee_name", "candidate_name",
                     "status", "loaded_at"],
    },
    {
        "rpc_func": "export_committee_candidate_bridge",
        "target_schema": "staging",
        "target_table": "committee_candidate_bridge",
        "expected_rows": 864,
        "columns": ["committee_sboe_id", "committee_name", "registry_candidate_name",
                     "name_on_ballot", "contest_name", "county_name",
                     "party_candidate", "election_dt", "match_confidence", "match_method"],
    },
]

def main():
    for spec in TABLES:
        schema = spec["target_schema"]
        table = spec["target_table"]
        func = spec["rpc_func"]
        print(f"\n{'='*60}")
        print(f"{func} -> {schema}.{table}")
        print(f"{'='*60}")

        # Truncate
        ssh_cmd(f"PGPASSWORD='{PG_PASS}' psql -h localhost -U postgres -d postgres -c 'TRUNCATE {schema}.\"{table}\";'")

        # Fetch
        rows = fetch_all_rpc(func, page_size=1000)
        print(f"  Total fetched: {len(rows)} (expected: {spec['expected_rows']})")

        if not rows:
            print("  SKIPPED - no rows")
            continue

        # Generate SQL
        sql = generate_insert_sql(schema, table, rows, spec["columns"])
        local_path = f"/home/user/workspace/chunks/{table}_insert.sql"
        with open(local_path, "w") as f:
            f.write(sql)
        print(f"  Generated SQL: {len(sql):,} bytes")

        # SCP to Hetzner
        scp_cmd = f"sshpass -p '{HETZNER_PASS}' scp -o StrictHostKeyChecking=no {local_path} root@{HETZNER_HOST}:/tmp/{table}_insert.sql"
        subprocess.run(scp_cmd, shell=True, capture_output=True, timeout=60)

        # Execute
        result = psql_file(f"/tmp/{table}_insert.sql")
        # Count INSERT lines
        inserts = [l for l in result.stdout.split('\n') if l.startswith('INSERT')]
        print(f"  Load: {len(inserts)} INSERT statements executed")
        if result.stderr.strip():
            print(f"  Stderr: {result.stderr.strip()[:300]}")

        # Verify
        result = ssh_cmd(f"PGPASSWORD='{PG_PASS}' psql -h localhost -U postgres -d postgres -t -c 'SELECT COUNT(*) FROM {schema}.\"{table}\";'")
        count = result.stdout.strip()
        print(f"  Verify count: {count}")
        
        if str(spec['expected_rows']) in count:
            print(f"  MATCH")
        else:
            print(f"  *** MISMATCH *** expected {spec['expected_rows']}")

if __name__ == "__main__":
    main()
