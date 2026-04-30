# BroyhillGOP — Phone Brief

**Last updated:** 2026-04-26 evening
**Read this on your phone for the daily snapshot.**

---

## TODAY (2026-04-26)

✅ **Phase B cluster-level apply EXECUTED on Hetzner.**
- 4,293 committee donor clusters got DataTrust voter IDs attached
- 19,715 rows updated
- All canaries intact
- session_state id=23 inserted
- Exit code 0, no rollback

✅ **Canonical-publish orchestrator dry-run clean.**
- All 11 preflight checks pass
- 28,042 clusters ready to become canonical
- No column-rename conflicts
- Dependencies enumerated

⚠️ **Match rate is 47% on committee file** — below typical (70-85%). Today's apply is the safe floor; recovery passes can push to 63-72% later.

---

## TOMORROW MORNING'S FIRST ACTION

**Run the canonical-publish orchestrator with `--apply`.**

Before you authorize:
1. Tell Cursor to terminate the two long-running Hetzner SELECTs (PIDs from the dry-run report). They block the column-rename lock.
2. Have Cursor confirm five protocol items:
   - session_state INSERT is INSIDE the rename transaction (atomic)
   - No `git push` is baked into the script
   - Post-rename verify query: `SELECT viewdef FROM pg_views WHERE definition LIKE '%cluster_id_v2%';` returns zero
   - The 60,238 vs 60,241 cluster-count math discrepancy reconciled
   - Five refinements I gave Cursor are in the script

**Then authorize with this exact phrase:**

```
I AUTHORIZE THIS ACTION — Committee V4 matched-safe canonical publish orchestrator
```

After it runs:
- 28,042 clusters become canonical-matched
- session_state id=24 inserted
- V4 artifacts ready for push to a clean branch

---

## KEY NUMBERS TO REMEMBER

| Item | Value |
|---|---|
| Spine rows | 321,348 |
| Spine clusters | 98,303 |
| Committee staging rows | 293,396 |
| Committee clusters | 60,238 |
| Phase B applied | 4,293 clusters / 19,715 rows |
| Stage 4 strict | 2,123 rows / 265 clusters |
| READY_MATCHED (publish) | 28,042 |
| Held pools (committee) | ~32,196 |
| session_state | id=23 |

---

## THE THREE CANARIES (memorize)

1. **Spine** cluster 372171 = 147 rows / $332,631.30 / `ed@broyhill.net`
2. **Ed committee** cluster_id_v2 = 5005999 = 40 rows / $155,945.45 / no MELANIE
3. **Pope committee** cluster_id_v2 = 5037665 = 22 rows / $378,114.05 / no KATHERINE

If any drift, STOP. Don't authorize anything until canaries are restored.

---

## OPEN BLOCKERS

- 2 long-running SELECTs on Hetzner — kill before orchestrator apply
- Branch `session-mar17-2026-clean` ahead 22 / behind 72 of origin — needs reconciliation before any push
- Cursor's local commits past `session-mar17-2026-clean` are not in canonical remote

---

## AFTER CANONICAL PUBLISH (recovery passes)

Each pass = its own dry-run + authorization round. Estimated leverage:

1. **Address-token disambiguation** for 14,319 multi-RNC ambiguous clusters → ~5,000 recoveries
2. **Residual classification** for OOS donors → reframe ~5,000 from "unmatched" to "RESIDUAL_OOS"
3. **Cross-cluster reused-RNC review** for 2,137 held clusters → ~1,500 recoveries
4. **Token-bag retry** for high-variation zero-RNC → ~3,000 recoveries

Realistic ceiling: 38,000 matched (63%) + 5,000 OOS classified (8%) = 71% of committee donors disposed.

---

## OUT OF SCOPE — DO NOT START

- Stage 5 RNC API fallback (deferred until API spec implemented)
- T5 employer match (permanently blocked, schema doesn't have employer)
- Phase E household/family-office attribution (Stage 10 — separate analytical layer)
- person_master loads
- FEC / WinRed / Anedot ingestion
- Scoring / microsegments / Brain triggers / dashboards

---

## DOCS THAT MATTER

- `NEXUS_STARTUP_PROTOCOL.md` (this folder) — what every session reads first
- `SESSION_TRANSCRIPT_2026-04-26_CLAUDE.md` (this folder) — full session arc
- `docs/runbooks/COMMITTEE_DONOR_CLUSTER_ROLLUP_MATCH_PLAN.md` — architecture
- `docs/runbooks/PHASE_B_ROW_PROPOSAL_PATH_DEPRECATED.md` — what failed and why
- `scripts/committee_v4_matched_safe_publish_orchestrator.py` — tomorrow's apply target

---

*This brief is updated each session. If you're reading on your phone, the GitHub iOS app or the broyhill/BroyhillGOP repo on the web should show this file once it's pushed.*
