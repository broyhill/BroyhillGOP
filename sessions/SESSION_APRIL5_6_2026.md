# BroyhillGOP Session — April 5-6, 2026
**Perplexity-Claude | Ed Broyhill | NC National Committeeman**
**Session: Saturday April 5 3:41 PM EDT — Sunday April 6 2:19 AM EDT**

---

## TODO LIST — MORNING APRIL 6

### IMMEDIATE (before anything else)
- [ ] **Rotate DB password** — it appeared in chat multiple times tonight. Change in Supabase dashboard → Settings → Database → Reset password
- [ ] **Rotate FEC API key** — at api.data.gov. Old key `M7JqKy1IYd23ajGAGrR5WYR3jOrhWB1luqGIX95Y` is compromised

### FEC LOAD — PRIMARY TASK
- [ ] Export .numbers files to CSV on Mac (File → Export To → CSV, UTF-8):
  - tillis-burr-budd-2015-2026.numbers
  - WHATLEY-MCCRORY-2015-2026-US-SENATE-2.numbers
  - group-1-pres-2015-2026.numbers
  - group-2-2015-2026-president.numbers
- [ ] Run test load (smallest file first):
  ```
  cd /Users/Broyhill/.cursor/worktrees/BroyhillGOP-CURSOR/yte
  python3 -m pip install pandas psycopg2-binary
  export FEC_BULK_DATABASE_URL="postgresql://postgres:NEWPASSWORD@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres?sslmode=require"
  python3 -m pipeline.load_fec_bulk \
    --file ".../2015-2018-TRUMP-INDIDUALS.csv" --category TRUMP
  ```
- [ ] Paste 4-line output to Perplexity for verification
- [ ] If test passes, run all 13 files in sequence (see FEC_LOAD_SEQUENCE below)

### NCSBE LOAD — SECOND TASK
- [ ] Say **"I authorize this action"** to Perplexity to run dedup cleanup first:
  - Removes 11,676 duplicate rows from nc_boe_donations_raw
  - Adds UNIQUE constraint on content_hash
- [ ] Then authorize NCSBE bulk load — ~2.15M rows across 14 files
- [ ] Do NOT load: alderman file (78 rows, trivial)
- [ ] Do NOT load partial statewide files (AG, Supreme/Appeals, Treasurer — need re-pull)

### STATEWIDE RE-PULLS NEEDED
- [ ] Re-pull Attorney General — search all 100 counties (current file only has ~13 counties, 188 rows)
- [ ] Re-pull Supreme/Superior/Appeals — current file only 1,133 rows
- [ ] Re-pull Treasurer/Auditor/Ag/Labor — current file only 314 rows

### OTHER PENDING
- [ ] FEC Presidential pull — Presidential: running PID 90226, likely stalled. Kill and restart with timeout fix after Cursor applies it
- [ ] Cursor fix needed: add per-request timeout=30 to Schedule A pagination loop in fec_nc_republican_donors.py
- [ ] CONTACTS_COLUMN_MIGRATION.sql — designed by Claude, never executed, needs Ed authorization
- [ ] Danny Gustafson — dim_election CSV still pending (email dgustafson@gop.com)
- [ ] Check Hetzner county BOE download log: /opt/broyhillgop/logs/county_boe_download.log
- [ ] DataTrust token expires April 10 — confirm renewal with Danny

---

## FEC LOAD SEQUENCE (all 13 files)

```bash
# TRUMP (3 files — ~694,192 rows total)
python3 -m pipeline.load_fec_bulk --file ".../2015-2018-TRUMP-INDIDUALS.csv" --category TRUMP
python3 -m pipeline.load_fec_bulk --file ".../2019-2020-Trump-NC-GOP-FEC.csv" --category TRUMP
python3 -m pipeline.load_fec_bulk --file ".../2022-2026-Trump-nc-individ-only.csv" --category TRUMP

# SENATE (3 files — ~39,160 rows total)
python3 -m pipeline.load_fec_bulk --file ".../tillis-burr-budd-2015-2026.csv" --category SENATE
python3 -m pipeline.load_fec_bulk --file ".../WHATLEY-MCCRORY-2015-2026-US-SENATE-2.csv" --category SENATE
python3 -m pipeline.load_fec_bulk --file ".../GROUP-3-BROWN-MORROM-FEC-SENATE-2015-2026-3.csv" --category SENATE

# PRESIDENTIAL (2 files — ~5,554 rows total)
python3 -m pipeline.load_fec_bulk --file ".../group-1-pres-2015-2026.csv" --category PRESIDENTIAL
python3 -m pipeline.load_fec_bulk --file ".../group-2-2015-2026-president.csv" --category PRESIDENTIAL

# HOUSE (5 batches + Villaverde — ~41,055 rows total)
python3 -m pipeline.load_fec_bulk --file ".../2015-2026-us-house-fec-batch-one.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file ".../2015-2026-us-house-batch2.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file ".../2015-2026-us-house-batch-3.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file ".../batch-4-us-house.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file ".../batch-5-house.csv" --category HOUSE
python3 -m pipeline.load_fec_bulk --file ".../villaverde.csv" --category HOUSE
```

---

## WHAT WAS BUILT TONIGHT

### FEC Manual Download Collection — Complete
780,961 rows | $114.4M | All NC, all individual, all Republican

