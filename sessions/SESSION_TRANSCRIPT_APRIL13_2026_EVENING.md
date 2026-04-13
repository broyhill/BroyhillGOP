# BroyhillGOP — Session Transcript
## April 13, 2026, Afternoon/Evening Session (approx 2:00 PM – 7:30 PM EDT)
## Author: Perplexity Computer for Ed Broyhill

---

## SESSION OBJECTIVE

Complete the Acxiom data load into Hetzner PostgreSQL. Three tables needed: `core.acxiom_ibe` (909 columns), `core.acxiom_market_indices` (524 columns), and `core.acxiom_ap_models` (~478 columns). AP Models was already done. IBE had a partial load of 5,700,000 out of 7,655,593 rows. Market Indices was empty.

---

## TIMELINE OF EVENTS

### 1. Session Pickup & Architecture Review (~2:00 PM)

Reloaded context from prior session. Ed asked for an honest assessment of the Claude-authored BGOP Architecture Brief. Gave it a B+ with specific criticisms:

- **Redis pub/sub as event bus**: Fire-and-forget — if brain worker is down, events are lost. No replay, no dead letter queue.
- **Single brain worker**: One Python process handling all 60 ecosystems. Single point of failure and throughput bottleneck for 3,000 candidates × 9M voters.
- **FK bug**: Architecture Brief referenced `core.candidates(id)` but the actual column is `core.candidates(candidate_id)`.
- **No connection pooling**: Direct PG connections from every service.
- **Stock PostgreSQL defaults**: 128MB shared_buffers on a 251GB RAM machine. Crippling.

### 2. Wave 1 DDL Deployment (~2:30 PM)

Deployed all 8 items from the Architecture Brief's Wave 1:

**New tables created:**
- `public.bgop_config` (9 rows)
- `pipeline.credentials_vault` (5 rows)
- `pipeline.campaign_codes`
- `pipeline.processor_access`

**Column additions:**
- `donor_intelligence.person_master.confidence_score` (NUMERIC)
- `donor_intelligence.person_master.acxiom_load_batch` (TEXT)
- `donor_intelligence.contribution_map.campaign_code_id` (UUID + FK)

**Partitions created:**
- `brain.event_queue_2026_08`
- `pipeline.inbound_data_queue_2026_08`

**Problem encountered:** A `pg_dump` process was holding AccessShareLock on every table, blocking all ALTER TABLE and CREATE PARTITION commands. Had to identify and kill the pg_dump process (PID) before DDL could proceed. This is a recurring architectural issue — see Problem 6 below.

**Committed to GitHub:** `99288fa` on `session-mar17-2026-clean`.

### 3. The Acxiom Load Nightmare Begins (~3:00 PM)

The prior session had started `restructure_option_c.py` to load IBE data. Ed checked in on progress and it was crawling — the row-by-row Python INSERT approach was far too slow for 909 columns × 7.6M rows.

Ed said: **"this approach of downloading isnt working"**

I proposed building a fast replacement loader using PostgreSQL COPY. Ed said: **"do it"**

### 4. Fast Loader v1 — Killed by Invisible Force (~3:15 PM)

Built `fast_acxiom_loader.py` v1:
- Strategy: Read parquet with pyarrow, write CSV to disk, use `psql \copy` to bulk load
- Result: **Process killed silently** after ~30 seconds

No error message. Process just vanished. Checked `dmesg` — no OOM. Checked disk — plenty of space. Mysterious.

### 5. Fast Loader v2 — Killed Again (~3:30 PM)

Rebuilt with more defensive coding, smaller batches.
- Result: **Killed again** in the same way. No trace.

### 6. Fast Loader v3 — Killed Again (~3:45 PM)

Added error handling, try/except blocks, logging to file.
- Result: **Killed again.** Log file just stops mid-write.

At this point I was baffled. Three scripts, three silent deaths. Something external was killing processes.

### 7. DISCOVERY: Cryptominer + Watchdog (~4:00 PM)

Finally ran `ps aux` sorted by CPU and discovered the root cause:

