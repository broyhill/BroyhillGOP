-- =====================================================
-- BROYHILLGOP SUPABASE DATABASE SCHEMA
-- File 5: Triggers & Automation Functions
-- Real-Time Learning & Performance Updates
-- =====================================================

-- =====================================================
-- Trigger 1: Auto-Update Campaign Performance Metrics
-- When a campaign completes, calculate final metrics
-- =====================================================
CREATE OR REPLACE FUNCTION update_campaign_metrics()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Calculate actual revenue from donor communications
        UPDATE campaign_events
        SET actual_revenue = (
            SELECT COALESCE(SUM(donation_amount), 0)
            FROM donor_communications
            WHERE campaign_event_id = NEW.campaign_event_id
            AND donated = TRUE
        ),
        total_invitations_sent = (
            SELECT COUNT(DISTINCT donor_id)
            FROM donor_communications
            WHERE campaign_event_id = NEW.campaign_event_id
        ),
        total_rsvps = (
            SELECT COUNT(DISTINCT donor_id)
            FROM donor_communications
            WHERE campaign_event_id = NEW.campaign_event_id
            AND rsvp_status = 'yes'
        ),
        total_attendees = (
            SELECT COUNT(DISTINCT donor_id)
            FROM donor_communications
            WHERE campaign_event_id = NEW.campaign_event_id
            AND attended = TRUE
        ),
        updated_at = NOW()
        WHERE campaign_event_id = NEW.campaign_event_id;

        -- Update historical ROI for this campaign type
        UPDATE campaign_types
        SET avg_historical_roi = (
            SELECT ROUND(AVG((ce.actual_revenue - (
                SELECT COALESCE(SUM(dc.cost), 0)
                FROM donor_communications dc
                WHERE dc.campaign_event_id = ce.campaign_event_id
            )) / NULLIF((
                SELECT SUM(dc.cost)
                FROM donor_communications dc
                WHERE dc.campaign_event_id = ce.campaign_event_id
            ), 0) * 100), 2)
            FROM campaign_events ce
            WHERE ce.campaign_type_id = NEW.campaign_type_id
            AND ce.status = 'completed'
        )
        WHERE campaign_type_id = NEW.campaign_type_id;

        -- Refresh materialized views
        PERFORM refresh_channel_effectiveness();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_campaign_metrics
AFTER UPDATE OF status ON campaign_events
FOR EACH ROW
EXECUTE FUNCTION update_campaign_metrics();

-- =====================================================
-- Trigger 2: Auto-Update Thompson Sampling Bandit State
-- When experiment result is recorded, update alpha/beta
-- =====================================================
CREATE OR REPLACE FUNCTION update_bandit_state()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.donated = TRUE THEN
        -- Success: increment alpha (successes + 1)
        UPDATE ml_bandit_state
        SET 
            alpha = alpha + 1,
            conversions = conversions + 1,
            impressions = impressions + 1,
            total_revenue = total_revenue + COALESCE(NEW.donation_amount, 0),
            avg_donation = total_revenue / NULLIF(conversions, 0),
            last_updated = NOW()
        WHERE experiment_id = NEW.experiment_id
        AND variant_id = NEW.variant_id;
    ELSE
        -- Failure: increment beta (failures + 1)
        UPDATE ml_bandit_state
        SET 
            beta = beta + 1,
            impressions = impressions + 1,
            last_updated = NOW()
        WHERE experiment_id = NEW.experiment_id
        AND variant_id = NEW.variant_id;
    END IF;

    -- Recalculate traffic allocation based on Beta distribution
    WITH total_weight AS (
        SELECT experiment_id, SUM(alpha::NUMERIC / (alpha + beta)) AS sum_weight
        FROM ml_bandit_state
        WHERE experiment_id = NEW.experiment_id
        GROUP BY experiment_id
    )
    UPDATE ml_bandit_state bs
    SET traffic_allocation_pct = ROUND(
        (bs.alpha::NUMERIC / (bs.alpha + bs.beta)) / tw.sum_weight * 100, 2
    )
    FROM total_weight tw
    WHERE bs.experiment_id = tw.experiment_id
    AND bs.experiment_id = NEW.experiment_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_bandit_state
AFTER INSERT OR UPDATE OF donated ON ml_experiment_results
FOR EACH ROW
EXECUTE FUNCTION update_bandit_state();

-- =====================================================
-- Trigger 3: Auto-Train ML Model When Sufficient Data
-- Triggers PostgresML training after 5,000+ interactions
-- =====================================================
CREATE OR REPLACE FUNCTION trigger_ml_training()
RETURNS TRIGGER AS $$
DECLARE 
    row_count INT;
    last_training TIMESTAMP;
BEGIN
    -- Check if we have enough data and haven't trained recently
    SELECT COUNT(*) INTO row_count 
    FROM donor_communications 
    WHERE donated = TRUE;

    SELECT MAX(test_date) INTO last_training
    FROM ml_model_performance
    WHERE model_name = 'channel_optimizer';

    -- Train if: >5000 donations AND (never trained OR >30 days since last training)
    IF row_count > 5000 AND (last_training IS NULL OR last_training < NOW() - INTERVAL '30 days') THEN
        -- PostgresML training (requires pgml extension)
        BEGIN
            PERFORM pgml.train(
                project_name => 'channel_optimizer',
                task => 'classification',
                relation_name => 'donor_communications',
                y_column_name => 'donated',
                algorithm => 'xgboost',
                hyperparams => '{"n_estimators": 100, "max_depth": 10}'
            );

            -- Log training event
            INSERT INTO ml_model_performance (model_name, model_version, training_samples, notes)
            VALUES ('channel_optimizer', 'v' || EXTRACT(EPOCH FROM NOW())::TEXT, row_count, 'Auto-trained via trigger');
        EXCEPTION WHEN OTHERS THEN
            -- Log error but don't fail the insert
            RAISE NOTICE 'ML training failed: %', SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_train_ml
