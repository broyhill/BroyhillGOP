# Identity Resolution — Checkpoint After 066

**STOP: Human review required before running 067.**

Migration 066 (Phase 1 spine dedup) completed. It built merge candidates and clusters. **067 executes the merges** — run it only after validating the Art Pope cluster below.

---

## Art Pope Cluster (from 066 output)

```
 cluster_root | person_id | is_canonical | cluster_size | norm_first | norm_last | voter_ncid | contribution_count | total_contributed 
--------------+-----------+--------------+--------------+------------+-----------+------------+--------------------+-------------------
        75287 |     75287 | t            |            1 | JAMES      | POPE      | EH34831    |                134 |         790984.05
       118472 |    118472 | t            |            1 | ART        | POPE      |            |                 11 |         197135.00
       290433 |    290433 | t            |            1 | ARTHUR     | POPE      |            |                  1 |           2700.00
       290476 |    290476 | t            |            1 | JAMES      | POPE      | BN196820   |                 12 |           2241.33
```

**Expected:** ART, ARTHUR, JAMES ARTHUR Pope (same person, voter EH34831) should collapse to 1 canonical record.

**Observed:** 4 separate records, each with `cluster_size = 1` — they were **not** clustered together.

- **75287** (JAMES, EH34831) — 134 txns, $790K — likely Art Pope
- **118472** (ART, no voter) — 11 txns, $197K — likely Art Pope
- **290433** (ARTHUR, no voter) — 1 txn, $2.7K — likely Art Pope
- **290476** (JAMES, BN196820) — 12 txns, $2.2K — different person (different voter)

**Action:** Investigate why ART/ARTHUR/JAMES ARTHUR (75287, 118472, 290433) did not cluster. Possible causes: different zip5, canonical_first mismatch, or merge-candidate logic. Fix 066 or staging data, then re-run 066 before 067.

---

## Run 067 only after human approval

```bash
psql "postgresql://postgres:BroyhillGOP2026@db.isbgjpnbocdkeslofota.supabase.co:6543/postgres" -f database/migrations/067_PHASE1B_EXECUTE_MERGES.sql
```

Then 068, 069, 070 in order.
