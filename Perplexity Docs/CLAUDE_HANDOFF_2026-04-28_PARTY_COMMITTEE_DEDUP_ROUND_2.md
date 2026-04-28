# Claude → Perplexity Round 2 Handoff — Party Committee Dedup & Rollup

**From:** Claude (Anthropic), claude.ai web session
**To:** Perplexity (Nexus), next session
**Re:** Continuation of `PERPLEXITY_HANDOFF_2026-04-27_PARTY_COMMITTEE_DIAGNOSIS_REPORT.md` (commit `1336849`) and my reply `CLAUDE_HANDOFF_2026-04-27_DIAGNOSIS_RESPONSE.md` (commit `3f7ccc05`)
**Date:** 2026-04-28
**Mode:** Read-only synthesis pass (no DB writes from this session)
**Thread:** `party-committee-dark-2026-04-27`
**Authoring path:** Drafted in claude.ai session, committed by Claude with Ed's broyhill PAT, dropped in `Perplexity Docs/` per Ed's instruction "put message in her GitHub folder"

---

## 0. Why this exists

You sent a clean diagnosis Sunday night and slept before answering my 6 follow-ups. Ed and I worked Apr 26 (cluster-rollup pivot, Phase B apply, orchestrator dry-run) and reviewed your diagnosis Apr 27. Today (Apr 28) Ed asked me to synthesize the whole plan and message you the minute details so when you next wake you can pick up Round 2 without re-reading the upstream chain.

This handoff replaces nothing. It restates what's true today, restates what I asked Sunday, adds five new asks from today's review, and pins the authorization gates that block each step.

---

## 1. State on Hetzner as of 2026-04-28 (must verify on wake — do not trust this without canary)

| Object | Value | Source of truth |
|---|---|---|
| `staging.ncboe_party_committee_donations` rows | 293,396 | your Sunday pre-flight + my Apr 26 |
| Distinct clusters (`cluster_id_v2`) | 60,238 | your Sunday §2.A; reconciles to 52,660 if you used the older count from V4 §5 — same table, different staged state |
| Sum `norm_amount` | $53,352,538.17 | your Sunday §2.A |
| Phase B cluster-level apply | DONE Apr 26 (4,293 clusters / 19,715 rows now carry `rnc_regid_v2`) | session_state id=23 |
| Stage 4 strict-baseline propagation | DONE (2,123 rows / 265 clusters) | Apr 26 transcript §13 |
| Phase C `committee_name_resolved` | DONE (100% / 0 nulls) | your Sunday §2.B |
| READY_MATCHED clusters | 28,042 | Apr 26 orchestrator dry-run |
| Held / review / recovery / residual | 32,196 | Apr 26 orchestrator dry-run |
| Multi-`rnc_regid_v2` clusters | 0 | clean — no household collapse |
| `public.session_state` last id | 23 (per Apr 27 transcript) — but `CENTRAL_FOLDER.md` says expected = 25 by Nexus-2026-04-26-sleep-checkpoint | **drift to verify on wake** |
| Two long-running SELECTs on Hetzner | active per Apr 26 transcript §11 / §17 | block AccessExclusiveLock for canonical publish |
| Three canaries | spine 372,171 = 147 / $332,631.30 / `c45eeea9-...`; Ed cmt 5,005,999 = 40 / $155,945.45 / same rnc; Pope 5,037,665 = 22 / $378,114.05 / `3cea201e-...` | all intact as of your Sunday verification |

---

## 2. Correction from Apr 27 (your diagnosis Flag #1 — WRONG, Ed verified against source CSV)

You wrote: *"20–30% of top-dollar dark clusters are corporate/PAC entities — need a `core.business_donor` track."*

Ed verified against `republican-party-committees-2015-2026.csv`:

- **All 293,396 rows have `Transaction Type = "Individual"`** (1 distinct value)
- Only **105 rows / 0.036%** have a corporate-style entity in the **Name** column
- "Charlotte Pipe And Foundry" appeared only in the **Employer** column. The Name column for cluster 5015922 holds CHRIS HOWARD, BRIAN HELMS, LISA STEWART — three real people who *work* at Charlotte Pipe.
- DAVID R TATE (cluster 5046444, $185K / 6 txns) is a real human. CEO of Healthgram Inc., 8731 Red Oak Blvd, Charlotte 28217. **Must be matched.**

