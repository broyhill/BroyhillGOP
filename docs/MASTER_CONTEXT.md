# MASTER CONTEXT
## BroyhillGOP Platform — Reference for Every Agent Session

**Read this before non-trivial work. Ed may waive for specific small tasks; default is read it.**

Last updated: April 25, 2026 (v2 — loosened, agent-neutral)
Maintained by: Ed Broyhill. Any agent (Claude, Perplexity, Cursor, or other) may propose edits via PR; Ed approves.

*(This file was previously named `CLAUDE_MASTER_CONTEXT.md`. The old filename now redirects here. Update internal links when convenient.)*

---

## WHY THIS FILE EXISTS

Previous agent sessions caused database damage by:
- Using wrong table names (`person_spine` instead of `core.person_spine`; `person_master` instead of `donor_intelligence.person_master`)
- Treating Supabase as the primary database (it is NOT)
- Designing schemas that duplicated existing ecosystems (E40/E41 already exist)
- Making migrations without knowing current state
- Overwriting work that was already built

**Rule 0 (default — Ed may waive):** Read this file and `SESSION-STATE.md` before non-trivial work. Then confirm today's task with Ed. Avoid designing, creating, migrating, or ALTERing anything until you understand the current state. For trivial tasks (typo fixes, single-line edits, read-only queries), Ed may waive this read.

---

## §1 THE ACTUAL STACK (Not Supabase)

### Primary Database: Hetzner PG16
```
Host:   37.27.169.232
DB:     bgop
Port:   5432
Server: AX162 — 96-core AMD EPYC, 251GB RAM
```
**All data lives here.** The Supabase connection string in old docs is WRONG for general use.

### Supabase — LIMITED SCOPE ONLY
```
Project: isbgjpnbocdkeslofota.supabase.co
```
Supabase holds EXACTLY TWO THINGS:
1. `brain.agent_messages` — inter-agent coordination (Perplexity ↔ Claude)
2. `brain.decisions` — brain decision log

**Supabase is NOT the primary DB. Do NOT create tables there. Do NOT query donor/voter data there.**

### HTTP / Async Layer
| Component | Status | Location |
|-----------|--------|----------|
| relay.py (FastAPI) | RUNNING | Port 8080 on Hetzner |
| Redis pub/sub (bgop:events) | RUNNING | localhost:6379 |
| brain.event_queue (PG partitioned) | DEPLOYED | Hetzner — partitioned monthly |
| **Brain Worker** | **❌ NOT RUNNING** | **Critical gap — entire AI pipeline is inert without it** |

**The brain worker is the most important missing piece. 905 brain.triggers are loaded and waiting. Nothing fires until this runs.**

---

## §2 CANONICAL TABLES — USE THESE, NOTHING ELSE

This is the #1 source of past mistakes. Know these cold.

### On Hetzner (new schema — use for all new work)

| Purpose | Table | Rows (Apr 2026) |
|---------|-------|-----------------|
| Golden donor record | `donor_intelligence.person_master` | 5.575M+ (IBE loading, ~73%) |
| Donation → person link | `donor_intelligence.contribution_map` | Active |
| Identity resolution queue | `donor_intelligence.identity_resolution` | Active |
| Raw Acxiom IBE | `donor_intelligence.acxiom_ibe_raw` | 5.575M loaded of 7.62M |
| All candidate profiles | `core.candidates` | ~280 |
| Users / staff | `core.users` | Active |
| Inbound data (all sources) | `pipeline.inbound_data_queue` | Partitioned monthly |
| Data source registry | `pipeline.data_sources` | 9 rows |
| AI triggers | `brain.triggers` | 905 rows |
| Event queue | `brain.event_queue` | Partitioned monthly |
| Ecosystems catalog | `platform.ecosystems` | 60 rows (E00–E60) |
| Universe groups | `platform.universes` | 7 rows |

### On Supabase (old schema — read-only reference, do not add to)

