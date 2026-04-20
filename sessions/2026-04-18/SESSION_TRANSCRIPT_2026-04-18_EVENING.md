# Session Transcript — 2026-04-18 Evening (Nexus / Perplexity Computer)

**Session window:** ~20:00 – 22:15 EDT (Saturday, April 18, 2026)
**Agent:** Nexus (Perplexity Computer — Claude Sonnet 4.6)
**Ed's goal:** Get Nexus connected to Hetzner postgres, then run committee party rollup for cluster 372171

---

## Context going in

- Stage 1 (`core.donor_profile`, 98,303 rows, canary ✅) had just been completed by the prior Nexus session (16:00–19:45 EDT).
- Accountability doc written and committed to `sessions/2026-04-18/ACCOUNTABILITY_2026-04-18.md`.
- Hetzner server `37.27.169.232` was under Hetzner network lock (abuse from April 17 masscan).
- Tailscale pre-auth key was in session context: `tskey-auth-kiGcp9UYvZ11CNTRL-GWtR234giMTLgmMVuDXNMTp95Uq1aq6h5` (expires 2026-07-17).
- Ed's Mac can reach server via `ssh root@hetzner-1` (Tailscale IP 100.108.229.41).
- Sandbox egress IP: `136.109.176.148`.

---

## What happened

### 1. Tailscale onboard attempted — failed (sandbox APIPA networking)

Nexus installed Tailscale on the sandbox (`tailscaled --tun=userspace-networking`) and attempted auth with the pre-auth key. The Tailscale daemon reached the control plane (HTTP 200 confirmed) but auth never completed. Root cause: sandbox's `eth0` interface has a `169.254.0.21/30` APIPA link-local address. Tailscale sees `v4=false`, cannot establish WireGuard peers. Repeated attempts all timed out with `Logged out` status.

**Conclusion: Tailscale cannot work from Perplexity's sandbox due to APIPA networking. This is a hard infrastructure constraint, not a key or config problem.**

### 2. Direct port 5432 attempted — blocked by Hetzner network lock

TCP to `37.27.169.232:5432` timed out. The Hetzner network lock from the April 17 abuse incident blocks all external traffic to the server's public IP at the datacenter edge, above UFW. The UFW rule for sandbox IP was added (see below) but makes no difference while the Hetzner lock is in effect.

**Note:** `listen_addresses = '*'` confirmed, pg_hba.conf entry added for `136.109.176.148/32 scram-sha-256`. These changes are in place and will work the moment Hetzner lifts the network lock.

### 3. Server configuration work completed (via Ed's terminal relay)

Ed was SSH'd into `root@broyhillgop-db` (the server itself). The following was completed:

| Action | Result |
|---|---|
| `grep listen_addresses /etc/postgresql/16/main/postgresql.conf` | Already `*` — no change needed |
| `echo "host postgres postgres 136.109.176.148/32 scram-sha-256" >> /etc/postgresql/16/main/pg_hba.conf` | ✅ Added |
| `pg_ctlcluster 16 main reload` | ✅ Done |
| `/usr/sbin/ufw allow from 136.109.176.148 to any port 5432 proto tcp comment 'nexus-sandbox'` | ✅ Added |

### 4. Bore.pub tunnel attempted — never confirmed

Ed ran on the server:
```bash
curl -sL https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz | tar xz -C /tmp && /tmp/bore local 5432 --to bore.pub
```
The command started but Ed never pasted back the port number. Session ended before tunnel was confirmed.

### 5. Committee party rollup — NOT run

The query was ready (see next session TODO). Never executed because no live database connection was established.

---

## What was NOT accomplished

- Direct Nexus → Hetzner postgres connection (blocked, per above)
- Committee party rollup for cluster 372171
- Pre-flight checks via direct connection
- `public.session_state` update on Hetzner

---

## Infrastructure state as of session end

| Item | Status |
|---|---|
| `core.donor_profile` (Hetzner) | ✅ 98,303 rows, canary 147/$332,631.30/ed@broyhill.net |
| Hetzner network lock (public IP) | 🔴 Still in effect — reply to Hetzner abuse email to lift |
| UFW rule for sandbox | ✅ Added (will activate once lock lifts) |
| pg_hba.conf for sandbox | ✅ Added |
| listen_addresses | ✅ `*` |
| Bore binary | ✅ At `/tmp/bore` on server (may be cleared on reboot) |
| Bore tunnel port | ❌ Not confirmed |
| Dropbox nightly backup | 🔴 Still broken since April 14 (rclone config) |
| Tailscale on sandbox | ❌ Hard constraint — APIPA networking |

---

## TODO for next session (in priority order)

1. **Open bore tunnel** — From `root@broyhillgop-db`, run bore and paste port to Nexus. Then complete pre-flight + committee rollup.
   ```bash
   curl -sL https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz | tar xz -C /tmp && /tmp/bore local 5432 --to bore.pub
   ```
2. **Reply to Hetzner abuse report** to lift network lock on 37.27.169.232 (permanent fix for direct access).
3. **Run pre-flight** (session state, row counts, canary) via live connection.
4. **Committee party rollup for cluster 372171** — query ready (see below).
5. **Stage 1b bridge** — SIC/NAICS / dark-donor classification. Files committed at `sessions/2026-04-18/donor_profile_stage1/01b_bridge_ddl.sql` + `02b_business_address_bridge.sql`. Not yet run.
6. **Fix Dropbox backup** — re-run `rclone config` as postgres user on Hetzner.
7. **Update `public.session_state`** on Hetzner.

---

## Prepared query: committee party rollup for cluster 372171

Note: `public.committee_registry` does not exist on Hetzner. Need to discover the correct committee table. Run this discovery first:

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'committee'
   OR table_name ILIKE '%committee%'
   OR table_name ILIKE '%registry%'
ORDER BY 1, 2;
```

Then adapt this rollup:
```sql
WITH ed AS (
  SELECT * FROM raw.ncboe_donations WHERE cluster_id = 372171
),
party AS (
  SELECT
    ed.committee_sboe_id,
    ed.committee_name,
    r.committee_type,
    ed.norm_amount,
    ed.date_occurred
  FROM ed
  LEFT JOIN <committee_table> r ON r.sboe_id = ed.committee_sboe_id
  WHERE r.committee_type IN ('PARTY','COUNTY_PARTY','REC','COUNTY_REC','CAUCUS')
)
SELECT committee_type, COUNT(*) AS txns, SUM(norm_amount) AS total
FROM party
GROUP BY committee_type
ORDER BY total DESC;

SELECT 'GRAND TOTAL', COUNT(*), SUM(norm_amount) FROM party;
```

---

*Written by Nexus — 2026-04-20 10:30 AM EDT as part of session archiving per Ed's direction.*
