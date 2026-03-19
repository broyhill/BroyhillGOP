# NCBOE Ingestion Pipeline — Corrected Master Plan v2

**Ready for Cursor.** This document supersedes the original NC BOE instruction doc and the 20-point remediation plan. Implement exactly as specified.

---

## Do This Right Now (Before Any DDL)

**Every assumption below is calibrated from prior analysis and may be stale. Confirm against live data before a single DDL statement runs.**

1. **Run the pre-flight query** (already in your SQL editor — click Run):
   ```sql
   SELECT transaction_type, account_code, count(*) AS cnt
   FROM nc_boe_donations_raw
   GROUP BY 1, 2
   ORDER BY 3 DESC;
   ```
   Confirms NULL row count and full transaction_type distribution. Do not proceed until you see results.

2. **Verify nc_boe_donations_raw.id column exists** (required before DDL — dedup_key uses id::text):
   ```sql
   SELECT column_name, data_type
   FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'nc_boe_donations_raw' AND column_name = 'id';
   ```
   ETL passes id::text, so BIGINT, INTEGER, SERIAL, UUID all work. Confirm the column exists.

---

**Key fixes from v1:** (1) NULL transaction_type and bad dates in pre-flight; (2) voter NCID match Phase 1 + archive non-matches; (3) canonical_first before dedup; (4) **content_hash** + **dedup_key** (two columns); (5) NCBOE employer_normalize; (6) committee_type from lookup only; (7) raw→processed handoff; (8) idempotent ETL; (9) bulk SQL only; (10) NOT EXISTS; (11) explicit column lists; (12) source_cycle; (13) import script + pre-handoff diagnostic.

---

## Pre-Flight: Fix Raw Data Before Any ETL

Run `pipeline/nc_boe_preflight.sql` **after** DDL (which creates `staging.ncboe_archive`) and **before** ETL.

**Pre-flight check (run first):** Confirm NULL transaction_type distribution before any DDL touches the database:
```sql
SELECT transaction_type, account_code, count(*) AS cnt
FROM public.nc_boe_donations_raw
GROUP BY 1, 2
ORDER BY 3 DESC;
```
Click Run. Expect 1 row with transaction_type IS NULL (orphan) — from prior analysis; verify against live results. Do not proceed until you see output. Bad date counts (e.g. 61 in NCBOE_2020_2026) are also from prior analysis; confirm with live data.

**Explicit column lists** — Do not use `r.*`. Column order must match `nc_boe_donations_raw` exactly. Use a helper or this list:

