# 🚀 BROYHILLGOP — CURSOR SESSION START
## Paste this at the top of every new Composer session

---

## WHO YOU ARE WORKING WITH

**Eddie Broyhill** — NC Republican National Committeeman. Building BroyhillGOP, a fully AI-automated political campaign management platform for NC Republicans.

---

## WHAT THIS PROJECT IS

- **61 ecosystems** (E00–E60, E59 skipped) — each is a self-contained AI-powered module
- **Supabase project:** `isbgjpnbocdkeslofota` — 1,187 tables across 18 schemas
- **Canonical repo:** `github.com/broyhill/BroyhillGOP` (public) — only source of truth
- **Two Hetzner servers:** GEX44 relay (5.9.99.109) and AX41-NVMe main (144.76.219.24)
- **Latest migration:** `20260327201032` (spine_add_rnc_regid_column)

---

## ⚠️ GOVERNANCE — READ BEFORE TOUCHING ANYTHING

**Two mandatory docs. Read both at session start:**

1. `docs/🛡️_AI_DEVELOPMENT_GOVERNANCE.md` — sacred tables, prohibited actions, migration standards
2. `docs/🔴_REMEDIATION_ROADMAP_MAR28.md` — current known issues, prioritized fixes, what is healthy

**These exist because previous AI sessions degraded the database through autonomous decisions. You are bound by the governance doc.**

---

## DATABASE HEALTH SNAPSHOT (as of 2026-03-28 audit)

### ✅ HEALTHY — Do Not Touch
| Table | Rows | Notes |
|-------|------|-------|
| `nc_voters` | 9,082,810 | Full NCSBE voter file — backbone intact |
| `nc_datatrust` | 7,655,593 | DataTrust enriched 251-col voter file |
| `rnc_voter_staging` | 7,708,542 | RNC match staging |
| `rnc_voter_core` | 1,106,000 | Perfect PK, clean |
| `rnc_political_geography` | 1,105,000 | Cleanest table in RNC family |
| `fec_donations` | 2,591,933 | 11 years FEC data (minor date issues) |
| `donor_voter_links` | 309,103 | Exists but 65.4% orphaned — see roadmap |
| `person_source_links` | 1,846,282 | Identity graph backbone |

### 🔴 CRITICAL KNOWN ISSUES
| Issue | Table | Status |
|-------|-------|--------|
| `party` column contains FEC cycle years | `fec_committees` | 99.8% broken — fix is in roadmap |
| 65.4% of donor→voter links are orphaned | `donor_voter_links` | 202,143 links point nowhere |
| `transaction_date` stored as TEXT `MMDDYYYY` | `fec_party_committee_donations` | 1.7M rows — all temporal analysis blocked |
| `volunteer_score` 100% NULL | `rnc_proprietary_scores` | 1.1M rows — never populated |
| `last_gift` = year 9007 | `nc_donor_summary` | Propagated from NCBOE future dates |
| Corrupt dates year 1015 / 2106 | `fec_donations` + `fec_god_contributions` | 3 shared rows — quarantine by sub_id |
| $32.2M cash_amount | `winred_donors` | Impossible individual contribution |
| NCBOE absent from contribution map | `donor_contribution_map` | $218M NC giving invisible |

### ⭕ EMPTY TABLES (schema defined, no data)
`contacts`, `households`, `donor_accounts`, `donor_scores`, `candidate_profiles`, `compliance_violations`

---

## YOUR MCP TOOLS — USE THEM DIRECTLY

Do not ask Eddie to run commands. Use your tools.

| Tool | What it gives you |
|------|-------------------|
| **supabase** (29 tools) | Direct DB — execute SQL, apply migrations, check schema |
| **github** (26 tools) | Read/write repo, push migrations |
| **hetzner** (9 tools) | SSH both servers, health checks, logs |

**DB password:** `ZODTJq9BAtAq0qYF`

---

## PROJECT STRUCTURE

```
ecosystems/          ← 58 Python ecosystem files (E00–E57 built)
database/migrations/ ← SQL migrations (numbered NNN_NAME.sql)
docs/
  🛡️_AI_DEVELOPMENT_GOVERNANCE.md   ← READ FIRST
  🔴_REMEDIATION_ROADMAP_MAR28.md   ← Current fix priorities
  🚨_ECOSYSTEM_COMPLETION_TRACKER.md ← Ecosystem status
  god E60_ADDICTION_PSYCHOLOGY_ENGAGEMENT_ENGINE.docx ← E60 blueprint
hetzner_mcp/server.py  ← Hetzner MCP (Python 3.14)
.cursor/mcp.json       ← MCP config
CURSOR_WAKE_UP.md      ← This file
```

---

## OUTSTANDING ECOSYSTEM WORK

| Item | Status | Notes |
|------|--------|-------|
| **E58** | ❌ No code, no blueprint | Business model ecosystem |
| **E60** | ❌ Blueprint only | Engagement engine — blueprint in docs/ |
| **Database remediation** | 🔄 Active | See 🔴_REMEDIATION_ROADMAP_MAR28.md |
| **Frontend** | ⏳ After DB | Inspinia-based UI |

---

## SESSION PROTOCOL

1. Read `docs/🛡️_AI_DEVELOPMENT_GOVERNANCE.md`
2. Read `docs/🔴_REMEDIATION_ROADMAP_MAR28.md`
3. Run: `SELECT tablename, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 20` to verify current DB state
4. Ask Eddie: **"What are we working on today?"**
5. Work autonomously. Report what you did. Ask only for business decisions.
