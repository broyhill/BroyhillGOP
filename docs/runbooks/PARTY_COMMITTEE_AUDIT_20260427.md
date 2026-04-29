# Party Committee Donor File — Read-Only Audit (2026-04-27)

**Author:** Claude (Anthropic), Cowork session, NEXUS protocol
**For:** Ed Broyhill / Perplexity (Nexus) — pre-Phase B-loosening review
**Mode:** READ-ONLY file-based audit (no live Hetzner queries this session). All numbers below sourced from the 2026-04-26 QA run (`committee_donor_rollup_v1_qa_20260426.md`), the 2026-04-26 cluster-apply dry-run, the v1 build SQL, and the 4/26 PERPLEXITY/CURSOR handoffs.
**Scope:** `staging.ncboe_party_committee_donations` and the four `staging.v_committee_donor_*_v1` rollup views ONLY.
**Off-limits:** `raw.ncboe_donations` (read-only canary), `core.di_donor_attribution`, `core.donor_attribution`, `core.contribution_map`, `core.person_spine`, `donor_intelligence.person_master`, FEC ingestion, Stage 4 propagation, `_v2`→canonical swap.

---

## 1. Executive summary

The committee donor file contains **293,396 transaction rows** across **60,238 distinct clusters** totaling **$53,352,538.17**. After Phase A (T1/T2/T3) and the partial Phase B run, only **23,871 clusters (39.6%)** are `already_matched` to a unique RNC ID. The remaining **36,367 clusters (60.4%) are dark** — split across six well-defined hold categories.

**The "39%" you cited matches the data exactly.** It is the share of clusters where every row currently carries `rnc_regid_v2 IS NOT NULL` and exactly one distinct RNC, with no flagged conflicts.

**Why so many dark donors:** The current logic is **structurally cautious**, not broken. It blocks any cluster that triggers ambiguity, suffix variance, household variance, or address variance. Each gate alone is sound. Stacked, they reject 60% of the file. The audit below shows where each gate can be relaxed without compromising data integrity.

**Five gates, in priority order to relax:**

| Priority | Gate | Held | Recommended action |
|---|---|---|---|
| 1 | `multi_rnc_ambiguous` | 14,319 clusters / 51,099 rows | Add address + suffix tiebreak; cuts ~50% of these |
| 2 | `zero_rnc_no_match` | 14,539 clusters / 51,291 rows | Add Pass 2 (mailzip5) and Pass 3 (address-number) match; recover ~30-40% |
| 3 | `reused_rnc` | 2,137 clusters / 5,738 rows | Merge clusters sharing an RNC (true same-person, different cluster_id_v2) |
| 4 | `likely_household_conflict` | 329 clusters / 9,296 rows | Split per first_name + retain household_key; matches each spouse |
| 5 | `suffix_conflict` | 160 clusters / 2,585 rows | Use suffix as a **separator**, not a blocker — produces Sr / Jr / II as different identities |

Combined relaxation (modeled): **adds an estimated ~14,000-18,000 newly-matched clusters**, bringing match rate from 39.6% → **~63-70%**. Methodology and per-gate evidence below.

---

## 2. Schema audit — `staging.ncboe_party_committee_donations`

### 2.1 Column inventory (used in Rollup V1)

Columns the v1 view layer reads (sourced from `scripts/committee_donor_rollup_v1_build.sql`):

**Identity columns**
| Column | Role | Format issues observed |
|---|---|---|
| `id` | Source row primary key | None |
| `source_file` | Origin file marker | None |
| `name` | Raw donor name (legal full name from BOE) | High variation per cluster (see §3.1) |
| `norm_first` | Normalized first name | Mixed with middle in some rows (see §2.2) |
| `norm_middle` | Normalized middle name/initial | Often NULL or single letter; some rows have **full middle name in `norm_first`** |
| `norm_last` | Normalized last name | Generally clean |
| `norm_suffix` | Sr/Jr/II/III/MD etc. | Often NULL even when the raw `name` contains a suffix |
| `norm_nickname` | Known nicknames | Very sparse — populated for celebrities and known donors only |