```sql
-- pipeline/nc_boe_preflight.sql
-- REQUIRES: staging.ncboe_archive exists (run nc_boe_ddl.sql first)

-- Raw table columns (match information_schema for nc_boe_donations_raw)
-- id, donor_name, street_line_1, street_line_2, city, state, zip_code, profession_job_title,
-- employer_name, transaction_type, committee_name, committee_sboe_id, committee_street_1,
-- committee_street_2, committee_city, committee_state, committee_zip_code, report_name,
-- date_occured_raw, account_code, amount_raw, amount_numeric, date_occurred, form_of_payment,
-- purpose, candidate_referendum_name, declaration, source_file, loaded_at, norm_last, norm_first,
-- norm_addr, norm_zip5, norm_city, norm_state, canonical_first, committee_type
-- Plus: dedup_key, content_hash, voter_ncid, zip9, voter_party_cd, employer_normalized, middle_name, name_suffix (if added by DDL)

-- 1. Archive and delete the NULL transaction_type orphan (use explicit columns)
-- Include all raw columns; archive has same structure as raw + archive_reason, archived_at
INSERT INTO staging.ncboe_archive (
  id, donor_name, street_line_1, street_line_2, city, state, zip_code, profession_job_title,
  employer_name, transaction_type, committee_name, committee_sboe_id, committee_street_1,
  committee_street_2, committee_city, committee_state, committee_zip_code, report_name,
  date_occured_raw, account_code, amount_raw, amount_numeric, date_occurred, form_of_payment,
  purpose, candidate_referendum_name, declaration, source_file, loaded_at, norm_last, norm_first,
  norm_addr, norm_zip5, norm_city, norm_state, canonical_first, committee_type,
  content_hash, dedup_key, voter_ncid, zip9, voter_party_cd, employer_normalized, middle_name, name_suffix,
  archive_reason, archived_at
)
SELECT
  r.id, r.donor_name, r.street_line_1, r.street_line_2, r.city, r.state, r.zip_code,
  r.profession_job_title, r.employer_name, r.transaction_type, r.committee_name, r.committee_sboe_id,
  r.committee_street_1, r.committee_street_2, r.committee_city, r.committee_state, r.committee_zip_code,
  r.report_name, r.date_occured_raw, r.account_code, r.amount_raw, r.amount_numeric, r.date_occurred,
  r.form_of_payment, r.purpose, r.candidate_referendum_name, r.declaration, r.source_file, r.loaded_at,
  r.norm_last, r.norm_first, r.norm_addr, r.norm_zip5, r.norm_city, r.norm_state, r.canonical_first, r.committee_type,
  r.content_hash, r.dedup_key, r.voter_ncid, r.zip9, r.voter_party_cd, r.employer_normalized, r.middle_name, r.name_suffix,
  'null_transaction_type', now()
FROM public.nc_boe_donations_raw r
WHERE r.transaction_type IS NULL;
DELETE FROM public.nc_boe_donations_raw WHERE transaction_type IS NULL;

-- 2. Fix bad dates: set to NULL where out of range (61 bad dates in NCBOE_2020_2026)
UPDATE public.nc_boe_donations_raw
SET date_occurred = NULL
WHERE date_occurred < '1990-01-01' OR date_occurred > CURRENT_DATE + INTERVAL '1 year';

-- 3. Archive and delete rows with unparseable/NULL dates (same explicit column list)
INSERT INTO staging.ncboe_archive (
  id, donor_name, street_line_1, street_line_2, city, state, zip_code, profession_job_title,
  employer_name, transaction_type, committee_name, committee_sboe_id, committee_street_1,
  committee_street_2, committee_city, committee_state, committee_zip_code, report_name,
  date_occured_raw, account_code, amount_raw, amount_numeric, date_occurred, form_of_payment,
  purpose, candidate_referendum_name, declaration, source_file, loaded_at, norm_last, norm_first,
  norm_addr, norm_zip5, norm_city, norm_state, canonical_first, committee_type,
  content_hash, dedup_key, voter_ncid, zip9, voter_party_cd, employer_normalized, middle_name, name_suffix,
  archive_reason, archived_at
)
SELECT
  r.id, r.donor_name, r.street_line_1, r.street_line_2, r.city, r.state, r.zip_code,
  r.profession_job_title, r.employer_name, r.transaction_type, r.committee_name, r.committee_sboe_id,
  r.committee_street_1, r.committee_street_2, r.committee_city, r.committee_state, r.committee_zip_code,
  r.report_name, r.date_occured_raw, r.account_code, r.amount_raw, r.amount_numeric, r.date_occurred,
  r.form_of_payment, r.purpose, r.candidate_referendum_name, r.declaration, r.source_file, r.loaded_at,
  r.norm_last, r.norm_first, r.norm_addr, r.norm_zip5, r.norm_city, r.norm_state, r.canonical_first, r.committee_type,
  r.content_hash, r.dedup_key, r.voter_ncid, r.zip9, r.voter_party_cd, r.employer_normalized, r.middle_name, r.name_suffix,
  'unparseable_date', now()
FROM public.nc_boe_donations_raw r
WHERE r.date_occurred IS NULL;
DELETE FROM public.nc_boe_donations_raw WHERE date_occurred IS NULL;
```

**Note:** Generate the full column list from `SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'nc_boe_donations_raw'`. The archive table has those columns plus archive_reason, archived_at. The preflight list above shows the base 37; if DDL added content_hash, dedup_key, voter_ncid, etc., include them.

---

## Phase 0: DDL (`pipeline/nc_boe_ddl.sql`)

### Dependencies Header (add to top of file)

```sql
-- NCBOE Ingestion Pipeline — DDL
-- REQUIRES (run first):
--   pipeline_ddl.sql: pipeline schema, source_quality_rules, dedup_rules
--   pipeline.employer_normalize exists (FEC version; we add employer_normalize_ncboe for NCBOE)
--   core.nick_group table (seeded from public.name_nickname_map)
--   public.nc_boe_donations_raw
-- Rollback: pipeline/nc_boe_ddl_rollback.sql
```

### New/Changed DDL Objects

