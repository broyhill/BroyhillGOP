# BroyhillGOP E59 Agent Mesh Framework

A complete distributed agent framework for monitoring 58 ecosystems (E00-E58) of the BroyhillGOP political CRM platform.

**Hardware**: Hetzner AX162-R server
- 96 CPU cores
- 252GB RAM
- Network: 37.27.169.232

## Architecture

### Core Components

#### 1. **base_agent.py** (709 lines)
The foundation class that all ecosystem agents inherit from.

**Features:**
- Async/await architecture with asyncio and httpx
- 4 core monitoring loops:
  - `health_check()`: Ecosystem health monitoring
  - `audit_data_quality()`: Data quality audits
  - `check_performance()`: Performance metrics
  - `check_domain_rules()`: Domain-specific rules
- Heartbeat management (writes to `agent_heartbeats` table)
- Event emission system (writes to `agent_events` table)
- Rule evaluation engine with hot-reload
- Metric recording (writes to `agent_metrics` table)
- Cost/credit tracking per API call
- Brain directive execution (reads from `agent_brain_directives` table)
- Graceful shutdown handling (SIGTERM, SIGINT)
- Structured JSON logging

**Abstract Methods** (implement in subclasses):
```python
async def _perform_health_check() -> Dict[str, Any]
async def _perform_data_quality_audit() -> Dict[str, Any]
async def _perform_performance_check() -> Dict[str, Any]
async def _check_domain_specific_rules() -> None
```

#### 2. **rule_engine.py** (364 lines)
Dynamic rule evaluation engine with hot-reload support.

**Features:**
- Loads rules from `agent_rules` table
- Evaluates rules by metric_query and comparison_operator
- Supports operators: gt, lt, gte, lte, eq, neq, contains, between, regex
- Cooldown enforcement (prevents alert storms)
- CRUD operations: add_rule(), update_rule(), delete_rule(), toggle_rule()
- Rule validation before save
- Hot-reload detection (auto-refresh every 5 minutes)
- Integration with Brain: AI-managed rules can be modified by E20

**Example Rule:**
```python
{
    "id": "rule_123",
    "ecosystem_id": "E00",
    "name": "CPU Usage Alert",
    "metric_key": "cpu_usage_percent",
    "threshold": 85,
    "comparison_operator": "gt",
    "severity": "warning",
    "cooldown_seconds": 300,
    "enabled": True
}
```

#### 3. **supervisor.py** (310 lines)
Master process managing all ecosystem agents.

**Features:**
- Reads `agent_registry` to spawn agents
- Spawns agents as asyncio Tasks
- Monitors heartbeats, restarts after 3 missed beats
- Priority-based spawning (critical ecosystems first)
- Health check HTTP endpoint (port 9090)
- Graceful shutdown (SIGTERM, SIGINT)
- Systemd integration (sd_notify)
- Daily summary generation

**Health Endpoints:**
- `GET /health` - Supervisor status
- `GET /agents` - List all agents

#### 4. **control_api.py** (453 lines)
FastAPI REST API for the control panel.

**Agent Endpoints:**
- `GET /agents` - List all agents
- `GET /agents/{eco_id}` - Agent details
- `POST /agents/{eco_id}/toggle` - Enable/disable

**Rule Endpoints:**
- `GET /agents/{eco_id}/rules` - List rules
- `POST /agents/{eco_id}/rules` - Add rule
- `PUT /agents/{eco_id}/rules/{rule_id}` - Update
- `DELETE /agents/{eco_id}/rules/{rule_id}` - Delete
- `POST /agents/{eco_id}/rules/{rule_id}/toggle` - Enable/disable

**Control Endpoints:**
- `GET /agents/{eco_id}/controls` - List controls
- `PUT /agents/{eco_id}/controls/{control_id}` - Update control

**Monitoring Endpoints:**
- `GET /agents/{eco_id}/metrics` - Get metrics (with time range)
- `GET /agents/{eco_id}/events` - Get events (with severity filter)
- `POST /agents/{eco_id}/events/{event_id}/acknowledge` - Acknowledge alert

