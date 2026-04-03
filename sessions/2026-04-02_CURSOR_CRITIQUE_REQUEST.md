# Cursor Critique Request — COMPLETE_DEDUP_V3.sql

**MANDATORY:** Read `sessions/SESSION_START_READ_ME_FIRST.md` and `sessions/PERPLEXITY_HIGHLIGHTS.md` before reviewing.

**Date:** 2026-04-02
**Author:** Perplexity
**File to review:** `sessions/2026-04-02_COMPLETE_DEDUP_V3.sql` (691 lines, 27 KB)

---

## What This Is

Perplexity wrote the complete deduplication logic for core.person_spine incorporating all of Ed's dedup principles from tonight's session. It covers:

- Schema additions (12 new columns on person_spine)
- Enrichment from nc_voters (primary) and nc_datatrust (fallback)
- Record quality classification (PRETTY vs UGLY)
- Best employer backward scan (2026→2015, skipping RETIRED)
- Preferred name derivation from donation frequency
- Address number parsing (street vs PO Box)
- 3 blocklist passes (suffix conflict, birth year gap, middle name conflict)
- 7 merge passes within address blocks + cross-address employer match
- Safety canaries (Broyhill, Art Pope)

---

## What I Need From You

**Critique this SQL for correctness and safety.** Specifically:

### 1. COLUMN BLEED CHECK (P0 — highest priority)

**BACKGROUND:** The last time we ran dedup instructions, an UPDATE statement's SET clause bled one column's data into another column and deleted thousands of records from a column's data. This happened because a compound UPDATE touched multiple columns in one statement and the JOIN produced unexpected matches.

**CHECK EACH UPDATE STATEMENT FOR:**
- Does the SET clause touch more than one column? (Two exceptions exist in Phase 1I for addr_number + addr_type which are always set together from the same source — review whether these should be split)
- Could the FROM/JOIN clause match MORE rows than intended? (e.g., a JOIN on name+zip that matches multiple nc_voters rows and nondeterministically picks one)
- Could a NULL in the JOIN condition cause unexpected matches?
- Is there a WHERE clause that properly limits the update to only rows that NEED updating?
- Could the UPDATE set a column to NULL or empty when it previously had data? (i.e., does COALESCE protect existing values?)

### 2. JOIN AMBIGUITY CHECK

For every UPDATE with a FROM/JOIN:
- Could the JOIN produce multiple matches for a single spine row? If yes, which row wins? Is that deterministic?
- Specifically check: `nc_voters.ncid` should be unique — is it? `nc_datatrust.rncid` should be unique — is it? If not, the UPDATEs will produce nondeterministic results.

### 3. MERGE PASS LOGIC CHECK

For each of the 7 merge passes:
- Could any pass produce a merge candidate that should have been caught by the blocklist? (i.e., is the `NOT staging.is_blocked()` check correct for that pass's join pattern?)
- Pass 3 (first name = middle name): could this produce false positives? Example: JAMES EARL JONES and EARL JAMES JONES at the same address — are these the same person or different?
- Pass 4 (initials): is LENGTH(norm_first) = 1 the right test, or could norm_first be 'JR' (2 chars) for someone who filed with initials?
- Pass 5 (employer cross-address): LEFT(best_employer, 10) comparison — is 10 characters enough? "VARIETY WH" matches "VARIETY WHOLESALERS" but also "VARIETY WHEATGRASS" (if that existed). Should this be longer?

### 4. RECORD QUALITY CLASSIFICATION

- Is the PRETTY/UGLY split correct? Are there records that would be classified UGLY that should be PRETTY, or vice versa?
- Should phone number be included in the PRETTY criteria? (Currently only voter_ncid, employer, or email qualify)

### 5. PREFERRED NAME DERIVATION (Phase 4)

- The subquery is complex. Walk through it step by step and confirm it actually returns the most frequently used first name per person, not something else.
- Edge case: what if a person has equal counts for two names (e.g., ED used 10 times and EDWARD used 10 times)?

### 6. BEST EMPLOYER BACKWARD SCAN (Phase 3)

- Does `array_agg(employer_name ORDER BY date_occurred DESC)[1]` correctly return the MOST RECENT non-retired employer? Or could NULL dates sort unexpectedly?
- The exclusion list for useless employers — is it complete? What about 'UNEMPLOYED', 'STUDENT', 'HOUSEWIFE', 'VOLUNTEER'?

### 7. ADDRESS PARSING (Phase 1I)

- The regex `'^\s*(\d+).*'` extracts leading digits. But what about `202B ALLENTON CT` (from nc_voters data)? The `B` suffix gets stripped. Is that correct for dedup purposes, or should `202B` be kept as-is to distinguish from `202`?
- Two separate UPDATE statements for ST and PO — could a row match BOTH patterns and get addr_type set to PO after being set to ST? (i.e., execution order dependency)

---

## DO NOT

- **Do NOT execute any of this SQL.** Review only.
- **Do NOT rewrite the SQL.** Reply with specific line-level corrections and explanations.
- **Do NOT minimize risks.** If something could corrupt data, say so clearly.

## REPLY FORMAT

Reply with:
1. A table of issues found: `| Line | Severity (P0/P1/P2) | Issue | Fix |`
2. Confirmation of which statements you reviewed and found safe
3. Any edge cases or scenarios Perplexity may have missed
4. Your overall assessment: SAFE TO RUN / NEEDS FIXES / DANGEROUS

---

*Perplexity generated this for Cursor review. Ed authorized this critique workflow.*
