---
name: cloud-env-bootstrap
description: Use when a cloud agent starts in a minimal runtime and missing CLI tools block required verification or database workflows.
---

# Cloud Env Bootstrap

## Overview
Standardize first-run environment checks in minimal cloud agents so required diagnostics run reliably.

## When to Use
- `psql`, `nc`, or similar diagnostics are missing.
- Connection workflows stall due to tooling gaps, not business logic.
- Repeated sessions spend time rediscovering the same missing dependencies.

## Baseline
1. Check current tool availability:
   - `python3 --version`
   - `python3 -m pip --version`
   - `psql --version`
   - `nc -h`
2. Capture public egress IP:
   - `curl -sS ifconfig.me`
3. Verify Python DB client:
   - `python3 -c "import psycopg2; print('ok')"`

## Package Policy
- Prefer user-space installs when root package installs are blocked.
- Keep bootstrap commands idempotent.
- Never install extra tooling beyond what runbooks require.

## Recommended Startup Script
- Put this in cloud image startup config when possible:
  - `python3 -m pip install --user psycopg2-binary`
  - install PostgreSQL client package if base image allows apt/yum
  - install netcat package if base image allows apt/yum

## Output Contract
When bootstrap is complete, report:
- Installed vs unavailable tools
- Egress IP
- Whether DB smoke tests are now runnable

## Common Mistakes
- Treating missing CLI tools as a DB outage.
- Installing broad dependency bundles when only two tools are needed.
- Failing to re-run smoke tests after bootstrap.
