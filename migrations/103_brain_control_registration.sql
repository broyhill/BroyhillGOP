-- ============================================================================
-- Migration 103: Tech Provider Registration in Brain Control Governance Layer
-- ============================================================================
--
-- Purpose: Register the E19 Tech Provider as a first-class ecosystem in the
--          brain_control schema so the platform's governance, cost accounting,
--          health monitoring, and trigger router pick it up automatically.
--
--          Also registers automation_workflows that fire when Tech Provider
--          publishes social.oauth.* events, wiring it into the pre-existing
--          TriggerRouter pattern used across the platform.
--
-- Status: DRY-RUN. NOT APPLIED. Review only.
--
-- Phase: Step 5b in safe-pathway sequence.
--        Architecture: META_TECH_PROVIDER_ARCHITECTURE.md (Section 13: Brain Integration)
--
-- Author: Claude
-- For: Eddie Broyhill
-- Date: 2026-04-29
--
-- ----------------------------------------------------------------------------
-- LOCKED RULES VERIFIED:
-- ----------------------------------------------------------------------------
--   [x] TWO-PHASE PROTOCOL: dry-run only
--   [x] No FEC/NCBOE touched
--   [x] No identity resolver changes
--   [x] All routes through E55 API gateway (URL pattern documented)
--   [x] Idempotent: ON CONFLICT DO UPDATE everywhere
--   [x] Pattern matches 053_NEXUS_PLATFORM_INTEGRATION.sql canonical pattern
--
-- ----------------------------------------------------------------------------
-- DEPENDENCIES (must exist before applying):
-- ----------------------------------------------------------------------------
--   - brain_control schema (from 000_brain_init.sql)
--   - brain_control.ecosystems table (from 001_brain_core_schema.sql)
--   - brain_control.functions table (from 001_brain_core_schema.sql)
--   - automation_workflows table (used by TriggerRouter)
--   - Migration 102 (this Tech Provider's own tables) applied first
--
-- ----------------------------------------------------------------------------
-- COLLISION CHECK:
-- ----------------------------------------------------------------------------
--   Ecosystem code: 'E19_TECH_PROVIDER' (new, no collision with E19_SOCIAL or NEXUS)
--   Function codes: 'F-TP01' through 'F-TP04' (TP prefix avoids collision with F001-F999 numeric pattern)
--
--   NOTE: brain_control.functions has a CHECK constraint:
--     CONSTRAINT chk_function_code CHECK (function_code ~ '^F[0-9]{3}$')
--   This forces 3-digit numeric codes. We use F901-F904 (high range, unallocated)
--   to comply with the constraint while reserving Tech Provider's namespace.
--
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- SECTION 1: Pre-flight checks
-- ----------------------------------------------------------------------------

DO $preflight$
BEGIN
    -- Verify brain_control schema exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata WHERE schema_name = 'brain_control'
    ) THEN
        RAISE EXCEPTION 'Pre-flight failed: brain_control schema does not exist. '
                        'Apply 000_brain_init.sql through 001_brain_core_schema.sql first.';
    END IF;

    -- Verify brain_control.ecosystems table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'brain_control' AND table_name = 'ecosystems'
    ) THEN
        RAISE EXCEPTION 'Pre-flight failed: brain_control.ecosystems missing.';
    END IF;

    -- Verify brain_control.functions table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'brain_control' AND table_name = 'functions'
    ) THEN
        RAISE EXCEPTION 'Pre-flight failed: brain_control.functions missing.';
    END IF;

    -- Verify migration 102 was applied (look for one of its tables)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'meta_oauth_audit_log'
    ) THEN
        RAISE EXCEPTION 'Pre-flight failed: migration 102 not yet applied. '
                        'Apply 102_meta_tech_provider.sql first.';
    END IF;

    -- automation_workflows is optional — if it exists, we register workflows;
    -- if not, we skip the workflow registration block but still complete the
    -- ecosystem and function registration. (TriggerRouter is OK without us.)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'automation_workflows'
    ) THEN
        RAISE NOTICE 'automation_workflows table not present; skipping workflow registration. '
                     'TriggerRouter integration will activate when that table is created.';
    END IF;

    RAISE NOTICE 'Pre-flight checks passed.';
