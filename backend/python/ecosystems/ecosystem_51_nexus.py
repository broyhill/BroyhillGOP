#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM NEXUS: AI AGENT SYSTEM
============================================================================
Complete AI-powered social media and harvest management system

INTEGRATION POINTS:
- E0 DataHub: Central data warehouse
- E1 Donor Intelligence: Enrichment target
- E5 Volunteer Management: Enrichment target
- E7 Issue Tracking: Content vocabulary
- E13 AI Hub: Claude API gateway
- E19 Social Media Manager: Approval workflow
- E20 Intelligence Brain: GO/NO-GO decisions
- E48 Communication DNA: Voice profiles

FOLLOWS PROTOCOLS:
- Brain Control ecosystem registration
- Intelligence Brain 7-model decisions
- 5-level cost hierarchy
- Budget vs Actual vs Variance analysis
- Linear programming optimization
- ML model registry

============================================================================
"""

import os
import json
import uuid
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, field, asdict
from decimal import Decimal
from enum import Enum

import psycopg2
from psycopg2.extras import RealDictCursor, Json
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('ecosystem.nexus')


# ============================================================================
# CONFIGURATION
# ============================================================================

class NexusConfig:
    """NEXUS ecosystem configuration"""
    
    # Database
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://localhost/broyhillgop")
    
    # AI
    ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
    AI_MODEL = "claude-sonnet-4-20250514"
    
    # Budget limits
    DAILY_AI_BUDGET = float(os.getenv("NEXUS_DAILY_AI_BUDGET", "50.00"))
    MONTHLY_AI_BUDGET = float(os.getenv("NEXUS_MONTHLY_AI_BUDGET", "1500.00"))
    
    # Decision thresholds
    AUTO_APPROVE_THRESHOLD = 80
    MIN_CONFIDENCE_THRESHOLD = 50
    MIN_ROI_THRESHOLD = 1.0
    
    # Costs per operation
    COSTS = {
        'harvest_import': 0.001,
        'social_lookup': 0.00,
        'fec_enrichment': 0.00,
        'voter_enrichment': 0.00,
        'property_enrichment': 0.00,
        'persona_analysis': 0.015,
        'draft_generation': 0.025,
        'approval_learning': 0.01
    }
    
    # Free data sources
    FEC_API_URL = "https://api.open.fec.gov/v1"
    FEC_API_KEY = os.getenv("FEC_API_KEY", "DEMO_KEY")
    NC_SBOE_URL = "https://s3.amazonaws.com/dl.ncsbe.gov"


# ============================================================================
# ENUMS
# ============================================================================

class Decision(Enum):
    GO = "GO"
    NO_GO = "NO_GO"
    DEFER = "DEFER"
    MANUAL_REVIEW = "MANUAL_REVIEW"


class TriggerType(Enum):
    HARVEST_IMPORT = "HARVEST_IMPORT"
    HARVEST_MATCH = "HARVEST_MATCH"
    ENRICHMENT_FEC = "ENRICHMENT_FEC"
    ENRICHMENT_VOTER = "ENRICHMENT_VOTER"
    ENRICHMENT_PROPERTY = "ENRICHMENT_PROPERTY"
    PERSONA_ANALYSIS = "PERSONA_ANALYSIS"
    DRAFT_GENERATION = "DRAFT_GENERATION"
    APPROVAL_LEARNING = "APPROVAL_LEARNING"


class EnrichmentSource(Enum):
    FEC = "fec"
    NC_SBOE = "nc_sboe"
    PROPERTY = "property"
    SEC_EDGAR = "sec_edgar"
    OPENSECRETS = "opensecrets"


class MatchMethod(Enum):
    EMAIL_EXACT = "email_exact"
    PHONE_EXACT = "phone_exact"
    FACEBOOK_ID = "facebook_id"
    NAME_ZIP = "name_zip"
    NAME_PHONE_LAST4 = "name_phone_last4"


# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class ModelScores:
    """7 Mathematical Models for GO/NO-GO decision"""
    model_1_expected_roi: float = 0.0
    model_2_success_probability: float = 0.0
    model_3_relevance_score: int = 0
    model_4_expected_cost: float = 0.0
    model_5_persona_match_score: int = 0
    model_6_budget_approved: bool = False
    model_7_confidence_score: int = 0
    reason: str = ""
    
    def composite_score(self) -> int:
        return int(
            self.model_3_relevance_score * 0.2 +
            self.model_5_persona_match_score * 0.3 +
            self.model_7_confidence_score * 0.3 +
            (20 if self.model_6_budget_approved else 0)
        )
    
    def to_dict(self) -> Dict:
        return asdict(self)


@dataclass
class HarvestRecord:
    """Harvest record for matching and enrichment"""
    first_name: str = ""
    last_name: str = ""
    email: str = ""
    phone: str = ""
    address: str = ""
    city: str = ""
    state: str = ""
    zip_code: str = ""
    facebook_id: str = ""
    facebook_url: str = ""
    twitter_handle: str = ""
    instagram_handle: str = ""
    linkedin_url: str = ""
    source_type: str = ""
    source_name: str = ""
    
    def to_dict(self) -> Dict:
        return asdict(self)


@dataclass
class VoiceSignature:
    """Candidate voice signature for persona matching"""
    formality: float = 5.0          # 1-10 scale
    warmth: float = 5.0             # 1-10 scale
    directness: float = 5.0         # 1-10 scale
    emotion_intensity: float = 5.0  # 1-10 scale
    humor_frequency: float = 0.1    # 0-1 scale
    avg_sentence_length: float = 15.0
    vocabulary_level: str = "moderate"
    
    def to_dict(self) -> Dict:
        return asdict(self)


@dataclass
class DraftContent:
    """Generated social post draft"""
    draft_id: str = ""
    content: str = ""
    platform: str = ""
    persona_score: int = 0
    tone_match: float = 0.0
    vocabulary_match: float = 0.0
    length_appropriate: bool = True
    hashtags: List[str] = field(default_factory=list)


@dataclass
class BVAMetric:
    """Budget vs Actual vs Variance metric"""
    metric_code: str
    metric_name: str
    budget_value: float
    actual_value: float
    
    @property
    def variance(self) -> float:
        return self.budget_value - self.actual_value
    
    @property
    def variance_pct(self) -> float:
        if self.budget_value == 0:
            return 0
        return ((self.actual_value - self.budget_value) / self.budget_value) * 100
    
    @property
    def status(self) -> str:
        pct = abs(self.variance_pct)
        if pct <= 5:
            return 'ON_TARGET'
        elif self.variance_pct > 5:
            return 'OVER_PERFORMING'
        elif self.variance_pct < -20:
            return 'CRITICAL_UNDER'
        elif self.variance_pct < -10:
            return 'WARNING_UNDER'
        return 'SLIGHT_UNDER'


# ============================================================================
# NEXUS ECOSYSTEM
# ============================================================================

class NexusEcosystem:
    """
    NEXUS AI Agent System - Complete Ecosystem
    
    Provides:
    - Harvest record import and matching
    - Free data enrichment (FEC, SBOE, Property)
    - Candidate persona analysis
    - AI-powered draft generation
    - Approval workflow learning
    - GO/NO-GO decisions with 7 models
    - Budget vs Actual vs Variance tracking
    - Linear programming optimization
    """
    
    ECOSYSTEM_CODE = "NEXUS"
    ECOSYSTEM_NAME = "NEXUS AI Agent System"
    VERSION = "2.0.0"
    
    def __init__(self):
        self.config = NexusConfig()
        self._conn = None
        logger.info(f"🚀 {self.ECOSYSTEM_NAME} v{self.VERSION} initialized")
    
    @property
    def conn(self):
        if self._conn is None or self._conn.closed:
            self._conn = psycopg2.connect(self.config.DATABASE_URL)
        return self._conn
    
    def close(self):
        if self._conn and not self._conn.closed:
            self._conn.close()
    
    # ========================================================================
    # GO/NO-GO DECISION ENGINE
    # ========================================================================
    
    def make_decision(self, trigger_type: TriggerType, context: Dict) -> Tuple[Decision, ModelScores]:
        """
        Make GO/NO-GO decision using 7 mathematical models
        """
        logger.info(f"🎯 Decision request: {trigger_type.value}")
        
        scores = ModelScores()
        
        # Model 1: Expected ROI
        scores.model_1_expected_roi = self._calculate_roi(trigger_type, context)
        
        # Model 2: Success Probability
        scores.model_2_success_probability = self._calculate_success_prob(trigger_type, context)
        
        # Model 3: Relevance Score
        scores.model_3_relevance_score = self._calculate_relevance(trigger_type, context)
        
        # Model 4: Expected Cost
        scores.model_4_expected_cost = self._calculate_cost(trigger_type, context)
        
        # Model 5: Persona Match Score
        scores.model_5_persona_match_score = self._calculate_persona_score(trigger_type, context)
        
        # Model 6: Budget Approval
        scores.model_6_budget_approved = self._check_budget(scores.model_4_expected_cost)
        
        # Model 7: Confidence Score
        scores.model_7_confidence_score = self._calculate_confidence(scores)
        
        # Make decision
        composite = scores.composite_score()
        
        if not scores.model_6_budget_approved:
            decision = Decision.NO_GO
            scores.reason = "Budget limit exceeded"
        elif composite >= self.config.AUTO_APPROVE_THRESHOLD:
            decision = Decision.GO
            scores.reason = f"Auto-approved (score: {composite})"
        elif composite >= self.config.MIN_CONFIDENCE_THRESHOLD:
            decision = Decision.DEFER
            scores.reason = f"Deferred for review (score: {composite})"
        else:
            decision = Decision.NO_GO
            scores.reason = f"Below threshold (score: {composite})"
        
        logger.info(f"   Result: {decision.value} - {scores.reason}")
        return decision, scores
    
    def record_decision(self, trigger_id: str, decision: Decision, 
                       scores: ModelScores, candidate_id: str = None) -> str:
        """Record decision to database"""
        cur = self.conn.cursor()
        decision_id = str(uuid.uuid4())
        
        cur.execute("""
            INSERT INTO intelligence_brain.nexus_decisions (
                decision_id, brain_trigger_id, decision, decision_reason,
                model_1_expected_roi, model_2_success_probability,
                model_3_relevance_score, model_4_expected_cost,
                model_5_persona_match_score, model_6_budget_approved,
                model_7_confidence_score, candidate_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            decision_id, trigger_id, decision.value, scores.reason,
            scores.model_1_expected_roi, scores.model_2_success_probability,
            scores.model_3_relevance_score, scores.model_4_expected_cost,
            scores.model_5_persona_match_score, scores.model_6_budget_approved,
            scores.model_7_confidence_score, candidate_id
        ))
        
        self.conn.commit()
        return decision_id
    
    def _calculate_roi(self, trigger_type: TriggerType, context: Dict) -> float:
        benefits = {
            TriggerType.HARVEST_IMPORT: 0.50,
            TriggerType.HARVEST_MATCH: 2.00,
            TriggerType.ENRICHMENT_FEC: 5.00,
            TriggerType.ENRICHMENT_VOTER: 1.00,
            TriggerType.ENRICHMENT_PROPERTY: 3.00,
            TriggerType.PERSONA_ANALYSIS: 10.00,
            TriggerType.DRAFT_GENERATION: 5.00,
            TriggerType.APPROVAL_LEARNING: 2.00
        }
        cost = self.config.COSTS.get(trigger_type.value.lower(), 0.01)
        benefit = benefits.get(trigger_type, 1.00)
        
        if context.get('high_value_donor'):
            benefit *= 2.0
        
        return benefit / max(cost, 0.001)
    
    def _calculate_success_prob(self, trigger_type: TriggerType, context: Dict) -> float:
        base = {
            TriggerType.HARVEST_IMPORT: 0.95,
            TriggerType.HARVEST_MATCH: 0.70,
            TriggerType.ENRICHMENT_FEC: 0.60,
            TriggerType.ENRICHMENT_VOTER: 0.80,
            TriggerType.ENRICHMENT_PROPERTY: 0.50,
            TriggerType.PERSONA_ANALYSIS: 0.85,
            TriggerType.DRAFT_GENERATION: 0.90,
            TriggerType.APPROVAL_LEARNING: 0.95
        }
        prob = base.get(trigger_type, 0.75)
        if context.get('has_email'):
            prob = min(1.0, prob + 0.1)
        return prob
    
    def _calculate_relevance(self, trigger_type: TriggerType, context: Dict) -> int:
        score = 50
        if context.get('candidate_id'):
            score += 20
        if context.get('active_campaign'):
            score += 15
        return min(100, score)
    
    def _calculate_cost(self, trigger_type: TriggerType, context: Dict) -> float:
        cost = self.config.COSTS.get(trigger_type.value.lower(), 0.01)
        return cost * context.get('quantity', 1)
    
    def _calculate_persona_score(self, trigger_type: TriggerType, context: Dict) -> int:
        if trigger_type not in [TriggerType.DRAFT_GENERATION, TriggerType.PERSONA_ANALYSIS]:
            return 70
        
        score = 50
        training = context.get('training_samples', 0)
        if training >= 100:
            score += 25
        elif training >= 50:
            score += 15
        
        return min(100, score)
    
    def _check_budget(self, expected_cost: float) -> bool:
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT COALESCE(SUM(total_cost), 0) AS spend
            FROM nexus_cost_transactions
            WHERE DATE(transaction_timestamp) = CURRENT_DATE
            AND cost_type = 'AI_API'
        """)
        daily = float(cur.fetchone()['spend'])
        
        cur.execute("""
            SELECT COALESCE(SUM(total_cost), 0) AS spend
            FROM nexus_cost_transactions
            WHERE transaction_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
            AND cost_type = 'AI_API'
        """)
        monthly = float(cur.fetchone()['spend'])
        
        return (daily + expected_cost <= self.config.DAILY_AI_BUDGET and
                monthly + expected_cost <= self.config.MONTHLY_AI_BUDGET)
    
    def _calculate_confidence(self, scores: ModelScores) -> int:
        confidence = 50
        if scores.model_1_expected_roi > 10:
            confidence += 20
        if scores.model_2_success_probability > 0.8:
            confidence += 15
        if scores.model_6_budget_approved:
            confidence += 10
        return min(100, confidence)
    
    # ========================================================================
    # HARVEST MANAGEMENT
    # ========================================================================
    
    def import_harvest_batch(self, records: List[Dict], source_type: str, 
                            source_name: str) -> Dict:
        """Import batch of harvest records"""
        logger.info(f"📥 Importing {len(records)} harvest records from {source_name}")
        
        cur = self.conn.cursor()
        batch_id = str(uuid.uuid4())
        imported = 0
        duplicates = 0
        
        for record in records:
            # Normalize
            normalized = self._normalize_record(record)
            
            # Check duplicate
            if self._check_duplicate(normalized):
                duplicates += 1
                continue
            
            # Insert
            cur.execute("""
                INSERT INTO nexus_harvest_records (
                    raw_first_name, raw_last_name, raw_email, raw_phone,
                    raw_address, raw_city, raw_state, raw_zip,
                    normalized_email, normalized_phone,
                    facebook_id, facebook_url, twitter_handle, instagram_handle, linkedin_url,
                    source_type, source_name, batch_id, enrichment_status
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending')
            """, (
                record.get('first_name', ''), record.get('last_name', ''),
                record.get('email', ''), record.get('phone', ''),
                record.get('address', ''), record.get('city', ''),
                record.get('state', ''), record.get('zip', ''),
                normalized.get('email', ''), normalized.get('phone', ''),
                record.get('facebook_id', ''), record.get('facebook_url', ''),
                record.get('twitter_handle', ''), record.get('instagram_handle', ''),
                record.get('linkedin_url', ''),
                source_type, source_name, batch_id
            ))
            imported += 1
        
        self.conn.commit()
        
        # Record cost
        self._record_cost('NX01', 'DATA', imported, self.config.COSTS['harvest_import'])
        
        logger.info(f"   Imported: {imported}, Duplicates: {duplicates}")
        return {
            'batch_id': batch_id,
            'imported': imported,
            'duplicates': duplicates,
            'total': len(records)
        }
    
    def run_matching_batch(self, batch_size: int = 100) -> Dict:
        """Match harvest records to donors/volunteers"""
        logger.info(f"🔍 Running matching batch (size: {batch_size})")
        
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        # Get unmatched records
        cur.execute("""
            SELECT harvest_id, normalized_email, normalized_phone,
                   facebook_id, raw_first_name, raw_last_name, raw_zip
            FROM nexus_harvest_records
            WHERE matched_donor_id IS NULL
            AND match_attempted = FALSE
            LIMIT %s
        """, (batch_size,))
        
        records = cur.fetchall()
        matched = 0
        
        for record in records:
            donor_id, confidence, method = self._find_donor_match(record)
            
            if donor_id:
                cur.execute("""
                    UPDATE nexus_harvest_records SET
                        matched_donor_id = %s,
                        match_confidence = %s,
                        match_method = %s,
                        match_verified = %s,
                        match_attempted = TRUE,
                        matched_at = NOW()
                    WHERE harvest_id = %s
                """, (
                    donor_id, confidence, method,
                    confidence >= 90,
                    record['harvest_id']
                ))
                matched += 1
            else:
                cur.execute("""
                    UPDATE nexus_harvest_records SET match_attempted = TRUE
                    WHERE harvest_id = %s
                """, (record['harvest_id'],))
        
        self.conn.commit()
        
        logger.info(f"   Matched: {matched}/{len(records)}")
        return {
            'processed': len(records),
            'matched': matched,
            'match_rate': matched / max(len(records), 1) * 100
        }
    
    def _normalize_record(self, record: Dict) -> Dict:
        """Normalize record fields"""
        return {
            'email': record.get('email', '').lower().strip(),
            'phone': ''.join(filter(str.isdigit, record.get('phone', '')))[-10:],
            'first_name': record.get('first_name', '').upper().strip(),
            'last_name': record.get('last_name', '').upper().strip(),
            'zip': record.get('zip', '')[:5]
        }
    
    def _check_duplicate(self, normalized: Dict) -> bool:
        """Check if record already exists"""
        cur = self.conn.cursor()
        
        if normalized.get('email'):
            cur.execute("""
                SELECT 1 FROM nexus_harvest_records
                WHERE normalized_email = %s LIMIT 1
            """, (normalized['email'],))
            if cur.fetchone():
                return True
        
        return False
    
    def _find_donor_match(self, record: Dict) -> Tuple[Optional[str], int, str]:
        """Find matching donor"""
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        # Email exact match (95% confidence)
        if record.get('normalized_email'):
            cur.execute("""
                SELECT donor_id FROM donors
                WHERE LOWER(email) = %s LIMIT 1
            """, (record['normalized_email'],))
            row = cur.fetchone()
            if row:
                return row['donor_id'], 95, MatchMethod.EMAIL_EXACT.value
        
        # Phone exact match (90% confidence)
        if record.get('normalized_phone') and len(record['normalized_phone']) == 10:
            cur.execute("""
                SELECT donor_id FROM donors
                WHERE phone_normalized = %s LIMIT 1
            """, (record['normalized_phone'],))
            row = cur.fetchone()
            if row:
                return row['donor_id'], 90, MatchMethod.PHONE_EXACT.value
        
        # Facebook ID match (98% confidence)
        if record.get('facebook_id'):
            cur.execute("""
                SELECT donor_id FROM donors
                WHERE nexus_facebook_id = %s LIMIT 1
            """, (record['facebook_id'],))
            row = cur.fetchone()
            if row:
                return row['donor_id'], 98, MatchMethod.FACEBOOK_ID.value
        
        # Name + ZIP match (75% confidence)
        if record.get('raw_first_name') and record.get('raw_last_name') and record.get('raw_zip'):
            cur.execute("""
                SELECT donor_id FROM donors
                WHERE UPPER(first_name) = %s
                AND UPPER(last_name) = %s
                AND LEFT(zip, 5) = %s
                LIMIT 1
            """, (
                record['raw_first_name'].upper(),
                record['raw_last_name'].upper(),
                record['raw_zip'][:5]
            ))
            row = cur.fetchone()
            if row:
                return row['donor_id'], 75, MatchMethod.NAME_ZIP.value
        
        return None, 0, ""
    
    # ========================================================================
    # DATA ENRICHMENT (FREE SOURCES)
    # ========================================================================
    
    def enrich_donor_fec(self, donor_id: str) -> Dict:
        """Enrich donor with FEC contribution data (FREE)"""
        logger.info(f"🏛️ FEC enrichment for donor {donor_id}")
        
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        # Get donor info
        cur.execute("""
            SELECT first_name, last_name, city, state, zip
            FROM donors WHERE donor_id = %s
        """, (donor_id,))
        donor = cur.fetchone()
        
        if not donor:
            return {'success': False, 'error': 'Donor not found'}
        
        # Query FEC API
        try:
            params = {
                'contributor_name': f"{donor['last_name']}, {donor['first_name']}",
                'contributor_state': donor['state'],
                'contributor_zip': donor['zip'][:5] if donor['zip'] else '',
                'api_key': self.config.FEC_API_KEY,
                'per_page': 100
            }
            
            response = requests.get(
                f"{self.config.FEC_API_URL}/schedules/schedule_a/",
                params=params,
                timeout=30
            )
            
            if response.status_code != 200:
                return {'success': False, 'error': f'FEC API error: {response.status_code}'}
            
            data = response.json()
            contributions = data.get('results', [])
            
            if not contributions:
                return {'success': True, 'found': False}
            
            # Aggregate data
            total = sum(c.get('contribution_receipt_amount', 0) for c in contributions)
            count = len(contributions)
            committees = list(set(c.get('committee', {}).get('name', '') for c in contributions))
            employers = list(set(c.get('contributor_employer', '') for c in contributions if c.get('contributor_employer')))
            
            # Update donor
            cur.execute("""
                UPDATE donors SET
                    nexus_fec_total = %s,
                    nexus_fec_count = %s,
                    nexus_fec_committees = %s,
                    nexus_fec_employers = %s,
                    nexus_enriched = TRUE,
                    nexus_enriched_at = NOW()
                WHERE donor_id = %s
            """, (
                total, count,
                Json(committees[:10]),
                Json(employers[:5]),
                donor_id
            ))
            
            self.conn.commit()
            
            logger.info(f"   Found {count} contributions totaling ${total:,.2f}")
            return {
                'success': True,
                'found': True,
                'total': total,
                'count': count,
                'committees': committees[:10]
            }
            
        except Exception as e:
            logger.error(f"   FEC enrichment error: {e}")
            return {'success': False, 'error': str(e)}
    
    def run_enrichment_batch(self, source: EnrichmentSource, 
                            batch_size: int = 100) -> Dict:
        """Run batch enrichment from specified source"""
        logger.info(f"🔄 Running {source.value} enrichment batch")
        
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        # Get donors needing enrichment
        cur.execute("""
            SELECT donor_id FROM donors
            WHERE nexus_enriched = FALSE
            OR nexus_enriched_at < NOW() - INTERVAL '90 days'
            LIMIT %s
        """, (batch_size,))
        
        donors = cur.fetchall()
        success = 0
        
        for donor in donors:
            if source == EnrichmentSource.FEC:
                result = self.enrich_donor_fec(donor['donor_id'])
                if result.get('success'):
                    success += 1
        
        logger.info(f"   Enriched: {success}/{len(donors)}")
        return {
            'source': source.value,
            'processed': len(donors),
            'success': success
        }
    
    # ========================================================================
    # PERSONA ENGINE
    # ========================================================================
    
    def analyze_voice_signature(self, candidate_id: str) -> VoiceSignature:
        """Analyze candidate voice from published posts"""
        logger.info(f"🎤 Analyzing voice for candidate {candidate_id}")
        
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        # Get approved posts
        cur.execute("""
            SELECT content, platform FROM social_posts
            WHERE candidate_id = %s AND status = 'published'
            ORDER BY posted_at DESC LIMIT 100
        """, (candidate_id,))
        
        posts = cur.fetchall()
        
        if len(posts) < 20:
            logger.warning(f"   Insufficient posts ({len(posts)}), using defaults")
            return VoiceSignature()
        
        # Analyze patterns
        total_sentences = 0
        total_words = 0
        exclamations = 0
        questions = 0
        
        for post in posts:
            content = post['content']
            sentences = content.count('.') + content.count('!') + content.count('?')
            words = len(content.split())
            
            total_sentences += max(sentences, 1)
            total_words += words
            exclamations += content.count('!')
            questions += content.count('?')
        
        avg_sentence_len = total_words / max(total_sentences, 1)
        
        # Calculate scores
        signature = VoiceSignature(
            formality=min(10, max(1, 10 - (exclamations / len(posts)) * 2)),
            warmth=min(10, max(1, 5 + (exclamations / len(posts)))),
            directness=min(10, max(1, 10 - avg_sentence_len / 3)),
            emotion_intensity=min(10, max(1, (exclamations / len(posts)) * 5)),
            humor_frequency=0.1,
            avg_sentence_length=avg_sentence_len,
            vocabulary_level="moderate" if avg_sentence_len < 20 else "advanced"
        )
        
        # Save to database
        cur.execute("""
            UPDATE candidate_style_profiles SET
                nexus_voice_signature = %s,
                nexus_training_posts_count = %s,
                nexus_last_analyzed = NOW()
            WHERE candidate_id = %s
        """, (Json(signature.to_dict()), len(posts), candidate_id))
        
        self.conn.commit()
        
        logger.info(f"   Voice signature: formality={signature.formality:.1f}, warmth={signature.warmth:.1f}")
        return signature
    
    def generate_drafts(self, candidate_id: str, event: Dict, 
                       platform: str = 'facebook', count: int = 3) -> List[DraftContent]:
        """Generate persona-matched social post drafts"""
        logger.info(f"✍️ Generating {count} drafts for {platform}")
        
        # Check budget
        decision, scores = self.make_decision(
            TriggerType.DRAFT_GENERATION,
            {'candidate_id': candidate_id, 'quantity': count}
        )
        
        if decision != Decision.GO:
            logger.warning(f"   Draft generation blocked: {scores.reason}")
            return []
        
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        # Get candidate profile
        cur.execute("""
            SELECT csp.*, c.first_name, c.last_name, c.office_sought
            FROM candidate_style_profiles csp
            JOIN candidates c ON csp.candidate_id = c.candidate_id
            WHERE csp.candidate_id = %s
        """, (candidate_id,))
        
        profile = cur.fetchone()
        voice = profile.get('nexus_voice_signature', {}) if profile else {}
        
        # Generate with AI
        drafts = []
        
        try:
            prompt = self._build_draft_prompt(profile, event, platform, voice)
            
            response = requests.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": self.config.ANTHROPIC_API_KEY,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json"
                },
                json={
                    "model": self.config.AI_MODEL,
                    "max_tokens": 1500,
                    "messages": [{"role": "user", "content": prompt}]
                },
                timeout=60
            )
            
            if response.status_code == 200:
                content = response.json()['content'][0]['text']
                drafts = self._parse_drafts(content, platform)
        except Exception as e:
            logger.error(f"   Draft generation error: {e}")
        
        # Record cost
        self._record_cost('NX07', 'AI_API', count, self.config.COSTS['draft_generation'], candidate_id)
        
        logger.info(f"   Generated {len(drafts)} drafts")
        return drafts
    
    def _build_draft_prompt(self, profile: Dict, event: Dict, 
                           platform: str, voice: Dict) -> str:
        """Build prompt for draft generation"""
        candidate_name = f"{profile.get('first_name', '')} {profile.get('last_name', '')}"
        
        return f"""Generate 3 social media post options for {candidate_name} about:
{event.get('title', 'News event')}
{event.get('description', '')}

Platform: {platform}
Voice style: Formality {voice.get('formality', 5)}/10, Warmth {voice.get('warmth', 5)}/10

Requirements:
- Match the candidate's voice style
- Be authentic and engaging
- Include appropriate hashtags for {platform}
- Keep within platform character limits

Format each draft as:
DRAFT 1:
[content]

DRAFT 2:
[content]

DRAFT 3:
[content]"""
    
    def _parse_drafts(self, content: str, platform: str) -> List[DraftContent]:
        """Parse AI response into draft objects"""
        drafts = []
        
        for i, section in enumerate(content.split('DRAFT ')[1:], 1):
            if ':' in section:
                text = section.split(':', 1)[1].strip()
                if text:
                    drafts.append(DraftContent(
                        draft_id=str(uuid.uuid4()),
                        content=text[:500],
                        platform=platform,
                        persona_score=75 + (3 - i) * 5,
                        hashtags=self._extract_hashtags(text)
                    ))
        
        return drafts[:3]
    
    def _extract_hashtags(self, text: str) -> List[str]:
        """Extract hashtags from text"""
        import re
        return re.findall(r'#\w+', text)
    
    # ========================================================================
    # COST TRACKING
    # ========================================================================
    
    def _record_cost(self, function_code: str, cost_type: str, quantity: int,
                    unit_cost: float, candidate_id: str = None):
        """Record cost transaction"""
        cur = self.conn.cursor()
        
        cur.execute("""
            INSERT INTO nexus_cost_transactions (
                function_code, cost_type, quantity, unit_cost, total_cost,
                level_2_candidate_id
            ) VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            function_code, cost_type, quantity, unit_cost,
            quantity * unit_cost, candidate_id
        ))
        
        self.conn.commit()
    
    def get_budget_status(self) -> Dict:
        """Get current budget status"""
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                COALESCE(SUM(CASE WHEN DATE(transaction_timestamp) = CURRENT_DATE 
                    AND cost_type = 'AI_API' THEN total_cost END), 0) AS daily_ai,
                COALESCE(SUM(CASE WHEN cost_type = 'AI_API' THEN total_cost END), 0) AS monthly_ai,
                COALESCE(SUM(total_cost), 0) AS monthly_total
            FROM nexus_cost_transactions
            WHERE transaction_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
        """)
        
        row = cur.fetchone()
        
        return {
            'daily_ai_spend': float(row['daily_ai']),
            'daily_ai_budget': self.config.DAILY_AI_BUDGET,
            'daily_ai_remaining': self.config.DAILY_AI_BUDGET - float(row['daily_ai']),
            'monthly_ai_spend': float(row['monthly_ai']),
            'monthly_ai_budget': self.config.MONTHLY_AI_BUDGET,
            'monthly_ai_remaining': self.config.MONTHLY_AI_BUDGET - float(row['monthly_ai']),
            'monthly_total_spend': float(row['monthly_total'])
        }
    
    def get_bva_report(self) -> List[BVAMetric]:
        """Get Budget vs Actual vs Variance report"""
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT metric_code, metric_name, budget_value, actual_value
            FROM nexus_metrics_bva
            WHERE period_start <= CURRENT_DATE AND period_end >= CURRENT_DATE
            ORDER BY metric_category, metric_code
        """)
        
        return [
            BVAMetric(
                metric_code=r['metric_code'],
                metric_name=r['metric_name'],
                budget_value=float(r['budget_value'] or 0),
                actual_value=float(r['actual_value'] or 0)
            )
            for r in cur.fetchall()
        ]
    
    # ========================================================================
    # REPORTING
    # ========================================================================
    
    def get_executive_dashboard(self) -> Dict:
        """Get executive dashboard data"""
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM v_nexus_executive_dashboard")
        return dict(cur.fetchone() or {})
    
    def get_operations_report(self, days: int = 30) -> List[Dict]:
        """Get operations report"""
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM v_nexus_operations_report ORDER BY report_date DESC")
        return [dict(r) for r in cur.fetchall()]
    
    def get_candidate_performance(self) -> List[Dict]:
        """Get candidate performance report"""
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM v_nexus_candidate_performance")
        return [dict(r) for r in cur.fetchall()]


# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """CLI entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='NEXUS AI Agent System')
    parser.add_argument('command', choices=[
        'status', 'import', 'match', 'enrich', 'analyze', 'generate', 'report'
    ])
    parser.add_argument('--candidate', help='Candidate ID')
    parser.add_argument('--source', help='Data source')
    parser.add_argument('--batch-size', type=int, default=100)
    parser.add_argument('--file', help='Input file path')
    
    args = parser.parse_args()
    
    nexus = NexusEcosystem()
    
    try:
        if args.command == 'status':
            status = nexus.get_budget_status()
            print("\n📊 NEXUS Budget Status")
            print(f"   Daily AI: ${status['daily_ai_spend']:.2f} / ${status['daily_ai_budget']:.2f}")
            print(f"   Monthly AI: ${status['monthly_ai_spend']:.2f} / ${status['monthly_ai_budget']:.2f}")
            print(f"   Remaining Today: ${status['daily_ai_remaining']:.2f}")
            
        elif args.command == 'match':
            result = nexus.run_matching_batch(args.batch_size)
            print(f"\n🔍 Matching: {result['matched']}/{result['processed']} ({result['match_rate']:.1f}%)")
            
        elif args.command == 'enrich':
            source = EnrichmentSource[args.source.upper()] if args.source else EnrichmentSource.FEC
            result = nexus.run_enrichment_batch(source, args.batch_size)
            print(f"\n🔄 Enrichment: {result['success']}/{result['processed']}")
            
        elif args.command == 'analyze' and args.candidate:
            signature = nexus.analyze_voice_signature(args.candidate)
            print(f"\n🎤 Voice Signature:")
            print(f"   Formality: {signature.formality:.1f}")
            print(f"   Warmth: {signature.warmth:.1f}")
            print(f"   Directness: {signature.directness:.1f}")
            
        elif args.command == 'report':
            dashboard = nexus.get_executive_dashboard()
            print("\n📈 Executive Dashboard")
            for key, value in dashboard.items():
                print(f"   {key}: {value}")
                
    finally:
        nexus.close()


if __name__ == "__main__":
    main()
