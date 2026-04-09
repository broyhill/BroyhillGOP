# SESSION START — READ THIS ENTIRE FILE BEFORE DOING ANYTHING
**BroyhillGOP | Last updated: April 9, 2026 12:15 AM EDT**
**Authority: Ed Broyhill | NC National Committeeman**

---

## ⛔ CRITICAL APRIL 9, 2026 — FULL DATABASE RESET IN EFFECT

**DECISION MADE TONIGHT:** All FEC and NCBOE donor files in Supabase are contaminated and worthless. The Supabase database was restored to the April 9, 2026 7:00 AM snapshot. **Do not reference any FEC or NCBOE data loaded before this reset.**

### What Was Discovered (April 9, 2026)
1. **All previous FEC files** contained Democratic candidates, Independent candidates, and out-of-state donations. They were built on throttled FEC bulk downloads that mixed party data indiscriminately.
2. **All previous NCBOE files** contained Democratic and Independent candidate donations — the BOE download portal throttles results when downloaded in bulk, meaning the prior 2-file approach gave a partial, politically mixed dataset.
3. **The fix for throttling:** Break downloads into counties, cities, and smaller candidate selections — this tripled output volume and allows clean Republican-only filtering at the source before upload.
4. **Fresh files are on Ed's laptop**, organized and secured. These are the ONLY authorized source files going forward.

### What Was Preserved (Sacred — Do Not Touch)
- `public.nc_datatrust` — 7,661,978 rows ✅ SACRED
- `public.nc_voters` / `staging.nc_voters_fresh` — ~7.7M rows ✅ SACRED
- `public.rnc_voter_staging` — 7,708,268 rows ✅ SACRED

### What Was Reset (Replaced / Rebuilt from fresh files)
- All `public.nc_boe_donations_raw` rows from old NCBOE files — **GONE, being replaced**
- All `public.fec_donations` rows from old FEC files — **GONE, being replaced**
- `norm.nc_boe_donations` — **STALE, rebuild after fresh NCBOE load**
- `norm.fec_individual` — **STALE, rebuild after fresh FEC load**
- `core.contribution_map` — **Rebuild after both source loads complete**
- `core.person_spine` donor enrichment — **Rebuild after contribution_map is clean**

---

## READ THESE FILES BEFORE ANYTHING ELSE (in order)
1. `sessions/SESSION_START_READ_ME_FIRST.md` — THIS FILE — read completely first
2. `sessions/MASTER_FILE_MANIFEST.md` — exact file inventory and what not to touch
3. `sessions/PERPLEXITY_HIGHLIGHTS.md` — key architectural rules and agent guardrails
4. `sessions/SESSION_APRIL9_2026.md` — tonight's session: contamination discovery, reset decision, new file strategy
5. `sessions/SESSION_APRIL7_2026_EVENING.md` — prior session baseline (pre-reset context)

---

## ⚠️ MANDATORY — ALL AGENTS (PERPLEXITY, CURSOR, CLAUDE, ANY AI)

Before you write a single line of SQL, make a single recommendation, or touch anything:

1. Read this file completely
2. State which files you read in your first reply
3. If you cannot see the repo — say so explicitly and ask for a paste
4. **DO NOT guess process, pipeline, or architecture from memory or code inspection alone**
5. **DO NOT load any FEC or NCBOE file without explicit authorization from Ed stating the filename and source**

We have burned 6+ hours in single sessions because an agent skipped this step and improvised. Do not repeat that.

---

## THE DATABASE — BroyhillGOP-Claude

**Supabase Project:** isbgjpnbocdkeslofota | Region: us-east-1
**Pooler (always use):** `db.isbgjpnbocdkeslofota.supabase.co` port **6543** `sslmode=require`
**Always run first:** `SET statement_timeout = 0;`

---

## THE PEARL — core.person_spine

`core.person_spine` is THE master unified identity table. Every person in this database — donor, voter, volunteer — has one and only one active row here. It is called THE PEARL.

**Current state (April 9, 2026 — post-reset):**
- Active persons: TBD after fresh donor load completes
- Donor enrichment columns are stale until fresh FEC + NCBOE files are loaded and rollup is run
- `public.nc_datatrust` and `public.nc_voters` remain intact as identity anchors

**Rules for THE PEARL:**
- Claude/Perplexity MAY: SELECT anywhere, CREATE TEMP TABLEs, CREATE in staging schema, INSERT into staging
- Claude/Perplexity MAY NOT: DROP/ALTER any table in core/public/archive/norm/raw/staging/audit; UPDATE/DELETE from core.person_spine directly without explicit authorization
- TWO PHASE PROTOCOL: DRY RUN first, then EXECUTION only after Ed says **"I authorize this action"**

---

## SACRED TABLES — DO NOT TOUCH. EVER.

| Table | Rows | Why Sacred |
|-------|------|------------|
| `public.nc_datatrust` | 7,661,978 | RNC DataTrust file — primary identity anchor |
| `public.nc_voters` | ~7.7M | NC State voter file |
| `public.rnc_voter_staging` | 7,708,268 | RNC voter staging |
| `public.person_source_links` | — | Spine bridge table |

**If you are about to touch any of these — STOP. Re-read this file. Then ask Ed.**

---

## KEY POLICY DECISIONS (Ed's Rules — Non-Negotiable)