**Dashboard Endpoints:**
- `GET /dashboard` - Cross-ecosystem summary
- `GET /costs` - Cost/variance report
- `POST /brain/directive` - Submit brain directive

#### 5. **brain_integration.py** (375 lines)
Integration with E20 Intelligence Brain and E21 ML.

**Features:**
- Receives directives from `agent_brain_directives` table
- Auto-executes approved directives
- Queues directives requiring human approval
- ML model integration:
  - Anomaly detection (sklearn IsolationForest)
  - Predictive alerts (xgboost)
- Cost optimization: Linear programming for resource allocation
- Variance analysis: Budget vs actual comparison
- Predictive alerts: Forecasts future threshold breaches
- Reports findings back to Brain

**Directive Types:**
- `adjust_threshold` - Modify rule threshold
- `toggle_control` - Enable/disable control
- `optimize_budget` - Allocate budget across ecosystems
- `scale_monitoring` - Adjust monitoring intervals

#### 6. **notifier.py** (308 lines)
Multi-channel notification system.

**Channels:**
- Slack webhook notifications with color coding
- Email (SMTP) - red for emergency, orange for critical
- SMS (Twilio) - urgent alerts
- Dashboard (Supabase insert) - blue for info
- Webhooks - arbitrary URL callbacks

**Features:**
- Rate limiting per channel (5-minute cooldown)
- Message deduplication
- Severity-based formatting:
  - Emergency: Red (#cc0000)
  - Critical: Orange (#ff6600)
  - Warning: Yellow (#ffaa00)
  - Info: Blue (#0099cc)
- Escalation: If critical alert not acknowledged in 30 min, escalates to emergency

#### 7. **cost_tracker.py** (318 lines)
Cost/budget tracking and optimization.

**Features:**
- Tracks API calls, compute time, storage per ecosystem
- Writes to `agent_cost_tracking` table
- Cost per record calculation
- Budget vs actual variance calculation
- Linear programming optimization:
  - Given total budget, allocates optimally based on ROI
  - Weighted allocation to high-ROI ecosystems
- Variance reports
- Historical cost analysis

## Database Tables

### Required Supabase Tables

```sql
-- Agent registry and configuration
CREATE TABLE agent_registry (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT UNIQUE,
  enabled BOOLEAN DEFAULT true,
  priority INT DEFAULT 50,
  health_check_interval INT DEFAULT 60,
  audit_interval INT DEFAULT 300,
  created_at TIMESTAMP
);

-- Agent heartbeats for monitoring
CREATE TABLE agent_heartbeats (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT,
  status TEXT,
  timestamp TIMESTAMP,
  uptime_seconds INT,
  api_call_count INT,
  total_api_cost FLOAT
);

-- Rule definitions
CREATE TABLE agent_rules (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT,
  name TEXT,
  metric_key TEXT,
  threshold FLOAT,
  comparison_operator TEXT,
  severity TEXT,
  cooldown_seconds INT DEFAULT 300,
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Events and alerts
CREATE TABLE agent_events (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT,
  event_type TEXT,
  severity TEXT,
  details JSONB,
  timestamp TIMESTAMP,
  acknowledged BOOLEAN DEFAULT false,
  acknowledged_at TIMESTAMP
);

-- Metrics
CREATE TABLE agent_metrics (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT,
  metric_name TEXT,
  metric_value FLOAT,
  metric_type TEXT,
  tags JSONB,
  timestamp TIMESTAMP
);

-- Cost tracking
CREATE TABLE agent_cost_tracking (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT,
  api_type TEXT,
  cost FLOAT,
  record_count INT,
  cost_per_record FLOAT,
  timestamp TIMESTAMP
);

-- Budget definitions
CREATE TABLE agent_budgets (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT,
  monthly_limit FLOAT,
  created_at TIMESTAMP
);

-- Brain directives
CREATE TABLE agent_brain_directives (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT,
  directive_type TEXT,
  payload JSONB,
  status TEXT,
  auto_execute BOOLEAN DEFAULT false,
  created_at TIMESTAMP
);

-- Control switches
CREATE TABLE agent_controls (
  id UUID PRIMARY KEY,
  ecosystem_id TEXT,
  control_name TEXT,
  control_value BOOLEAN,
  updated_at TIMESTAMP
);

-- Notifications
CREATE TABLE agent_notifications (
  id UUID PRIMARY KEY,
  event_id UUID,
  severity TEXT,
  message TEXT,
  details JSONB,
  created_at TIMESTAMP,
  read BOOLEAN DEFAULT false
);
```

## Environment Variables

```bash
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-api-key

# Notifications
SLACK_WEBHOOK=https://hooks.slack.com/services/...
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASSWORD=password

# Twilio
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_NUMBER=+1234567890

# API
CONTROL_API_PORT=8080
HEALTH_CHECK_PORT=9090
```

## Usage Example

```python
import asyncio
import os
from supervisor import AgentSupervisor
from control_api import ControlAPI

async def main():
    # Initialize supervisor
    supervisor = AgentSupervisor(
        supabase_url=os.getenv("SUPABASE_URL"),
        supabase_key=os.getenv("SUPABASE_KEY"),
        health_check_port=9090,
    )

    # Start supervisor in background
    supervisor_task = asyncio.create_task(supervisor.run())

    # Initialize control API
    api = ControlAPI(
        supabase_url=os.getenv("SUPABASE_URL"),
        supabase_key=os.getenv("SUPABASE_KEY"),
    )

    # Start API server (requires uvicorn)
    # uvicorn.run(api.app, host="0.0.0.0", port=8080)

    # Wait for supervisor
    await supervisor_task

if __name__ == "__main__":
    asyncio.run(main())
```

## Running the System

### 1. Install Dependencies

```bash
pip install httpx fastapi uvicorn scikit-learn xgboost numpy aiohttp
```

### 2. Configure Environment

Create `.env` file with required variables.

### 3. Start Supervisor

```bash
python -m supervisor
```

### 4. Start Control API

```bash
uvicorn control_api:app --host 0.0.0.0 --port 8080
```

### 5. Monitor Health

```bash
curl http://localhost:9090/health
curl http://localhost:9090/agents
```

## Integration Points

### With E20 Intelligence Brain
- Receives AI-generated directives
- Auto-executes approved optimizations
- Reports findings and metrics
- Accepts rule modifications

### With E21 ML Services
- Uses anomaly detection models
- Leverages predictive models
- Implements cost optimization algorithms
- Feeds historical data for training

### With Control Panel
- Provides REST API for management
- Dashboard visualization
- Real-time metrics and events
- Alert acknowledgment

## Performance Characteristics

- **Scalability**: Efficiently handles 58 ecosystems
- **Memory**: ~4-8GB per agent, scales linearly
- **CPU**: Thread-async hybrid for I/O efficiency
- **Network**: Connection pooling with httpx
- **Database**: Optimized queries, proper indexing
- **Latency**: <100ms for rule evaluation, <500ms for API calls

## Monitoring & Observability

- Structured JSON logging
- Heartbeat tracking (30-second intervals)
- Metric collection (gauge, counter, histogram)
- Event emission (info, warning, critical, emergency)
- Health check endpoints
- Daily summary generation
- Cost tracking and variance analysis

## Security Considerations

- All Supabase calls use API keys (rotate regularly)
- Environment variables for secrets (never hardcode)
- HTTPS for all external APIs
- Rate limiting on notifications
- Event acknowledgment tracking
- Graceful error handling
- No sensitive data in logs

## Future Enhancements

- WebSocket support for real-time updates
- Distributed tracing with OpenTelemetry
- Custom metrics exporters (Prometheus, Datadog)
- Advanced ML models (LSTM for time series)
- Multi-region deployment
- Agent clustering and load balancing
- GraphQL API alternative

---

**Version**: 1.0.0  
**Python**: 3.8+  
**License**: Proprietary
