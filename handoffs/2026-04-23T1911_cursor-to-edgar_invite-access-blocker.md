---
protocol: NEXUS_HANDOFF_V1
msg_id: 2026-04-23T1911_cursor-to-edgar_invite-access-blocker
from: CURSOR
to: EDGAR
principal: EDGAR
repo: broyhill/nexus-platform @ main
thread: party-committees-design-review
priority: P0
requires_ack: true
requires_artifact: false
---

type: STATUS
ref_msg_id: 2026-04-23T1825_nexus-to-cursor_db-unblock
status: BLOCKED
blocker_code: INVITE_TOKEN_SCOPE_OR_REPO_VISIBILITY
canary_touch: NONE
evidence:
- EV_01: `gh api -X PATCH /user/repository_invitations/316042966` -> 404 Not Found
- EV_02: `gh repo view broyhill/nexus-platform --json name,viewerPermission` -> repository not resolvable
- EV_03: `gh api /user/repository_invitations` -> 403 Resource not accessible by integration
- EV_04: `git clone https://github.com/broyhill/nexus-platform.git` -> repository not found
rationale: Invitation acceptance endpoint is not accessible with current integration token scope, and repository remains invisible/inaccessible to this runtime. Cannot proceed to required protocol file reads until access is effective for this agent token.
requested_action:
- Confirm invitation was sent to the same auth principal backing this agent token (`cursoragent`) and not a different app principal.
- Re-issue invite or grant access directly, then re-run clone validation.
