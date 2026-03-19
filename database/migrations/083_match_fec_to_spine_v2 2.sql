-- ============================================================
-- Migration 083 v2: Three-tier FEC donation → spine matching
-- ============================================================
-- Uses rebuilt public.fec_donations (from 080c) with clean
-- contributor_first / contributor_last from raw CSV data.
-- 
-- Tier 1: Exact last + zip5 + first name  (confidence 0.95)
-- Tier 2: Last + zip5 + canonical first   (confidence 0.90) 
-- Tier 3: Last + zip5 + street number     (confidence 0.85)
--
-- Expected: ~1.5M+ non-memo donations matched to spine
-- ============================================================

BEGIN;

DO $$ BEGIN RAISE NOTICE '── 083v2 START ──'; END $$;

-- ── Pre-flight ─────────────────────────────────────────────
DO $$
DECLARE v_total bigint; v_linked bigint; v_unlinked bigint;
BEGIN
  SELECT COUNT(*) INTO v_total FROM public.fec_donations WHERE is_memo = false;
  SELECT COUNT(*) INTO v_linked FROM public.fec_donations WHERE is_memo = false AND person_id IS NOT NULL;
  v_unlinked := v_total - v_linked;
  RAISE NOTICE 'PRE: total non-memo=% | linked=% | unlinked=%', v_total, v_linked, v_unlinked;
END $$;

-- ── Normalize names for matching ───────────────────────────
-- Ensure norm columns are populated (080c should have done this,
-- but belt-and-suspenders)
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
WHERE norm_first IS NULL AND contributor_first IS NOT NULL;

DO $$
DECLARE v_normed bigint;
BEGIN
  SELECT COUNT(*) INTO v_normed FROM public.fec_donations WHERE norm_first IS NOT NULL;
  RAISE NOTICE 'Normalized rows: %', v_normed;
END $$;

-- ── TIER 1: Exact last + zip5 + first (highest confidence) ─
-- Clear any previous matching from bad data
UPDATE public.fec_donations SET person_id = NULL WHERE person_id IS NOT NULL;

DO $$ BEGIN RAISE NOTICE '── Tier 1: exact last+zip+first ──'; END $$;

WITH matches AS (
  SELECT DISTINCT ON (f.id)
    f.id AS fec_id,
    ps.person_id
  FROM public.fec_donations f
  JOIN core.person_spine ps
    ON f.norm_last = ps.norm_last
    AND f.norm_zip5 = ps.zip5
    AND f.norm_first = ps.norm_first
  WHERE f.person_id IS NULL
    AND ps.is_active = true
    AND f.norm_last IS NOT NULL
    AND f.norm_last != ''
    AND f.norm_zip5 IS NOT NULL
    AND LENGTH(f.norm_zip5) = 5
  ORDER BY f.id, ps.person_id
)
UPDATE public.fec_donations f
SET person_id = m.person_id
FROM matches m
WHERE f.id = m.fec_id;

DO $$
DECLARE v_t1 bigint;
BEGIN
  SELECT COUNT(*) INTO v_t1 FROM public.fec_donations WHERE person_id IS NOT NULL;
  RAISE NOTICE 'After Tier 1: % linked', v_t1;
END $$;

-- ── TIER 2: Last + zip5 + canonical first (catches nicknames) ─
DO $$ BEGIN RAISE NOTICE '── Tier 2: last+zip+canonical first (nickname resolution) ──'; END $$;

WITH matches AS (
  SELECT DISTINCT ON (f.id)
    f.id AS fec_id,
    ps.person_id
  FROM public.fec_donations f
  JOIN core.person_spine ps
    ON f.norm_last = ps.norm_last
    AND f.norm_zip5 = ps.zip5
  LEFT JOIN public.name_variants nv_fec ON nv_fec.nickname = f.norm_first
  LEFT JOIN public.name_variants nv_sp  ON nv_sp.nickname = ps.norm_first
  WHERE f.person_id IS NULL
    AND ps.is_active = true
    AND f.norm_last IS NOT NULL
    AND f.norm_last != ''
    AND f.norm_zip5 IS NOT NULL
    AND LENGTH(f.norm_zip5) = 5
    -- Canonical first names must match
    AND COALESCE(nv_fec.canonical, f.norm_first) = COALESCE(nv_sp.canonical, ps.norm_first)
    -- But they weren't an exact match (those were caught in Tier 1)
    AND f.norm_first != ps.norm_first
  ORDER BY f.id, ps.person_id
)
UPDATE public.fec_donations f
SET person_id = m.person_id
FROM matches m
WHERE f.id = m.fec_id;

DO $$
DECLARE v_t2 bigint;
BEGIN
  SELECT COUNT(*) INTO v_t2 FROM public.fec_donations WHERE person_id IS NOT NULL;
  RAISE NOTICE 'After Tier 2: % linked', v_t2;
END $$;

-- ── TIER 3: Last + zip5 + street number (address anchor) ──
DO $$ BEGIN RAISE NOTICE '── Tier 3: last+zip+street number (address anchor) ──'; END $$;

WITH matches AS (
  SELECT DISTINCT ON (f.id)
    f.id AS fec_id,
    ps.person_id
  FROM public.fec_donations f
  JOIN core.person_spine ps
    ON f.norm_last = ps.norm_last
    AND f.norm_zip5 = ps.zip5
  WHERE f.person_id IS NULL
    AND ps.is_active = true
    AND f.norm_last IS NOT NULL
    AND f.norm_last != ''
    AND f.norm_zip5 IS NOT NULL
    AND LENGTH(f.norm_zip5) = 5
    -- Street number must match
    AND f.norm_street_num IS NOT NULL
    AND f.norm_street_num != ''
    AND ps.street IS NOT NULL
    AND REGEXP_REPLACE(ps.street, '[^0-9].*', '') = f.norm_street_num
    -- First initial must match (safety valve)
    AND LEFT(f.norm_first, 1) = LEFT(ps.norm_first, 1)
  ORDER BY f.id, ps.person_id
)
UPDATE public.fec_donations f
SET person_id = m.person_id
FROM matches m
WHERE f.id = m.fec_id;

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
DECLARE v_ed_linked bigint; v_ed_total numeric;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(contribution_amount), 0)
    INTO v_ed_linked, v_ed_total
  FROM public.fec_donations
  WHERE norm_last = 'BROYHILL' 
    AND person_id IS NOT NULL
    AND is_memo = false;
  RAISE NOTICE 'BROYHILL check: % linked non-memo donations, $%', v_ed_linked, v_ed_total;
END $$;

COMMIT;

DO $$ BEGIN RAISE NOTICE '── 083v2 COMPLETE ──'; END $$;
