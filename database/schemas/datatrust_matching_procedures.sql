-- ============================================================================
-- DATA TRUST MATCHING & INTEGRATION PROCEDURES (nc_datatrust canonical)
-- Part 3: Matching Functions, Sync Procedures, Algorithm Updates
-- ============================================================================
--
-- Rewritten from datatrust_profiles → public.nc_datatrust per docs/CANONICAL_TABLES_AUDIT.md
-- Column map (subset): rnc_id→rncid, first_name→firstname, last_name→lastname,
--   home_* → reg* / countyname, phone_primary→cell (fallback landline / append sources),
--   scores: turnout_likelihood_score→turnoutgeneralscore, modeled_partisanship→republicanpartyscore,
--   voter_regularity_score→voterregularitygeneral.
--
-- Prerequisites:
--   1) public.nc_datatrust populated
--   2) database/migrations/097_INTEGRATION_DATATRUST_CONTACT_LINK.sql applied
--   3) public.unified_contacts exists (CRM shell) if you run sync/enrichment functions
--
-- Note: nc_datatrust has no primary email column in the spine mapping doc; email match path is a no-op
-- unless you add a column later. Issue / volunteer / CoS helpers use coalition + score proxies.
-- ============================================================================

-- ============================================================================
-- MATCHING FUNCTIONS
-- ============================================================================

-- Function 1: Match Data Trust row to Unified Contact
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
    -- Try exact phone match (cell, landline, Neustar append phones)
    SELECT uc.contact_id, 100 INTO v_contact_id, v_match_score
    FROM public.unified_contacts uc
    INNER JOIN public.nc_datatrust dt ON dt.rncid::text = p_rnc_id
    WHERE (
        uc.mobile_phone IS NOT NULL AND (
            uc.mobile_phone IS NOT DISTINCT FROM dt.cell
         OR uc.mobile_phone IS NOT DISTINCT FROM dt.landline
         OR uc.mobile_phone IS NOT DISTINCT FROM dt.cellneustar
         OR uc.mobile_phone IS NOT DISTINCT FROM dt.landlineneustar
        )
    ) OR (
        uc.home_phone IS NOT NULL AND (
            uc.home_phone IS NOT DISTINCT FROM dt.landline
         OR uc.home_phone IS NOT DISTINCT FROM dt.cell
         OR uc.home_phone IS NOT DISTINCT FROM dt.landlineneustar
        )
    )
    LIMIT 1;

    IF v_contact_id IS NOT NULL THEN
        RETURN v_contact_id;
    END IF;

    -- Email: nc_datatrust typically has no email in current spine mapping; enable if you add column `email`
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'nc_datatrust' AND column_name = 'email'
    ) THEN
        SELECT uc.contact_id INTO v_contact_id
        FROM public.unified_contacts uc
        INNER JOIN public.nc_datatrust dt ON dt.rncid::text = p_rnc_id
        WHERE uc.email IS NOT NULL AND uc.email IS NOT DISTINCT FROM dt.email
        LIMIT 1;
        IF v_contact_id IS NOT NULL THEN
            RETURN v_contact_id;
        END IF;
    END IF;

    -- Fuzzy name + geography (NC only)
    FOR v_contact_id, v_match_score IN
        SELECT
            uc.contact_id,
            CASE WHEN uc.last_name_clean = dt.lastname THEN 30 ELSE 0 END +
            CASE WHEN uc.first_name_clean = dt.firstname THEN 20 ELSE 0 END +
            CASE WHEN uc.zip_code = dt.regzip5 THEN 20 ELSE 0 END +
            CASE WHEN uc.city = dt.regcity THEN 15 ELSE 0 END +
            CASE WHEN uc.county = dt.countyname THEN 15 ELSE 0 END AS match_score
        FROM public.unified_contacts uc
        CROSS JOIN public.nc_datatrust dt
        WHERE dt.rncid::text = p_rnc_id
          AND uc.last_name_clean = dt.lastname
          AND uc.state = 'NC'
        ORDER BY match_score DESC
        LIMIT 5
    LOOP
        IF v_match_score > v_best_score THEN
            v_best_score := v_match_score;
            v_best_match_id := v_contact_id;
        END IF;
    END LOOP;

    IF v_best_score >= 60 THEN
        RETURN v_best_match_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Sync Data Trust row into Unified Contact
