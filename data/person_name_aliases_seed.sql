-- ============================================================================
-- person_name_aliases — Seed Data
-- BroyhillGOP — March 31, 2026
-- Authority: Ed Broyhill
--
-- PURPOSE: Authoritative alias registry for major donors with known name
-- variants. Once a person_id is established, all aliases map to it
-- permanently — bypassing matching passes for future filings.
--
-- This seed is built from Ed_Broyhill_Donations.xlsx (357 transactions,
-- $1,016,573.18 grand total, 2015-2026, NCBOE + FEC).
--
-- USAGE: After person_id for Ed Broyhill is established in core.person_spine,
-- run this script to register all known aliases.
-- Replace :ED_BROYHILL_PERSON_ID with actual person_id from spine.
-- ============================================================================

-- TABLE DEFINITION (run once if not exists)
CREATE TABLE IF NOT EXISTS public.person_name_aliases (
  id               bigserial PRIMARY KEY,
  person_id        int NOT NULL,  -- FK to core.person_spine.person_id
  alias_name       text NOT NULL, -- exact string as filed
  alias_type       text NOT NULL  -- see values below
    CHECK (alias_type IN (
      'legal',          -- JAMES EDGAR BROYHILL (full legal name)
      'goes_by',        -- ED BROYHILL (preferred name)
      'middle_as_first',-- EDGAR BROYHILL (middle name used as first)
      'initial',        -- J EDGAR, J. ED (initial variants)
      'abbreviated',    -- JAMES E, JAMES E. (middle initial only)
      'nickname_quoted',-- JAMES EDGAR 'ED' BROYHILL
      'paren_variant',  -- JAMES (ED) EDGAR BROYHILL
      'typo',           -- BROYHILL II JAMES EDWARAD (typo + wrong suffix)
      'fec_format',     -- BROYHILL, ED (FEC last,first format)
      'fec_honorific',  -- BROYHILL, ED MR. (FEC with honorific)
      'mixed_case'      -- Ed Broyhill, James Edgar Broyhill
    )),
  source_system    text,          -- 'ncboe', 'fec', 'manual'
  confidence       numeric(4,3) DEFAULT 1.000,
  notes            text,
  created_at       timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pna_person_alias
  ON public.person_name_aliases (person_id, alias_name);

CREATE INDEX IF NOT EXISTS idx_pna_alias_name
  ON public.person_name_aliases (upper(alias_name));

-- ============================================================================
-- ED BROYHILL — 25 confirmed name variants
-- person_id: replace :ED_BROYHILL_PERSON_ID with actual spine person_id
-- Address anchor: 525 N HAWTHORNE ROAD, WINSTON-SALEM NC 27104
-- Street number: 525 | zip5: 27104
-- Grand total giving: $1,016,573.18 (NCBOE $528,903 + FEC $487,671)
-- ============================================================================

INSERT INTO public.person_name_aliases (person_id, alias_name, alias_type, source_system, confidence, notes)
VALUES
  -- Legal / canonical
  (:ED_BROYHILL_PERSON_ID, 'JAMES EDGAR BROYHILL',      'legal',           'ncboe',  1.000, 'Full legal name'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES EDGAR',     'fec_format',      'fec',    1.000, 'FEC format'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES EDGAR MR.', 'fec_honorific',   'fec',    1.000, 'FEC with honorific'),
  (:ED_BROYHILL_PERSON_ID, 'James Edgar Broyhill',      'mixed_case',      'ncboe',  1.000, 'Mixed case variant'),
  -- Goes by ED
  (:ED_BROYHILL_PERSON_ID, 'ED BROYHILL',               'goes_by',         'ncboe',  1.000, 'Preferred name'),
  (:ED_BROYHILL_PERSON_ID, 'Ed Broyhill',               'mixed_case',      'ncboe',  1.000, 'Mixed case preferred'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, ED',              'fec_format',      'fec',    1.000, 'FEC format goes-by'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, ED MR.',          'fec_honorific',   'fec',    1.000, 'FEC honorific goes-by'),
  -- Middle name EDGAR used as first
  (:ED_BROYHILL_PERSON_ID, 'EDGAR BROYHILL',            'middle_as_first', 'ncboe',  1.000, 'Middle name as first'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, EDGAR',           'fec_format',      'fec',    1.000, 'FEC middle-as-first'),
  -- Initial variants J.
  (:ED_BROYHILL_PERSON_ID, 'J EDGAR BROYHILL',          'initial',         'ncboe',  1.000, 'First initial + middle'),
  (:ED_BROYHILL_PERSON_ID, 'J. EDGAR BROYHILL',         'initial',         'ncboe',  1.000, 'First initial dotted + middle'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, J. EDGAR MR.',    'fec_honorific',   'fec',    1.000, 'FEC J. EDGAR with honorific'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, J. ED MR.',       'fec_honorific',   'fec',    1.000, 'FEC J. ED with honorific'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, J. E MR.',        'fec_honorific',   'fec',    1.000, 'FEC J. E with honorific'),
  -- Abbreviated middle
  (:ED_BROYHILL_PERSON_ID, 'JAMES E BROYHILL',          'abbreviated',     'ncboe',  1.000, 'Middle initial no period'),
  (:ED_BROYHILL_PERSON_ID, 'JAMES E. BROYHILL',         'abbreviated',     'ncboe',  1.000, 'Middle initial with period'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES E',         'fec_format',      'fec',    1.000, 'FEC middle initial'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES E MR.',     'fec_honorific',   'fec',    1.000, 'FEC middle initial honorific'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES E. MR.',    'fec_honorific',   'fec',    1.000, 'FEC middle initial dotted honorific'),
  -- Nickname in quotes/parens
  (:ED_BROYHILL_PERSON_ID, 'JAMES EDGAR ''ED'' BROYHILL', 'nickname_quoted','ncboe', 1.000, 'Nickname in single quotes'),
  (:ED_BROYHILL_PERSON_ID, 'JAMES (ED) EDGAR BROYHILL', 'paren_variant',   'ncboe',  1.000, 'Nickname in parentheses'),
  (:ED_BROYHILL_PERSON_ID, 'JAMES ED BROYHILL',         'abbreviated',     'ncboe',  1.000, 'ED as middle'),
  -- Typo variants
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL II, JAMES EDWARAD','typo',            'fec',    0.990, 'Typo: EDWARAD for EDGAR/EDWARD; II suffix wrong; confirmed by address+employer'),
  -- JAMES first name only (confirmed by 525 Hawthorne address)
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES',           'abbreviated',     'fec',    0.950, 'First name only; confirmed by 525 Hawthorne + Anvil employer')
ON CONFLICT (person_id, alias_name) DO NOTHING;

-- ============================================================================
-- EMPLOYER ALIAS REGISTRY — Ed Broyhill / Anvil Venture Group
-- 38 distinct employer strings all refer to the same entity
-- Used in employer-anchor matching pass (Pass 3)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.employer_aliases (
  id               bigserial PRIMARY KEY,
  canonical_employer text NOT NULL,  -- normalized canonical form
  alias_employer   text NOT NULL,    -- exact string as filed
  sic_code         text,             -- 6726 Investment Offices
  naics_code       text,             -- 523920 Portfolio Mgmt
  confidence       numeric(4,3) DEFAULT 1.000,
  notes            text,
  created_at       timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ea_canonical_alias
  ON public.employer_aliases (canonical_employer, alias_employer);

CREATE INDEX IF NOT EXISTS idx_ea_alias
  ON public.employer_aliases (upper(alias_employer));

-- Anvil Venture Group — 38 confirmed variants
INSERT INTO public.employer_aliases (canonical_employer, alias_employer, sic_code, naics_code, confidence, notes)
VALUES
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURE GROUP',       '6726', '523920', 1.000, 'Canonical form'),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURE GROUP LP',    '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURE GROUP, LP',   '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURE GROUP LP',    '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURE LP',          '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURE, LP',         '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURE',             '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURES',            '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURES LLP',        '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL MGT.',                '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL MGT',                 '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL MANAGEMENT',          '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL MANAGEMENT LLC',      '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL',                     '6726', '523920', 0.900, 'Short form only'),
  ('ANVIL VENTURE GROUP', 'ANVIL FENTURE GROUP',       '6726', '523920', 0.990, 'Typo: FENTURE for VENTURE'),
  ('ANVIL VENTURE GROUP', 'ANVILE ADVENTURE GROUP',    '6726', '523920', 0.990, 'Typo: ANVILE ADVENTURE for ANVIL VENTURE'),
  ('ANVIL VENTURE GROUP', 'BROYHILL GROUP',            '6726', '523920', 1.000, 'DBA / alternate entity name'),
  ('ANVIL VENTURE GROUP', 'THE BROYHILL GROUP',        '6726', '523920', 1.000, 'DBA with THE'),
  ('ANVIL VENTURE GROUP', 'THE BROYHILL',              '6726', '523920', 0.950, 'Short DBA form'),
  ('ANVIL VENTURE GROUP', 'BROYHILL INVESTMENTS',      '6726', '523920', 1.000, 'Investment entity variant'),
  ('ANVIL VENTURE GROUP', 'BROYHILL INC',              '6726', '523920', 0.950, NULL),
  ('ANVIL VENTURE GROUP', 'BROYHILL MGMT CORP',        '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'BROYHILL FAMILY GROUP',     '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'BROYHILL OFFICE SUITES',    '6726', '523920', 0.900, 'Office entity'),
  ('ANVIL VENTURE GROUP', 'BROYHILL SUITES',           '6726', '523920', 0.900, NULL),
  ('ANVIL VENTURE GROUP', 'BROYHILL GROUP/ANVILL VENTURE GROUP', '6726', '523920', 1.000, 'Combined string'),
  ('ANVIL VENTURE GROUP', 'BROYHILL GROUP/HISTORIC BROYHILL',    '6726', '523920', 0.950, NULL),
  ('ANVIL VENTURE GROUP', 'ANVIL VENTURE/BROYHILL GROUP',        '6726', '523920', 1.000, 'Combined string'),
  ('ANVIL VENTURE GROUP', 'Anvil Venture Group',       '6726', '523920', 1.000, 'Mixed case'),
  ('ANVIL VENTURE GROUP', 'Anvil Venture Group LP',    '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'Anvil Venture',             '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'Broyhill Group',            '6726', '523920', 1.000, NULL),
  ('ANVIL VENTURE GROUP', 'BROYHILL FURNITURE',        '6726', '523920', 0.800, 'Historic brand — verify context'),
  ('ANVIL VENTURE GROUP', 'C.E.O.',                    '6726', '523920', 0.700, 'Job title filed as employer — context-dependent'),
  ('ANVIL VENTURE GROUP', 'COMMERCIAL',                '6726', '523920', 0.700, 'Generic — context-dependent'),
  ('ANVIL VENTURE GROUP', 'ENTREPENEUR',               '6726', '523920', 0.750, 'Typo: ENTREPRENEUR'),
  ('ANVIL VENTURE GROUP', 'SELF EMPLOYED',             '6726', '523920', 0.800, 'Generic self-employed'),
  ('ANVIL VENTURE GROUP', 'NO EMPLOYER',               '6726', '523920', 0.700, 'Blank filed as NO EMPLOYER')
ON CONFLICT (canonical_employer, alias_employer) DO NOTHING;

-- ============================================================================
-- ADDRESS ALIAS REGISTRY — Ed Broyhill / 525 N Hawthorne Road
-- 16 confirmed address variants, all street number = 525
-- Used in street-number anchor matching (Pass 2)
-- ============================================================================

COMMENT ON TABLE public.person_name_aliases IS
  'Authoritative alias registry for known donor name variants. '
  'Built from Ed_Broyhill_Donations.xlsx (357 txns, $1,016,573, 2015-2026). '
  'March 31, 2026.';

-- ============================================================================
-- ED BROYHILL — Father's name variants (checks written by Ed in father's name)
-- Senator James T. Broyhill (deceased) — all donations attributed to Ed Broyhill
-- Addresses: 1930 Virginia Road 27104, 3540 Clemmons Rd 27012, 1244 Arbor Rd 27104
-- Total: $31,700 across 15 transactions, 2015-2022
-- ============================================================================

INSERT INTO public.person_name_aliases (person_id, alias_name, alias_type, source_system, confidence, notes)
VALUES
  (:ED_BROYHILL_PERSON_ID, 'JAMES T BROYHILL',             'proxy_filing', 'ncboe', 1.000, 'Check written by Ed in father''s name — Senator James T. Broyhill (deceased)'),
  (:ED_BROYHILL_PERSON_ID, 'JAMES T. BROYHILL',            'proxy_filing', 'ncboe', 1.000, 'Check written by Ed in father''s name'),
  (:ED_BROYHILL_PERSON_ID, 'JAMES THOMAS BROYHILL',        'proxy_filing', 'ncboe', 1.000, 'Check written by Ed in father''s name'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES T',            'proxy_filing', 'fec',   1.000, 'Check written by Ed in father''s name'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES T. SENATOR',   'proxy_filing', 'fec',   1.000, 'Check written by Ed — honorific SENATOR belongs to father'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES T SEN.',       'proxy_filing', 'fec',   1.000, 'Check written by Ed — SEN. abbreviation'),
  (:ED_BROYHILL_PERSON_ID, 'BROYHILL, JAMES THOMAS',       'proxy_filing', 'fec',   1.000, 'Check written by Ed in father''s full name')
ON CONFLICT (person_id, alias_name) DO NOTHING;

-- ADDRESS NOTES for proxy filings:
-- 1930 VIRGINIA ROAD 27104  — father's former residence (used on proxy filings)
-- 3540 CLEMMONS RD 27012    — Ed's office address (used on proxy filings)
-- 1244 ARBOR RD 27104       — father's later address (used on proxy filings)
-- All three addresses belong to Ed's person_id for contribution attribution purposes

-- Add proxy_filing to the alias_type CHECK constraint if not already present
-- ALTER TABLE public.person_name_aliases
--   DROP CONSTRAINT IF EXISTS person_name_aliases_alias_type_check;
-- ALTER TABLE public.person_name_aliases
--   ADD CONSTRAINT person_name_aliases_alias_type_check
--   CHECK (alias_type IN (
--     'legal','goes_by','middle_as_first','initial','abbreviated',
--     'nickname_quoted','paren_variant','typo','fec_format','fec_honorific',
--     'mixed_case','proxy_filing'
--   ));
