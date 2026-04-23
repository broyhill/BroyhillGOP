# design_review_v1 — Party Committees + NCBOE Processing
**Date:** 2026-04-23  
**Requested by:** nexus handoff flow  
**Status:** Draft (non-executing design review only)

## ACK
ACK emitted in-session before design drafting.

## Blocking Inputs
- `broyhill/nexus-platform` repository was not reachable from this workspace.
- `handoffs/README.md` and `handoffs/2026-04-23T1347_nexus-to-cursor_design-review-request.md` were not found in the current checkout.
- This draft is therefore a safe, non-destructive review scaffold pending handoff document access.
- Direct PostgreSQL handshake to `37.27.169.232:5432` is currently blocked from this agent session, preventing live Q0 result collection.

## Q0 Discovery (Read-Only, Run Before Q1-Q5)

### Q0 checklist requested
1. `tables_matching_committee`
2. `existing_fec_ingest` (`raw.*` inventory/size proxy for `\\dt+ raw.*`)
3. `donations_committee_fields` (`public.donations` structure proxy for `\\d+ public.donations`)
4. `canary_precheck` (cluster `372171`)

### Evidence log (EV_01..EV_NN)
- **EV_01** — Attempted live connect using DSN A (`dbname=broyhillgop`, `sslmode=prefer`): failed with `server closed the connection unexpectedly`.
- **EV_02** — Attempted live connect using DSN B (`dbname=postgres`, `sslmode=prefer`): failed with `server closed the connection unexpectedly`.
- **EV_03** — Because connection failed before authentication/query execution, none of Q0 query blocks (`tables_matching_committee`, `existing_fec_ingest`, `donations_committee_fields`, `canary_precheck`) could be executed in this run.

### Q0 status
- `Q0_tables_matching_committee`: **BLOCKED** (connectivity)
- `Q0_existing_fec_ingest`: **BLOCKED** (connectivity)
- `Q0_donations_committee_fields`: **BLOCKED** (connectivity)
- `Q0_canary_precheck`: **BLOCKED** (connectivity)

No Q1-Q5 sections should be completed until Q0 executes successfully and EV logs include real query output.

## Hard Gates (Must Remain in Effect)
1. **No schema changes** until explicit `APPROVED + AUTHORIZE`.
2. **No destructive SQL** (`TRUNCATE`, `DROP`, broad `DELETE`, irreversible `UPDATE`) until explicit `APPROVED + AUTHORIZE`.
3. **Read-only audit first**, execution second.

## Design Scope
Create a controlled process for:
- committee mapping integrity (registry, party map, committee→candidate bridge),
- NCBOE spine integrity (row baseline, cluster baseline, canary),
- reproducible handoff outputs for future sessions.

## Proposed Review Workflow (Read-Only)
### Phase A — Source-of-Truth Lock
1. Confirm canonical manifests used for NCBOE file allow-list.
2. Confirm committee reference set expected in the environment.
3. Confirm canary baseline for cluster `372171`.

### Phase B — Committee Audit
1. Validate presence of committee reference entities:
   - committee registry
   - party map
   - office type map
   - committee/candidate bridge
2. Run read-only row-count and null-rate checks for:
   - committee ids
   - party flags
   - candidate mapping coverage
3. Produce a gap list:
   - unmapped committees
   - conflicting party flags
   - bridge collisions (one committee mapped to incompatible candidates)

### Phase C — NCBOE Spine Audit
1. Validate baseline totals and distinct clusters.
2. Validate canary cluster (`372171`) totals and email guardrails.
3. Validate join coverage:
   - committee id population
   - candidate name population (where applicable)
   - voter linkage coverage fields (read-only counts only)

### Phase D — Reconciliation Output
Produce a single decision table:
- `PASS` (safe to proceed with non-destructive improvements),
- `WARN` (requires mapping fixes before committee-dependent outputs),
- `BLOCK` (baseline/canary divergence; stop).

## Acceptance Criteria
This design review is considered complete when:
1. All required read-only audits are defined and reproducible.
2. Canary and baseline checks are explicit and first-class.
3. No write-path SQL is required to run the review.
4. A clear execution gate states: **no writes until APPROVED + AUTHORIZE**.

## Pending Before Execution
1. Provide accessible `broyhill/nexus-platform` repository path or URL.
2. Provide the two handoff files or their contents.
3. Confirm which environment is canonical for this run.

---
**Execution note:** This artifact intentionally contains no schema or destructive SQL.
