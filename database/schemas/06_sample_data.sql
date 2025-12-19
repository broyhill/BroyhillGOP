-- =====================================================
-- BROYHILLGOP SUPABASE DATABASE SCHEMA
-- File 6: Sample Data Inserts
-- Test Data for Development & Demo
-- =====================================================

-- =====================================================
-- SECTION 1: Sample Candidates
-- =====================================================
INSERT INTO candidates (first_name, last_name, office_type, district, county, email, phone) VALUES
    ('Sarah', 'Mitchell', 'State House', 'District 35', 'Wake', 'sarah.mitchell@campaign.com', '919-555-0101'),
    ('John', 'Davis', 'State Senate', 'District 14', 'Mecklenburg', 'john.davis@campaign.com', '704-555-0102'),
    ('Tom', 'Johnson', 'County Sheriff', NULL, 'Alamance', 'tom.johnson@sheriff.com', '336-555-0103'),
    ('Lisa', 'Brown', 'School Board', 'Mecklenburg County Schools', 'Mecklenburg', 'lisa.brown@schoolboard.com', '704-555-0104'),
    ('Robert', 'Smith', 'District Court Judge', 'District 10', 'Durham', 'robert.smith@courts.nc.gov', '919-555-0105'),
    ('Patricia', 'Lee', 'Mayor', 'Town of Cary', 'Wake', 'patricia.lee@cary.gov', '919-555-0106'),
    ('Michael', 'Chen', 'State House', 'District 42', 'Wake', 'michael.chen@campaign.com', '919-555-0107'),
    ('Jane', 'Wilson', 'County Commissioner', 'District 3', 'Guilford', 'jane.wilson@county.gov', '336-555-0108');

-- =====================================================
-- SECTION 2: Sample Donors (20 examples)
-- =====================================================
INSERT INTO donors (first_name, last_name, tier, age, occupation, household_income, contribution_total_2yr, issue_scores, county) VALUES
    -- Tier A (Mega Donors)
    ('Susan', 'Thompson', 'A', 58, 'Healthcare Executive', 750000, 125000, '{"healthcare": 90, "education": 85, "crime": 70}', 'Wake'),
    ('Richard', 'Anderson', 'A', 62, 'Business Owner', 1200000, 200000, '{"economy": 95, "tax_policy": 90, "small_business": 95}', 'Mecklenburg'),

    -- Tier B (Major Donors)
    ('Jennifer', 'Martinez', 'B', 45, 'Physician', 450000, 50000, '{"healthcare": 85, "opioid_crisis": 80, "education": 75}', 'Durham'),
    ('David', 'White', 'B', 52, 'Attorney', 380000, 45000, '{"crime": 85, "second_amendment": 75, "economy": 70}', 'Wake'),
    ('Emily', 'Taylor', 'B', 39, 'Small Business Owner', 320000, 35000, '{"tax_policy": 80, "small_business": 90, "economy": 85}', 'Guilford'),

    -- Tier C (Mid-Level Donors)
    ('James', 'Harris', 'C', 48, 'Accountant', 180000, 15000, '{"tax_policy": 75, "economy": 70, "education": 65}', 'Wake'),
    ('Linda', 'Clark', 'C', 55, 'Retired Teacher', 95000, 12000, '{"education": 90, "school_choice": 85, "family_values": 80}', 'Mecklenburg'),
    ('Robert', 'Lewis', 'C', 41, 'Law Enforcement', 78000, 10000, '{"crime": 95, "second_amendment": 90, "opioid_crisis": 85}', 'Alamance'),
    ('Mary', 'Walker', 'C', 50, 'Nurse', 82000, 11000, '{"healthcare": 85, "opioid_crisis": 80, "family_values": 75}', 'Durham'),
    ('William', 'Hall', 'C', 37, 'IT Professional', 125000, 13000, '{"economy": 70, "tax_policy": 75, "education": 60}', 'Wake'),

    -- Tier D (Minor Donors)
    ('Barbara', 'Allen', 'D', 63, 'Retired', 55000, 5000, '{"healthcare": 80, "family_values": 85, "veterans": 75}', 'Guilford'),
    ('Thomas', 'Young', 'D', 34, 'Sales Representative', 68000, 4500, '{"economy": 65, "tax_policy": 60, "small_business": 70}', 'Wake'),
    ('Karen', 'King', 'D', 46, 'Administrative Assistant', 52000, 3800, '{"education": 75, "school_choice": 70, "family_values": 80}', 'Mecklenburg'),
    ('Steven', 'Wright', 'D', 29, 'Construction Worker', 48000, 2500, '{"economy": 70, "immigration": 65, "second_amendment": 75}', 'Alamance'),
    ('Nancy', 'Lopez', 'D', 58, 'Realtor', 95000, 6200, '{"economy": 75, "tax_policy": 70, "small_business": 65}', 'Durham'),

    -- Tier U (Small Donors)
    ('Daniel', 'Hill', 'U', 25, 'Student', 15000, 500, '{"education": 60, "economy": 55, "immigration": 50}', 'Wake'),
    ('Michelle', 'Scott', 'U', 31, 'Retail Manager', 42000, 750, '{"economy": 65, "family_values": 70, "education": 60}', 'Guilford'),
    ('Kenneth', 'Green', 'U', 68, 'Retired Military', 38000, 1000, '{"veterans": 95, "crime": 80, "second_amendment": 85}', 'Mecklenburg'),
    ('Betty', 'Adams', 'U', 44, 'Daycare Provider', 35000, 300, '{"education": 75, "family_values": 85, "healthcare": 65}', 'Durham'),
    ('Paul', 'Baker', 'U', 52, 'Truck Driver', 58000, 600, '{"economy": 70, "immigration": 75, "second_amendment": 70}', 'Alamance');

