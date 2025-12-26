# BroyhillGOP December 2024 Enhancement Package

## Overview

This package introduces four major enhancements to the BroyhillGOP platform:

1. **Triple Grading System** - State/District/County percentile-based grading
2. **Office Context Mapping** - Auto-selects appropriate grade based on race type
3. **Cultivation Intelligence** - AI-driven investment decisions (no hard caps)
4. **Event Timing Discipline** - Day -4 rule for volunteer activation

## Quick Start

```bash
# 1. Run database migration
psql -d broyhillgop -f database/migrations/2024_12_enhancement_migration.sql

# 2. Recalculate grades after populating districts
psql -d broyhillgop -c "SELECT recalculate_district_grades();"

# 3. Start API server
cd backend/python/api
pip install fastapi uvicorn psycopg2-binary
python campaign_wizard_api.py
```

## Files Added

| Category | File | Purpose |
|----------|------|---------|
| Database | `database/migrations/2024_12_enhancement_migration.sql` | Complete schema migration |
| Database | `database/schemas/CALCULATE_TRIPLE_GRADES.sql` | Grade calculation SQL |
| Python | `backend/python/ecosystems/nc_office_context_mapping.py` | Office → Grade context |
| Python | `backend/python/ecosystems/donor_cultivation_intelligence.py` | AI cultivation (no caps) |
| Python | `backend/python/ecosystems/event_timing_discipline.py` | Day -4 rule |
| Python | `backend/python/ecosystems/december_2024_integration.py` | Unified integration |
| API | `backend/python/api/campaign_wizard_api.py` | FastAPI endpoints |
| Frontend | `frontend/candidate-portal/ecosystem-donor-intelligence-triple.html` | Triple grade UI |

## Key Concepts

### Triple Grading
```
Sarah Mitchell (Caldwell County, HD-87)
├── State:    B+  (#8,234 of 243,575)  → Ask $1,000 for Governor race
├── District: A+  (#2 of 2,847)        → Ask $5,000 for State House race
└── County:   A++ (#1 of 1,845)        → Ask $6,800 for Sheriff race
```

### Office Context Auto-Selection
| Office | Uses |
|--------|------|
| Governor, US Senate, Council of State | State Grade |
| US House, State Senate, State House | District Grade |
| Sheriff, Commissioner, Local | County Grade |

### Cultivation Intelligence
- **NO HARD CAPS** - AI decides investment based on ROI
- Tests all segments continuously
- Scales up winners, reduces (but doesn't abandon) losers
- Grade is starting point, not constraint

### Event Timing
- Day -30 to -5: Paid solicitation only
- Day -4 to -1: Volunteer file activated if undersold
- Prevents giving away seats that could be sold

## API Endpoints

```
GET  /api/v2/office-types                    # All NC offices with context
GET  /api/v2/donors/{id}/grades              # All three grades
GET  /api/v2/donors/{id}/contextual-grade    # Grade for specific race
POST /api/v2/campaigns                       # Create with context
POST /api/v2/campaigns/validate-goal         # Reality check
GET  /api/v2/events/{id}/status              # Timing phase
POST /api/v2/cultivation/segment-strategy    # AI recommendation
```

## Standard Donation Menu

| Grade | Amount |
|-------|--------|
| A++ | $6,800 |
| A+ | $5,000 |
| A/A- | $2,500 |
| B+/B | $1,000 |
| B-/C+ | $500 |
| C-/D/U | $100 |

## Special Guest Multipliers

| Guest | Multiplier |
|-------|------------|
| US Senator | 4.0x |
| Governor | 3.5x |
| US Congressman | 2.5x |
| Speaker | 2.0x |

See `docs/TRIPLE_GRADING_ENHANCEMENT.md` for full documentation.