| Purpose | Table | Rows | Notes |
|---------|-------|------|-------|
| Canonical voter/DataTrust | `public.nc_datatrust` | 7.6M | 251 cols, join key: `rncid` |
| Golden donor spine (old) | `core.person_spine` | 333K | RFC-001 identity layer — still canonical on Supabase side |
| All donations (old) | `public.donor_contribution_map` | 3.1M | fec_party, NC_BOE, fec_god sources |
| Raw NC voter file | `public.nc_voters` | 9M | join key: `ncid` |
| Entity intelligence | `political_entity_master` | 1,947 | Every R committee/PAC/party org |
| Entity → office map | `entity_office_influence` | 1,985 | Maps entities to offices |
| Entity → candidate | `entity_candidate_links` | 1,139 | Links entities to candidates |
| WinRed donors | `public.winred_donors` | 194,278 | Loaded |

### ❌ DEPRECATED TABLES — NEVER USE

| Table | Why Deprecated |
|-------|---------------|
| `public.person_master` | Mostly empty shell; `ncvoter_ncid` only; `golden_record_id` 0.4% filled. Use `core.person_spine` (Supabase) or `donor_intelligence.person_master` (Hetzner) |
| `public.datatrust_profiles` | 100% redundant subset of nc_datatrust (73 cols vs 251 cols). Safe to drop. |
| `public.person_source_links` | Superseded by identity resolution layer |
| `person_spine` (without schema) | ALWAYS qualify: `core.person_spine` (Supabase) — the unqualified name has caused bugs |

---

## §3 HETZNER SCHEMA MAP (11 schemas, ~35 tables)

```
public          — bgop_config (MISSING — P1 gap), migrations log
core            — candidates, users, organizations, offices, districts
donor_intelligence — person_master, contribution_map, identity_resolution,
                     acxiom_ibe_raw, address_history, contact_points
pipeline        — data_sources (9 rows), inbound_data_queue (partitioned),
                  credentials_vault (MISSING — P1), processing_jobs,
                  dead_letter_queue
                  campaign_codes (MISSING — P1), processor_access (MISSING — P1)
brain           — event_queue (partitioned), triggers (905), candidate_triggers,
                  decisions, agent_messages (Supabase mirror)
platform        — universes (7), ecosystems (60), ecosystem_features,
                  ecosystem_versions, candidate_ecosystems,
                  candidate_feature_config, ecosystem_dependencies,
                  ecosystem_health, dashboard_config (MISSING — P3)
comms           — message_queue, send_log, template_library (all empty — not activated)
outreach        — volunteer_assignments, canvass_log (empty)
reporting       — fec_quarterly_log, ncgop_integrity_log (empty)
                  bgop_sla_definitions (MISSING — P2)
finance         — disbursement_requests (empty)
audit           — audit_trail (RLS-enabled, active)
backup          — backup_history, restore_log, v_backup_status (Perplexity built Apr 13)
```

Tables marked MISSING are specified with full DDL in: `docs/BGOP_ARCHITECTURE_BRIEF.docx`

---

## §4 THE ECOSYSTEM CATALOG (E00–E60) — ALL ALREADY BUILT

**Do not design schemas for features that already exist as ecosystems.**
The Python code exists in `backend/python/ecosystems/` and `ecosystems/` (duplicate paths).
ECOSYSTEM_REPORTS docx files exist for each one in `ECOSYSTEM_REPORTS/`.

### Tier 1 — Data & Intelligence (E0–E13)
| ID | Name | File |
|----|------|------|
| E0 | DataHub | ecosystem_00_datahub_complete.py |
| E1 | Donor Intelligence | ecosystem_01_donor_intelligence_complete.py |
| E2 | Donation Processing | ecosystem_02_donation_processing_complete.py |
| E3 | Candidate Profiles | ecosystem_03_candidate_profiles_complete.py |
| E4 | Activist Network | ecosystem_04_activist_network_complete.py |
| E5 | Volunteer Management | ecosystem_05_volunteer_management_complete.py |
| E6 | Analytics Engine | ecosystem_06_analytics_engine_complete.py |
| E7 | Issue Tracking | ecosystem_07_issue_tracking_complete.py |
| E8 | Communications Library | ecosystem_08_communications_library_complete.py |
| E9 | Content Creation AI | ecosystem_09_content_creation_ai_complete.py |
| E10 | Compliance Manager | ecosystem_10_compliance_manager_complete.py |
| E11 | Budget Management | ecosystem_11_budget_management_complete.py |
| E12 | Campaign Operations | ecosystem_12_campaign_operations_complete.py |
| E13 | AI Hub | ecosystem_13_ai_hub_complete.py |

