# NCBOE Pipeline Audit Report

**Generated:** March 2025  
**Database:** Supabase (isbgjpnbocdkeslofota)

---

## 1. Raw Data (nc_boe_donations_raw)

| Metric | Count |
|--------|-------|
| Total rows | 1,148,939 |
| Individual (transaction_type) | 1,059,073 |
| With voter_ncid | 154,472 |
| With dedup_key | 1,148,939 |

**Voter match rate:** 154,472 / 1,059,073 ≈ **14.6%** of individuals have NCID.

---

## 2. Pipeline Control Tables

### dedup_rules (nc_boe)
- **Rule:** dedup_key_ncboe
- **Columns:** norm_last, norm_zip5, canonical_first
- **id_column:** id
- **zip_required:** false

### identity_clusters
- **nc_boe clusters:** 0 (dedup has not completed successfully)
- **identity_pass_log:** 0 rows (no pass has been logged)

### identity_clusters Schema (actual DB)
| Column | Type |
|--------|------|
| id | uuid |
| source_system | text |
| cluster_key | text |
| member_ids | jsonb |
| member_count | integer |
| status | text |
| confidence_score | numeric |
| created_at | timestamptz |
| reviewed_at | timestamptz |
| reviewed_by | text |

**Note:** No `staging_schema`, `staging_table`, `member_refs`, or `cluster_id`. Code was updated to use `id` and `confidence_score`.

### committee_registry
- **Rows:** 2,032

### staging.ncboe_archive
- **Archived:** 0 rows

---

## 3. Code vs Schema Alignment

| Component | Status | Notes |
|-----------|--------|-------|
| dedup.py → identity_clusters | **Fixed** | INSERT now uses `id`, `confidence_score`; no staging_schema/table |
| dedup.py → Union-Find | **Fixed** | Iterative find (no recursion limit) |
| nc_boe_voter_match.py | **OK** | Retry + smaller batches; runs successfully |
| dedup_rules.notes | **OK** | JSONB with norm_last, norm_zip5, canonical_first |

---

## 4. Pending / Gaps

1. **Dedup not completed** — identity_clusters has 0 nc_boe rows. Dedup run was interrupted (timeout) or failed before insert. Re-run: `python3 -m pipeline.dedup nc_boe` (allow 15–30+ min).

2. **identity_pass_log empty** — No dedup pass has been logged. Will populate after successful dedup.

3. **Voter match** — 14.6% match rate is expected (many donors out-of-state, unregistered). Voter match script is stable with retry logic.

---

## 5. Recommended Next Steps

1. Run dedup in background: `nohup python3 -m pipeline.dedup nc_boe > dedup.log 2>&1 &`
2. After dedup completes, verify: `SELECT count(*) FROM pipeline.identity_clusters WHERE source_system = 'nc_boe';`
3. Proceed to DataTrust enrichment (join on voter_ncid) per Master Plan Phase 3.

---

## 6. Refresh This Audit

**Option A — Python (uses pipeline.db):**
```bash
python3 -m pipeline.audit_ncboe_status
```

**Option B — Shell script (psql only, no Python deps):**
```bash
./scripts/audit_ncboe.sh
```

Both require `SUPABASE_DB_URL` or `DATABASE_URL` in environment (or `.env`).
