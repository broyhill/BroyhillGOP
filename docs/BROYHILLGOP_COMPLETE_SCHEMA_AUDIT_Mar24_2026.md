# BroyhillGOP — Complete Database Schema Audit
**Date:** March 24, 2026  
**Prepared by:** Claude (verified via direct psql connection)  
**Connection:** `db.isbgjpnbocdkeslofota.supabase.co:5432`  
**Total size:** ~60 GB across 20 schemas, ~1,200 tables

---

## ⚠️ MANDATORY READING FOR ALL FUTURE SESSIONS

### The Single Most Important Rule
**The Supabase REST API only exposes the `public` schema.**  
All previous sessions that said "donor_master is GONE" or "donor_golden_records is GONE" were wrong.  
Those tables are alive in the `archive` schema with 393,334 rows each.  
**Always connect via psql for schema work. Never trust REST-only audits.**

### psql Connection
```
PGPASSWORD="Anamaria@2026@" psql -h db.isbgjpnbocdkeslofota.supabase.co -U postgres -d postgres
```

### First Command Every Session
```sql
-- List all schemas and their sizes
SELECT table_schema, COUNT(*) as tables,
    pg_size_pretty(SUM(pg_total_relation_size(quote_ident(table_schema)||'.'||quote_ident(table_name)))) as size
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema','extensions','pgbouncer','realtime','supabase_functions','storage','auth')
  AND table_type = 'BASE TABLE'
GROUP BY table_schema
ORDER BY SUM(pg_total_relation_size(quote_ident(table_schema)||'.'||quote_ident(table_name))) DESC;
```

---

## Database Architecture — 6-Layer ETL Stack

```
raw.*        →  Raw ingestion (FEC, BOE files as loaded)
    ↓
norm.*       →  Normalized/cleaned layer
    ↓
staging.*    →  Processing staging area
    ↓
core.*       →  Canonical working tables (person_spine, contribution_map)
    ↓
public.*     →  App-facing tables (REST API exposed)
    ↓
archive.*    →  Preserved "deleted" tables — NOTHING IS GONE
```

This architecture was never documented. Every session that audited only `public.*` was seeing 1 of 6 layers.

---

## Schema Inventory

### Schema Summary

| Schema | Tables | Size | Purpose |
|--------|-------:|-----:|---------|
| public | 708 | 47 GB | App-facing REST tables |
| archive | 46 | 3.5 GB | Preserved tables — nothing deleted |
| norm | 4 | 3.3 GB | Normalized ingestion layer |
| raw | 4 | 2.2 GB | Raw file ingestion |
| core | 15 | 1.7 GB | Canonical spine + money trail |
| staging | 8 | 181 MB | Processing staging area |
| donor_intelligence | 12 | 26 MB | Intelligence layer |
| brain_control | 216 | 7.6 MB | Ecosystem control tables |
| social_intelligence | 96 | 4 MB | Social data |
| pipeline | 14 | 2 MB | Pipeline tracking |
| intelligence_brain | 17 | 840 kB | Brain layer |
| state_legislature | 7 | 640 kB | NC legislature |
| demo_ecosystem | 15 | 448 kB | Demo data |
| judicial_offices | 6 | 368 kB | NC courts |
| state_offices | 6 | 304 kB | NC state offices |
| federal_offices | 9 | 296 kB | Federal offices |
| cron | 2 | 128 kB | Scheduled jobs |
| frontend | 3 | 88 kB | Frontend config |
| datahub | 1 | 32 kB | DataHub bridge |
| vault | 1 | 48 kB | Secrets |

---

## CORE Schema — The Canonical Working Layer

The real spine and money trail live here. Perplexity's Master Database Plan referenced these tables correctly.

| Table | Rows | Size | Description |
|-------|-----:|-----:|-------------|
| contribution_map | 4,006,356 | 1,082 MB | **THE money trail** — FEC + BOE + Party unified |
| person_spine | 358,144 | 415 MB | Donor identity spine (donors only, by design) |
| fec_donation_person_map | 1,612,466 | 190 MB | FEC donations linked to spine persons |
| identity_clusters | 32,156 | 16 MB | **Clustering HAS run** — 32K clusters exist |
| golden_record_person_map | 60,866 | 7.9 MB | Golden record → spine person bridge |
| ncboe_committee_type_lookup | — | 408 kB | BOE committee type reference |
| ncboe_committee_registry | — | 384 kB | BOE committee reference |
| nick_group | — | 136 kB | Nickname matching groups (Bob→Robert etc.) |
| vip_overrides | — | 48 kB | Manual identity overrides |
| candidate_committee_map | — | 48 kB | Candidate → committee mapping |
| salutation_parts | — | 48 kB | Name parsing reference |
| person_addresses | — | 32 kB | Spine address store |
| person_names | — | 32 kB | Spine name store |
| ncboe_donations_processed | — | 24 kB | BOE processing log |
| preferred_name_cache | — | 16 kB | Name cache |

