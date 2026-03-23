# BroyhillGOP Session Transcripts

This folder contains summaries of key Claude working sessions on the BroyhillGOP platform. Each file documents what was done, what the state was at the end, and what needs to happen next.

## ⚠️ CRITICAL FACTS FOR ANY NEW SESSION

Before doing anything — run these checks:

```sql
SELECT COUNT(*) FROM nc_voters;         -- Should be ~9.1M (already loaded)
SELECT COUNT(*) FROM nc_datatrust;      -- Should be ~7.6M
SELECT COUNT(*) FROM nc_boe_donations_raw WHERE rncid IS NULL; -- Should be ~287K
SELECT COUNT(*) FROM rnc_voter_staging; -- Should be 7,708,542
```

**DO NOT re-download or re-ingest the voter file.** It has 9,161,218 rows already in Supabase.

---

## Sessions (Most Recent First)

| File | Date | Status | Topic |
|------|------|--------|-------|
| [2026-03-23_Hetzner-Docker-Claude-API.md](./2026-03-23_Hetzner-Docker-Claude-API.md) | Mar 23 | ✅ Done | Hetzner Docker, Claude API live, E20 Brain deployed |
| [2026-03-22_RNC-donor-id-BOE-update.md](./2026-03-22_RNC-donor-id-BOE-update.md) | Mar 22 | ⚠️ Half done | RNC voter file downloaded, 338,720 BOE rows matched (54.1%), 287K still need fuzzy match |
| [2026-03-21_DataTrust-Acxiom-Supabase-setup.md](./2026-03-21_DataTrust-Acxiom-Supabase-setup.md) | Mar 21 | ✅ Done | DataTrust/Acxiom loaded, infrastructure reference |
| [2026-03-20_NEXUS-donor-search-confession.md](./2026-03-20_NEXUS-donor-search-confession.md) | Mar 20 | ⚠️ Important | AI fabrication caught, lessons learned, norm tables state |

---

## Top Priority Right Now

1. **Resume BOE fuzzy match** — 287K unmatched rows in `nc_boe_donations_raw`
2. **Fix voter_ncid column type** — change from bigint to VARCHAR
3. **Populate brain_decisions table** — schema needed in Supabase
4. **FEC ingestion** — fec_schedule_a_raw = 0 rows
