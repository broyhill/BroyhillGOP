# Perplexity Task: Build & Install Donor Analysis System

## Objective

Build and install the BroyhillGOP donor analysis system (correlations, clustering, ML) so users can search donors and discover statistical commonality. Uses NCBOE donations + DataTrust enrichment.

---

## Context

- **BroyhillGOP**: NC Republican campaign SaaS
- **Database**: Supabase PostgreSQL (isbgjpnbocdkeslofota)
- **Stack**: Python, pandas, scikit-learn, psycopg2
- **Location**: `/Users/Broyhill/Desktop/BroyhillGOP-CURSOR`

---

## Prerequisites (Verify First)

1. **nc_boe_donations_raw** exists with columns: voter_ncid, norm_last, canonical_first, norm_zip5, amount_numeric, date_occurred, candidate_referendum_name, transaction_type
2. **nc_datatrust** exists with columns: statevoterid, registeredparty, age, republicanpartyscore, turnoutgeneralscore, householdincomemodeled, educationmodeled, etc.
3. **Supabase DB URL** available: `postgresql://postgres:PASSWORD@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres`

---

## Step 1: Run Database Migrations

```bash
cd /Users/Broyhill/Desktop/BroyhillGOP-CURSOR
export SUPABASE_DB_URL="postgresql://postgres:YOUR_PASSWORD@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres"

psql "$SUPABASE_DB_URL" -f database/migrations/057_DONOR_ANALYSIS_VIEW.sql
psql "$SUPABASE_DB_URL" -f database/migrations/058_FEC_VOTER_MATCHES.sql
psql "$SUPABASE_DB_URL" -f database/migrations/059_FEC_SEPARATE_COMMITTEES.sql  # Run before fec_voter_matcher
psql "$SUPABASE_DB_URL" -f database/migrations/060_DATATRUST_DONOR_CANDIDATE_AFFINITY.sql
psql "$SUPABASE_DB_URL" -f database/migrations/061_DATATRUST_AFFINITY_EXTENDED.sql
psql "$SUPABASE_DB_URL" -f database/migrations/062_DATATRUST_FULL_2500_AFFINITY.sql
```

**Creates**:
- `vw_donor_analysis_consolidated` — donor-level view joining NCBOE + DataTrust
- `fec_voter_matches` — FEC contributor → NC voter matches (for fec_voter_matcher.py)
- `vw_donor_datatrust_base`, `calc_donor_candidate_datatrust_affinity`, `donor_candidates_affinity_for_candidate` — donor–candidate affinity (060)
- `calc_donor_candidate_datatrust_affinity_extended`, `donor_candidates_affinity_extended_for_candidate`, `calc_donor_candidate_datatrust_affinity_all_cols` — extended affinity (40+ vars, all 251 cols) (061)
- `get_datatrust_full_for_ncid`, `calc_donor_candidate_datatrust_affinity_full`, `donor_candidates_affinity_full_for_candidate` — full 2,500 DataTrust vars (nc_datatrust + acxiom) (062)

**Verify**:
```sql
SELECT COUNT(*) FROM public.vw_donor_analysis_consolidated;
-- Should return donor count (tens of thousands)
```

---

## Step 2: Install Python Dependencies

```bash
cd /Users/Broyhill/Desktop/BroyhillGOP-CURSOR
pip install -r analysis/requirements.txt
```

**Requirements** (analysis/requirements.txt): pandas, scikit-learn, psycopg2-binary

---

## Step 3: Set Environment Variable

```bash
export SUPABASE_DB_URL="postgresql://postgres:YOUR_PASSWORD@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres"
```

Or add to `.env` and load via python-dotenv.

---

## Step 4: Run Analysis (CLI)

```bash
cd /Users/Broyhill/Desktop/BroyhillGOP-CURSOR
python -m analysis.donor_analysis --limit 10000 --clusters 5 --out analysis_results.json
```

**Output**: `analysis_results.json` with correlations, clustering, commonality report, PCA.

---

## Step 5: Use Python API (Optional)

```python
from analysis.donor_analysis import (
    fetch_donor_data,
    run_correlations,
    run_clustering,
    run_commonality_report,
)

df = fetch_donor_data()
corr = run_correlations(df)
clust = run_clustering(df, n_clusters=5)
common = run_commonality_report(df, group_by="top_candidate", top_n=10)
```

---

## Files Involved

| File | Purpose |
|------|---------|
| database/migrations/057_DONOR_ANALYSIS_VIEW.sql | Creates vw_donor_analysis_consolidated |
| analysis/donor_analysis.py | Main analysis module |
| analysis/requirements.txt | Python deps |
| analysis/README.md | Usage docs |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "relation vw_donor_analysis_consolidated does not exist" | Run migration 057 first |
| "Set SUPABASE_DB_URL" | Export DB URL with correct password |
| "No module named sklearn" | pip install scikit-learn |
| "Insufficient data" | Check nc_boe_donations_raw has rows; increase --limit |

---

## Success Criteria

- Migration runs without error
- `python -m analysis.donor_analysis` produces JSON output
- analysis_results.json contains correlations, clustering, commonality keys
