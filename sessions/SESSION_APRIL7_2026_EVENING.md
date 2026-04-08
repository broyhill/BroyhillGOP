# SESSION — April 7, 2026 Evening
**BroyhillGOP-Claude | Recorded: April 7, 2026 ~10:20 PM EDT**
**Authority: Ed Broyhill | NC National Committeeman**

---

## WHAT HAPPENED THIS SESSION

### Morning Session — Agent Failure (DO NOT REPEAT)
The morning Perplexity session did NOT read SESSION_START_READ_ME_FIRST.md first. It:
1. Generated the PDF audit report (BroyhillGOP_Spine_Donor_Analysis_2026-04-07.pdf) — that part was valid
2. Loaded wrong old NCBOE files from the Cursor workspace into `public.nc_boe_donations_raw` — files contained committee-to-committee transactions, PACs, NCGOP affiliate committee donations (not individual donors)
3. This contaminated the sacred raw table
4. DataTrust ID column mismatches (`firstname`/`lastname` no-underscore vs `first_name`/`last_name`) caused NULL joins — the voter sync was broken on those contaminated rows

**Ed caught this, audited everything, cleaned it up, and restarted correctly.**

### GitHub — Fixed
- 29 open secret scanning alerts cleared (Google Docs embedded keys, AWS temp keys, Supabase key)
- Google Docs assets folder added to `.gitignore` and removed from tracking
- `session-mar17-2026` branch had commit `61ba269` (secrets in `docs/Perplexity-March-21.md`) blocking push
- Cursor force-reset `session-mar17-2026` to `origin/main` tip (`4bd0246`) — push succeeded
- `session-mar17-2026-clean` also exists at same tip + new commit (`8b84c06`)
- 0 open secret scanning alerts as of end of session

### NCBOE GOLD Load — IN PROGRESS
The correct load set is **18 CSVs from `/Users/Broyhill/Desktop/NCBOE DONORS GOLD`**.
These are individual-donor-only, Republican NC candidates/committees, all 100 counties, by office type, 2015–2026.

**Status as of 10:19 PM EDT:**

| File | Rows in raw | Registered in pipeline |
|---|---|---|
| 2015-2025-lt-governor.csv | 31,793 | ✅ |
| 2015-2026-Mayors.csv | 18,281 | ✅ |
| 2015-2026-NC-Council-of-state.csv | 96,363 | loading |
| 2015-2026-supreme-court-appeals-.csv | 75,000 | loading |
| Files 5–18 | TBD | pending |

Total in `nc_boe_donations_raw` as of 10:19 PM: ~221,437 rows across 4 files. 14 files still to load.

**DO NOT run normalization or any downstream process until all 18 files are loaded and pipeline.loaded_ncboe_files shows all 18 registered.**

### MAJOR NEWS — DataTrust Full Consumer File
**Zack Imel** (RNC Digital Director — replaces Danny Gustafson) agreed to provide the full **2,200-variable DataTrust dump** to BroyhillGOP.
- Schema decision is URGENT: do NOT add 2,200 scalar columns to `nc_datatrust` — use jsonb chunks or domain-split tables
- `rnc_regid` and `rncid` population on the spine becomes highest-value enrichment once the file arrives
- Phase 1F (DataTrust full consumer) from WAVE1_CONSOLIDATED_PLAN_STATUS.md is now active — design schema before file arrives

---

## CURRENT DATABASE STATE (April 7, 2026 ~10:20 PM EDT)

