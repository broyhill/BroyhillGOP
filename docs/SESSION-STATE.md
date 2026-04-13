# SESSION-STATE.md — APRIL 13, 2026
## BroyhillGOP Platform — Context Migration + Architecture Brief Session
## Maintained by: Claude + Perplexity
## Updated: April 13, 2026

---

## WHAT HAPPENED THIS SESSION (April 13, 2026)

### Major Deliverables Completed

| Item | File | Commit | Status |
|------|------|--------|--------|
| Architecture Brief (full DDL, 7 tables, 12 column mods) | `docs/BGOP_ARCHITECTURE_BRIEF.docx` | `f0ad35b` | ✅ Pushed to main |
| Master Context Reference | `docs/CLAUDE_MASTER_CONTEXT.md` | `d0ae12e` | ✅ Pushed to main |
| Constitution v4 (supersedes v2/v3) | `docs/BROYHILLGOP_CONSTITUTION_v4.md` | this session | ✅ In this commit |
| SESSION-STATE.md (this file) | `docs/SESSION-STATE.md` | this session | ✅ In this commit |
| Perplexity backup system | scripts at `/opt/pgbackup/scripts/` | `80ead2c` | ✅ Perplexity commit |

### Key Decisions Made This Session

1. **Hetzner PG16 is primary** — Supabase is agent coordination only (`brain.agent_messages`, `brain.decisions`)
2. **Marketing automation gap identified correctly** — E40 (Automation Control Panel) and E41 (Campaign Builder AI) ALREADY EXIST as Python code; the gap is their backing DB tables, not the ecosystems themselves
3. **Three-layer context system deployed** — CLAUDE_MASTER_CONTEXT.md (constitution) + SESSION-STATE.md (living state) + mandatory session-start protocol (read both files + Google Drive search)
4. **Rule 14 added** — "Backup Before Breaking" — Perplexity deployed full PITR + Dropbox snapshots + per-candidate surgical restore at `/opt/pgbackup/scripts/`
5. **Google Drive MCP activated** — `mcp__c1fc4002-5f49-5f9d-a4e5-93c4ef5d6a75` — use at every session start
6. **Constitution v4 ratified** — supersedes v2 (Django/Inspinia era) and v3; reflects actual 2026 Hetzner stack

---

## CURRENT SYSTEM STATE (April 13, 2026)

### Hetzner PG16 — Primary Database
- **Host:** `37.27.169.232` — AX162, 96-core AMD EPYC, 251GB RAM
- **Database:** `bgop`
- **Status:** Operational

### Infrastructure Up/Down
| Component | Status |
|-----------|--------|
| relay.py (FastAPI, port 8080) | ✅ RUNNING |
| Redis pub/sub (`bgop:events`) | ✅ RUNNING |
| `brain.event_queue` (partitioned PG) | ✅ DEPLOYED |
| **Brain Worker (Python process)** | **❌ NOT RUNNING — critical gap** |
| Inspinia Bootstrap 5 frontend | ✅ Active |
| `brain.triggers` | ✅ 905 rows loaded |
| `platform.ecosystems` | ✅ 60 ecosystems cataloged |

### Acxiom IBE Load Status
- 5,575,000 / 7,620,000 rows loaded (~73%)
- **Brain worker must start BEFORE IBE completes** — completion signal will be lost otherwise
- Reload tracking: `person_master.acxiom_load_batch` column does NOT yet exist (P2 gap)

### Supabase — Agent Coordination Only
- `brain.agent_messages` — inter-agent coordination (Perplexity ↔ Claude)
- `brain.decisions` — brain decision log
- All other Supabase tables are legacy Supabase-era data; Hetzner is canonical going forward

---

## P1 BUILD GAPS (Critical — Blocks Platform Operation)

| Gap | Table/Component | Blocks |
|-----|----------------|--------|
| Config store | `public.bgop_config` | All Python .env reads |
| Credential vault | `pipeline.credentials_vault` | data_sources vault refs |
| Co-admin mapping | `pipeline.campaign_codes` | Donation webhook routing |
| Co-admin audit | `pipeline.processor_access` | FEC/NCGOP reporting |
| Identity confidence score | `person_master.confidence_score` column | 905 triggers can't evaluate |
| IBE batch tracking | `person_master.acxiom_load_batch` column | IBE reload management |
| August partition | `brain.event_queue_2026_08` | All August events — due Jul 31 |
| August partition | `pipeline.inbound_data_queue_2026_08` | All August intake — due Jul 31 |
| **Brain worker** | **Python process** | **Entire AI pipeline — inert without it** |

Full DDL for all gaps: `docs/BGOP_ARCHITECTURE_BRIEF.docx` §3–§6

---

## WHAT PERPLEXITY NEEDS TO DO NEXT

