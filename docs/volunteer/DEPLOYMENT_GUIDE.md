# ============================================================================
# VOLUNTEER ECOSYSTEM COMPLETE DEPLOYMENT GUIDE
# ============================================================================
# E05 Volunteer Management + E26 Volunteer Portal + E20 Brain Integration
# ============================================================================

## PACKAGE CONTENTS

```
VOLUNTEER_ECOSYSTEM_COMPLETE/
├── ecosystem_05_volunteer_management_complete.py    # Core volunteer system
├── VOLUNTEER_ECOSYSTEM_COMPLETE_SCHEMA.sql          # Database schema
├── E20_VOLUNTEER_INTEGRATION_UPDATE.py              # Brain Hub integration
├── E05_VOLUNTEER_MANAGEMENT_DASHBOARD.html          # Admin dashboard
├── E26_VOLUNTEER_PORTAL_DASHBOARD.html              # Public portal
└── DEPLOYMENT_GUIDE.md                              # This file
```

---

## STEP 1: DATABASE DEPLOYMENT (Supabase)

### 1.1 Run Schema in Supabase SQL Editor

1. Log into Supabase: https://supabase.com/dashboard
2. Select project: `isbgjpnbocdkeslofofa`
3. Go to SQL Editor
4. Paste contents of `VOLUNTEER_ECOSYSTEM_COMPLETE_SCHEMA.sql`
5. Execute

### 1.2 Verify Tables Created

Run this query to verify:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE 'volunteer%'
ORDER BY table_name;
```

**Expected tables (17 total):**
- volunteer_accounts
- volunteer_achievement_earnings
- volunteer_achievements
- volunteer_badge_definitions
- volunteer_badge_earnings
- volunteer_brain_events
- volunteer_hours_log
- volunteer_leaderboards
- volunteer_messages
- volunteer_message_reads
- volunteer_opportunities
- volunteer_portal_team_members
- volunteer_portal_teams
- volunteer_sessions
- volunteer_signups
- volunteer_team_members
- volunteer_teams
- volunteer_shifts
- shift_assignments
- volunteers

### 1.3 Verify Views Created

```sql
SELECT viewname FROM pg_views 
WHERE schemaname = 'public' 
AND viewname LIKE 'v_volunteer%';
```

**Expected views:**
- v_volunteer_summary
- v_volunteer_dashboard
- v_volunteer_leaderboard
- v_shift_availability
- v_top_volunteers
- v_available_opportunities

---

## STEP 2: E20 BRAIN HUB INTEGRATION

### 2.1 Update E20 Event Subscriptions

Add to `ecosystem_20_intelligence_brain.py` in `subscribe_to_events()`:

```python
# Volunteer Events (Ecosystem 5)
'volunteer.registered',
'volunteer.shift_completed',
'volunteer.grade_changed',
'volunteer.milestone_reached',
'volunteer.churn_risk_high',
'volunteer.no_show',
'volunteer.team_joined',
'volunteer.promoted',
```

### 2.2 Add Event Routing

In `handle_event()` method, add:

```python
elif event_type.startswith('volunteer.'):
    self.handle_volunteer_event(event)
```

### 2.3 Import Handler Methods

Copy all handler methods from `E20_VOLUNTEER_INTEGRATION_UPDATE.py` into the IntelligenceBrain class.

### 2.4 Test E20 Integration

```bash
# Test event publishing
redis-cli PUBLISH "volunteer.registered" '{"event_type":"volunteer.registered","data":{"volunteer_id":"test-uuid","name":"Test User","email":"test@example.com"}}'

# Check E20 received it
tail -f /var/log/broyhillgop/e20_brain.log
```

---

## STEP 3: PYTHON FILE DEPLOYMENT

### 3.1 Deploy to Hetzner Server

```bash
# SSH to server
ssh root@5.9.99.109

# Navigate to ecosystems directory
cd /var/www/broyhillgop/backend/python/ecosystems

# Upload file
scp ecosystem_05_volunteer_management_complete.py root@5.9.99.109:/var/www/broyhillgop/backend/python/ecosystems/

# Set permissions
chmod 644 ecosystem_05_volunteer_management_complete.py
```

### 3.2 Install Dependencies

```bash
pip install redis psycopg2-binary --break-system-packages
```

### 3.3 Test Python Module

```python
python3 -c "
from ecosystem_05_volunteer_management_complete import VolunteerManagement
vm = VolunteerManagement()
print('✅ Volunteer Management loaded successfully')
"
```

---

## STEP 4: GITHUB DEPLOYMENT

### 4.1 Commit to Repository

```bash
cd /path/to/BroyhillGOP

# Add new files
git add backend/python/ecosystems/ecosystem_05_volunteer_management_complete.py
git add database/schemas/volunteer_ecosystem_schema.sql

