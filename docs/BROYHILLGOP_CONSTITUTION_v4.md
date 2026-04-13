# BroyhillGOP Constitution for Claude — Version 4.0

**Official Operating Charter & Context Reference**
**Effective Date:** April 13, 2026
**Authority:** Supersedes ALL prior versions (v1, v2, v3) in their entirety
**Maintained by:** Claude + Perplexity — update when architecture changes

---

## MANDATORY SESSION START PROTOCOL

Before any work in any session, Claude MUST complete these steps in order:

1. Search Google Drive: `fullText contains 'BroyhillGOP' and modifiedTime > '2026-01-01'` — find the most recent state documents
2. Read `docs/CLAUDE_MASTER_CONTEXT.md` from the GitHub repo — authoritative architecture reference
3. Read `docs/SESSION-STATE.md` from the GitHub repo — what was last done, what's in progress
4. Open with: *"I've read the master context and session state. [State what's current]. What are we working on today?"*

**Do NOT design, create tables, write migrations, or ALTER anything until steps 1–3 are complete.**

---

## Article I — Project Identity

**§1.1 What BroyhillGOP Is**
A multi-tenant SaaS political engagement platform serving 5,000+ Republican candidates across North Carolina and the nation. Every touchpoint leads to **DONATE** or **VOLUNTEER**. That is the core principle. Everything serves it.

**§1.2 Who Eddie Broyhill Is**
NC Republican National Committeeman. CEO of BroyhillGOP LLC, Anvil Venture LP, Broyhill Management Corp. 50 years of political fundraising expertise encoded into this platform.

**§1.3 Platform Scale**
- Revenue target: $36M ARR by Year 3
- Candidates served: 5,000+ Republican candidates
- Data foundation: 7.6M+ NC voter records, 333K+ donor spine records, 7.62M Acxiom IBE records
- Intelligence layer: 905 brain triggers, 60 ecosystems, 7 universe groups
- Platform value: $4M+ development value across all ecosystems

**§1.4 Core Innovation**
E56 Visitor Deanonymization — 30–65% visitor identification rate vs. 1.5% industry standard. This is the economic engine. Combined with E01 Donor Intelligence (RFM grading), E41 Campaign Builder, and E20 Intelligence Brain, this creates a fully automated fundraising and engagement machine.

---

## Article II — The Actual Technology Stack (2026)

**This supersedes every prior document that references Django, Inspinia-as-backend, or Supabase-as-primary-database.**

### Primary Database: Hetzner PG16
```
Host:     37.27.169.232
Database: bgop
Server:   AX162 — 96-core AMD EPYC, 251GB RAM, PG16
```
All operational data lives here. This is the only database Claude should write migrations for.

### Supabase — LIMITED SCOPE ONLY
```
Project: isbgjpnbocdkeslofota.supabase.co
```
Supabase holds EXACTLY:
- `brain.agent_messages` — inter-agent coordination (Perplexity ↔ Claude)
- `brain.decisions` — brain decision log

Do NOT create tables on Supabase. Do NOT query donor/voter data on Supabase.

### Application Layer
| Component | Technology | Status |
|-----------|-----------|--------|
| HTTP entry point | relay.py — FastAPI, port 8080 | RUNNING |
| Async signaling | Redis pub/sub — bgop:events | RUNNING |
| Event persistence | brain.event_queue — partitioned PG table | DEPLOYED |
| **AI agent processor** | **Brain Worker — Python process** | **❌ NOT RUNNING — Critical gap** |
| Frontend | Inspinia Bootstrap 5 | Active — UI framework |
| Backend services | Python (FastAPI, not Django) | Active |
| GitHub | github.com/broyhill/BroyhillGOP | Source of truth |

### Available Tools in Cowork Mode
Claude has: Read, Write, Edit, Bash (sandboxed Linux shell), Google Drive search/fetch, Computer use (Mac desktop), Web search, Web fetch. The Constitution v2 prohibition on bash tools is OBSOLETE — bash is available and appropriate for non-database tasks.

---

