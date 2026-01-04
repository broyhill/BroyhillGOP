# ============================================================================
# VOLUNTEER ECOSYSTEM: 55-ECOSYSTEM INTEGRATION MAP
# ============================================================================
# Shows all touchpoints between E05/E26 Volunteer and other ecosystems
# ============================================================================

## ECOSYSTEM INTEGRATION DIAGRAM

```
                                    ┌─────────────────────────────────────┐
                                    │     E20 INTELLIGENCE BRAIN HUB      │
                                    │   (Central Decision Orchestrator)   │
                                    └──────────────────┬──────────────────┘
                                                       │
                    ┌──────────────────────────────────┼──────────────────────────────────┐
                    │                                  │                                  │
                    ▼                                  ▼                                  ▼
        ┌───────────────────┐              ┌───────────────────┐              ┌───────────────────┐
        │  E05 VOLUNTEER    │◄────────────►│  E26 VOLUNTEER    │◄────────────►│   E00 DATAHUB     │
        │   MANAGEMENT      │              │     PORTAL        │              │  (Data Storage)   │
        │   (Backend)       │              │   (Frontend)      │              │                   │
        └─────────┬─────────┘              └─────────┬─────────┘              └───────────────────┘
                  │                                  │
                  │         VOLUNTEER DATA FLOW      │
                  │                                  │
    ┌─────────────┼──────────────────────────────────┼─────────────────┐
    │             │                                  │                 │
    ▼             ▼                                  ▼                 ▼
┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐
│  E01  │    │  E04  │    │  E06  │    │  E12  │    │  E34  │    │  E37  │
│ Donor │    │Activist│   │Analyt-│    │Campaign│   │Events │    │ Event │
│ Intel │    │Network │   │  ics  │    │  Ops  │    │       │    │ Mgmt  │
└───────┘    └───────┘    └───────┘    └───────┘    └───────┘    └───────┘

                              COMMUNICATION CHANNELS
    ┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
    │             │             │             │             │             │
    ▼             ▼             ▼             ▼             ▼             ▼
┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐
│  E30  │    │  E31  │    │  E32  │    │  E33  │    │  E35  │    │  E36  │
│ Email │    │  SMS  │    │ Phone │    │Direct │    │ Auto  │    │Messngr│
│       │    │       │    │ Bank  │    │ Mail  │    │Response│   │       │
└───────┘    └───────┘    └───────┘    └───────┘    └───────┘    └───────┘
```

---

## DETAILED INTEGRATION POINTS

### TIER 1: DIRECT INTEGRATIONS (Bidirectional Data Flow)

| Ecosystem | Integration Type | Data Exchanged | Events |
|-----------|-----------------|----------------|--------|
| **E00 DataHub** | Storage | All volunteer records | CRUD operations |
| **E20 Brain Hub** | Orchestration | Events, decisions | volunteer.* events |
| **E26 Volunteer Portal** | UI/Frontend | Account data, signups | User actions |
| **E01 Donor Intelligence** | Conversion | Volunteer→Donor linking | conversion.volunteer_to_donor |
| **E04 Activist Network** | Overlap | Shared contact records | activist.volunteer_linked |

### TIER 2: OPERATIONAL INTEGRATIONS

| Ecosystem | Integration Type | Purpose |
|-----------|-----------------|---------|
| **E06 Analytics Engine** | Reporting | Volunteer metrics, KPIs |
| **E12 Campaign Operations** | Allocation | Volunteer assignment to campaigns |
| **E27 Realtime Dashboard** | Display | Live volunteer stats |
| **E34 Events** | Scheduling | Event volunteer coordination |
| **E37 Event Management** | Full lifecycle | Event volunteer management |
| **E40 Control Panel** | Automation | IFTTT rules for volunteers |

### TIER 3: COMMUNICATION INTEGRATIONS

| Ecosystem | Channel | Volunteer Use Cases |
|-----------|---------|---------------------|
| **E30 Email** | Email | Welcome, reminders, thank you |
| **E31 SMS** | Text | Shift reminders, alerts |
| **E32 Phone Banking** | Voice | Recruitment calls |
| **E35 Auto Response** | Multi | Automated responses |
| **E36 Messenger** | Social | Facebook/IG messaging |

