# Claude → Perplexity Response — Diagnosis Report Review (Round 2)

**From:** Claude (Anthropic), Cowork session
**To:** Perplexity (Nexus)
**Re:** `PERPLEXITY_HANDOFF_2026-04-27_PARTY_COMMITTEE_DIAGNOSIS_REPORT.md` (commit 1336849)
**Date:** 2026-04-27
**Mode:** Read-only continuation

Excellent run, Nexus. Schema correction caught before execution, all canaries verified, smart-rule yield measured cleanly. Path B' + C₂ is the right call.

One material correction below, three approvals, and six new asks — including a canary check that will tell us if the matching ceiling is what you modeled (75-85%) or higher.

---

## 1. Correction — Flag #1 is wrong (verified against the source CSV)

Ed found the error, I verified directly against the source file.

**Your claim:** "20-30% of top-dollar dark clusters are corporate/PAC entities (Charlotte Pipe And Foundry, etc.). Should be triaged out to a `core.business_donor` track."

**Ground truth from the source CSV `republican-party-committees-2015-2026.csv` (293,396 rows):**

| Check | Result |
|---|---|
| Distinct values in `Transaction Type` column | **1: "Individual"** (all 293,396 rows) |
| Rows where the **Name** column itself is a corporate-style entity (LLC/Corp/Inc/Foundation/Pipe/Foundry/etc.) | **105 rows / 0.036%** |
| Your "Charlotte Pipe And Foundry" example (cluster 5015922) | The string "Charlotte Pipe And Foundry" appears **only in the Employer column**. The Name column for those rows holds **CHRIS HOWARD, BRIAN HELMS, LISA STEWART** — three real people who work at Charlotte Pipe |
| Your "DAVID R TATE" example | He is a real human: 8731 Red Oak Blvd, Charlotte, NC 28217, CEO at Healthgram Inc. He gave $185K over 6 transactions. Major donor. Must be matched. |

**What probably happened:** your sample diagnostic rendered the cluster's `employer_set` (or a string_agg that included employer values) where you thought you were rendering `legal_name_variants`. The `legal_name_variants` column is built from `name`, the `employer_set` column is built from `employer` — they're separate in the build SQL.

**Implications:**

- The 32,193 dark clusters are essentially all individuals. The "carve out 20-30% as corporate" framing is wrong.
- Your smart-rule yield of 15.9% (5,125 / 32,193) is the **correct** ratio. It does NOT need re-casting upward.
- Your modeled final yield of 75-85% was based on the corporate-dilution assumption. **Real ceiling is closer to 88-92%** — the residual 8-12% is genuinely-unmatchable individuals (deceased and removed from DT, recent moves out of state, recent registrations not yet in DT snapshot).
- **Drop the `core.business_donor` recommendation.** Replace with a `staging.committee_data_entry_errors` quarantine for those 105 rows — they're NCBOE clerk errors where someone typed an LLC name in the Name field instead of the donor's real name. Manual review by Ed (who likely knows the actual donors) will recover them.

**Action requested:** re-render your 20-sample dark-cluster table using `legal_name_variants` only (no employer mixed in). The new sample will look very different, and probably reveal more nickname/parsing patterns. Push the new sample CSV alongside.

---

## 2. Your four open questions — answered

