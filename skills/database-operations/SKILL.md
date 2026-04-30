---
name: database-operations
description: >
  This skill should be used when working on the BroyhillGOP database,
  including "database work", "run SQL", "contact enrichment", "phone repopulation",
  "donor clustering", "golden record", "candidate names", "voter spine",
  "what stage are we on", "check database status", or any schema/data changes.
  CRITICAL: Contains guardrails to prevent the duplication and data destruction
  incidents that have occurred 13+ times. Must be loaded before any database operation.
metadata:
  version: '0.3.0'
  author: perplexity-ceo
  updated: '2026-04-16'
---

# BroyhillGOP Database Operations

---

## 🚨 NIGHTMARE HISTORY — READ THIS FIRST

This database has been corrupted **13+ times** by AI agents who did not follow protocols. The most destructive incidents:

1. **7.4x Transaction Inflation (April 14-15, 2026):** The 18 GOLD NCBOE files overlap — the same donation appears in multiple files because each covers a different race category. Naive loading without cross-file dedup inflated $162M to $1.2B and Ed Broyhill's canary from $332K to $1.3M. Ed caught it: "there is no way I donated that much."

2. **53,636 Records Deactivated (April 7, 2026):** Claude bulk-flipped 53K spine records from active to inactive with no audit trail, no merged_into values, no timestamps. The spine dropped from 128K to 74K.

3. **$417K Contribution Loss (March 27 - April 6, 2026):** Multiple rollup operations deleted legitimate contribution_map rows. Ed's canary dropped from $769K to $352K.

4. **NCBOE Contamination (13 incidents):** Files loaded without TRUNCATE-first protocol, Democrat candidates mixed in, unenriched files appended to sacred tables.

**THE DUPLICATION PROBLEM EXPLAINED:**
The 18 GOLD NCBOE files are scoped by race type (House, Senate, Sheriff, Judicial, etc.). When Ed Broyhill donates to BOTH an NC House candidate AND a Sheriff candidate, his donation record appears in BOTH the House file AND the Sheriff file. This is correct — these are separate donations to separate candidates. **The 2,431,198 row count is correct.** Cross-race donations are NOT duplicates. The dedup already ran and produced this number. Do NOT attempt to reduce it further.

**WHAT ACTUALLY WAS DUPLICATED:**
The inflation happened when rows were counted multiple times during rollup/aggregation, not in the raw data. The raw 2,431,198 rows are clean. The problem was in how totals were computed — summing across files without accounting for the same transaction appearing in multiple files. The fix was dedup on `(name, street_line_1, date_occurred, amount, candidate_referendum_name, committee_sboe_id)`.

---

## ⚠️ MANDATORY PRE-FLIGHT — DO THIS BEFORE ANYTHING ELSE

**Every session. No exceptions. Do not touch data until all 4 steps are complete and reported to Ed.**

### Step 1 — Read session state from the database
```sql
SELECT state_md FROM public.session_state ORDER BY id DESC LIMIT 1;
```
Read the full output carefully. Know what was done last session and what comes next before doing anything.

### Step 2 — Verify live row counts
```sql
SELECT
  (SELECT COUNT(*) FROM raw.ncboe_donations)                                    AS ncboe_rows,
  (SELECT COUNT(DISTINCT cluster_id) FROM raw.ncboe_donations)                  AS clusters,
  (SELECT COUNT(*) FROM raw.ncboe_donations WHERE rnc_regid IS NOT NULL)        AS voter_matched,
  (SELECT COUNT(*) FROM raw.ncboe_donations WHERE cell_phone IS NOT NULL)       AS cell_populated,
  (SELECT COUNT(*) FROM raw.ncboe_donations WHERE personal_email IS NOT NULL)   AS email_populated;
```
**If `ncboe_rows` ≠ 2,431,198 — STOP immediately and tell Ed before doing anything else.**

This number is sacred. It was produced by `ncboe_dedup_v2.py` (946 lines) which correctly handles cross-file donation overlap. If this number changed, someone re-ran the dedup or deleted rows.

