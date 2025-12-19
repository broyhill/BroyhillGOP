# NEXUS Deployment Guide
## BroyhillGOP Platform Integration

---

## Quick Start

```bash
# 1. Clone and navigate
git clone https://github.com/broyhillgop/platform.git
cd platform/nexus

# 2. Configure environment
cp .env.example .env
# Edit .env with your credentials

# 3. Run migrations
./deploy.sh migrate

# 4. Verify deployment
./deploy.sh verify
```

---

## Prerequisites

### Required
- PostgreSQL 15+ (Supabase)
- Python 3.11+
- Node.js 20+ (for TypeScript)
- Anthropic API key

### Existing Platform
NEXUS requires these existing schemas:
- `brain_control` - Brain Control system
- `intelligence_brain` - Intelligence Brain decisions
- `public` - Core platform tables (donors, volunteers, candidates, etc.)

---

## File Structure

```
nexus/
├── migrations/
│   ├── 001_NEXUS_SOCIAL_EXTENSION.sql      # Core schema
│   ├── 002_NEXUS_HARVEST_ENRICHMENT.sql    # Enrichment config
│   └── 003_NEXUS_PLATFORM_INTEGRATION.sql  # Brain integration
├── engines/
│   ├── nexus_brain_engine.py               # GO/NO-GO decisions
│   ├── nexus_persona_engine.py             # Voice matching
│   └── nexus_harvest_engine.py             # Harvest processing
├── types/
│   └── nexus.types.ts                      # TypeScript definitions
├── .github/
│   └── workflows/
│       └── deploy-nexus.yml                # CI/CD workflow
├── ecosystem_nexus_complete.py             # Complete ecosystem
├── deploy.sh                               # Deployment script
├── .env.example                            # Environment template
└── README.md                               # Documentation
```

---

## Deployment Steps

### Step 1: Database Migrations

Run migrations **in order**:

```bash
# Using Supabase CLI
supabase db push

# Or manually
psql $DATABASE_URL -f migrations/001_NEXUS_SOCIAL_EXTENSION.sql
psql $DATABASE_URL -f migrations/002_NEXUS_HARVEST_ENRICHMENT.sql
psql $DATABASE_URL -f migrations/003_NEXUS_PLATFORM_INTEGRATION.sql
```

**What gets created:**

| Migration | Tables | Views | Functions |
|-----------|--------|-------|-----------|
| 001 | 9 new, 4 extended | 10 | 4 |
| 002 | 2 | 2 | 3 |
| 003 | 8 | 6 | 3 |

### Step 2: Python Environment

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or: venv\Scripts\activate  # Windows

# Install dependencies
pip install psycopg2-binary anthropic requests

# Verify installation
python -c "from engines.nexus_brain_engine import NexusBrainEngine; print('✅ OK')"
```

### Step 3: Environment Configuration

```bash
# Copy template
cp .env.example .env

# Required variables:
DATABASE_URL=postgresql://...
ANTHROPIC_API_KEY=sk-ant-...
```

### Step 4: Verify Deployment

```bash
# Run verification script
./deploy.sh verify

# Or manually check:
psql $DATABASE_URL -c "SELECT * FROM v_nexus_executive_dashboard;"
```

---

## Integration with Existing Platform

### Brain Control Registration

NEXUS auto-registers in `brain_control.ecosystems`:

```sql
SELECT * FROM brain_control.ecosystems WHERE ecosystem_code = 'NEXUS';
```

### Functions Registered

```sql
SELECT function_code, function_name, unit_cost 
FROM brain_control.functions 
WHERE ecosystem_code = 'NEXUS';
```

| Code | Function | Cost |
|------|----------|------|
| NX01 | Harvest Import | $0.001 |
| NX02 | Social Lookup | $0.00 |
| NX03 | FEC Enrichment | $0.00 |
| NX04 | Voter Enrichment | $0.00 |
| NX05 | Property Enrichment | $0.00 |
| NX06 | Persona Analysis | $0.015 |
| NX07 | Draft Generation | $0.025 |
| NX08 | Approval Learning | $0.010 |

### E19 Social Media Extension

NEXUS extends existing approval workflow:

```sql
-- New columns added to social_approval_requests
ALTER TABLE social_approval_requests ADD COLUMN nexus_persona_score INT;
ALTER TABLE social_approval_requests ADD COLUMN nexus_trigger_type VARCHAR(50);
ALTER TABLE social_approval_requests ADD COLUMN nexus_confidence INT;
```

---

## Usage Examples

### Python CLI

```bash
# Check budget status
python ecosystem_nexus_complete.py status

