-- ============================================================
-- Migration 084: Match party committee donations to person_spine
-- ============================================================
-- Adds person_id column to fec_party_committee_donations and
-- runs three-tier matching (same as 083v3).
-- Then adds party donations to contribution_map and recalculates
-- spine aggregates.
-- ============================================================

SET statement_timeout = '900s';

DO $$ BEGIN RAISE NOTICE '── 084 START ──'; END $$;

-- ── Step 0: Add person_id column if not exists ─────────────
ALTER TABLE public.fec_party_committee_donations
  ADD COLUMN IF NOT EXISTS person_id bigint;

-- Add norm_street_num for Tier 3 matching
ALTER TABLE public.fec_party_committee_donations
  ADD COLUMN IF NOT EXISTS norm_street_num text;

-- ── Pre-flight ─────────────────────────────────────────────
DO $$
DECLARE v_total bigint; v_with_name bigint;
BEGIN
  SELECT COUNT(*), COUNT(*) FILTER (WHERE norm_last IS NOT NULL) 
    INTO v_total, v_with_name
  FROM public.fec_party_committee_donations;
  RAISE NOTICE 'PRE: total=% | with_name=%', v_total, v_with_name;
END $$;

-- ════════════════════════════════════════════════════════════
-- TIER 1: Exact last + zip5 + first (confidence 0.95)
-- ════════════════════════════════════════════════════════════
DO $$ BEGIN RAISE NOTICE '── Tier 1: exact last+zip+first ──'; END $$;