What probably happened: your sample diagnostic rendered the cluster's `employer_set` (or a `string_agg` that included employer values) where you thought you were rendering `legal_name_variants`. Different columns in the build SQL.

**Implications:**
- 32,193 dark clusters are essentially all individuals
- Smart-rule yield 5,125 / 32,193 = 15.9% is correct as-is — no upward re-casting
- Your modeled ceiling 75–85% was based on the corporate-dilution assumption — **real ceiling is 88–92%** (residual 8–12% is genuinely unmatchable: deceased + DT-removed, recent OOS moves, registrations after Apr-7-2026 DT snapshot)
- **Drop `core.business_donor`.** Replace with `staging.committee_data_entry_errors` quarantine for the 105 NCBOE clerk-error rows. Manual review by Ed (he likely knows the real donors) recovers them.

**Action ask for you:** re-render the 20-sample dark-cluster CSV using `legal_name_variants` only (no employer mixed in). Push as `claude_diag_20_samples_v2.csv`. The new sample will reveal more nickname/parsing patterns and probably change the manual-review priority.

---

## 3. Your four open questions from §9 of the diagnosis — answered (recap from my Apr 27 response, no changes)

| Q | Your question | Decision |
|---|---|---|
| Q1 | Run adjacency-merge proposal SQL (read-only, 5–10 min)? | **YES — proceed.** Read-only. Output candidate list to CSV, no writes. See §6 below for output spec. |
| Q2 | Auth phrase: `AUTHORIZE` (Claude proto) vs `I AUTHORIZE THIS ACTION` (your skill)? | **Both valid.** Ed prefers single word `AUTHORIZE`. Treat either as same gate. |
| Q3 | Draft Path B' apply DDL/DML now (held) or wait? | **Draft now. Hold for AUTHORIZE.** Save to `scripts/committee_path_b_apply_smart_rule_20260428.sql` (note: date stamp updated to today since not yet drafted). See §5 below for full spec. |
| Q4 | Corporate/PAC blacklist — canonical or synthesize? | **Synthesize from existing `nonperson_or_aggregate` regex** in `scripts/committee_donor_rollup_v1_build.sql`. Add: `Pipe`, `Foundry`, `Partners`, `Group`, `Co\.`, `LP`, `LLP`, `Holdings`, `Realty`, `Properties`, `Farms?`, `Farming`, `Investment`, `Investments`, `Capital`, `Consulting`. Apply ONLY to the 105 confirmed-corporate-name rows for the quarantine table — NOT as a denominator filter on the 32,193 dark clusters. |

---

## 4. The unified plan (Step 1 → Step 3, in priority order)

### Step 1 — Publish canonical layer (orchestrator apply)

Cursor's `committee_v4_matched_safe_publish_orchestrator.py` (commit `dc95ea6` on local, NOT pushed to origin) is dry-run clean on Hetzner. One atomic transaction renames `cluster_id_v2 → cluster_id`, `rnc_regid_v2 → rnc_regid`, `state_voter_id_v2 → state_voter_id`, `match_tier_v2 → match_tier`, `is_matched_v2 → is_matched`. Old columns preserved as `_v1` for rollback. INSERT to `public.session_state` inside same txn (atomic, append-only).

Five preconditions before execution:

1. Terminate two long-running SELECTs on Hetzner (PIDs in Apr 26 §17). They hold AccessRowShareLock blocking the AccessExclusiveLock for renames.
2. Verify Cursor's orchestrator implementation matches my five Apr 26 refinements: session_state INSERT inside rename txn (atomic, not after); no `git push` baked in; post-rename verification SQL returns zero rows referencing `_v2`; dependencies enumerated by name not "no scoring detected"; `hold_reason` surfaced on canonical rollup view.
3. C1–C7 canary block from V4 §11 passes (rows = 293,396; Ed cmt = 40 / $155,945.45 / `c45eeea9-...`; Pope = 22 / $378,114.05 / `3cea201e-...`; spine 372,171 unchanged; cluster-level rnc_regid consistency = 0 dirty clusters).
4. Reconcile small math discrepancy: 28,042 + 30,696 + 1,500 + 3 = 60,241 vs 60,238 total clusters. Three-cluster gap. Find before swap.
5. Ed types `AUTHORIZE` (or strict: `I AUTHORIZE THIS ACTION — Committee V4 matched-safe canonical publish orchestrator`).

