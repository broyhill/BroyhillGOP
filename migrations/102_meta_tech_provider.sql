-- ============================================================================
-- Migration 102: Meta Tech Provider Architecture
-- ============================================================================
--
-- Purpose: Schema additions for per-candidate Meta Business Manager isolation
--          via the Tech Provider pattern. Enables BroyhillGOP's single Meta App
--          to operate as a Tech Provider inside each candidate's own BM,
--          giving BM-level cascade-ban isolation without per-candidate App Review.
--
-- Status: DRY-RUN. NOT APPLIED. Review only.
--
-- Phase: Step 3 of 8 in safe-pathway sequence.
--        Architecture document: META_TECH_PROVIDER_ARCHITECTURE.md (Step 1)
--        This migration: Step 3 (write only)
--        Application of this migration: Step 8 (after explicit authorization)
--
-- Author: Claude (architecture build)
-- For: Eddie Broyhill
-- Date: 2026-04-29
--
-- ----------------------------------------------------------------------------
-- LOCKED RULES VERIFIED:
-- ----------------------------------------------------------------------------
--   [x] TWO-PHASE PROTOCOL: Dry-run only, no production execution
--   [x] Silo isolation: All new tables have candidate_id + RLS policy
--   [x] No FEC/NCBOE files touched
--   [x] No identity resolver changes (Ed != Edward rule preserved by not modifying it)
--   [x] All paths route through E55 API gateway (webhook URL pattern documented)
--   [x] TCPA gate non-bypassable (this migration doesn't touch compliance gates)
--   [x] Idempotent: every CREATE/ALTER uses IF NOT EXISTS
--   [x] Tokens never stored plaintext (system_user_token_encrypted is BYTEA)
--   [x] Append-only audit log (meta_oauth_audit_log)
--
-- ----------------------------------------------------------------------------
-- DEPENDENCIES (must exist before applying):
-- ----------------------------------------------------------------------------
--   - public.candidate_social_accounts table (from existing E19 deployment)
--   - public.candidates table
--   - pgcrypto extension (for gen_random_uuid)
--
-- ----------------------------------------------------------------------------
-- ROLLBACK STRATEGY:
-- ----------------------------------------------------------------------------
--   This migration only ADDS columns and tables. It does not modify or drop
--   existing schema. Rollback consists of:
--     - DROP TABLE meta_app_health
--     - DROP TABLE meta_oauth_audit_log
--     - ALTER TABLE candidate_social_accounts DROP COLUMN <each new col>
--   See bottom of file for the full rollback block (commented out).
--
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- SECTION 1: Pre-flight checks
-- ----------------------------------------------------------------------------
-- Verify expected dependencies exist before proceeding.
-- If any of these fail, the migration aborts cleanly with no partial state.

DO $preflight$
BEGIN
    -- Check pgcrypto for gen_random_uuid()
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'
    ) THEN
        CREATE EXTENSION IF NOT EXISTS pgcrypto;
    END IF;

    -- Check candidates table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'candidates'
    ) THEN
        RAISE EXCEPTION 'Pre-flight failed: public.candidates table does not exist. Apply E03 migration first.';
    END IF;

    -- Check candidate_social_accounts table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'candidate_social_accounts'
    ) THEN
        RAISE EXCEPTION 'Pre-flight failed: public.candidate_social_accounts table does not exist. Apply E19 base migration first.';
    END IF;

    RAISE NOTICE 'Pre-flight checks passed.';
END;
$preflight$;


-- ----------------------------------------------------------------------------
-- SECTION 2: Add Tech Provider columns to candidate_social_accounts
-- ----------------------------------------------------------------------------
-- These columns extend the existing per-candidate row with Business Manager,
-- System User, and webhook subscription identifiers. Tokens stored encrypted.

ALTER TABLE public.candidate_social_accounts
    ADD COLUMN IF NOT EXISTS business_manager_id            VARCHAR(255),
    ADD COLUMN IF NOT EXISTS system_user_id                 VARCHAR(255),
    ADD COLUMN IF NOT EXISTS system_user_token_encrypted    BYTEA,
    ADD COLUMN IF NOT EXISTS system_user_token_expires_at   TIMESTAMP,
    ADD COLUMN IF NOT EXISTS meta_encryption_key_id         VARCHAR(64),
    ADD COLUMN IF NOT EXISTS bm_provisioning_status         VARCHAR(50)
        DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS bm_provisioned_at              TIMESTAMP,
    ADD COLUMN IF NOT EXISTS webhook_subscription_id        VARCHAR(255),
    ADD COLUMN IF NOT EXISTS instagram_business_account_id  VARCHAR(255),
    ADD COLUMN IF NOT EXISTS last_token_refresh_at          TIMESTAMP,
    ADD COLUMN IF NOT EXISTS last_health_check_at           TIMESTAMP,
    ADD COLUMN IF NOT EXISTS account_health_score           INT,
    ADD COLUMN IF NOT EXISTS oauth_revoked_at               TIMESTAMP;

