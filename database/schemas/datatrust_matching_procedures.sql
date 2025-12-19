-- ============================================================================
-- DATA TRUST MATCHING & INTEGRATION PROCEDURES
-- Part 3: Matching Functions, Sync Procedures, Algorithm Updates
-- ============================================================================

-- ============================================================================
-- MATCHING FUNCTIONS
-- ============================================================================

-- Function 1: Match Data Trust Profile to Unified Contact
CREATE OR REPLACE FUNCTION match_datatrust_to_contact(
    p_rnc_id VARCHAR(32)
)
RETURNS BIGINT AS $$
DECLARE
    v_contact_id BIGINT;
    v_match_score INTEGER := 0;
    v_best_match_id BIGINT;
    v_best_score INTEGER := 0;
BEGIN
    -- Try exact phone match first
    SELECT uc.contact_id, 100 INTO v_contact_id, v_match_score
    FROM unified_contacts uc
    INNER JOIN datatrust_profiles dt ON dt.rnc_id = p_rnc_id
    WHERE uc.mobile_phone = dt.phone_primary
        OR uc.mobile_phone = dt.phone_secondary
        OR uc.home_phone = dt.phone_neustar
    LIMIT 1;
    
    IF v_contact_id IS NOT NULL THEN
        RETURN v_contact_id;
    END IF;
    
    -- Try exact email match
    SELECT uc.contact_id, 90 INTO v_contact_id, v_match_score
    FROM unified_contacts uc
    INNER JOIN datatrust_profiles dt ON dt.rnc_id = p_rnc_id
    WHERE uc.email = dt.email_primary
    LIMIT 1;
    
    IF v_contact_id IS NOT NULL THEN
        RETURN v_contact_id;
    END IF;
    
    -- Try fuzzy name + address match
    FOR v_contact_id, v_match_score IN
        SELECT 
            uc.contact_id,
            CASE 
                WHEN uc.last_name_clean = dt.last_name THEN 30 ELSE 0
            END +
            CASE 
                WHEN uc.first_name_clean = dt.first_name THEN 20 ELSE 0
            END +
            CASE 
                WHEN uc.zip_code = dt.home_zip THEN 20 ELSE 0
            END +
            CASE 
                WHEN uc.city = dt.home_city THEN 15 ELSE 0
            END +
            CASE 
                WHEN uc.county = dt.home_county THEN 15 ELSE 0
            END as match_score
        FROM unified_contacts uc
        CROSS JOIN datatrust_profiles dt
        WHERE dt.rnc_id = p_rnc_id
            AND uc.last_name_clean = dt.last_name
            AND uc.state = 'NC'
        ORDER BY match_score DESC
        LIMIT 5
    LOOP
        IF v_match_score > v_best_score THEN
            v_best_score := v_match_score;
            v_best_match_id := v_contact_id;
        END IF;
    END LOOP;
    
    -- Only return if confidence is high enough (>60)
    IF v_best_score >= 60 THEN
        RETURN v_best_match_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Sync Data Trust Data to Unified Contact
