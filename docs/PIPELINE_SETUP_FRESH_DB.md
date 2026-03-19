# NCBOE + NCGOP Pipeline — Fresh Database Setup

For a Supabase database with no existing tables.

---

## Step 1: Run DDL

Execute the SQL in `scripts/001_create_pipeline_tables.sql` against your Supabase database:

```bash
psql "$SUPABASE_DB_URL" -f scripts/001_create_pipeline_tables.sql
```

Or paste the contents into the Supabase SQL Editor and run.

---

## Step 2: Load NC Voter File (~9M rows)

The pipeline needs `public.nc_voters` with columns: `statevoterid`, `last_name`, `first_name`, `zip_code`, `res_city_desc`.

### Option A: NCSBE CSV/pipe-delimited with headers

If your voter file has headers and matches (or can be mapped to) these columns:

```bash
# Map your columns to: statevoterid, last_name, first_name, zip_code, res_city_desc
# NCSBE often uses voter_reg_num — load it into statevoterid
psql "$SUPABASE_DB_URL" -c "\COPY nc_voters(statevoterid, last_name, first_name, zip_code, res_city_desc) FROM 'voter_file.csv' WITH (FORMAT csv, HEADER true, DELIMITER '|');"
```

### Option B: Python loader (flexible column mapping)

Create `scripts/load_nc_voters.py` if your file format differs. The table expects:
- `statevoterid` (PK) — voter registration number
- `last_name`, `first_name`, `zip_code`, `res_city_desc`

### Option C: Supabase Table Editor / CSV import

Upload via Supabase Dashboard → Table Editor → nc_voters → Import.

---

## Step 3: Load NCBOE Data

### If you have NCBOE CSV files (Committee SBoE ID, Date Occured, Contributor Name, etc.):

```bash
python3 scripts/import_ncboe_raw.py NCBOE-2015-2019.csv
python3 scripts/import_ncboe_raw.py NCBOE-2020-2026-part1.csv
python3 scripts/import_ncboe_raw.py NCBOE-2020-2026-part2.csv
```

### If nc_boe_donations_raw is empty

The normalize step will have nothing to process. You must load NCBOE data first (from NCSBE campaign finance downloads) or skip Steps 4–6 for NCBOE.

---

## Step 4: Run Pipeline (after voter + NCBOE loaded)

```bash
cd /tmp/BroyhillGOP  # or your project root

# Step 1 — Validate NCGOP file
python3 scripts/validate_source_files.py NCGOP_WinRed_03:10:2026.csv

# Step 2 — Stage NCGOP (use --no-header --encoding latin-1 if file has no headers)
python3 scripts/import_ncgop_staging.py --no-header --encoding latin-1 NCGOP_WinRed_03:10:2026.csv

# Step 3 — Match NCGOP → voters
python3 scripts/match_ncgop_to_voters.py

# Step 4 — Normalize NCBOE (requires nc_boe_donations_raw populated)
python3 scripts/normalize_ncboe.py

# Step 5 — Dry run golden records
python3 scripts/build_donor_golden_records.py --dry-run

# Step 6 — Dry run contributions
python3 scripts/build_contributions.py --dry-run
```

---

## WinRed File: No Header Row

The NCGOP WinRed file has **no header row** and **latin-1 encoding**. Use:

```bash
python3 scripts/import_ncgop_staging.py --no-header --encoding latin-1 /tmp/BroyhillGOP/NCGOP_WinRed_03:10:2026.csv
```

You must add `--no-header` and `--encoding latin-1` support to `import_ncgop_staging.py` if not already present.
