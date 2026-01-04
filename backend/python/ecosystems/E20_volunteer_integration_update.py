#!/usr/bin/env python3
"""
============================================================================
E20 INTELLIGENCE BRAIN - VOLUNTEER INTEGRATION UPDATE
============================================================================

Adds volunteer event handling to E20 Brain Hub:
- volunteer.registered -> Welcome sequence
- volunteer.shift_completed -> Recognition/Points
- volunteer.grade_changed -> Engagement adjustment
- volunteer.milestone_reached -> Celebration
- volunteer.churn_risk_high -> Re-engagement campaign

Add this to existing ecosystem_20_intelligence_brain.py
============================================================================
"""

# ============================================================================
# ADD TO subscribe_to_events() METHOD
# ============================================================================

VOLUNTEER_EVENT_CHANNELS = [
    # Volunteer Events (Ecosystem 5)
    'volunteer.registered',
    'volunteer.shift_completed',
    'volunteer.grade_changed',
    'volunteer.milestone_reached',
    'volunteer.churn_risk_high',
    'volunteer.no_show',
    'volunteer.team_joined',
    'volunteer.promoted',
]

# ============================================================================
# ADD TO handle_event() METHOD - EVENT ROUTING
# ============================================================================

def handle_volunteer_event(self, event):
    """Route volunteer events to appropriate handlers"""
    event_type = event.get('event_type')
    
    if event_type == 'volunteer.registered':
        self.handle_volunteer_registered(event)
    
    elif event_type == 'volunteer.shift_completed':
        self.handle_volunteer_shift_completed(event)
    
    elif event_type == 'volunteer.grade_changed':
        self.handle_volunteer_grade_changed(event)
    
    elif event_type == 'volunteer.milestone_reached':
        self.handle_volunteer_milestone(event)
    
    elif event_type == 'volunteer.churn_risk_high':
        self.handle_volunteer_churn_risk(event)
    
    elif event_type == 'volunteer.no_show':
        self.handle_volunteer_no_show(event)

# ============================================================================
# VOLUNTEER EVENT HANDLERS
# ============================================================================

def handle_volunteer_registered(self, event):
    """
    Handle new volunteer registration
    
    Workflow:
    1. Send welcome email
    2. Send welcome SMS
    3. Schedule orientation call
    4. Add to volunteer newsletter
    """
    logger.info(f"🎉 NEW VOLUNTEER: {event['data'].get('name')}")
    
    volunteer_id = event['data'].get('volunteer_id')
    candidate_id = event['data'].get('candidate_id')
    email = event['data'].get('email')
    
    # Request welcome content from Library (E8)
    content = self.request_content(
        candidate_id=candidate_id,
        occasion='volunteer_welcome',
        channel='EMAIL',
        context='new_volunteer'
    )
    
    if content:
        # Trigger welcome email (E30)
        self.trigger_email_campaign(
            candidate_id=candidate_id,
            content_uuid=content['content_uuid'],
            recipients=[volunteer_id],
            priority='normal',
            context='volunteer_welcome'
        )
        logger.info(f"   📧 Welcome email sent")
    
    # Trigger welcome SMS (E31)
    sms_content = self.request_content(
        candidate_id=candidate_id,
        occasion='volunteer_welcome',
        channel='SMS',
        context='new_volunteer'
    )
    
    if sms_content:
        self.trigger_sms_campaign(
            candidate_id=candidate_id,
            content_uuid=sms_content['content_uuid'],
            recipients=[volunteer_id],
            priority='normal',
            context='volunteer_welcome_sms'
        )
        logger.info(f"   📱 Welcome SMS sent")
    
    # Log decision
    self.publish_decision(
        decision_type='volunteer_welcome',
        candidate_id=candidate_id,
        action='welcome_sequence_triggered',
        volunteer_id=volunteer_id
    )


