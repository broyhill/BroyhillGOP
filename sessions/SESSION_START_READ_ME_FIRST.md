# SESSION START — READ THIS ENTIRE FILE BEFORE DOING ANYTHING
**BroyhillGOP | Last updated: April 9, 2026 6:10 PM EDT**
**Authority: Ed Broyhill | NC National Committeeman**

---

## 🚨 INCIDENT #13 — April 9, 2026 Evening — nc_boe_donations_raw CONTAMINATED AGAIN

**For the 13th time, an agent loaded rows into nc_boe_donations_raw without executing the mandatory TRUNCATE-first protocol.**

The 18 GOLD files were appended on top of existing rows. `nc_boe_donations_raw` now contains **~2,269,053 rows** — a toxic hybrid of enriched sacred rows + raw unenriched new rows.

| Row Set | Count | Enrichment Status |
|---------|-------|------------------|
| Original sacred rows | 338,223 | ✅ voter_ncid, RNCID, DataTrust enriched |
| New GOLD file rows (appended) | ~1,930,000 | ❌ Raw — zero voter_ncid, no RNCID, no DataTrust linkage |
| **TOTAL (contaminated)** | **~2,269,053** | 🔴 DO NOT USE |

**THE PEARL is intact:**
- `core.person_spine` — untouched ✅
- `core.contribution_map` — untouched ✅
- `public.fec_donations` — locked ✅
- All SACRED tables — untouched ✅

**Recovery required before ANY nc_boe_donations_raw work:**
1. Ed says **"I authorize this action"**
2. `TRUNCATE public.nc_boe_donations_raw;`
3. Reload the 338,223 sacred rows from backup snapshot `audit.nc_boe_donations_raw_pre_reload_20260330`
4. Verify `SELECT COUNT(*) FROM public.nc_boe_donations_raw;` = **338,223 exactly**
5. Only then — plan GOLD file ingestion with the full 9-step enrichment pipeline

---

## ⛔ CRITICAL APRIL 9, 2026 — FULL DATABASE RESET IN EFFECT (from 12:15 AM session)

**EARLIER DECISION:** All prior FEC and NCBOE donor files in Supabase were contaminated (Democratic candidates, out-of-state donors, throttled bulk downloads). The Supabase database was restored to the April 9, 2026 7:00 AM snapshot. **Do not reference any FEC or NCBOE data loaded before this reset.**

### What Was Preserved (Sacred — Do Not Touch)
- `public.nc_datatrust` — 7,661,978 rows ✅ SACRED
- `public.nc_voters` — 9,079,672 rows ✅ SACRED
- `public.rnc_voter_staging` — 7,708,268 rows ✅ SACRED
- `staging.nc_voters_fresh` — 7,707,910 rows ✅ SACRED

---

## READ THESE FILES BEFORE ANYTHING ELSE (in order)
1. `sessions/SESSION_START_READ_ME_FIRST.md` — THIS FILE — read completely first
2. `sessions/SESSION_APRIL9_2026_EVENING.md` — tonight's session: incident #13, live counts, recovery plan
3. `sessions/MASTER_FILE_MANIFEST.md` — exact file inventory and what not to touch
4. `sessions/PERPLEXITY_HIGHLIGHTS.md` — key architectural rules and agent guardrails
5. `sessions/SESSION_APRIL7_2026_EVENING.md` — prior session baseline

---

## ⚠️ MANDATORY — ALL AGENTS (PERPLEXITY, CURSOR, CLAUDE, ANY AI)

Before you write a single line of SQL, make a single recommendation, or touch anything:

1. **Read this file completely**
2. **State which files you read in your first reply**
3. If you cannot see the repo — say so explicitly and ask for a paste
4. **DO NOT guess process, pipeline, or architecture from memory or code inspection alone**
5. **DO NOT load any FEC or NCBOE file without explicit authorization from Ed stating the filename and source**
6. **DO NOT INSERT or COPY into nc_boe_donations_raw without first running TRUNCATE and getting "I authorize this action" from Ed**

We have burned 6+ hours in single sessions because an agent skipped this step and improvised. This is the 13th contamination incident. Do not repeat it.

---

## LIVE DATABASE STATE (April 9, 2026 — 6:10 PM EDT — Perplexity verified)

| Table | Live Rows | Status |
|-------|-----------|--------|
| `public.nc_datatrust` | 7,661,978 | ✅ SACRED — untouched |
| `public.nc_voters` | 9,079,672 | ✅ SACRED — untouched |
| `public.rnc_voter_staging` | 7,708,268 | ✅ SACRED — untouched |
| `staging.nc_voters_fresh` | 7,707,910 | ✅ SACRED — untouched |
| `public.person_master` | 7,728,689 | ✅ untouched |
| `public.nc_boe_donations_raw` | **~2,269,053** | 🔴 CONTAMINATED — needs TRUNCATE + reload to 338,223 |
| `public.fec_donations` | 783,887 | ✅ locked |
| `public.contacts` | 226,821 | ✅ untouched |
| `core.person_spine` | ~200,383 | ✅ PEARL — untouched |
| `core.contribution_map` | 2,953,533 | ✅ untouched |

