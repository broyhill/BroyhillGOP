# Session: March 31, 2026 — Master Architecture Session
## Agent: Perplexity AI (lead architect)
## Duration: ~4 hours (10 PM PDT March 30 — 2:48 AM EDT March 31)
## Status: ACTIVE — Implementation queued for Claude

---

## SESSION SUMMARY

Tonight's session was the most comprehensive architecture session to date.
Starting from a database repair question, we built the complete intelligence
and campaign management architecture for BroyhillGOP — covering every
elected office in NC, every special interest, every community type, and
every donor/volunteer segment from federal down to municipal level.

---

## ALL DOCUMENTS CREATED THIS SESSION

All pushed to `docs/` in broyhill/BroyhillGOP:

| File | Description |
|------|-------------|
| `docs/ECOSYSTEM_COMPLETION_TRACKER.md` | 59-ecosystem status, E58 outstanding |
| `docs/COMMITTEE_TAXONOMY.md` | 8-tier committee classification + partisan_lean R/D/N/U |
| `docs/ISSUE_ACTIVIST_MATRIX.md` | 26 conservative issues × activist orgs × office levels |
| `docs/DISTRICT_GEOGRAPHY_ISSUES.md` | Permanent geographic issues per NC region |
| `docs/NC_COMMUNITY_IDENTITY_TAXONOMY.md` | 22 community identity types (beach, mountain, university, hog farm, etc.) |
| `docs/NC_ELECTED_OFFICE_PAC_MAP.md` | Every NC office × special interest PAC map, all levels |
| `docs/ELECTED_OFFICIAL_PROFILE_SPEC.md` | Full profile page spec for every elected official + PAC |
| `docs/POLITICAL_CLOUT_SCORING.md` | 12-dimension clout scoring system + human intelligence layer |
| `docs/AFFINITY_COALITION_GROUPS.md` | "Farmers for Broyhill" etc — 25+ groups, SQL, content strategy |
| `docs/MICROSEGMENT_SIZE_ESTIMATES.md` | All 30 segments with voter/donor/volunteer counts |
| `docs/DATATRUST_ACXIOM_SEGMENT_FIELDS.md` | Exact DataTrust fields for each microsegment |
| `docs/MICROSEGMENT_INFLUENCER_MAP.md` | Per-segment influencer universes + monitoring sources |
| `docs/INFLUENCER_ROI_TRACKING.md` | Referral chains, performance scoring, leaderboard |
| `docs/ECOSYSTEM_NEWSFEED_INTELLIGENCE.md` | E42 feeds per ecosystem + host fundraiser strategy |
| `docs/DONOR_VOLUNTEER_MICROSEGMENT.md` | person_district_map + volunteer_profiles mirror schema |
| `docs/DISTRICT_MICROSEGMENT_RANKING.md` | Dominance rank 1-100 per segment per district |
| `docs/OFFICE_SEGMENT_RELEVANCE_FILTER.md` | PRIMARY/SECONDARY/IRRELEVANT per office type |
| `docs/CONTROL_PANEL_SPEC.md` | Toggle/timer/AI control for segments, issues, persons |
| `docs/NC_ELECTED_OFFICE_PAC_MAP.md` | Updated with local judicial, county, municipal levels |

**Data files pushed:**
| File | Description |
|------|-------------|
| `data/NCGA_GOP_ROSTER.json` | 30 NC Senate R + 70 NC House R confirmed from NCGA website |

**Session notes pushed:**
| File | Description |
|------|-------------|
| `sessions/2026-03-28_repo-audit-ecosystem-consolidation.md` | Repo audit findings |
| `sessions/2026-03-31_MASTER_ARCHITECTURE_SESSION.md` | This file |

---

## DATABASE SCHEMAS DESIGNED THIS SESSION