| Table | Rows | Status |
|---|---|---|
| `core.person_spine` active | 74,407 | ✅ Clean — untouched |
| `core.person_spine` inactive | 125,976 | ✅ |
| `core.contribution_map` | 2,960,201 | ✅ Zero D-flag — untouched |
| `public.fec_donations` | 779,182 | ✅ 14 clean files |
| `public.nc_boe_donations_raw` | ~221,437 (growing) | ⚠️ GOLD LOAD IN PROGRESS |
| `norm.nc_boe_donations` | 581,741 | ⚠️ STALE — built from old files, do not trust until renormalized |
| `norm.fec_individual` | 2,597,125 | ✅ |
| `public.nc_datatrust` | 7,661,978 | ✅ SACRED |
| `archive.democratic_candidate_donor_records` | 906,609 | ✅ |
| `audit.nc_boe_donations_raw_pre_reload_20260330` | 625,897 | ✅ Backup of pre-GOLD raw data |

**CRITICAL:** `norm.nc_boe_donations` (581,741 rows) was built from the old 2-file load. It is NOT consistent with the new GOLD raw data. Do not use for reporting until renormalized after all 18 files load.

---

## WAVE 1 CONSOLIDATED PLAN — PHASE STATUS

Based on Cursor's plan (sessions/WAVE1_CONSOLIDATED_PLAN_STATUS.md):

| Phase | Status | Notes |
|---|---|---|
| Phase 0 — Lock scope | ✅ Done | 18 GOLD files, individual-only, GOP NC, ncid + rnc_regid keys |
| Phase 1 — Voter/DataTrust foundation | ⚠️ Pending | 1A–1E not yet run; start in parallel with Phase 2 |
| Phase 2 — GOLD ingest | 🔄 IN PROGRESS | 4/18 files loaded |
| Phase 3 — Match/dedup/rollup/spine | ⏸️ Blocked | Waits on Phase 1 exit criteria + all 18 files loaded |
| Phase 4 — FEC | ⏸️ Later | After Phase 3 stable |
| Phase 5 — Hardening | ⏸️ Later | |

**Phase 1 can start NOW in parallel with the file load.** Safe read-only work:
- 1A: Record voter_file_import_date / datatrust_import_date
- 1B: Map nc_voters status vocab → DataTrust A/I canonical layer
- 1C: Type alignment rules (birth_year/age across 3 sources)
- 1D: Recompute is_registered_voter (22K flag vs 129K with voter_ncid gap)
- 1E: Quarantine 114K orphaned donor_voter_links

---

## SCHEMA FIXES — MUST RUN BEFORE PHASE 3

These are blocking issues from the morning audit that must be resolved before any merge jobs run:

1. `staging.spine_clusters` integer → bigint (overflow at 2.1B)
2. `candidate_id` uuid → text (core.contribution_map vs public FEC tables)
3. `person_id` type standardization (staging/volunteer tables — integer → bigint)

---

## ONE OPEN DECISION BEFORE NORMALIZATION RUNS

**Zero-amount (103K rows) and negative-amount (29K rows) rule:**
Tag as memo/refund, or exclude? This rule must be written down and agreed before the normalizer runs. Wrong choice = wrong aggregates on the spine.

---

## KEY CONTACTS UPDATE

| Role | Person | Contact |
|---|---|---|
| RNC Digital Director / DataTrust | **Zack Imel** | (direct — Danny Gustafson no longer there) |
| NC National Committeeman | Ed Broyhill | ed.broyhill@gmail.com |

---

## CURSOR HANDOFF NOTE (verbatim, for next Perplexity session)

> Read: SESSION_START_READ_ME_FIRST.md, MASTER_FILE_MANIFEST.md (NCBOE = 18), PERPLEXITY_HIGHLIGHTS.md, WAVE1_CONSOLIDATED_PLAN_STATUS.md (has stray ** markdown typos — interpret carefully).
> Reconcile DB to Desktop: SELECT COUNT(*), source_file FROM pipeline.loaded_ncboe_files + nc_boe_donations_raw vs the 18 filenames.
> Do NOT assume spine / norm / contribution_map are consistent with new raw until normalize + downstream QA are run and checked.
> If the morning audit PDF is needed — ask Ed to drop it into sessions/ or paste it; it is not in the repo.

---

*Updated by Perplexity-Claude | April 7, 2026 10:20 PM EDT*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