| Category | Rows | Total $ |
|----------|------|---------|
| Trump (2015-2026) | 694,192 | $51.8M |
| Senate | 39,160 | $22.5M |
| Presidential | 5,554 | $2.0M |
| House (5 batches + Villaverde) | 41,055 | $38.1M |

**Known gaps:** Meadows for Congress (committee unlocatable in FEC), Ted Budd House (merged with Senate committee C00614776 — data IS captured)

**New committee discovered:** C00867937 — TRUMP 47 COMMITTEE, INC. ($6.2M, 273 NC major donors, avg $22,877)

### Database Changes Made Tonight
- Added `uq_fec_donations_sub_id` UNIQUE constraint on `public.fec_donations.sub_id`
- Added 7 new columns to `public.fec_donations`: contributor_middle_name, contributor_suffix, contributor_id, candidate_id, candidate_office_district, election_type, pdf_url

### New Scripts Committed to GitHub
- `pipeline/load_fec_bulk.py` — loads any FEC bulk CSV into fec_donations with ON CONFLICT (sub_id) DO NOTHING
- `sessions/FEC_COLLECTION_INVENTORY.md` — complete manifest of all files
- `sessions/FEC_PULL_V2_CRITERIA.md` — 16 approved parameters for API pull
- `sessions/FEC_OVERNIGHT_PLAYBOOK.md` — restart commands

### NCSBE Files Queued (~2.15M rows)
Waiting for "I authorize this action":
1. NC-House-Gop-2015-2026.csv — 407,499 rows, $280M
2. NC-Senate-Gop-2015-2026-2.csv — 321,585 rows, $313M
3. County-Municipal-100-counties-GOP-2015-2026.csv — 451,483 rows
4. 2ndary-counties-muni-cty-gop-2015-2026.csv — 96,273 rows
5. shiff-only-gop-100-counties.csv — 272,481 rows
6. 2ndary-sheriff-gop-2015-2026.csv — 75,550 rows
7. Judicial-gop-100-counties-2015-2026.csv — 170,002 rows
8. Test-county-commissioners.csv — 7,484 rows
9. District-Att-gop-100-counties-2015-2026.csv — 46,069 rows
10. District-ct-judge-gop-100-counties-2015-2026.csv — 64,708 rows
11. clerk-court-gop-2015-2026.csv — 5,651 rows
12. Council-commissioners-gop-2015-2026.csv — 55,965 rows
13. school-board-gop-2015-2026.csv — 25,834 rows
14. governor-2015-2026.csv — 96,093 rows (USE THIS — replaces old 4,287-row file)
15. council-city-town-gop-2015-2026.csv — 51,425 rows

SKIP: alderman-gop-100-counties-2015-2026.csv (78 rows)
DO NOT LOAD: AG, Supreme/Appeals, Treasurer (partial county coverage — need re-pull)

---

## KEY DISCOVERIES THIS SESSION

### 1. FEC $200 Threshold
Federal races require itemization only at $200+. NC state races (NCSBE) disclose every donor regardless of amount. NCSBE is actually MORE complete than FEC for donor identification.

### 2. Trump Dominance
Trump NC individual donors: 694,192 rows, $51.8M across 2016-2026. Compare to all NC Senate Republican candidates combined: 39,160 rows, $22.5M. Trump = 18x more NC individual donors than entire Senate field.

Average donation fell from $169 (2016) to $54 (2022-2026) — mass mobilization of small-dollar donors.

### 3. McCrory's Federal Committee
Pat McCrory's 2016 governor fundraising used federal committee FED-085NFW-C-001 (THE PAT MCCRORY COMMITTEE). His NCSBE state file has near-zero data. His major donor file is in FEC — separate pull needed.

### 4. Ted Budd House/Senate Same Committee
C00614776 was renamed from TED BUDD FOR CONGRESS to TED BUDD FOR SENATE. All his House AND Senate individual donor data (2016-2022) is in one committee. 11,149 rows, $5.6M captured in Senate batch.

### 5. NCSBE Search Gap Confirmed
County-by-county NCSBE search captures 5-16% of actual dollars vs bulk download files. Governor file: old search = 4,287 rows, $1.1M. New complete pull = 96,093 rows, $30M. The bulk download by office type is the only complete source.

---

## DATABASE STATE (end of session)

| Table | Rows | Status |
|-------|------|--------|
| public.contacts | 227,978 | ✅ |
| public.nc_boe_donations_raw | 338,223 | ⚠️ 11,676 duplicate hashes need cleanup before load |
| public.fec_donations | 2,591,933 | ✅ NC-only, clean, sub_id unique constraint added |
| public.nc_datatrust | 7,661,978 | ✅ SACRED |
| staging.nc_voters_fresh | 7,708,542 | ✅ DataTrust March 2026 |
| core.person_spine | 128,043 active | ✅ |

---

## INFRASTRUCTURE NOTES
- Hetzner Server 1: 5.9.99.109 (relay port 8080)
- GitHub: broyhill/BroyhillGOP
- Supabase: isbgjpnbocdkeslofota (us-east-1)
- DataTrust token expires: April 10, 2026
- FEC API key: ROTATE — old key posted in chat

---
*Recorded by BroyhillGOP-Claude (Perplexity) | April 6, 2026 2:19 AM EDT*