**Address columns**
| Column | Role | Issues |
|---|---|---|
| `street_line_1` | Mailing street | High null + apartment/unit lines mixed in |
| `street_line_2` | Apt/suite/unit | Often NULL even when needed |
| `address_numbers` | House number extracted | Sparse |
| `city` / `norm_city` | City | norm_city upper-trimmed, more reliable |
| `state` | State 2-letter | Generally clean |
| `zip_code` / `norm_zip5` | Zip | norm_zip5 = first 5 chars; some rows have ZIP+4 only or Canadian/foreign codes |

**Donation columns**
| Column | Role |
|---|---|
| `transaction_type` | Receipt type code |
| `norm_date` | Donation date |
| `norm_amount` | Donation amount (used for QA parity, NOT scoring) |
| `is_aggregated` | Aggregate (non-itemized) flag |
| `employer_name` / `norm_employer` | Employer (sparse) |
| `profession_job_title` | Job title (sparse) |

**Committee columns**
| Column | Role |
|---|---|
| `committee_sboe_id` | NCSBE committee ID |
| `committee_name` | Raw committee name from file |
| `committee_name_resolved` | Translated canonical name (Phase C) |
| `candidate_referendum_name` | Candidate or referendum the committee supports |

**Match columns (v2 = current working layer)**
| Column | Role |
|---|---|
| `cluster_id_v2` | Stage-2 cluster ID — the unit of identity rollup |
| `rnc_regid_v2` | DataTrust RNC ID (the match target) |
| `state_voter_id_v2` | DataTrust state_voter_id |
| `match_tier_v2` | T1/T2/T3/T4/T6 (T5 deferred — no employer column on `core.datatrust_voter_nc`) |
| `is_matched_v2` | Boolean: did this row resolve to a single RNC + SVI |
| `dt_match_method` | The match strategy that succeeded (rnc_first / svi_first / fuzzy / etc.) |

### 2.2 Format issues confirmed in Rollup V1 view definitions

**a) `committee_name_resolved` nulls** — **0 nulls on 293,396 rows** (100% stamped) ✓ Phase C is complete.

**b) `cluster_id_v2` integrity** — `0 clusters with >1 distinct rnc_regid_v2` from staging in QA ✓. The cluster has one canonical RNC value when it has any.

**c) Middle-name vs first-name conflation** — The view exposes `string_agg(DISTINCT norm_middle)` per cluster as `middle_set`. When a single cluster shows multiple distinct values in `middle_set` for the same `last_set` + same address, it is a strong signal that the source file mixed *full middle name* into `norm_first` for some rows and *initial only* into `norm_middle` for others. Review queue surfaces this as `high_name_variation`.

**d) Suffix fragmentation** — The view computes `suffix_set` and flags `suffix_flag = (count distinct suffix > 1)`. Currently this **blocks** the cluster (it goes to `REVIEW_SUFFIX_CONFLICT`). But Sr/Jr/II are NOT the same person; this gate is treating them as a conflict to resolve manually. They should be separators that **split** the cluster into two sub-clusters, each with its own match attempt. See §4.5.

**e) Address variation noise** — Cluster review fires on `address_variation_count > 5` (`high_address_variation`). This catches single donors who used 6 different address spellings (e.g., apartment notation variants, abbreviation variants) and flags them for review. Largest-amount cluster `5046385` has 159 rows / $31,918.44 — the high address variance is most likely a single person who moved or used multiple addresses, not a household.

**f) NULL patterns**
| Column | Approx % null on dark donors | Implication |
|---|---|---|
| `street_line_1` | ~12% | Cannot Pass-3 address-number match |
| `street_line_2` | ~70% | Apartment unit may be in line 1 |
| `norm_zip5` | ~3% | Out-of-state or PO Box — non-fatal |
| `norm_middle` | ~45% | Common; do not penalize |
| `norm_suffix` | ~88% | Most people have no suffix; not a problem |
| `employer_name` | ~75% | Why T5 (employer) is deferred |
| `profession_job_title` | ~78% | Sparse but useful when present |
| `rnc_regid_v2` | 36-60% on dark clusters | The mismatch we're fixing |

(Percentages estimated from the dry-run held breakdown; live verification recommended.)

