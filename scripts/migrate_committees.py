#!/usr/bin/env python3
"""
Migrate committee tables from Supabase to Hetzner PostgreSQL.
Uses REST API for public tables, generates SQL INSERTs for all.
"""

import json
import csv
import io
import subprocess
import requests
import sys
import time

# Supabase config
SUPABASE_URL = "https://isbgjpnbocdkeslofota.supabase.co"
ANON_KEY = "${SUPABASE_ANON_KEY}"

# Hetzner config
HETZNER_HOST = "37.27.169.232"
HETZNER_PASS = "${PG_PASSWORD_RETIRED_20260417}"
PG_PASS = "${PG_PASSWORD}"
PG_CONNSTR = "postgresql://postgres:${PG_PASSWORD_URLENCODED}@localhost:5432/postgres"

def ssh_cmd(cmd):
    """Execute command on Hetzner via SSH."""
    full = f"sshpass -p '{HETZNER_PASS}' ssh -o StrictHostKeyChecking=no root@{HETZNER_HOST} \"{cmd}\""
    result = subprocess.run(full, shell=True, capture_output=True, text=True, timeout=120)
    return result

def psql_cmd(sql):
    """Execute SQL on Hetzner PostgreSQL via SSH."""
    # Escape single quotes in SQL for shell
    escaped = sql.replace("'", "'\\''")
    cmd = f"PGPASSWORD='{PG_PASS}' psql -h localhost -U postgres -d postgres -c '{escaped}'"
    return ssh_cmd(cmd)

def psql_file(filepath):
    """Execute SQL file on Hetzner PostgreSQL via SSH."""
    cmd = f"PGPASSWORD='{PG_PASS}' psql -h localhost -U postgres -d postgres -f {filepath}"
    return ssh_cmd(cmd)

def fetch_rest_api_table(table_name, order_col="id"):
    """Fetch all rows from a public table via Supabase REST API."""
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
        "Prefer": "count=exact"
    }
    
    all_rows = []
    offset = 0
    page_size = 1000
    total = None
    
    while True:
        url = f"{SUPABASE_URL}/rest/v1/{table_name}?select=*&limit={page_size}&offset={offset}&order={order_col}"
        resp = requests.get(url, headers=headers)
        
        if resp.status_code not in (200, 206):
            print(f"  ERROR: HTTP {resp.status_code} - {resp.text[:200]}")
            break
            
        rows = resp.json()
        if not rows:
            break
            
        all_rows.extend(rows)
        
        # Get total from content-range header
        cr = resp.headers.get("content-range", "")
        if "/" in cr:
            total = int(cr.split("/")[1])
        
        offset += page_size
        print(f"  Fetched {len(all_rows)}/{total or '?'} rows...")
        
        if total and len(all_rows) >= total:
            break
    
    return all_rows

def escape_sql_value(val):
    """Escape a value for SQL INSERT."""
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

def generate_insert_sql(schema, table, rows, columns=None):
    """Generate INSERT SQL statements in batches."""
    if not rows:
        return ""
    
    if columns is None:
        columns = list(rows[0].keys())
    
    col_list = ", ".join(f'"{c}"' for c in columns)
    statements = []
    
    # Batch inserts (100 rows per INSERT for efficiency)
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

def generate_create_table_sql(schema, table, columns_spec):
    """Generate CREATE TABLE IF NOT EXISTS."""
    cols = []
    for col_name, col_type in columns_spec:
        pg_type = col_type
        # Map common types
        type_map = {
            "integer": "INTEGER",
            "bigint": "BIGINT",
            "text": "TEXT",
            "boolean": "BOOLEAN",
            "numeric": "NUMERIC",
            "double precision": "DOUBLE PRECISION",
            "date": "DATE",
            "timestamp with time zone": "TIMESTAMPTZ",
            "jsonb": "JSONB",
            "character varying": "TEXT",
            "uuid": "UUID",
        }
        pg_type = type_map.get(col_type, col_type.upper())
        cols.append(f'  "{col_name}" {pg_type}')
    
    return f'CREATE TABLE IF NOT EXISTS {schema}."{table}" (\n' + ",\n".join(cols) + "\n);"

# ---- TABLE DEFINITIONS ----