# Commit with proper message
git commit -m "[2026-01-04] - Ecosystem 5 - Volunteer Management Complete with E20 Integration"

# Push to main
git push origin main
```

### 4.2 Verify GitHub Upload

- Go to: https://github.com/broyhill/BroyhillGOP
- Navigate to `backend/python/ecosystems/`
- Confirm file is present

---

## STEP 5: FRONTEND DEPLOYMENT

### 5.1 Deploy Dashboard HTML

```bash
# Copy to frontend directory
cp E05_VOLUNTEER_MANAGEMENT_DASHBOARD.html /var/www/broyhillgop/frontend/volunteer/

# Or for Inspinia integration
cp E05_VOLUNTEER_MANAGEMENT_DASHBOARD.html /var/www/broyhillgop/frontend/inspinia/views/volunteer.html
```

### 5.2 Update Navigation

Add to main navigation in all ecosystem dashboards:

```html
<li>
    <a href="/volunteer"><i class="fas fa-hands-helping"></i> <span>Volunteers</span></a>
</li>
```

---

## STEP 6: E20 BRAIN TRIGGERS TO CONFIGURE

### 6.1 Add Volunteer Triggers to brain_triggers Table

```sql
INSERT INTO brain_triggers (trigger_code, trigger_name, category, priority, actions, conditions)
VALUES
('VOL_REGISTERED', 'New Volunteer Registration', 'VOLUNTEER', 5, 
 '{"send_welcome_email": true, "send_welcome_sms": true, "add_to_newsletter": true}',
 '{"has_email": true}'),

('VOL_SHIFT_COMPLETE', 'Volunteer Shift Completed', 'VOLUNTEER', 3,
 '{"award_points": true, "check_badges": true, "update_leaderboard": true}',
 '{"hours_worked": "> 0"}'),

('VOL_HIGH_PERFORMER', 'High Performer Detection', 'VOLUNTEER', 4,
 '{"send_thank_you": true, "flag_for_leadership": true}',
 '{"doors_knocked": ">= 50", "OR": {"hours_worked": ">= 4"}}'),

('VOL_CHURN_RISK', 'Volunteer Churn Risk High', 'VOLUNTEER', 6,
 '{"send_reengagement_email": true, "schedule_call": true}',
 '{"churn_risk": "> 0.7", "days_inactive": "< 90"}'),

('VOL_NO_SHOW', 'Volunteer No-Show', 'VOLUNTEER', 4,
 '{"send_followup": true, "update_reliability": true}',
 '{"assignment_status": "no_show"}'),

('VOL_MILESTONE', 'Volunteer Milestone Reached', 'VOLUNTEER', 3,
 '{"send_congratulations": true, "award_badge": true, "social_share": true}',
 '{"badge_earned": true}');
```

---

## STEP 7: IFTTT AUTOMATION RULES

### 7.1 Add to E40 Control Panel

Create these automation rules in the Control Panel:

| Rule Name | Trigger | Condition | Action |
|-----------|---------|-----------|--------|
| Welcome New Volunteer | volunteer.registered | has_email = true | Send E30 Welcome Email |
| Thank High Performer | volunteer.shift_completed | doors >= 50 | Send E30 Thank You |
| Re-engage Inactive | volunteer.churn_risk_high | risk > 0.7 | Send E30 Re-engagement |
| Badge Celebration | volunteer.milestone_reached | badge_earned | Send E31 SMS Congrats |
| No-Show Follow-up | volunteer.no_show | - | Send E30 Check-in Email |

---

## STEP 8: REDIS EVENT BUS CONFIGURATION

### 8.1 Verify Redis Channels

```bash
redis-cli
> PUBSUB CHANNELS "volunteer.*"
```

### 8.2 Subscribe to Test Events

```bash
redis-cli
> SUBSCRIBE volunteer.registered volunteer.shift_completed volunteer.grade_changed
```

---

## STEP 9: VERIFICATION CHECKLIST

### Database
- [ ] All 17+ volunteer tables created
- [ ] All 6 views created
- [ ] Badge definitions seeded
- [ ] Achievement definitions seeded

### Python
- [ ] ecosystem_05_volunteer_management_complete.py deployed
- [ ] Dependencies installed
- [ ] Module imports successfully

### E20 Brain Hub
- [ ] Volunteer event channels subscribed
- [ ] Event handlers added
- [ ] Triggers configured in brain_triggers table

### Frontend
- [ ] Dashboard HTML deployed
- [ ] Navigation updated
- [ ] Inspinia components working

### GitHub
- [ ] Python file committed
- [ ] SQL schema committed
- [ ] Commit message format correct

### IFTTT/Control Panel
- [ ] Automation rules created
- [ ] Rules tested with sample events

---

## STEP 10: TESTING PROTOCOL

### 10.1 Create Test Volunteer

```python
from ecosystem_05_volunteer_management_complete import VolunteerManagement

