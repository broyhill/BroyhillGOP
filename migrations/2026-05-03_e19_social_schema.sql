-- =============================================================================
-- E19 Social Media Stealth Machine — DDL
-- =============================================================================
-- Migration ID:    2026-05-03_e19_social_schema
-- Created:         2026-05-03
-- Author:          Claude (Cowork session, Opus 4.7)
-- Branch:          claude/section-12-e19-stealth-machine-2026-05-03
-- Authorization:   REQUIRED — Ed must type `I AUTHORIZE THIS ACTION` before
--                  applying. Per RULES.md, no DDL changes without explicit
--                  authorization. THIS FILE WILL NOT EXECUTE on push.
-- Safety:          ADDITIVE ONLY. Does NOT touch raw.ncboe_donations or any
--                  core.donor_profile* table or view.
-- Rollback:        See block at end of file.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Extend social_posts (existing table) with funnel-stage tagging columns.
--    All ALTERs are IF NOT EXISTS so the migration is idempotent.
-- ---------------------------------------------------------------------------

ALTER TABLE social_posts
    ADD COLUMN IF NOT EXISTS content_stage         VARCHAR(32);

ALTER TABLE social_posts
    ADD COLUMN IF NOT EXISTS funnel_stage_targets  JSONB        DEFAULT '[]'::jsonb;

ALTER TABLE social_posts
    ADD COLUMN IF NOT EXISTS variant_id            UUID;

ALTER TABLE social_posts
    ADD COLUMN IF NOT EXISTS parent_brief_id       UUID;

COMMENT ON COLUMN social_posts.content_stage IS
    'E19 funnel content tag — see docs/architecture/E19_FUNNEL_STAGES.md §3. '
    'Single value (lowest stage the asset is appropriate for).';
COMMENT ON COLUMN social_posts.funnel_stage_targets IS
    'JSONB array of FunnelStage values this asset is optimized for. '
    'Ordered by relevance.';
COMMENT ON COLUMN social_posts.variant_id IS
    'FK to e19_variant_outcomes.variant_id when this post is one of a multi-variant test.';
COMMENT ON COLUMN social_posts.parent_brief_id IS
    'Groups variants generated from the same content brief.';

CREATE INDEX IF NOT EXISTS idx_social_posts_content_stage
    ON social_posts (content_stage);

CREATE INDEX IF NOT EXISTS idx_social_posts_variant_id
    ON social_posts (variant_id) WHERE variant_id IS NOT NULL;


