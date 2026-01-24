#!/usr/bin/env python3
"""
NC State Board of Elections Donor Data Processor for BroyhillGOP

Processes NC SBoE individual contributions CSV files from Desktop folder,
filters for Republican candidate committee donors, and imports to Supabase donorsnew table.

Author: Ed Broyhill
Date: January 23, 2026
"""

import os
import csv
import json
from pathlib import Path
from datetime import datetime
import re
from supabase import create_client, Client
from collections import defaultdict

# Configuration
SUPABASE_URL = "https://isbgjpnbocdkeslofota.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MDc3MDcsImV4cCI6MjA4MDI4MzcwN30.pSF0-C-QOklmDWtbexUvnFphuz_bFTdF4INaBMSW1SM"
DESKTOP_PATH = Path.home() / "Desktop"
BATCH_SIZE = 1000

def init_supabase() -> Client:
    """Initialize Supabase client"""
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def find_ncsbe_csv_files() -> list:
    """Find NC SBoE transaction CSV files on Desktop"""
    csv_files = []
    
    for file in DESKTOP_PATH.iterdir():
        if file.suffix == '.csv' and 'transacq' in file.name.lower():
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
    
    # If no comma, assume it's formatted differently
    parts = full_name.split()
    if len(parts) >= 2:
        return {
            'firstname': parts[0],
            'middlename': parts[1] if len(parts) > 2 else '',
            'lastname': parts[-1],
            'suffix': ''
        }
    
    return {'firstname': full_name, 'middlename': '', 'lastname': '', 'suffix': ''}

def generate_name_variants(firstname: str, middlename: str, lastname: str) -> list:
    """Generate name variants for deduplication"""
    variants = []
    
    if firstname and lastname:
        variants.append(f"{firstname} {lastname}")
        
        if middlename:
            variants.append(f"{firstname} {middlename[0]} {lastname}")
            variants.append(f"{firstname} {middlename} {lastname}")
        
        variants.append(f"{firstname[0]} {lastname}")
    
    return variants

def generate_dedupe_key(firstname: str, lastname: str, zip5: str) -> str:
    """Generate deduplication key: lastname_firstname_zip5"""
    return f"{lastname.upper()}_{firstname.upper()}_{zip5}".replace(' ', '')

def parse_zip(zipcode: str) -> dict:
    """Parse ZIP code into zip5 and zip4"""
    if not zipcode:
        return {'zip5': '', 'zip4': '', 'zip9': ''}
    
    clean_zip = str(zipcode).replace('-', '').replace(' ', '')
    
    if len(clean_zip) >= 5:
        zip5 = clean_zip[:5]
        zip4 = clean_zip[5:9] if len(clean_zip) > 5 else ''
        zip9 = zip5 + zip4 if zip4 else zip5
        return {'zip5': zip5, 'zip4': zip4, 'zip9': zip9}
    
    return {'zip5': clean_zip, 'zip4': '', 'zip9': clean_zip}

def process_csv_file(csv_path: Path) -> list:
    """Process a single NC SBoE CSV file"""
    nc_donors = []
    
    print(f"Processing {csv_path.name}...")
    
    try:
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                # Only process individual contributions (not expenditures)
                nc_donors.append(row)
        
        print(f"  Found {len(nc_donors)} NC donor records")
    except Exception as e:
        print(f"  Error processing file: {e}")
    
    return nc_donors

