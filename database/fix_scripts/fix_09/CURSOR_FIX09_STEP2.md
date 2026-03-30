# Cursor Instructions — fix_09 Step 2: Load Remaining 1,781 Committees
**Project:** BroyhillGOP-Claude | Supabase ID: `isbgjpnbocdkeslofota`
**Date:** 2026-03-28
**Prepared by:** Perplexity Computer

---

## Context

core.candidate_committee_map currently has 1,952 rows (loaded by Claude Anthropic).
Coverage: 1,950 / 3,732 committees in fec_donations (52%).
Perplexity resolved the remaining 1,781 unlinked committees from FEC bulk files
(2018–2026 cycles). 1 committee ID was not found in any FEC file — genuinely invalid.

---

## Your Task

Execute 4 SQL chunks in order. Each is an INSERT with ON CONFLICT DO NOTHING.
Run validation after all 4. Report results back to Ed.

---

## Step 1 — Pre-flight check

```sql
SELECT COUNT(*) AS current_rows FROM core.candidate_committee_map;
-- Expected: 1,952
```

---

## Step 2 — Execute chunks in order

Run each file via apply_migration or execute_sql, one at a time:

1. `fix09_chunk_01.sql` — 500 rows
2. `fix09_chunk_02.sql` — 500 rows
3. `fix09_chunk_03.sql` — 500 rows
4. `fix09_chunk_04.sql` — 281 rows

All use `ON CONFLICT DO NOTHING` — fully safe to re-run.

---

## Step 3 — Validation

```sql
-- Total rows
SELECT COUNT(*) AS total FROM core.candidate_committee_map;
-- Expected: ~3,700 (1,952 existing + up to 1,781 new)

-- Coverage against fec_donations
SELECT
  COUNT(DISTINCT fd.committee_id) AS total_in_donations,
  COUNT(DISTINCT ccm.committee_id) AS now_linked,
  COUNT(DISTINCT CASE WHEN ccm.committee_id IS NULL
    THEN fd.committee_id END) AS still_unlinked
FROM fec_donations fd
LEFT JOIN core.candidate_committee_map ccm
  ON fd.committee_id = ccm.committee_id;
-- Expected: still_unlinked = 1 (one genuinely invalid FEC ID)

-- Source breakdown
SELECT committee_source, COUNT(*) FROM core.candidate_committee_map
GROUP BY committee_source ORDER BY COUNT(*) DESC;
```

---

## Rules

- Do NOT touch nc_voters, nc_datatrust, rnc_voter_staging, person_source_links
- Do NOT truncate or modify the existing 1,952 rows
- ON CONFLICT DO NOTHING handles any duplicates — safe to re-run
- Paste full validation output back to Ed when done