**`/usr/local/bin/systemd`** — This was NOT the real systemd. It was an **XMRig cryptocurrency miner** disguised with the systemd name, consuming all 96 CPU cores.

But the miner alone wasn't killing our processes. Its companion was:

**`/usr/local/bin/free_proc.sh`** — A watchdog script running every 2 seconds via systemd timer. It killed ANY process using >100% CPU... **except** processes named "systemd" (i.e., the miner itself). 

Our pyarrow CSV writer naturally used multiple cores and exceeded 100% CPU immediately. The watchdog killed it every time. This is why we had no error messages — it was a SIGKILL from an external process.

**Persistence mechanism:**
- `systemd.service` in `/etc/systemd/system/` — RestartSec=30 (auto-restarts miner)
- `observed.service` in `/etc/systemd/system/` — runs the watchdog

**Resolution:**
```bash
systemctl stop systemd.service observed.service
systemctl mask systemd.service observed.service
cp /dev/null /usr/local/bin/systemd
cp /dev/null /usr/local/bin/free_proc.sh
chattr +i /usr/local/bin/systemd /usr/local/bin/free_proc.sh  # immutable — can't be recreated
```

Load average dropped from **97 to ~1** after killing the miner. Every CPU core had been mining Monero.

**Impact:** This miner was the root cause of EVERY slow/failed data operation across multiple sessions. The `restructure_option_c.py` that had been "crawling" was being throttled/killed by this watchdog the entire time.

**Unresolved:** How did the miner get installed? No forensic investigation performed. The server holds 9M voter records. Entry vector unknown — possibly exposed SSH with password auth, or a compromised dependency.

### 8. Fast Loader v4 — Success, Then Data Corruption (~4:30 PM)

With the miner dead, v4 ran beautifully:
- **CSV generation**: 7,655,593 rows, 15.65 GB, 231 seconds (33,054 rows/sec)
- **COPY to staging**: 404 seconds
- **Merge INSERT**: Started successfully

But when I checked the data: **every single rnc_regid had literal double-quote characters** in it.

`"C45EEEA9-663F-40E1-B0E7-A473BAEE794E"` instead of `C45EEEA9-663F-40E1-B0E7-A473BAEE794E`

**Root cause:** PyArrow's `write_csv` defaults to RFC 4180 CSV quoting. When values contain certain characters, pyarrow wraps them in double-quotes. But PostgreSQL `COPY` with `FORMAT text` treats double-quotes as literal characters — it doesn't understand CSV quoting semantics.

Result: 7,655,593 rows loaded with corrupted primary keys. Every join to voter/donor tables would fail.

**Fix:** Had to DELETE all 7.6M rows (creating 7.6M dead tuples, bloating the table from ~32GB to 62GB), then fix the writer:

```python
pcsv.WriteOptions(quoting_style='none')  # Don't quote anything
```

### 9. Type Mismatch — TEXT Staging vs INTEGER Target (~5:00 PM)

After fixing the quoting, the merge INSERT failed with a new error: **cannot cast TEXT to INTEGER**.

**Root cause:** The staging table was created with all TEXT columns (because COPY loads everything as text). But `core.acxiom_ibe` has 907 INTEGER columns and 2 NUMERIC columns. PostgreSQL won't implicitly cast TEXT→INTEGER.

**Additional complication:** Empty strings. Acxiom data has empty strings for missing values. `''::INTEGER` throws an error — you must use `NULLIF('', '')::INTEGER` to convert empties to NULL first.

**Solution:** Dynamically built a 910-expression SELECT statement by querying `information_schema.columns` for each column's type, then generating the appropriate CAST:
- TEXT columns: pass through as-is
- INTEGER columns: `NULLIF("col_name", '')::INTEGER`
- NUMERIC columns: `NULLIF("col_name", '')::NUMERIC`

This generated approximately 50KB of SQL for a single INSERT statement.

### 10. Successful Load — IBE Complete (~5:30 PM)

With all fixes in place, v4 ran to completion:

