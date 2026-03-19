-- ============================================================================
-- MIGRATION 083: Match FEC donations to person_spine
-- Populates fec_spine_match_candidates; updates fec_donations.person_id.
-- Pass 1: name+zip exact. Pass 2: street_num+last+first_initial. Pass 3: street_num only (unambiguous).
-- No DELETE, no TRUNCATE. Idempotent (INSERT only where not already matched).
-- ============================================================================

BEGIN;

-- ============================================================================
-- Create fec_spine_match_candidates table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.fec_spine_match_candidates (
  fec_donation_id INTEGER,
  person_id BIGINT,
  match_pass TEXT,
  confidence NUMERIC,
  matched_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fec_spine_match_fec_id
  ON public.fec_spine_match_candidates(fec_donation_id);

-- ============================================================================
-- Pass 1: norm_last + norm_first + norm_zip5 exact match to person_spine
-- (is_active=true). Confidence 0.95.
-- ============================================================================
INSERT INTO public.fec_spine_match_candidates (fec_donation_id, person_id, match_pass, confidence)
SELECT DISTINCT ON (fd.id)
  fd.id,
  ps.person_id,
  'pass1_name_zip',
  0.95
FROM public.fec_donations fd
JOIN core.person_spine ps
  ON ps.norm_last = fd.norm_last
  AND (ps.norm_first = fd.norm_first OR ps.nickname_canonical = fd.norm_first)
  AND ps.zip5 = fd.norm_zip5
  AND ps.is_active = true
WHERE fd.norm_last IS NOT NULL
  AND fd.norm_first IS NOT NULL
  AND fd.norm_zip5 IS NOT NULL
  AND fd.id NOT IN (SELECT fec_donation_id FROM public.fec_spine_match_candidates)
ORDER BY fd.id, ps.contribution_count DESC NULLS LAST;

-- ============================================================================
-- Pass 2: norm_street_num + norm_last + first initial agreement
-- Confidence 0.85.
-- ============================================================================
INSERT INTO public.fec_spine_match_candidates (fec_donation_id, person_id, match_pass, confidence)
SELECT DISTINCT ON (fd.id)
  fd.id,
  ps.person_id,
  'pass2_street_last_initial',
  0.85
FROM public.fec_donations fd
JOIN core.person_spine ps
  ON SUBSTRING(ps.street FROM '^(\d+)') = fd.norm_street_num
  AND ps.norm_last = fd.norm_last
  AND (LEFT(ps.norm_first, 1) = LEFT(fd.norm_first, 1) OR LEFT(ps.nickname_canonical, 1) = LEFT(fd.norm_first, 1))
  AND ps.is_active = true
WHERE fd.norm_street_num IS NOT NULL
  AND fd.norm_last IS NOT NULL
  AND fd.norm_first IS NOT NULL
  AND fd.id NOT IN (SELECT fec_donation_id FROM public.fec_spine_match_candidates)
ORDER BY fd.id, ps.contribution_count DESC NULLS LAST;

-- ============================================================================
-- Pass 3: norm_street_num + norm_last only where exactly 1 person_spine matches (unambiguous). Confidence 0.70.
-- ============================================================================
INSERT INTO public.fec_spine_match_candidates (fec_donation_id, person_id, match_pass, confidence)
SELECT fd.id, ps.person_id, 'pass3_street_unambiguous', 0.70
FROM public.fec_donations fd
JOIN core.person_spine ps
  ON SUBSTRING(ps.street FROM '^(\d+)') = fd.norm_street_num
  AND ps.norm_last = fd.norm_last
  AND ps.is_active = true
WHERE fd.norm_street_num IS NOT NULL
  AND fd.norm_last IS NOT NULL
  AND fd.id NOT IN (SELECT fec_donation_id FROM public.fec_spine_match_candidates)
  AND (SELECT COUNT(*) FROM core.person_spine ps2
       WHERE SUBSTRING(ps2.street FROM '^(\d+)') = fd.norm_street_num
         AND ps2.norm_last = fd.norm_last
         AND ps2.is_active = true) = 1;

-- ============================================================================
-- Verification
-- ============================================================================
SELECT match_pass, COUNT(*), ROUND(AVG(confidence)::numeric, 2) AS avg_confidence
FROM public.fec_spine_match_candidates
GROUP BY match_pass
ORDER BY match_pass;

COMMIT;