**Key join paths:**
- `core.person_spine` → `public.nc_datatrust` via `voter_rncid = nc_datatrust.rnc_regid`
- `core.person_spine` → `core.contribution_map` via `person_id`
- `core.contribution_map` → `core.fec_donation_person_map` via `source_id`

---

## ARCHIVE Schema — Nothing Was Deleted

Every table that was reported as "GONE" in previous session notes is here.

| Table | Rows | Size | Notes |
|-------|-----:|-----:|-------|
| donation_transactions | 1,148,939 | 553 MB | Legacy money trail |
| donations | 1,148,835 | 410 MB | Legacy donation table |
| nc_boe_raw_donor_mapping | — | 319 MB | BOE donor mapping backup |
| **donor_master** | **393,334** | **277 MB** | **"GONE" — actually here** |
| **donor_golden_records** | **393,334** | **275 MB** | **"GONE" — actually here** |
| **nc_boe_donations_raw_backup** | **758,520** | **272 MB** | **Full BOE backup pre-edits** |
| norm_nc_boe_donations_20260309 | — | 232 MB | Normalized BOE snapshot Mar 9 |
| fec_party_quarantine | — | 204 MB | FEC party donations on hold |
| donors_backup_20260125 | — | 197 MB | Jan 25 donor backup |
| donor_universe | — | 170 MB | Legacy donor universe |
| donor_master_old_20260301 | — | 108 MB | Mar 1 donor_master backup |
| donor_master_backup_20260125 | — | 107 MB | Jan 25 donor_master backup |
| fec_2015_2016_a_staging | — | 60 MB | FEC staging hold |
| nc_data_committee_donors_20260309 | — | 60 MB | Committee donors Mar 9 |
| fec_2015_2016_b_staging | — | 58 MB | FEC staging hold |
| donorsnew_backup_20260125 | — | 43 MB | Jan 25 backup |
| donor_contribution_map_boe_backup_20260302 | — | 41 MB | BOE contribution map Mar 2 backup |
| client_subscriber_donors | — | 31 MB | Client subscribers |
| donors_master_backup_20260125 | — | 27 MB | Jan 25 backup |
| ncgop_party_committee_donations | — | 23 MB | NCGOP party committee donations |
| fec_2015_2016_a_filtered | — | 21 MB | Filtered FEC staging |
| orphan_contribution_map_backup | — | 13 MB | Orphaned rows backup |
| + 24 more tables | — | small | e55 tables, nexus backups, etc. |

**Critical note on nc_boe_donations_raw_backup:** 758,520 rows vs public.nc_boe_donations_raw 625,897 rows. The 132,623 gap represents rows removed from the live table. This backup can be used to investigate and potentially restore the 652,786 rows deleted from donor_contribution_map in the March 21 session.

---

## NORM Schema — Normalized Ingestion Layer

| Table | Rows | Size | Description |
|-------|-----:|-----:|-------------|
| fec_individual | 2,597,125 | 1,524 MB | Normalized FEC individual contributions |
| fec_party | 2,221,781 | 1,072 MB | Normalized FEC party contributions |
| nc_boe_donations | 581,741 | 708 MB | Normalized NC BOE donations |
| fec_contributions | — | 40 kB | Contribution type reference |

---

## RAW Schema — Raw File Ingestion

| Table | Rows | Size | Description |
|-------|-----:|-----:|-------------|
| fec_donations | 2,597,935 | 2,168 MB | Raw FEC as loaded from files |
| load_log | — | 32 kB | Ingestion audit trail |
| nc_boe_donations | — | 8 kB | Near-empty (raw BOE in public) |
| fec_contributions | — | 8 kB | Near-empty |

**Note:** `raw.fec_donations` (2,597,935 rows) is the authoritative FEC count. `public.fec_donations` queries time out via REST — same data, different access path.

---

