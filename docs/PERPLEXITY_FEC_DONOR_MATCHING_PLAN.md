# Perplexity Task: FEC Donor Matching to NC Voter File

## Objective

Match FEC (federal) campaign donation records to the NC voter file so donors can be linked to voter IDs (ncid) and enriched with DataTrust demographics. This enables unified donor analysis across state (NCBOE) and federal (FEC) giving.

---

## Context

- **BroyhillGOP** is an NC Republican campaign SaaS platform
- **Database**: Supabase PostgreSQL (project: isbgjpnbocdkeslofota)
- **nc_voters**: ~9M NC SBOE voter records, primary key `ncid` (e.g. BR192458)
- **nc_datatrust**: ~7.6M RNC DataTrust records; join `statevoterid` = `nc_voters.ncid`; keyed by `rncid`
- **core.person_spine**: 333K golden donor records, keyed by `person_id` (NOT ncid)
- **donor_contribution_map**: 3.1M contributions linked via `golden_record_id` → spine
- **fec_raw_schedule_a**: ~197K FEC Schedule A (individual contributions) records
- **nc_boe_donations_raw**: ~506K NC state donations, has `voter_ncid` column (partially populated)
- **Current FEC match rate**: 40–50% (weak) — name + zip only, no address-based matching

**Join path to golden donor:** `nc_datatrust.rncid` or `nc_voters.ncid` → voter identity → `core.person_spine.person_id` → `donor_contribution_map.golden_record_id`. See `docs/CANONICAL_TABLES_AUDIT.md`.

---

## Target Outcome

1. Add `voter_ncid` (or equivalent) column to FEC donation table if missing
2. Match FEC contributors to `nc_voters` using best-available fields
3. Populate `voter_ncid` for matched rows
4. Document match rate and strategy

---

## FEC Schema (Key Columns)

From `fec_raw_schedule_a` or `fec_god_contributions`:

| Column | Purpose |
|--------|---------|
| contributor_name | Raw name (e.g. "SMITH, JOHN") |
| contributor_first_name | Parsed first |
| contributor_last_name | Parsed last |
| contributor_street_1 | Street address |
| contributor_city | City |
| contributor_state | State (filter NC) |
| contributor_zip | Zip (5 or 9 digit) |
| contribution_receipt_amount | Donation amount |
| contribution_receipt_date | Date |
| committee_id | Recipient committee |
| candidate_id | Candidate supported |

---

## NC Voter Schema (Key Columns)

From `nc_voters`:

| Column | Purpose |
|--------|---------|
| ncid | PRIMARY KEY, voter ID (e.g. BR192458) |
| last_name | Last name |
| first_name | First name |
| res_street_address | Residential street |
| res_city_desc | City |
| state_cd | State (NC) |
| zip_code | Zip (may include +4) |

---

## Matching Strategy (Tiers)

### Tier 1: Strong match (address + name + zip5)
- `LOWER(TRIM(fec.contributor_last_name))` = `LOWER(TRIM(nv.last_name))`
- `LOWER(TRIM(fec.contributor_first_name))` = `LOWER(TRIM(nv.first_name))`
- `LEFT(fec.contributor_zip, 5)` = `LEFT(nv.zip_code, 5)`
- Address: normalize both, compare street number + street name (fuzzy or substring)

### Tier 2: Name + zip5 + city
- Same name logic
- Zip5 match
- `LOWER(TRIM(fec.contributor_city))` = `LOWER(TRIM(nv.res_city_desc))`

### Tier 3: Name + zip5 only (weak)
- Current fallback
- Higher false-positive risk

### Deduplication
- When multiple nc_voters match, prefer: exact address match > city match > first match by ncid

---

## Implementation Steps

0. **Separate committees from individuals (run before matching)**
   - Run `database/migrations/059_FEC_SEPARATE_COMMITTEES.sql` to move PAC/ORG/committee rows from `norm.fec_individual` to `staging.fec_non_individual_contributions`
   - Committees cannot be matched to nc_voters; leaving them in fec_individual wastes cycles and risks false matches

1. **Verify FEC table schema**
   - Confirm table name: `fec_raw_schedule_a` or `fec_god_contributions`
   - Confirm columns: contributor_first_name, contributor_last_name, contributor_zip, contributor_city, contributor_street_1
   - Add `voter_ncid TEXT` if not present

2. **Filter to NC donors**
   - `contributor_state = 'NC'` or `contributor_state IS NULL` (many FEC records omit state)

3. **Build matching SQL or Python script**
   - Option A: Single SQL UPDATE with JOIN (may be slow on 9M voters)
   - Option B: Python script using pandas/psycopg2, batch by zip5 to limit join size
   - Option C: Use `core.person_spine` or `donor_contribution_map` if FEC already links there
   - **Do NOT use** `person_master` or `person_source_links` — see docs/CANONICAL_TABLES_AUDIT.md

4. **Run match and populate voter_ncid**
   - Update FEC table SET voter_ncid = nc_voters.ncid WHERE match conditions
   - Log match rate: matched / total NC individual contributions

5. **Extend donor analysis view**
   - Add FEC donations to `vw_donor_analysis_consolidated` via UNION or separate join
   - Ensure donor_key handles both NCBOE and FEC sources

---

## Constraints

- **Do NOT** destructively modify nc_voters or nc_datatrust
- **Do NOT** merge or delete golden_records (per RFC-001)
- Prefer non-destructive updates: only ADD voter_ncid to FEC, do not overwrite existing links without review
- Match one FEC row to one ncid when possible; if ambiguous, pick best match by confidence

---

## Success Metrics

- Match rate: aim for 60%+ of NC FEC individual contributions (vs current 40–50%)
- No regression in NCBOE donor analysis
- FEC donors with voter_ncid can be enriched with DataTrust in vw_donor_analysis_consolidated

---

## References in Codebase

- `pipeline/nc_boe_ddl.sql` — NCBOE voter_ncid column pattern
- `pipeline/fec_norm_populate.py` — FEC processing (may have voter_ncid logic)
- `database/migrations/057_DONOR_ANALYSIS_VIEW.sql` — donor analysis view (NCBOE only today)
- `MD FILES/DATABASE-AUDIT-2026-02-22.md` — current schema state
- `docs/CANONICAL_TABLES_AUDIT.md` — **use nc_datatrust, core.person_spine, donor_contribution_map; avoid person_master, datatrust_profiles**

---

## Output for Perplexity

When executing this plan, produce:
1. SQL migration or Python script for FEC → nc_voters matching
2. Brief report: rows processed, rows matched, match rate %
3. Any changes needed to vw_donor_analysis_consolidated to include FEC
