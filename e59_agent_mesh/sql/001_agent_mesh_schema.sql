-- =====================================================================
-- BroyhillGOP E59 Agent Mesh System - Complete Schema Migration
-- PostgreSQL/Supabase Database
-- 
-- This schema manages AI agents monitoring 58 ecosystems (E00-E58)
-- on a political CRM platform. Each ecosystem is independent and gets
-- its own dedicated monitoring agent.
-- 
-- Version: 1.0.0
-- Created: 2026-04-11
-- =====================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================================
-- 1. AGENT_REGISTRY - Master list of all agents
-- =====================================================================

CREATE TABLE agent_registry (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ecosystem_id VARCHAR(10) NOT NULL UNIQUE,
  agent_name VARCHAR(255) NOT NULL,
  agent_class VARCHAR(255) NOT NULL COMMENT 'Python class name for agent implementation',
  description TEXT,
  enabled BOOLEAN NOT NULL DEFAULT true,
  priority INT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  check_interval_seconds INT NOT NULL DEFAULT 300 CHECK (check_interval_seconds > 0),
  max_retries INT NOT NULL DEFAULT 3 CHECK (max_retries >= 0),
  timeout_seconds INT NOT NULL DEFAULT 30 CHECK (timeout_seconds > 0),
  status VARCHAR(50) NOT NULL DEFAULT 'initializing'
    CHECK (status IN ('initializing', 'running', 'paused', 'stopped', 'error', 'dead')),
  last_heartbeat TIMESTAMPTZ,
  consecutive_failures INT NOT NULL DEFAULT 0 CHECK (consecutive_failures >= 0),
  config JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT valid_ecosystem_id CHECK (ecosystem_id ~ '^E\d{2}$')
);

CREATE INDEX idx_agent_registry_ecosystem_id ON agent_registry(ecosystem_id);
CREATE INDEX idx_agent_registry_enabled ON agent_registry(enabled);
CREATE INDEX idx_agent_registry_status ON agent_registry(status);
CREATE INDEX idx_agent_registry_priority ON agent_registry(priority);
CREATE INDEX idx_agent_registry_created_at ON agent_registry(created_at DESC);

-- =====================================================================
-- 2. AGENT_RULES - Configurable monitoring rules per ecosystem
-- =====================================================================

CREATE TABLE agent_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL REFERENCES agent_registry(id) ON DELETE CASCADE,
  ecosystem_id VARCHAR(10) NOT NULL,
  rule_name VARCHAR(255) NOT NULL,
  rule_description TEXT,
  rule_category VARCHAR(50) NOT NULL
    CHECK (rule_category IN ('health', 'data_quality', 'performance', 'compliance', 'security', 'cost', 'custom')),
  metric_source VARCHAR(50) NOT NULL
    CHECK (metric_source IN ('supabase_query', 'api_check', 'process_check', 'log_scan', 'custom_function')),
  metric_query TEXT NOT NULL,
  comparison_operator VARCHAR(20) NOT NULL
    CHECK (comparison_operator IN ('gt', 'lt', 'gte', 'lte', 'eq', 'neq', 'contains', 'between', 'regex')),
  threshold_value NUMERIC,
  threshold_value_secondary NUMERIC,
  severity VARCHAR(50) NOT NULL DEFAULT 'warning'
    CHECK (severity IN ('info', 'warning', 'critical', 'emergency')),
  notification_channels TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  enabled BOOLEAN NOT NULL DEFAULT true,
  is_ai_managed BOOLEAN NOT NULL DEFAULT false,
  cooldown_seconds INT NOT NULL DEFAULT 300 CHECK (cooldown_seconds >= 0),
  last_triggered_at TIMESTAMPTZ,
  trigger_count INT NOT NULL DEFAULT 0 CHECK (trigger_count >= 0),
  created_by VARCHAR(50) NOT NULL DEFAULT 'system' CHECK (created_by IN ('user', 'ai', 'system')),
  sort_order INT DEFAULT 0,
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT unique_agent_rule_name UNIQUE (agent_id, rule_name),
  CONSTRAINT valid_threshold CHECK (
    (comparison_operator != 'between') OR 
    (threshold_value IS NOT NULL AND threshold_value_secondary IS NOT NULL)
  )
);

