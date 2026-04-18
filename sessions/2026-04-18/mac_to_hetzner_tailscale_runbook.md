# Mac → Hetzner SSH Runbook (Tailscale-backed)

**Author:** Nexus · **Session:** 2026-04-18 · **Purpose:** Permanent, reproducible way for Ed (MacBook) and Nexus (Perplexity Computer sandbox) to reach the Hetzner fleet without juggling UFW whitelists, abuse locks, or rescue-mode dances ever again.

Motivation: on April 17 the box was compromised via a password that ended up in a public GitHub doc; on April 18 the UFW whitelist made the sandbox unable to reach Postgres while Hetzner's abuse lock made the edge drop all traffic to 37.27 — including SSH. Tailscale solves both.

---

## 1 · Fleet at a glance

| # | Hetzner ID | Hostname tag | Public IPv4 | Role | Tailnet name |
|---|---|---|---|---|---|
| 1 | AX162-R #2973063 | prod-db | 37.27.169.232 | Postgres 238 GB (raw.ncboe_donations) | `prod-db` |
| 2 | GEX44 #2882435 | datatrust | 5.9.99.109 | DataTrust whitelist, relay.py :8080 | `datatrust` |
| 3 | AX41-NVMe #2955738 | secondary-db | 144.76.219.24 | Secondary Postgres, backups | `secondary-db` |

All three will be members of a single tailnet. The MacBook (`broyhill-macbook`) and the Perplexity Computer sandbox (`nexus-sandbox`) join the same tailnet; every hop goes over WireGuard on the 100.64.0.0/10 CGNAT range.

---

## 2 · One-time setup on each Hetzner server

Run this once per server, via SSH over the public IP (or while the box is in rescue with the real disk chrooted). Replace `<HOSTNAME>` with `prod-db`, `datatrust`, or `secondary-db`.

### 2.1 Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### 2.2 Bring it up with the pre-auth key

```bash
# The pre-auth key lives in Ed's sandbox file HETZNER_NEW_CREDS.txt
# NEVER paste the key into a git-tracked file.
export TS_AUTHKEY='<paste tskey-auth-... here>'

tailscale up \
  --authkey="$TS_AUTHKEY" \
  --hostname=<HOSTNAME> \
  --ssh \
  --accept-routes \
  --advertise-tags=tag:hetzner-server \
  --accept-dns=false
```

Flags explained:
- `--ssh` — enables Tailscale SSH on this node. `tailscale ssh root@<hostname>` works from any tailnet member; WireGuard replaces SSH keys for discovery, but OpenSSH still authenticates with your key. No more sshd exposure to the public internet is required, though we keep it running for break-glass.
- `--accept-routes` — pick up any subnet advertisements from other tailnet members.
- `--advertise-tags=tag:hetzner-server` — required for ACL-based gating (see §5).
- `--accept-dns=false` — we keep Hetzner's resolv.conf; Tailscale MagicDNS is optional.

### 2.3 Verify

```bash
tailscale status
tailscale ip -4
systemctl is-active tailscaled     # expect: active
```

`tailscale status` should show the other fleet members once they've been added. Note the `100.x.y.z` IPv4 address — that's the tailnet address the MacBook will dial.

### 2.4 Lock down public SSH (do this AFTER Tailscale works)

Once you can SSH in via Tailscale, close port 22 on the public interface. UFW:

```bash
# Keep SSH reachable only from the tailnet interface
ufw allow in on tailscale0 to any port 22 proto tcp
ufw delete allow 22/tcp                    # if it exists as a blanket rule
ufw deny 22/tcp                            # or just delete the allow
# (If you want break-glass over public SSH from Ed's home IP, leave this:)
# ufw allow from 174.111.16.88 to any port 22 proto tcp comment 'ed-home-breakglass'
```

Do the same for Postgres so even its break-glass is cleaner:

```bash
ufw allow in on tailscale0 to any port 5432 proto tcp
ufw delete allow 5432/tcp                  # remove world-open rule if present
ufw allow from 174.111.16.88 to any port 5432 proto tcp comment 'ed-home-breakglass'
```

