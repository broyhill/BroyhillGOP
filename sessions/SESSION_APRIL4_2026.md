# BroyhillGOP Session — April 4, 2026
**Perplexity-Claude | Ed Broyhill | NC National Committeeman**

---

## FEC Pull Status

### Presidential — RUNNING (PID 83575)
- Started 10:05 PM
- 2016 ✅ 51,362 fetches | 2018 ✅ 14,714 fetches | 2020 🔄 in progress
- Output: `~/Downloads/FEC_NC_Presidential.csv`
- Log: `~/Downloads/fec_pres_nc.log`
- **Wait for COMPLETE then start Senate immediately**

### Senate — NOT YET STARTED
```bash
cd /Users/Broyhill/.cursor/worktrees/BroyhillGOP-CURSOR/yte
export OPENFEC_API_KEY="YOUR_ROTATED_KEY"
export OPENFEC_REQUEST_DELAY=2.0
nohup env OPENFEC_API_KEY="$OPENFEC_API_KEY" OPENFEC_REQUEST_DELAY="$OPENFEC_REQUEST_DELAY" \
  python3 -u -m pipeline.fec_nc_republican_donors --skip-presidential --office S \
  --output ~/Downloads/FEC_NC_Senate.csv >> ~/Downloads/fec_senate_nc.log 2>&1 &
echo "Senate PID: $!"
```

### House — COMPLETE ✅
- 65,883 rows | `~/Downloads/FEC_NC_House.csv`
- NC-only filter reduces to 41,216 rows on load

---

## FEC Script State (commit fcf1f34)

### 16 Approved Parameters
1. contributor_state = NC (API + script verification)
2. party = REP (API + script verification)
3. designation = P (principal committee only)
4. committee_type = H/S/P only
5. committee state = NC (House/Senate discovery)
6. cycles = 2016-2026
7. Schedule A only
8. is_individual = true
9. date range 01/01/2015-12/31/2026
10. per_page = 100, full pagination
11. FEC_ContributorID captured (new field)
12. Sequential runs only
13. REQUEST_DELAY = 2.0 seconds
14. Presidential = fixed committee list
15. Explicit committee_type exclusion (no party/PAC types)
16. Explicit non-Republican candidate exclusion

### Trump/Carson Bypass (COMMITTEE_IDS_BYPASS_PRINCIPAL_FILTER)
- C00580100 — MAKE AMERICA GREAT AGAIN PAC (Trump 2016)
- C00618371 — TRUMP MAKE AMERICA GREAT AGAIN COMMITTEE (Trump 2016/2020)
- C00828541 — NEVER SURRENDER, INC. (Trump 2024)
- C00573519 — THINK BIG AMERICA PAC (Carson 2016)

### BUG STILL IN SCRIPT — Fix Before Next Full Re-Run
- C00571372 (Right to Rise USA — Jeb Bush Super PAC) still in list — **REMOVE**
- C00579458 (JEB 2016, INC. — correct Jeb Bush principal) — **ADD**
- This affected current Presidential run (45 rows from wrong committee)

### Missing from Presidential List (couldn't look up — rate limited)
- Rand Paul 2016 — no principal type=P committee found in FEC
- Nikki Haley 2024 — only SFA ACTION (type=Q) found, no principal committee
- Tim Scott 2024 — no principal committee found in FEC system

---

## NCSBE Files — Ingestion Queue

### Ready to Load (need "I authorize this action")
| File | Rows | $ | Notes |
|------|------|---|-------|
| NC-House-Gop-2015-2026.csv | 407,499 | $280M | ✅ analyzed |
| NC-Senate-Gop-2015-2026-2.csv | 321,585 | $313M | ✅ analyzed |
| County-Municipal-100-counties-GOP-2015-2026.csv | 451,483 | — | ✅ queued |
| 2ndary-counties-muni-cty-gop-2015-2026.csv | 96,273 | — | ✅ queued |
| shiff-only-gop-100-counties.csv | 272,481 | — | ✅ queued |
| 2ndary-sheriff-gop-2015-2026.csv | 75,550 | — | ✅ queued |
| Judicial-gop-100-counties-2015-2026.csv | 170,002 | — | ✅ queued |
| Test-county-commissioners.csv | 7,484 | — | ✅ queued |
| District-Att-gop-100-counties-2015-2026.csv | 46,069 | $13M | ✅ analyzed |
| District-ct-judge-gop-100-counties-2015-2026.csv | 64,708 | $28M | ✅ analyzed |
| clerk-court-gop-2015-2026.csv | 5,651 | $1.1M | ✅ analyzed |
| Council-commissioners-gop-2015-2026.csv | 55,965 | $28.7M | ✅ analyzed |
| school-board-gop-2015-2026.csv | 25,834 | $9.3M | ✅ analyzed |
| **governor-2015-2026.csv** | **96,093** | $30M | ✅ USE THIS — replaces old 4,287-row file |
| council-city-town-gop-2015-2026.csv | 51,425 | $26.9M | ✅ analyzed |
| **SKIP:** alderman (78 rows — trivial) | — | — | skip |