-- ---------------------------------------------------------------------------
-- 2. core.e19_variant_outcomes — variant performance ledger.
--    Per-signal observations for the future ML ranker. Append-only.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.e19_variant_outcomes (
    outcome_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_id      UUID         NOT NULL,
    platform        VARCHAR(32)  NOT NULL,
    signal_type     VARCHAR(64)  NOT NULL
                                 CHECK (signal_type IN (
                                     'save_rate', 'share_rate',
                                     'comment_rate', 'watch_time',
                                     'scroll_stop', 'profile_visit_after_view',
                                     'click_rate', 'conversion_rate'
                                 )),
    signal_value    NUMERIC(10,4) NOT NULL,
    recorded_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE core.e19_variant_outcomes IS
    'E19 variant performance observations. Append-only. Feeds the ML ranker '
    'training pipeline (not yet built — see ADR 2026-05-03).';

CREATE INDEX IF NOT EXISTS idx_e19_variant_outcomes_variant
    ON core.e19_variant_outcomes (variant_id);
CREATE INDEX IF NOT EXISTS idx_e19_variant_outcomes_platform_signal
    ON core.e19_variant_outcomes (platform, signal_type, recorded_at DESC);


-- ---------------------------------------------------------------------------
-- 3. core.e19_audiences — custom + lookalike audience registry.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.e19_audiences (
    audience_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id       UUID         NOT NULL,
    audience_type      VARCHAR(64)  NOT NULL
                                    CHECK (audience_type IN (
                                        'donor_list', 'web_visitors',
                                        'email_engagers', 'sms_engagers',
                                        'lookalike', 'manual_upload'
                                    )),
    source_filter      JSONB        NOT NULL,
    rnc_regid_count    INTEGER      NOT NULL CHECK (rnc_regid_count >= 0),
    match_tier_filter  VARCHAR(64)  NOT NULL DEFAULT 'A_EXACT,B_ALIAS',
    platform_uploads   JSONB        NOT NULL DEFAULT '{}'::jsonb,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by         TEXT
);

COMMENT ON TABLE core.e19_audiences IS
    'E19 custom + lookalike audience registry. platform_uploads carries the '
    'per-platform upload IDs returned by Meta/Google/X/TikTok APIs.';

CREATE INDEX IF NOT EXISTS idx_e19_audiences_candidate
    ON core.e19_audiences (candidate_id);
CREATE INDEX IF NOT EXISTS idx_e19_audiences_type
    ON core.e19_audiences (audience_type);


-- ---------------------------------------------------------------------------
-- 4. core.e19_donor_funnel — current funnel stage per donor per candidate.
--    UPSERT pattern: one row per (rnc_regid, candidate_id).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.e19_donor_funnel (
    rnc_regid           UUID         NOT NULL,
    candidate_id        UUID         NOT NULL,
    funnel_stage        VARCHAR(32)  NOT NULL
                                     CHECK (funnel_stage IN (
                                         'STRANGER', 'AWARE', 'ENGAGED',
                                         'SUBSCRIBER', 'SMALL_DONOR',
                                         'REPEAT_DONOR', 'BUNDLER'
                                     )),
    stage_entered_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_evaluated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (rnc_regid, candidate_id)
);

COMMENT ON TABLE core.e19_donor_funnel IS
    'Current E19 funnel stage per donor per candidate. Updated by the nightly '
    're-evaluation job. See docs/architecture/E19_FUNNEL_STAGES.md §1, §2.';

CREATE INDEX IF NOT EXISTS idx_e19_funnel_candidate_stage
    ON core.e19_donor_funnel (candidate_id, funnel_stage);


-- ---------------------------------------------------------------------------
-- 5. core.e19_inbox — inbound message ingestion + AI draft + approval state.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.e19_inbox (
    inbox_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    platform          VARCHAR(32)  NOT NULL,
    source_type       VARCHAR(32)  NOT NULL
                                   CHECK (source_type IN (
                                       'comment', 'mention', 'quote', 'dm', 'reply'
                                   )),
    source_user_id    VARCHAR(255),
    rnc_regid         UUID,
    content           TEXT         NOT NULL,
    sentiment         VARCHAR(16)  CHECK (sentiment IN ('pos', 'neg', 'neutral')),
    intent            VARCHAR(32)  CHECK (intent IN (
                                       'question', 'complaint', 'praise',
                                       'hostile', 'spam', 'press', 'donation_intent'
                                   )),
    urgency           VARCHAR(16)  CHECK (urgency IN ('low', 'med', 'high')),
    ai_draft_reply    TEXT,
    approval_status   VARCHAR(32)  NOT NULL DEFAULT 'pending'
                                   CHECK (approval_status IN (
                                       'pending', 'approved', 'rejected',
                                       'auto_approved', 'expired'
                                   )),
    approved_by       UUID,
    fired_at          TIMESTAMPTZ,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE core.e19_inbox IS
    'E19 listening inbox. Every inbound comment / mention / quote / DM lands '
    'here. Classifier fills sentiment/intent/urgency. AI drafts reply. E24 '
    'approval queue routing happens via approval_status state machine.';

CREATE INDEX IF NOT EXISTS idx_e19_inbox_platform_status
    ON core.e19_inbox (platform, approval_status);
CREATE INDEX IF NOT EXISTS idx_e19_inbox_rnc_regid
    ON core.e19_inbox (rnc_regid) WHERE rnc_regid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_e19_inbox_created
    ON core.e19_inbox (created_at DESC);


-- ---------------------------------------------------------------------------
-- 6. core.compliance_audit — extended/created.
--    The paper trail for every gate decision across every Brain ecosystem.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.compliance_audit (
    audit_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    source_ecosystem  VARCHAR(16)  NOT NULL,
    gate_name         VARCHAR(64)  NOT NULL,
    decision          VARCHAR(16)  NOT NULL CHECK (decision IN ('allow', 'block')),
    reason            TEXT,
    context           JSONB        NOT NULL DEFAULT '{}'::jsonb,
    evaluated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE core.compliance_audit IS
    'Cross-ecosystem compliance gate audit log. Every gate decision (allow or '
    'block) is appended here. Source of truth for FEC inquiries, platform '
    'policy disputes, and internal post-mortems. Partitioning by month is '
    'backlog''d when rate exceeds ~50K rows/day.';

CREATE INDEX IF NOT EXISTS idx_compliance_audit_eco_time
    ON core.compliance_audit (source_ecosystem, evaluated_at DESC);
CREATE INDEX IF NOT EXISTS idx_compliance_audit_gate_decision
    ON core.compliance_audit (gate_name, decision);


COMMIT;

-- =============================================================================
-- ROLLBACK PLAN (run only if absolutely necessary)
-- =============================================================================
-- BEGIN;
--   DROP TABLE IF EXISTS core.e19_inbox;
--   DROP TABLE IF EXISTS core.e19_donor_funnel;
--   DROP TABLE IF EXISTS core.e19_audiences;
--   DROP TABLE IF EXISTS core.e19_variant_outcomes;
--   -- DO NOT drop core.compliance_audit if it pre-existed in any form;
--   -- it is shared across ecosystems. Drop only if THIS migration created it.
--   ALTER TABLE social_posts DROP COLUMN IF EXISTS parent_brief_id;
--   ALTER TABLE social_posts DROP COLUMN IF EXISTS variant_id;
--   ALTER TABLE social_posts DROP COLUMN IF EXISTS funnel_stage_targets;
--   ALTER TABLE social_posts DROP COLUMN IF EXISTS content_stage;
-- COMMIT;
-- =============================================================================
