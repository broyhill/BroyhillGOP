#!/usr/bin/env python3
"""
Geocodio Address Enrichment for BroyhillGOP
Adds ZIP+4, Congressional Districts, State Legislative Districts, FIPS codes

PRICING:
- FREE: 2,500 lookups/day
- Pay-as-you-go: $0.50 per 1,000 after free tier
- 111K records = ~$55 total (or 45 days free)

SETUP:
1. Go to https://dash.geocod.io/register
2. Create free account (no credit card needed)
3. Get API key from dashboard
4. export GEOCODIO_API_KEY='your_api_key'

DATA RETURNED:
- ZIP+4 (zip9)
- County FIPS code
- Congressional district
- State Senate district  
- State House district
- Lat/Long coordinates
- Accuracy score
"""

import os
import sys
import json
import time
import csv
import requests
from datetime import datetime

# Configuration
GEOCODIO_API_URL = 'https://api.geocod.io/v1.9'
BATCH_SIZE = 1000  # Max 10,000 per batch request
RATE_LIMIT_DELAY = 1  # seconds between batches
OUTPUT_DIR = '/opt/broyhillgop/data/geocodio'

# Database connection
DB_CONFIG = {
    'host': 'aws-0-us-east-1.pooler.supabase.com',
    'port': 6543,
    'dbname': 'postgres',
    'user': 'postgres.slkbmwfpxgdcriqqsome',
    'password': 'ChairMan2024!$@!'
}


