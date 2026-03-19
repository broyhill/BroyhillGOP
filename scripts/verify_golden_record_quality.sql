-- verify_golden_record_quality.sql
-- Run against Supabase to verify golden record / donor identity quality.
-- Usage: psql $SUPABASE_DB_URL -f scripts/verify_golden_record_quality.sql
--
-- Context: docs/CLAUDE_10_QUESTIONS_RESPONSE_AND_CORRECTIVE_PLAN.md
--   - 50,455 inactive golden records were dropped without analysis (Q5)
--   - donor_golden_records: known identity resolution problem (JAMES BROYHILL appears 11x)
--   - core.person_spine is RFC-001 canonical; donor_golden_records is legacy

\echo '=== GOLDEN RECORD QUALITY VERIFICATION ==='
\echo ''

-- 1. Table existence (donor_golden_records vs core.person_spine)
\echo '--- 1. Table existence ---'
SELECT
  EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'donor_golden_records'
  ) AS has_donor_golden_records,
  EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'core' AND table_name = 'person_spine'
  ) AS has_core_person_spine,
  EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'donor_contribution_map'
  ) AS has_donor_contribution_map;

-- 2. Row counts
\echo ''
\echo '--- 2. Row counts ---'
SELECT 'donor_golden_records' AS tbl, COUNT(*) AS cnt FROM public.donor_golden_records
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'donor_golden_records')
UNION ALL
SELECT 'core.person_spine', COUNT(*) FROM core.person_spine
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'core' AND table_name = 'person_spine')
UNION ALL
SELECT 'donor_contribution_map', COUNT(*) FROM public.donor_contribution_map
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'donor_contribution_map');

-- 3. donor_contribution_map: orphaned golden_record_ids (no matching donor)
\echo ''
\echo '--- 3. Orphaned contributions (golden_record_id not in donor_golden_records) ---'
SELECT
  COUNT(*) AS total_contributions,
  COUNT(*) FILTER (WHERE dcm.golden_record_id IS NULL) AS null_golden_record_id,
  COUNT(*) FILTER (WHERE dcm.golden_record_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.donor_golden_records dgr
    WHERE dgr.golden_record_id = dcm.golden_record_id
  )) AS orphaned_contributions
FROM public.donor_contribution_map dcm
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'donor_contribution_map');

-- 4. donor_golden_records: duplicate donors (same name+zip appearing multiple times)
\echo ''
\echo '--- 4. donor_golden_records: potential duplicates (same last_name + first_name + zip5) ---'
SELECT
  last_name,
  first_name,
  zip5,
  COUNT(*) AS duplicate_count,
  array_agg(golden_record_id ORDER BY golden_record_id) AS golden_record_ids
FROM public.donor_golden_records
WHERE last_name IS NOT NULL AND first_name IS NOT NULL AND zip5 IS NOT NULL
  AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'donor_golden_records')
GROUP BY
  LOWER(TRIM(last_name)),
  LOWER(TRIM(first_name)),
  LEFT(TRIM(COALESCE(zip5,'')), 5)
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 20;

-- 5. JAMES BROYHILL check (known problem: 11 duplicates)
\echo ''
\echo '--- 5. JAMES BROYHILL check (known problem: 11 duplicates) ---'
SELECT golden_record_id, first_name, last_name, zip5, city, county
FROM public.donor_golden_records
WHERE LOWER(TRIM(last_name)) = 'broyhill'
  AND LOWER(TRIM(COALESCE(first_name,''))) LIKE '%james%'
  AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'donor_golden_records')
ORDER BY zip5, city;

-- 6. donor_golden_records: null/missing critical fields
\echo ''
\echo '--- 6. donor_golden_records: null/missing critical fields ---'
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE last_name IS NULL OR TRIM(last_name) = '') AS missing_last_name,
  COUNT(*) FILTER (WHERE first_name IS NULL OR TRIM(first_name) = '') AS missing_first_name,
  COUNT(*) FILTER (WHERE zip5 IS NULL OR TRIM(zip5) = '') AS missing_zip5,
  COUNT(*) FILTER (WHERE email IS NULL OR TRIM(email) = '') AS missing_email
FROM public.donor_golden_records
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'donor_golden_records');

-- 7. Contribution linkage summary (donor_golden_records is legacy; core.person_spine is RFC-001)
\echo ''
\echo '--- 7. Contribution linkage summary ---'
SELECT
  source_system,
  COUNT(*) AS contribution_count,
  COUNT(*) FILTER (WHERE golden_record_id IS NOT NULL) AS has_golden_record_id
FROM public.donor_contribution_map
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'donor_contribution_map')
GROUP BY source_system
ORDER BY contribution_count DESC;

\echo ''
\echo '=== END VERIFICATION ==='