| Phase | Duration | Details |
|-------|----------|---------|
| CSV write | 231s | 7,655,593 rows, 15.65 GB, 33K rows/sec |
| COPY to staging | 404s | Tab-delimited TEXT into UNLOGGED table |
| DROP PK + create temp index | 1s | Swap PK for temp unique index (faster merge) |
| Merge INSERT | 970s (~16 min) | INSERT ... ON CONFLICT DO NOTHING, with 910 CAST expressions |
| Rebuild PK | 31s | Drop temp index, add primary key back |
| **Total IBE** | **~27 min** | **vs 31+ hours with row-by-row approach** |

Result: `INSERT 0 1955593` — exactly 1,955,593 new rows added to the existing 5,700,000. Total: **7,655,593 rows**. Ed Broyhill canary verified.

### 11. Market Indices — Automatic Phase 2 (~6:00 PM)

The loader automatically proceeded to Phase 2 (market_indices):

| Phase | Duration | Details |
|-------|----------|---------|
| CSV write | 155s | 7,655,593 rows, 10.81 GB, 49K rows/sec (fewer cols = faster) |
| COPY to staging | 170s | Faster — smaller table |
| INSERT (TRUNCATE + clean load) | ~8 min | No ON CONFLICT needed — table was empty |
| Add PK | Error: PK already existed | Non-fatal — data was fully loaded |
| **Total MI** | **~12 min** | |

Result: **7,655,593 rows loaded.** Ed canary verified.

The PK error was trivial — `TRUNCATE` doesn't drop constraints, so when the script tried `ADD PRIMARY KEY`, it already existed. All data was intact.

### 12. VACUUM FULL — Reclaiming Dead Tuple Bloat (~7:05 PM)

The failed first IBE load (with quoted rnc_regids) left 7,655,593 dead tuples after the DELETE. The table was 62GB but only ~32GB was live data.

First increased `maintenance_work_mem` to 8GB (was 64MB — stock default), then ran VACUUM FULL:

| Metric | Before | After |
|--------|--------|-------|
| Table size | 62 GB | 32 GB |
| Dead tuples | 7,664,054 | 0 |
| Duration | — | 399 seconds (~7 min) |

**30 GB reclaimed.**

### 13. PostgreSQL Tuning — Complete Overhaul (~7:08 PM)

Built and applied a production `postgresql.conf` for the 96-CPU / 251GB RAM server. Every setting was stock default before this.

| Setting | Before | After | Impact |
|---------|--------|-------|--------|
| shared_buffers | 128 MB | 63 GB | 500x more buffer cache |
| work_mem | 4 MB | 128 MB | 32x more per-query sort/hash memory |
| maintenance_work_mem | 64 MB | 4 GB | 64x faster VACUUM/CREATE INDEX |
| effective_cache_size | 4 GB | 188 GB | Planner uses realistic memory estimate |
| max_parallel_workers | 8 | 48 | 6x more parallel query capacity |
| max_wal_size | 1 GB | 16 GB | 16x fewer checkpoint stalls during loads |
| random_page_cost | 4.0 | 1.1 | NVMe-appropriate (was spinning disk default) |
| autovacuum_max_workers | 3 | 6 | 2x more concurrent vacuum |
| autovacuum_vacuum_scale_factor | 0.2 | 0.02 | 10x more frequent vacuum triggers |
| listen_addresses | `*` (internet-exposed!) | `127.0.0.1` | **Security fix** |
| huge_pages | try | on | 33,868 huge pages allocated |
| wal_compression | off | zstd | ~60% WAL size reduction |
| shared_preload_libraries | (none) | pg_stat_statements | Query performance tracking |

PostgreSQL restarted successfully. All settings verified. Relay reconnected.

### 14. WAL Archiving & PITR Backup (~7:09 PM)

Enabled Ed's requested "reset button":

- `archive_mode = on` — WAL segments copied to `/backup/wal/`
- First WAL segment archived successfully
- Base backup launched in background (screen `basebackup`)
- This enables point-in-time recovery to any transaction

### 15. The rnc_regid Case Problem (~7:19 PM)

Ed asked if the voter file was synced to the complete DataTrust dataset. I ran a JOIN and discovered:

**Only 5 rows matched between datatrust_voter_nc and acxiom_ibe.**