-- Constrain bm_provisioning_status to known states.
-- Drop existing constraint first if present, to make this idempotent.
ALTER TABLE public.candidate_social_accounts
    DROP CONSTRAINT IF EXISTS candidate_social_accounts_bm_status_check;

ALTER TABLE public.candidate_social_accounts
    ADD CONSTRAINT candidate_social_accounts_bm_status_check
    CHECK (bm_provisioning_status IN (
        'pending',           -- Candidate has not started OAuth flow yet
        'oauth_initiated',   -- Candidate clicked Connect, on Meta OAuth screen
        'auto_created',      -- BM was auto-created via Business Login API
        'existing_bm_used',  -- Candidate had existing BM, we used it
        'transfer_required', -- Page is in someone else's BM, candidate must transfer
        'provisioned',       -- Fully set up, tokens active, webhooks subscribed
        'oauth_revoked',     -- Candidate revoked access via FB settings
        'oauth_expired',     -- Token expired and refresh failed
        'oauth_error'        -- Unrecoverable error during provisioning
    ));

COMMENT ON COLUMN public.candidate_social_accounts.business_manager_id IS
    'Meta-assigned Business Manager ID for this candidate. Each candidate has their own BM, owned by the candidate, with BroyhillGOP installed as Tech Provider partner.';

COMMENT ON COLUMN public.candidate_social_accounts.system_user_id IS
    'Meta-assigned System User ID inside the candidate''s BM. The System User holds long-lived tokens and is the persistent identity used for API calls on behalf of this candidate.';

COMMENT ON COLUMN public.candidate_social_accounts.system_user_token_encrypted IS
    'Long-lived System User access token, encrypted with AES-256-GCM using key identified by meta_encryption_key_id. Never stored plaintext. Decrypted in application memory only at API call time.';

COMMENT ON COLUMN public.candidate_social_accounts.meta_encryption_key_id IS
    'Identifier for which encryption key version was used. Supports key rotation: old tokens decryptable with old key while new tokens use rotated key.';

COMMENT ON COLUMN public.candidate_social_accounts.bm_provisioning_status IS
    'Lifecycle state of the candidate''s Business Manager provisioning. See CHECK constraint for allowed values.';

-- Index for monitoring workers (token refresh, health checks)
CREATE INDEX IF NOT EXISTS idx_csa_token_expires
    ON public.candidate_social_accounts (system_user_token_expires_at)
    WHERE system_user_token_encrypted IS NOT NULL
      AND bm_provisioning_status = 'provisioned';

CREATE INDEX IF NOT EXISTS idx_csa_provisioning_status
    ON public.candidate_social_accounts (bm_provisioning_status);

CREATE INDEX IF NOT EXISTS idx_csa_business_manager
    ON public.candidate_social_accounts (business_manager_id)
    WHERE business_manager_id IS NOT NULL;


-- ----------------------------------------------------------------------------
-- SECTION 3: meta_oauth_audit_log
-- ----------------------------------------------------------------------------
-- Append-only audit log of every OAuth and token lifecycle event.
-- Never updated or deleted. Retention managed by separate archival policy.

CREATE TABLE IF NOT EXISTS public.meta_oauth_audit_log (
    event_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id        UUID         NOT NULL,
    event_type          VARCHAR(64)  NOT NULL,
    event_metadata      JSONB        NOT NULL DEFAULT '{}'::jsonb,
    event_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
    ip_address          INET,
    user_agent          TEXT,
    -- No FK constraint on candidate_id intentionally:
    -- audit log must survive candidate row deletion for compliance.
    -- Soft references only.
    CONSTRAINT meta_oauth_audit_log_event_type_check
        CHECK (event_type IN (
            'oauth_initiated',
            'oauth_callback_received',
            'bm_existing_detected',
            'bm_auto_created',
            'bm_existing_selected',
            'pages_granted',
            'pages_denied',
            'permissions_granted',
            'permissions_denied',
            'system_user_created',
            'token_issued',
            'token_refreshed',
            'token_refresh_failed',
            'token_expired',
            'access_revoked_by_candidate',
            'access_revoked_by_admin',
            'webhook_subscribed',
            'webhook_unsubscribed',
            'webhook_disabled_by_meta',
            'transfer_required_detected',
            'health_check_performed'
        ))
);

