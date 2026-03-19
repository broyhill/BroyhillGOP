-- ============================================================================
-- MIGRATION 081: Normalize FEC donation columns for matching in 083
-- Adds norm_first, norm_last, norm_zip5, norm_street_num to public.fec_donations.
-- Zip: contributor_zip5 preferred, else LEFT(contributor_zip, 5)
-- No DELETE, no TRUNCATE. Idempotent (ADD IF NOT EXISTS, UPDATE all rows).
-- ============================================================================

SET statement_timeout = '30min';

BEGIN;

-- ============================================================================
-- Step 1: Add columns if not exists
-- ============================================================================
ALTER TABLE public.fec_donations
  ADD COLUMN IF NOT EXISTS norm_first TEXT,
  ADD COLUMN IF NOT EXISTS norm_last TEXT,
  ADD COLUMN IF NOT EXISTS norm_zip5 TEXT,
  ADD COLUMN IF NOT EXISTS norm_street_num TEXT;

-- ============================================================================
-- Step 2: Populate norm_last
-- ============================================================================
UPDATE public.fec_donations
SET norm_last = TRIM(
  REGEXP_REPLACE(
    REGEXP_REPLACE(
      UPPER(TRIM(COALESCE(contributor_last, ''))),
      '\s*(,?\s*(JR|SR|II|III|IV|ESQ|MD|PHD|CPA|DDS|DVM))\.?\s*$',
      '',
      'gi'
    ),
    '\s+',
    ' ',
    'g'
  )
)
WHERE contributor_last IS NOT NULL AND contributor_last != '';

-- ============================================================================
-- Step 3: Populate norm_first (two-pass: strip prefix, then canonical override)
-- ============================================================================
UPDATE public.fec_donations
SET norm_first = UPPER(TRIM(REGEXP_REPLACE(COALESCE(contributor_first, ''), '^(MR\.?|MRS\.?|MS\.?|DR\.?|HON\.?|REV\.?)\s+', '', 'gi')))
WHERE contributor_first IS NOT NULL AND contributor_first != '';

UPDATE public.fec_donations fd
SET norm_first = nv.canonical
FROM public.name_variants nv
WHERE fd.norm_first IS NOT NULL
  AND nv.nickname = fd.norm_first;

-- ============================================================================
-- Step 4: Populate norm_zip5
-- ============================================================================
UPDATE public.fec_donations
SET norm_zip5 = CASE
  WHEN contributor_zip5 IS NOT NULL AND contributor_zip5 != '' THEN LEFT(TRIM(contributor_zip5), 5)
  WHEN contributor_zip IS NOT NULL AND contributor_zip != '' THEN LEFT(REGEXP_REPLACE(contributor_zip, '[^0-9]', '', 'g'), 5)
  ELSE NULL
END
WHERE contributor_zip5 IS NOT NULL OR contributor_zip IS NOT NULL;

-- ============================================================================
-- Step 5: Populate norm_street_num
-- ============================================================================
UPDATE public.fec_donations
SET norm_street_num = (SELECT (m)[1] FROM REGEXP_MATCHES(contributor_street_1, '^(\d+)') AS m LIMIT 1)
WHERE contributor_street_1 IS NOT NULL
  AND contributor_street_1 != ''
  AND contributor_street_1 ~ '^\d+';

-- ============================================================================
-- Step 6: Add indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_fec_norm_name_zip
  ON public.fec_donations(norm_last, norm_first, norm_zip5);
CREATE INDEX IF NOT EXISTS idx_fec_norm_street
  ON public.fec_donations(norm_street_num, norm_last);

-- ============================================================================
-- Verification block
-- ============================================================================
SELECT
  COUNT(*) AS total_rows,
  COUNT(norm_first) AS has_norm_first,
  COUNT(norm_last) AS has_norm_last,
  COUNT(norm_zip5) AS has_norm_zip5,
  COUNT(norm_street_num) AS has_norm_street_num
FROM public.fec_donations;

COMMIT;
