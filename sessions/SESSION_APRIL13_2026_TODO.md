# BroyhillGOP — Master TODO & Status
## Updated: April 13, 2026 7:30 PM EDT
## Author: Perplexity Computer for Ed Broyhill

---

## SESSION SUMMARY — April 13, 2026 (Evening Session)

### COMPLETED THIS SESSION

1. **Acxiom IBE Load — DONE** ✓
   - Built `fast_acxiom_loader_v4.py` (4 iterations, multiple bug fixes)
   - 7,655,593 rows loaded, 909 columns, 32 GB after VACUUM
   - Ed Broyhill canary verified (rnc_regid `C45EEEA9-663F-40E1-B0E7-A473BAEE794E`)

2. **Acxiom Market Indices Load — DONE** ✓
   - 7,655,593 rows, 524 columns, 21 GB
   - Loaded automatically as Phase 2 of fast loader

3. **Cryptominer Discovery & Removal — DONE** ✓
   - XMRig at `/usr/local/bin/systemd` using all 96 CPUs
   - Watchdog `free_proc.sh` killing any process >100% CPU every 2 seconds
   - Root cause of ALL loader failures across multiple sessions
   - Neutralized: services masked, binaries immutable

4. **VACUUM FULL on acxiom_ibe — DONE** ✓
   - 62 GB → 32 GB (30 GB reclaimed from 7.6M dead tuples)
   - 7 minutes with 8GB maintenance_work_mem

5. **PostgreSQL Tuning — DONE** ✓
   - Full production config: 63GB shared_buffers, 128MB work_mem, 4GB maintenance_work_mem
   - Huge pages (33,868), NVMe settings, aggressive autovacuum
   - `listen_addresses` locked to localhost (was `*` — exposed to internet!)
   - pg_stat_statements enabled
   - Committed to GitHub: `scripts/tuning/postgresql_broyhillgop.conf`

6. **WAL Archiving & PITR — DONE** ✓
   - archive_mode on, archiving to `/backup/wal/`
   - Ed's "reset button" — point-in-time recovery now possible
   - Base backup running

7. **Wave 1 DDL Deployment — DONE** ✓
   - 4 new tables, 3 column additions, 2 partitions
   - Committed: `99288fa`

8. **GitHub Commits — DONE** ✓
   - `99288fa` — Wave 1 DDL
   - `6c7b344` — Fast loader, PG tuning, bulk load docs

### STILL RUNNING (will complete on their own)

| Process | Screen | ETA |
|---------|--------|-----|
| rnc_regid lowercase normalization (4 Acxiom tables) | `normalize` | ~30 min |
| Base backup (174 GB) | `basebackup` | ~30 min |
| ANALYZE on Acxiom tables | `analyze` | ~10 min |

---

## WHAT WAS ALREADY COMPLETE (prior sessions)

1. **Acxiom AP Models** — 7,655,593 rows, 478 cols, 16 GB ✓
2. **Acxiom Consumer NC** — 7,655,593 rows, 22 cols, 89 GB ✓
3. **DataTrust Voter File** — 7,727,637 rows, 252 cols, 12 GB ✓
4. **NCBOE Donations** — 2,431,198 rows, deduped into 758,110 clusters ✓
5. **NCBOE Internal Dedup** — 7 stages, 1,673,088 merges, `ncboe_dedup_v2.py` ✓
6. **Dark Donor Rescue** — 193,868 donors recovered via cluster propagation ✓
7. **Household Linkage** — 58,442 households, Ed+Melanie linked at $1.39M ✓
8. **Platform Ecosystems** — 60 ecosystems configured ✓

---

## CURRENT DATABASE STATE — April 13, 2026 7:30 PM

### Data Tables

| Table | Rows | Size | Cols | Status |
|-------|------|------|------|--------|
| core.datatrust_voter_nc | 7,727,637 | 12 GB | 252 | ✓ Complete |
| core.acxiom_consumer_nc | 7,655,593 | 89 GB | 22 | ✓ Complete |
| core.acxiom_ap_models | 7,655,593 | 16 GB | 478 | ✓ Complete |
| core.acxiom_ibe | 7,655,593 | 32 GB | 911 | ✓ Complete — normalizing rnc_regid |
| core.acxiom_market_indices | 7,655,593 | 21 GB | 526 | ✓ Complete — normalizing rnc_regid |
| raw.ncboe_donations | 2,431,198 | 5.3 GB | 59 | ✓ Complete — deduped |
| platform.ecosystems | 60 | config | — | ✓ Config |
| public.bgop_config | 9 | config | — | ✓ Config |
| pipeline.credentials_vault | 5 | config | — | ✓ Config |

