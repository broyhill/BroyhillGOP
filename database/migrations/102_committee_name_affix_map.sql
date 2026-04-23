-- 102_committee_name_affix_map.sql
-- Purpose: Affix abbreviated committee names (e.g., REC) to canonical names.
-- Notes:
--   - Non-destructive migration (CREATE IF NOT EXISTS + UPSERT seeds).
--   - Designed for NCBOE/committee naming cleanup and deterministic matching.

CREATE SCHEMA IF NOT EXISTS committee;

-- ============================================================
-- 1) Token-level abbreviation map (table-driven)
-- ============================================================
CREATE TABLE IF NOT EXISTS committee.committee_name_token_map (
  token            text PRIMARY KEY,
  expansion        text NOT NULL,
  priority         integer NOT NULL DEFAULT 100,
  is_active        boolean NOT NULL DEFAULT true,
  notes            text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT committee_name_token_map_token_ck
    CHECK (token = upper(token) AND token ~ '^[A-Z0-9]+$')
);

CREATE INDEX IF NOT EXISTS committee_name_token_map_active_priority_idx
  ON committee.committee_name_token_map (is_active, priority, token);

INSERT INTO committee.committee_name_token_map (token, expansion, priority, is_active, notes)
VALUES
  ('REC', 'REPUBLICAN EXECUTIVE COMMITTEE', 10, true, 'Primary NC abbreviation observed in donor committee names')
ON CONFLICT (token) DO UPDATE
SET expansion  = EXCLUDED.expansion,
    priority   = EXCLUDED.priority,
    is_active  = EXCLUDED.is_active,
    notes      = EXCLUDED.notes,
    updated_at = now();

-- ============================================================
-- 2) Exact alias map for known committee naming variants
-- ============================================================
CREATE TABLE IF NOT EXISTS committee.committee_name_alias_map (
  alias_name_norm          text PRIMARY KEY,
  canonical_name           text NOT NULL,
  canonical_sboe_id        text,
  canonical_committee_type text,
  source                   text NOT NULL DEFAULT 'manual_seed',
  is_active                boolean NOT NULL DEFAULT true,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS committee_name_alias_map_active_idx
  ON committee.committee_name_alias_map (is_active, alias_name_norm);

INSERT INTO committee.committee_name_alias_map (
  alias_name_norm,
  canonical_name,
  canonical_sboe_id,
  canonical_committee_type,
  source,
  is_active,
  notes
)
VALUES
  ('WAKE REC', 'WAKE REPUBLICAN EXECUTIVE COMMITTEE', NULL, NULL, 'manual_seed', true, 'Observed abbreviation pair'),
  ('WAKE COUNTY REC', 'WAKE COUNTY REPUBLICAN EXECUTIVE COMMITTEE', NULL, NULL, 'manual_seed', true, 'Observed abbreviation pair'),
  ('NC REC', 'NC REPUBLICAN EXECUTIVE COMMITTEE', NULL, NULL, 'manual_seed', true, 'Observed abbreviation pair'),
  ('NC REC-STATE', 'NORTH CAROLINA REPUBLICAN EXECUTIVE COMMITTEE', NULL, NULL, 'manual_seed', true, 'Observed abbreviation pair'),
  ('NC REC - STATE', 'NORTH CAROLINA REPUBLICAN EXECUTIVE COMMITTEE', NULL, NULL, 'manual_seed', true, 'Observed abbreviation pair')
ON CONFLICT (alias_name_norm) DO UPDATE
SET canonical_name           = EXCLUDED.canonical_name,
    canonical_sboe_id        = EXCLUDED.canonical_sboe_id,
    canonical_committee_type = EXCLUDED.canonical_committee_type,
    source                   = EXCLUDED.source,
    is_active                = EXCLUDED.is_active,
    notes                    = EXCLUDED.notes,
    updated_at               = now();

-- ============================================================
-- 3) Normalizer and affix function
-- ============================================================
CREATE OR REPLACE FUNCTION committee.normalize_committee_name(raw_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(upper(trim(coalesce(raw_name, ''))), '\s+', ' ', 'g');
$$;

CREATE OR REPLACE FUNCTION committee.affix_committee_name(raw_name text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  out_name text := committee.normalize_committee_name(raw_name);
  alias_hit text;
  token_row record;
BEGIN
  IF out_name = '' THEN
    RETURN out_name;
  END IF;

  SELECT a.canonical_name
    INTO alias_hit
  FROM committee.committee_name_alias_map a
  WHERE a.is_active = true
    AND a.alias_name_norm = out_name
  LIMIT 1;

  IF alias_hit IS NOT NULL THEN
    RETURN alias_hit;
  END IF;

  FOR token_row IN
    SELECT token, expansion
    FROM committee.committee_name_token_map
    WHERE is_active = true
    ORDER BY priority ASC, token ASC
  LOOP
    out_name := regexp_replace(
      out_name,
      '(^|[^A-Z0-9])' || token_row.token || '([^A-Z0-9]|$)',
      E'\\1' || token_row.expansion || E'\\2',
      'g'
    );
  END LOOP;

  RETURN regexp_replace(out_name, '\s+', ' ', 'g');
END;
$$;

-- ============================================================
-- 4) Affixed-name view over committee registry
-- ============================================================
CREATE OR REPLACE VIEW committee.v_registry_name_affixed AS
SELECT
  r.sboe_id,
  r.committee_name                                        AS raw_committee_name,
  committee.normalize_committee_name(r.committee_name)    AS normalized_committee_name,
  committee.affix_committee_name(r.committee_name)        AS affixed_committee_name,
  a.canonical_name                                        AS exact_alias_match_name,
  a.canonical_sboe_id                                     AS exact_alias_match_sboe_id,
  r.committee_type,
  r.fec_committee_id
FROM committee.registry r
LEFT JOIN committee.committee_name_alias_map a
  ON a.is_active = true
 AND a.alias_name_norm = committee.normalize_committee_name(r.committee_name);

-- Example usage:
-- SELECT sboe_id, raw_committee_name, affixed_committee_name
-- FROM committee.v_registry_name_affixed
-- WHERE raw_committee_name ILIKE '% REC %'
--    OR raw_committee_name ILIKE '% REC'
-- ORDER BY raw_committee_name;