CREATE OR REPLACE FUNCTION sync_datatrust_to_unified_contact(
    p_rnc_id VARCHAR(32)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_contact_id BIGINT;
    v_dt RECORD;
    v_addr TEXT;
    v_reg_score NUMERIC;
    v_turnout_score NUMERIC;
BEGIN
    SELECT * INTO v_dt
    FROM public.nc_datatrust
    WHERE rncid::text = p_rnc_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    v_reg_score := CASE
        WHEN v_dt.voterregularitygeneral ~ '^[0-9]*\.?[0-9]+$'
        THEN v_dt.voterregularitygeneral::numeric ELSE NULL END;
    v_turnout_score := CASE
        WHEN v_dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
        THEN v_dt.turnoutgeneralscore::numeric ELSE NULL END;

    v_contact_id := (
        SELECT lk.contact_id
        FROM integration.datatrust_contact_link lk
        WHERE lk.rncid = p_rnc_id
    );

    IF v_contact_id IS NULL THEN
        v_contact_id := match_datatrust_to_contact(p_rnc_id);
        IF v_contact_id IS NOT NULL THEN
            INSERT INTO integration.datatrust_contact_link (
                rncid, contact_id, synced_to_unified_contacts, sync_date, updated_at
            ) VALUES (
                p_rnc_id, v_contact_id, TRUE, now(), now()
            )
            ON CONFLICT (rncid) DO UPDATE SET
                contact_id = EXCLUDED.contact_id,
                synced_to_unified_contacts = TRUE,
                sync_date = now(),
                updated_at = now();
        END IF;
    END IF;

    v_addr := NULLIF(TRIM(COALESCE(v_dt.registrationaddr1, '')), '');
    IF v_addr IS NULL THEN
        v_addr := TRIM(CONCAT_WS(' ',
            NULLIF(TRIM(v_dt.reghousenum), ''),
            NULLIF(TRIM(v_dt.regstprefix), ''),
            NULLIF(TRIM(v_dt.regstname), ''),
            NULLIF(TRIM(v_dt.regsttype), '')
        ));
        v_addr := NULLIF(v_addr, '');
    END IF;

    IF v_contact_id IS NOT NULL THEN
        UPDATE public.unified_contacts SET
            mobile_phone = COALESCE(mobile_phone, v_dt.cell),
            home_phone = COALESCE(home_phone, v_dt.landline),
            street_line_1 = CASE
                WHEN v_addr IS NOT NULL AND street_line_1 IS NULL THEN v_addr
                ELSE street_line_1
            END,
            city = COALESCE(city, v_dt.regcity),
            state = COALESCE(state, v_dt.regsta),
            zip_code = COALESCE(zip_code, v_dt.regzip5),
            county = COALESCE(county, v_dt.countyname),
            custom_fields = COALESCE(custom_fields, '{}'::jsonb) || jsonb_build_object(
                'rncid', v_dt.rncid,
                'voter_registration_status', v_dt.voterstatus,
                'registered_party', v_dt.registeredparty,
                'partisanship_score', v_dt.republicanpartyscore,
                'turnout_score', v_dt.turnoutgeneralscore,
                'voter_regularity', v_dt.voterregularitygeneral,
                'congressional_district', v_dt.congressionaldistrict,
                'state_senate_district', v_dt.statelegupperdistrict,
                'state_house_district', v_dt.stateleglowerdistrict,
                'precinct', v_dt.precinctcode,
                'data_trust_synced', true,
                'data_trust_sync_date', NOW()
            ),
            engagement_score = GREATEST(
                engagement_score,
                COALESCE((v_reg_score * 50)::INTEGER, 0) +
                COALESCE((v_turnout_score * 30)::INTEGER, 0) +
                20
            ),
            updated_at = NOW()
        WHERE contact_id = v_contact_id;

        UPDATE integration.datatrust_contact_link SET
            synced_to_unified_contacts = TRUE,
            sync_date = now(),
            updated_at = now()
        WHERE rncid = p_rnc_id;

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
        SELECT dt.rncid::text AS rncid
        FROM public.nc_datatrust dt
        LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
        WHERE lk.rncid IS NULL
           OR lk.synced_to_unified_contacts = FALSE
           OR lk.contact_id IS NULL
        LIMIT p_limit
    ),
    ran AS (
        SELECT u.rncid, sync_datatrust_to_unified_contact(u.rncid) AS synced_ok
        FROM unsynced u
    )
    SELECT
        r.rncid::varchar(32),
        lk.contact_id,
        CASE WHEN lk.contact_id IS NOT NULL THEN 'matched'::varchar(20) ELSE 'no_match'::varchar(20) END,
        CASE WHEN lk.contact_id IS NOT NULL THEN 100 ELSE 0 END
    FROM ran r
    LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = r.rncid;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TARGETING FUNCTIONS FOR CAMPAIGNS