# Public tables -> committee schema on Hetzner
PUBLIC_TABLES = {
    "committee_registry": {
        "target_schema": "committee",
        "target_table": "registry",
        "order_col": "id",
        "expected_rows": 10975,
        "columns": [
            ("id", "integer"), ("sboe_id", "text"), ("committee_name", "text"), ("norm_name", "text"),
            ("committee_type", "text"), ("candidate_name", "text"), ("candidate_norm_last", "text"),
            ("candidate_norm_first", "text"), ("committee_city", "text"), ("committee_state", "text"),
            ("committee_zip", "text"), ("total_received", "numeric"), ("total_given", "numeric"),
            ("donation_count", "integer"), ("unique_donors", "integer"), ("first_activity", "date"),
            ("last_activity", "date"), ("fec_committee_id", "text"), ("created_at", "timestamp with time zone"),
            ("source_level", "text"), ("source", "text"), ("role", "text"), ("canonical_id", "integer"),
            ("is_alias", "boolean"), ("gifts_given", "integer"), ("recipients_count", "integer"),
            ("donor_subtype", "text"), ("is_client_subscriber", "boolean"), ("client_tier", "text"),
            ("website_url", "text"), ("facebook_url", "text"), ("twitter_url", "text"),
            ("instagram_url", "text"), ("youtube_url", "text"), ("chairman_name", "text"),
            ("chairman_email", "text"), ("chairman_phone", "text"), ("org_address", "text"),
            ("org_phone", "text"), ("org_email", "text"), ("officers_json", "jsonb"),
            ("org_description", "text"), ("candidate_profile_id", "text"),
        ],
    },
    "committee_office_type_map": {
        "target_schema": "committee",
        "target_table": "office_type_map",
        "order_col": "committee_name",
        "expected_rows": 1550,
        "columns": [
            ("committee_name", "text"), ("office_type", "text"), ("office_level", "text"),
            ("candidate_name", "text"), ("total_amount", "numeric"), ("contribution_count", "integer"),
            ("classification_method", "text"),
        ],
    },
    "boe_committee_candidate_map": {
        "target_schema": "committee",
        "target_table": "boe_candidate_map",
        "order_col": "id",
        "expected_rows": 648,
        "columns": [
            ("id", "integer"), ("sboe_committee_id", "text"), ("committee_name", "text"),
            ("committee_type", "text"), ("party_cd", "text"), ("extracted_name", "text"),
            ("matched_candidate_id", "bigint"), ("matched_candidate_name", "text"),
            ("matched_last_name", "text"), ("matched_first_name", "text"),
            ("matched_party", "text"), ("matched_contest", "text"), ("matched_county", "text"),
            ("match_method", "text"), ("match_confidence", "double precision"),
            ("donation_count", "integer"), ("total_donated", "numeric"),
            ("created_at", "timestamp with time zone"), ("updated_at", "timestamp with time zone"),
        ],
    },
    "committee_party_map": {
        "target_schema": "committee",
        "target_table": "party_map",
        "order_col": "id",
        "expected_rows": 19982,
        "columns": [
            ("id", "bigint"), ("committee_id", "text"), ("committee_name", "text"),
            ("source", "text"), ("party_flag", "text"), ("committee_type", "text"),
            ("candidate_name", "text"), ("candidate_id", "text"),
            ("created_at", "timestamp with time zone"),
        ],
    },
    "ncsbe_candidate_committee_master": {
        "target_schema": "committee",
        "target_table": "ncsbe_candidate_master",
        "order_col": "id",
        "expected_rows": 4165,
        "columns": [
            ("id", "integer"), ("candidate_last_name", "text"), ("candidate_first_name", "text"),
            ("candidate_middle_name", "text"), ("candidate_suffix", "text"),
            ("candidate_nick_name", "text"), ("committee_sboe_id", "text"),
            ("committee_name", "text"), ("committee_type", "text"), ("match_method", "text"),
            ("match_confidence", "text"), ("total_received", "numeric"),
            ("election_years", "text"), ("num_elections", "integer"), ("counties", "text"),
            ("contests", "text"), ("ballot_names", "text"), ("email", "text"), ("phone", "text"),
            ("has_committee", "text"), ("has_donations", "text"),
            ("canonical_candidate_id", "text"), ("created_at", "timestamp with time zone"),
        ],
    },
}

