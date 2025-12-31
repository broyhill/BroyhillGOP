#!/usr/bin/env python3
"""
DATATRUST API CLIENT
BroyhillGOP Platform - E00 DataHub Integration

Connects to GOP Data Trust API to pull voter data for NC.
Uses OAuth2 client credentials flow.

CONFIGURATION:
Set environment variables:
  DATATRUST_CLIENT_ID
  DATATRUST_CLIENT_SECRET
  SUPABASE_ANON_KEY

Author: BroyhillGOP Platform
Created: December 30, 2024
"""

import os
import json
import time
import logging
import requests
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, field

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('datatrust_api')


@dataclass
class DatatrustConfig:
    """Configuration for Datatrust API connection"""
    # Load from environment variables
    client_id: str = field(default_factory=lambda: os.environ.get("DATATRUST_CLIENT_ID", ""))
    client_secret: str = field(default_factory=lambda: os.environ.get("DATATRUST_CLIENT_SECRET", ""))
    
    # API Endpoints - Try production first, fall back to test
    token_url: str = "https://api.gopdatatrust.com/oauth/token"
    api_base_url: str = "https://api.gopdatatrust.com/v2"
    
    # Alternative endpoints
    lincoln_token_url: str = "https://lincoln.gopdatatrust.com/oauth/token"
    lincoln_api_url: str = "https://lincoln.gopdatatrust.com/v2"
    
    # State filter
    state: str = "NC"
    
    # Rate limiting
    requests_per_minute: int = 60
    batch_size: int = 1000


