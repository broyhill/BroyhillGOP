# ============================================================================
# ECOSYSTEM 50: CONTACT INTELLIGENCE ENGINE
# Enhancement Layer for BroyhillGOP Platform
# ============================================================================
#
# PURPOSE: This ecosystem EXTENDS existing systems (E15, E44) to add:
#   1. Apollo.io integration for HIGH-VALUE donors/volunteers only
#   2. BetterContact waterfall enrichment for phone/email verification
#   3. RNC DataTrust integration (FREE for Eddie)
#   4. Deceased detection via multiple sources
#   5. Continuous auto-update scheduling
#
# INTEGRATES WITH (already built):
#   - E15: Contact Directory (deceased status, household linking)
#   - E44: Social Intelligence (FREE enrichment sources)
#   - E0:  DataHub (master records)
#   - E20: Intelligence Brain (event triggers)
#
# NEW CAPABILITIES:
#   - Apollo API for B2B enrichment (high-value only)
#   - BetterContact waterfall (20+ providers)
#   - Deceased detection pipeline
#   - Quarterly auto-refresh scheduling
#
# ============================================================================

"""
============================================================================
WHAT E50 ADDS TO YOUR EXISTING PLATFORM
============================================================================

YOU ALREADY HAVE:
┌─────────────────────────────────────────────────────────────────────────────┐
│ E15 Contact Directory         │ E44 Social Intelligence                    │
│ ├─ Deceased status field      │ ├─ NC Voter File (FREE)                    │
│ ├─ Household linking          │ ├─ FEC API (FREE)                          │
│ ├─ Email/phone hashes         │ ├─ County GIS (FREE)                       │
│ └─ Verification history       │ └─ NC SoS (FREE)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ Family Linking SQL            │ Donor Merge Pipeline                       │
│ ├─ Spouse detection           │ ├─ Name parsing                            │
│ ├─ Address matching           │ ├─ Deduplication                           │
│ └─ Family networks            │ └─ Source tracking                         │
└─────────────────────────────────────────────────────────────────────────────┘

E50 ADDS:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   PAID ENRICHMENT (High-Value Only)         DECEASED DETECTION              │
│   ├─ Apollo.io (A++/A+ donors only)         ├─ NC DHHS Death Records       │
│   │   - 210M+ contacts                      ├─ Voter File Removals         │
│   │   - $0.20/credit                        ├─ Obituary Scraper            │
│   │   - 8 credits = 1 phone                 │   (Legacy.com, local papers) │
│   │   - Work emails, titles, companies      ├─ SSDI Public File            │
│   │                                         └─ Family notification          │
│   ├─ BetterContact Waterfall                                                │
│   │   - 20+ data providers                  SCHEDULING                      │
│   │   - $0.049/email found                  ├─ Daily: FEC, Deaths           │
│   │   - $0.49/phone found                   ├─ Weekly: NCBOE, Voter file    │
│   │   - Only pay for valid data             ├─ Monthly: Property records    │
│   │                                         └─ Quarterly: L2, Apollo        │
│   └─ RNC DataTrust (FREE for you!)                                          │
│       - Daily sync available                                                │
│       - Phones, emails, voter data                                          │
│       - Consumer overlays                                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

============================================================================
"""

import os
import json
import uuid
import logging
import hashlib
import asyncio
import aiohttp
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, field
from enum import Enum
from abc import ABC, abstractmethod
import psycopg2
from psycopg2.extras import RealDictCursor, execute_values

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem50.contact_intelligence')


# ============================================================================
# CONFIGURATION
# ============================================================================

class E50Config:
    """Configuration for Contact Intelligence Engine"""
    
    # Database (same as rest of platform)
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres.isbgjpnbocdkeslofofa:ChairM%40n2024%21@aws-0-us-east-1.pooler.supabase.com:6543/postgres")
    
    # Apollo.io API (for HIGH-VALUE donors only)
    # Pricing: $49/user/month (Basic), includes credits
    # 1 credit = 1 email, 8 credits = 1 phone
    APOLLO_API_KEY = os.getenv("APOLLO_API_KEY")
    APOLLO_API_URL = "https://api.apollo.io/v1"
    APOLLO_CREDITS_PER_PHONE = 8
    APOLLO_CREDITS_PER_EMAIL = 1
    
    # BetterContact API (waterfall enrichment)
    # Pricing: $49/month for 1000 credits
    # 1 credit = 1 email + verification
    # 10 credits = 1 phone + verification
    BETTERCONTACT_API_KEY = os.getenv("BETTERCONTACT_API_KEY")
    BETTERCONTACT_API_URL = "https://app.bettercontact.rocks/api/v2"
    
    # RNC DataTrust (FREE for Eddie!)
    RNC_DATAHUB_CLIENT_ID = os.getenv("RNC_DATAHUB_CLIENT_ID", "07264d72-5f06-4de1-81c0-26909ac136f2")
    RNC_DATAHUB_CLIENT_SECRET = os.getenv("RNC_DATAHUB_CLIENT_SECRET")
    RNC_API_URL = "https://rncdatahubapi.gop"
    RNC_SQL_SERVER = "rncazdwsql.cloudapp.net:52954"
    
    # Bandwidth (for phone verification)
    # You already have this from E32 Phone Banking
    BANDWIDTH_ACCOUNT_ID = os.getenv("BANDWIDTH_ACCOUNT_ID")
    BANDWIDTH_API_USER = os.getenv("BANDWIDTH_API_USER")
    BANDWIDTH_API_PASSWORD = os.getenv("BANDWIDTH_API_PASSWORD")
    
    # Which donors get PAID enrichment (Apollo/BetterContact)?
    # A++ through C- grades (top 10 tiers of donors)
    HIGH_VALUE_GRADES = [
        # Donor grades
        'A++', 'A+', 'A', 'A-', 
        'B+', 'B', 'B-', 
        'C+', 'C', 'C-',
        # Volunteer grades (same tiers)
        'V-A++', 'V-A+', 'V-A', 'V-A-',
        'V-B+', 'V-B', 'V-B-',
        'V-C+', 'V-C', 'V-C-'
    ]
    
    # Tiered enrichment strategy (cost optimization)
    # Tier 1: Full enrichment (Apollo + BetterContact)
    TIER_1_GRADES = ['A++', 'A+', 'A']
    # Tier 2: BetterContact only (cheaper, still good)
    TIER_2_GRADES = ['A-', 'B+', 'B']
    # Tier 3: BetterContact phone only (most cost-effective)
    TIER_3_GRADES = ['B-', 'C+', 'C', 'C-']
    
    # Deceased detection sources
    OBITUARY_SOURCES = [
        'https://www.legacy.com',
        'https://www.newspapers.com/obituaries',
        # Add NC local papers
    ]
    
    # Scheduling (cron expressions)
    SCHEDULE_RNC_SYNC = "0 2 * * *"        # Daily at 2 AM
    SCHEDULE_FEC_SCRAPE = "0 3 * * *"      # Daily at 3 AM
    SCHEDULE_NCBOE_SYNC = "0 4 * * 0"      # Weekly Sunday 4 AM
    SCHEDULE_DECEASED_CHECK = "0 5 * * *"  # Daily at 5 AM
    SCHEDULE_APOLLO_ENRICH = "0 6 1 */3 *" # Quarterly 1st at 6 AM
    SCHEDULE_BETTERCONTACT = "0 7 1 * *"   # Monthly 1st at 7 AM


# ============================================================================
# ENUMS
# ============================================================================

class EnrichmentSource(Enum):
    """Data sources for enrichment"""
    # FREE (from E44)
    RNC_DATATRUST = "rnc_datatrust"
    NC_VOTER_FILE = "nc_voter_file"
    FEC_API = "fec_api"
    NC_PROPERTY = "nc_property"
    NC_SOS = "nc_sos"
    
    # PAID (E50 new)
    APOLLO = "apollo"
    BETTERCONTACT = "bettercontact"
    L2 = "l2"
    
    # DECEASED
    NC_DHHS_DEATHS = "nc_dhhs_deaths"
    VOTER_FILE_REMOVED = "voter_file_removed"
    OBITUARY = "obituary"
    SSDI = "ssdi"
    FAMILY_REPORT = "family_report"


class VerificationStatus(Enum):
    """Phone/email verification status"""
    UNVERIFIED = "unverified"
    VALID = "valid"
    INVALID = "invalid"
    RISKY = "risky"
    CATCH_ALL = "catch_all"
    DISCONNECTED = "disconnected"
    DO_NOT_CALL = "do_not_call"


class PhoneType(Enum):
    """Phone line types"""
    MOBILE = "mobile"
    LANDLINE = "landline"
    VOIP = "voip"
    TOLL_FREE = "toll_free"
    UNKNOWN = "unknown"


# ============================================================================
# DATABASE SCHEMA (Additions to existing tables)
# ============================================================================