**Do not run these commands until Tailscale is confirmed working on that box** — otherwise you lock yourself out.

---

## 3 · One-time setup on the MacBook

### 3.1 Install

```bash
brew install --cask tailscale        # menu-bar app with GUI auth
# or, CLI-only:
# brew install tailscale-cli && sudo tailscaled install-system-daemon
```

### 3.2 Auth

Click the menu-bar icon → **Log in** → use your Google/Microsoft SSO (same identity that owns the tailnet). Mac becomes a tailnet member named something like `edgar-broyhills-macbook`.

### 3.3 Add SSH config

Open `~/.ssh/config` and append:

```ssh-config
# ---------- Hetzner fleet (via Tailscale) ----------
Host prod-db
    HostName prod-db
    User root
    IdentityFile ~/.ssh/broyhill-macbook
    IdentitiesOnly yes
    ServerAliveInterval 30

Host datatrust
    HostName datatrust
    User root
    IdentityFile ~/.ssh/broyhill-macbook
    IdentitiesOnly yes
    ServerAliveInterval 30

Host secondary-db
    HostName secondary-db
    User root
    IdentityFile ~/.ssh/broyhill-macbook
    IdentitiesOnly yes
    ServerAliveInterval 30
```

After this: `ssh prod-db` — done. No IPs, no passwords, no `-i` flag, no UFW drama.

### 3.4 Optional: name-resolution without MagicDNS

If you don't enable MagicDNS (we disabled it on the servers above), use the tailnet IPv4 instead of hostnames:

```bash
tailscale status | grep -E 'prod-db|datatrust|secondary-db'
# -> 100.x.y.z  prod-db      ed-broyhill@    linux   idle, ...
```

Then in `~/.ssh/config` replace `HostName prod-db` with `HostName 100.x.y.z`. MagicDNS can be turned on later in the Tailscale admin console with zero downtime.

---

## 4 · One-time setup on the Perplexity Computer sandbox

The Computer sandbox is ephemeral — state doesn't persist across sessions, so Tailscale needs to rejoin each time. Use a non-expiring, reusable, tagged pre-auth key dedicated to the sandbox.

```bash
# In any new Nexus session:
curl -fsSL https://tailscale.com/install.sh | sh
# Key is pulled from the sandbox-local creds file, never from git
TS_AUTHKEY=$(grep -A1 'TAILSCALE PRE-AUTH KEY' ~/workspace/HETZNER_NEW_CREDS.txt | tail -1 | awk '{print $1}')
tailscaled --tun=userspace-networking &
tailscale up \
  --authkey="$TS_AUTHKEY" \
  --hostname=nexus-sandbox-$(date +%s) \
  --advertise-tags=tag:nexus-sandbox \
  --accept-dns=false
```

Once that's up, from the sandbox:

```bash
ssh root@prod-db "echo hello"
# or
psql "postgresql://postgres:<pw>@prod-db:5432/postgres" -c "SELECT 1"
```

Rationale for `--tun=userspace-networking`: the sandbox doesn't have permission to create kernel TUN devices. Userspace networking is slower but works from any unprivileged container.

Rationale for a time-stamped hostname: so ephemeral sandboxes don't fight over the same tailnet name.

---

## 5 · Tailnet ACLs (paste into Tailscale admin → Access controls)

```hujson
{
  "tagOwners": {
    "tag:hetzner-server":  ["autogroup:admin"],
    "tag:nexus-sandbox":   ["autogroup:admin"],
    "tag:mac":             ["autogroup:admin"]
  },

  "acls": [
    // Ed's MacBook can reach every Hetzner server on SSH + Postgres
    { "action": "accept",
      "src":    ["tag:mac"],
      "dst":    ["tag:hetzner-server:22", "tag:hetzner-server:5432",
                 "tag:hetzner-server:8080", "tag:hetzner-server:4399"] },

    // Nexus sandbox can reach Postgres only — no SSH, no admin panels
    { "action": "accept",
      "src":    ["tag:nexus-sandbox"],
      "dst":    ["tag:hetzner-server:5432"] }
  ],

  "ssh": [
    // Tailscale SSH: Ed's mac can SSH as root to any Hetzner server
    { "action": "accept",
      "src":    ["tag:mac"],
      "dst":    ["tag:hetzner-server"],
      "users":  ["root"] }
  ]
}
```