**Total: ~2.15M rows**

### NOT Ready — Need Re-Pull (partial county coverage)
- Attorney-General-gop-2015-2026.csv — only 188 rows, ~13 counties
- suprem-court-superior-court-ct-of-appeals-2015-2026-gop.csv — only 1,133 rows
- treasurer-auditor-agriculture-labor-2015-2026-gop.csv — only 314 rows
- Governor-gop-2015-2026.csv (the OLD one, 4,287 rows) — replaced by governor-2015-2026.csv
- **Re-pull all 3 with all 100 counties same as governor was re-pulled**

### McCrory Gap
- Pat McCrory 2016 governor fundraising = federal committee FED-085NFW-C-001
- His major donors are in FEC, not NCSBE
- Pull separately via FEC API: `--committee FED-085NFW-C-001 --contributor_state NC`

---

## Database State

| Table | Rows | Status |
|-------|------|--------|
| public.contacts | 227,978 | ✅ |
| public.nc_boe_donations_raw | 338,223 | ⚠️ 11,676 duplicate hashes need cleanup |
| public.fec_donations | 2,591,933 | ✅ NC-only, clean |
| public.nc_datatrust | 7,661,978 | ✅ SACRED |
| staging.nc_voters_fresh | 7,708,542 | ✅ DataTrust March 2026 |
| core.person_spine | 128,043 active | ✅ |

### One Database Fix Needed Before NCSBE Load
```sql
-- REQUIRES: "I authorize this action"
-- Step 1: Remove 11,676 duplicate rows (keep lowest id per content_hash)
DELETE FROM public.nc_boe_donations_raw
WHERE id NOT IN (
    SELECT MIN(id)
    FROM public.nc_boe_donations_raw
    GROUP BY content_hash
);
-- Step 2: Lock it permanently
ALTER TABLE public.nc_boe_donations_raw
ADD CONSTRAINT uq_ncboe_content_hash UNIQUE (content_hash);
```

---

## Key Discoveries This Session

### NCSBE Search Coverage Problem
- County-by-county search captures far more than statewide search
- But statewide files (AG, Courts, Treasurer) still only had 15-20 counties
- Governor file re-pulled correctly: 4,287 rows → 96,093 rows (22x bigger)
- AG/Courts/Treasurer need same treatment

### FEC $200 Threshold
- Federal races: donors under $200 are anonymous (unitemized)
- NC state races: NCSBE discloses every donor down to $0.01
- NCSBE files are more complete than FEC for donor identification
- Trump small-dollar donors ($1-$199) not in FEC or NCSBE, only in WinRed
- WinRed file (194,278 rows) is NOT Trump-specific — it's your own contacts

### McCrory Finding
- Pat McCrory's 2016 governor fundraising filed federally (FED-085NFW-C-001)
- Near-zero donations in NCSBE state system
- Major donor data lives in FEC — needs separate pull

### DataTrust/Acxiom Fields
- 251-256 columns in nc_datatrust — confirmed complete for NC
- No "900 variables" exists — that's the national schema, NC gets 251
- custom01-custom05 fields present but not yet inventoried
- Database is clean — "7 critical March 28 issues" appear to have been resolved in prior sessions

---

## Pending Authorizations

1. **"I authorize this action"** → dedup cleanup (11,676 rows deleted from nc_boe_donations_raw) + unique constraint
2. **"I authorize this action"** → NCSBE bulk load (~2.15M rows)
3. **CONTACTS_COLUMN_MIGRATION.sql** → still designed by Claude, never executed, needs Ed auth

---
*Session recorded by Perplexity | April 4, 2026 11:34 PM EDT*
