-- =====================================================
-- BROYHILLGOP SUPABASE DATABASE SCHEMA
-- File 2: Campaign Sequence Engine Tables
-- Adaptive Multi-Touch Orchestration
-- =====================================================

-- Table: campaign_sequences
-- Defines the default multi-touch sequence for each campaign type
CREATE TABLE IF NOT EXISTS campaign_sequences (
    sequence_id SERIAL PRIMARY KEY,
    campaign_type_id INT REFERENCES campaign_types(campaign_type_id) ON DELETE CASCADE,
    channel_id INT REFERENCES campaign_channels(channel_id),
    day_offset INT NOT NULL, -- Days from campaign start (negative = before event, 0 = day of)
    sequence_order INT NOT NULL, -- 1, 2, 3, 4... (execution order)
    action_description TEXT NOT NULL,
    psychological_tone_id INT REFERENCES psychological_tones(tone_id),
    target_donor_tiers VARCHAR(50)[], -- ARRAY['A', 'B', 'C']
    active BOOLEAN DEFAULT TRUE,
    estimated_cost_per_contact NUMERIC(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sequences_campaign_type ON campaign_sequences(campaign_type_id);
CREATE INDEX idx_sequences_order ON campaign_sequences(campaign_type_id, sequence_order);

-- Example: Private Donor Home Reception Sequence
-- Campaign Type 1: 7-touch sequence
INSERT INTO campaign_sequences (campaign_type_id, channel_id, day_offset, sequence_order, action_description, target_donor_tiers, estimated_cost_per_contact) VALUES
    (1, 1, -21, 1, 'Send Save the Date email with host details', ARRAY['A', 'B'], 0.10),
    (1, 4, -18, 2, 'Call Center: Co-host recruitment outreach', ARRAY['A'], 15.00),
    (1, 3, -10, 3, 'Mail formal printed invitation (6x9 cardstock)', ARRAY['A', 'B'], 3.20),
    (1, 1, -6, 4, 'Follow-up email with co-host names and agenda', ARRAY['A', 'B'], 0.10),
    (1, 2, -2, 5, 'SMS reminder with RSVP link', ARRAY['A', 'B'], 0.08),
    (1, 5, 0, 6, 'WhatsApp day-of logistics (parking, dress code)', ARRAY['A'], 0.05),
    (1, 1, 2, 7, 'Thank-you email for attendees', ARRAY['A', 'B'], 0.10);

-- Example: FEC Deadline Push Sequence
-- Campaign Type 18: 5-touch email-SMS blitz
INSERT INTO campaign_sequences (campaign_type_id, channel_id, day_offset, sequence_order, action_description, target_donor_tiers, estimated_cost_per_contact) VALUES
    (18, 1, -7, 1, 'Email countdown: 7 days until FEC deadline', ARRAY['A', 'B', 'C', 'D', 'U'], 0.10),
    (18, 1, -5, 2, 'Email countdown: 5 days - urgency messaging', ARRAY['A', 'B', 'C', 'D'], 0.10),
    (18, 2, -3, 3, 'SMS blast: 72 hours left', ARRAY['A', 'B', 'C'], 0.08),
    (18, 1, -1, 4, 'Email final push: 24 hours', ARRAY['A', 'B', 'C', 'D'], 0.10),
    (18, 4, -0.5, 5, 'Call Center: Non-responders (final 12 hours)', ARRAY['A', 'B'], 15.00);

-- Example: Meet-and-Greet Free Event
-- Campaign Type 6: 4-touch low-cost sequence
INSERT INTO campaign_sequences (campaign_type_id, channel_id, day_offset, sequence_order, action_description, target_donor_tiers, estimated_cost_per_contact) VALUES
    (6, 1, -7, 1, 'Email invitation to free meet-and-greet', ARRAY['D', 'U'], 0.10),
    (6, 1, -2, 2, 'Email reminder with parking details', ARRAY['D', 'U'], 0.10),
    (6, 2, -1, 3, 'SMS day-before reminder', ARRAY['D', 'U'], 0.08),
    (6, 1, 1, 4, 'Follow-up email with donation link', ARRAY['D', 'U'], 0.10);

-- =====================================================
-- Table: campaign_events
-- Each specific campaign instance created by candidates
-- =====================================================
CREATE TABLE IF NOT EXISTS campaign_events (
    campaign_event_id SERIAL PRIMARY KEY,
    candidate_id INT REFERENCES candidates(candidate_id),
    campaign_type_id INT REFERENCES campaign_types(campaign_type_id),
    event_name VARCHAR(255) NOT NULL,
    event_date DATE NOT NULL,
    location VARCHAR(500),
    venue_name VARCHAR(255),
    budget NUMERIC(12,2),
    revenue_goal NUMERIC(12,2),
    actual_revenue NUMERIC(12,2) DEFAULT 0,
    total_invitations_sent INT DEFAULT 0,
    total_rsvps INT DEFAULT 0,
    total_attendees INT DEFAULT 0,
    status VARCHAR(50) DEFAULT 'planned', -- 'planned', 'launched', 'in_progress', 'completed', 'cancelled'
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_events_candidate ON campaign_events(candidate_id);
CREATE INDEX idx_events_type ON campaign_events(campaign_type_id);
CREATE INDEX idx_events_status ON campaign_events(status);
CREATE INDEX idx_events_date ON campaign_events(event_date DESC);

-- =====================================================
-- Table: donor_communications
-- Logs every single contact with each donor
-- =====================================================
CREATE TABLE IF NOT EXISTS donor_communications (
    communication_id SERIAL PRIMARY KEY,
    donor_id INT REFERENCES donors(donor_id),
    campaign_event_id INT REFERENCES campaign_events(campaign_event_id),
    channel_id INT REFERENCES campaign_channels(channel_id),
    sequence_id INT REFERENCES campaign_sequences(sequence_id),
    template_id INT, -- Reference to template used
    sent_at TIMESTAMP DEFAULT NOW(),
    delivered_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    response_at TIMESTAMP,
    rsvp_status VARCHAR(20), -- 'yes', 'no', 'maybe', 'pending'
    attended BOOLEAN DEFAULT FALSE,
    donated BOOLEAN DEFAULT FALSE,
    donation_amount NUMERIC(10,2) DEFAULT 0,
    cost NUMERIC(10,2), -- Cost of this specific communication
    channel_used VARCHAR(50), -- Actual channel if different from planned
    error_message TEXT, -- If delivery failed
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_comms_donor ON donor_communications(donor_id);
CREATE INDEX idx_comms_campaign ON donor_communications(campaign_event_id);
CREATE INDEX idx_comms_sent_at ON donor_communications(sent_at DESC);
CREATE INDEX idx_comms_donated ON donor_communications(donated) WHERE donated = TRUE;

-- =====================================================
-- Table: sequence_modifications
-- Tracks ML-driven changes to sequences over time
-- =====================================================
CREATE TABLE IF NOT EXISTS sequence_modifications (
    modification_id SERIAL PRIMARY KEY,
    campaign_type_id INT REFERENCES campaign_types(campaign_type_id),
    original_sequence_id INT REFERENCES campaign_sequences(sequence_id),
    modification_type VARCHAR(50), -- 'channel_swap', 'timing_adjustment', 'removed', 'added'
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    ml_confidence_score NUMERIC(5,2),
    expected_improvement NUMERIC(10,2), -- Predicted ROI improvement %
    actual_improvement NUMERIC(10,2), -- Measured after deployment
    applied_at TIMESTAMP DEFAULT NOW(),
    measured_at TIMESTAMP
);

CREATE INDEX idx_modifications_campaign_type ON sequence_modifications(campaign_type_id);

-- Comments
COMMENT ON TABLE campaign_sequences IS 'Default multi-touch sequences per campaign type';
COMMENT ON TABLE campaign_events IS 'Individual campaign instances created by candidates';
COMMENT ON TABLE donor_communications IS 'Complete log of every donor interaction';
COMMENT ON TABLE sequence_modifications IS 'ML-driven sequence changes with before/after metrics';