### Step 3 — Run Ed's cluster integrity check (the canary)
```sql
SELECT
  cluster_id,
  COUNT(*)              AS txns,
  SUM(norm_amount)      AS total,
  MAX(cell_phone)       AS cell,
  MAX(home_phone)       AS home,
  MAX(personal_email)   AS p_email,
  MAX(business_email)   AS b_email,
  BOOL_OR(trump_rally_donor) AS rally
FROM raw.ncboe_donations
WHERE cluster_id = 372171
GROUP BY cluster_id;
```
Expected always: `txns=627` | `total=$1,318,672.04`
⚠️ If `p_email = jsneeden@msn.com` — **STOP. Clear it before doing anything else. That is Apollo bad data.**

### Step 4 — Report to Ed
Tell Ed the row counts and cluster check results. Confirm they match expectations (or flag any discrepancy). **Wait for Ed to say what to work on before proceeding.**

---

## CONNECTION

```
Host: 37.27.169.232 | Port: 5432 | DB: postgres | User: postgres
Password: ${PG_PASSWORD}
Full: postgresql://postgres:${PG_PASSWORD_URLENCODED}@37.27.169.232:5432/postgres
```

**Supabase (legacy — READ ONLY):**
```
Host: db.isbgjpnbocdkeslofota.supabase.co | Port: 6543 (pooler, sslmode=require)
```

---

## ABSOLUTE PROHIBITIONS

These actions require Ed to type the exact phrase: **`I AUTHORIZE THIS ACTION`**
"Yes", "go ahead", "ok", "do it", "proceed" are **NOT** authorization. Only that exact phrase.

| Action | Why It's Prohibited |
|--------|-------------------|
| `TRUNCATE` any table | Destroyed 2.4M rows + 5 hours of work on April 14, 2026 |
| `DROP TABLE` or `DROP COLUMN` | Irreversible |
| `DELETE` without a `WHERE` clause | Full-table wipe |
| `ALTER TABLE` removing or renaming columns | Breaks all dependent queries |
| Any DDL on `raw.ncboe_donations` | The crown jewel — treat as sacred |
| Re-running `ncboe_dedup_v2.py` | Already ran. Output = current 2,431,198 rows. |
| Re-running `datatrust_enrich.py` | Already ran. Voter matching complete. |
| Any bulk UPDATE that affects > 10,000 rows | Must be reviewed by Ed first |
| Creating aggregate/rollup tables without verification | The 7.4x inflation was caused by bad rollups |

**Protocol for any prohibited action:**
1. Show Ed the exact SQL that would execute
2. Show how many rows would be affected: `SELECT COUNT(*) FROM ... WHERE ...`
3. Say: *"This requires authorization. Please type: I AUTHORIZE THIS ACTION"*
4. Wait for that exact phrase
5. Only then execute

---

## ABSOLUTE RULES

1. **2,431,198 rows is correct.** Cross-race donations are legitimate — one donor giving to NC House AND Sheriff = 2 rows, both correct. Never attempt to reduce row count.
2. **IS NULL guard on all contact stamping.** Never overwrite existing phone/email. First source wins.
3. **`jsneeden@msn.com` is never Ed's email.** Apollo bad data. If it appears on cluster 372171, clear it immediately.
4. **ED = EDGAR, not EDWARD.** Hardcoded name matching rule. Always apply. Ed Broyhill's full legal name is James Edgar Broyhill II. "Ed" is short for his middle name EDGAR.
5. **Verify before modifying.** Run a SELECT showing what would change before any UPDATE/INSERT.
6. **Update session state after every session** — see instructions below.
7. **Never generate large spreadsheet previews.** Rendering large tables in browser preview panes crashes Claude sessions and loses all work. Export to CSV file instead.
8. **Never trust Acxiom modeled scores over real data.** Donation history, voting history, party positions, and volunteer activity override Acxiom scores. Acxiom ranked the NC National Committeeman as 74/100 Republican and his Biden-voting mother as 100/100.
9. **Process donations 2026 → 2015 (reverse chronological).** Newest records match best against current voter file. Older records inherit matches from newer ones.
10. **Employer + SIC code is the primary match anchor for major donors.** 75% of wealthy donors file from business addresses. The voter file only knows home addresses. The SIC/NAICS code bridges the gap.

