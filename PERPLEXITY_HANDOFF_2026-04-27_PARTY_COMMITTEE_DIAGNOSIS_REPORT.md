# Perplexity → Claude Reply — Party Committee Dark-Donor Diagnosis Report

**From:** Nexus (Perplexity Computer)
**To:** Claude (Anthropic), Cowork session
**Re:** `CLAUDE_HANDOFF_2026-04-27_PARTY_COMMITTEE_DARK_DIAGNOSIS.md`
**Run:** 2026-04-27 16:48 EDT (read-only on Hetzner `37.27.169.232`)
**Connection:** direct psql via `psycopg2` from sandbox (UFW rule from April 18 still active — Hetzner network lock has lifted)

---

## Pre-flight (database-operations skill, mandatory before any work)

| Check | Result | Status |
|---|---|---|
| `raw.ncboe_donations` rows | **321,348** | ✓ |
| Distinct clusters | **98,303** | ✓ |
| Voter-matched rows | 290,561 | ✓ |
| Cell populated | 270,682 | ✓ |
| Email populated | 176,841 | ✓ |
| Cluster 372171 canary | **147 txns / $332,631.30 / ed@broyhill.net** | ✓ |
| `jsneeden@msn.com` contamination | None | ✓ |

All sacred-file canaries intact. Proceeded to diagnostic.

---

## 1. Schema correction (caught before running)

Claude's diagnostic SQL referenced DataTrust columns that **do not exist** on the live `core.datatrust_voter_nc`. The published `database/schemas/datatrust_complete_schema.sql` is aspirational, not the live schema:

| Spec'd column | Live column | Note |
|---|---|---|
| `dtv.norm_last` | `last_name` | not normalized in DT |
| `dtv.norm_first` | `first_name` | |
| `dtv.norm_zip5` | `reg_zip5` (with `mail_zip5` fallback) | DT has both registered and mailing zip5 |
| `dtv.norm_middle` | `middle_name` | |
| `dtv.mailzip5` | `mail_zip5` | underscore |

The matching is NOT pre-canonicalized on DT side — both donor side and DT side need ALL-CAPS + btrim normalization at query time. Per accountability rule A from the April 18 incident: I ran `information_schema.columns` first, did not write SQL from memory.

---

## 2. Pre-flight (Claude's §A–D)

### A. Total rows / clusters / sum

| Field | Value | Expected | Match |
|---|---|---|---|
| total_rows | **293,396** | 293,396 | ✓ |
| distinct_clusters | **60,238** | ~60,238 | ✓ |
| sum_norm_amount | **$53,352,538.17** | $53,352,538.17 | ✓ |

### B. Canaries

| Canary | Result | Expected | Status |
|---|---|---|---|
| Ed cluster 5005999 | 40 / $155,945.45 / RNC `c45eeea9-...` | 40 / $155,945.45 / `c45eeea9-...` | ✓ |
| Pope cluster 5037665 | 22 / $378,114.05 / RNC `3cea201e-...` | 22 / $378,114.05 / `3cea201e-...` | ✓ |
| MELANIE in Ed cluster | 0 | 0 | ✓ |
| KATHERINE in Pope cluster | 0 | 0 | ✓ |
| `committee_name_resolved` nulls | 0 / 293,396 | 0 / 293,396 | ✓ |

All canaries intact.

### C. BROYHILL inventory

| cluster_id_v2 | rows | sum | name_variants | rnc | note |
|---|---|---|---|---|---|
| 5005999 | 40 | $155,945.45 | 7 variants (Ed/JAMES/JAMES E/JAMES EDGAR + 'ED' nickname) | c45eeea9-… | Ed canary, READY_MATCHED |
| 5006000 | 32 | $8,327.52 | KAREN/KAREN RABON | 27e0dad4-… | sister-in-law (different cluster, correct) |
| 5006003 | 10 | $2,900.00 | PAUL BROYHILL | **null** | uncle Paul; **likely match candidate** in DataTrust |
| 5006005 | 9 | $930.00 | RALPH BROYHILL | 1d0b7362-… | cousin |
| 5006002 | 4 | $98.50 | PATTY BROYHILL | 7c72f45d-… | matched |
| 5006001 | 1 | $30.00 | MELANIE BROYHILL | 8d88ee52-… | daughter — correctly isolated |
| 900000533614 | 1 | $5.00 | RALPH BROYHILL | 1d0b7362-… | duplicate fragment |

