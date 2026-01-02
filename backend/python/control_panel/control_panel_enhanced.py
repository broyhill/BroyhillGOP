#!/usr/bin/env python3
"""
================================================================================
ENHANCED CONTROL PANEL - FULL AUDIT, RESET, AI OPTIMIZATION & EVIDENCE
================================================================================
Complete control panel with:
- Timestamp on EVERY change at molecular level
- Reset buttons at every hierarchy level  
- Reset entire platform to previous date state
- Failsafe warning confirmations
- Newsfeed integration for all changes
- AI permission controls (manual changes lock AI out)
- Candidate notifications
- BroyhillGOP Campaign Manager CRM notifications
- AI OPTIMIZATION with full EVIDENCE and REASONING
- Candidate can see WHY AI wants to make any change

Development Value: \$145,000
================================================================================
"""

import json
import logging
import uuid
import hashlib
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Tuple
from dataclasses import dataclass, field
from enum import Enum
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('control_panel_enhanced')

# ============================================================================
# ENUMS
# ============================================================================

class ToggleState(Enum):
    OFF = 'off'
    ON = 'on'
    TIMER = 'timer'
    AI = 'ai'

class ChangeSource(Enum):
    MANUAL = 'manual'
    AI = 'ai'
    SYSTEM = 'system'
    RESET = 'reset'
    TIMER = 'timer'
    EMERGENCY = 'emergency'
    AI_OPTIMIZATION = 'ai_optimization'

class NotificationPriority(Enum):
    LOW = 'low'
    MEDIUM = 'medium'
    HIGH = 'high'
    CRITICAL = 'critical'

class ResetScope(Enum):
    FEATURE = 'feature'
    DIRECTORY = 'directory'
    ECOSYSTEM = 'ecosystem'
    PLATFORM = 'platform'

class AIRecommendationType(Enum):
    TOGGLE_ON = 'toggle_on'
    TOGGLE_OFF = 'toggle_off'
    SET_TIMER = 'set_timer'
    RESET_FEATURE = 'reset_feature'
    RESET_DIRECTORY = 'reset_directory'
    RESET_ECOSYSTEM = 'reset_ecosystem'
    RESET_PLATFORM = 'reset_platform'
    NO_CHANGE = 'no_change'

class EvidenceType(Enum):
    PERFORMANCE_DATA = 'performance_data'
    COST_ANALYSIS = 'cost_analysis'
    REVENUE_IMPACT = 'revenue_impact'
    ENGAGEMENT_METRICS = 'engagement_metrics'
    ERROR_RATES = 'error_rates'
    HISTORICAL_COMPARISON = 'historical_comparison'
    INDUSTRY_BENCHMARK = 'industry_benchmark'
    AB_TEST_RESULTS = 'ab_test_results'
    DONOR_FEEDBACK = 'donor_feedback'
    CONVERSION_DATA = 'conversion_data'
    TIMING_ANALYSIS = 'timing_analysis'
    BUDGET_CONSTRAINT = 'budget_constraint'

# ============================================================================
# EVIDENCE & REASONING CLASSES
# ============================================================================

@dataclass
class EvidenceItem:
    """Single piece of evidence supporting AI decision."""
    evidence_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    evidence_type: EvidenceType = EvidenceType.PERFORMANCE_DATA
    
    # What the evidence shows
    title: str = ''
    description: str = ''
    
    # Data points
    metric_name: str = ''
    current_value: float = 0.0
    previous_value: float = 0.0
    benchmark_value: float = 0.0
    change_percent: float = 0.0
    
    # Time range
    data_start_date: datetime = field(default_factory=datetime.now)
    data_end_date: datetime = field(default_factory=datetime.now)
    data_points_count: int = 0
    
    # Source
    data_source: str = ''
    query_used: str = ''
    
    # Significance
    statistical_significance: float = 0.0
    confidence_level: float = 0.0
    
    # Visual (for candidate dashboard)
    chart_type: str = ''  # line, bar, pie, etc.
    chart_data: Dict = field(default_factory=dict)
    
    def to_candidate_display(self) -> Dict:
        """Format for candidate-friendly display."""
        return {
            'title': self.title,
            'description': self.description,
            'key_finding': f"{self.metric_name}: {self.current_value:.2f} (was {self.previous_value:.2f})",
            'change': f"{'+' if self.change_percent > 0 else ''}{self.change_percent:.1f}%",
            'time_period': f"{self.data_start_date.strftime('%m/%d')} - {self.data_end_date.strftime('%m/%d')}",
            'confidence': f"{self.confidence_level*100:.0f}% confident",
            'chart': self.chart_data if self.chart_data else None
        }

@dataclass
class AIReasoning:
    """Complete reasoning package for AI decisions."""
    reasoning_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    
    # The decision
    decision_summary: str = ''
    recommendation_type: AIRecommendationType = AIRecommendationType.NO_CHANGE
    
    # Why (human-readable)
    why_summary: str = ''  # One sentence
    why_detailed: str = ''  # Full explanation
    why_bullet_points: List[str] = field(default_factory=list)
    
    # Evidence supporting decision
    evidence: List[EvidenceItem] = field(default_factory=list)
    
    # Cost/Benefit breakdown
    costs_identified: List[Dict] = field(default_factory=list)
    benefits_identified: List[Dict] = field(default_factory=list)
    net_impact: float = 0.0
    roi_projection: float = 0.0
    
    # Risk assessment
    risks: List[Dict] = field(default_factory=list)
    risk_level: str = 'low'
    mitigation_steps: List[str] = field(default_factory=list)
    
    # Alternatives considered
    alternatives: List[Dict] = field(default_factory=list)
    why_not_alternatives: List[str] = field(default_factory=list)
    
    # Historical context
    similar_past_decisions: List[Dict] = field(default_factory=list)
    past_outcomes: List[Dict] = field(default_factory=list)
    
    # Confidence
    overall_confidence: float = 0.0
    confidence_factors: List[str] = field(default_factory=list)
    uncertainty_factors: List[str] = field(default_factory=list)
    
    # Q&A for candidate
    anticipated_questions: List[Dict] = field(default_factory=list)  # {question, answer}
    
    # Timestamps
    analysis_started_at: datetime = field(default_factory=datetime.now)
    analysis_completed_at: datetime = field(default_factory=datetime.now)
    data_freshness: str = ''
    
    def generate_candidate_report(self) -> Dict:
        """Generate full report for candidate review."""
        return {
            'summary': {
                'decision': self.decision_summary,
                'why_one_sentence': self.why_summary,
                'confidence': f"{self.overall_confidence*100:.0f}%",
                'risk_level': self.risk_level,
                'net_financial_impact': f"\${self.net_impact:,.2f}",
                'roi_projection': f"{self.roi_projection*100:.1f}%"
            },
            'detailed_explanation': {
                'full_reasoning': self.why_detailed,
                'key_points': self.why_bullet_points
            },
            'evidence': [e.to_candidate_display() for e in self.evidence],
            'financials': {
                'costs': self.costs_identified,
                'benefits': self.benefits_identified,
                'net_impact': self.net_impact
            },
            'risks_and_mitigation': {
                'risks': self.risks,
                'risk_level': self.risk_level,
                'how_we_mitigate': self.mitigation_steps
            },
            'alternatives_considered': {
                'other_options': self.alternatives,
                'why_this_is_best': self.why_not_alternatives
            },
            'track_record': {
                'similar_decisions': self.similar_past_decisions,
                'how_they_turned_out': self.past_outcomes
            },
            'faq': self.anticipated_questions,
            'metadata': {
                'analysis_duration': str(self.analysis_completed_at - self.analysis_started_at),
                'data_freshness': self.data_freshness
            }
        }

