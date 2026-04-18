# Unlock Reply — GEX44 #2882435 / 5.9.99.109

**Ticket:** 2026041803003181
**Procedure:** L002B78C8
**Customer:** Mr Ed Broyhill / BroyhillGOP — K1268625125
**To:** suspension-network@hetzner.com
**In reply to thread:** 19d9ded59d1dc1df (Hetzner reply 2026-04-18 00:11 UTC)
**Date:** 2026-04-18

---

## Subject
Re: [Ticket#2026041803003181] L002B78C8 Unblock — choosing the whitelist path; server will be rebuilt from installimage

## Message

Dear Hetzner Support,

Thank you for the response. Understood — we will not ask you to unlock the
server without first demonstrating we can reach it under our control.

We are choosing the **IP whitelist** option (Robot → Servers → Server locking
→ enter home/office IP). I will enter our static office IP via Robot as soon
as I have written confirmation from you that the whitelist is in place. If
our IP is for any reason not acceptable as static, we will switch to the KVM
console path and open a Remote Console request via Robot → Support.

Once the whitelist is active:

1. We will connect to 5.9.99.109 from the whitelisted IP.
2. We will trigger a fresh `installimage` from Robot rescue to completely
   rebuild the server — none of the compromised filesystem will be reused.
3. Before the host rejoins production, it will receive the same hardened
   baseline we have already applied estate-wide:
   - SSH: `PermitRootLogin prohibit-password`, `PasswordAuthentication no`,
     key-only authentication
   - fail2ban installed and enabled on sshd
   - ufw default-deny inbound, with an explicit allowlist (our admin IPs
     plus required sandbox/vendor ranges only) — no public DB ports, admin
     panels, or ad-hoc HTTP
   - All credentials rotated to a fresh 24-character random string; no
     secret written to any document that could leave the vault
   - Egress rate-limit / packet-per-second alarms in place, with any
     outbound flood or masscan-style traffic treated as a pageable incident
     requiring immediate network isolation

For context — this is the same actor who compromised our AX162-R
(37.27.169.232, Abuse ID 2604:G1218ROETADB). That host was already contained
and remediated on 2026-04-17; an unlock request for that server is
separately in flight with your abuse team. There is no indication the
attacker pivoted beyond those two hosts.

Please confirm when our whitelist entry is active on 5.9.99.109 and we will
proceed immediately with the `installimage` rebuild.

Thank you,

**Mr Ed Broyhill**
BroyhillGOP
Customer No. K1268625125
ed.broyhill@gmail.com
