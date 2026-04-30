# Committee Donor Cluster Rollup → DataTrust Match Plan

**Date:** 2026-04-26
**Author:** Claude (Cowork mode), at Ed Broyhill's direction
**Status:** Design — read-only SQL only. No writes. No apply. No Stage 4. No swap.

---

## Architectural change

The Phase B row/proposal-CSV apply path is **deprecated**. See companion note:
`docs/runbooks/PHASE_B_ROW_PROPOSAL_PATH_DEPRECATED.md`.

The corrected path is four explicit layers:

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

This satisfies Ed's row-level-IDs rule (Layer 4) without doing identity matching at the noisy row level (the previous mistake).

## Universe declaration

`GOP_PARTY_COMMITTEE_DONOR_PREP` = `staging.ncboe_party_committee_donations`.

`raw.ncboe_donations` is **read-only canary only** in this work.

## Live state assumed at the start of this work

Verified by Phase C apply and prior Stage 2 safe-person apply:

| Item | Value |
|---|---|
| Spine | `raw.ncboe_donations` 321,348 rows / 98,303 clusters |
| Spine canary | cluster 372171 = 147 rows / $332,631.30 / `c45eeea9-663f-40e1-b0e7-a473baee794e` / `ed@broyhill.net` |
| Committee staging rows | 293,396 |
| `cluster_id_v2` nulls | 0 |
| `cluster_id_v2` distinct clusters | 60,238 |
| `committee_name_resolved` nulls | 0 (Phase C complete) |
| Multi-`rnc_regid_v2` clusters | 0 |
| Ed committee canary | `cluster_id_v2 = 5005999` = 40 rows / $155,945.45 / no Melanie |
| Pope committee canary | `cluster_id_v2 = 5037665` = 22 rows / $378,114.05 / no Katherine |

Pre-flight (read-only) re-verifies all of the above before any new work.

## Layer 2 — `staging.v_committee_donor_identity_rollup_v1`

One row per `cluster_id_v2` aggregating identity evidence from all rows in the cluster.

### Identity evidence
- `legal_name_variants` — every distinct raw `name` field across the cluster
- `first_set`, `middle_set`, `last_set`, `suffix_set` — distinct uppercased trimmed values per name field
- `nickname_set` — distinct nickname values when present (extracted from quoted forms)

### Address evidence
- `zip5_set`, `city_set` — distinct values
- `street1_set`, `street2_set` — distinct uppercased trimmed values
- `address_numeric_token_set` — every numeric token extracted from line 1 AND line 2 (house numbers, PO boxes, highway numbers, suite/unit/floor/RR/apt numbers, building numbers)

### Recipient evidence (Phase C dependent)
- `recipient_committee_id_set` — distinct `committee_sboe_id`
- `recipient_committee_name_set` — distinct `committee_name_resolved`
- `recipient_candidate_name_set` — distinct `candidate_referendum_name`

### QA / blast-radius context (NOT scoring)
- `total_amount` — sum of `norm_amount`
- `first_donation_date`, `last_donation_date`
- `row_count`

These are diagnostics only. They are NOT donor scores, ratings, microsegments, or prioritization. They give a reviewer context on what's in a cluster.

### Variation counts
- `name_variation_count`, `address_variation_count`, `zip5_count`, `committee_count`
- `first_variation_count`, `last_variation_count`

### Existing-match diagnostics
- `existing_rnc_regid_set`, `existing_state_voter_id_set`
- `existing_rnc_count`
- `already_matched` — TRUE if any row in the cluster already has `rnc_regid_v2`

### Conflict / disqualifier flags
- `suffix_conflict` — cluster contains > 1 distinct concrete suffix value (JR/SR/II/III/IV)
- `likely_household_conflict` — conservative: cluster has ≥ 3 distinct first-letter initials AND single last name AND single address — likely Stage 2 over-merge of a household
- `nonperson_or_aggregate_signal` — name field contains CASH / AGGREGATED / UNITEMIZED / PAC / LLC / CORP / COMMITTEE / FOUNDATION / TRUST / INC / LP / LLP / PLLC / FUND patterns; or `is_unitemized = TRUE`
- `needs_review` — TRUE when any disqualifier or conflict flag fires
- `review_reason` — text array of fired-flag reasons

## Layer 3 — Cluster-level DataTrust match dry-run

Input: rows from the rollup view where `NOT already_matched AND NOT suffix_conflict AND NOT likely_household_conflict AND NOT nonperson_or_aggregate_signal`.

Match logic against `core.datatrust_voter_nc`:

