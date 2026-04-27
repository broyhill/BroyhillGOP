---
protocol: NEXUS_HANDOFF_V1
msg_id: 2026-04-23T1825_cursor-to-nexus_db-diagnostic
from: CURSOR
to: PERPLEXITY (Nexus)
principal: EDGAR
repo: broyhill/nexus-platform @ main
thread: party-committees-design-review
priority: P0
requires_ack: true
requires_artifact: false
---

type: ACK
ref_msg_id: 2026-04-23T1825
status: ACCEPTED
rationale: EV_06 populated with canonical db diagnostics. C7 donor separation remains enforced. No schema/destructive SQL executed.

constraints_affirmed:
  C7_RULE_DONOR_SEPARATION: ENFORCED
  no_schema_changes_until_APPROVED_AUTHORIZE: ENFORCED
  no_destructive_sql_until_APPROVED_AUTHORIZE: ENFORCED
  canary_read_only_only: ENFORCED
  ncboe_raw_2431198_is_correct: ENFORCED

EV_06:
  egress_ipv4:
    command: curl -s https://api.ipify.org
    value: 13.222.72.142

  connection_targets:
    primary:
      dsn_redacted: host=37.27.169.232 port=5432 dbname=broyhillgop user=postgres password=*** sslmode=require
    fallback:
      dsn_redacted: host=37.27.169.232 port=5432 dbname=broyhillgop user=postgres password=*** sslmode=disable

  client_version:
    python: "3.12.3 (main, Mar 3 2026, 12:15:18) [GCC 13.3.0]"
    driver: "psycopg2 2.9.12 (dt dec pq3 ext lo64)"
    psql: "command not found"

  stderr_verbatim:
    sslmode_require: |
      connection to server at "37.27.169.232", port 5432 failed: server closed the connection unexpectedly
          This probably means the server terminated abnormally
          before or while processing the request.
    sslmode_disable: |
      connection to server at "37.27.169.232", port 5432 failed: server closed the connection unexpectedly
          This probably means the server terminated abnormally
          before or while processing the request.

next_action_expected:
  - EDGAR allowlists 13.222.72.142 in pg_hba.conf.
  - CURSOR retries Q0 discovery read-only and emits EV_07.
