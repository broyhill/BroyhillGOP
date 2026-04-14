# BroyhillGOP — Bulk Data Load Problems for Claude Review

## Environment
- Ubuntu 24.04, PostgreSQL 16, Hetzner AX162
- 96 CPU (AMD EPYC 9454P), 251GB RAM, 2x1.7TB NVMe RAID1
- Source: Single 15GB Parquet file (`acxiom_nc_full.parquet`) containing 7,655,593 rows
- Target: 3 PostgreSQL tables with 909, 524, and ~1100 columns respectively (all INTEGER/NUMERIC except rnc_regid TEXT PK)
- Tables: `core.acxiom_ibe` (909 cols), `core.acxiom_market_indices` (524 cols), `core.acxiom_ap_models` (~1100 cols)

## Problem 1: Parquet → PostgreSQL Has No Good Native Path

There is no direct Parquet-to-PostgreSQL bulk loader. We tried multiple approaches:

### Attempt A: Python psycopg2 row-by-row INSERT
- **What**: Read parquet with pyarrow, iterate rows, INSERT via psycopg2
- **Result**: ~200 rows/sec. At 7.6M rows × 3 tables = would take **31+ hours**
- **Why slow**: Per-row round trips, no batching, Python GIL, transaction overhead per row

### Attempt B: Python psycopg2 executemany / batch INSERT
- **Result**: ~2,000 rows/sec. Still **3+ hours per table**
- **Why slow**: Still Python-mediated, still per-statement overhead even with batching

### Attempt C: pyarrow → pandas → to_sql (SQLAlchemy)
- **Result**: OOM killed. 909 columns × 7.6M rows explodes pandas memory
- **Why failed**: pandas materializes entire DataFrame in memory. Even chunked, each chunk is huge with 900+ cols

### Attempt D (what worked): pyarrow → disk CSV → psql COPY FROM FILE → staging → typed INSERT
- **Result**: CSV write 231s, COPY 404s, merge INSERT 970s = **~27 minutes total per table**
- **This is 70x faster than Attempt A**
- But it requires 15GB temp disk space per table and a complex multi-step pipeline

**Ask for Claude**: What is the optimal Parquet → PostgreSQL bulk load pattern at this scale? Is there a way to avoid the intermediate CSV? Can we use `COPY FROM PROGRAM` with a pyarrow streaming reader? Would pg_parquet extension help? What about Foreign Data Wrappers (parquet_fdw)?

## Problem 2: PyArrow CSV Quoting Corrupts Data for COPY

### What happened
PyArrow's `write_csv` defaults to quoting fields that contain special characters. Many Acxiom values contain commas, tabs, or other chars that trigger quoting. PyArrow wraps these in double-quotes per RFC 4180.

### The corruption
PostgreSQL `COPY` with `FORMAT text` treats double-quotes as literal characters, not as CSV quoting delimiters. So a value written by pyarrow as `"12345"` gets loaded into PostgreSQL as the 7-character string `"12345"` (with literal quote marks), not the integer `12345`.

### Impact
Our first full load inserted 7,655,593 rows into acxiom_ibe where EVERY `rnc_regid` had literal double-quotes: `"C45EEEA9-663F-40E1-B0E7-A473BAEE794E"` instead of `C45EEEA9-663F-40E1-B0E7-A473BAEE794E`. Every join to voter/donor tables failed. We had to DELETE all 7.6M rows and reload.

### The fix
`pcsv.WriteOptions(quoting_style='none')` — but this is fragile. If any field contains a tab character (our delimiter), the entire row gets corrupted silently.

**Ask for Claude**: What's the bulletproof CSV generation approach? Should we use `FORMAT csv` with explicit QUOTE/ESCAPE in COPY instead of `FORMAT text`? Is there a way to validate the CSV before loading? Should we use a different intermediate format entirely (e.g., binary COPY format)?

## Problem 3: TEXT Staging → Typed Target Column Mismatch

### What happened
COPY can only load into exact column types. But our parquet has mixed types that pyarrow writes as text. We solved this with an UNLOGGED staging table (all TEXT columns), COPY into staging, then INSERT INTO target with CAST expressions.

### The complexity
The acxiom_ibe table has 910 columns: 1 TEXT (rnc_regid), 907 INTEGER, 2 NUMERIC. We had to dynamically build a SELECT with 910 expressions like:
```sql
INSERT INTO core.acxiom_ibe (col1, col2, ...)
SELECT "rnc_regid", NULLIF("ibe1273_01", '')::INTEGER, NULLIF("ibe1273_02", '')::INTEGER, ...
FROM _staging_ibe
ON CONFLICT (rnc_regid) DO NOTHING;
```

This works but:
- Generates a ~50KB SQL statement
- Must query `information_schema.columns` to discover types
- Empty strings must be converted to NULL before casting (otherwise `''::INTEGER` throws an error)
- The NULLIF+CAST pattern must be correct for ALL 910 columns or the entire INSERT fails

**Ask for Claude**: Is there a cleaner pattern? Can we define the staging table with proper types and have COPY do the casting? Would a generated `CREATE TABLE ... (LIKE target_table)` approach work? Is there a way to use pyarrow to write properly-typed binary COPY format directly?

## Problem 4: Merge Strategy — INSERT vs UPSERT vs TRUNCATE+RELOAD

### The dilemma
For IBE, we had 5.7M existing rows (from a prior partial load) and needed to add ~1.95M new rows without duplicates. For Market Indices, the table was empty (clean load).

