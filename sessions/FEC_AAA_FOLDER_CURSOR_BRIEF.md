# Cursor Brief — AAA FEC Folder Pre-Load Audit
**Authority: Ed Broyhill | April 8, 2026**
**DO NOT LOAD ANY FILE until pre-load audit passes all 4 filters.**

---

## Objective
Inspect every CSV in `/Users/Broyhill/Desktop/AAA FEC Federal Pres Senate House/` and classify each file before loading. Output a routing decision for each file.

---

## Step 1 — List all files

```bash
ls -lh "/Users/Broyhill/Desktop/AAA FEC Federal Pres Senate House/"
```

Record filename and file size for every CSV. Do not assume anything about content from the filename — Ed has not titled them consistently.

---

## Step 2 — Run 4-filter audit on each file

For each CSV, run the following checks. Use pandas or equivalent. The FEC column names vary — detect which format the file uses:

**Common FEC column name variants:**
| Field | Variant A | Variant B |
|---|---|---|
| Donor name | `contributor_name` | `Name` |
| State | `contributor_state` | `State` |
| Committee | `committee_id` | `CMTE_ID` |
| Amount | `contribution_receipt_amount` | `Amount` |
| Memo flag | `memo_cd` | `MEMO_CODE` |
| Transaction type | `receipt_type` | `transaction_tp` |

**Filter 1 — Individual donors only**
Flag rows where donor name contains: `LLC`, `INC`, `CORP`, `PAC`, `COMMITTEE`, `CLUB`, `ASSOCIATION`, `FOUNDATION`, `TRUST`, `FUND`, `GROUP`, `PARTY`, `REC`, `NAT'L`, `NATIONAL`
Report: `{total_rows}` total, `{org_rows}` organizational (would be excluded)

**Filter 2 — Republican candidates/committees only**
Check committee names or party flags for: `DEM`, `DEMOCRAT`, `BIDEN`, `HARRIS`, `HILLARY`, `CLINTON`, `BERNIE`, `SANDERS`, `BEASLEY`, `COOPER`, `STEIN`, `WARREN`, `OBAMA`, `WARNOCK`, `OSSOFF`
Report: `{dem_rows}` Democratic-flagged rows (would be excluded)

**Filter 3 — NC donors only**
Check `contributor_state` or `State` column.
Report: `{nc_rows}` NC rows, `{out_of_state_rows}` out-of-state (would be excluded)

**Filter 4 — No memo transactions**
Check `memo_cd = 'X'` or `MEMO_CODE = 'X'` or `transaction_tp IN ('24I','24T')`
Report: `{memo_rows}` memo rows (would be excluded)

**Net estimate after all 4 filters:**
```
net_rows = total - org_rows - dem_rows - out_of_state_rows - memo_rows
```
(Use conservative estimate — some rows may fail multiple filters)

---

## Step 3 — Output routing table

For each file produce one line:

```
filename.csv | {total_rows} total | {net_rows} net after filters | ROUTE: [raw / committee_transfers / DISCARD] | NOTES: [key findings]
```

**Routing rules:**
- `net_rows > 0` AND all donors look like individuals AND Republican candidates → `ROUTE: raw` → `public.fec_donations` via existing FEC loader
- All rows are committee-to-committee or PAC → `ROUTE: committee_transfers` → `staging.ncboe_committee_transfers`
- Majority Democratic or unidentifiable → `ROUTE: DISCARD` → ask Ed before doing anything

---

## Step 4 — Post to Ed for confirmation

Paste the routing table to Ed. **Do not load any file until Ed says "confirmed" or "I authorize".**

After Ed confirms each file, load using the existing FEC ingestion pipeline with the 4 filters applied as WHERE conditions. Register each file in `pipeline.loaded_ncboe_files` (or equivalent FEC tracking table) with `ON CONFLICT DO NOTHING`.

---

## Step 5 — Post-load verification

After each file loads, run:

```sql
SELECT source_file,
       COUNT(*) AS rows_loaded,
       COUNT(DISTINCT committee_id) AS distinct_committees,
       MIN(contribution_receipt_date) AS min_date,
       MAX(contribution_receipt_date) AS max_date,
       SUM(contribution_receipt_amount) AS total_amount
FROM public.fec_donations
WHERE source_file = '[filename]'
GROUP BY source_file;
```

Report counts to Ed. If row count differs from `net_rows` estimate by more than 5% — stop and explain before continuing.

---

## What NOT to do

- Do NOT load any file directly without the 4-filter audit
- Do NOT add these files to `norm.fec_individual` or `core.contribution_map` yet — FEC spine linkage is Phase 4
- Do NOT touch `core.person_spine`, `public.nc_datatrust`, `public.nc_voters`, or `public.nc_boe_donations_raw`
- Do NOT run normalization or rollup on FEC data until Ed explicitly authorizes Phase 4

---

## Reference
- Existing FEC files (already loaded, do not reload): see `sessions/MASTER_FILE_MANIFEST.md` → "FEC FILES — Already loaded"
- FEC new folder documented in manifest: `sessions/MASTER_FILE_MANIFEST.md` → "FEC FILES — NEW"
- Banned files (never reload): any file with `2026-03-11` in source_file is contamination — delete immediately

---

*Written by Perplexity-Claude | April 8, 2026*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
