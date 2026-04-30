# BroyhillGOP — Complete Schema Audit
**Date:** March 24, 2026 (updated with live counts, evening session)
**Source:** Live psql query — db.isbgjpnbocdkeslofota.supabase.co
**Authority:** Supersedes all prior audits. Previous sessions used REST API, which only exposes `public`. The database has 19 schemas. That blindness caused weeks of wasted work.

---

## THE CRITICAL DISCOVERY

Every AI session before March 24, 2026 audited this database using the Supabase REST API, which **only exposes the `public` schema**. Tables like `donor_master` and `donor_golden_records` were never deleted — they live in `archive`. Sessions spent weeks trying to "recreate" data that was never gone.

**Mandatory rule for all future sessions: Connect via psql. Never trust REST-only audits.**

```
psql -h db.isbgjpnbocdkeslofota.supabase.co -U postgres -d postgres
Password: ${PG_PASSWORD}
```

---

## ALL 19 SCHEMAS — LIVE COUNTS

| Schema | Tables | Est. Rows | Reality |
|--------|--------|-----------|---------|
| public | 708 | ~73,000,000 | SaaS app layer — what REST sees |
| archive | 46 | ~11,560,000 | Preserved data — NOT deleted |
| core | 15 | ~6,074,000 | Authoritative processed data |
| norm | 4 | ~5,434,000 | Normalized source data |
| raw | 4 | ~2,535,000 | Raw imports |
| staging | 8 | ~540,000 | Fuzzy match queues |
| donor_intelligence | 12 | ~63,000 | Partial |
| state_legislature | 7 | 1,237 | Partial |
| brain_control | 216 | 490 | Ghost — built, barely populated |
| judicial_offices | 6 | 105 | Partial |
| state_offices | 6 | 59 | Partial |
| cron | 2 | 26 | Broken — all 5 jobs reference missing objects |
| datahub | 1 | 0 | Empty |
| intelligence_brain | 17 | 0 | Empty |
| frontend | 3 | 0 | Empty |
| social_intelligence | 96 | 0 | Ghost — 96 tables, zero rows |
| demo_ecosystem | 15 | 0 | Empty |
| pipeline | 14 | 0 | Empty |
| federal_offices | 9 | 0 | Empty |

---

## KEY TABLES — EXACT LIVE COUNTS

### The Money Trail
| Table | Exact Count | Notes |
|-------|-------------|-------|
| `core.contribution_map` | **4,006,356** | Authoritative financial record |
| `public.nc_boe_donations_raw` | **625,897** | Live — 132,623 rows SHORT vs backup |
| `archive.nc_boe_donations_raw_backup` | **758,520** | Backup from before March 21 deletions |

### Donor Identity
| Table | Exact Count | Notes |
|-------|-------------|-------|
| `archive.donor_master` | **393,334** | NOT deleted — lives in archive |
| `archive.donor_golden_records` | **393,334** | NOT deleted — lives in archive |
| `archive.donor_universe` | **393,334** | Third copy, same population |
| `core.person_spine` | **358,144** | Donors-only spine |

### Fuzzy Match Queue (live)
| Status | Count |
|--------|-------|
| resolved ≥0.85 | 76,071 |
| review 0.70–0.84 | 13,304 |
| unresolved <0.70 | 26,222 |
| pending (running now) | 35,158 |
| **Total** | **150,755** |

---

## THE 6-LAYER ETL ARCHITECTURE

```
raw → norm → staging → core → public → archive
```

- **raw**: Original imports, untouched
- **norm**: Standardized names, addresses, fields
- **staging**: Fuzzy match queues, intermediate work
- **core**: Authoritative outputs — contribution_map (4M rows), person_spine (358K)
- **public**: What the app reads. What REST API sees.
- **archive**: Preserved snapshots. Nothing is truly deleted here.

---

## WHAT WENT WRONG (DOCUMENTED)

1. **March 6, 2026**: AI dropped `public.donormaster`. Gone permanently.
2. **March 21, 2026**: AI deleted 132,623 rows from `nc_boe_donations_raw`. Backup survived in archive.
3. **All prior sessions**: REST-only audits → blind to 18 schemas → declared archive tables "deleted" → wasted sessions trying to recreate intact data.
4. **5 pg_cron jobs**: All broken. Reference tables/functions that do not exist.
5. **public.donor_contribution_map**: Deleted. Authoritative copy lives at `core.contribution_map` (4M rows).

---

## PRIORITY RECOMMENDATIONS

### 1. Finish fuzzy match (running now, ~35 min remaining)
Screen session `149220.fuzzy` on Hetzner. 35,158 rows pending.
When done: ~76K donors get confirmed RNC voter IDs.

### 2. Restore nc_boe_donations_raw — Eddie must approve
```sql
INSERT INTO public.nc_boe_donations_raw
SELECT * FROM archive.nc_boe_donations_raw_backup b
WHERE NOT EXISTS (
  SELECT 1 FROM public.nc_boe_donations_raw r WHERE r.id = b.id
);
-- Restores ~132,623 missing rows
```

### 3. Fix voter_ncid column type — Eddie must approve
`nc_boe_donations_raw.voter_ncid` is `bigint`. NC voter IDs are strings. Must be VARCHAR to join `nc_voters.ncid`.
```sql
ALTER TABLE public.nc_boe_donations_raw
  ALTER COLUMN voter_ncid TYPE VARCHAR(20) USING voter_ncid::text;
```

### 4. Block G write-back — after Eddie reviews resolved rows
After fuzzy completes and Eddie approves a sample:
```sql
UPDATE public.nc_boe_donations_raw r
SET rncid = q.resolved_rncid,
    voter_ncid = q.resolved_voter_ncid
FROM public.rncid_resolution_queue q
WHERE q.status = 'resolved'
  AND q.match_confidence >= 0.85
  AND r.id = q.source_id;
```

### 5. Rebuild public.donor_contribution_map
The public-schema version was deleted. Simplest fix:
```sql
CREATE VIEW public.donor_contribution_map AS
  SELECT * FROM core.contribution_map;
```

### 6. Ghost schemas — low priority
`brain_control` (216 tables, 490 rows) and `social_intelligence` (96 tables, 0 rows) are planned-but-unbuilt features. Do not populate until identity resolution and donation data are clean.

---

## CREDENTIALS (for all sessions)

```
DB Host:   db.isbgjpnbocdkeslofota.supabase.co
Port:      5432
User:      postgres
Password:  ${PG_PASSWORD}
Database:  postgres

Hetzner:   root@5.9.99.109
SSH Key:   ~/.ssh/id_ed25519_hetzner
Web Term:  http://5.9.99.109:7681  (no password, root shell)
```

---

## THE BOTTOM LINE

The database is not as broken as prior sessions believed. The data is largely intact — hidden across schemas that REST-only audits could not see. Three real problems remain:

1. **Identity resolution incomplete** — fuzzy match 77% done, finishing now
2. **132K donation rows missing** — one INSERT from archive backup
3. **voter_ncid type mismatch** — one ALTER TABLE from working joins

Everything else is noise until these three are resolved.

*Live psql audit — March 24, 2026*
