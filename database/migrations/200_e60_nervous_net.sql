-- =============================================================================
-- E60 NERVOUS NET — DDL for cost_ledger + iftt_rules + iftt_rule_fires
-- =============================================================================
-- Migration ID:  200
-- Created:       2026-05-02
-- Author:        Claude (Cowork session, Opus 4.7)
-- Authorized:    REQUIRED — Ed must type `I AUTHORIZE THIS ACTION` before
--                applying this migration. Per RULES.md, no DDL changes
--                without explicit authorization.
-- Safety:        ADDITIVE ONLY. Does NOT touch raw.ncboe_donations or any
--                core.donor_profile* table or view. Three brand-new tables
--                in the `core` schema.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. core.cost_ledger — universal CostEvent persistence
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.cost_ledger (
    event_id                  TEXT         PRIMARY KEY,
    source_ecosystem          TEXT         NOT NULL,
    donor_id                  TEXT,
    cost_type                 TEXT         NOT NULL,
    vendor                    TEXT         NOT NULL,
    unit_cost_cents           INTEGER      NOT NULL CHECK (unit_cost_cents >= 0),
    quantity                  INTEGER      NOT NULL CHECK (quantity >= 1),
    total_cost_cents          INTEGER      NOT NULL CHECK (total_cost_cents >= 0),
    revenue_attributed_cents  INTEGER      NOT NULL DEFAULT 0,
    occurred_at               TIMESTAMPTZ  NOT NULL,
    created_at                TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS cost_ledger_source_ecosystem_idx
    ON core.cost_ledger(source_ecosystem);
CREATE INDEX IF NOT EXISTS cost_ledger_donor_id_idx
    ON core.cost_ledger(donor_id) WHERE donor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS cost_ledger_occurred_at_idx
    ON core.cost_ledger(occurred_at);

COMMENT ON TABLE core.cost_ledger IS
    'E60 Nervous Net cost ledger. Every Brain module emits a CostEvent here '
    'on every spend event. Idempotent on event_id. See E60 cost_ledger.py.';

-- ---------------------------------------------------------------------------
-- 2. core.iftt_rules — rule definitions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.iftt_rules (
    rule_id           TEXT         PRIMARY KEY,
    name              TEXT         NOT NULL,
    condition_sql     TEXT         NOT NULL,
    action_payload    JSONB        NOT NULL,
    target_ecosystem  TEXT         NOT NULL,
    enabled           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_by        TEXT,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE core.iftt_rules IS
    'E60 Nervous Net IFTTT rule registry. condition_sql is a SQL boolean '
    'expression; action_payload is a JSONB template for the RuleFired '
    'payload sent to target_ecosystem.';

-- ---------------------------------------------------------------------------
-- 3. core.iftt_rule_fires — audit log of every rule fire
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.iftt_rule_fires (
    fire_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id           TEXT         NOT NULL REFERENCES core.iftt_rules(rule_id),
    fired_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    target_payload    JSONB        NOT NULL,
    outcome           TEXT
);

CREATE INDEX IF NOT EXISTS iftt_rule_fires_rule_id_idx
    ON core.iftt_rule_fires(rule_id);
CREATE INDEX IF NOT EXISTS iftt_rule_fires_fired_at_idx
    ON core.iftt_rule_fires(fired_at);

COMMENT ON TABLE core.iftt_rule_fires IS
    'E60 Nervous Net audit log. Every RuleFired payload sent to another '
    'ecosystem is persisted here. audit_trail_id in RuleFired = fire_id here.';

-- ---------------------------------------------------------------------------
-- 4. Seed the 4 mandated IFTTT rules (idempotent)
-- ---------------------------------------------------------------------------
INSERT INTO core.iftt_rules
    (rule_id, name, condition_sql, action_payload, target_ecosystem, enabled, created_by)
VALUES
    ('hard_bounce_suppress_and_regrade',
     'Hard bounce: suppress + ask E01 to re-grade',
     E'bounce_type = ''hard''',
     '{"action":"add_to_suppression","reason":"hard_bounce"}'::jsonb,
     'E30', TRUE, 'claude_cowork_2026_05_02'),
    ('high_confidence_cluster_recommend',
     'High-confidence cross-spine match: recommend rnc_regid stamp',
     E'cross_spine_match_confidence > 0.95',
     '{"action":"recommend_rnc_regid_stamp"}'::jsonb,
     'E01', TRUE, 'claude_cowork_2026_05_02'),
    ('low_match_tier_block_outbound',
     'Low match tier: block outbound on all electronic channels',
     E'match_tier IN (''E_WRONG_LAST'', ''UNMATCHED'')',
     '{"action":"add_to_suppression","reason":"low_match_tier"}'::jsonb,
     'E30', TRUE, 'claude_cowork_2026_05_02'),
    ('daily_budget_breach_pause_sends',
     'Daily budget exceeded: pause E30 and E31 sends',
     E'daily_burn_cents > daily_cap_cents',
     '{"action":"pause_sends"}'::jsonb,
     'E30', TRUE, 'claude_cowork_2026_05_02')
ON CONFLICT (rule_id) DO NOTHING;

COMMIT;

-- =============================================================================
-- ROLLBACK PLAN (if needed):
--   BEGIN;
--   DROP TABLE IF EXISTS core.iftt_rule_fires;
--   DROP TABLE IF EXISTS core.iftt_rules;
--   DROP TABLE IF EXISTS core.cost_ledger;
--   COMMIT;
-- =============================================================================
