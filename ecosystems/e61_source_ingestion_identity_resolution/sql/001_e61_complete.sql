-- =============================================================================
-- E61 — Source Ingestion & Identity Resolution Engine
-- Layers 1 (DDL), 2 (Indexes), 3 (RLS), 5 (Triggers)
-- =============================================================================
-- Status: HELD ARTIFACT. Do NOT execute until:
--   1. Donor identity pipeline complete (Path B' + C₂ on committee table landed)
--   2. user_roles table exists
--   3. organization_id reconciled on candidate_profiles
--   4. candidate_id UUID-vs-VARCHAR type mismatch resolved
--   5. Ed types AUTHORIZE
-- =============================================================================
-- Per skill rule: "Do NOT create ecosystem database tables until the donor
-- identity pipeline is complete." This file is review-and-refine artifact only.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- LAYER 1 — DDL
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS e61;
COMMENT ON SCHEMA e61 IS 'Source Ingestion & Identity Resolution Engine — every CSV/upload flows through here before touching core.* schemas';

-- Sources Ed accepts (NCBOE batch / candidate uploads / donor uploads / FEC / Acxiom / etc.)
CREATE TABLE IF NOT EXISTS e61.source_registry (
    source_id           TEXT PRIMARY KEY,
    source_kind         TEXT NOT NULL CHECK (source_kind IN ('batch','portal_candidate','portal_donor','api_push')),
    schema_version      INT  NOT NULL DEFAULT 1,
    expected_columns    JSONB NOT NULL,
    normalization_rules JSONB NOT NULL,
    canonical_dest      TEXT NOT NULL,
    auto_match_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          TEXT
);

-- Each ingestion event (one CSV/upload = one run)
CREATE TABLE IF NOT EXISTS e61.ingestion_run (
    run_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id           TEXT NOT NULL REFERENCES e61.source_registry(source_id),
    submitter_user_id   UUID,
    submitter_role      TEXT CHECK (submitter_role IN ('candidate','donor','admin','staff','automation')),
    file_name           TEXT NOT NULL,
    file_sha256         TEXT NOT NULL,
    file_size_bytes     BIGINT,
    row_count_input     BIGINT,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,
    status              TEXT NOT NULL DEFAULT 'queued'
                          CHECK (status IN ('queued','normalizing','clustering','matching','publishing','done','failed','quarantined')),
    error_msg           TEXT,
    metrics             JSONB
);

-- Every row from the input file, with full lineage
CREATE TABLE IF NOT EXISTS e61.ingested_row (
    ingested_row_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id              UUID NOT NULL REFERENCES e61.ingestion_run(run_id) ON DELETE CASCADE,
    source_row_index    BIGINT NOT NULL,
    raw_payload         JSONB NOT NULL,
    normalized_payload  JSONB,
    cluster_id_v2       BIGINT,
    rnc_regid_v2        TEXT,
    state_voter_id_v2   TEXT,
    match_tier          TEXT,
    match_method        TEXT,
    match_confidence    NUMERIC(4,3),
    canonical_dest_id   TEXT,
    quarantine_reason   TEXT,
    UNIQUE (run_id, source_row_index)
);

-- Quarantine queue
CREATE TABLE IF NOT EXISTS e61.quarantine (
    quarantine_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ingested_row_id     UUID NOT NULL REFERENCES e61.ingested_row(ingested_row_id) ON DELETE CASCADE,
    reason_code         TEXT NOT NULL,
    reason_detail       TEXT,
    suggested_fix       JSONB,
    resolution_status   TEXT NOT NULL DEFAULT 'open'
                          CHECK (resolution_status IN ('open','manual_fixed','dropped','auto_fixed')),
    resolved_by_user_id UUID,
    resolved_at         TIMESTAMPTZ
);

-- Lineage: trace any canonical record back to every source row that contributed
CREATE TABLE IF NOT EXISTS e61.lineage_link (
    lineage_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_table     TEXT NOT NULL,
    canonical_id        TEXT NOT NULL,
    ingested_row_id     UUID NOT NULL REFERENCES e61.ingested_row(ingested_row_id) ON DELETE CASCADE,
    contribution_kind   TEXT CHECK (contribution_kind IN ('created','updated_field','merged_into','no_op')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Reference lookups
CREATE TABLE IF NOT EXISTS e61.lookup_zip_county (
    zip5         CHAR(5) PRIMARY KEY,
    county_name  TEXT NOT NULL,
    state        CHAR(2) NOT NULL DEFAULT 'NC'
);

CREATE TABLE IF NOT EXISTS e61.lookup_county_prefix (
    sbe_prefix          CHAR(2) PRIMARY KEY,
    county_name         TEXT NOT NULL,
    state_county_code   TEXT
);

CREATE TABLE IF NOT EXISTS e61.lookup_nickname_pair (
    legal_first   TEXT NOT NULL,
    common_first  TEXT NOT NULL,
    confidence    NUMERIC(4,3) DEFAULT 1.000,
    source        TEXT,
    PRIMARY KEY (legal_first, common_first)
);

CREATE TABLE IF NOT EXISTS e61.lookup_nonperson_token (
    token  TEXT PRIMARY KEY,
    kind   TEXT CHECK (kind IN ('corporation','partnership','trust','foundation','government','committee','association','other'))
);

-- ---------------------------------------------------------------------------
-- LAYER 2 — Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS ix_e61_run_source_started ON e61.ingestion_run(source_id, started_at DESC);
CREATE INDEX IF NOT EXISTS ix_e61_run_status         ON e61.ingestion_run(status) WHERE status NOT IN ('done','failed');
CREATE UNIQUE INDEX IF NOT EXISTS ux_e61_run_sha     ON e61.ingestion_run(file_sha256, source_id);

CREATE INDEX IF NOT EXISTS ix_e61_irow_run        ON e61.ingested_row(run_id);
CREATE INDEX IF NOT EXISTS ix_e61_irow_cluster    ON e61.ingested_row(cluster_id_v2) WHERE cluster_id_v2 IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_e61_irow_rnc        ON e61.ingested_row(rnc_regid_v2)  WHERE rnc_regid_v2  IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_e61_irow_quarantine ON e61.ingested_row(quarantine_reason) WHERE quarantine_reason IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_e61_q_status   ON e61.quarantine(resolution_status, reason_code) WHERE resolution_status='open';
CREATE INDEX IF NOT EXISTS ix_e61_lin_canonical ON e61.lineage_link(canonical_table, canonical_id);
CREATE INDEX IF NOT EXISTS ix_e61_lin_irow      ON e61.lineage_link(ingested_row_id);
CREATE INDEX IF NOT EXISTS ix_e61_nick_common   ON e61.lookup_nickname_pair(common_first);

-- ---------------------------------------------------------------------------
-- LAYER 3 — Row-Level Security
-- ---------------------------------------------------------------------------
-- DEPENDENCY: requires public.user_roles table + auth.user_has_role(text) function.
-- Skill flagged this as a missing dependency. Below is the intended policy set.
-- Until the dependency exists, RLS will be enabled but only the service_role policy applies.
-- ---------------------------------------------------------------------------

ALTER TABLE e61.ingestion_run     ENABLE ROW LEVEL SECURITY;
ALTER TABLE e61.ingested_row      ENABLE ROW LEVEL SECURITY;
ALTER TABLE e61.quarantine        ENABLE ROW LEVEL SECURITY;
ALTER TABLE e61.lineage_link      ENABLE ROW LEVEL SECURITY;

-- Service role: full access (for engine workers)
CREATE POLICY e61_svc_full ON e61.ingestion_run FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY e61_svc_full ON e61.ingested_row  FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY e61_svc_full ON e61.quarantine    FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY e61_svc_full ON e61.lineage_link  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Admins: full read/write (DEPENDS ON auth.user_has_role)
-- CREATE POLICY e61_admin_all ON e61.ingestion_run FOR ALL TO authenticated USING (auth.user_has_role('admin'));
-- CREATE POLICY e61_admin_all ON e61.ingested_row  FOR ALL TO authenticated USING (auth.user_has_role('admin'));
-- CREATE POLICY e61_admin_all ON e61.quarantine    FOR ALL TO authenticated USING (auth.user_has_role('admin'));
-- CREATE POLICY e61_admin_all ON e61.lineage_link  FOR ALL TO authenticated USING (auth.user_has_role('admin'));

-- Candidates: see only their own runs
-- CREATE POLICY e61_candidate_own_runs ON e61.ingestion_run FOR SELECT TO authenticated
--   USING (auth.user_has_role('candidate') AND submitter_user_id = auth.uid());

-- Donors: see only their own runs
-- CREATE POLICY e61_donor_own_runs ON e61.ingestion_run FOR SELECT TO authenticated
--   USING (auth.user_has_role('donor') AND submitter_user_id = auth.uid());

-- Staff: read all runs, no delete
-- CREATE POLICY e61_staff_read ON e61.ingestion_run FOR SELECT TO authenticated USING (auth.user_has_role('staff'));

-- ---------------------------------------------------------------------------
-- LAYER 5 — Triggers
-- ---------------------------------------------------------------------------

-- When ingestion_run.status flips to 'done', notify E20 Brain
CREATE OR REPLACE FUNCTION e61.notify_brain_run_done() RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'done' AND (OLD.status IS NULL OR OLD.status <> 'done') THEN
    PERFORM pg_notify(
      'e20_brain',
      json_build_object(
        'event','e61.run.completed',
        'run_id', NEW.run_id,
        'source_id', NEW.source_id,
        'metrics', NEW.metrics,
        'completed_at', NEW.completed_at
      )::text
    );
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_e61_run_done ON e61.ingestion_run;
CREATE TRIGGER trg_e61_run_done
  AFTER UPDATE ON e61.ingestion_run
  FOR EACH ROW EXECUTE FUNCTION e61.notify_brain_run_done();

-- Pub/sub for E27 Realtime Dashboard on quarantine changes
CREATE OR REPLACE FUNCTION e61.notify_e27_quarantine_change() RETURNS trigger AS $$
BEGIN
  PERFORM pg_notify(
    'e27_realtime',
    json_build_object(
      'event','e61.quarantine.changed',
      'quarantine_id', COALESCE(NEW.quarantine_id, OLD.quarantine_id),
      'resolution_status', COALESCE(NEW.resolution_status, OLD.resolution_status),
      'reason_code', COALESCE(NEW.reason_code, OLD.reason_code)
    )::text
  );
  RETURN COALESCE(NEW, OLD);
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_e61_q_change ON e61.quarantine;
CREATE TRIGGER trg_e61_q_change
  AFTER INSERT OR UPDATE OR DELETE ON e61.quarantine
  FOR EACH ROW EXECUTE FUNCTION e61.notify_e27_quarantine_change();

-- =============================================================================
-- END — held until activation
-- =============================================================================
