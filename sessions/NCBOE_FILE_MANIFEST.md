# NCBOE File Manifest — ⚠️ SUPERSEDED
**DO NOT USE THIS FILE FOR ROUTING DECISIONS**
This file is outdated (20-file narrative, April 6 vintage).
**Use `sessions/MASTER_FILE_MANIFEST.md` as the single authoritative source.**

---
*Retired April 8, 2026 — Perplexity-Claude*

---

# ARCHIVED CONTENT BELOW (for reference only)
**BroyhillGOP | Last updated: April 6, 2026**
**Authority: Ed Broyhill**

**Pre–GOLD-load audit priorities (P0/P1/P2):** see **`sessions/NCBOE_GOLD_PRE_INGEST_PLAN.md`** (recovered from the April 2026 spine-audit discussion; lives in-repo so it is not chat-only).

---

## PURPOSE OF THESE FILES

These are Ed Broyhill's manually pulled NCBOE donation files organized by office type,
downloaded April 3-4, 2026 from the NC SBOE campaign finance search tool.
All files are NC Republican candidates only, individual donors only, 2015-2026.

These files are the REPLACEMENT for the old `nc_boe_donations_raw` bulk files
(`2015-2019-ncboe.csv` and `2020-2026-ncboe.csv`) which were organized by year
instead of by office type and are missing the voter_ncid enrichment.

**These 20 files together = the complete NC BOE donor dataset organized correctly.**

---

## THE 20 NCBOE WORKSPACE FILES

| File | Rows | Size | Office Type | Load? |
|------|------|------|-------------|-------|
| NC-House-Gop-2015-2026.csv | 407,499 | 92MB | NC House GOP | ✅ YES |
| NC-Senate-Gop-2015-2026-2.csv | 321,585 | 74MB | NC Senate GOP | ✅ YES |
| County-Municipal-100-counties-GOP-2015-2026.csv | 451,483 | 96MB | County/Municipal | ✅ YES |
| shiff-only-gop-100-counties.csv | 272,481 | 57MB | Sheriff (primary 100 counties) | ✅ YES |
| 2ndary-sheriff-gop-2015-2026.csv | 75,550 | 15MB | Sheriff (secondary) | ✅ YES |
| Judicial-gop-100-counties-2015-2026.csv | 170,002 | 37MB | Judicial 100 counties | ✅ YES |
| 2ndary-counties-muni-cty-gop-2015-2026.csv | 96,273 | 20MB | County/Muni secondary | ✅ YES |
| governor-2015-2026.csv | 96,093 | 23MB | Governor **(USE THIS ONE)** | ✅ YES |
| District-ct-judge-gop-100-counties-2015-2026.csv | 64,708 | 14MB | District Court Judge | ✅ YES |
| Council-commissioners-gop-2015-2026.csv | 55,965 | 13MB | Council of Commissioners | ✅ YES |
| council-city-town-gop-2015-2026.csv | 51,425 | 12MB | City/Town Council | ✅ YES |
| District-Att-gop-100-counties-2015-2026.csv | 46,069 | 10MB | District Attorney (Dan Bishop) | ✅ YES |
| school-board-gop-2015-2026.csv | 25,834 | 6MB | School Board | ✅ YES |
| Test-county-commissioners.csv | 7,484 | 2MB | County Commissioners test batch | ✅ YES |
| clerk-court-gop-2015-2026.csv | 5,651 | 1MB | Clerk of Court | ✅ YES |
| suprem-court-superior-court-ct-of-appeals-2015-2026-gop.csv | 1,133 | 0.3MB | Supreme/Superior/Appeals | ✅ YES |
| Attorney-General-gop-2015-2026.csv | 188 | 45KB | Attorney General (Dan Bishop) | ✅ YES |
| treasurer-auditor-agriculture-labor-2015-2026-gop.csv | 314 | 80KB | Treasurer/Auditor/Ag/Labor | ✅ YES |
| alderman-gop-100-counties-2015-2026.csv | 78 | 20KB | Alderman | ✅ YES |
| **TOTAL** | **2,219,985** | | | |

---

## DO NOT LOAD

| File | Rows | Reason |
|------|------|--------|
| Governor-gop-2015-2026.csv | 4,287 | OLD small governor file — superseded by governor-2015-2026.csv (96,093 rows) |
| FEC_NC_House.csv | 65,883 | Unknown origin — NOT an NCBOE file. Do not load until Ed confirms what this is. |

---

## WHAT IS IN nc_boe_donations_raw NOW (April 6, 2026)

Current installed files — the OLD bulk format:
- `2015-2019-ncboe.csv` — 95,967 rows
- `2020-2026-ncboe.csv` — 242,256 rows
- **Total: 338,223 rows — ZERO voter_ncid populated**

The audit table `audit.nc_boe_donations_raw_pre_reload_20260330` has 625,897 rows
WITH voter_ncid and rncid populated — this was the pre-reload snapshot from March 30.

---

## THE DECISION TO MAKE (Next Session)

Before loading the 20 office-by-office files, Ed must decide:

**Option A:** Restore from `audit.nc_boe_donations_raw_pre_reload_20260330`
- Gets back to 625,897 rows WITH voter_ncid and rncid
- Same data as current files, just fully enriched
- No file uploads needed

**Option B:** Replace with the 20 office-by-office files (2,219,985 rows)
- Nearly 7x more rows
- Organized by office type — better for candidate/committee matching
- No voter_ncid on these yet — would need enrichment pass after load
- Requires truncating nc_boe_donations_raw and reloading

**Option C:** Both — restore enriched data first, then add office-by-office files
- Most complete dataset
- Most work

**Ed must make this decision. Do not touch nc_boe_donations_raw until he does.**

---

## FEC_NC_House.csv — UNKNOWN
65,883 rows, 28.8MB. This file is in the workspace but its origin is unknown.
It does NOT match the naming pattern of the NCBOE office-by-office files.
It may be an FEC file for NC House races, not an NCBOE file.
**Do not load until Ed confirms what this is.**

---
*Written by Perplexity-Claude | April 6, 2026 10:29 PM EDT*
