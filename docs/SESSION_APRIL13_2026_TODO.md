# BroyhillGOP — Master TODO & Status
## Updated: April 13, 2026 1:30 AM EDT
## Author: Perplexity Computer for Ed Broyhill

---

## SESSION SUMMARY — April 12-13, 2026 (Night Session)

### COMPLETED THIS SESSION

1. **NCBOE Internal Dedup — DONE AND APPLIED**
   - Built `ncboe_dedup_v2.py` (946 lines Python, Union-Find)
   - 7 stages: 1A-1G, 1,673,088 total merges
   - 2,431,198 rows → 758,110 clusters (677,335 singletons, 80,775 multi-row)
   - Fixed 1D spouse-merge bug: first-name compatibility guard + rnc_regid conflict check
   - Fixed 1G cross-zip: last+first+employer across zips + last+first+addr_num across zips
   - Applied with `--apply --propagate-ids`

2. **Dark Donor Rescue — DONE**
   - 193,868 previously-dark donors now have rnc_regid via cluster propagation
   - Coverage: 45.2% → 53.2% (1,099,201 → 1,293,069 rows with rnc_regid)
   - `dt_match_method = 'cluster_propagation'` for audit trail

3. **Household Linkage — DONE**
   - 58,442 total households, 4,459 with 2+ donor clusters
   - 9,089 clusters linked across households
   - Each cluster_profile has household_id, household_total, household_cluster_ids
   - Ed + Melanie linked at $1,385,696.27 household total

4. **Ed Broyhill Canary — VERIFIED CORRECT**
   - Cluster 372171: ED/EDGAR/J/JAMES, 627 rows, $1,318,672.04
   - Melanie: separate cluster 372197, $67,024.23, linked via household
   - Louise: separate cluster, own dt_house_hold_id 636696
   - Senator's donations: merged into Ed's cluster per Ed's instruction

5. **Cursor Briefing Document — DONE**
   - `CURSOR_BRIEFING_NCBOE_DEDUP_GROUNDWORK.md` — 759 lines, 15 sections
   - Converted to 26-page `.docx` with full formatting
   - Both versions uploaded to `/opt/broyhillgop/sessions/`
   - Pushed to GitHub `session-mar17-2026-clean` (commit `80e33f3`)

6. **GitHub Push — DONE**
   - `ncboe_dedup_v2.py` + Cursor briefing pushed
   - Branch: `session-mar17-2026-clean`

---

## WHAT'S STILL RUNNING

| Process | Screen | Status | Expected |
|---------|--------|--------|----------|
| Acxiom IBE load | `acxrestructure` | Running since Apr 12 | 4,450,000 rows loaded so far, target ~7.6M |
| Relay service | `relay` | Running since Apr 11 | Stable |

**Check IBE progress:**
```bash
screen -r acxrestructure
# or:
PGPASSWORD='${PG_PASSWORD}' psql -h 127.0.0.1 -U postgres -d postgres -c "SELECT count(*) FROM core.acxiom_ibe;"
```

---

## NEXT STEPS — PRIORITY ORDER

### Phase 1: Immediate (Cursor can start these)

| # | Task | Blocked By | Notes |
|---|------|------------|-------|
| 1 | **Verify Acxiom IBE load completes** | Time (still running) | Confirm ~7.6M rows, then safe to query |
| 2 | **Load employer_sic_master** | Need source file location | 62,100 mappings — table schema exists, 0 rows. Check if dump exists on Supabase or Ed's laptop |
| 3 | **Merge session branch to main** | None | `session-mar17-2026-clean` has all the work; `main` is behind |

### Phase 2: Normalization (after SIC master loaded)

| # | Task | Blocked By | Notes |
|---|------|------------|-------|
| 4 | **SIC-based employer normalization** | employer_sic_master data | Build phase2_normalize.py to update norm_employer + populate employer_sic_code/employer_naics_code |
| 5 | **Update cluster profiles** | Step 4 | Re-run profile builder only (NOT dedup) to update JSONB with normalized employers |

### Phase 3: Stage 2 — Voter File Matching (HIGHEST VALUE)

| # | Task | Blocked By | Notes |
|---|------|------------|-------|
| 6 | **Build Stage 2 matching script** | None — can start now | Match 758,110 clusters to core.datatrust_voter_nc (7.7M voters) |
| | Pass 1: DOB + Sex + Last + Zip | | Top select — run first |
| | Pass 2: Address number + Last + Zip | | Any addr_num from cluster vs reg_house_num |
| | Pass 3: Employer + Last + City | | Catches 75% of major donors (business address) |
| | Pass 4: FEC cross-reference | FEC data needed | Two govt sources agreeing |
| | Pass 5: Committee loyalty fingerprint | | 3+ same committees = identity proof |
| | Pass 6: Name variants + Last + City | | All first names from cluster |
| | Pass 7: Geocode proximity | reg_latitude/reg_longitude | 100m radius |
| | Pass 8: Household matching | | If one member matched, check others |
| **Target:** resolve remaining 46.8% dark donors (1,138,129 rows) |