## Article III — Canonical Tables (Know These Cold)

### The #1 Source of Past Damage: Wrong Table Names

| What You Need | Correct Table | System | NEVER Use |
|--------------|--------------|--------|-----------|
| Golden donor record (Hetzner) | `donor_intelligence.person_master` | Hetzner | `person_master` (unqualified), `public.person_master` |
| Golden donor spine (Supabase legacy) | `core.person_spine` | Supabase | `person_spine` (unqualified) |
| All NC voters | `public.nc_datatrust` | Supabase | `datatrust_profiles` (deprecated) |
| All donations (Supabase) | `public.donor_contribution_map` | Supabase | — |
| Donation → person (Hetzner) | `donor_intelligence.contribution_map` | Hetzner | — |
| Entity intelligence | `political_entity_master` | Supabase | `committee_party_map` (superseded) |
| Campaign codes | `pipeline.campaign_codes` | Hetzner | — |
| AI triggers | `brain.triggers` | Hetzner | — |
| Ecosystems catalog | `platform.ecosystems` | Hetzner | — |

### Deprecated Tables — Hard Stop
- `public.person_master` — mostly empty shell, do not use
- `datatrust_profiles` — redundant subset of nc_datatrust, safe to drop
- `committee_party_map` — superseded by political_entity_master

---

## Article IV — The 60 Ecosystems

**All ecosystem Python code already exists.** Before proposing any new schema or feature, check whether an ecosystem already handles it.

Code location: `backend/python/ecosystems/` and `ecosystems/`
Documentation: `ECOSYSTEM_REPORTS/` (docx per ecosystem)
Full reference: `docs/COMPLETE_ECOSYSTEM_REFERENCE.md`

### Universe Groups (7)
| Universe | Ecosystems | Domain |
|----------|-----------|--------|
| U1 — Donor | E00–E09 | Donor intelligence, contributions, analytics |
| U2 — Outreach | E10–E19 | Volunteer, canvass, phone, social, media |
| U3 — Intelligence | E20–E29 | Brain, ML, A/B testing, portals, dashboards |
| U4 — Comms | E30–E36 | Email, SMS, phone bank, direct mail, messenger |
| U5 — Candidate | E37–E44 | Events, P2P, automation, builder, news |
| U6 — Production | E45–E51 | Video, broadcast, voice, GPU, NEXUS AI |
| U7 — Operations | E52–E60 | Finance, microsegment, specialized engines |

### Critical Ecosystems to Know
| ID | Name | Why It Matters |
|----|------|---------------|
| E20 | Intelligence Brain | Central nervous system — orchestrates all 60 ecosystems |
| E40 | Automation Control | IFTTT-style visual rule builder — the marketing automation engine |
| E41 | Campaign Builder AI | 22+ campaign types: welcome series, GOTV, major donor cultivation |
| E51 | NEXUS AI System | Meta-intelligence, top-level orchestration |
| E56 | Visitor Deanonymization | Core economic innovation — 30–65% visitor ID |
| E01 | Donor Intelligence | RFM grading, the scoring engine |
| E00 | DataHub | Foundation layer, PostgreSQL + Redis event bus |
| E13 | AI Hub | AI orchestration layer |

**E40 and E41 together ARE the marketing automation and funnel system. Do not build separate marketing automation schemas without reading these files first.**

---

## Article V — Immutable Architecture Rules

These are settled decisions. Do not propose changing them.

**Rule 1 — Raw donation tables are FROZEN.**
Do NOT modify `fec_donations`, `fec_party_committee_donations`, `nc_boe_donations_raw` for enrichment. Query through views: `v_fec_donations_enriched`, `v_ncboe_donations_enriched`, `v_fec_party_donations_enriched`.

**Rule 2 — All donation tables are 100% Republican.**
Democratic/Independent rows were removed by Opus 4.6. Do not re-add them. `party_flag` columns are moot.

**Rule 3 — WinRed/Anedot co-admin model only.**
BGOP does NOT process donations directly. BGOP is co-admin on candidate processor accounts. Zero PCI scope. The 48-hour FEC large-donor filing obligation belongs to WinRed/Anedot as processors, NOT to BGOP.

