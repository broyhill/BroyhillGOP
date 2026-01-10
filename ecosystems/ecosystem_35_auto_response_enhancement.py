#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 35 ENHANCEMENT: AUTO-RESPONSE & THANK YOU ENGINE
============================================================================

Polite automated responses triggered by:
- Voicemail left (60 second delay, then SMS thank you)
- SMS received (immediate or delayed response)
- Donation made (personalized thank you)
- RSVP confirmed (confirmation + details)
- Callback requested (acknowledgment + ETA)
- Volunteer signup (welcome + next steps)

All responses are:
- Personalized with {{first_name}}, {{last_name}}
- Timed appropriately (immediate vs delayed)
- Channel-appropriate (SMS, email, or call back)
- Tracked for analytics
- A/B testable

============================================================================
"""

# Add these tables and methods to ecosystem_35_interactive_comm_hub_complete.py

AUTO_RESPONSE_SCHEMA_ADDITION = """
-- ============================================================================
-- AUTO-RESPONSE & THANK YOU SYSTEM
-- ============================================================================

-- Auto-Response Templates
CREATE TABLE IF NOT EXISTS auto_response_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    name VARCHAR(255) NOT NULL,
    candidate_id UUID,
    
    -- Trigger
    trigger_type VARCHAR(100) NOT NULL,
    trigger_intent VARCHAR(100),
    
    -- Timing
    delay_seconds INTEGER DEFAULT 60,
    send_immediately BOOLEAN DEFAULT false,
    
    -- Response channel
    response_channel VARCHAR(50) DEFAULT 'sms',
    
    -- Content
    message_template TEXT NOT NULL,
    subject_template VARCHAR(500),
    
    -- Personalization available:
    -- {{first_name}}, {{last_name}}, {{full_name}}
    -- {{donation_amount}}, {{event_name}}, {{event_date}}
    -- {{candidate_name}}, {{candidate_first_name}}
    -- {{callback_time}}, {{volunteer_role}}
    
    -- Signature
    include_signature BOOLEAN DEFAULT true,
    signature_name VARCHAR(255),
    signature_title VARCHAR(255),
    
    -- Media
    include_image BOOLEAN DEFAULT false,
    image_url TEXT,
    
    -- A/B Testing
    ab_test_id UUID,
    variant_code VARCHAR(10),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    priority INTEGER DEFAULT 50,
    
    -- Stats
    times_sent INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auto_templates_trigger ON auto_response_templates(trigger_type);
CREATE INDEX IF NOT EXISTS idx_auto_templates_candidate ON auto_response_templates(candidate_id);

