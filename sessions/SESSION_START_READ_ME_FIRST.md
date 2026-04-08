# SESSION START — READ THIS ENTIRE FILE BEFORE DOING ANYTHING
**BroyhillGOP-Claude | Last updated: April 7, 2026 10:20 PM EDT**
**Authority: Ed Broyhill | NC National Committeeman**

---

## READ THESE FILES BEFORE ANYTHING ELSE (in order)
1. `sessions/MASTER_FILE_MANIFEST.md` — exact file inventory, NCBOE = 18 GOLD files, what not to touch
2. `sessions/PERPLEXITY_HIGHLIGHTS.md` — key architectural rules and agent guardrails
3. `sessions/WAVE1_CONSOLIDATED_PLAN_STATUS.md` — current phase plan (**note: has stray `**` markdown typos — interpret carefully**)
4. `sessions/SESSION_APRIL7_2026_EVENING.md` — tonight's session: GOLD load in progress, DataTrust news, what went wrong this morning
5. `sessions/SESSION_APRIL6_2026_EVENING.md` — prior session baseline

## LATEST SESSION
`sessions/SESSION_APRIL7_2026_EVENING.md` — April 7, 2026 evening. NCBOE GOLD load in progress (4/18 files), Zack Imel agreed to full 2,200-variable DataTrust dump, norm.nc_boe_donations is STALE until renormalized.

---

## ⚠️ MANDATORY — ALL AGENTS (PERPLEXITY, CURSOR, ANY AI)

Before you write a single line of SQL, make a single recommendation, or touch anything:

1. Read this file completely
2. State which files you read in your first reply
3. If you cannot see the repo — say so explicitly and ask for a paste
4. **DO NOT guess process, pipeline, or architecture from memory or code inspection alone**

We have burned 6+ hours in single sessions because an agent skipped this step and improvised. Do not repeat that.

---

## THE DATABASE — BroyhillGOP-Claude

**Supabase Project:** isbgjpnbocdkeslofota | Region: us-east-1
**Pooler (always use):** `db.isbgjpnbocdkeslofota.supabase.co` port **6543** `sslmode=require`
**Always run first:** `SET statement_timeout = 0;`

---

## THE PEARL — core.person_spine

`core.person_spine` is THE master unified identity table. Every person in this database — donor, voter, volunteer — has one and only one active row here. It is called THE PEARL.

**Current state (April 6, 2026):**
- **74,407 active persons** | $320.5M total contributed | $258.5M Republican
- 125,976 inactive (deactivated/merged)
- Zero duplicate NCIDs among active records
- Zero D-flag rows in contribution_map

**Rules for THE PEARL:**
- Claude/Perplexity MAY: SELECT anywhere, CREATE TEMP TABLEs, CREATE in staging schema, INSERT into staging
- Claude/Perplexity MAY NOT: DROP/ALTER any table in core/public/archive/norm/raw/staging/audit; UPDATE/DELETE from core.person_spine directly without explicit authorization
- TWO PHASE PROTOCOL: DRY RUN first, then EXECUTION only after Ed says **"I authorize this action"**

---

## SACRED TABLES — DO NOT TOUCH. EVER.

| Table | Rows | Why Sacred |
|-------|------|------------|
| `public.nc_boe_donations_raw` | GROWING | GOLD LOAD IN PROGRESS — 18 files from Desktop. Do not touch. |
| `norm.nc_boe_donations` | 581,741 | ⚠️ STALE — built from old 2-file load. Not consistent with new GOLD raw. Do not use for reporting until renormalized. |
| `core.ncboe_donations_processed` | — | NC BOE processed layer |
| `norm.nc_boe_donations` | 581,741 | ⚠️ STALE — built from old 2-file load, not yet renormalized against GOLD files |
| `staging.boe_donation_candidate_map` | 338,213 | Candidate-matched staging |
| `public.nc_datatrust` | 7,661,978 | RNC DataTrust file — primary identity anchor |
| `public.nc_voters` | ~7.7M | NC State voter file |
| `public.rnc_voter_staging` | 7,708,268 | RNC voter staging |
| `public.person_source_links` | — | Spine bridge table |

**If you are about to touch any of these — STOP. Re-read this file. Then ask Ed.**

---

## BANNED FILES — NEVER LOAD INTO fec_donations

These 23 files are unfiltered FEC bulk downloads containing Biden, Harris, Hillary, Bernie, Beasley, Cooper, and hundreds of Democratic candidates. They were deleted April 6, 2026. **They are gone. Do not bring them back.**

Any `source_file` in `fec_donations` containing `2026-03-11` = contamination. Delete immediately and alert Ed.

---

## CURRENT DATABASE STATE (April 6, 2026)