CREATE OR REPLACE FUNCTION sync_datatrust_to_unified_contact(
    p_rnc_id VARCHAR(32)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_contact_id BIGINT;
    v_dt_record RECORD;
BEGIN
    -- Get the Data Trust record
    SELECT * INTO v_dt_record
    FROM datatrust_profiles
    WHERE rnc_id = p_rnc_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Get or match contact ID
    v_contact_id := v_dt_record.contact_id;
    IF v_contact_id IS NULL THEN
        v_contact_id := match_datatrust_to_contact(p_rnc_id);
        
        -- Update the link
        IF v_contact_id IS NOT NULL THEN
            UPDATE datatrust_profiles
            SET contact_id = v_contact_id,
                synced_to_unified_contacts = TRUE,
                sync_date = NOW()
            WHERE rnc_id = p_rnc_id;
        END IF;
    END IF;
    
    -- If we have a match, enrich the unified contact
    IF v_contact_id IS NOT NULL THEN
        UPDATE unified_contacts SET
            -- Update missing phone numbers
            mobile_phone = COALESCE(mobile_phone, v_dt_record.phone_primary),
            home_phone = COALESCE(home_phone, v_dt_record.phone_neustar),
            
            -- Update missing email
            email = COALESCE(email, v_dt_record.email_primary),
            
            -- Enrich address if better quality
            street_line_1 = CASE 
                WHEN v_dt_record.home_full_address IS NOT NULL 
                    AND street_line_1 IS NULL 
                THEN v_dt_record.home_full_address
                ELSE street_line_1
            END,
            city = COALESCE(city, v_dt_record.home_city),
            state = COALESCE(state, v_dt_record.home_state),
            zip_code = COALESCE(zip_code, v_dt_record.home_zip),
            county = COALESCE(county, v_dt_record.home_county),
            
            -- Add Data Trust-specific fields to custom_fields JSONB
            custom_fields = custom_fields || jsonb_build_object(
                'rnc_id', v_dt_record.rnc_id,
                'voter_registration_status', v_dt_record.voter_registration_status,
                'registered_party', v_dt_record.registered_party_affiliation,
                'partisanship_score', v_dt_record.modeled_partisanship_score,
                'turnout_score', v_dt_record.turnout_likelihood_score,
                'voter_regularity', v_dt_record.voter_regularity_score,
                'trump_approval', v_dt_record.issue_trump_approval,
                'gun_rights_support', v_dt_record.issue_gun_rights_support,
                'congressional_district', v_dt_record.congressional_district_current,
                'state_senate_district', v_dt_record.state_senate_district,
                'state_house_district', v_dt_record.state_house_district,
                'precinct', v_dt_record.precinct_code,
                'data_trust_synced', true,
                'data_trust_sync_date', NOW()
            ),
            
            -- Update engagement score based on vote history
            engagement_score = GREATEST(
                engagement_score,
                (v_dt_record.voter_regularity_score * 50)::INTEGER + 
                (v_dt_record.turnout_likelihood_score * 30)::INTEGER +
                20
            ),
            
            updated_at = NOW()
        WHERE contact_id = v_contact_id;
        
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Bulk Match and Sync
CREATE OR REPLACE FUNCTION bulk_sync_datatrust(
    p_limit INTEGER DEFAULT 1000
)
RETURNS TABLE(
    rnc_id VARCHAR(32),
    contact_id BIGINT,
    sync_status VARCHAR(20),
    match_score INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH unsynced AS (
        SELECT dt.rnc_id
        FROM datatrust_profiles dt
        WHERE dt.synced_to_unified_contacts = FALSE
            OR dt.contact_id IS NULL
        LIMIT p_limit
    ),
    sync_results AS (
        SELECT 
            u.rnc_id,
            sync_datatrust_to_unified_contact(u.rnc_id) as synced
        FROM unsynced u
    )
    SELECT 
        dt.rnc_id,
        dt.contact_id,
        CASE 
            WHEN dt.contact_id IS NOT NULL THEN 'matched'
            ELSE 'no_match'
        END as sync_status,
        CASE 
            WHEN dt.contact_id IS NOT NULL THEN 100
            ELSE 0
        END as match_score
    FROM datatrust_profiles dt
    WHERE dt.rnc_id IN (SELECT rnc_id FROM unsynced);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TARGETING FUNCTIONS FOR CAMPAIGNS
-- ============================================================================

-- Function 4: Get High-Priority Voter Targets
CREATE OR REPLACE FUNCTION get_voter_targets(
    p_county VARCHAR(100) DEFAULT NULL,
    p_district VARCHAR(10) DEFAULT NULL,
    p_min_turnout_score NUMERIC DEFAULT 0.5,
    p_min_partisanship NUMERIC DEFAULT 0.6,
    p_limit INTEGER DEFAULT 10000
)
RETURNS TABLE(
    rnc_id VARCHAR(32),
    contact_id BIGINT,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255),
    county VARCHAR(100),
    district VARCHAR(10),
    turnout_score NUMERIC,
    partisanship_score NUMERIC,
    priority_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dt.rnc_id,
        dt.contact_id,
        dt.full_name_computed,
        dt.phone_primary,
        dt.email_primary,
        dt.home_county,
        dt.congressional_district_current,
        dt.turnout_likelihood_score,
        dt.modeled_partisanship_score,
        -- Calculate priority score
        (dt.turnout_likelihood_score * 0.4 +
         dt.modeled_partisanship_score * 0.3 +
         dt.voter_regularity_score * 0.2 +
         CASE WHEN uc.donor_grade IN ('A++', 'A+', 'A') THEN 0.1 ELSE 0 END) as priority_score
    FROM datatrust_profiles dt
    LEFT JOIN unified_contacts uc ON dt.contact_id = uc.contact_id
    WHERE dt.voter_registration_status = 'active'
        AND dt.deceased_flag = FALSE
        AND dt.turnout_likelihood_score >= p_min_turnout_score
        AND dt.modeled_partisanship_score >= p_min_partisanship
        AND (p_county IS NULL OR dt.home_county = p_county)
        AND (p_district IS NULL OR dt.congressional_district_current = p_district)
        AND (dt.phone_primary IS NOT NULL OR dt.email_primary IS NOT NULL)
    ORDER BY priority_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Issue-Specific Targets
CREATE OR REPLACE FUNCTION get_issue_targets(
    p_issue_name VARCHAR(50),
    p_min_issue_score NUMERIC DEFAULT 0.6,
    p_county VARCHAR(100) DEFAULT NULL,
    p_limit INTEGER DEFAULT 5000
)
RETURNS TABLE(
    rnc_id VARCHAR(32),
    contact_id BIGINT,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255),
    issue_score NUMERIC,
    turnout_score NUMERIC
) AS $$
DECLARE
    v_issue_column TEXT;
BEGIN
    -- Map issue name to column
    v_issue_column := CASE p_issue_name
        WHEN 'gun_rights' THEN 'issue_gun_rights_support'
        WHEN 'abortion' THEN 'issue_abortion_pro_life'
        WHEN 'border' THEN 'issue_border_security'
        WHEN 'school_choice' THEN 'issue_school_choice'
        WHEN 'trump' THEN 'issue_trump_approval'
        WHEN 'taxes' THEN 'issue_tax_cuts_support'
        WHEN 'law_order' THEN 'issue_law_and_order'
        ELSE 'issue_trump_approval'
    END;
    
    RETURN QUERY EXECUTE format('
        SELECT 
            dt.rnc_id,
            dt.contact_id,
            dt.full_name_computed,
            dt.phone_primary,
            dt.email_primary,
            dt.%I as issue_score,
            dt.turnout_likelihood_score
        FROM datatrust_profiles dt
        WHERE dt.voter_registration_status = ''active''
            AND dt.deceased_flag = FALSE
            AND dt.%I >= $1
            AND ($2 IS NULL OR dt.home_county = $2)
            AND dt.turnout_likelihood_score > 0.4
        ORDER BY dt.%I DESC, dt.turnout_likelihood_score DESC
        LIMIT $3
    ', v_issue_column, v_issue_column, v_issue_column)
    USING p_min_issue_score, p_county, p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function 6: Get Volunteer Recruitment Targets
CREATE OR REPLACE FUNCTION get_volunteer_targets(
    p_county VARCHAR(100) DEFAULT NULL,
    p_min_activism_score NUMERIC DEFAULT 0.5,
    p_limit INTEGER DEFAULT 1000
)
RETURNS TABLE(
    rnc_id VARCHAR(32),
    contact_id BIGINT,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255),
    activism_score NUMERIC,
    volunteer_likelihood NUMERIC,
    donor_status VARCHAR(10)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dt.rnc_id,
        dt.contact_id,
        dt.full_name_computed,
        dt.phone_primary,
        dt.email_primary,
        dt.political_activism_score,
        dt.grassroots_volunteer_likelihood,
        uc.donor_grade
    FROM datatrust_profiles dt
    LEFT JOIN unified_contacts uc ON dt.contact_id = uc.contact_id
    WHERE dt.voter_registration_status = 'active'
        AND dt.deceased_flag = FALSE
        AND dt.political_activism_score >= p_min_activism_score
        AND dt.turnout_likelihood_score > 0.6
        AND (p_county IS NULL OR dt.home_county = p_county)
        AND dt.phone_primary IS NOT NULL
    ORDER BY dt.grassroots_volunteer_likelihood DESC, 
             dt.political_activism_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COUNCIL OF STATE CANDIDATE TARGETING
-- ============================================================================

-- Function 7: Get Statewide Targets for Council of State Races
CREATE OR REPLACE FUNCTION get_council_of_state_targets(
    p_office VARCHAR(50),  -- 'agriculture', 'labor', 'insurance', etc.
    p_min_turnout NUMERIC DEFAULT 0.6,
    p_limit INTEGER DEFAULT 50000
)
RETURNS TABLE(
    rnc_id VARCHAR(32),
    contact_id BIGINT,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255),
    county VARCHAR(100),
    turnout_score NUMERIC,
    partisanship_score NUMERIC,
    office_interest BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dt.rnc_id,
        dt.contact_id,
        dt.full_name_computed,
        dt.phone_primary,
        dt.email_primary,
        dt.home_county,
        dt.turnout_likelihood_score,
        dt.modeled_partisanship_score,
        CASE p_office
            WHEN 'agriculture' THEN dt.nc_agriculture_interest
            WHEN 'labor' THEN dt.nc_labor_interest
            WHEN 'insurance' THEN dt.nc_insurance_interest
            WHEN 'education' THEN dt.nc_education_interest
            WHEN 'treasurer' THEN dt.nc_treasurer_interest
            ELSE FALSE
        END as office_interest
    FROM datatrust_profiles dt
    WHERE dt.voter_registration_status = 'active'
        AND dt.deceased_flag = FALSE
        AND dt.turnout_likelihood_score >= p_min_turnout
        AND dt.modeled_partisanship_score >= 0.5
        AND (dt.phone_primary IS NOT NULL OR dt.email_primary IS NOT NULL)
    ORDER BY 
        CASE 
            WHEN CASE p_office
                WHEN 'agriculture' THEN dt.nc_agriculture_interest
                WHEN 'labor' THEN dt.nc_labor_interest
                WHEN 'insurance' THEN dt.nc_insurance_interest
                WHEN 'education' THEN dt.nc_education_interest
                WHEN 'treasurer' THEN dt.nc_treasurer_interest
                ELSE FALSE
            END THEN 1
            ELSE 2
        END,
        dt.turnout_likelihood_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ALGORITHM UPDATES FOR ECOSYSTEM
-- ============================================================================

-- Function 8: Update ML Model Inputs with Data Trust Data
CREATE OR REPLACE FUNCTION update_ml_model_inputs()
RETURNS INTEGER AS $$
DECLARE
    v_updated_count INTEGER := 0;
BEGIN
    -- Update contact predictions with Data Trust turnout scores
    UPDATE ml_contact_predictions mcp
    SET 
        will_open_next_email = GREATEST(
            mcp.will_open_next_email,
            dt.turnout_likelihood_score * 0.7  -- Adjust for email vs vote
        ),
        will_volunteer_next = GREATEST(
            mcp.will_volunteer_next,
            dt.grassroots_volunteer_likelihood
        ),
        best_send_hour = COALESCE(
            mcp.best_send_hour,
            EXTRACT(HOUR FROM dt.phone_neustar_call_window_local::TIME)::INTEGER
        ),
        confidence = LEAST(
            1.0,
            mcp.confidence + (dt.data_accuracy_score / 200.0)  -- Boost confidence
        ),
        model_version = 'v2.0_datatrust',
        prediction_date = NOW()
    FROM datatrust_profiles dt
    INNER JOIN unified_contacts uc ON dt.contact_id = uc.contact_id
    WHERE mcp.contact_id = uc.contact_id
        AND dt.synced_to_unified_contacts = TRUE;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function 9: Enhance Donor Intelligence with Voter Data
CREATE OR REPLACE FUNCTION enhance_donor_intelligence()
RETURNS INTEGER AS $$
DECLARE
    v_enhanced_count INTEGER := 0;
BEGIN
    -- Add voter participation data to donor profiles
    UPDATE unified_contacts uc
    SET 
        custom_fields = uc.custom_fields || jsonb_build_object(
            'voter_regularity', dt.voter_regularity_score,
            'last_voted', dt.last_vote_date,
            'turnout_2026_predicted', dt.turnout_general_2026_prob,
            'partisanship_strength', CASE 
                WHEN dt.modeled_partisanship_score > 0.8 THEN 'strong_republican'
                WHEN dt.modeled_partisanship_score > 0.6 THEN 'lean_republican'
                WHEN dt.modeled_partisanship_score > 0.4 THEN 'swing'
                WHEN dt.modeled_partisanship_score > 0.2 THEN 'lean_democrat'
                ELSE 'strong_democrat'
            END,
            'primary_voter', CASE 
                WHEN dt.voter_regularity_score > 0.7 THEN TRUE
                ELSE FALSE
            END,
            'issue_top_priority', CASE 
                WHEN dt.issue_gun_rights_support > 0.7 THEN '2A'
                WHEN dt.issue_abortion_pro_life > 0.7 THEN 'pro_life'
                WHEN dt.issue_border_security > 0.7 THEN 'border'
                WHEN dt.issue_trump_approval > 0.7 THEN 'trump'
                ELSE 'mixed'
            END
        ),
        
        -- Upgrade engagement score for active voters
        engagement_score = LEAST(
            100,
            uc.engagement_score + 
            (dt.voter_regularity_score * 20)::INTEGER +
            (dt.turnout_likelihood_score * 15)::INTEGER
        ),
        
        updated_at = NOW()
    FROM datatrust_profiles dt
    WHERE uc.contact_id = dt.contact_id
        AND uc.donor_grade IS NOT NULL
        AND dt.synced_to_unified_contacts = TRUE;
    
    GET DIAGNOSTICS v_enhanced_count = ROW_COUNT;
    RETURN v_enhanced_count;
END;
$$ LANGUAGE plpgsql;

-- Function 10: Update Volunteer Intelligence with Activism Scores
CREATE OR REPLACE FUNCTION enhance_volunteer_intelligence()
RETURNS INTEGER AS $$
DECLARE
    v_enhanced_count INTEGER := 0;
BEGIN
    UPDATE unified_contacts uc
    SET 
        custom_fields = uc.custom_fields || jsonb_build_object(
            'activism_score', dt.political_activism_score,
            'volunteer_likelihood', dt.grassroots_volunteer_likelihood,
            'county_party_member', dt.nc_county_party_member,
            'precinct_captain', dt.nc_precinct_captain,
            'delegate_history', dt.nc_state_convention_delegate,
            'reliable_volunteer_predicted', CASE 
                WHEN dt.grassroots_volunteer_likelihood > 0.6 
                    AND dt.voter_regularity_score > 0.7 
                THEN TRUE
                ELSE FALSE
            END
        ),
        
        -- Boost engagement for activists
        engagement_score = LEAST(
            100,
            uc.engagement_score + 
            (dt.political_activism_score * 25)::INTEGER
        ),
        
        updated_at = NOW()
    FROM datatrust_profiles dt
    WHERE uc.contact_id = dt.contact_id
        AND uc.volunteer_status IN ('active', 'prospective')
        AND dt.synced_to_unified_contacts = TRUE;
    
    GET DIAGNOSTICS v_enhanced_count = ROW_COUNT;
    RETURN v_enhanced_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CAMPAIGN ECOSYSTEM UPDATES
-- ============================================================================

-- Function 11: Generate Targeted Campaign Lists
CREATE OR REPLACE FUNCTION generate_campaign_list(
    p_campaign_type VARCHAR(50),  -- 'voter_turnout', 'persuasion', 'donor', 'volunteer'
    p_geography_filter JSONB DEFAULT '{}',  -- {"county": "Wake", "district": "NC-02"}
    p_limit INTEGER DEFAULT 10000
)
RETURNS TABLE(
    rnc_id VARCHAR(32),
    contact_id BIGINT,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255),
    priority_score NUMERIC,
    recommended_message VARCHAR(50),
    best_contact_time VARCHAR(50)
) AS $$
BEGIN
    IF p_campaign_type = 'voter_turnout' THEN
        RETURN QUERY
        SELECT 
            dt.rnc_id,
            dt.contact_id,
            dt.full_name_computed,
            dt.phone_primary,
            dt.email_primary,
            dt.turnout_likelihood_score,
            CASE 
                WHEN dt.abev_preference = 'mail' THEN 'absentee_ballot'
                WHEN dt.abev_preference = 'early' THEN 'early_voting'
                ELSE 'election_day'
            END as recommended_message,
            dt.phone_neustar_call_window_local
        FROM datatrust_profiles dt
        WHERE dt.turnout_likelihood_score BETWEEN 0.4 AND 0.7  -- Persuadable on turnout
            AND dt.modeled_partisanship_score > 0.5
            AND dt.voter_registration_status = 'active'
            AND dt.deceased_flag = FALSE
            AND (p_geography_filter = '{}' 
                OR (p_geography_filter->>'county' IS NULL OR dt.home_county = p_geography_filter->>'county')
                AND (p_geography_filter->>'district' IS NULL OR dt.congressional_district_current = p_geography_filter->>'district'))
        ORDER BY dt.turnout_likelihood_score DESC
        LIMIT p_limit;
        
    ELSIF p_campaign_type = 'persuasion' THEN
        RETURN QUERY
        SELECT 
            dt.rnc_id,
            dt.contact_id,
            dt.full_name_computed,
            dt.phone_primary,
            dt.email_primary,
            ABS(0.5 - dt.modeled_partisanship_score) * -2 + 1 as priority_score,  -- Closer to center = higher
            CASE 
                WHEN dt.issue_gun_rights_support > 0.6 THEN 'gun_rights'
                WHEN dt.issue_abortion_pro_life > 0.6 THEN 'pro_life'
                WHEN dt.issue_border_security > 0.6 THEN 'immigration'
                ELSE 'economy'
            END as recommended_message,
            dt.phone_neustar_call_window_local
        FROM datatrust_profiles dt
        WHERE dt.modeled_partisanship_score BETWEEN 0.35 AND 0.65
            AND dt.turnout_likelihood_score > 0.5
            AND dt.voter_registration_status = 'active'
            AND dt.deceased_flag = FALSE
            AND (p_geography_filter = '{}' 
                OR (p_geography_filter->>'county' IS NULL OR dt.home_county = p_geography_filter->>'county'))
        ORDER BY priority_score DESC
        LIMIT p_limit;
        
    ELSIF p_campaign_type = 'donor' THEN
        RETURN QUERY
        SELECT 
            dt.rnc_id,
            dt.contact_id,
            dt.full_name_computed,
            dt.phone_primary,
            dt.email_primary,
            (dt.income_household / 100000.0 * 0.3 +
             dt.political_activism_score * 0.4 +
             dt.turnout_likelihood_score * 0.3) as priority_score,
            CASE 
                WHEN uc.donor_grade IN ('A++', 'A+', 'A') THEN 'major_donor_upgrade'
                WHEN uc.total_donations_aggregated > 0 THEN 'lapsed_donor'
                ELSE 'prospective_donor'
            END as recommended_message,
            dt.phone_neustar_call_window_local
        FROM datatrust_profiles dt
        LEFT JOIN unified_contacts uc ON dt.contact_id = uc.contact_id
        WHERE dt.modeled_partisanship_score > 0.6
            AND dt.income_household > 75000
            AND dt.voter_registration_status = 'active'
            AND dt.deceased_flag = FALSE
            AND (p_geography_filter = '{}' 
                OR (p_geography_filter->>'county' IS NULL OR dt.home_county = p_geography_filter->>'county'))
        ORDER BY priority_score DESC
        LIMIT p_limit;
        
    ELSIF p_campaign_type = 'volunteer' THEN
        RETURN QUERY
        SELECT 
            dt.rnc_id,
            dt.contact_id,
            dt.full_name_computed,
            dt.phone_primary,
            dt.email_primary,
            dt.grassroots_volunteer_likelihood,
            'volunteer_recruitment' as recommended_message,
            dt.phone_neustar_call_window_local
        FROM datatrust_profiles dt
        WHERE dt.grassroots_volunteer_likelihood > 0.5
            AND dt.political_activism_score > 0.4
            AND dt.turnout_likelihood_score > 0.6
            AND dt.voter_registration_status = 'active'
            AND dt.deceased_flag = FALSE
            AND (p_geography_filter = '{}' 
                OR (p_geography_filter->>'county' IS NULL OR dt.home_county = p_geography_filter->>'county'))
        ORDER BY dt.grassroots_volunteer_likelihood DESC
        LIMIT p_limit;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ADMINISTRATIVE FUNCTIONS
-- ============================================================================

-- Function 12: Calculate System Statistics
CREATE OR REPLACE FUNCTION get_datatrust_statistics()
RETURNS TABLE(
    stat_name VARCHAR(50),
    stat_value TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'total_profiles'::VARCHAR(50), COUNT(*)::TEXT FROM datatrust_profiles
    UNION ALL
    SELECT 'synced_to_contacts'::VARCHAR(50), COUNT(*)::TEXT FROM datatrust_profiles WHERE contact_id IS NOT NULL
    UNION ALL
    SELECT 'has_mobile_phone'::VARCHAR(50), COUNT(*)::TEXT FROM datatrust_profiles WHERE has_mobile_phone = TRUE
    UNION ALL
    SELECT 'has_email'::VARCHAR(50), COUNT(*)::TEXT FROM datatrust_profiles WHERE has_email = TRUE
    UNION ALL
    SELECT 'active_voters'::VARCHAR(50), COUNT(*)::TEXT FROM datatrust_profiles WHERE voter_registration_status = 'active'
    UNION ALL
    SELECT 'republicans'::VARCHAR(50), COUNT(*)::TEXT FROM datatrust_profiles WHERE modeled_partisanship_score > 0.6
    UNION ALL
    SELECT 'high_turnout'::VARCHAR(50), COUNT(*)::TEXT FROM datatrust_profiles WHERE turnout_likelihood_score > 0.7
    UNION ALL
    SELECT 'matched_donors'::VARCHAR(50), COUNT(*)::TEXT 
        FROM datatrust_profiles dt 
        INNER JOIN unified_contacts uc ON dt.contact_id = uc.contact_id 
        WHERE uc.donor_grade IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION match_datatrust_to_contact IS 'Matches Data Trust profile to unified contact using phone, email, and fuzzy name/address matching';
COMMENT ON FUNCTION sync_datatrust_to_unified_contact IS 'Syncs Data Trust data into unified_contacts table, enriching existing profiles';
COMMENT ON FUNCTION bulk_sync_datatrust IS 'Bulk sync operation for matching and syncing multiple profiles';
COMMENT ON FUNCTION get_voter_targets IS 'Returns prioritized list of voters for GOTV campaigns';
COMMENT ON FUNCTION get_issue_targets IS 'Returns voters prioritized by specific issue positions';
COMMENT ON FUNCTION get_volunteer_targets IS 'Returns high-likelihood volunteer recruitment targets';
COMMENT ON FUNCTION get_council_of_state_targets IS 'Returns statewide targets for NC Council of State races';
COMMENT ON FUNCTION update_ml_model_inputs IS 'Updates ML prediction models with Data Trust voter intelligence';
COMMENT ON FUNCTION enhance_donor_intelligence IS 'Enriches donor profiles with voter participation data';
COMMENT ON FUNCTION enhance_volunteer_intelligence IS 'Enriches volunteer profiles with activism and engagement scores';
COMMENT ON FUNCTION generate_campaign_list IS 'Generates targeted lists for specific campaign types with personalized messaging recommendations';

-- ============================================================================
-- INITIALIZATION SCRIPT
-- ============================================================================

-- Run these after Data Trust import:
-- 1. Match profiles to contacts:
-- SELECT * FROM bulk_sync_datatrust(10000);

-- 2. Update ML models:
-- SELECT update_ml_model_inputs();

-- 3. Enhance donor intelligence:
-- SELECT enhance_donor_intelligence();

-- 4. Enhance volunteer intelligence:
-- SELECT enhance_volunteer_intelligence();

-- 5. View statistics:
-- SELECT * FROM get_datatrust_statistics();
