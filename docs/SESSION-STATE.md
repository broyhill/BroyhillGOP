# SESSION-STATE.md — AUTHORITATIVE REFRESH
## BroyhillGOP Database — March 31, 2026 1:41 PM EDT
## Source: Live Cursor audit + Perplexity REST verification
## Maintained by: Perplexity AI

---

## VERIFIED LIVE ROW COUNTS (Cursor audit, March 31 2026)

### Voter / Identity Foundation
| Table | Rows | Status |
|-------|------|--------|
| `public.person_master` | **7,728,689** | ✅ Full voter+DataTrust master |
| `public.nc_datatrust` | **7,661,978** | ✅ Full DataTrust NC pull |
| `public.rnc_voter_staging` | **7,708,268** | ✅ RNC voter file |
| `public.rnc_scores_fresh` | **7,708,765** | ✅ RNC scores loaded |
| `public.nc_voters` | **0** | ⚠️ Empty — deprecated or load failed |
| `public.rnc_voter_core` | **0** | ⚠️ Empty — deprecated or load failed |

### Donor / Contact Layer
| Table | Rows | Status |
|-------|------|--------|
| `public.contacts` | **310,867** | ✅ fix_08 complete — unified contact hub |
| `public.person_source_links` | **2,055,703** | ✅ Source attribution links |
| `public.donor_voter_links` | **220,964** | ✅ Donor→voter linkage |
| `public.person_contacts` | **42,179** | ✅ Supplemental contact info |
| `public.winred_donors` | **194,278** | ✅ WinRed loaded |
| `public.rncid_resolution_queue` | **150,755** | Partially resolved |

### Contribution / Finance Layer
| Table | Rows | Status |
|-------|------|--------|
| `public.fec_party_committee_donations` | **1,746,126** | ✅ |
| `public.donor_contribution_map` | **789,771** | ✅ |
| `public.nc_boe_donations_raw` | **282,096** | 🔴 WRONG FILES — needs reload |
| `public.nc_boe_pac_committee_raw` | **57,617** | ✅ |
| `public.ncgop_god_contributions` | **23,026** | ✅ |
| `public.fec_committee_transfers` | **107,485** | ✅ |
| `public.fec_committees` | **35,521** | ✅ |

### Classification / Intelligence Layer
| Table | Rows | Status |
|-------|------|--------|
| `public.committee_party_map` | **19,982** | ✅ fix_10 complete, 0 NULL flags |
| `public.gop_fec_committee_whitelist` | **25** | ✅ fix_09 |
| `public.gop_fec_candidate_whitelist` | **137** | ✅ fix_09 |
| `public.ncsbe_candidates` | **55,985** | ✅ |
| `public.donor_candidate_scores` | **142,288** | ✅ |

---

## FIXES COMPLETED SINCE MARCH 28 (Cursor execution)

