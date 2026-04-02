# MASTER DEPLOYMENT — BroyhillGOP Complete Dedup + Enrichment + Rollup

**Date:** 2026-04-02
**Prepared by:** Perplexity (CEO, AI team)
**For:** Cursor (executor), Ed Broyhill (authorization authority)

**MANDATORY:** Read `sessions/SESSION_START_READ_ME_FIRST.md` and `sessions/2026-04-02_SESSION_TRANSCRIPT.md` before executing anything below.

---

## Pre-Deployment Checklist

Before ANY SQL runs:

- [ ] Cursor confirms it has read the session transcript
- [ ] Ed is present and authorizing each phase
- [ ] Supabase project: `isbgjpnbocdkeslofota`
- [ ] Verify connection: `SELECT COUNT(*) FROM core.person_spine WHERE is_active = true;` → expect **128,047**
- [ ] Verify canary: `SELECT person_id, norm_first, norm_last, total_contributed FROM core.person_spine WHERE person_id = 26451;` → expect JAMES BROYHILL, $352,415.86

---

## Execution Order — 8 Stages

### STAGE 1: Schema Additions (Phase 0 from V3.1)

**Source:** `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` — lines 1-106 (Phase 0)

**What it does:** Adds 12 new columns to `core.person_spine`:
- `birth_year`, `canonical_first_name`, `preferred_name`, `legal_first_name`
- `best_employer`, `addr_number`, `addr_type`, `record_quality`
- `honorary_title`, `title_salutation`, `title_branch`, `title_status`

**Risk:** ZERO — DDL only, adds nullable columns, cannot lose existing data.

**Verify after:**
```sql
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'core' AND table_name = 'person_spine'
AND column_name IN ('birth_year','canonical_first_name','preferred_name',
  'legal_first_name','best_employer','addr_number','addr_type',
  'record_quality','honorary_title','title_salutation','title_branch','title_status')
ORDER BY column_name;
```
→ Expect 12 rows.

**Ed says GO → Execute Phase 0.**

---

### STAGE 2: Enrichment (Phase 1 from V3.1)

**Source:** `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` — lines 108-230 (Phase 1)

**What it does:** Fills empty columns from nc_voters (primary) and nc_datatrust (fallback). Each UPDATE touches ONE column only. Every UPDATE has `WHERE column IS NULL` guard — cannot overwrite existing data.

**Run in this exact order, verify after each:**

| Step | Update | Expected rows affected |
|------|--------|----------------------|
| 1A | `legal_first_name` from nc_voters | ~127,643 |
| 1B | `middle_name` from nc_voters | ~120,626 |
| 1C | `middle_name` from nc_datatrust (gaps) | ~9 |
| 1D | `suffix` from nc_voters | ~8,577 |
| 1E | `suffix` from nc_datatrust (gaps) | small |
| 1F | `birth_year` from nc_voters | ~127,643 |
| 1G | `canonical_first_name` from nc_voters | ~6,470 |
| 1H | `household_id` from nc_datatrust | ~92,609 |
| 1I | `addr_number` + `addr_type` from street | ~most records with street |

**Canary after all enrichment:**
```sql
SELECT person_id, norm_first, legal_first_name, middle_name, suffix,
       birth_year, canonical_first_name, household_id, addr_number, addr_type
FROM core.person_spine WHERE person_id = 26451;
```
→ Expect: legal_first_name=JAMES, middle_name=EDGAR, suffix=II, birth_year=1954, canonical_first_name=NULL (correct — JAMES is already legal), addr_number=525, addr_type=ST

**Ed says GO → Execute Phase 1, one UPDATE at a time.**

---

### STAGE 3: Best Employer Backward Scan (Phase 2 from V3.1)

**Source:** `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` — lines 232-273 (Phase 2)

**What it does:** For each spine person with NC BOE donations, finds the most recent NON-RETIRED employer by scanning backward from 2026.

**Risk:** LOW — fills `best_employer` only where NULL. Cannot touch other columns.

**Verify:**
```sql
SELECT person_id, norm_first, norm_last, best_employer
FROM core.person_spine
WHERE norm_last = 'POPE' AND norm_first LIKE 'ART%' AND is_active = true;
```
→ Art Pope should get VARIETY WHOLESALERS (or variant).

