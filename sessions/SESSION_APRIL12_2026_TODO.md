# BroyhillGOP — Tonight's Work Items
## Created: April 12, 2026 4:53 PM EDT | Ed returns ~8 PM EDT
## Priority: Complete Phase D data load + monitor background jobs

---

## FIRST — CHECK BACKGROUND JOBS (do this the moment you sit down)

SSH to 37.27.169.232 and check both screen sessions:

```bash
ssh root@37.27.169.232

# Check Acxiom restructure
screen -r acxrestructure
# What to look for: is ap_models done? Is ibe loading? Is market_indices done?
# Ctrl+A D to detach

# Check RNC fact table downloads
screen -r factpull
# What to look for: is absentee.jsonl done? Have the 6 remaining tables started?
# Ctrl+A D to detach

# Quick table count summary
psql "postgresql://postgres:Anamaria%402026%40@127.0.0.1:5432/postgres" -c "
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'core'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 15;"
```

**Expected when complete:**
- `core.acxiom_ap_models` → ~7,655,593 rows
- `core.acxiom_ibe` → ~7,655,593 rows
- `core.acxiom_market_indices` → ~7,655,593 rows
- `/data/rnc/absentee.jsonl` → 10.5M+ rows (already at 10.5M when Ed left)
- `/data/rnc/VoterContacts.jsonl`, `Volunteers.jsonl`, `Organizations.jsonl`, `DimElection.jsonl`, `DimOrganization.jsonl`, `DimTag.jsonl` → all present

---

## SECOND — DROP OLD ACXIOM JSONB TABLE (once restructure is confirmed complete)

**Only run after all three new tables are fully loaded and verified.**

```sql
-- Verify counts first
SELECT COUNT(*) FROM core.acxiom_ap_models;      -- must be ~7,655,593
SELECT COUNT(*) FROM core.acxiom_ibe;             -- must be ~7,655,593
SELECT COUNT(*) FROM core.acxiom_market_indices;  -- must be ~7,655,593

-- Then drop the old table
DROP TABLE core.acxiom_consumer_nc;
```

**Authorization required.** Do not drop until you verify the three replacement tables.

---

## THIRD — TRANSFER AND LOAD THE 18 GOLD NCBOE FILES

The Phase D infrastructure is ready. `raw.ncboe_donations` is built and empty on the server.

### 3a. Transfer files from your laptop to the server
```bash
# From your Mac:
scp -i ~/.ssh/id_ed25519_hetzner \
    /path/to/ncboe/gold/*.csv \
    root@37.27.169.232:/data/ncboe/gold/

# Verify they arrived:
ssh root@37.27.169.232 "ls -lh /data/ncboe/gold/"
```

### 3b. Dry-run the first file (NO data inserted)
```bash
ssh root@37.27.169.232
cd /opt/broyhillgop
export HETZNER_DB_URL='postgresql://postgres:Anamaria%402026%40@127.0.0.1:5432/postgres'
python3 -m pipeline.ncboe_normalize_pipeline --file /data/ncboe/gold/[first_file].csv
```

Review the output. Look for:
- Name parse errors (especially anything mapping ED → EDWARD)
- Column header mismatches (must see `Transction Type` and `Date Occured` — typos are correct)
- Employer normalization results
- Amount parsing (numeric conversion)

### 3c. Load each file one at a time (requires "I authorize this action")
```bash
python3 -m pipeline.ncboe_normalize_pipeline --file /data/ncboe/gold/[file].csv --apply
```

After each file, verify the count:
```sql
SELECT source_file, COUNT(*) FROM raw.ncboe_donations GROUP BY source_file ORDER BY 1;
```

### 3d. After all 18 files loaded — run internal dedup clustering
```bash
python3 -m pipeline.ncboe_internal_dedup
```

Verify cluster assignment:
```sql
SELECT COUNT(*) FROM raw.ncboe_donations WHERE cluster_id IS NOT NULL;
SELECT COUNT(DISTINCT cluster_id) FROM raw.ncboe_donations;
```

---

## FOURTH — LOAD EMPLOYER_SIC_MASTER (unblocks SIC matching)

