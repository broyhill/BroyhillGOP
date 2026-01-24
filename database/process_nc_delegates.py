#!/usr/bin/env python3
"""
NC Delegates and Volunteers Data Processor for BroyhillGOP

Processes NC_DELEGATES.csv files from Desktop folder,
imports to Supabase nc_delegates_staging table,
and updates donor_master with delegate/volunteer flags.

Author: Ed Broyhill
Date: January 24, 2026
"""

import os
import csv
import json
from pathlib import Path
from datetime import datetime
import re
from supabase import create_client, Client

# Configuration
SUPABASE_URL = "https://isbgjpnbocdkeslofota.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MDc3MDcsImV4cCI6MjA4MDI4MzcwN30.pSF0-C-QOklmDWtbexUvnFphuz_bFTdF4INaBMSW1SM"
DESKTOP_PATH = Path.home() / "Desktop"
BATCH_SIZE = 100

def init_supabase() -> Client:
    """Initialize Supabase client"""
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def find_delegate_csv_files() -> list:
    """Find NC Delegate CSV files on Desktop"""
    csv_files = []
    for file in DESKTOP_PATH.iterdir():
        if file.suffix.lower() == '.csv' and 'delegate' in file.name.lower():
            csv_files.append(file)
    return sorted(csv_files)

def parse_name(full_name: str) -> dict:
    """Parse full name into components"""
    if not full_name:
        return {'firstname': '', 'middlename': '', 'lastname': '', 'suffix': ''}
    
    # Handle format: LASTNAME, FIRSTNAME MIDDLENAME SUFFIX
    parts = full_name.split(',')
    
    if len(parts) >= 2:
        lastname = parts[0].strip()
        remaining = parts[1].strip().split()
        firstname = remaining[0] if len(remaining) > 0 else ''
        middlename = remaining[1] if len(remaining) > 1 else ''
        suffix = remaining[2] if len(remaining) > 2 else ''
        return {
            'firstname': firstname,
            'middlename': middlename,
            'lastname': lastname,
            'suffix': suffix
        }
    
    # If no comma, assume FIRSTNAME LASTNAME format
    parts = full_name.split()
    if len(parts) >= 2:
        return {
            'firstname': parts[0],
            'middlename': parts[1] if len(parts) > 2 else '',
            'lastname': parts[-1],
            'suffix': ''
        }
    
    return {'firstname': full_name, 'middlename': '', 'lastname': '', 'suffix': ''}

def clean_phone(phone: str) -> str:
    """Clean phone number to standard format"""
    if not phone:
        return ''
    digits = re.sub(r'\D', '', str(phone))
    if len(digits) == 10:
        return f"{digits[:3]}-{digits[3:6]}-{digits[6:]}"
    return phone

def process_csv_file(csv_path: Path) -> list:
    """Process a single NC Delegates CSV file"""
    delegates = []
    print(f"Processing {csv_path.name}...")
    
    try:
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            for row in reader:
                delegates.append(row)
        print(f"  Found {len(delegates)} delegate records")
    except Exception as e:
        print(f"  Error processing file: {e}")
    
    return delegates

