-- =============================================================================
-- BGOP ARCHITECTURE BRIEF — WAVE 1 (P1 CRITICAL) MIGRATION
-- =============================================================================
-- Date:       2026-04-13
-- Author:     Perplexity Engineering
-- Backup:     manual_20260413_193955.dump (Rule 14 satisfied)
-- Reference:  docs/BGOP_ARCHITECTURE_BRIEF.docx §3.1–§4, commit f0ad35b
-- Branch:     session-mar17-2026-clean
-- =============================================================================
-- CORRECTIONS FROM BRIEF:
--   1. FK references corrected: core.candidates(id) → core.candidates(candidate_id)
--      The brief's DDL uses (id) but the actual PK is candidate_id.
--   2. credentials_vault.secret_value DEFAULT '' added — brief has NOT NULL but
--      seed rows don't provide values (set via pgp_sym_encrypt later).
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- §3.1  public.bgop_config — Configuration Store
-- Replaces .env reads in relay.py and brain worker. Single source of truth.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.bgop_config (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  key          TEXT        NOT NULL,
  environment  TEXT        NOT NULL CHECK (environment IN ('local','staging','prod')),
  value        TEXT,
  is_secret    BOOLEAN     DEFAULT FALSE,
  is_locked    BOOLEAN     DEFAULT FALSE,
  ecosystem_id TEXT,                    -- NULL = global; else scoped to E01–E60
  description  TEXT,
  updated_at   TIMESTAMPTZ DEFAULT now(),
  updated_by   TEXT,
  UNIQUE (key, environment)
);

CREATE INDEX idx_bgop_config_env ON public.bgop_config(environment);
CREATE INDEX idx_bgop_config_eco ON public.bgop_config(ecosystem_id)
  WHERE ecosystem_id IS NOT NULL;

INSERT INTO public.bgop_config (key, environment, value, is_secret, description) VALUES
  ('REDIS_HOST',          'prod', 'localhost',                                    false, 'Redis pub/sub host'),
  ('REDIS_PORT',          'prod', '6379',                                         false, 'Redis port'),
  ('RELAY_PORT',          'prod', '8080',                                         false, 'relay.py FastAPI port'),
  ('BRAIN_WORKER_PORT',   'prod', '8081',                                         false, 'Brain worker health port'),
  ('HETZNER_PG_HOST',     'prod', '37.27.169.232',                                false, 'Hetzner primary PG host'),
  ('WINRED_HMAC_SECRET',  'prod', NULL,                                           true,  'WinRed webhook HMAC secret'),
  ('ANEDOT_HMAC_SECRET',  'prod', NULL,                                           true,  'Anedot webhook HMAC secret'),
  ('SUPABASE_URL',        'prod', 'https://isbgjpnbocdkeslofota.supabase.co',     false, 'Supabase — agent_messages only'),
  ('SUPABASE_SERVICE_KEY','prod', NULL,                                           true,  'Supabase service role key');

-- ─────────────────────────────────────────────────────────────────────────────
-- §3.2  pipeline.credentials_vault — Secret Store
-- Backs vault: prefix refs in pipeline.data_sources.connection_config JSONB.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE pipeline.credentials_vault (
  vault_key    TEXT        PRIMARY KEY,
  secret_value TEXT        NOT NULL DEFAULT '',  -- pgp_sym_encrypt(plaintext, master_key) — set later
  description  TEXT,
  rotated_at   TIMESTAMPTZ DEFAULT now(),
  expires_at   TIMESTAMPTZ,
  created_by   TEXT        DEFAULT 'system',
  CONSTRAINT vault_key_format CHECK (vault_key ~ '^[a-z0-9_]+$')
);

INSERT INTO pipeline.credentials_vault (vault_key, description) VALUES
  ('winred_hmac_secret_prod',    'WinRed webhook HMAC verification secret'),
  ('anedot_hmac_secret_prod',    'Anedot webhook HMAC verification secret'),
  ('sendgrid_api_key_prod',      'SendGrid transactional email API key'),
  ('perplexity_api_key_prod',    'Perplexity AI API key for agent queries'),
  ('acxiom_sftp_password_prod',  'Acxiom IBE SFTP delivery password');

