# BroyhillGOP — Session State
**Last updated: 2026-04-20 10:30 AM EDT by Nexus (Perplexity Computer)**

---

## Current Canary (memorize this)

| Field | Value |
|---|---|
| Table | `raw.ncboe_donations` on Hetzner |
| Cluster | 372171 (Ed Broyhill / James Edgar Broyhill II) |
| Transactions | **147** |
| Total | **$332,631.30** |
| Email | **ed@broyhill.net** |

If you see 627 txns or $1.3M → you are querying a dropped inflated table. Stop.
If you see `jsneeden@msn.com` → Apollo bad data. Clear it.

---

## Truth Source

**Hetzner prod-db is the truth source for all donor and voter data.**
Supabase is legacy, READ ONLY, limited scope: `brain.agent_messages`, `brain.decisions`, Storage bucket `nc-donors-raw`.

| Host | Purpose | Connection |
|---|---|---|
| `37.27.169.232` (broyhillgop-db) | Prod postgres — ALL real data | SSH via Tailscale only (public IP network-locked by Hetzner post-abuse) |
| `100.108.229.41` | Tailscale IP of prod-db | `ssh root@hetzner-1` from Ed's Mac |
| Postgres password | `XanypdTxZb3qRE8bUdGXFGGK` | Port 5432, db: postgres, user: postgres |
| PostgreSQL version | 16 | Config: `/etc/postgresql/16/main/` |

---

## Row Counts (post April 17 tumor cleanup)

| Table | Rows | Notes |
|---|---|---|
| `raw.ncboe_donations` | **321,348** | Sacred — post-dedup spine. NEVER drop/truncate. |
| `raw.ncboe_donations` clusters | **98,303** | Distinct cluster_ids |
| `core.datatrust_voter_nc` | 7,727,637 | DataTrust 252-col voter file |
| `core.donor_profile` | **98,303** | Stage 1 complete ✅ (April 18, 2026) |
| `core.donor_profile` voter-matched | **80,605** | 82% match rate |
| `core.acxiom_ap_models` | 7,655,593 | Acxiom scores |

---

## What Is Complete

| Item | Status | Date |
|---|---|---|
| NCBOE dedup (ncboe_dedup_v2.py) | ✅ Done | April 17 |
| Tumor cleanup (2.4M → 321,348) | ✅ Done | April 17 |
| DataTrust voter enrichment | ✅ Done | April 17 |
| `core.donor_profile` Stage 1 populate | ✅ Done | April 18 |
| Stage 1 canary verified | ✅ 147/$332,631.30/ed@broyhill.net | April 18 |
| UFW rule for sandbox IP (136.109.176.148) | ✅ Added | April 18 |
| pg_hba.conf for sandbox IP | ✅ Added | April 18 |

---

## What Is Pending (in priority order)

| Item | Notes |
|---|---|
| **Bore tunnel OR Hetzner lock lift** | Bore binary at `/tmp/bore` on server. Run: `curl -sL https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz \| tar xz -C /tmp && /tmp/bore local 5432 --to bore.pub` — paste port to Nexus. Permanent fix: reply to Hetzner abuse email. |
| **Committee party rollup for cluster 372171** | Discover committee table in `committee` schema first. Query ready in `sessions/2026-04-18/SESSION_TRANSCRIPT_2026-04-18_EVENING.md`. |
| **Stage 1b business-address bridge** | Files committed at `sessions/2026-04-18/donor_profile_stage1/01b_bridge_ddl.sql` + `02b_business_address_bridge.sql`. NOT RUN. |
| **Fix Dropbox nightly backup** | rclone config broken since April 14. Re-run `rclone config` as postgres user. |
| **Backfill `candidate_name` on 88,256 downballot 'U' rows** | Per `sessions/2026-04-18/phase2_committee_replication/MATCH_RATE_DIAGNOSIS.md` |
| **Update `public.session_state` on Hetzner** | Not updated since April 17 (no live connection in April 18 evening session) |
| **Drop stale Supabase tables** | After confirming Hetzner parity: `staging.boe_donation_candidate_map`, `public.nc_boe_donations_raw`, `secondary.nc_boe_party_committee_donations`, `public.committee_registry` |

---

## Sandbox Connection Notes (for Nexus)

The Perplexity sandbox **cannot** use Tailscale (APIPA `169.254.x.x` interface — hard constraint).
The sandbox egress IP is `136.109.176.148`.

**Working connection path:**
1. Ed runs bore on server: `curl -sL https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz | tar xz -C /tmp && /tmp/bore local 5432 --to bore.pub`
2. Ed pastes the `bore.pub:XXXXX` port to Nexus
3. Nexus connects: `psql -h bore.pub -p XXXXX -U postgres -d postgres`

**Permanent path (after Hetzner lock lifts):**
Direct psql to `37.27.169.232:5432` — UFW + pg_hba.conf already configured.

**Relay-only fallback:**
`ssh root@hetzner-1 "sudo -u postgres psql -d postgres -c '...'"` from Ed's Mac.

---

## Dropped Tables — DO NOT RECREATE

- `raw.ncboe_donations_inflated` (2.4M) — was the tumor. Gone.
- `raw.ncboe_donations_pre_dedup` (2.4M) — gone.
- `donor_intelligence.mv_donor_totals` — inflated rollup. Gone.

---

## Key File Locations in This Repo

| File | Purpose |
|---|---|
| `sessions/SESSION_START_READ_ME_FIRST.md` | Master startup brief for every session |
| `sessions/PERPLEXITY_SESSION_STARTER.md` | Paste-at-session-start prompt |
| `sessions/2026-04-18/ACCOUNTABILITY_2026-04-18.md` | What went wrong April 18 + rules for next Nexus |
| `sessions/2026-04-18/donor_profile_stage1/` | All Stage 1 SQL (complete) |
| `sessions/2026-04-18/SESSION_TRANSCRIPT_2026-04-18_EVENING.md` | Evening session transcript + party rollup query |
| `sessions/2026-04-18/phase2_committee_replication/` | Phase 2 committee work (partial) |
| `sessions/2026-04-18/infrastructure_state.md` | Hetzner infrastructure state |

---

*Nexus is the Perplexity Computer agent identity for BroyhillGOP database sessions. It loads `database-operations`, `incident-response`, `donor-attribution`, and `broyhillgop-architecture` skills at every session start.*
