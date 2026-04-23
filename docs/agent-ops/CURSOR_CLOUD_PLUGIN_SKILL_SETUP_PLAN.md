# Cursor Cloud Plugin + Skill Setup Plan
**Date:** 2026-04-23  
**Owner:** Nexus/Cursor session  
**Scope:** Make model escalation explicit and add reusable operational skills for DB sessions.

## Goals
- Add a clear rule for when to escalate to an additional model (`composer-2-fast` subagent).
- Reduce repeated environment friction in Cursor Cloud (missing `psql`, missing `nc`).
- Standardize reconnect + smoke + canary checks for Hetzner PostgreSQL sessions.

## Environment Additions (Cloud Image)
Add these packages to the base cloud environment so DB diagnostics are one-command:
- `postgresql-client`
- `netcat-openbsd`
- `jq`
- `dnsutils`

## Plugin / Tooling Additions (Recommended)
1. **Postgres query MCP (read-only default)**
   - Purpose: schema introspection, smoke checks, canary queries without shell bootstrapping.
2. **Session diagnostics MCP**
   - Purpose: capture egress IP, DNS, TCP, SSL mode probes in one report.

## New In-Repo Skills Added
1. `skills/db-smoke-canary/SKILL.md`
   - Canonical smoke and canary flow before any data operation.
2. `skills/hetzner-postgres-connectivity/SKILL.md`
   - Deterministic troubleshooting for handshake, pg_hba, firewall, and SSL-mode issues.
3. `skills/cloud-env-bootstrap/SKILL.md`
   - Minimal cloud host prep for DB work (`psql`, `nc`, verification commands).

## Model Strategy Update
- Default: current session model for normal implementation and reporting.
- Escalate to `composer-2-fast` subagent when tasks require:
  - broad parallel codebase exploration,
  - iterative debug loops,
  - multi-path hypothesis checks.
- Keep final edits, git operations, and user summary in the main session.

## Operational Guardrails
- Never run destructive SQL without explicit authorization.
- Always run smoke + canary before migrations, bulk updates, or ingestion.
- If connectivity blocks smoke/canary, stop and report blocker details immediately.

## Rollout Checklist
- [x] Update startup protocol to include model escalation rules.
- [x] Add this setup plan doc.
- [x] Add three operational skills under `skills/`.
- [ ] Integrate cloud image dependency changes via env setup agent.
- [ ] (Optional) Add Postgres/diagnostics MCP servers after governance approval.

## Suggested Env Setup Agent Prompt
Use this at <https://cursor.com/onboard>:

`Update my Cursor Cloud environment for broyhill/BroyhillGOP. Add postgresql-client, netcat-openbsd, jq, and dnsutils to the base image. Keep Python + psycopg2 available. Validate with: psql --version, nc -h, jq --version, and a smoke command template for Postgres connectivity.`
