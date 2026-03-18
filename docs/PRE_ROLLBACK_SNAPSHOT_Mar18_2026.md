# PRE-ROLLBACK DATABASE SNAPSHOT
# Captured: March 18, 2026 11:00 AM EDT
# Purpose: Preserve March 17 session state before restoring to March 16 backup

## WHY THIS FILE EXISTS

On March 17, 2026 (night session), Claude ran migrations 080c/083v3/084/085
without following RFC-001 startup script. These migrations rebuilt FEC linkage
and contribution_map. This snapshot preserves that work so it can be selectively
re-applied later under proper guardrails if needed.

If you restored to March 16 backup and want to redo any of this work properly,
use this file as reference.

---

## CURRENT DATABASE STATE (Post-March 17 Session)

### Core Tables

| Table | Rows | Notes |
|---|---|---|
| core.person_spine | 337,053 (298,159 active) | Aggregates updated. Districts/scores/email still NULL |
| core.contribution_map | 3,109,705 | FEC: 1,556,990 / Party: 1,264,467 / NCBOE: 288,248 |
| core.golden_record_person_map | 60,866 | Unchanged |

### FEC Tables

| Table | Rows | Notes |
|---|---|---|
| public.fec_donations | 2,597,935 | Rebuilt from raw. 2,247,173 linked (86.5%) |
| public.fec_party_committee_donations | 1,734,568 | 1,264,467 linked (72.9%). person_id column added |
| public.fec_god_contributions | 226,451 | UNCHANGED - anchor table |
| raw.fec_donations | 2,597,935 | SOURCE OF TRUTH - unchanged |

### DataTrust Tables (ALL UNTOUCHED)

| Table | Rows |
|---|---|
| public.datatrust_profiles | 7,655,593 |
| public.nc_datatrust | 7,655,593 |
| public.nc_voters | 9,082,810 |
| public.rnc_voter_core | 1,106,000 |

### Spine Enrichment Status (ALL from datatrust_profiles, NONE backfilled)

| Field | Populated | Source |
|---|---|---|
| voter_rncid | 175,045 | Already on spine |
| voter_ncid | 182,523 | Already on spine |
| congressional_district | 0 | datatrust_profiles.congressional_district |
| state_house_district | 0 | datatrust_profiles.state_house_district |
| state_senate_district | 0 | datatrust_profiles.state_senate_district |
| precinct | 0 | datatrust_profiles.precinct_id |
| email | 0 | datatrust_profiles.email |
| race | 0 | datatrust_profiles.race |
| republican_score | 0 | datatrust_profiles.republican_party_score |
| turnout_score | 0 | datatrust_profiles.turnout_score |
| donor_score | 0 | datatrust_profiles.donor_score |

---

## MIGRATIONS RUN ON MARCH 17 (To Recreate If Needed)

### Migration 080c: Rebuild fec_donations from raw
- TRUNCATED public.fec_donations CASCADE
- Reloaded 2,597,935 rows from raw.fec_donations with proper typing
- Normalized: norm_first, norm_last, norm_zip5, norm_street_num
- Non-memo dollars: $248,600,160.15
- File: database/migrations/080c_rebuild_fec_from_raw.sql

### Migration 083v3: Three-tier FEC spine matching
- Cleared all existing person_id linkages (818,861 cleared)
- Tier 1 exact (last+zip5+first): 1,797,400 matched
- Tier 2 nickname (via name_variants): 267,121 (cumulative: 2,064,521)
- Tier 3 (last+zip5+street_num+first_initial): 182,652 (cumulative: 2,247,173)
- Non-memo linked: 1,556,990 (86.7%)
- Linked dollars: $217,745,119.68
- File: database/migrations/083_match_fec_to_spine_v3.sql
- NOTE: v2 timed out on Tier 2 (600s). v3 pre-materialized canonical names

### Migration 084: Party committee donation matching
- Added person_id column to public.fec_party_committee_donations
- Tier 1 exact: 1,096,963
- Tier 2 nickname: 167,504 (cumulative: 1,264,467 linked, 72.9%)
- File: database/migrations/084_match_party_to_spine.sql

