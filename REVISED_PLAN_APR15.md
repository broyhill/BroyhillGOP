# REVISED MASTER PLAN — BroyhillGOP Donor Intelligence Build
## Revised: April 15, 2026 ~01:00 AM EDT
## Author: Perplexity Computer | Authority: Ed Broyhill
## Context: Critical discovery of 7.4x spine inflation from cross-file transaction duplication

---

## ⚠️ CRITICAL CONTEXT — THE SPINE IS INFLATED

The 18 NCBOE source files (GOLD uploads) contain overlapping donations. Each CSV covers a different race category (House, Senate, Sheriff, Municipal, Judicial, Council of State, Governor, Lt. Governor, Supreme Court, Appeals, District Court, District Attorney, Clerk of Court, County Commissioners, Council/City/Town, School Board, Mayors, 2ndary Sheriff, 2ndary Counties). **The same donation appears in every file where that candidate's race category matches.**

Cursor's dedup pipeline (ncboe_dedup_v2.py, stages 1A-1G) deduplicated **person identity** — merging ED/EDGAR/JAMES/J BROYHILL into one cluster. It never deduplicated **transactions**. The only column that differs between duplicate rows is `source_file`.

### Impact
| Metric | Current (Inflated) | Real (After Transaction Dedup) |
|---|---|---|
| Spine rows | 2,431,198 | ~321,756 |
| Total dollars | $1,199,211,944 | $162,056,814 |
| Distinct clusters | 758,110 | ~98,305 |
| Ed candidate txns | 627 | 147 |
| Ed candidate total | $1,318,672 | $332,631 |
| Inflation factor | — | 7.4x average |

### Verified Dedup Key
`(name, street_line_1, date_occured, amount, candidate_referendum_name, committee_sboe_id)`

This key produces exactly 147 unique transactions / $332,631.30 for Ed's cluster — matching his real-world knowledge.

Adding `account_code` and `form_of_payment` to the key does NOT change the results — those columns are identical across duplicate rows.

---

## WHAT IS SOLID (DO NOT REDO)

1. **Cluster identity (Union-Find)** — ncboe_dedup_v2.py stages 1A-1G correctly identified which rows belong to the same person. Clusters are valid.
2. **Party committee matching** — 288,786 linked rows in staging.ncboe_party_committee_donations (278,814 from Cursor + 9,972 from Perplexity tonight). Valid cluster linkages.
3. **Contact enrichment** — All phone/email/rally tags on the spine are correct.
4. **DataTrust voter matching** — 1,293,069 rows with rnc_regid. Valid.
5. **Acxiom joins** — Valid via rnc_regid.
6. **Committee table infrastructure** — 10 tables replicated from Supabase.
7. **Party table structure** — staging.ncboe_party_committee_donations has NO cross-file duplication (loaded from separate source, not the 18 GOLD files).

---

## REVISED STEP-BY-STEP PLAN

### Phase 0: Pre-Flight (EVERY SESSION — NO EXCEPTIONS)

Before touching anything:
1. Read SESSION_STATE from database
2. Verify spine row count = expected (see Phase 1 for whether this changes)
3. Ed canary: cluster 372171 — verify txn count and total match expected values
4. Read this plan
5. Read the latest session transcript
6. **Report to Ed and wait for his direction**

---

### Phase 1: Transaction Deduplication of the Spine
**Priority:** BLOCKER — nothing downstream works until this is resolved
**Executor:** Cursor (tedious SQL work, AI leads strategy)
**Ed authorization required:** YES — this modifies raw.ncboe_donations

#### The Problem
2,431,198 rows → ~321,756 unique transactions. 2,109,442 rows are cross-file duplicates where `source_file` is the ONLY differing column.

#### Strategy Options (FOR ED TO DECIDE)

**Option A: Deduplicated View (Non-Destructive)**
- Create a VIEW or MATERIALIZED VIEW that selects `DISTINCT ON` the dedup key
- Leave the 2,431,198 rows intact
- All downstream queries use the view instead of the raw table
- Pro: Reversible, no data loss, no authorization needed for the view itself
- Con: Every query is slower (dedup happens at read time), cluster_profile JSONB still contains inflated stats

