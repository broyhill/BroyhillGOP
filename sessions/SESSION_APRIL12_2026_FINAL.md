# SESSION TRANSCRIPT — April 12, 2026
## BroyhillGOP Platform — Perplexity (CEO) + Ed Broyhill + Cursor
### Duration: 1:18 PM – 4:53 PM EDT
### Written by: Perplexity at session close, April 12, 2026 4:53 PM EDT

---

## READ FIRST — Files to read at next session start (in order)
1. `sessions/SESSION_START_READ_ME_FIRST.md`
2. `sessions/COMPLETE_BUILD_TODO.md`
3. `sessions/DONOR_DEDUP_PIPELINE_V2.md`
4. `sessions/SESSION_APRIL12_2026.md` (the earlier version — mid-session notes)
5. This file (SESSION_APRIL12_2026_FINAL.md)

---

## WHAT WAS ACCOMPLISHED TODAY

### Phase A — DataTrust Voter File: COMPLETE (carried in from overnight)
- 7,727,637 rows in `core.datatrust_voter_nc` on new server 37.27.169.232
- 252 columns, primary key on `rnc_regid`, 15 indexes
- Broyhill canary verified: JAMES EDGAR BROYHILL, rnc_regid c45eeea9-663f-40e1-b0e7-a473baee794e, NCID BN94856, 525 N Hawthorne Rd Winston-Salem 27104, Republican
- Birthday note: DataTrust says June 21 — WRONG. Ed confirmed June 23, 1954.

### Phase B — Acxiom Restructure: IN PROGRESS at session close
- Original JSONB load: 7,655,593 rows in `core.acxiom_consumer_nc`
- Ed chose Option C: separate tables per data layer for 3,000-user production performance
- Script running in screen `acxrestructure` on 37.27.169.232
- `core.acxiom_ap_models`: ~675K rows loaded as of 3:39 PM, still loading
- `core.acxiom_ibe`: queued
- `core.acxiom_market_indices`: queued
- All tables join by `rnc_regid`
- Old JSONB table `core.acxiom_consumer_nc` to be dropped after restructure completes

### Phase C — RNC Fact Tables: IN PROGRESS at session close
- Absentee ballot file: 10,509,999 rows (8.2GB) downloading in screen `factpull`
- After absentee completes, script auto-pulls: VoterContacts, Volunteers, Organizations, DimElection, DimOrganization, DimTag
- All saved to /data/rnc/ as JSONL files

### Phase D — NCBOE Infrastructure: COMPLETE ✓
This is the big win of the afternoon. Full build + deploy verified.

**What Cursor built and pushed (commit fb1dbea4 on session-mar17-2026-clean):**

| File | Purpose |
|------|---------|
| `database/migrations/099_raw_ncboe_donations_gold_hetzner.sql` | `raw.ncboe_donations` table with typo columns preserved, SIC/NAICS columns, cluster_profile, is_unitemized, 12 indexes |
| `pipeline/ncboe_gold_csv_headers.py` | Single source of truth for exact NCBOE headers (typos preserved) |
| `pipeline/ncboe_name_parser.py` | NCBOE FIRST-order name parser with unit tests |
| `pipeline/address_number_extractor.py` | Numeric token extractor from both address lines |
| `pipeline/employer_normalizer.py` | Text cleanup + SIC/NAICS lookup against `employer_sic_master` |
| `pipeline/ncboe_normalize_pipeline.py` | CSV → norms; dry-run by default; `--apply` to INSERT |
| `pipeline/ncboe_internal_dedup.py` | Union-find Stage 1A+1B+light 1C; `cluster_profile` JSON; Stage 1D-1G as aggregates |
| `pipeline/db.py` | HETZNER_DB_URL → DATABASE_URL → SUPABASE_DB_URL priority |
| `scripts/hetzner_apply_099_ncboe.sh` | Applies migration 099 + creates /data/ncboe/gold |

**Verified on server 37.27.169.232:**
- `raw.ncboe_donations`: EXISTS, COUNT = 0 (clean — no data loaded)
- 12 indexes confirmed (11 secondary + primary key)
- Parser smoke test passed:
  - `ED BROYHILL` → first=ED, last=BROYHILL (NEVER EDWARD ✓)
  - `JAMES EDGAR 'ED' BROYHILL` → first=JAMES, middle=EDGAR, nickname=ED, last=BROYHILL ✓
  - `JAMES T BROYHILL JR` → first=JAMES, middle=T, last=BROYHILL, suffix=JR ✓
  - `DR JANE SMITH` → prefix=DR, first=JANE, last=SMITH ✓

---

## KEY DESIGN DECISIONS MADE TODAY

### Platform Hierarchy Rule (Ed's Law — non-negotiable)
Acxiom modeled scores are LAST RESORT. Priority order for every score:
1. Donation history (what they gave, to whom, how much) — REAL
2. Voting history (which primaries, turnout) — REAL
3. Party positions (officer, delegate, committee member) — REAL
4. Volunteer activity (events hosted, contacts made) — REAL
5. Acxiom modeled scores — only when 1-4 are empty

Every variable needs SOURCE ATTRIBUTION. Multi-source scores required in spine:
- `republican_score_acxiom` (modeled)
- `republican_score_datatrust` (CalcParty)
- `republican_score_donation` (computed from giving)
- `republican_score_voting` (computed from primary ballots)
- `republican_score_party` (computed from officer/delegate roles)
- `republican_score_composite` (weighted blend — what candidates see)