def handle_volunteer_shift_completed(self, event):
    """
    Handle shift completion
    
    Workflow:
    1. Calculate bonus if high performance
    2. Send thank you
    3. Request next shift signup
    """
    data = event['data']
    logger.info(f"✅ SHIFT COMPLETED: {data.get('volunteer_id')}")
    logger.info(f"   Hours: {data.get('hours')}, Doors: {data.get('doors')}, Points: {data.get('points')}")
    
    volunteer_id = data.get('volunteer_id')
    hours = data.get('hours', 0)
    doors = data.get('doors', 0)
    points = data.get('points', 0)
    
    # High performer check
    if doors >= 50 or hours >= 4:
        # Send thank you message
        logger.info(f"   🌟 High performer - triggering thank you")
        
        # This would call E30/E31 to send thank you
        self._send_volunteer_thank_you(volunteer_id, {
            'hours': hours,
            'doors': doors,
            'points': points,
            'is_high_performer': True
        })
    
    # Check if streak milestone
    conn = self.connect_database()
    cur = conn.cursor()
    cur.execute("""
        SELECT current_streak FROM volunteers WHERE volunteer_id = %s
    """, (volunteer_id,))
    result = cur.fetchone()
    if result and result[0] in [7, 14, 30]:
        self._celebrate_streak(volunteer_id, result[0])
    conn.close()


def handle_volunteer_grade_changed(self, event):
    """
    Handle volunteer grade change
    
    Actions based on direction:
    - Improved: Congratulate, consider for leadership
    - Declined: Check in, offer support
    """
    data = event['data']
    logger.info(f"📊 GRADE CHANGED: {data.get('volunteer_id')}")
    logger.info(f"   New Grade: {data.get('grade_3d')}, Score: {data.get('composite_score')}")
    
    composite = data.get('composite_score', 50)
    reliability = data.get('reliability', 'C')
    
    # High performer - consider for leadership
    if composite >= 80 and reliability in ['A+', 'A']:
        logger.info(f"   🏆 High performer - flagging for leadership consideration")
        self._flag_for_leadership(data.get('volunteer_id'))
    
    # Low reliability - needs attention
    elif reliability in ['D', 'F']:
        logger.info(f"   ⚠️ Low reliability - scheduling check-in")
        self._schedule_volunteer_checkin(data.get('volunteer_id'))


def handle_volunteer_milestone(self, event):
    """
    Handle volunteer milestone/badge earned
    
    Workflow:
    1. Send congratulations
    2. Share on social (with permission)
    3. Consider promotion
    """
    data = event['data']
    badges = data.get('badges_earned', [])
    
    logger.info(f"🏅 MILESTONE: {data.get('volunteer_id')}")
    logger.info(f"   Badges: {badges}")
    
    volunteer_id = data.get('volunteer_id')
    
    # Send congratulations
    for badge in badges:
        self._send_badge_notification(volunteer_id, badge)
    
    # Check for promotion badges
    promotion_badges = ['HOURS_100', 'LEADERSHIP', 'STREAK_30', 'POINTS_10000']
    if any(b in badges for b in promotion_badges):
        logger.info(f"   🎖️ Promotion-worthy achievement!")
        self._consider_for_promotion(volunteer_id)


def handle_volunteer_churn_risk(self, event):
    """
    Handle high churn risk volunteer
    
    Workflow:
    1. Send re-engagement email
    2. Offer easy shift opportunities
    3. Personal outreach from coordinator
    """
    data = event['data']
    logger.warning(f"⚠️ CHURN RISK HIGH: {data.get('name')}")
    logger.warning(f"   Risk: {data.get('churn_risk')}, Days Inactive: {data.get('days_inactive')}")
    
    volunteer_id = data.get('volunteer_id')
    churn_risk = data.get('churn_risk', 0.5)
    days_inactive = data.get('days_inactive', 0)
    
    # Decision: Only re-engage if not too far gone
    if days_inactive < 90 and churn_risk < 0.9:
        logger.info(f"   ✅ GO DECISION: Triggering re-engagement")
        
        # Request re-engagement content
        content = self.request_content(
            candidate_id=None,  # Platform-wide
            occasion='volunteer_reengagement',
            channel='EMAIL',
            context='churn_prevention'
        )
        
        if content:
            self.trigger_email_campaign(
                candidate_id=None,
                content_uuid=content['content_uuid'],
                recipients=[volunteer_id],
                priority='normal',
                context='volunteer_reengagement'
            )
        
        # Also trigger SMS
        self._send_volunteer_check_in_sms(volunteer_id)
        
        self.publish_decision(
            decision_type='volunteer_reengagement',
            action='reengagement_campaign_triggered',
            volunteer_id=volunteer_id,
            churn_risk=churn_risk
        )
    else:
        logger.info(f"   ⏸️ NO-GO: Volunteer too inactive, manual review needed")


