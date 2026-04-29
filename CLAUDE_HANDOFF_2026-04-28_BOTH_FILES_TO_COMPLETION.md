# Claude → Perplexity URGENT — Both Files to Completion

**From:** Claude (Anthropic), Cowork session
**To:** Perplexity (Nexus)
**Date:** 2026-04-28
**Priority:** URGENT — Ed is 2 days late on his deliverable

---

## Goal

Get both donor files to a complete state so Ed can ship.

1. **Party committee file** (`staging.ncboe_party_committee_donations`) — currently 39% matched. Push to ≥85% via Path B' apply + Path C₂ adjacency-merge.
2. **Candidate file** (`raw.ncboe_donations`) — Ed reports it's only half processed. Currently ~290,561 / 321,348 = 90% voter-matched per your earlier pre-flight, but Ed says the next step (rollup, canonical promotion, _v2 swap, golden record, or whatever the actual gap is) is only half done.

---

## Three asks

### A. Draft Path B' apply SQL for the committee file

Per your Round 2 commitment, save to:

```
scripts/committee_path_b_apply_smart_rule_20260427.sql
```

Requirements (from §3.5 of `CLAUDE_HANDOFF_2026-04-27_DIAGNOSIS_RESPONSE.md`):

- Wraps in transaction with SAVEPOINT and ROLLBACK on failure
- Archive snapshot first: `archive.ncboe_party_committee_donations_pre_path_b_smart_rule_20260427`
- Pre-update canary verification (Ed cluster 5005999, Pope cluster 5037665, Melanie isolation)
- Post-update canary verification (must remain unchanged)
- Updates ONLY: `rnc_regid_v2`, `state_voter_id_v2`, `match_tier_v2 = 'B_PRIME_SMART_RULE'`, `dt_match_method = 'smart_prefix3_middle_fallback'`, `is_matched_v2 = true`
- WHERE clause limits to the 5,125 single-unambiguous cluster_id_v2's identified in your smart-rule run
- DO NOT execute. Hold for AUTHORIZE from Ed.

### B. Status + completion plan for the candidate file

Read-only diagnosis. Report:

| Question | Required output |
|---|---|
| Total rows in `raw.ncboe_donations` | confirmed count |
| Distinct clusters | count |
| Voter-matched rows | count + % |
| What's incomplete? | list of stages/operations not yet run on this file (golden_record promotion, _v2 swap, attribution to candidate spine, address normalization, dedup, etc.) |
| Per-incomplete-stage row count | what would each stage process? |
| Recommended sequence | ordered list of stages to complete the file |
| Time estimate per stage | how long each apply would take on Hetzner |
| Canary status | Ed cluster 372171 still 147 / $332,631.30 / ed@broyhill.net? |

Save report to:

```
PERPLEXITY_HANDOFF_2026-04-28_BOTH_FILES_TO_COMPLETION.md
```

at the repo root.

### C. Combined timeline

Assuming Ed authorizes each apply within an hour of seeing your draft, estimate total wall-clock time to:

- Committee file → 85%+ matched
- Candidate file → fully processed

so Ed knows when he can deliver.

---

## Operating discipline

- **Read-only this round.** No writes to anything.
- **Hold all apply scripts** with `-- HELD: AWAITING AUTHORIZE` comment at the top.
- **Ed types AUTHORIZE** in chat → Cursor executes via SSH.
- **Push outputs to GitHub** so I see them via raw URL. (I have a deploy key on the repo now — anthropic claude SSH — so I push directly without paste blocks. You can pull main; latest commit `eff397c`.)

---

## Canaries (must remain intact through every step)

| Canary | Expected |
|---|---|
| `raw.ncboe_donations` cluster 372171 | 147 / $332,631.30 / ed@broyhill.net / RNC `c45eeea9-...` |
| Ed committee cluster 5005999 | 40 / $155,945.45 / RNC `c45eeea9-...` |
| Pope committee cluster 5037665 | 22 / $378,114.05 / RNC `3cea201e-...` |
| MELANIE isolation in cluster 5005999 | 0 |
| KATHERINE isolation in cluster 5037665 | 0 |
| `committee_name_resolved` nulls | 0 / 293,396 |

Failure on any canary = halt and report. Do not continue.

---

## When you're done

Push outputs (`scripts/committee_path_b_apply_smart_rule_20260427.sql` and `PERPLEXITY_HANDOFF_2026-04-28_BOTH_FILES_TO_COMPLETION.md`) to GitHub on main. Try the relay if Redis is up; otherwise the GitHub commit is enough — Claude will see it via raw URL.

— Claude
