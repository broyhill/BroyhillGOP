# BroyhillGOP SESSION STATE
## Updated: 2026-03-31 11:31 EDT by Perplexity

---

## CRITICAL: READ THIS BEFORE DOING ANYTHING

The old SESSION-STATE.md (dated 2026-03-24) is obsolete. Ignore all numbers and task lists from that version. This is the authoritative current state.

---

## DATABASE: TRUE CURRENT STATE (2026-03-31)

### Core Tables — Verified Row Counts (COUNT(*), not pg_stat estimates)

| Table | Rows | Status |
|-------|------|--------|
| public.contacts | 310,867 | ✅ Primary masterfile |
| public.nc_datatrust | 7,661,978 | ✅ SACRED — do not touch |
| public.fec_donations | 2,591,933 | ✅ NC individual donors, all cycles 2015-2026 |
| public.nc_boe_donations_raw | 282,096 | ✅ Reloaded — individuals only, no PACs/committees |
| public.winred_donors | ~194,278 | ✅ Clean |
| public.nc_donor_summary | 195,317 | ✅ PRESERVED — Letha Davis/Mark file, address reference only |
| public.person_source_links | 2,055,703 | ✅ |
| core.person_spine | 200,383 | ✅ Republican-only ($495M) after fix_10 |
| core.contribution_map | 4,137,549 | ✅ party_flag stamped, 733K rows attributed to candidates |
| core.candidate_committee_map | 3,733 rows | ✅ 99.97% FEC committee coverage (fix_09) |
| candidate_profiles | 3,630 | ✅ All Republican, faction scores |
| staging.nc_voters_fresh | 0 | ⚠️ Table ready, COPY blocked — needs Hetzner SSH key auth |

### SACRED TABLES — DO NOT TOUCH UNDER ANY CIRCUMSTANCES
- `nc_voters`
- `nc_datatrust`
- `rnc_voter_staging`
- `person_source_links` (pre-existing rows)

---

## CONTACTS TABLE — ADDRESS COVERAGE (True Current State)

| Source | Total | Has Address | Missing |
|--------|-------|-------------|---------|
| nc_datatrust | 132,613 | 132,612 | 1 ✅ |
| winred_donors | 38,060 | 38,057 | 3 ✅ |
| fec_donations | 39,024 | 38,285 | 739 ✅ (blank at FEC source) |
| nc_boe_donations_raw | 16,844 | 16,697 | 147 ✅ (blank at BOE source) |
| nc_donor_summary | 84,326 | 0 | 84,326 ❌ ACTIVE WORK ITEM |

**Total missing address_line1: 85,216**
**Root cause: nc_donor_summary was a summary rollup file (from Letha Davis, Oct 2024) with no streets**
**Fix: Match to nc_datatrust by name+zip → pull registration address → staged UPDATE**

---

## CONTACTS TABLE — VOTER_ID (RNCID) COVERAGE

| Source | Total | Has voter_id (RNCID) | Missing |
|--------|-------|----------------------|---------|
| nc_datatrust | 132,613 | 132,613 | 0 ✅ |
| nc_donor_summary | 84,326 | 0 | 84,326 |
| fec_donations | 39,024 | 0 | 39,024 |
| winred_donors | 38,060 | 0 | 38,060 |
| nc_boe_donations_raw | 16,844 | 0 | 16,844 |

**Note:** `contacts.voter_id` stores RNCID (e.g. 24234683774), NOT NC SBOE statevoterid (e.g. AN130350).
`nc_datatrust.statevoterid` contains the NC SBOE voter registration number for every record.

---

## FIXES COMPLETED (fix_01 through fix_11)

