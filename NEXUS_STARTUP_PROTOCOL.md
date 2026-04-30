# NEXUS STARTUP PROTOCOL — BroyhillGOP

**Read this before touching anything. Every session, every agent, no exceptions.**

Last updated: 2026-04-26 by Claude (Cowork) at Ed Broyhill's direction.

---

## What "Nexus" means

Nexus is the cross-agent identity that any AI loads when starting a BroyhillGOP session — Claude (Cowork or Code), Cursor, Perplexity, or any successor. It is not an agent itself. It is the shared protocol contract.

When you start a session, you ARE Nexus until you complete the pre-flight and Ed releases you to specific work.

---

## MANDATORY PRE-FLIGHT — DO BEFORE ANY DB ACCESS

Run all four steps. Report results to Ed. Wait for direction before doing anything else.

### Step 1 — Read live session_state from the database

```sql
SELECT id, updated_at, updated_by, length(state_md) AS chars, state_md
FROM   public.session_state
ORDER  BY id DESC
LIMIT  1;
```

The newest row is always the live state. Read it fully. Do not infer.

### Step 2 — Verify spine row counts

```sql
SELECT
  (SELECT COUNT(*)              FROM raw.ncboe_donations)                              AS spine_rows,        -- expect 321,348
  (SELECT COUNT(DISTINCT cluster_id) FROM raw.ncboe_donations)                         AS spine_clusters,    -- expect 98,303
  (SELECT COUNT(*)              FROM staging.ncboe_party_committee_donations)          AS staging_rows,      -- expect 293,396
  (SELECT COUNT(*) FILTER (WHERE cluster_id_v2 IS NULL) FROM staging.ncboe_party_committee_donations) AS v2_nulls,  -- expect 0
  (SELECT COUNT(*) FILTER (WHERE committee_name_resolved IS NULL) FROM staging.ncboe_party_committee_donations) AS resolved_nulls;  -- expect 0
```

If spine_rows ≠ 321,348: **STOP. Tell Ed before doing anything.**

### Step 3 — Three canaries

**Spine canary cluster 372171** (Ed Broyhill on candidate spine):
```sql
SELECT cluster_id, COUNT(*) AS txns, SUM(norm_amount) AS total,
       MAX(rnc_regid) AS rnc, MAX(personal_email) AS p_email
FROM raw.ncboe_donations WHERE cluster_id = 372171 GROUP BY cluster_id;
```
Expected: 147 / $332,631.30 / `c45eeea9-663f-40e1-b0e7-a473baee794e` / `ed@broyhill.net`

**Ed committee canary** `cluster_id_v2 = 5005999`:
Expected: 40 rows / $155,945.45 / no MELANIE in cluster

**Pope committee canary** `cluster_id_v2 = 5037665`:
Expected: 22 rows / $378,114.05 / no KATHERINE in cluster

If any canary drift: **STOP. Tell Ed.**

### Step 4 — Multi-RNC integrity check

```sql
SELECT COUNT(*) AS multi_rnc_clusters FROM (
  SELECT cluster_id_v2 FROM staging.ncboe_party_committee_donations
   WHERE cluster_id_v2 IS NOT NULL AND rnc_regid_v2 IS NOT NULL
   GROUP BY cluster_id_v2 HAVING COUNT(DISTINCT rnc_regid_v2) > 1
) z;
```

Expected: 0. If > 0, **STOP. Tell Ed.** The matching pipeline has corrupted person identity.

---

## DONOR UNIVERSE DOCTRINE

Every task starts by declaring which donor universe you are working in. Never assume.

| Object | AI-safe label | Meaning | Warning |
|---|---|---|---|
| `raw.ncboe_donations` | `GOP_CANDIDATE_DONOR_SPINE` | Sacred deduped GOP candidate donor spine. 321,348 rows / 98,303 clusters | NEVER write to this. Read-only canary use only during committee work. |
| `staging.ncboe_party_committee_donations` | `GOP_PARTY_COMMITTEE_DONOR_PREP` | Live party committee donor file. 293,396 rows / 60,238 clusters | Current V4 work surface. Phase B cluster apply complete. |
| `core.ncboe_party_individual_donations` | `GOP_PARTY_COMMITTEE_DONOR_CORE` | Frozen raw committee source | IDs do NOT match staging IDs. Don't join by `id`. |
| `donor_intelligence.person_master` | `PERSON_ROLLUP_LAYER` | Future person-level rollup | Currently EMPTY. Never load directly from staging. |
| `core.di_donor_attribution` | `DONOR_ATTRIBUTION_LAYER` | Analytical credited-to layer | Never mutates legal donor records. Per-action authorization. |

---

## ABSOLUTE PROHIBITIONS

These actions require Ed to type the **exact phrase** `I AUTHORIZE THIS ACTION` (often with a scope qualifier).

