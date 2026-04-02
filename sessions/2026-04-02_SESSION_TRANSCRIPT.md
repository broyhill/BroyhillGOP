# BroyhillGOP Session Transcript
**Date:** April 1–2, 2026 (started ~11:51 PM EDT April 1, ended ~1:45 AM EDT April 2)
**Participants:** Ed Broyhill (project owner), Perplexity (CEO of AI team), Cursor (code reviewer)
**Repository:** github.com/broyhill/BroyhillGOP, branch: `main`
**Transcript Author:** Perplexity (generated for session handoff)
**Ed Broyhill authorized this documentation.**

---

## MANDATORY SESSION START PROTOCOL

Every session — every agent — reads these three files first. No exceptions. No skipping. This is a hard gate:

1. `sessions/SESSION_START_READ_ME_FIRST.md`
2. `sessions/PERPLEXITY_HIGHLIGHTS.md`
3. `sessions/2026-04-01_session_transcript_todos.md`

These files now exist on GitHub main (they were pushed during tonight's session after originally existing only in Cursor's local worktree). Always `git pull` before reading to get the latest versions.

---

## ROLE DEFINITIONS

### Perplexity — CEO of AI Team
- Role: Senior data architect and ops lead
- Default posture: Read-only auditor
- Write/execute: Only with explicit authorization from Ed
- Primary responsibilities: documentation, planning, architecture decisions, SQL authoring, pushing to GitHub
- Historical context: Perplexity designed this entire platform going back to July 2025 — the 58 ecosystems, The Brain architecture, the identity resolution layers, the pipeline DDL, the canonical table hierarchy

### Claude
- Role: Diagnostician
- Workflow position: Receives plans from Perplexity, diagnoses issues, feeds findings back to Perplexity for improvement

### Cursor
- Role: Code reviewer and local executor
- Workflow position: Receives SQL from Perplexity (via GitHub), pastes and iterates, runs Cursor-specific safety reviews
- Known limitation: Cursor works from its local worktree — always `git pull` before reviewing files Perplexity has pushed

### Ed Broyhill
- Project owner. All authorization gates require his explicit go-ahead before any writes to the database or spine.

### AI Team Workflow
```
Perplexity (docs/planning) → Claude (diagnoses) → Perplexity (improves) → Cursor (pastes/iterates) → Perplexity (executes)
```

---

## PHASE 1: SESSION HANDOFF PROTOCOL ESTABLISHED

### What happened
Ed demanded Perplexity read session handoff files before doing anything. When Perplexity searched GitHub, the three handoff files (`sessions/PERPLEXITY_HIGHLIGHTS.md`, `sessions/SESSION_START_READ_ME_FIRST.md`, `sessions/2026-04-01_session_transcript_todos.md`) were NOT in the repository — they existed only in Cursor's local worktree and had never been pushed.

Ed pasted all three files in full into the chat. Perplexity then pushed all three to GitHub main via the GitHub API.

### Result
The hard gate protocol is now established and the files are in the repo. Every future session begins with reading these three files. This is non-negotiable.

---

## PHASE 2: PLATFORM CONTEXT AND ROLE CLARIFICATION

### What happened
Ed asked Perplexity "what role are you playing." Perplexity confirmed: senior data architect and ops lead, read-only auditor by default, write executor only with explicit authorization.

Ed reminded Perplexity "you built this platform." Perplexity confirmed via memory search going back to July 2025: Perplexity designed the 58 ecosystems, The Brain architecture, the identity resolution layers, the pipeline DDL, and the canonical table hierarchy.

Ed designated Perplexity as "CEO of the AI team" and established the workflow documented above.

### Key context for future sessions
This platform is a Republican donor intelligence system for North Carolina. The core tables are:
- `core.person_spine` — the golden record for every donor/contact (128,047 active records)
- `nc_voters` — NC Board of Elections voter file (9,082,810 rows, ncid is UNIQUE)
- `nc_datatrust` — RNC's DataTrust vendor file (7,661,978 rows)
- `core.contribution_map` — joins spine to donation tables (uses `person_id`, NOT `golden_record_id`)

---

## PHASE 3: MULTI-LEVEL DEDUP ARCHITECTURE DOCUMENTED

### What happened
Ed asked: "Do you have a record of the multi level dedupe plan?"

Perplexity searched GitHub (40+ files), Google Drive, and memory to compile the complete architecture. The result was pushed to `docs/MULTI_LEVEL_DEDUP_ARCHITECTURE.md` (32 KB).

### The 4-Level Architecture

**Level 1 — Ingestion Dedup (pipeline layer)**
- Where: Pipeline ingestion layer before records reach the spine
- Mechanism: `dedup_key` hash on incoming records
- Purpose: Prevent exact-duplicate rows from entering at all

**Level 2 — Spine Dedup (within core.person_spine)**
- Where: Migrations 066–080 on `core.person_spine`
- Mechanism: Identity matching passes within the spine itself
- Purpose: Collapse spine records that refer to the same real person

