# SESSION-STATE.md
## BroyhillGOP Database — Session March 23, 2026
### Maintained by: Perplexity AI (lead architect)

---

## VERIFIED STATE AS OF 9:44 PM EDT, March 23, 2026

### Row Counts — Confirmed via live COUNT(*)

| Table | Rows | Notes |
|-------|------|-------|
| `public.nc_boe_donations_raw` | 625,897 | Full load — all 3 March 8 files |
| `public.nc_boe_donations_raw` (with rncid) | 338,720 | 54.1% matched — 287,177 still need fuzzy |
| `public.fec_donations` | 2,597,935 | Full load intact |
| `public.fec_donations` (non-memo, linked) | 1,612,466 | 89.8% linked to core.person_spine |
| `public.winred_donors` | 194,279 | 123,317 have voter_ncid |
| `public.fec_committees` | 35,521 | ✅ Promoted from staging this session |
| `public.fec_committee_master_staging` | 35,521 | Staging intact |
| `public.rnc_voter_staging` | 7,708,542 | Full RNC NC file, downloaded Mar 22 |
| `public.rncid_resolution_queue` | 150,755 | 69,490 resolved; 81,265 still unresolved |
| `public.donor_contribution_map` | 795,345 | BOE golden record map |
| `public.donor_voter_links` | 309,112 | ncid+rncid linkage table |
| `public.golden_record_clusters` | 3 | Clustering never ran — needs rebuild |
| `public.nc_datatrust` | 7,655,593 | Full DataTrust NC pull — intact |
| `core.person_spine` | 337,053 | Unified donor identity spine |
| `core.person_spine` (voter_rncid populated) | 189,527 | 56.2% have RNCID |
| `core.contribution_map` | 4,006,356 | FEC: 2.33M, FEC party: 1.39M, BOE: 288K |
| `core.fec_donation_person_map` | 1,612,466 | Rebuilt this session |
| `core.golden_record_person_map` | 60,866 | BOE→spine bridge |
| `core.identity_clusters` | 32,156 | |
| `staging.spine_merge_candidates` | 23,023 | |
| `staging.spine_clusters` | 315,959 | |

---

## WHAT RAN THIS SESSION (Confirmed Successful)

| Fix | What it did | Result |
|-----|------------|--------|
| Fix 1 | Promoted fec_committee_master_staging → fec_committees | 60 → **35,521** ✅ |
| Fix 2 | Backfill voter_rncid on spine from rnc_voter_staging via voter_ncid | +1,205 new RNCIDs |
| Fix 3 | Stamp voter_rncid from donor_voter_links via ncid | +48 new RNCIDs |
| Fix 4 | Stamp voter_rncid from BOE via voter_ncid | no net new (already covered) |
| Fix 5 | Exact name+zip match on rncid_resolution_queue | **69,490 of 150,755 resolved** |
| Fix 6 | Write resolved queue → nc_boe_donations_raw | 0 new (source_id match issue — see below) |
| Index | GiST trigram indexes on rnc_voter_staging.norm_last + norm_first | Built ✅ |
| Fix 10 | Rebuilt core.fec_donation_person_map from fec_donations.person_id | **1,612,466 rows** ✅ |

---

## WHAT IS QUEUED (Not Yet Executed — In migration 086)

Run `database/migrations/086_completion_fixes.sql` in Supabase SQL editor, ONE BLOCK AT A TIME:

| Block | What it does | Expected outcome |
|-------|-------------|-----------------|
| A | Add is_donor column + populate from contribution_map | ~200K spine records flagged |
| B | Recalculate spine aggregates (total_contributed, count, dates) | All 200K spine donors get $$ totals |
| C | Insert WinRed donors missing from spine | ~71K new spine rows (123K winred have ncid, ~52K already on spine) |
| D | Add WinRed to core.contribution_map | ~123K new entries |
| E | Stamp person_master.rnc_rncid from spine.voter_rncid | ~189K person_master rows updated |
| F | Stamp person_master.is_donor from spine | ~200K person_master rows updated |
| G | Write resolved queue RNCIDs → nc_boe_donations_raw | Expected ~69K new rncid values |
| H | Stamp new BOE RNCIDs onto spine | Expected ~few thousand new spine RNCIDs |
| I | Batched fuzzy pass (20K rows at a time, threshold 0.82) | Resolves portion of 81,265 remaining |
| J | Final state audit | Report all final numbers |