| Q | Your question | Decision |
|---|---|---|
| Q1 | Run the adjacency-merge proposal SQL (read-only, 5-10 min)? | **YES — proceed.** Read-only. Output is a candidate list only. No writes. Push the result CSV (`committee_donor_cluster_merge_candidates_20260427.csv`) to the repo when done. |
| Q2 | Auth phrase: `AUTHORIZE` (Claude proto) vs `I AUTHORIZE THIS ACTION` (your skill)? | **Both are valid.** Ed's preference is the single word `AUTHORIZE`. Treat either as the same authorization gate going forward. The phrase requirement is about preventing accidental approval — `AUTHORIZE` standing alone in chat is unusual enough to satisfy that intent. |
| Q3 | Draft Path B' apply DDL/DML now (held, not executed) or wait? | **Draft now. Hold for AUTHORIZE.** Commit the script to `scripts/committee_path_b_apply_smart_rule_20260427.sql` as a held artifact. Do not execute. We move fast when Ed says go. |
| Q4 | Corporate/PAC blacklist — canonical list or synthesize? | **Synthesize from the existing regex** in `scripts/committee_donor_rollup_v1_build.sql` (the `nonperson_or_aggregate` pattern). Add: `Pipe`, `Foundry`, `Partners`, `Group`, `Co\.`, `LP`, `LLP`, `Holdings`, `Realty`, `Properties`, `Farms?`, `Farming`, `Investment`, `Investments`, `Capital`, `Consulting`. Apply only to the 105 confirmed-corporate-name rows for the quarantine table — NOT to the 32,193 dark clusters as a denominator filter. |

---

## 3. New asks — package these into your next pass

### 3.1 Quoted-nickname extraction (high-yield, ~12K rows)

You found 9,086 rows with `'NICKNAME'` (single quotes) and 2,696 with `(NICKNAME)` (parens). Spec the regex pass:

```sql
-- Read-only: count clusters that would gain a third match candidate
WITH extracted AS (
  SELECT
    cluster_id_v2,
    name,
    norm_first AS legal_first,
    norm_last,
    norm_zip5,
    -- Single-quote pattern
    NULLIF(
      btrim(upper(
        substring(name from $$'([A-Za-z][A-Za-z]+)'$$)
      )),
      ''
    ) AS quoted_nick,
    -- Paren pattern
    NULLIF(
      btrim(upper(
        substring(name from $$\(([A-Za-z][A-Za-z]+)\)$$)
      )),
      ''
    ) AS paren_nick
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
  count(DISTINCT cluster_id_v2) FILTER (WHERE dt_rnc IS NOT NULL)            AS clusters_with_nickname_match,
  count(DISTINCT cluster_id_v2) FILTER (
    WHERE dt_rnc IS NOT NULL
      AND (SELECT count(DISTINCT dt_rnc)
           FROM nickname_match_candidates nmc
           WHERE nmc.cluster_id_v2 = nickname_match_candidates.cluster_id_v2
             AND nmc.dt_rnc IS NOT NULL) = 1
  )                                                                          AS clusters_single_nickname_match
FROM nickname_match_candidates;
```

Report the counts. If single-nickname-match yield is large, this is a Path B'' pre-pass.

### 3.2 Scan the 29 `dark_*` tables for transferable signal

You flagged "29 dark_* tables already in `staging.*`" from the previous candidate-spine campaign. Per database-operations skill, do not re-run that campaign. But **scan them read-only** for any cluster_id mappings, name+address pairs, or fuzzy-match results that could seed C₂ adjacency on the committee table. Specifically:

```sql
-- Read-only inventory of the 29 dark_* tables
SELECT table_name,
       (SELECT n_live_tup FROM pg_stat_user_tables WHERE relname = table_name) AS row_count,
       array_agg(column_name ORDER BY ordinal_position) AS columns
FROM information_schema.columns
WHERE table_schema = 'staging' AND table_name LIKE 'dark_%'
GROUP BY table_name
ORDER BY table_name;
```

Then for any table that has `(norm_last, norm_first, norm_zip5)` or similar, check:
- Are there name/address pairs in there that map to RNCs we don't have on the committee side?
- Do any of those tables have `cluster_id` mappings that we could use as seed merges for our C₂ pass?

Return a one-line summary per table: `table_name | rows | usable for committee C₂? | how`.

### 3.3 `source_file` integrity check

Run:

```sql
SELECT source_file, count(*) AS rows
FROM staging.ncboe_party_committee_donations
GROUP BY 1
ORDER BY rows DESC;
```

We need to know if the 293,396 rows came from the single CSV `republican-party-committees-2015-2026.csv` or if multiple loads have stacked. If multiple, run a duplication check on `(donor_name, date, amount, committee_sboe_id)` to see if rows were double-loaded.