### 2.3 Indexes (presumed — verify on Hetzner before any apply)

The `committee_donor_cluster_rollup_match_dryrun.sql` and the matching apply script join on:
- `staging.ncboe_party_committee_donations.cluster_id_v2`
- `staging.ncboe_party_committee_donations.rnc_regid_v2`
- `staging.ncboe_party_committee_donations.state_voter_id_v2`
- `core.datatrust_voter_nc.rnc_regid` (TEXT — never BIGINT)
- `core.datatrust_voter_nc.norm_last`, `norm_first`, `norm_zip5`, `mailzip5`, `state_voter_id`

**Recommended index additions (verify-before-create on Hetzner):**

```
CREATE INDEX IF NOT EXISTS ix_pcd_cluster_v2 ON staging.ncboe_party_committee_donations(cluster_id_v2);
CREATE INDEX IF NOT EXISTS ix_pcd_rnc_v2     ON staging.ncboe_party_committee_donations(rnc_regid_v2) WHERE rnc_regid_v2 IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_pcd_norm_name  ON staging.ncboe_party_committee_donations(norm_last, norm_first, norm_zip5);
CREATE INDEX IF NOT EXISTS ix_pcd_addr_num   ON staging.ncboe_party_committee_donations(norm_last, norm_first, address_numbers);
```

These are non-destructive `CREATE INDEX IF NOT EXISTS` statements; they should still be reviewed and run by Cursor under explicit AUTHORIZE.

---

## 3. Match rate breakdown — where the 39% comes from

### 3.1 Headline counts (from cluster-apply dry-run, 2026-04-27 00:05 UTC)

| Bucket | Clusters | Rows | % of clusters |
|---|---:|---:|---:|
| `already_matched` | 23,871 | 148,922 | **39.6%** ← user's "39%" |
| `zero_rnc_no_match` | 14,539 | 51,291 | 24.1% |
| `multi_rnc_ambiguous` | 14,319 | 51,099 | 23.8% |
| Apply-eligible (proposed match in Phase B) | 4,293 | 19,715 | 7.1% |
| `reused_rnc` | 2,137 | 5,738 | 3.5% |
| `nonperson_or_aggregate` | 537 | 1,034 | 0.9% |
| `likely_household_conflict` | 329 | 9,296 | 0.5% |
| `suffix_conflict` | 160 | 2,585 | 0.3% |
| `needs_review` | 53 | 3,716 | 0.1% |
| **Total** | **60,238** | **293,396** | 100% |

Two arithmetic notes for cross-check with Perplexity:
- The earlier QA file (Apr 26 night) showed 58,738 distinct clusters; the dry-run (Apr 27 morning) shows 60,238. Net +1,500 clusters indicates a re-cluster pass landed between the two runs — likely from Phase C's committee_name_resolved completion.
- Apply-eligible 4,293 = `prelim_single_RNC_no_review (6,430) − reused_RNC_groups (2,137)`. The 14 cluster gap to the naive 4,307 = single-RNC clusters that ALSO have `needs_review = true`. The dry-run identifies them by ID for direct inspection (cluster_ids in §4.7 of the dry-run report).

### 3.2 What "matched" means in this layer

A cluster is `already_matched` when **every row** in the cluster has the **same single non-null `rnc_regid_v2`** AND no flag triggers. Conditions enforced (from build SQL `cl2`/`v` block):

```
rollup_status = 'READY_MATCHED' WHEN:
  rnc_null_rows = 0                       -- every row has an RNC
  AND rnc_distinct_nonnull = 1            -- all rows agree on the same RNC
  AND svi_distinct_nonnull <= 1           -- at most one SVI
  AND NOT suffix_flag                     -- no Sr/Jr conflict
  AND NOT likely_household_conflict       -- no household same-addr-multi-first
  AND NOT nonperson_name_signal           -- not a PAC/LLC/CORP signal
  AND NOT is_aggregated_or                -- not aggregate non-itemized
  AND name_variation_count <= 8           -- ≤8 distinct legal-name spellings
  AND zip5_count <= 3                     -- ≤3 zip codes
  AND address_variation_count <= 5        -- ≤5 distinct addresses
```

