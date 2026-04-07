# NCBOE upload — preflight plan & safety gate

**Created:** 2026-04-08  
**Authority:** Ed authorized *planning* through “determine we are safe to upload data” — **no raw replace executed in this task.**

**Read first:** `sessions/SESSION_START_READ_ME_FIRST.md`, `sessions/MASTER_FILE_MANIFEST.md`

---

## 1. What “safe to upload” means

| Criterion | Meaning |
|-----------|---------|
| **Allow-list only** | Every CSV loaded is on `MASTER_FILE_MANIFEST.md` (NCBOE ✅ YES) or explicitly added by Ed. **No** unknown Desktop stragglers. |
| **No banned files** | e.g. `Governor-gop-2015-2026.csv` (superseded), `FEC_NC_House.csv` (unknown bucket), other “UNKNOWN / NEEDS ED” rows — not in the ingest folder. |
| **Folder matches intent** | `wave1_ingest_gold_ncboe.sh` ingests **every** `*.csv` in `GOLD_DIR`. The folder must contain **only** approved NCBOE files (or script must be changed to loop the manifest only). |
| **Dry run clean** | `bash scripts/wave1_ingest_gold_ncboe.sh --dry-run` exits 0 for every file you will load. |
| **Replace strategy explicit** | Truncate `nc_boe_donations_raw` (and whether to clear `pipeline.loaded_ncboe_files` for NCBOE) is **written down** before first insert — avoids duplicate universe on top of old bulk data. |
| **Ed authorization for writes** | Exact phrase **“I authorize this action”** for **replacing** sacred raw (per `SESSION_START` + manifest footer). *Planning authorization ≠ execute authorization unless Ed repeats for the cutover.* |

---

## 2. Phase 0 bullets (minimum before first byte hits Postgres)

Lock so work does not churn (from consolidated Wave 1 plan):

1. **Recipient filter:** GOP committees/candidates only in the **exported** files (already Ed’s export discipline).  
2. **Individual-only:** NCBOE individual rows only in these files.  
3. **Contributor rule:** DEM/UNA/IND **people** giving to GOP — **in**; non-GOP recipients — **out** (file sourcing handles this).  
4. **Keys:** `ncid` + `rnc_regid` on spine when available; legacy `rncid` for joins — document in spec when enriching **after** raw load.  
5. **Registered voter (reporting):** recommend `nc_voters.status_cd = 'A'` for TRUE (`089` pattern); refresh after voter file updates.

*(One page in `docs/` optional; bullets above can stand as the Phase 0 gate for upload.)*

---

## 3. Authoritative allow-list — **18 files Ed approved** (Apr 2026)

**Source of truth:** Ed’s **NCBOE DONORS GOLD** folder (Finder). The repo manifest was updated **2026-04-08** to match **only** these names.

1. `2ndary-counties-muni-cty-gop-2015-2026.csv`  
2. `2ndary-sheriff-gop-2015-2026.csv`  
3. `2015-2025-lt-governor.csv`  
4. `2015-2026-Mayors.csv`  
5. `2015-2026-NC-Council-of-state.csv`  
6. `2015-2026-supreme-court-appeals-.csv`  
7. `clerk-court-gop-2015-2026.csv`  
8. `council-city-town-gop-2015-2026.csv`  
9. `Council-commissioners-gop-2015-2026.csv`  
10. `County-Municipal-100-counties-GOP-2015-2026.csv`  
11. `District-Att-gop-100 counties-2015-2026.csv` *(space after `100`)*  
12. `District-ct-judge-gop-100-counties-2015-2026.csv`  
13. `governor-2015-2026.csv`  
14. `Judicial-gop-100-counties-2015-2026.csv`  
15. `NC-House-Gop++-2015-2026.csv`  
16. `NC-Senate-Gop-2015-2026.csv`  
17. `school-board-gop-2015-2026.csv`  
18. `sheriff-only-gop-100-counties.csv`  

**Do not load:** `Governor-gop-2015-2026.csv` (old); any other CSV.

---

## 4. Desktop folder check (`~/Desktop/NCBOE DONORS GOLD`)

**Expected:** exactly **18** `.csv` files, **matching the list above** — no extra downloads, no unknown files.  
`wave1_ingest_gold_ncboe.sh` loads **all** `*.csv` in the folder; extra files = **not safe**.

---

## 5. Current database snapshot (read-only, preflight)

- `nc_boe_donations_raw` row count: **416,297** (Apr 8 spot check; differs from Apr 6 SESSION note — treat as current until replace).  
- `pipeline.loaded_ncboe_files`: **7** rows — prior partial loads exist.

**Implication:** Replace/truncate strategy must account for **`loaded_ncboe_files`** (whether to clear hashes for a clean **18-file** pass — **decide with Ed**).

---

## 6. Safety verdict — allow-list **aligned**; remaining gates before production ingest

**Allow-list:** ✅ Ed’s 18 files = `sessions/MASTER_FILE_MANIFEST.md` (updated 2026-04-08).

**Still required before upload:**

1. **Folder hygiene:** GOLD directory contains **only** those 18 CSVs (plus README/log if non-`.csv`).  
2. **`wave1_ingest_gold_ncboe.sh --dry-run`** exits **0** for all 18.  
3. **Written decision:** truncate `nc_boe_donations_raw` or not; **`pipeline.loaded_ncboe_files`** reset policy for this cutover.  
4. Ed: **“I authorize this action”** for **replacing** sacred raw (`SESSION_START`).

---

## 7. Next actions (in order)

1. **Verify** Desktop folder = **exactly** the 18 files (no stragglers).  
2. **Optional:** `scripts/wave1_ingest_manifest_only.sh` looping **only** these 18 basenames — safer than glob-if-folder-ever-picks-up-junk.  
3. **Dry run** → **truncate** (authorized) → **ingest** → row-count sanity check.  
4. **Insert** `pipeline.wave1_source_snapshots` row.  
5. **Separate authorized cycle** for `norm.nc_boe_donations` rebuild (`SESSION_START`).

---

*Preflight: allow-list corrected per Ed. **Complete Section 6 gates before production ingest.***