### Tier 2 — Production & Media (E14–E21)
| ID | Name | File |
|----|------|------|
| E14 | Print Production | ecosystem_14_print_production_complete.py |
| E15 | Contact Directory | ecosystem_15_contact_directory_complete.py |
| E16 | TV/Radio AI | ecosystem_16_tv_radio_complete.py |
| E16b | Voice Synthesis ULTRA | ecosystem_16b_voice_synthesis_ULTRA.py |
| E17 | RVM System | ecosystem_17_rvm_complete.py |
| E18 | VDP Composition | ecosystem_18_vdp_composition_engine_complete.py |
| E19 | Social Media | ecosystem_19_social_media_manager.py |
| E20 | Intelligence Brain | ecosystem_20_intelligence_brain_complete.py |
| E21 | ML Clustering | ecosystem_21_ml_clustering_complete.py |

### Tier 3 — Analytics & Portals (E22–E29)
| ID | Name | File |
|----|------|------|
| E22 | A/B Testing Engine | ecosystem_22_ab_testing_engine_complete.py |
| E23 | Creative Asset 3D | ecosystem_23_creative_asset_3d_engine_complete.py |
| E24 | Candidate Portal | ecosystem_24_candidate_portal_complete.py |
| E25 | Donor Portal | ecosystem_25_donor_portal_complete.py |
| E26 | Volunteer Portal | ecosystem_26_volunteer_portal_complete.py |
| E27 | Realtime Dashboard | ecosystem_27_realtime_dashboard_complete.py |
| E28 | Financial Dashboard | ecosystem_28_financial_dashboard_complete.py |
| E29 | Analytics Dashboard | ecosystem_29_analytics_dashboard_complete.py |

### Tier 4 — Communication Channels (E30–E36)
| ID | Name | Notes |
|----|------|-------|
| E30 | Email System | Drip sequences, automation |
| E31 | SMS System | TCPA-compliant |
| E32 | Phone Banking | Call lists, scripts |
| E33 | Direct Mail | VDP, print-ready output |
| E34 | Events | Event-triggered sends |
| E35 | Interactive Comm Hub | Auto-response, chatbot |
| E36 | Messenger Integration | FB Messenger, WhatsApp |

### Tier 5 — Advanced Automation (E37–E51)
| ID | Name | Notes |
|----|------|-------|
| E37 | Event Management | Physical event logistics |
| E38 | Volunteer Coordination | Assignment engine |
| E39 | P2P Fundraising | Peer-to-peer campaigns |
| **E40** | **Automation Control** | **IFTTT-style visual rule builder — the marketing automation engine** |
| **E41** | **Campaign Builder AI** | **22+ campaign types: welcome, lapsed donor, GOTV, major donor cultivation** |
| E42 | News Intelligence | 13,000+ source monitoring |
| E43 | Advocacy Tools | Issue-based outreach |
| E44 | Vendor Compliance | Vendor/security management |
| E45 | Video Studio | AI video production |
| E46 | Broadcast Hub | TV/radio distribution |
| E47 | AI Script Generator | Automated scripts |
| E48 | Communication DNA | Brand voice engine |
| E49 | Interview System | Candidate prep |
| E50 | GPU Orchestrator | Distributed compute |
| E51 | NEXUS AI System | Meta-intelligence layer |

### Tier 6 — Specialized (E52–E60)
E52–E60 include P2P Fundraising variants, Finance Committee, Microsegment Intelligence (E59), Addiction Psychology Engagement Engine (E60), and others.
Full list: `docs/BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md`

**Key point about E40/E41:** These ARE the marketing automation and funnel systems. Do not build separate marketing automation schemas without reading these files first. The gap is their backing DB tables, not the ecosystem logic.

---

## §5 ARCHITECTURAL RULES

These are the current settled decisions. They can be revisited only with Ed's explicit approval and an amendment-log entry in the Constitution. Do not change them silently.

**Hard rules** (Rules 1, 2, 6, 12, 13) prevent data loss and cannot be waived without Ed's written authorization. **Default rules** (Rules 3, 4, 5, 7, 8, 9, 10, 11, 14) are strong defaults Ed may waive for a specific task.