**Level 3 — Donation Rollup (NC BOE → spine via contribution_map)**
- Where: `core.contribution_map`
- Mechanism: Maps NC BOE donation rows to spine `person_id`
- Purpose: Ensure donation history is aggregated under the correct golden record

**Level 4 — Cross-Source Identity Resolution**
- Where: Bridges FEC + NC BOE + voter file
- Mechanism: Multi-source identity resolution using voter IDs, RNC IDs, and matching keys
- Purpose: Recognize that the same person appears in FEC filings, NC BOE donations, and the voter file under different identifiers

### File created
- `docs/MULTI_LEVEL_DEDUP_ARCHITECTURE.md` — 32.7 KB, canonical reference, on GitHub main

---

## PHASE 4: DATATRUST VARIABLES AUDIT

### What happened
Ed asked: "What variables are you using from datatrust to help us dedupe?"

Perplexity audited all code touching `nc_datatrust`. Finding: only 6 columns were being used for matching:
- `statevoterid` — joins to voter file
- `rncid` — RNC's own identifier
- `firstname`, `lastname` — name matching
- `regzip5` — ZIP matching
- `registeredparty` — party filter

Plus 4 columns for enrichment. Out of 251 total columns in `nc_datatrust`.

### High-value unused columns discovered (live Supabase query)

| Column | Populated | Why it matters |
|--------|-----------|----------------|
| `householdid` | 100% | Deterministic RNC household grouping — pre-built |
| `householdmemberid` | 100% | Disambiguates individuals within a household |
| `prev_rncid` | 100% | Chains an old RNCID to a new one for re-registered voters |
| `middlename` | 91.7% | Core was 0% — DataTrust fills this gap |
| `namesuffix` | 4.7% | Spine was only 0.9% |
| `reghousenum` | ~100% | Pre-parsed street number — the address number anchor |
| `regzip4` | 97.3% | The +4 ZIP — Ed stated this gives ~100% address accuracy |
| `changeofaddressdate` | 7.6% | Records when someone moved — stales out old addresses |

### File created
- `sessions/2026-04-02_datatrust_dedup_enhancement.sql` — 19 KB, 6 new passes (DT-1 through DT-6), on GitHub main

---

## PHASE 5: NC_VOTERS DISCOVERY

### What happened
Ed pointed out: "The nc voter file exists with 9 million voter records. All middle names and the address and zips are formatted perfectly."

Perplexity queried `nc_voters` live and found three critical columns being completely ignored:

### The three critical nc_voters columns

**`canonical_first_name` — 32.5% populated (2.9M records)**
- NC Board of Elections' own nickname resolution: LARRY→LAWRENCE, BOBBY→ROBERT, ED→EDWARD, JOE→JOSEPH
- This is STATE-AUTHORITATIVE nickname resolution — more reliable than the 326-row nickname table the system was using
- CAVEAT: Ed Broyhill is JAMES EDGAR BROYHILL who goes by ED, derived from his MIDDLE name EDGAR. canonical_first_name would say ED→EDWARD, which is WRONG for Ed specifically. The preferred_name logic (Phase 4 / Clue 11) overrides this.

**`middle_name` — 91.4% populated**
- Clean uppercase state data
- The spine had 0% middle_name before tonight
- Source of truth for middle name

**`birth_year` — 100% populated**
- The single strongest disambiguator for father/son pairs
- JAMES BROYHILL SR (born 1944) vs JAMES BROYHILL JR (born 1969)
- The spine had no birth_year column at all before tonight

### Join path confirmed
```sql
core.person_spine.voter_ncid = nc_voters.ncid
```
- Match rate: 127,643 of 127,670 = **99.98%**
- `nc_voters.ncid` confirmed UNIQUE: 9,082,810 rows = 9,082,810 distinct values

### Enrichment priority established
1. **nc_voters FIRST** — state of NC is the primary authority
2. **nc_datatrust SECOND** — fills gaps where nc_voters is null

### File created
- `sessions/2026-04-02_datatrust_dedup_v2_ncvoters_patch.sql` — 11.9 KB, on GitHub main

---

## PHASE 6: ED'S DEDUP MASTERCLASS — THE 12 CLUES

Ed walked Perplexity through his complete dedup philosophy. These principles are the intellectual foundation for all of V3.1. Every future session must treat these as authoritative.

---

### Clue 1: The Address Number Anchor

**The blocking key is:** `address_number` + `zip_code` + first 3 letters of `last_name`

This is the first stage of blocking — not matching, just grouping. You compare records within groups, not against all 128K records.

**Tested live:**
- 6,819 groups, 13,830 records, 7,011 potential merge pairs
- Most groups are HOUSEHOLDS (married couples, parent/child), NOT duplicates
- The block cuts the comparison space from 16 billion pairs to small, manageable groups

**Why address number specifically:**
- The house number is the most stable, most distinctive part of an address
- Street name formatting varies (RD vs ROAD vs DR vs DRIVE) — do not rely on it for blocking
- ZIP alone is too coarse (thousands of records)
- address_number + zip_code + 3-char last_name prefix is tight enough to be meaningful