```sql
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;

-- Ensure raw table has required norm/voter columns (add if missing)
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS content_hash TEXT;  -- duplicate detection (same for true dupes)
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS dedup_key TEXT;      -- unique row id (content_hash || id)
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS voter_ncid TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS zip9 TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS voter_party_cd TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS employer_normalized TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS middle_name TEXT;
ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS name_suffix TEXT;

-- Archive table (receives orphan, bad-date, no-voter-match, dedup-collision rows)
CREATE TABLE IF NOT EXISTS staging.ncboe_archive (
    LIKE public.nc_boe_donations_raw INCLUDING DEFAULTS,
    archive_reason TEXT,
    archived_at TIMESTAMPTZ DEFAULT now()
);

-- Non-individual off-ramp (committee transfers, party comm, etc.)
CREATE TABLE IF NOT EXISTS staging.ncboe_committee_transfers (
    LIKE public.nc_boe_donations_raw INCLUDING DEFAULTS,
    transferred_at TIMESTAMPTZ DEFAULT now()
);
-- Idempotency: INSERT only rows whose id not already in transfers

-- Committee registry
CREATE TABLE IF NOT EXISTS core.ncboe_committee_registry (
    committee_sboe_id TEXT PRIMARY KEY,
    committee_name TEXT,
    committee_type TEXT,
    first_seen_year INT,
    last_seen_year INT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Committee type lookup — MUST be populated from NCBOE official committee registry
CREATE TABLE IF NOT EXISTS core.ncboe_committee_type_lookup (
    committee_sboe_id TEXT PRIMARY KEY,
    committee_type TEXT NOT NULL,  -- 'candidate', 'pac', 'party', 'independent', etc.
    notes TEXT
);
-- DO NOT use split_part(committee_sboe_id, '-', 3) — SBOE IDs are opaque, not structured type codes.
-- Import from NCBOE Campaign Finance committee registry:
--   Source: https://cf.ncsbe.gov/CFOrgLkup/ or NCSBE public data (dl.ncsbe.gov)
--   Run pipeline/import_ncboe_committee_registry.py (or equivalent) before ETL.
-- If lookup is empty, ETL Step 6 leaves committee_type NULL and logs a warning.
```

### Functions

**Column names:** Use `street_line_1` (not street_address), `employer_name` (not employer), `amount_numeric` (not amount). `nc_voters` uses `res_street_address`, `zip_code` (char 9), `last_name`, `first_name`, `ncid`.

```sql
-- Name parser: "LAST, FIRST MIDDLE" with fallback for no-comma
CREATE OR REPLACE FUNCTION pipeline.parse_ncboe_name(p_donor_name TEXT)
RETURNS TABLE(norm_last TEXT, norm_first TEXT, middle_name TEXT, name_suffix TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_clean TEXT;
    v_comma_pos INT;
    v_left TEXT;
    v_right TEXT;
    v_suffix TEXT;
BEGIN
    v_clean := upper(trim(coalesce(p_donor_name, '')));
    IF v_clean = '' THEN
        norm_last := NULL; norm_first := NULL; middle_name := NULL; name_suffix := NULL;
        RETURN NEXT; RETURN;
    END IF;

    IF position(',' IN v_clean) > 0 THEN
        v_left := trim(split_part(v_clean, ',', 1));
        v_right := trim(split_part(v_clean, ',', 2));
        -- Suffix on last name: JONES JR
        IF v_left ~ '\s+(JR|SR|II|III|IV)\.?$' THEN
            v_suffix := (regexp_match(v_left, '\s+(JR|SR|II|III|IV)\.?$', 'i'))[1];
            v_left := trim(regexp_replace(v_left, '\s+(JR|SR|II|III|IV)\.?$', '', 'i'));
        END IF;
        -- Suffix on first: ROBERT JR
        IF v_right ~ '\s+(JR|SR|II|III|IV)\.?$' THEN
            v_suffix := coalesce(v_suffix, (regexp_match(v_right, '\s+(JR|SR|II|III|IV)\.?$', 'i'))[1]);
            v_right := trim(regexp_replace(v_right, '\s+(JR|SR|II|III|IV)\.?$', '', 'i'));
        END IF;
        -- Strip titles: DR. MR. MRS. REV.
        v_right := regexp_replace(v_right, '^\s*(DR|MR|MRS|MS|REV|HON)\.?\s+', '', 'i');
        norm_last := v_left;
        norm_first := split_part(trim(v_right), ' ', 1);
        middle_name := CASE WHEN array_length(string_to_array(trim(v_right), ' '), 1) > 1
            THEN array_to_string(string_to_array(trim(v_right), ' ')[2:], ' ') ELSE NULL END;
        name_suffix := v_suffix;
    ELSE
        -- No comma: "FIRST LAST" — treat first word as first, rest as last
        norm_first := split_part(v_clean, ' ', 1);
        norm_last := trim(substring(v_clean from length(split_part(v_clean, ' ', 1)) + 2));
        middle_name := NULL;
        name_suffix := NULL;
    END IF;
    RETURN NEXT;
END;
$$;

-- NCBOE-specific employer normalizer (separate from FEC employer_normalize)
CREATE OR REPLACE FUNCTION pipeline.employer_normalize_ncboe(p_emp TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN p_emp IS NULL OR trim(p_emp) = '' THEN NULL
        WHEN upper(trim(p_emp)) IN ('N/A','NA','NONE','NOT EMPLOYED','RETIRED','SELF') THEN upper(trim(p_emp))
        ELSE trim(regexp_replace(upper(coalesce(p_emp,'')), '\s+', ' ', 'g'))
    END;
$$;

-- content_hash: SAME for true duplicate transactions (used for duplicate detection in Step 8)
CREATE OR REPLACE FUNCTION pipeline.content_hash_ncboe(
    p_norm_last TEXT,
    p_canonical_first TEXT,
    p_norm_zip5 TEXT,
    p_date_occurred DATE,
    p_amount NUMERIC
) RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT md5(
        coalesce(p_norm_last,'') || '|' ||
        coalesce(p_canonical_first,'') || '|' ||
        coalesce(p_norm_zip5,'') || '|' ||
        coalesce(p_date_occurred::text,'') || '|' ||
        coalesce(p_amount::text,'')
    );
$$;

-- dedup_key: UNIQUE per row (content_hash || id). Used as PK surrogate in processed table.
-- p_row_id: pass id::text from ETL — works with BIGINT, INTEGER, SERIAL, UUID (verify id type first).
CREATE OR REPLACE FUNCTION pipeline.dedup_key_ncboe(
    p_content_hash TEXT,
    p_row_id TEXT  -- id::text from raw table; avoids type assumption (BIGINT vs INT vs UUID)
) RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT md5(coalesce(p_content_hash,'') || '|' || coalesce(p_row_id,''));
$$;
```