---

## E20 BRAIN HUB EVENT SUBSCRIPTIONS

### Events E05 Publishes → E20 Receives

```python
VOLUNTEER_EVENTS_PUBLISHED = [
    'volunteer.registered',        # New volunteer signup
    'volunteer.shift_completed',   # Shift finished with results
    'volunteer.grade_changed',     # 3D grade recalculated
    'volunteer.milestone_reached', # Badge/achievement earned
    'volunteer.churn_risk_high',   # ML detected churn risk
    'volunteer.no_show',           # Missed assigned shift
    'volunteer.team_joined',       # Joined a team
    'volunteer.promoted',          # Became team leader
    'volunteer.reactivated',       # Returned after inactivity
]
```

### Events E05 Subscribes To ← E20 Publishes

```python
VOLUNTEER_EVENTS_SUBSCRIBED = [
    'brain.decision.volunteer_welcome',     # Trigger welcome sequence
    'brain.decision.volunteer_reengagement',# Trigger re-engagement
    'brain.decision.shift_reminder',        # Send shift reminder
    'brain.decision.volunteer_thank_you',   # Send thank you
    'campaign.volunteer_needed',            # Campaign needs volunteers
    'event.volunteer_slots_open',           # Event needs volunteers
    'donor.volunteer_conversion',           # Donor wants to volunteer
]
```

---

## SUPABASE TABLE DEPENDENCIES

### Tables E05 Creates/Owns

```sql
-- Core tables
volunteers                      -- Main volunteer records
volunteer_shifts               -- Shift definitions
shift_assignments              -- Volunteer-shift mappings
volunteer_teams                -- Team definitions
volunteer_team_members         -- Team memberships
volunteer_hours_log            -- Hours tracking
volunteer_badge_definitions    -- Badge definitions
volunteer_badge_earnings       -- Earned badges
volunteer_leaderboards         -- Pre-calculated rankings
volunteer_brain_events         -- E20 event log

-- Portal tables (E26)
volunteer_accounts             -- Portal login accounts
volunteer_sessions             -- Auth sessions
volunteer_opportunities        -- Public-facing shifts
volunteer_signups              -- Portal signups
volunteer_achievements         -- Portal achievements
volunteer_achievement_earnings -- Earned achievements
volunteer_portal_teams         -- Portal teams
volunteer_portal_team_members  -- Portal team members
volunteer_messages             -- Announcements
volunteer_message_reads        -- Read tracking
```

### Tables E05 References (Foreign Keys)

```sql
-- From E00 DataHub
contacts                       -- volunteers.contact_id
campaigns                      -- volunteer_shifts.campaign_id
candidates                     -- volunteers.candidate_id

-- From E01 Donor Intelligence
donors                         -- volunteers.donor_id
donor_scores                   -- For volunteer→donor conversion

-- From E34/E37 Events
events                         -- volunteer_shifts.event_id
```

---

## IFTTT AUTOMATION RULES (E40 Control Panel)

### Volunteer-Related Automation Rules

| Rule ID | Trigger | Condition | Action | Ecosystem |
|---------|---------|-----------|--------|-----------|
| VOL-001 | volunteer.registered | has_email=true | Send welcome email | E30 |
| VOL-002 | volunteer.registered | has_phone=true | Send welcome SMS | E31 |
| VOL-003 | volunteer.shift_completed | doors>=50 | Send thank you | E30 |
| VOL-004 | volunteer.shift_completed | always | Update leaderboard | E05 |
| VOL-005 | volunteer.milestone_reached | badge_earned | Send congrats SMS | E31 |
| VOL-006 | volunteer.churn_risk_high | risk>0.7 | Send re-engagement | E30 |
| VOL-007 | volunteer.no_show | always | Send follow-up | E30 |
| VOL-008 | shift.24h_before | assigned=true | Send reminder SMS | E31 |
| VOL-009 | volunteer.grade_changed | grade=A+ | Flag for leadership | E05 |
| VOL-010 | donor.converted | was_volunteer=true | Link records | E01 |

---

## API ENDPOINTS (E55 API Gateway)

### Volunteer Management API

