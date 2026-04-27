# Claude → Perplexity Handoff — Party Committee Dark-Donor Diagnosis (Option C)

**From:** Claude (Anthropic), Cowork session
**To:** Perplexity (Nexus)
**Date:** 2026-04-27
**Context:** Read-only audit completed at `docs/runbooks/PARTY_COMMITTEE_AUDIT_20260427.md` (central folder). Ed and I refined hypotheses through file inspection. We chose path **Option C** of the audit's §6 — *diagnose first, then act*. This handoff packages the diagnostic for you to verify on Hetzner and to add anything we missed.

---

## Goal

Determine whether the 60% dark-donor problem in `staging.ncboe_party_committee_donations` is a **matching** problem, a **clustering** problem, or both. Based on yield, decide between three execution paths. **No writes in this handoff. Read-only diagnosis only.**

---

## Universe declaration

**In scope (READ ONLY):**
- `staging.ncboe_party_committee_donations` and its existing rollup views (`staging.v_committee_donor_*_v1`)
- `core.datatrust_voter_nc` — for join verification only
- Reference lookups (NC zip → county, county → SBE 2-letter SVI prefix) — verify existence in `core.*` or propose loading

**Off-limits (no reads, no writes):**
- `raw.ncboe_donations` (read-only canary file)
- `core.di_donor_attribution`, `core.donor_attribution`
- `donor_intelligence.person_master`
- `core.contribution_map`, `core.person_spine`
- FEC ingestion, Acxiom materialization, Stage 4 propagation, `_v2`→canonical swap

---

## What Claude observed (please verify)

These are the findings from inspection of the source CSV (`republican-party-committees-2015-2026.csv`, 293,396 rows, 63 MB) plus the existing audit artifacts. Please confirm or correct each.

### 1. Source file is pure NC, no contact channels

| Check | Observed | Action |
|---|---|---|
| Total rows in CSV | 293,396 | matches Hetzner staging — confirm |
| `State` column | 100% `NC`, only one distinct value | **rules out out-of-state as a dark cause** |
| Phone column present? | No | rules out phone match |
| Email column present? | No (Danny G confirmed in `DATATRUST_API_ANSWERS.md` — "DataTrust does NOT have emails for NC voters") | **strike `email_dt` from any matching plan** |
| Sort order | Alphabetical by `Name` | **adjacency-clustering signal we should exploit** |

### 2. The dark donors are ALSO the high-volume donors (BROYHILL example)

The CSV contains **122 rows with surname BROYHILL**. At least **40+ are unambiguously Ed Broyhill** at 525 N Hawthorne Rd, Winston-Salem, NC 27104. They appear under SEVEN name variants:

```
Ed Broyhill              (mixed case)
ED BROYHILL              (all caps)
JAMES BROYHILL           (legal w/o middle)
JAMES E BROYHILL         (with middle initial)
James Edgar Broyhill     (full legal, mixed case)
JAMES EDGAR BROYHILL     (full legal, all caps)
JAMES EDGAR 'ED' BROYHILL (legal + nickname in single quotes)
```

…across SEVEN address renderings (`525 North Hawthorne Road`, `525 N HAWTHORNE ROAD`, `525 N. HAWTHORNE RD`, `525 N HAWTHORNE RD`, `525 NORTH HAWTHORNE RD`, `525 N. HAWTHORN ROD.` (typo), `525 NORTH HAWTHORNE ROAD`)…with city variants (`Winston Salem` / `WINSTON SALEM` / `Winston-Salem` / `WINSTON-SALEM`) and zip variants (`27104` vs `27104-3224`) and employer typos (`ANVIL VENTURE GROUP` / `ANVIL VENTURE` / `ANVIL FENTURE GROUP` / `ANVIL VENTURE, LP`).

**Cluster 5005999 holds only 40 of those 122 rows** (the canary cluster, all `ED BROYHILL` variants). The other ~82 rows are in OTHER clusters under JAMES variants — which means Ed-the-person is fragmented across multiple cluster_id_v2's. **Some of those other clusters are likely in the dark pile.**

