# Perplexity Handoff Packet — V4 Phases B + C + D
**From:** Ed Broyhill, via Claude (Cowork mode)
**Date:** 2026-04-26
**Goal:** Move the Party Committee Donor V4 ingestion from the Stage 5 safe checkpoint to the Stage 8 authorized state, with one round of Ed authorization in the middle.

---

## Universe declaration

I am working in `GOP_PARTY_COMMITTEE_DONOR_PREP` = `staging.ncboe_party_committee_donations`.

I will not write to `raw.ncboe_donations` (read-only canary use only).
I will not write to `core.di_donor_attribution`, `core.donor_attribution`, or `donor_intelligence.person_master`.
I will not run Stage 4 propagation, the `_v2` swap, FEC ingestion, or Acxiom materialization.
T5 employer match remains deferred — `core.datatrust_voter_nc` has no employer column.

## Mandatory skill stack loaded

`database-operations`, `broyhillgop-architecture`, `donor-attribution`, `data-ingestion-and-forecasting`, `data/sql-queries`, `data/validation`, `coding-and-data`.

If any are not loaded, stop and load before proceeding.

---

## What Ed needs from this packet

**Three dry-run reports in one reply, no apply on any of them.** Ed authorizes after reading. Each section below specifies the dry-run, the expected canaries, and the report format.

You drive Phases B + C + D in parallel. Ed only re-engages at the authorization gate.

---

## Phase B — Stage 3 T4/T6 voter-resolution dry-run

### Pre-flight
Confirm the current Stage 3 dry-run state. If you (or Cursor) have already produced a Stage 3 T4/T6 dry-run report, paste its file path and content. If not, produce one now.

### What to dry-run
T4 and T6 only. T5 stays deferred. T1/T2/T3 are already applied (161,012 rows, 24,513 matched clusters).

For each unmatched `cluster_id_v2` (currently 36,367 clusters / 132,384 rows), propose a `state_voter_id_v2` + `rnc_regid_v2` pair. **Both fields must come from the same row of `core.datatrust_voter_nc`.** Never match them independently.

### Hard guards (must hold in the dry-run output)
- Ambiguity guard: exactly one DataTrust candidate per cluster, or no proposal.
- No fuzzy best-guess. No Acxiom-first matching.
- Suffix mismatch on a candidate row blocks the proposal.
- PO Box / highway / unit / line-2 / multi-number addresses cannot drive the match.
- Same address + different first name = household, not a proposal.

### Required report format
| metric | value |
|---|---|
| dry-run timestamp | |
| pre-state: unmatched clusters | 36,367 |
| pre-state: unmatched rows | 132,384 |
| T4 proposals: clusters | |
| T4 proposals: rows that would inherit | |
| T6 proposals: clusters | |
| T6 proposals: rows that would inherit | |
| ambiguity-blocked clusters | |
| suffix-blocked clusters | |
| household-flagged clusters | |
| post-state: still-unmatched clusters | |
| Ed canary intact? | yes/no |
| Pope canary intact? | yes/no |
| spine canary intact? | yes/no |

Plus 20 sample proposed matches (cluster_id_v2, last name, first name, suffix, zip5, proposed state_voter_id_v2, proposed rnc_regid_v2, match_tier_v2, evidence note).

---

## Phase C — Stage 8 committee_name_resolved dry-run (parallel to Phase B)

### What to dry-run
The deterministic update from `committee.committee_id_canonical_name`. Translator already covers 291/291 committee IDs.

```sql
-- DRY-RUN ONLY — produces the affected row count and a sample, no UPDATE
WITH proposed AS (
  SELECT s.id,
         s.committee_sboe_id,
         s.committee_name        AS current_committee_name_raw,
         t.canonical_name        AS proposed_committee_name_resolved
  FROM   staging.ncboe_party_committee_donations s
  JOIN   committee.committee_id_canonical_name t
         ON t.committee_sboe_id = s.committee_sboe_id
  WHERE  s.committee_name_resolved IS NULL
)
SELECT
  (SELECT COUNT(*) FROM proposed)                                      AS rows_to_update,
  (SELECT COUNT(DISTINCT committee_sboe_id) FROM proposed)             AS distinct_committee_ids,
  (SELECT COUNT(*) FROM staging.ncboe_party_committee_donations
     WHERE committee_name_resolved IS NULL
       AND committee_sboe_id NOT IN (SELECT committee_sboe_id
                                       FROM committee.committee_id_canonical_name)) AS rows_unmappable
;
-- Plus: 20 sample rows from `proposed`.
```