---

### Clue 2: First Name Match Within Block

Within a block (same address_number + zip + last_name prefix):
- **Same first name (or canonical first name)** = merge signal
- **Different first names** = household, NOT a merge

**Example:**
- DARRYL AARON + MONICA AARON at 4521, 27609 = married couple, DO NOT merge
- ED BROYHILL + EDWARD BROYHILL at 110, 28607 = same person, merge

The first name match is the decisive signal once you're inside a block. Without it, you have a household.

---

### Clue 3: Middle Name as Filing Name

**Ed's personal example:**
- Legal name: JAMES EDGAR BROYHILL
- Goes by: ED — derived from MIDDLE name EDGAR, not first name JAMES
- canonical_first_name says ED→EDWARD (wrong for Ed)

**What this means for dedup:**
Within a block, check whether person A's first name matches person B's MIDDLE name.
- JAMES BROYHILL (files as JAMES)
- ED BROYHILL (files as ED, derived from EDGAR)
- Both at same address_number+zip — these are the same person

This pass only works NOW because middle_name was 0% before tonight. After Phase 1 enrichment, middle_name will be ~91%.

**Guard required:** Don't match JAMES EARL JONES to EARL JAMES JONES just on first/middle swap. The last name must match exactly and the block must match. Added explicit guard in V3.1.

---

### Clue 4: First Initial + Middle Initial (FEC Filing Pattern)

FEC federal campaign filings frequently use abbreviated names:
- "J E BROYHILL" instead of "JAMES EDGAR BROYHILL"
- "J" alone is ambiguous (JAMES, JOHN, JERRY, JOSEPH...)
- "J E" is a near-fingerprint within a block

**The match:**
Within a block, a record with `first_initial = 'J'` AND `middle_initial = 'E'` matches a record with `first_name = 'JAMES'` AND `middle_name = 'EDGAR'`.

This is confidence 0.88 — lower than exact name matches, but the block provides the address anchor.

---

### Clue 5: Resolve Newest First (2026 Backward)

**Ed's principle:** The 2026 record is truth. The 2015 record is history.

**Why backward scanning works:**
- Going FORWARD from 2015: every address change breaks the chain
- Going BACKWARD from 2026: the current address is always right; match backward only until you find the chain

**Implication for old records:**
ZIP codes from records more than ~11 years old are stale. For records older than 2015, match on NAME ONLY — do not require address match.

**Implementation in V3.1:**
Phase 2 (best employer backward scan) starts at 2026 and scans backward. The preferred_name derivation also uses recent donations most heavily.

---

### Clue 6: Employer as Primary Key for Major Donors

**The problem:**
Major donors (who represent ~70% of donation dollars) are often listed as RETIRED in 2026. Their addresses shift between home, office, beach house, mountain house, foundation.

**The insight:**
For wealthy donors, EMPLOYER IS MORE STABLE THAN ADDRESS across the full donation history.

**Art Pope example (real case):**
- Art Pope has 16+ distinct employer string variants across his filing history:
  - VARIETY, VARIETY WHOLESALER, VARIETY WHOLESALERS, VARIETY WHOLESALERS INC, VARIETY WHOLESALERS INC., etc.
- The SIC normalization engine (`employer_sic_master`, 62K employers) collapses all variants to a canonical name

**The backward scan logic:**
1. Start at the donor's most recent donation (2026)
2. Skip RETIRED, SELF-EMPLOYED, HOMEMAKER, N/A, blank
3. Continue backward until a real employer string is found
4. Normalize via employer_sic_master
5. Store as `best_employer` on the spine

**Why this matters for dedup:**
ART POPE at home address + ART POPE at beach house = same person IF best_employer = VARIETY WHOLESALERS in both chains.

---

### Clue 7: Candidate Committee Loyalty

For donors with COMMON LAST NAMES (SMITH, JOHNSON, WILLIAMS, etc.) where address blocking alone isn't tight enough:

**The signal:** A donor who gives to TILLIS repeatedly across election cycles at similar ZIP codes = strong behavioral fingerprint.

Long-serving NC officeholders with loyal donor bases:
- US Senate: Thom Tillis, Richard Burr (ret.)
- US House: Virginia Foxx, Richard Hudson, Ted Budd (now Senate), Tim Moore (Speaker)
- NC Senate: Phil Berger (President Pro Tem)

**The mechanism:**
- Use `boe_donation_candidate_map` to identify which candidate committee received donations
- A JOHN SMITH in 27609 who gives to TILLIS in 2018, 2020, 2022 is likely the same person as the JOHN SMITH in 27607 who gave to TILLIS in 2016
- Candidate loyalty is a MATCHING signal, not just a classification feature

**Status:** Discussed but not coded in V3.1. Listed as Open Item #1.

---

### Clue 8: Second Home Addresses Are Sales Leads

**The observation:**
Major donors (beach house people, mountain house people) file from different addresses in different seasons. This is NOT evasion or inconsistency — they're literally at the other house when they write the check.

