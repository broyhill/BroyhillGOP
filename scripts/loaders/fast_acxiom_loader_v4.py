#!/usr/bin/env python3
"""
Fast Acxiom IBE + Market Indices loader v4.
Strategy: Parquet -> disk CSV -> psql COPY FROM FILE.
No in-memory casting. Minimal Python memory footprint.
Processes one row group at a time, appends to CSV on disk.
"""
import pyarrow.parquet as pq
import pyarrow.csv as pcsv
import pyarrow as pa
import subprocess
import os, re, time

PARQUET = '/data/acxiom/acxiom_nc_full.parquet'
TMPDIR = '/data/acxiom/tmp'
DB_CONN = "host=localhost port=5432 user=postgres password=${PGPASSWORD} dbname=postgres"

def to_snake(name):
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', name)
    s = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s)
    return s.lower().replace(' ', '_').replace('-', '_')

def log(msg):
    ts = time.strftime('%H:%M:%S')
    print('[' + ts + '] ' + msg, flush=True)

def write_csv_for_table(parquet_cols, label):
    """Write parquet columns to a tab-separated CSV file on disk."""
    os.makedirs(TMPDIR, exist_ok=True)
    csv_path = TMPDIR + '/' + label + '.csv'

    pf = pq.ParquetFile(PARQUET)
    cols_to_read = ['RNC_RegID'] + parquet_cols
    snake_cols = [to_snake(c) for c in parquet_cols]
    new_names = ['rnc_regid'] + snake_cols
    num_rgs = pf.metadata.num_row_groups
    total_rows = 0
    start = time.time()

    # Write row groups one at a time to disk — minimal memory
    with open(csv_path, 'wb') as f:
        for rg_idx in range(num_rgs):
            table = pf.read_row_group(rg_idx, columns=cols_to_read)
            table = table.rename_columns(new_names)

            # Write as CSV (pyarrow handles type conversion to text automatically)
            buf = pa.BufferOutputStream()
            opts = pcsv.WriteOptions(delimiter='\t', include_header=False, quoting_style='none')
            pcsv.write_csv(table, buf, write_options=opts)
            f.write(buf.getvalue().to_pybytes())

            total_rows += table.num_rows
            del table  # Free memory immediately

            if (rg_idx + 1) % 50 == 0 or rg_idx == num_rgs - 1:
                elapsed = time.time() - start
                rate = int(total_rows / elapsed) if elapsed > 0 else 0
                sz = os.path.getsize(csv_path) / 1e9
                log(label + ': ' + str(total_rows) + ' rows written (' +
                    str(rg_idx+1) + '/' + str(num_rgs) + ' rg, ' +
                    str(rate) + '/sec, ' + str(round(sz, 2)) + ' GB)')

    elapsed = time.time() - start
    sz = os.path.getsize(csv_path) / 1e9
    log(label + ': CSV complete — ' + str(total_rows) + ' rows, ' +
        str(round(sz, 2)) + ' GB in ' + str(int(elapsed)) + 's')
    return csv_path, new_names, total_rows

def psql_cmd(sql):
    """Run SQL via psql subprocess."""
    cmd = ['psql', '-h', 'localhost', '-U', 'postgres', '-d', 'postgres',
           '-v', 'ON_ERROR_STOP=1', '-c', sql]
    env = os.environ.copy()
    env['PGPASSWORD'] = os.environ.get('PGPASSWORD', 'SET_PGPASSWORD_ENV_VAR')
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        log('SQL ERROR: ' + result.stderr)
        raise Exception('psql failed: ' + result.stderr)
    return result.stdout.strip()

def copy_from_file(csv_path, target_table, col_names):
    """Use psql \\copy to load CSV into table."""
    col_list = ','.join('"' + c + '"' for c in col_names)
    sql = "\\copy " + target_table + " (" + col_list + ") FROM '" + csv_path + "' WITH (FORMAT text)"
    cmd = ['psql', '-h', 'localhost', '-U', 'postgres', '-d', 'postgres',
           '-v', 'ON_ERROR_STOP=1', '-c', sql]
    env = os.environ.copy()
    env['PGPASSWORD'] = os.environ.get('PGPASSWORD', 'SET_PGPASSWORD_ENV_VAR')
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        log('COPY ERROR: ' + result.stderr)
        raise Exception('COPY failed: ' + result.stderr)
    return result.stdout.strip()