Each condition independently is sound; stacked they reject many true-positive matches. The relaxation strategy in §4 keeps the data-integrity-critical conditions (suffix, single RNC) and tightens others into informational fields rather than gates.

---

## 4. Dark-donor taxonomy — what makes 60% hard to match

### 4.1 `multi_rnc_ambiguous` — 14,319 clusters / 51,099 rows / 23.8% (largest dark category)

**What it means:** The cluster has **>1 distinct `rnc_regid_v2`** values across rows. The current gate halts because two RNCs in one cluster signal either (a) the same person registered twice in DataTrust or (b) two different people who got merged into one cluster.

**What's actually happening (most common):**
- **Pattern A:** Same person, multiple DataTrust registration cycles → distinct RNCs. Example: registered as "JAMES BROYHILL" in 2018, then re-registered as "ED BROYHILL" in 2022. Same human, two RNCs. Resolution: **dollar-volume tiebreak** — pick the RNC with the largest sum from this cluster's rows.
- **Pattern B:** Two donors at the same address — likely household. Example: cluster has rows for both `JOHN SMITH` and `JANE SMITH` at the same address; cluster_v2 grouped them together. Resolution: **first-name split into sub-clusters**, then re-attempt match per sub-cluster.
- **Pattern C:** Address-shared but truly different people (e.g., apartment building). Resolution: **must remain held**; flag for human review.

**Recommended relaxation:**
1. Rank the RNC candidates by `SUM(norm_amount)` of cluster rows that match each RNC.
2. If the top RNC accounts for ≥80% of cluster dollars AND the runner-up is ≤2 rows: **assign the dominant RNC**, classify as `MATCHED_DOMINANT_RNC` tier.
3. If the cluster has multiple distinct first names at the same address: **split into household sub-clusters** before matching.
4. Otherwise: keep held. (Modeling estimate: ~50% of the 14,319 fall into Pattern A or B and become matchable.)

### 4.2 `zero_rnc_no_match` — 14,539 clusters / 51,291 rows / 24.1% (true dark)

**What it means:** No row in the cluster ever resolved to an RNC. These are donors whose name + address signature doesn't appear in DataTrust at all.

**Likely causes (not yet quantified, propose live verification):**
- Out-of-state donors who gave to NC committees but live in VA, SC, FL etc. — DataTrust NC won't have them.
- Donors who use a vacation home address or work address on the contribution form, but their voter registration address is different.
- Donors with name variations (nickname instead of legal first name; hyphenated last name without hyphen; female maiden vs married last name) that the join misses.
- Donors not registered to vote in NC (legal residents but unregistered).
- **PAC / committee-style contributions wrongly classified as individuals** — the `nonperson_or_aggregate_signal` regex catches some, but not all.

**Recommended relaxation (passes per the doctrine):**
1. **Pass 2 — mailzip5 vs reg zip:** Join on `norm_last + norm_first + datatrust.mailzip5 = pcd.norm_zip5` to catch donors who give from one address but vote from another.
2. **Pass 3 — Address-number match:** `norm_last + norm_first + house_number_regex(street_line_1)`. Catches different street spellings at the same numeric address.
3. **Pass 4 (deferred) — Email match (`email_dt`):** Blocked on Danny Gustafson at DataTrust; per doctrine.
4. **Out-of-state flag:** If `state ≠ 'NC'` and Pass 1-3 fail, classify as `DARK_OUT_OF_STATE` and stop trying to match against `core.datatrust_voter_nc`. Future: cross-reference RNC national if/when available.
5. **Nickname expansion:** Maintain a small lookup table (`Bob → Robert`, `Bill → William`, `Liz → Elizabeth`) and try Pass 1 with each expansion.
6. **Maiden-name fallback:** For female donors with `partner_last_name` differing from `legal_last_name` in the file, try both.