### Rule 1 — Raw donation tables are FROZEN
Do NOT modify `fec_donations`, `fec_party_committee_donations`, `nc_boe_donations_raw` for enrichment or filtering. Query through enrichment views: `v_fec_donations_enriched`, `v_ncboe_donations_enriched`, `v_fec_party_donations_enriched`.

### Rule 2 — All donation tables are 100% Republican
Opus 4.6 removed all D/I rows. `party_flag` columns are moot. Do not re-add Democrat rows.

### Rule 3 — WinRed/Anedot co-admin model
BGOP does NOT process donations. BGOP is co-admin on candidate processor accounts. Zero PCI scope. The 48-hour FEC large-donor filing obligation belongs to WinRed/Anedot, not BGOP.

### Rule 4 — FEC reporting is quarterly only
March 31, June 30, September 30, January 31. No other FEC filing obligation from BGOP's side.

### Rule 5 — NCGOP reporting is quarterly data integrity log
Per-candidate silo. Reports identity resolution issues, duplicates, attribution corrections. Not a financial report.

### Rule 6 — person_spine is always schema-qualified
Always write `core.person_spine` — never bare `person_spine`. The unqualified name caused production bugs.

### Rule 7 — donor_intelligence.person_master is the Hetzner golden record
On Hetzner, `donor_intelligence.person_master` is the golden record. On old Supabase schema, `core.person_spine` (333K rows) is the golden record. These are different systems. When working on Hetzner, use `donor_intelligence.person_master`. When working on Supabase legacy schema, use `core.person_spine`.

### Rule 8 — Do not seed core.person_spine from golden_records or person_master
Per RFC-001. The identity resolution pipeline has specific rules. See `docs/CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md`.

### Rule 9 — Partitions must be created before month starts
`brain.event_queue` and `pipeline.inbound_data_queue` are monthly partitioned. Missing partition = INSERT failure. `2026_08` partition is P1 gap — must be created before July 31.

### Rule 10 — political_entity_master supersedes committee_party_map
`political_entity_master` (1,947 rows) is the current entity intelligence layer. `committee_party_map` is superseded. Use entity layer for committee/PAC attribution.

### Rule 11 — datatrust_profiles is safe to drop
`datatrust_profiles` is a 100% redundant subset of `nc_datatrust`. Do not reference it. `nc_datatrust` (7.6M rows, 251 cols) is canonical.

### Rule 12 — Never DROP, TRUNCATE, or ALTER live donor/voter tables without backup
Apply Rule 14 first (see below). These tables took months to load. A bad migration cost weeks of recovery time.

### Rule 13 — Supabase is agent coordination only
Do not create application tables on Supabase. `agent_messages` and `decisions` only.

### Rule 14 — Backup Before High-Risk Changes (Default — Ed may waive)
Before high-risk changes (DDL on live donor/voter tables, bulk data changes >10K rows, restructures, ecosystem migrations), run a backup. For routine work and reversible changes, backup is optional but recommended.
1. Run `candidate_snapshot.sh <id>` for affected candidates, OR
2. Run `backup_now.sh "before migration XYZ"` for full safety net
3. On failure: `candidate_restore.sh <id> latest` (surgical) or `pitr_restore.sh "timestamp"` (nuclear)
Scripts location: `/opt/pgbackup/scripts/` on Hetzner. See backup schema: `backup.backup_history`, `backup.restore_log`.

---

## §6 WHAT NEEDS TO BE BUILT (Priority Order)

Full DDL for all of these is in `docs/BGOP_ARCHITECTURE_BRIEF.docx`.

### P1 — Critical (blocks everything else)
1. `public.bgop_config` — config store; replaces all Python .env reads
2. `pipeline.credentials_vault` — backs vault: references in data_sources
3. `pipeline.campaign_codes` — WinRed/Anedot campaign code → candidate mapping
4. `pipeline.processor_access` — co-admin access audit trail
5. `ALTER donor_intelligence.person_master ADD confidence_score NUMERIC(4,3)`
6. `ALTER donor_intelligence.person_master ADD acxiom_load_batch TEXT`
7. `CREATE brain.event_queue_2026_08 partition` — before July 31
8. `CREATE pipeline.inbound_data_queue_2026_08 partition` — before July 31
9. **Build and start brain worker** (Python process) — entire AI pipeline is inert without it

