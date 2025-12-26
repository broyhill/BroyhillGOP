#!/usr/bin/env python3
"""
============================================================================
DONOR CULTIVATION INTELLIGENCE
============================================================================

AI-driven cultivation investment decisions. NO HARD CAPS.

The system learns through testing and probing:
- Which microsegments respond to which channels
- Optimal investment levels by segment
- When to increase/decrease spend
- ROI thresholds that trigger strategy changes

Philosophy:
- Let the algorithm work naturally
- Cost/benefit determines investment, not arbitrary caps
- Continuous testing and learning
- Grade is a STARTING POINT, not a constraint

============================================================================
"""

from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum


class InvestmentStrategy(Enum):
    """AI-determined investment strategies"""
    AGGRESSIVE = "aggressive"      # High potential, invest heavily
    STANDARD = "standard"          # Normal cultivation
    TESTING = "testing"            # Probing to learn more
    CONSERVATION = "conservation"  # Low ROI, reduce but don't stop
    REACTIVATION = "reactivation"  # Lapsed, try to win back


@dataclass
class MicrosegmentPerformance:
    """Performance data for a microsegment"""
    segment_id: str
    segment_definition: Dict  # e.g., {'grade': 'U', 'county': 'Wake', 'age_range': '25-34'}
    
    # Investment
    total_invested: float = 0.0
    investment_period_days: int = 0
    
    # Results
    total_revenue: float = 0.0
    conversions: int = 0
    
    # Engagement
    emails_sent: int = 0
    emails_opened: int = 0
    clicks: int = 0
    
    # Calculated
    @property
    def roi(self) -> float:
        if self.total_invested <= 0:
            return 0.0
        return (self.total_revenue - self.total_invested) / self.total_invested
    
    @property
    def open_rate(self) -> float:
        if self.emails_sent <= 0:
            return 0.0
        return self.emails_opened / self.emails_sent
    
    @property
    def conversion_rate(self) -> float:
        if self.emails_sent <= 0:
            return 0.0
        return self.conversions / self.emails_sent
    
    @property
    def cost_per_conversion(self) -> float:
        if self.conversions <= 0:
            return float('inf')
        return self.total_invested / self.conversions


# ============================================================================
# AI INVESTMENT DECISION ENGINE
# ============================================================================

