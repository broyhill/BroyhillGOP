# Canonical Tables Audit — Suspicious References & Fixes

**Context:** Database audit found 4 tables with identical 7.6M row counts; 3 are redundant. Use this doc to find and fix code/docs that reference the wrong tables.

**Architecture:** Raw donation tables are frozen; query via enrichment views. See docs/DATABASE_ARCHITECTURE_RULES.md.

---

## PERPLEXITY AUDIT CONTEXT — Join Paths (Cursor Must Know)

**Critical:** `person_master.ncvoter_ncid` maps to `nc_datatrust` or `nc_voters.ncid` — **NOT** to `core.person_spine`. `core.person_spine` uses `person_id` as its primary key.

**FEC matching join path:** `nc_datatrust.rncid` or `nc_voters.ncid` → voter identity → `core.person_spine.person_id` → golden donor record.

| Table | Rows | Key | Purpose |
|------|------|-----|---------|
| `nc_datatrust` | 7.6M | `rncid` | Canonical voter/DataTrust file (251 cols) |
| `core.person_spine` | 333K | `person_id` | Golden donor master |
| `donor_contribution_map` | 3.1M | `golden_record_id` | Contributions linked to spine; sources: fec_party (2.2M), NC_BOE (683K), fec_god (197K) |
| `nc_voters` | 9M | `ncid` | Raw NC voter file |

- **datatrust_profiles:** 100% redundant subset of nc_datatrust (73 cols vs 251 cols, same 7.6M rows matched by `rncid`).
- **person_master:** Mostly empty — only `ncvoter_ncid` populated; `rnc_rncid` 100% NULL; `golden_record_id` only 0.4% filled.
- **datatrust_matching_procedures.sql:** 20+ references to `datatrust_profiles` — must be rewritten before dropping.

---

## Canonical Tables (Use These)

| Purpose | Canonical Table | Rows | Notes |
|---------|-----------------|------|-------|
| **Voter file (full DataTrust)** | `public.nc_datatrust` | 7.6M | 251 cols, join key `statevoterid` = nc_voters.ncid |
| **Donor identity spine** | `core.person_spine` | 333K | RFC-001 identity layer |
| **Donations (all sources)** | `public.donor_contribution_map` | 3.1M | fec_party, NC_BOE, fec_god |
| **NC raw voters** | `public.nc_voters` | 9M | NC SBOE, join key `ncid` |

---

## Redundant Tables (Do NOT Use — Drop or Archive)

| Table | Status | Action |
|-------|--------|--------|
| `public.datatrust_profiles` | 100% subset of nc_datatrust | **Safe to drop** (6.4 GB) |
| `public.person_master` | Mostly empty shell, ncvoter_ncid only | **Likely safe to drop** (3 GB) — verify no active code first |
| `public.acxiom_consumer_data` | Key format differs, needs column-overlap check | **Investigate before drop** |

---

## Files That Reference Suspicious Tables

### CRITICAL — Code that writes/reads redundant tables

| File | References | Fix |
|------|------------|-----|
| `backend/python/integrations/datatrust_api_client.py` | `datatrust_profiles` (line 444) | Change to `nc_datatrust`; map API columns to nc_datatrust schema (rncid, firstname, lastname, etc.) |

### Docs / Plans — Update to canonical tables