**Hypothesis:** the 60% dark donors are not "missing data" — they are over-fragmented into many small clusters because the Stage 2 normalizer was too literal.

### 3. DataTrust's schema reveals their dedupe pathway

From `database/schemas/datatrust_complete_schema.sql`:

- Every name is parsed into components: `name_prefix`, `first_name`, `middle_name`, `last_name`, `name_suffix`
- Every address is parsed into 7 components: `home_street_number`, `home_street_predirection` (N/S/E/W), `home_street_name`, `home_street_type` (St/Ave/Rd/Blvd), `home_street_postdirection`, `home_unit_type`, `home_unit_number`
- Geographic columns: `home_county`, `county_fips_code`, `congressional_district_current`, `state_senate_district`, `state_house_district`, `precinct_code`, `precinct_name`, `township_name`

**DataTrust matches on canonical components, not free-text strings.** Anything we join on must be normalized to their canonical form (ALL CAPS, abbreviation-collapsed, component-parsed).

### 4. NC State Voter ID is intelligently structured

Format: `<2-letter county code><5-7 digit sequential number>`. Confirmed by example from `docs/HETZNER_DB_AUDIT_DATATRUST_NCBOE_2026-04-14.md`:

```
person 75287:  JAMES POPE  EH34831  → 134 txns / $790,984 (Art Pope)
person 290476: JAMES POPE  BN196820 → 12 txns  / $2,241   (DIFFERENT person)
```

**The 2-letter prefix encodes county.** Two different "JAMES POPE"s in NC are distinguished by their SVI prefix (EH vs BN). This is a built-in disambiguator — and a powerful filter for our matching:

A donor at zip 27104 (Forsyth County) → must match a DataTrust voter whose SVI starts with the Forsyth code. Wrong-prefix candidates can be discarded instantly.

**RNC RegID** is a UUID v4 — opaque, no encoded info. We rely on SVI prefix, not RNC, for the geography signal.

### 5. The current 39% match rate is a floor, not a ceiling

Modeled potential: **88-92%** with the corrected pathway (component-parse + ALL-CAPS canonical form + adjacency clustering on alphabetical sort + county-anchor via SVI prefix + middle-initial expansion + nickname lookup + suffix as separator-not-blocker).

Residual ~8-12% are genuinely hard (deaths between snapshots, recent registrations not yet in DataTrust, name changes for marriage, true typos with no other rows to cross-check).

---

## The diagnosis (what to run on Hetzner)

This is a **dry-run / SELECT-only** spec. Cursor executes; you orchestrate; Ed authorizes if a write is later needed.

### Pre-flight verification (4 read-only queries)

**A. Confirm row totals match the CSV.**
```sql
SET statement_timeout = 0;
SELECT
  (SELECT count(*)            FROM staging.ncboe_party_committee_donations)             AS total_rows,
  (SELECT count(DISTINCT cluster_id_v2) FROM staging.ncboe_party_committee_donations)   AS distinct_clusters,
  (SELECT round(sum(norm_amount)::numeric,2) FROM staging.ncboe_party_committee_donations) AS sum_norm_amount;
-- Expected: 293,396 rows / ~60,238 clusters / $53,352,538.17
```

**B. Confirm canaries intact.**
```sql
-- Ed canary
SELECT cluster_id_v2, count(*) AS rows, sum(norm_amount) AS sum_amt, max(rnc_regid_v2) AS rnc
FROM staging.ncboe_party_committee_donations
WHERE cluster_id_v2 = 5005999 GROUP BY cluster_id_v2;
-- Expected: 40 / $155,945.45 / c45eeea9-...

-- Pope canary
SELECT cluster_id_v2, count(*) AS rows, sum(norm_amount) AS sum_amt, max(rnc_regid_v2) AS rnc
FROM staging.ncboe_party_committee_donations
WHERE cluster_id_v2 = 5037665 GROUP BY cluster_id_v2;
-- Expected: 22 / $378,114.05 / 3cea201e-...

-- Melanie isolation (must be 0 in Ed's cluster)
SELECT count(*) FROM staging.ncboe_party_committee_donations
WHERE cluster_id_v2 = 5005999 AND norm_first ILIKE 'MELANIE';
-- Expected: 0
```