"Yes" / "ok" / "go ahead" / "proceed" are NOT authorization. Only the exact phrase.

| Prohibited Action | Why |
|---|---|
| TRUNCATE any table | Destroyed 2.4M rows + 5 hours of work on April 14, 2026 |
| DROP TABLE / DROP COLUMN | Irreversible |
| DELETE without WHERE | Full-table wipe |
| ALTER TABLE removing/renaming columns | Breaks dependents |
| Any DDL on `raw.ncboe_donations` | Crown jewel — sacred |
| Re-run `ncboe_dedup_v2.py` | Already ran. Output = current state. |
| Re-run `datatrust_enrich.py` | Already ran. |
| UPDATE on `public.session_state` rows | Append-only protocol — INSERT new id, never UPDATE in place |
| Stage 4 propagation without dry-run review | High blast radius |
| `_v2` → canonical swap without orchestrator | Production publication step |

For prohibited actions:
1. Show Ed the exact SQL that would execute.
2. Show how many rows would be affected.
3. Say: "This requires authorization. Please type: `I AUTHORIZE THIS ACTION — <scope>`"
4. Wait for the exact phrase.
5. Only then execute.

---

## OUT OF SCOPE FOR ANY DB SESSION

Per Ed's explicit direction, the following are NEVER touched by data-ingestion work:

- Donor scoring, ratings, microsegments
- Donor prioritization (the 2,200-office-affinity layer is NOT in scope here)
- NC contribution-limit checks (NC GS 163-278.13)
- FEC contribution-limit checks
- Cycle-aggregation rules
- Refund / memo / conduit / earmarking treatment
- Independent-expenditure committees
- Brain triggers, dashboards, model features, propensity scoring
- Acxiom materialization
- `donor_intelligence.person_master` direct loads
- FEC / WinRed / Anedot ingestion (separate workstreams)

If a downstream concern requires any of the above, route it to a separate readiness/attribution layer. Do NOT try to handle it in the matching pipeline.

---

## CURRENT STATE (as of 2026-04-26 evening)

**Committee file:**
- Phase C complete (committee_name_resolved 100% filled)
- Phase B cluster-level apply complete (4,293 clusters / 19,715 rows attached to DataTrust)
- Stage 4 strict-baseline propagation complete (2,123 rows / 265 clusters)
- 28,042 clusters READY_MATCHED (publishable canonical when orchestrator runs)
- 32,196 held in review/recovery/residual pools
- Multi-rnc_regid_v2 = 0
- session_state id=23

**Spine:**
- Sacred. Untouched. 321,348 rows / 98,303 clusters.
- 79,277 clean single-person matches
- 1,328 multi-RNC household-collapse clusters identified, classification pending
- 175 multi-suffix conflicts pending review

**Database connection (Hetzner):**
- Host: 37.27.169.232 / Port: 5432 / DB: postgres / User: postgres
- Password lives in `/opt/broyhillgop/.env` on the server (rotated 2026-04-17). NEVER commit to git.
- SSH key: `~/.ssh/id_ed25519` (default), NOT `id_ed25519_hetzner` (documented but not accepted)
- UFW whitelisted: Ed home (174.111.16.88), sandbox egress (34.x/35.x/104.x /8)

**Repo:**
- Canonical: `github.com/broyhill/BroyhillGOP`
- Active branch: `session-mar17-2026-clean` (currently divergent from origin)
- V4 artifacts: NOT pushed yet pending branch reconciliation

---

## TOMORROW'S CRITICAL PATH

Tracked in `PHONE_BRIEF.md` (this folder) and `SESSION_TRANSCRIPT_2026-04-26_CLAUDE.md`.

In short:
1. Terminate two long-running Hetzner SELECTs
2. Run canonical-publish orchestrator with `--apply` after Cursor confirms five protocol refinements
3. Authorization phrase: `I AUTHORIZE THIS ACTION — Committee V4 matched-safe canonical publish orchestrator`
4. Push V4 artifacts to clean branch (not the diverged `session-mar17-2026-clean`)

After canonical publish: address-token disambiguation, OOS classification, cross-cluster recovery, token-bag retry — recovery passes to push match rate from 47% to ~63-72%.

---

## MANDATORY SKILLS TAG

`<!-- AI_MANDATORY_SKILLS:DONOR_INGESTION_V4 -->`

The 7 skills required at session start:
1. `database-operations`
2. `broyhillgop-architecture`
3. `donor-attribution`
4. `data-ingestion-and-forecasting`
5. `data/sql-queries`
6. `data/validation`
7. `coding-and-data` (when repo work is involved)

If any are missing, stop and load before proceeding.

---

## END OF PROTOCOL

After completing pre-flight (Steps 1-4), report results to Ed and **wait for him to say what to work on**. Do not improvise. Do not start new work. Do not assume continuity from a previous session.

Ed sets the agenda. Nexus executes against authorized scope only.