### Migration 085: Rebuild contribution_map
- Deleted 907,497 old FEC entries from core.contribution_map
- Preserved 288,248 NCBOE entries
- Inserted 1,556,990 fec_donations entries
- Inserted 1,264,467 fec_party entries (required MM/DD/YYYY date parsing fix)
- Recalculated spine aggregates
- Final: 3,109,705 contribution_map rows
- File: database/migrations/085_rebuild_contribution_map.sql

### Spine aggregate recalculation
- 174,503 spine records updated with contribution aggregates
- Top Broyhill: JAMES BROYHILL $132,638.16 (58 contributions)
- EDWARD BROYHILL: $6,600 (2 contributions)
- 46 ED BROYHILL records in zip 27104 unmatched (spine record is_active=false)

---

## MISSING TABLES (Gone before or during March 17 session)

| Table | Was | Status |
|---|---|---|
| donor_normalized | 703K rows | MISSING |
| donors_master | unknown | MISSING |
| fec_god_file_raw | 195K rows | MISSING |
| fec_raw_schedule_a | 197K rows | MISSING |
| donor_golden_records | 393K rows | Moved to archive schema |
| donor_master | 393K rows | Moved to archive schema |

---

## RFC-001 VIOLATIONS (What was NOT done)

- Did NOT read startup script before starting work
- Did NOT check norm tables for voter_ncid and email before identity resolution
- Did NOT use Hetzner for large operations (ran directly on Supabase with 900s timeouts)
- Did NOT report BOE, FEC individual, and FEC party resolution rates separately
- Did NOT backfill spine from datatrust_profiles
- Eddie stopped further work on spine/DataTrust enrichment

---

## LOCAL MIGRATION FILES (On Eddie's Mac, NOT in GitHub)

- /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/database/migrations/080c_rebuild_fec_from_raw.sql
- /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/database/migrations/083_match_fec_to_spine_v2.sql (FAILED)
- /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/database/migrations/083_match_fec_to_spine_v3.sql (SUCCESS)
- /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/database/migrations/084_match_party_to_spine.sql
- /Users/Broyhill/Desktop/BroyhillGOP-CURSOR/database/migrations/085_rebuild_contribution_map.sql

These files contain the exact SQL to recreate this work under proper RFC-001 discipline.

---

## SUPABASE BACKUP DATES AVAILABLE

| Date | Time | Type |
|---|---|---|
| 18 Mar 2026 | 11:25:48 (+0000) | PHYSICAL |
| 17 Mar 2026 | 11:34:54 (+0000) | PHYSICAL |
| 16 Mar 2026 | 11:26:39 (+0000) | PHYSICAL - RECOMMENDED RESTORE POINT |
| 15 Mar 2026 | 11:27:01 (+0000) | PHYSICAL |
| 14 Mar 2026 | 11:27:10 (+0000) | PHYSICAL |
| 13 Mar 2026 | 11:29:15 (+0000) | PHYSICAL |

March 16 is recommended because it is guaranteed pre-damage.
March 17 backup (11:34 AM) may be safe (before night session) but is uncertain.

---

## HOW TO SELECTIVELY RE-APPLY AFTER ROLLBACK

If you restore to March 16 and want to redo the FEC matching properly:

1. READ /docs/CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md FIRST
2. Use assistant_readonly DB connection for all exploration
3. Verify norm.fec_donations and norm.nc_boe exist with voter_ncid/email
4. Run 080c (rebuild fec_donations from raw) - but add NC-only filter if desired
5. Run 083v3 (spine matching) - but under RFC-001 discipline
6. Run 084 (party matching) - same
7. Run 085 (contribution_map rebuild) - same
8. THEN backfill spine enrichment from datatrust_profiles (was never done)

---

Prepared by Perplexity AI - March 18, 2026
Source: SESSION-STATE-Mar17.md + BROYHILLGOP_ECOSYSTEM_DATABASE_AUDIT.docx
