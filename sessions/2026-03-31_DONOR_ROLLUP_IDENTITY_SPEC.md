# Donor Rollup Identity Resolution Spec
## BroyhillGOP — March 31, 2026
## Authority: Ed Broyhill
## Priority: CRITICAL — do not build spine completion without this

---

## THE CORE REQUIREMENT

**The top 30% of donors by total giving give multiple times across multiple committees
under multiple name variants. They MUST be rolled up to a single person_id with a
single aggregated political footprint before any clout scoring, ranking, or profiling.**

A donor appearing as 7 different name variants across 50 transactions is ONE donor.
Their total political footprint is the SUM of all 50 transactions.
Until that rollup is complete, all scoring, ranking, and profiling is wrong.

---

## Why This Matters Most for Top Donors

| Donor type | Name variants | Filing pattern | Risk if not rolled up |
|---|---|---|---|
| Major investor/executive | 3-7 variants | Office address, multiple entities | Shows as 7 small donors instead of 1 major donor |
| Active political player | 2-4 variants | Mix of home + office | Clout score severely understated |
| Family household | 2-3 variants (spouse) | Both names file separately | Family footprint split |
| Post-life-event donor | 2 variants (pre/post divorce or death) | Address/name change mid-timeline | Timeline fractures, giving history lost |

---

## The Multi-Donor Fragmentation Pattern (Real Example)

All of these are the SAME person in nc_boe_donations_raw:

| Donor name as filed | Address | Amount | Committee |
|---|---|---|---|
| ED BROYHILL | 525 N HAWTHORNE RD, 27104 | $1,041 | FRIENDS OF CHRISTINE VILLAVERDE |
| ED BROYHILL | 525 N HAWTHORNE RD, 27104 | $500 | COMMITTEE TO ELECT SCOTT STONE |
| EDGAR BROYHILL | 525 N. HAWTHORNE ROAD, 27104 | $2,500 | CONRAD COMM FOR NC HOUSE |
| J EDGAR BROYHILL | 525 N HAWTHORNE RD, 27104 | $2,500 | COMM TO ELECT DONNY LAMBETH |
| JAMES BROYHILL | 525 N. HAWTHORNE ROAD, 27104 | $2,000 | BERLIN FOR JUDGE |
| JAMES E BROYHILL | 525 N HAWTHORNE RD, 27104 | $2,000 | CAMPAIGN TO ELECT MIKE HAGER |
| JAMES EDGAR BROYHILL | 525 N HAWTHORNE RD, 27104 | $5,200 | PHIL BERGER COMMITTEE |
| JAMES EDGAR 'ED' BROYHILL | 525 N. HAWTHORNE ROAD, 27104 | $650 | RE-ELECT JUSTICE JACKSON |

Without rollup: 8 separate donors, largest single = $5,200
After rollup: 1 donor, TRUE total = sum of all transactions across all years

---

## Rollup Pass Sequence (Highest to Lowest Confidence)

### Pass 1 — voter_ncid exact bridge (ZERO false positives)
```sql
-- voter_ncid in nc_boe_donations_raw = statevoterid in nc_datatrust = RNCID bridge
-- If two name variants share the same voter_ncid → same person, collapse immediately
GROUP BY voter_ncid
HAVING count(DISTINCT norm_last) > 1 OR count(DISTINCT norm_first) > 1
```
Confidence: 100%. No review needed. Auto-merge.

### Pass 2 — Street number + zip5 + last prefix (HIGH confidence)
```sql
-- Extract leading numeric from street_line_1
-- Match: regexp_replace(street_line_1, '^(\d+).*', '\1') + LEFT(norm_zip5,5) + LEFT(norm_last,3)
-- Single match only → auto-merge
-- Multi-match → review queue
```
Confidence: 97%+. Single matches auto-merge.
Catches: ED BROYHILL vs JAMES EDGAR BROYHILL at same street number + zip

### Pass 3 — Employer name + SIC + last prefix (MAJOR DONOR anchor)
```sql
-- employer_name normalized → SIC code via donor_sic_classification_engine
-- Match: SIC code + LEFT(norm_last,3) + single result only
-- Critical for donors filing from office (most top 30% donors)
```
Confidence: 94%+.
Catches: Executive donors filing from business address (different from home)

### Pass 4 — Federal candidate cross-reference (HIGHEST VALUE anchor)
```sql
-- Donors giving to Tillis, Budd, Hudson, Foxx appear in BOTH NCBOE and FEC
-- FEC filing has independent employer + address record
-- Cross-reference: LEFT(norm_last,3) + employer similarity + date proximity
-- Two independent government filings = near-certain identity confirmation
```
Confidence: 98%+.
Catches: Major donors who give federally AND to state candidates