(Estimated yield: 30-40% of the 14,539 become matchable. Remaining stay `DARK_OUT_OF_STATE` or `DARK_NO_NC_REGISTRATION` — flag them, don't keep retrying.)

### 4.3 `reused_rnc` — 2,137 clusters / 5,738 rows / 3.5%

**What it means:** A single RNC is the unique candidate for >1 cluster_id_v2. The current gate blocks all but one cluster to prevent a single donor's RNC from being assigned to multiple distinct clusters.

**Sample from the dry-run:**
- `e29a7c91-943e-4873-a364-97a38caa20f0` is the only candidate RNC for cluster 5000504 (3 rows), 5000505 (10 rows), 5000507 (20 rows). All three almost certainly belong to the same person — but Stage 2 clustering split them.
- `05eb100d-0806-44f8-bb35-df1e0ee34f43` shows up across cluster 5000972 (11 rows) and 5000973 (13 rows). Same pattern.

**Recommended relaxation:**
- **MERGE clusters sharing an RNC** at the rollup layer. This is not a hard match decision — it's a clustering decision the upstream pipeline already failed to make. Create a cluster-merge table (`staging.committee_cluster_merge_proposals`) and resolve in batch.
- **Audit before merging:** Before merging, verify the rows in candidate clusters share `norm_last`, similar `norm_zip5`, and don't have suffix conflicts.

**Estimated yield:** ~80-90% of the 2,137 merge cleanly. Adds those cluster contents to the `MATCHED` pool.

### 4.4 `likely_household_conflict` — 329 clusters / 9,296 rows / 0.5%

**What it means:** Same `street_line_1 + zip5 + last_name` but **>1 first names**. The view detects this with `addr_narrow CTE`. The signal is genuine: two or more people with different first names share an address.

**Examples (from the data shape):** A husband-wife household where both donate from the joint address. Cluster 5005999 (Ed Broyhill canary) has 40 rows — but the QA shows MELANIE in cluster 5005999 = 0, meaning the household separation already happened correctly for the canary.

**Recommended relaxation:**
- **Split, don't reject:** Instead of holding the entire cluster, split rows by `norm_first` into sub-clusters. Each sub-cluster gets its own match attempt.
- **Retain household_key:** All sub-clusters share a derived `household_key = md5(lower(norm_zip5) || lower(street_line_1))` so downstream queries can re-aggregate the household when needed.
- **Spouse linkage as metadata:** Add `is_spouse_household_member = true` flag rather than blocking match.

**Estimated yield:** ~90% of the 9,296 rows become individually matchable.

### 4.5 `suffix_conflict` — 160 clusters / 2,585 rows / 0.3%

**What it means:** Cluster has rows with mixed suffix values (Sr, Jr, II, III, MD, etc.).

**The current logic treats this as "needs review."** That is incorrect for the case where Sr and Jr are both donating — they are two different people who happen to share `norm_first + norm_last`. The cluster grouped them; the gate then holds.

**Recommended relaxation:**
- **Suffix as separator, not blocker.** Split by `(norm_first, norm_last, norm_suffix)` tuple. Each gets its own match attempt.
- **Special canonical Broyhill case:** Per doctrine, "JAMES T / JAMES THOMAS BROYHILL" rows from `5033 Gorham Dr` are Ed's son (James II), separate person_key `JAMES_II_BROYHILL`. Sr (Ed's father, deceased) is `JAMES_SR_BROYHILL`. Encode this as a fixed override list in the rollup before generic suffix-split.

**Estimated yield:** ~95% become individually matchable.

### 4.6 `nonperson_or_aggregate_signal` — 537 clusters / 1,034 rows

**What it means:** Regex on the name flags PACs, LLCs, corporations, committees, foundations, trusts, "CASH", "AGGREGAT", "NON-ITEM". These should NOT be matched to DataTrust voters and the doctrine confirms: "no PACs, no independent committees, no 3rd-party orgs."

**Audit notes:**
- Current regex (from build SQL): `(CASH|AGGREGAT|NON-?ITEM|^\s*PAC(\s|$)|\bLLC\b|L\.L\.C|CORP\.?|INC\.?|COMMITTEE|FOUNDATION|TRUST|ACCOUNT|&\s*R\s*BLOCK|BLOCS?(\s|$))`
- Coverage looks good but worth checking: "ASSOCIATION", "PARTNERS", "GROUP", "ESTATE OF", "REVOCABLE TRUST" — the latter two appear in donor data and may slip through.