---

## THE DUPLICATION TRAP — HOW TO AVOID IT

When computing donor totals or building aggregate tables:

**WRONG (causes 7.4x inflation):**
```sql
-- DO NOT DO THIS
SELECT cluster_id, SUM(norm_amount) as total
FROM raw.ncboe_donations
GROUP BY cluster_id;
```
This double-counts because the same physical donation appears in multiple rows (once per race file it was reported in).

**RIGHT (dedup on transaction identity):**
```sql
SELECT cluster_id, SUM(norm_amount) as total
FROM (
    SELECT DISTINCT ON (norm_last, norm_first, street_line_1, date_occurred, norm_amount, candidate_referendum_name, committee_sboe_id)
        cluster_id, norm_amount
    FROM raw.ncboe_donations
) deduped
GROUP BY cluster_id;
```

**Or use the pre-deduped count:** 321,348 unique transactions from the original 2,431,198 rows.

When in doubt about totals, check Ed's canary: cluster 372171 should total $1,318,672.04 for the cluster but his real unique candidate donations are ~$332K. If you see $1.3M, you're double-counting.

---

## DARK DONORS — 17,698 UNMATCHED

29 staging tables were created attempting to resolve "dark donors" (donors with no voter file match). Current status:
- 80,605 clusters matched to voter file (82%)
- 17,698 clusters still unmatched (18%)

Methods already attempted: phone matching, email matching, address number matching, geocode, fuzzy name, co-donation pattern, cross-zip, precinct-level. The remaining 17,698 are the hardest cases — likely dead, moved, out-of-state, or filed with insufficient data.

**Do NOT re-run the dark donor matching passes.** They have been completed. The results are in the `staging.dark_*` tables.

---

## HOW TO UPDATE SESSION STATE

After completing any meaningful work, insert a new row:

```sql
INSERT INTO public.session_state (updated_by, state_md)
VALUES ('Claude-YYYY-MM-DD', $$ [updated markdown] $$);
```

The most recent row (`ORDER BY id DESC LIMIT 1`) is always the live state. Keep the same format so future sessions can parse it immediately.

---

## PRODUCTION SCRIPTS — DO NOT REWRITE, DO NOT RE-RUN

| Script | Status | Notes |
|--------|--------|-------|
| `ncboe_dedup_v2.py` | ✓ Complete | 946 lines. Output = 2,431,198 rows. Do not touch. |
| `datatrust_enrich.py` | ✓ Complete | Voter matching done. 1,293,069 matched. Do not touch. |
| `pipeline/import_ncboe_committee_registry.py` | ⬜ Not yet run | Use for `candidate_referendum_name` population |

---

## CONTACT ENRICHMENT — EXACT SOURCE ORDER

When repopulating contact columns, process in this exact order. IS NULL guard throughout — first source wins.

1. **DataTrust** via JOIN on `rnc_regid` → phones only, from `core.datatrust_voter_nc`
2. `staging.winred_deduped` → email + phones
3. `staging.harris_cluster_contacts` + `staging.harris_spouse_contacts`
4. `staging.budd_matches`
5. `staging.budd_forsyth_matches`
6. `staging.budd_guilford_matches`
7. `staging.budd_wake_matches`
8. `staging.trump_nc_matches`
9. `staging.ncgop_forsyth_matches`
10. `staging.apollo_matches` ← ⚠️ **EXCLUDE `jsneeden@msn.com` on cluster 372171**
11. `staging.master_matches`
12. `staging.military_matches`
13. `staging.trump_rally_matches` ← tag `trump_rally_donor = TRUE` only (no contact info)
14. `staging.ncgop_2026_matches`
15. `staging.foxx_matches`
16. `staging.trump_ln_matches`
17. `staging.oneill_matches`