def do_ibe(parquet_cols):
    """Complete IBE load: CSV -> staging -> merge -> cleanup."""
    snake_cols = [to_snake(c) for c in parquet_cols]
    all_snake = ['rnc_regid'] + snake_cols

    # Step 1: Write CSV
    csv_path, col_names, total_rows = write_csv_for_table(parquet_cols, 'ibe')

    # Step 2: Create staging table
    log('IBE: Creating staging table...')
    col_defs = ', '.join('"' + c + '" TEXT' for c in all_snake)
    psql_cmd('DROP TABLE IF EXISTS _staging_ibe;')
    psql_cmd('CREATE UNLOGGED TABLE _staging_ibe (' + col_defs + ');')

    # Step 3: COPY CSV into staging
    log('IBE: Loading CSV into staging...')
    start = time.time()
    copy_from_file(csv_path, '_staging_ibe', col_names)
    log('IBE: COPY done in ' + str(int(time.time() - start)) + 's')

    # Step 4: Get target columns WITH types for proper casting
    cmd = ['psql', '-h', 'localhost', '-U', 'postgres', '-d', 'postgres', '-t', '-A', '-c',
           "SELECT column_name || '|' || data_type FROM information_schema.columns WHERE table_schema='core' AND table_name='acxiom_ibe' AND column_name != 'created_at' ORDER BY ordinal_position;"]
    env = os.environ.copy()
    env['PGPASSWORD'] = os.environ.get('PGPASSWORD', 'SET_PGPASSWORD_ENV_VAR')
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    target_cols = []
    select_exprs = []
    for line in result.stdout.strip().split('\n'):
        if '|' not in line:
            continue
        col_name, data_type = line.split('|', 1)
        target_cols.append('"' + col_name + '"')
        if data_type == 'text':
            select_exprs.append('"' + col_name + '"')
        elif data_type == 'integer':
            select_exprs.append('NULLIF("' + col_name + '", \'\')::INTEGER')
        elif data_type == 'numeric':
            select_exprs.append('NULLIF("' + col_name + '", \'\')::NUMERIC')
        else:
            select_exprs.append('"' + col_name + '"::' + data_type)
    target_list = ', '.join(target_cols)
    select_list = ', '.join(select_exprs)
    log('IBE: ' + str(len(target_cols)) + ' target columns mapped with types')

    # Step 5: Merge
    log('IBE: Dropping PK...')
    psql_cmd('ALTER TABLE core.acxiom_ibe DROP CONSTRAINT IF EXISTS acxiom_ibe_pkey;')

    log('IBE: Creating temp unique index...')
    psql_cmd('CREATE UNIQUE INDEX IF NOT EXISTS _tmp_ibe_rnc ON core.acxiom_ibe (rnc_regid);')

    log('IBE: Merging staging -> core.acxiom_ibe...')
    start = time.time()
    out = psql_cmd('INSERT INTO core.acxiom_ibe (' + target_list + ') SELECT ' + select_list + ' FROM _staging_ibe ON CONFLICT (rnc_regid) DO NOTHING;')
    log('IBE: Merge done in ' + str(int(time.time() - start)) + 's — ' + out)

    log('IBE: Rebuilding PK...')
    start = time.time()
    psql_cmd('DROP INDEX IF EXISTS _tmp_ibe_rnc;')
    psql_cmd('ALTER TABLE core.acxiom_ibe ADD PRIMARY KEY (rnc_regid);')
    log('IBE: PK rebuilt in ' + str(int(time.time() - start)) + 's')

    # Cleanup
    psql_cmd('DROP TABLE IF EXISTS _staging_ibe;')
    os.remove(csv_path)
    log('IBE: Cleanup done')