---

## KNOWN ISSUES / WHAT'S STILL BROKEN

### 1. rncid_resolution_queue write-back to BOE (Fix 6 returned 0 rows)
**Root cause:** The queue's `source_id` values (BOE row IDs in the 6M range) didn't match unmatched BOE rows because those rows already had rncid populated from a different path. The 69,490 resolved queue entries need investigation — either they ARE the 338K already matched, or there's an ID mismatch. Block G in migration 086 will clarify.

### 2. Fuzzy pass times out in Supabase SQL editor
**Root cause:** Even with GiST indexes, the 81K × 7.7M similarity join exceeds the 2-minute UI timeout. Must run in batches of 20K or via direct psql connection.
**Workaround:** Run Block I from migration 086 four times (each run processes 20K rows — 4 runs covers all 81K).

### 3. golden_record_clusters has only 3 rows
**Root cause:** Clustering was attempted (March 17 timestamp on the 3 rows), stopped after 3 records. The full clustering job needs to run using `match_key_v2` from core.person_spine.
**Impact:** BOE donations linked via golden_record_id (290,931 rows) can't resolve to spine person_ids until clustering runs.

### 4. core.person_spine is 337K rows, not the full 7.66M voter universe
**Root cause:** core.person_spine was built from DONOR records only — it's not the voter file. public.person_master (7.66M) is the voter+DataTrust spine. core.person_spine is the DONOR identity spine. These are intentionally different.
**Impact:** None — this is by design. Donors who are also voters link via voter_ncid.

### 5. WinRed rncid column is empty (0 rows)
**Root cause:** WinRed donors were matched to voters via voter_ncid but the rncid was never stamped back onto winred_donors from rnc_voter_staging.
**Fix:** After Block H, run:
```sql
UPDATE public.winred_donors wd
SET rncid = rvs.rncid::text
FROM public.rnc_voter_staging rvs
WHERE rvs.state_voter_id = wd.voter_ncid
  AND wd.rncid IS NULL;
```

---

## SCHEMA CORRECTIONS vs. GUARDRAILS (Update CLAUDE_GUARDRAILS.md)

The guardrails document has one error that must be corrected:
- **WRONG:** `core.person_spine.datatrust_rncid` — this column does NOT exist
- **CORRECT:** `core.person_spine.voter_rncid` — this is the actual RNCID column name on the spine

All references to `datatrust_rncid` in the guardrails should be `voter_rncid`.

---

## NEXT SESSION — START HERE

1. **Run migration 086 Blocks A through J** in Supabase SQL editor
2. **Run Block I four times** to process all 81K fuzzy queue records
3. **Run WinRed rncid backfill** (query above in Known Issues #5)
4. **Rebuild golden_record_clusters** — this is the biggest remaining gap
5. **Connect nc_datatrust to core.person_spine** via voter_rncid = nc_datatrust.rnc_regid

---

## REFERENCE: KEY CONNECTION PATHS

```
nc_boe_donations_raw.voter_ncid  →  core.person_spine.voter_ncid  (BOE donor → spine)
nc_boe_donations_raw.rncid       →  nc_datatrust.rnc_regid         (BOE donor → DataTrust)
core.person_spine.voter_rncid    →  nc_datatrust.rnc_regid         (spine → DataTrust)
core.person_spine.voter_ncid     →  public.person_master.ncvoter_ncid (spine → voter master)
public.person_master.ncvoter_ncid = public.nc_datatrust.statevoterid   (voter master → DataTrust)
fec_donations.person_id          →  core.person_spine.person_id    (FEC → spine)
```

---
*Updated by Perplexity AI — March 23, 2026 9:44 PM EDT*
