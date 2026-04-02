# CURSOR — Audit + Confirm Before Rollup
**Time:** 2026-04-01 23:16 EDT  
**From:** Perplexity Computer  
**Action:** Read this fully. Run the audit queries. Report numbers. Do not execute rollup until you confirm.

---

## Tonight's work (what Perplexity ran)

| Step | What happened | Status |
|------|--------------|--------|
| partisan_flag | All 338,213 rows set to R | ✅ |
| SBOE committee master | 13,237 committees scraped from cf.ncsbe.gov → `staging.sboe_committee_master` | ✅ |
| committee_registry backfill | candidate_name filled: 1,202 → 1,690 rows | ✅ |
| boe_donation_candidate_map | candidate_name updated via committee_sboe_id → committee_registry join | ✅ |
| Reported match rate | 99.7% (337,108 / 338,213) | ⚠️ needs your confirmation |

---

## What you need to audit

### 1. Confirm the 99.7% is real, not a phantom

The `sboe_registry` UPDATE filled `candidate_name` from `committee_registry.candidate_name` joined on `committee_sboe_id = sboe_id`. Verify the names are actual candidates, not junk:

```sql
-- Sample what sboe_registry method produced
SELECT candidate_name, committee_name, COUNT(*) as n
FROM staging.boe_donation_candidate_map
WHERE match_method = 'sboe_registry'
GROUP BY candidate_name, committee_name
ORDER BY n DESC
LIMIT 20;

-- Match rate breakdown by method
SELECT 
  match_method,
  COUNT(*) as rows,
  ROUND(COUNT(*)::numeric/338213*100,1) as pct
FROM staging.boe_donation_candidate_map
GROUP BY match_method ORDER BY rows DESC;

-- Overall match rate
SELECT 
  COUNT(*) as total,
  COUNT(candidate_name) as matched,
  ROUND(COUNT(candidate_name)::numeric/COUNT(*)*100,1) as match_pct
FROM staging.boe_donation_candidate_map;
```

Expected: sboe_registry rows contain real NC candidate names (Phil Berger, Dan Bishop, etc.). If you see party org names or NULL garbage → flag before rollup.

### 2. Confirm the 793 registry gap is not a blocker

The 793 `committee_registry` rows that have `sboe_id` but no `candidate_name` are COUNTY_REC party committees — they legitimately have no single candidate owner. Donations to them are party donations, not candidate donations. Confirm:

```sql
-- Breakdown of the 793 by committee_type
SELECT committee_type, COUNT(*) as n
FROM committee_registry
WHERE sboe_id IS NOT NULL
  AND (candidate_name IS NULL OR candidate_name = '')
GROUP BY committee_type ORDER BY n DESC;

-- How many unmatched donation rows go to these 793 committees?
SELECT COUNT(*) as affected_donation_rows
FROM staging.boe_donation_candidate_map m
JOIN committee_registry cr ON m.committee_sboe_id = cr.sboe_id
WHERE m.candidate_name IS NULL
  AND (cr.candidate_name IS NULL OR cr.candidate_name = '');
```

Expected: 793 are mostly COUNTY_REC/PARTY types. Affected donation rows should be small (< 500). If > 10K rows are affected → that changes the rollup calculus, flag it.

### 3. Confirm staging table is clean for rollup

```sql
-- Full pre-flight
SELECT 
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE partisan_flag = 'R') as r_flag,
  COUNT(*) FILTER (WHERE partisan_flag != 'R' OR partisan_flag IS NULL) as not_r,
  COUNT(candidate_name) as has_candidate,
  COUNT(*) FILTER (WHERE amount_numeric <= 0 OR amount_numeric IS NULL) as bad_amount,
  COUNT(*) FILTER (WHERE date_occurred IS NULL) as null_date,
  COUNT(*) FILTER (WHERE committee_sboe_id IS NULL) as null_committee
FROM staging.boe_donation_candidate_map;
```

Expected: total=338,213, r_flag=338,213, not_r=0, bad_amount=0 or very small.

### 4. Confirm the join path for rollup is valid

The rollup inserts from `nc_boe_donations_raw → person_spine` (name+zip). Check the join preview:

```sql
-- How many rows will actually INSERT?
SELECT COUNT(*) as will_insert
FROM public.nc_boe_donations_raw r
JOIN core.person_spine sp
  ON sp.norm_last  = r.norm_last
  AND sp.norm_first = r.norm_first
  AND sp.zip5      = LEFT(r.norm_zip5, 5)
  AND sp.is_active = true
WHERE r.amount_numeric > 0
  AND r.norm_last IS NOT NULL AND r.norm_last != ''
  AND r.norm_first IS NOT NULL AND r.norm_first != ''
  AND r.norm_zip5 IS NOT NULL AND r.norm_zip5 != '';

-- Current stale NC_BOE count
SELECT COUNT(*) as current_nc_boe FROM core.contribution_map WHERE source_system = 'NC_BOE';

-- Ed Broyhill canary before rollup
SELECT person_id, COUNT(*) as tx, SUM(amount) as total
FROM core.contribution_map WHERE person_id = 26451 GROUP BY person_id;
```

Expected: will_insert > 108,943 (the current stale count). If will_insert = 0 → STOP, do not rollup.

---

## If all checks pass — rollup SQL

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
  AND r.norm_last  IS NOT NULL AND r.norm_last  != ''
  AND r.norm_first IS NOT NULL AND r.norm_first != ''
  AND r.norm_zip5  IS NOT NULL AND r.norm_zip5  != ''
ON CONFLICT (source_system, source_id) DO NOTHING;

-- Count before commit
SELECT COUNT(*) as inserted FROM core.contribution_map WHERE source_system = 'NC_BOE';

COMMIT;
-- or ROLLBACK if inserted = 0
```

After commit:
```sql
-- Person spine aggregate refresh
UPDATE core.person_spine ps
SET
  total_contributed   = agg.total,
  first_donation_date = agg.first_dt,
  last_donation_date  = agg.last_dt,
  largest_donation    = agg.max_gift
FROM (
  SELECT person_id,
    SUM(amount)           AS total,
    MIN(transaction_date) AS first_dt,
    MAX(transaction_date) AS last_dt,
    MAX(amount)           AS max_gift
  FROM core.contribution_map
  GROUP BY person_id
) agg
WHERE ps.person_id = agg.person_id AND ps.is_active = true;

-- Ed Broyhill canary after
SELECT person_id, COUNT(*) as tx, SUM(amount) as total
FROM core.contribution_map WHERE person_id = 26451 GROUP BY person_id;

SELECT person_id, total_contributed, first_donation_date, last_donation_date
FROM core.person_spine WHERE person_id = 26451;
```

---

## Hard rules
- Run all audit queries first. Report numbers back to Ed before executing rollup.
- If `will_insert = 0` → STOP. Do not rollup.
- If `not_r > 0` in staging → STOP. Do not rollup.
- `ON CONFLICT DO NOTHING` — do not overwrite FEC/WinRed/ncgop_god rows.
- Do NOT touch person_id = 26451 directly.
- Do NOT run 7-pass donor merge — that is next session after Ed signs off.