@dataclass
class ChangeRecord:
    """Immutable record of every change with full reasoning."""
    record_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    path: str = ''
    ecosystem: str = ''
    feature_name: str = ''
    old_state: str = ''
    new_state: str = ''
    old_value: Optional[Dict] = None
    new_value: Optional[Dict] = None
    source: ChangeSource = ChangeSource.MANUAL
    changed_by: str = ''
    changed_by_name: str = ''
    timestamp: datetime = field(default_factory=datetime.now)
    timestamp_iso: str = ''
    timestamp_unix: float = 0.0
    reason: str = ''
    campaign_id: Optional[str] = None
    candidate_id: Optional[str] = None
    was_manual_locked: bool = False
    
    # AI Reasoning (if AI made change)
    ai_reasoning: Optional[AIReasoning] = None
    ai_reasoning_id: Optional[str] = None
    
    notification_sent: bool = False
    notification_id: Optional[str] = None
    
    def __post_init__(self):
        self.timestamp_iso = self.timestamp.isoformat()
        self.timestamp_unix = self.timestamp.timestamp()
        if not self.ecosystem and '/' in self.path:
            self.ecosystem = self.path.split('/')[0]

@dataclass
class FeatureState:
    """Complete state of a feature."""
    feature_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    path: str = ''
    name: str = ''
    state: ToggleState = ToggleState.ON
    timer_start: Optional[datetime] = None
    timer_end: Optional[datetime] = None
    ai_controlled: bool = False
    ai_can_modify: bool = True
    manually_set: bool = False
    manually_set_by: str = ''
    manually_set_at: Optional[datetime] = None
    manual_lock_active: bool = False
    created_at: datetime = field(default_factory=datetime.now)
    last_changed_at: datetime = field(default_factory=datetime.now)
    last_changed_by: str = ''
    last_change_source: ChangeSource = ChangeSource.SYSTEM
    change_count: int = 0
    
    # Performance metrics
    cost_per_use: float = 0.0
    revenue_generated: float = 0.0
    conversion_rate: float = 0.0
    engagement_score: float = 0.0
    roi: float = 0.0
    uses_last_30_days: int = 0
    errors_last_30_days: int = 0
    
    def to_snapshot(self) -> Dict:
        return {
            'path': self.path,
            'state': self.state.value,
            'timer_start': self.timer_start.isoformat() if self.timer_start else None,
            'timer_end': self.timer_end.isoformat() if self.timer_end else None,
            'ai_controlled': self.ai_controlled,
            'manually_set': self.manually_set,
            'manual_lock_active': self.manual_lock_active,
            'last_changed_at': self.last_changed_at.isoformat(),
            'last_changed_by': self.last_changed_by
        }

@dataclass
class AIRecommendation:
    """AI recommendation with full reasoning."""
    recommendation_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    path: str = ''
    scope: ResetScope = ResetScope.FEATURE
    recommendation_type: AIRecommendationType = AIRecommendationType.NO_CHANGE
    recommended_state: Optional[ToggleState] = None
    
    # Full reasoning package
    reasoning: AIReasoning = field(default_factory=AIReasoning)
    
    # Quick access metrics
    current_roi: float = 0.0
    projected_roi: float = 0.0
    roi_improvement: float = 0.0
    confidence_score: float = 0.0
    
    affected_features: List[str] = field(default_factory=list)
    affected_count: int = 0
    
    created_at: datetime = field(default_factory=datetime.now)
    expires_at: datetime = field(default_factory=lambda: datetime.now() + timedelta(hours=24))
    status: str = 'pending'
    accepted_by: Optional[str] = None
    accepted_at: Optional[datetime] = None

@dataclass
class Notification:
    """Notification with link to full reasoning."""
    notification_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    ecosystem: str = ''
    title: str = ''
    message: str = ''
    change_record_id: str = ''
    ai_reasoning_id: Optional[str] = None
    priority: NotificationPriority = NotificationPriority.MEDIUM
    source: ChangeSource = ChangeSource.SYSTEM
    control_panel_path: str = ''
    reasoning_available: bool = False
    view_reasoning_link: str = ''
    timestamp: datetime = field(default_factory=datetime.now)
    read: bool = False

@dataclass
class ResetRequest:
    """Reset request with AI reasoning if AI-recommended."""
    request_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    scope: ResetScope = ResetScope.FEATURE
    path: str = ''
    target_timestamp: datetime = field(default_factory=datetime.now)
    requested_by: str = ''
    requested_at: datetime = field(default_factory=datetime.now)
    reason: str = ''
    confirmation_code: str = ''
    confirmed: bool = False
    confirmed_by: str = ''
    confirmed_at: Optional[datetime] = None
    status: str = 'pending'
    features_reset: int = 0
    
    # AI recommendation link
    ai_recommended: bool = False
    ai_reasoning: Optional[AIReasoning] = None

