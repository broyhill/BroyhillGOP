# Dedup V3.1 Merge Candidate Review
## Date: April 2, 2026
## Reviewer: Perplexity (lead architect)

## Final State After Review
- Started with: 167 candidates
- After P5 delete (false positives — family businesses): 126 remaining
- After P3 delete (false positives — household first/middle name): 12 remaining
- After P2 + P4 delete (false positives — family members): **4 remaining**

## 4 APPROVED Merge Pairs (P7 — DataTrust Household, Same Birth Year)
| keeper_person_id | merge_person_id | Names | Birth Year | Reason |
|-----------------|----------------|-------|-----------|--------|
| 4742 | 149805 | KATHLEEN EATON | 1944 | Same birth year, DT household, moved zips |
| 23556 | 158538 | RICHARD FRIEDMAN | 1956 | Same birth year, DT household, neighboring zips |
| 43758 | 199442 | JOHN BUGG | 1944 | Same birth year, DT household |
| 79305 | 188525 | THOMAS BLUE | 1955 | Same birth year, DT household, WELLS FARGO |

## False Positive Analysis — V3.2 Required Fixes

### P5 (Employer Cross-Address) — ALL 41 REJECTED
Root cause: Family businesses. Same last name + same employer = family members, not duplicates.
Fix needed: Add birth_year guard (ABS <= 5 years) AND require exact norm_first match.

### P3 (First=Middle in Block) — ALL 114 REJECTED
Root cause: Household naming patterns. Spouses share first/middle names (very common in
Indian, Middle Eastern, traditional American families). Father names son using own first as middle.
Examples: PRASHANT/POONAM PATEL, FIROZ/FIROZA MISTRY, AOUS/HANA ALKHALDI
Fix needed: P3 should be DISABLED for this dataset. The pattern produces near-zero true positives.
Alternative: Only fire P3 when same voter_ncid (impossible if same address) or same birth_year.

### P2 (Canonical Name) — ALL 5 REJECTED
Root cause: Canonical name lookup is matching across household members with same canonical form.
JILLIAN+THOMAS BASHORE both have canonical="BETTY" — that's a data error in nc_voters.
CLIFTON vs CLIFFORD — 24 year age gap, different people.
Fix needed: Add birth_year guard (ABS <= 5 years) to P2.

### P4 (Initials) — ALL 3 REJECTED
Root cause: Family members sharing last name and initial at same address.
SUSAN BELL WOOTEN (1944) vs S BENNETT WOOTEN (1993) — mother/daughter, 49 year gap.
Fix needed: Add birth_year guard (ABS <= 5 years) to P4.

## V3.2 Required Changes for Cursor
1. P5: Add `AND (a.birth_year IS NULL OR b.birth_year IS NULL OR ABS(a.birth_year - b.birth_year) <= 5)`
        Add `AND a.norm_first = b.norm_first` (exact first name match for cross-address)
2. P3: DISABLE entirely OR add `AND a.birth_year IS NOT NULL AND b.birth_year IS NOT NULL AND ABS(a.birth_year - b.birth_year) <= 2`
3. P2: Add `AND (a.birth_year IS NULL OR b.birth_year IS NULL OR ABS(a.birth_year - b.birth_year) <= 5)`
4. P4: Add `AND (a.birth_year IS NULL OR b.birth_year IS NULL OR ABS(a.birth_year - b.birth_year) <= 5)`
5. Phase 8 block_reason fix: `LEFT(block_reason, NULLIF(POSITION(':' IN block_reason), 0) - 1)`

## Current staging.v3_merge_candidates
4 rows — all P7, all verified, all ready for merge executor authorization from Ed.