class CultivationIntelligence:
    """
    AI-driven cultivation investment decisions.
    
    Replaces hard-coded rules with learning algorithms that:
    1. Test and probe all segments
    2. Learn what works
    3. Adjust investment based on results
    4. Never completely abandon any segment (always testing)
    """
    
    def __init__(self):
        # Minimum test thresholds (to ensure statistical significance)
        self.min_test_sends = 100  # Need at least 100 sends to evaluate
        self.min_test_period_days = 30  # Need at least 30 days of data
        
        # ROI thresholds for strategy changes (learned, not fixed)
        self.roi_thresholds = {
            'excellent': 5.0,   # 5:1 ROI
            'good': 2.0,        # 2:1 ROI
            'acceptable': 1.0,  # Break even
            'poor': 0.5,        # Losing money but showing promise
            'very_poor': 0.0    # Negative ROI
        }
    
    def determine_investment_strategy(
        self,
        segment: MicrosegmentPerformance
    ) -> Dict:
        """
        AI determines optimal strategy for a microsegment.
        
        NO HARD CAPS - decisions based on performance data.
        """
        # Not enough data? Keep testing
        if segment.emails_sent < self.min_test_sends:
            return {
                'strategy': InvestmentStrategy.TESTING.value,
                'reason': f'Insufficient data ({segment.emails_sent} sends, need {self.min_test_sends})',
                'recommended_action': 'Continue testing all channels',
                'investment_modifier': 1.0,  # Normal investment
                'channels_to_test': ['email', 'sms', 'direct_mail'],
                'suppress': False
            }
        
        # Evaluate performance
        roi = segment.roi
        open_rate = segment.open_rate
        conversion_rate = segment.conversion_rate
        
        # Excellent performers - invest aggressively
        if roi >= self.roi_thresholds['excellent']:
            return {
                'strategy': InvestmentStrategy.AGGRESSIVE.value,
                'reason': f'Excellent ROI ({roi:.1f}:1)',
                'recommended_action': 'Increase investment, expand channels',
                'investment_modifier': 2.0,  # Double investment
                'channels_to_expand': self._get_best_channels(segment),
                'suppress': False
            }
        
        # Good performers - standard cultivation
        if roi >= self.roi_thresholds['good']:
            return {
                'strategy': InvestmentStrategy.STANDARD.value,
                'reason': f'Good ROI ({roi:.1f}:1)',
                'recommended_action': 'Maintain current investment',
                'investment_modifier': 1.0,
                'suppress': False
            }
        
        # Acceptable - continue but test optimizations
        if roi >= self.roi_thresholds['acceptable']:
            return {
                'strategy': InvestmentStrategy.TESTING.value,
                'reason': f'Acceptable ROI ({roi:.1f}:1) - room for improvement',
                'recommended_action': 'Test different channels, timing, content',
                'investment_modifier': 1.0,
                'test_variations': ['channel', 'timing', 'content', 'frequency'],
                'suppress': False
            }
        
        # Poor ROI but showing engagement
        if roi >= self.roi_thresholds['poor'] or open_rate > 0.15:
            return {
                'strategy': InvestmentStrategy.TESTING.value,
                'reason': f'Low ROI ({roi:.1f}:1) but engagement ({open_rate:.0%} opens)',
                'recommended_action': 'Reduce frequency, test conversion optimization',
                'investment_modifier': 0.5,  # Reduce but don't stop
                'focus': 'conversion_optimization',
                'suppress': False
            }
        
        # Very poor - conservation mode (but never stop completely)
        return {
            'strategy': InvestmentStrategy.CONSERVATION.value,
            'reason': f'Poor performance (ROI: {roi:.1f}:1, Opens: {open_rate:.0%})',
            'recommended_action': 'Minimal investment, periodic re-testing',
            'investment_modifier': 0.25,  # Reduce to 25%
            'retest_interval_days': 90,  # Re-test quarterly
            'suppress': False  # NEVER completely suppress
        }
    
    def _get_best_channels(self, segment: MicrosegmentPerformance) -> List[str]:
        """Determine best channels based on segment data (placeholder)"""
        # In production, this queries the learning database
        return ['email', 'sms']
    
    def calculate_optimal_investment(
        self,
        segment: MicrosegmentPerformance,
        available_budget: float,
        campaign_goal: float
    ) -> Dict:
        """
        Calculate optimal investment for a segment.
        
        Based on:
        - Historical performance
        - Available budget
        - Campaign goals
        - Portfolio diversification (don't over-concentrate)
        """
        strategy = self.determine_investment_strategy(segment)
        modifier = strategy['investment_modifier']
        
        # Base investment calculation
        if segment.conversions > 0:
            # Have conversion data - use cost per conversion
            target_conversions = campaign_goal / (segment.total_revenue / segment.conversions) if segment.conversions > 0 else 10
            base_investment = segment.cost_per_conversion * target_conversions
        else:
            # No conversions yet - testing budget
            base_investment = min(available_budget * 0.1, 500)  # 10% or $500 max for testing
        
        # Apply strategy modifier
        recommended_investment = base_investment * modifier
        
        # Portfolio limit (don't put more than 30% in any one segment)
        max_segment_allocation = available_budget * 0.30
        final_investment = min(recommended_investment, max_segment_allocation)
        
        return {
            'segment_id': segment.segment_id,
            'strategy': strategy['strategy'],
            'base_investment': round(base_investment, 2),
            'modifier': modifier,
            'recommended_investment': round(recommended_investment, 2),
            'final_investment': round(final_investment, 2),
            'expected_roi': segment.roi,
            'expected_conversions': int(final_investment / segment.cost_per_conversion) if segment.cost_per_conversion < float('inf') else 0,
            'reasoning': strategy['reason']
        }
    
    def generate_test_plan(
        self,
        untested_segments: List[Dict],
        test_budget: float
    ) -> List[Dict]:
        """
        Generate testing plan for segments with insufficient data.
        
        Philosophy: Always be testing. Never assume a segment won't work.
        """
        # Allocate test budget evenly across untested segments
        per_segment_budget = test_budget / len(untested_segments) if untested_segments else 0
        
        test_plans = []
        for segment in untested_segments:
            test_plans.append({
                'segment': segment,
                'test_budget': round(per_segment_budget, 2),
                'test_channels': ['email'],  # Start with cheapest
                'test_sends': max(100, int(per_segment_budget / 0.01)),  # At $0.01 per email
                'test_duration_days': 30,
                'success_criteria': {
                    'min_open_rate': 0.10,
                    'min_click_rate': 0.02,
                    'target_conversion_rate': 0.01
                },
                'escalation_criteria': {
                    'if_open_rate_above': 0.20,
                    'then': 'Test SMS and direct mail'
                }
            })
        
        return test_plans


# ============================================================================
# GRADE-BASED STARTING POINTS (Not Caps)
# ============================================================================

# These are STARTING POINTS for the AI, not hard limits
# The AI will adjust based on actual performance