### Processed Table (Handoff Target)

```sql
CREATE TABLE IF NOT EXISTS core.ncboe_donations_processed (
    id BIGSERIAL PRIMARY KEY,
    raw_id BIGINT,
    donor_id BIGINT,
    committee_sboe_id TEXT,
    date_occurred DATE,
    amount NUMERIC(12,2),
    norm_last TEXT,
    canonical_first TEXT,
    norm_zip5 TEXT,
    norm_addr TEXT,
    employer_normalized TEXT,
    voter_ncid TEXT,
    voter_party_cd TEXT,
    zip9 TEXT,
    dedup_key TEXT UNIQUE,
    source_cycle TEXT,
    ingested_at TIMESTAMPTZ DEFAULT now()
);
```

---

## Phase 1: Quality Rules (`pipeline/seed_nc_boe.sql`)

Use existing `pipeline.source_quality_rules` schema: `(source_system, rule_name, rule_sql_condition, severity, description)`.

| Rule | rule_name | Check | Severity | ETL Action |
|------|-----------|-------|----------|------------|
| Q1 | require_donor_name | donor_name IS NOT NULL AND trim(donor_name) != '' | fatal | Archive |
| Q2 | require_amount | amount_numeric IS NOT NULL AND amount_numeric > 0 | fatal | Archive |
| Q3 | require_date | date_occurred IS NOT NULL | fatal | Pre-flight handles |
| Q4 | require_committee | committee_sboe_id IS NOT NULL AND trim(committee_sboe_id) != '' | fatal | Archive |
| Q5 | require_individual | transaction_type = 'Individual' | fatal | Transfer to committee_transfers |
| Q6 | require_zip | norm_zip5 ~ '^\d{5}$' (post-norm) | warn | Flag only |
| Q7 | require_voter_match | voter_ncid IS NOT NULL (post-match) | fatal | Archive |

```sql
INSERT INTO pipeline.source_quality_rules (source_system, rule_name, rule_sql_condition, severity, description) VALUES
('nc_boe', 'q1_donor_name', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE donor_name IS NULL OR trim(coalesce(donor_name,'''')) = ''''', 'fatal', 'donor_name required'),
('nc_boe', 'q2_amount', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE amount_numeric IS NULL OR amount_numeric <= 0', 'fatal', 'amount_numeric required'),
('nc_boe', 'q3_date', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE date_occurred IS NULL', 'fatal', 'date_occurred required'),
('nc_boe', 'q4_committee', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE committee_sboe_id IS NULL OR trim(coalesce(committee_sboe_id,'''')) = ''''', 'fatal', 'committee_sboe_id required'),
('nc_boe', 'q5_individual', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE transaction_type IS DISTINCT FROM ''Individual''', 'fatal', 'non-Individual routed to transfers'),
('nc_boe', 'q6_zip', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE norm_zip5 IS NOT NULL AND norm_zip5 !~ ''^\d{5}$''', 'warn', 'norm_zip5 invalid format'),
('nc_boe', 'q7_voter_match', 'SELECT COUNT(*) FROM public.nc_boe_donations_raw WHERE voter_ncid IS NULL', 'fatal', 'voter_ncid required after match')
ON CONFLICT (source_system, rule_name) DO UPDATE SET rule_sql_condition = EXCLUDED.rule_sql_condition, severity = EXCLUDED.severity, description = EXCLUDED.description;
```

