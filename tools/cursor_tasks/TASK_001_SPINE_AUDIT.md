# TASK 001 — Spine Audit (READ-ONLY)
## Assigned by: Perplexity Computer
## Date: April 15, 2026
## Classification: WARM-UP — SELECT ONLY, NO WRITES

---

## BEFORE YOU START

You MUST read these files first (session-start.mdc requires this):
1. `/opt/broyhillgop/sessions/SESSION_START_READ_ME_FIRST.md`
2. `/opt/broyhillgop/sessions/SESSION_TRANSCRIPT_APRIL14_2026_AFTERNOON.md`
3. `/opt/broyhillgop/sessions/SESSION_TRANSCRIPT_APRIL14_2026_CONTACT_ENRICHMENT.md`

**Connection string**: `postgresql://postgres:${PG_PASSWORD_URLENCODED}@37.27.169.232:5432/postgres`

---

## YOUR ASSIGNMENT

Run every query below. Report the ACTUAL result next to the EXPECTED result. Flag any discrepancy.

**DO NOT RUN ANY INSERT, UPDATE, DELETE, TRUNCATE, ALTER, DROP, or CREATE statements.**
**This is a SELECT-only audit. If you feel the urge to "fix" something — STOP and report instead.**

---

## Section 1: Spine Row Count

```sql
SELECT COUNT(*) AS total_rows FROM raw.ncboe_donations;
```
**Expected: 2,431,198**

If this number is wrong, STOP IMMEDIATELY and tell Ed. Do not proceed.

---

## Section 2: Cluster Integrity

```sql
SELECT
  COUNT(DISTINCT cluster_id) AS distinct_clusters,
  MIN(cluster_id) AS min_cluster,
  MAX(cluster_id) AS max_cluster
FROM raw.ncboe_donations;
```
**Expected: 758,110 distinct clusters**

---

## Section 3: Ed's Canary Record (cluster 372171)

```sql
SELECT
  cluster_id,
  COUNT(*) AS txns,
  SUM(norm_amount) AS total_dollars,
  COUNT(DISTINCT source_file) AS source_files,
  MAX(cell_phone) AS cell,
  MAX(home_phone) AS home,
  MAX(personal_email) AS p_email,
  MAX(business_email) AS b_email,
  BOOL_OR(trump_rally_donor) AS rally_tagged
FROM raw.ncboe_donations
WHERE cluster_id = 372171
GROUP BY cluster_id;
```

**Expected values:**
| Field | Expected |
|---|---|
| txns | 627 |
| total_dollars | $1,318,672.04 |
| cell | EMPTY or 3369721000 |
| home | EMPTY or 3367243726 |
| p_email | NULL (must NOT be jsneeden@msn.com) |
| b_email | EMPTY or ed@broyhill.net |
| rally_tagged | EMPTY or TRUE |

⚠️ If p_email = jsneeden@msn.com — flag this as CRITICAL. That's Apollo bad data.

---

## Section 4: Voter Matching Coverage

```sql
SELECT
  COUNT(*) FILTER (WHERE rnc_regid IS NOT NULL) AS voter_matched,
  COUNT(*) FILTER (WHERE rnc_regid IS NULL) AS unmatched,
  ROUND(100.0 * COUNT(*) FILTER (WHERE rnc_regid IS NOT NULL) / COUNT(*), 1) AS match_pct
FROM raw.ncboe_donations;
```
**Expected: 1,293,069 matched (53.2%)**

---

## Section 5: Contact Column Status

```sql
SELECT
  COUNT(*) FILTER (WHERE cell_phone IS NOT NULL) AS has_cell,
  COUNT(*) FILTER (WHERE home_phone IS NOT NULL) AS has_home,
  COUNT(*) FILTER (WHERE personal_email IS NOT NULL) AS has_p_email,
  COUNT(*) FILTER (WHERE business_email IS NOT NULL) AS has_b_email,
  COUNT(*) FILTER (WHERE trump_rally_donor = TRUE) AS has_rally_tag
FROM raw.ncboe_donations;
```

**Expected: ALL ZEROS** — contact columns were lost in the April 14 PITR recovery.
If any are non-zero, that's GOOD news (means some enrichment survived) — report the numbers.

---

## Section 6: Source File Distribution