## STAGING Schema

| Table | Size | Description |
|-------|-----:|-------------|
| spine_clusters | 117 MB | Clustering work in progress |
| staging_general_fund | 53 MB | General fund staging |
| spine_merge_candidates | 9.6 MB | Identity merge candidates queue |
| merge_aggregations | 1.7 MB | Merge aggregation results |
| voter_match_batch | 384 kB | Voter match batch processor |
| ncgop_winred | 24 kB | WinRed/NCGOP bridge |

---

## PUBLIC Schema — Key Tables (REST-exposed)

Full audit at BROYHILLGOP_COMPLETE_FILE_AUDIT_Mar23_2026.md. Key tables with current counts:

| Table | Rows | Notes |
|-------|-----:|-------|
| nc_voters | 9,082,810 | NC SBOE — stable |
| nc_datatrust | 7,655,593 | RNC voter intel — DO NOT TOUCH |
| rnc_voter_staging | 7,708,542 | RNC file for rncid matching |
| person_master | 7,660,662 | Public identity spine (voters) |
| rnc_voter_core | 1,106,000 | Stalled at 14.4% — needs resume |
| nc_boe_donations_raw | 625,897 | Live BOE donations |
| donor_contribution_map | 795,345 | Public money trail (incomplete) |
| fec_god_contributions | 224,887 | FEC mapped |
| fec_committees | 35,521 | Promoted from staging |
| winred_donors | 194,279 | Online donors |
| ncsbe_candidates | 55,985 | NC candidates |
| donor_candidate_scores | 142,288 | Affinity scores |
| ncgop_god_contributions | 23,026 | NCGOP |
| person_contacts | 42,179 | Emails + phones |
| rncid_resolution_queue | 150,755 | Fuzzy match queue |
| golden_record_clusters | 3 | Public clustering — use core.identity_clusters instead |
| brain_decisions | 0 | E20 brain log — brain idle |

---

## Active Work as of March 24, 2026

### Fuzzy Match Job (RUNNING on Hetzner)
- Script: `/opt/broyhillgop/fuzzy_full.py`
- Screen session: `fuzzy` on Hetzner 5.9.99.109
- Progress: ~18 batches of 163 total (~11%)
- Writing ONLY to `rncid_resolution_queue` — `nc_boe_donations_raw` NOT touched
- Expected yield: ~8,600 new resolved rncids + ~27,000 for review
- **Do not kill this job**

### Pending (Requires Eddie Approval Before Execution)
1. Block G write-back: stamp approved `resolved_rncid` → `nc_boe_donations_raw.rncid` (after fuzzy job completes and Eddie reviews)
2. Fix `voter_ncid` column type on `nc_boe_donations_raw` (bigint → VARCHAR)
3. Rebuild `donor_contribution_map` from `nc_boe_donations_raw` (restore 652K deleted rows)
4. Resume `rnc_voter_core` population (stalled at 14.4%)

---

## Known Issues

| Issue | Impact | Fix |
|-------|--------|-----|
| voter_ncid is bigint on nc_boe_donations_raw | Can't join to nc_voters.ncid | ALTER COLUMN — needs Eddie approval |
| donor_contribution_map missing 652K rows | Money trail incomplete | Rebuild from nc_boe_donations_raw |
| rnc_voter_core at 14.4% | RNC profile table incomplete | Resume batch job on Hetzner |
| person_master donor linkage = 0 | Donors not linked to voters | Run Block E/F after fuzzy job |
| psql password rotated | Was BroyhillGOP2026, now Anamaria@2026@ | Updated in Hetzner .env Mar 24 |

---

## Infrastructure

| Service | Location | Status |
|---------|----------|--------|
| Supabase | db.isbgjpnbocdkeslofota.supabase.co | ✅ Live |
| Hetzner GEX44 | 5.9.99.109 | ✅ Live |
| Docker | Hetzner /opt/broyhillgop/ | ✅ v29.3.0 |
| bgop_brain | Hetzner container | ✅ Running |
| bgop_redis | Hetzner container | ✅ Running |
| SSH key | ~/.ssh/id_ed25519_hetzner | ✅ Working |
| GitHub | github.com/broyhill/BroyhillGOP | ✅ Public |

---

*Audit executed March 24, 2026 via direct psql connection.*  
*Previous REST-only audits were blind to core, archive, norm, raw, staging schemas.*  
*This document supersedes all prior database audits.*
