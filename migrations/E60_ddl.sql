-- ============================================================================
-- E60 — POLL & SURVEY INTELLIGENCE
-- Full DDL for Supabase PostgreSQL
-- STATUS: BLOCKED — Do NOT execute until Golden Record Stages 0-5 complete
-- DEPENDENCIES: user_roles table, golden_record_id from E01
-- ============================================================================

-- ============================================================
-- LAYER 1: CORE REFERENCE TABLES
-- ============================================================

CREATE TABLE poll_sources (
  source_key        TEXT PRIMARY KEY,
  institution_name  TEXT NOT NULL,
  director          TEXT,
  methodology       TEXT,
  geographic_scope  TEXT NOT NULL DEFAULT 'NC_STATE',
  sample_size_min   INT,
  sample_size_max   INT,
  moe_typical       NUMERIC(4,2),
  active_since      DATE,
  partisan_lean     TEXT,
  accuracy_rating   TEXT,
  archive_url       TEXT,
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE nc_counties (
  county_fips       CHAR(5) PRIMARY KEY,
  county_name       TEXT NOT NULL,
  onsp_tier         TEXT NOT NULL,
  omb_msa_code      TEXT,
  omb_msa_name      TEXT,
  total_registered  INT,
  reg_dem_pct       NUMERIC(5,2),
  reg_rep_pct       NUMERIC(5,2),
  reg_unaffiliated_pct NUMERIC(5,2),
  trump_2024_pct    NUMERIC(5,2),
  trump_2020_pct    NUMERIC(5,2),
  trump_2016_pct    NUMERIC(5,2),
  presidential_swing NUMERIC(5,2),
  median_household_income INT,
  rural_urban_continuum_code INT,
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE voter_archetypes (
  archetype_key     TEXT PRIMARY KEY,
  display_name      TEXT NOT NULL,
  description       TEXT,
  primary_triggers  TEXT[],
  secondary_triggers TEXT[],
  suppression_triggers TEXT[],
  dominant_tiers    TEXT[],
  notes             TEXT
);

-- ============================================================
-- LAYER 1: POLL & SURVEY TABLES
-- ============================================================

CREATE TABLE polls (
  poll_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_key        TEXT NOT NULL REFERENCES poll_sources(source_key),
  poll_date_start   DATE NOT NULL,
  poll_date_end     DATE,
  survey_number     TEXT,
  title             TEXT,
  sample_size       INT,
  moe               NUMERIC(4,2),
  methodology       TEXT,
  population        TEXT,
  geographic_scope  TEXT DEFAULT 'NC_STATE',
  press_release_url TEXT,
  crosstabs_url     TEXT,
  memo_url          TEXT,
  top_line_findings TEXT,
  archetype_relevance TEXT[],
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE poll_questions (
  question_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id           UUID NOT NULL REFERENCES polls(poll_id) ON DELETE CASCADE,
  question_number   INT,
  question_text     TEXT NOT NULL,
  question_category TEXT,
  issue_key         TEXT,
  is_hot_button     BOOLEAN DEFAULT FALSE,
  archetype_targets TEXT[],
  notes             TEXT
);

CREATE TABLE poll_responses (
  response_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id       UUID NOT NULL REFERENCES poll_questions(question_id) ON DELETE CASCADE,
  response_text     TEXT NOT NULL,
  pct_overall       NUMERIC(5,2),
  pct_republican    NUMERIC(5,2),
  pct_democrat      NUMERIC(5,2),
  pct_independent   NUMERIC(5,2),
  pct_male          NUMERIC(5,2),
  pct_female        NUMERIC(5,2),
  pct_age_18_34     NUMERIC(5,2),
  pct_age_35_49     NUMERIC(5,2),
  pct_age_50_64     NUMERIC(5,2),
  pct_age_65_plus   NUMERIC(5,2),
  pct_white         NUMERIC(5,2),
  pct_black         NUMERIC(5,2),
  pct_hispanic      NUMERIC(5,2),
  pct_college       NUMERIC(5,2),
  pct_no_college    NUMERIC(5,2),
  pct_rural         NUMERIC(5,2),
  pct_suburban      NUMERIC(5,2),
  pct_urban         NUMERIC(5,2),
  pct_income_under50k  NUMERIC(5,2),
  pct_income_50_100k   NUMERIC(5,2),
  pct_income_100_200k  NUMERIC(5,2),
  pct_income_over200k  NUMERIC(5,2)
);

CREATE TABLE poll_crosstabs (
  crosstab_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id       UUID NOT NULL REFERENCES poll_questions(question_id) ON DELETE CASCADE,
  segment_type      TEXT NOT NULL,
  segment_value     TEXT NOT NULL,
  response_text     TEXT NOT NULL,
  pct               NUMERIC(5,2),
  n_weighted        NUMERIC(8,2),
  margin_of_error   NUMERIC(4,2),
  county_fips       CHAR(5) REFERENCES nc_counties(county_fips),
  onsp_tier         TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LAYER 1: COUNTY-LEVEL INTELLIGENCE TABLES
-- ============================================================

CREATE TABLE nc_county_issue_intensity (
  intensity_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  county_fips       CHAR(5) NOT NULL REFERENCES nc_counties(county_fips),
  issue_key         TEXT NOT NULL,
  archetype_key     TEXT REFERENCES voter_archetypes(archetype_key),
  onsp_tier         TEXT NOT NULL,
  intensity_score   NUMERIC(5,2) NOT NULL,
  direction         TEXT NOT NULL,
  confidence_level  TEXT NOT NULL,
  source_poll_ids   UUID[],
  sample_basis      TEXT,
  trending          TEXT DEFAULT 'STABLE',
  trend_change      NUMERIC(5,2),
  as_of_date        DATE NOT NULL,
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(county_fips, issue_key, archetype_key, as_of_date)
);

CREATE TABLE nc_county_race_tracking (
  tracking_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id           UUID REFERENCES polls(poll_id),
  race_name         TEXT NOT NULL,
  race_type         TEXT NOT NULL,
  district_id       TEXT,
  county_fips       CHAR(5) REFERENCES nc_counties(county_fips),
  candidate_d       TEXT,
  candidate_r       TEXT,
  pct_d             NUMERIC(5,2),
  pct_r             NUMERIC(5,2),
  pct_undecided     NUMERIC(5,2),
  lead_margin       NUMERIC(5,2),
  moe               NUMERIC(4,2),
  within_moe        BOOLEAN GENERATED ALWAYS AS (ABS(lead_margin) <= moe) STORED,
  poll_date         DATE NOT NULL,
  notes             TEXT
);

CREATE TABLE archetype_poll_calibration (
  calibration_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  archetype_key     TEXT NOT NULL REFERENCES voter_archetypes(archetype_key),
  issue_key         TEXT NOT NULL,
  poll_id           UUID REFERENCES polls(poll_id),
  activation_weight NUMERIC(5,3) NOT NULL,
  suppression_risk  NUMERIC(5,3) DEFAULT 0,
  crossover_appeal  NUMERIC(5,3) DEFAULT 0,
  geographic_modifier TEXT,
  source_finding    TEXT,
  as_of_date        DATE NOT NULL,
  calibrated_by     TEXT DEFAULT 'E20_BRAIN',
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE poll_fetch_schedule (
  schedule_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_key        TEXT NOT NULL REFERENCES poll_sources(source_key),
  fetch_url         TEXT NOT NULL,
  fetch_frequency   TEXT NOT NULL,
  last_fetched_at   TIMESTAMPTZ,
  last_poll_count   INT,
  next_fetch_due    TIMESTAMPTZ,
  auto_extract      BOOLEAN DEFAULT FALSE,
  extract_method    TEXT,
  is_active         BOOLEAN DEFAULT TRUE,
  notes             TEXT
);

CREATE TABLE poll_alerts (
  alert_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id           UUID REFERENCES polls(poll_id),
  alert_type        TEXT NOT NULL,
  alert_severity    TEXT NOT NULL,
  issue_key         TEXT,
  archetype_key     TEXT,
  county_fips       CHAR(5),
  finding_summary   TEXT NOT NULL,
  recommended_action TEXT,
  acknowledged      BOOLEAN DEFAULT FALSE,
  acknowledged_by   UUID,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LAYER 2: INDEXES
-- ============================================================

CREATE INDEX idx_county_issue_intensity_lookup ON nc_county_issue_intensity(county_fips, issue_key, archetype_key);
CREATE INDEX idx_county_issue_intensity_date ON nc_county_issue_intensity(as_of_date DESC);
CREATE INDEX idx_county_issue_intensity_tier ON nc_county_issue_intensity(onsp_tier, issue_key);

CREATE INDEX idx_polls_source ON polls(source_key, poll_date_start DESC);
CREATE INDEX idx_polls_relevance ON polls USING GIN(archetype_relevance);
CREATE INDEX idx_poll_questions_category ON poll_questions(question_category, is_hot_button);

CREATE INDEX idx_crosstabs_county ON poll_crosstabs(county_fips, segment_type, segment_value);
CREATE INDEX idx_crosstabs_archetype ON poll_crosstabs(segment_value) WHERE segment_type = 'ARCHETYPE';

CREATE INDEX idx_race_tracking_name ON nc_county_race_tracking(race_name, poll_date DESC);
CREATE INDEX idx_race_tracking_county ON nc_county_race_tracking(county_fips, race_type);
CREATE INDEX idx_race_tracking_within_moe ON nc_county_race_tracking(within_moe, race_name);

CREATE INDEX idx_alerts_unacked ON poll_alerts(acknowledged, alert_severity, created_at DESC)
  WHERE acknowledged = FALSE;

CREATE INDEX idx_calibration_archetype_issue ON archetype_poll_calibration(archetype_key, issue_key, as_of_date DESC);

-- ============================================================
-- LAYER 5: TRIGGERS & FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION fn_recalculate_county_intensity()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify(
    'poll_ingested',
    json_build_object(
      'poll_id', NEW.question_id::text,
      'action', TG_OP
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_poll_response_ingested
  AFTER INSERT OR UPDATE ON poll_responses
  FOR EACH ROW EXECUTE FUNCTION fn_recalculate_county_intensity();

CREATE OR REPLACE FUNCTION fn_detect_swing_alert()
RETURNS TRIGGER AS $$
DECLARE
  v_prior NUMERIC;
BEGIN
  SELECT intensity_score INTO v_prior
  FROM nc_county_issue_intensity
  WHERE county_fips = NEW.county_fips
    AND issue_key = NEW.issue_key
    AND archetype_key = NEW.archetype_key
    AND as_of_date < NEW.as_of_date
  ORDER BY as_of_date DESC LIMIT 1;

  IF v_prior IS NOT NULL AND ABS(NEW.intensity_score - v_prior) >= 10 THEN
    INSERT INTO poll_alerts(alert_type, alert_severity, issue_key, archetype_key,
      county_fips, finding_summary)
    VALUES ('SWING_DETECTED',
      CASE WHEN ABS(NEW.intensity_score - v_prior) >= 20 THEN 'CRITICAL' ELSE 'HIGH' END,
      NEW.issue_key, NEW.archetype_key, NEW.county_fips,
      format('%s pts swing on %s in %s (%s)',
        ROUND(NEW.intensity_score - v_prior, 1),
        NEW.issue_key, NEW.county_fips, NEW.archetype_key));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_intensity_swing_alert
  AFTER INSERT ON nc_county_issue_intensity
  FOR EACH ROW EXECUTE FUNCTION fn_detect_swing_alert();

-- ============================================================
-- END E60 DDL
-- DO NOT EXECUTE UNTIL GOLDEN RECORD STAGES 0-5 COMPLETE
-- ============================================================