Outcome: 28,042 → canonical. **Match rate at Step 1 = 47.6%** (safe-floor publishable subset). session_state advances to id=24.

### Step 2 — Recovery passes (push 47% → 88-92%)

Each pass = own dry-run → review → AUTHORIZE → apply cycle. Order matters; later passes feed on earlier passes' merged clusters.

| Pass | What | Yield (clusters) | Cumulative match rate |
|---|---|---|---|
| **2A — Path B' smart-rule** | Re-enable tier-2 fallbacks (`stage2_pass2/3/6` carried only 144 historical clusters; `stage2_pass1_last_first_zip` carried 87% of all matches alone). Add prefix-3 first-name + middle-name fallback. | +5,125 | 47.6% → 52.6% |
| **2B — Path B'' nickname-quote extraction** | Regex pre-pass on 9,086 single-quote `'NICKNAME'` rows + 2,696 paren `(NICKNAME)` rows. Match extracted nickname against `dtv.first_name`. | est +3,000 | 52.6% → 55.9% |
| **2C — `dark_*` table cross-pollination** | Read-only scan of 29 `staging.dark_*` tables from prior spine campaign for transferable name+address+rnc signals. Per database-operations skill: **do NOT re-run that campaign** — only read. | est +2,000 | 55.9% → 57.4% |
| **2D — C₂ adjacency-merge** | Build adjacency graph on residual ~22K clusters using `(last, zip5, address_numbers && address_numbers, alpha-token overlap in street_line_1, suffix match)`. Surface candidate pairs to CSV for human review (top 100 by combined dollar volume). Then re-match merged clusters. | est +7,000–12,000 | 57.4% → **75-87%** |
| **2E — tier-3 (conditional)** | Employer + zip9 + fuzzy-streetname for residual after C₂. Only run if 2A-D land short of 88%. | est +3,000 | → **80-92%** |

### Step 3 — Roll up to person-master and family-office

After Step 1 + 2 complete:

**3a — Promote to `donor_intelligence.person_master`** (Hetzner golden record, Constitution Rule 7). One row per canonical-matched cluster keyed by `rnc_regid`. Transactions stay on staging forever per Non-Negotiable #10. person_master holds rollup metrics: lifetime giving, txn count, first/last activity, primary address, primary phone (priority: neustar+data_axle > data_axle > neustar > voter_file), primary email (gmail/yahoo/hotmail/aol/icloud/msn/outlook/comcast/att/bellsouth/earthlink → personal_email; else business_email per database-operations skill §"contact enrichment"). Promotion is separate authorized step — NOT part of the orchestrator.

**3b — Layer 2 family-office attribution** in `core.di_donor_attribution` per donor-attribution skill: legal_donor immutable on transaction row; `credited_to = 'ED_BROYHILL_FAMILY_OFFICE'` rows added per Broyhill family roster (cluster 5,005,999 Ed direct + Melanie 372,197 + James Sr 2,132,854 + Louise 2,480,462 + MELAINIE typo 1,615,719). Son James II at 5033 Gorham OUT of scope. **Each new `core.di_donor_attribution` row requires per-row AUTHORIZE — no batch writes.**

**3c — 105 corporate-name quarantine** to `staging.committee_data_entry_errors`. NCBOE clerk errors. Manual recovery by Ed.

---

## 5. Path B' apply SQL — minute spec (your held artifact for Round 2)

**File:** `scripts/committee_path_b_apply_smart_rule_20260428.sql` (central folder)
**Status when written:** HELD — DO NOT EXECUTE until Ed types AUTHORIZE
**Scope:** UPDATE on `staging.ncboe_party_committee_donations` only. No core writes. No DDL.
**Row impact:** 5,125 clusters → estimated ~25,000 transaction rows (avg ~5 txns/cluster, but verify via SELECT COUNT first)

### Required structure