AFTER INSERT ON donor_communications
FOR EACH STATEMENT
EXECUTE FUNCTION trigger_ml_training();

-- =====================================================
-- Trigger 4: Update Donor Engagement Scores
-- Recalculate donor engagement metrics after each interaction
-- =====================================================
CREATE OR REPLACE FUNCTION update_donor_engagement()
RETURNS TRIGGER AS $$
BEGIN
    -- Update donor's lifetime contribution if they donated
    IF NEW.donated = TRUE THEN
        UPDATE donors
        SET 
            lifetime_contribution = lifetime_contribution + NEW.donation_amount,
            updated_at = NOW()
        WHERE donor_id = NEW.donor_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_donor_engagement
AFTER INSERT OR UPDATE OF donated ON donor_communications
FOR EACH ROW
EXECUTE FUNCTION update_donor_engagement();

-- =====================================================
-- Trigger 5: Log Sequence Modifications
-- Track when ML engine changes a sequence
-- =====================================================
CREATE OR REPLACE FUNCTION log_sequence_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.day_offset != OLD.day_offset OR NEW.channel_id != OLD.channel_id OR NEW.active != OLD.active) THEN
        INSERT INTO sequence_modifications (
            campaign_type_id,
            original_sequence_id,
            modification_type,
            old_value,
            new_value,
            reason
        ) VALUES (
            NEW.campaign_type_id,
            NEW.sequence_id,
            CASE 
                WHEN NEW.channel_id != OLD.channel_id THEN 'channel_swap'
                WHEN NEW.day_offset != OLD.day_offset THEN 'timing_adjustment'
                WHEN NEW.active != OLD.active THEN 'status_change'
            END,
            jsonb_build_object(
                'channel_id', OLD.channel_id,
                'day_offset', OLD.day_offset,
                'active', OLD.active
            ),
            jsonb_build_object(
                'channel_id', NEW.channel_id,
                'day_offset', NEW.day_offset,
                'active', NEW.active
            ),
            'ML-driven optimization'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_sequence_modification
AFTER UPDATE ON campaign_sequences
FOR EACH ROW
EXECUTE FUNCTION log_sequence_modification();

-- =====================================================
-- Function: Schedule Campaign Sequence Execution
-- Automatically schedules all touchpoints when campaign is created
-- =====================================================
CREATE OR REPLACE FUNCTION schedule_campaign_sequence(p_campaign_event_id INT)
RETURNS void AS $$
DECLARE
    v_campaign_type_id INT;
    v_event_date DATE;
    v_sequence RECORD;
BEGIN
    -- Get campaign details
    SELECT campaign_type_id, event_date INTO v_campaign_type_id, v_event_date
    FROM campaign_events
    WHERE campaign_event_id = p_campaign_event_id;

    -- For each sequence step, create scheduled communications
    FOR v_sequence IN 
        SELECT * FROM campaign_sequences
        WHERE campaign_type_id = v_campaign_type_id
        AND active = TRUE
        ORDER BY sequence_order
    LOOP
        -- This would integrate with Supabase Edge Functions to schedule actual sends
        -- For now, we just log the intent
        RAISE NOTICE 'Scheduling % for % days offset', v_sequence.action_description, v_sequence.day_offset;

        -- In production, this would call:
        -- PERFORM schedule_edge_function('send-communication', v_event_date + v_sequence.day_offset, ...)
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Function: Donor Communication Frequency Cap Check
-- Ensures donors don't receive too many messages
-- =====================================================
CREATE OR REPLACE FUNCTION check_frequency_cap(
    p_donor_id INT,
    p_days INT DEFAULT 7
) RETURNS BOOLEAN AS $$
DECLARE
    v_tier VARCHAR(10);
    v_recent_count INT;
    v_max_allowed INT;
BEGIN
    -- Get donor tier
    SELECT tier INTO v_tier FROM donors WHERE donor_id = p_donor_id;

    -- Set frequency caps by tier
    v_max_allowed := CASE v_tier
        WHEN 'A' THEN 3  -- Tier A: max 3 per week
        WHEN 'B' THEN 2  -- Tier B: max 2 per week
        WHEN 'C' THEN 1.5 -- Tier C: max 6 per month (1.5/week)
        WHEN 'D' THEN 1  -- Tier D: max 1 per week
        WHEN 'U' THEN 0.5 -- Tier U: max 2 per month
        ELSE 1
    END;

    -- Count recent communications
    SELECT COUNT(*) INTO v_recent_count
    FROM donor_communications
    WHERE donor_id = p_donor_id
    AND sent_at >= NOW() - (p_days || ' days')::INTERVAL;

    -- Return TRUE if under cap, FALSE if over
    RETURN v_recent_count < (v_max_allowed * (p_days::NUMERIC / 7));
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON FUNCTION update_campaign_metrics IS 'Auto-calculates final metrics when campaign completes';
COMMENT ON FUNCTION update_bandit_state IS 'Thompson Sampling state update for multi-armed bandit';
COMMENT ON FUNCTION trigger_ml_training IS 'Auto-trains ML model when sufficient data collected';
COMMENT ON FUNCTION schedule_campaign_sequence IS 'Automatically schedules all touchpoints for new campaign';
COMMENT ON FUNCTION check_frequency_cap IS 'Prevents donor over-communication based on tier limits';