class GeocodioEnricher:
    def __init__(self):
        self.api_key = os.environ.get('GEOCODIO_API_KEY')
        if not self.api_key:
            print("ERROR: Set GEOCODIO_API_KEY environment variable")
            print("Get free API key at: https://dash.geocod.io/register")
            sys.exit(1)
        
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        self.stats = {'processed': 0, 'success': 0, 'failed': 0}
    
    def geocode_single(self, street, city, state, zip5):
        """Geocode a single address"""
        address = f"{street}, {city}, {state} {zip5}"
        
        # Fields to append - these are the political districts we need
        fields = 'cd,stateleg,census2020'
        
        response = requests.get(
            f"{GEOCODIO_API_URL}/geocode",
            params={
                'q': address,
                'api_key': self.api_key,
                'fields': fields
            }
        )
        
        if response.status_code != 200:
            return {'error': response.text, 'status': response.status_code}
        
        return response.json()
    
    def geocode_batch(self, addresses):
        """
        Geocode batch of addresses (up to 10,000)
        addresses: list of address strings
        """
        fields = 'cd,stateleg,census2020'
        
        response = requests.post(
            f"{GEOCODIO_API_URL}/geocode",
            params={
                'api_key': self.api_key,
                'fields': fields
            },
            json=addresses
        )
        
        if response.status_code != 200:
            return {'error': response.text, 'status': response.status_code}
        
        return response.json()
    
    def parse_result(self, result):
        """Extract enrichment data from Geocodio result"""
        if not result.get('results'):
            return None
        
        best = result['results'][0]
        addr = best.get('address_components', {})
        fields = best.get('fields', {})
        location = best.get('location', {})
        
        # Extract congressional district
        cd = fields.get('congressional_districts', [{}])
        cd_info = cd[0] if cd else {}
        
        # Extract state legislative districts
        state_leg = fields.get('state_legislative_districts', {})
        senate = state_leg.get('senate', [{}])
        house = state_leg.get('house', [{}])
        senate_info = senate[0] if senate else {}
        house_info = house[0] if house else {}
        
        # Extract census data
        census = fields.get('census', {}).get('2020', {}).get('census_tract', {})
        
        return {
            'zip_plus4': addr.get('suffix', ''),  # ZIP+4 suffix
            'zip9': f"{addr.get('zip', '')}-{addr.get('suffix', '')}" if addr.get('suffix') else addr.get('zip', ''),
            'county_fips': addr.get('county_fips', ''),
            'latitude': location.get('lat'),
            'longitude': location.get('lng'),
            'accuracy': best.get('accuracy'),
            'accuracy_type': best.get('accuracy_type'),
            'congressional_district': cd_info.get('district_number'),
            'state_senate_district': senate_info.get('district_number'),
            'state_house_district': house_info.get('district_number'),
            'census_tract': census.get('code', '')
        }
    
    def test_single(self):
        """Test with sample address"""
        print("Testing Geocodio API...")
        result = self.geocode_single(
            '525 N Hawthorne Rd',
            'Winston-Salem',
            'NC',
            '27104'
        )
        print(json.dumps(result, indent=2))
        
        if result.get('results'):
            parsed = self.parse_result(result)
            print("\nParsed enrichment data:")
            print(json.dumps(parsed, indent=2))
        
        return result
    
    def export_donors_for_geocoding(self, limit=None, offset=0):
        """Export donor addresses to CSV for batch geocoding"""
        import psycopg2
        
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        # Get addresses needing enrichment
        query = """
            SELECT id, street_address, city, state, zip_code
            FROM donors
            WHERE street_address IS NOT NULL 
              AND street_address != ''
              AND city IS NOT NULL
              AND state IS NOT NULL
              AND (zip_plus4 IS NULL OR zip_plus4 = '')
            ORDER BY id
        """
        if limit:
            query += f" LIMIT {limit} OFFSET {offset}"
        
        cur.execute(query)
        rows = cur.fetchall()
        
        # Write to CSV
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        csv_path = f"{OUTPUT_DIR}/donors_to_geocode_{timestamp}.csv"
        
        with open(csv_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['id', 'street_address', 'city', 'state', 'zip_code', 'full_address'])
            for row in rows:
                id, street, city, state, zip5 = row
                full_address = f"{street}, {city}, {state} {zip5}"
                writer.writerow([id, street, city, state, zip5, full_address])
        
        conn.close()
        print(f"Exported {len(rows)} addresses to {csv_path}")
        return csv_path, len(rows)
    
    def process_batch_from_csv(self, csv_path, output_path=None):
        """Process exported CSV through Geocodio batch API"""
        if not output_path:
            output_path = csv_path.replace('.csv', '_enriched.csv')
        
        # Read addresses
        addresses = {}
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                addresses[row['id']] = row['full_address']
        
        print(f"Processing {len(addresses)} addresses...")
        
        # Process in batches
        ids = list(addresses.keys())
        results = {}
        
        for i in range(0, len(ids), BATCH_SIZE):
            batch_ids = ids[i:i+BATCH_SIZE]
            batch_addresses = [addresses[id] for id in batch_ids]
            
            print(f"  Batch {i//BATCH_SIZE + 1}: {len(batch_addresses)} addresses...")
            
            response = self.geocode_batch(batch_addresses)
            
            if 'error' in response:
                print(f"    ERROR: {response['error']}")
                continue
            
            # Map results back to IDs
            batch_results = response.get('results', [])
            for j, result in enumerate(batch_results):
                donor_id = batch_ids[j]
                parsed = self.parse_result(result.get('response', {}))
                if parsed:
                    results[donor_id] = parsed
                    self.stats['success'] += 1
                else:
                    self.stats['failed'] += 1
                self.stats['processed'] += 1
            
            time.sleep(RATE_LIMIT_DELAY)
        
        # Write enriched CSV
        with open(output_path, 'w', newline='') as f:
            fieldnames = ['id', 'zip_plus4', 'zip9', 'county_fips', 'latitude', 'longitude',
                         'accuracy', 'accuracy_type', 'congressional_district', 
                         'state_senate_district', 'state_house_district', 'census_tract']
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for donor_id, data in results.items():
                row = {'id': donor_id}
                row.update(data)
                writer.writerow(row)
        
        print(f"\nResults saved to {output_path}")
        print(f"Stats: {self.stats}")
        return output_path
    
    def update_database(self, enriched_csv_path):
        """Update donors table with enriched data"""
        import psycopg2
        from psycopg2.extras import execute_batch
        
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        updates = []
        with open(enriched_csv_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                updates.append((
                    row['zip_plus4'] or None,
                    row['zip9'] or None,
                    row['county_fips'] or None,
                    float(row['latitude']) if row['latitude'] else None,
                    float(row['longitude']) if row['longitude'] else None,
                    row['accuracy_type'] or None,
                    row['congressional_district'] or None,
                    row['state_senate_district'] or None,
                    row['state_house_district'] or None,
                    row['id']
                ))
        
        print(f"Updating {len(updates)} records in database...")
        
        execute_batch(cur, """
            UPDATE donors SET
                zip_plus4 = %s,
                zip9 = %s,
                county_fips = %s,
                latitude = %s,
                longitude = %s,
                geocode_accuracy = %s,
                congressional_district = %s,
                state_senate_district = %s,
                state_house_district = %s,
                address_validated = TRUE,
                updated_at = NOW()
            WHERE id = %s
        """, updates)
        
        conn.commit()
        conn.close()
        print("Database updated successfully!")


def main():
    if len(sys.argv) < 2:
        print("""
Geocodio Address Enrichment Tool

Usage:
  python3 geocodio_enrichment.py test              # Test single address
  python3 geocodio_enrichment.py export [limit]    # Export donors to CSV
  python3 geocodio_enrichment.py process <csv>     # Process CSV through API
  python3 geocodio_enrichment.py update <csv>      # Update database from enriched CSV
  python3 geocodio_enrichment.py full [limit]      # Full pipeline: export, process, update

Examples:
  python3 geocodio_enrichment.py test
  python3 geocodio_enrichment.py export 1000       # Export first 1000 donors
  python3 geocodio_enrichment.py full 2500         # Process 2500 (free daily limit)
        """)
        return
    
    enricher = GeocodioEnricher()
    command = sys.argv[1]
    
    if command == 'test':
        enricher.test_single()
    
    elif command == 'export':
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else None
        enricher.export_donors_for_geocoding(limit)
    
    elif command == 'process':
        csv_path = sys.argv[2]
        enricher.process_batch_from_csv(csv_path)
    
    elif command == 'update':
        csv_path = sys.argv[2]
        enricher.update_database(csv_path)
    
    elif command == 'full':
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 2500
        print(f"Running full pipeline for {limit} addresses...")
        
        # Export
        csv_path, count = enricher.export_donors_for_geocoding(limit)
        
        # Process
        enriched_path = enricher.process_batch_from_csv(csv_path)
        
        # Update
        enricher.update_database(enriched_path)
        
        print("\nPipeline complete!")


if __name__ == '__main__':
    main()