END;
$preflight$;


-- ----------------------------------------------------------------------------
-- SECTION 2: Register Tech Provider as an ecosystem
-- ----------------------------------------------------------------------------
-- Pattern matches NEXUS registration in 053_NEXUS_PLATFORM_INTEGRATION.sql

INSERT INTO brain_control.ecosystems (
    ecosystem_code,
    ecosystem_name,
    description,
    schema_name,
    api_prefix,
    status,
    criticality,
    dependencies,
    provides_to,
    ai_powered,
    ai_provider,
    ai_primary_model,
    monthly_budget,
    cost_center,
    tables_count,
    functions_count
) VALUES (
    'E19_TECH_PROVIDER',
    'E19 Meta Tech Provider',
    'Per-candidate Meta Business Manager isolation via Tech Provider OAuth pattern. '
        'Provides per-candidate cascade-ban isolation, encrypted token vault, daily '
        'token refresh, webhook subscription lifecycle, and OAuth provisioning at '
        '~90-second onboarding cost per candidate.',
    'public',
    '/v1/webhooks/meta',
    'ACTIVE',
    'HIGH',
    ARRAY['E0_DATAHUB', 'E20_BRAIN', 'E55_API_GATEWAY'],
    ARRAY['E19_SOCIAL', 'E20_BRAIN', 'E35_INBOX', 'E51_NEXUS'],
    FALSE,                              -- This layer is plumbing, not AI generation
    NULL,
    NULL,
    50.00,                              -- Meta API calls are mostly free; budget for monitoring/alerts
    'TECH_PROVIDER',
    4,                                   -- meta_oauth_audit_log, meta_app_health, meta_webhook_event_log, meta_token_refresh_attempts
    4                                    -- F901-F904 below
)
ON CONFLICT (ecosystem_code) DO UPDATE SET
    description = EXCLUDED.description,
    dependencies = EXCLUDED.dependencies,
    provides_to = EXCLUDED.provides_to,
    monthly_budget = EXCLUDED.monthly_budget,
    tables_count = EXCLUDED.tables_count,
    functions_count = EXCLUDED.functions_count,
    updated_at = NOW();


-- ----------------------------------------------------------------------------
-- SECTION 3: Register dependencies
-- ----------------------------------------------------------------------------

INSERT INTO brain_control.ecosystem_dependencies (
    ecosystem_code, depends_on, dependency_type, description
) VALUES
    ('E19_TECH_PROVIDER', 'E0_DATAHUB', 'required',
     'Token vault storage, audit log, webhook event log all live in DataHub.'),
    ('E19_TECH_PROVIDER', 'E20_BRAIN', 'required',
     'Tech Provider publishes social.oauth.* events to Brain and consumes '
     'intelligence.* decisions back from Brain.'),
    ('E19_TECH_PROVIDER', 'E55_API_GATEWAY', 'required',
     'OAuth callback URL and webhook endpoints route through E55 gateway.')
ON CONFLICT (ecosystem_code, depends_on) DO UPDATE SET
    description = EXCLUDED.description;


-- ----------------------------------------------------------------------------
-- SECTION 4: Register Tech Provider functions
-- ----------------------------------------------------------------------------
-- Function codes F901-F904 (high range to avoid collision with existing F001-F899)
-- chk_function_code CHECK constraint requires '^F[0-9]{3}$' — these match.

