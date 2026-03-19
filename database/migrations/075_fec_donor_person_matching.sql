-- ============================================================================
-- MIGRATION 075: Link FEC Donations to core.person_spine
-- ============================================================================
-- PROBLEM: FEC donation records exist in public.fec_donations but are NOT
--          linked to our unified identity system (core.person_spine).
--
-- STRATEGY: Multi-pass matching (exact → nickname → address → employer+state)
--           Populate fec_donation_person_map, update fec_donations.person_id,
--           refresh person_spine donation aggregates.
--
-- SCHEMA NOTES:
--   - public.fec_donations: contributor_last, contributor_first (normalized
--     in SQL as UPPER(TRIM(...)) for matching); contributor_zip5, contributor_street_1,
--     contributor_state, employer_normalized, is_memo
--   - core.person_spine: norm_last, norm_first, nickname_canonical, zip5,
--     addr_hash, employer, state, is_active
--
-- SAFETY: Audit table, snapshot for rollback. Skip is_memo = true.
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 0: Create audit table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.migration_075_audit (
    audit_id SERIAL PRIMARY KEY,
    match_method TEXT NOT NULL,
    records_matched INT NOT NULL,
    pct_of_total NUMERIC(5,2),
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- STEP 1: Add person_id column to public.fec_donations
-- ============================================================================
ALTER TABLE public.fec_donations
ADD COLUMN IF NOT EXISTS person_id BIGINT REFERENCES core.person_spine(person_id);

-- ============================================================================
-- STEP 2: Create linking table core.fec_donation_person_map
-- ============================================================================
CREATE TABLE IF NOT EXISTS core.fec_donation_person_map (
    fec_donation_id INTEGER NOT NULL REFERENCES public.fec_donations(id) ON DELETE CASCADE,
    person_id BIGINT NOT NULL REFERENCES core.person_spine(person_id) ON DELETE CASCADE,
    match_method TEXT NOT NULL,
    match_confidence NUMERIC(4,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (fec_donation_id),
    CONSTRAINT chk_match_method CHECK (match_method IN ('pass1_exact', 'pass2_nickname', 'pass3_address', 'pass4_employer'))
);

-- ============================================================================
-- STEP 3: Create indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_fec_donations_person_id
    ON public.fec_donations(person_id) WHERE person_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fec_donation_person_map_person
    ON core.fec_donation_person_map(person_id);

CREATE INDEX IF NOT EXISTS idx_fec_donations_norm_match
    ON public.fec_donations(contributor_last, contributor_first, contributor_zip5)
    WHERE contributor_last IS NOT NULL AND contributor_first IS NOT NULL AND contributor_zip5 IS NOT NULL;

-- ============================================================================
-- STEP 4: Snapshot for rollback (donations not yet linked)
-- ============================================================================
DROP TABLE IF EXISTS public.migration_075_snapshot;
CREATE TABLE public.migration_075_snapshot AS
SELECT id, person_id
FROM public.fec_donations
WHERE is_memo = FALSE AND person_id IS NULL;

-- ============================================================================
-- STEP 5: Multi-pass matching (DO block)
-- ============================================================================
DO $$
DECLARE
    v_total_fec INT;
    v_total_non_memo INT;
    v_pass1 INT := 0;
    v_pass2 INT := 0;
    v_pass3 INT := 0;
    v_pass4 INT := 0;
    v_total_matched INT := 0;
    v_pct NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_total_fec FROM public.fec_donations;
    SELECT COUNT(*) INTO v_total_non_memo FROM public.fec_donations WHERE is_memo = FALSE;
    RAISE NOTICE '%', format('MIGRATION 075: Total fec_donations=%s, non-MEMO=%s', v_total_fec, v_total_non_memo);

    -- -------------------------------------------------------------------------
    -- PASS 1: Exact name + zip (confidence 0.95)
    -- contributor_last_norm = norm_last, contributor_first_norm = norm_first, contributor_zip5 = zip5
    -- Skip is_memo = true. Only active spine.
    -- -------------------------------------------------------------------------
    INSERT INTO core.fec_donation_person_map (fec_donation_id, person_id, match_method, match_confidence)
    SELECT DISTINCT ON (fd.id)
        fd.id,
        sp.person_id,
        'pass1_exact',
        0.95
    FROM public.fec_donations fd
    JOIN core.person_spine sp
        ON UPPER(TRIM(COALESCE(fd.contributor_last, ''))) = sp.norm_last
        AND UPPER(TRIM(COALESCE(fd.contributor_first, ''))) = sp.norm_first
        AND fd.contributor_zip5 = sp.zip5
    WHERE fd.is_memo = FALSE
      AND sp.is_active = TRUE
      AND fd.contributor_last IS NOT NULL
      AND fd.contributor_first IS NOT NULL
      AND fd.contributor_zip5 IS NOT NULL
      AND sp.norm_last IS NOT NULL
      AND sp.norm_first IS NOT NULL
      AND sp.zip5 IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM core.fec_donation_person_map m WHERE m.fec_donation_id = fd.id)
    ORDER BY fd.id, sp.contribution_count DESC NULLS LAST;

    GET DIAGNOSTICS v_pass1 = ROW_COUNT;
    RAISE NOTICE '%', format('PASS 1 (exact name+zip): %s matched', v_pass1);

    -- -------------------------------------------------------------------------
    -- PASS 2: Nickname (confidence 0.85)
    -- contributor_last_norm = norm_last, contributor_first_norm = nickname_canonical, contributor_zip5 = zip5
    -- Only for records NOT matched in Pass 1
    -- -------------------------------------------------------------------------
    INSERT INTO core.fec_donation_person_map (fec_donation_id, person_id, match_method, match_confidence)
    SELECT DISTINCT ON (fd.id)
        fd.id,
        sp.person_id,
        'pass2_nickname',
        0.85
    FROM public.fec_donations fd
    JOIN core.person_spine sp
        ON UPPER(TRIM(COALESCE(fd.contributor_last, ''))) = sp.norm_last
        AND UPPER(TRIM(COALESCE(fd.contributor_first, ''))) = sp.nickname_canonical
        AND fd.contributor_zip5 = sp.zip5
    WHERE fd.is_memo = FALSE
      AND sp.is_active = TRUE
      AND sp.nickname_canonical IS NOT NULL
      AND sp.nickname_canonical != ''
      AND fd.contributor_last IS NOT NULL
      AND fd.contributor_first IS NOT NULL
      AND fd.contributor_zip5 IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM core.fec_donation_person_map m WHERE m.fec_donation_id = fd.id)
    ORDER BY fd.id, sp.contribution_count DESC NULLS LAST;

    GET DIAGNOSTICS v_pass2 = ROW_COUNT;
    RAISE NOTICE '%', format('PASS 2 (nickname): %s matched', v_pass2);

    -- -------------------------------------------------------------------------
    -- PASS 3: Address (confidence 0.80)
    -- contributor_last_norm = norm_last, contributor_first_norm = norm_first
    -- AND md5(lower(trim(contributor_street_1)) || contributor_zip5) = addr_hash
    -- Only for records NOT matched in Pass 1-2
    -- -------------------------------------------------------------------------
    INSERT INTO core.fec_donation_person_map (fec_donation_id, person_id, match_method, match_confidence)
    SELECT DISTINCT ON (fd.id)
        fd.id,
        sp.person_id,
        'pass3_address',
        0.80
    FROM public.fec_donations fd
    JOIN core.person_spine sp
        ON UPPER(TRIM(COALESCE(fd.contributor_last, ''))) = sp.norm_last
        AND UPPER(TRIM(COALESCE(fd.contributor_first, ''))) = sp.norm_first
        AND md5(lower(TRIM(COALESCE(fd.contributor_street_1, ''))) || COALESCE(fd.contributor_zip5, '')) = sp.addr_hash
    WHERE fd.is_memo = FALSE
      AND sp.is_active = TRUE
      AND sp.addr_hash IS NOT NULL
      AND sp.addr_hash != ''
      AND fd.contributor_last IS NOT NULL
      AND fd.contributor_first IS NOT NULL
      AND fd.contributor_street_1 IS NOT NULL
      AND fd.contributor_street_1 != ''
      AND fd.contributor_zip5 IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM core.fec_donation_person_map m WHERE m.fec_donation_id = fd.id)
    ORDER BY fd.id, sp.contribution_count DESC NULLS LAST;

    GET DIAGNOSTICS v_pass3 = ROW_COUNT;
    RAISE NOTICE '%', format('PASS 3 (address): %s matched', v_pass3);

    -- -------------------------------------------------------------------------
    -- PASS 4: Employer + State (confidence 0.70)
    -- contributor_last_norm = norm_last, contributor_first_norm = norm_first
    -- AND employer_normalized = lower(trim(employer)) AND contributor_state = state
    -- Only for records NOT matched in Pass 1-3
    -- -------------------------------------------------------------------------
    INSERT INTO core.fec_donation_person_map (fec_donation_id, person_id, match_method, match_confidence)
    SELECT DISTINCT ON (fd.id)
        fd.id,
        sp.person_id,
        'pass4_employer',
        0.70
    FROM public.fec_donations fd
    JOIN core.person_spine sp
        ON UPPER(TRIM(COALESCE(fd.contributor_last, ''))) = sp.norm_last
        AND UPPER(TRIM(COALESCE(fd.contributor_first, ''))) = sp.norm_first
        AND lower(TRIM(COALESCE(fd.employer_normalized, ''))) = lower(TRIM(COALESCE(sp.employer, '')))
        AND COALESCE(fd.contributor_state, '') = COALESCE(sp.state, '')
    WHERE fd.is_memo = FALSE
      AND sp.is_active = TRUE
      AND fd.contributor_last IS NOT NULL
      AND fd.contributor_first IS NOT NULL
      AND fd.employer_normalized IS NOT NULL
      AND fd.employer_normalized != ''
      AND sp.employer IS NOT NULL
      AND sp.employer != ''
      AND NOT EXISTS (SELECT 1 FROM core.fec_donation_person_map m WHERE m.fec_donation_id = fd.id)
    ORDER BY fd.id, sp.contribution_count DESC NULLS LAST;

    GET DIAGNOSTICS v_pass4 = ROW_COUNT;
    RAISE NOTICE '%', format('PASS 4 (employer+state): %s matched', v_pass4);

    -- -------------------------------------------------------------------------
    -- Audit records
    -- -------------------------------------------------------------------------
    v_total_matched := v_pass1 + v_pass2 + v_pass3 + v_pass4;
    v_pct := ROUND(v_total_matched::numeric / NULLIF(v_total_non_memo, 0) * 100, 2);

    INSERT INTO public.migration_075_audit (match_method, records_matched, pct_of_total)
    VALUES
        ('pass1_exact', v_pass1, ROUND(v_pass1::numeric / NULLIF(v_total_non_memo, 0) * 100, 2)),
        ('pass2_nickname', v_pass2, ROUND(v_pass2::numeric / NULLIF(v_total_non_memo, 0) * 100, 2)),
        ('pass3_address', v_pass3, ROUND(v_pass3::numeric / NULLIF(v_total_non_memo, 0) * 100, 2)),
        ('pass4_employer', v_pass4, ROUND(v_pass4::numeric / NULLIF(v_total_non_memo, 0) * 100, 2));

    RAISE NOTICE '%', format('TOTAL MATCHED: %s / %s (%s%%)', v_total_matched, v_total_non_memo, v_pct);
    RAISE NOTICE '%', format('REMAINING UNMATCHED: %s', v_total_non_memo - v_total_matched);