**Rule 4 — FEC reporting is quarterly only.**
March 31, June 30, September 30, January 31. No other FEC filing from BGOP.

**Rule 5 — NCGOP reporting is a data integrity log.**
Quarterly, per-candidate silo. Identity resolution issues, duplicates, attribution corrections. Not a financial report.

**Rule 6 — Always schema-qualify person_spine.**
Write `core.person_spine` always. The unqualified name caused production failures.

**Rule 7 — person_master context depends on which system.**
On Hetzner: `donor_intelligence.person_master` is the golden record.
On Supabase legacy: `core.person_spine` (333K rows) is the golden record.
These are different systems at different migration stages.

**Rule 8 — Do NOT seed core.person_spine from golden_records or person_master.**
Per RFC-001. See `docs/CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md`.

**Rule 9 — Partitions must exist before the month starts.**
`brain.event_queue` and `pipeline.inbound_data_queue` are monthly partitioned. Missing partition = INSERT failures for the entire month. `2026_08` is the current P1 gap — must be created before July 31.

**Rule 10 — political_entity_master is canonical for committee attribution.**
1,947 rows. Supersedes `committee_party_map`. Use `entity_office_influence` and `entity_candidate_links` for attribution chains.

**Rule 11 — datatrust_profiles is deprecated.**
Redundant subset of `nc_datatrust`. Do not reference it. Safe to drop (6.4 GB recovery).

**Rule 12 — Never DROP, TRUNCATE, or ALTER live donor/voter tables without backup.**
Apply Rule 14 first. These tables took months to load. One bad migration cost weeks.

**Rule 13 — Supabase is agent coordination only.**
Do not create application tables on Supabase. `agent_messages` and `decisions` only.

**Rule 14 — Backup Before Breaking. (Perplexity, April 13 2026)**
Before any migration, bulk data change, or restructure:
1. Run `candidate_snapshot.sh <id>` for affected candidates, OR
2. Run `backup_now.sh "description"` for full safety net
3. Rollback: `candidate_restore.sh <id> latest` (surgical) or `pitr_restore.sh "timestamp"` (nuclear)
Scripts: `/opt/pgbackup/scripts/` on Hetzner.

---

## Article VI — Current Build Gaps (P1 Critical)

Full DDL in `docs/BGOP_ARCHITECTURE_BRIEF.docx`.

| Gap | Table | Blocks |
|-----|-------|--------|
| Config store | `public.bgop_config` | All Python .env reads |
| Credential store | `pipeline.credentials_vault` | data_sources vault: refs |
| Co-admin mapping | `pipeline.campaign_codes` | Donation webhook routing |
| Co-admin audit | `pipeline.processor_access` | FEC/NCGOP reporting |
| Identity confidence | `person_master.confidence_score` | 905 triggers can't evaluate |
| IBE batch tracking | `person_master.acxiom_load_batch` | IBE reload management |
| Aug partition | `brain.event_queue_2026_08` | All August events — due Jul 31 |
| Aug partition | `pipeline.inbound_data_queue_2026_08` | All August intake — due Jul 31 |
| **Brain worker** | **Python process** | **Entire AI pipeline — inert without it** |

---

## Article VII — Multi-Tenant Architecture

The platform is NOT a single-candidate tool. It is SaaS infrastructure serving thousands of candidates with complete data isolation.

**Per-Candidate Data Boundary (13 Tables for surgical restore):**
core.candidates, core.campaigns, brain.budgets, brain.candidate_metrics, brain.candidate_triggers, brain.decisions, pipeline.candidate_data_subscriptions, pipeline.inbound_data_queue, pipeline.candidate_enrichment_log, platform.candidate_ecosystems, platform.candidate_feature_config (+ campaign_codes, processor_access once built)

**Shared Infrastructure (never siloed):**
nc_datatrust, fec_donations, person_master/spine, political_entity_master, brain.triggers (global), platform.ecosystems, audit.audit_trail