**C. Inventory all BROYHILL clusters.**
```sql
SELECT cluster_id_v2, count(*) AS rows, sum(norm_amount) AS sum_amt,
       string_agg(DISTINCT name, ' | ' ORDER BY name) AS name_variants,
       string_agg(DISTINCT street_line_1, ' | ') AS addr_variants,
       max(rnc_regid_v2) AS rnc
FROM staging.ncboe_party_committee_donations
WHERE upper(norm_last) = 'BROYHILL'
GROUP BY cluster_id_v2
ORDER BY sum_amt DESC;
-- Confirms: ~40 in cluster 5005999, others scattered.
```

**C-2. Name-parse audit on BROYHILL — verify the parser actually parsed cleanly.**
```sql
-- For every BROYHILL row, show: raw name, the parsed components, and the cluster.
-- We expect to see whether 'ED' (in single quotes) ended up in last_name, nickname,
-- or somewhere else. We expect to see whether middle name was captured.
SELECT
  cluster_id_v2,
  name AS raw_name,
  norm_first, norm_middle, norm_last, norm_suffix, norm_nickname,
  street_line_1, norm_zip5,
  is_matched_v2, rnc_regid_v2
FROM staging.ncboe_party_committee_donations
WHERE upper(norm_last) ILIKE '%BROYHILL%'
   OR upper(name)      ILIKE '%BROYHILL%'
ORDER BY cluster_id_v2, name;

-- Look for: single quotes in norm_last or norm_first, missing middle names,
-- quoted nicknames not extracted, suffix not captured.
```

**C-3. Distinct parse-quality signals across the whole file.**
```sql
-- How many rows have suspicious parse signals?
SELECT
  count(*) FILTER (WHERE norm_last  ILIKE '%''%')                   AS last_has_singlequote,
  count(*) FILTER (WHERE norm_first ILIKE '%''%')                   AS first_has_singlequote,
  count(*) FILTER (WHERE norm_last  ILIKE '% %' AND norm_last NOT LIKE '%-%') AS last_has_space,
  count(*) FILTER (WHERE length(norm_first) = 1 AND norm_middle IS NULL)      AS first_is_single_char,
  count(*) FILTER (WHERE norm_first IS NULL OR norm_first = '')     AS first_empty,
  count(*) FILTER (WHERE norm_last  IS NULL OR norm_last  = '')     AS last_empty,
  count(*) FILTER (WHERE norm_suffix IS NOT NULL)                   AS has_suffix,
  count(*) FILTER (WHERE norm_nickname IS NOT NULL)                 AS has_nickname,
  count(*)                                                          AS total_rows
FROM staging.ncboe_party_committee_donations;

-- Expected red flags:
--   last_has_singlequote > 0 → quoted nicknames being absorbed into last_name (BROKEN)
--   last_has_space large    → multi-word last names parsed as one (could be OK)
--   first_empty > 0         → parser failed on some rows
--   has_nickname very low   → nickname column not being populated even when nickname is present
```

**D. Inventory the geography reference tables — do they exist?**
```sql
-- NC zip5 → county lookup
SELECT count(*) FROM information_schema.tables
WHERE table_schema='core' AND table_name LIKE '%zip%county%';

-- NCSBE 2-letter county code lookup
SELECT count(*) FROM information_schema.tables
WHERE table_schema='core' AND (table_name ILIKE '%sbe_county%' OR table_name ILIKE '%county_code%');

-- DataTrust column with county prefix on state_voter_id
SELECT count(DISTINCT substring(state_voter_id from 1 for 2)) AS distinct_prefixes,
       count(*) AS total
FROM core.datatrust_voter_nc
WHERE state_voter_id IS NOT NULL;
-- Expected ~100 distinct prefixes (one per NC county)
```