CREATE INDEX idx_agent_rules_agent_id ON agent_rules(agent_id);
CREATE INDEX idx_agent_rules_ecosystem_id ON agent_rules(ecosystem_id);
CREATE INDEX idx_agent_rules_enabled ON agent_rules(enabled);
CREATE INDEX idx_agent_rules_severity ON agent_rules(severity);
CREATE INDEX idx_agent_rules_category ON agent_rules(rule_category);
CREATE INDEX idx_agent_rules_is_ai_managed ON agent_rules(is_ai_managed);
CREATE INDEX idx_agent_rules_created_by ON agent_rules(created_by);
CREATE INDEX idx_agent_rules_tags ON agent_rules USING GIN(tags);
CREATE INDEX idx_agent_rules_last_triggered ON agent_rules(last_triggered_at DESC);
CREATE INDEX idx_agent_rules_composite ON agent_rules(agent_id, enabled, severity);

-- =====================================================================
-- 3. AGENT_RULE_HISTORY - Audit trail for rule changes
-- =====================================================================

CREATE TABLE agent_rule_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rule_id UUID NOT NULL REFERENCES agent_rules(id) ON DELETE CASCADE,
  action VARCHAR(50) NOT NULL
    CHECK (action IN ('created', 'updated', 'deleted', 'enabled', 'disabled')),
  changed_by VARCHAR(255),
  old_values JSONB,
  new_values JSONB,
  reason TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_agent_rule_history_rule_id ON agent_rule_history(rule_id);
CREATE INDEX idx_agent_rule_history_action ON agent_rule_history(action);
CREATE INDEX idx_agent_rule_history_changed_by ON agent_rule_history(changed_by);
CREATE INDEX idx_agent_rule_history_timestamp ON agent_rule_history(timestamp DESC);

-- =====================================================================
-- 4. AGENT_EVENTS - All observations, alerts, anomalies
-- =====================================================================

CREATE TABLE agent_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL REFERENCES agent_registry(id) ON DELETE CASCADE,
  ecosystem_id VARCHAR(10) NOT NULL,
  rule_id UUID REFERENCES agent_rules(id) ON DELETE SET NULL,
  severity VARCHAR(50) NOT NULL
    CHECK (severity IN ('info', 'warning', 'critical', 'emergency')),
  event_type VARCHAR(50) NOT NULL
    CHECK (event_type IN ('alert', 'observation', 'anomaly', 'resolution', 'heartbeat')),
  message TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  acknowledged BOOLEAN NOT NULL DEFAULT false,
  acknowledged_by VARCHAR(255),
  acknowledged_at TIMESTAMPTZ,
  resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT ack_timestamp_check CHECK (
    (acknowledged = false AND acknowledged_at IS NULL) OR 
    (acknowledged = true AND acknowledged_at IS NOT NULL)
  ),
  CONSTRAINT resolved_timestamp_check CHECK (
    (resolved = false AND resolved_at IS NULL) OR 
    (resolved = true AND resolved_at IS NOT NULL)
  )
);

CREATE INDEX idx_agent_events_agent_id ON agent_events(agent_id);
CREATE INDEX idx_agent_events_ecosystem_id ON agent_events(ecosystem_id);
CREATE INDEX idx_agent_events_rule_id ON agent_events(rule_id);
CREATE INDEX idx_agent_events_severity ON agent_events(severity);
CREATE INDEX idx_agent_events_event_type ON agent_events(event_type);
CREATE INDEX idx_agent_events_acknowledged ON agent_events(acknowledged);
CREATE INDEX idx_agent_events_resolved ON agent_events(resolved);
CREATE INDEX idx_agent_events_created_at ON agent_events(created_at DESC);
CREATE INDEX idx_agent_events_composite ON agent_events(ecosystem_id, severity, resolved, created_at DESC);
CREATE INDEX idx_agent_events_unresolved_critical ON agent_events(created_at DESC) 
  WHERE severity = 'critical' AND resolved = false;

-- =====================================================================
-- 5. AGENT_HEARTBEATS - Real-time agent health
-- =====================================================================

