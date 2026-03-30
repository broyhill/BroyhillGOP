# Cursor Briefing — fix_08: Donor Identity Resolution & contacts Population
**Project:** BroyhillGOP-Claude | Supabase ID: `isbgjpnbocdkeslofota`
**Date:** 2026-03-28
**Prepared by:** Perplexity Computer
**Mode:** PLAN MODE FIRST — do not write any SQL until the plan is reviewed and approved

---

## Your Instructions

1. Read this entire document before doing anything
2. Produce a complete execution plan — step by step, table by table
3. Do NOT write any SQL yet — plan only
4. After Ed approves the plan, switch to Agent mode for execution
5. Execute one step at a time, paste validation output back to Ed after each step
6. Wait for authorization before proceeding to each next step

---

## Context

fix_01 through fix_07 are fully complete. The database is clean. This is the
first constructive operation — populating `contacts`, the master unified identity
hub, currently at 0 rows.

The goal: take every individual donor across all source tables, deduplicate them
into a single person record anchored by `rncid` (the RNC's deduplicated voter ID),
and insert one row per unique person into `contacts`.

---

## Sacred Tables — DO NOT TOUCH

These tables must never be modified by fix_08 or any sub-step:
- `nc_voters` (9,082,810 rows)
- `nc_datatrust` (7,655,593 rows)
- `rnc_voter_staging` (7,708,542 rows)
- `person_source_links` (1,846,282 rows)

---

## Source Tables (donor data)

| Table | Rows | Key name fields | Has rncid? |
|---|---|---|---|
| `donor_voter_links` | 220,964 | donor_id → source table | YES — 220,127 rows |
| `nc_donor_summary` | 195,317 | norm_last, norm_first, zip5 | NO |
| `fec_donations` | 2,591,933 | contributor_last, contributor_first, contributor_zip5 | NO |
| `winred_donors` | 194,279 | address fields | NO |
| `nc_boe_donations_raw` | 625,897 | parsed_last, parsed_first, norm_zip5 | PARTIAL (rncid col exists) |

## Target Tables

| Table | Rows now | Purpose |
|---|---|---|
| `contacts` | 0 | Master unified identity hub — one row per person |
| `person_source_links` | 1,846,282 | Links each contact_id to every source record |

---

## Key Architecture Decisions (already approved by Ed)

### 1. rncid is the deduplication key
One rncid = one person. Period. If multiple donor records share an rncid,
they all collapse to ONE contacts row. Transaction history goes to
person_source_links, not contacts.

### 2. Name source priority
When rncid resolves to nc_datatrust, use nc_datatrust name fields as the
canonical name. Never overwrite nc_datatrust names with donor file names.
Donor file names are only used when no rncid match exists.

### 3. Name storage format
All caps internally. Title case rendered at query time via INITCAP().
Never store title case — it causes matching bugs.

### 4. Individual donors only — no PACs or committees
Filter fec_donations to receipt_type IN ('15','15E','15J') only.
All other receipt types are committee-to-committee transfers — exclude.

### 5. Address matching — use BOTH addresses in nc_datatrust
Join on regzip5 (voter registration address) OR mailzip5 (mailing address).
Donors often use business or mailing addresses on FEC filings that differ
from their voter registration address. Using both addresses significantly
improves match rate.

### 6. Employer zip as Tier 3 match
employer_sic_master (62,100 rows) maps normalized employer names to zip codes.
Use employer_normalized + employer zip for donors who used a business address
and failed Tiers 1 and 2.

### 7. Confidence scoring
Every match written to person_source_links gets a match_confidence score
and an address_type flag. Matches below 0.75 are flagged for review.

---

## Pre-Flight Steps (DDL only — safe, non-destructive)

### Pre-Step A — Add honorific column to contacts
```sql
ALTER TABLE contacts
  ADD COLUMN IF NOT EXISTS honorific VARCHAR;

COMMENT ON COLUMN contacts.honorific IS
  'Official courtesy title for elected/appointed officials.
   e.g. ''The Honorable'', ''Judge'', ''Sheriff'', ''Commissioner'', ''Mayor''.
   Separate from prefix (social title: Mr/Mrs/Dr) and suffix (generational: Jr/III).
   Added fix_08 2026-03-28.';
```

### Pre-Step B — Fix empty-string rncid in donor_voter_links
358 rows have rncid = '' (empty string) instead of NULL. These are match
pipeline failures. Normalize to NULL before any join.
```sql
-- Diagnostic first:
SELECT COUNT(*) FROM donor_voter_links WHERE rncid = '';
-- Expected: ~358

-- Fix:
UPDATE donor_voter_links SET rncid = NULL WHERE rncid = '';
```

### Pre-Step C — Add norm columns to nc_datatrust (if not present)
Check first — these may already exist. Only add if missing.

CRITICAL: Address numbers must be classified by type before extraction.
Never match a PO box number against a house number — they are different
addresses. A donor using PO Box 4521 and a voter at 123 Oak St should NOT
match on address number even if zip and last name match.

Address types:
- 'street'      — leading digit, e.g. '123 Oak St' → extract '123'
- 'po_box'      — PO BOX pattern → extract box number only
- 'rural_route' — RR or HC prefix → NULL (unreliable for matching)
- 'unknown'     — anything else → NULL

```sql
-- Check what already exists:
SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='nc_datatrust'
AND column_name IN ('norm_first','norm_last','norm_zip5','addr_type','norm_street_num');

-- Add only if missing (will take 2-5 min on 7.6M rows):
ALTER TABLE nc_datatrust
  ADD COLUMN IF NOT EXISTS norm_first TEXT
    GENERATED ALWAYS AS (UPPER(TRIM(firstname))) STORED,
  ADD COLUMN IF NOT EXISTS norm_last TEXT
    GENERATED ALWAYS AS (UPPER(TRIM(lastname))) STORED,
  ADD COLUMN IF NOT EXISTS norm_zip5 TEXT
    GENERATED ALWAYS AS (LEFT(regzip5,5)) STORED,
  ADD COLUMN IF NOT EXISTS addr_type TEXT
    GENERATED ALWAYS AS (
      CASE
        WHEN registrationaddr1 ~* '^\s*P\.?O\.?\s*BOX' THEN 'po_box'
        WHEN registrationaddr1 ~* '^\s*R\.?R\.?\s*\d'  THEN 'rural_route'
        WHEN registrationaddr1 ~* '^\s*HC\s*\d'        THEN 'highway_contract'
        WHEN registrationaddr1 ~* '^\d'                 THEN 'street'
        ELSE 'unknown'
      END
    ) STORED,
  ADD COLUMN IF NOT EXISTS norm_street_num TEXT
    GENERATED ALWAYS AS (
      CASE
        WHEN registrationaddr1 ~* '^\s*P\.?O\.?\s*BOX'
          THEN REGEXP_REPLACE(registrationaddr1, '.*BOX\s*(\d+).*', '\1', 'i')
        WHEN registrationaddr1 ~* '^\d'
          THEN REGEXP_REPLACE(registrationaddr1, '^(\d+).*', '\1')
        ELSE NULL
      END
    ) STORED;

-- Index after population:
CREATE INDEX IF NOT EXISTS idx_nc_datatrust_norm_match
  ON nc_datatrust(norm_last, norm_first, norm_zip5);
CREATE INDEX IF NOT EXISTS idx_nc_datatrust_mailzip5
  ON nc_datatrust(norm_last, norm_first, mailzip5);
CREATE INDEX IF NOT EXISTS idx_nc_datatrust_addr_type
  ON nc_datatrust(addr_type, norm_street_num);
```

### Pre-Step D — Create v_individual_donations view
```sql
CREATE OR REPLACE VIEW v_individual_donations AS
SELECT fd.*
FROM fec_donations fd
WHERE fd.receipt_type IN ('15', '15E', '15J')
  AND (
    EXISTS (
      SELECT 1 FROM fec_committees fc
      WHERE fc.committee_id = fd.committee_id
      AND fc.designation IN ('H','S','P','U')
    )
    OR NOT EXISTS (
      SELECT 1 FROM fec_committees fc
      WHERE fc.committee_id = fd.committee_id
    )
  );

-- Verify row count (expected ~2,388,256):
SELECT COUNT(*) FROM v_individual_donations;
```

### Pre-Step E — Flag organizations in nc_boe_donations_raw
```sql
-- Diagnostic first:
SELECT COUNT(*) FROM nc_boe_donations_raw
WHERE donor_name ~* '(LLC|INC\b|CORP|PAC\b|COMMITTEE|ASSOCIATION|FUND\b|
                       TRUST\b|COMPANY|LLP|PLC\b|GROUP\b|FOUNDATION|
                       AUTHORITY|COUNCIL|DEPARTMENT|UNION|COALITION)';

-- Flag:
UPDATE nc_boe_donations_raw
SET is_organization = true
WHERE donor_name ~* '(LLC|INC\b|CORP|PAC\b|COMMITTEE|ASSOCIATION|FUND\b|
                       TRUST\b|COMPANY|LLP|PLC\b|GROUP\b|FOUNDATION|
                       AUTHORITY|COUNCIL|DEPARTMENT|UNION|COALITION)'
AND (is_organization IS NULL OR is_organization = false);
```

### Pre-Step F — Fix suffix-as-last-name in nc_boe_donations_raw
```sql
-- Diagnostic:
SELECT COUNT(*) FROM nc_boe_donations_raw
WHERE parsed_last IN ('JR','SR','JR.','SR.','II','III','IV','V','MD','PHD','ESQ');

-- Fix: move suffix to parsed_suffix, re-extract real last name from donor_name
UPDATE nc_boe_donations_raw
SET
  parsed_suffix = parsed_last,
  parsed_last = UPPER(TRIM(
    REGEXP_REPLACE(
      REGEXP_REPLACE(donor_name,
        '\s+(JR\.?|SR\.?|II|III|IV|V|MD|PHD|ESQ)$', '', 'i'),
      '^.*\s+', ''  -- take last word after stripping suffix
    )
  ))
WHERE parsed_last ~* '^(JR\.?|SR\.?|II|III|IV|V|MD|PHD|ESQ)$'
AND is_organization = false;
```

---

## Main Steps

### Step 1 — Populate contacts: Tier 1 (rncid direct, ~93K rows)

Source: `donor_voter_links` (live links only, is_orphaned=false) →
        `nc_datatrust` (via rncid)

For each distinct rncid in live donor_voter_links, insert ONE row into
contacts using nc_datatrust as the name/address source.

Key field mappings from nc_datatrust → contacts:
- firstname → first_name (UPPER TRIM)
- lastname → last_name (UPPER TRIM)
- middlename → middle_name
- namesuffix → suffix
- nameprefix → prefix
- registrationaddr1 → address_line1
- regzip5 → zip_code
- rncid → voter_id (store rncid here as the golden key)
- statevoterid → custom_fields jsonb (store ncid/sboe id)
- regzip5 + mailzip5 → zip_code primary, mailzip5 in custom_fields
- source = 'nc_datatrust'
- source_detail = 'rncid_direct_via_donor_voter_links'
- primary_type = 'donor'
- contact_types = '["donor"]'
- acquisition_date = CURRENT_DATE

After INSERT, write to person_source_links:
- person_id = new contact_id
- source_table = 'donor_voter_links'
- source_key = donor_voter_links.donor_id
- match_method = 'rncid_direct'
- match_confidence = 1.00

Validation: SELECT COUNT(*) FROM contacts; -- Expected ~82K-93K
(distinct rncids only — multiple donor_ids per rncid collapse to one)

### Step 2 — Populate contacts: Tier 2 (name+zip match, nc_donor_summary)

For rows in nc_donor_summary NOT already matched via rncid in Step 1:
Match norm_last + norm_first + zip5 against nc_datatrust
on norm_last + norm_first + (norm_zip5 OR mailzip5).

- Tier 2a (regzip5 match): match_confidence = 0.95, address_type='voter_reg'
- Tier 2b (mailzip5 match): match_confidence = 0.92, address_type='mailing'

For matched rows: INSERT new contacts row (if rncid not already in contacts),
write to person_source_links.
For unmatched rows: INSERT contacts row using donor file name/address,
voter_id = NULL, source = 'nc_donor_summary', match_confidence = NULL.

### Step 3 — Populate contacts: Tier 2 (name+zip match, v_individual_donations)

Same pattern as Step 2 but sourced from v_individual_donations.
Use parsed name fields (see Pre-Step F logic for fec_donations):
  - Strip suffix from contributor_last before matching
  - Use contributor_zip5

- Tier 2a: norm_last + norm_first + regzip5, confidence 0.95
- Tier 2b: norm_last + norm_first + mailzip5, confidence 0.92

### Step 4 — Populate contacts: Tier 3 (employer zip match)

For donors still unmatched after Steps 1-3:
Join employer_normalized → employer_sic_master → get employer zip
Match norm_last + norm_first + employer_zip against nc_datatrust.
match_confidence = 0.80, address_type = 'employer'

### Step 5 — Populate contacts: Tier 3b (address number + last + zip)

For donors still unmatched:
Match norm_last + norm_zip5 + norm_street_num against nc_datatrust.

CRITICAL — address type must match:
- Only match street number to street number (addr_type = 'street')
- Only match PO box number to PO box number (addr_type = 'po_box')
- Never cross-match street vs PO box — different address types
- rural_route / highway_contract / unknown → skip address number matching,
  fall through to Tier 4

Confidence by address type:
- street match:  match_confidence = 0.88, address_type = 'voter_reg'
- po_box match:  match_confidence = 0.82, address_type = 'po_box'
  (lower because PO boxes are shared and less personally identifying)

### Step 6 — Populate contacts: Unmatched residual

Donors that failed all tiers: INSERT to contacts with donor file data,
voter_id = NULL, match_confidence = NULL,
tags = '["unmatched_donor"]', requires_review flag in custom_fields.

### Step 7 — Final validation

```sql
-- Total contacts populated
SELECT COUNT(*) AS total FROM contacts;

-- Breakdown by source
SELECT source, COUNT(*) AS cnt FROM contacts GROUP BY source ORDER BY cnt DESC;

-- Match confidence distribution
SELECT
  CASE
    WHEN mc = 1.00 THEN 'Tier 1 — rncid direct'
    WHEN mc >= 0.90 THEN 'Tier 2 — name+zip'
    WHEN mc >= 0.75 THEN 'Tier 3 — employer/house'
    ELSE 'Unmatched'
  END AS tier,
  COUNT(*) AS cnt
FROM (
  SELECT MAX(match_confidence) AS mc
  FROM person_source_links psl
  JOIN contacts c ON psl.person_id::text = c.contact_id::text
  GROUP BY c.contact_id
) sub
GROUP BY 1 ORDER BY 2 DESC;

-- Confirm no org names leaked through
SELECT COUNT(*) FROM contacts
WHERE last_name IN ('LLC','INC','CORP','ASSOCIATION','FOUNDATION','COMMITTEE');

-- Confirm honorific column exists
SELECT column_name FROM information_schema.columns
WHERE table_name='contacts' AND column_name='honorific';
```

---

## Rollback

If any step produces unexpected results:
```sql
-- Full rollback of contacts population
TRUNCATE TABLE contacts;

-- Remove only person_source_links rows added by fix_08
DELETE FROM person_source_links
WHERE linked_at >= '2026-03-28'
AND match_method IN (
  'rncid_direct','norm_last_first_regzip5','norm_last_first_mailzip5',
  'employer_zip','house_num_last_zip','unmatched_donor'
);
```

---

## Rules

- Sacred tables (nc_voters, nc_datatrust, rnc_voter_staging, person_source_links) are READ ONLY
- One contacts row per distinct rncid — never insert duplicates
- Always run diagnostic SELECT before any UPDATE or INSERT
- Paste full validation output after each step — Ed verifies before next step
- If validation fails expected thresholds — STOP and report
- Do not uncomment any commented-out destructive SQL without explicit "I authorize this action" from Ed
