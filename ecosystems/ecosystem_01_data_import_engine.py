#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 1 EXTENSION: DATA IMPORT ENGINE WITH CONTROL PANEL
============================================================================

Multi-tenant data upload system integrated into E01 Donor Intelligence:
- CSV, XLS, XLSX, PDF file parsing
- Auto-column mapping for WinRed/Anedot exports
- Contact normalization (name, phone, email, address)
- Deduplication with fuzzy matching
- Hierarchical Control Panel with master/category/function toggles

Control Panel Access Levels:
- BROYHILLGOP_ADMIN: Full access to all controls
- CAMPAIGN_MANAGER: Category and function controls for assigned candidates
- CANDIDATE: View-only + limited function toggles for their own data

Integrates with:
- E20 Intelligence Brain (master control)
- E01 Donor Intelligence (grading pipeline)
- E0 DataHub (storage)

Author: BroyhillGOP Platform
Created: January 2026
Version: 1.0.0 - Production Ready
============================================================================
"""

# Load environment
from dotenv import load_dotenv
load_dotenv("/opt/broyhillgop/config/supabase.env")
import os
import io
import re
import json
import uuid
import logging
import hashlib
import redis
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any, Union
from dataclasses import dataclass, field, asdict
from enum import Enum
from pathlib import Path

import psycopg2
from psycopg2.extras import RealDictCursor, execute_values

# Optional imports for file parsing
try:
    import pandas as pd
    HAS_PANDAS = True
except ImportError:
    HAS_PANDAS = False
    pd = None

try:
    import pdfplumber
    HAS_PDF = True
except ImportError:
    HAS_PDF = False
    pdfplumber = None

try:
    from fuzzywuzzy import fuzz
    HAS_FUZZY = True
except ImportError:
    HAS_FUZZY = False
    fuzz = None

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem1.data_import')


# ============================================================================
# CONFIGURATION
# ============================================================================

class ImportConfig:
    """Data Import Engine configuration"""
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
    REDIS_DB = int(os.getenv("REDIS_DB", "0"))
    
    # File limits
    MAX_FILE_SIZE_MB = 100
    MAX_ROWS_PER_IMPORT = 1_000_000
    BATCH_SIZE = 500
    
    # Fuzzy matching threshold (0-100)
    FUZZY_MATCH_THRESHOLD = 85
    
    # Timer defaults (minutes)
    DEFAULT_TIMER_DURATION = 60
    MAX_TIMER_DURATION = 1440  # 24 hours


# ============================================================================
# ENUMS AND DATA CLASSES
# ============================================================================

class ToggleState(Enum):
    """Control panel toggle states"""
    OFF = "off"
    ON = "on"
    TIMER = "timer"

class AccessLevel(Enum):
    """Access levels for control panel"""
    BROYHILLGOP_ADMIN = "broyhillgop_admin"      # Full platform admin
    CAMPAIGN_MANAGER = "campaign_manager"        # Manages multiple candidates
    CANDIDATE = "candidate"                       # Individual candidate

class FunctionCategory(Enum):
    """Categories of import functions"""
    FILE_PARSING = "file_parsing"
    NORMALIZATION = "normalization"
    DEDUPLICATION = "deduplication"
    ENRICHMENT = "enrichment"
    NOTIFICATIONS = "notifications"

@dataclass
class ControlToggle:
    """Individual function toggle"""
    function_id: str
    function_name: str
    category: FunctionCategory
    state: ToggleState = ToggleState.ON
    timer_end: Optional[datetime] = None
    timer_duration_minutes: int = 0
    description: str = ""
    min_access_level: AccessLevel = AccessLevel.CANDIDATE
    last_modified_by: str = ""
    last_modified_at: datetime = field(default_factory=datetime.now)
    
    def is_active(self) -> bool:
        """Check if function is currently active"""
        if self.state == ToggleState.OFF:
            return False
        if self.state == ToggleState.ON:
            return True
        if self.state == ToggleState.TIMER:
            if self.timer_end and datetime.now() < self.timer_end:
                return True
            return False
        return False

@dataclass
class CategoryControl:
    """Category-level control"""
    category: FunctionCategory
    state: ToggleState = ToggleState.ON
    timer_end: Optional[datetime] = None
    timer_duration_minutes: int = 0
    
    def is_active(self) -> bool:
        if self.state == ToggleState.OFF:
            return False
        if self.state == ToggleState.ON:
            return True
        if self.state == ToggleState.TIMER:
            if self.timer_end and datetime.now() < self.timer_end:
                return True
            return False
        return False

@dataclass
class MasterControl:
    """Master switch for entire import system"""
    state: ToggleState = ToggleState.ON
    timer_end: Optional[datetime] = None
    timer_duration_minutes: int = 0
    emergency_shutdown: bool = False
    shutdown_reason: str = ""
    
    def is_active(self) -> bool:
        if self.emergency_shutdown:
            return False
        if self.state == ToggleState.OFF:
            return False
        if self.state == ToggleState.ON:
            return True
        if self.state == ToggleState.TIMER:
            if self.timer_end and datetime.now() < self.timer_end:
                return True
            return False
        return False

@dataclass
class ImportRecord:
    """Single record to import"""
    email: Optional[str] = None
    phone: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    full_name: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip_code: Optional[str] = None
    donation_amount: Optional[float] = None
    donation_date: Optional[datetime] = None
    source: str = "upload"
    raw_data: Dict = field(default_factory=dict)

@dataclass
class ImportResult:
    """Result of import operation"""
    import_id: str
    candidate_id: str
    file_name: str
    total_rows: int
    imported: int
    duplicates: int
    errors: int
    skipped: int
    error_details: List[Dict] = field(default_factory=list)
    started_at: datetime = field(default_factory=datetime.now)
    completed_at: Optional[datetime] = None
    duration_seconds: float = 0


# ============================================================================
# DATABASE SCHEMA
# ============================================================================

DATA_IMPORT_SCHEMA = """
-- ============================================================================
-- E01 EXTENSION: DATA IMPORT ENGINE SCHEMA
-- ============================================================================

-- Import Control Panel - Master Switch
CREATE TABLE IF NOT EXISTS import_control_master (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL DEFAULT 'global',  -- 'global' or candidate_id
    state VARCHAR(20) NOT NULL DEFAULT 'on',
    timer_end TIMESTAMP,
    timer_duration_minutes INTEGER DEFAULT 0,
    emergency_shutdown BOOLEAN DEFAULT FALSE,
    shutdown_reason TEXT,
    last_modified_by UUID,
    last_modified_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(scope)
);

-- Import Control Panel - Category Controls
CREATE TABLE IF NOT EXISTS import_control_categories (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL DEFAULT 'global',
    category VARCHAR(50) NOT NULL,
    state VARCHAR(20) NOT NULL DEFAULT 'on',
    timer_end TIMESTAMP,
    timer_duration_minutes INTEGER DEFAULT 0,
    last_modified_by UUID,
    last_modified_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(scope, category)
);

-- Import Control Panel - Function Toggles
CREATE TABLE IF NOT EXISTS import_control_functions (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL DEFAULT 'global',
    function_id VARCHAR(100) NOT NULL,
    function_name VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    state VARCHAR(20) NOT NULL DEFAULT 'on',
    timer_end TIMESTAMP,
    timer_duration_minutes INTEGER DEFAULT 0,
    min_access_level VARCHAR(50) DEFAULT 'candidate',
    last_modified_by UUID,
    last_modified_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(scope, function_id)
);

-- Import Control Panel - Access Permissions
CREATE TABLE IF NOT EXISTS import_control_access (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    access_level VARCHAR(50) NOT NULL,
    candidate_ids UUID[],  -- NULL = all candidates (for admin)
    granted_by UUID,
    granted_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id)
);