---

## Article VIII — What to Do Before Writing Any Code

1. **Search Google Drive** for existing documents on the topic
2. **Check the ecosystem catalog** — does an ecosystem already handle this? (`docs/COMPLETE_ECOSYSTEM_REFERENCE.md`)
3. **Check `docs/CANONICAL_TABLES_AUDIT.md`** — does the table already exist?
4. **Check `docs/DATABASE_ARCHITECTURE_RULES.md`** — does a rule prohibit this?
5. **Check `docs/SESSION-STATE.md`** — is this already in progress?
6. **Apply Rule 14** before any migration
7. **Then and only then** write code

**Never design a schema for something without checking whether it already exists as an ecosystem, table, or documented plan.**

---

## Article IX — Communication Standards

**§9.1 When Starting Work**
- Identify which ecosystems are affected
- State which tables will be touched
- Confirm Rule 14 backup is in plan if touching donor/voter data

**§9.2 When Stuck or Uncertain**
- State the specific uncertainty
- Search Google Drive for prior decisions on the topic
- Ask Eddie rather than guess

**§9.3 Never**
- Drop tables without explicit authorization
- Truncate live data
- Modify raw donation tables
- Create Supabase tables for application data
- Use unqualified `person_spine` or `person_master`
- Assume a feature doesn't exist without checking the ecosystem catalog
- Start a session without reading CLAUDE_MASTER_CONTEXT.md and SESSION-STATE.md

---

## Article X — Session Close Protocol

At the end of every session:
1. Run `broyhillgop:update-state` skill to update `SESSION-STATE.md`
2. Include: what was built, what's in progress, any new gaps found, any new rules, commit hashes
3. Push SESSION-STATE.md and CLAUDE_MASTER_CONTEXT.md to GitHub
4. If architecture changed, update this Constitution

---

## Article XI — Amendment Log

| Version | Date | What Changed | Why |
|---------|------|-------------|-----|
| v1.0 | Jan 2026 | Initial Constitution | Establish baseline (Django/Inspinia era) |
| v2.0 | Jan 4, 2026 | Added emergency protocols, tool prohibitions | Prevent common errors |
| v3.0 | ~Jan 2026 | Added credential startup protocol | Session initialization |
| **v4.0** | **Apr 13, 2026** | **Full rewrite: Hetzner stack, 60 ecosystems, 14 rules, Google Drive search protocol, brain worker gap, multi-tenant model** | **Platform migrated to Hetzner; Supabase demoted; major architecture evolution; repeated session errors caused by stale context** |

---

## Appendix A — Quick Reference

**🚫 NEVER:**
- Use `person_master` or `person_spine` without schema prefix
- Touch `fec_donations` / `fec_party_committee_donations` / `nc_boe_donations_raw` directly
- Create tables on Supabase
- Start work without reading CLAUDE_MASTER_CONTEXT.md
- Migrate/ALTER without Rule 14 backup

**✅ ALWAYS:**
- Schema-qualify every table name
- Search Drive + read CLAUDE_MASTER_CONTEXT.md at session start
- Check ecosystem catalog before designing new features
- Apply Rule 14 before touching live donor/voter data
- Update SESSION-STATE.md at session end

**📍 Primary Repo:** `github.com/broyhill/BroyhillGOP` (PUBLIC — more complete than private repo)
**📍 Hetzner Host:** `37.27.169.232` — PG16, bgop database
**📍 Key Doc:** `docs/CLAUDE_MASTER_CONTEXT.md` — read this first every session
**📍 Key Doc:** `docs/BGOP_ARCHITECTURE_BRIEF.docx` — all P1–P3 DDL
**📍 Key Doc:** `docs/COMPLETE_ECOSYSTEM_REFERENCE.md` — all 60 ecosystems

---

*Constitution v4.0 — Ratified April 13, 2026*
*This document supersedes BroyhillGOP-Constitution-v2.md, v3, and all prior operating instructions.*
*Next review: When platform architecture changes significantly or a new session causes damage due to stale context.*
