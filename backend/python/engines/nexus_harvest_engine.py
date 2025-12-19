#!/usr/bin/env python3
"""
============================================================================
NEXUS HARVEST ENRICHMENT ENGINE
============================================================================
Processes 150K harvest records, matches to donors/volunteers, enriches data

INTEGRATIONS:
- E0 DataHub: Central data warehouse
- E1 Donor Intelligence: Enrichment append
- E5 Volunteer Management: Enrichment append  
- E20 Intelligence Brain: Priority control

FREE DATA SOURCES:
- NC SBOE: Voter registration, primary history
- FEC.gov: Contribution history
- NC Secretary of State: Business filings
- County Property: Property values
- SEC EDGAR: Executive data

============================================================================
"""

import os
import json
import uuid
import logging
import re
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, field
import hashlib

import psycopg2
from psycopg2.extras import RealDictCursor, Json

# Optional: HTTP client for API calls
try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('nexus.harvest')


# ============================================================================
# CONFIGURATION
# ============================================================================

class HarvestConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    
    # Batch sizes
    MATCH_BATCH_SIZE = 100
    ENRICH_BATCH_SIZE = 50
    
    # Matching thresholds
    EMAIL_MATCH_CONFIDENCE = 95.0
    PHONE_MATCH_CONFIDENCE = 90.0
    FACEBOOK_MATCH_CONFIDENCE = 98.0
    NAME_ZIP_CONFIDENCE = 75.0
    
    # Auto-verify threshold
    AUTO_VERIFY_THRESHOLD = 90.0
    
    # Rate limits (per hour)
    FEC_RATE_LIMIT = 1000
    NC_SBOE_RATE_LIMIT = 500


# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class HarvestRecord:
    harvest_id: str
    raw_email: Optional[str] = None
    raw_phone: Optional[str] = None
    raw_first_name: Optional[str] = None
    raw_last_name: Optional[str] = None
    raw_address: Optional[str] = None
    raw_city: Optional[str] = None
    raw_state: Optional[str] = None
    raw_zip: Optional[str] = None
    facebook_id: Optional[str] = None
    facebook_url: Optional[str] = None
    twitter_handle: Optional[str] = None
    instagram_handle: Optional[str] = None
    linkedin_url: Optional[str] = None
    enrichment_status: str = 'pending'
    enrichment_score: int = 0


@dataclass
class MatchResult:
    harvest_id: str
    match_type: str  # 'donor', 'volunteer', 'activist'
    match_id: str
    match_method: str  # 'email_exact', 'phone_exact', 'facebook_match', 'name_zip'
    confidence: float
    auto_verified: bool = False


@dataclass  
class EnrichmentResult:
    target_type: str
    target_id: str
    source: str
    success: bool
    data: Dict = field(default_factory=dict)
    fields_populated: List[str] = field(default_factory=list)
    error: Optional[str] = None


# ============================================================================
# NEXUS HARVEST ENGINE
# ============================================================================

