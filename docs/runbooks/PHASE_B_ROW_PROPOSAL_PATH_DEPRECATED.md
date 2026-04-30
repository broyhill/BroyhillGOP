# Phase B Row/Proposal-CSV Path — DEPRECATED

**Date:** 2026-04-26
**Status:** Deprecated. Do not use as Phase B apply basis.

## What was deprecated

All variants of the row-derived proposal-CSV path for Phase B Stage 3 voter resolution, including:

- `committee_ingestion_v4_phase_b_proposals_20260426_2049.csv` (original token-bag dry-run)
- `committee_ingestion_v4_phase_b_corrected_proposals_20260426_2122.csv` (observed-last anchor correction)
- `committee_ingestion_v4_phase_b_merged_proposals_20260426.csv` (commit `2a94f41` — different matcher; not a true merge of the corrected pipeline)
- `committee_ingestion_v4_phase_b_merged_review_20260426.md` (the merged dry-run report)
- `committee_ingestion_v4_phase_b_merged_dryrun.py` (commit `e3e8184` — script tracked but superseded)

These files remain on disk and on the `v4-committee-ingestion-artifacts-20260426` branch as forensic artifacts. They are not authoritative and not to be used as Phase B apply input.

## Why deprecated

Repeated dry-runs on the row-derived proposal CSV path surfaced false-positive patterns that were symptoms of the wrong matching unit, not just rule-tuning issues:

- **LEE ANN bug** — token-bag matching let DataTrust `last_name` match any token anywhere in a cluster's bag, not just the cluster's observed last names. Four real Lee Ann surnames (PATTON, MORRIS, STARRARD, PRESTON) collapsed to one rnc_regid because the LEE token was matching against rows where LEE was the donor's first name.
- **WOLF household collapse** — four members of one Wolf household (AMY, BRUCE, CHARLIE, KATHRYN) were proposed for the same rnc_regid because the algorithm checked uniqueness per cluster but not across clusters within a reused-rnc group.
- **ELIZABETH SMITH 9-zip collapse** — nine geographically distinct Elizabeth Smith donors mapped to one rnc_regid; uniqueness held per-cluster but not across the reused-rnc group.
- **Each fix layered another filter on top of the row-derived proposal set** — observed-last anchor (LEE ANN), Pattern A (WOLF), Pattern B (ELIZABETH SMITH), parse-artifact normalization, T4_THIN_NO_RECIPIENT_EVIDENCE — without addressing that identity matching at the row level amplifies noise instead of resolving it.
- **The `2a94f41` "merged" dry-run was not a true merge** — it abandoned token-bag matching, abandoned the corrected (2122) pipeline's evidence path, regenerated a different 6,645-candidate universe, and shipped a CSV missing the modal name fields needed for human review.

The architectural error: identity matching was being attempted at the noisiest layer (individual transaction rows / per-row proposals) when the natural unit of identity is the cluster (`cluster_id_v2`) — a person, with all their name and address variations rolled up.

## Replacement

The correct architecture is layered:

```
Layer 1: transaction staging
  staging.ncboe_party_committee_donations  (legal/source rows; immutable)

Layer 2: cluster identity rollup
  staging.v_committee_donor_identity_rollup_v1  (one row per cluster_id_v2)

Layer 3: cluster-level DataTrust match proposals
  staging.committee_donor_datatrust_match_proposal_v1  (one row per cluster proposal)

Layer 4: row-level affix (only after accepted proposals)
  rnc_regid_v2 / state_voter_id_v2 written back to ALL rows in accepted clusters
```

Design and SQL for the replacement path:

- `docs/runbooks/COMMITTEE_DONOR_CLUSTER_ROLLUP_MATCH_PLAN.md`
- `scripts/committee_donor_cluster_rollup_match_dryrun.sql`

## What to do with the deprecated artifacts

- Keep them in the repo for forensics and audit trail.
- Do not authorize any apply that draws from them.
- Do not iterate further on the row-derived proposal path. Any new identity-matching work uses the rollup-then-match flow.

## Decision

Phase B remains HOLD until the cluster-level rollup match dry-run produces a clean reviewable artifact and Ed authorizes the apply_eligible cluster subset using the Phase C protocol shape.

No Stage 4 propagation. No `_v2` swap. No attribution writes. No `person_master` loads. No FEC ingestion. No Acxiom materialization. No scoring / rating / microsegment / model / Brain / dashboard updates.
