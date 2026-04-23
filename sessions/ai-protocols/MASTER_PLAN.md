# BROYHILLGOP — MASTER DEVELOPMENT PLAN
**Governing Document for All AI Agents: Perplexity · Cursor · Claude**  
**Repository:** broyhill/BroyhillGOP  
**Date Created:** 2026-03-23  
**Last Updated:** 2026-04-23 by Perplexity AI  

---

## HOW THIS DOCUMENT WORKS

This is the **single source of truth** for the BroyhillGOP development project.  
Every AI agent (Perplexity, Cursor, Claude) reads this on startup (`nexus`) and updates it on shutdown (`nexus sleep`).  
All agents share work through this document and the `sessions/` folder in GitHub.

**Trigger words:**
- `nexus` → Boot sequence: read this document + most recent session
- `nexus sleep` → Shutdown: update this document + write dated session file to GitHub

---

## PLATFORM OVERVIEW

| Item | Value |
|---|---|
| Platform | NEXUS — Full-Spectrum Campaign Intelligence |
| Owner | Ed Broyhill / BroyhillGOP / NC Republican Data Committee |
| Stack | Supabase (PostgreSQL) · Inspinia Bootstrap · Vercel/Next.js · Hetzner |
| Ecosystems | 55 integrated (E0–E51, E50 does not exist) |
| AI Triggers | 905 automated |
| Development Value | $3,520,000+ |
| Monthly AI Cost Target | ~$700 |
| Projected ROI | 7,008% ($7.7M increase) |

---

## DATABASE STATE (Last Audited: 2026-03-23)

| Data Asset | Rows | Status |
|---|---|---|
| FEC Donations | 2,597,935 | ✅ Loaded |
| FEC → Spine Link | 1,612,466 (89.8%) | ✅ Built |
| NC BOE | 625,897 | ✅ Loaded |
| BOE → RNCID Match | 338,720 (54.1%) | 🔄 Fuzzy pass needed |
| WinRed | 194,279 | ✅ Loaded |
| RNC Voter Staging | 7,708,542 | ✅ Full NC file |
| DataTrust | 7,655,593 (251 cols) | ✅ Untouched |
| Person Spine | 337,053 | ✅ Active |
| Spine RNCIDs | 189,527 (56.2%) | 🔄 Needs backfill |
| Contribution Map | 4,006,356 | ✅ Active |

---

## 5-PHASE COMPLETION PLAN

### ✅ PHASE 1: Execute Queued Migrations (086-087)
**Status:** QUEUED — Blocks A-J pending  
**Tasks:**
- [ ] A: Add `is_donor` column to spine + populate (~200K rows)
- [ ] B: Recalculate spine aggregates ($$ totals)
- [ ] C: Insert WinRed donors missing from spine (~71K new rows)
- [ ] D: Add WinRed to `core.contribution_map` (~123K entries)
- [ ] E: Stamp `rnc_rncid` on person_master from spine (~189K rows)
- [ ] F: Stamp `is_donor` on person_master (~200K rows)
- [ ] G: Write resolved queue RNCIDs → BOE raw (~69K values)
- [ ] H: Stamp new BOE RNCIDs onto spine
- [ ] I: Batched fuzzy pass (20K × 4 runs)
- [ ] J: Final state audit

### 🔄 PHASE 2: Fuzzy Match Pass
**Status:** QUEUED  
**Method:** Batched trigram similarity (threshold 0.82), 4 runs of 20K  
**Who:** Claude via Hetzner psql  
**Goal:** BOE match rate 54% → 75-80%

### 🔄 PHASE 3: Golden Record Clustering
**Status:** QUEUED — only 3 rows exist, needs full rebuild  
**Method:** Rebuild `golden_record_clusters` from `match_key_v2`  
**Who:** Claude / Hetzner (too large for Supabase)  
**Goal:** BOE→spine bridge fully populated

### 🔄 PHASE 4: DataTrust Enrichment
**Status:** QUEUED — Eddie must approve each field  
**Fields to backfill on `core.person_spine`:**  
- congressional_district, state_house_district, state_senate_district, precinct
- email, race
- republican_score, turnout_score, donor_score
- voter_ncid (182,523 already populated)