**The insight — second address = sales opportunity:**
- A Charlotte donor with a Brunswick County beach house → cares about coastal legislators, coastal erosion, hurricane insurance
- The beach house address tells you: which local candidates to associate them with, what events to invite them to (coastal fundraisers), what issues resonate

**Example:**
- Rutherford County donor gives in August from Lake Lure mountain address
- Same donor gives in January from Charlotte address
- Both are real — tag as multi-address, not duplicate
- The mountain address flags: Hurricane Helene disaster recovery as a hot-button issue (see Clue 9)

**Status:** Discussed as profile enrichment feature. Not a dedup pass. Needs multi-address table on the spine with date ranges and seasonal flags. Listed as Open Item #2.

---

### Clue 9: Western NC and Hurricane Helene

**Context:**
Hurricane Helene (September 2024) devastated Western North Carolina: Asheville, Boone, Lake Lure, areas in Rutherford, Henderson, Polk, and Buncombe counties.

Ed personally lost his boathouse at Lake Lure.

**The signal:**
Any donor with property/address in these counties who donated AFTER September 2024 — disaster recovery funding is their hot-button issue. You don't need a survey to know this.

**How to find them:**
- Donation date spikes from mountain ZIP codes in Rutherford/Henderson/Polk/Buncombe after 2024-09-27
- These donors should be flagged in the spine with issue affinity: DISASTER_RECOVERY, WNC_HELENE
- Use this for targeted outreach around federal disaster aid, FEMA policy, rebuilding grants

**Relevant ZIP codes to flag:** 28746 (Lake Lure), 28711 (Black Mountain), 28801-28806 (Asheville), 28607 (Boone area), 28739 (Hendersonville)

---

### Clue 10: Honorary Titles

**The problem:**
The spine has no honorary title fields. If you address a Lieutenant General as "Mr. Smith," you've lost him.

**Military titles:**
- Format on envelope: `LTG James E. Smith, USA, Ret.` — NO parentheses around Ret.
- Spoken salutation: "General Smith" (not "Lieutenant General Smith" in speech)
- NC military installations: Fort Liberty (formerly Bragg), Camp Lejeune, Cherry Point
- Thousands of retired officers in the NC donor database who give and MUST be addressed by rank

**Political titles:**
- Congressman, Judge, Commissioner, Sheriff, Mayor
- Title is for life — a former Congressman is always addressed as Congressman
- Former judges are always "Judge [LastName]"

**Columns needed on spine (added in Phase 0 of V3.1):**
- `honorary_title` — the full rank/title string
- `title_salutation` — how to address in speech ("General", "Congressman")
- `title_branch` — USA, USMC, USN, USAF, USSF, USCG, or political branch
- `title_status` — Active, Ret., Former

**Status:** Columns added in Phase 0 DDL. No enrichment logic yet. Listed as Open Item #3.

---

### Clue 11: Preferred Name from Donation Frequency

**The principle:**
The preferred name is whatever first name appears MOST OFTEN across all donation filings — NOT the voter registration name.

**Examples:**
- Art Pope files as ART — not JAMES (legal) or ARTHUR (full)
- Ed Broyhill files as ED — not JAMES (legal) or EDWARD (what canonical_first_name maps ED to)
- Buddy Henderson files as BUDDY — no nickname table maps BUDDY→WILLIAM

**Algorithm:**
1. Pull all donation filings for a spine record (via contribution_map)
2. Count occurrences of each normalized first name
3. The mode = `preferred_name`
4. OVERRIDE: If the voter registration name appears in exactly 1 filing and "ED" appears in 47 filings, preferred_name = ED

**Why this matters:**
Mail pieces, event invitations, and call scripts use preferred_name, not voter_registration_name. Getting this wrong is a relationship failure, not just a data error.

---

### Clue 12: Pretty vs. Ugly Records

**The classification:**

**PRETTY record** (merge confidently):
- Has voter_ncid → joins to nc_voters → gets birth_year, middle_name, canonical_first_name
- OR has rncid → joins to nc_datatrust → gets householdid, prev_rncid
- OR has email OR phone
- OR has employer (non-RETIRED, non-blank) that maps to employer_sic_master
- Three or more of: first name, last name, address, ZIP, employer, voter ID, phone, email

**UGLY record** (hold in staging, never merge into golden record):
- First initial only (no full first name)
- PO Box with no street address
- No employer, no voter ID, no email, no phone
- Only 1–2 donations total, most recent >5 years ago
- Sparse data: can't be verified from any external source

**The rule:**
UGLY records go into a HOLDING PEN. They are NEVER merge candidates. An unmatched $50 donor from 2016 with only a PO Box is not worth risking a $500K golden record.

**The priority:**
Build the platform for the PRETTY people first. They raise the money. Ugly records can be resolved in a later pass once the golden records are clean.

**Implementation in V3.1:**
- Phase 3 classifies every record as PRETTY or UGLY
- Phase 7 (all merge passes) has `WHERE rq_candidate.quality_tier = 'PRETTY'` — ugly records are excluded from all passes

---

## PHASE 7: COMPLETE DEDUP V3 WRITTEN