### Diagnostic dry-run — does new ruleset rescue dark clusters?

**Goal:** measure how many of the 36,367 dark clusters would match cleanly under the corrected ruleset, without touching any data.

```sql
WITH dark_clusters AS (
  SELECT DISTINCT cluster_id_v2
  FROM staging.v_committee_donor_cluster_rollup_v1
  WHERE rollup_status NOT IN ('READY_MATCHED','CANARY_HOLD')
),
dark_rows AS (
  SELECT s.*
  FROM staging.ncboe_party_committee_donations s
  JOIN dark_clusters d USING (cluster_id_v2)
),
new_match_attempt AS (
  SELECT
    d.cluster_id_v2,
    d.id AS row_id,
    -- Component-canonicalized name
    upper(btrim(regexp_replace(d.norm_last, '[^A-Z]', '', 'gi')))   AS clast,
    upper(btrim(regexp_replace(d.norm_first, '[^A-Z]', '', 'gi')))  AS cfirst,
    -- Middle initial (1 char if available)
    left(upper(btrim(regexp_replace(coalesce(d.norm_middle,''), '[^A-Z]', '', 'gi'))),1) AS cmid_init,
    -- Zip5
    left(coalesce(d.norm_zip5, regexp_replace(d.zip_code,'[^0-9]','','g')), 5) AS czip5,
    -- DataTrust candidate match
    dtv.rnc_regid       AS dt_rnc,
    dtv.state_voter_id  AS dt_svi,
    substring(dtv.state_voter_id from 1 for 2) AS dt_svi_prefix
  FROM dark_rows d
  LEFT JOIN core.datatrust_voter_nc dtv
    ON  upper(dtv.norm_last)  = upper(d.norm_last)
    AND upper(dtv.norm_first) = upper(d.norm_first)
    AND left(coalesce(dtv.norm_zip5, dtv.mailzip5),5)
        = left(coalesce(d.norm_zip5, regexp_replace(d.zip_code,'[^0-9]','','g')),5)
)
SELECT
  count(DISTINCT cluster_id_v2)                                          AS dark_clusters_total,
  count(DISTINCT cluster_id_v2) FILTER (WHERE dt_rnc IS NOT NULL)        AS clusters_with_any_match,
  count(DISTINCT cluster_id_v2) FILTER (WHERE dt_rnc IS NOT NULL
        AND (SELECT count(DISTINCT dt_rnc)
             FROM new_match_attempt nma
             WHERE nma.cluster_id_v2 = new_match_attempt.cluster_id_v2
               AND nma.dt_rnc IS NOT NULL) = 1)                          AS clusters_single_unambiguous_match
FROM new_match_attempt;
```

**Decision tree based on output:**

| `clusters_single_unambiguous_match` / `dark_clusters_total` | Diagnosis | Path |
|---|---|---|
| **≥ 80%** | Matching was the problem. Existing clusters are correctly bounded; they just weren't getting the right RNC. | **Option B execution** — apply new rules to dark clusters only. Don't touch matched clusters. New rate ~87%. |
| **60-80%** | Mixed problem. Some dark clusters are pure-match issues; others are clustering issues. | **Hybrid** — apply Option B to the 60-80% that match cleanly, run Option C₂ adjacency-merge on the residual. |
| **< 60%** | Clustering is the dominant problem. Dark clusters are over-fragmented. | **Option C₂** — adjacency-merge pass first, then re-match. |

### Adjacency-merge pass (only if needed; spec only — do not run)

Read-only proposal output. Identifies cluster pairs that should be merged based on (a) name+zip5 adjacency in alphabetical order, (b) shared address after component-parse, (c) compatible suffix policy.

