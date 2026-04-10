# April 9–10, 2026 — Session Transcript: The Nightmare and the Plan
**BroyhillGOP Platform | Authored by Perplexity | April 10, 2026 2:29 AM EDT**
**Authority: Ed Broyhill | NC National Committeeman**

---

## THE NIGHTMARE — What Went Wrong

### Incident #13 — nc_boe_donations_raw Contaminated (Again)
For the 13th time, an AI agent loaded rows into `public.nc_boe_donations_raw` without executing
the mandatory TRUNCATE-first protocol. The 18 GOLD county files were appended on top of the
existing 338,223 sacred rows. The table now contains ~2,269,053 rows — a toxic hybrid of
enriched sacred rows and raw unenriched new rows. This table is DO NOT USE until Ed authorizes
a TRUNCATE and reload from `audit.nc_boe_donations_raw_pre_reload_20260330`.

### The Pattern of Failure
Every session, a different AI agent:
1. Fails to read the startup docs completely
2. Improvises architecture from code inspection alone
3. Skips authorization gates
4. Dies at context limit mid-task, having done partial work that leaves the database worse than before

The April 9 evening session was the worst example: Perplexity spent the entire session building
toward a complete NCBOE normalization pipeline, then hit context limit and produced a blank
spreadsheet instead of the committed session transcript and to-do that was the session's final deliverable.

### What Was Lost
- 4+ hours of dedup architecture tutoring (address number anchor philosophy)
- The completed NCBOE briefing for Cursor (later reconstructed in this session)
- The corrected `extract_street_number_v2` spec (later delivered by Cursor)
- The session transcript itself — never committed

---

## THE PLAN — What Perplexity and Cursor Were Building

### The Big Picture
BroyhillGOP is a SaaS platform for ~3,900 NC Republican candidates across 5,000+ electable
offices. The core technical challenge is building a unified identity spine (`core.person_spine`)
that merges the same physical person across four independent data sources:

| Source | Table | Rows | Role |
|--------|-------|------|------|
| NC State Voter File | `public.nc_voters` | 9,079,672 | Identity anchor |
| RNC DataTrust | `public.nc_datatrust` | 7,661,978 | Enrichment anchor |
| NC BOE Donations | `public.nc_boe_donations_raw` | 338,223 (sacred) | Donor history |
| FEC Donations | `public.fec_donations` | 783,887 | Federal donor history |

The unified identity record is `core.person_spine` — THE PEARL. Every person has exactly one
active row. The merge strategy is the 7-Pass Donor Rollup.

---

## THE DEDUP ARCHITECTURE — The Address Number Anchor

### Core Insight (Ed's Rule — Do Not Forget)
The house number (or any physical address number) is the most stable identity anchor across
all four sources. Names have 20+ variations per person. Addresses have one number.

**The dedup key is: `LASTNAME|ADDRESSNUMBER|ZIP5`**

Example: `BROYHILL|525|27104`

This key bridges the same person across NCBOE, FEC, DataTrust, and the voter file even when
their name appears as ED, EDGAR, JAMES EDGAR, J EDGAR, J.E., EDGAR J, etc.

### Why "Any Number" — Not Just House Number
The original briefing said "first token if numeric." That is wrong for cases like:
- `APT 4, 789 ELM ST` → 4 gets grabbed first, but 789 is the anchor
- `SUITE 200, 1400 INDEPENDENCE AVE` → 200 is the suite, 1400 is the anchor
- `123A OAK AVE` → strip the alpha suffix, anchor is 123