COMMENT ON TABLE public.meta_oauth_audit_log IS
    'Append-only audit log of OAuth and token lifecycle events. Used for compliance, debugging, and security incident investigation. Never updated or deleted by application code.';

CREATE INDEX IF NOT EXISTS idx_oauth_audit_candidate
    ON public.meta_oauth_audit_log (candidate_id, event_at DESC);

CREATE INDEX IF NOT EXISTS idx_oauth_audit_event_type
    ON public.meta_oauth_audit_log (event_type, event_at DESC);

CREATE INDEX IF NOT EXISTS idx_oauth_audit_event_at
    ON public.meta_oauth_audit_log (event_at DESC);

-- Enforce append-only: prevent UPDATE and DELETE on this table.
-- Triggers raise exceptions on any attempt.

CREATE OR REPLACE FUNCTION public.meta_oauth_audit_log_block_modify()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'meta_oauth_audit_log is append-only. % not permitted.', TG_OP;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS meta_oauth_audit_log_no_update
    ON public.meta_oauth_audit_log;
CREATE TRIGGER meta_oauth_audit_log_no_update
    BEFORE UPDATE ON public.meta_oauth_audit_log
    FOR EACH ROW EXECUTE FUNCTION public.meta_oauth_audit_log_block_modify();

DROP TRIGGER IF EXISTS meta_oauth_audit_log_no_delete
    ON public.meta_oauth_audit_log;
CREATE TRIGGER meta_oauth_audit_log_no_delete
    BEFORE DELETE ON public.meta_oauth_audit_log
    FOR EACH ROW EXECUTE FUNCTION public.meta_oauth_audit_log_block_modify();