```sql
SELECT best_employer, COUNT(*) FROM core.person_spine
WHERE is_active = true AND best_employer IS NOT NULL
GROUP BY best_employer ORDER BY COUNT(*) DESC LIMIT 20;
```
→ Verify top employers look real (not RETIRED, not SELF-EMPLOYED).

**Ed says GO → Execute Phase 2.**

---

### STAGE 4: Record Quality Classification (Phase 3 from V3.1)

**Source:** `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` — lines 276-300 (Phase 3)

**What it does:** Classifies every active spine record as PRETTY or UGLY. PRETTY = has name + zip + address number + at least one of (voter_ncid, best_employer, email). UGLY = everything else.

**Risk:** LOW — sets one column (`record_quality`). Reversible by re-running.

**Verify:**
```sql
SELECT record_quality, COUNT(*) FROM core.person_spine
WHERE is_active = true GROUP BY record_quality;
```
→ Expect majority PRETTY (99.98% have voter_ncid).

**Ed says GO → Execute Phase 3.**

---

### STAGE 5: Preferred Name (Phase 4 from V3.1)

**Source:** `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` — lines 303-332 (Phase 4)

**What it does:** For each spine person, finds the most frequently used first name across all NC BOE donation filings. That becomes `preferred_name`.

**Risk:** LOW — fills `preferred_name` only where NULL.

**Canary:**
```sql
SELECT person_id, norm_first, preferred_name
FROM core.person_spine WHERE person_id = 26451;
```
→ Ed's preferred_name should be ED (most frequent on donation filings), not JAMES.

**Ed says GO → Execute Phase 4.**

---

### STAGE 6: Honorary Titles

**Source:** `sessions/2026-04-02_HONORARY_TITLE_ENRICHMENT.sql` (push needed — see below)

**What it does:**
1. Creates `staging.contest_title_map` — maps contest_name patterns to titles (34 mappings)
2. Builds `staging.spine_honorary_titles` — matches 669 spine donors to their highest office
3. Writes `honorary_title` and `title_salutation` to spine (one column per UPDATE)
4. Creates `staging.title_manual_overrides` for military ranks (manual entry later)

**Run the T3 diagnostics BEFORE T4 writes:**
- T3a: Count donors getting titles (expect ~669)
- T3b: Distribution by title type
- T3c: Sample names + titles
- T3d: BROYHILL CANARY — Ed should NOT get a title (unless he ran for office)
- T3e-g: Spot checks — Terry Johnson=Sheriff, Donna Stroud=Judge, Ralph Hise=Senator

**Ed says GO → Execute T1-T3 (staging), review, then T4 (spine writes).**

---

### STAGE 7: Blocklists + Merge Passes (Phases 5-7 from V3.1)

**Source:** `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` — lines 334-end

**What it does:**
1. Creates staging tables (`staging.v3_merge_blocklist`, `staging.v3_merge_candidates`)
2. Runs 3 blocklists: suffix conflicts, birth year gaps (>2 years), middle name conflicts
3. Runs 7 merge passes — all produce CANDIDATES ONLY in staging. Nothing touches the spine.
4. UGLY records are NEVER considered.

**This is the part that requires courage — but it writes ZERO rows to the spine.**

**Run Phase 8 canaries IMMEDIATELY after:**
```sql
-- Ed must NOT appear as merge candidate
SELECT * FROM staging.v3_merge_candidates
WHERE keeper_person_id = 26451 OR merge_person_id = 26451;

-- Art Pope check
SELECT mc.*, s1.norm_first as keeper_first, s2.norm_first as merge_first
FROM staging.v3_merge_candidates mc
JOIN core.person_spine s1 ON mc.keeper_person_id = s1.person_id
JOIN core.person_spine s2 ON mc.merge_person_id = s2.person_id
WHERE s1.norm_last = 'POPE' OR s2.norm_last = 'POPE';

-- Summary by pass
SELECT match_method, COUNT(*) as candidates,
  ROUND(AVG(confidence),2) as avg_conf
FROM staging.v3_merge_candidates
GROUP BY match_method ORDER BY match_method;

-- Blocklist summary
SELECT LEFT(block_reason, POSITION(':' IN block_reason)-1) as reason,
  COUNT(*) as blocked_pairs
FROM staging.v3_merge_blocklist
WHERE POSITION(':' IN block_reason) > 0
GROUP BY 1 ORDER BY 2 DESC;
```