E50_SCHEMA_ADDITIONS = """
-- ============================================================================
-- ECOSYSTEM 50: CONTACT INTELLIGENCE ENGINE
-- Schema additions to existing platform
-- ============================================================================

-- Add columns to existing donors table (if not exists)
ALTER TABLE broyhillgop.donors 
    ADD COLUMN IF NOT EXISTS cell_phone VARCHAR(20),
    ADD COLUMN IF NOT EXISTS cell_phone_verified BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS cell_phone_type VARCHAR(20),
    ADD COLUMN IF NOT EXISTS cell_phone_carrier VARCHAR(100),
    ADD COLUMN IF NOT EXISTS cell_phone_confidence INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cell_phone_last_verified TIMESTAMP,
    ADD COLUMN IF NOT EXISTS cell_phone_sources TEXT[] DEFAULT '{}',
    
    ADD COLUMN IF NOT EXISTS home_phone VARCHAR(20),
    ADD COLUMN IF NOT EXISTS home_phone_verified BOOLEAN DEFAULT false,
    
    ADD COLUMN IF NOT EXISTS work_phone VARCHAR(20),
    ADD COLUMN IF NOT EXISTS work_phone_ext VARCHAR(10),
    ADD COLUMN IF NOT EXISTS work_phone_verified BOOLEAN DEFAULT false,
    
    ADD COLUMN IF NOT EXISTS personal_email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS personal_email_verified BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS personal_email_status VARCHAR(20),
    ADD COLUMN IF NOT EXISTS personal_email_last_verified TIMESTAMP,
    
    ADD COLUMN IF NOT EXISTS work_email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS work_email_verified BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS work_email_status VARCHAR(20),
    
    ADD COLUMN IF NOT EXISTS deceased_status VARCHAR(20) DEFAULT 'unknown',
    ADD COLUMN IF NOT EXISTS deceased_date DATE,
    ADD COLUMN IF NOT EXISTS deceased_source VARCHAR(50),
    ADD COLUMN IF NOT EXISTS deceased_detected_at TIMESTAMP,
    
    ADD COLUMN IF NOT EXISTS last_enrichment_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS enrichment_sources TEXT[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS data_quality_score INTEGER DEFAULT 0;

-- Phone records table (multiple phones per donor)
CREATE TABLE IF NOT EXISTS e50_donor_phones (
    phone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL REFERENCES broyhillgop.donors(id) ON DELETE CASCADE,
    
    phone_number VARCHAR(20) NOT NULL,
    phone_e164 VARCHAR(20),  -- +1xxxxxxxxxx format
    phone_type VARCHAR(20) DEFAULT 'unknown',
    phone_label VARCHAR(20) DEFAULT 'primary',  -- primary, home, work, mobile
    
    carrier VARCHAR(100),
    carrier_type VARCHAR(20),  -- wireless, landline, voip
    
    -- Verification
    is_verified BOOLEAN DEFAULT false,
    verification_status VARCHAR(20) DEFAULT 'unverified',
    confidence_score INTEGER DEFAULT 50 CHECK (confidence_score BETWEEN 0 AND 100),
    last_verified_at TIMESTAMP,
    verification_method VARCHAR(50),
    
    -- Source tracking
    sources TEXT[] DEFAULT '{}',
    source_count INTEGER DEFAULT 1,
    first_seen_at TIMESTAMP DEFAULT NOW(),
    last_seen_at TIMESTAMP DEFAULT NOW(),
    
    -- Usage stats
    call_attempts INTEGER DEFAULT 0,
    successful_contacts INTEGER DEFAULT 0,
    last_successful_contact TIMESTAMP,
    do_not_call BOOLEAN DEFAULT false,
    dnc_reason VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, phone_number)
);

CREATE INDEX IF NOT EXISTS idx_e50_phones_donor ON e50_donor_phones(donor_id);
CREATE INDEX IF NOT EXISTS idx_e50_phones_number ON e50_donor_phones(phone_number);
CREATE INDEX IF NOT EXISTS idx_e50_phones_verified ON e50_donor_phones(is_verified);


-- Email records table (multiple emails per donor)
CREATE TABLE IF NOT EXISTS e50_donor_emails (
    email_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL REFERENCES broyhillgop.donors(id) ON DELETE CASCADE,
    
    email VARCHAR(255) NOT NULL,
    email_lower VARCHAR(255),
    email_type VARCHAR(20) DEFAULT 'unknown',  -- personal, work
    domain VARCHAR(255),
    domain_type VARCHAR(50),  -- corporate, personal, government, education
    
    -- Verification
    is_verified BOOLEAN DEFAULT false,
    verification_status VARCHAR(20) DEFAULT 'unverified',
    confidence_score INTEGER DEFAULT 50 CHECK (confidence_score BETWEEN 0 AND 100),
    last_verified_at TIMESTAMP,
    verification_method VARCHAR(50),
    
    -- Source tracking
    sources TEXT[] DEFAULT '{}',
    source_count INTEGER DEFAULT 1,
    first_seen_at TIMESTAMP DEFAULT NOW(),
    last_seen_at TIMESTAMP DEFAULT NOW(),
    
    -- Engagement
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    emails_bounced INTEGER DEFAULT 0,
    unsubscribed BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, email_lower)
);

CREATE INDEX IF NOT EXISTS idx_e50_emails_donor ON e50_donor_emails(donor_id);
CREATE INDEX IF NOT EXISTS idx_e50_emails_email ON e50_donor_emails(email_lower);
CREATE INDEX IF NOT EXISTS idx_e50_emails_verified ON e50_donor_emails(is_verified);


-- Deceased records
CREATE TABLE IF NOT EXISTS e50_deceased_records (
    deceased_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL UNIQUE REFERENCES broyhillgop.donors(id) ON DELETE CASCADE,
    
    deceased_date DATE,
    deceased_date_precision VARCHAR(20),  -- exact, month, year, estimated
    
    detection_source VARCHAR(50) NOT NULL,
    detection_date TIMESTAMP DEFAULT NOW(),
    source_url TEXT,
    source_details JSONB,
    
    -- Obituary data
    obituary_text TEXT,
    obituary_url TEXT,
    surviving_family JSONB,  -- Array of family member names
    
    -- Verification
    verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMP,
    verified_by VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_e50_deceased_donor ON e50_deceased_records(donor_id);
CREATE INDEX IF NOT EXISTS idx_e50_deceased_date ON e50_deceased_records(deceased_date);


-- Enrichment queue
CREATE TABLE IF NOT EXISTS e50_enrichment_queue (
    queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL REFERENCES broyhillgop.donors(id) ON DELETE CASCADE,
    
    enrichment_type VARCHAR(50) NOT NULL,  -- phone, email, full, deceased_check
    priority INTEGER DEFAULT 50,  -- 1=highest, 100=lowest
    donor_grade VARCHAR(10),
    
    scheduled_at TIMESTAMP DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    status VARCHAR(20) DEFAULT 'pending',  -- pending, processing, completed, failed
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    
    result JSONB,
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_e50_queue_status ON e50_enrichment_queue(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_e50_queue_donor ON e50_enrichment_queue(donor_id);


-- Enrichment history (audit trail)
CREATE TABLE IF NOT EXISTS e50_enrichment_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL REFERENCES broyhillgop.donors(id) ON DELETE CASCADE,
    
    enrichment_source VARCHAR(50) NOT NULL,
    enrichment_type VARCHAR(50) NOT NULL,
    
    fields_updated TEXT[],
    old_values JSONB,
    new_values JSONB,
    
    cost_credits DECIMAL(10,2) DEFAULT 0,
    cost_dollars DECIMAL(10,4) DEFAULT 0,
    
    enriched_at TIMESTAMP DEFAULT NOW(),
    enriched_by VARCHAR(100) DEFAULT 'system'
);

CREATE INDEX IF NOT EXISTS idx_e50_history_donor ON e50_enrichment_history(donor_id);
CREATE INDEX IF NOT EXISTS idx_e50_history_source ON e50_enrichment_history(enrichment_source);
CREATE INDEX IF NOT EXISTS idx_e50_history_date ON e50_enrichment_history(enriched_at);


-- Ingestion jobs tracking
CREATE TABLE IF NOT EXISTS e50_ingestion_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    job_type VARCHAR(50) NOT NULL,  -- rnc_sync, fec_scrape, deceased_check, etc.
    source VARCHAR(50) NOT NULL,
    
    scheduled_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    status VARCHAR(20) DEFAULT 'pending',
    
    records_found INTEGER DEFAULT 0,
    records_new INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    
    parameters JSONB,
    result JSONB,
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_e50_jobs_status ON e50_ingestion_jobs(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_e50_jobs_type ON e50_ingestion_jobs(job_type);


-- View: Donors needing enrichment
CREATE OR REPLACE VIEW e50_v_donors_need_enrichment AS
SELECT 
    d.id as donor_id,
    d.full_name,
    d.email,
    d.phone,
    d.cell_phone,
    d.amount_grade_state as grade,
    d.total_donations,
    d.last_enrichment_at,
    d.data_quality_score,
    d.deceased_status,
    
    -- Calculate enrichment priority
    CASE 
        WHEN d.amount_grade_state IN ('A++', 'A+') THEN 10
        WHEN d.amount_grade_state IN ('A', 'A-') THEN 20
        WHEN d.amount_grade_state IN ('B+', 'B') THEN 30
        WHEN d.amount_grade_state IN ('B-', 'C+') THEN 40
        ELSE 50
    END as priority,
    
    -- What's missing?
    d.cell_phone IS NULL as needs_cell,
    d.email IS NULL as needs_email,
    d.cell_phone_verified = false as needs_phone_verify,
    (d.last_enrichment_at IS NULL OR d.last_enrichment_at < NOW() - INTERVAL '90 days') as needs_refresh

FROM broyhillgop.donors d
WHERE d.deceased_status != 'deceased'
  AND (
    d.cell_phone IS NULL 
    OR d.email IS NULL 
    OR d.cell_phone_verified = false
    OR d.last_enrichment_at IS NULL 
    OR d.last_enrichment_at < NOW() - INTERVAL '90 days'
  )
ORDER BY priority, d.total_donations DESC;


-- View: Data quality dashboard
CREATE OR REPLACE VIEW e50_v_data_quality_dashboard AS
SELECT 
    COUNT(*) as total_donors,
    COUNT(*) FILTER (WHERE cell_phone IS NOT NULL) as with_cell_phone,
    COUNT(*) FILTER (WHERE cell_phone_verified = true) as cell_verified,
    COUNT(*) FILTER (WHERE email IS NOT NULL) as with_email,
    COUNT(*) FILTER (WHERE deceased_status = 'deceased') as deceased_count,
    
    ROUND(100.0 * COUNT(*) FILTER (WHERE cell_phone IS NOT NULL) / COUNT(*), 1) as pct_with_cell,
    ROUND(100.0 * COUNT(*) FILTER (WHERE cell_phone_verified = true) / NULLIF(COUNT(*) FILTER (WHERE cell_phone IS NOT NULL), 0), 1) as pct_cell_verified,
    ROUND(100.0 * COUNT(*) FILTER (WHERE email IS NOT NULL) / COUNT(*), 1) as pct_with_email,
    
    AVG(data_quality_score) as avg_quality_score,
    
    COUNT(*) FILTER (WHERE last_enrichment_at > NOW() - INTERVAL '30 days') as enriched_last_30d,
    COUNT(*) FILTER (WHERE last_enrichment_at > NOW() - INTERVAL '90 days') as enriched_last_90d

FROM broyhillgop.donors
WHERE merged_into_id IS NULL;
""";


# ============================================================================
# APOLLO.IO CLIENT
# ============================================================================

