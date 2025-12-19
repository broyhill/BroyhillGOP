#!/usr/bin/env python3
"""
============================================================================
NEXUS BRAIN INTEGRATION ENGINE
============================================================================
Integrates NEXUS with E20 Intelligence Brain for GO/NO-GO decisions
Implements 7 mathematical models, cost accounting, ML optimization

FOLLOWS EXISTING PROTOCOLS:
- Brain Control ecosystem registration
- Intelligence Brain GO/NO-GO decisions  
- 5-level cost hierarchy
- Budget vs Actual vs Variance analysis
- ML model registry and predictions

============================================================================
"""

import os
import json
import uuid
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, field
from decimal import Decimal
from enum import Enum

import psycopg2
from psycopg2.extras import RealDictCursor, Json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('nexus.brain')


# ============================================================================
# ENUMS & CONFIGURATION
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


class CostType(Enum):
    AI_API = "AI_API"
    INFRASTRUCTURE = "INFRASTRUCTURE"
    DATA = "DATA"
    VENDOR = "VENDOR"


class BrainConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    
    # Decision thresholds
    AUTO_APPROVE_THRESHOLD = 80
    MIN_CONFIDENCE_THRESHOLD = 50
    MIN_ROI_THRESHOLD = 1.0
    
    # Budget limits
    DAILY_AI_BUDGET = 50.00
    MONTHLY_AI_BUDGET = 1500.00
    
    # Cost per operation
    COST_PERSONA_ANALYSIS = 0.015
    COST_DRAFT_GENERATION = 0.025
    COST_APPROVAL_LEARNING = 0.01
    COST_HARVEST_IMPORT = 0.001


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
        """Calculate composite decision score"""
        return int(
            self.model_3_relevance_score * 0.2 +
            self.model_5_persona_match_score * 0.3 +
            self.model_7_confidence_score * 0.3 +
            (20 if self.model_6_budget_approved else 0)
        )
    
    def to_dict(self) -> Dict:
        return {
            'expected_roi': self.model_1_expected_roi,
            'success_probability': self.model_2_success_probability,
            'relevance_score': self.model_3_relevance_score,
            'expected_cost': self.model_4_expected_cost,
            'persona_match_score': self.model_5_persona_match_score,
            'budget_approved': self.model_6_budget_approved,
            'confidence_score': self.model_7_confidence_score,
            'reason': self.reason
        }


@dataclass
class CostTransaction:
    """Cost transaction record"""
    function_code: str
    cost_type: CostType
    quantity: int
    unit_cost: float
    candidate_id: Optional[str] = None
    reference_type: Optional[str] = None
    reference_id: Optional[str] = None
    
    @property
    def total_cost(self) -> float:
        return self.quantity * self.unit_cost


@dataclass
class BVAMetric:
    """Budget vs Actual vs Variance metric"""
    metric_code: str
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
# NEXUS BRAIN ENGINE
# ============================================================================