---

## THE DATABASE — BroyhillGOP-Claude

**Supabase Project:** isbgjpnbocdkeslofota | Region: us-east-1
**Pooler (always use):** `db.isbgjpnbocdkeslofota.supabase.co` port **6543** `sslmode=require`
**Always run first:** `SET statement_timeout = 0;`

---

## THE PEARL — core.person_spine

`core.person_spine` is THE master unified identity table. Every person in this database — donor, voter, volunteer — has one and only one active row here. It is called THE PEARL.

**Rules for THE PEARL:**
- Claude/Perplexity MAY: SELECT anywhere, CREATE TEMP TABLEs, CREATE in staging schema, INSERT into staging
- Claude/Perplexity MAY NOT: DROP/ALTER any table in core/public/archive/norm/raw/staging/audit; UPDATE/DELETE from core.person_spine directly without explicit authorization
- TWO PHASE PROTOCOL: DRY RUN first, then EXECUTION only after Ed says **"I authorize this action"**

---

## SACRED TABLES — DO NOT TOUCH. EVER.

| Table | Rows | Why Sacred |
|-------|------|------------|
| `public.nc_datatrust` | 7,661,978 | RNC DataTrust file — primary identity anchor |
| `public.nc_voters` | 9,079,672 | NC State voter file |
| `public.rnc_voter_staging` | 7,708,268 | RNC voter staging |
| `staging.nc_voters_fresh` | 7,707,910 | DataTrust-enriched voter file |
| `public.person_source_links` | — | Spine bridge table |

**If you are about to touch any of these — STOP. Re-read this file. Then ask Ed.**

---

## KEY POLICY DECISIONS (Ed's Rules — Non-Negotiable)

1. **Republican candidates ONLY** — no Democratic, Independent, Green, or Libertarian candidates in any donor table. Ever.
2. **Democrat and Independent crossover donors ARE kept** — DEM/UNA registered voters who donate to Republican candidates belong in the spine. The donor's party registration is irrelevant; the candidate's party is what matters.
3. **NC donors only** — no out-of-state donors in NCBOE files
4. **Individual donors only** — no corporations, PACs, associations, LLCs
5. **D-only donors are removed** — persons whose ONLY donations went to Democratic committees are deactivated
6. **"Ed" is NOT mapped to "Edward"** — ever, in any system
7. **No committee-to-committee donations** — individual donors to candidate FEC ID committees only
8. **We do not drop schema columns** until we know why they exist and what dataset they match

---

## nc_boe_donations_raw — LOAD PROTOCOL (NON-NEGOTIABLE)

**Before ANY load into nc_boe_donations_raw:**
1. Run `SELECT COUNT(*) FROM public.nc_boe_donations_raw;` — confirm current count
2. Present the count to Ed
3. Run `SELECT COUNT(*) FROM [source_file_staging_table];` — confirm incoming count
4. Get Ed to say: **"I authorize this action"** (exact phrase — no substitutes)
5. Run TRUNCATE first: `TRUNCATE public.nc_boe_donations_raw;`
6. Confirm 0 rows after TRUNCATE
7. Load from backup or fresh files
8. Verify final count matches expected

**Skipping any step = repeating incident #13. There is no exception.**

---

## NEW FILE SOURCING RULES (April 9 — Required Going Forward)

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

---

## PENDING WORK (Post-Incident Priority Order)

### IMMEDIATE — nc_boe_donations_raw Recovery
1. Ed authorizes: **"I authorize this action"**
2. TRUNCATE `public.nc_boe_donations_raw`
3. Reload 338,223 sacred rows from `audit.nc_boe_donations_raw_pre_reload_20260330`
4. Verify COUNT = 338,223 exactly

### Phase 1 — Fresh File Load (After table is clean)
5. Ed transfers fresh county-broken NCBOE files from laptop (GOLD 18 + approved supplementals)
6. Load NCBOE files ONE AT A TIME with Ed's authorization per file, TRUNCATE-first protocol enforced
7. Run enrichment pipeline after each batch before loading next

### Phase 2 — Normalization
8. Rebuild `norm.nc_boe_donations` from fresh raw
9. Rebuild `core.contribution_map`

### Phase 3 — Identity Resolution
10. Run 7-Pass Donor Rollup per `DONOR_ROLLUP_IDENTITY_SPEC.md`
11. Ed Broyhill canary must pass before any merge executes

### Infrastructure (Ongoing — URGENT)
- **DataTrust token expires April 10, 2026** — renew with Zack Imel (RNC Digital Director) TODAY
- **DataTrust full 2,200-variable dump** — Zack Imel agreed; schema must be jsonb-ready before delivery
- **DB password** — rotate at Supabase dashboard (compromised)
- **FEC API key** — rotate at api.data.gov (compromised)

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
| DataTrust full dump | Zack Imel agreed; schema must be jsonb-ready before delivery |
| DataTrust token expires | **April 10, 2026** — URGENT — contact Zack Imel today |

---

*Updated by Perplexity | April 9, 2026 6:10 PM EDT*
*Incident #13 documented. nc_boe_donations_raw contaminated (~2.27M rows). Recovery pending Ed authorization.*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
