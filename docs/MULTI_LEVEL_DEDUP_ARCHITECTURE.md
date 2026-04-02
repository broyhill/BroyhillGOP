# MULTI-LEVEL DEDUPLICATION ARCHITECTURE
## BroyhillGOP Platform — Canonical Reference

> **⚠ READ THIS BEFORE WRITING ANY IDENTITY RESOLUTION, DEDUP, OR ROLLUP SQL.**
>
> This is the single source of truth for all agents (Cursor, Claude, Perplexity) working on identity resolution, donor matching, deduplication, or rollup logic. Do not begin any work in these areas without reading this document in full.

---

## TABLE OF CONTENTS

1. [Architecture Overview](#1-architecture-overview)
2. [Canonical Tables — Use These](#2-canonical-tables--use-these)
3. [Deprecated Tables — NEVER USE](#3-deprecated-tables--never-use)
4. [Level 1 — Ingestion Dedup](#4-level-1--ingestion-dedup-pipeline-layer)
5. [Level 2 — Spine Dedup](#5-level-2--spine-dedup-within-coreperson_spine)
6. [Level 3 — Donation Rollup](#6-level-3--donation-rollup-nc-boe--spine-via-contribution_map)
7. [Level 4 — Cross-Source Identity Resolution](#7-level-4--cross-source-identity-resolution)
8. [Matching Hierarchy & Data Principles](#8-matching-hierarchy--data-principles)
9. [Key Functions](#9-key-functions)
10. [Migration Files — Complete Registry](#10-migration-files--complete-registry)
11. [Other Dedup-Related Files](#11-other-dedup-related-files)
12. [Current Execution State](#12-current-execution-state)
13. [P0/P1/P2/P3 TODOs](#13-p0p1p2p3-todos)
14. [Critical Rules & Safety Checks](#14-critical-rules--safety-checks)
15. [Validation Queries](#15-validation-queries)

---

## 1. ARCHITECTURE OVERVIEW

There are **four distinct deduplication levels** in the BroyhillGOP platform. They are NOT interchangeable. Confusing them is the single most common source of bugs.

```
┌─────────────────────────────────────────────────────────────────────┐
│  Level 1 — Ingestion Dedup                                          │
│  "Have I seen this exact raw row before?"                           │
│  Lives in: pipeline/dedup.py, pipeline/identity_resolution.py      │
│  Key: dedup_key (MD5 hash of raw row fields)                        │
│  NOT identity resolution — purely a duplicate row guard             │
└─────────────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────────────┐
│  Level 2 — Spine Dedup                                              │
│  "Are these two spine records actually the same human?"             │
│  Lives in: database/migrations/066, 067, 080                        │
│  Key: person_id in core.person_spine                                │
│  Collapses fragmented spine records to one golden record per donor  │
└─────────────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────────────┐
│  Level 3 — Donation Rollup                                          │
│  "Which spine person_id owns this raw donation row?"                │
│  Lives in: sessions/donor_rollup_execute.sql, 7-pass queue         │
│  Key: golden_record_id in contribution_map                          │
│  Maps raw donations → correct person_id after spine is clean        │
└─────────────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────────────┐
│  Level 4 — Cross-Source Identity Resolution                         │
│  "Is this FEC donor the same person as this NC BOE donor?"          │
│  Lives in: database/migrations/068, 075, 079, 083, 084             │
│  Key: voter_ncid → spine person_id bridge                           │
│  Links FEC + NC BOE + voter file to a single spine record           │
└─────────────────────────────────────────────────────────────────────┘
```

**Rule: Cluster first (Levels 2 & 4), roll up second (Level 3). Never roll up to a fragmented spine.**

---

## 2. CANONICAL TABLES — USE THESE

| Purpose | Schema.Table | Row Count | Primary Key | Notes |
|---------|-------------|-----------|-------------|-------|
| Voter file (DataTrust) | `public.nc_datatrust` | 7.6M | `statevoterid` | statevoterid = nc_voters.ncid |
| NC BOE raw voters | `public.nc_voters` | 9M | `ncid` | |
| Donor identity spine | `core.person_spine` | 128,047 active | `person_id` | 128,047 active after 080 Pass 2 |
| Donations (all sources) | `public.donor_contribution_map` OR `core.contribution_map` | 3.1M+ | `golden_record_id` | These are the same table — use either alias |
| NC BOE raw donations | `public.nc_boe_donations_raw` | ~338K | `id` | 338,223 rows, all `transaction_type = 'Individual'` |
| FEC individual donations | `public.fec_donations` | 1.1M | | |
| FEC party committee donations | `public.fec_party_committee_donations` | 2.1M | | |
| Name variants | `public.name_variants` | 204 | | nickname→canonical |
| Nickname map | `public.name_nickname_map` | 326 | | |
| Common nicknames | `public.common_nicknames` | 132 | | |
| Donor name variants | `public.donor_name_variants` | 13,447 | | |
| Nick group (canonical) | `core.nick_group` | | | ED→EDGAR, ART→ARTHUR |
| Person name aliases | `public.person_name_aliases` | | `(person_id, alias_name)` | Alias type registry |
| Employer aliases | `public.employer_aliases` | | `(canonical_employer, alias_employer)` | 38 rows for ANVIL VENTURE GROUP |
| Merge candidates (queue) | `staging.donor_merge_candidates` | | | 7-pass queue — NOT executed |
| Merge audit log | `public.donor_merge_audit` | | | All merges logged here |

---

## 3. DEPRECATED TABLES — NEVER USE

| Table | Why Deprecated | Replacement |
|-------|---------------|-------------|
| `datatrust_profiles` | Old schema — 20+ refs in datatrust_matching_procedures.sql; must be rewritten | `public.nc_datatrust` |
| `person_master` | Mostly empty shell — 7.66M voter records, zero donor links | `core.person_spine` |
| `donor_golden_records` | Old schema, superseded | `core.person_spine` + `core.contribution_map` |

**If you see any of these three tables in a query you are writing or reviewing: STOP and rewrite to use the canonical equivalents.**

---

## 4. LEVEL 1 — INGESTION DEDUP (PIPELINE LAYER)

**Purpose:** Prevents inserting the same raw row twice during file loads. This is NOT identity resolution.

**Files:**
- `pipeline/dedup.py` (12.5 KB) — Python pipeline dedup_key logic
- `pipeline/identity_resolution.py` (19.3 KB) — Identity resolution pipeline
- `docs/PIPELINE_DEDUP_ARCHITECTURE.md` — Reference doc for this level

**Key:**
- `dedup_key` — deterministic MD5 hash of the raw row's identifying fields
- Two Postgres stored functions implement this:
  - `pipeline.dedup_key_fec_individual(...)` — Parameters: contributor_last_name, contributor_first_name, contributor_zip, committee_id, contribution_receipt_amount, contribution_receipt_date, report_id, line_number
  - `pipeline.dedup_key_ncboe(...)` — Same pattern for NC BOE

**Current state:**
- FEC and NC BOE dedup_key functions: **implemented** in pipeline_ddl.sql
- Identity clustering (donor-level: last_name + zip + dmetaphone first_name → `pipeline.identity_clusters`) is still in Python — acceptable as temporary; will migrate to stored procedure `pipeline.run_dedup_fec_identity()`
- Per Master Plan: Python `dedup.py` is a thin caller of Postgres procedures; logic lives in SQL

**Critical distinction:** Level 1 asks "did I load this row before?" Level 2+ asks "is this the same human as another record?" Never conflate them.

---

## 5. LEVEL 2 — SPINE DEDUP (WITHIN core.person_spine)

**Purpose:** Collapses duplicate spine records that represent the same human into one golden record. After this level runs, every real-world donor has exactly one active `person_id`.

**Files:**
- `database/migrations/066_PHASE1_SPINE_DEDUP.sql` — Builds `staging.spine_merge_candidates` (3 strategies: nickname, voter_ncid, employer+city)
- `database/migrations/067_PHASE1B_EXECUTE_MERGES.sql` — Executes merges (marks merged records `is_active = false`, keeps survivor)
- `database/migrations/080_spine_dedup_five_pass.sql` — Claude's 5-pass dedup (22.9 KB)
- `sessions/2026-04-01_donor_merge_7pass_queue.sql` — Cursor's 7-pass merge queue → `staging.donor_merge_candidates`

**Execution status:**
- Migrations 066 + 067: **Executed**
- Migration 080 Pass 1: **Executed** (background)
- Migration 080 Pass 2: **Executed** — 211 merges applied
- Migration 080 Passes 3–5: **Status unknown / not confirmed executed**
- 7-pass merge queue (sessions file): **Staged only — NOT executed.** Records sit in `staging.donor_merge_candidates` as a queue, not yet applied to `core.person_spine`

**Current baseline:**
- Active spine records: **128,047**
- Validation check: Art Pope → must resolve to 1 active record with ~$990K+ total and ~156 transactions (voter_ncid = EH34831)

**Safety check before any spine merge:**
- Art Pope → 1 record check
- Ed Broyhill + Melanie Broyhill safety check required
- Run Ed Broyhill canary: person_id 26451, NC_BOE sum ≈ $132,763.36

---

## 6. LEVEL 3 — DONATION ROLLUP (NC BOE → SPINE VIA contribution_map)

**Purpose:** Maps raw donation records in `nc_boe_donations_raw` to the correct `person_id` in `core.person_spine` via `contribution_map`. This is the final "who owns this dollar?" assignment.

**Files:**
- `sessions/donor_rollup_execute.sql` — Staging passes only. **NO INSERT statements present.**
- `sessions/2026-03-31_donor_rollup_patches.sql` — Pass 1/3/5 patches
- `sessions/2026-04-01_partisan_flag_fix.sql` → `staging.boe_donation_candidate_map`
- `sessions/2026-03-31_committee_candidate_fuzzy_match.sql` → `staging.committee_candidate_bridge`

**Execution status: NOT EXECUTED. Ed said stop.**

**Authorization gates (ALL required before any INSERT):**

| Action | Required Gate |
|--------|--------------|
| CREATE staging tables | No auth needed |
| SELECT / staging inserts | No auth needed |
| UPDATE core.person_spine | Explicit "I authorize this action" from Ed |
| UPDATE core.contribution_map | Explicit "I authorize this action" from Ed |
| Merge person_ids (mark merged_into) | Explicit "I authorize this action" from Ed |

**Pre-execution thresholds (canary + gate):**
1. `will_insert > 108,943` — confirmed NC_BOE rows in contribution_map must exceed current baseline
2. Broyhill canary: Ed's NC_BOE sum must be verifiable vs baseline of $478,632
3. Spine refresh required after commit

**Current baseline:**
- NC_BOE rows in contribution_map: **108,943**
- Ed Broyhill (person_id 26451) NC_BOE sum: **~$132,763.36**

**7-Pass Rollup Strategy (from `sessions/2026-04-01_donor_merge_7pass_queue.sql`):**

| Pass | Method | Confidence | Notes |
|------|--------|-----------|-------|
| Pass 1 | voter_ncid exact bridge | 100% | Zero false positives — auto-merge |
| Pass 2 | Street number + zip5 + last prefix | 97%+ | Single matches auto-merge; multi → review queue |
| Pass 3 | Employer name + SIC + last prefix | 94%+ | Captures top 30% major donors filing from office |
| Pass 4 | Federal candidate cross-reference | 98%+ | Two independent government filings (FEC + BOE) |
| Pass 5 | Committee loyalty fingerprint | 96%+ | Same 2+ committees across 3+ cycles |
| Pass 6 | Canonical first name / nickname normalization | 90%+ | BOB→ROBERT, BILL→WILLIAM |
| Pass 7 | Reverse-chronological last + zip (standard match) | Variable | Last resort; already produced 108,943 baseline rows |

**Canary verification (run after all passes staged, before any merge):**
```sql
-- Ed Broyhill: all 32 name variants must resolve to 1 statevoterid, 1 rncid
SELECT boe_name, statevoterid, rncid, match_count, match_method
FROM (
  SELECT boe_name, statevoterid, rncid, match_count, 'pass1_street' AS match_method
  FROM staging.staging_pass1_street_match
  WHERE boe_street_num = '525' AND boe_zip IN ('27104','27012')
  UNION ALL
  SELECT donor_name, statevoterid, rncid, 1, 'pass2_ncid'
  FROM staging.staging_pass2_ncid
  WHERE norm_zip5 = '27104' AND norm_last = 'BROYHILL'
) all_matches
ORDER BY match_method, boe_name;
-- If any variant maps to a different statevoterid: STOP and report to Ed
```

**Candidate/committee matching context:**
- Post-rebuild: 99.67% candidate_name fill
- 1,105 donations still missing candidate_name (unresolved)

---

## 7. LEVEL 4 — CROSS-SOURCE IDENTITY RESOLUTION

**Purpose:** Links the same donor across FEC, NC BOE, and the NC voter file to a single `person_id` in `core.person_spine`. Bridges disparate sources into a unified identity.

**Files:**
- `database/migrations/068_PHASE2_VOTER_MATCHING.sql` — 3-pass voter matching (Pass 3 uses first-initial; should use middle_name when available — known gap)
- `database/migrations/075_fec_donor_person_matching.sql` — FEC matching (14.1 KB)
- `database/migrations/079_pass2_identity_resolution.sql` — Pass 2 resolution
- `database/migrations/083_match_fec_to_spine_v3.sql` — FEC to spine v3
- `database/migrations/084_match_party_to_spine.sql` — Party to spine
- `backend/python/matching/fec_voter_matcher.py` — FEC voter matcher (9.3 KB)
- `api/identity_resolver.py` — API identity resolver (14.8 KB)
- `database/schemas/datatrust_matching_procedures.sql` — DataTrust matching (28 KB) — ⚠️ HAS 20+ REFS TO DEPRECATED `datatrust_profiles` — MUST REWRITE

**Execution status:**
- Migrations 068, 075, 079, 083, 084: **Executed**
- Current FEC match rate: 40–50% (weak) — target is 60%+
- `datatrust_matching_procedures.sql`: **needs rewrite** — all `datatrust_profiles` references must be replaced with `public.nc_datatrust`

**Matching hierarchy (Level 4):**

| Priority | Method | Tables Involved |
|----------|--------|----------------|
| 1 (highest) | RNCID exact | nc_datatrust.rncid → person_spine |
| 2 | voter_ncid exact | nc_boe_donations_raw.voter_ncid = nc_datatrust.statevoterid |
| 3 | last + first + zip5 | person_spine ↔ nc_datatrust |
| 4 | canonical_first (nickname) + last + zip5 | core.nick_group resolution |
| 5 | last + first_initial + zip5 + party | Only when middle unavailable |
| 6 | Address anchor (street_number + norm_last + zip5) | High-significance marker |
| 7 | Cross-zip with secondary signal | email / phone / employer confirmation required |

---

## 8. MATCHING HIERARCHY & DATA PRINCIPLES

### Ed's Data Principles (Non-Negotiable)

1. **Classify before aggregating** — cluster identity first, then roll up dollars
2. **RNCID is permanent** — deterministic dedup key from nc_datatrust; never generated, always imported
3. **DataTrust norm_first_tok is a root token** — use it for blocking
4. **Resolve year-by-year from newest** — most recent records are most reliable
5. **Zip codes over 11 years old are stale** — match on name only for old addresses
6. **Household rollups matter** — track family-level political footprint
7. **PAC money goes to HOLD** — do not count PAC contributions in candidate totals
8. **Only Republican candidate money counts in totals** — filter by partisan_lean = 'R'
9. **Donors can be any party registration** — party_registration ≠ contribution eligibility
10. **Address number is the first dedup layer** — the numeric street number is more stable than street name
11. **9-digit zipcode = 100% pairing accuracy** — use zip+4 when available
12. **Abbreviate employer names** — up to 20+ name variations per donor; use employer_aliases table
13. **System clusters name variations and deduces preferred nicknames based on record frequency**
14. **Last name + street number + zipcode for dedup** (Ed's address_block_key rule)
15. **PO Box numbers treated as separate markers** — distinct from street address numbers
16. **Separate numeric street number from street name** — extract via regexp before matching

### Match Variables — Use All Available

| Variable | Source | Use In |
|----------|--------|--------|
| norm_last | donor/spine | All passes |
| norm_first | donor/spine | All passes |
| **norm_middle / middle_name** | donor, nc_voters, person_spine | **Include in match keys** |
| canonical_first | fn_normalize_donor_name | Nickname resolution (ED→EDGAR, ART→ARTHUR) |
| name_suffix | donor, nc_voters | Disambiguation (Jr, Sr, II, III) |
| norm_zip5 | donor | All passes |
| **street_number** | parsed from address | **High-significance marker — same-address block anchor** |
| **po_box_number** | parsed from address | **Separate marker from street number** |
| **address_block_key** | f(street_number, norm_last, zip5) | **Eddie's rule — same-address donor block** |
| voter_ncid | nc_voters | Definitive when present |
| employer_normalized | donor | Passes 3 and 5 |
| email, phone | donor | Secondary signals (cross-zip pass) |

### Name Format Warning (NC BOE)

NC BOE stores names in TWO formats in `donor_name`:
- **Format A:** `"BROYHILL, ED"` (LAST, FIRST) → norm_last = BROYHILL ✅
- **Format B:** `"ED BROYHILL"` (FIRST LAST) → norm_last = ED BROYHILL ❌ (breaks all last-prefix joins)

**Always detect format before extracting last name:**
```sql
CASE
  WHEN donor_name LIKE '%,%' THEN
    -- "LAST, FIRST" format
    upper(trim(split_part(donor_name, ',', 1)))
  ELSE
    -- "FIRST LAST" format — rightmost token
    upper(trim(
      split_part(donor_name, ' ',
        array_length(string_to_array(trim(donor_name), ' '), 1)
      )
    ))
END AS true_last
```

### Scale of Variation (Real Data)

- Name variations: up to **20 per person** (e.g., Ed Broyhill: ED, EDGAR, J EDGAR, JAMES ED, JAMES EDGAR, JAMES EDGAR 'ED', etc.)
- Address variations: up to **15 per person** (casing, abbreviations, typos, zip formats)
- Employer variations: use `employer_aliases` table (38 aliases for ANVIL VENTURE GROUP alone)
- Street number is stable across all address variations — use it as the primary matching anchor

### Top 30% Donor Rule

The top 30% of donors by total giving file multiple times across multiple committees under multiple name variants. **They MUST be rolled up to a single person_id before any clout scoring, ranking, or profiling.** A donor appearing as 7 different name variants across 50 transactions is ONE donor. Until rollup is complete, all scoring is wrong.

```sql
-- Top 30% threshold (run after rollup)
SELECT percentile_cont(0.70) WITHIN GROUP (ORDER BY total_all_giving) AS threshold_30pct
FROM donor_political_footprint;
```

---

## 9. KEY FUNCTIONS

### fn_normalize_donor_name

**Location:** PostgreSQL function deployed to Supabase (public schema)

**Returns:** `canonical_first_name`, `last_name`, `first_name`, `suffix`

**Use for:** All identity resolution — nickname expansion, canonical name standardization

**Do NOT use for identity resolution:** `pipeline.parse_ncboe_name` — it only uppercases; it does NOT parse or normalize. `parse_ncboe_name` returns norm_last, norm_first, middle_name, name_suffix but is pipeline-only.

**Use fn_normalize_donor_name everywhere identity resolution logic runs.**

### Other Infrastructure (Do Not Recreate)

| Component | Location | Purpose |
|-----------|---------|---------|
| `pipeline.dedup_key_fec_individual` | DB (pipeline schema) | MD5 dedup key for FEC rows |
| `pipeline.dedup_key_ncboe` | DB (pipeline schema) | MD5 dedup key for NC BOE rows |
| `core.nick_group` | core schema | Nickname → canonical (ED→EDGAR, ART→ARTHUR) |
| `pipeline.parse_ncboe_name` | pipeline/nc_boe_ddl.sql | Pipeline normalization ONLY — not for identity |

### DB Connection

Use **port 6543** (Supabase pooler), NOT 5432. Port 5432 gets rate-limited after bad password attempts.
```
postgresql://user:pass@db.isbgjpnbocdkeslofota.supabase.co:6543/postgres
```

---

## 10. MIGRATION FILES — COMPLETE REGISTRY

| Migration | File | Size | Purpose | Executed? |
|-----------|------|------|---------|-----------|
| 065 | `065_IDENTITY_RESOLUTION_OVERHAUL_PHASE0.sql` | 2.2 KB | VACUUM + drop unused indexes (~1.8 GB) + create nc_voters indexes | ✅ Yes |
| 066 | `066_PHASE1_SPINE_DEDUP.sql` | 9.1 KB | Build staging.spine_merge_candidates (3 strategies: nickname, voter_ncid, employer+city) | ✅ Yes |
| 067 | `067_PHASE1B_EXECUTE_MERGES.sql` | 4.9 KB | Execute merges — mark merged records is_active=false, keep survivor | ✅ Yes |
| 068 | `068_PHASE2_VOTER_MATCHING.sql` | 8.9 KB | 3-pass voter matching. **Note: Pass 3 uses first-initial; rewrite to use middle_name when available** | ✅ Yes |
| 069 | *(referenced in plan)* | — | Phase 3: FEC donations mapping | Unknown |
| 070 | *(referenced in plan)* | — | Phase 4: Bridge person_master, rebuild aggregates | Unknown |
| 071 | `071_identity_rollup_revised.sql` | 10.6 KB | Identity rollup | Unknown |
| 075 | `075_fec_donor_person_matching.sql` | 14.1 KB | FEC matching to spine | ✅ Yes |
| 076 | `076_golden_record_spine_bridge.sql` | 9.9 KB | Golden record bridge | Unknown |
| 078 | `078_recalculate_spine_aggregates.sql` | 7.2 KB | Spine aggregates recalculation | Unknown |
| 079 | `079_pass2_identity_resolution.sql` | 8.4 KB | Pass 2 identity resolution | ✅ Yes |
| 080 | `080_spine_dedup_five_pass.sql` | 22.9 KB | Claude's 5-pass spine dedup. Pass 1: ✅ Pass 2: ✅ (211 merges). Passes 3–5: status unconfirmed | Partial |
| 083 | `083_match_fec_to_spine_v3.sql` | 8.3 KB | Match FEC donors to spine v3 | ✅ Yes |
| 084 | `084_match_party_to_spine.sql` | 9.7 KB | Match party committee donations to spine | ✅ Yes |
| 086 | `086_completion_fixes.sql` | Unknown | Spine aggregate refresh pattern (Block B) | Unknown |

All migrations live in `database/migrations/`.

---

## 11. OTHER DEDUP-RELATED FILES

| File | Size | Purpose | Status / Notes |
|------|------|---------|----------------|
| `pipeline/dedup.py` | 12.5 KB | Pipeline dedup_key logic | Active — thin caller of Postgres procedures |
| `pipeline/identity_resolution.py` | 19.3 KB | Identity resolution pipeline | Active |
| `api/identity_resolver.py` | 14.8 KB | API identity resolver | Active |
| `backend/python/matching/fec_voter_matcher.py` | 9.3 KB | FEC voter matcher | Active |
| `database/schemas/datatrust_matching_procedures.sql` | 28 KB | DataTrust matching procedures | ⚠️ NEEDS REWRITE — 20+ refs to deprecated `datatrust_profiles` |
| `database/fix_scripts/fix_10_party_filter_spine.sql` | 13.2 KB | Party filter fix for spine | Applied |
| `pipeline/nc_boe_dedup_fixes.sql` | 3.9 KB | NC BOE dedup fixes (ED/EDGAR→EDWARD backfill) | Applied |
| `sessions/2026-04-01_donor_merge_7pass_queue.sql` | — | 7-pass merge queue → staging.donor_merge_candidates | **Staged only — NOT executed** |
| `sessions/donor_rollup_execute.sql` | — | Staging passes — NO INSERT | **Not executed** |
| `sessions/2026-03-31_donor_rollup_patches.sql` | — | Pass 1/3/5 patches | **Not executed** |
| `sessions/2026-04-01_partisan_flag_fix.sql` | — | → staging.boe_donation_candidate_map | **Staged** |
| `sessions/2026-03-31_committee_candidate_fuzzy_match.sql` | — | → staging.committee_candidate_bridge | **Staged** |

---

## 12. CURRENT EXECUTION STATE

### What Is Done

- **Spine dedup (Level 2):** Migrations 066 + 067 executed. Migration 080 Pass 1 and Pass 2 executed (211 merges from Pass 2).
- **Voter matching (Level 4):** Migration 068 executed (3-pass voter matching).
- **FEC matching (Level 4):** Migrations 075, 079, 083, 084 executed.
- **NC BOE baseline in contribution_map:** 108,943 rows linked.
- **Candidate name fill:** 99.67% fill rate post-rebuild; 1,105 donations still missing candidate_name.

### What Is Staged (Not Executed)

- **7-pass rollup queue:** `staging.donor_merge_candidates` contains the full 7-pass merge queue from Cursor's `sessions/2026-04-01_donor_merge_7pass_queue.sql`. **This is a queue only. No merges have been applied to core.person_spine.**
- **Rollup SQL (Level 3):** `sessions/donor_rollup_execute.sql` — staging passes only, INSERT SQL body not present in repo.
- **Committee candidate bridge:** `staging.boe_donation_candidate_map` and `staging.committee_candidate_bridge` are staged.

### What Is Blocked

- **Level 3 rollup INSERT:** Blocked by explicit instruction from Ed ("stop"). No INSERT into contribution_map may proceed without:
  1. Confirmed `will_insert > 108,943`
  2. Broyhill canary verified vs $478,632 baseline
  3. Spine refresh confirmed post-commit
  4. Explicit "I authorize this action" from Ed
- **datatrust_matching_procedures.sql rewrite:** 20+ references to deprecated `datatrust_profiles` must be replaced with `public.nc_datatrust` before this file is usable.
- **Migration 080 Passes 3–5:** Execution status unconfirmed — verify before building on top of these.

### Current Spine State

```
Active spine records:  128,047
NC_BOE in contribution_map:  108,943 rows
Ed Broyhill (person_id 26451) NC_BOE sum:  ~$132,763.36
FEC match rate:  40–50% (target: 60%+)
Candidate_name fill:  99.67% (1,105 missing)
```

---

## 13. P0/P1/P2/P3 TODOs

### P0 — Must Fix Before Any Rollup Proceeds

1. **Verify 080 Pass 3–5 execution status.** Run confirmation queries; do not assume they ran.
2. **Rewrite `datatrust_matching_procedures.sql`** — replace all 20+ `datatrust_profiles` references with `public.nc_datatrust`. This file is a dependency for any DataTrust-based matching and is currently broken.
3. **Ed authorization gate for Level 3 INSERT** — The INSERT body does not exist in repo. Do not write it until Ed gives explicit go-ahead.

### P1 — High Priority After P0

1. **Execute 7-pass rollup** (after Ed authorization):
   - Run all staging passes → report counts + canary to Ed
   - Wait for authorization
   - Execute merges in one transaction
   - Refresh spine aggregates
2. **Raise FEC match rate from ~45% to 60%+**:
   - Add street address matching to FEC → nc_voters bridge (currently name + zip only)
   - Migration: add `voter_ncid` column to FEC table if missing; populate via Tier 1/2/3 matching
3. **Fix migration 068 Pass 3** — rewrite to use `middle_name` instead of first-initial-only when nc_voters data is available.
4. **Confirm Art Pope validation** — after any spine operation, verify Art Pope → 1 record, ~$990K+, voter_ncid = EH34831.

### P2 — Important, Not Blocking

1. **Migrate identity clustering out of Python** — move `pipeline.identity_clusters` logic from `dedup.py` into stored procedure `pipeline.run_dedup_fec_identity()`.
2. **Build `donor_political_footprint` view** — post-rollup aggregation across all sources with PAC filtering and R-only candidate totals.
3. **Resolve 1,105 missing candidate_name donations** — remaining gap in committee candidate map.
4. **Household rollup tracking** — family-level political footprint aggregation after individual rollup is complete.

### P3 — Future / Matching Logic Expansion

1. **Activate unused donor fields in matching logic** — Demographics, voter data, and engagement are 100% unused in candidate-donor matching. High-value gaps:
   - Occupation/office affinity (attorney → judicial races)
   - Veteran/military branch match
   - Religion/community match
   - Alumni match
   - Historical office type affinity
2. **Event-driven re-scoring** — when donor record is created/updated, trigger recalculation of match scores for all active candidates.
3. **ML opportunity** — 200+ donor fields + 200+ candidate fields; train on historical donation outcomes to discover hidden patterns.

---

## 14. CRITICAL RULES & SAFETY CHECKS

### Non-Negotiable Rules

1. **Never delete donations or spine records.** Mark `is_active = false`. Deletion is forbidden.
2. **Use `fn_normalize_donor_name` for identity resolution.** Do NOT use `pipeline.parse_ncboe_name` for identity work.
3. **Cluster first, roll up second.** Spine must be clean before contribution_map rollup.
4. **General-type = individual persons.** Already fixed in norm_etl_ncboe; verify before writing new filters.
5. **Ingestion dedup ≠ identity dedup.** Level 1 is a row-level hash guard. Never use it for identity matching.
6. **No writes without Ed's explicit authorization.** Staging is always permitted. INSERTs/UPDATEs to core tables require "I authorize this action."
7. **Do not merge on name alone.** Always require a second anchor: street number, employer, voter_ncid, or committee fingerprint.
8. **Do not auto-merge multi-match candidates.** Single-match results → auto-merge. Multi-match → review queue.
9. **All merges logged to `public.donor_merge_audit`** with kept_person_id, merged_person_id, match_method, match_confidence, and merged_at.
10. **9-digit zip = 100% pairing accuracy.** Use zip+4 whenever available.
11. **Street number > street name.** Use the numeric portion of street_line_1 as primary address anchor. Parse it before matching.

### Safety Checks (Run Before Any Spine Operation)

```sql
-- Art Pope golden record
SELECT person_id, norm_last, norm_first, voter_ncid, contribution_count, total_contributed
FROM core.person_spine
WHERE norm_last = 'POPE' AND voter_ncid = 'EH34831' AND is_active = true;
-- Expected: exactly 1 row, total_contributed ~$990K+

-- Ed Broyhill canary
SELECT person_id, norm_first, norm_last, zip5, voter_ncid, total_contributed, contribution_count
FROM core.person_spine
WHERE norm_last = 'BROYHILL' AND zip5 IN ('27104','27012') AND is_active = true
ORDER BY total_contributed DESC NULLS LAST;
-- Expected: person_id 26451 is highest; NC_BOE sum ~$132,763.36

-- No orphaned donations
SELECT source_system, count(*)
FROM donor_contribution_map
WHERE golden_record_id NOT IN (
  SELECT person_id FROM core.person_spine WHERE is_active = true
)
GROUP BY source_system;
-- Expected: 0 rows

-- Spine linkage rate (target >80%)
SELECT count(*) AS total, count(voter_ncid) AS linked,
       round(100.0 * count(voter_ncid) / count(*), 1) AS pct
FROM core.person_spine WHERE is_active = true;
```

### Rollup Guardrails

- Do NOT score or rank donors before rollup is complete
- Do NOT present `total_contributed` from `person_spine` as the donor's true footprint until all 7 passes have run — it may reflect only 1 of 7 name variants
- Do NOT merge when multiple spine records could match — multi-match goes to review queue only

---

## 15. VALIDATION QUERIES

### Confirm NC BOE Baseline

```sql
SELECT count(*), count(*) FILTER (WHERE transaction_type = 'Individual')
FROM public.nc_boe_donations_raw;
-- Expected: 338,223 total, 338,223 Individual
```

### Confirm Spine Baseline

```sql
SELECT count(*) AS active_spine, round(sum(total_contributed)) AS total_dollars
FROM core.person_spine WHERE is_active = true;
-- Expected: ~128,047 active
```

### Confirm contribution_map NC_BOE Baseline

```sql
SELECT source_system, count(*) AS rows
FROM core.contribution_map
WHERE source_system = 'NC_BOE'
GROUP BY source_system;
-- Expected: 108,943
```

### Check 7-Pass Queue

```sql
SELECT match_method, count(*) AS queued_merges
FROM staging.donor_merge_candidates
GROUP BY match_method
ORDER BY count(*) DESC;
-- These are staged but NOT executed
```

### FEC Match Rate

```sql
SELECT
  count(*) AS total_nc_fec,
  count(voter_ncid) AS matched,
  round(100.0 * count(voter_ncid) / count(*), 1) AS match_pct
FROM public.fec_donations
WHERE contributor_state = 'NC';
-- Target: 60%+. Current: ~40-50%
```

---

*Document version: 2026-04-02*
*Compiled from: dedup-ref/ source materials + session history + Ed Broyhill's data principles*
*Canonical location: docs/MULTI_LEVEL_DEDUP_ARCHITECTURE.md*
*All agents must read this document before touching identity resolution, donor matching, or rollup work.*
