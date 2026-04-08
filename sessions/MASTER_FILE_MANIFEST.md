# MASTER FILE MANIFEST — BroyhillGOP Workspace
**Last updated: April 6, 2026 10:49 PM EDT**
**Authority: Ed Broyhill**
**DO NOT LOAD ANY FILE NOT ON THIS LIST**

---

## NCBOE FILES — Load into public.nc_boe_donations_raw
**Ed downloaded these April 3-4, 2026. One full day of work. All NC Republican candidates.**

| File | Rows | Load |
|------|------|------|
| NC-House-Gop-2015-2026.csv | 407,499 | ✅ YES |
| NC-Senate-Gop-2015-2026-2.csv | 321,585 | ✅ YES |
| County-Municipal-100-counties-GOP-2015-2026.csv | 451,483 | ✅ YES |
| shiff-only-gop-100-counties.csv | 272,481 | ✅ YES |
| Judicial-gop-100-counties-2015-2026.csv | 170,002 | ✅ YES |
| 2ndary-counties-muni-cty-gop-2015-2026.csv | 96,273 | ✅ YES |
| governor-2015-2026.csv | 96,093 | ✅ YES |
| 2ndary-sheriff-gop-2015-2026.csv | 75,550 | ✅ YES |
| District-ct-judge-gop-100-counties-2015-2026.csv | 64,708 | ✅ YES |
| Council-commissioners-gop-2015-2026.csv | 55,965 | ✅ YES |
| council-city-town-gop-2015-2026.csv | 51,425 | ✅ YES |
| District-Att-gop-100-counties-2015-2026.csv | 46,069 | ✅ YES |
| school-board-gop-2015-2026.csv | 25,834 | ✅ YES |
| Test-county-commissioners.csv | 7,484 | ✅ YES |
| clerk-court-gop-2015-2026.csv | 5,651 | ✅ YES |
| suprem-court-superior-court-ct-of-appeals-2015-2026-gop.csv | 1,133 | ✅ YES |
| Attorney-General-gop-2015-2026.csv | 188 | ✅ YES |
| treasurer-auditor-agriculture-labor-2015-2026-gop.csv | 314 | ✅ YES |
| alderman-gop-100-counties-2015-2026.csv | 78 | ✅ YES |
| **TOTAL** | **1,875,603** | |

## NCBOE MUNICIPAL — Load into public.nc_boe_donations_raw (individual donors)
Downloaded April 7, 2026 in 4 category batches — mayors, city council, school board, GOP 2015–2026.
Use: `bash scripts/wave1_ingest_municipal_gop_batches.sh` (set MUNI_DIR first)

| File | Size | Status |
|------|------|--------|
| Mayors-council-school-GOP-category-1-2015-2026.csv | 113 KB | ✅ LOAD → nc_boe_donations_raw |
| Mayors-council-school-gop-category-2-2015-2026.csv | 239 KB | ✅ LOAD → nc_boe_donations_raw |
| mayors-council-school-gop-cat-3-2015-2026.csv | 234 KB | ✅ LOAD → nc_boe_donations_raw |
| mayors-council-school-cat-4-gop-2015-2026.csv | 61 KB | ✅ LOAD → nc_boe_donations_raw |

---

## NCBOE PARTY / OTHER — Route to staging.ncboe_committee_transfers
NOT individual donors. Use: `python3 scripts/import_ncboe_raw.py --to-committee-transfers [file]`

| File | Size | Routing | Notes |
|------|------|---------|-------|
| General-Contrib-GOP-Party-2015-2026.csv | 142 KB | ⛔ → ncboe_committee_transfers | Party general fund — committee-level, not individuals |
| GOP-PARTY-Donors-2015-2026.csv | 1.2 MB | ⚠️ REVIEW FIRST | Run inspect_ncboe_top_donor_names.py — if org/committee names → transfers; if person names → raw |
| OTHER-GOP-2015-2026.csv | 230 KB | ⚠️ REVIEW FIRST | Run inspect_ncboe_top_donor_names.py — PAC/nonprofit vs individual decision pending |

Inspect command: `python3 scripts/inspect_ncboe_top_donor_names.py "/path/GOP-PARTY-Donors-2015-2026.csv" "/path/OTHER-GOP-2015-2026.csv"`
Runbook: `sessions/MUNICIPAL_GOP_NCBOE_BATCH_ROUTING.md`

---

## NCBOE — DO NOT LOAD
| File | Reason |
|------|--------|
| Governor-gop-2015-2026.csv | OLD small file (4,287 rows) — superseded by governor-2015-2026.csv |

---

## FEC FILES — Already loaded into public.fec_donations (779,182 rows LOCKED)
| File | Rows | Category |
|------|------|----------|
| 2022-2026-Trump-nc-individ-only.csv | 377,779 | TRUMP |
| 2019-2020-Trump-NC-GOP-FEC.csv | 273,618 | TRUMP |
| 2015-2018-TRUMP-INDIDUALS.csv | 42,795 | TRUMP |
| tillis-burr-budd-2015-2026.csv | 30,890 | SENATE |
| 2015-2026-us-house-fec-batch-one.csv | 20,476 | HOUSE |
| 2015-2026-us-house-batch2.csv | 12,196 | HOUSE |
| WHATLEY-MCCRORY-2015-2026-US-SENATE.csv | 7,604 | SENATE |
| 2015-2026-us-house-batch-3.csv | 5,424 | HOUSE |
| group-1-pres-2015-2026.csv | 3,960 | PRESIDENTIAL |
| batch-4-us-house.csv | 2,443 | HOUSE |
| group-2-2015-2026-president.csv | 1,594 | PRESIDENTIAL |
| batch-5-house.csv | 412 | HOUSE |
| GROUP-3-BROWN-MORROM-FEC-SENATE-2015-2026-3.csv | 666 | SENATE |
| villaverde.csv | 104 | HOUSE |
| **TOTAL** | **779,961** | LOADED ✅ |

---

## UNKNOWN / NEEDS ED DECISION
| File | Rows | Issue |
|------|------|-------|
| FEC_NC_House.csv | 65,883 | FEC format (has FEC transaction IDs) but found among NCBOE files. 100% REP, NC House candidates. Ed must decide: add to fec_donations or discard? |
| ted_budd_staging.csv | 5,114 | Staging file — unknown status |

---

## REFERENCE (do not load)
| File | Purpose |
|------|---------|
| gop_presidential_committees_2016_2024.csv | Reference lookup |
| nc_republican_federal_candidates_2015_2026-1.csv | Reference lookup |

---

## FIRST TASK NEXT SESSION
Load the 19 NCBOE files into nc_boe_donations_raw.
Current nc_boe_donations_raw has 338,223 rows with ZERO voter_ncid.
These 19 files will replace it with 1,875,603 rows.
Requires "I authorize this action" from Ed.

---
*Perplexity-Claude | April 6, 2026 10:49 PM EDT*