END $$;

-- ============================================================================
-- STEP 6: UPDATE public.fec_donations SET person_id from map
-- ============================================================================
UPDATE public.fec_donations fd
SET person_id = m.person_id
FROM core.fec_donation_person_map m
WHERE fd.id = m.fec_donation_id
  AND fd.person_id IS NULL;

-- ============================================================================
-- STEP 7: Update person_spine donation aggregates for matched persons
-- ============================================================================
UPDATE core.person_spine sp
SET
    total_contributed = agg.tot,
    contribution_count = agg.cnt,
    first_contribution = agg.first_dt,
    last_contribution = agg.last_dt,
    max_single_gift = agg.max_amt,
    avg_gift = agg.avg_amt,
    updated_at = NOW()
FROM (
    SELECT
        m.person_id,
        SUM(fd.contribution_amount) AS tot,
        COUNT(*)::INT AS cnt,
        MIN(fd.contribution_date) AS first_dt,
        MAX(fd.contribution_date) AS last_dt,
        MAX(fd.contribution_amount) AS max_amt,
        AVG(fd.contribution_amount) AS avg_amt
    FROM core.fec_donation_person_map m
    JOIN public.fec_donations fd ON fd.id = m.fec_donation_id
    GROUP BY m.person_id
) agg
WHERE sp.person_id = agg.person_id;