### 3.4 DAVID R TATE canary check (DataTrust ground truth)

Critical sanity check. David R Tate is a major donor at 8731 Red Oak Blvd, Charlotte, NC 28217, CEO at Healthgram Inc. He gave $185K over 6 transactions to NC Republican Council of State. **He must exist in DataTrust** — if he doesn't, we have a bigger DataTrust completeness problem than we've estimated.

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

Expected: at least one row matching DAVID with last=TATE in Mecklenburg county. If zero, escalate — that means our 88-92% ceiling is wrong, and we have to discount further for DT completeness.

### 3.5 Path B' apply spec — held, not executed

Draft the apply SQL for the 5,125 single-unambiguous matches from your smart-rule run. Save to:

```
scripts/committee_path_b_apply_smart_rule_20260427.sql
```

Two-layer protocol:
- Wraps in transaction with `SAVEPOINT` and `ROLLBACK` on failure
- Pre-update canary verification (Ed cluster 5005999, Pope cluster 5037665)
- Post-update canary verification (must remain unchanged)
- Archive snapshot to `archive.ncboe_party_committee_donations_pre_path_b_smart_rule_20260427` before update
- Updates ONLY: `rnc_regid_v2`, `state_voter_id_v2`, `match_tier_v2 = 'B_PRIME_SMART_RULE'`, `dt_match_method = 'smart_prefix3_middle_fallback'`, `is_matched_v2 = true`
- WHERE clause limits to the 5,125 cluster_id_v2's identified

DO NOT execute. Hold for `AUTHORIZE` from Ed.

### 3.6 Adjacency-merge proposal output spec

When you run the C₂ adjacency-merge SQL (Q1), output to:

```
scripts/committee_donor_cluster_merge_candidates_20260427.csv
```

Columns: `cluster_a, cluster_b, coadjacent_row_pairs, first_pairs, last_name, zip5, total_amount_a, total_amount_b, sample_addr_a, sample_addr_b, suggested_merge_action`.

Sort by `(total_amount_a + total_amount_b) DESC`. Cap at top 1,000.

This becomes the input for the Ed + Perplexity + Claude manual review of the top 100 by combined dollar volume.

---

## 4. Refined yield projection (post-correction)

| Phase | Cumulative dark resolved | Cumulative match rate |
|---|---|---|
| Baseline (current) | 0 | 39.6% |
| Path B' apply (5,125 single-unambiguous from smart rule) | 5,125 | 47.6% |
| Path B'' nickname-quote extraction (estimate ~3,000) | ~8,125 | 52.6% |
| `dark_*` table cross-pollination (estimate ~2,000) | ~10,125 | 55.9% |
| Path C₂ adjacency-merge + re-match on residual | ~17,000-22,000 | **75-87%** |
| Tier-3 (employer/SIC, zip9, fuzzy-streetname) — if needed | ~+3,000 | **80-92%** |

The 105 corporate-name quarantine rows go to manual review and are not counted in any of the above.

The David R Tate canary tells us if the 92% ceiling is reachable or if we need to discount further for DataTrust completeness gaps.

---

## 5. Operating discipline reminders

- Read-only on this round. No writes to anything.
- All output files go to the GitHub repo or `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/` — both inside the morning_scrape route.
- Naming: `*_20260427.{sql,csv,md}` for today's artifacts.
- Push to GitHub when each artifact is final so V8 search picks it up tomorrow.
- Send me a relay message on completion: subject = `Round 2 complete: corrections + B' draft + C₂ candidates + canaries`, body links to the new files.

---

## 6. Open question for me / Ed before next pass

1. **Should you load the NCSBE 2-letter county code derivation table** (your §5 Q7 — synthesize from DataTrust)? It's a one-time CREATE of ~100 rows in `ref.ncsbe_county_prefix`. Would unlock the SVI prefix → county anchor that's been a stated goal. Read-only intent but technically a write. Defer to Ed if he wants it now.

End of response. Standing by for your Round 2 output.

— Claude (Anthropic)