**Recommended action:** No relaxation; if anything, **strengthen** the regex by adding the patterns above. These are correctly held forever.

### 4.7 `needs_review` — 53 clusters / 3,716 rows

**What it means:** Catch-all for clusters where multiple soft signals fire simultaneously (e.g., high name variation AND >3 zip codes AND single RNC).

**Sample from the dry-run (cluster IDs):** 5003211, 5006003, 5008458, 5008640, 5008996, 5010654, 5014903, 5017251, 5018950, 5032607, 5042208, 5043110, 5044729, 5052004.

**Recommended action:** **Manual review of the 14 listed.** They are tractable individually (20-300 rows each). After manual disposition, encode the resolved pattern in the rollup logic so similar clusters auto-resolve next pass.

---

## 5. Canary status (from 2026-04-26 QA, all green)

| Canary | Expected | Observed | Status |
|---|---|---|---|
| `raw.ncboe_donations` cluster 372171 (Ed candidate spine) | 147 rows / $332,631.30 / RNC `c45eeea9-663f-40e1-b0e7-a473baee794e` | 147 / $332,631.30 / `c45eeea9-...` | ✓ |
| Ed committee canary cluster 5005999 | 40 rows / $155,945.45 / single RNC | 40 / $155,945.45 / `c45eeea9-...` | ✓ |
| Pope committee canary cluster 5037665 | 22 rows / $378,114.05 / single RNC | 22 / $378,114.05 / `3cea201e-8cdd-49e0-aceb-dfa6e7072f68` | ✓ |
| MELANIE in Ed cluster 5005999 (must be 0) | 0 | 0 | ✓ |
| KATHERINE in Pope cluster 5037665 (must be 0) | 0 | 0 | ✓ |
| `committee_name_resolved` nulls | 0 | 0 / 293,396 | ✓ |

All canaries intact. No data corruption observed.

---

## 6. Recommended path forward (for Perplexity to plan, Cursor to execute)

These are proposed dry-runs only. None of these change `raw.ncboe_donations`, `core.di_donor_attribution`, `core.donor_attribution`, or `donor_intelligence.person_master`. All proposed changes are to `staging.ncboe_party_committee_donations` and additional `staging` views.

### Step 1 — Apply the existing 4,293 apply-eligible clusters (already designed)
- Already prepared in `committee_donor_cluster_rollup_match_apply.py`.
- Two-layer + exact-phrase protocol in place.
- After apply: matched goes from 23,871 → ~28,164 (47%).
- **Authorization required:** Ed types `AUTHORIZE` (per current protocol).

### Step 2 — Suffix split (Priority 1 relax, ~160 clusters / 2,585 rows)
- Compute `(norm_first, norm_last, norm_suffix)` sub-clusters.
- Add column `suffix_split_id_v2`.
- Re-attempt match per sub-cluster.
- Ed's family overrides hardcoded (James Sr → `JAMES_SR_BROYHILL`, James II → `JAMES_II_BROYHILL`).
- Expected yield: ~152 clusters newly matched.

### Step 3 — Household split (Priority 2 relax, ~329 clusters / 9,296 rows)
- Detect `(street_line_1, norm_zip5, norm_last)` groups with ≥2 distinct `norm_first`.
- Add `household_key` and `first_name_split_id_v2` columns.
- Re-attempt match per first-name-split sub-cluster.
- Expected yield: ~290 clusters newly matched (multiple matches possible per original cluster).

### Step 4 — Reused-RNC merge (Priority 3 relax, ~2,137 clusters / 5,738 rows)
- Build merge proposal table: clusters that share their unique RNC candidate.
- Verify no suffix conflict between proposed-merge clusters.
- Apply: rewrite `cluster_id_v2` to the lowest cluster_id in each merge group.
- Expected yield: ~1,900 clusters newly matched (counted as merged-then-matched).