class ApolloClient:
    """
    Apollo.io API client for B2B enrichment.
    
    IMPORTANT: Only use for HIGH-VALUE donors (A++, A+, A)
    
    Pricing:
    - $49/user/month (Basic) includes credits
    - 1 credit = 1 email
    - 8 credits = 1 phone
    - Extra credits: $0.20 each
    
    Features:
    - 210M+ contacts
    - Work emails (direct, not guessed)
    - Phone numbers (direct, mobile, work)
    - Job titles, companies
    - LinkedIn profiles
    """
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key or E50Config.APOLLO_API_KEY
        self.base_url = E50Config.APOLLO_API_URL
        
    async def enrich_person(self, 
                           first_name: str,
                           last_name: str,
                           email: str = None,
                           domain: str = None,
                           company: str = None,
                           reveal_phone: bool = True,
                           reveal_personal_emails: bool = True) -> Dict:
        """
        Enrich a single person via Apollo.
        
        Args:
            first_name: First name
            last_name: Last name
            email: Known email (helps matching)
            domain: Company domain (e.g., acme.com)
            company: Company name
            reveal_phone: Get phone number (costs 8 credits)
            reveal_personal_emails: Get personal emails
            
        Returns:
            Dict with enriched data
            
        Credit usage:
            - Base lookup: 1 credit
            - Phone reveal: +7 credits (8 total)
            - Personal email reveal: included in base
        """
        if not self.api_key:
            logger.error("Apollo API key not configured")
            return None
            
        async with aiohttp.ClientSession() as session:
            payload = {
                "first_name": first_name,
                "last_name": last_name,
                "reveal_phone_number": reveal_phone,
                "reveal_personal_emails": reveal_personal_emails
            }
            
            if email:
                payload["email"] = email
            if domain:
                payload["domain"] = domain
            if company:
                payload["organization_name"] = company
                
            headers = {
                "Content-Type": "application/json",
                "Cache-Control": "no-cache",
                "X-Api-Key": self.api_key
            }
            
            try:
                async with session.post(
                    f"{self.base_url}/people/match",
                    json=payload,
                    headers=headers
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        return self._parse_person_response(data)
                    else:
                        error = await response.text()
                        logger.error(f"Apollo API error: {response.status} - {error}")
                        return None
            except Exception as e:
                logger.error(f"Apollo API exception: {e}")
                return None
    
    def _parse_person_response(self, data: Dict) -> Dict:
        """Parse Apollo API response into standard format"""
        person = data.get('person', {})
        
        if not person:
            return None
            
        return {
            'source': 'apollo',
            'matched': True,
            
            # Contact info
            'email': person.get('email'),
            'personal_emails': person.get('personal_emails', []),
            'phone': person.get('phone_number'),
            'mobile_phone': person.get('mobile_phone'),
            'corporate_phone': person.get('corporate_phone'),
            
            # Professional info
            'title': person.get('title'),
            'seniority': person.get('seniority'),
            'departments': person.get('departments', []),
            
            # Company info
            'company': person.get('organization', {}).get('name'),
            'company_website': person.get('organization', {}).get('website_url'),
            'company_linkedin': person.get('organization', {}).get('linkedin_url'),
            'company_industry': person.get('organization', {}).get('industry'),
            'company_size': person.get('organization', {}).get('estimated_num_employees'),
            
            # Social
            'linkedin_url': person.get('linkedin_url'),
            'twitter_url': person.get('twitter_url'),
            'facebook_url': person.get('facebook_url'),
            
            # Location
            'city': person.get('city'),
            'state': person.get('state'),
            'country': person.get('country'),
            
            # Metadata
            'apollo_id': person.get('id'),
            'confidence': person.get('email_confidence') or 90
        }
    
    async def bulk_enrich(self, people: List[Dict], 
                         reveal_phones: bool = True) -> List[Dict]:
        """
        Bulk enrich up to 10 people at once.
        
        Args:
            people: List of dicts with first_name, last_name, email/domain
            reveal_phones: Whether to reveal phone numbers
            
        Returns:
            List of enriched records
        """
        if not self.api_key:
            logger.error("Apollo API key not configured")
            return []
            
        async with aiohttp.ClientSession() as session:
            payload = {
                "reveal_phone_number": reveal_phones,
                "details": people[:10]  # Max 10 per request
            }
            
            headers = {
                "Content-Type": "application/json",
                "X-Api-Key": self.api_key
            }
            
            try:
                async with session.post(
                    f"{self.base_url}/people/bulk_match",
                    json=payload,
                    headers=headers
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        return [
                            self._parse_person_response({'person': p})
                            for p in data.get('matches', [])
                            if p
                        ]
                    else:
                        error = await response.text()
                        logger.error(f"Apollo bulk API error: {response.status}")
                        return []
            except Exception as e:
                logger.error(f"Apollo bulk API exception: {e}")
                return []


# ============================================================================
# BETTERCONTACT CLIENT
# ============================================================================

class BetterContactClient:
    """
    BetterContact API client for waterfall enrichment.
    
    KEY ADVANTAGE: Uses 20+ data providers in sequence,
    only charges when valid data is found.
    
    Pricing:
    - $49/month for 1,000 credits
    - 1 credit = 1 email + verification
    - 10 credits = 1 phone + verification
    - Credits roll over (up to 2x your plan)
    - Only charges for VALID data found
    
    Providers include:
    - Apollo, RocketReach, ContactOut
    - Datagma, People Data Labs
    - Hunter, Prospeo, and 12+ more
    
    Why use this over Apollo directly?
    - Waterfall = higher hit rate
    - Built-in verification
    - Only pay for valid data
    - Better for phones (Apollo weak on mobile)
    """
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key or E50Config.BETTERCONTACT_API_KEY
        self.base_url = E50Config.BETTERCONTACT_API_URL
        
    async def enrich_contact(self,
                            first_name: str,
                            last_name: str,
                            company: str = None,
                            linkedin_url: str = None,
                            find_email: bool = True,
                            find_phone: bool = True) -> Dict:
        """
        Enrich a single contact via BetterContact waterfall.
        
        The waterfall process:
        1. BetterContact analyzes the input
        2. Determines optimal provider sequence
        3. Queries providers until valid data found
        4. Verifies data before returning
        5. Only charges if valid data found
        
        Args:
            first_name: First name
            last_name: Last name
            company: Company name (improves matching)
            linkedin_url: LinkedIn profile URL (best for matching)
            find_email: Whether to find email (1 credit if found)
            find_phone: Whether to find phone (10 credits if found)
            
        Returns:
            Dict with found contact data
        """
        if not self.api_key:
            logger.error("BetterContact API key not configured")
            return None
            
        async with aiohttp.ClientSession() as session:
            payload = {
                "first_name": first_name,
                "last_name": last_name,
                "find_email": find_email,
                "find_phone": find_phone
            }
            
            if company:
                payload["company"] = company
            if linkedin_url:
                payload["linkedin_url"] = linkedin_url
                
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            
            try:
                # Submit enrichment request
                async with session.post(
                    f"{self.base_url}/enrich",
                    json=payload,
                    headers=headers
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        
                        # BetterContact is async - need to poll for results
                        request_id = data.get('request_id')
                        if request_id:
                            return await self._poll_for_result(session, request_id, headers)
                        return self._parse_response(data)
                    else:
                        error = await response.text()
                        logger.error(f"BetterContact API error: {response.status} - {error}")
                        return None
            except Exception as e:
                logger.error(f"BetterContact API exception: {e}")
                return None
    
    async def _poll_for_result(self, session, request_id: str, headers: Dict, 
                               max_attempts: int = 10) -> Dict:
        """Poll for async enrichment result"""
        for attempt in range(max_attempts):
            await asyncio.sleep(2)  # Wait 2 seconds between polls
            
            try:
                async with session.get(
                    f"{self.base_url}/enrich/{request_id}",
                    headers=headers
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        if data.get('status') == 'completed':
                            return self._parse_response(data)
            except Exception as e:
                logger.warning(f"Poll attempt {attempt} failed: {e}")
                
        return None
    
    def _parse_response(self, data: Dict) -> Dict:
        """Parse BetterContact response"""
        return {
            'source': 'bettercontact',
            'matched': data.get('found', False),
            
            # Email
            'email': data.get('email'),
            'email_verified': data.get('email_verified', False),
            'email_status': data.get('email_status'),  # valid, risky, catch_all
            
            # Phone
            'phone': data.get('phone'),
            'phone_verified': data.get('phone_verified', False),
            'phone_type': data.get('phone_type'),  # mobile, landline
            
            # Metadata
            'credits_used': data.get('credits_used', 0),
            'providers_used': data.get('providers_used', [])
        }
    
    async def bulk_enrich(self, contacts: List[Dict],
                         find_email: bool = True,
                         find_phone: bool = True,
                         webhook_url: str = None) -> str:
        """
        Submit bulk enrichment job.
        
        Args:
            contacts: List of contact dicts
            find_email: Find emails
            find_phone: Find phones
            webhook_url: Optional webhook for completion notification
            
        Returns:
            Batch ID for tracking
        """
        if not self.api_key:
            return None
            
        async with aiohttp.ClientSession() as session:
            payload = {
                "contacts": contacts,
                "find_email": find_email,
                "find_phone": find_phone
            }
            
            if webhook_url:
                payload["webhook_url"] = webhook_url
                
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            
            try:
                async with session.post(
                    f"{self.base_url}/batch/enrich",
                    json=payload,
                    headers=headers
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('batch_id')
                    return None
            except Exception as e:
                logger.error(f"BetterContact bulk error: {e}")
                return None


# ============================================================================
# RNC DATATRUST CLIENT (FREE FOR EDDIE!)
# ============================================================================

class RNCDataTrustClient:
    """
    RNC DataTrust API client.
    
    IMPORTANT: This is FREE for Eddie as NC RNC Committeeman!
    
    Access methods:
    1. REST API: rncdatahubapi.gop
    2. Direct SQL: rncazdwsql.cloudapp.net:52954
    
    Data available:
    - Full voter file with enhanced data
    - Phone numbers (cell + landline)
    - Email addresses
    - Household linking
    - Consumer data overlays
    - Propensity scores
    - 2,500+ data fields
    
    This should be PRIMARY source before any paid enrichment.
    """
    
    def __init__(self):
        self.client_id = E50Config.RNC_DATAHUB_CLIENT_ID
        self.client_secret = E50Config.RNC_DATAHUB_CLIENT_SECRET
        self.api_url = E50Config.RNC_API_URL
        self.access_token = None
        self.token_expires = None
        
    async def authenticate(self) -> bool:
        """Get OAuth token from RNC DataHub"""
        if not self.client_id or not self.client_secret:
            logger.error("RNC DataHub credentials not configured")
            return False
            
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(
                    f"{self.api_url}/oauth/token",
                    data={
                        "grant_type": "client_credentials",
                        "client_id": self.client_id,
                        "client_secret": self.client_secret,
                        "scope": "read"
                    }
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        self.access_token = data.get('access_token')
                        self.token_expires = datetime.now() + timedelta(
                            seconds=data.get('expires_in', 3600)
                        )
                        logger.info("RNC DataTrust authenticated successfully")
                        return True
                    else:
                        error = await response.text()
                        logger.error(f"RNC auth failed: {response.status} - {error}")
                        return False
            except Exception as e:
                logger.error(f"RNC auth exception: {e}")
                return False
    
    async def lookup_voter(self, 
                          first_name: str = None,
                          last_name: str = None,
                          address: str = None,
                          city: str = None,
                          state: str = "NC",
                          zip_code: str = None) -> Dict:
        """
        Look up voter in RNC DataTrust.
        
        Returns enhanced voter data including:
        - Phone numbers (if available)
        - Email addresses (if available)  
        - Party affiliation
        - Vote history
        - Consumer data overlays
        - Propensity scores
        """
        if not self.access_token or datetime.now() >= self.token_expires:
            if not await self.authenticate():
                return None
                
        async with aiohttp.ClientSession() as session:
            params = {
                "state": state
            }
            if first_name:
                params["firstName"] = first_name
            if last_name:
                params["lastName"] = last_name
            if address:
                params["address"] = address
            if city:
                params["city"] = city
            if zip_code:
                params["zip"] = zip_code
                
            headers = {
                "Authorization": f"Bearer {self.access_token}",
                "Content-Type": "application/json"
            }
            
            try:
                async with session.get(
                    f"{self.api_url}/v1/voters/search",
                    params=params,
                    headers=headers
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        voters = data.get('voters', [])
                        if voters:
                            return self._parse_voter(voters[0])
                    return None
            except Exception as e:
                logger.error(f"RNC lookup error: {e}")
                return None
    
    def _parse_voter(self, voter: Dict) -> Dict:
        """Parse RNC DataTrust voter record"""
        return {
            'source': 'rnc_datatrust',
            'matched': True,
            
            # Identity
            'voter_id': voter.get('voterFileId'),
            'first_name': voter.get('firstName'),
            'last_name': voter.get('lastName'),
            
            # Contact (if available)
            'phone': voter.get('phone'),
            'cell_phone': voter.get('cellPhone'),
            'email': voter.get('email'),
            
            # Address
            'address': voter.get('address'),
            'city': voter.get('city'),
            'state': voter.get('state'),
            'zip': voter.get('zip'),
            
            # Political
            'party': voter.get('party'),
            'voter_score': voter.get('voterScore'),
            'partisan_score': voter.get('partisanScore'),
            
            # Vote history
            'vote_history': voter.get('voteHistory', []),
            'elections_voted': voter.get('electionsVoted', 0),
            
            # Consumer data
            'estimated_income': voter.get('estimatedIncome'),
            'education': voter.get('education'),
            'homeowner': voter.get('homeowner'),
            
            # Household
            'household_id': voter.get('householdId'),
            'household_size': voter.get('householdSize')
        }


# ============================================================================
# DECEASED DETECTION
# ============================================================================

class DeceasedDetector:
    """
    Multi-source deceased detection.
    
    Sources (in order of reliability):
    1. NC DHHS Death Records (via NCBOE voter file updates)
    2. Voter File Removals (status=REMOVED, reason=DECEASED)
    3. SSDI Public File (Social Security Death Index)
    4. Obituary Scraping (Legacy.com, local NC papers)
    5. Family Notification (manual flag)
    
    NC DHHS sends weekly death records to NCBOE.
    NCBOE removes deceased from voter rolls.
    You can detect deceased by:
    - Comparing current vs. previous voter file
    - Looking for status changes to REMOVED
    - Matching names against SSDI
    - Scraping obituaries
    """
    
    def __init__(self, db_connection=None):
        self.db = db_connection
        
    def check_ncboe_removed(self, first_name: str, last_name: str,
                           dob: datetime = None) -> Optional[Dict]:
        """
        Check if person was removed from NC voter file as deceased.
        
        NC voter file updates weekly. When someone dies:
        1. NC DHHS notifies NCBOE
        2. NCBOE changes voter status to REMOVED
        3. Reason code indicates DECEASED
        
        You already scrape NCBOE - this checks the removed records.
        """
        if not self.db:
            return None
            
        cursor = self.db.cursor(cursor_factory=RealDictCursor)
        
        # Check voter file for removed records
        # You'd need to store historical voter file data
        sql = """
            SELECT *
            FROM ncboe_voter_history
            WHERE UPPER(first_name) = UPPER(%s)
              AND UPPER(last_name) = UPPER(%s)
              AND status = 'REMOVED'
              AND reason_code = 'DECEASED'
        """
        params = [first_name, last_name]
        
        if dob:
            sql += " AND birth_date = %s"
            params.append(dob)
            
        cursor.execute(sql, params)
        result = cursor.fetchone()
        
        if result:
            return {
                'source': 'voter_file_removed',
                'deceased': True,
                'deceased_date': result.get('status_change_date'),
                'voter_id': result.get('voter_id'),
                'confidence': 95
            }
        return None
    
    async def check_obituaries(self, first_name: str, last_name: str,
                               city: str = None, state: str = "NC") -> Optional[Dict]:
        """
        Search obituary sites for death notices.
        
        Sites searched:
        - Legacy.com (largest)
        - Local NC newspapers
        - Funeral home websites
        
        Uses AI to extract:
        - Date of death
        - Surviving family members (for family linking!)
        - Location
        """
        # Search Legacy.com
        query = f"{first_name} {last_name}"
        if city:
            query += f" {city}"
        if state:
            query += f" {state}"
            
        async with aiohttp.ClientSession() as session:
            try:
                # Legacy.com search
                async with session.get(
                    "https://www.legacy.com/obituaries/search",
                    params={
                        "firstName": first_name,
                        "lastName": last_name,
                        "state": state,
                        "countryId": 1  # USA
                    }
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        return self._parse_obituary_results(html)
            except Exception as e:
                logger.error(f"Obituary search error: {e}")
                
        return None
    
    def _parse_obituary_results(self, html: str) -> Optional[Dict]:
        """Parse obituary search results (would use BeautifulSoup in production)"""
        # Simplified - in production, parse HTML for obituary details
        # Extract: name, dates, surviving family, obituary text
        return None
    
    def check_ssdi_public(self, first_name: str, last_name: str,
                         dob: datetime = None, ssn_last4: str = None) -> Optional[Dict]:
        """
        Check public SSDI (Social Security Death Index).
        
        Note: Full SSDI requires NTIS certification.
        Public portion available via:
        - Ancestry.com (paywall)
        - FamilySearch.org (free, but dated)
        - Various genealogy sites
        
        For bulk checking, consider services like:
        - Tracers (has API, batch processing)
        - Streamline Verify
        """
        # This would integrate with an SSDI service
        # For now, return None
        return None
    
    async def check_all_sources(self, first_name: str, last_name: str,
                                dob: datetime = None,
                                city: str = None,
                                state: str = "NC") -> Dict:
        """
        Check all deceased detection sources.
        
        Returns combined result with source and confidence.
        """
        results = {
            'deceased': False,
            'sources_checked': [],
            'matches': []
        }
        
        # Check NCBOE removed voters
        ncboe = self.check_ncboe_removed(first_name, last_name, dob)
        results['sources_checked'].append('ncboe_voter_file')
        if ncboe:
            results['matches'].append(ncboe)
            results['deceased'] = True
            
        # Check obituaries
        obit = await self.check_obituaries(first_name, last_name, city, state)
        results['sources_checked'].append('obituaries')
        if obit:
            results['matches'].append(obit)
            results['deceased'] = True
            
        # Check SSDI
        ssdi = self.check_ssdi_public(first_name, last_name, dob)
        results['sources_checked'].append('ssdi')
        if ssdi:
            results['matches'].append(ssdi)
            results['deceased'] = True
            
        # Calculate overall confidence
        if results['matches']:
            results['best_source'] = max(results['matches'], 
                                        key=lambda x: x.get('confidence', 0))
            results['confidence'] = results['best_source'].get('confidence', 0)
            
        return results


# ============================================================================
# CONTACT INTELLIGENCE ENGINE (Main Orchestrator)
# ============================================================================

class ContactIntelligenceEngine:
    """
    Main orchestrator for contact enrichment.
    
    Strategy:
    1. RNC DataTrust FIRST (free for Eddie!)
    2. If high-value (A++/A+) and still missing data:
       - Apollo for work info
       - BetterContact for phone verification
    3. Check deceased status periodically
    4. Update golden record
    
    Cost optimization:
    - FREE sources first (RNC, FEC, NCBOE, Property)
    - PAID sources only for A++/A+/A grades
    - BetterContact only charges for valid data
    """
    
    def __init__(self):
        self.apollo = ApolloClient()
        self.bettercontact = BetterContactClient()
        self.rnc = RNCDataTrustClient()
        self.deceased = DeceasedDetector()
        self.db = None
        
    def connect_db(self):
        """Connect to database"""
        if not self.db:
            self.db = psycopg2.connect(E50Config.DATABASE_URL)
            self.deceased.db = self.db
        return self.db
    
    async def enrich_donor(self, donor_id: str, 
                          force_paid: bool = False) -> Dict:
        """
        Enrich a single donor using optimal source strategy.
        
        Strategy:
        1. Load donor from database
        2. Check RNC DataTrust (FREE)
        3. If high-value and missing data, use paid sources
        4. Update donor record
        5. Log enrichment history
        """
        conn = self.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Load donor
        cursor.execute("""
            SELECT * FROM broyhillgop.donors WHERE id = %s
        """, (donor_id,))
        donor = cursor.fetchone()
        
        if not donor:
            return {'error': 'Donor not found'}
            
        results = {
            'donor_id': donor_id,
            'before': {
                'cell_phone': donor.get('cell_phone'),
                'email': donor.get('email')
            },
            'sources_used': [],
            'fields_updated': [],
            'cost_credits': 0,
            'cost_dollars': 0
        }
        
        # Step 1: RNC DataTrust (FREE!)
        rnc_data = await self.rnc.lookup_voter(
            first_name=donor.get('first_name'),
            last_name=donor.get('last_name'),
            address=donor.get('address'),
            city=donor.get('city'),
            state=donor.get('state', 'NC'),
            zip_code=donor.get('zip')
        )
        
        if rnc_data:
            results['sources_used'].append('rnc_datatrust')
            
            # Update if we found new data
            if rnc_data.get('cell_phone') and not donor.get('cell_phone'):
                results['fields_updated'].append('cell_phone')
                
            if rnc_data.get('email') and not donor.get('email'):
                results['fields_updated'].append('email')
        
        # Step 2: Check if we need paid enrichment
        grade = donor.get('amount_grade_state', '')
        
        # Determine enrichment tier
        is_tier_1 = grade in E50Config.TIER_1_GRADES  # A++, A+, A = Full enrichment
        is_tier_2 = grade in E50Config.TIER_2_GRADES  # A-, B+, B = BetterContact only
        is_tier_3 = grade in E50Config.TIER_3_GRADES  # B-, C+, C, C- = Phone only
        is_high_value = grade in E50Config.HIGH_VALUE_GRADES
        
        needs_more = (
            not donor.get('cell_phone') or
            not donor.get('email') or
            not donor.get('cell_phone_verified')
        )
        
        apollo_data = None
        bc_data = None
        
        if (is_high_value or force_paid) and needs_more:
            
            # TIER 1: A++, A+, A - Full Apollo + BetterContact
            if is_tier_1 or force_paid:
                # Try Apollo for work email/phone
                if not donor.get('work_email') or not donor.get('cell_phone'):
                    apollo_data = await self.apollo.enrich_person(
                        first_name=donor.get('first_name'),
                        last_name=donor.get('last_name'),
                        email=donor.get('email'),
                        company=donor.get('employer'),
                        reveal_phone=not donor.get('cell_phone')
                    )
                    
                    if apollo_data:
                        results['sources_used'].append('apollo')
                        results['cost_credits'] += (
                            E50Config.APOLLO_CREDITS_PER_EMAIL +
                            (E50Config.APOLLO_CREDITS_PER_PHONE if apollo_data.get('phone') else 0)
                        )
                        results['cost_dollars'] += results['cost_credits'] * 0.20
                        
                        if apollo_data.get('email'):
                            results['fields_updated'].append('work_email')
                        if apollo_data.get('phone'):
                            results['fields_updated'].append('work_phone')
                        if apollo_data.get('title'):
                            results['fields_updated'].append('occupation')
            
            # TIER 1 & 2: A++ through B - BetterContact for email + phone
            if (is_tier_1 or is_tier_2) and (not donor.get('cell_phone_verified') or not donor.get('email')):
                bc_data = await self.bettercontact.enrich_contact(
                    first_name=donor.get('first_name'),
                    last_name=donor.get('last_name'),
                    company=donor.get('employer'),
                    find_email=not donor.get('email'),
                    find_phone=True
                )
                
                if bc_data and bc_data.get('matched'):
                    results['sources_used'].append('bettercontact')
                    results['cost_credits'] += bc_data.get('credits_used', 0)
                    results['cost_dollars'] += (
                        bc_data.get('credits_used', 0) * 0.049  # Approx per credit
                    )
                    
                    if bc_data.get('phone') and bc_data.get('phone_verified'):
                        results['fields_updated'].append('cell_phone_verified')
                    if bc_data.get('email') and bc_data.get('email_verified'):
                        results['fields_updated'].append('email')
            
            # TIER 3: B- through C- - BetterContact phone ONLY (most cost-effective)
            elif is_tier_3 and not donor.get('cell_phone'):
                bc_data = await self.bettercontact.enrich_contact(
                    first_name=donor.get('first_name'),
                    last_name=donor.get('last_name'),
                    company=donor.get('employer'),
                    find_email=False,  # Skip email to save credits
                    find_phone=True
                )
                
                if bc_data and bc_data.get('matched'):
                    results['sources_used'].append('bettercontact')
                    results['cost_credits'] += bc_data.get('credits_used', 0)
                    results['cost_dollars'] += (
                        bc_data.get('credits_used', 0) * 0.049
                    )
                    
                    if bc_data.get('phone') and bc_data.get('phone_verified'):
                        results['fields_updated'].append('cell_phone_verified')
        
        # Step 3: Check deceased status
        deceased_check = await self.deceased.check_all_sources(
            first_name=donor.get('first_name'),
            last_name=donor.get('last_name'),
            city=donor.get('city'),
            state=donor.get('state', 'NC')
        )
        
        if deceased_check.get('deceased'):
            results['deceased_detected'] = True
            results['fields_updated'].append('deceased_status')
        
        # Step 4: Update donor record
        if results['fields_updated']:
            await self._update_donor_record(
                donor_id, 
                results, 
                rnc_data, 
                apollo_data,
                bc_data
            )
            
        # Step 5: Log enrichment history
        await self._log_enrichment(donor_id, results)
        
        results['after'] = {
            'fields_updated': results['fields_updated'],
            'sources_used': results['sources_used']
        }
        
        return results
    
    async def _update_donor_record(self, donor_id: str, results: Dict,
                                   rnc_data: Dict = None, 
                                   apollo_data: Dict = None):
        """Update donor record with enriched data"""
        conn = self.connect_db()
        cursor = conn.cursor()
        
        updates = []
        params = []
        
        if rnc_data:
            if rnc_data.get('cell_phone'):
                updates.append("cell_phone = %s")
                params.append(rnc_data['cell_phone'])
                updates.append("cell_phone_sources = array_append(cell_phone_sources, 'rnc_datatrust')")
                
            if rnc_data.get('email'):
                updates.append("email = COALESCE(email, %s)")
                params.append(rnc_data['email'])
                
        if apollo_data:
            if apollo_data.get('email'):
                updates.append("work_email = %s")
                params.append(apollo_data['email'])
                
            if apollo_data.get('phone'):
                updates.append("work_phone = %s")
                params.append(apollo_data['phone'])
                
            if apollo_data.get('title'):
                updates.append("occupation = COALESCE(occupation, %s)")
                params.append(apollo_data['title'])
                
        if results.get('deceased_detected'):
            updates.append("deceased_status = 'deceased'")
            updates.append("deceased_detected_at = NOW()")
            
        # Always update enrichment timestamp
        updates.append("last_enrichment_at = NOW()")
        updates.append("enrichment_sources = enrichment_sources || %s::text[]")
        params.append(results.get('sources_used', []))
        
        if updates:
            sql = f"""
                UPDATE broyhillgop.donors 
                SET {', '.join(updates)}, updated_at = NOW()
                WHERE id = %s
            """
            params.append(donor_id)
            cursor.execute(sql, params)
            conn.commit()
    
    async def _log_enrichment(self, donor_id: str, results: Dict):
        """Log enrichment to history table"""
        conn = self.connect_db()
        cursor = conn.cursor()
        
        for source in results.get('sources_used', []):
            cursor.execute("""
                INSERT INTO e50_enrichment_history 
                (donor_id, enrichment_source, enrichment_type, 
                 fields_updated, cost_credits, cost_dollars)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                donor_id,
                source,
                'full',
                results.get('fields_updated', []),
                results.get('cost_credits', 0),
                results.get('cost_dollars', 0)
            ))
            
        conn.commit()
    
    async def run_scheduled_enrichment(self, 
                                       max_donors: int = 100,
                                       grades: List[str] = None):
        """
        Run scheduled enrichment for donors needing updates.
        
        Called by cron scheduler (e.g., quarterly for full refresh).
        
        Priority order:
        1. A++, A+ (highest value, get paid enrichment)
        2. A, A- (high value)
        3. B+, B (medium value, free sources only)
        4. Everyone else (free sources only)
        """
        conn = self.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get donors needing enrichment
        sql = """
            SELECT donor_id, grade, needs_cell, needs_email, priority
            FROM e50_v_donors_need_enrichment
            WHERE TRUE
        """
        params = []
        
        if grades:
            sql += " AND grade = ANY(%s)"
            params.append(grades)
            
        sql += " ORDER BY priority, total_donations DESC LIMIT %s"
        params.append(max_donors)
        
        cursor.execute(sql, params)
        donors = cursor.fetchall()
        
        logger.info(f"Starting enrichment for {len(donors)} donors")
        
        results = {
            'total': len(donors),
            'enriched': 0,
            'errors': 0,
            'cost_total': 0
        }
        
        for donor in donors:
            try:
                result = await self.enrich_donor(
                    donor['donor_id'],
                    force_paid=(donor['grade'] in E50Config.HIGH_VALUE_GRADES)
                )
                results['enriched'] += 1
                results['cost_total'] += result.get('cost_dollars', 0)
            except Exception as e:
                logger.error(f"Error enriching {donor['donor_id']}: {e}")
                results['errors'] += 1
                
        logger.info(f"Enrichment complete: {results}")
        return results
    
    async def run_deceased_check(self, max_donors: int = 500):
        """
        Run deceased detection for all donors.
        
        Called daily to catch recent deaths.
        """
        conn = self.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get donors not marked as deceased
        cursor.execute("""
            SELECT id, first_name, last_name, city, state, date_of_birth
            FROM broyhillgop.donors
            WHERE deceased_status != 'deceased'
              AND (deceased_status IS NULL OR deceased_status = 'unknown')
            ORDER BY last_enrichment_at ASC NULLS FIRST
            LIMIT %s
        """, (max_donors,))
        
        donors = cursor.fetchall()
        
        deceased_found = 0
        
        for donor in donors:
            result = await self.deceased.check_all_sources(
                first_name=donor['first_name'],
                last_name=donor['last_name'],
                dob=donor.get('date_of_birth'),
                city=donor.get('city'),
                state=donor.get('state', 'NC')
            )
            
            if result.get('deceased'):
                deceased_found += 1
                
                # Update donor as deceased
                cursor.execute("""
                    UPDATE broyhillgop.donors
                    SET deceased_status = 'deceased',
                        deceased_date = %s,
                        deceased_source = %s,
                        deceased_detected_at = NOW(),
                        updated_at = NOW()
                    WHERE id = %s
                """, (
                    result.get('best_source', {}).get('deceased_date'),
                    result.get('best_source', {}).get('source'),
                    donor['id']
                ))
                
                # Log to deceased records
                cursor.execute("""
                    INSERT INTO e50_deceased_records
                    (donor_id, deceased_date, detection_source, source_details)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (donor_id) DO NOTHING
                """, (
                    donor['id'],
                    result.get('best_source', {}).get('deceased_date'),
                    result.get('best_source', {}).get('source'),
                    json.dumps(result)
                ))
                
        conn.commit()
        
        logger.info(f"Deceased check complete: {deceased_found} deceased found out of {len(donors)} checked")
        return {
            'checked': len(donors),
            'deceased_found': deceased_found
        }


# ============================================================================
# SCHEDULER
# ============================================================================

class E50Scheduler:
    """
    Scheduler for E50 enrichment jobs.
    
    Jobs:
    - Daily: RNC sync, FEC scrape, deceased check
    - Weekly: NCBOE voter file sync
    - Monthly: BetterContact verification for new phones
    - Quarterly: Apollo enrichment for high-value donors
    """
    
    def __init__(self, engine: ContactIntelligenceEngine):
        self.engine = engine
        
    async def run_daily_jobs(self):
        """Run daily enrichment jobs"""
        logger.info("Starting daily E50 jobs")
        
        # RNC DataTrust sync
        # (This would sync with RNC API for any updates)
        
        # FEC scrape for new donations
        # (Already handled by existing scrapers)
        
        # Deceased check
        await self.engine.run_deceased_check(max_donors=500)
        
    async def run_weekly_jobs(self):
        """Run weekly enrichment jobs"""
        logger.info("Starting weekly E50 jobs")
        
        # NCBOE voter file sync
        # Check for new removals (deceased)
        
    async def run_monthly_jobs(self):
        """Run monthly enrichment jobs"""
        logger.info("Starting monthly E50 jobs")
        
        # BetterContact verification for unverified phones
        await self.engine.run_scheduled_enrichment(
            max_donors=200,
            grades=['A++', 'A+', 'A', 'A-']
        )
        
    async def run_quarterly_jobs(self):
        """Run quarterly enrichment jobs"""
        logger.info("Starting quarterly E50 jobs")
        
        # Full Apollo enrichment for high-value donors
        await self.engine.run_scheduled_enrichment(
            max_donors=500,
            grades=['A++', 'A+']
        )


# ============================================================================
# E20 INTELLIGENCE BRAIN INTEGRATION
# ============================================================================

class E50BrainIntegration:
    """
    Full integration with E20 Intelligence Brain
    
    E50 receives commands from E20:
    - e20.enrich.priority → Immediate high-value donor enrichment
    - e20.enrich.batch → Quarterly/monthly batch enrichment
    - e20.verify.campaign → Pre-campaign contact verification
    - e20.deceased.check → Run deceased detection
    
    E50 publishes results to E20:
    - e50.contact.enriched → New phone/email found
    - e50.contact.verified → Contact confirmed
    - e50.contact.deceased → Death detected
    - e50.prospect.enriched → Social prospect ready
    - e50.cost.logged → Budget tracking
    """
    
    def __init__(self, engine: 'ContactIntelligenceEngine'):
        self.engine = engine
        self.redis_client = None
        self.running = False
        self.control_settings = None
        
    async def connect(self):
        """Connect to Redis event bus"""
        import redis.asyncio as redis
        self.redis_client = redis.Redis(
            host=os.getenv('REDIS_HOST', 'localhost'),
            port=int(os.getenv('REDIS_PORT', 6379)),
            db=0,
            decode_responses=True
        )
        await self.load_control_settings()
        logger.info("🧠 E50 connected to Intelligence Brain")
        
    async def load_control_settings(self):
        """Load control panel settings from database"""
        conn = self.engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT * FROM e50_control_settings LIMIT 1
        """)
        self.control_settings = cursor.fetchone()
        
        if not self.control_settings:
            # Create default settings
            cursor.execute("""
                INSERT INTO e50_control_settings DEFAULT VALUES
                RETURNING *
            """)
            conn.commit()
            self.control_settings = cursor.fetchone()
        
        logger.info(f"📋 Loaded E50 control settings")
        return self.control_settings
    
    async def start_listening(self):
        """Start listening for E20 Brain commands"""
        if not self.redis_client:
            await self.connect()
        
        pubsub = self.redis_client.pubsub()
        
        # Subscribe to E20 Brain channels
        channels = [
            'e20.enrich.priority',    # High-value donor enrichment
            'e20.enrich.batch',       # Quarterly refresh
            'e20.verify.campaign',    # Pre-campaign verification
            'e20.deceased.check',     # Deceased detection
            'e1.grade.changed',       # Donor grade changes
        ]
        
        await pubsub.subscribe(*channels)
        
        self.running = True
        logger.info(f"📡 E50 listening to {len(channels)} Brain channels")
        
        async for message in pubsub.listen():
            if not self.running:
                break
                
            if message['type'] == 'message':
                await self.handle_brain_command(message)
    
    async def handle_brain_command(self, message: Dict):
        """Handle commands from E20 Intelligence Brain"""
        try:
            channel = message['channel']
            data = json.loads(message['data'])
            
            logger.info(f"📥 E50 received Brain command: {channel}")
            
            if channel == 'e20.enrich.priority':
                await self.handle_priority_enrichment(data)
                
            elif channel == 'e20.enrich.batch':
                await self.handle_batch_enrichment(data)
                
            elif channel == 'e20.verify.campaign':
                await self.handle_campaign_verification(data)
                
            elif channel == 'e20.deceased.check':
                await self.handle_deceased_check(data)
                
            elif channel == 'e1.grade.changed':
                await self.handle_grade_change(data)
                
        except json.JSONDecodeError:
            logger.error(f"Invalid JSON from Brain: {message['data']}")
        except Exception as e:
            logger.error(f"Error handling Brain command: {e}")
    
    async def handle_priority_enrichment(self, data: Dict):
        """
        Handle high-priority donor enrichment request from E20
        
        Triggered when:
        - New high-value donation detected
        - Donor upgraded to A++ tier
        - VIP max-out detected
        """
        donor_id = data.get('donor_id')
        reason = data.get('reason', 'priority')
        
        logger.info(f"🔴 PRIORITY ENRICHMENT: {donor_id} ({reason})")
        
        if not self.control_settings.get('auto_enrich_enabled', True):
            logger.info("⏸️ Auto-enrich disabled, skipping")
            return
        
        # Run immediate enrichment
        result = await self.engine.enrich_donor(donor_id)
        
        # Publish result
        await self.publish_enrichment_result(result)
        
        # Log cost
        if result.get('total_cost', 0) > 0:
            await self.log_cost(
                source='mixed',
                operation='priority_enrichment',
                cost=result['total_cost'],
                donor_id=donor_id
            )
    
    async def handle_batch_enrichment(self, data: Dict):
        """
        Handle batch enrichment request from E20
        
        Triggered by:
        - Quarterly refresh schedule
        - Monthly A-tier refresh
        - Manual trigger from control panel
        """
        max_donors = data.get('max_donors', 500)
        grades = data.get('grades')
        
        logger.info(f"📦 BATCH ENRICHMENT: {max_donors} donors, grades={grades}")
        
        if not self.control_settings.get('auto_enrich_enabled', True):
            logger.info("⏸️ Auto-enrich disabled, skipping")
            return
        
        # Check budget
        budget_ok = await self.check_budget()
        if not budget_ok:
            logger.warning("💰 Budget limit reached, skipping batch")
            return
        
        # Run batch enrichment
        result = await self.engine.run_scheduled_enrichment(
            max_donors=max_donors,
            grades=grades
        )
        
        # Publish completion
        await self.redis_client.publish(
            'e50.batch.completed',
            json.dumps({
                'donors_processed': result.get('processed', 0),
                'success_count': result.get('success', 0),
                'total_cost': result.get('total_cost', 0),
                'timestamp': datetime.now().isoformat()
            })
        )
    
    async def handle_campaign_verification(self, data: Dict):
        """
        Handle pre-campaign contact verification from E20
        
        Triggered before:
        - Email campaign launch
        - SMS campaign launch
        - Phone banking campaign
        """
        campaign_id = data.get('campaign_id')
        contact_ids = data.get('contact_ids', [])
        channel = data.get('channel', 'email')  # email, sms, phone
        
        logger.info(f"✅ PRE-CAMPAIGN VERIFICATION: {len(contact_ids)} contacts for {channel}")
        
        if not self.control_settings.get('pre_campaign_verification', True):
            logger.info("⏸️ Pre-campaign verification disabled")
            return
        
        # Verify contacts based on channel
        verified = []
        unverified = []
        
        for contact_id in contact_ids:
            status = await self.engine.get_enrichment_status(contact_id)
            
            if channel == 'email':
                if status.get('email_verified') or status.get('email'):
                    verified.append(contact_id)
                else:
                    unverified.append(contact_id)
                    
            elif channel in ['sms', 'phone']:
                if status.get('phone_verified') or status.get('cell_phone'):
                    verified.append(contact_id)
                else:
                    unverified.append(contact_id)
        
        # Check threshold (block if >10% unverified)
        unverified_pct = len(unverified) / max(len(contact_ids), 1) * 100
        
        result = {
            'campaign_id': campaign_id,
            'channel': channel,
            'total_contacts': len(contact_ids),
            'verified_count': len(verified),
            'unverified_count': len(unverified),
            'unverified_percent': unverified_pct,
            'status': 'APPROVED' if unverified_pct <= 10 else 'BLOCKED',
            'unverified_ids': unverified[:100]  # First 100 for review
        }
        
        await self.redis_client.publish(
            'e50.campaign.verified',
            json.dumps(result)
        )
        
        if result['status'] == 'BLOCKED':
            logger.warning(f"⛔ Campaign BLOCKED: {unverified_pct:.1f}% unverified")
        else:
            logger.info(f"✅ Campaign APPROVED: {100-unverified_pct:.1f}% verified")
    
    async def handle_deceased_check(self, data: Dict):
        """
        Handle deceased detection request from E20
        """
        max_donors = data.get('max_donors', 100)
        
        logger.info(f"💀 DECEASED CHECK: {max_donors} donors")
        
        if not self.control_settings.get('deceased_detection_enabled', True):
            logger.info("⏸️ Deceased detection disabled")
            return
        
        result = await self.engine.run_deceased_check(max_donors=max_donors)
        
        # Publish each deceased donor
        for deceased in result.get('deceased_found', []):
            await self.redis_client.publish(
                'e50.contact.deceased',
                json.dumps({
                    'donor_id': deceased['donor_id'],
                    'full_name': deceased['full_name'],
                    'source': 'ssdi',
                    'confidence': deceased.get('confidence', 'high'),
                    'detected_at': datetime.now().isoformat()
                })
            )
            logger.info(f"☠️ Deceased detected: {deceased['full_name']}")
    
    async def handle_grade_change(self, data: Dict):
        """
        Handle donor grade change from E1
        
        If upgraded to A tier, trigger enrichment
        """
        donor_id = data.get('donor_id')
        old_grade = data.get('old_grade')
        new_grade = data.get('new_grade')
        
        logger.info(f"📈 Grade change: {donor_id} {old_grade} → {new_grade}")
        
        # Check if upgraded to A tier
        a_grades = ['A++', 'A+', 'A', 'A-']
        
        if new_grade in a_grades and old_grade not in a_grades:
            logger.info(f"🎯 Upgraded to A-tier, triggering enrichment")
            await self.handle_priority_enrichment({
                'donor_id': donor_id,
                'reason': f'grade_upgrade_{new_grade}'
            })
    
    async def publish_enrichment_result(self, result: Dict):
        """Publish enrichment result to event bus"""
        if result.get('phone') or result.get('email'):
            await self.redis_client.publish(
                'e50.contact.enriched',
                json.dumps({
                    'donor_id': result.get('donor_id'),
                    'phone': result.get('phone'),
                    'phone_verified': result.get('phone_verified', False),
                    'email': result.get('email'),
                    'email_verified': result.get('email_verified', False),
                    'sources': result.get('sources_used', []),
                    'timestamp': datetime.now().isoformat()
                })
            )
    
    async def check_budget(self) -> bool:
        """Check if monthly budget allows more enrichment"""
        conn = self.engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        current_month = datetime.now().strftime('%Y-%m')
        
        cursor.execute("""
            SELECT COALESCE(SUM(cost), 0) as spent
            FROM e50_cost_log
            WHERE month_year = %s
        """, (current_month,))
        
        spent = cursor.fetchone()['spent']
        budget = self.control_settings.get('monthly_budget', 350)
        stop_pct = self.control_settings.get('auto_stop_percent', 100)
        
        stop_amount = budget * (stop_pct / 100)
        
        return spent < stop_amount
    
    async def log_cost(self, source: str, operation: str, cost: float, 
                       donor_id: str = None, prospect_id: str = None,
                       campaign_id: str = None):
        """Log enrichment cost for budget tracking"""
        conn = self.engine.connect_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO e50_cost_log 
            (source, operation, cost, donor_id, prospect_id, campaign_id)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (source, operation, cost, donor_id, prospect_id, campaign_id))
        conn.commit()
        
        # Publish to Brain for tracking
        await self.redis_client.publish(
            'e50.cost.logged',
            json.dumps({
                'source': source,
                'operation': operation,
                'cost': cost,
                'timestamp': datetime.now().isoformat()
            })
        )
    
    def stop(self):
        """Stop listening"""
        self.running = False
        logger.info("👋 E50 Brain integration stopped")


# ============================================================================
# E15 CONTACT DIRECTORY INTEGRATION
# ============================================================================

class E50ContactDirectoryIntegration:
    """
    Integration with E15 Contact Directory
    
    Provides:
    - Contact enrichment status lookup
    - On-demand enrichment triggers
    - Enrichment history display
    """
    
    def __init__(self, engine: 'ContactIntelligenceEngine'):
        self.engine = engine
    
    async def get_enrichment_status(self, contact_id: str) -> Dict:
        """
        Get enrichment status for contact display in E15
        
        Returns data for Contact Directory's enrichment panel:
        - Current phone/email
        - Verification status
        - Last enrichment date
        - Sources used
        - Enrichment history
        """
        conn = self.engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get enrichment record
        cursor.execute("""
            SELECT 
                donor_id,
                cell_phone,
                phone_verified,
                email,
                email_verified,
                last_enriched_at,
                enrichment_sources,
                enrichment_count
            FROM e50_enrichment_records
            WHERE donor_id = %s
        """, (contact_id,))
        
        record = cursor.fetchone()
        
        if not record:
            return {
                'status': 'not_enriched',
                'can_enrich': True,
                'message': 'Contact has not been enriched'
            }
        
        # Get enrichment history
        cursor.execute("""
            SELECT 
                source, operation, cost, created_at
            FROM e50_cost_log
            WHERE donor_id = %s
            ORDER BY created_at DESC
            LIMIT 10
        """, (contact_id,))
        
        history = cursor.fetchall()
        
        return {
            'status': 'enriched',
            'phone': record['cell_phone'],
            'phone_verified': record['phone_verified'],
            'email': record['email'],
            'email_verified': record['email_verified'],
            'last_enriched': record['last_enriched_at'].isoformat() if record['last_enriched_at'] else None,
            'sources': record['enrichment_sources'] or [],
            'enrichment_count': record['enrichment_count'] or 0,
            'history': [
                {
                    'source': h['source'],
                    'operation': h['operation'],
                    'cost': float(h['cost']),
                    'date': h['created_at'].isoformat()
                }
                for h in history
            ],
            'can_enrich': True
        }
    
    async def trigger_enrichment(self, contact_id: str, user: str = None) -> Dict:
        """
        Trigger on-demand enrichment from E15 Contact Directory
        
        Called when user clicks "Enrich Contact" button
        """
        logger.info(f"👆 Manual enrichment triggered for {contact_id} by {user}")
        
        result = await self.engine.enrich_donor(contact_id)
        
        return {
            'success': result.get('status') != 'failed',
            'phone_found': bool(result.get('phone')),
            'email_found': bool(result.get('email')),
            'sources_used': result.get('sources_used', []),
            'cost': result.get('total_cost', 0)
        }


# ============================================================================
# NCOA / CHANGE OF ADDRESS INTEGRATION
# ============================================================================

class NCOAProvider:
    """
    National Change of Address (NCOA) integration.
    
    USPS NCOA captures address changes filed with USPS (18-month lookback).
    We integrate with NCOA processors to:
    1. Identify donors who have moved
    2. Get their new addresses
    3. Update our database
    4. Flag deceased (if address forwarded to estate)
    
    NCOA Providers (in order of preference):
    - SmartyStreets ($0.01-0.05/record) - Best API
    - Melissa Data ($0.02-0.04/record) - Good coverage
    - Lob ($0.03/record) - Good for mail campaigns
    - AccuZIP (batch pricing) - Cheapest for large volumes
    """
    
    def __init__(self):
        self.smarty_auth_id = os.getenv('SMARTY_AUTH_ID', '')
        self.smarty_auth_token = os.getenv('SMARTY_AUTH_TOKEN', '')
        self.melissa_api_key = os.getenv('MELISSA_API_KEY', '')
        self.lob_api_key = os.getenv('LOB_API_KEY', '')
        
    async def check_ncoa_smarty(self, address: Dict) -> Dict:
        """
        Check NCOA status via SmartyStreets.
        
        Returns:
        {
            "moved": true/false,
            "move_type": "individual" | "family" | "business",
            "move_effective_date": "2025-06-15",
            "new_address": {
                "line1": "456 New St",
                "city": "Charlotte",
                "state": "NC",
                "zip": "28202"
            },
            "dpv_match": "Y",  # Delivery Point Validation
            "vacant": false,
            "deceased": false  # If forwarded to estate
        }
        """
        if not self.smarty_auth_id:
            return {'error': 'SmartyStreets not configured'}
        
        import aiohttp
        
        url = "https://us-street.api.smartystreets.com/street-address"
        params = {
            'auth-id': self.smarty_auth_id,
            'auth-token': self.smarty_auth_token,
            'street': address.get('line1', ''),
            'city': address.get('city', ''),
            'state': address.get('state', ''),
            'zipcode': address.get('zip', ''),
            'match': 'enhanced'  # Get NCOA data
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params) as resp:
                    if resp.status == 200:
                        results = await resp.json()
                        if results:
                            return self._parse_smarty_ncoa(results[0])
                    return {'moved': False}
        except Exception as e:
            logger.error(f"SmartyStreets NCOA error: {e}")
            return {'error': str(e)}
    
    def _parse_smarty_ncoa(self, result: Dict) -> Dict:
        """Parse SmartyStreets NCOA response"""
        analysis = result.get('analysis', {})
        
        ncoa_data = {
            'moved': False,
            'dpv_match': analysis.get('dpv_match_code', ''),
            'vacant': analysis.get('dpv_vacant', 'N') == 'Y',
            'active': analysis.get('active', 'Y') == 'Y'
        }
        
        # Check for NCOA move
        footnotes = analysis.get('footnotes', '')
        if 'A#' in footnotes:  # NCOA match - new address
            ncoa_data['moved'] = True
            ncoa_data['move_type'] = 'individual'
            
            # New address in components
            components = result.get('components', {})
            if components:
                ncoa_data['new_address'] = {
                    'line1': f"{components.get('primary_number', '')} {components.get('street_name', '')} {components.get('street_suffix', '')}".strip(),
                    'city': components.get('city_name', ''),
                    'state': components.get('state_abbreviation', ''),
                    'zip': components.get('zipcode', ''),
                    'zip_plus_4': components.get('plus4_code', '')
                }
        
        return ncoa_data
    
    async def check_ncoa_melissa(self, address: Dict) -> Dict:
        """
        Check NCOA via Melissa Data.
        Similar to SmartyStreets but different API structure.
        """
        if not self.melissa_api_key:
            return {'error': 'Melissa Data not configured'}
        
        import aiohttp
        
        url = "https://personator.melissadata.net/v3/WEB/ContactVerify/doContactVerify"
        params = {
            'id': self.melissa_api_key,
            'act': 'Check,Verify,Append,NCOALink',  # Enable NCOA
            'a1': address.get('line1', ''),
            'city': address.get('city', ''),
            'state': address.get('state', ''),
            'postal': address.get('zip', ''),
            'ctry': 'US',
            'format': 'json'
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        return self._parse_melissa_ncoa(data)
                    return {'moved': False}
        except Exception as e:
            logger.error(f"Melissa NCOA error: {e}")
            return {'error': str(e)}
    
    def _parse_melissa_ncoa(self, data: Dict) -> Dict:
        """Parse Melissa Data NCOA response"""
        records = data.get('Records', [])
        if not records:
            return {'moved': False}
        
        record = records[0]
        results = record.get('Results', '')
        
        ncoa_data = {
            'moved': 'NS' in results,  # NS = NCOA move
            'address_type': record.get('AddressTypeCode', ''),
            'deliverable': 'AS01' in results or 'AS02' in results
        }
        
        if ncoa_data['moved']:
            ncoa_data['new_address'] = {
                'line1': record.get('AddressLine1', ''),
                'city': record.get('City', ''),
                'state': record.get('State', ''),
                'zip': record.get('PostalCode', '')[:5] if record.get('PostalCode') else ''
            }
            ncoa_data['move_effective_date'] = record.get('MoveEffectiveDate', '')
        
        return ncoa_data
    
    async def batch_ncoa_check(self, addresses: List[Dict], provider: str = 'smarty') -> List[Dict]:
        """
        Check multiple addresses for NCOA moves.
        More efficient than individual lookups.
        """
        results = []
        
        for addr in addresses:
            if provider == 'smarty':
                result = await self.check_ncoa_smarty(addr)
            elif provider == 'melissa':
                result = await self.check_ncoa_melissa(addr)
            else:
                result = {'error': f'Unknown provider: {provider}'}
            
            results.append({
                'original_address': addr,
                'ncoa_result': result
            })
        
        return results


class ChangeOfAddressManager:
    """
    Manages the Change of Address workflow for E50.
    
    QUARTERLY WORKFLOW:
    1. Pull all donors with addresses older than 6 months
    2. Run through NCOA to find movers
    3. Update addresses in database
    4. Flag deceased (estate forwards)
    5. Generate report
    
    REAL-TIME WORKFLOW:
    1. Before any direct mail campaign
    2. Before phone banking (wrong area codes)
    3. When donation returned/bounced
    """
    
    def __init__(self, engine: 'ContactIntelligenceEngine'):
        self.engine = engine
        self.ncoa = NCOAProvider()
        
    async def run_quarterly_ncoa(self, max_records: int = 10000) -> Dict:
        """
        Run quarterly NCOA check on donor database.
        
        Checks donors whose addresses haven't been verified in 6+ months.
        Returns summary of moves found and updates made.
        """
        logger.info(f"Starting quarterly NCOA check (max {max_records} records)")
        
        conn = self.engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get donors needing NCOA check
        cursor.execute("""
            SELECT 
                d.id as donor_id,
                d.full_name,
                d.address_line1,
                d.address_line2,
                d.city,
                d.state,
                d.zip_code,
                e.ncoa_last_checked
            FROM broyhillgop.donors d
            LEFT JOIN e50_enrichment_results e ON d.id = e.donor_id
            WHERE d.address_line1 IS NOT NULL
              AND d.state = 'NC'
              AND (e.ncoa_last_checked IS NULL 
                   OR e.ncoa_last_checked < NOW() - INTERVAL '6 months')
            ORDER BY d.amount_grade_state DESC NULLS LAST  -- High value first
            LIMIT %s
        """, (max_records,))
        
        donors = cursor.fetchall()
        logger.info(f"Found {len(donors)} donors needing NCOA check")
        
        results = {
            'total_checked': 0,
            'moves_found': 0,
            'addresses_updated': 0,
            'deceased_flagged': 0,
            'errors': 0,
            'cost_estimate': 0.0
        }
        
        for donor in donors:
            try:
                address = {
                    'line1': donor['address_line1'],
                    'line2': donor.get('address_line2', ''),
                    'city': donor['city'],
                    'state': donor['state'],
                    'zip': donor['zip_code']
                }
                
                # Check NCOA (prefer SmartyStreets)
                ncoa_result = await self.ncoa.check_ncoa_smarty(address)
                
                if ncoa_result.get('error'):
                    # Fallback to Melissa
                    ncoa_result = await self.ncoa.check_ncoa_melissa(address)
                
                results['total_checked'] += 1
                results['cost_estimate'] += 0.03  # ~$0.03 per lookup
                
                if ncoa_result.get('moved'):
                    results['moves_found'] += 1
                    
                    # Update donor address
                    new_addr = ncoa_result.get('new_address', {})
                    if new_addr:
                        await self._update_donor_address(
                            donor['donor_id'],
                            new_addr,
                            ncoa_result
                        )
                        results['addresses_updated'] += 1
                
                if ncoa_result.get('deceased'):
                    results['deceased_flagged'] += 1
                    await self._flag_deceased(donor['donor_id'], 'NCOA_ESTATE_FORWARD')
                
                # Record NCOA check
                cursor.execute("""
                    INSERT INTO e50_enrichment_results (donor_id, ncoa_last_checked, ncoa_result)
                    VALUES (%s, NOW(), %s)
                    ON CONFLICT (donor_id) DO UPDATE SET
                        ncoa_last_checked = NOW(),
                        ncoa_result = EXCLUDED.ncoa_result
                """, (donor['donor_id'], json.dumps(ncoa_result)))
                
                conn.commit()
                
            except Exception as e:
                logger.error(f"NCOA check error for {donor['donor_id']}: {e}")
                results['errors'] += 1
        
        conn.close()
        
        logger.info(f"NCOA check complete: {results}")
        return results
    
    async def check_single_address(self, donor_id: str) -> Dict:
        """Check NCOA for a single donor's address"""
        conn = self.engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT id, full_name, address_line1, address_line2, city, state, zip_code
            FROM broyhillgop.donors
            WHERE id = %s
        """, (donor_id,))
        
        donor = cursor.fetchone()
        conn.close()
        
        if not donor:
            return {'error': 'Donor not found'}
        
        address = {
            'line1': donor['address_line1'],
            'line2': donor.get('address_line2', ''),
            'city': donor['city'],
            'state': donor['state'],
            'zip': donor['zip_code']
        }
        
        return await self.ncoa.check_ncoa_smarty(address)
    
    async def pre_campaign_ncoa(self, campaign_id: str) -> Dict:
        """
        Run NCOA check before a direct mail campaign.
        Integrates with E33 Direct Mail system.
        """
        logger.info(f"Running pre-campaign NCOA for campaign {campaign_id}")
        
        conn = self.engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get recipients from E33 mail campaign
        cursor.execute("""
            SELECT 
                mp.piece_id,
                mp.recipient_id,
                mp.address_line1,
                mp.address_line2,
                mp.city,
                mp.state,
                mp.zip_code
            FROM mail_pieces mp
            WHERE mp.campaign_id = %s
              AND mp.ncoa_action IS NULL
        """, (campaign_id,))
        
        pieces = cursor.fetchall()
        
        results = {
            'total_checked': len(pieces),
            'moves_found': 0,
            'addresses_updated': 0,
            'undeliverable': 0
        }
        
        for piece in pieces:
            address = {
                'line1': piece['address_line1'],
                'city': piece['city'],
                'state': piece['state'],
                'zip': piece['zip_code']
            }
            
            ncoa_result = await self.ncoa.check_ncoa_smarty(address)
            
            if ncoa_result.get('moved'):
                results['moves_found'] += 1
                new_addr = ncoa_result.get('new_address', {})
                
                # Update mail piece with new address
                cursor.execute("""
                    UPDATE mail_pieces SET
                        address_line1 = %s,
                        city = %s,
                        state = %s,
                        zip_code = %s,
                        ncoa_action = 'UPDATED',
                        address_validated = true
                    WHERE piece_id = %s
                """, (
                    new_addr.get('line1'),
                    new_addr.get('city'),
                    new_addr.get('state'),
                    new_addr.get('zip'),
                    piece['piece_id']
                ))
                results['addresses_updated'] += 1
                
            elif ncoa_result.get('vacant') or not ncoa_result.get('deliverable', True):
                results['undeliverable'] += 1
                cursor.execute("""
                    UPDATE mail_pieces SET
                        deliverability = 'undeliverable',
                        ncoa_action = 'VACANT'
                    WHERE piece_id = %s
                """, (piece['piece_id'],))
            else:
                cursor.execute("""
                    UPDATE mail_pieces SET
                        ncoa_action = 'NO_MOVE',
                        address_validated = true
                    WHERE piece_id = %s
                """, (piece['piece_id'],))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Pre-campaign NCOA complete: {results}")
        return results
    
    async def _update_donor_address(self, donor_id: str, new_address: Dict, ncoa_result: Dict):
        """Update donor's address in database with NCOA data"""
        conn = self.engine.connect_db()
        cursor = conn.cursor()
        
        # Archive old address first
        cursor.execute("""
            INSERT INTO e50_address_history (
                donor_id, old_address_line1, old_city, old_state, old_zip,
                new_address_line1, new_city, new_state, new_zip,
                change_source, change_date
            )
            SELECT 
                id, address_line1, city, state, zip_code,
                %s, %s, %s, %s,
                'NCOA', NOW()
            FROM broyhillgop.donors WHERE id = %s
        """, (
            new_address.get('line1'),
            new_address.get('city'),
            new_address.get('state'),
            new_address.get('zip'),
            donor_id
        ))
        
        # Update donor record
        cursor.execute("""
            UPDATE broyhillgop.donors SET
                address_line1 = %s,
                city = %s,
                state = %s,
                zip_code = %s,
                updated_at = NOW()
            WHERE id = %s
        """, (
            new_address.get('line1'),
            new_address.get('city'),
            new_address.get('state'),
            new_address.get('zip'),
            donor_id
        ))
        
        conn.commit()
        conn.close()
    
    async def _flag_deceased(self, donor_id: str, source: str):
        """Flag donor as deceased based on NCOA estate forward"""
        conn = self.engine.connect_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO e50_deceased_records (donor_id, source, detected_at, confidence_score)
            VALUES (%s, %s, NOW(), 0.7)
            ON CONFLICT (donor_id) DO UPDATE SET
                additional_sources = array_append(
                    COALESCE(e50_deceased_records.additional_sources, '{}'), 
                    %s
                )
        """, (donor_id, source, source))
        
        cursor.execute("""
            UPDATE broyhillgop.donors SET
                deceased = true,
                deceased_date = NOW(),
                updated_at = NOW()
            WHERE id = %s
        """, (donor_id,))
        
        conn.commit()
        conn.close()


# Add NCOA schema additions
E50_NCOA_SCHEMA = """
-- Address History (for NCOA tracking)
CREATE TABLE IF NOT EXISTS e50_address_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    
    -- Old address
    old_address_line1 VARCHAR(255),
    old_address_line2 VARCHAR(255),
    old_city VARCHAR(100),
    old_state VARCHAR(2),
    old_zip VARCHAR(10),
    
    -- New address
    new_address_line1 VARCHAR(255),
    new_address_line2 VARCHAR(255),
    new_city VARCHAR(100),
    new_state VARCHAR(2),
    new_zip VARCHAR(10),
    
    -- Change tracking
    change_source VARCHAR(50),  -- NCOA, DONOR_UPDATE, RNC_SYNC, etc.
    change_date TIMESTAMP DEFAULT NOW(),
    move_type VARCHAR(50),  -- individual, family, business
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_e50_addr_history_donor ON e50_address_history(donor_id);
CREATE INDEX IF NOT EXISTS idx_e50_addr_history_date ON e50_address_history(change_date);


-- Add NCOA fields to enrichment results
ALTER TABLE e50_enrichment_results 
    ADD COLUMN IF NOT EXISTS ncoa_last_checked TIMESTAMP,
    ADD COLUMN IF NOT EXISTS ncoa_result JSONB,
    ADD COLUMN IF NOT EXISTS address_verified BOOLEAN DEFAULT false;


-- View: Donors with address changes in last 90 days
CREATE OR REPLACE VIEW e50_v_recent_movers AS
SELECT 
    ah.donor_id,
    d.full_name,
    d.amount_grade_state,
    ah.old_city || ', ' || ah.old_state as moved_from,
    ah.new_city || ', ' || ah.new_state as moved_to,
    ah.change_source,
    ah.change_date
FROM e50_address_history ah
JOIN broyhillgop.donors d ON ah.donor_id = d.id
WHERE ah.change_date > NOW() - INTERVAL '90 days'
ORDER BY ah.change_date DESC;


-- View: Donors needing NCOA check
CREATE OR REPLACE VIEW e50_v_ncoa_needed AS
SELECT 
    d.id as donor_id,
    d.full_name,
    d.address_line1,
    d.city,
    d.state,
    d.amount_grade_state,
    e.ncoa_last_checked,
    EXTRACT(DAYS FROM NOW() - COALESCE(e.ncoa_last_checked, d.created_at)) as days_since_check
FROM broyhillgop.donors d
LEFT JOIN e50_enrichment_results e ON d.id = e.donor_id
WHERE d.address_line1 IS NOT NULL
  AND d.state = 'NC'
  AND d.deceased IS NOT TRUE
  AND (e.ncoa_last_checked IS NULL OR e.ncoa_last_checked < NOW() - INTERVAL '6 months')
ORDER BY 
    CASE d.amount_grade_state 
        WHEN 'A++' THEN 1 WHEN 'A+' THEN 2 WHEN 'A' THEN 3 
        WHEN 'A-' THEN 4 WHEN 'B+' THEN 5 WHEN 'B' THEN 6
        ELSE 10 
    END;
"""




class SocialMediaProspectEnricher:
    """
    Integrates E50 with the Social Media AI Agent systems:
    
    E44 Social Intelligence (Prospect Discovery):
    - Scrapes Twitter/Facebook/LinkedIn/Instagram for conservative prospects
    - Scores them 1-10 on conservative likelihood
    - Finds 5,000-15,000 prospects/month
    - Triggers: prospect.discovered, prospect.enriched
    
    E19 Social Media Manager (Engagement):
    - Posts to 4 platforms for 5,000 candidates
    - AI voice personalization
    - Nightly approval workflow
    - Triggers: social.engagement.recorded
    
    E50's Role (Contact Intelligence):
    - When E44 discovers a prospect → E50 enriches with phone/email
    - When E19 gets engagement → E50 looks up engager's contact info
    - Feeds enriched contacts back to E1 Donor Intelligence
    """
    
    def __init__(self, engine: 'ContactIntelligenceEngine'):
        self.engine = engine
        self.redis_client = None
        
    async def connect_event_bus(self):
        """Connect to Redis event bus for E44/E19 events"""
        import redis.asyncio as redis
        self.redis_client = redis.Redis(
            host=os.getenv('REDIS_HOST', 'localhost'),
            port=int(os.getenv('REDIS_PORT', 6379)),
            db=0
        )
        
    async def listen_for_prospects(self):
        """
        Listen for prospect.discovered events from E44 Social Intelligence.
        
        E44 publishes when it finds a conservative prospect on social media.
        E50 then enriches with phone/email using the waterfall:
        1. RNC DataTrust (FREE) - match by name/address if available
        2. Apollo (if high score) - get work email/phone
        3. BetterContact (if high score) - verify phone
        """
        if not self.redis_client:
            await self.connect_event_bus()
            
        pubsub = self.redis_client.pubsub()
        await pubsub.subscribe('prospect.discovered')
        
        logger.info("E50 listening for E44 prospect.discovered events")
        
        async for message in pubsub.listen():
            if message['type'] == 'message':
                try:
                    prospect = json.loads(message['data'])
                    await self.enrich_social_prospect(prospect)
                except Exception as e:
                    logger.error(f"Error processing prospect: {e}")
    
    async def enrich_social_prospect(self, prospect: Dict) -> Dict:
        """
        Enrich a prospect discovered by E44 Social Intelligence.
        
        Prospect data from E44:
        {
            "prospect_id": "uuid",
            "platform": "twitter",  # twitter, facebook, linkedin, instagram
            "username": "@conservative_voter",
            "display_name": "John Smith",
            "bio": "Proud American, 2A supporter...",
            "location": "Raleigh, NC",
            "conservative_score": 8.5,  # 1-10 scale
            "followers": 1234,
            "posts_analyzed": 50,
            "scraped_at": "2026-01-09T12:00:00Z"
        }
        
        E50 enrichment adds:
        - First/last name parsing
        - Phone number (if findable)
        - Email address (if findable)
        - Voter file match
        - Donor history match
        """
        logger.info(f"Enriching E44 prospect: {prospect.get('display_name')}")
        
        # Parse name from display name
        name_parts = self._parse_display_name(prospect.get('display_name', ''))
        
        # Parse location
        location = self._parse_location(prospect.get('location', ''))
        
        # Start enrichment
        enriched = {
            'prospect_id': prospect.get('prospect_id'),
            'platform': prospect.get('platform'),
            'username': prospect.get('username'),
            'conservative_score': prospect.get('conservative_score', 0),
            'enrichment_status': 'pending',
            'sources_used': []
        }
        
        # Only enrich high-score prospects (7+ out of 10)
        if prospect.get('conservative_score', 0) >= 7:
            
            # Step 1: Try RNC DataTrust (FREE!)
            if name_parts.get('first_name') and name_parts.get('last_name'):
                rnc_data = await self.engine.rnc.lookup_voter(
                    first_name=name_parts['first_name'],
                    last_name=name_parts['last_name'],
                    city=location.get('city'),
                    state=location.get('state', 'NC')
                )
                
                if rnc_data:
                    enriched['sources_used'].append('rnc_datatrust')
                    enriched['phone'] = rnc_data.get('cell_phone') or rnc_data.get('phone')
                    enriched['email'] = rnc_data.get('email')
                    enriched['voter_id'] = rnc_data.get('voter_id')
                    enriched['party'] = rnc_data.get('party')
                    enriched['voter_score'] = rnc_data.get('voter_score')
            
            # Step 2: If high score (8+) and still missing contact, try paid
            if prospect.get('conservative_score', 0) >= 8:
                if not enriched.get('email'):
                    # Try Apollo for work email
                    linkedin_url = prospect.get('linkedin_url')
                    apollo_data = await self.engine.apollo.enrich_person(
                        first_name=name_parts.get('first_name', ''),
                        last_name=name_parts.get('last_name', ''),
                        reveal_phone=not enriched.get('phone')
                    )
                    
                    if apollo_data:
                        enriched['sources_used'].append('apollo')
                        if apollo_data.get('email'):
                            enriched['work_email'] = apollo_data['email']
                        if apollo_data.get('phone'):
                            enriched['phone'] = apollo_data['phone']
                        if apollo_data.get('title'):
                            enriched['occupation'] = apollo_data['title']
                        if apollo_data.get('company'):
                            enriched['employer'] = apollo_data['company']
                
                if not enriched.get('phone'):
                    # Try BetterContact for phone
                    bc_data = await self.engine.bettercontact.enrich_contact(
                        first_name=name_parts.get('first_name', ''),
                        last_name=name_parts.get('last_name', ''),
                        company=enriched.get('employer'),
                        find_email=False,
                        find_phone=True
                    )
                    
                    if bc_data and bc_data.get('matched'):
                        enriched['sources_used'].append('bettercontact')
                        if bc_data.get('phone'):
                            enriched['phone'] = bc_data['phone']
                            enriched['phone_verified'] = bc_data.get('phone_verified', False)
        
        # Determine enrichment status
        if enriched.get('phone') or enriched.get('email'):
            enriched['enrichment_status'] = 'success'
        elif enriched['sources_used']:
            enriched['enrichment_status'] = 'partial'
        else:
            enriched['enrichment_status'] = 'failed'
        
        # Publish enriched prospect back to event bus
        await self._publish_enriched_prospect(enriched)
        
        # Store in database
        await self._store_enriched_prospect(prospect, enriched)
        
        return enriched
    
    async def listen_for_engagers(self):
        """
        Listen for social.engagement.recorded events from E19.
        
        E19 publishes when someone likes/comments/shares a candidate's post.
        E50 tries to identify and enrich these engagers as potential donors.
        """
        if not self.redis_client:
            await self.connect_event_bus()
            
        pubsub = self.redis_client.pubsub()
        await pubsub.subscribe('social.engagement.recorded')
        
        logger.info("E50 listening for E19 social.engagement.recorded events")
        
        async for message in pubsub.listen():
            if message['type'] == 'message':
                try:
                    engagement = json.loads(message['data'])
                    await self.enrich_social_engager(engagement)
                except Exception as e:
                    logger.error(f"Error processing engager: {e}")
    
    async def enrich_social_engager(self, engagement: Dict) -> Dict:
        """
        Enrich a user who engaged with a candidate's post.
        
        Engagement data from E19:
        {
            "engagement_id": "uuid",
            "post_id": "uuid",
            "candidate_id": "uuid",
            "platform": "facebook",
            "engagement_type": "like",  # like, comment, share
            "user_id": "facebook_user_id",
            "user_name": "John Smith",
            "user_profile_url": "https://facebook.com/johnsmith",
            "comment_text": "Great message!",  # if comment
            "engaged_at": "2026-01-09T12:00:00Z"
        }
        
        We try to match this engager to:
        1. Existing donor in our database
        2. NC voter file
        3. New prospect to cultivate
        """
        logger.info(f"Processing E19 engager: {engagement.get('user_name')}")
        
        # Parse name
        name_parts = self._parse_display_name(engagement.get('user_name', ''))
        
        if not name_parts.get('first_name') or not name_parts.get('last_name'):
            return {'status': 'skipped', 'reason': 'Could not parse name'}
        
        conn = self.engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Step 1: Check if already a donor
        cursor.execute("""
            SELECT id, full_name, email, phone, amount_grade_state
            FROM broyhillgop.donors
            WHERE LOWER(first_name) = LOWER(%s)
              AND LOWER(last_name) = LOWER(%s)
              AND state = 'NC'
            LIMIT 1
        """, (name_parts['first_name'], name_parts['last_name']))
        
        existing = cursor.fetchone()
        
        if existing:
            # Already a donor - log the engagement for scoring
            cursor.execute("""
                INSERT INTO e50_social_engagements
                (donor_id, platform, engagement_type, candidate_id, engaged_at)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (
                existing['id'],
                engagement.get('platform'),
                engagement.get('engagement_type'),
                engagement.get('candidate_id'),
                engagement.get('engaged_at')
            ))
            conn.commit()
            
            return {
                'status': 'matched_donor',
                'donor_id': str(existing['id']),
                'grade': existing['amount_grade_state']
            }
        
        # Step 2: Not a donor - try to find in voter file via RNC
        rnc_data = await self.engine.rnc.lookup_voter(
            first_name=name_parts['first_name'],
            last_name=name_parts['last_name'],
            state='NC'
        )
        
        if rnc_data:
            # Found in voter file - create prospect
            prospect_data = {
                'source': 'social_engagement',
                'platform': engagement.get('platform'),
                'engagement_type': engagement.get('engagement_type'),
                'candidate_id': engagement.get('candidate_id'),
                'first_name': name_parts['first_name'],
                'last_name': name_parts['last_name'],
                'phone': rnc_data.get('cell_phone') or rnc_data.get('phone'),
                'email': rnc_data.get('email'),
                'voter_id': rnc_data.get('voter_id'),
                'party': rnc_data.get('party')
            }
            
            # Publish as new prospect
            await self.redis_client.publish(
                'prospect.enriched',
                json.dumps(prospect_data)
            )
            
            return {
                'status': 'new_prospect',
                'has_phone': bool(prospect_data.get('phone')),
                'has_email': bool(prospect_data.get('email'))
            }
        
        return {'status': 'not_found'}
    
    def _parse_display_name(self, display_name: str) -> Dict:
        """Parse social media display name into first/last name"""
        if not display_name:
            return {}
            
        # Remove emojis and special characters
        import re
        clean_name = re.sub(r'[^\w\s]', '', display_name).strip()
        
        parts = clean_name.split()
        if len(parts) >= 2:
            return {
                'first_name': parts[0],
                'last_name': parts[-1],
                'full_name': clean_name
            }
        elif len(parts) == 1:
            return {
                'first_name': parts[0],
                'full_name': clean_name
            }
        return {}
    
    def _parse_location(self, location: str) -> Dict:
        """Parse social media location into city/state"""
        if not location:
            return {}
            
        # Common patterns: "Raleigh, NC", "Charlotte, North Carolina", "NC"
        import re
        
        # State abbreviations
        state_map = {
            'north carolina': 'NC', 'nc': 'NC',
            'south carolina': 'SC', 'sc': 'SC',
            'virginia': 'VA', 'va': 'VA',
            # Add more as needed
        }
        
        location_lower = location.lower().strip()
        
        # Check for state
        state = None
        for pattern, abbrev in state_map.items():
            if pattern in location_lower:
                state = abbrev
                break
        
        # Try to extract city
        city = None
        if ',' in location:
            city = location.split(',')[0].strip()
        
        return {
            'city': city,
            'state': state or 'NC'  # Default to NC
        }
    
    async def _publish_enriched_prospect(self, enriched: Dict):
        """Publish enriched prospect to event bus"""
        if self.redis_client:
            await self.redis_client.publish(
                'prospect.enriched',
                json.dumps(enriched)
            )
    
    async def _store_enriched_prospect(self, prospect: Dict, enriched: Dict):
        """Store enriched prospect in database"""
        conn = self.engine.connect_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO e50_social_prospects
            (prospect_id, platform, username, display_name, 
             conservative_score, phone, email, voter_id,
             enrichment_status, sources_used, enriched_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
            ON CONFLICT (prospect_id) DO UPDATE SET
                phone = EXCLUDED.phone,
                email = EXCLUDED.email,
                voter_id = EXCLUDED.voter_id,
                enrichment_status = EXCLUDED.enrichment_status,
                sources_used = EXCLUDED.sources_used,
                enriched_at = NOW()
        """, (
            prospect.get('prospect_id'),
            prospect.get('platform'),
            prospect.get('username'),
            prospect.get('display_name'),
            prospect.get('conservative_score'),
            enriched.get('phone'),
            enriched.get('email') or enriched.get('work_email'),
            enriched.get('voter_id'),
            enriched.get('enrichment_status'),
            enriched.get('sources_used', [])
        ))
        conn.commit()


# Add social prospects table to schema
E50_SOCIAL_SCHEMA_ADDITIONS = """
-- Social Media Prospect Enrichment (E44 → E50)
CREATE TABLE IF NOT EXISTS e50_social_prospects (
    prospect_id UUID PRIMARY KEY,
    
    -- Social media source
    platform VARCHAR(20) NOT NULL,  -- twitter, facebook, linkedin, instagram
    username VARCHAR(100),
    display_name VARCHAR(255),
    profile_url TEXT,
    
    -- E44 scoring
    conservative_score DECIMAL(3,1),  -- 1.0-10.0
    followers INTEGER,
    posts_analyzed INTEGER,
    
    -- E50 enrichment
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    phone_verified BOOLEAN DEFAULT false,
    email VARCHAR(255),
    work_email VARCHAR(255),
    voter_id VARCHAR(50),
    party VARCHAR(20),
    
    -- Professional (from Apollo)
    occupation VARCHAR(255),
    employer VARCHAR(255),
    
    -- Status
    enrichment_status VARCHAR(20) DEFAULT 'pending',
    sources_used TEXT[] DEFAULT '{}',
    
    -- Conversion tracking
    converted_to_donor BOOLEAN DEFAULT false,
    donor_id UUID,
    converted_at TIMESTAMP,
    
    -- Timestamps
    scraped_at TIMESTAMP,
    enriched_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_e50_social_platform ON e50_social_prospects(platform);
CREATE INDEX IF NOT EXISTS idx_e50_social_score ON e50_social_prospects(conservative_score);
CREATE INDEX IF NOT EXISTS idx_e50_social_status ON e50_social_prospects(enrichment_status);
CREATE INDEX IF NOT EXISTS idx_e50_social_converted ON e50_social_prospects(converted_to_donor);


-- Social Engagement Tracking (E19 → E50)
CREATE TABLE IF NOT EXISTS e50_social_engagements (
    engagement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Linked donor (if matched)
    donor_id UUID REFERENCES broyhillgop.donors(id),
    
    -- Engagement details
    platform VARCHAR(20) NOT NULL,
    engagement_type VARCHAR(20) NOT NULL,  -- like, comment, share, follow
    candidate_id UUID,
    post_id UUID,
    
    -- Timestamps
    engaged_at TIMESTAMP,
    recorded_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, platform, engagement_type, post_id)
);

CREATE INDEX IF NOT EXISTS idx_e50_engage_donor ON e50_social_engagements(donor_id);
CREATE INDEX IF NOT EXISTS idx_e50_engage_candidate ON e50_social_engagements(candidate_id);


-- View: Social prospects ready for outreach
CREATE OR REPLACE VIEW e50_v_social_prospects_ready AS
SELECT 
    sp.*,
    CASE 
        WHEN sp.phone IS NOT NULL AND sp.phone_verified THEN 'phone_ready'
        WHEN sp.phone IS NOT NULL THEN 'phone_unverified'
        WHEN sp.email IS NOT NULL THEN 'email_only'
        ELSE 'no_contact'
    END as outreach_status
FROM e50_social_prospects sp
WHERE sp.enrichment_status = 'success'
  AND sp.converted_to_donor = false
  AND sp.conservative_score >= 7
ORDER BY sp.conservative_score DESC, sp.enriched_at DESC;
""";




# ============================================================================
# MAIN & CLI
# ============================================================================

async def main():
    """Main entry point for E50 Contact Intelligence Engine"""
    import argparse
    
    parser = argparse.ArgumentParser(description='E50 Contact Intelligence Engine')
    parser.add_argument('--job', choices=[
        # Core jobs
        'enrich_donor',
        'scheduled_enrichment', 
        'deceased_check',
        
        # Brain integration
        'listen_brain',          # Listen for E20 Brain commands
        
        # Social media integration
        'listen_prospects',      # Listen for E44 prospects
        'listen_engagers',       # Listen for E19 engagements
        
        # NCOA / Change of Address
        'ncoa_quarterly',        # Run quarterly NCOA check
        'ncoa_single',           # Check single donor address
        'ncoa_campaign',         # Pre-campaign NCOA (E33 integration)
        
        # Scheduled jobs
        'rnc_sync',
        'monthly_enrich',
        'quarterly_enrich',
        
        # Debug/info
        'status',
        'budget'
    ], help='Job to run')
    parser.add_argument('--donor-id', help='Donor ID for single enrichment or NCOA')
    parser.add_argument('--campaign-id', help='Campaign ID for pre-campaign NCOA (E33)')
    parser.add_argument('--max-donors', type=int, default=100, help='Max donors to process')
    parser.add_argument('--grades', nargs='+', help='Grades to process')
    
    args = parser.parse_args()
    
    # Initialize components
    engine = ContactIntelligenceEngine()
    brain = E50BrainIntegration(engine)
    social = SocialMediaProspectEnricher(engine)
    scheduler = E50Scheduler(engine)
    e15 = E50ContactDirectoryIntegration(engine)
    
    if args.job == 'enrich_donor' and args.donor_id:
        result = await engine.enrich_donor(args.donor_id)
        print(json.dumps(result, indent=2, default=str))
        
    elif args.job == 'scheduled_enrichment':
        result = await engine.run_scheduled_enrichment(
            max_donors=args.max_donors,
            grades=args.grades
        )
        print(json.dumps(result, indent=2, default=str))
        
    elif args.job == 'deceased_check':
        result = await engine.run_deceased_check(max_donors=args.max_donors)
        print(json.dumps(result, indent=2, default=str))
        
    elif args.job == 'listen_brain':
        # Listen for E20 Intelligence Brain commands
        print("🧠 Starting E50 ↔ E20 Brain listener...")
        print("   Listening for: e20.enrich.priority, e20.enrich.batch,")
        print("                  e20.verify.campaign, e20.deceased.check")
        await brain.start_listening()
        
    elif args.job == 'listen_prospects':
        # Listen for E44 Social Intelligence prospects
        print("🔍 Starting E50 ↔ E44 prospect listener...")
        await social.listen_for_prospects()
        
    elif args.job == 'listen_engagers':
        # Listen for E19 Social Media Manager engagements
        print("👥 Starting E50 ↔ E19 engagement listener...")
        await social.listen_for_engagers()
    
    elif args.job == 'ncoa_quarterly':
        # Run quarterly NCOA check
        ncoa_mgr = ChangeOfAddressManager(engine)
        print(f"📬 Starting quarterly NCOA check (max {args.max_donors} records)...")
        result = await ncoa_mgr.run_quarterly_ncoa(max_records=args.max_donors)
        print("\n📊 NCOA RESULTS")
        print("=" * 40)
        print(f"Total Checked:      {result['total_checked']:,}")
        print(f"Moves Found:        {result['moves_found']:,}")
        print(f"Addresses Updated:  {result['addresses_updated']:,}")
        print(f"Deceased Flagged:   {result['deceased_flagged']:,}")
        print(f"Errors:             {result['errors']:,}")
        print(f"Est. Cost:          ${result['cost_estimate']:.2f}")
        
    elif args.job == 'ncoa_single' and args.donor_id:
        # Check single donor address
        ncoa_mgr = ChangeOfAddressManager(engine)
        print(f"📬 Checking NCOA for donor {args.donor_id}...")
        result = await ncoa_mgr.check_single_address(args.donor_id)
        print(json.dumps(result, indent=2, default=str))
        
    elif args.job == 'ncoa_campaign' and args.campaign_id:
        # Pre-campaign NCOA check (integrates with E33 Direct Mail)
        ncoa_mgr = ChangeOfAddressManager(engine)
        print(f"📬 Running pre-campaign NCOA for campaign {args.campaign_id}...")
        result = await ncoa_mgr.pre_campaign_ncoa(args.campaign_id)
        print("\n📊 PRE-CAMPAIGN NCOA RESULTS")
        print("=" * 40)
        print(f"Total Checked:      {result['total_checked']:,}")
        print(f"Moves Found:        {result['moves_found']:,}")
        print(f"Addresses Updated:  {result['addresses_updated']:,}")
        print(f"Undeliverable:      {result['undeliverable']:,}")
        
    elif args.job == 'rnc_sync':
        await scheduler.run_daily_jobs()
        
    elif args.job == 'monthly_enrich':
        await scheduler.run_monthly_jobs()
        
    elif args.job == 'quarterly_enrich':
        await scheduler.run_quarterly_jobs()
        
    elif args.job == 'status':
        # Show enrichment status
        conn = engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT 
                COUNT(*) as total_enriched,
                COUNT(*) FILTER (WHERE cell_phone IS NOT NULL) as with_phone,
                COUNT(*) FILTER (WHERE email IS NOT NULL) as with_email,
                COUNT(*) FILTER (WHERE phone_verified) as phone_verified,
                COUNT(*) FILTER (WHERE email_verified) as email_verified
            FROM e50_enrichment_records
        """)
        stats = cursor.fetchone()
        
        print("\n📊 E50 ENRICHMENT STATUS")
        print("=" * 40)
        print(f"Total Enriched:    {stats['total_enriched']:,}")
        print(f"With Phone:        {stats['with_phone']:,}")
        print(f"With Email:        {stats['with_email']:,}")
        print(f"Phone Verified:    {stats['phone_verified']:,}")
        print(f"Email Verified:    {stats['email_verified']:,}")
        
    elif args.job == 'budget':
        # Show budget status
        conn = engine.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        current_month = datetime.now().strftime('%Y-%m')
        
        cursor.execute("""
            SELECT 
                source,
                SUM(cost) as spent,
                COUNT(*) as records
            FROM e50_cost_log
            WHERE month_year = %s
            GROUP BY source
        """, (current_month,))
        
        by_source = cursor.fetchall()
        
        cursor.execute("""
            SELECT COALESCE(SUM(cost), 0) as total
            FROM e50_cost_log
            WHERE month_year = %s
        """, (current_month,))
        total = cursor.fetchone()['total']
        
        print(f"\n💰 E50 BUDGET STATUS ({current_month})")
        print("=" * 40)
        for row in by_source:
            print(f"{row['source']:20} ${row['spent']:8.2f} ({row['records']:,} records)")
        print("-" * 40)
        print(f"{'TOTAL':20} ${total:8.2f}")
        print(f"{'Budget':20} $350.00")
        print(f"{'Remaining':20} ${350.00 - float(total):8.2f}")
        
    else:
        # Default: Show help
        print("""
🔍 E50 CONTACT INTELLIGENCE ENGINE

USAGE:
  python ecosystem_50_contact_intelligence_engine.py --job <JOB>

JOBS:
  Core Operations:
    enrich_donor --donor-id <UUID>    Enrich single donor
    scheduled_enrichment              Run scheduled enrichment batch
    deceased_check                    Run SSDI deceased check
    
  Brain Integration:
    listen_brain                      Listen for E20 Brain commands
    
  Social Media Integration:
    listen_prospects                  Listen for E44 discovered prospects
    listen_engagers                   Listen for E19 engagement events
    
  Scheduled Jobs:
    rnc_sync                          Daily RNC DataTrust sync
    monthly_enrich                    Monthly A-tier enrichment
    quarterly_enrich                  Quarterly batch enrichment
    
  Info:
    status                            Show enrichment statistics
    budget                            Show budget usage

EXAMPLES:
  # Enrich a single donor
  python ecosystem_50_contact_intelligence_engine.py --job enrich_donor --donor-id abc-123
  
  # Start Brain listener (runs continuously)
  python ecosystem_50_contact_intelligence_engine.py --job listen_brain
  
  # Run quarterly enrichment for B-tier donors
  python ecosystem_50_contact_intelligence_engine.py --job quarterly_enrich --grades B+ B B-
        """)


if __name__ == "__main__":
    asyncio.run(main())