**Join:** `core.person_spine.voter_rncid = nc_datatrust.rnc_regid`

### 🔄 PHASE 5: NEXUS Product Layer
**Status:** QUEUED  
**Tasks:**
1. Create `nexus_morning_feed` table
2. Wire `brain_events` to receive writes (currently 0 rows)
3. Build materialized search view on spine + top 20 fields
4. Design `person_features` feature store for AI matching
5. Set up n8n behavioral scoring (Layer 2)
6. Set up Make.com feed assembly (Layer 3)
7. Build Inspinia card UI (Layer 4)

**Monthly cost:** $48 (Supabase $25 + n8n $6 + Make.com $9 + OpenAI $8)

---

## KNOWN ISSUES (Active)

1. `rncid_resolution_queue` write-back returned 0 rows — source_id mismatch
2. Fuzzy pass times out in Supabase SQL editor — must run in 20K batches on Hetzner
3. `golden_record_clusters` has only 3 rows — clustering never completed
4. `core.person_spine` is 337K (donors only, by design — not 7.66M voter universe)
5. WinRed `rncid` column is empty — needs backfill from `rnc_voter_staging`

---

## RULES THAT NEVER CHANGE

1. **Eddie approves all destructive operations**
2. **Read RFC-001 and CLAUDE_GUARDRAILS.md every session**
3. **`voter_rncid` is the universal anchor** — never break it
4. **Never destroy donation records**
5. **Run large ops on Hetzner** — Supabase has a 2-min timeout
6. **Every session ends with NEXUS SLEEP** — update this file

---

## SESSION LOG

### 2026-04-23 — Perplexity AI
**Work Done:**
- Created unified NEXUS startup protocol system for all three AI agents
- Built `sessions/ai-protocols/PERPLEXITY_STARTUP.md`
- Built `sessions/ai-protocols/CURSOR_STARTUP.md`
- Built `sessions/ai-protocols/CLAUDE_STARTUP.md`
- Created this `MASTER_PLAN.md` as shared governing document
- Established `nexus` (boot) and `nexus sleep` (shutdown) protocol across all agents
- All agents now share session state through this document + dated session files

**Decisions:**
- All AI agents use same trigger word `nexus` to boot
- All AI agents use `nexus sleep` to write session state and update this Master Plan
- Session files named: `sessions/SESSION_[MONTH]_[DAY]_[YEAR]_[AGENT].md`
- This MASTER_PLAN.md is the cross-agent memory hub

**Next Session Tasks:**
1. Execute Migration 086 Block A — add `is_donor` to spine
2. Execute Migration 086 Block B — recalculate spine aggregates
3. Begin WinRed insert to spine (Block C)
4. Confirm Hetzner psql connection is live for fuzzy pass

---

## NEXT SESSION (Priority Order)

1. **Run Migration 086 Block A** — Add `is_donor` column to `core.person_spine`, populate from `core.contribution_map` (~200K rows flagged)
2. **Run Migration 086 Block B** — Recalculate `lifetime_total_amount` and `donation_count` aggregates on spine
3. **Run Migration 086 Block C** — Insert ~71K WinRed donors missing from spine
4. **Verify Hetzner psql** — Confirm connection: `psql -h [host] -U postgres -d postgres`
5. **Begin fuzzy pass planning** — Pull the 81,265 BOE records without RNCID, confirm trigram indexes exist

---

## COMPLETION SCORECARD

| Metric | Current | Phase 1 Target | Phase 5 Target |
|---|---|---|---|
| Spine rows | 337K | ~408K | ~408K |
| Spine RNCID % | 56.2% | ~60% | ~80% |
| BOE match rate | 54.1% | 54.1% | ~85% |
| WinRed on spine | 0% | ~60% | ~60% |
| Spine enrichment | 0/10 fields | 0/10 | 10/10 |
| Intelligence feed | Not built | Not built | LIVE |
| Contribution map | 4.0M rows | ~4.1M | ~4.4M |

---
*Master Plan — BroyhillGOP | Last Updated: 2026-04-23 by Perplexity AI*
