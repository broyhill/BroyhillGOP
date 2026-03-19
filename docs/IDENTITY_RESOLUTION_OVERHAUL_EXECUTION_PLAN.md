# Identity Resolution Overhaul — Execution Plan

**Source:** Cursor-Identity-Resolution-Overhaul.docx (Claude → Cursor, March 14, 2026)

## Connection

Use **port 6543** (Supabase pooler), NOT 5432. Port 5432 gets rate-limited after bad password attempts.
```
postgresql://user:pass@db.isbgjpnbocdkeslofota.supabase.co:6543/postgres
```

## Migrations 066–070 (Already Exist)

Phases 1–4 executable SQL is in `database/migrations/`:
- **066** — Phase 1: Spine dedup (merge candidates, union-find)
- **067** — Phase 1B: Execute merges
- **068** — Phase 2: Voter matching (3 passes) + General Fund spine records
- **069** — Phase 3: FEC donations mapping
- **070** — Phase 4: Bridge person_master, rebuild aggregates

Read these before writing any new identity-resolution migrations.

## fn_normalize_donor_name

PostgreSQL function deployed to Supabase. Returns `canonical_first_name`, `last_name`, `first_name`, `suffix`.
Do NOT use `pipeline.parse_ncboe_name` for identity resolution — it only uppercases; does not parse.

---

## Summary

Unify two disconnected identity systems into one:
- **person_master** (7.66M) — voter file, zero donor links
- **core.person_spine** (333K) — donor profiles, fragmented (Art Pope = 4–5 records)

**Goal:** One golden record per donor, linked to voter, all donations mapped.

---

## Phase 0: Database Health (Do First)

**Migration:** `database/migrations/065_IDENTITY_RESOLUTION_OVERHAUL_PHASE0.sql`

```bash
psql $DATABASE_URL -f database/migrations/065_IDENTITY_RESOLUTION_OVERHAUL_PHASE0.sql
```

1. **VACUUM** nc_boe_donations_raw, ncsbe_candidates, staging_committee_ref, boe_committee_candidate_map, candidate_profiles
2. **Drop 6 unused indexes** (~1.8 GB) — verify `idx_scan = 0` first
3. **Create nc_voters indexes** (CRITICAL) — ncid, last_first, last_zip, last_county

---

## Phase 1: Fix core.person_spine Fragmentation

1. Build `staging.spine_merge_candidates` (3 strategies: nickname, voter_ncid, employer+city)
2. Union-find clustering
3. Execute merges (mark merged as `is_active = false`, keep survivor)

**Validation:** Art Pope → 1 canonical record, ~156 txns, ~$990K+

---

## Phase 2: Voter-Link the Unlinked

1. Pass 1: Exact last + first + zip5
2. Pass 2: Canonical first + last + zip5 (nickname resolution)
3. Pass 3: Last + first initial + zip5 + party=REP
4. Create spine records for General Fund donors

---

## Phase 3: Map fec_donations (1.13M unmapped)

1. Assess fec_donations schema
2. Create spine records for FEC-only donors
3. Add to donor_contribution_map

---

## Phase 4: Bridge person_master to spine

Update person_master.boe_donor_id, fec_contributor_id, is_donor from spine.

---

## Phase 5: Close NC BOE Gaps

1. Add 147K missing NC BOE rows to contribution map
2. Voter-match General Fund donors
3. Rebuild aggregate metrics

---

## Critical Rules

1. **Never delete** donations or spine records (mark `is_active = false`)
2. Use **fn_normalize_donor_name** for identity resolution (not pipeline.parse_ncboe_name)
3. Cluster first, roll up second
4. General-type = individual persons (already fixed in norm_etl_ncboe)

---

## Validation Queries

```sql
-- Art Pope golden record
SELECT person_id, norm_last, norm_first, voter_ncid, contribution_count, total_contributed
FROM core.person_spine WHERE norm_last = 'POPE' AND voter_ncid = 'EH34831' AND is_active = true;

-- No orphaned donations
SELECT source_system, count(*) FROM donor_contribution_map
WHERE golden_record_id NOT IN (SELECT person_id FROM core.person_spine WHERE is_active = true)
GROUP BY source_system;

-- Spine linkage rate (target >80%)
SELECT count(*) as total, count(voter_ncid) as linked, round(100.0*count(voter_ncid)/count(*),1) as pct
FROM core.person_spine WHERE is_active = true;
```
