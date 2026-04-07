# CURSOR FEC RELOAD — COMPLETION BRIEF
**Date:** April 6, 2026 8:36 PM EDT | **From:** Perplexity-Claude
**Status:** Almost done — 8,789 rows remaining across 11 files

---

## CURRENT STATE

`public.fec_donations` has **779,182 rows**. Target is **780,961 rows**.
Gap: **8,789 rows** across the files listed below.

---

## WHAT STILL NEEDS TO LOAD

Re-run ONLY these files — `ON CONFLICT (sub_id) DO NOTHING` protects against duplicates:

| File | Target | Loaded | Missing |
|------|--------|--------|---------|
| `WHATLEY-MCCRORY-2015-2026-US-SENATE.csv` | 7,604 | 0 | **7,604** |
| `GROUP-3-BROWN-MORROM-FEC-SENATE-2015-2026-3.csv` | 666 | 0 | **666** |
| `batch-5-house.csv` | 412 | 0 | **412** |
| `tillis-burr-budd-2015-2026.csv` | 30,890 | 30,845 | 45 |
| `2015-2026-us-house-fec-batch-one.csv` | 20,476 | 20,450 | 26 |
| `2015-2018-TRUMP-INDIDUALS.csv` | 42,795 | 42,785 | 10 |
| `2015-2026-us-house-batch2.csv` | 12,196 | 12,186 | 10 |
| `2015-2026-us-house-batch-3.csv` | 5,424 | 5,412 | 12 |
| `2019-2020-Trump-NC-GOP-FEC.csv` | 273,618 | 273,616 | 2 |
| `batch-4-us-house.csv` | 2,443 | 2,442 | 1 |
| `2022-2026-Trump-nc-individ-only.csv` | 377,779 | 377,778 | 1 |

```bash
export FEC_BULK_DATABASE_URL="postgresql://postgres:Anamaria%402026%40@db.isbgjpnbocdkeslofota.supabase.co:6543/postgres?sslmode=require"

python3 -m pipeline.load_fec_bulk --file "WHATLEY-MCCRORY-2015-2026-US-SENATE.csv" --category SENATE
python3 -m pipeline.load_fec_bulk --file "GROUP-3-BROWN-MORROM-FEC-SENATE-2015-2026-3.csv" --category SENATE
python3 -m pipeline.load_fec_bulk --file "batch-5-house.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "tillis-burr-budd-2015-2026.csv" --category SENATE
python3 -m pipeline.load_fec_bulk --file "2015-2026-us-house-fec-batch-one.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "2015-2018-TRUMP-INDIDUALS.csv" --category TRUMP
python3 -m pipeline.load_fec_bulk --file "2015-2026-us-house-batch2.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "2015-2026-us-house-batch-3.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "2019-2020-Trump-NC-GOP-FEC.csv" --category TRUMP
python3 -m pipeline.load_fec_bulk --file "batch-4-us-house.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file "2022-2026-Trump-nc-individ-only.csv" --category TRUMP
```

---

## VERIFY WHEN DONE

Run this query and report back to Ed:

```sql
SELECT source_file, COUNT(*) as rows
FROM public.fec_donations
GROUP BY source_file
ORDER BY rows DESC;
```

**Pass criteria:**
- Total rows = **780,961**
- Exactly **14 source files**
- **ZERO filenames containing `2026-03-11`** — if you see any, STOP and alert Ed immediately

---

## ⚠️ DO NOT TOUCH — EVER

| Table | Reason |
|-------|--------|
| `core.person_spine` | THE PEARL |
| `public.nc_boe_donations_raw` | Installed, synced, 3 days of work |
| `core.ncboe_donations_processed` | NC BOE processed layer |
| `norm.nc_boe_donations` | NC BOE normalized layer |
| `staging.boe_donation_candidate_map` | NC BOE candidate map |
| `public.nc_datatrust` | SACRED |
| `public.nc_voters` | SACRED |
| `public.rnc_voter_staging` | SACRED |
| `public.person_source_links` | SACRED |

---

## ⚠️ BANNED FILES — DO NOT LOAD UNDER ANY CIRCUMSTANCES

Any file with `2026-03-11` in the name. These were unfiltered FEC bulk downloads
containing Biden, Harris, Hillary, Bernie, Beasley, Cooper and hundreds of
Democratic candidates. They were deleted tonight. They are gone. Do not bring them back.

---

## WHAT COMES NEXT (Perplexity handles — not your job)

After you confirm 780,961 rows:
1. D-flag cleanup on `core.contribution_map` — 935,162 rows archived/deleted
2. Spine aggregate recompute for crossover donors
3. Deactivate D-only persons in `core.person_spine`

Report your final row count to Ed and stand by.

---
*Perplexity-Claude | April 6, 2026 8:36 PM EDT*
*Ed Broyhill authorized March 11 bulk delete at 8:15 PM EDT*