-- Import Control Panel - Audit Log
CREATE TABLE IF NOT EXISTS import_control_audit (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,  -- 'master', 'category', 'function'
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

-- Import Jobs
CREATE TABLE IF NOT EXISTS import_jobs (
    import_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    uploaded_by UUID NOT NULL,
    file_name VARCHAR(500) NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    file_size_bytes BIGINT,
    status VARCHAR(50) DEFAULT 'pending',
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

-- Import Staging Table (temporary records before commit)
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

-- Column Mappings (learned from previous imports)
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

-- Pre-populated WinRed column mappings
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

-- Pre-populated Anedot column mappings
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

-- Initialize default master control
INSERT INTO import_control_master (scope, state) VALUES ('global', 'on')
ON CONFLICT (scope) DO NOTHING;

-- Initialize default category controls
INSERT INTO import_control_categories (scope, category, state) VALUES
    ('global', 'file_parsing', 'on'),
    ('global', 'normalization', 'on'),
    ('global', 'deduplication', 'on'),
    ('global', 'enrichment', 'on'),
    ('global', 'notifications', 'on')
ON CONFLICT (scope, category) DO NOTHING;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_import_jobs_candidate ON import_jobs(candidate_id);
CREATE INDEX IF NOT EXISTS idx_import_jobs_status ON import_jobs(status);
CREATE INDEX IF NOT EXISTS idx_import_staging_import ON import_staging(import_id);
CREATE INDEX IF NOT EXISTS idx_import_staging_email ON import_staging(email);
CREATE INDEX IF NOT EXISTS idx_import_control_audit_scope ON import_control_audit(scope, performed_at);

-- View: Control Panel Status
CREATE OR REPLACE VIEW v_import_control_status AS
SELECT 
    m.scope,
    m.state as master_state,
    m.emergency_shutdown,
    m.timer_end as master_timer_end,
    (
        SELECT jsonb_object_agg(category, jsonb_build_object(
            'state', state,
            'timer_end', timer_end
        ))
        FROM import_control_categories c
        WHERE c.scope = m.scope
    ) as categories,
    (
        SELECT count(*) 
        FROM import_control_functions f 
        WHERE f.scope = m.scope AND f.state = 'on'
    ) as functions_on,
    (
        SELECT count(*) 
        FROM import_control_functions f 
        WHERE f.scope = m.scope AND f.state = 'off'
    ) as functions_off,
    (
        SELECT count(*) 
        FROM import_control_functions f 
        WHERE f.scope = m.scope AND f.state = 'timer'
    ) as functions_timer,
    m.last_modified_at
FROM import_control_master m;
"""


# ============================================================================
# DEFAULT FUNCTION DEFINITIONS
# ============================================================================

DEFAULT_FUNCTIONS = [
    # FILE_PARSING category
    {
        "function_id": "parse_csv",
        "function_name": "CSV File Parsing",
        "category": "file_parsing",
        "description": "Parse CSV files and extract donor records",
        "min_access_level": "candidate"
    },
    {
        "function_id": "parse_xlsx",
        "function_name": "Excel File Parsing",
        "category": "file_parsing",
        "description": "Parse XLS/XLSX files and extract donor records",
        "min_access_level": "candidate"
    },
    {
        "function_id": "parse_pdf",
        "function_name": "PDF File Parsing",
        "category": "file_parsing",
        "description": "Parse PDF files with table extraction",
        "min_access_level": "candidate"
    },
    {
        "function_id": "auto_detect_columns",
        "function_name": "Auto-Detect Columns",
        "category": "file_parsing",
        "description": "Automatically map source columns to donor schema",
        "min_access_level": "candidate"
    },
    {
        "function_id": "winred_format",
        "function_name": "WinRed Format Support",
        "category": "file_parsing",
        "description": "Native support for WinRed export format",
        "min_access_level": "candidate"
    },
    {
        "function_id": "anedot_format",
        "function_name": "Anedot Format Support",
        "category": "file_parsing",
        "description": "Native support for Anedot export format",
        "min_access_level": "candidate"
    },
    
    # NORMALIZATION category
    {
        "function_id": "normalize_phone",
        "function_name": "Phone Number Normalization",
        "category": "normalization",
        "description": "Standardize phone numbers to 10-digit format",
        "min_access_level": "candidate"
    },
    {
        "function_id": "normalize_email",
        "function_name": "Email Normalization",
        "category": "normalization",
        "description": "Lowercase, trim, and validate email addresses",
        "min_access_level": "candidate"
    },
    {
        "function_id": "normalize_name",
        "function_name": "Name Normalization",
        "category": "normalization",
        "description": "Split full names, proper case, handle suffixes",
        "min_access_level": "candidate"
    },
    {
        "function_id": "normalize_address",
        "function_name": "Address Normalization",
        "category": "normalization",
        "description": "Standardize addresses (St/Street, Ave/Avenue)",
        "min_access_level": "candidate"
    },
    {
        "function_id": "normalize_state",
        "function_name": "State Normalization",
        "category": "normalization",
        "description": "Convert state names to 2-letter codes",
        "min_access_level": "candidate"
    },
    {
        "function_id": "normalize_zip",
        "function_name": "ZIP Code Normalization",
        "category": "normalization",
        "description": "Standardize ZIP codes (5 or 9 digit)",
        "min_access_level": "candidate"
    },
    
    # DEDUPLICATION category
    {
        "function_id": "dedupe_exact_email",
        "function_name": "Exact Email Match",
        "category": "deduplication",
        "description": "Find duplicates by exact email match",
        "min_access_level": "candidate"
    },
    {
        "function_id": "dedupe_exact_phone",
        "function_name": "Exact Phone Match",
        "category": "deduplication",
        "description": "Find duplicates by exact phone match",
        "min_access_level": "candidate"
    },
    {
        "function_id": "dedupe_fuzzy_name",
        "function_name": "Fuzzy Name Match",
        "category": "deduplication",
        "description": "Find duplicates by fuzzy name matching (85% threshold)",
        "min_access_level": "campaign_manager"
    },
    {
        "function_id": "dedupe_fuzzy_address",
        "function_name": "Fuzzy Address Match",
        "category": "deduplication",
        "description": "Find duplicates by fuzzy address matching",
        "min_access_level": "campaign_manager"
    },
    {
        "function_id": "dedupe_merge_records",
        "function_name": "Auto-Merge Duplicates",
        "category": "deduplication",
        "description": "Automatically merge confirmed duplicates",
        "min_access_level": "campaign_manager"
    },
    
    # ENRICHMENT category
    {
        "function_id": "enrich_calculate_grade",
        "function_name": "Calculate Donor Grade",
        "category": "enrichment",
        "description": "Calculate 3D donor grade after import",
        "min_access_level": "candidate"
    },
    {
        "function_id": "enrich_rfm_score",
        "function_name": "Calculate RFM Score",
        "category": "enrichment",
        "description": "Calculate RFM score after import",
        "min_access_level": "candidate"
    },
    {
        "function_id": "enrich_match_datatrust",
        "function_name": "Match Against DataTrust",
        "category": "enrichment",
        "description": "Match imported donors against RNC DataTrust",
        "min_access_level": "campaign_manager"
    },
    {
        "function_id": "enrich_append_voter",
        "function_name": "Append Voter Data",
        "category": "enrichment",
        "description": "Append NC voter file data to imported records",
        "min_access_level": "campaign_manager"
    },
    
    # NOTIFICATIONS category
    {
        "function_id": "notify_import_complete",
        "function_name": "Import Complete Notification",
        "category": "notifications",
        "description": "Send notification when import completes",
        "min_access_level": "candidate"
    },
    {
        "function_id": "notify_duplicates_found",
        "function_name": "Duplicates Found Alert",
        "category": "notifications",
        "description": "Alert when significant duplicates found",
        "min_access_level": "candidate"
    },
    {
        "function_id": "notify_errors",
        "function_name": "Import Error Alerts",
        "category": "notifications",
        "description": "Alert on import errors",
        "min_access_level": "candidate"
    },
    {
        "function_id": "notify_e20_brain",
        "function_name": "Notify E20 Brain",
        "category": "notifications",
        "description": "Send events to E20 Intelligence Brain",
        "min_access_level": "broyhillgop_admin"
    }
]


# ============================================================================
# CONTROL PANEL ENGINE
# ============================================================================

class ImportControlPanel:
    """
    Hierarchical Control Panel for Data Import Engine
    
    Hierarchy:
    1. Master Switch (ON/OFF/TIMER) - Controls entire system
    2. Category Controls (ON/OFF/TIMER) - Controls groups of functions
    3. Function Toggles (ON/OFF/TIMER) - Controls individual functions
    
    Access Levels:
    - BROYHILLGOP_ADMIN: Full access
    - CAMPAIGN_MANAGER: Category + function controls for assigned candidates
    - CANDIDATE: Limited function toggles for own data
    """
    
    def __init__(self, scope: str = "global"):
        """
        Initialize control panel
        
        Args:
            scope: 'global' for platform-wide, or candidate_id for candidate-specific
        """
        self.scope = scope
        self.redis = None
        try:
            self.redis = redis.Redis(
                host=ImportConfig.REDIS_HOST,
                port=ImportConfig.REDIS_PORT,
                db=ImportConfig.REDIS_DB,
                decode_responses=True
            )
            self.redis.ping()
        except:
            logger.warning("Redis not available, using database-only mode")
            self.redis = None
    
    def _get_db(self):
        """Get database connection"""
        return psycopg2.connect(ImportConfig.DATABASE_URL)
    
    def _cache_key(self, key_type: str) -> str:
        """Generate Redis cache key"""
        return f"import_control:{self.scope}:{key_type}"
    
    # ========================================================================
    # MASTER SWITCH
    # ========================================================================
    
    def get_master_state(self) -> MasterControl:
        """Get current master switch state"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT state, timer_end, timer_duration_minutes, 
                   emergency_shutdown, shutdown_reason
            FROM import_control_master
            WHERE scope = %s
        """, (self.scope,))
        
        row = cur.fetchone()
        conn.close()
        
        if row:
            return MasterControl(
                state=ToggleState(row['state']),
                timer_end=row['timer_end'],
                timer_duration_minutes=row['timer_duration_minutes'] or 0,
                emergency_shutdown=row['emergency_shutdown'] or False,
                shutdown_reason=row['shutdown_reason'] or ""
            )
        
        return MasterControl()
    
    def set_master_state(
        self,
        state: ToggleState,
        user_id: str,
        timer_minutes: int = 0,
        reason: str = ""
    ) -> bool:
        """
        Set master switch state
        
        Args:
            state: ON, OFF, or TIMER
            user_id: Who is making the change
            timer_minutes: Duration if TIMER state
            reason: Optional reason for change
        """
        conn = self._get_db()
        cur = conn.cursor()
        
        # Get old state for audit
        cur.execute("SELECT state, timer_end FROM import_control_master WHERE scope = %s", (self.scope,))
        old = cur.fetchone()
        old_state = old[0] if old else None
        old_timer = old[1] if old else None
        
        timer_end = None
        if state == ToggleState.TIMER and timer_minutes > 0:
            timer_end = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO import_control_master (scope, state, timer_end, timer_duration_minutes, last_modified_by)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (scope) DO UPDATE SET
                state = EXCLUDED.state,
                timer_end = EXCLUDED.timer_end,
                timer_duration_minutes = EXCLUDED.timer_duration_minutes,
                last_modified_by = EXCLUDED.last_modified_by,
                last_modified_at = NOW()
        """, (self.scope, state.value, timer_end, timer_minutes, user_id))
        
        # Audit log
        cur.execute("""
            INSERT INTO import_control_audit 
            (scope, action, target_type, old_state, new_state, old_timer_end, new_timer_end, performed_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (self.scope, 'set_master', 'master', old_state, state.value, old_timer, timer_end, user_id))
        
        conn.commit()
        conn.close()
        
        # Invalidate cache
        if self.redis:
            self.redis.delete(self._cache_key('master'))
        
        # Publish event to E20 Brain
        self._publish_control_event('master_changed', {
            'scope': self.scope,
            'state': state.value,
            'timer_end': timer_end.isoformat() if timer_end else None,
            'changed_by': user_id
        })
        
        logger.info(f"Master switch set to {state.value} for scope {self.scope}")
        return True
    
    def emergency_shutdown(self, user_id: str, reason: str) -> bool:
        """Emergency shutdown - immediately stops all import operations"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE import_control_master
            SET emergency_shutdown = TRUE,
                shutdown_reason = %s,
                state = 'off',
                last_modified_by = %s,
                last_modified_at = NOW()
            WHERE scope = %s
        """, (reason, user_id, self.scope))
        
        # Audit log
        cur.execute("""
            INSERT INTO import_control_audit 
            (scope, action, target_type, new_state, performed_by)
            VALUES (%s, %s, %s, %s, %s)
        """, (self.scope, 'emergency_shutdown', 'master', 'off', user_id))
        
        conn.commit()
        conn.close()
        
        # Publish alert
        self._publish_control_event('emergency_shutdown', {
            'scope': self.scope,
            'reason': reason,
            'triggered_by': user_id
        })
        
        logger.warning(f"🚨 EMERGENCY SHUTDOWN triggered for scope {self.scope}: {reason}")
        return True
    
    def clear_emergency_shutdown(self, user_id: str) -> bool:
        """Clear emergency shutdown"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE import_control_master
            SET emergency_shutdown = FALSE,
                shutdown_reason = NULL,
                state = 'on',
                last_modified_by = %s,
                last_modified_at = NOW()
            WHERE scope = %s
        """, (user_id, self.scope))
        
        # Audit log
        cur.execute("""
            INSERT INTO import_control_audit 
            (scope, action, target_type, new_state, performed_by)
            VALUES (%s, %s, %s, %s, %s)
        """, (self.scope, 'clear_emergency_shutdown', 'master', 'on', user_id))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Emergency shutdown cleared for scope {self.scope}")
        return True
    
    # ========================================================================
    # CATEGORY CONTROLS
    # ========================================================================
    
    def get_category_state(self, category: FunctionCategory) -> CategoryControl:
        """Get state for a function category"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT state, timer_end, timer_duration_minutes
            FROM import_control_categories
            WHERE scope = %s AND category = %s
        """, (self.scope, category.value))
        
        row = cur.fetchone()
        conn.close()
        
        if row:
            return CategoryControl(
                category=category,
                state=ToggleState(row['state']),
                timer_end=row['timer_end'],
                timer_duration_minutes=row['timer_duration_minutes'] or 0
            )
        
        return CategoryControl(category=category)
    
    def set_category_state(
        self,
        category: FunctionCategory,
        state: ToggleState,
        user_id: str,
        timer_minutes: int = 0
    ) -> bool:
        """Set state for a function category"""
        conn = self._get_db()
        cur = conn.cursor()
        
        # Get old state
        cur.execute("""
            SELECT state, timer_end FROM import_control_categories 
            WHERE scope = %s AND category = %s
        """, (self.scope, category.value))
        old = cur.fetchone()
        
        timer_end = None
        if state == ToggleState.TIMER and timer_minutes > 0:
            timer_end = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO import_control_categories (scope, category, state, timer_end, timer_duration_minutes, last_modified_by)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (scope, category) DO UPDATE SET
                state = EXCLUDED.state,
                timer_end = EXCLUDED.timer_end,
                timer_duration_minutes = EXCLUDED.timer_duration_minutes,
                last_modified_by = EXCLUDED.last_modified_by,
                last_modified_at = NOW()
        """, (self.scope, category.value, state.value, timer_end, timer_minutes, user_id))
        
        # Audit log
        cur.execute("""
            INSERT INTO import_control_audit 
            (scope, action, target_type, target_id, old_state, new_state, old_timer_end, new_timer_end, performed_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (self.scope, 'set_category', 'category', category.value, 
              old[0] if old else None, state.value, 
              old[1] if old else None, timer_end, user_id))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Category {category.value} set to {state.value} for scope {self.scope}")
        return True
    
    def get_all_categories(self) -> Dict[str, CategoryControl]:
        """Get all category states"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT category, state, timer_end, timer_duration_minutes
            FROM import_control_categories
            WHERE scope = %s
        """, (self.scope,))
        
        results = {}
        for row in cur.fetchall():
            cat = FunctionCategory(row['category'])
            results[row['category']] = CategoryControl(
                category=cat,
                state=ToggleState(row['state']),
                timer_end=row['timer_end'],
                timer_duration_minutes=row['timer_duration_minutes'] or 0
            )
        
        conn.close()
        return results
    
    # ========================================================================
    # FUNCTION TOGGLES
    # ========================================================================
    
    def get_function_state(self, function_id: str) -> Optional[ControlToggle]:
        """Get state for a specific function"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT function_id, function_name, category, description,
                   state, timer_end, timer_duration_minutes, min_access_level,
                   last_modified_by, last_modified_at
            FROM import_control_functions
            WHERE scope = %s AND function_id = %s
        """, (self.scope, function_id))
        
        row = cur.fetchone()
        conn.close()
        
        if row:
            return ControlToggle(
                function_id=row['function_id'],
                function_name=row['function_name'],
                category=FunctionCategory(row['category']),
                state=ToggleState(row['state']),
                timer_end=row['timer_end'],
                timer_duration_minutes=row['timer_duration_minutes'] or 0,
                description=row['description'] or "",
                min_access_level=AccessLevel(row['min_access_level']),
                last_modified_by=row['last_modified_by'] or "",
                last_modified_at=row['last_modified_at']
            )
        
        return None
    
    def set_function_state(
        self,
        function_id: str,
        state: ToggleState,
        user_id: str,
        timer_minutes: int = 0
    ) -> bool:
        """Set state for a specific function"""
        conn = self._get_db()
        cur = conn.cursor()
        
        # Get old state
        cur.execute("""
            SELECT state, timer_end FROM import_control_functions 
            WHERE scope = %s AND function_id = %s
        """, (self.scope, function_id))
        old = cur.fetchone()
        
        if not old:
            conn.close()
            raise ValueError(f"Function {function_id} not found")
        
        timer_end = None
        if state == ToggleState.TIMER and timer_minutes > 0:
            timer_end = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            UPDATE import_control_functions
            SET state = %s,
                timer_end = %s,
                timer_duration_minutes = %s,
                last_modified_by = %s,
                last_modified_at = NOW()
            WHERE scope = %s AND function_id = %s
        """, (state.value, timer_end, timer_minutes, user_id, self.scope, function_id))
        
        # Audit log
        cur.execute("""
            INSERT INTO import_control_audit 
            (scope, action, target_type, target_id, old_state, new_state, old_timer_end, new_timer_end, performed_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (self.scope, 'set_function', 'function', function_id, 
              old[0], state.value, old[1], timer_end, user_id))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Function {function_id} set to {state.value} for scope {self.scope}")
        return True
    
    def get_all_functions(self, category: Optional[FunctionCategory] = None) -> List[ControlToggle]:
        """Get all function states, optionally filtered by category"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        if category:
            cur.execute("""
                SELECT function_id, function_name, category, description,
                       state, timer_end, timer_duration_minutes, min_access_level,
                       last_modified_by, last_modified_at
                FROM import_control_functions
                WHERE scope = %s AND category = %s
                ORDER BY function_name
            """, (self.scope, category.value))
        else:
            cur.execute("""
                SELECT function_id, function_name, category, description,
                       state, timer_end, timer_duration_minutes, min_access_level,
                       last_modified_by, last_modified_at
                FROM import_control_functions
                WHERE scope = %s
                ORDER BY category, function_name
            """, (self.scope,))
        
        results = []
        for row in cur.fetchall():
            results.append(ControlToggle(
                function_id=row['function_id'],
                function_name=row['function_name'],
                category=FunctionCategory(row['category']),
                state=ToggleState(row['state']),
                timer_end=row['timer_end'],
                timer_duration_minutes=row['timer_duration_minutes'] or 0,
                description=row['description'] or "",
                min_access_level=AccessLevel(row['min_access_level']),
                last_modified_by=row['last_modified_by'] or "",
                last_modified_at=row['last_modified_at']
            ))
        
        conn.close()
        return results
    
    # ========================================================================
    # COMBINED CHECK - Is Function Active?
    # ========================================================================
    
    def is_function_active(self, function_id: str) -> Tuple[bool, str]:
        """
        Check if a function is currently active
        
        Checks hierarchy:
        1. Master switch
        2. Category control
        3. Function toggle
        
        Returns:
            Tuple of (is_active, reason)
        """
        # Check master
        master = self.get_master_state()
        if not master.is_active():
            if master.emergency_shutdown:
                return False, f"Emergency shutdown: {master.shutdown_reason}"
            return False, "Master switch is OFF"
        
        # Get function to find its category
        func = self.get_function_state(function_id)
        if not func:
            return False, f"Function {function_id} not found"
        
        # Check category
        category = self.get_category_state(func.category)
        if not category.is_active():
            return False, f"Category {func.category.value} is OFF"
        
        # Check function
        if not func.is_active():
            return False, f"Function {function_id} is OFF"
        
        return True, "Active"
    
    # ========================================================================
    # BULK OPERATIONS
    # ========================================================================
    
    def set_all_category_functions(
        self,
        category: FunctionCategory,
        state: ToggleState,
        user_id: str,
        timer_minutes: int = 0
    ) -> int:
        """Set all functions in a category to the same state"""
        functions = self.get_all_functions(category)
        count = 0
        
        for func in functions:
            self.set_function_state(func.function_id, state, user_id, timer_minutes)
            count += 1
        
        return count
    
    def get_full_status(self) -> Dict:
        """Get complete control panel status"""
        master = self.get_master_state()
        categories = self.get_all_categories()
        functions = self.get_all_functions()
        
        # Group functions by category
        funcs_by_cat = {}
        for func in functions:
            cat = func.category.value
            if cat not in funcs_by_cat:
                funcs_by_cat[cat] = []
            funcs_by_cat[cat].append({
                'id': func.function_id,
                'name': func.function_name,
                'state': func.state.value,
                'timer_end': func.timer_end.isoformat() if func.timer_end else None,
                'is_active': func.is_active(),
                'description': func.description
            })
        
        return {
            'scope': self.scope,
            'master': {
                'state': master.state.value,
                'timer_end': master.timer_end.isoformat() if master.timer_end else None,
                'emergency_shutdown': master.emergency_shutdown,
                'shutdown_reason': master.shutdown_reason,
                'is_active': master.is_active()
            },
            'categories': {
                cat: {
                    'state': ctrl.state.value,
                    'timer_end': ctrl.timer_end.isoformat() if ctrl.timer_end else None,
                    'is_active': ctrl.is_active(),
                    'functions': funcs_by_cat.get(cat, [])
                }
                for cat, ctrl in categories.items()
            },
            'summary': {
                'total_functions': len(functions),
                'functions_on': sum(1 for f in functions if f.state == ToggleState.ON),
                'functions_off': sum(1 for f in functions if f.state == ToggleState.OFF),
                'functions_timer': sum(1 for f in functions if f.state == ToggleState.TIMER)
            }
        }
    
    # ========================================================================
    # ACCESS CONTROL
    # ========================================================================
    
    def check_access(self, user_id: str, required_level: AccessLevel) -> bool:
        """Check if user has required access level"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT access_level, candidate_ids, expires_at, is_active
            FROM import_control_access
            WHERE user_id = %s AND is_active = TRUE
        """, (user_id,))
        
        row = cur.fetchone()
        conn.close()
        
        if not row:
            return False
        
        # Check expiration
        if row['expires_at'] and row['expires_at'] < datetime.now():
            return False
        
        user_level = AccessLevel(row['access_level'])
        
        # Admin has all access
        if user_level == AccessLevel.BROYHILLGOP_ADMIN:
            return True
        
        # Check hierarchy
        level_hierarchy = {
            AccessLevel.BROYHILLGOP_ADMIN: 3,
            AccessLevel.CAMPAIGN_MANAGER: 2,
            AccessLevel.CANDIDATE: 1
        }
        
        return level_hierarchy.get(user_level, 0) >= level_hierarchy.get(required_level, 0)
    
    def can_modify_function(self, user_id: str, function_id: str) -> Tuple[bool, str]:
        """Check if user can modify a specific function"""
        func = self.get_function_state(function_id)
        if not func:
            return False, f"Function {function_id} not found"
        
        if self.check_access(user_id, func.min_access_level):
            return True, "Access granted"
        
        return False, f"Requires {func.min_access_level.value} access"
    
    # ========================================================================
    # E20 BRAIN INTEGRATION
    # ========================================================================
    
    def _publish_control_event(self, event_type: str, data: Dict):
        """Publish control panel event to E20 Brain"""
        if not self.redis:
            return
        
        event = {
            'event_type': f'import_control.{event_type}',
            'ecosystem': 1,
            'timestamp': datetime.now().isoformat(),
            **data
        }
        
        try:
            self.redis.publish('broyhillgop.events', json.dumps(event))
        except Exception as e:
            logger.error(f"Failed to publish event: {e}")
    
    def receive_brain_command(self, command: Dict) -> bool:
        """
        Receive and execute command from E20 Brain
        
        E20 Brain can send commands like:
        - emergency_shutdown
        - set_master_state
        - set_category_state
        - set_function_state
        """
        cmd_type = command.get('command')
        
        if cmd_type == 'emergency_shutdown':
            return self.emergency_shutdown(
                command.get('user_id', 'e20_brain'),
                command.get('reason', 'E20 Brain triggered shutdown')
            )
        
        elif cmd_type == 'set_master':
            return self.set_master_state(
                ToggleState(command.get('state', 'off')),
                command.get('user_id', 'e20_brain'),
                command.get('timer_minutes', 0)
            )
        
        elif cmd_type == 'set_category':
            return self.set_category_state(
                FunctionCategory(command.get('category')),
                ToggleState(command.get('state', 'off')),
                command.get('user_id', 'e20_brain'),
                command.get('timer_minutes', 0)
            )
        
        elif cmd_type == 'set_function':
            return self.set_function_state(
                command.get('function_id'),
                ToggleState(command.get('state', 'off')),
                command.get('user_id', 'e20_brain'),
                command.get('timer_minutes', 0)
            )
        
        return False


# ============================================================================
# DATA IMPORT ENGINE
# ============================================================================

class DataImportEngine:
    """
    Multi-tenant data upload system for BroyhillGOP
    
    Handles:
    - CSV, XLS, XLSX, PDF file parsing
    - Auto-column mapping (WinRed, Anedot, custom)
    - Contact normalization
    - Deduplication (exact + fuzzy)
    - Integration with E01 Donor Intelligence for grading
    """
    
    def __init__(self, candidate_id: str):
        """
        Initialize import engine for a specific candidate
        
        Args:
            candidate_id: UUID of the candidate whose data is being imported
        """
        self.candidate_id = candidate_id
        self.control_panel = ImportControlPanel(scope=candidate_id)
        self.global_control = ImportControlPanel(scope="global")
        
        # Track current import job
        self.current_import_id: Optional[str] = None
        self.redis = None
        try:
            self.redis = redis.Redis(
                host=ImportConfig.REDIS_HOST,
                port=ImportConfig.REDIS_PORT,
                db=ImportConfig.REDIS_DB,
                decode_responses=True
            )
        except:
            pass
    
    def _get_db(self):
        """Get database connection"""
        return psycopg2.connect(ImportConfig.DATABASE_URL)
    
    def _check_function(self, function_id: str) -> Tuple[bool, str]:
        """Check if function is active at both global and candidate level"""
        # Check global first
        active, reason = self.global_control.is_function_active(function_id)
        if not active:
            return False, f"Global: {reason}"
        
        # Check candidate-specific
        active, reason = self.control_panel.is_function_active(function_id)
        if not active:
            return False, f"Candidate: {reason}"
        
        return True, "Active"
    
    # ========================================================================
    # FILE PARSING
    # ========================================================================
    
    def parse_file(
        self,
        file_content: Union[bytes, io.BytesIO],
        file_name: str,
        file_type: str = None
    ) -> Tuple[List[Dict], Dict]:
        """
        Parse uploaded file and extract records
        
        Args:
            file_content: File bytes or BytesIO
            file_name: Original filename
            file_type: Optional explicit file type ('csv', 'xlsx', 'pdf')
        
        Returns:
            Tuple of (records_list, metadata_dict)
        """
        if not file_type:
            file_type = self._detect_file_type(file_name)
        
        if file_type == 'csv':
            active, reason = self._check_function('parse_csv')
            if not active:
                raise RuntimeError(f"CSV parsing disabled: {reason}")
            return self._parse_csv(file_content)
        
        elif file_type in ('xls', 'xlsx'):
            active, reason = self._check_function('parse_xlsx')
            if not active:
                raise RuntimeError(f"Excel parsing disabled: {reason}")
            return self._parse_excel(file_content)
        
        elif file_type == 'pdf':
            active, reason = self._check_function('parse_pdf')
            if not active:
                raise RuntimeError(f"PDF parsing disabled: {reason}")
            return self._parse_pdf(file_content)
        
        else:
            raise ValueError(f"Unsupported file type: {file_type}")
    
    def _detect_file_type(self, file_name: str) -> str:
        """Detect file type from extension"""
        ext = Path(file_name).suffix.lower().lstrip('.')
        if ext in ('csv', 'txt'):
            return 'csv'
        elif ext in ('xls', 'xlsx', 'xlsm'):
            return 'xlsx'
        elif ext == 'pdf':
            return 'pdf'
        return ext
    
    def _parse_csv(self, content: Union[bytes, io.BytesIO]) -> Tuple[List[Dict], Dict]:
        """Parse CSV file"""
        if not HAS_PANDAS:
            raise RuntimeError("pandas required for CSV parsing")
        
        if isinstance(content, bytes):
            content = io.BytesIO(content)
        
        # Try different encodings
        for encoding in ['utf-8', 'latin-1', 'cp1252']:
            try:
                content.seek(0)
                df = pd.read_csv(content, encoding=encoding, dtype=str)
                break
            except:
                continue
        else:
            raise ValueError("Could not decode CSV file")
        
        # Clean column names
        df.columns = [c.strip().lower().replace(' ', '_') for c in df.columns]
        
        records = df.to_dict('records')
        metadata = {
            'file_type': 'csv',
            'row_count': len(records),
            'columns': list(df.columns),
            'encoding': encoding
        }
        
        return records, metadata
    
    def _parse_excel(self, content: Union[bytes, io.BytesIO]) -> Tuple[List[Dict], Dict]:
        """Parse Excel file"""
        if not HAS_PANDAS:
            raise RuntimeError("pandas required for Excel parsing")
        
        if isinstance(content, bytes):
            content = io.BytesIO(content)
        
        df = pd.read_excel(content, dtype=str)
        
        # Clean column names
        df.columns = [str(c).strip().lower().replace(' ', '_') for c in df.columns]
        
        records = df.to_dict('records')
        metadata = {
            'file_type': 'xlsx',
            'row_count': len(records),
            'columns': list(df.columns)
        }
        
        return records, metadata
    
    def _parse_pdf(self, content: Union[bytes, io.BytesIO]) -> Tuple[List[Dict], Dict]:
        """Parse PDF file with table extraction"""
        if not HAS_PDF:
            raise RuntimeError("pdfplumber required for PDF parsing")
        
        if isinstance(content, bytes):
            content = io.BytesIO(content)
        
        records = []
        all_columns = set()
        
        with pdfplumber.open(content) as pdf:
            for page in pdf.pages:
                tables = page.extract_tables()
                for table in tables:
                    if not table or len(table) < 2:
                        continue
                    
                    # First row is header
                    headers = [str(h).strip().lower().replace(' ', '_') if h else f'col_{i}' 
                               for i, h in enumerate(table[0])]
                    all_columns.update(headers)
                    
                    # Remaining rows are data
                    for row in table[1:]:
                        if any(cell for cell in row):  # Skip empty rows
                            record = {headers[i]: str(cell).strip() if cell else '' 
                                      for i, cell in enumerate(row) if i < len(headers)}
                            records.append(record)
        
        metadata = {
            'file_type': 'pdf',
            'row_count': len(records),
            'columns': list(all_columns)
        }
        
        return records, metadata
    
    # ========================================================================
    # COLUMN MAPPING
    # ========================================================================
    
    def auto_map_columns(self, columns: List[str]) -> Dict[str, str]:
        """
        Automatically map source columns to target schema
        
        Returns:
            Dict mapping source_column -> target_column
        """
        active, reason = self._check_function('auto_detect_columns')
        if not active:
            return {}
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        mapping = {}
        
        for col in columns:
            col_lower = col.lower().strip()
            
            # Check known mappings
            cur.execute("""
                SELECT target_column, confidence
                FROM import_column_mappings
                WHERE LOWER(source_column) = %s
                ORDER BY confidence DESC, usage_count DESC
                LIMIT 1
            """, (col_lower,))
            
            row = cur.fetchone()
            if row:
                mapping[col] = row['target_column']
                continue
            
            # Fuzzy match against common patterns
            mapping[col] = self._fuzzy_map_column(col_lower)
        
        conn.close()
        return mapping
    
    def _fuzzy_map_column(self, col: str) -> Optional[str]:
        """Fuzzy match column name to target schema"""
        patterns = {
            'email': ['email', 'e-mail', 'mail', 'contributor_email', 'email_address'],
            'phone': ['phone', 'tel', 'mobile', 'cell', 'contributor_phone', 'phone_number'],
            'first_name': ['first', 'firstname', 'first_name', 'fname', 'contributor_first'],
            'last_name': ['last', 'lastname', 'last_name', 'lname', 'surname', 'contributor_last'],
            'full_name': ['name', 'fullname', 'full_name', 'contributor_name'],
            'address': ['address', 'street', 'addr', 'address_line', 'contributor_address'],
            'city': ['city', 'town', 'municipality'],
            'state': ['state', 'province', 'region', 'contributor_state'],
            'zip_code': ['zip', 'zipcode', 'zip_code', 'postal', 'postal_code', 'contributor_zip'],
            'donation_amount': ['amount', 'donation', 'contribution', 'total', 'gift'],
            'donation_date': ['date', 'created', 'transaction_date', 'donation_date']
        }
        
        for target, keywords in patterns.items():
            for keyword in keywords:
                if keyword in col or col in keyword:
                    return target
        
        return None
    
    def detect_source_format(self, columns: List[str]) -> str:
        """Detect if file is WinRed, Anedot, or custom format"""
        col_set = set(c.lower() for c in columns)
        
        # WinRed indicators
        winred_cols = {'contributor_email', 'contributor_first_name', 'contributor_last_name'}
        if winred_cols.issubset(col_set):
            active, _ = self._check_function('winred_format')
            if active:
                return 'winred'
        
        # Anedot indicators
        anedot_cols = {'email_address', 'first', 'last'}
        anedot_cols2 = {'email', 'first_name', 'last_name'}
        if anedot_cols.issubset(col_set) or anedot_cols2.issubset(col_set):
            active, _ = self._check_function('anedot_format')
            if active:
                return 'anedot'
        
        return 'custom'
    
    # ========================================================================
    # NORMALIZATION
    # ========================================================================
    
    def normalize_record(self, record: Dict, mapping: Dict[str, str]) -> ImportRecord:
        """
        Normalize a single record
        
        Applies:
        - Column mapping
        - Phone normalization
        - Email normalization
        - Name normalization
        - Address normalization
        """
        result = ImportRecord(raw_data=record.copy())
        
        # Apply column mapping
        mapped = {}
        for src_col, value in record.items():
            target = mapping.get(src_col)
            if target:
                mapped[target] = value
            else:
                mapped[src_col] = value
        
        # Extract basic fields
        result.email = mapped.get('email', '')
        result.phone = mapped.get('phone', '')
        result.first_name = mapped.get('first_name', '')
        result.last_name = mapped.get('last_name', '')
        result.full_name = mapped.get('full_name', '')
        result.address = mapped.get('address', '')
        result.city = mapped.get('city', '')
        result.state = mapped.get('state', '')
        result.zip_code = mapped.get('zip_code', '')
        
        # Parse donation amount
        amt_str = mapped.get('donation_amount', '')
        if amt_str:
            try:
                # Remove currency symbols and commas
                amt_clean = re.sub(r'[^\d.]', '', str(amt_str))
                result.donation_amount = float(amt_clean) if amt_clean else None
            except:
                result.donation_amount = None
        
        # Parse donation date
        date_str = mapped.get('donation_date', '')
        if date_str:
            result.donation_date = self._parse_date(date_str)
        
        # Apply normalizations
        active, _ = self._check_function('normalize_email')
        if active and result.email:
            result.email = self._normalize_email(result.email)
        
        active, _ = self._check_function('normalize_phone')
        if active and result.phone:
            result.phone = self._normalize_phone(result.phone)
        
        active, _ = self._check_function('normalize_name')
        if active:
            result.first_name, result.last_name = self._normalize_name(
                result.first_name, result.last_name, result.full_name
            )
        
        active, _ = self._check_function('normalize_address')
        if active and result.address:
            result.address = self._normalize_address(result.address)
        
        active, _ = self._check_function('normalize_state')
        if active and result.state:
            result.state = self._normalize_state(result.state)
        
        active, _ = self._check_function('normalize_zip')
        if active and result.zip_code:
            result.zip_code = self._normalize_zip(result.zip_code)
        
        return result
    
    def _normalize_email(self, email: str) -> str:
        """Normalize email: lowercase, trim, validate"""
        if not email:
            return ''
        
        email = str(email).strip().lower()
        
        # Basic validation
        if '@' not in email or '.' not in email:
            return ''
        
        return email
    
    def _normalize_phone(self, phone: str) -> str:
        """Normalize phone: extract 10 digits"""
        if not phone:
            return ''
        
        # Remove all non-digits
        digits = re.sub(r'\D', '', str(phone))
        
        # Handle country code
        if len(digits) == 11 and digits.startswith('1'):
            digits = digits[1:]
        
        # Must be 10 digits
        if len(digits) != 10:
            return ''
        
        return digits
    
    def _normalize_name(
        self, 
        first: str, 
        last: str, 
        full: str
    ) -> Tuple[str, str]:
        """Normalize names: proper case, split full name"""
        # If we have both first and last, just clean them
        if first and last:
            return self._proper_case(first), self._proper_case(last)
        
        # Try to split full name
        if full:
            full = str(full).strip()
            parts = full.split()
            
            if len(parts) >= 2:
                # Handle suffixes
                suffixes = ['jr', 'jr.', 'sr', 'sr.', 'ii', 'iii', 'iv']
                last_part = parts[-1].lower().rstrip('.')
                
                if last_part in suffixes and len(parts) >= 3:
                    first = ' '.join(parts[:-2])
                    last = parts[-2]
                else:
                    first = parts[0]
                    last = ' '.join(parts[1:])
            else:
                first = full
                last = ''
        
        return self._proper_case(first or ''), self._proper_case(last or '')
    
    def _proper_case(self, name: str) -> str:
        """Convert name to proper case"""
        if not name:
            return ''
        
        name = str(name).strip()
        
        # Handle all caps or all lower
        if name.isupper() or name.islower():
            # Special handling for Mc/Mac names
            if name.lower().startswith('mc'):
                return 'Mc' + name[2:].title()
            elif name.lower().startswith('mac') and len(name) > 3:
                return 'Mac' + name[3:].title()
            return name.title()
        
        return name
    
    def _normalize_address(self, address: str) -> str:
        """Normalize address: standardize abbreviations"""
        if not address:
            return ''
        
        address = str(address).strip()
        
        # Common replacements
        replacements = {
            r'\bstreet\b': 'St',
            r'\bst\b': 'St',
            r'\bavenue\b': 'Ave',
            r'\bave\b': 'Ave',
            r'\broad\b': 'Rd',
            r'\brd\b': 'Rd',
            r'\bdrive\b': 'Dr',
            r'\bdr\b': 'Dr',
            r'\blane\b': 'Ln',
            r'\bln\b': 'Ln',
            r'\bcourt\b': 'Ct',
            r'\bct\b': 'Ct',
            r'\bcircle\b': 'Cir',
            r'\bcir\b': 'Cir',
            r'\bboulevard\b': 'Blvd',
            r'\bblvd\b': 'Blvd',
            r'\bapartment\b': 'Apt',
            r'\bapt\b': 'Apt',
            r'\bsuite\b': 'Ste',
            r'\bste\b': 'Ste',
            r'\bnorth\b': 'N',
            r'\bsouth\b': 'S',
            r'\beast\b': 'E',
            r'\bwest\b': 'W',
        }
        
        result = address.lower()
        for pattern, replacement in replacements.items():
            result = re.sub(pattern, replacement, result, flags=re.IGNORECASE)
        
        # Title case but preserve abbreviations
        words = result.split()
        result = ' '.join(w.upper() if len(w) <= 2 else w.title() for w in words)
        
        return result
    
    def _normalize_state(self, state: str) -> str:
        """Normalize state: convert to 2-letter code"""
        if not state:
            return ''
        
        state = str(state).strip().upper()
        
        # Already 2 letters
        if len(state) == 2:
            return state
        
        # State name mapping
        state_map = {
            'ALABAMA': 'AL', 'ALASKA': 'AK', 'ARIZONA': 'AZ', 'ARKANSAS': 'AR',
            'CALIFORNIA': 'CA', 'COLORADO': 'CO', 'CONNECTICUT': 'CT', 'DELAWARE': 'DE',
            'FLORIDA': 'FL', 'GEORGIA': 'GA', 'HAWAII': 'HI', 'IDAHO': 'ID',
            'ILLINOIS': 'IL', 'INDIANA': 'IN', 'IOWA': 'IA', 'KANSAS': 'KS',
            'KENTUCKY': 'KY', 'LOUISIANA': 'LA', 'MAINE': 'ME', 'MARYLAND': 'MD',
            'MASSACHUSETTS': 'MA', 'MICHIGAN': 'MI', 'MINNESOTA': 'MN', 'MISSISSIPPI': 'MS',
            'MISSOURI': 'MO', 'MONTANA': 'MT', 'NEBRASKA': 'NE', 'NEVADA': 'NV',
            'NEW HAMPSHIRE': 'NH', 'NEW JERSEY': 'NJ', 'NEW MEXICO': 'NM', 'NEW YORK': 'NY',
            'NORTH CAROLINA': 'NC', 'NORTH DAKOTA': 'ND', 'OHIO': 'OH', 'OKLAHOMA': 'OK',
            'OREGON': 'OR', 'PENNSYLVANIA': 'PA', 'RHODE ISLAND': 'RI', 'SOUTH CAROLINA': 'SC',
            'SOUTH DAKOTA': 'SD', 'TENNESSEE': 'TN', 'TEXAS': 'TX', 'UTAH': 'UT',
            'VERMONT': 'VT', 'VIRGINIA': 'VA', 'WASHINGTON': 'WA', 'WEST VIRGINIA': 'WV',
            'WISCONSIN': 'WI', 'WYOMING': 'WY', 'DISTRICT OF COLUMBIA': 'DC'
        }
        
        return state_map.get(state.upper(), state[:2])
    
    def _normalize_zip(self, zip_code: str) -> str:
        """Normalize ZIP code: 5 or 9 digits"""
        if not zip_code:
            return ''
        
        # Extract digits
        digits = re.sub(r'\D', '', str(zip_code))
        
        if len(digits) >= 9:
            return f"{digits[:5]}-{digits[5:9]}"
        elif len(digits) >= 5:
            return digits[:5]
        
        return ''
    
    def _parse_date(self, date_str: str) -> Optional[datetime]:
        """Parse date string to datetime"""
        if not date_str:
            return None
        
        date_str = str(date_str).strip()
        
        formats = [
            '%Y-%m-%d',
            '%m/%d/%Y',
            '%m/%d/%y',
            '%Y-%m-%dT%H:%M:%S',
            '%Y-%m-%d %H:%M:%S',
            '%m-%d-%Y',
            '%d-%m-%Y',
        ]
        
        for fmt in formats:
            try:
                return datetime.strptime(date_str, fmt)
            except:
                continue
        
        return None
    
    # ========================================================================
    # DEDUPLICATION
    # ========================================================================
    
    def find_duplicates(self, record: ImportRecord) -> List[Dict]:
        """
        Find existing donors that may be duplicates of this record
        
        Returns list of potential matches with confidence scores
        """
        duplicates = []
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Exact email match
        active, _ = self._check_function('dedupe_exact_email')
        if active and record.email:
            cur.execute("""
                SELECT donor_id, email, phone, first_name, last_name, 
                       address, city, state, zip_code
                FROM donors
                WHERE candidate_id = %s AND LOWER(email) = LOWER(%s)
            """, (self.candidate_id, record.email))
            
            for row in cur.fetchall():
                duplicates.append({
                    'donor_id': str(row['donor_id']),
                    'match_type': 'exact_email',
                    'confidence': 100,
                    'data': dict(row)
                })
        
        # Exact phone match
        active, _ = self._check_function('dedupe_exact_phone')
        if active and record.phone and not duplicates:
            cur.execute("""
                SELECT donor_id, email, phone, first_name, last_name,
                       address, city, state, zip_code
                FROM donors
                WHERE candidate_id = %s AND phone = %s
            """, (self.candidate_id, record.phone))
            
            for row in cur.fetchall():
                # Check if already found by email
                if not any(d['donor_id'] == str(row['donor_id']) for d in duplicates):
                    duplicates.append({
                        'donor_id': str(row['donor_id']),
                        'match_type': 'exact_phone',
                        'confidence': 95,
                        'data': dict(row)
                    })
        
        # Fuzzy name match
        active, _ = self._check_function('dedupe_fuzzy_name')
        if active and HAS_FUZZY and record.first_name and record.last_name and not duplicates:
            full_name = f"{record.first_name} {record.last_name}"
            
            cur.execute("""
                SELECT donor_id, email, phone, first_name, last_name,
                       address, city, state, zip_code
                FROM donors
                WHERE candidate_id = %s
                  AND (LOWER(last_name) = LOWER(%s) OR 
                       similarity(last_name, %s) > 0.5)
            """, (self.candidate_id, record.last_name, record.last_name))
            
            for row in cur.fetchall():
                existing_name = f"{row['first_name']} {row['last_name']}"
                score = fuzz.ratio(full_name.lower(), existing_name.lower())
                
                if score >= ImportConfig.FUZZY_MATCH_THRESHOLD:
                    if not any(d['donor_id'] == str(row['donor_id']) for d in duplicates):
                        duplicates.append({
                            'donor_id': str(row['donor_id']),
                            'match_type': 'fuzzy_name',
                            'confidence': score,
                            'data': dict(row)
                        })
        
        conn.close()
        return duplicates
    
    # ========================================================================
    # IMPORT WORKFLOW
    # ========================================================================
    
    def import_file(
        self,
        file_content: Union[bytes, io.BytesIO],
        file_name: str,
        uploaded_by: str,
        settings: Dict = None
    ) -> ImportResult:
        """
        Complete import workflow:
        1. Parse file
        2. Detect format and map columns
        3. Normalize records
        4. Deduplicate
        5. Insert/update donors
        6. Trigger enrichment
        7. Notify E20 Brain
        
        Args:
            file_content: File bytes
            file_name: Original filename
            uploaded_by: User ID who uploaded
            settings: Optional import settings
        
        Returns:
            ImportResult with counts and details
        """
        settings = settings or {}
        started_at = datetime.now()
        
        # Create import job
        import_id = str(uuid.uuid4())
        self.current_import_id = import_id
        
        conn = self._get_db()
        cur = conn.cursor()
        
        # Get file size
        if isinstance(file_content, bytes):
            file_size = len(file_content)
        else:
            file_content.seek(0, 2)
            file_size = file_content.tell()
            file_content.seek(0)
        
        file_type = self._detect_file_type(file_name)
        
        cur.execute("""
            INSERT INTO import_jobs 
            (import_id, candidate_id, uploaded_by, file_name, file_type, 
             file_size_bytes, status, settings, started_at)
            VALUES (%s, %s, %s, %s, %s, %s, 'processing', %s, NOW())
        """, (import_id, self.candidate_id, uploaded_by, file_name, file_type,
              file_size, json.dumps(settings)))
        conn.commit()
        
        result = ImportResult(
            import_id=import_id,
            candidate_id=self.candidate_id,
            file_name=file_name,
            total_rows=0,
            imported=0,
            duplicates=0,
            errors=0,
            skipped=0,
            started_at=started_at
        )
        
        try:
            # Step 1: Parse file
            records, metadata = self.parse_file(file_content, file_name, file_type)
            result.total_rows = len(records)
            
            # Update job with row count
            cur.execute("""
                UPDATE import_jobs SET total_rows = %s WHERE import_id = %s
            """, (len(records), import_id))
            conn.commit()
            
            if not records:
                raise ValueError("No records found in file")
            
            # Step 2: Detect format and map columns
            source_format = self.detect_source_format(metadata['columns'])
            column_mapping = self.auto_map_columns(metadata['columns'])
            
            cur.execute("""
                UPDATE import_jobs SET column_mapping = %s WHERE import_id = %s
            """, (json.dumps({'format': source_format, 'mapping': column_mapping}), import_id))
            conn.commit()
            
            # Step 3-5: Process records in batches
            batch = []
            
            for i, raw_record in enumerate(records):
                try:
                    # Normalize
                    normalized = self.normalize_record(raw_record, column_mapping)
                    
                    # Skip if no email or phone
                    if not normalized.email and not normalized.phone:
                        result.skipped += 1
                        continue
                    
                    # Check for duplicates
                    dupes = self.find_duplicates(normalized)
                    
                    if dupes:
                        # Merge with existing
                        active, _ = self._check_function('dedupe_merge_records')
                        if active and settings.get('auto_merge', True):
                            self._merge_with_existing(normalized, dupes[0], cur)
                            result.duplicates += 1
                        else:
                            result.duplicates += 1
                    else:
                        # Insert new donor
                        self._insert_donor(normalized, cur)
                        result.imported += 1
                    
                    batch.append(normalized)
                    
                    # Commit batch
                    if len(batch) >= ImportConfig.BATCH_SIZE:
                        conn.commit()
                        batch = []
                        
                        # Update progress
                        cur.execute("""
                            UPDATE import_jobs 
                            SET imported_count = %s, duplicate_count = %s, 
                                error_count = %s, skipped_count = %s
                            WHERE import_id = %s
                        """, (result.imported, result.duplicates, result.errors, 
                              result.skipped, import_id))
                        conn.commit()
                
                except Exception as e:
                    result.errors += 1
                    result.error_details.append({
                        'row': i + 1,
                        'error': str(e),
                        'data': raw_record
                    })
            
            # Final commit
            conn.commit()
            
            # Step 6: Trigger enrichment
            active, _ = self._check_function('enrich_calculate_grade')
            if active:
                self._trigger_enrichment(import_id)
            
            # Step 7: Notify completion
            active, _ = self._check_function('notify_import_complete')
            if active:
                self._notify_complete(result)
            
            # Update job status
            result.completed_at = datetime.now()
            result.duration_seconds = (result.completed_at - result.started_at).total_seconds()
            
            cur.execute("""
                UPDATE import_jobs 
                SET status = 'completed',
                    imported_count = %s,
                    duplicate_count = %s,
                    error_count = %s,
                    skipped_count = %s,
                    error_details = %s,
                    completed_at = NOW(),
                    duration_seconds = %s
                WHERE import_id = %s
            """, (result.imported, result.duplicates, result.errors, result.skipped,
                  json.dumps(result.error_details[:100]),  # Limit stored errors
                  result.duration_seconds, import_id))
            conn.commit()
            
        except Exception as e:
            # Mark job as failed
            cur.execute("""
                UPDATE import_jobs 
                SET status = 'failed',
                    error_details = %s,
                    completed_at = NOW()
                WHERE import_id = %s
            """, (json.dumps({'fatal_error': str(e)}), import_id))
            conn.commit()
            raise
        
        finally:
            conn.close()
        
        logger.info(f"Import complete: {result.imported} imported, {result.duplicates} duplicates, {result.errors} errors")
        return result
    
    def _insert_donor(self, record: ImportRecord, cur):
        """Insert new donor record"""
        donor_id = str(uuid.uuid4())
        
        cur.execute("""
            INSERT INTO donors (
                donor_id, candidate_id, email, phone, 
                first_name, last_name, address, city, state, zip_code,
                source, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
        """, (
            donor_id, self.candidate_id, record.email, record.phone,
            record.first_name, record.last_name, record.address,
            record.city, record.state, record.zip_code, 'upload'
        ))
        
        # Insert donation if present
        if record.donation_amount and record.donation_amount > 0:
            cur.execute("""
                INSERT INTO donations (
                    donation_id, donor_id, candidate_id, amount, 
                    donation_date, source, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, NOW())
            """, (
                str(uuid.uuid4()), donor_id, self.candidate_id,
                record.donation_amount, 
                record.donation_date or datetime.now(),
                'upload'
            ))
        
        return donor_id
    
    def _merge_with_existing(self, record: ImportRecord, existing: Dict, cur):
        """Merge new record with existing donor"""
        donor_id = existing['donor_id']
        
        # Update fields that are missing
        updates = []
        values = []
        
        if record.phone and not existing['data'].get('phone'):
            updates.append("phone = %s")
            values.append(record.phone)
        
        if record.address and not existing['data'].get('address'):
            updates.append("address = %s")
            values.append(record.address)
        
        if record.city and not existing['data'].get('city'):
            updates.append("city = %s")
            values.append(record.city)
        
        if record.state and not existing['data'].get('state'):
            updates.append("state = %s")
            values.append(record.state)
        
        if record.zip_code and not existing['data'].get('zip_code'):
            updates.append("zip_code = %s")
            values.append(record.zip_code)
        
        if updates:
            updates.append("updated_at = NOW()")
            values.append(donor_id)
            
            cur.execute(f"""
                UPDATE donors SET {', '.join(updates)}
                WHERE donor_id = %s
            """, values)
        
        # Add donation if present
        if record.donation_amount and record.donation_amount > 0:
            cur.execute("""
                INSERT INTO donations (
                    donation_id, donor_id, candidate_id, amount,
                    donation_date, source, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, NOW())
            """, (
                str(uuid.uuid4()), donor_id, self.candidate_id,
                record.donation_amount,
                record.donation_date or datetime.now(),
                'upload'
            ))
    
    def _trigger_enrichment(self, import_id: str):
        """Trigger E01 enrichment for imported donors"""
        if self.redis:
            event = {
                'event_type': 'import.completed',
                'ecosystem': 1,
                'import_id': import_id,
                'candidate_id': self.candidate_id,
                'action': 'enrich_donors',
                'timestamp': datetime.now().isoformat()
            }
            self.redis.publish('broyhillgop.events', json.dumps(event))
    
    def _notify_complete(self, result: ImportResult):
        """Send completion notification"""
        if self.redis:
            event = {
                'event_type': 'import.notification',
                'ecosystem': 1,
                'candidate_id': self.candidate_id,
                'import_id': result.import_id,
                'summary': {
                    'total': result.total_rows,
                    'imported': result.imported,
                    'duplicates': result.duplicates,
                    'errors': result.errors
                },
                'timestamp': datetime.now().isoformat()
            }
            self.redis.publish('broyhillgop.events', json.dumps(event))


# ============================================================================
# DEPLOYMENT
# ============================================================================

def deploy_data_import_schema():
    """Deploy the data import schema and initialize default controls"""
    print("=" * 70)
    print("📥 E01 EXTENSION: DATA IMPORT ENGINE - DEPLOYMENT")
    print("=" * 70)
    print()
    
    try:
        conn = psycopg2.connect(ImportConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("Deploying Data Import schema...")
        cur.execute(DATA_IMPORT_SCHEMA)
        conn.commit()
        
        print("   ✅ import_control_master table")
        print("   ✅ import_control_categories table")
        print("   ✅ import_control_functions table")
        print("   ✅ import_control_access table")
        print("   ✅ import_control_audit table")
        print("   ✅ import_jobs table")
        print("   ✅ import_staging table")
        print("   ✅ import_column_mappings table")
        print()
        
        # Initialize default functions
        print("Initializing default function toggles...")
        for func in DEFAULT_FUNCTIONS:
            cur.execute("""
                INSERT INTO import_control_functions 
                (scope, function_id, function_name, category, description, 
                 state, min_access_level)
                VALUES ('global', %s, %s, %s, %s, 'on', %s)
                ON CONFLICT (scope, function_id) DO NOTHING
            """, (
                func['function_id'],
                func['function_name'],
                func['category'],
                func['description'],
                func['min_access_level']
            ))
        
        conn.commit()
        print(f"   ✅ {len(DEFAULT_FUNCTIONS)} functions initialized")
        print()
        
        conn.close()
        
        print("=" * 70)
        print("✅ DATA IMPORT ENGINE DEPLOYED!")
        print("=" * 70)
        print()
        print("Features:")
        print("   • CSV/XLS/XLSX/PDF file parsing")
        print("   • WinRed & Anedot auto-mapping")
        print("   • Contact normalization (phone, email, name, address)")
        print("   • Deduplication (exact + fuzzy matching)")
        print("   • Hierarchical control panel (master/category/function)")
        print("   • E20 Brain integration")
        print()
        print("Control Panel Access Levels:")
        print("   • BROYHILLGOP_ADMIN: Full access")
        print("   • CAMPAIGN_MANAGER: Category + function controls")
        print("   • CANDIDATE: Limited function toggles")
        print()
        
        return True
        
    except Exception as e:
        print(f"❌ Deployment failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def initialize_candidate_controls(candidate_id: str):
    """Initialize control panel for a specific candidate"""
    conn = psycopg2.connect(ImportConfig.DATABASE_URL)
    cur = conn.cursor()
    
    # Copy global settings to candidate scope
    cur.execute("""
        INSERT INTO import_control_master (scope, state)
        SELECT %s, state FROM import_control_master WHERE scope = 'global'
        ON CONFLICT (scope) DO NOTHING
    """, (candidate_id,))
    
    cur.execute("""
        INSERT INTO import_control_categories (scope, category, state)
        SELECT %s, category, state FROM import_control_categories WHERE scope = 'global'
        ON CONFLICT (scope, category) DO NOTHING
    """, (candidate_id,))
    
    cur.execute("""
        INSERT INTO import_control_functions 
        (scope, function_id, function_name, category, description, state, min_access_level)
        SELECT %s, function_id, function_name, category, description, state, min_access_level
        FROM import_control_functions WHERE scope = 'global'
        ON CONFLICT (scope, function_id) DO NOTHING
    """, (candidate_id,))
    
    conn.commit()
    conn.close()
    
    print(f"✅ Control panel initialized for candidate {candidate_id}")


# ============================================================================
# CLI INTERFACE
# ============================================================================

if __name__ == "__main__":
    import sys

# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 01DataImportEngineError(Exception):
    """Base exception for this ecosystem"""
    pass

class 01DataImportEngineValidationError(01DataImportEngineError):
    """Validation error in this ecosystem"""
    pass

class 01DataImportEngineDatabaseError(01DataImportEngineError):
    """Database error in this ecosystem"""
    pass

class 01DataImportEngineAPIError(01DataImportEngineError):
    """API error in this ecosystem"""
    pass
# === END CUSTOM EXCEPTIONS ===


# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 01DataImportEngineError(Exception):
    """Base exception for this ecosystem"""
    pass

class 01DataImportEngineValidationError(01DataImportEngineError):
    """Validation error in this ecosystem"""
    pass

class 01DataImportEngineDatabaseError(01DataImportEngineError):
    """Database error in this ecosystem"""
    pass

class 01DataImportEngineAPIError(01DataImportEngineError):
    """API error in this ecosystem"""
    pass
# === END CUSTOM EXCEPTIONS ===

    
    if len(sys.argv) < 2:
        print("📥 E01 Data Import Engine")
        print()
        print("Usage:")
        print("  python ecosystem_01_data_import_engine.py --deploy")
        print("  python ecosystem_01_data_import_engine.py --init-candidate <candidate_id>")
        print("  python ecosystem_01_data_import_engine.py --status [scope]")
        print("  python ecosystem_01_data_import_engine.py --set-master <on|off|timer> [minutes]")
        print()
        sys.exit(0)
    
    command = sys.argv[1]
    
    if command == "--deploy":
        deploy_data_import_schema()
    
    elif command == "--init-candidate" and len(sys.argv) > 2:
        initialize_candidate_controls(sys.argv[2])
    
    elif command == "--status":
        scope = sys.argv[2] if len(sys.argv) > 2 else "global"
        panel = ImportControlPanel(scope)
        status = panel.get_full_status()
        print(json.dumps(status, indent=2, default=str))
    
    elif command == "--set-master" and len(sys.argv) > 2:
        scope = "global"
        state = ToggleState(sys.argv[2])
        timer = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        
        panel = ImportControlPanel(scope)
        panel.set_master_state(state, "cli_user", timer)
        print(f"✅ Master switch set to {state.value}")
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