WITH matches AS (
  SELECT DISTINCT ON (f.id)
    f.id AS fec_id, ps.person_id
  FROM public.fec_party_committee_donations f
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
UPDATE public.fec_party_committee_donations f
SET person_id = m.person_id
FROM matches m WHERE f.id = m.fec_id;

DO $$
DECLARE v_t1 bigint;
BEGIN
  SELECT COUNT(*) INTO v_t1 FROM public.fec_party_committee_donations WHERE person_id IS NOT NULL;
  RAISE NOTICE 'After Tier 1: % linked', v_t1;
END $$;

-- ════════════════════════════════════════════════════════════
-- TIER 2: Last + zip5 + canonical first (nickname resolution)
-- ════════════════════════════════════════════════════════════
DO $$ BEGIN RAISE NOTICE '── Tier 2: building canonical name lookup ──'; END $$;

DROP TABLE IF EXISTS staging.party_canonical;
CREATE TABLE staging.party_canonical AS
SELECT f.id AS fec_id,
       f.norm_last,
       f.norm_zip5,
       COALESCE(nv.canonical, f.norm_first) AS canonical_first
FROM public.fec_party_committee_donations f
LEFT JOIN public.name_variants nv ON nv.nickname = f.norm_first
WHERE f.person_id IS NULL
  AND f.norm_last IS NOT NULL AND f.norm_last != ''
  AND f.norm_zip5 IS NOT NULL AND LENGTH(f.norm_zip5) = 5;

CREATE INDEX idx_party_canonical_match ON staging.party_canonical (norm_last, norm_zip5, canonical_first);

-- Reuse spine_canonical if it exists, else create
DROP TABLE IF EXISTS staging.spine_canonical;
CREATE TABLE staging.spine_canonical AS
SELECT ps.person_id, ps.norm_last, ps.zip5, ps.norm_first,
       COALESCE(nv.canonical, ps.norm_first) AS canonical_first
FROM core.person_spine ps
LEFT JOIN public.name_variants nv ON nv.nickname = ps.norm_first
WHERE ps.is_active = true
  AND ps.norm_last IS NOT NULL AND ps.norm_last != ''
  AND ps.zip5 IS NOT NULL AND LENGTH(ps.zip5) = 5;

CREATE INDEX idx_spine_canonical_match ON staging.spine_canonical (norm_last, zip5, canonical_first);

DO $$ BEGIN RAISE NOTICE '── Tier 2: matching on canonical names ──'; END $$;

WITH matches AS (
  SELECT DISTINCT ON (fc.fec_id)
    fc.fec_id, sc.person_id
  FROM staging.party_canonical fc
  JOIN staging.spine_canonical sc
    ON fc.norm_last = sc.norm_last
    AND fc.norm_zip5 = sc.zip5
    AND fc.canonical_first = sc.canonical_first
  JOIN public.fec_party_committee_donations f ON f.id = fc.fec_id
  JOIN core.person_spine ps ON ps.person_id = sc.person_id
  WHERE f.norm_first != ps.norm_first
  ORDER BY fc.fec_id, sc.person_id
)
UPDATE public.fec_party_committee_donations f
SET person_id = m.person_id
FROM matches m WHERE f.id = m.fec_id;

DROP TABLE IF EXISTS staging.party_canonical;
DROP TABLE IF EXISTS staging.spine_canonical;

DO $$
DECLARE v_t2 bigint;
BEGIN
  SELECT COUNT(*) INTO v_t2 FROM public.fec_party_committee_donations WHERE person_id IS NOT NULL;
  RAISE NOTICE 'After Tier 2: % linked', v_t2;
END $$;

-- ════════════════════════════════════════════════════════════
-- TIER 3: Last + zip5 + first initial (relaxed - no street on this table)
-- ════════════════════════════════════════════════════════════
-- NOTE: fec_party_committee_donations has no street address,
-- so Tier 3 is skipped. Tier 1+2 are sufficient.

-- ── Post-flight ────────────────────────────────────────────
DO $$
DECLARE 
  v_total bigint; v_linked bigint;
  v_linked_dollars numeric; v_unlinked_dollars numeric;
BEGIN
  SELECT COUNT(*) INTO v_total FROM public.fec_party_committee_donations;
  SELECT COUNT(*), COALESCE(SUM(transaction_amount),0)
    INTO v_linked, v_linked_dollars
    FROM public.fec_party_committee_donations WHERE person_id IS NOT NULL;
  SELECT COALESCE(SUM(transaction_amount),0) INTO v_unlinked_dollars 
    FROM public.fec_party_committee_donations WHERE person_id IS NULL;
  
  RAISE NOTICE '══════════════════════════════════════';
  RAISE NOTICE 'PARTY: total=% | linked=% (%) | unlinked=%',
    v_total, v_linked, ROUND(v_linked::numeric / v_total * 100, 1), v_total - v_linked;
  RAISE NOTICE 'Linked $: % | Unlinked $: %', v_linked_dollars, v_unlinked_dollars;
  RAISE NOTICE '══════════════════════════════════════';
END $$;

-- ── Add party donations to contribution_map ────────────────
DO $$ BEGIN RAISE NOTICE '── Adding party donations to contribution_map ──'; END $$;

DELETE FROM core.contribution_map WHERE source_system = 'fec_party';

INSERT INTO core.contribution_map (
  person_id, source_system, source_id, amount, transaction_date, committee_id
)
SELECT
  f.person_id,
  'fec_party',
  f.id::bigint,
  f.transaction_amount,
  f.transaction_date::date,
  f.committee_id
FROM public.fec_party_committee_donations f
WHERE f.person_id IS NOT NULL
  AND f.transaction_amount IS NOT NULL;

-- ── Recalculate spine aggregates ───────────────────────────
DO $$ BEGIN RAISE NOTICE '── Recalculating spine aggregates ──'; END $$;

UPDATE core.person_spine ps SET
  total_contributed = agg.total_amt,
  contribution_count = agg.cnt,
  first_contribution = agg.first_dt,
  last_contribution = agg.last_dt
FROM (
  SELECT person_id,
    SUM(amount) AS total_amt, COUNT(*) AS cnt,
    MIN(transaction_date) AS first_dt, MAX(transaction_date) AS last_dt
  FROM core.contribution_map
  GROUP BY person_id
) agg
WHERE ps.person_id = agg.person_id;

UPDATE core.person_spine SET
  total_contributed = 0, contribution_count = 0,
  first_contribution = NULL, last_contribution = NULL
WHERE total_contributed > 0
  AND person_id NOT IN (SELECT DISTINCT person_id FROM core.contribution_map);

-- ── Final verification ─────────────────────────────────────
DO $$
DECLARE 
  v_cm_total bigint; v_cm_dollars numeric;
  v_spine_donors bigint; v_spine_dollars numeric;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(amount),0) INTO v_cm_total, v_cm_dollars FROM core.contribution_map;
  SELECT COUNT(*), COALESCE(SUM(total_contributed),0) INTO v_spine_donors, v_spine_dollars
    FROM core.person_spine WHERE total_contributed > 0;
  
  RAISE NOTICE '══════════════════════════════════════';
  RAISE NOTICE 'FINAL contribution_map: % rows, $%', v_cm_total, v_cm_dollars;
  RAISE NOTICE 'FINAL spine donors: %, $%', v_spine_donors, v_spine_dollars;
  RAISE NOTICE '══════════════════════════════════════';
END $$;

-- Broyhill spot check
DO $$
DECLARE v_cnt bigint; v_total numeric;
BEGIN
  SELECT contribution_count, total_contributed INTO v_cnt, v_total
  FROM core.person_spine WHERE norm_last='BROYHILL' AND norm_first='EDWARD' AND is_active=true
  LIMIT 1;
  RAISE NOTICE 'BROYHILL EDWARD (active): % contributions, $%', v_cnt, v_total;
END $$;

DO $$ BEGIN RAISE NOTICE '── 084 COMPLETE ──'; END $$;
RESET statement_timeout;