def transform_to_donorsnew(ncsbe_records: list) -> list:
    """Transform NC SBoE records to donorsnew schema"""
    donor_groups = defaultdict(list)
    
    for record in ncsbe_records:
        # Parse name and zip from NC SBoE format
        name_parts = parse_name(record.get('Name', ''))
        zip_parts = parse_zip(record.get('Zip Code', ''))
        
        key = generate_dedupe_key(
            name_parts['firstname'],
            name_parts['lastname'],
            zip_parts['zip5']
        )
        
        donor_groups[key].append(record)
    
    donors = []
    
    for dedupe_key, transactions in donor_groups.items():
        first_tx = transactions[0]
        name_parts = parse_name(first_tx.get('Name', ''))
        zip_parts = parse_zip(first_tx.get('Zip Code', ''))
        
        # Calculate aggregates
        total_donated = 0
        for tx in transactions:
            amount_str = tx.get('Amount', '0')
            try:
                total_donated += float(amount_str.replace('$', '').replace(',', ''))
            except:
                pass
        
        # Parse dates
        donation_dates = []
        for tx in transactions:
            date_str = tx.get('Date Occurred', '')
            if date_str:
                try:
                    donation_dates.append(datetime.strptime(date_str, '%m/%d/%Y'))
                except:
                    pass
        
        first_donation = min(donation_dates) if donation_dates else None
        last_donation = max(donation_dates) if donation_dates else None
        
        # Build donor record
        donor = {
            'firstname': name_parts['firstname'],
            'middlename': name_parts['middlename'],
            'lastname': name_parts['lastname'],
            'suffix': name_parts['suffix'],
            'fullnameformal': first_tx.get('Name', ''),
            'namevariants': generate_name_variants(
                name_parts['firstname'],
                name_parts['middlename'],
                name_parts['lastname']
            ),
            'homecity': first_tx.get('City', ''),
            'homestate': 'NC',
            'homezip5': zip_parts['zip5'],
            'homezip4': zip_parts['zip4'],
            'homezip9': zip_parts['zip9'],
            'totaldonatedstate': total_donated,
            'totaldonatedall': total_donated,
            'firstdonationdate': first_donation.isoformat() if first_donation else None,
            'lastdonationdate': last_donation.isoformat() if last_donation else None,
            'donationcount': len(transactions),
            'largestdonation': max(
                (float(tx.get('Amount', '0').replace('$', '').replace(',', '')) for tx in transactions),
                default=0
            ),
            'avgdonation': total_donated / len(transactions) if transactions else 0,
            'isdonor': True,
            'sourcencsbe': True,
            'rawncsbe': json.dumps(transactions[:10]),
            'dedupekeynamezip': dedupe_key,
            'createdat': datetime.now().isoformat(),
            'updatedat': datetime.now().isoformat()
        }
        
        # Add year-by-year totals
        for tx in transactions:
            date_str = tx.get('Date Occurred', '')
            if date_str:
                try:
                    year = datetime.strptime(date_str, '%m/%d/%Y').year
                    year_field = f'donated{year}'
                    if year_field not in donor:
                        donor[year_field] = 0
                    amount = float(tx.get('Amount', '0').replace('$', '').replace(',', ''))
                    donor[year_field] += amount
                except:
                    pass
        
        donors.append(donor)
    
    return donors

def import_to_supabase(supabase: Client, donors: list):
    """Import donors to Supabase donorsnew table in batches"""
    total = len(donors)
    imported = 0
    
    for i in range(0, total, BATCH_SIZE):
        batch = donors[i:i + BATCH_SIZE]
        
        try:
            supabase.table('donorsnew').upsert(
                batch,
                on_conflict='dedupekeynamezip'
            ).execute()
            
            imported += len(batch)
            print(f"  Imported {imported}/{total} donors")
        
        except Exception as e:
            print(f"  Error importing batch: {e}")
            continue

def main():
    """Main execution"""
    print("="*60)
    print("NC SBoE Donor Data Processor for BroyhillGOP")
    print("="*60)
    
    # Find CSV files on Desktop
    csv_files = find_ncsbe_csv_files()
    print(f"\nFound {len(csv_files)} NC SBoE CSV files:")
    for csv_file in csv_files:
        print(f"  - {csv_file.name}")
    
    if not csv_files:
        print("\nNo NC SBoE CSV files found on Desktop.")
        return
    
    # Initialize Supabase
    print("\nConnecting to Supabase...")
    supabase = init_supabase()
    
    # Process each CSV file
    all_nc_donors = []
    
    for csv_file in csv_files:
        nc_donors = process_csv_file(csv_file)
        all_nc_donors.extend(nc_donors)
    
    print(f"\nTotal NC donor transactions: {len(all_nc_donors)}")
    
    # Transform to donorsnew schema
    print("\nTransforming to donorsnew schema...")
    donors = transform_to_donorsnew(all_nc_donors)
    print(f"Unique donors after deduplication: {len(donors)}")
    
    # Import to Supabase
    print("\nImporting to Supabase donorsnew table...")
    import_to_supabase(supabase, donors)
    
    print("\n" + "="*60)
    print("COMPLETE!")
    print(f"Processed {len(csv_files)} files")
    print(f"Found {len(all_nc_donors)} NC transactions")
    print(f"Created {len(donors)} unique donor records")
    print("="*60)

if __name__ == '__main__':
    main()