**Ed reviews candidates → decides whether to proceed to merge execution (separate step, NOT in V3.1).**

---

### STAGE 8: Candidate/Committee Matching (existing scripts)

**This is NOT new code — these were written March 31-April 1 and already exist in the repo.**

**Source files (run in this order):**

| Order | File | Purpose |
|-------|------|---------|
| 8a | `sessions/2026-04-01_partisan_flag_fix.sql` | Rebuild `staging.boe_donation_candidate_map` + partisan flags |
| 8b | `sessions/2026-03-31_committee_candidate_fuzzy_match.sql` | Fuzzy match → `staging.committee_candidate_bridge` |
| 8c | `sessions/2026-04-01_committee_name_clean_patch.sql` | Clean committee names, backfill candidate_name |
| 8d | `sessions/2026-03-31_donor_candidate_matching.sql` | Donor-to-candidate matching |

**These scripts already handle the 1,105 missing candidate_name rows** (420 registry-has-no-name + 685 not-in-registry). The candidate names are extracted from committee name strings using patterns already coded in the fuzzy match and clean patch.

**Run AFTER Stages 1-7 because the enriched spine (middle names, birth years, preferred names) improves matching accuracy.**

---

## NOT IN THIS DEPLOYMENT

These items are staged but require separate authorization:

1. **Merge execution** — The actual spine merges from `staging.v3_merge_candidates`. This is a separate step after Ed reviews the candidates from Stage 7.

2. **Donation rollup INSERT** — `INSERT INTO core.contribution_map` with gates (`will_insert > 108,943`, Broyhill canary vs $478,632). The INSERT SQL body is NOT in the repo — it's in Cursor's local worktree only. Files needed:
   - `sessions/donor_rollup_execute.sql` (NOT ON GITHUB — push from worktree)
   - `sessions/2026-04-01_rollup_to_core.sql` (on GitHub)
   - `sessions/2026-03-31_donor_rollup_patches.sql` (on GitHub)
   - `database/migrations/086_completion_fixes.sql` Block B (spine aggregate refresh)

3. **7-pass donor merge queue** — `sessions/2026-04-01_donor_merge_7pass_queue.sql` (NOT ON GITHUB — push from worktree). Queue only, no execution without Ed sign-off.

4. **Military title manual entry** — `staging.title_manual_overrides` table created but empty. Needs manual population for military ranks.

---

## Files Cursor Needs to Push From Worktree

These exist locally but NOT on GitHub `main`:

```bash
cd /Users/Broyhill/.cursor/worktrees/BroyhillGOP-CURSOR/yte
git add sessions/donor_rollup_execute.sql sessions/2026-04-01_donor_merge_7pass_queue.sql
git commit -m "Push rollup execute and merge queue SQL to main"
git push origin main
```

---

## Summary

| Stage | Risk | Writes to spine | Reversible |
|-------|------|:---------------:|:----------:|
| 1 Schema | ZERO | DDL only | Yes (drop columns) |
| 2 Enrichment | LOW | Fills NULLs only | Yes (set back to NULL) |
| 3 Employer | LOW | Fills NULLs only | Yes |
| 4 Quality | LOW | Sets one column | Yes (re-run) |
| 5 Preferred Name | LOW | Fills NULLs only | Yes |
| 6 Titles | LOW | Fills NULLs only | Yes |
| 7 Blocklists + Merges | **ZERO** | Staging tables only | Drop staging tables |
| 8 Candidate Match | MEDIUM | Staging tables | Re-run from scratch |

**Total spine-modifying operations:** Stages 1-6 only. All fill NULL columns. None overwrite existing data. All reversible.

**Stage 7 writes ZERO rows to the spine.** It only populates staging tables for Ed to review.

---

*This is 4 months of work in one deployment. Take it one stage at a time. Verify after each. Stop whenever you want.*