| Table | Rows | Status |
|-------|------|--------|
| `core.person_spine` active | 74,407 | ✅ Clean |
| `core.person_spine` inactive | 125,976 | ✅ |
| `core.contribution_map` | 2,960,201 | ✅ Zero D-flag rows |
| `public.fec_donations` | 779,182 | ✅ 14 clean files only |
| `public.nc_boe_donations_raw` | ~221,437+ (growing) | 🔄 GOLD LOAD IN PROGRESS — 4/18 files as of 10:19 PM Apr 7 |
| `norm.nc_boe_donations` | 581,741 | ⚠️ STALE — do not trust until renormalized post-GOLD load |
| `norm.fec_individual` | 2,597,125 | ✅ 99.9997% linked |
| `public.nc_datatrust` | 7,661,978 | ✅ SACRED |
| `archive.democratic_candidate_donor_records` | 906,609 | ✅ D donations archived |

### contribution_map party_flag (April 6, post-cleanup)
| party_flag | Rows | Amount |
|------------|------|--------|
| R | 2,842,933 | $432.0M |
| OTHER | 116,157 | $20.2M |
| PAC | 1,111 | $889k |
| D | **0** | **$0** ✅ |

---

## KEY POLICY DECISIONS (Ed's Rules — Non-Negotiable)

1. **NC donors only** — no out-of-state donors
2. **Individual donors only** — no corporations, PACs, associations, LLCs
3. **Republican candidates only** — no Democratic, Independent, Green candidates
4. **Democrat crossover donors ARE kept** — DEM/UNA registered voters who donate to Republicans belong in the spine
5. **D-only donors are removed** — persons whose ONLY donations went to Democratic committees are deactivated
6. **"Ed" is NOT mapped to "Edward"** — ever, in any system
7. **No committee-to-committee donations** — individual donors to candidate FEC ID committees only
8. **We do not drop schema columns** until we know why they exist and what dataset they match

---

## THE ROLLUP PIPELINE — THE MOST IMPORTANT PROCESS

**This is the identity resolution process that links donors across name variants to a single person_id.**

### The Problem
Top 30% of donors give multiple times across multiple committees under multiple name variants. Ed Broyhill himself appears as 8 different names at 525 N Hawthorne Rd 27104. Without rollup, he shows as 8 small donors instead of 1 major donor. All scoring, ranking, and profiling is wrong until rollup is complete.

### The Canary — Ed Broyhill
**Before ANY merge executes, run this check:**
```sql
SELECT person_id, norm_first, norm_last, zip5, voter_ncid,
       total_contributed, contribution_count, is_active
FROM core.person_spine
WHERE norm_last = 'BROYHILL'
  AND zip5 IN ('27104','27012')
  AND is_active = true
ORDER BY total_contributed DESC;
```
All 8 name variants (ED, EDGAR, JAMES, J EDGAR, JAMES EDGAR, etc.) at 525 N Hawthorne must resolve to ONE person_id. If any variant maps to a different person — STOP and report to Ed before proceeding.

### The 7-Pass Rollup (DataTrust is the primary anchor — NOT just name+zip)

| Pass | Anchor | DataTrust Role | Confidence |
|------|--------|---------------|------------|
| **Pass 1** | `voter_ncid` exact bridge | `nc_datatrust.statevoterid` = `nc_boe_donations_raw.voter_ncid` | 100% — auto-merge |
| **Pass 2** | Street number + zip5 + last prefix | `nc_datatrust.registrationaddr1` street number | 97% — single match auto-merge |
| **Pass 3** | Employer + SIC + last prefix | `nc_datatrust.employer` via SIC classification | 94% — single match auto-merge |
| **Pass 4** | Federal candidate cross-reference | FEC filing + NCBOE filing = two govt sources | 98% |
| **Pass 5** | Committee loyalty fingerprint | Same 3+ committees across cycles | 96% |
| **Pass 6** | Canonical first name + last + zip | Nickname normalization (BOB→ROBERT etc.) | 90% |
| **Pass 7** | Last + first + zip | Standard match | 85% |

### Critical Rules for Rollup
- **NEVER merge on name alone** — always require a second anchor
- **Multi-matches go to review queue** — never auto-merge ambiguous cases
- **Birth year guard** — all passes except Pass 1 require `ABS(birth_year_a - birth_year_b) <= 5` when both are known
- **Pass 3 (First=Middle) is DISABLED** — produces near-zero true positives, high household false positives
- All merges logged to `public.donor_merge_audit` with method, confidence, and timestamp
- Staging table: `staging.donor_merge_candidates` — review before any execute

### Rollup Script Location
`pipeline/identity_resolution.py` — phases A through G2
`sessions/2026-03-31_DONOR_ROLLUP_IDENTITY_SPEC.md` — the authoritative spec
`sessions/2026-03-31_DONOR_ROLLUP_CURSOR_BRIEF.md` — Cursor execution brief

### Current Rollup State
- `public.person_name_aliases`: 32 rows (Ed Broyhill aliases seeded)
- `staging.donor_merge_candidates`: 0 rows (empty — rollup not yet run on clean data)
- `public.donor_merge_audit`: 0 rows
- `norm.fec_individual`: 2,597,125 rows, 2,597,118 linked to person_id

---

## FEC DATA — WHAT'S IN THE DATABASE

**779,182 rows in `public.fec_donations` — 14 approved source files only:**