-- ============================================================================

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
        dt.rncid::varchar(32),
        lk.contact_id,
        (TRIM(COALESCE(dt.firstname, '') || ' ' || COALESCE(dt.lastname, '')))::varchar(255),
        COALESCE(dt.cell, dt.landline)::varchar(20),
        NULL::varchar(255),
        dt.countyname::varchar(100),
        dt.congressionaldistrict::varchar(10),
        CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.turnoutgeneralscore::numeric ELSE NULL END,
        CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.republicanpartyscore::numeric ELSE NULL END,
        (
         COALESCE(CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                  THEN dt.turnoutgeneralscore::numeric ELSE 0 END, 0) * 0.4 +
         COALESCE(CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                  THEN dt.republicanpartyscore::numeric ELSE 0 END, 0) * 0.3 +
         COALESCE(CASE WHEN dt.voterregularitygeneral ~ '^[0-9]*\.?[0-9]+$'
                  THEN dt.voterregularitygeneral::numeric ELSE 0 END, 0) * 0.2 +
         CASE WHEN uc.donor_grade IN ('A++', 'A+', 'A') THEN 0.1 ELSE 0 END
        )::numeric AS priority_score
    FROM public.nc_datatrust dt
    LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
    LEFT JOIN public.unified_contacts uc ON uc.contact_id = lk.contact_id
    WHERE UPPER(TRIM(COALESCE(dt.voterstatus, ''))) = 'A'
      AND COALESCE(dt.cell, dt.landline) IS NOT NULL
      AND (CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                THEN dt.turnoutgeneralscore::numeric ELSE 0 END) >= p_min_turnout_score
      AND (CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                THEN dt.republicanpartyscore::numeric ELSE 0 END) >= p_min_partisanship
      AND (p_county IS NULL OR dt.countyname = p_county)
      AND (p_district IS NULL OR dt.congressionaldistrict = p_district)
    ORDER BY priority_score DESC NULLS LAST
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Issue targeting: coalition Y/N flags (1.0) or republicanpartyscore (numeric)
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
BEGIN
    RETURN QUERY
    WITH scored AS (
        SELECT
            dt.*,
            lk.contact_id AS lk_contact_id,
            CASE lower(trim(p_issue_name))
                WHEN 'gun_rights' THEN
                    CASE WHEN upper(trim(coalesce(dt.coalitionid_2ndamendment, ''))) IN ('Y','1','T','TRUE') THEN 1.0::numeric
                         WHEN dt.coalitionid_2ndamendment ~ '^[0-9]*\.?[0-9]+$' THEN dt.coalitionid_2ndamendment::numeric
                         ELSE 0::numeric END
                WHEN 'abortion' THEN
                    CASE WHEN upper(trim(coalesce(dt.coalitionid_prolife, ''))) IN ('Y','1','T','TRUE') THEN 1.0::numeric
                         WHEN dt.coalitionid_prolife ~ '^[0-9]*\.?[0-9]+$' THEN dt.coalitionid_prolife::numeric
                         ELSE 0::numeric END
                WHEN 'border' THEN
                    CASE WHEN upper(trim(coalesce(dt.coalitionid_socialconservative, ''))) IN ('Y','1','T','TRUE') THEN 1.0::numeric
                         WHEN dt.coalitionid_socialconservative ~ '^[0-9]*\.?[0-9]+$' THEN dt.coalitionid_socialconservative::numeric
                         ELSE 0::numeric END
                WHEN 'school_choice' THEN
                    CASE WHEN upper(trim(coalesce(dt.coalitionid_fiscalconservative, ''))) IN ('Y','1','T','TRUE') THEN 1.0::numeric
                         WHEN dt.coalitionid_fiscalconservative ~ '^[0-9]*\.?[0-9]+$' THEN dt.coalitionid_fiscalconservative::numeric
                         ELSE 0::numeric END
                WHEN 'trump' THEN
                    CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$' THEN dt.republicanpartyscore::numeric ELSE 0::numeric END
                WHEN 'taxes' THEN
                    CASE WHEN upper(trim(coalesce(dt.coalitionid_fiscalconservative, ''))) IN ('Y','1','T','TRUE') THEN 1.0::numeric
                         WHEN dt.coalitionid_fiscalconservative ~ '^[0-9]*\.?[0-9]+$' THEN dt.coalitionid_fiscalconservative::numeric
                         ELSE 0::numeric END
                WHEN 'law_order' THEN
                    CASE WHEN upper(trim(coalesce(dt.coalitionid_socialconservative, ''))) IN ('Y','1','T','TRUE') THEN 1.0::numeric
                         WHEN dt.coalitionid_socialconservative ~ '^[0-9]*\.?[0-9]+$' THEN dt.coalitionid_socialconservative::numeric
                         ELSE 0::numeric END
                ELSE
                    CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$' THEN dt.republicanpartyscore::numeric ELSE 0::numeric END
            END AS computed_issue,
            CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                 THEN dt.turnoutgeneralscore::numeric ELSE NULL END AS computed_turnout
        FROM public.nc_datatrust dt
        LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
        WHERE upper(trim(coalesce(dt.voterstatus, ''))) = 'A'
          AND (p_county IS NULL OR dt.countyname = p_county)
          AND COALESCE(
                CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                     THEN dt.turnoutgeneralscore::numeric ELSE 0 END, 0
              ) > 0.4
    )
    SELECT
        s.rncid::varchar(32),
        s.lk_contact_id,
        (TRIM(COALESCE(s.firstname, '') || ' ' || COALESCE(s.lastname, '')))::varchar(255),
        COALESCE(s.cell, s.landline)::varchar(20),
        NULL::varchar(255),
        s.computed_issue,
        s.computed_turnout
    FROM scored s
    WHERE s.computed_issue >= p_min_issue_score
    ORDER BY s.computed_issue DESC NULLS LAST, s.computed_turnout DESC NULLS LAST
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

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
        dt.rncid::varchar(32),
        lk.contact_id,
        (TRIM(COALESCE(dt.firstname, '') || ' ' || COALESCE(dt.lastname, '')))::varchar(255),
        COALESCE(dt.cell, dt.landline)::varchar(20),
        NULL::varchar(255),
        CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.republicanpartyscore::numeric ELSE NULL END,
        CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.turnoutgeneralscore::numeric ELSE NULL END,
        uc.donor_grade::varchar(10)
    FROM public.nc_datatrust dt
    LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
    LEFT JOIN public.unified_contacts uc ON uc.contact_id = lk.contact_id
    WHERE UPPER(TRIM(COALESCE(dt.voterstatus, ''))) = 'A'
      AND (CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                THEN dt.republicanpartyscore::numeric ELSE 0 END) >= p_min_activism_score
      AND (CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                THEN dt.turnoutgeneralscore::numeric ELSE 0 END) > 0.6
      AND (p_county IS NULL OR dt.countyname = p_county)
      AND dt.cell IS NOT NULL
    ORDER BY
        CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.turnoutgeneralscore::numeric ELSE 0 END DESC NULLS LAST,
        CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.republicanpartyscore::numeric ELSE 0 END DESC NULLS LAST
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_council_of_state_targets(
    p_office VARCHAR(50),
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
        dt.rncid::varchar(32),
        lk.contact_id,
        (TRIM(COALESCE(dt.firstname, '') || ' ' || COALESCE(dt.lastname, '')))::varchar(255),
        COALESCE(dt.cell, dt.landline)::varchar(20),
        NULL::varchar(255),
        dt.countyname::varchar(100),
        CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.turnoutgeneralscore::numeric ELSE NULL END,
        CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.republicanpartyscore::numeric ELSE NULL END,
        CASE lower(trim(p_office))
            WHEN 'agriculture' THEN upper(trim(coalesce(dt.coalitionid_sportsmen, ''))) IN ('Y','1','T','TRUE')
            WHEN 'labor' THEN upper(trim(coalesce(dt.coalitionid_veteran, ''))) IN ('Y','1','T','TRUE')
            WHEN 'insurance' THEN upper(trim(coalesce(dt.coalitionid_fiscalconservative, ''))) IN ('Y','1','T','TRUE')
            WHEN 'education' THEN upper(trim(coalesce(dt.coalitionid_socialconservative, ''))) IN ('Y','1','T','TRUE')
            WHEN 'treasurer' THEN upper(trim(coalesce(dt.coalitionid_fiscalconservative, ''))) IN ('Y','1','T','TRUE')
            ELSE FALSE
        END
    FROM public.nc_datatrust dt
    LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
    WHERE UPPER(TRIM(COALESCE(dt.voterstatus, ''))) = 'A'
      AND (CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                THEN dt.turnoutgeneralscore::numeric ELSE 0 END) >= p_min_turnout
      AND (CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                THEN dt.republicanpartyscore::numeric ELSE 0 END) >= 0.5
      AND COALESCE(dt.cell, dt.landline) IS NOT NULL
    ORDER BY
        CASE
            WHEN CASE lower(trim(p_office))
                WHEN 'agriculture' THEN upper(trim(coalesce(dt.coalitionid_sportsmen, ''))) IN ('Y','1','T','TRUE')
                WHEN 'labor' THEN upper(trim(coalesce(dt.coalitionid_veteran, ''))) IN ('Y','1','T','TRUE')
                WHEN 'insurance' THEN upper(trim(coalesce(dt.coalitionid_fiscalconservative, ''))) IN ('Y','1','T','TRUE')
                WHEN 'education' THEN upper(trim(coalesce(dt.coalitionid_socialconservative, ''))) IN ('Y','1','T','TRUE')
                WHEN 'treasurer' THEN upper(trim(coalesce(dt.coalitionid_fiscalconservative, ''))) IN ('Y','1','T','TRUE')
                ELSE FALSE
            END THEN 1 ELSE 2
        END,
        CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
             THEN dt.turnoutgeneralscore::numeric ELSE 0 END DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ALGORITHM UPDATES FOR ECOSYSTEM
-- ============================================================================

CREATE OR REPLACE FUNCTION update_ml_model_inputs()
RETURNS INTEGER AS $$
DECLARE
    v_updated_count INTEGER := 0;
BEGIN
    -- Dynamic SQL so CREATE FUNCTION succeeds when ml_contact_predictions is not deployed yet
    IF to_regclass('public.ml_contact_predictions') IS NULL THEN
        RETURN 0;
    END IF;
    EXECUTE $ml$
    UPDATE ml_contact_predictions mcp
    SET
        will_open_next_email = GREATEST(
            mcp.will_open_next_email,
            CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                 THEN dt.turnoutgeneralscore::numeric * 0.7 ELSE mcp.will_open_next_email END
        ),
        will_volunteer_next = GREATEST(
            mcp.will_volunteer_next,
            CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                 THEN dt.turnoutgeneralscore::numeric ELSE mcp.will_volunteer_next END
        ),
        best_send_hour = COALESCE(
            mcp.best_send_hour,
            CASE
                WHEN trim(coalesce(dt.cellneustartimeofday, '')) ~ '^[0-9]{1,2}:[0-9]{2}'
                THEN EXTRACT(HOUR FROM trim(dt.cellneustartimeofday)::time)::integer
                WHEN trim(coalesce(dt.landlineneustartimeofday, '')) ~ '^[0-9]{1,2}:[0-9]{2}'
                THEN EXTRACT(HOUR FROM trim(dt.landlineneustartimeofday)::time)::integer
                ELSE 10
            END
        ),
        confidence = LEAST(1.0, mcp.confidence + 0.05),
        model_version = 'v2.1_nc_datatrust',
        prediction_date = NOW()
    FROM public.nc_datatrust dt
    INNER JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
    INNER JOIN public.unified_contacts uc ON lk.contact_id = uc.contact_id
    WHERE mcp.contact_id = uc.contact_id
      AND lk.synced_to_unified_contacts = TRUE
    $ml$;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION enhance_donor_intelligence()
RETURNS INTEGER AS $$
DECLARE
    v_enhanced_count INTEGER := 0;
BEGIN
    UPDATE public.unified_contacts uc
    SET
        custom_fields = COALESCE(uc.custom_fields, '{}'::jsonb) || jsonb_build_object(
            'voter_regularity', dt.voterregularitygeneral,
            'turnout_score', dt.turnoutgeneralscore,
            'partisanship_strength', CASE
                WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$' AND dt.republicanpartyscore::numeric > 0.8 THEN 'strong_republican'
                WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$' AND dt.republicanpartyscore::numeric > 0.6 THEN 'lean_republican'
                WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$' AND dt.republicanpartyscore::numeric > 0.4 THEN 'swing'
                WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$' AND dt.republicanpartyscore::numeric > 0.2 THEN 'lean_democrat'
                ELSE 'strong_democrat'
            END,
            'primary_voter', CASE
                WHEN dt.voterregularitygeneral ~ '^[0-9]*\.?[0-9]+$' AND dt.voterregularitygeneral::numeric > 0.7 THEN TRUE
                ELSE FALSE
            END,
            'issue_top_priority', CASE
                WHEN upper(trim(coalesce(dt.coalitionid_2ndamendment, ''))) IN ('Y','1','T','TRUE') THEN '2A'
                WHEN upper(trim(coalesce(dt.coalitionid_prolife, ''))) IN ('Y','1','T','TRUE') THEN 'pro_life'
                WHEN upper(trim(coalesce(dt.coalitionid_socialconservative, ''))) IN ('Y','1','T','TRUE') THEN 'social_conservative'
                WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$' AND dt.republicanpartyscore::numeric > 0.7 THEN 'partisan_gop'
                ELSE 'mixed'
            END
        ),
        engagement_score = LEAST(
            100,
            uc.engagement_score +
            COALESCE(CASE WHEN dt.voterregularitygeneral ~ '^[0-9]*\.?[0-9]+$'
                     THEN (dt.voterregularitygeneral::numeric * 20)::integer ELSE 0 END, 0) +
            COALESCE(CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                     THEN (dt.turnoutgeneralscore::numeric * 15)::integer ELSE 0 END, 0)
        ),
        updated_at = NOW()
    FROM public.nc_datatrust dt
    INNER JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
    WHERE uc.contact_id = lk.contact_id
      AND uc.donor_grade IS NOT NULL
      AND lk.synced_to_unified_contacts = TRUE;

    GET DIAGNOSTICS v_enhanced_count = ROW_COUNT;
    RETURN v_enhanced_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION enhance_volunteer_intelligence()
RETURNS INTEGER AS $$
DECLARE
    v_enhanced_count INTEGER := 0;
BEGIN
    UPDATE public.unified_contacts uc
    SET
        custom_fields = COALESCE(uc.custom_fields, '{}'::jsonb) || jsonb_build_object(
            'activism_proxy_republican_score', dt.republicanpartyscore,
            'volunteer_proxy_turnout_score', dt.turnoutgeneralscore,
            'donorflag', dt.donorflag,
            'reliable_volunteer_predicted', CASE
                WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$' AND dt.turnoutgeneralscore::numeric > 0.6
                 AND dt.voterregularitygeneral ~ '^[0-9]*\.?[0-9]+$' AND dt.voterregularitygeneral::numeric > 0.7
                THEN TRUE ELSE FALSE
            END
        ),
        engagement_score = LEAST(
            100,
            uc.engagement_score +
            COALESCE(CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                     THEN (dt.republicanpartyscore::numeric * 25)::integer ELSE 0 END, 0)
        ),
        updated_at = NOW()
    FROM public.nc_datatrust dt
    INNER JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
    WHERE uc.contact_id = lk.contact_id
      AND uc.volunteer_status IN ('active', 'prospective')
      AND lk.synced_to_unified_contacts = TRUE;

    GET DIAGNOSTICS v_enhanced_count = ROW_COUNT;
    RETURN v_enhanced_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_campaign_list(
    p_campaign_type VARCHAR(50),
    p_geography_filter JSONB DEFAULT '{}',
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
            dt.rncid::varchar(32),
            lk.contact_id,
            (TRIM(COALESCE(dt.firstname, '') || ' ' || COALESCE(dt.lastname, '')))::varchar(255),
            COALESCE(dt.cell, dt.landline)::varchar(20),
            NULL::varchar(255),
            CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                 THEN dt.turnoutgeneralscore::numeric ELSE NULL END,
            CASE
                WHEN upper(trim(coalesce(dt.permanentabsentee, ''))) IN ('Y','1','T','TRUE') THEN 'absentee_ballot'
                ELSE 'election_day'
            END::varchar(50),
            COALESCE(
                NULLIF(trim(dt.cellneustartimeofday), ''),
                NULLIF(trim(dt.landlineneustartimeofday), ''),
                'business_hours'
            )::varchar(50)
        FROM public.nc_datatrust dt
        LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
        WHERE (CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                    THEN dt.turnoutgeneralscore::numeric ELSE 0 END) BETWEEN 0.4 AND 0.7
          AND (CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                    THEN dt.republicanpartyscore::numeric ELSE 0 END) > 0.5
          AND UPPER(TRIM(COALESCE(dt.voterstatus, ''))) = 'A'
          AND (p_geography_filter = '{}'::jsonb
               OR (
                 (p_geography_filter->>'county' IS NULL OR dt.countyname = p_geography_filter->>'county')
                 AND (p_geography_filter->>'district' IS NULL OR dt.congressionaldistrict = p_geography_filter->>'district')
               ))
        ORDER BY CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                      THEN dt.turnoutgeneralscore::numeric ELSE 0 END DESC
        LIMIT p_limit;

    ELSIF p_campaign_type = 'persuasion' THEN
        RETURN QUERY
        SELECT
            dt.rncid::varchar(32),
            lk.contact_id,
            (TRIM(COALESCE(dt.firstname, '') || ' ' || COALESCE(dt.lastname, '')))::varchar(255),
            COALESCE(dt.cell, dt.landline)::varchar(20),
            NULL::varchar(255),
            (ABS(0.5 - COALESCE(CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                               THEN dt.republicanpartyscore::numeric ELSE 0.5 END, 0.5)) * -2 + 1)::numeric,
            CASE
                WHEN upper(trim(coalesce(dt.coalitionid_2ndamendment, ''))) IN ('Y','1','T','TRUE') THEN 'gun_rights'
                WHEN upper(trim(coalesce(dt.coalitionid_prolife, ''))) IN ('Y','1','T','TRUE') THEN 'pro_life'
                WHEN upper(trim(coalesce(dt.coalitionid_socialconservative, ''))) IN ('Y','1','T','TRUE') THEN 'social_conservative'
                ELSE 'economy'
            END::varchar(50),
            COALESCE(
                NULLIF(trim(dt.cellneustartimeofday), ''),
                NULLIF(trim(dt.landlineneustartimeofday), ''),
                'business_hours'
            )::varchar(50)
        FROM public.nc_datatrust dt
        LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
        WHERE (CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                    THEN dt.republicanpartyscore::numeric ELSE 0.5 END) BETWEEN 0.35 AND 0.65
          AND (CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                    THEN dt.turnoutgeneralscore::numeric ELSE 0 END) > 0.5
          AND UPPER(TRIM(COALESCE(dt.voterstatus, ''))) = 'A'
          AND (p_geography_filter = '{}'::jsonb
               OR (p_geography_filter->>'county' IS NULL OR dt.countyname = p_geography_filter->>'county'))
        ORDER BY 6 DESC
        LIMIT p_limit;

    ELSIF p_campaign_type = 'donor' THEN
        RETURN QUERY
        SELECT
            dt.rncid::varchar(32),
            lk.contact_id,
            (TRIM(COALESCE(dt.firstname, '') || ' ' || COALESCE(dt.lastname, '')))::varchar(255),
            COALESCE(dt.cell, dt.landline)::varchar(20),
            NULL::varchar(255),
            (
              CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                   THEN dt.republicanpartyscore::numeric * 0.4 ELSE 0 END +
              CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                   THEN dt.turnoutgeneralscore::numeric * 0.3 ELSE 0 END +
              0.3
            )::numeric,
            CASE
                WHEN uc.donor_grade IN ('A++', 'A+', 'A') THEN 'major_donor_upgrade'
                WHEN uc.total_donations_aggregated > 0 THEN 'lapsed_donor'
                ELSE 'prospective_donor'
            END::varchar(50),
            COALESCE(
                NULLIF(trim(dt.cellneustartimeofday), ''),
                NULLIF(trim(dt.landlineneustartimeofday), ''),
                'business_hours'
            )::varchar(50)
        FROM public.nc_datatrust dt
        LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
        LEFT JOIN public.unified_contacts uc ON uc.contact_id = lk.contact_id
        WHERE (CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                    THEN dt.republicanpartyscore::numeric ELSE 0 END) > 0.6
          AND UPPER(TRIM(COALESCE(dt.voterstatus, ''))) = 'A'
          AND (p_geography_filter = '{}'::jsonb
               OR (p_geography_filter->>'county' IS NULL OR dt.countyname = p_geography_filter->>'county'))
        ORDER BY 6 DESC
        LIMIT p_limit;

    ELSIF p_campaign_type = 'volunteer' THEN
        RETURN QUERY
        SELECT
            dt.rncid::varchar(32),
            lk.contact_id,
            (TRIM(COALESCE(dt.firstname, '') || ' ' || COALESCE(dt.lastname, '')))::varchar(255),
            COALESCE(dt.cell, dt.landline)::varchar(20),
            NULL::varchar(255),
            CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                 THEN dt.turnoutgeneralscore::numeric ELSE NULL END,
            'volunteer_recruitment'::varchar(50),
            COALESCE(
                NULLIF(trim(dt.cellneustartimeofday), ''),
                NULLIF(trim(dt.landlineneustartimeofday), ''),
                'business_hours'
            )::varchar(50)
        FROM public.nc_datatrust dt
        LEFT JOIN integration.datatrust_contact_link lk ON lk.rncid = dt.rncid::text
        WHERE (CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                    THEN dt.turnoutgeneralscore::numeric ELSE 0 END) > 0.5
          AND (CASE WHEN dt.republicanpartyscore ~ '^[0-9]*\.?[0-9]+$'
                    THEN dt.republicanpartyscore::numeric ELSE 0 END) > 0.4
          AND (CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                    THEN dt.turnoutgeneralscore::numeric ELSE 0 END) > 0.6
          AND UPPER(TRIM(COALESCE(dt.voterstatus, ''))) = 'A'
          AND (p_geography_filter = '{}'::jsonb
               OR (p_geography_filter->>'county' IS NULL OR dt.countyname = p_geography_filter->>'county'))
        ORDER BY CASE WHEN dt.turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$'
                      THEN dt.turnoutgeneralscore::numeric ELSE 0 END DESC
        LIMIT p_limit;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_datatrust_statistics()
RETURNS TABLE(
    stat_name VARCHAR(50),
    stat_value TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'total_profiles'::varchar(50), COUNT(*)::text FROM public.nc_datatrust
    UNION ALL
    SELECT 'synced_to_contacts'::varchar(50),
           COUNT(*)::text FROM integration.datatrust_contact_link WHERE contact_id IS NOT NULL
    UNION ALL
    SELECT 'has_mobile_phone'::varchar(50),
           COUNT(*)::text FROM public.nc_datatrust WHERE cell IS NOT NULL AND trim(cell) <> ''
    UNION ALL
    SELECT 'has_email'::varchar(50), '0'::text
    UNION ALL
    SELECT 'active_voters'::varchar(50),
           COUNT(*)::text FROM public.nc_datatrust WHERE upper(trim(coalesce(voterstatus, ''))) = 'A'
    UNION ALL
    SELECT 'republicans'::varchar(50),
           COUNT(*)::text FROM public.nc_datatrust
           WHERE republicanpartyscore ~ '^[0-9]*\.?[0-9]+$' AND republicanpartyscore::numeric > 0.6
    UNION ALL
    SELECT 'high_turnout'::varchar(50),
           COUNT(*)::text FROM public.nc_datatrust
           WHERE turnoutgeneralscore ~ '^[0-9]*\.?[0-9]+$' AND turnoutgeneralscore::numeric > 0.7
    UNION ALL
    SELECT 'matched_donors'::varchar(50),
           COUNT(*)::text
    FROM integration.datatrust_contact_link lk
    INNER JOIN public.unified_contacts uc ON lk.contact_id = uc.contact_id
    WHERE uc.donor_grade IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION match_datatrust_to_contact IS
  'Matches nc_datatrust row to unified_contacts via phone, optional email column, name+geo (NC).';
COMMENT ON FUNCTION sync_datatrust_to_unified_contact IS
  'Enriches unified_contacts from nc_datatrust; persists link in integration.datatrust_contact_link.';
COMMENT ON FUNCTION bulk_sync_datatrust IS 'Bulk sync using nc_datatrust + integration.datatrust_contact_link.';
COMMENT ON FUNCTION get_voter_targets IS 'GOTV-style list from nc_datatrust (active = voterstatus A).';
COMMENT ON FUNCTION get_issue_targets IS
  'Issue targeting via coalition flags / republicanpartyscore (nc_datatrust column whitelist).';
COMMENT ON FUNCTION get_volunteer_targets IS
  'Volunteer prospects using republicanpartyscore + turnoutgeneralscore as proxies.';
COMMENT ON FUNCTION get_council_of_state_targets IS
  'Statewide list; office_interest uses coalition flags (proxy for legacy nc_*_interest columns).';
COMMENT ON FUNCTION update_ml_model_inputs IS 'Updates ml_contact_predictions from nc_datatrust via contact link.';
COMMENT ON FUNCTION enhance_donor_intelligence IS 'Donor custom_fields from nc_datatrust coalition + scores.';
COMMENT ON FUNCTION enhance_volunteer_intelligence IS 'Volunteer custom_fields from nc_datatrust scores.';
COMMENT ON FUNCTION generate_campaign_list IS 'Campaign lists from nc_datatrust + optional unified_contacts join.';
COMMENT ON FUNCTION get_datatrust_statistics IS 'Row counts from nc_datatrust + integration.datatrust_contact_link.';