| Fix | Description | Status |
|-----|-------------|--------|
| fix_01 | FEC committees party column | ✅ |
| fix_02 | Donor-voter links orphans | ✅ |
| fix_03 | RNC volunteer score backfill | ✅ |
| fix_04 | FEC corrupt dates | ✅ |
| fix_05 | nc_donor_summary dates | ✅ |
| fix_06 | WinRed large amounts | ✅ |
| fix_07 | FEC party committee date cast + table rename | ✅ |
| fix_08 | Contacts masterfile build (310,867 rows) | ✅ |
| fix_09 | Committee-candidate linkage (3,733 rows, 99.97%) | ✅ |
| fix_10 | Republican-only spine totals ($495M) | ✅ |
| fix_11 | FEC address backfill (38,285 contacts fixed) | ✅ |

---

## ACTIVE WORK ITEMS

### fix_12 — Address Enrichment for nc_donor_summary contacts (PENDING)
- 84,326 contacts with zero addresses
- Plan: JOIN contacts (source=nc_donor_summary) → nc_datatrust on norm_last + norm_first + norm_zip5
- Use registration address (registrationaddr1) or mailing address (mailingaddr1)
- **MUST stage first** → show Ed counts → UPDATE only after "I authorize this action"
- Staging table to create: `staging.staging_claude_fix12_ncd_match`

### nc_voters_fresh load (BLOCKED)
- 9,083,727 rows downloaded to /tmp/ncvoter_fresh/ on Hetzner server 5.9.99.109
- staging.nc_voters_fresh table ready (0 rows)
- BLOCKED: SSH password auth fails from cloud environments — needs key-based auth
- Command ready to run (see prior session notes)

### Phase 1-7 Architecture Build (QUEUED for Claude)
- 20+ new tables designed in March 31 master architecture session
- Full spec in: sessions/2026-03-31_MASTER_ARCHITECTURE_SESSION.md
- Has NOT been executed yet — design only
- Start with Phase 1: person_district_map, volunteer_profiles, community_profiles

---

## KEY FACTS / GUARDRAILS

### Authorization Protocol
- Any UPDATE/DELETE on core tables requires exact phrase: **"I authorize this action"**
- TWO PHASE protocol always: DRY RUN showing counts → EXECUTION after authorization
- Fix_07: TWO MANUAL PASSES ONLY rule still applies

### Data Rules
- Ed = ED BROYHILL in all systems — never map to Edward
- No out-of-state candidate donations in individual donor files
- nc_donor_summary: PRESERVE as-is — address reference file, do not delete
- Democratic donations: in archive.democratic_candidate_donor_records (906,609 rows) — preserved

### MAY NOT (Claude guardrails)
- DROP/ALTER tables in core/public/archive/norm/raw/staging/audit schemas
- UPDATE/DELETE from core.person_spine, core.contribution_map, public.contacts,
  public.person_source_links, public.nc_datatrust, public.nc_boe_donations_raw
- Touch views starting with v_individual_donations or v_transactions_with_candidate
- Touch auth tables or RLS

### MAY (Claude guardrails)
- CREATE TEMP TABLEs
- CREATE in staging schema only (names starting staging_claude_)
- INSERT into staging
- SELECT anywhere

---

## INFRASTRUCTURE

| Resource | Value |
|----------|-------|
| Supabase Project | BroyhillGOP-Claude |
| Project ID | isbgjpnbocdkeslofota |
| Region | us-east-1 |
| Postgres | 17.6 |
| Hetzner server 1 | 5.9.99.109 |
| Hetzner server 2 | 144.76.219.24 (needs DataTrust IP whitelist) |
| GitHub | broyhill/BroyhillGOP |

---

## KEY FINANCIAL FIGURES
- Republican spine total: $495,429,453
- Archived Democratic + Unknown: $220,708,080
- Old contaminated total (before fix_10): $726,630,745

---

## PENDING WITH DATATRUST (Danny Gustafson — dgustafson@gop.com)
- Email sent requesting: fresh voter file SAS token, RNCID in API responses,
  IP whitelist for 144.76.219.24, composite key guidance for identity matching