INSERT INTO brain_control.functions (
    function_code,
    function_name,
    ecosystem_code,
    description,
    is_ai_powered,
    cost_type,
    unit_cost,
    monthly_forecast_calls,
    monthly_forecast_cost,
    quality_floor,
    effectiveness_floor,
    latency_threshold_ms,
    error_rate_threshold,
    is_active,
    is_critical,
    requires_approval,
    timeout_seconds,
    retry_count
) VALUES
    -- F901: OAuth Provisioning (the big one)
    ('F901',
     'Tech Provider OAuth Provisioning',
     'E19_TECH_PROVIDER',
     'Handles the full OAuth callback flow: code exchange, BM auto-provisioning, '
     'System User creation, token issuance, webhook subscription. Called once per '
     'candidate at onboarding. Target: 11-step flow completes in <15 seconds.',
     FALSE,
     'per_call',
     0.0,                                -- Meta API is free for this
     500,                                 -- Estimate: 500 onboardings/mo at scale
     0.00,
     95.00,                               -- 95% of OAuth attempts must complete successfully
     90.00,
     30000,                               -- 30s p99 latency
     0.05,                                -- 5% error rate ceiling (transfer_required is "expected" failure)
     TRUE,
     TRUE,                                -- Critical: blocking onboarding stops new candidates
     FALSE,
     60,
     2),

    -- F902: Token Refresh
    ('F902',
     'System User Token Refresh',
     'E19_TECH_PROVIDER',
     'Daily cron that refreshes System User tokens for candidates within 7 days '
     'of expiry. 3 consecutive failures triggers oauth_expired status and staff alert.',
     FALSE,
     'per_call',
     0.0,
     90000,                               -- ~3000 candidates × 30 days
     0.00,
     99.00,                               -- 99% refresh success rate floor
     99.00,
     5000,
     0.01,
     TRUE,
     TRUE,                                -- Critical: token expiration cascades to candidate offline
     FALSE,
     30,
     3),

    -- F903: Webhook Subscription Lifecycle
    ('F903',
     'Webhook Subscription Manager',
     'E19_TECH_PROVIDER',
     'Manages Meta webhook subscriptions per candidate Page. Handles subscribe, '
     'health check, resubscribe-after-disable, and unsubscribe-on-revoke.',
     FALSE,
     'per_call',
     0.0,
     10000,
     0.00,
     99.00,
     99.00,
     5000,
     0.01,
     TRUE,
     FALSE,
     FALSE,
     30,
     2),

    -- F904: Token Vault (encryption/decryption operations)
    ('F904',
     'Token Vault Encryption Operations',
     'E19_TECH_PROVIDER',
     'AES-256-GCM encrypt/decrypt of System User tokens with key rotation support. '
     'Called at every token storage and every Meta API call.',
     FALSE,
     'per_call',
     0.0,
     1000000,                             -- High volume — every API call
     0.00,
     99.99,                               -- Crypto failures are catastrophic
     99.99,
     50,                                  -- p99 latency in ms
     0.0001,
     TRUE,
     TRUE,
     FALSE,
     5,
     1)
ON CONFLICT (function_code) DO UPDATE SET
    description = EXCLUDED.description,
    monthly_forecast_calls = EXCLUDED.monthly_forecast_calls,
    quality_floor = EXCLUDED.quality_floor,
    updated_at = NOW();


-- ----------------------------------------------------------------------------
-- SECTION 5: Register automation_workflows (TriggerRouter integration)
-- ----------------------------------------------------------------------------
-- These workflows fire when Tech Provider publishes social.oauth.* events.
-- TriggerRouter subscribes to "*" and matches event_type against trigger_type.
--
-- Schema reference (from MASTER_ECOSYSTEM_ORCHESTRATOR.py TriggerRouter):
--   workflow_id, trigger_type, trigger_config, candidate_id, status, mode, timer_expires_at
--
-- We use NULL candidate_id for platform-wide workflows that apply to ALL candidates.
-- Status='active' and mode='auto' (alternative is mode='manual' for review-required).