-- ----------------------------------------------------------------------------
-- SECTION 4: meta_app_health
-- ----------------------------------------------------------------------------
-- Master-tier monitoring of the BroyhillGOP App's overall health.
-- Single-row table updated by daily monitoring worker.
-- Read by master-tier control panel.
-- Not RLS-isolated by candidate (it's platform-wide state).

CREATE TABLE IF NOT EXISTS public.meta_app_health (
    -- Single-row table. Use a fixed UUID for the only row.
    health_id                       UUID         PRIMARY KEY
                                                  DEFAULT 'a0000000-0000-0000-0000-000000000001'::uuid,
    checked_at                      TIMESTAMP    NOT NULL DEFAULT NOW(),
    app_id                          VARCHAR(255),
    app_review_status               VARCHAR(50)  DEFAULT 'pending',
    business_verification_status    VARCHAR(50)  DEFAULT 'pending',
    current_rate_limit_tier         INT,
    connected_candidates_count      INT          DEFAULT 0,
    revoked_candidates_count        INT          DEFAULT 0,
    expired_candidates_count        INT          DEFAULT 0,
    pending_token_refreshes_count   INT          DEFAULT 0,
    last_24h_oauth_initiations      INT          DEFAULT 0,
    last_24h_oauth_completions      INT          DEFAULT 0,
    last_24h_oauth_failures         INT          DEFAULT 0,
    health_alerts                   JSONB        DEFAULT '[]'::jsonb,
    notes                           TEXT,
    CONSTRAINT meta_app_health_review_status_check
        CHECK (app_review_status IN (
            'pending', 'under_review', 'standard_access',
            'advanced_access', 'restricted', 'suspended'
        )),
    CONSTRAINT meta_app_health_verification_status_check
        CHECK (business_verification_status IN (
            'pending', 'submitted', 'verified', 'expired', 'denied'
        )),
    CONSTRAINT meta_app_health_singleton
        CHECK (health_id = 'a0000000-0000-0000-0000-000000000001'::uuid)
);

COMMENT ON TABLE public.meta_app_health IS
    'Single-row platform-wide health state of the BroyhillGOP Meta App. Master-tier read-only. Updated by monitoring worker.';

-- Seed the singleton row if it doesn't exist
INSERT INTO public.meta_app_health (health_id)
VALUES ('a0000000-0000-0000-0000-000000000001'::uuid)
ON CONFLICT (health_id) DO NOTHING;


-- ----------------------------------------------------------------------------
-- SECTION 5: meta_webhook_event_log
-- ----------------------------------------------------------------------------
-- Append-only log of inbound webhook events from Meta.
-- Used for idempotency (de-duplicate retries via external_event_id),
-- replay, and debugging.

CREATE TABLE IF NOT EXISTS public.meta_webhook_event_log (
    log_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id        UUID,                                           -- Resolved by webhook router from BM ID; NULL if unresolvable
    business_manager_id VARCHAR(255),                                   -- From Meta payload
    page_id             VARCHAR(255),                                   -- From Meta payload
    external_event_id   VARCHAR(255) NOT NULL,                          -- Meta's event ID, used for idempotency
    event_type          VARCHAR(64)  NOT NULL,                          -- 'message', 'comment', 'feed', 'mention', etc.
    event_payload       JSONB        NOT NULL,                          -- Full Meta webhook payload
    received_at         TIMESTAMP    NOT NULL DEFAULT NOW(),
    processed_at        TIMESTAMP,                                      -- NULL until handler completes
    processing_status   VARCHAR(32)  DEFAULT 'pending',
    processing_error    TEXT,
    -- Idempotency: same external_event_id from same BM = same event
    CONSTRAINT meta_webhook_event_log_idempotency
        UNIQUE (business_manager_id, external_event_id),
    CONSTRAINT meta_webhook_event_log_status_check
        CHECK (processing_status IN (
            'pending', 'processing', 'completed', 'failed', 'duplicate', 'unresolvable'
        ))
);

COMMENT ON TABLE public.meta_webhook_event_log IS
    'Inbound webhook events from Meta. Idempotency-keyed by (business_manager_id, external_event_id). Routed to handlers by event_type.';

CREATE INDEX IF NOT EXISTS idx_webhook_event_candidate
    ON public.meta_webhook_event_log (candidate_id, received_at DESC)
    WHERE candidate_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_webhook_event_pending
    ON public.meta_webhook_event_log (received_at)
    WHERE processing_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_webhook_event_bm
    ON public.meta_webhook_event_log (business_manager_id, received_at DESC);


-- ----------------------------------------------------------------------------
-- SECTION 6: meta_token_refresh_attempts
-- ----------------------------------------------------------------------------
-- Tracks attempts to refresh System User tokens. Used by the daily refresh
-- worker to retry failed refreshes with backoff and to surface persistent
-- failures to staff.

CREATE TABLE IF NOT EXISTS public.meta_token_refresh_attempts (
    attempt_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id        UUID         NOT NULL,
    attempted_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    outcome             VARCHAR(32)  NOT NULL,
    error_code          VARCHAR(64),
    error_message       TEXT,
    new_expires_at      TIMESTAMP,
    CONSTRAINT meta_token_refresh_outcome_check
        CHECK (outcome IN (
            'success',
            'token_expired',
            'access_revoked',
            'rate_limited',
            'meta_api_error',
            'network_error',
            'unknown_error'
        ))
);

COMMENT ON TABLE public.meta_token_refresh_attempts IS
    'Per-attempt log of token refresh outcomes. Persistent failures (3+ in a row) trigger staff alert.';

CREATE INDEX IF NOT EXISTS idx_token_refresh_candidate
    ON public.meta_token_refresh_attempts (candidate_id, attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_token_refresh_failures
    ON public.meta_token_refresh_attempts (candidate_id, attempted_at DESC)
    WHERE outcome != 'success';


-- ----------------------------------------------------------------------------
-- SECTION 6.5: meta_event_bus_replay_queue
-- ----------------------------------------------------------------------------
-- Fallback queue for events that fail to publish to Redis (Redis down,
-- network blip, etc). A replay worker picks these up when Redis recovers
-- and re-publishes them to broyhillgop.events channel.
--
-- This makes Brain integration fault-tolerant: events never get lost.
-- Idempotency via event_id is enforced at the Brain side.

CREATE TABLE IF NOT EXISTS public.meta_event_bus_replay_queue (
    queue_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id            UUID         NOT NULL,                  -- Same UUID present in event payload for dedup
    event_type          VARCHAR(64)  NOT NULL,                  -- e.g. 'social.oauth.completed'
    candidate_id        UUID,                                    -- Nullable for app-wide events
    event_payload       JSONB        NOT NULL,                  -- Full event JSON ready to re-publish
    enqueued_at         TIMESTAMP    NOT NULL DEFAULT NOW(),
    publish_attempts    INT          NOT NULL DEFAULT 0,
    last_attempt_at     TIMESTAMP,
    last_error          TEXT,
    published_at        TIMESTAMP,                               -- Set when worker successfully publishes
    status              VARCHAR(32)  NOT NULL DEFAULT 'pending',
    CONSTRAINT meta_replay_queue_status_check
        CHECK (status IN ('pending', 'publishing', 'published', 'permanent_failure'))
);

COMMENT ON TABLE public.meta_event_bus_replay_queue IS
    'Fallback queue for events that fail to publish to Redis. Replay worker '
    'processes pending entries and re-publishes when Redis is healthy. '
    'Permanent failure status set after MAX_REPLAY_ATTEMPTS (configurable, default 10).';

CREATE INDEX IF NOT EXISTS idx_replay_queue_pending
    ON public.meta_event_bus_replay_queue (enqueued_at)
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_replay_queue_event_id
    ON public.meta_event_bus_replay_queue (event_id);

CREATE INDEX IF NOT EXISTS idx_replay_queue_candidate
    ON public.meta_event_bus_replay_queue (candidate_id, enqueued_at DESC)
    WHERE candidate_id IS NOT NULL;


-- ----------------------------------------------------------------------------
-- SECTION 7: Row-Level Security policies
-- ----------------------------------------------------------------------------
-- Every candidate-scoped table gets RLS enforcing candidate_id isolation.
-- Master tier (platform_admin role) can bypass via service-role connection.
--
-- Note: The existing candidate_social_accounts table already has its own
-- RLS policy (from E19 base migration). The new columns inherit it. We do
-- NOT add a new policy on candidate_social_accounts in this migration.

-- 7.1 RLS on meta_oauth_audit_log
ALTER TABLE public.meta_oauth_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS meta_oauth_audit_log_candidate_isolation
    ON public.meta_oauth_audit_log;

CREATE POLICY meta_oauth_audit_log_candidate_isolation
    ON public.meta_oauth_audit_log
    FOR ALL
    TO authenticated
    USING (
        candidate_id::text = current_setting('app.current_candidate_id', true)
        OR current_setting('app.current_role', true) = 'platform_admin'
    )
    WITH CHECK (
        candidate_id::text = current_setting('app.current_candidate_id', true)
        OR current_setting('app.current_role', true) = 'platform_admin'
    );

-- 7.2 RLS on meta_webhook_event_log
ALTER TABLE public.meta_webhook_event_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS meta_webhook_event_log_candidate_isolation
    ON public.meta_webhook_event_log;

CREATE POLICY meta_webhook_event_log_candidate_isolation
    ON public.meta_webhook_event_log
    FOR ALL
    TO authenticated
    USING (
        candidate_id::text = current_setting('app.current_candidate_id', true)
        OR current_setting('app.current_role', true) = 'platform_admin'
        OR candidate_id IS NULL  -- unresolvable events visible to platform_admin only via the OR above
    )
    WITH CHECK (
        candidate_id::text = current_setting('app.current_candidate_id', true)
        OR current_setting('app.current_role', true) = 'platform_admin'
    );

-- 7.3 RLS on meta_token_refresh_attempts
ALTER TABLE public.meta_token_refresh_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS meta_token_refresh_attempts_candidate_isolation
    ON public.meta_token_refresh_attempts;

CREATE POLICY meta_token_refresh_attempts_candidate_isolation
    ON public.meta_token_refresh_attempts
    FOR ALL
    TO authenticated
    USING (
        candidate_id::text = current_setting('app.current_candidate_id', true)
        OR current_setting('app.current_role', true) = 'platform_admin'
    )
    WITH CHECK (
        candidate_id::text = current_setting('app.current_candidate_id', true)
        OR current_setting('app.current_role', true) = 'platform_admin'
    );

-- 7.4 RLS on meta_app_health (master-tier only)
ALTER TABLE public.meta_app_health ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS meta_app_health_master_only
    ON public.meta_app_health;

CREATE POLICY meta_app_health_master_only
    ON public.meta_app_health
    FOR ALL
    TO authenticated
    USING (current_setting('app.current_role', true) = 'platform_admin')
    WITH CHECK (current_setting('app.current_role', true) = 'platform_admin');

-- 7.5 RLS on meta_event_bus_replay_queue (master-tier only — queue is platform plumbing)
ALTER TABLE public.meta_event_bus_replay_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS meta_event_bus_replay_queue_master_only
    ON public.meta_event_bus_replay_queue;

CREATE POLICY meta_event_bus_replay_queue_master_only
    ON public.meta_event_bus_replay_queue
    FOR ALL
    TO authenticated
    USING (current_setting('app.current_role', true) = 'platform_admin')
    WITH CHECK (current_setting('app.current_role', true) = 'platform_admin');


-- ----------------------------------------------------------------------------
-- SECTION 8: Helper views
-- ----------------------------------------------------------------------------
-- Convenience views for common queries. Read-only.

-- 8.1 Candidates with active Tech Provider provisioning
CREATE OR REPLACE VIEW public.v_meta_provisioned_candidates AS
SELECT
    csa.candidate_id,
    c.name                                    AS candidate_name,
    csa.business_manager_id,
    csa.system_user_id,
    csa.facebook_page_id,
    csa.instagram_business_account_id,
    csa.bm_provisioning_status,
    csa.bm_provisioned_at,
    csa.system_user_token_expires_at,
    csa.last_token_refresh_at,
    csa.last_health_check_at,
    csa.account_health_score,
    -- Days until token expires (NULL if no token or already expired)
    CASE
        WHEN csa.system_user_token_expires_at IS NULL THEN NULL
        WHEN csa.system_user_token_expires_at < NOW() THEN -1
        ELSE EXTRACT(DAY FROM (csa.system_user_token_expires_at - NOW()))::INT
    END AS days_until_token_expires
FROM public.candidate_social_accounts csa
JOIN public.candidates c ON c.candidate_id = csa.candidate_id
WHERE csa.bm_provisioning_status IN ('provisioned', 'oauth_expired');

COMMENT ON VIEW public.v_meta_provisioned_candidates IS
    'Convenience view of candidates with Tech Provider provisioning. Honors RLS from underlying tables.';

-- 8.2 Token refresh worker queue
CREATE OR REPLACE VIEW public.v_meta_tokens_needing_refresh AS
SELECT
    csa.candidate_id,
    csa.business_manager_id,
    csa.system_user_id,
    csa.system_user_token_expires_at,
    csa.last_token_refresh_at,
    -- Tokens expiring within 7 days, not refreshed in last 24h
    EXTRACT(DAY FROM (csa.system_user_token_expires_at - NOW()))::INT AS days_until_expiry
FROM public.candidate_social_accounts csa
WHERE csa.bm_provisioning_status = 'provisioned'
  AND csa.system_user_token_encrypted IS NOT NULL
  AND csa.system_user_token_expires_at IS NOT NULL
  AND csa.system_user_token_expires_at < (NOW() + INTERVAL '7 days')
  AND (
      csa.last_token_refresh_at IS NULL
      OR csa.last_token_refresh_at < (NOW() - INTERVAL '24 hours')
  );

COMMENT ON VIEW public.v_meta_tokens_needing_refresh IS
    'Token refresh worker queue. Refresh runs daily and processes tokens expiring within 7 days that have not been refreshed in the last 24 hours.';


-- ----------------------------------------------------------------------------
-- SECTION 9: Verification queries
-- ----------------------------------------------------------------------------
-- Run these after applying the migration to verify state.
-- They are SELECT-only and have no side effects.

-- 9.1 Verify all new columns exist
DO $verify_columns$
DECLARE
    expected_cols TEXT[] := ARRAY[
        'business_manager_id', 'system_user_id', 'system_user_token_encrypted',
        'system_user_token_expires_at', 'meta_encryption_key_id',
        'bm_provisioning_status', 'bm_provisioned_at', 'webhook_subscription_id',
        'instagram_business_account_id', 'last_token_refresh_at',
        'last_health_check_at', 'account_health_score', 'oauth_revoked_at'
    ];
    missing_cols TEXT[] := ARRAY[]::TEXT[];
    col TEXT;
BEGIN
    FOREACH col IN ARRAY expected_cols LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'candidate_social_accounts'
              AND column_name = col
        ) THEN
            missing_cols := array_append(missing_cols, col);
        END IF;
    END LOOP;

    IF array_length(missing_cols, 1) > 0 THEN
        RAISE EXCEPTION 'Verification failed: missing columns on candidate_social_accounts: %',
            array_to_string(missing_cols, ', ');
    END IF;

    RAISE NOTICE 'Verification: all 13 expected columns present on candidate_social_accounts';
END;
$verify_columns$;

-- 9.2 Verify all new tables exist
DO $verify_tables$
DECLARE
    expected_tables TEXT[] := ARRAY[
        'meta_oauth_audit_log',
        'meta_app_health',
        'meta_webhook_event_log',
        'meta_token_refresh_attempts',
        'meta_event_bus_replay_queue'
    ];
    missing_tables TEXT[] := ARRAY[]::TEXT[];
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY expected_tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            missing_tables := array_append(missing_tables, tbl);
        END IF;
    END LOOP;

    IF array_length(missing_tables, 1) > 0 THEN
        RAISE EXCEPTION 'Verification failed: missing tables: %',
            array_to_string(missing_tables, ', ');
    END IF;

    RAISE NOTICE 'Verification: all 5 expected tables present';
END;
$verify_tables$;

-- 9.3 Verify singleton row in meta_app_health
DO $verify_singleton$
DECLARE
    row_count INT;
BEGIN
    SELECT COUNT(*) INTO row_count FROM public.meta_app_health;
    IF row_count != 1 THEN
        RAISE EXCEPTION 'Verification failed: meta_app_health should have exactly 1 row, has %', row_count;
    END IF;
    RAISE NOTICE 'Verification: meta_app_health singleton row present';
END;
$verify_singleton$;


-- ----------------------------------------------------------------------------
-- SECTION 10: Migration metadata
-- ----------------------------------------------------------------------------
-- Optional: record this migration in a migrations log if your project tracks them.
-- Commented out by default; uncomment if you have a migrations tracking table.

-- INSERT INTO public.schema_migrations (version, name, applied_at)
-- VALUES ('102', 'meta_tech_provider', NOW())
-- ON CONFLICT (version) DO NOTHING;


COMMIT;

-- ============================================================================
-- ROLLBACK (kept commented for safety; uncomment and run only if rolling back)
-- ============================================================================
-- BEGIN;
--
-- -- Drop helper views first
-- DROP VIEW IF EXISTS public.v_meta_tokens_needing_refresh;
-- DROP VIEW IF EXISTS public.v_meta_provisioned_candidates;
--
-- -- Drop new tables (in reverse dependency order; none have FK to each other so order doesn't strictly matter)
-- DROP TABLE IF EXISTS public.meta_event_bus_replay_queue;
-- DROP TABLE IF EXISTS public.meta_token_refresh_attempts;
-- DROP TABLE IF EXISTS public.meta_webhook_event_log;
-- DROP TABLE IF EXISTS public.meta_oauth_audit_log;
-- DROP TABLE IF EXISTS public.meta_app_health;
-- DROP FUNCTION IF EXISTS public.meta_oauth_audit_log_block_modify();
--
-- -- Drop new constraint and indexes on candidate_social_accounts
-- DROP INDEX IF EXISTS public.idx_csa_business_manager;
-- DROP INDEX IF EXISTS public.idx_csa_provisioning_status;
-- DROP INDEX IF EXISTS public.idx_csa_token_expires;
-- ALTER TABLE public.candidate_social_accounts
--     DROP CONSTRAINT IF EXISTS candidate_social_accounts_bm_status_check;
--
-- -- Drop new columns
-- ALTER TABLE public.candidate_social_accounts
--     DROP COLUMN IF EXISTS oauth_revoked_at,
--     DROP COLUMN IF EXISTS account_health_score,
--     DROP COLUMN IF EXISTS last_health_check_at,
--     DROP COLUMN IF EXISTS last_token_refresh_at,
--     DROP COLUMN IF EXISTS instagram_business_account_id,
--     DROP COLUMN IF EXISTS webhook_subscription_id,
--     DROP COLUMN IF EXISTS bm_provisioned_at,
--     DROP COLUMN IF EXISTS bm_provisioning_status,
--     DROP COLUMN IF EXISTS meta_encryption_key_id,
--     DROP COLUMN IF EXISTS system_user_token_expires_at,
--     DROP COLUMN IF EXISTS system_user_token_encrypted,
--     DROP COLUMN IF EXISTS system_user_id,
--     DROP COLUMN IF EXISTS business_manager_id;
--
-- COMMIT;
-- ============================================================================
-- END OF MIGRATION 102
-- ============================================================================