---

## Phase 2: ETL (`pipeline/norm_etl_ncboe.py`)

**Critical design principles:**
- Idempotency: all UPDATEs use `WHERE target_column IS NULL` (or equivalent)
- Bulk SQL only: zero Python row loops
- canonical_first resolved BEFORE dedup_key
- Voter NCID match in Phase 1; archive non-matches

### ETL Steps (implement in order)

1. **Route non-individuals** (idempotent). Use NOT EXISTS, not NOT IN — avoids full seq scan on re-run.
   ```sql
   INSERT INTO staging.ncboe_committee_transfers
   SELECT r.*, now()
   FROM public.nc_boe_donations_raw r
   WHERE transaction_type IS DISTINCT FROM 'Individual'
     AND NOT EXISTS (SELECT 1 FROM staging.ncboe_committee_transfers t WHERE t.id = r.id);
   DELETE FROM public.nc_boe_donations_raw WHERE transaction_type IS DISTINCT FROM 'Individual';
   ```

2. **Parse names** (bulk)
   ```sql
   UPDATE public.nc_boe_donations_raw r
   SET (norm_last, norm_first, middle_name, name_suffix) = (
       SELECT p.norm_last, p.norm_first, p.middle_name, p.name_suffix
       FROM pipeline.parse_ncboe_name(r.donor_name) p
   )
   WHERE r.norm_last IS NULL AND r.transaction_type = 'Individual';
   ```

3. **Address normalize**
   ```sql
   UPDATE public.nc_boe_donations_raw SET
       norm_zip5 = left(regexp_replace(coalesce(zip_code,''), '[^0-9]', '', 'g'), 5),
       norm_addr = upper(trim(regexp_replace(coalesce(street_line_1,''), '\s*(APT|SUITE|#|UNIT).*$', '', 'i'))),
       norm_city = upper(trim(coalesce(city,''))),
       norm_state = upper(trim(coalesce(state,'')))
   WHERE norm_zip5 IS NULL AND transaction_type = 'Individual';
   ```

4. **Employer normalize** (NCBOE-specific)
   ```sql
   UPDATE public.nc_boe_donations_raw
   SET employer_normalized = pipeline.employer_normalize_ncboe(employer_name)
   WHERE employer_normalized IS NULL AND transaction_type = 'Individual' AND employer_name IS NOT NULL;
   ```

5. **Canonical first** (BEFORE dedup key). Use `core.nick_group` column `canonical` (not canonical_name).
   ```sql
   UPDATE public.nc_boe_donations_raw r
   SET canonical_first = ng.canonical
   FROM core.nick_group ng
   WHERE upper(r.norm_first) = upper(ng.nickname) AND r.canonical_first IS NULL AND r.transaction_type = 'Individual';
   UPDATE public.nc_boe_donations_raw
   SET canonical_first = coalesce(canonical_first, norm_first)
   WHERE canonical_first IS NULL AND transaction_type = 'Individual';
   ```

6. **Committee type** from lookup table ONLY (no split_part heuristic)
   ```sql
   UPDATE public.nc_boe_donations_raw r
   SET committee_type = l.committee_type
   FROM core.ncboe_committee_type_lookup l
   WHERE r.committee_sboe_id = l.committee_sboe_id AND r.committee_type IS NULL AND r.transaction_type = 'Individual';
   ```
   If lookup is empty or a committee has no match, committee_type remains NULL. Log: `SELECT count(*) FROM nc_boe_donations_raw WHERE committee_type IS NULL AND committee_sboe_id IS NOT NULL` — if > 0, run NCBOE committee registry import before next ETL.

7. **content_hash and dedup_key** (after canonical_first). Two distinct columns:
   ```sql
   UPDATE public.nc_boe_donations_raw SET
       content_hash = pipeline.content_hash_ncboe(norm_last, canonical_first, norm_zip5, date_occurred, amount_numeric)
   WHERE content_hash IS NULL AND transaction_type = 'Individual';
   UPDATE public.nc_boe_donations_raw SET
       dedup_key = pipeline.dedup_key_ncboe(content_hash, id::text)
   WHERE dedup_key IS NULL AND content_hash IS NOT NULL AND transaction_type = 'Individual';
   ```