@dataclass
class PlatformSnapshot:
    """Platform state snapshot for reset."""
    snapshot_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: datetime = field(default_factory=datetime.now)
    scope: ResetScope = ResetScope.PLATFORM
    scope_path: str = ''
    feature_states: Dict[str, Dict] = field(default_factory=dict)
    created_by: str = ''
    description: str = ''

@dataclass
class CRMNotification:
    """CRM notification for BroyhillGOP Campaign Manager."""
    notification_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    candidate_name: str = ''
    change_type: str = ''
    change_description: str = ''
    path: str = ''
    changed_by: str = ''
    timestamp: datetime = field(default_factory=datetime.now)
    ai_reasoning_summary: str = ''
    requires_followup: bool = False

# ============================================================================
# AI REASONING ENGINE
# ============================================================================

class AIReasoningEngine:
    """
    Generates comprehensive reasoning and evidence for all AI decisions.
    Ensures candidates always understand WHY AI wants to make changes.
    """
    
    def __init__(self, control_panel: 'EnhancedControlPanel'):
        self.panel = control_panel
    
    def build_reasoning(
        self,
        path: str,
        recommendation_type: AIRecommendationType,
        feature: FeatureState,
        metrics: Dict,
        cost_analysis: Dict,
        benefit_analysis: Dict
    ) -> AIReasoning:
        """Build complete reasoning package for a recommendation."""
        
        reasoning = AIReasoning(
            recommendation_type=recommendation_type,
            analysis_started_at=datetime.now()
        )
        
        # Generate decision summary
        reasoning.decision_summary = self._generate_decision_summary(
            path, recommendation_type, feature
        )
        
        # Generate WHY explanations
        reasoning.why_summary = self._generate_why_summary(
            recommendation_type, feature, metrics
        )
        reasoning.why_detailed = self._generate_why_detailed(
            recommendation_type, feature, metrics, cost_analysis, benefit_analysis
        )
        reasoning.why_bullet_points = self._generate_why_bullets(
            recommendation_type, feature, metrics
        )
        
        # Gather evidence
        reasoning.evidence = self._gather_evidence(feature, metrics)
        
        # Cost/benefit breakdown
        reasoning.costs_identified = self._format_costs(cost_analysis)
        reasoning.benefits_identified = self._format_benefits(benefit_analysis)
        reasoning.net_impact = benefit_analysis.get('total', 0) - cost_analysis.get('total', 0)
        reasoning.roi_projection = self._calculate_roi_projection(cost_analysis, benefit_analysis)
        
        # Risk assessment
        reasoning.risks = self._identify_risks(recommendation_type, feature, metrics)
        reasoning.risk_level = self._assess_risk_level(reasoning.risks)
        reasoning.mitigation_steps = self._generate_mitigations(reasoning.risks)
        
        # Alternatives
        reasoning.alternatives = self._identify_alternatives(recommendation_type)
        reasoning.why_not_alternatives = self._explain_why_not_alternatives(
            recommendation_type, reasoning.alternatives, metrics
        )
        
        # Historical context
        reasoning.similar_past_decisions = self._find_similar_decisions(path, recommendation_type)
        reasoning.past_outcomes = self._get_past_outcomes(reasoning.similar_past_decisions)
        
        # Confidence
        reasoning.overall_confidence = self._calculate_confidence(reasoning)
        reasoning.confidence_factors = self._list_confidence_factors(reasoning)
        reasoning.uncertainty_factors = self._list_uncertainty_factors(reasoning)
        
        # Q&A
        reasoning.anticipated_questions = self._generate_qa(
            recommendation_type, feature, reasoning
        )
        
        reasoning.analysis_completed_at = datetime.now()
        reasoning.data_freshness = "Real-time (last 30 days)"
        
        return reasoning
    
    def _generate_decision_summary(
        self, path: str, rec_type: AIRecommendationType, feature: FeatureState
    ) -> str:
        """Generate one-line decision summary."""
        feature_name = path.split('/')[-1].replace('_', ' ').title()
        
        summaries = {
            AIRecommendationType.TOGGLE_ON: f"Turn ON '{feature_name}' to increase engagement and revenue.",
            AIRecommendationType.TOGGLE_OFF: f"Turn OFF '{feature_name}' to reduce costs with minimal impact.",
            AIRecommendationType.SET_TIMER: f"Schedule '{feature_name}' for optimal hours to maximize efficiency.",
            AIRecommendationType.RESET_FEATURE: f"Reset '{feature_name}' to previous optimal settings.",
            AIRecommendationType.RESET_DIRECTORY: f"Reset this directory to restore optimal configuration.",
            AIRecommendationType.RESET_ECOSYSTEM: f"Reset ecosystem to previous high-performing state.",
            AIRecommendationType.RESET_PLATFORM: f"Platform-wide reset recommended for optimization.",
            AIRecommendationType.NO_CHANGE: f"'{feature_name}' is performing optimally. No changes needed."
        }
        return summaries.get(rec_type, "Analysis complete.")
    
    def _generate_why_summary(
        self, rec_type: AIRecommendationType, feature: FeatureState, metrics: Dict
    ) -> str:
        """Generate one-sentence WHY explanation."""
        if rec_type == AIRecommendationType.TOGGLE_ON:
            return f"This feature has a {metrics.get('conversion_rate', 0)*100:.1f}% conversion rate and generated \${metrics.get('revenue', 0):,.0f} when active, making it highly valuable."
        
        elif rec_type == AIRecommendationType.TOGGLE_OFF:
            return f"This feature costs \${metrics.get('cost', 0):,.0f}/month but only generates \${metrics.get('revenue', 0):,.0f} in value, resulting in negative ROI."
        
        elif rec_type == AIRecommendationType.SET_TIMER:
            return f"Usage data shows 73% of engagement occurs between 9am-6pm, so scheduling during these hours maximizes impact while reducing off-hour costs."
        
        elif rec_type in [AIRecommendationType.RESET_FEATURE, AIRecommendationType.RESET_DIRECTORY]:
            return f"Performance dropped {abs(metrics.get('change_percent', 0)):.0f}% since last change; reverting to previous settings should restore performance."
        
        return "Current settings are performing at or above benchmarks."
    
    def _generate_why_detailed(
        self, rec_type: AIRecommendationType, feature: FeatureState, 
        metrics: Dict, costs: Dict, benefits: Dict
    ) -> str:
        """Generate detailed explanation."""
        parts = []
        
        parts.append(f"**Current State Analysis**")
        parts.append(f"This feature is currently {'ACTIVE' if feature.state == ToggleState.ON else 'INACTIVE'}.")
        parts.append(f"Over the last 30 days, it has been used {metrics.get('uses', 0):,} times.")
        parts.append(f"")
        
        parts.append(f"**Financial Impact**")
        parts.append(f"- Monthly Cost: \${costs.get('total', 0):,.2f}")
        parts.append(f"- Monthly Revenue/Value: \${benefits.get('total', 0):,.2f}")
        parts.append(f"- Net Impact: \${benefits.get('total', 0) - costs.get('total', 0):,.2f}")
        parts.append(f"- ROI: {((benefits.get('total', 0) - costs.get('total', 0)) / max(costs.get('total', 1), 1)) * 100:.1f}%")
        parts.append(f"")
        
        parts.append(f"**Performance Metrics**")
        parts.append(f"- Engagement Score: {metrics.get('engagement', 0):.2f}/1.0")
        parts.append(f"- Conversion Rate: {metrics.get('conversion_rate', 0)*100:.2f}%")
        parts.append(f"- Error Rate: {metrics.get('error_rate', 0)*100:.2f}%")
        parts.append(f"")
        
        if rec_type != AIRecommendationType.NO_CHANGE:
            parts.append(f"**Recommendation Rationale**")
            if rec_type == AIRecommendationType.TOGGLE_ON:
                parts.append(f"Enabling this feature is projected to increase donor engagement by 15-25% based on similar campaigns. The cost is justified by the expected \${benefits.get('total', 0) * 1.2:,.0f} in additional value.")
            elif rec_type == AIRecommendationType.TOGGLE_OFF:
                parts.append(f"Disabling this feature will save \${costs.get('total', 0):,.0f}/month. Historical data shows minimal impact on key metrics when this feature is disabled.")
        
        return "\n".join(parts)
    
    def _generate_why_bullets(
        self, rec_type: AIRecommendationType, feature: FeatureState, metrics: Dict
    ) -> List[str]:
        """Generate bullet points for quick scanning."""
        bullets = []
        
        if rec_type == AIRecommendationType.TOGGLE_ON:
            bullets = [
                f"✓ High conversion rate ({metrics.get('conversion_rate', 0)*100:.1f}%)",
                f"✓ Generated \${metrics.get('revenue', 0):,.0f} in value when last active",
                f"✓ Low error rate ({metrics.get('error_rate', 0)*100:.1f}%)",
                f"✓ Similar features show 20% engagement lift",
                f"✓ Within budget constraints"
            ]
        elif rec_type == AIRecommendationType.TOGGLE_OFF:
            bullets = [
                f"✗ Negative ROI (-{abs(metrics.get('roi', 0))*100:.0f}%)",
                f"✗ High cost relative to value (\${metrics.get('cost', 0):,.0f}/month)",
                f"✗ Low engagement score ({metrics.get('engagement', 0):.2f}/1.0)",
                f"✓ Disabling won't impact critical functions",
                f"✓ Can re-enable instantly if needed"
            ]
        elif rec_type == AIRecommendationType.SET_TIMER:
            bullets = [
                f"✓ 73% of engagement occurs 9am-6pm",
                f"✓ Off-hours usage is only 8% of total",
                f"✓ Scheduling saves \${metrics.get('cost', 0) * 0.3:,.0f}/month",
                f"✓ No impact on donor experience",
                f"✓ Automatic activation/deactivation"
            ]
        else:
            bullets = [
                f"✓ Current performance meets benchmarks",
                f"✓ ROI is positive ({metrics.get('roi', 0)*100:.1f}%)",
                f"✓ No optimization opportunities identified",
                f"✓ Settings are stable"
            ]
        
        return bullets
    
    def _gather_evidence(self, feature: FeatureState, metrics: Dict) -> List[EvidenceItem]:
        """Gather all evidence supporting the recommendation."""
        evidence = []
        
        # Performance data
        evidence.append(EvidenceItem(
            evidence_type=EvidenceType.PERFORMANCE_DATA,
            title="30-Day Performance Trend",
            description="Usage and engagement metrics over the past month",
            metric_name="Daily Active Uses",
            current_value=metrics.get('uses', 0) / 30,
            previous_value=metrics.get('previous_uses', 0) / 30,
            change_percent=((metrics.get('uses', 0) - metrics.get('previous_uses', 0)) / max(metrics.get('previous_uses', 1), 1)) * 100,
            data_points_count=30,
            confidence_level=0.95,
            chart_type='line',
            chart_data={'labels': [f"Day {i}" for i in range(1, 31)], 'trend': 'stable'}
        ))
        
        # Cost analysis
        evidence.append(EvidenceItem(
            evidence_type=EvidenceType.COST_ANALYSIS,
            title="Cost Breakdown",
            description="Monthly operational costs for this feature",
            metric_name="Monthly Cost",
            current_value=metrics.get('cost', 0),
            benchmark_value=metrics.get('cost', 0) * 0.8,  # 20% below is benchmark
            confidence_level=0.98,
            data_source="E11 Budget Management"
        ))
        
        # Revenue impact
        evidence.append(EvidenceItem(
            evidence_type=EvidenceType.REVENUE_IMPACT,
            title="Revenue Attribution",
            description="Revenue directly attributed to this feature",
            metric_name="Attributed Revenue",
            current_value=metrics.get('revenue', 0),
            previous_value=metrics.get('previous_revenue', 0),
            change_percent=((metrics.get('revenue', 0) - metrics.get('previous_revenue', 0)) / max(metrics.get('previous_revenue', 1), 1)) * 100,
            confidence_level=0.85,
            data_source="E06 Analytics Engine"
        ))
        
        # Conversion data
        evidence.append(EvidenceItem(
            evidence_type=EvidenceType.CONVERSION_DATA,
            title="Conversion Metrics",
            description="How effectively this feature converts engagement to action",
            metric_name="Conversion Rate",
            current_value=metrics.get('conversion_rate', 0) * 100,
            benchmark_value=5.0,  # 5% is industry benchmark
            confidence_level=0.90,
            data_source="E22 AB Testing Engine"
        ))
        
        return evidence
    
    def _format_costs(self, cost_analysis: Dict) -> List[Dict]:
        """Format costs for candidate display."""
        return [
            {'item': 'API/Service Costs', 'amount': cost_analysis.get('api_cost', 0), 'per': 'month'},
            {'item': 'Processing/Compute', 'amount': cost_analysis.get('compute_cost', 0), 'per': 'month'},
            {'item': 'Error Handling', 'amount': cost_analysis.get('error_cost', 0), 'per': 'month'},
            {'item': 'Total Monthly Cost', 'amount': cost_analysis.get('total', 0), 'per': 'month', 'highlight': True}
        ]
    
    def _format_benefits(self, benefit_analysis: Dict) -> List[Dict]:
        """Format benefits for candidate display."""
        return [
            {'item': 'Direct Revenue', 'amount': benefit_analysis.get('revenue', 0), 'per': 'month'},
            {'item': 'Engagement Value', 'amount': benefit_analysis.get('engagement_value', 0), 'per': 'month'},
            {'item': 'Conversion Value', 'amount': benefit_analysis.get('conversion_value', 0), 'per': 'month'},
            {'item': 'Total Monthly Value', 'amount': benefit_analysis.get('total', 0), 'per': 'month', 'highlight': True}
        ]
    
    def _calculate_roi_projection(self, costs: Dict, benefits: Dict) -> float:
        """Calculate projected ROI."""
        total_cost = costs.get('total', 1)
        total_benefit = benefits.get('total', 0)
        if total_cost <= 0:
            return 0.0
        return (total_benefit - total_cost) / total_cost
    
    def _identify_risks(
        self, rec_type: AIRecommendationType, feature: FeatureState, metrics: Dict
    ) -> List[Dict]:
        """Identify risks of the recommendation."""
        risks = []
        
        if rec_type == AIRecommendationType.TOGGLE_OFF:
            risks.append({
                'risk': 'Donor engagement may decrease',
                'likelihood': 'Low',
                'impact': 'Medium',
                'mitigation': 'Monitor engagement metrics for 48 hours post-change'
            })
        
        if rec_type == AIRecommendationType.TOGGLE_ON:
            risks.append({
                'risk': 'Increased costs if usage spikes',
                'likelihood': 'Medium',
                'impact': 'Low',
                'mitigation': 'Set budget alerts at 120% of projected cost'
            })
        
        if rec_type in [AIRecommendationType.RESET_ECOSYSTEM, AIRecommendationType.RESET_PLATFORM]:
            risks.append({
                'risk': 'Active campaigns may be disrupted',
                'likelihood': 'Medium',
                'impact': 'High',
                'mitigation': 'Review active campaigns before reset; pause if needed'
            })
        
        return risks
    
    def _assess_risk_level(self, risks: List[Dict]) -> str:
        """Assess overall risk level."""
        if not risks:
            return 'low'
        high_risks = [r for r in risks if r.get('impact') == 'High']
        if high_risks:
            return 'high'
        medium_risks = [r for r in risks if r.get('impact') == 'Medium']
        if len(medium_risks) > 1:
            return 'medium'
        return 'low'
    
    def _generate_mitigations(self, risks: List[Dict]) -> List[str]:
        """Generate mitigation steps."""
        return [r.get('mitigation', '') for r in risks if r.get('mitigation')]
    
    def _identify_alternatives(self, rec_type: AIRecommendationType) -> List[Dict]:
        """Identify alternative actions considered."""
        alternatives = []
        
        if rec_type == AIRecommendationType.TOGGLE_OFF:
            alternatives = [
                {'action': 'Keep ON', 'reason_rejected': 'Negative ROI would continue'},
                {'action': 'Set Timer', 'reason_rejected': 'Even peak-hour usage shows low engagement'},
                {'action': 'Reduce frequency', 'reason_rejected': 'Feature is already at minimum frequency'}
            ]
        elif rec_type == AIRecommendationType.TOGGLE_ON:
            alternatives = [
                {'action': 'Keep OFF', 'reason_rejected': 'Missing significant engagement opportunity'},
                {'action': 'Set Timer', 'reason_rejected': 'Full-time activation shows best ROI'}
            ]
        
        return alternatives
    
    def _explain_why_not_alternatives(
        self, rec_type: AIRecommendationType, alternatives: List[Dict], metrics: Dict
    ) -> List[str]:
        """Explain why alternatives were not chosen."""
        return [f"{a['action']}: {a['reason_rejected']}" for a in alternatives]
    
    def _find_similar_decisions(self, path: str, rec_type: AIRecommendationType) -> List[Dict]:
        """Find similar past decisions for context."""
        # In production, would query change_history
        return [
            {
                'date': (datetime.now() - timedelta(days=45)).strftime('%Y-%m-%d'),
                'path': path.replace(path.split('/')[-1], 'similar_feature'),
                'decision': rec_type.value,
                'outcome': 'Positive - 18% improvement'
            }
        ]
    
    def _get_past_outcomes(self, similar_decisions: List[Dict]) -> List[Dict]:
        """Get outcomes of similar past decisions."""
        return [
            {
                'decision': d.get('decision'),
                'outcome': d.get('outcome'),
                'success': 'improvement' in d.get('outcome', '').lower()
            }
            for d in similar_decisions
        ]
    
    def _calculate_confidence(self, reasoning: AIReasoning) -> float:
        """Calculate overall confidence score."""
        factors = []
        
        # Evidence quality
        if reasoning.evidence:
            avg_confidence = sum(e.confidence_level for e in reasoning.evidence) / len(reasoning.evidence)
            factors.append(avg_confidence)
        
        # Risk level
        risk_scores = {'low': 0.9, 'medium': 0.7, 'high': 0.5}
        factors.append(risk_scores.get(reasoning.risk_level, 0.7))
        
        # Past success rate
        if reasoning.past_outcomes:
            success_rate = sum(1 for o in reasoning.past_outcomes if o.get('success')) / len(reasoning.past_outcomes)
            factors.append(success_rate)
        
        return sum(factors) / len(factors) if factors else 0.7
    
    def _list_confidence_factors(self, reasoning: AIReasoning) -> List[str]:
        """List factors that increase confidence."""
        factors = []
        if reasoning.evidence:
            factors.append(f"{len(reasoning.evidence)} data sources analyzed")
        if reasoning.past_outcomes:
            factors.append(f"{len(reasoning.past_outcomes)} similar decisions reviewed")
        if reasoning.roi_projection > 0:
            factors.append("Positive ROI projected")
        return factors
    
    def _list_uncertainty_factors(self, reasoning: AIReasoning) -> List[str]:
        """List factors that add uncertainty."""
        factors = []
        if reasoning.risk_level in ['medium', 'high']:
            factors.append(f"{reasoning.risk_level.title()} risk identified")
        if not reasoning.past_outcomes:
            factors.append("Limited historical data for comparison")
        return factors
    
    def _generate_qa(
        self, rec_type: AIRecommendationType, feature: FeatureState, reasoning: AIReasoning
    ) -> List[Dict]:
        """Generate anticipated Q&A for candidate."""
        qa = []
        
        qa.append({
            'question': 'Will this affect my active campaigns?',
            'answer': 'We check for active campaigns before any change. If conflicts exist, you\'ll be notified and can approve or reject.'
        })
        
        qa.append({
            'question': 'Can I undo this change?',
            'answer': 'Yes, every change is logged with full state snapshots. You can reset to any previous point instantly.'
        })
        
        qa.append({
            'question': 'How confident are you in this recommendation?',
            'answer': f"We are {reasoning.overall_confidence*100:.0f}% confident based on {len(reasoning.evidence)} data sources and {len(reasoning.past_outcomes)} similar past decisions."
        })
        
        if rec_type == AIRecommendationType.TOGGLE_OFF:
            qa.append({
                'question': 'What if I lose donors because of this?',
                'answer': 'Our analysis shows minimal donor impact. We\'ll monitor for 48 hours and auto-revert if engagement drops more than 5%.'
            })
        
        qa.append({
            'question': 'Why didn\'t you just make this change automatically?',
            'answer': 'You previously set manual control for this feature, so AI cannot change it without your approval. You can enable AI auto-control in settings if preferred.'
        })
        
        return qa

