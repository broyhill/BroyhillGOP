-- ============================================================
-- Migration 085: Rebuild contribution_map + spine aggregates
-- ============================================================
-- Replaces all FEC entries in contribution_map with fresh data
-- from the newly matched public.fec_donations, then recalculates
-- spine aggregate columns.
-- ============================================================

SET statement_timeout = '900s';

DO $$ BEGIN RAISE NOTICE '── 085 START ──'; END $$;

-- ── Pre-flight ─────────────────────────────────────────────
DO $$
DECLARE v_cm bigint; v_fec bigint; v_ncboe bigint;
BEGIN
  SELECT COUNT(*) INTO v_cm FROM core.contribution_map;
  SELECT COUNT(*) INTO v_fec FROM core.contribution_map WHERE source_system LIKE 'fec%';
  SELECT COUNT(*) INTO v_ncboe FROM core.contribution_map WHERE source_system = 'NC_BOE';
  RAISE NOTICE 'PRE: contribution_map=% | fec_entries=% | nc_boe=%', v_cm, v_fec, v_ncboe;
END $$;

-- ── Step 1: Delete old FEC entries ─────────────────────────
DELETE FROM core.contribution_map WHERE source_system LIKE 'fec%';

DO $$
DECLARE v_remaining bigint;
BEGIN
  SELECT COUNT(*) INTO v_remaining FROM core.contribution_map;
  RAISE NOTICE 'After FEC delete: % remaining (NC_BOE etc.)', v_remaining;
END $$;

-- ── Step 2: Insert new FEC entries (non-memo, linked only) ──
INSERT INTO core.contribution_map (
  person_id, source_system, source_id, amount, transaction_date, committee_id
)
SELECT
  f.person_id,
  'fec_donations',
  f.id,
  f.contribution_amount,
  f.contribution_date,
  f.committee_id
FROM public.fec_donations f
WHERE f.person_id IS NOT NULL
  AND f.is_memo = false
  AND f.contribution_amount IS NOT NULL;

DO $$
DECLARE v_new_fec bigint; v_total bigint;
BEGIN
  SELECT COUNT(*) INTO v_new_fec FROM core.contribution_map WHERE source_system = 'fec_donations';
  SELECT COUNT(*) INTO v_total FROM core.contribution_map;
  RAISE NOTICE 'After FEC insert: fec=% | total=%', v_new_fec, v_total;
END $$;

-- ── Step 3: Recalculate spine aggregates ───────────────────
DO $$ BEGIN RAISE NOTICE '── Recalculating spine aggregates ──'; END $$;

UPDATE core.person_spine ps SET
  total_contributed = agg.total_amt,
  contribution_count = agg.cnt,
  first_contribution = agg.first_dt,
  last_contribution = agg.last_dt
FROM (
  SELECT
    person_id,
    SUM(amount) AS total_amt,
    COUNT(*) AS cnt,
    MIN(transaction_date) AS first_dt,
    MAX(transaction_date) AS last_dt
  FROM core.contribution_map
  GROUP BY person_id
) agg
WHERE ps.person_id = agg.person_id;

-- Zero out spine records that no longer have contributions
UPDATE core.person_spine SET
  total_contributed = 0,
  contribution_count = 0,
  first_contribution = NULL,
  last_contribution = NULL
WHERE total_contributed > 0
  AND person_id NOT IN (SELECT DISTINCT person_id FROM core.contribution_map);

-- ── Post-flight ────────────────────────────────────────────
DO $$
DECLARE 
  v_total_cm bigint; v_total_dollars numeric;
  v_spine_with_contrib bigint; v_spine_total_dollars numeric;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(amount),0) INTO v_total_cm, v_total_dollars FROM core.contribution_map;
  SELECT COUNT(*), COALESCE(SUM(total_contributed),0) INTO v_spine_with_contrib, v_spine_total_dollars 
    FROM core.person_spine WHERE total_contributed > 0;
  
  RAISE NOTICE '══════════════════════════════════════';
  RAISE NOTICE 'contribution_map: % rows, $%', v_total_cm, v_total_dollars;
  RAISE NOTICE 'spine with contributions: %, $%', v_spine_with_contrib, v_spine_total_dollars;
  RAISE NOTICE '══════════════════════════════════════';
END $$;

-- Broyhill spot check
DO $$
DECLARE v_cnt bigint; v_total numeric;
BEGIN
  SELECT contribution_count, total_contributed INTO v_cnt, v_total
  FROM core.person_spine WHERE norm_last='BROYHILL' AND norm_first='EDDIE'
  ORDER BY total_contributed DESC NULLS LAST LIMIT 1;
  RAISE NOTICE 'BROYHILL EDDIE: % contributions, $%', v_cnt, v_total;
END $$;

DO $$ BEGIN RAISE NOTICE '── 085 COMPLETE ──'; END $$;
RESET statement_timeout;