```
POST   /api/v1/volunteers                    # Create volunteer
GET    /api/v1/volunteers                    # List volunteers
GET    /api/v1/volunteers/{id}               # Get volunteer
PUT    /api/v1/volunteers/{id}               # Update volunteer
DELETE /api/v1/volunteers/{id}               # Deactivate volunteer

POST   /api/v1/volunteers/{id}/grade         # Recalculate grade
GET    /api/v1/volunteers/{id}/stats         # Get volunteer stats
GET    /api/v1/volunteers/{id}/badges        # Get earned badges
GET    /api/v1/volunteers/{id}/shifts        # Get shift history

POST   /api/v1/shifts                        # Create shift
GET    /api/v1/shifts                        # List shifts
GET    /api/v1/shifts/available              # Get available shifts
POST   /api/v1/shifts/{id}/assign            # Assign volunteer
POST   /api/v1/shifts/{id}/complete          # Complete shift

GET    /api/v1/leaderboard                   # Get leaderboard
GET    /api/v1/leaderboard/{category}        # Get category leaderboard

POST   /api/v1/teams                         # Create team
GET    /api/v1/teams                         # List teams
POST   /api/v1/teams/{id}/members            # Add team member
```

### Volunteer Portal API (E26)

```
POST   /api/v1/portal/register               # Create portal account
POST   /api/v1/portal/login                  # Authenticate
GET    /api/v1/portal/dashboard              # Get dashboard data
GET    /api/v1/portal/opportunities          # Get available shifts
POST   /api/v1/portal/signup/{id}            # Sign up for shift
DELETE /api/v1/portal/signup/{id}            # Cancel signup
POST   /api/v1/portal/checkin/{id}           # Check in to shift
GET    /api/v1/portal/badges                 # Get badges
GET    /api/v1/portal/leaderboard            # Get leaderboard
```

---

## CROSS-ECOSYSTEM DATA FLOWS

### 1. Volunteer → Donor Conversion Flow

```
E05 (Volunteer) → E20 (Brain) → E01 (Donor Intelligence)
     │                │              │
     │ volunteer      │ decision     │ create_donor()
     │ .high_value    │ .convert     │ link_volunteer_id
     │                │              │
     └────────────────┴──────────────┘
```

### 2. Event Volunteer Recruitment Flow

```
E34 (Events) → E20 (Brain) → E05 (Volunteer) → E30 (Email)
     │              │              │              │
     │ event        │ decision     │ get_         │ send_
     │ .needs_      │ .recruit     │ available    │ recruitment
     │ volunteers   │              │ volunteers   │ email
     └──────────────┴──────────────┴──────────────┘
```

### 3. Campaign Staffing Flow

```
E12 (Campaign Ops) → E20 (Brain) → E05 (Volunteer) → E37 (Event Mgmt)
     │                    │              │              │
     │ campaign           │ allocate     │ assign       │ create
     │ .launch           │ volunteers   │ to_shifts    │ shifts
     └────────────────────┴──────────────┴──────────────┘
```

---

## AFFECTED ECOSYSTEMS SUMMARY

When modifying E05 Volunteer Management:

### MUST UPDATE (Direct Dependencies)
- **E20 Intelligence Brain** - Add event handlers
- **E26 Volunteer Portal** - Sync data models
- **E00 DataHub** - Schema additions
- **E40 Control Panel** - Add automation rules

### SHOULD NOTIFY (Indirect Dependencies)
- **E01 Donor Intelligence** - Conversion logic
- **E06 Analytics Engine** - New metrics
- **E27 Realtime Dashboard** - New widgets

### MAY AFFECT (Communication Channels)
- **E30 Email** - New templates
- **E31 SMS** - New templates
- **E32 Phone Banking** - Recruitment scripts

---

## DEPLOYMENT ORDER

When deploying volunteer ecosystem updates:

```
1. FIRST:  Run SQL schema in Supabase
2. SECOND: Deploy E05 Python to Hetzner
3. THIRD:  Update E20 Brain Hub event handlers
4. FOURTH: Configure E40 Control Panel rules
5. FIFTH:  Deploy E26 Portal frontend
6. LAST:   Test full integration
```

---

*Integration Map v1.0 - January 4, 2026*
*BroyhillGOP Volunteer Ecosystem*
