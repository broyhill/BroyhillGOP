-- ============================================================================
-- E01 EXTENSION: DATA IMPORT ENGINE WITH CONTROL PANEL
-- Database Schema
-- ============================================================================
-- 
-- Hierarchical Control Panel Architecture:
--   MASTER SWITCH → CATEGORY CONTROLS → FUNCTION TOGGLES
--
-- Each level supports: ON / OFF / TIMER states
-- Timer allows temporary enable/disable with auto-revert
--
-- Access Levels:
--   - BROYHILLGOP_ADMIN: Full platform control
--   - CAMPAIGN_MANAGER: Assigned candidate controls
--   - CANDIDATE: Own data controls only
--
-- ============================================================================

-- ============================================================================
-- CONTROL PANEL TABLES
-- ============================================================================

-- Master Switch (top of hierarchy)
-- Controls: Entire import system ON/OFF/TIMER
CREATE TABLE IF NOT EXISTS import_control_master (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL DEFAULT 'global',  -- 'global' or candidate_id
    state VARCHAR(20) NOT NULL DEFAULT 'on' CHECK (state IN ('on', 'off', 'timer')),
    timer_end TIMESTAMP,
    timer_duration_minutes INTEGER DEFAULT 0,
    emergency_shutdown BOOLEAN DEFAULT FALSE,
    shutdown_reason TEXT,
    last_modified_by UUID,
    last_modified_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(scope)
);

-- Category Controls (middle of hierarchy)
-- Controls: Groups of related functions
-- Categories: file_parsing, normalization, deduplication, enrichment, notifications
CREATE TABLE IF NOT EXISTS import_control_categories (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL DEFAULT 'global',
    category VARCHAR(50) NOT NULL CHECK (category IN (
        'file_parsing', 'normalization', 'deduplication', 'enrichment', 'notifications'
    )),
    state VARCHAR(20) NOT NULL DEFAULT 'on' CHECK (state IN ('on', 'off', 'timer')),
    timer_end TIMESTAMP,
    timer_duration_minutes INTEGER DEFAULT 0,
    last_modified_by UUID,
    last_modified_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(scope, category)
);

-- Function Toggles (bottom of hierarchy)
-- Controls: Individual import functions
CREATE TABLE IF NOT EXISTS import_control_functions (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL DEFAULT 'global',
    function_id VARCHAR(100) NOT NULL,
    function_name VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    state VARCHAR(20) NOT NULL DEFAULT 'on' CHECK (state IN ('on', 'off', 'timer')),
    timer_end TIMESTAMP,
    timer_duration_minutes INTEGER DEFAULT 0,
    min_access_level VARCHAR(50) DEFAULT 'candidate' CHECK (min_access_level IN (
        'broyhillgop_admin', 'campaign_manager', 'candidate'
    )),
    last_modified_by UUID,
    last_modified_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(scope, function_id)
);

-- Access Control
-- Maps users to access levels and candidate permissions
CREATE TABLE IF NOT EXISTS import_control_access (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    access_level VARCHAR(50) NOT NULL CHECK (access_level IN (
        'broyhillgop_admin', 'campaign_manager', 'candidate'
    )),
    candidate_ids UUID[],  -- NULL = all candidates (for admin)
    granted_by UUID,
    granted_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id)
);

-- Audit Log
-- Tracks all control panel changes
CREATE TABLE IF NOT EXISTS import_control_audit (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL CHECK (target_type IN ('master', 'category', 'function')),
    target_id VARCHAR(100),
    old_state VARCHAR(20),
    new_state VARCHAR(20),
    old_timer_end TIMESTAMP,
    new_timer_end TIMESTAMP,
    performed_by UUID,
    performed_at TIMESTAMP DEFAULT NOW(),
    ip_address VARCHAR(50),
    user_agent TEXT
);

-- ============================================================================
-- IMPORT JOB TABLES
-- ============================================================================

-- Import Jobs - Tracks each file upload
CREATE TABLE IF NOT EXISTS import_jobs (
    import_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    uploaded_by UUID NOT NULL,
    file_name VARCHAR(500) NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    file_size_bytes BIGINT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN (
        'pending', 'processing', 'completed', 'failed', 'cancelled'
    )),
    total_rows INTEGER DEFAULT 0,
    imported_count INTEGER DEFAULT 0,
    duplicate_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    skipped_count INTEGER DEFAULT 0,
    error_details JSONB,
    column_mapping JSONB,
    settings JSONB,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    duration_seconds DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Import Staging - Temporary storage during import