**Option B: Mark-and-Filter (Semi-Destructive)**
- Add a column `is_primary_txn boolean DEFAULT false`
- Mark exactly one row per unique transaction as `is_primary_txn = true`
- Keep `source_file` info on the primary row (or aggregate source_files into an array)
- All downstream queries filter on `is_primary_txn = true`
- Pro: Reversible (column can be dropped), original rows preserved
- Con: Still carrying 2.1M dead rows, indexes/storage bloated

**Option C: True Dedup (Destructive — Requires Authorization)**
- DELETE the duplicate rows, keeping one representative per unique transaction
- Preserve `source_file` info by creating a `source_files text[]` array or separate mapping table
- Update cluster_profile JSONB to reflect true counts
- Re-verify all cluster_ids and contact enrichment
- Pro: Clean data, fast queries, accurate totals
- Con: Irreversible (backup first), requires "I AUTHORIZE THIS ACTION"

#### Recommended Approach: Option B first, then Option C after Ed validates

**Step 1B.1:** Create the is_primary_txn column
```sql
ALTER TABLE raw.ncboe_donations ADD COLUMN IF NOT EXISTS is_primary_txn boolean DEFAULT false;
```

**Step 1B.2:** Mark primary transactions
```sql
WITH ranked AS (
    SELECT id, ROW_NUMBER() OVER (
        PARTITION BY name, street_line_1, date_occured, amount, 
                     candidate_referendum_name, committee_sboe_id
        ORDER BY id ASC  -- keep lowest ID as primary
    ) AS rn
    FROM raw.ncboe_donations
)
UPDATE raw.ncboe_donations d
SET is_primary_txn = true
FROM ranked r
WHERE d.id = r.id AND r.rn = 1;
```

**Step 1B.3:** Verify Ed's canary
```sql
SELECT COUNT(*) as txns, SUM(norm_amount) as total
FROM raw.ncboe_donations
WHERE cluster_id = 372171 AND is_primary_txn = true;
-- Expected: 147 txns, $332,631.30
```

**Step 1B.4:** Verify spine-wide
```sql
SELECT COUNT(*) as primary_rows,
       COUNT(DISTINCT cluster_id) as clusters,
       ROUND(SUM(norm_amount)::numeric, 2) as total_dollars
FROM raw.ncboe_donations
WHERE is_primary_txn = true;
-- Expected: ~321,756 rows, ~98,305 clusters, ~$162,056,814
```

**Step 1B.5:** Ed reviews. If satisfied, Phase 1 complete. 
If Ed wants Option C (full delete), proceed with backup + DELETE WHERE is_primary_txn = false.

#### Post-Dedup: Update Cluster Profiles
After is_primary_txn is set, the cluster_profile JSONB on each row is stale (contains inflated n_rows and total_amount). Either:
- Rebuild cluster_profile using only is_primary_txn = true rows
- Or defer to person_master (Phase 4) which will compute correct totals

#### New Ed Canary Values (Post-Dedup)
| Metric | Old (Inflated) | New (Real) |
|---|---|---|
| Spine rows (is_primary_txn) | 2,431,198 | ~321,756 |
| Ed txns | 627 | 147 |
| Ed candidate total | $1,318,672.04 | $332,631.30 |
| Ed party total | $155,945.45 | $155,945.45 (unchanged) |
| Ed combined | $1,474,617.49 | $488,576.75 |

---

### Phase 2: Party Committee Matching — COMPLETE ✓

Already done tonight (April 15). 9,972 new matches across 6 stages. Results:
- 285,908 individual donors linked (95.6% of matchable individuals)
- 13,158 individual donors remain unlinked:
  - 5,705 with no address/zip/city (nothing to match on)
  - 3,981 whose name doesn't exist in the spine (party-only donors)
  - 167 out-of-state donors
  - Remaining: ambiguous multi-cluster matches

**No further action needed on party matching unless Ed wants to pursue the 13,158.**

---

### Phase 3: Committee Non-Individual Transactions
**Priority:** DEFERRED per Ed — "best to set aside committees for tomorrow"
**Executor:** Cursor

18,169 non-individual rows in the party table include:
- "PHIL BERGER COMMITTEE" parsed as L:COMMITTEE F:PHIL M:BERGER
- Committee-to-committee transfers
- Outside Source, Refund, Interest transactions

These require a completely separate matching approach — committee name → committee_sboe_id → candidate linkage. Different pipeline, different table, different logic. DO NOT MIX with individual donor processing.

