# Infrastructure State — BroyhillGOP / Nexus

**Authoritative source of truth for the Hetzner estate and related infrastructure.**

Updated every `NEXUS Sleep` ritual. If this file disagrees with memory, chat, or
any other doc, THIS FILE WINS. If Nexus reads this file at startup and finds a
status that no longer matches reality, Nexus stops and reconciles with Ed
before touching anything.

- **Last updated:** 2026-04-18 12:00 EDT
- **Updated by:** Nexus (session 2026-04-18 morning, Hetzner estate reconciliation)
- **Next scheduled update:** at `NEXUS Sleep` close of this session

---

## 1. SERVER ESTATE — 3 SERVERS

All three are Hetzner dedicated. Managed via [Robot](https://robot.hetzner.com).
Hetzner customer number: **K1268625125**. Customer of record: **Mr Ed Broyhill /
BroyhillGOP**, `ed.broyhill@gmail.com`.

| # | Robot ID | Model | IPv4 | IPv6 | DC | Role | Status |
|---|---|---|---|---|---|---|---|
| 1 | #2973063 | AX162-R | **37.27.169.232** | 2a01:4f9:3071:35ea::2 | HEL1-DC7 (Helsinki) | **Prod Postgres** — 238 GB DB, system of truth, 47 GB pg_dump → Dropbox nightly | LOCKED by abuse team (2026-04-17 masscan incident) — unlock reply sent 2026-04-18 |
| 2 | #2882435 | GEX44 | **5.9.99.109** | 2a01:4f8:162:316a::/64 | FSN1-DC7 (Falkenstein) | **DataTrust whitelist relay** (IP whitelisted at RNC for 2,200-variable DataHub feed), `relay.py` v1.4 FastAPI on :8080, SPINE-DONOR-CORRECTION-PLAN.md served on :9090, GOD File index (8,549 files), `/opt/broyhillgop/` planning docs | LOCKED by suspension team (2026-04-15 DDoS) — Ticket 2026041803003181 / L002B78C8 — unlock reply sent 2026-04-18 (whitelist path chosen) |
| 3 | #2955738 | AX41-NVMe | **144.76.219.24** | 2a01:4f8:200:9206::/64 | FSN1-DC11 (Falkenstein) | **Secondary / Old Hetzner 2** — 2× 477 GB NVMe RAID1. Purpose to be re-inventoried. NOT a GPU box despite stale notes. | In **rescue mode** as of 2026-04-18 11:22 EDT. No file access attempted. |

### Canonical corrections applied 2026-04-18
- **Estate size is THREE, not two.** Previous session state had only two.
- **#2955738 is AX41-NVMe, NOT a GPU / RTX 4000.** Prior notes mislabeled it.
- **Server 2 (5.9.99.109) is NOT retired.** It holds the RNC DataTrust
  whitelist — a strategic asset. Do not suggest returning the product.
- **Server 3 (144.76.219.24) role is still being reconciled with Ed.**
  Do not installimage, wipe, mount, or inspect files without explicit
  authorization.

---

## 2. HETZNER TICKETS / ABUSE / THREADS

| Server | Type | Hetzner identifier | Contact | Gmail thread | Status |
|---|---|---|---|---|---|
| 37.27.169.232 | Abuse | **2604:G1218ROETADB** | `abuse-network@hetzner.com` | `19d990320d06f88a` | Reply SENT 2026-04-18 |
| 5.9.99.109 | Suspension | **Ticket#2026041803003181 / Procedure L002B78C8** | `suspension-network@hetzner.com` | `19d9ded59d1dc1df` | Reply SENT 2026-04-18; Hetzner confirmed whitelist path is "available all the time"; Ed to paste home IP in Robot→Server locking when ready |

### Whitelist status
- Ed home public IP: **174.111.16.88** (Spectrum, Greensboro NC — verified live 2026-04-18 11:37 EDT via whatismyipaddress.com)
- NOT yet pasted into Robot → Servers → 5.9.99.109 → Server locking. Ed deferred — "maybe wait."
- Whitelist entry auto-expires 2 hours after insertion. Do not paste until Ed is ready to do the rebuild work in the same window.

---

## 3. CREDENTIALS — POINTER ONLY

**All live credentials:** `/home/user/workspace/HETZNER_NEW_CREDS.txt`

Nexus MUST read that file at startup and MUST never embed passwords in this
state doc. If a credential appears here, delete it and move it to
`HETZNER_NEW_CREDS.txt`.

Rescue passwords that may still be live (auto-expire 60 min if unused):
- 37.27.169.232: see `HETZNER_NEW_CREDS.txt` (armed 2026-04-18 11:14 EDT) — **DO NOT REBOOT**; prod Postgres. Server is network-locked anyway so rescue is unreachable.
- 144.76.219.24: see `HETZNER_NEW_CREDS.txt` (armed 2026-04-18 11:19 EDT, active — box is in rescue now)

---

## 4. FIREWALL / NETWORK POSTURE (37.27.169.232)

| Port | Service | Allowlist |
|---|---|---|
| 22 | SSH | anyone (protected by fail2ban; 4 IPs banned as of rotation) |
| 5432 | Postgres | 174.111.16.88 (Ed home), 34.57/34.72 (sandbox), 34/35/104 /8 (Vercel/Google egress) |
| 4399 | 1Panel | 174.111.16.88 only |
| 8080 | Relay (legacy; real relay lives on 5.9.99.109) | 174.111.16.88 only |
| 8317 | (masscan attacker port) | **DENY IN + OUT** permanently |

fail2ban active on sshd. `PermitRootLogin prohibit-password`,
`PasswordAuthentication no` — key-only after rotation.

---

## 5. BACKUPS

| Item | Value |
|---|---|
| Method | `pg_dump --format=directory --compress=6 --jobs=8` → `rclone → dropbox:BroyhillGOP/backups/daily/` |
| Schedule | `0 3 * * *` (3:00 AM CEST) in `postgres` crontab |
| Script | `/opt/pgbackup/scripts/daily_snapshot_dropbox.sh` |
| Local retention | 3 days |
| Dropbox retention | 14 days |
| **Current state** | **DUMP succeeds. UPLOAD FAILS since 2026-04-14 (rclone config lost in credential rotation). Local dumps piling up. No fresh Dropbox backup since rotation.** |
| Fix required | `rclone config` as postgres user on Hetzner — re-authorize Dropbox remote. Blocked until 37.27 unlocked. |

PITR base backup separately at 2:00 AM CEST (continuous WAL replay).

---

## 6. SESSION STATE — DATABASE

Live session state rows are in `public.session_state` on Hetzner Postgres.
Read with:
```sql
SELECT state_md FROM public.session_state ORDER BY id DESC LIMIT 1;
```
Not reachable right now (37.27 locked). Nexus Sleep must write a session_state
row when Postgres is reachable again. If Nexus Sleep runs while DB is
unreachable, record the block in this file AND in `HETZNER_NEW_CREDS.txt`
timestamp log AND attempt the write on next successful startup.

**Last verified canary:** cluster 372171 = 147 txns / $332,631.30 / ed@broyhill.net (verified 2026-04-17 23:59 EDT). Re-verify on next successful DB connection.

---

## 7. SESSION LOG (rolling, most recent first)

### 2026-04-18 — morning (Ed iPhone, no laptop)
- Started the morning LOCKED on all 3 servers' unlock status
- Nexus drift: initially reported 2-server estate (wrong), called #2955738 a "GPU RTX 4000" (wrong — it's AX41-NVMe with 2× NVMe RAID1), asked Ed for his home IP that was already on file
- Corrective: Ed pushed back; Nexus re-read `NEXUS_STARTUP_PREREQUISITE.md` + `HETZNER_NEW_CREDS.txt` + searched GitHub for credentials
- Drafted + sent unlock replies for both 37.27 (abuse) and 5.9.99.109 (suspension); drafts threaded correctly to Gmail
- 144.76.219.24 rebooted into rescue mode (verified via SSH banner + rescue password works); no further action
- Ed deferred whitelisting 174.111.16.88 on Robot for 5.9.99.109 — "maybe wait"
- Discussed and approved: new `nexus` skill with `NEXUS Sleep` close-out ritual; this file is the first artifact

### 2026-04-17 — evening
- Masscan containment on 37.27.169.232; persistence stubs removed (`systemd.service`, `observed.service`, 0-byte `chattr +i` payloads in `/usr/local/bin/`)
- Credentials rotated (new password in `HETZNER_NEW_CREDS.txt`); `.env` + backup script updated
- UFW locked down (deny 8317 in+out; allowlisted Postgres to Ed+sandbox+Vercel/Google /8)
- Tumor cleanup: dropped `raw.ncboe_donations_inflated`, `raw.ncboe_donations_pre_dedup`, `donor_intelligence.mv_donor_totals`
- Sacred spine confirmed: 321,348 rows / 98,303 clusters

---

## 8. OPEN WORK — INFRASTRUCTURE TRACK

- [ ] Wait for Hetzner abuse team to respond on 37.27.169.232
- [ ] Wait for Hetzner suspension team to respond on 5.9.99.109 (or Ed paste 174.111.16.88)
- [ ] Decide fate of 144.76.219.24 (currently in rescue) — inspect filesystem read-only OR reboot back to normal OR installimage rebuild
- [ ] Once 37.27 unlocked: fix rclone Dropbox config → restore nightly backup chain
- [ ] Once 37.27 unlocked: write session_state row reflecting April 18 session
- [ ] Draft the `hetzner-estate`/`nexus` skill (in progress)
- [ ] Commit `/home/user/workspace/skills/user/nexus/` + this file to `broyhill/BroyhillGOP/sessions/2026-04-18/`

## 9. OPEN WORK — BUSINESS MACHINE / DONOR IDENTITY TRACK

26 tasks across T0.x–T5.x remain untouched since 2026-04-17. All blocked on
37.27.169.232 being reachable. See `/home/user/workspace/extensive_todo_2026-04-18`
for the full list. Natural resume point when DB is reachable: **T0.1 —
rebuild `ref.business_address`** so `is_manual_business` / `is_owned_property`
/ `is_ed_enterprise` are inputs to the GENERATED column `is_business`.

---

*This file is maintained by Nexus. Update only via `NEXUS Sleep` close-out or
explicit repair commits. Never let memory / chat / transcripts override this
file.*