-- Scheduled Auto-Responses (queued for sending)
CREATE TABLE IF NOT EXISTS auto_response_queue (
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Template
    template_id UUID REFERENCES auto_response_templates(template_id),
    
    -- Recipient
    recipient_phone VARCHAR(20),
    recipient_email VARCHAR(255),
    recipient_name VARCHAR(255),
    contact_id UUID,
    
    -- Personalization data
    personalization_data JSONB DEFAULT '{}',
    
    -- Rendered content
    rendered_message TEXT,
    rendered_subject VARCHAR(500),
    
    -- Source
    source_type VARCHAR(50),
    source_id UUID,
    voicemail_id UUID,
    donation_id UUID,
    rsvp_id UUID,
    
    -- Timing
    scheduled_for TIMESTAMP NOT NULL,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    
    -- Tracking
    provider_message_id VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auto_queue_scheduled ON auto_response_queue(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_auto_queue_status ON auto_response_queue(status);

-- Auto-Response Delivery Log
CREATE TABLE IF NOT EXISTS auto_response_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    queue_id UUID REFERENCES auto_response_queue(queue_id),
    template_id UUID,
    
    -- Recipient
    recipient_phone VARCHAR(20),
    recipient_email VARCHAR(255),
    contact_id UUID,
    
    -- Content sent
    channel VARCHAR(50),
    message_sent TEXT,
    
    -- Trigger info
    trigger_type VARCHAR(100),
    trigger_source_id UUID,
    
    -- Delivery
    status VARCHAR(50),
    delivered_at TIMESTAMP,
    
    -- Response (if any)
    recipient_replied BOOLEAN DEFAULT false,
    reply_message TEXT,
    reply_at TIMESTAMP,
    
    sent_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auto_log_trigger ON auto_response_log(trigger_type);

-- Default Templates (seeded on deployment)
INSERT INTO auto_response_templates (name, trigger_type, delay_seconds, message_template, signature_name)
VALUES 
-- Voicemail Thank You (60 second delay)
('Voicemail Thank You', 'voicemail', 60, 
'Hi {{first_name}}, thank you so much for your message! I personally review every voicemail and truly appreciate you taking the time to reach out. I''ll get back to you as soon as possible.

God bless,
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- Voicemail from VIP/Major Donor (immediate)
('VIP Voicemail Response', 'voicemail_vip', 0,
'{{first_name}}, thank you for calling! Your support means the world to me. I saw your message come in and wanted you to know I''ll be calling you back personally very soon.

With gratitude,
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- Donation Thank You (immediate)
('Donation Thank You', 'donation', 0,
'{{first_name}}, WOW! Thank you so much for your generous ${{donation_amount}} contribution! Patriots like you make this campaign possible. Your support gives me the strength to keep fighting for our community.

With deep gratitude,
{{candidate_first_name}}

P.S. - Your donation receipt has been emailed to you.', 'Sheriff Jim Davis'),

-- Major Donation Thank You ($500+)
('Major Donation Thank You', 'donation_major', 0,
'{{first_name}}, I am truly humbled by your incredible ${{donation_amount}} investment in our campaign. I would love to personally thank you - expect a call from me in the next day or two.

Your belief in our mission to keep our community safe means everything. Thank you for standing with me.

With sincere gratitude,
{{candidate_name}}', 'Sheriff Jim Davis'),

-- Recurring Donation Thank You
('Recurring Donation Thank You', 'donation_recurring', 0,
'{{first_name}}, thank you for becoming a sustaining supporter with your monthly ${{donation_amount}} contribution! Monthly donors are the backbone of our campaign, providing the steady support we need to win.

Welcome to the team!
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- RSVP Confirmation
('RSVP Confirmation', 'rsvp', 0,
'Great news, {{first_name}}! You''re confirmed for {{event_name}} on {{event_date}}! 

I can''t wait to meet you in person. Details and directions will be sent closer to the event.

See you there!
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- Callback Request Acknowledgment
('Callback Acknowledgment', 'callback_request', 0,
'Hi {{first_name}}, we received your request for a callback. A member of our team will call you back within 24 hours. If you need immediate assistance, please call us at {{campaign_phone}}.

Thank you for your patience!
Team {{candidate_last_name}}', 'Team Davis'),

-- Volunteer Welcome
('Volunteer Welcome', 'volunteer', 0,
'{{first_name}}, THANK YOU for volunteering! Patriots like you are the heart of our campaign. 

Our volunteer coordinator will reach out within 48 hours to discuss how you can make the biggest impact.

Together, we WILL win!
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- General SMS Response (60 second delay)
('General SMS Thank You', 'sms_general', 60,
'Hi {{first_name}}, thank you for reaching out! I appreciate every message from supporters like you. How can we help you today?

Reply DONATE, RSVP, VOLUNTEER, or CALL for more options.', 'Team Davis'),

-- After Hours Voicemail
('After Hours Response', 'voicemail_after_hours', 0,
'Hi {{first_name}}, thank you for your message! Our office is currently closed, but I wanted you to know your call is important to me. We''ll follow up with you during business hours.

Thank you for your support!
{{candidate_first_name}}', 'Sheriff Jim Davis'),

-- Question/Info Request
('Info Request Response', 'info_request', 30,
'Hi {{first_name}}, thank you for your interest! Here are some ways to learn more about our campaign:

🌐 Website: {{website_url}}
📧 Email: {{campaign_email}}
📞 Call: {{campaign_phone}}

What specific information can we help you with?', 'Team Davis')

ON CONFLICT DO NOTHING;

-- View for monitoring auto-responses
CREATE OR REPLACE VIEW v_auto_response_stats AS
SELECT 
    t.template_id,
    t.name,
    t.trigger_type,
    t.delay_seconds,
    t.times_sent,
    COUNT(l.log_id) as actual_sent,
    COUNT(l.log_id) FILTER (WHERE l.recipient_replied = true) as replies_received,
    ROUND(COUNT(l.log_id) FILTER (WHERE l.recipient_replied = true)::DECIMAL / 
          NULLIF(COUNT(l.log_id), 0) * 100, 2) as reply_rate
FROM auto_response_templates t
LEFT JOIN auto_response_log l ON t.template_id = l.template_id
GROUP BY t.template_id, t.name, t.trigger_type, t.delay_seconds, t.times_sent;
"""


class AutoResponseEngine:
    """Auto-Response & Thank You System"""
    
    def __init__(self, db_url: str):
        self.db_url = db_url
    
    def _get_db(self):
        import psycopg2
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # TEMPLATE MANAGEMENT
    # ========================================================================
    
    def create_template(self, name: str, trigger_type: str,
                       message_template: str,
                       delay_seconds: int = 60,
                       candidate_id: str = None,
                       response_channel: str = 'sms',
                       signature_name: str = None) -> str:
        """Create a custom auto-response template"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO auto_response_templates (
                name, trigger_type, message_template, delay_seconds,
                candidate_id, response_channel, signature_name
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING template_id
        """, (name, trigger_type, message_template, delay_seconds,
              candidate_id, response_channel, signature_name))
        
        template_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return template_id
    
    # ========================================================================
    # TRIGGER AUTO-RESPONSES
    # ========================================================================
    
    def trigger_voicemail_response(self, voicemail_id: str, contact_phone: str,
                                   contact_name: str = None,
                                   contact_id: str = None,
                                   is_vip: bool = False,
                                   is_after_hours: bool = False,
                                   candidate_id: str = None) -> str:
        """Queue auto-response for voicemail"""
        
        # Determine which template to use
        if is_vip:
            trigger_type = 'voicemail_vip'
        elif is_after_hours:
            trigger_type = 'voicemail_after_hours'
        else:
            trigger_type = 'voicemail'
        
        return self._queue_response(
            trigger_type=trigger_type,
            recipient_phone=contact_phone,
            recipient_name=contact_name,
            contact_id=contact_id,
            source_type='voicemail',
            source_id=voicemail_id,
            candidate_id=candidate_id,
            personalization_data={
                'first_name': contact_name.split()[0] if contact_name else 'Friend'
            }
        )
    
    def trigger_donation_response(self, donation_id: str, donor_phone: str,
                                  donor_name: str, amount: float,
                                  is_recurring: bool = False,
                                  contact_id: str = None,
                                  candidate_id: str = None) -> str:
        """Queue auto-response for donation"""
        
        # Determine template based on amount and type
        if is_recurring:
            trigger_type = 'donation_recurring'
        elif amount >= 500:
            trigger_type = 'donation_major'
        else:
            trigger_type = 'donation'
        
        first_name = donor_name.split()[0] if donor_name else 'Friend'
        
        return self._queue_response(
            trigger_type=trigger_type,
            recipient_phone=donor_phone,
            recipient_name=donor_name,
            contact_id=contact_id,
            source_type='donation',
            source_id=donation_id,
            candidate_id=candidate_id,
            personalization_data={
                'first_name': first_name,
                'full_name': donor_name,
                'donation_amount': f"{amount:.2f}"
            }
        )
    
    def trigger_rsvp_response(self, rsvp_id: str, contact_phone: str,
                             contact_name: str, event_name: str,
                             event_date: str,
                             contact_id: str = None,
                             candidate_id: str = None) -> str:
        """Queue auto-response for RSVP"""
        
        first_name = contact_name.split()[0] if contact_name else 'Friend'
        
        return self._queue_response(
            trigger_type='rsvp',
            recipient_phone=contact_phone,
            recipient_name=contact_name,
            contact_id=contact_id,
            source_type='rsvp',
            source_id=rsvp_id,
            candidate_id=candidate_id,
            personalization_data={
                'first_name': first_name,
                'event_name': event_name,
                'event_date': event_date
            }
        )
    
    def trigger_callback_response(self, source_id: str, contact_phone: str,
                                  contact_name: str = None,
                                  contact_id: str = None,
                                  candidate_id: str = None) -> str:
        """Queue auto-response for callback request"""
        
        return self._queue_response(
            trigger_type='callback_request',
            recipient_phone=contact_phone,
            recipient_name=contact_name,
            contact_id=contact_id,
            source_type='callback',
            source_id=source_id,
            candidate_id=candidate_id,
            personalization_data={
                'first_name': contact_name.split()[0] if contact_name else 'Friend'
            }
        )
    
    def trigger_volunteer_response(self, source_id: str, contact_phone: str,
                                   contact_name: str,
                                   contact_id: str = None,
                                   candidate_id: str = None) -> str:
        """Queue auto-response for volunteer signup"""
        
        return self._queue_response(
            trigger_type='volunteer',
            recipient_phone=contact_phone,
            recipient_name=contact_name,
            contact_id=contact_id,
            source_type='volunteer',
            source_id=source_id,
            candidate_id=candidate_id,
            personalization_data={
                'first_name': contact_name.split()[0] if contact_name else 'Friend'
            }
        )
    
    def trigger_sms_response(self, source_id: str, contact_phone: str,
                            contact_name: str = None,
                            message_intent: str = 'general',
                            contact_id: str = None,
                            candidate_id: str = None) -> str:
        """Queue auto-response for incoming SMS"""
        
        trigger_type = f'sms_{message_intent}' if message_intent else 'sms_general'
        
        return self._queue_response(
            trigger_type=trigger_type,
            recipient_phone=contact_phone,
            recipient_name=contact_name,
            contact_id=contact_id,
            source_type='sms',
            source_id=source_id,
            candidate_id=candidate_id,
            personalization_data={
                'first_name': contact_name.split()[0] if contact_name else 'Friend'
            }
        )
    
    # ========================================================================
    # CORE QUEUE METHOD
    # ========================================================================
    
    def _queue_response(self, trigger_type: str, recipient_phone: str,
                       recipient_name: str, source_type: str,
                       source_id: str, candidate_id: str = None,
                       contact_id: str = None,
                       personalization_data: dict = None) -> str:
        """Queue an auto-response for sending"""
        conn = self._get_db()
        cur = conn.cursor()
        from psycopg2.extras import RealDictCursor
        cur2 = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get template
        cur2.execute("""
            SELECT * FROM auto_response_templates 
            WHERE trigger_type = %s AND is_active = true
            AND (candidate_id = %s OR candidate_id IS NULL)
            ORDER BY candidate_id NULLS LAST, priority DESC
            LIMIT 1
        """, (trigger_type, candidate_id))
        
        template = cur2.fetchone()
        
        if not template:
            # Fall back to general template
            cur2.execute("""
                SELECT * FROM auto_response_templates 
                WHERE trigger_type = 'sms_general' AND is_active = true
                LIMIT 1
            """)
            template = cur2.fetchone()
        
        if not template:
            conn.close()
            return None
        
        # Get candidate info for personalization
        candidate_data = {}
        if candidate_id:
            cur2.execute("""
                SELECT first_name, last_name, 
                       first_name || ' ' || last_name as full_name
                FROM candidates WHERE candidate_id = %s
            """, (candidate_id,))
            cand = cur2.fetchone()
            if cand:
                candidate_data = {
                    'candidate_name': cand['full_name'],
                    'candidate_first_name': cand['first_name'],
                    'candidate_last_name': cand['last_name']
                }
        
        # Merge personalization data
        all_data = {
            **(personalization_data or {}),
            **candidate_data,
            'signature_name': template['signature_name'] or ''
        }
        
        # Render message
        rendered = template['message_template']
        for key, value in all_data.items():
            rendered = rendered.replace('{{' + key + '}}', str(value or ''))
        
        # Calculate send time
        from datetime import datetime, timedelta
        delay = template['delay_seconds'] or 0
        scheduled_for = datetime.now() + timedelta(seconds=delay)
        
        if template['send_immediately']:
            scheduled_for = datetime.now()
        
        # Queue the response
        cur.execute("""
            INSERT INTO auto_response_queue (
                template_id, recipient_phone, recipient_name, contact_id,
                personalization_data, rendered_message, scheduled_for,
                source_type, source_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING queue_id
        """, (
            template['template_id'], recipient_phone, recipient_name, contact_id,
            json.dumps(all_data), rendered, scheduled_for,
            source_type, source_id
        ))
        
        queue_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return queue_id
    
    # ========================================================================
    # SEND QUEUED RESPONSES
    # ========================================================================
    
    def process_queue(self, limit: int = 100) -> int:
        """Process pending auto-responses (called by scheduler)"""
        conn = self._get_db()
        cur = conn.cursor()
        from psycopg2.extras import RealDictCursor
        cur2 = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get pending responses that are ready to send
        cur2.execute("""
            SELECT * FROM auto_response_queue
            WHERE status = 'pending' AND scheduled_for <= NOW()
            ORDER BY scheduled_for
            LIMIT %s
        """, (limit,))
        
        pending = cur2.fetchall()
        sent_count = 0
        
        for item in pending:
            # Send via SMS (would integrate with E31)
            success = self._send_sms(item['recipient_phone'], item['rendered_message'])
            
            if success:
                # Update queue
                cur.execute("""
                    UPDATE auto_response_queue SET
                        status = 'sent',
                        sent_at = NOW()
                    WHERE queue_id = %s
                """, (item['queue_id'],))
                
                # Log
                cur.execute("""
                    INSERT INTO auto_response_log (
                        queue_id, template_id, recipient_phone, contact_id,
                        channel, message_sent, trigger_type, trigger_source_id, status
                    ) VALUES (%s, %s, %s, %s, 'sms', %s, %s, %s, 'sent')
                """, (
                    item['queue_id'], item['template_id'],
                    item['recipient_phone'], item['contact_id'],
                    item['rendered_message'], item['source_type'], item['source_id']
                ))
                
                # Update template stats
                cur.execute("""
                    UPDATE auto_response_templates SET times_sent = times_sent + 1
                    WHERE template_id = %s
                """, (item['template_id'],))
                
                sent_count += 1
            else:
                cur.execute("""
                    UPDATE auto_response_queue SET status = 'failed' WHERE queue_id = %s
                """, (item['queue_id'],))
        
        conn.commit()
        conn.close()
        
        return sent_count
    
    def _send_sms(self, phone: str, message: str) -> bool:
        """Send SMS (integrates with E31)"""
        # In production, calls E31 SMS system
        print(f"📱 Sending to {phone}: {message[:50]}...")
        return True
    
    # ========================================================================
    # STATS
    # ========================================================================
    
    def get_stats(self) -> dict:
        """Get auto-response statistics"""
        conn = self._get_db()
        from psycopg2.extras import RealDictCursor
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                (SELECT COUNT(*) FROM auto_response_templates WHERE is_active = true) as active_templates,
                (SELECT COUNT(*) FROM auto_response_queue WHERE status = 'pending') as pending_queue,
                (SELECT COUNT(*) FROM auto_response_queue WHERE status = 'sent') as total_sent,
                (SELECT COUNT(*) FROM auto_response_log WHERE sent_at > NOW() - INTERVAL '24 hours') as sent_last_24h,
                (SELECT COUNT(*) FROM auto_response_log WHERE recipient_replied = true) as total_replies
        """)
        
        stats = dict(cur.fetchone())
        
        # By trigger type
        cur.execute("SELECT * FROM v_auto_response_stats ORDER BY actual_sent DESC")
        stats['by_template'] = [dict(r) for r in cur.fetchall()]
        
        conn.close()
        return stats


# Integration with E35 InteractiveCommunicationHub
def integrate_auto_response_with_hub():
    """
    Add these methods to InteractiveCommunicationHub class:
    
    In save_voicemail():
        # After saving voicemail, trigger auto-response
        auto_engine = AutoResponseEngine(self.db_url)
        auto_engine.trigger_voicemail_response(
            voicemail_id=message_id,
            contact_phone=call['from_phone'],
            contact_name=call['contact_name'],
            is_vip=call.get('is_vip', False),
            is_after_hours=not self._is_business_hours()
        )
    
    In process_sms_response() when action == 'donate':
        auto_engine = AutoResponseEngine(self.db_url)
        # Donation response will be triggered when donation completes
    
    In process_sms_response() when action == 'rsvp':
        auto_engine = AutoResponseEngine(self.db_url)
        auto_engine.trigger_rsvp_response(
            rsvp_id=result['rsvp_id'],
            contact_phone=from_phone,
            contact_name=contact_name,
            event_name="Campaign Rally",
            event_date="December 20, 2025"
        )
    
    In process_sms_response() when action == 'callback':
        auto_engine = AutoResponseEngine(self.db_url)
        auto_engine.trigger_callback_response(
            source_id=str(uuid.uuid4()),
            contact_phone=from_phone,
            contact_name=contact_name
        )
    
    In process_sms_response() when action == 'volunteer':
        auto_engine = AutoResponseEngine(self.db_url)
        auto_engine.trigger_volunteer_response(
            source_id=str(uuid.uuid4()),
            contact_phone=from_phone,
            contact_name=contact_name
        )
    """
    pass


import json

if __name__ == "__main__":
    print("=" * 70)
    print("📱 AUTO-RESPONSE & THANK YOU ENGINE")
    print("=" * 70)
    print("""
TRIGGERS:
  • voicemail - 60 sec delay, personalized thank you
  • voicemail_vip - Immediate, personal from candidate
  • voicemail_after_hours - Immediate, explains office closed
  • donation - Immediate, celebrates contribution
  • donation_major ($500+) - Immediate, promises personal call
  • donation_recurring - Immediate, welcomes to sustainer program
  • rsvp - Immediate, confirms with event details
  • callback_request - Immediate, confirms 24hr callback
  • volunteer - Immediate, welcomes and explains next steps
  • sms_general - 60 sec delay, friendly response

PERSONALIZATION VARIABLES:
  {{first_name}}, {{last_name}}, {{full_name}}
  {{donation_amount}}
  {{event_name}}, {{event_date}}
  {{candidate_name}}, {{candidate_first_name}}

To deploy, add AUTO_RESPONSE_SCHEMA_ADDITION to E35 schema.
    """)