---

### Phase 4: Populate donor_intelligence.contribution_map
**Priority:** BLOCKED until Phase 1 complete
**Executor:** Cursor (SQL), AI (validation)

After transaction dedup (Phase 1), insert into contribution_map using ONLY `is_primary_txn = true` rows from the spine:

```sql
-- Candidate donations (ONLY primary transactions)
INSERT INTO donor_intelligence.contribution_map (...)
SELECT ... FROM raw.ncboe_donations
WHERE cluster_id IS NOT NULL AND is_primary_txn = true;

-- Party donations (no dedup issue here)
INSERT INTO donor_intelligence.contribution_map (...)
SELECT ... FROM staging.ncboe_party_committee_donations
WHERE cluster_id IS NOT NULL;
```

Ed canary: contribution_map for person_id=372171 should show $488,576.75 combined.

---

### Phase 5: Populate donor_intelligence.person_master
**Priority:** BLOCKED until Phase 4 complete
**Executor:** Cursor (SQL), AI (validation)

One row per cluster with correct (non-inflated) totals derived from contribution_map. Include:
- Best name variant (most frequent, not alphabetical MAX)
- DataTrust reg_zip5 as authoritative zip (Ed = 27104, NOT 27105)
- Contact info (cell_phone, home_phone, personal_email, business_email) with source provenance
- Combined candidate + party donation totals
- Source systems flag

---

### Phase 6: Verify Ed Cluster 372171
**Priority:** Gate check before any deployment
**Executor:** AI

Ed's cluster must show:
- candidate_total: $332,631.30 (147 unique transactions)
- party_total: $155,945.45 (40 transactions)
- combined_total: $488,576.75
- zip5: 27104 (from DataTrust reg_zip5)
- cell_phone: 3369721000
- personal_email: ed@broyhill.net
- trump_rally_donor: TRUE
- No jsneeden@msn.com anywhere

---

### Phase 7: Update SESSION_STATE
After each phase, update the database SESSION_STATE with current verified counts.

---

### Phase 8: Employer Bridge for Major Donors (Future)
**Priority:** After Phases 1-6 complete
**Context:** Ed explained that major donors often file from their office address, which won't match their voter registration address. "these rich men in 2025-2026 are old and retired so they may use retired for last 5 years. best to match employer and donor from 2015 going forward to 2026"

This is the remaining ~13,158 unlinked individual party donors. Some can be matched via:
- Employer name overlap (spine employer = party employer, same last name)
- Geocode matching (Acxiom lat/lon vs address) — but "office is a problem"
- DataTrust 2,200 variables — "something has to match easy"

Defer to after the foundation (Phases 1-6) is solid.

---

### Partitions #7 and #8 — HARD DEADLINE JULY 31
These are the most time-sensitive items. Details TBD but the deadline is firm. Everything above must be completed well before this date to leave room for these partitions.

---

## CURSOR DEPLOYMENT NOTES

The CURSOR_PARTY_MATCH_BRIEF.md in the repo is now outdated. It was written before the cross-file duplication discovery. Key changes:
1. All dollar totals in the brief are wrong (inflated 7.4x)
2. The contribution_map and person_master SQL in Part 2/3 must use `is_primary_txn = true` filter
3. Ed canary expected values have changed (see Phase 6 above)
4. The brief's 6-stage matching SQL is VALID and ALREADY EXECUTED — do not re-run

Cursor should:
1. Read this revised plan
2. Read the session transcript
3. Implement Phase 1 (transaction dedup) as first priority
4. Report to Ed before executing anything destructive
5. Follow the authorization protocol for any DDL on raw.ncboe_donations

---

## AUTHORIZATION PROTOCOL REMINDER

Destructive actions on raw.ncboe_donations require Ed to type exactly:
**"I AUTHORIZE THIS ACTION"**

Not "yes." Not "ok." Not "go ahead." Not "do it." The exact phrase.

Show Ed:
1. Exactly what SQL will execute
2. How many rows will be affected
3. What the expected outcome is
4. What the rollback plan is

---

*Revised by Perplexity Computer — April 15, 2026 ~01:00 AM EDT*
*"i cautioned you in the beginning when i saw the multi million number and you wouldnt listen" — Ed Broyhill*
*He was right. Build on truth, not inflated numbers.*