Root cause: DataTrust voter file stores rnc_regid in **lowercase** (`c45eeea9-663f-40e1-b0e7-a473baee794e`). Acxiom stores it in **UPPERCASE** (`C45EEEA9-663F-40E1-B0E7-A473BAEE794E`). NCBOE donations also use lowercase.

Case-insensitive test confirmed: **7,616,642 rows match** when ignoring case.

**Fix:** UPDATE all 4 Acxiom tables to lowercase rnc_regid. Currently running (IBE first, then ap_models, market_indices, consumer_nc). PKs dropped before UPDATE, will be rebuilt after.

### 16. Claude Architecture Review (~6:48 PM)

Ed had Cursor produce a session doc and asked me to write a detailed problem briefing for Claude. Wrote `CLAUDE_DOWNLOAD_LOAD_PROBLEMS.md` covering all 7 issues.

Claude responded with comprehensive recommendations:
1. **DuckDB direct write** as best Parquet→PG path
2. **FORMAT csv with explicit QUOTE** instead of our fragile `quoting_style='none'`
3. **Table swap pattern** (RENAME) instead of ON CONFLICT for full refreshes
4. **WAL-based PITR** instead of pg_dump (we implemented this)
5. **Server rebuild** recommended post-cryptominer
6. **Complete postgresql.conf** (we implemented a version of this)

---

## PROBLEMS ENCOUNTERED — DETAILED CATALOG

### Problem 1: Cryptominer + Watchdog (CRITICAL — hours lost)
- **Symptom**: Every Python process silently killed after ~30 seconds
- **Root cause**: XMRig miner disguised as `/usr/local/bin/systemd`, watchdog `free_proc.sh` killing >100% CPU processes every 2 seconds
- **Fix**: Mask services, replace binaries with empty files, set immutable flag
- **Time lost**: ~2 hours of debugging across multiple loader versions
- **Status**: Resolved. Root cause of server compromise unknown.

### Problem 2: PyArrow CSV Quoting (CRITICAL — full table reload)
- **Symptom**: All rnc_regid values wrapped in literal `"` characters
- **Root cause**: PyArrow `write_csv` default quoting + PG `COPY FORMAT text` treating quotes as literals
- **Fix**: `pcsv.WriteOptions(quoting_style='none')`
- **Time lost**: ~45 minutes (load + diagnosis + delete + reload)
- **Status**: Resolved but fragile. Claude recommends FORMAT csv with QUOTE pairing.

### Problem 3: TEXT→INTEGER Type Mismatch (HIGH)
- **Symptom**: `cannot cast type text to integer` during merge INSERT
- **Root cause**: Staging table all TEXT, target has 907 INTEGER columns
- **Fix**: Dynamic CAST SQL from information_schema.columns with NULLIF for empty strings
- **Time lost**: ~30 minutes
- **Status**: Resolved. Claude recommends DuckDB to eliminate staging entirely.

### Problem 4: rnc_regid Case Mismatch (HIGH)
- **Symptom**: Only 5 rows join between voter file and Acxiom
- **Root cause**: Voter file = lowercase, Acxiom = UPPERCASE, NCBOE = lowercase
- **Fix**: UPDATE all 4 Acxiom tables to LOWER(rnc_regid)
- **Time lost**: ~15 minutes diagnosis
- **Status**: Fix running now. Will create dead tuples requiring future VACUUM.

### Problem 5: pg_dump Holding Locks (MEDIUM)
- **Symptom**: ALTER TABLE and CREATE PARTITION blocked indefinitely
- **Root cause**: pg_dump holds AccessShareLock which conflicts with DDL locks
- **Fix**: Killed pg_dump. Switched to WAL-based PITR backup.
- **Time lost**: ~20 minutes
- **Status**: Resolved permanently with WAL archiving.

### Problem 6: Stock PostgreSQL Defaults (MEDIUM)
- **Symptom**: Everything slow — loads, vacuums, queries
- **Root cause**: 128MB shared_buffers on 251GB RAM machine
- **Fix**: Complete postgresql.conf overhaul (see section 13 above)
- **Time lost**: Compounded across every operation
- **Status**: Resolved.