-- Add contact information for first 5 donors
INSERT INTO phone_numbers (donor_id, phone_number, phone_type, is_primary, confidence_score, carrier_verified) VALUES
    (1, '919-555-1001', 'Mobile', TRUE, 95, TRUE),
    (2, '704-555-1002', 'Mobile', TRUE, 98, TRUE),
    (3, '919-555-1003', 'Mobile', TRUE, 92, TRUE),
    (4, '919-555-1004', 'Mobile', TRUE, 90, TRUE),
    (5, '336-555-1005', 'Mobile', TRUE, 88, TRUE);

INSERT INTO email_addresses (donor_id, email_address, email_type, is_primary, confidence_score, smtp_verified) VALUES
    (1, 'susan.thompson@email.com', 'Personal', TRUE, 100, TRUE),
    (2, 'r.anderson@business.com', 'Business', TRUE, 100, TRUE),
    (3, 'jennifer.martinez@hospital.org', 'Business', TRUE, 98, TRUE),
    (4, 'david.white@lawfirm.com', 'Business', TRUE, 100, TRUE),
    (5, 'emily.taylor@smallbiz.com', 'Business', TRUE, 95, TRUE);

INSERT INTO physical_addresses (donor_id, address_line1, city, state, zip, county, is_primary, usps_verified) VALUES
    (1, '1234 Oak Street', 'Raleigh', 'NC', '27601', 'Wake', TRUE, TRUE),
    (2, '5678 Main Avenue', 'Charlotte', 'NC', '28202', 'Mecklenburg', TRUE, TRUE),
    (3, '910 Medical Drive', 'Durham', 'NC', '27701', 'Durham', TRUE, TRUE),
    (4, '2468 Legal Lane', 'Raleigh', 'NC', '27605', 'Wake', TRUE, TRUE),
    (5, '1357 Business Blvd', 'Greensboro', 'NC', '27401', 'Guilford', TRUE, TRUE);

-- =====================================================
-- SECTION 3: Sample Issue Heat Map Data
-- =====================================================
-- Rep. Sarah Mitchell (Healthcare focus)
INSERT INTO issue_heat_map (candidate_id, issue_id, intensity_score, committee_chair, legislative_activity_count) VALUES
    (1, 1, 100, TRUE, 12),  -- Healthcare
    (1, 12, 70, FALSE, 3),   -- School Choice
    (1, 13, 85, FALSE, 5);   -- Opioid Crisis

-- Sen. John Davis (Education focus)
INSERT INTO issue_heat_map (candidate_id, issue_id, intensity_score, committee_chair, legislative_activity_count) VALUES
    (2, 2, 100, TRUE, 15),   -- Education
    (2, 12, 95, FALSE, 8);   -- School Choice

-- Sheriff Tom Johnson (Crime focus)
INSERT INTO issue_heat_map (candidate_id, issue_id, intensity_score, committee_chair, legislative_activity_count) VALUES
    (3, 3, 100, FALSE, 0),   -- Crime & Public Safety
    (3, 13, 95, FALSE, 0),   -- Opioid Crisis
    (3, 7, 90, FALSE, 0),    -- Second Amendment
    (3, 6, 85, FALSE, 0);    -- Immigration

-- =====================================================
-- SECTION 4: Sample Campaign Event
-- =====================================================
INSERT INTO campaign_events (candidate_id, campaign_type_id, event_name, event_date, location, venue_name, budget, revenue_goal, status) VALUES
    (1, 1, 'Healthcare Victory Reception', '2025-11-15', '1234 Oak Street, Raleigh, NC', 'Thompson Residence', 5000, 100000, 'planned');

-- =====================================================
-- SECTION 5: Sample Donor Communications
-- Simulate a fundraising event sequence
-- =====================================================
-- Email Save the Date (Day -21)
INSERT INTO donor_communications (donor_id, campaign_event_id, channel_id, sequence_id, sent_at, opened, clicked, cost) VALUES
    (1, 1, 1, 1, NOW() - INTERVAL '21 days', TRUE, TRUE, 0.10),
    (2, 1, 1, 1, NOW() - INTERVAL '21 days', TRUE, FALSE, 0.10),
    (3, 1, 1, 1, NOW() - INTERVAL '21 days', TRUE, TRUE, 0.10),
    (4, 1, 1, 1, NOW() - INTERVAL '21 days', FALSE, FALSE, 0.10),
    (5, 1, 1, 1, NOW() - INTERVAL '21 days', TRUE, TRUE, 0.10);