CREATE TABLE agent_heartbeats (
  agent_id UUID PRIMARY KEY REFERENCES agent_registry(id) ON DELETE CASCADE,
  ecosystem_id VARCHAR(10) NOT NULL,
  status VARCHAR(50) NOT NULL
    CHECK (status IN ('initializing', 'running', 'paused', 'stopped', 'error', 'dead')),
  last_check TIMESTAMPTZ NOT NULL DEFAULT now(),
  cpu_percent NUMERIC(5,2) CHECK (cpu_percent >= 0 AND cpu_percent <= 100),
  memory_mb NUMERIC(10,2) CHECK (memory_mb >= 0),
  observations_pending INT NOT NULL DEFAULT 0 CHECK (observations_pending >= 0),
  errors_last_hour INT NOT NULL DEFAULT 0 CHECK (errors_last_hour >= 0),
  uptime_seconds BIGINT NOT NULL DEFAULT 0 CHECK (uptime_seconds >= 0),
  version VARCHAR(50),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_agent_heartbeats_status ON agent_heartbeats(status);
CREATE INDEX idx_agent_heartbeats_last_check ON agent_heartbeats(last_check DESC);
CREATE INDEX idx_agent_heartbeats_ecosystem_id ON agent_heartbeats(ecosystem_id);

-- =====================================================================
-- 6. AGENT_METRICS - Time-series performance data
-- =====================================================================

CREATE TABLE agent_metrics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ecosystem_id VARCHAR(10) NOT NULL,
  metric_name VARCHAR(255) NOT NULL,
  metric_value NUMERIC NOT NULL,
  metric_unit VARCHAR(50),
  tags JSONB DEFAULT '{}',
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT valid_ecosystem_id CHECK (ecosystem_id ~ '^E\d{2}$')
);

CREATE INDEX idx_agent_metrics_ecosystem_metric_time ON agent_metrics(ecosystem_id, metric_name, timestamp DESC);
CREATE INDEX idx_agent_metrics_timestamp ON agent_metrics(timestamp DESC);
CREATE INDEX idx_agent_metrics_metric_name ON agent_metrics(metric_name);

-- =====================================================================
-- 7. AGENT_CONTROLS - Toggle switches for ecosystem functions
-- =====================================================================

CREATE TABLE agent_controls (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ecosystem_id VARCHAR(10) NOT NULL,
  control_name VARCHAR(255) NOT NULL,
  control_type VARCHAR(50) NOT NULL
    CHECK (control_type IN ('toggle', 'slider', 'dropdown', 'input')),
  current_value JSONB,
  default_value JSONB,
  description TEXT,
  category VARCHAR(50)
    CHECK (category IS NULL OR category IN ('processing', 'reporting', 'alerts', 'integration')),
  is_locked BOOLEAN NOT NULL DEFAULT false,
  locked_by VARCHAR(255),
  locked_reason TEXT,
  updated_by VARCHAR(255),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT unique_control UNIQUE (ecosystem_id, control_name),
  CONSTRAINT lock_consistency CHECK (
    (is_locked = false AND locked_by IS NULL AND locked_reason IS NULL) OR 
    (is_locked = true AND locked_by IS NOT NULL)
  )
);

CREATE INDEX idx_agent_controls_ecosystem_id ON agent_controls(ecosystem_id);
CREATE INDEX idx_agent_controls_control_name ON agent_controls(control_name);
CREATE INDEX idx_agent_controls_category ON agent_controls(category);
CREATE INDEX idx_agent_controls_is_locked ON agent_controls(is_locked);

-- =====================================================================
-- 8. AGENT_CONTROL_HISTORY - Audit trail for control changes
-- =====================================================================

CREATE TABLE agent_control_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  control_id UUID NOT NULL REFERENCES agent_controls(id) ON DELETE CASCADE,
  old_value JSONB,
  new_value JSONB NOT NULL,
  changed_by VARCHAR(255) NOT NULL,
  reason TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_agent_control_history_control_id ON agent_control_history(control_id);
CREATE INDEX idx_agent_control_history_changed_by ON agent_control_history(changed_by);
CREATE INDEX idx_agent_control_history_timestamp ON agent_control_history(timestamp DESC);

-- =====================================================================
-- 9. AGENT_COST_TRACKING - Cost/benefit per ecosystem
-- =====================================================================