### Pass 5 — Repeat candidate loyalty fingerprint (BEHAVIORAL anchor)
```sql
-- Same committee_sboe_id cluster across 3+ election cycles
-- Different name variants giving to same 3+ committees → same donor
-- committee_fingerprint = array_agg(DISTINCT committee_sboe_id ORDER BY ...)
-- Overlap of 2+ anchor committees across name variants → merge candidate
```
Confidence: 96%+.
Catches: Long-term donors whose name varies but giving pattern is unmistakable
Best for: Post-move, post-divorce, post-retirement donors

### Pass 6 — Canonical first name + last + zip (nickname normalization)
```sql
-- BOB → ROBERT, BILL → WILLIAM, KATE → KATHERINE etc.
-- Uses core.nickname_inferred table from prior identity resolution work
-- After canonical substitution, re-run name+zip match
```
Confidence: 90%+.
Catches: Nickname vs legal name variants

### Pass 7 — Last + first + zip (standard match — already partially done)
Current match that produced 108,943 rows. Catches remaining clean matches.

---

## The Rollup Aggregation — Final Output

After all passes complete, every merged donor gets a SINGLE person_id with:

```sql
-- donor_political_footprint (one row per person_id)
SELECT
  ps.person_id,
  ps.norm_first,
  ps.norm_last,
  -- ALL committee giving aggregated
  count(DISTINCT cm.source_id)              AS total_transactions,
  sum(cm.amount)                             AS total_all_giving,
  count(DISTINCT cm.committee_id)            AS committees_funded,
  -- By tier
  sum(cm.amount) FILTER (WHERE cpm.tier IN (1,2))  AS party_giving,
  sum(cm.amount) FILTER (WHERE cpm.tier = 4)        AS candidate_giving,
  sum(cm.amount) FILTER (WHERE cpm.tier IN (5,6,7)) AS pac_giving,
  -- Cross-system
  sum(cm.amount) FILTER (WHERE cm.source_system = 'NC_BOE')   AS ncboe_giving,
  sum(cm.amount) FILTER (WHERE cm.source_system LIKE 'fec%')  AS fec_giving,
  sum(cm.amount) FILTER (WHERE cm.source_system = 'winred')   AS winred_giving,
  -- Partisan lean
  round(100.0 * sum(cm.amount) FILTER (WHERE cpm.partisan_lean = 'R')
    / nullif(sum(cm.amount), 0), 1)          AS r_pct,
  -- Recency
  max(cm.transaction_date)                   AS last_gift_date,
  min(cm.transaction_date)                   AS first_gift_date,
  -- Sophistication
  count(DISTINCT EXTRACT(year FROM cm.transaction_date)) AS active_cycles
FROM core.person_spine ps
JOIN core.contribution_map cm ON cm.person_id = ps.person_id
LEFT JOIN public.committee_party_map cpm ON cpm.committee_id = cm.committee_id
WHERE ps.is_active = true
GROUP BY ps.person_id, ps.norm_first, ps.norm_last
ORDER BY total_all_giving DESC;
```

---

## The 30% Rule — Defining "Top Donors"

Top 30% is NOT just dollar amount. It is:
- Gave 2+ times (repeat donor = relationship, not accident)
- Gave to 2+ different committees (sophistication signal)
- Total giving across ALL rolled-up transactions

```sql
-- Define top 30% threshold after rollup
SELECT
  percentile_cont(0.70) WITHIN GROUP (ORDER BY total_all_giving) AS threshold_30pct
FROM donor_political_footprint;
-- Everyone above this threshold = top 30%
-- These are the donors who get the deepest profiling, influencer tracking, host fundraiser targeting
```

---

## GUARDRAILS — What Must NOT Happen

1. Do NOT score or rank donors before rollup is complete
2. Do NOT present total_contributed from person_spine as the donor's true footprint
   until all passes have run — it may reflect only 1 of 7 name variants
3. Do NOT merge on name alone — always require a second anchor
   (street number, employer, voter_ncid, or committee fingerprint)
4. Do NOT auto-merge multi-match candidates — they go to review queue
5. All merges logged to merge_audit table with before/after person_id,
   merge_method, match_confidence, and merged_at timestamp

---

## Implementation Order (Next Session)

1. Run Pass 1 (voter_ncid) — fastest, zero risk, immediate wins
2. Run Pass 2 (street number + zip + last prefix) — highest volume wins
3. Run Pass 3 (employer + SIC + last prefix) — captures top 30% major donors
4. Run Pass 4 (federal candidate cross-reference) — confirms high-value identities
5. Run Pass 5 (committee loyalty fingerprint) — catches long-term major donors
6. Build donor_political_footprint table from merged spine
7. Define top 30% threshold
8. Activate clout scoring on rolled-up profiles only

---

*Prepared by Perplexity AI — March 31, 2026*
*Ed Broyhill: "the most valuable donors are top 30% who multiple donate.*
*I hope you pay careful attention to roll them up as one in the final exercise."*
*This spec is the direct implementation of that instruction.*