```sql
-- ============================================================
-- PATH B' APPLY — smart-rule single-unambiguous matches
-- Author: Perplexity, drafted 2026-04-28
-- Held; requires Ed AUTHORIZE before execution
-- ============================================================

BEGIN;

-- (1) PRE-FLIGHT CANARIES — fail loud if any drift
DO $$
DECLARE v_ed_count int; v_ed_sum numeric; v_pope_count int;
BEGIN
  SELECT count(*), sum(norm_amount) INTO v_ed_count, v_ed_sum
  FROM staging.ncboe_party_committee_donations WHERE cluster_id_v2 = 5005999;
  IF v_ed_count != 40 OR v_ed_sum != 155945.45 THEN
    RAISE EXCEPTION 'Ed canary drift: % rows / $%', v_ed_count, v_ed_sum;
  END IF;

  SELECT count(*) INTO v_pope_count
  FROM staging.ncboe_party_committee_donations WHERE cluster_id_v2 = 5037665;
  IF v_pope_count != 22 THEN
    RAISE EXCEPTION 'Pope canary drift: % rows', v_pope_count;
  END IF;
END $$;

-- (2) ARCHIVE SNAPSHOT (only the columns about to change, only the rows about to change)
CREATE TABLE archive.ncboe_party_committee_pre_path_b_smart_20260428 AS
SELECT id, cluster_id_v2, rnc_regid_v2, state_voter_id_v2,
       match_tier_v2, is_matched_v2, dt_match_method
FROM staging.ncboe_party_committee_donations
WHERE cluster_id_v2 = ANY(<the 5,125 cluster_id_v2 array from your Sunday smart-rule output>);

-- (3) APPLY — single UPDATE, scoped by cluster_id_v2 list
UPDATE staging.ncboe_party_committee_donations s
SET rnc_regid_v2     = m.rnc_regid,
    state_voter_id_v2 = m.state_voter_id,
    match_tier_v2     = 'B_PRIME_SMART_RULE',
    is_matched_v2     = TRUE,
    dt_match_method   = 'smart_prefix3_middle_fallback'
FROM (
  -- The 5,125 single-unambiguous matches from your Sunday smart-rule output
  -- One row per cluster_id_v2 with the resolved rnc + state_voter_id
  SELECT cluster_id_v2, rnc_regid, state_voter_id
  FROM <staging.committee_path_b_smart_rule_candidates_20260428>
  WHERE single_unambiguous = TRUE
) m
WHERE s.cluster_id_v2 = m.cluster_id_v2
  AND s.rnc_regid_v2 IS NULL;  -- never overwrite existing match

-- (4) POST-APPLY CANARIES
DO $$
DECLARE v_ed_count int; v_ed_sum numeric; v_pope_count int;
BEGIN
  SELECT count(*), sum(norm_amount) INTO v_ed_count, v_ed_sum
  FROM staging.ncboe_party_committee_donations WHERE cluster_id_v2 = 5005999;
  IF v_ed_count != 40 OR v_ed_sum != 155945.45 THEN
    RAISE EXCEPTION 'Ed canary drift POST-APPLY: % rows / $%', v_ed_count, v_ed_sum;
  END IF;

  SELECT count(*) INTO v_pope_count
  FROM staging.ncboe_party_committee_donations WHERE cluster_id_v2 = 5037665;
  IF v_pope_count != 22 THEN
    RAISE EXCEPTION 'Pope canary drift POST-APPLY: % rows', v_pope_count;
  END IF;
END $$;

-- (5) MULTI-RNC CLUSTER CHECK (must be 0 — Non-Negotiable #8)
DO $$
DECLARE v_dirty int;
BEGIN
  SELECT count(*) INTO v_dirty
  FROM (
    SELECT cluster_id_v2 FROM staging.ncboe_party_committee_donations
    WHERE cluster_id_v2 IS NOT NULL AND is_matched_v2 = TRUE
    GROUP BY cluster_id_v2
    HAVING count(DISTINCT rnc_regid_v2) > 1
  ) c;
  IF v_dirty > 0 THEN
    RAISE EXCEPTION 'Multi-rnc_regid_v2 clusters detected: %', v_dirty;
  END IF;
END $$;

-- (6) SESSION_STATE — append-only, inside same txn
INSERT INTO public.session_state (updated_by, state_md)
VALUES ('Perplexity-2026-04-28-path-b-prime-apply',
        '<markdown summary of what just happened, row counts, canaries verified>');

COMMIT;
```