### Required report format
| metric | expected | actual |
|---|---|---|
| rows currently NULL | 293,396 | |
| rows that would resolve | 293,396 | |
| distinct committee_sboe_ids | 291 | |
| rows unmappable (no translator match) | 0 | |
| sample of 20 proposed updates | — | included |
| Ed canary intact? | yes | |
| Pope canary intact? | yes | |
| spine canary intact? | yes | |

If `rows_unmappable` is anything other than 0, stop and report — do not propose an apply.

---

## Phase D — 17 suffix-conflict cluster review

### What to produce
A compact, human-readable review table for the 17 `cluster_id_v2` values that contain multiple concrete suffix values (JR / SR / II / III / IV).

For each cluster, one row showing:

```sql
SELECT cluster_id_v2,
       COUNT(*)                                           AS rows,
       array_agg(DISTINCT norm_name_suffix
                 ORDER BY norm_name_suffix)               AS suffixes,
       array_agg(DISTINCT norm_name_first
                 ORDER BY norm_name_first)                AS firsts,
       array_agg(DISTINCT norm_name_middle
                 ORDER BY norm_name_middle)               AS middles,
       array_agg(DISTINCT norm_name_last
                 ORDER BY norm_name_last)                 AS lasts,
       array_agg(DISTINCT rnc_regid_v2
                 ORDER BY rnc_regid_v2)
                 FILTER (WHERE rnc_regid_v2 IS NOT NULL)  AS rnc_regids,
       SUM(norm_amount)                                   AS total_amount,
       MIN(norm_date)                                     AS first_date,
       MAX(norm_date)                                     AS last_date
FROM   staging.ncboe_party_committee_donations
WHERE  cluster_id_v2 IN (
         SELECT cluster_id_v2
         FROM   staging.ncboe_party_committee_donations
         WHERE  norm_name_suffix IS NOT NULL
         GROUP  BY cluster_id_v2
         HAVING COUNT(DISTINCT norm_name_suffix) > 1
       )
GROUP  BY cluster_id_v2
ORDER  BY total_amount DESC;
```

### What you tell Ed for each cluster
One of: `SPLIT_CLEAR_GENERATIONAL` (different suffixes, separate rnc_regids — split now), `KEEP_DOCUMENTED` (single rnc_regid, evidence consistent — leave clustered, document), or `DEFER` (ambiguous — exclude from Stage 4 propagation, revisit after Stage 6 final).

Output one line per cluster, no SQL block, plain-English judgment.

---

## Authorization gate

After all three reports come back, Ed will respond with one of:

- `I AUTHORIZE THIS ACTION — Phase B Stage 3 T4/T6 apply`
- `I AUTHORIZE THIS ACTION — Phase C Stage 8 committee_name_resolved apply`
- `I AUTHORIZE THIS ACTION — Phase D suffix-conflict splits per attached list`
- Or any combination of the above
- Or `HOLD` with specific concerns

Without the exact `I AUTHORIZE THIS ACTION` phrase per phase, no apply runs.

---

## What you do NOT do in this round

- Do not run Stage 4 propagation. (Gated on Phase B + D both passing.)
- Do not write to `donor_intelligence.person_master`.
- Do not write to `core.di_donor_attribution` or `core.donor_attribution`.
- Do not swap `_v2` columns to canonical.
- Do not retry T5 employer match.
- Do not touch `raw.ncboe_donations` except for canary reads.

---

## Post-apply (only after Ed authorizes specific phases)

1. Apply only what Ed authorized, exactly as proposed in the dry-run.
2. Re-run all three canaries and report intact/drift.
3. Insert a new `public.session_state` row (id 22 or higher) with the V4 progress update and the mandatory skill tag preserved.
4. Confirm `multi-rnc_regid_v2 clusters` is still 0.
5. Reply with the final state for the next session to inherit.

---

## Operational note

After this round closes, the next Ed-touch point is Phase E (Stage 4 row-level ID propagation) — gated on Phase B and Phase D both being authorized and applied. Phase E is its own dry-run + authorization round.

Ed does not need to be in the loop between Phase B/C/D apply and the Phase E dry-run preparation. Drive that uninterrupted.

---

*End of packet.*