class DatatrustAPIClient:
    """
    Client for GOP Data Trust Direct API
    
    Handles:
    - OAuth2 authentication
    - Voter data queries
    - Batch downloads
    - Rate limiting
    
    Usage:
        # Set environment variables first:
        # export DATATRUST_CLIENT_ID="your-client-id"
        # export DATATRUST_CLIENT_SECRET="your-client-secret"
        
        client = DatatrustAPIClient()
        if client.authenticate():
            voters = client.search_voters(state="NC", county="Wake", limit=100)
    """
    
    def __init__(self, config: Optional[DatatrustConfig] = None):
        self.config = config or DatatrustConfig()
        self.access_token: Optional[str] = None
        self.token_expires_at: Optional[datetime] = None
        self.session = requests.Session()
        self._last_request_time = 0
        
        # Validate configuration
        if not self.config.client_id or not self.config.client_secret:
            logger.warning(
                "Datatrust credentials not configured. "
                "Set DATATRUST_CLIENT_ID and DATATRUST_CLIENT_SECRET environment variables."
            )
        
    def _rate_limit(self):
        """Enforce rate limiting"""
        min_interval = 60.0 / self.config.requests_per_minute
        elapsed = time.time() - self._last_request_time
        if elapsed < min_interval:
            time.sleep(min_interval - elapsed)
        self._last_request_time = time.time()
    
    def authenticate(self) -> bool:
        """
        Authenticate with Datatrust API using OAuth2 client credentials
        
        Returns:
            bool: True if authentication successful
        """
        if not self.config.client_id or not self.config.client_secret:
            logger.error("Client credentials not configured")
            return False
            
        logger.info("Authenticating with Datatrust API...")
        
        # Try different token endpoints
        endpoints = [
            self.config.token_url,
            self.config.lincoln_token_url,
            f"{self.config.api_base_url}/oauth/token",
        ]
        
        for endpoint in endpoints:
            try:
                logger.info(f"Trying token endpoint: {endpoint}")
                
                response = self.session.post(
                    endpoint,
                    data={
                        "grant_type": "client_credentials",
                        "client_id": self.config.client_id,
                        "client_secret": self.config.client_secret,
                        "scope": "api://datatrust/.default"
                    },
                    headers={"Content-Type": "application/x-www-form-urlencoded"},
                    timeout=30
                )
                
                if response.status_code == 200:
                    token_data = response.json()
                    self.access_token = token_data.get("access_token")
                    expires_in = token_data.get("expires_in", 3600)
                    self.token_expires_at = datetime.now() + timedelta(seconds=expires_in)
                    
                    logger.info(f"✅ Authentication successful! Token expires in {expires_in}s")
                    return True
                else:
                    logger.warning(f"Auth failed at {endpoint}: {response.status_code} - {response.text[:200]}")
                    
            except requests.exceptions.RequestException as e:
                logger.warning(f"Connection error at {endpoint}: {str(e)[:100]}")
                continue
        
        logger.error("❌ All authentication attempts failed")
        return False
    
    def _ensure_authenticated(self):
        """Ensure we have a valid access token"""
        if not self.access_token or (self.token_expires_at and datetime.now() >= self.token_expires_at):
            if not self.authenticate():
                raise Exception("Failed to authenticate with Datatrust API")
    
    def _make_request(self, method: str, endpoint: str, **kwargs) -> Dict:
        """Make an authenticated API request"""
        self._ensure_authenticated()
        self._rate_limit()
        
        url = f"{self.config.api_base_url}/{endpoint}"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        
        response = self.session.request(
            method,
            url,
            headers=headers,
            timeout=60,
            **kwargs
        )
        
        response.raise_for_status()
        return response.json()
    
    def get_voter_by_rnc_id(self, rnc_id: str) -> Optional[Dict]:
        """
        Get a single voter by RNC ID
        
        Args:
            rnc_id: The RNC's unique voter identifier
            
        Returns:
            Voter data dictionary or None
        """
        try:
            return self._make_request("GET", f"voter/{rnc_id}")
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                return None
            raise
    
    def search_voters(
        self,
        state: str = "NC",
        county: Optional[str] = None,
        last_name: Optional[str] = None,
        first_name: Optional[str] = None,
        zip_code: Optional[str] = None,
        party: Optional[str] = None,
        limit: int = 100,
        offset: int = 0
    ) -> Dict:
        """
        Search for voters with filters
        
        Args:
            state: State code (default: NC)
            county: County name filter
            last_name: Last name filter
            first_name: First name filter
            zip_code: ZIP code filter
            party: Party affiliation filter (R, D, U, L)
            limit: Max results per page
            offset: Pagination offset
            
        Returns:
            Search results with voters array and pagination info
        """
        params = {
            "state": state,
            "limit": limit,
            "offset": offset
        }
        
        if county:
            params["county"] = county
        if last_name:
            params["lastName"] = last_name
        if first_name:
            params["firstName"] = first_name
        if zip_code:
            params["zip"] = zip_code
        if party:
            params["party"] = party
            
        return self._make_request("GET", "voters/search", params=params)
    
    def get_county_voters(
        self,
        county: str,
        state: str = "NC",
        batch_size: int = 1000
    ) -> List[Dict]:
        """
        Get all voters for a county (with pagination)
        
        Args:
            county: County name
            state: State code
            batch_size: Records per batch
            
        Yields:
            Voter data dictionaries
        """
        offset = 0
        total_retrieved = 0
        
        while True:
            logger.info(f"Fetching {county} county voters: offset={offset}")
            
            result = self.search_voters(
                state=state,
                county=county,
                limit=batch_size,
                offset=offset
            )
            
            voters = result.get("voters", [])
            if not voters:
                break
                
            for voter in voters:
                yield voter
                total_retrieved += 1
            
            # Check if more pages
            total = result.get("total", 0)
            if offset + len(voters) >= total:
                break
                
            offset += batch_size
        
        logger.info(f"Retrieved {total_retrieved} voters from {county} county")
    
    def get_all_nc_voters(self, batch_callback=None) -> int:
        """
        Download ALL NC voters (7.8 million+)
        
        Args:
            batch_callback: Function to call with each batch of voters
            
        Returns:
            Total voters downloaded
        """
        nc_counties = [
            "Alamance", "Alexander", "Alleghany", "Anson", "Ashe", "Avery",
            "Beaufort", "Bertie", "Bladen", "Brunswick", "Buncombe", "Burke",
            "Cabarrus", "Caldwell", "Camden", "Carteret", "Caswell", "Catawba",
            "Chatham", "Cherokee", "Chowan", "Clay", "Cleveland", "Columbus",
            "Craven", "Cumberland", "Currituck", "Dare", "Davidson", "Davie",
            "Duplin", "Durham", "Edgecombe", "Forsyth", "Franklin", "Gaston",
            "Gates", "Graham", "Granville", "Greene", "Guilford", "Halifax",
            "Harnett", "Haywood", "Henderson", "Hertford", "Hoke", "Hyde",
            "Iredell", "Jackson", "Johnston", "Jones", "Lee", "Lenoir",
            "Lincoln", "Macon", "Madison", "Martin", "McDowell", "Mecklenburg",
            "Mitchell", "Montgomery", "Moore", "Nash", "New Hanover", "Northampton",
            "Onslow", "Orange", "Pamlico", "Pasquotank", "Pender", "Perquimans",
            "Person", "Pitt", "Polk", "Randolph", "Richmond", "Robeson",
            "Rockingham", "Rowan", "Rutherford", "Sampson", "Scotland", "Stanly",
            "Stokes", "Surry", "Swain", "Transylvania", "Tyrrell", "Union",
            "Vance", "Wake", "Warren", "Washington", "Watauga", "Wayne",
            "Wilkes", "Wilson", "Yadkin", "Yancey"
        ]
        
        total = 0
        for county in nc_counties:
            logger.info(f"Processing {county} county...")
            batch = []
            
            for voter in self.get_county_voters(county):
                batch.append(voter)
                
                if len(batch) >= self.config.batch_size:
                    if batch_callback:
                        batch_callback(batch)
                    total += len(batch)
                    batch = []
            
            # Process remaining batch
            if batch:
                if batch_callback:
                    batch_callback(batch)
                total += len(batch)
        
        logger.info(f"✅ Downloaded {total:,} NC voters")
        return total
    
    def get_available_fields(self) -> List[str]:
        """Get list of available data fields from API"""
        try:
            result = self._make_request("GET", "fields")
            return result.get("fields", [])
        except Exception as e:
            logger.error(f"Failed to get fields: {e}")
            return []
    
    def health_check(self) -> Dict:
        """Check API health and connection status"""
        result = {
            "authenticated": False,
            "api_reachable": False,
            "token_valid": False,
            "credentials_configured": bool(self.config.client_id and self.config.client_secret),
            "timestamp": datetime.now().isoformat()
        }
        
        if not result["credentials_configured"]:
            result["error"] = "Credentials not configured. Set DATATRUST_CLIENT_ID and DATATRUST_CLIENT_SECRET"
            return result
        
        try:
            if self.authenticate():
                result["authenticated"] = True
                result["token_valid"] = True
                
                # Try a simple query
                test = self.search_voters(state="NC", limit=1)
                if test:
                    result["api_reachable"] = True
                    result["sample_total"] = test.get("total", 0)
                    
        except Exception as e:
            result["error"] = str(e)
        
        return result