### P2 — High (within 30 days)
10. `reporting.bgop_sla_definitions` — FEC quarterly + NCGOP integrity SLAs
11. `brain.bgop_queues` + `brain.bgop_queue_items` — human review queues
12. `ALTER pipeline.data_sources ADD last_webhook_at, webhook_failure_count`
13. `ALTER brain.triggers ADD event_type TEXT` + index
14. `ALTER core.candidates ADD winred_co_admin, anedot_co_admin BOOLEAN`
15. PostgreSQL RLS policies for 8 defined roles (roles exist, policies not written)

### P3 — Medium (this quarter)
16. `platform.dashboard_config` — view/form config for UI layer
17. `brain.prediction_model_registry` — AI model tracking
18. `ALTER platform.candidate_feature_config ADD override_json JSONB`
19. `ALTER audit.audit_trail ADD ecosystem_id TEXT`
20. Migrate Python .env reads to bgop_config

---

## §7 CURRENT ACXIOM IBE STATUS

As of April 13, 2026: **5.575M of 7.62M rows loaded (~73%)** into `donor_intelligence.acxiom_ibe_raw` and merging into `donor_intelligence.person_master`.

**Critical ordering requirement:** Brain worker MUST be running before IBE load completes. The completion event fires a Redis signal. If brain worker is down when IBE completes, the signal is lost (Redis pub/sub does not persist unread messages). All E01, E15 trigger logic would miss the completion event.

---

## §8 KEY REFERENCE DOCUMENTS

| Document | Location | What It Contains |
|----------|----------|-----------------|
| Architecture Brief | `docs/BGOP_ARCHITECTURE_BRIEF.docx` | Full DDL for all P1–P3 new tables, brain worker spec, partition schedule |
| D365 Config Framework | `docs/BROYHILLGOP_D365_CONFIG_FRAMEWORK.docx` | 14 config domains, DIRECT/ADAPTED/NOT APPLICABLE decisions |
| Database Architecture Rules | `docs/DATABASE_ARCHITECTURE_RULES.md` | Frozen table rules, entity layer, enrichment views |
| Canonical Tables Audit | `docs/CANONICAL_TABLES_AUDIT.md` | Deprecated tables list, correct canonical tables |
| RFC-001 | `docs/CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md` | Identity resolution rules, person_spine seeding rules |
| Session State | `docs/SESSION-STATE.md` | What was done last session, current in-progress work |
| Ecosystem Inventory | `docs/BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md` | Full E00–E60 catalog with file names |
| Complete Ecosystem Reference | `docs/COMPLETE_ECOSYSTEM_REFERENCE.md` | Feature detail for every ecosystem |
| Hetzner DB Architecture | `docs/CURSOR_HETZNER_DB_ARCHITECTURE.md` | Full Hetzner schema, backup system (Rule 14) |
| Hetzner Handoff Briefing | `docs/sessions/2026-04-13_HETZNER_HANDOFF_BRIEFING.md` | April 13 server state snapshot |

---

## §9 STARTING A SESSION

After reading this file and SESSION-STATE.md, confirm readiness in the agent's own voice (no scripted opener required). A useful pattern: name the current architecture state, the known critical gap, and what's in progress — then ask Ed what today's task is.

Defaults (Ed may waive):
- Avoid designing or proposing until you know today's specific task
- Avoid assuming a table exists — check SESSION-STATE.md or ask Ed to confirm
- Avoid writing SQL that touches `donor_intelligence` or `brain` schema with a high-risk change without a Rule 14 backup first

---

## §10 SESSION CLOSE PROTOCOL

At the end of every session, run `broyhillgop:update-state` skill to update `SESSION-STATE.md` with:
- What was built or changed
- What's now in progress
- Any new gaps discovered
- Any new rules added
- Commit hash of any pushes made

Then push SESSION-STATE.md and CLAUDE_MASTER_CONTEXT.md to GitHub.

---

*This document is the foundation. If it's wrong, everything built on top of it is wrong.*
*v1: April 13, 2026. v2: April 25, 2026 — agent-neutral language, renamed file, loosened Rule 0.*