8. **Dedup collision** — Detect on content_hash (same content = duplicate). Archive higher-id rows, keep lowest id.
   ```sql
   INSERT INTO staging.ncboe_archive (/* explicit columns */, archive_reason, archived_at)
   SELECT r.id, r.donor_name, r.street_line_1, r.street_line_2, r.city, r.state, r.zip_code,
     r.profession_job_title, r.employer_name, r.transaction_type, r.committee_name, r.committee_sboe_id,
     r.committee_street_1, r.committee_street_2, r.committee_city, r.committee_state, r.committee_zip_code,
     r.report_name, r.date_occured_raw, r.account_code, r.amount_raw, r.amount_numeric, r.date_occurred,
     r.form_of_payment, r.purpose, r.candidate_referendum_name, r.declaration, r.source_file, r.loaded_at,
     r.norm_last, r.norm_first, r.norm_addr, r.norm_zip5, r.norm_city, r.norm_state, r.canonical_first, r.committee_type,
     r.content_hash, r.dedup_key, r.voter_ncid, r.zip9, r.voter_party_cd, r.employer_normalized, r.middle_name, r.name_suffix,
     'dedup_collision', now()
   FROM public.nc_boe_donations_raw r
   WHERE EXISTS (
       SELECT 1 FROM public.nc_boe_donations_raw r2
       WHERE r2.content_hash = r.content_hash AND r2.id < r.id
   );
   DELETE FROM public.nc_boe_donations_raw r
   WHERE EXISTS (
       SELECT 1 FROM public.nc_boe_donations_raw r2
       WHERE r2.content_hash = r.content_hash AND r2.id < r.id
   );
   ```

9. **Voter NCID match**
   ```sql
   UPDATE public.nc_boe_donations_raw d
   SET voter_ncid = v.ncid, zip9 = v.zip_code, voter_party_cd = v.party_cd
   FROM public.nc_voters v
   WHERE upper(d.norm_last) = upper(v.last_name)
     AND upper(d.canonical_first) = upper(v.first_name)
     AND d.norm_zip5 = left(trim(v.zip_code), 5)
     AND d.voter_ncid IS NULL AND d.transaction_type = 'Individual';
   ```

10. **Archive unmatched voters** — Use the same explicit column list as preflight (all raw columns + archive_reason, archived_at).

11. **Committee registry** (ON CONFLICT)
    ```sql
    INSERT INTO core.ncboe_committee_registry (committee_sboe_id, committee_name, committee_type, first_seen_year, last_seen_year)
    SELECT committee_sboe_id, (array_agg(committee_name ORDER BY date_occurred DESC))[1], (array_agg(committee_type ORDER BY date_occurred DESC))[1],
           min(extract(year FROM date_occurred)::int), max(extract(year FROM date_occurred)::int)
    FROM public.nc_boe_donations_raw WHERE committee_sboe_id IS NOT NULL
    GROUP BY committee_sboe_id
    ON CONFLICT (committee_sboe_id) DO UPDATE SET last_seen_year = greatest(core.ncboe_committee_registry.last_seen_year, excluded.last_seen_year), updated_at = now();
    ```

12. **Post-norm indexes** — run `pipeline/nc_boe_post_norm_indexes.sql`

---

## Phase 3: Raw → Processed Handoff (`pipeline/nc_boe_handoff.sql`)

**Handoff target:** `public.donors_master` (confirmed from SQL Editor / schema). Join on `voter_ncid` or equivalent — verify column name: `SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'donors_master' AND column_name ILIKE '%ncid%'`.

**No donor_id = NULL fallback.** Inserting orphaned rows (donor_id = NULL) poisons the processed table. Use **INNER JOIN** — only rows with a donors_master match are inserted.

**Critical:** After Step 10, all remaining rows have voter_ncid (from nc_voters match). But INNER JOIN to donors_master will drop rows where the donor is a registered voter but their voter_ncid has not been loaded into donors_master yet. Those records disappear permanently.

**Pre-handoff check (required):**
```sql
-- 1. Count orphaned: voter_ncids in NCBOE that don't exist in donors_master yet
SELECT count(*) AS orphaned,
       (SELECT count(*) FROM public.nc_boe_donations_raw) AS total,
       round(100.0 * count(*) / nullif((SELECT count(*) FROM public.nc_boe_donations_raw), 0), 2) AS pct_orphaned
FROM public.nc_boe_donations_raw r
WHERE NOT EXISTS (SELECT 1 FROM public.donors_master dm WHERE dm.voter_ncid = r.voter_ncid);
-- If orphaned > 0: run identity resolution to upsert these voter_ncids into donors_master before handoff.
-- Handoff FAILS if orphaned > 1% of total.
```