# ============================================================================
# SUPABASE INTEGRATION
# ============================================================================

class DatatrustSupabaseSync:
    """
    Syncs Datatrust data to Supabase database
    """
    
    def __init__(
        self,
        datatrust_client: DatatrustAPIClient,
        supabase_url: str = "https://isbgjpnbocdkeslofota.supabase.co",
        supabase_key: str = None
    ):
        self.dt = datatrust_client
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key or os.environ.get("SUPABASE_ANON_KEY")
        self.session = requests.Session()
    
    def _supabase_request(self, method: str, table: str, data=None, params=None):
        """Make Supabase REST API request"""
        url = f"{self.supabase_url}/rest/v1/{table}"
        headers = {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal"
        }
        
        response = self.session.request(
            method,
            url,
            headers=headers,
            json=data,
            params=params,
            timeout=60
        )
        response.raise_for_status()
        return response
    
    def upsert_voters(self, voters: List[Dict]):
        """
        Insert or update voters in datatrust_profiles table
        
        Args:
            voters: List of voter dictionaries from API
        """
        # Map API fields to database columns
        records = []
        for voter in voters:
            record = self._map_voter_to_record(voter)
            records.append(record)
        
        # Upsert to Supabase
        self._supabase_request(
            "POST",
            "datatrust_profiles",
            data=records,
            params={"on_conflict": "rnc_id"}
        )
        
        logger.info(f"Upserted {len(records)} voter records")
    
    def _map_voter_to_record(self, voter: Dict) -> Dict:
        """Map API response to database schema"""
        return {
            "rnc_id": voter.get("RNID") or voter.get("rnc_id"),
            "first_name": voter.get("FirstName") or voter.get("first_name"),
            "middle_name": voter.get("MiddleName") or voter.get("middle_name"),
            "last_name": voter.get("LastName") or voter.get("last_name"),
            "name_suffix": voter.get("Suffix") or voter.get("name_suffix"),
            "date_of_birth": voter.get("DOB") or voter.get("date_of_birth"),
            
            # Address
            "home_street_number": voter.get("RegistrationAddrNum"),
            "home_street_name": voter.get("RegistrationAddrStreet"),
            "home_city": voter.get("RegistrationCity") or voter.get("home_city"),
            "home_county": voter.get("County") or voter.get("home_county"),
            "home_state": voter.get("State", "NC"),
            "home_zip": voter.get("RegistrationZip") or voter.get("home_zip"),
            
            # Registration
            "voter_registration_status": voter.get("VoterStatus", "active"),
            "registered_party_affiliation": voter.get("Party") or voter.get("registered_party"),
            
            # Contact
            "phone_primary": voter.get("Phone") or voter.get("phone_primary"),
            "phone_neustar": voter.get("NeustarPhone"),
            "email_primary": voter.get("Email") or voter.get("email_primary"),
            
            # Political scores
            "modeled_partisanship_score": voter.get("RNCCalcParty"),
            "turnout_likelihood_score": voter.get("TurnoutScore"),
            "voter_regularity_score": voter.get("VoterRegularity"),
            
            # Vote history
            "voted_pres_2024": voter.get("VH24G"),
            "voted_pres_2020": voter.get("VH20G"),
            "voted_general_2022": voter.get("VH22G"),
            
            # Districts
            "congressional_district_current": voter.get("CD"),
            "state_senate_district": voter.get("SD"),
            "state_house_district": voter.get("HD"),
            "precinct_code": voter.get("Precinct"),
            
            # Metadata
            "data_source": "datatrust_api",
            "last_api_sync": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
    
    def sync_county(self, county: str) -> int:
        """Sync all voters for a county"""
        count = 0
        batch = []
        
        for voter in self.dt.get_county_voters(county):
            batch.append(voter)
            
            if len(batch) >= 500:
                self.upsert_voters(batch)
                count += len(batch)
                batch = []
        
        if batch:
            self.upsert_voters(batch)
            count += len(batch)
        
        logger.info(f"Synced {count} voters from {county}")
        return count
    
    def run_full_sync(self):
        """Run full NC voter sync"""
        logger.info("Starting full NC voter sync...")
        total = self.dt.get_all_nc_voters(batch_callback=self.upsert_voters)
        logger.info(f"✅ Full sync complete: {total:,} voters")
        return total


# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """Command line interface for Datatrust API"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Datatrust API Client")
    parser.add_argument("command", choices=["health", "test", "sync", "fields"])
    parser.add_argument("--county", help="County to sync")
    parser.add_argument("--limit", type=int, default=10, help="Limit for test queries")
    
    args = parser.parse_args()
    
    client = DatatrustAPIClient()
    
    if args.command == "health":
        result = client.health_check()
        print(json.dumps(result, indent=2))
        
    elif args.command == "test":
        if client.authenticate():
            result = client.search_voters(state="NC", limit=args.limit)
            print(json.dumps(result, indent=2))
        else:
            print("Authentication failed")
            
    elif args.command == "fields":
        if client.authenticate():
            fields = client.get_available_fields()
            for field in fields:
                print(field)
        else:
            print("Authentication failed")
            
    elif args.command == "sync":
        supabase_key = os.environ.get("SUPABASE_ANON_KEY")
        if not supabase_key:
            print("Set SUPABASE_ANON_KEY environment variable")
            return
            
        sync = DatatrustSupabaseSync(client, supabase_key=supabase_key)
        
        if args.county:
            sync.sync_county(args.county)
        else:
            sync.run_full_sync()


if __name__ == "__main__":
    main()
