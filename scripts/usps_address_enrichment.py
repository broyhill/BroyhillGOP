#!/usr/bin/env python3
"""
USPS Address Enrichment for BroyhillGOP
Validates addresses and adds ZIP+4 using USPS Address Standardization API

SETUP REQUIRED:
1. Register at https://www.usps.com/business/web-tools-apis/
2. Create account at Business Customer Gateway
3. Go to https://developers.usps.com/
4. Create an App to get Consumer Key + Consumer Secret
5. Set environment variables:
   export USPS_CLIENT_ID='your_consumer_key'
   export USPS_CLIENT_SECRET='your_consumer_secret'
"""

import os
import json
import time
import requests
from datetime import datetime
import psycopg2
from psycopg2.extras import execute_batch

# Configuration
USPS_OAUTH_URL = 'https://apis.usps.com/oauth2/v3/token'
USPS_ADDRESS_URL = 'https://apis.usps.com/addresses/v3/address'
BATCH_SIZE = 100
RATE_LIMIT_PER_HOUR = 60  # Default quota, request increase for batch

# Database connection
DB_HOST = 'aws-0-us-east-1.pooler.supabase.com'
DB_PORT = 6543
DB_NAME = 'postgres'
DB_USER = 'postgres.isbgjpnbocdkeslofota'
DB_PASS = 'Br0yh1ll2024!'

class USPSAddressEnricher:
    def __init__(self):
        self.client_id = os.environ.get('USPS_CLIENT_ID')
        self.client_secret = os.environ.get('USPS_CLIENT_SECRET')
        self.access_token = None
        self.token_expiry = 0
        
        if not self.client_id or not self.client_secret:
            print("ERROR: Set USPS_CLIENT_ID and USPS_CLIENT_SECRET environment variables")
            print("See registration instructions at top of this file")
            exit(1)
    
    def get_access_token(self):
        """Get OAuth 2.0 access token from USPS"""
        if self.access_token and time.time() < self.token_expiry - 60:
            return self.access_token
        
        response = requests.post(
            USPS_OAUTH_URL,
            headers={'Content-Type': 'application/json'},
            json={
                'client_id': self.client_id,
                'client_secret': self.client_secret,
                'grant_type': 'client_credentials'
            }
        )
        
        if response.status_code != 200:
            print(f"OAuth Error: {response.status_code} - {response.text}")
            return None
        
        data = response.json()
        self.access_token = data['access_token']
        self.token_expiry = time.time() + int(data.get('expires_in', 3600))
        print(f"Got access token, expires in {data.get('expires_in', 3600)} seconds")
        return self.access_token
    
    def validate_address(self, street, city, state, zip5):
        """Validate single address and get ZIP+4"""
        token = self.get_access_token()
        if not token:
            return None
        
        params = {
            'streetAddress': street,
            'city': city,
            'state': state,
            'ZIPCode': zip5
        }
        
        response = requests.get(
            USPS_ADDRESS_URL,
            headers={
                'Authorization': f'Bearer {token}',
                'Accept': 'application/json'
            },
            params=params
        )
        
        if response.status_code != 200:
            return {'error': response.text, 'status': response.status_code}
        
        return response.json()
    
    def process_batch_from_db(self, limit=100, offset=0):
        """Process addresses from donors table"""
        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
            user=DB_USER, password=DB_PASS
        )
        
        try:
            cur = conn.cursor()
            
            # Get addresses needing enrichment (have address, no ZIP+4)
            cur.execute("""
                SELECT id, street_address, city, state, zip_code
                FROM donors
                WHERE street_address IS NOT NULL 
                  AND street_address != ''
                  AND city IS NOT NULL
                  AND state IS NOT NULL
                  AND zip_code IS NOT NULL
                  AND LENGTH(zip_code) = 5
                  AND (zip_plus4 IS NULL OR zip_plus4 = '')
                ORDER BY id
                LIMIT %s OFFSET %s
            """, (limit, offset))
            
            rows = cur.fetchall()
            print(f"Processing {len(rows)} addresses...")
            
            updates = []
            for row in rows:
                donor_id, street, city, state, zip5 = row
                
                result = self.validate_address(street, city, state, zip5)
                
                if result and 'address' in result:
                    addr = result['address']
                    zip_plus4 = addr.get('ZIPPlus4')
                    std_street = addr.get('streetAddress')
                    std_city = addr.get('city')
                    
                    if zip_plus4:
                        updates.append((
                            zip_plus4,
                            std_street or street,
                            std_city or city,
                            True,  # address_validated
                            donor_id
                        ))
                        print(f"  ✓ {donor_id}: {zip5}-{zip_plus4}")
                    else:
                        print(f"  ? {donor_id}: No ZIP+4 returned")
                else:
                    print(f"  ✗ {donor_id}: {result.get('error', 'Unknown error')}")
                
                # Rate limiting - 60 per hour = 1 per minute
                time.sleep(60)  # Adjust based on your quota
            
            # Update database
            if updates:
                execute_batch(cur, """
                    UPDATE donors SET
                        zip_plus4 = %s,
                        street_address = %s,
                        city = %s,
                        address_validated = %s,
                        updated_at = NOW()
                    WHERE id = %s
                """, updates)
                conn.commit()
                print(f"Updated {len(updates)} records")
            
        finally:
            conn.close()
    
    def test_single_address(self):
        """Test with Eddie's address"""
        print("Testing USPS API with sample address...")
        result = self.validate_address(
            '525 N Hawthorne Rd',
            'Winston-Salem',
            'NC',
            '27104'
        )
        print(json.dumps(result, indent=2))
        return result


if __name__ == '__main__':
    import sys
    
    enricher = USPSAddressEnricher()
    
    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        enricher.test_single_address()
    elif len(sys.argv) > 1 and sys.argv[1] == 'run':
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 100
        offset = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        enricher.process_batch_from_db(limit, offset)
    else:
        print("Usage:")
        print("  python3 usps_address_enrichment.py test     # Test single address")
        print("  python3 usps_address_enrichment.py run 100 0  # Process 100 from offset 0")
