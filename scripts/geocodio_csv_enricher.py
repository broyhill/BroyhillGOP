#!/usr/bin/env python3
"""
Geocodio CSV Enricher - Standalone tool
No database needed - works with CSV files

Usage:
  python3 geocodio_csv_enricher.py input.csv output.csv

Input CSV needs columns: street_address, city, state, zip_code
Optional: id column (preserved in output)

Output adds: zip_plus4, county_fips, latitude, longitude, 
             congressional_district, state_senate, state_house, accuracy
"""

import os
import sys
import csv
import json
import time
import requests
from datetime import datetime

API_KEY = os.environ.get('GEOCODIO_API_KEY', '93e436663f16c1f6ed4cd5fd0696166d54c5d9f')
API_URL = 'https://api.geocod.io/v1.9/geocode'
BATCH_SIZE = 1000
FIELDS = 'cd,stateleg,census2020'

def geocode_batch(addresses):
    """Send batch of addresses to Geocodio"""
    response = requests.post(
        API_URL,
        params={'api_key': API_KEY, 'fields': FIELDS},
        json=addresses
    )
    if response.status_code != 200:
        print(f"  ERROR: {response.status_code} - {response.text[:200]}")
        return None
    return response.json()

def parse_result(result):
    """Extract useful fields from Geocodio result"""
    if not result or not result.get('results'):
        return {}
    
    best = result['results'][0]
    addr = best.get('address_components', {})
    fields = best.get('fields', {})
    location = best.get('location', {})
    
    # Congressional district
    cd_list = fields.get('congressional_districts', [])
    cd = cd_list[0].get('district_number') if cd_list else None
    
    # State legislative
    state_leg = fields.get('state_legislative_districts', {})
    senate_list = state_leg.get('senate', [])
    house_list = state_leg.get('house', [])
    senate = senate_list[0].get('district_number') if senate_list else None
    house = house_list[0].get('district_number') if house_list else None
    
    # Census
    census = fields.get('census', {}).get('2020', {})
    
    return {
        'zip_plus4': addr.get('suffix', ''),
        'county_fips': census.get('county_fips', ''),
        'latitude': location.get('lat'),
        'longitude': location.get('lng'),
        'accuracy': best.get('accuracy_type', ''),
        'congressional_district': cd,
        'state_senate': senate,
        'state_house': house,
        'census_tract': census.get('tract_code', ''),
        'metro_area': census.get('metro_micro_statistical_area', {}).get('name', '')
    }

def process_csv(input_path, output_path):
    """Process CSV file through Geocodio"""
    
    # Read input
    with open(input_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames
    
    print(f"Loaded {len(rows)} rows from {input_path}")
    
    # Build addresses
    addresses = []
    for row in rows:
        street = row.get('street_address') or row.get('address') or row.get('Address') or ''
        city = row.get('city') or row.get('City') or ''
        state = row.get('state') or row.get('State') or ''
        zip_code = row.get('zip_code') or row.get('zip') or row.get('Zip') or ''
        
        if street and city and state:
            addr = f"{street}, {city}, {state} {zip_code}".strip()
            addresses.append(addr)
        else:
            addresses.append('')
    
    # Process in batches
    results = []
    total_batches = (len(addresses) + BATCH_SIZE - 1) // BATCH_SIZE
    
    for i in range(0, len(addresses), BATCH_SIZE):
        batch = addresses[i:i+BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        print(f"Processing batch {batch_num}/{total_batches} ({len(batch)} addresses)...")
        
        # Filter out empty addresses for API call
        valid_indices = [j for j, a in enumerate(batch) if a]
        valid_addresses = [batch[j] for j in valid_indices]
        
        if valid_addresses:
            response = geocode_batch(valid_addresses)
            if response:
                batch_results = response.get('results', [])
                
                # Map results back
                result_idx = 0
                for j in range(len(batch)):
                    if j in valid_indices:
                        if result_idx < len(batch_results):
                            parsed = parse_result(batch_results[result_idx].get('response', {}))
                            results.append(parsed)
                        else:
                            results.append({})
                        result_idx += 1
                    else:
                        results.append({})
            else:
                results.extend([{} for _ in batch])
        else:
            results.extend([{} for _ in batch])
        
        time.sleep(1)  # Rate limiting
    
    # Output fields
    new_fields = ['zip_plus4', 'county_fips', 'latitude', 'longitude', 
                  'accuracy', 'congressional_district', 'state_senate', 
                  'state_house', 'census_tract', 'metro_area']
    output_fieldnames = list(fieldnames) + [f for f in new_fields if f not in fieldnames]
    
    # Write output
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=output_fieldnames)
        writer.writeheader()
        
        for row, enrichment in zip(rows, results):
            row.update(enrichment)
            writer.writerow(row)
    
    # Stats
    enriched = sum(1 for r in results if r.get('latitude'))
    print(f"\nComplete! Enriched {enriched}/{len(rows)} addresses")
    print(f"Output saved to: {output_path}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 geocodio_csv_enricher.py input.csv output.csv")
        print("\nInput CSV needs: street_address, city, state, zip_code columns")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    if not os.path.exists(input_file):
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)
    
    process_csv(input_file, output_file)