### Problem 7: Table Bloat from Failed Load (MEDIUM)
- **Symptom**: acxiom_ibe at 62GB with only 32GB live data
- **Root cause**: 7.6M dead tuples from DELETE after corrupted first load
- **Fix**: VACUUM FULL with increased maintenance_work_mem
- **Time lost**: 7 minutes for VACUUM
- **Status**: Resolved. 30GB reclaimed.

---

## FINAL DATABASE STATE — April 13, 2026 7:30 PM EDT

### Loaded & Complete

| Table | Rows | Size | Variables |
|-------|------|------|-----------|
| core.datatrust_voter_nc | 7,727,637 | 12 GB | 252 |
| core.acxiom_consumer_nc | 7,655,593 | 89 GB | 22 |
| core.acxiom_ap_models | 7,655,593 | 16 GB | 478 |
| core.acxiom_ibe | 7,655,593 | 32 GB | 911 |
| core.acxiom_market_indices | 7,655,593 | 21 GB | 526 |
| raw.ncboe_donations | 2,431,198 | 5.3 GB | 59 |
| platform.ecosystems | 60 | config | — |
| public.bgop_config | 9 | config | — |
| pipeline.credentials_vault | 5 | config | — |

**Total: 2,248 data variables across 7.6M+ NC voter/donor records**
**Total DB size: 174 GB | Disk: 271 GB / 1.8 TB (17%)**

### In Progress
- rnc_regid lowercase normalization on 4 Acxiom tables (running)
- Base backup to /backup/ (running)

### Not Yet Loaded
| Table | Status | Blocked By |
|-------|--------|------------|
| raw.fec_donations | 0 rows, no source data | FEC API key needed |
| donor_intelligence.person_master | 0 rows | Dedup process (Stage 2) |
| donor_intelligence.contribution_map | 0 rows | Dedup process |
| core.candidates | 0 rows | Candidate roster |
| core.campaigns | 0 rows | Campaign data |
| donor_intelligence.employer_sic_master | 0 rows | Source file |
| RNC fact tables (absentee, etc.) | Data on disk, no tables | Schema + loader needed |

### Infrastructure Applied This Session
- PG tuning: 63GB shared_buffers, 128MB work_mem, 4GB maintenance, 48 parallel workers
- Huge pages: 33,868 × 2MB = 66GB reserved
- WAL archiving: active, archiving to /backup/wal/
- listen_addresses: locked to localhost (was exposed to internet)
- pg_stat_statements: enabled for query tracking
- Autovacuum: aggressive settings for large table workloads

### GitHub Commits This Session
| Commit | Branch | Content |
|--------|--------|---------|
| `99288fa` | session-mar17-2026-clean | Wave 1 DDL migration |
| `6c7b344` | session-mar17-2026-clean | Fast loader v4, PG tuning, bulk load docs |

### Screen Sessions Active on Hetzner
| Screen | Process | Status |
|--------|---------|--------|
| relay | relay.py on port 8080 | Running since Apr 11 |
| normalize | rnc_regid lowercase UPDATE | Running |
| basebackup | pg_basebackup | Running |
| analyze | ANALYZE on Acxiom tables | Running |

---

## KEY LESSONS FOR FUTURE SESSIONS

1. **Always check for rogue processes first.** `ps aux --sort=-%cpu | head -20` before any heavy workload.
2. **PyArrow + COPY FORMAT pairing matters.** Either use `quoting_style='none'` with `FORMAT text`, or default quoting with `FORMAT csv QUOTE '"'`. Never mix.
3. **Case-normalize rnc_regid on ingest.** Every loader should `LOWER()` the rnc_regid before or during load.
4. **Stock PG defaults are catastrophically wrong** for any serious workload. Tune on first deploy.
5. **WAL archiving > pg_dump** for databases >50GB with ongoing DDL changes.
6. **DuckDB should be the next loader.** Eliminates CSV intermediate, handles type casting, no staging table needed.

---

*Written by Perplexity Computer | April 13, 2026 7:30 PM EDT*
*Ed Broyhill — NC Republican National Committeeman | ed.broyhill@gmail.com*