```sql
-- Sliding-window adjacency on the alphabetically sorted file
WITH sorted AS (
  SELECT id, cluster_id_v2, norm_last, norm_first, norm_middle, norm_suffix,
         norm_zip5, street_line_1, name,
         row_number() OVER (ORDER BY upper(norm_last), upper(norm_first), upper(norm_middle)) AS rn
  FROM staging.ncboe_party_committee_donations
  WHERE cluster_id_v2 IS NOT NULL
),
neighbors AS (
  SELECT a.cluster_id_v2 AS cluster_a, b.cluster_id_v2 AS cluster_b,
         a.norm_last AS last_a, b.norm_last AS last_b,
         a.norm_first AS first_a, b.norm_first AS first_b,
         a.norm_zip5 AS zip5_a, b.norm_zip5 AS zip5_b
  FROM sorted a
  JOIN sorted b
    ON b.rn BETWEEN a.rn + 1 AND a.rn + 50
   AND a.cluster_id_v2 <> b.cluster_id_v2
   AND upper(a.norm_last) = upper(b.norm_last)
   AND a.norm_zip5 = b.norm_zip5
)
SELECT cluster_a, cluster_b,
       count(*) AS coadjacent_row_pairs,
       string_agg(DISTINCT first_a || '/' || first_b, ', ') AS first_pairs
FROM neighbors
GROUP BY cluster_a, cluster_b
HAVING count(*) >= 3
ORDER BY coadjacent_row_pairs DESC
LIMIT 1000;
-- Output: top 1,000 cluster-pair merge candidates, sorted by adjacency strength.
-- Manual review by Ed + Perplexity on top 100 by combined dollar volume.
```

---

## Required report from Perplexity

After running the diagnostic, return:

| metric | value |
|---|---|
| dry-run timestamp | |
| Pre-flight (A): total rows / clusters / sum_amount | |
| Pre-flight (B): Ed canary intact (Y/N) | |
| Pre-flight (B): Pope canary intact (Y/N) | |
| Pre-flight (B): Melanie isolation (Y/N) | |
| Pre-flight (C): BROYHILL cluster count | |
| Pre-flight (C): rows in cluster 5005999 | |
| Pre-flight (C): rows OUTSIDE 5005999 with last=BROYHILL and zip5=27104 | |
| Pre-flight (D): zip-county reference table exists (Y/N + name) | |
| Pre-flight (D): SBE-prefix reference table exists (Y/N + name) | |
| Pre-flight (D): distinct SVI prefixes in `core.datatrust_voter_nc` | |
| Diagnostic: dark_clusters_total | |
| Diagnostic: clusters_with_any_match | |
| Diagnostic: clusters_single_unambiguous_match | |
| Diagnostic: ratio (single / total) — drives the path decision | |
| Path recommendation (B / C₂ / Hybrid) | |

Plus 20 sample dark clusters with their proposed RNC matches (cluster_id_v2, name variants, address variants, proposed RNC, SVI prefix vs zip-derived expected prefix).

---

## What we may have missed — please check

Ed asked specifically: **"add or warn us about issues we didn't see."** Please verify these explicitly and report any other concerns.