| File | Rows | Category |
|------|------|----------|
| 2022-2026-Trump-nc-individ-only.csv | 377,778 | TRUMP |
| 2019-2020-Trump-NC-GOP-FEC.csv | 273,616 | TRUMP |
| 2015-2018-TRUMP-INDIDUALS.csv | 42,785 | TRUMP |
| tillis-burr-budd-2015-2026.csv | 30,845 | SENATE |
| 2015-2026-us-house-fec-batch-one.csv | 20,450 | HOUSE |
| 2015-2026-us-house-batch2.csv | 12,186 | HOUSE |
| WHATLEY-MCCRORY-2015-2026-US-SENATE.csv | 7,602 | SENATE |
| 2015-2026-us-house-batch-3.csv | 5,412 | HOUSE |
| group-1-pres-2015-2026.csv | 3,960 | PRESIDENTIAL |
| batch-4-us-house.csv | 2,442 | HOUSE |
| group-2-2015-2026-president.csv | 1,594 | PRESIDENTIAL |
| batch--5-house.csv | 408 | HOUSE |
| villaverde.csv | 104 | HOUSE |
| **TOTAL** | **779,182** | |

**779,182 is the locked and correct total.** The gap from 780,961 (inventory) is explained by 114 filtered rows (organizations, PACs) and 665 sub_id overlaps. This is complete.

---

## NCBOE DATA — WHAT'S IN THE DATABASE

`public.nc_boe_donations_raw`: **338,223 rows** from two source files:
- `2020-2026-ncboe.csv` — 242,256 rows
- `2015-2019-ncboe.csv` — 95,967 rows

This table is **installed, normalized, synced to voter file and DataTrust**. Do not touch it.

`norm.nc_boe_donations`: **581,741 rows** — all 100% linked to person_id. This is the normalized layer built from the raw table over 3 days of work.

---

## PENDING WORK (Next Sessions)

### Critical — Must Complete Before Scoring/Ranking
1. **7-Pass Donor Rollup** — Run all 7 passes per `DONOR_ROLLUP_IDENTITY_SPEC.md`. Ed Broyhill canary must pass before any merge executes. This is the most important remaining task.
2. **donor_political_footprint** — Build the rolled-up view after Pass 7 completes
3. **Top 30% threshold** — Define after footprint is built

### Database Fixes Remaining
4. **5 aggregate edge cases** — persons where total_R > total_contributed (minor, pre-existing)
5. **2.2M candidate_id gap** — CCM bridge table is 61% empty (separate project)
6. **15 RNCID collision groups** — DataTrust quality issue, need human review
7. **merged_into column** — 0% filled, inactive records need forward pointers

### Infrastructure
8. **Twilio 10DLC campaign** — needs privacy policy + T&C pages at broyhillgop.com before resubmission
9. **DataTrust token expires April 10, 2026** — renew with Danny Gustafson dgustafson@gop.com
10. **FEC API key** — rotate at api.data.gov (old key compromised, posted in chat)
11. **DB password** — rotate at Supabase dashboard (compromised)

---

## DATATRUST COLUMN NAMES (exact — use these, not guesses)

| Field | Column |
|-------|--------|
| Party score | `republicanpartyscore`, `turnoutgeneralscore`, `democraticpartyscore` |
| Sex | `sex` |
| Address | `registrationaddr1`, `regcity`, `regzip5` |
| Birthday | `birthday` (day), `birthmonth`, `birthyear` |
| Phone | `cell`, `cellneustar` |
| Household | `householdid`, `householdparty`, `householdincomemodeled` |
| RNCID | `rncid` |
| StateVoterID | `statevoterid` |
| Employer | `employer` |
| Coalition flags | `coalitionid_sportsmen`, `coalitionid_veteran`, `coalitionid_2ndamendment`, `coalitionid_prolife`, `coalitionid_socialconservative`, `coalitionid_fiscalconservative` |

---

## NC_BOE_DONATIONS_RAW COLUMN NAMES (exact)

| Field | Column |
|-------|--------|
| Donor | `donor_name`, `street_line_1`, `city`, `state`, `zip_code` |
| Profession | `profession_job_title`, `employer_name` |
| Amount | `amount_numeric`, `date_occurred` |
| Committee | `committee_sboe_id`, `committee_name`, `candidate_referendum_name` |
| Normalized | `norm_last`, `norm_first`, `norm_zip5`, `norm_addr` |
| Voter link | `voter_ncid`, `rncid` |

---

## INFRASTRUCTURE

| Resource | Value |
|----------|-------|
| GitHub repo | broyhill/BroyhillGOP |
| Hetzner Server | 5.9.99.109 (relay port 8080) |
| Relay API key | bgop-relay-k9x2mP8vQnJwT4rL |
| DataTrust contact | **Zack Imel** — RNC Digital Director (Danny Gustafson no longer there) |
| DataTrust full dump | Zack Imel agreed to provide full 2,200-variable DataTrust file — schema must be ready (jsonb/split tables, NOT 2,200 scalar columns) |
| DataTrust token expires | April 10, 2026 — renew with Zack Imel |

---

*Updated by Perplexity-Claude | April 7, 2026 10:20 PM EDT*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