CREATE TABLE agent_cost_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ecosystem_id VARCHAR(10) NOT NULL UNIQUE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  api_calls_count INT NOT NULL DEFAULT 0 CHECK (api_calls_count >= 0),
  api_cost_usd NUMERIC(12,4) NOT NULL DEFAULT 0 CHECK (api_cost_usd >= 0),
  compute_hours NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (compute_hours >= 0),
  compute_cost_usd NUMERIC(12,4) NOT NULL DEFAULT 0 CHECK (compute_cost_usd >= 0),
  storage_gb NUMERIC(10,4) NOT NULL DEFAULT 0 CHECK (storage_gb >= 0),
  storage_cost_usd NUMERIC(12,4) NOT NULL DEFAULT 0 CHECK (storage_cost_usd >= 0),
  credits_consumed NUMERIC NOT NULL DEFAULT 0 CHECK (credits_consumed >= 0),
  credits_cost_usd NUMERIC(12,4) NOT NULL DEFAULT 0 CHECK (credits_cost_usd >= 0),
  total_cost_usd NUMERIC(12,4) NOT NULL DEFAULT 0 CHECK (total_cost_usd >= 0),
  records_processed INT NOT NULL DEFAULT 0 CHECK (records_processed >= 0),
  records_enriched INT NOT NULL DEFAULT 0 CHECK (records_enriched >= 0),
  records_failed INT NOT NULL DEFAULT 0 CHECK (records_failed >= 0),
  cost_per_record NUMERIC(12,6),
  budget_allocated NUMERIC(12,4),
  budget_remaining NUMERIC(12,4),
  variance_pct NUMERIC(8,4),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT valid_period CHECK (period_start <= period_end),
  CONSTRAINT valid_ecosystem_id CHECK (ecosystem_id ~ '^E\d{2}$')
);

CREATE INDEX idx_agent_cost_tracking_ecosystem_id ON agent_cost_tracking(ecosystem_id);
CREATE INDEX idx_agent_cost_tracking_period ON agent_cost_tracking(period_start, period_end);
CREATE INDEX idx_agent_cost_tracking_total_cost ON agent_cost_tracking(total_cost_usd DESC);

-- =====================================================================
-- 10. AGENT_BRAIN_DIRECTIVES - Instructions from E20 Intelligence Brain
-- =====================================================================

CREATE TABLE agent_brain_directives (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_brain_module VARCHAR(50) NOT NULL
    CHECK (source_brain_module IN ('e20_intelligence', 'e21_ml', 'e06_analytics')),
  target_ecosystem_id VARCHAR(10) NOT NULL,
  directive_type VARCHAR(50) NOT NULL
    CHECK (directive_type IN ('adjust_rule', 'toggle_control', 'scale_resources', 'alert_override')),
  directive_payload JSONB NOT NULL DEFAULT '{}',
  priority INT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  status VARCHAR(50) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'executed', 'rejected')),
  requires_human_approval BOOLEAN NOT NULL DEFAULT true,
  approved_by VARCHAR(255),
  executed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT valid_ecosystem_id CHECK (target_ecosystem_id ~ '^E\d{2}$'),
  CONSTRAINT approval_consistency CHECK (
    (status != 'approved' AND approved_by IS NULL) OR 
    (status = 'approved' AND approved_by IS NOT NULL)
  ),
  CONSTRAINT execution_consistency CHECK (
    (status != 'executed' AND executed_at IS NULL) OR 
    (status = 'executed' AND executed_at IS NOT NULL)
  )
);

CREATE INDEX idx_agent_brain_directives_source_module ON agent_brain_directives(source_brain_module);
CREATE INDEX idx_agent_brain_directives_target_ecosystem ON agent_brain_directives(target_ecosystem_id);
CREATE INDEX idx_agent_brain_directives_status ON agent_brain_directives(status);
CREATE INDEX idx_agent_brain_directives_priority ON agent_brain_directives(priority);
CREATE INDEX idx_agent_brain_directives_requires_approval ON agent_brain_directives(requires_human_approval)
  WHERE status = 'pending';
CREATE INDEX idx_agent_brain_directives_created_at ON agent_brain_directives(created_at DESC);