The `donor_intelligence.employer_sic_master` table was created empty. It needs the 62,100-row dump from Supabase (which has the full mapping).

```bash
# On your Mac — dump from Supabase
pg_dump \
  "postgresql://postgres:Anamaria@2026@@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres" \
  -t donor_intelligence.employer_sic_master \
  --data-only \
  -f /tmp/employer_sic_master.sql

# Copy to new server
scp -i ~/.ssh/id_ed25519_hetzner \
    /tmp/employer_sic_master.sql \
    root@37.27.169.232:/tmp/

# Load on new server
ssh root@37.27.169.232
psql "postgresql://postgres:Anamaria%402026%40@127.0.0.1:5432/postgres" \
  < /tmp/employer_sic_master.sql

# Verify
psql "postgresql://postgres:Anamaria%402026%40@127.0.0.1:5432/postgres" \
  -c "SELECT COUNT(*) FROM donor_intelligence.employer_sic_master;"
# Must be 62,100
```

Once loaded, re-run normalization to populate `employer_sic_code` and `employer_naics_code` on existing rows.

---

## FIFTH — DANNY PELETSKI: IBE DATA DICTIONARY

242 Acxiom IBE codes remain undefined. Danny's three workbooks are all Acxiom provides — but the IBE dictionary has 8,685 columns and only 928 are documented.

Email Danny:
- **To:** DPeletski@gop.com
- **Ask:** Full IBE behavioral data dictionary for the 242 undefined codes. Specifically the IBE field definitions that weren't included in the three workbooks (apmodels, ibe, marketindices).
- **CC:** Zack Imel (ZImel@gop.com) if Danny doesn't respond within 48 hours.

---

## SIXTH — SUPABASE nc_boe_donations_raw RECOVERY (when ready)

The Supabase `nc_boe_donations_raw` table is contaminated (~2.27M rows, mix of enriched + raw). Recovery requires your explicit authorization.

**When you are ready:**
1. Confirm: `SELECT COUNT(*) FROM public.nc_boe_donations_raw;` → should show ~2,269,053
2. Say: **"I authorize this action"**
3. `TRUNCATE public.nc_boe_donations_raw;`
4. Reload 338,223 sacred rows from `audit.nc_boe_donations_raw_pre_reload_20260330`
5. Verify: `SELECT COUNT(*) FROM public.nc_boe_donations_raw;` → must be exactly 338,223

**Do NOT do this tonight unless the new server NCBOE pipeline is running clean first.**

---

## PARKED — DO NOT START TONIGHT

These are important but wait:
- FEC API key registration (DEMO_KEY rate limit reset — get a real key at api.data.gov)
- NC donors to Club for Growth / NRA / AFP (blocked on FEC API key)
- ms_* microsegment table population (blocked on PAC research)
- Voter file column migration (staging.nc_voters_fresh → nc_datatrust)
- Name+Zip match (9,799 matches staged, awaiting approval)
- WinRed phone/email backfill for 94K contacts

---

## TECHNICAL REFERENCE

| Item | Value |
|------|-------|
| New server | 37.27.169.232 |
| Server root pw | c7pgN4_fD63DnG |
| PostgreSQL password | Anamaria@2026@ (URL-encoded: Anamaria%402026%40) |
| Supabase project | isbgjpnbocdkeslofota |
| Supabase pooler | db.isbgjpnbocdkeslofota.supabase.co port 6543 |
| Supabase password | Anamaria@2026@ |
| GitHub branch | session-mar17-2026-clean, tip fb1dbea4 |
| Relay | 37.27.169.232:8080, key: bgop-relay-k9x2mP8vQnJwT4rL |
| Danny Peletski | DPeletski@gop.com |
| Zack Imel | ZImel@gop.com, 270-799-0923 |
| HETZNER_DB_URL | postgresql://postgres:Anamaria%402026%40@127.0.0.1:5432/postgres |

---

## SECURITY TODO (when convenient)
- Rotate `root@37.27.169.232` password — appeared in plaintext in session today
- Rotate Supabase password — same
- Relay API key rotation is lower priority (private server)

---

*Written by Perplexity (CEO) | April 12, 2026 4:53 PM EDT*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
*Do not modify without Ed's authorization.*
