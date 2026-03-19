-- ============================================================
-- Migration 083 v3: Three-tier FEC donation → spine matching
-- ============================================================
-- NO TRANSACTION WRAPPER - each tier commits independently
-- Tier 2 optimized with pre-materialized canonical names
-- ============================================================

SET statement_timeout = '900s';

DO $$ BEGIN RAISE NOTICE '── 083v3 START ──'; END $$;

-- ── Pre-flight ─────────────────────────────────────────────
DO $$
DECLARE v_total bigint; v_linked bigint;
BEGIN
  SELECT COUNT(*) INTO v_total FROM public.fec_donations WHERE is_memo = false;
  SELECT COUNT(*) INTO v_linked FROM public.fec_donations WHERE is_memo = false AND person_id IS NOT NULL;
  RAISE NOTICE 'PRE: total non-memo=% | linked=% | unlinked=%', v_total, v_linked, v_total - v_linked;
END $$;

-- ── Clear old linkages ─────────────────────────────────────
UPDATE public.fec_donations SET person_id = NULL WHERE person_id IS NOT NULL;

-- ════════════════════════════════════════════════════════════
-- TIER 1: Exact last + zip5 + first (confidence 0.95)
-- ════════════════════════════════════════════════════════════
DO $$ BEGIN RAISE NOTICE '── Tier 1: exact last+zip+first ──'; END $$;

WITH matches AS (
  SELECT DISTINCT ON (f.id)
    f.id AS fec_id, ps.person_id
  FROM public.fec_donations f
  JOIN core.person_spine ps
    ON f.norm_last = ps.norm_last
    AND f.norm_zip5 = ps.zip5
    AND f.norm_first = ps.norm_first
  WHERE f.person_id IS NULL
    AND ps.is_active = true
    AND f.norm_last IS NOT NULL AND f.norm_last != ''
    AND f.norm_zip5 IS NOT NULL AND LENGTH(f.norm_zip5) = 5
  ORDER BY f.id, ps.person_id
)
UPDATE public.fec_donations f
SET person_id = m.person_id
FROM matches m WHERE f.id = m.fec_id;

DO $$
DECLARE v_t1 bigint;
BEGIN
  SELECT COUNT(*) INTO v_t1 FROM public.fec_donations WHERE person_id IS NOT NULL;
  RAISE NOTICE 'After Tier 1: % linked', v_t1;
END $$;

-- ════════════════════════════════════════════════════════════
-- TIER 2: Last + zip5 + canonical first (nickname resolution)
-- Pre-materialize canonical names to avoid expensive runtime JOINs
-- ════════════════════════════════════════════════════════════
DO $$ BEGIN RAISE NOTICE '── Tier 2: building canonical name lookup ──'; END $$;

-- Build canonical first name for unlinked FEC records
DROP TABLE IF EXISTS staging.fec_canonical;
CREATE TABLE staging.fec_canonical AS
SELECT f.id AS fec_id,
       f.norm_last,
       f.norm_zip5,
       COALESCE(nv.canonical, f.norm_first) AS canonical_first
FROM public.fec_donations f
LEFT JOIN public.name_variants nv ON nv.nickname = f.norm_first
WHERE f.person_id IS NULL
  AND f.norm_last IS NOT NULL AND f.norm_last != ''
  AND f.norm_zip5 IS NOT NULL AND LENGTH(f.norm_zip5) = 5;

CREATE INDEX idx_fec_canonical_match ON staging.fec_canonical (norm_last, norm_zip5, canonical_first);

-- Build canonical first name for spine
DROP TABLE IF EXISTS staging.spine_canonical;
CREATE TABLE staging.spine_canonical AS
SELECT ps.person_id,
       ps.norm_last,
       ps.zip5,
       ps.norm_first,
       COALESCE(nv.canonical, ps.norm_first) AS canonical_first
FROM core.person_spine ps
LEFT JOIN public.name_variants nv ON nv.nickname = ps.norm_first
WHERE ps.is_active = true
  AND ps.norm_last IS NOT NULL AND ps.norm_last != ''
  AND ps.zip5 IS NOT NULL AND LENGTH(ps.zip5) = 5;

CREATE INDEX idx_spine_canonical_match ON staging.spine_canonical (norm_last, zip5, canonical_first);

DO $$ BEGIN RAISE NOTICE '── Tier 2: matching on canonical names ──'; END $$;

