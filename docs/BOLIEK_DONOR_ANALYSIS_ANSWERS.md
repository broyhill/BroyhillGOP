# Boliek Donor Analysis — Cursor Answers

**Context:** Dave Boliek for Auditor (Council of State), 1,309 donors. Questions passed to Cursor for the donor analysis pipeline.

---

## 1. Does vw_donor_analysis_consolidated exist in the database right now?

**Answer:** It exists **in the migration files** only. It is defined in `database/migrations/057_DONOR_ANALYSIS_VIEW.sql` and has **not** been verified as deployed to the live Supabase database.

**Action:** Run the migration before Python analysis:

```bash
export SUPABASE_DB_URL="postgresql://postgres:PASSWORD@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres"
psql "$SUPABASE_DB_URL" -f database/migrations/057_DONOR_ANALYSIS_VIEW.sql
```

**Verify deployment:**

```sql
SELECT COUNT(*) FROM public.vw_donor_analysis_consolidated;
```

If the view does not exist, you'll get an error. If it returns a row count, it's deployed.

---

## 2. Can donor_analysis.py run against Boliek's 1,309 donors specifically?

**Answer:** **Not out of the box.** The script fetches from `vw_donor_analysis_consolidated` with only a `LIMIT` — no `WHERE` clause. The view aggregates **all** NCBOE donors across all committees.

**To scope to Boliek donors**, you need one of:

### Option A: Boliek-specific view (recommended)

Create a view that filters `nc_boe_donations_raw` by `committee_name = 'DAVE BOLIEK FOR AUDITOR'` before aggregating, then joins to DataTrust. Example:

```sql
CREATE OR REPLACE VIEW public.vw_donor_analysis_boliek AS
SELECT * FROM public.vw_donor_analysis_consolidated
WHERE donor_key IN (
  SELECT COALESCE(d.voter_ncid, 'noid_' || md5(COALESCE(d.norm_last,'') || '|' || COALESCE(d.canonical_first,'') || '|' || COALESCE(d.norm_zip5,'')))
  FROM public.nc_boe_donations_raw d
  WHERE d.committee_name = 'DAVE BOLIEK FOR AUDITOR'
    AND d.transaction_type = 'Individual'
    AND d.amount_numeric > 0
);
```

Then run `donor_analysis.py` with a modified fetch that queries `vw_donor_analysis_boliek` instead.

### Option B: Extend donor_analysis.py to accept a custom query/filter

Add a `--committee` or `--sql` CLI option so the fetch uses:

```sql
SELECT * FROM public.vw_donor_analysis_consolidated
WHERE top_committee = 'DAVE BOLIEK FOR AUDITOR'
   OR donor_key IN (SELECT ... FROM nc_boe_donations_raw WHERE committee_name = 'DAVE BOLIEK FOR AUDITOR' ...)
```

**Caveat:** `top_committee` is the *mode* (most frequent) committee per donor. A donor who gave to Boliek once and to 5 others would have a different `top_committee`. For strict Boliek-only, filter at the raw donation level (Option A).

---

## 3. What's the current state of core.person_spine? Are Boliek's donors already matched?

**Answer:** Docs say **333K golden records** in `core.person_spine`. `donor_contribution_map` has 3.1M contributions (fec_party 2.2M, NC_BOE 683K, fec_god 197K) linked via `golden_record_id` → `core.person_spine.person_id`.

**Join path for Boliek donors:**

1. **nc_boe_donations_raw** → `voter_ncid` (if populated) → **nc_datatrust** (`statevoterid`) → DataTrust/Acxiom
2. **nc_boe_donations_raw** → `donor_contribution_map` (if NCBOE rows are linked) → `golden_record_id` → **core.person_spine** → `voter_ncid` → nc_datatrust

**Unknown:** Whether `donor_contribution_map` links NCBOE donations by `committee_name` or by a generic NCBOE source. The schema does not expose committee in `donor_contribution_map` directly — you'd need to trace back through the contribution source.

**Practical path for Boliek today:** Use **nc_boe_donations_raw** directly with `committee_name = 'DAVE BOLIEK FOR AUDITOR'`, join to **nc_datatrust** via `voter_ncid = statevoterid`. That works regardless of `core.person_spine`. `vw_donor_datatrust_base` (migration 060) does exactly that join but aggregates all donors; a Boliek-scoped version would filter the raw table first.

---

## 4. Can the pipeline take a custom feature list?

**Answer:** **Yes.** `donor_analysis.py` already accepts custom features:

- `run_clustering(df, features=[...])` — pass a list of column names
- `run_correlations(df, numeric_cols=[...])` — pass a list
- `run_pca(df, features=[...])` — pass a list

**Current defaults (7 features):**  
`total_amount`, `donation_count`, `avg_amount`, `dt_age`, `dt_republican_score`, `dt_turnout_score`, `dt_voter_regularity`

**Suggested Council of State feature list:**

| Source | Column | Notes |
|--------|--------|-------|
| nc_datatrust | dt_2nd_amendment | Already in vw_donor_analysis_consolidated |
| nc_datatrust | dt_prolife | Already in view |
| nc_datatrust | dt_veteran | Already in view |
| nc_datatrust | dt_fiscal_conservative | Add to view (coalitionid_fiscalconservative) |
| nc_datatrust | dt_social_conservative | Add to view (coalitionid_socialconservative) |
| acxiom | IBE7641_01 (income) | Requires join to acxiom_consumer_data via rncid |
| acxiom | IBE8606 (homeowner) | Same |
| acxiom | IBE9514 (education) | Same |
| acxiom | AP004359 (conservative views) | Same |
| acxiom | AP001715 (charitable org member) | Same |

**Gap:** `vw_donor_analysis_consolidated` and `vw_donor_datatrust_base` do **not** join to `acxiom_consumer_data`. Migration 062 adds `get_datatrust_full_for_ncid()` which merges nc_datatrust + acxiom. To use Acxiom features in clustering, you'd need to either:

1. Extend the donor view to join acxiom (on `nc_datatrust.rncid = acxiom_consumer_data.rnc_regid`), or  
2. Fetch Acxiom in a separate step and merge in Python before clustering.

---

## 5. Does the framework have time-series decomposition?

**Answer:** **No.** `donor_analysis.py` has correlations, K-means clustering, commonality report, and PCA. No seasonal decomposition or time-series tools.

**For timeline/seasonality (launch spike, pre-primary surge, general push, post-election rebuild):** Build that separately. Options:

- **statsmodels:** `from statsmodels.tsa.seasonal import seasonal_decompose`
- **pandas:** rolling means, resampling by month
- **Custom:** Your monthly donation timeline is the right input; add decomposition on top

The donor_analysis pipeline is cross-sectional (donor profiles). Time-series is a different analysis layer.

---

## Summary: What to do next

1. **Deploy 057** if `vw_donor_analysis_consolidated` is not in the DB.
2. **Create a Boliek-scoped view** (or equivalent filter) so analysis runs on his 1,309 donors only.
3. **Use nc_boe_donations_raw + nc_datatrust** as the primary join path; `core.person_spine` is optional and depends on contribution mapping.
4. **Pass a custom feature list** to `run_clustering()` and `run_correlations()`; add coalition + Acxiom columns once the view/join includes them.
5. **Implement time-series decomposition** outside donor_analysis.py (e.g., statsmodels or pandas).

---

*Generated by Cursor — March 2026*
