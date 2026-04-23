---
name: hetzner-postgres-connectivity
description: Use when database connections to Hetzner PostgreSQL fail, partially connect, or are unstable and you need a strict reachability/authentication triage workflow.
---

# Hetzner PostgreSQL Connectivity Triage

## Overview

Use this skill to diagnose connectivity failures in a fixed order that separates network issues from PostgreSQL handshake/auth issues.

## When to Use

- `OperationalError` during connect
- TCP reachable but PostgreSQL closes connection
- SSL mode uncertainty (`prefer` vs `require` vs `disable`)
- Need to provide exact egress IP to infrastructure owner

## Triage Order (Do Not Skip)

1. Confirm target DSN (host, port, dbname, user, sslmode).
2. Run raw TCP connect check.
3. Run psycopg2 connect tests in explicit ssl modes.
4. Capture current egress IP.
5. Return raw outputs with no assumptions.

## Commands

### 1) TCP and SSL matrix test

```bash
python3 - <<'PY'
import socket, psycopg2

host='37.27.169.232'; port=5432
db='broyhillgop'; user='postgres'; pw='MelanieRNC2026$'

try:
    s = socket.create_connection((host, port), timeout=5)
    s.close()
    print('TCP: ok')
except Exception as e:
    print(f'TCP: FAIL -> {e}')

for mode in ['require','prefer','disable']:
    try:
        c = psycopg2.connect(host=host, port=port, dbname=db, user=user, password=pw, sslmode=mode, connect_timeout=8)
        cur = c.cursor()
        cur.execute('SELECT version()')
        print(f'SSL-{mode}: ok -> {cur.fetchone()[0][:60]}')
        cur.close(); c.close()
    except Exception as e:
        print(f'SSL-{mode}: FAIL -> {type(e).__name__}: {str(e)[:220]}')
PY
```

### 2) Egress IP capture

```bash
curl -sS ifconfig.me
```

## Reporting Format

- Include exact command output blocks verbatim.
- If user requested "no interpretation", provide only raw outputs.
- If interpretation is allowed, classify:
  - `TCP FAIL` = network/firewall path issue.
  - `TCP ok + SSL FAIL` = PostgreSQL/auth/pg_hba/SSL policy path issue.

## Common Mistakes

- Guessing pg_hba issue without running ssl mode matrix.
- Reporting old egress IP from prior run.
- Mixing credentials from stale docs without stating which DSN was tested.