# Run harvest matching
python ecosystem_nexus_complete.py match --batch-size 100

# Run FEC enrichment
python ecosystem_nexus_complete.py enrich --source fec --batch-size 50

# Analyze candidate voice
python ecosystem_nexus_complete.py analyze --candidate UUID

# Generate report
python ecosystem_nexus_complete.py report
```

### Python API

```python
from ecosystem_nexus_complete import NexusEcosystem, TriggerType

nexus = NexusEcosystem()

# Make GO/NO-GO decision
decision, scores = nexus.make_decision(
    TriggerType.DRAFT_GENERATION,
    {'candidate_id': 'uuid', 'training_samples': 75}
)

# Import harvest records
result = nexus.import_harvest_batch(
    records=[{'first_name': 'John', 'email': 'john@example.com'}],
    source_type='event_list',
    source_name='Rally 2024'
)

# Get budget status
status = nexus.get_budget_status()

# Close connection
nexus.close()
```

---

## Monitoring

### Key Views

| View | Purpose |
|------|---------|
| `v_nexus_executive_dashboard` | High-level KPIs |
| `v_nexus_budget_variance` | BVA by function |
| `v_nexus_operations_report` | Daily operations |
| `v_nexus_candidate_performance` | Per-candidate metrics |
| `v_nexus_harvest_progress` | Harvest status |

### Health Checks

```sql
-- Budget status
SELECT * FROM v_nexus_budget_variance;

-- Recent decisions
SELECT decision, COUNT(*) 
FROM intelligence_brain.nexus_decisions 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY decision;

-- Enrichment progress
SELECT enrichment_status, COUNT(*) 
FROM nexus_harvest_records 
GROUP BY enrichment_status;
```

---

## Troubleshooting

### Common Issues

**1. Migration fails: "relation does not exist"**
```
Ensure brain_control schema exists first.
Run platform core migrations before NEXUS.
```

**2. Budget check fails**
```
Check NEXUS_DAILY_AI_BUDGET and NEXUS_MONTHLY_AI_BUDGET in .env
Verify nexus_cost_transactions table exists
```

**3. AI drafts not generating**
```
Verify ANTHROPIC_API_KEY is set
Check budget limits not exceeded
Ensure candidate has style profile
```

### Logs

```bash
# View Python logs
tail -f /var/log/nexus/nexus.log

# Query decision log
SELECT * FROM intelligence_brain.nexus_decisions 
ORDER BY created_at DESC LIMIT 10;
```

---

## Security

### Required Secrets

Store these in GitHub Secrets or environment:
- `DATABASE_URL`
- `ANTHROPIC_API_KEY`
- `SUPABASE_ACCESS_TOKEN` (for CI/CD)

### Data Access

NEXUS follows platform RLS policies:
- Candidates see only their data
- Admins have full access
- API calls require authentication

---

## Support

**BroyhillGOP Platform Team**
- GitHub Issues: [Create Issue](https://github.com/broyhillgop/platform/issues)
- Documentation: [Platform Docs](https://docs.broyhillgop.com)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2024-12 | Full platform integration, 7-model decisions |
| 1.0.0 | 2024-12 | Initial NEXUS release |