1. **Last-name anchor (strict):** DataTrust `last_name` MUST be in the cluster's `last_set`. The previous LEE ANN bug is impossible because we're checking against the cluster's observed last names, not raw token bags.
2. **First-name evidence (token-bag for first only):** DataTrust `first_name` is compatible if it's in `first_set`, or if its first-letter initial appears in any `first_set` member's first letter, or if a known-nickname expansion would map it to a `first_set` member. (Last name stays strict.)
3. **Middle compatibility:** if DataTrust `middle_name` is set AND the cluster has any non-empty `middle_set` entries, the DataTrust value (or its initial) must align with at least one cluster middle. If either side is empty, that's "unknown not conflict."
4. **Suffix compatibility:** if both sides have a concrete suffix, they must match. Concrete vs NULL is "unknown." Concrete vs different concrete blocks.
5. **Pair rule:** `rnc_regid` and `state_voter_id` must come from the SAME DataTrust row.
6. **Uniqueness rule:** for a cluster's match to be proposed, the candidate set surviving guards must resolve to exactly ONE distinct `rnc_regid`. Multiple DataTrust rows that share the same `rnc_regid` are the same person — they pass. Multiple distinct `rnc_regid` values block.
7. **Cross-cluster uniqueness:** if a proposed `rnc_regid` is reused across multiple clusters, the proposal is allowed only if cluster-level evidence supports same-person (recipient continuity OR coherent address/numeric overlap). Otherwise the whole reused-RNC group is held for review.

### Tier labels
- `T_zip` — cluster zip5_set ∩ DataTrust zip5 ≠ ∅, plus name evidence
- `T_addr` — cluster (numeric_token, zip5) pair set ∩ DataTrust (numeric_token, zip5) pair set ≠ ∅, plus name evidence
- `T_recip` — cluster recipient_committee_id_set has continuity evidence, plus name evidence and uniqueness
- `T_strong` — multiple of the above present
- `T_cross_zip` — name + middle + suffix only, no zip overlap; requires uniqueness AND non-common-name

### Hard exclusions
- `suffix_conflict` clusters → not auto-proposed
- `likely_household_conflict` clusters → not auto-proposed
- `nonperson_or_aggregate_signal` clusters → not auto-proposed
- T5 (employer-DataTrust) is permanently deferred per disclosure: `core.datatrust_voter_nc` has no employer column

## Dry-run output

`docs/runbooks/committee_donor_cluster_rollup_match_dryrun_20260426.md` produced after the read-only run executes against Hetzner.

### Required report sections
1. **Rollup counts** — total clusters, already-matched, unmatched, suffix_conflict, likely_household_conflict, nonperson/aggregate, needs_review
2. **Proposed matches** — proposal clusters, proposal rows that would inherit, proposal tier breakdown, rejected/held counts by reason
3. **Canaries** — spine, Ed committee, Pope committee
4. **Sample proposals by evidence type** — 10 each from T_zip, T_addr, T_recip, T_cross_zip
5. **Review list** — reused-rnc groups, suffix conflicts, household conflicts, high-variation clusters
6. **Recommendation** — fact-based observations, NOT a hardcoded heuristic verdict

## Hard no-go in this work

No UPDATE to staging. No writes to `rnc_regid_v2`, `state_voter_id_v2`, `match_tier_v2`, `is_matched_v2`. No Stage 4. No swap. No `raw.ncboe_donations` writes. No attribution. No `person_master`. No FEC. No Acxiom. No scoring / rating / prioritization / microsegment / model / Brain / dashboard updates.

Reviewer (Ed) authorizes apply explicitly per the Phase C protocol shape (atomic transaction, in-flight post-checks, archive snapshot first, exact-phrase authorization, append-only `session_state`).

## What this plan replaces

Deprecated: `committee_ingestion_v4_phase_b_corrected_proposals_*` and `committee_ingestion_v4_phase_b_merged_proposals_*` and any prior row/proposal CSV intended as Phase B apply input. They remain on disk as forensic artifacts, not as apply basis.

## Sequence

1. Read-only pre-flight on Hetzner — re-verify all live state (above table).
2. Define the rollup view (`scripts/committee_donor_cluster_rollup_match_dryrun.sql`, section 1).
3. Run the cluster-level matching dry-run (section 2 of the same SQL file). Output committed to `docs/runbooks/committee_donor_cluster_rollup_match_dryrun_20260426.md`.
4. Independent identity-risk review of the dry-run output (this is where I come back in to review).
5. If clean: Ed authorizes the `apply_eligible = TRUE` cluster subset.
6. Apply: write the proposed `rnc_regid_v2` + `state_voter_id_v2` to ALL transaction rows in each accepted cluster. Atomic transaction with in-flight post-checks. Update `public.session_state` (append, not UPDATE).
7. Stage 4 propagation only after Phase B apply settles cleanly.

## Schema verification required before run

The SQL file uses column names from prior briefings and disclosure documents. Before any execution, the runner must verify against the live schema (use `\d staging.ncboe_party_committee_donations` and `\d core.datatrust_voter_nc`). Specifically:
- `staging.ncboe_party_committee_donations`: `cluster_id_v2`, `norm_first`, `norm_middle`, `norm_last`, `norm_suffix`, `norm_zip5`, `street_line_1`, `street_line_2`, `city`, `state`, `zip_code`, `norm_amount`, `norm_date`, `committee_sboe_id`, `committee_name_resolved`, `candidate_referendum_name`, `name`, `rnc_regid_v2`, `state_voter_id_v2`, `is_unitemized`
- `core.datatrust_voter_nc`: `last_name`, `first_name`, `middle_name`, `name_suffix`, `reg_zip5`, `mail_zip5`, `state_voter_id`, `rnc_regid`

Any column-name drift must be reconciled before run.