-- =====================================================================
-- HELPER FUNCTIONS
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_agent_health_summary(p_agent_id UUID)
RETURNS TABLE (
  agent_id UUID,
  ecosystem_id VARCHAR,
  agent_name VARCHAR,
  status VARCHAR,
  last_heartbeat TIMESTAMPTZ,
  cpu_percent NUMERIC,
  memory_mb NUMERIC,
  errors_last_hour INT,
  observations_pending INT,
  critical_alerts INT,
  unresolved_count INT,
  last_event_at TIMESTAMPTZ
) AS $$
SELECT 
  ar.id,
  ar.ecosystem_id,
  ar.agent_name,
  ar.status,
  ah.last_check,
  ah.cpu_percent,
  ah.memory_mb,
  ah.errors_last_hour,
  ah.observations_pending,
  COALESCE(
    (SELECT COUNT(*)::INT FROM agent_events 
     WHERE agent_id = ar.id AND severity = 'critical' AND resolved = false),
    0
  ),
  COALESCE(
    (SELECT COUNT(*)::INT FROM agent_events 
     WHERE agent_id = ar.id AND resolved = false),
    0
  ),
  (SELECT created_at FROM agent_events 
   WHERE agent_id = ar.id 
   ORDER BY created_at DESC 
   LIMIT 1)
FROM agent_registry ar
LEFT JOIN agent_heartbeats ah ON ar.id = ah.agent_id
WHERE ar.id = p_agent_id;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION fn_ecosystem_cost_summary(p_ecosystem_id VARCHAR)
RETURNS TABLE (
  ecosystem_id VARCHAR,
  period_start DATE,
  period_end DATE,
  total_cost_usd NUMERIC,
  records_processed INT,
  cost_per_record NUMERIC,
  budget_allocated NUMERIC,
  budget_remaining NUMERIC,
  variance_pct NUMERIC
) AS $$
SELECT 
  ecosystem_id,
  period_start,
  period_end,
  total_cost_usd,
  records_processed,
  cost_per_record,
  budget_allocated,
  budget_remaining,
  variance_pct
FROM agent_cost_tracking
WHERE ecosystem_id = p_ecosystem_id
ORDER BY period_end DESC
LIMIT 1;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION fn_active_alerts_count(p_ecosystem_id VARCHAR DEFAULT NULL)
RETURNS TABLE (
  ecosystem_id VARCHAR,
  severity VARCHAR,
  count INT
) AS $$
SELECT 
  ae.ecosystem_id,
  ae.severity,
  COUNT(*)::INT
FROM agent_events ae
WHERE ae.resolved = false 
  AND ae.event_type IN ('alert', 'anomaly', 'critical')
  AND (p_ecosystem_id IS NULL OR ae.ecosystem_id = p_ecosystem_id)
GROUP BY ae.ecosystem_id, ae.severity
ORDER BY ae.ecosystem_id, ae.severity;
$$ LANGUAGE SQL STABLE;

-- =====================================================================
-- TRIGGER FUNCTIONS
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_log_rule_changes()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO agent_rule_history (rule_id, action, changed_by, old_values, new_values, timestamp)
  VALUES (
    CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
    CASE 
      WHEN TG_OP = 'INSERT' THEN 'created'
      WHEN TG_OP = 'DELETE' THEN 'deleted'
      WHEN TG_OP = 'UPDATE' THEN 
        CASE 
          WHEN OLD.enabled != NEW.enabled THEN (CASE WHEN NEW.enabled THEN 'enabled' ELSE 'disabled' END)
          ELSE 'updated'
        END
    END,
    COALESCE(current_setting('app.current_user', true), 'system'),
    CASE WHEN TG_OP != 'INSERT' THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP != 'DELETE' THEN to_jsonb(NEW) ELSE NULL END,
    now()
  );
  
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_log_control_changes()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO agent_control_history (control_id, old_value, new_value, changed_by, timestamp)
  VALUES (
    CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
    CASE WHEN TG_OP != 'INSERT' THEN OLD.current_value ELSE NULL END,
    CASE WHEN TG_OP != 'DELETE' THEN NEW.current_value ELSE NULL END,
    COALESCE(current_setting('app.current_user', true), 'system'),
    now()
  );
  
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- TRIGGERS
-- =====================================================================