vm = VolunteerManagement()

# Create volunteer
vol_id = vm.create_volunteer({
    'first_name': 'Test',
    'last_name': 'Volunteer',
    'email': 'test@broyhillgop.org',
    'phone': '3365551234',
    'city': 'Winston-Salem',
    'county': 'Forsyth',
    'recruitment_source': 'Website'
})

print(f"Created volunteer: {vol_id}")
```

### 10.2 Create Test Shift

```python
shift_id = vm.create_shift({
    'title': 'Test Door Knocking',
    'activity_code': 'CANVASS',
    'shift_date': '2026-01-10',
    'start_time': '09:00',
    'end_time': '13:00',
    'location_name': 'Forsyth County HQ',
    'slots_total': 10
})

print(f"Created shift: {shift_id}")
```

### 10.3 Assign and Complete

```python
# Assign
result = vm.assign_volunteer(shift_id, vol_id)
assignment_id = result['assignment_id']

# Complete with results
vm.complete_shift(assignment_id, {
    'hours_worked': 4,
    'doors_knocked': 52,
    'calls_made': 0
})

# Check grade recalculation
grade = vm.calculate_grade(vol_id)
print(f"Volunteer grade: {grade}")
```

### 10.4 Verify E20 Events Fired

Check Redis or E20 logs for:
- `volunteer.registered`
- `volunteer.shift_completed`
- `volunteer.grade_changed`

---

## ECOSYSTEM DEPENDENCIES

### E05 Volunteer Management Depends On:
- **E00 DataHub** - Data storage
- **E20 Brain Hub** - Decision orchestration
- **E30 Email** - Welcome/thank you emails
- **E31 SMS** - Notifications
- **E40 Control Panel** - IFTTT automation

### E05 Volunteer Management Feeds:
- **E01 Donor Intelligence** - Volunteer→Donor conversion
- **E06 Analytics** - Volunteer metrics
- **E12 Campaign Operations** - Volunteer allocation
- **E27 Realtime Dashboard** - Live stats

### E26 Volunteer Portal Depends On:
- **E05 Volunteer Management** - Core data
- **E20 Brain Hub** - Personalization
- **E08 Communications Library** - Content

---

## ROLLBACK PROCEDURE

If issues occur:

### Database Rollback
```sql
-- Drop all volunteer tables (CAUTION)
DROP TABLE IF EXISTS volunteer_brain_events CASCADE;
DROP TABLE IF EXISTS volunteer_message_reads CASCADE;
DROP TABLE IF EXISTS volunteer_messages CASCADE;
DROP TABLE IF EXISTS volunteer_portal_team_members CASCADE;
DROP TABLE IF EXISTS volunteer_portal_teams CASCADE;
DROP TABLE IF EXISTS volunteer_achievement_earnings CASCADE;
DROP TABLE IF EXISTS volunteer_achievements CASCADE;
DROP TABLE IF EXISTS volunteer_signups CASCADE;
DROP TABLE IF EXISTS volunteer_opportunities CASCADE;
DROP TABLE IF EXISTS volunteer_sessions CASCADE;
DROP TABLE IF EXISTS volunteer_accounts CASCADE;
DROP TABLE IF EXISTS volunteer_badge_earnings CASCADE;
DROP TABLE IF EXISTS volunteer_badge_definitions CASCADE;
DROP TABLE IF EXISTS volunteer_leaderboards CASCADE;
DROP TABLE IF EXISTS volunteer_hours_log CASCADE;
DROP TABLE IF EXISTS volunteer_team_members CASCADE;
DROP TABLE IF EXISTS volunteer_teams CASCADE;
DROP TABLE IF EXISTS shift_assignments CASCADE;
DROP TABLE IF EXISTS volunteer_shifts CASCADE;
DROP TABLE IF EXISTS volunteers CASCADE;

-- Drop views
DROP VIEW IF EXISTS v_volunteer_summary CASCADE;
DROP VIEW IF EXISTS v_volunteer_dashboard CASCADE;
DROP VIEW IF EXISTS v_volunteer_leaderboard CASCADE;
DROP VIEW IF EXISTS v_shift_availability CASCADE;
DROP VIEW IF EXISTS v_top_volunteers CASCADE;
DROP VIEW IF EXISTS v_available_opportunities CASCADE;
```

### Git Rollback
```bash
git revert HEAD
git push origin main
```

---

## SUPPORT CONTACTS

- **GitHub Issues**: github.com/broyhill/BroyhillGOP/issues
- **Supabase Dashboard**: supabase.com/dashboard
- **Hetzner Console**: console.hetzner.cloud

---

*Deployment Guide v1.0 - January 4, 2026*
*BroyhillGOP Volunteer Ecosystem Complete Package*
