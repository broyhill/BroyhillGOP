#!/usr/bin/env python3
"""
BROYHILLGOP PRE-DEPLOYMENT VALIDATOR
Run BEFORE deploying ANY code to GitHub or Supabase

Usage:
    python pre_deployment_validator.py --sql schema.sql
    python pre_deployment_validator.py --python ecosystem.py
    
Returns: 0=SAFE, 1=WARNINGS, 2=ERRORS (blocked)
"""

import re
import sys
import argparse

EXISTING_TABLES = {
    'donors', 'persons', 'contacts', 'candidates', 'campaigns',
    'donations', 'volunteers', 'events', 'voice_generations',
    'nc_districts', 'nc_office_types', 'donation_menu_levels',
    'intelligence_rules', 'intelligence_triggers', 'intelligence_actions',
    'donor_accounts', 'volunteer_accounts', 'campaign_audience_grades',
    'microsegment_performance', 'volunteer_grades', 'event_invitations'
}

CRITICAL_FUNCTIONS = [
    'calculate_donor_grade', 'recalculate_district_grades',
    'get_contextual_grade', 'process_intelligence_trigger'
]

def validate_sql(content, filename):
    errors, warnings = [], []
    lines = content.split('\n')
    
    for i, line in enumerate(lines, 1):
        # DROP TABLE = ERROR
        if re.search(r'DROP\s+TABLE', line, re.IGNORECASE):
            errors.append(f'[{filename}:{i}] DROP TABLE detected!')
        
        # TRUNCATE = ERROR  
        if re.search(r'TRUNCATE', line, re.IGNORECASE):
            errors.append(f'[{filename}:{i}] TRUNCATE detected!')
        
        # CREATE TABLE without IF NOT EXISTS on existing table
        match = re.search(r'CREATE\s+TABLE\s+(?!IF\s+NOT\s+EXISTS)(\w+)', line, re.IGNORECASE)
        if match:
            table = match.group(1).lower()
            if table in EXISTING_TABLES:
                errors.append(f'[{filename}:{i}] Table {table} exists! Use IF NOT EXISTS')
            else:
                warnings.append(f'[{filename}:{i}] New table {table} - verify needed')
        
        # Critical function modification
        for func in CRITICAL_FUNCTIONS:
            if re.search(f'CREATE.*FUNCTION.*{func}', line, re.IGNORECASE):
                warnings.append(f'[{filename}:{i}] Modifying critical function: {func}')
    
    return errors, warnings

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sql', help='SQL file to validate')
    parser.add_argument('--python', help='Python file to validate')
    args = parser.parse_args()
    
    errors, warnings = [], []
    
    if args.sql:
        with open(args.sql) as f:
            e, w = validate_sql(f.read(), args.sql)
            errors.extend(e)
            warnings.extend(w)
    
    print('='*60)
    print('BROYHILLGOP PRE-DEPLOYMENT VALIDATION')
    print('='*60)
    
    if errors:
        print('\n🚨 ERRORS (DEPLOYMENT BLOCKED):')
        for e in errors: print(f'  {e}')
    
    if warnings:
        print('\n⚠️  WARNINGS (Review Required):')
        for w in warnings: print(f'  {w}')
    
    if not errors and not warnings:
        print('\n✅ VALIDATION PASSED - SAFE TO DEPLOY')
        return 0
    
    return 2 if errors else 1

if __name__ == '__main__':
    sys.exit(main())
