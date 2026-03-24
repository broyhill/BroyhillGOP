# BroyhillGOP SESSION STATE
# ─────────────────────────────────────────────────────────────────────────────
# This file is the single source of truth for both agents (Perplexity + Claude).
# UPDATE THIS FILE at the end of every session using the format below.
# Both agents read it automatically at startup via GET /briefing.
# ─────────────────────────────────────────────────────────────────────────────

## PROJECT IDENTITY
- **Platform:** BroyhillGOP — multi-tenant SaaS for NC Republican candidates
- **Owner:** Eddie Broyhill (James Edgar Broyhill), CEO, Anvil Venture Group, Winston-Salem NC
- **Ecosystems:** 58 planned (E01–E58), E20 Brain Hub active
- **Database:** Supabase PostgreSQL — project isbgjpnbocdkeslofota
- **Server:** Hetzner GEX44 at 5.9.99.109 (root, SSH key ~/.ssh/id_ed25519_hetzner)
- **GitHub:** github.com/broyhill/BroyhillGOP (branch: main)

## INFRASTRUCTURE (live as of Mar 24 2026)
| Service       | Location                        | Port  | Status  |
|---------------|---------------------------------|-------|---------|
| ttyd terminal | http://5.9.99.109:7681          | 7681  | ✅ live  |
| Redis         | Docker bgop_redis               | 6379  | ✅ live  |
| Brain (E20)   | Docker bgop_brain               | —     | ✅ live  |
| Relay v1.1    | Docker bgop_relay               | 8080  | ✅ live  |
| Supabase DB   | db.isbgjpnbocdkeslofota.supabase.co | 5432 | ✅ live |

**Relay API Key:** `bgop-relay-k9x2mP8vQnJwT4rL`
**DB Password:** `Anamaria@2026@`

## DATABASE SCHEMA SUMMARY (19 schemas)
- **public** — operational tables (nc_voters, nc_boe_donations_raw, rncid_resolution_queue, _lookup_datatrust_all, rnc_voter_staging, agent_messages, brain_decisions)
- **archive** — backups (nc_boe_donations_raw_backup: 758,520 rows)
- **core** — contribution_map: 4,006,356 rows (authoritative financial data)
- **norm, staging, raw** — ETL pipeline layers
- Full audit: docs/BROYHILLGOP_COMPLETE_SCHEMA_AUDIT_Mar24_2026.md

## IDENTITY RESOLUTION — CURRENT STATE (as of Mar 24 2026)
| Status     | Count   | Notes                                    |
|------------|---------|------------------------------------------|
| resolved   | 79,702  | High-confidence RNCID match              |
| review     | 42,529  | Matched but needs human spot-check       |
| unresolved | 28,524  | No match found — true hard cases         |
| **TOTAL**  | **150,755** |                                      |

**Fuzzy Match v4 completed Mar 24 2026** — 3-pass SQL set-based:
- Pass 1 (exact name+zip): +225 resolved in 9.3s
- Pass 2 (last+zip+first initial): +14,407 review in 57.6s
- Pass 3 (last+first+city): +5,108 review in 105s

## KNOWN ISSUES / DO NOT REPEAT
1. `donormaster` table was DROPPED Mar 6 2026 — gone, do not reference
2. 5 pg_cron jobs are broken — reference tables/functions that don't exist
3. nc_boe_donations_raw is 132,623 rows SHORT vs archive backup — restoration pending Eddie approval
4. person_spine mislink: person_id 235240 links to NCID CY36869 (Robert Landon Jordan, son, b.1991) instead of father Robert B. Jordan IV (~63) — needs fix before Block G write-back
5. rnc_voter_core load is at 14.4% — not resumed yet
6. Golden records are broken — Ed Broyhill appears as 7+ records, Art Pope as 0
7. There is NO automated ingestion pipeline — all loads were manual

## AGENT ROLES
**Perplexity** (ttyd terminal at :7681)
- Leads all code development — designs algorithms, writes Python scripts
- Tests SQL queries, checks row counts, spots schema issues in real time
- Runs dry-runs and diagnostics directly in her terminal
- Pushes findings and tasks to Claude via POST /message

**Claude** (this chat session via Eddie's Mac)
- Verifies and reviews all code Perplexity writes before production execution
- Deploys scripts to /opt/broyhillgop/app/ via SSH/scp
- Manages systemd, Docker, screen sessions, git commits
- Reads inbox at session start — checks for Perplexity's pending messages
- Pushes results and confirmations back via POST /reply

**Both agents must:**
- Read this file at session start (auto-delivered via relay /briefing endpoint)
- Update this file at session end (broyhillgop:update-state skill)
- Follow CLAUDE_RULES.md — no destructive ops without Eddie approval
- Check agent_messages inbox before starting new work

## LAST SESSION SUMMARY (Mar 24 2026)
- Restored ttyd socket (systemd service confirmed running)
- Wrote and pushed complete schema audit to GitHub (commit 2fc69c9)
- Deep research: Robert B. Jordan IV ($541K NC donor, ~63yo, Mt. Gilead, timber/farming, WAJ Rustic Vacations). Son is Robert Landon Jordan (35yo, NCID CY36869)
- Wendy Jordan (NCID CY24646): Dem voter, gives Republican — $50K to NC GOP Council of State, $5,400 Dan Forest, Mark Robinson x3, Ben Moss
- Fuzzy Match v4 deployed and completed: 19,641 rows pulled from unresolved
- Relay v1.0 built and deployed (port 8080, FastAPI, Docker)
- Relay v1.1 upgraded: inter-agent message channel (agent_messages table + 5 endpoints)
- agent_messages table created in Supabase, channel tested end-to-end ✅

## AGREED TO-DO LIST (priority order)
- [ ] **BLOCK G WRITE-BACK** — stamp resolved RNCIDs back to nc_boe_donations_raw — NEEDS EDDIE APPROVAL
- [ ] **Fix person_spine mislink** — person_id 235240 → correct Robert B. Jordan IV NCID before write-back
- [ ] **Restore 132,623 missing rows** in nc_boe_donations_raw from archive backup — NEEDS EDDIE APPROVAL
- [ ] **Review queue decision** — 42,529 rows in 'review': auto-promote ≥0.90 confidence? Or spot-check?
- [ ] **Resume rnc_voter_core load** — currently at 14.4%
- [ ] **Fix 5 broken pg_cron jobs** — identify and either repair or drop
- [ ] **Golden record rebuild** — Ed Broyhill 7+ records, Art Pope 0 — identity resolution never properly built
- [ ] **Rebuild person_spine** — current links have errors (Jordan father/son confusion)
- [ ] **E20 outbound queue consumer** — brain.py pushes to bgop:outbound but nothing consumes it yet

## HOW TO UPDATE THIS FILE
At end of session, run: `broyhillgop:update-state` skill in Claude, or manually edit and scp:
```bash
scp -i ~/.ssh/id_ed25519_hetzner SESSION-STATE.md root@5.9.99.109:/opt/broyhillgop/SESSION-STATE.md
```
Then commit to GitHub:
```bash
git add SESSION-STATE.md && git commit -m "Update session state" && git push
```
