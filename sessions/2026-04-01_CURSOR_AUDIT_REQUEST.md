# Cursor Audit Request — 2026-04-01
**Written by:** Perplexity Computer  
**Time:** 2026-04-01 ~23:10 EDT  
**Action required:** Audit + run the rollup SQL below. Do NOT run anything else.

---

## What happened tonight (Perplexity)

1. `staging.boe_donation_candidate_map` — 338,213 rows, 100% partisan_flag=R, candidate match 99.7%
2. `staging.sboe_committee_master` loaded — 13,237 NCSBE committees
3. `committee_registry.candidate_name` backfilled — 1,202 → 1,690 rows

**The staging table is clean. The source of truth for the rollup is `public.nc_boe_donations_raw` (338,213 rows), joined to `core.person_spine` on norm_last + norm_first + zip5 — exactly as you ran it on March 31.**

---

## Current DB state (verified just now)

| Table | Rows | Notes |
|-------|------|-------|
| `public.nc_boe_donations_raw` | 338,213 | Clean individual donors only, 2015–2026 |
| `core.contribution_map NC_BOE` | **108,943** | Stale — built from old 282K file, needs rebuild |
| `core.contribution_map` total | ~3.9M | fec_donations, fec_party, winred, ncgop_god also present |
| `core.person_spine` (active) | ~128K | Joined via norm_last + norm_first + zip5 |

---

## What to audit

File: `sessions/2026-04-01_rollup_to_core.sql`

**The rollup SQL I wrote has a bug — it references `staging.boe_donation_candidate_map.person_id` which does not exist.** The correct join path is `nc_boe_donations_raw → person_spine` on name+zip, which is what you ran on March 31. 

Please:

### Step 1 — Run these read-only counts first
```sql
-- 1a. Raw source
SELECT COUNT(*) FROM public.nc_boe_donations_raw;
-- Expected: 338,213

-- 1b. How many will match to spine (name+zip join preview)
SELECT COUNT(*) 
FROM public.nc_boe_donations_raw r
JOIN core.person_spine sp
  ON sp.norm_last  = r.norm_last
  AND sp.norm_first = r.norm_first
  AND sp.zip5      = LEFT(r.norm_zip5, 5)
  AND sp.is_active = true
WHERE r.amount_numeric > 0;
-- This was ~108K last time. Expect similar or higher.

-- 1c. Current stale NC_BOE rows
SELECT COUNT(*) FROM core.contribution_map WHERE source_system = 'NC_BOE';
-- Expected: 108,943

-- 1d. Ed Broyhill canary (before)
SELECT person_id, COUNT(*) as tx, SUM(amount) as total
FROM core.contribution_map WHERE person_id = 26451 GROUP BY person_id;
```

Report all four counts back before proceeding.

### Step 2 — Rewrite + run the rollup (your judgment on exact SQL)
Based on your March 31 script and the current schema, the correct rollup is:

```sql
BEGIN;

DELETE FROM core.contribution_map WHERE source_system = 'NC_BOE';

INSERT INTO core.contribution_map (
    person_id, source_system, source_id,
    amount, transaction_date, committee_id, party_flag, created_at
)
SELECT
    sp.person_id,
    'NC_BOE',
    r.id,
    r.amount_numeric,
    r.date_occurred::date,
    r.committee_sboe_id,
    'R',
    NOW()
FROM public.nc_boe_donations_raw r
JOIN core.person_spine sp
  ON sp.norm_last  = r.norm_last
  AND sp.norm_first = r.norm_first
  AND sp.zip5      = LEFT(r.norm_zip5, 5)
  AND sp.is_active = true
WHERE r.amount_numeric > 0
  AND r.norm_last IS NOT NULL AND r.norm_last != ''
  AND r.norm_first IS NOT NULL AND r.norm_first != ''
  AND r.norm_zip5 IS NOT NULL AND r.norm_zip5 != ''
ON CONFLICT (source_system, source_id) DO NOTHING;

-- Count check BEFORE commit
SELECT COUNT(*) FROM core.contribution_map WHERE source_system = 'NC_BOE';

COMMIT;
```

**If the INSERT produces 0 rows → ROLLBACK immediately and report.**

### Step 3 — Post-commit verification
```sql
-- 3a. Source breakdown
SELECT source_system, COUNT(*) as rows, ROUND(SUM(amount)) as total
FROM core.contribution_map GROUP BY source_system ORDER BY rows DESC;

-- 3b. Ed Broyhill canary (after)
SELECT person_id, COUNT(*) as tx, SUM(amount) as total
FROM core.contribution_map WHERE person_id = 26451 GROUP BY person_id;
-- Previous person_spine.total_contributed = $478,632
-- Contribution_map was $709,767 — delta was -$231,135
-- Did it move closer to $478,632?

-- 3c. Update person_spine aggregates
UPDATE core.person_spine ps
SET
  total_contributed = agg.total,
  first_donation_date = agg.first_dt,
  last_donation_date  = agg.last_dt,
  largest_donation    = agg.max_gift
FROM (
  SELECT person_id,
    SUM(amount)  AS total,
    MIN(transaction_date) AS first_dt,
    MAX(transaction_date) AS last_dt,
    MAX(amount)           AS max_gift
  FROM core.contribution_map
  GROUP BY person_id
) agg
WHERE ps.person_id = agg.person_id AND ps.is_active = true;

-- 3d. Final Ed Broyhill spine check
SELECT person_id, total_contributed, first_donation_date, last_donation_date
FROM core.person_spine WHERE person_id = 26451;
```

---

## Hard rules
- Do NOT touch `person_id = 26451` directly
- Do NOT run the 7-pass donor merge pipeline — that's next session
- Do NOT alter `staging.boe_donation_candidate_map`
- `ON CONFLICT DO NOTHING` — do not upsert, do not overwrite FEC/WinRed rows
- Report all Step 1 counts before executing Step 2

---

## Why this matters
The current 108,943 NC_BOE rows in `contribution_map` were matched from the old 282K dirty file. We now have 338,213 clean individual donor rows. The rebuild will expand spine coverage and fix the total_contributed delta on the Ed Broyhill canary.
