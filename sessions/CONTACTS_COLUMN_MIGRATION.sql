-- ============================================================================
-- CONTACTS_COLUMN_MIGRATION.sql
-- Promotes custom_fields->'datatrust_2026' JSON into top-level columns
-- on public.contacts.
--
-- DESIGN ONLY — DO NOT EXECUTE without explicit approval.
-- Author: Claude (BroyhillGOP session 2026-04-03)
-- Affects: 132,036 contacts that have datatrust_2026 JSON data
-- ============================================================================

-- ============================================================================
-- STEP 1: ADD NEW COLUMNS
-- These 14 keys exist in the JSON but have no matching column on contacts.
-- ============================================================================

ALTER TABLE public.contacts
  ADD COLUMN IF NOT EXISTS ethnicity          TEXT,
  ADD COLUMN IF NOT EXISTS religion           TEXT,
  ADD COLUMN IF NOT EXISTS education_level    TEXT,
  ADD COLUMN IF NOT EXISTS household_party    TEXT,
  ADD COLUMN IF NOT EXISTS household_id_datatrust TEXT,
  ADD COLUMN IF NOT EXISTS cell_source        TEXT,
  ADD COLUMN IF NOT EXISTS landline_source    TEXT,
  ADD COLUMN IF NOT EXISTS dt_cell_dnc        TEXT,
  ADD COLUMN IF NOT EXISTS dt_cell_source     TEXT,
  ADD COLUMN IF NOT EXISTS dt_cell_reliability TEXT,  ADD COLUMN IF NOT EXISTS dt_landline_dnc    TEXT,
  ADD COLUMN IF NOT EXISTS dt_landline_source TEXT,
  ADD COLUMN IF NOT EXISTS dt_landline_reliability TEXT,
  ADD COLUMN IF NOT EXISTS dt_enriched_at     TIMESTAMPTZ;

-- ============================================================================
-- STEP 2: POPULATE NEW COLUMNS from JSON
-- Only touches rows where custom_fields->'datatrust_2026' is a non-empty object.
-- ============================================================================

UPDATE public.contacts
SET
  ethnicity               = custom_fields->'datatrust_2026'->>'ethnicity',
  religion                = custom_fields->'datatrust_2026'->>'religion',
  education_level         = custom_fields->'datatrust_2026'->>'education_level',
  household_party         = custom_fields->'datatrust_2026'->>'household_party',
  household_id_datatrust  = custom_fields->'datatrust_2026'->>'household_id_datatrust',
  cell_source             = custom_fields->'datatrust_2026'->>'cell_source',
  landline_source         = custom_fields->'datatrust_2026'->>'landline_source',
  dt_cell_dnc             = custom_fields->'datatrust_2026'->>'dt_cell_dnc',
  dt_cell_source          = custom_fields->'datatrust_2026'->>'dt_cell_source',
  dt_cell_reliability     = custom_fields->'datatrust_2026'->>'dt_cell_reliability',
  dt_landline_dnc         = custom_fields->'datatrust_2026'->>'dt_landline_dnc',
  dt_landline_source      = custom_fields->'datatrust_2026'->>'dt_landline_source',
  dt_landline_reliability = custom_fields->'datatrust_2026'->>'dt_landline_reliability',
  dt_enriched_at          = (custom_fields->'datatrust_2026'->>'enriched_at')::TIMESTAMPTZWHERE custom_fields->'datatrust_2026' IS NOT NULL
  AND jsonb_typeof(custom_fields->'datatrust_2026') = 'object'
  AND custom_fields->'datatrust_2026' != '{}'::jsonb;

-- ============================================================================
-- STEP 3: UPDATE EXISTING COLUMNS from JSON
-- These columns already exist on contacts. We only overwrite if the existing
-- value is NULL or empty, to preserve any previously-set data.
-- Key mappings:
--   JSON new_rnc_regid       -> contacts.dt_rncid
--   JSON rep_ballot_score    -> contacts.republican_ballot_score
--   JSON dem_ballot_score    -> contacts.democratic_ballot_score
--   JSON turnout_score       -> contacts.turnout_score
--   JSON republican_score    -> contacts.republican_score
--   JSON democratic_score    -> contacts.democratic_score
--   JSON dt_last_update      -> contacts.dt_last_update
--   JSON vh*                 -> contacts.vh* (vote history)
--   JSON coalition_*         -> contacts.coalition_*
-- ============================================================================