**Total: 2,248 data variables | 174 GB database | 7.6M+ voter/donor records**

### Empty Tables — Need Data

| Table | Rows | What's Needed |
|-------|------|---------------|
| raw.fec_donations | 0 | FEC API key (DEMO_KEY rate limited) |
| donor_intelligence.person_master | 0 | Stage 2 dedup process |
| donor_intelligence.contribution_map | 0 | Stage 2 dedup process |
| donor_intelligence.employer_sic_master | 0 | Source file location |
| core.candidates | 0 | Candidate roster data |
| core.campaigns | 0 | Campaign data |

### RNC Data on Disk (not yet loaded into tables)

| File | Size | Notes |
|------|------|-------|
| /data/rnc/absentee.jsonl | 22 GB | Needs schema + loader |
| /data/rnc/dim_election.jsonl | 28 KB | Small dimension table |
| /data/rnc/dim_organization.jsonl | 25 KB | Small dimension table |
| /data/rnc/dim_tag.jsonl | 252 KB | Tag taxonomy |

---

## NEXT STEPS — PRIORITY ORDER

### Phase 1: Immediate (Can start next session)

| # | Task | Blocked By | Estimate | Notes |
|---|------|------------|----------|-------|
| 1 | **Verify rnc_regid normalization completes** | Running now | Auto | Check all 4 tables lowercase, PKs rebuilt, joins work |
| 2 | **VACUUM after normalization** | Step 1 | ~30 min | UPDATEs create dead tuples on all 4 Acxiom tables |
| 3 | **Drop old acxiom_consumer_nc?** | Ed decision | Instant | 89 GB — only 22 cols, all available in other tables. Confirm with Ed. |
| 4 | **Merge session branch to main** | None | 5 min | `session-mar17-2026-clean` has all work; `main` is behind |
| 5 | **Load employer_sic_master** | Need source file | 30 min | 62,100 SIC→employer mappings — table exists, 0 rows |

### Phase 2: Stage 2 — Voter File Matching (HIGHEST VALUE)

| # | Task | Blocked By | Estimate | Notes |
|---|------|------------|----------|-------|
| 6 | **Build Stage 2 matching script** | rnc_regid normalized | 2-4 hrs | Match 758,110 NCBOE clusters → datatrust_voter_nc (7.7M voters) |
| | Pass 1: DOB + Sex + Last + Zip | | | Top-priority match |
| | Pass 2: Address number + Last + Zip | | | Any addr_num from cluster vs reg_house_num |
| | Pass 3: Employer + Last + City | | | Catches 75% major donors |
| | Pass 4: FEC cross-reference | FEC data | | Two govt sources agreeing |
| | Pass 5: Committee loyalty fingerprint | | | 3+ same committees |
| | Pass 6: Name variants + Last + City | | | All first names from cluster |
| | Pass 7: Geocode proximity | | | reg_latitude/reg_longitude, 100m radius |
| | Pass 8: Household matching | | | If one member matched, check others |
| **Target:** resolve remaining 46.8% dark donors (1,138,129 rows) |

### Phase 3: Enrichment & Views

| # | Task | Blocked By | Estimate | Notes |
|---|------|------------|----------|-------|
| 7 | **Build person_master** | Stage 2 | 1-2 hrs | Unified donor/voter profile from dedup results |
| 8 | **Donor enrichment view** | person_master | 1 hr | JOIN donations→voter→all 4 Acxiom tables via rnc_regid |
| 9 | **Microsegmentation tagging** | employer_sic_master | 1 hr | SIC/NAICS employer segments |
| 10 | **Refresh materialized views** | Enrichment view | 30 min | mv_donation_summary, mv_donor_profile |

### Phase 4: RNC & FEC Data

| # | Task | Blocked By | Estimate | Notes |
|---|------|------------|----------|-------|
| 11 | **Load RNC absentee data** | Schema design | 2 hrs | 22 GB JSONL on disk |
| 12 | **Load RNC dimension tables** | Schema design | 30 min | Small files |
| 13 | **FEC API registration** | API key | 1 hr | Upgrade from DEMO_KEY |
| 14 | **FEC donation download** | API key | 2 hrs | NC donors to major PACs |

### Phase 5: Security (URGENT — schedule this week)