def do_mi(parquet_cols):
    """Complete Market Indices load."""
    snake_cols = [to_snake(c) for c in parquet_cols]
    all_snake = ['rnc_regid'] + snake_cols

    csv_path, col_names, total_rows = write_csv_for_table(parquet_cols, 'mi')

    log('MI: Creating staging...')
    col_defs = ', '.join('"' + c + '" TEXT' for c in all_snake)
    psql_cmd('DROP TABLE IF EXISTS _staging_mi;')
    psql_cmd('CREATE UNLOGGED TABLE _staging_mi (' + col_defs + ');')

    log('MI: Loading CSV into staging...')
    start = time.time()
    copy_from_file(csv_path, '_staging_mi', col_names)
    log('MI: COPY done in ' + str(int(time.time() - start)) + 's')

    # Get target columns WITH types
    cmd = ['psql', '-h', 'localhost', '-U', 'postgres', '-d', 'postgres', '-t', '-A', '-c',
           "SELECT column_name || '|' || data_type FROM information_schema.columns WHERE table_schema='core' AND table_name='acxiom_market_indices' AND column_name != 'created_at' ORDER BY ordinal_position;"]
    env = os.environ.copy()
    env['PGPASSWORD'] = os.environ.get('PGPASSWORD', 'SET_PGPASSWORD_ENV_VAR')
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    target_cols = []
    select_exprs = []
    for line in result.stdout.strip().split('\n'):
        if '|' not in line:
            continue
        col_name, data_type = line.split('|', 1)
        target_cols.append('"' + col_name + '"')
        if data_type == 'text':
            select_exprs.append('"' + col_name + '"')
        elif data_type == 'integer':
            select_exprs.append('NULLIF("' + col_name + '", \'\')::INTEGER')
        elif data_type == 'numeric':
            select_exprs.append('NULLIF("' + col_name + '", \'\')::NUMERIC')
        else:
            select_exprs.append('"' + col_name + '"::' + data_type)
    target_list = ', '.join(target_cols)
    select_list = ', '.join(select_exprs)

    log('MI: Truncating target...')
    psql_cmd('TRUNCATE core.acxiom_market_indices;')

    log('MI: Inserting from staging...')
    start = time.time()
    out = psql_cmd('INSERT INTO core.acxiom_market_indices (' + target_list + ') SELECT ' + select_list + ' FROM _staging_mi;')
    log('MI: Insert done in ' + str(int(time.time() - start)) + 's — ' + out)

    log('MI: Adding PK...')
    psql_cmd('ALTER TABLE core.acxiom_market_indices ADD PRIMARY KEY (rnc_regid);')

    psql_cmd('DROP TABLE IF EXISTS _staging_mi;')
    os.remove(csv_path)
    log('MI: Done')

def main():
    pf = pq.ParquetFile(PARQUET)
    all_cols = pf.schema_arrow.names
    ibe_cols = [c for c in all_cols if c.startswith('IBE')]
    mi_cols = [c for c in all_cols if c.startswith('mi')]

    log('=== FAST ACXIOM LOADER v4 ===')
    log('IBE: ' + str(len(ibe_cols)) + ' cols, MI: ' + str(len(mi_cols)) + ' cols')
    log('Parquet: ' + str(pf.metadata.num_rows) + ' rows, ' + str(pf.metadata.num_row_groups) + ' row groups')
    log('Strategy: parquet -> disk CSV -> COPY -> staging -> merge')

    log('')
    log('=== PHASE 1: IBE ===')
    do_ibe(ibe_cols)

    log('')
    log('=== PHASE 2: MARKET INDICES ===')
    do_mi(mi_cols)

    # Canary
    log('')
    log('=== BROYHILL CANARY ===')
    out = psql_cmd("SELECT count(*) FROM core.acxiom_ibe WHERE rnc_regid = 'c45eeea9-663f-40e1-b0e7-a473baee794e';")
    log('Ed Broyhill IBE: ' + ('FOUND' if '1' in out else 'MISSING'))
    out = psql_cmd("SELECT count(*) FROM core.acxiom_market_indices WHERE rnc_regid = 'c45eeea9-663f-40e1-b0e7-a473baee794e';")
    log('Ed Broyhill MI: ' + ('FOUND' if '1' in out else 'MISSING'))

    log('')
    log('=== COMPLETE ===')

if __name__ == '__main__':
    main()