Ed's quote: "We are the Gold Standard with bad info. Nobody else has this data at all. Acxiom is the wrapping paper. Donation history is the truth."

### Acxiom Errors Found on Ed's Own Record
| Field | Acxiom Says | Reality |
|-------|-------------|---------|
| Birthday | June 21, 1954 | June 23, 1954 |
| Republican score (AP006784) | 74/100 | Should be 99-100 — he IS NC National Committeeman |
| Fundraising propensity (AP001722) | 6/20 | Has hosted 248 fundraisers |
| Political contributor (AP005098) | 3/20 | Top 20 donor in the state |
| Home value (AP000444) | $348,000 | $1,800,000 (purchase price $2,550,000) |
| Vehicles | 2016 Chrysler Town & Country | That's his father's van |
| Net worth | $199,000 | Not even close |

Ed's mother Louise Broyhill scores 100 on the Republican scale — but voted for Biden and Obama.

### NCBOE Schema Rules (exact — do not deviate)
- Column typos are intentional: `Transction Type`, `Date Occured` — match the file exactly
- Name field order: FIRST LAST (not LAST, FIRST like FEC)
- ED = EDGAR, never EDWARD. Ever.
- FEC name format is different: LAST, FIRST MIDDLE (split on first comma)

### Employer SIC Rule
- SIC/NAICS code is MORE stable than employer text
- ANVIL VENTURE GROUP, ANVIL VENTURES, ANVILE VENTURE → all map to one SIC code
- `employer_sic_master` has 62,100 mappings (text → code)
- Matching anchor: `last_name + SIC_code + city` → unique match even for common names
- Until `employer_sic_master` is loaded onto the new server, SIC columns stay NULL — text normalization still runs

### Lat/Long Rule
- NOT a primary match anchor
- 75% of major donors file from business address ≠ home address
- Use lat/long to CONFIRM a match already found by other means only

### Donors With No Address
- Track 2 donors (25+ transactions, no address) — never drop
- Pass 3: employer + last name + committee city
- Pass 5: committee loyalty fingerprint
- Pass 6: name variants from cluster

---

## INFRASTRUCTURE STATE — End of Session

### New Server: 37.27.169.232
| Item | Status |
|------|--------|
| OS | Ubuntu 24.04, 96 cores, 252GB RAM, 1.7TB free |
| PostgreSQL 16 | Running |
| `core.datatrust_voter_nc` | 7,727,637 rows — COMPLETE |
| `core.acxiom_ap_models` | Loading (~675K of 7.65M) — screen `acxrestructure` |
| `core.acxiom_ibe` | Queued after ap_models |
| `core.acxiom_market_indices` | Queued after ibe |
| `core.acxiom_consumer_nc` | OLD JSONB — drop after restructure |
| `/data/rnc/absentee.jsonl` | 10.5M rows — screen `factpull` |
| `/data/rnc/` (6 more fact tables) | Queued after absentee |
| `raw.ncboe_donations` | TABLE BUILT, 0 rows — waiting for GOLD files |
| Relay | Running on port 8080 — screen `relay` |
| GitHub branch | `session-mar17-2026-clean`, tip `fb1dbea4` |

### Supabase (isbgjpnbocdkeslofota)
| Item | Status |
|------|--------|
| `core.person_spine` | 74,407 active — canary passing |
| Broyhill canary | $352,416 (matches contribution_map) |
| `nc_boe_donations_raw` | 🔴 CONTAMINATED ~2.27M rows — needs TRUNCATE + reload to 338,223 |
| Status | Stable, do not touch this session |

### Screen Sessions on 37.27.169.232
- `relay` — BroyhillGOP relay on port 8080
- `factpull` — RNC fact table downloads
- `acxrestructure` — Acxiom Option C restructure

---

## WHAT CURSOR STILL NEEDS TO DO

Infrastructure is built. Waiting for Ed to transfer files. When Ed is back:

1. Ed transfers 18 GOLD NCBOE files to `/data/ncboe/gold/` on 37.27.169.232
2. Dry-run first file: `python3 -m pipeline.ncboe_normalize_pipeline --file /data/ncboe/gold/[file].csv`
3. Ed reviews dry-run output
4. After Ed says "I authorize this action": add `--apply` flag
5. Repeat for all 18 files
6. After all 18 loaded: `python3 -m pipeline.ncboe_internal_dedup`

---

## ACXIOM VARIABLE STATUS
- V3 report: 1,170 non-null variables, 928 defined, 242 still undefined
- 242 undefined are IBE codes not in any of Danny Peletski's workbooks
- Action needed: ask Danny for full IBE data dictionary for the 242 undefined codes
- Danny's email: DPeletski@gop.com

---

## SECURITY NOTE
Server passwords appeared in plaintext in session instructions today. Rotate when convenient:
- `root@37.27.169.232` password
- Supabase password (db.isbgjpnbocdkeslofota.supabase.co)

---

*Written by Perplexity (CEO) at Ed Broyhill's direction, April 12, 2026 4:53 PM EDT*
*Ed is traveling — back ~8 PM EDT. Do not modify without Ed's authorization.*