| # | Task | Blocked By | Estimate | Notes |
|---|------|------------|----------|-------|
| 15 | **Post-compromise audit** | None | 2 hrs | Check for other backdoors, SSH keys, cron jobs |
| 16 | **Firewall (ufw)** | None | 30 min | Default deny, allow only known IPs |
| 17 | **SSH hardening** | None | 30 min | Key-only auth, disable root login, non-standard port |
| 18 | **Rotate ALL credentials** | None | 30 min | Root password, PG password, Supabase keys |
| 19 | **Consider full server rebuild** | Ed decision | 1 day | Unknown entry vector + 9M voter PII = compliance risk |

### Phase 6: Frontend

| # | Task | Blocked By | Estimate | Notes |
|---|------|------------|----------|-------|
| 20 | **Donor profile pages** | Enrichment view | TBD | Individual view with cluster data |
| 21 | **Household view** | Linkage (done) | TBD | Combined family giving |
| 22 | **Search/filter UI** | Profile pages | TBD | By employer, committee, district, amount |

---

## PARKED — NOT YET STARTED

- [ ] Danny Peletski: IBE data dictionary for 242 undefined codes (DPeletski@gop.com)
- [ ] Supabase nc_boe_donations_raw recovery (contaminated ~2.27M rows)
- [ ] NC donors to Club for Growth / NRA / AFP (blocked on FEC key)
- [ ] ms_* microsegment table population (blocked on PAC research)
- [ ] WinRed phone/email backfill for 94K contacts
- [ ] Universe consolidation: 60 ecosystems → 5-7 universes (architecture revision)
- [ ] Brain worker scaling plan (single Python process → worker pool)
- [ ] Redis pub/sub → reliable event bus (Redis Streams or PG outbox pattern)
- [ ] Connection pooling (pgbouncer)
- [ ] DuckDB-based loader for next Acxiom refresh

---

## KEY FILES

| File | Location | Purpose |
|------|----------|---------|
| ncboe_dedup_v2.py | /opt/broyhillgop/ + GitHub | **PRODUCTION** dedup — DO NOT MODIFY |
| fast_acxiom_loader_v4.py | /data/acxiom/ + GitHub `scripts/loaders/` | Acxiom bulk loader |
| postgresql_broyhillgop.conf | /etc/postgresql/16/main/ + GitHub `scripts/tuning/` | Production PG config |
| apply_pg_tuning.sh | GitHub `scripts/tuning/` | One-shot config apply script |
| DONOR_DEDUP_PIPELINE_V2.md | /opt/broyhillgop/sessions/ + GitHub | Canonical dedup plan — the Bible |
| CURSOR_BRIEFING_NCBOE_DEDUP_GROUNDWORK.md | /opt/broyhillgop/sessions/ + GitHub | Cursor briefing (759 lines) |
| BULK_LOAD_PROBLEMS_AND_SOLUTIONS.md | GitHub `docs/` | 7 problems + solutions catalog |
| wave1_migration.sql | GitHub `migrations/` | Wave 1 DDL |
| nuke_miner.sh | /opt/broyhillgop/ | Cryptominer removal script |

---

## TECHNICAL REFERENCE

| Item | Value |
|------|-------|
| Hetzner server | 37.27.169.232 |
| Root password | ${PG_PASSWORD_RETIRED_20260417} (**ROTATE — appeared in logs**) |
| PostgreSQL | postgresql://postgres:${PG_PASSWORD_URLENCODED}@127.0.0.1:5432/postgres |
| PG password | ${PG_PASSWORD} (**ROTATE — appeared in logs**) |
| Supabase project | isbgjpnbocdkeslofota |
| GitHub repo | broyhill/BroyhillGOP |
| GitHub branch | session-mar17-2026-clean (tip: `6c7b344`) |
| Relay | 37.27.169.232:8080, key: bgop-relay-k9x2mP8vQnJwT4rL |
| Danny Peletski | DPeletski@gop.com |
| Zack Imel | ZImel@gop.com, 270-799-0923 |
| Ed canary rnc_regid | c45eeea9-663f-40e1-b0e7-a473baee794e (lowercase after normalization) |
| Ed cluster | 372171 | Melanie cluster | 372197 | Household | 636697 |

### PG Config Applied (key values)
| Setting | Value |
|---------|-------|
| shared_buffers | 63 GB |
| work_mem | 128 MB |
| maintenance_work_mem | 4 GB |
| effective_cache_size | 188 GB |
| max_parallel_workers | 48 |
| max_wal_size | 16 GB |
| archive_mode | on |
| huge_pages | on (33,868 pages) |

---

*Written by Perplexity Computer | April 13, 2026 7:30 PM EDT*
*Ed Broyhill — NC Republican National Committeeman | ed.broyhill@gmail.com*
*Do not modify the dedup plan or script without Ed's authorization.*