| Fix | What it did | Status |
|-----|-------------|--------|
| `fix_08` | Populated `public.contacts` + `person_source_links` (rncid, name+zip, address match) — 310,867 contacts | ✅ Complete |
| `fix_08b` | Restricted `v_individual_donations` to R/PAC/UNKNOWN; archived D-candidate donors | ✅ Complete |
| `fix_09` | Loaded GOP FEC committee + candidate whitelists; candidate attribution in `contribution_map` | ✅ Complete |
| `fix_10` v3 | `party_flag` stamped on `contribution_map`; spine R totals = R+PAC; 0 NULL flags | ✅ Complete |
| `fix_11` | (Per Claude's GUARDRAILS commit) — details TBD | ✅ Per commit |
| `fix_12` | Queued per SESSION-STATE commit | ⏳ Queued |

---

## KNOWN GAPS / ACTIVE ISSUES

### 🔴 CRITICAL
1. **`nc_boe_donations_raw` has wrong files** (282,096 rows, mixed types)
   - Should be: ~338,223 rows, Individual + General only
   - Correct files: `2015-2019-ncboe.csv` (95,967 rows) + `2020-2026-ncboe.csv` (242,256 rows)
   - IMPORTANT: Cursor notes these files contain committee/party/PAC rows — need staging classification before loading to donor tables
   - Status: Awaiting Cursor classification decision before reload

2. **`staging.nc_voters_fresh` may be 0 rows**
   - 9M row `\copy` from Hetzner may not have completed
   - Must verify: `SELECT COUNT(*) FROM staging.nc_voters_fresh;`
   - `public.nc_voters` intentionally left untouched

3. **`core.contact_spine_bridge`** — row count unknown (core schema, needs psql)

### 🟠 HIGH
4. **Email gap is universal** — `person_master.email` = 0 for ALL parties
   - Only ~4,400 emails in `person_contacts` (supplemental)
   - Fix: email append service needed (Acxiom already overlaid in DataTrust but not extracted)

5. **5,069 orphaned long-form party codes** (DEM/UNA/REP/LIB)
   - All from nc_voters, all have `datatrust_rncid = NULL`
   - Most have `street = 'REMOVED'` — confidential/judicial voters
   - Fix: normalize to single-letter codes, merge where possible

6. **`contribution_map.candidate_id` partially filled**
   - Large share still NULL — fill rate varies by source_system
   - Rule: do NOT assign GOP UUIDs from bulk FEC rows including national Democrats

### 🟡 MEDIUM
7. **nc_voters = 0, rnc_voter_core = 0**
   - Unclear if intentionally deprecated in favor of `person_master`
   - Needs clarification before any work touching voter file

8. **4,903 records with `street = 'REMOVED'`**
   - Confidential voters (judicial officers, etc.) — no phone/email, unusable for outreach
   - Should be flagged `is_confidential = true` and excluded from outreach lists

9. **58 records with missing first names** — name parsing failures, needs manual review

---

## PARTY DISTRIBUTION — person_master

| Party | Records | % |
|-------|---------|---|
| U (Unaffiliated) | 2,976,559 | 38.5% |
| R (Republican) | 2,315,067 | 30.0% |
| D (Democrat) | 2,312,991 | 29.9% |
| T (?) | 46,608 | 0.6% |
| G (Green) | 4,368 | 0.1% |
| REP/UNA/DEM/LIB (orphaned) | 5,069 | <0.1% |

**R + U reachable universe: ~5,291,626**

---

## ARCHITECTURE DECISIONS (confirmed)

- `public.contacts` = unified contact hub (NOT person_master)
- `core.person_spine` = donor identity spine (junction, not denormalized)
- `core.contact_spine_bridge` = contacts ↔ person_spine junction
- `public.nc_voters` = unchanged by design (sacred)
- `public.person_master` = voter + DataTrust master (sacred)
- NC BOE CSVs = NOT pure individual donor files — contain committee/party/PAC rows; must classify in staging first
- Cursor lane: migrations + core junction tables (when authorized)
- Claude lane: staging-only proposals unless Ed explicitly approves production writes
- **Destructive DELETE/TRUNCATE requires explicit "I authorize this action" from Ed**

---

## THREE-AGENT ROLES (clarified March 31)

| Agent | Role | DB Access |
|-------|------|-----------|
| **Cursor** | Direct execution, Mac + Hetzner psql, local file access | Direct psql port 5432 |
| **Claude** | Server-side scripts, Hetzner execution, long-running jobs | Via Hetzner psql |
| **Perplexity** | Architecture, research, coordination, GitHub, relay | REST API only (times out on large tables) |

---

## NEXT STEPS — PRIORITY ORDER

1. **Verify `staging.nc_voters_fresh`** — `SELECT COUNT(*) FROM staging.nc_voters_fresh;` via psql
2. **Confirm `core.contact_spine_bridge`** row count via psql
3. **Confirm `contribution_map.candidate_id`** fill rate by source_system via psql
4. **NC BOE reload decision** — Cursor to classify CSV row types in staging before any reload
5. **Email enrichment strategy** — DataTrust has Acxiom overlay but email not extracted to person_master
6. **Normalize 5,069 orphaned party code records**
7. **Begin Phase 1-7 implementation** (new architecture schemas from overnight session)

---

*Updated: Perplexity AI — March 31, 2026 1:41 PM EDT*
*Source: Cursor live audit + Perplexity REST verification*
*Supersedes all prior SESSION-STATE entries*