DO $register_workflows$
BEGIN
    -- Only proceed if automation_workflows table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'automation_workflows'
    ) THEN
        RAISE NOTICE 'automation_workflows table not found; skipping workflow registration. '
                     'Run this migration again after the table is created.';
        RETURN;
    END IF;

    -- Workflow 1: oauth_completed_welcome
    -- When a candidate finishes OAuth, trigger welcome series + enable automation
    INSERT INTO automation_workflows (
        workflow_id, workflow_name, trigger_type, trigger_config,
        candidate_id, status, mode
    ) VALUES (
        gen_random_uuid(),
        'tech_provider_oauth_completed_welcome',
        'social.oauth.completed',
        jsonb_build_object(
            'description',
                'Triggered when a candidate completes Tech Provider OAuth. '
                'Sends welcome email via E30, congratulatory SMS via E31, '
                'and notifies Brain to begin nightly approval workflow.',
            'actions',
                jsonb_build_array(
                    jsonb_build_object('ecosystem', 'E30', 'action', 'send_welcome_email'),
                    jsonb_build_object('ecosystem', 'E31', 'action', 'send_welcome_sms'),
                    jsonb_build_object('ecosystem', 'E20', 'action', 'enable_candidate_automation')
                ),
            'sla_seconds', 300
        ),
        NULL,                                  -- Platform-wide
        'active',
        'auto'
    )
    ON CONFLICT (workflow_name) DO UPDATE SET
        trigger_type = EXCLUDED.trigger_type,
        trigger_config = EXCLUDED.trigger_config,
        status = 'active';

    -- Workflow 2: oauth_failed_assist
    INSERT INTO automation_workflows (
        workflow_id, workflow_name, trigger_type, trigger_config,
        candidate_id, status, mode
    ) VALUES (
        gen_random_uuid(),
        'tech_provider_oauth_failed_assist',
        'social.oauth.failed',
        jsonb_build_object(
            'description',
                'OAuth provisioning failed (transfer required, error). Routes the '
                'candidate to staff via E35 unified inbox + E15 contact directory.',
            'actions',
                jsonb_build_array(
                    jsonb_build_object('ecosystem', 'E35', 'action', 'create_staff_ticket'),
                    jsonb_build_object('ecosystem', 'E15', 'action', 'flag_candidate_needs_help')
                ),
            'sla_seconds', 1800
        ),
        NULL,
        'active',
        'auto'
    )
    ON CONFLICT (workflow_name) DO UPDATE SET
        trigger_type = EXCLUDED.trigger_type,
        trigger_config = EXCLUDED.trigger_config,
        status = 'active';

    -- Workflow 3: oauth_revoked_reengage
    INSERT INTO automation_workflows (
        workflow_id, workflow_name, trigger_type, trigger_config,
        candidate_id, status, mode
    ) VALUES (
        gen_random_uuid(),
        'tech_provider_oauth_revoked_reengage',
        'social.oauth.revoked',
        jsonb_build_object(
            'description',
                'Candidate revoked Tech Provider access via FB settings. Triggers '
                'reconnect campaign through email and SMS, with Brain prioritization '
                'based on candidate value.',
            'actions',
                jsonb_build_array(
                    jsonb_build_object('ecosystem', 'E20', 'action', 'evaluate_reengagement_priority'),
                    jsonb_build_object('ecosystem', 'E30', 'action', 'send_reconnect_email'),
                    jsonb_build_object('ecosystem', 'E31', 'action', 'schedule_reconnect_sms', 'delay', 86400)
                ),
            'sla_seconds', 7200
        ),
        NULL,
        'active',
        'auto'
    )
    ON CONFLICT (workflow_name) DO UPDATE SET
        trigger_type = EXCLUDED.trigger_type,
        trigger_config = EXCLUDED.trigger_config,
        status = 'active';

    -- Workflow 4: token_expired_alert
    INSERT INTO automation_workflows (
        workflow_id, workflow_name, trigger_type, trigger_config,
        candidate_id, status, mode
    ) VALUES (
        gen_random_uuid(),
        'tech_provider_token_expired_alert',
        'social.token.expired',
        jsonb_build_object(
            'description',
                '3 consecutive token refresh failures = candidate offline. Alerts '
                'staff and pings candidate via SMS to reconnect.',
            'actions',
                jsonb_build_array(
                    jsonb_build_object('ecosystem', 'E35', 'action', 'create_urgent_ticket'),
                    jsonb_build_object('ecosystem', 'E31', 'action', 'send_reconnect_urgent_sms')
                ),
            'sla_seconds', 600
        ),
        NULL,
        'active',
        'auto'
    )
    ON CONFLICT (workflow_name) DO UPDATE SET
        trigger_type = EXCLUDED.trigger_type,
        trigger_config = EXCLUDED.trigger_config,
        status = 'active';

    -- Workflow 5: app_health_degraded_pause
    -- App-wide event — affects ALL candidates. Pauses automation platform-wide.
    INSERT INTO automation_workflows (
        workflow_id, workflow_name, trigger_type, trigger_config,
        candidate_id, status, mode
    ) VALUES (
        gen_random_uuid(),
        'tech_provider_app_health_degraded_pause',
        'social.app_health.degraded',
        jsonb_build_object(
            'description',
                'Meta App entered degraded state (rate limit, review status drop, '
                'mass revocation). Pauses Tech Provider automation platform-wide '
                'and alerts master.',
            'actions',
                jsonb_build_array(
                    jsonb_build_object('ecosystem', 'E20', 'action', 'pause_app_wide_automation'),
                    jsonb_build_object('ecosystem', 'E35', 'action', 'create_master_alert')
                ),
            'sla_seconds', 60
        ),
        NULL,
        'active',
        'manual'                                -- Manual mode: master must approve resume
    )
    ON CONFLICT (workflow_name) DO UPDATE SET
        trigger_type = EXCLUDED.trigger_type,
        trigger_config = EXCLUDED.trigger_config,
        status = 'active';

    RAISE NOTICE 'Registered 5 Tech Provider workflows in automation_workflows.';
