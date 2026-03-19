-- ============================================================
-- Migration 080c: Rebuild public.fec_donations from raw.fec_donations
-- ============================================================
-- CHUNKED version to avoid Supabase statement timeout
-- ============================================================

-- Step 0: Increase statement timeout for this session
SET statement_timeout = '600s';

-- Step 1: Save linkages (outside transaction to avoid timeout cascade)
DROP TABLE IF EXISTS staging.fec_person_linkages;
CREATE TABLE staging.fec_person_linkages AS
SELECT DISTINCT ON (sub_id)
  sub_id, person_id
FROM public.fec_donations
WHERE person_id IS NOT NULL
ORDER BY sub_id, person_id;

-- Step 2: Truncate
TRUNCATE public.fec_donations CASCADE;

-- Step 3: Insert from raw (the big one)
INSERT INTO public.fec_donations (
  committee_id, committee_name, contributor_name,
  contributor_first, contributor_last,
  contributor_street_1, contributor_street_2,
  contributor_city, contributor_state,
  contributor_zip, contributor_zip5,
  contributor_employer, contributor_occupation,
  employer_normalized,
  contribution_date, contribution_amount,
  receipt_type, candidate_name, candidate_office,
  two_year_period, sub_id, source_file, fec_category,
  party, is_memo
)
SELECT
  r.committee_id, r.committee_name, r.contributor_name,
  r.contributor_first_name, r.contributor_last_name,
  r.contributor_street_1, r.contributor_street_2,
  r.contributor_city, r.contributor_state,
  r.contributor_zip, r.contributor_zip5,
  r.contributor_employer, r.contributor_occupation,
  r.employer_normalized,
  r.contribution_receipt_date::date,
  r.contribution_receipt_amount::numeric,
  r.receipt_type, r.candidate_name, r.candidate_office,
  NULLIF(r.two_year_transaction_period, '')::int,
  r.sub_id, r.source_file, r.fec_category,
  CASE
    WHEN r.committee_name ILIKE '%republican%' OR r.committee_name ILIKE '%GOP%' THEN 'REP'
    WHEN r.committee_name ILIKE '%democrat%' OR r.committee_name ILIKE '%DNC%' THEN 'DEM'
    ELSE NULL
  END,
  CASE WHEN r.memo_code = 'X' THEN true ELSE false END
FROM raw.fec_donations r;

-- Step 4: Normalize names
UPDATE public.fec_donations
SET
  norm_first = UPPER(TRIM(REGEXP_REPLACE(
    REGEXP_REPLACE(contributor_first, '(^|\s)(MR|MRS|MS|DR|JR|SR|II|III|IV|V)\.?\s*', ' ', 'gi'),
    '\s+', ' ', 'g'))),
  norm_last = UPPER(TRIM(REGEXP_REPLACE(
    REGEXP_REPLACE(contributor_last, '(^|\s)(JR|SR|II|III|IV|V|ESQ|MD|PHD)\.?\s*', ' ', 'gi'),
    '\s+', ' ', 'g'))),
  norm_zip5 = LEFT(REGEXP_REPLACE(contributor_zip, '[^0-9]', '', 'g'), 5),
  norm_street_num = REGEXP_REPLACE(contributor_street_1, '[^0-9].*', '')
WHERE contributor_first IS NOT NULL;

-- Step 5: Re-apply person_id linkages
UPDATE public.fec_donations p
SET person_id = s.person_id
FROM staging.fec_person_linkages s
WHERE p.sub_id = s.sub_id;

-- Step 6: Indexes
CREATE INDEX IF NOT EXISTS idx_fec_donations_norm_match 
  ON public.fec_donations (norm_last, norm_zip5) WHERE person_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_fec_donations_sub_id 
  ON public.fec_donations (sub_id);
CREATE INDEX IF NOT EXISTS idx_fec_donations_street
  ON public.fec_donations (norm_street_num, norm_zip5)
  WHERE contributor_street_1 IS NOT NULL;

-- Step 7: Verify
SELECT 'total' as metric, COUNT(*)::text as val FROM public.fec_donations
UNION ALL
SELECT 'distinct_sub_ids', COUNT(DISTINCT sub_id)::text FROM public.fec_donations
UNION ALL
SELECT 'with_address', COUNT(*)::text FROM public.fec_donations WHERE contributor_street_1 IS NOT NULL AND contributor_street_1 != ''
UNION ALL
SELECT 'non_memo_dollars', SUM(contribution_amount)::text FROM public.fec_donations WHERE is_memo = false
UNION ALL
SELECT 'linked_to_spine', COUNT(*)::text FROM public.fec_donations WHERE person_id IS NOT NULL
UNION ALL
SELECT 'broyhill_linked', COUNT(*)::text FROM public.fec_donations WHERE norm_last = 'BROYHILL' AND person_id IS NOT NULL AND is_memo = false;

-- Cleanup
DROP TABLE IF EXISTS staging.fec_person_linkages;

RESET statement_timeout;
