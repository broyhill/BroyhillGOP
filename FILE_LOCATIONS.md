# BroyhillGOP Platform - File Locations Guide
## Complete Platform Structure

**Total Files:** 2,385+
**Python Files:** 67
**SQL Files:** 78
**Last Updated:** December 18, 2025

---

## 📁 DIRECTORY STRUCTURE

```
BroyhillGOP-Platform/
│
├── frontend/                          # FRONTEND FILES
│   ├── inspinia/                      # Inspinia v4.7.0 Bootstrap 5 Template
│   │   ├── Full/                      # Complete template (USE THIS FOR PRODUCTION)
│   │   │   └── dist/                  # Ready-to-deploy files
│   │   ├── Seed/                      # Minimal starter template
│   │   └── Docs/                      # Template documentation
│   │
│   └── command-center/                # CUSTOM COMMAND CENTER UI
│       ├── DAVE_BOLIEK_COMMAND_CENTER.html    # Full donor command center (171KB)
│       └── DONOR_PROFILE_JAMES_WILSON.html    # Donor profile template (73KB)
│
├── backend/python/                    # PYTHON BACKEND FILES
│   ├── ecosystems/                    # 59 Ecosystem Files (E00-E51)
│   │   ├── ecosystem_00_datahub_complete.py
│   │   ├── ecosystem_01_donor_intelligence_complete.py
│   │   ├── ecosystem_02_comms_engine_complete.py
│   │   ├── ... (E03-E50)
│   │   └── ecosystem_51_nexus_complete.py     # NEW: NEXUS AI System
│   │
│   ├── engines/                       # 3 NEXUS AI Engines
│   │   ├── nexus_brain_engine.py      # Central AI processing
│   │   ├── nexus_persona_engine.py    # Persona generation
│   │   └── nexus_harvest_engine.py    # Donor harvesting
│   │
│   └── integrations/                  # 5 Master Integration Scripts
│       ├── DEPLOY_ALL_ECOSYSTEMS.py
│       ├── MASTER_ECOSYSTEM_ORCHESTRATOR.py
│       ├── BROYHILLGOP_MASTER_INTEGRATION_COMPLETE.py
│       ├── BROYHILLGOP_COMPLETE_PLATFORM.py
│       └── BROYHILLGOP_COMPLETE_INTEGRATION.py
│
├── database/                          # SQL DATABASE FILES
│   ├── schemas/                       # 75 Schema Files
│   │   ├── 001_broyhillgop_complete.sql       # Master schema (446KB)
│   │   ├── COMPLETE_ALL_49_ECOSYSTEMS.sql     # All ecosystems combined
│   │   ├── ecosystem_00_datahub.sql
│   │   ├── ecosystem_01_donor_intelligence.sql
│   │   ├── ... (all ecosystem schemas)
│   │   └── integration_*.sql                  # Integration schemas
│   │
│   └── migrations/                    # 3 NEXUS E51 Migrations
│       ├── 051_NEXUS_SOCIAL_EXTENSION.sql     # Social media tables
│       ├── 052_NEXUS_HARVEST_ENRICHMENT.sql   # Harvest/enrichment tables
│       └── 053_NEXUS_PLATFORM_INTEGRATION.sql # Platform integration
│
├── docs/                              # DOCUMENTATION
│   ├── MASTER_HANDOFF_DOCUMENT.md
│   ├── 49_ECOSYSTEMS_COMPLETE_GUIDE.md
│   ├── NEXUS_DEPLOYMENT_GUIDE.md
│   ├── QUICK_START.md
│   └── ... (additional docs)
│
├── config/                            # CONFIGURATION FILES
│   ├── .env.example                   # Environment template
│   ├── deploy.sh                      # Deployment script
│   └── nexus.types.ts                 # TypeScript definitions
│
├── .github/workflows/                 # CI/CD
│   └── deploy-nexus.yml               # GitHub Actions workflow
│
├── README.md                          # Main documentation
├── requirements.txt                   # Python dependencies
├── LICENSE                            # Proprietary license
└── .gitignore                         # Git exclusions
```

---

## 🔑 KEY FILE LOCATIONS

### Boliek Command Center Templates
```
frontend/command-center/DAVE_BOLIEK_COMMAND_CENTER.html
frontend/command-center/DONOR_PROFILE_JAMES_WILSON.html
```

### Python Ecosystems (E00-E51)
```
backend/python/ecosystems/ecosystem_00_datahub_complete.py
backend/python/ecosystems/ecosystem_01_donor_intelligence_complete.py
... through ...
backend/python/ecosystems/ecosystem_51_nexus_complete.py
```

### NEXUS AI Engines
```
backend/python/engines/nexus_brain_engine.py
backend/python/engines/nexus_persona_engine.py
backend/python/engines/nexus_harvest_engine.py
```

### Database Schemas
```
database/schemas/001_broyhillgop_complete.sql      # Master (446KB)
database/schemas/COMPLETE_ALL_49_ECOSYSTEMS.sql    # Combined
database/migrations/051_NEXUS_SOCIAL_EXTENSION.sql
database/migrations/052_NEXUS_HARVEST_ENRICHMENT.sql
database/migrations/053_NEXUS_PLATFORM_INTEGRATION.sql
```

### Inspinia Template (Production)
```
frontend/inspinia/Full/dist/          # Deploy this folder
```

---

## 💰 PLATFORM VALUE

| Metric | Value |
|--------|-------|
| Development Value | $64M+ |
| Ecosystems | 51 complete |
| Annual ROI | 7,008% |
| Monthly AI Budget | $1,500 |
| Daily AI Limit | $50 |
| Harvest Capacity | 150,000/year |

---

## 🚀 QUICK START

1. **Database Setup:**
   ```bash
   psql -U postgres -d broyhillgop -f database/schemas/001_broyhillgop_complete.sql
   psql -U postgres -d broyhillgop -f database/migrations/051_NEXUS_SOCIAL_EXTENSION.sql
   psql -U postgres -d broyhillgop -f database/migrations/052_NEXUS_HARVEST_ENRICHMENT.sql
   psql -U postgres -d broyhillgop -f database/migrations/053_NEXUS_PLATFORM_INTEGRATION.sql
   ```

2. **Python Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Environment Configuration:**
   ```bash
   cp config/.env.example .env
   # Edit .env with your Supabase/API credentials
   ```

4. **Frontend Deployment:**
   ```bash
   # Copy frontend/inspinia/Full/dist/ to your web server
   # Or open frontend/command-center/DAVE_BOLIEK_COMMAND_CENTER.html
   ```

---

## 📞 SUPPORT

**BroyhillGOP LLC**
Ed Broyhill - Founder/CEO
Email: ed@broyhill.net
Supabase: https://isbgjpnbocdkeslofota.supabase.co

---

© 2024-2025 BroyhillGOP LLC. All Rights Reserved.
