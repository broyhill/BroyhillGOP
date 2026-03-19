# NCBOE Tasks 1–3 — REVISED Plan (SQL Only — Do Not Execute Until Approved)

## Schema Corrections Applied

1. **donor_identities**: Import existing `nc_data_committee.donors` first; preserve their `id` as `donor_id`. Do NOT generate new UUIDs for donors that already exist.
2. **fn_match_donor_to_person**: Use `person_master.person_id` (PK), not `id`.
3. **fn_populate_donations_from_raw**: Map to actual `public.donations` column names.

---

## Pre-flight: Schema Check

**Run before Step 1.2:** Verify `staging` schema exists.

```sql
SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'staging';
```

**Result:** `staging` exists. Proceed.

---

## Task 1: Identity Resolution / Donor Dedup Pipeline

### ~~Step 1.1: Create mapping table~~ SKIP

**nc_boe_raw_donor_mapping ALREADY EXISTS** with 1,148,837 rows, all matched. Do NOT run CREATE TABLE. The existing table's `person_id` column points to `nc_data_committee.donors.id`, NOT `person_master.person_id`. Adding an FK to `person_master(person_id)` would fail on existing data. **Skip Step 1.1 entirely.**

### Step 1.2: Create staging view for person_match_key (from raw)

**Pre-check:** Run `SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'staging'` — confirmed `staging` exists.

```sql
-- person_match_key = LOWER(norm_last || '|' || canonical_first || '|' || COALESCE(norm_zip5, ''))
-- Used for matching; norm_zip5 can be empty for ~15% of rows
CREATE OR REPLACE VIEW staging.ncboe_person_match_keys AS
SELECT
    r.id AS raw_id,
    LOWER(TRIM(COALESCE(r.norm_last, '')) || '|' ||
          TRIM(COALESCE(r.canonical_first, r.norm_first, '')) || '|' ||
          COALESCE(SUBSTRING(REGEXP_REPLACE(TRIM(COALESCE(r.norm_zip5, '')), '\D', '', 'g') FROM 1 FOR 5), '')
    ) AS person_match_key
FROM public.nc_boe_donations_raw r
WHERE r.transaction_type = 'Individual'
  AND TRIM(COALESCE(r.norm_last, '')) != ''
  AND (TRIM(COALESCE(r.canonical_first, '')) != '' OR TRIM(COALESCE(r.norm_first, '')) != '');
```

### Step 1.3: Populate donor_identities — IMPORT EXISTING DONORS FIRST

```sql
-- A. Create donor_identities staging table (or use nc_data_committee.donors directly)
-- B. First: insert existing nc_data_committee.donors into mapping by constructing their person_match_key
--    Preserve nc_data_committee.donors.id as donor_id — do NOT generate new UUIDs.

-- Add person_match_key to nc_data_committee.donors if not present (for matching)
ALTER TABLE nc_data_committee.donors
ADD COLUMN IF NOT EXISTS person_match_key VARCHAR(255);

-- Backfill person_match_key for existing donors
UPDATE nc_data_committee.donors d
SET person_match_key = LOWER(
    TRIM(COALESCE(d.last_name, '')) || '|' ||
    TRIM(COALESCE(d.first_name, '')) || '|' ||
    COALESCE(SUBSTRING(REGEXP_REPLACE(TRIM(COALESCE(d.zip, '')), '\D', '', 'g') FROM 1 FOR 5), '')
)
WHERE d.person_match_key IS NULL
  AND (d.last_name IS NOT NULL OR d.first_name IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_nc_donors_person_match_key
ON nc_data_committee.donors(person_match_key)
WHERE person_match_key IS NOT NULL;
```

### Step 1.4: Python script logic (pseudocode — actual code in .py)

```
1. Fetch distinct person_match_key from donation_transactions WHERE data_source='NCBOE'
   (or from staging.ncboe_person_match_keys)
2. For each person_match_key:
   a. SELECT id FROM nc_data_committee.donors WHERE person_match_key = ? LIMIT 1
   b. If found: use that id as donor_id (preserve existing)
   c. If not found: INSERT into nc_data_committee.donors (first_name, last_name, zip, person_match_key)
      with gen_random_uuid() for id; use that as donor_id
3. For each raw row: INSERT into nc_boe_raw_donor_mapping (raw_id, donor_id, person_match_key, match_method)
```