-- ============================================================================
-- STEP 8: Final report
-- ============================================================================
DO $$
DECLARE
    v_linked INT;
    v_total INT;
    v_pct NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_total FROM public.fec_donations WHERE is_memo = FALSE;
    SELECT COUNT(*) INTO v_linked FROM public.fec_donations WHERE is_memo = FALSE AND person_id IS NOT NULL;
    v_pct := ROUND(v_linked::numeric / NULLIF(v_total, 0) * 100, 1);
    RAISE NOTICE '%', format('============================================');
    RAISE NOTICE '%', format('MIGRATION 075 — FINAL REPORT');
    RAISE NOTICE '%', format('============================================');
    RAISE NOTICE '%', format('FEC donations linked to person_spine: %s / %s (%s%%)', v_linked, v_total, v_pct);
    RAISE NOTICE '%', format('============================================');
END $$;

COMMIT;

-- ============================================================================
-- ROLLBACK SCRIPT (run separately if needed)
-- ============================================================================
-- BEGIN;
-- UPDATE public.fec_donations fd
-- SET person_id = s.person_id
-- FROM public.migration_075_snapshot s
-- WHERE fd.id = s.id;
-- DELETE FROM core.fec_donation_person_map;
-- -- Optionally: revert person_spine aggregates (requires pre-migration snapshot)
-- COMMIT;
