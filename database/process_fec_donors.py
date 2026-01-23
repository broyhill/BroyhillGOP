#!/usr/bin/env python3
"""
FEC Donor Data Processor for BroyhillGOP

Processes FEC individual contributions ZIP files from Downloads folder,
filters for NC Republican donors, and imports to Supabase donorsnew table.

Author: Ed Broyhill
Date: January 23, 2026
"""

import os
import zipfile
import csv
from pathlib import Path
import json
from datetime import datetime
import re
from supabase import create_client, Client
from collections import defaultdict

# Configuration
SUPABASE_URL = "https://isbgjpnbocdkeslofota.supabase.co"
SUPABASE_KEY = "your-anon-key-here"  # Replace with actual key
DOWNLOADS_PATH = Path.home() / "Downloads"
BATCH_SIZE = 1000

# FEC file column mapping (based on FEC header file)
FEC_COLUMNS = [
    'CMTE_ID', 'AMNDT_IND', 'RPT_TP', 'TRANSACTION_PGI', 'IMAGE_NUM',
    'TRANSACTION_TP', 'ENTITY_TP', 'NAME', 'CITY', 'STATE', 'ZIP_CODE',
    'EMPLOYER', 'OCCUPATION', 'TRANSACTION_DT', 'TRANSACTION_AMT',
    'OTHER_ID', 'TRAN_ID', 'FILE_NUM', 'MEMO_CD', 'MEMO_TEXT', 'SUB_ID'
]

def init_supabase() -> Client:
    """Initialize Supabase client"""
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def find_fec_zip_files() -> list:
    """Find all FEC individual contributions ZIP files in Downloads"""
    pattern = re.compile(r'indiv\d{2}\.zip')
    zip_files = []
    
    for file in DOWNLOADS_PATH.iterdir():
        if pattern.match(file.name):
            zip_files.append(file)
    
    return sorted(zip_files)

def parse_name(full_name: str) -> dict:
    """Parse full name into components"""
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
    
    return {'firstname': full_name, 'middlename': '', 'lastname': '', 'suffix': ''}

def generate_name_variants(firstname: str, middlename: str, lastname: str) -> list:
    """Generate name variants for deduplication"""
    variants = []
    
    if firstname and lastname:
        # Full name
        variants.append(f"{firstname} {lastname}")
        
        # With middle initial
        if middlename:
            variants.append(f"{firstname} {middlename[0]} {lastname}")
            variants.append(f"{firstname} {middlename} {lastname}")
        
        # First initial + last name
        variants.append(f"{firstname[0]} {lastname}")
        
        # Common nicknames
        nicknames = {
            'JAMES': ['JIM', 'JIMMY', 'JAMIE'],
            'WILLIAM': ['BILL', 'BILLY', 'WILL'],
            'ROBERT': ['BOB', 'BOBBY', 'ROB'],
            'RICHARD': ['RICK', 'DICK', 'RICH'],
            'MICHAEL': ['MIKE', 'MICH'],
            'EDWARD': ['ED', 'EDDIE', 'TED'],
            'THOMAS': ['TOM', 'TOMMY'],
            'CHARLES': ['CHUCK', 'CHARLIE'],
            'JOSEPH': ['JOE', 'JOEY'],
            'ELIZABETH': ['LIZ', 'BETH', 'BETTY'],
            'MARGARET': ['MAGGIE', 'PEGGY', 'MEG']
        }
        
        if firstname.upper() in nicknames:
            for nick in nicknames[firstname.upper()]:
                variants.append(f"{nick} {lastname}")
    
    return variants

def generate_dedupe_key(firstname: str, lastname: str, zip5: str) -> str:
    """Generate deduplication key: lastname_firstname_zip5"""
    return f"{lastname.upper()}_{firstname.upper()}_{zip5}".replace(' ', '')

def parse_zip(zipcode: str) -> dict:
    """Parse ZIP code into zip5 and zip4"""
    if not zipcode:
        return {'zip5': '', 'zip4': '', 'zip9': ''}
    
    # Remove hyphens and spaces
    clean_zip = zipcode.replace('-', '').replace(' ', '')
    
    if len(clean_zip) >= 5:
        zip5 = clean_zip[:5]
        zip4 = clean_zip[5:9] if len(clean_zip) > 5 else ''
        zip9 = zip5 + zip4 if zip4 else zip5
        return {'zip5': zip5, 'zip4': zip4, 'zip9': zip9}
    
    return {'zip5': clean_zip, 'zip4': '', 'zip9': clean_zip}