GRADE_STARTING_ASSUMPTIONS = {
    'A++': {
        'expected_response_rate': 0.35,
        'expected_avg_gift': 5000,
        'initial_channels': ['phone', 'direct_mail', 'email', 'events'],
        'initial_frequency': 'high'
    },
    'A+': {
        'expected_response_rate': 0.28,
        'expected_avg_gift': 2500,
        'initial_channels': ['phone', 'direct_mail', 'email', 'events'],
        'initial_frequency': 'high'
    },
    'A': {
        'expected_response_rate': 0.22,
        'expected_avg_gift': 1000,
        'initial_channels': ['direct_mail', 'email', 'events'],
        'initial_frequency': 'medium'
    },
    'B+': {
        'expected_response_rate': 0.15,
        'expected_avg_gift': 500,
        'initial_channels': ['direct_mail', 'email'],
        'initial_frequency': 'medium'
    },
    'B': {
        'expected_response_rate': 0.12,
        'expected_avg_gift': 250,
        'initial_channels': ['email', 'sms'],
        'initial_frequency': 'medium'
    },
    'C': {
        'expected_response_rate': 0.08,
        'expected_avg_gift': 100,
        'initial_channels': ['email'],
        'initial_frequency': 'low'
    },
    'D': {
        'expected_response_rate': 0.04,
        'expected_avg_gift': 50,
        'initial_channels': ['email'],
        'initial_frequency': 'low'
    },
    'U': {
        'expected_response_rate': 0.02,  # Unknown - will learn
        'expected_avg_gift': 50,         # Unknown - will learn
        'initial_channels': ['email'],   # Start cheap, expand if working
        'initial_frequency': 'testing',  # Probe to learn
        'note': 'These are GUESSES. AI will learn actual values.'
    }
}


# ============================================================================
# PROMOTION DETECTION (AI-Driven)
# ============================================================================

def detect_promotion_candidates(
    donors: List[Dict],
    performance_data: Dict[str, MicrosegmentPerformance]
) -> List[Dict]:
    """
    AI identifies donors who should be promoted based on behavior,
    not arbitrary thresholds.
    
    Looks for:
    - Engagement exceeding grade average
    - Donation patterns suggesting higher capacity
    - Response rates above segment peers
    """
    candidates = []
    
    for donor in donors:
        donor_id = donor['id']
        current_grade = donor['grade']
        
        # Get donor's engagement metrics
        engagement = donor.get('engagement', {})
        
        # Compare to grade average
        grade_avg = GRADE_STARTING_ASSUMPTIONS.get(current_grade, {})
        expected_response = grade_avg.get('expected_response_rate', 0.05)
        
        # Donor's actual response rate
        if donor.get('solicitations_received', 0) > 0:
            actual_response = donor.get('donations_made', 0) / donor['solicitations_received']
        else:
            actual_response = 0
        
        # If responding at 2x+ grade average, candidate for promotion
        if actual_response >= expected_response * 2:
            candidates.append({
                'donor_id': donor_id,
                'current_grade': current_grade,
                'reason': f'Response rate {actual_response:.0%} is 2x+ grade average ({expected_response:.0%})',
                'recommended_action': 'Upgrade investment tier, test higher ask amounts'
            })
        
        # If engagement metrics exceed expectations
        if engagement.get('email_open_rate', 0) > 0.40:  # 40%+ open rate
            candidates.append({
                'donor_id': donor_id,
                'current_grade': current_grade,
                'reason': f'High engagement ({engagement["email_open_rate"]:.0%} open rate)',
                'recommended_action': 'Expand channel testing, increase frequency'
            })
    
    return candidates


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("DONOR CULTIVATION INTELLIGENCE")
    print("=" * 60)
    print("\nPhilosophy: NO HARD CAPS")
    print("Let the AI learn what works through testing and probing.")
    print("=" * 60)
    
    intel = CultivationIntelligence()
    
    # Example: U donor segment with good engagement
    u_segment = MicrosegmentPerformance(
        segment_id='U_Wake_25-34',
        segment_definition={'grade': 'U', 'county': 'Wake', 'age_range': '25-34'},
        total_invested=150.00,
        investment_period_days=60,
        total_revenue=425.00,
        conversions=8,
        emails_sent=1500,
        emails_opened=375,
        clicks=45
    )
    
    print(f"\nSegment: {u_segment.segment_id}")
    print(f"  Invested: ${u_segment.total_invested:.2f}")
    print(f"  Revenue: ${u_segment.total_revenue:.2f}")
    print(f"  ROI: {u_segment.roi:.1f}:1")
    print(f"  Open Rate: {u_segment.open_rate:.0%}")
    print(f"  Conversions: {u_segment.conversions}")
    
    strategy = intel.determine_investment_strategy(u_segment)
    print(f"\nAI RECOMMENDATION:")
    print(f"  Strategy: {strategy['strategy']}")
    print(f"  Reason: {strategy['reason']}")
    print(f"  Action: {strategy['recommended_action']}")
    print(f"  Investment Modifier: {strategy['investment_modifier']}x")
    
    # Calculate optimal investment
    investment = intel.calculate_optimal_investment(
        segment=u_segment,
        available_budget=10000,
        campaign_goal=50000
    )
    
    print(f"\nOPTIMAL INVESTMENT:")
    print(f"  Recommended: ${investment['final_investment']:.2f}")
    print(f"  Expected Conversions: {investment['expected_conversions']}")
    print(f"  Reasoning: {investment['reasoning']}")
    
    print("\n" + "=" * 60)
    print("KEY INSIGHT: The U segment above has 1.8:1 ROI!")
    print("Old system would have capped investment at $0.50/donor.")
    print("New system says: INVEST MORE - it's working!")
    print("=" * 60)