**Phone hierarchy:** neustar+data_axle > data_axle > neustar > voter_file
**Email classification:** gmail/yahoo/hotmail/aol/icloud/msn/outlook/comcast/att/bellsouth/earthlink → `personal_email`; all others → `business_email`
**Phone cleaning:** `REGEXP_REPLACE(phone, '[^0-9]', '', 'g')`, truncate to 10 digits

---

## ARCHITECTURE — READ THIS

- **758,110 cluster_ids** = distinct clusters ≈ unique real people. Clusters ≠ rows.
- **2,431,198 rows** = total donation records across 18 GOLD NCBOE files (cross-race overlap is legitimate)
- **321,348 unique transactions** after dedup on (name, address, date, amount, candidate, committee)
- **1,293,069 rows** have `rnc_regid` (53.2% voter-matched). Enrichable from DataTrust + Acxiom.
- **1,138,129 rows** have no voter link. Contact data for these comes only from staging tables.
- **Matching logic:** `norm_last = p_last AND LEFT(norm_first, 3) = LEFT(p_first, 3) AND norm_zip5 = zip5`
- **Acxiom tables** (4 × 7,655,593 rows) join on `rnc_regid`. ~225 GB total. Join carefully.
- **When done:** lock PG back to `listen_addresses = '127.0.0.1'`, reallocate huge pages first: `echo 33868 > /proc/sys/vm/nr_hugepages`

---

## KEY TABLES ON NEW SERVER (37.27.169.232)

| Schema | Table | Rows | Purpose |
|--------|-------|------|---------|
| core | datatrust_voter_nc | 7,727,637 | DataTrust 252-column voter file — FOUNDATION |
| core | acxiom_ap_models | 7,655,593 | Acxiom predictive/political scores |
| core | acxiom_ibe | 7,655,593 | Acxiom individual behavioral |
| core | acxiom_market_indices | 7,655,593 | Acxiom census/geographic |
| raw | ncboe_donations | 2,431,198 | NCBOE GOLD donor data — SACRED |
| staging | dark_* (29 tables) | Various | Dark donor matching results |
| staging | winred_deduped | — | WinRed contact data |
| staging | Various match tables | — | Contact enrichment sources |

## THE JOIN CHAIN (memorize)
```
nc_voters.ncid = DataTrust.StateVoterID → DataTrust.RNC_RegID = Acxiom.RNC_RegID
```

---

## NCBOE FILE FORMAT — EXACT COLUMN HEADERS (with NCBOE typos)

```
1.  Name
2.  Street Line 1
3.  Street Line 2
4.  City
5.  State
6.  Zip Code
7.  Profession/Job Title
8.  Employer's Name/Specific Field
9.  Transction Type          ← TYPO in source file
10. Committee Name
11. Committee SBoE ID
12. Committee Street 1
13. Committee Street 2
14. Committee City
15. Committee State
16. Committee Zip Code
17. Report Name
18. Date Occured             ← TYPO in source file
19. Account Code
20. Amount
21. Form of Payment
22. Purpose
23. Candidate/Referendum Name
24. Declaration
```

Name format: FIRST MIDDLE LAST (not LAST, FIRST like FEC)

---

## REFERENCE DOCUMENTS (in GitHub repo: broyhill/BroyhillGOP/sessions/)

| Document | Purpose |
|----------|---------|
| SESSION_START_READ_ME_FIRST.md | Master startup doc — read every session |
| COMPLETE_BUILD_TODO.md | Full Phase 0-K build plan |
| DONOR_DEDUP_PIPELINE_V2.md | 7-stage dedup with 8 matching passes |
| SESSION_APRIL10_2026_EVENING.md | Session with all dilemmas documented |
| SESSION_APRIL12_2026.md | Schema corrections, Acxiom findings |

---

*Last updated: April 16, 2026 by Perplexity (CEO)*
*Do not modify without Ed Broyhill's authorization.*
