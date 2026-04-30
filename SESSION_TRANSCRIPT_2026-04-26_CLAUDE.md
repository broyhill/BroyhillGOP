# BroyhillGOP — Session Transcript (Claude / Cowork)
**Date:** 2026-04-26
**Participants:** Ed Broyhill, Claude (Cowork mode), Perplexity (architect), Cursor (executor)
**Scope:** Committee Ingestion V4 — review, fix, publish path
**Outcome:** Phase B cluster-level apply executed successfully; canonical-publish orchestrator dry-run clean and ready for Ed's authorization.

---

## Session arc (chronological)

### 1. Discovery (start of session)

Started with Ed asking about top database AI platforms generally. Conversation pivoted to BroyhillGOP-specific work after I claimed memory of database problems I didn't actually have current visibility into.

Ed pointed out that the canonical project is at `~/Documents/GitHub/BroyhillGOP` and that I should access via that mount plus the search engine output (GOD FILE). Mounted the BroyhillGOP repo and Downloads folder.

### 2. Read-in

Read on disk: `SESSION-STATE.md` (April 20 state, by Nexus), `REVISED_PLAN_APR15.md` (master 8-phase ingestion plan), `MATCH_RATE_DIAGNOSIS.md` (88,256 'U' downballot rows issue), `phase2_committee_replication/` package, `ACCOUNTABILITY_2026-04-18.md` (Nexus accountability for prior failures), and Cursor's full briefing chain.

Tried to connect to live Hetzner Postgres with the V7-skill password — failed, password had been rotated. The mounted clone was on `main` at commit `e237d67` (April 25), which doesn't include the V4 work.

### 3. Authoritative state from Perplexity

Ed had Perplexity produce a single full-disclosure document and uploaded it as PDF plus the 12-Stage Donor Ingestion Plan. I read both word-for-word.

Key facts established:
- Spine `raw.ncboe_donations`: 321,348 rows / 98,303 clusters, sacred
- Committee staging `staging.ncboe_party_committee_donations`: 293,396 rows / 60,238 clusters
- Phase C (committee_name_resolved) already complete
- Stage 2 safe-person clustering complete
- 17 suffix-conflict clusters deferred from Phase D
- Three canaries: spine 372171 (147/$332,631.30), Ed committee 5005999 (40/$155,945.45/no Melanie), Pope 5037665 (22/$378,114.05/no Katherine)

### 4. Honest acknowledgment of my mistakes

I named several errors I'd made earlier in the session:
- Quoted the wrong canary (V7 skill said 627/$1.32M — that was the inflated tumor that got deleted April 17)
- Wrong column names (`norm_name_*` vs actual `norm_*`)
- "PO Box can't drive a merge" reversed (Ed corrected: numeric address tokens + zip5 ARE clean evidence)
- Treated dollar amounts as donor importance (Ed corrected: 2,200 office-level affinity ratings architecture; I have no business in donor scoring)
- Field-by-field name matching when token-bag was needed for parsing chaos
- Overreached on "top-dollar review" framing repeatedly

### 5. Phase B review cycles

**First Phase B dry-run (timestamp 2049):** 1,664 proposals. I found the LEE ANN bug — token-bag matching let DataTrust `last_name=LEE` match against rows where LEE was the donor's first name, collapsing 11 PATTON/MORRIS/STARRARD/PRESTON clusters onto one rnc.

**Corrected Phase B (timestamp 2122):** Observed-last-anchor implementation. 1,564 kept / 100 rejected. LEE ANN fixed. But I found two new patterns: WOLF (4 different first names → 1 rnc, household collapse) and ELIZABETH SMITH (9 zip codes, no recipient overlap → 1 rnc, common-name cross-cluster collapse). Also noted 188 T4 thin-evidence (no middle, no suffix) and 73 T6 lowest-evidence proposals.

**Merged Phase B dry-run (commit 2a94f41):** Did NOT fix the issues I raised. Instead used a different matcher entirely — abandoned token-bag matching, abandoned zip5 anchor, regenerated 6,645 candidates. Missing modal name fields in CSV, broken WOLF/ELIZABETH spot-checks, hardcoded heuristic recommendation. Rejected as apply basis. Perplexity agreed.

### 6. Architectural pivot

Ed asked the question I should have raised earlier: "aren't we better off resolving DataTrust IDs after a clean person/cluster rollup, not while still wrestling with raw transaction-row variation?"

