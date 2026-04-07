# MASTER FILE MANIFEST — BroyhillGOP Workspace
**Last updated: April 8, 2026 (NCBOE section corrected to Ed-approved Desktop set)**
**Authority: Ed Broyhill**
**DO NOT LOAD ANY FILE NOT ON THIS LIST**

---

## NCBOE FILES — Load into public.nc_boe_donations_raw
**Authoritative allow-list:** the **18 CSVs** Ed approved in **NCBOE DONORS GOLD** (Finder / Desktop — Apr 2026).  
Older 19-row tables in docs were **superseded** by this list. Row totals: confirm with `import_ncboe_raw.py --dry-run` or post-load `COUNT(*)`.

| File | Load |
|------|------|
| `2ndary-counties-muni-cty-gop-2015-2026.csv` | ✅ APPROVED |
| `2ndary-sheriff-gop-2015-2026.csv` | ✅ APPROVED |
| `2015-2025-lt-governor.csv` | ✅ APPROVED |
| `2015-2026-Mayors.csv` | ✅ APPROVED |
| `2015-2026-NC-Council-of-state.csv` | ✅ APPROVED |
| `2015-2026-supreme-court-appeals-.csv` | ✅ APPROVED |
| `clerk-court-gop-2015-2026.csv` | ✅ APPROVED |
| `council-city-town-gop-2015-2026.csv` | ✅ APPROVED |
| `Council-commissioners-gop-2015-2026.csv` | ✅ APPROVED |
| `County-Municipal-100-counties-GOP-2015-2026.csv` | ✅ APPROVED |
| `District-Att-gop-100 counties-2015-2026.csv` | ✅ APPROVED *(note: space after `100` — exact filename)* |
| `District-ct-judge-gop-100-counties-2015-2026.csv` | ✅ APPROVED |
| `governor-2015-2026.csv` | ✅ APPROVED |
| `Judicial-gop-100-counties-2015-2026.csv` | ✅ APPROVED |
| `NC-House-Gop++-2015-2026.csv` | ✅ APPROVED |
| `NC-Senate-Gop-2015-2026.csv` | ✅ APPROVED |
| `school-board-gop-2015-2026.csv` | ✅ APPROVED |
| `sheriff-only-gop-100-counties.csv` | ✅ APPROVED |
| **COUNT** | **18 files** |

## NCBOE — DO NOT LOAD
| File | Reason |
|------|--------|
| `Governor-gop-2015-2026.csv` | OLD small file — superseded by `governor-2015-2026.csv` |
| Any CSV **not** in the 18-row table above | Not approved |

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
Load the **18 approved** NCBOE files into `nc_boe_donations_raw` (replace strategy per `SESSION_START_READ_ME_FIRST.md`).
Requires **"I authorize this action"** from Ed before truncate/replace.

---
*Perplexity-Claude | April 6, 2026 10:49 PM EDT*