CREATE TRIGGER trig_agent_registry_updated_at
BEFORE UPDATE ON agent_registry
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trig_agent_rules_updated_at
BEFORE UPDATE ON agent_rules
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trig_agent_controls_updated_at
BEFORE UPDATE ON agent_controls
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trig_agent_brain_directives_updated_at
BEFORE UPDATE ON agent_brain_directives
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trig_log_agent_rule_changes
AFTER INSERT OR UPDATE OR DELETE ON agent_rules
FOR EACH ROW EXECUTE FUNCTION fn_log_rule_changes();

CREATE TRIGGER trig_log_control_changes
AFTER INSERT OR UPDATE OR DELETE ON agent_controls
FOR EACH ROW EXECUTE FUNCTION fn_log_control_changes();

-- =====================================================================
-- VIEWS
-- =====================================================================

CREATE OR REPLACE VIEW v_agent_dashboard AS
SELECT 
  ar.id,
  ar.ecosystem_id,
  ar.agent_name,
  ar.agent_class,
  ar.enabled,
  ar.priority,
  ar.status,
  ar.last_heartbeat,
  ar.consecutive_failures,
  ar.created_at,
  ah.cpu_percent,
  ah.memory_mb,
  ah.observations_pending,
  ah.errors_last_hour,
  ah.uptime_seconds,
  ah.version,
  COALESCE(critical_alerts.count, 0) as critical_alert_count,
  COALESCE(warning_alerts.count, 0) as warning_alert_count,
  COALESCE(unresolved_alerts.count, 0) as total_unresolved_alerts,
  COALESCE(active_rules.count, 0) as active_rule_count,
  EXTRACT(EPOCH FROM (now() - ar.last_heartbeat))::INT as seconds_since_heartbeat
FROM agent_registry ar
LEFT JOIN agent_heartbeats ah ON ar.id = ah.agent_id
LEFT JOIN (
  SELECT agent_id, COUNT(*) as count 
  FROM agent_events 
  WHERE severity = 'critical' AND resolved = false
  GROUP BY agent_id
) critical_alerts ON ar.id = critical_alerts.agent_id
LEFT JOIN (
  SELECT agent_id, COUNT(*) as count 
  FROM agent_events 
  WHERE severity = 'warning' AND resolved = false
  GROUP BY agent_id
) warning_alerts ON ar.id = warning_alerts.agent_id
LEFT JOIN (
  SELECT agent_id, COUNT(*) as count 
  FROM agent_events 
  WHERE resolved = false
  GROUP BY agent_id
) unresolved_alerts ON ar.id = unresolved_alerts.agent_id
LEFT JOIN (
  SELECT agent_id, COUNT(*) as count 
  FROM agent_rules 
  WHERE enabled = true
  GROUP BY agent_id
) active_rules ON ar.id = active_rules.agent_id
ORDER BY ar.priority, ar.ecosystem_id;

CREATE OR REPLACE VIEW v_cost_variance_report AS
SELECT 
  ecosystem_id,
  period_start,
  period_end,
  api_calls_count,
  api_cost_usd,
  compute_hours,
  compute_cost_usd,
  storage_gb,
  storage_cost_usd,
  credits_consumed,
  credits_cost_usd,
  total_cost_usd,
  records_processed,
  records_enriched,
  records_failed,
  ROUND(
    CASE 
      WHEN records_processed > 0 THEN cost_per_record
      ELSE 0
    END::NUMERIC, 6
  ) as cost_per_record_calculated,
  budget_allocated,
  budget_remaining,
  ROUND(variance_pct::NUMERIC, 2) as variance_percent,
  CASE 
    WHEN variance_pct > 10 THEN 'over_budget'
    WHEN variance_pct < -10 THEN 'under_budget'
    ELSE 'on_track'
  END as budget_status,
  created_at
FROM agent_cost_tracking
ORDER BY period_end DESC, ecosystem_id;

-- =====================================================================
-- ROW-LEVEL SECURITY POLICIES
-- =====================================================================

ALTER TABLE agent_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_rule_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_heartbeats ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_controls ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_control_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_cost_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_brain_directives ENABLE ROW LEVEL SECURITY;

CREATE POLICY agent_registry_admin ON agent_registry
  FOR ALL USING (auth.jwt_matches_claim('role', 'admin'));

