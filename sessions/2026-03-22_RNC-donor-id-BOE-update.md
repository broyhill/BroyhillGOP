# Session: RNC Donor ID + BOE Update
**Date:** March 22, 2026  
**Status:** ⚠️ HALF FINISHED — 54.1% complete, needs resume  
**Session ID:** local_74e6d1ac

---

## What Was Done

Downloaded the full RNC NC voter file (7,708,542 records) from `rncdatahubapi.gop` and loaded into staging table `public.rnc_voter_staging`. Ran an UPDATE joining `nc_boe_donations_raw` to staging on `norm_last + SPLIT_PART(norm_first,' ',1) + norm_zip5`.

### Results
- **338,720 BOE rows updated (54.1%)** — rncid and voter_ncid written
- **287,177 rows still unmatched** — need fuzzy matching
- RNCIDs range: `24,502,744,226 → 24,511,844,097`
- voter_ncid populated with NC registration IDs (AR10451, EH25347, etc.)
- 69,583 distinct voters matched across 338,720 rows

### Why 287K Didn't Match
Exact name+zip5 match only. Remaining rows either have name/zip format differences or are out-of-state donors to NC campaigns. 54.1% exact match rate is reasonable.

---

## What Needs to Happen Next

1. **Fuzzy match the 287K unmatched rows** using dmetaphone or trigram similarity
2. **Fix voter_ncid column type** — currently `bigint` but StateVoterID is alphanumeric (e.g. `AR10451`) — change to `VARCHAR`
3. **Run voter spine update** after fixing column type

---

## Key Tables
- `rnc_voter_staging` — 7,708,542 rows, fully indexed, intact
- `nc_boe_donations_raw` — 338,720 rows have rncid, 287,177 still NULL

## SQL to Resume Exact Pass
```sql
UPDATE nc_boe_donations_raw d
SET rncid = s.rncid, voter_ncid = s.statevoterid::varchar
FROM rnc_voter_staging s
WHERE d.rncid IS NULL
  AND d.norm_last = s.norm_last
  AND SPLIT_PART(d.norm_first,' ',1) = SPLIT_PART(s.norm_first,' ',1)
  AND d.norm_zip5 = s.zip5;
```

## SQL for Fuzzy Pass (Next Step)
```sql
UPDATE nc_boe_donations_raw d
SET rncid = s.rncid, voter_ncid = s.statevoterid::varchar, match_method = 'fuzzy_trigram'
FROM rnc_voter_staging s
WHERE d.rncid IS NULL
  AND d.norm_last = s.norm_last
  AND similarity(d.norm_first, s.norm_first) > 0.8
  AND d.norm_zip5 = s.zip5;
```