From Architecture Brief §10 (Wave 1 — execute in order):
1. Run `backup_now.sh "pre-wave1"` (Rule 14)
2. Create `public.bgop_config` (DDL in brief §3.1)
3. Create `pipeline.credentials_vault` (DDL in brief §3.2)
4. Create `pipeline.campaign_codes` (DDL in brief §3.3)
5. Create `pipeline.processor_access` (DDL in brief §3.4)
6. Add `person_master.confidence_score` column
7. Add `person_master.acxiom_load_batch` column
8. Create `brain.event_queue_2026_08` partition (due Jul 31 — do not wait)
9. Create `pipeline.inbound_data_queue_2026_08` partition (due Jul 31)

Then Wave 2: Extract E40/E41 table expectations from Python files and create `comms` schema tables.

**Note for Perplexity:** If the Architecture Brief shows 0 bytes, run `git pull origin main` — the file is 34K on main branch (commit `f0ad35b`).

---

## E40 / E41 TABLE WORK (Pending)

E40 (`ecosystem_40_automation_control_panel_complete.py`) and E41 (`ecosystem_41_campaign_builder_complete.py`) are the marketing automation and funnel system. Their Python code exists but their backing DB tables do NOT yet exist on Hetzner.

**Next step:** Read these Python files to extract what tables/columns they expect → create DDL → add to Architecture Brief Wave 2.

Files at: `backend/python/ecosystems/` and `ecosystems/`

---

## ARCHITECTURE REFERENCE FILES (Read These Every Session)

| File | Purpose |
|------|---------|
| `docs/CLAUDE_MASTER_CONTEXT.md` | Authoritative architecture reference — read first |
| `docs/BROYHILLGOP_CONSTITUTION_v4.md` | Operating charter — session protocols, rules |
| `docs/BGOP_ARCHITECTURE_BRIEF.docx` | Full P1–P3 DDL and build specifications |
| `docs/COMPLETE_ECOSYSTEM_REFERENCE.md` | All 60 ecosystems with filenames |
| `docs/CANONICAL_TABLES_AUDIT.md` | Canonical vs deprecated table map |
| `docs/DATABASE_ARCHITECTURE_RULES.md` | Frozen tables, enrichment views, RFC-001 |

---

## CANONICAL TABLE QUICK REFERENCE

| What You Need | Correct Table | System |
|--------------|--------------|--------|
| Golden donor record | `donor_intelligence.person_master` | Hetzner |
| Golden donor spine (legacy) | `core.person_spine` | Supabase |
| All NC voters | `public.nc_datatrust` | Supabase legacy |
| All donations (Supabase) | `public.donor_contribution_map` | Supabase |
| Donation → person (Hetzner) | `donor_intelligence.contribution_map` | Hetzner |
| Entity intelligence | `political_entity_master` | Supabase |
| Campaign codes | `pipeline.campaign_codes` | Hetzner (P1 — not yet created) |
| AI triggers | `brain.triggers` | Hetzner |
| Ecosystems catalog | `platform.ecosystems` | Hetzner |

**NEVER use unqualified `person_spine` or `person_master`** — always schema-qualify.

---

## OPEN QUESTIONS / DECISIONS NEEDED

1. **nc_boe_donations_raw reload** — 282,096 rows but wrong files; correct files identified (`2015-2019-ncboe.csv`, `2020-2026-ncboe.csv`); Cursor needs to classify in staging before reload
2. **E40/E41 backing tables** — need to read Python files and extract expected schema
3. **Brain worker build** — full spec in Architecture Brief §2; needs Engineering assignment
4. **Google Drive copy of Constitution v4** — Eddie to create Google Doc and paste content so it's findable at session start via Drive search

---

## THREE-AGENT LANES

| Agent | Role | DB Access |
|-------|------|-----------|
| **Claude** | Architecture, context, long-running scripts, Hetzner execution | Via Hetzner psql (Cowork mode) |
| **Perplexity** | GitHub, Wave migrations, coordination, research | REST API + direct psql |
| **Cursor** | Direct execution, Mac + Hetzner psql, local file access | Direct psql port 5432 |

---

## RULE 14 — BACKUP BEFORE BREAKING (Perplexity commit `80ead2c`)

Scripts at `/opt/pgbackup/scripts/` on Hetzner:
- `backup_now.sh "description"` — full safety net
- `candidate_snapshot.sh <id>` — surgical per-candidate backup
- `candidate_restore.sh <id> latest` — surgical restore
- `pitr_restore.sh "timestamp"` — nuclear restore

**Run `backup_now.sh` before ANY migration, bulk change, or ALTER.**

---

*Updated: Claude — April 13, 2026*
*Supersedes: March 31, 2026 SESSION-STATE (Perplexity)*
*Source: April 13 session — context migration, Architecture Brief, Constitution v4*
