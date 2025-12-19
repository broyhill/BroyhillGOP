-- ============================================================================
-- BRAIN CONTROL SYSTEM - MASTER SCHEMA INITIALIZATION
-- ============================================================================
-- BroyhillGOP Central AI & Automation Command Platform
-- Version: 2.0 | November 29, 2025
-- 
-- This is the master initialization script that creates the complete
-- BRAIN Control System database infrastructure.
--
-- EXECUTION ORDER:
-- 1. 001_brain_core_schema.sql      - Core tables, ecosystems, functions
-- 2. 002_brain_cost_accounting.sql  - Cost/benefit tracking & bookkeeping
-- 3. 003_brain_ai_governance.sql    - AI models, prompts, usage tracking
-- 4. 004_brain_self_correction.sql  - Self-correction engine & quality
-- 5. 005_brain_alerts.sql           - Alerts & notifications
-- 6. 006_brain_vendors.sql          - Vendor management & health
-- 7. 007_brain_crm.sql              - CRM integration & sync
-- 8. 008_brain_recovery.sql         - Crash detection & recovery
-- 9. 009_brain_campaigns.sql        - Campaign management integration
-- 10. 010_brain_views.sql           - Reporting views & dashboards
-- 11. 011_brain_functions.sql       - Stored procedures & triggers
-- 12. 012_brain_seed_data.sql       - Initial configuration data
-- ============================================================================

-- Create the schema
DROP SCHEMA IF EXISTS brain_control CASCADE;
CREATE SCHEMA brain_control;

-- Set search path
SET search_path TO brain_control, public;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- SCHEMA METADATA
-- ============================================================================

CREATE TABLE schema_info (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO schema_info (key, value) VALUES
('version', '2.0.0'),
('created_at', NOW()::TEXT),
('platform', 'BroyhillGOP'),
('description', 'BRAIN Control System - Central AI & Automation Command Platform'),
('ecosystems_count', '16'),
('vendors_count', '18'),
('functions_count', '35');

-- ============================================================================
-- ENUMERATED TYPES
-- ============================================================================

-- Ecosystem status
CREATE TYPE ecosystem_status AS ENUM (
    'ACTIVE',
    'DEGRADED', 
    'MAINTENANCE',
    'OFFLINE',
    'CRASHED',
    'RECOVERING'
);

-- Alert severity
CREATE TYPE alert_severity AS ENUM (
    'CRITICAL',
    'HIGH',
    'MEDIUM',
    'LOW',
    'INFO'
);

-- Variance status
CREATE TYPE variance_status AS ENUM (
    'green',
    'yellow',
    'orange',
    'red',
    'critical'
);

-- Correction action types
CREATE TYPE correction_action AS ENUM (
    'model_downgrade',
    'model_upgrade',
    'batch_increase',
    'batch_decrease',
    'cache_enable',
    'cache_disable',
    'rate_limit_adjust',
    'prompt_simplify',
    'retry_strategy',
    'parallel_scale',
    'circuit_breaker',
    'failover',
    'restart'
);

-- Vendor types
CREATE TYPE vendor_type AS ENUM (
    'ai',
    'data_enrichment',
    'payment',
    'communication',
    'crm',
    'analytics',
    'government',
    'media'
);

-- CRM sync direction
CREATE TYPE sync_direction AS ENUM (
    'to_crm',
    'from_crm',
    'bidirectional'
);

-- Cost types
CREATE TYPE cost_type AS ENUM (
    'per_call',
    'per_record',
    'per_transaction',
    'per_email',
    'per_match',
    'per_campaign',
    'per_event',
    'per_report',
    'per_model',
    'per_query',
    'per_import',
    'per_update',
    'per_check',
    'per_correction',
    'per_alert',
    'per_recovery',
    'per_analysis',
    'per_recommendation',
    'per_prediction',
    'per_test',
    'per_receipt',
    'per_activity',
    'per_lookup',
    'per_map',
    'flat_monthly'
);

-- Criticality levels
CREATE TYPE criticality_level AS ENUM (
    'CRITICAL',
    'HIGH',
    'MEDIUM',
    'LOW'
);

COMMENT ON SCHEMA brain_control IS 'BRAIN Control System - Central AI & Automation Command Platform';