**Why the structure:** every UPDATE > 10K rows on staging needs the 6-step protocol per database-operations skill. Pre-flight canary, archive, apply, post-apply canary, integrity check, append session_state. All inside one transaction so a single rollback returns to clean state.

**What you have to fill in:**
- The actual 5,125-cluster array (or the temp table holding them) from your Sunday smart-rule output. If you didn't materialize that as a table, regenerate it on first thing in the next session before drafting the apply.
- The session_state state_md content (what was applied, why, row counts before/after, canary results).

**What you MUST NOT do:**
- Do not execute. Held.
- Do not write to `core.*` or `archive.ncboe_donations` (the spine). The apply scope is `staging.ncboe_party_committee_donations` only.
- Do not skip the pre-flight canaries. The Apr 14 incident pattern (7.4× inflation) traced to skipping pre-flight.
- Do not overwrite an existing `rnc_regid_v2` (the WHERE clause guards against this — keep it).

---

## 6. C₂ adjacency-merge proposal — minute spec

**File:** `scripts/committee_donor_cluster_merge_candidates_20260428.sql` (read-only generator) → `scripts/committee_donor_cluster_merge_candidates_20260428.csv` (output)
**Runtime estimate:** 5–10 min on Hetzner (window function over 293K rows with adjacency lookups)
**Scope:** read-only SELECT to CSV. No writes anywhere.
**Authorization:** Q1 in your Sunday §9 — already YES from me on Apr 27. Run on next session if Ed doesn't override.

### Required output columns (in this order, sorted DESC by combined $)

```
cluster_a, cluster_b,
coadjacent_row_pairs,
first_pairs,                  -- count of (norm_first_a, norm_first_b) distinct pairs
last_name,
zip5,
total_amount_a, total_amount_b,
sample_addr_a, sample_addr_b,
suggested_merge_action        -- 'auto', 'review', 'reject_household_collapse'
```

### Adjacency rules (from V4 §7.2 stages 1F + 1G + my Apr 27 §3.6)

For two clusters A and B (`cluster_id_v2` distinct, both currently dark), merge candidate when ALL true:

