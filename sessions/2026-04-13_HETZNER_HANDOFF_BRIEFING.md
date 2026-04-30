# Cursor → Hetzner Server 3 (AX162) Connection & Status

## SSH Access

```
Host: 37.27.169.232
User: root
Password: ${PG_PASSWORD_RETIRED_20260417}
```

**Connect with key (preferred):**
```bash
ssh -i ~/.ssh/id_ed25519_hetzner root@37.27.169.232
```

**Connect with password (if key fails):**
```bash
sshpass -p '${PG_PASSWORD_RETIRED_20260417}' ssh -o StrictHostKeyChecking=no root@37.27.169.232
```

**Authorized keys on server:**
1. `eddie@broyhillgop-cursor` — Cursor's own key (already installed)
2. `broyhill-hetzner-e49` — Ed's main Hetzner key (just added)

Password authentication is now **enabled**. If your key doesn't work, password will.

---

## Database Access

```
PostgreSQL on localhost (same server):
postgresql://postgres:${PG_PASSWORD_URLENCODED}@localhost:5432/postgres
```

**Quick test:**
```bash
PGPASSWORD='${PG_PASSWORD}' psql -h localhost -U postgres -d postgres -c "SELECT COUNT(*) FROM raw.ncboe_donations;"
```

---

## Current State — What's Done

### raw.ncboe_donations — LOADED AND VERIFIED
- **2,431,198 rows** from 18 NCBOE GOLD CSV files
- All per-file counts verified exact match
- Phase 2 normalization complete: norm_first, norm_last, norm_middle, norm_suffix, norm_prefix, norm_nickname, norm_zip5, norm_city, norm_employer, norm_amount, norm_date, year_donated, address_numbers, all_addresses, is_unitemized
- Source files: `/data/ncboe/gold/*.csv` (18 files, 538MB)

### core.datatrust_voter_nc — COMPLETE
- 7,727,637 rows

### core.acxiom_ap_models — COMPLETE
- 7,509,898 rows

### core.acxiom_ibe — IN PROGRESS
- ~1,179,856 rows loaded (~15%)
- Running in screen session `acxrestructure`

### core.acxiom_market_indices — QUEUED
- Empty, waiting for acxiom_ibe to finish

---

## What You Need to Do Next

### 1. Fix the double-commit bug in your db.py

`/opt/broyhillgop/pipeline/db.py` line 105 and `/opt/broyhillgop/pipeline/ncboe_normalize_pipeline.py` line 256 both call `conn.commit()`. The `get_connection()` context manager commits on exit, AND `_insert_batch()` commits after executemany. This caused 200x row duplication and 50% row loss in your earlier load attempt.

**Fix:** Remove `conn.commit()` from `_insert_batch()` (line 256 in ncboe_normalize_pipeline.py). Let the context manager handle it.

### 2. Do NOT re-run ncboe_normalize_pipeline.py

The data is already loaded and normalized. Running it again will double the rows. The table is clean at exactly 2,431,198. Verify with:
```sql
SELECT source_file, COUNT(*) FROM raw.ncboe_donations GROUP BY source_file ORDER BY count DESC;
```

### 3. Run the dedup engine

```bash
cd /opt/broyhillgop
python3 -m pipeline.ncboe_internal_dedup
```

Expected output: ~2.4M rows → ~321K unique transactions → ~125K unique donors → ~160K final clusters after cross-file dedup.

### 4. SIC/NAICS employer lookup (optional, after dedup)

The `employer_sic_code` and `employer_naics_code` columns are NULL — the `donor_intelligence.employer_sic_master` table needs to be populated first (pg_dump from Supabase). This can wait.

---

## Screen Sessions Active

| Session | Status | What |
|---------|--------|------|
| `relay` | Running | Relay on port 8080 |
| `acxrestructure` | Running | Acxiom IBE restructure (~15%) |

---

## File Locations

| Path | Contents |
|------|----------|
| `/data/ncboe/gold/` | 18 GOLD CSV files (538MB) — source of truth |
| `/opt/broyhillgop/pipeline/` | Phase D code (name parser, address extractor, employer normalizer, normalize pipeline, dedup engine) |
| `/opt/broyhillgop/bulletproof_load.py` | The loader that successfully loaded all 2,431,198 rows |
| `/opt/broyhillgop/phase2_normalize.py` | The normalizer that populated all norm_* columns |
| `/opt/broyhillgop/.env` | Has HETZNER_DB_URL set |
| `/tmp/bulletproof_load.log` | Load log with per-file verification |
| `/tmp/phase2_normalize.log` | Normalization log |

---

## Critical Rules

1. **ED = EDGAR, never EDWARD.** The name parser enforces this. Do not add any ED→EDWARD expansion.
2. **Do not truncate or reload raw.ncboe_donations.** It's verified at 2,431,198. If you need to reload, coordinate with Ed first.
3. **Do not run ncboe_normalize_pipeline.py with --apply.** The data is already loaded and normalized. Running it again will create duplicates.
4. **Verify before you trust.** Always check row counts before and after any operation.
