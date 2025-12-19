-- =====================================================
-- BROYHILLGOP SUPABASE DATABASE SCHEMA
-- File 3: Machine Learning Tables
-- Multi-Armed Bandit & Experimentation Engine
-- =====================================================

-- Table: ml_experiments
-- Defines A/B tests and multi-armed bandit experiments
CREATE TABLE IF NOT EXISTS ml_experiments (
    experiment_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    campaign_type_id INT REFERENCES campaign_types(campaign_type_id),
    issue_category_id INT REFERENCES issue_categories(issue_id),
    variants JSONB NOT NULL, -- [{"id": "A", "name": "Subject line A"}, {"id": "B", ...}]
    target_donor_tiers VARCHAR(10)[],
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'paused', 'completed', 'archived'
    strategy VARCHAR(50) DEFAULT 'thompson_sampling', -- 'thompson_sampling', 'epsilon_greedy', 'traditional_ab'
    sample_size_target INT,
    created_by INT REFERENCES candidates(candidate_id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_experiments_status ON ml_experiments(status);
CREATE INDEX idx_experiments_campaign_type ON ml_experiments(campaign_type_id);

-- Table: ml_experiment_results
-- Tracks performance of each variant in real-time
CREATE TABLE IF NOT EXISTS ml_experiment_results (
    result_id SERIAL PRIMARY KEY,
    experiment_id INT REFERENCES ml_experiments(experiment_id) ON DELETE CASCADE,
    variant_id VARCHAR(10) NOT NULL,
    donor_id INT REFERENCES donors(donor_id),
    campaign_event_id INT REFERENCES campaign_events(campaign_event_id),
    assigned_at TIMESTAMP DEFAULT NOW(),
    opened BOOLEAN DEFAULT FALSE,
    clicked BOOLEAN DEFAULT FALSE,
    rsvp BOOLEAN DEFAULT FALSE,
    attended BOOLEAN DEFAULT FALSE,
    donated BOOLEAN DEFAULT FALSE,
    donation_amount NUMERIC(10,2) DEFAULT 0,
    cost NUMERIC(10,2),
    recorded_at TIMESTAMP
);

CREATE INDEX idx_results_experiment ON ml_experiment_results(experiment_id);
CREATE INDEX idx_results_variant ON ml_experiment_results(experiment_id, variant_id);
CREATE INDEX idx_results_donated ON ml_experiment_results(donated) WHERE donated = TRUE;

-- Table: ml_bandit_state
-- Thompson Sampling state (Beta distribution parameters)
CREATE TABLE IF NOT EXISTS ml_bandit_state (
    bandit_id SERIAL PRIMARY KEY,
    experiment_id INT REFERENCES ml_experiments(experiment_id) ON DELETE CASCADE,
    variant_id VARCHAR(10) NOT NULL,
    alpha INT DEFAULT 1, -- Successes + 1 (Beta prior)
    beta INT DEFAULT 1, -- Failures + 1 (Beta prior)
    impressions INT DEFAULT 0,
    conversions INT DEFAULT 0,
    total_revenue NUMERIC(12,2) DEFAULT 0,
    avg_donation NUMERIC(10,2),
    traffic_allocation_pct NUMERIC(5,2), -- Current % of traffic assigned
    last_updated TIMESTAMP DEFAULT NOW(),
    UNIQUE (experiment_id, variant_id)
);

CREATE INDEX idx_bandit_experiment ON ml_bandit_state(experiment_id);

-- Table: ml_predictions
-- ML model predictions for optimal channel, timing, etc.
CREATE TABLE IF NOT EXISTS ml_predictions (
    prediction_id SERIAL PRIMARY KEY,
    donor_id INT REFERENCES donors(donor_id),
    campaign_type_id INT REFERENCES campaign_types(campaign_type_id),
    model_name VARCHAR(100) NOT NULL, -- 'channel_optimizer', 'timing_predictor', 'tone_selector'
    prediction_value JSONB NOT NULL, -- {"recommended_channel": "sms", "confidence": 0.87}
    predicted_at TIMESTAMP DEFAULT NOW(),
    used_in_campaign BOOLEAN DEFAULT FALSE,
    actual_outcome JSONB, -- Filled in after campaign executes
    model_version VARCHAR(20),
    confidence_score NUMERIC(5,2)
);

CREATE INDEX idx_predictions_donor ON ml_predictions(donor_id);
CREATE INDEX idx_predictions_model ON ml_predictions(model_name);
CREATE INDEX idx_predictions_campaign_type ON ml_predictions(campaign_type_id);

-- Table: ml_insights
-- Discovered patterns (e.g., "SMS works better for Tier A healthcare donors")
CREATE TABLE IF NOT EXISTS ml_insights (
    insight_id SERIAL PRIMARY KEY,
    insight_category VARCHAR(100) NOT NULL, -- 'channel_optimization', 'timing', 'message', 'segmentation'
    insight_text TEXT NOT NULL,
    supporting_data JSONB, -- Detailed evidence
    recommended_action TEXT,
    estimated_impact_dollars NUMERIC(12,2),
    discovered_at TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'deployed', 'rejected'
    deployed_at TIMESTAMP,
    actual_impact_dollars NUMERIC(12,2), -- Measured after deployment
    confidence_level VARCHAR(20) -- 'low', 'medium', 'high', 'very_high'
);

CREATE INDEX idx_insights_category ON ml_insights(insight_category);
CREATE INDEX idx_insights_status ON ml_insights(status);

-- Table: ml_channel_recommendations
-- Final ML output: optimal sequence for each campaign type + donor segment
CREATE TABLE IF NOT EXISTS ml_channel_recommendations (
    recommendation_id SERIAL PRIMARY KEY,
    campaign_type_id INT REFERENCES campaign_types(campaign_type_id),
    donor_segment VARCHAR(20) NOT NULL, -- 'A', 'B', 'C', 'D', 'U'
    recommended_sequence JSONB NOT NULL, -- Ordered list: [{"channel": "email", "day": -14}, {"channel": "sms", "day": -2}]
    predicted_roi NUMERIC(10,2),
    predicted_conversion_rate NUMERIC(5,2),
    model_confidence NUMERIC(5,2),
    sample_size INT, -- Number of campaigns used to train this recommendation
    last_updated TIMESTAMP DEFAULT NOW(),
    UNIQUE (campaign_type_id, donor_segment)
);

CREATE INDEX idx_recommendations_campaign_type ON ml_channel_recommendations(campaign_type_id);

-- Table: ml_model_performance
-- Tracks accuracy of ML models over time
CREATE TABLE IF NOT EXISTS ml_model_performance (
    performance_id SERIAL PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(20),
    accuracy NUMERIC(5,2),
    precision_score NUMERIC(5,2),
    recall NUMERIC(5,2),
    f1_score NUMERIC(5,2),
    training_samples INT,
    test_date TIMESTAMP DEFAULT NOW(),
    notes TEXT
);

CREATE INDEX idx_performance_model ON ml_model_performance(model_name);

-- Comments
COMMENT ON TABLE ml_experiments IS 'A/B tests and multi-armed bandit experiments';
COMMENT ON TABLE ml_bandit_state IS 'Thompson Sampling state for real-time traffic allocation';
COMMENT ON TABLE ml_predictions IS 'Per-donor ML predictions for optimal channel/timing/tone';
COMMENT ON TABLE ml_insights IS 'Discovered patterns from cross-campaign analysis';
COMMENT ON TABLE ml_channel_recommendations IS 'Final ML output: best sequence per campaign type + donor segment';