def handle_volunteer_no_show(self, event):
    """
    Handle volunteer no-show
    
    Workflow:
    1. Log the no-show
    2. Send check-in message
    3. Update reliability score
    """
    data = event['data']
    logger.warning(f"❌ NO-SHOW: {data.get('volunteer_id')}")
    
    volunteer_id = data.get('volunteer_id')
    shift_id = data.get('shift_id')
    
    # Send gentle check-in
    self._send_no_show_followup(volunteer_id, shift_id)
    
    # Check if pattern
    conn = self.connect_database()
    cur = conn.cursor()
    cur.execute("""
        SELECT no_shows, total_shifts FROM volunteers WHERE volunteer_id = %s
    """, (volunteer_id,))
    result = cur.fetchone()
    
    if result and result[0] >= 3:
        no_show_rate = result[0] / max(1, result[1])
        if no_show_rate > 0.3:
            logger.warning(f"   🚨 High no-show rate ({no_show_rate:.0%}) - flagging for review")
            self._flag_volunteer_for_review(volunteer_id, 'high_no_show_rate')
    
    conn.close()


# ============================================================================
# HELPER METHODS
# ============================================================================

def _send_volunteer_thank_you(self, volunteer_id: str, stats: dict):
    """Send thank you to volunteer"""
    # Implementation connects to E30/E31
    logger.info(f"   → Sending thank you to {volunteer_id}")


def _celebrate_streak(self, volunteer_id: str, streak_days: int):
    """Celebrate volunteer streak milestone"""
    logger.info(f"   🔥 Celebrating {streak_days}-day streak for {volunteer_id}")


def _flag_for_leadership(self, volunteer_id: str):
    """Flag volunteer for leadership consideration"""
    logger.info(f"   → Flagging {volunteer_id} for leadership")


def _schedule_volunteer_checkin(self, volunteer_id: str):
    """Schedule check-in call with struggling volunteer"""
    logger.info(f"   → Scheduling check-in for {volunteer_id}")


def _send_badge_notification(self, volunteer_id: str, badge_name: str):
    """Send badge earned notification"""
    logger.info(f"   → Badge notification: {badge_name} to {volunteer_id}")


def _consider_for_promotion(self, volunteer_id: str):
    """Consider volunteer for team leader promotion"""
    logger.info(f"   → Considering {volunteer_id} for promotion")


def _send_volunteer_check_in_sms(self, volunteer_id: str):
    """Send check-in SMS to inactive volunteer"""
    logger.info(f"   → Check-in SMS to {volunteer_id}")


def _send_no_show_followup(self, volunteer_id: str, shift_id: str):
    """Send follow-up after no-show"""
    logger.info(f"   → No-show follow-up to {volunteer_id}")


def _flag_volunteer_for_review(self, volunteer_id: str, reason: str):
    """Flag volunteer for manual review"""
    logger.info(f"   → Flagging {volunteer_id} for review: {reason}")


# ============================================================================
# INTEGRATION INSTRUCTIONS
# ============================================================================
"""
To integrate into existing E20 Intelligence Brain:

1. Add VOLUNTEER_EVENT_CHANNELS to the channels list in subscribe_to_events()

2. Add this routing to handle_event():
   
   elif event_type.startswith('volunteer.'):
       self.handle_volunteer_event(event)

3. Add all the handler methods to the IntelligenceBrain class

4. Update the database schema with volunteer_brain_events table

5. Test by publishing events:
   
   redis-cli PUBLISH "volunteer.registered" '{"event_type":"volunteer.registered","data":{"volunteer_id":"test","name":"John Doe"}}'

"""

# ============================================================================
# E20 BRAIN VOLUNTEER DECISION THRESHOLDS
# ============================================================================

VOLUNTEER_THRESHOLDS = {
    # Re-engagement
    'MAX_INACTIVE_DAYS': 90,          # Days before marking as churned
    'REENGAGEMENT_RISK_THRESHOLD': 0.7,  # Churn risk to trigger re-engagement
    
    # Performance
    'HIGH_PERFORMER_DOORS': 50,       # Doors in single shift
    'HIGH_PERFORMER_HOURS': 4,        # Hours in single shift
    
    # Leadership
    'LEADERSHIP_COMPOSITE_MIN': 80,   # Min composite score for leadership
    'LEADERSHIP_RELIABILITY_MIN': 'A', # Min reliability for leadership
    
    # No-show
    'NO_SHOW_RATE_WARNING': 0.2,      # 20% no-show rate triggers warning
    'NO_SHOW_RATE_CRITICAL': 0.3,     # 30% triggers review
    
    # Fatigue
    'VOLUNTEER_CONTACT_COOLDOWN': 48, # Hours between contact attempts
}
