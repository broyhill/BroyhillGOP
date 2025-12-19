#!/bin/bash
# ============================================================================
# NEXUS AI Agent System - Deployment Script
# ============================================================================
# Usage: ./deploy.sh [command]
# Commands: migrate, verify, status, test, rollback
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"

# Load environment
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
fi

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo -e "\n${BLUE}============================================================================${NC}"
    echo -e "${BLUE}  NEXUS AI Agent System - $1${NC}"
    echo -e "${BLUE}============================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check PostgreSQL
    if command -v psql &> /dev/null; then
        print_success "PostgreSQL client found"
    else
        print_error "PostgreSQL client not found"
        exit 1
    fi
    
    # Check Python
    if command -v python3 &> /dev/null; then
        print_success "Python 3 found: $(python3 --version)"
    else
        print_error "Python 3 not found"
        exit 1
    fi
    
    # Check DATABASE_URL
    if [ -z "$DATABASE_URL" ]; then
        print_error "DATABASE_URL not set"
        echo "Please set DATABASE_URL in .env or environment"
        exit 1
    else
        print_success "DATABASE_URL configured"
    fi
    
    # Check ANTHROPIC_API_KEY
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        print_warning "ANTHROPIC_API_KEY not set - AI features will be disabled"
    else
        print_success "ANTHROPIC_API_KEY configured"
    fi
}

run_migrations() {
    print_header "Running Migrations"
    
    local migration_files=(
        "001_NEXUS_SOCIAL_EXTENSION.sql"
        "002_NEXUS_HARVEST_ENRICHMENT.sql"
        "003_NEXUS_PLATFORM_INTEGRATION.sql"
    )
    
    for file in "${migration_files[@]}"; do
        if [ -f "$MIGRATIONS_DIR/$file" ]; then
            echo -e "\n${BLUE}Running: $file${NC}"
            
            if psql "$DATABASE_URL" -f "$MIGRATIONS_DIR/$file" 2>&1; then
                print_success "$file completed"
            else
                print_error "$file failed"
                exit 1
            fi
        else
            print_warning "$file not found, skipping"
        fi
    done
    
    print_success "All migrations completed"
}

verify_deployment() {
    print_header "Verifying Deployment"
    
    echo "Checking NEXUS ecosystem registration..."
    result=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM brain_control.ecosystems WHERE ecosystem_code = 'NEXUS';" 2>/dev/null || echo "0")
    if [ "$result" -gt 0 ]; then
        print_success "NEXUS registered in brain_control.ecosystems"
    else
        print_warning "NEXUS not found in ecosystems"
    fi
    
    echo "Checking NEXUS functions..."
    result=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM brain_control.functions WHERE ecosystem_code = 'NEXUS';" 2>/dev/null || echo "0")
    print_success "$result NEXUS functions registered"
    
    echo "Checking NEXUS tables..."
    tables=(
        "nexus_harvest_records"
        "nexus_enrichment_queue"
        "nexus_brain_triggers"
        "nexus_cost_transactions"
        "nexus_ml_models"
        "nexus_metrics_bva"
        "nexus_lp_constraints"
    )
    
    for table in "${tables[@]}"; do
        result=$(psql "$DATABASE_URL" -t -c "SELECT to_regclass('public.$table');" 2>/dev/null)
        if [[ "$result" == *"$table"* ]]; then
            print_success "Table: $table"
        else
            print_warning "Missing table: $table"
        fi
    done
    
    echo "Checking NEXUS views..."
    views=(
        "v_nexus_executive_dashboard"
        "v_nexus_budget_variance"
        "v_nexus_operations_report"
    )
    
    for view in "${views[@]}"; do
        result=$(psql "$DATABASE_URL" -t -c "SELECT to_regclass('public.$view');" 2>/dev/null)
        if [[ "$result" == *"$view"* ]]; then
            print_success "View: $view"
        else
            print_warning "Missing view: $view"
        fi
    done
}

show_status() {
    print_header "NEXUS Status"
    
    echo "Ecosystem Info:"
    psql "$DATABASE_URL" -c "SELECT ecosystem_code, ecosystem_name, status, ai_powered, monthly_budget FROM brain_control.ecosystems WHERE ecosystem_code = 'NEXUS';" 2>/dev/null || echo "Not found"
    
    echo -e "\nFunctions:"
    psql "$DATABASE_URL" -c "SELECT function_code, function_name, unit_cost FROM brain_control.functions WHERE ecosystem_code = 'NEXUS';" 2>/dev/null || echo "Not found"
    
    echo -e "\nBudget Status:"
    psql "$DATABASE_URL" -c "SELECT * FROM v_nexus_budget_variance;" 2>/dev/null || echo "View not found"
    
    echo -e "\nRecent Decisions (7 days):"
    psql "$DATABASE_URL" -c "SELECT decision, COUNT(*) as count FROM intelligence_brain.nexus_decisions WHERE created_at > NOW() - INTERVAL '7 days' GROUP BY decision;" 2>/dev/null || echo "Table not found"
}

run_tests() {
    print_header "Running Tests"
    
    echo "Testing Python imports..."
    python3 -c "
from engines.nexus_brain_engine import NexusBrainEngine, TriggerType
from ecosystem_nexus_complete import NexusEcosystem
print('✅ Python imports successful')
" || print_error "Python import failed"
    
    echo -e "\nTesting database connection..."
    python3 -c "
import psycopg2
import os
conn = psycopg2.connect(os.environ['DATABASE_URL'])
cur = conn.cursor()
cur.execute('SELECT 1')
print('✅ Database connection successful')
conn.close()
" || print_error "Database connection failed"
    
    echo -e "\nRunning pytest..."
    if [ -d "tests" ]; then
        python3 -m pytest tests/ -v || print_warning "Some tests failed"
    else
        print_warning "No tests directory found"
    fi
}

