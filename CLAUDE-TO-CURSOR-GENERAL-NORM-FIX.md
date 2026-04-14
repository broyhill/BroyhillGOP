# CURSOR: General-Type Normalization Bug Fix

**From: Claude (Cowork) | Date: March 15, 2026 | Priority: HIGH**

## Problem

Your `norm_etl_ncboe.py` treated "General" transaction type records as **organizations**, but they are **individuals** (persons donating to party general accounts). This means 70,283 rows have wrong normalization:

**Current (WRONG):**
```
donor_name = "Art Pope"     → norm_last = "ART POPE"      norm_first = "ART POPE"     is_organization = true
donor_name = "James A Pope" → norm_last = "JAMES A POPE"  norm_first = "JAMES A POPE" is_organization = true
```

**Expected (CORRECT):**
```
donor_name = "Art Pope"     → norm_last = "POPE"   norm_first = "ART"    is_organization = false
donor_name = "James A Pope" → norm_last = "POPE"   norm_first = "JAMES"  is_organization = false
```

## Evidence

Art Pope official NC BOE total: **157 txns / $1,156,519**
Our DB query using `norm_last = 'POPE'` returns: **145 txns / $992,919** (misses all 10 General-type Pope records)
Our DB query using `donor_name ILIKE` returns: **155 txns / $1,190,719** (finds them, proves they're loaded)

The 10 missing records are all General-type with `norm_last = 'ART POPE'` instead of `'POPE'`.

## Fix Required

### 1. Fix norm_etl_ncboe.py

In the transaction type routing logic, move "General" from the organization path to the person path:

```python
# PERSON types — parse with fn_normalize_donor_name
PERSON_TYPES = ('Individual', 'General')

# ORG types — set norm_last = donor_name, is_organization = true  
ORG_TYPES = ('Non-Party Comm', 'Cont to Other Comm', 'Party Comm', 'Coord Party Exp')
```

### 2. Re-normalize existing General rows

```sql
-- Fix the 70,283 General-type rows that were wrongly normalized as orgs
UPDATE nc_boe_donations_raw SET
  norm_last = (fn_normalize_donor_name(donor_name)).norm_last,
  norm_first = (fn_normalize_donor_name(donor_name)).norm_first,
  is_organization = false,
  donor_type = 'individual',
  canonical_first = NULL,  -- will be re-derived by canonical_first pipeline
  dedup_key = NULL          -- will be re-derived
WHERE source_file LIKE 'general-fund%'
  AND transaction_type = 'General'
  AND (is_organization = true OR norm_last = donor_name);
```

Then re-run canonical_first and dedup_key derivation for these rows.

### 3. Validation query (run after fix)

```sql
-- Should return ~155 txns / ~$1,190,719
SELECT COUNT(*) as txns, SUM(amount_numeric)::money as total
FROM nc_boe_donations_raw
WHERE norm_last = 'POPE' 
  AND (norm_first IN ('ART','JAMES','ARTHRU') OR donor_name ILIKE '%art%pope%')
  AND donor_name NOT ILIKE '%james w pope%'
  AND donor_name NOT ILIKE '%james larry%'
  AND NOT (donor_name = 'JAMES POPE' AND city = 'LILLINGTON');
```

## Summary

- **70,283 General-type rows** need re-normalization as persons, not organizations
- The pipeline fix in `norm_etl_ncboe.py` is a one-line change (add 'General' to person types)
- The SQL UPDATE fixes existing data
- Art Pope is the validation benchmark