| File | References | Fix |
|------|------------|-----|
| `docs/PERPLEXITY_FEC_DONOR_MATCHING_PLAN.md` | person_master, person_source_links | Use `core.person_spine` + `donor_contribution_map`; match FEC → nc_voters.ncid |
| `docs/NCBOE_TASK1_2_3_REVISED_PLAN.md` | person_master.person_id, fn_match_donor_to_person | Use `core.person_spine` if migrating; else note person_master is deprecated |
| `docs/NCBOE_SCHEMA_REFERENCE.md` | person_master | Add deprecation note; point to core.person_spine |
| `MD FILES/BROYHILLGOP_PLATFORM_BIBLE.md` | datatrust_profiles, state_voter_id | Use nc_datatrust, statevoterid |
| `MD FILES/CROSS_REFERENCE_GAP_ANALYSIS.md` | datatrust_profiles | Use nc_datatrust |
| `MD FILES/Perplexity-E11-Print-Ecosystem-Prompt.md` | person_master, donor_contribution_map | Keep donor_contribution_map; replace person_master with core.person_spine |
| `MD FILES/Perplexity-E11-Print-Ecosystem-Prompt copy.md` | Same | Same |
| `docs/CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md` | person_master, datatrust_profiles, acxiom | Already says preserve nc_datatrust + acxiom; archive datatrust_profiles only |
| `docs/RNC_DATAHUB_CONNECTION.md` | datatrust_profiles | Use nc_datatrust |
| `docs/cursor-ingestion-complete*.md` | person_master | Use core.person_spine |
| `docs/NEXUS_BRAIN_INTEGRATION_SPEC_VOL1 - Google Docs.html` | person_master, acxiom, datatrust | Use nc_datatrust, core.person_spine |
| `pipeline/identity_resolution.py` | person_master (negative ref: "do NOT seed from") | No change — correctly warns against person_master |

### Schema / SQL procedures — need migration to nc_datatrust

| File | References | Fix |
|------|------------|-----|
| `database/schemas/datatrust_complete_schema.sql` | CREATE TABLE datatrust_profiles | Do not run; nc_datatrust is canonical. If new schema needed, extend nc_datatrust. |
| `database/schemas/datatrust_matching_procedures.sql` | 20+ references to datatrust_profiles | Rewrite JOINs to use nc_datatrust; map rnc_id → rncid, state_voter_id → statevoterid. |

---

## Key Column Mappings

### datatrust_profiles → nc_datatrust (for API client migration)

| datatrust_profiles | nc_datatrust | API field |
|--------------------|--------------|-----------|
| state_voter_id | statevoterid | SourceID or JurisdictionVoterID |
| rnc_id | rncid | RNCID |
| first_name | firstname | FirstName |
| last_name | lastname | LastName |
| home_county | countyname | CountyName |
| home_city | regcity | RegistrationCity |
| home_zip | regzip5 | RegistrationZip |

### person_master → core.person_spine

| person_master | core.person_spine |
|---------------|-------------------|
| person_id | person_id |
| ncvoter_ncid | voter_ncid |
| (empty boe_donor_id, fec_contributor_id) | resolved via norm + contribution_map |

---

## Other Suspicious / Strange Files

| File or pattern | Why suspicious |
|-----------------|----------------|
| `cursor-ingestion-complete copy.md`, `cursor-ingestion-complete copy 2.md`, `cursor-ingestion-complete copy 3.md` | Duplicate docs; may drift. Consolidate or delete copies. |
| `Perplexity-E11-Print-Ecosystem-Prompt copy.md` | Duplicate of Perplexity prompt; references person_master. |
| `database/schemas/datatrust_matching_procedures.sql` | Heavy datatrust_profiles usage; procedures will break if table is dropped. |
| `brain_control` schema (220 tables, 183 empty) | AI-scaffolded, never populated. Consider archiving or dropping empty tables. |
| `social_intelligence` schema (96 tables, 80 empty) | Same situation. |
| `scripts/match_ncgop_to_voters.py` | Uses `statevoterid` on staging.ncgop_winred — different table, but naming may confuse. |
| `scripts/build_donor_golden_records.py` | References `statevoterid` in norm/NCGOP context — verify it doesn't assume person_master. |

---

## Summary for Perplexity / Cursor

When executing FEC matching, donor analysis, or identity resolution:

1. **Voter enrichment:** Use `nc_datatrust` (join on `statevoterid` = ncid). Do NOT use `datatrust_profiles`.
2. **Donor identity:** Use `core.person_spine` and `donor_contribution_map`. Do NOT use `person_master` for new logic.
3. **DataTrust API sync:** Update `datatrust_api_client.py` to write to `nc_datatrust` (with column mapping) before dropping `datatrust_profiles`.