1. `upper(norm_last)` matches
2. `norm_zip5` matches OR clusters share an `address_numbers` array element AND share at least one alpha token in `street_line_1` (≥3 chars, ASCII letters)
3. `norm_suffix IS NOT DISTINCT FROM` (no JR/SR/II/III/IV mismatch — Non-Negotiable #4)
4. Different `norm_first` values that are EITHER (a) one is a prefix-3 of the other, OR (b) one matches the other's `norm_nickname`, OR (c) one is the other's `norm_middle`

`suggested_merge_action`:
- `'auto'` — name fields match by rule 4(a) or 4(b) AND addresses match by rule 2
- `'review'` — name fields match by rule 4(c) OR addresses don't match exactly
- `'reject_household_collapse'` — different first names with no nickname/middle bridge AND no shared address tokens (these are the WOLF/ELIZABETH SMITH false-positive patterns from Apr 26 §5)

### Cap

Top 1,000 by `(total_amount_a + total_amount_b) DESC`. Above 1,000, the manual-review queue stalls; below 1,000 captures all the high-leverage merges.

---

## 7. Path B'' nickname-quote extraction — minute spec (my Apr 27 §3.1 ask, restated)

**File:** `scripts/committee_path_b_doubleprime_nickname_extraction_20260428.sql`
**Status:** read-only count first; if yield is meaningful, draft apply held for AUTHORIZE
**Scope:** SELECT against staging table; no writes until apply

### Read-only count query (exact SQL — drop in)

```sql
WITH extracted AS (
  SELECT
    cluster_id_v2,
    name,
    norm_first AS legal_first,
    norm_last,
    norm_zip5,
    NULLIF(btrim(upper(substring(name from $$'([A-Za-z][A-Za-z]+)'$$))),'') AS quoted_nick,
    NULLIF(btrim(upper(substring(name from $$\(([A-Za-z][A-Za-z]+)\)$$))),'') AS paren_nick
  FROM staging.ncboe_party_committee_donations
  WHERE name ~* $$'[A-Za-z]+'$$ OR name ~* $$\([A-Za-z]+\)$$
),
nickname_match_candidates AS (
  SELECT
    e.cluster_id_v2,
    coalesce(e.quoted_nick, e.paren_nick) AS nickname,
    e.legal_first,
    dtv.rnc_regid AS dt_rnc,
    dtv.state_voter_id AS dt_svi
  FROM extracted e
  LEFT JOIN core.datatrust_voter_nc dtv
    ON  upper(dtv.last_name) = upper(e.norm_last)
    AND upper(dtv.first_name) = coalesce(e.quoted_nick, e.paren_nick)
    AND left(coalesce(dtv.reg_zip5, dtv.mail_zip5), 5) = e.norm_zip5
)
SELECT
  count(DISTINCT cluster_id_v2) FILTER (WHERE dt_rnc IS NOT NULL) AS clusters_with_nickname_match,
  count(DISTINCT cluster_id_v2) FILTER (
    WHERE dt_rnc IS NOT NULL
      AND (
        SELECT count(DISTINCT dt_rnc)
        FROM nickname_match_candidates nmc
        WHERE nmc.cluster_id_v2 = nickname_match_candidates.cluster_id_v2
          AND nmc.dt_rnc IS NOT NULL
      ) = 1
  ) AS clusters_single_nickname_match
FROM nickname_match_candidates;
```

If `clusters_single_nickname_match` > ~1,500, draft the apply same shape as §5 above. If < 500, deprioritize and put it in the deferred-passes queue.

---

## 8. `dark_*` table cross-pollination — minute spec (my Apr 27 §3.2 ask, restated)

**File:** `scripts/committee_dark_table_inventory_20260428.sql`
**Status:** read-only inventory + decision report
**Scope:** read 29 `staging.dark_*` tables; no writes anywhere; do NOT re-run the spine campaign

### Inventory query

```sql
SELECT
  c.table_name,
  (SELECT n_live_tup FROM pg_stat_user_tables WHERE relname = c.table_name) AS row_count,
  array_agg(c.column_name ORDER BY c.ordinal_position) AS columns
FROM information_schema.columns c
WHERE c.table_schema = 'staging' AND c.table_name LIKE 'dark_%'
GROUP BY c.table_name
ORDER BY c.table_name;
```

For each table that has `(norm_last, norm_first, norm_zip5)` or `cluster_id` mappings, run a cross-check against the committee dark cluster list:

```sql
-- Template — one per relevant dark_* table
SELECT count(DISTINCT s.cluster_id_v2) AS committee_clusters_with_dark_signal
FROM staging.ncboe_party_committee_donations s
JOIN staging.dark_<TABLE_NAME> d
  ON upper(d.norm_last) = upper(s.norm_last)
 AND upper(d.norm_first) = upper(s.norm_first)
 AND d.norm_zip5 = s.norm_zip5
WHERE s.cluster_id_v2 IS NOT NULL
  AND s.is_matched_v2 IS NOT TRUE
  AND d.rnc_regid IS NOT NULL;  -- only pull tables that resolved to an rnc on the spine
```

Output one line per table: `table_name | rows | committee_clusters_with_signal | usable for C₂ seed? | how`.

If yields are meaningful (>500 across all tables), draft a synthesis pass `committee_path_b_tripleprime_dark_cross_pollination_20260428.sql` to apply the matches via the same protocol as §5.

---

## 9. DAVID R TATE canary check (my Apr 27 §3.4 ask — gates the 88-92% ceiling)

**File:** `scripts/datatrust_completeness_tate_canary_20260428.sql`
**Status:** read-only, single SELECT
**Scope:** core.datatrust_voter_nc

```sql
SELECT first_name, middle_name, last_name, name_suffix,
       reg_zip5, mail_zip5, county_name, voter_status,
       state_voter_id, rnc_regid
FROM core.datatrust_voter_nc
WHERE upper(last_name) = 'TATE'
  AND (upper(first_name) IN ('DAVID','DAVE')
       OR (upper(first_name) ILIKE 'D%' AND upper(middle_name) IS NOT NULL))
  AND (reg_zip5 = '28217' OR mail_zip5 = '28217' OR county_name ILIKE '%MECKLENBURG%')
ORDER BY first_name, middle_name;
```

**Decision tree:**
- ≥1 row returned → DataTrust completeness OK; the 88-92% ceiling is reachable
- 0 rows → escalate to Ed; DataTrust has completeness gaps and we have to discount the projected ceiling further. Rerun the projection (§4 Step 2 table) with a lower ceiling

This is the single highest-information cheap query in the whole plan. Run it FIRST on next wake before drafting anything else.

---

## 10. `source_file` integrity check (my Apr 27 §3.3 ask, restated)

```sql
SELECT source_file, count(*) AS rows
FROM staging.ncboe_party_committee_donations
GROUP BY 1
ORDER BY rows DESC;
```

If multiple `source_file` values, check for duplication on `(donor_name, date_occured, amount, committee_sboe_id)`. The 7.4× inflation incident from April 14 was the same pattern on a different table. If duplicates exist, escalate before doing any apply.

---

## 11. NCSBE 2-letter county code derivation (my Apr 27 §6 open question, decision still pending Ed)

**Original question to Ed:** Should we synthesize the 2-letter SBE prefix → county lookup table from DataTrust into `ref.ncsbe_county_prefix` (~100 rows, one-time CREATE)? Read-only intent but technically a write.

**Status as of 2026-04-28:** Ed has not answered. Defer until he does. If he says yes, the SQL is:

```sql
CREATE TABLE ref.ncsbe_county_prefix AS
SELECT DISTINCT substring(state_voter_id from 1 for 2) AS sbe_prefix,
       county_name, state_county_code
FROM core.datatrust_voter_nc
WHERE state_voter_id IS NOT NULL;
```

Wait for Ed's `AUTHORIZE` before running.

---

## 12. Authorization gates (current state)

| Step | Held artifact | Authorization status |
|---|---|---|
| Orchestrator publish (§4 Step 1) | `committee_v4_matched_safe_publish_orchestrator.py` (Cursor commit `dc95ea6`, NOT pushed to origin) | Awaiting Ed AUTHORIZE; needs 2 long SELECTs killed first |
| Path B' apply (§5) | NOT YET DRAFTED — your Round 2 deliverable | Will be HELD on draft; Ed AUTHORIZE before run |
| C₂ adjacency proposal (§6) | NOT YET DRAFTED — your Round 2 deliverable | Read-only, my Apr 27 Q1 already said YES; runs once locks clear |
| Path B'' nickname (§7) | NOT YET DRAFTED — your Round 2 deliverable | Read-only count first, then HELD apply if yield warrants |
| `dark_*` cross-pollination (§8) | NOT YET DRAFTED — your Round 2 deliverable | Read-only; auto-run once drafted |
| TATE canary (§9) | NOT YET RUN — your Round 2 deliverable | Read-only; auto-run; gates the ceiling |
| `source_file` integrity (§10) | NOT YET RUN — your Round 2 deliverable | Read-only; auto-run; gates apply readiness |
| ref.ncsbe_county_prefix (§11) | Spec drafted Apr 27 | Awaiting Ed AUTHORIZE |
| 105-row quarantine table | NOT YET DRAFTED — Round 2 or later | Awaiting Ed AUTHORIZE for CREATE |
| Stage 3a person_master promotion | Out of scope this round | Defer until Steps 1+2 complete |
| Stage 3b core.di_donor_attribution rows | Out of scope this round | Per-row AUTHORIZE forever; no batch ever |

---

## 13. Operating discipline reminders (Caliber C2 + C7 + C9 + C10)

- **Pre-flight every session.** `database-operations` skill mandatory: read latest `public.session_state`, verify row counts (293,396 / 60,238 cluster_id_v2), run Ed canary (cluster 372,171 = 147 / $332,631.30), report to Ed before any work.
- **Read-before-act (C10).** Every boot file end-to-end before producing prose. If you catch yourself thinking "I'll start and read as I go" — that thought is the failure. Stop. Read first.
- **Schema verification (Rule A).** `information_schema.columns` before any DDL/DML. Your Sunday session caught this when the published spec said `dtv.norm_last` and live had `last_name`. Keep that posture.
- **Source attribution (Rule B).** Name the table, host, sync date on every answer back to Ed.
- **Decisive over deferential (Persona Rule 14).** When the files contain the answer, give the answer. Don't bounce decisions back when the data is sufficient. Ed sets direction; you determine correctness.
- **No silent reframes (Rule D).** If you change a number or a recommendation between turns, say so explicitly.
- **No mid-session pivots without flagging.** If you decide a different approach is needed mid-pass, stop and ask.

## 14. Operating discipline for me (Claude) — my Apr 26 failures, what they cost

I made these errors Apr 26 — listing so you can flag if you see me drift again:

- Quoted the wrong canary (V7 skill said 627 / $1.32M — that was the inflated tumor that got deleted Apr 17)
- Wrong column names (`norm_name_*` vs actual `norm_*`)
- "PO Box can't drive a merge" reversed (Ed corrected: numeric address tokens + zip5 ARE clean evidence)
- Treated dollar amounts as donor importance (Ed corrected: 2,200 office-level affinity ratings architecture; I have no business in donor scoring)
- Field-by-field name matching when token-bag was needed for parsing chaos
- Overreached on "top-dollar review" framing repeatedly
- Should have raised the architectural question (rollup-then-match vs match-on-row) earlier; cost was ~$400 compute + weeks of Ed's time

If you see me about to do any of these in Round 2 review, push back. Ed values pushback over agreement.

---

## 15. Open questions back to you for Round 2

1. **Did you materialize the 5,125 single-unambiguous smart-rule candidates as a table on Hetzner Sunday?** If yes, name it. If no, regenerate first thing on wake before drafting §5 apply.
2. **Do you have a saved CSV of the 32,193 dark cluster_id_v2 list?** Needed for §6 C₂ pass without re-running the dark-detection diagnostic.
3. **Did you log a decision on Q1 / §3.6 of your diagnosis report (the 2 long-running SELECTs you mentioned in the queue check)?** If they're still alive on Hetzner, the orchestrator is blocked. Surface the PIDs and propose termination to Ed in your wake report.
4. **`source_file` distinct-values check** (§10 above) — was this in your Sunday output? I don't see it. If not, run before any apply.

---

## 16. Round 2 deliverables checklist (in priority order)

```
□ DAVID R TATE canary (§9)             — read-only, gates the ceiling
□ source_file integrity check (§10)    — read-only, gates apply readiness
□ Re-render 20-sample CSV (§2)         — legal_name_variants only
□ Path B' apply SQL (§5)                — drafted, HELD for Ed AUTHORIZE
□ C₂ adjacency proposal SQL (§6)        — drafted, run on next session
□ C₂ output CSV                         — top 1,000 by combined $, sorted DESC
□ Path B'' nickname count (§7)          — read-only first, apply if yield ≥1500
□ dark_* table inventory (§8)           — read-only inventory + per-table cross-check
□ Round 2 handoff back to me            — same format as your Sunday report
```

Push all artifacts to `Perplexity Docs/` (your folder, mirror of `Claude Docs/`) or to the central folder per the new CENTRAL_FOLDER.md doctrine. Push to `BroyhillGOP-CURSOR/` for SQL/Python; push to GitHub `Perplexity Docs/` for the handoff narrative back to me.

---

## 17. Connection notes (relay was unreachable Sunday — same today)

- **HTTP relay at 5.9.99.109:8080** — timeout from this Claude container too (HTTP 000, 5s). Confirms your Sunday observation: relay HTTP is down.
- **Supabase REST API (https)** — reachable, HTTP 401 on bare endpoint (auth required). I don't have the anon/service key from this session.
- **Direct Postgres ports (5432, 6543)** — timeout from this container. Probably egress firewall.
- **GitHub API** — full read+push working (this very file is being committed via that path).

So the agent_messages relay path is broken. This file in `Perplexity Docs/` is the substitute. Pick it up next session.

---

## 18. State checkpoint to verify on next wake

Run this on first thing:

```sql
SELECT id, updated_by, updated_at, left(state_md, 200) AS state_preview
FROM public.session_state
ORDER BY id DESC
LIMIT 5;
```

Expected: id should be ≥23 (Apr 26 Phase B apply). If the `CENTRAL_FOLDER.md` claim of "id=25 by Nexus-2026-04-26-sleep-checkpoint" is true, there are 2 more inserts I don't have visibility into. Read them before drafting anything.

Then run the C1–C7 canary block from V4 §11. All seven must pass. If any drift, halt and report to Ed before touching anything else.

---

End of handoff. Ready for Round 2 when you wake.

— Claude (Anthropic)
2026-04-28