-- Now join on pre-computed canonical names (fast equi-join)
WITH matches AS (
  SELECT DISTINCT ON (fc.fec_id)
    fc.fec_id, sc.person_id
  FROM staging.fec_canonical fc
  JOIN staging.spine_canonical sc
    ON fc.norm_last = sc.norm_last
    AND fc.norm_zip5 = sc.zip5
    AND fc.canonical_first = sc.canonical_first
  -- Skip exact first-name matches (already caught in Tier 1)
  JOIN public.fec_donations f ON f.id = fc.fec_id
  JOIN core.person_spine ps ON ps.person_id = sc.person_id
  WHERE f.norm_first != ps.norm_first
  ORDER BY fc.fec_id, sc.person_id
)
UPDATE public.fec_donations f
SET person_id = m.person_id
FROM matches m WHERE f.id = m.fec_id;

DROP TABLE IF EXISTS staging.fec_canonical;
DROP TABLE IF EXISTS staging.spine_canonical;

DO $$
DECLARE v_t2 bigint;
BEGIN
  SELECT COUNT(*) INTO v_t2 FROM public.fec_donations WHERE person_id IS NOT NULL;
  RAISE NOTICE 'After Tier 2: % linked', v_t2;
END $$;

-- ════════════════════════════════════════════════════════════
-- TIER 3: Last + zip5 + street number + first initial (0.85)
-- ════════════════════════════════════════════════════════════
DO $$ BEGIN RAISE NOTICE '── Tier 3: last+zip+street number+initial ──'; END $$;

WITH matches AS (
  SELECT DISTINCT ON (f.id)
    f.id AS fec_id, ps.person_id
  FROM public.fec_donations f
  JOIN core.person_spine ps
    ON f.norm_last = ps.norm_last
    AND f.norm_zip5 = ps.zip5
  WHERE f.person_id IS NULL
    AND ps.is_active = true
    AND f.norm_street_num IS NOT NULL AND f.norm_street_num != ''
    AND ps.street IS NOT NULL
    AND REGEXP_REPLACE(ps.street, '[^0-9].*', '') = f.norm_street_num
    AND LEFT(f.norm_first, 1) = LEFT(ps.norm_first, 1)
  ORDER BY f.id, ps.person_id
)
UPDATE public.fec_donations f
SET person_id = m.person_id
FROM matches m WHERE f.id = m.fec_id;

DO $$
DECLARE v_t3 bigint;
BEGIN
  SELECT COUNT(*) INTO v_t3 FROM public.fec_donations WHERE person_id IS NOT NULL;
  RAISE NOTICE 'After Tier 3: % linked', v_t3;
END $$;

-- ── Post-flight verification ───────────────────────────────
DO $$
DECLARE 
  v_total bigint; v_linked bigint; v_unlinked bigint;
  v_linked_dollars numeric; v_unlinked_dollars numeric;
BEGIN
  SELECT COUNT(*) INTO v_total FROM public.fec_donations WHERE is_memo = false;
  SELECT COUNT(*), COALESCE(SUM(contribution_amount),0) 
    INTO v_linked, v_linked_dollars 
    FROM public.fec_donations WHERE is_memo = false AND person_id IS NOT NULL;
  v_unlinked := v_total - v_linked;
  SELECT COALESCE(SUM(contribution_amount),0) INTO v_unlinked_dollars 
    FROM public.fec_donations WHERE is_memo = false AND person_id IS NULL;
  
  RAISE NOTICE '══════════════════════════════════════';
  RAISE NOTICE 'FINAL: total=% | linked=% (%) | unlinked=%', 
    v_total, v_linked, ROUND(v_linked::numeric / v_total * 100, 1), v_unlinked;
  RAISE NOTICE 'Linked $: % | Unlinked $: %', v_linked_dollars, v_unlinked_dollars;
  RAISE NOTICE '══════════════════════════════════════';
END $$;

-- ── Broyhill spot check ────────────────────────────────────
DO $$
DECLARE v_cnt bigint; v_total numeric;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(contribution_amount), 0)
    INTO v_cnt, v_total
  FROM public.fec_donations
  WHERE norm_last = 'BROYHILL' AND person_id IS NOT NULL AND is_memo = false;
  RAISE NOTICE 'BROYHILL: % linked non-memo donations, $%', v_cnt, v_total;
END $$;

DO $$ BEGIN RAISE NOTICE '── 083v3 COMPLETE ──'; END $$;

RESET statement_timeout;
