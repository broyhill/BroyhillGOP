# NCBOE GOLD — pre-ingest plan (recovered)

**Source:** Spine donor analysis (2026-04-07 PDF) + Cursor session prioritization for loading **`/Users/Broyhill/Desktop/NCBOE DONORS GOLD`** (18 GOP-sliced CSVs on Desktop).  
**Related:** `sessions/NCBOE_FILE_MANIFEST.md` (20 office-type workspace files, Option A/B/C for raw reload).  
**Transcript:** [599a72ed-a97c-4301-94bc-fdb023e3ec1d](599a72ed-a97c-4301-94bc-fdb023e3ec1d)

This file exists so the plan is **in the repo**, not only in chat history.

---

## Intended wave-1 sequence (agreed direction)

1. Ingest **NCBOE GOLD only** (state/local GOP), not mixed with FEC Desktop files.  
2. `import_ncboe_raw.py` → `nc_boe_donations_raw` (idempotent via `pipeline.loaded_ncboe_files`).  
3. Normalize → match **`nc_voters`** / **`nc_datatrust`** → dedupe → roll transactions → spine.  
4. **FEC** = second wave, separate loaders and logic.

**Scripts:** `scripts/wave1_ingest_gold_ncboe.sh` (default `GOLD_DIR=~/Desktop/NCBOE DONORS GOLD`), then `scripts/wave1_normalize_ncboe.sh`.

---

## P0 — Fix or verify before (or immediately at start of) GOLD ingest

Affects safety, idempotency, and joinability once NCBOE hits normalized / spine-related tables.

| # | Issue | Action |
|---|--------|--------|
| 1 | `person_id` type chaos (bigint / uuid / integer / varchar) | Pick one canonical type; align staging, volunteers, any integer `person_id`. |
| 2 | `staging.spine_clusters` (and related merge staging) using **integer** for IDs | P0 if dedupe/merge runs after NCBOE; risk of overflow / broken dedup at scale. |
| 3 | `candidate_id` uuid vs text across `core.contribution_map` vs public FEC/donor tables | Standardize or document explicit casts before combined reporting. |
| 4 | ~103k zero / ~29k negative amounts | Define rules (memo vs real vs refund); consider `is_refund` / `transaction_type` before trusting aggregates. |

---

## P1 — Strongly recommended before relying on voter / DataTrust overlay

May not block first `import_ncboe_raw`, but hurts overlay quality.

| # | Issue | Action |
|---|--------|--------|
| 5 | `is_registered_voter` vs `voter_ncid` mismatch on spine | Refresh flag or define semantics after voter match. |
| 6 | `donor_voter_links` ~52% orphaned | Purge / re-match before trusting link-based metrics. |
| 7 | `core.fec_donation_person_map` empty; `fec_donations.person_id` unset | Gate any logic that assumes FEC is on spine until FEC wave. |

---

## P2 — Long-term spine quality (parallel or right after first GOLD batch)

| # | Topic |
|---|--------|
| 8 | Email ~9.1%, WinRed ~5.6% — contact completeness |
| 9 | 13 always-NULL columns on `person_spine` — prune or backfill |
| 10 | Name/address column differences — use views/mapping for matchers |
| 11 | Empty-string street/city → NULL normalization |
| 12 | Golden-record → spine mismatches if that ETL runs alongside GOLD |

---

## Explicitly **not** prerequisite to uploading GOLD GOP raw

- Democratic archive / party quarantine (already separated in audit narrative).  
- “NCBOE GOLD DONORS folder not in Drive” — canonical Desktop folder name is **`NCBOE DONORS GOLD`**.  
- FEC memo-row quirks — handle in FEC wave.

---

## Completion status (honest, as of repo + DB checks)

| Item | Status |
|------|--------|
| Plan articulated (P0/P1/P2) | Done in transcript; **this file** adds repo visibility. |
| Map each P0 to a **specific migration + script line** | **Not done** in that session (offered as next step). |
| Load all GOLD CSVs into Supabase via wave1 script | **Not verified complete** — `pipeline.loaded_ncboe_files` has shown **7** distinct prior loads with different filenames than the 20-row manifest; raw `dedup_key` / `voter_ncid` have been **0** in spot checks. |
| Ed decision Option A / B / C (`sessions/NCBOE_FILE_MANIFEST.md`) | **Open** — blocks intentional truncate/reload strategy. |
| 18 (Desktop GOLD) vs 20 (manifest table) | **Reconcile** filenames between Desktop folder and manifest before claiming “all files loaded.” |

---

## Next actions (when you want execution)

1. Confirm **Option A, B, or C** for `nc_boe_donations_raw` (manifest).  
2. Reconcile **18 Desktop CSVs** vs **20 manifest** rows (counts differ by packaging).  
3. Run `wave1_ingest_gold_ncboe.sh` (or `--dry-run` first), then normalize; verify `loaded_ncboe_files` and `dedup_key`.  
4. Optionally: ticket each P0 against a migration or script change.