class NexusHarvestEngine:
    """
    Processes harvest records for matching and enrichment
    Controlled by E20 Intelligence Brain
    """
    
    def __init__(self, db_url: str = None):
        self.db_url = db_url or HarvestConfig.DATABASE_URL
        logger.info("🌾 NEXUS Harvest Engine initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # HARVEST IMPORT
    # ========================================================================
    
    def import_harvest_batch(self, records: List[Dict], source_type: str, 
                            source_name: str = None) -> Dict:
        """
        Import a batch of harvest records
        """
        logger.info(f"📥 Importing {len(records)} harvest records from {source_type}")
        
        conn = self._get_db()
        cur = conn.cursor()
        
        # Create batch record
        batch_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO nexus_harvest_batches 
            (batch_id, source_type, source_file, total_records, status, started_at)
            VALUES (%s, %s, %s, %s, 'processing', NOW())
        """, (batch_id, source_type, source_name, len(records)))
        
        imported = 0
        duplicates = 0
        invalid = 0
        
        for record in records:
            try:
                # Normalize data
                normalized = self._normalize_record(record)
                
                # Check for duplicates
                if self._is_duplicate(normalized, cur):
                    duplicates += 1
                    continue
                
                # Insert record
                cur.execute("""
                    INSERT INTO nexus_harvest_records
                    (source_type, source_name, import_batch_id,
                     raw_first_name, raw_last_name, raw_email, raw_phone,
                     raw_address, raw_city, raw_state, raw_zip,
                     facebook_id, facebook_url, twitter_handle, 
                     instagram_handle, linkedin_url,
                     enrichment_status, enrichment_priority)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending', %s)
                """, (
                    source_type, source_name, batch_id,
                    normalized.get('first_name'),
                    normalized.get('last_name'),
                    normalized.get('email'),
                    normalized.get('phone'),
                    normalized.get('address'),
                    normalized.get('city'),
                    normalized.get('state', 'NC'),
                    normalized.get('zip'),
                    normalized.get('facebook_id'),
                    normalized.get('facebook_url'),
                    normalized.get('twitter_handle'),
                    normalized.get('instagram_handle'),
                    normalized.get('linkedin_url'),
                    self._calculate_priority(normalized)
                ))
                imported += 1
                
            except Exception as e:
                logger.error(f"Error importing record: {e}")
                invalid += 1
        
        # Update batch record
        cur.execute("""
            UPDATE nexus_harvest_batches SET
                rows_imported = %s,
                rows_duplicate = %s,
                rows_invalid = %s,
                status = 'completed',
                completed_at = NOW()
            WHERE batch_id = %s
        """, (imported, duplicates, invalid, batch_id))
        
        conn.commit()
        conn.close()
        
        result = {
            'batch_id': batch_id,
            'total': len(records),
            'imported': imported,
            'duplicates': duplicates,
            'invalid': invalid
        }
        
        logger.info(f"   Imported: {imported}, Duplicates: {duplicates}, Invalid: {invalid}")
        return result
    
    def _normalize_record(self, record: Dict) -> Dict:
        """Normalize raw record data"""
        normalized = {}
        
        # Name fields
        normalized['first_name'] = self._clean_string(
            record.get('first_name') or record.get('firstName') or record.get('fname')
        )
        normalized['last_name'] = self._clean_string(
            record.get('last_name') or record.get('lastName') or record.get('lname')
        )
        
        # Email
        email = record.get('email') or record.get('Email') or record.get('EMAIL')
        if email:
            normalized['email'] = email.lower().strip()
        
        # Phone - normalize to digits only
        phone = record.get('phone') or record.get('Phone') or record.get('mobile')
        if phone:
            normalized['phone'] = re.sub(r'[^0-9]', '', str(phone))
            if len(normalized['phone']) == 11 and normalized['phone'].startswith('1'):
                normalized['phone'] = normalized['phone'][1:]
        
        # Address
        normalized['address'] = self._clean_string(
            record.get('address') or record.get('street') or record.get('address1')
        )
        normalized['city'] = self._clean_string(record.get('city'))
        normalized['state'] = (record.get('state') or 'NC').upper()[:2]
        normalized['zip'] = str(record.get('zip') or record.get('zipcode') or '')[:5]
        
        # Social media
        normalized['facebook_id'] = record.get('facebook_id') or record.get('fb_id')
        normalized['facebook_url'] = record.get('facebook_url') or record.get('fb_url')
        normalized['twitter_handle'] = self._clean_handle(
            record.get('twitter') or record.get('twitter_handle')
        )
        normalized['instagram_handle'] = self._clean_handle(
            record.get('instagram') or record.get('ig_handle')
        )
        normalized['linkedin_url'] = record.get('linkedin') or record.get('linkedin_url')
        
        return normalized
    
    def _clean_string(self, value: Optional[str]) -> Optional[str]:
        if not value:
            return None
        return str(value).strip().title()
    
    def _clean_handle(self, value: Optional[str]) -> Optional[str]:
        if not value:
            return None
        handle = str(value).strip()
        if handle.startswith('@'):
            handle = handle[1:]
        return handle.lower() if handle else None
    
    def _is_duplicate(self, record: Dict, cur) -> bool:
        """Check if record already exists"""
        if record.get('email'):
            cur.execute("""
                SELECT 1 FROM nexus_harvest_records 
                WHERE LOWER(raw_email) = %s LIMIT 1
            """, (record['email'].lower(),))
            if cur.fetchone():
                return True
        
        if record.get('facebook_id'):
            cur.execute("""
                SELECT 1 FROM nexus_harvest_records 
                WHERE facebook_id = %s LIMIT 1
            """, (record['facebook_id'],))
            if cur.fetchone():
                return True
        
        return False
    
    def _calculate_priority(self, record: Dict) -> int:
        """Calculate enrichment priority (higher = process first)"""
        priority = 50
        
        if record.get('email'):
            priority += 20
        if record.get('phone'):
            priority += 15
        if record.get('facebook_id'):
            priority += 25
        if record.get('twitter_handle'):
            priority += 10
        if record.get('first_name') and record.get('last_name'):
            priority += 10
        if record.get('zip'):
            priority += 5
        
        return min(100, priority)
    
    # ========================================================================
    # MATCHING ENGINE
    # ========================================================================
    
    def run_matching_batch(self, batch_size: int = None) -> Dict:
        """
        Match harvest records to existing donors/volunteers
        """
        batch_size = batch_size or HarvestConfig.MATCH_BATCH_SIZE
        logger.info(f"🔍 Running matching batch (size: {batch_size})")
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get unmatched harvest records
        cur.execute("""
            SELECT * FROM nexus_harvest_records
            WHERE enrichment_status = 'pending'
            AND matched_donor_id IS NULL
            AND matched_volunteer_id IS NULL
            ORDER BY enrichment_priority DESC
            LIMIT %s
        """, (batch_size,))
        
        records = cur.fetchall()
        
        matched = 0
        unmatched = 0
        
        for record in records:
            matches = self._find_matches(record, cur)
            
            if matches:
                # Take best match
                best_match = max(matches, key=lambda x: x.confidence)
                
                # Update harvest record
                if best_match.match_type == 'donor':
                    cur.execute("""
                        UPDATE nexus_harvest_records SET
                            matched_donor_id = %s,
                            match_confidence = %s,
                            match_method = %s,
                            match_verified = %s,
                            enrichment_status = 'matched'
                        WHERE harvest_id = %s
                    """, (
                        best_match.match_id,
                        best_match.confidence,
                        best_match.match_method,
                        best_match.auto_verified,
                        record['harvest_id']
                    ))
                elif best_match.match_type == 'volunteer':
                    cur.execute("""
                        UPDATE nexus_harvest_records SET
                            matched_volunteer_id = %s,
                            match_confidence = %s,
                            match_method = %s,
                            match_verified = %s,
                            enrichment_status = 'matched'
                        WHERE harvest_id = %s
                    """, (
                        best_match.match_id,
                        best_match.confidence,
                        best_match.match_method,
                        best_match.auto_verified,
                        record['harvest_id']
                    ))
                
                matched += 1
                
                # If auto-verified, apply enrichment immediately
                if best_match.auto_verified:
                    self._apply_harvest_to_target(record, best_match, cur)
            else:
                # Mark as no match found
                cur.execute("""
                    UPDATE nexus_harvest_records SET
                        enrichment_status = 'no_match',
                        enrichment_attempts = enrichment_attempts + 1
                    WHERE harvest_id = %s
                """, (record['harvest_id'],))
                unmatched += 1
        
        conn.commit()
        conn.close()
        
        result = {
            'processed': len(records),
            'matched': matched,
            'unmatched': unmatched
        }
        
        logger.info(f"   Processed: {len(records)}, Matched: {matched}, Unmatched: {unmatched}")
        return result
    
    def _find_matches(self, record: Dict, cur) -> List[MatchResult]:
        """Find potential matches for a harvest record"""
        matches = []
        harvest_id = str(record['harvest_id'])
        
        # Email exact match to donors
        if record.get('raw_email'):
            cur.execute("""
                SELECT donor_id FROM donors 
                WHERE LOWER(email) = %s
            """, (record['raw_email'].lower(),))
            for row in cur.fetchall():
                matches.append(MatchResult(
                    harvest_id=harvest_id,
                    match_type='donor',
                    match_id=str(row['donor_id']),
                    match_method='email_exact',
                    confidence=HarvestConfig.EMAIL_MATCH_CONFIDENCE,
                    auto_verified=True
                ))
        
        # Phone exact match to donors
        if record.get('raw_phone') and len(record['raw_phone']) >= 10:
            phone_digits = re.sub(r'[^0-9]', '', record['raw_phone'])
            cur.execute("""
                SELECT donor_id FROM donors 
                WHERE REGEXP_REPLACE(phone, '[^0-9]', '', 'g') = %s
            """, (phone_digits,))
            for row in cur.fetchall():
                matches.append(MatchResult(
                    harvest_id=harvest_id,
                    match_type='donor',
                    match_id=str(row['donor_id']),
                    match_method='phone_exact',
                    confidence=HarvestConfig.PHONE_MATCH_CONFIDENCE,
                    auto_verified=True
                ))
        
        # Facebook ID match to donors
        if record.get('facebook_id'):
            cur.execute("""
                SELECT donor_id FROM donors 
                WHERE social_facebook_id = %s
            """, (record['facebook_id'],))
            for row in cur.fetchall():
                matches.append(MatchResult(
                    harvest_id=harvest_id,
                    match_type='donor',
                    match_id=str(row['donor_id']),
                    match_method='facebook_match',
                    confidence=HarvestConfig.FACEBOOK_MATCH_CONFIDENCE,
                    auto_verified=True
                ))
        
        # Name + ZIP match to donors (lower confidence, requires verification)
        if record.get('raw_first_name') and record.get('raw_last_name') and record.get('raw_zip'):
            cur.execute("""
                SELECT donor_id FROM donors 
                WHERE LOWER(first_name) = %s 
                AND LOWER(last_name) = %s
                AND zip = %s
            """, (
                record['raw_first_name'].lower(),
                record['raw_last_name'].lower(),
                record['raw_zip']
            ))
            for row in cur.fetchall():
                matches.append(MatchResult(
                    harvest_id=harvest_id,
                    match_type='donor',
                    match_id=str(row['donor_id']),
                    match_method='name_zip',
                    confidence=HarvestConfig.NAME_ZIP_CONFIDENCE,
                    auto_verified=False  # Requires manual verification
                ))
        
        # Also check volunteers with same logic
        if record.get('raw_email'):
            cur.execute("""
                SELECT volunteer_id FROM volunteers 
                WHERE LOWER(email) = %s
            """, (record['raw_email'].lower(),))
            for row in cur.fetchall():
                matches.append(MatchResult(
                    harvest_id=harvest_id,
                    match_type='volunteer',
                    match_id=str(row['volunteer_id']),
                    match_method='email_exact',
                    confidence=HarvestConfig.EMAIL_MATCH_CONFIDENCE,
                    auto_verified=True
                ))
        
        return matches
    
    def _apply_harvest_to_target(self, record: Dict, match: MatchResult, cur):
        """Apply harvest social data to matched record"""
        
        if match.match_type == 'donor':
            cur.execute("""
                UPDATE donors SET
                    social_facebook_url = COALESCE(social_facebook_url, %s),
                    social_facebook_id = COALESCE(social_facebook_id, %s),
                    social_twitter_handle = COALESCE(social_twitter_handle, %s),
                    social_instagram_handle = COALESCE(social_instagram_handle, %s),
                    social_linkedin_url = COALESCE(social_linkedin_url, %s),
                    nexus_harvest_id = %s,
                    nexus_enriched = TRUE,
                    nexus_enriched_at = NOW()
                WHERE donor_id = %s
            """, (
                record.get('facebook_url'),
                record.get('facebook_id'),
                record.get('twitter_handle'),
                record.get('instagram_handle'),
                record.get('linkedin_url'),
                record['harvest_id'],
                match.match_id
            ))
            
        elif match.match_type == 'volunteer':
            cur.execute("""
                UPDATE volunteers SET
                    social_facebook_url = COALESCE(social_facebook_url, %s),
                    social_twitter_handle = COALESCE(social_twitter_handle, %s),
                    social_instagram_handle = COALESCE(social_instagram_handle, %s),
                    social_linkedin_url = COALESCE(social_linkedin_url, %s),
                    nexus_harvest_id = %s,
                    nexus_enriched = TRUE,
                    nexus_enriched_at = NOW()
                WHERE volunteer_id = %s
            """, (
                record.get('facebook_url'),
                record.get('twitter_handle'),
                record.get('instagram_handle'),
                record.get('linkedin_url'),
                record['harvest_id'],
                match.match_id
            ))
    
    # ========================================================================
    # FREE DATA ENRICHMENT
    # ========================================================================
    
    def enrich_donor_fec(self, donor_id: str) -> EnrichmentResult:
        """
        Enrich donor with FEC contribution data (FREE)
        """
        logger.info(f"📊 Enriching donor {donor_id} with FEC data")
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get donor info for lookup
        cur.execute("""
            SELECT first_name, last_name, email, zip, employer
            FROM donors WHERE donor_id = %s
        """, (donor_id,))
        donor = cur.fetchone()
        
        if not donor:
            conn.close()
            return EnrichmentResult(
                target_type='donor',
                target_id=donor_id,
                source='fec_api',
                success=False,
                error='Donor not found'
            )
        
        # Query FEC API
        fec_data = self._query_fec_api(donor['first_name'], donor['last_name'], donor.get('zip'))
        
        if fec_data:
            # Update donor record
            cur.execute("""
                UPDATE donors SET
                    nexus_fec_total = %s,
                    nexus_fec_last_date = %s,
                    nexus_fec_committees = %s,
                    nexus_fec_employers = %s,
                    nexus_enriched = TRUE,
                    nexus_enriched_at = NOW(),
                    nexus_enrichment_sources = nexus_enrichment_sources || '["fec_api"]'::jsonb
                WHERE donor_id = %s
            """, (
                fec_data.get('total_contributions', 0),
                fec_data.get('last_contribution_date'),
                Json(fec_data.get('committees', [])),
                Json(fec_data.get('employers', [])),
                donor_id
            ))
            
            conn.commit()
            conn.close()
            
            return EnrichmentResult(
                target_type='donor',
                target_id=donor_id,
                source='fec_api',
                success=True,
                data=fec_data,
                fields_populated=['nexus_fec_total', 'nexus_fec_committees', 'nexus_fec_employers']
            )
        
        conn.close()
        return EnrichmentResult(
            target_type='donor',
            target_id=donor_id,
            source='fec_api',
            success=False,
            error='No FEC data found'
        )
    
    def _query_fec_api(self, first_name: str, last_name: str, zip_code: str = None) -> Optional[Dict]:
        """
        Query FEC.gov API for contribution data
        FREE - No API key required for basic queries
        """
        if not HAS_REQUESTS:
            logger.warning("requests library not available for FEC API")
            return None
        
        try:
            # FEC API endpoint
            base_url = "https://api.open.fec.gov/v1/schedules/schedule_a/"
            
            params = {
                'contributor_name': f"{first_name} {last_name}",
                'per_page': 100,
                'api_key': 'DEMO_KEY'  # FEC provides a demo key for testing
            }
            
            if zip_code:
                params['contributor_zip'] = zip_code
            
            response = requests.get(base_url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                results = data.get('results', [])
                
                if results:
                    total = sum(r.get('contribution_receipt_amount', 0) for r in results)
                    committees = list(set(r.get('committee', {}).get('name', '') for r in results if r.get('committee')))
                    employers = list(set(r.get('contributor_employer', '') for r in results if r.get('contributor_employer')))
                    dates = [r.get('contribution_receipt_date') for r in results if r.get('contribution_receipt_date')]
                    
                    return {
                        'total_contributions': total,
                        'contribution_count': len(results),
                        'committees': committees[:10],
                        'employers': employers[:5],
                        'last_contribution_date': max(dates) if dates else None
                    }
            
            return None
            
        except Exception as e:
            logger.error(f"FEC API error: {e}")
            return None
    
    def enrich_donor_voter(self, donor_id: str) -> EnrichmentResult:
        """
        Enrich donor with NC voter registration data (FREE)
        Note: Actual implementation would query NC SBOE voter file
        """
        logger.info(f"🗳️ Enriching donor {donor_id} with voter data")
        
        # Placeholder - actual implementation would query NC SBOE
        # NC voter file is publicly available for download
        
        return EnrichmentResult(
            target_type='donor',
            target_id=donor_id,
            source='nc_sboe',
            success=False,
            error='NC SBOE integration pending'
        )
    
    def enrich_donor_property(self, donor_id: str) -> EnrichmentResult:
        """
        Enrich donor with property tax data (FREE)
        Note: Actual implementation would query county GIS/tax systems
        """
        logger.info(f"🏠 Enriching donor {donor_id} with property data")
        
        # Placeholder - actual implementation would query county systems
        # Most NC counties have public GIS/property tax portals
        
        return EnrichmentResult(
            target_type='donor',
            target_id=donor_id,
            source='county_property',
            success=False,
            error='County property integration pending'
        )
    
    # ========================================================================
    # BATCH ENRICHMENT (E20 Brain Controlled)
    # ========================================================================
    
    def run_enrichment_batch(self, enrichment_type: str, batch_size: int = None) -> Dict:
        """
        Run enrichment batch for specified type
        Controlled by E20 Intelligence Brain priorities
        """
        batch_size = batch_size or HarvestConfig.ENRICH_BATCH_SIZE
        logger.info(f"⚡ Running {enrichment_type} enrichment batch (size: {batch_size})")
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get items from enrichment queue
        cur.execute("""
            SELECT * FROM nexus_enrichment_queue
            WHERE enrichment_type = %s
            AND status = 'pending'
            AND brain_approved = TRUE
            ORDER BY priority DESC
            LIMIT %s
        """, (enrichment_type, batch_size))
        
        queue_items = cur.fetchall()
        
        success_count = 0
        fail_count = 0
        
        for item in queue_items:
            # Mark as processing
            cur.execute("""
                UPDATE nexus_enrichment_queue SET
                    status = 'processing',
                    last_attempt_at = NOW(),
                    attempts = attempts + 1
                WHERE queue_id = %s
            """, (item['queue_id'],))
            conn.commit()
            
            # Run enrichment based on type
            if enrichment_type == 'fec_check' and item['target_type'] == 'donor':
                result = self.enrich_donor_fec(str(item['target_id']))
            elif enrichment_type == 'voter_check' and item['target_type'] == 'donor':
                result = self.enrich_donor_voter(str(item['target_id']))
            elif enrichment_type == 'property_check' and item['target_type'] == 'donor':
                result = self.enrich_donor_property(str(item['target_id']))
            else:
                result = EnrichmentResult(
                    target_type=item['target_type'],
                    target_id=str(item['target_id']),
                    source=enrichment_type,
                    success=False,
                    error=f'Unknown enrichment type: {enrichment_type}'
                )
            
            # Update queue status
            if result.success:
                cur.execute("""
                    UPDATE nexus_enrichment_queue SET
                        status = 'completed',
                        success = TRUE,
                        enrichment_data = %s,
                        fields_enriched = %s,
                        completed_at = NOW()
                    WHERE queue_id = %s
                """, (
                    Json(result.data),
                    Json(result.fields_populated),
                    item['queue_id']
                ))
                success_count += 1
            else:
                status = 'failed' if item['attempts'] >= 3 else 'pending'
                cur.execute("""
                    UPDATE nexus_enrichment_queue SET
                        status = %s,
                        success = FALSE,
                        error_message = %s
                    WHERE queue_id = %s
                """, (status, result.error, item['queue_id']))
                fail_count += 1
            
            conn.commit()
        
        conn.close()
        
        return {
            'enrichment_type': enrichment_type,
            'processed': len(queue_items),
            'success': success_count,
            'failed': fail_count
        }
    
    # ========================================================================
    # STATISTICS & REPORTING
    # ========================================================================
    
    def get_harvest_stats(self) -> Dict:
        """Get current harvest database statistics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                COUNT(*) as total_records,
                COUNT(*) FILTER (WHERE enrichment_status = 'pending') as pending,
                COUNT(*) FILTER (WHERE enrichment_status = 'matched') as matched,
                COUNT(*) FILTER (WHERE enrichment_status = 'no_match') as no_match,
                COUNT(*) FILTER (WHERE matched_donor_id IS NOT NULL) as matched_to_donors,
                COUNT(*) FILTER (WHERE matched_volunteer_id IS NOT NULL) as matched_to_volunteers,
                COUNT(*) FILTER (WHERE match_verified = TRUE) as verified_matches,
                COUNT(*) FILTER (WHERE facebook_id IS NOT NULL) as has_facebook,
                COUNT(*) FILTER (WHERE twitter_handle IS NOT NULL) as has_twitter,
                COUNT(*) FILTER (WHERE linkedin_url IS NOT NULL) as has_linkedin,
                AVG(enrichment_score) as avg_enrichment_score
            FROM nexus_harvest_records
        """)
        
        stats = cur.fetchone()
        conn.close()
        
        return dict(stats) if stats else {}
    
    def get_enrichment_stats(self) -> Dict:
        """Get enrichment queue statistics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                enrichment_type,
                status,
                COUNT(*) as count
            FROM nexus_enrichment_queue
            GROUP BY enrichment_type, status
            ORDER BY enrichment_type, status
        """)
        
        rows = cur.fetchall()
        conn.close()
        
        stats = {}
        for row in rows:
            etype = row['enrichment_type']
            if etype not in stats:
                stats[etype] = {}
            stats[etype][row['status']] = row['count']
        
        return stats


# ============================================================================
# STANDALONE EXECUTION
# ============================================================================

if __name__ == "__main__":
    print("=" * 70)
    print("NEXUS HARVEST ENRICHMENT ENGINE")
    print("Processes 150K harvest records for matching and enrichment")
    print("=" * 70)
    
    engine = NexusHarvestEngine()
    
    print("\n📊 Current Harvest Statistics:")
    stats = engine.get_harvest_stats()
    for key, value in stats.items():
        print(f"   {key}: {value}")
    
    print("\nExample usage:")
    print("  # Import harvest batch")
    print("  engine.import_harvest_batch(records, 'event_list', 'Rally 2024')")
    print()
    print("  # Run matching")
    print("  engine.run_matching_batch(batch_size=100)")
    print()
    print("  # Enrich with FEC data")
    print("  engine.enrich_donor_fec('donor-uuid')")
    print()
    print("  # Run enrichment queue")
    print("  engine.run_enrichment_batch('fec_check', batch_size=50)")