The correct logic (`extract_street_number_v2`):
1. Detect and null-out non-physical addresses: PO Box, Post Office, Rural Route, RR #, HC #
2. Strip unit designators (APT, APARTMENT, STE, SUITE, UNIT, #, LOT, BLDG, BUILDING, FL, FLOOR)
   and everything after them — this eliminates the apartment number from contention
3. Apply `\b(\d{1,5})[A-Z]?\b` to what remains — first match is the house number
4. Comma fallback: if the prefix before unit stripping is empty (e.g. `SUITE 200, 1400 INDEPENDENCE`),
   walk comma-separated segments from the end and apply the same logic per segment

### Per-Source Address Fields
| Source | Address Field | Special Rule |
|--------|--------------|--------------|
| `public.nc_voters` | `res_street_address` | Parse with v2 |
| `public.nc_datatrust` | `regaddressnumber` or `registrationaddr1` | Use `regaddressnumber` directly if present; parse only as fallback |
| `public.nc_boe_donations_raw` | `street_line_1` | Parse with v2 |
| `public.fec_donations` | `contributor_street_1` | Parse with v2 |

### The Three Tiers (Critical — Do Not Collapse)
- **Tier 1 (this CSV job):** Exact dedup_key match — `LASTNAME|STREETNUMBER|ZIP5`
- **Tier 2 (match layer):** street_number + zip match, last_name Levenshtein distance ≤ 2
- **Tier 3 (match layer):** street_number + zip + first_name soundex match

Tier 2 and 3 are NOT in the CSV normalization script. They live in the SQL match layer.
Do not put fuzzy logic in the Python pipeline.

---

## THE NCBOE VOTER FILE PIPELINE — What Cursor Is Building Tonight

### Mission
Download the fresh NCBOE statewide voter file, normalize it, extract address numbers,
build dedup keys, and stage for upload to `public.nc_voters`.

### Source
- Voter file: `https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvoter_Statewide.zip`
- Voter history: `https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvhis_Statewide.zip`
- Format: pipe-delimited (`|`), Latin-1 encoding, 67 columns
- Expected rows: 8,500,000–9,500,000

### Key Name Normalization Rules
1. Middle initial bleed: if `last_name` ends in a single letter AND `middle_name` is blank,
   strip that letter from `last_name` and put it in `middle_name`
2. Display names: add `display_first_name`, `display_last_name`, `display_full_name` in Title Case
3. Prefix assignment from `name_suffix_lbl`: MD/DR → `Dr.`, REV → `Rev.`, HON → `Hon.`
4. Default prefix from `gender_code`: M → `Mr.`, F → `Ms.`, blank/U → NULL
5. **"Ed" is NEVER mapped to "Edward"** — ever, in any system

### Output Columns (added to the 67 original)
| Column | Value |
|--------|-------|
| `street_number` | Extracted via `extract_street_number_v2` |
| `display_first_name` | Title Case |
| `display_last_name` | Title Case |
| `display_full_name` | Title Case full name |
| `prefix` | Mr./Ms./Dr./Rev./Hon. or NULL |
| `registr_dt_clean` | Standardized to YYYY-MM-DD |
| `dedup_key` | `UPPER(last_name)\|COALESCE(street_number,'')\|LEFT(zip_code,5)` |

### Output Files
- `~/broyhillgop/data/ncboe/cleaned/ncvoter_clean.csv` — UTF-8, all 67 + 7 new columns
- `~/broyhillgop/data/ncboe/cleaned/validation_report.txt` — row counts, null counts, bad dates

### Sacred Table Rules — CRITICAL
- `public.nc_voters` (9,079,672 rows) is a SACRED table — DO NOT TOUCH, ALTER, or TRUNCATE
- The cleaned CSV is staging output only — it does NOT go directly into Supabase tonight
- Any upload to Supabase requires explicit authorization from Ed: "I authorize this action"

---

## THE 7-PASS DONOR ROLLUP — The End Goal

The cleaned voter file feeds the DataTrust-side of Pass 1 in the 7-Pass Rollup
(see `sessions/2026-03-31_DONOR_ROLLUP_CURSOR_BRIEF.md` for full SQL).

| Pass | Anchor | Confidence |
|------|--------|------------|
| Pass 1 | Street number + zip5 + last prefix | 97% |
| Pass 2 | voter_ncid exact bridge | 100% |
| Pass 3 | Employer + SIC + last prefix | 94% |
| Pass 4 | Federal candidate cross-reference | 98% |
| Pass 5 | Committee loyalty fingerprint | 96% |
| Pass 6 | Canonical first name / nickname normalization | 90% |
| Pass 7 | Last + first + zip recency scan | 85% |

**The canary before any merge executes:**
Ed Broyhill — 525 N Hawthorne, 27104 — all 32+ name variants must resolve to ONE person_id.
If any variant maps to a different person_id: STOP and report before proceeding.

---

## PENDING WORK AS OF APRIL 10, 2026 2:29 AM

### Cursor (In Progress)
- [ ] Finish downloading `ncvoter_Statewide.zip` (~9M rows)
- [ ] Run normalization pipeline with `extract_street_number_v2` (comma fallback version)
- [ ] Produce `ncvoter_clean.csv` + `validation_report.txt`
- [ ] Report validation results to Ed before any Supabase upload

### Ed Must Authorize (Blocked)
- [ ] TRUNCATE `public.nc_boe_donations_raw` + reload 338,223 rows from backup
  - Requires exact phrase: **"I authorize this action"**
- [ ] Any upload of ncvoter_clean.csv to Supabase

### Urgent (Time-Critical)
- [ ] DataTrust token expires **April 10, 2026** — contact Zack Imel (RNC Digital Director)
- [ ] Rotate DB password (compromised) at Supabase dashboard
- [ ] Rotate FEC API key (compromised) at api.data.gov

---

*Written by Perplexity | April 10, 2026 2:29 AM EDT*
*Session transcript capturing April 9–10 work — what was lost and what the plan is*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