CREATE TABLE IF NOT EXISTS import_staging (
    staging_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    import_id UUID NOT NULL REFERENCES import_jobs(import_id) ON DELETE CASCADE,
    row_number INTEGER NOT NULL,
    raw_data JSONB NOT NULL,
    normalized_data JSONB,
    email VARCHAR(255),
    phone VARCHAR(20),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    donation_amount DECIMAL(12,2),
    donation_date TIMESTAMP,
    validation_errors JSONB,
    is_duplicate BOOLEAN DEFAULT FALSE,
    duplicate_of UUID,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Column Mappings - Learned from imports
CREATE TABLE IF NOT EXISTS import_column_mappings (
    id SERIAL PRIMARY KEY,
    source_type VARCHAR(50) NOT NULL,  -- 'winred', 'anedot', 'custom'
    source_column VARCHAR(200) NOT NULL,
    target_column VARCHAR(100) NOT NULL,
    confidence DECIMAL(5,2) DEFAULT 100,
    usage_count INTEGER DEFAULT 1,
    last_used_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(source_type, source_column)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_import_control_master_scope ON import_control_master(scope);
CREATE INDEX IF NOT EXISTS idx_import_control_categories_scope ON import_control_categories(scope);
CREATE INDEX IF NOT EXISTS idx_import_control_functions_scope ON import_control_functions(scope);
CREATE INDEX IF NOT EXISTS idx_import_control_functions_category ON import_control_functions(category);
CREATE INDEX IF NOT EXISTS idx_import_control_access_user ON import_control_access(user_id);
CREATE INDEX IF NOT EXISTS idx_import_control_audit_scope ON import_control_audit(scope, performed_at);
CREATE INDEX IF NOT EXISTS idx_import_jobs_candidate ON import_jobs(candidate_id);
CREATE INDEX IF NOT EXISTS idx_import_jobs_status ON import_jobs(status);
CREATE INDEX IF NOT EXISTS idx_import_staging_import ON import_staging(import_id);
CREATE INDEX IF NOT EXISTS idx_import_staging_email ON import_staging(email);

-- ============================================================================
-- DEFAULT DATA
-- ============================================================================

-- Initialize global master control
INSERT INTO import_control_master (scope, state) VALUES ('global', 'on')
ON CONFLICT (scope) DO NOTHING;

-- Initialize global category controls
INSERT INTO import_control_categories (scope, category, state) VALUES
    ('global', 'file_parsing', 'on'),
    ('global', 'normalization', 'on'),
    ('global', 'deduplication', 'on'),
    ('global', 'enrichment', 'on'),
    ('global', 'notifications', 'on')
ON CONFLICT (scope, category) DO NOTHING;

-- Initialize function toggles
-- FILE_PARSING functions
INSERT INTO import_control_functions (scope, function_id, function_name, category, description, state, min_access_level) VALUES
    ('global', 'parse_csv', 'CSV File Parsing', 'file_parsing', 'Parse CSV files and extract donor records', 'on', 'candidate'),
    ('global', 'parse_xlsx', 'Excel File Parsing', 'file_parsing', 'Parse XLS/XLSX files and extract donor records', 'on', 'candidate'),
    ('global', 'parse_pdf', 'PDF File Parsing', 'file_parsing', 'Parse PDF files with table extraction', 'on', 'candidate'),
    ('global', 'auto_detect_columns', 'Auto-Detect Columns', 'file_parsing', 'Automatically map source columns to donor schema', 'on', 'candidate'),
    ('global', 'winred_format', 'WinRed Format Support', 'file_parsing', 'Native support for WinRed export format', 'on', 'candidate'),
    ('global', 'anedot_format', 'Anedot Format Support', 'file_parsing', 'Native support for Anedot export format', 'on', 'candidate')
ON CONFLICT (scope, function_id) DO NOTHING;

-- NORMALIZATION functions
INSERT INTO import_control_functions (scope, function_id, function_name, category, description, state, min_access_level) VALUES
    ('global', 'normalize_phone', 'Phone Number Normalization', 'normalization', 'Standardize phone numbers to 10-digit format', 'on', 'candidate'),
    ('global', 'normalize_email', 'Email Normalization', 'normalization', 'Lowercase, trim, and validate email addresses', 'on', 'candidate'),
    ('global', 'normalize_name', 'Name Normalization', 'normalization', 'Split full names, proper case, handle suffixes', 'on', 'candidate'),
    ('global', 'normalize_address', 'Address Normalization', 'normalization', 'Standardize addresses (St/Street, Ave/Avenue)', 'on', 'candidate'),
    ('global', 'normalize_state', 'State Normalization', 'normalization', 'Convert state names to 2-letter codes', 'on', 'candidate'),
    ('global', 'normalize_zip', 'ZIP Code Normalization', 'normalization', 'Standardize ZIP codes (5 or 9 digit)', 'on', 'candidate')
ON CONFLICT (scope, function_id) DO NOTHING;

-- DEDUPLICATION functions
INSERT INTO import_control_functions (scope, function_id, function_name, category, description, state, min_access_level) VALUES
    ('global', 'dedupe_exact_email', 'Exact Email Match', 'deduplication', 'Find duplicates by exact email match', 'on', 'candidate'),
    ('global', 'dedupe_exact_phone', 'Exact Phone Match', 'deduplication', 'Find duplicates by exact phone match', 'on', 'candidate'),
    ('global', 'dedupe_fuzzy_name', 'Fuzzy Name Match', 'deduplication', 'Find duplicates by fuzzy name matching (85% threshold)', 'on', 'campaign_manager'),
    ('global', 'dedupe_fuzzy_address', 'Fuzzy Address Match', 'deduplication', 'Find duplicates by fuzzy address matching', 'on', 'campaign_manager'),
    ('global', 'dedupe_merge_records', 'Auto-Merge Duplicates', 'deduplication', 'Automatically merge confirmed duplicates', 'on', 'campaign_manager')
ON CONFLICT (scope, function_id) DO NOTHING;

-- ENRICHMENT functions
INSERT INTO import_control_functions (scope, function_id, function_name, category, description, state, min_access_level) VALUES
    ('global', 'enrich_calculate_grade', 'Calculate Donor Grade', 'enrichment', 'Calculate 3D donor grade after import', 'on', 'candidate'),
    ('global', 'enrich_rfm_score', 'Calculate RFM Score', 'enrichment', 'Calculate RFM score after import', 'on', 'candidate'),
    ('global', 'enrich_match_datatrust', 'Match Against DataTrust', 'enrichment', 'Match imported donors against RNC DataTrust', 'on', 'campaign_manager'),
    ('global', 'enrich_append_voter', 'Append Voter Data', 'enrichment', 'Append NC voter file data to imported records', 'on', 'campaign_manager')
ON CONFLICT (scope, function_id) DO NOTHING;

-- NOTIFICATIONS functions
INSERT INTO import_control_functions (scope, function_id, function_name, category, description, state, min_access_level) VALUES
    ('global', 'notify_import_complete', 'Import Complete Notification', 'notifications', 'Send notification when import completes', 'on', 'candidate'),
    ('global', 'notify_duplicates_found', 'Duplicates Found Alert', 'notifications', 'Alert when significant duplicates found', 'on', 'candidate'),
    ('global', 'notify_errors', 'Import Error Alerts', 'notifications', 'Alert on import errors', 'on', 'candidate'),
    ('global', 'notify_e20_brain', 'Notify E20 Brain', 'notifications', 'Send events to E20 Intelligence Brain', 'on', 'broyhillgop_admin')
ON CONFLICT (scope, function_id) DO NOTHING;

-- Pre-populate WinRed column mappings
INSERT INTO import_column_mappings (source_type, source_column, target_column, confidence) VALUES
    ('winred', 'contributor_email', 'email', 100),
    ('winred', 'contributor_first_name', 'first_name', 100),
    ('winred', 'contributor_last_name', 'last_name', 100),
    ('winred', 'contributor_phone', 'phone', 100),
    ('winred', 'contributor_address', 'address', 100),
    ('winred', 'contributor_city', 'city', 100),
    ('winred', 'contributor_state', 'state', 100),
    ('winred', 'contributor_zip', 'zip_code', 100),
    ('winred', 'amount', 'donation_amount', 100),
    ('winred', 'created_at', 'donation_date', 100)
ON CONFLICT (source_type, source_column) DO NOTHING;

-- Pre-populate Anedot column mappings
INSERT INTO import_column_mappings (source_type, source_column, target_column, confidence) VALUES
    ('anedot', 'email_address', 'email', 100),
    ('anedot', 'email', 'email', 100),
    ('anedot', 'first', 'first_name', 100),
    ('anedot', 'first_name', 'first_name', 100),
    ('anedot', 'last', 'last_name', 100),
    ('anedot', 'last_name', 'last_name', 100),
    ('anedot', 'phone', 'phone', 100),
    ('anedot', 'phone_number', 'phone', 100),
    ('anedot', 'address_line_1', 'address', 100),
    ('anedot', 'address', 'address', 100),
    ('anedot', 'city', 'city', 100),
    ('anedot', 'state', 'state', 100),
    ('anedot', 'zip', 'zip_code', 100),
    ('anedot', 'postal_code', 'zip_code', 100),
    ('anedot', 'amount', 'donation_amount', 100),
    ('anedot', 'total_amount', 'donation_amount', 100),
    ('anedot', 'date', 'donation_date', 100),
    ('anedot', 'created_at', 'donation_date', 100)
ON CONFLICT (source_type, source_column) DO NOTHING;

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Control Panel Status View
CREATE OR REPLACE VIEW v_import_control_status AS
SELECT 
    m.scope,
    m.state as master_state,
    m.emergency_shutdown,
    m.shutdown_reason,
    m.timer_end as master_timer_end,
    CASE 
        WHEN m.emergency_shutdown THEN FALSE
        WHEN m.state = 'off' THEN FALSE
        WHEN m.state = 'on' THEN TRUE
        WHEN m.state = 'timer' AND m.timer_end > NOW() THEN TRUE
        ELSE FALSE
    END as master_is_active,
    (
        SELECT jsonb_object_agg(category, jsonb_build_object(
            'state', state,
            'timer_end', timer_end,
            'is_active', CASE 
                WHEN state = 'off' THEN FALSE
                WHEN state = 'on' THEN TRUE
                WHEN state = 'timer' AND timer_end > NOW() THEN TRUE
                ELSE FALSE
            END
        ))
        FROM import_control_categories c
        WHERE c.scope = m.scope
    ) as categories,
    (SELECT count(*) FROM import_control_functions f WHERE f.scope = m.scope AND f.state = 'on') as functions_on,
    (SELECT count(*) FROM import_control_functions f WHERE f.scope = m.scope AND f.state = 'off') as functions_off,
    (SELECT count(*) FROM import_control_functions f WHERE f.scope = m.scope AND f.state = 'timer') as functions_timer,
    m.last_modified_at,
    m.last_modified_by
FROM import_control_master m;

-- Import Jobs Summary View
CREATE OR REPLACE VIEW v_import_jobs_summary AS
SELECT 
    j.candidate_id,
    COUNT(*) as total_imports,
    SUM(j.imported_count) as total_imported,
    SUM(j.duplicate_count) as total_duplicates,
    SUM(j.error_count) as total_errors,
    MAX(j.completed_at) as last_import_at,
    AVG(j.duration_seconds) as avg_duration_seconds
FROM import_jobs j
WHERE j.status = 'completed'
GROUP BY j.candidate_id;

-- Recent Audit View
CREATE OR REPLACE VIEW v_import_control_recent_audit AS
SELECT 
    a.*,
    CASE 
        WHEN a.performed_at > NOW() - INTERVAL '1 hour' THEN 'last_hour'
        WHEN a.performed_at > NOW() - INTERVAL '24 hours' THEN 'last_day'
        WHEN a.performed_at > NOW() - INTERVAL '7 days' THEN 'last_week'
        ELSE 'older'
    END as time_bucket
FROM import_control_audit a
ORDER BY a.performed_at DESC
LIMIT 1000;

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

-- Function to copy global controls to candidate scope
CREATE OR REPLACE FUNCTION initialize_candidate_import_controls(p_candidate_id UUID)
RETURNS void AS $$
BEGIN
    -- Copy master control
    INSERT INTO import_control_master (scope, state)
    SELECT p_candidate_id::text, state 
    FROM import_control_master 
    WHERE scope = 'global'
    ON CONFLICT (scope) DO NOTHING;
    
    -- Copy category controls
    INSERT INTO import_control_categories (scope, category, state)
    SELECT p_candidate_id::text, category, state 
    FROM import_control_categories 
    WHERE scope = 'global'
    ON CONFLICT (scope, category) DO NOTHING;
    
    -- Copy function toggles
    INSERT INTO import_control_functions 
    (scope, function_id, function_name, category, description, state, min_access_level)
    SELECT p_candidate_id::text, function_id, function_name, category, description, state, min_access_level
    FROM import_control_functions 
    WHERE scope = 'global'
    ON CONFLICT (scope, function_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Function to check if a function is active (checks hierarchy)
CREATE OR REPLACE FUNCTION is_import_function_active(
    p_scope VARCHAR,
    p_function_id VARCHAR
) RETURNS TABLE(is_active BOOLEAN, reason TEXT) AS $$
DECLARE
    v_master_active BOOLEAN;
    v_category VARCHAR;
    v_category_active BOOLEAN;
    v_function_active BOOLEAN;
BEGIN
    -- Check master
    SELECT CASE 
        WHEN m.emergency_shutdown THEN FALSE
        WHEN m.state = 'off' THEN FALSE
        WHEN m.state = 'on' THEN TRUE
        WHEN m.state = 'timer' AND m.timer_end > NOW() THEN TRUE
        ELSE FALSE
    END INTO v_master_active
    FROM import_control_master m
    WHERE m.scope = p_scope;
    
    IF NOT v_master_active THEN
        RETURN QUERY SELECT FALSE, 'Master switch is OFF'::TEXT;
        RETURN;
    END IF;
    
    -- Get function category
    SELECT f.category INTO v_category
    FROM import_control_functions f
    WHERE f.scope = p_scope AND f.function_id = p_function_id;
    
    IF v_category IS NULL THEN
        RETURN QUERY SELECT FALSE, ('Function ' || p_function_id || ' not found')::TEXT;
        RETURN;
    END IF;
    
    -- Check category
    SELECT CASE 
        WHEN c.state = 'off' THEN FALSE
        WHEN c.state = 'on' THEN TRUE
        WHEN c.state = 'timer' AND c.timer_end > NOW() THEN TRUE
        ELSE FALSE
    END INTO v_category_active
    FROM import_control_categories c
    WHERE c.scope = p_scope AND c.category = v_category;
    
    IF NOT v_category_active THEN
        RETURN QUERY SELECT FALSE, ('Category ' || v_category || ' is OFF')::TEXT;
        RETURN;
    END IF;
    
    -- Check function
    SELECT CASE 
        WHEN f.state = 'off' THEN FALSE
        WHEN f.state = 'on' THEN TRUE
        WHEN f.state = 'timer' AND f.timer_end > NOW() THEN TRUE
        ELSE FALSE
    END INTO v_function_active
    FROM import_control_functions f
    WHERE f.scope = p_scope AND f.function_id = p_function_id;
    
    IF NOT v_function_active THEN
        RETURN QUERY SELECT FALSE, ('Function ' || p_function_id || ' is OFF')::TEXT;
        RETURN;
    END IF;
    
    RETURN QUERY SELECT TRUE, 'Active'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE import_control_master IS 'Master switch for entire import system - top of control hierarchy';
COMMENT ON TABLE import_control_categories IS 'Category-level controls for groups of functions';
COMMENT ON TABLE import_control_functions IS 'Individual function toggles - bottom of control hierarchy';
COMMENT ON TABLE import_control_access IS 'User access permissions for control panel';
COMMENT ON TABLE import_control_audit IS 'Audit log for all control panel changes';
COMMENT ON TABLE import_jobs IS 'Tracks each file upload/import job';
COMMENT ON TABLE import_staging IS 'Temporary staging for records during import';
COMMENT ON TABLE import_column_mappings IS 'Learned column mappings from previous imports';

COMMENT ON FUNCTION initialize_candidate_import_controls IS 'Copies global control settings to a candidate scope';
COMMENT ON FUNCTION is_import_function_active IS 'Checks if a function is active by checking full hierarchy';

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