```sql
SELECT source_file, COUNT(*) AS rows
FROM raw.ncboe_donations
GROUP BY source_file
ORDER BY rows DESC;
```
**Expected: 18 source files.** Report all 18 with counts.

---

## Section 7: Match Method Distribution

```sql
SELECT dt_match_method, COUNT(*) AS rows
FROM raw.ncboe_donations
WHERE dt_match_method IS NOT NULL
GROUP BY dt_match_method
ORDER BY rows DESC;
```
Report all match methods and counts. This shows how the voter matching was done.

---

## Section 8: Flag Status

```sql
SELECT
  COUNT(*) FILTER (WHERE is_matched = TRUE) AS is_matched_true,
  COUNT(*) FILTER (WHERE is_matched = FALSE) AS is_matched_false,
  COUNT(*) FILTER (WHERE match_pass IS NOT NULL) AS has_match_pass,
  COUNT(*) FILTER (WHERE candidate_referendum_name IS NOT NULL) AS has_candidate_name
FROM raw.ncboe_donations;
```

**Expected:**
- is_matched should be TRUE for 1,293,069 rows (but may still be all FALSE — known bug)
- match_pass likely all NULL (known bug)
- candidate_referendum_name likely all NULL (never populated)

---

## Section 9: Staging Table Health Check

```sql
SELECT schemaname, tablename, n_live_tup
FROM pg_stat_user_tables
WHERE schemaname = 'staging'
ORDER BY n_live_tup DESC
LIMIT 20;
```
**Expected: 57 staging tables, all intact.** Report the top 20 by row count.

Key tables to verify:
- staging.ncboe_cluster_reps — should be ~158,461
- staging.cluster_dominant_name — should be ~230,533

---

## Section 10: Donation Dollar Sanity

```sql
SELECT
  SUM(norm_amount) AS total_dollars,
  MIN(norm_amount) AS min_donation,
  MAX(norm_amount) AS max_donation,
  AVG(norm_amount) AS avg_donation,
  COUNT(*) FILTER (WHERE norm_amount < 0) AS negative_donations,
  COUNT(*) FILTER (WHERE norm_amount > 100000) AS over_100k
FROM raw.ncboe_donations;
```

**Expected: ~$162M total** (NOT $1.2B — that was the inflated number before cross-file dedup was understood)

⚠️ Wait — the 2,431,198 rows include cross-race duplicates (same donation in multiple source files). So the SUM here will be INFLATED. The REAL total is ~$162M using dedup key `(name, street, date, amount, candidate, committee_sboe_id)`. Report what you get and note it's the raw sum before transaction dedup.

---

## Section 11: Date Range & Corrupt Dates

```sql
SELECT
  MIN(norm_date) AS earliest,
  MAX(norm_date) AS latest,
  COUNT(*) FILTER (WHERE EXTRACT(year FROM norm_date) > 2026) AS future_dates,
  COUNT(*) FILTER (WHERE EXTRACT(year FROM norm_date) < 2000) AS pre_2000
FROM raw.ncboe_donations;
```
**Expected: 42 corrupt future dates (years 2029, 2906, 3201, 5200)**

---

## Section 12: Committee Coverage

```sql
SELECT
  COUNT(DISTINCT committee_sboe_id) AS distinct_committees,
  COUNT(*) FILTER (WHERE committee_sboe_id IS NULL) AS null_committees
FROM raw.ncboe_donations;
```
**Expected: ~1,669 distinct committees**

---

## DELIVERABLE

Create a table summarizing all 12 sections:

| Check | Expected | Actual | Status |
|---|---|---|---|
| Row count | 2,431,198 | ??? | ✓ or ✗ |
| Clusters | 758,110 | ??? | ✓ or ✗ |
| ... | ... | ... | ... |

Flag any ✗ with explanation. Do NOT attempt to fix anything.

---

## WHAT YOU MUST NOT DO

1. Do not TRUNCATE anything
2. Do not INSERT, UPDATE, or DELETE any rows
3. Do not ALTER any table
4. Do not "fix" the is_matched flag (that's a separate task)
5. Do not "fix" the contact columns (that's a separate task)
6. Do not re-run ncboe_dedup_v2.py
7. Do not reload any CSV files
8. Do not create any new tables

**Your only job is to READ and REPORT.**