UPDATE public.contacts
SET
  -- Scores (cast text to numeric)
  republican_score       = COALESCE(republican_score,
    (custom_fields->'datatrust_2026'->>'republican_score')::NUMERIC),
  democratic_score       = COALESCE(democratic_score,
    (custom_fields->'datatrust_2026'->>'democratic_score')::NUMERIC),
  turnout_score          = COALESCE(turnout_score,
    (custom_fields->'datatrust_2026'->>'turnout_score')::NUMERIC),  republican_ballot_score = COALESCE(republican_ballot_score,
    (custom_fields->'datatrust_2026'->>'rep_ballot_score')::NUMERIC),
  democratic_ballot_score = COALESCE(democratic_ballot_score,
    (custom_fields->'datatrust_2026'->>'dem_ballot_score')::NUMERIC),

  -- RNC ID and last update
  dt_rncid               = COALESCE(NULLIF(dt_rncid, ''),
    custom_fields->'datatrust_2026'->>'new_rnc_regid'),
  dt_last_update         = COALESCE(NULLIF(dt_last_update, ''),
    custom_fields->'datatrust_2026'->>'dt_last_update'),

  -- Vote history codes
  vh20g = COALESCE(NULLIF(vh20g, ''), custom_fields->'datatrust_2026'->>'vh20g'),
  vh20p = COALESCE(NULLIF(vh20p, ''), custom_fields->'datatrust_2026'->>'vh20p'),
  vh22g = COALESCE(NULLIF(vh22g, ''), custom_fields->'datatrust_2026'->>'vh22g'),
  vh22p = COALESCE(NULLIF(vh22p, ''), custom_fields->'datatrust_2026'->>'vh22p'),
  vh24g = COALESCE(NULLIF(vh24g, ''), custom_fields->'datatrust_2026'->>'vh24g'),
  vh24p = COALESCE(NULLIF(vh24p, ''), custom_fields->'datatrust_2026'->>'vh24p'),
  vh25g = COALESCE(NULLIF(vh25g, ''), custom_fields->'datatrust_2026'->>'vh25g'),
  vh25p = COALESCE(NULLIF(vh25p, ''), custom_fields->'datatrust_2026'->>'vh25p'),

  -- Coalition flags
  coalition_social_conservative = COALESCE(NULLIF(coalition_social_conservative, ''),
    custom_fields->'datatrust_2026'->>'coalition_social_conservative'),
  coalition_fiscal_conservative = COALESCE(NULLIF(coalition_fiscal_conservative, ''),
    custom_fields->'datatrust_2026'->>'coalition_fiscal_conservative'),  coalition_veteran      = COALESCE(NULLIF(coalition_veteran, ''),
    custom_fields->'datatrust_2026'->>'coalition_veteran'),
  coalition_sportsmen    = COALESCE(NULLIF(coalition_sportsmen, ''),
    custom_fields->'datatrust_2026'->>'coalition_sportsmen'),
  coalition_2nd_amendment = COALESCE(NULLIF(coalition_2nd_amendment, ''),
    custom_fields->'datatrust_2026'->>'coalition_2nd_amendment'),
  coalition_prolife      = COALESCE(NULLIF(coalition_prolife, ''),
    custom_fields->'datatrust_2026'->>'coalition_prolife'),
  coalition_prochoice    = COALESCE(NULLIF(coalition_prochoice, ''),
    custom_fields->'datatrust_2026'->>'coalition_prochoice')
WHERE custom_fields->'datatrust_2026' IS NOT NULL
  AND jsonb_typeof(custom_fields->'datatrust_2026') = 'object'
  AND custom_fields->'datatrust_2026' != '{}'::jsonb;

-- ============================================================================
-- STEP 4: (OPTIONAL) STRIP datatrust_2026 from custom_fields after promotion
-- Uncomment only after verifying all data was correctly promoted.
-- ============================================================================

-- UPDATE public.contacts
-- SET custom_fields = custom_fields - 'datatrust_2026'
-- WHERE custom_fields ? 'datatrust_2026';

-- ============================================================================
-- STEP 5: ADD INDEXES for common query patterns
-- ============================================================================
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_ethnicity
  ON public.contacts (ethnicity) WHERE ethnicity IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_religion
  ON public.contacts (religion) WHERE religion IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_education
  ON public.contacts (education_level) WHERE education_level IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_household_dt
  ON public.contacts (household_id_datatrust) WHERE household_id_datatrust IS NOT NULL;

-- ============================================================================
-- VERIFICATION QUERIES (run after migration to confirm correctness)
-- ============================================================================

-- Check new column fill rates:
-- SELECT
--   COUNT(*) FILTER (WHERE ethnicity IS NOT NULL) AS ethnicity_filled,
--   COUNT(*) FILTER (WHERE religion IS NOT NULL) AS religion_filled,
--   COUNT(*) FILTER (WHERE education_level IS NOT NULL) AS education_filled,
--   COUNT(*) FILTER (WHERE household_party IS NOT NULL) AS household_party_filled,
--   COUNT(*) FILTER (WHERE dt_enriched_at IS NOT NULL) AS enriched_at_filled,
--   COUNT(*) FILTER (WHERE republican_score IS NOT NULL) AS rep_score_filled,
--   COUNT(*) FILTER (WHERE turnout_score IS NOT NULL) AS turnout_filled
-- FROM public.contacts;

-- Confirm no data loss — JSON count should equal column count:
-- SELECT
--   (SELECT COUNT(*) FROM public.contacts
--    WHERE custom_fields->'datatrust_2026'->>'ethnicity' IS NOT NULL) AS json_ethnicity,
--   (SELECT COUNT(*) FROM public.contacts WHERE ethnicity IS NOT NULL) AS col_ethnicity;