### Step 1.5: fn_match_donor_to_person — use person_master.person_id

```sql
-- Match donor to person_master using person_id (NOT id)
-- person_master PK is person_id
CREATE OR REPLACE FUNCTION public.fn_match_donor_to_person(
    p_donor_id UUID,
    p_person_match_key VARCHAR(255)
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_person_id UUID;
    v_last TEXT;
    v_first TEXT;
    v_zip5 TEXT;
BEGIN
    -- Parse person_match_key: last|first|zip5
    v_last  := SPLIT_PART(p_person_match_key, '|', 1);
    v_first := SPLIT_PART(p_person_match_key, '|', 2);
    v_zip5  := SPLIT_PART(p_person_match_key, '|', 3);

    -- Match on person_master using person_id
    SELECT pm.person_id INTO v_person_id
    FROM public.person_master pm
    WHERE LOWER(TRIM(pm.last_name)) = LOWER(TRIM(v_last))
      AND LOWER(TRIM(pm.first_name)) = LOWER(TRIM(v_first))
      AND COALESCE(SUBSTRING(REGEXP_REPLACE(TRIM(COALESCE(pm.zip5, '')), '\D', '', 'g') FROM 1 FOR 5), '')
        = COALESCE(v_zip5, '')
    LIMIT 1;

    RETURN v_person_id;
END;
$$;
```

### Step 1.6: Bulk update mapping with person_id (single JOIN, not row-by-row)

**Do NOT call fn_match_donor_to_person row-by-row** — that would take hours on 1.1M rows × 7.6M person_master. Use a single bulk UPDATE with direct JOIN:

```sql
UPDATE public.nc_boe_raw_donor_mapping m
SET person_id = pm.person_id
FROM public.person_master pm
WHERE LOWER(TRIM(pm.last_name)) = LOWER(TRIM(SPLIT_PART(m.person_match_key, '|', 1)))
  AND LOWER(TRIM(pm.first_name)) = LOWER(TRIM(SPLIT_PART(m.person_match_key, '|', 2)))
  AND COALESCE(LEFT(pm.zip5, 5), '') = COALESCE(SPLIT_PART(m.person_match_key, '|', 3), '')
  AND m.person_id IS NULL;
```

**Note:** If multiple person_master rows match one mapping row, the UPDATE may pick one arbitrarily. Add `LIMIT 1` via subquery if deterministic single-match is required.

---

## Task 2: Populate public.donations

### Step 2.1: fn_populate_donations_from_raw — ACTUAL column mapping

Using `public.donations` schema:

| public.donations column | Source (nc_boe_donations_raw) |
|------------------------|------------------------------|
| donation_id | gen_random_uuid() |
| donor_id | nc_boe_raw_donor_mapping.donor_id |
| candidate_id | NULL |
| campaign_id | NULL |
| amount | amount_numeric |
| currency | 'USD' |
| fee_amount | 0 |
| net_amount | amount_numeric |
| payment_method | COALESCE(form_of_payment, 'CHECK') |
| payment_gateway | NULL |
| gateway_transaction_id | NULL |
| gateway_customer_id | NULL |
| last_four | NULL |
| card_brand | NULL |
| status | 'completed' |
| status_message | NULL |
| election_type | NULL |
| election_year | EXTRACT(YEAR FROM date_occurred) |
| race_level | NULL |
| is_itemized | true |
| fec_reported | false |
| fec_report_id | NULL |
| donor_name | donor_name |
| donor_address | street_line_1 \|\| COALESCE(' ' \|\| street_line_2, '') |
| donor_city | city |
| donor_state | state |
| donor_zip | zip_code |
| donor_employer | employer_normalized or employer_name |
| donor_occupation | profession_job_title |
| is_recurring | false |
| recurring_id | NULL |
| refunded_amount | 0 |
| refund_reason | NULL |
| refund_date | NULL |
| source | 'NCBOE' |
| utm_source | NULL |
| utm_campaign | NULL |
| device_type | NULL |
| ip_address | NULL |
| donation_date | date_occurred |
| processed_at | now() |
| created_at | now() |
| updated_at | now() |