Tag-gate everything. Nexus cannot SSH in. Nexus can only reach Postgres on port 5432. That's the minimum blast radius for a compromised sandbox.

---

## 6 · Pre-auth key hygiene (from the April 17 incident)

- **Never commit a pre-auth key to git.** The April 17 server compromise came from `c7pgN4_fD63DnG` sitting in plaintext in a committed doc. Treat `tskey-auth-*` exactly the same.
- **One key per class of device.** `tag:mac`, `tag:nexus-sandbox`, `tag:hetzner-server` each get their own reusable key, so a leak is containable by revoking one key in Tailscale admin without re-provisioning the others.
- **Rotate on a schedule.** The current key expires 2026-07-17. Calendar alert fires 7 days prior; generate a new one, update `HETZNER_NEW_CREDS.txt`, re-enroll the sandbox. Servers stay enrolled even after key expires.
- **Revoke immediately on any suspected leak.** Admin → Settings → Keys → the key → Revoke. Doesn't affect already-authenticated nodes.
- **Ephemeral flag for short-lived agents.** If Nexus spawns a disposable worker, use an ephemeral key: the node vanishes from the tailnet 5 min after it disconnects, no manual cleanup.

---

## 7 · Verification checklist (run after every fleet change)

From Mac:

```bash
# All three Hetzner boxes reachable
for h in prod-db datatrust secondary-db; do
  printf '%-15s  ' "$h"
  ssh -o BatchMode=yes -o ConnectTimeout=5 $h 'echo OK; hostname; uptime' 2>&1 | head -1
done

# Postgres sanity
psql "postgresql://postgres:<pw>@prod-db:5432/postgres" \
  -c "SELECT current_timestamp, (SELECT count(*) FROM raw.ncboe_donations) AS rows"
# expect: rows = 321348

# Ed canary
psql "postgresql://postgres:<pw>@prod-db:5432/postgres" \
  -c "SELECT count(*), sum(norm_amount), max(personal_email) FROM raw.ncboe_donations WHERE cluster_id = 372171"
# expect: 147 | 332631.30 | ed@broyhill.net
```

From sandbox (Nexus):

```bash
# Should succeed on 5432 only, fail on 22
nc -zv prod-db 5432       # -> succeeded
nc -zv prod-db 22         # -> refused (ACL blocked)
```

---

## 8 · Break-glass paths (keep these rare, documented, and time-boxed)

1. **Ed's home IP** (`174.111.16.88`) still has UFW allow on 22 + 5432 on all three servers as an escape hatch if Tailscale is ever broken. See §2.4.
2. **Hetzner rescue** boots with `broyhill-macbook` key pre-injected (Key Management → rescue key set). Fallback passwords live in `HETZNER_NEW_CREDS.txt`, not in git.
3. **Hetzner Robot** Server-locking whitelist (when there's an abuse lock): Ed's home IP is pre-listed, sandbox is not. Widen only for the duration of the lock.

---

## 9 · What this replaces

Before today we had 4 moving parts to remember:
- Hetzner UFW per-IP whitelist
- Server-lock whitelist (separate from UFW!)
- Rescue mode + SSH key injection + disk mount + chroot
- sshd exposed to the public internet with fail2ban as the only gate

After Tailscale is live, the only moving parts are:
- Tailscale daemon running on each box (systemd unit, auto-restart)
- A single tailnet ACL that says who can do what
- Ed's home IP as break-glass

That's it.

---

*Last updated: 2026-04-18 by Nexus. No credentials in this document. Pre-auth key and fallback passwords live in `HETZNER_NEW_CREDS.txt` (workspace only, never committed).*