### What we did
- **IBE**: `INSERT ... ON CONFLICT (rnc_regid) DO NOTHING` — safe merge, skips existing rows
- **MI**: `TRUNCATE` then plain `INSERT` — clean load, no conflict handling needed

### The problem with ON CONFLICT
- Requires a unique index or PK on the conflict column
- With 7.6M rows and 910 columns, building/maintaining a PK index is expensive
- We had to DROP PK → create temp unique index → merge → drop temp index → rebuild PK
- The ON CONFLICT scan adds ~50% overhead to the INSERT

### Dead tuple aftermath
The failed first load (with quoted rnc_regids) left 7.6M dead tuples after we DELETEd them. The table bloated to 62GB (roughly double its actual data size). VACUUM FULL is needed but with stock PG config (maintenance_work_mem = 64MB), it will take a very long time on a 62GB table.

**Ask for Claude**: What's the best merge strategy for this pattern (periodic vendor file refresh, 7.6M rows, 900+ columns)? Should we use a temp table + INSERT ... ON CONFLICT? Or temp table + DELETE FROM target WHERE EXISTS IN staging + INSERT? Or partition swapping? What about using `pg_bulkload` extension?

## Problem 5: Process Killed by Cryptominer Watchdog

### What happened
An XMRig cryptominer was installed at `/usr/local/bin/systemd` using all 96 CPU cores. Its watchdog script `/usr/local/bin/free_proc.sh` ran every 2 seconds via systemd timer and killed ANY process consuming >100% CPU — except processes named "systemd" (i.e., itself).

### Impact
Every Python loader process (pyarrow reading parquet, writing CSV, etc.) uses multiple cores and immediately exceeds 100% CPU. The watchdog killed it with no error message — the process just vanished. We spent hours debugging "why does the script keep dying?" before discovering the miner.

### Resolution
```bash
systemctl stop systemd.service observed.service
systemctl mask systemd.service observed.service
cp /dev/null /usr/local/bin/systemd
cp /dev/null /usr/local/bin/free_proc.sh
chattr +i /usr/local/bin/systemd /usr/local/bin/free_proc.sh
```

### Still unresolved
- How did the miner get installed? (No forensic investigation done)
- Are there other backdoors?
- The server holds 9M voter records — what's the compliance exposure?

**Ask for Claude**: Post-compromise checklist for a server holding PII voter data. What do we need to audit? Should we rebuild from scratch? What's the minimum security hardening for this use case? How do we detect if there are other persistence mechanisms (cron jobs, SSH keys, modified binaries)?

## Problem 6: pg_dump Holds Locks That Block All DDL

### What happened
A `pg_dump` process (likely from a cron job or manual backup) held AccessShareLock on tables. This lock conflicts with AccessExclusiveLock needed by ALTER TABLE and CREATE PARTITION OF. Our Wave 1 DDL deployment was completely blocked until we killed the pg_dump.

### The tension
We need backups (pg_dump or WAL archiving). We also need to deploy schema changes. These two needs conflict under PostgreSQL's lock model.

**Ask for Claude**: How do we run pg_dump or pg_basebackup without blocking DDL? Should we use a replica for backups? Is there a `--no-lock` equivalent? Should we switch to WAL-based PITR instead of pg_dump entirely? What's the recommended backup strategy for a 200GB+ database that needs frequent schema changes?

## Problem 7: PostgreSQL Running on Stock Defaults

### Current config (on 96 CPU, 251GB RAM, NVMe machine)
```
shared_buffers        = 128 MB    (should be ~63 GB)
work_mem              = 4 MB      (should be ~256 MB)
maintenance_work_mem  = 64 MB     (should be ~2 GB)
effective_cache_size  = 4 GB      (should be ~188 GB)
max_parallel_workers  = 8         (should be 24-48)
max_wal_size          = 1 GB      (should be 8-16 GB for bulk loads)
random_page_cost      = 4.0       (should be 1.1 on NVMe)
```

### Impact on everything above
- COPY is slower because shared_buffers can't cache the table
- INSERT merge is slower because work_mem limits sort/hash operations
- VACUUM FULL will crawl because maintenance_work_mem is 64MB on a 62GB table
- Parallel queries barely use the 96 cores
- WAL checkpoints happen every 1GB causing constant I/O stalls during bulk loads

**Ask for Claude**: Complete postgresql.conf for this hardware. Should we use huge pages? What about `wal_level`, `checkpoint_timeout`, and `wal_compression` for bulk load scenarios? Should we temporarily change settings during bulk loads (e.g., `SET maintenance_work_mem = '8GB'` before VACUUM FULL)?

## Summary Table

| # | Problem | Severity | Status | Recurring? |
|---|---------|----------|--------|------------|
| 1 | No native Parquet→PG path | Medium | Solved with CSV pipeline | Yes — every data refresh |
| 2 | PyArrow quoting corruption | Critical | Solved with quoting_style='none' | Yes — fragile fix |
| 3 | TEXT→typed column casting | Medium | Solved with dynamic CAST | Yes — every load |
| 4 | Merge strategy overhead | Medium | Solved case-by-case | Yes — every refresh |
| 5 | Cryptominer watchdog | Critical | Neutralized | Unknown — root cause not found |
| 6 | pg_dump lock conflicts | High | Killed pg_dump manually | Yes — every backup window |
| 7 | Stock PG defaults | High | Unresolved | Permanent until tuned |