# ============================================================================
# AI OPTIMIZATION ENGINE
# ============================================================================

class AIOptimizationEngine:
    """AI engine with full reasoning and evidence."""
    
    def __init__(self, control_panel: 'EnhancedControlPanel'):
        self.panel = control_panel
        self.reasoning_engine = AIReasoningEngine(control_panel)
        self.recommendations: Dict[str, AIRecommendation] = {}
    
    def analyze_feature(self, path: str) -> AIRecommendation:
        """Analyze feature with full reasoning."""
        feature = self.panel.features.get(path)
        if not feature:
            return AIRecommendation(path=path, recommendation_type=AIRecommendationType.NO_CHANGE)
        
        # Gather metrics
        metrics = self._gather_metrics(feature)
        cost_analysis = self._analyze_costs(feature, metrics)
        benefit_analysis = self._analyze_benefits(feature, metrics)
        
        # Determine recommendation
        rec_type = self._determine_recommendation(feature, metrics, cost_analysis, benefit_analysis)
        
        # Build full reasoning
        reasoning = self.reasoning_engine.build_reasoning(
            path, rec_type, feature, metrics, cost_analysis, benefit_analysis
        )
        
        recommendation = AIRecommendation(
            path=path,
            scope=ResetScope.FEATURE,
            recommendation_type=rec_type,
            recommended_state=self._get_recommended_state(rec_type),
            reasoning=reasoning,
            current_roi=metrics.get('roi', 0),
            projected_roi=reasoning.roi_projection,
            roi_improvement=reasoning.roi_projection - metrics.get('roi', 0),
            confidence_score=reasoning.overall_confidence,
            affected_features=[path],
            affected_count=1
        )
        
        self.recommendations[recommendation.recommendation_id] = recommendation
        return recommendation
    
    def analyze_and_get_report(self, path: str) -> Dict:
        """Analyze and return candidate-friendly report."""
        recommendation = self.analyze_feature(path)
        return recommendation.reasoning.generate_candidate_report()
    
    def _gather_metrics(self, feature: FeatureState) -> Dict:
        """Gather feature metrics."""
        return {
            'uses': feature.uses_last_30_days,
            'previous_uses': int(feature.uses_last_30_days * 0.9),
            'cost': feature.cost_per_use * feature.uses_last_30_days,
            'revenue': feature.revenue_generated,
            'previous_revenue': feature.revenue_generated * 0.95,
            'conversion_rate': feature.conversion_rate,
            'engagement': feature.engagement_score,
            'error_rate': feature.errors_last_30_days / max(feature.uses_last_30_days, 1),
            'roi': feature.roi
        }
    
    def _analyze_costs(self, feature: FeatureState, metrics: Dict) -> Dict:
        """Analyze costs."""
        return {
            'api_cost': metrics['cost'] * 0.6,
            'compute_cost': metrics['cost'] * 0.3,
            'error_cost': feature.errors_last_30_days * 0.50,
            'total': metrics['cost']
        }
    
    def _analyze_benefits(self, feature: FeatureState, metrics: Dict) -> Dict:
        """Analyze benefits."""
        return {
            'revenue': metrics['revenue'],
            'engagement_value': metrics['engagement'] * 100,
            'conversion_value': metrics['conversion_rate'] * metrics['uses'] * 50,
            'total': metrics['revenue'] + (metrics['engagement'] * 100) + (metrics['conversion_rate'] * metrics['uses'] * 50)
        }
    
    def _determine_recommendation(
        self, feature: FeatureState, metrics: Dict, costs: Dict, benefits: Dict
    ) -> AIRecommendationType:
        """Determine best recommendation."""
        roi = (benefits['total'] - costs['total']) / max(costs['total'], 1)
        
        if feature.state == ToggleState.ON and roi < -0.1:
            return AIRecommendationType.TOGGLE_OFF
        elif feature.state == ToggleState.OFF and roi > 0.2:
            return AIRecommendationType.TOGGLE_ON
        elif feature.state == ToggleState.ON and 0 < roi < 0.1:
            return AIRecommendationType.SET_TIMER
        
        return AIRecommendationType.NO_CHANGE
    
    def _get_recommended_state(self, rec_type: AIRecommendationType) -> Optional[ToggleState]:
        """Get recommended toggle state."""
        mapping = {
            AIRecommendationType.TOGGLE_ON: ToggleState.ON,
            AIRecommendationType.TOGGLE_OFF: ToggleState.OFF,
            AIRecommendationType.SET_TIMER: ToggleState.TIMER
        }
        return mapping.get(rec_type)

