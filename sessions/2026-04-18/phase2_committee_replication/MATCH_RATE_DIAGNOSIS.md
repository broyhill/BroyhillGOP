# `committee.boe_donation_candidate_map` — 99.67% vs 73.91% diagnosed

**Date:** 2026-04-18 18:25 EDT
**Triggered by:** Phase 2 replication verify showing 249,957 / 338,213 = 73.91%, vs April 1 Cursor audit's 99.67%.
**Status:** Not a regression. Not an audit subset. Classification gap.

## What the numbers actually say

| Slice | Rows | Matched (`candidate_name IS NOT NULL`) | Match rate |
|---|---:|---:|---:|
| `partisan_flag = 'R'` | 249,957 | 249,957 | 100.00% |
| `partisan_flag = 'U'` | 88,256 | 0 | 0.00% |
| **Total** | **338,213** | **249,957** | **73.91%** |

Row total is *identical* to April 1 (338,213). Nothing grew, nothing shrank. The table was **reclassified** between April 1 and April 18: 88,256 rows flipped `R → U` and had `candidate_name` nulled in the same pass.

## What the "U" rows actually are

Top U committees by row count (sample of 25, accounting for ~30K of the 88K):

| Committee | Rows | Registry candidate_name | Real party |
|---|---:|---|---|
| COMMITTEE TO ELECT WAYNE COATS SHERIFF | 4,656 | WAYNE COATS SHERIFF | R |
| COMMITTEE TO ELECT BANKS HINCEMAN SHERIFF | 2,123 | BANKS HINCEMAN SHERIFF | R |
| DANNY BRITT FOR NC SENATE | 1,884 | DANNY BRITT | R |
| COMMITTEE TO ELECT SHERIFF JOHN W INGRAM V | 1,795 | SHERIFF JOHN W INGRAM V | R |
| COMMITTEE TO ELECT BRIAN M CHISM SHERIFF | 1,600 | BRIAN M CHISM SHERIFF | R |
| NEWBY FOR JUSTICE COMMITTEE | 1,398 | NEWBY FOR JUSTICE | R |
| TREY ALLEN FOR JUSTICE | 1,354 | CURTIS HUDSON ALLEN 3 | R |
| BISHOP FOR SENATE | 726 | JAMES DANIEL BISHOP | R |
| BERGER FOR JUSTICE | 701 | PHILIP BERGER JR | R |
| NEWTON FOR SENATE | 676 | PAUL ROBERT NEWTON | R |
| …etc | | | |

All 25 samples have a real `candidate_name` in `public.committee_registry` already. None are Unaffiliated. They are downballot R candidates (sheriff, DA, judicial, county house/senate).

## Root cause (hypothesis)

Whatever re-ran the partisan classifier between April 1 and April 18 (not yet identified in the repo — no committed script touches `staging.boe_donation_candidate_map` between those dates) treated anything outside statewide partisan races as `U` and voided the candidate_name at the same time.

## Fix (Stage 2b, not Stage 1 blocking)

Two-line backfill on Hetzner after Stage 1 lands:

```sql
BEGIN;
UPDATE committee.boe_donation_candidate_map m
   SET candidate_name = r.candidate_name
  FROM public.committee_registry r           -- or the equivalent on Hetzner
 WHERE m.committee_sboe_id = r.sboe_id
   AND m.candidate_name IS NULL
   AND r.candidate_name IS NOT NULL;
-- Expected: ~80K+ rows updated. Run SELECT COUNT first.
COMMIT;
```

Plus a separate `partisan_flag` correction pass that joins the same registry's `committee_type` and infers R vs D from candidate party affiliation.

Expected post-fix match rate: ≥ 99% (same ballpark as April 1, slightly different because sheriff/judicial registry entries may have edge cases).

## Why this doesn't block Stage 1

`core.donor_profile` keys on `cluster_id`, not `candidate_name`. The 88,256 downballot rows still have `committee_sboe_id` and dollar amounts — they'll land in Stage 1 correctly. The candidate-level attribution just looks more sparse than it should. Ed already has the full picture from sheer dollar counts.

## TODO

- [x] Diagnose
- [ ] Run the two-line backfill (Stage 2b)
- [ ] Re-run partisan_flag classifier with downballot awareness (Stage 2b)
- [ ] Update `committee.v_matching_machine_status` expected match_rate to 99%+

---

*Diagnosed by Nexus, 2026-04-18 18:25 EDT.*