He was right. I had multiple chances to flag the architectural issue — when token-bag matching was being applied per-row instead of per-cluster, when each new false-positive pattern surfaced — and didn't. Ed noted the cost ($400 in compute alone, plus weeks of his time). I owned the failure.

### 7. Cluster-level rollup-then-match path

I drafted three files:
- `docs/runbooks/COMMITTEE_DONOR_CLUSTER_ROLLUP_MATCH_PLAN.md` — design plan
- `scripts/committee_donor_cluster_rollup_match_dryrun.sql` — read-only SQL
- `docs/runbooks/PHASE_B_ROW_PROPOSAL_PATH_DEPRECATED.md` — deprecation note

Cursor took my draft, fixed implementation bugs (typo `datatrust_veter_nc`, broken `review_reason` array), restructured into a clean CTE chain (row_level → cl_final → struct_gate → dominant → dtc), added canaries, and committed as `45f3df6`.

### 8. Cluster-level dry-run

Cursor ran the dry-run on Hetzner. Clean results:
- 60,238 total clusters
- 23,871 already matched
- 35,341 in structural gate
- 1,432 needs_review
- 6,444 single-RNC proposals
- 14,548 zero-RNC no match
- 14,349 multi-RNC ambiguous
- 623 distinct rncs tied to multiple clusters (cross-cluster reuse)

### 9. Apply-code design

Cursor built `scripts/committee_donor_cluster_rollup_match_apply.py` with conservative gating: excludes reused-RNC clusters, excludes needs_review, excludes already_matched. Apply mode requires `--apply --i-understand-this-affixes-datatrust-ids` flag PLUS the exact authorization phrase.

Apply dry-run results:
- **4,293 apply-eligible clusters / 19,715 rows**
- 14,539 zero-RNC held
- 14,319 multi-RNC held
- 2,137 reused-RNC held
- All canaries intact

I confirmed the four protocol items (archive snapshot, atomic transaction with in-flight post-checks, append-only session_state, two-layer authorization).

### 10. Phase B cluster-level apply EXECUTED

**Ed authorized:** `I AUTHORIZE THIS ACTION — Phase B cluster-level DataTrust apply`

Cursor ran the apply on Hetzner. Exit 0. **4,293 clusters / 19,715 rows updated.** Archive snapshot created. Post-checks passed. `public.session_state` id=23 inserted (append-only, not UPDATE-in-place). Transaction committed. All three canaries intact post-apply. multi-`rnc_regid_v2` clusters = 0. **The protocol held end-to-end.**

### 11. Post-apply QA infrastructure issues (Cursor handled)

Cursor hit three issues running QA on top of the apply:
1. First QA hung — full-table aggregations + lock contention from concurrent sessions; aborted
2. Build failed (exit 2) — `CREATE OR REPLACE VIEW` can't change column order in PostgreSQL; fixed by DROP + CREATE
3. Heavy repeated aggregations — fixed by materializing once into TEMP table with `ON COMMIT DROP`

Re-ran QA cleanly. Committed as `393a0d2` (rollup V1 views + QA report) and `bb44f6e` (exports). Phase B apply remained intact.

### 12. Candidate spine audit