# Core/staging tables (pulled via connector - script generates placeholder)
NONPUBLIC_TABLES = {
    "core.ncboe_committee_registry": {
        "target_schema": "core",
        "target_table": "ncboe_committee_registry",
        "expected_rows": 2032,
        "columns": [
            ("committee_sboe_id", "text"), ("committee_name", "text"), ("committee_type", "text"),
            ("first_seen_year", "integer"), ("last_seen_year", "integer"),
            ("updated_at", "timestamp with time zone"),
        ],
    },
    "core.ncboe_committee_type_lookup": {
        "target_schema": "core",
        "target_table": "ncboe_committee_type_lookup",
        "expected_rows": 2039,
        "columns": [
            ("committee_sboe_id", "text"), ("committee_type", "text"), ("notes", "text"),
        ],
    },
    "core.candidate_committee_map": {
        "target_schema": "core",
        "target_table": "candidate_committee_map",
        "expected_rows": 5761,
        "columns": [
            ("id", "integer"), ("committee_id", "text"), ("committee_name", "text"),
            ("committee_source", "text"), ("committee_type", "text"), ("candidate_id", "uuid"),
            ("candidate_name", "text"), ("tenant_id", "uuid"), ("election_cycle", "text"),
            ("office", "text"), ("state", "text"), ("district", "text"),
            ("match_confidence", "numeric"), ("created_at", "timestamp with time zone"),
            ("fec_cand_id", "text"),
        ],
    },
    "staging.sboe_committee_master": {
        "target_schema": "staging",
        "target_table": "sboe_committee_master",
        "expected_rows": 13237,
        "columns": [
            ("sboe_id", "text"), ("old_id", "text"), ("committee_name", "text"),
            ("candidate_name", "text"), ("status", "text"),
            ("loaded_at", "timestamp with time zone"),
        ],
    },
    "staging.committee_candidate_bridge": {
        "target_schema": "staging",
        "target_table": "committee_candidate_bridge",
        "expected_rows": 864,
        "columns": [
            ("committee_sboe_id", "text"), ("committee_name", "text"),
            ("registry_candidate_name", "text"), ("name_on_ballot", "text"),
            ("contest_name", "text"), ("county_name", "text"),
            ("party_candidate", "text"), ("election_dt", "text"),
            ("match_confidence", "numeric"), ("match_method", "text"),
        ],
    },
}


def main():
    phase = sys.argv[1] if len(sys.argv) > 1 else "all"
    
    if phase in ("ddl", "all"):
        print("=" * 60)
        print("PHASE 1: Create schemas and tables on Hetzner")
        print("=" * 60)
        
        # Create committee schema
        result = psql_cmd("CREATE SCHEMA IF NOT EXISTS committee;")
        print(f"Create committee schema: {result.stdout.strip()}")
        
        # Create all tables
        for tables_dict in [PUBLIC_TABLES, NONPUBLIC_TABLES]:
            for src_name, spec in tables_dict.items():
                schema = spec["target_schema"]
                table = spec["target_table"]
                ddl = generate_create_table_sql(schema, table, spec["columns"])
                
                # Write DDL to temp file and execute
                ssh_cmd(f"cat > /tmp/ddl_{table}.sql << 'SQEOF'\n{ddl}\nSQEOF")
                result = psql_file(f"/tmp/ddl_{table}.sql")
                print(f"  Created {schema}.{table}: {result.stdout.strip()} {result.stderr.strip()}")
        
        print()
    
    if phase in ("public", "all"):
        print("=" * 60)
        print("PHASE 2: Load public tables via REST API")
        print("=" * 60)
        
        for src_name, spec in PUBLIC_TABLES.items():
            schema = spec["target_schema"]
            table = spec["target_table"]
            print(f"\n--- {src_name} -> {schema}.{table} ---")
            
            # Truncate first (safe — these are new empty tables)
            psql_cmd(f'TRUNCATE {schema}."{table}";')
            
            # Fetch via REST API
            rows = fetch_rest_api_table(src_name, spec["order_col"])
            print(f"  Total fetched: {len(rows)} (expected: {spec['expected_rows']})")
            
            if not rows:
                print("  SKIPPED - no rows fetched")
                continue
            
            # Generate SQL and load
            col_names = [c[0] for c in spec["columns"]]
            sql = generate_insert_sql(schema, table, rows, col_names)
            
            # Write SQL to local file, then SCP to Hetzner
            local_path = f"/home/user/workspace/chunks/{table}_insert.sql"
            with open(local_path, "w") as f:
                f.write(sql)
            
            file_size = len(sql)
            print(f"  Generated SQL: {file_size:,} bytes")
            
            # SCP to Hetzner
            scp_cmd = f"sshpass -p '{HETZNER_PASS}' scp -o StrictHostKeyChecking=no {local_path} root@{HETZNER_HOST}:/tmp/{table}_insert.sql"
            subprocess.run(scp_cmd, shell=True, capture_output=True, timeout=60)
            
            # Execute on Hetzner
            result = psql_file(f"/tmp/{table}_insert.sql")
            print(f"  Load result: {result.stdout.strip()}")
            if result.stderr.strip():
                print(f"  Stderr: {result.stderr.strip()[:500]}")
            
            # Verify count
            result = psql_cmd(f'SELECT COUNT(*) FROM {schema}."{table}";')
            print(f"  Verify count: {result.stdout.strip()}")
    
    if phase in ("nonpublic", "all"):
        print("=" * 60)
        print("PHASE 3: Non-public tables need connector (handled separately)")
        print("=" * 60)
        print("These tables require the Supabase connector execute_sql with pagination.")
        print("Run the companion script or manual connector calls for:")
        for src_name, spec in NONPUBLIC_TABLES.items():
            print(f"  {src_name} -> {spec['target_schema']}.{spec['target_table']} ({spec['expected_rows']} rows)")


if __name__ == "__main__":
    main()
