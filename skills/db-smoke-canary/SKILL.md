---
name: db-smoke-canary
description: Use when starting or reconnecting any BroyhillGOP database session and you must run smoke connectivity plus Ed canary checks before operational work.
---

# DB Smoke + Canary

Run this before database implementation, migrations, or bulk data operations.

## Quick checklist

1. Confirm connection settings for the current session.
2. Run TCP reachability test to DB host/port.
3. Run SQL smoke test (`SELECT 1`).
4. Run spine baseline count query.
5. Run Ed canary query (cluster `372171`).
6. Report results and stop if baseline/canary diverges.

## Commands

Use Python because cloud agents may not have `psql` installed.

```bash
python3 - <<'PY'
import socket, psycopg2
from psycopg2.extras import RealDictCursor

HOST='37.27.169.232'; PORT=5432; DB='broyhillgop'; USER='postgres'; PWD='[PASSWORD_FROM_1PASSWORD]'

try:
    s=socket.create_connection((HOST,PORT), timeout=5); s.close()
    print("TCP_OK")
except Exception as e:
    print("TCP_FAIL", e)
    raise SystemExit(1)

conn=psycopg2.connect(host=HOST, port=PORT, dbname=DB, user=USER, password=PWD, sslmode='prefer', connect_timeout=10)
cur=conn.cursor(cursor_factory=RealDictCursor)

cur.execute("SELECT 1 AS smoke;")
print("SMOKE", cur.fetchone())

cur.execute("""
SELECT COUNT(*) AS rows, COUNT(DISTINCT cluster_id) AS clusters
FROM raw.ncboe_donations;
""")
print("SPINE_BASELINE", cur.fetchone())

cur.execute("""
SELECT
  cluster_id,
  COUNT(*) AS txns,
  SUM(norm_amount) AS total,
  MAX(personal_email) AS p_email
FROM raw.ncboe_donations
WHERE cluster_id = 372171
GROUP BY cluster_id;
""")
print("ED_CANARY", cur.fetchone())

cur.close(); conn.close()
PY
```

## Expected values (current baseline)

- Spine: `321,348` rows and `98,303` clusters
- Ed canary: `147` txns, `$332,631.30`, `p_email=ed@broyhill.net`

If you see old inflated values (`627`, `$1.3M`) or a different canary email, stop and report before any write operation.

## Common mistakes

- Skipping smoke and only testing TCP.
- Using stale canary values from older transcripts.
- Running write operations while canary status is unknown.