1. **Republican candidates ONLY** — no Democratic, Independent, Green, or Libertarian candidates in any donor table. Ever. This caused the contamination that required the April 9 reset.
2. **Democrat and Independent crossover donors ARE kept** — DEM/UNA registered voters who donate to Republican candidates belong in the spine. The donor's party registration is irrelevant; the candidate's party is what matters.
3. **NC donors only** — no out-of-state donors in NCBOE files
4. **Individual donors only** — no corporations, PACs, associations, LLCs
5. **D-only donors are removed** — persons whose ONLY donations went to Democratic committees are deactivated
6. **"Ed" is NOT mapped to "Edward"** — ever, in any system
7. **No committee-to-committee donations** — individual donors to candidate FEC ID committees only
8. **We do not drop schema columns** until we know why they exist and what dataset they match

---

## NEW FILE SOURCING RULES (April 9 — Required Going Forward)

**WHY THE OLD FILES FAILED:** FEC and NCBOE both throttle bulk downloads. Downloading by full state or broad date ranges returns mixed-party, incomplete data. The fix:

### FEC Downloads
- Break searches by: county → city → individual candidate
- Filter at source: Republican candidates only, NC donors only, individual contributors only
- Verify each file before upload: `SELECT DISTINCT candidate_party FROM [file_sample]` must return only `REP` or equivalent

### NCBOE Downloads
- Break searches by: county → city → smaller candidate selection
- Filter at source: Republican and non-partisan candidates only
- Verify each file before upload: `SELECT candidate_party_cd, COUNT(*) FROM [file_sample] GROUP BY candidate_party_cd`
- Any row with `DEM`, `LIB`, `UNA`, `GRN` as the CANDIDATE party → entire file goes back. Do not load.

### Authorization Gate
**No file loads into Supabase without Ed explicitly stating:**
> "Load [exact filename] from [source: FEC/NCBOE] — I authorize this action"

---

## THE CANARY — Ed Broyhill (Run Before Every Merge)

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

---

## THE ROLLUP PIPELINE

**This is the identity resolution process that links donors across name variants to a single person_id.**

### The 7-Pass Rollup (DataTrust is the primary anchor)

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

### Rollup Script Location
`pipeline/identity_resolution.py` — phases A through G2
`sessions/2026-03-31_DONOR_ROLLUP_IDENTITY_SPEC.md` — the authoritative spec

---

## CURRENT DATABASE STATE (April 9, 2026 — post-reset)

| Table | Rows | Status |
|-------|------|--------|
| `public.nc_datatrust` | 7,661,978 | ✅ SACRED — untouched |
| `public.nc_voters` | ~7.7M | ✅ SACRED — untouched |
| `public.rnc_voter_staging` | 7,708,268 | ✅ SACRED — untouched |
| `public.fec_donations` | TBD | 🔄 Awaiting fresh files from Ed's laptop |
| `public.nc_boe_donations_raw` | TBD | 🔄 Awaiting fresh files from Ed's laptop |
| `norm.nc_boe_donations` | — | ⚠️ Rebuild after fresh NCBOE load |
| `norm.fec_individual` | — | ⚠️ Rebuild after fresh FEC load |
| `core.contribution_map` | — | ⚠️ Rebuild after both source loads |
| `core.person_spine` active | TBD | 🔄 Donor enrichment pending |
| `archive.democratic_candidate_donor_records` | 906,609 | ✅ D donations archived |

---

## PENDING WORK (Post-Reset Priority Order)

### Phase 1 — Fresh File Load (Before anything else)
1. Ed transfers fresh county-broken NCBOE files from laptop
2. Verify each file: Republican candidates only, NC donors only
3. Load NCBOE files one at a time with Ed's explicit authorization per file
4. Ed transfers fresh FEC files from laptop
5. Verify each FEC file: Republican candidates only, NC individual donors only
6. Load FEC files one at a time with Ed's explicit authorization per file

### Phase 2 — Normalization (After all files loaded)
7. Rebuild `norm.nc_boe_donations` from fresh raw
8. Rebuild `norm.fec_individual` from fresh FEC
9. Rebuild `core.contribution_map`

### Phase 3 — Identity Resolution
10. Run 7-Pass Donor Rollup per `DONOR_ROLLUP_IDENTITY_SPEC.md`
11. Ed Broyhill canary must pass before any merge executes
12. Build `donor_political_footprint` after rollup completes

### Infrastructure (Ongoing)
- **DataTrust token expires April 10, 2026** — renew with Zack Imel (RNC Digital Director)
- **DataTrust full 2,200-variable dump** — Zack Imel agreed; schema must be jsonb-ready before delivery
- **Twilio 10DLC campaign** — needs privacy policy + T&C pages before resubmission
- **FEC API key** — rotate at api.data.gov (old key compromised)
- **DB password** — rotate at Supabase dashboard (compromised)

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
| DataTrust contact | **Zack Imel** — RNC Digital Director |
| DataTrust full dump | Zack Imel agreed to provide full 2,200-variable DataTrust file — schema must be ready (jsonb/split tables, NOT 2,200 scalar columns) |
| DataTrust token expires | April 10, 2026 — mention to Zack Imel when coordinating the 2,200-variable dump delivery |

---

*Updated by Perplexity | April 9, 2026 12:15 AM EDT*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