END;
$register_workflows$;


-- ----------------------------------------------------------------------------
-- SECTION 6: Register Tech Provider event types in intelligence_brain_events
-- ----------------------------------------------------------------------------
-- The Brain reads from intelligence_brain_events for inbound decisions.
-- We don't insert rows here — the Brain inserts when it makes decisions targeted
-- at E19_TECH_PROVIDER. We just verify the table exists for the consumer.

DO $verify_brain_events$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'intelligence_brain_events'
    ) THEN
        RAISE NOTICE 'intelligence_brain_events table not present. Tech Provider '
                     'will rely solely on Redis pub/sub for Brain decisions until '
                     'this table exists. No action needed in this migration.';
    ELSE
        RAISE NOTICE 'intelligence_brain_events table present. Tech Provider will '
                     'read decisions from both Redis and this table.';
    END IF;
END;
$verify_brain_events$;


-- ----------------------------------------------------------------------------
-- SECTION 7: Verification queries
-- ----------------------------------------------------------------------------

DO $verify_registration$
DECLARE
    eco_count INT;
    func_count INT;
    dep_count INT;
BEGIN
    SELECT COUNT(*) INTO eco_count
    FROM brain_control.ecosystems
    WHERE ecosystem_code = 'E19_TECH_PROVIDER';

    IF eco_count != 1 THEN
        RAISE EXCEPTION 'Verification failed: E19_TECH_PROVIDER not registered in brain_control.ecosystems';
    END IF;

    SELECT COUNT(*) INTO func_count
    FROM brain_control.functions
    WHERE ecosystem_code = 'E19_TECH_PROVIDER';

    IF func_count != 4 THEN
        RAISE EXCEPTION 'Verification failed: expected 4 Tech Provider functions, found %', func_count;
    END IF;

    SELECT COUNT(*) INTO dep_count
    FROM brain_control.ecosystem_dependencies
    WHERE ecosystem_code = 'E19_TECH_PROVIDER';

    IF dep_count != 3 THEN
        RAISE EXCEPTION 'Verification failed: expected 3 dependencies, found %', dep_count;
    END IF;

    RAISE NOTICE 'Verification: E19_TECH_PROVIDER fully registered (1 ecosystem, % functions, % deps)',
                 func_count, dep_count;
END;
$verify_registration$;


COMMIT;

-- ============================================================================
-- ROLLBACK (commented for safety; uncomment and run only if rolling back)
-- ============================================================================
-- BEGIN;
--
-- -- Remove workflows (only if automation_workflows exists)
-- DELETE FROM automation_workflows
-- WHERE workflow_name IN (
--     'tech_provider_oauth_completed_welcome',
--     'tech_provider_oauth_failed_assist',
--     'tech_provider_oauth_revoked_reengage',
--     'tech_provider_token_expired_alert',
--     'tech_provider_app_health_degraded_pause'
-- );
--
-- -- Remove function registrations
-- DELETE FROM brain_control.functions
-- WHERE function_code IN ('F901', 'F902', 'F903', 'F904');
--
-- -- Remove dependencies
-- DELETE FROM brain_control.ecosystem_dependencies
-- WHERE ecosystem_code = 'E19_TECH_PROVIDER';
--
-- -- Remove ecosystem
-- DELETE FROM brain_control.ecosystems
-- WHERE ecosystem_code = 'E19_TECH_PROVIDER';
--
-- COMMIT;
-- ============================================================================
-- END OF MIGRATION 103
-- ============================================================================