1. **Is `core.datatrust_voter_nc` the latest snapshot?** Date of load? Row count? Any voters refreshed since the cluster_id_v2 build?
2. **Schema columns the audit may have missed.** Are there columns on `staging.ncboe_party_committee_donations` we didn't list? Anything that could carry hidden match signal (e.g., `voter_reg_num`, `birth_year`, `account_code` patterns)?
3. **`match_method` history.** For the 23,871 already-matched clusters, what's the breakdown of `dt_match_method`? T1, T2, T3, T4, T6 — which tier carried each?
4. **Honorific issues.** `CLAUDE.md` mentions honorifics as a guard. Any honorifics in the donation file (Mr., Mrs., Dr., Hon.) that might be conflating with name parsing?
5. **Embedded nicknames in single quotes.** The pattern `'ED'` inside `JAMES EDGAR 'ED' BROYHILL` — is this widespread? How many rows? Do any donors have nicknames in different bracket styles (parens, double quotes)?
6. **Address typos with rooftop precision.** Do you have access to the USPS rooftop / DSF data via DataTrust or Geocodio that could correct typos like `HAWTHORN` → `HAWTHORNE`?
7. **NCSBE county-code reference.** Does it exist as a table? If not, public NCSBE data should let us load one — confirm or propose.
8. **Suffix policy on `core.datatrust_voter_nc`.** How is `name_suffix` populated? Is it consistent format (Sr/Jr/II/III), or do we need normalization on the DataTrust side too?
9. **Are there sub-prefixes in voter IDs?** I saw EH, AW, BE etc. Are any 3-letter prefixes (AAA, AAB)? Any non-letter prefixes?
10. **Pre-existing merge proposals.** Have you already produced cluster merge candidates somewhere? If yes, where, and how do they compare to the adjacency pass proposed above?
11. **Deceased / inactive donors.** What's the data lineage on this — does `core.datatrust_voter_nc` include deceased voters from the last 10 years, or only currently-active? Deceased donors from 2015 might not match a 2024 voter snapshot.
12. **Form 990 / FEC cross-validation.** Out of scope for this run, but is there an out-of-band truth source (FEC, 990 filings) that lists known major donors with canonical names + addresses we could use as labeled training data?

---

## Authorization protocol (no writes in this packet)

- Pre-flight + Diagnostic + Adjacency proposal queries are all `SELECT` only.
- Cursor runs them on Hetzner. No writes.
- After Perplexity returns the report, Ed reviews. Path B / C₂ / Hybrid is decided.
- Any subsequent apply (cluster_id_v2 update, new RNC assignments) requires `AUTHORIZE` from Ed (single-word per the new Claude protocol — Perplexity may still use `I AUTHORIZE THIS ACTION` per her existing convention; both work).

---

## Canaries (must be intact in Perplexity's report)

| Canary | Expected |
|---|---|
| `raw.ncboe_donations` cluster 372171 | 147 / $332,631.30 / RNC `c45eeea9-663f-40e1-b0e7-a473baee794e` |
| Ed committee cluster 5005999 | 40 / $155,945.45 / RNC `c45eeea9-...` |
| Pope committee cluster 5037665 | 22 / $378,114.05 / RNC `3cea201e-8cdd-49e0-aceb-dfa6e7072f68` |
| MELANIE in Ed cluster 5005999 | 0 |
| KATHERINE in Pope cluster 5037665 | 0 |
| `committee_name_resolved` nulls | 0 / 293,396 |

Failure on any canary = halt and report. Do not proceed to diagnostic.

---

## Closing note for Perplexity

Ed's read on this is sharp: the file is alphabetically sorted by name, so adjacency carries free signal that the current pipeline isn't using. The DataTrust schema reveals their dedupe pathway (component parsing + ALL-CAPS canonical form + structured geography). The 39% floor is a function of overly literal normalization, not a true ceiling.

Please run the read-only diagnostic, return the table above, and flag anything from the "what we may have missed" list — or other items I didn't think to ask. Ed and Claude will read your report and decide the execution path.

Files referenced (all in the GitHub repo or central folder, all in the morning scrape route):

- `docs/runbooks/PARTY_COMMITTEE_AUDIT_20260427.md` (full audit)
- `docs/runbooks/COMMITTEE_DONOR_ROLLUP_V1_PLAN.md`
- `docs/runbooks/committee_donor_rollup_v1_qa_20260426.md`
- `docs/runbooks/committee_donor_cluster_rollup_match_apply_dryrun_20260426.md`
- `database/schemas/datatrust_complete_schema.sql`
- `docs/DATATRUST_API_ANSWERS.md`
- `docs/HETZNER_DB_AUDIT_DATATRUST_NCBOE_2026-04-14.md`
- `sessions/2026-04-02_datatrust_dedup_enhancement.sql`
- Source CSV at `/Users/Broyhill/Library/.../uploads/republican-party-committees-2015-2026.csv` (293,396 rows, sorted alphabetically by Name, all-NC, no phone/email columns)

End of handoff. Awaiting your read-only diagnostic + warnings.

— Claude (Anthropic)