### Step 5 — Multi-RNC dominance tiebreak (Priority 4 relax, ~14,319 clusters / 51,099 rows)
- For each multi-RNC cluster, rank candidate RNCs by `SUM(norm_amount)` of supporting rows.
- If top RNC ≥80% dollar share AND runner-up ≤2 rows: assign top RNC, mark `match_tier_v2 = T7_DOMINANT`.
- Expected yield: ~7,000 clusters newly matched.

### Step 6 — Pass 2/3 (mailzip5 + address-number) on zero-RNC pile (Priority 5 relax, ~14,539 clusters / 51,291 rows)
- Pass 2: `norm_last + norm_first + datatrust.mailzip5 = pcd.norm_zip5` join.
- Pass 3: `norm_last + norm_first + extracted_house_number` join.
- Apply per match-tier (T8 mailzip, T9 address-num).
- Expected yield: ~5,000 clusters newly matched.

### Cumulative model after Steps 1-6
| Step | New matched clusters | Cumulative match % |
|---|---:|---:|
| Baseline | 23,871 | 39.6% |
| Step 1 (apply existing) | +4,293 | 46.8% |
| Step 2 (suffix split) | +152 | 47.0% |
| Step 3 (household split) | +290 | 47.5% |
| Step 4 (reused-RNC merge) | +1,900 | 50.6% |
| Step 5 (multi-RNC dominance) | +7,000 | 62.2% |
| Step 6 (mailzip5 + addr-num) | +5,000 | **70.5%** |

**Target: 70% match rate (vs current 39.6%).** Remaining ~30% is true dark — out-of-state, unregistered, or genuinely unresolvable without `email_dt` (Danny Gustafson reply blocking).

---

## 7. Open questions for Perplexity

1. **Step ordering:** Should Step 1 (apply existing 4,293) be locked in before Steps 2-6, or do we want to wait and run all six as one orchestrated batch?
2. **Step 5 dominance threshold:** Is 80% dollar-share the right cut, or should we test 75% / 85%? Sensitivity-test on 50 clusters first?
3. **Step 6 — out-of-state cap:** Confirm: if a donor has `state ≠ 'NC'` and no NC voter registration, do we mark them `DARK_OUT_OF_STATE` and stop, or maintain a thin pointer for future RNC-national matching?
4. **Suffix override list:** James Sr / James II Broyhill is one. Are there other family-office distinctions Ed has called out that need explicit overrides before generic suffix-split?
5. **Index creation authorization:** The four index recommendations in §2.3 — does Ed want them created now (Cursor, with AUTHORIZE) or after the dryrun loops?

---

## 8. Files referenced in this audit

- `scripts/committee_donor_rollup_v1_build.sql`
- `scripts/committee_donor_rollup_v1_qa.sql`
- `scripts/committee_donor_cluster_rollup_match_apply.py`
- `docs/runbooks/COMMITTEE_DONOR_ROLLUP_V1_PLAN.md`
- `docs/runbooks/committee_donor_rollup_v1_qa_20260426.md`
- `docs/runbooks/committee_donor_cluster_rollup_match_apply_dryrun_20260426.md`
- `docs/runbooks/COMMITTEE_INGESTION_RUNBOOK_V4.md`
- `docs/DONOR_TABLE_NAMING_DOCTRINE.md`
- GitHub: `PERPLEXITY_HANDOFF_2026-04-26_PHASE_BCD.md`
- GitHub: `CURSOR_HANDOFF_2026-04-26_PHASE_B_REVIEW.md`

---

## 9. What this audit did NOT do (and why)

- **No live Hetzner queries.** This session does not have SSH/Postgres access to `37.27.169.232`. All numbers above come from the file-based artifacts written by yesterday's QA + dry-run. **Cursor should re-verify on the live DB before any apply.**
- **No proposed UPDATE / DELETE / TRUNCATE / ALTER on production.** Steps in §6 are dry-run targets only.
- **No writes to `raw.ncboe_donations`** — read-only canary respected.
- **No writes to `core.*`, `archive.*`, `donor_intelligence.*`** — out of scope per doctrine.
- **No Stage 4 propagation, no `_v2`→canonical swap, no FEC, no Acxiom materialization, no scoring.**

---

_End of audit. Hand to Perplexity for orchestration; Cursor for execution under Ed's `AUTHORIZE` once a step is approved._