-- ─────────────────────────────────────────────────────────────────────────────
-- §3.3  pipeline.campaign_codes — WinRed/Anedot Co-Admin Mapping
-- Maps candidate → processor campaign code. Brain worker uses this to route
-- inbound donation webhooks to the correct candidate silo.
-- FK CORRECTED: core.candidates(candidate_id) — brief had (id)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE pipeline.campaign_codes (
  id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  candidate_id    UUID        NOT NULL REFERENCES core.candidates(candidate_id),
  processor       TEXT        NOT NULL CHECK (processor IN ('winred','anedot')),
  campaign_code   TEXT        NOT NULL,
  is_active       BOOLEAN     DEFAULT TRUE,
  co_admin_since  DATE,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (candidate_id, processor)
);

CREATE INDEX idx_campaign_codes_code      ON pipeline.campaign_codes(campaign_code);
CREATE INDEX idx_campaign_codes_candidate ON pipeline.campaign_codes(candidate_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- §3.3  pipeline.processor_access — Co-Admin Access Audit Trail
-- Tracks when BGOP gained/lost co-admin status per processor account.
-- FK CORRECTED: core.candidates(candidate_id) — brief had (id)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE pipeline.processor_access (
  id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  candidate_id    UUID        NOT NULL REFERENCES core.candidates(candidate_id),
  processor       TEXT        NOT NULL CHECK (processor IN ('winred','anedot')),
  access_level    TEXT        NOT NULL CHECK (access_level IN ('co_admin','read_only','none')),
  granted_at      TIMESTAMPTZ DEFAULT now(),
  revoked_at      TIMESTAMPTZ,
  granted_by      TEXT,
  notes           TEXT
);

CREATE INDEX idx_processor_access_candidate ON pipeline.processor_access(candidate_id);
CREATE INDEX idx_processor_access_active    ON pipeline.processor_access(candidate_id)
  WHERE revoked_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  ALTER donor_intelligence.person_master
-- Add confidence_score (identity resolution 0.0–1.0) and acxiom_load_batch
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE donor_intelligence.person_master
  ADD COLUMN confidence_score  NUMERIC(4,3) DEFAULT 0.0,
  ADD COLUMN acxiom_load_batch TEXT;

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  ALTER donor_intelligence.contribution_map
-- Add FK to campaign_codes — links donation to co-admin campaign
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE donor_intelligence.contribution_map
  ADD COLUMN campaign_code_id UUID REFERENCES pipeline.campaign_codes(id);

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Partition: brain.event_queue_2026_08
-- Must exist before July 31 or all August events fail to INSERT.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE brain.event_queue_2026_08
  PARTITION OF brain.event_queue
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Partition: pipeline.inbound_data_queue_2026_08
-- Same deadline — both queues are monthly partitioned.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE pipeline.inbound_data_queue_2026_08
  PARTITION OF pipeline.inbound_data_queue
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

COMMIT;

-- =============================================================================
-- WAVE 1 DEPLOYMENT SUMMARY
-- =============================================================================
-- NEW TABLES:
--   1. public.bgop_config           — 9 seed rows (3 secrets, 6 config)
--   2. pipeline.credentials_vault   — 5 seed rows (vault keys, values TBD)
--   3. pipeline.campaign_codes      — empty, FK → core.candidates(candidate_id)
--   4. pipeline.processor_access    — empty, FK → core.candidates(candidate_id)
--
-- ALTERED TABLES:
--   5. donor_intelligence.person_master   — +confidence_score, +acxiom_load_batch
--   6. donor_intelligence.contribution_map — +campaign_code_id FK → campaign_codes
--
-- NEW PARTITIONS:
--   7. brain.event_queue_2026_08          — Aug 2026
--   8. pipeline.inbound_data_queue_2026_08 — Aug 2026
--
-- NEW INDEXES: 6 (2 on bgop_config, 2 on campaign_codes, 2 on processor_access)
-- FK CORRECTIONS: 2 (brief referenced candidates(id), actual PK is candidate_id)
-- =============================================================================