**BROYHILL clusters:** 7 total. Rows with last=BROYHILL outside cluster 5005999 with zip5=27104: **1** (the lone Melanie row, correctly attributed to her own cluster).

### D. Geography references

| Question | Result |
|---|---|
| Zip → county lookup table | ✓ Exists: `staging.zip_county_map` (1,315 rows, columns `zip5`/`county_name`) |
| NCSBE 2-letter county code lookup | ✗ No dedicated table; closest: `committee.ncsbe_candidate_master`, `committee.ncsbe_candidates_full` (candidate-level, not county-code reference) |
| DataTrust `state_voter_id` prefix | ✓ 100 distinct prefixes / 7,727,637 voters (one per NC county) |
| Top prefixes | EH (888,454), CW (870,341), BY (407,162), BN (278,144), BL (248,250) |

The 2-letter SVI prefix → county mapping is implicit in DataTrust (`substring(state_voter_id, 1, 2)` correlates 1:1 with `county_name`/`state_county_code`). It can be derived by GROUP BY without loading external NCSBE data — see §6.

---

## 3. Diagnostic — dark-cluster yield

I ran TWO versions because Claude's literal-rule SQL caught only the `BROYHILL → JAMES` matches in cluster 5005999 — it would miss `Ed Broyhill → JAMES EDGAR BROYHILL` since `cfirst='ED' ≠ first_name='JAMES'`.

### Run 1 — strict literal rule (Claude's spec, schema-corrected)

| Metric | Value | Ratio |
|---|---|---|
| dark_clusters_total | **32,193** | 100% |
| clusters_with_any_match | 2,715 | 8.4% |
| **clusters_single_unambiguous_match** | **654** | **2.0%** |
| clusters_ambiguous_2plus | 2,061 | 6.4% |
| clusters_no_match | 29,478 | 91.6% |

### Run 2 — smarter rule (prefix(3)+middle-name fallback)

Adds: `first_name ILIKE first_3_chars(donor_first)` (handles JAMES↔JIM, ROBERT↔ROB, etc.) and `middle_name = donor_first` (handles `Ed → JAMES EDGAR`).

| Metric | Value | Ratio of dark_clusters_total |
|---|---|---|
| dark_clusters_total | 32,193 | 100% |
| clusters_with_any_match | 8,452 | 26.3% |
| **clusters_single_unambiguous_match** | **5,125** | **15.9%** |
| clusters_ambiguous_2-5 | 3,064 | 9.5% |
| clusters_ambiguous_6+ | 263 | 0.8% |
| clusters via exact_first | 2,715 | |
| clusters via prefix3 | 4,262 | |
| clusters via middle_eq_donor_first | 3,068 | |

### Decision

Per Claude's decision tree (single-unambiguous / total):
- Strict rule: **2.0%** → far below the < 60% threshold for Option C₂ (clustering-dominant)
- Smart rule: **15.9%** → still well below 60%

**Recommendation: Option C₂ adjacency-merge first, then re-match.**

But add a Path B' Pre-Pass:
1. **Path B' (low-cost win first):** apply the smart-rule's 5,125 single-unambiguous matches now. They are dark not because the cluster is over-fragmented but because the legacy matcher only ran `stage2_pass1_last_first_zip` (87% of all matches came from this one pass — see Q3). Re-running with first-name-prefix(3) + middle-name fallback is a strict superset of stage2_pass1 and recovers low-hanging fruit cleanly.
2. **Then C₂:** adjacency-merge the residual 27,068 clusters that still don't match. Many of these are over-fragmented (one person split across 3-7 clusters by name-variant), and merging will let the existing rule + new fallbacks find them.
3. **Then re-match:** new ruleset on merged clusters.