All new tables to be built by Claude per the master implementation plan (msg #191):

### Phase 1 — Foundation
- `public.person_district_map` — every donor/voter tagged to every district they live in
- `public.volunteer_profiles` — mirrors person_district_map for volunteer tracking
- `public.community_profiles` — NC community identity profiles

### Phase 2 — Microsegment Ranking
- `public.district_microsegment_rankings` — rank 1-100 per segment per district
- `public.office_segment_relevance` — PRIMARY/SECONDARY/IRRELEVANT filter per office type

### Phase 3 — Affinity + Influencer
- `public.affinity_group_templates` — master group definitions
- `public.affinity_groups` — instances per candidate
- `public.affinity_group_members` — who belongs to each group
- `public.influencer_registry` — every person who refers donors
- `public.influencer_segment_map` — influencer × segment assignments
- `public.donor_referral_map` — every referral tracked with full attribution
- `public.influencer_events` — events hosted, content posted

### Phase 4 — Campaign Control Panel
- `public.campaigns` — parent record (needed first)
- `public.campaign_segment_controls` — toggle/mode/intensity/timer per segment
- `public.campaign_issue_controls` — issue alerts + candidate stance
- `public.campaign_person_controls` — person flags + outreach stage
- `public.campaign_timers` — scheduled actions
- `public.campaign_permissions` — candidate/manager/AI permission levels
- `public.conflict_alerts` — auto-detected conflicts

### Phase 5 — Interest Groups + Clout
- Updated `public.committee_registry` — add 20+ new columns
- `public.issue_tags` — 26 conservative issues
- `public.committee_issues` — committee × issue junction
- `public.candidate_issues` — candidate × issue junction
- `public.interest_group_people` — officer/decision-maker profiles
- `public.community_identity_types` — 22 community identity lookups

### Phase 6 — Elected Official Profiles
- Updated `public.candidates` — add bio, social, scorecard columns
- Seed: 30 NC Senate R, 70 NC House R, 14 federal delegation, Council of State

### Phase 7 — District Geography
- `public.district_geography_issues` — permanent geographic issues
- `public.district_candidate_geography` — candidate × geography junction

---

## KEY ARCHITECTURAL DECISIONS MADE TONIGHT

### 1. Three-Layer Microsegment Filter
```
Geography → Office-Type Relevance → Dominance Ranking
```
Boliek in Watauga: 31,000 R+U voters → 700-1,000 relevant to NC Auditor after filter.
Never show hunters to an auditor candidate. Never show CPAs to a school board candidate.

### 2. Candidate Stance Layer (4 values)
- `champion` — actively promote
- `neutral` — no position, don't surface
- `avoiding` — actively dodging, suppress completely
- `conflicted` — pause all automation, flag for candidate

### 3. Person Conflict Flags (9 values)
From `normal` through `vip`, `adversarial`, `conflict_of_interest`, `pending_litigation`.
AI is flag-aware — never contacts DNC/adversarial/litigation persons automatically.

### 4. Manual Priority Override (3 levels)
```
📌 PIN → Manual # → AI Calculated
```
Candidate can boost/suppress any segment. Temporary overrides auto-expire.

### 5. Community Identity × Office Type = Precise Targeting
22 community types (beach town, university town, hog farm, NASCAR, etc.) × office type relevance filter = only relevant content surfaces for each race.

### 6. Host-Based Fundraising > Ask-Based
Top donor as HOST multiplies network (estimated 10x ROI vs direct ask).
E34 Events auto-builds event skeleton when major charitable gift detected.

### 7. DataTrust Coalition IDs Replace All Estimates
`coalitionid_sportsmen`, `coalitionid_veteran`, `coalitionid_2ndamendment`,
`coalitionid_prolife`, `coalitionid_socialconservative`, `coalitionid_fiscalconservative`
— pre-built RNC flags in nc_datatrust replace all size estimates with exact counts.

---

## OPEN ITEMS / TO-DOS

### Immediate (Claude executing now)
- [ ] **NCBOE reload** — `nc_boe_donations_raw` truncated, awaiting load of 2 clean CSVs (msgs 181/183)
- [ ] **DataTrust district analysis** — coalition counts + microsegment CSVs by district via psql (msgs 187/189)
- [ ] **Master implementation plan Phase 0-7** — full build order sent to Claude (msg 191)

### Needs Eddie Approval Before Claude Executes
- [ ] **Phase 2**: Confirm office_segment_relevance matrix before populating (it determines what every candidate sees)
- [ ] **Phase 4**: Review campaign_person_controls relationship_flag values — are these the right categories?
- [ ] **Phase 6**: Confirm Council of State current holders are correctly identified before loading

### Needs Additional Data / Research
- [ ] **E58 — Business Model ecosystem** — 0 code, 0 implementation, needs full build
- [ ] **E56/E57 location** — Python files confirmed at `ecosystems/` root, need to move to `backend/python/ecosystems/` for consistency
- [ ] **NC Dairy Producers Association** — get officer names + contacts for dairy microsegment
- [ ] **NC Sheriffs list** — pull all 100 current sheriffs with party registration for Sheriffs for Broyhill
- [ ] **NC Senate leadership** — pull full leadership roster (only Pro Tem Berger confirmed)
- [ ] **RNC API IP whitelist** — contact dpeletski@gop.com to whitelist Hetzner IPs 5.9.99.109 + 144.76.219.24
- [ ] **RNC scores load** — stalled at 14.4%, resume overnight script
- [ ] **BOE restore** — 132,623 deleted rows in archive.nc_boe_donations_raw_backup — restore after NCBOE reload confirms clean

### Technical Debt
- [ ] `fec_committees.party` column has FEC cycle years instead of party codes — fix from fec_committee_master_staging
- [ ] 5 broken pg_cron jobs — identify and repair or drop
- [ ] `contacts` table empty — identity resolution pipeline never ran
- [ ] `donor_scores` + `donor_propensity_scores` empty — scoring pipeline not built
- [ ] `campaigns` table empty — parent record needed before control panel tables

### Future Sessions
- [ ] Build E58 (Business Model / Candidate Network Data Acquisition)
- [ ] Donor 360 profile page — full card layout from ELECTED_OFFICIAL_PROFILE_SPEC.md
- [ ] Dashboard addiction UI — newsfeed with live CTAs per ecosystem
- [ ] Social media auto-post engine integration with affinity groups
- [ ] RNC API live data integration (pending IP whitelist)

---

## RELAY MESSAGE LOG — TONIGHT'S TASKS TO CLAUDE

| Msg # | Subject | Status |
|-------|---------|--------|
| 167 | NCBOE clean reload task (original) | Queued |
| 169 | Exact file paths for NCBOE files | Queued |
| 171 | STOP — wrong files | Queued |
| 173 | Updated file strategy | Queued |
| 175 | FINAL load plan — 3 files | Queued |
| 177 | Filter: Individual + General only | Queued |
| 179 | Pre-check: wc -l all files | Queued |
| 181 | FINAL DEFINITIVE: 2 files only | Queued |
| 183 | Confirmed 2 approved files | Queued |
| 185 | Committee taxonomy design doc | Queued |
| 187 | DataTrust coalition counts by district | Queued |
| 189 | Build district_microsegment_rankings table | Queued |
| 191 | MASTER IMPLEMENTATION PLAN Phase 0-7 | Queued |

---

## INFRASTRUCTURE STATUS (as of session end)

- Relay: v1.4.0 running healthy at 5.9.99.109:8080 (uptime 4.6 days)
- Redis: OK
- nc_boe_donations_raw: **0 rows** (truncated, awaiting reload)
- core.person_spine: 128,047 active NC Republican donors (99.98% RNCID)
- core.contribution_map: 4,064,169 rows / $686M
- DataTrust: 7,655,593 rows, 251 cols, intact
- New Hetzner server: 144.76.219.24 — GitHub PAT needed (msg 129)

---

*Perplexity AI — March 31, 2026 2:48 AM EDT*
*Most architecturally productive session to date*
*All schemas designed, all specs documented, implementation queued*