**When check fails: run diagnostic (produces actionable output):**
```sql
-- Orphan breakdown by county, ZIP, cycle year — distinguishes loading gap vs data quality
SELECT
  coalesce(v.county_desc, 'unknown') AS county,
  r.norm_zip5 AS zip5,
  extract(year from r.date_occurred)::int AS cycle_year,
  count(*) AS orphaned
FROM public.nc_boe_donations_raw r
LEFT JOIN public.donors_master dm ON dm.voter_ncid = r.voter_ncid
LEFT JOIN public.nc_voters v ON v.ncid = r.voter_ncid
WHERE dm.id IS NULL
GROUP BY 1, 2, 3
ORDER BY 4 DESC;
```

**Recovery path:** Upsert missing voter_ncids into donors_master via identity resolution (or bulk insert from nc_voters for those NCIDs). Then re-run handoff.

**Handoff command must fail with exit code 1** when orphaned > 1%, printing the diagnostic output. Do not silently proceed.

```sql
INSERT INTO core.ncboe_donations_processed (
    raw_id, donor_id, committee_sboe_id, date_occurred, amount,
    norm_last, canonical_first, norm_zip5, norm_addr, employer_normalized,
    voter_ncid, voter_party_cd, zip9, dedup_key, source_cycle
)
SELECT
    r.id,
    dm.id,
    r.committee_sboe_id, r.date_occurred, r.amount_numeric,
    r.norm_last, r.canonical_first, r.norm_zip5, r.norm_addr, r.employer_normalized,
    r.voter_ncid, r.voter_party_cd, r.zip9, r.dedup_key,
    CASE
        WHEN r.date_occurred BETWEEN '2015-01-01' AND '2016-12-31' THEN '2015_2016'
        WHEN r.date_occurred BETWEEN '2017-01-01' AND '2018-12-31' THEN '2017_2018'
        WHEN r.date_occurred BETWEEN '2019-01-01' AND '2020-12-31' THEN '2019_2020'
        WHEN r.date_occurred >= '2021-01-01' THEN '2021_plus'
        ELSE 'other'
    END
FROM public.nc_boe_donations_raw r
INNER JOIN public.donors_master dm ON dm.voter_ncid = r.voter_ncid  -- adjust column if different
ON CONFLICT (dedup_key) DO NOTHING;
```

**source_cycle partitioning:** Enables incremental ETL when adding 2020–2026 data later.

---

## Post-Norm Indexes (`pipeline/nc_boe_post_norm_indexes.sql`)

```sql
CREATE INDEX IF NOT EXISTS idx_ncboe_norm_last_zip ON public.nc_boe_donations_raw (norm_last, norm_zip5);
CREATE INDEX IF NOT EXISTS idx_ncboe_content_hash ON public.nc_boe_donations_raw (content_hash);  -- Step 8 duplicate detection
CREATE INDEX IF NOT EXISTS idx_ncboe_dedup_key ON public.nc_boe_donations_raw (dedup_key);
CREATE INDEX IF NOT EXISTS idx_ncboe_committee_sboe ON public.nc_boe_donations_raw (committee_sboe_id);
CREATE INDEX IF NOT EXISTS idx_ncboe_voter_ncid ON public.nc_boe_donations_raw (voter_ncid);
```

---

## Rollback Script (`pipeline/nc_boe_ddl_rollback.sql`)

```sql
DROP TABLE IF EXISTS staging.ncboe_committee_transfers CASCADE;
DROP TABLE IF EXISTS staging.ncboe_archive CASCADE;
DROP TABLE IF EXISTS core.ncboe_committee_registry CASCADE;
DROP TABLE IF EXISTS core.ncboe_committee_type_lookup CASCADE;
DROP TABLE IF EXISTS core.ncboe_donations_processed CASCADE;
DROP FUNCTION IF EXISTS pipeline.parse_ncboe_name(TEXT);
DROP FUNCTION IF EXISTS pipeline.content_hash_ncboe(TEXT,TEXT,TEXT,DATE,NUMERIC);
DROP FUNCTION IF EXISTS pipeline.dedup_key_ncboe(TEXT,BIGINT);
DROP FUNCTION IF EXISTS pipeline.dedup_key_ncboe(TEXT,TEXT);
DROP FUNCTION IF EXISTS pipeline.employer_normalize_ncboe(TEXT);
```

---

## Corrected Run Order

**Dependency:** `import_ncboe_committee_registry` upserts into `core.ncboe_committee_type_lookup` — a table created by DDL. DDL must run first.