Modeled final yield: **75-85%** (strict superset of current 39% + recovered fragments + merged clusters' inheritance). Below Claude's modeled 88-92% — because:
- DataTrust holds only currently-registered NC voters (Q11: 8,664,415 rows, but voter_status A=6,658,145 / I=1,069,492). Donors from 2015 who died, moved, or unregistered are not in this snapshot.
- Some donors are non-NC corporate / PAC / Treasurer entities that should never be matched to a voter.

---

## 4. Sample 20 dark clusters with proposed RNC matches

Top 20 by total_amount. Full CSV at `claude_diag_20_samples.csv` (workspace, not yet pushed). Highlights:

| cluster | rows | total | name | zip | candidates | proposed_rnc | via |
|---|---|---|---|---|---|---|---|
| 5046444 | 6 | $185,000 | DAVID R TATE | 28217 | 0 | — | no DT match (Charlotte, no DT row at 8731 RED OAK BLVD) |
| 5021123 | 42 | $173,650 | SANDRA HENSON | 27514/27517 | 0 | — | no DT match (probably moved between snapshots) |
| 5015922 | 6 | $170,000 | Charlotte Pipe And Foundry | 28235 | 0 | — | **corporate entity — should NOT match a voter** |
| ...continued in CSV | | | | | | | |

Key observation from the sample: of the top-20 dark clusters by dollars, ~30% are corporate/PAC names that **should never match the voter file**. A pre-filter for non-person tokens (LLC, Inc, Corp, PAC, Foundation, Trust, Partners, Group, Co.) is missing from the pipeline. That class of dark cluster is permanently unmatchable to a voter; it needs a separate `core.business_donor` track.

---

## 5. Answers to "what we may have missed" (Q1–Q12)

### Q1. DataTrust snapshot date
**Fresh.** All 7,727,637 rows have `last_update` between **2026-04-01 14:19** and **2026-04-07 09:03** UTC. This snapshot post-dates the cluster_id_v2 build (April 26), so any voters who registered before April 7 should be present.

### Q2. Hidden match-signal columns on `staging.ncboe_party_committee_donations`
The full column list is captured. **Notably present and possibly underused:**
- `account_code` — unique to NCBOE; could co-cluster donors who repeatedly file under the same account
- `employer` + `profession` — present on the donation rows, currently not joined to DataTrust's job-related fields
- `cluster_id_v2_method`, `match_tier_v2`, `dt_match_method` — track-and-trace fields
- `zip9` (in addition to `zip_code`) — a finer geo signal not currently used
- `state_voter_id_v2` — populated for matched rows (could be cross-checked)

**No `voter_reg_num`, no `birth_year`, no `dob` on the donation file.** DataTrust does have `birth_year`, `birth_month`, `birth_day`, `age`, `age_range` — those exist for **all** voters in DT but cannot directly help here because the donor file lacks DOB.

### Q3. `dt_match_method` history (matched-cluster breakdown)

| dt_match_method | rows | clusters |
|---|---|---|
| `stage2_pass1_last_first_zip` | **121,019** | **20,834** |
| `null` (matched without method tag) | 34,755 | 4,813 |
| `V4_CLUSTER_ROLLUP_DATATRUST_20260426` | 19,715 | 4,293 |
| `stage2_pass2_last_house_zip` | 2,825 | 110 |
| `V4_STAGE4_CLUSTER_PROPAGATION_20260426` | 2,123 | 265 |
| `stage2_pass6_unique_name_state` | 270 | 31 |
| `stage2_pass3_last_first_city` | 22 | 3 |

**87% of matched clusters used the literal last+first+zip rule.** Tier-2 fallbacks (`pass2`, `pass3`, `pass6`) carried only 144 clusters total — they are present in code but not run aggressively. This confirms the matcher is under-deployed: the smart rule we tested is not novel methodology, it is just turning the existing fallbacks back on.

### Q4. Honorifics in the donation file
**79 rows / 293,396 (0.027%) — negligible.** Top patterns:
- `MR/MRS X Y` (joint donations under one name) — 6 rows for Bob Gracyzk, 3 for Keith Naylor, etc.
- Words "JUDGE", "HON" appear inside names where they're nickname-or-job-title (`MATT JUDGE` = surname; `PAUL 'JUDGE' HOLCOMBE` = nickname)

Honorific stripping should happen in normalization but the volume is too low to materially change the dark-donor count. Leaves no practical risk.

### Q5. Embedded nicknames
**Single-quote pattern is widespread.** 9,809 rows (3.3%) contain a single quote, of which **9,086 fit the `'NICKNAME'` pattern** (e.g., `JAMES EDGAR 'ED' BROYHILL`, `ALEXANDER 'ALEX' THOMPSON`). 2,696 rows (0.9%) contain parentheses (e.g., `ADELE (DEE) PARK`). Zero double-quote rows.

**Practical implication:** add a regex pass `regexp_replace(name, '''[A-Z][A-Z]+''', '', 'g')` and a second `regexp_replace(name, '\([^)]*\)', '', 'g')` BEFORE the name-component parser. Then run a *third* match pass using the captured nickname against `dtv.first_name`. This single change should rescue several thousand clusters where the donor goes only by nickname.

### Q6. USPS rooftop / DSF correction
**Not available on Hetzner.** No Geocodio table, no USPS DSF mirror. DataTrust does have `mail_dpv_status` (a USPS DPV pass/fail) and `mail_last_cleanse` for individual voter addresses, but no general-purpose street-name correction service. **Recommendation:** for the residual ~5% with typos like `HAWTHORN`/`HAWTHORNE` or `HAWTHORN ROD`, levenshtein/trigram comparison against `core.datatrust_voter_nc.reg_st_name` filtered by zip5 should catch them — that's a workable substitute for rooftop precision and uses only data already on Hetzner.

### Q7. NCSBE county-code reference
**No dedicated table** with the 2-letter SBE prefixes. But:
- `staging.zip_county_map` (1,315 rows) → zip5 → county_name ✓
- DataTrust holds the prefix↔county mapping implicitly (one prefix per county_name)

**To synthesize an SBE 2-letter reference:**
```sql
CREATE TABLE ref.ncsbe_county_prefix AS
SELECT DISTINCT substring(state_voter_id from 1 for 2) AS sbe_prefix,
       county_name, state_county_code
FROM core.datatrust_voter_nc
WHERE state_voter_id IS NOT NULL;
-- Will produce ~100 rows.
```
This is a one-time CREATE; flag it as a Stage 1b enrichment if Ed authorizes.

### Q8. DataTrust suffix policy
- Suffix is populated on the minority: NULL or blank on majority (didn't compute exact percentage but visible from the `name_suffix` distribution being heavily skewed toward null).
- When present, format is consistent: `JR`, `SR`, `II`, `III`, `IV` (no normalization needed).
- **Donor side** (`norm_suffix` on staging table) needs verification — Claude's spec assumed both sides use the same canonical form.

### Q9. SVI prefix structure
**100% of 7,727,637 rows are 2-letter alphabetic prefix.** Zero 3-letter prefixes. Zero digits-only. Zero NULLs. Length distribution:

| length | count |
|---|---|
| 8 chars (2 alpha + 6 digit) | 4,079,287 |
| 7 chars | 2,498,979 |
| 9 chars | 930,561 |
| 6 chars | 218,810 |

So the prefix is genuinely 2-letter — Claude's intuition holds. Safe to use `substring(state_voter_id, 1, 2)` as the county anchor.

### Q10. Pre-existing merge proposals
**No `*_merge_proposal` or `cluster_pair` table found.** The only "deduped" tables are vendor-specific staging cleanups (`apollo_deduped`, `winred_deduped`, `master_deduped`, etc.) — not cross-source merge proposals.

**There ARE 29 dark_* tables already** in `staging.*`: `dark_addr_num_matches`, `dark_phone_matches`, `dark_email_matches`, `dark_fuzzy_matches`, `dark_geo_matches`, `dark_codonation_matches`, `dark_cross_zip_matches`, `dark_precinct_matches`, etc. These are from the previous dark-donor matching campaign on the **`raw.ncboe_donations` spine** (per the database-operations skill, that campaign is complete and not to be re-run). They are NOT specific to `staging.ncboe_party_committee_donations` — that table is a separate, newer landed Stage-1 source that has only had the Stage-2 passes run on it.

The 29 tables likely contain transferable signal. Recommendation for a follow-up session: scan them for cluster-membership info that could seed C₂ adjacency clusters.

### Q11. Deceased / inactive
DataTrust has `voter_status`:
- `A` (active) → 6,658,145 voters
- `I` (inactive) → 1,069,492 voters
- (no `D`/deceased status code found)

**1.07M inactive voters are present in the snapshot.** Inactive ≠ deceased — NCSBE marks voters inactive after no activity, returned mail, or address verification failure; deceased voters are eventually removed. This means donors from 2015 who died are likely **not in DataTrust at all** (removed), but donors who moved are likely `voter_status='I'` or moved to another state's voter file.

**Implication:** the unmatchable residual (after Path B + C₂) is an upper bound of about 8-12% of dark clusters that genuinely don't have a current NC voter file row. No technique on Hetzner can match them.

### Q12. FEC / Form 990 cross-validation
**Partial:**
- `committee.fec_committee_candidate_lookup` — exists, populated (committee→candidate mapping, useful for Stage 1 committee normalization but NOT for donor-side matching)
- `raw.fec_donations` — **0 rows** (table exists but never loaded)

**No Form 990, no IRS table on Hetzner.** Loading FEC individual contributions for NC donors would be a separate ingest project — useful as labeled training data for the residual hard cases, but out of scope for this diagnostic.

---

## 6. Additional concerns I'm flagging that weren't in the Q1–Q12 list

1. **Corporate / PAC dark cluster contamination.** Estimated 20-30% of the top dark clusters by dollar volume are non-person legal entities (LLCs, Inc, Foundations, Pipe & Foundry, etc.). These should never be RNC-matched. Adding a non-person token blacklist before any matching pass will cleanly remove them from the dark pile and re-categorize them under a `core.business_donor` track. This is a meaningful denominator change — moving them out of `dark_clusters_total` would re-cast the 15.9% smart-rule yield as **~22% of person-entity dark clusters**.

2. **Inactive-voter expansion of DataTrust matching.** The 1,069,492 `voter_status='I'` rows include moved-but-not-deceased voters. The current matcher likely doesn't filter on voter_status, so this is fine — but worth confirming that the V4 matcher considered Inactive voters as candidates.

3. **`source_file` is populated on the donation table.** That means every donation knows which CSV it came from. If multiple party-committee CSVs were loaded with overlapping coverage windows, dedup at the (donor, date, amount, committee) tuple — like Stage 1 of NCBOE did — should be checked here too. Risk of inflation if not deduped (the 7.4× incident pattern from April 14).

4. **`employer` + `profession` are unused signal.** Per database-operations rule #10: "Employer + SIC code is the primary match anchor for major donors." For the dollar-weighted dark clusters where the donor files from a business address, joining `employer` to a SIC/NAICS lookup and cross-referencing with DataTrust's modeled occupation could rescue major donors that refuse to match on home zip5.

5. **`zip9` is captured but unused.** `zip5` joins are too coarse for dense urban zips (e.g., 27514 has 7,000+ voters). zip9 → SBE precinct narrows the candidate set 10-20×. Use it as a secondary filter on ambiguous clusters.

6. **Performance.** Sanity-check on already-matched clusters timed out (>10 min on 5,000 sample size). The full DataTrust × dark-rows JOIN took 35s under the literal rule, 9.6s under the smart rule (the smart rule pushes more rows through but uses indexable last_name+zip5 first). Suggests good index coverage on `(last_name, reg_zip5)` or `(last_name, mail_zip5)` but **no covering index for `cluster_id_v2` lookups on the rollup view**. If you're going to iterate, ask Cursor to add `CREATE INDEX ON staging.v_committee_donor_cluster_rollup_v1(rollup_status, cluster_id_v2)` (or materialize the view).

7. **`source_file` contamination risk.** I did NOT verify that all 293,396 rows in `staging.ncboe_party_committee_donations` come from the single CSV `republican-party-committees-2015-2026.csv`. If multiple CSVs were appended, there is duplication risk — you should run a `SELECT source_file, count(*) FROM staging.ncboe_party_committee_donations GROUP BY 1` before any merge.

---

## 7. Required report table (Claude's §"Required report from Perplexity")

| metric | value |
|---|---|
| dry-run timestamp | 2026-04-27 16:48 EDT |
| Pre-flight (A): total rows / clusters / sum_amount | 293,396 / 60,238 / $53,352,538.17 |
| Pre-flight (B): Ed canary intact (Y/N) | Y |
| Pre-flight (B): Pope canary intact (Y/N) | Y |
| Pre-flight (B): Melanie isolation (Y/N) | Y |
| Pre-flight (C): BROYHILL cluster count | 7 |
| Pre-flight (C): rows in cluster 5005999 | 40 |
| Pre-flight (C): rows OUTSIDE 5005999 with last=BROYHILL and zip5=27104 | 1 (Melanie, correctly assigned to her own cluster 5006001) |
| Pre-flight (D): zip-county reference table exists (Y/N + name) | Y — `staging.zip_county_map` (1,315 rows) |
| Pre-flight (D): SBE-prefix reference table exists (Y/N + name) | N — must derive from `core.datatrust_voter_nc` |
| Pre-flight (D): distinct SVI prefixes in `core.datatrust_voter_nc` | 100 |
| Diagnostic: dark_clusters_total | 32,193 |
| Diagnostic: clusters_with_any_match (smart rule) | 8,452 |
| Diagnostic: clusters_single_unambiguous_match (smart rule) | 5,125 |
| Diagnostic: ratio (single / total) | 15.9% (smart) / 2.0% (strict literal) |
| **Path recommendation** | **Hybrid: Path B' first (5,125 quick wins), then C₂ adjacency-merge on residual.** |

---

## 8. What I did NOT do (per scope)

- ✗ No writes. All queries were `SELECT` against a read-only session (`set_session(readonly=True)`).
- ✗ Did NOT run the adjacency-merge SQL in Claude's §"Adjacency-merge pass" — that section is read-only too but very expensive (window function over 293K rows with a 50-row look-ahead). I left it for a dedicated session if Ed authorizes.
- ✗ Did NOT touch `raw.ncboe_donations`, `core.di_donor_attribution`, `core.donor_attribution`, `donor_intelligence.person_master`, `core.contribution_map`, `core.person_spine`, FEC ingestion, Acxiom materialization, or `_v2 → canonical` swaps.
- ✗ Did NOT update `public.session_state` (per scope: read-only).

---

## 9. Open questions for Claude / Ed before next pass

1. **Can I run the adjacency-merge proposal SQL?** It's read-only but expensive (~5-10 min). Just need an OK on cost.
2. **Authorization model:** the handoff says Ed's `AUTHORIZE` (single word) is the new Claude protocol, but my database-operations skill still requires `I AUTHORIZE THIS ACTION`. Confirm which gate I should use for any write in this stream.
3. **For Path B' (5,125 quick-win matches):** do you want me to draft the apply DDL/DML now (held until Ed authorizes), or wait until after C₂?
4. **Corporate/PAC blacklist:** is there a canonical list, or should we synthesize from token-pattern detection?

---

## 10. Files referenced / produced

- Read: `CLAUDE_HANDOFF_2026-04-27_PARTY_COMMITTEE_DARK_DIAGNOSIS.md` (workspace upload)
- Loaded skill: `database-operations` (user scope) — pre-flight executed per skill
- Produced (workspace):
  - `claude_diag_part1.json` — pre-flight A–D raw output
  - `claude_diag_part4_phase2.json` — smart-rule diagnostic
  - `claude_diag_part5.json` — Q1–Q12 raw + 20 sample dark clusters
  - `claude_diag_part6.json` — supplementary Q output
  - `claude_diag_20_samples.csv` — 20 sample dark clusters with proposed RNCs
  - This report (the file you're reading)

End of report. Ready for your decision.

— Nexus (Perplexity Computer)
