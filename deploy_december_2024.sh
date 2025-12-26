#!/bin/bash
# ============================================================================
# DECEMBER 2024 ENHANCEMENT DEPLOYMENT SCRIPT
# ============================================================================
#
# This script deploys the December 2024 enhancements:
# - Triple Grading System
# - Office Context Mapping
# - Cultivation Intelligence
# - Event Timing Discipline
#
# Prerequisites:
# - psql client installed
# - DATABASE_URL environment variable set
# - Python 3.9+ with pip
#
# ============================================================================

set -e

echo "============================================"
echo "BroyhillGOP December 2024 Enhancement Deploy"
echo "============================================"
echo ""

# Check for DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL environment variable not set"
    echo ""
    echo "Set it with:"
    echo "  export DATABASE_URL='postgresql://postgres:PASSWORD@db.PROJECT.supabase.co:5432/postgres'"
    echo ""
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Project root: $PROJECT_ROOT"
echo ""

# ============================================================================
# STEP 1: RUN DATABASE MIGRATION
# ============================================================================
echo "[1/4] Running database migration..."
echo "---------------------------------------------"

MIGRATION_FILE="$PROJECT_ROOT/database/migrations/2024_12_enhancement_migration.sql"

if [ -f "$MIGRATION_FILE" ]; then
    psql "$DATABASE_URL" -f "$MIGRATION_FILE"
    echo "✓ Migration complete"
else
    echo "ERROR: Migration file not found: $MIGRATION_FILE"
    exit 1
fi

echo ""

# ============================================================================
# STEP 2: VERIFY TABLES CREATED
# ============================================================================
echo "[2/4] Verifying database tables..."
echo "---------------------------------------------"

VERIFY_SQL="
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'nc_districts',
    'nc_office_types', 
    'donation_menu_levels',
    'microsegment_performance',
    'volunteer_grades',
    'event_invitations',
    'special_guest_types',
    'campaign_audience_grades'
)
ORDER BY table_name;
"

TABLE_COUNT=$(psql "$DATABASE_URL" -t -c "$VERIFY_SQL" | grep -c '^\s*[a-z]' || true)

echo "Found $TABLE_COUNT of 8 expected tables"

if [ "$TABLE_COUNT" -lt 8 ]; then
    echo "WARNING: Not all tables created. Check migration logs."
else
    echo "✓ All tables verified"
fi

echo ""

# ============================================================================
# STEP 3: INSTALL PYTHON DEPENDENCIES
# ============================================================================
echo "[3/4] Installing Python dependencies..."
echo "---------------------------------------------"

cd "$PROJECT_ROOT"

if [ -f "requirements.txt" ]; then
    # Add new dependencies if not already present
    grep -q "fastapi" requirements.txt || echo "fastapi>=0.109.0" >> requirements.txt
    grep -q "uvicorn" requirements.txt || echo "uvicorn>=0.27.0" >> requirements.txt
    grep -q "psycopg2-binary" requirements.txt || echo "psycopg2-binary>=2.9.9" >> requirements.txt
    grep -q "pydantic" requirements.txt || echo "pydantic>=2.5.0" >> requirements.txt
    
    pip install -r requirements.txt --quiet
    echo "✓ Dependencies installed"
else
    pip install fastapi uvicorn psycopg2-binary pydantic --quiet
    echo "✓ Dependencies installed (no requirements.txt found)"
fi

echo ""

# ============================================================================
# STEP 4: RECALCULATE DISTRICT GRADES (if data exists)
# ============================================================================
echo "[4/4] Checking for district grade recalculation..."
echo "---------------------------------------------"

DONOR_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM persons WHERE is_donor = TRUE;" 2>/dev/null || echo "0")

if [ "$DONOR_COUNT" -gt 0 ]; then
    echo "Found $DONOR_COUNT donors. Recalculating district grades..."
    psql "$DATABASE_URL" -c "SELECT recalculate_district_grades();" 2>/dev/null || echo "Note: recalculate_district_grades() may require district assignments first"
    echo "✓ Grade recalculation attempted"
else
    echo "No donor data found. Skipping grade recalculation."
    echo "Run 'SELECT recalculate_district_grades();' after populating donor data."
fi

echo ""

# ============================================================================
# COMPLETE
# ============================================================================
echo "============================================"
echo "DEPLOYMENT COMPLETE"
echo "============================================"
echo ""
echo "New features available:"
echo "  • Triple Grading (State/District/County)"
echo "  • Office Context Mapping"
echo "  • Cultivation Intelligence (AI-driven)"
echo "  • Event Timing Discipline"
echo ""
echo "To start the API server:"
echo "  cd $PROJECT_ROOT/backend/python/api"
echo "  python campaign_wizard_api.py"
echo ""
echo "API will be available at: http://localhost:8000"
echo "Docs at: http://localhost:8000/docs"
echo ""