def transform_to_staging(records: list) -> list:
    """Transform delegate records to nc_delegates_staging schema"""
    delegates = []
    
    for record in records:
        # Map CSV columns to staging table columns
        # Flexible mapping to handle various CSV formats
        delegate = {
            'fullname': record.get('Full Name', record.get('fullname', record.get('Name', ''))),
            'firstname': record.get('First Name', record.get('firstname', '')),
            'middlename': record.get('Middle Name', record.get('middlename', '')),
            'lastname': record.get('Last Name', record.get('lastname', '')),
            'suffix': record.get('Suffix', record.get('suffix', '')),
            'address1': record.get('Address', record.get('address1', record.get('Street', ''))),
            'address2': record.get('Address 2', record.get('address2', '')),
            'city': record.get('City', record.get('city', '')),
            'state': record.get('State', record.get('state', 'NC')),
            'zip': record.get('Zip', record.get('zip', record.get('ZIP', ''))),
            'county': record.get('County', record.get('county', '')),
            'homephone': clean_phone(record.get('Home Phone', record.get('homephone', record.get('Phone', '')))),
            'homephonesource': record.get('Home Phone Source', 'CSV Import'),
            'mobilephone': clean_phone(record.get('Mobile Phone', record.get('mobilephone', record.get('Cell', '')))),
            'mobilephonesource': record.get('Mobile Phone Source', 'CSV Import'),
            'otherphone': clean_phone(record.get('Other Phone', record.get('otherphone', ''))),
            'otherphonesource': record.get('Other Phone Source', 'CSV Import'),
            'email': record.get('Email', record.get('email', '')),
            'employer': record.get('Employer', record.get('employer', '')),
            'occupation': record.get('Occupation', record.get('occupation', '')),
            'title': record.get('Title', record.get('title', '')),
            'isdelegate': record.get('Is Delegate', record.get('isdelegate', 'true')).lower() in ['true', 'yes', '1', 't'],
            'isvolunteer': record.get('Is Volunteer', record.get('isvolunteer', 'false')).lower() in ['true', 'yes', '1', 't'],
            'sourcefiles': record.get('Source', 'NC_DELEGATES.csv'),
            'createdat': datetime.now().isoformat(),
            'updatedat': datetime.now().isoformat()
        }
        
        # Parse fullname if firstname/lastname not provided
        if not delegate['firstname'] and delegate['fullname']:
            name_parts = parse_name(delegate['fullname'])
            delegate['firstname'] = name_parts['firstname']
            delegate['middlename'] = name_parts['middlename']
            delegate['lastname'] = name_parts['lastname']
            delegate['suffix'] = name_parts['suffix']
        
        # Build fullname if not provided
        if not delegate['fullname'] and delegate['firstname']:
            delegate['fullname'] = f"{delegate['firstname']} {delegate['lastname']}".strip()
        
        delegates.append(delegate)
    
    return delegates

def import_to_staging(supabase: Client, delegates: list):
    """Import delegates to nc_delegates_staging table"""
    total = len(delegates)
    imported = 0
    
    for i in range(0, total, BATCH_SIZE):
        batch = delegates[i:i + BATCH_SIZE]
        try:
            supabase.table('nc_delegates_staging').upsert(
                batch,
                on_conflict='fullname'
            ).execute()
            imported += len(batch)
            print(f"  Imported {imported}/{total} delegates")
        except Exception as e:
            print(f"  Error importing batch: {e}")
            continue

def update_donor_master(supabase: Client):
    """Update donor_master with delegate/volunteer flags from staging"""
    print("\nUpdating donor_master with delegate flags...")
    
    try:
        # SQL to update donor_master based on name matching
        result = supabase.rpc('update_donor_master_delegates').execute()
        print(f"  Updated donor_master records")
    except Exception as e:
        print(f"  Note: Manual SQL update may be needed: {e}")
        print("  Run the 'NC Delegates Staging Insert' query in Supabase SQL Editor")

def main():
    """Main execution"""
    print("="*60)
    print("NC Delegates Data Processor for BroyhillGOP")
    print("="*60)
    
    # Find CSV files on Desktop
    csv_files = find_delegate_csv_files()
    print(f"\nFound {len(csv_files)} NC Delegate CSV files:")
    for csv_file in csv_files:
        print(f"  - {csv_file.name}")
    
    if not csv_files:
        print("\nNo NC Delegate CSV files found on Desktop.")
        print("Expected files: NC_DELEGATES.csv or similar")
        return
    
    # Initialize Supabase
    print("\nConnecting to Supabase...")
    supabase = init_supabase()
    
    # Process each CSV file
    all_delegates = []
    for csv_file in csv_files:
        delegates = process_csv_file(csv_file)
        all_delegates.extend(delegates)
    
    print(f"\nTotal delegate records: {len(all_delegates)}")
    
    # Transform to staging schema
    print("\nTransforming to nc_delegates_staging schema...")
    staging_records = transform_to_staging(all_delegates)
    print(f"Prepared {len(staging_records)} staging records")
    
    # Import to staging table
    print("\nImporting to nc_delegates_staging table...")
    import_to_staging(supabase, staging_records)
    
    # Update donor_master
    update_donor_master(supabase)
    
    print("\n" + "="*60)
    print("COMPLETE!")
    print(f"Processed {len(csv_files)} files")
    print(f"Imported {len(staging_records)} delegate records")
    print("="*60)

if __name__ == '__main__':
    main()