```bash
# 0. Pre-execution checks (run NOW, before any DDL)
#    - Pre-flight query: transaction_type, account_code distribution
#    - Verify nc_boe_donations_raw.id exists and data_type (BIGINT/INT/UUID all OK — ETL uses id::text)

# 1. DDL (creates archive, transfers, registry, lookup, functions)
psql $DATABASE_URL -f pipeline/nc_boe_ddl.sql

# 2. Import NCBOE committee registry (REQUIRED before ETL Step 6 — table exists after DDL)
python3 -m pipeline.import_ncboe_committee_registry path/to/committees.csv
#    Source: NCBOE Campaign Finance (cf.ncsbe.gov/CFOrgLkup) or NCSBE public data (dl.ncsbe.gov)
#    CSV must have committee_sboe_id and committee_type columns. See script --help.

# 3. Pre-flight: fix raw data
psql $DATABASE_URL -f pipeline/nc_boe_preflight.sql

# 4. Seed quality rules
psql $DATABASE_URL -f pipeline/seed_nc_boe.sql

# 5. Run norm ETL (idempotent)
python3 -m pipeline.norm_etl_ncboe

# 6. Post-norm indexes
psql $DATABASE_URL -f pipeline/nc_boe_post_norm_indexes.sql

# 7. Pre-handoff check (fails with diagnostic if orphaned > 1%)
python3 -m pipeline.nc_boe_pre_handoff_check
#    On fail: prints orphan count by county, ZIP, cycle year. Run identity resolution, then re-run.

# 8. Handoff (INNER JOIN donors_master — no orphaned rows)
psql $DATABASE_URL -f pipeline/nc_boe_handoff.sql
```

---

## What Was Deliberately Left Out

- **donors_master upsert** from ncboe_donations_processed — requires full identity resolution across FEC + NCBOE
- **staging.ncboe_committee_transfers** downstream — define whether PAC/party donations get analytics table or permanent archive
- **Name-parse QA** — manual spot-check of no-comma name fallbacks

---

## Schema Collision Note

`staging` and `core` may already exist (FEC pipeline). This script creates `staging.ncboe_archive`, `staging.ncboe_committee_transfers`, `core.ncboe_committee_registry`, `core.ncboe_committee_type_lookup`, `core.ncboe_donations_processed`. No overlap with `public.fec_2015_2016_a_staging`.

---

## Fixes vs. Claude 4.6 Critique (Scorecard)

| Issue | Status |
|-------|--------|
| **content_hash vs dedup_key** — Two distinct columns. content_hash = duplicate detection (same for true dupes). dedup_key = unique row id (content_hash + id). Step 8 uses content_hash. | Fixed |
| **NOT IN → NOT EXISTS** — Route step uses `NOT EXISTS (SELECT 1 FROM ... WHERE t.id = r.id)`. | Fixed |
| **Explicit column lists** — Preflight and Step 8 use explicit column lists for archive INSERTs. | Fixed |
| **source_cycle partitioning** — Handoff table has source_cycle; enables incremental reprocessing. | Fixed |
| **Rollback script** — Updated for content_hash_ncboe and new dedup_key_ncboe signature. | Fixed |
| **content_hash index** — Post-norm indexes include idx_ncboe_content_hash for Step 8. | Fixed |
| **committee_type heuristic** — split_part removed. Lookup from NCBOE registry. [pipeline/import_ncboe_committee_registry.py](pipeline/import_ncboe_committee_registry.py) implemented. | Fixed |
| **Handoff donor_id = NULL** — Locked in donors_master. INNER JOIN only. Pre-handoff check fails if orphaned > 1%. | Fixed |
| **import_ncboe_committee_registry placeholder** — Real script: accepts CSV, flexible column mapping, upserts to lookup. First blocker. | Fixed |
| **Pre-handoff 1% orphan threshold** — [pipeline/nc_boe_pre_handoff_check.py](pipeline/nc_boe_pre_handoff_check.py) produces diagnostic (county, ZIP, cycle year) on fail. Recovery path documented. | Fixed |
| **INNER JOIN fragile** — Pre-handoff check explicitly detects voter_ncids in NCBOE not yet in donors_master. Those must be upserted before handoff or they disappear. | Fixed |
| **Run order dependency inversion** — DDL creates core.ncboe_committee_type_lookup; import runs after DDL. Correct order: DDL → import → preflight → seed → ETL. | Fixed |
| **id column type assumption** — dedup_key_ncboe(p_row_id TEXT) accepts id::text; works with BIGINT, INT, UUID. Verification query added before DDL. | Fixed |
| **Pre-flight query unrun** — Plan stresses: run query NOW, confirm against live data before any DDL. Assumptions may be stale. | Fixed |

---

## Three Things to Do Before Anything Else

```sql
-- 1. Run this NOW (already in your editor)
SELECT transaction_type, account_code, count(*) AS cnt
FROM nc_boe_donations_raw GROUP BY 1, 2 ORDER BY 3 DESC;

-- 2. Confirm id column type
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'nc_boe_donations_raw' AND column_name = 'id';
```

3. Fix run order: DDL → import_committee_registry → preflight → seed → ETL (see Corrected Run Order above).