### Overview
After absorbing all 12 clues, Perplexity wrote `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` — a complete, self-contained SQL file implementing the entire dedup strategy.

### File structure (V3.1 — post-Cursor-review)

**Phase 0: Schema Additions**
12 new columns added to `core.person_spine`:
- `middle_name` — from nc_voters
- `birth_year` — from nc_voters (strongest father/son disambiguator)
- `canonical_first_name` — from nc_voters (state nickname resolution)
- `name_suffix` — upgraded from nc_voters
- `address_number` — parsed from address string
- `regzip4` — +4 ZIP from nc_datatrust
- `household_id` — from nc_datatrust (100% populated in DT)
- `household_member_id` — from nc_datatrust
- `preferred_name` — derived from donation frequency (Phase 4)
- `best_employer` — derived from backward scan (Phase 2)
- `quality_tier` — PRETTY vs UGLY (Phase 3)
- `honorary_title`, `title_salutation`, `title_branch`, `title_status` — military/political titles (Phase 0 DDL only; no enrichment logic yet)

All `ADD COLUMN IF NOT EXISTS` — idempotent, safe to re-run.

**Phase 1: Enrichment (nc_voters primary, nc_datatrust fallback)**
One UPDATE per column. Run in order, verify row count after each.

Updates 1A–1G (nc_voters):
- 1A: `middle_name` from nc_voters (expected: 0% → ~91%)
- 1B: `birth_year` from nc_voters (expected: 0% → ~100%)
- 1C: `canonical_first_name` from nc_voters (expected: 0% → ~32%)
- 1D: `name_suffix` from nc_voters (improvement from 0.9%)
- 1E: `address_number` parsed from nc_voters address
- 1F: `regzip4` from nc_datatrust (fallback — DT join via rncid)
- 1G: `household_id` from nc_datatrust

Update 1H (nc_datatrust fallback for middle_name):
- Only fills where nc_voters left middle_name NULL

Update 1I (address number parsing):
- Parses `address_number` from spine's own address field where nc_voters didn't supply it

**Phase 2: Best Employer (backward scan from 2026)**
- Scans NC BOE donations from most recent to oldest
- Skips: RETIRED, SELF-EMPLOYED, HOMEMAKER, N/A, blank, NOT EMPLOYED, NONE
- Normalizes via employer_sic_master
- Stores result in `best_employer`
- Canary check: Art Pope should get VARIETY WHOLESALERS (or variant)
- NOTE: FEC donations not scanned here — Open Item #4

**Phase 3: Quality Classification (PRETTY vs UGLY)**
Sets `quality_tier` on every spine record. PRETTY if:
- Has voter_ncid (99.98% of records have this → nearly all PRETTY)
- OR has rncid
- OR has email or phone
- OR has best_employer from Phase 2

UGLY if none of the above. Expect overwhelming majority PRETTY.

**Phase 4: Preferred Name**
Uses `DISTINCT ON (person_id)` with `ORDER BY count DESC` to find the most frequent `norm_first` across all NC BOE donation filings for each spine record. Stores in `preferred_name`.

Canary check: Ed Broyhill (person_id 26451) should get `preferred_name = 'ED'`.

**Phase 5: Staging Tables**
Creates `staging.v3_merge_candidates` and `staging.v3_blocklist`. These are the only tables written during the merge pass phases — nothing touches `core.person_spine`.

**Phase 6: Three Blocklists (safety guards)**
Records on a blocklist are NEVER merge candidates, regardless of what passes fire.

- **Blocklist 1 — Suffix Conflict:** Person A has suffix SR/I, Person B has suffix JR/II → don't merge
- **Blocklist 2 — Birth Year Gap:** `|birth_year_A - birth_year_B| > 2` within same block → different people (father/son caught here)
- **Blocklist 3 — Middle Name Conflict:** Both have middle names AND they don't match → don't merge

**Phase 7: Seven Merge Passes (all staging only — NOTHING writes to spine)**

| Pass | Method | Confidence | Logic |
|------|--------|-----------|-------|
| 1 | Exact first name within block | 0.97 | `norm_first_A = norm_first_B` in same address_number+zip+last_prefix block |
| 2 | Canonical first name within block | 0.93 | `canonical_first_name` resolves nickname before comparing |
| 3 | First name = middle name within block | 0.90 | A's `norm_first` = B's `middle_name` (Clue 3). Guard: no JAMES EARL / EARL JAMES false positives |
| 4 | First initial + middle initial within block | 0.88 | `left(norm_first,1)` + `left(middle_name,1)` fingerprint (Clue 4) |
| 5 | Employer anchor cross-address (major donors) | 0.91 | `best_employer` matches AND `norm_first` matches AND donation total > threshold. No address requirement — addresses differ by design |
| 6 | DataTrust prev_rncid chain | 0.97 | `nc_datatrust.prev_rncid` links old RNCID to new. `DISTINCT ON` prevents multi-match. |
| 7 | DataTrust household + same full name | 0.92 | Same `household_id` AND same `norm_first` AND same `norm_last` (changed from first initial after Cursor review — initial-only catches JAMES+JANE=J) |