def process_zip_file(zip_path: Path) -> list:
    """Extract and process a single FEC ZIP file"""
    nc_donors = []
    
    print(f"Processing {zip_path.name}...")
    
    with zipfile.ZipFile(zip_path, 'r') as zf:
        # FEC files are typically named like itcont.txt inside the ZIP
        txt_files = [f for f in zf.namelist() if f.endswith('.txt')]
        
        for txt_file in txt_files:
            print(f"  Reading {txt_file}...")
            
            with zf.open(txt_file) as f:
                # FEC files are pipe-delimited
                reader = csv.DictReader(
                    (line.decode('latin-1') for line in f),
                    fieldnames=FEC_COLUMNS,
                    delimiter='|'
                )
                
                for row in reader:
                    # Filter for NC only
                    if row.get('STATE') == 'NC':
                        nc_donors.append(row)
    
    print(f"  Found {len(nc_donors)} NC donors")
    return nc_donors

def transform_to_donorsnew(fec_records: list) -> list:
    """Transform FEC records to donorsnew schema"""
    # Group by donor (name + zip)
    donor_groups = defaultdict(list)
    
    for record in fec_records:
        name_parts = parse_name(record.get('NAME', ''))
        zip_parts = parse_zip(record.get('ZIP_CODE', ''))
        
        key = generate_dedupe_key(
            name_parts['firstname'],
            name_parts['lastname'],
            zip_parts['zip5']
        )
        
        donor_groups[key].append(record)
    
    # Create donor records
    donors = []
    
    for dedupe_key, transactions in donor_groups.items():
        # Use first transaction for basic info
        first_tx = transactions[0]
        name_parts = parse_name(first_tx.get('NAME', ''))
        zip_parts = parse_zip(first_tx.get('ZIP_CODE', ''))
        
        # Calculate aggregates
        total_donated = sum(
            float(tx.get('TRANSACTION_AMT', 0)) 
            for tx in transactions
        )
        
        donation_dates = [
            datetime.strptime(tx.get('TRANSACTION_DT', ''), '%m%d%Y')
            for tx in transactions
            if tx.get('TRANSACTION_DT')
        ]
        
        first_donation = min(donation_dates) if donation_dates else None
        last_donation = max(donation_dates) if donation_dates else None
        
        # Build donor record
        donor = {
            'firstname': name_parts['firstname'],
            'middlename': name_parts['middlename'],
            'lastname': name_parts['lastname'],
            'suffix': name_parts['suffix'],
            'fullnameformal': first_tx.get('NAME', ''),
            'namevariants': generate_name_variants(
                name_parts['firstname'],
                name_parts['middlename'],
                name_parts['lastname']
            ),
            'homecity': first_tx.get('CITY', ''),
            'homestate': 'NC',
            'homezip5': zip_parts['zip5'],
            'homezip4': zip_parts['zip4'],
            'homezip9': zip_parts['zip9'],
            'employer1name': first_tx.get('EMPLOYER', ''),
            'occupation': first_tx.get('OCCUPATION', ''),
            'totaldonatedfederal': total_donated,
            'totaldonatedall': total_donated,
            'firstdonationdate': first_donation.isoformat() if first_donation else None,
            'lastdonationdate': last_donation.isoformat() if last_donation else None,
            'donationcount': len(transactions),
            'largestdonation': max(
                float(tx.get('TRANSACTION_AMT', 0)) 
                for tx in transactions
            ),
            'avgdonation': total_donated / len(transactions) if transactions else 0,
            'isdonor': True,
            'sourcefec': True,
            'rawfec': json.dumps(transactions[:10]),  # Store first 10 transactions
            'dedupekeynamezip': dedupe_key,
            'createdat': datetime.now().isoformat(),
            'updatedat': datetime.now().isoformat()
        }
        
        # Add year-by-year totals
        for tx in transactions:
            tx_date = tx.get('TRANSACTION_DT', '')
            if tx_date:
                year = datetime.strptime(tx_date, '%m%d%Y').year
                year_field = f'donated{year}'
                if year_field not in donor:
                    donor[year_field] = 0
                donor[year_field] += float(tx.get('TRANSACTION_AMT', 0))
        
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
    print("FEC Donor Data Processor for BroyhillGOP")
    print("="*60)
    
    # Find ZIP files
    zip_files = find_fec_zip_files()
    print(f"\nFound {len(zip_files)} FEC ZIP files:")
    for zf in zip_files:
        print(f"  - {zf.name}")
    
    if not zip_files:
        print("\nNo FEC ZIP files found in Downloads folder.")
        return
    
    # Initialize Supabase
    print("\nConnecting to Supabase...")
    supabase = init_supabase()
    
    # Process each ZIP file
    all_nc_donors = []
    
    for zip_file in zip_files:
        nc_donors = process_zip_file(zip_file)
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
    print(f"Processed {len(zip_files)} files")
    print(f"Found {len(all_nc_donors)} NC transactions")
    print(f"Created {len(donors)} unique donor records")
    print("="*60)

if __name__ == '__main__':
    main()
