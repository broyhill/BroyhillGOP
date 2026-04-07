# CURSOR FEC RELOAD BRIEF
**Date:** April 6, 2026 | **From:** Perplexity-Claude | **Priority: CRITICAL**

---

## WHAT JUST HAPPENED

Perplexity deleted **2,591,933 rows** from `public.fec_donations` tonight.
These were the **March 11, 2026 bulk FEC downloads** — unfiltered Schedule A files
that included Biden, Harris, Hillary, Bernie, Beasley, Cooper, and hundreds of
other Democratic candidates and out-of-state donors.

They are gone. Good riddance.

---

## WHAT IS IN fec_donations RIGHT NOW

**393,675 rows** — partial loads from Ed's manually curated files.
These are the ONLY rows that belong in this database.

Current state (partial — needs completion):
```
236,604  2022-2026-Trump-nc-individ-only.csv
143,294  2019-2020-Trump-NC-GOP-FEC.csv
 10,949  2015-2018-TRUMP-INDIDUALS.csv
  1,245  WHATLEY-MCCRORY-2015-2026-US-SENATE.csv
    630  2015-2026-us-house-fec-batch-one.csv
    432  tillis-burr-budd-2015-2026.csv
    286  2015-2026-us-house-batch2.csv
    118  group-1-pres-2015-2026.csv
     78  batch-4-us-house.csv
     38  group-2-2015-2026-president.csv
      1  2015-2026-us-house-batch-3.csv
```

Target after your reload: **780,961 rows**

---

## YOUR JOB — RELOAD THE 14 CLEAN FILES

Use `pipeline/load_fec_bulk.py` with `ON CONFLICT (sub_id) DO NOTHING`.
This is safe to re-run — duplicates are skipped automatically.

```bash
export FEC_BULK_DATABASE_URL="postgresql://postgres:Anamaria%402026%40@db.isbgjpnbocdkeslofota.supabase.co:6543/postgres?sslmode=require"

# TRUMP (3 files)
python3 -m pipeline.load_fec_bulk --file "2015-2018-TRUMP-INDIDUALS.csv" --category TRUMP
python3 -m pipeline.load_fec_bulk --file "2019-2020-Trump-NC-GOP-FEC.csv" --category TRUMP
python3 -m pipeline.load_fec_bulk --file "2022-2026-Trump-nc-individ-only.csv" --category TRUMP

# SENATE (3 files)
python3 -m pipeline.load_fec_bulk --file "tillis-burr-budd-2015-2026.csv" --category SENATE
python3 -m pipeline.load_fec_bulk --file "WHATLEY-MCCRORY-2015-2026-US-SENATE.csv" --category SENATE
python3 -m pipeline.load_fec_bulk --file "GROUP-3-BROWN-MORROM-FEC-SENATE-2015-2026-3.csv" --category SENATE

# PRESIDENTIAL (2 files)
python3 -m pipeline.load_fec_bulk --file "group-1-pres-2015-2026.csv" --category PRESIDENTIAL
python3 -m pipeline.load_fec_bulk --file "group-2-2015-2026-president.csv" --category PRESIDENTIAL

# HOUSE (6 files)
python3 -m pipeline.load_fec_bulk --file "2015-2026-us-house-fec-batch-one.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "2015-2026-us-house-batch2.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "2015-2026-us-house-batch-3.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "batch-4-us-house.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "batch-5-house.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "villaverde.csv" --category HOUSE
```

---

## ⚠️ CRITICAL — DO NOT LOAD THESE FILES — EVER

These are the files that were just deleted. They are **CANCER** to this database.
Do not load them under any circumstances, do not reference them, do not use them
as a source for anything:

```
pres-2023-2024-schedule_a-2026-03-11T22_34_32.csv   ← Kamala Harris, Biden
pres-2019-2020schedule_a-2026-03-11T22_29_00.csv    ← Biden, Bernie
pres-2015-16-schedule_a-2026-03-11T22_18_56.csv     ← Hillary, Bernie
pres-2017-2018-schedule_a-2026-03-11T22_21_57.csv
pres-2021-2022-schedule_a-2026-03-11T22_32_16.csv
pres-2025-2026-schedule_a-2026-03-11T22_36_12.csv
RNC-2015-2023-schedule_a-2026-03-11T23_24_16.csv    ← Unfiltered, all states
RNC-2024-2026-schedule_a-2026-03-11T23_26_28.csv
senate-2015-2016-schedule_a-2026-03-11T22_52_17.csv ← All parties, all states
senate-2017-2018-schedule_a-2026-03-11T22_53_51.csv
senate-2019-2020-schedule_a-2026-03-11T23_00_50.csv
senate-2021-2022-schedule_a-2026-03-11T23_12_37.csv
senate-2023-2024-schedule_a-2026-03-11T23_14_42.csv
senate-2025-2026-schedule_a-2026-03-11T23_16_23.csv
house-2017-2018-schedule_a-2026-03-11T22_40_13.csv
house-2019-2020-schedule_a-2026-03-11T22_42_56.csv
house 2021-2022-schedule_a-2026-03-11T22_46_12.csv
house-2023-2024-schedule_a-2026-03-11T22_48_39.csv
house-2025-2026-schedule_a-2026-03-11T22_50_12.csv
House-2015-2016-schedule_a-2026-03-11T22_38_59.csv
NRSC-2015-2020-schedule_a-2026-03-11T23_34_04.csv
NRSC-2021-2026-schedule_a-2026-03-11T23_36_31.csv
NRCC-2015-2026-schedule_a-2026-03-11T23_29_07.csv
```

If you ever see a source_file in fec_donations containing `2026-03-11` — that is
contamination and must be deleted immediately.

---

## WHAT "CLEAN" MEANS FOR THIS DATABASE

- NC donors ONLY (`contributor_state = 'NC'`)
- Individual donors ONLY (no corporations, PACs, associations)
- Republican candidates ONLY (no Democratic, Independent, Green candidates)
- The 14 files above are the ONLY approved FEC sources

---

## AFTER YOUR RELOAD — VERIFY THIS

```sql
SELECT source_file, COUNT(*) as rows
FROM public.fec_donations
GROUP BY source_file
ORDER BY rows DESC;
```

Expected result: exactly 14 source files, total = **780,961 rows**

If you see ANY filename containing `2026-03-11` — STOP and alert Ed immediately.

---

## WHAT COMES NEXT (Perplexity will handle — not your job)

1. NCSBE load — 19 files, ~2.15M rows into nc_boe_donations_raw
2. D-flag cleanup — 935,162 rows archived/deleted from contribution_map
3. Spine aggregate recompute for 11,268 crossover persons

---
*Written by Perplexity-Claude | April 6, 2026 8:18 PM EDT*
*Ed Broyhill authorized the March 11 bulk delete at 8:15 PM EDT*
