# Cursor Handoff Packet — Phase B Stage 3 Review Materialization
**From:** Ed Broyhill, via Claude (Cowork mode)
**Date:** 2026-04-26
**Authorization:** **DRY-RUN MATERIALIZATION ONLY. NO APPLY.**

---

## Goal

Convert your Phase B Stage 3 T4/T6 dry-run output into two artifacts:

1. A CSV of every proposed cluster→voter match.
2. A technical diagnostic report covering matching-correctness only.

No `rnc_regid_v2`, `state_voter_id_v2`, `match_tier_v2`, or `is_matched_v2` writes to `staging.ncboe_party_committee_donations`. This packet does not authorize Phase B apply, Stage 4, swap, suffix splits, attribution, person_master, FEC, Acxiom, or scoring/model updates.

## Explicitly OUT OF SCOPE for this packet

This packet covers matching correctness only. The following are NOT addressed here and must NOT be inferred from this work:

- Donor scoring, ratings, or microsegments (handled by E01 Donor Intelligence and the platform's analytical layer)
- Donor prioritization or "high-value" classification (handled by Ed and the platform's existing rating logic)
- NC contribution-limit checks (NC GS 163-278.13 and successor statutes)
- FEC contribution-limit checks
- Cycle-aggregation or joint-filer aggregation rules
- Refund / return-of-contribution handling
- Memo-entry handling
- Conduit / earmarking / bundling rules
- In-kind contribution treatment
- Independent-expenditure committee distinctions
- Brain triggers, dashboards, model features, propensity scoring

If a downstream concern requires any of the above, that work happens at the readiness/attribution layer (Stage 11 or Stage 10 of the 12-stage plan), not in Phase B. Phase B's only job is: assign `rnc_regid_v2` + `state_voter_id_v2` to staging rows where matching evidence supports it.

---

## Universe and skill stack

Universe: `GOP_PARTY_COMMITTEE_DONOR_PREP` = `staging.ncboe_party_committee_donations`.

Mandatory skills loaded: `database-operations`, `broyhillgop-architecture`, `donor-attribution`, `data-ingestion-and-forecasting`, `data/sql-queries`, `data/validation`, `coding-and-data`. If any are missing, stop and load.

---

## Pre-checks (must pass before producing the report)

1. Staging row count = 293,396.
2. `cluster_id_v2` nulls = 0.
3. `committee_name_resolved` nulls = 0 (Phase C complete).
4. Multi-`rnc_regid_v2` clusters = 0.
5. Spine canary `cluster_id = 372171` = 147 rows / $332,631.30 / `c45eeea9-663f-40e1-b0e7-a473baee794e` / `ed@broyhill.net`.
6. Ed committee canary `cluster_id_v2 = 5005999` = 40 / $155,945.45 / no MELANIE.
7. Pope committee canary `cluster_id_v2 = 5037665` = 22 / $378,114.05 / no KATHERINE.

If any pre-check fails, stop and report.

---

## Phase B match rules (use these, exactly)

### Name token bag — the foundational primitive (Ed correction 2026-04-26)

Field-by-field matching breaks because parsing is chaotic: middle initials end up in the last-name column, "J Edgar Broyhill" gets parsed three different ways across a donor's history, "BROYHILL, JAMES" comma-format flips first and last, and prefixes/suffixes bleed into adjacent fields. Match against the **token bag**, not the columns.

For a cluster, build the **cluster name token bag** by:

1. Collecting every alphabetic token from `norm_first`, `norm_middle`, `norm_last`, `norm_suffix`, AND `raw_name` (or `name`) across ALL rows in the cluster.
2. Stripping punctuation, uppercasing, deduping.
3. Removing honorifics/prefixes (DR, MR, MRS, MS, REV, HON, etc.) into a separate prefix bag (not used for identity).
4. Removing pure stop-tokens (NMN, NA, N/A, etc.).
5. Identifying each remaining token as one of: known-first-name, known-nickname, single-letter-initial, suffix-token (JR/SR/II/III/IV), or candidate-last-name (everything else).

For a DataTrust candidate row, build the **DataTrust name token bag** the same way from `first_name`, `middle_name`, `last_name`, `name_suffix`.

Match logic uses token-set membership and expansion, not column-to-column equality.

### T4 — cross-zip with strong identity support
Allowed only when ALL of the following hold for a proposed `(cluster_id_v2 → core.datatrust_voter_nc row)` pair:

- DataTrust last_name token appears in the cluster's token bag (anywhere — first, middle, last, suffix, or raw_name field).
- DataTrust first_name token (OR a compatible nickname expansion: ED↔EDGAR, JIM↔JAMES, BOB↔ROBERT, etc., per parser v4) appears in the cluster's token bag.
- DataTrust middle_name token (OR its first-letter initial) appears in the cluster's bag. If the cluster has NO middle tokens at all, this is unknown not a conflict — but T4 requires SOME middle alignment evidence (initial or full), so a cluster with no middle tokens fails T4.
- Suffix compatible. JR/SR/II/III/IV mismatch blocks. NULL on one side and concrete on the other does NOT satisfy compatibility for T4.
- Common-name override: if the cluster's candidate-last-name token has > 1,000 (last+first) combinations in DataTrust statewide, T4 requires zip5 match (i.e., it falls into T6).
- Exactly one DISTINCT `rnc_regid` resolves after all guards (per Section 5c).

### T6 — same-zip5 person identity (variation-tolerant)
Allowed when ALL of the following hold:

- The cluster's zip5 SET (every distinct norm_zip5 across the cluster's rows, not just the modal) intersects the DataTrust candidate's `reg_zip5` OR `mail_zip5`.
- DataTrust last_name token appears in the cluster's token bag (anywhere).
- DataTrust first_name token (OR a compatible nickname/initial expansion) appears in the cluster's token bag.
- If DataTrust has a middle_name token AND the cluster has any middle-position tokens, they must be compatible (full match, OR initial of full, OR full of initial). If the cluster has NO middle tokens at all OR DataTrust has no middle_name, that is unknown not a conflict.
- Suffix compatible. JR/SR/II/III/IV mismatch blocks. NULL-vs-concrete is unknown not a conflict for T6 (looser than T4 because zip5 is doing identity work).
- The cluster's (numeric_token, zip5) pair set intersects the DataTrust candidate's (numeric_token, zip5) pair set. If empty, the match still proceeds on name+zip5 alone but gets a weaker `evidence_note` flag.
- Exactly one DISTINCT `rnc_regid` resolves after all guards (per Section 5c).

### Worked example — Ed Broyhill cluster

Cluster name token bag (assembled across 20 name variations):
```
{ED, EDGAR, JAMES, J, E, BROYHILL, II}
```

Honorifics/stops removed (none present).

Candidate-last-name tokens (after stripping known first names, nicknames, initials, and suffix tokens):
```
{BROYHILL}
```
(JAMES, ED, EDGAR are first/nickname; J, E are initials; II is a suffix token.)

DataTrust query: `WHERE upper(last_name) = 'BROYHILL'` (uses existing index).

Each candidate row tested for token-bag overlap. A DataTrust row with first_name='JAMES', middle_name='EDGAR', last_name='BROYHILL', suffix='II' — every one of those tokens appears in the cluster's bag. Match.

Same logic recovers the cluster even from the messy parses:
- "J EDGAR BROYHILL" → tokens {J, EDGAR, BROYHILL} all in bag ✓
- "BROYHILL, JAMES" → tokens {BROYHILL, JAMES} all in bag ✓
- Initial "J" stranded in last-name column → still in the bag ✓

### Hard guards (apply to both T4 and T6)
- `rnc_regid_v2` and `state_voter_id_v2` must come from the SAME row of `core.datatrust_voter_nc`. Never matched independently.
- Same address + different first name = household candidate, not a Phase B proposal.
- Any cluster_id_v2 in the Phase D suffix-conflict set (17 clusters) is excluded from Phase B entirely.
- T5 (employer/DataTrust) is deferred. Do not retry it.

### Address number rule (Ed correction 2026-04-26 — overrides any prior "PO Box can't drive a match" guidance)

Numeric tokens from address line 1 AND line 2 are VALID identity evidence when paired with zip5. Extract every number: house number, PO box number, highway number, suite/unit number, floor number, rural route number, apt number, building number. Both lines.

Examples:
- "525 N HAWTHORNE RD" + "APT 3224" → tokens [525, 3224]
- "PO BOX 1247" → tokens [1247]
- "4721 HWY 421 S" → tokens [4721, 421]
- "STE 300 100 MAIN ST" → tokens [300, 100]

Within a cluster, collect every (numeric_token, zip5) pair that appears across the cluster's rows. For a DataTrust candidate, do the same against the candidate's address. If the cluster's pair set ∩ DataTrust candidate's pair set ≠ ∅, that is supporting identity evidence — strengthens the match.

Multi-number addresses are NOT a disqualifier. They expand the identity-token pool. Generic numbers (like "100") that appear in many addresses get caught by the rnc_regid uniqueness rule (Section 5c) — if a cluster's numbers resolve to more than one distinct rnc_regid at the same zip5, the proposal is rejected. The fix lives in the uniqueness check, not in a blanket blacklist.

This rule particularly matters for high-variation donors. A donor with 15 address variations and 20 name variations (Ed Broyhill is the canonical example: cluster_id_v2 5005999) has the names spread thin, but the numeric tokens at home zip + business zip tend to repeat across his rows. Number+zip evidence anchors high-variation clusters that name-only matching would miss.

---

## Output 1 — Proposal CSV

**Path:** `/Users/Broyhill/Documents/GitHub/BroyhillGOP/docs/runbooks/committee_ingestion_v4_phase_b_proposals_20260426.csv`

**Columns (in this exact order):**

| Column | Source / Definition |
|---|---|
| `cluster_id_v2` | staging.cluster_id_v2 |
| `cluster_rows` | COUNT(*) of staging rows in this cluster |
| `cluster_total_amount` | SUM(norm_amount) for the cluster |
| `norm_last` | most common norm_last in the cluster |
| `norm_first` | most common norm_first in the cluster |
| `norm_middle` | most common norm_middle (or NULL) |
| `norm_suffix` | most common norm_suffix (or NULL) |
| `cluster_zip5_modal` | most common normalized zip5 in the cluster |
| `proposed_state_voter_id_v2` | from the same DataTrust row |
| `proposed_rnc_regid_v2` | from the same DataTrust row |
| `match_tier_v2` | 'T4' or 'T6' |
| `dt_candidates_before_guards` | how many DataTrust rows matched on (last + first) before any guard ran |
| `dt_candidates_after_guards` | must be 1 |
| `evidence_note` | one short sentence in plain English, e.g. "T6: same-zip 27104; middle E matches; suffix null both sides; only DataTrust candidate after guards." |

One row per proposed cluster. No row if no proposal exists for the cluster.

Sort: `cluster_total_amount DESC`.

---

## Output 2 — Review report

**Path:** `/Users/Broyhill/Documents/GitHub/BroyhillGOP/docs/runbooks/committee_ingestion_v4_phase_b_review_20260426.md`

### Section 1 — Counts table

| Metric | Original dry-run | This run |
|---|---|---|
| T4 proposals (clusters) | 929 | |
| T4 proposals (rows that would inherit) | 5,189 | |
| T6 proposals (clusters) | 5,745 | |
| T6 proposals (rows that would inherit) | 18,326 | |
| **Total proposed clusters** | **6,674** | |
| **Total proposed rows** | **23,515** | |

If T4 dropped under the tightened rule, that's expected and good. If T4 stayed at or near 929, the tightening was not applied — flag and stop.

### Section 2 — Dense-name-space matching behavior

This is a technical correctness check, not a donor-importance ranking. In dense name spaces (last+first combinations with many candidates statewide), the exactly-one-distinct-rnc_regid rule has to do real work. List 20 proposals from clusters whose candidate-last-name token has > 1,000 (last + first) combinations in DataTrust statewide. Columns: `cluster_id_v2`, candidate-last-name token, top first-name tokens in the cluster's bag, `dt_candidates_before_guards`, `dt_candidates_after_guards`, `n_distinct_rnc_regid_after_guards`, `match_tier_v2`, `evidence_note`. The question this section answers: does the uniqueness rule converge to one rnc_regid in noisy name spaces, or does it produce false positives?

### Section 3 — Reserved (intentionally empty)

The original Section 3 proposed donor-importance prioritization based on dollar amounts. That is out of scope for this packet — it crosses into donor classification, contribution-limit context, and platform scoring criteria that this matching-correctness review does not address.

### Section 4 — Suffix-conflict cluster overlap

Cross-join the 17 cluster_id_v2 values from your Phase D suffix-conflict review against the Phase B proposal set. Expected: 0 overlap. If > 0, that is a bug — the exclusion rule did not hold. Report and stop.

### Section 5 — T4/T6 health diagnostics

- T4: percentage of proposals where `dt_candidates_before_guards > 1` (shows the guards actually did work; if this is near 0%, T4 is rarely cross-zip-with-many-candidates and the rule may be too conservative).
- T6: distribution of cluster_zip5_modal vs DataTrust `reg_zip5` (matched) vs DataTrust `mail_zip5` (matched). Three buckets, three numbers.
- Both: distribution of `dt_candidates_after_guards` (should be 1 in 100% of cases by definition; any other value is a bug in the SQL).

### Section 5b — High-token-count cluster diagnostic

Some clusters carry many name and/or address variations. The matching logic must handle high token counts gracefully — this is a technical question about the algorithm's behavior, not a donor-importance ranking. If the field-by-field code path is still active anywhere, high-token-count clusters will fall through; the token-bag rule is supposed to recover them.

For every UNMATCHED cluster_id_v2 (currently 36,367 clusters / 132,384 rows), compute:

- `n_distinct_name_variations` = COUNT(DISTINCT (norm_first || ' ' || COALESCE(norm_middle,'') || ' ' || norm_last || ' ' || COALESCE(norm_suffix,''))) within the cluster
- `n_distinct_address_variations` = COUNT(DISTINCT (street_line_1 || ' | ' || COALESCE(street_line_2,'') || ' | ' || COALESCE(norm_zip5,''))) within the cluster
- `n_distinct_zip5` = COUNT(DISTINCT norm_zip5) within the cluster

Report two tables:

**Table A — Variation distribution across unmatched clusters**
| Variation bucket | Cluster count | Rows |
|---|---|---|
| 1 name / 1 address | | |
| 2-4 names OR 2-4 addresses | | |
| 5-9 names OR 5-9 addresses | | |
| 10+ names OR 10+ addresses | | |

**Table B — 25 unmatched high-token-count clusters (sorted by token-count, not by amount)**
Selection: rows from the 5-9 and 10+ buckets. Tie-break by cluster_id_v2 ascending. No dollar-based ordering.

For each: cluster_id_v2, n_distinct_name_variations, n_distinct_address_variations, n_distinct_zip5, top 3 name token-bag entries, top 3 zip5s seen, was a match proposed (Y/N), if N then "why not" (zero candidates / multiple distinct rnc_regids / suffix block / other).

This table is the test of whether the token-bag rule handles high token counts. If 10+ of the 25 high-token clusters have no proposal because the algorithm couldn't converge, the rule needs revision before any apply.

### Section 5c — Match rule on rnc_regid uniqueness (CRITICAL)

The "exactly one candidate after guards" rule must be implemented as **"exactly one DISTINCT `rnc_regid` resolves"**, not "exactly one DataTrust row." DataTrust may contain multiple rows for the same real person (deduplication artifacts, registration history, multi-county). Two DataTrust rows that share the same rnc_regid are the SAME person — the match should pass. Two DataTrust rows with different rnc_regids are different people — the match must fail.

Report: for the proposal set, count of clusters where `dt_candidates_after_guards > 1` BUT `n_distinct_rnc_regid_after_guards = 1`. These are proposals that the original "one row" rule would have rejected and the corrected "one rnc_regid" rule accepts. Also count clusters where `n_distinct_rnc_regid_after_guards > 1` — these are correctly rejected (different real people, same name).

### Section 6 — Technical observations only (not an apply recommendation)

Cursor reports observations, not a ship/no-ship verdict. The apply decision is made by Ed in the platform context (with whatever scoring, compliance, contribution-limit, microsegment, and operational considerations apply at that level — none of which are in scope for this packet).

State, factually:
- Did the suffix-conflict overlap check (Section 4) come back as 0? Y/N.
- Did the rnc_regid uniqueness check (Section 5c) show any clusters where multiple distinct rnc_regids resolved? Y/N + count.
- Did Section 5b's high-token-count test produce proposals for the 25-cluster sample? Counts of Y vs N + the "why not" breakdown.
- Did all four post-checks pass? Y/N each.

No "looks safe to apply" line. No tier-by-tier ship recommendation. Just the facts from the diagnostics above.

---

## Hard no-go in this packet

- Do NOT write to `staging.ncboe_party_committee_donations`. Dry-run is compute-only.
- Do NOT write to `raw.ncboe_donations`.
- Do NOT write to `core.di_donor_attribution`, `core.donor_attribution`, or `donor_intelligence.person_master`.
- Do NOT run Stage 4 propagation.
- Do NOT swap `_v2` columns to canonical.
- Do NOT touch FEC, Acxiom, scoring, models, microsegments, brain triggers, or dashboards.
- Do NOT update `public.session_state`. (No state change has occurred — only a report.)

---

## Post-checks before reporting done

1. Staging row count still = 293,396.
2. `committee_name_resolved` nulls still = 0.
3. Multi-`rnc_regid_v2` clusters still = 0.
4. All three canaries unchanged.

If any drift, you wrote where you shouldn't have. Roll back, report.

---

## Reply format

When complete, reply with:

- Commit hash for the two-file commit (CSV + report).
- Paths to both files.
- Section 1 counts (T4/T6/total).
- Section 6 recommendation.
- Confirmation that all four post-checks passed.

That's it. No prose summary needed beyond Section 6's one-line recommendation.

---

*End of packet.*