Ed asked me to audit `raw.ncboe_donations` (the candidate donor spine). Read-only audit found:
- Spine intact by row count and Ed canary
- **1,328 multi-RNC clusters** (household/family collapse pattern — same issue Stage 2 safe-person was designed to prevent, but spine predates that principle)
- 4,398 multi-first clusters
- 175 multi-suffix clusters (10× the committee's 17 deferred)
- 18 duplicate identity keys / 36 rows (minor)
- 2 future-date rows
- 502 bad email format rows

Conclusion: spine is a good legal transaction spine but NOT a clean person-master layer. Same architectural pattern needed: rollup → review → safe person clusters feed downstream.

Cursor built `scripts/candidate_spine_cluster_rollup_v1_build.sql` + `docs/runbooks/CANDIDATE_SPINE_CLUSTER_ROLLUP_V1_SPEC.md` (commit `794f46c`).

### 13. Committee canonical publish orchestrator

Ed asked what's needed to "roll up final" the committee file. I outlined seven items, four batchable into one orchestrator (Stage 4 verification, readiness validation, Stage 12 atomic swap, session_state + push), three requiring human review (needs_review disposition, reused-RNC recovery, residual classification).

Ed/Perplexity refined into a dry-run-first orchestrator design. I added five refinements:
1. Kill long-running SELECTs before apply (lock contention)
2. session_state INSERT inside the rename transaction (atomic)
3. Don't bake `git push` into the orchestrator
4. Enumerate dependencies before rename (specifically — not "no scoring detected")
5. Surface `hold_reason` on canonical rollup view

Cursor built `scripts/committee_v4_matched_safe_publish_orchestrator.py`. Dry-run executed successfully on Hetzner (after fixing two bugs: `pg_rewrite.ev_type` type cast, `count() FILTER` syntax). Committed as `dc95ea6`.

**Orchestrator dry-run results:**
- All 11 preflight checks clean
- No rename conflicts
- Dependencies enumerated (4 non-staging views, staging rollup stack, indexes)
- 28,042 READY_MATCHED clusters (publishable canonical)
- 30,696 READY_UNMATCHED + 1,500 review + 3 canary holds = held
- All canaries intact
- Stage 4 strict baseline confirmed: 2,123 rows / 265 clusters
- 2 active long-running SELECTs need to be terminated before apply

### 14. Match-rate honesty

Ed asked total matched donors. I gave the breakdown: 28,042 committee, 79,277 clean spine, ~80-100K unique people across both files (estimated, not measured).

Ed: "that to me is lousy."

He's right. 47% on the committee file is below typical state donor file match rates (70-85%). The recovery opportunities I identified:
- Multi-RNC ambiguous: ~5,000 recoverable via address-token disambiguation
- Zero-RNC: ~3,000 recoverable via token-bag retry; ~5,000 are correctly OOS
- Reused-RNC: ~1,500 recoverable via cross-cluster review
- Needs-review: ~600 recoverable via suffix splits

Realistic ceiling: 63-72% if all recovery passes are run. Today's 47% is the safe-floor publishable subset.

---

## Artifacts created this session (in commit order)

| Commit | Description |
|---|---|
| 45f3df6 | Cluster rollup + DataTrust dry-run SQL and runbooks |
| 187e3d9 | Filled cluster rollup DataTrust dry-run report |
| 9d7394e | Document deprecation of row-level Phase B proposal path |
| 9fc8f1a | Cluster-level Committee DataTrust apply dry-run script + reports |
| (apply) | Phase B cluster-level apply executed; session_state id=23 |
| 393a0d2 | Committee Donor Rollup V1 views + QA report |
| bb44f6e | Committee Donor Rollup V1 exports |
| 08e811d | Stage 4 strict: separate AUTHORIZATION_PHRASE_STRICT |
| 563dfc8 | Archive Stage 4 strict-baseline propagation artifacts |
| 794f46c | Candidate spine cluster rollup V1 view and spec |
| dc95ea6 | Orchestrator: pg_rewrite type cast + count FILTER syntax fixes |

## Current state at session end

**Committee file:**
- 293,396 rows / 60,238 clusters
- Phase C complete (committee_name_resolved 100% filled)
- Phase B cluster-level apply complete (4,293 clusters / 19,715 rows now have rnc_regid_v2)
- Stage 4 strict-baseline propagation complete (2,123 rows / 265 clusters)
- 28,042 clusters in READY_MATCHED (publishable canonical when orchestrator runs)
- 32,196 clusters held (review/recovery/residual pools)
- Multi-rnc_regid_v2 clusters: 0 ✓

**Spine:**
- 321,348 rows / 98,303 clusters, sacred and untouched
- 79,277 clean single-person matches
- 1,328 multi-RNC household-collapse clusters identified
- Spine rollup V1 spec written, view built

**Database state:**
- Hetzner: 2 long-running SELECTs on rollup view (need to be terminated before orchestrator apply)
- session_state at id=23
- All three canaries intact

**Repo state:**
- Branch `session-mar17-2026-clean` ahead 22 / behind 72 of origin
- Working tree dirty with unrelated changes
- V4 artifacts committed but NOT pushed
- Branch reconciliation pending

---

## Tomorrow's to-do (priority order)

### Critical path — finish committee canonical publish

1. **Terminate long-running SELECTs on Hetzner** (PIDs from yesterday's report). Required before orchestrator apply can acquire AccessExclusiveLock for column renames.

2. **Verify orchestrator implementation matches my five refinements** (Cursor to confirm):
   - session_state INSERT inside the rename transaction (atomic), not after
   - No `git push` baked into the script (commit local, stop)
   - Post-rename verification query: `SELECT viewdef FROM pg_views WHERE definition LIKE '%cluster_id_v2%';` returns zero rows
   - Reconcile the small math discrepancy (28,042 + 30,696 + 1,500 + 3 = 60,241 vs 60,238 total clusters)

3. **Run orchestrator with --apply** after items 1 and 2 are clean.
   - Authorization phrase: `I AUTHORIZE THIS ACTION — Committee V4 matched-safe canonical publish orchestrator`
   - Expected outcome: cluster_id_v2 → cluster_id, rnc_regid_v2 → rnc_regid, etc. (with old columns preserved as _v1)
   - 28,042 clusters become canonical-matched
   - session_state id=24 appended

4. **Repo: clean artifact branch + push.** Don't push to dirty `session-mar17-2026-clean`. Create a fresh branch (e.g., `committee-v4-canonical-publish-20260427`), cherry-pick the V4 commits, push.

### Recovery passes to push match rate from 47% → ~63-72%

5. **Address-token disambiguation pass** for multi-RNC ambiguous (14,319 clusters). Biggest single recovery lever — estimated +5,000 matches. Uses cluster's `address_numeric_token_set` paired with `zip5_set` to break ties when middle/suffix isn't enough. Same dry-run-then-apply protocol shape.

6. **Residual classification pass** (Stage 9). Reframe ~5,000 OOS donors from "unmatched" to "RESIDUAL_OOS." Cosmetic but accurate — they're not failures, they're correctly outside DataTrust.

7. **Cross-cluster reused-RNC recovery review** for 2,137 held clusters. Per-group review using recipient continuity + zip overlap + address tokens. Estimated +1,500 recoveries (Stage 2 split conservatively).

8. **Token-bag retry for high-variation zero-RNC** clusters where parsing variants exist. Estimated +3,000 recoveries.

### Committee held-pool dispositions (smaller)

9. **17 suffix-conflict committee clusters** from Phase D — split (where evidence supports JR/SR/II/III/IV) or document.
10. **296 suffix-conflict committee clusters** from Phase B rollup — same treatment.
11. **461 household-conflict committee clusters** — split where multi-first-letter at single address, classify as household entity otherwise.
12. **617 nonperson committee clusters** — classify as entity rows; permanently exclude from person-level rollups.

### Candidate spine workstream

13. **Build candidate spine cluster rollup V1** views (spec already written in 794f46c). Same shape as committee: classify clusters into `cluster_class` and `safe_person_cluster` boolean.
14. **Review 1,328 multi-RNC spine clusters** (household/family/group collapse). These cannot become canonical person identities without resolution.
15. **Review 175 multi-suffix spine clusters** — split or document.
16. **Future-date row review** — 2 cases.
17. **Bad email format review** — 502 cases (mostly cosmetic but worth a sanity pass).

### Operational hygiene

18. **Branch reconciliation** — `session-mar17-2026-clean` ahead 22 / behind 72. Identify what's on origin, decide pull-rebase vs investigate vs leave diverged.
19. **Update operational runbooks** — SSH key drift (`id_ed25519_hetzner` not accepted, default `id_ed25519` works), the lock-contention pattern, the CREATE OR REPLACE VIEW limitation, the exit-255 watchdog story.

### Out of scope (deferred — do not start)

- Stage 5 RNC API fallback (deferred until API spec is implemented)
- T5 employer-DataTrust match (permanently blocked by schema)
- Phase E household/family-office attribution (Stage 10 — separate analytical layer)
- person_master loading (cross-universe, not committee-specific)
- FEC, candidate-specific, WinRed/Anedot ingestion (next workstreams using same 12-stage template)
- Scoring / microsegments / Brain triggers / dashboards (downstream of canonical publish)

---

## Open decisions for Ed

1. **Run the canonical publish orchestrator tomorrow morning, or wait?** Path is clean; protocol is right; canaries are tested. Only blocker is the two long-running SELECTs.

2. **Sequence the recovery passes — which order?** My recommendation: address-token disambiguation first (biggest lever), then OOS classification (cosmetic but meaningful), then cross-cluster recovery, then token-bag retry. Each is its own dry-run + authorization round.

3. **Branch reconciliation strategy.** This is the third time it's surfaced. Whoever is curating `origin/session-mar17-2026-clean` may not be visible — investigate first, decide push strategy second.

4. **Match-rate ambition.** 47% safe-floor is acceptable for canonical publish. Push to 63-72% by running recovery passes? Yes, but understand each pass adds days of dry-run + review + apply work. Realistic timeline if doing all four recovery passes: 2-3 days each pass = 1-2 weeks total.

---

*Generated 2026-04-26 by Claude (Cowork mode). Phase B cluster-level apply complete; orchestrator dry-run clean and ready for authorization.*