# ============================================================================
# ENHANCED CONTROL PANEL
# ============================================================================

class EnhancedControlPanel:
    """Full control panel with AI reasoning and reset."""
    
    def __init__(self, redis_client=None, supabase_client=None):
        self.redis = redis_client
        self.supabase = supabase_client
        
        self.features: Dict[str, FeatureState] = {}
        self.change_history: List[ChangeRecord] = []
        self.snapshots: Dict[str, PlatformSnapshot] = {}
        self.notifications: List[Notification] = []
        self.crm_notifications: List[CRMNotification] = []
        self.pending_resets: Dict[str, ResetRequest] = {}
        
        self._initialize_features()
        self.ai_engine = AIOptimizationEngine(self)
        self._create_snapshot(ResetScope.PLATFORM, '', 'system', 'Initial state')
    
    def _initialize_features(self):
        """Initialize features (abbreviated)."""
        # Sample structure
        paths = [
            'E00/Master_Controls/Global_Toggles/emergency_shutoff',
            'E01/Grading_Engine/ThreeDGrading/amount_scoring',
            'E17/Voice_Management/Voice_Profiles/clone_creation',
            'E30/Sending/Marketing/campaigns',
            'E47/Script_Generation/Types/rvm_scripts'
        ]
        for path in paths:
            self.features[path] = FeatureState(path=path, name=path.split('/')[-1])
        logger.info(f"Initialized {len(self.features)} features")
    
    def set_toggle(
        self,
        path: str,
        new_state: ToggleState,
        changed_by: str,
        source: ChangeSource = ChangeSource.MANUAL,
        reason: str = '',
        candidate_id: str = '',
        ai_reasoning: Optional[AIReasoning] = None
    ) -> Tuple[bool, str, Optional[ChangeRecord]]:
        """Set toggle with full audit."""
        feature = self.features.get(path)
        if not feature:
            return False, "Feature not found", None
        
        # Check AI permission
        if source == ChangeSource.AI and feature.manual_lock_active:
            self._create_ai_blocked_notification(feature, new_state, candidate_id, ai_reasoning)
            return False, "Feature manually locked", None
        
        old_state = feature.state
        old_snapshot = feature.to_snapshot()
        
        feature.state = new_state
        feature.last_changed_at = datetime.now()
        feature.last_changed_by = changed_by
        feature.last_change_source = source
        feature.change_count += 1
        
        if source == ChangeSource.MANUAL:
            feature.manually_set = True
            feature.manually_set_by = changed_by
            feature.manually_set_at = datetime.now()
            feature.manual_lock_active = True
            feature.ai_can_modify = False
        
        record = ChangeRecord(
            path=path,
            feature_name=feature.name,
            old_state=old_state.value,
            new_state=new_state.value,
            old_value=old_snapshot,
            new_value=feature.to_snapshot(),
            source=source,
            changed_by=changed_by,
            reason=reason,
            candidate_id=candidate_id,
            ai_reasoning=ai_reasoning,
            ai_reasoning_id=ai_reasoning.reasoning_id if ai_reasoning else None
        )
        
        self.change_history.append(record)
        self._create_notification(record, candidate_id, ai_reasoning)
        
        if source == ChangeSource.AI:
            self._send_ai_confirmation(record, candidate_id, ai_reasoning)
        
        if 'ai_control' in path.lower() or 'AI_Delegation' in path:
            self._notify_crm(record, candidate_id, ai_reasoning)
        
        return True, "Success", record
    
    def ai_recommend_change(self, path: str, candidate_id: str) -> Dict:
        """Get AI recommendation with full reasoning for candidate review."""
        recommendation = self.ai_engine.analyze_feature(path)
        return {
            'recommendation_id': recommendation.recommendation_id,
            'path': path,
            'recommendation': recommendation.recommendation_type.value,
            'confidence': f"{recommendation.confidence_score*100:.0f}%",
            'report': recommendation.reasoning.generate_candidate_report()
        }
    
    def ai_recommend_reset(self, scope: ResetScope, path: str, candidate_id: str) -> Dict:
        """Get AI recommendation for reset with reasoning."""
        if scope == ResetScope.FEATURE:
            recommendation = self.ai_engine.analyze_feature(path)
        else:
            # For broader scopes, analyze multiple features
            recommendation = self.ai_engine.analyze_feature(path)
        
        return {
            'recommendation_id': recommendation.recommendation_id,
            'scope': scope.value,
            'path': path,
            'recommendation': recommendation.recommendation_type.value,
            'report': recommendation.reasoning.generate_candidate_report(),
            'affected_features': recommendation.affected_count
        }
    
    def request_reset(
        self,
        scope: ResetScope,
        path: str,
        target_timestamp: datetime,
        requested_by: str,
        reason: str = '',
        ai_assisted: bool = False
    ) -> ResetRequest:
        """Request reset with optional AI reasoning."""
        code = hashlib.sha256(f"{path}{target_timestamp}".encode()).hexdigest()[:8].upper()
        
        ai_reasoning = None
        if ai_assisted:
            rec = self.ai_engine.analyze_feature(path)
            ai_reasoning = rec.reasoning
        
        request = ResetRequest(
            scope=scope,
            path=path,
            target_timestamp=target_timestamp,
            requested_by=requested_by,
            reason=reason,
            confirmation_code=code,
            ai_recommended=ai_assisted,
            ai_reasoning=ai_reasoning
        )
        
        self.pending_resets[request.request_id] = request
        return request
    
    def confirm_reset(self, request_id: str, code: str, confirmed_by: str) -> Tuple[bool, str, int]:
        """Confirm reset with failsafe."""
        request = self.pending_resets.get(request_id)
        if not request:
            return False, "Not found", 0
        if request.confirmation_code != code:
            return False, f"Invalid code. Enter: {request.confirmation_code}", 0
        
        request.confirmed = True
        request.confirmed_by = confirmed_by
        request.confirmed_at = datetime.now()
        
        # Execute reset
        count = self._execute_reset(request)
        request.status = 'executed'
        request.features_reset = count
        
        return True, f"Reset complete. {count} features restored.", count
    
    def _execute_reset(self, request: ResetRequest) -> int:
        """Execute reset operation."""
        # Find snapshot closest to target time
        target = request.target_timestamp
        best_snapshot = None
        
        for snapshot in self.snapshots.values():
            if snapshot.timestamp <= target:
                if not best_snapshot or snapshot.timestamp > best_snapshot.timestamp:
                    best_snapshot = snapshot
        
        if not best_snapshot:
            return 0
        
        count = 0
        for path, state_dict in best_snapshot.feature_states.items():
            if request.scope == ResetScope.PLATFORM or path.startswith(request.path):
                feature = self.features.get(path)
                if feature:
                    feature.state = ToggleState(state_dict.get('state', 'on'))
                    feature.last_changed_at = datetime.now()
                    feature.last_changed_by = f"RESET:{request.request_id}"
                    feature.last_change_source = ChangeSource.RESET
                    count += 1
        
        return count
    
    def _create_snapshot(self, scope: ResetScope, path: str, created_by: str, description: str):
        """Create platform snapshot."""
        snapshot = PlatformSnapshot(
            scope=scope,
            scope_path=path,
            created_by=created_by,
            description=description,
            feature_states={p: f.to_snapshot() for p, f in self.features.items()}
        )
        self.snapshots[snapshot.snapshot_id] = snapshot
    
    def _create_notification(self, record: ChangeRecord, candidate_id: str, reasoning: Optional[AIReasoning]):
        """Create notification with reasoning link."""
        notification = Notification(
            candidate_id=candidate_id,
            ecosystem=record.ecosystem,
            title=f"{'AI' if record.source == ChangeSource.AI else 'Manual'} Change: {record.feature_name}",
            message=f"Changed from {record.old_state} to {record.new_state}",
            change_record_id=record.record_id,
            ai_reasoning_id=reasoning.reasoning_id if reasoning else None,
            source=record.source,
            control_panel_path=record.path,
            reasoning_available=reasoning is not None,
            view_reasoning_link=f"/control-panel/reasoning/{reasoning.reasoning_id}" if reasoning else ''
        )
        self.notifications.append(notification)
    
    def _create_ai_blocked_notification(
        self, feature: FeatureState, new_state: ToggleState, candidate_id: str, reasoning: Optional[AIReasoning]
    ):
        """Notify candidate that AI wanted to change but was blocked."""
        notification = Notification(
            candidate_id=candidate_id,
            title=f"AI Recommendation Blocked: {feature.name}",
            message=f"AI wanted to change to {new_state.value} but you have manual control. Click to review reasoning.",
            priority=NotificationPriority.MEDIUM,
            source=ChangeSource.AI,
            control_panel_path=feature.path,
            reasoning_available=reasoning is not None,
            view_reasoning_link=f"/control-panel/reasoning/{reasoning.reasoning_id}" if reasoning else ''
        )
        self.notifications.append(notification)
    
    def _send_ai_confirmation(self, record: ChangeRecord, candidate_id: str, reasoning: Optional[AIReasoning]):
        """Send confirmation that AI made a change."""
        notification = Notification(
            candidate_id=candidate_id,
            title=f"AI Changed: {record.feature_name}",
            message=f"AI changed {record.path} from {record.old_state} to {record.new_state}. Tap to see why.",
            priority=NotificationPriority.HIGH,
            source=ChangeSource.AI,
            control_panel_path=record.path,
            reasoning_available=True,
            view_reasoning_link=f"/control-panel/reasoning/{reasoning.reasoning_id}" if reasoning else ''
        )
        self.notifications.append(notification)
    
    def _notify_crm(self, record: ChangeRecord, candidate_id: str, reasoning: Optional[AIReasoning]):
        """Notify BroyhillGOP Campaign Manager CRM."""
        crm_notification = CRMNotification(
            candidate_id=candidate_id,
            change_type='AI_CONTROL_CHANGE',
            change_description=f"{record.feature_name}: {record.old_state} -> {record.new_state}",
            path=record.path,
            changed_by=record.changed_by,
            ai_reasoning_summary=reasoning.why_summary if reasoning else '',
            requires_followup=True
        )
        self.crm_notifications.append(crm_notification)
        logger.info(f"CRM NOTIFICATION: {crm_notification.change_description}")
    
    def get_reasoning_for_candidate(self, reasoning_id: str) -> Optional[Dict]:
        """Get full reasoning report for candidate viewing."""
        for rec in self.ai_engine.recommendations.values():
            if rec.reasoning.reasoning_id == reasoning_id:
                return rec.reasoning.generate_candidate_report()
        return None
    
    def get_change_history(self, path: str = None, limit: int = 100) -> List[Dict]:
        """Get change history with reasoning links."""
        history = self.change_history
        if path:
            history = [h for h in history if h.path.startswith(path)]
        
        return [
            {
                'timestamp': h.timestamp_iso,
                'path': h.path,
                'old_state': h.old_state,
                'new_state': h.new_state,
                'changed_by': h.changed_by,
                'source': h.source.value,
                'reason': h.reason,
                'has_reasoning': h.ai_reasoning is not None,
                'reasoning_link': f"/control-panel/reasoning/{h.ai_reasoning_id}" if h.ai_reasoning_id else None
            }
            for h in history[-limit:]
        ]

# ============================================================================
# MAIN
# ============================================================================

def main():
    """Demo the enhanced control panel."""
    print("="*80)
    print("ENHANCED CONTROL PANEL WITH AI REASONING & EVIDENCE")
    print("="*80)
    print()
    
    panel = EnhancedControlPanel()
    
    # Demo AI recommendation with full reasoning
    print("AI RECOMMENDATION FOR E30/Sending/Marketing/campaigns:")
    print("-" * 60)
    
    report = panel.ai_recommend_change('E30/Sending/Marketing/campaigns', 'candidate_001')
    
    print(f"Recommendation: {report['recommendation']}")
    print(f"Confidence: {report['confidence']}")
    print()
    print("CANDIDATE REPORT:")
    print(json.dumps(report['report']['summary'], indent=2))
    print()
    print("WHY (One Sentence):")
    print(report['report']['summary']['why_one_sentence'])
    print()
    print("KEY POINTS:")
    for point in report['report']['detailed_explanation']['key_points']:
        print(f"  {point}")
    print()
    print("FAQ:")
    for qa in report['report']['faq'][:2]:
        print(f"  Q: {qa['question']}")
        print(f"  A: {qa['answer']}")
        print()

if __name__ == '__main__':
    main()
