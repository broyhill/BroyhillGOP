# BroyhillGOP Platform

## AI-Powered Political Campaign Technology Platform

[![Version](https://img.shields.io/badge/version-3.0-blue.svg)](https://github.com/broyhillgop/platform)
[![Ecosystems](https://img.shields.io/badge/ecosystems-51-green.svg)](docs/)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

---

## Overview

BroyhillGOP is North Carolina's most advanced political campaign management platform, consisting of **51 integrated ecosystems** designed to fully automate Republican campaign operations.

| Metric | Value |
|--------|-------|
| **Total Ecosystems** | 51 (E00-E51) |
| **Platform Value** | $64M+ development |
| **Annual ROI** | 7,008% |
| **Monthly AI Cost** | ~$700 |
| **Database** | Supabase PostgreSQL |

---

## 🗂️ Repository Structure

```
BroyhillGOP-Platform/
│
├── frontend/
│   ├── inspinia/                    # Premium HTML Template (v4.7.0)
│   │   ├── Full/                    # Full template with all features
│   │   │   ├── dist/                # Production-ready files (USE THIS)
│   │   │   └── src/                 # Source files for customization
│   │   ├── Seed/                    # Minimal starter template
│   │   └── Docs/                    # Template documentation
│   │
│   └── command-center/              # BroyhillGOP Custom UI
│       ├── DAVE_BOLIEK_COMMAND_CENTER.html
│       └── DONOR_PROFILE_JAMES_WILSON.html
│
├── backend/
│   └── python/
│       ├── ecosystems/              # 51 Ecosystem Python Files
│       │   ├── ecosystem_00_datahub_complete.py
│       │   ├── ecosystem_01_donor_intelligence_complete.py
│       │   ├── ... (E02-E50)
│       │   └── ecosystem_51_nexus_complete.py
│       │
│       ├── engines/                 # NEXUS AI Engines
│       │   ├── nexus_brain_engine.py
│       │   ├── nexus_persona_engine.py
│       │   └── nexus_harvest_engine.py
│       │
│       └── integrations/            # Master Integration Scripts
│           ├── DEPLOY_ALL_ECOSYSTEMS.py
│           ├── MASTER_ECOSYSTEM_ORCHESTRATOR.py
│           └── BROYHILLGOP_MASTER_INTEGRATION_COMPLETE.py
│
├── database/
│   ├── schemas/                     # 75+ SQL Schema Files
│   │   ├── 001_broyhillgop_complete.sql
│   │   ├── COMPLETE_ALL_49_ECOSYSTEMS.sql
│   │   └── ... (all ecosystem schemas)
│   │
│   └── migrations/                  # NEXUS E51 Migrations
│       ├── 051_NEXUS_SOCIAL_EXTENSION.sql
│       ├── 052_NEXUS_HARVEST_ENRICHMENT.sql
│       └── 053_NEXUS_PLATFORM_INTEGRATION.sql
│
├── docs/                            # Documentation
│   ├── 00_MASTER_HANDOFF_COMPLETE.md
│   ├── README_COMPLETE_49_ECOSYSTEMS.md
│   ├── NEXUS_DEPLOYMENT.md
│   └── NEXUS_README.md
│
├── config/                          # Configuration
│   ├── .env.example
│   ├── deploy.sh
│   └── nexus.types.ts
│
└── .github/workflows/               # CI/CD
    └── deploy-nexus.yml
```

---

## 🚀 Quick Start

### Prerequisites
- PostgreSQL 15+ (Supabase recommended)
- Python 3.11+
- Node.js 20+ (for frontend build)
- Anthropic API key

### Installation

```bash
# 1. Clone repository
git clone https://github.com/YOUR_USERNAME/BroyhillGOP-Platform.git
cd BroyhillGOP-Platform

# 2. Configure environment
cp config/.env.example .env
# Edit .env with your credentials

# 3. Run database setup (in order!)
psql $DATABASE_URL -f database/schemas/001_broyhillgop_complete.sql
psql $DATABASE_URL -f database/migrations/051_NEXUS_SOCIAL_EXTENSION.sql
psql $DATABASE_URL -f database/migrations/052_NEXUS_HARVEST_ENRICHMENT.sql
psql $DATABASE_URL -f database/migrations/053_NEXUS_PLATFORM_INTEGRATION.sql

# 4. Install Python dependencies
pip install psycopg2-binary anthropic requests pandas python-dotenv

# 5. Test deployment
python backend/python/ecosystems/ecosystem_51_nexus_complete.py status
```

---

## 📊 Complete Ecosystem List (51 Systems)

### Core Infrastructure (E00-E07)
| # | Ecosystem | Status |
|---|-----------|--------|
| 00 | DataHub | 90% |
| 01 | Donor Intelligence | 85% |
| 02 | Donation Processing | 80% |
| 03 | Candidate Profiles | 75% |
| 04 | Activist Network | 85% |
| 05 | Volunteer Management | 80% |
| 06 | Analytics Engine | 80% |
| 07 | Issue Tracking | 70% |

### Content & Communications (E08-E15)
| # | Ecosystem | Status |
|---|-----------|--------|
| 08 | Communications Library | ✅ 100% |
| 09 | Content Creation AI | 60% |
| 10 | Compliance Manager | 75% |
| 11 | Budget Management | 70% |
| 12 | Campaign Operations | 65% |
| 13 | AI Hub | 90% |
| 14 | Print Production | 70% |
| 15 | Contact Directory | ✅ 100% |

### Media & Advertising (E16-E21)
| # | Ecosystem | Status |
|---|-----------|--------|
| 16 | TV/Radio AI | 92% |
| 17 | RVM System | 95% |
| 18 | Print Advertising/VDP | 70% |
| 19 | Social Media Manager | 65% |
| 20 | Intelligence Brain | ✅ 100% |
| 21 | ML Clustering | 60% |

### Dashboards & Portals (E22-E29)
| # | Ecosystem | Status |
|---|-----------|--------|
| 22 | A/B Testing Engine | 65% |
| 23 | Creative Asset/3D Engine | 60% |
| 24 | Candidate Portal | 65% |
| 25 | Donor Portal | 60% |
| 26 | Volunteer Portal | 65% |
| 27 | Real-Time Dashboard | 75% |
| 28 | Financial Dashboard | 70% |
| 29 | Analytics Dashboard | 75% |

### Communication Channels (E30-E39)
| # | Ecosystem | Status |
|---|-----------|--------|
| 30 | Email System | 85% |
| 31 | SMS System | 80% |
| 32 | Phone Banking | 75% |
| 33 | Direct Mail | 70% |
| 34 | Events | 70% |
| 35 | Interactive Comm Hub | 65% |
| 36 | Messenger Integration | 40% |
| 37 | Event Management | 70% |
| 38 | Volunteer Coordination | 70% |
| 39 | P2P Fundraising | 55% |

### Advanced Features (E40-E51)
| # | Ecosystem | Status |
|---|-----------|--------|
| 40 | Automation Control Panel | 65% |
| 41 | Campaign Builder | 65% |
| 42 | News Intelligence | ✅ 100% |
| 43 | Advocacy Tools | 60% |
| 44 | Vendor Compliance/Security | 70% |
| 45 | Video Studio | 60% |
| 46 | Broadcast Hub | 55% |
| 47 | AI Script Generator | 60% |
| 48 | Communication DNA | 65% |
| 49 | Interview System | 55% |
| **51** | **NEXUS AI Agent** | **✅ NEW** |

---

## 🧠 NEXUS AI Agent (E51) - NEW

The newest ecosystem providing intelligent harvest management and AI-powered social content:

### Features
- **7 Mathematical Models** for GO/NO-GO decisions
- **150K Harvest Records** processing
- **Voice Signature Analysis** for persona matching
- **FREE Data Enrichment** from government sources

### NEXUS Functions

| Code | Function | Cost |
|------|----------|------|
| NX01 | Harvest Import | $0.001 |
| NX02 | Social Lookup | FREE |
| NX03 | FEC Enrichment | FREE |
| NX04 | Voter Enrichment | FREE |
| NX05 | Property Enrichment | FREE |
| NX06 | Persona Analysis | $0.015 |
| NX07 | Draft Generation | $0.025 |
| NX08 | Approval Learning | $0.010 |

---

## 🎨 Frontend: Inspinia Template

Premium Bootstrap 5 admin template with 200+ pages:

### Using the Template
```bash
# Production files (ready to use)
cd frontend/inspinia/Full/dist/

# Open any HTML file in browser
open index.html

# Or serve locally
python -m http.server 8000
# Then visit: http://localhost:8000
```

### Key Pages
- `index.html` - Main dashboard
- `auth-sign-in.html` - Login page
- `ecommerce-*.html` - E-commerce (adapt for donations)
- `tables-datatables-*.html` - Data tables
- `charts-apex-*.html` - Analytics charts

---

## 📁 Database

### Supabase Connection
```
URL: https://isbgjpnbocdkeslofota.supabase.co
```

### Schema Files
- **Complete Schema:** `001_broyhillgop_complete.sql`
- **All 49 Ecosystems:** `COMPLETE_ALL_49_ECOSYSTEMS.sql`
- **NEXUS E51:** `051-053_NEXUS_*.sql`

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Master Handoff](docs/00_MASTER_HANDOFF_COMPLETE.md) | Complete platform overview |
| [49 Ecosystems](docs/README_COMPLETE_49_ECOSYSTEMS.md) | All ecosystem details |
| [NEXUS Deployment](docs/NEXUS_DEPLOYMENT.md) | E51 setup guide |
| [NEXUS Technical](docs/NEXUS_README.md) | E51 API reference |

---

## 👤 Contact

**BroyhillGOP LLC**  
Ed Broyhill - NC Republican National Committeeman  
📧 ed@broyhill.net

---

*Built for North Carolina Republicans* 🐘