```sql
CREATE OR REPLACE FUNCTION public.fn_populate_donations_from_raw()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_inserted INTEGER := 0;
BEGIN
    INSERT INTO public.donations (
        donation_id,
        donor_id,
        candidate_id,
        campaign_id,
        amount,
        currency,
        fee_amount,
        net_amount,
        payment_method,
        payment_gateway,
        gateway_transaction_id,
        gateway_customer_id,
        last_four,
        card_brand,
        status,
        status_message,
        election_type,
        election_year,
        race_level,
        is_itemized,
        fec_reported,
        fec_report_id,
        donor_name,
        donor_address,
        donor_city,
        donor_state,
        donor_zip,
        donor_employer,
        donor_occupation,
        is_recurring,
        recurring_id,
        refunded_amount,
        refund_reason,
        refund_date,
        source,
        utm_source,
        utm_campaign,
        device_type,
        ip_address,
        donation_date,
        processed_at,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid(),
        m.donor_id,
        NULL,
        NULL,
        r.amount_numeric,
        'USD',
        0,
        r.amount_numeric,
        COALESCE(NULLIF(TRIM(r.form_of_payment), ''), 'CHECK'),
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        'completed',
        NULL,
        NULL,
        EXTRACT(YEAR FROM r.date_occurred)::INTEGER,
        NULL,
        true,
        false,
        NULL,
        r.donor_name,
        TRIM(COALESCE(r.street_line_1, '') || ' ' || COALESCE(r.street_line_2, '')),
        r.city,
        r.state,
        r.zip_code,
        COALESCE(r.employer_normalized, r.employer_name),
        r.profession_job_title,
        false,
        NULL,
        0,
        NULL,
        NULL,
        'NCBOE',
        NULL,
        NULL,
        NULL,
        NULL,
        r.date_occurred,
        now(),
        now(),
        now()
    FROM public.nc_boe_donations_raw r
    JOIN public.nc_boe_raw_donor_mapping m ON m.raw_id = r.id
    WHERE r.amount_numeric IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM public.donations d
        WHERE d.donor_id = m.donor_id
          AND d.donation_date = r.date_occurred
          AND d.amount = r.amount_numeric
          AND d.source = 'NCBOE'
    );

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;
```

**Duplicate guard:** Only `donations` — prevents double-inserts if the function is called twice (donor_id + donation_date + amount + source). Data is copied from raw into donations; `donation_transactions` is a separate table and is not used as an exclusion guard.

**Filter:** `r.amount_numeric IS NOT NULL` — excludes rows with NULL amount (donations.amount is NOT NULL).

---

## Task 3: Norm Zip5 Gap Fill (Python script)

- Parse `zip_code` from raw for rows where `norm_zip5 IS NULL`
- Use regex to extract 5-digit zip
- UPDATE nc_boe_donations_raw SET norm_zip5 = parsed_value WHERE id IN (...)

---

## Execution Order

1. ~~Step 1.1~~ **SKIP** — nc_boe_raw_donor_mapping already exists (1,148,837 rows)
2. Run Step 1.2 (create view) — after confirming `staging` schema exists
3. Run Step 1.3 (alter donors, backfill person_match_key, create index)
4. Run Python script for Step 1.4 (populate mapping; import existing donors first) — *may be no-op if mapping already full*
5. Run Step 1.5 (create fn_match_donor_to_person)
6. Run Step 1.6 (bulk UPDATE with JOIN — not row-by-row)
7. Run Step 2.1 (create fn_populate_donations_from_raw)
8. Execute fn_populate_donations_from_raw()
9. Task 3: Norm Zip5 gap-fill script

---

**Do NOT execute until user says "go".**