class NexusBrainEngine:
    """
    Integrates NEXUS with E20 Intelligence Brain
    Implements GO/NO-GO decisions with 7 mathematical models
    """
    
    def __init__(self, db_url: str = None):
        self.db_url = db_url or BrainConfig.DATABASE_URL
        logger.info("🧠 NEXUS Brain Integration Engine initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # GO/NO-GO DECISION ENGINE
    # ========================================================================
    
    def make_decision(self, trigger_type: TriggerType, context: Dict) -> Tuple[Decision, ModelScores]:
        """
        Make GO/NO-GO decision using 7 mathematical models
        
        Following Intelligence Brain protocol
        """
        logger.info(f"🎯 Making decision for {trigger_type.value}")
        
        # Calculate all 7 model scores
        scores = ModelScores()
        
        # Model 1: Expected ROI
        scores.model_1_expected_roi = self._calculate_expected_roi(trigger_type, context)
        
        # Model 2: Success Probability
        scores.model_2_success_probability = self._calculate_success_probability(trigger_type, context)
        
        # Model 3: Relevance Score
        scores.model_3_relevance_score = self._calculate_relevance_score(trigger_type, context)
        
        # Model 4: Expected Cost
        scores.model_4_expected_cost = self._calculate_expected_cost(trigger_type, context)
        
        # Model 5: Persona Match Score (for social operations)
        scores.model_5_persona_match_score = self._calculate_persona_score(trigger_type, context)
        
        # Model 6: Budget Approval
        scores.model_6_budget_approved = self._check_budget_approval(scores.model_4_expected_cost)
        
        # Model 7: Confidence Score
        scores.model_7_confidence_score = self._calculate_confidence_score(scores)
        
        # Make decision based on composite score
        composite = scores.composite_score()
        
        if composite >= BrainConfig.AUTO_APPROVE_THRESHOLD:
            decision = Decision.GO
            scores.reason = f"Auto-approved: composite score {composite} >= {BrainConfig.AUTO_APPROVE_THRESHOLD}"
        elif composite >= BrainConfig.MIN_CONFIDENCE_THRESHOLD:
            decision = Decision.DEFER
            scores.reason = f"Deferred for review: composite score {composite}"
        else:
            decision = Decision.NO_GO
            scores.reason = f"Rejected: composite score {composite} < {BrainConfig.MIN_CONFIDENCE_THRESHOLD}"
        
        # Check hard constraints
        if not scores.model_6_budget_approved:
            decision = Decision.NO_GO
            scores.reason = "Budget limit exceeded"
        
        if scores.model_1_expected_roi < BrainConfig.MIN_ROI_THRESHOLD:
            if trigger_type in [TriggerType.DRAFT_GENERATION, TriggerType.PERSONA_ANALYSIS]:
                decision = Decision.NO_GO
                scores.reason = f"ROI {scores.model_1_expected_roi:.2f} below threshold {BrainConfig.MIN_ROI_THRESHOLD}"
        
        logger.info(f"   Decision: {decision.value} (composite: {composite})")
        logger.info(f"   Reason: {scores.reason}")
        
        return decision, scores
    
    def _calculate_expected_roi(self, trigger_type: TriggerType, context: Dict) -> float:
        """Model 1: Calculate expected ROI"""
        
        # Cost estimates
        costs = {
            TriggerType.HARVEST_IMPORT: 0.001,
            TriggerType.HARVEST_MATCH: 0.0,
            TriggerType.ENRICHMENT_FEC: 0.0,
            TriggerType.ENRICHMENT_VOTER: 0.0,
            TriggerType.ENRICHMENT_PROPERTY: 0.0,
            TriggerType.PERSONA_ANALYSIS: 0.015,
            TriggerType.DRAFT_GENERATION: 0.025,
            TriggerType.APPROVAL_LEARNING: 0.01
        }
        
        # Benefit estimates (based on downstream value)
        benefits = {
            TriggerType.HARVEST_IMPORT: 0.50,      # Value of matched record
            TriggerType.HARVEST_MATCH: 2.00,       # Value of verified match
            TriggerType.ENRICHMENT_FEC: 5.00,      # FEC data value
            TriggerType.ENRICHMENT_VOTER: 1.00,    # Voter data value
            TriggerType.ENRICHMENT_PROPERTY: 3.00, # Property data value
            TriggerType.PERSONA_ANALYSIS: 10.00,   # Improved content quality
            TriggerType.DRAFT_GENERATION: 5.00,    # Social engagement value
            TriggerType.APPROVAL_LEARNING: 2.00    # Model improvement value
        }
        
        cost = costs.get(trigger_type, 0.01)
        benefit = benefits.get(trigger_type, 1.00)
        
        # Adjust for context
        if context.get('high_value_donor'):
            benefit *= 2.0
        if context.get('active_campaign'):
            benefit *= 1.5
        
        return benefit / max(cost, 0.001)
    
    def _calculate_success_probability(self, trigger_type: TriggerType, context: Dict) -> float:
        """Model 2: Calculate probability of success"""
        
        base_probabilities = {
            TriggerType.HARVEST_IMPORT: 0.95,
            TriggerType.HARVEST_MATCH: 0.70,
            TriggerType.ENRICHMENT_FEC: 0.60,
            TriggerType.ENRICHMENT_VOTER: 0.80,
            TriggerType.ENRICHMENT_PROPERTY: 0.50,
            TriggerType.PERSONA_ANALYSIS: 0.85,
            TriggerType.DRAFT_GENERATION: 0.90,
            TriggerType.APPROVAL_LEARNING: 0.95
        }
        
        prob = base_probabilities.get(trigger_type, 0.75)
        
        # Adjust for data quality
        if context.get('has_email'):
            prob = min(1.0, prob + 0.1)
        if context.get('has_phone'):
            prob = min(1.0, prob + 0.05)
        if context.get('training_samples', 0) > 50:
            prob = min(1.0, prob + 0.1)
        
        return prob
    
    def _calculate_relevance_score(self, trigger_type: TriggerType, context: Dict) -> int:
        """Model 3: Calculate relevance to candidate/campaign"""
        
        score = 50  # Base score
        
        # Candidate-specific relevance
        if context.get('candidate_id'):
            score += 20
            if context.get('active_campaign'):
                score += 15
            if context.get('upcoming_event'):
                score += 10
        
        # Trigger-specific adjustments
        if trigger_type == TriggerType.DRAFT_GENERATION:
            if context.get('event_urgency') == 'HIGH':
                score += 15
        elif trigger_type == TriggerType.ENRICHMENT_FEC:
            if context.get('donor_tier') in ['A+', 'A', 'A-']:
                score += 20
        
        return min(100, score)
    
    def _calculate_expected_cost(self, trigger_type: TriggerType, context: Dict) -> float:
        """Model 4: Calculate expected cost"""
        
        base_costs = {
            TriggerType.HARVEST_IMPORT: BrainConfig.COST_HARVEST_IMPORT,
            TriggerType.HARVEST_MATCH: 0.0,
            TriggerType.ENRICHMENT_FEC: 0.0,
            TriggerType.ENRICHMENT_VOTER: 0.0,
            TriggerType.ENRICHMENT_PROPERTY: 0.0,
            TriggerType.PERSONA_ANALYSIS: BrainConfig.COST_PERSONA_ANALYSIS,
            TriggerType.DRAFT_GENERATION: BrainConfig.COST_DRAFT_GENERATION,
            TriggerType.APPROVAL_LEARNING: BrainConfig.COST_APPROVAL_LEARNING
        }
        
        cost = base_costs.get(trigger_type, 0.01)
        
        # Multiply by quantity if batch operation
        quantity = context.get('quantity', 1)
        
        return cost * quantity
    
    def _calculate_persona_score(self, trigger_type: TriggerType, context: Dict) -> int:
        """Model 5: Calculate persona match score"""
        
        if trigger_type not in [TriggerType.DRAFT_GENERATION, TriggerType.PERSONA_ANALYSIS]:
            return 70  # Default for non-social operations
        
        score = 50
        
        # Training data quality
        training_samples = context.get('training_samples', 0)
        if training_samples >= 100:
            score += 25
        elif training_samples >= 50:
            score += 15
        elif training_samples >= 20:
            score += 5
        
        # Profile confidence
        ml_confidence = context.get('ml_confidence', 50)
        score += int(ml_confidence * 0.25)
        
        return min(100, score)
    
    def _check_budget_approval(self, expected_cost: float) -> bool:
        """Model 6: Check if within budget limits"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Check daily spend
        cur.execute("""
            SELECT COALESCE(SUM(total_cost), 0) AS daily_spend
            FROM nexus_cost_transactions
            WHERE DATE(transaction_timestamp) = CURRENT_DATE
            AND cost_type = 'AI_API'
        """)
        daily = cur.fetchone()['daily_spend']
        
        # Check monthly spend
        cur.execute("""
            SELECT COALESCE(SUM(total_cost), 0) AS monthly_spend
            FROM nexus_cost_transactions
            WHERE transaction_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
            AND cost_type = 'AI_API'
        """)
        monthly = cur.fetchone()['monthly_spend']
        
        conn.close()
        
        daily_ok = (float(daily) + expected_cost) <= BrainConfig.DAILY_AI_BUDGET
        monthly_ok = (float(monthly) + expected_cost) <= BrainConfig.MONTHLY_AI_BUDGET
        
        return daily_ok and monthly_ok
    
    def _calculate_confidence_score(self, scores: ModelScores) -> int:
        """Model 7: Calculate overall confidence score"""
        
        confidence = 50
        
        # High ROI increases confidence
        if scores.model_1_expected_roi > 10:
            confidence += 20
        elif scores.model_1_expected_roi > 5:
            confidence += 10
        
        # High success probability increases confidence
        if scores.model_2_success_probability > 0.8:
            confidence += 15
        elif scores.model_2_success_probability > 0.6:
            confidence += 10
        
        # Budget approval
        if scores.model_6_budget_approved:
            confidence += 10
        
        # Persona match (for applicable operations)
        if scores.model_5_persona_match_score > 70:
            confidence += 5
        
        return min(100, confidence)
    
    # ========================================================================
    # RECORD DECISION (Following Brain Protocol)
    # ========================================================================
    
    def record_decision(self, trigger_id: str, decision: Decision, 
                       scores: ModelScores, candidate_id: str = None) -> str:
        """Record decision in intelligence_brain.nexus_decisions"""
        
        conn = self._get_db()
        cur = conn.cursor()
        
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
            decision_id,
            trigger_id,
            decision.value,
            scores.reason,
            scores.model_1_expected_roi,
            scores.model_2_success_probability,
            scores.model_3_relevance_score,
            scores.model_4_expected_cost,
            scores.model_5_persona_match_score,
            scores.model_6_budget_approved,
            scores.model_7_confidence_score,
            candidate_id
        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"   Recorded decision {decision_id}")
        return decision_id
    
    # ========================================================================
    # COST ACCOUNTING (Following 5-Level Hierarchy)
    # ========================================================================
    
    def record_cost(self, transaction: CostTransaction) -> str:
        """Record cost transaction following 5-level hierarchy"""
        
        conn = self._get_db()
        cur = conn.cursor()
        
        transaction_id = str(uuid.uuid4())
        
        cur.execute("""
            INSERT INTO nexus_cost_transactions (
                transaction_id, function_code, cost_type,
                quantity, unit_cost, total_cost,
                level_2_candidate_id, reference_type, reference_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            transaction_id,
            transaction.function_code,
            transaction.cost_type.value,
            transaction.quantity,
            transaction.unit_cost,
            transaction.total_cost,
            transaction.candidate_id,
            transaction.reference_type,
            transaction.reference_id
        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"💰 Recorded cost: ${transaction.total_cost:.4f} for {transaction.function_code}")
        return transaction_id
    
    # ========================================================================
    # BUDGET VS ACTUAL VS VARIANCE
    # ========================================================================
    
    def get_bva_report(self) -> List[BVAMetric]:
        """Get Budget vs Actual vs Variance report"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT metric_code, budget_value, actual_value
            FROM nexus_metrics_bva
            WHERE period_start <= CURRENT_DATE AND period_end >= CURRENT_DATE
            ORDER BY metric_category, metric_code
        """)
        
        rows = cur.fetchall()
        conn.close()
        
        return [
            BVAMetric(
                metric_code=r['metric_code'],
                budget_value=float(r['budget_value'] or 0),
                actual_value=float(r['actual_value'] or 0)
            )
            for r in rows
        ]
    
    def update_bva_actuals(self):
        """Update actual values in BVA metrics"""
        
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("SELECT nexus_update_bva_metrics()")
        
        conn.commit()
        conn.close()
        
        logger.info("📊 Updated BVA actuals")
    
    def get_budget_status(self) -> Dict:
        """Get current budget status"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Daily AI spend
        cur.execute("""
            SELECT COALESCE(SUM(total_cost), 0) AS spend
            FROM nexus_cost_transactions
            WHERE DATE(transaction_timestamp) = CURRENT_DATE
            AND cost_type = 'AI_API'
        """)
        daily_ai = float(cur.fetchone()['spend'])
        
        # Monthly AI spend
        cur.execute("""
            SELECT COALESCE(SUM(total_cost), 0) AS spend
            FROM nexus_cost_transactions
            WHERE transaction_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
            AND cost_type = 'AI_API'
        """)
        monthly_ai = float(cur.fetchone()['spend'])
        
        # Total monthly spend
        cur.execute("""
            SELECT COALESCE(SUM(total_cost), 0) AS spend
            FROM nexus_cost_transactions
            WHERE transaction_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
        """)
        monthly_total = float(cur.fetchone()['spend'])
        
        conn.close()
        
        return {
            'daily_ai_spend': daily_ai,
            'daily_ai_budget': BrainConfig.DAILY_AI_BUDGET,
            'daily_ai_pct': (daily_ai / BrainConfig.DAILY_AI_BUDGET) * 100,
            'monthly_ai_spend': monthly_ai,
            'monthly_ai_budget': BrainConfig.MONTHLY_AI_BUDGET,
            'monthly_ai_pct': (monthly_ai / BrainConfig.MONTHLY_AI_BUDGET) * 100,
            'monthly_total_spend': monthly_total,
            'daily_ai_remaining': BrainConfig.DAILY_AI_BUDGET - daily_ai,
            'monthly_ai_remaining': BrainConfig.MONTHLY_AI_BUDGET - monthly_ai
        }
    
    # ========================================================================
    # EXECUTIVE DASHBOARD
    # ========================================================================
    
    def get_executive_dashboard(self) -> Dict:
        """Get executive dashboard data"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM v_nexus_executive_dashboard")
        dashboard = cur.fetchone()
        
        conn.close()
        
        return dict(dashboard) if dashboard else {}
    
    def get_operations_report(self, days: int = 30) -> List[Dict]:
        """Get operations report"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM v_nexus_operations_report
            WHERE report_date > CURRENT_DATE - INTERVAL '%s days'
            ORDER BY report_date DESC
        """, (days,))
        
        rows = cur.fetchall()
        conn.close()
        
        return [dict(r) for r in rows]
    
    def get_candidate_performance(self) -> List[Dict]:
        """Get candidate performance report"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM v_nexus_candidate_performance")
        
        rows = cur.fetchall()
        conn.close()
        
        return [dict(r) for r in rows]


# ============================================================================
# LINEAR PROGRAMMING OPTIMIZER
# ============================================================================

class NexusLPOptimizer:
    """
    Linear Programming optimizer for resource allocation
    """
    
    def __init__(self, db_url: str = None):
        self.db_url = db_url or BrainConfig.DATABASE_URL
        logger.info("📐 NEXUS LP Optimizer initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    def get_constraints(self, scope_type: str = 'GLOBAL') -> List[Dict]:
        """Get active LP constraints"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM nexus_lp_constraints
            WHERE is_active = TRUE
            AND (scope_type = %s OR scope_type = 'GLOBAL')
            ORDER BY is_hard_constraint DESC, constraint_type
        """, (scope_type,))
        
        rows = cur.fetchall()
        conn.close()
        
        return [dict(r) for r in rows]
    
    def optimize_daily_allocation(self, candidates: List[str]) -> Dict:
        """
        Optimize daily resource allocation across candidates
        
        Objective: Maximize total expected value
        Subject to: Budget, capacity, quality constraints
        """
        logger.info(f"🎯 Optimizing daily allocation for {len(candidates)} candidates")
        
        constraints = self.get_constraints()
        
        # Simple greedy allocation (replace with scipy.optimize for production)
        daily_budget = BrainConfig.DAILY_AI_BUDGET
        per_candidate_budget = daily_budget / max(len(candidates), 1)
        
        allocation = {}
        for candidate_id in candidates:
            allocation[candidate_id] = {
                'drafts_allowed': min(5, int(per_candidate_budget / BrainConfig.COST_DRAFT_GENERATION)),
                'persona_refresh': per_candidate_budget >= BrainConfig.COST_PERSONA_ANALYSIS,
                'budget_allocated': per_candidate_budget
            }
        
        # Record optimization run
        run_id = self._record_lp_run(
            run_type='DAILY_ALLOCATION',
            objective='Maximize expected value',
            status='OPTIMAL',
            solution=allocation
        )
        
        return {
            'run_id': run_id,
            'allocation': allocation,
            'total_budget': daily_budget,
            'candidates_allocated': len(candidates)
        }
    
    def _record_lp_run(self, run_type: str, objective: str, 
                       status: str, solution: Dict) -> str:
        """Record LP optimization run"""
        
        conn = self._get_db()
        cur = conn.cursor()
        
        run_id = str(uuid.uuid4())
        
        cur.execute("""
            INSERT INTO nexus_lp_runs (
                run_id, run_type, objective, status,
                solution_variables, applied, applied_at
            ) VALUES (%s, %s, %s, %s, %s, TRUE, NOW())
        """, (
            run_id,
            run_type,
            objective,
            status,
            Json(solution)
        ))
        
        conn.commit()
        conn.close()
        
        return run_id


# ============================================================================
# ML MODEL MANAGER
# ============================================================================

class NexusMLManager:
    """
    Manages NEXUS ML models and predictions
    """
    
    def __init__(self, db_url: str = None):
        self.db_url = db_url or BrainConfig.DATABASE_URL
        logger.info("🤖 NEXUS ML Manager initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    def get_active_models(self) -> List[Dict]:
        """Get active ML models"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT model_id, model_code, model_name, model_type,
                   algorithm, framework, accuracy, f1_score,
                   is_champion, deployed_at
            FROM nexus_ml_models
            WHERE is_active = TRUE
            ORDER BY model_code
        """)
        
        rows = cur.fetchall()
        conn.close()
        
        return [dict(r) for r in rows]
    
    def record_prediction(self, model_code: str, input_features: Dict,
                         prediction_value: float = None, prediction_class: str = None,
                         confidence: float = None, target_type: str = None,
                         target_id: str = None) -> str:
        """Record ML prediction for model improvement"""
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get model ID
        cur.execute("""
            SELECT model_id FROM nexus_ml_models WHERE model_code = %s
        """, (model_code,))
        row = cur.fetchone()
        
        if not row:
            conn.close()
            raise ValueError(f"Model {model_code} not found")
        
        model_id = row['model_id']
        prediction_id = str(uuid.uuid4())
        
        cur.execute("""
            INSERT INTO nexus_ml_predictions (
                prediction_id, model_id, input_features,
                prediction_value, prediction_class, confidence,
                target_type, target_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            prediction_id,
            model_id,
            Json(input_features),
            prediction_value,
            prediction_class,
            confidence,
            target_type,
            target_id
        ))
        
        conn.commit()
        conn.close()
        
        return prediction_id
    
    def record_feedback(self, prediction_id: str, actual_value: float = None,
                       actual_class: str = None):
        """Record actual outcome for prediction"""
        
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE nexus_ml_predictions SET
                actual_value = %s,
                actual_class = %s,
                feedback_at = NOW()
            WHERE prediction_id = %s
        """, (actual_value, actual_class, prediction_id))
        
        conn.commit()
        conn.close()
        
        logger.info(f"📝 Recorded feedback for prediction {prediction_id}")


# ============================================================================
# STANDALONE EXECUTION
# ============================================================================

if __name__ == "__main__":
    print("=" * 70)
    print("NEXUS BRAIN INTEGRATION ENGINE")
    print("GO/NO-GO decisions with 7 mathematical models")
    print("=" * 70)
    
    brain = NexusBrainEngine()
    
    print("\n📊 Budget Status:")
    status = brain.get_budget_status()
    print(f"   Daily AI: ${status['daily_ai_spend']:.2f} / ${status['daily_ai_budget']:.2f} ({status['daily_ai_pct']:.1f}%)")
    print(f"   Monthly AI: ${status['monthly_ai_spend']:.2f} / ${status['monthly_ai_budget']:.2f} ({status['monthly_ai_pct']:.1f}%)")
    
    print("\n🎯 Example Decision:")
    decision, scores = brain.make_decision(
        TriggerType.DRAFT_GENERATION,
        {'candidate_id': 'test', 'training_samples': 75, 'ml_confidence': 80}
    )
    print(f"   Decision: {decision.value}")
    print(f"   Composite Score: {scores.composite_score()}")
    print(f"   ROI: {scores.model_1_expected_roi:.1f}x")
    print(f"   Budget Approved: {scores.model_6_budget_approved}")
    
    print("\n📈 BVA Report:")
    bva = brain.get_bva_report()
    for metric in bva[:5]:
        print(f"   {metric.metric_code}: B=${metric.budget_value:.2f} A=${metric.actual_value:.2f} V={metric.variance_pct:+.1f}% [{metric.status}]")