CREATE POLICY agent_rules_admin ON agent_rules
  FOR ALL USING (auth.jwt_matches_claim('role', 'admin'));

CREATE POLICY agent_events_admin ON agent_events
  FOR ALL USING (auth.jwt_matches_claim('role', 'admin'));

CREATE POLICY agent_heartbeats_admin ON agent_heartbeats
  FOR ALL USING (auth.jwt_matches_claim('role', 'admin'));

CREATE POLICY agent_metrics_admin ON agent_metrics
  FOR ALL USING (auth.jwt_matches_claim('role', 'admin'));

CREATE POLICY agent_controls_admin ON agent_controls
  FOR ALL USING (auth.jwt_matches_claim('role', 'admin'));

CREATE POLICY agent_cost_tracking_admin ON agent_cost_tracking
  FOR ALL USING (auth.jwt_matches_claim('role', 'admin'));

CREATE POLICY agent_brain_directives_admin ON agent_brain_directives
  FOR ALL USING (auth.jwt_matches_claim('role', 'admin'));

CREATE POLICY agent_registry_agent_read ON agent_registry
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'agent') OR
    auth.jwt_matches_claim('role', 'admin') OR
    auth.jwt_matches_claim('role', 'viewer')
  );

CREATE POLICY agent_rules_agent_read ON agent_rules
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'agent') OR
    auth.jwt_matches_claim('role', 'admin') OR
    auth.jwt_matches_claim('role', 'viewer')
  );

CREATE POLICY agent_rules_agent_write ON agent_rules
  FOR INSERT WITH CHECK (auth.jwt_matches_claim('role', 'agent'));

CREATE POLICY agent_rules_agent_update ON agent_rules
  FOR UPDATE USING (auth.jwt_matches_claim('role', 'agent'));

CREATE POLICY agent_events_agent_read ON agent_events
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'agent') OR
    auth.jwt_matches_claim('role', 'admin') OR
    auth.jwt_matches_claim('role', 'viewer')
  );

CREATE POLICY agent_events_agent_write ON agent_events
  FOR INSERT WITH CHECK (auth.jwt_matches_claim('role', 'agent'));

CREATE POLICY agent_controls_agent_read ON agent_controls
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'agent') OR
    auth.jwt_matches_claim('role', 'admin') OR
    auth.jwt_matches_claim('role', 'viewer')
  );

CREATE POLICY agent_controls_agent_write ON agent_controls
  FOR INSERT WITH CHECK (auth.jwt_matches_claim('role', 'agent'));

CREATE POLICY agent_controls_agent_update ON agent_controls
  FOR UPDATE USING (auth.jwt_matches_claim('role', 'agent'));

CREATE POLICY agent_registry_viewer ON agent_registry
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'viewer') OR
    auth.jwt_matches_claim('role', 'admin')
  );

CREATE POLICY agent_rules_viewer ON agent_rules
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'viewer') OR
    auth.jwt_matches_claim('role', 'admin')
  );

CREATE POLICY agent_events_viewer ON agent_events
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'viewer') OR
    auth.jwt_matches_claim('role', 'admin')
  );

CREATE POLICY agent_heartbeats_viewer ON agent_heartbeats
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'viewer') OR
    auth.jwt_matches_claim('role', 'admin')
  );

CREATE POLICY agent_metrics_viewer ON agent_metrics
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'viewer') OR
    auth.jwt_matches_claim('role', 'admin')
  );

CREATE POLICY agent_controls_viewer ON agent_controls
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'viewer') OR
    auth.jwt_matches_claim('role', 'admin')
  );

CREATE POLICY agent_cost_tracking_viewer ON agent_cost_tracking
  FOR SELECT USING (
    auth.jwt_matches_claim('role', 'viewer') OR
    auth.jwt_matches_claim('role', 'admin')
  );

-- =====================================================================
-- MIGRATION METADATA
-- =====================================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(255) PRIMARY KEY,
  description TEXT,
  executed_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO schema_migrations (version, description)
VALUES (
  '001_agent_mesh_schema',
  'Initial schema for BroyhillGOP E59 Agent Mesh system with 10 core tables, helper functions, triggers, views, and RLS policies'
);

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================