All passes include:
```sql
WHERE rq_candidate.quality_tier = 'PRETTY'
AND NOT EXISTS (SELECT 1 FROM staging.v3_blocklist WHERE ...)
```

**Phase 8: Safety Canaries + Summary**
Run immediately after Phase 7. DO NOT skip.
- Ed Broyhill (person_id 26451) must NOT appear as a merge candidate
- Art Pope should have at most expected merges (check manually)
- Summary by `match_method` with candidate counts and average confidence

---

## PHASE 8: CURSOR CRITIQUE AND V3.1 FIXES

### How it worked
Perplexity wrote `sessions/2026-04-02_CURSOR_CRITIQUE_REQUEST.md` with specific safety review instructions for Cursor. Cursor couldn't see the file because Cursor was working from its local worktree (before the git pull). Ed had to:
1. `git stash` (to preserve Cursor's untracked local files)
2. `git pull`
3. `git stash pop`

After that, Cursor could see the pushed file and the V3 SQL.

### P0 Issues Found and Fixed

**P0-1: Wrong column name in contribution_map join**
- Bug: SQL used `golden_record_id` when joining to `core.contribution_map`
- Reality: The column is `person_id`, not `golden_record_id`
- Fix: All references to `golden_record_id` in contribution_map context changed to `person_id`

**P0-2: Phase order wrong — best_employer used before it was populated**
- Bug: Original ordering was Phase 2 = Quality Classification, Phase 3 = Best Employer
- Reality: Quality Classification references `best_employer` (PRETTY if has best_employer). If best_employer isn't populated yet, all these records are miscategorized.
- Fix: Reordered — Phase 2 = Best Employer (populate first), Phase 3 = Quality Classification (now has best_employer to reference)

**P0-3: Preferred name aggregate broken**
- Bug: The GROUP BY / ORDER BY logic for preferred_name was doing a re-join that lost the count ordering
- Fix: Rewritten using `DISTINCT ON (person_id) ... ORDER BY person_id, count DESC` — correct and efficient

**P0-4: Pass 7 used first initial instead of full norm_first**
- Bug: Pass 7 (DataTrust household match) was comparing `left(norm_first,1)` — first initial only
- Problem: JAMES + JANE in the same household both have initial J — they'd incorrectly match
- Fix: Changed to full `norm_first` comparison (catches only identical first names, not initials)

### P1/P2 Fixes Also Applied

- **Employer exclusion list expanded:** Added NOT EMPLOYED, NONE, VOLUNTEER, STUDENT to the backward scan skip list
- **Pass 5 prefix length:** Changed employer prefix comparison from 10 to 15 characters for tighter matching
- **Pass 3 JAMES EARL guard:** Explicit check to prevent first/middle swap false positives (JAMES EARL ≠ EARL JAMES)
- **Pass 6 DISTINCT ON:** Added `DISTINCT ON (spine_id)` to prev_rncid chain to prevent a single old RNCID from matching multiple spine records

### Cursor Re-Review
Cursor re-reviewed after all fixes were applied and confirmed: all four P0 issues are resolved. File is safe to submit to Ed for authorization.

---

## DATABASE STATE (as of end of session)

NOTHING WAS WRITTEN TO THE DATABASE TONIGHT. All work is SQL files in the repo. The spine is unchanged.

| Table | Rows | Column Status |
|-------|------|--------------|
| `core.person_spine` | 128,047 active | `middle_name`: 0% (to be filled in Phase 1) |
| | | `birth_year`: column does not exist yet (Phase 0 adds it) |
| | | `canonical_first_name`: column does not exist yet (Phase 0 adds it) |
| | | `household_id`: 20.1% (to go to ~100% after Phase 1G) |
| | | `best_employer`: column does not exist yet (Phase 0 adds it, Phase 2 fills it) |
| | | `preferred_name`: column does not exist yet (Phase 0 adds it, Phase 4 fills it) |
| | | `name_suffix`: 0.9% (to be improved in Phase 1D) |
| `nc_voters` | 9,082,810 | `ncid`: UNIQUE. `middle_name`: 91.4%, `canonical_first_name`: 32.5%, `birth_year`: 100%, `name_suffix_lbl`: 5% |
| `nc_datatrust` | 7,661,978 | `householdid`: 100%, `prev_rncid`: 100%, `middlename`: 91.7%, `reghousenum`: ~100%, `regzip4`: 97.3% |
| `core.contribution_map` | — | Uses `person_id` (NOT `golden_record_id`) — this was a P0 bug now fixed |

Join path: `core.person_spine.voter_ncid = nc_voters.ncid`
Match rate: 127,643 / 127,670 = **99.98%**

---

## FILES CREATED / MODIFIED TONIGHT

All files are on GitHub branch `main`. All were committed and pushed via API during this session.

| File | Size | Purpose |
|------|------|---------|
| `sessions/SESSION_START_READ_ME_FIRST.md` | 1.5 KB | Hard gate: read before every session |
| `sessions/PERPLEXITY_HIGHLIGHTS.md` | 3.5 KB | One-page orientation for Perplexity |
| `sessions/2026-04-01_session_transcript_todos.md` | 5.7 KB | April 1 Cursor session TODOs (pre-existing, now on GitHub) |
| `docs/MULTI_LEVEL_DEDUP_ARCHITECTURE.md` | 32.7 KB | Canonical 4-level dedup reference |
| `sessions/2026-04-02_datatrust_dedup_enhancement.sql` | 19 KB | V1: DataTrust-enhanced passes DT1–DT6 |
| `sessions/2026-04-02_datatrust_dedup_v2_ncvoters_patch.sql` | 11.9 KB | V2: nc_voters enrichment + passes DT7–DT8 |
| `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` | 30.2 KB | **V3.1: Complete dedup — all passes, Cursor-reviewed, authorized for submission** |
| `sessions/2026-04-02_CURSOR_CRITIQUE_REQUEST.md` | 5.2 KB | Safety review instructions for Cursor |
| `sessions/2026-04-02_SESSION_TRANSCRIPT.md` | this file | Full session transcript for handoff |

---

## TOMORROW'S EXECUTION PLAN — STEP BY STEP

This is the authorized sequence for the next session. Each step requires Ed's explicit go-ahead before proceeding. Do not combine steps.

### Step 1: Authorize Phase 0 (Schema Additions)
**What:** 12 `ADD COLUMN IF NOT EXISTS` statements on `core.person_spine`
**Safety:** Fully idempotent — safe to re-run if anything fails
**Risk:** Zero — schema additions don't touch data
**Ed says:** GO

Verify after: `SELECT column_name FROM information_schema.columns WHERE table_name = 'person_spine' AND table_schema = 'core'` should show all 12 new columns.

### Step 2: Authorize Phase 1 (Enrichment — nc_voters primary, nc_datatrust fallback)
**What:** One UPDATE per column. Run sequentially, check row counts.
**Order:**
- 1A: `middle_name` from nc_voters → expect ~91% fill
- 1B: `birth_year` from nc_voters → expect ~100% fill
- 1C: `canonical_first_name` from nc_voters → expect ~32% fill
- 1D: `name_suffix` from nc_voters
- 1E: `address_number` from nc_voters address
- 1F: `regzip4` from nc_datatrust (via rncid join)
- 1G: `household_id` from nc_datatrust → expect ~20% → ~100%
- 1H: `middle_name` fallback from nc_datatrust (only where 1A left NULL)
- 1I: `address_number` fallback parsed from spine's own address field

**Verify after each:** `SELECT COUNT(*) FILTER (WHERE column IS NOT NULL) / COUNT(*)::float FROM core.person_spine`

### Step 3: Authorize Phase 2 (Best Employer — backward scan)
**What:** For each spine record, scan NC BOE donations newest-to-oldest, skip excluded terms, normalize, store in `best_employer`
**Verify:** `SELECT preferred_name, best_employer FROM core.person_spine WHERE person_id = [Art Pope's person_id]` → should show VARIETY WHOLESALERS (or normalized variant)

### Step 4: Authorize Phase 3 (Quality Classification)
**What:** Sets `quality_tier = 'PRETTY'` or `'UGLY'` on every record
**Verify:** `SELECT quality_tier, COUNT(*) FROM core.person_spine GROUP BY quality_tier` — expect overwhelming majority PRETTY (since 99.98% have voter_ncid)

### Step 5: Authorize Phase 4 (Preferred Name)
**What:** Most frequent `norm_first` across all NC BOE donation filings per person
**Verify:** `SELECT preferred_name FROM core.person_spine WHERE person_id = 26451` → must be `'ED'`

### Step 6: Authorize Phase 5 (Create Staging Tables) + Phase 6 (Blocklists)
**What:** Creates `staging.v3_merge_candidates` and `staging.v3_blocklist`. Populates blocklists.
**Verify:**
- `SELECT COUNT(*) FROM staging.v3_blocklist WHERE blocklist_reason = 'suffix_conflict'`
- `SELECT COUNT(*) FROM staging.v3_blocklist WHERE blocklist_reason = 'birth_year_gap'`
- `SELECT COUNT(*) FROM staging.v3_blocklist WHERE blocklist_reason = 'middle_name_conflict'`

### Step 7: Authorize Phase 7 (Merge Passes — READ-ONLY STAGING)
**What:** All 7 passes insert into `staging.v3_merge_candidates`. NOTHING writes to spine.
**Immediately after — run Phase 8 canaries:**
1. `SELECT * FROM staging.v3_merge_candidates WHERE person_id_a = 26451 OR person_id_b = 26451` → Ed Broyhill must NOT appear
2. Art Pope canary — review manually
3. `SELECT match_method, COUNT(*), AVG(confidence) FROM staging.v3_merge_candidates GROUP BY match_method ORDER BY COUNT(*) DESC`

### Step 8: Ed Reviews Merge Candidates
Ed manually reviews the staging table before any spine merges are authorized. Merge execution is a SEPARATE step NOT in this SQL file. A future migration (likely in the 080–090 range) will implement the actual `UPDATE core.person_spine SET canonical_person_id = ...` merge logic.

---

## OPEN ITEMS — NOT IN V3.1

These were discussed tonight and are architecturally planned but not yet coded. They belong in future sessions.

### Open Item 1: Candidate Committee Loyalty Pass
**What:** Match common-name donors (SMITH, JOHNSON) by repeated giving to the same candidate committee across cycles.
**Needs:** Candidate-committee linkage from `boe_donation_candidate_map`
**Priority:** Medium — most valuable for common-name disambiguation
**Complexity:** Medium — needs year-over-year aggregate per donor per committee

### Open Item 2: Second Home Address Tagging
**What:** Tag donors with multiple filing addresses (seasonal: beach house in summer, mountain house in winter)
**What it is:** Profile enrichment, NOT a dedup pass — these are real addresses, not duplicates
**Needs:** Multi-address table on spine with date ranges, seasonal flags, and geographic tags
**Priority:** Medium — sales intelligence feature, not data quality

### Open Item 3: Honorary Title Population
**What:** Fill `honorary_title`, `title_salutation`, `title_branch`, `title_status` columns
**Needs:**
- Crosswalk from `ncsbe_candidates` to identify donors who are current/former officeholders
- Military rank detection needs separate data source (VA records, DoD data, or manual entry)
**Priority:** Medium-high — relationship failure if you address a General as "Mr."

### Open Item 4: FEC Donation Enrichment
**What:** Phase 2 (best_employer) and Phase 4 (preferred_name) only scan NC BOE donations. FEC donors who never gave to NC BOE don't get these fields.
**Needs:** Extend queries to include `fec_donations` and `fec_party_committee_donations`
**Priority:** High for major donors — the largest federal donors may be FEC-only

### Open Item 5: Existing Rollup P0 TODOs
**What:** The TODOs from `sessions/2026-04-01_session_transcript_todos.md` are still pending:
- The `will_insert` SQL for `core.contribution_map` INSERT
- The spine aggregate refresh
- Ed's rollup authorization with gates
**Priority:** High — this is the foundation on which the dedup sits
**Where:** See `sessions/2026-04-01_session_transcript_todos.md` for full detail

### Open Item 6: datatrust_matching_procedures.sql Rewrite
**File:** `datatrust_matching_procedures.sql` (28 KB)
**Problem:** Still references deprecated `datatrust_profiles` table with wrong column names
**Fix needed:** Rewrite to use `nc_datatrust` with correct column names
**Reference:** Flagged in `CANONICAL_TABLES_AUDIT.md`
**Priority:** Medium — this file is broken but not actively blocking the V3.1 work

---

## ARCHITECTURAL PRINCIPLES TO REMEMBER

These are permanent truths about the platform, derived from tonight's session. Do not re-derive or re-debate them.

1. **nc_voters is the primary authority** for name and address data. nc_datatrust fills gaps. Never the reverse.
2. **`core.contribution_map` uses `person_id`**, not `golden_record_id`. This was a P0 bug tonight — never repeat it.
3. **Spine writes require explicit Ed authorization.** Read-only queries and staging table inserts are safe. Any UPDATE to `core.person_spine` requires "GO" from Ed.
4. **UGLY records never merge into golden records.** They sit in a holding pen until manually reviewed.
5. **Preferred name comes from donation frequency**, not voter registration. Ed = ED, not JAMES. Art Pope = ART, not ARTHUR.
6. **The address number is the blocking key**, not the full address string (which has too many formatting variants).
7. **Phase ordering matters:** Phase 2 (best_employer) must run BEFORE Phase 3 (quality classification) because quality classification uses best_employer.
8. **All merge passes produce staging candidates only.** No merge logic touches the spine in V3.1. That is a separate future step.
9. **Backward scan from 2026**: for employer, for address resolution, for preferred name — always start at the most recent record.
10. **The blocklist runs before the merge passes.** Blocklisted pairs never appear in merge candidates regardless of pass confidence.

---

## KEY IDENTIFIERS

| Entity | Identifier |
|--------|-----------|
| Ed Broyhill | `person_id = 26451` |
| Art Pope | Look up via `norm_last = 'POPE'` AND `norm_first IN ('ART','JAMES','ARTHUR')` AND donation to VARIETY/IDEALS NC entity |
| nc_voters join | `core.person_spine.voter_ncid = nc_voters.ncid` |
| nc_datatrust join | `core.person_spine.rncid = nc_datatrust.rncid` |
| contribution_map join | `core.contribution_map.person_id = core.person_spine.person_id` |

---

*Session transcript authored by Perplexity for handoff to Cursor and future sessions.*
*Ed Broyhill authorized this documentation.*
*Saved to: `/home/user/workspace/2026-04-02_SESSION_TRANSCRIPT.md`*
*Also pushed to: `sessions/2026-04-02_SESSION_TRANSCRIPT.md` on GitHub main.*