### Phase 4: Enrichment

| # | Task | Blocked By | Notes |
|---|------|------------|-------|
| 7 | **Donor enrichment view** | Stage 2 complete | JOIN donations → datatrust → acxiom_ap_models → acxiom_ibe via rnc_regid |
| 8 | **Microsegmentation tagging** | employer_sic_master | Tag donors into SIC/NAICS microsegments |
| 9 | **Honorific assignment** | DataTrust fields | Title hierarchy per DONOR_DEDUP_PIPELINE_V2.md |

### Phase 5: Frontend

| # | Task | Blocked By | Notes |
|---|------|------------|-------|
| 10 | **Donor profile pages** | Enrichment view | Individual view with cluster_profile data |
| 11 | **Household view** | Household linkage (done) | Combined family giving |
| 12 | **Search/filter UI** | Profile pages | By employer, committee, district, amount, date |

---

## PARKED — NOT YET STARTED

- [ ] Danny Peletski: IBE data dictionary for 242 undefined codes (DPeletski@gop.com)
- [ ] Supabase nc_boe_donations_raw recovery (contaminated ~2.27M rows, need TRUNCATE + reload 338,223 sacred rows)
- [ ] FEC API key registration (DEMO_KEY rate limit)
- [ ] NC donors to Club for Growth / NRA / AFP (blocked on FEC key)
- [ ] ms_* microsegment table population (blocked on PAC research)
- [ ] WinRed phone/email backfill for 94K contacts
- [ ] Drop old core.acxiom_consumer_nc (89 GB) after IBE load confirmed complete
- [ ] Security: rotate root password + Supabase password (appeared in plaintext)

---

## DATABASE STATE — April 13, 2026 1:30 AM

| Table | Rows | Size | Status |
|-------|------|------|--------|
| core.acxiom_consumer_nc | 7,655,593 | 89 GB | Loaded (may be droppable after IBE confirms) |
| core.acxiom_ibe | ~4,450,000 | 18 GB | **STILL LOADING** — 911 columns |
| core.acxiom_ap_models | 7,655,593 | 16 GB | Loaded — ~420 columns |
| core.datatrust_voter_nc | 7,727,637 | 12 GB | Loaded — 252 columns |
| raw.ncboe_donations | 2,431,198 | 5.3 GB | **DEDUP APPLIED** — 58 columns, 758K clusters |
| core.acxiom_market_indices | 0 | 16 KB | Empty — schema only |
| donor_intelligence.employer_sic_master | 0 | 32 KB | **EMPTY** — 6 cols, needs data |

**Disk:** 222 GB used / 1.8 TB (14%)

---

## KEY FILES

| File | Location | Purpose |
|------|----------|---------|
| ncboe_dedup_v2.py | /opt/broyhillgop/ + GitHub | **PRODUCTION** dedup script — DO NOT MODIFY |
| DONOR_DEDUP_PIPELINE_V2.md | /opt/broyhillgop/sessions/ + GitHub | Canonical dedup plan — the Bible |
| CURSOR_BRIEFING_NCBOE_DEDUP_GROUNDWORK.md | /opt/broyhillgop/sessions/ + GitHub | Full Cursor briefing (759 lines) |
| CURSOR_BRIEFING_NCBOE_DEDUP_GROUNDWORK.docx | /opt/broyhillgop/sessions/ | Same briefing as Word doc (26 pages) |
| /tmp/ncboe_dedup_v2.log | Server only | Apply run log with full stats |

---

## TECHNICAL REFERENCE

| Item | Value |
|------|-------|
| Hetzner server | 37.27.169.232 |
| Root password | ${PG_PASSWORD_RETIRED_20260417} |
| PostgreSQL | postgresql://postgres:${PG_PASSWORD_URLENCODED}@127.0.0.1:5432/postgres |
| Supabase project | isbgjpnbocdkeslofota |
| GitHub repo | broyhill/BroyhillGOP |
| GitHub branch | session-mar17-2026-clean (tip: 80e33f3) |
| Relay | 37.27.169.232:8080, key: bgop-relay-k9x2mP8vQnJwT4rL |
| Danny Peletski | DPeletski@gop.com |
| Zack Imel | ZImel@gop.com, 270-799-0923 |

---

*Written by Perplexity Computer | April 13, 2026 1:30 AM EDT*
*Ed Broyhill — NC Republican National Committeeman | ed.broyhill@gmail.com*
*Do not modify the dedup plan or script without Ed's authorization.*