-- Printed invitation (Day -10)
INSERT INTO donor_communications (donor_id, campaign_event_id, channel_id, sequence_id, sent_at, opened, rsvp_status, cost) VALUES
    (1, 1, 3, 3, NOW() - INTERVAL '10 days', TRUE, 'yes', 3.20),
    (2, 1, 3, 3, NOW() - INTERVAL '10 days', TRUE, 'yes', 3.20),
    (3, 1, 3, 3, NOW() - INTERVAL '10 days', TRUE, 'maybe', 3.20),
    (4, 1, 3, 3, NOW() - INTERVAL '10 days', FALSE, NULL, 3.20),
    (5, 1, 3, 3, NOW() - INTERVAL '10 days', TRUE, 'yes', 3.20);

-- SMS Reminder (Day -2)
INSERT INTO donor_communications (donor_id, campaign_event_id, channel_id, sequence_id, sent_at, opened, clicked, cost) VALUES
    (1, 1, 2, 5, NOW() - INTERVAL '2 days', TRUE, TRUE, 0.08),
    (2, 1, 2, 5, NOW() - INTERVAL '2 days', TRUE, TRUE, 0.08),
    (3, 1, 2, 5, NOW() - INTERVAL '2 days', TRUE, FALSE, 0.08),
    (5, 1, 2, 5, NOW() - INTERVAL '2 days', TRUE, TRUE, 0.08);

-- Simulate donations
UPDATE donor_communications SET donated = TRUE, donation_amount = 2500 WHERE communication_id = 1;
UPDATE donor_communications SET donated = TRUE, donation_amount = 5000 WHERE communication_id = 2;
UPDATE donor_communications SET donated = TRUE, donation_amount = 1000 WHERE communication_id = 3;

-- =====================================================
-- SECTION 6: Sample ML Experiment
-- =====================================================
INSERT INTO ml_experiments (name, description, campaign_type_id, variants, target_donor_tiers, start_date, strategy) VALUES
    ('Email Subject Line Test - Private Reception',
     'Testing 3 subject line variants for fundraising home receptions',
     1,
     '[
        {"id": "A", "name": "You''re Invited: Reception with {Candidate}"},
        {"id": "B", "name": "EXCLUSIVE: Join 15 Leaders Supporting {Candidate}"},
        {"id": "C", "name": "Saturday: Private Reception for {Candidate}"}
     ]'::jsonb,
     ARRAY['A', 'B'],
     '2025-10-01',
     'thompson_sampling');

-- Initialize bandit state
INSERT INTO ml_bandit_state (experiment_id, variant_id) VALUES
    (1, 'A'),
    (1, 'B'),
    (1, 'C');

-- =====================================================
-- SECTION 7: Sample ML Insights
-- =====================================================
INSERT INTO ml_insights (insight_category, insight_text, supporting_data, recommended_action, estimated_impact_dollars, confidence_level, status) VALUES
    ('channel_optimization',
     'Print invitations outperform email-only for events with $1000+ ticket price',
     '{"print_response_rate": 28, "email_response_rate": 11, "sample_size": 247}'::jsonb,
     'Auto-recommend print for all high-dollar events',
     250000,
     'high',
     'approved'),

    ('timing',
     'Donors age 65+ convert 2.3x better when contacted 8-10 AM vs evening',
     '{"morning_conversion": 2.1, "evening_conversion": 0.9, "age_group": "65+", "sample_size": 8456}'::jsonb,
     'Adjust send time for 65+ donors to morning hours',
     67000,
     'very_high',
     'pending');

-- =====================================================
-- SECTION 8: Sample ML Channel Recommendations
-- =====================================================
INSERT INTO ml_channel_recommendations (campaign_type_id, donor_segment, recommended_sequence, predicted_roi, predicted_conversion_rate, model_confidence, sample_size) VALUES
    (1, 'A', 
     '[
        {"channel": "email", "day": -21, "description": "Save the date"},
        {"channel": "phone", "day": -18, "description": "Personal co-host invitation"},
        {"channel": "print", "day": -10, "description": "Formal invitation"},
        {"channel": "email", "day": -6, "description": "Follow-up with agenda"},
        {"channel": "sms", "day": -2, "description": "Reminder"},
        {"channel": "whatsapp", "day": 0, "description": "Day-of logistics"}
     ]'::jsonb,
     4137,
     23.6,
     87.5,
     40),

    (6, 'U',
     '[
        {"channel": "email", "day": -7, "description": "Free event invitation"},
        {"channel": "email", "day": -2, "description": "Reminder"},
        {"channel": "sms", "day": -1, "description": "Day before reminder"}
     ]'::jsonb,
     850,
     8.7,
     72.3,
     125);

-- Comments
COMMENT ON TABLE donors IS 'Sample includes 20 donors across all 5 tiers (A, B, C, D, U)';
COMMENT ON TABLE donor_communications IS 'Sample shows typical fundraising event sequence with results';
COMMENT ON TABLE ml_experiments IS 'Sample shows subject line A/B test with 3 variants';