rollback() {
    print_header "Rollback NEXUS"
    
    print_warning "This will remove all NEXUS data and schema objects!"
    read -p "Are you sure? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Rollback cancelled"
        exit 0
    fi
    
    echo "Rolling back NEXUS..."
    
    psql "$DATABASE_URL" << 'EOF'
-- Drop NEXUS-specific tables
DROP TABLE IF EXISTS nexus_cost_transactions CASCADE;
DROP TABLE IF EXISTS nexus_ml_predictions CASCADE;
DROP TABLE IF EXISTS nexus_ml_models CASCADE;
DROP TABLE IF EXISTS nexus_lp_runs CASCADE;
DROP TABLE IF EXISTS nexus_lp_constraints CASCADE;
DROP TABLE IF EXISTS nexus_metrics_bva CASCADE;
DROP TABLE IF EXISTS nexus_communication_strategies CASCADE;
DROP TABLE IF EXISTS intelligence_brain.nexus_decisions CASCADE;
DROP TABLE IF EXISTS intelligence_brain.nexus_trigger_types CASCADE;
DROP TABLE IF EXISTS nexus_approval_learning CASCADE;
DROP TABLE IF EXISTS nexus_ml_optimization CASCADE;
DROP TABLE IF EXISTS nexus_persona_issue_mapping CASCADE;
DROP TABLE IF EXISTS nexus_variance_reports CASCADE;
DROP TABLE IF EXISTS nexus_brain_triggers CASCADE;
DROP TABLE IF EXISTS nexus_enrichment_queue CASCADE;
DROP TABLE IF EXISTS nexus_enrichment_waterfall CASCADE;
DROP TABLE IF EXISTS nexus_harvest_batches CASCADE;
DROP TABLE IF EXISTS nexus_harvest_records CASCADE;

-- Remove from brain_control
DELETE FROM brain_control.functions WHERE ecosystem_code = 'NEXUS';
DELETE FROM brain_control.ecosystem_dependencies WHERE ecosystem_code = 'NEXUS' OR depends_on = 'NEXUS';
DELETE FROM brain_control.budget_forecasts WHERE ecosystem_code = 'NEXUS';
DELETE FROM brain_control.budget_allocations WHERE ecosystem_code = 'NEXUS';
DELETE FROM brain_control.ecosystems WHERE ecosystem_code = 'NEXUS';

-- Drop views
DROP VIEW IF EXISTS v_nexus_executive_dashboard CASCADE;
DROP VIEW IF EXISTS v_nexus_budget_variance CASCADE;
DROP VIEW IF EXISTS v_nexus_operations_report CASCADE;
DROP VIEW IF EXISTS v_nexus_candidate_performance CASCADE;
DROP VIEW IF EXISTS v_nexus_daily_costs CASCADE;
DROP VIEW IF EXISTS v_nexus_monthly_costs CASCADE;
DROP VIEW IF EXISTS v_nexus_harvest_progress CASCADE;
DROP VIEW IF EXISTS v_nexus_donor_enrichment CASCADE;
DROP VIEW IF EXISTS v_nexus_volunteer_enrichment CASCADE;
DROP VIEW IF EXISTS v_nexus_approval_performance CASCADE;
DROP VIEW IF EXISTS v_nexus_persona_effectiveness CASCADE;
DROP VIEW IF EXISTS v_nexus_queue_status CASCADE;
DROP VIEW IF EXISTS v_nexus_brain_summary CASCADE;
DROP VIEW IF EXISTS v_nexus_variance_alerts CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS nexus_record_decision CASCADE;
DROP FUNCTION IF EXISTS nexus_record_cost CASCADE;
DROP FUNCTION IF EXISTS nexus_update_bva_metrics CASCADE;
DROP FUNCTION IF EXISTS nexus_match_harvest_to_donor CASCADE;
DROP FUNCTION IF EXISTS nexus_calculate_persona_score CASCADE;
DROP FUNCTION IF EXISTS nexus_queue_enrichment CASCADE;

SELECT 'NEXUS rollback complete' AS status;
EOF
    
    print_success "Rollback completed"
}

show_help() {
    echo "NEXUS Deployment Script"
    echo ""
    echo "Usage: ./deploy.sh [command]"
    echo ""
    echo "Commands:"
    echo "  migrate   Run database migrations"
    echo "  verify    Verify deployment"
    echo "  status    Show NEXUS status"
    echo "  test      Run tests"
    echo "  rollback  Remove NEXUS (destructive)"
    echo "  help      Show this help"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh migrate    # Run all migrations"
    echo "  ./deploy.sh verify     # Check deployment"
    echo "  ./deploy.sh status     # View current status"
}

# ============================================================================
# MAIN
# ============================================================================

case "${1:-help}" in
    migrate)
        check_prerequisites
        run_migrations
        verify_deployment
        ;;
    verify)
        check_prerequisites
        verify_deployment
        ;;
    status)
        show_status
        ;;
    test)
        run_tests
        ;;
    rollback)
        rollback
        ;;
    help|*)
        show_help
        ;;
esac
